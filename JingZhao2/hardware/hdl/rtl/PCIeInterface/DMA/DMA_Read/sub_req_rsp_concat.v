`timescale 1ns / 100ps
//*************************************************************************
// > File Name: sub_req_rsp_concat.v
// > Author   : Kangning
// > Date     : 2020-09-24
// > Note     : sub_req_rsp_concat, used to reassemble sub-request according 
// >               to Max_Read_Request_Size.
//*************************************************************************

module sub_req_rsp_concat #(
    parameter HEAD_DEPTH_LOG = 6
) (
    input wire dma_clk, // i, 1
    input wire rst_n   , // i, 1

    /* -------response emission{begin}------- */
    input  wire                     emit, // i, 1 ; high active
    /* -------response emission{end}------- */

    /* ------- Read Response from <read_response> module{begin} ------- */
    /* *_head (interact with RDMA modules, through an async fifo), valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    input  wire                   rd_sub_req_rsp_valid, // i, 1
    input  wire                   rd_sub_req_rsp_last , // i, 1
    input  wire [`DMA_DATA_W-1:0] rd_sub_req_rsp_data , // i, `DMA_DATA_W
    input  wire [`DMA_HEAD_W-1:0] rd_sub_req_rsp_head , // i, `DMA_HEAD_W
    output wire                   rd_sub_req_rsp_ready, // o, 1

    output  reg                   is_avail, // o, 1
    /* ------- Read Response from <read_response> module{end} ------- */

    /* ------- Read Response to RDMA Engine{begin} ------- */
    /* *_head (interact with RDMA modules, through an async fifo), valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    output  wire                   rd_rsp_valid, // o, 1
    output  wire                   rd_rsp_last , // o, 1
    output  wire [`DMA_DATA_W-1:0] rd_rsp_data , // o, `DMA_DATA_W
    output  wire [`DMA_HEAD_W-1:0] rd_rsp_head , // o, `DMA_HEAD_W
    input   wire                   rd_rsp_ready, // i, 1
    /* ------- Read Response to RDMA Engine{end} ------- */

    /* -------PCIe fragment property{begin}------- */
    /* This signal indicates the (max payload size & max read request size) agreed in the communication
     * 3'b000 -- 128 B
     * 3'b001 -- 256 B
     * 3'b010 -- 512 B
     * 3'b011 -- 1024B
     * 3'b100 -- 2048B
     * 3'b101 -- 4096B
     */
    input wire [2:0] max_pyld_sz  ,
    input wire [2:0] max_rd_req_sz  // max read request size
    /* -------PCIe fragment property{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [`SRAM_RW_DATA_W-1:0] rw_data  // i, `SRAM_RW_DATA_W
    ,output wire [`RSP_CONCAT_SIGNAL_W-1:0] dbg_signal  // o, `RSP_CONCAT_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

/* --------Head FIFO{begin}-------- */
reg is_sub_head_sop;
reg is_head_sop;
reg  [`DMA_ADDR_WIDTH-1:0] hd_addr;
reg  [`DMA_LEN_WIDTH -1:0] hd_byte_len;
wire [`DMA_LEN_WIDTH -1:0] nxt_byte_len;

wire only_req_rsp_sop    ;
wire last_sub_req_rsp_sop; // sop of last sub_req rsp
wire last_sub_req_rsp_eop; // eop of last sub_req rsp

wire                   head_in_valid;
wire [`DMA_HEAD_W-1:0] head_in_head ;
wire                   head_in_ready;
wire                   head_in_full ;

wire                   head_out_valid;
wire [`DMA_HEAD_W-1:0] head_out_head ;
wire                   head_out_ready;
wire                   head_out_empty;
/* --------Head FIFO{end}-------- */

/* --------prog_full{begin}--------- */
/* The inputt is blocked caused by : 
 * 1. data_rsp_fifo cannot accept new pkt;
 * 2. head_store_fifo cannot store new head. */
wire is_input_blocked;
wire fifo_prog_full;
wire [`DW_LEN_WIDTH-1:0] max_rd_req_cycle_num; // The maximum read request in dw unit
wire [`DMA_LEN_WIDTH-5-1:0] fifo_cycle_cnt;
reg  [`DMA_LEN_WIDTH  -1:0] fifo_byte_cnt;
wire [`DMA_LEN_WIDTH  -1:0] nxt_fifo_byte_cnt, fifo_in_inc, fifo_out_dec;
/* --------prog_full{end}--------- */

/* --------Data FIFO{begin}-------- */
wire                      sub_req_rsp_valid;
wire                      sub_req_rsp_last ;
wire                      sub_req_rsp_eop  ; // End of the req rsp msg
wire [`DMA_DATA_W   -1:0] sub_req_rsp_data ;
wire [`DMA_LEN_WIDTH-1:0] sub_req_rsp_blen ;
wire [`DMA_HEAD_W   -1:0] sub_req_rsp_head ;
wire                      sub_req_rsp_ready;

wire [`DMA_LEN_WIDTH -1:0] sub_blen_total;
wire [`DMA_LEN_WIDTH -1:0] sub_blen_left ;
reg  [`DMA_LEN_WIDTH -1:0] in_trans_cnt  ;

wire [`DMA_LEN_WIDTH -1:0] out_blen_total;
wire [`DMA_LEN_WIDTH -1:0] out_blen_left ;
reg  [`DMA_LEN_WIDTH -1:0] out_trans_cnt ;

wire                   req_rsp_valid;
wire                   req_rsp_last ;
wire [`DMA_DATA_W-1:0] req_rsp_data ;
wire                   req_rsp_ready;
/* --------Data FIFO{end}-------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire [`DATA_FIFO_SIGNAL_W-1:0] dbg_signal_data_fifo;
/* -------APB reated signal{end}------- */
`endif

//-----------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign dbg_signal = { // 2770
    is_sub_head_sop, is_head_sop, // 2
    hd_addr, hd_byte_len, nxt_byte_len, // 90
    only_req_rsp_sop, last_sub_req_rsp_sop, last_sub_req_rsp_eop, // 3
    head_in_valid, head_in_head , head_in_ready, head_in_full , // 131
    head_out_valid, head_out_head , head_out_ready, head_out_empty, // 131
    is_input_blocked, fifo_prog_full, // 2
    max_rd_req_cycle_num, // 11
    fifo_cycle_cnt, // 8
    fifo_byte_cnt, // 13
    nxt_fifo_byte_cnt, fifo_in_inc, fifo_out_dec, // 39
    sub_req_rsp_valid, sub_req_rsp_last, sub_req_rsp_eop, sub_req_rsp_data, sub_req_rsp_blen, sub_req_rsp_head, sub_req_rsp_ready, // 401
    sub_blen_total, sub_blen_left , in_trans_cnt  , // 39
    out_blen_total, out_blen_left , out_trans_cnt , // 39
    req_rsp_valid, req_rsp_last , req_rsp_data , req_rsp_ready, // 259
    dbg_signal_data_fifo // 1602
};
/* -------APB reated signal{end}------- */
`endif

/* --------Head FIFO{begin}-------- */
// start of sub_req rsp pkt
always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        is_sub_head_sop <= `TD 1'b1;
    end
    else if (sub_req_rsp_valid & sub_req_rsp_ready & sub_req_rsp_last) begin
        is_sub_head_sop <= `TD 1'b1;
    end
    else if (sub_req_rsp_valid & sub_req_rsp_ready) begin // invalid after the first cycle
        is_sub_head_sop <= `TD 1'b0;
    end
end

// start of req rsp pkt
always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        is_head_sop <= `TD 1'b1;
    end
    else if (sub_req_rsp_valid & sub_req_rsp_ready & sub_req_rsp_last & emit) begin
        is_head_sop <= `TD 1'b1;
    end
    else if (sub_req_rsp_valid & sub_req_rsp_ready) begin // invalid after the first cycle
        is_head_sop <= `TD 1'b0;
    end
end

always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        hd_addr <= `TD 0;
    end
    else if (sub_req_rsp_valid & sub_req_rsp_ready & is_head_sop) begin // first cycle of req rsp
        hd_addr <= `TD sub_req_rsp_head[95:32];
    end
    else if (last_sub_req_rsp_eop) begin // last cycle of last sub_req rsp
        hd_addr <= `TD 0;
    end
end

always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        hd_byte_len <= `TD 0;
    end
    else if (sub_req_rsp_valid & sub_req_rsp_ready & is_head_sop) begin // first cycle of req rsp
        hd_byte_len <= `TD sub_req_rsp_head[12:0];
    end
    else if (sub_req_rsp_valid & sub_req_rsp_ready & is_sub_head_sop) begin // first cycle of middle & last sub_req rsp
        hd_byte_len <= `TD nxt_byte_len;
    end
    else if (last_sub_req_rsp_eop) begin // last cycle of last sub_req rsp
        hd_byte_len <= `TD 0;
    end
end
assign nxt_byte_len = hd_byte_len + sub_req_rsp_head[12:0];

assign only_req_rsp_sop     = emit & sub_req_rsp_valid & sub_req_rsp_ready & is_head_sop     ;
assign last_sub_req_rsp_sop = emit & sub_req_rsp_valid & sub_req_rsp_ready & is_sub_head_sop ;
assign last_sub_req_rsp_eop = emit & sub_req_rsp_valid & sub_req_rsp_ready & sub_req_rsp_last;


// -----------------------------------------Store the head------------------------------------------
assign head_in_valid = last_sub_req_rsp_sop | only_req_rsp_sop;
assign head_in_head  = only_req_rsp_sop ? 
                        {32'd0, sub_req_rsp_head[95:32], {32-`DMA_LEN_WIDTH{1'b0}}, sub_req_rsp_head[12:0]} : // if only has one sub_req rsp for a rsp
                        {32'd0, hd_addr, {32-`DMA_LEN_WIDTH{1'b0}}, nxt_byte_len};
assign head_in_ready  = !head_in_full;

assign head_out_ready = rd_rsp_valid & rd_rsp_ready & req_rsp_last;
assign head_out_valid = !head_out_empty;
pcieifc_sync_fifo #(
    .DSIZE      ( `DMA_HEAD_W    ), // 128
    .ASIZE      ( HEAD_DEPTH_LOG )  // 2
) head_store_fifo (

    .clk   ( dma_clk ), // i, i
    .rst_n ( rst_n   ), // i, i
    .clr   ( 1'd0    ), // i, 1

    .wen  ( head_in_valid & head_in_ready   ), // i, 1
    .din  ( head_in_head  ), // i, `DMA_HEAD_W
    .full ( head_in_full  ), // o, 1

    .ren  ( head_out_valid & head_out_ready ), // i, 1
    .dout ( head_out_head  ), // o, `DMA_HEAD_W
    .empty( head_out_empty )  // o, 1

`ifdef PCIEI_APB_DBG
    ,.rtsel ( 2'b0 )  // i, 2
    ,.wtsel ( 2'b0 )  // i, 2
    ,.ptsel ( 2'b0 )  // i, 2
    ,.vg    ( 1'b0 )  // i, 1
    ,.vs    ( 1'b0 )  // i, 1
`endif
);
/* --------Head FIFO{end}-------- */

/* --------is available{begin}-------- */
always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        is_avail <= `TD 1'd0;
    end
    else if (rd_rsp_ready) begin
        is_avail <= `TD 1'd1;
    end
    else begin
        is_avail <= `TD 1'd0;
    end
end
/* --------is available{end}-------- */

/* --------prog_full{begin}--------- */
assign rd_sub_req_rsp_ready = sub_req_rsp_ready & !is_input_blocked;

assign max_rd_req_cycle_num = 8'd4 << max_rd_req_sz;
assign is_input_blocked = is_sub_head_sop & (fifo_prog_full | !head_in_ready);
assign fifo_prog_full   = (fifo_cycle_cnt + max_rd_req_cycle_num) > (8'd1 << `RSP_FIFO_DEPTH_LOG);
assign fifo_cycle_cnt   = (|fifo_byte_cnt[4:0] + fifo_byte_cnt[`DMA_LEN_WIDTH-1:5]);

assign nxt_fifo_byte_cnt = fifo_byte_cnt + sub_req_rsp_blen;
assign fifo_in_inc  = last_sub_req_rsp_eop ? ((|nxt_fifo_byte_cnt[4:0] + nxt_fifo_byte_cnt[`DMA_LEN_WIDTH-1:5]) << 5) : 
                      (sub_req_rsp_valid & sub_req_rsp_ready) ? (fifo_byte_cnt + sub_req_rsp_blen) : fifo_byte_cnt;
assign fifo_out_dec = (req_rsp_valid & req_rsp_ready) ? `DMA_W_BCNT : {`DMA_LEN_WIDTH{1'd0}};
always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        fifo_byte_cnt <= `TD 0;
    end
    else begin
        fifo_byte_cnt <= `TD fifo_in_inc - fifo_out_dec;
    end
end
/* --------prog_full{end}--------- */

/* --------Data FIFO{begin}-------- */
assign sub_req_rsp_valid = rd_sub_req_rsp_valid & !is_input_blocked;
assign sub_req_rsp_last  = rd_sub_req_rsp_last ;
assign sub_req_rsp_eop   = rd_sub_req_rsp_last & emit;
assign sub_req_rsp_data  = rd_sub_req_rsp_data ;
assign sub_req_rsp_head  = rd_sub_req_rsp_head ;

assign sub_req_rsp_blen = (sub_blen_left >= `DMA_W_BCNT) ? `DMA_W_BCNT : sub_blen_left;
assign sub_blen_left    = sub_blen_total - in_trans_cnt;
assign sub_blen_total   = sub_req_rsp_head[12:0];
always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        in_trans_cnt <= `TD 0;
    end
    else if (sub_req_rsp_valid & sub_req_rsp_ready & sub_req_rsp_last) begin
        in_trans_cnt <= `TD 0;
    end
    else if (sub_req_rsp_valid & sub_req_rsp_ready) begin
        in_trans_cnt <= `TD in_trans_cnt + `DMA_W_BCNT;
    end
end

rsp_data_fifo #(
    
) rsp_data_fifo (

    .dma_clk ( dma_clk ), // i, 1
    .rst_n   ( rst_n   ), // i, 1

    /* ------- sub_req rsp input{begin} ------- */
    .sub_req_rsp_valid ( sub_req_rsp_valid ), // i, 1
    .sub_req_rsp_last  ( sub_req_rsp_last & emit ), // i, 1
    .sub_req_rsp_blen  ( sub_req_rsp_blen  ), // i, `DMA_LEN_WIDTH; blen for every cycle
    .sub_req_rsp_data  ( sub_req_rsp_data  ), // i, `DMA_DATA_W
    .sub_req_rsp_ready ( sub_req_rsp_ready ), // o, 1
    /* ------- sub_req rsp input{end} ------- */

    /* ------- rsp output{begin} ------- */
    .req_rsp_valid ( req_rsp_valid ), // o, 1
    .req_rsp_data  ( req_rsp_data  ), // o, `DMA_DATA_W
    .req_rsp_ready ( req_rsp_ready )  // i, 1
    /* ------- rsp output{end} ------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.rw_data      ( rw_data ) // i, `SRAM_RW_DATA_W
    ,.dbg_signal   ( dbg_signal_data_fifo )  // o, `DATA_FIFO_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

assign out_blen_total = head_out_head[12:0];
assign out_blen_left  = out_blen_total - out_trans_cnt;
always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        out_trans_cnt <= `TD 0;
    end
    else if (rd_rsp_valid & rd_rsp_ready & rd_rsp_last) begin
        out_trans_cnt <= `TD 0;
    end
    else if (rd_rsp_valid & rd_rsp_ready) begin
        out_trans_cnt <= `TD out_trans_cnt + `DMA_W_BCNT;
    end
end

assign req_rsp_last = (out_blen_left <= `DMA_W_BCNT);
/* --------Data FIFO{end}-------- */

/* --------Output {begin}-------- */
assign rd_rsp_valid  = req_rsp_valid & head_out_valid;
assign rd_rsp_last   = req_rsp_valid & req_rsp_last  ;
assign rd_rsp_data   = req_rsp_data ;
assign rd_rsp_head   = head_out_head;

assign req_rsp_ready = head_out_valid & rd_rsp_ready;
/* --------Output {end}-------- */

endmodule
