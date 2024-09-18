/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       RespRecvCore
Author:     YangFan
Function:   1.Handle response from network.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module RespRecvCore
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
    input   wire                                                        clk,
    input   wire                                                        rst,

//Interface with PacketDeparser
    input   wire                                                        ingress_pkt_valid,
    input   wire    [`PKT_META_BUS_WIDTH - 1 : 0]                       ingress_pkt_head,
    output  wire                                                        ingress_pkt_ready,

//Interface with OoOStation(For CxtMgt)
    output  wire                                                        fetch_cxt_ingress_valid,
    output  wire    [`RX_RESP_OOO_CXT_INGRESS_HEAD_WIDTH - 1 : 0]       fetch_cxt_ingress_head,
    output  wire    [`RX_RESP_OOO_CXT_INGRESS_DATA_WIDTH - 1 : 0]       fetch_cxt_ingress_data,
    output  wire                                                        fetch_cxt_ingress_start,
    output  wire                                                        fetch_cxt_ingress_last,
    input   wire                                                        fetch_cxt_ingress_ready,

    input   wire                                                        fetch_cxt_egress_valid,
    input   wire    [`RX_RESP_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]        fetch_cxt_egress_head,
    input   wire    [`RX_RESP_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]        fetch_cxt_egress_data,
    input   wire                                                        fetch_cxt_egress_start,
    input   wire                                                        fetch_cxt_egress_last,
    output  wire                                                        fetch_cxt_egress_ready,

//Interface with OoOStation(For MRMgt)
    output  wire                                                        fetch_mr_ingress_valid,
    output  wire    [`RX_RESP_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]        fetch_mr_ingress_head,
    output  wire    [`RX_RESP_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]        fetch_mr_ingress_data,
    output  wire                                                        fetch_mr_ingress_start,
    output  wire                                                        fetch_mr_ingress_last,
    input   wire                                                        fetch_mr_ingress_ready,

    input   wire                                                        fetch_mr_egress_valid,
    input   wire    [`RX_RESP_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]         fetch_mr_egress_head,
    input   wire    [`RX_RESP_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]         fetch_mr_egress_data,
    input   wire                                                        fetch_mr_egress_start,
    input   wire                                                        fetch_mr_egress_last,
    output  wire                                                        fetch_mr_egress_ready,

//Interface with WQEBuffer
    output  wire                                                        dequeue_req_valid,
    output  wire    [`QP_NUM_LOG + `WQE_BUFFER_SLOT_NUM_LOG - 1 : 0]    dequeue_req_head,
    input   wire                                                        dequeue_req_ready,

    input   wire                                                        dequeue_resp_valid,
    input   wire    [`QP_NUM_LOG + `WQE_BUFFER_SLOT_NUM_LOG - 1 : 0]    dequeue_resp_head,
    input   wire                                                        dequeue_resp_start,
    input   wire                                                        dequeue_resp_last,
    output  wire                                                        dequeue_resp_ready,
    input   wire    [`RC_WQE_BUFFER_SLOT_WIDTH - 1 : 0]                    dequeue_resp_data,

//Interface with CompletionQueueMgt
    output  wire                                                        cq_req_valid,
    output  wire    [`CQ_REQ_HEAD_WIDTH - 1 : 0]                        cq_req_head,
    input   wire                                                        cq_req_ready,
     
    input   wire                                                        cq_resp_valid,
    input   wire    [`CQ_RESP_HEAD_WIDTH - 1 : 0]                       cq_resp_head,
    output  wire                                                        cq_resp_ready,

//Interface with EventQueueMgt
    output  wire                                                        eq_req_valid,
    output  wire    [`EQ_REQ_HEAD_WIDTH - 1 : 0]                        eq_req_head,
    input   wire                                                        eq_req_ready,
 
    input   wire                                                        eq_resp_valid,
    input   wire    [`EQ_RESP_HEAD_WIDTH - 1 : 0]                       eq_resp_head,
    output  wire                                                        eq_resp_ready,

//ScatterData Req Interface
    output  wire                                                        scatter_req_wen,
    output  wire    [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]   scatter_req_din,
    input   wire                                                        scatter_req_prog_full,

    output  wire                                                        scatter_data_wen,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                           scatter_data_din,
    input   wire                                                        scatter_data_prog_full,

//Interface with PacketBuffer
    output  wire                                                        delete_req_valid,
    output  wire    [`RECV_BUFFER_SLOT_NUM_LOG * 2 - 1 : 0]             delete_req_head,
    input   wire                                                        delete_req_ready,
                    
    input   wire                                                        delete_resp_valid,
    input   wire                                                        delete_resp_start,
    input   wire                                                        delete_resp_last,
    input   wire    [`RECV_BUFFER_SLOT_WIDTH - 1 : 0]                   delete_resp_data,
    output  wire                                                        delete_resp_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
RespRecvCore_Thread_1 #(
    .INGRESS_CXT_HEAD_WIDTH         (       INGRESS_CXT_HEAD_WIDTH      ),
    .INGRESS_CXT_DATA_WIDTH         (       INGRESS_CXT_DATA_WIDTH      )
)
RespRecvCore_Thread_1_Inst
(
    .clk                            (       clk                         ),
    .rst                            (       rst                         ),

    .ingress_pkt_valid              (       ingress_pkt_valid           ),
    .ingress_pkt_head               (       ingress_pkt_head            ),
    .ingress_pkt_ready              (       ingress_pkt_ready           ),

    .fetch_cxt_ingress_valid        (       fetch_cxt_ingress_valid     ),
    .fetch_cxt_ingress_head         (       fetch_cxt_ingress_head      ),
    .fetch_cxt_ingress_data         (       fetch_cxt_ingress_data      ),
    .fetch_cxt_ingress_start        (       fetch_cxt_ingress_start     ),
    .fetch_cxt_ingress_last         (       fetch_cxt_ingress_last      ),
    .fetch_cxt_ingress_ready        (       fetch_cxt_ingress_ready     )
);

RespRecvCore_Thread_2 #(
    .INGRESS_MR_HEAD_WIDTH          (       INGRESS_MR_HEAD_WIDTH       ),
    .INGRESS_MR_DATA_WIDTH          (       INGRESS_MR_DATA_WIDTH       ),
    .EGRESS_CXT_HEAD_WIDTH          (       EGRESS_CXT_HEAD_WIDTH       ),
    .EGRESS_CXT_DATA_WIDTH          (       EGRESS_CXT_DATA_WIDTH       )
)
RespRecvCore_Thread_2_Inst
(
    .clk                            (       clk                         ),
    .rst                            (       rst                         ),

    .fetch_cxt_egress_valid         (       fetch_cxt_egress_valid      ),
    .fetch_cxt_egress_head          (       fetch_cxt_egress_head       ),
    .fetch_cxt_egress_data          (       fetch_cxt_egress_data       ),
    .fetch_cxt_egress_start         (       fetch_cxt_egress_start      ),
    .fetch_cxt_egress_last          (       fetch_cxt_egress_last       ),
    .fetch_cxt_egress_ready         (       fetch_cxt_egress_ready      ),

    .fetch_mr_ingress_valid         (       fetch_mr_ingress_valid      ),
    .fetch_mr_ingress_head          (       fetch_mr_ingress_head       ),
    .fetch_mr_ingress_data          (       fetch_mr_ingress_data       ),
    .fetch_mr_ingress_start         (       fetch_mr_ingress_start      ),
    .fetch_mr_ingress_last          (       fetch_mr_ingress_last       ),
    .fetch_mr_ingress_ready         (       fetch_mr_ingress_ready      ),

    .dequeue_req_valid              (       dequeue_req_valid           ),
    .dequeue_req_head               (       dequeue_req_head            ),
    .dequeue_req_ready              (       dequeue_req_ready           ),

    .dequeue_resp_valid             (       dequeue_resp_valid          ),
    .dequeue_resp_head              (       dequeue_resp_head           ),
    .dequeue_resp_start             (       dequeue_resp_start          ),
    .dequeue_resp_last              (       dequeue_resp_last           ),
    .dequeue_resp_ready             (       dequeue_resp_ready          ),
    .dequeue_resp_data              (       dequeue_resp_data           ),

    .cq_req_valid                   (       cq_req_valid                ),
    .cq_req_head                    (       cq_req_head                 ),
    .cq_req_ready                   (       cq_req_ready                ),
     
    .cq_resp_valid                  (       cq_resp_valid               ),
    .cq_resp_head                   (       cq_resp_head                ),
    .cq_resp_ready                  (       cq_resp_ready               ),

    .eq_req_valid                   (       eq_req_valid                ),
    .eq_req_head                    (       eq_req_head                 ),
    .eq_req_ready                   (       eq_req_ready                ),
 
    .eq_resp_valid                  (       eq_resp_valid               ),
    .eq_resp_head                   (       eq_resp_head                ),
    .eq_resp_ready                  (       eq_resp_ready               )
);

RespRecvCore_Thread_3 #(
    .EGRESS_MR_HEAD_WIDTH           (       EGRESS_MR_HEAD_WIDTH        ),
    .EGRESS_MR_DATA_WIDTH           (       EGRESS_MR_DATA_WIDTH        )
)
RespRecvCore_Thread_3_Inst
(
    .clk                            (       clk                         ),
    .rst                            (       rst                         ),

    .fetch_mr_egress_valid          (       fetch_mr_egress_valid       ),
    .fetch_mr_egress_head           (       fetch_mr_egress_head        ),
    .fetch_mr_egress_data           (       fetch_mr_egress_data        ),
    .fetch_mr_egress_start          (       fetch_mr_egress_start       ),
    .fetch_mr_egress_last           (       fetch_mr_egress_last        ),
    .fetch_mr_egress_ready          (       fetch_mr_egress_ready       ),

    .scatter_req_wen                (       scatter_req_wen             ),
    .scatter_req_din                (       scatter_req_din             ),
    .scatter_req_prog_full          (       scatter_req_prog_full       ),

    .scatter_data_wen               (       scatter_data_wen            ),
    .scatter_data_din               (       scatter_data_din            ),
    .scatter_data_prog_full         (       scatter_data_prog_full      ),

    .delete_req_valid               (       delete_req_valid            ),
    .delete_req_head                (       delete_req_head             ),
    .delete_req_ready               (       delete_req_ready            ),
    
    .delete_resp_valid              (       delete_resp_valid           ),
    .delete_resp_start              (       delete_resp_start           ),
    .delete_resp_last               (       delete_resp_last            ),
    .delete_resp_data               (       delete_resp_data            ),
    .delete_resp_ready              (       delete_resp_ready           )
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
/*------------------------------------------- Variables Decode : End ------------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule