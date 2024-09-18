`timescale 1ns / 100ps
//*************************************************************************
// > File   : tgt_pyld_buf.v
// > Author : Kangning
// > Date   : 2022-08-29
// > Note   : Payload buffer for payload temp store
//*************************************************************************

module tgt_pyld_buf #(
    
) (

    input  wire clk     , // i, 1
    input  wire rst_n   , // i, 1
    output reg  init_end, // o, 1

    /* --------allocated buffer address{begin}-------- */
    output wire                       pbuf_alloc_valid   , // o, 1
    output wire                       pbuf_alloc_last    , // o, 1
    output wire [`BUF_ADDR_WIDTH-1:0] pbuf_alloc_buf_addr, // o, `BUF_ADDR_WIDTH
    output wire [8              -1:0] pbuf_alloc_qnum    , // o, 8
    input  wire                       pbuf_alloc_ready   , // i, 1 ; assume it always asserts
    /* --------allocated buffer address{end}-------- */

    /* --------p2p mem payload in{begin}-------- */
    input  wire                       st_pyld_req_valid, // i, 1
    input  wire                       st_pyld_req_last , // i, 1
    input  wire [`MSG_BLEN_WIDTH-1:0] st_pyld_req_blen , // i, `MSG_BLEN_WIDTH
    input  wire [8              -1:0] st_pyld_req_qnum , // i, 8
    input  wire [`P2P_DATA_W    -1:0] st_pyld_req_data , // i, `P2P_DATA_W
    output wire                       st_pyld_req_ready, // o, 1
    /* --------p2p mem payload in{end}-------- */
    
    /* --------Ctrl Info to pyld_buf{begin}-------- */
    input  wire                       pbuf_free_valid     , // i, 1
    input  wire                       pbuf_free_last      , // i, 1
    input  wire [`P2P_DHEAD_W   -1:0] pbuf_free_head      , // i, `P2P_DHEAD_W
    input  wire [1                :0] pbuf_free_buf_offset, // i, 2
    input  wire [`BUF_ADDR_WIDTH-1:0] pbuf_free_buf_addr  , // i, `BUF_ADDR_WIDTH
    output wire                       pbuf_free_ready     , // o, 1
    /* --------Ctrl Info to pyld_buf{begin}-------- */
    
    /* --------p2p mem payload out{begin}-------- */
    output reg                        ft_pyld_req_valid, // o, 1
    output reg                        ft_pyld_req_last , // o, 1
    output reg  [`P2P_DHEAD_W   -1:0] ft_pyld_req_head , // o, `P2P_DHEAD_W
    output wire [`P2P_DATA_W    -1:0] ft_pyld_req_data , // o, `P2P_DATA_W
    input  wire                       ft_pyld_req_ready  // i, 1
    /* --------p2p mem payload out{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [`SRAM_RW_DATA_W*2-1:0] rw_data  // i, `SRAM_RW_DATA_W*2
	,output wire [`TGT_PBUF_SIGNAL_W-1:0] dbg_signal // o, `TGT_PBUF_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

localparam BEAT_BYTE_NUM      = `P2P_DATA_W / 8; // 32
localparam P2P_DATA_W_LOG = $clog2(`P2P_DATA_W); // 8
localparam PBUF_BLOCK_WIDTH   = `PBUF_SZ_LOG + 3 - P2P_DATA_W_LOG; // 2
localparam PBUF_ADDR_WIDTH    = `PBUF_NUM_LOG + PBUF_BLOCK_WIDTH; // 12

/* --------free buffer list{begin}-------- */
wire                        free_buf_wen , free_buf_ren  ;
wire [`PBUF_NUM_LOG-1:0]    free_buf_din , free_buf_dout ;
wire                        free_buf_full, free_buf_empty;

wire init_stat;
reg [`PBUF_NUM_LOG-1:0] init_din;
/* --------free buffer list{end}-------- */

/* --------payload buffer{begin}-------- */
wire is_st_last_pbuf_beat; // the last beat to store payload buffer block

wire                       pbuf_st_wen ;
wire [PBUF_ADDR_WIDTH-1:0] pbuf_st_addr;
wire [`P2P_DATA_W    -1:0] pbuf_st_din ;

wire                       pbuf_ft_ren ;
wire [PBUF_ADDR_WIDTH-1:0] pbuf_ft_addr;
wire [`P2P_DATA_W    -1:0] pbuf_ft_dout;

reg  [PBUF_BLOCK_WIDTH-1:0] st_offset ;
/* --------payload buffer{end}-------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire  [1:0]  pyld_buf_rtsel, free_buf_fifo_rtsel;
wire  [1:0]  pyld_buf_wtsel, free_buf_fifo_wtsel;
wire  [1:0]  pyld_buf_ptsel, free_buf_fifo_ptsel;
wire         pyld_buf_vg   , free_buf_fifo_vg   ;
wire         pyld_buf_vs   , free_buf_fifo_vs   ;
/* -------APB reated signal{end}------- */
`endif

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign {
        free_buf_fifo_rtsel, 
        free_buf_fifo_wtsel, 
        free_buf_fifo_ptsel, 
        free_buf_fifo_vg   , 
        free_buf_fifo_vs   , 
        pyld_buf_rtsel     , 
        pyld_buf_wtsel     , 
        pyld_buf_ptsel     , 
        pyld_buf_vg        , 
        pyld_buf_vs        
} = rw_data;

assign dbg_signal = { // 576
    
    free_buf_wen , free_buf_ren  , 
    free_buf_din , free_buf_dout , 
    free_buf_full, free_buf_empty, // 24

    init_stat, init_din, // 11
    is_st_last_pbuf_beat, // 1
    
    pbuf_st_wen, pbuf_st_addr, pbuf_st_din , // 269
    pbuf_ft_ren, pbuf_ft_addr, pbuf_ft_dout, // 269

    st_offset // 2
};
/* -------APB reated signal{end}------- */
`endif

/* --------free buffer list{begin}-------- */
pcieifc_sync_fifo #(
    .DSIZE ( `PBUF_NUM_LOG ), // 10
    .ASIZE ( `PBUF_NUM_LOG )  // 10
) free_buf_fifo (
    .clk   ( clk   ),
    .rst_n ( rst_n ),
    .clr   ( 1'd0  ),
    
    .wen    ( free_buf_wen  ),
    .din    ( free_buf_din  ),
    
    .ren    ( free_buf_ren  ),
    .dout   ( free_buf_dout ),
    
    .full   ( free_buf_full  ),
    .empty  ( free_buf_empty )

`ifdef PCIEI_APB_DBG
    ,.rtsel ( free_buf_fifo_rtsel )  // i, 2
    ,.wtsel ( free_buf_fifo_wtsel )  // i, 2
    ,.ptsel ( free_buf_fifo_ptsel )  // i, 2
    ,.vg    ( free_buf_fifo_vg    )  // i, 1
    ,.vs    ( free_buf_fifo_vs    )  // i, 1
`endif
);

assign free_buf_wen = init_stat ? 1        : (pbuf_free_valid & pbuf_free_ready & (pbuf_free_last || pbuf_free_buf_offset == 3));
assign free_buf_din = init_stat ? init_din : pbuf_free_buf_addr;

assign free_buf_ren = pbuf_alloc_valid & pbuf_alloc_ready;

// Initialization related signal
assign init_stat = (~init_end & rst_n);
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        init_din <= `TD 0;
    end
    else if (~init_end) begin
        init_din <= `TD init_din + 1;
    end
end
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        init_end <= `TD 0;
    end
    else if (init_din == 10'd1023) begin
        init_end <= `TD 1;
    end
end
/* --------free buffer list{end}-------- */

/* --------payload buffer{begin}-------- */
assign is_st_last_pbuf_beat = (st_offset == 3) || st_pyld_req_last;

//pcieifc_sd_sram #(
//    .DATAWIDTH ( `P2P_DATA_W  ), // Memory data word width, 256
//    .ADDRWIDTH ( PBUF_ADDR_WIDTH )  // Number of mem address bits, 12
//) pyld_buf (
//    .clk   ( clk   ), // i, 1
//    .rst_n ( rst_n ), // i, 1

//    .wea   ( pbuf_st_wen  ), // i, 1
//    .addra ( pbuf_st_addr ), // i, ADDRWIDTH
//    .dina  ( pbuf_st_din  ), // i, DATAWIDTH

//    .reb   ( pbuf_ft_ren  ), // i, 1
//    .addrb ( pbuf_ft_addr ), // i, ADDRWIDTH
//    .doutb ( pbuf_ft_dout )  // o, DATAWIDTH

//`ifdef PCIEI_APB_DBG
//    ,.rtsel ( pyld_buf_rtsel )  // i, 2
//    ,.wtsel ( pyld_buf_wtsel )  // i, 2
//    ,.ptsel ( pyld_buf_ptsel )  // i, 2
//    ,.vg    ( pyld_buf_vg    )  // i, 1
//    ,.vs    ( pyld_buf_vs    )  // i, 1
//`endif
//);

// payload buffer related signal
assign pbuf_st_wen  = st_pyld_req_valid & st_pyld_req_ready;
assign pbuf_st_addr = {free_buf_dout, st_offset};
assign pbuf_st_din  = st_pyld_req_data;

assign pbuf_ft_ren  = pbuf_free_valid & pbuf_free_ready;
assign pbuf_ft_addr = {pbuf_free_buf_addr, pbuf_free_buf_offset};

// store address generation
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        st_offset <= `TD 0;
    end
    else if (is_st_last_pbuf_beat & (st_pyld_req_valid & st_pyld_req_ready)) begin
        st_offset <= `TD 0;
    end
    else if (st_pyld_req_valid & st_pyld_req_ready) begin
        st_offset <= `TD st_offset + 1;
    end
end
/* --------payload buffer{end}-------- */

/* --------store related output{begin}-------- */
assign st_pyld_req_ready = (is_st_last_pbuf_beat ? pbuf_alloc_ready : 1) & !free_buf_empty;

assign pbuf_alloc_valid    = is_st_last_pbuf_beat & st_pyld_req_valid & !free_buf_empty;
assign pbuf_alloc_last     = pbuf_alloc_valid & st_pyld_req_last;
assign pbuf_alloc_buf_addr = free_buf_dout   ;
assign pbuf_alloc_qnum     = st_pyld_req_qnum;
/* --------store related output{end}-------- */

/* --------fetch related output{begin}-------- */
assign pbuf_free_ready   = !ft_pyld_req_valid | ft_pyld_req_ready;

assign ft_pyld_req_data  = pbuf_ft_dout;
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        ft_pyld_req_valid <= `TD 1'd0;
        ft_pyld_req_last  <= `TD 1'd0;
        ft_pyld_req_head  <= `TD {`P2P_DHEAD_W{1'd0}};
    end
    else if (pbuf_free_valid & pbuf_free_ready) begin
        ft_pyld_req_valid <= `TD 1'd1;
        ft_pyld_req_last  <= `TD pbuf_free_last;
        ft_pyld_req_head  <= `TD pbuf_free_head;
    end
    else if (ft_pyld_req_valid & ft_pyld_req_ready) begin
        ft_pyld_req_valid <= `TD 1'd0;
        ft_pyld_req_last  <= `TD 1'd0;
        ft_pyld_req_head  <= `TD {`P2P_DHEAD_W{1'd0}};
    end
end
/* --------fetch related output{end}-------- */

endmodule
