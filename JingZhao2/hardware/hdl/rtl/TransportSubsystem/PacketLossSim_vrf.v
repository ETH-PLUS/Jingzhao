/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       PacketLossSim_vrf
Author:     YangFan
Function:   Intentially drop some packets(Req or ACK), for verification.
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

// `define     PORT_A_LOSS_CNT         100       //Drop a packet when cnt reaches this threshold
// `define     PORT_B_LOSS_CNT         100

module PacketLossSim_vrf(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Port A Interface
    input   wire                                                            i_recv_from_port_A_valid,
    input   wire        [`PKT_HEAD_WIDTH - 1 : 0]                           iv_recv_from_port_A_head,
    input   wire        [`PKT_DATA_WIDTH - 1 : 0]                           iv_recv_from_port_A_data,
    input   wire                                                            i_recv_from_port_A_start,
    input   wire                                                            i_recv_from_port_A_last,
    output  wire                                                            o_recv_from_port_A_ready,

    output  wire                                                            o_send_to_port_A_valid,
    output  wire         [`PKT_HEAD_WIDTH - 1 : 0]                          ov_send_to_port_A_head,
    output  wire         [`PKT_DATA_WIDTH - 1 : 0]                          ov_send_to_port_A_data,
    output  wire                                                            o_send_to_port_A_start,
    output  wire                                                            o_send_to_port_A_last,
    input   wire                                                            i_send_to_port_A_ready,

//Port B Interface
    input   wire                                                            i_recv_from_port_B_valid,
    input   wire        [`PKT_HEAD_WIDTH - 1 : 0]                           iv_recv_from_port_B_head,
    input   wire        [`PKT_DATA_WIDTH - 1 : 0]                           iv_recv_from_port_B_data,
    input   wire                                                            i_recv_from_port_B_start,
    input   wire                                                            i_recv_from_port_B_last,
    output  wire                                                            o_recv_from_port_B_ready,

    output  wire                                                            o_send_to_port_B_valid,
    output  wire        [`PKT_HEAD_WIDTH - 1 : 0]                           ov_send_to_port_B_head,
    output  wire        [`PKT_DATA_WIDTH - 1 : 0]                           ov_send_to_port_B_data,
    output  wire                                                            o_send_to_port_B_start,
    output  wire                                                            o_send_to_port_B_last,
    input   wire                                                            i_send_to_port_B_ready
);

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg                     [63:0]              port_A_cnt;
reg                     [63:0]              port_B_cnt;

/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
assign o_recv_from_port_A_ready = (port_A_cnt != `PORT_A_LOSS_CNT) ?  i_send_to_port_B_ready : 'd1;

assign o_send_to_port_A_valid = (port_B_cnt != `PORT_B_LOSS_CNT) ? i_recv_from_port_B_valid : 'd0;
assign ov_send_to_port_A_head = (port_B_cnt != `PORT_B_LOSS_CNT) ? iv_recv_from_port_B_head : 'd0;
assign ov_send_to_port_A_data = (port_B_cnt != `PORT_B_LOSS_CNT) ? iv_recv_from_port_B_data : 'd0;
assign o_send_to_port_A_start = (port_B_cnt != `PORT_B_LOSS_CNT) ? i_recv_from_port_B_start : 'd0;
assign o_send_to_port_A_last = (port_B_cnt != `PORT_B_LOSS_CNT) ? i_recv_from_port_B_last : 'd0;

assign o_recv_from_port_B_ready = (port_B_cnt != `PORT_B_LOSS_CNT) ?  i_send_to_port_A_ready : 'd1;

assign o_send_to_port_B_valid = (port_A_cnt != `PORT_A_LOSS_CNT) ? i_recv_from_port_A_valid : 'd0;
assign ov_send_to_port_B_head = (port_A_cnt != `PORT_A_LOSS_CNT) ? iv_recv_from_port_A_head : 'd0;
assign ov_send_to_port_B_data = (port_A_cnt != `PORT_A_LOSS_CNT) ? iv_recv_from_port_A_data : 'd0;
assign o_send_to_port_B_start = (port_A_cnt != `PORT_A_LOSS_CNT) ? i_recv_from_port_A_start : 'd0;
assign o_send_to_port_B_last = (port_A_cnt != `PORT_A_LOSS_CNT) ? i_recv_from_port_A_last : 'd0;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        port_A_cnt <= 'd0;
    end
    else if(port_A_cnt == `PORT_A_LOSS_CNT) begin
        if(i_recv_from_port_A_last) begin
            port_A_cnt <= 'd0;
        end
        else begin
            port_A_cnt <= port_A_cnt;
        end
    end
    else begin
        if(i_recv_from_port_A_last && i_send_to_port_B_ready) begin
            port_A_cnt <= port_A_cnt + 'd1;
        end
        else begin
            port_A_cnt <= port_A_cnt;
        end
    end     
end

always @(posedge clk or posedge rst) begin
    if(rst) begin
        port_B_cnt <= 'd0;
    end
    else if(port_B_cnt == `PORT_B_LOSS_CNT) begin
        if(i_recv_from_port_B_last) begin
            port_B_cnt <= 'd0;
        end
        else begin
            port_B_cnt <= port_B_cnt;
        end
    end
    else begin
        if(i_recv_from_port_B_last && i_send_to_port_A_ready) begin
            port_B_cnt <= port_B_cnt + 'd1;
        end
        else begin
            port_B_cnt <= port_B_cnt;
        end
    end     
end
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

endmodule