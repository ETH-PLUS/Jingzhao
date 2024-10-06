`timescale 1ns / 100ps

`include "ceu_def_h.vh"
`include "msg_def_ctxmgt_h.vh"
`include "msg_def_v2p_h.vh"
`include "route_params_def.vh"
`include "chip_include_rdma.vh"
`include "cfg_node_def.vh"

module ProtocolEngine_Top
#(
	//parameter 				RDMA_RO_REG_NUM = 32'd129 + 32'd33 + `CXTMGT_DBG_RW_NUM + `VTP_DBG_RW_NUM,
	//parameter 				RDMA_RW_REG_NUM = 32'd129 + 32'd33 + `CXTMGT_DBG_RO_NUM + `VTP_DBG_RO_NUM,
	parameter 				REDUNDANT_INSTANCE = 1024,


	parameter				RDMA_RO_REG_NUM = 32'd129 + 32'd33,
	parameter				RDMA_RW_REG_NUM = 32'd129 + 32'd33,
	parameter				ETH_RO_REG_NUM	= 32'd70,
	parameter				ETH_RW_REG_NUM	= 32'd70,
	parameter				ROUTE_RO_REG_NUM = 32'd13,
	parameter				ROUTE_RW_REG_NUM = 32'd13,

    parameter 			ENGINE_NIC_DATA_WIDTH 					= 256,
    parameter 			ENGINE_NIC_KEEP_WIDTH 					= 32,
    parameter 			ENGINE_LINK_LAYER_USER_WIDTH 			= 7,

    /*RDMA_Top parameters*/
    parameter          C_DATA_WIDTH                        = 256,         // RX/TX interface data width
    parameter          KEEP_WIDTH                          = C_DATA_WIDTH / 32,

    // defined for pcie interface
    parameter          AXIL_DATA_WIDTH                = 32      , 
	parameter 			AXIL_ADDR_WIDTH					= 24,
    parameter          ETHER_BASE                     = 24'h0    ,
    parameter          ETHER_LEN                      = 24'h1000 ,
    parameter          DB_BASE                        = 12'h0    ,
    parameter          HCR_BASE                       = 20'h80000,

    parameter          AXIL_STRB_WIDTH                = (AXIL_DATA_WIDTH/8),

    parameter 			NIC_DATA_WIDTH 					= 256,
    parameter 			NIC_KEEP_WIDTH 					= 5,
    parameter 			LINK_LAYER_USER_WIDTH 			= 7,

    //parameter 			RW_REG_NUM 						= RDMA_RW_REG_NUM + ETH_RW_REG_NUM + ROUTE_RW_REG_NUM,
    //parameter 			RO_REG_NUM 						= RDMA_RO_REG_NUM + ETH_RO_REG_NUM + ROUTE_RO_REG_NUM,
    parameter 			RW_REG_NUM 						= RDMA_RW_REG_NUM + ROUTE_RW_REG_NUM,
    parameter 			RO_REG_NUM 						= RDMA_RO_REG_NUM + ROUTE_RO_REG_NUM,

    /*eth_engine_top parameters*/
    /* axil parameter */
    parameter           AXIL_CSR_ADDR_WIDTH   = 12,
    parameter           AXIL_QUEUE_ADDR_WIDTH = 12,
    parameter           AXIL_MSIX_ADDR_WIDTH  = 12,

    /* some feature of the eth nic */
    parameter           RX_RSS_ENABLE = 1, 
    parameter           RX_HASH_ENABLE = 1,
    parameter           TX_CHECKSUM_ENABLE = 1,
    parameter           RX_CHECKSUM_ENABLE = 1,
    parameter           RX_VLAN_ENABLE = 1,
    parameter           QUEUE_COUNT  = 32,

    parameter           DESC_TABLE_SIZE = 32,


    // defined for pcie interface
    parameter           DMA_HEAD_WIDTH                 = 128      ,
    parameter           UPPER_HEAD_WIDTH               = 64 , 
    parameter           DOWN_HEAD_WIDTH                = 64 ,
	parameter           PORT_NUM_LOG_2 = 32'd4,
	parameter           PORT_INDEX = 32'd0,
	parameter           PORT_NUM = 32'd16,
	parameter           QUEUE_DEPTH_LOG_2 = 10, 	//Maximum depth of one output queue is (1 << QUEUE_DEPTH)

//Ring Data Parameter
    parameter           NODE_NUM = 18,
    parameter           PKT_DATA_WIDTH = 128,
    parameter           PKT_ADDR_WIDTH = 2,
    parameter           ID_ADDR_WIDTH = log2b(NODE_NUM),

////Route Cfg Parameter
//	parameter           ROUTE_RO_REG_NUM = 4,
//	parameter           ROUTE_RW_REG_NUM = 4,
//
////NIC Cfg Parameter
//    parameter           NIC_RO_REG_NUM = 8,
//    parameter           NIC_RW_REG_NUM = 8,
//
////Link Cfg Parameter
//    parameter           LINK_RO_REG_NUM = 10,
//    parameter           LINK_RW_REG_NUM = 13,

    //parameter 			PROTOCOL_ENGINE_RW_REG_NUM 						= RDMA_RW_REG_NUM + ETH_RW_REG_NUM + ROUTE_RW_REG_NUM,
    //parameter 			PROTOCOL_ENGINE_RO_REG_NUM 						= RDMA_RO_REG_NUM + ETH_RO_REG_NUM + ROUTE_RO_REG_NUM,
    parameter 			PROTOCOL_ENGINE_RW_REG_NUM 						= RDMA_RW_REG_NUM + ROUTE_RW_REG_NUM,
    parameter 			PROTOCOL_ENGINE_RO_REG_NUM 						= RDMA_RO_REG_NUM + ROUTE_RO_REG_NUM,

	parameter 			RDMA_DBG_RANGE_START = 32'h00001000,
	parameter 			RDMA_DBG_RANGE_END = 32'h00001FFF,

	parameter 			ETH_DBG_RANGE_START = 32'h0002000,
	parameter 			ETH_DBG_RANGE_END = 32'h00002FFF,

	parameter 			ROUTE_DBG_RANGE_START = 32'h00003000,
	parameter 			ROUTE_DBG_RANGE_END = 32'h00003FFF,

//Cfg Node Parameter
    parameter           CFG_NODE_REG_BASE_ADDR  = `REG_BASE_ADDR_PET,//
	parameter           CFG_NODE_RW_REG_NUM = PROTOCOL_ENGINE_RW_REG_NUM,//read-writer register number,register data witdh is 32bit,
	parameter           CFG_NODE_RO_BASE_ADDR  = `RO_BASE_ADDR_PET,//configuration read only register base address  //
	parameter           CFG_NODE_RO_REG_NUM = PROTOCOL_ENGINE_RO_REG_NUM, //read-only register number,register data witdh is 32bit, SUM max is 14'h3fff-3
	parameter           CFG_NODE_BUS_BASE_ADDR  = `BUS_BASE_ADDR_PET, ////configuration bus base address	 //
	parameter           CFG_NODE_BUS_ADDR_WIDTH = `BUS_ADDR_WIDTH_PET,

//Phy cfg parameter
    parameter           APB_SEL = 1'b0
)
(
    input   wire                    clk,
    input   wire                    rst_n,

    input                           mgmt_clk,
    input                           mgmt_rst_n,

	input 	wire						ist_mbist_rstn,
	output 	wire 						ist_mbist_done,
	output 	wire						ist_mbist_pass,

	output 	wire [REDUNDANT_INSTANCE - 1 : 0]						redundant_out,

/*-----------------------------------------------RDMA_Top interface-------------------------------------------*/
    /* -------pio interface{begin}------- */
    input   wire [63:0]                 hcr_in_param      ,
    input   wire [31:0]                 hcr_in_modifier   ,
    input   wire [63:0]                 hcr_out_dma_addr  ,
    output  wire [63:0]                 hcr_out_param     ,
    input   wire [31:0]                 hcr_token         ,
    output  wire [ 7:0]                 hcr_status        ,
    input   wire                        hcr_go            ,
    output  wire                        hcr_clear         ,
    input   wire                        hcr_event         ,
    input   wire [ 7:0]                 hcr_op_modifier   ,
    input   wire [11:0]                 hcr_op            ,

    input  wire [63:0]                  uar_db_data_diff ,
    output wire                         uar_db_ready_diff,
    input  wire                         uar_db_valid_diff,
    /* -------pio interface{end}------- */

    /* -------dma interface{begin}------- */
    /* dma_*_head(interact with RDMA modules), valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    // CEU Relevant
    // CEU Read Req
    output  wire                           dma_ceu_rd_req_valid_diff,
    output  wire                           dma_ceu_rd_req_last_diff ,
    output  wire [(C_DATA_WIDTH-1)  :0]    dma_ceu_rd_req_data_diff ,
    output  wire [(DMA_HEAD_WIDTH-1):0]    dma_ceu_rd_req_head_diff ,
    input   wire                           dma_ceu_rd_req_ready_diff,

    // CEU DMA Read Resp
    input   wire                           dma_ceu_rd_rsp_valid_diff,
    input   wire                           dma_ceu_rd_rsp_last_diff ,
    input   wire [(C_DATA_WIDTH-1)  :0]    dma_ceu_rd_rsp_data_diff ,
    input   wire [(DMA_HEAD_WIDTH-1):0]    dma_ceu_rd_rsp_head_diff ,
    output  wire                           dma_ceu_rd_rsp_ready_diff,

    // CEU DMA Write Req
    output  wire                           dma_ceu_wr_req_valid_diff,
    output  wire                           dma_ceu_wr_req_last_diff ,
    output  wire [(C_DATA_WIDTH-1)  :0]    dma_ceu_wr_req_data_diff ,
    output  wire [(DMA_HEAD_WIDTH-1):0]    dma_ceu_wr_req_head_diff ,
    input   wire                           dma_ceu_wr_req_ready_diff,
    // End CEU Relevant


    // CxtMgt Relevant
    // Context Management DMA Read Request
    output  wire                           dma_cm_rd_req_valid_diff,
    output  wire                           dma_cm_rd_req_last_diff ,
    output  wire [(C_DATA_WIDTH-1)  :0]    dma_cm_rd_req_data_diff ,
    output  wire [(DMA_HEAD_WIDTH-1):0]    dma_cm_rd_req_head_diff ,
    input   wire                           dma_cm_rd_req_ready_diff,

    // Context Management DMA Read Response
    input   wire                           dma_cm_rd_rsp_valid_diff,
    input   wire                           dma_cm_rd_rsp_last_diff ,
    input   wire [(C_DATA_WIDTH-1)  :0]    dma_cm_rd_rsp_data_diff ,
    input   wire [(DMA_HEAD_WIDTH-1):0]    dma_cm_rd_rsp_head_diff ,
    output  wire                           dma_cm_rd_rsp_ready_diff,

    // Context Management DMA Write Request
    output  wire                           dma_cm_wr_req_valid_diff,
    output  wire                           dma_cm_wr_req_last_diff ,
    output  wire [(C_DATA_WIDTH-1)  :0]    dma_cm_wr_req_data_diff ,
    output  wire [(DMA_HEAD_WIDTH-1):0]    dma_cm_wr_req_head_diff ,
    input   wire                           dma_cm_wr_req_ready_diff,
    // End CxtMgt Relevant


    // Virt2Phys Relevant
    // Virtual to Physical DMA Context Read Request(MPT)
    output  wire                           dma_cv2p_mpt_rd_req_valid_diff,
    output  wire                           dma_cv2p_mpt_rd_req_last_diff,
    output  wire [(C_DATA_WIDTH-1)  :0]    dma_cv2p_mpt_rd_req_data_diff,
    output  wire [(DMA_HEAD_WIDTH-1):0]    dma_cv2p_mpt_rd_req_head_diff,
    input   wire                           dma_cv2p_mpt_rd_req_ready_diff,

    // Virtual to Physical DMA Context Read Response
    input   wire                           dma_cv2p_mpt_rd_rsp_valid_diff,
    input   wire                           dma_cv2p_mpt_rd_rsp_last_diff,
    input   wire [(C_DATA_WIDTH-1)  :0]    dma_cv2p_mpt_rd_rsp_data_diff,
    input   wire [(DMA_HEAD_WIDTH-1):0]    dma_cv2p_mpt_rd_rsp_head_diff,
    output  wire                           dma_cv2p_mpt_rd_rsp_ready_diff,

    // Virtual to Physical DMA Context Write Request
    output  wire                           dma_cv2p_mpt_wr_req_valid_diff,
    output  wire                           dma_cv2p_mpt_wr_req_last_diff,
    output  wire [(C_DATA_WIDTH-1)  :0]    dma_cv2p_mpt_wr_req_data_diff,
    output  wire [(DMA_HEAD_WIDTH-1):0]    dma_cv2p_mpt_wr_req_head_diff,
    input   wire                           dma_cv2p_mpt_wr_req_ready_diff,

    output  wire                           dma_cv2p_mtt_rd_req_valid_diff,
    output  wire                           dma_cv2p_mtt_rd_req_last_diff,
    output  wire [(C_DATA_WIDTH-1)  :0]    dma_cv2p_mtt_rd_req_data_diff,
    output  wire [(DMA_HEAD_WIDTH-1):0]    dma_cv2p_mtt_rd_req_head_diff,
    input   wire                           dma_cv2p_mtt_rd_req_ready_diff,

    // Virtual to Physical DMA Context Read Response
    input   wire                           dma_cv2p_mtt_rd_rsp_valid_diff,
    input   wire                           dma_cv2p_mtt_rd_rsp_last_diff,
    input   wire [(C_DATA_WIDTH-1)  :0]    dma_cv2p_mtt_rd_rsp_data_diff,
    input   wire [(DMA_HEAD_WIDTH-1):0]    dma_cv2p_mtt_rd_rsp_head_diff,
    output  wire                           dma_cv2p_mtt_rd_rsp_ready_diff,

    // Virtual to Physical DMA Context Write Request
    output  wire                           dma_cv2p_mtt_wr_req_valid_diff,
    output  wire                           dma_cv2p_mtt_wr_req_last_diff,
    output  wire [(C_DATA_WIDTH-1)  :0]    dma_cv2p_mtt_wr_req_data_diff,
    output  wire [(DMA_HEAD_WIDTH-1):0]    dma_cv2p_mtt_wr_req_head_diff,
    input   wire                           dma_cv2p_mtt_wr_req_ready_diff,

    // Virtual to Physical DMA Data Read Request
    output  wire                           dma_dv2p_dt_rd_req_valid_diff,
    output  wire                           dma_dv2p_dt_rd_req_last_diff,
    output  wire [(C_DATA_WIDTH-1)  :0]    dma_dv2p_dt_rd_req_data_diff,
    output  wire [(DMA_HEAD_WIDTH-1):0]    dma_dv2p_dt_rd_req_head_diff,
    input   wire                           dma_dv2p_dt_rd_req_ready_diff,

    // Virtual to Physical DMA Data Read Response
    input   wire                           dma_dv2p_dt_rd_rsp_valid_diff,
    input   wire                           dma_dv2p_dt_rd_rsp_last_diff,
    input   wire [(C_DATA_WIDTH-1)  :0]    dma_dv2p_dt_rd_rsp_data_diff,
    input   wire [(DMA_HEAD_WIDTH-1):0]    dma_dv2p_dt_rd_rsp_head_diff,
    output  wire                           dma_dv2p_dt_rd_rsp_ready_diff,

    // Virtual to Physical DMA Data Write Request
    output  wire                           dma_dv2p_dt_wr_req_valid_diff,
    output  wire                           dma_dv2p_dt_wr_req_last_diff,
    output  wire [(C_DATA_WIDTH-1)  :0]    dma_dv2p_dt_wr_req_data_diff,
    output  wire [(DMA_HEAD_WIDTH-1):0]    dma_dv2p_dt_wr_req_head_diff,
    input   wire                           dma_dv2p_dt_wr_req_ready_diff,

    // ADD 1 DMA read and response channel for v2p read RQ WQE
        // Virtual to Physical DMA RQ WQE Read Request
    output  wire                           dma_dv2p_wqe_rd_req_valid_diff,
    output  wire                           dma_dv2p_wqe_rd_req_last_diff,
    output  wire [(C_DATA_WIDTH-1)  :0]    dma_dv2p_wqe_rd_req_data_diff,
    output  wire [(DMA_HEAD_WIDTH-1):0]    dma_dv2p_wqe_rd_req_head_diff,
    input   wire                           dma_dv2p_wqe_rd_req_ready_diff,

        // Virtual to Physical DMA RQ WQE  Read Response
    input   wire                           dma_dv2p_wqe_rd_rsp_valid_diff,
    input   wire                           dma_dv2p_wqe_rd_rsp_last_diff,
    input   wire [(C_DATA_WIDTH-1)  :0]    dma_dv2p_wqe_rd_rsp_data_diff,
    input   wire [(DMA_HEAD_WIDTH-1):0]    dma_dv2p_wqe_rd_rsp_head_diff,
    output  wire                           dma_dv2p_wqe_rd_rsp_ready_diff,

	output 	wire 							o_rdma_init_finish,

/*-------------------------------------------eth_engine_top interface--------------------------------------------*/

    /* to dma module, to get the desc */
  output wire                               rx_desc_dma_req_valid_diff,
  output wire                               rx_desc_dma_req_last_diff,
  output wire [C_DATA_WIDTH-1:0]          rx_desc_dma_req_data_diff,
  output wire [DMA_HEAD_WIDTH-1:0]          rx_desc_dma_req_head_diff,
  input  wire                               rx_desc_dma_req_ready_diff,

  input   wire                               rx_desc_dma_rsp_valid_diff,
  input   wire                               rx_desc_dma_rsp_last_diff,
  input   wire [C_DATA_WIDTH-1:0]          rx_desc_dma_rsp_data_diff,
  input   wire [DMA_HEAD_WIDTH-1:0]          rx_desc_dma_rsp_head_diff,
  output  wire                               rx_desc_dma_rsp_ready_diff,
  /* -------to dma module, to get the desc{end}------- */

  /* -------to dma module , to write the frame{begin}------- */
  output wire                               rx_axis_wr_valid_diff,
  output wire                               rx_axis_wr_last_diff,
  output wire [C_DATA_WIDTH-1:0]          rx_axis_wr_data_diff,
  output wire [DMA_HEAD_WIDTH-1:0]          rx_axis_wr_head_diff,
  input  wire                               rx_axis_wr_ready_diff,
  /* -------to dma module , to write the frame{end}------- */

  /* to dma module, to get the desc */
  output wire                               tx_desc_dma_req_valid_diff,
  output wire                               tx_desc_dma_req_last_diff,
  output wire [C_DATA_WIDTH-1:0]          tx_desc_dma_req_data_diff,
  output wire [DMA_HEAD_WIDTH-1:0]          tx_desc_dma_req_head_diff,
  input  wire                               tx_desc_dma_req_ready_diff,

  /* to dma module, to get the desc */
  input   wire                               tx_desc_dma_rsp_valid_diff,
  input   wire [C_DATA_WIDTH-1:0]          tx_desc_dma_rsp_data_diff,
  input   wire [DMA_HEAD_WIDTH-1:0]          tx_desc_dma_rsp_head_diff,
  input   wire                               tx_desc_dma_rsp_last_diff,
  output  wire                               tx_desc_dma_rsp_ready_diff,

    /* to dma module, to get the frame */
  output wire                               tx_frame_req_valid_diff,
  output wire                               tx_frame_req_last_diff,
  output wire [C_DATA_WIDTH-1:0]          tx_frame_req_data_diff,
  output wire [DMA_HEAD_WIDTH-1:0]          tx_frame_req_head_diff,
  input  wire                               tx_frame_req_ready_diff,

  /* interface to dma */
  input   wire                               tx_frame_rsp_valid_diff,
  input   wire [C_DATA_WIDTH-1:0]          tx_frame_rsp_data_diff,
  input   wire [DMA_HEAD_WIDTH-1:0]          tx_frame_rsp_head_diff,
  input   wire                               tx_frame_rsp_last_diff,
  output  wire                               tx_frame_rsp_ready_diff,

  
  /* completion data dma interface */
  output wire                               tx_axis_wr_valid_diff,
  output wire [C_DATA_WIDTH-1:0]          tx_axis_wr_data_diff,
  output wire [DMA_HEAD_WIDTH-1:0]          tx_axis_wr_head_diff,
  output wire                               tx_axis_wr_last_diff,
  input  wire                               tx_axis_wr_ready_diff,

  // Write Address Channel from Master 1
  input wire                       awvalid_m,
  input wire  [AXIL_ADDR_WIDTH-1:0]        awaddr_m,
  output  wire                     awready_m,
  
// Write Data Channel from Master 1
  input wire                       wvalid_m,
  input wire  [AXIL_DATA_WIDTH-1:0]        wdata_m,
  input wire  [AXIL_STRB_WIDTH-1:0]        wstrb_m,
  output  wire                      wready_m,
// Write Response Channel from Master 1
  output  wire                      bvalid_m,
  input wire                       bready_m,
// Read Address Channel from Master 1
  input wire                       arvalid_m,
  input wire  [AXIL_ADDR_WIDTH-1:0]        araddr_m,
  output  wire                      arready_m,

// Read Data Channel from Master 1
  output  wire                      rvalid_m,
  output  wire [AXIL_DATA_WIDTH-1:0]        rdata_m,
  input wire                       rready_m,
/*--------------------------------------------HostRoute_Top interface--------------------------------------------*/

    /* --------ARM CQ interface{begin}-------- */
    output  wire          cq_ren , // o, 1
    output  wire [31:0]   cq_num , // o, 32
    input wire          cq_dout, // i, 1
    /* --------ARM CQ interface{end}-------- */

    /* --------ARM EQ interface{begin}-------- */
    output  wire          eq_ren , // o, 1
    output  wire [31:0]   eq_num , // o, 32
    input wire          eq_dout, // i, 1
    /* --------ARM EQ interface{end}-------- */

    /* --------Interrupt Vector entry request & response{begin}-------- */
    output  wire          pio_eq_int_req_valid, // o, 1
    output  wire [63:0]   pio_eq_int_req_num  , // o, 64
    input wire          pio_eq_int_req_ready, // i, 1

    input wire          pio_eq_int_rsp_valid, // i, 1
    input wire [127:0]  pio_eq_int_rsp_data , // i, 128
    output  wire          pio_eq_int_rsp_ready, // o, 1
    /* -------Interrupt Vector entry request & response{end}-------- */

    /* --------p2p forward up channel{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved | dst_dev | src_dev | Reserved | Byte length |
     * |  63:35   |  37:35  |  34:32  |  31:16   |    15:0     |
     */
    output  wire [1                - 1 : 0] 	p2p_tx_valid_diff,     
    output  wire [1                - 1 : 0] 	p2p_tx_last_diff,     
    output  wire [C_DATA_WIDTH     - 1 : 0] 	p2p_tx_data_diff, 
    output  wire [UPPER_HEAD_WIDTH - 1 : 0] 	p2p_tx_head_diff, 
    input 	wire [1                - 1 : 0] 	p2p_tx_ready_diff, 
    /* --------p2p forward up channel{end}-------- */

    /* --------p2p forward down channel{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved | dst_dev | src_dev | Reserved | Byte length |
     * |  63:35   |  37:35  |  34:32  |  31:16   |    15:0     |
     */
    input wire [1                - 1 : 0] 		p2p_rx_valid_diff,     
    input wire [1                - 1 : 0] 		p2p_rx_last_diff,     
    input wire [C_DATA_WIDTH     - 1 : 0] 		p2p_rx_data_diff, 
    input wire [DOWN_HEAD_WIDTH  - 1 : 0] 		p2p_rx_head_diff, 
    output wire [1                - 1 : 0] 		p2p_rx_ready_diff, 
    /* --------p2p forward down channel{end}-------- */

    /*-------------------------------Interface with Cfg_Subsystem(Begin)----------------------------------*/
    input  wire     [66:0]                                      cfg_pkt_in,
    input  wire                                                	cfg_pkt_in_vld,
    output wire                                                 cfg_pkt_in_rdy,
//
//	//Phy cfg node
//    output wire                                                 psel,
//    output wire                                                 penable,
//    output wire                                                 pwrite,
//    output wire     [15:0]                                      paddr,
//    output wire     [31:0]                                      pwdata,
//    input  wire                                                 pready,
//    input  wire                                                 pslverr,
//    input  wire     [31:0]                                      prdata,
//
//    //output wire     [7:0]                                       dbg_bus,
//
    output wire     [66:0]                                      cfg_pkt_out,
    output wire                                                 cfg_pkt_out_vld,
    input  wire                                                 cfg_pkt_out_rdy,
//
//	//NIC and Link cfg signals 
//    input       wire    [NIC_RW_REG_NUM * 32 - 1 : 0]           iv_nic_init_rw_data,
//	output 	 	wire 	[NIC_RW_REG_NUM * 32 - 1 : 0]			ov_nic_rw_data,
//	input 		wire 	[NIC_RO_REG_NUM * 32 - 1 : 0]			iv_nic_ro_data,
//	output 		wire 	[31:0]								    ov_nic_dbg_sel,
//	input 		wire 	[31:0]								    iv_nic_dbg_bus,
//
//    input       wire    [LINK_RW_REG_NUM * 32 - 1 : 0]          iv_link_init_rw_data,
//	output 	 	wire 	[LINK_RW_REG_NUM * 32 - 1 : 0]			ov_link_rw_data,
//	input 		wire 	[LINK_RO_REG_NUM * 32 - 1 : 0]			iv_link_ro_data,
//    output 		wire 	[31:0]								    ov_link_dbg_sel,
//	input 		wire 	[31:0]								    iv_link_dbg_bus,
/*-------------------------------Interface with Cfg_Subsystem(End)----------------------------------*/

/*-------------------------------Interface with Link(Begin)----------------------------------*/
    //HPC Traffic in
    input 	wire												i_link_hpc_rx_pkt_valid_diff,
    input 	wire 												i_link_hpc_rx_pkt_start_diff,
    input 	wire 												i_link_hpc_rx_pkt_end_diff,
    input 	wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			iv_link_hpc_rx_pkt_user_diff,
    input 	wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			iv_link_hpc_rx_pkt_keep_diff,
    input	wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			iv_link_hpc_rx_pkt_data_diff,	
    output 	wire 												o_link_hpc_rx_pkt_ready_diff,

    //ETH Traffic in、			
    input 	wire												i_link_eth_rx_pkt_valid_diff,
    input 	wire 												i_link_eth_rx_pkt_start_diff,
    input 	wire 												i_link_eth_rx_pkt_end_diff,
    input 	wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			iv_link_eth_rx_pkt_user_diff,
    input 	wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			iv_link_eth_rx_pkt_keep_diff,
    input	wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			iv_link_eth_rx_pkt_data_diff,
    output 	wire 												o_link_eth_rx_pkt_ready_diff,

    //HPC Traffic out
    output 	wire												o_link_hpc_tx_pkt_valid_diff,
    output 	wire 												o_link_hpc_tx_pkt_start_diff,
    output 	wire 												o_link_hpc_tx_pkt_end_diff,
    output 	wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			ov_link_hpc_tx_pkt_user_diff,
    output 	wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			ov_link_hpc_tx_pkt_keep_diff,
    output	wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			ov_link_hpc_tx_pkt_data_diff,	
    input 	wire 												i_link_hpc_tx_pkt_ready_diff,

    //ETH Traffic out、			
    output 	wire												o_link_eth_tx_pkt_valid_diff,
    output 	wire 												o_link_eth_tx_pkt_start_diff,
    output 	wire 												o_link_eth_tx_pkt_end_diff,
    output 	wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			ov_link_eth_tx_pkt_user_diff,
    output 	wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			ov_link_eth_tx_pkt_keep_diff,
    output	wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			ov_link_eth_tx_pkt_data_diff,
    input 	wire 												i_link_eth_tx_pkt_ready_diff
/*-------------------------------Interface with Link(End)----------------------------------*/
);

assign ist_mbist_done = 1'b1;
assign ist_mbist_pass = 1'b1;

function integer log2b;
    input integer val;
    begin: func_log2b
        integer i;
        log2b = 1;
        for (i = 0; i < 32; i = i + 1) begin
            if (|(val >> i)) begin
                log2b = i + 1;
            end
        end
end
endfunction

wire [63:0]                  uar_db_data ;
wire                         uar_db_ready;
wire                         uar_db_valid;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(64),
    .TDATA_WIDTH(64)
)
stream_reg_for_protocol_engine_1(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(8'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(uar_db_valid_diff), 
    .axis_tlast(uar_db_valid_diff), 
    .axis_tuser(64'd0), 
    .axis_tdata(uar_db_data_diff), 
    .axis_tready(uar_db_ready_diff), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(uar_db_valid),  
    .in_reg_tlast(), 
    .in_reg_tuser(),
    .in_reg_tdata(uar_db_data),
    .in_reg_tready(uar_db_ready),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);


wire                           dma_ceu_rd_req_valid;
wire                           dma_ceu_rd_req_last ;
wire [(C_DATA_WIDTH-1)  :0]    dma_ceu_rd_req_data ;
wire [(DMA_HEAD_WIDTH-1):0]    dma_ceu_rd_req_head ;
wire                           dma_ceu_rd_req_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_2(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(dma_ceu_rd_req_valid), 
    .axis_tlast(dma_ceu_rd_req_last), 
    .axis_tuser(dma_ceu_rd_req_head), 
    .axis_tdata(dma_ceu_rd_req_data), 
    .axis_tready(dma_ceu_rd_req_ready), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(dma_ceu_rd_req_valid_diff),  
    .in_reg_tlast(dma_ceu_rd_req_last_diff), 
    .in_reg_tuser(dma_ceu_rd_req_head_diff),
    .in_reg_tdata(dma_ceu_rd_req_data_diff),
    .in_reg_tready(dma_ceu_rd_req_ready_diff),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);


wire                           dma_ceu_rd_rsp_valid;
wire                           dma_ceu_rd_rsp_last ;
wire [(C_DATA_WIDTH-1)  :0]    dma_ceu_rd_rsp_data ;
wire [(DMA_HEAD_WIDTH-1):0]    dma_ceu_rd_rsp_head ;
wire                           dma_ceu_rd_rsp_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_3(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(dma_ceu_rd_rsp_valid_diff), 
    .axis_tlast(dma_ceu_rd_rsp_last_diff), 
    .axis_tuser(dma_ceu_rd_rsp_head_diff), 
    .axis_tdata(dma_ceu_rd_rsp_data_diff), 
    .axis_tready(dma_ceu_rd_rsp_ready_diff), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(dma_ceu_rd_rsp_valid),  
    .in_reg_tlast(dma_ceu_rd_rsp_last), 
    .in_reg_tuser(dma_ceu_rd_rsp_head),
    .in_reg_tdata(dma_ceu_rd_rsp_data),
    .in_reg_tready(dma_ceu_rd_rsp_ready),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);

wire                           dma_ceu_wr_req_valid;
wire                           dma_ceu_wr_req_last ;
wire [(C_DATA_WIDTH-1)  :0]    dma_ceu_wr_req_data ;
wire [(DMA_HEAD_WIDTH-1):0]    dma_ceu_wr_req_head ;
wire                           dma_ceu_wr_req_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_4(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(dma_ceu_wr_req_valid), 
    .axis_tlast(dma_ceu_wr_req_last), 
    .axis_tuser(dma_ceu_wr_req_head), 
    .axis_tdata(dma_ceu_wr_req_data), 
    .axis_tready(dma_ceu_wr_req_ready), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(dma_ceu_wr_req_valid_diff),  
    .in_reg_tlast(dma_ceu_wr_req_last_diff), 
    .in_reg_tuser(dma_ceu_wr_req_head_diff),
    .in_reg_tdata(dma_ceu_wr_req_data_diff),
    .in_reg_tready(dma_ceu_wr_req_ready_diff),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);


wire                           dma_cm_rd_req_valid;
wire                           dma_cm_rd_req_last ;
wire [(C_DATA_WIDTH-1)  :0]    dma_cm_rd_req_data ;
wire [(DMA_HEAD_WIDTH-1):0]    dma_cm_rd_req_head ;
wire                           dma_cm_rd_req_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_5(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(dma_cm_rd_req_valid), 
    .axis_tlast(dma_cm_rd_req_last), 
    .axis_tuser(dma_cm_rd_req_head), 
    .axis_tdata(dma_cm_rd_req_data), 
    .axis_tready(dma_cm_rd_req_ready), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(dma_cm_rd_req_valid_diff),  
    .in_reg_tlast(dma_cm_rd_req_last_diff), 
    .in_reg_tuser(dma_cm_rd_req_head_diff),
    .in_reg_tdata(dma_cm_rd_req_data_diff),
    .in_reg_tready(dma_cm_rd_req_ready_diff),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);


wire                           dma_cm_rd_rsp_valid;
wire                           dma_cm_rd_rsp_last ;
wire [(C_DATA_WIDTH-1)  :0]    dma_cm_rd_rsp_data ;
wire [(DMA_HEAD_WIDTH-1):0]    dma_cm_rd_rsp_head ;
wire                           dma_cm_rd_rsp_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_6(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(dma_cm_rd_rsp_valid_diff), 
    .axis_tlast(dma_cm_rd_rsp_last_diff), 
    .axis_tuser(dma_cm_rd_rsp_head_diff), 
    .axis_tdata(dma_cm_rd_rsp_data_diff), 
    .axis_tready(dma_cm_rd_rsp_ready_diff), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(dma_cm_rd_rsp_valid),  
    .in_reg_tlast(dma_cm_rd_rsp_last), 
    .in_reg_tuser(dma_cm_rd_rsp_head),
    .in_reg_tdata(dma_cm_rd_rsp_data),
    .in_reg_tready(dma_cm_rd_rsp_ready),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);


wire                           dma_cm_wr_req_valid;
wire                           dma_cm_wr_req_last ;
wire [(C_DATA_WIDTH-1)  :0]    dma_cm_wr_req_data ;
wire [(DMA_HEAD_WIDTH-1):0]    dma_cm_wr_req_head ;
wire                           dma_cm_wr_req_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_7(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(dma_cm_wr_req_valid), 
    .axis_tlast(dma_cm_wr_req_last), 
    .axis_tuser(dma_cm_wr_req_head), 
    .axis_tdata(dma_cm_wr_req_data), 
    .axis_tready(dma_cm_wr_req_ready), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(dma_cm_wr_req_valid_diff),  
    .in_reg_tlast(dma_cm_wr_req_last_diff), 
    .in_reg_tuser(dma_cm_wr_req_head_diff),
    .in_reg_tdata(dma_cm_wr_req_data_diff),
    .in_reg_tready(dma_cm_wr_req_ready_diff),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);


wire                           dma_cv2p_mpt_rd_req_valid;
wire                           dma_cv2p_mpt_rd_req_last ;
wire [(C_DATA_WIDTH-1)  :0]    dma_cv2p_mpt_rd_req_data ;
wire [(DMA_HEAD_WIDTH-1):0]    dma_cv2p_mpt_rd_req_head ;
wire                           dma_cv2p_mpt_rd_req_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_8(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(dma_cv2p_mpt_rd_req_valid), 
    .axis_tlast(dma_cv2p_mpt_rd_req_last), 
    .axis_tuser(dma_cv2p_mpt_rd_req_head), 
    .axis_tdata(dma_cv2p_mpt_rd_req_data), 
    .axis_tready(dma_cv2p_mpt_rd_req_ready), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(dma_cv2p_mpt_rd_req_valid_diff),  
    .in_reg_tlast(dma_cv2p_mpt_rd_req_last_diff), 
    .in_reg_tuser(dma_cv2p_mpt_rd_req_head_diff),
    .in_reg_tdata(dma_cv2p_mpt_rd_req_data_diff),
    .in_reg_tready(dma_cv2p_mpt_rd_req_ready_diff),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);

wire                           dma_cv2p_mpt_rd_rsp_valid;
wire                           dma_cv2p_mpt_rd_rsp_last ;
wire [(C_DATA_WIDTH-1)  :0]    dma_cv2p_mpt_rd_rsp_data ;
wire [(DMA_HEAD_WIDTH-1):0]    dma_cv2p_mpt_rd_rsp_head ;
wire                           dma_cv2p_mpt_rd_rsp_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_9(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(dma_cv2p_mpt_rd_rsp_valid_diff), 
    .axis_tlast(dma_cv2p_mpt_rd_rsp_last_diff), 
    .axis_tuser(dma_cv2p_mpt_rd_rsp_head_diff), 
    .axis_tdata(dma_cv2p_mpt_rd_rsp_data_diff), 
    .axis_tready(dma_cv2p_mpt_rd_rsp_ready_diff), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(dma_cv2p_mpt_rd_rsp_valid),  
    .in_reg_tlast(dma_cv2p_mpt_rd_rsp_last), 
    .in_reg_tuser(dma_cv2p_mpt_rd_rsp_head),
    .in_reg_tdata(dma_cv2p_mpt_rd_rsp_data),
    .in_reg_tready(dma_cv2p_mpt_rd_rsp_ready),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);

wire                           dma_cv2p_mpt_wr_req_valid;
wire                           dma_cv2p_mpt_wr_req_last ;
wire [(C_DATA_WIDTH-1)  :0]    dma_cv2p_mpt_wr_req_data ;
wire [(DMA_HEAD_WIDTH-1):0]    dma_cv2p_mpt_wr_req_head ;
wire                           dma_cv2p_mpt_wr_req_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_10(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(dma_cv2p_mpt_wr_req_valid), 
    .axis_tlast(dma_cv2p_mpt_wr_req_last), 
    .axis_tuser(dma_cv2p_mpt_wr_req_head), 
    .axis_tdata(dma_cv2p_mpt_wr_req_data), 
    .axis_tready(dma_cv2p_mpt_wr_req_ready), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(dma_cv2p_mpt_wr_req_valid_diff),  
    .in_reg_tlast(dma_cv2p_mpt_wr_req_last_diff), 
    .in_reg_tuser(dma_cv2p_mpt_wr_req_head_diff),
    .in_reg_tdata(dma_cv2p_mpt_wr_req_data_diff),
    .in_reg_tready(dma_cv2p_mpt_wr_req_ready_diff),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);


wire                           dma_cv2p_mtt_rd_req_valid;
wire                           dma_cv2p_mtt_rd_req_last ;
wire [(C_DATA_WIDTH-1)  :0]    dma_cv2p_mtt_rd_req_data ;
wire [(DMA_HEAD_WIDTH-1):0]    dma_cv2p_mtt_rd_req_head ;
wire                           dma_cv2p_mtt_rd_req_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_11(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(dma_cv2p_mtt_rd_req_valid), 
    .axis_tlast(dma_cv2p_mtt_rd_req_last), 
    .axis_tuser(dma_cv2p_mtt_rd_req_head), 
    .axis_tdata(dma_cv2p_mtt_rd_req_data), 
    .axis_tready(dma_cv2p_mtt_rd_req_ready), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(dma_cv2p_mtt_rd_req_valid_diff),  
    .in_reg_tlast(dma_cv2p_mtt_rd_req_last_diff), 
    .in_reg_tuser(dma_cv2p_mtt_rd_req_head_diff),
    .in_reg_tdata(dma_cv2p_mtt_rd_req_data_diff),
    .in_reg_tready(dma_cv2p_mtt_rd_req_ready_diff),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);


wire                           dma_cv2p_mtt_rd_rsp_valid;
wire                           dma_cv2p_mtt_rd_rsp_last ;
wire [(C_DATA_WIDTH-1)  :0]    dma_cv2p_mtt_rd_rsp_data ;
wire [(DMA_HEAD_WIDTH-1):0]    dma_cv2p_mtt_rd_rsp_head ;
wire                           dma_cv2p_mtt_rd_rsp_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_12(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(dma_cv2p_mtt_rd_rsp_valid_diff), 
    .axis_tlast(dma_cv2p_mtt_rd_rsp_last_diff), 
    .axis_tuser(dma_cv2p_mtt_rd_rsp_head_diff), 
    .axis_tdata(dma_cv2p_mtt_rd_rsp_data_diff), 
    .axis_tready(dma_cv2p_mtt_rd_rsp_ready_diff), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(dma_cv2p_mtt_rd_rsp_valid),  
    .in_reg_tlast(dma_cv2p_mtt_rd_rsp_last), 
    .in_reg_tuser(dma_cv2p_mtt_rd_rsp_head),
    .in_reg_tdata(dma_cv2p_mtt_rd_rsp_data),
    .in_reg_tready(dma_cv2p_mtt_rd_rsp_ready),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);

wire                           dma_cv2p_mtt_wr_req_valid;
wire                           dma_cv2p_mtt_wr_req_last ;
wire [(C_DATA_WIDTH-1)  :0]    dma_cv2p_mtt_wr_req_data ;
wire [(DMA_HEAD_WIDTH-1):0]    dma_cv2p_mtt_wr_req_head ;
wire                           dma_cv2p_mtt_wr_req_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_13(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(dma_cv2p_mtt_wr_req_valid), 
    .axis_tlast(dma_cv2p_mtt_wr_req_last), 
    .axis_tuser(dma_cv2p_mtt_wr_req_head), 
    .axis_tdata(dma_cv2p_mtt_wr_req_data), 
    .axis_tready(dma_cv2p_mtt_wr_req_ready), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(dma_cv2p_mtt_wr_req_valid_diff),  
    .in_reg_tlast(dma_cv2p_mtt_wr_req_last_diff), 
    .in_reg_tuser(dma_cv2p_mtt_wr_req_head_diff),
    .in_reg_tdata(dma_cv2p_mtt_wr_req_data_diff),
    .in_reg_tready(dma_cv2p_mtt_wr_req_ready_diff),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);

wire                           dma_dv2p_dt_rd_req_valid;
wire                           dma_dv2p_dt_rd_req_last ;
wire [(C_DATA_WIDTH-1)  :0]    dma_dv2p_dt_rd_req_data ;
wire [(DMA_HEAD_WIDTH-1):0]    dma_dv2p_dt_rd_req_head ;
wire                           dma_dv2p_dt_rd_req_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_14(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(dma_dv2p_dt_rd_req_valid), 
    .axis_tlast(dma_dv2p_dt_rd_req_last), 
    .axis_tuser(dma_dv2p_dt_rd_req_head), 
    .axis_tdata(dma_dv2p_dt_rd_req_data), 
    .axis_tready(dma_dv2p_dt_rd_req_ready), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(dma_dv2p_dt_rd_req_valid_diff),  
    .in_reg_tlast(dma_dv2p_dt_rd_req_last_diff), 
    .in_reg_tuser(dma_dv2p_dt_rd_req_head_diff),
    .in_reg_tdata(dma_dv2p_dt_rd_req_data_diff),
    .in_reg_tready(dma_dv2p_dt_rd_req_ready_diff),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);

wire                           dma_dv2p_dt_rd_rsp_valid;
wire                           dma_dv2p_dt_rd_rsp_last ;
wire [(C_DATA_WIDTH-1)  :0]    dma_dv2p_dt_rd_rsp_data ;
wire [(DMA_HEAD_WIDTH-1):0]    dma_dv2p_dt_rd_rsp_head ;
wire                           dma_dv2p_dt_rd_rsp_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_15(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(dma_dv2p_dt_rd_rsp_valid_diff), 
    .axis_tlast(dma_dv2p_dt_rd_rsp_last_diff), 
    .axis_tuser(dma_dv2p_dt_rd_rsp_head_diff), 
    .axis_tdata(dma_dv2p_dt_rd_rsp_data_diff), 
    .axis_tready(dma_dv2p_dt_rd_rsp_ready_diff), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(dma_dv2p_dt_rd_rsp_valid),  
    .in_reg_tlast(dma_dv2p_dt_rd_rsp_last), 
    .in_reg_tuser(dma_dv2p_dt_rd_rsp_head),
    .in_reg_tdata(dma_dv2p_dt_rd_rsp_data),
    .in_reg_tready(dma_dv2p_dt_rd_rsp_ready),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);


wire                           dma_dv2p_dt_wr_req_valid;
wire                           dma_dv2p_dt_wr_req_last ;
wire [(C_DATA_WIDTH-1)  :0]    dma_dv2p_dt_wr_req_data ;
wire [(DMA_HEAD_WIDTH-1):0]    dma_dv2p_dt_wr_req_head ;
wire                           dma_dv2p_dt_wr_req_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_16(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(dma_dv2p_dt_wr_req_valid), 
    .axis_tlast(dma_dv2p_dt_wr_req_last), 
    .axis_tuser(dma_dv2p_dt_wr_req_head), 
    .axis_tdata(dma_dv2p_dt_wr_req_data), 
    .axis_tready(dma_dv2p_dt_wr_req_ready), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(dma_dv2p_dt_wr_req_valid_diff),  
    .in_reg_tlast(dma_dv2p_dt_wr_req_last_diff), 
    .in_reg_tuser(dma_dv2p_dt_wr_req_head_diff),
    .in_reg_tdata(dma_dv2p_dt_wr_req_data_diff),
    .in_reg_tready(dma_dv2p_dt_wr_req_ready_diff),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);

wire                           dma_dv2p_wqe_rd_req_valid;
wire                           dma_dv2p_wqe_rd_req_last ;
wire [(C_DATA_WIDTH-1)  :0]    dma_dv2p_wqe_rd_req_data ;
wire [(DMA_HEAD_WIDTH-1):0]    dma_dv2p_wqe_rd_req_head ;
wire                           dma_dv2p_wqe_rd_req_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_17(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(dma_dv2p_wqe_rd_req_valid), 
    .axis_tlast(dma_dv2p_wqe_rd_req_last), 
    .axis_tuser(dma_dv2p_wqe_rd_req_head), 
    .axis_tdata(dma_dv2p_wqe_rd_req_data), 
    .axis_tready(dma_dv2p_wqe_rd_req_ready), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(dma_dv2p_wqe_rd_req_valid_diff),  
    .in_reg_tlast(dma_dv2p_wqe_rd_req_last_diff), 
    .in_reg_tuser(dma_dv2p_wqe_rd_req_head_diff),
    .in_reg_tdata(dma_dv2p_wqe_rd_req_data_diff),
    .in_reg_tready(dma_dv2p_wqe_rd_req_ready_diff),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);

wire                           dma_dv2p_wqe_rd_rsp_valid;
wire                           dma_dv2p_wqe_rd_rsp_last ;
wire [(C_DATA_WIDTH-1)  :0]    dma_dv2p_wqe_rd_rsp_data ;
wire [(DMA_HEAD_WIDTH-1):0]    dma_dv2p_wqe_rd_rsp_head ;
wire                           dma_dv2p_wqe_rd_rsp_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_18(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(dma_dv2p_wqe_rd_rsp_valid_diff), 
    .axis_tlast(dma_dv2p_wqe_rd_rsp_last_diff), 
    .axis_tuser(dma_dv2p_wqe_rd_rsp_head_diff), 
    .axis_tdata(dma_dv2p_wqe_rd_rsp_data_diff), 
    .axis_tready(dma_dv2p_wqe_rd_rsp_ready_diff), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(dma_dv2p_wqe_rd_rsp_valid),  
    .in_reg_tlast(dma_dv2p_wqe_rd_rsp_last), 
    .in_reg_tuser(dma_dv2p_wqe_rd_rsp_head),
    .in_reg_tdata(dma_dv2p_wqe_rd_rsp_data),
    .in_reg_tready(dma_dv2p_wqe_rd_rsp_ready),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);

wire                           rx_desc_dma_req_valid;
wire                           rx_desc_dma_req_last ;
wire [(C_DATA_WIDTH-1)  :0]    rx_desc_dma_req_data ;
wire [(DMA_HEAD_WIDTH-1):0]    rx_desc_dma_req_head ;
wire                           rx_desc_dma_req_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_19(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(rx_desc_dma_req_valid), 
    .axis_tlast(rx_desc_dma_req_last), 
    .axis_tuser(rx_desc_dma_req_head), 
    .axis_tdata(rx_desc_dma_req_data), 
    .axis_tready(rx_desc_dma_req_ready), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(rx_desc_dma_req_valid_diff),  
    .in_reg_tlast(rx_desc_dma_req_last_diff), 
    .in_reg_tuser(rx_desc_dma_req_head_diff),
    .in_reg_tdata(rx_desc_dma_req_data_diff),
    .in_reg_tready(rx_desc_dma_req_ready_diff),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);

wire                           rx_desc_dma_rsp_valid;
wire                           rx_desc_dma_rsp_last ;
wire [(C_DATA_WIDTH-1)  :0]    rx_desc_dma_rsp_data ;
wire [(DMA_HEAD_WIDTH-1):0]    rx_desc_dma_rsp_head ;
wire                           rx_desc_dma_rsp_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_20(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(rx_desc_dma_rsp_valid_diff), 
    .axis_tlast(rx_desc_dma_rsp_last_diff), 
    .axis_tuser(rx_desc_dma_rsp_head_diff), 
    .axis_tdata(rx_desc_dma_rsp_data_diff), 
    .axis_tready(rx_desc_dma_rsp_ready_diff), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(rx_desc_dma_rsp_valid),  
    .in_reg_tlast(rx_desc_dma_rsp_last), 
    .in_reg_tuser(rx_desc_dma_rsp_head),
    .in_reg_tdata(rx_desc_dma_rsp_data),
    .in_reg_tready(rx_desc_dma_rsp_ready),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);


wire                           rx_axis_wr_valid;
wire                           rx_axis_wr_last ;
wire [(C_DATA_WIDTH-1)  :0]    rx_axis_wr_data ;
wire [(DMA_HEAD_WIDTH-1):0]    rx_axis_wr_head ;
wire                           rx_axis_wr_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_21(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(rx_axis_wr_valid), 
    .axis_tlast(rx_axis_wr_last), 
    .axis_tuser(rx_axis_wr_head), 
    .axis_tdata(rx_axis_wr_data), 
    .axis_tready(rx_axis_wr_ready), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(rx_axis_wr_valid_diff),  
    .in_reg_tlast(rx_axis_wr_last_diff), 
    .in_reg_tuser(rx_axis_wr_head_diff),
    .in_reg_tdata(rx_axis_wr_data_diff),
    .in_reg_tready(rx_axis_wr_ready_diff),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);


wire                           tx_desc_dma_req_valid;
wire                           tx_desc_dma_req_last ;
wire [(C_DATA_WIDTH-1)  :0]    tx_desc_dma_req_data ;
wire [(DMA_HEAD_WIDTH-1):0]    tx_desc_dma_req_head ;
wire                           tx_desc_dma_req_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_22(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(tx_desc_dma_req_valid), 
    .axis_tlast(tx_desc_dma_req_last), 
    .axis_tuser(tx_desc_dma_req_head), 
    .axis_tdata(tx_desc_dma_req_data), 
    .axis_tready(tx_desc_dma_req_ready), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(tx_desc_dma_req_valid_diff),  
    .in_reg_tlast(tx_desc_dma_req_last_diff), 
    .in_reg_tuser(tx_desc_dma_req_head_diff),
    .in_reg_tdata(tx_desc_dma_req_data_diff),
    .in_reg_tready(tx_desc_dma_req_ready_diff),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);

wire                           tx_desc_dma_rsp_valid;
wire                           tx_desc_dma_rsp_last ;
wire [(C_DATA_WIDTH-1)  :0]    tx_desc_dma_rsp_data ;
wire [(DMA_HEAD_WIDTH-1):0]    tx_desc_dma_rsp_head ;
wire                           tx_desc_dma_rsp_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_23(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(tx_desc_dma_rsp_valid_diff), 
    .axis_tlast(tx_desc_dma_rsp_last_diff), 
    .axis_tuser(tx_desc_dma_rsp_head_diff), 
    .axis_tdata(tx_desc_dma_rsp_data_diff), 
    .axis_tready(tx_desc_dma_rsp_ready_diff), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(tx_desc_dma_rsp_valid),  
    .in_reg_tlast(tx_desc_dma_rsp_last), 
    .in_reg_tuser(tx_desc_dma_rsp_head),
    .in_reg_tdata(tx_desc_dma_rsp_data),
    .in_reg_tready(tx_desc_dma_rsp_ready),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);

wire                           tx_frame_req_valid;
wire                           tx_frame_req_last ;
wire [(C_DATA_WIDTH-1)  :0]    tx_frame_req_data ;
wire [(DMA_HEAD_WIDTH-1):0]    tx_frame_req_head ;
wire                           tx_frame_req_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_24(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(tx_frame_req_valid), 
    .axis_tlast(tx_frame_req_last), 
    .axis_tuser(tx_frame_req_head), 
    .axis_tdata(tx_frame_req_data), 
    .axis_tready(tx_frame_req_ready), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(tx_frame_req_valid_diff),  
    .in_reg_tlast(tx_frame_req_last_diff), 
    .in_reg_tuser(tx_frame_req_head_diff),
    .in_reg_tdata(tx_frame_req_data_diff),
    .in_reg_tready(tx_frame_req_ready_diff),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);

wire                           tx_frame_rsp_valid;
wire                           tx_frame_rsp_last ;
wire [(C_DATA_WIDTH-1)  :0]    tx_frame_rsp_data ;
wire [(DMA_HEAD_WIDTH-1):0]    tx_frame_rsp_head ;
wire                           tx_frame_rsp_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_25(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(tx_frame_rsp_valid_diff), 
    .axis_tlast(tx_frame_rsp_last_diff), 
    .axis_tuser(tx_frame_rsp_head_diff), 
    .axis_tdata(tx_frame_rsp_data_diff), 
    .axis_tready(tx_frame_rsp_ready_diff), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(tx_frame_rsp_valid),  
    .in_reg_tlast(tx_frame_rsp_last), 
    .in_reg_tuser(tx_frame_rsp_head),
    .in_reg_tdata(tx_frame_rsp_data),
    .in_reg_tready(tx_frame_rsp_ready),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);

  
wire                           tx_axis_wr_valid;
wire                           tx_axis_wr_last ;
wire [(C_DATA_WIDTH-1)  :0]    tx_axis_wr_data ;
wire [(DMA_HEAD_WIDTH-1):0]    tx_axis_wr_head ;
wire                           tx_axis_wr_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DMA_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_26(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(tx_axis_wr_valid), 
    .axis_tlast(tx_axis_wr_last), 
    .axis_tuser(tx_axis_wr_head), 
    .axis_tdata(tx_axis_wr_data), 
    .axis_tready(tx_axis_wr_ready), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(tx_axis_wr_valid_diff),  
    .in_reg_tlast(tx_axis_wr_last_diff), 
    .in_reg_tuser(tx_axis_wr_head_diff),
    .in_reg_tdata(tx_axis_wr_data_diff),
    .in_reg_tready(tx_axis_wr_ready_diff),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);

wire                           p2p_tx_valid;
wire                           p2p_tx_last ;
wire [(C_DATA_WIDTH-1)  :0]    p2p_tx_data ;
wire [(UPPER_HEAD_WIDTH-1):0]    p2p_tx_head ;
wire                           p2p_tx_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(UPPER_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_27(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(p2p_tx_valid), 
    .axis_tlast(p2p_tx_last), 
    .axis_tuser(p2p_tx_head), 
    .axis_tdata(p2p_tx_data), 
    .axis_tready(p2p_tx_ready), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(p2p_tx_valid_diff),  
    .in_reg_tlast(p2p_tx_last_diff), 
    .in_reg_tuser(p2p_tx_head_diff),
    .in_reg_tdata(p2p_tx_data_diff),
    .in_reg_tready(p2p_tx_ready_diff),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */    
);

wire                           p2p_rx_valid;
wire                           p2p_rx_last ;
wire [(C_DATA_WIDTH-1)  :0]    p2p_rx_data ;
wire [(DOWN_HEAD_WIDTH-1):0]    p2p_rx_head ;
wire                           p2p_rx_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(DOWN_HEAD_WIDTH),
    .TDATA_WIDTH(C_DATA_WIDTH)
)
stream_reg_for_protocol_engine_28(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(32'd0),
    .axis_tstart(1'b0),
    .axis_tvalid(p2p_rx_valid_diff), 
    .axis_tlast(p2p_rx_last_diff), 
    .axis_tuser(p2p_rx_head_diff), 
    .axis_tdata(p2p_rx_data_diff), 
    .axis_tready(p2p_rx_ready_diff), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(p2p_rx_valid),  
    .in_reg_tlast(p2p_rx_last), 
    .in_reg_tuser(p2p_rx_head),
    .in_reg_tdata(p2p_rx_data),
    .in_reg_tready(p2p_rx_ready),
    .in_reg_tstart(),
    .in_reg_tkeep(),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */
);


    //HPC Traffic in
wire                                        i_link_hpc_rx_pkt_valid;
wire                                        i_link_hpc_rx_pkt_start;
wire                                        i_link_hpc_rx_pkt_end;
wire  [`HOST_ROUTE_USER_WIDTH - 1 : 0]      iv_link_hpc_rx_pkt_user;
wire  [`HOST_ROUTE_KEEP_WIDTH - 1 : 0]      iv_link_hpc_rx_pkt_keep;
wire  [`HOST_ROUTE_DATA_WIDTH - 1 : 0]      iv_link_hpc_rx_pkt_data;
wire                                        o_link_hpc_rx_pkt_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(`HOST_ROUTE_USER_WIDTH),
    .TDATA_WIDTH(`HOST_ROUTE_DATA_WIDTH),
    .TKEEP_WIDTH(`HOST_ROUTE_KEEP_WIDTH)
)
stream_reg_for_protocol_engine_29(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(iv_link_hpc_rx_pkt_keep_diff),
    .axis_tstart(i_link_hpc_rx_pkt_start_diff),
    .axis_tvalid(i_link_hpc_rx_pkt_valid_diff), 
    .axis_tlast(i_link_hpc_rx_pkt_end_diff), 
    .axis_tuser(iv_link_hpc_rx_pkt_user_diff), 
    .axis_tdata(iv_link_hpc_rx_pkt_data_diff), 
    .axis_tready(o_link_hpc_rx_pkt_ready_diff), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(i_link_hpc_rx_pkt_valid),  
    .in_reg_tlast(i_link_hpc_rx_pkt_end), 
    .in_reg_tuser(iv_link_hpc_rx_pkt_user),
    .in_reg_tdata(iv_link_hpc_rx_pkt_data),
    .in_reg_tready(o_link_hpc_rx_pkt_ready),
    .in_reg_tstart(i_link_hpc_rx_pkt_start),
    .in_reg_tkeep(iv_link_hpc_rx_pkt_keep),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */
);

    //ETH Traffic in、     
wire                                        i_link_eth_rx_pkt_valid;
wire                                        i_link_eth_rx_pkt_start;
wire                                        i_link_eth_rx_pkt_end;
wire  [`HOST_ROUTE_USER_WIDTH - 1 : 0]      iv_link_eth_rx_pkt_user;
wire  [`HOST_ROUTE_KEEP_WIDTH - 1 : 0]      iv_link_eth_rx_pkt_keep;
wire  [`HOST_ROUTE_DATA_WIDTH - 1 : 0]      iv_link_eth_rx_pkt_data;
wire                                        o_link_eth_rx_pkt_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(`HOST_ROUTE_USER_WIDTH),
    .TDATA_WIDTH(`HOST_ROUTE_DATA_WIDTH),
    .TKEEP_WIDTH(`HOST_ROUTE_KEEP_WIDTH)
)
stream_reg_for_protocol_engine_30(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(iv_link_eth_rx_pkt_keep_diff),
    .axis_tstart(i_link_eth_rx_pkt_start_diff),
    .axis_tvalid(i_link_eth_rx_pkt_valid_diff), 
    .axis_tlast(i_link_eth_rx_pkt_end_diff), 
    .axis_tuser(iv_link_eth_rx_pkt_user_diff), 
    .axis_tdata(iv_link_eth_rx_pkt_data_diff), 
    .axis_tready(o_link_eth_rx_pkt_ready_diff), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(i_link_eth_rx_pkt_valid),  
    .in_reg_tlast(i_link_eth_rx_pkt_end), 
    .in_reg_tuser(iv_link_eth_rx_pkt_user),
    .in_reg_tdata(iv_link_eth_rx_pkt_data),
    .in_reg_tready(o_link_eth_rx_pkt_ready),
    .in_reg_tstart(i_link_eth_rx_pkt_start),
    .in_reg_tkeep(iv_link_eth_rx_pkt_keep),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */
);


    //HPC Traffic out
wire                                        o_link_hpc_tx_pkt_valid;
wire                                        o_link_hpc_tx_pkt_start;
wire                                        o_link_hpc_tx_pkt_end;
wire  [`HOST_ROUTE_USER_WIDTH - 1 : 0]      ov_link_hpc_tx_pkt_user;
wire  [`HOST_ROUTE_KEEP_WIDTH - 1 : 0]      ov_link_hpc_tx_pkt_keep;
wire  [`HOST_ROUTE_DATA_WIDTH - 1 : 0]      ov_link_hpc_tx_pkt_data;
wire                                        i_link_hpc_tx_pkt_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(`HOST_ROUTE_USER_WIDTH),
    .TDATA_WIDTH(`HOST_ROUTE_DATA_WIDTH),
    .TKEEP_WIDTH(`HOST_ROUTE_KEEP_WIDTH)
)
stream_reg_for_protocol_engine_31(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(ov_link_hpc_tx_pkt_keep),
    .axis_tstart(o_link_hpc_tx_pkt_start),
    .axis_tvalid(o_link_hpc_tx_pkt_valid), 
    .axis_tlast(o_link_hpc_tx_pkt_end), 
    .axis_tuser(ov_link_hpc_tx_pkt_user), 
    .axis_tdata(ov_link_hpc_tx_pkt_data), 
    .axis_tready(i_link_hpc_tx_pkt_ready), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(o_link_hpc_tx_pkt_valid_diff),  
    .in_reg_tlast(o_link_hpc_tx_pkt_end_diff), 
    .in_reg_tuser(ov_link_hpc_tx_pkt_user_diff),
    .in_reg_tdata(ov_link_hpc_tx_pkt_data_diff),
    .in_reg_tready(i_link_hpc_tx_pkt_ready_diff),
    .in_reg_tstart(o_link_hpc_tx_pkt_start_diff),
    .in_reg_tkeep(ov_link_hpc_tx_pkt_keep_diff),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */
);


    //ETH Traffic out、      
wire                                        o_link_eth_tx_pkt_valid;
wire                                        o_link_eth_tx_pkt_start;
wire                                        o_link_eth_tx_pkt_end;
wire  [`HOST_ROUTE_USER_WIDTH - 1 : 0]      ov_link_eth_tx_pkt_user;
wire  [`HOST_ROUTE_KEEP_WIDTH - 1 : 0]      ov_link_eth_tx_pkt_keep;
wire  [`HOST_ROUTE_DATA_WIDTH - 1 : 0]      ov_link_eth_tx_pkt_data;
wire                                        i_link_eth_tx_pkt_ready;

stream_reg_for_protocol_engine 
#(
    .TUSER_WIDTH(`HOST_ROUTE_USER_WIDTH),
    .TDATA_WIDTH(`HOST_ROUTE_DATA_WIDTH),
    .TKEEP_WIDTH(`HOST_ROUTE_KEEP_WIDTH)
)
stream_reg_for_protocol_engine_32(
    .clk(clk),
    .rst_n(rst_n),

    /* -------input axis-like interface{begin}------- */
    .axis_tkeep(ov_link_eth_tx_pkt_keep),
    .axis_tstart(o_link_eth_tx_pkt_start),
    .axis_tvalid(o_link_eth_tx_pkt_valid), 
    .axis_tlast(o_link_eth_tx_pkt_end), 
    .axis_tuser(ov_link_eth_tx_pkt_user), 
    .axis_tdata(ov_link_eth_tx_pkt_data), 
    .axis_tready(i_link_eth_tx_pkt_ready), 
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .in_reg_tvalid(o_link_eth_tx_pkt_valid_diff),  
    .in_reg_tlast(o_link_eth_tx_pkt_end_diff), 
    .in_reg_tuser(ov_link_eth_tx_pkt_user_diff),
    .in_reg_tdata(ov_link_eth_tx_pkt_data_diff),
    .in_reg_tready(i_link_eth_tx_pkt_ready_diff),
    .in_reg_tstart(o_link_eth_tx_pkt_start_diff),
    .in_reg_tkeep(ov_link_eth_tx_pkt_keep_diff),
    .tuser_clear(1'b0)
    /* -------output in_reg inteface{end}------- */
);

/*Interface with Cfg Ring*/
wire 	[CFG_NODE_RW_REG_NUM * 32 - 1 : 0] 			wv_init_reg_data;     //1 for ring_data
wire  	[CFG_NODE_RO_REG_NUM * 32 - 1 : 0] 			wv_ro_reg_data;     //3 for ring_data
wire 	[CFG_NODE_RW_REG_NUM * 32 - 1 : 0] 			wv_rw_reg_data;     //1 for ring_data
wire    [31:0]										wv_dbg_sel;
wire    [31:0]										wv_dbg_bus;

//Route cfg 
wire    [ROUTE_RW_REG_NUM * 32 - 1 : 0] 			wv_route_init_reg_data;    
wire  	[ROUTE_RO_REG_NUM * 32 - 1 : 0] 			wv_route_ro_reg_data;    
wire 	[ROUTE_RW_REG_NUM * 32 - 1 : 0] 			wv_route_rw_reg_data;    
//wire    [`DBG_NUM_ROUTE_SUBSYS * 32 - 1:0]										wv_route_dbg_bus;
wire    [32 - 1:0]										wv_route_dbg_bus;

//RDMA cfg 
wire    [RDMA_RW_REG_NUM * 32 - 1 : 0] 			wv_rdma_init_reg_data;    
wire  	[RDMA_RO_REG_NUM * 32 - 1 : 0] 			wv_rdma_ro_reg_data;    
wire 	[RDMA_RW_REG_NUM * 32 - 1 : 0] 			wv_rdma_rw_reg_data;    
//wire    [(`DBG_NUM_RDMA_ENGINE_WRAPPER * 32 + `CEU_DBG_WIDTH + `VTP_DBG_REG_NUM * 32 + `CXTMGT_DBG_REG_NUM * 32) - 1:0] wv_rdma_dbg_bus;
wire    [32 - 1:0] wv_rdma_dbg_bus;

//Eth cfg 
wire    [ETH_RW_REG_NUM * 32 - 1 : 0] 			wv_eth_init_reg_data;    
wire  	[ETH_RO_REG_NUM * 32 - 1 : 0] 			wv_eth_ro_reg_data;    
wire 	[ETH_RW_REG_NUM * 32 - 1 : 0] 			wv_eth_rw_reg_data;    
//wire    [524 * 32 - 1:0]										wv_eth_dbg_bus;
wire    [32 - 1:0]										wv_eth_dbg_bus;

wire 	[`DBG_NUM_ROUTE_SUBSYS * 32 + (`DBG_NUM_RDMA_ENGINE_WRAPPER * 32 + `CEU_DBG_WIDTH + `VTP_DBG_REG_NUM * 32 + `CXTMGT_DBG_REG_NUM * 32) + 524 * 32 - 1 : 0]	wv_coalesced_bus;

assign wv_coalesced_bus = {wv_route_dbg_bus, wv_rdma_dbg_bus, wv_eth_dbg_bus};

//assign wv_ro_reg_data = {wv_route_ro_reg_data, wv_eth_ro_reg_data, wv_rdma_ro_reg_data};
//assign wv_init_reg_data = {wv_route_init_reg_data, wv_eth_init_reg_data, wv_rdma_init_reg_data};
assign wv_ro_reg_data = {wv_route_ro_reg_data, wv_rdma_ro_reg_data};
assign wv_init_reg_data = {wv_route_init_reg_data, wv_rdma_init_reg_data};

//assign wv_rdma_rw_reg_data = wv_rw_reg_data[RDMA_RW_REG_NUM * 32 - 1 : 0];
//assign wv_eth_rw_reg_data = wv_rw_reg_data[(RDMA_RW_REG_NUM + ETH_RW_REG_NUM) * 32 - 1 : RDMA_RW_REG_NUM * 32];
//assign wv_route_rw_reg_data = wv_rw_reg_data[(RDMA_RW_REG_NUM + ETH_RW_REG_NUM + ROUTE_RW_REG_NUM) * 32 - 1 : (RDMA_RW_REG_NUM + ETH_RW_REG_NUM) * 32];
assign wv_rdma_rw_reg_data = wv_rw_reg_data[RDMA_RW_REG_NUM * 32 - 1 : 0];
assign wv_eth_rw_reg_data = 'd0;
assign wv_route_rw_reg_data = wv_rw_reg_data[(RDMA_RW_REG_NUM + ROUTE_RW_REG_NUM) * 32 - 1 : (RDMA_RW_REG_NUM) * 32];

assign wv_dbg_bus = (wv_dbg_sel >= RDMA_DBG_RANGE_START && wv_dbg_sel <= RDMA_DBG_RANGE_END) ? wv_rdma_dbg_bus : 
					(wv_dbg_sel >= ETH_DBG_RANGE_START && wv_dbg_sel <= ETH_DBG_RANGE_END) ? wv_eth_dbg_bus : 
					(wv_dbg_sel >= ROUTE_DBG_RANGE_START && wv_dbg_sel <= ROUTE_DBG_RANGE_END) ? wv_route_dbg_bus :
					32'd0;				

    //connections of hpc traffic stream
    wire	[5 - 1 : 0]     					        rdma_tx_keep ;
    wire                                 		        hpc_tx_valid;
    wire                                 		        hpc_tx_last ;
    wire	[ENGINE_NIC_DATA_WIDTH - 1 : 0]             hpc_tx_data ;
    wire	[ENGINE_NIC_KEEP_WIDTH - 1 : 0]             hpc_tx_keep ;
    wire                                 		        hpc_tx_ready;
    wire 										        hpc_tx_start;
    wire 	[ENGINE_LINK_LAYER_USER_WIDTH - 1:0]	    hpc_tx_user ;

    wire	[5 - 1 : 0]     					        rdma_rx_keep ;
    wire                                 		        hpc_rx_valid;
    wire                                 		        hpc_rx_last ;
    wire	[ENGINE_NIC_DATA_WIDTH - 1 : 0]             hpc_rx_data ;
    wire	[ENGINE_NIC_KEEP_WIDTH - 1 : 0]             hpc_rx_keep ;
    wire                                 		        hpc_rx_ready;
    wire 										        hpc_rx_start;
    wire 	[ENGINE_LINK_LAYER_USER_WIDTH - 1:0]	    hpc_rx_user ;
    //connections of eth traffic stream
    wire                                 		        eth_tx_valid;
    wire                                 		        eth_tx_last ;
    wire	[ENGINE_NIC_DATA_WIDTH - 1 : 0]             eth_tx_data ;
    wire	[ENGINE_NIC_KEEP_WIDTH - 1 : 0]             eth_tx_keep ;
    wire                                 		        eth_tx_ready;
    wire 										        eth_tx_start;
    wire 	[ENGINE_LINK_LAYER_USER_WIDTH - 1:0]		eth_tx_user ;

    wire                                 		        eth_rx_valid; 
    wire                                 		        eth_rx_last ;
    wire	[ENGINE_NIC_DATA_WIDTH - 1 : 0]             eth_rx_data ;
    wire	[ENGINE_NIC_KEEP_WIDTH - 1 : 0]             eth_rx_keep ;
    wire                                 		        eth_rx_ready;	
    wire 										        eth_rx_start;
    wire 	[ENGINE_LINK_LAYER_USER_WIDTH - 1:0]		eth_rx_user ; 

    wire 				w_roce_prog_full;
    wire 	[255:0]		wv_roce_ingress_data;
    wire 				w_roce_wr_en;

    /* input from roce desc_diff, request for a desc */
    wire 				w_tx_desc_empty;
    wire 	[191:0]		wv_tx_desc_data;
    wire 				w_tx_desc_rd_en;

    wire 				w_roce_empty;
    wire 	[255:0]		wv_roce_egress_data;
    wire 				w_roce_rd_en;

    assign rdma_rx_keep = (hpc_rx_keep == 32'b0000_0000_0000_0000_0000_0000_0000_0001) ? 'd1 :
                            (hpc_rx_keep == 32'b0000_0000_0000_0000_0000_0000_0000_0011) ? 'd2 :
                            (hpc_rx_keep == 32'b0000_0000_0000_0000_0000_0000_0000_0111) ? 'd3 :
                            (hpc_rx_keep == 32'b0000_0000_0000_0000_0000_0000_0000_1111) ? 'd4 :
                            (hpc_rx_keep == 32'b0000_0000_0000_0000_0000_0000_0001_1111) ? 'd5 :
                            (hpc_rx_keep == 32'b0000_0000_0000_0000_0000_0000_0011_1111) ? 'd6 :
                            (hpc_rx_keep == 32'b0000_0000_0000_0000_0000_0000_0111_1111) ? 'd7 :
                            (hpc_rx_keep == 32'b0000_0000_0000_0000_0000_0000_1111_1111) ? 'd8 :
                            (hpc_rx_keep == 32'b0000_0000_0000_0000_0000_0001_1111_1111) ? 'd9 :
                            (hpc_rx_keep == 32'b0000_0000_0000_0000_0000_0011_1111_1111) ? 'd10 :
                            (hpc_rx_keep == 32'b0000_0000_0000_0000_0000_0111_1111_1111) ? 'd11 :
                            (hpc_rx_keep == 32'b0000_0000_0000_0000_0000_1111_1111_1111) ? 'd12 :
                            (hpc_rx_keep == 32'b0000_0000_0000_0000_0001_1111_1111_1111) ? 'd13 :
                            (hpc_rx_keep == 32'b0000_0000_0000_0000_0011_1111_1111_1111) ? 'd14 :
                            (hpc_rx_keep == 32'b0000_0000_0000_0000_0111_1111_1111_1111) ? 'd15 :
                            (hpc_rx_keep == 32'b0000_0000_0000_0000_1111_1111_1111_1111) ? 'd16 :
                            (hpc_rx_keep == 32'b0000_0000_0000_0001_1111_1111_1111_1111) ? 'd17 :
                            (hpc_rx_keep == 32'b0000_0000_0000_0011_1111_1111_1111_1111) ? 'd18 :
                            (hpc_rx_keep == 32'b0000_0000_0000_0111_1111_1111_1111_1111) ? 'd19 :
                            (hpc_rx_keep == 32'b0000_0000_0000_1111_1111_1111_1111_1111) ? 'd20 :
                            (hpc_rx_keep == 32'b0000_0000_0001_1111_1111_1111_1111_1111) ? 'd21 :
                            (hpc_rx_keep == 32'b0000_0000_0011_1111_1111_1111_1111_1111) ? 'd22 :
                            (hpc_rx_keep == 32'b0000_0000_0111_1111_1111_1111_1111_1111) ? 'd23 :
                            (hpc_rx_keep == 32'b0000_0000_1111_1111_1111_1111_1111_1111) ? 'd24 :
                            (hpc_rx_keep == 32'b0000_0001_1111_1111_1111_1111_1111_1111) ? 'd25 :
                            (hpc_rx_keep == 32'b0000_0011_1111_1111_1111_1111_1111_1111) ? 'd26 :
                            (hpc_rx_keep == 32'b0000_0111_1111_1111_1111_1111_1111_1111) ? 'd27 :
                            (hpc_rx_keep == 32'b0000_1111_1111_1111_1111_1111_1111_1111) ? 'd28 :
                            (hpc_rx_keep == 32'b0001_1111_1111_1111_1111_1111_1111_1111) ? 'd29 :
                            (hpc_rx_keep == 32'b0011_1111_1111_1111_1111_1111_1111_1111) ? 'd30 :
                            (hpc_rx_keep == 32'b0111_1111_1111_1111_1111_1111_1111_1111) ? 'd31 :
                            (hpc_rx_keep == 32'b1111_1111_1111_1111_1111_1111_1111_1111) ? 'd0 :
                            (hpc_rx_keep == 32'b0000_0000_0000_0000_0000_0000_0000_0000) ? 'd0 : 'd0;

    assign hpc_tx_keep = (rdma_tx_keep == 'd1 ) ? 32'b0000_0000_0000_0000_0000_0000_0000_0001 : 
                            (rdma_tx_keep == 'd2 ) ? 32'b0000_0000_0000_0000_0000_0000_0000_0011 :
                            (rdma_tx_keep == 'd3 ) ? 32'b0000_0000_0000_0000_0000_0000_0000_0111 :
                            (rdma_tx_keep == 'd4 ) ? 32'b0000_0000_0000_0000_0000_0000_0000_1111 :
                            (rdma_tx_keep == 'd5 ) ? 32'b0000_0000_0000_0000_0000_0000_0001_1111 :
                            (rdma_tx_keep == 'd6 ) ? 32'b0000_0000_0000_0000_0000_0000_0011_1111 :
                            (rdma_tx_keep == 'd7 ) ? 32'b0000_0000_0000_0000_0000_0000_0111_1111 :
                            (rdma_tx_keep == 'd8 ) ? 32'b0000_0000_0000_0000_0000_0000_1111_1111 :
                            (rdma_tx_keep == 'd9 ) ? 32'b0000_0000_0000_0000_0000_0001_1111_1111 :
                            (rdma_tx_keep == 'd10) ? 32'b0000_0000_0000_0000_0000_0011_1111_1111 :
                            (rdma_tx_keep == 'd11) ? 32'b0000_0000_0000_0000_0000_0111_1111_1111 :
                            (rdma_tx_keep == 'd12) ? 32'b0000_0000_0000_0000_0000_1111_1111_1111 :
                            (rdma_tx_keep == 'd13) ? 32'b0000_0000_0000_0000_0001_1111_1111_1111 :
                            (rdma_tx_keep == 'd14) ? 32'b0000_0000_0000_0000_0011_1111_1111_1111 :
                            (rdma_tx_keep == 'd15) ? 32'b0000_0000_0000_0000_0111_1111_1111_1111 :
                            (rdma_tx_keep == 'd16) ? 32'b0000_0000_0000_0000_1111_1111_1111_1111 :
                            (rdma_tx_keep == 'd17) ? 32'b0000_0000_0000_0001_1111_1111_1111_1111 :
                            (rdma_tx_keep == 'd18) ? 32'b0000_0000_0000_0011_1111_1111_1111_1111 :
                            (rdma_tx_keep == 'd19) ? 32'b0000_0000_0000_0111_1111_1111_1111_1111 :
                            (rdma_tx_keep == 'd20) ? 32'b0000_0000_0000_1111_1111_1111_1111_1111 :
                            (rdma_tx_keep == 'd21) ? 32'b0000_0000_0001_1111_1111_1111_1111_1111 :
                            (rdma_tx_keep == 'd22) ? 32'b0000_0000_0011_1111_1111_1111_1111_1111 :
                            (rdma_tx_keep == 'd23) ? 32'b0000_0000_0111_1111_1111_1111_1111_1111 :
                            (rdma_tx_keep == 'd24) ? 32'b0000_0000_1111_1111_1111_1111_1111_1111 :
                            (rdma_tx_keep == 'd25) ? 32'b0000_0001_1111_1111_1111_1111_1111_1111 :
                            (rdma_tx_keep == 'd26) ? 32'b0000_0011_1111_1111_1111_1111_1111_1111 :
                            (rdma_tx_keep == 'd27) ? 32'b0000_0111_1111_1111_1111_1111_1111_1111 :
                            (rdma_tx_keep == 'd28) ? 32'b0000_1111_1111_1111_1111_1111_1111_1111 :
                            (rdma_tx_keep == 'd29) ? 32'b0001_1111_1111_1111_1111_1111_1111_1111 :
                            (rdma_tx_keep == 'd30) ? 32'b0011_1111_1111_1111_1111_1111_1111_1111 :
                            (rdma_tx_keep == 'd31) ? 32'b0111_1111_1111_1111_1111_1111_1111_1111 :
                            (rdma_tx_keep == 'd0 ) ? 32'b1111_1111_1111_1111_1111_1111_1111_1111 : 'd0;

wire 		[RDMA_RW_REG_NUM * 32 - 1 : 0]		wv_rdma_top_init_data;

RDMA_Top 
#(
	.RW_REG_NUM(RDMA_RW_REG_NUM),
	.RO_REG_NUM(RDMA_RO_REG_NUM)
)
RDMA_Top_Inst
(
    .clk(clk), 
    .rst(~rst_n),

    /* -------pio interface{begin}------- */
    .hcr_in_param      (hcr_in_param      ),
    .hcr_in_modifier   (hcr_in_modifier   ),
    .hcr_out_dma_addr  (hcr_out_dma_addr  ),
    .hcr_out_param     (hcr_out_param     ),
    .hcr_token         (hcr_token         ),
    .hcr_status        (hcr_status        ),
    .hcr_go            (hcr_go            ),
    .hcr_clear         (hcr_clear         ),
    .hcr_event         (hcr_event         ),
    .hcr_op_modifier   (hcr_op_modifier   ),
    .hcr_op            (hcr_op            ),

    /* --------ARM CQ interface{begin}-------- */
    .cq_ren(cq_ren) , // o, 1
    .cq_num(cq_num) , // o, 32
    .cq_dout(cq_dout), // i, 1
    /* --------ARM CQ interface{end}-------- */

    /* --------ARM EQ interface{begin}-------- */
    .eq_ren(eq_ren) , // o, 1
    .eq_num(eq_num) , // o, 32
    .eq_dout(eq_dout), // i, 1
    /* --------ARM EQ interface{end}-------- */

    /* --------Interrupt Vector entry request & response{begin}-------- */
    .pio_eq_int_req_valid(pio_eq_int_req_valid), // o, 1
    .pio_eq_int_req_num(pio_eq_int_req_num), // o, 64
    .pio_eq_int_req_ready(pio_eq_int_req_ready), // i, 1

    .pio_eq_int_rsp_valid(pio_eq_int_rsp_valid), // i, 1
    .pio_eq_int_rsp_data(pio_eq_int_rsp_data), // i, 128
    .pio_eq_int_rsp_ready(pio_eq_int_rsp_ready), // o, 1
    /* -------Interrupt Vector entry request & response{end}-------- */

    .uar_db_data (uar_db_data ),
    .uar_db_ready(uar_db_ready),
    .uar_db_valid(uar_db_valid),
    /* -------pio interface{end}------- */

    /* -------dma interface{begin}------- */
    /* dma_*_head(interact with RDMA modules), valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    // CEU Relevant
    // CEU Read Req
    .dma_ceu_rd_req_valid(dma_ceu_rd_req_valid),
    .dma_ceu_rd_req_last (dma_ceu_rd_req_last ),
    .dma_ceu_rd_req_data (dma_ceu_rd_req_data ),
    .dma_ceu_rd_req_head (dma_ceu_rd_req_head ),
    .dma_ceu_rd_req_ready(dma_ceu_rd_req_ready),

    // CEU DMA Read Resp
    .dma_ceu_rd_rsp_valid(dma_ceu_rd_rsp_valid),
    .dma_ceu_rd_rsp_last (dma_ceu_rd_rsp_last ),
    .dma_ceu_rd_rsp_data (dma_ceu_rd_rsp_data ),
    .dma_ceu_rd_rsp_head (dma_ceu_rd_rsp_head ),
    .dma_ceu_rd_rsp_ready(dma_ceu_rd_rsp_ready),

    // CEU DMA Write Req
    .dma_ceu_wr_req_valid(dma_ceu_wr_req_valid),
    .dma_ceu_wr_req_last (dma_ceu_wr_req_last ),
    .dma_ceu_wr_req_data (dma_ceu_wr_req_data ),
    .dma_ceu_wr_req_head (dma_ceu_wr_req_head ),
    .dma_ceu_wr_req_ready(dma_ceu_wr_req_ready),
    // End CEU Relevant


    // CxtMgt Relevant
    // Context Management DMA Read Request
    .dma_cm_rd_req_valid(dma_cm_rd_req_valid),
    .dma_cm_rd_req_last (dma_cm_rd_req_last ),
    .dma_cm_rd_req_data (dma_cm_rd_req_data ),
    .dma_cm_rd_req_head (dma_cm_rd_req_head ),
    .dma_cm_rd_req_ready(dma_cm_rd_req_ready),

    // Context Management DMA Read Response
    .dma_cm_rd_rsp_valid(dma_cm_rd_rsp_valid),
    .dma_cm_rd_rsp_last (dma_cm_rd_rsp_last ),
    .dma_cm_rd_rsp_data (dma_cm_rd_rsp_data ),
    .dma_cm_rd_rsp_head (dma_cm_rd_rsp_head ),
    .dma_cm_rd_rsp_ready(dma_cm_rd_rsp_ready),

    // Context Management DMA Write Request
    .dma_cm_wr_req_valid(dma_cm_wr_req_valid),
    .dma_cm_wr_req_last (dma_cm_wr_req_last ),
    .dma_cm_wr_req_data (dma_cm_wr_req_data ),
    .dma_cm_wr_req_head (dma_cm_wr_req_head ),
    .dma_cm_wr_req_ready(dma_cm_wr_req_ready),
    // End CxtMgt Relevant


    // Virt2Phys Relevant
    // Virtual to Physical DMA Context Read Request(MPT)
    .dma_cv2p_mpt_rd_req_valid(dma_cv2p_mpt_rd_req_valid),
    .dma_cv2p_mpt_rd_req_last (dma_cv2p_mpt_rd_req_last ),
    .dma_cv2p_mpt_rd_req_data (dma_cv2p_mpt_rd_req_data ),
    .dma_cv2p_mpt_rd_req_head (dma_cv2p_mpt_rd_req_head ),
    .dma_cv2p_mpt_rd_req_ready(dma_cv2p_mpt_rd_req_ready),

    // Virtual to Physical DMA Context Read Response
    .dma_cv2p_mpt_rd_rsp_valid(dma_cv2p_mpt_rd_rsp_valid),
    .dma_cv2p_mpt_rd_rsp_last (dma_cv2p_mpt_rd_rsp_last ),
    .dma_cv2p_mpt_rd_rsp_data (dma_cv2p_mpt_rd_rsp_data ),
    .dma_cv2p_mpt_rd_rsp_head (dma_cv2p_mpt_rd_rsp_head ),
    .dma_cv2p_mpt_rd_rsp_ready(dma_cv2p_mpt_rd_rsp_ready),

    // Virtual to Physical DMA Context Write Request
    .dma_cv2p_mpt_wr_req_valid(dma_cv2p_mpt_wr_req_valid),
    .dma_cv2p_mpt_wr_req_last (dma_cv2p_mpt_wr_req_last ),
    .dma_cv2p_mpt_wr_req_data (dma_cv2p_mpt_wr_req_data ),
    .dma_cv2p_mpt_wr_req_head (dma_cv2p_mpt_wr_req_head ),
    .dma_cv2p_mpt_wr_req_ready(dma_cv2p_mpt_wr_req_ready),

    .dma_cv2p_mtt_rd_req_valid(dma_cv2p_mtt_rd_req_valid),
    .dma_cv2p_mtt_rd_req_last (dma_cv2p_mtt_rd_req_last ),
    .dma_cv2p_mtt_rd_req_data (dma_cv2p_mtt_rd_req_data ),
    .dma_cv2p_mtt_rd_req_head (dma_cv2p_mtt_rd_req_head ),
    .dma_cv2p_mtt_rd_req_ready(dma_cv2p_mtt_rd_req_ready),

    // Virtual to Physical DMA Context Read Response
    .dma_cv2p_mtt_rd_rsp_valid(dma_cv2p_mtt_rd_rsp_valid),
    .dma_cv2p_mtt_rd_rsp_last (dma_cv2p_mtt_rd_rsp_last ),
    .dma_cv2p_mtt_rd_rsp_data (dma_cv2p_mtt_rd_rsp_data ),
    .dma_cv2p_mtt_rd_rsp_head (dma_cv2p_mtt_rd_rsp_head ),
    .dma_cv2p_mtt_rd_rsp_ready(dma_cv2p_mtt_rd_rsp_ready),

    // Virtual to Physical DMA Context Write Request
    .dma_cv2p_mtt_wr_req_valid(dma_cv2p_mtt_wr_req_valid),
    .dma_cv2p_mtt_wr_req_last (dma_cv2p_mtt_wr_req_last ),
    .dma_cv2p_mtt_wr_req_data (dma_cv2p_mtt_wr_req_data ),
    .dma_cv2p_mtt_wr_req_head (dma_cv2p_mtt_wr_req_head ),
    .dma_cv2p_mtt_wr_req_ready(dma_cv2p_mtt_wr_req_ready),

    // Virtual to Physical DMA Data Read Request
    .dma_dv2p_dt_rd_req_valid(dma_dv2p_dt_rd_req_valid),
    .dma_dv2p_dt_rd_req_last (dma_dv2p_dt_rd_req_last ),
    .dma_dv2p_dt_rd_req_data (dma_dv2p_dt_rd_req_data ),
    .dma_dv2p_dt_rd_req_head (dma_dv2p_dt_rd_req_head ),
    .dma_dv2p_dt_rd_req_ready(dma_dv2p_dt_rd_req_ready),

    // Virtual to Physical DMA Data Read Response
    .dma_dv2p_dt_rd_rsp_valid(dma_dv2p_dt_rd_rsp_valid),
    .dma_dv2p_dt_rd_rsp_last (dma_dv2p_dt_rd_rsp_last ),
    .dma_dv2p_dt_rd_rsp_data (dma_dv2p_dt_rd_rsp_data ),
    .dma_dv2p_dt_rd_rsp_head (dma_dv2p_dt_rd_rsp_head ),
    .dma_dv2p_dt_rd_rsp_ready(dma_dv2p_dt_rd_rsp_ready),

    // Virtual to Physical DMA Data Write Request
    .dma_dv2p_dt_wr_req_valid(dma_dv2p_dt_wr_req_valid),
    .dma_dv2p_dt_wr_req_last (dma_dv2p_dt_wr_req_last ),
    .dma_dv2p_dt_wr_req_data (dma_dv2p_dt_wr_req_data ),
    .dma_dv2p_dt_wr_req_head (dma_dv2p_dt_wr_req_head ),
    .dma_dv2p_dt_wr_req_ready (dma_dv2p_dt_wr_req_ready ),

    // ADD 1 DMA read and response channel for v2p read RQ WQE
        // Virtual to Physical DMA RQ WQE Read Request
    .dma_dv2p_wqe_rd_req_valid(dma_dv2p_wqe_rd_req_valid),
    .dma_dv2p_wqe_rd_req_last (dma_dv2p_wqe_rd_req_last ),
    .dma_dv2p_wqe_rd_req_data (dma_dv2p_wqe_rd_req_data ),
    .dma_dv2p_wqe_rd_req_head (dma_dv2p_wqe_rd_req_head ),
    .dma_dv2p_wqe_rd_req_ready(dma_dv2p_wqe_rd_req_ready),

        // Virtual to Physical DMA RQ WQE  Read Response
    .dma_dv2p_wqe_rd_rsp_valid(dma_dv2p_wqe_rd_rsp_valid),
    .dma_dv2p_wqe_rd_rsp_last (dma_dv2p_wqe_rd_rsp_last ),
    .dma_dv2p_wqe_rd_rsp_data (dma_dv2p_wqe_rd_rsp_data ),
    .dma_dv2p_wqe_rd_rsp_head (dma_dv2p_wqe_rd_rsp_head ),
    .dma_dv2p_wqe_rd_rsp_ready(dma_dv2p_wqe_rd_rsp_ready),

    // End Virt2Phys Relevant
    /* -------dma interface{end}------- */

        /*Interface with EthSubsystem*/
        //Rx 
        .o_roce_prog_full(w_roce_prog_full),
        .iv_roce_data(wv_roce_ingress_data),
        .i_roce_wr_en(w_roce_wr_en),
        
        //Tx
        .o_tx_desc_empty(w_tx_desc_empty),
        .ov_tx_desc_data(wv_tx_desc_data),
        .i_tx_desc_rd_en(w_tx_desc_rd_en),
        
        .o_roce_empty(w_roce_empty),
        .ov_roce_data(wv_roce_egress_data),
        .i_roce_rd_en(w_roce_rd_en),

        /* -------Interact with Link Layer{begin}------- */
        /*Interface with Link Layer*/
            /*Interface with TX HPC Link, AXIS Interface*/
        .o_hpc_tx_valid(hpc_tx_valid),
        .o_hpc_tx_last(hpc_tx_last),
        .ov_hpc_tx_data(hpc_tx_data),
        .ov_hpc_tx_keep(rdma_tx_keep),
        .i_hpc_tx_ready(hpc_tx_ready),
        .o_hpc_tx_start(hpc_tx_start), 		//Indicates start of the packet
        .ov_hpc_tx_user(hpc_tx_user), 	 	//Indicates length of the packet, in unit of 128 Byte, round up to 128

        /*Interface with RX HPC Link, AXIS Interface*/
            /*interface to LinkLayer Rx  */
        .i_hpc_rx_valid(hpc_rx_valid),
        .i_hpc_rx_last(hpc_rx_last),
        .iv_hpc_rx_data(hpc_rx_data),
        .iv_hpc_rx_keep(rdma_rx_keep),
        .o_hpc_rx_ready(hpc_rx_ready),
        .i_hpc_rx_start(hpc_rx_start),
        .iv_hpc_rx_user(hpc_rx_user),
        /* -------Interact with Link Layer{end}------- */

		.o_rdma_init_finish(o_rdma_init_finish),

`ifndef CFG_SIM
	/*Interface with Cfg Subsystem*/
	.iv_rw_data(wv_rdma_rw_reg_data),
	.ov_ro_data(wv_rdma_ro_reg_data),
	.ov_init_data(wv_rdma_init_reg_data),
`else 
	.iv_rw_data(wv_rdma_top_init_data),
	.ov_ro_data(),
	.ov_init_data(wv_rdma_top_init_data),
`endif
	.iv_dbg_sel(wv_dbg_sel),
	.ov_dbg_bus(wv_rdma_dbg_bus)
);

eth_engine_top 
#(
	.RW_REG_NUM(ETH_RW_REG_NUM),
	.RO_REG_NUM(ETH_RO_REG_NUM)
)
eth_engine_top_inst (
    .clk(clk),
    .rst_n(rst_n),

  /* -------interface to mac rx{begin}------- */
  /*interface to mac rx  */

    .axis_rx_valid(eth_rx_valid),
    .axis_rx_last(eth_rx_last),
    .axis_rx_data(eth_rx_data),
    .axis_rx_data_be(eth_rx_keep),
    .axis_rx_ready(eth_rx_ready),
    .axis_rx_user(eth_rx_user),
    .axis_rx_start(eth_rx_start),
    
    /* -------interface to mac rx{end}------- */
    
    
      /* to dma module, to get the desc */
    .rx_desc_dma_req_valid(rx_desc_dma_req_valid),
    .rx_desc_dma_req_last(rx_desc_dma_req_last),
    .rx_desc_dma_req_data(rx_desc_dma_req_data),
    .rx_desc_dma_req_head(rx_desc_dma_req_head),
    .rx_desc_dma_req_ready(rx_desc_dma_req_ready),
    
    .rx_desc_dma_rsp_valid(rx_desc_dma_rsp_valid),
    .rx_desc_dma_rsp_last(rx_desc_dma_rsp_last),
    .rx_desc_dma_rsp_data(rx_desc_dma_rsp_data),
    .rx_desc_dma_rsp_head(rx_desc_dma_rsp_head),
    .rx_desc_dma_rsp_ready(rx_desc_dma_rsp_ready),
  /* -------to dma module, to get the desc{end}------- */

    /* -------to dma module , to write the frame{begin}------- */
    .rx_axis_wr_valid(rx_axis_wr_valid),
    .rx_axis_wr_last(rx_axis_wr_last),
    .rx_axis_wr_data(rx_axis_wr_data),
    .rx_axis_wr_head(rx_axis_wr_head),
    .rx_axis_wr_ready(rx_axis_wr_ready),
    /* -------to dma module , to write the frame{end}------- */

    /*interface to mac rx  */
    .axis_tx_valid(eth_tx_valid),
    .axis_tx_last(eth_tx_last),
    .axis_tx_data(eth_tx_data),
    .axis_tx_data_be(eth_tx_keep),
    .axis_tx_ready(eth_tx_ready),
    .axis_tx_user(eth_tx_user),
    .axis_tx_start(eth_tx_start),
    
    /* to dma module, to get the desc */
    .tx_desc_dma_req_valid(tx_desc_dma_req_valid),
    .tx_desc_dma_req_last(tx_desc_dma_req_last),
    .tx_desc_dma_req_data(tx_desc_dma_req_data),
    .tx_desc_dma_req_head(tx_desc_dma_req_head),
    .tx_desc_dma_req_ready(tx_desc_dma_req_ready),

    /* to dma module, to get the desc */
    .tx_desc_dma_rsp_valid(tx_desc_dma_rsp_valid),
    .tx_desc_dma_rsp_data(tx_desc_dma_rsp_data),
    .tx_desc_dma_rsp_head(tx_desc_dma_rsp_head),
    .tx_desc_dma_rsp_last(tx_desc_dma_rsp_last),
    .tx_desc_dma_rsp_ready(tx_desc_dma_rsp_ready),

      /* to dma module, to get the frame */
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

    
    /* completion data dma interface */
    .tx_axis_wr_valid(tx_axis_wr_valid),
    .tx_axis_wr_data(tx_axis_wr_data),
    .tx_axis_wr_head(tx_axis_wr_head),
    .tx_axis_wr_last(tx_axis_wr_last),
    .tx_axis_wr_ready(tx_axis_wr_ready),
    

    /*interface to roce rx  */
    .i_roce_prog_full(w_roce_prog_full),
    .ov_roce_data(wv_roce_ingress_data),
    .o_roce_wr_en(w_roce_wr_en),
    
    /* input from roce desc, request for a desc */
    .i_tx_desc_empty(w_tx_desc_empty),
    .iv_tx_desc_data(wv_tx_desc_data),
    .o_tx_desc_rd_en(w_tx_desc_rd_en),
    
    .i_roce_empty(w_roce_empty),
    .iv_roce_data(wv_roce_egress_data),
    .o_roce_rd_en(w_roce_rd_en),

    .awvalid_m(awvalid_m),
    .awaddr_m({8'd0, awaddr_m}),
    .awready_m(awready_m),
    
    .wvalid_m(wvalid_m),
    .wdata_m(wdata_m),
    .wstrb_m(wstrb_m),
    .wready_m(wready_m),

    .bvalid_m(bvalid_m),
    .bready_m(bready_m),

    .arvalid_m(arvalid_m),
    .araddr_m({8'd0, araddr_m}),
    .arready_m(arready_m),

    .rvalid_m(rvalid_m),
    .rdata_m(rdata_m),
    .rready_m(rready_m),
	
	.rw_data(wv_eth_rw_reg_data),
	.ro_data(wv_eth_ro_reg_data),
	.init_rw_data(wv_eth_init_reg_data),

    .Dbg_sel(wv_dbg_sel),
	.Dbg_bus(wv_eth_dbg_bus)
);

HostRoute_Top
#(
	.ROUTE_RW_REG_NUM(ROUTE_RW_REG_NUM),
	.ROUTE_RO_REG_NUM(ROUTE_RO_REG_NUM)
)
HostRoute_Top_Inst
(
    .clk(clk),
    .rst_n(rst_n),

/*-------------------------------Interface with NIC_Top(Begin)----------------------------------*/
    //HPC Traffic in
        .i_nic_hpc_rx_pkt_valid                         (hpc_tx_valid),
        .i_nic_hpc_rx_pkt_start                         (hpc_tx_start),
        .i_nic_hpc_rx_pkt_end                           (hpc_tx_last ),
        .iv_nic_hpc_rx_pkt_user                         (hpc_tx_user ),
        .iv_nic_hpc_rx_pkt_keep                         (hpc_tx_keep ),
        .iv_nic_hpc_rx_pkt_data                         (hpc_tx_data ),	
        .o_nic_hpc_rx_pkt_ready                         (hpc_tx_ready),

    //ETH Traffic in、			
        .i_nic_eth_rx_pkt_valid                         (eth_tx_valid),
        .i_nic_eth_rx_pkt_start                         (eth_tx_start ),
        .i_nic_eth_rx_pkt_end                           (eth_tx_last ),
        .iv_nic_eth_rx_pkt_user                         (eth_tx_user ),
        .iv_nic_eth_rx_pkt_keep                         (eth_tx_keep),
        .iv_nic_eth_rx_pkt_data                         (eth_tx_data),
        .o_nic_eth_rx_pkt_ready                         (eth_tx_ready ),

    //HPC Traffic out
        .o_nic_hpc_tx_pkt_valid                         (hpc_rx_valid ),
        .o_nic_hpc_tx_pkt_start                         (hpc_rx_start ),
        .o_nic_hpc_tx_pkt_end                           (hpc_rx_last  ),
        .ov_nic_hpc_tx_pkt_user                         (hpc_rx_user  ),
        .ov_nic_hpc_tx_pkt_keep                         (hpc_rx_keep  ),
        .ov_nic_hpc_tx_pkt_data                         (hpc_rx_data  ),	
        .i_nic_hpc_tx_pkt_ready                         (hpc_rx_ready ),

    //ETH Traffic out、			
        .o_nic_eth_tx_pkt_valid                         (eth_rx_valid), 
        .o_nic_eth_tx_pkt_start                         (eth_rx_start ),
        .o_nic_eth_tx_pkt_end                           (eth_rx_last ),
        .ov_nic_eth_tx_pkt_user                         (eth_rx_user ),
        .ov_nic_eth_tx_pkt_keep                         (eth_rx_keep),	
        .ov_nic_eth_tx_pkt_data                         (eth_rx_data),
        .i_nic_eth_tx_pkt_ready                         (eth_rx_ready ), 
/*-------------------------------Interface with NIC_Top(End)----------------------------------*/

    /* --------p2p forward up channel{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved | dst_dev | src_dev | Reserved | Byte length |
     * |  63:35   |  37:35  |  34:32  |  31:16   |    15:0     |
     */
    .p2p_tx_valid(p2p_tx_valid),
    .p2p_tx_last(p2p_tx_last), 
    .p2p_tx_data(p2p_tx_data), 
    .p2p_tx_head(p2p_tx_head), 
    .p2p_tx_ready(p2p_tx_ready), 
    /* --------p2p forward up channel{end}-------- */

    /* --------p2p forward down channel{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved | dst_dev | src_dev | Reserved | Byte length |
     * |  63:35   |  37:35  |  34:32  |  31:16   |    15:0     |
     */
    .p2p_rx_valid(p2p_rx_valid),     
    .p2p_rx_last(p2p_rx_last),     
    .p2p_rx_data(p2p_rx_data), 
    .p2p_rx_head(p2p_rx_head), 
    .p2p_rx_ready(p2p_rx_ready), 
    /* --------p2p forward down channel{end}-------- */

/*-------------------------------Interface with Link(Begin)----------------------------------*/
    //HPC Traffic in
    .i_link_hpc_rx_pkt_valid(i_link_hpc_rx_pkt_valid),
    .i_link_hpc_rx_pkt_start(i_link_hpc_rx_pkt_start),
    .i_link_hpc_rx_pkt_end(i_link_hpc_rx_pkt_end),
    .iv_link_hpc_rx_pkt_user(iv_link_hpc_rx_pkt_user),
    .iv_link_hpc_rx_pkt_keep(iv_link_hpc_rx_pkt_keep),
    .iv_link_hpc_rx_pkt_data(iv_link_hpc_rx_pkt_data),
    .o_link_hpc_rx_pkt_ready(o_link_hpc_rx_pkt_ready),

    //ETH Traffic in、			
    .i_link_eth_rx_pkt_valid(i_link_eth_rx_pkt_valid),
    .i_link_eth_rx_pkt_start(i_link_eth_rx_pkt_start),
    .i_link_eth_rx_pkt_end(i_link_eth_rx_pkt_end),
    .iv_link_eth_rx_pkt_user(iv_link_eth_rx_pkt_user),
    .iv_link_eth_rx_pkt_keep(iv_link_eth_rx_pkt_keep),
    .iv_link_eth_rx_pkt_data(iv_link_eth_rx_pkt_data),
    .o_link_eth_rx_pkt_ready(o_link_eth_rx_pkt_ready),

    //HPC Traffic out
    .o_link_hpc_tx_pkt_valid(o_link_hpc_tx_pkt_valid),
    .o_link_hpc_tx_pkt_start(o_link_hpc_tx_pkt_start),
    .o_link_hpc_tx_pkt_end(o_link_hpc_tx_pkt_end),
    .ov_link_hpc_tx_pkt_user(ov_link_hpc_tx_pkt_user),
    .ov_link_hpc_tx_pkt_keep(ov_link_hpc_tx_pkt_keep),
    .ov_link_hpc_tx_pkt_data(ov_link_hpc_tx_pkt_data),
    .i_link_hpc_tx_pkt_ready(i_link_hpc_tx_pkt_ready),

    //ETH Traffic out、			
    .o_link_eth_tx_pkt_valid(o_link_eth_tx_pkt_valid),
    .o_link_eth_tx_pkt_start(o_link_eth_tx_pkt_start),
    .o_link_eth_tx_pkt_end(o_link_eth_tx_pkt_end),
    .ov_link_eth_tx_pkt_user(ov_link_eth_tx_pkt_user),
    .ov_link_eth_tx_pkt_keep(ov_link_eth_tx_pkt_keep),
    .ov_link_eth_tx_pkt_data(ov_link_eth_tx_pkt_data),
    .i_link_eth_tx_pkt_ready(i_link_eth_tx_pkt_ready),
/*-------------------------------Interface with Link(End)----------------------------------*/


/*-------------------------------Interface with Cfg_Subsystem(Begin)----------------------------------*/
	/*Interface with Cfg Ring*/
	.init_rw_data(wv_route_init_reg_data),
	.ro_reg_data(wv_route_ro_reg_data),
	.rw_reg_data(wv_route_rw_reg_data),
	.dbg_sel(wv_dbg_sel),
	.dbg_bus(wv_route_dbg_bus)	

/*-------------------------------Interface with Cfg_Subsystem(End)----------------------------------*/
);




//cfg_pkt2apb  #(
//    .APB_SEL(APB_SEL)
//)
//cfg_pkt2apb_Inst(
//    .clk(mgmt_clk),
//    .rst_n(mgmt_rst_n),
//
//    .ib_id(6'd1 + 6'b100000),
//
//    .pkt_in(inner_cfg_pkt),
//    .pkt_in_vld(inner_cfg_pkt_vld),
//    .pkt_in_rdy(inner_cfg_pkt_rdy),
//    .pkt_out(phy_cfg_pkt_out),
//    .pkt_out_vld(phy_cfg_pkt_out_vld),
//    .pkt_out_rdy(phy_cfg_pkt_out_rdy),
//
//    .psel(psel),
//    .penable(penable),
//    .pwrite(pwrite),
//    .paddr(paddr),
//    .pwdata(pwdata),
//    .pready(pready),
//    .pslverr(pslverr),
//    .prdata(prdata),
//
//    .dbg_bus(wv_pkt2apb_dbg_bus)
//);

//cfg_node #(
//    .REG_BASE_ADDR (CFG_NODE_REG_BASE_ADDR ),
//	.RW_REG_NUM(CFG_NODE_RW_REG_NUM),
//	.RO_BASE_ADDR (CFG_NODE_RO_BASE_ADDR ),
//	.RO_REG_NUM(CFG_NODE_RO_REG_NUM),
//	.BUS_BASE_ADDR (CFG_NODE_BUS_BASE_ADDR ),
//	.BUS_ADDR_WIDTH(CFG_NODE_BUS_ADDR_WIDTH)
//)
//cfg_node_Inst
//(
/////ring bus interface///////
//    .mgmt_clk(mgmt_clk),
//    .mgmt_rst_n(mgmt_rst_n),

//        ////user interface///////////
//    .clk(clk),
//    .rst_n(rst_n),

//    .ib_id(`IB_ID_PET),

//    .pkt_in(cfg_pkt_in),
//    .pkt_in_vld(cfg_pkt_in_vld),
//    .pkt_in_rdy(cfg_pkt_in_rdy),
//    .pkt_out(cfg_pkt_out),
//    .pkt_out_vld(cfg_pkt_out_vld),
//    .pkt_out_rdy(cfg_pkt_out_rdy),

//    .bus_wr_data(),
//    .bus_wr_vld(),
//    .bus_wr_rdy(1'h1),
//    .bus_rd_data(wv_dbg_sel),
//    .bus_rd_vld(1'h1),
//    .bus_rd_rdy(),


//    .rw_data(wv_rw_reg_data),//read-writer register interface
//    .ro_data(wv_ro_reg_data),//read-only register interface
//  	.init_rw_data(wv_init_reg_data),
//    .dbg_sel(wv_dbg_sel),//debug bus select
//   	.dbg_bus(wv_dbg_bus) //debug bus data
//);

/*Add redundancy registers for ECO convenience*/
reg 	[REDUNDANT_INSTANCE - 1 : 0]			redundancy_regs;
wire 							pos_triggered_rst;
assign pos_triggered_rst = ~rst_n;
always @(posedge clk or posedge pos_triggered_rst) begin
	if(pos_triggered_rst) begin
		redundancy_regs <= 'd0;
	end 
	else begin
		redundancy_regs <= redundancy_regs + 'd1;
	end 
end 

assign redundant_out = redundancy_regs;

reg         [63:0]          tx_cycle_record;                  
reg         [63:0]          rx_cycle_record;

always @(posedge clk or posedge pos_triggered_rst) begin
    if(pos_triggered_rst) begin
        tx_cycle_record <= 'd0;
        rx_cycle_record <= 'd0;
    end
    else begin
        tx_cycle_record <= tx_cycle_record + 'd1;
        rx_cycle_record <= rx_cycle_record + 'd1;
    end
end

ila_tx_cycle_record ila_tx_cycle_record_inst(
    .clk(clk),
    .probe0(o_link_eth_tx_pkt_valid_diff),
    .probe1(tx_cycle_record)
);

ila_rx_cycle_record ila_rx_cycle_record_inst(
    .clk(clk),
    .probe0(i_link_eth_rx_pkt_valid_diff),
    .probe1(rx_cycle_record)
);

endmodule
