/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       CQMgt
Author:     YangFan
Function:   1.Manage SQ/RQ/CQ/EQ.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module QueueSubsystem
#(
    parameter   INGRESS_CXT_HEAD_WIDTH      =       128,
    parameter   INGRESS_CXT_DATA_WIDTH      =       256,
    parameter   EGRESS_CXT_HEAD_WIDTH       =       128,
    parameter   EGRESS_CXT_DATA_WIDTH       =       256,

    parameter   INGRESS_MR_HEAD_WIDTH       =       128,
    parameter   INGRESS_MR_DATA_WIDTH       =       256,
    parameter   EGRESS_MR_HEAD_WIDTH        =       128,
    parameter   EGRESS_MR_DATA_WIDTH        =       256
)
(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with PIO
    input   wire                                                            db_fifo_empty,
    input   wire            [63:0]                                          db_fifo_dout,
    output  wire                                                            db_fifo_rd_en,

//Interface with CxtMgt 
    output  wire                                                           SQ_fetch_cxt_ingress_valid,
    output  wire    [`SQ_OOO_CXT_INGRESS_HEAD_WIDTH - 1 : 0]               SQ_fetch_cxt_ingress_head, 
    output  wire    [`SQ_OOO_CXT_INGRESS_DATA_WIDTH - 1 : 0]               SQ_fetch_cxt_ingress_data, 
    output  wire                                                           SQ_fetch_cxt_ingress_start,
    output  wire                                                           SQ_fetch_cxt_ingress_last,
    input   wire                                                           SQ_fetch_cxt_ingress_ready,

    input   wire                                                           SQ_fetch_cxt_egress_valid,
    input   wire    [`SQ_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]                SQ_fetch_cxt_egress_head,  
    input   wire    [`SQ_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]                SQ_fetch_cxt_egress_data,
    input   wire                                                           SQ_fetch_cxt_egress_start,
    input   wire                                                           SQ_fetch_cxt_egress_last,
    output  wire                                                           SQ_fetch_cxt_egress_ready,

//Interface with MRMgt    
    output  wire                                                           SQ_fetch_mr_ingress_valid,
    output  wire    [`SQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]                SQ_fetch_mr_ingress_head, 
    output  wire    [`SQ_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]                SQ_fetch_mr_ingress_data,
    output  wire                                                           SQ_fetch_mr_ingress_start,
    output  wire                                                           SQ_fetch_mr_ingress_last,
    input   wire                                                           SQ_fetch_mr_ingress_ready,

    input   wire                                                           SQ_fetch_mr_egress_valid,
    input   wire    [`SQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]                 SQ_fetch_mr_egress_head,
    input   wire    [`SQ_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]                 SQ_fetch_mr_egress_data,
    input   wire                                                           SQ_fetch_mr_egress_start,
    input   wire                                                           SQ_fetch_mr_egress_last,
    output  wire                                                           SQ_fetch_mr_egress_ready,


//Interface with DMA Read Channel
    output  wire                                                            SQ_dma_rd_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                               SQ_dma_rd_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                               SQ_dma_rd_req_data,
    output  wire                                                            SQ_dma_rd_req_last,
    input   wire                                                            SQ_dma_rd_req_ready,
                        
    input   wire                                                            SQ_dma_rd_rsp_valid,
    input   wire    [`DMA_HEAD_WIDTH - 1 : 0]                               SQ_dma_rd_rsp_head,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                               SQ_dma_rd_rsp_data,
    input   wire                                                            SQ_dma_rd_rsp_last,
    output  wire                                                            SQ_dma_rd_rsp_ready,

//Interface with RDMACore
    output  wire                                                            sub_wqe_valid,
    output  wire    [`WQE_META_WIDTH - 1 : 0]                               sub_wqe_meta,
    input   wire                                                            sub_wqe_ready,

//Interface with DynamicBuffer(Payload Buffer)
    output  wire                                                            insert_req_valid,
    output  wire                                                            insert_req_start,
    output  wire                                                            insert_req_last,
    output  wire    [`INLINE_PAYLOAD_BUFFER_SLOT_NUM_LOG - 1 : 0]           insert_req_head,
    output  wire    [`INLINE_PAYLOAD_BUFFER_SLOT_WIDTH - 1 : 0]             insert_req_data,
    input   wire                                                            insert_req_ready,

    input   wire                                                            insert_resp_valid,
    input   wire    [`INLINE_PAYLOAD_BUFFER_SLOT_WIDTH - 1 : 0]             insert_resp_data,


//Interface with RDMACore/ReqRecvCore
    input   wire                                                            RQ_wqe_req_valid,
    input   wire    [`WQE_META_WIDTH - 1 : 0]                               RQ_wqe_req_head,
    input   wire                                                            RQ_wqe_req_start,
    input   wire                                                            RQ_wqe_req_last,
    output  wire                                                            RQ_wqe_req_ready,

    output  wire                                                            RQ_wqe_resp_valid,
    output  wire    [`WQE_META_WIDTH - 1 : 0]                               RQ_wqe_resp_head,
    output  wire    [`WQE_SEG_WIDTH - 1 : 0]                                RQ_wqe_resp_data,
    output  wire                                                            RQ_wqe_resp_start,
    output  wire                                                            RQ_wqe_resp_last,
    input   wire                                                            RQ_wqe_resp_ready,

    input   wire                                                            RQ_cache_offset_wen,
    input   wire    [`QP_NUM_LOG - 1 : 0]                                   RQ_cache_offset_addr,
    input   wire    [`RQ_CACHE_SLOT_NUM_LOG - 1:0]                          RQ_cache_offset_din,
    output  wire    [`RQ_CACHE_SLOT_NUM_LOG - 1:0]                          RQ_cache_offset_dout,

    input   wire                                                            RQ_offset_wen,
    input   wire    [`QP_NUM_LOG - 1 : 0]                                   RQ_offset_addr,
    input   wire    [23:0]                                                  RQ_offset_din,
    output  wire    [23:0]                                                  RQ_offset_dout,

    input   wire                                                            RQ_cache_owned_wen,
    input   wire    [`RQ_CACHE_CELL_NUM_LOG - 1 : 0]                        RQ_cache_owned_addr,
    input   wire    [`QP_NUM_LOG - 1 : 0]                                   RQ_cache_owned_din,
    output  wire    [`QP_NUM_LOG - 1 : 0]                                   RQ_cache_owned_dout,

//Interface with MRMgt
    output  wire                                                           RQ_fetch_mr_ingress_valid,
    output  wire    [`RQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]                RQ_fetch_mr_ingress_head, 
    output  wire    [`RQ_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]                RQ_fetch_mr_ingress_data,
    output  wire                                                           RQ_fetch_mr_ingress_start,
    output  wire                                                           RQ_fetch_mr_ingress_last,
    input   wire                                                           RQ_fetch_mr_ingress_ready,

    input   wire                                                           RQ_fetch_mr_egress_valid,
    input   wire    [`RQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]                 RQ_fetch_mr_egress_head,
    input   wire    [`RQ_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]                 RQ_fetch_mr_egress_data,
    input   wire                                                           RQ_fetch_mr_egress_start,
    input   wire                                                           RQ_fetch_mr_egress_last,
    output  wire                                                           RQ_fetch_mr_egress_ready,

//Interface with DMA Read Channel
    output  wire                                                            RQ_dma_rd_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                               RQ_dma_rd_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                               RQ_dma_rd_req_data,
    output  wire                                                            RQ_dma_rd_req_last,
    input   wire                                                            RQ_dma_rd_req_ready,
                        
    input   wire                                                            RQ_dma_rd_rsp_valid,
    input   wire    [`DMA_HEAD_WIDTH - 1 : 0]                               RQ_dma_rd_rsp_head,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                               RQ_dma_rd_rsp_data,
    input   wire                                                            RQ_dma_rd_rsp_last,
    output  wire                                                            RQ_dma_rd_rsp_ready,

//Interface with ReqTransCore
    input   wire                                                            TX_REQ_cq_req_valid,
    input   wire    [`CQ_REQ_HEAD_WIDTH - 1 : 0]                            TX_REQ_cq_req_head,
    output  wire                                                            TX_REQ_cq_req_ready,
     
    output  wire                                                            TX_REQ_cq_resp_valid,
    output  wire    [`CQ_RESP_HEAD_WIDTH - 1 : 0]                           TX_REQ_cq_resp_head,
    input   wire                                                            TX_REQ_cq_resp_ready,

//Interface with ReqRecvCore
    input   wire                                                            RX_REQ_cq_req_valid,
    input   wire   [`CQ_REQ_HEAD_WIDTH - 1 : 0]                             RX_REQ_cq_req_head,
    output  wire                                                            RX_REQ_cq_req_ready,
     
    output  wire                                                            RX_REQ_cq_resp_valid,
    output  wire    [`CQ_RESP_HEAD_WIDTH - 1 : 0]                           RX_REQ_cq_resp_head,
    input   wire                                                            RX_REQ_cq_resp_ready,

//Interface with RespRecvCore
    input   wire                                                            RX_RESP_cq_req_valid,
    input   wire   [`CQ_REQ_HEAD_WIDTH - 1 : 0]                             RX_RESP_cq_req_head,
    output  wire                                                            RX_RESP_cq_req_ready,
     
    output  wire                                                            RX_RESP_cq_resp_valid,
    output  wire    [`CQ_RESP_HEAD_WIDTH - 1 : 0]                           RX_RESP_cq_resp_head,
    input   wire                                                            RX_RESP_cq_resp_ready,

//Interface with ReqTransCore
    input   wire                                                            TX_REQ_eq_req_valid,
    input   wire    [`EQ_REQ_HEAD_WIDTH - 1 : 0]                            TX_REQ_eq_req_head,
    output  wire                                                            TX_REQ_eq_req_ready,
     
    output  wire                                                            TX_REQ_eq_resp_valid,
    output  wire    [`EQ_RESP_HEAD_WIDTH - 1 : 0]                           TX_REQ_eq_resp_head,
    input   wire                                                            TX_REQ_eq_resp_ready,

//Interface with ReqRecvCore
    input   wire                                                            RX_REQ_eq_req_valid,
    input   wire    [`EQ_REQ_HEAD_WIDTH - 1 : 0]                            RX_REQ_eq_req_head,
    output  wire                                                            RX_REQ_eq_req_ready,
     
    output  wire                                                            RX_REQ_eq_resp_valid,
    output  wire    [`EQ_RESP_HEAD_WIDTH - 1 : 0]                           RX_REQ_eq_resp_head,
    input   wire                                                            RX_REQ_eq_resp_ready,

//Interface with RespRecvCore
    input   wire                                                            RX_RESP_eq_req_valid,
    input   wire    [`EQ_REQ_HEAD_WIDTH - 1 : 0]                            RX_RESP_eq_req_head,
    output  wire                                                            RX_RESP_eq_req_ready,
     
    output  wire                                                            RX_RESP_eq_resp_valid,
    output  wire    [`EQ_RESP_HEAD_WIDTH - 1 : 0]                           RX_RESP_eq_resp_head,
    input   wire                                                            RX_RESP_eq_resp_ready
);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
SQMgt 
#(
    .CACHE_SLOT_NUM             (       `SQ_CACHE_SLOT_NUM      ),
    .CACHE_CELL_NUM             (       `SQ_CACHE_CELL_NUM      ),

    .INGRESS_CXT_HEAD_WIDTH     (       128                     ),
    .INGRESS_CXT_DATA_WIDTH     (       256                     ),
    .EGRESS_CXT_HEAD_WIDTH      (       128                     ),
    .EGRESS_CXT_DATA_WIDTH      (       256                     ),

    .INGRESS_MR_HEAD_WIDTH      (       128                     ),
    .INGRESS_MR_DATA_WIDTH      (       256                     ),
    .EGRESS_MR_HEAD_WIDTH       (       128                     ),
    .EGRESS_MR_DATA_WIDTH       (       256                     )
)
SQMgt_Inst(
    .clk                                (           clk                             ),
    .rst                                (           rst                             ),

    .db_fifo_empty                      (           db_fifo_empty                   ),
    .db_fifo_dout                       (           db_fifo_dout                    ),
    .db_fifo_rd_en                      (           db_fifo_rd_en                   ),

    .fetch_cxt_ingress_valid            (           SQ_fetch_cxt_ingress_valid      ),
    .fetch_cxt_ingress_head             (           SQ_fetch_cxt_ingress_head       ), 
    .fetch_cxt_ingress_data             (           SQ_fetch_cxt_ingress_data       ), 
    .fetch_cxt_ingress_start            (           SQ_fetch_cxt_ingress_start      ),
    .fetch_cxt_ingress_last             (           SQ_fetch_cxt_ingress_last       ),
    .fetch_cxt_ingress_ready            (           SQ_fetch_cxt_ingress_ready      ),

    .fetch_cxt_egress_valid             (           SQ_fetch_cxt_egress_valid       ),
    .fetch_cxt_egress_head              (           SQ_fetch_cxt_egress_head        ),
    .fetch_cxt_egress_data              (           SQ_fetch_cxt_egress_data        ),
    .fetch_cxt_egress_start             (           SQ_fetch_cxt_egress_start       ),
    .fetch_cxt_egress_last              (           SQ_fetch_cxt_egress_last        ),
    .fetch_cxt_egress_ready             (           SQ_fetch_cxt_egress_ready       ),

    .fetch_mr_ingress_valid             (           SQ_fetch_mr_ingress_valid       ),
    .fetch_mr_ingress_head              (           SQ_fetch_mr_ingress_head        ),
    .fetch_mr_ingress_data              (           SQ_fetch_mr_ingress_data        ),
    .fetch_mr_ingress_start             (           SQ_fetch_mr_ingress_start       ),
    .fetch_mr_ingress_last              (           SQ_fetch_mr_ingress_last        ),
    .fetch_mr_ingress_ready             (           SQ_fetch_mr_ingress_ready       ),

    .fetch_mr_egress_valid              (           SQ_fetch_mr_egress_valid        ),
    .fetch_mr_egress_head               (           SQ_fetch_mr_egress_head         ),
    .fetch_mr_egress_data               (           SQ_fetch_mr_egress_data         ),
    .fetch_mr_egress_start              (           SQ_fetch_mr_egress_start        ),
    .fetch_mr_egress_last               (           SQ_fetch_mr_egress_last         ),
    .fetch_mr_egress_ready              (           SQ_fetch_mr_egress_ready        ),

    .SQ_dma_rd_req_valid                (           SQ_dma_rd_req_valid             ),
    .SQ_dma_rd_req_head                 (           SQ_dma_rd_req_head              ),
    .SQ_dma_rd_req_data                 (           SQ_dma_rd_req_data              ),
    .SQ_dma_rd_req_last                 (           SQ_dma_rd_req_last              ),
    .SQ_dma_rd_req_ready                (           SQ_dma_rd_req_ready             ),

    .SQ_dma_rd_rsp_valid               (           SQ_dma_rd_rsp_valid            ),
    .SQ_dma_rd_rsp_head                (           SQ_dma_rd_rsp_head             ),
    .SQ_dma_rd_rsp_data                (           SQ_dma_rd_rsp_data             ),
    .SQ_dma_rd_rsp_last                (           SQ_dma_rd_rsp_last             ),
    .SQ_dma_rd_rsp_ready               (           SQ_dma_rd_rsp_ready            ),

    .sub_wqe_valid                      (           sub_wqe_valid                   ),
    .sub_wqe_meta                       (           sub_wqe_meta                    ),
    .sub_wqe_ready                      (           sub_wqe_ready                   ),

    .insert_req_valid                   (           insert_req_valid                ),
    .insert_req_start                   (           insert_req_start                ),
    .insert_req_last                    (           insert_req_last                 ),
    .insert_req_head                    (           insert_req_head                 ),
    .insert_req_data                    (           insert_req_data                 ),
    .insert_req_ready                   (           insert_req_ready                ),

    .insert_resp_valid                  (           insert_resp_valid               ),
    .insert_resp_data                   (           insert_resp_data                )
);

RQMgt 
#(
    .CACHE_SLOT_NUM             (       `RQ_CACHE_SLOT_NUM      ),
    .CACHE_CELL_NUM             (       `RQ_CACHE_CELL_NUM      ),

    .INGRESS_CXT_HEAD_WIDTH     (       128                     ),
    .INGRESS_CXT_DATA_WIDTH     (       256                     ),
    .EGRESS_CXT_HEAD_WIDTH      (       128                     ),
    .EGRESS_CXT_DATA_WIDTH      (       256                     ),

    .INGRESS_MR_HEAD_WIDTH      (       128                     ),
    .INGRESS_MR_DATA_WIDTH      (       256                     ),
    .EGRESS_MR_HEAD_WIDTH       (       128                     ),
    .EGRESS_MR_DATA_WIDTH       (       256                     )
)
RQMgt_Inst(
    .clk                                (           clk                             ),
    .rst                                (           rst                             ),

    .wqe_req_valid                      (           RQ_wqe_req_valid              ),
    .wqe_req_head                       (           RQ_wqe_req_head               ),
    .wqe_req_start                      (           RQ_wqe_req_start              ),
    .wqe_req_last                       (           RQ_wqe_req_last               ),
    .wqe_req_ready                      (           RQ_wqe_req_ready              ),

    .wqe_resp_valid                     (           RQ_wqe_resp_valid             ),
    .wqe_resp_head                      (           RQ_wqe_resp_head              ),
    .wqe_resp_data                      (           RQ_wqe_resp_data              ),
    .wqe_resp_start                     (           RQ_wqe_resp_start             ),
    .wqe_resp_last                      (           RQ_wqe_resp_last              ),
    .wqe_resp_ready                     (           RQ_wqe_resp_ready             ),

    .RQ_cache_offset_wen                (           RQ_cache_offset_wen             ),
    .RQ_cache_offset_addr               (           RQ_cache_offset_addr            ),
    .RQ_cache_offset_din                (           RQ_cache_offset_din             ),
    .RQ_cache_offset_dout               (           RQ_cache_offset_dout            ),

    .RQ_offset_wen                      (           RQ_offset_wen                   ),
    .RQ_offset_addr                     (           RQ_offset_addr                  ),
    .RQ_offset_din                      (           RQ_offset_din                   ),
    .RQ_offset_dout                     (           RQ_offset_dout                  ),

    .RQ_cache_owned_wen                 (           RQ_cache_owned_wen              ),
    .RQ_cache_owned_addr                (           RQ_cache_owned_addr             ),
    .RQ_cache_owned_din                 (           RQ_cache_owned_din              ),
    .RQ_cache_owned_dout                (           RQ_cache_owned_dout             ),

    .fetch_mr_ingress_valid             (           RQ_fetch_mr_ingress_valid       ),
    .fetch_mr_ingress_head              (           RQ_fetch_mr_ingress_head        ),
    .fetch_mr_ingress_data              (           RQ_fetch_mr_ingress_data        ),
    .fetch_mr_ingress_start             (           RQ_fetch_mr_ingress_start       ),
    .fetch_mr_ingress_last              (           RQ_fetch_mr_ingress_last        ),
    .fetch_mr_ingress_ready             (           RQ_fetch_mr_ingress_ready       ),

    .fetch_mr_egress_valid              (           RQ_fetch_mr_egress_valid        ),
    .fetch_mr_egress_head               (           RQ_fetch_mr_egress_head         ),
    .fetch_mr_egress_data               (           RQ_fetch_mr_egress_data         ),
    .fetch_mr_egress_start              (           RQ_fetch_mr_egress_start        ),
    .fetch_mr_egress_last               (           RQ_fetch_mr_egress_last         ),
    .fetch_mr_egress_ready              (           RQ_fetch_mr_egress_ready        ),

    .RQ_dma_rd_req_valid                (           RQ_dma_rd_req_valid             ),
    .RQ_dma_rd_req_head                 (           RQ_dma_rd_req_head              ),
    .RQ_dma_rd_req_data                 (           RQ_dma_rd_req_data              ),
    .RQ_dma_rd_req_last                 (           RQ_dma_rd_req_last              ),
    .RQ_dma_rd_req_ready                (           RQ_dma_rd_req_ready             ),

    .RQ_dma_rd_rsp_valid               (           RQ_dma_rd_rsp_valid            ),
    .RQ_dma_rd_rsp_head                (           RQ_dma_rd_rsp_head             ),
    .RQ_dma_rd_rsp_data                (           RQ_dma_rd_rsp_data             ),
    .RQ_dma_rd_rsp_last                (           RQ_dma_rd_rsp_last             ),
    .RQ_dma_rd_rsp_ready               (           RQ_dma_rd_rsp_ready            )
);

CQMgt CQMgt_Inst(
    .clk                                (           clk                             ),
    .rst                                (           rst                             ),

    .TX_REQ_cq_req_valid                (           TX_REQ_cq_req_valid             ),
    .TX_REQ_cq_req_head                 (           TX_REQ_cq_req_head              ),
    .TX_REQ_cq_req_ready                (           TX_REQ_cq_req_ready             ),

    .TX_REQ_cq_resp_valid               (           TX_REQ_cq_resp_valid            ),
    .TX_REQ_cq_resp_head                (           TX_REQ_cq_resp_head             ),
    .TX_REQ_cq_resp_ready               (           TX_REQ_cq_resp_ready            ),

    .RX_REQ_cq_req_valid                (           RX_REQ_cq_req_valid             ),
    .RX_REQ_cq_req_head                 (           RX_REQ_cq_req_head              ),
    .RX_REQ_cq_req_ready                (           RX_REQ_cq_req_ready             ),

    .RX_REQ_cq_resp_valid               (           RX_REQ_cq_resp_valid            ),
    .RX_REQ_cq_resp_head                (           RX_REQ_cq_resp_head             ),
    .RX_REQ_cq_resp_ready               (           RX_REQ_cq_resp_ready            ),

    .RX_RESP_cq_req_valid                (           RX_RESP_cq_req_valid             ),
    .RX_RESP_cq_req_head                 (           RX_RESP_cq_req_head              ),
    .RX_RESP_cq_req_ready                (           RX_RESP_cq_req_ready             ),

    .RX_RESP_cq_resp_valid               (           RX_RESP_cq_resp_valid            ),
    .RX_RESP_cq_resp_head                (           RX_RESP_cq_resp_head             ),
    .RX_RESP_cq_resp_ready               (           RX_RESP_cq_resp_ready            )
);

EQMgt EQMgt_Inst(
    .clk                                (           clk                             ),
    .rst                                (           rst                             ),

    .TX_REQ_eq_req_valid                (           TX_REQ_eq_req_valid             ),
    .TX_REQ_eq_req_head                 (           TX_REQ_eq_req_head              ),
    .TX_REQ_eq_req_ready                (           TX_REQ_eq_req_ready             ),

    .TX_REQ_eq_resp_valid               (           TX_REQ_eq_resp_valid            ),
    .TX_REQ_eq_resp_head                (           TX_REQ_eq_resp_head             ),
    .TX_REQ_eq_resp_ready               (           TX_REQ_eq_resp_ready            ),

    .RX_REQ_eq_req_valid                (           RX_REQ_eq_req_valid             ),
    .RX_REQ_eq_req_head                 (           RX_REQ_eq_req_head              ),
    .RX_REQ_eq_req_ready                (           RX_REQ_eq_req_ready             ),

    .RX_REQ_eq_resp_valid               (           RX_REQ_eq_resp_valid            ),
    .RX_REQ_eq_resp_head                (           RX_REQ_eq_resp_head             ),
    .RX_REQ_eq_resp_ready               (           RX_REQ_eq_resp_ready            ),

    .RX_RESP_eq_req_valid                (           RX_RESP_eq_req_valid             ),
    .RX_RESP_eq_req_head                 (           RX_RESP_eq_req_head              ),
    .RX_RESP_eq_req_ready                (           RX_RESP_eq_req_ready             ),

    .RX_RESP_eq_resp_valid               (           RX_RESP_eq_resp_valid            ),
    .RX_RESP_eq_resp_head                (           RX_RESP_eq_resp_head             ),
    .RX_RESP_eq_resp_ready               (           RX_RESP_eq_resp_ready            )
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
/*------------------------------------------- Variables Decode : End ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/

/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule