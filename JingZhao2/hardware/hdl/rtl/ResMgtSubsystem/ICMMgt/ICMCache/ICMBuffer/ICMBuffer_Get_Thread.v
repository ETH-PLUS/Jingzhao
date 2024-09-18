/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ICMBuffer_Get_Thread
Author:     YangFan
Function:   Get entry from SRAM.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module ICMBuffer_Get_Thread
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

//Cache Get Req Interface
    input   wire                                                                                                get_req_valid,
    input   wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]        get_req_head,
    output  wire                                                                                                get_req_ready,

//Cache Get Resp Interface
    output  wire                                                                                                get_rsp_valid,
    output  wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH + 1 - 1 : 0]    get_rsp_head,
    output  wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                 get_rsp_data,
    input   wire                                                                                                get_rsp_ready,

//SRAM operation
    output  wire    [0:0]                                                                                       way_0_wen,
    output  wire    [CACHE_SET_NUM_LOG - 1 : 0]                                                                 way_0_addr,
    output  wire    [CACHE_ENTRY_WIDTH + CACHE_TAG_WIDTH + 1 - 1 : 0]                                           way_0_din,
    input   wire    [CACHE_ENTRY_WIDTH + CACHE_TAG_WIDTH + 1 - 1 : 0]                                           way_0_dout,


    output  wire    [0:0]                                                                                       way_1_wen,
    output  wire    [CACHE_SET_NUM_LOG - 1 : 0]                                                                 way_1_addr,
    output  wire    [CACHE_ENTRY_WIDTH + CACHE_TAG_WIDTH + 1 - 1 : 0]                                           way_1_din,
    input   wire    [CACHE_ENTRY_WIDTH + CACHE_TAG_WIDTH + 1 - 1 : 0]                                           way_1_dout,

    output  wire    [0:0]                                                                                       lru_wen,
    output  wire    [CACHE_SET_NUM_LOG - 1 : 0]                                                                 lru_addr,
    output  wire    [0:0]                                                                                       lru_din,
    input   wire    [0:0]                                                                                       lru_dout
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     VALID       1'b1
`define     WAY_0       1'b0
`define     WAY_1       1'b1
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg         [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]            get_req_head_diff;
wire        [CACHE_ADDR_WIDTH - 1 : 0]                                                                      cache_addr;
wire        [CACHE_TAG_WIDTH - 1 : 0]                                                                       cache_tag;
wire        [CACHE_SET_NUM_LOG - 1 : 0]                                                                     cache_set;       

wire        [CACHE_TAG_WIDTH - 1 : 0]                                                                       way_0_cache_tag;
wire        [CACHE_TAG_WIDTH - 1 : 0]                                                                       way_1_cache_tag;
wire                                                                                                        way_0_valid;
wire                                                                                                        way_1_valid;

wire                                                                                                        cache_hit;
wire                                                                                                        way_0_hit;
wire                                                                                                        way_1_hit;

/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg             [1:0]                       cur_state;
reg             [1:0]                       next_state;

parameter       [1:0]                       IDLE_s = 2'd1,
                                            RSP_s = 2'd2;

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
        IDLE_s:         if(get_req_valid) begin
                                next_state = RSP_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
        RSP_s:          if(get_rsp_valid && get_rsp_ready) begin
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = RSP_s;
                            end
        default:            next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- get_req_head_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        get_req_head_diff <= 'd0;
    end
    else if(cur_state == IDLE_s && get_req_valid) begin
        get_req_head_diff <= get_req_head;
    end
    else if(cur_state == RSP_s && get_rsp_valid && get_rsp_ready) begin
        get_req_head_diff <= 'd0;
    end
    else begin
        get_req_head_diff <= get_req_head_diff;
    end
end

//-- cache_addr --
assign cache_addr = (cur_state == IDLE_s && get_req_valid) ? get_req_head[CACHE_ADDR_WIDTH - 1 : 0] : 
                    (cur_state == RSP_s) ? get_req_head_diff[CACHE_ADDR_WIDTH - 1 : 0] : 'd0;

//-- cache_tag --
assign cache_tag = cache_addr[CACHE_TAG_WIDTH + CACHE_SET_NUM_LOG + CACHE_OFFSET_WIDTH - 1 : CACHE_SET_NUM_LOG + CACHE_OFFSET_WIDTH];
                   

//-- cache_set --
assign cache_set = cache_addr[CACHE_SET_NUM_LOG + CACHE_OFFSET_WIDTH - 1 : CACHE_OFFSET_WIDTH];  

//-- get_req_ready --
assign get_req_ready = (cur_state == RSP_s);

//-- get_rsp_valid --
//-- get_rsp_head --
//-- get_rsp_data --
assign get_rsp_valid = (cur_state == RSP_s) ? 'd1 : 'd0;
assign get_rsp_head = (cur_state == RSP_s) ? {cache_hit, get_req_head_diff} : 'd0;
assign get_rsp_data = (cur_state == RSP_s && way_0_hit) ? way_0_dout :
                      (cur_state == RSP_s && way_1_hit) ? way_1_dout : 'd0;


//-- cache_hit --
assign cache_hit = (way_0_hit || way_1_hit);

//-- way_0_hit --
assign way_0_hit = (cache_tag == way_0_cache_tag) && (way_0_valid == `VALID);

//-- way_1_hit --
assign way_1_hit = (cache_tag == way_1_cache_tag) && (way_1_valid == `VALID);

//-- way_0_cache_tag --
//-- way_1_cache_tag --
//-- way_0_valid --
//-- way_1_valid --
assign way_0_cache_tag = way_0_dout[CACHE_TAG_WIDTH + CACHE_ENTRY_WIDTH - 1 : CACHE_ENTRY_WIDTH];
assign way_1_cache_tag = way_1_dout[CACHE_TAG_WIDTH + CACHE_ENTRY_WIDTH - 1 : CACHE_ENTRY_WIDTH];
assign way_0_valid = way_0_dout[CACHE_TAG_WIDTH + CACHE_ENTRY_WIDTH];
assign way_1_valid = way_1_dout[CACHE_TAG_WIDTH + CACHE_ENTRY_WIDTH];

//-- way_0_wen --
//-- way_0_addr --
//-- way_0_din --
assign way_0_wen = 'd0;     //Always read
assign way_0_addr = ((cur_state == IDLE_s && get_req_valid) || (cur_state == RSP_s)) ? cache_set : 'd0;
assign way_0_din = 'd0;

//-- way_1_wen --
//-- way_1_addr --
//-- way_1_din --
assign way_1_wen = 'd0;     //Always read
assign way_1_addr = ((cur_state == IDLE_s && get_req_valid) || (cur_state == RSP_s)) ? cache_set : 'd0;
assign way_1_din = 'd0;

//-- lru_wen --
//-- lru_addr --
//-- lru_din --
assign lru_wen = (cur_state == RSP_s && cache_hit) ? 'd1 : 'd0;
assign lru_addr = (cur_state == RSP_s && cache_hit) ? cache_set : 'd0;
assign lru_din = (cur_state == RSP_s && way_0_hit) ? `WAY_0 :
                     (cur_state == RSP_s && way_1_hit) ? `WAY_1 : 'd0;

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef              VALID
`undef              WAY_0
`undef              WAY_1
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule