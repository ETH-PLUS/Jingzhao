`timescale 1ns / 100ps
//*************************************************************************
// > File Name: np_tag_mgmt.v
// > Author   : Kangning
// > Date     : 2022-06-29
// > Note     : np_tag_mgmt, used for tag allocation of non-post request.
// >            V1.1 2022-06-29 : Add tag_chnl field to store
// >            V2.0 2022-11-03 : Add support for multi-channel tag fifo
//*************************************************************************

module np_tag_mgmt #(
    
) (
    input  wire dma_clk  , // i, 1
    input  wire rst_n    , // i, 1
    output reg  init_done, // o, 1; assert at the end of initial state

    /* -------tag request{begin}------- */
    input  wire                     tag_rreq_ready, // i, 1
    input  wire                     tag_rreq_last , // i, 1  ; Indicate the last sub-req for rd req
    input  wire [`DW_LEN_WIDTH-1:0] tag_rreq_sz   , // i, `DW_LEN_WIDTH ; Request size(in dw unit) of this tag
    input  wire [`TAG_MISC    -1:0] tag_rreq_misc , // o, `TAG_MISC ; Including addr && dw empty info
    input  wire [8            -1:0] tag_rreq_chnl , // i, 8 ; channel number for this request
    output wire [`TAG_NUM_LOG -1:0] tag_rreq_tag  , // o, `TAG_NUM_LOG
    output wire                     tag_rreq_valid, // o, 1
    /* -------tag request{end}------- */

    /* -------tag release{begin}------- */
    // Note that only one channel is allowed to assert at the same time
    input  wire [`DMA_RD_CHNL_NUM * 1             - 1 : 0] tag_rrsp_ready, // i, 1
    output wire [`DMA_RD_CHNL_NUM * 1             - 1 : 0] tag_rrsp_last , // o, 1
    output wire [`DMA_RD_CHNL_NUM * `DW_LEN_WIDTH - 1 : 0] tag_rrsp_sz   , // o, `DW_LEN_WIDTH
    output wire [`DMA_RD_CHNL_NUM * `TAG_MISC     - 1 : 0] tag_rrsp_misc , // o, `TAG_MISC ; Including addr && dw empty info
    output wire [`DMA_RD_CHNL_NUM * `TAG_NUM_LOG  - 1 : 0] tag_rrsp_tag  , // o, `TAG_NUM_LOG
    output wire [`DMA_RD_CHNL_NUM * 1             - 1 : 0] tag_rrsp_valid  // o, 1
    /* -------tag release{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [(`DMA_RD_CHNL_NUM+1)*`SRAM_RW_DATA_W-1:0] rw_data // i, (`DMA_RD_CHNL_NUM+1)*`SRAM_RW_DATA_W
    ,output wire [`TAG_MGMT_SIGNAL_W-1:0] dbg_signal  // o, `TAG_MGMT_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif

`ifdef SIMULATION    
    /* | reserved | tag_num | chnl_num | valid |
     * |  255:17  |  16:9   |    8:1   |   0   |
     */
    ,output wire [255:0] debug
    /* ------- Debug interface {end}------- */
`endif
);

/* --------Debug signal{begin}-------- */
`ifdef SIMULATION    

wire [7:0] dbug_tag_num, dbug_tag_chnl;
wire dbug_tag_valid;

`endif
/* --------Debug signal{end}-------- */

reg [`TAG_NUM_LOG-1:0] init_cnt;

/* --------Free tag management{begin}-------- */
wire                    free_tag_wen  ;
wire [`TAG_NUM_LOG-1:0] free_tag_din  ;
wire                    free_tag_full ;
wire                    free_tag_ren  ;
wire [`TAG_NUM_LOG-1:0] free_tag_dout ;
wire                    free_tag_empty;
/* --------Free tag management{end}-------- */

/* --------Free tag management{begin}-------- */
wire                                              alloced_tag_wen  [`DMA_RD_CHNL_NUM-1:0];
wire [`TAG_NUM_LOG+`DW_LEN_WIDTH+1+`TAG_MISC-1:0] alloced_tag_din  [`DMA_RD_CHNL_NUM-1:0];
wire                                              alloced_tag_full [`DMA_RD_CHNL_NUM-1:0];
wire                                              alloced_tag_ren  [`DMA_RD_CHNL_NUM-1:0];
wire [`TAG_NUM_LOG+`DW_LEN_WIDTH+1+`TAG_MISC-1:0] alloced_tag_dout [`DMA_RD_CHNL_NUM-1:0];
wire                                              alloced_tag_empty[`DMA_RD_CHNL_NUM-1:0];
/* --------Free tag management{end}-------- */

/* --------Arbiter logic{begin}-------- */
wire                    arb_tag_wen;
wire [`TAG_NUM_LOG-1:0] arb_tag_din;
/* --------Arbiter logic{end}-------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire  [1:0]  free_rtsel;
wire  [1:0]  free_wtsel;
wire  [1:0]  free_ptsel;
wire         free_vg   ;
wire         free_vs   ;
wire  [`DMA_RD_CHNL_NUM*2-1:0] alloced_rtsel;
wire  [`DMA_RD_CHNL_NUM*2-1:0] alloced_wtsel;
wire  [`DMA_RD_CHNL_NUM*2-1:0] alloced_ptsel;
wire  [`DMA_RD_CHNL_NUM*1-1:0] alloced_vg   ;
wire  [`DMA_RD_CHNL_NUM*1-1:0] alloced_vs   ;
/* -------APB reated signal{end}------- */
`endif

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign {
    free_rtsel, free_wtsel, free_ptsel, free_vg, free_vs, 
    alloced_rtsel, alloced_wtsel, alloced_ptsel, alloced_vg, alloced_vs} = rw_data;
assign dbg_signal = { // 605
    init_cnt, // 6
    free_tag_wen  , free_tag_din  , free_tag_full , free_tag_ren  , free_tag_dout , free_tag_empty, // 16

    alloced_tag_wen  [0], alloced_tag_wen  [1], alloced_tag_wen  [2], alloced_tag_wen  [3], 
    alloced_tag_wen  [4], alloced_tag_wen  [5], alloced_tag_wen  [6], alloced_tag_wen  [7], alloced_tag_wen  [8], 
    alloced_tag_din  [0], alloced_tag_din  [1], alloced_tag_din  [2], alloced_tag_din  [3], 
    alloced_tag_din  [4], alloced_tag_din  [5], alloced_tag_din  [6], alloced_tag_din  [7], alloced_tag_din  [8], 
    alloced_tag_full [0], alloced_tag_full [1], alloced_tag_full [2], alloced_tag_full [3], 
    alloced_tag_full [4], alloced_tag_full [5], alloced_tag_full [6], alloced_tag_full [7], alloced_tag_full [8], 
    alloced_tag_ren  [0], alloced_tag_ren  [1], alloced_tag_ren  [2], alloced_tag_ren  [3], 
    alloced_tag_ren  [4], alloced_tag_ren  [5], alloced_tag_ren  [6], alloced_tag_ren  [7], alloced_tag_ren  [8], 
    alloced_tag_dout [0], alloced_tag_dout [1], alloced_tag_dout [2], alloced_tag_dout [3], 
    alloced_tag_dout [4], alloced_tag_dout [5], alloced_tag_dout [6], alloced_tag_dout [7], alloced_tag_dout [8], 
    alloced_tag_empty[0], alloced_tag_empty[1], alloced_tag_empty[2], alloced_tag_empty[3], 
    alloced_tag_empty[4], alloced_tag_empty[5], alloced_tag_empty[6], alloced_tag_empty[7], alloced_tag_empty[8], // 64 * 9

    arb_tag_wen, arb_tag_din  // 7
};
/* -------APB reated signal{end}------- */
`endif

/* --------Debug signal{begin}-------- */
`ifdef SIMULATION    

/* | reserved | tag_num | chnl_num | valid |
 * |  255:9   |   8:1   |    8:1   |   1   |
 */
assign debug = {dbug_tag_num, dbug_tag_chnl, dbug_tag_valid};

generate
if (`DMA_RD_CHNL_NUM == 9) begin:DBUG_TAG_CHNL9
    
    assign dbug_tag_chnl  = (tag_rrsp_valid[0] & tag_rrsp_ready[0]) ? 8'd0 :
                            (tag_rrsp_valid[1] & tag_rrsp_ready[1]) ? 8'd1 :
                            (tag_rrsp_valid[2] & tag_rrsp_ready[2]) ? 8'd2 :
                            (tag_rrsp_valid[3] & tag_rrsp_ready[3]) ? 8'd3 :
                            (tag_rrsp_valid[4] & tag_rrsp_ready[4]) ? 8'd4 :
                            (tag_rrsp_valid[5] & tag_rrsp_ready[5]) ? 8'd5 :
                            (tag_rrsp_valid[6] & tag_rrsp_ready[6]) ? 8'd6 :
                            (tag_rrsp_valid[7] & tag_rrsp_ready[7]) ? 8'd7 :
                            (tag_rrsp_valid[8] & tag_rrsp_ready[8]) ? 8'd8 : 8'd0;

    assign dbug_tag_num   = (tag_rrsp_valid[0] & tag_rrsp_ready[0]) ? tag_rrsp_tag[1*`TAG_NUM_LOG-1:0*`TAG_NUM_LOG] :
                            (tag_rrsp_valid[1] & tag_rrsp_ready[1]) ? tag_rrsp_tag[2*`TAG_NUM_LOG-1:1*`TAG_NUM_LOG] :
                            (tag_rrsp_valid[2] & tag_rrsp_ready[2]) ? tag_rrsp_tag[3*`TAG_NUM_LOG-1:2*`TAG_NUM_LOG] :
                            (tag_rrsp_valid[3] & tag_rrsp_ready[3]) ? tag_rrsp_tag[4*`TAG_NUM_LOG-1:3*`TAG_NUM_LOG] :
                            (tag_rrsp_valid[4] & tag_rrsp_ready[4]) ? tag_rrsp_tag[5*`TAG_NUM_LOG-1:4*`TAG_NUM_LOG] :
                            (tag_rrsp_valid[5] & tag_rrsp_ready[5]) ? tag_rrsp_tag[6*`TAG_NUM_LOG-1:5*`TAG_NUM_LOG] :
                            (tag_rrsp_valid[6] & tag_rrsp_ready[6]) ? tag_rrsp_tag[7*`TAG_NUM_LOG-1:6*`TAG_NUM_LOG] :
                            (tag_rrsp_valid[7] & tag_rrsp_ready[7]) ? tag_rrsp_tag[8*`TAG_NUM_LOG-1:7*`TAG_NUM_LOG] :
                            (tag_rrsp_valid[8] & tag_rrsp_ready[8]) ? tag_rrsp_tag[9*`TAG_NUM_LOG-1:8*`TAG_NUM_LOG] : 8'd0;
end
endgenerate

assign dbug_tag_valid = |(tag_rrsp_valid & tag_rrsp_ready);

`endif
/* --------Debug signal{end}-------- */

/* --------Init logic{begin}-------- */
always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        init_cnt <= `TD 0;
    end
    else if (init_cnt < `TAG_NUM - 1'd1) begin
        init_cnt <= `TD init_cnt + 1;
    end
end

always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        init_done <= `TD 0;
    end
    else if (init_cnt == `TAG_NUM - 1'd1) begin
        init_done <= `TD 1;
    end
end
/* --------Init logic{end}-------- */

/* -------Free tag management{begin}------- */

assign free_tag_wen = (init_done ? arb_tag_wen : 1'd1) & !free_tag_full;
assign free_tag_din =  init_done ? arb_tag_din : (init_cnt + `TAG_BASE);

pcieifc_sync_fifo #(
    .DSIZE      ( `TAG_NUM_LOG ), // 6
    .ASIZE      ( `TAG_NUM_LOG )  // 6
) free_tag_fifo (

    .clk   ( dma_clk ), // i, i
    .rst_n ( rst_n   ), // i, i
    .clr   ( 1'd0    ), // i, 1

    .wen  ( free_tag_wen  ), // i, 1
    .din  ( free_tag_din  ), // i, `TAG_NUM_LOG
    .full ( free_tag_full ), // o, 1

    .ren  ( free_tag_ren   ), // i, 1
    .dout ( free_tag_dout  ), // o, `TAG_NUM_LOG
    .empty( free_tag_empty )  // o, 1

`ifdef PCIEI_APB_DBG
    ,.rtsel ( free_rtsel )  // i, 2
    ,.wtsel ( free_wtsel )  // i, 2
    ,.ptsel ( free_ptsel )  // i, 2
    ,.vg    ( free_vg    )  // i, 1
    ,.vs    ( free_vs    )  // i, 1
`endif
);
assign free_tag_ren  = tag_rreq_valid & tag_rreq_ready;
/* -------Free tag management{end}------- */

/* --------Tag rreq logic{begin}-------- */
assign tag_rreq_valid = !free_tag_empty;
assign tag_rreq_tag   = free_tag_dout;
/* --------Tag rreq logic{end}-------- */

genvar i;
generate
for (i = 0; i < `DMA_RD_CHNL_NUM; i = i + 1) begin:TAG_CHNL
    
/* -------Alloced FIFO logic{begin}------- */
    assign alloced_tag_wen[i] = (tag_rreq_chnl == i) & tag_rreq_valid & tag_rreq_ready; // alloced_tag_full never asserted
    assign alloced_tag_din[i] = {tag_rreq_tag, tag_rreq_sz, tag_rreq_last, tag_rreq_misc};
    pcieifc_sync_fifo #(
        .DSIZE      ( `TAG_NUM_LOG + `DW_LEN_WIDTH + 1 + `TAG_MISC ), // Stores tag & sz & last & misc. (30)
        .ASIZE      ( `TAG_NUM_LOG ) // (6)
    ) alloced_tag_fifo (

        .clk   ( dma_clk ), // i, i
        .rst_n ( rst_n   ), // i, i
        .clr   ( 1'd0    ), // i, 1

        .wen  ( alloced_tag_wen [i] ), // i, 1
        .din  ( alloced_tag_din [i] ), // i, `TAG_NUM_LOG + `DW_LEN_WIDTH + 1
        .full ( alloced_tag_full[i] ), // o, 1

        .ren  ( alloced_tag_ren  [i] ), // i, 1
        .dout ( alloced_tag_dout [i] ), // o, `TAG_NUM_LOG + `DW_LEN_WIDTH + 1
        .empty( alloced_tag_empty[i] )  // o, 1
    
    `ifdef PCIEI_APB_DBG
        ,.rtsel ( alloced_rtsel[(i+1)*2-1:i*2] )  // i, 2
        ,.wtsel ( alloced_wtsel[(i+1)*2-1:i*2] )  // i, 2
        ,.ptsel ( alloced_ptsel[(i+1)*2-1:i*2] )  // i, 2
        ,.vg    ( alloced_vg   [i] )  // i, 1
        ,.vs    ( alloced_vs   [i] )  // i, 1
    `endif
    );
    assign alloced_tag_ren  [i] = (tag_rrsp_ready[i] == 1);
/* -------Alloced FIFO logic{end}------- */

/* --------Tag rrsp logic{begin}-------- */
    assign {tag_rrsp_tag [(i+1) * `TAG_NUM_LOG  - 1 : i * `TAG_NUM_LOG ], 
            tag_rrsp_sz  [(i+1) * `DW_LEN_WIDTH - 1 : i * `DW_LEN_WIDTH], 
            tag_rrsp_last[(i+1) * 1             - 1 : i * 1            ],
            tag_rrsp_misc[(i+1) * `TAG_MISC     - 1 : i * `TAG_MISC    ]} = alloced_tag_dout[i];
    
    assign tag_rrsp_valid[i] = !alloced_tag_empty[i];
/* --------Tag rrsp logic{end}-------- */

end
endgenerate

/* --------arbiter logic{begin}-------- */
generate
if (`DMA_RD_CHNL_NUM == 2) begin:TAG_CHNL2

    assign arb_tag_din = tag_rrsp_valid[0] & tag_rrsp_ready[0] ? tag_rrsp_tag[1*`TAG_NUM_LOG-1:0*`TAG_NUM_LOG] :
                         tag_rrsp_valid[1] & tag_rrsp_ready[1] ? tag_rrsp_tag[2*`TAG_NUM_LOG-1:1*`TAG_NUM_LOG] : 0;
    
    assign arb_tag_wen = tag_rrsp_valid[0] & tag_rrsp_ready[0] |
                         tag_rrsp_valid[1] & tag_rrsp_ready[1];

end
else if (`DMA_RD_CHNL_NUM == 9) begin:TAG_CHNL9

    assign arb_tag_din = (tag_rrsp_valid[0] & tag_rrsp_ready[0]) ? tag_rrsp_tag[1*`TAG_NUM_LOG-1:0*`TAG_NUM_LOG] :
                         (tag_rrsp_valid[1] & tag_rrsp_ready[1]) ? tag_rrsp_tag[2*`TAG_NUM_LOG-1:1*`TAG_NUM_LOG] :
                         (tag_rrsp_valid[2] & tag_rrsp_ready[2]) ? tag_rrsp_tag[3*`TAG_NUM_LOG-1:2*`TAG_NUM_LOG] :
                         (tag_rrsp_valid[3] & tag_rrsp_ready[3]) ? tag_rrsp_tag[4*`TAG_NUM_LOG-1:3*`TAG_NUM_LOG] :
                         (tag_rrsp_valid[4] & tag_rrsp_ready[4]) ? tag_rrsp_tag[5*`TAG_NUM_LOG-1:4*`TAG_NUM_LOG] :
                         (tag_rrsp_valid[5] & tag_rrsp_ready[5]) ? tag_rrsp_tag[6*`TAG_NUM_LOG-1:5*`TAG_NUM_LOG] :
                         (tag_rrsp_valid[6] & tag_rrsp_ready[6]) ? tag_rrsp_tag[7*`TAG_NUM_LOG-1:6*`TAG_NUM_LOG] :
                         (tag_rrsp_valid[7] & tag_rrsp_ready[7]) ? tag_rrsp_tag[8*`TAG_NUM_LOG-1:7*`TAG_NUM_LOG] :
                         (tag_rrsp_valid[8] & tag_rrsp_ready[8]) ? tag_rrsp_tag[9*`TAG_NUM_LOG-1:8*`TAG_NUM_LOG] : 0;
    
    assign arb_tag_wen = (tag_rrsp_valid[0] & tag_rrsp_ready[0]) |
                         (tag_rrsp_valid[1] & tag_rrsp_ready[1]) |
                         (tag_rrsp_valid[2] & tag_rrsp_ready[2]) |
                         (tag_rrsp_valid[3] & tag_rrsp_ready[3]) |
                         (tag_rrsp_valid[4] & tag_rrsp_ready[4]) |
                         (tag_rrsp_valid[5] & tag_rrsp_ready[5]) |
                         (tag_rrsp_valid[6] & tag_rrsp_ready[6]) |
                         (tag_rrsp_valid[7] & tag_rrsp_ready[7]) |
                         (tag_rrsp_valid[8] & tag_rrsp_ready[8]);

end
else if (`DMA_RD_CHNL_NUM == 10) begin:TAG_CHNL10

    assign arb_tag_din = (tag_rrsp_valid[0] & tag_rrsp_ready[0]) ? tag_rrsp_tag[1*`TAG_NUM_LOG-1:0*`TAG_NUM_LOG] :
                         (tag_rrsp_valid[1] & tag_rrsp_ready[1]) ? tag_rrsp_tag[2*`TAG_NUM_LOG-1:1*`TAG_NUM_LOG] :
                         (tag_rrsp_valid[2] & tag_rrsp_ready[2]) ? tag_rrsp_tag[3*`TAG_NUM_LOG-1:2*`TAG_NUM_LOG] :
                         (tag_rrsp_valid[3] & tag_rrsp_ready[3]) ? tag_rrsp_tag[4*`TAG_NUM_LOG-1:3*`TAG_NUM_LOG] :
                         (tag_rrsp_valid[4] & tag_rrsp_ready[4]) ? tag_rrsp_tag[5*`TAG_NUM_LOG-1:4*`TAG_NUM_LOG] :
                         (tag_rrsp_valid[5] & tag_rrsp_ready[5]) ? tag_rrsp_tag[6*`TAG_NUM_LOG-1:5*`TAG_NUM_LOG] :
                         (tag_rrsp_valid[6] & tag_rrsp_ready[6]) ? tag_rrsp_tag[7*`TAG_NUM_LOG-1:6*`TAG_NUM_LOG] :
                         (tag_rrsp_valid[7] & tag_rrsp_ready[7]) ? tag_rrsp_tag[8*`TAG_NUM_LOG-1:7*`TAG_NUM_LOG] :
                         (tag_rrsp_valid[8] & tag_rrsp_ready[8]) ? tag_rrsp_tag[9*`TAG_NUM_LOG-1:8*`TAG_NUM_LOG] :
                         (tag_rrsp_valid[9] & tag_rrsp_ready[9]) ? tag_rrsp_tag[10*`TAG_NUM_LOG-1:9*`TAG_NUM_LOG] : 0;
    
    assign arb_tag_wen = (tag_rrsp_valid[0] & tag_rrsp_ready[0]) |
                         (tag_rrsp_valid[1] & tag_rrsp_ready[1]) |
                         (tag_rrsp_valid[2] & tag_rrsp_ready[2]) |
                         (tag_rrsp_valid[3] & tag_rrsp_ready[3]) |
                         (tag_rrsp_valid[4] & tag_rrsp_ready[4]) |
                         (tag_rrsp_valid[5] & tag_rrsp_ready[5]) |
                         (tag_rrsp_valid[6] & tag_rrsp_ready[6]) |
                         (tag_rrsp_valid[7] & tag_rrsp_ready[7]) |
                         (tag_rrsp_valid[8] & tag_rrsp_ready[8]) |
                         (tag_rrsp_valid[9] & tag_rrsp_ready[9]);

end
endgenerate
/* --------Tag rrsp logic{end}-------- */

endmodule
