/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ICMCache
Author:     YangFan
Function:   Manage ICM Data and Provides ICM Access Interface.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module ICMCache
#(
    parameter               ICM_CACHE_TYPE          =       `CACHE_TYPE_MTT,
    parameter               ICM_PAGE_NUM            =       `ICM_PAGE_NUM_MTT,
    parameter               ICM_PAGE_NUM_LOG        =       log2b(ICM_PAGE_NUM - 1),
    parameter               ICM_ENTRY_NUM           =       `ICM_ENTRY_NUM_MTT,
    parameter               ICM_ENTRY_NUM_LOG       =       log2b(ICM_ENTRY_NUM - 1),
    parameter               ICM_SLOT_SIZE           =       `ICM_SLOT_SIZE_MTT,
    parameter               ICM_ADDR_WIDTH          =       `ICM_SPACE_ADDR_WIDTH,

    parameter               CACHE_ADDR_WIDTH        =       log2b(ICM_ENTRY_NUM * ICM_SLOT_SIZE),
    parameter               CACHE_ENTRY_WIDTH       =       256,
    parameter               CACHE_SET_NUM           =       1024,
    parameter               CACHE_SET_NUM_LOG       =       log2b(CACHE_SET_NUM - 1),
    parameter               CACHE_OFFSET_WIDTH      =       log2b(ICM_SLOT_SIZE - 1),
    parameter               CACHE_TAG_WIDTH         =       CACHE_ADDR_WIDTH - CACHE_OFFSET_WIDTH - CACHE_SET_NUM_LOG,
    parameter               PHYSICAL_ADDR_WIDTH     =       `PHY_SPACE_ADDR_WIDTH,
    parameter               COUNT_MAX               =       2,
    parameter               COUNT_MAX_LOG           =       log2b(COUNT_MAX - 1) + 1,
    parameter               REQ_TAG_NUM             =       `REQ_TAG_NUM,
    parameter               REQ_TAG_NUM_LOG         =       log2b(REQ_TAG_NUM - 1),
    parameter               REORDER_BUFFER_WIDTH    =       (ICM_CACHE_TYPE == `CACHE_TYPE_MTT) ? CACHE_ENTRY_WIDTH * 2 + COUNT_MAX_LOG : CACHE_ENTRY_WIDTH + COUNT_MAX_LOG 
)
(
    input   wire                                                                                                clk,
    input   wire                                                                                                rst,

//ICM Get Req Interface
    input   wire                                                                                                icm_get_req_valid,
    input   wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]        icm_get_req_head,
    output  wire                                                                                                icm_get_req_ready,

//ICM Get Resp Interface
    output  wire                                                                                                icm_get_rsp_valid,
    output  wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]        icm_get_rsp_head,
    output  wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                 icm_get_rsp_data,
    input   wire                                                                                                icm_get_rsp_ready,

//Cache Set Req Interface
    input   wire                                                                                                icm_set_req_valid,
    input   wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]        icm_set_req_head,
    input   wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                 icm_set_req_data,
    output  wire                                                                                                icm_set_req_ready,

//Cache Del Req Interface
    input   wire                                                                                                icm_del_req_valid,
    input   wire    [CACHE_ADDR_WIDTH - 1 : 0]                                                                  icm_del_req_head,
    output  wire                                                                                                icm_del_req_ready,

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
    output  wire                                                                                                dma_rd_rsp_ready,

//DMA Write Req Interface
    output  wire                                                                                                dma_wr_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                                                                   dma_wr_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                                                                   dma_wr_req_data,
    output  wire                                                                                                dma_wr_req_last,
    input   wire                                                                                                dma_wr_req_ready,

//Set ICM Mapping Table Entry
    input   wire                                                                                                icm_mapping_set_valid,
    input   wire    [`PAGE_FRAME_WIDTH - 1 : 0]                                                                 icm_mapping_set_head,
    input   wire    [`PAGE_FRAME_WIDTH - 1 : 0]                                                                 icm_mapping_set_data,

//Mapping Lookup Interface
    input   wire                                                                                                icm_mapping_lookup_valid,
    input   wire    [ICM_ENTRY_NUM_LOG - 1 : 0]                                                                 icm_mapping_lookup_head,

    output  wire                                                                                                icm_mapping_rsp_valid,
    output  wire    [ICM_ADDR_WIDTH - 1 : 0]                                                                    icm_mapping_rsp_icm_addr,
    output  wire    [PHYSICAL_ADDR_WIDTH - 1 : 0]                                                               icm_mapping_rsp_phy_addr,

    input   wire    [ICM_ADDR_WIDTH - 1 : 0]                                                                    icm_base
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/

/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                                                                                cache_get_req_valid;
wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]        cache_get_req_head ;
wire                                                                                                cache_get_req_ready;

wire                                                                                                cache_get_rsp_valid;
wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH + 1 - 1 : 0]    cache_get_rsp_head ;
wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                 cache_get_rsp_data ;
wire                                                                                                cache_get_rsp_ready;

wire                                                                                                cache_set_req_valid;
wire    [ICM_ADDR_WIDTH - 1 : 0]                                                                    cache_set_req_head ;
wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                 cache_set_req_data ;
wire                                                                                                cache_set_req_ready;

wire                                                                                                cache_del_req_valid;
wire    [ICM_ADDR_WIDTH - 1 : 0]                                                                    cache_del_req_head ;
wire                                                                                                cache_del_req_ready;

//From ICMGetProc to ICMSetDelProc, update cache entry
wire                                                                                                replace_req_valid;
wire    [ICM_ADDR_WIDTH - 1 : 0]                                                                    replace_req_head ;
wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                 replace_req_data ;
wire                                                                                                replace_req_ready;

/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
ICMGetProc
#(
    .ICM_CACHE_TYPE          (  ICM_CACHE_TYPE          ),
    .ICM_PAGE_NUM            (  ICM_PAGE_NUM            ),
    .ICM_PAGE_NUM_LOG        (  ICM_PAGE_NUM_LOG        ),
    .ICM_ENTRY_NUM           (  ICM_ENTRY_NUM           ),
    .ICM_ENTRY_NUM_LOG       (  ICM_ENTRY_NUM_LOG       ),
    .ICM_SLOT_SIZE           (  ICM_SLOT_SIZE           ),
    .ICM_ADDR_WIDTH          (  ICM_ADDR_WIDTH          ),

    .CACHE_ADDR_WIDTH        (  CACHE_ADDR_WIDTH        ),
    .CACHE_ENTRY_WIDTH       (  CACHE_ENTRY_WIDTH       ),
    .CACHE_SET_NUM           (  CACHE_SET_NUM           ),
    .CACHE_SET_NUM_LOG       (  CACHE_SET_NUM_LOG       ),
    .CACHE_OFFSET_WIDTH      (  CACHE_OFFSET_WIDTH      ),
    .CACHE_TAG_WIDTH         (  CACHE_TAG_WIDTH         ),
    .PHYSICAL_ADDR_WIDTH     (  PHYSICAL_ADDR_WIDTH     ),
    .COUNT_MAX               (  COUNT_MAX               ),
    .COUNT_MAX_LOG           (  COUNT_MAX_LOG           ),
    .REQ_TAG_NUM             (  REQ_TAG_NUM             ),
    .REQ_TAG_NUM_LOG         (  REQ_TAG_NUM_LOG         ),
    .REORDER_BUFFER_WIDTH    (  REORDER_BUFFER_WIDTH    ) 
)
ICMGetProc_Inst
(
    .clk                     (   clk                    ),
    .rst                     (   rst                    ),

    .icm_get_req_valid       (   icm_get_req_valid      ),
    .icm_get_req_head        (   icm_get_req_head       ),
    .icm_get_req_ready       (   icm_get_req_ready      ),

    .icm_get_rsp_valid       (   icm_get_rsp_valid      ),
    .icm_get_rsp_head        (   icm_get_rsp_head       ),
    .icm_get_rsp_data        (   icm_get_rsp_data       ),
    .icm_get_rsp_ready       (   icm_get_rsp_ready      ),

    .cache_get_req_valid     (   cache_get_req_valid    ),
    .cache_get_req_head      (   cache_get_req_head     ),
    .cache_get_req_ready     (   cache_get_req_ready    ),

    .cache_get_rsp_valid     (   cache_get_rsp_valid    ),
    .cache_get_rsp_head      (   cache_get_rsp_head     ),
    .cache_get_rsp_data      (   cache_get_rsp_data     ),
    .cache_get_rsp_ready     (   cache_get_rsp_ready    ),

    .cache_set_req_valid     (   replace_req_valid      ),
    .cache_set_req_head      (   replace_req_head       ),
    .cache_set_req_data      (   replace_req_data       ),
    .cache_set_req_ready     (   replace_req_ready      ),

    .dma_rd_req_valid        (   dma_rd_req_valid       ),
    .dma_rd_req_head         (   dma_rd_req_head        ),
    .dma_rd_req_data         (   dma_rd_req_data        ),
    .dma_rd_req_last         (   dma_rd_req_last        ),
    .dma_rd_req_ready        (   dma_rd_req_ready       ),
    
    .dma_rd_rsp_valid        (   dma_rd_rsp_valid      ),
    .dma_rd_rsp_head         (   dma_rd_rsp_head       ),
    .dma_rd_rsp_data         (   dma_rd_rsp_data       ),
    .dma_rd_rsp_last         (   dma_rd_rsp_last       ),
    .dma_rd_rsp_ready        (   dma_rd_rsp_ready      )
);

ICMSetDelProc
#(
    .ICM_CACHE_TYPE          (  ICM_CACHE_TYPE          ),
    .ICM_PAGE_NUM            (  ICM_PAGE_NUM            ),
    .ICM_PAGE_NUM_LOG        (  ICM_PAGE_NUM_LOG        ),
    .ICM_ENTRY_NUM           (  ICM_ENTRY_NUM           ),
    .ICM_ENTRY_NUM_LOG       (  ICM_ENTRY_NUM_LOG       ),
    .ICM_SLOT_SIZE           (  ICM_SLOT_SIZE           ),
    .ICM_ADDR_WIDTH          (  ICM_ADDR_WIDTH          ),

    .CACHE_ADDR_WIDTH        (  CACHE_ADDR_WIDTH        ),
    .CACHE_ENTRY_WIDTH       (  CACHE_ENTRY_WIDTH       ),
    .CACHE_SET_NUM           (  CACHE_SET_NUM           ),
    .CACHE_SET_NUM_LOG       (  CACHE_SET_NUM_LOG       ),
    .CACHE_OFFSET_WIDTH      (  CACHE_OFFSET_WIDTH      ),
    .CACHE_TAG_WIDTH         (  CACHE_TAG_WIDTH         ),
    .PHYSICAL_ADDR_WIDTH     (  PHYSICAL_ADDR_WIDTH     ),
    .COUNT_MAX               (  COUNT_MAX               ),
    .COUNT_MAX_LOG           (  COUNT_MAX_LOG           ),
    .REQ_TAG_NUM             (  REQ_TAG_NUM             ),
    .REQ_TAG_NUM_LOG         (  REQ_TAG_NUM_LOG         ),
    .REORDER_BUFFER_WIDTH    (  REORDER_BUFFER_WIDTH    ) 
)
ICMSetDelProc_Inst
(
    .clk                     (  clk                     ),
    .rst                     (  rst                     ),

    .set_req_valid_chnl_0    (  replace_req_valid       ),
    .set_req_head_chnl_0     (  replace_req_head        ),
    .set_req_data_chnl_0     (  replace_req_data        ),
    .set_req_ready_chnl_0    (  replace_req_ready       ),

    .set_req_valid_chnl_1    (  icm_set_req_valid       ),
    .set_req_head_chnl_1     (  icm_set_req_head        ),
    .set_req_data_chnl_1     (  icm_set_req_data        ),
    .set_req_ready_chnl_1    (  icm_set_req_ready       ),

    .del_req_valid           (  icm_del_req_valid       ),
    .del_req_head            (  icm_del_req_head        ),
    .del_req_ready           (  icm_del_req_ready       ),
    
    .cache_set_req_valid     (  cache_set_req_valid     ),
    .cache_set_req_head      (  cache_set_req_head      ),
    .cache_set_req_data      (  cache_set_req_data      ),
    .cache_set_req_ready     (  cache_set_req_ready     ),
        
    .cache_del_req_valid     (  cache_del_req_valid     ),
    .cache_del_req_head      (  cache_del_req_head      ),
    .cache_del_req_ready     (  cache_del_req_ready     ),

    .dma_wr_req_valid       (   dma_wr_req_valid       ),
    .dma_wr_req_head        (   dma_wr_req_head        ),
    .dma_wr_req_data        (   dma_wr_req_data        ),
    .dma_wr_req_last        (   dma_wr_req_last        ),
    .dma_wr_req_ready       (   dma_wr_req_ready       )
);

ICMBuffer
#(
    .ICM_CACHE_TYPE          (  ICM_CACHE_TYPE          ),
    .ICM_PAGE_NUM            (  ICM_PAGE_NUM            ),
    .ICM_PAGE_NUM_LOG        (  ICM_PAGE_NUM_LOG        ),
    .ICM_ENTRY_NUM           (  ICM_ENTRY_NUM           ),
    .ICM_ENTRY_NUM_LOG       (  ICM_ENTRY_NUM_LOG       ),
    .ICM_SLOT_SIZE           (  ICM_SLOT_SIZE           ),
    .ICM_ADDR_WIDTH          (  ICM_ADDR_WIDTH          ),

    .CACHE_ADDR_WIDTH        (   CACHE_ADDR_WIDTH        ),
    .CACHE_ENTRY_WIDTH       (   CACHE_ENTRY_WIDTH       ),
    .CACHE_SET_NUM           (   CACHE_SET_NUM           ),
    .CACHE_SET_NUM_LOG       (   CACHE_SET_NUM_LOG       ),
    .CACHE_OFFSET_WIDTH      (   CACHE_OFFSET_WIDTH      ),
    .CACHE_TAG_WIDTH         (   CACHE_TAG_WIDTH         ),
    .PHYSICAL_ADDR_WIDTH     (   PHYSICAL_ADDR_WIDTH     ),
    .COUNT_MAX               (   COUNT_MAX               ),
    .COUNT_MAX_LOG           (   COUNT_MAX_LOG           ),
    .REQ_TAG_NUM             (   REQ_TAG_NUM             ),
    .REQ_TAG_NUM_LOG         (   REQ_TAG_NUM_LOG         )
)
ICMBuffer_Inst
(
    .clk                      (   clk                     ),
    .rst                      (   rst                     ),

    .get_req_valid            (   cache_get_req_valid     ),
    .get_req_head             (   cache_get_req_head      ),
    .get_req_ready            (   cache_get_req_ready     ),

    .get_rsp_valid            (   cache_get_rsp_valid     ),
    .get_rsp_head             (   cache_get_rsp_head      ),
    .get_rsp_data             (   cache_get_rsp_data      ),
    .get_rsp_ready            (   cache_get_rsp_ready     ),

    .set_req_valid            (   cache_set_req_valid     ),
    .set_req_head             (   cache_set_req_head      ),
    .set_req_data             (   cache_set_req_data      ),
    .set_req_ready            (   cache_set_req_ready     ),

    .del_req_valid            (   cache_del_req_valid     ),
    .del_req_head             (   cache_del_req_head      ),
    .del_req_ready            (   cache_del_req_ready     )
);

ICMMetaProc
#(
    .ICM_CACHE_TYPE           (   ICM_CACHE_TYPE             ),
    .ICM_PAGE_NUM             (   ICM_PAGE_NUM               ),
    .ICM_ENTRY_NUM            (   ICM_ENTRY_NUM              ),
    .ICM_SLOT_SIZE            (   ICM_SLOT_SIZE              )
)
ICMMetaProc_Inst
(
    .clk                        (   clk                        ),
    .rst                        (   rst                        ),

    .icm_mapping_set_valid      (   icm_mapping_set_valid      ),
    .icm_mapping_set_head       (   icm_mapping_set_head       ),
    .icm_mapping_set_data       (   icm_mapping_set_data       ),

    .icm_mapping_lookup_valid   (   icm_mapping_lookup_valid   ),
    .icm_mapping_lookup_head    (   icm_mapping_lookup_head    ),

    .icm_mapping_rsp_valid      (   icm_mapping_rsp_valid      ),
    .icm_mapping_rsp_icm_addr   (   icm_mapping_rsp_icm_addr   ),
    .icm_mapping_rsp_phy_addr   (   icm_mapping_rsp_phy_addr   ),

    .icm_base                   (   icm_base                    )
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule