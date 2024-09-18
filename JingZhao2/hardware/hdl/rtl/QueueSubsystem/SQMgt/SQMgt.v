/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       SQMgt
Author:     YangFan
Function:   Manage Send Queue.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module SQMgt
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

//Interface with PIO
    input   wire                                                            db_fifo_empty,
    input   wire            [63:0]                                          db_fifo_dout,
    output  wire                                                            db_fifo_rd_en,

//Interface with CxtMgt 
    output  wire                                                            fetch_cxt_ingress_valid,
    output  wire    [`SQ_OOO_CXT_INGRESS_HEAD_WIDTH - 1 : 0]                fetch_cxt_ingress_head, 
    output  wire    [`SQ_OOO_CXT_INGRESS_DATA_WIDTH - 1 : 0]                fetch_cxt_ingress_data, 
    output  wire                                                            fetch_cxt_ingress_start,
    output  wire                                                            fetch_cxt_ingress_last,
    input   wire                                                            fetch_cxt_ingress_ready,

    input   wire                                                            fetch_cxt_egress_valid,
    input   wire    [`SQ_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]                 fetch_cxt_egress_head,  
    input   wire    [`SQ_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]                 fetch_cxt_egress_data,
    input   wire                                                            fetch_cxt_egress_start,
    input   wire                                                            fetch_cxt_egress_last,
    output  wire                                                            fetch_cxt_egress_ready,

//Interface with MRMgt    
    output  wire                                                            fetch_mr_ingress_valid,
    output  wire    [`SQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]                 fetch_mr_ingress_head, 
    output  wire    [`SQ_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]                 fetch_mr_ingress_data,
    output  wire                                                            fetch_mr_ingress_start,
    output  wire                                                            fetch_mr_ingress_last,
    input   wire                                                            fetch_mr_ingress_ready,

    input   wire                                                            fetch_mr_egress_valid,
    input   wire    [`SQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]                  fetch_mr_egress_head,
    input   wire    [`SQ_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]                  fetch_mr_egress_data,
    input   wire                                                            fetch_mr_egress_start,
    input   wire                                                            fetch_mr_egress_last,
    output  wire                                                            fetch_mr_egress_ready,

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
    input   wire    [`INLINE_PAYLOAD_BUFFER_SLOT_WIDTH - 1 : 0]             insert_resp_data
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                                                        chnl_0_qpn_valid;
wire    [`QP_NUM_LOG - 1 : 0]                                               chnl_0_qpn_data;
wire                                                                        chnl_0_qpn_ready;

wire                                                                        chnl_1_qpn_valid;
wire    [`QP_NUM_LOG - 1 : 0]                                               chnl_1_qpn_data;
wire                                                                        chnl_1_qpn_ready;

wire                                                                        qpn_in_valid;
wire            [23:0]                                                      qpn_in_data;
wire                                                                        qpn_in_ready;
wire                                                                        qpn_in_prog_full;

wire                                                                        qpn_out_valid;
wire            [23:0]                                                      qpn_out_data;
wire                                                                        qpn_out_ready;
wire 																		qpn_out_empty;

wire                                                                        on_schedule_wea;
wire            [23:0]                                                      on_schedule_addra;
wire            [0:0]                                                       on_schedule_dina;
wire            [23:0]                                                      on_schedule_addrb;
wire            [0:0]                                                       on_schedule_doutb;

wire            [0:0]                                                       sq_head_record_wea;
wire            [`QP_NUM_LOG - 1 : 0]                                       sq_head_record_addra;
wire            [23:0]                                                      sq_head_record_dina;
wire            [23:0]                                                      sq_head_record_douta;

wire            [0:0]                                                       sq_head_record_web;
wire            [`QP_NUM_LOG - 1 : 0]                                       sq_head_record_addrb;
wire            [23:0]                                                      sq_head_record_dinb;
wire            [23:0]                                                      sq_head_record_doutb;

wire            [0:0]                                                       sq_offset_record_wea;
wire            [`QP_NUM_LOG - 1 : 0]                                       sq_offset_record_addra;
wire            [23:0]                                                      sq_offset_record_dina;
wire            [23:0]                                                      sq_offset_record_douta;

wire            [0:0]                                                       sq_offset_record_web;
wire            [`QP_NUM_LOG - 1 : 0]                                       sq_offset_record_addrb;
wire            [23:0]                                                      sq_offset_record_dinb;
wire            [23:0]                                                      sq_offset_record_doutb;

wire                                                                        cache_owned_wea;
wire            [CACHE_CELL_NUM_LOG - 1 : 0]                                cache_owned_addra;
wire            [`QP_NUM_LOG - 1 : 0]                                       cache_owned_dina;
wire            [`QP_NUM_LOG - 1 : 0]                                       cache_owned_douta;

wire                                                                        cache_owned_web;
wire            [CACHE_CELL_NUM_LOG - 1 : 0]                                cache_owned_addrb;
wire            [`QP_NUM_LOG - 1 : 0]                                       cache_owned_dinb;
wire            [`QP_NUM_LOG - 1 : 0]                                       cache_owned_doutb;

wire                                                                        cache_offset_wea;
wire            [`QP_NUM_LOG - 1 : 0]                                       cache_offset_addra;
wire            [`SQ_CACHE_SLOT_NUM_LOG - 1:0]                              cache_offset_dina;
wire            [`SQ_CACHE_SLOT_NUM_LOG - 1:0]                              cache_offset_douta;

wire                                                                        cache_offset_web;
wire            [`QP_NUM_LOG - 1 : 0]                                       cache_offset_addrb;
wire            [`SQ_CACHE_SLOT_NUM_LOG - 1:0]                              cache_offset_dinb;
wire            [`SQ_CACHE_SLOT_NUM_LOG - 1:0]                              cache_offset_doutb;

wire                                                                                                        cache_buffer_wea;
wire            [log2b(`SQ_CACHE_SLOT_NUM * `SQ_CACHE_CELL_NUM - 1) - 1 : 0]                            cache_buffer_addra;
wire            [`WQE_SEG_WIDTH - 1 : 0]                                                                    cache_buffer_dina;

wire            [log2b(`SQ_CACHE_SLOT_NUM * `SQ_CACHE_CELL_NUM - 1) - 1 : 0]                            cache_buffer_addrb;
wire            [`WQE_SEG_WIDTH - 1 : 0]                                                                    cache_buffer_doutb;

wire                                                                        wqe_valid;
wire            [`WQE_PARSER_META_WIDTH - 1 : 0]                                   wqe_head;
wire            [`WQE_SEG_WIDTH - 1 : 0]                                    wqe_data;
wire                                                                        wqe_start;
wire                                                                        wqe_last;
wire                                                                        wqe_ready;

wire                                                                        sq_meta_valid;
wire            [`SQ_META_WIDTH - 1 : 0]                                    sq_meta_data;
wire                                                                        sq_meta_ready;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
DBProc DBProc_Inst(
    .clk                                (       clk                          ),
    .rst                                (       rst                          ),

    .db_fifo_empty                      (       db_fifo_empty                ),
    .db_fifo_dout                       (       db_fifo_dout                 ),
    .db_fifo_rd_en                      (       db_fifo_rd_en                ),

    .qpn_fifo_valid                     (       chnl_0_qpn_valid             ),
    .qpn_fifo_data                      (       chnl_0_qpn_data              ),
    .qpn_fifo_ready                     (       chnl_0_qpn_ready             ),

    .on_schedule_addr                   (       on_schedule_addrb            ),
    .on_schedule_dout                   (       on_schedule_doutb            ),

    .sq_head_record_wen                 (       sq_head_record_wea           ),
    .sq_head_record_addr                (       sq_head_record_addra         ),
    .sq_head_record_din                 (       sq_head_record_dina          ),
    .sq_head_record_dout                (       sq_head_record_douta         )
);

SQMetaProc SQMetaProc_Inst(
    .clk                                (       clk                         ),
    .rst                                (       rst                         ),

    .qpn_valid                          (       qpn_out_valid               ),
    .qpn_data                           (       qpn_out_data                ),
    .qpn_ready                          (       qpn_out_ready               ),

    .fetch_cxt_ingress_valid            (       fetch_cxt_ingress_valid     ),
    .fetch_cxt_ingress_head             (       fetch_cxt_ingress_head      ), 
    .fetch_cxt_ingress_data             (       fetch_cxt_ingress_data      ), 
    .fetch_cxt_ingress_start            (       fetch_cxt_ingress_start     ),
    .fetch_cxt_ingress_last             (       fetch_cxt_ingress_last      ),
    .fetch_cxt_ingress_ready            (       fetch_cxt_ingress_ready     ),

    .fetch_cxt_egress_valid             (       fetch_cxt_egress_valid      ),
    .fetch_cxt_egress_head              (       fetch_cxt_egress_head       ), 
    .fetch_cxt_egress_data              (       fetch_cxt_egress_data       ),
    .fetch_cxt_egress_start             (       fetch_cxt_egress_start      ),
    .fetch_cxt_egress_last              (       fetch_cxt_egress_last       ),
    .fetch_cxt_egress_ready             (       fetch_cxt_egress_ready      ),
 
    .fetch_mr_ingress_valid             (       fetch_mr_ingress_valid      ),
    .fetch_mr_ingress_head              (       fetch_mr_ingress_head       ), 
    .fetch_mr_ingress_data              (       fetch_mr_ingress_data       ),
    .fetch_mr_ingress_start             (       fetch_mr_ingress_start      ),
    .fetch_mr_ingress_last              (       fetch_mr_ingress_last       ),
    .fetch_mr_ingress_ready             (       fetch_mr_ingress_ready      ),

    .fetch_mr_egress_valid              (       fetch_mr_egress_valid       ),
    .fetch_mr_egress_head               (       fetch_mr_egress_head        ),
    .fetch_mr_egress_data               (       fetch_mr_egress_data        ),
    .fetch_mr_egress_start              (       fetch_mr_egress_start       ),
    .fetch_mr_egress_last               (       fetch_mr_egress_last        ),
    .fetch_mr_egress_ready              (       fetch_mr_egress_ready       ),

    .sq_offset_wen                      (       sq_offset_record_wea        ),
    .sq_offset_addr                     (       sq_offset_record_addra      ),
    .sq_offset_din                      (       sq_offset_record_dina       ),
    .sq_offset_dout                     (       sq_offset_record_douta      ),

    .sq_meta_valid                      (       sq_meta_valid               ),
    .sq_meta_data                       (       sq_meta_data                ),
    .sq_meta_ready                      (       sq_meta_ready               )
);

WQECache
#(
    .CACHE_SLOT_NUM                     (       CACHE_SLOT_NUM              ),
    .CACHE_SLOT_NUM_LOG                 (       CACHE_SLOT_NUM_LOG          ),

    .CACHE_CELL_NUM                     (       CACHE_CELL_NUM              ),
    .CACHE_CELL_NUM_LOG                 (       CACHE_CELL_NUM_LOG          )
)
SQCache_Inst
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

    .cache_owned_web                    (       cache_owned_web              ),
    .cache_owned_addrb                  (       cache_owned_addrb            ),
    .cache_owned_dinb                   (       cache_owned_dinb             ),
    .cache_owned_doutb                  (       cache_owned_doutb            ),

    .cache_offset_wea                   (       cache_offset_wea            ),
    .cache_offset_addra                 (       cache_offset_addra          ),
    .cache_offset_dina                  (       cache_offset_dina           ),
    .cache_offset_douta                 (       cache_offset_douta          ),

    .cache_offset_web                   (       cache_offset_web            ),
    .cache_offset_addrb                 (       cache_offset_addrb          ),
    .cache_offset_dinb                  (       cache_offset_dinb           ),
    .cache_offset_doutb                 (       cache_offset_doutb          )
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
        
    .meta_valid                         (       sq_meta_valid               ),
    .meta_data                          (       sq_meta_data                ),
    .meta_ready                         (       sq_meta_ready               ),

    .cache_buffer_wea                   (       cache_buffer_wea            ),
    .cache_buffer_addra                 (       cache_buffer_addra          ),
    .cache_buffer_dina                  (       cache_buffer_dina           ),

    .cache_buffer_addrb                 (       cache_buffer_addrb          ),
    .cache_buffer_doutb                 (       cache_buffer_doutb          ),

    .cache_owned_wen                    (       cache_owned_wea             ),
    .cache_owned_addr                   (       cache_owned_addra           ),
    .cache_owned_din                    (       cache_owned_dina            ),
    .cache_owned_dout                   (       cache_owned_douta           ),

    .dma_rd_req_valid                   (       SQ_dma_rd_req_valid         ),
    .dma_rd_req_head                    (       SQ_dma_rd_req_head          ),
    .dma_rd_req_data                    (       SQ_dma_rd_req_data          ),
    .dma_rd_req_last                    (       SQ_dma_rd_req_last          ),
    .dma_rd_req_ready                   (       SQ_dma_rd_req_ready         ),

    .dma_rd_rsp_valid                  (       SQ_dma_rd_rsp_valid        ),
    .dma_rd_rsp_head                   (       SQ_dma_rd_rsp_head         ),
    .dma_rd_rsp_data                   (       SQ_dma_rd_rsp_data         ),
    .dma_rd_rsp_last                   (       SQ_dma_rd_rsp_last         ),
    .dma_rd_rsp_ready                  (       SQ_dma_rd_rsp_ready        ),

    .cache_offset_wen                   (       cache_offset_wea            ),
    .cache_offset_addr                  (       cache_offset_addra          ),
    .cache_offset_din                   (       cache_offset_dina           ),
    .cache_offset_dout                  (       cache_offset_douta          ),

    .wqe_valid                          (       wqe_valid                   ),
    .wqe_head                           (       wqe_head                    ),
    .wqe_data                           (       wqe_data                    ),
    .wqe_start                          (       wqe_start                   ),
    .wqe_last                           (       wqe_last                    ),
    .wqe_ready                          (       wqe_ready                   )
);

WQEParser
#(
    .CACHE_SLOT_NUM                     (       CACHE_SLOT_NUM              ),
    .CACHE_SLOT_NUM_LOG                 (       CACHE_SLOT_NUM_LOG          ),

    .CACHE_CELL_NUM                     (       CACHE_CELL_NUM              ),
    .CACHE_CELL_NUM_LOG                 (       CACHE_CELL_NUM_LOG          )
)
WQEParser_Inst
(
    .clk                                (       clk                         ),
    .rst                                (       rst                         ),

    .wqe_valid                          (       wqe_valid                   ),
    .wqe_head                           (       wqe_head                    ),
    .wqe_data                           (       wqe_data                    ),
    .wqe_start                          (       wqe_start                   ),
    .wqe_last                           (       wqe_last                    ),
    .wqe_ready                          (       wqe_ready                   ),

    .cache_offset_wen                   (       cache_offset_web            ),
    .cache_offset_addr                  (       cache_offset_addrb          ),
    .cache_offset_din                   (       cache_offset_dinb           ),
    .cache_offset_dout                  (       cache_offset_doutb          ),

    .on_schedule_wen                    (       on_schedule_wea             ),
    .on_schedule_addr                   (       on_schedule_addra           ),
    .on_schedule_din                    (       on_schedule_dina            ),

    .sq_head_record_wen                 (       sq_head_record_web          ),
    .sq_head_record_addr                (       sq_head_record_addrb        ),
    .sq_head_record_din                 (       sq_head_record_dinb         ),
    .sq_head_record_dout                (       sq_head_record_doutb        ),

    .sq_offset_wen                      (       sq_offset_record_web        ),
    .sq_offset_addr                     (       sq_offset_record_addrb      ),
    .sq_offset_din                      (       sq_offset_record_dinb       ),
    .sq_offset_dout                     (       sq_offset_record_doutb      ),

    .cache_owned_wen                    (       cache_owned_web              ),
    .cache_owned_addr                   (       cache_owned_addrb            ),
    .cache_owned_din                    (       cache_owned_dinb             ),
    .cache_owned_dout                   (       cache_owned_doutb            ),

    .sub_wqe_valid                      (       sub_wqe_valid               ),
    .sub_wqe_meta                       (       sub_wqe_meta                ),
    .sub_wqe_ready                      (       sub_wqe_ready               ),

    .qpn_fifo_valid                     (       chnl_1_qpn_valid            ),
    .qpn_fifo_data                      (       chnl_1_qpn_data             ),
    .qpn_fifo_ready                     (       chnl_1_qpn_ready            ),

    .ov_available_slot_num              (       ov_available_slot_num       ),

    .insert_req_valid                   (       insert_req_valid            ),
    .insert_req_start                   (       insert_req_start            ),
    .insert_req_last                    (       insert_req_last             ),
    .insert_req_head                    (       insert_req_head             ),
    .insert_req_data                    (       insert_req_data             ),
    .insert_req_ready                   (       insert_req_ready            ),

    .insert_resp_valid                  (       insert_resp_valid           ),
    .insert_resp_data                   (       insert_resp_data            )
);

SRAM_TDP_Template #(
    .RAM_WIDTH      (   24                                      ),
    .RAM_DEPTH      (   `QP_NUM                            		)
)
SQOffsetRecordTable
(
    .clk            (   clk                                     ),
    .rst            (   rst                                     ),

    .wea            (   sq_offset_record_wea                    ),
    .addra          (   sq_offset_record_addra                  ),
    .dina           (   sq_offset_record_dina                   ),
    .douta          (   sq_offset_record_douta                  ),

    .web            (   sq_offset_record_web                    ),
    .addrb          (   sq_offset_record_addrb                  ),
    .dinb           (   sq_offset_record_dinb                   ),
    .doutb          (   sq_offset_record_doutb                  )
);

SRAM_TDP_Template #(
    .RAM_WIDTH      (   24                                      ),
    .RAM_DEPTH      (   `QP_NUM                             	)
)
SQHeadRecordTable
(
    .clk            (   clk                                     ),
    .rst 			(	rst 									),

    .wea            (   sq_head_record_wea                      ),
    .addra          (   sq_head_record_addra                    ),
    .dina           (   sq_head_record_dina                     ),
    .douta          (   sq_head_record_douta                    ),

    .web            (   sq_head_record_web                      ),
    .addrb          (   sq_head_record_addrb                    ),
    .dinb           (   sq_head_record_dinb                     ),
    .doutb          (   sq_head_record_doutb                    )
);

SRAM_SDP_Template #(
    .RAM_WIDTH      (   1                                      	),
    .RAM_DEPTH      (   `QP_NUM                             	)
)
OnScheduleRecordTable
(
    .clk            (   clk                                     ),
    .rst            (   rst                                     ),

    .wea            (   on_schedule_wea                   		),
    .addra          (   on_schedule_addra                   	),
    .dina           (   on_schedule_dina                  		),

    .addrb          (   on_schedule_addrb                   	),
    .doutb          (   on_schedule_doutb                   	)
);

AXISArbiter
#(
    .HEAD_WIDTH     (       16      ),
    .DATA_WIDTH     (       24      )
)
QPNArbiter_Inst
(
    .clk,
    .rst,

    .in_axis_valid_a            (       chnl_0_qpn_valid        ),
    .in_axis_head_a             (       'd0                     ),
    .in_axis_data_a             (       chnl_0_qpn_data         ),
    .in_axis_start_a            (       chnl_0_qpn_valid        ),
    .in_axis_last_a             (       chnl_0_qpn_valid        ),
    .in_axis_ready_a            (       chnl_0_qpn_ready        ),

    .in_axis_valid_b            (       chnl_1_qpn_valid        ),
    .in_axis_head_b             (       'd0                     ),
    .in_axis_data_b             (       chnl_1_qpn_data         ),
    .in_axis_start_b            (       chnl_1_qpn_valid        ),
    .in_axis_last_b             (       chnl_1_qpn_valid        ),
    .in_axis_ready_b            (       chnl_1_qpn_ready        ),

    .out_axis_valid             (       qpn_in_valid            ),
    .out_axis_head              (                               ),
    .out_axis_data              (       qpn_in_data             ),
    .out_axis_start             (                               ),
    .out_axis_last              (                               ),
    .out_axis_ready             (       qpn_in_ready            )
);

SyncFIFO_Template #(
    .FIFO_TYPE                          (       0                   ),
    .FIFO_WIDTH                         (       24                  ),
    .FIFO_DEPTH                         (       `QP_NUM             )
)
QPNFIFO_Inst
(
    .clk                                (       clk                 ),
    .rst                                (       rst                 ),

    .wr_en                              (       qpn_in_valid        ),
    .din                                (       qpn_in_data         ),
    .prog_full                          (       qpn_in_prog_full    ),

    .rd_en                              (       qpn_out_ready       ),
    .dout                               (       qpn_out_data        ),
    .empty                              (       qpn_out_empty       )
);

assign qpn_in_ready = !qpn_in_prog_full;
assign qpn_out_valid = !qpn_out_empty;
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule