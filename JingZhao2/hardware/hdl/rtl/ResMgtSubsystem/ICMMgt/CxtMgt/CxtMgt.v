/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       CxtMgt
Author:     YangFan
Function:   Context Management.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module CxtMgt
(
	input 	wire 															clk,
	input 	wire 															rst,

//CEU Request
    input   wire                                                            ceu_req_valid,
    input   wire    [`CEU_CXT_HEAD_WIDTH - 1 : 0]                           ceu_req_head,
    input   wire                                                            ceu_req_last,
    input   wire    [`CEU_CXT_DATA_WIDTH - 1 : 0]                           ceu_req_data,
    output  wire                                                            ceu_req_ready,

//CEU Response
    output  wire                                                            qpc_rsp_valid,
    output  wire    [`CEU_CXT_HEAD_WIDTH - 1 : 0]                           qpc_rsp_head,
    output  wire                                                            qpc_rsp_last,
    output  wire    [`CEU_CXT_DATA_WIDTH - 1 : 0]                           qpc_rsp_data,
    input   wire                                                            qpc_rsp_ready,

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
    input   wire                                                            eqc_dma_wr_req_ready
);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/

/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                                                    qpc_icm_mapping_set_valid;
wire    [`PAGE_FRAME_WIDTH - 1 : 0]                                     qpc_icm_mapping_set_head;
wire    [`PAGE_FRAME_WIDTH - 1 : 0]                                     qpc_icm_mapping_set_data;

wire                                                                    qpc_icm_mapping_lookup_valid;
wire    [log2b(`ICM_ENTRY_NUM_MPT - 1) - 1 : 0]                         qpc_icm_mapping_lookup_head;

wire                                                                    qpc_icm_mapping_rsp_valid;
wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                 qpc_icm_mapping_rsp_icm_addr;
wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                 qpc_icm_mapping_rsp_phy_addr;

wire                                                                    sw_qpc_icm_mapping_lookup_valid;
wire    [log2b(`ICM_ENTRY_NUM_QPC - 1) - 1 : 0]                         sw_qpc_icm_mapping_lookup_head;
wire                                                                    sw_qpc_icm_mapping_lookup_ready;

wire                                                                    sw_qpc_icm_mapping_rsp_valid;
wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                 sw_qpc_icm_mapping_rsp_icm_addr;
wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                 sw_qpc_icm_mapping_rsp_phy_addr;
wire                                                                    sw_qpc_icm_mapping_rsp_ready;

wire                                                                    hw_qpc_icm_mapping_lookup_valid;
wire    [log2b(`ICM_ENTRY_NUM_QPC - 1) - 1 : 0]                         hw_qpc_icm_mapping_lookup_head;
wire                                                                    hw_qpc_icm_mapping_lookup_ready;

wire                                                                    hw_qpc_icm_mapping_rsp_valid;
wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                 hw_qpc_icm_mapping_rsp_icm_addr;
wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                 hw_qpc_icm_mapping_rsp_phy_addr;
wire                                                                    hw_qpc_icm_mapping_rsp_ready;

wire                                                                                                        qpc_icm_get_req_valid;
wire    [`COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + `PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH - 1 : 0]     qpc_icm_get_req_head;
wire                                                                                                        qpc_icm_get_req_ready;

wire                                                                                                        qpc_icm_get_rsp_valid;
wire    [`COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + `PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH - 1 : 0]     qpc_icm_get_rsp_head;
wire    [`CACHE_ENTRY_WIDTH_QPC - 1 : 0]                                                                    qpc_icm_get_rsp_data;
wire                                                                                                        qpc_icm_get_rsp_ready;

wire                                                                                                        sw_qpc_icm_get_req_valid;
wire    [`COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + `PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH - 1 : 0]     sw_qpc_icm_get_req_head;
wire                                                                                                        sw_qpc_icm_get_req_ready;

wire                                                                                                        sw_qpc_icm_get_rsp_valid;
wire    [`COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + `PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH - 1 : 0]     sw_qpc_icm_get_rsp_head;
wire    [`CACHE_ENTRY_WIDTH_QPC - 1 : 0]                                                                    sw_qpc_icm_get_rsp_data;
wire                                                                                                        sw_qpc_icm_get_rsp_ready;

wire                                                                                                        hw_qpc_icm_get_req_valid;
wire    [`COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + `PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH - 1 : 0]     hw_qpc_icm_get_req_head;
wire                                                                                                        hw_qpc_icm_get_req_ready;

wire                                                                                                        hw_qpc_icm_get_rsp_valid;
wire    [`COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + `PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH - 1 : 0]     hw_qpc_icm_get_rsp_head;
wire    [`CACHE_ENTRY_WIDTH_QPC - 1 : 0]                                                                    hw_qpc_icm_get_rsp_data;
wire                                                                                                        hw_qpc_icm_get_rsp_ready;

wire                                                                    qpc_icm_set_req_valid;
wire    [`PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH - 1 : 0]         qpc_icm_set_req_head;
wire    [`CACHE_ENTRY_WIDTH_QPC - 1 : 0]                                qpc_icm_set_req_data;
wire                                                                    qpc_icm_set_req_ready;

wire                                                                    cqc_icm_mapping_set_valid;
wire    [`PAGE_FRAME_WIDTH - 1 : 0]                                     cqc_icm_mapping_set_head;
wire    [`PAGE_FRAME_WIDTH - 1 : 0]                                     cqc_icm_mapping_set_data;

wire                                                                    cqc_icm_mapping_lookup_valid;
wire    [log2b(`ICM_ENTRY_NUM_CQC - 1) - 1 : 0]                         cqc_icm_mapping_lookup_head;

wire                                                                    cqc_icm_mapping_rsp_valid;
wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                 cqc_icm_mapping_rsp_icm_addr;
wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                 cqc_icm_mapping_rsp_phy_addr;

wire                                                                    sw_cqc_icm_mapping_lookup_valid;
wire    [log2b(`ICM_ENTRY_NUM_CQC - 1) - 1 : 0]                         sw_cqc_icm_mapping_lookup_head;
wire                                                                    sw_cqc_icm_mapping_lookup_ready;

wire                                                                    sw_cqc_icm_mapping_rsp_valid;
wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                 sw_cqc_icm_mapping_rsp_icm_addr;
wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                 sw_cqc_icm_mapping_rsp_phy_addr;
wire                                                                    sw_cqc_icm_mapping_rsp_ready;

wire                                                                    hw_cqc_icm_mapping_lookup_valid;
wire    [log2b(`ICM_ENTRY_NUM_CQC - 1) - 1 : 0]                         hw_cqc_icm_mapping_lookup_head;
wire                                                                    hw_cqc_icm_mapping_lookup_ready;

wire                                                                    hw_cqc_icm_mapping_rsp_valid;
wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                 hw_cqc_icm_mapping_rsp_icm_addr;
wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                 hw_cqc_icm_mapping_rsp_phy_addr;
wire                                                                    hw_cqc_icm_mapping_rsp_ready;

wire                                                                                                            cqc_icm_get_req_valid;
wire    [`COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + `PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH - 1 : 0]     cqc_icm_get_req_head;
wire                                                                                                            cqc_icm_get_req_ready;

wire                                                                                                            cqc_icm_get_rsp_valid;
wire    [`COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + `PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH - 1 : 0]     cqc_icm_get_rsp_head;
wire    [`CACHE_ENTRY_WIDTH_CQC - 1 : 0]                                                                        cqc_icm_get_rsp_data;
wire                                                                                                            cqc_icm_get_rsp_ready;

wire                                                                    cqc_icm_set_req_valid;
wire    [`PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH - 1 : 0]         cqc_icm_set_req_head;
wire    [`CACHE_ENTRY_WIDTH_CQC - 1 : 0]                                cqc_icm_set_req_data;
wire                                                                    cqc_icm_set_req_ready;

wire                                                                    eqc_icm_mapping_set_valid;
wire    [`PAGE_FRAME_WIDTH - 1 : 0]                                     eqc_icm_mapping_set_head;
wire    [`PAGE_FRAME_WIDTH - 1 : 0]                                     eqc_icm_mapping_set_data;

wire                                                                    eqc_icm_mapping_lookup_valid;
wire    [log2b(`ICM_ENTRY_NUM_MTT - 1) - 1 : 0]                         eqc_icm_mapping_lookup_head;

wire                                                                    eqc_icm_mapping_rsp_valid;
wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                 eqc_icm_mapping_rsp_icm_addr;
wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                 eqc_icm_mapping_rsp_phy_addr;

wire                                                                    sw_eqc_icm_mapping_lookup_valid;
wire    [log2b(`ICM_ENTRY_NUM_EQC - 1) - 1 : 0]                         sw_eqc_icm_mapping_lookup_head;
wire                                                                    sw_eqc_icm_mapping_lookup_ready;

wire                                                                    sw_eqc_icm_mapping_rsp_valid;
wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                 sw_eqc_icm_mapping_rsp_icm_addr;
wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                 sw_eqc_icm_mapping_rsp_phy_addr;
wire                                                                    sw_eqc_icm_mapping_rsp_ready;

wire                                                                    hw_eqc_icm_mapping_lookup_valid;
wire    [log2b(`ICM_ENTRY_NUM_EQC - 1) - 1 : 0]                         hw_eqc_icm_mapping_lookup_head;
wire                                                                    hw_eqc_icm_mapping_lookup_ready;

wire                                                                    hw_eqc_icm_mapping_rsp_valid;
wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                 hw_eqc_icm_mapping_rsp_icm_addr;
wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                 hw_eqc_icm_mapping_rsp_phy_addr;
wire                                                                    hw_eqc_icm_mapping_rsp_ready;

wire                                                                                                        eqc_icm_get_req_valid;
wire    [`COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + `PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH - 1 : 0]     eqc_icm_get_req_head;
wire                                                                                                        eqc_icm_get_req_ready;

wire                                                                                                        eqc_icm_get_rsp_valid;
wire    [`COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + `PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH - 1 : 0]     eqc_icm_get_rsp_head;
wire    [`CACHE_ENTRY_WIDTH_EQC - 1 : 0]                                                                    eqc_icm_get_rsp_data;
wire                                                                                                        eqc_icm_get_rsp_ready;

wire                                                                    eqc_icm_set_req_valid;
wire    [`PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH - 1 : 0]         eqc_icm_set_req_head;
wire    [`CACHE_ENTRY_WIDTH_EQC - 1 : 0]                                eqc_icm_set_req_data;
wire                                                                    eqc_icm_set_req_ready;

wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                                                     qpc_base;
wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                                                     cqc_base;
wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                                                     eqc_base;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
SWAccCMCtl SWAccCMCtl_Inst(
	.clk 							(		clk 							),
	.rst 							(		rst 							),

    .ceu_req_valid					(		ceu_req_valid					),
    .ceu_req_head					(		ceu_req_head					),
    .ceu_req_last					(		ceu_req_last					),
    .ceu_req_data					(		ceu_req_data					),
    .ceu_req_ready					(		ceu_req_ready					),

    .qpc_rsp_valid					(		qpc_rsp_valid					),
    .qpc_rsp_head					(		qpc_rsp_head					),
    .qpc_rsp_last					(		qpc_rsp_last					),
    .qpc_rsp_data					(		qpc_rsp_data					),
    .qpc_rsp_ready					(		qpc_rsp_ready					),

    .qpc_mapping_set_valid			(		qpc_icm_mapping_set_valid 		),
    .qpc_mapping_set_head			(		qpc_icm_mapping_set_head 		),
    .qpc_mapping_set_data			(		qpc_icm_mapping_set_data 		),

    .qpc_cache_get_req_valid		(		sw_qpc_icm_get_req_valid 	    ),
    .qpc_cache_get_req_head			(		sw_qpc_icm_get_req_head 		),
    .qpc_cache_get_req_ready		(		sw_qpc_icm_get_req_ready 	    ),

    .qpc_cache_get_rsp_valid		(		sw_qpc_icm_get_rsp_valid 	    ),
    .qpc_cache_get_rsp_head			(		sw_qpc_icm_get_rsp_head 		),
    .qpc_cache_get_rsp_data			(		sw_qpc_icm_get_rsp_data 		),
    .qpc_cache_get_rsp_ready		(		sw_qpc_icm_get_rsp_ready 	    ),

    .qpc_cache_set_req_valid		(		qpc_icm_set_req_valid 	        ),
    .qpc_cache_set_req_head			(		qpc_icm_set_req_head 		    ),
    .qpc_cache_set_req_data			(		qpc_icm_set_req_data 		    ),
    .qpc_cache_set_req_ready		(		qpc_icm_set_req_ready 	        ),

    .qpc_icm_mapping_lookup_valid	(		sw_qpc_icm_mapping_lookup_valid ),
    .qpc_icm_mapping_lookup_head	(		sw_qpc_icm_mapping_lookup_head  ),
    .qpc_icm_mapping_lookup_ready	(		sw_qpc_icm_mapping_lookup_ready ),

    .qpc_icm_mapping_rsp_valid		(		sw_qpc_icm_mapping_rsp_valid 	),
    .qpc_icm_mapping_rsp_icm_addr	(		sw_qpc_icm_mapping_rsp_icm_addr ),
    .qpc_icm_mapping_rsp_phy_addr	(		sw_qpc_icm_mapping_rsp_phy_addr ),
    .qpc_icm_mapping_rsp_ready		(		sw_qpc_icm_mapping_rsp_ready 	),

    .cqc_mapping_set_valid			(		cqc_icm_mapping_set_valid 		),
    .cqc_mapping_set_head			(		cqc_icm_mapping_set_head 		),
    .cqc_mapping_set_data			(		cqc_icm_mapping_set_data 		),

    .cqc_cache_set_req_valid		(		cqc_icm_set_req_valid 	        ),
    .cqc_cache_set_req_head			(		cqc_icm_set_req_head 		    ),
    .cqc_cache_set_req_data			(		cqc_icm_set_req_data 		    ),
    .cqc_cache_set_req_ready		(		cqc_icm_set_req_ready 	        ),

    .cqc_icm_mapping_lookup_valid	(		sw_cqc_icm_mapping_lookup_valid ),
    .cqc_icm_mapping_lookup_head	(		sw_cqc_icm_mapping_lookup_head  ),
    .cqc_icm_mapping_lookup_ready	(		sw_cqc_icm_mapping_lookup_ready ),

    .cqc_icm_mapping_rsp_valid		(		sw_cqc_icm_mapping_rsp_valid 	),
    .cqc_icm_mapping_rsp_icm_addr	(		sw_cqc_icm_mapping_rsp_icm_addr ),
    .cqc_icm_mapping_rsp_phy_addr	(		sw_cqc_icm_mapping_rsp_phy_addr ),
    .cqc_icm_mapping_rsp_ready		(		sw_cqc_icm_mapping_rsp_ready 	),

    .eqc_mapping_set_valid			(		eqc_icm_mapping_set_valid       ),
    .eqc_mapping_set_head			(		eqc_icm_mapping_set_head 		),
    .eqc_mapping_set_data			(		eqc_icm_mapping_set_data        ),

    .eqc_cache_set_req_valid		(		eqc_icm_set_req_valid           ),
    .eqc_cache_set_req_head			(		eqc_icm_set_req_head            ),
    .eqc_cache_set_req_data			(		eqc_icm_set_req_data 			),
    .eqc_cache_set_req_ready		(		eqc_icm_set_req_ready 		    ),

    .eqc_icm_mapping_lookup_valid	(		sw_eqc_icm_mapping_lookup_valid ),
    .eqc_icm_mapping_lookup_head	(		sw_eqc_icm_mapping_lookup_head  ),
    .eqc_icm_mapping_lookup_ready	(		sw_eqc_icm_mapping_lookup_ready ),

    .eqc_icm_mapping_rsp_valid		(		sw_eqc_icm_mapping_rsp_valid 	),
    .eqc_icm_mapping_rsp_icm_addr	(		sw_eqc_icm_mapping_rsp_icm_addr ),
    .eqc_icm_mapping_rsp_phy_addr	(		sw_eqc_icm_mapping_rsp_phy_addr ),
    .eqc_icm_mapping_rsp_ready		(		sw_eqc_icm_mapping_rsp_ready 	),

    .qpc_base                       (       qpc_base                        ),
    .cqc_base                       (       cqc_base                        ),
    .eqc_base                       (       eqc_base                        )
);

HWAccCMCtl HWAccCMCtl_Inst(
    .clk										(         clk                                      ),
    .rst										(         rst                                      ),

    .SQ_cxt_req_valid					    (         SQ_cxt_req_valid                 ),
    .SQ_cxt_req_head					    (         SQ_cxt_req_head                  ),
    .SQ_cxt_req_data					    (         SQ_cxt_req_data                  ),
    .SQ_cxt_req_ready					    (         SQ_cxt_req_ready                 ),

    .TX_REQ_cxt_req_valid					(         TX_REQ_cxt_req_valid                 ),
    .TX_REQ_cxt_req_head					(         TX_REQ_cxt_req_head                  ),
    .TX_REQ_cxt_req_data					(         TX_REQ_cxt_req_data                  ),
    .TX_REQ_cxt_req_ready					(         TX_REQ_cxt_req_ready                 ),

    .RX_REQ_cxt_req_valid					(         RX_REQ_cxt_req_valid                 ),
    .RX_REQ_cxt_req_head					(         RX_REQ_cxt_req_head                  ),
    .RX_REQ_cxt_req_data					(         RX_REQ_cxt_req_data                  ),
    .RX_REQ_cxt_req_ready					(         RX_REQ_cxt_req_ready                 ),

    .RX_RESP_cxt_req_valid					(         RX_RESP_cxt_req_valid                 ),
    .RX_RESP_cxt_req_head					(         RX_RESP_cxt_req_head                  ),
    .RX_RESP_cxt_req_data					(         RX_RESP_cxt_req_data                  ),
    .RX_RESP_cxt_req_ready					(         RX_RESP_cxt_req_ready                 ),

    .SQ_cxt_rsp_valid					    (         SQ_cxt_rsp_valid                 ),
    .SQ_cxt_rsp_head					    (         SQ_cxt_rsp_head                  ),
    .SQ_cxt_rsp_data					    (         SQ_cxt_rsp_data                  ),
    .SQ_cxt_rsp_ready					    (         SQ_cxt_rsp_ready                 ),

    .TX_REQ_cxt_rsp_valid					(         TX_REQ_cxt_rsp_valid                 ),
    .TX_REQ_cxt_rsp_head					(         TX_REQ_cxt_rsp_head                  ),
    .TX_REQ_cxt_rsp_data					(         TX_REQ_cxt_rsp_data                  ),
    .TX_REQ_cxt_rsp_ready					(         TX_REQ_cxt_rsp_ready                 ),

    .RX_REQ_cxt_rsp_valid					(         RX_REQ_cxt_rsp_valid                 ),
    .RX_REQ_cxt_rsp_head					(         RX_REQ_cxt_rsp_head                  ),
    .RX_REQ_cxt_rsp_data					(         RX_REQ_cxt_rsp_data                  ),
    .RX_REQ_cxt_rsp_ready					(         RX_REQ_cxt_rsp_ready                 ),

    .RX_RESP_cxt_rsp_valid					(         RX_RESP_cxt_rsp_valid                 ),
    .RX_RESP_cxt_rsp_head					(         RX_RESP_cxt_rsp_head                  ),
    .RX_RESP_cxt_rsp_data					(         RX_RESP_cxt_rsp_data                  ),
    .RX_RESP_cxt_rsp_ready					(         RX_RESP_cxt_rsp_ready                 ),

    .qpc_icm_mapping_lookup_valid				(		  hw_qpc_icm_mapping_lookup_valid          ),
    .qpc_icm_mapping_lookup_head				(		  hw_qpc_icm_mapping_lookup_head           ),
    .qpc_icm_mapping_lookup_ready				(		  hw_qpc_icm_mapping_lookup_ready          ),

    .qpc_icm_mapping_rsp_valid					(		  hw_qpc_icm_mapping_rsp_valid             ),
    .qpc_icm_mapping_rsp_icm_addr				(		  hw_qpc_icm_mapping_rsp_icm_addr          ),
    .qpc_icm_mapping_rsp_phy_addr				(		  hw_qpc_icm_mapping_rsp_phy_addr          ),
    .qpc_icm_mapping_rsp_ready                  (         hw_qpc_icm_mapping_rsp_ready             ),

    .qpc_get_req_valid							(		  hw_qpc_icm_get_req_valid                 ),
    .qpc_get_req_head							(		  hw_qpc_icm_get_req_head                  ),
    .qpc_get_req_ready							(		  hw_qpc_icm_get_req_ready                 ),

    .qpc_get_rsp_valid							(		  hw_qpc_icm_get_rsp_valid                 ),
    .qpc_get_rsp_head							(		  hw_qpc_icm_get_rsp_head                  ),
    .qpc_get_rsp_data							(		  hw_qpc_icm_get_rsp_data                  ),
    .qpc_get_rsp_ready							(		  hw_qpc_icm_get_rsp_ready                 ),

	.cqc_icm_mapping_lookup_valid				(		  hw_cqc_icm_mapping_lookup_valid          ),
    .cqc_icm_mapping_lookup_head				(		  hw_cqc_icm_mapping_lookup_head           ),
    .cqc_icm_mapping_lookup_ready				(		  hw_cqc_icm_mapping_lookup_ready          ),

    .cqc_icm_mapping_rsp_valid					(		  hw_cqc_icm_mapping_rsp_valid             ),
    .cqc_icm_mapping_rsp_icm_addr				(		  hw_cqc_icm_mapping_rsp_icm_addr          ),
    .cqc_icm_mapping_rsp_phy_addr				(		  hw_cqc_icm_mapping_rsp_phy_addr          ),
    .cqc_icm_mapping_rsp_ready                  (         hw_cqc_icm_mapping_rsp_ready             ),

    .cqc_get_req_valid							(		  cqc_icm_get_req_valid                    ),
    .cqc_get_req_head							(		  cqc_icm_get_req_head                     ),
    .cqc_get_req_ready							(		  cqc_icm_get_req_ready                    ),

    .cqc_get_rsp_valid							(		  cqc_icm_get_rsp_valid                    ),
    .cqc_get_rsp_head							(		  cqc_icm_get_rsp_head                     ),
    .cqc_get_rsp_data							(		  cqc_icm_get_rsp_data                     ),
    .cqc_get_rsp_ready							(		  cqc_icm_get_rsp_ready                    ),

    .eqc_icm_mapping_lookup_valid				(		  hw_eqc_icm_mapping_lookup_valid          ),
    .eqc_icm_mapping_lookup_head				(		  hw_eqc_icm_mapping_lookup_head           ),
    .eqc_icm_mapping_lookup_ready				(		  hw_eqc_icm_mapping_lookup_ready          ),

    .eqc_icm_mapping_rsp_valid					(		  hw_eqc_icm_mapping_rsp_valid             ),
    .eqc_icm_mapping_rsp_icm_addr				(		  hw_eqc_icm_mapping_rsp_icm_addr          ),
    .eqc_icm_mapping_rsp_phy_addr				(		  hw_eqc_icm_mapping_rsp_phy_addr          ),
    .eqc_icm_mapping_rsp_ready                  (         hw_eqc_icm_mapping_rsp_ready             ),

    .eqc_get_req_valid							(		  eqc_icm_get_req_valid                    ),
    .eqc_get_req_head							(		  eqc_icm_get_req_head                     ),
    .eqc_get_req_ready							(		  eqc_icm_get_req_ready                    ),

    .eqc_get_rsp_valid							(		  eqc_icm_get_rsp_valid                    ),
    .eqc_get_rsp_head							(		  eqc_icm_get_rsp_head                     ),
    .eqc_get_rsp_data							(		  eqc_icm_get_rsp_data                     ),
    .eqc_get_rsp_ready 							(		  eqc_icm_get_rsp_ready                    )
);

ICMCache #(
   .ICM_CACHE_TYPE                  (     `CACHE_TYPE_QPC           ),
   .ICM_PAGE_NUM                    (     `ICM_PAGE_NUM_QPC         ),

   .ICM_ENTRY_NUM                   (     `ICM_ENTRY_NUM_QPC        ),

   .ICM_SLOT_SIZE                   (     `ICM_SLOT_SIZE_QPC        ),
   .ICM_ADDR_WIDTH                  (     `ICM_SPACE_ADDR_WIDTH     ),

   .CACHE_ENTRY_WIDTH               (     `CACHE_ENTRY_WIDTH_QPC    ),
   .CACHE_SET_NUM                   (     `CACHE_SET_NUM_QPC        )
)
QPCCache_Inst
(
    .clk                            (           clk                         ),
    .rst                            (           rst                         ),

    .icm_get_req_valid              (       qpc_icm_get_req_valid           ),
    .icm_get_req_head               (       qpc_icm_get_req_head            ),
    .icm_get_req_ready              (       qpc_icm_get_req_ready           ),

    .icm_get_rsp_valid              (       qpc_icm_get_rsp_valid           ),
    .icm_get_rsp_head               (       qpc_icm_get_rsp_head            ),
    .icm_get_rsp_data               (       qpc_icm_get_rsp_data            ),
    .icm_get_rsp_ready              (       qpc_icm_get_rsp_ready           ),

    .icm_set_req_valid              (       qpc_icm_set_req_valid           ),
    .icm_set_req_head               (       qpc_icm_set_req_head            ),
    .icm_set_req_data               (       qpc_icm_set_req_data            ),
    .icm_set_req_ready              (       qpc_icm_set_req_ready           ),

    .icm_del_req_valid              (       'd0                             ),
    .icm_del_req_head               (       'd0                             ),
    .icm_del_req_ready              (                                       ),

    .dma_rd_req_valid               (       qpc_dma_rd_req_valid            ),
    .dma_rd_req_head                (       qpc_dma_rd_req_head             ),
    .dma_rd_req_data                (       qpc_dma_rd_req_data             ),
    .dma_rd_req_last                (       qpc_dma_rd_req_last             ),
    .dma_rd_req_ready               (       qpc_dma_rd_req_ready            ),

    .dma_rd_rsp_valid               (       qpc_dma_rd_rsp_valid            ),
    .dma_rd_rsp_head                (       qpc_dma_rd_rsp_head             ),
    .dma_rd_rsp_data                (       qpc_dma_rd_rsp_data             ),
    .dma_rd_rsp_last                (       qpc_dma_rd_rsp_last             ),
    .dma_rd_rsp_ready               (       qpc_dma_rd_rsp_ready            ),

    .dma_wr_req_valid               (       qpc_dma_wr_req_valid            ),
    .dma_wr_req_head                (       qpc_dma_wr_req_head             ),
    .dma_wr_req_data                (       qpc_dma_wr_req_data             ),
    .dma_wr_req_last                (       qpc_dma_wr_req_last             ),
    .dma_wr_req_ready               (       qpc_dma_wr_req_ready            ),

    .icm_mapping_set_valid          (       qpc_icm_mapping_set_valid       ),
    .icm_mapping_set_head           (       qpc_icm_mapping_set_head        ),
    .icm_mapping_set_data           (       qpc_icm_mapping_set_data        ),

    .icm_mapping_lookup_valid       (       qpc_icm_mapping_lookup_valid    ),
    .icm_mapping_lookup_head        (       qpc_icm_mapping_lookup_head     ),

    .icm_mapping_rsp_valid          (       qpc_icm_mapping_rsp_valid       ),
    .icm_mapping_rsp_icm_addr       (       qpc_icm_mapping_rsp_icm_addr    ),
    .icm_mapping_rsp_phy_addr       (       qpc_icm_mapping_rsp_phy_addr    ),

    .icm_base                       (       qpc_base                        )
 );

ICMCache #(
   .ICM_CACHE_TYPE                  (     `CACHE_TYPE_CQC           ),
   .ICM_PAGE_NUM                    (     `ICM_PAGE_NUM_CQC         ),

   .ICM_ENTRY_NUM                   (     `ICM_ENTRY_NUM_CQC        ),

   .ICM_SLOT_SIZE                   (     `ICM_SLOT_SIZE_CQC        ),
   .ICM_ADDR_WIDTH                  (     `ICM_SPACE_ADDR_WIDTH     ),

   .CACHE_ENTRY_WIDTH               (     `CACHE_ENTRY_WIDTH_CQC    ),
   .CACHE_SET_NUM                   (     `CACHE_SET_NUM_CQC        )
)
CQCCache_Inst
(
    .clk                            (           clk                         ),
    .rst                            (           rst                         ),

    .icm_get_req_valid              (       cqc_icm_get_req_valid           ),
    .icm_get_req_head               (       cqc_icm_get_req_head            ),
    .icm_get_req_ready              (       cqc_icm_get_req_ready           ),

    .icm_get_rsp_valid              (       cqc_icm_get_rsp_valid           ),
    .icm_get_rsp_head               (       cqc_icm_get_rsp_head            ),
    .icm_get_rsp_data               (       cqc_icm_get_rsp_data            ),
    .icm_get_rsp_ready              (       cqc_icm_get_rsp_ready           ),

    .icm_set_req_valid              (       cqc_icm_set_req_valid           ),
    .icm_set_req_head               (       cqc_icm_set_req_head            ),
    .icm_set_req_data               (       cqc_icm_set_req_data            ),
    .icm_set_req_ready              (       cqc_icm_set_req_ready           ),

    .icm_del_req_valid              (       'd0                             ),
    .icm_del_req_head               (       'd0                             ),
    .icm_del_req_ready              (                                       ),

    .dma_rd_req_valid               (       cqc_dma_rd_req_valid            ),
    .dma_rd_req_head                (       cqc_dma_rd_req_head             ),
    .dma_rd_req_data                (       cqc_dma_rd_req_data             ),
    .dma_rd_req_last                (       cqc_dma_rd_req_last             ),
    .dma_rd_req_ready               (       cqc_dma_rd_req_ready            ),

    .dma_rd_rsp_valid               (       cqc_dma_rd_rsp_valid            ),
    .dma_rd_rsp_head                (       cqc_dma_rd_rsp_head             ),
    .dma_rd_rsp_data                (       cqc_dma_rd_rsp_data             ),
    .dma_rd_rsp_last                (       cqc_dma_rd_rsp_last             ),
    .dma_rd_rsp_ready               (       cqc_dma_rd_rsp_ready            ),

    .dma_wr_req_valid               (       cqc_dma_wr_req_valid            ),
    .dma_wr_req_head                (       cqc_dma_wr_req_head             ),
    .dma_wr_req_data                (       cqc_dma_wr_req_data             ),
    .dma_wr_req_last                (       cqc_dma_wr_req_last             ),
    .dma_wr_req_ready               (       cqc_dma_wr_req_ready            ),

    .icm_mapping_set_valid          (       cqc_icm_mapping_set_valid       ),
    .icm_mapping_set_head           (       cqc_icm_mapping_set_head        ),
    .icm_mapping_set_data           (       cqc_icm_mapping_set_data        ),

    .icm_mapping_lookup_valid       (       cqc_icm_mapping_lookup_valid    ),
    .icm_mapping_lookup_head        (       cqc_icm_mapping_lookup_head     ),

    .icm_mapping_rsp_valid          (       cqc_icm_mapping_rsp_valid       ),
    .icm_mapping_rsp_icm_addr       (       cqc_icm_mapping_rsp_icm_addr    ),
    .icm_mapping_rsp_phy_addr       (       cqc_icm_mapping_rsp_phy_addr    ),

    .icm_base                       (       cqc_base                        )
 );

ICMCache #(
   .ICM_CACHE_TYPE                  (     `CACHE_TYPE_EQC           ),
   .ICM_PAGE_NUM                    (     `ICM_PAGE_NUM_EQC         ),

   .ICM_ENTRY_NUM                   (     `ICM_ENTRY_NUM_EQC        ),

   .ICM_SLOT_SIZE                   (     `ICM_SLOT_SIZE_EQC        ),
   .ICM_ADDR_WIDTH                  (     `ICM_SPACE_ADDR_WIDTH     ),

   .CACHE_ENTRY_WIDTH               (     `CACHE_ENTRY_WIDTH_EQC    ),
   .CACHE_SET_NUM                   (     `CACHE_SET_NUM_EQC        )
)
EQCCache_Inst
(
    .clk                            (           clk                         ),
    .rst                            (           rst                         ),

    .icm_get_req_valid              (       eqc_icm_get_req_valid           ),
    .icm_get_req_head               (       eqc_icm_get_req_head            ),
    .icm_get_req_ready              (       eqc_icm_get_req_ready           ),

    .icm_get_rsp_valid              (       eqc_icm_get_rsp_valid           ),
    .icm_get_rsp_head               (       eqc_icm_get_rsp_head            ),
    .icm_get_rsp_data               (       eqc_icm_get_rsp_data            ),
    .icm_get_rsp_ready              (       eqc_icm_get_rsp_ready           ),

    .icm_set_req_valid              (       eqc_icm_set_req_valid           ),
    .icm_set_req_head               (       eqc_icm_set_req_head            ),
    .icm_set_req_data               (       eqc_icm_set_req_data            ),
    .icm_set_req_ready              (       eqc_icm_set_req_ready           ),

    .icm_del_req_valid              (       'd0                             ),
    .icm_del_req_head               (       'd0                             ),
    .icm_del_req_ready              (                                       ),

    .dma_rd_req_valid               (       eqc_dma_rd_req_valid            ),
    .dma_rd_req_head                (       eqc_dma_rd_req_head             ),
    .dma_rd_req_data                (       eqc_dma_rd_req_data             ),
    .dma_rd_req_last                (       eqc_dma_rd_req_last             ),
    .dma_rd_req_ready               (       eqc_dma_rd_req_ready            ),

    .dma_rd_rsp_valid               (       eqc_dma_rd_rsp_valid            ),
    .dma_rd_rsp_head                (       eqc_dma_rd_rsp_head             ),
    .dma_rd_rsp_data                (       eqc_dma_rd_rsp_data             ),
    .dma_rd_rsp_last                (       eqc_dma_rd_rsp_last             ),
    .dma_rd_rsp_ready               (       eqc_dma_rd_rsp_ready            ),

    .dma_wr_req_valid               (       eqc_dma_wr_req_valid            ),
    .dma_wr_req_head                (       eqc_dma_wr_req_head             ),
    .dma_wr_req_data                (       eqc_dma_wr_req_data             ),
    .dma_wr_req_last                (       eqc_dma_wr_req_last             ),
    .dma_wr_req_ready               (       eqc_dma_wr_req_ready            ),

    .icm_mapping_set_valid          (       eqc_icm_mapping_set_valid       ),
    .icm_mapping_set_head           (       eqc_icm_mapping_set_head        ),
    .icm_mapping_set_data           (       eqc_icm_mapping_set_data        ),

    .icm_mapping_lookup_valid       (       eqc_icm_mapping_lookup_valid    ),
    .icm_mapping_lookup_head        (       eqc_icm_mapping_lookup_head     ),

    .icm_mapping_rsp_valid          (       eqc_icm_mapping_rsp_valid       ),
    .icm_mapping_rsp_icm_addr       (       eqc_icm_mapping_rsp_icm_addr    ),
    .icm_mapping_rsp_phy_addr       (       eqc_icm_mapping_rsp_phy_addr    ),

    .icm_base                       (       eqc_base                        )
 );

ICMLookupArbiter 
#(
    .ICM_ENTRY_NUM                  (           `ICM_ENTRY_NUM_QPC                  )
)
QPC_ICMLookupArbiter_Inst
(
    .clk                            (           clk                                 ),
    .rst                            (           rst                                 ),

    .chnl_0_lookup_valid            (           sw_qpc_icm_mapping_lookup_valid     ),
    .chnl_0_lookup_head             (           sw_qpc_icm_mapping_lookup_head      ),
    .chnl_0_lookup_ready            (           sw_qpc_icm_mapping_lookup_ready     ),

    .chnl_0_rsp_valid               (           sw_qpc_icm_mapping_rsp_valid        ),
    .chnl_0_rsp_icm_addr            (           sw_qpc_icm_mapping_rsp_icm_addr     ),
    .chnl_0_rsp_phy_addr            (           sw_qpc_icm_mapping_rsp_phy_addr     ),
    .chnl_0_rsp_ready               (           sw_qpc_icm_mapping_rsp_ready        ),

    .chnl_1_lookup_valid            (           hw_qpc_icm_mapping_lookup_valid     ),
    .chnl_1_lookup_head             (           hw_qpc_icm_mapping_lookup_head      ),
    .chnl_1_lookup_ready            (           hw_qpc_icm_mapping_lookup_ready     ),   

    .chnl_1_rsp_valid               (           hw_qpc_icm_mapping_rsp_valid        ),
    .chnl_1_rsp_icm_addr            (           hw_qpc_icm_mapping_rsp_icm_addr     ),
    .chnl_1_rsp_phy_addr            (           hw_qpc_icm_mapping_rsp_phy_addr     ),
    .chnl_1_rsp_ready               (           hw_qpc_icm_mapping_rsp_ready        ),

    .lookup_valid                   (           qpc_icm_mapping_lookup_valid        ),
    .lookup_head                    (           qpc_icm_mapping_lookup_head         ),

    .rsp_valid                      (           qpc_icm_mapping_rsp_valid           ),
    .rsp_icm_addr                   (           qpc_icm_mapping_rsp_icm_addr        ),
    .rsp_phy_addr                   (           qpc_icm_mapping_rsp_phy_addr        )
);

ICMLookupArbiter 
#(
    .ICM_ENTRY_NUM                  (           `ICM_ENTRY_NUM_CQC                  )
)
CQC_ICMLookupArbiter_Inst
(
    .clk                            (           clk                                 ),
    .rst                            (           rst                                 ),

    .chnl_0_lookup_valid            (           sw_cqc_icm_mapping_lookup_valid     ),
    .chnl_0_lookup_head             (           sw_cqc_icm_mapping_lookup_head      ),
    .chnl_0_lookup_ready            (           sw_cqc_icm_mapping_lookup_ready     ),

    .chnl_0_rsp_valid               (           sw_cqc_icm_mapping_rsp_valid        ),
    .chnl_0_rsp_icm_addr            (           sw_cqc_icm_mapping_rsp_icm_addr     ),
    .chnl_0_rsp_phy_addr            (           sw_cqc_icm_mapping_rsp_phy_addr     ),
    .chnl_0_rsp_ready               (           sw_cqc_icm_mapping_rsp_ready        ),

    .chnl_1_lookup_valid            (           hw_cqc_icm_mapping_lookup_valid     ),
    .chnl_1_lookup_head             (           hw_cqc_icm_mapping_lookup_head      ),
    .chnl_1_lookup_ready            (           hw_cqc_icm_mapping_lookup_ready     ),   

    .chnl_1_rsp_valid               (           hw_cqc_icm_mapping_rsp_valid        ),
    .chnl_1_rsp_icm_addr            (           hw_cqc_icm_mapping_rsp_icm_addr     ),
    .chnl_1_rsp_phy_addr            (           hw_cqc_icm_mapping_rsp_phy_addr     ),
    .chnl_1_rsp_ready               (           hw_cqc_icm_mapping_rsp_ready        ),

    .lookup_valid                   (           cqc_icm_mapping_lookup_valid        ),
    .lookup_head                    (           cqc_icm_mapping_lookup_head         ),

    .rsp_valid                      (           cqc_icm_mapping_rsp_valid           ),
    .rsp_icm_addr                   (           cqc_icm_mapping_rsp_icm_addr        ),
    .rsp_phy_addr                   (           cqc_icm_mapping_rsp_phy_addr        )
);

ICMLookupArbiter 
#(
    .ICM_ENTRY_NUM                  (           `ICM_ENTRY_NUM_EQC                  )
)
EQC_ICMLookupArbiter_Inst
(
    .clk                            (           clk                                 ),
    .rst                            (           rst                                 ),

    .chnl_0_lookup_valid            (           sw_eqc_icm_mapping_lookup_valid     ),
    .chnl_0_lookup_head             (           sw_eqc_icm_mapping_lookup_head      ),
    .chnl_0_lookup_ready            (           sw_eqc_icm_mapping_lookup_ready     ),

    .chnl_0_rsp_valid               (           sw_eqc_icm_mapping_rsp_valid        ),
    .chnl_0_rsp_icm_addr            (           sw_eqc_icm_mapping_rsp_icm_addr     ),
    .chnl_0_rsp_phy_addr            (           sw_eqc_icm_mapping_rsp_phy_addr     ),
    .chnl_0_rsp_ready               (           sw_eqc_icm_mapping_rsp_ready        ),

    .chnl_1_lookup_valid            (           hw_eqc_icm_mapping_lookup_valid     ),
    .chnl_1_lookup_head             (           hw_eqc_icm_mapping_lookup_head      ),
    .chnl_1_lookup_ready            (           hw_eqc_icm_mapping_lookup_ready     ),   

    .chnl_1_rsp_valid               (           hw_eqc_icm_mapping_rsp_valid        ),
    .chnl_1_rsp_icm_addr            (           hw_eqc_icm_mapping_rsp_icm_addr     ),
    .chnl_1_rsp_phy_addr            (           hw_eqc_icm_mapping_rsp_phy_addr     ),
    .chnl_1_rsp_ready               (           hw_eqc_icm_mapping_rsp_ready        ),

    .lookup_valid                   (           eqc_icm_mapping_lookup_valid        ),
    .lookup_head                    (           eqc_icm_mapping_lookup_head         ),

    .rsp_valid                      (           eqc_icm_mapping_rsp_valid           ),
    .rsp_icm_addr                   (           eqc_icm_mapping_rsp_icm_addr        ),
    .rsp_phy_addr                   (           eqc_icm_mapping_rsp_phy_addr        )
);

AXISArbiter
#(
    .HEAD_WIDTH                     (   `COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + `PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH   ),
    .DATA_WIDTH                     (   1   )
)
QPCGetReqArbiter_Inst
(
    .clk                            (   clk                             ),
    .rst                            (   rst                             ),

    .in_axis_valid_a                (   sw_qpc_icm_get_req_valid        ),
    .in_axis_head_a                 (   sw_qpc_icm_get_req_head         ),
    .in_axis_data_a                 (   'd0                             ),
    .in_axis_start_a                (   sw_qpc_icm_get_req_valid        ),
    .in_axis_last_a                 (   sw_qpc_icm_get_req_valid        ),
    .in_axis_ready_a                (   sw_qpc_icm_get_req_ready        ),

    .in_axis_valid_b                (   hw_qpc_icm_get_req_valid        ),
    .in_axis_head_b                 (   hw_qpc_icm_get_req_head         ),
    .in_axis_data_b                 (   'd0                             ),
    .in_axis_start_b                (   hw_qpc_icm_get_req_valid        ),
    .in_axis_last_b                 (   hw_qpc_icm_get_req_valid        ),
    .in_axis_ready_b                (   hw_qpc_icm_get_req_ready        ),

    .out_axis_valid                 (   qpc_icm_get_req_valid           ),
    .out_axis_head                  (   qpc_icm_get_req_head            ),
    .out_axis_data                  (                                   ),
    .out_axis_start                 (                                   ),
    .out_axis_last                  (                                   ),
    .out_axis_ready                 (   qpc_icm_get_req_ready           )
);

wire                is_sw_qpc_rsp;
wire                is_hw_qpc_rsp;

assign is_sw_qpc_rsp = qpc_icm_get_rsp_head[`MAX_REQ_TAG_NUM_LOG + `PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH : `PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH] == 'd0;
assign is_hw_qpc_rsp = qpc_icm_get_rsp_head[`MAX_REQ_TAG_NUM_LOG + `PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH : `PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH] != 'd0;

assign sw_qpc_icm_get_rsp_valid = is_sw_qpc_rsp ? qpc_icm_get_rsp_valid : 'd0;
assign sw_qpc_icm_get_rsp_head = is_sw_qpc_rsp ? qpc_icm_get_rsp_head : 'd0;
assign sw_qpc_icm_get_rsp_data = is_sw_qpc_rsp ? qpc_icm_get_rsp_data : 'd0;

assign hw_qpc_icm_get_rsp_valid = is_hw_qpc_rsp ? qpc_icm_get_rsp_valid : 'd0;
assign hw_qpc_icm_get_rsp_head = is_hw_qpc_rsp ? qpc_icm_get_rsp_head : 'd0;
assign hw_qpc_icm_get_rsp_data = is_hw_qpc_rsp ? qpc_icm_get_rsp_data : 'd0;

assign qpc_icm_get_rsp_ready = is_sw_qpc_rsp ? sw_qpc_icm_get_rsp_ready :
                                is_hw_qpc_rsp ? hw_qpc_icm_get_rsp_ready : 'd0;
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/
// `ifdef ILA_ON
// ila_cxt_cache ila_cxt_cache_inst(
//     .clk(clk),

//     .probe0(hw_qpc_icm_get_req_valid),
//     .probe1(hw_qpc_icm_get_rsp_valid),
//     .probe2(cqc_icm_get_req_valid),
//     .probe3(cqc_icm_get_rsp_valid),
//     .probe4(eqc_icm_get_req_valid),
//     .probe5(eqc_icm_get_rsp_valid)
// );
// `endif

endmodule