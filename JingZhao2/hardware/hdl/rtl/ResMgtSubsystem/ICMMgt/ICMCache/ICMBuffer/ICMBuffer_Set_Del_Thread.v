/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ICMBuffer_Set_Del_Thread
Author:     YangFan
Function:   Set/Del entry from SRAM.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module ICMBuffer_Set_Del_Thread
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

//Cache Set Req Interface
    input   wire                                                                                                set_req_valid,
    input   wire    [ICM_ADDR_WIDTH - 1 : 0]                                                                    set_req_head,
    input   wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                 set_req_data,
    output  wire                                                                                                set_req_ready,

//Cache Del Req Interface
    input   wire                                                                                                del_req_valid,
    input   wire    [ICM_ADDR_WIDTH - 1 : 0]                                                                    del_req_head,
    output  wire                                                                                                del_req_ready,

//SRAM operation
    output  reg     [0:0]                                                                                       way_0_wen,
    output  reg     [CACHE_SET_NUM_LOG - 1 : 0]                                                                 way_0_addr,
    output  reg     [CACHE_ENTRY_WIDTH + CACHE_TAG_WIDTH + 1 - 1 : 0]                                           way_0_din,
    input   wire    [CACHE_ENTRY_WIDTH + CACHE_TAG_WIDTH + 1 - 1 : 0]                                           way_0_dout,


    output  reg     [0:0]                                                                                       way_1_wen,
    output  reg     [CACHE_SET_NUM_LOG - 1 : 0]                                                                 way_1_addr,
    output  reg     [CACHE_ENTRY_WIDTH + CACHE_TAG_WIDTH + 1 - 1 : 0]                                           way_1_din,
    input   wire    [CACHE_ENTRY_WIDTH + CACHE_TAG_WIDTH + 1 - 1 : 0]                                           way_1_dout,

    output  reg     [0:0]                                                                                       lru_wen,
    output  reg     [CACHE_SET_NUM_LOG - 1 : 0]                                                                 lru_addr,
    output  reg     [0:0]                                                                                       lru_din,
    input   wire    [0:0]                                                                                       lru_dout
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     VALID       1'b1
`define     INVALID     1'b0
`define     WAY_0       1'b0
`define     WAY_1       1'b1
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg         [COUNT_MAX_LOG * 2 + REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]            set_req_head_diff;
reg         [COUNT_MAX_LOG * 2 + REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]            del_req_head_diff;
reg         [CACHE_ENTRY_WIDTH - 1 : 0]                                                                     set_req_data_diff;
wire        [CACHE_ADDR_WIDTH - 1 : 0]                                                                      cache_addr;
wire        [CACHE_TAG_WIDTH - 1 : 0]                                                                       cache_tag;
wire        [CACHE_SET_NUM_LOG - 1 : 0]                                                                     cache_set;            
wire        [CACHE_ENTRY_WIDTH - 1 : 0]                                                                     cache_data;

wire                                                                                                        way_0_hit;
wire                                                                                                        way_1_hit;

/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg         [1:0]           cur_state;
reg         [1:0]           next_state;

parameter   [1:0]           IDLE_s = 2'd1,
                            SET_s = 2'd2,
                            DEL_s = 2'd3;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        cur_state <= IDLE_s;
    end
    else begin
        cur_state <= next_state;
    end
end

always @(*) begin
    case(cur_state) 
        IDLE_s:     if(set_req_valid) begin
                        next_state = SET_s;
                    end
                    else if(del_req_valid) begin
                        next_state = DEL_s;
                    end
                    else begin
                        next_state = IDLE_s;
                    end
        SET_s:      next_state = IDLE_s;
        DEL_s:      next_state = IDLE_s;
        default:    next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- set_req_head_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        set_req_head_diff <= 'd0;
    end
    else if(cur_state == IDLE_s && set_req_valid) begin
        set_req_head_diff <= set_req_head;
    end
    else if(cur_state == SET_s) begin
        set_req_head_diff <= 'd0;
    end
    else begin
        set_req_head_diff <= set_req_head_diff;
    end
end

//-- del_req_head_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        del_req_head_diff <= 'd0;
    end
    else if(cur_state == IDLE_s && del_req_valid) begin
        del_req_head_diff <= del_req_head;
    end
    else if(cur_state == DEL_s) begin
        del_req_head_diff <= 'd0;
    end
    else begin
        del_req_head_diff <= del_req_head_diff;
    end
end

//-- set_req_data_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        set_req_data_diff <= 'd0;
    end
    else if(cur_state == IDLE_s && set_req_valid) begin
        set_req_data_diff <= set_req_data;
    end
    else if(cur_state == SET_s) begin
        set_req_data_diff <= 'd0;
    end
    else begin
        set_req_data_diff <= set_req_data_diff;
    end
end

//-- cache_addr --
assign cache_addr = (cur_state == IDLE_s && set_req_valid) ? set_req_head[CACHE_ADDR_WIDTH - 1 : 0] : 
                    (cur_state == IDLE_s && del_req_valid) ? del_req_head[CACHE_ADDR_WIDTH - 1 : 0] : 
                    (cur_state == SET_s) ? set_req_head_diff[CACHE_ADDR_WIDTH - 1 : 0] :
                    (cur_state == DEL_s) ? del_req_head_diff[CACHE_ADDR_WIDTH - 1 : 0] : 'd0;

//-- cache_tag --
assign cache_tag = cache_addr[CACHE_TAG_WIDTH + CACHE_SET_NUM_LOG + CACHE_OFFSET_WIDTH - 1 : CACHE_SET_NUM_LOG + CACHE_OFFSET_WIDTH];
                   

//-- cache_set --
assign cache_set = cache_addr[CACHE_SET_NUM_LOG + CACHE_OFFSET_WIDTH - 1 : CACHE_OFFSET_WIDTH];  

//-- cache_data --
assign cache_data = (cur_state == IDLE_s && set_req_valid) ? set_req_data :
                    (cur_state == SET_s) ? set_req_data_diff : 'd0;

//-- way_0_hit --
assign way_0_hit = (cache_tag == way_0_dout[CACHE_TAG_WIDTH + CACHE_ENTRY_WIDTH - 1 : CACHE_ENTRY_WIDTH]) && (way_0_dout[CACHE_TAG_WIDTH + CACHE_ENTRY_WIDTH] == `VALID);

//-- way_1_hit --
assign way_1_hit = (cache_tag == way_1_dout[CACHE_TAG_WIDTH + CACHE_ENTRY_WIDTH - 1 : CACHE_ENTRY_WIDTH]) && (way_1_dout[CACHE_TAG_WIDTH + CACHE_ENTRY_WIDTH] == `VALID);

//-- way_0_wen --
//-- way_0_addr --
//-- way_0_din --
always @(*) begin
    if(rst) begin
        way_0_wen = 'd0;
        way_0_addr = 'd0;
        way_0_din = 'd0;
    end
    else if(cur_state == IDLE_s && (set_req_valid || del_req_valid)) begin
        way_0_wen = 'd0;
        way_0_addr = cache_set;
        way_0_din = 'd0;      
    end
    else if(cur_state == SET_s) begin
        way_0_wen = (lru_dout == `WAY_1) ? 'd1 : 'd0;
        way_0_addr = (lru_dout == `WAY_1) ? cache_set : 'd0;
        way_0_din = (lru_dout == `WAY_1) ? {`VALID, cache_tag, cache_data} : 'd0;
    end
    else if(cur_state == DEL_s) begin
        way_0_wen = way_0_hit ? 'd1 : 'd0;
        way_0_addr = way_0_hit ? cache_set : 'd0;
        way_0_din = way_0_hit ? {`VALID, {CACHE_TAG_WIDTH{1'b0}}, {CACHE_ENTRY_WIDTH{1'b0}}} : 'd0;
    end
    else begin
        way_0_wen = 'd0;
        way_0_addr = 'd0;
        way_0_din = 'd0;        
    end
end

//-- way_1_wen --
//-- way_1_addr --
//-- way_1_din --
always @(*) begin
    if(rst) begin
        way_1_wen = 'd0;
        way_1_addr = 'd0;
        way_1_din = 'd0;
    end
    else if(cur_state == IDLE_s && (set_req_valid || del_req_valid)) begin
        way_1_wen = 'd0;
        way_1_addr = cache_set;
        way_1_din = 'd0;      
    end
    else if(cur_state == SET_s) begin
        way_1_wen = (lru_dout == `WAY_0) ? 'd1 : 'd0;
        way_1_addr = (lru_dout == `WAY_0) ? cache_set : 'd0;
        way_1_din = (lru_dout == `WAY_0) ? {`VALID, cache_tag, cache_data} : 'd0;
    end
    else if(cur_state == DEL_s) begin
        way_1_wen = way_1_hit ? 'd1 : 'd0;
        way_1_addr = way_1_hit ? cache_set : 'd0;
        way_1_din = way_1_hit ? {`VALID, {CACHE_TAG_WIDTH{1'b0}}, {CACHE_ENTRY_WIDTH{1'b0}}} : 'd0;
    end
    else begin
        way_1_wen = 'd0;
        way_1_addr = 'd0;
        way_1_din = 'd0;        
    end
end

//-- lru_wen --
//-- lru_addr --
//-- lru_din --
always @(*) begin
    if(rst) begin
        lru_wen = 'd0;
        lru_addr = 'd0;
        lru_din = 'd0;
    end
    else if(cur_state == IDLE_s && set_req_valid) begin
        lru_wen = 'd0;
        lru_addr = cache_set;
        lru_din = 'd0;
    end
    else if(cur_state == SET_s) begin
        lru_wen = 'd1;
        lru_addr = cache_set;
        lru_din = (lru_dout == `WAY_0) ? `WAY_1 : `WAY_0;
    end
    else begin
        lru_wen = 'd0;
        lru_addr = 'd0;
        lru_din = 'd0;
    end
end

//-- set_req_ready --
assign set_req_ready = (cur_state == SET_s);

//-- del_req_ready --
assign del_req_ready = (cur_state == DEL_s);
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef              VALID
`undef              INVALID
`undef              WAY_0
`undef              WAY_1
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule