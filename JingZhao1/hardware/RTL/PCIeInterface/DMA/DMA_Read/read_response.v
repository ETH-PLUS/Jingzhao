`timescale 1ns / 100ps
//*************************************************************************
// > File Name: read_response.v
// > Author   : Kangning
// > Date     : V1.0 -- 2020-08-27
// > Note     : read_response, used to get read response from PCIe, and 
// >               reorder the out-of-order packet.
// > V1.1 -- 2020-09-27: Add support for sub-request recombination 
// >                     and response recombination
// > V1.2 -- 2021-04-14: Reconstruct the file with the following structure.
// > |------------|------------------|------------|------------|
// > | input axis |   transfrom to   |    FSM     |  rsp data  |
// > |    data    |   dma_head type  | processing | reassemble |
// > |            | (dw dealignment) |  (reorder) |            |
// > |------------|------------------|------------|------------|
// > V1.3 -- 2022-06-29: Rebuild the read response channel.
// > |------------|------------------|------------|-------------|
// > | input axis |   transfrom to   |  push to   | ifc warpper |
// > |    data    |   dma_head type  |  reorder   | sub_req_rsp |
// > |            | (dw dealignment) |  buffer    |             |
// > |------------|------------------|------------|-------------|
//*************************************************************************

//`include "../lib/global_include_h.v"
//`include "../lib/dma_def_h.v"

module read_response #(
    
) (
    input  wire dma_clk, // i, 1
    input  wire rst_n  , // i, 1
    output wire init_done, // o, 1

    /* -------axis read response interface{begin}------- */
    /* AXI-Stream read response tuser, interact with read response distributor.
     * Only valid in first beat of a packet
     * | Reserved | REQ CPL |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 119:105  |   104   | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     */
    input  wire                     axis_rd_rsp_tvalid, // i, 1
    input  wire                     axis_rd_rsp_tlast , // i, 1
    input  wire [`DMA_DATA_W  -1:0] axis_rd_rsp_tdata , // i, `DMA_DATA_W
    input  wire [`AXIS_TUSER_W-1:0] axis_rd_rsp_tuser , // i, `AXIS_TUSER_W
    input  wire [`DMA_KEEP_W  -1:0] axis_rd_rsp_tkeep , // i, `DMA_KEEP_W
    output wire                     axis_rd_rsp_tready, // o, 1
    /* -------axis read response interface{end}------- */

    /* -------tag release{begin}------- */
    // Note that only one channel is allowed to assert at the same time
    output wire [`DMA_RD_CHNL_NUM * 1             - 1 : 0] tag_rrsp_ready, // o, 1
    input  wire [`DMA_RD_CHNL_NUM * 1             - 1 : 0] tag_rrsp_last , // i, 1
    input  wire [`DMA_RD_CHNL_NUM * `DW_LEN_WIDTH - 1 : 0] tag_rrsp_sz   , // i, `DW_LEN_WIDTH
    input  wire [`DMA_RD_CHNL_NUM * `TAG_MISC     - 1 : 0] tag_rrsp_misc , // i, `TAG_MISC ; Including addr && dw empty info
    input  wire [`DMA_RD_CHNL_NUM * `TAG_NUM_LOG  - 1 : 0] tag_rrsp_tag  , // i, `TAG_NUM_LOG
    input  wire [`DMA_RD_CHNL_NUM * 1             - 1 : 0] tag_rrsp_valid, // i, 1
    /* -------tag release{end}------- */

    /* ------- Read sub-req response{begin} ------- */
    /* dma_*_head
     * | emit | chnl_num | Reserved | address | Reserved | Byte length |
     * | 127  | 126:120  |  119:96  |  95:32  |  31:13   |    12:0     |
     */
    output wire                   sub_req_rsp_valid, // o, 1
    output wire                   sub_req_rsp_last , // o, 1
    output wire [`DMA_DATA_W-1:0] sub_req_rsp_data , // o, `DMA_DATA_W
    output wire [`DMA_HEAD_W-1:0] sub_req_rsp_head , // o, `DMA_HEAD_W
    input  wire                   sub_req_rsp_ready, // i, 1
    /* ------- Read sub-req response{end} ------- */

    /* --------chnl_stall{begin}-------- */
    input  wire [`DMA_RD_CHNL_NUM - 1 : 0] chnl_avail  // i, `DMA_RD_CHNL_NUM
    /* --------chnl_stall{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [`SRAM_RW_DATA_W*2-1:0] rw_data // i, `SRAM_RW_DATA_W*2
    ,input  wire [31:0] dbg_sel  // i, 32
    ,output wire [31:0] dbg_bus  // o, 32
    /* -------APB reated signal{end}------- */
`endif
);

/* -------tag release{begin}------- */
wire                     nxt_match_ready;
wire                     nxt_match_last ;
wire [`DW_LEN_WIDTH-1:0] nxt_match_sz   ;
wire [`TAG_MISC    -1:0] nxt_match_misc ;
wire [8            -1:0] nxt_match_chnl ;
wire [`TAG_NUM_LOG -1:0] nxt_match_tag  ;
wire                     nxt_match_valid;

wire is_begin_ft; // begin fetch pkt in reorder buffer and forward it to the concat module

// wire                     st_nxt_match_ready;
// wire                     st_nxt_match_last ;
// wire [`DW_LEN_WIDTH-1:0] st_nxt_match_sz   ;
// wire [8            -1:0] st_nxt_match_chnl ;
// wire [`TAG_NUM_LOG -1:0] st_nxt_match_tag  ;
// wire                     st_nxt_match_valid;
/* -------tag release{end}------- */

/* ------- Related to Reorder Buffer{begin} ------- */
wire                     st_rd_rsp_wen ;
wire                     st_rd_rsp_last;
wire                     st_rd_rsp_eop ;
wire [`DMA_HEAD_W  -1:0] st_rd_rsp_head;
wire [`DW_LEN_WIDTH-1:0] st_rd_rsp_dlen;
wire [`TAG_NUM_LOG -1:0] st_rd_rsp_tag ;
wire [`DMA_DATA_W  -1:0] st_rd_rsp_data;
wire                     st_rd_rsp_rdy ;

wire                    ft_rd_rsp_ren ;
wire [`TAG_NUM_LOG-1:0] ft_rd_rsp_tag ;
wire [`DMA_HEAD_W -1:0] ft_rd_rsp_head;
wire [`DMA_DATA_W -1:0] ft_rd_rsp_data;
wire                    ft_rd_rsp_last;
wire                    ft_rd_rsp_vld ;
/* ------- Related to Reorder Buffer{end} ------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire [32-1:0] dbg_sel_rd_rsp_top, dbg_sel_rsp_dealign, dbg_sel_reorder_buf, dbg_sel_tag_matching, dbg_sel_wrapper;
wire [32-1:0] dbg_bus_rd_rsp_top, dbg_bus_rsp_dealign, dbg_bus_reorder_buf, dbg_bus_tag_matching, dbg_bus_wrapper;

wire [`RD_RSP_TOP_SIGNAL_W  -1:0] dbg_signal_rd_rsp_top;
wire [`RSP_DEALIGN_SIGNAL_W -1:0] dbg_signal_rsp_dealign;
/* -------APB reated signal{end}------- */
`endif

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign dbg_bus = (`RD_RSP_TOP_DBG_B   <= dbg_sel && dbg_sel < `RSP_DEALIGN_DBG_B ) ? dbg_bus_rd_rsp_top   : 
                 (`RSP_DEALIGN_DBG_B  <= dbg_sel && dbg_sel < `REORDER_BUF_DBG_B ) ? dbg_bus_rsp_dealign  : 
                 (`REORDER_BUF_DBG_B  <= dbg_sel && dbg_sel < `TAG_MATCHING_DBG_B) ? dbg_bus_reorder_buf  : 
                 (`TAG_MATCHING_DBG_B <= dbg_sel && dbg_sel < `WRAPPER_DBG_B     ) ? dbg_bus_tag_matching : 
                 (`WRAPPER_DBG_B      <= dbg_sel && dbg_sel < `RD_RSP_DBG_SIZE   ) ? dbg_bus_wrapper      : 32'd0;

assign dbg_sel_rd_rsp_top   = (`RD_RSP_TOP_DBG_B   <= dbg_sel && dbg_sel < `RSP_DEALIGN_DBG_B ) ? (dbg_sel - `RD_RSP_TOP_DBG_B  ) : 32'd0;
assign dbg_sel_rsp_dealign  = (`RSP_DEALIGN_DBG_B  <= dbg_sel && dbg_sel < `REORDER_BUF_DBG_B ) ? (dbg_sel - `RSP_DEALIGN_DBG_B ) : 32'd0;
assign dbg_sel_reorder_buf  = (`REORDER_BUF_DBG_B  <= dbg_sel && dbg_sel < `TAG_MATCHING_DBG_B) ? (dbg_sel - `REORDER_BUF_DBG_B ) : 32'd0;
assign dbg_sel_tag_matching = (`TAG_MATCHING_DBG_B <= dbg_sel && dbg_sel < `WRAPPER_DBG_B     ) ? (dbg_sel - `TAG_MATCHING_DBG_B) : 32'd0;
assign dbg_sel_wrapper      = (`WRAPPER_DBG_B      <= dbg_sel && dbg_sel < `RD_RSP_DBG_SIZE   ) ? (dbg_sel - `WRAPPER_DBG_B     ) : 32'd0;

// Debug bus for read rsp top
assign dbg_bus_rd_rsp_top = dbg_signal_rd_rsp_top >> {dbg_sel_rd_rsp_top, 5'd0};

// Debug bus for rrsp dealign
assign dbg_bus_rsp_dealign = dbg_signal_rsp_dealign >> {dbg_sel_rsp_dealign, 5'd0};

assign dbg_signal_rd_rsp_top = { // 827
    nxt_match_ready, nxt_match_last, nxt_match_sz, nxt_match_misc, nxt_match_chnl, nxt_match_tag  , nxt_match_valid, // 28
    is_begin_ft, // 1
    st_rd_rsp_wen , st_rd_rsp_last, st_rd_rsp_eop , st_rd_rsp_head, st_rd_rsp_dlen, st_rd_rsp_tag , st_rd_rsp_data, st_rd_rsp_rdy, // 405
    ft_rd_rsp_ren , ft_rd_rsp_tag, ft_rd_rsp_head, ft_rd_rsp_data, ft_rd_rsp_last, ft_rd_rsp_vld // 393
};
/* -------APB reated signal{end}------- */
`endif


/* -------Double word dealignment{begin}------- */
rrsp_dealign #(
    
) rrsp_dealign (
    .dma_clk ( dma_clk ), // i, 1
    .rst_n   ( rst_n   ), // i, 1


    /* -------axis read response interface{begin}------- */
    /* AXI-Stream read response tuser, interact with read response distributor.
     * Only valid in first beat of a packet
     * | Reserved | REQ CPL |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 119:105  |   104   | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     */
    .axis_rd_rsp_tvalid ( axis_rd_rsp_tvalid ), // i, 1
    .axis_rd_rsp_tlast  ( axis_rd_rsp_tlast  ), // i, 1
    .axis_rd_rsp_tdata  ( axis_rd_rsp_tdata  ), // i, `DMA_DATA_W
    .axis_rd_rsp_tuser  ( axis_rd_rsp_tuser  ), // i, `AXIS_TUSER_W
    .axis_rd_rsp_tkeep  ( axis_rd_rsp_tkeep  ), // i, `DMA_KEEP_W
    .axis_rd_rsp_tready ( axis_rd_rsp_tready ), // o, 1
    /* -------axis read response interface{end}------- */


    /* ------- Read Response store to Reorder Buffer{begin} ------- */
    /* *_head (interact with <reorder_buffer> module, valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    .rd_rsp_dealign_valid ( st_rd_rsp_wen   ), // o, 1
    .rd_rsp_dealign_last  ( st_rd_rsp_last  ), // o, 1 ; assert in every last beat of sub-rsp pkt
    .rd_rsp_dealign_eop   ( st_rd_rsp_eop   ), // o, 1 ; assert when this is the last sub-rsp pkt
    .rd_rsp_dealign_dlen  ( st_rd_rsp_dlen  ), // o, `DW_LEN_WIDTH ; part of head field in "store channel"
    .rd_rsp_dealign_tag   ( st_rd_rsp_tag   ), // o, `TAG_NUM_LOG  ; part of head field in "store channel"
    .rd_rsp_dealign_head  ( st_rd_rsp_head  ), // o, `DMA_HEAD_W
    .rd_rsp_dealign_data  ( st_rd_rsp_data  ), // o, `DMA_DATA_W
    .rd_rsp_dealign_ready ( st_rd_rsp_rdy   )  // i, 1
    /* ------- Read Response store to Reorder Buffer{end} ------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_signal ( dbg_signal_rsp_dealign ) // o, `RSP_DEALIGN_SIGNAL_W  
    /* -------APB reated signal{end}------- */
`endif
);
/* -------Double word dealignment{end}------- */

/* -------Reorder Buffer{begin}------- */
reorder_buf #(
    
) reorder_buffer (
    .dma_clk      ( dma_clk   ), // i, 1
    .rst_n        ( rst_n     ), // i, 1
    .init_done    ( init_done ), // o, 1

    /* ------- Read Response input{begin} ------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    .st_rd_rsp_wen   ( st_rd_rsp_wen   ), // i, 1
    .st_rd_rsp_last  ( st_rd_rsp_last  ), // i, 1 ; assert in every last beat of sub-rsp pkt
    .st_rd_rsp_eop   ( st_rd_rsp_eop   ), // i, 1 ; assert when this is the last sub-rsp pkt
    .st_rd_rsp_tag   ( st_rd_rsp_tag   ), // i, `TAG_NUM_LOG
    .st_rd_rsp_head  ( st_rd_rsp_head  ), // i, `DMA_HEAD_W
    .st_rd_rsp_data  ( st_rd_rsp_data  ), // i, `DMA_DATA_W
    .st_rd_rsp_rdy   ( st_rd_rsp_rdy   ), // o, 1
    /* ------- Read Response input{end} ------- */


    /* ------- Read Response output{begin} ------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    .ft_rd_rsp_ren    ( ft_rd_rsp_ren   ), // i, 1
    .ft_rd_rsp_tag    ( ft_rd_rsp_tag   ), // i, `TAG_NUM_LOG
    .ft_rd_rsp_head   ( ft_rd_rsp_head  ), // o, `DMA_HEAD_W
    .ft_rd_rsp_data   ( ft_rd_rsp_data  ), // o, `DMA_DATA_W
    .ft_rd_rsp_last   ( ft_rd_rsp_last  ), // o, 1
    .ft_rd_rsp_vld    ( ft_rd_rsp_vld   )  // o, 1
    /* ------- Read Response output{end} ------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.rw_data    ( rw_data ) // i, `SRAM_RW_DATA_W*2
    ,.dbg_sel    ( dbg_sel_reorder_buf )  // i, 32
    ,.dbg_bus    ( dbg_bus_reorder_buf )  // o, 32
    /* -------APB reated signal{end}------- */
`endif
);
/* -------Reorder Buffer{end}------- */

assign is_begin_ft       = ft_rd_rsp_ren;
tag_matching #(

) tag_matching (

    .dma_clk      ( dma_clk   ), // i, 1
    .rst_n        ( rst_n     ), // i, 1

    /* -------tag release{begin}------- */
    // Note that only one channel is allowed to assert at the same time
    .tag_rrsp_ready ( tag_rrsp_ready ), // o, `DMA_RD_CHNL_NUM * 1
    .tag_rrsp_last  ( tag_rrsp_last  ), // i, `DMA_RD_CHNL_NUM * 1
    .tag_rrsp_sz    ( tag_rrsp_sz    ), // i, `DMA_RD_CHNL_NUM * `DW_LEN_WIDTH
    .tag_rrsp_misc  ( tag_rrsp_misc  ), // i, `DMA_RD_CHNL_NUM * `TAG_MISC ; Including addr && dw empty info
    .tag_rrsp_tag   ( tag_rrsp_tag   ), // i, `DMA_RD_CHNL_NUM * `TAG_NUM_LOG
    .tag_rrsp_valid ( tag_rrsp_valid ), // i, `DMA_RD_CHNL_NUM * 1
    /* -------tag release{end}------- */

    /* ------- Store input{begin} ------- */
    .st_rd_rsp_wen   ( st_rd_rsp_wen   ), // i, 1
    .st_rd_rsp_last  ( st_rd_rsp_last  ), // i, 1 ; assert in every last beat of sub-rsp pkt
    .st_rd_rsp_dlen  ( st_rd_rsp_dlen  ), // i, `DW_LEN_WIDTH ; part of head field in "store channel"
    .st_rd_rsp_tag   ( st_rd_rsp_tag   ), // i, `TAG_NUM_LOG  ; part of head field in "store channel"
    .st_rd_rsp_rdy   ( st_rd_rsp_rdy   ), // i, 1
    /* ------- Store input{end} ------- */

    /* --------chnl_stall{begin}-------- */
    .chnl_avail ( chnl_avail | {`DMA_RD_CHNL_NUM{is_begin_ft}} ), // i, `DMA_RD_CHNL_NUM
    /* --------chnl_stall{end}-------- */

    /* -------tag release{begin}------- */
    .nxt_match_ready ( nxt_match_ready ), // i, 1
    .nxt_match_last  ( nxt_match_last  ), // o, 1
    .nxt_match_sz    ( nxt_match_sz    ), // o, `DW_LEN_WIDTH
    .nxt_match_misc  ( nxt_match_misc  ), // o, `TAG_MISC ; Including addr && dw empty info
    .nxt_match_chnl  ( nxt_match_chnl  ), // o, 8
    .nxt_match_tag   ( nxt_match_tag   ), // o, `TAG_NUM_LOG
    .nxt_match_valid ( nxt_match_valid )  // o, 1
    /* -------tag release{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_sel    ( dbg_sel_tag_matching )  // i, 32
    ,.dbg_bus    ( dbg_bus_tag_matching )  // o, 32
    /* -------APB reated signal{end}------- */
`endif
);

sub_req_rsp_wrapper #(
    
) sub_req_rsp_wrapper (
    .dma_clk ( dma_clk ), // i, 1
    .rst_n   ( rst_n   ), // i, 1

    /* ------- Read Response output{begin} ------- */
    /* *_head (interact with <read_response> module, valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    .ft_rd_rsp_ren   ( ft_rd_rsp_ren  ), // o, 1
    .ft_rd_rsp_tag   ( ft_rd_rsp_tag  ), // o, `TAG_NUM_LOG
    .ft_rd_rsp_head  ( ft_rd_rsp_head ), // i, `DMA_HEAD_W
    .ft_rd_rsp_data  ( ft_rd_rsp_data ), // i, `DMA_DATA_W
    .ft_rd_rsp_last  ( ft_rd_rsp_last ), // i, 1
    .ft_rd_rsp_vld   ( ft_rd_rsp_vld  ), // i, 1
    /* ------- Read Response output{end} ------- */

    /* -------tag release{begin}------- */
    .nxt_match_ready ( nxt_match_ready ), // o, 1
    .nxt_match_last  ( nxt_match_last  ), // i, 1
    .nxt_match_sz    ( nxt_match_sz    ), // i, `DW_LEN_WIDTH
    .nxt_match_misc  ( nxt_match_misc  ), // i, `TAG_MISC ; Including addr && dw empty info
    .nxt_match_chnl  ( nxt_match_chnl  ), // i, 8
    .nxt_match_tag   ( nxt_match_tag   ), // i, `TAG_NUM_LOG
    .nxt_match_valid ( nxt_match_valid ), // i, 1
    /* -------tag release{end}------- */

    /* ------- Read sub-req response{begin} ------- */
    /* dma_*_head
     * | emit | chnl_num | Reserved | address | Reserved | Byte length |
     * | 127  | 126:120  |  119:96  |  95:32  |  31:13   |    12:0     |
     */
    .st_sub_req_rsp_valid ( sub_req_rsp_valid ), // o, 1
    .st_sub_req_rsp_last  ( sub_req_rsp_last  ), // o, 1
    .st_sub_req_rsp_data  ( sub_req_rsp_data  ), // o, `DMA_DATA_W
    .st_sub_req_rsp_head  ( sub_req_rsp_head  ), // o, `DMA_HEAD_W
    .st_sub_req_rsp_ready ( sub_req_rsp_ready )  // i, 1
    /* ------- Read sub-req response{end} ------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_sel    ( dbg_sel_wrapper )  // i, 32
    ,.dbg_bus    ( dbg_bus_wrapper )  // o, 32
    /* -------APB reated signal{end}------- */
`endif
);

endmodule
