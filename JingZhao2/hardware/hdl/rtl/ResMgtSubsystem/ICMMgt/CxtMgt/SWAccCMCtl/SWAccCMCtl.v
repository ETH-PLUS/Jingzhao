/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       SWAccCMCtl
Author:     YangFan
Function:   Control Software to CxtMgt Access.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module SWAccCMCtl
#(
    parameter               ICM_CACHE_TYPE          =       `CACHE_TYPE_QPC,
    parameter               ICM_PAGE_NUM            =       `ICM_PAGE_NUM_QPC,
    parameter               ICM_PAGE_NUM_LOG        =       log2b(ICM_PAGE_NUM - 1),
    parameter               ICM_ENTRY_NUM           =       `ICM_ENTRY_NUM_QPC,
    parameter               ICM_ENTRY_NUM_LOG       =       log2b(ICM_ENTRY_NUM - 1),
    parameter               ICM_SLOT_SIZE           =       `ICM_SLOT_SIZE_QPC,
    parameter               ICM_ADDR_WIDTH          =       64,

    parameter               CACHE_ADDR_WIDTH        =       64,
    parameter               CACHE_ENTRY_WIDTH       =       `CACHE_ENTRY_WIDTH_QPC,
    parameter               CACHE_SET_NUM           =       1024,
    parameter               CACHE_SET_NUM_LOG       =       log2b(CACHE_SET_NUM - 1),
    parameter               CACHE_OFFSET_WIDTH      =       log2b(CACHE_ENTRY_WIDTH / 8 - 1),
    parameter               CACHE_TAG_WIDTH         =       CACHE_ADDR_WIDTH - CACHE_OFFSET_WIDTH - CACHE_SET_NUM_LOG,
    parameter               PHYSICAL_ADDR_WIDTH     =       64,
    parameter               COUNT_MAX               =       2,
    parameter               COUNT_MAX_LOG           =       log2b(COUNT_MAX - 1) + 1,
    parameter               REQ_TAG_NUM             =       32,
    parameter               REQ_TAG_NUM_LOG         =       log2b(REQ_TAG_NUM - 1),
    parameter               REORDER_BUFFER_WIDTH    =       (ICM_CACHE_TYPE == `CACHE_TYPE_QPC) ? CACHE_ENTRY_WIDTH * 2 + COUNT_MAX_LOG : CACHE_ENTRY_WIDTH + COUNT_MAX_LOG 
)
(
    input   wire                                                            clk,
    input   wire                                                            rst,

/*****************************************	Interface with CEU *******************************************/
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

/*****************************************	Interface with QPCCache *******************************************/
//Set QPC ICM Mapping Table Entry
    output  wire                                                           										qpc_mapping_set_valid,
    output  wire     [`PAGE_FRAME_WIDTH - 1 : 0]                            									qpc_mapping_set_head,
    output  wire     [`PAGE_FRAME_WIDTH - 1 : 0]                           										qpc_mapping_set_data,

//ICM Get Req Interface
    output  wire                                                                                                        qpc_cache_get_req_valid,
    output  wire    [`MAX_REQ_TAG_NUM_LOG + `COUNT_MAX_LOG * 2 + `ICM_SPACE_ADDR_WIDTH + `PHY_SPACE_ADDR_WIDTH - 1 : 0]     qpc_cache_get_req_head,
    input   wire                                                                                                        qpc_cache_get_req_ready,

//ICM Get Resp Interface
    input   wire                                                                                                        qpc_cache_get_rsp_valid,
    input   wire    [`MAX_REQ_TAG_NUM_LOG + `COUNT_MAX_LOG * 2 + `ICM_SPACE_ADDR_WIDTH + `PHY_SPACE_ADDR_WIDTH - 1 : 0]     qpc_cache_get_rsp_head,
    input   wire    [`CACHE_ENTRY_WIDTH_QPC - 1 : 0]                                                                    qpc_cache_get_rsp_data,
    output  wire                                                                                                        qpc_cache_get_rsp_ready,

//Cache Set Req Interface
    output  wire                                                                                                        qpc_cache_set_req_valid,
    output  wire    [`MAX_REQ_TAG_NUM_LOG + `COUNT_MAX_LOG * 2 + `ICM_SPACE_ADDR_WIDTH + `PHY_SPACE_ADDR_WIDTH - 1 : 0]     qpc_cache_set_req_head,
    output  wire    [`CACHE_ENTRY_WIDTH_QPC - 1 : 0]                                                                    qpc_cache_set_req_data,
    input   wire                                                                                                        qpc_cache_set_req_ready,

//ICM Address Translation Interface
    output  wire                                                                                                qpc_icm_mapping_lookup_valid,
    output  wire    [log2b(`ICM_ENTRY_NUM_QPC - 1) - 1 : 0]                                                     qpc_icm_mapping_lookup_head,
    input   wire                                                                                                qpc_icm_mapping_lookup_ready,

    input   wire                                                                                                qpc_icm_mapping_rsp_valid,
    input   wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                                             qpc_icm_mapping_rsp_icm_addr,
    input   wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                                             qpc_icm_mapping_rsp_phy_addr,
    output  wire                                                                                                qpc_icm_mapping_rsp_ready,

    output  wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                                             qpc_base,

/*****************************************	Interface with CQCCache *******************************************/
//Set CQC ICM Mapping Table Entry
    output  wire                                                                                                cqc_mapping_set_valid,
    output  wire     [`PAGE_FRAME_WIDTH - 1 : 0]                                                                cqc_mapping_set_head,
    output  wire     [`PAGE_FRAME_WIDTH - 1 : 0]                                                                cqc_mapping_set_data,

//Cache Set Req Interface
    output  wire                                                                                                        cqc_cache_set_req_valid,
    output  wire    [`MAX_REQ_TAG_NUM_LOG + `COUNT_MAX_LOG * 2 + `ICM_SPACE_ADDR_WIDTH + `PHY_SPACE_ADDR_WIDTH - 1 : 0]     cqc_cache_set_req_head,
    output  wire    [`CACHE_ENTRY_WIDTH_CQC - 1 : 0]                                                                    cqc_cache_set_req_data,
    input   wire                                                                                                        cqc_cache_set_req_ready,

//ICM Address Translation Interface
    output  wire                                                                                                cqc_icm_mapping_lookup_valid,
    output  wire    [log2b(`ICM_ENTRY_NUM_CQC - 1) - 1 : 0]                                                     cqc_icm_mapping_lookup_head,
    input   wire                                                                                                cqc_icm_mapping_lookup_ready,

    input   wire                                                                                                cqc_icm_mapping_rsp_valid,
    input   wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                                             cqc_icm_mapping_rsp_icm_addr,
    input   wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                                             cqc_icm_mapping_rsp_phy_addr,
    output  wire                                                                                                cqc_icm_mapping_rsp_ready,

    output  wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                                             cqc_base,

/*****************************************	Interface with EQCCache *******************************************/
//Set CQC ICM Mapping Table Entry
    output  wire                                                                                                eqc_mapping_set_valid,
    output  wire     [`PAGE_FRAME_WIDTH - 1 : 0]                                                                eqc_mapping_set_head,
    output  wire     [`PAGE_FRAME_WIDTH - 1 : 0]                                                                eqc_mapping_set_data,

//Cache Set Req Interface
    output  wire                                                                                                        eqc_cache_set_req_valid,
    output  wire    [`MAX_REQ_TAG_NUM_LOG + `COUNT_MAX_LOG * 2 + `ICM_SPACE_ADDR_WIDTH + `PHY_SPACE_ADDR_WIDTH - 1 : 0]     eqc_cache_set_req_head,
    output  wire    [`CACHE_ENTRY_WIDTH_EQC - 1 : 0]                                                                    eqc_cache_set_req_data,
    input   wire                                                                                                        eqc_cache_set_req_ready,

//ICM Address Translation Interface
    output  wire                                                                                                eqc_icm_mapping_lookup_valid,
    output  wire    [log2b(`ICM_ENTRY_NUM_EQC - 1) - 1 : 0]                                                     eqc_icm_mapping_lookup_head,
    input   wire                                                                                                eqc_icm_mapping_lookup_ready,

    input   wire                                                                                                eqc_icm_mapping_rsp_valid,
    input   wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                                             eqc_icm_mapping_rsp_icm_addr,
    input   wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                                             eqc_icm_mapping_rsp_phy_addr,
    output  wire                                                                                                eqc_icm_mapping_rsp_ready,

    output  wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                                             eqc_base


);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/

/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                                            qpc_req_valid;
wire    [`CEU_CXT_HEAD_WIDTH - 1 : 0]                           qpc_req_head;
wire                                                            qpc_req_last;
wire    [`CEU_CXT_DATA_WIDTH - 1 : 0]                           qpc_req_data;
wire                                                            qpc_req_ready;

wire                                                            cqc_req_valid;
wire    [`CEU_CXT_HEAD_WIDTH - 1 : 0]                           cqc_req_head;
wire                                                            cqc_req_last;
wire    [`CEU_CXT_DATA_WIDTH - 1 : 0]                           cqc_req_data;
wire                                                            cqc_req_ready;

wire                                                            eqc_req_valid;
wire    [`CEU_CXT_HEAD_WIDTH - 1 : 0]                           eqc_req_head;
wire                                                            eqc_req_last;
wire    [`CEU_CXT_DATA_WIDTH - 1 : 0]                           eqc_req_data;
wire                                                            eqc_req_ready;

wire                                                            mapping_req_valid;
wire    [`CEU_CXT_HEAD_WIDTH - 1 : 0]                           mapping_req_head;
wire                                                            mapping_req_last;
wire    [`CEU_CXT_DATA_WIDTH - 1 : 0]                           mapping_req_data;
wire                                                            mapping_req_ready;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
SWAccCMCtl_Thread_1 SWAccCMCtl_Thread_1_Inst(
    .clk							(	clk						),
    .rst							(	rst						),

    .ceu_req_valid					(	ceu_req_valid			),
    .ceu_req_head					(	ceu_req_head			),
    .ceu_req_last					(	ceu_req_last			),
    .ceu_req_data					(	ceu_req_data			),
    .ceu_req_ready					(	ceu_req_ready			),

    .qpc_req_valid					(	qpc_req_valid			),
    .qpc_req_head					(	qpc_req_head			),
    .qpc_req_last					(	qpc_req_last			),
    .qpc_req_data					(	qpc_req_data			),
    .qpc_req_ready					(	qpc_req_ready			),

    .cqc_req_valid					(	cqc_req_valid			),
    .cqc_req_head					(	cqc_req_head			),
    .cqc_req_last					(	cqc_req_last			),
    .cqc_req_data					(	cqc_req_data			),
    .cqc_req_ready					(	cqc_req_ready			),

    .eqc_req_valid					(	eqc_req_valid			),
    .eqc_req_head					(	eqc_req_head			),
    .eqc_req_last					(	eqc_req_last			),
    .eqc_req_data					(	eqc_req_data			),
    .eqc_req_ready					(	eqc_req_ready			),

    .mapping_req_valid				(	mapping_req_valid		),
    .mapping_req_head				(	mapping_req_head		),
    .mapping_req_last				(	mapping_req_last		),
    .mapping_req_data				(	mapping_req_data		),
    .mapping_req_ready 				(	mapping_req_ready 		)
);

SWAccCMCtl_Thread_2 SWAccCMCtl_Thread_2_Inst (
    .clk							(	clk								),
    .rst							(	rst								),

    .qpc_req_valid					(	qpc_req_valid					),
    .qpc_req_head					(	qpc_req_head					),
    .qpc_req_last					(	qpc_req_last					),
    .qpc_req_data					(	qpc_req_data					),
    .qpc_req_ready					(	qpc_req_ready					),

    .icm_get_req_valid			   (	qpc_cache_get_req_valid			),
    .icm_get_req_head				(	qpc_cache_get_req_head			),
    .icm_get_req_ready			   (	qpc_cache_get_req_ready			),

    .icm_get_rsp_valid			   (	qpc_cache_get_rsp_valid			),
    .icm_get_rsp_head				(	qpc_cache_get_rsp_head			),
    .icm_get_rsp_data				(	qpc_cache_get_rsp_data			),
    .icm_get_rsp_ready			   (	qpc_cache_get_rsp_ready			),

    .icm_set_req_valid			   (	qpc_cache_set_req_valid			),
    .icm_set_req_head				(	qpc_cache_set_req_head			),
    .icm_set_req_data				(	qpc_cache_set_req_data			),
    .icm_set_req_ready			   (	qpc_cache_set_req_ready			),

    .icm_mapping_lookup_valid		(	qpc_icm_mapping_lookup_valid	),
    .icm_mapping_lookup_head		(	qpc_icm_mapping_lookup_head		),
    .icm_mapping_lookup_ready		(	qpc_icm_mapping_lookup_ready	),

    .icm_mapping_rsp_valid			(	qpc_icm_mapping_rsp_valid		),
    .icm_mapping_rsp_icm_addr		(	qpc_icm_mapping_rsp_icm_addr	),
    .icm_mapping_rsp_phy_addr		(	qpc_icm_mapping_rsp_phy_addr	),
    .icm_mapping_rsp_ready			(	qpc_icm_mapping_rsp_ready		),

    .qpc_rsp_valid					(	qpc_rsp_valid					),
    .qpc_rsp_head					(	qpc_rsp_head					),
    .qpc_rsp_last					(	qpc_rsp_last					),
    .qpc_rsp_data					(	qpc_rsp_data					),
    .qpc_rsp_ready					(	qpc_rsp_ready					)
);

SWAccCMCtl_Thread_3 SWAccCMCtl_Thread_3_Inst(
    .clk							(	clk								),
    .rst							(	rst								),

    .cqc_req_valid					(	cqc_req_valid					),
    .cqc_req_head					(	cqc_req_head					),
    .cqc_req_last					(	cqc_req_last					),
    .cqc_req_data					(	cqc_req_data					),
    .cqc_req_ready					(	cqc_req_ready					),

    .cache_set_req_valid			(	cqc_cache_set_req_valid			),
    .cache_set_req_head				(	cqc_cache_set_req_head			),
    .cache_set_req_data				(	cqc_cache_set_req_data			),
    .cache_set_req_ready			(	cqc_cache_set_req_ready			),

    .icm_mapping_lookup_valid		(	cqc_icm_mapping_lookup_valid	),
    .icm_mapping_lookup_head		(	cqc_icm_mapping_lookup_head		),
    .icm_mapping_lookup_ready		(	cqc_icm_mapping_lookup_ready	),

    .icm_mapping_rsp_valid			(	cqc_icm_mapping_rsp_valid		),
    .icm_mapping_rsp_icm_addr		(	cqc_icm_mapping_rsp_icm_addr	),
    .icm_mapping_rsp_phy_addr		(	cqc_icm_mapping_rsp_phy_addr	),
    .icm_mapping_rsp_ready			(	cqc_icm_mapping_rsp_ready		)
);

SWAccCMCtl_Thread_4 SWAccCMCtl_Thread_4_Inst (
    .clk							(	clk								),
    .rst							(	rst								),

    .eqc_req_valid					(	eqc_req_valid					),
    .eqc_req_head					(	eqc_req_head					),
    .eqc_req_last					(	eqc_req_last					),
    .eqc_req_data					(	eqc_req_data					),
    .eqc_req_ready					(	eqc_req_ready					),

    .cache_set_req_valid			(	eqc_cache_set_req_valid			),
    .cache_set_req_head				(	eqc_cache_set_req_head			),
    .cache_set_req_data				(	eqc_cache_set_req_data			),
    .cache_set_req_ready			(	eqc_cache_set_req_ready			),

    .icm_mapping_lookup_valid		(	eqc_icm_mapping_lookup_valid	),
    .icm_mapping_lookup_head		(	eqc_icm_mapping_lookup_head		),
    .icm_mapping_lookup_ready		(	eqc_icm_mapping_lookup_ready	),

    .icm_mapping_rsp_valid			(	eqc_icm_mapping_rsp_valid		),
    .icm_mapping_rsp_icm_addr		(	eqc_icm_mapping_rsp_icm_addr	),
    .icm_mapping_rsp_phy_addr		(	eqc_icm_mapping_rsp_phy_addr	),
    .icm_mapping_rsp_ready 			(	eqc_icm_mapping_rsp_ready 		)
);

SWAccCMCtl_Thread_5 
#(
    .ICM_PAGE_NUM            		(	ICM_PAGE_NUM					)
)
SWAccCMCtl_Thread_5_Inst(
    .clk							(	clk								),
    .rst							(	rst								),

    .map_req_valid					(	mapping_req_valid				),
    .map_req_head					(	mapping_req_head				),
    .map_req_last					(	mapping_req_last				),
    .map_req_data					(	mapping_req_data				),
    .map_req_ready					(	mapping_req_ready				),

    .qpc_mapping_set_valid			(	qpc_mapping_set_valid			),
    .qpc_mapping_set_head			(	qpc_mapping_set_head			),
    .qpc_mapping_set_data			(	qpc_mapping_set_data			),

    .cqc_mapping_set_valid			(	cqc_mapping_set_valid			),
    .cqc_mapping_set_head			(	cqc_mapping_set_head			),
    .cqc_mapping_set_data			(	cqc_mapping_set_data			),

    .eqc_mapping_set_valid			(	eqc_mapping_set_valid			),
    .eqc_mapping_set_head			(	eqc_mapping_set_head			),
    .eqc_mapping_set_data 			(	eqc_mapping_set_data 			),

    .qpc_base                       (   qpc_base                        ),
    .cqc_base                       (   cqc_base                        ),
    .eqc_base                       (   eqc_base                        )
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule