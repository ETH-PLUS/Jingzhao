/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       DBProc
Author:     YangFan
Function:   Parse doorbell and update SQ Head.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module DBProc
(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with PIO
    input   wire                                                            db_fifo_empty,
    input   wire            [63:0]                                          db_fifo_dout,
    output  wire                                                            db_fifo_rd_en,

//Interface with QPNArbiter
    output  wire                                                            qpn_fifo_valid,
    output  wire            [23:0]                                          qpn_fifo_data,
    input   wire                                                            qpn_fifo_ready,

//Interface with OnScheduleRecord
    output  wire            [23:0]                                          on_schedule_addr,
    input   wire            [0:0]                                           on_schedule_dout,

//Interface with SQHeadRecord
    output  wire            [0:0]                                           sq_head_record_wen,
    output  wire            [`QP_NUM_LOG - 1 : 0]                           sq_head_record_addr,
    output  wire            [23:0]                                          sq_head_record_din,
    input   wire            [23:0]                                          sq_head_record_dout
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define                 SQ_HEAD_OFFSET              31:8
`define                 QPN_OFFSET                  63:40
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg                 [2:0]                   cur_state;
reg                 [2:0]                   next_state;

parameter           IDLE_s      =   2'd1,
                    UPDATE_s    =   2'd2;

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
        IDLE_s:         if(!db_fifo_empty) begin
                            next_state = UPDATE_s;
                        end
                        else begin
                            next_state = IDLE_s;
                        end
        UPDATE_s:       if(!on_schedule_dout && qpn_fifo_ready) begin
                            next_state = IDLE_s; 
                        end
                        else if(on_schedule_dout) begin
                            next_state = IDLE_s;
                        end
                        else begin
                            next_state = UPDATE_s;
                        end
        default:        next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- db_fifo_rd_en --
assign db_fifo_rd_en = (cur_state == UPDATE_s) && ((!on_schedule_dout && qpn_fifo_ready) || on_schedule_dout) ? 'd1 : 'd0;

//-- qpn_fifo_valid --
//-- qpn_fifo_data --
assign qpn_fifo_valid = ((cur_state == UPDATE_s) && !on_schedule_dout) ? 'd1 : 'd0;
assign qpn_fifo_data = ((cur_state == UPDATE_s) && !on_schedule_dout) ? db_fifo_dout[`QPN_OFFSET] : 'd0;

//Interface with OnScheduleRecord
assign on_schedule_addr = db_fifo_dout[`QPN_OFFSET];

//Interface with SQHeadRecord
assign sq_head_record_wen = (cur_state == UPDATE_s) ? 'd1 : 'd0;
assign sq_head_record_addr = (cur_state == UPDATE_s) ? db_fifo_dout[`QPN_OFFSET] : 'd0; 
assign sq_head_record_din = (cur_state == UPDATE_s) ? db_fifo_dout[`SQ_HEAD_OFFSET] : 'd0;
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef                  SQ_HEAD_OFFSET
`undef                  QPN_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule