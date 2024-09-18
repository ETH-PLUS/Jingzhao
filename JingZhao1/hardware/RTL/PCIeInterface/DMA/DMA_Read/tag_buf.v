`timescale 1ns / 100ps
//*************************************************************************
// > File Name: tag_buf.v
// > Author   : Kangning
// > Date     : 2023-02-28
// > Note     : tag_buf, store reordered rsp pkt.
//*************************************************************************

module tag_buf #(
    
) (
    input  wire dma_clk, // i, 1
    input  wire rst_n  , // i, 1

    /* -------- Store related channel {begin}-------- */
    input  wire                    store_wen , // o, 1
    input  wire [`TAG_NUM_LOG-1:0] store_tag , // o, `TAG_NUM_LOG
    input  wire                    store_last, // o, 1
    input  wire [`DMA_DATA_W -1:0] store_data, // o, `DMA_DATA_W
    output wire                    store_rdy , // i, 1
    /* -------- Store related channel {end}-------- */

    /* -------- Fetch related channel {begin}-------- */
    input  wire                    fetch_ren  , // i, 1
    input  wire [`TAG_NUM_LOG-1:0] fetch_tag  , // i, `TAG_NUM_LOG
    output wire                    fetch_last , // o, 1 ; assert when this is the last sub-rsp pkt
    output wire [`DMA_DATA_W -1:0] fetch_data , // o, `DMA_DATA_W
    output wire                    fetch_vld    // o, 1
    /* -------- Fetch related channel {end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [`SRAM_RW_DATA_W-1:0] rw_data// i, `SRAM_RW_DATA_W
    ,output wire [`TAG_BUF_SIGNAL_W-1:0] dbg_signal  // o, `TAG_BUF_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

/* -------Index file{begin}------- */
reg [2:0] rd_idx[`TAG_NUM-1:0];
reg [2:0] wr_idx[`TAG_NUM-1:0];
reg [3:0] cnt   [`TAG_NUM-1:0];

reg rd_data_vld;
wire full, empty;
/* -------Index file{end}------- */

/* --------reordered rsp pkt storge{begin}-------- */
wire                      buf_wen   ;
wire [`TAG_NUM_LOG+3-1:0] buf_waddr ;
wire [1+`DMA_DATA_W -1:0] buf_din   ;

wire                      buf_ren   ;
wire [`TAG_NUM_LOG+3-1:0] buf_raddr ;
wire [1+`DMA_DATA_W -1:0] buf_dout  ;
/* --------reordered rsp pkt storge{end}-------- */


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
assign dbg_signal = { // 537
    rd_data_vld, full, empty, // 3
    buf_wen, buf_waddr, buf_din  , // 267
    buf_ren, buf_raddr, buf_dout // 267
};
/* -------APB reated signal{end}------- */
`endif

/* -------- Index file update{begin}-------- */
integer i;
always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        for (i = 0; i < `TAG_NUM; i = i + 1) begin
            rd_idx[i] <= `TD 0;
        end
    end
    else if (fetch_ren) begin
        rd_idx[fetch_tag] <= `TD rd_idx[fetch_tag] + !empty;
    end
end

integer j;
always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        for (j = 0; j < `TAG_NUM; j = j + 1) begin
            wr_idx[j] <= `TD 0;
        end
    end
    else if (store_wen) begin
        wr_idx[store_tag] <= `TD wr_idx[store_tag] + !full;
    end
end

integer k;
always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        for (k = 0; k < `TAG_NUM; k = k + 1) begin
            cnt[k] <= `TD 0;
        end
    end
    else if ((store_tag == fetch_tag) & 
            store_wen & fetch_ren) begin // store and fetch the same buffer
        cnt[store_tag] <= `TD cnt[store_tag] + !full - !empty;
    end
    else if (store_wen & fetch_ren) begin
        cnt[store_tag] <= `TD cnt[store_tag] + !full;
        cnt[fetch_tag] <= `TD cnt[fetch_tag] - !empty;
    end
    else if (store_wen) begin
        cnt[store_tag] <= `TD cnt[store_tag] + !full;
    end
    else if (fetch_ren) begin
        cnt[fetch_tag] <= `TD cnt[fetch_tag] - !empty;
    end
end
/* -------- Index file update{end}-------- */

/* --------Store related logic{begin}-------- */
assign full = (cnt[store_tag] == 8);

assign store_rdy = !full;
/* --------Store related logic{end}-------- */

/* --------Fetch related logic{begin}-------- */
assign empty = (cnt[fetch_tag] == 0);

assign {fetch_last, fetch_data} = fetch_vld ? buf_dout : {1+`DMA_DATA_W{1'd0}};

always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        rd_data_vld <= `TD 1'd0;
    end
    else if (fetch_last) begin
        rd_data_vld <= `TD 1'd0;
    end
    else if (fetch_ren) begin
        rd_data_vld <= `TD buf_ren;
    end
end
assign fetch_vld = rd_data_vld;
/* --------Fetch related logic{end}-------- */

/* --------reordered rsp pkt storge{begin}-------- */
assign buf_wen   = store_wen & store_rdy;
assign buf_waddr = (store_tag << 3) + wr_idx[store_tag];
assign buf_din   = {store_last, store_data};

assign buf_ren   = fetch_ren & !empty;
assign buf_raddr = (fetch_tag << 3) + rd_idx[fetch_tag];

pcieifc_sd_sram #(
    .DATAWIDTH  ( 1 + `DMA_DATA_W  ), // 257
    .ADDRWIDTH  ( `TAG_NUM_LOG + 3 )  // 512 depth
) reorder_buf (
    .clk   ( dma_clk ), // i, 1
    .rst_n ( rst_n   ), // i, 1

    .wea   ( buf_wen   ), // i, 1
    .addra ( buf_waddr ), // i, ADDRWIDTH
    .dina  ( buf_din   ), // i, DATAWIDTH

    .reb   ( buf_ren   ), // i, 1
    .addrb ( buf_raddr ), // i, ADDRWIDTH
    .doutb ( buf_dout  )  // o, DATAWIDTH

`ifdef PCIEI_APB_DBG
    ,.rtsel ( rtsel )
    ,.wtsel ( wtsel )
    ,.ptsel ( ptsel )
    ,.vg    ( vg    )
    ,.vs    ( vs    )
`endif
);

/* --------reordered rsp pkt storge{end}-------- */



endmodule