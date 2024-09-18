`timescale 1ns / 100ps
//*************************************************************************
// > File Name: reorder_buf.v
// > Author   : Kangning
// > Date     : 2023-02-27
// > Note     : reorder_buf, which acts as a reorder buffer
//*************************************************************************

//`include "../lib/dma_def_h.v"

module reorder_buf #(
    
) (
    input  wire       dma_clk  , // i, 1
    input  wire       rst_n    , // i, 1
    output wire       init_done, // o, 1

    /* ------- Reorder buf input{begin} ------- */
    /* *_head (interact with <read_response> module, valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    input  wire                    st_rd_rsp_wen , // i, 1
    input  wire                    st_rd_rsp_last, // i, 1 ; assert in every last beat of sub-rsp pkt
    input  wire                    st_rd_rsp_eop , // i, 1 ; assert when this is the last sub-rsp pkt
    input  wire [`TAG_NUM_LOG-1:0] st_rd_rsp_tag , // i, `TAG_NUM_LOG
    input  wire [`DMA_HEAD_W -1:0] st_rd_rsp_head, // i, `DMA_HEAD_W
    input  wire [`DMA_DATA_W -1:0] st_rd_rsp_data, // i, `DMA_DATA_W
    output wire                    st_rd_rsp_rdy , // o, 1
    /* ------- Reorder buf input{end} ------- */


    /* ------- Reorder buf output{begin} ------- */
    /* *_head (interact with <read_response> module, valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    input   wire                    ft_rd_rsp_ren , // i, 1
    input   wire [`TAG_NUM_LOG-1:0] ft_rd_rsp_tag , // i, `TAG_NUM_LOG
    output  wire [`DMA_HEAD_W -1:0] ft_rd_rsp_head, // o, `DMA_HEAD_W
    output  wire [`DMA_DATA_W -1:0] ft_rd_rsp_data, // o, `DMA_DATA_W
    output  wire                    ft_rd_rsp_last, // o, 1
    output  wire                    ft_rd_rsp_vld   // o, 1
    /* ------- Reorder buf output{end} ------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [`SRAM_RW_DATA_W*2-1:0] rw_data // i, `SRAM_RW_DATA_W*2
    ,input  wire [31:0] dbg_sel  // i, 32
    ,output wire [31:0] dbg_bus  // o, 32
    /* -------APB reated signal{end}------- */
`endif
);

/* ------- Reorder buf input{begin} ------- */
/* *_head (interact with <read_response> module, valid only in first beat of a packet
 * | Reserved | address | Reserved | Byte length |
 * |  127:96  |  95:32  |  31:13   |    12:0     |
 */
wire                      st_store_rd_rsp_wen ;
wire                      st_store_rd_rsp_last;
wire                      st_store_rd_rsp_eop ;
wire [`DMA_LEN_WIDTH-1:0] st_store_rd_rsp_blen;
wire [`TAG_NUM_LOG  -1:0] st_store_rd_rsp_tag ;
wire [`DMA_HEAD_W   -1:0] st_store_rd_rsp_head;
wire [`DMA_DATA_W   -1:0] st_store_rd_rsp_data;
wire                      st_store_rd_rsp_rdy ;
/* ------- Reorder buf input{end} ------- */

wire [`DMA_LEN_WIDTH -1:0] sub_blen_total ;
wire [`DMA_LEN_WIDTH -1:0] sub_blen_left  ;
reg  [`DMA_LEN_WIDTH -1:0] store_trans_cnt;


wire                    store_wen ;
wire [`TAG_NUM_LOG-1:0] store_tag ;
wire                    store_last;
wire [`DMA_DATA_W -1:0] store_data;
wire                    store_rdy;

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire [`SRAM_RW_DATA_W-1:0] concat_rw_data;
wire [`SRAM_RW_DATA_W-1:0] tag_buf_rw_data;

wire [`SUB_RSP_CONCAT_SIGNAL_W-1:0] dbg_signal_sub_rsp_concat;
wire [`TAG_BUF_SIGNAL_W       -1:0] dbg_signal_tag_buf;
wire [`REBUF_TOP_SIGNAL_W     -1:0] dbg_signal_rebuf_top;
/* -------APB reated signal{end}------- */
`endif

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign {tag_buf_rw_data, concat_rw_data} = rw_data;

assign dbg_bus = {dbg_signal_rebuf_top, dbg_signal_sub_rsp_concat, dbg_signal_tag_buf} >> {dbg_sel, 5'd0};

assign dbg_signal_rebuf_top = { // 711
    st_store_rd_rsp_wen , st_store_rd_rsp_last, st_store_rd_rsp_eop , st_store_rd_rsp_blen, 
    st_store_rd_rsp_tag , st_store_rd_rsp_head, st_store_rd_rsp_data, st_store_rd_rsp_rdy, // 407

    sub_blen_total , sub_blen_left  , store_trans_cnt, // 39

    store_wen , store_tag , store_last, store_data, store_rdy // 265
};
/* -------APB reated signal{end}------- */
`endif

/* -------Stream reg for st channel signal{begin}-------- */
st_reg #(
    .TUSER_WIDTH ( `TAG_NUM_LOG + `DMA_HEAD_W ),
    .TDATA_WIDTH ( 1 + `DMA_DATA_W            )
) in_st_reg (
    .clk   ( dma_clk ), // i, 1
    .rst_n ( rst_n   ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( st_rd_rsp_wen   ), // i, 1
    .axis_tlast  ( st_rd_rsp_last  ), // i, 1
    .axis_tuser  ( {st_rd_rsp_tag, st_rd_rsp_head} ), // i, TUSER_WIDTH
    .axis_tdata  ( {st_rd_rsp_eop, st_rd_rsp_data} ), // i, TDATA_WIDTH
    .axis_tready ( st_rd_rsp_rdy ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output inteface{begin}------- */
    .axis_reg_tvalid ( st_store_rd_rsp_wen  ), // o, 1
    .axis_reg_tlast  ( st_store_rd_rsp_last ), // o, 1
    .axis_reg_tuser  ( {st_store_rd_rsp_tag, st_store_rd_rsp_head} ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( {st_store_rd_rsp_eop, st_store_rd_rsp_data} ), // o, TDATA_WIDTH
    .axis_reg_tready ( st_store_rd_rsp_rdy )  // i, 1
    /* -------output inteface{end}------- */
);
/* -------Stream reg for st channel signal{end}-------- */

/* --------Generate byte length in every cycle{begin}-------- */
assign st_store_rd_rsp_blen = (sub_blen_left >= `DMA_W_BCNT) ? `DMA_W_BCNT : sub_blen_left;
assign sub_blen_left        = sub_blen_total - store_trans_cnt;
assign sub_blen_total       = st_store_rd_rsp_head[12:0];
always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        store_trans_cnt <= `TD 0;
    end
    else if (st_store_rd_rsp_wen & st_store_rd_rsp_rdy & st_store_rd_rsp_last) begin
        store_trans_cnt <= `TD 0;
    end
    else if (st_store_rd_rsp_wen & st_store_rd_rsp_rdy) begin
        store_trans_cnt <= `TD store_trans_cnt + `DMA_W_BCNT;
    end
end
/* --------Generate byte length in every cycle{end}-------- */

/* --------concat sub-rsp data{begin}-------- */
sub_rsp_concat sub_rsp_concat (
    .dma_clk      ( dma_clk   ), // i, 1
    .rst_n        ( rst_n     ), // i, 1
    .init_done    ( init_done ), // o, 1

    /* ------- Store Interface input{begin} ------- */
    .st_rd_rsp_valid ( st_store_rd_rsp_wen   ), // i, 1
    .st_rd_rsp_last  ( st_store_rd_rsp_last  ), // i, 1 ; assert in every last beat of sub-rsp pkt
    .st_rd_rsp_eop   ( st_store_rd_rsp_eop   ), // i, 1 ; assert when this is the last sub-rsp pkt
    .st_rd_rsp_tag   ( st_store_rd_rsp_tag   ), // i, `TAG_NUM_LOG
    .st_rd_rsp_blen  ( st_store_rd_rsp_blen  ), // i, `DMA_LEN_WIDTH
    .st_rd_rsp_data  ( st_store_rd_rsp_data  ), // i, `DMA_DATA_W
    .st_rd_rsp_ready ( st_store_rd_rsp_rdy   ), // o, 1
    /* ------- Store Interface input{end} ------- */

    /* --------Store Interface Output{begin}-------- */
    .store_fifo_wen  ( store_wen  ), // o, 1
    .store_fifo_tag  ( store_tag  ), // o, `TAG_NUM_LOG
    .store_fifo_last ( store_last ), // o, 1 ; assert when this is the last sub-rsp pkt
    .store_fifo_data ( store_data ), // o, `DMA_DATA_W
    .store_fifo_rdy  ( store_rdy  )  // i, 1
    /* --------Store Interface Output{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.rw_data    ( concat_rw_data ) // i, `SRAM_RW_DATA_W
    ,.dbg_signal ( dbg_signal_sub_rsp_concat ) // o, `DATA_FIFO_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);
/* --------concat sub-rsp data{end}-------- */


/* -------data stroage{begin}------- */
tag_buf tag_buf (
    .dma_clk      ( dma_clk   ), // i, 1
    .rst_n        ( rst_n     ), // i, 1

    /* -------- Store related channel {begin}-------- */
    .store_wen  ( store_wen  ), // i, 1
    .store_tag  ( store_tag  ), // i, `TAG_NUM_LOG
    .store_last ( store_last ), // i, 1 ; assert when this is the last sub-rsp pkt
    .store_data ( store_data ), // i, `DMA_DATA_W
    .store_rdy  ( store_rdy  ), // o, 1
    /* -------- Store related channel {end}-------- */

    /* -------- Fetch related channel {begin}-------- */
    .fetch_ren  ( ft_rd_rsp_ren  ), // i, 1
    .fetch_tag  ( ft_rd_rsp_tag  ), // i, `TAG_NUM_LOG
    .fetch_last ( ft_rd_rsp_last ), // o, 1 ; assert when this is the last sub-rsp pkt
    .fetch_data ( ft_rd_rsp_data ), // o, `DMA_DATA_W
    .fetch_vld  ( ft_rd_rsp_vld  )  // o, 1
    /* -------- Fetch related channel {end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.rw_data    ( tag_buf_rw_data ) // i, `SRAM_RW_DATA_W
    ,.dbg_signal ( dbg_signal_tag_buf ) // o, `DATA_FIFO_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);
/* -------data stroage{end}------- */

assign ft_rd_rsp_head = {`DMA_HEAD_W{1'd0}};

endmodule