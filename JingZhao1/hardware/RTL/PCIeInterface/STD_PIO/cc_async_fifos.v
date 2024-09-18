`timescale 1ns / 100ps
//*************************************************************************
// > File Name: cc_async_fifos.v
// > Author   : Kangning
// > Date     : 2023-02-24
// > Note     : cc_async_fifos, used to separate rdma and pcie clock domain, 
// >               in Completion Completer Channel.
//*************************************************************************

//`include "../lib/global_include_h.v"

module cc_async_fifos #(
    
) (
    input  wire                        user_clk  ,
    input  wire                        pcie_clk  ,
    input  wire                        user_rst_n,
    input  wire                        pcie_rst_n,

    /* -------std_pio --> pcie interface, pio part{begin}------- */
    /*  CC tuser
     * |  32:1  |      0      |
     * | parity | discontinue |
     * | ignore |   ignore    |
     */
    input  wire                   pio_axis_cc_tvalid, // i, 1
    input  wire                   pio_axis_cc_tlast , // i, 1
    input  wire [`PIO_DATA_W-1:0] pio_axis_cc_tdata , // i, `PIO_DATA_W
    input  wire [32           :0] pio_axis_cc_tuser , // i, 33
    input  wire [`PIO_KEEP_W-1:0] pio_axis_cc_tkeep , // i, `PIO_KEEP_W
    output wire                   pio_axis_cc_tready, // o, 1
    /* -------std_pio --> pcie interface, pio part{end}------- */

    /* -------std_pio --> pcie interface, pcie part{begin}------- */
    /*  CC tuser
     * |  32:1  |      0      |
     * | parity | discontinue |
     * | ignore |   ignore    |
     */
    output wire                   st_pcie_axis_cc_tvalid, // o, 1
    output wire                   st_pcie_axis_cc_tlast , // o, 1
    output wire [`PIO_DATA_W-1:0] st_pcie_axis_cc_tdata , // o, `PIO_DATA_W
    output wire [32           :0] st_pcie_axis_cc_tuser , // o, 33
    output wire [`PIO_KEEP_W-1:0] st_pcie_axis_cc_tkeep , // o, `PIO_KEEP_W
    input  wire                   st_pcie_axis_cc_tready  // i, 1
    /* -------std_pio --> pcie interface, pcie part{begin}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [`SRAM_RW_DATA_W   -1:0] rw_data    // i, `SRAM_RW_DATA_W  
    ,output wire [`CC_ASYNC_SIGNAL_W-1:0] dbg_signal // o, `CC_ASYNC_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);
wire pio_axis_cc_full;

/* -------tmp store the whole rq pkt{begin}------- */
wire                                     fifo_out_ren  ;
wire [1 + `PIO_KEEP_W + `PIO_DATA_W-1:0] fifo_out_tdata;
wire                                     fifo_out_empty;

wire                                     pkt_store_wen  ;
wire                                     pkt_store_full ;
wire                                     pkt_store_ren  ;
wire [1 + `PIO_KEEP_W + `PIO_DATA_W-1:0] pkt_store_tdata;
wire                                     pkt_store_empty;

reg [4:0] pkt_cnt; // 
/* -------tmp store the whole rq pkt{begin}------- */

/* -------std_pio --> pcie interface, pcie part{begin}------- */
wire                   pcie_axis_cc_tvalid;
wire                   pcie_axis_cc_tlast ;
wire [`PIO_DATA_W-1:0] pcie_axis_cc_tdata ;
wire [`PIO_KEEP_W-1:0] pcie_axis_cc_tkeep ;
wire                   pcie_axis_cc_tready;
/* -------std_pio --> pcie interface, pcie part{begin}------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire  [1:0]  rtsel;
wire  [1:0]  wtsel;
wire  [1:0]  ptsel;
wire         vg   ;
wire         vs   ;
/* -------APB reated signal{end}------- */
`endif

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign {rtsel, wtsel, ptsel, vg, vs} = rw_data;

assign dbg_signal = { // 809
    pio_axis_cc_full, // 1
    fifo_out_ren, fifo_out_tdata, fifo_out_empty, // 267
    pkt_store_wen, pkt_store_full, pkt_store_ren, pkt_store_tdata, pkt_store_empty, // 269
    pkt_cnt, // 5
    pcie_axis_cc_tvalid, pcie_axis_cc_tlast , pcie_axis_cc_tdata , pcie_axis_cc_tkeep , pcie_axis_cc_tready // 267
};
/* -------APB reated signal{end}------- */
`endif

pcieifc_async_fifo #(
    .DATA_WIDTH   ( 1 + `PIO_KEEP_W + `PIO_DATA_W ),
    .ADDR_WIDTH   (  5            )
) pcieifc_async_fifo (
    .wr_clk ( user_clk    ), // i, 1
    .rd_clk ( pcie_clk   ), // i, 1
    .wrst_n ( user_rst_n  ), // i, 1
    .rrst_n ( pcie_rst_n ), // i, 1

    .wen  ( pio_axis_cc_tvalid & pio_axis_cc_tready ), // i, 1
    .din  ( {pio_axis_cc_tlast, pio_axis_cc_tkeep, pio_axis_cc_tdata} ), // i, (1 + `PIO_KEEP_W + `PIO_DATA_W)
    .full ( pio_axis_cc_full                        ), // o, 1

    .ren   ( fifo_out_ren   ), // i, 1
    .dout  ( fifo_out_tdata ), // o, (1 + `PIO_KEEP_W + `PIO_DATA_W)
    .empty ( fifo_out_empty )  // o, 1

`ifdef PCIEI_APB_DBG
    ,.rtsel  ( rtsel )  // i, 2
    ,.wtsel  ( wtsel )  // i, 2
    ,.ptsel  ( ptsel )  // i, 2
    ,.vg     ( vg    )  // i, 1
    ,.vs     ( vs    )  // i, 1
`endif
);
assign pio_axis_cc_tready  = !pio_axis_cc_full;

/* --------tmp store the whole rq pkt{begin}------- */
assign fifo_out_ren  = !pkt_store_full;
assign pkt_store_wen = !fifo_out_empty & !pkt_store_full;
pcieifc_sync_fifo #(
    .DSIZE      ( 1 + `PIO_KEEP_W + `PIO_DATA_W ), // 1 + 8 + 256 = 265
    .ASIZE      ( 5 )  // 32 depth
) pkt_store_fifo (

    .clk   ( pcie_clk   ), // i, i
    .rst_n ( pcie_rst_n ), // i, i
    .clr   ( 1'd0       ), // i, 1

    .wen  ( pkt_store_wen  ), // i, 1
    .din  ( fifo_out_tdata ), // i, 1 + `PIO_KEEP_W + `PIO_DATA_W
    .full ( pkt_store_full ), // o, 1

    .ren  ( pkt_store_ren   ), // i, 1
    .dout ( pkt_store_tdata ), // o, 1 + `PIO_KEEP_W + `PIO_DATA_W
    .empty( pkt_store_empty )  // o, 1

`ifdef PCIEI_APB_DBG
    ,.rtsel ( 2'b0 )  // i, 2
    ,.wtsel ( 2'b0 )  // i, 2
    ,.ptsel ( 2'b0 )  // i, 2
    ,.vg    ( 1'b0 )  // i, 1
    ,.vs    ( 1'b0 )  // i, 1
`endif
);

always @(posedge pcie_clk, negedge pcie_rst_n) begin
    if (~pcie_rst_n) begin
        pkt_cnt <= `TD 5'd0;
    end
    else if (pkt_store_tdata[264] & pkt_store_ren & fifo_out_tdata[264] & pkt_store_wen) begin
        pkt_cnt <= `TD pkt_cnt;
    end
    else if (pkt_store_tdata[264] & pkt_store_ren) begin
        pkt_cnt <= `TD pkt_cnt - 5'd1;
    end
    else if (fifo_out_tdata[264] & pkt_store_wen) begin
        pkt_cnt <= `TD pkt_cnt + 5'd1;
    end
end

assign pcie_axis_cc_tvalid = !pkt_store_empty & (pkt_cnt > 0);
assign pcie_axis_cc_tlast  = pcie_axis_cc_tvalid ? pkt_store_tdata[264] : 1'd0;
assign pcie_axis_cc_tdata  = pcie_axis_cc_tvalid ? pkt_store_tdata[255:0] : 256'd0;
assign pcie_axis_cc_tkeep  = pcie_axis_cc_tvalid ? pkt_store_tdata[263:256] : 8'd0;

assign pkt_store_ren = pcie_axis_cc_tvalid & pcie_axis_cc_tready;
/* --------tmp store the whole rq pkt{end}------- */

/* -------Read Request FIFO{begin}------- */
st_reg #(
    .TUSER_WIDTH ( 1 ),
    .TDATA_WIDTH ( `PIO_DATA_W + `PIO_KEEP_W )
) st_cc (
    .clk   ( pcie_clk   ), // i, 1
    .rst_n ( pcie_rst_n ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( pcie_axis_cc_tvalid ), // i, 1
    .axis_tlast  ( pcie_axis_cc_tlast  ), // i, 1
    .axis_tuser  ( 1'd0  ), // i, TUSER_WIDTH
    .axis_tdata  ( {pcie_axis_cc_tdata, pcie_axis_cc_tkeep} ), // i, TDATA_WIDTH
    .axis_tready ( pcie_axis_cc_tready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .axis_reg_tvalid ( st_pcie_axis_cc_tvalid ), // o, 1
    .axis_reg_tlast  ( st_pcie_axis_cc_tlast  ), // o, 1
    .axis_reg_tuser  (   ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( {st_pcie_axis_cc_tdata, st_pcie_axis_cc_tkeep} ), // o, TDATA_WIDTH
    .axis_reg_tready ( st_pcie_axis_cc_tready )  //` i, 1
    /* -------output in_reg inteface{end}------- */
);
assign st_pcie_axis_cc_tuser = 33'd0;
/* -------Read Request FIFO{end}------- */

endmodule
