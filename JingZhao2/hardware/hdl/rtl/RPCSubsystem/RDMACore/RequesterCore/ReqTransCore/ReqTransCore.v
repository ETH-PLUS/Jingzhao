/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ReqTransCore
Author:     YangFan
Function:   1.Emit Sub-WQEs.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module ReqTransCore
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
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with WQEParser
    input   wire                                                            sub_wqe_valid,
    input   wire    [`WQE_META_WIDTH - 1 : 0]                               sub_wqe_meta,
    output  wire                                                            sub_wqe_ready,

//Interface with OoOStation(For CxtMgt)
    output  wire                                                            fetch_cxt_ingress_valid,
    output  wire    [`TX_REQ_OOO_CXT_INGRESS_HEAD_WIDTH - 1 : 0]            fetch_cxt_ingress_head,
    output  wire    [`TX_REQ_OOO_CXT_INGRESS_DATA_WIDTH - 1 : 0]            fetch_cxt_ingress_data,
    output  wire                                                            fetch_cxt_ingress_start,
    output  wire                                                            fetch_cxt_ingress_last,
    input   wire                                                            fetch_cxt_ingress_ready,

    input   wire                                                            fetch_cxt_egress_valid,
    input   wire    [`TX_REQ_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]             fetch_cxt_egress_head,
    input   wire    [`TX_REQ_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]             fetch_cxt_egress_data,
    input   wire                                                            fetch_cxt_egress_start,
    input   wire                                                            fetch_cxt_egress_last,
    output  wire                                                            fetch_cxt_egress_ready,

//Interface with OoOStation(For MRMgt)
    output  wire                                                           fetch_mr_ingress_valid,
    output  wire    [`TX_REQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]            fetch_mr_ingress_head,
    output  wire    [`TX_REQ_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]            fetch_mr_ingress_data,
    output  wire                                                           fetch_mr_ingress_start,
    output  wire                                                           fetch_mr_ingress_last,
    input   wire                                                           fetch_mr_ingress_ready,

    input   wire                                                           fetch_mr_egress_valid,
    input   wire    [`TX_REQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]             fetch_mr_egress_head,
    input   wire    [`TX_REQ_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]             fetch_mr_egress_data,
    input   wire                                                           fetch_mr_egress_start,
    input   wire                                                           fetch_mr_egress_last,
    output  wire                                                           fetch_mr_egress_ready,

//Interface with CompletionQueueMgt
    output  wire                                                            cq_req_valid,
    output  wire    [`CQ_REQ_HEAD_WIDTH - 1 : 0]                            cq_req_head,
    input   wire                                                            cq_req_ready,
     
    input   wire                                                            cq_resp_valid,
    input   wire    [`CQ_RESP_HEAD_WIDTH - 1 : 0]                           cq_resp_head,
    output  wire                                                            cq_resp_ready,

//Interface with EventQueueMgt
    output  wire                                                            eq_req_valid,
    output  wire    [`EQ_REQ_HEAD_WIDTH - 1 : 0]                            eq_req_head,
    input   wire                                                            eq_req_ready,
 
    input   wire                                                            eq_resp_valid,
    input   wire    [`EQ_RESP_HEAD_WIDTH - 1 : 0]                           eq_resp_head,
    output  wire                                                            eq_resp_ready,

//DMA Read Interface
    output  wire                                                            gather_req_wr_en,
    output  wire    [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]       gather_req_din,
    input   wire                                                            gather_req_prog_full,

//Interface with GatherData
    output  wire                                                            net_data_rd_en,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                               net_data_dout,
    input   wire                                                            net_data_empty,

//ScatterData Req Interface
    output  wire                                                            scatter_req_wen,
    output  wire     [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]      scatter_req_din,
    input   wire                                                            scatter_req_prog_full,

    output  wire                                                            scatter_data_wen,
    output  wire     [`DMA_DATA_WIDTH - 1 : 0]                              scatter_data_din,
    input   wire                                                            scatter_data_prog_full,

//Interface WQEBuffer
    output  wire                                                            enqueue_req_valid,
    output  wire    [`MAX_QP_NUM_LOG + `MAX_DMQ_SLOT_NUM_LOG - 1 : 0]       enqueue_req_head,
    output  wire    [`RC_WQE_BUFFER_SLOT_WIDTH - 1 : 0]                     enqueue_req_data,
    output  wire                                                            enqueue_req_start,
    output  wire                                                            enqueue_req_last,
    input   wire                                                            enqueue_req_ready,

//Interface with PacketBuffer
    output  wire                                                            insert_req_valid,
    output  wire                                                            insert_req_start,
    output  wire                                                            insert_req_last,
    output  wire   [`MAX_DB_SLOT_NUM_LOG - 1 : 0]                           insert_req_head,
    output  wire   [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                      insert_req_data,
    input   wire                                                            insert_req_ready,

    input   wire                                                            insert_resp_valid,
    input   wire   [`MAX_DB_SLOT_NUM_LOG - 1 : 0]                           insert_resp_data,

//Interface with TransportSubsystem
    output  wire                                                            egress_pkt_valid,
    output  wire    [`PKT_META_BUS_WIDTH - 1 : 0]                           egress_pkt_head,
    input   wire                                                            egress_pkt_ready
);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                                            net_req_wen;
wire    [`WQE_META_WIDTH - 1 : 0]                           net_req_din;
wire                                                            net_req_prog_full;

wire                                                            net_req_ren;
wire    [`WQE_META_WIDTH - 1 : 0]                           net_req_dout;
wire                                                            net_req_empty;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
ReqTransCore_Thread_1 #(
    .INGRESS_CXT_HEAD_WIDTH                 (   INGRESS_CXT_HEAD_WIDTH      ),
    .INGRESS_CXT_DATA_WIDTH                 (   INGRESS_CXT_DATA_WIDTH      )
)
ReqTransCore_Thread_1_Inst
(
    .clk                                    (   clk                         ),
    .rst                                    (   rst                         ),

    .sub_wqe_valid                          (   sub_wqe_valid               ),
    .sub_wqe_meta                           (   sub_wqe_meta                ),
    .sub_wqe_ready                          (   sub_wqe_ready               ),

    .fetch_cxt_ingress_valid                (   fetch_cxt_ingress_valid     ),
    .fetch_cxt_ingress_head                 (   fetch_cxt_ingress_head      ),
    .fetch_cxt_ingress_data                 (   fetch_cxt_ingress_data      ),
    .fetch_cxt_ingress_start                (   fetch_cxt_ingress_start     ),
    .fetch_cxt_ingress_last                 (   fetch_cxt_ingress_last      ),
    .fetch_cxt_ingress_ready                (   fetch_cxt_ingress_ready     )
);

ReqTransCore_Thread_2 #(
    .EGRESS_CXT_HEAD_WIDTH                  (   EGRESS_CXT_HEAD_WIDTH       ),
    .EGRESS_CXT_DATA_WIDTH                  (   EGRESS_CXT_DATA_WIDTH       ),


    .INGRESS_MR_HEAD_WIDTH                  (   INGRESS_MR_HEAD_WIDTH       ),
    .INGRESS_MR_DATA_WIDTH                  (   INGRESS_MR_DATA_WIDTH       )
)
ReqTransCore_Thread_2_Inst
(
    .clk                                    (   clk                         ),
    .rst                                    (   rst                         ),

    .fetch_cxt_egress_valid                 (   fetch_cxt_egress_valid      ),
    .fetch_cxt_egress_head                  (   fetch_cxt_egress_head       ),
    .fetch_cxt_egress_data                  (   fetch_cxt_egress_data       ),
    .fetch_cxt_egress_start                 (   fetch_cxt_egress_start      ),
    .fetch_cxt_egress_last                  (   fetch_cxt_egress_last       ),
    .fetch_cxt_egress_ready                 (   fetch_cxt_egress_ready      ),

    .fetch_mr_ingress_valid                 (   fetch_mr_ingress_valid      ),
    .fetch_mr_ingress_head                  (   fetch_mr_ingress_head       ),
    .fetch_mr_ingress_data                  (   fetch_mr_ingress_data       ),
    .fetch_mr_ingress_start                 (   fetch_mr_ingress_start      ),
    .fetch_mr_ingress_last                  (   fetch_mr_ingress_last       ),
    .fetch_mr_ingress_ready                 (   fetch_mr_ingress_ready      ),

    .cq_req_valid                           (   cq_req_valid                ),
    .cq_req_head                            (   cq_req_head                 ),
    .cq_req_ready                           (   cq_req_ready                ),

    .cq_resp_valid                          (   cq_resp_valid               ),
    .cq_resp_head                           (   cq_resp_head                ),
    .cq_resp_ready                          (   cq_resp_ready               ),

    .eq_req_valid                           (   eq_req_valid                ),
    .eq_req_head                            (   eq_req_head                 ),
    .eq_req_ready                           (   eq_req_ready                ),
 
    .eq_resp_valid                          (   eq_resp_valid               ),
    .eq_resp_head                           (   eq_resp_head                ),
    .eq_resp_ready                          (   eq_resp_ready               )
);

