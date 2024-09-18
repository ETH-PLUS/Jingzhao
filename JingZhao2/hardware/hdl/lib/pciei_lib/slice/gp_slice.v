// general purpose slice

module gp_slice #(
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

wire                        rst_n_sync;

generate
    if (SYNC_RESET) begin: reset_sync

        reset_sync #(
            .SYNC_MODE      (1                  )
        ) u_reset_sync (
            .rstn_d         (rst_n_sync         ),
            .rstn_s         (rst_n              ),
            .clk_d          (clk                )
        );

    end
    else begin: reset_no_sync

        assign rst_n_sync = rst_n;

    end
endgenerate

generate if (MODE == 0) begin: FUL_MODE

    reg  [PAYLD_WIDTH-1:0]  slice_a;
    reg                     valid_a;
    reg  [PAYLD_WIDTH-1:0]  slice_b;
    reg                     valid_b;
    reg                     sel_b;

    assign rdy_m   = (~valid_a) | (~valid_b);

    assign vld_s   = valid_a | valid_b;
    assign payld_s = sel_b ? slice_b : slice_a;

    always @(posedge clk or negedge rst_n_sync)
    begin
        if (!rst_n_sync) begin
            sel_b <= `TD 1'b0;
        end
        else if (vld_s & rdy_s) begin
            sel_b <= `TD ~sel_b;
        end
    end

    always @(posedge clk or negedge rst_n_sync)
    begin
        if (!rst_n_sync) begin
            slice_a <= `TD {PAYLD_WIDTH{1'b0}};
            valid_a <= `TD 1'b0;
        end
        else if ((~valid_a) & (valid_b | (~sel_b)) & vld_m) begin
            slice_a <= `TD payld_m;
            valid_a <= `TD 1'b1;
        end
        else if (valid_a & (~sel_b) & rdy_s) begin
            valid_a <= `TD 1'b0;
        end
    end

    always @(posedge clk or negedge rst_n_sync)
    begin
        if (!rst_n_sync) begin
            slice_b <= `TD {PAYLD_WIDTH{1'b0}};
            valid_b <= `TD 1'b0;
        end
        else if ((~valid_b) & (valid_a | sel_b) & vld_m) begin
            slice_b <= `TD payld_m;
            valid_b <= `TD 1'b1;
        end
        else if (valid_b & sel_b & rdy_s) begin
            valid_b <= `TD 1'b0;
        end
    end

end
else if (MODE == 1) begin: FWD_MODE

    reg  [PAYLD_WIDTH-1:0]  slice;
    reg                     valid;

    assign rdy_m   = ~valid | rdy_s;

    assign vld_s   = valid;
    assign payld_s = slice;

    always @(posedge clk or negedge rst_n_sync)
    begin
        if (!rst_n_sync) begin
            slice <= `TD {PAYLD_WIDTH{1'b0}};
            valid <= `TD 1'b0;
        end
        else if (vld_m & rdy_m) begin
            slice <= `TD payld_m;
            valid <= `TD 1'b1;
        end
        else if (vld_s & rdy_s) begin
            valid <= `TD 1'b0;
        end
    end

end
else if (MODE == 2) begin: REV_MODE

    reg  [PAYLD_WIDTH-1:0]  slice;
    reg                     valid;

    assign rdy_m   = ~valid;

    assign vld_s   = valid | vld_m;
    assign payld_s = valid ? slice : payld_m;

    always @(posedge clk or negedge rst_n_sync)
    begin
        if (!rst_n_sync) begin
            slice <= `TD {PAYLD_WIDTH{1'b0}};
            valid <= `TD 1'b0;
        end
        else if (vld_m & rdy_m & (~rdy_s)) begin
            slice <= `TD payld_m;
            valid <= `TD 1'b1;
        end
        else if (valid & rdy_s) begin
            valid <= `TD 1'b0;
        end
    end

end
else begin: BYP_MODE

    assign rdy_m   = rdy_s;

    assign vld_s   = vld_m;
    assign payld_s = payld_m;

end
endgenerate

endmodule
