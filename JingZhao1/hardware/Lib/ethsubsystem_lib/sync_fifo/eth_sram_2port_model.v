`timescale 1ns / 100ps

module eth_sram_2port_model #(
    parameter DATA_WIDTH  = 88,
    parameter ADDR_WIDTH  = 10,
    parameter FIFO_DEPTH = 1024
)
(
    input                           clk,
    input                           sram_wr_cen,
    input [ADDR_WIDTH-1:0]          sram_wr_a,
    input [DATA_WIDTH-1:0]          sram_wr_d,

    input                           sram_rd_cen,
    input [ADDR_WIDTH-1:0]          sram_rd_a,
    output reg [DATA_WIDTH-1:0]     sram_rd_q
);

reg  [DATA_WIDTH-1:0]   ram_array[0:FIFO_DEPTH-1];

always @(posedge clk)
begin
        if (~sram_wr_cen) begin
            ram_array[sram_wr_a] <= `TD sram_wr_d;
        end
end

always @(posedge clk)
begin
        if (~sram_rd_cen) begin
            sram_rd_q <= `TD ram_array[sram_rd_a] ;
        end
end


endmodule