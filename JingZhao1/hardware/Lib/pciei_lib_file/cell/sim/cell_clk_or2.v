module cell_clk_or2 (
    input   A,
    input   B,
    output  Y
);

assign Y = A | B;

endmodule
