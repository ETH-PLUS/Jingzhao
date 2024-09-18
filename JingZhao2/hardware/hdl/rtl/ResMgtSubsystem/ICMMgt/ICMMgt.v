/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ICMMgt
Author:     YangFan
Function:   Manage ICM Data and Provides ICM Access Interface.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module ICMMgt
(
	input 	wire 															clk,
	input 	wire 															rst,

//CEU Request
    input   wire                                                            ceu_cxt_req_valid,
    input   wire    [`CEU_CXT_HEAD_WIDTH - 1 : 0]                           ceu_cxt_req_head,
    input   wire                                                            ceu_cxt_req_last,
    input   wire    [`CEU_CXT_DATA_WIDTH - 1 : 0]                           ceu_cxt_req_data,
    output  wire                                                            ceu_cxt_req_ready,

//CEU Response
    output  wire                                                            ceu_cxt_rsp_valid,
    output  wire    [`CEU_CXT_HEAD_WIDTH - 1 : 0]                           ceu_cxt_rsp_head,
    output  wire                                                            ceu_cxt_rsp_last,
    output  wire    [`CEU_CXT_DATA_WIDTH - 1 : 0]                           ceu_cxt_rsp_data,
    input   wire                                                            ceu_cxt_rsp_ready,

//Request channels
    input   wire                                                            SQ_cxt_req_valid,
    input   wire    [`CXT_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                           SQ_cxt_req_head,
    input   wire    [`CXT_CMD_DATA_WIDTH - 1 : 0]                           SQ_cxt_req_data,
    output  wire                                                            SQ_cxt_req_ready,

    input   wire                                                            TX_REQ_cxt_req_valid,
    input   wire    [`CXT_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                           TX_REQ_cxt_req_head,
    input   wire    [`CXT_CMD_DATA_WIDTH - 1 : 0]                           TX_REQ_cxt_req_data,
    output  wire                                                            TX_REQ_cxt_req_ready,

    input   wire                                                            RX_REQ_cxt_req_valid,
    input   wire    [`CXT_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                           RX_REQ_cxt_req_head,
    input   wire    [`CXT_CMD_DATA_WIDTH - 1 : 0]                           RX_REQ_cxt_req_data,
    output  wire                                                            RX_REQ_cxt_req_ready,

    input   wire                                                            RX_RESP_cxt_req_valid,
    input   wire    [`CXT_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                           RX_RESP_cxt_req_head,
    input   wire    [`CXT_CMD_DATA_WIDTH - 1 : 0]                           RX_RESP_cxt_req_data,
    output  wire                                                            RX_RESP_cxt_req_ready,

//Response channels
    output  wire                                                            SQ_cxt_rsp_valid,
    output  wire    [`CXT_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                          SQ_cxt_rsp_head,
    output  wire    [`CXT_RESP_DATA_WIDTH - 1 : 0]                          SQ_cxt_rsp_data,
    input   wire                                                            SQ_cxt_rsp_ready,

    output  wire                                                            TX_REQ_cxt_rsp_valid,
    output  wire    [`CXT_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                          TX_REQ_cxt_rsp_head,
    output  wire    [`CXT_RESP_DATA_WIDTH - 1 : 0]                          TX_REQ_cxt_rsp_data,
    input   wire                                                            TX_REQ_cxt_rsp_ready,

    output  wire                                                            RX_REQ_cxt_rsp_valid,
    output  wire    [`CXT_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                          RX_REQ_cxt_rsp_head,
    output  wire    [`CXT_RESP_DATA_WIDTH - 1 : 0]                          RX_REQ_cxt_rsp_data,
    input   wire                                                            RX_REQ_cxt_rsp_ready,

    output  wire                                                            RX_RESP_cxt_rsp_valid,
    output  wire    [`CXT_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                          RX_RESP_cxt_rsp_head,
    output  wire    [`CXT_RESP_DATA_WIDTH - 1 : 0]                          RX_RESP_cxt_rsp_data,
    input   wire                                                            RX_RESP_cxt_rsp_ready,

//Interface with DMA
    output  wire                                                            qpc_dma_rd_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                               qpc_dma_rd_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                               qpc_dma_rd_req_data,
    output  wire                                                            qpc_dma_rd_req_last,
    input   wire                                                            qpc_dma_rd_req_ready,

    input   wire                                                            qpc_dma_rd_rsp_valid,
    input   wire    [`DMA_HEAD_WIDTH - 1 : 0]                               qpc_dma_rd_rsp_head,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                               qpc_dma_rd_rsp_data,
    input   wire                                                            qpc_dma_rd_rsp_last,
    output  wire                                                            qpc_dma_rd_rsp_ready,

    output  wire                                                            qpc_dma_wr_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                               qpc_dma_wr_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                               qpc_dma_wr_req_data,
    output  wire                                                            qpc_dma_wr_req_last,
    input   wire                                                            qpc_dma_wr_req_ready,

    output  wire                                                            cqc_dma_rd_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                               cqc_dma_rd_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                               cqc_dma_rd_req_data,
    output  wire                                                            cqc_dma_rd_req_last,
    input   wire                                                            cqc_dma_rd_req_ready,

    input   wire                                                            cqc_dma_rd_rsp_valid,
    input   wire    [`DMA_HEAD_WIDTH - 1 : 0]                               cqc_dma_rd_rsp_head,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                               cqc_dma_rd_rsp_data,
    input   wire                                                            cqc_dma_rd_rsp_last,
    output  wire                                                            cqc_dma_rd_rsp_ready,

    output  wire                                                            cqc_dma_wr_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                               cqc_dma_wr_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                               cqc_dma_wr_req_data,
    output  wire                                                            cqc_dma_wr_req_last,
    input   wire                                                            cqc_dma_wr_req_ready,

    output  wire                                                            eqc_dma_rd_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                               eqc_dma_rd_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                               eqc_dma_rd_req_data,
    output  wire                                                            eqc_dma_rd_req_last,
    input   wire                                                            eqc_dma_rd_req_ready,

    input   wire                                                            eqc_dma_rd_rsp_valid,
    input   wire    [`DMA_HEAD_WIDTH - 1 : 0]                               eqc_dma_rd_rsp_head,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                               eqc_dma_rd_rsp_data,
    input   wire                                                            eqc_dma_rd_rsp_last,
    output  wire                                                            eqc_dma_rd_rsp_ready,

    output  wire                                                            eqc_dma_wr_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                               eqc_dma_wr_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                               eqc_dma_wr_req_data,
    output  wire                                                            eqc_dma_wr_req_last,
    input   wire                                                            eqc_dma_wr_req_ready,

//Interface with CEU
    input   wire                                                            ceu_mr_req_valid,
    input   wire    [`CEU_MR_HEAD_WIDTH - 1 : 0]                            ceu_mr_req_head,
    input   wire                                                            ceu_mr_req_last,
    input   wire    [`CEU_MR_DATA_WIDTH - 1 : 0]                            ceu_mr_req_data,
    output  wire                                                            ceu_mr_req_ready,

//Interface with SQMgt
    input   wire                                                        	SQ_mr_req_valid,
    input   wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                        	SQ_mr_req_head,
    input   wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                        	SQ_mr_req_data,
    output  wire                                                        	SQ_mr_req_ready,

    output  wire                                                        	SQ_mr_rsp_valid,
    output  wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                        	SQ_mr_rsp_head,
    output  wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                        	SQ_mr_rsp_data,
    input  	wire                                                        	SQ_mr_rsp_ready,

//INterface with RQMgt
    input   wire                                                        	RQ_mr_req_valid,
    input   wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                        	RQ_mr_req_head,
    input   wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                        	RQ_mr_req_data,
    output  wire                                                        	RQ_mr_req_ready,

    output  wire                                                        	RQ_mr_rsp_valid,
    output  wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                        	RQ_mr_rsp_head,
    output  wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                        	RQ_mr_rsp_data,
    input  	wire                                                        	RQ_mr_rsp_ready,

//Interface with RDMACore/ReqTransCore
    input   wire                                                        	TX_REQ_mr_req_valid,
    input   wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                        	TX_REQ_mr_req_head,
    input   wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                        	TX_REQ_mr_req_data,
    output  wire                                                        	TX_REQ_mr_req_ready,

    output  wire                                                        	TX_REQ_mr_rsp_valid,
    output  wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                        	TX_REQ_mr_rsp_head,
    output  wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                        	TX_REQ_mr_rsp_data,
    input  	wire                                                        	TX_REQ_mr_rsp_ready,

//Interface with RDMACore/ReqRecvCore
    input   wire                                                        	RX_REQ_mr_req_valid,
    input   wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                        	RX_REQ_mr_req_head,
    input   wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                        	RX_REQ_mr_req_data,
    output  wire                                                        	RX_REQ_mr_req_ready,

    output  wire                                                        	RX_REQ_mr_rsp_valid,
    output  wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                        	RX_REQ_mr_rsp_head,
    output  wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                        	RX_REQ_mr_rsp_data,
    input   wire                                                        	RX_REQ_mr_rsp_ready,

//Interface with RDMACore/RespRecvCore
	input   wire                                                        	RX_RESP_mr_req_valid,
    input   wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                        	RX_RESP_mr_req_head,
    input   wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                        	RX_RESP_mr_req_data,
    output  wire                                                        	RX_RESP_mr_req_ready,

    output  wire                                                        	RX_RESP_mr_rsp_valid,
    output  wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                        	RX_RESP_mr_rsp_head,
    output  wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                        	RX_RESP_mr_rsp_data,
    input  	wire                                                        	RX_RESP_mr_rsp_ready,

//Interface with DMA
    output  wire                                                        	mpt_dma_rd_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                           	mpt_dma_rd_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                           	mpt_dma_rd_req_data,
    output  wire                                                        	mpt_dma_rd_req_last,
    input   wire                                                        	mpt_dma_rd_req_ready,

    input   wire                                                            mpt_dma_rd_rsp_valid,
    input   wire    [`DMA_HEAD_WIDTH - 1 : 0]                               mpt_dma_rd_rsp_head,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                               mpt_dma_rd_rsp_data,
    input   wire                                                            mpt_dma_rd_rsp_last,
    output  wire                                                            mpt_dma_rd_rsp_ready,

    output  wire                                                            mpt_dma_wr_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                               mpt_dma_wr_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                               mpt_dma_wr_req_data,
    output  wire                                                            mpt_dma_wr_req_last,
    input   wire                                                            mpt_dma_wr_req_ready,

    output  wire                                                            mtt_dma_rd_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                               mtt_dma_rd_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                               mtt_dma_rd_req_data,
    output  wire                                                            mtt_dma_rd_req_last,
    input   wire                                                            mtt_dma_rd_req_ready,

    input   wire                                                            mtt_dma_rd_rsp_valid,
    input   wire    [`DMA_HEAD_WIDTH - 1 : 0]                               mtt_dma_rd_rsp_head,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                               mtt_dma_rd_rsp_data,
    input   wire                                                            mtt_dma_rd_rsp_last,
    output  wire                                                            mtt_dma_rd_rsp_ready,

    output  wire                                                            mtt_dma_wr_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                               mtt_dma_wr_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                               mtt_dma_wr_req_data,
    output  wire                                                            mtt_dma_wr_req_last,
    input   wire                                                            mtt_dma_wr_req_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/

/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/

/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
CxtMgt CxtMgt_Inst(
	.clk								(			clk								),
	.rst								(			rst								),

    .ceu_req_valid						(			ceu_cxt_req_valid				),
    .ceu_req_head						(			ceu_cxt_req_head				),
    .ceu_req_last						(			ceu_cxt_req_last				),
    .ceu_req_data						(			ceu_cxt_req_data				),
    .ceu_req_ready						(			ceu_cxt_req_ready				),

    .qpc_rsp_valid						(			ceu_cxt_rsp_valid				),
    .qpc_rsp_head						(			ceu_cxt_rsp_head				),
    .qpc_rsp_last						(			ceu_cxt_rsp_last				),
    .qpc_rsp_data						(			ceu_cxt_rsp_data				),
    .qpc_rsp_ready						(			ceu_cxt_rsp_ready				),

    .SQ_cxt_req_valid			(			SQ_cxt_req_valid		),
    .SQ_cxt_req_head			(			SQ_cxt_req_head			),
    .SQ_cxt_req_data			(			SQ_cxt_req_data			),
    .SQ_cxt_req_ready			(			SQ_cxt_req_ready		),

    .TX_REQ_cxt_req_valid			(			TX_REQ_cxt_req_valid		),
    .TX_REQ_cxt_req_head			(			TX_REQ_cxt_req_head			),
    .TX_REQ_cxt_req_data			(			TX_REQ_cxt_req_data			),
    .TX_REQ_cxt_req_ready			(			TX_REQ_cxt_req_ready		),

    .RX_REQ_cxt_req_valid			(			RX_REQ_cxt_req_valid		),
    .RX_REQ_cxt_req_head			(			RX_REQ_cxt_req_head			),
    .RX_REQ_cxt_req_data			(			RX_REQ_cxt_req_data			),
    .RX_REQ_cxt_req_ready			(			RX_REQ_cxt_req_ready		),

    .RX_RESP_cxt_req_valid			(			RX_RESP_cxt_req_valid		),
    .RX_RESP_cxt_req_head			(			RX_RESP_cxt_req_head			),
    .RX_RESP_cxt_req_data			(			RX_RESP_cxt_req_data			),
    .RX_RESP_cxt_req_ready			(			RX_RESP_cxt_req_ready		),

    .SQ_cxt_rsp_valid			(			SQ_cxt_rsp_valid		),
    .SQ_cxt_rsp_head			(			SQ_cxt_rsp_head			),
    .SQ_cxt_rsp_data			(			SQ_cxt_rsp_data			),
    .SQ_cxt_rsp_ready			(			SQ_cxt_rsp_ready		),

    .TX_REQ_cxt_rsp_valid			(			TX_REQ_cxt_rsp_valid		),
    .TX_REQ_cxt_rsp_head			(			TX_REQ_cxt_rsp_head			),
    .TX_REQ_cxt_rsp_data			(			TX_REQ_cxt_rsp_data			),
    .TX_REQ_cxt_rsp_ready			(			TX_REQ_cxt_rsp_ready		),

    .RX_REQ_cxt_rsp_valid			(			RX_REQ_cxt_rsp_valid		),
    .RX_REQ_cxt_rsp_head			(			RX_REQ_cxt_rsp_head			),
    .RX_REQ_cxt_rsp_data			(			RX_REQ_cxt_rsp_data			),
    .RX_REQ_cxt_rsp_ready			(			RX_REQ_cxt_rsp_ready		),

    .RX_RESP_cxt_rsp_valid			(			RX_RESP_cxt_rsp_valid		),
    .RX_RESP_cxt_rsp_head			(			RX_RESP_cxt_rsp_head			),
    .RX_RESP_cxt_rsp_data			(			RX_RESP_cxt_rsp_data			),
    .RX_RESP_cxt_rsp_ready			(			RX_RESP_cxt_rsp_ready		),

    .qpc_dma_rd_req_valid				(			qpc_dma_rd_req_valid			),
    .qpc_dma_rd_req_head				(			qpc_dma_rd_req_head				),
    .qpc_dma_rd_req_data				(			qpc_dma_rd_req_data				),
    .qpc_dma_rd_req_last				(			qpc_dma_rd_req_last				),
    .qpc_dma_rd_req_ready				(			qpc_dma_rd_req_ready			),

    .qpc_dma_rd_rsp_valid				(			qpc_dma_rd_rsp_valid			),
    .qpc_dma_rd_rsp_head				(			qpc_dma_rd_rsp_head				),
    .qpc_dma_rd_rsp_data				(			qpc_dma_rd_rsp_data				),
    .qpc_dma_rd_rsp_last				(			qpc_dma_rd_rsp_last				),
    .qpc_dma_rd_rsp_ready				(			qpc_dma_rd_rsp_ready			),

    .qpc_dma_wr_req_valid				(			qpc_dma_wr_req_valid			),
    .qpc_dma_wr_req_head				(			qpc_dma_wr_req_head				),
    .qpc_dma_wr_req_data				(			qpc_dma_wr_req_data				),
    .qpc_dma_wr_req_last				(			qpc_dma_wr_req_last				),
    .qpc_dma_wr_req_ready				(			qpc_dma_wr_req_ready			),

    .cqc_dma_rd_req_valid				(			cqc_dma_rd_req_valid			),
    .cqc_dma_rd_req_head				(			cqc_dma_rd_req_head				),
    .cqc_dma_rd_req_data				(			cqc_dma_rd_req_data				),
    .cqc_dma_rd_req_last				(			cqc_dma_rd_req_last				),
    .cqc_dma_rd_req_ready				(			cqc_dma_rd_req_ready			),

    .cqc_dma_rd_rsp_valid				(			cqc_dma_rd_rsp_valid			),
    .cqc_dma_rd_rsp_head				(			cqc_dma_rd_rsp_head				),
    .cqc_dma_rd_rsp_data				(			cqc_dma_rd_rsp_data				),
    .cqc_dma_rd_rsp_last				(			cqc_dma_rd_rsp_last				),
    .cqc_dma_rd_rsp_ready				(			cqc_dma_rd_rsp_ready			),

    .cqc_dma_wr_req_valid				(			cqc_dma_wr_req_valid			),
    .cqc_dma_wr_req_head				(			cqc_dma_wr_req_head				),
    .cqc_dma_wr_req_data				(			cqc_dma_wr_req_data				),
    .cqc_dma_wr_req_last				(			cqc_dma_wr_req_last				),
    .cqc_dma_wr_req_ready				(			cqc_dma_wr_req_ready			),

    .eqc_dma_rd_req_valid				(			eqc_dma_rd_req_valid			),
    .eqc_dma_rd_req_head				(			eqc_dma_rd_req_head				),
    .eqc_dma_rd_req_data				(			eqc_dma_rd_req_data				),
    .eqc_dma_rd_req_last				(			eqc_dma_rd_req_last				),
    .eqc_dma_rd_req_ready				(			eqc_dma_rd_req_ready			),

    .eqc_dma_rd_rsp_valid				(			eqc_dma_rd_rsp_valid			),
    .eqc_dma_rd_rsp_head				(			eqc_dma_rd_rsp_head				),
    .eqc_dma_rd_rsp_data				(			eqc_dma_rd_rsp_data				),
    .eqc_dma_rd_rsp_last				(			eqc_dma_rd_rsp_last				),
    .eqc_dma_rd_rsp_ready				(			eqc_dma_rd_rsp_ready			),

    .eqc_dma_wr_req_valid				(			eqc_dma_wr_req_valid			),
    .eqc_dma_wr_req_head				(			eqc_dma_wr_req_head				),
    .eqc_dma_wr_req_data				(			eqc_dma_wr_req_data				),
    .eqc_dma_wr_req_last				(			eqc_dma_wr_req_last				),
    .eqc_dma_wr_req_ready				(			eqc_dma_wr_req_ready			)
);

MRMgt MRMgt_Inst (
	.clk							(			clk								),
	.rst							(			rst								),

	.ceu_req_valid					(			ceu_mr_req_valid				),
	.ceu_req_head					(			ceu_mr_req_head					),
	.ceu_req_last					(			ceu_mr_req_last					),
	.ceu_req_data					(			ceu_mr_req_data					),
	.ceu_req_ready					(			ceu_mr_req_ready				),

	.SQ_mr_req_valid		(			SQ_mr_req_valid			),
	.SQ_mr_req_head			(			SQ_mr_req_head			),
	.SQ_mr_req_data			(			SQ_mr_req_data			),
	.SQ_mr_req_ready		(			SQ_mr_req_ready			),

	.SQ_mr_rsp_valid		(			SQ_mr_rsp_valid			),
	.SQ_mr_rsp_head			(			SQ_mr_rsp_head			),
	.SQ_mr_rsp_data			(			SQ_mr_rsp_data			),
	.SQ_mr_rsp_ready		(			SQ_mr_rsp_ready			),

	.RQ_mr_req_valid		(			RQ_mr_req_valid			),
	.RQ_mr_req_head			(			RQ_mr_req_head			),
	.RQ_mr_req_data			(			RQ_mr_req_data			),
	.RQ_mr_req_ready		(			RQ_mr_req_ready			),

	.RQ_mr_rsp_valid		(			RQ_mr_rsp_valid			),
	.RQ_mr_rsp_head			(			RQ_mr_rsp_head			),
	.RQ_mr_rsp_data			(			RQ_mr_rsp_data			),
	.RQ_mr_rsp_ready		(			RQ_mr_rsp_ready			),

	.TX_REQ_mr_req_valid		(			TX_REQ_mr_req_valid			),
	.TX_REQ_mr_req_head			(			TX_REQ_mr_req_head			),
	.TX_REQ_mr_req_data			(			TX_REQ_mr_req_data			),
	.TX_REQ_mr_req_ready		(			TX_REQ_mr_req_ready			),

	.TX_REQ_mr_rsp_valid		(			TX_REQ_mr_rsp_valid			),
	.TX_REQ_mr_rsp_head			(			TX_REQ_mr_rsp_head			),
	.TX_REQ_mr_rsp_data			(			TX_REQ_mr_rsp_data			),
	.TX_REQ_mr_rsp_ready		(			TX_REQ_mr_rsp_ready			),

	.RX_REQ_mr_req_valid		(			RX_REQ_mr_req_valid			),
	.RX_REQ_mr_req_head			(			RX_REQ_mr_req_head			),
	.RX_REQ_mr_req_data			(			RX_REQ_mr_req_data			),
	.RX_REQ_mr_req_ready		(			RX_REQ_mr_req_ready			),

	.RX_REQ_mr_rsp_valid		(			RX_REQ_mr_rsp_valid			),
	.RX_REQ_mr_rsp_head			(			RX_REQ_mr_rsp_head			),
	.RX_REQ_mr_rsp_data			(			RX_REQ_mr_rsp_data			),
	.RX_REQ_mr_rsp_ready		(			RX_REQ_mr_rsp_ready			),

	.RX_RESP_mr_req_valid		(			RX_RESP_mr_req_valid		),
	.RX_RESP_mr_req_head		(			RX_RESP_mr_req_head			),
	.RX_RESP_mr_req_data		(			RX_RESP_mr_req_data			),
	.RX_RESP_mr_req_ready		(			RX_RESP_mr_req_ready		),

	.RX_RESP_mr_rsp_valid		(			RX_RESP_mr_rsp_valid		),
	.RX_RESP_mr_rsp_head		(			RX_RESP_mr_rsp_head			),
	.RX_RESP_mr_rsp_data		(			RX_RESP_mr_rsp_data			),
	.RX_RESP_mr_rsp_ready		(			RX_RESP_mr_rsp_ready		),

	.mpt_dma_rd_req_valid			(			mpt_dma_rd_req_valid			),
	.mpt_dma_rd_req_head			(			mpt_dma_rd_req_head				),
	.mpt_dma_rd_req_data			(			mpt_dma_rd_req_data				),
	.mpt_dma_rd_req_last			(			mpt_dma_rd_req_last				),
	.mpt_dma_rd_req_ready			(			mpt_dma_rd_req_ready			),

	.mpt_dma_rd_rsp_valid			(			mpt_dma_rd_rsp_valid			),
	.mpt_dma_rd_rsp_head			(			mpt_dma_rd_rsp_head				),
	.mpt_dma_rd_rsp_data			(			mpt_dma_rd_rsp_data				),
	.mpt_dma_rd_rsp_last			(			mpt_dma_rd_rsp_last				),
	.mpt_dma_rd_rsp_ready			(			mpt_dma_rd_rsp_ready			),

	.mpt_dma_wr_req_valid			(			mpt_dma_wr_req_valid			),
	.mpt_dma_wr_req_head			(			mpt_dma_wr_req_head				),
	.mpt_dma_wr_req_data			(			mpt_dma_wr_req_data				),
	.mpt_dma_wr_req_last			(			mpt_dma_wr_req_last				),
	.mpt_dma_wr_req_ready			(			mpt_dma_wr_req_ready			),

	.mtt_dma_rd_req_valid			(			mtt_dma_rd_req_valid			),
	.mtt_dma_rd_req_head			(			mtt_dma_rd_req_head				),
	.mtt_dma_rd_req_data			(			mtt_dma_rd_req_data				),
	.mtt_dma_rd_req_last			(			mtt_dma_rd_req_last				),
	.mtt_dma_rd_req_ready			(			mtt_dma_rd_req_ready			),

	.mtt_dma_rd_rsp_valid			(			mtt_dma_rd_rsp_valid			),
	.mtt_dma_rd_rsp_head			(			mtt_dma_rd_rsp_head				),
	.mtt_dma_rd_rsp_data			(			mtt_dma_rd_rsp_data				),
	.mtt_dma_rd_rsp_last			(			mtt_dma_rd_rsp_last				),
	.mtt_dma_rd_rsp_ready			(			mtt_dma_rd_rsp_ready			),

	.mtt_dma_wr_req_valid			(			mtt_dma_wr_req_valid			),
	.mtt_dma_wr_req_head			(			mtt_dma_wr_req_head				),
	.mtt_dma_wr_req_data			(			mtt_dma_wr_req_data				),
	.mtt_dma_wr_req_last			(			mtt_dma_wr_req_last				),
	.mtt_dma_wr_req_ready			(			mtt_dma_wr_req_ready			)
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule