module cell_clk_mux2 (
    input   A,
    input   B,
    input   S,
    output  Y
);

assign Y = S ? B : A;

endmodule
