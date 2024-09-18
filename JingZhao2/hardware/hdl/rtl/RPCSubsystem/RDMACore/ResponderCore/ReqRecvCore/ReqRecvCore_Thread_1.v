/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ReqRecvCore_Thread_1
Author:     YangFan
Function:   1.Fetch Cxt and generate Net Meta.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module ReqRecvCore_Thread_1
#(
    parameter                       INGRESS_CXT_HEAD_WIDTH                  =   128,
    parameter                       INGRESS_CXT_DATA_WIDTH                  =   256
)
(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with MACDecap
    input   wire                                                            ingress_pkt_valid,
    input   wire    [`PKT_META_BUS_WIDTH - 1 : 0]                           ingress_pkt_head,
    output  wire                                                            ingress_pkt_ready,

//Interface with OoOStation(For CxtMgt)
    output  wire                                                            fetch_cxt_ingress_valid,
    output  wire    [`RX_REQ_OOO_CXT_INGRESS_HEAD_WIDTH - 1 : 0]            fetch_cxt_ingress_head,
    output  wire    [`RX_REQ_OOO_CXT_INGRESS_DATA_WIDTH - 1 : 0]            fetch_cxt_ingress_data,
    output  wire                                                            fetch_cxt_ingress_start,
    output  wire                                                            fetch_cxt_ingress_last,
    input   wire                                                            fetch_cxt_ingress_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     REMOTE_QPN_OFFSET                   55:32
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire            [`INGRESS_COMMON_HEAD_WIDTH - 1 : 0]            ingress_common_head;
wire            [`MAX_OOO_SLOT_NUM_LOG - 1 :0]                                          ingress_slot_count;

reg                 [`PKT_META_BUS_WIDTH - 1 : 0]                       pkt_header_bus;
                
wire                [23:0]                                          PktHeader_remote_qpn;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg                 [2:0]                       cur_state;
reg                 [2:0]                       next_state;

parameter           [2:0]                       IDLE_s = 3'd1,
                                                JUDGE_s = 3'd2,
                                                FETCH_CXT_s = 3'd3;

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
        IDLE_s:             if(ingress_pkt_valid) begin
                                next_state = JUDGE_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
        JUDGE_s:            next_state = FETCH_CXT_s;
        FETCH_CXT_s:        if(fetch_cxt_ingress_valid && fetch_cxt_ingress_ready) begin
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = FETCH_CXT_s;
                            end
        default:            next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
wire        [`QP_NUM_LOG - 1 : 0]                   qpn_data;
assign qpn_data = PktHeader_remote_qpn;

wire        [`MAX_QP_NUM_LOG - 1 : 0]               queue_index;
assign queue_index = {'d0, qpn_data[`QP_NUM_LOG - 1 : 0]};

//-- pkt_header_bus --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        pkt_header_bus <= 'd0;
    end
    else if(cur_state == IDLE_s && ingress_pkt_valid) begin
        pkt_header_bus <= ingress_pkt_head;
    end
    else begin
        pkt_header_bus <= pkt_header_bus;
    end
end

//-- PktHeader_remote_qpn --
assign PktHeader_remote_qpn = pkt_header_bus[`REMOTE_QPN_OFFSET];


//-- ingress_common_head --
//-- ingress_slot_count --
assign ingress_common_head = {`NO_BYPASS, ingress_slot_count, queue_index};
assign ingress_slot_count = 'd1;

//-- fetch_cxt_ingress_valid --
//-- fetch_cxt_ingress_head --
//-- fetch_cxt_ingress_data --
//-- fetch_cxt_ingress_start --
//-- fetch_cxt_ingress_last --
assign fetch_cxt_ingress_valid = (cur_state == FETCH_CXT_s) ? 'd1 : 'd0;
assign fetch_cxt_ingress_head = (cur_state == FETCH_CXT_s) ? {qpn_data[`QP_NUM_LOG - 1 : 0], `CXT_READ, ingress_common_head} : 'd0;
assign fetch_cxt_ingress_data = (cur_state == FETCH_CXT_s) ? pkt_header_bus : 'd0;
assign fetch_cxt_ingress_start = (cur_state == FETCH_CXT_s) ? 'd1 : 'd0;
assign fetch_cxt_ingress_last = (cur_state == FETCH_CXT_s) ? 'd1 : 'd0;

//-- ingress_pkt_ready --
assign ingress_pkt_ready = (cur_state == IDLE_s) ? 'd1 : 'd0;
/*------------------------------------------- Variables Decode : End ----------------------------------------------***/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef     REMOTE_QPN_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule