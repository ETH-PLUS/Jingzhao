/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       HWAccCMCtl_Thread_5
Author:     YangFan
Function:   Deal with EQC rsp and piece QPC-CQC-EQC together.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module HWAccCMCtl_Thread_5
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
    parameter               REORDER_BUFFER_WIDTH    =       (ICM_CACHE_TYPE == `CACHE_TYPE_MTT) ? CACHE_ENTRY_WIDTH * 2 + COUNT_MAX_LOG : CACHE_ENTRY_WIDTH + COUNT_MAX_LOG,

    parameter               CQN_NUM                 =       `ICM_ENTRY_NUM_CQC,
    parameter               CQN_NUM_LOG             =       log2b(CQN_NUM - 1)
)
(
    input   wire                                                                                                clk,
    input   wire                                                                                                rst,

//Interface with EQCCache
    input   wire                                                                                                eqc_get_rsp_valid,
    input   wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   eqc_get_rsp_head,
    input   wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                 eqc_get_rsp_data,
    output  wire                                                                                                eqc_get_rsp_ready,

//Interface with QPCStagedBuffer
    output  wire    [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                              qpc_buffer_addr,
    input   wire    [`CACHE_ENTRY_WIDTH_QPC - 1 : 0]                                                            qpc_buffer_dout,

//Interface with CQCStagedBuffer
    output  wire    [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                              cqc_buffer_addr,
    input   wire    [`CACHE_ENTRY_WIDTH_CQC - 1 : 0]                                                            cqc_buffer_dout,

//Interface with HWAccessCtl_Thread_6
    output  wire                                                                                                cxt_combine_valid,
    output  wire    [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                              cxt_combine_head,
    output  wire    [`CXT_RESP_DATA_WIDTH - 1 : 0]                                                              cxt_combine_data,
    input   wire                                                                                                cxt_combine_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg     [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]      eqc_get_rsp_head_diff;
reg     [CACHE_ENTRY_WIDTH - 1 : 0]                                                                 eqc_get_rsp_data_diff;

reg     [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                                   req_tag;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg         [1:0]                   cur_state;
reg         [1:0]                   next_state;

parameter   [1:0]                   IDLE_s = 2'd1,
                                    COMBINE_s = 2'd2,
                                    RSP_s = 2'd3;

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
        IDLE_s:         if(eqc_get_rsp_valid) begin
                            next_state = COMBINE_s;
                        end
                        else begin
                            next_state = IDLE_s;
                        end
        COMBINE_s:      next_state = RSP_s;
        RSP_s:          if(cxt_combine_valid && cxt_combine_ready) begin
                            next_state = IDLE_s;
                        end
                        else begin
                            next_state = RSP_s;
                        end
        default:        next_state  = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- eqc_get_rsp_head_diff --
//-- eqc_get_rsp_data_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        eqc_get_rsp_head_diff <= 'd0;
        eqc_get_rsp_data_diff <= 'd0;
    end
    else if(cur_state == IDLE_s && eqc_get_rsp_valid) begin
        eqc_get_rsp_head_diff <= eqc_get_rsp_head;
        eqc_get_rsp_data_diff <= eqc_get_rsp_data;
    end
    else begin
        eqc_get_rsp_head_diff <= eqc_get_rsp_head_diff;
        eqc_get_rsp_data_diff <= eqc_get_rsp_data_diff;
    end
end

//-- req_tag --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        req_tag <= 'd0;
    end
    else if(cur_state == IDLE_s && eqc_get_rsp_valid) begin
        req_tag <= eqc_get_rsp_head[`MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH];
    end
    else begin
        req_tag <= req_tag;
    end
end

//-- qpc_buffer_addr --
assign qpc_buffer_addr = req_tag;

//-- cqc_buffer_addr --
assign cqc_buffer_addr = req_tag;

//-- cxt_combine_valid --
//-- cxt_combine_head --
//-- cxt_combine_data --
assign cxt_combine_valid = (cur_state == RSP_s) ? 'd1 :  'd0;
assign cxt_combine_head = (cur_state == RSP_s) ? req_tag : 'd0;
assign cxt_combine_data = (cur_state == RSP_s) ? {eqc_get_rsp_data_diff, cqc_buffer_dout, qpc_buffer_dout} : 'd0;


//-- eqc_get_rsp_ready --
assign eqc_get_rsp_ready = (cur_state == IDLE_s);
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/
`ifdef ILA_ON

ila_hw_acc_cm_thread_5 ila_hw_acc_cm_thread_5_inst(
    .clk(clk),

    .probe0(eqc_get_rsp_valid),
    .probe1(eqc_get_rsp_head),
    .probe2(eqc_get_rsp_data),
    .probe3(eqc_get_rsp_ready),

    .probe4(qpc_buffer_addr),
    .probe5(qpc_buffer_dout),

    .probe6(cqc_buffer_addr),
    .probe7(cqc_buffer_dout),

    .probe8(cxt_combine_valid),
    .probe9(cxt_combine_head),
    .probe10(cxt_combine_data),
    .probe11(cxt_combine_ready)
);

`endif

endmodule