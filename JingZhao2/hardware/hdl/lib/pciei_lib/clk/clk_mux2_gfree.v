// 2-input glitch-free clock mux

module clk_mux2_gfree #(
    parameter   DEF_OUT_CLK_0 = 0   // default output clk_0
)
(
    input       clk_0,
    input       rst_n_0,
    input       clk_1,
    input       rst_n_1,
    input       clk_sel,
    output      clk_out
);

wire        clk_en_0;
wire        clk_en_1;

reg  [3:0]  clk_en_0_sync;
reg  [3:0]  clk_en_1_sync;

wire        gate_en_0;
wire        gate_en_1;

wire        clk_0_gated;
wire        clk_1_gated;

assign clk_en_0 = (clk_sel == 1'b0) & (~|clk_en_1_sync);
assign clk_en_1 = (clk_sel == 1'b1) & (~|clk_en_0_sync);

assign gate_en_0 = &clk_en_0_sync[3:1];
assign gate_en_1 = &clk_en_1_sync[3:1];

always @(posedge clk_0 or negedge rst_n_0)
begin
    if (~rst_n_0) begin
        clk_en_0_sync <= `TD DEF_OUT_CLK_0 ? 4'b1111 : 4'b0;
    end
    else begin
        clk_en_0_sync <= `TD {clk_en_0_sync[2:0], clk_en_0};
    end
end

always @(posedge clk_1 or negedge rst_n_1)
begin
    if (~rst_n_1) begin
        clk_en_1_sync <= `TD 4'b0;
    end
    else begin
        clk_en_1_sync <= `TD {clk_en_1_sync[2:0], clk_en_1};
    end
end

cell_clk_gate u_cell_clk_gate_0 (
    .TE         (1'b0               ),
    .CK         (clk_0              ),
    .E          (gate_en_0          ),
    .ECK        (clk_0_gated        )
);

cell_clk_gate u_cell_clk_gate_1 (
    .TE         (1'b0               ),
    .CK         (clk_1              ),
    .E          (gate_en_1          ),
    .ECK        (clk_1_gated        )
);

cell_clk_or2 u_clk_or2 (
    .A          (clk_0_gated        ),
    .B          (clk_1_gated        ),
    .Y          (clk_out            )
); 

endmodule
