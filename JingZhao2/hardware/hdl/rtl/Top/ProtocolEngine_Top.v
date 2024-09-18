/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ProtocolEngine_Top
Author:     YangFan
Function:   Integrate RPCSubsystem, QueueSubsystem, TransportSubsystem and ResMgtSubsystem.
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
module ProtocolEngine_Top
#(
    parameter                       INGRESS_CXT_HEAD_WIDTH                  =   128,
    parameter                       INGRESS_CXT_DATA_WIDTH                  =   256,
    parameter                       EGRESS_CXT_HEAD_WIDTH                   =   128,
    parameter                       EGRESS_CXT_DATA_WIDTH                   =   256,

    parameter                       INGRESS_MR_HEAD_WIDTH                   =   128,
    parameter                       INGRESS_MR_DATA_WIDTH                   =   256,
    parameter                       EGRESS_MR_HEAD_WIDTH                    =   128,
    parameter                       EGRESS_MR_DATA_WIDTH                    =   256
)
(
	input   wire                                                    user_clk,
    input   wire                                                    user_rst,

    input   wire                                                    mac_tx_clk,
    input   wire                                                    mac_tx_rst,

    input   wire                                                    mac_rx_clk,
    input   wire                                                    mac_rx_rst,

//Control Path Interface
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

//Data Path Interface

    input   wire                                                    db_fifo_empty,
    input   wire    [63:0]                                          db_fifo_dout,
    output  wire                                                    db_fifo_rd_en,

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
    input   wire                                                 	MTT_dma_wr_req_ready,

    output  wire                                                    SQ_dma_rd_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                       SQ_dma_rd_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                       SQ_dma_rd_req_data,
    output  wire                                                    SQ_dma_rd_req_last,
    input   wire                                                    SQ_dma_rd_req_ready,
                        
    input   wire                                                    SQ_dma_rd_rsp_valid,
    input   wire    [`DMA_HEAD_WIDTH - 1 : 0]                       SQ_dma_rd_rsp_head,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                       SQ_dma_rd_rsp_data,
    input   wire                                                    SQ_dma_rd_rsp_last,
    output  wire                                                    SQ_dma_rd_rsp_ready,

    output  wire                                                    RQ_dma_rd_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                       RQ_dma_rd_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                       RQ_dma_rd_req_data,
    output  wire                                                    RQ_dma_rd_req_last,
    input   wire                                                    RQ_dma_rd_req_ready,
                        
    input   wire                                                    RQ_dma_rd_rsp_valid,
    input   wire    [`DMA_HEAD_WIDTH - 1 : 0]                       RQ_dma_rd_rsp_head,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                       RQ_dma_rd_rsp_data,
    input   wire                                                    RQ_dma_rd_rsp_last,
    output  wire                                                    RQ_dma_rd_rsp_ready,

    output  wire                                                    TX_REQ_dma_wr_req_valid,
    output  wire                                                    TX_REQ_dma_wr_req_last,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                       TX_REQ_dma_wr_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                       TX_REQ_dma_wr_req_data,
    input   wire                                                    TX_REQ_dma_wr_req_ready,

    output  wire                                                    RX_REQ_dma_wr_req_valid,
    output  wire                                                    RX_REQ_dma_wr_req_last,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                       RX_REQ_dma_wr_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                       RX_REQ_dma_wr_req_data,
    input   wire                                                    RX_REQ_dma_wr_req_ready,

    output  wire                                                    RX_RESP_dma_wr_req_valid,
    output  wire                                                    RX_RESP_dma_wr_req_last,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                       RX_RESP_dma_wr_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                       RX_RESP_dma_wr_req_data,
    input   wire                                                    RX_RESP_dma_wr_req_ready,

    output  wire                                                    TX_REQ_dma_rd_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                       TX_REQ_dma_rd_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                       TX_REQ_dma_rd_req_data,
    output  wire                                                    TX_REQ_dma_rd_req_last,
    input   wire                                                    TX_REQ_dma_rd_req_ready,
    
    input   wire                                                    TX_REQ_dma_rd_rsp_valid,
    input   wire    [`DMA_HEAD_WIDTH - 1 : 0]                       TX_REQ_dma_rd_rsp_head,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                       TX_REQ_dma_rd_rsp_data,
    input   wire                                                    TX_REQ_dma_rd_rsp_last,
    output  wire                                                    TX_REQ_dma_rd_rsp_ready,

    output  wire                                                    TX_RESP_dma_rd_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                       TX_RESP_dma_rd_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                       TX_RESP_dma_rd_req_data,
    output  wire                                                    TX_RESP_dma_rd_req_last,
    input   wire                                                    TX_RESP_dma_rd_req_ready,
    
    input   wire                                                    TX_RESP_dma_rd_rsp_valid,
    input   wire    [`DMA_HEAD_WIDTH - 1 : 0]                       TX_RESP_dma_rd_rsp_head,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                       TX_RESP_dma_rd_rsp_data,
    input   wire                                                    TX_RESP_dma_rd_rsp_last,
    output  wire                                                    TX_RESP_dma_rd_rsp_ready,

//Interface with MAC
    output  wire                                                    mac_tx_valid,
    input   wire                                                    mac_tx_ready,
    output  wire                                                    mac_tx_start,
    output  wire                                                    mac_tx_last,
    output  wire    [`MAC_KEEP_WIDTH - 1 : 0]                       mac_tx_keep,
    output  wire                                                    mac_tx_user,
    output  wire    [`MAC_DATA_WIDTH - 1 : 0]                       mac_tx_data,

    input   wire                                                    mac_rx_valid,
    output  wire                                                    mac_rx_ready,
    input   wire                                                    mac_rx_start,
    input   wire                                                    mac_rx_last,
    input   wire    [`MAC_KEEP_WIDTH - 1 : 0]                       mac_rx_keep,
    input   wire                                                    mac_rx_user,
    input   wire    [`MAC_DATA_WIDTH - 1 : 0]                       mac_rx_data
);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                                    SQ_fetch_cxt_ingress_valid;
wire    [`SQ_OOO_CXT_INGRESS_HEAD_WIDTH - 1 : 0]        SQ_fetch_cxt_ingress_head; 
wire    [`SQ_OOO_CXT_INGRESS_DATA_WIDTH  - 1 : 0]       SQ_fetch_cxt_ingress_data; 
wire                                                    SQ_fetch_cxt_ingress_start;
wire                                                    SQ_fetch_cxt_ingress_last;
wire                                                    SQ_fetch_cxt_ingress_ready;

wire                                                    SQ_fetch_cxt_egress_valid;
wire    [`SQ_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]         SQ_fetch_cxt_egress_head;  
wire    [`SQ_OOO_CXT_EGRESS_DATA_WIDTH  - 1 : 0]        SQ_fetch_cxt_egress_data;
wire                                                    SQ_fetch_cxt_egress_start;
wire                                                    SQ_fetch_cxt_egress_last;
wire                                                    SQ_fetch_cxt_egress_ready;

wire                                                            TX_REQ_fetch_cxt_ingress_valid;
wire    [`TX_REQ_OOO_CXT_INGRESS_HEAD_WIDTH - 1 : 0]                TX_REQ_fetch_cxt_ingress_head;
wire    [`TX_REQ_OOO_CXT_INGRESS_DATA_WIDTH - 1 : 0]                TX_REQ_fetch_cxt_ingress_data;
wire                                                            TX_REQ_fetch_cxt_ingress_start;
wire                                                            TX_REQ_fetch_cxt_ingress_last;
wire                                                            TX_REQ_fetch_cxt_ingress_ready;

wire                                                            TX_REQ_fetch_cxt_egress_valid;
wire    [`TX_REQ_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]                 TX_REQ_fetch_cxt_egress_head;
wire    [`TX_REQ_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]                 TX_REQ_fetch_cxt_egress_data;
wire                                                            TX_REQ_fetch_cxt_egress_start;
wire                                                            TX_REQ_fetch_cxt_egress_last;
wire                                                            TX_REQ_fetch_cxt_egress_ready;

wire                                                            RX_REQ_fetch_cxt_ingress_valid;
wire    [`RX_REQ_OOO_CXT_INGRESS_HEAD_WIDTH - 1 : 0]            RX_REQ_fetch_cxt_ingress_head;
wire    [`RX_REQ_OOO_CXT_INGRESS_DATA_WIDTH - 1 : 0]            RX_REQ_fetch_cxt_ingress_data;
wire                                                            RX_REQ_fetch_cxt_ingress_start;
wire                                                            RX_REQ_fetch_cxt_ingress_last;
wire                                                            RX_REQ_fetch_cxt_ingress_ready;

wire                                                            RX_REQ_fetch_cxt_egress_valid;
wire    [`RX_REQ_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]             RX_REQ_fetch_cxt_egress_head;
wire    [`RX_REQ_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]             RX_REQ_fetch_cxt_egress_data;
wire                                                            RX_REQ_fetch_cxt_egress_start;
wire                                                            RX_REQ_fetch_cxt_egress_last;
wire                                                            RX_REQ_fetch_cxt_egress_ready;

wire                                                           RX_RESP_fetch_cxt_ingress_valid;
wire    [`RX_RESP_OOO_CXT_INGRESS_HEAD_WIDTH - 1 : 0]            RX_RESP_fetch_cxt_ingress_head;
wire    [`RX_RESP_OOO_CXT_INGRESS_DATA_WIDTH - 1 : 0]            RX_RESP_fetch_cxt_ingress_data;
wire                                                           RX_RESP_fetch_cxt_ingress_start;
wire                                                           RX_RESP_fetch_cxt_ingress_last;
wire                                                           RX_RESP_fetch_cxt_ingress_ready;

wire                                                           RX_RESP_fetch_cxt_egress_valid;
wire    [`RX_RESP_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]             RX_RESP_fetch_cxt_egress_head;
wire    [`RX_RESP_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]             RX_RESP_fetch_cxt_egress_data;
wire                                                           RX_RESP_fetch_cxt_egress_start;
wire                                                           RX_RESP_fetch_cxt_egress_last;
wire                                                           RX_RESP_fetch_cxt_egress_ready;

wire                                                    SQ_fetch_mr_ingress_valid;
wire    [`SQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]         SQ_fetch_mr_ingress_head; 
wire    [`SQ_OOO_MR_INGRESS_DATA_WIDTH  - 1 : 0]        SQ_fetch_mr_ingress_data;
wire                                                    SQ_fetch_mr_ingress_start;
wire                                                    SQ_fetch_mr_ingress_last;
wire                                                    SQ_fetch_mr_ingress_ready;

wire                                                    SQ_fetch_mr_egress_valid;
wire    [`SQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]          SQ_fetch_mr_egress_head;
wire    [`SQ_OOO_MR_EGRESS_DATA_WIDTH  - 1 : 0]         SQ_fetch_mr_egress_data;
wire                                                    SQ_fetch_mr_egress_start;
wire                                                    SQ_fetch_mr_egress_last;
wire                                                    SQ_fetch_mr_egress_ready;

wire                                                    RQ_fetch_mr_ingress_valid;
wire    [`RQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]         RQ_fetch_mr_ingress_head; 
wire    [`RQ_OOO_MR_INGRESS_DATA_WIDTH  - 1 : 0]        RQ_fetch_mr_ingress_data;
wire                                                    RQ_fetch_mr_ingress_start;
wire                                                    RQ_fetch_mr_ingress_last;
wire                                                    RQ_fetch_mr_ingress_ready;

wire                                                    RQ_fetch_mr_egress_valid;
wire    [`RQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]          RQ_fetch_mr_egress_head;
wire    [`RQ_OOO_MR_EGRESS_DATA_WIDTH  - 1 : 0]         RQ_fetch_mr_egress_data;
wire                                                    RQ_fetch_mr_egress_start;
wire                                                    RQ_fetch_mr_egress_last;
wire                                                    RQ_fetch_mr_egress_ready;

wire                                                   TX_REQ_fetch_mr_ingress_valid;
wire    [`TX_REQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]    TX_REQ_fetch_mr_ingress_head;
wire    [`TX_REQ_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]    TX_REQ_fetch_mr_ingress_data;
wire                                                   TX_REQ_fetch_mr_ingress_start;
wire                                                   TX_REQ_fetch_mr_ingress_last;
wire                                                   TX_REQ_fetch_mr_ingress_ready;

wire                                                   TX_REQ_fetch_mr_egress_valid;
wire    [`TX_REQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]     TX_REQ_fetch_mr_egress_head;
wire    [`TX_REQ_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]     TX_REQ_fetch_mr_egress_data;
wire                                                   TX_REQ_fetch_mr_egress_start;
wire                                                   TX_REQ_fetch_mr_egress_last;
wire                                                   TX_REQ_fetch_mr_egress_ready;

wire                                                           RX_RESP_fetch_mr_ingress_valid;
wire    [`RX_RESP_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]            RX_RESP_fetch_mr_ingress_head;
wire    [`RX_RESP_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]            RX_RESP_fetch_mr_ingress_data;
wire                                                           RX_RESP_fetch_mr_ingress_start;
wire                                                           RX_RESP_fetch_mr_ingress_last;
wire                                                           RX_RESP_fetch_mr_ingress_ready;

wire                                                           RX_RESP_fetch_mr_egress_valid;
wire    [`RX_RESP_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]             RX_RESP_fetch_mr_egress_head;
wire    [`RX_RESP_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]             RX_RESP_fetch_mr_egress_data;
wire                                                           RX_RESP_fetch_mr_egress_start;
wire                                                           RX_RESP_fetch_mr_egress_last;
wire                                                           RX_RESP_fetch_mr_egress_ready;

wire                                                                RX_REQ_fetch_mr_ingress_valid;
wire        [`RX_REQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]             RX_REQ_fetch_mr_ingress_head;
wire        [`RX_REQ_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]             RX_REQ_fetch_mr_ingress_data;
wire                                                                RX_REQ_fetch_mr_ingress_start;
wire                                                                RX_REQ_fetch_mr_ingress_last;
wire                                                                RX_REQ_fetch_mr_ingress_ready;

wire                                                                RX_REQ_fetch_mr_egress_valid;
wire        [`RX_REQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]              RX_REQ_fetch_mr_egress_head;
wire        [`RX_REQ_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]              RX_REQ_fetch_mr_egress_data;
wire                                                                RX_REQ_fetch_mr_egress_start;
wire                                                                RX_REQ_fetch_mr_egress_last;
wire                                                                RX_REQ_fetch_mr_egress_ready;


wire                                                            TX_REQ_sub_wqe_valid;
wire    [`WQE_META_WIDTH - 1 : 0]                               TX_REQ_sub_wqe_meta;
wire                                                            TX_REQ_sub_wqe_ready;

wire                                                            TX_inline_insert_req_valid;
wire                                                            TX_inline_insert_req_start;
wire                                                            TX_inline_insert_req_last;
wire    [`INLINE_PAYLOAD_BUFFER_SLOT_NUM_LOG - 1 : 0]           TX_inline_insert_req_head;
wire    [`INLINE_PAYLOAD_BUFFER_SLOT_WIDTH - 1 : 0]             TX_inline_insert_req_data;
wire                                                            TX_inline_insert_req_ready;

wire                                                            TX_inline_insert_resp_valid;
wire    [`INLINE_PAYLOAD_BUFFER_SLOT_WIDTH - 1 : 0]             TX_inline_insert_resp_data;

wire                                                            RQ_wqe_req_valid;
wire    [`WQE_META_WIDTH - 1 : 0]                               RQ_wqe_req_head;
wire                                                            RQ_wqe_req_start;
wire                                                            RQ_wqe_req_last;
wire                                                            RQ_wqe_req_ready;

wire                                                            RQ_wqe_resp_valid;
wire    [`WQE_META_WIDTH - 1 : 0]                               RQ_wqe_resp_head;
wire    [`WQE_SEG_WIDTH - 1 : 0]                                RQ_wqe_resp_data;
wire                                                            RQ_wqe_resp_start;
wire                                                            RQ_wqe_resp_last;
wire                                                            RQ_wqe_resp_ready;

wire                                                            RQ_cache_offset_wen;
wire    [`QP_NUM_LOG - 1 : 0]                                   RQ_cache_offset_addr;
wire    [`RQ_CACHE_SLOT_NUM_LOG - 1:0]                          RQ_cache_offset_din;
wire    [`RQ_CACHE_SLOT_NUM_LOG - 1:0]                          RQ_cache_offset_dout;

wire                                                            RQ_offset_wen;
wire    [`QP_NUM_LOG - 1 : 0]                                   RQ_offset_addr;
wire    [23:0]                                                  RQ_offset_din;
wire    [23:0]                                                  RQ_offset_dout;

wire                                                            RQ_cache_owned_wen;
wire    [`RQ_CACHE_CELL_NUM_LOG - 1 : 0]                        RQ_cache_owned_addr;
wire    [`QP_NUM_LOG - 1 : 0]                                   RQ_cache_owned_din;
wire    [`QP_NUM_LOG - 1 : 0]                                   RQ_cache_owned_dout;

wire                                                            TX_REQ_cq_req_valid;
wire    [`CQ_REQ_HEAD_WIDTH - 1 : 0]                            TX_REQ_cq_req_head;
wire                                                            TX_REQ_cq_req_ready;

wire                                                            TX_REQ_cq_resp_valid;
wire    [`CQ_RESP_HEAD_WIDTH - 1 : 0]                           TX_REQ_cq_resp_head;
wire                                                            TX_REQ_cq_resp_ready;

wire                                                            RX_REQ_cq_req_valid;
wire    [`CQ_REQ_HEAD_WIDTH - 1 : 0]                            RX_REQ_cq_req_head;
wire                                                            RX_REQ_cq_req_ready;

wire                                                            RX_REQ_cq_resp_valid;
wire    [`CQ_RESP_HEAD_WIDTH - 1 : 0]                           RX_REQ_cq_resp_head;
wire                                                            RX_REQ_cq_resp_ready;

wire                                                            RX_RESP_cq_req_valid;
wire    [`CQ_REQ_HEAD_WIDTH - 1 : 0]                            RX_RESP_cq_req_head;
wire                                                            RX_RESP_cq_req_ready;

wire                                                            RX_RESP_cq_resp_valid;
wire    [`CQ_RESP_HEAD_WIDTH - 1 : 0]                           RX_RESP_cq_resp_head;
wire                                                            RX_RESP_cq_resp_ready;

wire                                                            TX_REQ_eq_req_valid;
wire    [`EQ_REQ_HEAD_WIDTH - 1 : 0]                            TX_REQ_eq_req_head;
wire                                                            TX_REQ_eq_req_ready;

wire                                                            TX_REQ_eq_resp_valid;
wire    [`EQ_RESP_HEAD_WIDTH - 1 : 0]                           TX_REQ_eq_resp_head;
wire                                                            TX_REQ_eq_resp_ready;

wire                                                            RX_REQ_eq_req_valid;
wire    [`EQ_REQ_HEAD_WIDTH - 1 : 0]                            RX_REQ_eq_req_head;
wire                                                            RX_REQ_eq_req_ready;

wire                                                            RX_REQ_eq_resp_valid;
wire    [`EQ_RESP_HEAD_WIDTH - 1 : 0]                           RX_REQ_eq_resp_head;
wire                                                            RX_REQ_eq_resp_ready;

wire                                                            RX_RESP_eq_req_valid;
wire    [`EQ_REQ_HEAD_WIDTH - 1 : 0]                            RX_RESP_eq_req_head;
wire                                                            RX_RESP_eq_req_ready;

wire                                                            RX_RESP_eq_resp_valid;
wire    [`EQ_RESP_HEAD_WIDTH - 1 : 0]                           RX_RESP_eq_resp_head;
wire                                                            RX_RESP_eq_resp_ready;

wire                                                            TX_egress_pkt_valid;
wire    [`PKT_META_BUS_WIDTH - 1 : 0]                           TX_egress_pkt_head;
wire                                                            TX_egress_pkt_ready;

wire                                                            TX_non_inline_insert_req_valid;
wire                                                            TX_non_inline_insert_req_start;
wire                                                            TX_non_inline_insert_req_last;
wire    [`MAX_DB_SLOT_NUM_LOG - 1 : 0]                          TX_non_inline_insert_req_head;
wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     TX_non_inline_insert_req_data;
wire                                                            TX_non_inline_insert_req_ready;

wire                                                            TX_non_inline_insert_resp_valid;
wire    [`MAX_DB_SLOT_NUM_LOG - 1 : 0]                          TX_non_inline_insert_resp_data;

wire                                                            TX_insert_req_valid;
wire                                                            TX_insert_req_start;
wire                                                            TX_insert_req_last;
wire    [`MAX_DB_SLOT_NUM_LOG - 1 : 0]                          TX_insert_req_head;
wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     TX_insert_req_data;
wire                                                            TX_insert_req_ready;

wire                                                            TX_insert_resp_valid;
wire    [`MAX_DB_SLOT_NUM_LOG - 1 : 0]                          TX_insert_resp_data;

wire                                                            RX_ingress_pkt_valid;
wire    [`PKT_META_BUS_WIDTH - 1 : 0]                           RX_ingress_pkt_head;
wire                                                            RX_ingress_pkt_ready;

wire                                                            RX_delete_req_valid;
wire    [`MAX_DB_SLOT_NUM_LOG * 2 - 1 : 0]                      RX_delete_req_head;
wire                                                            RX_delete_req_ready;

wire                                                            RX_delete_resp_valid;
wire                                                            RX_delete_resp_start;
wire                                                            RX_delete_resp_last;
wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     RX_delete_resp_data;
wire                                                            RX_delete_resp_ready;

/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
QueueSubsystem
#(
    .INGRESS_CXT_HEAD_WIDTH      (          INGRESS_CXT_HEAD_WIDTH                  ),
    .INGRESS_CXT_DATA_WIDTH      (          INGRESS_CXT_DATA_WIDTH                  ),
    .EGRESS_CXT_HEAD_WIDTH       (          EGRESS_CXT_HEAD_WIDTH                   ),
    .EGRESS_CXT_DATA_WIDTH       (          EGRESS_CXT_DATA_WIDTH                   ),

    .INGRESS_MR_HEAD_WIDTH       (          INGRESS_MR_HEAD_WIDTH                   ),
    .INGRESS_MR_DATA_WIDTH       (          INGRESS_MR_DATA_WIDTH                   ),
    .EGRESS_MR_HEAD_WIDTH        (          EGRESS_MR_HEAD_WIDTH                    ),
    .EGRESS_MR_DATA_WIDTH        (          EGRESS_MR_DATA_WIDTH                    )
)
QueueSubsystem_Inst
(
    .clk                                (           user_clk                                 ),
    .rst                                (           user_rst                                 ),

//SQ Interface
    .db_fifo_empty                      (           db_fifo_empty                       ),
    .db_fifo_dout                       (           db_fifo_dout                        ),
    .db_fifo_rd_en                      (           db_fifo_rd_en                       ),

    .SQ_fetch_cxt_ingress_valid         (           SQ_fetch_cxt_ingress_valid          ),
    .SQ_fetch_cxt_ingress_head          (           SQ_fetch_cxt_ingress_head           ), 
    .SQ_fetch_cxt_ingress_data          (           SQ_fetch_cxt_ingress_data           ), 
    .SQ_fetch_cxt_ingress_start         (           SQ_fetch_cxt_ingress_start          ),
    .SQ_fetch_cxt_ingress_last          (           SQ_fetch_cxt_ingress_last           ),
    .SQ_fetch_cxt_ingress_ready         (           SQ_fetch_cxt_ingress_ready          ),

    .SQ_fetch_cxt_egress_valid          (           SQ_fetch_cxt_egress_valid           ),
    .SQ_fetch_cxt_egress_head           (           SQ_fetch_cxt_egress_head            ),
    .SQ_fetch_cxt_egress_data           (           SQ_fetch_cxt_egress_data            ),
    .SQ_fetch_cxt_egress_start          (           SQ_fetch_cxt_egress_start           ),
    .SQ_fetch_cxt_egress_last           (           SQ_fetch_cxt_egress_last            ),
    .SQ_fetch_cxt_egress_ready          (           SQ_fetch_cxt_egress_ready           ),

    .SQ_fetch_mr_ingress_valid          (           SQ_fetch_mr_ingress_valid           ),
    .SQ_fetch_mr_ingress_head           (           SQ_fetch_mr_ingress_head            ),
    .SQ_fetch_mr_ingress_data           (           SQ_fetch_mr_ingress_data            ),
    .SQ_fetch_mr_ingress_start          (           SQ_fetch_mr_ingress_start           ),
    .SQ_fetch_mr_ingress_last           (           SQ_fetch_mr_ingress_last            ),
    .SQ_fetch_mr_ingress_ready          (           SQ_fetch_mr_ingress_ready           ),

    .SQ_fetch_mr_egress_valid           (           SQ_fetch_mr_egress_valid            ),
    .SQ_fetch_mr_egress_head            (           SQ_fetch_mr_egress_head             ),
    .SQ_fetch_mr_egress_data            (           SQ_fetch_mr_egress_data             ),
    .SQ_fetch_mr_egress_start           (           SQ_fetch_mr_egress_start            ),
    .SQ_fetch_mr_egress_last            (           SQ_fetch_mr_egress_last             ),
    .SQ_fetch_mr_egress_ready           (           SQ_fetch_mr_egress_ready            ),

    .SQ_dma_rd_req_valid                (           SQ_dma_rd_req_valid                 ),
    .SQ_dma_rd_req_head                 (           SQ_dma_rd_req_head                  ),
    .SQ_dma_rd_req_data                 (           SQ_dma_rd_req_data                  ),
    .SQ_dma_rd_req_last                 (           SQ_dma_rd_req_last                  ),
    .SQ_dma_rd_req_ready                (           SQ_dma_rd_req_ready                 ),

    .SQ_dma_rd_rsp_valid               (           SQ_dma_rd_rsp_valid                ),
    .SQ_dma_rd_rsp_head                (           SQ_dma_rd_rsp_head                 ),
    .SQ_dma_rd_rsp_data                (           SQ_dma_rd_rsp_data                 ),
    .SQ_dma_rd_rsp_last                (           SQ_dma_rd_rsp_last                 ),
    .SQ_dma_rd_rsp_ready               (           SQ_dma_rd_rsp_ready                ),

    .sub_wqe_valid                      (           TX_REQ_sub_wqe_valid                ),
    .sub_wqe_meta                       (           TX_REQ_sub_wqe_meta                 ),
    .sub_wqe_ready                      (           TX_REQ_sub_wqe_ready                ),

    .insert_req_valid                   (           TX_inline_insert_req_valid          ),
    .insert_req_start                   (           TX_inline_insert_req_start          ),
    .insert_req_last                    (           TX_inline_insert_req_last           ),
    .insert_req_head                    (           TX_inline_insert_req_head           ),
    .insert_req_data                    (           TX_inline_insert_req_data           ),
    .insert_req_ready                   (           TX_inline_insert_req_ready          ),

    .insert_resp_valid                  (           TX_inline_insert_resp_valid         ),
    .insert_resp_data                   (           TX_inline_insert_resp_data          ),

//RQ Interface
    .RQ_wqe_req_valid                   (           RQ_wqe_req_valid                  ),
    .RQ_wqe_req_head                    (           RQ_wqe_req_head                   ),
    .RQ_wqe_req_start                   (           RQ_wqe_req_start                  ),
    .RQ_wqe_req_last                    (           RQ_wqe_req_last                   ),
    .RQ_wqe_req_ready                   (           RQ_wqe_req_ready                  ),

    .RQ_wqe_resp_valid                  (           RQ_wqe_resp_valid                 ),
    .RQ_wqe_resp_head                   (           RQ_wqe_resp_head                  ),
    .RQ_wqe_resp_data                   (           RQ_wqe_resp_data                  ),
    .RQ_wqe_resp_start                  (           RQ_wqe_resp_start                 ),
    .RQ_wqe_resp_last                   (           RQ_wqe_resp_last                  ),
    .RQ_wqe_resp_ready                  (           RQ_wqe_resp_ready                 ),

    .RQ_cache_offset_wen                (           RQ_cache_offset_wen                 ),
    .RQ_cache_offset_addr               (           RQ_cache_offset_addr                ),
    .RQ_cache_offset_din                (           RQ_cache_offset_din                 ),
    .RQ_cache_offset_dout               (           RQ_cache_offset_dout                ),

    .RQ_offset_wen                      (           RQ_offset_wen                       ),
    .RQ_offset_addr                     (           RQ_offset_addr                      ),
    .RQ_offset_din                      (           RQ_offset_din                       ),
    .RQ_offset_dout                     (           RQ_offset_dout                      ),

    .RQ_cache_owned_wen                 (           RQ_cache_owned_wen                  ),
    .RQ_cache_owned_addr                (           RQ_cache_owned_addr                 ),
    .RQ_cache_owned_din                 (           RQ_cache_owned_din                  ),
    .RQ_cache_owned_dout                (           RQ_cache_owned_dout                 ),

    .RQ_fetch_mr_ingress_valid          (           RQ_fetch_mr_ingress_valid           ),
    .RQ_fetch_mr_ingress_head           (           RQ_fetch_mr_ingress_head            ), 
    .RQ_fetch_mr_ingress_data           (           RQ_fetch_mr_ingress_data            ),
    .RQ_fetch_mr_ingress_start          (           RQ_fetch_mr_ingress_start           ),
    .RQ_fetch_mr_ingress_last           (           RQ_fetch_mr_ingress_last            ),
    .RQ_fetch_mr_ingress_ready          (           RQ_fetch_mr_ingress_ready           ),

    .RQ_fetch_mr_egress_valid           (           RQ_fetch_mr_egress_valid            ),
    .RQ_fetch_mr_egress_head            (           RQ_fetch_mr_egress_head             ),
    .RQ_fetch_mr_egress_data            (           RQ_fetch_mr_egress_data             ),
    .RQ_fetch_mr_egress_start           (           RQ_fetch_mr_egress_start            ),
    .RQ_fetch_mr_egress_last            (           RQ_fetch_mr_egress_last             ),
    .RQ_fetch_mr_egress_ready           (           RQ_fetch_mr_egress_ready            ),

    .RQ_dma_rd_req_valid                (           RQ_dma_rd_req_valid                 ),
    .RQ_dma_rd_req_head                 (           RQ_dma_rd_req_head                  ),
    .RQ_dma_rd_req_data                 (           RQ_dma_rd_req_data                  ),
    .RQ_dma_rd_req_last                 (           RQ_dma_rd_req_last                  ),
    .RQ_dma_rd_req_ready                (           RQ_dma_rd_req_ready                 ),
                        
    .RQ_dma_rd_rsp_valid               (           RQ_dma_rd_rsp_valid                ),
    .RQ_dma_rd_rsp_head                (           RQ_dma_rd_rsp_head                 ),
    .RQ_dma_rd_rsp_data                (           RQ_dma_rd_rsp_data                 ),
    .RQ_dma_rd_rsp_last                (           RQ_dma_rd_rsp_last                 ),
    .RQ_dma_rd_rsp_ready               (           RQ_dma_rd_rsp_ready                ),

//CQ Interface
    .TX_REQ_cq_req_valid                (           TX_REQ_cq_req_valid                 ),
    .TX_REQ_cq_req_head                 (           TX_REQ_cq_req_head                  ),
    .TX_REQ_cq_req_ready                (           TX_REQ_cq_req_ready                 ),

    .TX_REQ_cq_resp_valid               (           TX_REQ_cq_resp_valid                ),
    .TX_REQ_cq_resp_head                (           TX_REQ_cq_resp_head                 ),
    .TX_REQ_cq_resp_ready               (           TX_REQ_cq_resp_ready                ),

    .RX_REQ_cq_req_valid                (           RX_REQ_cq_req_valid                 ),
    .RX_REQ_cq_req_head                 (           RX_REQ_cq_req_head                  ),
    .RX_REQ_cq_req_ready                (           RX_REQ_cq_req_ready                 ),

    .RX_REQ_cq_resp_valid               (           RX_REQ_cq_resp_valid                ),
    .RX_REQ_cq_resp_head                (           RX_REQ_cq_resp_head                 ),
    .RX_REQ_cq_resp_ready               (           RX_REQ_cq_resp_ready                ),

    .RX_RESP_cq_req_valid               (           RX_RESP_cq_req_valid                ),
    .RX_RESP_cq_req_head                (           RX_RESP_cq_req_head                 ),
    .RX_RESP_cq_req_ready               (           RX_RESP_cq_req_ready                ),

    .RX_RESP_cq_resp_valid              (           RX_RESP_cq_resp_valid               ),
    .RX_RESP_cq_resp_head               (           RX_RESP_cq_resp_head                ),
    .RX_RESP_cq_resp_ready              (           RX_RESP_cq_resp_ready               ),

//EQ Interface
    .TX_REQ_eq_req_valid                (           TX_REQ_eq_req_valid                 ),
    .TX_REQ_eq_req_head                 (           TX_REQ_eq_req_head                  ),
    .TX_REQ_eq_req_ready                (           TX_REQ_eq_req_ready                 ),

    .TX_REQ_eq_resp_valid               (           TX_REQ_eq_resp_valid                ),
    .TX_REQ_eq_resp_head                (           TX_REQ_eq_resp_head                 ),
    .TX_REQ_eq_resp_ready               (           TX_REQ_eq_resp_ready                ),

    .RX_REQ_eq_req_valid                (           RX_REQ_eq_req_valid                 ),
    .RX_REQ_eq_req_head                 (           RX_REQ_eq_req_head                  ),
    .RX_REQ_eq_req_ready                (           RX_REQ_eq_req_ready                 ),

    .RX_REQ_eq_resp_valid               (           RX_REQ_eq_resp_valid                ),
    .RX_REQ_eq_resp_head                (           RX_REQ_eq_resp_head                 ),
    .RX_REQ_eq_resp_ready               (           RX_REQ_eq_resp_ready                ),

    .RX_RESP_eq_req_valid               (           RX_RESP_eq_req_valid                ),
    .RX_RESP_eq_req_head                (           RX_RESP_eq_req_head                 ),
    .RX_RESP_eq_req_ready               (           RX_RESP_eq_req_ready                ),
     
    .RX_RESP_eq_resp_valid              (           RX_RESP_eq_resp_valid               ),
    .RX_RESP_eq_resp_head               (           RX_RESP_eq_resp_head                ),
    .RX_RESP_eq_resp_ready              (           RX_RESP_eq_resp_ready               )
);

ResMgtSubsystem #(
        .INGRESS_CXT_HEAD_WIDTH      (          INGRESS_CXT_HEAD_WIDTH              ),
        .INGRESS_CXT_DATA_WIDTH      (          INGRESS_CXT_DATA_WIDTH              ),
        .EGRESS_CXT_HEAD_WIDTH       (          EGRESS_CXT_HEAD_WIDTH               ),
        .EGRESS_CXT_DATA_WIDTH       (          EGRESS_CXT_DATA_WIDTH               ),

        .INGRESS_MR_HEAD_WIDTH       (          INGRESS_MR_HEAD_WIDTH               ),
        .INGRESS_MR_DATA_WIDTH       (          INGRESS_MR_DATA_WIDTH               ),
        .EGRESS_MR_HEAD_WIDTH        (          EGRESS_MR_HEAD_WIDTH                ),
        .EGRESS_MR_DATA_WIDTH        (          EGRESS_MR_DATA_WIDTH                )
)
ResMgtSubsystem_Inst
(
    .clk                                    (           user_clk                                     ),
    .rst                                    (           user_rst                                     ),

    .ceu_hcr_in_param                       (           ceu_hcr_in_param                        ),
    .ceu_hcr_in_modifier                    (           ceu_hcr_in_modifier                     ),
    .ceu_hcr_out_dma_addr                   (           ceu_hcr_out_dma_addr                    ),
    .ceu_hcr_token                          (           ceu_hcr_token                           ),
    .ceu_hcr_go                             (           ceu_hcr_go                              ),
    .ceu_hcr_event                          (           ceu_hcr_event                           ),
    .ceu_hcr_op_modifier                    (           ceu_hcr_op_modifier                     ),
    .ceu_hcr_op                             (           ceu_hcr_op                              ),

    .ceu_hcr_out_param                      (           ceu_hcr_out_param                       ),
    .ceu_hcr_status                         (           ceu_hcr_status                          ),
    .ceu_hcr_clear                          (           ceu_hcr_clear                           ),

    .CEU_dma_rd_req_valid                   (           CEU_dma_rd_req_valid                    ),
    .CEU_dma_rd_req_last                    (           CEU_dma_rd_req_last                     ),
    .CEU_dma_rd_req_head                    (           CEU_dma_rd_req_head                     ),
    .CEU_dma_rd_req_data                    (           CEU_dma_rd_req_data                     ),
    .CEU_dma_rd_req_ready                   (           CEU_dma_rd_req_ready                    ),

    .CEU_dma_rd_rsp_valid                   (           CEU_dma_rd_rsp_valid                    ),
    .CEU_dma_rd_rsp_last                    (           CEU_dma_rd_rsp_last                     ),
    .CEU_dma_rd_rsp_head                    (           CEU_dma_rd_rsp_head                     ),
    .CEU_dma_rd_rsp_data                    (           CEU_dma_rd_rsp_data                     ),
    .CEU_dma_rd_rsp_ready                   (           CEU_dma_rd_rsp_ready                    ),

    .CEU_dma_wr_req_valid                   (           CEU_dma_wr_req_valid                    ),
    .CEU_dma_wr_req_last                    (           CEU_dma_wr_req_last                     ),
    .CEU_dma_wr_req_head                    (           CEU_dma_wr_req_head                     ),
    .CEU_dma_wr_req_data                    (           CEU_dma_wr_req_data                     ),
    .CEU_dma_wr_req_ready                   (           CEU_dma_wr_req_ready                    ),

    .SQ_fetch_cxt_ingress_valid             (           SQ_fetch_cxt_ingress_valid              ),
    .SQ_fetch_cxt_ingress_head              (           SQ_fetch_cxt_ingress_head               ),
    .SQ_fetch_cxt_ingress_data              (           SQ_fetch_cxt_ingress_data               ),
    .SQ_fetch_cxt_ingress_start             (           SQ_fetch_cxt_ingress_start              ),
    .SQ_fetch_cxt_ingress_last              (           SQ_fetch_cxt_ingress_last               ),
    .SQ_fetch_cxt_ingress_ready             (           SQ_fetch_cxt_ingress_ready              ),

    .SQ_fetch_cxt_egress_valid              (           SQ_fetch_cxt_egress_valid               ),
    .SQ_fetch_cxt_egress_head               (           SQ_fetch_cxt_egress_head                ),
    .SQ_fetch_cxt_egress_data               (           SQ_fetch_cxt_egress_data                ),
    .SQ_fetch_cxt_egress_start              (           SQ_fetch_cxt_egress_start               ),
    .SQ_fetch_cxt_egress_last               (           SQ_fetch_cxt_egress_last                ),
    .SQ_fetch_cxt_egress_ready              (           SQ_fetch_cxt_egress_ready               ),
 
    .TX_REQ_fetch_cxt_ingress_valid         (           TX_REQ_fetch_cxt_ingress_valid          ),
    .TX_REQ_fetch_cxt_ingress_head          (           TX_REQ_fetch_cxt_ingress_head           ),
    .TX_REQ_fetch_cxt_ingress_data          (           TX_REQ_fetch_cxt_ingress_data           ),
    .TX_REQ_fetch_cxt_ingress_start         (           TX_REQ_fetch_cxt_ingress_start          ),
    .TX_REQ_fetch_cxt_ingress_last          (           TX_REQ_fetch_cxt_ingress_last           ),
    .TX_REQ_fetch_cxt_ingress_ready         (           TX_REQ_fetch_cxt_ingress_ready          ),

    .TX_REQ_fetch_cxt_egress_valid          (           TX_REQ_fetch_cxt_egress_valid           ),
    .TX_REQ_fetch_cxt_egress_head           (           TX_REQ_fetch_cxt_egress_head            ),
    .TX_REQ_fetch_cxt_egress_data           (           TX_REQ_fetch_cxt_egress_data            ),
    .TX_REQ_fetch_cxt_egress_start          (           TX_REQ_fetch_cxt_egress_start           ),
    .TX_REQ_fetch_cxt_egress_last           (           TX_REQ_fetch_cxt_egress_last            ),
    .TX_REQ_fetch_cxt_egress_ready          (           TX_REQ_fetch_cxt_egress_ready           ),

    .RX_REQ_fetch_cxt_ingress_valid         (           RX_REQ_fetch_cxt_ingress_valid          ),
    .RX_REQ_fetch_cxt_ingress_head          (           RX_REQ_fetch_cxt_ingress_head           ),
    .RX_REQ_fetch_cxt_ingress_data          (           RX_REQ_fetch_cxt_ingress_data           ),
    .RX_REQ_fetch_cxt_ingress_start         (           RX_REQ_fetch_cxt_ingress_start          ),
    .RX_REQ_fetch_cxt_ingress_last          (           RX_REQ_fetch_cxt_ingress_last           ),
    .RX_REQ_fetch_cxt_ingress_ready         (           RX_REQ_fetch_cxt_ingress_ready          ),

    .RX_REQ_fetch_cxt_egress_valid          (           RX_REQ_fetch_cxt_egress_valid           ),
    .RX_REQ_fetch_cxt_egress_head           (           RX_REQ_fetch_cxt_egress_head            ),
    .RX_REQ_fetch_cxt_egress_data           (           RX_REQ_fetch_cxt_egress_data            ),
    .RX_REQ_fetch_cxt_egress_start          (           RX_REQ_fetch_cxt_egress_start           ),
    .RX_REQ_fetch_cxt_egress_last           (           RX_REQ_fetch_cxt_egress_last            ),
    .RX_REQ_fetch_cxt_egress_ready          (           RX_REQ_fetch_cxt_egress_ready           ),

    .RX_RESP_fetch_cxt_ingress_valid        (           RX_RESP_fetch_cxt_ingress_valid         ),
    .RX_RESP_fetch_cxt_ingress_head         (           RX_RESP_fetch_cxt_ingress_head          ),
    .RX_RESP_fetch_cxt_ingress_data         (           RX_RESP_fetch_cxt_ingress_data          ),
    .RX_RESP_fetch_cxt_ingress_start        (           RX_RESP_fetch_cxt_ingress_start         ),
    .RX_RESP_fetch_cxt_ingress_last         (           RX_RESP_fetch_cxt_ingress_last          ),
    .RX_RESP_fetch_cxt_ingress_ready        (           RX_RESP_fetch_cxt_ingress_ready         ),

    .RX_RESP_fetch_cxt_egress_valid         (           RX_RESP_fetch_cxt_egress_valid          ),
    .RX_RESP_fetch_cxt_egress_head          (           RX_RESP_fetch_cxt_egress_head           ),
    .RX_RESP_fetch_cxt_egress_data          (           RX_RESP_fetch_cxt_egress_data           ),
    .RX_RESP_fetch_cxt_egress_start         (           RX_RESP_fetch_cxt_egress_start          ),
    .RX_RESP_fetch_cxt_egress_last          (           RX_RESP_fetch_cxt_egress_last           ),
    .RX_RESP_fetch_cxt_egress_ready         (           RX_RESP_fetch_cxt_egress_ready          ),

    .SQ_fetch_mr_ingress_valid              (           SQ_fetch_mr_ingress_valid               ),
    .SQ_fetch_mr_ingress_head               (           SQ_fetch_mr_ingress_head                ), 
    .SQ_fetch_mr_ingress_data               (           SQ_fetch_mr_ingress_data                ),
    .SQ_fetch_mr_ingress_start              (           SQ_fetch_mr_ingress_start               ),
    .SQ_fetch_mr_ingress_last               (           SQ_fetch_mr_ingress_last                ),
    .SQ_fetch_mr_ingress_ready              (           SQ_fetch_mr_ingress_ready               ),

    .SQ_fetch_mr_egress_valid               (           SQ_fetch_mr_egress_valid                ),
    .SQ_fetch_mr_egress_head                (           SQ_fetch_mr_egress_head                 ),
    .SQ_fetch_mr_egress_data                (           SQ_fetch_mr_egress_data                 ),
    .SQ_fetch_mr_egress_start               (           SQ_fetch_mr_egress_start                ),
    .SQ_fetch_mr_egress_last                (           SQ_fetch_mr_egress_last                 ),
    .SQ_fetch_mr_egress_ready               (           SQ_fetch_mr_egress_ready                ),

    .RQ_fetch_mr_ingress_valid              (           RQ_fetch_mr_ingress_valid               ),
    .RQ_fetch_mr_ingress_head               (           RQ_fetch_mr_ingress_head                ),
    .RQ_fetch_mr_ingress_data               (           RQ_fetch_mr_ingress_data                ),
    .RQ_fetch_mr_ingress_start              (           RQ_fetch_mr_ingress_start               ),
    .RQ_fetch_mr_ingress_last               (           RQ_fetch_mr_ingress_last                ),
    .RQ_fetch_mr_ingress_ready              (           RQ_fetch_mr_ingress_ready               ),

    .RQ_fetch_mr_egress_valid               (           RQ_fetch_mr_egress_valid                ),
    .RQ_fetch_mr_egress_head                (           RQ_fetch_mr_egress_head                 ),
    .RQ_fetch_mr_egress_data                (           RQ_fetch_mr_egress_data                 ),
    .RQ_fetch_mr_egress_start               (           RQ_fetch_mr_egress_start                ),
    .RQ_fetch_mr_egress_last                (           RQ_fetch_mr_egress_last                 ),
    .RQ_fetch_mr_egress_ready               (           RQ_fetch_mr_egress_ready                ),

    .TX_REQ_fetch_mr_ingress_valid          (           TX_REQ_fetch_mr_ingress_valid           ),
    .TX_REQ_fetch_mr_ingress_head           (           TX_REQ_fetch_mr_ingress_head            ),
    .TX_REQ_fetch_mr_ingress_data           (           TX_REQ_fetch_mr_ingress_data            ),
    .TX_REQ_fetch_mr_ingress_start          (           TX_REQ_fetch_mr_ingress_start           ),
    .TX_REQ_fetch_mr_ingress_last           (           TX_REQ_fetch_mr_ingress_last            ),
    .TX_REQ_fetch_mr_ingress_ready          (           TX_REQ_fetch_mr_ingress_ready           ),

    .TX_REQ_fetch_mr_egress_valid           (           TX_REQ_fetch_mr_egress_valid            ),
    .TX_REQ_fetch_mr_egress_head            (           TX_REQ_fetch_mr_egress_head             ),
    .TX_REQ_fetch_mr_egress_data            (           TX_REQ_fetch_mr_egress_data             ),
    .TX_REQ_fetch_mr_egress_start           (           TX_REQ_fetch_mr_egress_start            ),
    .TX_REQ_fetch_mr_egress_last            (           TX_REQ_fetch_mr_egress_last             ),
    .TX_REQ_fetch_mr_egress_ready           (           TX_REQ_fetch_mr_egress_ready            ),

    .RX_RESP_fetch_mr_ingress_valid         (           RX_RESP_fetch_mr_ingress_valid          ),
    .RX_RESP_fetch_mr_ingress_head          (           RX_RESP_fetch_mr_ingress_head           ),
    .RX_RESP_fetch_mr_ingress_data          (           RX_RESP_fetch_mr_ingress_data           ),
    .RX_RESP_fetch_mr_ingress_start         (           RX_RESP_fetch_mr_ingress_start          ),
    .RX_RESP_fetch_mr_ingress_last          (           RX_RESP_fetch_mr_ingress_last           ),
    .RX_RESP_fetch_mr_ingress_ready         (           RX_RESP_fetch_mr_ingress_ready          ),

    .RX_RESP_fetch_mr_egress_valid          (           RX_RESP_fetch_mr_egress_valid           ),
    .RX_RESP_fetch_mr_egress_head           (           RX_RESP_fetch_mr_egress_head            ),
    .RX_RESP_fetch_mr_egress_data           (           RX_RESP_fetch_mr_egress_data            ),
    .RX_RESP_fetch_mr_egress_start          (           RX_RESP_fetch_mr_egress_start           ),
    .RX_RESP_fetch_mr_egress_last           (           RX_RESP_fetch_mr_egress_last            ),
    .RX_RESP_fetch_mr_egress_ready          (           RX_RESP_fetch_mr_egress_ready           ),

    .RX_REQ_fetch_mr_ingress_valid          (           RX_REQ_fetch_mr_ingress_valid           ),
    .RX_REQ_fetch_mr_ingress_head           (           RX_REQ_fetch_mr_ingress_head            ),
    .RX_REQ_fetch_mr_ingress_data           (           RX_REQ_fetch_mr_ingress_data            ),
    .RX_REQ_fetch_mr_ingress_start          (           RX_REQ_fetch_mr_ingress_start           ),
    .RX_REQ_fetch_mr_ingress_last           (           RX_REQ_fetch_mr_ingress_last            ),
    .RX_REQ_fetch_mr_ingress_ready          (           RX_REQ_fetch_mr_ingress_ready           ),

    .RX_REQ_fetch_mr_egress_valid           (           RX_REQ_fetch_mr_egress_valid            ),
    .RX_REQ_fetch_mr_egress_head            (           RX_REQ_fetch_mr_egress_head             ),
    .RX_REQ_fetch_mr_egress_data            (           RX_REQ_fetch_mr_egress_data             ),
    .RX_REQ_fetch_mr_egress_start           (           RX_REQ_fetch_mr_egress_start            ),
    .RX_REQ_fetch_mr_egress_last            (           RX_REQ_fetch_mr_egress_last             ),
    .RX_REQ_fetch_mr_egress_ready           (           RX_REQ_fetch_mr_egress_ready            ),

    .QPC_dma_rd_req_valid                   (           QPC_dma_rd_req_valid                    ),
    .QPC_dma_rd_req_head                    (           QPC_dma_rd_req_head                     ),
    .QPC_dma_rd_req_data                    (           QPC_dma_rd_req_data                     ),
    .QPC_dma_rd_req_last                    (           QPC_dma_rd_req_last                     ),
    .QPC_dma_rd_req_ready                   (           QPC_dma_rd_req_ready                    ),

    .QPC_dma_rd_rsp_valid                   (           QPC_dma_rd_rsp_valid                    ),
    .QPC_dma_rd_rsp_head                    (           QPC_dma_rd_rsp_head                     ),
    .QPC_dma_rd_rsp_data                    (           QPC_dma_rd_rsp_data                     ),
    .QPC_dma_rd_rsp_last                    (           QPC_dma_rd_rsp_last                     ),
    .QPC_dma_rd_rsp_ready                   (           QPC_dma_rd_rsp_ready                    ),

    .QPC_dma_wr_req_valid                   (           QPC_dma_wr_req_valid                    ),
    .QPC_dma_wr_req_head                    (           QPC_dma_wr_req_head                     ),
    .QPC_dma_wr_req_data                    (           QPC_dma_wr_req_data                     ),
    .QPC_dma_wr_req_last                    (           QPC_dma_wr_req_last                     ),
    .QPC_dma_wr_req_ready                   (           QPC_dma_wr_req_ready                    ),

    .CQC_dma_rd_req_valid                   (           CQC_dma_rd_req_valid                    ),
    .CQC_dma_rd_req_head                    (           CQC_dma_rd_req_head                     ),
    .CQC_dma_rd_req_data                    (           CQC_dma_rd_req_data                     ),
    .CQC_dma_rd_req_last                    (           CQC_dma_rd_req_last                     ),
    .CQC_dma_rd_req_ready                   (           CQC_dma_rd_req_ready                    ),

    .CQC_dma_rd_rsp_valid                   (           CQC_dma_rd_rsp_valid                    ),
    .CQC_dma_rd_rsp_head                    (           CQC_dma_rd_rsp_head                     ),
    .CQC_dma_rd_rsp_data                    (           CQC_dma_rd_rsp_data                     ),
    .CQC_dma_rd_rsp_last                    (           CQC_dma_rd_rsp_last                     ),
    .CQC_dma_rd_rsp_ready                   (           CQC_dma_rd_rsp_ready                    ),

    .CQC_dma_wr_req_valid                   (           CQC_dma_wr_req_valid                    ),
    .CQC_dma_wr_req_head                    (           CQC_dma_wr_req_head                     ),
    .CQC_dma_wr_req_data                    (           CQC_dma_wr_req_data                     ),
    .CQC_dma_wr_req_last                    (           CQC_dma_wr_req_last                     ),
    .CQC_dma_wr_req_ready                   (           CQC_dma_wr_req_ready                    ),

    .EQC_dma_rd_req_valid                   (           EQC_dma_rd_req_valid                    ),
    .EQC_dma_rd_req_head                    (           EQC_dma_rd_req_head                     ),
    .EQC_dma_rd_req_data                    (           EQC_dma_rd_req_data                     ),
    .EQC_dma_rd_req_last                    (           EQC_dma_rd_req_last                     ),
    .EQC_dma_rd_req_ready                   (           EQC_dma_rd_req_ready                    ),

    .EQC_dma_rd_rsp_valid                   (           EQC_dma_rd_rsp_valid                    ),
    .EQC_dma_rd_rsp_head                    (           EQC_dma_rd_rsp_head                     ),
    .EQC_dma_rd_rsp_data                    (           EQC_dma_rd_rsp_data                     ),
    .EQC_dma_rd_rsp_last                    (           EQC_dma_rd_rsp_last                     ),
    .EQC_dma_rd_rsp_ready                   (           EQC_dma_rd_rsp_ready                    ),

    .EQC_dma_wr_req_valid                   (           EQC_dma_wr_req_valid                    ),
    .EQC_dma_wr_req_head                    (           EQC_dma_wr_req_head                     ),
    .EQC_dma_wr_req_data                    (           EQC_dma_wr_req_data                     ),
    .EQC_dma_wr_req_last                    (           EQC_dma_wr_req_last                     ),
    .EQC_dma_wr_req_ready                   (           EQC_dma_wr_req_ready                    ),

    .MPT_dma_rd_req_valid                   (           MPT_dma_rd_req_valid                    ),
    .MPT_dma_rd_req_head                    (           MPT_dma_rd_req_head                     ),
    .MPT_dma_rd_req_data                    (           MPT_dma_rd_req_data                     ),
    .MPT_dma_rd_req_last                    (           MPT_dma_rd_req_last                     ),
    .MPT_dma_rd_req_ready                   (           MPT_dma_rd_req_ready                    ),

    .MPT_dma_rd_rsp_valid                   (           MPT_dma_rd_rsp_valid                    ),
    .MPT_dma_rd_rsp_head                    (           MPT_dma_rd_rsp_head                     ),
    .MPT_dma_rd_rsp_data                    (           MPT_dma_rd_rsp_data                     ),
    .MPT_dma_rd_rsp_last                    (           MPT_dma_rd_rsp_last                     ),
    .MPT_dma_rd_rsp_ready                   (           MPT_dma_rd_rsp_ready                    ),

    .MPT_dma_wr_req_valid                   (           MPT_dma_wr_req_valid                    ),
    .MPT_dma_wr_req_head                    (           MPT_dma_wr_req_head                     ),
    .MPT_dma_wr_req_data                    (           MPT_dma_wr_req_data                     ),
    .MPT_dma_wr_req_last                    (           MPT_dma_wr_req_last                     ),
    .MPT_dma_wr_req_ready                   (           MPT_dma_wr_req_ready                    ),

    .MTT_dma_rd_req_valid                   (           MTT_dma_rd_req_valid                    ),
    .MTT_dma_rd_req_head                    (           MTT_dma_rd_req_head                     ),
    .MTT_dma_rd_req_data                    (           MTT_dma_rd_req_data                     ),
    .MTT_dma_rd_req_last                    (           MTT_dma_rd_req_last                     ),
    .MTT_dma_rd_req_ready                   (           MTT_dma_rd_req_ready                    ),

    .MTT_dma_rd_rsp_valid                   (           MTT_dma_rd_rsp_valid                    ),
    .MTT_dma_rd_rsp_head                    (           MTT_dma_rd_rsp_head                     ),
    .MTT_dma_rd_rsp_data                    (           MTT_dma_rd_rsp_data                     ),
    .MTT_dma_rd_rsp_last                    (           MTT_dma_rd_rsp_last                     ),
    .MTT_dma_rd_rsp_ready                   (           MTT_dma_rd_rsp_ready                    ),

    .MTT_dma_wr_req_valid                   (           MTT_dma_wr_req_valid                    ),
    .MTT_dma_wr_req_head                    (           MTT_dma_wr_req_head                     ),
    .MTT_dma_wr_req_data                    (           MTT_dma_wr_req_data                     ),
    .MTT_dma_wr_req_last                    (           MTT_dma_wr_req_last                     ),
    .MTT_dma_wr_req_ready                   (           MTT_dma_wr_req_ready                    )
);

RPCSubsystem #(
    .INGRESS_CXT_HEAD_WIDTH                  (          INGRESS_CXT_HEAD_WIDTH                  ),
    .INGRESS_CXT_DATA_WIDTH                  (          INGRESS_CXT_DATA_WIDTH                  ),
    .EGRESS_CXT_HEAD_WIDTH                   (          EGRESS_CXT_HEAD_WIDTH                   ),
    .EGRESS_CXT_DATA_WIDTH                   (          EGRESS_CXT_DATA_WIDTH                   ),

    .INGRESS_MR_HEAD_WIDTH                   (          INGRESS_MR_HEAD_WIDTH                   ),
    .INGRESS_MR_DATA_WIDTH                   (          INGRESS_MR_DATA_WIDTH                   ),
    .EGRESS_MR_HEAD_WIDTH                    (          EGRESS_MR_HEAD_WIDTH                    ),
    .EGRESS_MR_DATA_WIDTH                    (          EGRESS_MR_DATA_WIDTH                    )
)
RPCSubsystem_Inst
(
    .clk                                    (           user_clk                                     ),
    .rst                                    (           user_rst                                     ),

    .TX_REQ_sub_wqe_valid                   (           TX_REQ_sub_wqe_valid                    ),
    .TX_REQ_sub_wqe_meta                    (           TX_REQ_sub_wqe_meta                     ),
    .TX_REQ_sub_wqe_ready                   (           TX_REQ_sub_wqe_ready                    ),

    .TX_REQ_cq_req_valid                    (           TX_REQ_cq_req_valid                     ),
    .TX_REQ_cq_req_head                     (           TX_REQ_cq_req_head                      ),
    .TX_REQ_cq_req_ready                    (           TX_REQ_cq_req_ready                     ),

    .TX_REQ_cq_resp_valid                   (           TX_REQ_cq_resp_valid                    ),
    .TX_REQ_cq_resp_head                    (           TX_REQ_cq_resp_head                     ),
    .TX_REQ_cq_resp_ready                   (           TX_REQ_cq_resp_ready                    ),

    .TX_REQ_eq_req_valid                    (           TX_REQ_eq_req_valid                     ),
    .TX_REQ_eq_req_head                     (           TX_REQ_eq_req_head                      ),
    .TX_REQ_eq_req_ready                    (           TX_REQ_eq_req_ready                     ),
 
    .TX_REQ_eq_resp_valid                   (           TX_REQ_eq_resp_valid                    ),
    .TX_REQ_eq_resp_head                    (           TX_REQ_eq_resp_head                     ),
    .TX_REQ_eq_resp_ready                   (           TX_REQ_eq_resp_ready                    ),

    .RQ_wqe_req_valid                       (           RQ_wqe_req_valid                        ),
    .RQ_wqe_req_head                        (           RQ_wqe_req_head                         ),
    .RQ_wqe_req_start                       (           RQ_wqe_req_start                        ),
    .RQ_wqe_req_last                        (           RQ_wqe_req_last                         ),
    .RQ_wqe_req_ready                       (           RQ_wqe_req_ready                        ),

    .RQ_wqe_resp_valid                      (           RQ_wqe_resp_valid                       ),
    .RQ_wqe_resp_head                       (           RQ_wqe_resp_head                        ),
    .RQ_wqe_resp_data                       (           RQ_wqe_resp_data                        ),
    .RQ_wqe_resp_start                      (           RQ_wqe_resp_start                       ),
    .RQ_wqe_resp_last                       (           RQ_wqe_resp_last                        ),
    .RQ_wqe_resp_ready                      (           RQ_wqe_resp_ready                       ),

    .RQ_cache_offset_wen                    (           RQ_cache_offset_wen                     ),
    .RQ_cache_offset_addr                   (           RQ_cache_offset_addr                    ),
    .RQ_cache_offset_din                    (           RQ_cache_offset_din                     ),
    .RQ_cache_offset_dout                   (           RQ_cache_offset_dout                    ),

    .RQ_offset_wen                          (           RQ_offset_wen                           ),
    .RQ_offset_addr                         (           RQ_offset_addr                          ),
    .RQ_offset_din                          (           RQ_offset_din                           ),
    .RQ_offset_dout                         (           RQ_offset_dout                          ),

    .RQ_cache_owned_wen                     (           RQ_cache_owned_wen                      ),
    .RQ_cache_owned_addr                    (           RQ_cache_owned_addr                     ),
    .RQ_cache_owned_din                     (           RQ_cache_owned_din                      ),
    .RQ_cache_owned_dout                    (           RQ_cache_owned_dout                     ),

    .RX_REQ_cq_req_valid                    (           RX_REQ_cq_req_valid                     ),
    .RX_REQ_cq_req_head                     (           RX_REQ_cq_req_head                      ),
    .RX_REQ_cq_req_ready                    (           RX_REQ_cq_req_ready                     ),

    .RX_REQ_cq_resp_valid                   (           RX_REQ_cq_resp_valid                    ),
    .RX_REQ_cq_resp_head                    (           RX_REQ_cq_resp_head                     ),
    .RX_REQ_cq_resp_ready                   (           RX_REQ_cq_resp_ready                    ),

    .RX_REQ_eq_req_valid                    (           RX_REQ_eq_req_valid                     ),
    .RX_REQ_eq_req_head                     (           RX_REQ_eq_req_head                      ),
    .RX_REQ_eq_req_ready                    (           RX_REQ_eq_req_ready                     ),
 
    .RX_REQ_eq_resp_valid                   (           RX_REQ_eq_resp_valid                    ),
    .RX_REQ_eq_resp_head                    (           RX_REQ_eq_resp_head                     ),
    .RX_REQ_eq_resp_ready                   (           RX_REQ_eq_resp_ready                    ),

    .RX_RESP_cq_req_valid                   (           RX_RESP_cq_req_valid                    ),
    .RX_RESP_cq_req_head                    (           RX_RESP_cq_req_head                     ),
    .RX_RESP_cq_req_ready                   (           RX_RESP_cq_req_ready                    ),

    .RX_RESP_cq_resp_valid                  (           RX_RESP_cq_resp_valid                   ),
    .RX_RESP_cq_resp_head                   (           RX_RESP_cq_resp_head                    ),
    .RX_RESP_cq_resp_ready                  (           RX_RESP_cq_resp_ready                   ),

    .RX_RESP_eq_req_valid                   (           RX_RESP_eq_req_valid                    ),
    .RX_RESP_eq_req_head                    (           RX_RESP_eq_req_head                     ),
    .RX_RESP_eq_req_ready                   (           RX_RESP_eq_req_ready                    ),
 
    .RX_RESP_eq_resp_valid                  (           RX_RESP_eq_resp_valid                   ),
    .RX_RESP_eq_resp_head                   (           RX_RESP_eq_resp_head                    ),
    .RX_RESP_eq_resp_ready                  (           RX_RESP_eq_resp_ready                   ),

    .TX_REQ_fetch_cxt_ingress_valid         (           TX_REQ_fetch_cxt_ingress_valid          ),
    .TX_REQ_fetch_cxt_ingress_head          (           TX_REQ_fetch_cxt_ingress_head           ),
    .TX_REQ_fetch_cxt_ingress_data          (           TX_REQ_fetch_cxt_ingress_data           ),
    .TX_REQ_fetch_cxt_ingress_start         (           TX_REQ_fetch_cxt_ingress_start          ),
    .TX_REQ_fetch_cxt_ingress_last          (           TX_REQ_fetch_cxt_ingress_last           ),
    .TX_REQ_fetch_cxt_ingress_ready         (           TX_REQ_fetch_cxt_ingress_ready          ),

    .TX_REQ_fetch_cxt_egress_valid          (           TX_REQ_fetch_cxt_egress_valid           ),
    .TX_REQ_fetch_cxt_egress_head           (           TX_REQ_fetch_cxt_egress_head            ),
    .TX_REQ_fetch_cxt_egress_data           (           TX_REQ_fetch_cxt_egress_data            ),
    .TX_REQ_fetch_cxt_egress_start          (           TX_REQ_fetch_cxt_egress_start           ),
    .TX_REQ_fetch_cxt_egress_last           (           TX_REQ_fetch_cxt_egress_last            ),
    .TX_REQ_fetch_cxt_egress_ready          (           TX_REQ_fetch_cxt_egress_ready           ),

    .RX_REQ_fetch_cxt_ingress_valid         (           RX_REQ_fetch_cxt_ingress_valid          ),
    .RX_REQ_fetch_cxt_ingress_head          (           RX_REQ_fetch_cxt_ingress_head           ),
    .RX_REQ_fetch_cxt_ingress_data          (           RX_REQ_fetch_cxt_ingress_data           ),
    .RX_REQ_fetch_cxt_ingress_start         (           RX_REQ_fetch_cxt_ingress_start          ),
    .RX_REQ_fetch_cxt_ingress_last          (           RX_REQ_fetch_cxt_ingress_last           ),
    .RX_REQ_fetch_cxt_ingress_ready         (           RX_REQ_fetch_cxt_ingress_ready          ),

    .RX_REQ_fetch_cxt_egress_valid          (           RX_REQ_fetch_cxt_egress_valid           ),
    .RX_REQ_fetch_cxt_egress_head           (           RX_REQ_fetch_cxt_egress_head            ),
    .RX_REQ_fetch_cxt_egress_data           (           RX_REQ_fetch_cxt_egress_data            ),
    .RX_REQ_fetch_cxt_egress_start          (           RX_REQ_fetch_cxt_egress_start           ),
    .RX_REQ_fetch_cxt_egress_last           (           RX_REQ_fetch_cxt_egress_last            ),
    .RX_REQ_fetch_cxt_egress_ready          (           RX_REQ_fetch_cxt_egress_ready           ),

    .RX_RESP_fetch_cxt_ingress_valid        (           RX_RESP_fetch_cxt_ingress_valid         ),
    .RX_RESP_fetch_cxt_ingress_head         (           RX_RESP_fetch_cxt_ingress_head          ),
    .RX_RESP_fetch_cxt_ingress_data         (           RX_RESP_fetch_cxt_ingress_data          ),
    .RX_RESP_fetch_cxt_ingress_start        (           RX_RESP_fetch_cxt_ingress_start         ),
    .RX_RESP_fetch_cxt_ingress_last         (           RX_RESP_fetch_cxt_ingress_last          ),
    .RX_RESP_fetch_cxt_ingress_ready        (           RX_RESP_fetch_cxt_ingress_ready         ),

    .RX_RESP_fetch_cxt_egress_valid         (           RX_RESP_fetch_cxt_egress_valid          ),
    .RX_RESP_fetch_cxt_egress_head          (           RX_RESP_fetch_cxt_egress_head           ),
    .RX_RESP_fetch_cxt_egress_data          (           RX_RESP_fetch_cxt_egress_data           ),
    .RX_RESP_fetch_cxt_egress_start         (           RX_RESP_fetch_cxt_egress_start          ),
    .RX_RESP_fetch_cxt_egress_last          (           RX_RESP_fetch_cxt_egress_last           ),
    .RX_RESP_fetch_cxt_egress_ready         (           RX_RESP_fetch_cxt_egress_ready          ),

    .TX_REQ_fetch_mr_ingress_valid          (           TX_REQ_fetch_mr_ingress_valid           ),
    .TX_REQ_fetch_mr_ingress_head           (           TX_REQ_fetch_mr_ingress_head            ),
    .TX_REQ_fetch_mr_ingress_data           (           TX_REQ_fetch_mr_ingress_data            ),
    .TX_REQ_fetch_mr_ingress_start          (           TX_REQ_fetch_mr_ingress_start           ),
    .TX_REQ_fetch_mr_ingress_last           (           TX_REQ_fetch_mr_ingress_last            ),
    .TX_REQ_fetch_mr_ingress_ready          (           TX_REQ_fetch_mr_ingress_ready           ),

    .TX_REQ_fetch_mr_egress_valid           (           TX_REQ_fetch_mr_egress_valid            ),
    .TX_REQ_fetch_mr_egress_head            (           TX_REQ_fetch_mr_egress_head             ),
    .TX_REQ_fetch_mr_egress_data            (           TX_REQ_fetch_mr_egress_data             ),
    .TX_REQ_fetch_mr_egress_start           (           TX_REQ_fetch_mr_egress_start            ),
    .TX_REQ_fetch_mr_egress_last            (           TX_REQ_fetch_mr_egress_last             ),
    .TX_REQ_fetch_mr_egress_ready           (           TX_REQ_fetch_mr_egress_ready            ),

    .RX_RESP_fetch_mr_ingress_valid         (           RX_RESP_fetch_mr_ingress_valid          ),
    .RX_RESP_fetch_mr_ingress_head          (           RX_RESP_fetch_mr_ingress_head           ),
    .RX_RESP_fetch_mr_ingress_data          (           RX_RESP_fetch_mr_ingress_data           ),
    .RX_RESP_fetch_mr_ingress_start         (           RX_RESP_fetch_mr_ingress_start          ),
    .RX_RESP_fetch_mr_ingress_last          (           RX_RESP_fetch_mr_ingress_last           ),
    .RX_RESP_fetch_mr_ingress_ready         (           RX_RESP_fetch_mr_ingress_ready          ),

    .RX_RESP_fetch_mr_egress_valid          (           RX_RESP_fetch_mr_egress_valid           ),
    .RX_RESP_fetch_mr_egress_head           (           RX_RESP_fetch_mr_egress_head            ),
    .RX_RESP_fetch_mr_egress_data           (           RX_RESP_fetch_mr_egress_data            ),
    .RX_RESP_fetch_mr_egress_start          (           RX_RESP_fetch_mr_egress_start           ),
    .RX_RESP_fetch_mr_egress_last           (           RX_RESP_fetch_mr_egress_last            ),
    .RX_RESP_fetch_mr_egress_ready          (           RX_RESP_fetch_mr_egress_ready           ),

    .RX_REQ_fetch_mr_ingress_valid          (           RX_REQ_fetch_mr_ingress_valid           ),
    .RX_REQ_fetch_mr_ingress_head           (           RX_REQ_fetch_mr_ingress_head            ),
    .RX_REQ_fetch_mr_ingress_data           (           RX_REQ_fetch_mr_ingress_data            ),
    .RX_REQ_fetch_mr_ingress_start          (           RX_REQ_fetch_mr_ingress_start           ),
    .RX_REQ_fetch_mr_ingress_last           (           RX_REQ_fetch_mr_ingress_last            ),
    .RX_REQ_fetch_mr_ingress_ready          (           RX_REQ_fetch_mr_ingress_ready           ),

    .RX_REQ_fetch_mr_egress_valid           (           RX_REQ_fetch_mr_egress_valid            ),
    .RX_REQ_fetch_mr_egress_head            (           RX_REQ_fetch_mr_egress_head             ),
    .RX_REQ_fetch_mr_egress_data            (           RX_REQ_fetch_mr_egress_data             ),
    .RX_REQ_fetch_mr_egress_start           (           RX_REQ_fetch_mr_egress_start            ),
    .RX_REQ_fetch_mr_egress_last            (           RX_REQ_fetch_mr_egress_last             ),
    .RX_REQ_fetch_mr_egress_ready           (           RX_REQ_fetch_mr_egress_ready            ),

    .TX_REQ_dma_wr_req_valid                (           TX_REQ_dma_wr_req_valid                 ),
    .TX_REQ_dma_wr_req_last                 (           TX_REQ_dma_wr_req_last                  ),
    .TX_REQ_dma_wr_req_head                 (           TX_REQ_dma_wr_req_head                  ),
    .TX_REQ_dma_wr_req_data                 (           TX_REQ_dma_wr_req_data                  ),
    .TX_REQ_dma_wr_req_ready                (           TX_REQ_dma_wr_req_ready                 ),

    .RX_REQ_dma_wr_req_valid                (           RX_REQ_dma_wr_req_valid                 ),
    .RX_REQ_dma_wr_req_last                 (           RX_REQ_dma_wr_req_last                  ),
    .RX_REQ_dma_wr_req_head                 (           RX_REQ_dma_wr_req_head                  ),
    .RX_REQ_dma_wr_req_data                 (           RX_REQ_dma_wr_req_data                  ),
    .RX_REQ_dma_wr_req_ready                (           RX_REQ_dma_wr_req_ready                 ),

    .RX_RESP_dma_wr_req_valid               (           RX_RESP_dma_wr_req_valid                ),
    .RX_RESP_dma_wr_req_last                (           RX_RESP_dma_wr_req_last                 ),
    .RX_RESP_dma_wr_req_head                (           RX_RESP_dma_wr_req_head                 ),
    .RX_RESP_dma_wr_req_data                (           RX_RESP_dma_wr_req_data                 ),
    .RX_RESP_dma_wr_req_ready               (           RX_RESP_dma_wr_req_ready                ),

    .TX_REQ_dma_rd_req_valid                (           TX_REQ_dma_rd_req_valid                 ),
    .TX_REQ_dma_rd_req_head                 (           TX_REQ_dma_rd_req_head                  ),
    .TX_REQ_dma_rd_req_data                 (           TX_REQ_dma_rd_req_data                  ),
    .TX_REQ_dma_rd_req_last                 (           TX_REQ_dma_rd_req_last                  ),
    .TX_REQ_dma_rd_req_ready                (           TX_REQ_dma_rd_req_ready                 ),
    
    .TX_REQ_dma_rd_rsp_valid               (           TX_REQ_dma_rd_rsp_valid                ),
    .TX_REQ_dma_rd_rsp_head                (           TX_REQ_dma_rd_rsp_head                 ),
    .TX_REQ_dma_rd_rsp_data                (           TX_REQ_dma_rd_rsp_data                 ),
    .TX_REQ_dma_rd_rsp_last                (           TX_REQ_dma_rd_rsp_last                 ),
    .TX_REQ_dma_rd_rsp_ready               (           TX_REQ_dma_rd_rsp_ready                ),

    .TX_RESP_dma_rd_req_valid               (           TX_RESP_dma_rd_req_valid                ),
    .TX_RESP_dma_rd_req_head                (           TX_RESP_dma_rd_req_head                 ),
    .TX_RESP_dma_rd_req_data                (           TX_RESP_dma_rd_req_data                 ),
    .TX_RESP_dma_rd_req_last                (           TX_RESP_dma_rd_req_last                 ),
    .TX_RESP_dma_rd_req_ready               (           TX_RESP_dma_rd_req_ready                ),
    
    .TX_RESP_dma_rd_rsp_valid              (           TX_RESP_dma_rd_rsp_valid               ),
    .TX_RESP_dma_rd_rsp_head               (           TX_RESP_dma_rd_rsp_head                ),
    .TX_RESP_dma_rd_rsp_data               (           TX_RESP_dma_rd_rsp_data                ),
    .TX_RESP_dma_rd_rsp_last               (           TX_RESP_dma_rd_rsp_last                ),
    .TX_RESP_dma_rd_rsp_ready              (           TX_RESP_dma_rd_rsp_ready               ),

    .TX_egress_pkt_valid                    (           TX_egress_pkt_valid                     ),
    .TX_egress_pkt_head                     (           TX_egress_pkt_head                      ),
    .TX_egress_pkt_ready                    (           TX_egress_pkt_ready                     ),

    .TX_insert_req_valid                    (           TX_non_inline_insert_req_valid          ),
    .TX_insert_req_start                    (           TX_non_inline_insert_req_start          ),
    .TX_insert_req_last                     (           TX_non_inline_insert_req_last           ),
    .TX_insert_req_head                     (           TX_non_inline_insert_req_head           ),
    .TX_insert_req_data                     (           TX_non_inline_insert_req_data           ),
    .TX_insert_req_ready                    (           TX_non_inline_insert_req_ready          ),

    .TX_insert_resp_valid                   (           TX_non_inline_insert_resp_valid         ),
    .TX_insert_resp_data                    (           TX_non_inline_insert_resp_data          ),

    .RX_ingress_pkt_valid                   (           RX_ingress_pkt_valid                    ),
    .RX_ingress_pkt_head                    (           RX_ingress_pkt_head                     ),
    .RX_ingress_pkt_ready                   (           RX_ingress_pkt_ready                    ),

    .RX_delete_req_valid                    (           RX_delete_req_valid                     ),
    .RX_delete_req_head                     (           RX_delete_req_head                      ),
    .RX_delete_req_ready                    (           RX_delete_req_ready                     ),

    .RX_delete_resp_valid                   (           RX_delete_resp_valid                    ),
    .RX_delete_resp_start                   (           RX_delete_resp_start                    ),
    .RX_delete_resp_last                    (           RX_delete_resp_last                     ),
    .RX_delete_resp_data                    (           RX_delete_resp_data                     ),
    .RX_delete_resp_ready                   (           RX_delete_resp_ready                    )
);

TransportSubsystem TransportSubsystem_Inst(
    .user_clk                               (           user_clk                                ),
    .user_rst                               (           user_rst                                ),

    .mac_tx_clk                             (           mac_tx_clk                              ),
    .mac_tx_rst                             (           mac_tx_rst                              ),

    .mac_rx_clk                             (           mac_rx_clk                              ),
    .mac_rx_rst                             (           mac_rx_rst                              ),

//Interface with RPCSubsystem
    .TX_egress_pkt_valid                    (           TX_egress_pkt_valid                     ),
    .TX_egress_pkt_head                     (           TX_egress_pkt_head                      ),
    .TX_egress_pkt_ready                    (           TX_egress_pkt_ready                     ),

    .TX_insert_req_valid                    (           TX_insert_req_valid                     ),
    .TX_insert_req_start                    (           TX_insert_req_start                     ),
    .TX_insert_req_last                     (           TX_insert_req_last                      ),
    .TX_insert_req_head                     (           TX_insert_req_head                      ),
    .TX_insert_req_data                     (           TX_insert_req_data                      ),
    .TX_insert_req_ready                    (           TX_insert_req_ready                     ),

    .TX_insert_resp_valid                   (           TX_insert_resp_valid                    ),
    .TX_insert_resp_data                    (           TX_insert_resp_data                     ),

    .RX_ingress_pkt_valid                   (           RX_ingress_pkt_valid                    ),
    .RX_ingress_pkt_head                    (           RX_ingress_pkt_head                     ),
    .RX_ingress_pkt_ready                   (           RX_ingress_pkt_ready                    ),

    .RX_delete_req_valid                    (           RX_delete_req_valid                     ),
    .RX_delete_req_head                     (           RX_delete_req_head                      ),
    .RX_delete_req_ready                    (           RX_delete_req_ready                     ),

    .RX_delete_resp_valid                   (           RX_delete_resp_valid                    ),
    .RX_delete_resp_start                   (           RX_delete_resp_start                    ),
    .RX_delete_resp_last                    (           RX_delete_resp_last                     ),
    .RX_delete_resp_data                    (           RX_delete_resp_data                     ),
    .RX_delete_resp_ready                   (           RX_delete_resp_ready                    ),

//Interface with MAC
    .mac_tx_valid                           (           mac_tx_valid                            ),
    .mac_tx_ready                           (           mac_tx_ready                            ),
    .mac_tx_start                           (           mac_tx_start                            ),
    .mac_tx_last                            (           mac_tx_last                             ),
    .mac_tx_keep                            (           mac_tx_keep                             ),
    .mac_tx_user                            (           mac_tx_user                             ),
    .mac_tx_data                            (           mac_tx_data                             ),

    .mac_rx_valid                           (           mac_rx_valid                            ),
    .mac_rx_ready                           (           mac_rx_ready                            ),
    .mac_rx_start                           (           mac_rx_start                            ),
    .mac_rx_last                            (           mac_rx_last                             ),
    .mac_rx_keep                            (           mac_rx_keep                             ),
    .mac_rx_user                            (           mac_rx_user                             ),
    .mac_rx_data                            (           mac_rx_data                             )
);


DynamicBufferInsertArbiter DynamicBufferInsertArbiter_Inst(
    .clk                        (           user_clk                                         ),
    .rst                        (           user_rst                                         ),

    .chnl_0_req_valid           (           TX_non_inline_insert_req_valid              ),
    .chnl_0_req_start           (           TX_non_inline_insert_req_start              ),
    .chnl_0_req_last            (           TX_non_inline_insert_req_last               ),
    .chnl_0_req_head            (           TX_non_inline_insert_req_head               ),
    .chnl_0_req_data            (           TX_non_inline_insert_req_data               ),
    .chnl_0_req_ready           (           TX_non_inline_insert_req_ready              ),

    .chnl_0_resp_valid          (           TX_non_inline_insert_resp_valid             ),
    .chnl_0_resp_data           (           TX_non_inline_insert_resp_data              ),

    .chnl_1_req_valid           (           TX_inline_insert_req_valid                  ),
    .chnl_1_req_start           (           TX_inline_insert_req_start                  ),
    .chnl_1_req_last            (           TX_inline_insert_req_last                   ),
    .chnl_1_req_head            (           TX_inline_insert_req_head                   ),
    .chnl_1_req_data            (           TX_inline_insert_req_data                   ),
    .chnl_1_req_ready           (           TX_inline_insert_req_ready                  ),

    .chnl_1_resp_valid          (           TX_inline_insert_resp_valid                 ),
    .chnl_1_resp_data           (           TX_inline_insert_resp_data                  ),

    .insert_req_valid           (           TX_insert_req_valid                         ),
    .insert_req_start           (           TX_insert_req_start                         ),
    .insert_req_last            (           TX_insert_req_last                          ),
    .insert_req_head            (           TX_insert_req_head                          ),
    .insert_req_data            (           TX_insert_req_data                          ),
    .insert_req_ready           (           TX_insert_req_ready                         ),

    .insert_resp_valid          (           TX_insert_resp_valid                        ),
    .insert_resp_data           (           TX_insert_resp_data                         )
);

`ifdef ILA_ON
ila_comm_res ila_comm_res_inst(
	.clk  		(	user_clk							),

	.probe0 	(	SQ_fetch_cxt_ingress_valid			),
	.probe1 	(	SQ_fetch_cxt_egress_valid			),
	.probe2 	(	TX_REQ_fetch_cxt_ingress_valid		),
	.probe3 	(	TX_REQ_fetch_cxt_egress_valid		),
	.probe4 	(	RX_REQ_fetch_cxt_ingress_valid		),
	.probe5 	(	RX_REQ_fetch_cxt_egress_valid		),
	.probe6 	(	RX_RESP_fetch_cxt_ingress_valid		),
	.probe7 	(	RX_RESP_fetch_cxt_egress_valid		),
	.probe8 	(	SQ_fetch_mr_ingress_valid			),
	.probe9 	(	SQ_fetch_mr_egress_valid			),
	.probe10 	(	RQ_fetch_mr_ingress_valid			),
	.probe11 	(	RQ_fetch_mr_egress_valid			),
	.probe12 	(	TX_REQ_fetch_mr_ingress_valid		),
	.probe13 	(	TX_REQ_fetch_mr_egress_valid		),
	.probe14 	(	RX_RESP_fetch_mr_ingress_valid		),
	.probe15 	(	RX_RESP_fetch_mr_egress_valid		),
	.probe16 	(	RX_REQ_fetch_mr_ingress_valid		),
	.probe17 	(	RX_REQ_fetch_mr_egress_valid		)
);
`endif
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/


/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
/*------------------------------------------- Variables Decode : End ------------------------------------------------*/

endmodule