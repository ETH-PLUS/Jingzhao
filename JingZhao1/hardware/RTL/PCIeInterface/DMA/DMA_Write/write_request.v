`timescale 1ns / 100ps
//*************************************************************************
// > File Name: write_request.v
// > Author   : Kangning
// > Date     : 2020-08-25
// > Note     : write_request, used to transform DMA write request. 
// >               Note that the packet must be 4KB aligned.
//*************************************************************************

//`include "../lib/global_include_h.v"
//`include "../lib/dma_def_h.v"

module write_request #(

) (
    input  wire    clk  ,
    input  wire    rst_n,

    /* -------dma write request interface{begin}------- */
    /* *_head of DMA interface (interact with RDMA modules), 
     * valid only in first beat of a packet.
     * When Transmiting msi-x interrupt message, 'Byte length' 
     * should be 0, 'address' means the address of msi-x, and
     * msi-x data locates in *_data[31:0].
     * | Resvd | Req Type |   address    | Reserved | Byte length |
     * |       | (wr,int) | (msi-x addr) |          | (0 for int) |
     * |-------|----------|--------------|----------|-------------|
     * |127:100|  99:96   |    95:32     |  31:13   |    12:0     |
     */
    input  wire                   dma_wr_req_valid,
    input  wire                   dma_wr_req_last ,
    input  wire [`DMA_HEAD_W-1:0] dma_wr_req_head ,
    input  wire [`DMA_DATA_W-1:0] dma_wr_req_data ,
    output wire                   dma_wr_req_ready,
    /* -------dma write request interface{end}------- */

    /* -------axis write request interface{begin}------- */
    /* AXI-Stream write request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     * or
     * AXI-Stream interrupt request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |  Resv  | address | Reserved |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:0    |
     */
    output wire                     axis_wr_req_tvalid,
    output wire                     axis_wr_req_tlast ,
    output wire [`DMA_DATA_W  -1:0] axis_wr_req_tdata , // contain only payload
    output wire [`AXIS_TUSER_W-1:0] axis_wr_req_tuser , // The field contents are different from dma_*_tuser interface
    output wire [`DMA_KEEP_W  -1:0] axis_wr_req_tkeep ,
    input  wire                     axis_wr_req_tready,
    /* -------axis write request interface{end}------- */

    /* -------PCIe fragment property{begin}------- */
    /* This signal indicates the (max payload size & max read request size) agreed in the communication
     * 3'b000 -- 128 B
     * 3'b001 -- 256 B
     * 3'b010 -- 512 B
     * 3'b011 -- 1024B
     * 3'b100 -- 2048B
     * 3'b101 -- 4096B
     */
    input wire [2:0] max_pyld_sz  ,
    input wire [2:0] max_rd_req_sz  // max read request size
    /* -------PCIe fragment property{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [`SRAM_RW_DATA_W -1:0] rw_data  // i, `SRAM_RW_DATA_W
    ,output wire [`WR_REQ_SIGNAL_W-1:0] dbg_signal // o, `WR_REQ_SIGNAL_W  
    /* -------APB reated signal{end}------- */
`endif
);

/* -------FIFO -> pkt align{begin}------- */
wire                      dma_valid;
wire                      dma_last ;
wire [`DMA_HEAD_W-1:0]    dma_head ;
wire [`DMA_DATA_W-1:0]    dma_data ;
wire                      dma_ready;

wire dma_empty, dma_full;
/* -------FIFO -> pkt align{end}------- */

/* -------FIFO -> pkt align{begin}------- */
wire                      align_valid;
wire                      align_last ;
wire [`DMA_HEAD_W-1:0]    align_user ;
wire [`DMA_DATA_W-1:0]    align_data ;
wire                      align_ready;
/* -------FIFO -> pkt align{end}------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire  [1:0]  rtsel;
wire  [1:0]  wtsel;
wire  [1:0]  ptsel;
wire         vg   ;
wire         vs   ;

wire [`WREQ_TOP_SIGNAL_W  -1:0] wreq_top_dbg_signal  ;
wire [`WREQ_ALIGN_SIGNAL_W-1:0] wreq_align_dbg_signal;
wire [`WREQ_SPLIT_SIGNAL_W-1:0] wreq_split_dbg_signal;
/* -------APB reated signal{end}------- */
`endif

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign {rtsel, wtsel, ptsel, vg, vs} = rw_data;
assign dbg_signal = {wreq_top_dbg_signal, wreq_align_dbg_signal, wreq_split_dbg_signal};

assign wreq_top_dbg_signal = { // 776
    dma_valid, dma_last, dma_head, dma_data, dma_ready, // 387
    dma_empty, dma_full, // 2
    align_valid, align_last, align_user, align_data, align_ready // 387
};
/* -------APB reated signal{end}------- */
`endif

/* ------- Write Request FIFO{begin}------- */
pcieifc_sync_fifo #(
    .DSIZE      ( 1 + `DMA_HEAD_W + `DMA_DATA_W ),   // 1 + 128 + 256=385
    .ASIZE      ( 7                              )   // 128 beats
) data_sync_fifo (
    .clk   ( clk ), // i, i
    .rst_n ( rst_n    ), // i, i
    .clr   ( 1'd0     ), // i, 1

    .wen  ( dma_wr_req_valid & dma_wr_req_ready ), // i, 1
    .din  ( {dma_wr_req_last, dma_wr_req_head, dma_wr_req_data}  ), // i, (1 + `DMA_HEAD_W + `DMA_DATA_W)
    .full ( dma_full                     ), // o, 1

    .ren  ( dma_valid & dma_ready ), // i, 1
    .dout ( {dma_last, dma_head, dma_data}  ), // o, (1 + `DMA_HEAD_W + `DMA_DATA_W)
    .empty( dma_empty             )  // o, 1

`ifdef PCIEI_APB_DBG
    ,.rtsel ( rtsel )  // i, 2
    ,.wtsel ( wtsel )  // i, 2
    ,.ptsel ( ptsel )  // i, 2
    ,.vg    ( vg    )  // i, 1
    ,.vs    ( vs    )  // i, 1
`endif
);
assign dma_wr_req_ready = !dma_full;
assign dma_valid = !dma_empty;
/* ------- Write Request FIFO{end}------- */


/* ------- Align data to DW aligned{begin}------- */
wreq_align #(
    
) wreq_align (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1
    
    .dma_valid ( dma_valid ), // i, 1
    .dma_last  ( dma_last  ), // i, 1
    .dma_head  ( dma_head  ), // i, `DMA_HEAD_W
    .dma_data  ( dma_data  ), // i, `DMA_DATA_W
    .dma_ready ( dma_ready ), // o, 1

    .align_valid ( align_valid ), // o, 1
    .align_last  ( align_last  ), // o, 1
    .align_user  ( align_user  ), // o, `AXIS_TUSER_W
    .align_data  ( align_data  ), // o, `DMA_DATA_W
    .align_ready ( align_ready )  // i, 1

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_signal ( wreq_align_dbg_signal ) // o, `WREQ_ALIGN_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);
/* ------- Align data to DW aligned{end}------- */

/* ------- Split pkt to fit max_pyld_sz{begin}------- */
wreq_split #(
    
) wreq_split (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    .max_pyld_sz ( max_pyld_sz ), // i, 3

    .align_valid ( align_valid ), // i, 1
    .align_last  ( align_last  ), // i, 1
    .align_user  ( align_user  ), // i, `AXIS_TUSER_W
    .align_data  ( align_data  ), // i, `DMA_DATA_W
    .align_ready ( align_ready ), // o, 1

    .axis_wr_req_tvalid ( axis_wr_req_tvalid ), // o, 1
    .axis_wr_req_tlast  ( axis_wr_req_tlast  ), // o, 1
    .axis_wr_req_tdata  ( axis_wr_req_tdata  ), // o, `DMA_DATA_W
    .axis_wr_req_tuser  ( axis_wr_req_tuser  ), // o, `AXIS_TUSER_W
    .axis_wr_req_tkeep  ( axis_wr_req_tkeep  ), // o, `DMA_KEEP_W
    .axis_wr_req_tready ( axis_wr_req_tready )  // i, 1

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_signal ( wreq_split_dbg_signal ) // o, `WREQ_SPLIT_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);
/* ------- Split pkt to fit max_pyld_sz{end}------- */

endmodule
