/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       MRMgt
Author:     YangFan
Function:   Memory Region Management.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module MRMgt
(
	input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with CEU
    input   wire                                                            ceu_req_valid,
    input   wire    [`CEU_MR_HEAD_WIDTH - 1 : 0]                            ceu_req_head,
    input   wire                                                            ceu_req_last,
    input   wire    [`CEU_MR_DATA_WIDTH - 1 : 0]                            ceu_req_data,
    output  wire                                                            ceu_req_ready,

//Interface with SQMgt
    input   wire                                                        	SQ_mr_req_valid,
    input   wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                        	SQ_mr_req_head,
    input   wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                        	SQ_mr_req_data,
    output  wire                                                        	SQ_mr_req_ready,

    output  wire                                                        	SQ_mr_rsp_valid,
    output  wire    [`MR_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                        	SQ_mr_rsp_head,
    output  wire    [`MR_RESP_DATA_WIDTH - 1 : 0]                        	SQ_mr_rsp_data,
    input  	wire                                                        	SQ_mr_rsp_ready,

//INterface with RQMgt
    input   wire                                                        	RQ_mr_req_valid,
    input   wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                        	RQ_mr_req_head,
    input   wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                        	RQ_mr_req_data,
    output  wire                                                        	RQ_mr_req_ready,

    output  wire                                                        	RQ_mr_rsp_valid,
    output  wire    [`MR_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                        	RQ_mr_rsp_head,
    output  wire    [`MR_RESP_DATA_WIDTH - 1 : 0]                        	RQ_mr_rsp_data,
    input  	wire                                                        	RQ_mr_rsp_ready,

//Interface with RDMACore/ReqTransCore
    input   wire                                                        	TX_REQ_mr_req_valid,
    input   wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                        	TX_REQ_mr_req_head,
    input   wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                        	TX_REQ_mr_req_data,
    output  wire                                                        	TX_REQ_mr_req_ready,

    output  wire                                                        	TX_REQ_mr_rsp_valid,
    output  wire    [`MR_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                        	TX_REQ_mr_rsp_head,
    output  wire    [`MR_RESP_DATA_WIDTH - 1 : 0]                        	TX_REQ_mr_rsp_data,
    input  	wire                                                        	TX_REQ_mr_rsp_ready,

//Interface with RDMACore/ReqRecvCore
    input   wire                                                        	RX_REQ_mr_req_valid,
    input   wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                        	RX_REQ_mr_req_head,
    input   wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                        	RX_REQ_mr_req_data,
    output  wire                                                        	RX_REQ_mr_req_ready,

    output  wire                                                        	RX_REQ_mr_rsp_valid,
    output  wire    [`MR_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                        	RX_REQ_mr_rsp_head,
    output  wire    [`MR_RESP_DATA_WIDTH - 1 : 0]                        	RX_REQ_mr_rsp_data,
    input   wire                                                        	RX_REQ_mr_rsp_ready,

//Interface with RDMACore/RespRecvCore
	input   wire                                                        	RX_RESP_mr_req_valid,
    input   wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                        	RX_RESP_mr_req_head,
    input   wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                        	RX_RESP_mr_req_data,
    output  wire                                                        	RX_RESP_mr_req_ready,

    output  wire                                                        	RX_RESP_mr_rsp_valid,
    output  wire    [`MR_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                        	RX_RESP_mr_rsp_head,
    output  wire    [`MR_RESP_DATA_WIDTH - 1 : 0]                        	RX_RESP_mr_rsp_data,
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
wire                                                                        mpt_icm_set_req_valid;
wire        [`PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH - 1 : 0]         mpt_icm_set_req_head;
wire        [`CACHE_ENTRY_WIDTH_MPT - 1 : 0]                                mpt_icm_set_req_data;
wire                                                                        mpt_icm_set_req_ready;

wire                                                                    sw_mpt_icm_mapping_lookup_valid;
wire    [log2b(`ICM_ENTRY_NUM_MPT - 1) - 1 : 0]                         sw_mpt_icm_mapping_lookup_head;
wire                                                                    sw_mpt_icm_mapping_lookup_ready;

wire                                                                    sw_mpt_icm_mapping_rsp_valid;
wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                 sw_mpt_icm_mapping_rsp_icm_addr;
wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                 sw_mpt_icm_mapping_rsp_phy_addr;
wire                                                                    sw_mpt_icm_mapping_rsp_ready;

wire                                                                    hw_mpt_icm_mapping_lookup_valid;
wire    [log2b(`ICM_ENTRY_NUM_MPT - 1) - 1 : 0]                         hw_mpt_icm_mapping_lookup_head;
wire                                                                    hw_mpt_icm_mapping_lookup_ready;

wire                                                                    hw_mpt_icm_mapping_rsp_valid;
wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                 hw_mpt_icm_mapping_rsp_icm_addr;
wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                 hw_mpt_icm_mapping_rsp_phy_addr;
wire                                                                    hw_mpt_icm_mapping_rsp_ready;

wire                                                                    mpt_icm_mapping_lookup_valid;
wire    [log2b(`ICM_ENTRY_NUM_MPT - 1) - 1 : 0]                         mpt_icm_mapping_lookup_head;
wire                                                                    mpt_icm_mapping_lookup_ready;

wire                                                                    mpt_icm_mapping_rsp_valid;
wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                 mpt_icm_mapping_rsp_icm_addr;
wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                 mpt_icm_mapping_rsp_phy_addr;
wire                                                                    mpt_icm_mapping_rsp_ready;

wire                                                                    mpt_icm_mapping_set_valid;
wire    [`PAGE_FRAME_WIDTH - 1 : 0]                                     mpt_icm_mapping_set_head;
wire    [`PAGE_FRAME_WIDTH - 1 : 0]                                     mpt_icm_mapping_set_data;

wire                                                                                                            mpt_icm_get_req_valid;
wire    [`COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + `PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH - 1 : 0]     mpt_icm_get_req_head;
wire                                                                                                            mpt_icm_get_req_ready;

wire                                                                                                            mpt_icm_get_rsp_valid;
wire    [`COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + `PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH - 1 : 0]     mpt_icm_get_rsp_head;
wire    [`CACHE_ENTRY_WIDTH_MPT - 1 : 0]                                                                        mpt_icm_get_rsp_data;
wire                                                                                                            mpt_icm_get_rsp_ready;

wire                                                                        mtt_icm_set_req_valid;
wire        [`PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH - 1 : 0]         mtt_icm_set_req_head;
wire        [`CACHE_ENTRY_WIDTH_MTT - 1 : 0]                                mtt_icm_set_req_data;
wire                                                                        mtt_icm_set_req_ready;

wire                                                                    sw_mtt_icm_mapping_lookup_valid;
wire    [log2b(`ICM_ENTRY_NUM_MTT - 1) - 1 : 0]                         sw_mtt_icm_mapping_lookup_head;
wire                                                                    sw_mtt_icm_mapping_lookup_ready;

wire                                                                    sw_mtt_icm_mapping_rsp_valid;
wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                 sw_mtt_icm_mapping_rsp_icm_addr;
wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                 sw_mtt_icm_mapping_rsp_phy_addr;
wire                                                                    sw_mtt_icm_mapping_rsp_ready;

wire                                                                    hw_mtt_icm_mapping_lookup_valid;
wire    [log2b(`ICM_ENTRY_NUM_MTT - 1) - 1 : 0]                         hw_mtt_icm_mapping_lookup_head;
wire                                                                    hw_mtt_icm_mapping_lookup_ready;

wire                                                                    hw_mtt_icm_mapping_rsp_valid;
wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                 hw_mtt_icm_mapping_rsp_icm_addr;
wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                 hw_mtt_icm_mapping_rsp_phy_addr;
wire                                                                    hw_mtt_icm_mapping_rsp_ready;

wire                                                                    mtt_icm_mapping_lookup_valid;
wire    [log2b(`ICM_ENTRY_NUM_MTT - 1) - 1 : 0]                         mtt_icm_mapping_lookup_head;
wire                                                                    mtt_icm_mapping_lookup_ready;

wire                                                                    mtt_icm_mapping_rsp_valid;
wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                 mtt_icm_mapping_rsp_icm_addr;
wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                 mtt_icm_mapping_rsp_phy_addr;
wire                                                                    mtt_icm_mapping_rsp_ready;

wire                                                                    mtt_icm_mapping_set_valid;
wire    [`PAGE_FRAME_WIDTH - 1 : 0]                                     mtt_icm_mapping_set_head;
wire    [`PAGE_FRAME_WIDTH - 1 : 0]                                     mtt_icm_mapping_set_data;

wire                                                                                                            mtt_icm_get_req_valid;
wire    [`COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + `PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH - 1 : 0]     mtt_icm_get_req_head;
wire                                                                                                            mtt_icm_get_req_ready;

wire                                                                                                            mtt_icm_get_rsp_valid;
wire    [`COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + `PHY_SPACE_ADDR_WIDTH + `ICM_SPACE_ADDR_WIDTH - 1 : 0]     mtt_icm_get_rsp_head;
wire    [`CACHE_ENTRY_WIDTH_MTT - 1 : 0]                                                                        mtt_icm_get_rsp_data;
wire                                                                                                            mtt_icm_get_rsp_ready;


wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                 mpt_base;
wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                 mtt_base;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
SWAccMRCtl SWAccMRCtl_Inst(
	.clk								(			clk                                 ),
    .rst								(			rst                                 ),

    .ceu_req_valid						(			ceu_req_valid						),
    .ceu_req_head						(			ceu_req_head						),
    .ceu_req_last						(			ceu_req_last						),
    .ceu_req_data						(			ceu_req_data						),
    .ceu_req_ready						(			ceu_req_ready						),

    .mpt_icm_set_req_valid				(			mpt_icm_set_req_valid				),
    .mpt_icm_set_req_head				(			mpt_icm_set_req_head				),
    .mpt_icm_set_req_data				(			mpt_icm_set_req_data				),
    .mpt_icm_set_req_ready				(			mpt_icm_set_req_ready				),

    .mpt_icm_mapping_lookup_valid		(			sw_mpt_icm_mapping_lookup_valid		),
    .mpt_icm_mapping_lookup_head		(			sw_mpt_icm_mapping_lookup_head		),
    .mpt_icm_mapping_lookup_ready		(			sw_mpt_icm_mapping_lookup_ready		),

    .mpt_icm_mapping_rsp_valid			(			sw_mpt_icm_mapping_rsp_valid		),
    .mpt_icm_mapping_rsp_icm_addr		(			sw_mpt_icm_mapping_rsp_icm_addr		),
    .mpt_icm_mapping_rsp_phy_addr		(			sw_mpt_icm_mapping_rsp_phy_addr		),
    .mpt_icm_mapping_rsp_ready			(			sw_mpt_icm_mapping_rsp_ready		),

    .mpt_icm_mapping_set_valid			(			mpt_icm_mapping_set_valid			),
    .mpt_icm_mapping_set_head			(			mpt_icm_mapping_set_head			),
    .mpt_icm_mapping_set_data			(			mpt_icm_mapping_set_data			),

    .mtt_icm_set_req_valid				(			mtt_icm_set_req_valid				),
    .mtt_icm_set_req_head				(			mtt_icm_set_req_head				),
    .mtt_icm_set_req_data				(			mtt_icm_set_req_data				),
    .mtt_icm_set_req_ready				(			mtt_icm_set_req_ready				),

    .mtt_icm_mapping_lookup_valid		(			sw_mtt_icm_mapping_lookup_valid		),
    .mtt_icm_mapping_lookup_head		(			sw_mtt_icm_mapping_lookup_head		),
    .mtt_icm_mapping_lookup_ready		(			sw_mtt_icm_mapping_lookup_ready		),

    .mtt_icm_mapping_rsp_valid			(			sw_mtt_icm_mapping_rsp_valid		),
    .mtt_icm_mapping_rsp_icm_addr		(			sw_mtt_icm_mapping_rsp_icm_addr		),
    .mtt_icm_mapping_rsp_phy_addr		(			sw_mtt_icm_mapping_rsp_phy_addr		),
    .mtt_icm_mapping_rsp_ready			(			sw_mtt_icm_mapping_rsp_ready		),

    .mtt_icm_mapping_set_valid			(			mtt_icm_mapping_set_valid			),
    .mtt_icm_mapping_set_head			(			mtt_icm_mapping_set_head			),
    .mtt_icm_mapping_set_data 			(			mtt_icm_mapping_set_data 			),

    .mpt_base                           (           mpt_base                            ),
    .mtt_base                           (           mtt_base                            )
);

HWAccMRCtl HWAccMRCtl_Inst(
	.clk								(		clk						            ),
	.rst								(		rst						            ),

    .SQ_mr_req_valid				(		SQ_mr_req_valid				),
    .SQ_mr_req_head					(		SQ_mr_req_head				),
    .SQ_mr_req_data					(		SQ_mr_req_data				),
    .SQ_mr_req_ready				(		SQ_mr_req_ready				),

    .SQ_mr_rsp_valid				(		SQ_mr_rsp_valid				),
    .SQ_mr_rsp_head					(		SQ_mr_rsp_head				),
    .SQ_mr_rsp_data					(		SQ_mr_rsp_data				),
    .SQ_mr_rsp_ready				(		SQ_mr_rsp_ready				),

    .RQ_mr_req_valid				(		RQ_mr_req_valid				),
    .RQ_mr_req_head					(		RQ_mr_req_head				),
    .RQ_mr_req_data					(		RQ_mr_req_data				),
    .RQ_mr_req_ready				(		RQ_mr_req_ready				),

    .RQ_mr_rsp_valid				(		RQ_mr_rsp_valid				),
    .RQ_mr_rsp_head					(		RQ_mr_rsp_head				),
    .RQ_mr_rsp_data					(		RQ_mr_rsp_data				),
    .RQ_mr_rsp_ready				(		RQ_mr_rsp_ready				),

    .TX_REQ_mr_req_valid				(		TX_REQ_mr_req_valid				),
    .TX_REQ_mr_req_head					(		TX_REQ_mr_req_head				),
    .TX_REQ_mr_req_data					(		TX_REQ_mr_req_data				),
    .TX_REQ_mr_req_ready				(		TX_REQ_mr_req_ready				),

    .TX_REQ_mr_rsp_valid				(		TX_REQ_mr_rsp_valid				),
    .TX_REQ_mr_rsp_head					(		TX_REQ_mr_rsp_head				),
    .TX_REQ_mr_rsp_data					(		TX_REQ_mr_rsp_data				),
    .TX_REQ_mr_rsp_ready				(		TX_REQ_mr_rsp_ready				),

    .RX_REQ_mr_req_valid				(		RX_REQ_mr_req_valid				),
    .RX_REQ_mr_req_head					(		RX_REQ_mr_req_head				),
    .RX_REQ_mr_req_data					(		RX_REQ_mr_req_data				),
    .RX_REQ_mr_req_ready				(		RX_REQ_mr_req_ready				),

    .RX_REQ_mr_rsp_valid				(		RX_REQ_mr_rsp_valid				),
    .RX_REQ_mr_rsp_head					(		RX_REQ_mr_rsp_head				),
    .RX_REQ_mr_rsp_data					(		RX_REQ_mr_rsp_data				),
    .RX_REQ_mr_rsp_ready				(		RX_REQ_mr_rsp_ready				),

	.RX_RESP_mr_req_valid				(		RX_RESP_mr_req_valid			),
    .RX_RESP_mr_req_head				(		RX_RESP_mr_req_head				),
    .RX_RESP_mr_req_data				(		RX_RESP_mr_req_data				),
    .RX_RESP_mr_req_ready				(		RX_RESP_mr_req_ready			),

    .RX_RESP_mr_rsp_valid				(		RX_RESP_mr_rsp_valid			),
    .RX_RESP_mr_rsp_head				(		RX_RESP_mr_rsp_head				),
    .RX_RESP_mr_rsp_data				(		RX_RESP_mr_rsp_data				),
    .RX_RESP_mr_rsp_ready				(		RX_RESP_mr_rsp_ready			),

    .mpt_icm_mapping_lookup_valid			(		hw_mpt_icm_mapping_lookup_valid		),
    .mpt_icm_mapping_lookup_head			(		hw_mpt_icm_mapping_lookup_head		),
    .mpt_icm_mapping_lookup_ready			(		hw_mpt_icm_mapping_lookup_ready		),

    .mpt_icm_mapping_rsp_valid				(		hw_mpt_icm_mapping_rsp_valid		),
    .mpt_icm_mapping_rsp_icm_addr			(		hw_mpt_icm_mapping_rsp_icm_addr		),
    .mpt_icm_mapping_rsp_phy_addr			(		hw_mpt_icm_mapping_rsp_phy_addr		),
    .mpt_icm_mapping_rsp_ready           (       hw_mpt_icm_mapping_rsp_ready     ),

    .mpt_icm_get_req_valid					(		mpt_icm_get_req_valid				),
    .mpt_icm_get_req_head					(		mpt_icm_get_req_head				),
    .mpt_icm_get_req_ready					(		mpt_icm_get_req_ready				),

    .mpt_icm_get_rsp_valid					(		mpt_icm_get_rsp_valid				),
    .mpt_icm_get_rsp_head					(		mpt_icm_get_rsp_head				),
    .mpt_icm_get_rsp_data					(		mpt_icm_get_rsp_data				),
    .mpt_icm_get_rsp_ready					(		mpt_icm_get_rsp_ready				),

    .mtt_icm_mapping_lookup_valid			(		hw_mtt_icm_mapping_lookup_valid		),
    .mtt_icm_mapping_lookup_head			(		hw_mtt_icm_mapping_lookup_head		),
    .mtt_icm_mapping_lookup_ready			(		hw_mtt_icm_mapping_lookup_ready		),

    .mtt_icm_mapping_rsp_valid				(		hw_mtt_icm_mapping_rsp_valid		),
    .mtt_icm_mapping_rsp_icm_addr			(		hw_mtt_icm_mapping_rsp_icm_addr		),
    .mtt_icm_mapping_rsp_phy_addr			(		hw_mtt_icm_mapping_rsp_phy_addr		),
    .mtt_icm_mapping_rsp_ready           (       hw_mtt_icm_mapping_rsp_ready     ),

    .mtt_icm_get_req_valid					(		mtt_icm_get_req_valid				),
    .mtt_icm_get_req_head					(		mtt_icm_get_req_head				),
    .mtt_icm_get_req_ready					(		mtt_icm_get_req_ready				),

    .mtt_icm_get_rsp_valid					(		mtt_icm_get_rsp_valid				),
    .mtt_icm_get_rsp_head					(		mtt_icm_get_rsp_head				),
    .mtt_icm_get_rsp_data					(		mtt_icm_get_rsp_data				),
    .mtt_icm_get_rsp_ready 					(		mtt_icm_get_rsp_ready				)
);

ICMCache #(
   .ICM_CACHE_TYPE                  (     `CACHE_TYPE_MPT           ),
   .ICM_PAGE_NUM                    (     `ICM_PAGE_NUM_MPT         ),

   .ICM_ENTRY_NUM                   (     `ICM_ENTRY_NUM_MPT        ),

   .ICM_SLOT_SIZE                   (     `ICM_SLOT_SIZE_MPT        ),
   .ICM_ADDR_WIDTH                  (     `ICM_SPACE_ADDR_WIDTH     ),

   .CACHE_ENTRY_WIDTH               (     `CACHE_ENTRY_WIDTH_MPT    ),
   .CACHE_SET_NUM                   (     `CACHE_SET_NUM_MPT        )
)
MPTCache_Inst
(
    .clk							(			clk						        ),
    .rst							(			rst						        ),

    .icm_get_req_valid				(			mpt_icm_get_req_valid			),
    .icm_get_req_head				(			mpt_icm_get_req_head			),
    .icm_get_req_ready				(			mpt_icm_get_req_ready			),

    .icm_get_rsp_valid				(			mpt_icm_get_rsp_valid			),
    .icm_get_rsp_head				(			mpt_icm_get_rsp_head			),
    .icm_get_rsp_data				(			mpt_icm_get_rsp_data			),
    .icm_get_rsp_ready				(			mpt_icm_get_rsp_ready			),

    .icm_set_req_valid				(			mpt_icm_set_req_valid			),
    .icm_set_req_head				(			mpt_icm_set_req_head			),
    .icm_set_req_data				(			mpt_icm_set_req_data			),
    .icm_set_req_ready				(			mpt_icm_set_req_ready			),

    .icm_del_req_valid				(          'd0                              ),
    .icm_del_req_head				(          'd0                              ),
    .icm_del_req_ready				(			                          		),

    .dma_rd_req_valid				(			mpt_dma_rd_req_valid			),
    .dma_rd_req_head				(			mpt_dma_rd_req_head				),
    .dma_rd_req_data				(			mpt_dma_rd_req_data				),
    .dma_rd_req_last				(			mpt_dma_rd_req_last				),
    .dma_rd_req_ready				(			mpt_dma_rd_req_ready			),

    .dma_rd_rsp_valid				(			mpt_dma_rd_rsp_valid			),
    .dma_rd_rsp_head				(			mpt_dma_rd_rsp_head				),
    .dma_rd_rsp_data				(			mpt_dma_rd_rsp_data				),
    .dma_rd_rsp_last				(			mpt_dma_rd_rsp_last				),
    .dma_rd_rsp_ready				(			mpt_dma_rd_rsp_ready			),

    .dma_wr_req_valid				(			mpt_dma_wr_req_valid			),
    .dma_wr_req_head				(			mpt_dma_wr_req_head				),
    .dma_wr_req_data				(			mpt_dma_wr_req_data				),
    .dma_wr_req_last				(			mpt_dma_wr_req_last				),
    .dma_wr_req_ready				(			mpt_dma_wr_req_ready			),

    .icm_mapping_set_valid			(			mpt_icm_mapping_set_valid		),
    .icm_mapping_set_head			(			mpt_icm_mapping_set_head		),
    .icm_mapping_set_data			(			mpt_icm_mapping_set_data		),

    .icm_mapping_lookup_valid		(			mpt_icm_mapping_lookup_valid	),
    .icm_mapping_lookup_head		(			mpt_icm_mapping_lookup_head		),

    .icm_mapping_rsp_valid			(			mpt_icm_mapping_rsp_valid		),
    .icm_mapping_rsp_icm_addr		(			mpt_icm_mapping_rsp_icm_addr	),
    .icm_mapping_rsp_phy_addr		(			mpt_icm_mapping_rsp_phy_addr	),

    .icm_base                       (           mpt_base                        )
 );

ICMCache #(
   .ICM_CACHE_TYPE                  (     `CACHE_TYPE_MTT           ),
   .ICM_PAGE_NUM                    (     `ICM_PAGE_NUM_MTT         ),

   .ICM_ENTRY_NUM                   (     `ICM_ENTRY_NUM_MTT        ),

   .ICM_SLOT_SIZE                   (     `ICM_SLOT_SIZE_MTT        ),
   .ICM_ADDR_WIDTH                  (     `ICM_SPACE_ADDR_WIDTH     ),

   .CACHE_ENTRY_WIDTH               (     `CACHE_ENTRY_WIDTH_MTT    ),
   .CACHE_SET_NUM                   (     `CACHE_SET_NUM_MTT        )
)
MTTCache_Inst
(
    .clk							(			clk								),
    .rst							(			rst								),

    .icm_get_req_valid				(			mtt_icm_get_req_valid			),
    .icm_get_req_head				(			mtt_icm_get_req_head			),
    .icm_get_req_ready				(			mtt_icm_get_req_ready			),

    .icm_get_rsp_valid				(			mtt_icm_get_rsp_valid			),
    .icm_get_rsp_head				(			mtt_icm_get_rsp_head			),
    .icm_get_rsp_data				(			mtt_icm_get_rsp_data			),
    .icm_get_rsp_ready				(			mtt_icm_get_rsp_ready			),

    .icm_set_req_valid				(			mtt_icm_set_req_valid			),
    .icm_set_req_head				(			mtt_icm_set_req_head			),
    .icm_set_req_data				(			mtt_icm_set_req_data			),
    .icm_set_req_ready				(			mtt_icm_set_req_ready			),

    .icm_del_req_valid				(          'd0                              ),
    .icm_del_req_head				(          'd0                              ),
    .icm_del_req_ready				(						                    ),

    .dma_rd_req_valid				(			mtt_dma_rd_req_valid			),
    .dma_rd_req_head				(			mtt_dma_rd_req_head				),
    .dma_rd_req_data				(			mtt_dma_rd_req_data				),
    .dma_rd_req_last				(			mtt_dma_rd_req_last				),
    .dma_rd_req_ready				(			mtt_dma_rd_req_ready			),

    .dma_rd_rsp_valid				(			mtt_dma_rd_rsp_valid			),
    .dma_rd_rsp_head				(			mtt_dma_rd_rsp_head				),
    .dma_rd_rsp_data				(			mtt_dma_rd_rsp_data				),
    .dma_rd_rsp_last				(			mtt_dma_rd_rsp_last				),
    .dma_rd_rsp_ready				(			mtt_dma_rd_rsp_ready			),

    .dma_wr_req_valid				(			mtt_dma_wr_req_valid			),
    .dma_wr_req_head				(			mtt_dma_wr_req_head				),
    .dma_wr_req_data				(			mtt_dma_wr_req_data				),
    .dma_wr_req_last				(			mtt_dma_wr_req_last				),
    .dma_wr_req_ready				(			mtt_dma_wr_req_ready			),

    .icm_mapping_set_valid			(			mtt_icm_mapping_set_valid		),
    .icm_mapping_set_head			(			mtt_icm_mapping_set_head		),
    .icm_mapping_set_data			(			mtt_icm_mapping_set_data		),

    .icm_mapping_lookup_valid		(			mtt_icm_mapping_lookup_valid	),
    .icm_mapping_lookup_head		(			mtt_icm_mapping_lookup_head		),

    .icm_mapping_rsp_valid			(			mtt_icm_mapping_rsp_valid		),
    .icm_mapping_rsp_icm_addr		(			mtt_icm_mapping_rsp_icm_addr	),
    .icm_mapping_rsp_phy_addr		(			mtt_icm_mapping_rsp_phy_addr	),

    .icm_base                       (           mtt_base                        )
 );

ICMLookupArbiter 
#(
    .ICM_ENTRY_NUM                  (           `ICM_ENTRY_NUM_MPT                  )
)
MPT_ICMLookupArbiter_Inst
(
	.clk							(			clk									),
    .rst							(			rst									),

    .chnl_0_lookup_valid			(			sw_mpt_icm_mapping_lookup_valid		),
    .chnl_0_lookup_head				(			sw_mpt_icm_mapping_lookup_head		),
    .chnl_0_lookup_ready            (           sw_mpt_icm_mapping_lookup_ready     ),

    .chnl_0_rsp_valid				(			sw_mpt_icm_mapping_rsp_valid		),
    .chnl_0_rsp_icm_addr			(			sw_mpt_icm_mapping_rsp_icm_addr		),
    .chnl_0_rsp_phy_addr			(			sw_mpt_icm_mapping_rsp_phy_addr		),
    .chnl_0_rsp_ready               (           sw_mpt_icm_mapping_rsp_ready        ),

    .chnl_1_lookup_valid			(			hw_mpt_icm_mapping_lookup_valid		),
    .chnl_1_lookup_head				(			hw_mpt_icm_mapping_lookup_head		),
    .chnl_1_lookup_ready            (           hw_mpt_icm_mapping_lookup_ready     ),   

    .chnl_1_rsp_valid				(			hw_mpt_icm_mapping_rsp_valid		),
    .chnl_1_rsp_icm_addr			(			hw_mpt_icm_mapping_rsp_icm_addr		),
    .chnl_1_rsp_phy_addr			(			hw_mpt_icm_mapping_rsp_phy_addr		),
    .chnl_1_rsp_ready               (           hw_mpt_icm_mapping_rsp_ready        ),

    .lookup_valid					(			mpt_icm_mapping_lookup_valid		),
    .lookup_head					(			mpt_icm_mapping_lookup_head			),

    .rsp_valid						(			mpt_icm_mapping_rsp_valid			),
    .rsp_icm_addr					(			mpt_icm_mapping_rsp_icm_addr		),
    .rsp_phy_addr					(			mpt_icm_mapping_rsp_phy_addr		)
);

ICMLookupArbiter 
#(
    .ICM_ENTRY_NUM                  (           `ICM_ENTRY_NUM_MTT                  )
)
MTT_ICMLookupArbiter_Inst
(
    .clk                            (           clk                                 ),
    .rst                            (           rst                                 ),

    .chnl_0_lookup_valid            (           sw_mtt_icm_mapping_lookup_valid     ),
    .chnl_0_lookup_head             (           sw_mtt_icm_mapping_lookup_head      ),
    .chnl_0_lookup_ready            (           sw_mtt_icm_mapping_lookup_ready     ),

    .chnl_0_rsp_valid               (           sw_mtt_icm_mapping_rsp_valid        ),
    .chnl_0_rsp_icm_addr            (           sw_mtt_icm_mapping_rsp_icm_addr     ),
    .chnl_0_rsp_phy_addr            (           sw_mtt_icm_mapping_rsp_phy_addr     ),
    .chnl_0_rsp_ready               (           sw_mtt_icm_mapping_rsp_ready        ),

    .chnl_1_lookup_valid            (           hw_mtt_icm_mapping_lookup_valid     ),
    .chnl_1_lookup_head             (           hw_mtt_icm_mapping_lookup_head      ),
    .chnl_1_lookup_ready            (           hw_mtt_icm_mapping_lookup_ready     ),   

    .chnl_1_rsp_valid               (           hw_mtt_icm_mapping_rsp_valid        ),
    .chnl_1_rsp_icm_addr            (           hw_mtt_icm_mapping_rsp_icm_addr     ),
    .chnl_1_rsp_phy_addr            (           hw_mtt_icm_mapping_rsp_phy_addr     ),
    .chnl_1_rsp_ready               (           hw_mtt_icm_mapping_rsp_ready        ),

    .lookup_valid                   (           mtt_icm_mapping_lookup_valid        ),
    .lookup_head                    (           mtt_icm_mapping_lookup_head         ),

    .rsp_valid                      (           mtt_icm_mapping_rsp_valid           ),
    .rsp_icm_addr                   (           mtt_icm_mapping_rsp_icm_addr        ),
    .rsp_phy_addr                   (           mtt_icm_mapping_rsp_phy_addr        )
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule