/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ReqRecvCore
Author:     YangFan
Function:   1.Handle Network Request.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module ReqRecvCore
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
    input   wire                                                            ingress_pkt_valid,
    input   wire    [`PKT_META_BUS_WIDTH - 1 : 0]                           ingress_pkt_head,
    output  wire                                                            ingress_pkt_ready,

//Interface with OoOStation(For CxtMgt)
    output  wire                                                            fetch_cxt_ingress_valid,
    output  wire    [`RX_REQ_OOO_CXT_INGRESS_HEAD_WIDTH - 1 : 0]            fetch_cxt_ingress_head,
    output  wire    [`RX_REQ_OOO_CXT_INGRESS_DATA_WIDTH - 1 : 0]            fetch_cxt_ingress_data,
    output  wire                                                            fetch_cxt_ingress_start,
    output  wire                                                            fetch_cxt_ingress_last,
    input   wire                                                            fetch_cxt_ingress_ready,

    input   wire                                                            fetch_cxt_egress_valid,
    input   wire    [`RX_REQ_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0 ]            fetch_cxt_egress_head,
    input   wire    [`RX_REQ_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0 ]            fetch_cxt_egress_data,
    input   wire                                                            fetch_cxt_egress_start,
    input   wire                                                            fetch_cxt_egress_last,
    output  wire                                                            fetch_cxt_egress_ready,

//Interface with OoOStation(For MRMgt)
    output  wire                                                            fetch_mr_ingress_valid,
    output  wire    [`RX_REQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]             fetch_mr_ingress_head,
    output  wire    [`RX_REQ_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]             fetch_mr_ingress_data,
    output  wire                                                            fetch_mr_ingress_start,
    output  wire                                                            fetch_mr_ingress_last,
    input   wire                                                            fetch_mr_ingress_ready,

    input   wire                                                            fetch_mr_egress_valid,
    input   wire    [`RX_REQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]              fetch_mr_egress_head,
    input   wire    [`RX_REQ_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]              fetch_mr_egress_data,
    input   wire                                                            fetch_mr_egress_start,
    input   wire                                                            fetch_mr_egress_last,
    output  wire                                                            fetch_mr_egress_ready,

//Interface with RecvQueueMgt
    output  wire                                                            wqe_req_valid,
    output  wire    [`WQE_META_WIDTH - 1 : 0]                               wqe_req_head,
    output  wire                                                            wqe_req_start,
    output  wire                                                            wqe_req_last,
    input   wire                                                            wqe_req_ready,

    input   wire                                                            wqe_resp_valid,
    input   wire    [`WQE_META_WIDTH - 1 : 0]                               wqe_resp_head,
    input   wire    [`WQE_SEG_WIDTH - 1 : 0]                                wqe_resp_data,
    input   wire                                                            wqe_resp_start,
    input   wire                                                            wqe_resp_last,
    output  wire                                                            wqe_resp_ready,

//Interface with cache offset table
    output  wire                                                            cache_offset_wen,
    output  wire     [`QP_NUM_LOG - 1 : 0]                                  cache_offset_addr,
    output  wire     [`RQ_CACHE_SLOT_NUM_LOG - 1:0]                         cache_offset_din,
    input   wire    [`RQ_CACHE_SLOT_NUM_LOG - 1:0]                          cache_offset_dout,

//Interface with RQHeadRecord
    output  wire                                                            rq_offset_wen,
    output  wire     [`QP_NUM_LOG - 1 : 0]                                  rq_offset_addr,
    output  wire     [23:0]                                                 rq_offset_din,
    input   wire    [23:0]                                                  rq_offset_dout,

    output  wire                                                            RQ_cache_owned_wen,
    output  wire    [`RQ_CACHE_CELL_NUM_LOG - 1 : 0]                        RQ_cache_owned_addr,
    output  wire    [`QP_NUM_LOG - 1 : 0]                                   RQ_cache_owned_din,
    input   wire    [`QP_NUM_LOG - 1 : 0]                                   RQ_cache_owned_dout,

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

//Interface with Packet Buffer
    output  wire                                                            delete_req_valid,
    output  wire    [`MAX_DB_SLOT_NUM_LOG * 2 - 1 : 0]                      delete_req_head,
    input   wire                                                            delete_req_ready,
                    
    input   wire                                                            delete_resp_valid,
    input   wire                                                            delete_resp_start,
    input   wire                                                            delete_resp_last,
    input   wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     delete_resp_data,
    output  wire                                                            delete_resp_ready,

//DMA Write Interface
    output  wire                                                            scatter_req_wr_en,
    output  wire     [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]      scatter_req_din,
    input   wire                                                            scatter_req_prog_full,

    output  wire                                                            scatter_data_wr_en,
    output  wire     [`DMA_DATA_WIDTH - 1: 0]                               scatter_data_din,
    input   wire                                                            scatter_data_prog_full,

//DMA Read Interface
    output  wire                                                            gather_req_wr_en,
    output  wire     [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]      gather_req_din,
    input   wire                                                            gather_req_prog_full,
    
//Interface with RespTransCore
    output  wire                                                            net_resp_wen,
    output  wire    [`NET_REQ_META_WIDTH - 1 : 0]                           net_resp_din,
    input   wire                                                            net_resp_prog_full
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/

/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
ReqRecvCore_Thread_1 #(
    .INGRESS_CXT_HEAD_WIDTH                  (      INGRESS_CXT_HEAD_WIDTH          ),
    .INGRESS_CXT_DATA_WIDTH                  (      INGRESS_CXT_DATA_WIDTH          )
)
ReqRecvCore_Thread_1_Inst
(
    .clk                                    (       clk                             ),
    .rst                                    (       rst                             ),

    .ingress_pkt_valid                      (       ingress_pkt_valid               ),
    .ingress_pkt_head                       (       ingress_pkt_head                ),
    .ingress_pkt_ready                      (       ingress_pkt_ready               ),

    .fetch_cxt_ingress_valid                (       fetch_cxt_ingress_valid         ),
    .fetch_cxt_ingress_head                 (       fetch_cxt_ingress_head          ),
    .fetch_cxt_ingress_data                 (       fetch_cxt_ingress_data          ),
    .fetch_cxt_ingress_start                (       fetch_cxt_ingress_start         ),
    .fetch_cxt_ingress_last                 (       fetch_cxt_ingress_last          ),
    .fetch_cxt_ingress_ready                (       fetch_cxt_ingress_ready         )
);

ReqRecvCore_Thread_2 #(
    .INGRESS_MR_HEAD_WIDTH                  (       INGRESS_MR_HEAD_WIDTH           ),
    .INGRESS_MR_DATA_WIDTH                  (       INGRESS_MR_DATA_WIDTH           ),
    .EGRESS_CXT_HEAD_WIDTH                  (       EGRESS_CXT_HEAD_WIDTH           ),
    .EGRESS_CXT_DATA_WIDTH                  (       EGRESS_CXT_DATA_WIDTH           )
)
ReqRecvCore_Thread_2_Inst
(
    .clk                                    (       clk                             ),
    .rst                                    (       rst                             ),

    .fetch_cxt_egress_valid                 (       fetch_cxt_egress_valid          ),
    .fetch_cxt_egress_head                  (       fetch_cxt_egress_head           ),
    .fetch_cxt_egress_data                  (       fetch_cxt_egress_data           ),
    .fetch_cxt_egress_start                 (       fetch_cxt_egress_start          ),
    .fetch_cxt_egress_last                  (       fetch_cxt_egress_last           ),
    .fetch_cxt_egress_ready                 (       fetch_cxt_egress_ready          ),

    .fetch_mr_ingress_valid                 (       fetch_mr_ingress_valid          ),
    .fetch_mr_ingress_head                  (       fetch_mr_ingress_head           ),
    .fetch_mr_ingress_data                  (       fetch_mr_ingress_data           ),
    .fetch_mr_ingress_start                 (       fetch_mr_ingress_start          ),
    .fetch_mr_ingress_last                  (       fetch_mr_ingress_last           ),
    .fetch_mr_ingress_ready                 (       fetch_mr_ingress_ready          ),

    .wqe_req_valid                          (       wqe_req_valid                   ),
    .wqe_req_head                           (       wqe_req_head                    ),
    .wqe_req_start                          (       wqe_req_start                   ),
    .wqe_req_last                           (       wqe_req_last                    ),
    .wqe_req_ready                          (       wqe_req_ready                   ),

    .wqe_resp_valid                         (       wqe_resp_valid                  ),
    .wqe_resp_head                          (       wqe_resp_head                   ),
    .wqe_resp_data                          (       wqe_resp_data                   ),
    .wqe_resp_start                         (       wqe_resp_start                  ),
    .wqe_resp_last                          (       wqe_resp_last                   ),
    .wqe_resp_ready                         (       wqe_resp_ready                  ),

    .cache_offset_wen                       (       cache_offset_wen                ),
    .cache_offset_addr                      (       cache_offset_addr               ),
    .cache_offset_din                       (       cache_offset_din                ),
    .cache_offset_dout                      (       cache_offset_dout               ),

    .rq_offset_wen                          (       rq_offset_wen                   ),
    .rq_offset_addr                         (       rq_offset_addr                  ),
    .rq_offset_din                          (       rq_offset_din                   ),
    .rq_offset_dout                         (       rq_offset_dout                  ),

    .cache_owned_wen                        (           RQ_cache_owned_wen              ),
    .cache_owned_addr                       (           RQ_cache_owned_addr             ),
    .cache_owned_din                        (           RQ_cache_owned_din              ),
    .cache_owned_dout                       (           RQ_cache_owned_dout             ),

    .cq_req_valid                           (       cq_req_valid                    ),
    .cq_req_head                            (       cq_req_head                     ),
    .cq_req_ready                           (       cq_req_ready                    ),

    .cq_resp_valid                          (       cq_resp_valid                   ),
    .cq_resp_head                           (       cq_resp_head                    ),
    .cq_resp_ready                          (       cq_resp_ready                   ),

    .eq_req_valid                           (       eq_req_valid                    ),
    .eq_req_head                            (       eq_req_head                     ),
    .eq_req_ready                           (       eq_req_ready                    ),
 
    .eq_resp_valid                          (       eq_resp_valid                   ),
    .eq_resp_head                           (       eq_resp_head                    ),
    .eq_resp_ready                          (       eq_resp_ready                   )
);

ReqRecvCore_Thread_3
#(
    .EGRESS_MR_HEAD_WIDTH                   (       EGRESS_MR_HEAD_WIDTH            ),
    .EGRESS_MR_DATA_WIDTH                   (       EGRESS_MR_DATA_WIDTH            )
)
ReqRecvCore_Thread_3_Inst
(
    .clk                                    (       clk                             ),
    .rst                                    (       rst                             ),

    .fetch_mr_egress_valid                  (       fetch_mr_egress_valid           ),
    .fetch_mr_egress_head                   (       fetch_mr_egress_head            ),
    .fetch_mr_egress_data                   (       fetch_mr_egress_data            ),
    .fetch_mr_egress_start                  (       fetch_mr_egress_start           ),
    .fetch_mr_egress_last                   (       fetch_mr_egress_last            ),
    .fetch_mr_egress_ready                  (       fetch_mr_egress_ready           ),

    .delete_req_valid                       (       delete_req_valid                ),
    .delete_req_head                        (       delete_req_head                 ),
    .delete_req_ready                       (       delete_req_ready                ),
                    
    .delete_resp_valid                      (       delete_resp_valid               ),
    .delete_resp_start                      (       delete_resp_start               ),
    .delete_resp_last                       (       delete_resp_last                ),
    .delete_resp_data                       (       delete_resp_data                ),
    .delete_resp_ready                      (       delete_resp_ready               ),

    .scatter_req_wr_en                      (       scatter_req_wr_en               ),
    .scatter_req_din                        (       scatter_req_din                 ),
    .scatter_req_prog_full                  (       scatter_req_prog_full           ),

    .scatter_data_wr_en                     (       scatter_data_wr_en              ),
    .scatter_data_din                       (       scatter_data_din                ),
    .scatter_data_prog_full                 (       scatter_data_prog_full          ),

    .gather_req_wr_en                       (       gather_req_wr_en                ),
    .gather_req_din                         (       gather_req_din                  ),
    .gather_req_prog_full                   (       gather_req_prog_full            ),
    
    .net_resp_wen                           (       net_resp_wen                    ),
    .net_resp_din                           (       net_resp_din                    ),
    .net_resp_prog_full                     (       net_resp_prog_full              )
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
/*------------------------------------------- Variables Decode : End ----------------------------------------------***/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule