/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       PacketArbiter
Author:     YangFan
Function:   Arbitrate packets from 2 channel.
            In current design, we only support 2-channel, no-weight, round-robin arbitration.
            In the future, we will extend its function.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "ib_constant_def_h.vh"
`include "common_function_def.vh"
`include "transport_subsystem_def.vh"
`include "global_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module PacketDistributer (
    input   wire                                                            clk,
    input   wire                                                            rst,

    input   wire                                                            i_recv_valid,
    input   wire         [`PKT_HEAD_WIDTH - 1 : 0]                          iv_recv_head,
    input   wire         [`PKT_DATA_WIDTH - 1 : 0]                          iv_recv_data,
    input   wire                                                            i_recv_start,
    input   wire                                                            i_recv_last,
    output  wire                                                            o_recv_ready,

    output  wire                                                            o_channel_0_out_valid,
    output  wire         [`PKT_HEAD_WIDTH - 1 : 0]                          ov_channel_0_out_head,
    output  wire         [`PKT_DATA_WIDTH - 1 : 0]                          ov_channel_0_out_data,
    output  wire                                                            o_channel_0_out_start,
    output  wire                                                            o_channel_0_out_last,
    input   wire                                                            i_channel_0_out_ready,

    output  wire                                                            o_channel_1_out_valid,
    output  wire         [`PKT_HEAD_WIDTH - 1 : 0]                          ov_channel_1_out_head,
    output  wire         [`PKT_DATA_WIDTH - 1 : 0]                          ov_channel_1_out_data,
    output  wire                                                            o_channel_1_out_start,
    output  wire                                                            o_channel_1_out_last,
    input   wire                                                            i_channel_1_out_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                    [4:0]               wv_opcode;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
//None
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg             [1:0]               dis_cur_state;
reg             [1:0]               dis_next_state;

parameter       [1:0]       DIS_IDLE_s = 3'd1,
                            DIS_REQ_s = 3'd2,
                            DIS_ACK_s = 3'd3;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        dis_cur_state <= DIS_IDLE_s;
    end
    else begin
        dis_cur_state <= dis_next_state;
    end
end

always @(*) begin
    case(dis_cur_state)
        DIS_IDLE_s:         if(i_recv_valid && wv_opcode == `ACKNOWLEDGE) begin
                                dis_next_state = DIS_ACK_s;
                            end
                            else if(i_recv_valid && wv_opcode != `ACKNOWLEDGE) begin
                                dis_next_state = DIS_REQ_s;
                            end
                            else begin
                                dis_next_state = DIS_IDLE_s;
                            end
        DIS_REQ_s:          if(i_recv_valid && i_recv_last && i_channel_0_out_ready) begin
                                dis_next_state = DIS_IDLE_s;
                            end
                            else begin
                                dis_next_state = DIS_REQ_s;
                            end
        DIS_ACK_s:          if(i_recv_valid && i_recv_last && i_channel_1_out_ready) begin
                                dis_next_state = DIS_IDLE_s;
                            end
                            else begin
                                dis_next_state = DIS_ACK_s;
                            end
        default:            dis_next_state = DIS_IDLE_s;
    endcase
end

/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
assign o_recv_ready =   (dis_cur_state == DIS_IDLE_s) ? 'd0 : 
                        (dis_cur_state == DIS_REQ_s) ? i_channel_0_out_ready :
                        (dis_cur_state == DIS_ACK_s) ? i_channel_1_out_ready : 'd0;

assign o_channel_0_out_valid =  (dis_cur_state == DIS_IDLE_s) ? 'd0 : 
                                (dis_cur_state == DIS_REQ_s) ? i_recv_valid : 'd0;
assign ov_channel_0_out_head =  (dis_cur_state == DIS_IDLE_s) ? 'd0 : 
                                (dis_cur_state == DIS_REQ_s) ? iv_recv_head : 'd0;
assign ov_channel_0_out_data =  (dis_cur_state == DIS_IDLE_s) ? 'd0 : 
                                (dis_cur_state == DIS_REQ_s) ? iv_recv_data : 'd0;
assign o_channel_0_out_start =  (dis_cur_state == DIS_IDLE_s) ? 'd0 : 
                                (dis_cur_state == DIS_REQ_s) ? i_recv_start : 'd0;
assign o_channel_0_out_last =   (dis_cur_state == DIS_IDLE_s) ? 'd0 : 
                                (dis_cur_state == DIS_REQ_s) ? i_recv_last : 'd0;

assign o_channel_1_out_valid =  (dis_cur_state == DIS_IDLE_s) ? 'd0 : 
                                (dis_cur_state == DIS_ACK_s) ? i_recv_valid : 'd0;
assign ov_channel_1_out_head =  (dis_cur_state == DIS_IDLE_s) ? 'd0 : 
                                (dis_cur_state == DIS_ACK_s) ? iv_recv_head : 'd0;
assign ov_channel_1_out_data =  (dis_cur_state == DIS_IDLE_s) ? 'd0 : 
                                (dis_cur_state == DIS_ACK_s) ? iv_recv_data : 'd0;
assign o_channel_1_out_start =  (dis_cur_state == DIS_IDLE_s) ? 'd0 : 
                                (dis_cur_state == DIS_ACK_s) ? i_recv_start : 'd0;
assign o_channel_1_out_last =   (dis_cur_state == DIS_IDLE_s) ? 'd0 : 
                                (dis_cur_state == DIS_ACK_s) ? i_recv_last : 'd0;

assign wv_opcode = iv_recv_head[`OPCODE_OFFSET];
/*------------------------------------------- Variables Decode : End ------------------------------------------------*/
endmodule

