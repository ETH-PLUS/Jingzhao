/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ICMBuffer
Author:     YangFan
Function:   2-Way-Associate Cache Buffer, provide generalized Get/Set/Del Interface.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/ 

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module ICMBuffer
#(
    parameter               ICM_CACHE_TYPE          =       `CACHE_TYPE_MTT,
    parameter               ICM_PAGE_NUM            =       `ICM_PAGE_NUM_MTT,
    parameter               ICM_PAGE_NUM_LOG        =       log2b(ICM_PAGE_NUM - 1),
    parameter               ICM_ENTRY_NUM           =       `ICM_ENTRY_NUM_MTT,
    parameter               ICM_ENTRY_NUM_LOG       =       log2b(ICM_ENTRY_NUM - 1),
    parameter               ICM_SLOT_SIZE           =       `ICM_SLOT_SIZE_MTT,
    parameter               ICM_ADDR_WIDTH          =       64,

    parameter               CACHE_ADDR_WIDTH        =       log2b(ICM_ENTRY_NUM * ICM_SLOT_SIZE),
    parameter               CACHE_ENTRY_WIDTH       =       256,
    parameter               CACHE_SET_NUM           =       1024,
    parameter               CACHE_SET_NUM_LOG       =       log2b(CACHE_SET_NUM - 1),
    parameter               CACHE_OFFSET_WIDTH      =       log2b(ICM_SLOT_SIZE - 1),
    parameter               CACHE_TAG_WIDTH         =       CACHE_ADDR_WIDTH - CACHE_OFFSET_WIDTH - CACHE_SET_NUM_LOG,
    parameter               PHYSICAL_ADDR_WIDTH     =       `PHY_SPACE_ADDR_WIDTH,
    parameter               COUNT_MAX               =       2,
    parameter               COUNT_MAX_LOG           =       log2b(COUNT_MAX - 1) + 1,
    parameter               REQ_TAG_NUM             =       32,
    parameter               REQ_TAG_NUM_LOG         =       log2b(REQ_TAG_NUM - 1),
    parameter               REORDER_BUFFER_WIDTH    =       (ICM_CACHE_TYPE == `CACHE_TYPE_MTT) ? CACHE_ENTRY_WIDTH * 2 + COUNT_MAX_LOG : CACHE_ENTRY_WIDTH + COUNT_MAX_LOG 
)
(
    input   wire                                                                                                clk,
    input   wire                                                                                                rst,

//Cache Get Req Interface
    input   wire                                                                                                get_req_valid,
    input   wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]        get_req_head,
    output  wire                                                                                                get_req_ready,

//Cache Get Resp Interface
    output  wire                                                                                                get_rsp_valid,
    output  wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH + 1 - 1 : 0]    get_rsp_head,
    output  wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                 get_rsp_data,
    input   wire                                                                                                get_rsp_ready,

//Cache Set Req Interface
    input   wire                                                                                                set_req_valid,
    input   wire    [CACHE_ADDR_WIDTH - 1 : 0]                                                                  set_req_head,
    input   wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                 set_req_data,
    output  wire                                                                                                set_req_ready,

//Cache Del Req Interface
    input   wire                                                                                                del_req_valid,
    input   wire    [CACHE_ADDR_WIDTH - 1 : 0]                                                                  del_req_head,
    output  wire                                                                                                del_req_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire        [0:0]                                                           way_0_get_wen;
wire        [CACHE_SET_NUM_LOG - 1 : 0]                                     way_0_get_addr;
wire        [CACHE_ENTRY_WIDTH + CACHE_TAG_WIDTH + 1 - 1 : 0]               way_0_get_din;
wire        [CACHE_ENTRY_WIDTH + CACHE_TAG_WIDTH + 1 - 1 : 0]               way_0_get_dout;

wire        [0:0]                                                           way_0_set_del_wen;
wire        [CACHE_SET_NUM_LOG - 1 : 0]                                     way_0_set_del_addr;
wire        [CACHE_ENTRY_WIDTH + CACHE_TAG_WIDTH + 1 - 1 : 0]               way_0_set_del_din;
wire        [CACHE_ENTRY_WIDTH + CACHE_TAG_WIDTH + 1 - 1 : 0]               way_0_set_del_dout;

wire        [0:0]                                                           way_1_get_wen;
wire        [CACHE_SET_NUM_LOG - 1 : 0]                                     way_1_get_addr;
wire        [CACHE_ENTRY_WIDTH + CACHE_TAG_WIDTH + 1 - 1 : 0]               way_1_get_din;
wire        [CACHE_ENTRY_WIDTH + CACHE_TAG_WIDTH + 1 - 1 : 0]               way_1_get_dout;

wire        [0:0]                                                           way_1_set_del_wen;
wire        [CACHE_SET_NUM_LOG - 1 : 0]                                     way_1_set_del_addr;
wire        [CACHE_ENTRY_WIDTH + CACHE_TAG_WIDTH + 1 - 1 : 0]               way_1_set_del_din;
wire        [CACHE_ENTRY_WIDTH + CACHE_TAG_WIDTH + 1 - 1 : 0]               way_1_set_del_dout;

wire        [0:0]                                       lru_get_wen;
wire        [CACHE_SET_NUM_LOG - 1 : 0]                 lru_get_addr;
wire        [0:0]                                       lru_get_din;
wire        [0:0]                                       lru_get_dout;

wire        [0:0]                                       lru_set_del_wen;
wire        [CACHE_SET_NUM_LOG - 1 : 0]                 lru_set_del_addr;
wire        [0:0]                                       lru_set_del_din;
wire        [0:0]                                       lru_set_del_dout;

/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
SRAM_TDP_Template #(
    .RAM_WIDTH      (   CACHE_ENTRY_WIDTH + CACHE_TAG_WIDTH + 1 ),
    .RAM_DEPTH      (   CACHE_SET_NUM                           )
)
Cache_Way_0
(
    .clk            (   clk                                     ),
    .rst            (   rst                                     ),

    .wea            (   way_0_get_wen                           ),
    .addra          (   way_0_get_addr                          ),
    .dina           (   way_0_get_din                           ),
    .douta          (   way_0_get_dout                          ),

    .web            (   way_0_set_del_wen                       ),
    .addrb          (   way_0_set_del_addr                      ),
    .dinb           (   way_0_set_del_din                       ),
    .doutb          (   way_0_set_del_dout                      )
);

SRAM_TDP_Template #(
    .RAM_WIDTH      (   CACHE_ENTRY_WIDTH + CACHE_TAG_WIDTH + 1 ),
    .RAM_DEPTH      (   CACHE_SET_NUM                           )
)
Cache_Way_1
(
    .clk            (   clk                                     ),
    .rst            (   rst                                     ),

    .wea            (   way_1_get_wen                           ),
    .addra          (   way_1_get_addr                          ),
    .dina           (   way_1_get_din                           ),
    .douta          (   way_1_get_dout                          ),

    .web            (   way_1_set_del_wen                       ),
    .addrb          (   way_1_set_del_addr                      ),
    .dinb           (   way_1_set_del_din                       ),
    .doutb          (   way_1_set_del_dout                      )
);

SRAM_TDP_Template #(
    .RAM_WIDTH      (   1                                       ),
    .RAM_DEPTH      (   CACHE_SET_NUM                           )
)
LRU_Table
(
    .clk            (   clk                                     ),
    .rst            (   rst                                     ),

    .wea            (   lru_get_wen                             ),
    .addra          (   lru_get_addr                            ),
    .dina           (   lru_get_din                             ),
    .douta          (   lru_get_dout                            ),

    .web            (   lru_set_del_wen                         ),
    .addrb          (   lru_set_del_addr                        ),
    .dinb           (   lru_set_del_din                         ),
    .doutb          (   lru_set_del_dout                        )
);

ICMBuffer_Get_Thread
#(
    .ICM_CACHE_TYPE          (  ICM_CACHE_TYPE          ),
    .CACHE_ADDR_WIDTH        (  CACHE_ADDR_WIDTH        ),
    .CACHE_ENTRY_WIDTH       (  CACHE_ENTRY_WIDTH       ),
    .CACHE_OFFSET_WIDTH      (  CACHE_OFFSET_WIDTH      ),
    .CACHE_TAG_WIDTH         (  CACHE_TAG_WIDTH         ),
    .CACHE_SET_NUM           (  CACHE_SET_NUM           ),
    .CACHE_SET_NUM_LOG       (  CACHE_SET_NUM_LOG       ),
    .PHYSICAL_ADDR_WIDTH     (  PHYSICAL_ADDR_WIDTH     ),
    .COUNT_MAX               (  COUNT_MAX               ),
    .COUNT_MAX_LOG           (  COUNT_MAX_LOG           ),
    .REQ_TAG_NUM             (  REQ_TAG_NUM             ),
    .REQ_TAG_NUM_LOG         (  REQ_TAG_NUM_LOG         )
)
ICMBuffer_Get_Thread_Inst
(
    .clk                (   clk                 ),
    .rst                (   rst                 ),

    .get_req_valid      (   get_req_valid       ),
    .get_req_head       (   get_req_head        ),
    .get_req_ready      (   get_req_ready       ),

    .get_rsp_valid      (   get_rsp_valid       ),
    .get_rsp_head       (   get_rsp_head        ),
    .get_rsp_data       (   get_rsp_data        ),
    .get_rsp_ready      (   get_rsp_ready       ),

    .way_0_wen          (   way_0_get_wen       ),
    .way_0_addr         (   way_0_get_addr      ),
    .way_0_din          (   way_0_get_din       ),
    .way_0_dout         (   way_0_get_dout      ),

    .way_1_wen          (   way_1_get_wen       ),
    .way_1_addr         (   way_1_get_addr      ),
    .way_1_din          (   way_1_get_din       ),
    .way_1_dout         (   way_1_get_dout      ),

    .lru_wen            (   lru_get_wen         ),
    .lru_addr           (   lru_get_addr        ),
    .lru_din            (   lru_get_din         ),
    .lru_dout           (   lru_get_dout        )
);

ICMBuffer_Set_Del_Thread
#(
    .ICM_CACHE_TYPE          (  ICM_CACHE_TYPE          ),
    .CACHE_ADDR_WIDTH        (  CACHE_ADDR_WIDTH        ),
    .CACHE_ENTRY_WIDTH       (  CACHE_ENTRY_WIDTH       ),
    .CACHE_OFFSET_WIDTH      (  CACHE_OFFSET_WIDTH      ),
    .CACHE_TAG_WIDTH         (  CACHE_TAG_WIDTH         ),
    .CACHE_SET_NUM           (  CACHE_SET_NUM           ),
    .CACHE_SET_NUM_LOG       (  CACHE_SET_NUM_LOG       ),
    .PHYSICAL_ADDR_WIDTH     (  PHYSICAL_ADDR_WIDTH     ),
    .COUNT_MAX               (  COUNT_MAX               ),
    .COUNT_MAX_LOG           (  COUNT_MAX_LOG           ),
    .REQ_TAG_NUM             (  REQ_TAG_NUM             ),
    .REQ_TAG_NUM_LOG         (  REQ_TAG_NUM_LOG         )
)
ICMBuffer_Set_Del_Thread_Inst
(
    .clk                (   clk                 ),
    .rst                (   rst                 ),

    .set_req_valid      (   set_req_valid       ),
    .set_req_head       (   set_req_head        ),
    .set_req_data       (   set_req_data        ),
    .set_req_ready      (   set_req_ready       ),

    .del_req_valid      (   del_req_valid       ),
    .del_req_head       (   del_req_head        ),
    .del_req_ready      (   del_req_ready       ),

    .way_0_wen          (   way_0_set_del_wen   ),
    .way_0_addr         (   way_0_set_del_addr  ),
    .way_0_din          (   way_0_set_del_din   ),
    .way_0_dout         (   way_0_set_del_dout  ),

    .way_1_wen          (   way_1_set_del_wen   ),
    .way_1_addr         (   way_1_set_del_addr  ),
    .way_1_din          (   way_1_set_del_din   ),
    .way_1_dout         (   way_1_set_del_dout  ),

    .lru_wen            (   lru_set_del_wen     ),
    .lru_addr           (   lru_set_del_addr    ),
    .lru_din            (   lru_set_del_din     ),
    .lru_dout           (   lru_set_del_dout    )
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

`ifdef  ILA_ON

    generate    

        if(ICM_CACHE_TYPE == `CACHE_TYPE_QPC) begin
            ila_icm_buffer ila_icm_buffer_inst(
                .clk(clk),

                .probe0(get_req_valid),
                .probe1(get_req_head),
                .probe2(get_req_ready),

                .probe3(get_rsp_valid),
                .probe4(get_rsp_head),
                .probe5(get_rsp_data),
                .probe6(get_rsp_ready),

                .probe7(set_req_valid),
                .probe8(set_req_head),
                .probe9(set_req_data),
                .probe10(set_req_ready)
            );
    end
    endgenerate
`endif

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule