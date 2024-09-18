/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       SQMetaProc_Thread_1
Author:     YangFan
Function:   Fetch SQ Context.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module SQMetaProc_Thread_1
(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with QPNArbiter
    input   wire                                                            qpn_valid,
    input   wire            [23:0]                                          qpn_data,
    output  wire                                                            qpn_ready,

    output  wire                                                            fetch_cxt_ingress_valid,
    output  wire            [`SQ_OOO_CXT_INGRESS_HEAD_WIDTH - 1 : 0]        fetch_cxt_ingress_head,
    output  wire            [`SQ_OOO_CXT_INGRESS_DATA_WIDTH - 1 : 0]        fetch_cxt_ingress_data,
    output  wire                                                            fetch_cxt_ingress_start,
    output  wire                                                            fetch_cxt_ingress_last,
    input   wire                                                            fetch_cxt_ingress_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/

/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire            [`INGRESS_COMMON_HEAD_WIDTH - 1 : 0]            ingress_common_head;
wire            [`MAX_OOO_SLOT_NUM_LOG - 1 :0]                                          ingress_slot_count;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg         [1:0]               cur_state;
reg         [1:0]               next_state;

parameter   [1:0]               IDLE_s      =   2'd1,
                                FETCH_CXT_s =   2'd2;

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
        IDLE_s:         if(qpn_valid) begin
                            next_state = FETCH_CXT_s;
                        end
                        else begin
                            next_state = IDLE_s;
                        end
        FETCH_CXT_s:    if(fetch_cxt_ingress_valid && fetch_cxt_ingress_ready) begin
                            next_state = IDLE_s;
                        end
                        else begin
                            next_state = FETCH_CXT_s;
                        end
        default:        next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- qpn_ready --
assign qpn_ready = (cur_state == FETCH_CXT_s && fetch_cxt_ingress_valid && fetch_cxt_ingress_ready) ? 'd1 : 'd0;

wire        [`MAX_QP_NUM_LOG - 1 : 0]               queue_index;
assign queue_index = {'d0, qpn_data[`QP_NUM_LOG - 1 : 0]};

//-- ingress_common_head --
//-- ingress_slot_count --
assign ingress_common_head = {`NO_BYPASS, ingress_slot_count, queue_index};
assign ingress_slot_count = 'd1;

//-- fetch_cxt_ingress_valid --
//-- fetch_cxt_ingress_head --
//-- fetch_cxt_ingress_data --
assign fetch_cxt_ingress_valid = (cur_state == FETCH_CXT_s) ? 'd1 : 'd0;
assign fetch_cxt_ingress_head = (cur_state == FETCH_CXT_s) ? {qpn_data[`QP_NUM_LOG - 1 : 0], `CXT_READ, ingress_common_head} : 'd0;
assign fetch_cxt_ingress_data = (cur_state == FETCH_CXT_s) ? 'd0 : 'd0;     //No extra data
assign fetch_cxt_ingress_start = (cur_state == FETCH_CXT_s) ? 'd1 : 'd0;
assign fetch_cxt_ingress_last = (cur_state == FETCH_CXT_s) ? 'd1 : 'd0;
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule