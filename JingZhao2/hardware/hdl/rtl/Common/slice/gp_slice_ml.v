// multi-level general purpose slice

module gp_slice_ml #(
    parameter NUM_LEVELS    = 1,
    parameter PAYLD_WIDTH   = 32'd32,
    parameter MODE          = 0, // slice mode: 0 -- full, 1 -- forward, 2 -- reverse, 3 -- bypass
    parameter SYNC_RESET    = 0
)
(
    input                       clk,
    input                       rst_n,

    input                       vld_m,
    output                      rdy_m,
    input  [PAYLD_WIDTH-1:0]    payld_m,
    output                      vld_s,
    input                       rdy_s,
    output [PAYLD_WIDTH-1:0]    payld_s
);

wire                    vld[NUM_LEVELS:0];
wire                    rdy[NUM_LEVELS:0];
wire [PAYLD_WIDTH-1:0]  payld[NUM_LEVELS:0];

genvar                  i;

assign vld[0]   = vld_m;
assign rdy_m    = rdy[0];
assign payld[0] = payld_m;

assign vld_s           = vld[NUM_LEVELS];
assign rdy[NUM_LEVELS] = rdy_s;
assign payld_s         = payld[NUM_LEVELS];

generate for (i=0; i<NUM_LEVELS; i=i+1) begin: slice

    gp_slice #(
        .PAYLD_WIDTH    (PAYLD_WIDTH    ),
        .MODE           (MODE           ),
        .SYNC_RESET     (SYNC_RESET     )
    ) u_gp_slice (
        .clk            (clk            ),
        .rst_n          (rst_n          ),
        .vld_m          (vld[i]         ),
        .rdy_m          (rdy[i]         ),
        .payld_m        (payld[i]       ),
        .vld_s          (vld[i+1]       ),
        .rdy_s          (rdy[i+1]       ),
        .payld_s        (payld[i+1]     )
    );

end
endgenerate

endmodule
