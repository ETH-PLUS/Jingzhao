`timescale 1ns / 100ps
//*************************************************************************
// > File   : STD_PIO.v
// > Author : Kangning
// > Date   : 2022-03-11
// > Note   : Interface for pio access.
// >          V1.0 -- An standard PIO module, Top module of PIO.
// >            Note that:
// >            1. we sassume the packet must be 4KB aligned.
//*************************************************************************


module STD_PIO #(
    parameter AXIL_DATA_WIDTH   = 32 ,
    parameter AXIL_ADDR_WIDTH   = 24 ,

    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8)
)(
    input  wire                      pcie_clk  ,
    input  wire                      pcie_rst_n,
    input  wire                      user_clk  ,
    input  wire                      rst_n     ,

    input  wire                      init_done , // i, 1

    /* -------Completer Requester{begin}------- */
    /*  CQ tuser
     * |  84:53 |    52:45   |   44:43  |      42     |     41      | 40  |  39:8   |   7:4   |    3:0   |
     * | parity | tph_st_tag | tph_type | tph_present | discontinue | sop | byte_en | last_be | first_be |
     * |   0    |     0      |     0    |             |             |     | ignore  |         |          |
     */
    input  wire                       m_axis_cq_tvalid,
    input  wire                       m_axis_cq_tlast ,
    input  wire [84           :0]     m_axis_cq_tuser ,
    input  wire [`PIO_KEEP_W-1:0]     m_axis_cq_tkeep ,
    input  wire [`PIO_DATA_W-1:0]     m_axis_cq_tdata ,
    output wire                       m_axis_cq_tready,
    /* -------Completer Requester{end}------- */

    /* -------Completer Completion{begin}------- */
    /*  CC tuser
     * |  32:1  |      0      |
     * | parity | discontinue |
     * | ignore |   ignore    |
     */
    output wire [`PIO_DATA_W-1:0]     s_axis_cc_tdata ,
    output wire                       s_axis_cc_tlast ,
    output wire [32           :0]     s_axis_cc_tuser ,
    output wire [`PIO_KEEP_W-1:0]     s_axis_cc_tkeep ,
    output wire                       s_axis_cc_tvalid,
    input  wire                       s_axis_cc_tready,
    /* -------Completer Completion{end}------- */

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
    input wire [2:0] max_rd_req_sz, // max read request size
    /* -------PCIe fragment property{end}------- */

    /* -------pio <--> RDMA interface{begin}------- */
    output  wire [63:0]                 pio_hcr_in_param      ,
    output  wire [31:0]                 pio_hcr_in_modifier   ,
    output  wire [63:0]                 pio_hcr_out_dma_addr  ,
    input   wire [63:0]                 pio_hcr_out_param     ,
    output  wire [15:0]                 pio_hcr_token         ,
    input   wire [ 7:0]                 pio_hcr_status        ,
    output  wire                        pio_hcr_go            ,
    input   wire                        pio_hcr_clear         ,
    output  wire                        pio_hcr_event         ,
    output  wire [ 7:0]                 pio_hcr_op_modifier   ,
    output  wire [11:0]                 pio_hcr_op            ,
    /* -------pio <-->RDMA interface{end}------- */

    /* --------SQ Doorbell{begin}-------- */
    output wire           pio_uar_db_valid, // o, 1
    output wire [63:0]    pio_uar_db_data , // o, 64
    input  wire           pio_uar_db_ready, // i, 1
    /* --------SQ Doorbell{end}-------- */

    /* --------ARM CQ interface{begin}-------- */
    input  wire          cq_ren , // i, 1
    input  wire [31:0]   cq_num , // i, 32
    output wire          cq_dout, // o, 1
    /* --------ARM CQ interface{end}-------- */
    
    /* --------ARM EQ interface{begin}-------- */
    input  wire          eq_ren , // i, 1
    input  wire [31:0]   eq_num , // i, 31
    output wire          eq_dout, // o, 1
    /* --------ARM EQ interface{end}-------- */

    /* --------Interrupt Vector entry request & response{begin}-------- */
    input  wire                          pio_eq_int_req_valid, // i, 1
    input  wire [`RDMA_MSIX_NUM_LOG-1:0] pio_eq_int_req_num  , // i, `RDMA_MSIX_NUM_LOG
    output wire                          pio_eq_int_req_ready, // o, 1

    output wire                          pio_eq_int_rsp_valid, // o, 1
    output wire [`RDMA_MSIX_DATA_W -1:0] pio_eq_int_rsp_data , // o, `RDMA_MSIX_DATA_W
    input  wire                          pio_eq_int_rsp_ready, // i, 1
    /* -------Interrupt Vector entry request & response{end}-------- */

    /* -------Reset signal{begin}------- */
    output wire                         cmd_rst,
    /* -------Reset signal{end}------- */

    /* --------Interact with Ethernet BAR{begin}------- */
    output wire [AXIL_ADDR_WIDTH-1:0]    m_axil_awaddr ,
    output wire                          m_axil_awvalid,
    input  wire                          m_axil_awready,

    output wire [AXIL_DATA_WIDTH-1:0]    m_axil_wdata ,
    output wire [AXIL_STRB_WIDTH-1:0]    m_axil_wstrb , // byte select
    output wire                          m_axil_wvalid,
    input  wire                          m_axil_wready,

    input  wire                          m_axil_bvalid,
    output wire                          m_axil_bready,

    output wire [AXIL_ADDR_WIDTH-1:0]    m_axil_araddr ,
    output wire                          m_axil_arvalid,
    input  wire                          m_axil_arready,
    
    input  wire [AXIL_DATA_WIDTH-1:0]    m_axil_rdata ,
    input  wire                          m_axil_rvalid,
    output wire                          m_axil_rready,
    /* --------Interact with Ethernet BAR{end}------- */

    /* --------P2P Configuration Channel{begin}-------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    output wire [1           - 1 : 0] p2p_cfg_req_valid, // o, 1
    output wire [1           - 1 : 0] p2p_cfg_req_last , // o, 1
    output wire [`PIO_DATA_W - 1 : 0] p2p_cfg_req_data , // o, `PIO_DATA_W
    output wire [`P2P_HEAD_W - 1 : 0] p2p_cfg_req_head , // o, `P2P_HEAD_W
    input  wire [1           - 1 : 0] p2p_cfg_req_ready, // i, 1
    
    input  wire [1           - 1 : 0] p2p_cfg_rrsp_valid, // i, 1
    input  wire [1           - 1 : 0] p2p_cfg_rrsp_last , // i, 1
    input  wire [`PIO_DATA_W - 1 : 0] p2p_cfg_rrsp_data , // i, `PIO_DATA_W
    output wire [1           - 1 : 0] p2p_cfg_rrsp_ready, // o, 1
    /* --------P2P Configuration Channel{end}-------- */

    /* -------P2P Memory Access Channel{begin}-------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    output wire [1           - 1 : 0] p2p_mem_req_valid, // o, 1
    output wire [1           - 1 : 0] p2p_mem_req_last , // o, 1
    output wire [`PIO_DATA_W - 1 : 0] p2p_mem_req_data , // o, `PIO_DATA_W
    output wire [`P2P_HEAD_W - 1 : 0] p2p_mem_req_head , // o, `P2P_HEAD_W
    input  wire [1           - 1 : 0] p2p_mem_req_ready  // i, 1
    /* -------P2P Memory Access Channel{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [`SRAM_RW_DATA_W*8-1:0] rw_data // i, `SRAM_RW_DATA_W*8
    ,input  wire [31:0] dbg_sel  // i, 32
    ,output wire [31:0] dbg_bus  // o, 32    
    /* -------APB reated signal{end}------- */
`endif

`ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved | reserved | idx | end | out |
     * |  255:10  |   9:5    | 4:2 |  1  |  0  |
     */
    ,output wire [255:0] debug
    /* ------- Debug interface {end}------- */
`endif
);

/* -------Async fifo{begin}------- */
wire                   cq_tvalid;
wire                   cq_tlast ;
wire [84           :0] cq_tuser ;
wire [`PIO_DATA_W-1:0] cq_tdata ;
wire                   cq_tready;

wire                   cc_tvalid;
wire                   cc_tlast ;
wire [`PIO_KEEP_W-1:0] cc_tkeep ;
wire [`PIO_DATA_W-1:0] cc_tdata ;
wire                   cc_tready;

wire                   cq_full, cq_empty;
/* -------Async fifo{end}------- */

/* --------PIO Request interface{begin}-------- */
wire [`PIO_DATA_W-1:0] axis_req_tdata ;
wire [`PIO_USER_W-1:0] axis_req_tuser ;
wire                   axis_req_tlast ;
wire                   axis_req_tvalid;
wire                   axis_req_tready;
/* --------PIO Request interface{end}-------- */

/* ---------PIO Response interface{begin}-------- */
wire [`PIO_DATA_W-1:0] axis_rrsp_tdata ;
wire [`PIO_USER_W-1:0] axis_rrsp_tuser ;
wire                   axis_rrsp_tlast ;
wire                   axis_rrsp_tvalid;
wire                   axis_rrsp_tready; 
/* ---------PIO Response interface{end}-------- */


/* ---------Splited PIO Interface{begin}-------- */
// register request
wire [`PIO_DATA_W-1:0] pio_uar_req_data , pio_p2p_mem_req_data , pio_p2p_cfg_req_data , pio_int_req_data , pio_eth_req_data , pio_hcr_req_data ;
wire [`PIO_HEAD_W-1:0] pio_uar_req_head , pio_p2p_mem_req_head , pio_p2p_cfg_req_head , pio_int_req_head , pio_eth_req_head , pio_hcr_req_head ;
wire [1          -1:0] pio_uar_req_last , pio_p2p_mem_req_last , pio_p2p_cfg_req_last , pio_int_req_last , pio_eth_req_last , pio_hcr_req_last ;
wire [1          -1:0] pio_uar_req_valid, pio_p2p_mem_req_valid, pio_p2p_cfg_req_valid, pio_int_req_valid, pio_eth_req_valid, pio_hcr_req_valid;
wire [1          -1:0] pio_uar_req_ready, pio_p2p_mem_req_ready, pio_p2p_cfg_req_ready, pio_int_req_ready, pio_eth_req_ready, pio_hcr_req_ready;

// register read response
wire [`PIO_DATA_W-1:0] pio_p2p_rrsp_data , pio_int_rrsp_data , pio_eth_rrsp_data , pio_hcr_rrsp_data ;
wire [`PIO_HEAD_W-1:0] pio_p2p_rrsp_head , pio_int_rrsp_head , pio_eth_rrsp_head , pio_hcr_rrsp_head ;
wire [1          -1:0] pio_p2p_rrsp_last , pio_int_rrsp_last , pio_eth_rrsp_last , pio_hcr_rrsp_last ;
wire [1          -1:0] pio_p2p_rrsp_valid, pio_int_rrsp_valid, pio_eth_rrsp_valid, pio_hcr_rrsp_valid;
wire [1          -1:0] pio_p2p_rrsp_ready, pio_int_rrsp_ready, pio_eth_rrsp_ready, pio_hcr_rrsp_ready;
/* --------Splited PIO Interface{end}-------- */


`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire [1:0] cq_rtsel;
wire [1:0] cq_wtsel;
wire [1:0] cq_ptsel;
wire       cq_vg   ;
wire       cq_vs   ;
wire [`SRAM_RW_DATA_W-1:0] rw_data_cq, rw_data_cc;
wire [2*`SRAM_RW_DATA_W-1:0] rw_data_rdma_uar;
wire [4*`SRAM_RW_DATA_W-1:0] rw_data_rdma_int;
wire [31:0] dbg_sel_std_pio_top, dbg_sel_cq_parser, dbg_sel_cc_composer, dbg_sel_pio_req, 
            dbg_sel_pio_rrsp, dbg_sel_rdma_uar, dbg_sel_rdma_int, dbg_sel_rdma_hcr, 
            dbg_sel_eth_cfg, dbg_sel_p2p_access;
wire [31:0] dbg_bus_std_pio_top, dbg_bus_cq_parser, dbg_bus_cc_composer, dbg_bus_pio_req, 
            dbg_bus_pio_rrsp, dbg_bus_rdma_uar, dbg_bus_rdma_int, dbg_bus_rdma_hcr, 
            dbg_bus_eth_cfg, dbg_bus_p2p_access;
wire [`STD_PIO_TOP_SIGNAL_W-1:0] dbg_signal_std_pio_top;
wire [`CC_ASYNC_SIGNAL_W-1:0] dbg_signal_cc;
/* -------APB reated signal{end}------- */
`endif

//----------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign {cq_rtsel, cq_wtsel, cq_ptsel, cq_vg, cq_vs} = rw_data_cq;
assign {rw_data_cq, rw_data_cc, rw_data_rdma_uar, rw_data_rdma_int} = rw_data;

assign dbg_sel_std_pio_top   = (`PIO_TOP_DBG_B     <= dbg_sel && dbg_sel < `CQ_PARSER_DBG_B  ) ? (dbg_sel - `PIO_TOP_DBG_B    ) : 32'd0;
assign dbg_sel_cq_parser     = (`CQ_PARSER_DBG_B   <= dbg_sel && dbg_sel < `CC_COMPOSER_DBG_B) ? (dbg_sel - `CQ_PARSER_DBG_B  ) : 32'd0;
assign dbg_sel_cc_composer   = (`CC_COMPOSER_DBG_B <= dbg_sel && dbg_sel < `PIO_REQ_DBG_B    ) ? (dbg_sel - `CC_COMPOSER_DBG_B) : 32'd0;
assign dbg_sel_pio_req       = (`PIO_REQ_DBG_B     <= dbg_sel && dbg_sel < `PIO_RRSP_DBG_B   ) ? (dbg_sel - `PIO_REQ_DBG_B    ) : 32'd0;
assign dbg_sel_pio_rrsp      = (`PIO_RRSP_DBG_B    <= dbg_sel && dbg_sel < `RDMA_UAR_DBG_B   ) ? (dbg_sel - `PIO_RRSP_DBG_B   ) : 32'd0;
assign dbg_sel_rdma_uar      = (`RDMA_UAR_DBG_B    <= dbg_sel && dbg_sel < `RDMA_INT_DBG_B   ) ? (dbg_sel - `RDMA_UAR_DBG_B   ) : 32'd0;
assign dbg_sel_rdma_int      = (`RDMA_INT_DBG_B    <= dbg_sel && dbg_sel < `RDMA_HCR_DBG_B   ) ? (dbg_sel - `RDMA_INT_DBG_B   ) : 32'd0;
assign dbg_sel_rdma_hcr      = (`RDMA_HCR_DBG_B    <= dbg_sel && dbg_sel < `ETH_CFG_DBG_B    ) ? (dbg_sel - `RDMA_HCR_DBG_B   ) : 32'd0;
assign dbg_sel_eth_cfg       = (`ETH_CFG_DBG_B     <= dbg_sel && dbg_sel < `P2P_ACCESS_DBG_B ) ? (dbg_sel - `ETH_CFG_DBG_B    ) : 32'd0;
assign dbg_sel_p2p_access    = (`P2P_ACCESS_DBG_B  <= dbg_sel && dbg_sel < `STD_PIO_DBG_SIZE ) ? (dbg_sel - `P2P_ACCESS_DBG_B ) : 32'd0;
assign dbg_bus = (`PIO_TOP_DBG_B     <= dbg_sel && dbg_sel < `CQ_PARSER_DBG_B  ) ? dbg_bus_std_pio_top : 
                 (`CQ_PARSER_DBG_B   <= dbg_sel && dbg_sel < `CC_COMPOSER_DBG_B) ? dbg_bus_cq_parser   : 
                 (`CC_COMPOSER_DBG_B <= dbg_sel && dbg_sel < `PIO_REQ_DBG_B    ) ? dbg_bus_cc_composer : 
                 (`PIO_REQ_DBG_B     <= dbg_sel && dbg_sel < `PIO_RRSP_DBG_B   ) ? dbg_bus_pio_req     : 
                 (`PIO_RRSP_DBG_B    <= dbg_sel && dbg_sel < `RDMA_UAR_DBG_B   ) ? dbg_bus_pio_rrsp    : 
                 (`RDMA_UAR_DBG_B    <= dbg_sel && dbg_sel < `RDMA_INT_DBG_B   ) ? dbg_bus_rdma_uar    : 
                 (`RDMA_INT_DBG_B    <= dbg_sel && dbg_sel < `RDMA_HCR_DBG_B   ) ? dbg_bus_rdma_int    : 
                 (`RDMA_HCR_DBG_B    <= dbg_sel && dbg_sel < `ETH_CFG_DBG_B    ) ? dbg_bus_rdma_hcr    : 
                 (`ETH_CFG_DBG_B     <= dbg_sel && dbg_sel < `P2P_ACCESS_DBG_B ) ? dbg_bus_eth_cfg     : 
                 (`P2P_ACCESS_DBG_B  <= dbg_sel && dbg_sel < `STD_PIO_DBG_SIZE ) ? dbg_bus_p2p_access  : 32'd0;

// Debug signal for pio_top
assign dbg_bus_std_pio_top = dbg_signal_std_pio_top >> {dbg_sel_std_pio_top, 5'd0};

assign dbg_signal_std_pio_top = { // 8323
    init_done, // 1
    m_axis_cq_tvalid, m_axis_cq_tlast, m_axis_cq_tuser, m_axis_cq_tkeep, m_axis_cq_tdata, m_axis_cq_tready, // 352
    s_axis_cc_tdata, s_axis_cc_tlast, s_axis_cc_tuser, s_axis_cc_tkeep, s_axis_cc_tvalid, s_axis_cc_tready, // 300
    max_pyld_sz, max_rd_req_sz, // 6

    pio_hcr_in_param, pio_hcr_in_modifier, pio_hcr_out_dma_addr, pio_hcr_out_param, 
    pio_hcr_token, pio_hcr_status, pio_hcr_go, pio_hcr_clear, pio_hcr_event, pio_hcr_op_modifier, pio_hcr_op, // 271

    pio_uar_db_valid, pio_uar_db_data, pio_uar_db_ready, // 66
    cq_ren, cq_num, cq_dout, eq_ren, eq_num, eq_dout, // 68

    pio_eq_int_req_valid, pio_eq_int_req_num, pio_eq_int_req_ready, 
    pio_eq_int_rsp_valid, pio_eq_int_rsp_data, pio_eq_int_rsp_ready, // 138

    cmd_rst, // 1
    
    m_axil_awaddr, m_axil_awvalid, m_axil_awready, 
    m_axil_wdata, m_axil_wstrb, m_axil_wvalid, m_axil_wready, 
    m_axil_bvalid, m_axil_bready, // 66

    m_axil_araddr, m_axil_arvalid, m_axil_arready, m_axil_rdata, m_axil_rvalid, m_axil_rready, // 60
    p2p_cfg_req_valid, p2p_cfg_req_last, p2p_cfg_req_data, p2p_cfg_req_head, p2p_cfg_req_ready, // 387
    p2p_cfg_rrsp_valid, p2p_cfg_rrsp_last, p2p_cfg_rrsp_data, p2p_cfg_rrsp_ready, // 259
    p2p_mem_req_valid, p2p_mem_req_last, p2p_mem_req_data, p2p_mem_req_head, p2p_mem_req_ready, // 387
    cq_tvalid, cq_tlast, cq_tuser, cq_tdata, cq_tready, // 344
    cc_tvalid, cc_tlast, cc_tkeep, cc_tdata, cc_tready, // 267
    cq_full, cq_empty, // 2

    axis_req_tdata, axis_req_tuser, axis_req_tlast, axis_req_tvalid, axis_req_tready,
    axis_rrsp_tdata, axis_rrsp_tuser, axis_rrsp_tlast, axis_rrsp_tvalid, axis_rrsp_tready, // 798

    pio_uar_req_data, pio_p2p_mem_req_data, pio_p2p_cfg_req_data, pio_int_req_data, pio_eth_req_data, pio_hcr_req_data, 
    pio_uar_req_head, pio_p2p_mem_req_head, pio_p2p_cfg_req_head, pio_int_req_head, pio_eth_req_head, pio_hcr_req_head, 
    pio_uar_req_last, pio_p2p_mem_req_last, pio_p2p_cfg_req_last, pio_int_req_last, pio_eth_req_last, pio_hcr_req_last, 
    pio_uar_req_valid, pio_p2p_mem_req_valid, pio_p2p_cfg_req_valid, pio_int_req_valid, pio_eth_req_valid, pio_hcr_req_valid, 
    pio_uar_req_ready, pio_p2p_mem_req_ready, pio_p2p_cfg_req_ready, pio_int_req_ready, pio_eth_req_ready, pio_hcr_req_ready, // 2346

    pio_p2p_rrsp_data, pio_int_rrsp_data, pio_eth_rrsp_data, pio_hcr_rrsp_data,
    pio_p2p_rrsp_head, pio_int_rrsp_head, pio_eth_rrsp_head, pio_hcr_rrsp_head,
    pio_p2p_rrsp_last, pio_int_rrsp_last, pio_eth_rrsp_last, pio_hcr_rrsp_last,
    pio_p2p_rrsp_valid, pio_int_rrsp_valid, pio_eth_rrsp_valid, pio_hcr_rrsp_valid, 
    pio_p2p_rrsp_ready, pio_int_rrsp_ready, pio_eth_rrsp_ready, pio_hcr_rrsp_ready, // 1564

    dbg_signal_cc // CC_ASYNC_SIGNAL_W (640)
};
/* -------APB reated signal{end}------- */
`endif

assign m_axis_cq_tready = !cq_full;
assign cq_tvalid        = !cq_empty;
pcieifc_async_fifo #(
    .DATA_WIDTH   ( 1 + 8 + 1 + `PIO_DATA_W ), // sop + first_be + last_be + last + data
    .ADDR_WIDTH   ( 5   )
) cq_async_fifo (
    .wr_clk ( pcie_clk   ), // i, 1
    .rd_clk ( user_clk   ), // i, 1
    .wrst_n ( pcie_rst_n ), // i, 1
    .rrst_n ( rst_n      ), // i, 1

    .wen  ( m_axis_cq_tvalid & m_axis_cq_tready ), // i, 1
    .din  ( {m_axis_cq_tuser[40], m_axis_cq_tuser[7:0], m_axis_cq_tlast, m_axis_cq_tdata}  ), // i, DATA_WIDTH
    .full (  cq_full         ), // o, 1

    .ren   ( cq_tready & cq_tvalid ), // i, 1
    .dout  ( {cq_tuser[40], cq_tuser[7:0], cq_tlast, cq_tdata}  ), // o, DATA_WIDTH
    .empty ( cq_empty  )  // o, 1

`ifdef PCIEI_APB_DBG
    ,.rtsel ( cq_rtsel )  // i, 2
    ,.wtsel ( cq_wtsel )  // i, 2
    ,.ptsel ( cq_ptsel )  // i, 2
    ,.vg    ( cq_vg    )  // i, 1
    ,.vs    ( cq_vs    )  // i, 1
`endif
);
assign cq_tuser[84:41] = 0;
assign cq_tuser[39:8]  = 0;

cc_async_fifos cc_async_fifos (
    .user_clk   ( user_clk   ),
    .pcie_clk   ( pcie_clk   ),
    .user_rst_n ( rst_n      ),
    .pcie_rst_n ( pcie_rst_n ),

    /* -------std_pio --> pcie interface, pio part{begin}------- */
    .pio_axis_cc_tvalid ( cc_tvalid ), // i, 1
    .pio_axis_cc_tlast  ( cc_tlast  ), // i, 1
    .pio_axis_cc_tdata  ( cc_tdata  ), // i, `PIO_DATA_W
    .pio_axis_cc_tuser  ( 33'd0     ), // i, 33
    .pio_axis_cc_tkeep  ( cc_tkeep  ), // i, `PIO_KEEP_W
    .pio_axis_cc_tready ( cc_tready ), // o, 1
    /* -------std_pio --> pcie interface, pio part{end}------- */

    /* -------std_pio --> pcie interface, pcie part{begin}------- */
    /*  CC tuser
     * |  32:1  |      0      |
     * | parity | discontinue |
     * | ignore |   ignore    |
     */
    .st_pcie_axis_cc_tvalid ( s_axis_cc_tvalid ), // o, 1
    .st_pcie_axis_cc_tlast  ( s_axis_cc_tlast  ), // o, 1
    .st_pcie_axis_cc_tdata  ( s_axis_cc_tdata  ), // o, `PIO_DATA_W
    .st_pcie_axis_cc_tuser  ( s_axis_cc_tuser  ), // o, 33
    .st_pcie_axis_cc_tkeep  ( s_axis_cc_tkeep  ), // o, `PIO_KEEP_W
    .st_pcie_axis_cc_tready ( s_axis_cc_tready )  // i, 1
    /* -------std_pio --> pcie interface, pcie part{begin}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.rw_data    ( rw_data_cc ) // i, `SRAM_RW_DATA_W  
    ,.dbg_signal ( dbg_signal_cc ) // o, `CC_ASYNC_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

cq_parser #(
    
) cq_parser (
    .clk             ( user_clk ), // i, 1
    .rst_n           ( rst_n    ), // i, 1

    /* -------Completer Requester{begin}------- */
    /*  CQ tuser
     * |  84:53 |    52:45   |   44:43  |      42     |     41      | 40  |  39:8   |   7:4   |    3:0   |
     * | parity | tph_st_tag | tph_type | tph_present | discontinue | sop | byte_en | last_be | first_be |
     * |   0    |     0      |     0    |             |             |     | ignore  |         |          |
     */
    .cq_tuser                                ( cq_tuser  ), // i , 85
    .cq_tdata                                ( cq_tdata  ), // i, `PIO_DATA_W
    .cq_tlast                                ( cq_tlast  ), // i, 1
    .cq_tvalid                               ( cq_tvalid ), // i, 1
    .cq_tready                               ( cq_tready ), // o, 1
    /* -------Completer Requester{end}------- */

    /* --------PIO Request intterface{begin}-------- */
    /* tuser
     * |  139  | 138:136 |  135:132 | 131:128 |    127:96    |   95:0  |
     * | is_wr | bar_id  | first_be | last_be | aligned_addr | cc_head |
     * |       |         |          |         |              |         |
     */
    .m_axis_req_tdata                        ( axis_req_tdata  ), // o, `PIO_DATA_W
    .m_axis_req_tuser                        ( axis_req_tuser  ), // o, `PIO_USER_W
    .m_axis_req_tlast                        ( axis_req_tlast  ), // o, 1
    .m_axis_req_tvalid                       ( axis_req_tvalid ), // o, 1
    .m_axis_req_tready                       ( axis_req_tready )  // i, 1
    /* --------PIO Request intterface{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_sel ( dbg_sel_cq_parser ) // i, 32; debug bus select
    ,.dbg_bus ( dbg_bus_cq_parser ) // o, 32; debug bus data    
    /* -------APB reated signal{end}------- */
`endif
);

cc_composer #(
    
) cc_composer (
    .clk             ( user_clk ), // i, 1
    .rst_n           ( rst_n    ), // i, 1

    /* -------Completer Completion{begin}------- */
    /*  CC tuser
     * |  32:1  |      0      |
     * | parity | discontinue |
     * | ignore |   ignore    |
     */
    .cc_tdata                                ( cc_tdata  ), // o, `PIO_DATA_W
    .cc_tlast                                ( cc_tlast  ), // o, 1
    .cc_tkeep                                ( cc_tkeep  ), // o, `PIO_KEEP_W
    .cc_tvalid                               ( cc_tvalid ), // o, 1
    .cc_tready                               ( cc_tready ), // i, 1
    /* -------Completer Completion{end}------- */

    /* --------PIO Response interface{begin}-------- */
    /* tuser
     * |  139  | 138:136 |  135:132 | 131:128 |    127:96    |   95:0  |
     * | is_wr | bar_id  | first_be | last_be | aligned_addr | cc_head |
     * |       |         |          |         |              |         |
     */
    .s_axis_rrsp_tdata                        ( axis_rrsp_tdata  ), // i, `PIO_DATA_W
    .s_axis_rrsp_tuser                        ( axis_rrsp_tuser  ), // i, `PIO_USER_W
    .s_axis_rrsp_tlast                        ( axis_rrsp_tlast  ), // i, 1
    .s_axis_rrsp_tvalid                       ( axis_rrsp_tvalid ), // i, 1
    .s_axis_rrsp_tready                       ( axis_rrsp_tready )  // o, 1
    /* --------PIO Response interface{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_sel ( dbg_sel_cc_composer ) // i, 32; debug bus select
    ,.dbg_bus ( dbg_bus_cc_composer ) // o, 32; debug bus data    
    /* -------APB reated signal{end}------- */
`endif
);

pio_req #(
    .CHANNEL_NUM                ( 6            )
) pio_req (
    .clk             ( user_clk ), // i, 1
    .rst_n           ( rst_n    ), // i, 1

    /* --------PIO Request interface{begin}-------- */
    /* pio_tuser
     * |  139  | 138:136 |  135:132 | 131:128 |    127:96    |   95:0  |
     * | is_wr | bar_id  | first_be | last_be | aligned_addr | cc_head |
     * |       |         |          |         |              |         |
     */
    .s_axis_req_tdata        ( axis_req_tdata  ), // i, `PIO_DATA_W
    .s_axis_req_tuser        ( axis_req_tuser  ), // i, `PIO_USER_W
    .s_axis_req_tlast        ( axis_req_tlast  ), // i, 1
    .s_axis_req_tvalid       ( axis_req_tvalid ), // i, 1
    .s_axis_req_tready       ( axis_req_tready ), // o, 1

    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    .m_axis_req_data        ( {pio_uar_req_data , pio_p2p_mem_req_data , pio_p2p_cfg_req_data , pio_int_req_data , pio_eth_req_data , pio_hcr_req_data } ), // o, CHANNEL_NUM * `PIO_DATA_W
    .m_axis_req_head        ( {pio_uar_req_head , pio_p2p_mem_req_head , pio_p2p_cfg_req_head , pio_int_req_head , pio_eth_req_head , pio_hcr_req_head } ), // o, CHANNEL_NUM * `PIO_HEAD_W
    .m_axis_req_last        ( {pio_uar_req_last , pio_p2p_mem_req_last , pio_p2p_cfg_req_last , pio_int_req_last , pio_eth_req_last , pio_hcr_req_last } ), // o, CHANNEL_NUM * 1
    .m_axis_req_valid       ( {pio_uar_req_valid, pio_p2p_mem_req_valid, pio_p2p_cfg_req_valid, pio_int_req_valid, pio_eth_req_valid, pio_hcr_req_valid} ), // o, CHANNEL_NUM * 1
    .m_axis_req_ready       ( {pio_uar_req_ready, pio_p2p_mem_req_ready, pio_p2p_cfg_req_ready, pio_int_req_ready, pio_eth_req_ready, pio_hcr_req_ready} )  // i, CHANNEL_NUM * 1
    /* --------PIO Request interface{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_sel ( dbg_sel_pio_req ) // i, 32; debug bus select
    ,.dbg_bus ( dbg_bus_pio_req ) // o, 32; debug bus data    
    /* -------APB reated signal{end}------- */
`endif
);

pio_rrsp #(
    .CHANNEL_NUM                 ( 4              )
) pio_rrsp (
    .clk             ( user_clk ), // i, 1
    .rst_n           ( rst_n    ), // i, 1

    /* --------PIO Request interface{begin}-------- */
    /* pio_tuser
     * |  139  | 138:136 |  135:132 | 131:128 |    127:96    |   95:0  |
     * | is_wr | bar_id  | first_be | last_be | aligned_addr | cc_head |
     * |       |         |          |         |              |         |
     */
    .m_axis_rrsp_tdata   ( axis_rrsp_tdata  ), // o, `PIO_DATA_W
    .m_axis_rrsp_tuser   ( axis_rrsp_tuser  ), // o, `PIO_USER_W
    .m_axis_rrsp_tlast   ( axis_rrsp_tlast  ), // o, 1
    .m_axis_rrsp_tvalid  ( axis_rrsp_tvalid ), // o, 1
    .m_axis_rrsp_tready  ( axis_rrsp_tready ), // i, 1
    /* --------PIO Request interface{end}-------- */

    /* --------PIO Request interface{begin}-------- */
    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    .s_axis_rrsp_data       ( {pio_p2p_rrsp_data , pio_int_rrsp_data , pio_eth_rrsp_data , pio_hcr_rrsp_data } ), // i, CHANNEL_NUM * `PIO_DATA_W
    .s_axis_rrsp_head       ( {pio_p2p_rrsp_head , pio_int_rrsp_head , pio_eth_rrsp_head , pio_hcr_rrsp_head } ), // i, CHANNEL_NUM * `PIO_HEAD_W
    .s_axis_rrsp_last       ( {pio_p2p_rrsp_last , pio_int_rrsp_last , pio_eth_rrsp_last , pio_hcr_rrsp_last } ), // i, CHANNEL_NUM * 1
    .s_axis_rrsp_valid      ( {pio_p2p_rrsp_valid, pio_int_rrsp_valid, pio_eth_rrsp_valid, pio_hcr_rrsp_valid} ), // i, CHANNEL_NUM * 1
    .s_axis_rrsp_ready      ( {pio_p2p_rrsp_ready, pio_int_rrsp_ready, pio_eth_rrsp_ready, pio_hcr_rrsp_ready} ), // o, CHANNEL_NUM * 1
    /* --------PIO Request interface{end}-------- */

    /* -------PCIe fragment property{begin}------- */
    /* This signal indicates the (max payload size & max read request size) agreed in the communication
     * 3'b000 -- 128 B
     * 3'b001 -- 256 B
     * 3'b010 -- 512 B
     * 3'b011 -- 1024B
     * 3'b100 -- 2048B
     * 3'b101 -- 4096B
     */
    .max_pyld_sz   ( max_pyld_sz   ), // i, 3
    .max_rd_req_sz ( max_rd_req_sz )  // i, 3 ;max read request size
    /* -------PCIe fragment property{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_sel ( dbg_sel_pio_rrsp ) // i, 32; debug bus select
    ,.dbg_bus ( dbg_bus_pio_rrsp ) // o, 32; debug bus data    
    /* -------APB reated signal{end}------- */
`endif

`ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved | reserved | top_idx | top_end | top_out |
     * |  255:10  |    9:5   |   4:2   |    1    |    0    |
     */
    ,.debug (debug)
    /* ------- Debug interface {end}------- */
`endif
);

rdma_uar #(
    
) rdma_uar (
    .clk             ( user_clk ), // i, 1
    .rst_n           ( rst_n    ), // i, 1

    /* --------Req Channel{begin}-------- */
    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    .pio_uar_req_data   ( pio_uar_req_data  ), // i, `PIO_DATA_W
    .pio_uar_req_head   ( pio_uar_req_head  ), // i, `PIO_HEAD_W
    .pio_uar_req_last   ( pio_uar_req_last  ), // i, 1
    .pio_uar_req_valid  ( pio_uar_req_valid ), // i, 1
    .pio_uar_req_ready  ( pio_uar_req_ready ), // o, 1
    /* --------Req Channel{end}-------- */

    /* --------SQ Doorbell{begin}-------- */
    .pio_uar_db_valid     ( pio_uar_db_valid ), // o, 1
    .pio_uar_db_data      ( pio_uar_db_data  ), // o, 64
    .pio_uar_db_ready     ( pio_uar_db_ready ), // i, 1
    /* --------SQ Doorbell{end}-------- */

    /* --------ARM CQ interface{begin}-------- */
    .cq_ren             ( cq_ren  ), // i, 1
    .cq_num             ( cq_num  ), // i, 31
    .cq_dout_reg        ( cq_dout ), // o, 1
    /* --------ARM CQ interface{end}-------- */
    
    /* --------ARM EQ interface{begin}-------- */
    .eq_ren             ( eq_ren  ), // i, 1
    .eq_num             ( eq_num  ), // i, 31
    .eq_dout_reg        ( eq_dout )  // o, 1
    /* --------ARM EQ interface{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.rw_data ( rw_data_rdma_uar ) // i, 2*`SRAM_RW_DATA_W
    ,.dbg_sel ( dbg_sel_rdma_uar ) // i, 32; debug bus select
    ,.dbg_bus ( dbg_bus_rdma_uar ) // o, 32; debug bus data    
    /* -------APB reated signal{end}------- */
`endif
);

rdma_int #(

) rdma_int (
    .clk             ( user_clk ), // i, 1
    .rst_n           ( rst_n    ), // i, 1

    /* --------Req Channel{begin}-------- */
    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    .pio_int_req_data   ( pio_int_req_data  ), // i, `PIO_DATA_W
    .pio_int_req_head   ( pio_int_req_head  ), // i, `PIO_HEAD_W
    .pio_int_req_last   ( pio_int_req_last  ), // i, 1
    .pio_int_req_valid  ( pio_int_req_valid ), // i, 1
    .pio_int_req_ready  ( pio_int_req_ready ), // o, 1
    /* --------Req Channel{end}-------- */

    /* --------Rsp Channel{begin}-------- */
    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    .pio_int_rrsp_data   ( pio_int_rrsp_data  ), // o, `PIO_DATA_W
    .pio_int_rrsp_head   ( pio_int_rrsp_head  ), // o, `PIO_HEAD_W
    .pio_int_rrsp_last   ( pio_int_rrsp_last  ), // o, 1
    .pio_int_rrsp_valid  ( pio_int_rrsp_valid ), // o, 1
    .pio_int_rrsp_ready  ( pio_int_rrsp_ready ), // i, 1
    /* -------Rsp Channel{end}-------- */

    /* --------Rsp Channel{begin}-------- */
    .in_pio_eq_int_req_valid  ( pio_eq_int_req_valid ), // i, 1
    .in_pio_eq_int_req_num    ( pio_eq_int_req_num   ), // i, `RDMA_MSIX_NUM_LOG
    .in_pio_eq_int_req_ready  ( pio_eq_int_req_ready ), // o, 1

    .out_pio_eq_int_rsp_valid ( pio_eq_int_rsp_valid ), // o, 1
    .out_pio_eq_int_rsp_data  ( pio_eq_int_rsp_data  ), // o, `RDMA_MSIX_DATA_W
    .out_pio_eq_int_rsp_ready ( pio_eq_int_rsp_ready )  // i, 1
    /* -------Rsp Channel{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.rw_data ( rw_data_rdma_int ) // i, 4*`SRAM_RW_DATA_W
    ,.dbg_sel ( dbg_sel_rdma_int ) // i, 32; debug bus select
    ,.dbg_bus ( dbg_bus_rdma_int ) // o, 32; debug bus data    
    /* -------APB reated signal{end}------- */
`endif
);

rdma_hcr #(
    
) rdma_hcr (

    .clk             ( user_clk ), // i, 1
    .rst_n           ( rst_n    ), // i, 1

    /* --------Req Channel{begin}-------- */
    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    .pio_hcr_req_data   ( pio_hcr_req_data  ), // i, `PIO_DATA_W
    .pio_hcr_req_head   ( pio_hcr_req_head  ), // i, `PIO_HEAD_W
    .pio_hcr_req_last   ( pio_hcr_req_last  ), // i, 1
    .pio_hcr_req_valid  ( pio_hcr_req_valid ), // i, 1
    .pio_hcr_req_ready  ( pio_hcr_req_ready ), // o, 1
    /* --------Req Channel{end}-------- */

    /* --------Rsp Channel{begin}-------- */
    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    .pio_hcr_rrsp_data   ( pio_hcr_rrsp_data  ), // o, `PIO_DATA_W
    .pio_hcr_rrsp_head   ( pio_hcr_rrsp_head  ), // o, `PIO_HEAD_W
    .pio_hcr_rrsp_last   ( pio_hcr_rrsp_last  ), // o, 1
    .pio_hcr_rrsp_valid  ( pio_hcr_rrsp_valid ), // o, 1
    .pio_hcr_rrsp_ready  ( pio_hcr_rrsp_ready ), // i, 1
    /* -------Rsp Channel{end}-------- */

    /* -------pio <--> RDMA interface{begin}------- */
    .pio_hcr_in_param     ( pio_hcr_in_param     ), // o, 64
    .pio_hcr_in_modifier  ( pio_hcr_in_modifier  ), // o, 32
    .pio_hcr_out_dma_addr ( pio_hcr_out_dma_addr ), // o, 64
    .pio_hcr_out_param    ( pio_hcr_out_param    ), // i, 64
    .pio_hcr_token        ( pio_hcr_token        ), // o, 16
    .pio_hcr_status       ( pio_hcr_status       ), // i, 8
    .pio_hcr_go           ( pio_hcr_go           ), // o, 1
    .pio_hcr_clear        ( pio_hcr_clear        ), // i, 1
    .pio_hcr_event        ( pio_hcr_event        ), // o, 1
    .pio_hcr_op_modifier  ( pio_hcr_op_modifier  ), // o, 8
    .pio_hcr_op           ( pio_hcr_op           ), // o, 12
    /* -------pio <--> RDMA interface{end}------- */

    /* -------Reset signal{begin}------- */
    .cmd_rst              ( cmd_rst       ), // o, 1
    .init_done            ( init_done     )  // i, 1
    /* -------Reset signal{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_sel ( dbg_sel_rdma_hcr ) // i, 32; debug bus select
    ,.dbg_bus ( dbg_bus_rdma_hcr ) // o, 32; debug bus data    
    /* -------APB reated signal{end}------- */
`endif
);

eth_cfg #(
    .AXIL_DATA_WIDTH           ( AXIL_DATA_WIDTH ),
    .AXIL_ADDR_WIDTH           ( AXIL_ADDR_WIDTH )
) eth_cfg (

    .clk             ( user_clk ), // i, 1
    .rst_n           ( rst_n    ), // i, 1

    /* --------Req Channel{begin}-------- */
    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    .pio_eth_req_data   ( pio_eth_req_data  ), // i, `PIO_DATA_W
    .pio_eth_req_head   ( pio_eth_req_head  ), // i, `PIO_HEAD_W
    .pio_eth_req_last   ( pio_eth_req_last  ), // i, 1
    .pio_eth_req_valid  ( pio_eth_req_valid ), // i, 1
    .pio_eth_req_ready  ( pio_eth_req_ready ), // o, 1
    /* --------Req Channel{end}-------- */

    /* --------Rsp Channel{begin}-------- */
    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    .st_pio_eth_rrsp_data   ( pio_eth_rrsp_data  ), // o, `PIO_DATA_W
    .st_pio_eth_rrsp_head   ( pio_eth_rrsp_head  ), // o, `PIO_HEAD_W
    .st_pio_eth_rrsp_last   ( pio_eth_rrsp_last  ), // o, 1
    .st_pio_eth_rrsp_valid  ( pio_eth_rrsp_valid ), // o, 1
    .st_pio_eth_rrsp_ready  ( pio_eth_rrsp_ready ), // i, 1
    /* -------Rsp Channel{end}-------- */

    /* --------Interact with Ethernet BAR{begin}------- */
    .m_axil_awaddr  ( m_axil_awaddr  ) , // o, AXIL_ADDR_WIDTH
    .m_axil_awvalid ( m_axil_awvalid ) , // o, 1
    .m_axil_awready ( m_axil_awready ) , // i, 1

    .m_axil_wdata   ( m_axil_wdata   ), // o, AXIL_DATA_WIDTH
    .m_axil_wstrb   ( m_axil_wstrb   ), // o, AXIL_STRB_WIDTH
    .m_axil_wvalid  ( m_axil_wvalid  ), // o, 1
    .m_axil_wready  ( m_axil_wready  ), // i, 1

    .m_axil_bvalid  ( m_axil_bvalid  ), // i, 1
    .m_axil_bready  ( m_axil_bready  ), // o, 1

    .m_axil_araddr  ( m_axil_araddr  ), // o, AXIL_ADDR_WIDTH
    .m_axil_arvalid ( m_axil_arvalid ), // o, 1
    .m_axil_arready ( m_axil_arready ), // i, 1
    
    .m_axil_rdata   ( m_axil_rdata   ), // i, AXIL_DATA_WIDTH
    .m_axil_rvalid  ( m_axil_rvalid  ), // i, 1
    .m_axil_rready  ( m_axil_rready  )  // o, 1
    /* --------Interact with Ethernet BAR{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_sel ( dbg_sel_eth_cfg ) // i, 32; debug bus select
    ,.dbg_bus ( dbg_bus_eth_cfg ) // o, 32; debug bus data    
    /* -------APB reated signal{end}------- */
`endif
);

p2p_access #(

) p2p_access (
    .clk             ( user_clk ), // i, 1
    .rst_n           ( rst_n    ), // i, 1

    /* --------Req Channel{begin}-------- */
    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    .pio_p2p_mem_req_valid  ( pio_p2p_mem_req_valid ), // i, 1
    .pio_p2p_mem_req_last   ( pio_p2p_mem_req_last  ), // i, 1
    .pio_p2p_mem_req_data   ( pio_p2p_mem_req_data  ), // i, `PIO_DATA_W
    .pio_p2p_mem_req_head   ( pio_p2p_mem_req_head  ), // i, `PIO_HEAD_W
    .pio_p2p_mem_req_ready  ( pio_p2p_mem_req_ready ), // o, 1
    /* --------Req Channel{end}-------- */

    /* --------Req Channel{begin}-------- */
    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    .pio_p2p_cfg_req_valid  ( pio_p2p_cfg_req_valid ), // i, 1
    .pio_p2p_cfg_req_last   ( pio_p2p_cfg_req_last  ), // i, 1
    .pio_p2p_cfg_req_data   ( pio_p2p_cfg_req_data  ), // i, `PIO_DATA_W
    .pio_p2p_cfg_req_head   ( pio_p2p_cfg_req_head  ), // i, `PIO_HEAD_W
    .pio_p2p_cfg_req_ready  ( pio_p2p_cfg_req_ready ), // o, 1
    /* --------Req Channel{end}-------- */

    /* --------Rsp Channel{begin}-------- */
    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    .pio_p2p_rrsp_valid  ( pio_p2p_rrsp_valid ), // o, 1
    .pio_p2p_rrsp_last   ( pio_p2p_rrsp_last  ), // o, 1
    .pio_p2p_rrsp_data   ( pio_p2p_rrsp_data  ), // o, `PIO_DATA_W
    .pio_p2p_rrsp_head   ( pio_p2p_rrsp_head  ), // o, `PIO_HEAD_W
    .pio_p2p_rrsp_ready  ( pio_p2p_rrsp_ready ), // i, 1
    /* -------Rsp Channel{end}-------- */

    /* --------P2P Configuration Channel{begin}-------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    .p2p_cfg_req_valid   ( p2p_cfg_req_valid  ), // o, 1
    .p2p_cfg_req_last    ( p2p_cfg_req_last   ), // o, 1
    .p2p_cfg_req_data    ( p2p_cfg_req_data   ), // o, `PIO_DATA_W
    .p2p_cfg_req_head    ( p2p_cfg_req_head   ), // o, `P2P_HEAD_W
    .p2p_cfg_req_ready   ( p2p_cfg_req_ready  ), // i, 1
    
    .p2p_cfg_rrsp_valid  ( p2p_cfg_rrsp_valid ), // i, 1
    .p2p_cfg_rrsp_last   ( p2p_cfg_rrsp_last  ), // i, 1
    .p2p_cfg_rrsp_data   ( p2p_cfg_rrsp_data  ), // i, `PIO_DATA_W
    .p2p_cfg_rrsp_ready  ( p2p_cfg_rrsp_ready ), // o, 1
    /* --------P2P Configuration Channel{end}-------- */

    /* -------P2P Memory Access Channel{begin}-------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    .p2p_mem_req_valid   ( p2p_mem_req_valid  ), // o, 1
    .p2p_mem_req_last    ( p2p_mem_req_last   ), // o, 1
    .p2p_mem_req_data    ( p2p_mem_req_data   ), // o, `PIO_DATA_W
    .p2p_mem_req_head    ( p2p_mem_req_head   ), // o, `P2P_HEAD_W
    .p2p_mem_req_ready   ( p2p_mem_req_ready  )  // i, 1
    /* -------P2P Memory Access Channel{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_sel ( dbg_sel_p2p_access ) // i, 32; debug bus select
    ,.dbg_bus ( dbg_bus_p2p_access ) // o, 32; debug bus data    
    /* -------APB reated signal{end}------- */
`endif
);


`ifdef ILA_ON
//ila_cq_async_fifo_wr(
//    .clk(pcie_clk),

//    .probe0( m_axis_cq_tvalid ), // i, 1
//    .probe1( cq_full  ), // i, DATA_WIDTH
//    .probe2(  {m_axis_cq_tuser[40], m_axis_cq_tuser[7:0], m_axis_cq_tlast, m_axis_cq_tdata}         )
//);

//ila_cq_async_fifo_rd ila_cq_async_fifo_rd_inst(
//    .clk(user_clk),

//    .probe0   ( cq_tvalid ), // i, 1
//    .probe1  ( cq_empty  ), // o, DATA_WIDTH
//    .probe2 ( {cq_tuser[40], cq_tuser[7:0], cq_tlast, cq_tdata}  )  // o, 1
//);

`endif


endmodule // PIO

