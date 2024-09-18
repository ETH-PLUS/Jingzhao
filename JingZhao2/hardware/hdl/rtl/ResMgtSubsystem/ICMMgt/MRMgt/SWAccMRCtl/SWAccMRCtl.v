/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       SWAccMRCtl
Author:     YangFan
Function:   Control Software to MRMgt Access.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module SWAccMRCtl
(
	input   wire                                                                       clk,
    input   wire                                                                        rst,

//Interface with CEU
    input   wire                                                                        ceu_req_valid,
    input   wire    [`CEU_MR_HEAD_WIDTH - 1 : 0]                                        ceu_req_head,
    input   wire                                                                        ceu_req_last,
    input   wire    [`CEU_MR_DATA_WIDTH - 1 : 0]                                        ceu_req_data,
    output  wire                                                                        ceu_req_ready,

//Interface with MPTCache(ICMCache)
    output  wire                                                                                                        mpt_icm_set_req_valid,
    output  wire    [`REQ_TAG_NUM_LOG + `COUNT_MAX_LOG * 2 + `ICM_SPACE_ADDR_WIDTH + `PHY_SPACE_ADDR_WIDTH - 1 : 0]     mpt_icm_set_req_head,
    output  wire    [`CACHE_ENTRY_WIDTH_MPT - 1 : 0]                                                                    mpt_icm_set_req_data,
    input   wire                                                                                                        mpt_icm_set_req_ready,

    output  wire                                                                        mpt_icm_mapping_lookup_valid,
    output  wire    [log2b(`ICM_ENTRY_NUM_MPT - 1) - 1 : 0]                             mpt_icm_mapping_lookup_head,
    input   wire                                                                        mpt_icm_mapping_lookup_ready,

    input   wire                                                                        mpt_icm_mapping_rsp_valid,
    input   wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                     mpt_icm_mapping_rsp_icm_addr,
    input   wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                     mpt_icm_mapping_rsp_phy_addr,
    output  wire                                                                        mpt_icm_mapping_rsp_ready,

    output  wire                                                                        mpt_icm_mapping_set_valid,
    output  wire    [`PAGE_FRAME_WIDTH - 1 : 0]                                         mpt_icm_mapping_set_head,
    output  wire    [`PAGE_FRAME_WIDTH - 1 : 0]                                         mpt_icm_mapping_set_data,

    output  wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                     mpt_base,

//Interface with MPTCache(ICMCache)
    output  wire                                                                                                            mtt_icm_set_req_valid,
    output  wire    [`REQ_TAG_NUM_LOG + `COUNT_MAX_LOG * 2 + `ICM_SPACE_ADDR_WIDTH + `PHY_SPACE_ADDR_WIDTH - 1 : 0]         mtt_icm_set_req_head,
    output  wire    [`CACHE_ENTRY_WIDTH_MTT - 1 : 0]                                                                        mtt_icm_set_req_data,
    input   wire                                                                                                            mtt_icm_set_req_ready,

    output  wire                                                                        mtt_icm_mapping_lookup_valid,
    output  wire    [log2b(`ICM_ENTRY_NUM_MTT - 1) - 1 : 0]                             mtt_icm_mapping_lookup_head,
    input   wire                                                                        mtt_icm_mapping_lookup_ready,

    input   wire                                                                        mtt_icm_mapping_rsp_valid,
    input   wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                     mtt_icm_mapping_rsp_icm_addr,
    input   wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                     mtt_icm_mapping_rsp_phy_addr,
    output  wire                                                                        mtt_icm_mapping_rsp_ready,

    output  wire                                                                        mtt_icm_mapping_set_valid,
    output  wire    [`PAGE_FRAME_WIDTH - 1 : 0]                                         mtt_icm_mapping_set_head,
    output  wire    [`PAGE_FRAME_WIDTH - 1 : 0]                                         mtt_icm_mapping_set_data,

    output  wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                     mtt_base
);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/

/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                                            mpt_req_valid;
wire    [`CEU_MR_HEAD_WIDTH - 1 : 0]                            mpt_req_head;
wire                                                            mpt_req_last;
wire    [`CEU_MR_DATA_WIDTH - 1 : 0]                            mpt_req_data;
wire                                                            mpt_req_ready;

wire                                                            mtt_req_valid;
wire    [`CEU_MR_HEAD_WIDTH - 1 : 0]                            mtt_req_head;
wire                                                            mtt_req_last;
wire    [`CEU_MR_DATA_WIDTH - 1 : 0]                            mtt_req_data;
wire                                                            mtt_req_ready;

wire                                                            mapping_req_valid;
wire    [`CEU_MR_HEAD_WIDTH - 1 : 0]                            mapping_req_head;
wire                                                            mapping_req_last;
wire    [`CEU_MR_DATA_WIDTH - 1 : 0]                            mapping_req_data;
wire                                                            mapping_req_ready;

/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
SWAccMRCtl_Thread_1 SWAccMRCtl_Thread_1_Inst(
    .clk					(			clk						),
    .rst					(			rst						),

    .ceu_req_valid			(			ceu_req_valid			),
    .ceu_req_head			(			ceu_req_head			),
    .ceu_req_last			(			ceu_req_last			),
    .ceu_req_data			(			ceu_req_data			),
    .ceu_req_ready			(			ceu_req_ready			),

    .mpt_req_valid			(			mpt_req_valid			),
    .mpt_req_head			(			mpt_req_head			),
    .mpt_req_last			(			mpt_req_last			),
    .mpt_req_data			(			mpt_req_data			),
    .mpt_req_ready			(			mpt_req_ready			),

    .mtt_req_valid			(			mtt_req_valid			),
    .mtt_req_head			(			mtt_req_head			),
    .mtt_req_last			(			mtt_req_last			),
    .mtt_req_data			(			mtt_req_data			),
    .mtt_req_ready			(			mtt_req_ready			),

    .mapping_req_valid		(			mapping_req_valid		),
    .mapping_req_head		(			mapping_req_head		),
    .mapping_req_last		(			mapping_req_last		),
    .mapping_req_data		(			mapping_req_data		),
    .mapping_req_ready		(			mapping_req_ready		)
);

SWAccMRCtl_Thread_2 SWAccMRCtl_Thread_2_Inst (
	.clk								(		clk								),
	.rst								(		rst								),

	.mpt_req_valid						(		mpt_req_valid					),
	.mpt_req_head						(		mpt_req_head					),
	.mpt_req_last						(		mpt_req_last					),
	.mpt_req_data						(		mpt_req_data					),
	.mpt_req_ready						(		mpt_req_ready					),

	.cache_set_req_valid				(		mpt_icm_set_req_valid			),
	.cache_set_req_head					(		mpt_icm_set_req_head			),
	.cache_set_req_data					(		mpt_icm_set_req_data			),
	.cache_set_req_ready				(		mpt_icm_set_req_ready			),

	.icm_mapping_lookup_valid			(		mpt_icm_mapping_lookup_valid	),
	.icm_mapping_lookup_head			(		mpt_icm_mapping_lookup_head		),
	.icm_mapping_lookup_ready			(		mpt_icm_mapping_lookup_ready	),

	.icm_mapping_rsp_valid				(		mpt_icm_mapping_rsp_valid		),
	.icm_mapping_rsp_icm_addr			(		mpt_icm_mapping_rsp_icm_addr	),
	.icm_mapping_rsp_phy_addr			(		mpt_icm_mapping_rsp_phy_addr	),
	.icm_mapping_rsp_ready				(		mpt_icm_mapping_rsp_ready		)
);

SWAccMRCtl_Thread_3 SWAccMRCtl_Thread_3_Inst (
    .clk								(		clk								),
    .rst								(		rst								),

    .mtt_req_valid						(		mtt_req_valid					),
    .mtt_req_head						(		mtt_req_head					),
    .mtt_req_last						(		mtt_req_last					),
    .mtt_req_data						(		mtt_req_data					),
    .mtt_req_ready						(		mtt_req_ready					),

    .cache_set_req_valid				(		mtt_icm_set_req_valid			),
    .cache_set_req_head					(		mtt_icm_set_req_head			),
    .cache_set_req_data					(		mtt_icm_set_req_data			),
    .cache_set_req_ready				(		mtt_icm_set_req_ready			),

    .icm_mapping_lookup_valid			(		mtt_icm_mapping_lookup_valid	),
    .icm_mapping_lookup_head			(		mtt_icm_mapping_lookup_head		),
    .icm_mapping_lookup_ready			(		mtt_icm_mapping_lookup_ready	),

    .icm_mapping_rsp_valid				(		mtt_icm_mapping_rsp_valid		),
    .icm_mapping_rsp_icm_addr			(		mtt_icm_mapping_rsp_icm_addr	),
    .icm_mapping_rsp_phy_addr			(		mtt_icm_mapping_rsp_phy_addr	),
    .icm_mapping_rsp_ready				(		mtt_icm_mapping_rsp_ready		)
);

SWAccMRCtl_Thread_4 SWAccMRCtl_Thread_4_Inst(
    .clk								(		clk							),
    .rst								(		rst							),
	
    .map_req_valid						(		mapping_req_valid			),
    .map_req_head						(		mapping_req_head			),
    .map_req_last						(		mapping_req_last			),
    .map_req_data						(		mapping_req_data			),
    .map_req_ready						(		mapping_req_ready			),

    .mpt_mapping_set_valid				(		mpt_icm_mapping_set_valid	),
    .mpt_mapping_set_head				(		mpt_icm_mapping_set_head	),
    .mpt_mapping_set_data				(		mpt_icm_mapping_set_data	),

    .mtt_mapping_set_valid				(		mtt_icm_mapping_set_valid	),
    .mtt_mapping_set_head				(		mtt_icm_mapping_set_head	),
    .mtt_mapping_set_data				(		mtt_icm_mapping_set_data	),

    .mpt_base                           (       mpt_base                    ),
    .mtt_base                           (       mtt_base                    )
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule