/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ResMgtSubsystem
Author:     YangFan
Function:   Manage various communication resources, controlled by both Sotware(CPU) and Hardware(RDMACore).
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module ResMgtSubsystem
#(
    parameter   INGRESS_CXT_HEAD_WIDTH      =       128,
    parameter   INGRESS_CXT_DATA_WIDTH      =       256,
    parameter   EGRESS_CXT_HEAD_WIDTH       =       128,
    parameter   EGRESS_CXT_DATA_WIDTH       =       256,

    parameter   INGRESS_MR_HEAD_WIDTH       =       128,
    parameter   INGRESS_MR_DATA_WIDTH       =       256,
    parameter   EGRESS_MR_HEAD_WIDTH        =       128,
    parameter   EGRESS_MR_DATA_WIDTH        =       256
)
(
	input   wire                                                    clk,
    input   wire                                                    rst,

//Interface for CEU
	input 	wire 	[63:0]											ceu_hcr_in_param,
	input 	wire 	[31:0]											ceu_hcr_in_modifier,
	input 	wire 	[63:0]											ceu_hcr_out_dma_addr,
	input 	wire 	[31:0]											ceu_hcr_token,
	input 	wire 													ceu_hcr_go,
	input 	wire 													ceu_hcr_event,
	input 	wire 	[7:0]											ceu_hcr_op_modifier,
	input 	wire 	[11:0]											ceu_hcr_op,

	output 	wire 	[63:0]											ceu_hcr_out_param,
	output 	wire 	[7:0]											ceu_hcr_status,
	output 	wire 													ceu_hcr_clear,

	output 	wire 													CEU_dma_rd_req_valid,
	output 	wire 													CEU_dma_rd_req_last,
	output 	wire 	[`DMA_HEAD_WIDTH - 1 : 0]						CEU_dma_rd_req_head,
	output 	wire 	[`DMA_DATA_WIDTH - 1 : 0]						CEU_dma_rd_req_data,
	input 	wire 													CEU_dma_rd_req_ready,

	input 	wire 													CEU_dma_rd_rsp_valid,
	input 	wire 													CEU_dma_rd_rsp_last,
	input 	wire 	[`DMA_HEAD_WIDTH - 1 : 0]						CEU_dma_rd_rsp_head,
	input 	wire 	[`DMA_DATA_WIDTH - 1 : 0]						CEU_dma_rd_rsp_data,
	output 	wire 													CEU_dma_rd_rsp_ready,

	output 	wire 													CEU_dma_wr_req_valid,
	output 	wire 													CEU_dma_wr_req_last,
	output 	wire 	[`DMA_HEAD_WIDTH - 1 : 0]						CEU_dma_wr_req_head,
	output 	wire 	[`DMA_DATA_WIDTH - 1 : 0]						CEU_dma_wr_req_data,
	input 	wire 													CEU_dma_wr_req_ready,

    input   wire                                                    SQ_fetch_cxt_ingress_valid,
    input   wire    [`SQ_OOO_CXT_INGRESS_HEAD_WIDTH - 1 : 0]        SQ_fetch_cxt_ingress_head,
    input   wire    [`SQ_OOO_CXT_INGRESS_DATA_WIDTH - 1 : 0]        SQ_fetch_cxt_ingress_data,
    input   wire                                                    SQ_fetch_cxt_ingress_start,
    input   wire                                                    SQ_fetch_cxt_ingress_last,
    output  wire                                                    SQ_fetch_cxt_ingress_ready,

    output  wire                                                    SQ_fetch_cxt_egress_valid,
    output  wire    [`SQ_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]         SQ_fetch_cxt_egress_head,  
    output  wire    [`SQ_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]         SQ_fetch_cxt_egress_data,
    output  wire                                                    SQ_fetch_cxt_egress_start,
    output  wire                                                    SQ_fetch_cxt_egress_last,
    input   wire                                                    SQ_fetch_cxt_egress_ready,
 


    input   wire                                                    TX_REQ_fetch_cxt_ingress_valid,
    input   wire    [`TX_REQ_OOO_CXT_INGRESS_HEAD_WIDTH - 1 : 0]    TX_REQ_fetch_cxt_ingress_head,
    input   wire    [`TX_REQ_OOO_CXT_INGRESS_DATA_WIDTH - 1 : 0]    TX_REQ_fetch_cxt_ingress_data,
    input   wire                                                    TX_REQ_fetch_cxt_ingress_start,
    input   wire                                                    TX_REQ_fetch_cxt_ingress_last,
    output  wire                                                    TX_REQ_fetch_cxt_ingress_ready,

    output  wire                                                    TX_REQ_fetch_cxt_egress_valid,
    output  wire    [`TX_REQ_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]     TX_REQ_fetch_cxt_egress_head,
    output  wire    [`TX_REQ_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]     TX_REQ_fetch_cxt_egress_data,
    output  wire                                                    TX_REQ_fetch_cxt_egress_start,
    output  wire                                                    TX_REQ_fetch_cxt_egress_last,
    input   wire                                                    TX_REQ_fetch_cxt_egress_ready,

    input   wire                                                             RX_REQ_fetch_cxt_ingress_valid,
    input   wire    [`RX_REQ_OOO_CXT_INGRESS_HEAD_WIDTH - 1 : 0]            RX_REQ_fetch_cxt_ingress_head,
    input   wire    [`RX_REQ_OOO_CXT_INGRESS_DATA_WIDTH - 1 : 0]            RX_REQ_fetch_cxt_ingress_data,
    input   wire                                                             RX_REQ_fetch_cxt_ingress_start,
    input   wire                                                             RX_REQ_fetch_cxt_ingress_last,
    output  wire                                                             RX_REQ_fetch_cxt_ingress_ready,

    output  wire                                                             RX_REQ_fetch_cxt_egress_valid,
    output  wire    [`RX_REQ_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]             RX_REQ_fetch_cxt_egress_head,
    output  wire    [`RX_REQ_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]             RX_REQ_fetch_cxt_egress_data,
    output  wire                                                             RX_REQ_fetch_cxt_egress_start,
    output  wire                                                             RX_REQ_fetch_cxt_egress_last,
    input   wire                                                             RX_REQ_fetch_cxt_egress_ready,

    input   wire                                                           RX_RESP_fetch_cxt_ingress_valid,
    input   wire    [`RX_RESP_OOO_CXT_INGRESS_HEAD_WIDTH - 1 : 0]            RX_RESP_fetch_cxt_ingress_head,
    input   wire    [`RX_RESP_OOO_CXT_INGRESS_DATA_WIDTH - 1 : 0]            RX_RESP_fetch_cxt_ingress_data,
    input   wire                                                           RX_RESP_fetch_cxt_ingress_start,
    input   wire                                                           RX_RESP_fetch_cxt_ingress_last,
    output  wire                                                           RX_RESP_fetch_cxt_ingress_ready,

    output  wire                                                           RX_RESP_fetch_cxt_egress_valid,
    output  wire    [`RX_RESP_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]             RX_RESP_fetch_cxt_egress_head,
    output  wire    [`RX_RESP_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]             RX_RESP_fetch_cxt_egress_data,
    output  wire                                                           RX_RESP_fetch_cxt_egress_start,
    output  wire                                                           RX_RESP_fetch_cxt_egress_last,
    input   wire                                                           RX_RESP_fetch_cxt_egress_ready,

    input   wire                                                    SQ_fetch_mr_ingress_valid,
    input   wire    [`SQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]         SQ_fetch_mr_ingress_head, 
    input   wire    [`SQ_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]         SQ_fetch_mr_ingress_data,
    input   wire                                                    SQ_fetch_mr_ingress_start,
    input   wire                                                    SQ_fetch_mr_ingress_last,
    output  wire                                                    SQ_fetch_mr_ingress_ready,

    output  wire                                                    SQ_fetch_mr_egress_valid,
    output  wire    [`SQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]          SQ_fetch_mr_egress_head,
    output  wire    [`SQ_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]          SQ_fetch_mr_egress_data,
    output  wire                                                    SQ_fetch_mr_egress_start,
    output  wire                                                    SQ_fetch_mr_egress_last,
    input   wire                                                    SQ_fetch_mr_egress_ready,

    input   wire                                                    RQ_fetch_mr_ingress_valid,
    input   wire    [`RQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]         RQ_fetch_mr_ingress_head, 
    input   wire    [`RQ_OOO_MR_INGRESS_DATA_WIDTH  - 1 : 0]        RQ_fetch_mr_ingress_data,
    input   wire                                                    RQ_fetch_mr_ingress_start,
    input   wire                                                    RQ_fetch_mr_ingress_last,
    output  wire                                                    RQ_fetch_mr_ingress_ready,

    output  wire                                                    RQ_fetch_mr_egress_valid,
    output  wire    [`RQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]          RQ_fetch_mr_egress_head,
    output  wire    [`RQ_OOO_MR_EGRESS_DATA_WIDTH  - 1 : 0]         RQ_fetch_mr_egress_data,
    output  wire                                                    RQ_fetch_mr_egress_start,
    output  wire                                                    RQ_fetch_mr_egress_last,
    input   wire                                                    RQ_fetch_mr_egress_ready,

    input   wire                                                   TX_REQ_fetch_mr_ingress_valid,
    input   wire    [`TX_REQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]    TX_REQ_fetch_mr_ingress_head,
    input   wire    [`TX_REQ_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]    TX_REQ_fetch_mr_ingress_data,
    input   wire                                                   TX_REQ_fetch_mr_ingress_start,
    input   wire                                                   TX_REQ_fetch_mr_ingress_last,
    output  wire                                                   TX_REQ_fetch_mr_ingress_ready,

    output  wire                                                   TX_REQ_fetch_mr_egress_valid,
    output  wire    [`TX_REQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]     TX_REQ_fetch_mr_egress_head,
    output  wire    [`TX_REQ_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]     TX_REQ_fetch_mr_egress_data,
    output  wire                                                   TX_REQ_fetch_mr_egress_start,
    output  wire                                                   TX_REQ_fetch_mr_egress_last,
    input   wire                                                   TX_REQ_fetch_mr_egress_ready,

    input   wire                                                           RX_RESP_fetch_mr_ingress_valid,
    input   wire    [`RX_RESP_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]            RX_RESP_fetch_mr_ingress_head,
    input   wire    [`RX_RESP_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]            RX_RESP_fetch_mr_ingress_data,
    input   wire                                                           RX_RESP_fetch_mr_ingress_start,
    input   wire                                                           RX_RESP_fetch_mr_ingress_last,
    output  wire                                                           RX_RESP_fetch_mr_ingress_ready,

    output  wire                                                           RX_RESP_fetch_mr_egress_valid,
    output  wire    [`RX_RESP_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]             RX_RESP_fetch_mr_egress_head,
    output  wire    [`RX_RESP_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]             RX_RESP_fetch_mr_egress_data,
    output  wire                                                           RX_RESP_fetch_mr_egress_start,
    output  wire                                                           RX_RESP_fetch_mr_egress_last,
    input   wire                                                           RX_RESP_fetch_mr_egress_ready,

    input   wire                                                                RX_REQ_fetch_mr_ingress_valid,
    input   wire        [`RX_REQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]             RX_REQ_fetch_mr_ingress_head,
    input   wire        [`RX_REQ_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]             RX_REQ_fetch_mr_ingress_data,
    input   wire                                                                RX_REQ_fetch_mr_ingress_start,
    input   wire                                                                RX_REQ_fetch_mr_ingress_last,
    output  wire                                                                RX_REQ_fetch_mr_ingress_ready,

    output  wire                                                                RX_REQ_fetch_mr_egress_valid,
    output  wire        [`RX_REQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]              RX_REQ_fetch_mr_egress_head,
    output  wire        [`RX_REQ_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]              RX_REQ_fetch_mr_egress_data,
    output  wire                                                                RX_REQ_fetch_mr_egress_start,
    output  wire                                                                RX_REQ_fetch_mr_egress_last,
    input   wire                                                                RX_REQ_fetch_mr_egress_ready,

//Interface with DMA
    output  wire                                                 	QPC_dma_rd_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                    	QPC_dma_rd_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                    	QPC_dma_rd_req_data,
    output  wire                                                 	QPC_dma_rd_req_last,
    input   wire                                                 	QPC_dma_rd_req_ready,

    input   wire                                                 	QPC_dma_rd_rsp_valid,
    input   wire    [`DMA_HEAD_WIDTH - 1 : 0]                    	QPC_dma_rd_rsp_head,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                    	QPC_dma_rd_rsp_data,
    input   wire                                                 	QPC_dma_rd_rsp_last,
    output  wire                                                 	QPC_dma_rd_rsp_ready,

    output  wire                                                 	QPC_dma_wr_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                    	QPC_dma_wr_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                    	QPC_dma_wr_req_data,
    output  wire                                                 	QPC_dma_wr_req_last,
    input   wire                                                 	QPC_dma_wr_req_ready,

    output  wire                                                 	CQC_dma_rd_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                    	CQC_dma_rd_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                    	CQC_dma_rd_req_data,
    output  wire                                                 	CQC_dma_rd_req_last,
    input   wire                                                 	CQC_dma_rd_req_ready,

    input   wire                                                 	CQC_dma_rd_rsp_valid,
    input   wire    [`DMA_HEAD_WIDTH - 1 : 0]                    	CQC_dma_rd_rsp_head,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                    	CQC_dma_rd_rsp_data,
    input   wire                                                 	CQC_dma_rd_rsp_last,
    output  wire                                                 	CQC_dma_rd_rsp_ready,

    output  wire                                                 	CQC_dma_wr_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                    	CQC_dma_wr_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                    	CQC_dma_wr_req_data,
    output  wire                                                 	CQC_dma_wr_req_last,
    input   wire                                                 	CQC_dma_wr_req_ready,

    output  wire                                                 	EQC_dma_rd_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                    	EQC_dma_rd_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                    	EQC_dma_rd_req_data,
    output  wire                                                 	EQC_dma_rd_req_last,
    input   wire                                                 	EQC_dma_rd_req_ready,

    input   wire                                                 	EQC_dma_rd_rsp_valid,
    input   wire    [`DMA_HEAD_WIDTH - 1 : 0]                    	EQC_dma_rd_rsp_head,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                    	EQC_dma_rd_rsp_data,
    input   wire                                                 	EQC_dma_rd_rsp_last,
    output  wire                                                 	EQC_dma_rd_rsp_ready,

    output  wire                                                 	EQC_dma_wr_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                    	EQC_dma_wr_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                    	EQC_dma_wr_req_data,
    output  wire                                                 	EQC_dma_wr_req_last,
    input   wire                                                 	EQC_dma_wr_req_ready,

//Interface with DMA
    output  wire                                                 	MPT_dma_rd_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                    	MPT_dma_rd_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                    	MPT_dma_rd_req_data,
    output  wire                                                 	MPT_dma_rd_req_last,
    input   wire                                                 	MPT_dma_rd_req_ready,

    input   wire                                                 	MPT_dma_rd_rsp_valid,
    input   wire    [`DMA_HEAD_WIDTH - 1 : 0]                    	MPT_dma_rd_rsp_head,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                    	MPT_dma_rd_rsp_data,
    input   wire                                                 	MPT_dma_rd_rsp_last,
    output  wire                                                 	MPT_dma_rd_rsp_ready,

    output  wire                                                 	MPT_dma_wr_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                    	MPT_dma_wr_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                    	MPT_dma_wr_req_data,
    output  wire                                                 	MPT_dma_wr_req_last,
    input   wire                                                 	MPT_dma_wr_req_ready,

    output  wire                                                 	MTT_dma_rd_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                    	MTT_dma_rd_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                    	MTT_dma_rd_req_data,
    output  wire                                                 	MTT_dma_rd_req_last,
    input   wire                                                 	MTT_dma_rd_req_ready,

    input   wire                                                 	MTT_dma_rd_rsp_valid,
    input   wire    [`DMA_HEAD_WIDTH - 1 : 0]                    	MTT_dma_rd_rsp_head,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                    	MTT_dma_rd_rsp_data,
    input   wire                                                 	MTT_dma_rd_rsp_last,
    output  wire                                                 	MTT_dma_rd_rsp_ready,

    output  wire                                                 	MTT_dma_wr_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                    	MTT_dma_wr_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                    	MTT_dma_wr_req_data,
    output  wire                                                 	MTT_dma_wr_req_last,
    input   wire                                                 	MTT_dma_wr_req_ready
);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire 													ceu_cxt_req_valid;
wire 	[`CEU_CXT_HEAD_WIDTH - 1 : 0]					ceu_cxt_req_head;
wire 													ceu_cxt_req_last;
wire 	[`CEU_CXT_DATA_WIDTH - 1 : 0]					ceu_cxt_req_data;
wire 													ceu_cxt_req_ready;

wire 													ceu_cxt_rsp_valid;
wire 	[`CEU_CXT_HEAD_WIDTH - 1 : 0]					ceu_cxt_rsp_head;
wire 													ceu_cxt_rsp_last;
wire 	[`CEU_CXT_DATA_WIDTH - 1 : 0]					ceu_cxt_rsp_data;
wire 													ceu_cxt_rsp_ready;

wire 													ceu_mr_req_valid;
wire 	[`CEU_MR_HEAD_WIDTH - 1 : 0]					ceu_mr_req_head;
wire 													ceu_mr_req_last;
wire 	[`CEU_MR_DATA_WIDTH - 1 : 0]					ceu_mr_req_data;
wire 													ceu_mr_req_ready;

wire                                                    SQ_mr_req_valid;
wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                    SQ_mr_req_head;
wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                    SQ_mr_req_data;
wire                                                    SQ_mr_req_ready;

wire                                                    SQ_mr_rsp_valid;
wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                    SQ_mr_rsp_head;
wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                    SQ_mr_rsp_data;
wire                                                    SQ_mr_rsp_ready;

wire                                                    RQ_mr_req_valid;
wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                    RQ_mr_req_head;
wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                    RQ_mr_req_data;
wire                                                    RQ_mr_req_ready;

wire                                                    RQ_mr_rsp_valid;
wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                    RQ_mr_rsp_head;
wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                    RQ_mr_rsp_data;
wire                                                    RQ_mr_rsp_ready;

wire                                                    TX_REQ_mr_req_valid;
wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                    TX_REQ_mr_req_head;
wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                    TX_REQ_mr_req_data;
wire                                                    TX_REQ_mr_req_ready;

wire                                                    TX_REQ_mr_rsp_valid;
wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                    TX_REQ_mr_rsp_head;
wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                    TX_REQ_mr_rsp_data;
wire                                                    TX_REQ_mr_rsp_ready;

wire                                                    RX_REQ_mr_req_valid;
wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                    RX_REQ_mr_req_head;
wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                    RX_REQ_mr_req_data;
wire                                                    RX_REQ_mr_req_ready;

wire                                                    RX_REQ_mr_rsp_valid;
wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                    RX_REQ_mr_rsp_head;
wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                    RX_REQ_mr_rsp_data;
wire                                                    RX_REQ_mr_rsp_ready;

wire                                                    RX_RESP_mr_req_valid;
wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                    RX_RESP_mr_req_head;
wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                    RX_RESP_mr_req_data;
wire                                                    RX_RESP_mr_req_ready;

wire                                                    RX_RESP_mr_rsp_valid;
wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                    RX_RESP_mr_rsp_head;
wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                    RX_RESP_mr_rsp_data;
wire                                                    RX_RESP_mr_rsp_ready;

wire                                                    SQ_cxt_req_valid;
wire    [`CXT_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                   SQ_cxt_req_head;
wire    [`CXT_CMD_DATA_WIDTH - 1 : 0]                   SQ_cxt_req_data;
wire                                                    SQ_cxt_req_ready;

wire                                                    SQ_cxt_rsp_valid;
wire    [`CXT_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                  SQ_cxt_rsp_head;
wire    [`CXT_RESP_DATA_WIDTH - 1 : 0]                  SQ_cxt_rsp_data;
wire                                                    SQ_cxt_rsp_ready;

wire                                                    TX_REQ_cxt_req_valid;
wire    [`CXT_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                   TX_REQ_cxt_req_head;
wire    [`CXT_CMD_DATA_WIDTH - 1 : 0]                   TX_REQ_cxt_req_data;
wire                                                    TX_REQ_cxt_req_ready;

wire                                                    TX_REQ_cxt_rsp_valid;
wire    [`CXT_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                  TX_REQ_cxt_rsp_head;
wire    [`CXT_RESP_DATA_WIDTH - 1 : 0]                  TX_REQ_cxt_rsp_data;
wire                                                    TX_REQ_cxt_rsp_ready;

wire                                                    RX_REQ_cxt_req_valid;
wire    [`CXT_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                   RX_REQ_cxt_req_head;
wire    [`CXT_CMD_DATA_WIDTH - 1 : 0]                   RX_REQ_cxt_req_data;
wire                                                    RX_REQ_cxt_req_ready;

wire                                                    RX_REQ_cxt_rsp_valid;
wire    [`CXT_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                  RX_REQ_cxt_rsp_head;
wire    [`CXT_RESP_DATA_WIDTH - 1 : 0]                  RX_REQ_cxt_rsp_data;
wire                                                    RX_REQ_cxt_rsp_ready;

wire                                                    RX_RESP_cxt_req_valid;
wire    [`CXT_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                   RX_RESP_cxt_req_head;
wire    [`CXT_CMD_DATA_WIDTH - 1 : 0]                   RX_RESP_cxt_req_data;
wire                                                    RX_RESP_cxt_req_ready;

wire                                                    RX_RESP_cxt_rsp_valid;
wire    [`CXT_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                  RX_RESP_cxt_rsp_head;
wire    [`CXT_RESP_DATA_WIDTH - 1 : 0]                  RX_RESP_cxt_rsp_data;
wire                                                    RX_RESP_cxt_rsp_ready;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : End : Begin ---------------------------------*/
CEU CEU_Inst(
	.clk						(	clk						),
	.rst_n						(	!rst					),

	.hcr_in_param				(	ceu_hcr_in_param		),
	.hcr_in_modifier			(	ceu_hcr_in_modifier		),
	.hcr_out_dma_addr			(	ceu_hcr_out_dma_addr	),
	.hcr_token					(	ceu_hcr_token			),
	.hcr_go						(	ceu_hcr_go				),
	.hcr_event					(	ceu_hcr_event			),
	.hcr_op_modifier			(	ceu_hcr_op_modifier		),
	.hcr_op						(	ceu_hcr_op				),

	.hcr_out_param				(	ceu_hcr_out_param	    ),
	.hcr_status					(	ceu_hcr_status		    ),
	.hcr_clear					(	ceu_hcr_clear		    ),
	
	.dma_rd_req_valid			(	CEU_dma_rd_req_valid	),
	.dma_rd_req_last			(	CEU_dma_rd_req_last		),
	.dma_rd_req_head			(	CEU_dma_rd_req_head		),
	.dma_rd_req_data			(	CEU_dma_rd_req_data		),
	.dma_rd_req_ready			(	CEU_dma_rd_req_ready	),
	
	.dma_rd_rsp_valid			(	CEU_dma_rd_rsp_valid	),
	.dma_rd_rsp_last			(	CEU_dma_rd_rsp_last		),
	.dma_rd_rsp_head			(	CEU_dma_rd_rsp_head		),
	.dma_rd_rsp_data			(	CEU_dma_rd_rsp_data		),
	.dma_rd_rsp_ready			(	CEU_dma_rd_rsp_ready	),
	
	.dma_wr_req_valid			(	CEU_dma_wr_req_valid	),
	.dma_wr_req_last			(	CEU_dma_wr_req_last		),
	.dma_wr_req_head			(	CEU_dma_wr_req_head		),
	.dma_wr_req_data			(	CEU_dma_wr_req_data		),
	.dma_wr_req_ready			(	CEU_dma_wr_req_ready	),

    .cm_req_valid               (   ceu_cxt_req_valid       ),
    .cm_req_last                (   ceu_cxt_req_last        ),
    .cm_req_head                (   ceu_cxt_req_head        ),
    .cm_req_data                (   ceu_cxt_req_data        ),
    .cm_req_ready               (   ceu_cxt_req_ready       ),
        
    .cm_rsp_valid               (   ceu_cxt_rsp_valid       ),
    .cm_rsp_last                (   ceu_cxt_rsp_last        ),
    .cm_rsp_head                (   ceu_cxt_rsp_head        ),
    .cm_rsp_data                (   ceu_cxt_rsp_data        ),
    .cm_rsp_ready               (   ceu_cxt_rsp_ready       ),
        
    .v2p_req_valid              (   ceu_mr_req_valid        ),
    .v2p_req_last               (   ceu_mr_req_last         ),
    .v2p_req_head               (   ceu_mr_req_head         ),
    .v2p_req_data               (   ceu_mr_req_data         ),
    .v2p_req_ready              (   ceu_mr_req_ready        )
);

ICMMgt ICMMgt_Inst(
	.clk								(			clk								),
	.rst								(			rst								),

    .ceu_cxt_req_valid					(			ceu_cxt_req_valid				),
    .ceu_cxt_req_head					(			ceu_cxt_req_head				),
    .ceu_cxt_req_last					(			ceu_cxt_req_last				),
    .ceu_cxt_req_data					(			ceu_cxt_req_data				),
    .ceu_cxt_req_ready					(			ceu_cxt_req_ready				),

    .ceu_cxt_rsp_valid					(			ceu_cxt_rsp_valid				),
    .ceu_cxt_rsp_head					(			ceu_cxt_rsp_head				),
    .ceu_cxt_rsp_last					(			ceu_cxt_rsp_last				),
    .ceu_cxt_rsp_data					(			ceu_cxt_rsp_data				),
    .ceu_cxt_rsp_ready					(			ceu_cxt_rsp_ready				),

    .SQ_cxt_req_valid				(			SQ_cxt_req_valid			),
    .SQ_cxt_req_head				(			SQ_cxt_req_head				),
    .SQ_cxt_req_data				(			SQ_cxt_req_data				),
    .SQ_cxt_req_ready				(			SQ_cxt_req_ready			),

    .TX_REQ_cxt_req_valid			(			TX_REQ_cxt_req_valid		),
    .TX_REQ_cxt_req_head			(			TX_REQ_cxt_req_head			),
    .TX_REQ_cxt_req_data			(			TX_REQ_cxt_req_data			),
    .TX_REQ_cxt_req_ready			(			TX_REQ_cxt_req_ready		),

    .RX_REQ_cxt_req_valid			(			RX_REQ_cxt_req_valid		),
    .RX_REQ_cxt_req_head			(			RX_REQ_cxt_req_head			),
    .RX_REQ_cxt_req_data			(			RX_REQ_cxt_req_data			),
    .RX_REQ_cxt_req_ready			(			RX_REQ_cxt_req_ready		),

    .RX_RESP_cxt_req_valid			(			RX_RESP_cxt_req_valid		),
    .RX_RESP_cxt_req_head			(			RX_RESP_cxt_req_head		),
    .RX_RESP_cxt_req_data			(			RX_RESP_cxt_req_data		),
    .RX_RESP_cxt_req_ready			(			RX_RESP_cxt_req_ready		),

    .SQ_cxt_rsp_valid               (           SQ_cxt_rsp_valid            ),
    .SQ_cxt_rsp_head                (           SQ_cxt_rsp_head             ),
    .SQ_cxt_rsp_data                (           SQ_cxt_rsp_data             ),
    .SQ_cxt_rsp_ready               (           SQ_cxt_rsp_ready            ),

    .TX_REQ_cxt_rsp_valid           (           TX_REQ_cxt_rsp_valid        ),
    .TX_REQ_cxt_rsp_head            (           TX_REQ_cxt_rsp_head         ),
    .TX_REQ_cxt_rsp_data            (           TX_REQ_cxt_rsp_data         ),
    .TX_REQ_cxt_rsp_ready           (           TX_REQ_cxt_rsp_ready        ),

    .RX_REQ_cxt_rsp_valid           (           RX_REQ_cxt_rsp_valid        ),
    .RX_REQ_cxt_rsp_head            (           RX_REQ_cxt_rsp_head         ),
    .RX_REQ_cxt_rsp_data            (           RX_REQ_cxt_rsp_data         ),
    .RX_REQ_cxt_rsp_ready           (           RX_REQ_cxt_rsp_ready        ),

    .RX_RESP_cxt_rsp_valid          (           RX_RESP_cxt_rsp_valid       ),
    .RX_RESP_cxt_rsp_head           (           RX_RESP_cxt_rsp_head        ),
    .RX_RESP_cxt_rsp_data           (           RX_RESP_cxt_rsp_data        ),
    .RX_RESP_cxt_rsp_ready          (           RX_RESP_cxt_rsp_ready       ),

    .qpc_dma_rd_req_valid				(			QPC_dma_rd_req_valid			),
    .qpc_dma_rd_req_head				(			QPC_dma_rd_req_head				),
    .qpc_dma_rd_req_data				(			QPC_dma_rd_req_data				),
    .qpc_dma_rd_req_last				(			QPC_dma_rd_req_last				),
    .qpc_dma_rd_req_ready				(			QPC_dma_rd_req_ready			),

    .qpc_dma_rd_rsp_valid				(			QPC_dma_rd_rsp_valid			),
    .qpc_dma_rd_rsp_head				(			QPC_dma_rd_rsp_head				),
    .qpc_dma_rd_rsp_data				(			QPC_dma_rd_rsp_data				),
    .qpc_dma_rd_rsp_last				(			QPC_dma_rd_rsp_last				),
    .qpc_dma_rd_rsp_ready				(			QPC_dma_rd_rsp_ready			),

    .qpc_dma_wr_req_valid				(			QPC_dma_wr_req_valid			),
    .qpc_dma_wr_req_head				(			QPC_dma_wr_req_head				),
    .qpc_dma_wr_req_data				(			QPC_dma_wr_req_data				),
    .qpc_dma_wr_req_last				(			QPC_dma_wr_req_last				),
    .qpc_dma_wr_req_ready				(			QPC_dma_wr_req_ready			),

    .cqc_dma_rd_req_valid				(			CQC_dma_rd_req_valid			),
    .cqc_dma_rd_req_head				(			CQC_dma_rd_req_head				),
    .cqc_dma_rd_req_data				(			CQC_dma_rd_req_data				),
    .cqc_dma_rd_req_last				(			CQC_dma_rd_req_last				),
    .cqc_dma_rd_req_ready				(			CQC_dma_rd_req_ready			),

    .cqc_dma_rd_rsp_valid				(			CQC_dma_rd_rsp_valid			),
    .cqc_dma_rd_rsp_head				(			CQC_dma_rd_rsp_head				),
    .cqc_dma_rd_rsp_data				(			CQC_dma_rd_rsp_data				),
    .cqc_dma_rd_rsp_last				(			CQC_dma_rd_rsp_last				),
    .cqc_dma_rd_rsp_ready				(			CQC_dma_rd_rsp_ready			),

    .cqc_dma_wr_req_valid				(			CQC_dma_wr_req_valid			),
    .cqc_dma_wr_req_head				(			CQC_dma_wr_req_head				),
    .cqc_dma_wr_req_data				(			CQC_dma_wr_req_data				),
    .cqc_dma_wr_req_last				(			CQC_dma_wr_req_last				),
    .cqc_dma_wr_req_ready				(			CQC_dma_wr_req_ready			),

    .eqc_dma_rd_req_valid				(			EQC_dma_rd_req_valid			),
    .eqc_dma_rd_req_head				(			EQC_dma_rd_req_head				),
    .eqc_dma_rd_req_data				(			EQC_dma_rd_req_data				),
    .eqc_dma_rd_req_last				(			EQC_dma_rd_req_last				),
    .eqc_dma_rd_req_ready				(			EQC_dma_rd_req_ready			),

    .eqc_dma_rd_rsp_valid				(			EQC_dma_rd_rsp_valid			),
    .eqc_dma_rd_rsp_head				(			EQC_dma_rd_rsp_head				),
    .eqc_dma_rd_rsp_data				(			EQC_dma_rd_rsp_data				),
    .eqc_dma_rd_rsp_last				(			EQC_dma_rd_rsp_last				),
    .eqc_dma_rd_rsp_ready				(			EQC_dma_rd_rsp_ready			),

    .eqc_dma_wr_req_valid				(			EQC_dma_wr_req_valid			),
    .eqc_dma_wr_req_head				(			EQC_dma_wr_req_head				),
    .eqc_dma_wr_req_data				(			EQC_dma_wr_req_data				),
    .eqc_dma_wr_req_last				(			EQC_dma_wr_req_last				),
    .eqc_dma_wr_req_ready				(			EQC_dma_wr_req_ready			),

    .ceu_mr_req_valid					(			ceu_mr_req_valid				),
    .ceu_mr_req_head					(			ceu_mr_req_head					),
    .ceu_mr_req_last					(			ceu_mr_req_last					),
    .ceu_mr_req_data					(			ceu_mr_req_data					),
    .ceu_mr_req_ready					(			ceu_mr_req_ready				),

    .SQ_mr_req_valid			         (			SQ_mr_req_valid			),
    .SQ_mr_req_head				         (			SQ_mr_req_head			),
    .SQ_mr_req_data				         (			SQ_mr_req_data			),
    .SQ_mr_req_ready			         (			SQ_mr_req_ready			),

    .SQ_mr_rsp_valid			     (			SQ_mr_rsp_valid			),
    .SQ_mr_rsp_head				     (			SQ_mr_rsp_head			),
    .SQ_mr_rsp_data				     (			SQ_mr_rsp_data			),
    .SQ_mr_rsp_ready			     (			SQ_mr_rsp_ready			),

    .RQ_mr_req_valid			     (			RQ_mr_req_valid			),
    .RQ_mr_req_head				     (			RQ_mr_req_head			),
    .RQ_mr_req_data				     (			RQ_mr_req_data			),
    .RQ_mr_req_ready			     (			RQ_mr_req_ready			),

    .RQ_mr_rsp_valid			     (			RQ_mr_rsp_valid			),
    .RQ_mr_rsp_head				     (			RQ_mr_rsp_head			),
    .RQ_mr_rsp_data				     (			RQ_mr_rsp_data			),
    .RQ_mr_rsp_ready			     (			RQ_mr_rsp_ready			),

    .TX_REQ_mr_req_valid			(			TX_REQ_mr_req_valid			),
    .TX_REQ_mr_req_head				(			TX_REQ_mr_req_head			),
    .TX_REQ_mr_req_data				(			TX_REQ_mr_req_data			),
    .TX_REQ_mr_req_ready			(			TX_REQ_mr_req_ready			),

    .TX_REQ_mr_rsp_valid			(			TX_REQ_mr_rsp_valid			),
    .TX_REQ_mr_rsp_head				(			TX_REQ_mr_rsp_head			),
    .TX_REQ_mr_rsp_data				(			TX_REQ_mr_rsp_data			),
    .TX_REQ_mr_rsp_ready			(			TX_REQ_mr_rsp_ready			),

    .RX_REQ_mr_req_valid			(			RX_REQ_mr_req_valid			),
    .RX_REQ_mr_req_head				(			RX_REQ_mr_req_head			),
    .RX_REQ_mr_req_data				(			RX_REQ_mr_req_data			),
    .RX_REQ_mr_req_ready			(			RX_REQ_mr_req_ready			),

    .RX_REQ_mr_rsp_valid			(			RX_REQ_mr_rsp_valid			),
    .RX_REQ_mr_rsp_head				(			RX_REQ_mr_rsp_head			),
    .RX_REQ_mr_rsp_data				(			RX_REQ_mr_rsp_data			),
    .RX_REQ_mr_rsp_ready			(			RX_REQ_mr_rsp_ready			),

	.RX_RESP_mr_req_valid			(			RX_RESP_mr_req_valid		),
    .RX_RESP_mr_req_head			(			RX_RESP_mr_req_head			),
    .RX_RESP_mr_req_data			(			RX_RESP_mr_req_data			),
    .RX_RESP_mr_req_ready			(			RX_RESP_mr_req_ready		),

    .RX_RESP_mr_rsp_valid			(			RX_RESP_mr_rsp_valid		),
    .RX_RESP_mr_rsp_head			(			RX_RESP_mr_rsp_head			),
    .RX_RESP_mr_rsp_data			(			RX_RESP_mr_rsp_data			),
    .RX_RESP_mr_rsp_ready			(			RX_RESP_mr_rsp_ready		),

    .mpt_dma_rd_req_valid				(			MPT_dma_rd_req_valid			),
    .mpt_dma_rd_req_head				(			MPT_dma_rd_req_head				),
    .mpt_dma_rd_req_data				(			MPT_dma_rd_req_data				),
    .mpt_dma_rd_req_last				(			MPT_dma_rd_req_last				),
    .mpt_dma_rd_req_ready				(			MPT_dma_rd_req_ready			),

    .mpt_dma_rd_rsp_valid				(			MPT_dma_rd_rsp_valid			),
    .mpt_dma_rd_rsp_head				(			MPT_dma_rd_rsp_head				),
    .mpt_dma_rd_rsp_data				(			MPT_dma_rd_rsp_data				),
    .mpt_dma_rd_rsp_last				(			MPT_dma_rd_rsp_last				),
    .mpt_dma_rd_rsp_ready				(			MPT_dma_rd_rsp_ready			),

    .mpt_dma_wr_req_valid				(			MPT_dma_wr_req_valid			),
    .mpt_dma_wr_req_head				(			MPT_dma_wr_req_head				),
    .mpt_dma_wr_req_data				(			MPT_dma_wr_req_data				),
    .mpt_dma_wr_req_last				(			MPT_dma_wr_req_last				),
    .mpt_dma_wr_req_ready				(			MPT_dma_wr_req_ready			),

    .mtt_dma_rd_req_valid				(			MTT_dma_rd_req_valid			),
    .mtt_dma_rd_req_head				(			MTT_dma_rd_req_head				),
    .mtt_dma_rd_req_data				(			MTT_dma_rd_req_data				),
    .mtt_dma_rd_req_last				(			MTT_dma_rd_req_last				),
    .mtt_dma_rd_req_ready				(			MTT_dma_rd_req_ready			),

    .mtt_dma_rd_rsp_valid				(			MTT_dma_rd_rsp_valid			),
    .mtt_dma_rd_rsp_head				(			MTT_dma_rd_rsp_head				),
    .mtt_dma_rd_rsp_data				(			MTT_dma_rd_rsp_data				),
    .mtt_dma_rd_rsp_last				(			MTT_dma_rd_rsp_last				),
    .mtt_dma_rd_rsp_ready				(			MTT_dma_rd_rsp_ready			),

    .mtt_dma_wr_req_valid				(			MTT_dma_wr_req_valid			),
    .mtt_dma_wr_req_head				(			MTT_dma_wr_req_head				),
    .mtt_dma_wr_req_data				(			MTT_dma_wr_req_data				),
    .mtt_dma_wr_req_last				(			MTT_dma_wr_req_last				),
    .mtt_dma_wr_req_ready				(			MTT_dma_wr_req_ready			)
);

OoOStation 
 #(

 	.ID                         (  1                              ),
    
    .TAG_NUM                            (           `REQ_TAG_NUM            ),

    .RESOURCE_CMD_HEAD_WIDTH            (           `CXT_CMD_HEAD_WIDTH             ),
    .RESOURCE_CMD_DATA_WIDTH            (           `CXT_CMD_DATA_WIDTH             ),
    .RESOURCE_RESP_HEAD_WIDTH           (           `CXT_RESP_HEAD_WIDTH            ), 
    .RESOURCE_RESP_DATA_WIDTH           (           `CXT_RESP_DATA_WIDTH            ),

    .SLOT_NUM                           (           `SQ_OOO_SLOT_NUM                ),
    .QUEUE_NUM                          (           `QP_NUM                         ),       

    .INGRESS_HEAD_WIDTH                 (           `SQ_OOO_CXT_INGRESS_HEAD_WIDTH  ),
    .INGRESS_DATA_WIDTH                 (           `SQ_OOO_CXT_INGRESS_DATA_WIDTH  ),

    .EGRESS_HEAD_WIDTH                  (           `SQ_OOO_CXT_EGRESS_HEAD_WIDTH   ),
    .EGRESS_DATA_WIDTH                  (           `SQ_OOO_CXT_EGRESS_DATA_WIDTH   )
)
SQ_Cxt_OoO_Inst(
    .clk                                (           clk                             ),
    .rst                                (           rst                             ),

    .ingress_valid                      (           SQ_fetch_cxt_ingress_valid      ),
    .ingress_head                       (           SQ_fetch_cxt_ingress_head       ),
    .ingress_data                       (           SQ_fetch_cxt_ingress_data       ),
    .ingress_start                      (           SQ_fetch_cxt_ingress_start      ),
    .ingress_last                       (           SQ_fetch_cxt_ingress_last       ),
    .ingress_ready                      (           SQ_fetch_cxt_ingress_ready      ),

    .available_slot_num                 (),

    .resource_req_valid                 (			SQ_cxt_req_valid                 ),
    .resource_req_head                  (			SQ_cxt_req_head                  ),
    .resource_req_data                  (			SQ_cxt_req_data                  ),
    .resource_req_start                 (			SQ_cxt_req_start                 ),
    .resource_req_last                  (			SQ_cxt_req_last                  ),
    .resource_req_ready                 (			SQ_cxt_req_ready                 ),

    .resource_resp_valid                (			SQ_cxt_rsp_valid                ),
    .resource_resp_head                 (			SQ_cxt_rsp_head                 ),
    .resource_resp_data                 (			SQ_cxt_rsp_data                 ),
    .resource_resp_start                (			SQ_cxt_rsp_valid                ),
    .resource_resp_last                 (			SQ_cxt_rsp_valid                ),
    .resource_resp_ready                (			SQ_cxt_rsp_ready                ),

    .egress_valid                       (           SQ_fetch_cxt_egress_valid      ),
    .egress_head                        (           SQ_fetch_cxt_egress_head       ),
    .egress_data                        (           SQ_fetch_cxt_egress_data       ),
    .egress_start                       (           SQ_fetch_cxt_egress_start      ),
    .egress_last                        (           SQ_fetch_cxt_egress_last       ),
    .egress_ready                       (           SQ_fetch_cxt_egress_ready      )
);

OoOStation 
 #(
     	.ID                         ( 2                              ),
    .TAG_NUM                            (           `REQ_TAG_NUM            ),

    .RESOURCE_CMD_HEAD_WIDTH            (           `CXT_CMD_HEAD_WIDTH             ),
    .RESOURCE_CMD_DATA_WIDTH            (           `CXT_CMD_DATA_WIDTH             ),
    .RESOURCE_RESP_HEAD_WIDTH           (           `CXT_RESP_HEAD_WIDTH            ), 
    .RESOURCE_RESP_DATA_WIDTH           (           `CXT_RESP_DATA_WIDTH            ),

    .SLOT_NUM                           (           `TX_REQ_OOO_SLOT_NUM                ),
    .QUEUE_NUM                          (           `QP_NUM                             ),       

    .INGRESS_HEAD_WIDTH                 (           `TX_REQ_OOO_CXT_INGRESS_HEAD_WIDTH  ),
    .INGRESS_DATA_WIDTH                 (           `TX_REQ_OOO_CXT_INGRESS_DATA_WIDTH  ),

    .EGRESS_HEAD_WIDTH                  (           `TX_REQ_OOO_CXT_EGRESS_HEAD_WIDTH   ),
    .EGRESS_DATA_WIDTH                  (           `TX_REQ_OOO_CXT_EGRESS_DATA_WIDTH   )
)
TX_REQ_Cxt_OoO_Inst(
    .clk                                (           clk                                 ),
    .rst                                (           rst                                 ),

    .ingress_valid                      (           TX_REQ_fetch_cxt_ingress_valid     	),
    .ingress_head                       (           TX_REQ_fetch_cxt_ingress_head      	),
    .ingress_data                       (           TX_REQ_fetch_cxt_ingress_data      	),
    .ingress_start                      (           TX_REQ_fetch_cxt_ingress_start     	),
    .ingress_last                       (           TX_REQ_fetch_cxt_ingress_last      	),
    .ingress_ready                      (           TX_REQ_fetch_cxt_ingress_ready     	),

    .available_slot_num                 (),

    .resource_req_valid                 (			TX_REQ_cxt_req_valid                	),
    .resource_req_head                  (			TX_REQ_cxt_req_head                 	),
    .resource_req_data                  (			TX_REQ_cxt_req_data                 	),
    .resource_req_start                 (			TX_REQ_cxt_req_start                	),
    .resource_req_last                  (			TX_REQ_cxt_req_last                 	),
    .resource_req_ready                 (			TX_REQ_cxt_req_ready                	),

    .resource_resp_valid                (			TX_REQ_cxt_rsp_valid               	),
    .resource_resp_head                 (			TX_REQ_cxt_rsp_head                	),
    .resource_resp_data                 (			TX_REQ_cxt_rsp_data                	),
    .resource_resp_start                (			TX_REQ_cxt_rsp_valid             ),
    .resource_resp_last                 (			TX_REQ_cxt_rsp_valid             ),
    .resource_resp_ready                (			TX_REQ_cxt_rsp_ready               	),

    .egress_valid                       (           TX_REQ_fetch_cxt_egress_valid     	),
    .egress_head                        (           TX_REQ_fetch_cxt_egress_head      	),
    .egress_data                        (           TX_REQ_fetch_cxt_egress_data      	),
    .egress_start                       (           TX_REQ_fetch_cxt_egress_start     	),
    .egress_last                        (           TX_REQ_fetch_cxt_egress_last      	),
    .egress_ready                       (           TX_REQ_fetch_cxt_egress_ready    	 )
);

OoOStation 
 #(
     	.ID                         (  3                             ),
    .TAG_NUM                            (           `REQ_TAG_NUM            ),

    .RESOURCE_CMD_HEAD_WIDTH            (           `CXT_CMD_HEAD_WIDTH             ),
    .RESOURCE_CMD_DATA_WIDTH            (           `CXT_CMD_DATA_WIDTH             ),
    .RESOURCE_RESP_HEAD_WIDTH           (           `CXT_RESP_HEAD_WIDTH            ), 
    .RESOURCE_RESP_DATA_WIDTH           (           `CXT_RESP_DATA_WIDTH            ),

    .SLOT_NUM                           (           `RX_REQ_OOO_SLOT_NUM                ),
    .QUEUE_NUM                          (           `QP_NUM                             ),       

    .INGRESS_HEAD_WIDTH                 (           `RX_REQ_OOO_CXT_INGRESS_HEAD_WIDTH  ),
    .INGRESS_DATA_WIDTH                 (           `RX_REQ_OOO_CXT_INGRESS_DATA_WIDTH  ),

    .EGRESS_HEAD_WIDTH                  (           `RX_REQ_OOO_CXT_EGRESS_HEAD_WIDTH   ),
    .EGRESS_DATA_WIDTH                  (           `RX_REQ_OOO_CXT_EGRESS_DATA_WIDTH   )
)
RX_REQ_Cxt_OoO_Inst(
    .clk                                (           clk                             ),
    .rst                                (           rst                             ),

    .ingress_valid                      (           RX_REQ_fetch_cxt_ingress_valid     	),
    .ingress_head                       (           RX_REQ_fetch_cxt_ingress_head      	),
    .ingress_data                       (           RX_REQ_fetch_cxt_ingress_data      	),
    .ingress_start                      (           RX_REQ_fetch_cxt_ingress_start     	),
    .ingress_last                       (           RX_REQ_fetch_cxt_ingress_last      	),
    .ingress_ready                      (           RX_REQ_fetch_cxt_ingress_ready     	),

    .available_slot_num                 (),

    .resource_req_valid                 (			RX_REQ_cxt_req_valid                	),
    .resource_req_head                  (			RX_REQ_cxt_req_head                 	),
    .resource_req_data                  (			RX_REQ_cxt_req_data                 	),
    .resource_req_start                 (			RX_REQ_cxt_req_start                	),
    .resource_req_last                  (			RX_REQ_cxt_req_last                 	),
    .resource_req_ready                 (			RX_REQ_cxt_req_ready                	),

    .resource_resp_valid                (			RX_REQ_cxt_rsp_valid               	),
    .resource_resp_head                 (			RX_REQ_cxt_rsp_head                	),
    .resource_resp_data                 (			RX_REQ_cxt_rsp_data                	),
    .resource_resp_start                (			RX_REQ_cxt_rsp_valid              ),
    .resource_resp_last                 (			RX_REQ_cxt_rsp_valid              ),
    .resource_resp_ready                (			RX_REQ_cxt_rsp_ready               	),

    .egress_valid                       (           RX_REQ_fetch_cxt_egress_valid     		),
    .egress_head                        (           RX_REQ_fetch_cxt_egress_head      		),
    .egress_data                        (           RX_REQ_fetch_cxt_egress_data      		),
    .egress_start                       (           RX_REQ_fetch_cxt_egress_start     		),
    .egress_last                        (           RX_REQ_fetch_cxt_egress_last      		),
    .egress_ready                       (           RX_REQ_fetch_cxt_egress_ready    		)
);

OoOStation 
 #(
     	.ID                         (  4                              ),
    .TAG_NUM                            (           `REQ_TAG_NUM            ),

    .RESOURCE_CMD_HEAD_WIDTH            (           `CXT_CMD_HEAD_WIDTH             ),
    .RESOURCE_CMD_DATA_WIDTH            (           `CXT_CMD_DATA_WIDTH             ),
    .RESOURCE_RESP_HEAD_WIDTH           (           `CXT_RESP_HEAD_WIDTH            ), 
    .RESOURCE_RESP_DATA_WIDTH           (           `CXT_RESP_DATA_WIDTH            ),

    .SLOT_NUM                           (           `RX_RESP_OOO_SLOT_NUM                ),
    .QUEUE_NUM                          (           `QP_NUM                         ),       

    .INGRESS_HEAD_WIDTH                 (           `RX_RESP_OOO_CXT_INGRESS_HEAD_WIDTH  ),
    .INGRESS_DATA_WIDTH                 (           `RX_RESP_OOO_CXT_INGRESS_DATA_WIDTH  ),

    .EGRESS_HEAD_WIDTH                  (           `RX_RESP_OOO_CXT_EGRESS_HEAD_WIDTH   ),
    .EGRESS_DATA_WIDTH                  (           `RX_RESP_OOO_CXT_EGRESS_DATA_WIDTH   )
)
RX_RESP_Cxt_OoO_Inst(
    .clk                                (           clk                             ),
    .rst                                (           rst                             ),

    .ingress_valid                      (           RX_RESP_fetch_cxt_ingress_valid     	),
    .ingress_head                       (           RX_RESP_fetch_cxt_ingress_head      	),
    .ingress_data                       (           RX_RESP_fetch_cxt_ingress_data      	),
    .ingress_start                      (           RX_RESP_fetch_cxt_ingress_start     	),
    .ingress_last                       (           RX_RESP_fetch_cxt_ingress_last      	),
    .ingress_ready                      (           RX_RESP_fetch_cxt_ingress_ready     	),

    .available_slot_num                 (),

    .resource_req_valid                 (			RX_RESP_cxt_req_valid                	),
    .resource_req_head                  (			RX_RESP_cxt_req_head                 	),
    .resource_req_data                  (			RX_RESP_cxt_req_data                 	),
    .resource_req_start                 (			RX_RESP_cxt_req_start                	),
    .resource_req_last                  (			RX_RESP_cxt_req_last                 	),
    .resource_req_ready                 (			RX_RESP_cxt_req_ready                	),

    .resource_resp_valid                (			RX_RESP_cxt_rsp_valid               	),
    .resource_resp_head                 (			RX_RESP_cxt_rsp_head                	),
    .resource_resp_data                 (			RX_RESP_cxt_rsp_data                	),
    .resource_resp_start                (			RX_RESP_cxt_rsp_valid            ),
    .resource_resp_last                 (			RX_RESP_cxt_rsp_valid            ),
    .resource_resp_ready                (			RX_RESP_cxt_rsp_ready               	),

    .egress_valid                       (           RX_RESP_fetch_cxt_egress_valid     	),
    .egress_head                        (           RX_RESP_fetch_cxt_egress_head      	),
    .egress_data                        (           RX_RESP_fetch_cxt_egress_data      	),
    .egress_start                       (           RX_RESP_fetch_cxt_egress_start     	),
    .egress_last                        (           RX_RESP_fetch_cxt_egress_last      	),
    .egress_ready                       (           RX_RESP_fetch_cxt_egress_ready    	 	)
);

OoOStation 
 #(
 	 	.ID                         ( 5                              ),
    .TAG_NUM                            (           `REQ_TAG_NUM            ),

    .RESOURCE_CMD_HEAD_WIDTH            (           `MR_CMD_HEAD_WIDTH             ),
    .RESOURCE_CMD_DATA_WIDTH            (           `MR_CMD_DATA_WIDTH             ),
    .RESOURCE_RESP_HEAD_WIDTH           (           `MR_RESP_HEAD_WIDTH            ), 
    .RESOURCE_RESP_DATA_WIDTH           (           `MR_RESP_DATA_WIDTH            ),

    .SLOT_NUM                           (           `SQ_OOO_SLOT_NUM                ),
    .QUEUE_NUM                          (           `QP_NUM                         ),       

    .INGRESS_HEAD_WIDTH                 (           `SQ_OOO_MR_INGRESS_HEAD_WIDTH  ),
    .INGRESS_DATA_WIDTH                 (           `SQ_OOO_MR_INGRESS_DATA_WIDTH  ),

    .EGRESS_HEAD_WIDTH                  (           `SQ_OOO_MR_EGRESS_HEAD_WIDTH   ),
    .EGRESS_DATA_WIDTH                  (           `SQ_OOO_MR_EGRESS_DATA_WIDTH   )
)
SQ_MR_OoO_Inst(
    .clk                                (           clk                             ),
    .rst                                (           rst                             ),

    .ingress_valid                      (           SQ_fetch_mr_ingress_valid     	),
    .ingress_head                       (           SQ_fetch_mr_ingress_head      	),
    .ingress_data                       (           SQ_fetch_mr_ingress_data      	),
    .ingress_start                      (           SQ_fetch_mr_ingress_start     	),
    .ingress_last                       (           SQ_fetch_mr_ingress_last      	),
    .ingress_ready                      (           SQ_fetch_mr_ingress_ready     	),

    .available_slot_num                 (),

    .resource_req_valid                 (			SQ_mr_req_valid                	),
    .resource_req_head                  (			SQ_mr_req_head                 	),
    .resource_req_data                  (			SQ_mr_req_data                 	),
    .resource_req_start                 (			SQ_mr_req_start                	),
    .resource_req_last                  (			SQ_mr_req_last                 	),
    .resource_req_ready                 (			SQ_mr_req_ready                	),

    .resource_resp_valid                (			SQ_mr_rsp_valid               	),
    .resource_resp_head                 (			SQ_mr_rsp_head                	),
    .resource_resp_data                 (			SQ_mr_rsp_data                	),
    .resource_resp_start                (			SQ_mr_rsp_valid              	),
    .resource_resp_last                 (			SQ_mr_rsp_valid              	),
    .resource_resp_ready                (			SQ_mr_rsp_ready               	),

    .egress_valid                       (           SQ_fetch_mr_egress_valid     	),
    .egress_head                        (           SQ_fetch_mr_egress_head      	),
    .egress_data                        (           SQ_fetch_mr_egress_data      	),
    .egress_start                       (           SQ_fetch_mr_egress_start     	),
    .egress_last                        (           SQ_fetch_mr_egress_last      	),
    .egress_ready                       (           SQ_fetch_mr_egress_ready    	 )
);

OoOStation 
 #(
 	 	.ID                         (  6                              ),
    .TAG_NUM                            (           `REQ_TAG_NUM            ),

    .RESOURCE_CMD_HEAD_WIDTH            (           `MR_CMD_HEAD_WIDTH             ),
    .RESOURCE_CMD_DATA_WIDTH            (           `MR_CMD_DATA_WIDTH             ),
    .RESOURCE_RESP_HEAD_WIDTH           (           `MR_RESP_HEAD_WIDTH            ), 
    .RESOURCE_RESP_DATA_WIDTH           (           `MR_RESP_DATA_WIDTH            ),

    .SLOT_NUM                           (           `RQ_OOO_SLOT_NUM                ),
    .QUEUE_NUM                          (           `QP_NUM                         ),       

    .INGRESS_HEAD_WIDTH                 (           `RQ_OOO_MR_INGRESS_HEAD_WIDTH  ),
    .INGRESS_DATA_WIDTH                 (           `RQ_OOO_MR_INGRESS_DATA_WIDTH  ),

    .EGRESS_HEAD_WIDTH                  (           `RQ_OOO_MR_EGRESS_HEAD_WIDTH   ),
    .EGRESS_DATA_WIDTH                  (           `RQ_OOO_MR_EGRESS_DATA_WIDTH   )
)
RQ_MR_OoO_Inst(
    .clk                                (           clk                             ),
    .rst                                (           rst                             ),

    .ingress_valid                      (           RQ_fetch_mr_ingress_valid     	),
    .ingress_head                       (           RQ_fetch_mr_ingress_head      	),
    .ingress_data                       (           RQ_fetch_mr_ingress_data      	),
    .ingress_start                      (           RQ_fetch_mr_ingress_start     	),
    .ingress_last                       (           RQ_fetch_mr_ingress_last      	),
    .ingress_ready                      (           RQ_fetch_mr_ingress_ready     	),

    .available_slot_num                 (),

    .resource_req_valid                 (			RQ_mr_req_valid                	),
    .resource_req_head                  (			RQ_mr_req_head                 	),
    .resource_req_data                  (			RQ_mr_req_data                 	),
    .resource_req_start                 (			RQ_mr_req_start                	),
    .resource_req_last                  (			RQ_mr_req_last                 	),
    .resource_req_ready                 (			RQ_mr_req_ready                	),

    .resource_resp_valid                (			RQ_mr_rsp_valid               	),
    .resource_resp_head                 (			RQ_mr_rsp_head                	),
    .resource_resp_data                 (			RQ_mr_rsp_data                	),
    .resource_resp_start                (			RQ_mr_rsp_valid                	),
    .resource_resp_last                 (			RQ_mr_rsp_valid                	),
    .resource_resp_ready                (			RQ_mr_rsp_ready               	),

    .egress_valid                       (           RQ_fetch_mr_egress_valid     	),
    .egress_head                        (           RQ_fetch_mr_egress_head      	),
    .egress_data                        (           RQ_fetch_mr_egress_data      	),
    .egress_start                       (           RQ_fetch_mr_egress_start     	),
    .egress_last                        (           RQ_fetch_mr_egress_last      	),
    .egress_ready                       (           RQ_fetch_mr_egress_ready    	 )
);

OoOStation 
 #(
     	.ID                         (  7                             ),
    .TAG_NUM                            (           `REQ_TAG_NUM            ),

    .RESOURCE_CMD_HEAD_WIDTH            (           `MR_CMD_HEAD_WIDTH             ),
    .RESOURCE_CMD_DATA_WIDTH            (           `MR_CMD_DATA_WIDTH             ),
    .RESOURCE_RESP_HEAD_WIDTH           (           `MR_RESP_HEAD_WIDTH            ), 
    .RESOURCE_RESP_DATA_WIDTH           (           `MR_RESP_DATA_WIDTH            ),

    .SLOT_NUM                           (           `TX_REQ_OOO_SLOT_NUM                ),
    .QUEUE_NUM                          (           `QP_NUM                             ),       

    .INGRESS_HEAD_WIDTH                 (           `TX_REQ_OOO_MR_INGRESS_HEAD_WIDTH   ),
    .INGRESS_DATA_WIDTH                 (           `TX_REQ_OOO_MR_INGRESS_DATA_WIDTH   ),

    .EGRESS_HEAD_WIDTH                  (           `TX_REQ_OOO_MR_EGRESS_HEAD_WIDTH    ),
    .EGRESS_DATA_WIDTH                  (           `TX_REQ_OOO_MR_EGRESS_DATA_WIDTH    )
)
TX_REQ_MR_OoO_Inst(
    .clk                                (           clk                             ),
    .rst                                (           rst                             ),

    .ingress_valid                      (           TX_REQ_fetch_mr_ingress_valid     	),
    .ingress_head                       (           TX_REQ_fetch_mr_ingress_head      	),
    .ingress_data                       (           TX_REQ_fetch_mr_ingress_data      	),
    .ingress_start                      (           TX_REQ_fetch_mr_ingress_start     	),
    .ingress_last                       (           TX_REQ_fetch_mr_ingress_last      	),
    .ingress_ready                      (           TX_REQ_fetch_mr_ingress_ready     	),

    .available_slot_num                 (),

    .resource_req_valid                 (			TX_REQ_mr_req_valid                	),
    .resource_req_head                  (			TX_REQ_mr_req_head                 	),
    .resource_req_data                  (			TX_REQ_mr_req_data                 	),
    .resource_req_start                 (			TX_REQ_mr_req_start                	),
    .resource_req_last                  (			TX_REQ_mr_req_last                 	),
    .resource_req_ready                 (			TX_REQ_mr_req_ready                	),

    .resource_resp_valid                (			TX_REQ_mr_rsp_valid               	),
    .resource_resp_head                 (			TX_REQ_mr_rsp_head                	),
    .resource_resp_data                 (			TX_REQ_mr_rsp_data                	),
    .resource_resp_start                (			TX_REQ_mr_rsp_valid                	),
    .resource_resp_last                 (			TX_REQ_mr_rsp_valid                	),
    .resource_resp_ready                (			TX_REQ_mr_rsp_ready               	),

    .egress_valid                       (           TX_REQ_fetch_mr_egress_valid     	),
    .egress_head                        (           TX_REQ_fetch_mr_egress_head      	),
    .egress_data                        (           TX_REQ_fetch_mr_egress_data      	),
    .egress_start                       (           TX_REQ_fetch_mr_egress_start     	),
    .egress_last                        (           TX_REQ_fetch_mr_egress_last      	),
    .egress_ready                       (           TX_REQ_fetch_mr_egress_ready    	 )
);

OoOStation
 #(
     	.ID                         (  8                             ),
    .TAG_NUM                            (           `REQ_TAG_NUM            ),

    .RESOURCE_CMD_HEAD_WIDTH            (           `MR_CMD_HEAD_WIDTH             ),
    .RESOURCE_CMD_DATA_WIDTH            (           `MR_CMD_DATA_WIDTH             ),
    .RESOURCE_RESP_HEAD_WIDTH           (           `MR_RESP_HEAD_WIDTH            ), 
    .RESOURCE_RESP_DATA_WIDTH           (           `MR_RESP_DATA_WIDTH            ),

    .SLOT_NUM                           (           `RX_REQ_OOO_SLOT_NUM                ),
    .QUEUE_NUM                          (           `QP_NUM                             ),       

    .INGRESS_HEAD_WIDTH                 (           `RX_REQ_OOO_MR_INGRESS_HEAD_WIDTH   ),
    .INGRESS_DATA_WIDTH                 (           `RX_REQ_OOO_MR_INGRESS_DATA_WIDTH   ),

    .EGRESS_HEAD_WIDTH                  (           `RX_REQ_OOO_MR_EGRESS_HEAD_WIDTH    ),
    .EGRESS_DATA_WIDTH                  (           `RX_REQ_OOO_MR_EGRESS_DATA_WIDTH    )
)
RX_REQ_MR_OoO_Inst(
    .clk                                (           clk                             ),
    .rst                                (           rst                             ),

    .ingress_valid                      (           RX_REQ_fetch_mr_ingress_valid     	),
    .ingress_head                       (           RX_REQ_fetch_mr_ingress_head      	),
    .ingress_data                       (           RX_REQ_fetch_mr_ingress_data      	),
    .ingress_start                      (           RX_REQ_fetch_mr_ingress_start     	),
    .ingress_last                       (           RX_REQ_fetch_mr_ingress_last      	),
    .ingress_ready                      (           RX_REQ_fetch_mr_ingress_ready     	),

    .available_slot_num                 (),

    .resource_req_valid                 (			RX_REQ_mr_req_valid                	),
    .resource_req_head                  (			RX_REQ_mr_req_head                 	),
    .resource_req_data                  (			RX_REQ_mr_req_data                 	),
    .resource_req_start                 (			RX_REQ_mr_req_start                	),
    .resource_req_last                  (			RX_REQ_mr_req_last                 	),
    .resource_req_ready                 (			RX_REQ_mr_req_ready                	),

    .resource_resp_valid                (			RX_REQ_mr_rsp_valid               	),
    .resource_resp_head                 (			RX_REQ_mr_rsp_head                	),
    .resource_resp_data                 (			RX_REQ_mr_rsp_data                	),
    .resource_resp_start                (			RX_REQ_mr_rsp_valid               	),
    .resource_resp_last                 (			RX_REQ_mr_rsp_valid               	),
    .resource_resp_ready                (			RX_REQ_mr_rsp_ready               	),

    .egress_valid                       (           RX_REQ_fetch_mr_egress_valid     	),
    .egress_head                        (           RX_REQ_fetch_mr_egress_head      	),
    .egress_data                        (           RX_REQ_fetch_mr_egress_data      	),
    .egress_start                       (           RX_REQ_fetch_mr_egress_start     	),
    .egress_last                        (           RX_REQ_fetch_mr_egress_last      	),
    .egress_ready                       (           RX_REQ_fetch_mr_egress_ready    	 )
);

OoOStation 
 #(
     	.ID                         (  9                             ),
    .TAG_NUM                            (           `REQ_TAG_NUM            ),

    .RESOURCE_CMD_HEAD_WIDTH            (           `MR_CMD_HEAD_WIDTH             ),
    .RESOURCE_CMD_DATA_WIDTH            (           `MR_CMD_DATA_WIDTH             ),
    .RESOURCE_RESP_HEAD_WIDTH           (           `MR_RESP_HEAD_WIDTH            ), 
    .RESOURCE_RESP_DATA_WIDTH           (           `MR_RESP_DATA_WIDTH            ),

    .SLOT_NUM                           (           `RX_RESP_OOO_SLOT_NUM                ),
    .QUEUE_NUM                          (           `QP_NUM                         ),       

    .INGRESS_HEAD_WIDTH                 (           `RX_RESP_OOO_MR_INGRESS_HEAD_WIDTH  ),
    .INGRESS_DATA_WIDTH                 (           `RX_RESP_OOO_MR_INGRESS_DATA_WIDTH  ),

    .EGRESS_HEAD_WIDTH                  (           `RX_RESP_OOO_MR_EGRESS_HEAD_WIDTH   ),
    .EGRESS_DATA_WIDTH                  (           `RX_RESP_OOO_MR_EGRESS_DATA_WIDTH   )
)
RX_RESP_MR_OoO_Inst(
    .clk                                (           clk                             ),
    .rst                                (           rst                             ),

    .ingress_valid                      (           RX_RESP_fetch_mr_ingress_valid     	),
    .ingress_head                       (           RX_RESP_fetch_mr_ingress_head      	),
    .ingress_data                       (           RX_RESP_fetch_mr_ingress_data      	),
    .ingress_start                      (           RX_RESP_fetch_mr_ingress_start     	),
    .ingress_last                       (           RX_RESP_fetch_mr_ingress_last      	),
    .ingress_ready                      (           RX_RESP_fetch_mr_ingress_ready     	),

    .available_slot_num                 (),

    .resource_req_valid                 (			RX_RESP_mr_req_valid                ),
    .resource_req_head                  (			RX_RESP_mr_req_head                 ),
    .resource_req_data                  (			RX_RESP_mr_req_data                 ),
    .resource_req_start                 (			RX_RESP_mr_req_start                ),
    .resource_req_last                  (			RX_RESP_mr_req_last                 ),
    .resource_req_ready                 (			RX_RESP_mr_req_ready                ),

    .resource_resp_valid                (			RX_RESP_mr_rsp_valid               ),
    .resource_resp_head                 (			RX_RESP_mr_rsp_head                ),
    .resource_resp_data                 (			RX_RESP_mr_rsp_data                ),
    .resource_resp_start                (			RX_RESP_mr_rsp_valid               ),
    .resource_resp_last                 (			RX_RESP_mr_rsp_valid               ),
    .resource_resp_ready                (			RX_RESP_mr_rsp_ready               ),

    .egress_valid                       (           RX_RESP_fetch_mr_egress_valid     	),
    .egress_head                        (           RX_RESP_fetch_mr_egress_head      	),
    .egress_data                        (           RX_RESP_fetch_mr_egress_data      	),
    .egress_start                       (           RX_RESP_fetch_mr_egress_start     	),
    .egress_last                        (           RX_RESP_fetch_mr_egress_last      	),
    .egress_ready                       (           RX_RESP_fetch_mr_egress_ready    	)
);

// `ifdef  ILA_ON
// ila_sq_ooo ila_sq_ooo_inst(
//     .clk(clk),

//     .probe0(SQ_fetch_cxt_ingress_valid),
//     .probe1(SQ_fetch_cxt_ingress_head),
//     .probe2(SQ_fetch_cxt_ingress_data),
//     .probe3(SQ_fetch_cxt_ingress_start),
//     .probe4(SQ_fetch_cxt_ingress_last),
//     .probe5(SQ_fetch_cxt_ingress_ready)
// );

// `endif

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/


/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
/*------------------------------------------- Variables Decode : End ------------------------------------------------*/
endmodule