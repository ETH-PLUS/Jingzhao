// DFF with reset input

module cell_dffr (
    input   CK,
    input   D,
    input   R,      // active HIGH reset
    output  Q
);

reg q_reg;

assign Q = q_reg;

always @(posedge CK or posedge R)
begin
    if (R) begin
        q_reg <= 1'b0;
    end
    else begin
        q_reg <= D;
    end
end

endmodule
