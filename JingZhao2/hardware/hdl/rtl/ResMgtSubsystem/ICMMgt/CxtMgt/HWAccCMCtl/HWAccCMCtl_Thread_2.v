/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       HWAccCMCtl_Thread_2
Author:     YangFan
Function:   Manage Hardware QPC access.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module HWAccCMCtl_Thread_2
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
    input   wire                                                                                                cxt_req_valid,
    input   wire    [`CXT_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                               cxt_req_head,
    input   wire    [`CXT_CMD_DATA_WIDTH - 1 : 0]                                                               cxt_req_data,
    output  wire                                                                                                cxt_req_ready,

//Mapping Lookup Interface
    output  wire                                                                                                icm_mapping_lookup_valid,
    output  wire    [ICM_ENTRY_NUM_LOG - 1 : 0]                                                                 icm_mapping_lookup_head,
    input   wire                                                                                                icm_mapping_lookup_ready,

    input   wire                                                                                                icm_mapping_rsp_valid,
    input   wire    [ICM_ADDR_WIDTH - 1 : 0]                                                                    icm_mapping_rsp_icm_addr,
    input   wire    [PHYSICAL_ADDR_WIDTH - 1 : 0]                                                               icm_mapping_rsp_phy_addr,
    output  wire                                                                                                icm_mapping_rsp_ready,

//ICM Get Interface
    output  wire                                                                                                qpc_get_req_valid,
    output  wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   qpc_get_req_head,
    input   wire                                                                                                qpc_get_req_ready

);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     CXT_CMD_TYPE_OFFSET                 63:60
`define     CXT_CMD_OPCODE_OFFSET               59:56
`define     CXT_CMD_QPN_OFFSET                  12+`QP_NUM_LOG-1:12
`define     CXT_CMD_TAG_OFFSET                  7:0
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg     [`CXT_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                               cxt_req_head_diff;

wire    [COUNT_MAX_LOG - 1 : 0]                                                                     count_total;
wire    [COUNT_MAX_LOG - 1 : 0]                                                                     count_index;

reg    [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                               req_tag;
reg    [PHYSICAL_ADDR_WIDTH - 1 : 0]                                                                phy_addr;
reg    [ICM_ADDR_WIDTH - 1 : 0]                                                                     icm_addr;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg         [2:0]       cur_state;
reg         [2:0]       next_state;

parameter   [2:0]       IDLE_s = 3'd1,
                        ADDR_REQ_s = 3'd2,
                        ADDR_RSP_s = 3'd3,
                        QPC_GET_s = 3'd4;

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
        IDLE_s:         if(cxt_req_valid) begin
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
                            next_state = QPC_GET_s;
                        end
                        else begin
                            next_state = ADDR_RSP_s;
                        end
        QPC_GET_s:      if(qpc_get_req_valid && qpc_get_req_ready) begin
                            next_state = IDLE_s;
                        end
                        else begin
                            next_state = QPC_GET_s;
                        end
        default:        next_state = IDLE_s;
    endcase
end

/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- count_total --
//-- count_index --
assign count_total = {{(COUNT_MAX_LOG - 1){1'b0}}, 1'b1};         //For Cxt Req, only one sub-req
assign count_index = {{(COUNT_MAX_LOG - 1){1'b0}}, 1'b0};

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
        req_tag <= {'d0, cxt_req_head_diff[`CXT_CMD_TAG_OFFSET]};
        phy_addr <= icm_mapping_rsp_phy_addr;
        icm_addr <= icm_mapping_rsp_icm_addr;
    end
    else begin
        req_tag <= req_tag;
        phy_addr <= phy_addr;
        icm_addr <= icm_addr;
    end
end

//-- cxt_req_ready --
assign cxt_req_ready = (cur_state == IDLE_s) ? 'd1 : 'd0;

//-- icm_mapping_rsp_ready --
assign icm_mapping_rsp_ready = (cur_state == ADDR_RSP_s) ? 'd1 : 'd0;

//-- icm_mapping_lookup_valid --
//-- icm_mapping_lookup_head --
assign icm_mapping_lookup_valid = (cur_state == ADDR_REQ_s) ? 'd1 : 'd0;
assign icm_mapping_lookup_head = (cur_state == ADDR_REQ_s) ? cxt_req_head_diff[`CXT_CMD_QPN_OFFSET] : 'd0;

//-- qpc_get_req_valid --
//-- qpc_get_req_head --
assign qpc_get_req_valid = (cur_state == QPC_GET_s) ? 'd1 : 'd0;
assign qpc_get_req_head = (cur_state == QPC_GET_s) ? {count_total, count_index, req_tag, phy_addr, icm_addr} : 'd0;

//-- cxt_req_head_diff --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cxt_req_head_diff <= 'd0;        
    end
    else if (cur_state == IDLE_s && cxt_req_valid) begin
        cxt_req_head_diff <= cxt_req_head;
    end

    else begin
        cxt_req_head_diff <= cxt_req_head_diff;
    end
end
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef      CXT_CMD_TYPE_OFFSET  
`undef      CXT_CMD_OPCODE_OFFSET 
`undef      CXT_CMD_QPN_OFFSET
`undef      CXT_CMD_TAG_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

`ifdef ILA_ON

ila_hw_acc_cm_thread_2 ila_hw_acc_cm_thread_2_inst(
    .clk(clk),

    .probe0(qpc_get_req_valid),
    .probe1(qpc_get_req_head),
    .probe2(qpc_get_req_ready)
);

`endif

endmodule