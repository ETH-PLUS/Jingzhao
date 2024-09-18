/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       HWAccCMCtl_Thread_1
Author:     YangFan
Function:   Arbitrate from different Request Channels..
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module HWAccCMCtl_Thread_6
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

//Interface with HWAccCMCtl_Thread_5
    input  	wire                                                                                                cxt_combine_valid,
    input  	wire    [`CXT_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                       cxt_combine_head,
    input  	wire    [`CXT_RESP_DATA_WIDTH - 1 : 0]                                                              cxt_combine_data,
    output  wire                                                                                                cxt_combine_ready,

//Interface with TagQPNMappingTable
    output  wire    [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                              tag_qpn_mapping_table_addr,
    input   wire    [`QP_NUM_LOG - 1 : 0]                                                                       tag_qpn_mapping_table_dout,

//Interface with RDMACore and QueueSubsystem
    //Interface with SQMgt
    output  wire                                                                                                SQ_cxt_rsp_valid,
    output  wire    [`CXT_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                       SQ_cxt_rsp_head,
    output  wire    [`CXT_RESP_DATA_WIDTH - 1 : 0]                                                              SQ_cxt_rsp_data,
    input   wire                                                                                                SQ_cxt_rsp_ready,

    //Interface with RDMACore/RequesterCore/ReqTransCore
    output  wire                                                                                                TX_REQ_cxt_rsp_valid,
    output  wire    [`CXT_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                       TX_REQ_cxt_rsp_head,
    output  wire    [`CXT_RESP_DATA_WIDTH - 1 : 0]                                                              TX_REQ_cxt_rsp_data,
    input   wire                                                                                                TX_REQ_cxt_rsp_ready,

    //Interface with RDMACore/RequesterCore/RespRecvCore
    output  wire                                                                                                RX_REQ_cxt_rsp_valid,
    output  wire    [`CXT_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                       RX_REQ_cxt_rsp_head,
    output  wire    [`CXT_RESP_DATA_WIDTH - 1 : 0]                                                              RX_REQ_cxt_rsp_data,
    input   wire                                                                                                RX_REQ_cxt_rsp_ready,

    //Interface with RDMACore/ResponderCore/ReqRecvCore
    output  wire                                                                                                RX_RESP_cxt_rsp_valid,
    output  wire    [`CXT_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                       RX_RESP_cxt_rsp_head,
    output  wire    [`CXT_RESP_DATA_WIDTH - 1 : 0]                                                              RX_RESP_cxt_rsp_data,
    input   wire                                                                                                RX_RESP_cxt_rsp_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/

/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire    [1:0]                                       chnl_index;

reg     [`CXT_RESP_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]              cxt_combine_head_diff;
reg     [`CXT_RESP_DATA_WIDTH - 1 : 0]              cxt_combine_data_diff;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg             [2:0]               cur_state;
reg             [2:0]               next_state;

parameter       [2:0]               IDLE_s          =   3'd1,
                                    CHNL_0_RSP_s    =   3'd2,
                                    CHNL_1_RSP_s    =   3'd3,
                                    CHNL_2_RSP_s    =   3'd4,
                                    CHNL_3_RSP_s    =   3'd5;

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
        IDLE_s:                 if(cxt_combine_valid) begin
                                    if(chnl_index == 0) begin
                                        next_state = CHNL_0_RSP_s;
                                    end
                                    else if(chnl_index == 1) begin
                                        next_state = CHNL_1_RSP_s;
                                    end
                                    else if(chnl_index == 2) begin
                                        next_state = CHNL_2_RSP_s;
                                    end
                                    else if(chnl_index == 3) begin
                                        next_state = CHNL_3_RSP_s;
                                    end
                                    else begin
                                        next_state = IDLE_s;
                                    end
                                end
                                else begin
                                    next_state = IDLE_s;
                                end
        CHNL_0_RSP_s:           if(SQ_cxt_rsp_valid && SQ_cxt_rsp_ready) begin
                                    next_state = IDLE_s;
                                end
                                else begin
                                    next_state = CHNL_0_RSP_s;
                                end
        CHNL_1_RSP_s:           if(TX_REQ_cxt_rsp_valid && TX_REQ_cxt_rsp_ready) begin
                                    next_state = IDLE_s;
                                end
                                else begin
                                    next_state = CHNL_1_RSP_s;
                                end
        CHNL_2_RSP_s:           if(RX_REQ_cxt_rsp_valid && RX_REQ_cxt_rsp_ready) begin
                                    next_state = IDLE_s;
                                end
                                else begin
                                    next_state = CHNL_2_RSP_s;
                                end
        CHNL_3_RSP_s:           if(RX_RESP_cxt_rsp_valid && RX_RESP_cxt_rsp_ready) begin
                                    next_state = IDLE_s;
                                end
                                else begin
                                    next_state = CHNL_3_RSP_s;
                                end
        default:                next_state  =   IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- chnl_index --
assign chnl_index = (cur_state == IDLE_s && cxt_combine_valid) ? cxt_combine_head[REQ_TAG_NUM_LOG + 2 - 1 : REQ_TAG_NUM_LOG] : 'd0;

//-- cxt_combine_head_diff --
//-- cxt_combine_data_diff --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cxt_combine_head_diff <= 'd0;
        cxt_combine_data_diff <= 'd0;
    end
    else if (cur_state == IDLE_s && cxt_combine_valid) begin
        cxt_combine_head_diff <= cxt_combine_head;
        cxt_combine_data_diff <= cxt_combine_data;        
    end
    else begin
        cxt_combine_head_diff <= cxt_combine_head_diff;
        cxt_combine_data_diff <= cxt_combine_data_diff;
    end
end

//-- tag_qpn_mapping_table_addr --
assign tag_qpn_mapping_table_addr = (cur_state == IDLE_s && cxt_combine_valid) ? cxt_combine_head[`MAX_REQ_TAG_NUM_LOG - 1 : 0] : cxt_combine_head_diff[`MAX_REQ_TAG_NUM_LOG - 1 : 0];

wire        [`MAX_REQ_TAG_NUM_LOG - 1 : 0]      rsp_tag;
assign rsp_tag = {'d0, cxt_combine_head_diff[REQ_TAG_NUM_LOG - 1 : 0]};

//-- SQ_cxt_rsp_valid --
//-- SQ_cxt_rsp_head --
//-- SQ_cxt_rsp_data --
assign SQ_cxt_rsp_valid = (cur_state == CHNL_0_RSP_s) ? 'd1 : 'd0;
assign SQ_cxt_rsp_head = (cur_state == CHNL_0_RSP_s) ? {tag_qpn_mapping_table_dout, rsp_tag} : 'd0;
assign SQ_cxt_rsp_data = (cur_state == CHNL_0_RSP_s) ? cxt_combine_data_diff : 'd0;

//-- TX_REQ_cxt_rsp_valid --
//-- TX_REQ_cxt_rsp_head --
//-- TX_REQ_cxt_rsp_data --
assign TX_REQ_cxt_rsp_valid = (cur_state == CHNL_1_RSP_s) ? 'd1 : 'd0;
assign TX_REQ_cxt_rsp_head = (cur_state == CHNL_1_RSP_s) ? {tag_qpn_mapping_table_dout, rsp_tag} : 'd0;
assign TX_REQ_cxt_rsp_data = (cur_state == CHNL_1_RSP_s) ? cxt_combine_data_diff : 'd0;

//-- RX_REQ_cxt_rsp_valid --
//-- RX_REQ_cxt_rsp_head --
//-- RX_REQ_cxt_rsp_data --
assign RX_REQ_cxt_rsp_valid = (cur_state == CHNL_2_RSP_s) ? 'd1 : 'd0;
assign RX_REQ_cxt_rsp_head = (cur_state == CHNL_2_RSP_s) ? {tag_qpn_mapping_table_dout, rsp_tag} : 'd0;
assign RX_REQ_cxt_rsp_data = (cur_state == CHNL_2_RSP_s) ? cxt_combine_data_diff : 'd0;

//-- RX_RESP_cxt_rsp_valid --
//-- RX_RESP_cxt_rsp_head --
//-- RX_RESP_cxt_rsp_data --
assign RX_RESP_cxt_rsp_valid = (cur_state == CHNL_3_RSP_s) ? 'd1 : 'd0;
assign RX_RESP_cxt_rsp_head = (cur_state == CHNL_3_RSP_s) ? {tag_qpn_mapping_table_dout, rsp_tag} : 'd0;
assign RX_RESP_cxt_rsp_data = (cur_state == CHNL_3_RSP_s) ? cxt_combine_data_diff : 'd0;

//-- cxt_combine_ready --
assign cxt_combine_ready = (cur_state == IDLE_s);
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule