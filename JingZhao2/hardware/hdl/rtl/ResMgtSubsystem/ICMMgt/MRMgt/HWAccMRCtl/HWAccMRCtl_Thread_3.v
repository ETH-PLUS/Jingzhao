/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       HWAccMRCtl_Thread_3
Author:     YangFan
Function:   Generate MTT requests.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module HWAccMRCtl_Thread_3
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

//Interface with MPTCache
    input   wire                                                                                                mpt_get_rsp_valid,
    input   wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   mpt_get_rsp_head,
    input   wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                 mpt_get_rsp_data,
    output  wire                                                                                                mpt_get_rsp_ready,

//Mapping Lookup Interface
    output  wire                                                                                                icm_mapping_lookup_valid,
    output  wire    [ICM_ENTRY_NUM_LOG - 1 : 0]                                                                 icm_mapping_lookup_head,
    input   wire                                                                                                icm_mapping_lookup_ready,

    input   wire                                                                                                icm_mapping_rsp_valid,
    input   wire    [ICM_ADDR_WIDTH - 1 : 0]                                                                    icm_mapping_rsp_icm_addr,
    input   wire    [PHYSICAL_ADDR_WIDTH - 1 : 0]                                                               icm_mapping_rsp_phy_addr,
    output  wire                                                                                                icm_mapping_rsp_ready,

//Interface with MTTCache
    output  wire                                                                                                mtt_get_req_valid,
    output  wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   mtt_get_req_head,
    input   wire                                                                                                mtt_get_req_ready,

//MR Req Buffer Interface
    output  wire                                                                                                mr_req_buffer_wen,
    output  wire    [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                              mr_req_buffer_addr,
    output  wire    [`MR_CMD_HEAD_WIDTH - 1 : 0]                                                               	mr_req_buffer_din,
    input   wire    [`MR_CMD_HEAD_WIDTH - 1 : 0]                                                               	mr_req_buffer_dout,

//Page offset Buffer Interface
    output  wire                                                                                                page_offset_buffer_wen,
    output  wire    [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                              page_offset_buffer_addr,
    output  wire    [32 + 12 - 1 : 0]                                                                           page_offset_buffer_din,
    input   wire    [32 + 12 - 1 : 0]                                                                           page_offset_buffer_dout
);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     MR_REQ_FLAGS_OFFSET                 31:0
`define     MR_REQ_PD_OFFSET                    63:32
`define     MR_REQ_KEY_OFFSET                   95:64
`define     MR_REQ_VA_OFFSET                    159:96
`define     MR_REQ_LENGTH_OFFSET                191:160

`define     MPT_FLAGS_OFFSET                    31:0
`define     MPT_PAGE_SIZE_OFFSET                63:32
`define     MPT_KEY_OFFSET                      95:64
`define     MPT_PD_OFFSET                       127:96
`define     MPT_START_OFFSET                    191:128
`define     MPT_LENGTH_OFFSET                   255:192
`define     MPT_MTT_SEG_OFFSET                  319:256
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg     [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1: 0]           mpt_get_rsp_head_diff;
reg     [CACHE_ENTRY_WIDTH - 1 : 0]           mpt_get_rsp_data_diff;

reg     [COUNT_MAX_LOG - 1 : 0]                 count_total;
reg     [COUNT_MAX_LOG - 1 : 0]                 count_index;

reg     [`MAX_REQ_TAG_NUM_LOG - 1 : 0]               req_tag;
reg     [PHYSICAL_ADDR_WIDTH - 1 : 0]           phy_addr;
reg     [ICM_ADDR_WIDTH - 1 : 0]              icm_addr;

reg     [31:0]                                  mr_req_flags;
reg     [31:0]                                  mr_req_pd;
reg     [31:0]                                  mr_req_key;
reg     [63:0]                                  mr_req_va;
reg     [31:0]                                  mr_req_length;

reg     [31:0]                                  mpt_flags;
reg     [31:0]                                  mpt_page_size;
reg     [31:0]                                  mpt_key;
reg     [31:0]                                  mpt_pd;
reg     [63:0]                                  mpt_start;
reg     [63:0]                                  mpt_length;
reg     [63:0]                                  mpt_mtt_seg;

wire    [ICM_ENTRY_NUM_LOG - 1 : 0]             mtt_index;

wire                                            is_relative_addr;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg         [2:0]       cur_state;
reg         [2:0]       next_state;

parameter   [2:0]       IDLE_s      = 3'd1,
                        MR_REQ_s    = 3'd2,
                        ADDR_REQ_s  = 3'd3,
                        ADDR_RSP_s  = 3'd4,
                        MTT_GET_s   = 3'd5;

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
        IDLE_s:         if(mpt_get_rsp_valid) begin
                            next_state = MR_REQ_s;
                        end
                        else begin
                            next_state = IDLE_s;
                        end
        MR_REQ_s:       next_state = ADDR_REQ_s;
        ADDR_REQ_s:     if(icm_mapping_lookup_valid && icm_mapping_lookup_ready) begin
                            next_state = ADDR_RSP_s;
                        end
                        else begin
                            next_state = ADDR_REQ_s;
                        end
        ADDR_RSP_s:     if(icm_mapping_rsp_valid) begin
                            next_state = MTT_GET_s;
                        end
                        else begin
                            next_state = ADDR_RSP_s;
                        end
        MTT_GET_s:      if(mtt_get_req_valid && mtt_get_req_ready) begin
                            if(count_index + 1 == count_total) begin    //All MTT requests have been issued
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = ADDR_REQ_s;
                            end
                        end
                        else begin
                            next_state = MTT_GET_s;
                        end
        default:        next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- mr_req_flags --
//-- mr_req_pd --
//-- mr_req_key --
//-- mr_req_va --
//-- mr_req_length --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        mr_req_flags <= 'd0;
        mr_req_pd <= 'd0;
        mr_req_key <= 'd0;
        mr_req_va <= 'd0;
        mr_req_length <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        mr_req_flags <= 'd0;
        mr_req_pd <= 'd0;
        mr_req_key <= 'd0;
        mr_req_va <= 'd0;
        mr_req_length <= 'd0;        
    end
    else if(cur_state == MR_REQ_s) begin
        mr_req_flags <= mr_req_buffer_dout[`MR_REQ_FLAGS_OFFSET];
        mr_req_pd <= mr_req_buffer_dout[`MR_REQ_PD_OFFSET];
        mr_req_key <= mr_req_buffer_dout[`MR_REQ_KEY_OFFSET];
        mr_req_va <= mr_req_buffer_dout[`MR_REQ_VA_OFFSET];
        mr_req_length <= mr_req_buffer_dout[`MR_REQ_LENGTH_OFFSET];
    end
    else begin
        mr_req_flags <= mr_req_flags;
        mr_req_pd <= mr_req_pd;
        mr_req_key <= mr_req_key;
        mr_req_va <= mr_req_va;
        mr_req_length <= mr_req_length;
    end
end

//-- mpt_flags --
//-- mpt_page_size --
//-- mpt_key --
//-- mpt_pd --
//-- mpt_start --
//-- mpt_length --
//-- mpt_mtt_seg --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        mpt_flags <= 'd0;
        mpt_page_size <= 'd0;
        mpt_key <= 'd0;
        mpt_pd <= 'd0;
        mpt_start <= 'd0;
        mpt_length <= 'd0;
        mpt_mtt_seg <= 'd0;
    end
    else if(cur_state == IDLE_s && mpt_get_rsp_valid) begin
        mpt_flags <= mpt_get_rsp_data[`MPT_FLAGS_OFFSET];
        mpt_page_size <= mpt_get_rsp_data[`MPT_PAGE_SIZE_OFFSET];
        mpt_key <= mpt_get_rsp_data[`MPT_KEY_OFFSET];
        mpt_pd <= mpt_get_rsp_data[`MPT_PD_OFFSET];
        mpt_start <= mpt_get_rsp_data[`MPT_START_OFFSET];
        mpt_length <= mpt_get_rsp_data[`MPT_LENGTH_OFFSET];
        mpt_mtt_seg <= mpt_get_rsp_data[`MPT_MTT_SEG_OFFSET];        
    end
    else begin
        mpt_flags <= mpt_flags;
        mpt_page_size <= mpt_page_size;
        mpt_key <= mpt_key;
        mpt_pd <= mpt_pd;
        mpt_start <= mpt_start;
        mpt_length <= mpt_length;
        mpt_mtt_seg <= mpt_mtt_seg;
    end
end

//-- mpt_get_rsp_head_diff --
//-- mpt_get_rsp_data_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        mpt_get_rsp_head_diff <= 'd0;
        mpt_get_rsp_data_diff <= 'd0;
    end
    else if(cur_state == IDLE_s && mpt_get_rsp_valid) begin
        mpt_get_rsp_head_diff <= mpt_get_rsp_head;
        mpt_get_rsp_data_diff <= mpt_get_rsp_data;
    end
    else begin
        mpt_get_rsp_head_diff <= mpt_get_rsp_head_diff;
        mpt_get_rsp_data_diff <= mpt_get_rsp_data_diff;
    end
end

wire            [11:0]              page_offset;

//-- page_offset --
assign page_offset = mr_req_buffer_dout[`MR_REQ_VA_OFFSET] & 64'h00000fff;

//-- count_total --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        count_total <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        count_total <= 'd0;
    end
    else if(cur_state == MR_REQ_s) begin
        count_total <= page_offset + mr_req_buffer_dout[`MR_REQ_LENGTH_OFFSET] > `PAGE_SIZE ? 'd2 : 'd1;
    end
    else begin
        count_total <= count_total;
    end
end

//-- count_index --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        count_index <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        count_index <= 'd0;
    end
    else if(cur_state == MR_REQ_s) begin
        count_index <= 'd0;
    end
    else if(cur_state == MTT_GET_s && mtt_get_req_valid && mtt_get_req_ready) begin
        count_index <= (count_index + 1 == count_total) ? 'd0 : count_index + 'd1;
    end
    else begin
        count_index <= count_index;
    end
end

//-- mr_req_buffer_wen --
assign mr_req_buffer_wen = (cur_state == MTT_GET_s && next_state == IDLE_s) ? 'd1 : 'd0;

//-- mr_req_buffer_din --
assign mr_req_buffer_din = 'd0;

//-- mr_req_buffer_addr --
assign mr_req_buffer_addr = (cur_state == IDLE_s && mpt_get_rsp_valid) ? mpt_get_rsp_head[`MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH] : 
                            (cur_state != IDLE_s) ? req_tag : 'd0;

//-- req_tag --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        req_tag <= 'd0;
    end
    else if(cur_state == IDLE_s && mpt_get_rsp_valid) begin
        req_tag <= mpt_get_rsp_head[`MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH];
    end
    else begin
        req_tag <= req_tag;
    end
end

//-- phy_addr --
//-- icm_addr --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        phy_addr <= 'd0;
        icm_addr <= 'd0;
    end
    else if (cur_state == ADDR_RSP_s && icm_mapping_rsp_valid) begin
        phy_addr <= icm_mapping_rsp_phy_addr;
        icm_addr <= icm_mapping_rsp_icm_addr;
    end
    else begin
        phy_addr <= phy_addr;
        icm_addr <= icm_addr;
    end
end

//-- mpt_get_rsp_ready --
assign mpt_get_rsp_ready = (cur_state == IDLE_s) ? 'd1 : 'd0;

//-- is_relative_addr --
assign is_relative_addr = mr_req_flags[25];

//-- mtt_index --
assign mtt_index = is_relative_addr ? (mr_req_va[ICM_ENTRY_NUM_LOG + 12 - 1 : 12] + mpt_mtt_seg[ICM_ENTRY_NUM_LOG - 1 : 0] + count_index) :        //Use count index to distinguish first page and second page(4KB at most for one req)
                                        (mr_req_va[ICM_ENTRY_NUM_LOG + 12 - 1 : 12] - mpt_start[ICM_ENTRY_NUM_LOG + 12 - 1 : 12] + mpt_mtt_seg + count_index);

//-- icm_mapping_lookup_valid --
//-- icm_mapping_lookup_head --
assign icm_mapping_lookup_valid = (cur_state == ADDR_REQ_s) ? 'd1 : 'd0;
assign icm_mapping_lookup_head = (cur_state == ADDR_REQ_s) ? mtt_index : 'd0;

//-- mtt_get_req_valid --
//-- mtt_get_req_head --
assign mtt_get_req_valid = (cur_state == MTT_GET_s) ? 'd1 : 'd0;
assign mtt_get_req_head = (cur_state == MTT_GET_s) ? {count_total, count_index, req_tag, phy_addr, icm_addr} : 'd0;

// -- icm_mapping_rsp_ready --
assign icm_mapping_rsp_ready = (cur_state == ADDR_RSP_s) ? 'd1 : 'd0;

//-- page_offset_buffer_wen --
//-- page_offset_buffer_addr --
//-- page_offset_buffer_din --
assign page_offset_buffer_wen = (cur_state == MR_REQ_s) ? 'd1 : 'd0;
assign page_offset_buffer_addr = (cur_state == MR_REQ_s) ? req_tag : 'd0;
assign page_offset_buffer_din = (cur_state == MR_REQ_s) ? {mr_req_buffer_dout[`MR_REQ_LENGTH_OFFSET], page_offset} : 'd0;
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef      MR_REQ_FLAGS_OFFSET 
`undef      MR_REQ_PD_OFFSET    
`undef      MR_REQ_KEY_OFFSET   
`undef      MR_REQ_VA_OFFSET    
`undef      MR_REQ_LENGTH_OFFSET

`undef      MPT_FLAGS_OFFSET    
`undef      MPT_PAGE_SIZE_OFFSET
`undef      MPT_KEY_OFFSET      
`undef      MPT_PD_OFFSET       
`undef      MPT_START_OFFSET    
`undef      MPT_LENGTH_OFFSET   
`undef      MPT_MTT_SEG_OFFSET  
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule