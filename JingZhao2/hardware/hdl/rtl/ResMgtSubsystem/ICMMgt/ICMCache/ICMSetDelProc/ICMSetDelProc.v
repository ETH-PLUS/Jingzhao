/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ICMSetDel
Author:     YangFan
Function:   Handle ICM Set/Del Request.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module ICMSetDelProc
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

//Interface for ICMGetProc to update cache entry
    input   wire                                                                                                        set_req_valid_chnl_0,
    input   wire    [`REQ_TAG_NUM_LOG + `COUNT_MAX_LOG * 2 + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]              set_req_head_chnl_0,
    input   wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                         set_req_data_chnl_0,
    output  wire                                                                                                        set_req_ready_chnl_0,

//Interface for SWAccCM/MRCtl to set cache entry
    input   wire                                                                                                        set_req_valid_chnl_1,
    input   wire    [`REQ_TAG_NUM_LOG + `COUNT_MAX_LOG * 2 + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]              set_req_head_chnl_1,
    input   wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                         set_req_data_chnl_1,
    output  wire                                                                                                        set_req_ready_chnl_1,

//Interface for SWAccCM/MRCtl to invalidate cache entry
    input   wire                                                                                                del_req_valid,
    input   wire    [ICM_ADDR_WIDTH - 1 : 0]                                                                    del_req_head,
    output  wire                                                                                                del_req_ready,
    
//ICMBuffer Set Req Interface
    output  wire                                                                                                cache_set_req_valid,
    output  wire    [ICM_ADDR_WIDTH - 1 : 0]                                                                    cache_set_req_head,
    output  wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                 cache_set_req_data,
    input   wire                                                                                                cache_set_req_ready,

//ICMBuffer Del Req Interface
    output  wire                                                                                                cache_del_req_valid,
    output  wire    [ICM_ADDR_WIDTH - 1 : 0]                                                                    cache_del_req_head,
    input   wire                                                                                                cache_del_req_ready,

//Interface with DMA
    output  wire                                                                                                dma_wr_req_valid,
    output  wire    [`DMA_HEAD_WIDTH - 1 : 0]                                                                   dma_wr_req_head,
    output  wire    [`DMA_DATA_WIDTH - 1 : 0]                                                                   dma_wr_req_data,
    output  wire                                                                                                dma_wr_req_last,
    input   wire                                                                                                dma_wr_req_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     CHNL_0                  0
`define     CHNL_1                  1

`define     DMA_ADDR_OFFSET         127:64
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg                                                     last_scheduled_chnl;

reg                     [31:0]                          dma_len;
reg                     [63:0]                          dma_addr;

reg                     [CACHE_ENTRY_WIDTH - 1 : 0]     set_req_data_chnl_1_diff;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg                     [2:0]                   cur_state;
reg                     [2:0]                   next_state;

parameter               [2:0]                   IDLE_s      = 3'd1,
                                                CHNL_0_s    = 3'd2,
                                                CHNL_1_s    = 3'd3,
                                                WT_s        = 3'd4;     //Cache Write Through

always @(posedge clk or posedge rst) begin
    if (rst) begin
        cur_state <= IDLE_s;        
    end
    else begin
        cur_state <= next_state;
    end
end

always @(*) begin
    case(cur_state)
        IDLE_s:         if(set_req_valid_chnl_0 && last_scheduled_chnl == `CHNL_1) begin
                            next_state = CHNL_0_s;
                        end
                        else if(set_req_valid_chnl_0 && !set_req_valid_chnl_1) begin
                            next_state = CHNL_0_s;
                        end
                        else if(set_req_valid_chnl_1 && last_scheduled_chnl == `CHNL_0) begin
                            next_state = CHNL_1_s;
                        end
                        else if(set_req_valid_chnl_1 && !set_req_valid_chnl_0) begin
                            next_state = CHNL_1_s;
                        end
                        else begin
                            next_state = IDLE_s;
                        end
        CHNL_0_s:       if(cache_set_req_valid && cache_set_req_ready) begin
                            next_state = IDLE_s;
                        end
                        else begin
                            next_state = CHNL_0_s;
                        end
        CHNL_1_s:       if(cache_set_req_valid && cache_set_req_ready) begin
                            next_state = WT_s;
                        end
                        else begin
                            next_state = CHNL_1_s;
                        end
        WT_s:           if(dma_wr_req_valid && dma_wr_req_ready) begin
                            next_state = IDLE_s;
                        end
                        else begin
                            next_state = WT_s;
                        end
        default:        next_state = IDLE_s;
    endcase
end

/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- last_scheduled_chnl --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        last_scheduled_chnl <= 'd0;        
    end
    else if (cur_state == CHNL_0_s) begin
        last_scheduled_chnl <= `CHNL_0;
    end
    else if (cur_state == CHNL_1_s) begin
        last_scheduled_chnl <= `CHNL_1;
    end
    else begin
        last_scheduled_chnl <= last_scheduled_chnl;
    end
end

//-- set_req_ready_chnl_0 --
assign set_req_ready_chnl_0 = (cur_state == CHNL_0_s) ? cache_set_req_ready : 'd0;

//-- set_req_ready_chnl_1 --
assign set_req_ready_chnl_1 = (cur_state == CHNL_1_s) ? cache_set_req_ready : 'd0;    

//-- del_req_ready --
assign del_req_ready = cache_del_req_ready;
    
//-- cache_set_req_valid --
//-- cache_set_req_head --
//-- cache_set_req_data --
assign cache_set_req_valid = (cur_state == CHNL_0_s) ? set_req_valid_chnl_0 : 
                             (cur_state == CHNL_1_s) ? set_req_valid_chnl_1 : 'd0;
assign cache_set_req_head =  (cur_state == CHNL_0_s) ? set_req_head_chnl_0[CACHE_ADDR_WIDTH - 1 : 0] :
                             (cur_state == CHNL_1_s) ? set_req_head_chnl_1[CACHE_ADDR_WIDTH - 1 : 0]  : 'd0;
assign cache_set_req_data =  (cur_state == CHNL_0_s) ? set_req_data_chnl_0 : 
                             (cur_state == CHNL_1_s) ? set_req_data_chnl_1 : 'd0;

//-- cache_del_req_valid --
//-- cache_del_req_head --
assign cache_del_req_valid = del_req_valid;
assign cache_del_req_head = del_req_head;

//-- dma_len --
//-- dma_addr --
//-- set_req_data_chnl_1_diff --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dma_len <= 'd0;
        dma_addr <= 'd0;
        set_req_data_chnl_1_diff <= 'd0;
    end
    else if (cur_state == CHNL_1_s) begin
        dma_len <= CACHE_ENTRY_WIDTH / 8;
        dma_addr <= set_req_head_chnl_1[`DMA_ADDR_OFFSET];
        set_req_data_chnl_1_diff <= set_req_data_chnl_1;
    end
    else begin
        dma_len <= dma_len;
        dma_addr <= dma_addr;
        set_req_data_chnl_1_diff <= set_req_data_chnl_1_diff;
    end
end

//-- dma_wr_req_valid --
//-- dma_wr_req_head --
//-- dma_wr_req_data --
//-- dma_wr_req_last --
assign dma_wr_req_valid = (cur_state == WT_s) ? 'd1 : 'd0;
assign dma_wr_req_head = (cur_state == WT_s) ? {32'd0, dma_addr, dma_len} : 'd0;
assign dma_wr_req_data= (cur_state == WT_s) ? set_req_data_chnl_1_diff : 'd0;
assign dma_wr_req_last = (cur_state == WT_s) ? 'd1 : 'd0;

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef  CHNL_0
`undef  CHNL_1

`undef  DMA_ADDR_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule