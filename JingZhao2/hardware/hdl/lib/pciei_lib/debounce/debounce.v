module debounce #(
    parameter DEBOUNCE_CYCLES = 10, // number of debounce cycles, minimum allowed value is 2
    parameter ACTIVE_STATE    = 0   // active state for sig_in
)
(
    input                   clk,

    input                   sig_in,
    output                  sig_out
);

wire                        sig_in_sync;
reg  [DEBOUNCE_CYCLES-1:0]  deb_sig;

generate if (ACTIVE_STATE) begin: GEN_DEBOUNCE_HIGH
    assign sig_out = &{deb_sig, sig_in_sync};
end
else begin: GEN_DEBOUNCE_LOW
    assign sig_out = |{deb_sig, sig_in_sync};
end
endgenerate

always @(posedge clk)
begin
    deb_sig <= `TD {deb_sig[DEBOUNCE_CYCLES-2:0], sig_in_sync};
end

cdc_syncff #(
    .DATA_WIDTH     (1              ),
    .RST_VALUE      (0              ),
    .SYNC_LEVELS    (2              )
) u_cdc_syncff (
    .data_d         (sig_in_sync    ),
    .data_s         (sig_in         ),
    .clk_d          (clk            ),
    .rstn_d         (1'b1           )
);

endmodule
