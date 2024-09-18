`timescale 1ns / 100ps
//*************************************************************************
// > File Name: DMA.v
// > Author   : Kangning
// > Date     : 2020-08-17
// > Note     : DMA module, used to generate DMA Interface
// > V1.1 - 2021-01-29: Modify formation of code, make it more generalize.
//*************************************************************************

//`include "../lib/global_include_h.v"
//`include "../lib/dma_def_h.v"

module DMA #(

) (
    input  wire                        pcie_clk  ,
    input  wire                        pcie_rst_n,
    input  wire                        dma_clk   ,
    input  wire                        rst_n     ,
    output wire                        init_done , // o, 1

    /* -------dma interface{begin}------- */
    /* *_head of DMA interface (interact with RDMA modules), 
     * valid only in first beat of a packet.
     * When Transmiting msi-x interrupt message, 'Byte length' 
     * should be 0, 'address' means the address of msi-x, and
     * msi-x data locates in *_data[31:0].
     * | Resvd |  Req Type |   address    | Reserved | Byte length |
     * |       |(rd,wr,int)| (msi-x addr) |          | (0 for int) |
     * |-------|-----------|--------------|----------|-------------|
     * |127:100|   99:96   |    95:32     |  31:13   |    12:0     |
     */
    // Read Req
    input  wire [`DMA_RD_CHNL_NUM * 1          -1:0] dma_rd_req_valid,
    input  wire [`DMA_RD_CHNL_NUM * 1          -1:0] dma_rd_req_last ,
    input  wire [`DMA_RD_CHNL_NUM * `DMA_DATA_W-1:0] dma_rd_req_data ,
    input  wire [`DMA_RD_CHNL_NUM * `DMA_HEAD_W-1:0] dma_rd_req_head ,
    output wire [`DMA_RD_CHNL_NUM * 1          -1:0] dma_rd_req_ready,

    // DMA Read Resp
    output wire [`DMA_RD_CHNL_NUM * 1          -1:0] dma_rd_rsp_valid,
    output wire [`DMA_RD_CHNL_NUM * 1          -1:0] dma_rd_rsp_last ,
    output wire [`DMA_RD_CHNL_NUM * `DMA_DATA_W-1:0] dma_rd_rsp_data ,
    output wire [`DMA_RD_CHNL_NUM * `DMA_HEAD_W-1:0] dma_rd_rsp_head ,
    input  wire [`DMA_RD_CHNL_NUM * 1          -1:0] dma_rd_rsp_ready,

    // DMA Write Req
    input  wire [`DMA_WR_CHNL_NUM * 1          -1:0] dma_wr_req_valid,
    input  wire [`DMA_WR_CHNL_NUM * 1          -1:0] dma_wr_req_last ,
    input  wire [`DMA_WR_CHNL_NUM * `DMA_DATA_W-1:0] dma_wr_req_data ,
    input  wire [`DMA_WR_CHNL_NUM * `DMA_HEAD_W-1:0] dma_wr_req_head ,
    output wire [`DMA_WR_CHNL_NUM * 1          -1:0] dma_wr_req_ready,
    /* -------dma interface{end}------- */


    /* -------Requester Request{begin}------- */
    /*  RQ tuser
     * |  59:28 |  27:24  |    23:16   |          15         |   14:13  |      12     |     11      |     10:8    |   7:4   |    3:0   |
     * | parity | seq_num | tph_st_tag | tph_indirect_tag_en | tph_type | tph_present | discontinue | addr_offset | last_be | first_be |
     * |   0    |   0     |     0      |          0          |     0    |      0      |      0      |      0      |         |          |
     */
    output wire                      s_axis_rq_tvalid,
    output wire                      s_axis_rq_tlast ,
    output wire [`DMA_DATA_W-1:0]    s_axis_rq_tdata ,
    output wire [59           :0]    s_axis_rq_tuser ,
    output wire [`DMA_KEEP_W-1:0]    s_axis_rq_tkeep ,
    input  wire                      s_axis_rq_tready,
    /* -------Requester Request{end}------- */

    /* -------Requester Completion{begin}------- */
    /*  RC tuser
     * |  74:43 |      42     |    41:38   |  37:34   |    33    |    32    |  31:0   |  
     * | parity | discontinue |  is_eof_1  | is_eof_0 | is_sof_1 | is_sof_0 | byte_en |
     * | ignore |   ignore    |  ignore    | ignore   |  ignore  |  ignore  |         |
     */
    input  wire                       m_axis_rc_tvalid,
    input  wire                       m_axis_rc_tlast ,
    input  wire [`DMA_DATA_W-1:0]     m_axis_rc_tdata ,
    input  wire [74           :0]     m_axis_rc_tuser ,
    input  wire [`DMA_KEEP_W-1:0]     m_axis_rc_tkeep ,
    output wire                       m_axis_rc_tready,
    /* -------Requester Completion{end}------- */

    /* -------Interrupt Interface Signals{begin}------- */
    input                  [1:0]     cfg_interrupt_msix_enable        ,
    input                  [1:0]     cfg_interrupt_msix_mask          ,
    output                [31:0]     cfg_interrupt_msix_data          ,
    output                [63:0]     cfg_interrupt_msix_address       ,
    output                           cfg_interrupt_msix_int           ,
    input                            cfg_interrupt_msix_sent          ,
    input                            cfg_interrupt_msix_fail          ,
    output wire            [2:0]     cfg_interrupt_msi_function_number,
    /* -------Interrupt Interface Signals{end}------- */

    /* -------Configuration Status Interface{begin}------- */
    input  wire [ 2:0]                 max_pyld_sz  ,
    input  wire [ 2:0]                 max_rd_req_sz, 
    input  wire [15:0]                 req_id
    /* -------Configuration Status Interface{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [(2*`DMA_RD_CHNL_NUM+`DMA_WR_CHNL_NUM+6)*`SRAM_RW_DATA_W-1:0] rw_data // i, (2*`DMA_RD_CHNL_NUM+`DMA_WR_CHNL_NUM+6)*`SRAM_RW_DATA_W
    ,input  wire [31:0] dbg_sel  // debug bus select
    ,output wire [31:0] dbg_bus  // debug bus data	
    /* -------APB reated signal{end}------- */
`endif
    
`ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* |          reserved          |
     * |           255:47           |
     * | tag_num | tag_chnl | valid |
     * |  46:39  |  38:31   |  30   |
     * | top_idx | top_end | top_out|
     * |  29:22  |    21   |   20   |
     * | rd_idx  | rd_end  | rd_out |
     * |  19:12  |   11    |   10   |
     * | wr_idx  | wr_end  | wr_out |
     * |   9:2   |    1    |    0   |
     */
    ,output wire [255:0]               debug
    /* ------- Debug interface {end}------- */
`endif
);

`ifdef SIMULATION

wire [255:0] debug_wr, debug_rd, debug_top, debug_tag;
assign debug = {209'd0, debug_tag[16:0], debug_top[9:0], debug_rd[9:0], debug_wr[9:0]};

`endif

/* -------Used in wr arbiter{begin}------- */
wire [`DMA_WR_CHNL_NUM * 1            -1:0] axis_wr_req_tvalid;
wire [`DMA_WR_CHNL_NUM * 1            -1:0] axis_wr_req_tlast ;
wire [`DMA_WR_CHNL_NUM * `DMA_DATA_W  -1:0] axis_wr_req_tdata ;
wire [`DMA_WR_CHNL_NUM * `AXIS_TUSER_W-1:0] axis_wr_req_tuser ;
wire [`DMA_WR_CHNL_NUM * `DMA_KEEP_W  -1:0] axis_wr_req_tkeep ;
wire [`DMA_WR_CHNL_NUM * 1            -1:0] axis_wr_req_tready;
/* -------Used in wr arbiter{end}------- */

/* -------Used in rd & wr arbiter{begin}------- */
wire                     axis_wreq_tvalid;
wire                     axis_wreq_tlast ;
wire [`DMA_DATA_W  -1:0] axis_wreq_tdata ;
wire [`AXIS_TUSER_W-1:0] axis_wreq_tuser ;
wire [`DMA_KEEP_W  -1:0] axis_wreq_tkeep ;
wire                     axis_wreq_tready;

wire                     axis_rreq_tvalid;
wire                     axis_rreq_tlast ;
wire [`DMA_DATA_W  -1:0] axis_rreq_tdata ;
wire [`AXIS_TUSER_W-1:0] axis_rreq_tuser ;
wire [`DMA_KEEP_W  -1:0] axis_rreq_tkeep ;
wire                     axis_rreq_tready;
/* -------Used in rd & wr arbiter{end}------- */

wire                     axis_req_tvalid;
wire                     axis_req_tlast ;
wire [`DMA_DATA_W  -1:0] axis_req_tdata ;
wire [`AXIS_TUSER_W-1:0] axis_req_tuser ;
wire [`DMA_KEEP_W  -1:0] axis_req_tkeep ;
wire                     axis_req_tready;



/* -------Used in read response{begin}------- */
// In pcie clock domain 
wire                                     pcie_axis_rrsp_tvalid;
wire                                     pcie_axis_rrsp_tlast ;
wire [`DMA_DATA_W  -1:0]                 pcie_axis_rrsp_tdata ;
wire [`AXIS_TUSER_W-1:0]                 pcie_axis_rrsp_tuser ;
wire [`DMA_KEEP_W  -1:0]                 pcie_axis_rrsp_tkeep ;
wire                                     pcie_axis_rrsp_tready;

// in dma clock domain
wire                                     dma_axis_rrsp_tvalid;
wire                                     dma_axis_rrsp_tlast ;
wire [`DMA_DATA_W  -1:0]                 dma_axis_rrsp_tdata ;
wire [`AXIS_TUSER_W-1:0]                 dma_axis_rrsp_tuser ;
wire [`DMA_KEEP_W  -1:0]                 dma_axis_rrsp_tkeep ;
wire                                     dma_axis_rrsp_tready;
/* -------Used in read response{end}------- */



/* --------Used in RQ & RC {begin}-------- */
wire                   dma_axis_rq_tvalid;
wire                   dma_axis_rq_tlast ;
wire [`DMA_DATA_W-1:0] dma_axis_rq_tdata ;
wire [59           :0] dma_axis_rq_tuser ;
wire [`DMA_KEEP_W-1:0] dma_axis_rq_tkeep ;
wire                   dma_axis_rq_tready;

// wire                   dma_axis_rc_tvalid;
// wire                   dma_axis_rc_tlast ;
// wire [`DMA_DATA_W-1:0] dma_axis_rc_tdata ;
// wire [74           :0] dma_axis_rc_tuser ;
// wire [`DMA_KEEP_W-1:0] dma_axis_rc_tkeep ;
// wire                   dma_axis_rc_tready;
/* --------Used in RQ & RC {end}-------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire [(2*`DMA_RD_CHNL_NUM+3)*`SRAM_RW_DATA_W-1:0] rw_data_rd_req_rsp;
wire [`DMA_WR_CHNL_NUM*`SRAM_RW_DATA_W-1:0] rw_data_wr_req;
wire [`SRAM_RW_DATA_W-1:0] rw_data_int;
wire [`SRAM_RW_DATA_W-1:0] rw_data_rq;
wire [`SRAM_RW_DATA_W-1:0] rw_data_rc;

wire [32-1:0] dbg_sel_dma_top, dbg_sel_rd_req_rsp, dbg_sel_wr_req, dbg_sel_wreq_arb, dbg_sel_req_arb, 
              dbg_sel_req_convert, dbg_sel_rsp_convert;
wire [32-1:0] dbg_bus_dma_top, dbg_bus_rd_req_rsp, dbg_bus_wr_req, dbg_bus_wreq_arb, dbg_bus_req_arb, 
              dbg_bus_req_convert, dbg_bus_rsp_convert;
        
wire [`DMA_TOP_SIGNAL_W-1:0] dbg_signal_dma_top;
wire [`DMA_WR_CHNL_NUM*`WR_REQ_SIGNAL_W-1:0] dbg_signal_wr_req;
wire [`WREQ_ARB_SIGNAL_W-1:0] dbg_signal_wreq_arb;
wire [`REQ_ARB_SIGNAL_W -1:0] dbg_signal_req_arb;
wire [`RQ_ASYNC_SIGNAL_W-1:0] dbg_signal_rq_async;
wire [`RC_ASYNC_SIGNAL_W-1:0] dbg_signal_rc_async;
wire [`RRSP_ASYNC_SIGNAL_W-1:0] dbg_signal_rrsp_async;
/* -------APB reated signal{end}------- */
`endif

//-----------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign {rw_data_rd_req_rsp, rw_data_wr_req, rw_data_int, rw_data_rq, rw_data_rc} = rw_data;

assign dbg_bus = (`DMA_TOP_DBG_B     <= dbg_sel && dbg_sel < `RD_REQ_RSP_DBG_B ) ? dbg_bus_dma_top     : 
                 (`RD_REQ_RSP_DBG_B  <= dbg_sel && dbg_sel < `WR_REQ_DBG_B     ) ? dbg_bus_rd_req_rsp  : 
                 (`WR_REQ_DBG_B      <= dbg_sel && dbg_sel < `WREQ_ARB_DBG_B   ) ? dbg_bus_wr_req      : 
                 (`WREQ_ARB_DBG_B    <= dbg_sel && dbg_sel < `REQ_ARB_DBG_B    ) ? dbg_bus_wreq_arb    : 
                 (`REQ_ARB_DBG_B     <= dbg_sel && dbg_sel < `REQ_CONVERT_DBG_B) ? dbg_bus_req_arb     : 
                 (`REQ_CONVERT_DBG_B <= dbg_sel && dbg_sel < `RSP_CONVERT_DBG_B) ? dbg_bus_req_convert : 
                 (`RSP_CONVERT_DBG_B <= dbg_sel && dbg_sel < `DMA_DBG_SIZE     ) ? dbg_bus_rsp_convert : 32'd0;

assign dbg_sel_dma_top     = (`DMA_TOP_DBG_B     <= dbg_sel && dbg_sel < `RD_REQ_RSP_DBG_B ) ? (dbg_sel - `DMA_TOP_DBG_B    ) : 32'd0;
assign dbg_sel_rd_req_rsp  = (`RD_REQ_RSP_DBG_B  <= dbg_sel && dbg_sel < `WR_REQ_DBG_B     ) ? (dbg_sel - `RD_REQ_RSP_DBG_B ) : 32'd0;
assign dbg_sel_wr_req      = (`WR_REQ_DBG_B      <= dbg_sel && dbg_sel < `WREQ_ARB_DBG_B   ) ? (dbg_sel - `WR_REQ_DBG_B     ) : 32'd0;
assign dbg_sel_wreq_arb    = (`WREQ_ARB_DBG_B    <= dbg_sel && dbg_sel < `REQ_ARB_DBG_B    ) ? (dbg_sel - `WREQ_ARB_DBG_B   ) : 32'd0;
assign dbg_sel_req_arb     = (`REQ_ARB_DBG_B     <= dbg_sel && dbg_sel < `REQ_CONVERT_DBG_B) ? (dbg_sel - `REQ_ARB_DBG_B    ) : 32'd0;
assign dbg_sel_req_convert = (`REQ_CONVERT_DBG_B <= dbg_sel && dbg_sel < `RSP_CONVERT_DBG_B) ? (dbg_sel - `REQ_CONVERT_DBG_B) : 32'd0;
assign dbg_sel_rsp_convert = (`RSP_CONVERT_DBG_B <= dbg_sel && dbg_sel < `DMA_DBG_SIZE     ) ? (dbg_sel - `RSP_CONVERT_DBG_B) : 32'd0;


// Debug signal for DMA_top
assign dbg_bus_dma_top = dbg_signal_dma_top >> {dbg_sel_dma_top, 5'd0};

// Debug signal for wr req
assign dbg_bus_wr_req  = dbg_signal_wr_req >> {dbg_sel_wr_req, 5'd0};

// Debug signal for wreq arbiter
assign dbg_bus_wreq_arb = dbg_signal_wreq_arb >> {dbg_sel_wreq_arb, 5'd0};

// Debug signal for wreq arbiter
assign dbg_bus_req_arb = dbg_signal_req_arb >> {dbg_sel_req_arb, 5'd0};

assign dbg_signal_dma_top = { // 17275
    init_done, // 1
    dma_rd_req_valid, dma_rd_req_last, dma_rd_req_data, dma_rd_req_head, dma_rd_req_ready, // 3483 = 9*387
    dma_rd_rsp_valid, dma_rd_rsp_last, dma_rd_rsp_data, dma_rd_rsp_head, dma_rd_rsp_ready, // 3483 = 9*387
    dma_wr_req_valid, dma_wr_req_last, dma_wr_req_data, dma_wr_req_head, dma_wr_req_ready, // 3096 = 8*387
    s_axis_rq_tvalid, s_axis_rq_tlast, s_axis_rq_tdata, s_axis_rq_tuser, s_axis_rq_tkeep , s_axis_rq_tready, // 327
    m_axis_rc_tvalid, m_axis_rc_tlast, m_axis_rc_tdata, m_axis_rc_tuser, m_axis_rc_tkeep , m_axis_rc_tready, // 342

    cfg_interrupt_msix_enable        , 
    cfg_interrupt_msix_mask          , 
    cfg_interrupt_msix_data          , 
    cfg_interrupt_msix_address       , 
    cfg_interrupt_msix_int           , 
    cfg_interrupt_msix_sent          , 
    cfg_interrupt_msix_fail          , 
    cfg_interrupt_msi_function_number, // 106

    max_pyld_sz,max_rd_req_sz, // 6
    axis_wr_req_tvalid, axis_wr_req_tlast, axis_wr_req_tdata, axis_wr_req_tuser, axis_wr_req_tkeep, axis_wr_req_tready, // 3160=395*8
    axis_wreq_tvalid, axis_wreq_tlast, axis_wreq_tdata, axis_wreq_tuser, axis_wreq_tkeep, axis_wreq_tready, // 395
    axis_rreq_tvalid, axis_rreq_tlast, axis_rreq_tdata, axis_rreq_tuser, axis_rreq_tkeep, axis_rreq_tready, // 395
    axis_req_tvalid, axis_req_tlast, axis_req_tdata, axis_req_tuser, axis_req_tkeep, axis_req_tready, // 395
    pcie_axis_rrsp_tvalid, pcie_axis_rrsp_tlast, pcie_axis_rrsp_tdata, pcie_axis_rrsp_tuser, pcie_axis_rrsp_tkeep, pcie_axis_rrsp_tready, // 395
    dma_axis_rrsp_tvalid, dma_axis_rrsp_tlast, dma_axis_rrsp_tdata, dma_axis_rrsp_tuser, dma_axis_rrsp_tkeep, dma_axis_rrsp_tready, // 395
    dma_axis_rq_tvalid, dma_axis_rq_tlast, dma_axis_rq_tdata, dma_axis_rq_tuser, dma_axis_rq_tkeep, dma_axis_rq_tready, // 327
    // dma_axis_rc_tvalid, dma_axis_rc_tlast, dma_axis_rc_tdata, dma_axis_rc_tuser, dma_axis_rc_tkeep, dma_axis_rc_tready, // 342

    dbg_signal_rq_async, // 885
    // dbg_signal_rc_async  // 34
    dbg_signal_rrsp_async // 84
};
/* -------APB reated signal{end}------- */
`endif

read_req_rsp #(
    
) rd_req_rsp (
    .dma_clk   ( dma_clk    ), // i, 1
    .rst_n     ( rst_n      ), // i, 1
    .init_done ( init_done  ), // o, 1

    /* ------- Read Request from RDMA{begin}------- */
    /* dma_*_head (interact with RDMA modules), valid only in first beat of a packet
    * | Reserved | address | Reserved | Byte length |
    * |  127:96  |  95:32  |  31:13   |    12:0     |
    */
    .dma_rd_req_valid ( dma_rd_req_valid ), // i, `DMA_RD_CHNL_NUM * 1
    .dma_rd_req_last  ( dma_rd_req_last  ), // i, `DMA_RD_CHNL_NUM * 1
    .dma_rd_req_data  ( dma_rd_req_data  ), // i, `DMA_RD_CHNL_NUM * `DMA_DATA_W
    .dma_rd_req_head  ( dma_rd_req_head  ), // i, `DMA_RD_CHNL_NUM * `DMA_HEAD_W
    .dma_rd_req_ready ( dma_rd_req_ready ), // o, `DMA_RD_CHNL_NUM * 1
    /* ------- Read Request from RDMA{end}------- */

    /* ------- Read Response to RDMA{begin} ------- */
    /* dma_*_head (interact with RDMA modules), valid only in first beat of a packet
    * | Reserved | address | Reserved | Byte length |
    * |  127:96  |  95:32  |  31:13   |    12:0     |
    */
    .dma_rd_rsp_valid ( dma_rd_rsp_valid ), // o, `DMA_RD_CHNL_NUM * 1
    .dma_rd_rsp_last  ( dma_rd_rsp_last  ), // o, `DMA_RD_CHNL_NUM * 1
    .dma_rd_rsp_data  ( dma_rd_rsp_data  ), // o, `DMA_RD_CHNL_NUM * `DMA_DATA_W
    .dma_rd_rsp_head  ( dma_rd_rsp_head  ), // o, `DMA_RD_CHNL_NUM * `DMA_HEAD_W
    .dma_rd_rsp_ready ( dma_rd_rsp_ready ), // i, `DMA_RD_CHNL_NUM * 1
    /* ------- Read Response to RDMA{end} ------- */

    /* -------axis read request interface{begin}------- */
    /* AXI-Stream read request tuser, interact with read request arbiter.
    * Only valid in first beat of a packet
    * | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
    * | 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
    */
    .axis_rd_req_tvalid ( axis_rreq_tvalid ), // o, 1
    .axis_rd_req_tlast  ( axis_rreq_tlast  ), // o, 1
    .axis_rd_req_tdata  ( axis_rreq_tdata  ), // o, `DMA_DATA_W
    .axis_rd_req_tuser  ( axis_rreq_tuser  ), // o, `AXIS_TUSER_W
    .axis_rd_req_tkeep  ( axis_rreq_tkeep  ), // o, `DMA_KEEP_W
    .axis_rd_req_tready ( axis_rreq_tready ), // i, 1
    /* -------axis read request interface{end}------- */

    /* -------axis read response interface{begin}------- */
    /* AXI-Stream read response tuser, interact with read response distributor.
     * Only valid in first beat of a packet
     * | Reserved | REQ CPL |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 119:105  |   104   | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     */
    .axis_rd_rsp_tvalid ( dma_axis_rrsp_tvalid ), // i, 1
    .axis_rd_rsp_tlast  ( dma_axis_rrsp_tlast  ), // i, 1
    .axis_rd_rsp_tdata  ( dma_axis_rrsp_tdata  ), // i, `DMA_DATA_W
    .axis_rd_rsp_tuser  ( dma_axis_rrsp_tuser  ), // i, `AXIS_TUSER_W
    .axis_rd_rsp_tkeep  ( dma_axis_rrsp_tkeep  ), // i, `DMA_KEEP_W
    .axis_rd_rsp_tready ( dma_axis_rrsp_tready ), // o, 1
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
    .max_pyld_sz   (  max_pyld_sz   ), // i, 3
    .max_rd_req_sz (  max_rd_req_sz )  // i, 3
    /* -------PCIe fragment property{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.rw_data  ( rw_data_rd_req_rsp )  // i, (2*`DMA_RD_CHNL_NUM+3)*`SRAM_RW_DATA_W
    ,.dbg_sel  ( dbg_sel_rd_req_rsp )  // i, 32
    ,.dbg_bus  ( dbg_bus_rd_req_rsp )  // o, 32
    /* -------APB reated signal{end}------- */
`endif

`ifdef SIMULATION    
    /* ------- Debug interface {begin}------- */
    /* |       reserved       |          idx       | end | out |
     * |  255:CHNL_NUM_LOG+2  | CHNL_NUM_LOG+2-1:2 |  1  |  0  |
     */
    ,.debug_rd ( debug_rd )

    /* | reserved | tag_num | chnl_num | valid |
     * |  255:17  |  16:9   |    8:1   |   0   |
     */
    ,.debug_tag( debug_tag)
    /* ------- Debug interface {end}------- */
`endif
);

genvar i;
generate
for (i = 0; i < `DMA_WR_CHNL_NUM; i = i + 1) begin:DMA_WR_CHNL

    write_request #(
        
    ) wr_req (
        .clk   ( dma_clk    ), // i, 1
        .rst_n ( rst_n      ), // i, 1

        /* -------dma write request interface{begin}------- */
        /* *_head of DMA interface (interact with RDMA modules), 
        * valid only in first beat of a packet.
        * When Transmiting msi-x interrupt message, 'Byte length' 
        * should be 0, 'address' means the address of msi-x, and
        * msi-x data locates in *_data[31:0].
        * | Resvd | Req Type |   address    | Reserved | Byte length |
        * |       | (wr,int) | (msi-x addr) |          | (0 for int) |
        * |-------|----------|--------------|----------|-------------|
        * |127:100|  99:96   |    95:32     |  31:13   |    12:0     |
        */
        .dma_wr_req_valid ( dma_wr_req_valid[(i + 1) * 1           - 1 : i * 1          ] ), // i, 1
        .dma_wr_req_last  ( dma_wr_req_last [(i + 1) * 1           - 1 : i * 1          ] ), // i, 1
        .dma_wr_req_data  ( dma_wr_req_data [(i + 1) * `DMA_DATA_W - 1 : i * `DMA_DATA_W] ), // i, `DMA_DATA_W
        .dma_wr_req_head  ( dma_wr_req_head [(i + 1) * `DMA_HEAD_W - 1 : i * `DMA_HEAD_W] ), // i, `DMA_HEAD_W
        .dma_wr_req_ready ( dma_wr_req_ready[(i + 1) * 1           - 1 : i * 1          ] ), // o, 1
        /* -------dma write request interface{end}------- */

        /* -------axis write request interface{begin}------- */
        /* AXI-Stream write request tuser, only valid in first beat of a packet
        * | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
        * | 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
        * or
        * AXI-Stream interrupt request tuser, only valid in first beat of a packet
        * | Reserved | REQ_TYPE |  Resv  | address | Reserved |
        * | 127:108  | 107:104  | 103:96 |  95:32  |  31:0    |
        */
        .axis_wr_req_tvalid ( axis_wr_req_tvalid[(i+1) * 1             - 1 : i * 1            ] ), // o, 1
        .axis_wr_req_tlast  ( axis_wr_req_tlast [(i+1) * 1             - 1 : i * 1            ] ), // o, 1
        .axis_wr_req_tdata  ( axis_wr_req_tdata [(i+1) * `DMA_DATA_W   - 1 : i * `DMA_DATA_W  ] ), // o, `DMA_DATA_W
        .axis_wr_req_tuser  ( axis_wr_req_tuser [(i+1) * `AXIS_TUSER_W - 1 : i * `AXIS_TUSER_W] ), // o, `AXIS_TUSER_W   ;The field contents are different from dma_*_tuser interface
        .axis_wr_req_tkeep  ( axis_wr_req_tkeep [(i+1) * `DMA_KEEP_W   - 1 : i * `DMA_KEEP_W  ] ), // o, `DMA_KEEP_W
        .axis_wr_req_tready ( axis_wr_req_tready[(i+1) * 1             - 1 : i * 1            ] ), // i, 1
        /* -------axis write request interface{end}------- */


        /* -------PCIe fragment property{begin}------- */
        /* This signal indicates the (max payload size & max read request size) agreed in the communication
        * 3'b000 -- 128 B
        * 3'b001 -- 256 B
        * 3'b010 -- 512 B
        * 3'b011 -- 1024B
        * 3'b100 -- 2048B
        * 3'b101 -- 4096B
        */
        .max_pyld_sz   ( max_pyld_sz   ),
        .max_rd_req_sz ( max_rd_req_sz )  // max read request size
        /* -------PCIe fragment property{end}------- */

    `ifdef PCIEI_APB_DBG
        /* -------APB reated signal{begin}------- */
        ,.rw_data    ( rw_data_wr_req[(i+1)*`SRAM_RW_DATA_W-1:i*`SRAM_RW_DATA_W] ) // i, `SRAM_RW_DATA_W
        ,.dbg_signal ( dbg_signal_wr_req[(i+1)*`WR_REQ_SIGNAL_W-1:i*`WR_REQ_SIGNAL_W] ) // o, `WR_REQ_SIGNAL_W  
        /* -------APB reated signal{end}------- */
    `endif
    );

end
endgenerate

req_arbiter #(
    .CHNL_NUM_LOG     ( `DMA_WR_CHNL_NUM_LOG ),
    .CHANNEL_NUM      ( `DMA_WR_CHNL_NUM     )   // number of slave signals to arbit
) wr_req_arbiter (

    .dma_clk ( dma_clk    ), // i, 1
    .rst_n   ( rst_n      ), // i, 1

    /* -------Slave AXIS Interface(Connect to <Write Request> Module){begin}------- */
    /* AXI-Stream write request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     * or
     * AXI-Stream interrupt request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |  Resv  | address | Reserved |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:0    |
     */
    .s_axis_req_tvalid ( axis_wr_req_tvalid ), // i, 1 * CHANNEL_NUM
    .s_axis_req_tlast  ( axis_wr_req_tlast  ), // i, 1 * CHANNEL_NUM
    .s_axis_req_tdata  ( axis_wr_req_tdata  ), // i, `DMA_DATA_W * CHANNEL_NUM
    .s_axis_req_tuser  ( axis_wr_req_tuser  ), // i, `AXIS_TUSER_W * CHANNEL_NUM  ;The field contents are different from dma_*_tuser interface
    .s_axis_req_tkeep  ( axis_wr_req_tkeep  ), // i, `DMA_KEEP_W * CHANNEL_NUM
    .s_axis_req_tready ( axis_wr_req_tready ), // o, 1 * CHANNEL_NUM
    /* -------Slave AXIS Interface(Connect to <Write Request> Module){end}------- */


    /* ------- Master AXIS Interface(Connect to PCIe or converter){begin} ------- */
    /* AXI-Stream write request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     * or
     * AXI-Stream interrupt request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |  Resv  | address | Reserved |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:0    |
     */
    .m_axis_req_tvalid ( axis_wreq_tvalid ), // o, 1
    .m_axis_req_tlast  ( axis_wreq_tlast  ), // o, 1
    .m_axis_req_tdata  ( axis_wreq_tdata  ), // o, `DMA_DATA_W
    .m_axis_req_tuser  ( axis_wreq_tuser  ), // o, `AXIS_TUSER_W   ;The field contents are different from dma_*_head interface
    .m_axis_req_tkeep  ( axis_wreq_tkeep  ), // o, `DMA_KEEP_W
    .m_axis_req_tready ( axis_wreq_tready )  // i, 1
    /* ------- Master AXIS Interface(Connect to PCIe or converter){end} ------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_signal ( dbg_signal_wreq_arb ) // o, `WREQ_ARB_SIGNAL_W  
    /* -------APB reated signal{end}------- */
`endif

`ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* |       reserved       |          idx       | end | out |
     * |  255:CHNL_NUM_LOG+2  | CHNL_NUM_LOG+2-1:2 |  1  |  0  |
     */
    ,.debug ( debug_wr )
    /* ------- Debug interface {end}------- */
`endif
);

req_arbiter #(
    .CHNL_NUM_LOG     ( 1                ),
    .CHANNEL_NUM      ( 2                )   // number of slave signals to arbit

) req_arbiter (
    .dma_clk ( dma_clk  ), // i, 1
    .rst_n   ( rst_n    ), // i, 1

    /* -------Slave AXIS Interface(Connect to <Write Request> Module){begin}------- */
    /* AXI-Stream request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     * or
     * AXI-Stream interrupt request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |  Resv  | address | Reserved |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:0    |
     */
    .s_axis_req_tvalid ( {axis_wreq_tvalid, axis_rreq_tvalid} ), // i, 1 * CHANNEL_NUM
    .s_axis_req_tlast  ( {axis_wreq_tlast , axis_rreq_tlast } ), // i, 1 * CHANNEL_NUM
    .s_axis_req_tdata  ( {axis_wreq_tdata , axis_rreq_tdata } ), // i, `DMA_DATA_W * CHANNEL_NUM
    .s_axis_req_tuser  ( {axis_wreq_tuser , axis_rreq_tuser } ), // i, `AXIS_TUSER_W * CHANNEL_NUM  ;The field contents are different from dma_*_tuser interface
    .s_axis_req_tkeep  ( {axis_wreq_tkeep , axis_rreq_tkeep } ), // i, `DMA_KEEP_W * CHANNEL_NUM
    .s_axis_req_tready ( {axis_wreq_tready, axis_rreq_tready} ), // o, 1 * CHANNEL_NUM
    /* -------Slave AXIS Interface(Connect to <Write Request> Module){end}------- */

    /* ------- Master AXIS Interface(Connect to PCIe or converter){begin} ------- */
    /* AXI-Stream request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     * or
     * AXI-Stream interrupt request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |  Resv  | address | Reserved |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:0    |
     */
    .m_axis_req_tvalid ( axis_req_tvalid ), // o, 1
    .m_axis_req_tlast  ( axis_req_tlast  ), // o, 1
    .m_axis_req_tdata  ( axis_req_tdata  ), // o, `DMA_DATA_W
    .m_axis_req_tuser  ( axis_req_tuser  ), // o, `AXIS_TUSER_W   ;The field contents are different from dma_*_head interface
    .m_axis_req_tkeep  ( axis_req_tkeep  ), // o, `DMA_KEEP_W
    .m_axis_req_tready ( axis_req_tready )  // i, 1
    /* ------- Master AXIS Interface(Connect to PCIe or converter){end} ------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_signal ( dbg_signal_req_arb ) // o, `REQ_ARB_SIGNAL_W  
    /* -------APB reated signal{end}------- */
`endif
    
`ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* |       reserved       |          idx       | end | out |
     * |  255:CHNL_NUM_LOG+2  | CHNL_NUM_LOG+2-1:2 |  1  |  0  |
     */
    ,.debug (debug_top)
    /* ------- Debug interface {end}------- */
`endif
);


req_converter #(

) req_converter (
    .pcie_clk   ( pcie_clk   ), // i, 1
    .pcie_rst_n ( pcie_rst_n ), // i, 1
    .dma_clk    ( dma_clk    ), // i, 1
    .rst_n      ( rst_n      ), // i, 1


    /* ------- Interface with Request Arbiter{begin} ------- */
    /* AXI-Stream request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     * or
     * AXI-Stream interrupt request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |  Resv  | address | Reserved |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:0    |
     */
    .axis_req_tvalid     ( axis_req_tvalid ), // i, 1
    .axis_req_tlast      ( axis_req_tlast  ), // i, 1
    .axis_req_tdata      ( axis_req_tdata  ), // i, `DMA_DATA_W
    .axis_req_tuser      ( axis_req_tuser  ), // i, `AXIS_TUSER_W
    .axis_req_tkeep      ( axis_req_tkeep  ), // i, `DMA_KEEP_W
    .axis_req_tready     ( axis_req_tready ), // o, 1
    /* ------- Interface with Request Arbiter{end} ------- */

    /* -------dma --> pcie interface{begin}------- */
    // Requester request
    /*  RQ tuser
     * |  59:28 |  27:24  |    23:16   |          15         |   14:13  |      12     |     11      |     10:8    |   7:4   |    3:0   |
     * | parity | seq_num | tph_st_tag | tph_indirect_tag_en | tph_type | tph_present | discontinue | addr_offset | last_be | first_be |
     * |   0    |   0     |     0      |          0          |     0    |      0      |      0      |      0      |         |          |
     */
    .s_axis_rq_tvalid    ( dma_axis_rq_tvalid    ), // o, 1
    .s_axis_rq_tlast     ( dma_axis_rq_tlast     ), // o, 1
    .s_axis_rq_tdata     ( dma_axis_rq_tdata     ), // o, `DMA_DATA_W
    .s_axis_rq_tuser     ( dma_axis_rq_tuser     ), // o, 60
    .s_axis_rq_tkeep     ( dma_axis_rq_tkeep     ), // o, `DMA_KEEP_W
    .s_axis_rq_tready    ( dma_axis_rq_tready    ), // i, 1
    /* -------dma --> pcie interface{end}------- */

    .req_id_in           ( req_id ), // i, 16

    /* -------Interrupt Interface Signals{begin}------- */
    .cfg_interrupt_msix_enable         ( cfg_interrupt_msix_enable         ), // i, 2
    .cfg_interrupt_msix_mask           ( cfg_interrupt_msix_mask           ), // i, 2
    .cfg_interrupt_msix_data           ( cfg_interrupt_msix_data           ), // o, 32
    .cfg_interrupt_msix_address        ( cfg_interrupt_msix_address        ), // o, 64
    .cfg_interrupt_msix_int            ( cfg_interrupt_msix_int            ), // o, 1
    .cfg_interrupt_msix_sent           ( cfg_interrupt_msix_sent           ), // i, 1
    .cfg_interrupt_msix_fail           ( cfg_interrupt_msix_fail           ), // i, 1
    .cfg_interrupt_msi_function_number ( cfg_interrupt_msi_function_number )  // o, 3
    /* -------Interrupt Interface Signals{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.rw_data ( rw_data_int         ) // i, `SRAM_RW_DATA_W
    ,.dbg_sel ( dbg_sel_req_convert ) // i, 32
    ,.dbg_bus ( dbg_bus_req_convert ) // o, 32  
    /* -------APB reated signal{end}------- */
`endif
);

rsp_converter #(

) rsp_converter (
    .dma_clk  ( pcie_clk    ), // i, 1
    .rst_n    ( rst_n      ), // i, 1

    /* ------- pcie --> dma interface{begin}------- */
    // Requester Completion
    /*  RC tuser
     * |  74:43 |      42     |    41:38   |  37:34   |    33    |    32    |  31:0   |  
     * | parity | discontinue |  is_eof_1  | is_eof_0 | is_sof_1 | is_sof_0 | byte_en |
     * | ignore |   ignore    |  ignore    | ignore   |  ignore  |  ignore  |         |
     */
    .m_axis_rc_tvalid   ( m_axis_rc_tvalid  ), // i, 1
    .m_axis_rc_tlast    ( m_axis_rc_tlast   ), // i, 1
    .m_axis_rc_tdata    ( m_axis_rc_tdata   ), // i, `DMA_DATA_W
    .m_axis_rc_tuser    ( m_axis_rc_tuser   ), // i, 75
    .m_axis_rc_tkeep    ( m_axis_rc_tkeep   ), // i, `DMA_KEEP_W
    .m_axis_rc_tready   ( m_axis_rc_tready  ), // o, 1
    /* ------- pcie --> dma interface{end}------- */


    /* ------- Interface with dma read module{begin}------- */
    /* AXI-Stream read response tuser, interact with read response distributor.
     * Only valid in first beat of a packet
     * | Reserved | REQ CPL |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 119:105  |   104   | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     */
    .axis_rd_rsp_tvalid ( pcie_axis_rrsp_tvalid ), // o, 1
    .axis_rd_rsp_tlast  ( pcie_axis_rrsp_tlast  ), // o, 1
    .axis_rd_rsp_tdata  ( pcie_axis_rrsp_tdata  ), // o, `DMA_DATA_W
    .axis_rd_rsp_tuser  ( pcie_axis_rrsp_tuser  ), // o, `AXIS_TUSER_W
    .axis_rd_rsp_tkeep  ( pcie_axis_rrsp_tkeep  ), // o, `DMA_KEEP_W
    .axis_rd_rsp_tready ( pcie_axis_rrsp_tready )  // i, 1
    /* ------- Interface with dma read module{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_sel ( dbg_sel_rsp_convert ) // i, 32
    ,.dbg_bus ( dbg_bus_rsp_convert ) // o, 32  
    /* -------APB reated signal{end}------- */
`endif
);


rq_async_fifos #(
    
) rq_async_fifos (
    .dma_clk    ( dma_clk    ),
    .pcie_clk   ( pcie_clk   ),
    .dma_rst_n  ( rst_n      ),
    .pcie_rst_n ( pcie_rst_n ),

    /* -------rdma write request interface{begin}------- */

    /* -------dma --> pcie interface, dma part{begin}------- */
    // Requester request
    /*  RQ tuser
     * |  59:28 |  27:24  |    23:16   |          15         |   14:13  |      12     |     11      |     10:8    |   7:4   |    3:0   |
     * | parity | seq_num | tph_st_tag | tph_indirect_tag_en | tph_type | tph_present | discontinue | addr_offset | last_be | first_be |
     * |   0    |   0     |     0      |          0          |     0    |      0      |      0      |      0      |         |          |
     */
    .dma_axis_rq_tvalid ( dma_axis_rq_tvalid ), // i, 1
    .dma_axis_rq_tlast  ( dma_axis_rq_tlast  ), // i, 1
    .dma_axis_rq_tdata  ( dma_axis_rq_tdata  ), // i, `DMA_DATA_W
    .dma_axis_rq_tuser  ( dma_axis_rq_tuser  ), // i, 60
    .dma_axis_rq_tkeep  ( dma_axis_rq_tkeep  ), // i, `DMA_KEEP_W
    .dma_axis_rq_tready ( dma_axis_rq_tready ), // o, 1
    /* -------dma --> pcie interface, dma part{end}------- */

    /* -------dma --> pcie interface, pcie part{begin}------- */
    // Requester request
    /*  RQ tuser
     * |  59:28 |  27:24  |    23:16   |          15         |   14:13  |      12     |     11      |     10:8    |   7:4   |    3:0   |
     * | parity | seq_num | tph_st_tag | tph_indirect_tag_en | tph_type | tph_present | discontinue | addr_offset | last_be | first_be |
     * |   0    |   0     |     0      |          0          |     0    |      0      |      0      |      0      |         |          |
     */
    .st_pcie_axis_rq_tvalid ( s_axis_rq_tvalid ), // o, 1
    .st_pcie_axis_rq_tlast  ( s_axis_rq_tlast  ), // o, 1
    .st_pcie_axis_rq_tdata  ( s_axis_rq_tdata  ), // o, `DMA_DATA_W
    .st_pcie_axis_rq_tuser  ( s_axis_rq_tuser  ), // o, 60
    .st_pcie_axis_rq_tkeep  ( s_axis_rq_tkeep  ), // o, `DMA_KEEP_W
    .st_pcie_axis_rq_tready ( s_axis_rq_tready )  // i, 1
    /* -------dma --> pcie interface, pcie part{begin}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.rw_data    ( rw_data_rq          ) // i, `SRAM_RW_DATA_W
    ,.dbg_signal ( dbg_signal_rq_async ) // o, `RQ_ASYNC_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);


// rc_async_fifos #(
    
// ) rc_async_fifos (
//     .dma_clk    ( dma_clk    ),
//     .pcie_clk   ( pcie_clk   ),
//     .dma_rst_n  ( rst_n      ),
//     .pcie_rst_n ( pcie_rst_n ),

//     /* ------- pcie --> dma interface, pcie part{begin}------- */
//     // Requester Completion
//     /*  RC tuser
//      * |  74:43 |      42     |    41:38   |  37:34   |    33    |    32    |  31:0   |  
//      * | parity | discontinue |  is_eof_1  | is_eof_0 | is_sof_1 | is_sof_0 | byte_en |
//      * | ignore |   ignore    |  ignore    | ignore   |  ignore  |  ignore  |         |
//      */
//     .pcie_axis_rc_tvalid ( m_axis_rc_tvalid ), // i, 1
//     .pcie_axis_rc_tlast  ( m_axis_rc_tlast  ), // i, 1
//     .pcie_axis_rc_tdata  ( m_axis_rc_tdata  ), // i, `DMA_DATA_W
//     .pcie_axis_rc_tuser  ( m_axis_rc_tuser  ), // i, 75
//     .pcie_axis_rc_tkeep  ( m_axis_rc_tkeep  ), // i, `DMA_KEEP_W
//     .pcie_axis_rc_tready ( m_axis_rc_tready ), // o, 1
//     /* ------- pcie --> dma interface, pcie part{end}------- */

//     /* ------- pcie --> dma interface, dma part{begin}------- */
//     // Requester Completion
//     /*  RC tuser
//      * |  74:43 |      42     |    41:38   |  37:34   |    33    |    32    |  31:0   |  
//      * | parity | discontinue |  is_eof_1  | is_eof_0 | is_sof_1 | is_sof_0 | byte_en |
//      * | ignore |   ignore    |  ignore    | ignore   |  ignore  |  ignore  |         |
//      */
//     .dma_axis_rc_tvalid ( dma_axis_rc_tvalid ), // o, 1
//     .dma_axis_rc_tlast  ( dma_axis_rc_tlast  ), // o, 1
//     .dma_axis_rc_tdata  ( dma_axis_rc_tdata  ), // o, `DMA_DATA_W
//     .dma_axis_rc_tuser  ( dma_axis_rc_tuser  ), // o, 75
//     .dma_axis_rc_tkeep  ( dma_axis_rc_tkeep  ), // o, `DMA_KEEP_W
//     .dma_axis_rc_tready ( dma_axis_rc_tready )  // i, 1
//     /* ------- pcie --> dma interface, dma part{end}------- */

// `ifdef PCIEI_APB_DBG
//     /* -------APB reated signal{begin}------- */
//     ,.rw_data    ( rw_data_rc          ) // i, `SRAM_RW_DATA_W
//     ,.dbg_signal ( dbg_signal_rc_async ) // o, `RC_ASYNC_SIGNAL_W
//     /* -------APB reated signal{end}------- */
// `endif
// );

rrsp_async_fifos #(

) rrsp_async_fifos (
    .dma_clk    ( dma_clk    ),
    .pcie_clk   ( pcie_clk   ),
    .dma_rst_n  ( rst_n      ),
    .pcie_rst_n ( pcie_rst_n ),

    /* ------- pcie clock domain{begin}------- */
    /* AXI-Stream read response tuser, interact with read response distributor.
     * Only valid in first beat of a packet
     * | Reserved | REQ CPL |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 119:105  |   104   | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     */
    .pcie_axis_rrsp_tvalid ( pcie_axis_rrsp_tvalid ), // i, 1
    .pcie_axis_rrsp_tlast  ( pcie_axis_rrsp_tlast  ), // i, 1
    .pcie_axis_rrsp_tdata  ( pcie_axis_rrsp_tdata  ), // i, `DMA_DATA_W
    .pcie_axis_rrsp_tuser  ( pcie_axis_rrsp_tuser  ), // i, `AXIS_TUSER_W
    .pcie_axis_rrsp_tkeep  ( pcie_axis_rrsp_tkeep  ), // i, `DMA_KEEP_W
    .pcie_axis_rrsp_tready ( pcie_axis_rrsp_tready ), // o, 1
    /* ------- pcie clock domain{end}------- */

    /* ------- dma clock domain{begin}------- */
    /* AXI-Stream read response tuser, interact with read response distributor.
     * Only valid in first beat of a packet
     * | Reserved | REQ CPL |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 119:105  |   104   | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     */
    .dma_axis_rrsp_tvalid ( dma_axis_rrsp_tvalid ), // o, 1
    .dma_axis_rrsp_tlast  ( dma_axis_rrsp_tlast  ), // o, 1
    .dma_axis_rrsp_tdata  ( dma_axis_rrsp_tdata  ), // o, `DMA_DATA_W
    .dma_axis_rrsp_tuser  ( dma_axis_rrsp_tuser  ), // o, `AXIS_TUSER_W
    .dma_axis_rrsp_tkeep  ( dma_axis_rrsp_tkeep  ), // o, `DMA_KEEP_W
    .dma_axis_rrsp_tready ( dma_axis_rrsp_tready )  // i, 1
    /* ------- dma clock domain{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.rw_data    ( rw_data_rc          ) // i, `SRAM_RW_DATA_W
    ,.dbg_signal ( dbg_signal_rrsp_async ) // o, `RRSP_ASYNC_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

endmodule
