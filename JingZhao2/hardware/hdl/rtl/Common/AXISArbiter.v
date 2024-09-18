/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       AXISArbiter
Author:     YangFan
Function:   Arbitrate different axis signals.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define 	CHANNEL_A 		0
`define 	CHANNEL_B 		1
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module AXISArbiter
#(
    parameter       HEAD_WIDTH              =       128,
    parameter       DATA_WIDTH              =       512
)
(
	input   wire                                                        clk,
    input   wire                                                        rst,

	input   wire														in_axis_valid_a,
	input   wire	[HEAD_WIDTH - 1 : 0]		                        in_axis_head_a,
	input   wire	[DATA_WIDTH - 1 : 0]						        in_axis_data_a,
	input   wire 														in_axis_start_a,
	input   wire														in_axis_last_a,
	output  wire  														in_axis_ready_a,

	input   wire														in_axis_valid_b,
	input   wire	[HEAD_WIDTH - 1 : 0]		                        in_axis_head_b,
	input   wire	[DATA_WIDTH - 1 : 0]						        in_axis_data_b,
	input   wire 														in_axis_start_b,
	input   wire														in_axis_last_b,
	output  wire  														in_axis_ready_b,

	output  wire														out_axis_valid,
	output  wire	[HEAD_WIDTH - 1 : 0]		                        out_axis_head,
	output  wire	[DATA_WIDTH - 1 : 0]						        out_axis_data,
	output  wire 														out_axis_start,
	output  wire														out_axis_last,
	input   wire  														out_axis_ready
);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg 							last_sch;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/


/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/


/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg 			[2:0]				arbit_cur_state;
reg 			[2:0]				arbit_next_state;

parameter 		[2:0]				ARBIT_IDLE_s 	= 3'd1,
									ARBIT_CHNL_A_s 	= 3'd2,
									ARBIT_CHNL_B_s 	= 3'd3;

always @(posedge clk or posedge rst) begin
	if(rst) begin
		arbit_cur_state <= ARBIT_IDLE_s;
	end
	else begin
		arbit_cur_state <= arbit_next_state;
	end
end

always @(*) begin
	case(ARBIT_IDLE_s)
		ARBIT_IDLE_s:		if(last_sch == `CHANNEL_B) begin
								if(in_axis_valid_a) begin
									arbit_next_state = ARBIT_CHNL_A_s;	
								end
								else if(in_axis_valid_b) begin
									arbit_next_state = ARBIT_CHNL_B_s;
								end
								else begin
									arbit_next_state = ARBIT_IDLE_s;
								end
							end
							else if(last_sch == `CHANNEL_A) begin
								if(in_axis_valid_b) begin
									arbit_next_state = ARBIT_CHNL_B_s;	
								end
								else if(in_axis_valid_a) begin
									arbit_next_state = ARBIT_CHNL_A_s;
								end
								else begin
									arbit_next_state = ARBIT_IDLE_s;
								end		
							end
							else begin
								arbit_next_state = ARBIT_IDLE_s;
							end
		ARBIT_CHNL_A_s:		if(in_axis_last_a && out_axis_ready) begin
								if(in_axis_valid_b) begin
									arbit_next_state = ARBIT_CHNL_B_s;
								end
								else begin
									arbit_next_state = ARBIT_IDLE_s;
								end
							end
							else begin
								arbit_next_state = ARBIT_IDLE_s;
							end
		ARBIT_CHNL_B_s:		if(in_axis_last_b && out_axis_ready) begin
								if(in_axis_valid_a) begin
									arbit_next_state = ARBIT_CHNL_A_s;
								end
								else begin
									arbit_next_state = ARBIT_IDLE_s;
								end
							end
							else begin
								arbit_next_state = ARBIT_IDLE_s;
							end
		default:			arbit_next_state = ARBIT_IDLE_s;
	endcase
end

/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- last_sch -- 
always @(posedge clk or posedge rst) begin
	if(rst) begin
		last_sch <= 'd0;
	end
	else if(arbit_cur_state == ARBIT_CHNL_A_s && arbit_next_state != ARBIT_CHNL_A_s) begin
		last_sch <= `CHANNEL_A;
	end
	else if(arbit_cur_state == ARBIT_CHNL_B_s && arbit_next_state != ARBIT_CHNL_B_s) begin
		last_sch <= `CHANNEL_B;
	end
	else begin
		last_sch <= last_sch;
	end
end

//out_axis_valid --
//out_axis_head --
//out_axis_data --
//out_axis_start --
//out_axis_last --
assign out_axis_valid = (arbit_cur_state == ARBIT_CHNL_A_s) ? in_axis_valid_a : 
						(arbit_cur_state == ARBIT_CHNL_B_s) ? in_axis_valid_b : 'd0;
assign out_axis_head = (arbit_cur_state == ARBIT_CHNL_A_s) ? in_axis_head_a : 
						(arbit_cur_state == ARBIT_CHNL_B_s) ? in_axis_head_b : 'd0;
assign out_axis_data = (arbit_cur_state == ARBIT_CHNL_A_s) ? in_axis_data_a : 
						(arbit_cur_state == ARBIT_CHNL_B_s) ? in_axis_data_b : 'd0;
assign out_axis_start = (arbit_cur_state == ARBIT_CHNL_A_s) ? in_axis_start_a : 
						(arbit_cur_state == ARBIT_CHNL_B_s) ? in_axis_start_b : 'd0;
assign out_axis_last = (arbit_cur_state == ARBIT_CHNL_A_s) ? in_axis_last_a : 
						(arbit_cur_state == ARBIT_CHNL_B_s) ? in_axis_last_b : 'd0;

//-- in_axis_ready_a --
assign in_axis_ready_a = (arbit_cur_state == ARBIT_CHNL_A_s) ? out_axis_ready : 'd0;

//-- in_axis_ready_b --
assign in_axis_ready_b = (arbit_cur_state == ARBIT_CHNL_B_s) ? out_axis_ready : 'd0;

/*------------------------------------------- Variables Decode : End ------------------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`undef 	CHANNEL_A
`undef 	CHANNEL_B            
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

endmodule