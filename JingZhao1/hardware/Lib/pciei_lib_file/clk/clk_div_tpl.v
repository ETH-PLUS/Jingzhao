module clk_div_tpl(
ckd_en,
ckd_cyc_h,
ckd_cyc_l,

src_clk,
src_reset_n,

cph_ind,
dst_clk
);

parameter CYC_WIDTH     = 4;
parameter EN_RST_VALUE  = 1'b0;
parameter CLK_INI_LEVEL = 1'b0;

// port declarations
input ckd_en;
input [CYC_WIDTH-1 : 0] ckd_cyc_h;
input [CYC_WIDTH-1 : 0] ckd_cyc_l;

input src_clk;
input src_reset_n;

output cph_ind; // clock phase relationship indicator
output dst_clk;

// signals declaration
wire ckd_enff;

reg [CYC_WIDTH-1 : 0] cnt;
wire d_clk;
wire d_clk_nxt;
wire d_clk_rep;
wire cph_ind;

// main code

cdc_syncff #(
    .DATA_WIDTH (1),
    .RST_VALUE  (EN_RST_VALUE),
    .SYNC_LEVELS(2)
)
u_en_sync(
    .data_d        (ckd_enff        ),
    .data_s        (ckd_en          ),
    .clk_d         (src_clk         ),
    .rstn_d        (src_reset_n     )
);

always @(posedge src_clk or negedge src_reset_n)
  if (!src_reset_n)
    cnt <= `TD {CYC_WIDTH{1'b0}};
  else if (!ckd_enff)
    cnt <= `TD {CYC_WIDTH{1'b0}};
  else if (((cnt==ckd_cyc_h) && (d_clk_rep==1)) || ((cnt==ckd_cyc_l) && (d_clk_rep==0)))
    cnt <= `TD {CYC_WIDTH{1'b0}};
  else 
    cnt <= `TD cnt + 1;

assign d_clk_nxt = (!ckd_enff) ? CLK_INI_LEVEL : ((cnt==ckd_cyc_l) && (d_clk_rep==0)) ? 1'b1 : ((cnt==ckd_cyc_h) && (d_clk_rep==1)) ? 1'b0 : d_clk_rep;

dff_wrap #(
    .RST_VAL    (CLK_INI_LEVEL  )
) u_dff_wrap_d_clk (
    .clk        (src_clk        ),
    .rst_n      (src_reset_n    ),
    .d          (d_clk_nxt      ),
    .q          (d_clk          )
);

dff_wrap #(
    .RST_VAL    (CLK_INI_LEVEL  )
) u_dff_wrap_d_clk_rep (
    .clk        (src_clk        ),
    .rst_n      (src_reset_n    ),
    .d          (d_clk_nxt      ),
    .q          (d_clk_rep      )
);

cell_clk_buf u_clkcell_d_buf (.A(d_clk), .Y(dst_clk));

assign cph_ind = (cnt==ckd_cyc_l) && (d_clk_rep==0);

endmodule
