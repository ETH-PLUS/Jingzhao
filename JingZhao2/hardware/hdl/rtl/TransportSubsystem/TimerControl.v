/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       TimerControl
Author:     YangFan
Function:   Provides timer for reliable data transfer.
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
module TimerControl (
    input   wire                                                            clk,
    input   wire                                                            rst,

    //Timer event in
    //Timer event format : {QPN}
    input   wire                                                            i_time_out_empty,
    input   wire        [`TIMER_EVENT_WIDTH - 1 : 0]                        iv_time_out_dout,
    output  wire                                                            o_time_out_rd_en,

    //Timer set out
    //Timer set format : {ACTION, QPN}
    output  wire                                                            o_timer_set_prog_full_A,
    input   wire                                                            i_timer_set_wr_en_A,
    input   wire       [`TIMER_CMD_WIDTH - 1 : 0]                           iv_timer_set_din_A,

    output  wire                                                            o_timer_set_prog_full_B,
    input   wire                                                            i_timer_set_wr_en_B,
    input   wire       [`TIMER_CMD_WIDTH - 1 : 0]                           iv_timer_set_din_B

);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/

/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
SyncFIFO_Template #(
    .FIFO_WIDTH(`TIMER_EVENT_WIDTH),
    .FIFO_DEPTH(64)
)
TimerEventFIFO_Inst
(
    .clk(clk),
    .rst(rst),

    .wr_en('d0),
    .din('d0),
    .prog_full(),
    .rd_en(o_time_out_rd_en),
    .dout(iv_time_out_dout),
    .empty(i_time_out_empty),
    .data_count()
);

SyncFIFO_Template #(
    .FIFO_WIDTH(`TIMER_CMD_WIDTH),
    .FIFO_DEPTH(64)
)
TimerSet_A_FIFO_Inst
(
    .clk(clk),
    .rst(rst),

    .wr_en(i_timer_set_wr_en_A),
    .din(iv_timer_set_din_A),
    .prog_full(o_timer_set_prog_full_A),
    .rd_en('d1),
    .dout(),
    .empty(),
    .data_count()
);

SyncFIFO_Template #(
    .FIFO_WIDTH(`TIMER_CMD_WIDTH),
    .FIFO_DEPTH(64)
)
TimerSet_B_FIFO_Inst
(
    .clk(clk),
    .rst(rst),

    .wr_en(i_timer_set_wr_en_B),
    .din(iv_timer_set_din_B),
    .prog_full(o_timer_set_prog_full_B),
    .rd_en('d1),
    .dout(),
    .empty(),
    .data_count()
);

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/

/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Variables Decode : End ------------------------------------------------*/
endmodule