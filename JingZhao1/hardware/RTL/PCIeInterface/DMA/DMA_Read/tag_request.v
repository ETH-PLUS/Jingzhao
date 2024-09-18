`timescale 1ns / 100ps
//*************************************************************************
// > File Name: tag_request.v
// > Author   : Kangning
// > Date     : 2022-11-07
// > Note     : tag_request, add tag to the read request.
//*************************************************************************

module tag_request #(
    
) (
    input wire dma_clk, // i, 1
    input wire rst_n  , // i, 1

    /* ------- Connect to rd_req_arbiter module{begin} ------- */
    /* AXI-Stream read request tuser, every read request contains only one beat.
     * | chnl_num | Reserved | REQ_TYPE |Tag(inv)| address | Reserved | DW length | first BE | last BE |
     * | 127:120  | 119:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     */
    input  wire                     axis_rreq_tvalid, // i, 1
    input  wire                     axis_rreq_tlast , // i, 1
    input  wire [`DMA_DATA_W  -1:0] axis_rreq_tdata , // i, `DMA_DATA_W
    input  wire [`AXIS_TUSER_W-1:0] axis_rreq_tuser , // i, `AXIS_TUSER_W
    input  wire [`DMA_KEEP_W  -1:0] axis_rreq_tkeep , // i, `DMA_KEEP_W
    output wire                     axis_rreq_tready, // o, 1
    /* ------- Connect to rd_req_arbiter module{end} ------- */

    /* -------tag request{begin}------- */
    output wire                     tag_rreq_ready, // o, 1
    output wire                     tag_rreq_last , // o, 1  ; Indicate the last sub-req for rd req
    output wire [`DW_LEN_WIDTH-1:0] tag_rreq_sz   , // o, `DW_LEN_WIDTH ; Request size(in dw unit) of this tag
    output wire [8            -1:0] tag_rreq_chnl , // o, 8 ; channel number for this request
    output wire [`TAG_MISC    -1:0] tag_rreq_misc , // o, `TAG_MISC ; Including addr && dw empty info
    input  wire [`TAG_NUM_LOG -1:0] tag_rreq_tag  , // i, `TAG_NUM_LOG
    input  wire                     tag_rreq_valid, // i, 1
    /* -------tag request{end}------- */

    /* -------axis read request interface{begin}------- */
    /* AXI-Stream read request tuser, interact with read request arbiter.
     * Only valid in first beat of a packet
     * | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     */
    output wire                     axis_rreq_tag_tvalid, // o, 1
    output wire                     axis_rreq_tag_tlast , // o, 1
    output wire [`DMA_DATA_W  -1:0] axis_rreq_tag_tdata , // o, `DMA_DATA_W
    output wire [`AXIS_TUSER_W-1:0] axis_rreq_tag_tuser , // o, `AXIS_TUSER_W
    output wire [`DMA_KEEP_W  -1:0] axis_rreq_tag_tkeep , // o, `DMA_KEEP_W
    input  wire                     axis_rreq_tag_tready  // i, 1
    /* -------axis read request interface{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,output wire [`TAG_REQ_SIGNAL_W-1:0] dbg_signal  // o, `TAG_REQ_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

/* -------State relevant in FSM{begin}------- */
wire                     rreq_taged_tvalid;
wire                     rreq_taged_tlast ;
wire [`AXIS_TUSER_W-1:0] rreq_taged_tuser ;
wire [`DMA_DATA_W  -1:0] rreq_taged_tdata ;
wire                     rreq_taged_tready;
/* -------State relevant in FSM{end}------- */

/* -------Head decode{begin}------- */
wire [8            -1:0] chnl_num    ;
wire                     last_sub_req;
wire [`DW_LEN_WIDTH-1:0] dw_len      ;
wire [4            -1:0] req_type    ;
wire [`DMA_ADDR_WIDTH-1:0] addr_align;

wire [`FIRST_BE_WIDTH-1:0] first_be   ;
wire [`LAST_BE_WIDTH -1:0] last_be    ;
wire [1:0]                first_empty ; // Number of invalid bytes in first Double word
wire [1:0]                last_empty  ; // Number of invalid bytes in last  Double word

wire [`DMA_ADDR_WIDTH-1:0] addr_unalign;
wire [5              -1:0] empty       ;    
/* -------Head decode{end}------- */

/* -------------------------------------------------------------------------------------------------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign dbg_signal = { // 556
    rreq_taged_tvalid, rreq_taged_tlast, rreq_taged_tuser, rreq_taged_tdata, rreq_taged_tready, // 387
    chnl_num, last_sub_req, dw_len, req_type, addr_align,  // 88
    first_be, last_be, first_empty, last_empty, // 12
    addr_unalign, empty // 69
/* -------Head decode{end}------- */
};
/* -------APB reated signal{end}------- */
`endif

/* -------Head decode{begin}------- */
/* AXI-Stream read request tuser, every read request contains only one beat.
 * | chnl_num | Reserved | REQ_TYPE |Tag(inv)| address | Reserved | DW length | first BE | last BE |
 * | 127:120  | 119:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
 */
assign chnl_num     = axis_rreq_tuser[127:120];
assign last_sub_req = axis_rreq_tuser[119];
assign dw_len       = axis_rreq_tuser[18 :8  ];
assign req_type     = axis_rreq_tuser[107:104];
assign addr_align   = axis_rreq_tuser[95:32];
assign first_be     = axis_rreq_tuser[7:4];
assign last_be      = axis_rreq_tuser[3:0];

assign first_empty  = first_be[0] ? 2'd0 :
                      first_be[1] ? 2'd1 :
                      first_be[2] ? 2'd2 :
                      first_be[3] ? 2'd3 : 
                      2'd0; // unlikely
assign last_empty   = (dw_len == 1) ?
                      (first_be[3] ? 2'd0 :
                       first_be[2] ? 2'd1 :
                       first_be[1] ? 2'd2 : 2'd3) :
                      ({2{(last_be  == 4'b1111)}} & 2'd0 |
                       {2{(last_be  == 4'b0001)}} & 2'd3 |
                       {2{(last_be  == 4'b0011)}} & 2'd2 |
                       {2{(last_be  == 4'b0111)}} & 2'd1);

assign addr_unalign = {addr_align[`DMA_ADDR_WIDTH-1:2], first_empty};
assign empty = first_empty + last_empty;
// assign byte_len     = (dw_len << 2) - first_empty - last_empty;
/* -------Head decode{end}------- */

/* --------input request{begin}-------- */
assign axis_rreq_tready = tag_rreq_valid & rreq_taged_tready;
/* --------input request{end}-------- */

/* --------Tag request{begin}-------- */
assign tag_rreq_ready = axis_rreq_tvalid & rreq_taged_tready;
assign tag_rreq_last  = last_sub_req;
assign tag_rreq_sz    = dw_len      ;
assign tag_rreq_chnl  = chnl_num    ;
assign tag_rreq_misc  = {addr_unalign[6:0], empty};
/* --------Tag request{end}-------- */

/* --------read request output {begin}-------- */
/* AXI-Stream read request tuser, every read request contains only one beat.
 * | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
 * | 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
 */
assign rreq_taged_tvalid = tag_rreq_valid & axis_rreq_tvalid;
assign rreq_taged_tlast  = 1'd1;
assign rreq_taged_tdata  = {`DMA_DATA_W{1'd0}};
assign rreq_taged_tuser  = {20'd0, req_type, {`TAG_EMPTY+`TAG_WIDTH-`TAG_NUM_LOG{1'd0}}, tag_rreq_tag, axis_rreq_tuser[95:0]};
/* --------read request output {end}-------- */


/* -------Read Request FIFO{begin}------- */
st_reg #(
    .TUSER_WIDTH ( `AXIS_TUSER_W ),
    .TDATA_WIDTH ( `DMA_DATA_W   )
) st_rd_req (
    .clk   ( dma_clk ), // i, 1
    .rst_n ( rst_n   ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( rreq_taged_tvalid ), // i, 1
    .axis_tlast  ( rreq_taged_tlast  ), // i, 1
    .axis_tuser  ( rreq_taged_tuser  ), // i, TUSER_WIDTH
    .axis_tdata  ( rreq_taged_tdata  ), // i, TDATA_WIDTH
    .axis_tready ( rreq_taged_tready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .axis_reg_tvalid ( axis_rreq_tag_tvalid ), // o, 1
    .axis_reg_tlast  ( axis_rreq_tag_tlast  ), // o, 1
    .axis_reg_tuser  ( axis_rreq_tag_tuser  ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( axis_rreq_tag_tdata  ), // o, TDATA_WIDTH
    .axis_reg_tready ( axis_rreq_tag_tready )  // i, 1
    /* -------output in_reg inteface{end}------- */
);
assign axis_rreq_tag_tkeep = {`DMA_KEEP_W{1'd0}};
/* -------Read Request FIFO{end}------- */

endmodule
