/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ICMGetProc
Author:     YangFan
Function:   Handle ICM Get Request. When ICM Cache Miss happens, DMA cache entry from host memory and update cache.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module ICMGetProc
#(
    parameter               ICM_CACHE_TYPE          =       `CACHE_TYPE_MTT,
    parameter               ICM_PAGE_NUM            =       `ICM_PAGE_NUM_MTT,
    parameter               ICM_PAGE_NUM_LOG        =       log2b(ICM_PAGE_NUM - 1),
    parameter               ICM_ENTRY_NUM           =       `ICM_ENTRY_NUM_MTT,
    parameter               ICM_ENTRY_NUM_LOG       =       log2b(ICM_ENTRY_NUM - 1),
    parameter               ICM_SLOT_SIZE           =       `ICM_SLOT_SIZE_MTT,
    parameter               ICM_ADDR_WIDTH          =       64,

    parameter               CACHE_ADDR_WIDTH        =       log2b(ICM_ENTRY_NUM * ICM_SLOT_SIZE - 1),
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

//ICM Get Req Interface
    input   wire                                                                                                icm_get_req_valid,
    input   wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   icm_get_req_head,
    output  wire                                                                                                icm_get_req_ready,

//ICM Get Resp Interface
    output  wire                                                                                                icm_get_rsp_valid,
    output  wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   icm_get_rsp_head,
    output  wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                 icm_get_rsp_data,
    input   wire                                                                                                icm_get_rsp_ready,

//Cache Get Req Interface
    output  wire                                                                                                cache_get_req_valid,
    output  wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   cache_get_req_head,
    input   wire                                                                                                cache_get_req_ready,

//Cache Get Resp Interface
    input   wire                                                                                                    cache_get_rsp_valid,
    input   wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH + 1 - 1 : 0]   cache_get_rsp_head,
    input   wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                     cache_get_rsp_data,
    output  wire                                                                                                    cache_get_rsp_ready,

//Cache Set Req Interface
    output  wire                                                                                                cache_set_req_valid,
    output  wire    [ICM_ADDR_WIDTH - 1 : 0]                                                                    cache_set_req_head,
    output  wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                 cache_set_req_data,
    input   wire                                                                                                cache_set_req_ready,

//DMA Read Req Interface
    output  wire                                                                                                dma_rd_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                                                                   dma_rd_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                                                                   dma_rd_req_data,
    output  wire                                                                                                dma_rd_req_last,
    input   wire                                                                                                dma_rd_req_ready,
    
//DMA Read Rsp Interface
    input   wire                                                                                                dma_rd_rsp_valid,
    input   wire    [`DMA_HEAD_WIDTH - 1 : 0]                                                                   dma_rd_rsp_head,
    input   wire    [`DMA_DATA_WIDTH - 1 : 0]                                                                   dma_rd_rsp_data,
    input   wire                                                                                                dma_rd_rsp_last,
    output  wire                                                                                                dma_rd_rsp_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/

/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                                                                            req_fifo_wr_en;
wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]    req_fifo_din;
wire                                                                                            req_fifo_prog_full;

wire                                                                                            req_fifo_rd_en;
wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]    req_fifo_dout ;
wire                                                                                            req_fifo_empty;

wire                                                                                            reorder_buffer_wea;
wire    [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                               reorder_buffer_addra;
wire    [REORDER_BUFFER_WIDTH - 1 : 0]                                                          reorder_buffer_dina;
wire    [REORDER_BUFFER_WIDTH - 1 : 0]                                                          reorder_buffer_douta;

wire                                                                                            reorder_buffer_web;
wire    [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                               reorder_buffer_addrb;
wire    [REORDER_BUFFER_WIDTH - 1 : 0]                                                          reorder_buffer_dinb;
wire    [REORDER_BUFFER_WIDTH - 1 : 0]                                                          reorder_buffer_doutb;

wire                                                                                            req_hit_wr_en;
wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]    req_hit_din;
wire                                                                                            req_hit_prog_full;

wire                                                                                            req_hit_rd_en;
wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]    req_hit_dout ;
wire                                                                                            req_hit_empty;

wire                                                                                            req_miss_wr_en;
wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]    req_miss_din;
wire                                                                                            req_miss_prog_full;

wire                                                                                            req_miss_rd_en;
wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]    req_miss_dout ;
wire                                                                                            req_miss_empty;

wire                                                                                            icm_entry_rsp_valid;
wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                             icm_entry_rsp_data ;
wire                                                                                            icm_entry_rsp_ready;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
SyncFIFO_Template #(
    .FIFO_WIDTH     (   COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH    ),
    .FIFO_DEPTH     (   32      )
)
ReqFIFO_Inst
(
    .clk            (       clk                             ),
    .rst            (       rst                             ),
    .wr_en          (       req_fifo_wr_en                  ),
    .din            (       req_fifo_din                    ),
    .prog_full      (       req_fifo_prog_full              ),
    .rd_en          (       req_fifo_rd_en                  ),
    .dout           (       req_fifo_dout                   ),
    .empty          (       req_fifo_empty                  ),
    .data_count     (                                       ) 
);

SyncFIFO_Template #(
    .FIFO_WIDTH     (   COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH    ),
    .FIFO_DEPTH     (   32      )
)
ReqHitFIFO_Inst
(
    .clk            (       clk                                 ),
    .rst            (       rst                                 ),
    .wr_en          (       req_hit_wr_en                       ),
    .din            (       req_hit_din                         ),
    .prog_full      (       req_hit_prog_full                   ),
    .rd_en          (       req_hit_rd_en                       ),
    .dout           (       req_hit_dout                        ),
    .empty          (       req_hit_empty                       ),
    .data_count     (                                           ) 
);

SyncFIFO_Template #(
    .FIFO_WIDTH     (   COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH    ),
    .FIFO_DEPTH     (   32      )
)
ReqMissFIFO_Inst
(
    .clk            (       clk                                 ),
    .rst            (       rst                                 ),
    .wr_en          (       req_miss_wr_en                      ),
    .din            (       req_miss_din                        ),
    .prog_full      (       req_miss_prog_full                  ),
    .rd_en          (       req_miss_rd_en                      ),
    .dout           (       req_miss_dout                       ),
    .empty          (       req_miss_empty                      ),
    .data_count     (                                           )
);

SRAM_TDP_Template #(
    .RAM_WIDTH      (   REORDER_BUFFER_WIDTH                    ),
    .RAM_DEPTH      (   32                             )
)
ReorderBuffer
(
    .clk            (   clk                                     ),
    .rst            (   rst                                     ),

    .wea            (   reorder_buffer_wea                      ),
    .addra          (   reorder_buffer_addra                    ),
    .dina           (   reorder_buffer_dina                     ),
    .douta          (   reorder_buffer_douta                    ),

    .web            (   reorder_buffer_web                      ),
    .addrb          (   reorder_buffer_addrb                    ),
    .dinb           (   reorder_buffer_dinb                     ),
    .doutb          (   reorder_buffer_doutb                    )
);

ICMGetProc_Thread_1
#(
    .ICM_CACHE_TYPE             (   ICM_CACHE_TYPE             ),
    .ICM_SLOT_SIZE              (   ICM_SLOT_SIZE              ),

    .CACHE_ADDR_WIDTH           (   CACHE_ADDR_WIDTH           ),
    .CACHE_ENTRY_WIDTH          (   CACHE_ENTRY_WIDTH          ),
    .CACHE_SET_NUM              (   CACHE_SET_NUM              ),
    .CACHE_SET_NUM_LOG          (   CACHE_SET_NUM_LOG          ),
    .CACHE_OFFSET_WIDTH         (   CACHE_OFFSET_WIDTH         ),
    .CACHE_TAG_WIDTH            (   CACHE_TAG_WIDTH            ),
    .PHYSICAL_ADDR_WIDTH        (   PHYSICAL_ADDR_WIDTH        ),
    .COUNT_MAX                  (   COUNT_MAX                  ),
    .COUNT_MAX_LOG              (   COUNT_MAX_LOG              ),
    .REQ_TAG_NUM                (   REQ_TAG_NUM                ),
    .REQ_TAG_NUM_LOG            (   REQ_TAG_NUM_LOG            ),
    .REORDER_BUFFER_WIDTH       (   REORDER_BUFFER_WIDTH       )
)
ICMGetProc_Thread_1_Inst
(
    .clk                        (   clk                         ),
    .rst                        (   rst                         ),

    .icm_get_req_valid          (   icm_get_req_valid           ),
    .icm_get_req_head           (   icm_get_req_head            ),
    .icm_get_req_ready          (   icm_get_req_ready           ),

    .req_fifo_wr_en             (   req_fifo_wr_en              ),
    .req_fifo_din               (   req_fifo_din                ),
    .req_fifo_prog_full         (   req_fifo_prog_full          )
);

ICMGetProc_Thread_2
#(
    .ICM_CACHE_TYPE             (   ICM_CACHE_TYPE             ),
    .ICM_SLOT_SIZE              (   ICM_SLOT_SIZE              ),

    .CACHE_ADDR_WIDTH           (   CACHE_ADDR_WIDTH           ),
    .CACHE_ENTRY_WIDTH          (   CACHE_ENTRY_WIDTH          ),
    .CACHE_SET_NUM              (   CACHE_SET_NUM              ),
    .CACHE_SET_NUM_LOG          (   CACHE_SET_NUM_LOG          ),
    .CACHE_OFFSET_WIDTH         (   CACHE_OFFSET_WIDTH         ),
    .CACHE_TAG_WIDTH            (   CACHE_TAG_WIDTH            ),
    .PHYSICAL_ADDR_WIDTH        (   PHYSICAL_ADDR_WIDTH        ),
    .COUNT_MAX                  (   COUNT_MAX                  ),
    .COUNT_MAX_LOG              (   COUNT_MAX_LOG              ),
    .REQ_TAG_NUM                (   REQ_TAG_NUM                ),
    .REQ_TAG_NUM_LOG            (   REQ_TAG_NUM_LOG            ),
    .REORDER_BUFFER_WIDTH       (   REORDER_BUFFER_WIDTH       )
)
ICMGetProc_Thread_2_Inst
(
    .clk                        (   clk                         ),
    .rst                        (   rst                         ),

    .req_fifo_rd_en             (   req_fifo_rd_en              ),
    .req_fifo_dout              (   req_fifo_dout               ),
    .req_fifo_empty             (   req_fifo_empty              ),

    .cache_get_req_valid        (   cache_get_req_valid         ),
    .cache_get_req_head         (   cache_get_req_head          ),
    .cache_get_req_ready        (   cache_get_req_ready         )
);

ICMGetProc_Thread_3
#(
    .ICM_CACHE_TYPE             (  ICM_CACHE_TYPE               ),
    .ICM_SLOT_SIZE              (   ICM_SLOT_SIZE              ),

    .CACHE_ADDR_WIDTH           (  CACHE_ADDR_WIDTH             ),
    .CACHE_ENTRY_WIDTH          (  CACHE_ENTRY_WIDTH            ),
    .CACHE_SET_NUM              (  CACHE_SET_NUM                ),
    .CACHE_SET_NUM_LOG          (  CACHE_SET_NUM_LOG            ),
    .CACHE_OFFSET_WIDTH         (  CACHE_OFFSET_WIDTH           ),
    .CACHE_TAG_WIDTH            (  CACHE_TAG_WIDTH              ),
    .PHYSICAL_ADDR_WIDTH        (  PHYSICAL_ADDR_WIDTH          ),
    .COUNT_MAX                  (  COUNT_MAX                    ),
    .COUNT_MAX_LOG              (  COUNT_MAX_LOG                ),
    .REQ_TAG_NUM                (  REQ_TAG_NUM                  ),
    .REQ_TAG_NUM_LOG            (  REQ_TAG_NUM_LOG              ),
    .REORDER_BUFFER_WIDTH       (  REORDER_BUFFER_WIDTH         )
)
ICMGetProc_Thread_3_Inst
(
    .clk                        (   clk                         ),
    .rst                        (   rst                         ),

    .get_rsp_valid              (   cache_get_rsp_valid         ),
    .get_rsp_head               (   cache_get_rsp_head          ),
    .get_rsp_data               (   cache_get_rsp_data          ),
    .get_rsp_ready              (   cache_get_rsp_ready         ),

    .reorder_buffer_wen         (   reorder_buffer_wea          ),
    .reorder_buffer_addr        (   reorder_buffer_addra        ),
    .reorder_buffer_din         (   reorder_buffer_dina         ),
    .reorder_buffer_dout        (   reorder_buffer_douta        ),

    .dma_rd_req_valid           (   dma_rd_req_valid            ),
    .dma_rd_req_head            (   dma_rd_req_head             ),
    .dma_rd_req_data            (   dma_rd_req_data             ),
    .dma_rd_req_last            (   dma_rd_req_last             ),
    .dma_rd_req_ready           (   dma_rd_req_ready            ),

    .req_hit_wr_en              (   req_hit_wr_en               ),
    .req_hit_din                (   req_hit_din                 ),
    .req_hit_prog_full          (   req_hit_prog_full           ),

    .req_miss_wr_en             (   req_miss_wr_en              ),
    .req_miss_din               (   req_miss_din                ),
    .req_miss_prog_full         (   req_miss_prog_full          )
);

ICMGetProc_Thread_4
#(
    .ICM_CACHE_TYPE             (  ICM_CACHE_TYPE               ),
    .ICM_SLOT_SIZE              (   ICM_SLOT_SIZE              ),

    .CACHE_ADDR_WIDTH           (  CACHE_ADDR_WIDTH             ),
    .CACHE_ENTRY_WIDTH          (  CACHE_ENTRY_WIDTH            ),
    .CACHE_SET_NUM              (  CACHE_SET_NUM                ),
    .CACHE_SET_NUM_LOG          (  CACHE_SET_NUM_LOG            ),
    .CACHE_OFFSET_WIDTH         (  CACHE_OFFSET_WIDTH           ),
    .CACHE_TAG_WIDTH            (  CACHE_TAG_WIDTH              ),
    .PHYSICAL_ADDR_WIDTH        (  PHYSICAL_ADDR_WIDTH          ),
    .COUNT_MAX                  (  COUNT_MAX                    ),
    .COUNT_MAX_LOG              (  COUNT_MAX_LOG                ),
    .REQ_TAG_NUM                (  REQ_TAG_NUM                  ),
    .REQ_TAG_NUM_LOG            (  REQ_TAG_NUM_LOG              ),
    .REORDER_BUFFER_WIDTH       (  REORDER_BUFFER_WIDTH         )
)
ICMGetProc_Thread_4_Inst
(
    .clk                        (   clk                         ),
    .rst                        (   rst                         ),

    .req_hit_rd_en              (   req_hit_rd_en               ),
    .req_hit_dout               (   req_hit_dout                ),
    .req_hit_empty              (   req_hit_empty               ),

    .req_miss_rd_en             (   req_miss_rd_en              ),
    .req_miss_dout              (   req_miss_dout               ),
    .req_miss_empty             (   req_miss_empty              ),

    .reorder_buffer_wen         (   reorder_buffer_web          ),
    .reorder_buffer_addr        (   reorder_buffer_addrb        ),
    .reorder_buffer_din         (   reorder_buffer_dinb         ),
    .reorder_buffer_dout        (   reorder_buffer_doutb        ),

    .icm_entry_rsp_valid        (   icm_entry_rsp_valid         ),
    .icm_entry_rsp_data         (   icm_entry_rsp_data          ),
    .icm_entry_rsp_ready        (   icm_entry_rsp_ready         ),

    .cache_set_req_valid        (   cache_set_req_valid         ),
    .cache_set_req_head         (   cache_set_req_head          ),
    .cache_set_req_data         (   cache_set_req_data          ),
    .cache_set_req_ready        (   cache_set_req_ready         ),

    .icm_get_rsp_valid          (   icm_get_rsp_valid           ),
    .icm_get_rsp_head           (   icm_get_rsp_head            ),
    .icm_get_rsp_data           (   icm_get_rsp_data            ),
    .icm_get_rsp_ready          (   icm_get_rsp_ready           )
);

ICMGetProc_Thread_5
#(
    .ICM_CACHE_TYPE             (  ICM_CACHE_TYPE               ),
    .ICM_SLOT_SIZE              (   ICM_SLOT_SIZE              ),
    
    .CACHE_ADDR_WIDTH           (  CACHE_ADDR_WIDTH             ),
    .CACHE_ENTRY_WIDTH          (  CACHE_ENTRY_WIDTH            ),
    .CACHE_SET_NUM              (  CACHE_SET_NUM                ),
    .CACHE_SET_NUM_LOG          (  CACHE_SET_NUM_LOG            ),
    .CACHE_OFFSET_WIDTH         (  CACHE_OFFSET_WIDTH           ),
    .CACHE_TAG_WIDTH            (  CACHE_TAG_WIDTH              ),
    .PHYSICAL_ADDR_WIDTH        (  PHYSICAL_ADDR_WIDTH          ),
    .COUNT_MAX                  (  COUNT_MAX                    ),
    .COUNT_MAX_LOG              (  COUNT_MAX_LOG                ),
    .REQ_TAG_NUM                (  REQ_TAG_NUM                  ),
    .REQ_TAG_NUM_LOG            (  REQ_TAG_NUM_LOG              ),
    .REORDER_BUFFER_WIDTH       (  REORDER_BUFFER_WIDTH         )
)
ICMGetProc_Thread_5_Inst
(
    .clk                        (   clk                         ),
    .rst                        (   rst                         ),

    .dma_rd_rsp_valid           (   dma_rd_rsp_valid            ),
    .dma_rd_rsp_head            (   dma_rd_rsp_head             ),
    .dma_rd_rsp_data            (   dma_rd_rsp_data             ),
    .dma_rd_rsp_last            (   dma_rd_rsp_last             ),
    .dma_rd_rsp_ready           (   dma_rd_rsp_ready            ),

    .icm_entry_rsp_valid        (   icm_entry_rsp_valid         ),
    .icm_entry_rsp_data         (   icm_entry_rsp_data          ),
    .icm_entry_rsp_ready        (   icm_entry_rsp_ready         )
);

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule