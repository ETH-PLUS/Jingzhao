module SRAM_SDP_Model #(
    parameter DATA_WIDTH  = 88,
    parameter ADDR_WIDTH  = 10,
    parameter RAM_DEPTH = 1024
)
(
    input                           clk,
	input 							rst,
    input                           sram_wr_cen,
    input [ADDR_WIDTH-1:0]          sram_wr_a,
    input [DATA_WIDTH-1:0]          sram_wr_d,

    input                           sram_rd_cen,
    input [ADDR_WIDTH-1:0]          sram_rd_a,
    output reg [DATA_WIDTH-1:0]     sram_rd_q
);

reg  [DATA_WIDTH-1:0]   ram_array[0:RAM_DEPTH-1];

integer i;

always @(posedge clk or posedge rst)
begin
		if(rst) begin
			for(i = 0; i < RAM_DEPTH; i = i + 1) begin : SRAM_INIT
				ram_array[i] <= {DATA_WIDTH{1'b0}};
			end 			
		end 
        else if (~sram_wr_cen) begin
            ram_array[sram_wr_a] <= `TD sram_wr_d;
        end 
		else begin
			ram_array[sram_wr_a] <= ram_array[sram_wr_a];
		end 
end

always @(posedge clk or posedge rst)
begin
		if(rst) begin
			sram_rd_q <= 'd0;
		end 
        else if (~sram_rd_cen) begin
            sram_rd_q <= `TD ram_array[sram_rd_a] ;
        end
		else begin
			sram_rd_q <= sram_rd_q;
		end 
end


endmodule
