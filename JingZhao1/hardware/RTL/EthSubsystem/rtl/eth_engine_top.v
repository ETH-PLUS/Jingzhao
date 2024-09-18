`timescale 1ns/1ps

//*************************************************************************
// > File Name: eth_engine_top.v
// > Author   : Li jianxiong
// > Date     : 2021-11-02
// > Note     : eth_engine_top is the top module of the eth, 
//              it contains the desc_provider and rx tx engine
// > V1.1 - 2021-11-02 : 
//*************************************************************************
module eth_engine_top #(
    /* axil parameter */
  parameter AXIL_CSR_ADDR_WIDTH   = 12,
  parameter AXIL_QUEUE_ADDR_WIDTH = 12,
  parameter AXIL_MSIX_ADDR_WIDTH  = 12,

  /* some feature of the eth nic */
  parameter RX_RSS_ENABLE = 1, 
  parameter RX_HASH_ENABLE = 1,
  parameter TX_CHECKSUM_ENABLE = 1,
  parameter RX_CHECKSUM_ENABLE = 1,
  parameter RX_VLAN_ENABLE = 1,
  parameter QUEUE_COUNT  = 32,

  parameter DESC_TABLE_SIZE = 32,

	parameter	RO_REG_NUM = 1,
	parameter	RW_REG_NUM = 14  // total 

) (
  input   wire                              clk,
  input   wire                              rst_n,

  /* -------interface to mac rx{begin}------- */
  /*interface to mac rx  */

  input     wire                                  axis_rx_valid, 
  input     wire                                  axis_rx_last,
  input     wire [`DMA_DATA_WIDTH-1:0]            axis_rx_data,
  input     wire [`DMA_KEEP_WIDTH-1:0]            axis_rx_data_be,
  output    wire                                  axis_rx_ready,
  input     wire [`XBAR_USER_WIDTH-1:0]           axis_rx_user,
  input     wire                                  axis_rx_start,

  /* -------interface to mac rx{end}------- */


    /* to dma module, to get the desc */
  output wire                               rx_desc_dma_req_valid,
  output wire                               rx_desc_dma_req_last,
  output wire [`DMA_DATA_WIDTH-1:0]          rx_desc_dma_req_data,
  output wire [`DMA_HEAD_WIDTH-1:0]          rx_desc_dma_req_head,
  input  wire                               rx_desc_dma_req_ready,

  input   wire                               rx_desc_dma_rsp_valid,
  input   wire                               rx_desc_dma_rsp_last,
  input   wire [`DMA_DATA_WIDTH-1:0]          rx_desc_dma_rsp_data,
  input   wire [`DMA_HEAD_WIDTH-1:0]          rx_desc_dma_rsp_head,
  output  wire                               rx_desc_dma_rsp_ready,
  /* -------to dma module, to get the desc{end}------- */

  /* -------to dma module , to write the frame{begin}------- */
  output wire                               rx_axis_wr_valid,
  output wire                               rx_axis_wr_last,
  output wire [`DMA_DATA_WIDTH-1:0]          rx_axis_wr_data,
  output wire [`DMA_HEAD_WIDTH-1:0]          rx_axis_wr_head,
  input  wire                               rx_axis_wr_ready,
  /* -------to dma module , to write the frame{end}------- */

  /*interface to mac rx  */
  output  wire                                  axis_tx_valid,
  output  wire                                  axis_tx_last,
  output  wire [`DMA_DATA_WIDTH-1:0]            axis_tx_data,
  output  wire [`DMA_KEEP_WIDTH-1:0]            axis_tx_data_be,
  input   wire                                  axis_tx_ready,
  output wire  [`XBAR_USER_WIDTH-1:0]           axis_tx_user,
  output wire                                   axis_tx_start,
  
  /* to dma module, to get the desc */
  output wire                               tx_desc_dma_req_valid,
  output wire                               tx_desc_dma_req_last,
  output wire [`DMA_DATA_WIDTH-1:0]          tx_desc_dma_req_data,
  output wire [`DMA_HEAD_WIDTH-1:0]          tx_desc_dma_req_head,
  input  wire                               tx_desc_dma_req_ready,

  /* to dma module, to get the desc */
  input   wire                               tx_desc_dma_rsp_valid,
  input   wire [`DMA_DATA_WIDTH-1:0]          tx_desc_dma_rsp_data,
  input   wire [`DMA_HEAD_WIDTH-1:0]          tx_desc_dma_rsp_head,
  input   wire                               tx_desc_dma_rsp_last,
  output  wire                               tx_desc_dma_rsp_ready,

    /* to dma module, to get the frame */
  output wire                               tx_frame_req_valid,
  output wire                               tx_frame_req_last,
  output wire [`DMA_DATA_WIDTH-1:0]          tx_frame_req_data,
  output wire [`DMA_HEAD_WIDTH-1:0]          tx_frame_req_head,
  input  wire                               tx_frame_req_ready,

  /* interface to dma */
  input   wire                               tx_frame_rsp_valid,
  input   wire [`DMA_DATA_WIDTH-1:0]          tx_frame_rsp_data,
  input   wire [`DMA_HEAD_WIDTH-1:0]          tx_frame_rsp_head,
  input   wire                               tx_frame_rsp_last,
  output  wire                               tx_frame_rsp_ready,

  
  /* completion data dma interface */
  output wire                               tx_axis_wr_valid,
  output wire [`DMA_DATA_WIDTH-1:0]          tx_axis_wr_data,
  output wire [`DMA_HEAD_WIDTH-1:0]          tx_axis_wr_head,
  output wire                               tx_axis_wr_last,
  input  wire                               tx_axis_wr_ready,
  

  /*interface to roce rx  */
  input   wire                                i_roce_prog_full,
  output  wire [`DMA_DATA_WIDTH-1:0]          ov_roce_data,
  output  wire                                o_roce_wr_en,

  /* input from roce desc, request for a desc */
  input   wire                                i_tx_desc_empty,
  input   wire     [`ROCE_DESC_WIDTH-1:0]     iv_tx_desc_data,
  output  wire                                o_tx_desc_rd_en,

  input   wire                                i_roce_empty,
  input   wire   [`DMA_DATA_WIDTH-1:0]        iv_roce_data,
  output  wire                                o_roce_rd_en,



  // Write Address Channel from Master 1
  input wire                       awvalid_m,
  input wire  [`AXI_AW-1:0]        awaddr_m,
  output  wire                     awready_m,
  
// Write Data Channel from Master 1
  input wire                       wvalid_m,
  input wire  [`AXI_DW-1:0]        wdata_m,
  input wire  [`AXI_SW-1:0]        wstrb_m,
  output  wire                      wready_m,
// Write Response Channel from Master 1
  output  wire                      bvalid_m,
  input wire                       bready_m,
// Read Address Channel from Master 1
  input wire                       arvalid_m,
  input wire  [`AXI_AW-1:0]        araddr_m,
  output  wire                      arready_m,

