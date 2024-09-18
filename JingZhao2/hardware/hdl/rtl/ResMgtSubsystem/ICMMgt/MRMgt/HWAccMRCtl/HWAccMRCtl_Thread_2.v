/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       HWAccMRCtl_Thread_2
Author:     YangFan
Function:   Generate MPT requests.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module HWAccMRCtl_Thread_2
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

//ICM Get Req Interface
    input   wire                                                                                                mr_req_valid,
    input   wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                               	mr_req_head,
    input   wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                                                               	mr_req_data,
    output  wire                                                                                                mr_req_ready,

//Mapping Lookup Interface
    output  wire                                                                                                icm_mapping_lookup_valid,
    output  wire    [ICM_ENTRY_NUM_LOG - 1 : 0]                                                                 icm_mapping_lookup_head,
    input   wire                                                                                                icm_mapping_lookup_ready,

    input   wire                                                                                                icm_mapping_rsp_valid,
    input   wire    [ICM_ADDR_WIDTH - 1 : 0]                                                                    icm_mapping_rsp_icm_addr,
    input   wire    [PHYSICAL_ADDR_WIDTH - 1 : 0]                                                               icm_mapping_rsp_phy_addr,
    output  wire                                                                                                icm_mapping_rsp_ready,

//ICM Get Interface
    output  wire                                                                                                icm_get_req_valid,
    output  wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]      icm_get_req_head,
    input   wire                                                                                                icm_get_req_ready,

//MR Req Buffer Interface
	output 	wire 			                        															mr_req_buffer_wen,
    output  wire    [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                              mr_req_buffer_addr,
    output  wire    [`MR_CMD_HEAD_WIDTH - 1 : 0]                                                               	mr_req_buffer_din,
    input   wire    [`MR_CMD_HEAD_WIDTH - 1 : 0]                                                                mr_req_buffer_dout
);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     MR_CMD_LKEY_OFFSET                 95+8:64+8
`define     MR_CMD_TAG_OFFSET                  7:0
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg     [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG- 1 : 0]                                                               mr_req_head_diff;
reg     [`MR_CMD_DATA_WIDTH - 1 : 0]                                                               mr_req_data_diff;

wire    [COUNT_MAX_LOG - 1 : 0]                                                                     count_total;
wire    [COUNT_MAX_LOG - 1 : 0]                                                                     count_index;

reg    [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                                    req_tag;
reg    [PHYSICAL_ADDR_WIDTH - 1 : 0]                                                                phy_addr;
reg    [ICM_ADDR_WIDTH - 1 : 0]                                                                   icm_addr;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg         [2:0]       cur_state;
reg         [2:0]       next_state;

parameter   [2:0]       IDLE_s = 3'd1,
                        ADDR_REQ_s = 3'd2,
                        ADDR_RSP_s = 3'd3,
                        MPT_GET_s = 3'd4;

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
        IDLE_s:         if(mr_req_valid) begin
                            next_state = ADDR_REQ_s;
                        end
                        else begin
                            next_state = IDLE_s;
                        end
        ADDR_REQ_s:     if(icm_mapping_lookup_valid && icm_mapping_lookup_ready) begin
                            next_state = ADDR_RSP_s;
                        end
                        else begin
                            next_state = ADDR_REQ_s;
                        end
        ADDR_RSP_s:     if(icm_mapping_rsp_valid) begin
                            next_state = MPT_GET_s;
                        end
                        else begin
                            next_state = ADDR_RSP_s;
                        end
        MPT_GET_s:      if(icm_get_req_valid && icm_get_req_ready) begin
                            next_state = IDLE_s;
                        end
                        else begin
                            next_state = MPT_GET_s;
                        end
        default:        next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- mr_req_head_diff --
//-- mr_req_data_diff --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		mr_req_head_diff <= 'd0;
		mr_req_data_diff <= 'd0;
	end
	else if(cur_state == IDLE_s && mr_req_valid) begin
		mr_req_head_diff <= mr_req_head;
		mr_req_data_diff <= mr_req_data;
	end
	else begin
		mr_req_head_diff <= mr_req_head_diff;
		mr_req_data_diff <= mr_req_data_diff;
	end
end

//-- count_total --
//-- count_index --
assign count_total = {{(COUNT_MAX_LOG - 1){1'b0}}, 1'b1};         //For MPT Req, only one sub-req
assign count_index = {{(COUNT_MAX_LOG - 1){1'b0}}, 1'b0};

//-- mr_req_buffer_wen --
//-- mr_req_buffer_addr --
//-- mr_req_buffer_din --
assign mr_req_buffer_wen = (cur_state == MPT_GET_s) ? 'd1 : 'd0;
assign mr_req_buffer_addr = (cur_state == MPT_GET_s) ? req_tag : 'd0;
assign mr_req_buffer_din = (cur_state == MPT_GET_s) ? mr_req_head_diff[`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : `MAX_REQ_TAG_NUM_LOG] : 'd0;

//-- req_tag --
//-- phy_addr --
//-- icm_addr --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        req_tag <= 'd0;
        phy_addr <= 'd0;
        icm_addr <= 'd0;
    end
    else if (cur_state == ADDR_RSP_s && icm_mapping_rsp_valid) begin
        req_tag <= mr_req_head_diff[`MR_CMD_TAG_OFFSET];
        phy_addr <= icm_mapping_rsp_phy_addr;
        icm_addr <= icm_mapping_rsp_icm_addr;
    end
    else begin
        req_tag <= req_tag;
        phy_addr <= phy_addr;
        icm_addr <= icm_addr;
    end
end

//-- mr_req_ready --
assign mr_req_ready = (cur_state == IDLE_s) ? 'd1 : 'd0;

//-- icm_mapping_lookup_valid --
//-- icm_mapping_lookup_head --
assign icm_mapping_lookup_valid = (cur_state == ADDR_REQ_s) ? 'd1 : 'd0;
assign icm_mapping_lookup_head = (cur_state == ADDR_REQ_s) ? mr_req_head_diff[`MR_CMD_LKEY_OFFSET] : 'd0;

//-- icm_get_req_valid --
//-- icm_get_req_head --
assign icm_get_req_valid = (cur_state == MPT_GET_s) ? 'd1 : 'd0;
assign icm_get_req_head = (cur_state == MPT_GET_s) ? {count_total, count_index, req_tag, phy_addr, icm_addr} : 'd0;

// -- icm_mapping_rsp_ready --
assign icm_mapping_rsp_ready = (cur_state == ADDR_RSP_s) ? 'd1 : 'd0;
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef     MR_CMD_LKEY_OFFSET
`undef     MR_CMD_TAG_OFFSET 
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule