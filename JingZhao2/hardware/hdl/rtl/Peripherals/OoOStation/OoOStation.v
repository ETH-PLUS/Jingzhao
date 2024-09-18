/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       OoOStation
Author:     YangFan
Function:   OoOStation is short for Out-of-Order station.
            This module is a special abstraction aimed at solving Head-Of-Line Problem in Stateful Pipeline.
            OoOStation accepts resources request and manages out-of-order request and resposne.
            User can carry user-defined data with request, when desired resource is available, OoOStation will return resources with user-defined data.
            For example, as for ReqTransEngine, the request is accompanied with WQE metadata, as for RespRecvControl, the request is accompanied with packet.
            OoOStation does not care about what the req and resource are, it just handles out-of-order execution.
            Typically, OoOStation interacts with two three threads: ingress thread, egress thread and resource mgt thread.
            Ingress thread: Asynchronously issues resource request to OoOStation.
            Egress thread: Accept resources from OoOStation and triggers next pipeline stage.
            Resource mgt thread: Manage resources and respond to resource request.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "common_function_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module OoOStation #(
    parameter       ID                          =   1,

    //TAG_NUM is not equal to SLOT_NUM, since each resource req consumes 1 tag, and it may require more than 1 slot.
    parameter       TAG_NUM                     =   32,
    parameter       TAG_NUM_LOG                 =   log2b(TAG_NUM - 1),


    //RESOURCE_CMD/RESP_WIDTH is resource-specific
    //For example, MR resource cmd format is {PD, LKey, Lengtg, Addr}, MR resource reply format is {PTE-1, PTE-0, indicator}
    parameter       RESOURCE_CMD_HEAD_WIDTH     =   128,
    parameter       RESOURCE_CMD_DATA_WIDTH     =   256,
    parameter       RESOURCE_RESP_HEAD_WIDTH    =   128, 
    parameter       RESOURCE_RESP_DATA_WIDTH    =   128,

    parameter       SLOT_NUM                    =   512,
    parameter       QUEUE_NUM                   =   32,
    parameter       SLOT_NUM_LOG                =   log2b(SLOT_NUM - 1),
    parameter       QUEUE_NUM_LOG               =   log2b(QUEUE_NUM - 1),

    //When issuing cmd to Resource Manager, add tag index
    parameter       OOO_CMD_HEAD_WIDTH          =   `MAX_REQ_TAG_NUM_LOG + RESOURCE_CMD_HEAD_WIDTH,
    parameter       OOO_CMD_DATA_WIDTH          =   RESOURCE_CMD_DATA_WIDTH,
    parameter       OOO_RESP_HEAD_WIDTH         =   `MAX_REQ_TAG_NUM_LOG + RESOURCE_RESP_HEAD_WIDTH,
    parameter       OOO_RESP_DATA_WIDTH         =   RESOURCE_RESP_DATA_WIDTH,

    parameter       INGRESS_HEAD_WIDTH          =   RESOURCE_CMD_HEAD_WIDTH + `INGRESS_COMMON_HEAD_WIDTH,
    //INGRESS_DATA_WIDTH is ingress-thread-specific
    parameter       INGRESS_DATA_WIDTH          =   512,

    parameter       SLOT_WIDTH                  =   INGRESS_DATA_WIDTH,


    //Egress thread
    parameter       EGRESS_HEAD_WIDTH           =   RESOURCE_RESP_HEAD_WIDTH + `EGRESS_COMMON_HEAD_WIDTH,
    parameter       EGRESS_DATA_WIDTH           =   INGRESS_DATA_WIDTH
)
(
    input   wire                                            clk,
    input   wire                                            rst,

    input   wire                                            ingress_valid,
    //Head format:
    //{tag index, required slot number, queue index}
    input   wire        [INGRESS_HEAD_WIDTH - 1 : 0]        ingress_head,
    //Data format:
    //This is defined by Ingress thread, OoOStation doesn't care about it.
    //Typically ingress_data represents the Metadata/Packet associated with current resource request 
    input   wire        [SLOT_WIDTH - 1 : 0]                ingress_data,
    input   wire                                            ingress_start,
    input   wire                                            ingress_last,
    output  wire                                            ingress_ready,

    output  wire        [SLOT_NUM_LOG : 0]                  available_slot_num,

    output  wire                                            resource_req_valid,
    //Head format:
    //{resource cmd, tag index}
    output  wire        [OOO_CMD_HEAD_WIDTH - 1 : 0]        resource_req_head,
    //Typically null
    output  wire        [OOO_CMD_DATA_WIDTH - 1 : 0]        resource_req_data,
    output  wire                                            resource_req_start,
    output  wire                                            resource_req_last,
    input   wire                                            resource_req_ready,

    input   wire                                            resource_resp_valid,
    //Head format:
    //{tag index}
    input   wire        [OOO_RESP_HEAD_WIDTH - 1 : 0]       resource_resp_head,
    //Data form ：
    //Defined by resource mgt
    input   wire        [OOO_RESP_DATA_WIDTH - 1 : 0]       resource_resp_data,
    input   wire                                            resource_resp_start,
    input   wire                                            resource_resp_last,
    output  wire                                            resource_resp_ready,

    output  wire                                            egress_valid,
    //Head format:
    //{resource, queue index}
    output  wire        [EGRESS_HEAD_WIDTH - 1 : 0]         egress_head,
    //Data format:
    //Same as ingress data
    output  wire        [EGRESS_DATA_WIDTH - 1 : 0]         egress_data,
    output  wire                                            egress_start,
    output  wire                                            egress_last,
    input   wire                                            egress_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                                        tag_fifo_wr_en;
wire            [TAG_NUM_LOG - 1 : 0]                       tag_fifo_din;
wire                                                        tag_fifo_prog_full;  
wire                                                        tag_fifo_empty;
wire            [TAG_NUM_LOG - 1 : 0]                       tag_fifo_dout;
wire                                                        tag_fifo_rd_en;

wire                                                        reorder_buffer_wea;
wire            [TAG_NUM_LOG - 1 : 0]                       reorder_buffer_addra;
wire            [RESOURCE_RESP_DATA_WIDTH + 1 - 1 : 0]      reorder_buffer_dina;             

wire            [TAG_NUM_LOG - 1 : 0]                       reorder_buffer_addrb;
wire            [RESOURCE_RESP_DATA_WIDTH + 1 - 1 : 0]      reorder_buffer_doutb;

wire                                                        tag_mapping_wea;
wire            [TAG_NUM_LOG - 1 : 0]                       tag_mapping_addra;
wire            [QUEUE_NUM_LOG + 1 - 1 : 0]                 tag_mapping_dina;             

wire            [TAG_NUM_LOG - 1 : 0]                       tag_mapping_addrb;
wire            [QUEUE_NUM_LOG + 1 - 1 : 0]                 tag_mapping_doutb;

wire                                                        enqueue_req_valid;
wire            [`MAX_QP_NUM_LOG + `MAX_OOO_SLOT_NUM_LOG - 1 : 0]      enqueue_req_head;
wire                                                        enqueue_req_start;
wire                                                        enqueue_req_last;
wire            [SLOT_WIDTH - 1 : 0]                        enqueue_req_data;
wire                                                        enqueue_req_ready;

wire                                                        empty_req_valid;
wire            [`MAX_QP_NUM_LOG - 1 : 0]                     empty_req_head;
wire                                                        empty_req_ready;
wire                                                        empty_resp_valid;
wire            [`MAX_QP_NUM_LOG : 0]                         empty_resp_head;
wire                                                        empty_resp_ready;

wire                                                        dequeue_req_valid;
wire            [`MAX_QP_NUM_LOG + `MAX_OOO_SLOT_NUM_LOG - 1 : 0]      dequeue_req_head;
wire  														dequeue_req_ready;
wire                                                        dequeue_resp_valid;
wire                                                        dequeue_resp_ready;
wire            [SLOT_WIDTH - 1 : 0]                        dequeue_resp_data;

wire                                                        get_req_valid;
wire            [`MAX_OOO_SLOT_NUM_LOG + `MAX_QP_NUM_LOG - 1 : 0]      get_req_head;
wire 														get_req_ready;
wire                                                        get_resp_valid;
wire                                                        get_resp_empty;
wire            [`MAX_OOO_SLOT_NUM_LOG + `MAX_QP_NUM_LOG - 1 : 0]      get_resp_head;
wire                                                        get_resp_ready;
wire            [SLOT_WIDTH - 1 : 0]                        get_resp_data;

wire                                                        bypass_egress_valid;
wire            [EGRESS_HEAD_WIDTH - 1 : 0]                 bypass_egress_head;
wire            [EGRESS_DATA_WIDTH - 1 : 0]                 bypass_egress_data;
wire                                                        bypass_egress_start;
wire                                                        bypass_egress_last;
wire                                                        bypass_egress_ready;

wire                                                        normal_egress_valid;
wire            [EGRESS_HEAD_WIDTH - 1 : 0]                 normal_egress_head;
wire            [EGRESS_DATA_WIDTH - 1 : 0]                 normal_egress_data;
wire                                                        normal_egress_start;
wire                                                        normal_egress_last;
wire                                                        normal_egress_ready;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
SyncFIFO_Template #(
    .FIFO_TYPE              (   0                       ),
    .FIFO_WIDTH             (   `DEFAULT_REQ_TAG_NUM_LOG             ),
    .FIFO_DEPTH             (   `DEFAULT_REQ_TAG_NUM                 )
)
ooo_tag_fifo
(
    .clk                    (   clk                     ),
    .rst                    (   rst                     ),

    .wr_en                  (   tag_fifo_wr_en          ),
    .din                    (   tag_fifo_din            ),
    .prog_full              (   tag_fifo_prog_full      ),
    .rd_en                  (   tag_fifo_rd_en          ),
    .dout                   (   tag_fifo_dout           ),
    .empty                  (   tag_fifo_empty          ),
    .data_count             (                           )
);

SRAM_SDP_Template #(
    .RAM_WIDTH              (   RESOURCE_RESP_DATA_WIDTH + 1    ),	//1-bit to indicate whether this slot is valid.
    .RAM_DEPTH              (   `DEFAULT_REQ_TAG_NUM                         )
)
ReorderBuffer
(
    .clk                    (   clk                             ),
    .rst                    (   rst                             ),

    .wea                    (   reorder_buffer_wea              ),
    .addra                  (   reorder_buffer_addra            ),
    .dina                   (   reorder_buffer_dina             ),             

    .addrb                  (   reorder_buffer_addrb            ),
    .doutb                  (   reorder_buffer_doutb            )                       
);

SRAM_SDP_Template #(
    .RAM_WIDTH              (   QUEUE_NUM_LOG                   ),  //Each tag is mapped to a QP
    .RAM_DEPTH              (   `DEFAULT_REQ_TAG_NUM                         )
)
TagMappingTable
(
    .clk                    (   clk                             ),
    .rst                    (   rst                             ),

    .wea                    (   tag_mapping_wea                 ),
    .addra                  (   tag_mapping_addra               ),
    .dina                   (   tag_mapping_dina                ),             

    .addrb                  (   tag_mapping_addrb               ),
    .doutb                  (   tag_mapping_doutb               )                       
);

DynamicMultiQueue #(
    .SLOT_WIDTH                 (   SLOT_WIDTH                     ),
    .SLOT_NUM                   (   SLOT_NUM                       ),
    .QUEUE_NUM                  (   QUEUE_NUM                      )
)
ReservationStation
(
    .clk                        (   clk                             ),
    .rst                        (   rst                             ),

    .ov_available_slot_num      (   available_slot_num              ),

    .i_enqueue_req_valid        (   enqueue_req_valid               ),
    .iv_enqueue_req_head        (   enqueue_req_head                ),
    .iv_enqueue_req_data        (   enqueue_req_data                ),
    .i_enqueue_req_start        (   enqueue_req_start               ),
    .i_enqueue_req_last         (   enqueue_req_last                ),
    .o_enqueue_req_ready        (   enqueue_req_ready               ),

    .i_empty_req_valid          (   empty_req_valid                 ),
    .iv_empty_req_head          (   empty_req_head                  ),
    .o_empty_req_ready          (   empty_req_ready                 ),

    .o_empty_resp_valid         (   empty_resp_valid                ),
    .ov_empty_resp_head         (   empty_resp_head                 ),
    .i_empty_resp_ready         (   empty_resp_ready                ),

    .i_dequeue_req_valid        (   dequeue_req_valid               ),
    .iv_dequeue_req_head        (   dequeue_req_head                ),
    .o_dequeue_req_ready        (   dequeue_req_ready				),

    .o_dequeue_resp_valid       (   dequeue_resp_valid              ),
    .ov_dequeue_resp_head       (   dequeue_resp_head               ),
    .o_dequeue_resp_start       (   dequeue_resp_start              ),
    .o_dequeue_resp_last        (   dequeue_resp_last               ),
    .i_dequeue_resp_ready       (   dequeue_resp_ready              ),
    .ov_dequeue_resp_data       (   dequeue_resp_data               ),

    .i_modify_head_req_valid    (   1'b0                            ),
    .iv_modify_head_req_head    (   {QUEUE_NUM_LOG{1'b0}}           ),
    .iv_modify_head_req_data    (   {SLOT_WIDTH{1'b0}}              ),
    .o_modify_head_req_ready    (                                   ),

    .i_get_req_valid            (   get_req_valid                   ),
    .iv_get_req_head            (   get_req_head                    ),
    .o_get_req_ready            (   get_req_ready                   ),

    .o_get_resp_valid           (   get_resp_valid                  ),
    .ov_get_resp_head           (   get_resp_head                   ),
    .o_get_resp_start           (                                   ),
    .o_get_resp_last            (                                   ),
    .o_get_resp_empty           (   get_resp_empty                  ),
    .i_get_resp_ready           (   get_resp_ready                  ),
    .ov_get_resp_data           (   get_resp_data                   )
);

OoOStation_Thread_1 #(
    .ID                         (   ID                              ),

    .TAG_NUM                     (   TAG_NUM                         ),
    .TAG_NUM_LOG                 (   TAG_NUM_LOG                     ),

    .RESOURCE_CMD_HEAD_WIDTH     (   RESOURCE_CMD_HEAD_WIDTH         ),
    .RESOURCE_CMD_DATA_WIDTH     (   RESOURCE_CMD_DATA_WIDTH         ),
    .RESOURCE_RESP_HEAD_WIDTH    (   RESOURCE_RESP_HEAD_WIDTH        ),
    .RESOURCE_RESP_DATA_WIDTH    (   RESOURCE_RESP_DATA_WIDTH        ),

    .SLOT_NUM                    (   SLOT_NUM                        ),
    .QUEUE_NUM                   (   QUEUE_NUM                       ),
    .SLOT_NUM_LOG                (   SLOT_NUM_LOG                    ),
    .QUEUE_NUM_LOG               (   QUEUE_NUM_LOG                   ),

    .OOO_CMD_HEAD_WIDTH          (   OOO_CMD_HEAD_WIDTH              ),
    .OOO_CMD_DATA_WIDTH          (   OOO_CMD_DATA_WIDTH              ),
    .OOO_RESP_HEAD_WIDTH         (   OOO_RESP_HEAD_WIDTH             ),
    .OOO_RESP_DATA_WIDTH         (   OOO_RESP_DATA_WIDTH             ),

    .INGRESS_HEAD_WIDTH          (   INGRESS_HEAD_WIDTH              ),
    .INGRESS_DATA_WIDTH          (   INGRESS_DATA_WIDTH              ),

    .SLOT_WIDTH                  (   SLOT_WIDTH                      ),

    .EGRESS_HEAD_WIDTH           (   EGRESS_HEAD_WIDTH               ),
    .EGRESS_DATA_WIDTH           (   EGRESS_DATA_WIDTH               )
)
OoOStation_Thread_1_Inst
(
    .clk                        (   clk                             ),
    .rst                        (   rst                             ),

    .ingress_valid              (   ingress_valid                   ),
    .ingress_head               (   ingress_head                    ),
    .ingress_data               (   ingress_data                    ),
    .ingress_start              (   ingress_start                   ),
    .ingress_last               (   ingress_last                    ),
    .ingress_ready              (   ingress_ready                   ),

    .resource_req_valid         (   resource_req_valid              ),
    .resource_req_head          (   resource_req_head               ),
    .resource_req_data          (   resource_req_data               ),
    .resource_req_start         (   resource_req_start              ),
    .resource_req_last          (   resource_req_last               ),
    .resource_req_ready         (   resource_req_ready              ),

    .tag_fifo_empty             (   tag_fifo_empty                  ),
    .tag_fifo_dout              (   tag_fifo_dout                   ),
    .tag_fifo_rd_en             (   tag_fifo_rd_en                  ),

    .tag_mapping_wea            (   tag_mapping_wea                 ),
    .tag_mapping_addra          (   tag_mapping_addra               ),
    .tag_mapping_dina           (   tag_mapping_dina                ),
        
    .available_slot_num         (   available_slot_num              ),

    .empty_req_valid            (   empty_req_valid                 ),
    .empty_req_head             (   empty_req_head                  ),
    .empty_req_ready            (   empty_req_ready                 ),

    .empty_resp_valid           (   empty_resp_valid                ),
    .empty_resp_head            (   empty_resp_head                 ),
    .empty_resp_ready           (   empty_resp_ready                ), 

    .enqueue_req_valid          (   enqueue_req_valid               ),
    .enqueue_req_head           (   enqueue_req_head                ),
    .enqueue_req_start          (   enqueue_req_start               ),
    .enqueue_req_last           (   enqueue_req_last                ),
    .enqueue_req_data           (   enqueue_req_data                ),
    .enqueue_req_ready          (   enqueue_req_ready               ),

    .egress_valid               (   bypass_egress_valid             ),
    .egress_head                (   bypass_egress_head              ),
    .egress_data                (   bypass_egress_data              ),
    .egress_start               (   bypass_egress_start             ),
    .egress_last                (   bypass_egress_last              ),
    .egress_ready               (   bypass_egress_ready             )
);

OoOStation_Thread_2 #(
    .ID                         (   ID                              ),

    .TAG_NUM                     (   TAG_NUM                         ),
    .TAG_NUM_LOG                 (   TAG_NUM_LOG                     ),

    .RESOURCE_CMD_HEAD_WIDTH     (   RESOURCE_CMD_HEAD_WIDTH         ),
    .RESOURCE_CMD_DATA_WIDTH     (   RESOURCE_CMD_DATA_WIDTH         ),
    .RESOURCE_RESP_HEAD_WIDTH    (   RESOURCE_RESP_HEAD_WIDTH        ),
    .RESOURCE_RESP_DATA_WIDTH    (   RESOURCE_RESP_DATA_WIDTH        ),

    .SLOT_NUM                    (   SLOT_NUM                        ),
    .QUEUE_NUM                   (   QUEUE_NUM                       ),
    .SLOT_NUM_LOG                (   SLOT_NUM_LOG                    ),
    .QUEUE_NUM_LOG               (   QUEUE_NUM_LOG                   ),

    .OOO_CMD_HEAD_WIDTH          (   OOO_CMD_HEAD_WIDTH              ),
    .OOO_CMD_DATA_WIDTH          (   OOO_CMD_DATA_WIDTH              ),
    .OOO_RESP_HEAD_WIDTH         (   OOO_RESP_HEAD_WIDTH             ),
    .OOO_RESP_DATA_WIDTH         (   OOO_RESP_DATA_WIDTH             ),

    .INGRESS_HEAD_WIDTH          (   INGRESS_HEAD_WIDTH              ),
    .INGRESS_DATA_WIDTH          (   INGRESS_DATA_WIDTH              ),

    .SLOT_WIDTH                  (   SLOT_WIDTH                      ),

    .EGRESS_HEAD_WIDTH           (   EGRESS_HEAD_WIDTH               ),
    .EGRESS_DATA_WIDTH           (   EGRESS_DATA_WIDTH               )
)
OoOStation_Thread_2_Inst
(
    .clk                        (   clk                             ),
    .rst                        (   rst                             ),

    .resource_resp_valid        (   resource_resp_valid             ),
    .resource_resp_head         (   resource_resp_head              ),
    .resource_resp_data         (   resource_resp_data              ),
    .resource_resp_start        (   resource_resp_start             ),
    .resource_resp_last         (   resource_resp_last              ),
    .resource_resp_ready        (   resource_resp_ready             ),

    .get_req_valid              (   get_req_valid                   ),
    .get_req_head               (   get_req_head                    ),
    .get_req_ready              (   get_req_ready                   ),
            
    .get_resp_valid             (   get_resp_valid                  ),
    .get_resp_empty             (   get_resp_empty                  ),
    .get_resp_data              (   get_resp_data                   ),
    .get_resp_ready             (   get_resp_ready                  ),

    .dequeue_req_valid          (   dequeue_req_valid               ),
    .dequeue_req_head           (   dequeue_req_head                ),
    .dequeue_req_ready          (   dequeue_req_ready               ),
    
    .dequeue_resp_valid         (   dequeue_resp_valid              ),
    .dequeue_resp_head          (   dequeue_resp_head               ),
    .dequeue_resp_start         (   dequeue_resp_start              ),
    .dequeue_resp_last          (   dequeue_resp_last               ),
    .dequeue_resp_data          (   dequeue_resp_data               ),
    .dequeue_resp_ready         (   dequeue_resp_ready              ),

    .reorder_buffer_wea         (   reorder_buffer_wea              ),
    .reorder_buffer_addra       (   reorder_buffer_addra            ),
    .reorder_buffer_dina        (   reorder_buffer_dina             ),

    .reorder_buffer_addrb       (   reorder_buffer_addrb            ),
    .reorder_buffer_doutb       (   reorder_buffer_doutb            ),

    .tag_fifo_wr_en             (   tag_fifo_wr_en                  ),
    .tag_fifo_din               (   tag_fifo_din                    ),
    .tag_fifo_prog_full         (   tag_fifo_prog_full              ), 

    .tag_mapping_addrb          (   tag_mapping_addrb               ),
    .tag_mapping_doutb          (   tag_mapping_doutb               ),

    .egress_valid               (   normal_egress_valid             ),
    .egress_head                (   normal_egress_head              ),
    .egress_data                (   normal_egress_data              ),
    .egress_start               (   normal_egress_start             ),
    .egress_last                (   normal_egress_last              ),
    .egress_ready               (   normal_egress_ready             )
);

OoOStation_Thread_3 #(
    .ID                         (   ID                              ),

    .TAG_NUM                     (   TAG_NUM                         ),
    .TAG_NUM_LOG                 (   TAG_NUM_LOG                     ),

    .RESOURCE_CMD_HEAD_WIDTH     (   RESOURCE_CMD_HEAD_WIDTH         ),
    .RESOURCE_CMD_DATA_WIDTH     (   RESOURCE_CMD_DATA_WIDTH         ),
    .RESOURCE_RESP_HEAD_WIDTH    (   RESOURCE_RESP_HEAD_WIDTH        ),
    .RESOURCE_RESP_DATA_WIDTH    (   RESOURCE_RESP_DATA_WIDTH        ),

    .SLOT_NUM                    (   SLOT_NUM                        ),
    .QUEUE_NUM                   (   QUEUE_NUM                       ),
    .SLOT_NUM_LOG                (   SLOT_NUM_LOG                    ),
    .QUEUE_NUM_LOG               (   QUEUE_NUM_LOG                   ),

    .OOO_CMD_HEAD_WIDTH          (   OOO_CMD_HEAD_WIDTH              ),
    .OOO_CMD_DATA_WIDTH          (   OOO_CMD_DATA_WIDTH              ),
    .OOO_RESP_HEAD_WIDTH         (   OOO_RESP_HEAD_WIDTH             ),
    .OOO_RESP_DATA_WIDTH         (   OOO_RESP_DATA_WIDTH             ),

    .INGRESS_HEAD_WIDTH          (   INGRESS_HEAD_WIDTH              ),
    .INGRESS_DATA_WIDTH          (   INGRESS_DATA_WIDTH              ),

    .SLOT_WIDTH                  (   SLOT_WIDTH                      ),

    .EGRESS_HEAD_WIDTH           (   EGRESS_HEAD_WIDTH               ),
    .EGRESS_DATA_WIDTH           (   EGRESS_DATA_WIDTH               )
)
OoOStation_Thread_3_Inst
(
    .clk                        (   clk                             ),
    .rst                        (   rst                             ),

    .bypass_egress_valid        (   bypass_egress_valid             ),
    .bypass_egress_head         (   bypass_egress_head              ),
    .bypass_egress_data         (   bypass_egress_data              ),
    .bypass_egress_start        (   bypass_egress_start             ),
    .bypass_egress_last         (   bypass_egress_last              ),
    .bypass_egress_ready        (   bypass_egress_ready             ),

    .normal_egress_valid        (   normal_egress_valid             ),
    .normal_egress_head         (   normal_egress_head              ),
    .normal_egress_data         (   normal_egress_data              ),
    .normal_egress_start        (   normal_egress_start             ),
    .normal_egress_last         (   normal_egress_last              ),
    .normal_egress_ready        (   normal_egress_ready             ),

    .egress_valid               (   egress_valid                    ),
    .egress_head                (   egress_head                     ),
    .egress_data                (   egress_data                     ),
    .egress_start               (   egress_start                    ),
    .egress_last                (   egress_last                     ),
    .egress_ready               (   egress_ready                    )
);

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
/*------------------------------------------- Variables Decode : End ------------------------------------------------*/

endmodule