// Read Data Channel from Master 1
  output  wire                      rvalid_m,
  output  wire [`AXI_DW-1:0]        rdata_m,
  input wire                       rready_m

`ifdef ETH_CHIP_DEBUG
	,output 	wire 	[RO_REG_NUM * 32 - 1 : 0]	ro_data
	,output wire 	[RW_REG_NUM * 32 - 1 : 0]	init_rw_data  //
	,input 	wire 	[RW_REG_NUM * 32 - 1 : 0]	rw_data  // total 18 ram

	,input 	  wire 		[31 : 0]		  Dbg_sel
	//,output 	wire 		[524 * 32 - 1 : 0]		  Dbg_bus
	,output 	wire 		[32 - 1 : 0]		  Dbg_bus
`endif


`ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved | reserved | idx | end | out |
     * |  255:10  |   9:5    | 4:2 |  1  |  0  |
     */
    ,output wire [255:0] debug_tx_dma
    ,output wire [255:0] debug_tx_macproc
    ,output wire [255:0] debug_rx_dma
    ,output wire [255:0] debug_tx_roce_mac
    ,output wire [255:0] debug_cpl_finish
    ,output wire [255:0] debug_rx_roce
    ,output wire [255:0] debug_rx_csum
    ,output wire [255:0] debug_desc_fetch_tx
    ,output wire [255:0] debug_desc_fetch_rx
    /* ------- Debug interface {end}------- */
`endif
);

assign init_rw_data = 'd0;
assign ro_data = rw_data;

localparam RX_QUEUE_COUNT = QUEUE_COUNT;
localparam AXIL_RX_QM_BASE_ADDR = 32'h1000;
localparam RX_CPL_QUEUE_COUNT = QUEUE_COUNT;
localparam AXIL_RX_CQM_BASE_ADDR = 32'h1000;
localparam TX_QUEUE_COUNT = QUEUE_COUNT;
localparam AXIL_TX_QM_BASE_ADDR = 20'h2000;
localparam TX_CPL_QUEUE_COUNT = QUEUE_COUNT;
localparam AXIL_TX_CQM_BASE_ADDR = 32'h2000;
localparam TX_MTU = 1500;
localparam RX_MTU = 1500;
localparam INTERRUPTE_NUM = 64;

wire                                  axis_rx_mac_valid;
wire                                  axis_rx_mac_last;
wire [`DMA_DATA_WIDTH-1:0]            axis_rx_mac_data;
wire [`DMA_KEEP_WIDTH-1:0]            axis_rx_mac_data_be;
wire                                  axis_rx_mac_ready;
wire   [`XBAR_USER_WIDTH-1:0]         axis_rx_mac_user;
wire                                  axis_rx_mac_start;

wire                                  axis_rx_roce_valid;
wire                                  axis_rx_roce_last;
wire [`DMA_DATA_WIDTH-1:0]            axis_rx_roce_data;
wire [`DMA_KEEP_WIDTH-1:0]            axis_rx_roce_data_be;
wire                                  axis_rx_roce_ready;
wire  [`XBAR_USER_WIDTH-1:0]          axis_rx_roce_user;
wire                                  axis_rx_roce_start;

/* input from rx_engine, request for a desc */
wire [`QUEUE_NUMBER_WIDTH-1:0]     rx_desc_req_qnum;
wire                              rx_desc_req_valid;
wire                              rx_desc_req_ready;

/* to rx_engine,  return the desc data */
wire [`STATUS_WIDTH-1:0]          rx_desc_rsp_status;
wire [`QUEUE_NUMBER_WIDTH-1:0]     rx_desc_rsp_qnum;
wire [`QUEUE_INDEX_WIDTH-1:0]      rx_desc_rsp_qindex;
wire [`ETH_LEN_WIDTH-1:0]          rx_desc_rsp_length;
wire [`DMA_ADDR_WIDTH-1:0]         rx_desc_rsp_dma_addr;
wire [`DMA_ADDR_WIDTH-1:0]         rx_desc_rsp_cpl_addr;
wire [`IRQ_MSG-1:0]                 rx_desc_rsp_msix_msg;
wire [`DMA_ADDR_WIDTH-1:0]          rx_desc_rsp_msix_addr;
wire                              rx_desc_rsp_valid;
wire                              rx_desc_rsp_ready;

wire    [`MSI_NUM_WIDTH-1:0]            rx_irq_req_msix;
wire                                    rx_irq_req_valid;
wire                                    rx_irq_req_ready;

wire   [`IRQ_MSG-1:0]                 rx_irq_rsp_msg;
wire   [`DMA_ADDR_WIDTH-1:0]          rx_irq_rsp_addr;
wire                                  rx_irq_rsp_valid;
wire                                  rx_irq_rsp_ready;


wire [`QUEUE_NUMBER_WIDTH-1:0]      rx_cpl_finish_qnum;
wire                                rx_cpl_finish_valid;
wire                                rx_cpl_finish_ready;

wire  [`QUEUE_NUMBER_WIDTH-1:0]     tx_doorbell_queue;
wire                                tx_doorbell_valid;

wire                                   start_sche;
wire                                   msix_enable;

/* input from tx_engine, request for a desc */
wire [`QUEUE_NUMBER_WIDTH-1:0]      tx_desc_req_qnum;
wire                                tx_desc_req_valid;
wire                                tx_desc_req_ready;

/* to tx_engine,  return the desc data */
wire [`STATUS_WIDTH-1:0]            tx_desc_rsp_status;
wire [`QUEUE_NUMBER_WIDTH-1:0]      tx_desc_rsp_qnum;
wire [`QUEUE_INDEX_WIDTH-1:0]       tx_desc_rsp_qindex;
wire [`ETH_LEN_WIDTH-1:0]           tx_desc_rsp_length;
wire [`DMA_ADDR_WIDTH-1:0]          tx_desc_rsp_dma_addr;
wire [`DMA_ADDR_WIDTH-1:0]          tx_desc_rsp_desc_addr;
wire [`CSUM_START_WIDTH-1:0]        tx_desc_rsp_csum_start;
wire [`CSUM_START_WIDTH-1:0]        tx_desc_rsp_csum_offset;
wire [`DMA_ADDR_WIDTH-1:0]          tx_desc_rsp_cpl_addr;
wire [`IRQ_MSG-1:0]                 tx_desc_rsp_msix_msg;
wire [`DMA_ADDR_WIDTH-1:0]          tx_desc_rsp_msix_addr;
wire                                tx_desc_rsp_valid;
wire                                tx_desc_rsp_ready;

wire                                  axis_tx_mac_valid;
wire                                  axis_tx_mac_last;
wire [`DMA_DATA_WIDTH-1:0]            axis_tx_mac_data;
wire [`DMA_KEEP_WIDTH-1:0]            axis_tx_mac_data_be;
wire                                  axis_tx_mac_ready;
wire [`XBAR_USER_WIDTH-1:0]           axis_tx_mac_user;

wire                                  axis_tx_roce_valid;
wire                                  axis_tx_roce_last;
wire [`DMA_DATA_WIDTH-1:0]            axis_tx_roce_data;
wire [`DMA_KEEP_WIDTH-1:0]            axis_tx_roce_data_be;
wire                                  axis_tx_roce_ready;
wire [`XBAR_USER_WIDTH-1:0]           axis_tx_roce_user;

wire   [`MSI_NUM_WIDTH-1:0]             tx_irq_req_msix;
wire                                    tx_irq_req_valid;
wire                                    tx_irq_req_ready;

wire [`QUEUE_NUMBER_WIDTH-1:0]      tx_cpl_finish_qnum;
wire                                tx_cpl_finish_valid;
wire                                tx_cpl_finish_ready;

wire   [`IRQ_MSG-1:0]                 tx_irq_rsp_msg;
wire   [`DMA_ADDR_WIDTH-1:0]          tx_irq_rsp_addr;
wire                                  tx_irq_rsp_valid;
wire                                  tx_irq_rsp_ready;

/* to tx roceproc, to get the desc */
wire [`ROCE_DTYP_WIDTH-1:0]         tx_desc_dtyp;
wire [`ROCE_LEN_WIDTH-1:0]          tx_desc_len;
wire [`MAC_WIDTH-1:0]               tx_desc_smac;
wire [`MAC_WIDTH-1:0]               tx_desc_dmac;
wire [`IP_WIDTH-1:0]                tx_desc_sip;
wire [`IP_WIDTH-1:0]                tx_desc_dip;
wire                                tx_desc_valid;
wire                                tx_desc_ready;


// Write Address Channel from Slave 1
  wire                      awvalid_csr;
  wire [`AXI_AW-1:0]        awaddr_csr;
  wire                      awready_csr;
// Write Data Channel from Slave 1
  wire                      wvalid_csr;
  wire [`AXI_DW-1:0]        wdata_csr;
  wire [`AXI_SW-1:0]        wstrb_csr;
  wire                       wready_csr;
// Write Response Channel from Slave 1
  wire                       bvalid_csr;
  wire                      bready_csr;
// Read Address Channel from Slave 1
  wire                      arvalid_csr;
  wire [`AXI_AW-1:0]        araddr_csr;
  wire                       arready_csr;
// Read Data Channel from Slave 1
  wire                       rvalid_csr;
  wire  [`AXI_DW-1:0]        rdata_csr;
  wire                      rready_csr;

// Write Address Channel from Slave2
  wire                      awvalid_rx;
  wire [`AXI_AW-1:0]        awaddr_rx;
  wire                       awready_rx;
// Write Data Channel from Slave2
  wire                      wvalid_rx;
  wire [`AXI_DW-1:0]        wdata_rx;
  wire [`AXI_SW-1:0]        wstrb_rx;
  wire                       wready_rx;
// Write Response Channel from Slave2
  wire                       bvalid_rx;
  wire                      bready_rx;
// Read Address Channel from Slave2
  wire                      arvalid_rx;
  wire [`AXI_AW-1:0]        araddr_rx;
  wire                       arready_rx;
// Read Data Channel from Slave2
  wire                       rvalid_rx;
  wire  [`AXI_DW-1:0]        rdata_rx;
  wire                      rready_rx;

// Write Address Channel from Slave3
  wire                      awvalid_tx;
  wire [`AXI_AW-1:0]        awaddr_tx;
  wire                       awready_tx;
// Write Data Channel from Slave3
  wire                      wvalid_tx;
  wire [`AXI_DW-1:0]        wdata_tx;
  wire [`AXI_SW-1:0]        wstrb_tx;
  wire                       wready_tx;
// Write Response Channel from Slave3
  wire                       bvalid_tx;
  wire                      bready_tx;
// Read Address Channel from Slave3
  wire                      arvalid_tx;
  wire [`AXI_AW-1:0]        araddr_tx;
  wire                       arready_tx;
// Read Data Channel from Slave3
  wire                        rvalid_tx;
  wire  [`AXI_DW-1:0]         rdata_tx;
  wire                        rready_tx;


  // Write Address Channel from Slave 4
  wire                      awvalid_msix;
  wire [`AXI_AW-1:0]        awaddr_msix;
  wire                      awready_msix;
// Write Data Channel from Slave 4
  wire                      wvalid_msix;
  wire [`AXI_DW-1:0]        wdata_msix;
  wire [`AXI_SW-1:0]        wstrb_msix;
  wire                       wready_msix;
// Write Response Channel from Slave 4
  wire                       bvalid_msix;
  wire                      bready_msix;
// Read Address Channel from Slave 4
  wire                      arvalid_msix;
  wire [`AXI_AW-1:0]        araddr_msix;
  wire                       arready_msix;
// Read Data Channel from Slave 4
  wire                       rvalid_msix;
  wire  [`AXI_DW-1:0]        rdata_msix;
  wire                      rready_msix;


wire [31:0]                           tx_mac_proc_rec_cnt;
wire [31:0]                           tx_mac_proc_xmit_cnt;
wire [31:0]                           tx_mac_proc_cpl_cnt;
wire [31:0]                           tx_mac_proc_msix_cnt;

wire [31:0]                           rx_mac_proc_rec_cnt;
wire [31:0]                           rx_mac_proc_desc_cnt;
wire [31:0]                           rx_mac_proc_cpl_cnt;
wire [31:0]                           rx_mac_proc_msix_cnt;
wire [31:0]                           rx_mac_proc_error_cnt;

wire [31:0]                           mac_fifo_rev_cnt;
wire [31:0]                           mac_fifo_send_cnt;
wire [31:0]                           mac_fifo_error_cnt;

wire [31:0]                           tx_desc_fetch_req_cnt;
wire [31:0]                           tx_desc_fetch_rsp_cnt;
wire [31:0]                           tx_desc_fetch_error_cnt;

wire [31:0]                           rx_desc_fetch_req_cnt;
wire [31:0]                           rx_desc_fetch_rsp_cnt;
wire [31:0]                           rx_desc_fetch_error_cnt;


`ifdef SIMULATION
  assign debug_cpl_finish = {tx_cpl_finish_ready && tx_cpl_finish_valid,
                                rx_cpl_finish_ready && rx_cpl_finish_valid};
`endif

`ifdef ETH_CHIP_DEBUG

wire 		[`DBG_DATA_WIDTH-1 : 0]		        Dbg_bus_eth_engine_top;

wire 		[`DBG_DATA_WIDTH-1 : 0]         Dbg_sel_ncsr_manager;
wire 		[`DBG_DATA_WIDTH-1 : 0]         Dbg_sel_msix_manager;
wire 		[`DBG_DATA_WIDTH-1 : 0]	        Dbg_sel_rx_desc_provider;
wire 		[`DBG_DATA_WIDTH-1 : 0]	        Dbg_sel_rx_mac_engine;
wire 		[`DBG_DATA_WIDTH-1 : 0]         Dbg_sel_rx_roceproc;
wire 		[`DBG_DATA_WIDTH-1 : 0]	        Dbg_sel_rx_distributor;
wire 		[`DBG_DATA_WIDTH-1 : 0]	        Dbg_sel_tx_desc_provider;
wire 		[`DBG_DATA_WIDTH-1 : 0]	        Dbg_sel_tx_mac_engine;
wire 		[`DBG_DATA_WIDTH-1 : 0]         Dbg_sel_tx_rocedesc;
wire 		[`DBG_DATA_WIDTH-1 : 0]         Dbg_sel_tx_roceproc;


wire 		[`DBG_DATA_WIDTH-1 : 0]         Dbg_bus_ncsr_manager;
wire 		[`DBG_DATA_WIDTH-1 : 0]         Dbg_bus_msix_manager;
wire 		[`DBG_DATA_WIDTH-1 : 0]	        Dbg_bus_rx_desc_provider;
wire 		[`DBG_DATA_WIDTH-1 : 0]	        Dbg_bus_rx_mac_engine;
wire 		[`DBG_DATA_WIDTH-1 : 0]         Dbg_bus_rx_roceproc;
wire 		[`DBG_DATA_WIDTH-1 : 0]	        Dbg_bus_rx_distributor;
wire 		[`DBG_DATA_WIDTH-1 : 0]	        Dbg_bus_tx_desc_provider;
wire 		[`DBG_DATA_WIDTH-1 : 0]	        Dbg_bus_tx_mac_engine;
wire 		[`DBG_DATA_WIDTH-1 : 0]         Dbg_bus_tx_rocedesc;
wire 		[`DBG_DATA_WIDTH-1 : 0]         Dbg_bus_tx_roceproc;

//wire 		[`NCSR_MANAGER_DEG_REG_NUM * 32 -1 : 0]         Dbg_bus_ncsr_manager;
//wire 		[`MSIX_MANAGER_DEG_REG_NUM * 32 -1 : 0]         Dbg_bus_msix_manager;
//wire 		[`DESC_PROVIDER_DEG_REG_NUM * 32 -1 : 0]	        Dbg_bus_rx_desc_provider;
//wire 		[`RX_MAC_ENGINE_DEG_REG_NUM * 32 -1 : 0]	        Dbg_bus_rx_mac_engine;
//wire 		[`RX_ROCEPROC_DEG_REG_NUM * 32 -1 : 0]         Dbg_bus_rx_roceproc;
//wire 		[`RX_DISTRIBUTER_DEG_REG_NUM * 32 -1 : 0]	        Dbg_bus_rx_distributor;
//wire 		[`DESC_PROVIDER_DEG_REG_NUM * 32-1 : 0]	        Dbg_bus_tx_desc_provider;
//wire 		[`TX_MAC_ENGINE_DEG_REG_NUM * 32-1 : 0]	        Dbg_bus_tx_mac_engine;
//wire 		[`TX_ROCEDESC_DEG_REG_NUM * 32-1 : 0]         Dbg_bus_tx_rocedesc;
//wire 		[`TX_ROCEPROC_DEG_REG_NUM * 32-1 : 0]         Dbg_bus_tx_roceproc;



assign Dbg_bus_eth_engine_top = (Dbg_sel >= `NCSR_MANAGER_DEG_REG_OFFSET        && Dbg_sel < `MSIX_MANAGER_DEG_REG_OFFSET)        ? Dbg_bus_ncsr_manager :
                                (Dbg_sel >= `MSIX_MANAGER_DEG_REG_OFFSET        && Dbg_sel < `RX_DESC_PROVIDER_DEG_REG_OFFSET)    ? Dbg_bus_msix_manager :
                                (Dbg_sel >= `RX_DESC_PROVIDER_DEG_REG_OFFSET    && Dbg_sel < `RX_MAC_ENGINE_DEG_REG_OFFSET)       ? Dbg_bus_rx_desc_provider :
                                (Dbg_sel >= `RX_MAC_ENGINE_DEG_REG_OFFSET       && Dbg_sel < `RX_ROCEPROC_DEG_REG_OFFSET)         ? Dbg_bus_rx_mac_engine :
                                (Dbg_sel >= `RX_ROCEPROC_DEG_REG_OFFSET         && Dbg_sel < `RX_DISTRIBUTER_DEG_REG_OFFSET)      ? Dbg_bus_rx_roceproc :
                                (Dbg_sel >= `RX_DISTRIBUTER_DEG_REG_OFFSET      && Dbg_sel < `TX_DESC_PROVIDER_DEG_REG_OFFSET)    ? Dbg_bus_rx_distributor :
                                (Dbg_sel >= `TX_DESC_PROVIDER_DEG_REG_OFFSET    && Dbg_sel < `TX_MAC_ENGINE_DEG_REG_OFFSET)       ? Dbg_bus_tx_desc_provider :
                                (Dbg_sel >= `TX_MAC_ENGINE_DEG_REG_OFFSET       && Dbg_sel < `TX_ROCEDESC_DEG_REG_OFFSET)         ? Dbg_bus_tx_mac_engine :
                                (Dbg_sel >= `TX_ROCEDESC_DEG_REG_OFFSET         && Dbg_sel < `TX_ROCEPROC_DEG_REG_OFFSET)         ? Dbg_bus_tx_rocedesc :
                                (Dbg_sel >= `TX_ROCEPROC_DEG_REG_OFFSET) ? Dbg_bus_tx_roceproc : 'b0;

assign Dbg_sel_ncsr_manager         = Dbg_sel > `NCSR_MANAGER_DEG_REG_OFFSET      ? Dbg_sel - `NCSR_MANAGER_DEG_REG_OFFSET : 'b0;
assign Dbg_sel_msix_manager         = Dbg_sel > `MSIX_MANAGER_DEG_REG_OFFSET      ? Dbg_sel - `MSIX_MANAGER_DEG_REG_OFFSET : 'b0;
assign Dbg_sel_rx_desc_provider     = Dbg_sel > `RX_DESC_PROVIDER_DEG_REG_OFFSET  ? Dbg_sel - `RX_DESC_PROVIDER_DEG_REG_OFFSET : 'b0;
assign Dbg_sel_rx_mac_engine        = Dbg_sel > `RX_MAC_ENGINE_DEG_REG_OFFSET     ? Dbg_sel - `RX_MAC_ENGINE_DEG_REG_OFFSET : 'b0;
assign Dbg_sel_rx_roceproc          = Dbg_sel > `RX_ROCEPROC_DEG_REG_OFFSET       ? Dbg_sel - `RX_ROCEPROC_DEG_REG_OFFSET : 'b0;
assign Dbg_sel_rx_distributor       = Dbg_sel > `RX_DISTRIBUTER_DEG_REG_OFFSET    ? Dbg_sel - `RX_DISTRIBUTER_DEG_REG_OFFSET : 'b0;
assign Dbg_sel_tx_desc_provider     = Dbg_sel > `TX_DESC_PROVIDER_DEG_REG_OFFSET  ? Dbg_sel - `TX_DESC_PROVIDER_DEG_REG_OFFSET : 'b0;
assign Dbg_sel_tx_mac_engine        = Dbg_sel > `TX_MAC_ENGINE_DEG_REG_OFFSET     ? Dbg_sel - `TX_MAC_ENGINE_DEG_REG_OFFSET : 'b0;
assign Dbg_sel_tx_rocedesc          = Dbg_sel > `TX_ROCEDESC_DEG_REG_OFFSET       ? Dbg_sel - `TX_ROCEDESC_DEG_REG_OFFSET : 'b0;
assign Dbg_sel_tx_roceproc          = Dbg_sel > `TX_ROCEPROC_DEG_REG_OFFSET       ? Dbg_sel - `TX_ROCEPROC_DEG_REG_OFFSET : 'b0;

assign Dbg_bus =  Dbg_bus_eth_engine_top;
//assign Dbg_bus = 	{
//						Dbg_bus_ncsr_manager ,
//                    	Dbg_bus_msix_manager ,
//                    	Dbg_bus_rx_desc_provider ,
//                    	Dbg_bus_rx_mac_engine ,
//                    	Dbg_bus_rx_roceproc ,
//                    	Dbg_bus_rx_distributor ,
//                    	Dbg_bus_tx_desc_provider ,
//                    	Dbg_bus_tx_mac_engine ,
//                    	Dbg_bus_tx_rocedesc ,
//                    	Dbg_bus_tx_roceproc
//					};

`endif

ncsr_manager #(
  /* axil parameter */
  .AXIL_ADDR_WIDTH(AXIL_CSR_ADDR_WIDTH),

  /* some feature of the eth nic */
  .RX_RSS_ENABLE(RX_RSS_ENABLE),
  .RX_HASH_ENABLE(RX_HASH_ENABLE),
  .TX_CHECKSUM_ENABLE(TX_CHECKSUM_ENABLE),
  .RX_CHECKSUM_ENABLE(RX_CHECKSUM_ENABLE),
  .RX_VLAN_ENABLE(RX_VLAN_ENABLE),

  /* queue base addr */
  .TX_QUEUE_COUNT(TX_QUEUE_COUNT),
  .AXIL_TX_QM_BASE_ADDR(AXIL_TX_QM_BASE_ADDR),
  .TX_CPL_QUEUE_COUNT(TX_CPL_QUEUE_COUNT),
  .AXIL_TX_CQM_BASE_ADDR(AXIL_TX_CQM_BASE_ADDR),
  .RX_QUEUE_COUNT(RX_QUEUE_COUNT),
  .AXIL_RX_QM_BASE_ADDR(AXIL_RX_QM_BASE_ADDR),
  .RX_CPL_QUEUE_COUNT(RX_CPL_QUEUE_COUNT),
  .AXIL_RX_CQM_BASE_ADDR(AXIL_RX_CQM_BASE_ADDR)
) 
ncsr_manager_inst
(
  .clk(clk),
  .rst_n(rst_n),

  .start_sche(start_sche),
  .msix_enable(msix_enable),

  /*axil write signal*/
  .awaddr_csr(awaddr_csr[AXIL_CSR_ADDR_WIDTH-1:0]),
  .awvalid_csr(awvalid_csr),
  .awready_csr(awready_csr),
  .wdata_csr(wdata_csr),
  .wstrb_csr(wstrb_csr),
  .wvalid_csr(wvalid_csr),
  .wready_csr(wready_csr),
  .bvalid_csr(bvalid_csr),
  .bready_csr(bready_csr),
  /*axil read signal*/
  .araddr_csr(araddr_csr[AXIL_CSR_ADDR_WIDTH-1:0]),
  .arvalid_csr(arvalid_csr),
  .arready_csr(arready_csr),
  .rdata_csr(rdata_csr),
  .rvalid_csr(rvalid_csr),
  .rready_csr(rready_csr)

  ,.tx_mac_proc_rec_cnt(tx_mac_proc_rec_cnt)
  ,.tx_mac_proc_xmit_cnt(tx_mac_proc_xmit_cnt)
  ,.tx_mac_proc_cpl_cnt(tx_mac_proc_cpl_cnt)
  ,.tx_mac_proc_msix_cnt(tx_mac_proc_msix_cnt)

  ,.rx_mac_proc_rec_cnt(rx_mac_proc_rec_cnt)
  ,.rx_mac_proc_desc_cnt(rx_mac_proc_desc_cnt)
  ,.rx_mac_proc_cpl_cnt(rx_mac_proc_cpl_cnt)
  ,.rx_mac_proc_msix_cnt(rx_mac_proc_msix_cnt)
  ,.rx_mac_proc_error_cnt(rx_mac_proc_error_cnt)

  ,.mac_fifo_rev_cnt(mac_fifo_rev_cnt)
  ,.mac_fifo_send_cnt(mac_fifo_send_cnt)
  ,.mac_fifo_error_cnt(mac_fifo_error_cnt)

  ,.tx_desc_fetch_req_cnt(tx_desc_fetch_req_cnt)
  ,.tx_desc_fetch_rsp_cnt(tx_desc_fetch_rsp_cnt)
  ,.tx_desc_fetch_error_cnt(tx_desc_fetch_error_cnt)

  ,.rx_desc_fetch_req_cnt(rx_desc_fetch_req_cnt)
  ,.rx_desc_fetch_rsp_cnt(rx_desc_fetch_rsp_cnt)
  ,.rx_desc_fetch_error_cnt(rx_desc_fetch_error_cnt)

`ifdef ETH_CHIP_DEBUG
  ,.Dbg_sel(Dbg_sel_ncsr_manager)
	,.Dbg_bus(Dbg_bus_ncsr_manager)
`endif
);


msix_manager #(
  /* axil parameter */
  .AXIL_ADDR_WIDTH(AXIL_MSIX_ADDR_WIDTH),
  .INTERRUPTE_NUM(INTERRUPTE_NUM)
) 
msix_manager_inst
(
  .clk(clk),
  .rst_n(rst_n),

  /*axil write signal*/
  .awaddr_msix(awaddr_msix[AXIL_MSIX_ADDR_WIDTH-1:0]),
  .awvalid_msix(awvalid_msix),
  .awready_msix(awready_msix),
  .wdata_msix(wdata_msix),
  .wstrb_msix(wstrb_msix),
  .wvalid_msix(wvalid_msix),
  .wready_msix(wready_msix),
  .bvalid_msix(bvalid_msix),
  .bready_msix(bready_msix),
  /*axil read signal*/
  .araddr_msix(araddr_msix[AXIL_MSIX_ADDR_WIDTH-1:0]),
  .arvalid_msix(arvalid_msix),
  .arready_msix(arready_msix),
  .rdata_msix(rdata_msix),
  .rvalid_msix(rvalid_msix),
  .rready_msix(rready_msix),

  .tx_irq_req_msix(tx_irq_req_msix),
  .tx_irq_req_valid(tx_irq_req_valid),
  .tx_irq_req_ready(tx_irq_req_ready),
  .tx_irq_rsp_msg(tx_irq_rsp_msg),
  .tx_irq_rsp_addr(tx_irq_rsp_addr),
  .tx_irq_rsp_valid(tx_irq_rsp_valid),
  .tx_irq_rsp_ready(tx_irq_rsp_ready),

  .rx_irq_req_msix(rx_irq_req_msix),
  .rx_irq_req_valid(rx_irq_req_valid),
  .rx_irq_req_ready(rx_irq_req_ready),
  .rx_irq_rsp_msg(rx_irq_rsp_msg),
  .rx_irq_rsp_addr(rx_irq_rsp_addr),
  .rx_irq_rsp_valid(rx_irq_rsp_valid),
  .rx_irq_rsp_ready(rx_irq_rsp_ready)

`ifdef ETH_CHIP_DEBUG
  ,.Dbg_sel(Dbg_sel_msix_manager)
	,.Dbg_bus(Dbg_bus_msix_manager)
`endif
);

/* -------rx path {begin}------- */
desc_provider #(
  .AXIL_ADDR_WIDTH(AXIL_QUEUE_ADDR_WIDTH),

  .QUEUE_COUNT(QUEUE_COUNT),
  .DESC_TABLE_SIZE(DESC_TABLE_SIZE),
  .DEBUG_RX(0)
)
rx_desc_provider_inst
(
  .clk(clk),
  .rst_n(rst_n),

  /* to dma module, to get the desc */
  .desc_dma_req_valid(rx_desc_dma_req_valid),
  .desc_dma_req_last(rx_desc_dma_req_last),
  .desc_dma_req_data(rx_desc_dma_req_data),
  .desc_dma_req_head(rx_desc_dma_req_head),
  .desc_dma_req_ready(rx_desc_dma_req_ready),

  /* to dma module, to get the desc */
  .desc_dma_rsp_valid(rx_desc_dma_rsp_valid),
  .desc_dma_rsp_data(rx_desc_dma_rsp_data),
  .desc_dma_rsp_head(rx_desc_dma_rsp_head),
  .desc_dma_rsp_last(rx_desc_dma_rsp_last),
  .desc_dma_rsp_ready(rx_desc_dma_rsp_ready),

  /* input from rx_engine, request for a desc */
  .desc_req_qnum(rx_desc_req_qnum),
  .desc_req_valid(rx_desc_req_valid),
  .desc_req_ready(rx_desc_req_ready),

  /* to rx_engine,  return the desc data */
  .desc_rsp_status(rx_desc_rsp_status),
  .desc_rsp_qnum(rx_desc_rsp_qnum),
  .desc_rsp_qindex(rx_desc_rsp_qindex),
  .desc_rsp_length(rx_desc_rsp_length),
  .desc_rsp_dma_addr(rx_desc_rsp_dma_addr),
  .desc_rsp_desc_addr(),
  .desc_rsp_csum_start(),
  .desc_rsp_csum_offset(),
  .desc_rsp_cpl_addr(rx_desc_rsp_cpl_addr),
  .desc_rsp_msix_msg(rx_desc_rsp_msix_msg),
  .desc_rsp_msix_addr(rx_desc_rsp_msix_addr),  
  .desc_rsp_valid(rx_desc_rsp_valid),
  .desc_rsp_ready(rx_desc_rsp_ready),

  .doorbell_queue(),
  .doorbell_valid(),

  .irq_req_msix(rx_irq_req_msix),
  .irq_req_valid(rx_irq_req_valid),
  .irq_req_ready(rx_irq_req_ready),

  .irq_rsp_msg(rx_irq_rsp_msg),
  .irq_rsp_addr(rx_irq_rsp_addr),
  .irq_rsp_valid(rx_irq_rsp_valid),
  .irq_rsp_ready(rx_irq_rsp_ready),

  .cpl_finish_qnum(rx_cpl_finish_qnum),
  .cpl_finish_valid(rx_cpl_finish_valid),
  .cpl_finish_ready(rx_cpl_finish_ready),

  /*axil write signal*/
  .awaddr_queue(awaddr_rx[AXIL_QUEUE_ADDR_WIDTH-1:0]),
  .awvalid_queue(awvalid_rx),
  .awready_queue(awready_rx),
  .wdata_queue(wdata_rx),
  .wstrb_queue(wstrb_rx),
  .wvalid_queue(wvalid_rx),
  .wready_queue(wready_rx),
  .bvalid_queue(bvalid_rx),
  .bready_queue(bready_rx),
  /*axil read signal*/
  .araddr_queue(araddr_rx[AXIL_QUEUE_ADDR_WIDTH-1:0]),
  .arvalid_queue(arvalid_rx),
  .arready_queue(arready_rx),
  .rdata_queue(rdata_rx),
  .rvalid_queue(rvalid_rx),
  .rready_queue(rready_rx)
  
  ,.desc_fetch_req_cnt(rx_desc_fetch_req_cnt)
  ,.desc_fetch_rsp_cnt(rx_desc_fetch_rsp_cnt)
  ,.desc_fetch_error_cnt(rx_desc_fetch_error_cnt)

`ifdef ETH_CHIP_DEBUG
  ,.Dbg_sel(Dbg_sel_rx_desc_provider)
	,.Dbg_bus(Dbg_bus_rx_desc_provider)
`endif

  `ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved | reserved | idx | end | out |
     * |  255:10  |   9:5    | 4:2 |  1  |  0  |
     */
    ,.debug_desc_fetch(debug_desc_fetch_rx)
    /* ------- Debug interface {end}------- */
  `endif
);


rx_mac_engine #(
  .QUEUE_COUNT(QUEUE_COUNT),
  .DESC_TABLE_SIZE(DESC_TABLE_SIZE),
  .RX_CHECKSUM_ENABLE(RX_CHECKSUM_ENABLE),
  .RX_VLAN_ENABLE(RX_VLAN_ENABLE)
) 
rx_mac_engine_inst
(
  .clk(clk),
  .rst_n(rst_n),

  /*interface to mac rx  */
  .axis_rx_valid(axis_rx_mac_valid),
  .axis_rx_last(axis_rx_mac_last),
  .axis_rx_data(axis_rx_mac_data),
  .axis_rx_data_be(axis_rx_mac_data_be),
  .axis_rx_ready(axis_rx_mac_ready),

  /* output to desc fetch , request for a desc */
  .rx_desc_req_qnum(rx_desc_req_qnum),
  .rx_desc_req_valid(rx_desc_req_valid),
  .rx_desc_req_ready(rx_desc_req_ready),

  /* from desc, get the desc data */
  .rx_desc_rsp_status(rx_desc_rsp_status),
  .rx_desc_rsp_qnum(rx_desc_rsp_qnum),
  .rx_desc_rsp_qindex(rx_desc_rsp_qindex),
  .rx_desc_rsp_length(rx_desc_rsp_length),
  .rx_desc_rsp_dma_addr(rx_desc_rsp_dma_addr),
  .rx_desc_rsp_cpl_addr(rx_desc_rsp_cpl_addr),
  .rx_desc_rsp_msix_msg(rx_desc_rsp_msix_msg),
  .rx_desc_rsp_msix_addr(rx_desc_rsp_msix_addr),   
  .rx_desc_rsp_valid(rx_desc_rsp_valid),
  .rx_desc_rsp_ready(rx_desc_rsp_ready),
  .rx_desc_rsp_head_ptr(16'd0),
  .rx_desc_rsp_tail_ptr(16'd0),
  .rx_desc_rsp_cpl_head_ptr(16'd0),
  .rx_desc_rsp_cpl_tail_ptr(16'd0),

  .rx_cpl_finish_qnum(rx_cpl_finish_qnum),
  .rx_cpl_finish_valid(rx_cpl_finish_valid),
  .rx_cpl_finish_ready(rx_cpl_finish_ready),

  .rx_axis_wr_valid(rx_axis_wr_valid),
  .rx_axis_wr_data(rx_axis_wr_data),
  .rx_axis_wr_head(rx_axis_wr_head),
  .rx_axis_wr_last(rx_axis_wr_last),
  .rx_axis_wr_ready(rx_axis_wr_ready)

  ,.start_sche(start_sche)
  ,.msix_enable(msix_enable)


  ,.rx_mac_proc_rec_cnt(rx_mac_proc_rec_cnt)
  ,.rx_mac_proc_desc_cnt(rx_mac_proc_desc_cnt)
  ,.rx_mac_proc_cpl_cnt(rx_mac_proc_cpl_cnt)
  ,.rx_mac_proc_msix_cnt(rx_mac_proc_msix_cnt)
  ,.rx_mac_proc_error_cnt(rx_mac_proc_error_cnt)

  ,.mac_fifo_rev_cnt(mac_fifo_rev_cnt)
  ,.mac_fifo_send_cnt(mac_fifo_send_cnt)
  ,.mac_fifo_error_cnt(mac_fifo_error_cnt)

`ifdef ETH_CHIP_DEBUG
  ,.rw_data(rw_data[5 * 32 - 1 : 0])
  ,.Dbg_sel(Dbg_sel_rx_mac_engine)
	,.Dbg_bus(Dbg_bus_rx_mac_engine)
`endif

`ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved | reserved | idx | end | out |
     * |  255:10  |   9:5    | 4:2 |  1  |  0  |
     */
    ,.debug_rx_dma(debug_rx_dma)
    ,.debug_rx_csum(debug_rx_csum)
    /* ------- Debug interface {end}------- */
`endif
);

rx_roceproc 
rx_roceproc_inst
(
  .clk(clk),
  .rst_n(rst_n),

  /*interface to mac tx  */
  .axis_rx_valid(axis_rx_roce_valid), 
  .axis_rx_last(axis_rx_roce_last),
  .axis_rx_data(axis_rx_roce_data),
  .axis_rx_data_be(axis_rx_roce_data_be),
  .axis_rx_ready(axis_rx_roce_ready),

  /*interface to roce rx  */
  .i_roce_prog_full(i_roce_prog_full),
  .ov_roce_data(ov_roce_data),
  .o_roce_wr_en(o_roce_wr_en)

`ifdef ETH_CHIP_DEBUG
  ,.Dbg_sel(Dbg_sel_rx_roceproc)
	,.Dbg_bus(Dbg_bus_rx_roceproc)
    ,.rw_data(rw_data[5*32 +: 2*32])
`endif

`ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved |  | data_be | last |
     * |  255:64  |  |  63:32  |  0  |
     */
    ,.debug(debug_rx_roce)
    ,.rw_data(rw_data[5*32 +: 2*32])
    /* ------- Debug interface {end}------- */
`endif
);


rx_distributor 
rx_distributor_inst
(
  .clk(clk),
  .rst_n(rst_n),

  .axis_rx_valid(axis_rx_valid), 
  .axis_rx_last(axis_rx_last),
  .axis_rx_data(axis_rx_data),
  .axis_rx_data_be(axis_rx_data_be),
  .axis_rx_ready(axis_rx_ready),
  .axis_rx_user(axis_rx_user),
  .axis_rx_start(axis_rx_start),

  .axis_rx_out_valid({axis_rx_roce_valid, axis_rx_mac_valid}),
  .axis_rx_out_last({axis_rx_roce_last, axis_rx_mac_last}),
  .axis_rx_out_data({axis_rx_roce_data, axis_rx_mac_data}),
  .axis_rx_out_data_be({axis_rx_roce_data_be, axis_rx_mac_data_be}),
  .axis_rx_out_ready({axis_rx_roce_ready, axis_rx_mac_ready}),
  .axis_rx_out_user({axis_rx_roce_user, axis_rx_mac_user}),
  .axis_rx_out_start({axis_rx_roce_start, axis_rx_mac_start})

`ifdef ETH_CHIP_DEBUG
  ,.Dbg_sel(Dbg_sel_rx_distributor)
	,.Dbg_bus(Dbg_bus_rx_distributor)
`endif
);

/* -------rx path {end}------- */


/* -------tx path {begin}------- */

desc_provider #(
  .AXIL_ADDR_WIDTH(AXIL_QUEUE_ADDR_WIDTH),

  .QUEUE_COUNT(QUEUE_COUNT),
  .DESC_TABLE_SIZE(DESC_TABLE_SIZE),
  .DEBUG_RX(1)
)
tx_desc_provider_inst
(
  .clk(clk),
  .rst_n(rst_n),

  /* to dma module, to get the desc */
  .desc_dma_req_valid(tx_desc_dma_req_valid),
  .desc_dma_req_last(tx_desc_dma_req_last),
  .desc_dma_req_data(tx_desc_dma_req_data),
  .desc_dma_req_head(tx_desc_dma_req_head),
  .desc_dma_req_ready(tx_desc_dma_req_ready),

  /* to dma module, to get the desc */
  .desc_dma_rsp_valid(tx_desc_dma_rsp_valid),
  .desc_dma_rsp_data(tx_desc_dma_rsp_data),
  .desc_dma_rsp_head(tx_desc_dma_rsp_head),
  .desc_dma_rsp_last(tx_desc_dma_rsp_last),
  .desc_dma_rsp_ready(tx_desc_dma_rsp_ready),

  /* input from tx_engine, request for a desc */
  .desc_req_qnum(tx_desc_req_qnum),
  .desc_req_valid(tx_desc_req_valid),
  .desc_req_ready(tx_desc_req_ready),

  /* to tx_engine,  return the desc data */
  .desc_rsp_status(tx_desc_rsp_status),
  .desc_rsp_qnum(tx_desc_rsp_qnum),
  .desc_rsp_qindex(tx_desc_rsp_qindex),
  .desc_rsp_length(tx_desc_rsp_length),
  .desc_rsp_dma_addr(tx_desc_rsp_dma_addr),
  .desc_rsp_desc_addr(tx_desc_rsp_desc_addr),
  .desc_rsp_csum_start(tx_desc_rsp_csum_start),
  .desc_rsp_csum_offset(tx_desc_rsp_csum_offset),
  .desc_rsp_cpl_addr(tx_desc_rsp_cpl_addr),
  .desc_rsp_msix_msg(tx_desc_rsp_msix_msg),
  .desc_rsp_msix_addr(tx_desc_rsp_msix_addr),    
  .desc_rsp_valid(tx_desc_rsp_valid),
  .desc_rsp_ready(tx_desc_rsp_ready),

  .doorbell_queue(tx_doorbell_queue),
  .doorbell_valid(tx_doorbell_valid),

  .irq_req_msix(tx_irq_req_msix),
  .irq_req_valid(tx_irq_req_valid),
  .irq_req_ready(tx_irq_req_ready),

  .irq_rsp_msg(tx_irq_rsp_msg),
  .irq_rsp_addr(tx_irq_rsp_addr),
  .irq_rsp_valid(tx_irq_rsp_valid),
  .irq_rsp_ready(tx_irq_rsp_ready),

  .cpl_finish_qnum(tx_cpl_finish_qnum),
  .cpl_finish_valid(tx_cpl_finish_valid),
  .cpl_finish_ready(tx_cpl_finish_ready),

  /*axil write signal*/
  .awaddr_queue(awaddr_tx[AXIL_QUEUE_ADDR_WIDTH-1:0]),
  .awvalid_queue(awvalid_tx),
  .awready_queue(awready_tx),
  .wdata_queue(wdata_tx),
  .wstrb_queue(wstrb_tx),
  .wvalid_queue(wvalid_tx),
  .wready_queue(wready_tx),
  .bvalid_queue(bvalid_tx),
  .bready_queue(bready_tx),
  /*axil read signal*/
  .araddr_queue(araddr_tx[AXIL_QUEUE_ADDR_WIDTH-1:0]),
  .arvalid_queue(arvalid_tx),
  .arready_queue(arready_tx),
  .rdata_queue(rdata_tx),
  .rvalid_queue(rvalid_tx),
  .rready_queue(rready_tx)

  ,.desc_fetch_req_cnt(tx_desc_fetch_req_cnt)
  ,.desc_fetch_rsp_cnt(tx_desc_fetch_rsp_cnt)
  ,.desc_fetch_error_cnt(tx_desc_fetch_error_cnt)

`ifdef ETH_CHIP_DEBUG
  ,.Dbg_sel(Dbg_sel_tx_desc_provider)
	,.Dbg_bus(Dbg_bus_tx_desc_provider)
`endif

  `ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved | reserved | idx | end | out |
     * |  255:10  |   9:5    | 4:2 |  1  |  0  |
     */
    ,.debug_desc_fetch(debug_desc_fetch_tx)
    /* ------- Debug interface {end}------- */
  `endif
);

tx_mac_engine #(
  .AXIL_ADDR_WIDTH(AXIL_QUEUE_ADDR_WIDTH),
  .DESC_TABLE_SIZE(DESC_TABLE_SIZE)
)
tx_mac_engine_inst
(
  .clk(clk),
  .rst_n(rst_n),

  .axis_tx_valid(axis_tx_mac_valid),
  .axis_tx_last(axis_tx_mac_last),
  .axis_tx_data(axis_tx_mac_data),
  .axis_tx_data_be(axis_tx_mac_data_be),
  .axis_tx_ready(axis_tx_mac_ready),
  .axis_tx_user(axis_tx_mac_user),
  .axis_tx_start(),

  .tx_doorbell_queue(tx_doorbell_queue),
  .tx_doorbell_valid(tx_doorbell_valid),

  /* input from tx_engine, request for a desc */
  .tx_desc_req_qnum(tx_desc_req_qnum),
  .tx_desc_req_valid(tx_desc_req_valid),
  .tx_desc_req_ready(tx_desc_req_ready),

  /* to tx_engine,  return the desc data */
  .tx_desc_status(tx_desc_rsp_status),
  .tx_desc_qnum(tx_desc_rsp_qnum),
  .tx_desc_qindex(tx_desc_rsp_qindex),
  .tx_desc_length(tx_desc_rsp_length),
  .tx_desc_dma_addr(tx_desc_rsp_dma_addr),
  .tx_desc_desc_addr(tx_desc_rsp_desc_addr),
  .tx_desc_csum_start(tx_desc_rsp_csum_start),
  .tx_desc_csum_offset(tx_desc_rsp_csum_offset),
  .tx_desc_cpl_addr(tx_desc_rsp_cpl_addr),
  .tx_desc_msix_msg(tx_desc_rsp_msix_msg),
  .tx_desc_msix_addr(tx_desc_rsp_msix_addr),    
  .tx_desc_valid(tx_desc_rsp_valid),
  .tx_desc_ready(tx_desc_rsp_ready),

  /* to dma module, to get the desc */
  .tx_frame_req_valid(tx_frame_req_valid),
  .tx_frame_req_last(tx_frame_req_last),
  .tx_frame_req_data(tx_frame_req_data),
  .tx_frame_req_head(tx_frame_req_head),
  .tx_frame_req_ready(tx_frame_req_ready),

  /* interface to dma */
  .tx_frame_rsp_valid(tx_frame_rsp_valid),
  .tx_frame_rsp_data(tx_frame_rsp_data),
  .tx_frame_rsp_head(tx_frame_rsp_head),
  .tx_frame_rsp_last(tx_frame_rsp_last),
  .tx_frame_rsp_ready(tx_frame_rsp_ready),

  .tx_cpl_finish_qnum(tx_cpl_finish_qnum),
  .tx_cpl_finish_valid(tx_cpl_finish_valid),
  .tx_cpl_finish_ready(tx_cpl_finish_ready),

  /* completion data dma interface */
  .tx_axis_wr_valid(tx_axis_wr_valid),
  .tx_axis_wr_data(tx_axis_wr_data),
  .tx_axis_wr_head(tx_axis_wr_head),
  .tx_axis_wr_last(tx_axis_wr_last),
  .tx_axis_wr_ready(tx_axis_wr_ready)

  ,.start_sche(start_sche)
  ,.msix_enable(msix_enable)

  ,.awaddr_queue(awaddr_tx[AXIL_QUEUE_ADDR_WIDTH-1:0])
  ,.awvalid_queue(awvalid_tx)
  ,.awready_queue(awready_tx)
  ,.wdata_queue(wdata_tx)
  ,.wvalid_queue(wvalid_tx)
  ,.wready_queue(wready_tx)

  ,.tx_mac_proc_rec_cnt(tx_mac_proc_rec_cnt)
  ,.tx_mac_proc_xmit_cnt(tx_mac_proc_xmit_cnt)
  ,.tx_mac_proc_cpl_cnt(tx_mac_proc_cpl_cnt)
  ,.tx_mac_proc_msix_cnt(tx_mac_proc_msix_cnt)

`ifdef ETH_CHIP_DEBUG
  ,.rw_data(rw_data[7*32 +: 3*32])
  ,.Dbg_sel(Dbg_sel_tx_mac_engine)
	,.Dbg_bus(Dbg_bus_tx_mac_engine)
`endif 

  `ifdef SIMULATION
  /* ------- Debug interface {begin}------- */
  /* | reserved | reserved | idx | end | out |
    * |  255:10  |   9:5    | 4:2 |  1  |  0  |
    */
  ,.debug_tx_dma(debug_tx_dma)
  ,.debug_tx_macproc(debug_tx_macproc)
  /* ------- Debug interface {end}------- */
`endif
);

/* -------tx path {end}------- */

tx_rocedesc
tx_rocedesc_inst
(
  .clk(clk),
  .rst_n(rst_n),

  /* input from roce desc, request for a desc */
  .i_tx_desc_empty(i_tx_desc_empty),
  .iv_tx_desc_data(iv_tx_desc_data),
  .o_tx_desc_rd_en(o_tx_desc_rd_en),

  /* to tx roceproc, to get the desc */
  .tx_desc_dtyp(tx_desc_dtyp),
  .tx_desc_len(tx_desc_len),
  .tx_desc_smac(tx_desc_smac),
  .tx_desc_dmac(tx_desc_dmac),
  .tx_desc_sip(tx_desc_sip),
  .tx_desc_dip(tx_desc_dip),
  .tx_desc_valid(tx_desc_valid),
  .tx_desc_ready(tx_desc_ready)

`ifdef ETH_CHIP_DEBUG
  
  ,.Dbg_sel(Dbg_sel_tx_rocedesc)
	,.Dbg_bus(Dbg_bus_tx_rocedesc)
`endif 
);

tx_roceproc 
tx_roceproc_inst
(
  .clk(clk),
  .rst_n(rst_n),

  /* from tx_rocedesc,  get the the desc*/
  .tx_desc_dtyp(tx_desc_dtyp),
  .tx_desc_len(tx_desc_len),
  .tx_desc_smac(tx_desc_smac),
  .tx_desc_dmac(tx_desc_dmac),
  .tx_desc_sip(tx_desc_sip),
  .tx_desc_dip(tx_desc_dip),
  .tx_desc_valid(tx_desc_valid),
  .tx_desc_ready(tx_desc_ready),

  .i_roce_empty(i_roce_empty),
  .iv_roce_data(iv_roce_data),
  .o_roce_rd_en(o_roce_rd_en),

  /* interface to mac */
  .axis_tx_valid(axis_tx_roce_valid), 
  .axis_tx_last(axis_tx_roce_last),
  .axis_tx_data(axis_tx_roce_data),
  .axis_tx_data_be(axis_tx_roce_data_be),
  .axis_tx_ready(axis_tx_roce_ready),
  .axis_tx_user(axis_tx_roce_user),
  .axis_tx_start()

`ifdef ETH_CHIP_DEBUG
  ,.rw_data(rw_data[10*32 +: 4*32])
	,.Dbg_sel(Dbg_sel_tx_roceproc)
	,.Dbg_bus(Dbg_bus_tx_roceproc)
`endif 
);





eth_req_arbiter #(
    .C_DATA_WIDTH(`DMA_DATA_WIDTH),
    .AXIS_TUSER_WIDTH(`XBAR_USER_WIDTH),
    .CHANNEL_NUM(2),    // number of slave signals to arbit
    .CHNL_NUM_LOG(1),
    .KEEP_WIDTH(`DMA_KEEP_WIDTH)
) 
tx_mac_roce_arbiter( 
    .rdma_clk(clk),
    .rst_n(rst_n),

    /* -------Slave AXIS Interface{begin}------- */
    .s_axis_req_tvalid ( { axis_tx_roce_valid,  axis_tx_mac_valid } ),
    .s_axis_req_tdata  ( { axis_tx_roce_data,   axis_tx_mac_data } ),
    .s_axis_req_tuser  ( { axis_tx_roce_user,   axis_tx_mac_user } ),
    .s_axis_req_tlast  ( { axis_tx_roce_last,   axis_tx_mac_last } ),
    .s_axis_req_tkeep  ( { axis_tx_roce_data_be, axis_tx_mac_data_be} ),
    .s_axis_req_tready ( { axis_tx_roce_ready,    axis_tx_mac_ready } ),
    /* -------Slave AXIS Interface{end}------- */

    /* ------- Master AXIS Interface{begin} ------- */
    .m_axis_req_tvalid (   axis_tx_valid  ),
    .m_axis_req_tdata  (   axis_tx_data), 
    .m_axis_req_tuser  (   axis_tx_user), 
    .m_axis_req_tlast  (   axis_tx_last ),    
    .m_axis_req_tkeep  (   axis_tx_data_be),
    .m_axis_req_tready (   axis_tx_ready ) 
    /* ------- Master AXIS Interface{end} ------- */

`ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved | reserved | idx | end | out |
     * |  255:10  |   9:5    | 4:2 |  1  |  0  |
     */
    ,.debug(debug_tx_roce_mac)
    /* ------- Debug interface {end}------- */
`endif
);

reg tx_start_reg;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    tx_start_reg <= `TD 0;
  end else if(axis_tx_valid && axis_tx_ready && axis_tx_last) begin
    tx_start_reg <= `TD 0;
  end else if(axis_tx_ready && axis_tx_valid) begin
    tx_start_reg <= `TD 1;
  end else begin
    tx_start_reg <= `TD tx_start_reg;
  end
end

assign axis_tx_start = !tx_start_reg && axis_tx_valid;


axi_util #(
  .AXIL_ADDR_WIDTH(`AXI_AW)
) axi_util_inst
(
  .clk(clk),
  .rst_n(rst_n),

  // Write Address Channel from Master 1
  .awvalid_m(awvalid_m),
  .awaddr_m({12'd0, awaddr_m[19:0]}),
  .awready_m(awready_m),  
  .wvalid_m(wvalid_m),
  .wdata_m(wdata_m),
  .wstrb_m(wstrb_m),
  .wready_m(wready_m),
  .bvalid_m(bvalid_m),
  .bready_m(bready_m),

  .arvalid_m(arvalid_m),
  .araddr_m({12'd0, araddr_m[19:0]}),
  .arready_m(arready_m),
  .rvalid_m(rvalid_m),
  .rdata_m(rdata_m),
  .rready_m(rready_m),

  /*axil write signal*/
  .awaddr_csr(awaddr_csr),
  .awvalid_csr(awvalid_csr),
  .awready_csr(awready_csr),
  .wdata_csr(wdata_csr),
  .wstrb_csr(wstrb_csr),
  .wvalid_csr(wvalid_csr),
  .wready_csr(wready_csr),
  .bvalid_csr(bvalid_csr),
  .bready_csr(bready_csr),
  /*axil read signal*/
  .araddr_csr(araddr_csr),
  .arvalid_csr(arvalid_csr),
  .arready_csr(arready_csr),
  .rdata_csr(rdata_csr),
  .rvalid_csr(rvalid_csr),
  .rready_csr(rready_csr),


    /*axil write signal*/
  .awaddr_rx(awaddr_rx),
  .awvalid_rx(awvalid_rx),
  .awready_rx(awready_rx),
  .wdata_rx(wdata_rx),
  .wstrb_rx(wstrb_rx),
  .wvalid_rx(wvalid_rx),
  .wready_rx(wready_rx),
  .bvalid_rx(bvalid_rx),
  .bready_rx(bready_rx),
  /*axil read signal*/
  .araddr_rx(araddr_rx),
  .arvalid_rx(arvalid_rx),
  .arready_rx(arready_rx),
  .rdata_rx(rdata_rx),
  .rvalid_rx(rvalid_rx),
  .rready_rx(rready_rx),

    /*axil write signal*/
  .awaddr_tx(awaddr_tx),
  .awvalid_tx(awvalid_tx),
  .awready_tx(awready_tx),
  .wdata_tx(wdata_tx),
  .wstrb_tx(wstrb_tx),
  .wvalid_tx(wvalid_tx),
  .wready_tx(wready_tx),
  .bvalid_tx(bvalid_tx),
  .bready_tx(bready_tx),
  /*axil read signal*/
  .araddr_tx(araddr_tx),
  .arvalid_tx(arvalid_tx),
  .arready_tx(arready_tx),
  .rdata_tx(rdata_tx),
  .rvalid_tx(rvalid_tx),
  .rready_tx(rready_tx),

    /*axil write signal*/
  .awaddr_msix(awaddr_msix),
  .awvalid_msix(awvalid_msix),
  .awready_msix(awready_msix),
  .wdata_msix(wdata_msix),
  .wstrb_msix(wstrb_msix),
  .wvalid_msix(wvalid_msix),
  .wready_msix(wready_msix),
  .bvalid_msix(bvalid_msix),
  .bready_msix(bready_msix),
  /*axil read signal*/
  .araddr_msix(araddr_msix),
  .arvalid_msix(arvalid_msix),
  .arready_msix(arready_msix),
  .rdata_msix(rdata_msix),
  .rvalid_msix(rvalid_msix),
  .rready_msix(rready_msix)
);

//ila_mac2engine ila_rx_distributor_inst(
//    .clk(clk),
//    .probe0(axis_rx_data),
//    .probe1(axis_rx_valid),
//    .probe2(axis_rx_data_be),
//    .probe3(axis_rx_last),
//    .probe4(axis_rx_ready),

//    .probe5(axis_rx_mac_data),
//    .probe6(axis_rx_mac_valid),
//    .probe7(axis_rx_mac_data_be),
//    .probe8(axis_rx_mac_last),
//    .probe9(axis_rx_mac_ready)
//);

/* -------tx path {end}------- */
endmodule
