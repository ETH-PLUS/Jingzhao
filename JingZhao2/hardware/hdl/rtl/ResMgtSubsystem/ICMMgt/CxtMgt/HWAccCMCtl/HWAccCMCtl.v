/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       HWAccCMCtl
Author:     YangFan
Function:   Control Hardware to CxtMgt Access.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module HWAccCMCtl
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
    input   wire                                                                                                clk,
    input   wire                                                                                                rst,

//Request channels
    input   wire                                                                                                SQ_cxt_req_valid,
    input   wire    [`CXT_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                        SQ_cxt_req_head,
    input   wire    [`CXT_CMD_DATA_WIDTH - 1 : 0]                                                               SQ_cxt_req_data,
    output  wire                                                                                                SQ_cxt_req_ready,

    input   wire                                                                                                TX_REQ_cxt_req_valid,
    input   wire    [`CXT_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                        TX_REQ_cxt_req_head,
    input   wire    [`CXT_CMD_DATA_WIDTH - 1 : 0]                                                               TX_REQ_cxt_req_data,
    output  wire                                                                                                TX_REQ_cxt_req_ready,

    input   wire                                                                                                RX_REQ_cxt_req_valid,
    input   wire    [`CXT_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                        RX_REQ_cxt_req_head,
    input   wire    [`CXT_CMD_DATA_WIDTH - 1 : 0]                                                               RX_REQ_cxt_req_data,
    output  wire                                                                                                RX_REQ_cxt_req_ready,

    input   wire                                                                                                RX_RESP_cxt_req_valid,
    input   wire    [`CXT_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                        RX_RESP_cxt_req_head,
    input   wire    [`CXT_CMD_DATA_WIDTH - 1 : 0]                                                               RX_RESP_cxt_req_data,
    output  wire                                                                                                RX_RESP_cxt_req_ready,

//Response channels
    output  wire                                                                                                SQ_cxt_rsp_valid,
    output  wire    [`CXT_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                       SQ_cxt_rsp_head,
    output  wire    [`CXT_RESP_DATA_WIDTH - 1 : 0]                                                              SQ_cxt_rsp_data,
    input   wire                                                                                                SQ_cxt_rsp_ready,

    output  wire                                                                                                TX_REQ_cxt_rsp_valid,
    output  wire    [`CXT_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                       TX_REQ_cxt_rsp_head,
    output  wire    [`CXT_RESP_DATA_WIDTH - 1 : 0]                                                              TX_REQ_cxt_rsp_data,
    input   wire                                                                                                TX_REQ_cxt_rsp_ready,

    output  wire                                                                                                RX_REQ_cxt_rsp_valid,
    output  wire    [`CXT_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                       RX_REQ_cxt_rsp_head,
    output  wire    [`CXT_RESP_DATA_WIDTH - 1 : 0]                                                              RX_REQ_cxt_rsp_data,
    input   wire                                                                                                RX_REQ_cxt_rsp_ready,

    output  wire                                                                                                RX_RESP_cxt_rsp_valid,
    output  wire    [`CXT_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                       RX_RESP_cxt_rsp_head,
    output  wire    [`CXT_RESP_DATA_WIDTH - 1 : 0]                                                              RX_RESP_cxt_rsp_data,
    input   wire                                                                                                RX_RESP_cxt_rsp_ready,

