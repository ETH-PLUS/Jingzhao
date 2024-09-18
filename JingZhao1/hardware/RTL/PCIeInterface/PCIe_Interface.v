`timescale 1ns / 100ps
//*************************************************************************
// > File Name   : PCIe_Interface.v
// > Description : PCIe_Interface, Top modulle for DMA and PIO interface
// > Author      : Kangning
// > Date        : 2021-09-07
//*************************************************************************

module  PCIe_Interface #(
    parameter AXIL_DATA_WIDTH  = 32 ,
    parameter AXIL_ADDR_WIDTH  = 24 ,

    // not visable from other module
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8)
)(

    input                           pcie_clk   , // i, 1
    input                           pcie_rst_n , // i, 1
    input                           user_clk   , // i, 1
    input                           user_rst_n , // i, 1

    input                           ist_mbist_rstn ,  
    output                          ist_mbist_done ,  
    output                          ist_mbist_pass ,  

    /* --------rdma_init_done{begin}-------- */
    input                           rdma_init_done, // i, 1
    /* --------rdma_init_done{end}-------- */

    /* ------- AXI Interface{begin}------- */
    output                         s_axis_rq_tvalid,
    output                         s_axis_rq_tlast ,
    output [`PCIEI_KEEP_W-1:0]     s_axis_rq_tkeep ,
    output              [59:0]     s_axis_rq_tuser ,
    output [`PCIEI_DATA_W-1:0]     s_axis_rq_tdata ,
    input                [3:0]     s_axis_rq_tready,

    input                          m_axis_rc_tvalid,
    input                          m_axis_rc_tlast ,
    input  [`PCIEI_KEEP_W-1:0]     m_axis_rc_tkeep ,
    input               [74:0]     m_axis_rc_tuser ,
    input  [`PCIEI_DATA_W-1:0]     m_axis_rc_tdata ,
    output                         m_axis_rc_tready,

    input                          m_axis_cq_tvalid,
    input                          m_axis_cq_tlast ,
    input  [`PCIEI_KEEP_W-1:0]     m_axis_cq_tkeep ,
    input               [84:0]     m_axis_cq_tuser ,
    input  [`PCIEI_DATA_W-1:0]     m_axis_cq_tdata ,
    output                         m_axis_cq_tready,

    output                         s_axis_cc_tvalid,
    output                         s_axis_cc_tlast ,
    output [`PCIEI_KEEP_W-1:0]     s_axis_cc_tkeep ,
    output              [32:0]     s_axis_cc_tuser ,
    output [`PCIEI_DATA_W-1:0]     s_axis_cc_tdata ,
    input                [3:0]     s_axis_cc_tready,
    /* ------- AXI Interface{end}------- */

    // Configuration (CFG) Interface
    input                  [2:0]     cfg_max_payload ,
    input                  [2:0]     cfg_max_read_req,
    input                  [12:0]    tl_cfg_busdev, 

    // Interrupt Interface Signals
    input                  [1:0]     cfg_interrupt_msix_enable        ,
    input                  [1:0]     cfg_interrupt_msix_mask          ,
    output                [31:0]     cfg_interrupt_msix_data          ,
    output                [63:0]     cfg_interrupt_msix_address       ,
    output                           cfg_interrupt_msix_int           ,
    input                            cfg_interrupt_msix_sent          ,
    input                            cfg_interrupt_msix_fail          ,
    output wire            [2:0]     cfg_interrupt_msi_function_number,

    /* -------pio interface{begin}------- */
    output  wire [63:0]              pio_hcr_in_param      ,
    output  wire [31:0]              pio_hcr_in_modifier   ,
    output  wire [63:0]              pio_hcr_out_dma_addr  ,
    input   wire [63:0]              pio_hcr_out_param     ,
    output  wire [15:0]              pio_hcr_token         ,
    input   wire [ 7:0]              pio_hcr_status        ,
    output  wire                     pio_hcr_go            ,
    input   wire                     pio_hcr_clear         ,
    output  wire                     pio_hcr_event         ,
    output  wire [ 7:0]              pio_hcr_op_modifier   ,
    output  wire [11:0]              pio_hcr_op            ,
    /* -------pio interface{end}------- */

    /* -------Reset signal{begin}------- */
    output wire                         cmd_rst,
    /* -------Reset signal{end}------- */

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
    input  wire [64                -1:0] pio_eq_int_req_num  , // i, 64
    output wire                          pio_eq_int_req_ready, // o, 1

    output wire                          pio_eq_int_rsp_valid, // o, 1
    output wire [`RDMA_MSIX_DATA_W -1:0] pio_eq_int_rsp_data , // o, 128
    input  wire                          pio_eq_int_rsp_ready, // i, 1
    /* -------Interrupt Vector entry request & response{end}-------- */

    /* --------Interact with Ethernet BAR{begin}------- */
    output wire [AXIL_ADDR_WIDTH-1:0]    m_axi_awaddr ,
    output wire                          m_axi_awvalid,
    input  wire                          m_axi_awready,

    output wire [AXIL_DATA_WIDTH-1:0]    m_axi_wdata ,
    output wire [AXIL_STRB_WIDTH-1:0]    m_axi_wstrb , // byte select
    output wire                          m_axi_wvalid,
    input  wire                          m_axi_wready,

    input  wire                          m_axi_bvalid,
    output wire                          m_axi_bready,

    output wire [AXIL_ADDR_WIDTH-1:0]    m_axi_araddr ,
    output wire                          m_axi_arvalid,
    input  wire                          m_axi_arready,
    
    input  wire [AXIL_DATA_WIDTH-1:0]    m_axi_rdata ,
    input  wire                          m_axi_rvalid,
    output wire                          m_axi_rready,
    /* --------Interact with Ethernet BAR{end}------- */

    /* -------dma interface{begin}------- */
    /* dma_*_head(interact with RDMA modules), valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    // Read Req
    input  wire [`DMA_RD_CHNL_NUM * 1            -1:0] dma_rd_req_valid,
    input  wire [`DMA_RD_CHNL_NUM * 1            -1:0] dma_rd_req_last ,
    input  wire [`DMA_RD_CHNL_NUM * `PCIEI_DATA_W-1:0] dma_rd_req_data ,
    input  wire [`DMA_RD_CHNL_NUM * `DMA_HEAD_W  -1:0] dma_rd_req_head ,
    output wire [`DMA_RD_CHNL_NUM * 1            -1:0] dma_rd_req_ready,

    // DMA Read Resp
    output wire [`DMA_RD_CHNL_NUM * 1            -1:0] dma_rd_rsp_valid,
    output wire [`DMA_RD_CHNL_NUM * 1            -1:0] dma_rd_rsp_last ,
    output wire [`DMA_RD_CHNL_NUM * `PCIEI_DATA_W-1:0] dma_rd_rsp_data ,
    output wire [`DMA_RD_CHNL_NUM * `DMA_HEAD_W  -1:0] dma_rd_rsp_head ,
    input  wire [`DMA_RD_CHNL_NUM * 1            -1:0] dma_rd_rsp_ready,

    // DMA Write Req. 
    // Note that PCIe Interface owns an extra channel for P2P uses.
    input  wire [(`DMA_WR_CHNL_NUM - 1) * 1            -1:0] dma_wr_req_valid, 
    input  wire [(`DMA_WR_CHNL_NUM - 1) * 1            -1:0] dma_wr_req_last , 
    input  wire [(`DMA_WR_CHNL_NUM - 1) * `PCIEI_DATA_W-1:0] dma_wr_req_data , 
    input  wire [(`DMA_WR_CHNL_NUM - 1) * `DMA_HEAD_W  -1:0] dma_wr_req_head , 
    output wire [(`DMA_WR_CHNL_NUM - 1) * 1            -1:0] dma_wr_req_ready,
    /* -------dma interface{end}------- */

    /* --------p2p forward up channel{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved | dst_dev | src_dev | Reserved | Byte length |
     * |  63:35   |  37:35  |  34:32  |  31:16   |    15:0     |
     */
    input  wire [1             - 1 : 0] p2p_upper_valid, // i, 1             
    input  wire [1             - 1 : 0] p2p_upper_last , // i, 1             
    input  wire [`PCIEI_DATA_W - 1 : 0] p2p_upper_data , // i, `PCIEI_DATA_W  
    input  wire [`P2P_UHEAD_W  - 1 : 0] p2p_upper_head , // i, `P2P_UHEAD_W
    output wire [1             - 1 : 0] p2p_upper_ready, // o, 1        
    /* --------p2p forward up channel{end}-------- */

    /* --------p2p forward down channel{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved | dst_dev | src_dev | Reserved | Byte length |
     * |  63:35   |  37:35  |  34:32  |  31:16   |    15:0     |
     */
    output wire [1             - 1 : 0] p2p_down_valid, // o, 1             
    output wire [1             - 1 : 0] p2p_down_last , // o, 1             
    output wire [`PCIEI_DATA_W - 1 : 0] p2p_down_data , // o, `PCIEI_DATA_W  
    output wire [`P2P_DHEAD_W  - 1 : 0] p2p_down_head , // o, `P2P_DHEAD_W
    input  wire [1             - 1 : 0] p2p_down_ready  // i, 1        
    /* --------p2p forward down channel{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [(2*`DMA_RD_CHNL_NUM+`DMA_WR_CHNL_NUM+2*`QUEUE_NUM+18)*`SRAM_RW_DATA_W-1:0] rw_data  // i, (2*`DMA_RD_CHNL_NUM+`DMA_WR_CHNL_NUM+2*`QUEUE_NUM+18)*`SRAM_RW_DATA_W
    ,input  wire [31:0] dbg_sel  // debug bus select
    ,output wire [31:0] dbg_bus  // debug bus data    
    /* -------APB reated signal{end}------- */
`endif
);

wire             pcie_syn_rstn;
/* --------Init_done{begin}--------- */
wire dma_init_done, p2p_init_done;
/* --------Init_done{end}--------- */

/* -------input reg{begin} -------- */
wire [2:0] cfg_max_payload_rdma ;
wire [2:0] cfg_max_read_req_rdma;
wire [12:0] tl_cfg_busdev_rdma;
/* -------input reg{end} -------- */

/* --------DMA Engine{begin}-------- */
wire [59:0] rq_tuser;

/* --------DMA Engine{end}-------- */

/* --------STD_PIO Engine{begin}-------- */
/* --------P2P Configuration Channel{begin}-------- */
wire [1           - 1 : 0] p2p_cfg_req_valid; // o, 1
wire [1           - 1 : 0] p2p_cfg_req_last ; // o, 1
wire [`P2P_DATA_W - 1 : 0] p2p_cfg_req_data ; // o, `P2P_DATA_W
wire [`P2P_HEAD_W - 1 : 0] p2p_cfg_req_head ; // o, `P2P_HEAD_W
wire [1           - 1 : 0] p2p_cfg_req_ready; // i, 1

wire [1           - 1 : 0] p2p_cfg_rrsp_valid; // i, 1
wire [1           - 1 : 0] p2p_cfg_rrsp_last ; // i, 1
wire [`P2P_DATA_W - 1 : 0] p2p_cfg_rrsp_data ; // i, `P2P_DATA_W
wire [1           - 1 : 0] p2p_cfg_rrsp_ready; // o, 1
/* --------P2P Configuration Channel{end}-------- */

/* -------P2P Memory Access Channel{begin}-------- */
wire [1           - 1 : 0] p2p_mem_req_valid; // o, 1
wire [1           - 1 : 0] p2p_mem_req_last ; // o, 1
wire [`P2P_DATA_W - 1 : 0] p2p_mem_req_data ; // o, `P2P_DATA_W
wire [`P2P_HEAD_W - 1 : 0] p2p_mem_req_head ; // o, `P2P_HEAD_W
wire [1           - 1 : 0] p2p_mem_req_ready; // i, 1
/* -------P2P Memory Access Channel{end}-------- */
/* --------STD_PIO Engine{end}-------- */

/* --------P2P DMA Write Req{begin}-------- */
/* dma_*_head, valid only in first beat of a packet
    * | Reserved | address | Reserved | Byte length |
    * |  127:96  |  95:32  |  31:13   |    12:0     |
    */
wire [1             - 1 : 0] p2p_dma_wr_req_valid; // o, 1             
wire [1             - 1 : 0] p2p_dma_wr_req_last ; // o, 1             
wire [`PCIEI_DATA_W - 1 : 0] p2p_dma_wr_req_data ; // o, `PCIEI_DATA_W  
wire [`DMA_HEAD_W   - 1 : 0] p2p_dma_wr_req_head ; // o, `DMA_HEAD_W
wire [1             - 1 : 0] p2p_dma_wr_req_ready; // i, 1             
/* --------P2P DMA Write Req{end}-------- */

/* -------Odd Parity function definition{begin}------- */
function odd_bit;
    input [7:0] bytes;
    begin
        odd_bit = ~(^bytes);
    end
endfunction
/* -------Odd Parity function definition{end}------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire [(2*`DMA_RD_CHNL_NUM+`DMA_WR_CHNL_NUM+6)*`SRAM_RW_DATA_W-1:0] dma_rw_data;
wire [`SRAM_RW_DATA_W*8-1:0] pio_rw_data;
wire [(2*`QUEUE_NUM+4)*`SRAM_RW_DATA_W-1:0] p2p_rw_data;
wire [32 - 1 : 0] dma_dbg_sel, pio_dbg_sel, p2p_dbg_sel;
wire [32 - 1 : 0] dma_dbg_bus, pio_dbg_bus, p2p_dbg_bus;
/* -------APB reated signal{end}------- */
`endif

//-------------------------------------------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign {dma_rw_data, pio_rw_data, p2p_rw_data} = rw_data;
assign dma_dbg_sel = (`DMA_DBG_BASE <= dbg_sel && dbg_sel < `PIO_DBG_BASE  ) ? (dbg_sel - `DMA_DBG_BASE) : 0;
assign pio_dbg_sel = (`PIO_DBG_BASE <= dbg_sel && dbg_sel < `P2P_DBG_BASE  ) ? (dbg_sel - `PIO_DBG_BASE) : 0;
assign p2p_dbg_sel = (`P2P_DBG_BASE <= dbg_sel && dbg_sel < `PCIEI_DBG_SIZE) ? (dbg_sel - `P2P_DBG_BASE) : 0;
assign dbg_bus = (`DMA_DBG_BASE <= dbg_sel && dbg_sel < `PIO_DBG_BASE  ) ? p2p_dbg_bus :
                 (`PIO_DBG_BASE <= dbg_sel && dbg_sel < `P2P_DBG_BASE  ) ? pio_dbg_bus :
                 (`P2P_DBG_BASE <= dbg_sel && dbg_sel < `PCIEI_DBG_SIZE) ? dma_dbg_bus : 32'd0;
/* -------APB reated signal{end}------- */
`endif

`ifdef PCIEI_SIM

assign pcie_syn_rstn = pcie_rst_n;

`else

macro_reset_sync2 u_syn_pcie_rstn(
    .test_en      (1'b0                ),
    .reset_n      (pcie_rst_n          ),
    .ck           (pcie_clk            ),
    .reset_sync_n (pcie_syn_rstn       )
);

`endif

cdc_syncff #(
    .DATA_WIDTH  ( 6 + 13 ), 
    .RST_VALUE   ( 0 ), 
    .SYNC_LEVELS ( 2 )
) u_ptr_sync_w2r (
    // Inputs
    .data_s ( {cfg_max_payload, cfg_max_read_req, tl_cfg_busdev}  ), 
    .clk_d  ( user_clk   ),
    .rstn_d ( user_rst_n ),
    // Output
    .data_d({cfg_max_payload_rdma, cfg_max_read_req_rdma, tl_cfg_busdev_rdma})
);

assign ist_mbist_done = 1'b1;  
assign ist_mbist_pass = 1'b1;  
/* --------DMA Engine{begin}-------- */
DMA #(
    
) DMA_inst (
    .pcie_clk   ( pcie_clk      ), // i, 1
    .pcie_rst_n ( pcie_syn_rstn ), // i, 1
    .dma_clk    ( user_clk      ), // i, 1
    .rst_n      ( user_rst_n    ), // i, 1
    .init_done  ( dma_init_done ), // o, 1

    /* -------pcie <--> dma interface{begin}------- */
    // Requester request
    /*  RQ tuser
     * |  59:28 |  27:24  |    23:16   |          15         |   14:13  |      12     |     11      |     10:8    |   7:4   |    3:0   |
     * | parity | seq_num | tph_st_tag | tph_indirect_tag_en | tph_type | tph_present | discontinue | addr_offset | last_be | first_be |
     * |   0    |   0     |     0      |          0          |     0    |      0      |      0      |      0      |         |          |
     */
    .s_axis_rq_tvalid     ( s_axis_rq_tvalid ), // o, 1
    .s_axis_rq_tlast      ( s_axis_rq_tlast  ), // o, 1
    .s_axis_rq_tdata      ( s_axis_rq_tdata  ), // o, `DMA_DATA_W
    .s_axis_rq_tuser      ( rq_tuser         ), // o, 60
    .s_axis_rq_tkeep      ( s_axis_rq_tkeep  ), // o, `DMA_KEEP_W
    .s_axis_rq_tready     ( s_axis_rq_tready[0] ), // i, 1

    // Requester Completion
    /*  RC tuser
     * |  74:43 |      42     |    41:38   |  37:34   |    33    |    32    |  31:0   |  
     * | parity | discontinue |  is_eof_1  | is_eof_0 | is_sof_1 | is_sof_0 | byte_en |
     * | ignore |   ignore    |  ignore    | ignore   |  ignore  |  ignore  |         |
     */
    .m_axis_rc_tvalid     ( m_axis_rc_tvalid ), // i, 1
    .m_axis_rc_tlast      ( m_axis_rc_tlast  ), // i, 1
    .m_axis_rc_tdata      ( m_axis_rc_tdata  ), // i, `DMA_DATA_W
    .m_axis_rc_tuser      ( m_axis_rc_tuser  ), // i, 75
    .m_axis_rc_tkeep      ( m_axis_rc_tkeep  ), // i, `DMA_KEEP_W
    .m_axis_rc_tready     ( m_axis_rc_tready ), // o, 1
    /* -------pcie <--> dma interface{end}------- */

    /* -------Interrupt Interface Signals{begin}------- */
    .cfg_interrupt_msix_enable         ( cfg_interrupt_msix_enable         ), // i, 2
    .cfg_interrupt_msix_mask           ( cfg_interrupt_msix_mask           ), // i, 2
    .cfg_interrupt_msix_data           ( cfg_interrupt_msix_data           ), // o, 32
    .cfg_interrupt_msix_address        ( cfg_interrupt_msix_address        ), // o, 64
    .cfg_interrupt_msix_int            ( cfg_interrupt_msix_int            ), // o, 1
    .cfg_interrupt_msix_sent           ( cfg_interrupt_msix_sent           ), // i, 1
    .cfg_interrupt_msix_fail           ( cfg_interrupt_msix_fail           ), // i, 1
    .cfg_interrupt_msi_function_number ( cfg_interrupt_msi_function_number ), // o, 3
    /* -------Interrupt Interface Signals{end}------- */

    /* -------PCIe fragment property{begin}------- */
    /* This signal indicates the (max payload size & max read request size) agreed in the communication
     * 3'b000 -- 128 B
     * 3'b001 -- 256 B
     * 3'b010 -- 512 B
     * 3'b011 -- 1024B
     * 3'b100 -- 2048B
     * 3'b101 -- 4096B
     */
    .max_pyld_sz      ( cfg_max_payload_rdma  ),
    .max_rd_req_sz    ( cfg_max_read_req_rdma ), // max read request size
    .req_id           ( {tl_cfg_busdev_rdma, 3'd0} ), 
    /* -------PCIe fragment property{end}------- */

    /* -------dma <--> RDMA interface{begin}------- */
    /* dma_*_head(interact with RDMA modules), valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    // CEU Read Req
    .dma_rd_req_valid ( dma_rd_req_valid ), // i, `DMA_RD_CHNL_NUM * 1             
    .dma_rd_req_last  ( dma_rd_req_last  ), // i, `DMA_RD_CHNL_NUM * 1             
    .dma_rd_req_data  ( dma_rd_req_data  ), // i, `DMA_RD_CHNL_NUM * `DMA_DATA_W  
    .dma_rd_req_head  ( dma_rd_req_head  ), // i, `DMA_RD_CHNL_NUM * `DMA_HEAD_W
    .dma_rd_req_ready ( dma_rd_req_ready ), // o, `DMA_RD_CHNL_NUM * 1             

    // CEU DMA Read Resp
    .dma_rd_rsp_valid ( dma_rd_rsp_valid ), // o, `DMA_RD_CHNL_NUM * 1             
    .dma_rd_rsp_last  ( dma_rd_rsp_last  ), // o, `DMA_RD_CHNL_NUM * 1             
    .dma_rd_rsp_data  ( dma_rd_rsp_data  ), // o, `DMA_RD_CHNL_NUM * `DMA_DATA_W  
    .dma_rd_rsp_head  ( dma_rd_rsp_head  ), // o, `DMA_RD_CHNL_NUM * `DMA_HEAD_W
    .dma_rd_rsp_ready ( dma_rd_rsp_ready ), // i, `DMA_RD_CHNL_NUM * 1             

    // CEU DMA Write Req
    .dma_wr_req_valid ( {p2p_dma_wr_req_valid, dma_wr_req_valid} ), // i, `DMA_WR_CHNL_NUM * 1             
    .dma_wr_req_last  ( {p2p_dma_wr_req_last , dma_wr_req_last } ), // i, `DMA_WR_CHNL_NUM * 1             
    .dma_wr_req_data  ( {p2p_dma_wr_req_data , dma_wr_req_data } ), // i, `DMA_WR_CHNL_NUM * `DMA_DATA_W  
    .dma_wr_req_head  ( {p2p_dma_wr_req_head , dma_wr_req_head } ), // i, `DMA_WR_CHNL_NUM * `DMA_HEAD_W
    .dma_wr_req_ready ( {p2p_dma_wr_req_ready, dma_wr_req_ready} )  // o, `DMA_WR_CHNL_NUM * 1             
    /* -------dma <--> RDMA interface{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.rw_data ( dma_rw_data ) // i, (2*`DMA_RD_CHNL_NUM+`DMA_WR_CHNL_NUM+6)*`SRAM_RW_DATA_W
    ,.dbg_sel ( dma_dbg_sel ) // debug bus select
    ,.dbg_bus ( dma_dbg_bus ) // debug bus data	
    /* -------APB reated signal{end}------- */
`endif
);

assign s_axis_rq_tuser = {odd_bit(s_axis_rq_tdata[8 * 32 - 1: 8 * 31]),
                           odd_bit(s_axis_rq_tdata[8 * 31 - 1: 8 * 30]),
                           odd_bit(s_axis_rq_tdata[8 * 30 - 1: 8 * 29]),
                           odd_bit(s_axis_rq_tdata[8 * 29 - 1: 8 * 28]),
                           odd_bit(s_axis_rq_tdata[8 * 28 - 1: 8 * 27]),
                           odd_bit(s_axis_rq_tdata[8 * 27 - 1: 8 * 26]),
                           odd_bit(s_axis_rq_tdata[8 * 26 - 1: 8 * 25]),
                           odd_bit(s_axis_rq_tdata[8 * 25 - 1: 8 * 24]),
                           odd_bit(s_axis_rq_tdata[8 * 24 - 1: 8 * 23]),
                           odd_bit(s_axis_rq_tdata[8 * 23 - 1: 8 * 22]),
                           odd_bit(s_axis_rq_tdata[8 * 22 - 1: 8 * 21]),
                           odd_bit(s_axis_rq_tdata[8 * 21 - 1: 8 * 20]),
                           odd_bit(s_axis_rq_tdata[8 * 20 - 1: 8 * 19]),
                           odd_bit(s_axis_rq_tdata[8 * 19 - 1: 8 * 18]),
                           odd_bit(s_axis_rq_tdata[8 * 18 - 1: 8 * 17]),
                           odd_bit(s_axis_rq_tdata[8 * 17 - 1: 8 * 16]),
                           odd_bit(s_axis_rq_tdata[8 * 16 - 1: 8 * 15]),
                           odd_bit(s_axis_rq_tdata[8 * 15 - 1: 8 * 14]),
                           odd_bit(s_axis_rq_tdata[8 * 14 - 1: 8 * 13]),
                           odd_bit(s_axis_rq_tdata[8 * 13 - 1: 8 * 12]),
                           odd_bit(s_axis_rq_tdata[8 * 12 - 1: 8 * 11]),
                           odd_bit(s_axis_rq_tdata[8 * 11 - 1: 8 * 10]),
                           odd_bit(s_axis_rq_tdata[8 * 10 - 1: 8 * 9 ]),
                           odd_bit(s_axis_rq_tdata[8 * 9  - 1: 8 * 8 ]),
                           odd_bit(s_axis_rq_tdata[8 * 8  - 1: 8 * 7 ]),
                           odd_bit(s_axis_rq_tdata[8 * 7  - 1: 8 * 6 ]),
                           odd_bit(s_axis_rq_tdata[8 * 6  - 1: 8 * 5 ]),
                           odd_bit(s_axis_rq_tdata[8 * 5  - 1: 8 * 4 ]),
                           odd_bit(s_axis_rq_tdata[8 * 4  - 1: 8 * 3 ]),
                           odd_bit(s_axis_rq_tdata[8 * 3  - 1: 8 * 2 ]),
                           odd_bit(s_axis_rq_tdata[8 * 2  - 1: 8 * 1 ]),
                           odd_bit(s_axis_rq_tdata[8 * 1  - 1: 8 * 0 ]), 
                           rq_tuser[27:0]};
/* --------DMA Engine{end}-------- */

/* --------STD_PIO Engine{begin}-------- */
STD_PIO #(
    .AXIL_DATA_WIDTH ( AXIL_DATA_WIDTH ), 
    .AXIL_ADDR_WIDTH ( AXIL_ADDR_WIDTH )
) STD_PIO_inst (

    .pcie_clk   ( pcie_clk      ), // i, 1
    .pcie_rst_n ( pcie_syn_rstn ), // i, 1
    .user_clk   ( user_clk      ), // i, 1
    .rst_n      ( user_rst_n    ), // i, 1

    .init_done  ( rdma_init_done &  dma_init_done & p2p_init_done ), // i, 1

    /* -------Completer Requester{begin}------- */
    /*  CQ tuser
     * |  84:53 |    52:45   |   44:43  |      42     |     41      | 40  |  39:8   |   7:4   |    3:0   |
     * | parity | tph_st_tag | tph_type | tph_present | discontinue | sop | byte_en | last_be | first_be |
     * |   0    |     0      |     0    |             |             |     | ignore  |         |          |
     */
    .m_axis_cq_tvalid                               ( m_axis_cq_tvalid ), // i, 1
    .m_axis_cq_tlast                                ( m_axis_cq_tlast  ), // i, 1
    .m_axis_cq_tuser                                ( m_axis_cq_tuser  ), // i, 85
    .m_axis_cq_tdata                                ( m_axis_cq_tdata  ), // i, `PIO_DATA_W
    .m_axis_cq_tkeep                                ( m_axis_cq_tkeep  ), // i, `DMA_KEEP_W
    .m_axis_cq_tready                               ( m_axis_cq_tready ), // o, 1
    /* -------Completer Requester{end}------- */

    /* -------Completer Completion{begin}------- */
    /*  CC tuser
     * |  32:1  |      0      |
     * | parity | discontinue |
     * | ignore |   ignore    |
     */
    .s_axis_cc_tvalid                               ( s_axis_cc_tvalid ), // o, 1
    .s_axis_cc_tlast                                ( s_axis_cc_tlast  ), // o, 1
    .s_axis_cc_tuser                                (   ), // o, 33
    .s_axis_cc_tdata                                ( s_axis_cc_tdata  ), // o, `PIO_DATA_W
    .s_axis_cc_tkeep                                ( s_axis_cc_tkeep  ), // o, `DMA_KEEP_W
    .s_axis_cc_tready                               ( s_axis_cc_tready[0] ),  // i, 1
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
    .max_pyld_sz   ( cfg_max_payload_rdma  ),
    .max_rd_req_sz ( cfg_max_read_req_rdma ), // max read request size
    /* -------PCIe fragment property{end}------- */

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

    /* --------SQ Doorbell{begin}-------- */
    .pio_uar_db_valid     ( pio_uar_db_valid ), // o, 1
    .pio_uar_db_data      ( pio_uar_db_data  ), // o, 64
    .pio_uar_db_ready     ( pio_uar_db_ready ), // i, 1
    /* --------SQ Doorbell{end}-------- */

    /* --------ARM CQ interface{begin}-------- */
    .cq_ren               ( cq_ren           ), // i, 1
    .cq_num               ( cq_num           ), // i, 32
    .cq_dout              ( cq_dout          ), // o, 1
    /* --------ARM CQ interface{end}-------- */
    
    /* --------ARM EQ interface{begin}-------- */
    .eq_ren               ( eq_ren           ), // i, 1
    .eq_num               ( eq_num           ), // i, 31
    .eq_dout              ( eq_dout          ), // o, 1
    /* --------ARM EQ interface{end}-------- */

    /* --------Interrupt Vector entry request & response{begin}-------- */
    .pio_eq_int_req_valid ( pio_eq_int_req_valid ), // i, 1
    .pio_eq_int_req_num   ( pio_eq_int_req_num[`RDMA_MSIX_NUM_LOG-1:0] ), // i, `RDMA_MSIX_NUM_LOG
    .pio_eq_int_req_ready ( pio_eq_int_req_ready ), // o, 1

    .pio_eq_int_rsp_valid ( pio_eq_int_rsp_valid ), // i, 1
    .pio_eq_int_rsp_data  ( pio_eq_int_rsp_data  ), // i, `RDMA_MSIX_DATA_W
    .pio_eq_int_rsp_ready ( pio_eq_int_rsp_ready ), // o, 1
    /* -------Interrupt Vector entry request & response{end}-------- */

    /* -------Reset signal{begin}------- */
    .cmd_rst              ( cmd_rst    ), // o, 1
    /* -------Reset signal{end}------- */

    /* --------Interact with Ethernet BAR{begin}------- */
    .m_axil_awaddr  ( m_axi_awaddr  ) , // o, AXIL_ADDR_WIDTH
    .m_axil_awvalid ( m_axi_awvalid ) , // o, 1
    .m_axil_awready ( m_axi_awready ) , // i, 1

    .m_axil_wdata   ( m_axi_wdata   ), // o, AXIL_DATA_WIDTH
    .m_axil_wstrb   ( m_axi_wstrb   ), // o, AXIL_STRB_WIDTH
    .m_axil_wvalid  ( m_axi_wvalid  ), // o, 1
    .m_axil_wready  ( m_axi_wready  ), // i, 1

    .m_axil_bvalid  ( m_axi_bvalid  ), // i, 1
    .m_axil_bready  ( m_axi_bready  ), // o, 1

    .m_axil_araddr  ( m_axi_araddr  ), // o, AXIL_ADDR_WIDTH
    .m_axil_arvalid ( m_axi_arvalid ), // o, 1
    .m_axil_arready ( m_axi_arready ), // i, 1
    
    .m_axil_rdata   ( m_axi_rdata   ), // i, AXIL_DATA_WIDTH
    .m_axil_rvalid  ( m_axi_rvalid  ), // i, 1
    .m_axil_rready  ( m_axi_rready  ), // o, 1
    /* --------Interact with Ethernet BAR{end}------- */

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
    ,.rw_data ( pio_rw_data ) // i, `SRAM_RW_DATA_W*8
    ,.dbg_sel ( pio_dbg_sel ) // i, 32; debug bus select
    ,.dbg_bus ( pio_dbg_bus ) // o, 32; debug bus data    
    /* -------APB reated signal{end}------- */
`endif
);

assign s_axis_cc_tuser = s_axis_cc_tvalid ?
                         {odd_bit(s_axis_cc_tdata[8 * 32 - 1: 8 * 31]),
                          odd_bit(s_axis_cc_tdata[8 * 31 - 1: 8 * 30]),
                          odd_bit(s_axis_cc_tdata[8 * 30 - 1: 8 * 29]),
                          odd_bit(s_axis_cc_tdata[8 * 29 - 1: 8 * 28]),
                          odd_bit(s_axis_cc_tdata[8 * 28 - 1: 8 * 27]),
                          odd_bit(s_axis_cc_tdata[8 * 27 - 1: 8 * 26]),
                          odd_bit(s_axis_cc_tdata[8 * 26 - 1: 8 * 25]),
                          odd_bit(s_axis_cc_tdata[8 * 25 - 1: 8 * 24]),
                          odd_bit(s_axis_cc_tdata[8 * 24 - 1: 8 * 23]),
                          odd_bit(s_axis_cc_tdata[8 * 23 - 1: 8 * 22]),
                          odd_bit(s_axis_cc_tdata[8 * 22 - 1: 8 * 21]),
                          odd_bit(s_axis_cc_tdata[8 * 21 - 1: 8 * 20]),
                          odd_bit(s_axis_cc_tdata[8 * 20 - 1: 8 * 19]),
                          odd_bit(s_axis_cc_tdata[8 * 19 - 1: 8 * 18]),
                          odd_bit(s_axis_cc_tdata[8 * 18 - 1: 8 * 17]),
                          odd_bit(s_axis_cc_tdata[8 * 17 - 1: 8 * 16]),
                          odd_bit(s_axis_cc_tdata[8 * 16 - 1: 8 * 15]),
                          odd_bit(s_axis_cc_tdata[8 * 15 - 1: 8 * 14]),
                          odd_bit(s_axis_cc_tdata[8 * 14 - 1: 8 * 13]),
                          odd_bit(s_axis_cc_tdata[8 * 13 - 1: 8 * 12]),
                          odd_bit(s_axis_cc_tdata[8 * 12 - 1: 8 * 11]),
                          odd_bit(s_axis_cc_tdata[8 * 11 - 1: 8 * 10]),
                          odd_bit(s_axis_cc_tdata[8 * 10 - 1: 8 * 9 ]),
                          odd_bit(s_axis_cc_tdata[8 * 9  - 1: 8 * 8 ]),
                          odd_bit(s_axis_cc_tdata[8 * 8  - 1: 8 * 7 ]),
                          odd_bit(s_axis_cc_tdata[8 * 7  - 1: 8 * 6 ]),
                          odd_bit(s_axis_cc_tdata[8 * 6  - 1: 8 * 5 ]),
                          odd_bit(s_axis_cc_tdata[8 * 5  - 1: 8 * 4 ]),
                          odd_bit(s_axis_cc_tdata[8 * 4  - 1: 8 * 3 ]),
                          odd_bit(s_axis_cc_tdata[8 * 3  - 1: 8 * 2 ]),
                          odd_bit(s_axis_cc_tdata[8 * 2  - 1: 8 * 1 ]),
                          odd_bit(s_axis_cc_tdata[8 * 1  - 1: 8 * 0 ]), 
                          1'b0} : 33'd0;
/* --------STD_PIO Engine{end}-------- */


//P2P #(
//    
//) P2P_inst (
//    .clk       ( user_clk      ), // i, 1
//    .rst_n     ( user_rst_n    ), // i, 1
//    .init_done ( p2p_init_done ), // o, 1
//
//    /* --------P2P Configuration Channel{begin}-------- */
//    /* p2p_req head
//     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
//     * | is_wr | Reserved | addr  | Reserved | byte_len |
//     */
//    .p2p_cfg_req_valid   ( p2p_cfg_req_valid  ), // i, 1
//    .p2p_cfg_req_last    ( p2p_cfg_req_last   ), // i, 1
//    .p2p_cfg_req_data    ( p2p_cfg_req_data   ), // i, `P2P_DATA_W
//    .p2p_cfg_req_head    ( p2p_cfg_req_head   ), // i, `P2P_HEAD_W
//    .p2p_cfg_req_ready   ( p2p_cfg_req_ready  ), // o, 1
//    
//    .p2p_cfg_rrsp_valid  ( p2p_cfg_rrsp_valid ), // o, 1
//    .p2p_cfg_rrsp_last   ( p2p_cfg_rrsp_last  ), // o, 1
//    .p2p_cfg_rrsp_data   ( p2p_cfg_rrsp_data  ), // o, `P2P_DATA_W
//    .p2p_cfg_rrsp_ready  ( p2p_cfg_rrsp_ready ), // i, 1
//    /* --------P2P Configuration Channel{end}-------- */
//
//    /* -------P2P Memory Access Channel{begin}-------- */
//    /* p2p_req head
//     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
//     * | is_wr | Reserved | addr  | Reserved | byte_len |
//     */
//    .p2p_mem_req_valid   ( p2p_mem_req_valid  ), // i, 1
//    .p2p_mem_req_last    ( p2p_mem_req_last   ), // i, 1
//    .p2p_mem_req_data    ( p2p_mem_req_data   ), // i, `P2P_DATA_W
//    .p2p_mem_req_head    ( p2p_mem_req_head   ), // i, `P2P_HEAD_W
//    .p2p_mem_req_ready   ( p2p_mem_req_ready  ), // o, 1
//    /* -------P2P Memory Access Channel{end}-------- */
//
//    /* --------P2P DMA Write Req{begin}-------- */
//    /* dma_*_head, valid only in first beat of a packet
//     * | Reserved | address | Reserved | Byte length |
//     * |  127:96  |  95:32  |  31:13   |    12:0     |
//     */
//    .p2p_dma_wr_req_valid ( p2p_dma_wr_req_valid ), // o, 1             
//    .p2p_dma_wr_req_last  ( p2p_dma_wr_req_last  ), // o, 1             
//    .p2p_dma_wr_req_data  ( p2p_dma_wr_req_data  ), // o, `P2P_DATA_W  
//    .p2p_dma_wr_req_head  ( p2p_dma_wr_req_head  ), // o, `DMA_HEAD_W
//    .p2p_dma_wr_req_ready ( p2p_dma_wr_req_ready ), // i, 1        
//    /* --------P2P DMA Write Req{end}-------- */
//
//    /* --------p2p forward up channel{begin}-------- */
//    /* *_head, valid only in first beat of a packet
//     * | Reserved | dst_dev | src_dev | Reserved | Byte length |
//     * |  63:35   |  37:35  |  34:32  |  31:16   |    15:0     |
//     */
//    .p2p_upper_valid ( p2p_upper_valid ), // i, 1             
//    .p2p_upper_last  ( p2p_upper_last  ), // i, 1             
//    .p2p_upper_data  ( p2p_upper_data  ), // i, `P2P_DATA_W  
//    .p2p_upper_head  ( p2p_upper_head  ), // i, `P2P_UHEAD_W
//    .p2p_upper_ready ( p2p_upper_ready ), // o, 1        
//    /* --------p2p forward up channel{end}-------- */
//
//    /* --------p2p forward down channel{begin}-------- */
//    /* *_head, valid only in first beat of a packet
//     * | Reserved | dst_dev | src_dev | Reserved | Byte length |
//     * |  63:35   |  37:35  |  34:32  |  31:16   |    15:0     |
//     */
//    .p2p_down_valid ( p2p_down_valid ), // o, 1             
//    .p2p_down_last  ( p2p_down_last  ), // o, 1             
//    .p2p_down_data  ( p2p_down_data  ), // o, `P2P_DATA_W  
//    .p2p_down_head  ( p2p_down_head  ), // o, `P2P_DHEAD_W
//    .p2p_down_ready ( p2p_down_ready )  // i, 1        
//    /* --------p2p forward down channel{end}-------- */
//
//`ifdef PCIEI_APB_DBG
//    /* -------APB reated signal{begin}------- */
//    ,.rw_data ( p2p_rw_data ) // i, (2*`QUEUE_NUM+4)*`SRAM_RW_DATA_W
//    ,.dbg_sel ( p2p_dbg_sel ) // i, 32; debug bus select
//    ,.dbg_bus ( p2p_dbg_bus ) // o, 32; debug bus data    
//    /* -------APB reated signal{end}------- */
//`endif
//);

//ila_max_payload_size ila_max_payload_size_inst(
//    .clk(user_clk),
//    .probe0(cfg_max_payload),
//    .probe1(cfg_max_read_req)
//);

endmodule
