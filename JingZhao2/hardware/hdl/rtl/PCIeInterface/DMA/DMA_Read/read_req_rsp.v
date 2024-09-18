`timescale 1ns / 100ps
//*************************************************************************
// > File Name: read_req_rsp.v
// > Author   : Kangning
// > Date     : 2020-08-26
// > Note     : read_req_rsp, used to process read request and read response.
//*************************************************************************

//`include "../lib/dma_def_h.v"

module read_req_rsp #(
    parameter  [8 * `DMA_RD_CHNL_NUM - 1 : 0] CHNL_NUM_TAB = {
		8'd9,
        8'd8,
        8'd7,
        8'd6,
        8'd5,
        8'd4,
        8'd3,
        8'd2,
        8'd1,
        8'd0
    }
) (
    input  wire                        dma_clk ,
    input  wire                        rst_n    ,
    output wire                        init_done, // o, 1


    /* ------- Read Request from RDMA{begin}------- */
    /* dma_*_head, valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    input  wire [`DMA_RD_CHNL_NUM * 1          -1 : 0] dma_rd_req_valid, // i, `DMA_RD_CHNL_NUM * 1
    input  wire [`DMA_RD_CHNL_NUM * 1          -1 : 0] dma_rd_req_last , // i, `DMA_RD_CHNL_NUM * 1
    input  wire [`DMA_RD_CHNL_NUM * `DMA_DATA_W-1 : 0] dma_rd_req_data , // i, `DMA_RD_CHNL_NUM * `DMA_DATA_W
    input  wire [`DMA_RD_CHNL_NUM * `DMA_HEAD_W-1 : 0] dma_rd_req_head , // i, `DMA_RD_CHNL_NUM * `DMA_HEAD_W
    output wire [`DMA_RD_CHNL_NUM * 1          -1 : 0] dma_rd_req_ready, // o, `DMA_RD_CHNL_NUM * 1
    /* ------- Read Request from RDMA{end}------- */

    /* ------- Read Response to RDMA{begin} ------- */
    /* dma_*_head , valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    output  wire [`DMA_RD_CHNL_NUM * 1          -1 : 0] dma_rd_rsp_valid, // o, `DMA_RD_CHNL_NUM * 1
    output  wire [`DMA_RD_CHNL_NUM * 1          -1 : 0] dma_rd_rsp_last , // o, `DMA_RD_CHNL_NUM * 1
    output  wire [`DMA_RD_CHNL_NUM * `DMA_DATA_W-1 : 0] dma_rd_rsp_data , // o, `DMA_RD_CHNL_NUM * `DMA_DATA_W
    output  wire [`DMA_RD_CHNL_NUM * `DMA_HEAD_W-1 : 0] dma_rd_rsp_head , // o, `DMA_RD_CHNL_NUM * `DMA_HEAD_W
    input   wire [`DMA_RD_CHNL_NUM * 1          -1 : 0] dma_rd_rsp_ready, // i, `DMA_RD_CHNL_NUM * 1
    /* ------- Read Response to RDMA{end} ------- */

    /* -------axis read request interface{begin}------- */
    /* AXI-Stream read request tuser.
     * Only valid in first beat of a packet
     * | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     */
    output  wire                      axis_rd_req_tvalid , // o, 1
    output  wire                      axis_rd_req_tlast  , // o, 1
    output  wire [`DMA_DATA_W  -1:0]  axis_rd_req_tdata  , // o, `DMA_DATA_W
    output  wire [`AXIS_TUSER_W-1:0]  axis_rd_req_tuser  , // o, `AXIS_TUSER_W
    output  wire [`DMA_KEEP_W  -1:0]  axis_rd_req_tkeep  , // o, `DMA_KEEP_W
    input   wire                      axis_rd_req_tready , // i, 1
    /* -------axis read request interface{end}------- */

    /* -------axis read response interface{begin}------- */
    /* AXI-Stream read response tuser, interact with read response distributor.
     * Only valid in first beat of a packet
     * | Reserved | REQ CPL |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 119:105  |   104   | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     */
    input  wire                      axis_rd_rsp_tvalid, // i, 1
    input  wire                      axis_rd_rsp_tlast , // i, 1
    input  wire [`DMA_DATA_W  -1:0]  axis_rd_rsp_tdata , // i, `DMA_DATA_W
    input  wire [`AXIS_TUSER_W-1:0]  axis_rd_rsp_tuser , // i, `AXIS_TUSER_W
    input  wire [`DMA_KEEP_W  -1:0]  axis_rd_rsp_tkeep , // i, `DMA_KEEP_W
    output wire                      axis_rd_rsp_tready, // o, 1
    /* -------axis read response interface{end}------- */

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
    ,input  wire [(2*`DMA_RD_CHNL_NUM+3)*`SRAM_RW_DATA_W-1:0] rw_data // i, (2*`DMA_RD_CHNL_NUM+3)*`SRAM_RW_DATA_W
    ,input  wire [31:0] dbg_sel  // debug bus select
    ,output wire [31:0] dbg_bus  // debug bus data	
    /* -------APB reated signal{end}------- */
`endif
    

`ifdef SIMULATION    
    /* ------- Debug interface {begin}------- */
    /* |       reserved       |          idx       | end | out |
     * |  255:CHNL_NUM_LOG+2  | CHNL_NUM_LOG+2-1:2 |  1  |  0  |
     */
    ,output wire [255:0] debug_rd

    /* | reserved | tag_num | chnl_num | valid |
     * |  255:17  |  16:9   |    8:1   |   0   |
     */
    ,output wire [255:0] debug_tag
    /* ------- Debug interface {end}------- */
`endif
);

wire init_done_tag_mgmt, init_done_rd_rsp;

/* -------Request FIFO relevant{begin}------- */
wire [`DMA_RD_CHNL_NUM * 1          -1 : 0] st_rd_req_valid;
wire [`DMA_RD_CHNL_NUM * 1          -1 : 0] st_rd_req_ready;
wire [`DMA_RD_CHNL_NUM * `DMA_HEAD_W-1 : 0] st_rd_req_head ;
/* -------Request FIFO relevant{end}------- */

/* -------axis read request interface{begin}------- */
wire [`DMA_RD_CHNL_NUM * 1            -1:0]  axis_rd_request_tvalid;
wire [`DMA_RD_CHNL_NUM * 1            -1:0]  axis_rd_request_tlast ;
wire [`DMA_RD_CHNL_NUM * `DMA_DATA_W  -1:0]  axis_rd_request_tdata ;
wire [`DMA_RD_CHNL_NUM * `AXIS_TUSER_W-1:0]  axis_rd_request_tuser ;
wire [`DMA_RD_CHNL_NUM * `DMA_KEEP_W  -1:0]  axis_rd_request_tkeep ;
wire [`DMA_RD_CHNL_NUM * 1            -1:0]  axis_rd_request_tready;
/* -------axis read request interface{end}------- */

/* -------axis rd req arbiter interface{begin}------- */
wire [1            -1:0]  axis_rd_req_arb_tvalid;
wire [1            -1:0]  axis_rd_req_arb_tlast ;
wire [`DMA_DATA_W  -1:0]  axis_rd_req_arb_tdata ;
wire [`AXIS_TUSER_W-1:0]  axis_rd_req_arb_tuser ;
wire [`DMA_KEEP_W  -1:0]  axis_rd_req_arb_tkeep ;
wire [1            -1:0]  axis_rd_req_arb_tready;
/* -------axis rd req arbiter interface{end}------- */

/* -------Tag Management relevant{begin}------- */
wire                     tag_rreq_ready;
wire                     tag_rreq_last ;
wire [`DW_LEN_WIDTH-1:0] tag_rreq_sz   ;
wire [`TAG_MISC    -1:0] tag_rreq_misc ;
wire [8            -1:0] tag_rreq_chnl ;
wire [`TAG_NUM_LOG -1:0] tag_rreq_tag  ;
wire                     tag_rreq_valid;

wire [`DMA_RD_CHNL_NUM * 1             - 1 : 0] tag_rrsp_ready;
wire [`DMA_RD_CHNL_NUM * 1             - 1 : 0] tag_rrsp_last ;
wire [`DMA_RD_CHNL_NUM * `DW_LEN_WIDTH - 1 : 0] tag_rrsp_sz   ;
wire [`DMA_RD_CHNL_NUM * `TAG_MISC     - 1 : 0] tag_rrsp_misc ;
wire [`DMA_RD_CHNL_NUM * `TAG_NUM_LOG  - 1 : 0] tag_rrsp_tag  ;
wire [`DMA_RD_CHNL_NUM * 1             - 1 : 0] tag_rrsp_valid;
/* -------Tag Management relevant{end}------- */

/* ------- Read sub-req response{begin} ------- */
/* dma_*_head
 * | emit | chnl_num | Reserved | address | Reserved | Byte length |
 * | 127  | 126:120  |  119:96  |  95:32  |  31:13   |    12:0     |
 */
wire                   rd_rsp_demux_valid;
wire                   rd_rsp_demux_last ;
wire [`DMA_DATA_W-1:0] rd_rsp_demux_data ;
wire [`DMA_HEAD_W-1:0] rd_rsp_demux_head ;
wire                   rd_rsp_demux_ready;

wire                   st_rd_rsp_demux_valid;
wire                   st_rd_rsp_demux_last ;
wire [`DMA_DATA_W-1:0] st_rd_rsp_demux_data ;
wire [`DMA_HEAD_W-1:0] st_rd_rsp_demux_head ;
wire                   st_rd_rsp_demux_ready;
/* ------- Read sub-req response{end} ------- */

/* ------- Read sub-req response{begin} ------- */
/* dma_*_head
 * | emit | chnl_num | Reserved | address | Reserved | Byte length |
 * | 127  | 126:120  |  119:96  |  95:32  |  31:13   |    12:0     |
 */
wire [`DMA_RD_CHNL_NUM * 1          - 1 : 0] rd_rsp_concat_valid; // o, 1              
wire [`DMA_RD_CHNL_NUM * 1          - 1 : 0] rd_rsp_concat_last ; // o, 1              
wire [`DMA_RD_CHNL_NUM * `DMA_DATA_W- 1 : 0] rd_rsp_concat_data ; // o, `DMA_DATA_W   
wire [`DMA_RD_CHNL_NUM * `DMA_HEAD_W- 1 : 0] rd_rsp_concat_head ; // o, `DMA_HEAD_W 
wire [`DMA_RD_CHNL_NUM * 1          - 1 : 0] rd_rsp_concat_ready; // i, 1              

/* Indicate that the rsp chnl is available. 
 * This signal is deasserted when : 
 *     1. rsp output chnl signl dma_rd_rsp_ready is deasserted; &&
 *     2. There is (part of) rsp pkt in sub_req_rsp_concat module.
 */
wire [`DMA_RD_CHNL_NUM * 1          - 1 : 0] is_rsp_chnl_avail;
/* ------- Read sub-req response{end} ------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire  [(`DMA_RD_CHNL_NUM+1)*`SRAM_RW_DATA_W-1:0] rw_data_tag;
wire  [2*`SRAM_RW_DATA_W                   -1:0] rw_data_rsp;
wire  [`DMA_RD_CHNL_NUM*`SRAM_RW_DATA_W    -1:0] rw_data_concat;

wire [32-1:0] dbg_sel_rd_top, dbg_sel_rd_req, dbg_sel_rreq_arb, dbg_sel_tag_req, dbg_sel_tag_mgmt, dbg_sel_rd_rsp, 
              dbg_sel_dma_demux, dbg_sel_rsp_concat;
wire [32-1:0] dbg_bus_rd_top, dbg_bus_rd_req, dbg_bus_rreq_arb, dbg_bus_tag_req, dbg_bus_tag_mgmt, dbg_bus_rd_rsp, 
              dbg_bus_dma_demux, dbg_bus_rsp_concat;

wire [`RD_TOP_SIGNAL_W-1:0] dbg_signal_rd_top;
wire [`DMA_RD_CHNL_NUM*`RD_REQ_SIGNAL_W-1:0] dbg_signal_rd_req;
wire [`RREQ_ARB_SIGNAL_W -1:0] dbg_signal_rreq_arb;
wire [`TAG_REQ_SIGNAL_W  -1:0] dbg_signal_tag_req;
wire [`TAG_MGMT_SIGNAL_W -1:0] dbg_signal_tag_mgmt;
wire [`DMA_DEMUX_SIGNAL_W-1:0] dbg_signal_dma_demux;
wire [`DMA_RD_CHNL_NUM*`RSP_CONCAT_SIGNAL_W-1:0] dbg_signal_rsp_concat;
/* -------APB reated signal{end}------- */
`endif

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign {rw_data_tag, rw_data_rsp, rw_data_concat} = rw_data;
assign dbg_bus = (`RD_TOP_DBG_B     <= dbg_sel && dbg_sel < `RD_REQ_DBG_B       ) ? dbg_bus_rd_top     : 
                 (`RD_REQ_DBG_B     <= dbg_sel && dbg_sel < `RREQ_ARB_DBG_B     ) ? dbg_bus_rd_req     : 
                 (`RREQ_ARB_DBG_B   <= dbg_sel && dbg_sel < `TAG_REQ_DBG_B      ) ? dbg_bus_rreq_arb   : 
                 (`TAG_REQ_DBG_B    <= dbg_sel && dbg_sel < `TAG_MGMT_DBG_B     ) ? dbg_bus_tag_req    : 
                 (`TAG_MGMT_DBG_B   <= dbg_sel && dbg_sel < `RD_RSP_DBG_B       ) ? dbg_bus_tag_mgmt   : 
                 (`RD_RSP_DBG_B     <= dbg_sel && dbg_sel < `DMA_DEMUX_DBG_B    ) ? dbg_bus_rd_rsp     : 
                 (`DMA_DEMUX_DBG_B  <= dbg_sel && dbg_sel < `RSP_CONCAT_DBG_B   ) ? dbg_bus_dma_demux  : 
                 (`RSP_CONCAT_DBG_B <= dbg_sel && dbg_sel < `RD_REQ_RSP_DBG_SIZE) ? dbg_bus_rsp_concat : 32'd0;

assign dbg_sel_rd_top     = (`RD_TOP_DBG_B     <= dbg_sel && dbg_sel < `RD_REQ_DBG_B       ) ? (dbg_sel - `RD_TOP_DBG_B    ) : 32'd0;
assign dbg_sel_rd_req     = (`RD_REQ_DBG_B     <= dbg_sel && dbg_sel < `RREQ_ARB_DBG_B     ) ? (dbg_sel - `RD_REQ_DBG_B    ) : 32'd0;
assign dbg_sel_rreq_arb   = (`RREQ_ARB_DBG_B   <= dbg_sel && dbg_sel < `TAG_REQ_DBG_B      ) ? (dbg_sel - `RREQ_ARB_DBG_B  ) : 32'd0;
assign dbg_sel_tag_req    = (`TAG_REQ_DBG_B    <= dbg_sel && dbg_sel < `TAG_MGMT_DBG_B     ) ? (dbg_sel - `TAG_REQ_DBG_B   ) : 32'd0;
assign dbg_sel_tag_mgmt   = (`TAG_MGMT_DBG_B   <= dbg_sel && dbg_sel < `RD_RSP_DBG_B       ) ? (dbg_sel - `TAG_MGMT_DBG_B  ) : 32'd0;
assign dbg_sel_rd_rsp     = (`RD_RSP_DBG_B     <= dbg_sel && dbg_sel < `DMA_DEMUX_DBG_B    ) ? (dbg_sel - `RD_RSP_DBG_B    ) : 32'd0;
assign dbg_sel_dma_demux  = (`DMA_DEMUX_DBG_B  <= dbg_sel && dbg_sel < `RSP_CONCAT_DBG_B   ) ? (dbg_sel - `DMA_DEMUX_DBG_B ) : 32'd0;
assign dbg_sel_rsp_concat = (`RSP_CONCAT_DBG_B <= dbg_sel && dbg_sel < `RD_REQ_RSP_DBG_SIZE) ? (dbg_sel - `RSP_CONCAT_DBG_B) : 32'd0;

// Debug bus for read top
assign dbg_bus_rd_top = dbg_signal_rd_top >> {dbg_sel_rd_top, 5'd0};

// Debug bus for read request
assign dbg_bus_rd_req = dbg_signal_rd_req >> {dbg_sel_rd_req, 5'd0};

// Debug bus for read arbiter
assign dbg_bus_rreq_arb = dbg_signal_rreq_arb >> {dbg_sel_rreq_arb, 5'd0};

// Debug bus for tag request
assign dbg_bus_tag_req  = dbg_signal_tag_req >> {dbg_sel_tag_req, 5'd0};

// Debug bus for tag request
assign dbg_bus_tag_mgmt = dbg_signal_tag_mgmt >> {dbg_sel_tag_mgmt, 5'd0};

// Debug bus for tag request
assign dbg_bus_dma_demux = dbg_signal_dma_demux >> {dbg_sel_dma_demux, 5'd0};

// Debug bus for tag request
assign dbg_bus_rsp_concat  = dbg_signal_rsp_concat >> {dbg_sel_rsp_concat, 5'd0};

assign dbg_signal_rd_top = { // 9716
    init_done_tag_mgmt, init_done_rd_rsp, // 2
    st_rd_req_valid, st_rd_req_ready, st_rd_req_head , // 1170
    axis_rd_request_tvalid, axis_rd_request_tlast , axis_rd_request_tdata , axis_rd_request_tuser , axis_rd_request_tkeep , axis_rd_request_tready, // 3555
    axis_rd_req_arb_tvalid, axis_rd_req_arb_tlast , axis_rd_req_arb_tdata , axis_rd_req_arb_tuser , axis_rd_req_arb_tkeep , axis_rd_req_arb_tready, // 395
    tag_rreq_ready, tag_rreq_last, tag_rreq_sz, tag_rreq_misc, tag_rreq_chnl, tag_rreq_tag, tag_rreq_valid, // 40
    tag_rrsp_ready, tag_rrsp_last, tag_rrsp_sz, tag_rrsp_misc, tag_rrsp_tag, tag_rrsp_valid, // 288
    rd_rsp_demux_valid, rd_rsp_demux_last , rd_rsp_demux_data , rd_rsp_demux_head , rd_rsp_demux_ready, // 387
    st_rd_rsp_demux_valid, st_rd_rsp_demux_last , st_rd_rsp_demux_data , st_rd_rsp_demux_head , st_rd_rsp_demux_ready, // 387
    rd_rsp_concat_valid, rd_rsp_concat_last , rd_rsp_concat_data , rd_rsp_concat_head , rd_rsp_concat_ready, // 3483
    is_rsp_chnl_avail // 9
};
/* -------APB reated signal{end}------- */
`endif

assign init_done = init_done_tag_mgmt & init_done_rd_rsp;

genvar i;
generate
for (i = 0; i < `DMA_RD_CHNL_NUM; i = i + 1) begin:DMA_RD_CHNL

    /* -------Read Request FIFO{begin}------- */
    st_reg #(
        .TUSER_WIDTH ( 1 ),
        .TDATA_WIDTH ( `DMA_HEAD_W )
    ) st_rd_req (
        .clk   ( dma_clk ), // i, 1
        .rst_n ( rst_n   ), // i, 1

        /* -------input axis-like interface{begin}------- */
        .axis_tvalid ( dma_rd_req_valid[i] ), // i, 1
        .axis_tlast  ( 1'd0 ), // i, 1
        .axis_tuser  ( 1'd0 ), // i, TUSER_WIDTH
        .axis_tdata  ( {CHNL_NUM_TAB[(i+1)*8-1 : i*8], dma_rd_req_head[(i+1)*`DMA_HEAD_W-1-8 : i*`DMA_HEAD_W]} ), // i, TDATA_WIDTH
        .axis_tready ( dma_rd_req_ready[i] ), // o, 1
        /* -------input axis-like interface{end}------- */

        /* -------output in_reg inteface{begin}------- */
        .axis_reg_tvalid ( st_rd_req_valid[i] ), // o, 1
        .axis_reg_tlast  (  ), // o, 1
        .axis_reg_tuser  (  ), // o, TUSER_WIDTH
        .axis_reg_tdata  ( st_rd_req_head[(i+1)*`DMA_HEAD_W-1 : i*`DMA_HEAD_W] ), // o, TDATA_WIDTH
        .axis_reg_tready ( st_rd_req_ready[i] ) // i, 1
        /* -------output in_reg inteface{end}------- */
    );
    /* -------Read Request FIFO{end}------- */

    /* -------Read request handling(align && split req){begin}-------- */
    read_request #(
        
    ) read_request (
        .dma_clk       ( dma_clk   ), // i, 1
        .rst_n         ( rst_n     ), // i, 1

        /* ------- Read Request input{begin} ------- */
        /* dma_*_head (interact with RDMA modules), valid only in first beat of a packet
        * | chnl_num | Reserved | address | Reserved | Byte length |
        * | 127:120  |  119:96  |  95:32  |  31:13   |    12:0     |
        */
        .rd_req_valid  ( st_rd_req_valid[i]  ), // i, 1        
        .rd_req_head   ( st_rd_req_head[(i+1)*`DMA_HEAD_W-1 : i*`DMA_HEAD_W] ), // i, `DMA_HEAD_W
        .rd_req_ready  ( st_rd_req_ready[i]  ), // o, 1
        /* ------- Read Request input{end} ------- */

        /* -------axis read request interface{begin}------- */
        /* AXI-Stream read request tuser, every read request contains only one beat.
         * | chnl_num |last_sub_req | Reserved | REQ_TYPE |Tag(inv)| address | Reserved | DW length | first BE | last BE |
         * | 127:120  |     119     | 118:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
         */
        .axis_rd_request_tvalid ( axis_rd_request_tvalid[(i+1) * 1             - 1 : i * 1            ] ), // o, 1
        .axis_rd_request_tlast  ( axis_rd_request_tlast [(i+1) * 1             - 1 : i * 1            ] ), // o, 1
        .axis_rd_request_tdata  ( axis_rd_request_tdata [(i+1) * `DMA_DATA_W   - 1 : i * `DMA_DATA_W  ] ), // o, `DMA_DATA_W
        .axis_rd_request_tuser  ( axis_rd_request_tuser [(i+1) * `AXIS_TUSER_W - 1 : i * `AXIS_TUSER_W] ), // o, `AXIS_TUSER_W
        .axis_rd_request_tkeep  ( axis_rd_request_tkeep [(i+1) * `DMA_KEEP_W   - 1 : i * `DMA_KEEP_W  ] ), // o, `DMA_KEEP_W
        .axis_rd_request_tready ( axis_rd_request_tready[(i+1) * 1             - 1 : i * 1            ] ), // i, 1
        /* -------axis read request interface{end}------- */

        /* --------read request blocking detection{begin}-------- */
        .chnl_avail  ( dma_rd_rsp_ready[i] ), // i, 1
        .chnl_valid  ( tag_rrsp_valid  [i] ), // i, 1
        /* --------read request blocking detection{end}-------- */

        /* -------PCIe fragment property{begin}------- */
        /* This signal indicates the (max payload size & max read request size) agreed in the communication
        * 3'b000 -- 128 B
        * 3'b001 -- 256 B
        * 3'b010 -- 512 B
        * 3'b011 -- 1024B
        * 3'b100 -- 2048B
        * 3'b101 -- 4096B
        */
        .max_pyld_sz   (  max_pyld_sz   ), // i, 3
        .max_rd_req_sz (  max_rd_req_sz )  // i, 3
        /* -------PCIe fragment property{end}------- */

    `ifdef PCIEI_APB_DBG
        /* -------APB reated signal{begin}------- */
        ,.dbg_signal ( dbg_signal_rd_req[(i+1)*`RD_REQ_SIGNAL_W-1:i*`RD_REQ_SIGNAL_W] )  // o, `RD_REQ_SIGNAL_W
        /* -------APB reated signal{end}------- */
    `endif
    );
    /* -------Read request handling(align && split req){end}-------- */

end
endgenerate

req_arbiter #(
    .CHNL_NUM_LOG          ( `DMA_RD_CHNL_NUM_LOG ),
    .CHANNEL_NUM           ( `DMA_RD_CHNL_NUM     )   // number of slave signals to arbit
) rd_req_arbiter (

    .dma_clk  ( dma_clk   ), // i, 1
    .rst_n    ( rst_n     ), // i, 1

    /* -------Slave AXIS Interface(Connect to Read Request Module){begin}------- */
    /* AXI-Stream read request tuser, every read request contains only one beat.
     * | chnl_num |last_sub_req | Reserved | REQ_TYPE |Tag(inv)| address | Reserved | DW length | first BE | last BE |
     * | 127:120  |     119     | 118:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     */
    .s_axis_req_tvalid ( axis_rd_request_tvalid ), // i, CHANNEL_NUM * 1
    .s_axis_req_tlast  ( axis_rd_request_tlast  ), // i, CHANNEL_NUM * 1
    .s_axis_req_tdata  ( axis_rd_request_tdata  ), // i, CHANNEL_NUM * `DMA_DATA_W
    .s_axis_req_tuser  ( axis_rd_request_tuser  ), // i, CHANNEL_NUM * `AXIS_TUSER_W  ;The field contents are different from dma_*_head interface
    .s_axis_req_tkeep  ( axis_rd_request_tkeep  ), // i, CHANNEL_NUM * `DMA_KEEP_W
    .s_axis_req_tready ( axis_rd_request_tready ), // o, CHANNEL_NUM * 1
    /* -------Slave AXIS Interface(Connect to Read Request Module){end}------- */


    /* ------- Master AXIS Interface(Connect to tag_alloc module){begin} ------- */
    /* AXI-Stream read request tuser, every read request contains only one beat.
     * | chnl_num |last_sub_req | Reserved | REQ_TYPE |Tag(inv)| address | Reserved | DW length | first BE | last BE |
     * | 127:120  |     119     | 118:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     */
    .m_axis_req_tvalid ( axis_rd_req_arb_tvalid ), // o, 1
    .m_axis_req_tlast  ( axis_rd_req_arb_tlast  ), // o, 1
    .m_axis_req_tdata  ( axis_rd_req_arb_tdata  ), // o, `DMA_DATA_W
    .m_axis_req_tuser  ( axis_rd_req_arb_tuser  ), // o, `AXIS_TUSER_W   ;The field contents are different from dma_*_tuser interface
    .m_axis_req_tkeep  ( axis_rd_req_arb_tkeep  ), // o, `DMA_KEEP_W
    .m_axis_req_tready ( axis_rd_req_arb_tready )  // i, 1
    /* ------- Master AXIS Interface(Connect to tag_alloc module){end} ------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_signal ( dbg_signal_rreq_arb ) // o, `RREQ_ARB_SIGNAL_W  
    /* -------APB reated signal{end}------- */
`endif
    
`ifdef SIMULATION    
    /* ------- Debug interface {begin}------- */
    /* |       reserved       |          idx       | end | out |
     * |  255:CHNL_NUM_LOG+2  | CHNL_NUM_LOG+2-1:2 |  1  |  0  |
     */
    ,.debug ( debug_rd )
    /* ------- Debug interface {end}------- */
`endif
);

tag_request #(
    
) tag_request (
    .dma_clk       ( dma_clk   ), // i, 1
    .rst_n         ( rst_n     ), // i, 1

    /* ------- Connect to rd_req_arbiter module{begin} ------- */
    /* AXI-Stream read request tuser, every read request contains only one beat.
     * | chnl_num |last_sub_req | Reserved | REQ_TYPE |Tag(inv)| address | Reserved | DW length | first BE | last BE |
     * | 127:120  |     119     | 118:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     */
    .axis_rreq_tvalid ( axis_rd_req_arb_tvalid ), // i, 1
    .axis_rreq_tlast  ( axis_rd_req_arb_tlast  ), // i, 1
    .axis_rreq_tdata  ( axis_rd_req_arb_tdata  ), // i, `DMA_DATA_W
    .axis_rreq_tuser  ( axis_rd_req_arb_tuser  ), // i, `AXIS_TUSER_W   ;The field contents are different from dma_*_tuser interface
    .axis_rreq_tkeep  ( axis_rd_req_arb_tkeep  ), // i, `DMA_KEEP_W
    .axis_rreq_tready ( axis_rd_req_arb_tready ), // o, 1
    /* ------- Connect to rd_req_arbiter module{end} ------- */

    /* -------tag request{begin}------- */
    .tag_rreq_ready ( tag_rreq_ready ), // o, 1
    .tag_rreq_last  ( tag_rreq_last  ), // o, 1  ; Indicate the last sub-req for rd req
    .tag_rreq_sz    ( tag_rreq_sz    ), // o, `DW_LEN_WIDTH ; Request size(in dw unit) of this tag
    .tag_rreq_misc  ( tag_rreq_misc  ), // o, `TAG_MISC ; Including addr && dw empty info
    .tag_rreq_chnl  ( tag_rreq_chnl  ), // o, 8 ; channel number for this request
    .tag_rreq_tag   ( tag_rreq_tag   ), // i, `TAG_NUM_LOG
    .tag_rreq_valid ( tag_rreq_valid ), // i, 1
    /* -------tag request{end}------- */

    /* -------axis read request interface{begin}------- */
    /* AXI-Stream read request tuser, interact with read request arbiter.
     * Only valid in first beat of a packet
     * | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     */
    .axis_rreq_tag_tvalid ( axis_rd_req_tvalid ), // o, 1
    .axis_rreq_tag_tlast  ( axis_rd_req_tlast  ), // o, 1
    .axis_rreq_tag_tdata  ( axis_rd_req_tdata  ), // o, `DMA_DATA_W
    .axis_rreq_tag_tuser  ( axis_rd_req_tuser  ), // o, `AXIS_TUSER_W
    .axis_rreq_tag_tkeep  ( axis_rd_req_tkeep  ), // o, `DMA_KEEP_W
    .axis_rreq_tag_tready ( axis_rd_req_tready )  // i, 1
    /* -------axis read request interface{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_signal   ( dbg_signal_tag_req )  // o, `TAG_REQ_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

np_tag_mgmt #(
    
) np_tag_mgmt (
    
    .dma_clk       ( dma_clk   ), // i, 1
    .rst_n         ( rst_n     ), // i, 1
    .init_done     ( init_done_tag_mgmt ), // o, 1

    /* -------tag request{begin}------- */
    .tag_rreq_ready ( tag_rreq_ready ), // i, 1
    .tag_rreq_last  ( tag_rreq_last  ), // i, 1  ; Indicate the last sub-req for rd req
    .tag_rreq_sz    ( tag_rreq_sz    ), // i, `DW_LEN_WIDTH ; Request size(in dw unit) of this tag
    .tag_rreq_misc  ( tag_rreq_misc  ), // i, `TAG_MISC ; Including addr && dw empty info
    .tag_rreq_chnl  ( tag_rreq_chnl  ), // i, 8 ; channel number for this request
    .tag_rreq_tag   ( tag_rreq_tag   ), // o, `TAG_NUM_LOG
    .tag_rreq_valid ( tag_rreq_valid ), // o, 1
    /* -------tag request{end}------- */

    /* -------tag release{begin}------- */
    // Note that only one channel is allowed to assert at the same time
    .tag_rrsp_ready ( tag_rrsp_ready ), // i, `DMA_RD_CHNL_NUM * 1
    .tag_rrsp_last  ( tag_rrsp_last  ), // o, `DMA_RD_CHNL_NUM * 1
    .tag_rrsp_sz    ( tag_rrsp_sz    ), // o, `DMA_RD_CHNL_NUM * `DW_LEN_WIDTH
    .tag_rrsp_misc  ( tag_rrsp_misc  ), // o, `DMA_RD_CHNL_NUM * `TAG_MISC ; Including addr && dw empty info
    .tag_rrsp_tag   ( tag_rrsp_tag   ), // o, `DMA_RD_CHNL_NUM * `TAG_NUM_LOG
    .tag_rrsp_valid ( tag_rrsp_valid )  // o, `DMA_RD_CHNL_NUM * 1
    /* -------tag release{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.rw_data    ( rw_data_tag         ) // i, (`DMA_RD_CHNL_NUM+1)*`SRAM_RW_DATA_W
    ,.dbg_signal ( dbg_signal_tag_mgmt ) // o, `TAG_MGMT_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif

`ifdef SIMULATION    
    /* ------- Debug interface {begin}------- */
    /* | reserved | tag_num | chnl_num | valid |
     * |  255:17  |  16:9   |    8:1   |   0   |
     */
    ,.debug ( debug_tag )
    /* ------- Debug interface {end}------- */
`endif
);

read_response #(
    
) read_response (
    
    .dma_clk      ( dma_clk   ), // i, 1
    .rst_n        ( rst_n     ), // i, 1
    .init_done    ( init_done_rd_rsp ), // o, 1

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

    /* -------tag release{begin}------- */
    // Note that only one channel is allowed to assert at the same time
    .tag_rrsp_ready ( tag_rrsp_ready ), // o, `DMA_RD_CHNL_NUM * 1
    .tag_rrsp_last  ( tag_rrsp_last  ), // i, `DMA_RD_CHNL_NUM * 1
    .tag_rrsp_sz    ( tag_rrsp_sz    ), // i, `DMA_RD_CHNL_NUM * `DW_LEN_WIDTH
    .tag_rrsp_misc  ( tag_rrsp_misc  ), // i, `DMA_RD_CHNL_NUM * `TAG_MISC ; Including addr && dw empty info
    .tag_rrsp_tag   ( tag_rrsp_tag   ), // i, `DMA_RD_CHNL_NUM * `TAG_NUM_LOG
    .tag_rrsp_valid ( tag_rrsp_valid ), // i, `DMA_RD_CHNL_NUM * 1
    /* -------tag release{end}------- */

    /* ------- Read Response to RDMA{begin} ------- */
    /* dma_*_head
     * | emit | chnl_num | Reserved | address | Reserved | Byte length |
     * | 127  | 126:120  |  119:96  |  95:32  |  31:13   |    12:0     |
     */
    .sub_req_rsp_valid ( rd_rsp_demux_valid ), // o, 1
    .sub_req_rsp_last  ( rd_rsp_demux_last  ), // o, 1
    .sub_req_rsp_head  ( rd_rsp_demux_head  ), // o, `DMA_HEAD_W
    .sub_req_rsp_data  ( rd_rsp_demux_data  ), // o, `DMA_DATA_W
    .sub_req_rsp_ready ( rd_rsp_demux_ready ), // i, 1
    /* ------- Read Response to RDMA{end} ------- */

    /* --------chnl_stall{begin}-------- */
    /* Indicate that the rsp chnl is available. 
     * This signal is deasserted when : 
     *     1. rsp output chnl signl dma_rd_rsp_ready is deasserted; &&
     *     2. There is (part of) rsp pkt in sub_req_rsp_concat module.
     * In this way, 
     */
    .chnl_avail ( is_rsp_chnl_avail )  // i, `DMA_RD_CHNL_NUM; 
    /* --------chnl_stall{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.rw_data    ( rw_data_rsp    )  // i, `SRAM_RW_DATA_W*2
    ,.dbg_sel    ( dbg_sel_rd_rsp )  // i, 32
    ,.dbg_bus    ( dbg_bus_rd_rsp )  // o, 32
    /* -------APB reated signal{end}------- */
`endif
);

/* -------output reg{begin}------- */
st_reg #(
    .TUSER_WIDTH ( `DMA_HEAD_W ),
    .TDATA_WIDTH ( `DMA_DATA_W ),
	.MODE( 		1		)
) out_st_reg (
    .clk   ( dma_clk ), // i, 1
    .rst_n ( rst_n   ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( rd_rsp_demux_valid ), // i, 1
    .axis_tlast  ( rd_rsp_demux_last  ), // i, 1
    .axis_tuser  ( rd_rsp_demux_head  ), // i, TUSER_WIDTH
    .axis_tdata  ( rd_rsp_demux_data  ), // i, TDATA_WIDTH
    .axis_tready ( rd_rsp_demux_ready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .axis_reg_tvalid ( st_rd_rsp_demux_valid ), // o, 1
    .axis_reg_tlast  ( st_rd_rsp_demux_last  ), // o, 1
    .axis_reg_tuser  ( st_rd_rsp_demux_head  ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( st_rd_rsp_demux_data  ), // o, TDATA_WIDTH
    .axis_reg_tready ( st_rd_rsp_demux_ready )  // i, 1
    /* -------output in_reg inteface{end}------- */
);
/* -------output reg{end}------- */

dma_demux #(
    .CHANNEL_NUM  ( `DMA_RD_CHNL_NUM )
) dma_demux (
    .clk             ( dma_clk   ), // i, 1
    .rst_n           ( rst_n     ), // i, 1

    .nxt_demux_vld   ( rd_rsp_demux_valid ), // i, 1
    .nxt_demux_sel   ( {1'd0, rd_rsp_demux_head[126:120]} ), // i, 8

    /* --------DMA Write Request interface{begin}-------- */
    /* dma_*_head
     * | emit | chnl_num | Reserved | address | Reserved | Byte length |
     * | 127  | 126:120  |  119:96  |  95:32  |  31:13   |    12:0     |
     */
    .s_axis_req_valid  ( st_rd_rsp_demux_valid ), // i, 1
    .s_axis_req_last   ( st_rd_rsp_demux_last  ), // i, 1
    .s_axis_req_head   ( st_rd_rsp_demux_head  ), // i, `DMA_HEAD_W
    .s_axis_req_data   ( st_rd_rsp_demux_data  ), // i, `DMA_DATA_W
    .s_axis_req_ready  ( st_rd_rsp_demux_ready ), // o, 1

    /* dma_*_head
     * | emit | chnl_num | Reserved | address | Reserved | Byte length |
     * | 127  | 126:120  |  119:96  |  95:32  |  31:13   |    12:0     |
     */
    .m_axis_req_valid  ( rd_rsp_concat_valid ), // o, CHANNEL_NUM * 1
    .m_axis_req_last   ( rd_rsp_concat_last  ), // o, CHANNEL_NUM * 1
    .m_axis_req_head   ( rd_rsp_concat_head  ), // o, CHANNEL_NUM * `DMA_HEAD_W
    .m_axis_req_data   ( rd_rsp_concat_data  ), // o, CHANNEL_NUM * `DMA_DATA_W
    .m_axis_req_ready  ( rd_rsp_concat_ready )  // i, CHANNEL_NUM * 1
    /* --------DMA Write Request interface{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_signal   ( dbg_signal_dma_demux )  // o, `DMA_DEMUX_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

generate
for (i = 0; i < `DMA_RD_CHNL_NUM; i = i + 1) begin:SUB_REQ_CONCAT

    /* -------Sub-req rsp concat{begin}------- */
    sub_req_rsp_concat #(

    ) sub_req_rsp_concat (
        .dma_clk ( dma_clk ), // i, 1
        .rst_n   ( rst_n   ), // i, 1

        /* -------response emission{begin}------- */
        .emit ( rd_rsp_concat_head[(i + 1) * `DMA_HEAD_W - 1 : i * `DMA_HEAD_W + `DMA_HEAD_W - 1]  ), // i, 1 ; high active
        /* -------response emission{end}------- */

        /* ------- Read Response to RDMA{begin} ------- */
        /* dma_*_head
         * | emit | chnl_num | Reserved | address | Reserved | Byte length |
         * | 127  | 126:120  |  119:96  |  95:32  |  31:13   |    12:0     |
         */
        .rd_sub_req_rsp_valid ( rd_rsp_concat_valid[(i + 1) * 1            - 1 : i * 1         ] ), // i, 1
        .rd_sub_req_rsp_last  ( rd_rsp_concat_last [(i + 1) * 1            - 1 : i * 1         ] ), // i, 1
        .rd_sub_req_rsp_head  ( rd_rsp_concat_head [(i + 1) * `DMA_HEAD_W - 1 : i * `DMA_HEAD_W] ), // i, `DMA_HEAD_W
        .rd_sub_req_rsp_data  ( rd_rsp_concat_data [(i + 1) * `DMA_DATA_W - 1 : i * `DMA_DATA_W] ), // i, `DMA_DATA_W
        .rd_sub_req_rsp_ready ( rd_rsp_concat_ready[(i + 1) * 1            - 1 : i * 1         ] ), // o, 1

        .is_avail             ( is_rsp_chnl_avail[(i + 1) * 1            - 1 : i * 1         ] ), // o, 1
        /* ------- Read Response to RDMA{end} ------- */

        /* ------- Read Response to RDMA{begin} ------- */
        /* *_head
        * | Reserved | address | Reserved | Byte length |
        * |  127:96  |  95:32  |  31:13   |    12:0     |
        */
        .rd_rsp_valid ( dma_rd_rsp_valid [(i + 1) * 1           - 1 : i * 1          ] ), // o, 1
        .rd_rsp_last  ( dma_rd_rsp_last  [(i + 1) * 1           - 1 : i * 1          ] ), // o, 1
        .rd_rsp_head  ( dma_rd_rsp_head  [(i + 1) * `DMA_HEAD_W - 1 : i * `DMA_HEAD_W] ), // o, `DMA_HEAD_W
        .rd_rsp_data  ( dma_rd_rsp_data  [(i + 1) * `DMA_DATA_W - 1 : i * `DMA_DATA_W] ), // o, `DMA_DATA_W
        .rd_rsp_ready ( dma_rd_rsp_ready [(i + 1) * 1           - 1 : i * 1          ] ), // i, 1
        /* ------- Read Response to RDMA{end} ------- */

        /* -------PCIe fragment property{begin}------- */
        /* This signal indicates the (max payload size & max read request size) agreed in the communication
        * 3'b000 -- 128 B
        * 3'b001 -- 256 B
        * 3'b010 -- 512 B
        * 3'b011 -- 1024B
        * 3'b100 -- 2048B
        * 3'b101 -- 4096B
        */
        .max_pyld_sz   (  max_pyld_sz   ), // i, 3
        .max_rd_req_sz (  max_rd_req_sz )  // i, 3
        /* -------PCIe fragment property{end}------- */

    `ifdef PCIEI_APB_DBG
        /* -------APB reated signal{begin}------- */
        ,.rw_data      ( rw_data_concat[(i+1)*`SRAM_RW_DATA_W-1:i*`SRAM_RW_DATA_W] ) // i, `SRAM_RW_DATA_W
        ,.dbg_signal   ( dbg_signal_rsp_concat[(i+1)*`RSP_CONCAT_SIGNAL_W-1:i*`RSP_CONCAT_SIGNAL_W] )  // o, `RSP_CONCAT_SIGNAL_W
        /* -------APB reated signal{end}------- */
    `endif
    );
    /* -------Sub-req rsp concat{end}------- */

end
endgenerate

endmodule
