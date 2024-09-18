`timescale 1ns / 100ps
//*************************************************************************
// > File Name: rrsp_async_fifos.v
// > Author   : Kangning
// > Date     : 2023-04-23
// > Note     : rrsp_async_fifos, used to separate rdma and pcie clock domain, 
// >               in RC (Requester Completion Channel).
//*************************************************************************

//`include "../lib/global_include_h.v"

module rrsp_async_fifos #(

) (
    input  wire                        dma_clk   ,
    input  wire                        pcie_clk  ,
    input  wire                        dma_rst_n ,
    input  wire                        pcie_rst_n,

    /* ------- pcie clock domain{begin}------- */
    /* AXI-Stream read response tuser, interact with read response distributor.
     * Only valid in first beat of a packet
     * | Reserved | REQ CPL |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 119:105  |   104   | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     */
    input  wire                      pcie_axis_rrsp_tvalid, // i, 1
    input  wire                      pcie_axis_rrsp_tlast , // i, 1
    input  wire  [`DMA_DATA_W  -1:0] pcie_axis_rrsp_tdata , // i, `DMA_DATA_W
    input  wire  [`AXIS_TUSER_W-1:0] pcie_axis_rrsp_tuser , // i, `AXIS_TUSER_W
    input  wire  [`DMA_KEEP_W  -1:0] pcie_axis_rrsp_tkeep , // i, `DMA_KEEP_W
    output wire                      pcie_axis_rrsp_tready, // o, 1
    /* ------- pcie clock domain{end}------- */

    /* ------- dma clock domain{begin}------- */
    /* AXI-Stream read response tuser, interact with read response distributor.
     * Only valid in first beat of a packet
     * | Reserved | REQ CPL |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 119:105  |   104   | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     */
    output wire                      dma_axis_rrsp_tvalid, // o, 1
    output wire                      dma_axis_rrsp_tlast , // o, 1
    output wire  [`DMA_DATA_W  -1:0] dma_axis_rrsp_tdata , // o, `DMA_DATA_W
    output wire  [`AXIS_TUSER_W-1:0] dma_axis_rrsp_tuser , // o, `AXIS_TUSER_W
    output wire  [`DMA_KEEP_W  -1:0] dma_axis_rrsp_tkeep , // o, `DMA_KEEP_W
    input  wire                      dma_axis_rrsp_tready  // i, 1
    /* ------- dma clock domain{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [`SRAM_RW_DATA_W   -1:0] rw_data    // i, `SRAM_RW_DATA_W
    ,output wire [`RRSP_ASYNC_SIGNAL_W-1:0] dbg_signal // o, `RRSP_ASYNC_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);
wire pcie_axis_rrsp_full, dma_axis_rrsp_empty;


// | addr   | last |  keep |  tag  | req_cpl | dw_len | first BE | last BE |
// | 12 bit | 1 bit| 8 bit | 8 bit |  1 bit  | 11 bit |  4 bit   |  4 bit  |
// | 48:37  |  36  | 35:28 | 27:20 |   19    |  18:8  |  7 : 4   |  3 : 0  |
wire [40:0] pcie_header, dma_header;

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
assign dbg_signal = { // 84
    pcie_axis_rrsp_full, dma_axis_rrsp_empty, 
    dma_header, 
    pcie_header
};
/* -------APB reated signal{end}------- */
`endif

assign pcie_header = {  pcie_axis_rrsp_tuser[35:32],  // addr, 4 bit
                        pcie_axis_rrsp_tlast, 
                        pcie_axis_rrsp_tkeep, 
                        pcie_axis_rrsp_tuser[103:96], // tag,, 8 bit
                        pcie_axis_rrsp_tuser[104],    // req cpl, 1 bit
                        pcie_axis_rrsp_tuser[18:0]};

pcieifc_async_fifo #(
    .DATA_WIDTH   ( (41 + `DMA_DATA_W) ),
    .ADDR_WIDTH   (  4             )
) pcieifc_async_fifo (
    .wr_clk ( pcie_clk   ), // i, 1
    .rd_clk ( dma_clk    ), // i, 1
    .wrst_n ( pcie_rst_n ), // i, 1
    .rrst_n ( dma_rst_n  ), // i, 1

    .wen  ( pcie_axis_rrsp_tvalid & pcie_axis_rrsp_tready ), // i, 1
    .din  ( {pcie_header, pcie_axis_rrsp_tdata} ), // i, (1 + `DMA_KEEP_W + 32 + `DMA_DATA_W)
    .full ( pcie_axis_rrsp_full                         ), // o, 1

    .ren   ( dma_axis_rrsp_tvalid & dma_axis_rrsp_tready ), // i, 1
    .dout  ( {dma_header, dma_axis_rrsp_tdata} ), // o, (1 + `DMA_KEEP_W + 32 + `DMA_DATA_W)
    .empty ( dma_axis_rrsp_empty                       )  // o, 1

`ifdef PCIEI_APB_DBG
    ,.rtsel  ( rtsel )  // i, 2
    ,.wtsel  ( wtsel )  // i, 2
    ,.ptsel  ( ptsel )  // i, 2
    ,.vg     ( vg    )  // i, 1
    ,.vs     ( vs    )  // i, 1
`endif
);

assign pcie_axis_rrsp_tready = !pcie_axis_rrsp_full;
assign dma_axis_rrsp_tvalid  = !dma_axis_rrsp_empty;


// | addr   | last |  keep |  tag  | req_cpl | dw_len | first BE | last BE |
// | 12 bit | 1 bit| 8 bit | 8 bit |  1 bit  | 11 bit |  4 bit   |  4 bit  |
// | 48:37  |  36  | 35:28 | 27:20 |   19    |  18:8  |  7 : 4   |  3 : 0  |
assign dma_axis_rrsp_tkeep = dma_header[35:28];
assign dma_axis_rrsp_tlast = dma_header[36];


/* AXI-Stream read response tuser, interact with read response distributor.
 * Only valid in first beat of a packet
 * | Reserved | REQ CPL |   Tag  | address | Reserved | DW length | first BE | last BE |
 * | 119:105  |   104   | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
 */
assign dma_axis_rrsp_tuser = {
                            24'd0, 
                            dma_header[19], 
                            dma_header[27:20], 
                            32'd0, 28'd0, dma_header[40:37], // addr, 64 bit
                            13'd0, dma_header[18:0]};

endmodule
