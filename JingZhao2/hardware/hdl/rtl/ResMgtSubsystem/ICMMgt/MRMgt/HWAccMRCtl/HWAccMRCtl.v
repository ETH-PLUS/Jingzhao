/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       HWAccMRCtl
Author:     YangFan
Function:   Control Hardware to MRMgt Access.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module HWAccMRCtl
#(
    parameter               ICM_CACHE_TYPE          =       `CACHE_TYPE_MTT,
    parameter               ICM_PAGE_NUM            =       `ICM_PAGE_NUM_MTT,
    parameter               ICM_PAGE_NUM_LOG        =       log2b(ICM_PAGE_NUM - 1),
    parameter               ICM_ENTRY_NUM           =       `ICM_ENTRY_NUM_MTT,
    parameter               ICM_ENTRY_NUM_LOG       =       log2b(ICM_ENTRY_NUM - 1),
    parameter               ICM_SLOT_SIZE           =       `ICM_SLOT_SIZE_MTT,
    parameter               ICM_ADDR_WIDTH          =       64,

    parameter               CACHE_ADDR_WIDTH        =       ICM_ADDR_WIDTH,
    parameter               CACHE_ENTRY_WIDTH       =       256,
    parameter               CACHE_SET_NUM           =       1024,
    parameter               CACHE_SET_NUM_LOG       =       log2b(CACHE_SET_NUM - 1),
    parameter               CACHE_OFFSET_WIDTH      =       log2b(CACHE_ENTRY_WIDTH / 8 - 1),
    parameter               CACHE_TAG_WIDTH         =       CACHE_ADDR_WIDTH - CACHE_OFFSET_WIDTH - CACHE_SET_NUM_LOG,
    parameter               PHYSICAL_ADDR_WIDTH     =       64,
    parameter               COUNT_MAX               =       2,
    parameter               COUNT_MAX_LOG           =       log2b(COUNT_MAX - 1) + 1,
    parameter               REQ_TAG_NUM             =       `REQ_TAG_NUM,
    parameter               REQ_TAG_NUM_LOG         =       log2b(REQ_TAG_NUM - 1),
    parameter               REORDER_BUFFER_WIDTH    =       (ICM_CACHE_TYPE == `CACHE_TYPE_MTT) ? CACHE_ENTRY_WIDTH * 2 + COUNT_MAX_LOG : CACHE_ENTRY_WIDTH + COUNT_MAX_LOG 
)
(
	input 	wire 																								clk,
	input 	wire 																								rst,

	//Interface with SQMgt
    input   wire                                                                                                SQ_mr_req_valid,
    input   wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                               	SQ_mr_req_head,
    input   wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                                                               	SQ_mr_req_data,
    output  wire                                                                                                SQ_mr_req_ready,

    output  wire                                                                                                SQ_mr_rsp_valid,
    output  wire    [`MR_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                               	SQ_mr_rsp_head,
    output  wire    [`MR_RESP_DATA_WIDTH - 1 : 0]                                                               	SQ_mr_rsp_data,
    input  	wire                                                                                                SQ_mr_rsp_ready,

    //INterface with RQMgt
    input   wire                                                                                                RQ_mr_req_valid,
    input   wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                               	RQ_mr_req_head,
    input   wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                                                               	RQ_mr_req_data,
    output  wire                                                                                                RQ_mr_req_ready,

    output  wire                                                                                                RQ_mr_rsp_valid,
    output  wire    [`MR_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                               	RQ_mr_rsp_head,
    output  wire    [`MR_RESP_DATA_WIDTH - 1 : 0]                                                               	RQ_mr_rsp_data,
    input  	wire                                                                                                RQ_mr_rsp_ready,

    //Interface with RDMACore/ReqTransCore
    input   wire                                                                                                TX_REQ_mr_req_valid,
    input   wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                               	TX_REQ_mr_req_head,
    input   wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                                                               	TX_REQ_mr_req_data,
    output  wire                                                                                                TX_REQ_mr_req_ready,

    output  wire                                                                                                TX_REQ_mr_rsp_valid,
    output  wire    [`MR_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                               	TX_REQ_mr_rsp_head,
    output  wire    [`MR_RESP_DATA_WIDTH - 1 : 0]                                                               	TX_REQ_mr_rsp_data,
    input  	wire                                                                                                TX_REQ_mr_rsp_ready,

    //Interface with RDMACore/ReqRecvCore
    input   wire                                                                                                RX_REQ_mr_req_valid,
    input   wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                               	RX_REQ_mr_req_head,
    input   wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                                                               	RX_REQ_mr_req_data,
    output  wire                                                                                                RX_REQ_mr_req_ready,

    output  wire                                                                                                RX_REQ_mr_rsp_valid,
    output  wire    [`MR_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                               	RX_REQ_mr_rsp_head,
    output  wire    [`MR_RESP_DATA_WIDTH - 1 : 0]                                                               	RX_REQ_mr_rsp_data,
    input   wire                                                                                                RX_REQ_mr_rsp_ready,

    //Interface with RDMACore/RespRecvCore
	input   wire                                                                                                RX_RESP_mr_req_valid,
    input   wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                               	RX_RESP_mr_req_head,
    input   wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                                                               	RX_RESP_mr_req_data,
    output  wire                                                                                                RX_RESP_mr_req_ready,

    output  wire                                                                                                RX_RESP_mr_rsp_valid,
    output  wire    [`MR_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                               	RX_RESP_mr_rsp_head,
    output  wire    [`MR_RESP_DATA_WIDTH - 1 : 0]                                                               	RX_RESP_mr_rsp_data,
    input  	wire                                                                                                RX_RESP_mr_rsp_ready,

//MPT Mapping Lookup Interface
    output  wire                                                                                                mpt_icm_mapping_lookup_valid,
    output  wire    [log2b(`ICM_ENTRY_NUM_MPT - 1) - 1 : 0]                                                                 mpt_icm_mapping_lookup_head,
    input   wire                                                                                                mpt_icm_mapping_lookup_ready,

    input   wire                                                                                                mpt_icm_mapping_rsp_valid,
    input   wire    [ICM_ADDR_WIDTH - 1 : 0]                                                                    mpt_icm_mapping_rsp_icm_addr,
    input   wire    [PHYSICAL_ADDR_WIDTH - 1 : 0]                                                               mpt_icm_mapping_rsp_phy_addr,
    output  wire                                                                                                mpt_icm_mapping_rsp_ready,

//ICM Get Interface
    output  wire                                                                                                mpt_icm_get_req_valid,
    output  wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   mpt_icm_get_req_head,
    input   wire                                                                                                mpt_icm_get_req_ready,

    input   wire                                                                                                mpt_icm_get_rsp_valid,
    input   wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   mpt_icm_get_rsp_head,
    input   wire    [`CACHE_ENTRY_WIDTH_MPT - 1 : 0]                                                            mpt_icm_get_rsp_data,
    output  wire                                                                                                mpt_icm_get_rsp_ready,

//MPT Mapping Lookup Interface
    output  wire                                                                                                mtt_icm_mapping_lookup_valid,
    output  wire    [log2b(`ICM_ENTRY_NUM_MTT - 1) - 1 : 0]                                                                 mtt_icm_mapping_lookup_head,
    input   wire                                                                                                mtt_icm_mapping_lookup_ready,

    input   wire                                                                                                mtt_icm_mapping_rsp_valid,
    input   wire    [ICM_ADDR_WIDTH - 1 : 0]                                                                    mtt_icm_mapping_rsp_icm_addr,
    input   wire    [PHYSICAL_ADDR_WIDTH - 1 : 0]                                                               mtt_icm_mapping_rsp_phy_addr,
    output  wire                                                                                                mtt_icm_mapping_rsp_ready,

//ICM/MPT Get Interface
    output  wire                                                                                                mtt_icm_get_req_valid,
    output  wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   mtt_icm_get_req_head,
    input   wire                                                                                                mtt_icm_get_req_ready,

    input   wire                                                                                                mtt_icm_get_rsp_valid,
    input   wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   mtt_icm_get_rsp_head,
    input   wire    [`CACHE_ENTRY_WIDTH_MTT - 1 : 0]                                                            mtt_icm_get_rsp_data,
    output  wire                                                                                                mtt_icm_get_rsp_ready
);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire 																								tag_qpn_mapping_table_wea;
wire 	[`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                              tag_qpn_mapping_table_addra;
wire 	[`QP_NUM_LOG - 1 : 0]                                                                       tag_qpn_mapping_table_dina;
wire 	[`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                              tag_qpn_mapping_table_addrb;
wire 	[`QP_NUM_LOG - 1 : 0]                                                                       tag_qpn_mapping_table_doutb;

wire 			                        															mr_req_buffer_wea;
wire    [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                              mr_req_buffer_addra;
wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                         mr_req_buffer_dina;
wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                         mr_req_buffer_douta;

wire                                                                                                mr_req_buffer_web;
wire    [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                              mr_req_buffer_addrb;
wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                         mr_req_buffer_dinb;
wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                         mr_req_buffer_doutb;

wire                                                                                                page_offset_buffer_wea;
wire    [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                              page_offset_buffer_addra;
wire    [32 + 12 - 1 : 0]                                                                           page_offset_buffer_dina;
wire    [32 + 12 - 1 : 0]                                                                           page_offset_buffer_douta;

wire                                                                                                page_offset_buffer_web;
wire    [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                              page_offset_buffer_addrb;
wire    [32 + 12 - 1 : 0]                                                                           page_offset_buffer_dinb;
wire    [32 + 12 - 1 : 0]                                                                           page_offset_buffer_doutb;

wire                                                                                                mr_req_valid;
wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                         mr_req_head;
wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                                                                mr_req_data;
wire                                                                                                mr_req_ready;

wire                                                                                                mr_rsp_valid;
wire    [`MR_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                        mr_rsp_head;
wire    [`MR_RESP_DATA_WIDTH - 1 : 0]                                                               mr_rsp_data;
wire                                                                                                mr_rsp_ready;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
HWAccMRCtl_Thread_1
#(
    .ICM_CACHE_TYPE          (			ICM_CACHE_TYPE          		),
    .ICM_PAGE_NUM            (			ICM_PAGE_NUM            		),
    .ICM_PAGE_NUM_LOG        (			ICM_PAGE_NUM_LOG        		),
    .ICM_ENTRY_NUM           (			ICM_ENTRY_NUM           		),
    .ICM_ENTRY_NUM_LOG       (			ICM_ENTRY_NUM_LOG       		),
    .ICM_SLOT_SIZE           (			ICM_SLOT_SIZE           		),
    .ICM_ADDR_WIDTH          (			ICM_ADDR_WIDTH          		),

    .CACHE_ADDR_WIDTH        (			CACHE_ADDR_WIDTH        		),
    .CACHE_ENTRY_WIDTH       (			CACHE_ENTRY_WIDTH       		),
    .CACHE_SET_NUM           (			CACHE_SET_NUM           		),
    .CACHE_SET_NUM_LOG       (			CACHE_SET_NUM_LOG       		),
    .CACHE_OFFSET_WIDTH      (			CACHE_OFFSET_WIDTH      		),
    .CACHE_TAG_WIDTH         (			CACHE_TAG_WIDTH         		),
    .PHYSICAL_ADDR_WIDTH     (			PHYSICAL_ADDR_WIDTH     		),
    .COUNT_MAX               (			COUNT_MAX               		),
    .COUNT_MAX_LOG           (			COUNT_MAX_LOG           		),
    .REQ_TAG_NUM             (			REQ_TAG_NUM             		),
    .REQ_TAG_NUM_LOG         (			REQ_TAG_NUM_LOG         		),
    .REORDER_BUFFER_WIDTH    (			REORDER_BUFFER_WIDTH    		)
)
HWAccMRCtl_Thread_1_Inst
(
	.clk							(		clk								),
	.rst							(		rst								),

    .SQ_mr_req_valid		(		SQ_mr_req_valid			),
    .SQ_mr_req_head			(		SQ_mr_req_head			),
    .SQ_mr_req_data			(		SQ_mr_req_data			),
    .SQ_mr_req_ready		(		SQ_mr_req_ready			),

   
    .RQ_mr_req_valid		(		RQ_mr_req_valid			),
    .RQ_mr_req_head			(		RQ_mr_req_head			),
    .RQ_mr_req_data			(		RQ_mr_req_data			),
    .RQ_mr_req_ready		(		RQ_mr_req_ready			),

   
    .TX_REQ_mr_req_valid		(		TX_REQ_mr_req_valid			),
    .TX_REQ_mr_req_head			(		TX_REQ_mr_req_head			),
    .TX_REQ_mr_req_data			(		TX_REQ_mr_req_data			),
    .TX_REQ_mr_req_ready		(		TX_REQ_mr_req_ready			),

   
    .RX_REQ_mr_req_valid		(		RX_REQ_mr_req_valid			),
    .RX_REQ_mr_req_head			(		RX_REQ_mr_req_head			),
    .RX_REQ_mr_req_data			(		RX_REQ_mr_req_data			),
    .RX_REQ_mr_req_ready		(		RX_REQ_mr_req_ready			),

   
	.RX_RESP_mr_req_valid		(		RX_RESP_mr_req_valid			),
    .RX_RESP_mr_req_head			(		RX_RESP_mr_req_head			),
    .RX_RESP_mr_req_data			(		RX_RESP_mr_req_data			),
    .RX_RESP_mr_req_ready		(		RX_RESP_mr_req_ready			),

    .mr_req_valid				(		mr_req_valid				),
    .mr_req_head				(		mr_req_head					),
    .mr_req_data				(		mr_req_data					),
    .mr_req_ready				(		mr_req_ready				),

    .tag_qpn_mapping_table_wen		(		tag_qpn_mapping_table_wea		),
    .tag_qpn_mapping_table_addr	(		tag_qpn_mapping_table_addra	),
    .tag_qpn_mapping_table_din  	(		tag_qpn_mapping_table_dina  	)
);

HWAccMRCtl_Thread_2
#(
    .ICM_CACHE_TYPE          (			ICM_CACHE_TYPE          		),
    .ICM_PAGE_NUM            (			ICM_PAGE_NUM            		),
    .ICM_PAGE_NUM_LOG        (			ICM_PAGE_NUM_LOG        		),
    .ICM_ENTRY_NUM           (			`ICM_ENTRY_NUM_MPT           		),

    .ICM_SLOT_SIZE           (			ICM_SLOT_SIZE           		),
    .ICM_ADDR_WIDTH          (			ICM_ADDR_WIDTH          		),

    .CACHE_ADDR_WIDTH        (			CACHE_ADDR_WIDTH        		),
    .CACHE_ENTRY_WIDTH       (			`CACHE_ENTRY_WIDTH_MPT       		),
    .CACHE_SET_NUM           (			CACHE_SET_NUM           		),
    .CACHE_SET_NUM_LOG       (			CACHE_SET_NUM_LOG       		),
    .CACHE_OFFSET_WIDTH      (			CACHE_OFFSET_WIDTH      		),
    .CACHE_TAG_WIDTH         (			CACHE_TAG_WIDTH         		),
    .PHYSICAL_ADDR_WIDTH     (			PHYSICAL_ADDR_WIDTH     		),
    .COUNT_MAX               (			COUNT_MAX               		),
    .COUNT_MAX_LOG           (			COUNT_MAX_LOG           		),
    .REQ_TAG_NUM             (			REQ_TAG_NUM             		),
    .REQ_TAG_NUM_LOG         (			REQ_TAG_NUM_LOG         		),
    .REORDER_BUFFER_WIDTH    (			REORDER_BUFFER_WIDTH    		)
)
HWAccMRCtl_Thread_2_Inst
(
    .clk							(		clk								),
    .rst							(		rst								),

    .mr_req_valid				(		mr_req_valid				),
    .mr_req_head				(		mr_req_head					),
    .mr_req_data				(		mr_req_data					),
    .mr_req_ready				(		mr_req_ready				),

    .icm_mapping_lookup_valid		(		mpt_icm_mapping_lookup_valid	),
    .icm_mapping_lookup_head		(		mpt_icm_mapping_lookup_head		),
    .icm_mapping_lookup_ready		(		mpt_icm_mapping_lookup_ready	),

    .icm_mapping_rsp_valid			(		mpt_icm_mapping_rsp_valid		),
    .icm_mapping_rsp_icm_addr		(		mpt_icm_mapping_rsp_icm_addr	),
    .icm_mapping_rsp_phy_addr		(		mpt_icm_mapping_rsp_phy_addr	),
    .icm_mapping_rsp_ready          (       mpt_icm_mapping_rsp_ready       ),

    .icm_get_req_valid				(		mpt_icm_get_req_valid			),
    .icm_get_req_head				(		mpt_icm_get_req_head			),
    .icm_get_req_ready				(		mpt_icm_get_req_ready			),

	.mr_req_buffer_wen				(		mr_req_buffer_wea				),
    .mr_req_buffer_addr				(		mr_req_buffer_addra				),
    .mr_req_buffer_din				(		mr_req_buffer_dina				),
    .mr_req_buffer_dout             (       mr_req_buffer_douta             )
);

HWAccMRCtl_Thread_3
#(
    .ICM_CACHE_TYPE          (			ICM_CACHE_TYPE          		),
    .ICM_PAGE_NUM            (			ICM_PAGE_NUM            		),
    .ICM_PAGE_NUM_LOG        (			ICM_PAGE_NUM_LOG        		),
    .ICM_ENTRY_NUM           (			`ICM_ENTRY_NUM_MTT           	),
    .ICM_ENTRY_NUM_LOG       (			ICM_ENTRY_NUM_LOG       		),
    .ICM_SLOT_SIZE           (			ICM_SLOT_SIZE           		),
    .ICM_ADDR_WIDTH          (			ICM_ADDR_WIDTH          		),

    .CACHE_ADDR_WIDTH        (			CACHE_ADDR_WIDTH        		),
    .CACHE_ENTRY_WIDTH       (			`CACHE_ENTRY_WIDTH_MPT       	),
    .CACHE_SET_NUM           (			CACHE_SET_NUM           		),
    .CACHE_SET_NUM_LOG       (			CACHE_SET_NUM_LOG       		),
    .CACHE_OFFSET_WIDTH      (			CACHE_OFFSET_WIDTH      		),
    .CACHE_TAG_WIDTH         (			CACHE_TAG_WIDTH         		),
    .PHYSICAL_ADDR_WIDTH     (			PHYSICAL_ADDR_WIDTH     		),
    .COUNT_MAX               (			COUNT_MAX               		),
    .COUNT_MAX_LOG           (			COUNT_MAX_LOG           		),
    .REQ_TAG_NUM             (			REQ_TAG_NUM             		),
    .REQ_TAG_NUM_LOG         (			REQ_TAG_NUM_LOG         		),
    .REORDER_BUFFER_WIDTH    (			REORDER_BUFFER_WIDTH    		) 
)
HWAccMRCtl_Thread_3_Inst
(
    .clk							(		clk								),
    .rst							(		rst 							),

    .mpt_get_rsp_valid				(		mpt_icm_get_rsp_valid 			),
    .mpt_get_rsp_head				(		mpt_icm_get_rsp_head			),
    .mpt_get_rsp_data				(		mpt_icm_get_rsp_data			),
    .mpt_get_rsp_ready				(		mpt_icm_get_rsp_ready			),

    .icm_mapping_lookup_valid		(		mtt_icm_mapping_lookup_valid	),
    .icm_mapping_lookup_head		(		mtt_icm_mapping_lookup_head		),
    .icm_mapping_lookup_ready		(		mtt_icm_mapping_lookup_ready 	),

    .icm_mapping_rsp_valid			(		mtt_icm_mapping_rsp_valid		),
    .icm_mapping_rsp_icm_addr		(		mtt_icm_mapping_rsp_icm_addr 	),
    .icm_mapping_rsp_phy_addr		(		mtt_icm_mapping_rsp_phy_addr	),
    .icm_mapping_rsp_ready          (       mtt_icm_mapping_rsp_ready       ),

    .mtt_get_req_valid				(		mtt_icm_get_req_valid			),
    .mtt_get_req_head				(		mtt_icm_get_req_head 			),
    .mtt_get_req_ready				(		mtt_icm_get_req_ready 			),

    .mr_req_buffer_wen              (       mr_req_buffer_web               ),
    .mr_req_buffer_addr             (       mr_req_buffer_addrb             ),
    .mr_req_buffer_din              (       mr_req_buffer_dinb              ),
    .mr_req_buffer_dout             (       mr_req_buffer_doutb             ),

    .page_offset_buffer_wen         (       page_offset_buffer_wea          ),
    .page_offset_buffer_addr        (       page_offset_buffer_addra        ),
    .page_offset_buffer_din         (       page_offset_buffer_dina         ),
    .page_offset_buffer_dout        (       page_offset_buffer_douta        )
);

HWAccMRCtl_Thread_4
#(
     .ICM_CACHE_TYPE         (			ICM_CACHE_TYPE          		),
    .ICM_PAGE_NUM            (			ICM_PAGE_NUM            		),
    .ICM_PAGE_NUM_LOG        (			ICM_PAGE_NUM_LOG        		),
    .ICM_ENTRY_NUM           (			ICM_ENTRY_NUM           		),
    .ICM_ENTRY_NUM_LOG       (			ICM_ENTRY_NUM_LOG       		),
    .ICM_SLOT_SIZE           (			ICM_SLOT_SIZE           		),
    .ICM_ADDR_WIDTH          (			ICM_ADDR_WIDTH          		),

    .CACHE_ADDR_WIDTH        (			CACHE_ADDR_WIDTH        		),
    .CACHE_ENTRY_WIDTH       (			`CACHE_ENTRY_WIDTH_MTT       	),
    .CACHE_SET_NUM           (			CACHE_SET_NUM           		),
    .CACHE_SET_NUM_LOG       (			CACHE_SET_NUM_LOG       		),
    .CACHE_OFFSET_WIDTH      (			CACHE_OFFSET_WIDTH      		),
    .CACHE_TAG_WIDTH         (			CACHE_TAG_WIDTH         		),
    .PHYSICAL_ADDR_WIDTH     (			PHYSICAL_ADDR_WIDTH     		),
    .COUNT_MAX               (			COUNT_MAX               		),
    .COUNT_MAX_LOG           (			COUNT_MAX_LOG           		),
    .REQ_TAG_NUM             (			REQ_TAG_NUM             		),
    .REQ_TAG_NUM_LOG         (			REQ_TAG_NUM_LOG         		),
    .REORDER_BUFFER_WIDTH    (			REORDER_BUFFER_WIDTH    		) 
)
HWAccMRCtl_Thread_4_Inst
(
    .clk							(		clk							),
    .rst							(		rst							),

    .mtt_get_rsp_valid				(		mtt_icm_get_rsp_valid		),
    .mtt_get_rsp_head				(		mtt_icm_get_rsp_head		),
    .mtt_get_rsp_data				(		mtt_icm_get_rsp_data		),
    .mtt_get_rsp_ready				(		mtt_icm_get_rsp_ready		),

    .mr_rsp_valid				(		mr_rsp_valid			),
    .mr_rsp_head				(		mr_rsp_head				),
    .mr_rsp_data				(		mr_rsp_data				),
    .mr_rsp_ready				(		mr_rsp_ready			),

    .page_offset_buffer_wen         (       page_offset_buffer_web          ),
    .page_offset_buffer_addr        (       page_offset_buffer_addrb        ),
    .page_offset_buffer_din         (       page_offset_buffer_dinb         ),
    .page_offset_buffer_dout        (       page_offset_buffer_doutb        )
);

HWAccMRCtl_Thread_5
#(
     .ICM_CACHE_TYPE         (			ICM_CACHE_TYPE          		),
    .ICM_PAGE_NUM            (			ICM_PAGE_NUM            		),
    .ICM_PAGE_NUM_LOG        (			ICM_PAGE_NUM_LOG        		),
    .ICM_ENTRY_NUM           (			ICM_ENTRY_NUM           		),
    .ICM_ENTRY_NUM_LOG       (			ICM_ENTRY_NUM_LOG       		),
    .ICM_SLOT_SIZE           (			ICM_SLOT_SIZE           		),
    .ICM_ADDR_WIDTH          (			ICM_ADDR_WIDTH          		),

    .CACHE_ADDR_WIDTH        (			CACHE_ADDR_WIDTH        		),
    .CACHE_ENTRY_WIDTH       (			CACHE_ENTRY_WIDTH       		),
    .CACHE_SET_NUM           (			CACHE_SET_NUM           		),
    .CACHE_SET_NUM_LOG       (			CACHE_SET_NUM_LOG       		),
    .CACHE_OFFSET_WIDTH      (			CACHE_OFFSET_WIDTH      		),
    .CACHE_TAG_WIDTH         (			CACHE_TAG_WIDTH         		),
    .PHYSICAL_ADDR_WIDTH     (			PHYSICAL_ADDR_WIDTH     		),
    .COUNT_MAX               (			COUNT_MAX               		),
    .COUNT_MAX_LOG           (			COUNT_MAX_LOG           		),
    .REQ_TAG_NUM             (			REQ_TAG_NUM             		),
    .REQ_TAG_NUM_LOG         (			REQ_TAG_NUM_LOG         		),
    .REORDER_BUFFER_WIDTH    (			REORDER_BUFFER_WIDTH    		) 
)
HWAccMRCtl_Thread_5_Inst
(
    .clk							(		clk		),
    .rst							(		rst		),

    .mr_rsp_valid				(		mr_rsp_valid				),
    .mr_rsp_head				(		mr_rsp_head					),
    .mr_rsp_data				(		mr_rsp_data					),
    .mr_rsp_ready				(		mr_rsp_ready				),

    .tag_qpn_mapping_table_addr	(		tag_qpn_mapping_table_addrb	),
    .tag_qpn_mapping_table_dout	(		tag_qpn_mapping_table_doutb	),

    .SQ_mr_rsp_valid		(		SQ_mr_rsp_valid			),
    .SQ_mr_rsp_head			(		SQ_mr_rsp_head			),
    .SQ_mr_rsp_data			(		SQ_mr_rsp_data			),
    .SQ_mr_rsp_ready		(		SQ_mr_rsp_ready			),

    .RQ_mr_rsp_valid		(		RQ_mr_rsp_valid			),
    .RQ_mr_rsp_head			(		RQ_mr_rsp_head			),
    .RQ_mr_rsp_data			(		RQ_mr_rsp_data			),
    .RQ_mr_rsp_ready		(		RQ_mr_rsp_ready			),

    .TX_REQ_mr_rsp_valid		(		TX_REQ_mr_rsp_valid			),
    .TX_REQ_mr_rsp_head			(		TX_REQ_mr_rsp_head			),
    .TX_REQ_mr_rsp_data			(		TX_REQ_mr_rsp_data			),
    .TX_REQ_mr_rsp_ready		(		TX_REQ_mr_rsp_ready			),

    .RX_REQ_mr_rsp_valid		(		RX_REQ_mr_rsp_valid			),
    .RX_REQ_mr_rsp_head			(		RX_REQ_mr_rsp_head			),
    .RX_REQ_mr_rsp_data			(		RX_REQ_mr_rsp_data			),
    .RX_REQ_mr_rsp_ready		(		RX_REQ_mr_rsp_ready			),

    .RX_RESP_mr_rsp_valid		(		RX_RESP_mr_rsp_valid		),
    .RX_RESP_mr_rsp_head		(		RX_RESP_mr_rsp_head			),
    .RX_RESP_mr_rsp_data		(		RX_RESP_mr_rsp_data			),
    .RX_RESP_mr_rsp_ready		(		RX_RESP_mr_rsp_ready		)
);

SRAM_SDP_Template #(
    .RAM_WIDTH      (   `QP_NUM_LOG                 ),
    .RAM_DEPTH      (   32                          )
)
ChannelQPNMappingTable_Inst
(
    .clk            (   	clk                                 ),
    .rst            (   	rst                                 ),

    .wea            (   	tag_qpn_mapping_table_wea			),
    .addra          (   	tag_qpn_mapping_table_addra		),
    .dina           (   	tag_qpn_mapping_table_dina			),

    .addrb          (   	tag_qpn_mapping_table_addrb		),
    .doutb          (   	tag_qpn_mapping_table_doutb		)
);

SRAM_TDP_Template #(
    .RAM_WIDTH      (   192                         	),
    .RAM_DEPTH      (   32                          )
)
MRReqStagedBuffer
(
    .clk            (   	clk                                 ),
    .rst            (   	rst                                 ),

    .wea            (   	mr_req_buffer_wea					),
    .addra          (   	mr_req_buffer_addra					),
    .dina           (   	mr_req_buffer_dina					),
    .douta          (       mr_req_buffer_douta                 ),

    .web            (       mr_req_buffer_web                   ),
    .addrb          (       mr_req_buffer_addrb                 ),
    .dinb           (       mr_req_buffer_dinb                  ),
    .doutb          (       mr_req_buffer_doutb                 )
);

SRAM_TDP_Template #(
    .RAM_WIDTH      (   32 + 12                             ),      //Size + Page offset
    .RAM_DEPTH      (   32                          )
)
PageOffsetStagedBuffer
(
    .clk            (       clk                                 ),
    .rst            (       rst                                 ),

    .wea            (       page_offset_buffer_wea              ),
    .addra          (       page_offset_buffer_addra            ),
    .dina           (       page_offset_buffer_dina             ),
    .douta          (       page_offset_buffer_douta            ),

    .web            (       page_offset_buffer_web              ),
    .addrb          (       page_offset_buffer_addrb            ),
    .dinb           (       page_offset_buffer_dinb             ),
    .doutb          (       page_offset_buffer_doutb            )
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule