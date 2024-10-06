`timescale 1ns / 1ps
`include "chip_include_rdma.vh"

module WQEIndicatorTable
#(
  parameter RW_REG_NUM = 1
)
( //"wit" for short
    input   wire                clk,
    input   wire                rst,

	input 	wire 	[RW_REG_NUM * 32 - 1 : 0]	rw_data,
	output 	wire 	[RW_REG_NUM * 32 - 1 : 0]	init_rw_data,

    input   wire                wr_en,
    input   wire    [13:0]      wr_addr,
    input   wire    [0:0]       wr_data,

    input   wire    [13:0]      rd_addr,
    output  wire    [0:0]       rd_data
);

//TODO - Need to be initialized
reg 					init_wea;
reg 		[13:0]		init_addr;
reg 		[13:0]		init_counter;

always @(posedge clk or posedge rst) begin
	if(rst) begin
		init_wea <= 'd0;
		init_addr <= 'd0;
		init_counter <= 'd0;
	end 
	else if(init_counter < `QP_NUM) begin
		init_wea <= 'd1;
		init_addr <= init_counter;
		init_counter <= init_counter + 1;
	end 
	else begin
		init_wea <= 'd0;
		init_addr <= init_addr;
		init_counter <= init_counter;
	end 
end 



//Depth chanfed to 8192
BRAM_SDP_1w_16384d WIT (
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[0 * 32 + 1 : 0 * 32 + 0]),
	.WTSEL( rw_data[0 * 32 + 3 : 0 * 32 + 2]),
	.PTSEL( rw_data[0 * 32 + 5 : 0 * 32 + 4]),
	.VG(    rw_data[0 * 32 + 6 : 0 * 32 + 6]),
	.VS(    rw_data[0 * 32 + 7 : 0 * 32 + 7]),

  `endif

  .clka(clk),    // input wire clka
  .ena(1'b1),      // input wire ena
  .wea(init_counter < `QP_NUM ? init_wea : wr_en),      // input wire [0 : 0] wea
  .addra(init_counter < `QP_NUM ? init_addr[12:0] : wr_addr[12:0]),  // input wire [13 : 0] addra
  .dina(init_counter < `QP_NUM ? 1'b0 : wr_data),    // input wire [0 : 0] dina
  .clkb(clk),    // input wire clkb
  .enb(1'b1),      // input wire enb
  .addrb(rd_addr[12:0]),  // input wire [13 : 0] addrb
  .doutb(rd_data)  // output wire [0 : 0] doutb
);

assign init_rw_data = 'd0;

endmodule