//Interface with QPCCache
    output  wire                                                                                                qpc_icm_mapping_lookup_valid,
    output  wire    [log2b(`ICM_ENTRY_NUM_QPC - 1) - 1 : 0]                                                     qpc_icm_mapping_lookup_head,
    input   wire                                                                                                qpc_icm_mapping_lookup_ready,

    input   wire                                                                                                qpc_icm_mapping_rsp_valid,
    input   wire    [ICM_ADDR_WIDTH - 1 : 0]                                                                    qpc_icm_mapping_rsp_icm_addr,
    input   wire    [PHYSICAL_ADDR_WIDTH - 1 : 0]                                                               qpc_icm_mapping_rsp_phy_addr,
    output  wire                                                                                                qpc_icm_mapping_rsp_ready,

    output  wire                                                                                                qpc_get_req_valid,
    output  wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   qpc_get_req_head,
    input   wire                                                                                                qpc_get_req_ready,

    input   wire                                                                                                qpc_get_rsp_valid,
    input   wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   qpc_get_rsp_head,
    input   wire    [`CACHE_ENTRY_WIDTH_QPC - 1 : 0]                                                            qpc_get_rsp_data,
    output  wire                                                                                                qpc_get_rsp_ready,

//Interface with CQCCache
	output  wire                                                                                                cqc_icm_mapping_lookup_valid,
    output  wire    [log2b(`ICM_ENTRY_NUM_CQC - 1) - 1 : 0]                                                     cqc_icm_mapping_lookup_head,
    input   wire                                                                                                cqc_icm_mapping_lookup_ready,

    input   wire                                                                                                cqc_icm_mapping_rsp_valid,
    input   wire    [ICM_ADDR_WIDTH - 1 : 0]                                                                    cqc_icm_mapping_rsp_icm_addr,
    input   wire    [PHYSICAL_ADDR_WIDTH - 1 : 0]                                                               cqc_icm_mapping_rsp_phy_addr,
    output  wire                                                                                                cqc_icm_mapping_rsp_ready,

    output  wire                                                                                                cqc_get_req_valid,
    output  wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   cqc_get_req_head,
    input   wire                                                                                                cqc_get_req_ready,

    input   wire                                                                                                cqc_get_rsp_valid,
    input   wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   cqc_get_rsp_head,
    input   wire    [`CACHE_ENTRY_WIDTH_CQC - 1 : 0]                                                            cqc_get_rsp_data,
    output  wire                                                                                                cqc_get_rsp_ready,

//Interface with EQCCache
    output  wire                                                                                                eqc_icm_mapping_lookup_valid,
    output  wire    [log2b(`ICM_ENTRY_NUM_EQC - 1) - 1 : 0]                                                     eqc_icm_mapping_lookup_head,
    input   wire                                                                                                eqc_icm_mapping_lookup_ready,

    input   wire                                                                                                eqc_icm_mapping_rsp_valid,
    input   wire    [ICM_ADDR_WIDTH - 1 : 0]                                                                    eqc_icm_mapping_rsp_icm_addr,
    input   wire    [PHYSICAL_ADDR_WIDTH - 1 : 0]                                                               eqc_icm_mapping_rsp_phy_addr,
    output  wire                                                                                                eqc_icm_mapping_rsp_ready,

    output  wire                                                                                                eqc_get_req_valid,
    output  wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   eqc_get_req_head,
    input   wire                                                                                                eqc_get_req_ready,

    input   wire                                                                                                eqc_get_rsp_valid,
    input   wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   eqc_get_rsp_head,
    input   wire    [`CACHE_ENTRY_WIDTH_EQC - 1 : 0]                                                            eqc_get_rsp_data,
    output  wire                                                                                                eqc_get_rsp_ready
);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                                                                                cxt_req_valid;
wire    [`CXT_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                        cxt_req_head;
wire    [`CXT_CMD_DATA_WIDTH - 1 : 0]                                                               cxt_req_data;
wire                                                                                                cxt_req_ready;

wire                                                                                                cxt_combine_valid;
wire    [`CXT_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                       cxt_combine_head;
wire    [`CXT_RESP_DATA_WIDTH - 1 : 0]                                                              cxt_combine_data;
wire                                                                                                cxt_combine_ready;

wire 																								qpc_staged_buffer_wea;
wire 	[`MAX_REQ_TAG_NUM_LOG - 1 : 0]																qpc_staged_buffer_addra;
wire 	[`CACHE_ENTRY_WIDTH_QPC - 1 : 0]															qpc_staged_buffer_dina;
wire 	[`MAX_REQ_TAG_NUM_LOG - 1 : 0]																qpc_staged_buffer_addrb;
wire    [`CACHE_ENTRY_WIDTH_QPC - 1 : 0]                                                            qpc_staged_buffer_doutb;

wire 																								cqc_staged_buffer_wea;
wire 	[`MAX_REQ_TAG_NUM_LOG - 1 : 0]																cqc_staged_buffer_addra;
wire    [`CACHE_ENTRY_WIDTH_CQC - 1 : 0]                                                            cqc_staged_buffer_dina;
wire 	[`MAX_REQ_TAG_NUM_LOG - 1 : 0]																cqc_staged_buffer_addrb;
wire    [`CACHE_ENTRY_WIDTH_CQC - 1 : 0]                                                            cqc_staged_buffer_doutb;

wire 																								tag_qpn_mapping_table_wea;
wire 	[`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                              tag_qpn_mapping_table_addra;
wire 	[`QP_NUM_LOG - 1 : 0]                                                                       tag_qpn_mapping_table_dina;
wire 	[`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                              tag_qpn_mapping_table_addrb;
wire 	[`QP_NUM_LOG - 1 : 0]                                                                       tag_qpn_mapping_table_doutb;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
HWAccCMCtl_Thread_1
#(
    .ICM_CACHE_TYPE          		(		ICM_CACHE_TYPE          	),
    .ICM_PAGE_NUM            		(		ICM_PAGE_NUM            	),
    
    .ICM_ENTRY_NUM           		(		ICM_ENTRY_NUM           	),
    
    .ICM_SLOT_SIZE           		(		ICM_SLOT_SIZE           	),
    .ICM_ADDR_WIDTH          		(		ICM_ADDR_WIDTH          	),

    .CACHE_ADDR_WIDTH        		(		CACHE_ADDR_WIDTH        	),
    .CACHE_ENTRY_WIDTH       		(		CACHE_ENTRY_WIDTH       	),
    .CACHE_SET_NUM           		(		CACHE_SET_NUM           	),
    
    .CACHE_OFFSET_WIDTH      		(		CACHE_OFFSET_WIDTH      	),
    .CACHE_TAG_WIDTH         		(		CACHE_TAG_WIDTH         	),
    .PHYSICAL_ADDR_WIDTH     		(		PHYSICAL_ADDR_WIDTH     	),
    .COUNT_MAX               		(		COUNT_MAX               	),
    
    .REQ_TAG_NUM             		(		REQ_TAG_NUM             	),

    .REORDER_BUFFER_WIDTH    		(		REORDER_BUFFER_WIDTH    	)
)
HWAccCMCtl_Thread_1_Inst
(
    .clk							(		clk 							),
    .rst							(		rst 							),

    .SQ_cxt_req_valid		(		SQ_cxt_req_valid		),
    .SQ_cxt_req_head		(		SQ_cxt_req_head			),
    .SQ_cxt_req_data		(		SQ_cxt_req_data			),
    .SQ_cxt_req_ready		(		SQ_cxt_req_ready		),

    .TX_REQ_cxt_req_valid		(		TX_REQ_cxt_req_valid		),
    .TX_REQ_cxt_req_head		(		TX_REQ_cxt_req_head			),
    .TX_REQ_cxt_req_data		(		TX_REQ_cxt_req_data			),
    .TX_REQ_cxt_req_ready		(		TX_REQ_cxt_req_ready		),

    .RX_REQ_cxt_req_valid		(		RX_REQ_cxt_req_valid		),
    .RX_REQ_cxt_req_head		(		RX_REQ_cxt_req_head			),
    .RX_REQ_cxt_req_data		(		RX_REQ_cxt_req_data			),
    .RX_REQ_cxt_req_ready		(		RX_REQ_cxt_req_ready		),

    .RX_RESP_cxt_req_valid		(		RX_RESP_cxt_req_valid		),
    .RX_RESP_cxt_req_head		(		RX_RESP_cxt_req_head			),
    .RX_RESP_cxt_req_data		(		RX_RESP_cxt_req_data			),
    .RX_RESP_cxt_req_ready		(		RX_RESP_cxt_req_ready		),

    .cxt_req_valid				(		cxt_req_valid				),
    .cxt_req_head				(		cxt_req_head				),
    .cxt_req_data				(		cxt_req_data				),
    .cxt_req_ready				(		cxt_req_ready				),

    .tag_qpn_mapping_table_wen		(		tag_qpn_mapping_table_wea		),
    .tag_qpn_mapping_table_addr	    (		tag_qpn_mapping_table_addra	),
    .tag_qpn_mapping_table_din		(		tag_qpn_mapping_table_dina		)
);

HWAccCMCtl_Thread_2
#(
    .ICM_CACHE_TYPE          		(		ICM_CACHE_TYPE          	),
    .ICM_PAGE_NUM            		(		ICM_PAGE_NUM            	),
    
    .ICM_ENTRY_NUM           		(		`ICM_ENTRY_NUM_QPC           	),
    
    .ICM_SLOT_SIZE           		(		ICM_SLOT_SIZE           	),
    .ICM_ADDR_WIDTH          		(		ICM_ADDR_WIDTH          	),

    .CACHE_ADDR_WIDTH        		(		CACHE_ADDR_WIDTH        	),
    .CACHE_ENTRY_WIDTH       		(		CACHE_ENTRY_WIDTH       	),
    .CACHE_SET_NUM           		(		CACHE_SET_NUM           	),
    
    .CACHE_OFFSET_WIDTH      		(		CACHE_OFFSET_WIDTH      	),
    .CACHE_TAG_WIDTH         		(		CACHE_TAG_WIDTH         	),
    .PHYSICAL_ADDR_WIDTH     		(		PHYSICAL_ADDR_WIDTH     	),
    .COUNT_MAX               		(		COUNT_MAX               	),
    
    .REQ_TAG_NUM             		(		REQ_TAG_NUM             	),

    .REORDER_BUFFER_WIDTH    		(		REORDER_BUFFER_WIDTH    	)
)
HWAccCMCtl_Thread_2_Inst
(
    .clk							(		clk 							),
    .rst							(		rst 							),

    .cxt_req_valid				(		cxt_req_valid				),
    .cxt_req_head				(		cxt_req_head				),
    .cxt_req_data				(		cxt_req_data				),
    .cxt_req_ready				(		cxt_req_ready				),

    .icm_mapping_lookup_valid		(		qpc_icm_mapping_lookup_valid	),
    .icm_mapping_lookup_head		(		qpc_icm_mapping_lookup_head		),
    .icm_mapping_lookup_ready		(		qpc_icm_mapping_lookup_ready	),

    .icm_mapping_rsp_valid			(		qpc_icm_mapping_rsp_valid		),
    .icm_mapping_rsp_icm_addr		(		qpc_icm_mapping_rsp_icm_addr	),
    .icm_mapping_rsp_phy_addr		(		qpc_icm_mapping_rsp_phy_addr	),
    .icm_mapping_rsp_ready          (       qpc_icm_mapping_rsp_ready       ),

    .qpc_get_req_valid				(		qpc_get_req_valid				),
    .qpc_get_req_head				(		qpc_get_req_head				),
    .qpc_get_req_ready				(		qpc_get_req_ready				)
);

HWAccCMCtl_Thread_3
#(
    .ICM_CACHE_TYPE          		(		ICM_CACHE_TYPE          	),
    .ICM_PAGE_NUM            		(		ICM_PAGE_NUM            	),
    
    .ICM_ENTRY_NUM           		(		`ICM_ENTRY_NUM_CQC           	),
    
    .ICM_SLOT_SIZE           		(		ICM_SLOT_SIZE           	),
    .ICM_ADDR_WIDTH          		(		ICM_ADDR_WIDTH          	),

    .CACHE_ADDR_WIDTH        		(		CACHE_ADDR_WIDTH        	),
    .CACHE_ENTRY_WIDTH       		(		`CACHE_ENTRY_WIDTH_QPC      ),
    .CACHE_SET_NUM           		(		CACHE_SET_NUM           	),
    
    .CACHE_OFFSET_WIDTH      		(		CACHE_OFFSET_WIDTH      	),
    .CACHE_TAG_WIDTH         		(		CACHE_TAG_WIDTH         	),
    .PHYSICAL_ADDR_WIDTH     		(		PHYSICAL_ADDR_WIDTH     	),
    .COUNT_MAX               		(		COUNT_MAX               	),
    
    .REQ_TAG_NUM             		(		REQ_TAG_NUM             	),

    .REORDER_BUFFER_WIDTH    		(		REORDER_BUFFER_WIDTH    	)
)
HWAccCMCtl_Thread_3_Inst
(
    .clk							(		clk 							),
    .rst							(		rst 							),

    .qpc_get_rsp_valid				(		qpc_get_rsp_valid				),
    .qpc_get_rsp_head				(		qpc_get_rsp_head				),
    .qpc_get_rsp_data				(		qpc_get_rsp_data				),
    .qpc_get_rsp_ready				(		qpc_get_rsp_ready				),

    .icm_mapping_lookup_valid		(		cqc_icm_mapping_lookup_valid	),
    .icm_mapping_lookup_head		(		cqc_icm_mapping_lookup_head		),
    .icm_mapping_lookup_ready		(		cqc_icm_mapping_lookup_ready	),

    .icm_mapping_rsp_valid			(		cqc_icm_mapping_rsp_valid		),
    .icm_mapping_rsp_icm_addr		(		cqc_icm_mapping_rsp_icm_addr	),
    .icm_mapping_rsp_phy_addr		(		cqc_icm_mapping_rsp_phy_addr	),
    .icm_mapping_rsp_ready          (       cqc_icm_mapping_rsp_ready       ),

    .qpc_buffer_wen					(		qpc_staged_buffer_wea			),
    .qpc_buffer_addr				(		qpc_staged_buffer_addra			),
    .qpc_buffer_din					(		qpc_staged_buffer_dina			),

    .cqc_get_req_valid				(		cqc_get_req_valid				),
    .cqc_get_req_head				(		cqc_get_req_head				),
    .cqc_get_req_ready				(		cqc_get_req_ready				)
);

HWAccCMCtl_Thread_4
#(
    .ICM_CACHE_TYPE          		(		ICM_CACHE_TYPE          	),
    .ICM_PAGE_NUM            		(		ICM_PAGE_NUM            	),
    
    .ICM_ENTRY_NUM           		(		`ICM_ENTRY_NUM_EQC          	),
    
    .ICM_SLOT_SIZE           		(		ICM_SLOT_SIZE           	),
    .ICM_ADDR_WIDTH          		(		ICM_ADDR_WIDTH          	),

    .CACHE_ADDR_WIDTH        		(		CACHE_ADDR_WIDTH        	),
    .CACHE_ENTRY_WIDTH       		(		`CACHE_ENTRY_WIDTH_CQC      ),
    .CACHE_SET_NUM           		(		CACHE_SET_NUM           	),
    
    .CACHE_OFFSET_WIDTH      		(		CACHE_OFFSET_WIDTH      	),
    .CACHE_TAG_WIDTH         		(		CACHE_TAG_WIDTH         	),
    .PHYSICAL_ADDR_WIDTH     		(		PHYSICAL_ADDR_WIDTH     	),
    .COUNT_MAX               		(		COUNT_MAX               	),
    
    .REQ_TAG_NUM             		(		REQ_TAG_NUM             	),

    .REORDER_BUFFER_WIDTH    		(		REORDER_BUFFER_WIDTH    	)
)
HWAccCMCtl_Thread_4_Inst
(
    .clk 							(		clk 							),
    .rst 							(		rst 							),

    .cqc_get_rsp_valid 				(		cqc_get_rsp_valid 				),
    .cqc_get_rsp_head 				(		cqc_get_rsp_head 				),
    .cqc_get_rsp_data 				(		cqc_get_rsp_data 				),
    .cqc_get_rsp_ready 				(		cqc_get_rsp_ready 				),

    .icm_mapping_lookup_valid 		(		eqc_icm_mapping_lookup_valid 	),
    .icm_mapping_lookup_head 		(		eqc_icm_mapping_lookup_head 	),
    .icm_mapping_lookup_ready 		(		eqc_icm_mapping_lookup_ready 	),

    .icm_mapping_rsp_valid 			(		eqc_icm_mapping_rsp_valid 		),
    .icm_mapping_rsp_icm_addr 		(		eqc_icm_mapping_rsp_icm_addr 	),
    .icm_mapping_rsp_phy_addr 		(		eqc_icm_mapping_rsp_phy_addr 	),
    .icm_mapping_rsp_ready          (       eqc_icm_mapping_rsp_ready       ),

    .cqc_buffer_wen 				(		cqc_staged_buffer_wea 			),
    .cqc_buffer_addr 				(		cqc_staged_buffer_addra 		),
    .cqc_buffer_din 				(		cqc_staged_buffer_dina 			),

    .eqc_get_req_valid 				(		eqc_get_req_valid 				),
    .eqc_get_req_head 				(		eqc_get_req_head 				),
    .eqc_get_req_ready 				(		eqc_get_req_ready 				)
);

HWAccCMCtl_Thread_5
#(
    .ICM_CACHE_TYPE          		(		ICM_CACHE_TYPE          	),
    .ICM_PAGE_NUM            		(		ICM_PAGE_NUM            	),
    
    .ICM_ENTRY_NUM           		(		ICM_ENTRY_NUM           	),
    
    .ICM_SLOT_SIZE           		(		ICM_SLOT_SIZE           	),
    .ICM_ADDR_WIDTH          		(		ICM_ADDR_WIDTH          	),

    .CACHE_ADDR_WIDTH        		(		CACHE_ADDR_WIDTH        	),
    .CACHE_ENTRY_WIDTH       		(		`CACHE_ENTRY_WIDTH_CQC      ),
    .CACHE_SET_NUM           		(		CACHE_SET_NUM           	),
    
    .CACHE_OFFSET_WIDTH      		(		CACHE_OFFSET_WIDTH      	),
    .CACHE_TAG_WIDTH         		(		CACHE_TAG_WIDTH         	),
    .PHYSICAL_ADDR_WIDTH     		(		PHYSICAL_ADDR_WIDTH     	),
    .COUNT_MAX               		(		COUNT_MAX               	),
    
    .REQ_TAG_NUM             		(		REQ_TAG_NUM             	),

    .REORDER_BUFFER_WIDTH    		(		REORDER_BUFFER_WIDTH    	)
)
HWAccCMCtl_Thread_5_Inst
(
    .clk							(		clk 							),
    .rst							(		rst 							),

    .eqc_get_rsp_valid				(		eqc_get_rsp_valid				),
    .eqc_get_rsp_head				(		eqc_get_rsp_head				),
    .eqc_get_rsp_data				(		eqc_get_rsp_data				),
    .eqc_get_rsp_ready				(		eqc_get_rsp_ready				),

    .qpc_buffer_addr				(		qpc_staged_buffer_addrb			),
    .qpc_buffer_dout				(		qpc_staged_buffer_doutb			),

    .cqc_buffer_addr				(		cqc_staged_buffer_addrb			),
    .cqc_buffer_dout				(		cqc_staged_buffer_doutb			),

    .cxt_combine_valid				(		cxt_combine_valid				),
    .cxt_combine_head				(		cxt_combine_head				),
    .cxt_combine_data				(		cxt_combine_data				),
    .cxt_combine_ready				(		cxt_combine_ready				)
);

HWAccCMCtl_Thread_6
#(
    .ICM_CACHE_TYPE          		(		ICM_CACHE_TYPE          	),
    .ICM_PAGE_NUM            		(		ICM_PAGE_NUM            	),
    
    .ICM_ENTRY_NUM           		(		ICM_ENTRY_NUM           	),
    
    .ICM_SLOT_SIZE           		(		ICM_SLOT_SIZE           	),
    .ICM_ADDR_WIDTH          		(		ICM_ADDR_WIDTH          	),

    .CACHE_ADDR_WIDTH        		(		CACHE_ADDR_WIDTH        	),
    .CACHE_ENTRY_WIDTH       		(		CACHE_ENTRY_WIDTH       	),
    .CACHE_SET_NUM           		(		CACHE_SET_NUM           	),
    
    .CACHE_OFFSET_WIDTH      		(		CACHE_OFFSET_WIDTH      	),
    .CACHE_TAG_WIDTH         		(		CACHE_TAG_WIDTH         	),
    .PHYSICAL_ADDR_WIDTH     		(		PHYSICAL_ADDR_WIDTH     	),
    .COUNT_MAX               		(		COUNT_MAX               	),
    
    .REQ_TAG_NUM             		(		REQ_TAG_NUM             	),

    .REORDER_BUFFER_WIDTH    		(		REORDER_BUFFER_WIDTH    	)
)
HWAccCMCtl_Thread_6_Inst
(
    .clk							(		clk 							),
    .rst							(		rst 							),

    .cxt_combine_valid				(		cxt_combine_valid				),
    .cxt_combine_head				(		cxt_combine_head				),
    .cxt_combine_data				(		cxt_combine_data				),
    .cxt_combine_ready				(		cxt_combine_ready				),

    .tag_qpn_mapping_table_addr	(		tag_qpn_mapping_table_addrb	),
    .tag_qpn_mapping_table_dout	(		tag_qpn_mapping_table_doutb	),

    .SQ_cxt_rsp_valid		(		SQ_cxt_rsp_valid		),
    .SQ_cxt_rsp_head		(		SQ_cxt_rsp_head			),
    .SQ_cxt_rsp_data		(		SQ_cxt_rsp_data			),
    .SQ_cxt_rsp_ready		(		SQ_cxt_rsp_ready		),

    .TX_REQ_cxt_rsp_valid		(		TX_REQ_cxt_rsp_valid		),
    .TX_REQ_cxt_rsp_head		(		TX_REQ_cxt_rsp_head			),
    .TX_REQ_cxt_rsp_data		(		TX_REQ_cxt_rsp_data			),
    .TX_REQ_cxt_rsp_ready		(		TX_REQ_cxt_rsp_ready		),

    .RX_REQ_cxt_rsp_valid		(		RX_REQ_cxt_rsp_valid		),
    .RX_REQ_cxt_rsp_head		(		RX_REQ_cxt_rsp_head			),
    .RX_REQ_cxt_rsp_data		(		RX_REQ_cxt_rsp_data			),
    .RX_REQ_cxt_rsp_ready		(		RX_REQ_cxt_rsp_ready		),

    .RX_RESP_cxt_rsp_valid		(		RX_RESP_cxt_rsp_valid		),
    .RX_RESP_cxt_rsp_head		(		RX_RESP_cxt_rsp_head			),
    .RX_RESP_cxt_rsp_data		(		RX_RESP_cxt_rsp_data			),
    .RX_RESP_cxt_rsp_ready 		(		RX_RESP_cxt_rsp_ready 		)
);

SRAM_SDP_Template #(
    .RAM_WIDTH      (   `CACHE_ENTRY_WIDTH_QPC      ),
    .RAM_DEPTH      (   32                          )
)
QPCStagedBuffer_Inst
(
    .clk            (   	clk                                 ),
    .rst            (   	rst                                 ),

    .wea            (		qpc_staged_buffer_wea				),
    .addra          (		qpc_staged_buffer_addra				),
    .dina           (		qpc_staged_buffer_dina				),

    .addrb          (		qpc_staged_buffer_addrb				),
    .doutb          (		qpc_staged_buffer_doutb				)
);

SRAM_SDP_Template #(
    .RAM_WIDTH      (   `CACHE_ENTRY_WIDTH_CQC      ),
    .RAM_DEPTH      (   32                          )
)
CQCStagedBuffer_Inst
(
    .clk            (   	clk                                 ),
    .rst            (   	rst                                 ),

    .wea            (   	cqc_staged_buffer_wea				),
    .addra          (   	cqc_staged_buffer_addra				),
    .dina           (   	cqc_staged_buffer_dina				),

    .addrb          (   	cqc_staged_buffer_addrb				),
    .doutb          (   	cqc_staged_buffer_doutb				)
);

SRAM_SDP_Template #(
    .RAM_WIDTH      (   `QP_NUM_LOG                 ),
    .RAM_DEPTH      (   32    )       //Tag per channel * 4 channels
)
TagQPNMappingTable_Inst
(
    .clk            (   	clk                                 ),
    .rst            (   	rst                                 ),

    .wea            (   	tag_qpn_mapping_table_wea			),
    .addra          (   	tag_qpn_mapping_table_addra		  ),
    .dina           (   	tag_qpn_mapping_table_dina			),

    .addrb          (   	tag_qpn_mapping_table_addrb		),
    .doutb          (   	tag_qpn_mapping_table_doutb		)
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule