`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/02/24 15:09:44
// Design Name: 
// Module Name: AXIStoFIFOTrans
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "chip_include_rdma.vh"

module AXIStoFIFOTrans(
	input 	wire 				clk,
	input 	wire 				rst,

	input 		wire 								i_hpc_prog_full,
	output 		wire 								o_hpc_wr_en,
	output 		wire 		[255:0]					ov_hpc_data,

	input     wire                                 	i_hpc_rx_valid, 
	input     wire                                 	i_hpc_rx_last,
	input     wire			[255:0]            		iv_hpc_rx_data,
	input     wire			[4:0]            		iv_hpc_rx_keep,
	output    wire                                 	o_hpc_rx_ready,	
	//Additional signals
	input 	  wire 									i_hpc_rx_start,
	input 	  wire 			[6:0]					iv_hpc_rx_user
);

assign o_hpc_wr_en = !i_hpc_prog_full && i_hpc_rx_valid;
assign ov_hpc_data = iv_hpc_rx_data;
assign o_hpc_rx_ready = !i_hpc_prog_full;

endmodule
