`timescale 1ns / 100ps
//*************************************************************************
// > File Name: rq_async_fifos.v
// > Author   : Kangning
// > Date     : 2021-08-16
// > Note     : rq_async_fifos, used to separate rdma and pcie clock domain, 
// >               in RQ (Requester request channel).
//*************************************************************************

//`include "../lib/global_include_h.v"

module rq_async_fifos #(
    
) (
    input  wire                        dma_clk   ,
    input  wire                        pcie_clk  ,
    input  wire                        dma_rst_n ,
    input  wire                        pcie_rst_n,


    /* -------dma --> pcie interface, dma part{begin}------- */
    // Requester request
    /*  RQ tuser
     * |  59:28 |  27:24  |    23:16   |          15         |   14:13  |      12     |     11      |     10:8    |   7:4   |    3:0   |
     * | parity | seq_num | tph_st_tag | tph_indirect_tag_en | tph_type | tph_present | discontinue | addr_offset | last_be | first_be |
     * |   0    |   0     |     0      |          0          |     0    |      0      |      0      |      0      |         |          |
     */
    input  wire                   dma_axis_rq_tvalid, // o, 1
    input  wire                   dma_axis_rq_tlast , // o, 1
    input  wire [`DMA_DATA_W-1:0] dma_axis_rq_tdata , // o, `DMA_DATA_W
    input  wire [59           :0] dma_axis_rq_tuser , // o, 60
    input  wire [`DMA_KEEP_W-1:0] dma_axis_rq_tkeep , // o, `DMA_KEEP_W
    output wire                   dma_axis_rq_tready, // i, 1
    /* -------dma --> pcie interface, dma part{end}------- */

    /* -------dma --> pcie interface, pcie part{begin}------- */
    // Requester request
    /*  RQ tuser
     * |  59:28 |  27:24  |    23:16   |          15         |   14:13  |      12     |     11      |     10:8    |   7:4   |    3:0   |
     * | parity | seq_num | tph_st_tag | tph_indirect_tag_en | tph_type | tph_present | discontinue | addr_offset | last_be | first_be |
     * |   0    |   0     |     0      |          0          |     0    |      0      |      0      |      0      |         |          |
     */
    output wire                   st_pcie_axis_rq_tvalid, // o, 1
    output wire                   st_pcie_axis_rq_tlast , // o, 1
    output wire [`DMA_DATA_W-1:0] st_pcie_axis_rq_tdata , // o, `DMA_DATA_W
    output wire [59           :0] st_pcie_axis_rq_tuser , // o, 60
    output wire [`DMA_KEEP_W-1:0] st_pcie_axis_rq_tkeep , // o, `DMA_KEEP_W
    input  wire                   st_pcie_axis_rq_tready  // i, 1
    /* -------dma --> pcie interface, pcie part{begin}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [`SRAM_RW_DATA_W   -1:0] rw_data    // i, `SRAM_RW_DATA_W  
    ,output wire [`RQ_ASYNC_SIGNAL_W-1:0] dbg_signal // o, `RQ_ASYNC_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);
wire dma_axis_rq_full;

/* -------tmp store the whole rq pkt{begin}------- */
wire                                         fifo_out_ren  ;
wire [1 + `DMA_KEEP_W + 8 + `DMA_DATA_W-1:0] fifo_out_tdata;
wire                                         fifo_out_empty;

wire                                         pkt_store_wen  ;
wire                                         pkt_store_full ;
wire                                         pkt_store_ren  ;
wire [1 + `DMA_KEEP_W + 8 + `DMA_DATA_W-1:0] pkt_store_tdata;
wire                                         pkt_store_empty;

reg [4:0] pkt_cnt; // 
/* -------tmp store the whole rq pkt{begin}------- */

/* -------dma --> pcie interface, pcie part{begin}------- */
// Requester request
/*  RQ tuser
 * |  59:28 |  27:24  |    23:16   |          15         |   14:13  |      12     |     11      |     10:8    |   7:4   |    3:0   |
 * | parity | seq_num | tph_st_tag | tph_indirect_tag_en | tph_type | tph_present | discontinue | addr_offset | last_be | first_be |
 * |   0    |   0     |     0      |          0          |     0    |      0      |      0      |      0      |         |          |
 */
wire                   pcie_axis_rq_tvalid;
wire                   pcie_axis_rq_tlast ;
wire [`DMA_DATA_W-1:0] pcie_axis_rq_tdata ;
wire [59           :0] pcie_axis_rq_tuser ;
wire [`DMA_KEEP_W-1:0] pcie_axis_rq_tkeep ;
wire                   pcie_axis_rq_tready;
/* -------dma --> pcie interface, pcie part{begin}------- */

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

assign dbg_signal = { // 885
    dma_axis_rq_full, // 1
    fifo_out_ren, fifo_out_tdata, fifo_out_empty, // 275
    pkt_store_wen, pkt_store_full, pkt_store_ren, pkt_store_tdata, pkt_store_empty, // 277 
    pkt_cnt, // 5
    pcie_axis_rq_tvalid, pcie_axis_rq_tlast , pcie_axis_rq_tdata , pcie_axis_rq_tuser , pcie_axis_rq_tkeep , pcie_axis_rq_tready // 327
};
/* -------APB reated signal{end}------- */
`endif

pcieifc_async_fifo #(
    .DATA_WIDTH   ( 1 + `DMA_KEEP_W + 8 + `DMA_DATA_W ),
    .ADDR_WIDTH   (  4            )
) pcieifc_async_fifo (
    .wr_clk ( dma_clk    ), // i, 1
    .rd_clk ( pcie_clk   ), // i, 1
    .wrst_n ( dma_rst_n  ), // i, 1
    .rrst_n ( pcie_rst_n ), // i, 1

    .wen  ( dma_axis_rq_tvalid & dma_axis_rq_tready ), // i, 1
    .din  ( {dma_axis_rq_tlast, dma_axis_rq_tkeep, dma_axis_rq_tuser[7:0], dma_axis_rq_tdata} ), // i, (`DMA_KEEP_W + 8 + 1 + `DMA_DATA_W)
    .full ( dma_axis_rq_full                        ), // o, 1

    .ren   ( fifo_out_ren   ), // i, 1
    .dout  ( fifo_out_tdata ), // o, (1 + `DMA_KEEP_W + 8 + `DMA_DATA_W)
    .empty ( fifo_out_empty )  // o, 1

`ifdef PCIEI_APB_DBG
    ,.rtsel  ( rtsel )  // i, 2
    ,.wtsel  ( wtsel )  // i, 2
    ,.ptsel  ( ptsel )  // i, 2
    ,.vg     ( vg    )  // i, 1
    ,.vs     ( vs    )  // i, 1
`endif
);
assign dma_axis_rq_tready  = !dma_axis_rq_full;

/* --------tmp store the whole rq pkt{begin}------- */
assign fifo_out_ren  = !pkt_store_full;
assign pkt_store_wen = !fifo_out_empty & !pkt_store_full;
pcieifc_sync_fifo #(
    .DSIZE      ( 1 + `DMA_KEEP_W + 8 + `DMA_DATA_W ), // 1 + 8 + 8 + 256 = 273
    .ASIZE      ( 4 )  // 16 depth
) pkt_store_fifo (

    .clk   ( pcie_clk   ), // i, i
    .rst_n ( pcie_rst_n ), // i, i
    .clr   ( 1'd0       ), // i, 1

    .wen  ( pkt_store_wen  ), // i, 1
    .din  ( fifo_out_tdata ), // i, 1 + `DMA_KEEP_W + 8 + `DMA_DATA_W
    .full ( pkt_store_full ), // o, 1

    .ren  ( pkt_store_ren   ), // i, 1
    .dout ( pkt_store_tdata ), // o, 1 + `DMA_KEEP_W + 8 + `DMA_DATA_W
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
    else if (pkt_store_tdata[272] & pkt_store_ren & fifo_out_tdata[272] & pkt_store_wen) begin
        pkt_cnt <= `TD pkt_cnt;
    end
    else if (pkt_store_tdata[272] & pkt_store_ren) begin
        pkt_cnt <= `TD pkt_cnt - 5'd1;
    end
    else if (fifo_out_tdata[272] & pkt_store_wen) begin
        pkt_cnt <= `TD pkt_cnt + 5'd1;
    end
end

assign pcie_axis_rq_tvalid = !pkt_store_empty & (pkt_cnt > 0);
assign pcie_axis_rq_tlast  = pcie_axis_rq_tvalid ? pkt_store_tdata[272] : 1'd0;
assign pcie_axis_rq_tdata  = pcie_axis_rq_tvalid ? pkt_store_tdata[255:0] : 256'd0;
assign pcie_axis_rq_tuser  = {52'd0, pkt_store_tdata[263:256]};
assign pcie_axis_rq_tkeep  = pcie_axis_rq_tvalid ? pkt_store_tdata[271:264] : 8'd0;

assign pkt_store_ren = pcie_axis_rq_tvalid & pcie_axis_rq_tready;
/* --------tmp store the whole rq pkt{end}------- */

/* -------Read Request FIFO{begin}------- */
st_reg #(
    .TUSER_WIDTH ( 60 ),
    .TDATA_WIDTH ( `DMA_DATA_W + `DMA_KEEP_W )
) st_rq (
    .clk   ( pcie_clk   ), // i, 1
    .rst_n ( pcie_rst_n ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( pcie_axis_rq_tvalid ), // i, 1
    .axis_tlast  ( pcie_axis_rq_tlast  ), // i, 1
    .axis_tuser  ( pcie_axis_rq_tuser  ), // i, TUSER_WIDTH
    .axis_tdata  ( {pcie_axis_rq_tdata, pcie_axis_rq_tkeep} ), // i, TDATA_WIDTH
    .axis_tready ( pcie_axis_rq_tready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .axis_reg_tvalid ( st_pcie_axis_rq_tvalid ), // o, 1
    .axis_reg_tlast  ( st_pcie_axis_rq_tlast  ), // o, 1
    .axis_reg_tuser  ( st_pcie_axis_rq_tuser  ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( {st_pcie_axis_rq_tdata, st_pcie_axis_rq_tkeep} ), // o, TDATA_WIDTH
    .axis_reg_tready ( st_pcie_axis_rq_tready )  //` i, 1
    /* -------output in_reg inteface{end}------- */
);
/* -------Read Request FIFO{end}------- */

endmodule
