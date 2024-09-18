module cell_clk_gate (
    input       TE,
    input       E,
    input       CK,
    output      ECK
);

`ifdef FPGA_VERSION

assign ECK = CK;

`else

wire clk_en_test;
reg  clk_en_lat;

assign clk_en_test = E | TE;

always @(CK or clk_en_test)
begin
    if (~CK) begin
        clk_en_lat <= clk_en_test;
    end
end

assign ECK = CK & clk_en_lat;

`endif

endmodule
