module add_dff(
    // Outputs
    data_d,
    // Inputs
    data_s,
    clk_d,
    rstn_d
    );

    parameter DATA_WIDTH  = 1;

    input [DATA_WIDTH-1:0]  data_s;   // data vector in source domain, to be synced
    input                   clk_d;    // clock in destination domain
    input                   rstn_d;   // async reset in destination domain, active low
    output [DATA_WIDTH-1:0] data_d;   // data vector in destination domain

genvar i;
    generate
        for (i=0; i<DATA_WIDTH; i=i+1) begin: sync_bit
           cell_dffr  u_cell_dffr (
              .CK     (clk_d      ),
              .D      (data_s[i]  ),
              .R      (~rstn_d    ),
              .Q      (data_d[i]  )
              );
         end
    endgenerate
endmodule
