/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       RequesterCore
Author:     YangFan
Function:   1.Requester.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module RequesterCore
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
    input   wire                                                            TX_REQ_sub_wqe_valid,
    input   wire    [`WQE_META_WIDTH - 1 : 0]                               TX_REQ_sub_wqe_meta,
    output  wire                                                            TX_REQ_sub_wqe_ready,

//Interface with OoOStation(For CxtMgt)
    output  wire                                                            TX_REQ_fetch_cxt_ingress_valid,
    output  wire    [`TX_REQ_OOO_CXT_INGRESS_HEAD_WIDTH - 1 : 0]            TX_REQ_fetch_cxt_ingress_head,
    output  wire    [`TX_REQ_OOO_CXT_INGRESS_DATA_WIDTH - 1 : 0]            TX_REQ_fetch_cxt_ingress_data,
    output  wire                                                            TX_REQ_fetch_cxt_ingress_start,
    output  wire                                                            TX_REQ_fetch_cxt_ingress_last,
    input   wire                                                            TX_REQ_fetch_cxt_ingress_ready,

    input   wire                                                            TX_REQ_fetch_cxt_egress_valid,
    input   wire    [`TX_REQ_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]             TX_REQ_fetch_cxt_egress_head,
    input   wire    [`TX_REQ_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]             TX_REQ_fetch_cxt_egress_data,
    input   wire                                                            TX_REQ_fetch_cxt_egress_start,
    input   wire                                                            TX_REQ_fetch_cxt_egress_last,
    output  wire                                                            TX_REQ_fetch_cxt_egress_ready,

//Interface with OoOStation(For MRMgt)
    output  wire                                                           TX_REQ_fetch_mr_ingress_valid,
    output  wire    [`TX_REQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]            TX_REQ_fetch_mr_ingress_head,
    output  wire    [`TX_REQ_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]            TX_REQ_fetch_mr_ingress_data,
    output  wire                                                           TX_REQ_fetch_mr_ingress_start,
    output  wire                                                           TX_REQ_fetch_mr_ingress_last,
    input   wire                                                           TX_REQ_fetch_mr_ingress_ready,

    input   wire                                                           TX_REQ_fetch_mr_egress_valid,
    input   wire    [`TX_REQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]             TX_REQ_fetch_mr_egress_head,
    input   wire    [`TX_REQ_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]             TX_REQ_fetch_mr_egress_data,
    input   wire                                                           TX_REQ_fetch_mr_egress_start,
    input   wire                                                           TX_REQ_fetch_mr_egress_last,
    output  wire                                                           TX_REQ_fetch_mr_egress_ready,

//Interface with CompletionQueueMgt
    output  wire                                                            TX_REQ_cq_req_valid,
    output  wire    [`CQ_REQ_HEAD_WIDTH - 1 : 0]                            TX_REQ_cq_req_head,
    input   wire                                                            TX_REQ_cq_req_ready,
     
    input   wire                                                            TX_REQ_cq_resp_valid,
    input   wire    [`CQ_RESP_HEAD_WIDTH - 1 : 0]                           TX_REQ_cq_resp_head,
    output  wire                                                            TX_REQ_cq_resp_ready,

//Interface with EventQueueMgt
    output  wire                                                            TX_REQ_eq_req_valid,
    output  wire    [`EQ_REQ_HEAD_WIDTH - 1 : 0]                            TX_REQ_eq_req_head,
    input   wire                                                            TX_REQ_eq_req_ready,
 
    input   wire                                                            TX_REQ_eq_resp_valid,
    input   wire    [`EQ_RESP_HEAD_WIDTH - 1 : 0]                           TX_REQ_eq_resp_head,
    output  wire                                                            TX_REQ_eq_resp_ready,

//DMA Read Interface
    output  wire                                                             TX_REQ_gather_req_wr_en,
    output  wire     [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]       TX_REQ_gather_req_din,
    input   wire                                                            TX_REQ_gather_req_prog_full,

//Interface with GatherData
    output  wire                                                            TX_REQ_net_data_rd_en,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                               TX_REQ_net_data_dout,
    input   wire                                                            TX_REQ_net_data_empty,

//ScatterData Req Interface
    output  wire                                                             TX_REQ_scatter_req_wen,
    output  wire     [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]       TX_REQ_scatter_req_din,
    input   wire                                                            TX_REQ_scatter_req_prog_full,

    output  wire                                                             TX_REQ_scatter_data_wen,
    output  wire     [`DMA_DATA_WIDTH - 1 : 0]                               TX_REQ_scatter_data_din,
    input   wire                                                            TX_REQ_scatter_data_prog_full,

//Interface with PacketBuffer
    output  wire                                                            TX_REQ_insert_req_valid,
    output  wire                                                            TX_REQ_insert_req_start,
    output  wire                                                            TX_REQ_insert_req_last,
    output  wire    [`MAX_DB_SLOT_NUM_LOG - 1 : 0]                          TX_REQ_insert_req_head,
    output  wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     TX_REQ_insert_req_data,
    input   wire                                                            TX_REQ_insert_req_ready,

    input   wire                                                            TX_REQ_insert_resp_valid,
    input   wire    [`MAX_DB_SLOT_NUM_LOG - 1 : 0]                          TX_REQ_insert_resp_data,

//Interface with TransportSubsystem
    output  wire                                                            TX_REQ_egress_pkt_valid,
    output  wire    [`PKT_META_BUS_WIDTH - 1 : 0]                           TX_REQ_egress_pkt_head,
    input   wire                                                            TX_REQ_egress_pkt_ready,

//Interface with PacketDeparser
    input   wire                                                            RX_RESP_ingress_pkt_valid,
    input   wire    [`PKT_META_BUS_WIDTH - 1 : 0]                           RX_RESP_ingress_pkt_head,
    output  wire                                                            RX_RESP_ingress_pkt_ready,

//Interface with OoOStation(For CxtMgt)
    output  wire                                                        RX_RESP_fetch_cxt_ingress_valid,
    output  wire    [`RX_RESP_OOO_CXT_INGRESS_HEAD_WIDTH - 1 : 0]       RX_RESP_fetch_cxt_ingress_head,
    output  wire    [`RX_RESP_OOO_CXT_INGRESS_DATA_WIDTH - 1 : 0]       RX_RESP_fetch_cxt_ingress_data,
    output  wire                                                        RX_RESP_fetch_cxt_ingress_start,
    output  wire                                                        RX_RESP_fetch_cxt_ingress_last,
    input   wire                                                        RX_RESP_fetch_cxt_ingress_ready,

    input   wire                                                        RX_RESP_fetch_cxt_egress_valid,
    input   wire    [`RX_RESP_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]        RX_RESP_fetch_cxt_egress_head,
    input   wire    [`RX_RESP_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]        RX_RESP_fetch_cxt_egress_data,
    input   wire                                                        RX_RESP_fetch_cxt_egress_start,
    input   wire                                                        RX_RESP_fetch_cxt_egress_last,
    output  wire                                                        RX_RESP_fetch_cxt_egress_ready,

//Interface with OoOStation(For MRMgt)
    output  wire                                                        RX_RESP_fetch_mr_ingress_valid,
    output  wire    [`RX_RESP_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]        RX_RESP_fetch_mr_ingress_head,
    output  wire    [`RX_RESP_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]        RX_RESP_fetch_mr_ingress_data,
    output  wire                                                        RX_RESP_fetch_mr_ingress_start,
    output  wire                                                        RX_RESP_fetch_mr_ingress_last,
    input   wire                                                        RX_RESP_fetch_mr_ingress_ready,

    input   wire                                                        RX_RESP_fetch_mr_egress_valid,
    input   wire    [`RX_RESP_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]         RX_RESP_fetch_mr_egress_head,
    input   wire    [`RX_RESP_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]         RX_RESP_fetch_mr_egress_data,
    input   wire                                                        RX_RESP_fetch_mr_egress_start,
    input   wire                                                        RX_RESP_fetch_mr_egress_last,
    output  wire                                                        RX_RESP_fetch_mr_egress_ready,

//Interface with CompletionQueueMgt
    output  wire                                                            RX_RESP_cq_req_valid,
    output  wire    [`CQ_REQ_HEAD_WIDTH - 1 : 0]                            RX_RESP_cq_req_head,
    input   wire                                                            RX_RESP_cq_req_ready,
     
    input   wire                                                            RX_RESP_cq_resp_valid,
    input   wire    [`CQ_RESP_HEAD_WIDTH - 1 : 0]                           RX_RESP_cq_resp_head,
    output  wire                                                            RX_RESP_cq_resp_ready,

//Interface with EventQueueMgt
    output  wire                                                            RX_RESP_eq_req_valid,
    output  wire    [`EQ_REQ_HEAD_WIDTH - 1 : 0]                            RX_RESP_eq_req_head,
    input   wire                                                            RX_RESP_eq_req_ready,
 
    input   wire                                                            RX_RESP_eq_resp_valid,
    input   wire    [`EQ_RESP_HEAD_WIDTH - 1 : 0]                           RX_RESP_eq_resp_head,
    output  wire                                                            RX_RESP_eq_resp_ready,

//ScatterData Req Interface
    output  wire                                                             RX_RESP_scatter_req_wen,
    output  wire     [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]       RX_RESP_scatter_req_din,
    input   wire                                                            RX_RESP_scatter_req_prog_full,

    output  wire                                                             RX_RESP_scatter_data_wen,
    output  wire     [`DMA_DATA_WIDTH - 1 : 0]                               RX_RESP_scatter_data_din,
    input   wire                                                            RX_RESP_scatter_data_prog_full,

//Interface with PacketBuffer
    output  wire                                                            RX_RESP_delete_req_valid,
    output  wire    [`RECV_BUFFER_SLOT_NUM_LOG * 2 - 1 : 0]                 RX_RESP_delete_req_head,
    input   wire                                                            RX_RESP_delete_req_ready,
                    
    input   wire                                                            RX_RESP_delete_resp_valid,
    input   wire                                                            RX_RESP_delete_resp_start,
    input   wire                                                            RX_RESP_delete_resp_last,
    input   wire    [`RECV_BUFFER_SLOT_WIDTH - 1 : 0]                       RX_RESP_delete_resp_data,
    output  wire                                                            RX_RESP_delete_resp_ready
);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                                            wqe_enqueue_req_valid;
wire    [`MAX_QP_NUM_LOG + `MAX_DMQ_SLOT_NUM_LOG - 1 : 0]       wqe_enqueue_req_head;
wire    [`RC_WQE_BUFFER_SLOT_WIDTH - 1 : 0]                     wqe_enqueue_req_data;
wire                                                            wqe_enqueue_req_start;
wire                                                            wqe_enqueue_req_last;
wire                                                            wqe_enqueue_req_ready;

wire                                                            wqe_dequeue_req_valid;
wire    [`MAX_QP_NUM_LOG + `MAX_DMQ_SLOT_NUM_LOG - 1 : 0]       wqe_dequeue_req_head;
wire                                                            wqe_dequeue_req_ready;

wire                                                            wqe_dequeue_resp_valid;
wire    [`MAX_QP_NUM_LOG + `MAX_DMQ_SLOT_NUM_LOG - 1 : 0]       wqe_dequeue_resp_head;
wire                                                            wqe_dequeue_resp_start;
wire                                                            wqe_dequeue_resp_last;
wire                                                            wqe_dequeue_resp_ready;
wire    [`RC_WQE_BUFFER_SLOT_WIDTH - 1 : 0]                     wqe_dequeue_resp_data;

/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
ReqTransCore #(
    .INGRESS_CXT_HEAD_WIDTH                 (   INGRESS_CXT_HEAD_WIDTH      ),
    .INGRESS_CXT_DATA_WIDTH                 (   INGRESS_CXT_DATA_WIDTH      ),
    .EGRESS_CXT_HEAD_WIDTH                  (   EGRESS_CXT_HEAD_WIDTH       ),
    .EGRESS_CXT_DATA_WIDTH                  (   EGRESS_CXT_DATA_WIDTH       ),


    .INGRESS_MR_HEAD_WIDTH                  (   INGRESS_MR_HEAD_WIDTH       ),
    .INGRESS_MR_DATA_WIDTH                  (   INGRESS_MR_DATA_WIDTH       ),
    .EGRESS_MR_HEAD_WIDTH                   (   EGRESS_MR_HEAD_WIDTH        ),
    .EGRESS_MR_DATA_WIDTH                   (   EGRESS_MR_DATA_WIDTH        )
)
ReqTransCore_Inst
(
    .clk                                    (   clk                         ),
    .rst                                    (   rst                         ),

    .sub_wqe_valid                          (   TX_REQ_sub_wqe_valid               ),
    .sub_wqe_meta                           (   TX_REQ_sub_wqe_meta                ),
    .sub_wqe_ready                          (   TX_REQ_sub_wqe_ready               ),

    .fetch_cxt_ingress_valid                (   TX_REQ_fetch_cxt_ingress_valid ),
    .fetch_cxt_ingress_head                 (   TX_REQ_fetch_cxt_ingress_head  ),
    .fetch_cxt_ingress_data                 (   TX_REQ_fetch_cxt_ingress_data  ),
    .fetch_cxt_ingress_start                (   TX_REQ_fetch_cxt_ingress_start ),
    .fetch_cxt_ingress_last                 (   TX_REQ_fetch_cxt_ingress_last  ),
    .fetch_cxt_ingress_ready                (   TX_REQ_fetch_cxt_ingress_ready ),

    .fetch_cxt_egress_valid                 (   TX_REQ_fetch_cxt_egress_valid  ),
    .fetch_cxt_egress_head                  (   TX_REQ_fetch_cxt_egress_head   ),
    .fetch_cxt_egress_data                  (   TX_REQ_fetch_cxt_egress_data   ),
    .fetch_cxt_egress_start                 (   TX_REQ_fetch_cxt_egress_start  ),
    .fetch_cxt_egress_last                  (   TX_REQ_fetch_cxt_egress_last   ),
    .fetch_cxt_egress_ready                 (   TX_REQ_fetch_cxt_egress_ready  ),

    .fetch_mr_ingress_valid                 (   TX_REQ_fetch_mr_ingress_valid  ),
    .fetch_mr_ingress_head                  (   TX_REQ_fetch_mr_ingress_head   ),
    .fetch_mr_ingress_data                  (   TX_REQ_fetch_mr_ingress_data   ),
    .fetch_mr_ingress_start                 (   TX_REQ_fetch_mr_ingress_start  ),
    .fetch_mr_ingress_last                  (   TX_REQ_fetch_mr_ingress_last   ),
    .fetch_mr_ingress_ready                 (   TX_REQ_fetch_mr_ingress_ready  ),

    .fetch_mr_egress_valid                  (   TX_REQ_fetch_mr_egress_valid   ),
    .fetch_mr_egress_head                   (   TX_REQ_fetch_mr_egress_head    ),
    .fetch_mr_egress_data                   (   TX_REQ_fetch_mr_egress_data    ),
    .fetch_mr_egress_start                  (   TX_REQ_fetch_mr_egress_start   ),
    .fetch_mr_egress_last                   (   TX_REQ_fetch_mr_egress_last    ),
    .fetch_mr_egress_ready                  (   TX_REQ_fetch_mr_egress_ready   ),

    .cq_req_valid                           (   TX_REQ_cq_req_valid            ),
    .cq_req_head                            (   TX_REQ_cq_req_head             ),
    .cq_req_ready                           (   TX_REQ_cq_req_ready            ),

    .cq_resp_valid                          (   TX_REQ_cq_resp_valid           ),
    .cq_resp_head                           (   TX_REQ_cq_resp_head            ),
    .cq_resp_ready                          (   TX_REQ_cq_resp_ready           ),

    .eq_req_valid                           (   TX_REQ_eq_req_valid            ),
    .eq_req_head                            (   TX_REQ_eq_req_head             ),
    .eq_req_ready                           (   TX_REQ_eq_req_ready            ),
        
    .eq_resp_valid                          (   TX_REQ_eq_resp_valid           ),
    .eq_resp_head                           (   TX_REQ_eq_resp_head            ),
    .eq_resp_ready                          (   TX_REQ_eq_resp_ready           ),

    .gather_req_wr_en                       (   TX_REQ_gather_req_wr_en            ),
    .gather_req_din                         (   TX_REQ_gather_req_din              ),
    .gather_req_prog_full                   (   TX_REQ_gather_req_prog_full        ),

    .net_data_rd_en                         (   TX_REQ_net_data_rd_en              ),
    .net_data_dout                          (   TX_REQ_net_data_dout               ),
    .net_data_empty                         (   TX_REQ_net_data_empty              ),

    .scatter_req_wen                        (   TX_REQ_scatter_req_wen         ),
    .scatter_req_din                        (   TX_REQ_scatter_req_din         ),
    .scatter_req_prog_full                  (   TX_REQ_scatter_req_prog_full   ),

    .scatter_data_wen                       (   TX_REQ_scatter_data_wen        ),
    .scatter_data_din                       (   TX_REQ_scatter_data_din        ),
    .scatter_data_prog_full                 (   TX_REQ_scatter_data_prog_full  ),

    .enqueue_req_valid                      (   wqe_enqueue_req_valid           ),
    .enqueue_req_head                       (   wqe_enqueue_req_head            ),
    .enqueue_req_data                       (   wqe_enqueue_req_data            ),
    .enqueue_req_start                      (   wqe_enqueue_req_start           ),
    .enqueue_req_last                       (   wqe_enqueue_req_last            ),
    .enqueue_req_ready                      (   wqe_enqueue_req_ready           ),
    
    .insert_req_valid                       (   TX_REQ_insert_req_valid            ),
    .insert_req_start                       (   TX_REQ_insert_req_start            ),
    .insert_req_last                        (   TX_REQ_insert_req_last             ),
    .insert_req_head                        (   TX_REQ_insert_req_head             ),
    .insert_req_data                        (   TX_REQ_insert_req_data             ),
    .insert_req_ready                       (   TX_REQ_insert_req_ready            ),

    .insert_resp_valid                      (   TX_REQ_insert_resp_valid           ),
    .insert_resp_data                       (   TX_REQ_insert_resp_data            ),

    .egress_pkt_valid                       (   TX_REQ_egress_pkt_valid            ),
    .egress_pkt_head                        (   TX_REQ_egress_pkt_head             ),
    .egress_pkt_ready                       (   TX_REQ_egress_pkt_ready            )
);

RespRecvCore
#(
    .INGRESS_CXT_HEAD_WIDTH                 (   INGRESS_CXT_HEAD_WIDTH      ),
    .INGRESS_CXT_DATA_WIDTH                 (   INGRESS_CXT_DATA_WIDTH      ),
    .EGRESS_CXT_HEAD_WIDTH                  (   EGRESS_CXT_HEAD_WIDTH       ),
    .EGRESS_CXT_DATA_WIDTH                  (   EGRESS_CXT_DATA_WIDTH       ),

    .INGRESS_MR_HEAD_WIDTH                  (   INGRESS_MR_HEAD_WIDTH       ),
    .INGRESS_MR_DATA_WIDTH                  (   INGRESS_MR_DATA_WIDTH       ),
    .EGRESS_MR_HEAD_WIDTH                   (   EGRESS_MR_HEAD_WIDTH        ),
    .EGRESS_MR_DATA_WIDTH                   (   EGRESS_MR_DATA_WIDTH        )
)
RespRecvCore_Inst
(
    .clk                                    (   clk                         ),
    .rst                                    (   rst                         ),

    .ingress_pkt_valid                      (   RX_RESP_ingress_pkt_valid           ),
    .ingress_pkt_head                       (   RX_RESP_ingress_pkt_head            ),
    .ingress_pkt_ready                      (   RX_RESP_ingress_pkt_ready           ),

    .fetch_cxt_ingress_valid                (   RX_RESP_fetch_cxt_ingress_valid ),
    .fetch_cxt_ingress_head                 (   RX_RESP_fetch_cxt_ingress_head  ),
    .fetch_cxt_ingress_data                 (   RX_RESP_fetch_cxt_ingress_data  ),
    .fetch_cxt_ingress_start                (   RX_RESP_fetch_cxt_ingress_start ),
    .fetch_cxt_ingress_last                 (   RX_RESP_fetch_cxt_ingress_last  ),
    .fetch_cxt_ingress_ready                (   RX_RESP_fetch_cxt_ingress_ready ),

    .fetch_cxt_egress_valid                 (   RX_RESP_fetch_cxt_egress_valid  ),
    .fetch_cxt_egress_head                  (   RX_RESP_fetch_cxt_egress_head   ),
    .fetch_cxt_egress_data                  (   RX_RESP_fetch_cxt_egress_data   ),
    .fetch_cxt_egress_start                 (   RX_RESP_fetch_cxt_egress_start  ),
    .fetch_cxt_egress_last                  (   RX_RESP_fetch_cxt_egress_last   ),
    .fetch_cxt_egress_ready                 (   RX_RESP_fetch_cxt_egress_ready  ),

    .fetch_mr_ingress_valid                 (   RX_RESP_fetch_mr_ingress_valid  ),
    .fetch_mr_ingress_head                  (   RX_RESP_fetch_mr_ingress_head   ),
    .fetch_mr_ingress_data                  (   RX_RESP_fetch_mr_ingress_data   ),
    .fetch_mr_ingress_start                 (   RX_RESP_fetch_mr_ingress_start  ),
    .fetch_mr_ingress_last                  (   RX_RESP_fetch_mr_ingress_last   ),
    .fetch_mr_ingress_ready                 (   RX_RESP_fetch_mr_ingress_ready  ),

    .fetch_mr_egress_valid                  (   RX_RESP_fetch_mr_egress_valid   ),
    .fetch_mr_egress_head                   (   RX_RESP_fetch_mr_egress_head    ),
    .fetch_mr_egress_data                   (   RX_RESP_fetch_mr_egress_data    ),
    .fetch_mr_egress_start                  (   RX_RESP_fetch_mr_egress_start   ),
    .fetch_mr_egress_last                   (   RX_RESP_fetch_mr_egress_last    ),
    .fetch_mr_egress_ready                  (   RX_RESP_fetch_mr_egress_ready   ),

    .dequeue_req_valid                      (   wqe_dequeue_req_valid           ),
    .dequeue_req_head                       (   wqe_dequeue_req_head            ),
    .dequeue_req_ready                      (   wqe_dequeue_req_ready           ),

    .dequeue_resp_valid                     (   wqe_dequeue_resp_valid          ),
    .dequeue_resp_head                      (   wqe_dequeue_resp_head           ),
    .dequeue_resp_start                     (   wqe_dequeue_resp_start          ),
    .dequeue_resp_last                      (   wqe_dequeue_resp_last           ),
    .dequeue_resp_ready                     (   wqe_dequeue_resp_ready          ),
    .dequeue_resp_data                      (   wqe_dequeue_resp_data           ),

    .cq_req_valid                           (   RX_RESP_cq_req_valid            ),
    .cq_req_head                            (   RX_RESP_cq_req_head             ),
    .cq_req_ready                           (   RX_RESP_cq_req_ready            ),
     
    .cq_resp_valid                          (   RX_RESP_cq_resp_valid           ),
    .cq_resp_head                           (   RX_RESP_cq_resp_head            ),
    .cq_resp_ready                          (   RX_RESP_cq_resp_ready           ),

    .eq_req_valid                           (   RX_RESP_eq_req_valid            ),
    .eq_req_head                            (   RX_RESP_eq_req_head             ),
    .eq_req_ready                           (   RX_RESP_eq_req_ready            ),
 
    .eq_resp_valid                          (   RX_RESP_eq_resp_valid           ),
    .eq_resp_head                           (   RX_RESP_eq_resp_head            ),
    .eq_resp_ready                          (   RX_RESP_eq_resp_ready           ),

    .scatter_req_wen                        (   RX_RESP_scatter_req_wen         ),
    .scatter_req_din                        (   RX_RESP_scatter_req_din         ),
    .scatter_req_prog_full                  (   RX_RESP_scatter_req_prog_full   ),

    .scatter_data_wen                       (   RX_RESP_scatter_data_wen        ),
    .scatter_data_din                       (   RX_RESP_scatter_data_din        ),
    .scatter_data_prog_full                 (   RX_RESP_scatter_data_prog_full  ),

    .delete_req_valid                       (   RX_RESP_delete_req_valid            ),
    .delete_req_head                        (   RX_RESP_delete_req_head             ),
    .delete_req_ready                       (   RX_RESP_delete_req_ready            ),
                    
    .delete_resp_valid                      (   RX_RESP_delete_resp_valid           ),
    .delete_resp_start                      (   RX_RESP_delete_resp_start           ),
    .delete_resp_last                       (   RX_RESP_delete_resp_last            ),
    .delete_resp_data                       (   RX_RESP_delete_resp_data            ),
    .delete_resp_ready                      (   RX_RESP_delete_resp_ready           )
);

DynamicMultiQueue #(
    .SLOT_WIDTH                             (   `RC_WQE_BUFFER_SLOT_WIDTH   ),
    .SLOT_NUM                               (   `RC_WQE_BUFFER_SLOT_NUM     ),
    .QUEUE_NUM                              (   `QP_NUM                     )
)
WQEBuffer_Inst
(
    .clk                                    (   clk                         ),
    .rst                                    (   rst                         ),

    .ov_available_slot_num                  (                               ),

    .i_enqueue_req_valid                    (   wqe_enqueue_req_valid           ),
    .iv_enqueue_req_head                    (   wqe_enqueue_req_head            ),
    .iv_enqueue_req_data                    (   wqe_enqueue_req_data            ),
    .i_enqueue_req_start                    (   wqe_enqueue_req_start           ),
    .i_enqueue_req_last                     (   wqe_enqueue_req_last            ),
    .o_enqueue_req_ready                    (   wqe_enqueue_req_ready           ),

    .i_empty_req_valid                      (   'd0                         ),
    .iv_empty_req_head                      (   'd0                         ),
    .o_empty_req_ready                      (                               ),

    .o_empty_resp_valid                     (                               ),
    .ov_empty_resp_head                     (                               ),
    .i_empty_resp_ready                     (   'd0                         ),

    .i_dequeue_req_valid                    (   wqe_dequeue_req_valid           ),
    .iv_dequeue_req_head                    (   wqe_dequeue_req_head            ),
    .o_dequeue_req_ready                    (   wqe_dequeue_req_ready           ),

    .o_dequeue_resp_valid                   (   wqe_dequeue_resp_valid          ),
    .ov_dequeue_resp_head                   (   wqe_dequeue_resp_head           ),
    .o_dequeue_resp_start                   (   wqe_dequeue_resp_start          ),
    .o_dequeue_resp_last                    (   wqe_dequeue_resp_last           ),
    .i_dequeue_resp_ready                   (   wqe_dequeue_resp_ready          ),
    .ov_dequeue_resp_data                   (   wqe_dequeue_resp_data           ),

    .i_modify_head_req_valid                (   'd0                         ),
    .iv_modify_head_req_head                (   'd0                         ),
    .iv_modify_head_req_data                (   'd0                         ),
    .o_modify_head_req_ready                (                               ),

    .i_get_req_valid                        (   'd0                         ),
    .iv_get_req_head                        (   'd0                         ),
    .o_get_req_ready                        (                               ),

    .o_get_resp_valid                       (                               ),
    .ov_get_resp_head                       (                               ),
    .o_get_resp_start                       (                               ),
    .o_get_resp_last                        (                               ),
    .ov_get_resp_data                       (                               ),
    .o_get_resp_empty                       (                               ),
    .i_get_resp_ready                       (   'd0                         )
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
/*------------------------------------------- Variables Decode : End ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/

/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule