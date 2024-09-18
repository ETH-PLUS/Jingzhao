`timescale 1ns / 100ps
//*************************************************************************
// > File Name: rc_async_fifos.v
// > Author   : Kangning
// > Date     : 2021-08-16
// > Note     : rc_async_fifos, used to separate rdma and pcie clock domain, 
// >               in RC (Requester Completion Channel).
//*************************************************************************

//`include "../lib/global_include_h.v"

module rc_async_fifos #(

) (
    input  wire                        dma_clk   ,
    input  wire                        pcie_clk  ,
    input  wire                        dma_rst_n ,
    input  wire                        pcie_rst_n,

    /* ------- pcie --> dma interface, pcie part{begin}------- */
    // Requester Completion
    /*  RC tuser
     * |  74:43 |      42     |    41:38   |  37:34   |    33    |    32    |  31:0   |  
     * | parity | discontinue |  is_eof_1  | is_eof_0 | is_sof_1 | is_sof_0 | byte_en |
     * | ignore |   ignore    |  ignore    | ignore   |  ignore  |  ignore  |         |
     */
    input  wire                   pcie_axis_rc_tvalid, // i, 1
    input  wire                   pcie_axis_rc_tlast , // i, 1
    input  wire [`DMA_DATA_W-1:0] pcie_axis_rc_tdata , // i, `DMA_DATA_W
    input  wire [74           :0] pcie_axis_rc_tuser , // i, 75
    input  wire [`DMA_KEEP_W-1:0] pcie_axis_rc_tkeep , // i, `DMA_KEEP_W
    output wire                   pcie_axis_rc_tready, // o, 1
    /* ------- pcie --> dma interface, pcie part{end}------- */

    /* ------- pcie --> dma interface, dma part{begin}------- */
    // Requester Completion
    /*  RC tuser
     * |  74:43 |      42     |    41:38   |  37:34   |    33    |    32    |  31:0   |  
     * | parity | discontinue |  is_eof_1  | is_eof_0 | is_sof_1 | is_sof_0 | byte_en |
     * | ignore |   ignore    |  ignore    | ignore   |  ignore  |  ignore  |         |
     */
    output wire                   dma_axis_rc_tvalid, // i, 1
    output wire                   dma_axis_rc_tlast , // i, 1
    output wire [`DMA_DATA_W-1:0] dma_axis_rc_tdata , // i, `DMA_DATA_W
    output wire [74           :0] dma_axis_rc_tuser , // i, 75
    output wire [`DMA_KEEP_W-1:0] dma_axis_rc_tkeep , // i, `DMA_KEEP_W
    input  wire                   dma_axis_rc_tready  // o, 1
    /* ------- pcie --> dma interface, dma part{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [`SRAM_RW_DATA_W   -1:0] rw_data    // i, `SRAM_RW_DATA_W
    ,output wire [`RC_ASYNC_SIGNAL_W-1:0] dbg_signal // o, `RC_ASYNC_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);
wire pcie_axis_rc_full, dma_axis_rc_empty;
wire [31:0] rc_tuser;

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
assign dbg_signal = {
    pcie_axis_rc_full, dma_axis_rc_empty, 
    rc_tuser
};
/* -------APB reated signal{end}------- */
`endif

pcieifc_async_fifo #(
    .DATA_WIDTH   ( (1 + `DMA_KEEP_W + 32 + `DMA_DATA_W) ),
    .ADDR_WIDTH   (  6             )
) pcieifc_async_fifo (
    .wr_clk ( pcie_clk   ), // i, 1
    .rd_clk ( dma_clk    ), // i, 1
    .wrst_n ( pcie_rst_n ), // i, 1
    .rrst_n ( dma_rst_n  ), // i, 1

    .wen  ( pcie_axis_rc_tvalid & pcie_axis_rc_tready ), // i, 1
    .din  ( {pcie_axis_rc_tlast, pcie_axis_rc_tkeep, pcie_axis_rc_tuser[31:0], pcie_axis_rc_tdata} ), // i, (1 + `DMA_KEEP_W + 32 + `DMA_DATA_W)
    .full ( pcie_axis_rc_full                         ), // o, 1

    .ren   ( dma_axis_rc_tvalid & dma_axis_rc_tready ), // i, 1
    .dout  ( {dma_axis_rc_tlast, dma_axis_rc_tkeep, rc_tuser, dma_axis_rc_tdata} ), // o, (1 + `DMA_KEEP_W + 32 + `DMA_DATA_W)
    .empty ( dma_axis_rc_empty                       )  // o, 1

`ifdef PCIEI_APB_DBG
    ,.rtsel  ( rtsel )  // i, 2
    ,.wtsel  ( wtsel )  // i, 2
    ,.ptsel  ( ptsel )  // i, 2
    ,.vg     ( vg    )  // i, 1
    ,.vs     ( vs    )  // i, 1
`endif
);

assign pcie_axis_rc_tready = !pcie_axis_rc_full;
assign dma_axis_rc_tvalid  = !dma_axis_rc_empty;


assign dma_axis_rc_tuser = {43'd0, rc_tuser};

endmodule
