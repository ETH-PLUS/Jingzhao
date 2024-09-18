/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ReqRecvCore
Author:     YangFan
Function:   Responder.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module ResponderCore
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
    input   wire                                                            RX_REQ_ingress_pkt_valid,
    input   wire    [`PKT_META_BUS_WIDTH - 1 : 0]                           RX_REQ_ingress_pkt_head,
    output  wire                                                            RX_REQ_ingress_pkt_ready,

//Interface with OoOStation(For CxtMgt)
    output  wire                                                            RX_REQ_fetch_cxt_ingress_valid,
    output  wire    [`RX_REQ_OOO_CXT_INGRESS_HEAD_WIDTH - 1 : 0]            RX_REQ_fetch_cxt_ingress_head,
    output  wire    [`RX_REQ_OOO_CXT_INGRESS_DATA_WIDTH - 1 : 0]            RX_REQ_fetch_cxt_ingress_data,
    output  wire                                                            RX_REQ_fetch_cxt_ingress_start,
    output  wire                                                            RX_REQ_fetch_cxt_ingress_last,
    input   wire                                                            RX_REQ_fetch_cxt_ingress_ready,

    input   wire                                                            RX_REQ_fetch_cxt_egress_valid,
    input   wire    [`RX_REQ_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]             RX_REQ_fetch_cxt_egress_head,
    input   wire    [`RX_REQ_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]             RX_REQ_fetch_cxt_egress_data,
    input   wire                                                            RX_REQ_fetch_cxt_egress_start,
    input   wire                                                            RX_REQ_fetch_cxt_egress_last,
    output  wire                                                            RX_REQ_fetch_cxt_egress_ready,

//Interface with OoOStation(For MRMgt)
    output  wire                                                            RX_REQ_fetch_mr_ingress_valid,
    output  wire    [`RX_REQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]             RX_REQ_fetch_mr_ingress_head,
    output  wire    [`RX_REQ_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]             RX_REQ_fetch_mr_ingress_data,
    output  wire                                                            RX_REQ_fetch_mr_ingress_start,
    output  wire                                                            RX_REQ_fetch_mr_ingress_last,
    input   wire                                                            RX_REQ_fetch_mr_ingress_ready,

    input   wire                                                            RX_REQ_fetch_mr_egress_valid,
    input   wire    [`RX_REQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]              RX_REQ_fetch_mr_egress_head,
    input   wire    [`RX_REQ_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]              RX_REQ_fetch_mr_egress_data,
    input   wire                                                            RX_REQ_fetch_mr_egress_start,
    input   wire                                                            RX_REQ_fetch_mr_egress_last,
    output  wire                                                            RX_REQ_fetch_mr_egress_ready,

//Interface with RecvQueueMgt
    output  wire                                                            RQ_wqe_req_valid,
    output  wire    [`WQE_META_WIDTH - 1 : 0]                               RQ_wqe_req_head,
    output  wire                                                            RQ_wqe_req_start,
    output  wire                                                            RQ_wqe_req_last,
    input   wire                                                            RQ_wqe_req_ready,

    input   wire                                                            RQ_wqe_resp_valid,
    input   wire    [`WQE_META_WIDTH - 1 : 0]                               RQ_wqe_resp_head,
    input   wire    [`WQE_SEG_WIDTH - 1 : 0]                                RQ_wqe_resp_data,
    input   wire                                                            RQ_wqe_resp_start,
    input   wire                                                            RQ_wqe_resp_last,
    output  wire                                                            RQ_wqe_resp_ready,

//Interface with cache offset table
    output  wire                                                            RQ_cache_offset_wen,
    output  wire     [`QP_NUM_LOG - 1 : 0]                                  RQ_cache_offset_addr,
    output  wire     [`RQ_CACHE_SLOT_NUM_LOG - 1:0]                         RQ_cache_offset_din,
    input   wire    [`RQ_CACHE_SLOT_NUM_LOG - 1:0]                          RQ_cache_offset_dout,

//Interface with RQHeadRecord
    output  wire                                                            RQ_offset_wen,
    output  wire     [`QP_NUM_LOG - 1 : 0]                                  RQ_offset_addr,
    output  wire     [23:0]                                                 RQ_offset_din,
    input   wire    [23:0]                                                  RQ_offset_dout,

    output  wire                                                            RQ_cache_owned_wen,
    output  wire    [`RQ_CACHE_CELL_NUM_LOG - 1 : 0]                        RQ_cache_owned_addr,
    output  wire    [`QP_NUM_LOG - 1 : 0]                                   RQ_cache_owned_din,
    input   wire    [`QP_NUM_LOG - 1 : 0]                                   RQ_cache_owned_dout,

//Interface with CompletionQueueMgt
    output  wire                                                            RX_REQ_cq_req_valid,
    output  wire    [`CQ_REQ_HEAD_WIDTH - 1 : 0]                            RX_REQ_cq_req_head,
    input   wire                                                            RX_REQ_cq_req_ready,
     
    input   wire                                                            RX_REQ_cq_resp_valid,
    input   wire    [`CQ_RESP_HEAD_WIDTH - 1 : 0]                           RX_REQ_cq_resp_head,
    output  wire                                                            RX_REQ_cq_resp_ready,

//Interface with EventQueueMgt
    output  wire                                                            RX_REQ_eq_req_valid,
    output  wire    [`EQ_REQ_HEAD_WIDTH - 1 : 0]                            RX_REQ_eq_req_head,
    input   wire                                                            RX_REQ_eq_req_ready,
 
    input   wire                                                            RX_REQ_eq_resp_valid,
    input   wire    [`EQ_RESP_HEAD_WIDTH - 1 : 0]                           RX_REQ_eq_resp_head,
    output  wire                                                            RX_REQ_eq_resp_ready,

//Interface with Packet Buffer
    output  wire                                                            RX_REQ_delete_req_valid,
    output  wire    [`MAX_DB_SLOT_NUM_LOG * 2 - 1 : 0]                      RX_REQ_delete_req_head,
    input   wire                                                            RX_REQ_delete_req_ready,
                    
    input   wire                                                            RX_REQ_delete_resp_valid,
    input   wire                                                            RX_REQ_delete_resp_start,
    input   wire                                                            RX_REQ_delete_resp_last,
    input   wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     RX_REQ_delete_resp_data,
    output  wire                                                            RX_REQ_delete_resp_ready,

//DMA Write Interface
    output  wire                                                            RX_REQ_scatter_req_wr_en,
    output  wire     [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]      RX_REQ_scatter_req_din,
    input   wire                                                            RX_REQ_scatter_req_prog_full,

    output  wire                                                            RX_REQ_scatter_data_wr_en,
    output  wire     [`DMA_DATA_WIDTH - 1: 0]                               RX_REQ_scatter_data_din,
    input   wire                                                            RX_REQ_scatter_data_prog_full,

//DMA Read Interface
    output  wire                                                            TX_RESP_gather_req_wr_en,
    output  wire     [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]      TX_RESP_gather_req_din,
    input   wire                                                            TX_RESP_gather_req_prog_full,

//Interface with Gather Data
    input   wire                                                            TX_RESP_payload_empty,
    input   wire    [511:0]                                                 TX_RESP_payload_data,
    output  wire                                                            TX_RESP_payload_rd_en,

//Interface with Payload Buffer
    output  wire                                                            TX_RESP_insert_req_valid,
    output  wire                                                            TX_RESP_insert_req_start,
    output  wire                                                            TX_RESP_insert_req_last,
    output  wire    [`PACKET_BUFFER_SLOT_NUM_LOG - 1 : 0]                   TX_RESP_insert_req_head,
    output  wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     TX_RESP_insert_req_data,
    input   wire                                                            TX_RESP_insert_req_ready,

    input   wire                                                            TX_RESP_insert_resp_valid,
    input   wire    [`PACKET_BUFFER_SLOT_NUM_LOG - 1 : 0]                   TX_RESP_insert_resp_data,

//Interface with TransportSubsystem
    output  wire                                                            TX_RESP_egress_pkt_valid,
    output  wire    [`PKT_META_BUS_WIDTH - 1 : 0]                           TX_RESP_egress_pkt_head,
    input   wire                                                            TX_RESP_egress_pkt_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                                            TX_RESP_net_resp_wen;
wire    [`NET_REQ_META_WIDTH - 1 : 0]                           TX_RESP_net_resp_din;
wire                                                            TX_RESP_net_resp_prog_full;

wire                                                            TX_RESP_net_resp_ren;
wire    [`NET_REQ_META_WIDTH - 1 : 0]                           TX_RESP_net_resp_dout;
wire                                                            TX_RESP_net_resp_empty;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
ReqRecvCore #(
    .INGRESS_CXT_HEAD_WIDTH             (       INGRESS_CXT_HEAD_WIDTH      ),
    .INGRESS_CXT_DATA_WIDTH             (       INGRESS_CXT_DATA_WIDTH      ),
    .EGRESS_CXT_HEAD_WIDTH              (       EGRESS_CXT_HEAD_WIDTH       ),
    .EGRESS_CXT_DATA_WIDTH              (       EGRESS_CXT_DATA_WIDTH       ),

    .INGRESS_MR_HEAD_WIDTH              (       INGRESS_MR_HEAD_WIDTH       ),
    .INGRESS_MR_DATA_WIDTH              (       INGRESS_MR_DATA_WIDTH       ),
    .EGRESS_MR_HEAD_WIDTH               (       EGRESS_MR_HEAD_WIDTH        ),
    .EGRESS_MR_DATA_WIDTH               (       EGRESS_MR_DATA_WIDTH        )
)
ReqRecvCore_Inst
(
    .clk                                (       clk                         ),
    .rst                                (       rst                         ),

    .ingress_pkt_valid                  (       RX_REQ_ingress_pkt_valid           ),
    .ingress_pkt_head                   (       RX_REQ_ingress_pkt_head            ),
    .ingress_pkt_ready                  (       RX_REQ_ingress_pkt_ready           ),

    .fetch_cxt_ingress_valid            (       RX_REQ_fetch_cxt_ingress_valid     ),
    .fetch_cxt_ingress_head             (       RX_REQ_fetch_cxt_ingress_head      ),
    .fetch_cxt_ingress_data             (       RX_REQ_fetch_cxt_ingress_data      ),
    .fetch_cxt_ingress_start            (       RX_REQ_fetch_cxt_ingress_start     ),
    .fetch_cxt_ingress_last             (       RX_REQ_fetch_cxt_ingress_last      ),
    .fetch_cxt_ingress_ready            (       RX_REQ_fetch_cxt_ingress_ready     ),

    .fetch_cxt_egress_valid             (       RX_REQ_fetch_cxt_egress_valid      ),
    .fetch_cxt_egress_head              (       RX_REQ_fetch_cxt_egress_head       ),
    .fetch_cxt_egress_data              (       RX_REQ_fetch_cxt_egress_data       ),
    .fetch_cxt_egress_start             (       RX_REQ_fetch_cxt_egress_start      ),
    .fetch_cxt_egress_last              (       RX_REQ_fetch_cxt_egress_last       ),
    .fetch_cxt_egress_ready             (       RX_REQ_fetch_cxt_egress_ready      ),

    .fetch_mr_ingress_valid             (       RX_REQ_fetch_mr_ingress_valid      ),
    .fetch_mr_ingress_head              (       RX_REQ_fetch_mr_ingress_head       ),
    .fetch_mr_ingress_data              (       RX_REQ_fetch_mr_ingress_data       ),
    .fetch_mr_ingress_start             (       RX_REQ_fetch_mr_ingress_start      ),
    .fetch_mr_ingress_last              (       RX_REQ_fetch_mr_ingress_last       ),
    .fetch_mr_ingress_ready             (       RX_REQ_fetch_mr_ingress_ready      ),

    .fetch_mr_egress_valid              (       RX_REQ_fetch_mr_egress_valid       ),
    .fetch_mr_egress_head               (       RX_REQ_fetch_mr_egress_head        ),
    .fetch_mr_egress_data               (       RX_REQ_fetch_mr_egress_data        ),
    .fetch_mr_egress_start              (       RX_REQ_fetch_mr_egress_start       ),
    .fetch_mr_egress_last               (       RX_REQ_fetch_mr_egress_last        ),
    .fetch_mr_egress_ready              (       RX_REQ_fetch_mr_egress_ready       ),

    .wqe_req_valid                      (       RQ_wqe_req_valid               ),
    .wqe_req_head                       (       RQ_wqe_req_head                ),
    .wqe_req_start                      (       RQ_wqe_req_start               ),
    .wqe_req_last                       (       RQ_wqe_req_last                ),
    .wqe_req_ready                      (       RQ_wqe_req_ready               ),
        
    .wqe_resp_valid                     (       RQ_wqe_resp_valid              ),
    .wqe_resp_head                      (       RQ_wqe_resp_head               ),
    .wqe_resp_data                      (       RQ_wqe_resp_data               ),
    .wqe_resp_start                     (       RQ_wqe_resp_start              ),
    .wqe_resp_last                      (       RQ_wqe_resp_last               ),
    .wqe_resp_ready                     (       RQ_wqe_resp_ready              ),

    .cache_offset_wen                   (       RQ_cache_offset_wen            ),
    .cache_offset_addr                  (       RQ_cache_offset_addr           ),
    .cache_offset_din                   (       RQ_cache_offset_din            ),
    .cache_offset_dout                  (       RQ_cache_offset_dout           ),

    .rq_offset_wen                      (       RQ_offset_wen               ),
    .rq_offset_addr                     (       RQ_offset_addr              ),
    .rq_offset_din                      (       RQ_offset_din               ),
    .rq_offset_dout                     (       RQ_offset_dout              ),

    .RQ_cache_owned_wen                 (           RQ_cache_owned_wen              ),
    .RQ_cache_owned_addr                (           RQ_cache_owned_addr             ),
    .RQ_cache_owned_din                 (           RQ_cache_owned_din              ),
    .RQ_cache_owned_dout                (           RQ_cache_owned_dout             ),

    .cq_req_valid                       (       RX_REQ_cq_req_valid                ),
    .cq_req_head                        (       RX_REQ_cq_req_head                 ),
    .cq_req_ready                       (       RX_REQ_cq_req_ready                ),
     
    .cq_resp_valid                      (       RX_REQ_cq_resp_valid               ),
    .cq_resp_head                       (       RX_REQ_cq_resp_head                ),
    .cq_resp_ready                      (       RX_REQ_cq_resp_ready               ),

    .eq_req_valid                       (       RX_REQ_eq_req_valid                ),
    .eq_req_head                        (       RX_REQ_eq_req_head                 ),
    .eq_req_ready                       (       RX_REQ_eq_req_ready                ),
 
    .eq_resp_valid                      (       RX_REQ_eq_resp_valid               ),
    .eq_resp_head                       (       RX_REQ_eq_resp_head                ),
    .eq_resp_ready                      (       RX_REQ_eq_resp_ready               ),

    .delete_req_valid                   (       RX_REQ_delete_req_valid            ),
    .delete_req_head                    (       RX_REQ_delete_req_head             ),
    .delete_req_ready                   (       RX_REQ_delete_req_ready            ),
                    
    .delete_resp_valid                  (       RX_REQ_delete_resp_valid           ),
    .delete_resp_start                  (       RX_REQ_delete_resp_start           ),
    .delete_resp_last                   (       RX_REQ_delete_resp_last            ),
    .delete_resp_data                   (       RX_REQ_delete_resp_data            ),
    .delete_resp_ready                  (       RX_REQ_delete_resp_ready           ),

    .scatter_req_wr_en                  (       RX_REQ_scatter_req_wr_en           ),
    .scatter_req_din                    (       RX_REQ_scatter_req_din             ),
    .scatter_req_prog_full              (       RX_REQ_scatter_req_prog_full       ),

    .scatter_data_wr_en                 (       RX_REQ_scatter_data_wr_en          ),
    .scatter_data_din                   (       RX_REQ_scatter_data_din            ),
    .scatter_data_prog_full             (       RX_REQ_scatter_data_prog_full      ),

    .gather_req_wr_en                   (       TX_RESP_gather_req_wr_en            ),
    .gather_req_din                     (       TX_RESP_gather_req_din              ),
    .gather_req_prog_full               (       TX_RESP_gather_req_prog_full        ),
    
    .net_resp_wen                       (       TX_RESP_net_resp_wen                ),
    .net_resp_din                       (       TX_RESP_net_resp_din                ),
    .net_resp_prog_full                 (       TX_RESP_net_resp_prog_full          )
);

RespTransCore RespTransCore_Inst(
    .clk                                (       clk                         ),
    .rst                                (       rst                         ),

    .net_resp_ren                       (       TX_RESP_net_resp_ren                ),
    .net_resp_empty                     (       TX_RESP_net_resp_empty              ),
    .net_resp_dout                      (       TX_RESP_net_resp_dout               ),

    .payload_empty                      (       TX_RESP_payload_empty               ),
    .payload_data                       (       TX_RESP_payload_data                ),
    .payload_ren                        (       TX_RESP_payload_rd_en                 ),

    .insert_req_valid                   (       TX_RESP_insert_req_valid            ),
    .insert_req_start                   (       TX_RESP_insert_req_start            ),
    .insert_req_last                    (       TX_RESP_insert_req_last             ),
    .insert_req_head                    (       TX_RESP_insert_req_head             ),
    .insert_req_data                    (       TX_RESP_insert_req_data             ),
    .insert_req_ready                   (       TX_RESP_insert_req_ready            ),

    .insert_resp_valid                  (       TX_RESP_insert_resp_valid           ),
    .insert_resp_data                   (       TX_RESP_insert_resp_data            ),

    .egress_pkt_valid                   (       TX_RESP_egress_pkt_valid            ),
    .egress_pkt_head                    (       TX_RESP_egress_pkt_head             ),
    .egress_pkt_ready                   (       TX_RESP_egress_pkt_ready            )
);

SyncFIFO_Template #(
    .FIFO_WIDTH     (       `NET_REQ_META_WIDTH         ),
    .FIFO_DEPTH     (       64                          )
)
NetReqFIFO_Inst
(
    .clk            (       clk                     ),
    .rst            (       rst                     ),

    .wr_en          (       TX_RESP_net_resp_wen            ),
    .din            (       TX_RESP_net_resp_din            ),
    .prog_full      (       TX_RESP_net_resp_prog_full      ),
    
    .rd_en          (       TX_RESP_net_resp_ren            ),
    .dout           (       TX_RESP_net_resp_dout           ),
    .empty          (       TX_RESP_net_resp_empty          ),

    .data_count     (                               )
);

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
/*------------------------------------------- Variables Decode : End ----------------------------------------------***/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule