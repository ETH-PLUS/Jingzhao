`timescale 1ns / 100ps
module pcieifc_async_fifo_prot #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 5 ,
    parameter FIFO_DEPTH = 32 
) (
    // clock and reset
    input  wire                   wclk  , // write clock
    input  wire                   rclk  , // read clock
    input  wire                   wrst_n, // async reset in write domain, active low
    input  wire                   rrst_n, // async reset in read domain, active low

    // interface with function logic 
    input  wire                   wclr       , // sync reset, active high
    input  wire                   winc       , // fifo write request
    input  wire [DATA_WIDTH-1:0]  wdata      , // write data
    output wire                   wfull      , // register out, write fifo full flag
    output wire                   wempty     , // register out, write fifo empty flag
    output wire [ADDR_WIDTH:0]    wptr_bin   , // binary pointer in write domain
    output wire [ADDR_WIDTH:0]    ptr_bin_r2w, // binary pointer synced from read domain 
    
    input  wire                   rclr       , // sync reset, active high
    input  wire                   rinc       , // fifo read request
    output wire [DATA_WIDTH-1:0]  rdata      , // read data
    output wire                   rfull      , // register out, read fifo full flag
    output wire                   rempty     , // register out, read fifo empty flag
    output wire [ADDR_WIDTH:0]    rptr_bin   , // binary pointer in read domain
    output wire [ADDR_WIDTH:0]    ptr_bin_w2r, // binary pointer synced from write domain 
    
    // interface with FIFO memory
    output wire [ADDR_WIDTH-1:0]  waddr,        // write fifo address pointer
    output wire                   wcen ,        // write fifo chip enable
    output wire [DATA_WIDTH-1:0]  wdin ,        // write fifo data input    

    input  wire [DATA_WIDTH-1:0]  rdout,         // read fifo data output
    output wire [ADDR_WIDTH-1:0]  raddr,         // read fifo address pointer
    output wire                   rcen           // read fifo chip enable
);

localparam CLAMP_RDATA = 1;

wire [ADDR_WIDTH:0]      ptr_gray_w2r;  // gray pointer synced from write domain
wire [ADDR_WIDTH:0]      ptr_gray_r2w;  // gray pointer synced from read domain
wire [ADDR_WIDTH:0]      wptr_gray;     // gray pointer in write domain
wire [ADDR_WIDTH:0]      rptr_gray;     // gray pointer in read domain
    
// ------------------------------------------------------------------------------- 
    
assign wdin  = wdata;

genvar k;
generate
if (CLAMP_RDATA) begin: clamp
    
    for (k=0; k<DATA_WIDTH; k=k+1) begin: clamp_bit
        cell_and2 u_cell_and2_rdata_clamp (
            .A      (~rempty    ),
            .B      (rdout[k]   ),
            .Y      (rdata[k]   )
        );
    end

end
else begin: non_clamp

    assign rdata = rdout;

end
endgenerate

cdc_syncff #(
    ADDR_WIDTH+1, 
    0, 
    2
) u_ptr_sync_w2r (
    // Inputs
    .data_s(wptr_gray), 
    .clk_d(rclk),
    .rstn_d(rrst_n),
    // Output
    .data_d(ptr_gray_w2r)
);


cdc_syncff #(
    ADDR_WIDTH+1, 
    0, 
    2
) u_ptr_sync_r2w (
    // Inputs
    .data_s(rptr_gray), 
    .clk_d(wclk),
    .rstn_d(wrst_n),
    // Output
    .data_d(ptr_gray_r2w)
);


pcieifc_fifo_ctrl_prot #(
    .ADDR_WIDTH   ( ADDR_WIDTH ), 
    .FIFO_DEPTH   ( FIFO_DEPTH )
) u_wr_fifo_ctrl (
    // Outputs
    .fifo_cen       ( wcen        ),
    .fifo_addr      ( waddr       ),
    .fifo_full      ( wfull       ),
    .fifo_empty     ( wempty      ),
    .ptr_bin        ( wptr_bin    ),
    .ptr_gray       ( wptr_gray   ),
    .ptr_bin_other  ( ptr_bin_r2w ),
    // Inputs
    .fifo_clk       ( wclk),
    .fifo_rstn      ( wrst_n),
    .fifo_clear     ( wclr),
    .fifo_inc       ( winc),
    .fifo_dir       ( 1'b1),
    .ptr_gray_other ( ptr_gray_r2w)
);

pcieifc_fifo_ctrl_prot #(
    .ADDR_WIDTH   ( ADDR_WIDTH ), 
    .FIFO_DEPTH   ( FIFO_DEPTH )
) u_rd_fifo_ctrl (
    // Outputs
    .fifo_cen       ( rcen        ),
    .fifo_addr      ( raddr       ),
    .fifo_full      ( rfull       ),
    .fifo_empty     ( rempty      ),
    .ptr_bin        ( rptr_bin    ),
    .ptr_gray       ( rptr_gray   ),
    .ptr_bin_other  ( ptr_bin_w2r ),
    // Inputs
    .fifo_clk       ( rclk         ),
    .fifo_rstn      ( rrst_n       ),
    .fifo_clear     ( rclr         ),
    .fifo_inc       ( rinc         ),
    .fifo_dir       ( 1'b0         ),
    .ptr_gray_other ( ptr_gray_w2r ) 
);
    
endmodule // pcieifc_async_fifo
