`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/10/29 09:51:03
// Design Name: 
// Module Name: WriteAddrTable
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
module WriteAddrTable
#(
    parameter RW_REG_NUM = 1
)
(  //"wat" for short
    input   wire                clk,
    input   wire                rst,

	input 	wire 	[RW_REG_NUM * 32 - 1 : 0]	rw_data,
	output 	wire 	[RW_REG_NUM * 32 - 1 : 0]	init_rw_data,

    input   wire                i_wat_wr_en,
    input   wire    [127:0]     iv_wat_wr_data,
    input   wire    [13:0]      iv_wat_addra,
    input   wire    [13:0]      iv_wat_addrb,
    output  wire    [127:0]     ov_wat_rd_data
);

reg 	q_wat_redundant;
always @(posedge clk or posedge rst) begin
	if(rst) begin
 		q_wat_redundant <= 'd0;
	end
	else begin
		q_wat_redundant <= q_wat_redundant;
	end 
end 

//Handle read-write collision although it may not happen
wire        [127:0]         wv_table_doutb;
assign  ov_wat_rd_data = (iv_wat_addra == iv_wat_addrb && i_wat_wr_en) ? wv_table_doutb : iv_wat_wr_data; 

BRAM_SDP_128w_16384d WAT(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[0 * 32 + 1 : 0 * 32 + 0]),
	.WTSEL( rw_data[0 * 32 + 3 : 0 * 32 + 2]),
	.PTSEL( rw_data[0 * 32 + 5 : 0 * 32 + 4]),
	.VG(    rw_data[0 * 32 + 6 : 0 * 32 + 6]),
	.VS(    rw_data[0 * 32 + 7 : 0 * 32 + 7]),

  `endif

  .clka(clk),    // input wire clka
  .ena(1'b1),      // input wire ena
  .wea(i_wat_wr_en),      // input wire [0 : 0] wea
  .addra(iv_wat_addra),  // input wire [13 : 0] addra
  .dina(iv_wat_wr_data),    // input wire [127 : 0] dina
  .clkb(clk),    // input wire clkb
  .enb(1'b1),      // input wire enb
  .addrb(iv_wat_addrb),  // input wire [13 : 0] addrb
  .doutb(wv_table_doutb)  // output wire [127 : 0] doutb
);

assign init_rw_data = 'd0;

endmodule
