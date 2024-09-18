module reset_sync(
    // Outputs
    rstn_d,
    // Inputs
    rstn_s,
    clk_d
    );

    parameter SYNC_MODE = 0;    // 0 -- rstn_d is asynchrously asserted
                                // 1 -- rstn_d is synchrously asserted

    input  rstn_s;   // async reset in source domain, active low, to be synced
    input  clk_d;    // clock in destination domain
    output rstn_d;   // async reset in destination domain, active low

    wire   rstn_s_ngf;

    // filter negative glitches
    //cell_ngf_buf u_cell_ngf_buf (
    //    .A      (rstn_s     ),
    //    .Y      (rstn_s_ngf )
    //);
    assign rstn_s_ngf = rstn_s;

    // ------------------------------------------------------------------------------- //
    // This module offers solution to safely transfer asynchronous reset signal from 
    // source clock domain to destination clock domain, which consists of 2 stage 
    // flip-flops and is useful to avoid removal/recovery timing violation
    // ------------------------------------------------------------------------------- //

    generate
        if (SYNC_MODE) begin: sync_reset

            cdc_syncff #(
                .DATA_WIDTH (1          ),
                .RST_VALUE  (0          ),
                .SYNC_LEVELS(2          )
            ) u_cdc_syncff (
                .data_d     (rstn_d     ),
                .data_s     (rstn_s_ngf ),
                .clk_d      (clk_d      ),
                .rstn_d     (1'b1       )
            );

        end
        else begin: async_reset

            cdc_syncff #(
                .DATA_WIDTH (1          ),
                .RST_VALUE  (0          ),
                .SYNC_LEVELS(2          )
            ) u_cdc_syncff (
                .data_d     (rstn_d     ),
                .data_s     (1'b1       ),
                .clk_d      (clk_d      ),
                .rstn_d     (rstn_s_ngf )
            );

        end
    endgenerate

endmodule
