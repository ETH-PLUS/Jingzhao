`timescale 1ns / 100ps
module cell_clk_and2 (
    input   A,
    input   B,
    output  Y
);

assign Y = A & B;

endmodule