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

`define         CHNL_0          0
`define         CHNL_1          1

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module PacketArbiter (
    input   wire                                                            clk,
    input   wire                                                            rst,

    input   wire                                                            i_channel_0_valid,
    input   wire         [`PKT_HEAD_WIDTH - 1 : 0]                          iv_channel_0_head,
    input   wire         [`PKT_DATA_WIDTH - 1 : 0]                          iv_channel_0_data,
    input   wire                                                            i_channel_0_start,
    input   wire                                                            i_channel_0_last,
    output  wire                                                            o_channel_0_ready, 

    input   wire                                                            i_channel_1_valid,
    input   wire         [`PKT_HEAD_WIDTH - 1 : 0]                          iv_channel_1_head,
    input   wire         [`PKT_DATA_WIDTH - 1 : 0]                          iv_channel_1_data,
    input   wire                                                            i_channel_1_start,
    input   wire                                                            i_channel_1_last,
    output  wire                                                            o_channel_1_ready,  

    output  wire                                                            o_channel_out_valid,
    output  wire         [`PKT_HEAD_WIDTH - 1 : 0]                          ov_channel_out_head,
    output  wire         [`PKT_DATA_WIDTH - 1 : 0]                          ov_channel_out_data,
    output  wire                                                            o_channel_out_start,
    output  wire                                                            o_channel_out_last,
    input   wire                                                            i_channel_out_ready

);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/
reg                 last_sch_channel;
/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/

/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
//None
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg             [1:0]           arbit_cur_state;
reg             [1:0]           arbit_next_state;

parameter       [1:0]           ARBIT_IDLE_s = 2'd1,
                                ARBIT_CHNL_0 = 2'd2,
                                ARBIT_CHNL_1 = 2'd3;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        arbit_cur_state <= ARBIT_IDLE_s;
    end
    else begin
        arbit_cur_state <= arbit_next_state;
    end
end

always @(*) begin
    case(arbit_cur_state) 
        ARBIT_IDLE_s:       if(i_channel_0_valid && last_sch_channel == `CHNL_1) begin
                                arbit_next_state = ARBIT_CHNL_0;
                            end
                            else if(i_channel_1_valid && last_sch_channel == `CHNL_0) begin
                                arbit_next_state = ARBIT_CHNL_1;
                            end
                            else if(i_channel_0_valid && !i_channel_1_valid) begin
                                arbit_next_state = ARBIT_CHNL_0;
                            end
                            else if(i_channel_1_valid && !i_channel_0_valid) begin
                                arbit_next_state = ARBIT_CHNL_1;
                            end
                            else begin
                                arbit_next_state = ARBIT_IDLE_s;
                            end
        ARBIT_CHNL_0:       if(i_channel_0_valid && i_channel_0_last && i_channel_out_ready) begin
                                arbit_next_state = ARBIT_IDLE_s;
                            end
                            else begin
                                arbit_next_state = ARBIT_CHNL_0;
                            end
        ARBIT_CHNL_1:       if(i_channel_1_valid && i_channel_1_last && i_channel_out_ready) begin
                                arbit_next_state = ARBIT_IDLE_s;
                            end
                            else begin
                                arbit_next_state = ARBIT_CHNL_1;
                            end
        default:            arbit_next_state = ARBIT_IDLE_s;
    endcase
end

/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- last_sch_channel --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        last_sch_channel <= `CHNL_0;
    end
    else if(arbit_cur_state == ARBIT_CHNL_0 && i_channel_0_valid && i_channel_0_last && i_channel_out_ready) begin
        last_sch_channel <= `CHNL_0;
    end
    else if(arbit_cur_state == ARBIT_CHNL_1 && i_channel_1_valid && i_channel_1_last && i_channel_out_ready) begin
        last_sch_channel <= `CHNL_1;
    end
    else begin
        last_sch_channel <= last_sch_channel;
    end
end

//-- o_channel_0_ready --
assign o_channel_0_ready = (arbit_cur_state == ARBIT_CHNL_0) ? i_channel_out_ready : 'd0;

//-- o_channel_1_ready --
assign o_channel_1_ready = (arbit_cur_state == ARBIT_CHNL_1) ? i_channel_out_ready : 'd0;

//-- o_channel_out_valid --
assign o_channel_out_valid = (arbit_cur_state == ARBIT_CHNL_0) ? i_channel_0_valid : 
                             (arbit_cur_state == ARBIT_CHNL_1) ? i_channel_1_valid : 'd0;

//-- ov_channel_out_head --
assign ov_channel_out_head = (arbit_cur_state == ARBIT_CHNL_0) ? iv_channel_0_head : 
                             (arbit_cur_state == ARBIT_CHNL_1) ? iv_channel_1_head : 'd0;

//-- ov_channel_out_data --
assign ov_channel_out_data = (arbit_cur_state == ARBIT_CHNL_0) ? iv_channel_0_data : 
                             (arbit_cur_state == ARBIT_CHNL_1) ? iv_channel_1_data : 'd0;

//-- o_channel_out_start --
assign o_channel_out_start = (arbit_cur_state == ARBIT_CHNL_0) ? i_channel_0_start : 
                             (arbit_cur_state == ARBIT_CHNL_1) ? i_channel_1_start : 'd0;

//-- o_channel_out_last --
assign o_channel_out_last = (arbit_cur_state == ARBIT_CHNL_0) ? i_channel_0_last : 
                            (arbit_cur_state == ARBIT_CHNL_1) ? i_channel_1_last : 'd0;

/*------------------------------------------- Variables Decode : End ------------------------------------------------*/
endmodule