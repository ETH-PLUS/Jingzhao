module cell_clk_and3 (
    input   A,
    input   B,
    input   C,
    output  Y
);

assign Y = A & B & C;

endmodule
