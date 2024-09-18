/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       SWAccMRCtl_Thread_2 
Author:     YangFan
Function:   Handle MPT Wr Command from CEU.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/



/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module SWAccMRCtl_Thread_2
(
    input   wire                                                                                                clk,
    input   wire                                                                                                rst,

//Interface with SWAccCMCtl_Thread_1
    input   wire                                                                                                mpt_req_valid,
    input   wire    [`CEU_MR_HEAD_WIDTH - 1 : 0]                                                                mpt_req_head,
    input   wire                                                                                                mpt_req_last,
    input   wire    [`CEU_MR_DATA_WIDTH - 1 : 0]                                                                mpt_req_data,
    output  wire                                                                                                mpt_req_ready,

//Interface with MPTCache(ICMCache)
//Cache Set Req Interface
    output  wire                                                                                                        cache_set_req_valid,
    output  wire    [`REQ_TAG_NUM_LOG + `COUNT_MAX_LOG * 2 + `ICM_SPACE_ADDR_WIDTH + `PHY_SPACE_ADDR_WIDTH - 1 : 0]     cache_set_req_head,
    output  wire     [`CACHE_ENTRY_WIDTH_MPT - 1 : 0]                                                                   cache_set_req_data,
    input   wire                                                                                                        cache_set_req_ready,

//ICM Address Translation Interface
    output  wire                                                                                                icm_mapping_lookup_valid,
    output  wire    [log2b(`ICM_ENTRY_NUM_MPT - 1) - 1 : 0]                                                     icm_mapping_lookup_head,
    input   wire                                                                                                icm_mapping_lookup_ready,

    input   wire                                                                                                icm_mapping_rsp_valid,
    input   wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                                             icm_mapping_rsp_icm_addr,
    input   wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                                             icm_mapping_rsp_phy_addr,
    output  wire                                                                                                icm_mapping_rsp_ready
);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     CEU_CMD_OPCODE_OFFSET                                   123:120
`define     CEU_CMD_INDEX_OFFSET                                    95:64
`define     MPT_PIECE_NUM                                           2           //64B (256bit data width) 

`define     WR_MPT_CMD_LENGTH_OFFSET                                32 * 2 - 1 : 32 * 0
`define     WR_MPT_CMD_START_OFFSET                                 32 * 4 - 1 : 32 * 2
`define     WR_MPT_CMD_PD_OFFSET                                    32 * 5 - 1 : 32 * 4
`define     WR_MPT_CMD_KEY_OFFSET                                   32 * 6 - 1 : 32 * 5
`define     WR_MPT_CMD_PAGE_SIZE_OFFSET                             32 * 7 - 1 : 32 * 6
`define     WR_MPT_CMD_FLAGS_OFFSET                                 32 * 8 - 1 : 32 * 7

`define     WR_MPT_CMD_MTT_SIZE_OFFSET                              32 * 3 - 1 : 32 * 2
`define     WR_MPT_CMD_MTT_SEG_OFFSET                               32 * 5 - 1 : 32 * 3
`define     WR_MPT_CMD_WINDOW_OFFSET                                32 * 7 - 1 : 32 * 5
`define     WR_MPT_CMD_LKEY_OFFSET                                  32 * 8 - 1 : 32 * 7
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg             [3:0]                                                       mpt_piece_count;

reg             [`CEU_MR_HEAD_WIDTH - 1 : 0]                                mpt_req_head_diff;

reg             [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                             icm_addr;
reg             [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                             phy_addr;

wire            [`COUNT_MAX_LOG - 1 : 0]                                    count_max;
wire            [`COUNT_MAX_LOG - 1 : 0]                                    count_index;

wire            [5:0]                                                       req_tag;

//MPT Info
reg                        [31:0]               flags;
reg                        [31:0]               page_size;
reg                        [31:0]               key;
reg                        [31:0]               pd;
reg                        [63:0]               start;
reg                        [63:0]               length;
reg                        [63:0]               mtt_seg;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg         [2:0]               cur_state;
reg         [2:0]               next_state;

parameter   [2:0]               IDLE_s = 3'd1,
                                ADDR_REQ_s = 3'd2,
                                ADDR_RSP_s = 3'd3,
                                MPT_COLLECT_s = 3'd4,
                                CACHE_SET_s = 3'd5,
                                MPT_INVALID_s = 3'd6;

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
        IDLE_s:             if(mpt_req_valid) begin
                                next_state = ADDR_REQ_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
        ADDR_REQ_s:         if(icm_mapping_lookup_valid && icm_mapping_lookup_ready) begin
                                next_state = ADDR_RSP_s;
                            end
                            else begin
                                next_state = ADDR_REQ_s;
                            end
        ADDR_RSP_s:         if(icm_mapping_rsp_valid && mpt_req_head_diff[`CEU_CMD_OPCODE_OFFSET] == `WR_MPT_WRITE) begin
                                next_state = MPT_COLLECT_s;
                            end
                            else if(icm_mapping_rsp_valid && mpt_req_head_diff[`CEU_CMD_OPCODE_OFFSET] == `WR_MPT_INVALID) begin
                                next_state = MPT_INVALID_s;
                            end
                            else begin
                                next_state = ADDR_RSP_s;
                            end
        MPT_COLLECT_s:      if(mpt_piece_count == `MPT_PIECE_NUM &&  mpt_req_valid && mpt_req_ready) begin
                                next_state = CACHE_SET_s;
                            end
                            else begin
                                next_state = MPT_COLLECT_s;
                            end
        CACHE_SET_s:        if(cache_set_req_valid && cache_set_req_ready) begin
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = CACHE_SET_s;
                            end
        MPT_INVALID_s:		next_state = IDLE_s;
        default:            next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

//-- Wr MPT Info --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        flags <= 'd0;
        page_size <= 'd0;
        key <= 'd0;
        pd <= 'd0;
        start <= 'd0;
        length <= 'd0;
        mtt_seg <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        flags <= 'd0;
        page_size <= 'd0;
        key <= 'd0;
        pd <= 'd0;
        start <= 'd0;
        length <= 'd0;
        mtt_seg <= 'd0;    
    end
    else if(cur_state == MPT_COLLECT_s && mpt_req_valid) begin
        flags <= (mpt_piece_count == 1) ?  mpt_req_data[`WR_MPT_CMD_FLAGS_OFFSET] : flags;
        page_size <= (mpt_piece_count == 1) ?  mpt_req_data[`WR_MPT_CMD_PAGE_SIZE_OFFSET] : page_size;
        key <= (mpt_piece_count == 1) ?  mpt_req_data[`WR_MPT_CMD_KEY_OFFSET] : key;
        pd <= (mpt_piece_count == 1) ? mpt_req_data[`WR_MPT_CMD_PD_OFFSET] : pd;
        start <= (mpt_piece_count == 1) ? mpt_req_data[`WR_MPT_CMD_START_OFFSET] : start;
        length <= (mpt_piece_count == 1) ? mpt_req_data[`WR_MPT_CMD_LENGTH_OFFSET] : length;
        mtt_seg <= (mpt_piece_count == 2) ? mpt_req_data[`WR_MPT_CMD_MTT_SEG_OFFSET] : mtt_seg;  
    end
    else begin
        flags <= flags;
        page_size <= page_size;
        key <= key;
        pd <= pd;
        start <= start;
        length <= length;
        mtt_seg <= mtt_seg;
    end
end

//-- count_max --
//-- count_index --
assign count_max = 'd1;     //Specific for QPC/EQC/CQC/MPT, 2 for MTT
assign count_index = 'd0;   //Specific for QPC/EQC/CQC/MPT, 0, 1 for MTT

//-- req_tag --
assign req_tag = 'd0;       //Specific for CEU request, RPCCore will use tag start from 1.

//-- mpt_piece_count --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        mpt_piece_count <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        mpt_piece_count <= 'd0;
    end
    else if(cur_state == ADDR_RSP_s && next_state == MPT_COLLECT_s) begin
        mpt_piece_count <= 'd1;
    end
    else if(cur_state == MPT_COLLECT_s && mpt_req_valid && mpt_req_ready) begin
        mpt_piece_count <= mpt_piece_count + 'd1;
    end
    else begin
        mpt_piece_count <= mpt_piece_count;
    end
end

//-- mpt_req_head_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        mpt_req_head_diff <= 'd0;
    end
    else if(cur_state == IDLE_s && mpt_req_valid) begin
        mpt_req_head_diff <= mpt_req_head;
    end
    else begin
        mpt_req_head_diff <= mpt_req_head_diff;
    end
end

//-- icm_addr --
//-- phy_addr --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        icm_addr <= 'd0;
        phy_addr <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        icm_addr <= 'd0;
        phy_addr <= 'd0;
    end
    else if(cur_state == ADDR_RSP_s && icm_mapping_rsp_valid) begin
        icm_addr <= icm_mapping_rsp_icm_addr;
        phy_addr <= icm_mapping_rsp_phy_addr;
    end
    else begin
        icm_addr <= icm_addr;
        phy_addr <= phy_addr;
    end
end

//-- icm_mapping_lookup_valid --
//-- icm_mapping_lookup_head --
assign icm_mapping_lookup_valid = (cur_state == ADDR_REQ_s) ? 'd1 : 'd0;
assign icm_mapping_lookup_head = (cur_state == ADDR_REQ_s) ? mpt_req_head_diff[`CEU_CMD_INDEX_OFFSET] : 'd0;  //Notice  CEU_CMD_INDEX_OFFSET is 32bit, may exceed actual index length, it does not matter

//-- icm_mapping_rsp_ready --
assign icm_mapping_rsp_ready = (cur_state == ADDR_RSP_s) ? 'd1 : 'd0;

//-- cache_set_req_valid --
//-- cache_set_req_head --
//-- cache_set_req_data --
assign cache_set_req_valid = (cur_state == CACHE_SET_s) ? 'd1 : 'd0;
assign cache_set_req_head = (cur_state == CACHE_SET_s) ? {req_tag, count_max, count_index, phy_addr, icm_addr} : 'd0; 
assign cache_set_req_data = {mtt_seg, length, start, pd, key, page_size, flags};

//-- mpt_req_ready --
assign mpt_req_ready = (cur_state == MPT_COLLECT_s) ? 'd1 :
						(cur_state == MPT_INVALID_s) ? 'd1 : 'd0;


//-- icm_mapping_rsp_ready --
assign icm_mapping_rsp_ready = (cur_state == ADDR_RSP_s) ? 'd1 : 'd0;

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef  CEU_CMD_OPCODE_OFFSET
`undef  CEU_CMD_INDEX_OFFSET
`undef  MPT_PIECE_NUM

`undef  WR_MTT_CMD_LENGTH_OFFSET   
`undef  WR_MTT_CMD_START_OFFSET    
`undef  WR_MTT_CMD_PD_OFFSET       
`undef  WR_MTT_CMD_KEY_OFFSET      
`undef  WR_MTT_CMD_PAGE_SIZE_OFFSET
`undef  WR_MTT_CMD_FLAGS_OFFSET    

`undef  WR_MTT_CMD_MTT_SIZE_OFFSET 
`undef  WR_MTT_CMD_MTT_SEG_OFFSET  
`undef  WR_MTT_CMD_WINDOW_OFFSET   
`undef  WR_MTT_CMD_LKEY_OFFSET     
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule