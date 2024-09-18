/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       RQMgt
Author:     YangFan
Function:   Manage Recv Queue.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module RQMgt
#(
    parameter   CACHE_SLOT_NUM              =       256,
    parameter   CACHE_SLOT_NUM_LOG          =       log2b(CACHE_SLOT_NUM - 1),

    parameter   CACHE_CELL_NUM              =       256,
    parameter   CACHE_CELL_NUM_LOG          =       log2b(CACHE_CELL_NUM - 1),

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

//Interface with RDMACore/ReqRecvCore
    input   wire                                                            wqe_req_valid,
    input   wire    [`WQE_META_WIDTH - 1 : 0]                               wqe_req_head,
    input   wire                                                            wqe_req_start,
    input   wire                                                            wqe_req_last,
    output  wire                                                            wqe_req_ready,

    output  wire                                                            wqe_resp_valid,
    output  wire    [`WQE_META_WIDTH - 1 : 0]                               wqe_resp_head,
    output  wire    [`WQE_SEG_WIDTH - 1 : 0]                                wqe_resp_data,
    output  wire                                                            wqe_resp_start,
    output  wire                                                            wqe_resp_last,
    input   wire                                                            wqe_resp_ready,

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
    output  wire                                                            fetch_mr_ingress_valid,
    output  wire    [`RQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]                 fetch_mr_ingress_head, 
    output  wire    [`RQ_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]                 fetch_mr_ingress_data,
    output  wire                                                            fetch_mr_ingress_start,
    output  wire                                                            fetch_mr_ingress_last,
    input   wire                                                            fetch_mr_ingress_ready,

    input   wire                                                            fetch_mr_egress_valid,
    input   wire    [`RQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]                  fetch_mr_egress_head,
    input   wire    [`RQ_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]                  fetch_mr_egress_data,
    input   wire                                                            fetch_mr_egress_start,
    input   wire                                                            fetch_mr_egress_last,
    output  wire                                                            fetch_mr_egress_ready,

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
    output  wire                                                            RQ_dma_rd_rsp_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire            [0:0]                                                       rq_offset_record_wea;
wire            [`QP_NUM_LOG - 1 : 0]                                       rq_offset_record_addra;
wire            [23:0]                                                      rq_offset_record_dina;
wire            [23:0]                                                      rq_offset_record_douta;

wire                                                                        cache_owned_wea;
wire            [CACHE_CELL_NUM_LOG - 1 : 0]                                cache_owned_addra;
wire            [`QP_NUM_LOG - 1 : 0]                                       cache_owned_dina;
wire            [`QP_NUM_LOG - 1 : 0]                                       cache_owned_douta;

wire                                                                        cache_offset_wea;
wire            [`QP_NUM_LOG - 1 : 0]                                       cache_offset_addra;
wire            [`SQ_CACHE_SLOT_NUM_LOG - 1:0]                              cache_offset_dina;
wire            [`SQ_CACHE_SLOT_NUM_LOG - 1:0]                              cache_offset_douta;

wire                                                                        cache_buffer_wea;
wire            [log2b(`RQ_CACHE_SLOT_NUM * `RQ_CACHE_CELL_NUM - 1) - 1 : 0]                            cache_buffer_addra;
wire            [`WQE_SEG_WIDTH - 1 : 0]                                    cache_buffer_dina;

wire            [log2b(`SQ_CACHE_SLOT_NUM * `SQ_CACHE_CELL_NUM - 1) - 1 : 0]                            cache_buffer_addrb;
wire            [`WQE_SEG_WIDTH - 1 : 0]                                    cache_buffer_doutb;

wire                                                                        wqe_valid;
wire            [`WQE_META_WIDTH - 1 : 0]                                   wqe_head;
wire            [`WQE_SEG_WIDTH - 1 : 0]                                    wqe_data;
wire                                                                        wqe_start;
wire                                                                        wqe_last;
wire                                                                        wqe_ready;

wire                                                                        rq_meta_valid;
wire            [`SQ_META_WIDTH - 1 : 0]                                    rq_meta_data;
wire                                                                        rq_meta_ready;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
RQMetaProc
#(
    .INGRESS_CXT_HEAD_WIDTH             (       INGRESS_CXT_HEAD_WIDTH          ),
    .INGRESS_CXT_DATA_WIDTH             (       INGRESS_CXT_DATA_WIDTH          ),
    .EGRESS_CXT_HEAD_WIDTH              (       EGRESS_CXT_HEAD_WIDTH           ),
    .EGRESS_CXT_DATA_WIDTH              (       EGRESS_CXT_DATA_WIDTH           ),

    .INGRESS_MR_HEAD_WIDTH              (       INGRESS_MR_HEAD_WIDTH           ),
    .INGRESS_MR_DATA_WIDTH              (       INGRESS_MR_DATA_WIDTH           ),
    .EGRESS_MR_HEAD_WIDTH               (       EGRESS_MR_HEAD_WIDTH            ),
    .EGRESS_MR_DATA_WIDTH               (       EGRESS_MR_DATA_WIDTH            )
)
RQMetaProc_Inst
(
    .clk                                (       clk                             ),
    .rst                                (       rst                             ),

    .wqe_req_valid                      (       wqe_req_valid                   ),
    .wqe_req_head                       (       wqe_req_head                    ),
    .wqe_req_start                      (       wqe_req_start                   ),
    .wqe_req_last                       (       wqe_req_last                    ),
    .wqe_req_ready                      (       wqe_req_ready                   ),

    .rq_offset_wen                      (       rq_offset_record_wea            ),
    .rq_offset_din                      (       rq_offset_record_dina           ),
    .rq_offset_addr                     (       rq_offset_record_addra          ),
    .rq_offset_dout                     (       rq_offset_record_douta          ),
  
    .fetch_mr_ingress_valid             (       fetch_mr_ingress_valid          ),
    .fetch_mr_ingress_head              (       fetch_mr_ingress_head           ), 
    .fetch_mr_ingress_data              (       fetch_mr_ingress_data           ),
    .fetch_mr_ingress_start             (       fetch_mr_ingress_start          ),
    .fetch_mr_ingress_last              (       fetch_mr_ingress_last           ),
    .fetch_mr_ingress_ready             (       fetch_mr_ingress_ready          ),

    .fetch_mr_egress_valid              (       fetch_mr_egress_valid           ),
    .fetch_mr_egress_head               (       fetch_mr_egress_head            ),
    .fetch_mr_egress_data               (       fetch_mr_egress_data            ),
    .fetch_mr_egress_start              (       fetch_mr_egress_start           ),
    .fetch_mr_egress_last               (       fetch_mr_egress_last            ),
    .fetch_mr_egress_ready              (       fetch_mr_egress_ready           ),

    .rq_meta_valid                      (       rq_meta_valid                   ),
    .rq_meta_data                       (       rq_meta_data                    ),
    .rq_meta_ready                      (       rq_meta_ready                   )

);

WQECache
#(
    .CACHE_SLOT_NUM                     (       CACHE_SLOT_NUM              ),
    .CACHE_SLOT_NUM_LOG                 (       CACHE_SLOT_NUM_LOG          ),

    .CACHE_CELL_NUM                     (       CACHE_CELL_NUM              ),
    .CACHE_CELL_NUM_LOG                 (       CACHE_CELL_NUM_LOG          )
)
RQCache_Inst
(
    .clk                                (       clk                         ),
    .rst                                (       rst                         ),

    .cache_buffer_wea                   (       cache_buffer_wea            ),
    .cache_buffer_addra                 (       cache_buffer_addra          ),
    .cache_buffer_dina                  (       cache_buffer_dina           ),

    .cache_buffer_addrb                 (       cache_buffer_addrb          ),
    .cache_buffer_doutb                 (       cache_buffer_doutb          ),

    .cache_owned_wea                    (       cache_owned_wea             ),
    .cache_owned_addra                  (       cache_owned_addra           ),
    .cache_owned_dina                   (       cache_owned_dina            ),
    .cache_owned_douta                  (       cache_owned_douta           ),

    .cache_owned_web                    (       RQ_cache_owned_wen          ),
    .cache_owned_addrb                  (       RQ_cache_owned_addr         ),
    .cache_owned_dinb                   (       RQ_cache_owned_din          ),
    .cache_owned_doutb                  (       RQ_cache_owned_dout         ),

    .cache_offset_wea                   (       cache_offset_wea            ),
    .cache_offset_addra                 (       cache_offset_addra          ),
    .cache_offset_dina                  (       cache_offset_dina           ),
    .cache_offset_douta                 (       cache_offset_douta          ),

    .cache_offset_web                   (       RQ_cache_offset_wen         ),
    .cache_offset_addrb                 (       RQ_cache_offset_addr        ),
    .cache_offset_dinb                  (       RQ_cache_offset_din         ),
    .cache_offset_doutb                 (       RQ_cache_offset_dout        )
);

WQEFetch
#(
    .CACHE_SLOT_NUM                     (       CACHE_SLOT_NUM              ),
    .CACHE_SLOT_NUM_LOG                 (       CACHE_SLOT_NUM_LOG          ),

    .CACHE_CELL_NUM                     (       CACHE_CELL_NUM              ),
    .CACHE_CELL_NUM_LOG                 (       CACHE_CELL_NUM_LOG          )
)
WQEFetch_Inst
(
    .clk                                (       clk                         ),
    .rst                                (       rst                         ),
        
    .meta_valid                         (       rq_meta_valid               ),
    .meta_data                          (       rq_meta_data                ),
    .meta_ready                         (       rq_meta_ready               ),

    .cache_buffer_wea                   (       cache_buffer_wea            ),
    .cache_buffer_addra                 (       cache_buffer_addra          ),
    .cache_buffer_dina                  (       cache_buffer_dina           ),

    .cache_buffer_addrb                 (       cache_buffer_addrb          ),
    .cache_buffer_doutb                 (       cache_buffer_doutb          ),

    .cache_owned_wen                    (       cache_owned_wea             ),
    .cache_owned_addr                   (       cache_owned_addra           ),
    .cache_owned_din                    (       cache_owned_dina            ),
    .cache_owned_dout                   (       cache_owned_douta           ),

    .dma_rd_req_valid                   (       RQ_dma_rd_req_valid         ),
    .dma_rd_req_head                    (       RQ_dma_rd_req_head          ),
    .dma_rd_req_data                    (       RQ_dma_rd_req_data          ),
    .dma_rd_req_last                    (       RQ_dma_rd_req_last          ),
    .dma_rd_req_ready                   (       RQ_dma_rd_req_ready         ),

    .dma_rd_rsp_valid                  (       RQ_dma_rd_rsp_valid        ),
    .dma_rd_rsp_head                   (       RQ_dma_rd_rsp_head         ),
    .dma_rd_rsp_data                   (       RQ_dma_rd_rsp_data         ),
    .dma_rd_rsp_last                   (       RQ_dma_rd_rsp_last         ),
    .dma_rd_rsp_ready                  (       RQ_dma_rd_rsp_ready        ),

    .cache_offset_wen                   (       cache_offset_wea            ),
    .cache_offset_addr                  (       cache_offset_addra          ),
    .cache_offset_din                   (       cache_offset_dina           ),
    .cache_offset_dout                  (       cache_offset_douta          ),

    .wqe_valid                          (       wqe_resp_valid              ),
    .wqe_head                           (       wqe_resp_head               ),
    .wqe_data                           (       wqe_resp_data               ),
    .wqe_start                          (       wqe_resp_start              ),
    .wqe_last                           (       wqe_resp_last               ),
    .wqe_ready                          (       wqe_resp_ready              )
);

SRAM_TDP_Template #(
    .RAM_WIDTH      (   24                                      ),
    .RAM_DEPTH      (   `QP_NUM                                 )
)
RQOffsetRecordTable
(
    .clk            (   clk                                     ),
    .rst            (   rst                                     ),

    .wea            (   rq_offset_record_wea                    ),
    .addra          (   rq_offset_record_addra                  ),
    .dina           (   rq_offset_record_dina                   ),
    .douta          (   rq_offset_record_douta                  ),

    .web            (   RQ_offset_wen                           ),
    .addrb          (   RQ_offset_addr                          ),
    .dinb           (   RQ_offset_din                           ),
    .doutb          (   RQ_offset_dout                          )
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule