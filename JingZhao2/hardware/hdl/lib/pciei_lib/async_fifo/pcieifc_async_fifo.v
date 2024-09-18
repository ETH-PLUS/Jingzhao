`timescale 1ns / 100ps
module pcieifc_async_fifo #(
    parameter DATA_WIDTH  = 192,
    parameter ADDR_WIDTH  = 3
) (
    input                   wr_clk,
    input                   rd_clk,
    input                   wrst_n,
    input                   rrst_n,

    input                   wen,
    input  [DATA_WIDTH-1:0] din,
    output                  full,

    input                   ren,
    output [DATA_WIDTH-1:0] dout,
    output                  empty

`ifdef PCIEI_APB_DBG
    ,input wire  [1:0]  rtsel
    ,input wire  [1:0]  wtsel
    ,input wire  [1:0]  ptsel
    ,input wire         vg   
    ,input wire         vs   
`endif
);

wire                  st_wen  ;
wire                  st_ren  ;
wire [DATA_WIDTH-1:0] st_din  ;
wire [DATA_WIDTH-1:0] st_dout ;
wire                  st_full ;
wire                  st_empty;

wire in_reg_ready;
wire fifo_reg_valid, fifo_reg_ready;
wire reg_out_valid;

/* --------Stream reg out for rd rsp{begin}-------- */
assign full = !in_reg_ready;
st_reg #(
    .TUSER_WIDTH ( 1          ), // unused
    .TDATA_WIDTH ( DATA_WIDTH )
) in_fifo_st_reg (
    .clk   ( wr_clk ), // i, 1
    .rst_n ( wrst_n ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( wen   ), // i, 1
    .axis_tlast  ( 1'b0  ), // i, 1
    .axis_tuser  ( 1'b0  ), // i, TUSER_WIDTH
    .axis_tdata  ( din   ), // i, TDATA_WIDTH
    .axis_tready ( in_reg_ready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output st_reg inteface{begin}------- */
    .axis_reg_tvalid ( st_wen   ), // o, 1  
    .axis_reg_tlast  (          ), // o, 1
    .axis_reg_tuser  (          ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( st_din   ), // o, TDATA_WIDTH
    .axis_reg_tready ( !st_full )  // i, 1
    /* -------output st_reg inteface{end}------- */
);
/* --------Stream reg out for rd rsp{end}-------- */

/* --------Async FIFO logic {begin}-------- */
pcieifc_async_fifo_2psram #(
    .DATA_WIDTH  ( DATA_WIDTH ),
    .ADDR_WIDTH  ( ADDR_WIDTH )
) pcieifc_async_fifo_2psram (
    .wr_clk ( wr_clk ),
    .rd_clk ( rd_clk ),
    .wrst_n ( wrst_n ),
    .rrst_n ( rrst_n ),

    .wr_en  ( st_wen  ), // i, 1
    .din    ( st_din  ), // i, DATA_WIDTH
    .full   ( st_full ), // o, 1

    .rd_en  ( st_ren   ), // i, 1
    .dout   ( st_dout  ), // o, DATA_WIDTH
    .empty  ( st_empty )  // o, 1

`ifdef PCIEI_APB_DBG
    ,.rtsel  ( rtsel )  // i, 2
    ,.wtsel  ( wtsel )  // i, 2
    ,.ptsel  ( ptsel )  // i, 2
    ,.vg     ( vg    )  // i, 1
    ,.vs     ( vs    )  // i, 1
`endif
);
/* --------Async FIFO logic {end}-------- */

/* --------Stream reg out fifo out{begin}-------- */
assign empty = !reg_out_valid;
assign fifo_reg_valid = !st_empty;
assign st_ren = fifo_reg_ready;
st_reg #(
    .TUSER_WIDTH ( 1          ), // unused
    .TDATA_WIDTH ( DATA_WIDTH ) 
) out_fifo_st_reg (
    .clk   ( rd_clk ), // i, 1
    .rst_n ( rrst_n ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( fifo_reg_valid ), // i, 1
    .axis_tlast  ( 1'b0           ), // i, 1
    .axis_tuser  ( 1'b0           ), // i, TUSER_WIDTH
    .axis_tdata  ( st_dout        ), // i, TDATA_WIDTH
    .axis_tready ( fifo_reg_ready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output st_reg inteface{begin}------- */
    .axis_reg_tvalid ( reg_out_valid ), // o, 1  
    .axis_reg_tlast  (            ), // o, 1
    .axis_reg_tuser  (            ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( dout       ), // o, TDATA_WIDTH
    .axis_reg_tready ( ren        )  // i, 1
    /* -------output st_reg inteface{end}------- */
);
/* -------- Stream reg out fifo out{end}-------- */

endmodule