ReqTransCore_Thread_3 #(
    .EGRESS_MR_HEAD_WIDTH                   (   EGRESS_MR_HEAD_WIDTH        ),
    .EGRESS_MR_DATA_WIDTH                   (   EGRESS_MR_DATA_WIDTH        )
)
ReqTransCore_Thread_3_Inst
(
    .clk                                    (   clk                         ),
    .rst                                    (   rst                         ),

    .fetch_mr_egress_valid                  (   fetch_mr_egress_valid       ),
    .fetch_mr_egress_head                   (   fetch_mr_egress_head        ),
    .fetch_mr_egress_data                   (   fetch_mr_egress_data        ),
    .fetch_mr_egress_start                  (   fetch_mr_egress_start       ),
    .fetch_mr_egress_last                   (   fetch_mr_egress_last        ),
    .fetch_mr_egress_ready                  (   fetch_mr_egress_ready       ),

    .net_req_wen                            (   net_req_wen                 ),
    .net_req_din                            (   net_req_din                 ),
    .net_req_prog_full                      (   net_req_prog_full           ),

    .gather_req_wr_en                       (   gather_req_wr_en            ),
    .gather_req_din                         (   gather_req_din              ),
    .gather_req_prog_full                   (   gather_req_prog_full        )
);

ReqTransCore_Thread_4 ReqTransCore_Thread_4_Inst(
    .clk                                    (   clk                         ),
    .rst                                    (   rst                         ),

    .net_req_ren                            (   net_req_ren                 ),
    .net_req_dout                           (   net_req_dout                ),
    .net_req_empty                          (   net_req_empty               ),

    .net_data_rd_en                         (   net_data_rd_en              ),
    .net_data_dout                          (   net_data_dout               ),
    .net_data_empty                         (   net_data_empty              ),

    .scatter_req_wen                        (   scatter_req_wen             ),
    .scatter_req_din                        (   scatter_req_din             ),
    .scatter_req_prog_full                  (   scatter_req_prog_full       ),

    .scatter_data_wen                       (   scatter_data_wen            ),
    .scatter_data_din                       (   scatter_data_din            ),
    .scatter_data_prog_full                 (   scatter_data_prog_full      ),

    .enqueue_req_valid                      (   enqueue_req_valid           ),
    .enqueue_req_head                       (   enqueue_req_head            ),
    .enqueue_req_data                       (   enqueue_req_data            ),
    .enqueue_req_start                      (   enqueue_req_start           ),
    .enqueue_req_last                       (   enqueue_req_last            ),
    .enqueue_req_ready                      (   enqueue_req_ready           ),

    .insert_req_valid                       (   insert_req_valid            ),
    .insert_req_start                       (   insert_req_start            ),
    .insert_req_last                        (   insert_req_last             ),
    .insert_req_head                        (   insert_req_head             ),
    .insert_req_data                        (   insert_req_data             ),
    .insert_req_ready                       (   insert_req_ready            ),

    .insert_resp_valid                      (   insert_resp_valid           ),
    .insert_resp_data                       (   insert_resp_data            ),

    .egress_pkt_valid                       (   egress_pkt_valid            ),
    .egress_pkt_head                        (   egress_pkt_head             ),
    .egress_pkt_ready                       (   egress_pkt_ready            )
);

SyncFIFO_Template #(
    .FIFO_WIDTH     (       `WQE_META_WIDTH             ),
    .FIFO_DEPTH     (       32                          )
)
NetReqFIFO_Inst
(
    .clk            (       clk                     ),
    .rst            (       rst                     ),

    .wr_en          (       net_req_wen             ),
    .din            (       net_req_din             ),
    .prog_full      (       net_req_prog_full       ),
    
    .rd_en          (       net_req_ren             ),
    .dout           (       net_req_dout            ),
    .empty          (       net_req_empty           ),

    .data_count     (                               )                 
);

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
/*------------------------------------------- Variables Decode : End ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/

/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule