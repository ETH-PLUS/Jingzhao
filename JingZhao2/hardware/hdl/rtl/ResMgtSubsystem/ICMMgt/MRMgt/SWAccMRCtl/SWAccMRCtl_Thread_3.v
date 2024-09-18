/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       SWAccMRCtl_Thread_3 
Author:     YangFan
Function:   Handle MTT Wr Command from CEU.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/



/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module SWAccMRCtl_Thread_3
(
    input   wire                                                                                                clk,
    input   wire                                                                                                rst,

//Interface with SWAccCMCtl_Thread_1
    input   wire                                                                                                mtt_req_valid,
    input   wire    [`CEU_MR_HEAD_WIDTH - 1 : 0]                                                                mtt_req_head,
    input   wire                                                                                                mtt_req_last,
    input   wire    [`CEU_MR_DATA_WIDTH - 1 : 0]                                                                mtt_req_data,
    output  wire                                                                                                mtt_req_ready,

//Interface with MPTCache(ICMCache)
//Cache Set Req Interface
    output  wire                                                                                                cache_set_req_valid,
    output  wire    [10 + `ICM_SPACE_ADDR_WIDTH + `PHY_SPACE_ADDR_WIDTH - 1 : 0]                                cache_set_req_head,
    output  wire    [`CACHE_ENTRY_WIDTH_MTT - 1 : 0]                                                            cache_set_req_data,
    input   wire                                                                                                cache_set_req_ready,

//ICM Address Translation Interface
    output  wire                                                                                                icm_mapping_lookup_valid,
    output  wire    [log2b(`ICM_ENTRY_NUM_MTT - 1) - 1 : 0]                                                     icm_mapping_lookup_head,
    input   wire                                                                                                icm_mapping_lookup_ready,

    input   wire                                                                                                icm_mapping_rsp_valid,
    input   wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                                             icm_mapping_rsp_icm_addr,
    input   wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                                             icm_mapping_rsp_phy_addr,
    output  wire                                                                                                icm_mapping_rsp_ready
);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     CEU_CMD_OPCODE_OFFSET                                   127:124
`define     CEU_CMD_MTT_NUM_OFFSET                                  95:64
`define     CEU_CMD_START_INDEX_OFFSET                              63:0

/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg             [31:0]                                                      mtt_seg_num;
reg             [31:0]                                                      mtt_write_count;
reg             [63:0]                                                      mtt_start_index;

reg             [`CEU_MR_HEAD_WIDTH - 1 : 0]                                mtt_req_head_diff;

reg             [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                             icm_addr;
reg             [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                             phy_addr;

wire            [1:0]                                                       count_max;
wire            [1:0]                                                       count_index;

wire            [5:0]                                                       req_tag;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg         [2:0]               cur_state;
reg         [2:0]               next_state;

parameter   [2:0]               IDLE_s = 3'd1,
                                ADDR_REQ_s = 3'd2,
                                ADDR_RSP_s = 3'd3,
                                CACHE_SET_s = 3'd4;

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
        IDLE_s:             if(mtt_req_valid) begin
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
        ADDR_RSP_s:         if(icm_mapping_rsp_valid) begin
                                next_state = CACHE_SET_s;
                            end
                            else begin
                                next_state = ADDR_RSP_s;
                            end
        CACHE_SET_s:        if(cache_set_req_valid && cache_set_req_ready) begin
                                if(mtt_write_count + 1 == mtt_seg_num) begin
                                    next_state = IDLE_s;
                                end
                                else begin
                                    next_state = ADDR_REQ_s;
                                end
                            end
                            else begin
                                next_state = CACHE_SET_s;
                            end
        default:            next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- mtt_seg_num --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        mtt_seg_num <= 'd0;
    end
    else if(cur_state == IDLE_s && mtt_req_valid) begin
        mtt_seg_num <= mtt_req_head[`CEU_CMD_MTT_NUM_OFFSET];
    end
    else begin
        mtt_seg_num <= mtt_seg_num;
    end
end

//-- mtt_start_index --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mtt_start_index <= 'd0;        
    end
    else if (cur_state == IDLE_s && mtt_req_valid) begin
        mtt_start_index <= mtt_req_head[`CEU_CMD_START_INDEX_OFFSET];
    end
    else begin
        mtt_start_index <= mtt_start_index;
    end
end

//-- mtt_write_count --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mtt_write_count <= 'd0;        
    end
    else if (cur_state == IDLE_s && mtt_req_valid) begin
        mtt_write_count <= 'd0;
    end
    else if(cur_state == CACHE_SET_s && cache_set_req_valid && cache_set_req_ready) begin
        mtt_write_count <= mtt_write_count + 'd1;
    end
    else begin
        mtt_write_count <= mtt_write_count;
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

//-- count_max --
//-- count_index --
assign count_max = 'd1;     //Specific for QPC/EQC/CQC/MPT, 2 for MTT Read
assign count_index = 'd0;   //Specific for QPC/EQC/CQC/MPT, 0, 1 for MTT Read

//-- req_tag --
assign req_tag = 'd0;       //Specific for CEU request, RPCCore will use tag start from 1.

//-- mtt_req_head_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        mtt_req_head_diff <= 'd0;
    end
    else if(cur_state == IDLE_s && mtt_req_valid) begin
        mtt_req_head_diff <= mtt_req_head;
    end
    else begin
        mtt_req_head_diff <= mtt_req_head_diff;
    end
end

//-- icm_mapping_lookup_valid --
//-- icm_mapping_lookup_head --
assign icm_mapping_lookup_valid = (cur_state == ADDR_REQ_s) ? 'd1 : 'd0;
assign icm_mapping_lookup_head = (cur_state == ADDR_REQ_s) ? mtt_start_index + mtt_write_count : 'd0;

//-- icm_mapping_rsp_ready --
assign icm_mapping_rsp_ready = (cur_state == ADDR_RSP_s) ? 'd1 : 'd0;

//-- cache_set_req_valid --
//-- cache_set_req_head --
//-- cache_set_req_data --
assign cache_set_req_valid = (cur_state == CACHE_SET_s) ? 'd1 : 'd0;
assign cache_set_req_head = (cur_state == CACHE_SET_s) ? {'d0, phy_addr, icm_addr} : 'd0;
assign cache_set_req_data = (cur_state == CACHE_SET_s && mtt_write_count[1:0] == 0) ? mtt_req_data[63 + 64 * 0 : 0 + 64 * 0] :
                            (cur_state == CACHE_SET_s && mtt_write_count[1:0] == 1) ? mtt_req_data[63 + 64 * 1 : 0 + 64 * 1] : 
                            (cur_state == CACHE_SET_s && mtt_write_count[1:0] == 2) ? mtt_req_data[63 + 64 * 2 : 0 + 64 * 2] : 
                            (cur_state == CACHE_SET_s && mtt_write_count[1:0] == 3) ? mtt_req_data[63 + 64 * 3 : 0 + 64 * 3] : 'd0;

//-- mtt_req_ready --
assign mtt_req_ready = ((cur_state == CACHE_SET_s && next_state == IDLE_s) || (cur_state == CACHE_SET_s && mtt_write_count[1:0] == 3 && cache_set_req_ready)) ? 'd1 : 'd0;


//-- icm_mapping_rsp_ready --
assign icm_mapping_rsp_ready = (cur_state == ADDR_RSP_s) ? 'd1 : 'd0;

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef  CEU_CMD_OPCODE_OFFSET
`undef  CEU_CMD_INDEX_OFFSET
`undef  CEU_CMD_START_INDEX_OFFSET
`undef  CEU_CMD_MTT_NUM_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule