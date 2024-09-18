`timescale 1ns / 100ps
module cdc_syncff(
    // Outputs
    data_d,
    // Inputs
    data_s,
    clk_d,
    rstn_d
    );

    parameter DATA_WIDTH  = 1;
    parameter RST_VALUE   = 0;
    parameter SYNC_LEVELS = 2;        // number of sync levels: 2 or 3

    input [DATA_WIDTH-1:0]  data_s;   // data vector in source domain, to be synced
    input                   clk_d;    // clock in destination domain
    input                   rstn_d;   // async reset in destination domain, active low
    output [DATA_WIDTH-1:0] data_d;   // data vector in destination domain

    genvar                  i;

    // ------------------------------------------------------------------------------- //
    // This module offers a basic solution to safely transfer signal from source clock 
    // domain to destination clock domain, which consists of 2/3 stage flip-flops that 
    // eliminate the unexpected mete-stability during clock domain crossing
    // ------------------------------------------------------------------------------- //

    generate
        for (i=0; i<DATA_WIDTH; i=i+1) begin: sync_bit
            if (RST_VALUE == 0) begin: reset_0
                if (SYNC_LEVELS == 2) begin: sync2ff
                    cell_sync2ffr u_cell_sync2ffr (
                        .CK     (clk_d      ),
                        .D      (data_s[i]  ),
                        .R      (~rstn_d    ),
                        .Q      (data_d[i]  )
                    );
                end
                else if (SYNC_LEVELS == 3) begin: sync3ff
                    cell_sync3ffr u_cell_sync3ffr (
                        .CK     (clk_d      ),
                        .D      (data_s[i]  ),
                        .R      (~rstn_d    ),
                        .Q      (data_d[i]  )
                    );
                end
            end
            else begin: set_1
                if (SYNC_LEVELS == 2) begin: sync2ff
                    cell_sync2ffs u_cell_sync2ffs (
                        .CK     (clk_d      ),
                        .D      (data_s[i]  ),
                        .SN     (rstn_d     ),
                        .Q      (data_d[i]  )
                    );
                end
                else if (SYNC_LEVELS == 3) begin: sync3ff
                    cell_sync3ffs u_cell_sync3ffs (
                        .CK     (clk_d      ),
                        .D      (data_s[i]  ),
                        .SN     (rstn_d     ),
                        .Q      (data_d[i]  )
                    );
                end
            end
        end
    endgenerate

endmodule
