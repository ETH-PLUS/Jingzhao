module sram_model #(
    parameter DATA_WIDTH  = 128,
    parameter ADDR_WIDTH  = 7
)
(
    input                       clk,
    input                       sram_cen,
    input                       sram_wen,
    input  [ADDR_WIDTH-1:0]     sram_a,
    input  [DATA_WIDTH-1:0]     sram_d,
    output reg [DATA_WIDTH-1:0] sram_q
);

reg  [DATA_WIDTH-1:0]   ram_array[0:(1<<ADDR_WIDTH)-1];

always @(posedge clk)
begin
    if (~sram_cen) begin
        if (sram_wen) begin
            sram_q <= `TD ram_array[sram_a];
        end
        else begin
            ram_array[sram_a] <= `TD sram_d;
        end
    end
end

`ifdef FPGA_VERSION

endmodule

`else

// synopsys translate_off
// This module is not intended for synthesis, so a syntax error is present during synthesis

endmodule

// synopsys translate_on

`endif
