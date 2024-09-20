`timescale 1ns / 100ps

`include "ceu_def_h.vh"
`include "msg_def_ctxmgt_h.vh"
`include "msg_def_v2p_h.vh"

module RDMA_Top #(
    parameter          C_DATA_WIDTH                        = 256,         // RX/TX interface data width
    parameter          KEEP_WIDTH                          = C_DATA_WIDTH / 32,

    // defined for pcie interface
    parameter          DMA_HEAD_WIDTH                 = 128      ,
    parameter          AXIL_DATA_WIDTH                = 32       ,
    parameter          AXIL_ADDR_WIDTH                = 24       ,
    parameter          ETHER_BASE                     = 24'h0    ,
    parameter          ETHER_LEN                      = 24'h1000 ,
    parameter          DB_BASE                        = 12'h0    ,
    parameter          HCR_BASE                       = 20'h80000,

    parameter          AXIL_STRB_WIDTH                = (AXIL_DATA_WIDTH/8),

    parameter 			NIC_DATA_WIDTH 					= 256,
    parameter 			NIC_KEEP_WIDTH 					= 5,
    parameter 			LINK_LAYER_USER_WIDTH 			= 7,

	parameter			CEU_RW_REG_NUM					=	33,
	parameter			CEU_RO_REG_NUM 					=	33,
	
	parameter			RDMAENGINE_RW_REG_NUM			=	129,
	parameter			RDMAENGINE_RO_REG_NUM 			=	129,
	
	parameter			CXTMGT_RW_REG_NUM 				=	`CXTMGT_DBG_RW_NUM,
	parameter			CXTMGT_RO_REG_NUM				=	`CXTMGT_DBG_RW_NUM,
	
	parameter			VTP_RW_REG_NUM					=	`VTP_DBG_RW_NUM,
	parameter			VTP_RO_REG_NUM					=	`VTP_DBG_RW_NUM,

	parameter			CEU_DBG_OFFSET					= 	0,
	parameter			CXT_DBG_OFFSET					=	15,
	parameter			VTP_DBG_OFFSET					=	31,
	parameter			RDMA_DBG_OFFSET					=	63,

    //parameter 			RW_REG_NUM 						= CEU_RW_REG_NUM + RDMAENGINE_RW_REG_NUM + CXTMGT_RW_REG_NUM + VTP_RW_REG_NUM,
    //parameter 			RO_REG_NUM 						= CEU_RO_REG_NUM + RDMAENGINE_RO_REG_NUM + CXTMGT_RO_REG_NUM + VTP_RO_REG_NUM
    parameter 			RW_REG_NUM 						= CEU_RW_REG_NUM + RDMAENGINE_RW_REG_NUM,
    parameter 			RO_REG_NUM 						= CEU_RO_REG_NUM + RDMAENGINE_RO_REG_NUM
) (
//    input  wire                         sys_clk  ,
    input   wire                        clk,  
    input   wire                        rst,

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

    input  wire [63:0]                  uar_db_data ,
    output wire                         uar_db_ready,
    input  wire                         uar_db_valid,

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

    /* -------dma interface{begin}------- */
    /* dma_*_head(interact with RDMA modules), valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    // CEU Relevant
    // CEU Read Req
    output  wire                           dma_ceu_rd_req_valid,
    output  wire                           dma_ceu_rd_req_last ,
    output  wire [(C_DATA_WIDTH-1)  :0]    dma_ceu_rd_req_data ,
    output  wire [(DMA_HEAD_WIDTH-1):0]    dma_ceu_rd_req_head ,
    input   wire                           dma_ceu_rd_req_ready,

    // CEU DMA Read Resp
    input   wire                           dma_ceu_rd_rsp_valid,
    input   wire                           dma_ceu_rd_rsp_last ,
    input   wire [(C_DATA_WIDTH-1)  :0]    dma_ceu_rd_rsp_data ,
    input   wire [(DMA_HEAD_WIDTH-1):0]    dma_ceu_rd_rsp_head ,
    output  wire                           dma_ceu_rd_rsp_ready,

    // CEU DMA Write Req
    output  wire                           dma_ceu_wr_req_valid,
    output  wire                           dma_ceu_wr_req_last ,
    output  wire [(C_DATA_WIDTH-1)  :0]    dma_ceu_wr_req_data ,
    output  wire [(DMA_HEAD_WIDTH-1):0]    dma_ceu_wr_req_head ,
    input   wire                           dma_ceu_wr_req_ready,
    // End CEU Relevant


    // CxtMgt Relevant
    // Context Management DMA Read Request
    output  wire                           dma_cm_rd_req_valid,
    output  wire                           dma_cm_rd_req_last ,
    output  wire [(C_DATA_WIDTH-1)  :0]    dma_cm_rd_req_data ,
    output  wire [(DMA_HEAD_WIDTH-1):0]    dma_cm_rd_req_head ,
    input   wire                           dma_cm_rd_req_ready,

    // Context Management DMA Read Response
    input   wire                           dma_cm_rd_rsp_valid,
    input   wire                           dma_cm_rd_rsp_last ,
    input   wire [(C_DATA_WIDTH-1)  :0]    dma_cm_rd_rsp_data ,
    input   wire [(DMA_HEAD_WIDTH-1):0]    dma_cm_rd_rsp_head ,
    output  wire                           dma_cm_rd_rsp_ready,

    // Context Management DMA Write Request
    output  wire                           dma_cm_wr_req_valid,
    output  wire                           dma_cm_wr_req_last ,
    output  wire [(C_DATA_WIDTH-1)  :0]    dma_cm_wr_req_data ,
    output  wire [(DMA_HEAD_WIDTH-1):0]    dma_cm_wr_req_head ,
    input   wire                           dma_cm_wr_req_ready,
    // End CxtMgt Relevant


    // Virt2Phys Relevant
    // Virtual to Physical DMA Context Read Request(MPT)
    output  wire                           dma_cv2p_mpt_rd_req_valid,
    output  wire                           dma_cv2p_mpt_rd_req_last ,
    output  wire [(C_DATA_WIDTH-1)  :0]    dma_cv2p_mpt_rd_req_data ,
    output  wire [(DMA_HEAD_WIDTH-1):0]    dma_cv2p_mpt_rd_req_head ,
    input   wire                           dma_cv2p_mpt_rd_req_ready,

    // Virtual to Physical DMA Context Read Response
    input   wire                           dma_cv2p_mpt_rd_rsp_valid,
    input   wire                           dma_cv2p_mpt_rd_rsp_last ,
    input   wire [(C_DATA_WIDTH-1)  :0]    dma_cv2p_mpt_rd_rsp_data ,
    input   wire [(DMA_HEAD_WIDTH-1):0]    dma_cv2p_mpt_rd_rsp_head ,
    output  wire                           dma_cv2p_mpt_rd_rsp_ready,

    // Virtual to Physical DMA Context Write Request
    output  wire                           dma_cv2p_mpt_wr_req_valid,
    output  wire                           dma_cv2p_mpt_wr_req_last ,
    output  wire [(C_DATA_WIDTH-1)  :0]    dma_cv2p_mpt_wr_req_data ,
    output  wire [(DMA_HEAD_WIDTH-1):0]    dma_cv2p_mpt_wr_req_head ,
    input   wire                           dma_cv2p_mpt_wr_req_ready,

    output  wire                           dma_cv2p_mtt_rd_req_valid,
    output  wire                           dma_cv2p_mtt_rd_req_last ,
    output  wire [(C_DATA_WIDTH-1)  :0]    dma_cv2p_mtt_rd_req_data ,
    output  wire [(DMA_HEAD_WIDTH-1):0]    dma_cv2p_mtt_rd_req_head ,
    input   wire                           dma_cv2p_mtt_rd_req_ready,

    // Virtual to Physical DMA Context Read Response
    input   wire                           dma_cv2p_mtt_rd_rsp_valid,
    input   wire                           dma_cv2p_mtt_rd_rsp_last ,
    input   wire [(C_DATA_WIDTH-1)  :0]    dma_cv2p_mtt_rd_rsp_data ,
    input   wire [(DMA_HEAD_WIDTH-1):0]    dma_cv2p_mtt_rd_rsp_head ,
    output  wire                           dma_cv2p_mtt_rd_rsp_ready,

    // Virtual to Physical DMA Context Write Request
    output  wire                           dma_cv2p_mtt_wr_req_valid,
    output  wire                           dma_cv2p_mtt_wr_req_last ,
    output  wire [(C_DATA_WIDTH-1)  :0]    dma_cv2p_mtt_wr_req_data ,
    output  wire [(DMA_HEAD_WIDTH-1):0]    dma_cv2p_mtt_wr_req_head ,
    input   wire                           dma_cv2p_mtt_wr_req_ready,

    // Virtual to Physical DMA Data Read Request
    output  wire                           dma_dv2p_dt_rd_req_valid,
    output  wire                           dma_dv2p_dt_rd_req_last ,
    output  wire [(C_DATA_WIDTH-1)  :0]    dma_dv2p_dt_rd_req_data ,
    output  wire [(DMA_HEAD_WIDTH-1):0]    dma_dv2p_dt_rd_req_head ,
    input   wire                           dma_dv2p_dt_rd_req_ready,

    // Virtual to Physical DMA Data Read Response
    input   wire                           dma_dv2p_dt_rd_rsp_valid,
    input   wire                           dma_dv2p_dt_rd_rsp_last ,
    input   wire [(C_DATA_WIDTH-1)  :0]    dma_dv2p_dt_rd_rsp_data ,
    input   wire [(DMA_HEAD_WIDTH-1):0]    dma_dv2p_dt_rd_rsp_head ,
    output  wire                           dma_dv2p_dt_rd_rsp_ready,

    // Virtual to Physical DMA Data Write Request
    output  wire                           dma_dv2p_dt_wr_req_valid,
    output  wire                           dma_dv2p_dt_wr_req_last ,
    output  wire [(C_DATA_WIDTH-1)  :0]    dma_dv2p_dt_wr_req_data ,
    output  wire [(DMA_HEAD_WIDTH-1):0]    dma_dv2p_dt_wr_req_head ,
    input   wire                           dma_dv2p_dt_wr_req_ready ,

    // ADD 1 DMA read and response channel for v2p read RQ WQE
        // Virtual to Physical DMA RQ WQE Read Request
    output  wire                           dma_dv2p_wqe_rd_req_valid,
    output  wire                           dma_dv2p_wqe_rd_req_last ,
    output  wire [(C_DATA_WIDTH-1)  :0]    dma_dv2p_wqe_rd_req_data ,
    output  wire [(DMA_HEAD_WIDTH-1):0]    dma_dv2p_wqe_rd_req_head ,
    input   wire                           dma_dv2p_wqe_rd_req_ready,

        // Virtual to Physical DMA RQ WQE  Read Response
    input   wire                           dma_dv2p_wqe_rd_rsp_valid,
    input   wire                           dma_dv2p_wqe_rd_rsp_last ,
    input   wire [(C_DATA_WIDTH-1)  :0]    dma_dv2p_wqe_rd_rsp_data ,
    input   wire [(DMA_HEAD_WIDTH-1):0]    dma_dv2p_wqe_rd_rsp_head ,
    output  wire                           dma_dv2p_wqe_rd_rsp_ready,

    // End Virt2Phys Relevant
    /* -------dma interface{end}------- */

    /* -------Eth Subsystem interface{begin}------- */
    //Rx 
	output  wire                            o_roce_prog_full,
	input   wire [255:0]                    iv_roce_data,
    input   wire                            i_roce_wr_en,
	
	//Tx
	output  wire                            o_tx_desc_empty,
	output  wire [191:0]                    ov_tx_desc_data,
	input   wire                            i_tx_desc_rd_en,
	
	output  wire                            o_roce_empty,
	output  wire [255:0]                    ov_roce_data,
	input   wire                            i_roce_rd_en,

	output 	wire 							o_rdma_init_finish,
    
    /* -------Eth Subsystem interface{end}------- */

	/*Interface with Link Layer*/
		/*Interface with TX HPC Link, AXIS Interface*/
	output 		wire                                 		o_hpc_tx_valid,
	output  	wire                                 		o_hpc_tx_last,
	output  	wire	[NIC_DATA_WIDTH - 1 : 0]           	ov_hpc_tx_data,
	output  	wire	[NIC_KEEP_WIDTH - 1 : 0]           	ov_hpc_tx_keep,
	input   	wire                                 		i_hpc_tx_ready,
	output 		wire 										o_hpc_tx_start, 		//Indicates start of the packet
	output 		wire 	[LINK_LAYER_USER_WIDTH - 1:0]		ov_hpc_tx_user, 	 	//Indicates length of the packet, in unit of 128 Byte, round up to 128

	/*Interface with RX HPC Link, AXIS Interface*/
		/*interface to LinkLayer Rx  */
	input     	wire                                 		i_hpc_rx_valid, 
	input     	wire                                 		i_hpc_rx_last,
	input     	wire	[NIC_DATA_WIDTH - 1 : 0]       		iv_hpc_rx_data,
	input     	wire	[NIC_KEEP_WIDTH - 1 : 0]       		iv_hpc_rx_keep,
	output    	wire                                 		o_hpc_rx_ready,	
	//Additional signals
	input 	  	wire 										i_hpc_rx_start,
	input 	  	wire 	[LINK_LAYER_USER_WIDTH - 1:0]		iv_hpc_rx_user,

	/*Interface with Cfg Subsystem*/
	input 	 	wire 	[RW_REG_NUM * 32 - 1 : 0]			iv_rw_data,
	output 		wire 	[RO_REG_NUM * 32 - 1 : 0]			ov_ro_data,
	output 		wire 	[RW_REG_NUM * 32 - 1 : 0]			ov_init_data,

	input 		wire 	[31:0]								iv_dbg_sel,
	output 		wire 	[31:0] 								ov_dbg_bus
	//output 		wire 	 [(`DBG_NUM_RDMA_ENGINE_WRAPPER * 32 + `CEU_DBG_WIDTH + `VTP_DBG_REG_NUM * 32 + `CXTMGT_DBG_REG_NUM * 32) - 1:0] ov_dbg_bus
);

/******************************************* Inner module connections : Begin *****************************************/
wire 	rdma_clk;
wire 	rst_n;
assign rdma_clk = clk;
assign rst_n = ~rst;

assign ov_ro_data = 'd0;

    /* --------ARM CQ interface{begin}-------- */
assign cq_ren = 'd0;
assign cq_num = 'd0;

    /* --------ARM EQ interface{begin}-------- */
assign eq_ren = 'd0; // o, 1
assign eq_num = 'd0; // o, 32

assign pio_eq_int_req_valid = 'd0; // o, 1
assign pio_eq_int_req_num = 'd0; // o, 64

assign pio_eq_int_rsp_ready = 'd0; // o, 1


/*---------------------------------------- Part 0: Debug connection : Begin ------------------------------------*/
wire 			[31:0]				dbg_ceu_sel;
wire 			[31:0]				dbg_cxt_sel;
wire			[31:0]				dbg_vtp_sel;
wire			[31:0]				dbg_rdma_sel;

wire 			[31:0]				dbg_ceu_bus;
wire 			[31:0]				dbg_cxt_bus;
wire			[31:0]				dbg_vtp_bus;
wire			[31:0]				dbg_rdma_bus;
//wire 			[`CEU_DBG_WIDTH - 1:0]				dbg_ceu_bus;
//wire 			[`CXTMGT_DBG_REG_NUM * 32 - 1:0]				dbg_cxt_bus;
//wire			[`VTP_DBG_REG_NUM * 32 - 1:0]				dbg_vtp_bus;
//wire			[`DBG_NUM_RDMA_ENGINE_WRAPPER * 32 - 1:0]				dbg_rdma_bus;


assign 	dbg_ceu_sel 	=	iv_dbg_sel;
assign 	dbg_cxt_sel 	=	iv_dbg_sel;
assign 	dbg_vtp_sel 	=	iv_dbg_sel;
assign 	dbg_rdma_sel 	=	iv_dbg_sel;

assign 	ov_dbg_bus 	=	(iv_dbg_sel	>= CEU_DBG_OFFSET && iv_dbg_sel < CXT_DBG_OFFSET) ? dbg_ceu_bus :
						(iv_dbg_sel	>= CXT_DBG_OFFSET && iv_dbg_sel < VTP_DBG_OFFSET) ? dbg_cxt_bus :
						(iv_dbg_sel	>= VTP_DBG_OFFSET && iv_dbg_sel < RDMA_DBG_OFFSET) ? dbg_vtp_bus :
						(iv_dbg_sel	>= RDMA_DBG_OFFSET) ? dbg_rdma_bus : 32'd0;

//assign ov_dbg_bus = {dbg_ceu_bus, dbg_cxt_bus, dbg_vtp_bus, dbg_rdma_bus};

wire 			[32 * CEU_RW_REG_NUM - 1 - 31 : 0]					ceu_init_rw_data;
wire 			[32 * CXTMGT_RW_REG_NUM - 1 : 0]				cxt_init_rw_data;
wire 			[32 * VTP_RW_REG_NUM - 1 : 0]					vtp_init_rw_data;
wire 			[32 * RDMAENGINE_RW_REG_NUM - 1 : 0]			rdmaengine_init_rw_data;	

//assign ov_init_data = {rdmaengine_init_rw_data, vtp_init_rw_data, cxt_init_rw_data, {31'b0, ceu_init_rw_data}};
assign ov_init_data = {rdmaengine_init_rw_data,  {31'b0, ceu_init_rw_data}};

/*---------------------------------------- Part 0: Debug connection : End ------------------------------------*/

/*---------------------------------------- Part 1: VTP Interface with RDMA Engine ------------------------------------*/
//Channel 1 for Doorbell Processing, only read
wire                w_db_vtp_cmd_empty;
wire                w_db_vtp_cmd_rd_en;
wire    [255:0]     wv_db_vtp_cmd_dout;
//wire                w_db_vtp_cmd_wr_en;
//wire                w_db_vtp_cmd_prog_full;
//wire    [255:0]     wv_db_vtp_cmd_din;

wire                w_db_vtp_resp_wr_en;
wire                w_db_vtp_resp_prog_full;
wire    [7:0]       wv_db_vtp_resp_din;
//wire                w_db_vtp_resp_empty;
//wire                w_db_vtp_resp_rd_en;
//wire    [7:0]       wv_db_vtp_resp_dout;

wire                w_db_vtp_download_wr_en;
wire                w_db_vtp_download_prog_full;
wire    [255:0]     wv_db_vtp_download_din;
//wire                w_db_vtp_download_empty;
//wire                w_db_vtp_download_rd_en;
//wire    [255:0]     wv_db_vtp_download_dout;


//Channel 2 for WQEParser, download SQ WQE
wire                w_wp_vtp_wqe_cmd_empty;
wire                w_wp_vtp_wqe_cmd_rd_en;
wire    [255:0]     wv_wp_vtp_wqe_cmd_dout;
//wire                w_wp_vtp_wqe_cmd_wr_en;
//wire                w_wp_vtp_wqe_cmd_prog_full;
//wire    [255:0]     wv_wp_vtp_wqe_cmd_din;

wire                w_wp_vtp_wqe_resp_wr_en;
wire                w_wp_vtp_wqe_resp_prog_full;
wire    [7:0]       wv_wp_vtp_wqe_resp_din;
//wire                w_wp_vtp_wqe_resp_empty;
//wire                w_wp_vtp_wqe_resp_rd_en;
//wire    [7:0]       wv_wp_vtp_wqe_resp_dout;

wire                w_wp_vtp_wqe_download_wr_en;
wire                w_wp_vtp_wqe_download_prog_full;
wire    [255:0]     wv_wp_vtp_wqe_download_din;
//wire                w_wp_vtp_wqe_download_empty;
//wire                w_wp_vtp_wqe_download_rd_en;
//wire    [255:0]     wv_wp_vtp_wqe_download_dout;

//Channel 3 for WQEParser, download network data
wire                w_wp_vtp_nd_cmd_empty;
wire                w_wp_vtp_nd_cmd_rd_en;
wire    [255:0]     wv_wp_vtp_nd_cmd_dout;    
//wire                w_wp_vtp_nd_cmd_wr_en;
//wire                w_wp_vtp_nd_cmd_prog_full;
//wire    [255:0]     wv_wp_vtp_nd_cmd_din;

wire                w_wp_vtp_nd_resp_wr_en;
wire                w_wp_vtp_nd_resp_prog_full;
wire    [7:0]       wv_wp_vtp_nd_resp_din;
//wire                w_wp_vtp_nd_resp_empty;
//wire                w_wp_vtp_nd_resp_rd_en;
//wire    [7:0]       wv_wp_vtp_nd_resp_dout;

wire                w_wp_vtp_nd_download_wr_en;
wire                w_wp_vtp_nd_download_prog_full;
wire    [255:0]     wv_wp_vtp_nd_download_din;
//wire                w_wp_vtp_nd_download_empty;
//wire                w_wp_vtp_nd_download_rd_en;
//wire    [255:0]     wv_wp_vtp_nd_download_dout;


//Channel 4 for RequesterTransControl, upload Completion Event
wire                w_rtc_vtp_cmd_empty;
wire                w_rtc_vtp_cmd_rd_en;
wire    [255:0]     wv_rtc_vtp_cmd_dout;
//wire                w_rtc_vtp_cmd_wr_en;
//wire                w_rtc_vtp_cmd_prog_full;
//wire    [255:0]     wv_rtc_vtp_cmd_din;

wire                w_rtc_vtp_resp_wr_en;
wire                w_rtc_vtp_resp_prog_full;
wire    [7:0]       wv_rtc_vtp_resp_din;
//wire                w_rtc_vtp_resp_empty;
//wire                w_rtc_vtp_resp_rd_en;
//wire    [7:0]       wv_rtc_vtp_resp_dout;

wire                w_rtc_vtp_upload_empty;
wire                w_rtc_vtp_upload_rd_en;
wire    [255:0]     wv_rtc_vtp_upload_dout;
//wire                w_rtc_vtp_upload_wr_en;
//wire                w_rtc_vtp_upload_prog_full;
//wire    [255:0]     wv_rtc_vtp_upload_din;

//Channel 5 for RequesterRecvControl, upload RDMA Read Response
wire                w_rrc_vtp_cmd_empty;
wire                w_rrc_vtp_cmd_rd_en;
wire    [255:0]     wv_rrc_vtp_cmd_dout;
//wire                w_rrc_vtp_cmd_wr_en;
//wire                w_rrc_vtp_cmd_prog_full;
//wire    [255:0]     wv_rrc_vtp_cmd_din;

wire                w_rrc_vtp_resp_wr_en;
wire                w_rrc_vtp_resp_prog_full;
wire    [7:0]       wv_rrc_vtp_resp_din;
//wire                w_rrc_vtp_resp_empty;
//wire                w_rrc_vtp_resp_rd_en;
//wire    [7:0]       wv_rrc_vtp_resp_dout;

wire                w_rrc_vtp_upload_empty;
wire                w_rrc_vtp_upload_rd_en;
wire    [255:0]     wv_rrc_vtp_upload_dout;
//wire                w_rrc_vtp_upload_wr_en;
//wire                w_rrc_vtp_upload_prog_full;
//wire    [255:0]     wv_rrc_vtp_upload_din;

//Channel 6 for ExecutionEngine, download RQ WQE
wire                w_rwm_vtp_cmd_empty;
wire                w_rwm_vtp_cmd_rd_en;
wire    [255:0]     wv_rwm_vtp_cmd_dout;
//wire                w_rwm_vtp_cmd_wr_en;
//wire                w_rwm_vtp_cmd_prog_full;
//wire    [255:0]     wv_rwm_vtp_cmd_din;

wire                w_rwm_vtp_resp_wr_en;
wire                w_rwm_vtp_resp_prog_full;
wire    [7:0]       wv_rwm_vtp_resp_din;
//wire                w_rwm_vtp_resp_empty;
//wire                w_rwm_vtp_resp_rd_en;
//wire    [7:0]       wv_rwm_vtp_resp_dout;

wire                w_rwm_vtp_download_wr_en;
wire                w_rwm_vtp_download_prog_full;
wire    [255:0]     wv_rwm_vtp_download_din;
//wire                w_rwm_vtp_download_rd_en;
//wire                w_rwm_vtp_download_empty;
//wire    [255:0]     wv_rwm_vtp_download_dout;

//Channel 7 for ExecutionEngine, upload Send/Write Payload and download Read Payload
wire                w_ee_vtp_cmd_empty;
wire                w_ee_vtp_cmd_rd_en;
wire    [255:0]     wv_ee_vtp_cmd_dout;
//wire                w_ee_vtp_cmd_wr_en;
//wire                w_ee_vtp_cmd_prog_full;
//wire    [255:0]     wv_ee_vtp_cmd_din;

wire                w_ee_vtp_resp_wr_en;
wire                w_ee_vtp_resp_prog_full;
wire    [7:0]       wv_ee_vtp_resp_din;
//wire                w_ee_vtp_resp_empty;
//wire                w_ee_vtp_resp_rd_en;
//wire    [7:0]       wv_ee_vtp_resp_dout;

wire                w_ee_vtp_upload_empty;
wire                w_ee_vtp_upload_rd_en;
wire    [255:0]     wv_ee_vtp_upload_dout;
//wire                w_ee_vtp_upload_wr_en;
//wire                w_ee_vtp_upload_prog_full;
//wire    [255:0]     wv_ee_vtp_upload_din;

wire                w_ee_vtp_download_wr_en;
wire                w_ee_vtp_download_prog_full;
wire    [255:0]     wv_ee_vtp_download_din;
//wire                w_ee_vtp_download_rd_en;
//wire                w_ee_vtp_download_empty;
//wire    [255:0]     wv_ee_vtp_download_dout;

/*---------------------------------------- Part 2: CxtMgt Interface with RDMA Engine ------------------------------------*/
    //Channel 1 for DoorbellProcessing, read cxt req, response ctx req, response ctx info, no write ctx req
wire                w_db_cxtmgt_cmd_empty;
wire                w_db_cxtmgt_cmd_rd_en;
wire    [127:0]     wv_db_cxtmgt_cmd_dout;
//wire                w_db_cxtmgt_cmd_wr_en;
//wire                w_db_cxtmgt_cmd_prog_full;
//wire    [127:0]     wv_db_cxtmgt_cmd_din;

wire                w_db_cxtmgt_resp_wr_en;
wire                w_db_cxtmgt_resp_prog_full;
wire    [127:0]     wv_db_cxtmgt_resp_din;
//wire                w_db_cxtmgt_resp_empty;
//wire                w_db_cxtmgt_resp_rd_en;
//wire    [127:0]     wv_db_cxtmgt_resp_dout;

wire                w_db_cxtmgt_cxt_download_wr_en;
wire                w_db_cxtmgt_cxt_download_prog_full;
wire    [255:0]     wv_db_cxtmgt_cxt_download_din;
//wire                w_db_cxtmgt_cxt_download_empty;
//wire                w_db_cxtmgt_cxt_download_rd_en;
//wire    [127:0]     wv_db_cxtmgt_cxt_download_dout;

    //Channel 2 for WQEParser, read cxt req, response ctx req, response ctx info, no write ctx req
wire                w_wp_cxtmgt_cmd_empty;
wire                w_wp_cxtmgt_cmd_rd_en;
wire    [127:0]     wv_wp_cxtmgt_cmd_dout;
//wire                w_wp_cxtmgt_cmd_wr_en;
//wire                w_wp_cxtmgt_cmd_prog_full;
//wire    [127:0]     wv_wp_cxtmgt_cmd_din;

wire                w_wp_cxtmgt_resp_wr_en;
wire                w_wp_cxtmgt_resp_prog_full;
wire    [127:0]     wv_wp_cxtmgt_resp_din;
//wire                w_wp_cxtmgt_resp_empty;
//wire                w_wp_cxtmgt_resp_rd_en;
//wire    [127:0]     wv_wp_cxtmgt_resp_dout;

wire                w_wp_cxtmgt_cxt_download_wr_en;
wire                w_wp_cxtmgt_cxt_download_prog_full;
wire    [127:0]     wv_wp_cxtmgt_cxt_download_din;
//wire                w_wp_cxtmgt_cxt_download_empty;
//wire                w_wp_cxtmgt_cxt_download_rd_en;
//wire    [127:0]     wv_wp_cxtmgt_cxt_download_dout;

    //Channel 3 for RequesterTransControl, read cxt req, response ctx req, response ctx info, write ctx req
wire                w_rtc_cxtmgt_cmd_empty;
wire                w_rtc_cxtmgt_cmd_rd_en;
wire    [127:0]     wv_rtc_cxtmgt_cmd_dout;
//wire                w_rtc_cxtmgt_cmd_wr_en;
//wire                w_rtc_cxtmgt_cmd_prog_full;
//wire    [127:0]     wv_rtc_cxtmgt_cmd_din;

wire                w_rtc_cxtmgt_resp_wr_en;
wire                w_rtc_cxtmgt_resp_prog_full;
wire    [127:0]     wv_rtc_cxtmgt_resp_din;
//wire                w_rtc_cxtmgt_resp_empty;
//wire                w_rtc_cxtmgt_resp_rd_en;
//wire    [127:0]     wv_rtc_cxtmgt_resp_dout;

wire                w_rtc_cxtmgt_cxt_download_wr_en;
wire                w_rtc_cxtmgt_cxt_download_prog_full;
wire    [9 * 32 - 1:0]     wv_rtc_cxtmgt_cxt_download_din;
//wire                w_rtc_cxtmgt_cxt_download_empty;
//wire                w_rtc_cxtmgt_cxt_download_rd_en;
//wire    [127:0]     wv_rtc_cxtmgt_cxt_download_dout;

wire                w_rtc_cxtmgt_cxt_upload_empty;
wire                w_rtc_cxtmgt_cxt_upload_rd_en;
wire    [127:0]     wv_rtc_cxtmgt_cxt_upload_dout;
//wire                w_rtc_cxtmgt_cxt_upload_prog_full;
//wire                w_rtc_cxtmgt_cxt_upload_wr_en;
//wire    [127:0]     wv_rtc_cxtmgt_cxt_upload_din;

    //Channel 4 for RequesterRecvContro, read/write cxt req, response ctx req, response ctx info,  write ctx info
wire                w_rrc_cxtmgt_cmd_empty;
wire                w_rrc_cxtmgt_cmd_rd_en;
wire    [127:0]     wv_rrc_cxtmgt_cmd_dout;
//wire                w_rrc_cxtmgt_cmd_wr_en;
//wire                w_rrc_cxtmgt_cmd_prog_full;
//wire    [127:0]     wv_rrc_cxtmgt_cmd_din;

wire                w_rrc_cxtmgt_resp_wr_en;
wire                w_rrc_cxtmgt_resp_prog_full;
wire    [127:0]     wv_rrc_cxtmgt_resp_din;
//wire                w_rrc_cxtmgt_resp_empty;
//wire                w_rrc_cxtmgt_resp_rd_en;
//wire    [127:0]     wv_rrc_cxtmgt_resp_dout;

wire                w_rrc_cxtmgt_cxt_download_wr_en;
wire                w_rrc_cxtmgt_cxt_download_prog_full;
wire    [32*11-1:0]     wv_rrc_cxtmgt_cxt_download_din;
//wire                w_rrc_cxtmgt_cxt_download_empty;
//wire                w_rrc_cxtmgt_cxt_download_rd_en;
//wire    [127:0]     wv_rrc_cxtmgt_cxt_download_dout;

wire                w_rrc_cxtmgt_cxt_upload_empty;
wire                w_rrc_cxtmgt_cxt_upload_rd_en;
wire    [127:0]     wv_rrc_cxtmgt_cxt_upload_dout;
//wire                w_rrc_cxtmgt_cxt_upload_prog_full;
//wire                w_rrc_cxtmgt_cxt_upload_wr_en;
//wire    [127:0]     wv_rrc_cxtmgt_cxt_upload_din; 

//Channel 5 for ExecutionEngine, read/write cxt req, response ctx req, response ctx info,  write ctx info
wire                w_ee_cxtmgt_cmd_empty;
wire                w_ee_cxtmgt_cmd_rd_en;
wire    [127:0]     wv_ee_cxtmgt_cmd_dout;
//wire                w_ee_cxtmgt_cmd_wr_en;
//wire                w_ee_cxtmgt_cmd_prog_full;
//wire    [127:0]     wv_ee_cxtmgt_cmd_din;

wire                w_ee_cxtmgt_resp_wr_en;
wire                w_ee_cxtmgt_resp_prog_full;
wire    [127:0]     wv_ee_cxtmgt_resp_din;
//wire                w_ee_cxtmgt_resp_empty;
//wire                w_ee_cxtmgt_resp_rd_en;
//wire    [127:0]     wv_ee_cxtmgt_resp_dout;

wire                w_ee_cxtmgt_cxt_download_wr_en;
wire                w_ee_cxtmgt_cxt_download_prog_full;
wire    [32*13-1:0]     wv_ee_cxtmgt_cxt_download_din;
//wire                w_ee_cxtmgt_cxt_download_empty;
//wire                w_ee_cxtmgt_cxt_download_rd_en;
//wire    [127:0]     wv_ee_cxtmgt_cxt_download_dout;

wire                w_ee_cxtmgt_cxt_upload_empty;
wire                w_ee_cxtmgt_cxt_upload_rd_en;
wire    [127:0]     wv_ee_cxtmgt_cxt_upload_dout;
//wire                w_ee_cxtmgt_cxt_upload_prog_full;
//wire                w_ee_cxtmgt_cxt_upload_wr_en;
//wire    [127:0]     wv_ee_cxtmgt_cxt_upload_din;

    //Channel 6 for FrameEncap, read cxt req, response ctx req, response ctx info
wire                w_fe_cxtmgt_cmd_empty;
wire                w_fe_cxtmgt_cmd_rd_en;
wire    [127:0]     wv_fe_cxtmgt_cmd_dout;

wire                w_fe_cxtmgt_resp_wr_en;
wire                w_fe_cxtmgt_resp_prog_full;
wire    [127:0]     wv_fe_cxtmgt_resp_din;

wire                w_fe_cxtmgt_cxt_download_wr_en;
wire                w_fe_cxtmgt_cxt_download_prog_full;
wire    [255:0]     wv_fe_cxtmgt_cxt_download_din;

/*---------------------------------------- Part 3: CEU Interface with CxtMgt ------------------------------------*/
/* -------Interact with Context Management Interface{begin}------- */
// CxtMgt req
wire                                     ceu_cm_req_valid; 
wire                                     ceu_cm_req_ready; 
wire [C_DATA_WIDTH-1      :0]            ceu_cm_req_data ;
wire [`CEU_CM_HEAD_WIDTH-1:0]            ceu_cm_req_head ;
wire                                     ceu_cm_req_last ; 

// CxtMgt read resp
wire                                       ceu_cm_rsp_valid;
wire                                       ceu_cm_rsp_ready;
wire [C_DATA_WIDTH-1      :0]              ceu_cm_rsp_data ;
wire [`CEU_CM_HEAD_WIDTH-1:0]              ceu_cm_rsp_head ;
wire                                       ceu_cm_rsp_last ;
/* -------Interact with Context Management Interface{end}------- */

/*---------------------------------------- Part 4: CEU Interface with VTP ------------------------------------*/
/* -------Interact with virtual-to-physial Interface{begin}------- */
// VirtToPhys write req
wire                                        ceu_v2p_req_valid;
wire                                        ceu_v2p_req_ready;
wire [(C_DATA_WIDTH-1)      :0]             ceu_v2p_req_data ;
wire [(`CEU_V2P_HEAD_WIDTH-1):0]            ceu_v2p_req_head ;
wire                                        ceu_v2p_req_last ;
/* -------Interact with virtual-to-physial Interface{end}------- */

wire [C_DATA_WIDTH-1:0] ceu_dma_wreq_data;
assign dma_ceu_wr_req_data = beat_trans(ceu_dma_wreq_data);
/* ------- DW transform{begin} ------ */
function [31:0] dw_trans;
input [31:0] dw_in;
begin
    dw_trans = {dw_in[7:0], dw_in[15:8], dw_in[23:16], dw_in[31:24]};
end
endfunction
/* ------- DW transform{end} ------ */

/* ------- Beat transform{begin} ------ */
function [255:0] beat_trans;
input [255:0] beat_in;
begin
    beat_trans = {dw_trans(beat_in[31 :0  ]), 
                  dw_trans(beat_in[63 :32 ]), 
                  dw_trans(beat_in[95 :64 ]), 
                  dw_trans(beat_in[127:96 ]), 
                  dw_trans(beat_in[159:128]), 
                  dw_trans(beat_in[191:160]), 
                  dw_trans(beat_in[223:192]), 
                  dw_trans(beat_in[255:224])};
end
endfunction
/* ------- Beat transform{end} ------ */

/******************************************* Inner module connections : End *****************************************/

//wire clk;

//BUFG BUFG1 (
//    .O(clk), // 1-bit output: Clock output
//    .I(sys_clk)  // 1-bit input: Clock input
//);

//Modified by Yangfan since there are two clk_wiz_0 in the prj, we rename this one

CEU #(
   .DMA_HEAD_WIDTH     ( DMA_HEAD_WIDTH     )     // DMA Stream *_head width
  // .C_DATA_WIDTH       ( C_DATA_WIDTH       )      // Stream Channel data width
) CEU_inst (
   .clk     ( rdma_clk ), // i, 1
   .rst_n   ( rst_n    ), // i, 1
`ifdef CEU_DBG_LOGIC
	.rw_data(iv_rw_data[32 * CEU_RW_REG_NUM - 1 - 31 : 0]),
	.rw_init_data(ceu_init_rw_data),
	.ro_data(),
	.dbg_sel(dbg_ceu_sel),
	.dbg_bus(dbg_ceu_bus),
`endif

   /* -------Interact with PIO Interface{begin}------- */
   .hcr_in_param     ( hcr_in_param     ), // i, 64
   .hcr_in_modifier  ( hcr_in_modifier  ), // i, 32
   .hcr_out_dma_addr ( hcr_out_dma_addr ), // i, 64
   .hcr_out_param    ( hcr_out_param    ), // o, 64
   .hcr_token        ( hcr_token        ), // i, 32
   .hcr_status       ( hcr_status       ), // o, 8
   .hcr_go           ( hcr_go           ), // i, 1
   .hcr_clear        ( hcr_clear        ), // o, 1
   .hcr_event        ( hcr_event        ), // i, 1
   .hcr_op_modifier  ( hcr_op_modifier  ), // i, 8
   .hcr_op           ( hcr_op           ), // i, 12
   /* -------Interact with PIO Interface{end}------- */


   /* -------Interact with DMA-engine module{begin}------- */
   /* dma_*_head(interact with RDMA modules), valid only in first beat of a packet
    * | Reserved | address | Reserved | Byte length |
    * |  127:96  |  95:32  |  31:13   |    12:0     |
    */
   // DMA Read Req
   .dma_rd_req_valid ( dma_ceu_rd_req_valid ), // o, 1
   .dma_rd_req_last  ( dma_ceu_rd_req_last  ), // o, 1
   .dma_rd_req_data  ( dma_ceu_rd_req_data  ), // o, C_DATA_WIDTH
   .dma_rd_req_head  ( dma_ceu_rd_req_head  ), // o, DMA_HEAD_WIDTH
   .dma_rd_req_ready ( dma_ceu_rd_req_ready ), // i, 1
   
   // DMA Read Resp
   .dma_rd_rsp_valid ( dma_ceu_rd_rsp_valid ), // i, 1
   .dma_rd_rsp_last  ( dma_ceu_rd_rsp_last  ), // i, 1
   .dma_rd_rsp_data  ( beat_trans(dma_ceu_rd_rsp_data)  ), // i, C_DATA_WIDTH
   .dma_rd_rsp_head  ( dma_ceu_rd_rsp_head  ), // i, DMA_HEAD_WIDTH
   .dma_rd_rsp_ready ( dma_ceu_rd_rsp_ready ), // o, 1

   // DMA Write Req
   .dma_wr_req_valid ( dma_ceu_wr_req_valid ), // o, 1
   .dma_wr_req_last  ( dma_ceu_wr_req_last  ), // o, 1
   .dma_wr_req_data  ( ceu_dma_wreq_data    ), // o, C_DATA_WIDTH
   .dma_wr_req_head  ( dma_ceu_wr_req_head  ), // o, DMA_HEAD_WIDTH
   .dma_wr_req_ready ( dma_ceu_wr_req_ready ), // i, 1
   /* -------Interact with DMA-engine module{end}------- */
   

   /* -------Interact with Context Management Module{begin}------- */
   // CxtMgt req
   .cm_req_valid ( ceu_cm_req_valid ), // o, 1
   .cm_req_last  ( ceu_cm_req_last  ), // o, 1
   .cm_req_data  ( ceu_cm_req_data  ), // o, C_DATA_WIDTH
   .cm_req_head  ( ceu_cm_req_head  ), // o, `CEU_CM_HEAD_WIDTH
   .cm_req_ready ( ceu_cm_req_ready ), // i, 1

   // CxtMgt read resp
   .cm_rsp_valid ( ceu_cm_rsp_valid ), // i, 1
   .cm_rsp_last  ( ceu_cm_rsp_last  ), // i, 1
   .cm_rsp_data  ( ceu_cm_rsp_data  ), // i, C_DATA_WIDTH
   .cm_rsp_head  ( ceu_cm_rsp_head  ), // i, `CEU_CM_HEAD_WIDTH
   .cm_rsp_ready ( ceu_cm_rsp_ready ), // o, 1
   /* -------Interact with Context Management Module{end}------- */

   /* -------Interact with virtual-to-physial Module{begin}------- */
   // VirtToPhys write req
   .v2p_req_valid ( ceu_v2p_req_valid ), // o, 1
   .v2p_req_last  ( ceu_v2p_req_last  ), // o, 1
   .v2p_req_data  ( ceu_v2p_req_data  ), // o, C_DATA_WIDTH
   .v2p_req_head  ( ceu_v2p_req_head  ), // o, `CEU_V2P_HEAD_WIDTH
   .v2p_req_ready ( ceu_v2p_req_ready )  // i, 1
   /* -------Interact with virtual-to-physial Module{end}------- */

);

ctxmgt cxt_mgt_inst (
    .clk(rdma_clk),
    .rst(~rst_n),

	.cxtmgt_init_finish(w_cxtmgt_init_finish),

//Intrerface with CEU 
    //CEU request
    .ceu_req_valid(ceu_cm_req_valid),
    .ceu_req_data(ceu_cm_req_data),
    .ceu_req_last(ceu_cm_req_last),
    .ceu_req_header(ceu_cm_req_head),
    .ceu_req_ready(ceu_cm_req_ready),
    //response to CEU
    .ceu_rsp_valid(ceu_cm_rsp_valid),
    .ceu_rsp_last (ceu_cm_rsp_last ),
    .ceu_rsp_data (ceu_cm_rsp_data ),
    .ceu_rsp_head (ceu_cm_rsp_head ),
    .ceu_rsp_ready(ceu_cm_rsp_ready),

//Interface with RDMA Engine
    //Channel 1 for DoorbellProcessing, read cxt req, response ctx req, response ctx info, no write ctx req
    .i_db_cxtmgt_cmd_empty(w_db_cxtmgt_cmd_empty),
    .o_db_cxtmgt_cmd_rd_en(w_db_cxtmgt_cmd_rd_en),
    .iv_db_cxtmgt_cmd_data(wv_db_cxtmgt_cmd_dout),

    .o_db_cxtmgt_resp_wr_en(w_db_cxtmgt_resp_wr_en),
    .i_db_cxtmgt_resp_prog_full(w_db_cxtmgt_resp_prog_full),
    .ov_db_cxtmgt_resp_data(wv_db_cxtmgt_resp_din),

    .o_db_cxtmgt_resp_cxt_wr_en(w_db_cxtmgt_cxt_download_wr_en),
    .i_db_cxtmgt_resp_cxt_prog_full(w_db_cxtmgt_cxt_download_prog_full),
    .ov_db_cxtmgt_resp_cxt_data(wv_db_cxtmgt_cxt_download_din),

    //Channel 2 for WQEParser, read cxt req, response ctx req, response ctx info, no write ctx req
    .i_wp_cxtmgt_cmd_empty(w_wp_cxtmgt_cmd_empty),
    .o_wp_cxtmgt_cmd_rd_en(w_wp_cxtmgt_cmd_rd_en),
    .iv_wp_cxtmgt_cmd_data(wv_wp_cxtmgt_cmd_dout),

    .o_wp_cxtmgt_resp_wr_en(w_wp_cxtmgt_resp_wr_en),
    .i_wp_cxtmgt_resp_prog_full(w_wp_cxtmgt_resp_prog_full),
    .ov_wp_cxtmgt_resp_data(wv_wp_cxtmgt_resp_din),

    .o_wp_cxtmgt_resp_cxt_wr_en(w_wp_cxtmgt_cxt_download_wr_en),
    .i_wp_cxtmgt_resp_cxt_prog_full(w_wp_cxtmgt_cxt_download_prog_full),
    .ov_wp_cxtmgt_resp_cxt_data(wv_wp_cxtmgt_cxt_download_din),

    //Channel 3 for RequesterTransControl, read cxt req, response ctx req, response ctx info, write ctx req
    .i_rtc_cxtmgt_cmd_empty(w_rtc_cxtmgt_cmd_empty),
    .o_rtc_cxtmgt_cmd_rd_en(w_rtc_cxtmgt_cmd_rd_en),
    .iv_rtc_cxtmgt_cmd_data(wv_rtc_cxtmgt_cmd_dout),

    .o_rtc_cxtmgt_resp_wr_en(w_rtc_cxtmgt_resp_wr_en),
    .i_rtc_cxtmgt_resp_prog_full(w_rtc_cxtmgt_resp_prog_full),
    .ov_rtc_cxtmgt_resp_data(wv_rtc_cxtmgt_resp_din),

    .o_rtc_cxtmgt_resp_cxt_wr_en(w_rtc_cxtmgt_cxt_download_wr_en),
    .i_rtc_cxtmgt_resp_cxt_prog_full(w_rtc_cxtmgt_cxt_download_prog_full),
    .ov_rtc_cxtmgt_resp_cxt_data(wv_rtc_cxtmgt_cxt_download_din),

    .i_rtc_cxtmgt_cxt_empty(w_rtc_cxtmgt_cxt_upload_empty),
    .o_rtc_cxtmgt_cxt_rd_en(w_rtc_cxtmgt_cxt_upload_rd_en),
    .iv_rtc_cxtmgt_cxt_data(wv_rtc_cxtmgt_cxt_upload_dout),

    //Channel 4 for RequesterRecvContro, read/write cxt req, response ctx req, response ctx info,  write ctx info
    .i_rrc_cxtmgt_cmd_empty(w_rrc_cxtmgt_cmd_empty),
    .o_rrc_cxtmgt_cmd_rd_en(w_rrc_cxtmgt_cmd_rd_en),
    .iv_rrc_cxtmgt_cmd_data(wv_rrc_cxtmgt_cmd_dout),

    .o_rrc_cxtmgt_resp_wr_en(w_rrc_cxtmgt_resp_wr_en),
    .i_rrc_cxtmgt_resp_prog_full(w_rrc_cxtmgt_resp_prog_full),
    .ov_rrc_cxtmgt_resp_data(wv_rrc_cxtmgt_resp_din),

    .o_rrc_cxtmgt_resp_cxt_wr_en(w_rrc_cxtmgt_cxt_download_wr_en),
    .i_rrc_cxtmgt_resp_cxt_prog_full(w_rrc_cxtmgt_cxt_download_prog_full),
    .ov_rrc_cxtmgt_resp_cxt_data(wv_rrc_cxtmgt_cxt_download_din),

    .i_rrc_cxtmgt_cxt_empty(w_rrc_cxtmgt_cxt_upload_empty),
    .o_rrc_cxtmgt_cxt_rd_en(w_rrc_cxtmgt_cxt_upload_rd_en),
    .iv_rrc_cxtmgt_cxt_data(wv_rrc_cxtmgt_cxt_upload_dout),

    //Channel 5 for ExecutionEngine, read/write cxt req, response ctx req, response ctx info,  write ctx info
    .i_ee_cxtmgt_cmd_empty(w_ee_cxtmgt_cmd_empty),
    .o_ee_cxtmgt_cmd_rd_en(w_ee_cxtmgt_cmd_rd_en),
    .iv_ee_cxtmgt_cmd_data(wv_ee_cxtmgt_cmd_dout),

    .o_ee_cxtmgt_resp_wr_en(w_ee_cxtmgt_resp_wr_en),
    .i_ee_cxtmgt_resp_prog_full(w_ee_cxtmgt_resp_prog_full),
    .ov_ee_cxtmgt_resp_data(wv_ee_cxtmgt_resp_din),

    .o_ee_cxtmgt_resp_cxt_wr_en(w_ee_cxtmgt_cxt_download_wr_en),
    .i_ee_cxtmgt_resp_cxt_prog_full(w_ee_cxtmgt_cxt_download_prog_full),
    .ov_ee_cxtmgt_resp_cxt_data(wv_ee_cxtmgt_cxt_download_din),

    .i_ee_cxtmgt_cxt_empty(w_ee_cxtmgt_cxt_upload_empty),
    .o_ee_cxtmgt_cxt_rd_en(w_ee_cxtmgt_cxt_upload_rd_en),
    .iv_ee_cxtmgt_cxt_data(wv_ee_cxtmgt_cxt_upload_dout),

    //Channel 6 for FrameEncap, read cxt req, response ctx req, response ctx info
    .i_fe_cxtmgt_cmd_empty(w_fe_cxtmgt_cmd_empty),
    .o_fe_cxtmgt_cmd_rd_en(w_fe_cxtmgt_cmd_rd_en),
    .iv_fe_cxtmgt_cmd_data(wv_fe_cxtmgt_cmd_dout),

    .o_fe_cxtmgt_resp_wr_en(w_fe_cxtmgt_resp_wr_en),
    .i_fe_cxtmgt_resp_prog_full(w_fe_cxtmgt_resp_prog_full),
    .ov_fe_cxtmgt_resp_data(wv_fe_cxtmgt_resp_din),

    .o_fe_cxtmgt_resp_cxt_wr_en(w_fe_cxtmgt_cxt_download_wr_en),
    .i_fe_cxtmgt_resp_cxt_prog_full(w_fe_cxtmgt_cxt_download_prog_full),
    .ov_fe_cxtmgt_resp_cxt_data(wv_fe_cxtmgt_cxt_download_din),

//Interface with DMA Engine
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
    .dma_cm_wr_req_ready(dma_cm_wr_req_ready)

`ifndef FPGA_VERSION
	,
	.rw_data({(CXTMGT_RW_REG_NUM * 32){1'b0}}),
	.init_rw_data(cxt_init_rw_data),
	.ro_data(),
	.Dbg_sel(dbg_cxt_sel),
	.Dbg_bus(dbg_cxt_bus)
`endif

);

VirtToPhys virt2phys_inst (
    .clk(rdma_clk),
    .rst(~rst_n),

	.v2p_init_finish(w_v2p_init_finish),

//Intrerface with CEU 
    .ceu_req_tvalid(ceu_v2p_req_valid),
    .ceu_req_tready(ceu_v2p_req_ready),
    .ceu_req_tdata(ceu_v2p_req_data),
    .ceu_req_tlast(ceu_v2p_req_last),
    .ceu_req_theader(ceu_v2p_req_head),

//Interface with RDMA Engine
    //Channel 1 for Doorbell Processing, only read
    .i_db_vtp_cmd_empty(w_db_vtp_cmd_empty),
    .o_db_vtp_cmd_rd_en(w_db_vtp_cmd_rd_en),
    .iv_db_vtp_cmd_data(wv_db_vtp_cmd_dout),

    .o_db_vtp_resp_wr_en(w_db_vtp_resp_wr_en),
    .i_db_vtp_resp_prog_full(w_db_vtp_resp_prog_full),
    .ov_db_vtp_resp_data(wv_db_vtp_resp_din),

    .o_db_vtp_download_wr_en(w_db_vtp_download_wr_en),
    .i_db_vtp_download_prog_full(w_db_vtp_download_prog_full),
    .ov_db_vtp_download_data(wv_db_vtp_download_din),
        
    //Channel 2 for WQEParser, download SQ WQE
    .i_wp_vtp_wqe_cmd_empty(w_wp_vtp_wqe_cmd_empty),
    .o_wp_vtp_wqe_cmd_rd_en(w_wp_vtp_wqe_cmd_rd_en),
    .iv_wp_vtp_wqe_cmd_data(wv_wp_vtp_wqe_cmd_dout),

    .o_wp_vtp_wqe_resp_wr_en(w_wp_vtp_wqe_resp_wr_en),
    .i_wp_vtp_wqe_resp_prog_full(w_wp_vtp_wqe_resp_prog_full),
    .ov_wp_vtp_wqe_resp_data(wv_wp_vtp_wqe_resp_din),

    .o_wp_vtp_wqe_download_wr_en(w_wp_vtp_wqe_download_wr_en),
    .i_wp_vtp_wqe_download_prog_full(w_wp_vtp_wqe_download_prog_full),
    .ov_wp_vtp_wqe_download_data(wv_wp_vtp_wqe_download_din),

    //Channel 3 for WQEParser, download network data
    .i_wp_vtp_nd_cmd_empty(w_wp_vtp_nd_cmd_empty),
    .o_wp_vtp_nd_cmd_rd_en(w_wp_vtp_nd_cmd_rd_en),
    .iv_wp_vtp_nd_cmd_data(wv_wp_vtp_nd_cmd_dout),

    .o_wp_vtp_nd_resp_wr_en(w_wp_vtp_nd_resp_wr_en),
    .i_wp_vtp_nd_resp_prog_full(w_wp_vtp_nd_resp_prog_full),
    .ov_wp_vtp_nd_resp_data(wv_wp_vtp_nd_resp_din),

    .o_wp_vtp_nd_download_wr_en(w_wp_vtp_nd_download_wr_en),
    .i_wp_vtp_nd_download_prog_full(w_wp_vtp_nd_download_prog_full),
    .ov_wp_vtp_nd_download_data(wv_wp_vtp_nd_download_din),

    //Channel 4 for RequesterTransControl, upload Completion Event
    .i_rtc_vtp_cmd_empty(w_rtc_vtp_cmd_empty),
    .o_rtc_vtp_cmd_rd_en(w_rtc_vtp_cmd_rd_en),
    .iv_rtc_vtp_cmd_data(wv_rtc_vtp_cmd_dout),

    .o_rtc_vtp_resp_wr_en(w_rtc_vtp_resp_wr_en),
    .i_rtc_vtp_resp_prog_full(w_rtc_vtp_resp_prog_full),
    .ov_rtc_vtp_resp_data(wv_rtc_vtp_resp_din),

    .i_rtc_vtp_upload_empty(w_rtc_vtp_upload_empty),
    .o_rtc_vtp_upload_rd_en(w_rtc_vtp_upload_rd_en),
    .iv_rtc_vtp_upload_data(wv_rtc_vtp_upload_dout),

    //Channel 5 for RequesterRecvControl, upload RDMA Read Response
    .i_rrc_vtp_cmd_empty(w_rrc_vtp_cmd_empty),
    .o_rrc_vtp_cmd_rd_en(w_rrc_vtp_cmd_rd_en),
    .iv_rrc_vtp_cmd_data(wv_rrc_vtp_cmd_dout),

    .o_rrc_vtp_resp_wr_en(w_rrc_vtp_resp_wr_en),
    .i_rrc_vtp_resp_prog_full(w_rrc_vtp_resp_prog_full),
    .ov_rrc_vtp_resp_data(wv_rrc_vtp_resp_din),

    .i_rrc_vtp_upload_empty(w_rrc_vtp_upload_empty),
    .o_rrc_vtp_upload_rd_en(w_rrc_vtp_upload_rd_en),
    .iv_rrc_vtp_upload_data(wv_rrc_vtp_upload_dout),

    //Channel 6 for ExecutionEngine, download RQ WQE
    .i_rwm_vtp_cmd_empty(w_rwm_vtp_cmd_empty),
    .o_rwm_vtp_cmd_rd_en(w_rwm_vtp_cmd_rd_en),
    .iv_rwm_vtp_cmd_data(wv_rwm_vtp_cmd_dout),

    .o_rwm_vtp_resp_wr_en(w_rwm_vtp_resp_wr_en),
    .i_rwm_vtp_resp_prog_full(w_rwm_vtp_resp_prog_full),
    .ov_rwm_vtp_resp_data(wv_rwm_vtp_resp_din),

    .o_rwm_vtp_download_wr_en(w_rwm_vtp_download_wr_en),
    .i_rwm_vtp_download_prog_full(w_rwm_vtp_download_prog_full),
    .ov_rwm_vtp_download_data(wv_rwm_vtp_download_din),

    //Channel 7 for ExecutionEngine, upload Send/Write Payload and download Read Payload
    .i_ee_vtp_cmd_empty(w_ee_vtp_cmd_empty),
    .o_ee_vtp_cmd_rd_en(w_ee_vtp_cmd_rd_en),
    .iv_ee_vtp_cmd_data(wv_ee_vtp_cmd_dout),

    .o_ee_vtp_resp_wr_en(w_ee_vtp_resp_wr_en),
    .i_ee_vtp_resp_prog_full(w_ee_vtp_resp_prog_full),
    .ov_ee_vtp_resp_data(wv_ee_vtp_resp_din),

    .i_ee_vtp_upload_empty(w_ee_vtp_upload_empty),
    .o_ee_vtp_upload_rd_en(w_ee_vtp_upload_rd_en),
    .iv_ee_vtp_upload_data(wv_ee_vtp_upload_dout),

    .o_ee_vtp_download_wr_en(w_ee_vtp_download_wr_en),
    .i_ee_vtp_download_prog_full(w_ee_vtp_download_prog_full),
    .ov_ee_vtp_download_data(wv_ee_vtp_download_din),

//Interface with DMA Engine
    //Channel 1 DMA Read  MPT Ctx Request
    .dma_v2p_mpt_rd_req_valid(dma_cv2p_mpt_rd_req_valid),
    .dma_v2p_mpt_rd_req_last (dma_cv2p_mpt_rd_req_last ),
    .dma_v2p_mpt_rd_req_data (dma_cv2p_mpt_rd_req_data ),
    .dma_v2p_mpt_rd_req_head (dma_cv2p_mpt_rd_req_head ),
    .dma_v2p_mpt_rd_req_ready(dma_cv2p_mpt_rd_req_ready),
    //Channel 1 DMA Read  MPT Ctx Response TODO
    .dma_v2p_mpt_rd_rsp_tready(dma_cv2p_mpt_rd_rsp_ready),
    .dma_v2p_mpt_rd_rsp_tvalid(dma_cv2p_mpt_rd_rsp_valid),
    .dma_v2p_mpt_rd_rsp_tdata(dma_cv2p_mpt_rd_rsp_data),
    .dma_v2p_mpt_rd_rsp_tlast(dma_cv2p_mpt_rd_rsp_last),
    .dma_v2p_mpt_rd_rsp_theader(dma_cv2p_mpt_rd_rsp_head),
    //Channel 1 DMA Write MPT CTX
    .dma_v2p_mpt_wr_req_valid(dma_cv2p_mpt_wr_req_valid),
    .dma_v2p_mpt_wr_req_last (dma_cv2p_mpt_wr_req_last ),
    .dma_v2p_mpt_wr_req_data (dma_cv2p_mpt_wr_req_data ),
    .dma_v2p_mpt_wr_req_head (dma_cv2p_mpt_wr_req_head ),
    .dma_v2p_mpt_wr_req_ready(dma_cv2p_mpt_wr_req_ready),

    //Channel 2 DMA Read  MTT Ctx Request
    .dma_v2p_mtt_rd_req_valid(dma_cv2p_mtt_rd_req_valid),
    .dma_v2p_mtt_rd_req_last (dma_cv2p_mtt_rd_req_last ),
    .dma_v2p_mtt_rd_req_data (dma_cv2p_mtt_rd_req_data ),
    .dma_v2p_mtt_rd_req_head (dma_cv2p_mtt_rd_req_head ),
    .dma_v2p_mtt_rd_req_ready(dma_cv2p_mtt_rd_req_ready),
    //Channel 2 DMA Read  MTT Ctx Response 
    .dma_v2p_mtt_rd_rsp_tready(dma_cv2p_mtt_rd_rsp_ready),
    .dma_v2p_mtt_rd_rsp_tvalid(dma_cv2p_mtt_rd_rsp_valid),
    .dma_v2p_mtt_rd_rsp_tdata(dma_cv2p_mtt_rd_rsp_data),
    .dma_v2p_mtt_rd_rsp_tlast(dma_cv2p_mtt_rd_rsp_last),
    .dma_v2p_mtt_rd_rsp_theader(dma_cv2p_mtt_rd_rsp_head),
    //Channel 2 DMA Write MTT CTX    
    .dma_v2p_mtt_wr_req_valid(dma_cv2p_mtt_wr_req_valid),
    .dma_v2p_mtt_wr_req_last (dma_cv2p_mtt_wr_req_last ),
    .dma_v2p_mtt_wr_req_data (dma_cv2p_mtt_wr_req_data ),
    .dma_v2p_mtt_wr_req_head (dma_cv2p_mtt_wr_req_head ),
    .dma_v2p_mtt_wr_req_ready(dma_cv2p_mtt_wr_req_ready),

    //Channel 3 DMA Read  Data(WQE/Network Data) Request 
    .dma_v2p_dt_rd_req_valid(dma_dv2p_dt_rd_req_valid),
    .dma_v2p_dt_rd_req_last (dma_dv2p_dt_rd_req_last ),
    .dma_v2p_dt_rd_req_data (dma_dv2p_dt_rd_req_data ),
    .dma_v2p_dt_rd_req_head (dma_dv2p_dt_rd_req_head ),
    .dma_v2p_dt_rd_req_ready(dma_dv2p_dt_rd_req_ready),
    //Channel 3 DMA Read  Data(WQE/Network Data) Response
    .dma_v2p_dt_rd_rsp_tready(dma_dv2p_dt_rd_rsp_ready),
    .dma_v2p_dt_rd_rsp_tvalid(dma_dv2p_dt_rd_rsp_valid),
    .dma_v2p_dt_rd_rsp_tdata(dma_dv2p_dt_rd_rsp_data),
    .dma_v2p_dt_rd_rsp_tlast(dma_dv2p_dt_rd_rsp_last),
    .dma_v2p_dt_rd_rsp_theader(dma_dv2p_dt_rd_rsp_head),
    //Channel 3 DMA Write Data(CQE/Network Data)   
    .dma_v2p_dt_wr_req_valid(dma_dv2p_dt_wr_req_valid),
    .dma_v2p_dt_wr_req_last (dma_dv2p_dt_wr_req_last ),
    .dma_v2p_dt_wr_req_data (dma_dv2p_dt_wr_req_data ),
    .dma_v2p_dt_wr_req_head (dma_dv2p_dt_wr_req_head ),
    .dma_v2p_dt_wr_req_ready (dma_dv2p_dt_wr_req_ready),

    //Channel 4 DMA Read  Data(RQ WQE for RDMA engine rwm) Request 
    .dma_v2p_wqe_rd_req_valid (dma_dv2p_wqe_rd_req_valid),//output  wire                           
    .dma_v2p_wqe_rd_req_last  (dma_dv2p_wqe_rd_req_last),//output  wire                           
    .dma_v2p_wqe_rd_req_data  (dma_dv2p_wqe_rd_req_data),//output  wire [(`DT_WIDTH-1):0]         
    .dma_v2p_wqe_rd_req_head  (dma_dv2p_wqe_rd_req_head),//output  wire [(`HD_WIDTH-1):0]         
    .dma_v2p_wqe_rd_req_ready (dma_dv2p_wqe_rd_req_ready),//input   wire                           
    //Channel 4 DMA Read  Data(RQ WQE for RDMA engine rwm) Response
    .dma_v2p_wqe_rd_rsp_tready (dma_dv2p_wqe_rd_rsp_ready), //output  wire                           
    .dma_v2p_wqe_rd_rsp_tvalid (dma_dv2p_wqe_rd_rsp_valid), //input   wire                           
    .dma_v2p_wqe_rd_rsp_tdata (dma_dv2p_wqe_rd_rsp_data), //input   wire [`DT_WIDTH-1:0]           
    .dma_v2p_wqe_rd_rsp_tlast (dma_dv2p_wqe_rd_rsp_last), //input   wire                           
    .dma_v2p_wqe_rd_rsp_theader (dma_dv2p_wqe_rd_rsp_head) //input   wire [`HD_WIDTH-1:0]           

`ifndef	FPGA_VERSION
	,	

	.rw_data({(VTP_RW_REG_NUM * 32){1'b0}}),
	.init_rw_data(vtp_init_rw_data),
	.ro_data(),

	.Dbg_sel(dbg_vtp_sel),
	.Dbg_bus(dbg_vtp_bus)	
`endif
);

wire      w_pio_ready;
assign uar_db_ready = ~w_pio_ready;
RDMAEngine_Wrapper RDMAEngine_Wrapper_Inst(
    .clk(rdma_clk),
    .rst(~rst_n),

	.dbg_sel(dbg_rdma_sel),
	.dbg_bus(dbg_rdma_bus),

	.rw_data(iv_rw_data[(RDMAENGINE_RW_REG_NUM + CEU_RW_REG_NUM) * 32 - 1 : (CEU_RW_REG_NUM) * 32]),
	.rw_init_data(rdmaengine_init_rw_data),
	.ro_data(),

//Interface with PIO
    .o_pio_prog_full(w_pio_ready),
    .i_pio_wr_en(uar_db_valid),
    .iv_pio_data(uar_db_data),

//Interface with CxtMgt
    //Channel 1 for DoorbellProcessing, no cxt write back
    .i_db_cxtmgt_cmd_rd_en(w_db_cxtmgt_cmd_rd_en),
    .o_db_cxtmgt_cmd_empty(w_db_cxtmgt_cmd_empty),
    .ov_db_cxtmgt_cmd_data(wv_db_cxtmgt_cmd_dout),

    .o_db_cxtmgt_resp_prog_full(w_db_cxtmgt_resp_prog_full),
    .i_db_cxtmgt_resp_wr_en(w_db_cxtmgt_resp_wr_en),
    .iv_db_cxtmgt_resp_data(wv_db_cxtmgt_resp_din),

    .o_db_cxtmgt_cxt_download_prog_full(w_db_cxtmgt_cxt_download_prog_full),
    .i_db_cxtmgt_cxt_download_wr_en(w_db_cxtmgt_cxt_download_wr_en),
    .iv_db_cxtmgt_cxt_download_data(wv_db_cxtmgt_cxt_download_din),

    //Channel 2 for WQEParser, no cxt write back
    .i_wp_cxtmgt_cmd_rd_en(w_wp_cxtmgt_cmd_rd_en),
    .o_wp_cxtmgt_cmd_empty(w_wp_cxtmgt_cmd_empty),
    .ov_wp_cxtmgt_cmd_data(wv_wp_cxtmgt_cmd_dout),

    .o_wp_cxtmgt_resp_prog_full(w_wp_cxtmgt_resp_prog_full),
    .i_wp_cxtmgt_resp_wr_en(w_wp_cxtmgt_resp_wr_en),
    .iv_wp_cxtmgt_resp_data(wv_wp_cxtmgt_resp_din),

    .o_wp_cxtmgt_cxt_download_prog_full(w_wp_cxtmgt_cxt_download_prog_full),
    .i_wp_cxtmgt_cxt_download_wr_en(w_wp_cxtmgt_cxt_download_wr_en),
    .iv_wp_cxtmgt_cxt_download_data(wv_wp_cxtmgt_cxt_download_din),

    //Channel 3 for RequesterTransControl, cxt write back
    .i_rtc_cxtmgt_cmd_rd_en(w_rtc_cxtmgt_cmd_rd_en),
    .o_rtc_cxtmgt_cmd_empty(w_rtc_cxtmgt_cmd_empty),
    .ov_rtc_cxtmgt_cmd_data(wv_rtc_cxtmgt_cmd_dout),

    .o_rtc_cxtmgt_resp_prog_full(w_rtc_cxtmgt_resp_prog_full),
    .i_rtc_cxtmgt_resp_wr_en(w_rtc_cxtmgt_resp_wr_en),
    .iv_rtc_cxtmgt_resp_data(wv_rtc_cxtmgt_resp_din),

    .o_rtc_cxtmgt_cxt_download_prog_full(w_rtc_cxtmgt_cxt_download_prog_full),
    .i_rtc_cxtmgt_cxt_download_wr_en(w_rtc_cxtmgt_cxt_download_wr_en),
    .iv_rtc_cxtmgt_cxt_download_data(wv_rtc_cxtmgt_cxt_download_din[191:0]),

/*Spyglass Add Begin*/
    .o_rtc_cxtmgt_cxt_upload_empty(w_rtc_cxtmgt_cxt_upload_empty),
    .i_rtc_cxtmgt_cxt_upload_rd_en(w_rtc_cxtmgt_cxt_upload_rd_en),
    .ov_rtc_cxtmgt_cxt_upload_data(wv_rtc_cxtmgt_cxt_upload_dout),
/*SPyglass Add End*/

    //Channel 4 for RequesterRecvContro, cxt write back 
    .i_rrc_cxtmgt_cmd_rd_en(w_rrc_cxtmgt_cmd_rd_en),
    .o_rrc_cxtmgt_cmd_empty(w_rrc_cxtmgt_cmd_empty),
    .ov_rrc_cxtmgt_cmd_data(wv_rrc_cxtmgt_cmd_dout),

    .o_rrc_cxtmgt_resp_prog_full(w_rrc_cxtmgt_resp_prog_full),
    .i_rrc_cxtmgt_resp_wr_en(w_rrc_cxtmgt_resp_wr_en),
    .iv_rrc_cxtmgt_resp_data(wv_rrc_cxtmgt_resp_din),

    .o_rrc_cxtmgt_cxt_download_prog_full(w_rrc_cxtmgt_cxt_download_prog_full),
    .i_rrc_cxtmgt_cxt_download_wr_en(w_rrc_cxtmgt_cxt_download_wr_en),
    .iv_rrc_cxtmgt_cxt_download_data(wv_rrc_cxtmgt_cxt_download_din[255:0]),

    .i_rrc_cxtmgt_cxt_upload_rd_en(w_rrc_cxtmgt_cxt_upload_rd_en),
    .o_rrc_cxtmgt_cxt_upload_empty(w_rrc_cxtmgt_cxt_upload_empty),
    .ov_rrc_cxtmgt_cxt_upload_data(wv_rrc_cxtmgt_cxt_upload_dout),

    //Channel 5 for ExecutionEngine, cxt write back
    .i_ee_cxtmgt_cmd_rd_en(w_ee_cxtmgt_cmd_rd_en),
    .o_ee_cxtmgt_cmd_empty(w_ee_cxtmgt_cmd_empty),
    .ov_ee_cxtmgt_cmd_data(wv_ee_cxtmgt_cmd_dout),

    .o_ee_cxtmgt_resp_prog_full(w_ee_cxtmgt_resp_prog_full),
    .i_ee_cxtmgt_resp_wr_en(w_ee_cxtmgt_resp_wr_en),
    .iv_ee_cxtmgt_resp_data(wv_ee_cxtmgt_resp_din),

    .o_ee_cxtmgt_cxt_download_prog_full(w_ee_cxtmgt_cxt_download_prog_full),
    .i_ee_cxtmgt_cxt_download_wr_en(w_ee_cxtmgt_cxt_download_wr_en),
    .iv_ee_cxtmgt_cxt_download_data(wv_ee_cxtmgt_cxt_download_din[319:0]),

    .i_ee_cxtmgt_cxt_upload_rd_en(w_ee_cxtmgt_cxt_upload_rd_en),
    .o_ee_cxtmgt_cxt_upload_empty(w_ee_cxtmgt_cxt_upload_empty),
    .ov_ee_cxtmgt_cxt_upload_data(wv_ee_cxtmgt_cxt_upload_dout),

    .i_fe_cxtmgt_cmd_rd_en(w_fe_cxtmgt_cmd_rd_en),
    .o_fe_cxtmgt_cmd_empty(w_fe_cxtmgt_cmd_empty),
    .ov_fe_cxtmgt_cmd_data(wv_fe_cxtmgt_cmd_dout),

    .o_fe_cxtmgt_resp_prog_full(w_fe_cxtmgt_resp_prog_full),
    .i_fe_cxtmgt_resp_wr_en(w_fe_cxtmgt_resp_wr_en),
    .iv_fe_cxtmgt_resp_data(wv_fe_cxtmgt_resp_din),

    .o_fe_cxtmgt_cxt_download_prog_full(w_fe_cxtmgt_cxt_download_prog_full),
    .i_fe_cxtmgt_cxt_download_wr_en(w_fe_cxtmgt_cxt_download_wr_en),
    .iv_fe_cxtmgt_cxt_download_data(wv_fe_cxtmgt_cxt_download_din),

//Interface with VirtToPhys
    //Channel 1 for Doorbell Processing, only read
    .i_db_vtp_cmd_rd_en(w_db_vtp_cmd_rd_en),
    .o_db_vtp_cmd_empty(w_db_vtp_cmd_empty),
    .ov_db_vtp_cmd_data(wv_db_vtp_cmd_dout),

    .o_db_vtp_resp_prog_full(w_db_vtp_resp_prog_full),
    .i_db_vtp_resp_wr_en(w_db_vtp_resp_wr_en),
    .iv_db_vtp_resp_data(wv_db_vtp_resp_din),

    .o_db_vtp_download_prog_full(w_db_vtp_download_prog_full),
    .i_db_vtp_download_wr_en(w_db_vtp_download_wr_en),
    .iv_db_vtp_download_data(wv_db_vtp_download_din),
        
    //Channel 2 for WQEParser, download SQ WQE
    .i_wp_vtp_wqe_cmd_rd_en(w_wp_vtp_wqe_cmd_rd_en),
    .o_wp_vtp_wqe_cmd_empty(w_wp_vtp_wqe_cmd_empty),
    .ov_wp_vtp_wqe_cmd_data(wv_wp_vtp_wqe_cmd_dout),

    .o_wp_vtp_wqe_resp_prog_full(w_wp_vtp_wqe_resp_prog_full),
    .i_wp_vtp_wqe_resp_wr_en(w_wp_vtp_wqe_resp_wr_en),
    .iv_wp_vtp_wqe_resp_data(wv_wp_vtp_wqe_resp_din),

    .o_wp_vtp_wqe_download_prog_full(w_wp_vtp_wqe_download_prog_full),
    .i_wp_vtp_wqe_download_wr_en(w_wp_vtp_wqe_download_wr_en),
    .iv_wp_vtp_wqe_download_data(wv_wp_vtp_wqe_download_din),

    //Channel 3 for WQEParser, download network data
    .i_wp_vtp_nd_cmd_rd_en(w_wp_vtp_nd_cmd_rd_en),
    .o_wp_vtp_nd_cmd_empty(w_wp_vtp_nd_cmd_empty),
    .ov_wp_vtp_nd_cmd_data(wv_wp_vtp_nd_cmd_dout),

    .o_wp_vtp_nd_resp_prog_full(w_wp_vtp_nd_resp_prog_full),
    .i_wp_vtp_nd_resp_wr_en(w_wp_vtp_nd_resp_wr_en),
    .iv_wp_vtp_nd_resp_data(wv_wp_vtp_nd_resp_din),

    .o_wp_vtp_nd_download_prog_full(w_wp_vtp_nd_download_prog_full),
    .i_wp_vtp_nd_download_wr_en(w_wp_vtp_nd_download_wr_en),
    .iv_wp_vtp_nd_download_data(wv_wp_vtp_nd_download_din),

    //Channel 4 for RequesterTransControl, upload Completion Event
    .i_rtc_vtp_cmd_rd_en(w_rtc_vtp_cmd_rd_en),
    .o_rtc_vtp_cmd_empty(w_rtc_vtp_cmd_empty),
    .ov_rtc_vtp_cmd_data(wv_rtc_vtp_cmd_dout),

    .o_rtc_vtp_resp_prog_full(w_rtc_vtp_resp_prog_full),
    .i_rtc_vtp_resp_wr_en(w_rtc_vtp_resp_wr_en),
    .iv_rtc_vtp_resp_data(wv_rtc_vtp_resp_din),

    .i_rtc_vtp_upload_rd_en(w_rtc_vtp_upload_rd_en),
    .o_rtc_vtp_upload_empty(w_rtc_vtp_upload_empty),
    .ov_rtc_vtp_upload_data(wv_rtc_vtp_upload_dout),

    //Channel 5 for RequesterRecvControl, upload RDMA Read Response
    .i_rrc_vtp_cmd_rd_en(w_rrc_vtp_cmd_rd_en),
    .o_rrc_vtp_cmd_empty(w_rrc_vtp_cmd_empty),
    .ov_rrc_vtp_cmd_data(wv_rrc_vtp_cmd_dout),

    .o_rrc_vtp_resp_prog_full(w_rrc_vtp_resp_prog_full),
    .i_rrc_vtp_resp_wr_en(w_rrc_vtp_resp_wr_en),
    .iv_rrc_vtp_resp_data(wv_rrc_vtp_resp_din),

    .i_rrc_vtp_upload_rd_en(w_rrc_vtp_upload_rd_en),
    .o_rrc_vtp_upload_empty(w_rrc_vtp_upload_empty),
    .ov_rrc_vtp_upload_data(wv_rrc_vtp_upload_dout),

    //Channel 6 for ExecutionEngine, upload Send/Write Payload and download Read Payload
    .i_ee_vtp_cmd_rd_en(w_ee_vtp_cmd_rd_en),
    .o_ee_vtp_cmd_empty(w_ee_vtp_cmd_empty),
    .ov_ee_vtp_cmd_data(wv_ee_vtp_cmd_dout),

    .o_ee_vtp_resp_prog_full(w_ee_vtp_resp_prog_full),
    .i_ee_vtp_resp_wr_en(w_ee_vtp_resp_wr_en),
    .iv_ee_vtp_resp_data(wv_ee_vtp_resp_din),

    .i_ee_vtp_upload_rd_en(w_ee_vtp_upload_rd_en),
    .o_ee_vtp_upload_empty(w_ee_vtp_upload_empty),
    .ov_ee_vtp_upload_data(wv_ee_vtp_upload_dout),

    .i_ee_vtp_download_wr_en(w_ee_vtp_download_wr_en),
    .o_ee_vtp_download_prog_full(w_ee_vtp_download_prog_full),
    .iv_ee_vtp_download_data(wv_ee_vtp_download_din),

    //Channel 7 for ExecutionEngine, download RQ WQE
    .i_rwm_vtp_cmd_rd_en(w_rwm_vtp_cmd_rd_en),
    .o_rwm_vtp_cmd_empty(w_rwm_vtp_cmd_empty),
    .ov_rwm_vtp_cmd_data(wv_rwm_vtp_cmd_dout),

    .o_rwm_vtp_resp_prog_full(w_rwm_vtp_resp_prog_full),
    .i_rwm_vtp_resp_wr_en(w_rwm_vtp_resp_wr_en),
    .iv_rwm_vtp_resp_data(wv_rwm_vtp_resp_din),

    .i_rwm_vtp_download_wr_en(w_rwm_vtp_download_wr_en),
    .o_rwm_vtp_download_prog_full(w_rwm_vtp_download_prog_full),
    .iv_rwm_vtp_download_data(wv_rwm_vtp_download_din),

//LinkLayer
/*Interface with TX HPC Link, AXIS Interface*/
	/*interface to LinkLayer Tx  */
	.o_hpc_tx_valid(o_hpc_tx_valid),
	.o_hpc_tx_last(o_hpc_tx_last),
	.ov_hpc_tx_data(ov_hpc_tx_data),
	.ov_hpc_tx_keep(ov_hpc_tx_keep),
	.i_hpc_tx_ready(i_hpc_tx_ready),
	.o_hpc_tx_start(o_hpc_tx_start),
	.ov_hpc_tx_user(ov_hpc_tx_user),

/*Interface with RX HPC Link, AXIS Interface*/
	/*interface to LinkLayer Rx  */
	.i_hpc_rx_valid(i_hpc_rx_valid), 
	.i_hpc_rx_last(i_hpc_rx_last),
	.iv_hpc_rx_data(iv_hpc_rx_data),
	.iv_hpc_rx_keep(iv_hpc_rx_keep),
	.o_hpc_rx_ready(o_hpc_rx_ready),	
	.i_hpc_rx_start(i_hpc_rx_start),
	.iv_hpc_rx_user(iv_hpc_rx_user), 

/*Interface with Tx Eth Link, FIFO Interface*/
	.o_desc_empty(o_tx_desc_empty),
	.ov_desc_data(ov_tx_desc_data),
	.i_desc_rd_en(i_tx_desc_rd_en),

	.o_roce_egress_empty(o_roce_empty),
	.i_roce_egress_rd_en(i_roce_rd_en),
	.ov_roce_egress_data(ov_roce_data),

/*Interface with Rx Eth Link, FIFO Interface*/
	.o_roce_ingress_prog_full(o_roce_prog_full),
	.i_roce_ingress_wr_en(i_roce_wr_en),
	.iv_roce_ingress_data(iv_roce_data),

	.o_rdma_init_finish(w_rdmaengine_init_finish)
);

assign o_rdma_init_finish = w_rdmaengine_init_finish & w_cxtmgt_init_finish & w_v2p_init_finish;

endmodule
