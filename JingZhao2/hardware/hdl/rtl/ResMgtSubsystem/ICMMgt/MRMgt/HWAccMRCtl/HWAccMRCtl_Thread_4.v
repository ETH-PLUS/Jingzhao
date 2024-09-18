/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       HWAccMRCtl_Thread_4
Author:     YangFan
Function:   Handle MTT Resp.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module HWAccMRCtl_Thread_4
#(
    parameter               ICM_CACHE_TYPE          =       `CACHE_TYPE_MTT,
    parameter               ICM_PAGE_NUM            =       `ICM_PAGE_NUM_MTT,
    parameter               ICM_PAGE_NUM_LOG        =       log2b(ICM_PAGE_NUM - 1),
    parameter               ICM_ENTRY_NUM           =       `ICM_ENTRY_NUM_MTT,
    parameter               ICM_ENTRY_NUM_LOG       =       log2b(ICM_ENTRY_NUM - 1),
    parameter               ICM_SLOT_SIZE           =       `ICM_SLOT_SIZE_MTT,
    parameter               ICM_ADDR_WIDTH          =       64,

    parameter               CACHE_ADDR_WIDTH        =       ICM_ADDR_WIDTH,
    parameter               CACHE_ENTRY_WIDTH       =       256,
    parameter               CACHE_SET_NUM           =       1024,
    parameter               CACHE_SET_NUM_LOG       =       log2b(CACHE_SET_NUM - 1),
    parameter               CACHE_OFFSET_WIDTH      =       log2b(CACHE_ENTRY_WIDTH / 8 - 1),
    parameter               CACHE_TAG_WIDTH         =       CACHE_ADDR_WIDTH - CACHE_OFFSET_WIDTH - CACHE_SET_NUM_LOG,
    parameter               PHYSICAL_ADDR_WIDTH     =       64,
    parameter               COUNT_MAX               =       2,
    parameter               COUNT_MAX_LOG           =       log2b(COUNT_MAX - 1) + 1,
    parameter               REQ_TAG_NUM             =       32,
    parameter               REQ_TAG_NUM_LOG         =       log2b(REQ_TAG_NUM - 1),
    parameter               REORDER_BUFFER_WIDTH    =       (ICM_CACHE_TYPE == `CACHE_TYPE_MTT) ? CACHE_ENTRY_WIDTH * 2 + COUNT_MAX_LOG : CACHE_ENTRY_WIDTH + COUNT_MAX_LOG 
)
(
    input   wire                                                                                                clk,
    input   wire                                                                                                rst,

//Interface with MTTCache
    input   wire                                                                                                mtt_get_rsp_valid,
    input   wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   mtt_get_rsp_head,
    input   wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                 mtt_get_rsp_data,
    output  wire                                                                                                mtt_get_rsp_ready,

//Interface with PageOffsetBuffer
    output  wire                                                                                                page_offset_buffer_wen,
    output  wire    [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                              page_offset_buffer_addr,
    output  wire    [32 + 12 - 1 : 0]                                                                           page_offset_buffer_din,
    input   wire    [32 + 12 - 1 : 0]                                                                           page_offset_buffer_dout,

//Interface with HWAccMRCtl_Thread_5
    output  wire                                                                                                mr_rsp_valid,
    output  wire    [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                              mr_rsp_head,
    output  wire    [`MR_RESP_DATA_WIDTH - 1 : 0]                                                               mr_rsp_data,
    input   wire                                                                                                mr_rsp_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/                
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg     [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]               mtt_get_rsp_head_diff;
reg     [63 : 0]                                                                             mtt_page_addr_0;
reg     [63 : 0]                                                                             mtt_page_addr_1;

reg     [31 : 0]                                                                            mtt_page_size_0;
reg     [31 : 0]                                                                            mtt_page_size_1;

reg     [COUNT_MAX_LOG - 1 : 0]                                                                                 count_total;

reg     [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                                          req_tag;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg                     [2:0]               cur_state;
reg                     [2:0]               next_state;

parameter               [2:0]               IDLE_s = 3'd1,
                                            COLLECT_PAGE_0_s = 3'd2,
                                            COLLECT_PAGE_1_s = 3'd3,
                                            FWD_s = 3'd4;

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
        IDLE_s:             if(mtt_get_rsp_valid) begin
                                next_state = COLLECT_PAGE_0_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
        COLLECT_PAGE_0_s:   if(mtt_get_rsp_valid && count_total == 1) begin
                                next_state = FWD_s;
                            end
                            else if(mtt_get_rsp_valid && count_total == 2)begin
                                next_state = COLLECT_PAGE_1_s;
                            end
                            else begin
                                next_state = COLLECT_PAGE_0_s;
                            end
        COLLECT_PAGE_1_s:   if(mtt_get_rsp_valid) begin
                                next_state = FWD_s;
                            end
                            else begin
                                next_state = COLLECT_PAGE_1_s;
                            end
        FWD_s:              if(mr_rsp_valid && mr_rsp_ready) begin
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = FWD_s;
                            end
        default:            next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- count_total --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        count_total <= 'd0;
    end
    else if(cur_state == IDLE_s && mtt_get_rsp_valid) begin
        count_total <= mtt_get_rsp_head[COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : COUNT_MAX_LOG + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH];
    end
    else begin
        count_total <= count_total;
    end
end

//-- req_tag --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        req_tag <= 'd0;        
    end
    else if (cur_state == IDLE_s && mtt_get_rsp_valid) begin
        req_tag <= mtt_get_rsp_head[`MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH];
    end
    else begin
        req_tag <= req_tag;
    end
end

//-- mtt_get_rsp_head_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        mtt_get_rsp_head_diff <= 'd0;
    end
    else if(cur_state == IDLE_s && mtt_get_rsp_valid) begin
        mtt_get_rsp_head_diff <= mtt_get_rsp_head;
    end
    else begin
        mtt_get_rsp_head_diff <= mtt_get_rsp_head_diff;       
    end
end

//-- mtt_page_addr_0 --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        mtt_page_addr_0 <= 'd0;
    end
    else if(cur_state == COLLECT_PAGE_0_s && mtt_get_rsp_valid) begin
        mtt_page_addr_0 <= {mtt_get_rsp_data[63:12], page_offset_buffer_dout[11:0]};
    end
    else begin
        mtt_page_addr_0 <= mtt_page_addr_0;
    end
end

//-- mtt_page_addr_1 --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mtt_page_addr_1 <= 'd0;        
    end
    else if (cur_state == COLLECT_PAGE_1_s && mtt_get_rsp_valid) begin
        mtt_page_addr_1 <= {mtt_get_rsp_data[63:12], 12'd0}; 		//Second page addr is 4KB aligned
    end
    else begin
        mtt_page_addr_1 <= mtt_page_addr_1;
    end
end

//-- mtt_page_size_0 --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mtt_page_size_0 <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        mtt_page_size_0 <= 'd0;
    end
    else if (cur_state == COLLECT_PAGE_0_s && mtt_get_rsp_valid) begin
        if(page_offset_buffer_dout[11:0] + page_offset_buffer_dout[43:12] <= `PAGE_SIZE) begin
            mtt_page_size_0 <= page_offset_buffer_dout[43:12];
        end
        else begin
            mtt_page_size_0 <= `PAGE_SIZE - page_offset_buffer_dout[11:0];
        end
    end
    else begin
        mtt_page_size_0 <= mtt_page_size_0;
    end
end

//-- mtt_page_size_1 --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mtt_page_size_1 <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        mtt_page_size_1 <= 'd0;
    end
    else if (cur_state == COLLECT_PAGE_1_s && mtt_get_rsp_valid) begin
        mtt_page_size_1 <= page_offset_buffer_dout[43:12] - (`PAGE_SIZE - page_offset_buffer_dout[11:0]);
    end
    else begin
        mtt_page_size_1 <= mtt_page_size_1;
    end
end

//-- mtt_get_rsp_ready --
assign mtt_get_rsp_ready = (cur_state == COLLECT_PAGE_0_s) ? 'd1 :
                           (cur_state == COLLECT_PAGE_1_s) ? 'd1 : 'd0;

//-- mr_rsp_valid --
assign mr_rsp_valid = (cur_state == FWD_s) ? 'd1 : 'd0;

//-- mr_rsp_head --
assign mr_rsp_head = (cur_state == FWD_s) ? req_tag : 'd0;

//-- mr_rsp_data --
assign mr_rsp_data = (cur_state == FWD_s && count_total == 2) ? {mtt_page_addr_1, mtt_page_addr_0, mtt_page_size_1, mtt_page_size_0, 24'd0, 4'b1111, 4'b1111} :
                        (cur_state == FWD_s && count_total == 1) ? {64'd0, mtt_page_addr_0, 32'd0, mtt_page_size_0, 24'd0, 4'b0000, 4'b1111} : 'd0;


//-- page_offset_buffer_wen --
//-- page_offset_buffer_addr --
//-- page_offset_buffer_din --
assign page_offset_buffer_wen = (cur_state == FWD_s && mr_rsp_valid && mr_rsp_ready) ? 'd1 : 'd0;
assign page_offset_buffer_addr = (cur_state == IDLE_s && mtt_get_rsp_valid) ? mtt_get_rsp_head[`MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH] : req_tag;
assign page_offset_buffer_din = 'd0;
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule