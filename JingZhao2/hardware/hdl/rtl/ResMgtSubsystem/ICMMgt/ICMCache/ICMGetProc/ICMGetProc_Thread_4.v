/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ICMGetProc_Thread_4
Author:     YangFan
Function:   Deal with Cache Hit and Cache Miss.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module ICMGetProc_Thread_4
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

//ReqHitFIFO Interface
    output  wire                                                                                                req_hit_rd_en,
    input   wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   req_hit_dout,
    input   wire                                                                                                req_hit_empty,

//ReqHitFIFO Interface
    output  wire                                                                                                req_miss_rd_en,
    input   wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   req_miss_dout,
    input   wire                                                                                                req_miss_empty,

//ReorderBuffer Interface
    output  reg                                                                                                 reorder_buffer_wen,
    output  reg     [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                              reorder_buffer_addr,
    output  reg     [REORDER_BUFFER_WIDTH - 1 : 0]                                                              reorder_buffer_din,
    input   wire    [REORDER_BUFFER_WIDTH - 1 : 0]                                                              reorder_buffer_dout,

//ICM Entry from Memory
    input   wire                                                                                                icm_entry_rsp_valid,
    input   wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                 icm_entry_rsp_data,
    output  wire                                                                                                icm_entry_rsp_ready,

//Cache Set Req
    output  wire                                                                                                cache_set_req_valid,
    output  wire    [ICM_ADDR_WIDTH - 1 : 0]                                                                    cache_set_req_head,
    output  wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                 cache_set_req_data,
    input   wire                                                                                                cache_set_req_ready,

//ICM Get Resp Interface
    output  wire                                                                                                icm_get_rsp_valid,
    output  wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   icm_get_rsp_head,
    output  wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                 icm_get_rsp_data,
    input   wire                                                                                                icm_get_rsp_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg                                     is_hit_proc;
reg                                     is_miss_proc;

wire    [COUNT_MAX_LOG - 1 : 0]         count_collected;
wire    [COUNT_MAX_LOG - 1 : 0]         count_max;
wire    [COUNT_MAX_LOG - 1 : 0]         count_index;
wire    [`MAX_REQ_TAG_NUM_LOG - 1 : 0]       req_tag;

reg     [COUNT_MAX_LOG - 1 : 0]         rsp_count;
reg     [COUNT_MAX_LOG - 1 : 0]         rsp_total;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg             [2:0]           cur_state;
reg             [2:0]           next_state;

parameter       [2:0]           IDLE_s = 3'd1,
                                HIT_s = 3'd2,
                                MISS_s = 3'd3,
                                SET_s = 3'd4,
                                RSP_s = 3'd5;         

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
        IDLE_s:             if(!req_miss_empty && icm_entry_rsp_valid) begin    //Miss Req has higher priority
                                next_state = MISS_s;
                            end
                            else if(!req_hit_empty) begin
                                next_state = HIT_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
        HIT_s:              if(count_collected == count_max) begin
                                next_state = RSP_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
        MISS_s:             next_state = SET_s;
        SET_s:              if(count_collected == count_max && cache_set_req_valid && cache_set_req_ready) begin
                                next_state = RSP_s;
                            end
                            else if(count_collected < count_max && cache_set_req_valid && cache_set_req_ready) begin
                            	next_state = IDLE_s;		//Finish curren miss req, wait ultil all request are collected
                            end
                            else begin
                                next_state = SET_s;
                            end
        RSP_s:              if(icm_get_rsp_valid && icm_get_rsp_ready && (rsp_count == rsp_total)) begin
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
//-- req_hit_rd_en -- 
//Break timing loop
// assign req_hit_rd_en = (cur_state == HIT_s && next_state == IDLE_s) ? 'd1 :
//                         (cur_state == RSP_s && next_state == IDLE_s && is_hit_proc) ? 'd1 : 'd0;
assign req_hit_rd_en = (cur_state == HIT_s && (count_collected != count_max)) ? 'd1 :
                        (cur_state == RSP_s && (icm_get_rsp_valid && icm_get_rsp_ready && (rsp_count == rsp_total)) && is_hit_proc) ? 'd1 : 'd0;

//-- req_miss_rd_en --
// assign req_miss_rd_en = (cur_state == SET_s && next_state == IDLE_s) ? 'd1 :
//                         (cur_state == RSP_s && next_state == IDLE_s && is_miss_proc) ? 'd1 : 'd0;
assign req_miss_rd_en = (cur_state == SET_s && (count_collected < count_max && cache_set_req_valid && cache_set_req_ready)) ? 'd1 :
                        (cur_state == RSP_s && (icm_get_rsp_valid && icm_get_rsp_ready && (rsp_count == rsp_total)) && is_miss_proc) ? 'd1 : 'd0;

//-- count_collected --
assign count_collected = (cur_state != IDLE_s) ? reorder_buffer_dout[REORDER_BUFFER_WIDTH - 1 : REORDER_BUFFER_WIDTH - COUNT_MAX_LOG] : 'd0;

//-- count_max --
assign count_max = (cur_state == IDLE_s && req_miss_empty && !req_hit_empty) ? req_hit_dout[COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : COUNT_MAX_LOG + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH] : 
                   (cur_state == IDLE_s && !req_miss_empty && icm_entry_rsp_valid) ? req_miss_dout[COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : COUNT_MAX_LOG + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH] : 
                   is_miss_proc ? req_miss_dout[COUNT_MAX_LOG * 2+ `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : COUNT_MAX_LOG + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH] :
                   is_hit_proc ? req_hit_dout[COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : COUNT_MAX_LOG + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH] : 'd0; 

//-- count_index =-- 
assign count_index = (cur_state == IDLE_s && req_miss_empty && !req_hit_empty) ? req_hit_dout[COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : COUNT_MAX_LOG + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH] : 
                     (cur_state == IDLE_s && !req_miss_empty && icm_entry_rsp_valid) ? req_miss_dout[COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : COUNT_MAX_LOG + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH] : 
                     is_miss_proc ? req_miss_dout[COUNT_MAX_LOG + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH] :
                     is_hit_proc ? req_hit_dout[COUNT_MAX_LOG + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH] : 'd0; 

//-- req_tag --
assign req_tag = (cur_state == IDLE_s && req_miss_empty && !req_hit_empty) ? req_hit_dout[`MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH] : 
                   (cur_state == IDLE_s && !req_miss_empty && icm_entry_rsp_valid) ? req_miss_dout[`MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH] : 
                   is_miss_proc ? req_miss_dout[`MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH] :
                   is_hit_proc ? req_hit_dout[`MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH] : 'd0;

//-- is_hit_proc --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        is_hit_proc <= 'd0;
    end
    else if(cur_state == IDLE_s && !req_miss_empty && icm_entry_rsp_valid) begin        //Miss Req has higher priority
        is_hit_proc <= 'd0;
    end
    else if(cur_state == IDLE_s && req_miss_empty && !req_hit_empty) begin
        is_hit_proc <= 'd1;
    end
    else begin
        is_hit_proc <= is_hit_proc;
    end
end

//-- is_miss_proc --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        is_miss_proc <= 'd0;
    end
    else if(cur_state == IDLE_s && !req_miss_empty && icm_entry_rsp_valid) begin        //Miss Req has higher priority
        is_miss_proc <= 'd1;
    end
    else if(cur_state == IDLE_s && !req_hit_empty) begin
        is_miss_proc <= 'd0;
    end
    else begin
        is_miss_proc <= is_miss_proc;
    end
end

//-- rsp_count --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        rsp_count <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        rsp_count <= 'd0;
    end
    // else if(cur_state != RSP_s && next_state == RSP_s) begin
    //     rsp_count <= 'd1;
    // end
    else if(cur_state == HIT_s && (count_collected == count_max)) begin
        rsp_count <= 'd1;
    end
    else if(cur_state == SET_s && (count_collected == count_max) && cache_set_req_valid && cache_set_req_ready) begin
        rsp_count <= 'd1;
    end
    else if(cur_state == RSP_s && icm_get_rsp_valid && icm_get_rsp_ready) begin
        if(rsp_count < rsp_total) begin
           rsp_count <= rsp_count + 'd1; 
        end
        else begin
            rsp_count <= 'd0;
        end
    end
    else begin
        rsp_count <= rsp_count;
    end
end

//-- rsp_total --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        rsp_total <= 'd0;        
    end
    else if(cur_state == IDLE_s) begin
        rsp_total <= 'd0;
    end
    // else if (cur_state != RSP_s && next_state == RSP_s) begin
    //     rsp_total <= count_max;
    // end
    else if(cur_state == HIT_s && (count_collected == count_max)) begin
        rsp_total <= count_max;
    end
    else if(cur_state == SET_s && (count_collected == count_max) && cache_set_req_valid && cache_set_req_ready) begin
        rsp_total <= count_max;
    end
    else begin
        rsp_total <= rsp_total;
    end
end

//-- reorder_buffer_wen --
//-- reorder_buffer_addr --
//-- reorder_buffer_din --
always @(*) begin
    if(rst) begin
        reorder_buffer_wen = 'd0; 
        reorder_buffer_addr = 'd0;
        reorder_buffer_din = 'd0;
    end
    else if(cur_state == IDLE_s && icm_entry_rsp_valid && (!req_hit_empty || !req_miss_empty)) begin
        reorder_buffer_wen = 'd0; 
        reorder_buffer_addr = req_tag;
        reorder_buffer_din = 'd0;
    end
    else if(cur_state == HIT_s) begin
        reorder_buffer_wen = 'd0; 
        reorder_buffer_addr = req_tag;
        reorder_buffer_din = 'd0;        
    end
    else if(cur_state == MISS_s) begin
        if(ICM_CACHE_TYPE == `CACHE_TYPE_MTT) begin
            if(count_index == 0) begin
                reorder_buffer_wen = 'd1;
                reorder_buffer_addr = req_tag;
                reorder_buffer_din = {count_collected + 'd1, reorder_buffer_dout[CACHE_ENTRY_WIDTH * 2 - 1 : CACHE_ENTRY_WIDTH], icm_entry_rsp_data};
            end
            else if(count_index == 1) begin
                reorder_buffer_wen = 'd1;
                reorder_buffer_addr = req_tag;
                reorder_buffer_din = {count_collected + 'd1, icm_entry_rsp_data, reorder_buffer_dout[CACHE_ENTRY_WIDTH - 1 : 0]};
            end
            else begin
                reorder_buffer_wen = 'd0;
                reorder_buffer_addr = req_tag;
                reorder_buffer_din = 'd0;
            end
        end
        else if(ICM_CACHE_TYPE == `CACHE_TYPE_QPC || ICM_CACHE_TYPE == `CACHE_TYPE_CQC || ICM_CACHE_TYPE == `CACHE_TYPE_EQC || ICM_CACHE_TYPE == `CACHE_TYPE_MPT) begin
            reorder_buffer_wen = 'd1;
            reorder_buffer_addr = req_tag;
            reorder_buffer_din = {count_collected + 'd1, icm_entry_rsp_data};
        end
        else begin
            reorder_buffer_wen = 'd0;
            reorder_buffer_addr = req_tag;
            reorder_buffer_din = 'd0;     
        end
    end
    else if(cur_state == SET_s) begin
        reorder_buffer_wen = 'd0;
        reorder_buffer_addr = req_tag;
        reorder_buffer_din = 'd0;
    end
    else if(cur_state == RSP_s && icm_get_rsp_valid && icm_get_rsp_ready && (rsp_count == rsp_total)) begin   //Each time response, clear curretn slot
        reorder_buffer_wen = 'd1;
        reorder_buffer_addr = req_tag;
        reorder_buffer_din = 'd0;
    end
    else begin
        reorder_buffer_wen = 'd0; 
        reorder_buffer_addr = req_tag;
        reorder_buffer_din = 'd0;       
    end
end

//-- icm_entry_rsp_ready --
assign icm_entry_rsp_ready = (cur_state == SET_s) && cache_set_req_ready;

//-- cache_set_req_valid --
//-- cache_set_req_head --
//-- cache_set_req_data --
assign cache_set_req_valid = (cur_state == SET_s) ? 'd1 : 'd0;
assign cache_set_req_head = (cur_state == SET_s) ? req_miss_dout[CACHE_ADDR_WIDTH - 1 : 0] : 'd0;
assign cache_set_req_data = (cur_state == SET_s) ? icm_entry_rsp_data : 'd0;

//ICM Get Resp Interface
assign icm_get_rsp_valid = (cur_state == RSP_s) ? 'd1 : 'd0;
assign icm_get_rsp_head =   (cur_state == RSP_s && is_miss_proc) ? req_miss_dout : 
                            (cur_state == RSP_s && is_hit_proc) ? req_hit_dout : 'd0;
assign icm_get_rsp_data = (cur_state == RSP_s && rsp_count == 'd1) ? reorder_buffer_dout[CACHE_ENTRY_WIDTH - 1 : 0] :
                            (cur_state == RSP_s && rsp_count == 'd2 && ICM_CACHE_TYPE == `CACHE_TYPE_MTT) ? reorder_buffer_dout[CACHE_ENTRY_WIDTH * 2 - 1 : CACHE_ENTRY_WIDTH] : 'd0;
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule