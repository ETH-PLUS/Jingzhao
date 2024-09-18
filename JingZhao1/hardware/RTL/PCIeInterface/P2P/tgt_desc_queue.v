`timescale 1ns / 100ps
//*************************************************************************
// > File   : tgt_desc_queue.v
// > Author : Kangning
// > Date   : 2022-08-31
// > Note   : descriptor queue, includes descriptor queue && pbuf allocated 
// >          address.
//*************************************************************************

module tgt_desc_queue #(

) (

    input  wire clk  , // i, 1
    input  wire rst_n, // i, 1

    /* --------p2p mem descriptor in{begin}-------- */
    /* p2p_req head. We just write mem descriptor space, and the byte_len is 8 byte aligned
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    input  wire                   p2p_mem_desc_req_valid, // i, 1
    input  wire                   p2p_mem_desc_req_last , // i, 1
    input  wire [`P2P_HEAD_W-1:0] p2p_mem_desc_req_head , // i, `P2P_HEAD_W
    input  wire [`P2P_DATA_W-1:0] p2p_mem_desc_req_data , // i, `P2P_DATA_W
    output wire                   p2p_mem_desc_req_ready, // o, 1
    /* --------p2p mem descriptor in{end}-------- */

    /* --------allocated buffer address{begin}-------- */
    input  wire                       pbuf_alloc_valid   , // i, 1
    input  wire                       pbuf_alloc_last    , // i, 1
    input  wire [`BUF_ADDR_WIDTH-1:0] pbuf_alloc_buf_addr, // i, `BUF_ADDR_WIDTH
    input  wire [8              -1:0] pbuf_alloc_qnum    , // i, 8
    output wire                       pbuf_alloc_ready   , // o, 1 ; assume it always asserts
    /* --------allocated buffer address{end}-------- */

    /* --------dropped queue{begin}-------- */
    output wire                      dropped_wen , // o, 1
    output wire [`QUEUE_NUM_LOG-1:0] dropped_qnum, // o, `QUEUE_NUM_LOG
    /* --------dropped queue{end}-------- */

    /* --------queue struct output for send processing{begin}-------- */
    /* desc_out_head_desc: payload descriptor
     * desc_out_buf_addr : allocated buffer base address in P2P pyld_buf, 
     *                     this is an array. A valid addr outputs when valid
     *                     and ready assert at the same time.
     * desc_out_last     : assert when the last desc_out_buf_addr is asserted
     */
    output wire                         desc_out_valid    , // o, 1
    output wire                         desc_out_last     , // o, 1
    output reg  [`QUEUE_DESC_WIDTH-1:0] desc_out_head_desc, // o, `QUEUE_DESC_WIDTH
    output wire [`QUEUE_NUM_LOG   -1:0] desc_out_head_qnum, // o, `QUEUE_NUM_LOG
    output wire [`BUF_ADDR_WIDTH  -1:0] desc_out_buf_addr , // o, `BUF_ADDR_WIDTH
    input  wire                         desc_out_ready      // i, 1
    /* --------queue struct output for send processing{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [2*`QUEUE_NUM*`SRAM_RW_DATA_W-1:0] rw_data // i, 2*`QUEUE_NUM*`SRAM_RW_DATA_W
	,output wire [`DESC_QUEUE_SIGNAL_W-1:0] dbg_signal // o, `DESC_QUEUE_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

/* --------p2p mem descriptor write{begin}-------- */
wire [`QUEUE_DESC_WIDTH-1:0] desc_data;
wire [`QUEUE_NUM_LOG   -1:0] desc_qnum;
/* --------p2p mem descriptor write{end}-------- */

/* --------queue descriptor{begin}-------- */
wire                         qdesc_0_wen  [`QUEUE_NUM-1:0];
wire [`QUEUE_DESC_WIDTH-1:0] qdesc_0_din  [`QUEUE_NUM-1:0];
wire                         qdesc_0_ren  [`QUEUE_NUM-1:0];
wire [`QUEUE_DESC_WIDTH-1:0] qdesc_0_dout [`QUEUE_NUM-1:0];
wire                         qdesc_0_full [`QUEUE_NUM-1:0];
wire                         qdesc_0_empty[`QUEUE_NUM-1:0];

// queue receive matching
wire [`MSG_BLEN_WIDTH-1:0] byte_len[`QUEUE_NUM-1:0];
reg  [`MSG_BLEN_WIDTH:0] byte_cnt[`QUEUE_NUM-1:0]; // This reg may exceed the length of byte_len
wire is_recved[`QUEUE_NUM-1:0];

wire                         qdesc_1_wen  [`QUEUE_NUM-1:0];
wire [`QUEUE_DESC_WIDTH-1:0] qdesc_1_din  [`QUEUE_NUM-1:0];
wire                         qdesc_1_ren  [`QUEUE_NUM-1:0];
wire [`QUEUE_DESC_WIDTH-1:0] qdesc_1_dout [`QUEUE_NUM-1:0];
wire                         qdesc_1_full [`QUEUE_NUM-1:0];
wire                         qdesc_1_empty[`QUEUE_NUM-1:0];

wire                        alloced_buf_wen  [`QUEUE_NUM-1:0];
wire [`BUF_ADDR_WIDTH-1:0]  alloced_buf_din  [`QUEUE_NUM-1:0];
wire                        alloced_buf_ren  [`QUEUE_NUM-1:0];
wire [`BUF_ADDR_WIDTH-1:0]  alloced_buf_dout [`QUEUE_NUM-1:0];
wire                        alloced_buf_full [`QUEUE_NUM-1:0];
wire                        alloced_buf_empty[`QUEUE_NUM-1:0];

wire is_que_rdy[`QUEUE_NUM-1:0];

wire is_match_succ;
wire [`QUEUE_NUM_LOG-1:0] match_qnum; // Used only when is_nxt_desc_que_out
reg  [`QUEUE_NUM_LOG-1:0] match_qnum_reg; // It is used only in DESC_QUE_OUT state
reg  [`QUEUE_NUM_LOG-1:0] pri_chnl; // The prior selected channel
/* --------queue descriptor{end}-------- */

/* --------queue struct output FSM{begin}-------- */
localparam  IDLE         = 2'b01,
            DESC_QUE_OUT = 2'b10;

reg [1:0] nxt_state;
reg [1:0] cur_state;

wire is_idle, is_desc_que_out;
wire is_nxt_desc_que_out;

reg [`MSG_BLEN_WIDTH-1:0] desc_out_byte_left;
/* --------queue struct output FSM{end}-------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire  [2*`QUEUE_NUM-1:0]  desc_que_rtsel, alloced_buf_rtsel;
wire  [2*`QUEUE_NUM-1:0]  desc_que_wtsel, alloced_buf_wtsel;
wire  [2*`QUEUE_NUM-1:0]  desc_que_ptsel, alloced_buf_ptsel;
wire  [1*`QUEUE_NUM-1:0]  desc_que_vg   , alloced_buf_vg   ;
wire  [1*`QUEUE_NUM-1:0]  desc_que_vs   , alloced_buf_vs   ;
wire  [2-1:0]  qcontext_rtsel;
wire  [2-1:0]  qcontext_wtsel;
wire  [2-1:0]  qcontext_ptsel;
wire  [1-1:0]  qcontext_vg   ;
wire  [1-1:0]  qcontext_vs   ;
/* -------APB reated signal{end}------- */
`endif

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign {
        desc_que_rtsel , 
        desc_que_wtsel , 
        desc_que_ptsel , 
        desc_que_vg    , 
        desc_que_vs    , 
        alloced_buf_rtsel, 
        alloced_buf_wtsel, 
        alloced_buf_ptsel, 
        alloced_buf_vg   , 
        alloced_buf_vs   
} = rw_data;

assign dbg_signal = { // 6312
    
    desc_data, desc_qnum, // 84

    qdesc_0_wen  [0 ], qdesc_0_wen  [1 ], qdesc_0_wen  [2 ], qdesc_0_wen  [3 ], 
    qdesc_0_wen  [4 ], qdesc_0_wen  [5 ], qdesc_0_wen  [6 ], qdesc_0_wen  [7 ], 
    qdesc_0_wen  [8 ], qdesc_0_wen  [9 ], qdesc_0_wen  [10], qdesc_0_wen  [11], 
    qdesc_0_wen  [12], qdesc_0_wen  [13], qdesc_0_wen  [14], qdesc_0_wen  [15], 
    qdesc_0_din  [0 ], qdesc_0_din  [1 ], qdesc_0_din  [2 ], qdesc_0_din  [3 ], 
    qdesc_0_din  [4 ], qdesc_0_din  [5 ], qdesc_0_din  [6 ], qdesc_0_din  [7 ], 
    qdesc_0_din  [8 ], qdesc_0_din  [9 ], qdesc_0_din  [10], qdesc_0_din  [11], 
    qdesc_0_din  [12], qdesc_0_din  [13], qdesc_0_din  [14], qdesc_0_din  [15], 
    qdesc_0_ren  [0 ], qdesc_0_ren  [1 ], qdesc_0_ren  [2 ], qdesc_0_ren  [3 ], 
    qdesc_0_ren  [4 ], qdesc_0_ren  [5 ], qdesc_0_ren  [6 ], qdesc_0_ren  [7 ], 
    qdesc_0_ren  [8 ], qdesc_0_ren  [9 ], qdesc_0_ren  [10], qdesc_0_ren  [11], 
    qdesc_0_ren  [12], qdesc_0_ren  [13], qdesc_0_ren  [14], qdesc_0_ren  [15], 
    qdesc_0_dout [0 ], qdesc_0_dout [1 ], qdesc_0_dout [2 ], qdesc_0_dout [3 ], 
    qdesc_0_dout [4 ], qdesc_0_dout [5 ], qdesc_0_dout [6 ], qdesc_0_dout [7 ], 
    qdesc_0_dout [8 ], qdesc_0_dout [9 ], qdesc_0_dout [10], qdesc_0_dout [11], 
    qdesc_0_dout [12], qdesc_0_dout [13], qdesc_0_dout [14], qdesc_0_dout [15], 
    qdesc_0_full [0 ], qdesc_0_full [1 ], qdesc_0_full [2 ], qdesc_0_full [3 ], 
    qdesc_0_full [4 ], qdesc_0_full [5 ], qdesc_0_full [6 ], qdesc_0_full [7 ], 
    qdesc_0_full [8 ], qdesc_0_full [9 ], qdesc_0_full [10], qdesc_0_full [11], 
    qdesc_0_full [12], qdesc_0_full [13], qdesc_0_full [14], qdesc_0_full [15], 
    qdesc_0_empty[0 ], qdesc_0_empty[1 ], qdesc_0_empty[2 ], qdesc_0_empty[3 ], 
    qdesc_0_empty[4 ], qdesc_0_empty[5 ], qdesc_0_empty[6 ], qdesc_0_empty[7 ], 
    qdesc_0_empty[8 ], qdesc_0_empty[9 ], qdesc_0_empty[10], qdesc_0_empty[11], 
    qdesc_0_empty[12], qdesc_0_empty[13], qdesc_0_empty[14], qdesc_0_empty[15], // 2624

    byte_len[0 ], byte_len[1 ], byte_len[2 ], byte_len[3 ], 
    byte_len[4 ], byte_len[5 ], byte_len[6 ], byte_len[7 ], 
    byte_len[8 ], byte_len[9 ], byte_len[10], byte_len[11], 
    byte_len[12], byte_len[13], byte_len[14], byte_len[15], 
    byte_cnt[0 ], byte_cnt[1 ], byte_cnt[2 ], byte_cnt[3 ], 
    byte_cnt[4 ], byte_cnt[5 ], byte_cnt[6 ], byte_cnt[7 ], 
    byte_cnt[8 ], byte_cnt[9 ], byte_cnt[10], byte_cnt[11], 
    byte_cnt[12], byte_cnt[13], byte_cnt[14], byte_cnt[15], // 528

    is_recved[0], is_recved[0], is_recved[0], is_recved[0], 
    is_recved[0], is_recved[0], is_recved[0], is_recved[0], 
    is_recved[0], is_recved[0], is_recved[0], is_recved[0], 
    is_recved[0], is_recved[0], is_recved[0], is_recved[0], // 16

    qdesc_1_wen  [0 ], qdesc_1_wen  [1 ], qdesc_1_wen  [2 ], qdesc_1_wen  [3 ], 
    qdesc_1_wen  [4 ], qdesc_1_wen  [5 ], qdesc_1_wen  [6 ], qdesc_1_wen  [7 ], 
    qdesc_1_wen  [8 ], qdesc_1_wen  [9 ], qdesc_1_wen  [10], qdesc_1_wen  [11], 
    qdesc_1_wen  [12], qdesc_1_wen  [13], qdesc_1_wen  [14], qdesc_1_wen  [15], 
    qdesc_1_din  [0 ], qdesc_1_din  [1 ], qdesc_1_din  [2 ], qdesc_1_din  [3 ], 
    qdesc_1_din  [4 ], qdesc_1_din  [5 ], qdesc_1_din  [6 ], qdesc_1_din  [7 ], 
    qdesc_1_din  [8 ], qdesc_1_din  [9 ], qdesc_1_din  [10], qdesc_1_din  [11], 
    qdesc_1_din  [12], qdesc_1_din  [13], qdesc_1_din  [14], qdesc_1_din  [15], 
    qdesc_1_ren  [0 ], qdesc_1_ren  [1 ], qdesc_1_ren  [2 ], qdesc_1_ren  [3 ], 
    qdesc_1_ren  [4 ], qdesc_1_ren  [5 ], qdesc_1_ren  [6 ], qdesc_1_ren  [7 ], 
    qdesc_1_ren  [8 ], qdesc_1_ren  [9 ], qdesc_1_ren  [10], qdesc_1_ren  [11], 
    qdesc_1_ren  [12], qdesc_1_ren  [13], qdesc_1_ren  [14], qdesc_1_ren  [15], 
    qdesc_1_dout [0 ], qdesc_1_dout [1 ], qdesc_1_dout [2 ], qdesc_1_dout [3 ], 
    qdesc_1_dout [4 ], qdesc_1_dout [5 ], qdesc_1_dout [6 ], qdesc_1_dout [7 ], 
    qdesc_1_dout [8 ], qdesc_1_dout [9 ], qdesc_1_dout [10], qdesc_1_dout [11], 
    qdesc_1_dout [12], qdesc_1_dout [13], qdesc_1_dout [14], qdesc_1_dout [15], 
    qdesc_1_full [0 ], qdesc_1_full [1 ], qdesc_1_full [2 ], qdesc_1_full [3 ], 
    qdesc_1_full [4 ], qdesc_1_full [5 ], qdesc_1_full [6 ], qdesc_1_full [7 ], 
    qdesc_1_full [8 ], qdesc_1_full [9 ], qdesc_1_full [10], qdesc_1_full [11], 
    qdesc_1_full [12], qdesc_1_full [13], qdesc_1_full [14], qdesc_1_full [15], 
    qdesc_1_empty[0 ], qdesc_1_empty[1 ], qdesc_1_empty[2 ], qdesc_1_empty[3 ], 
    qdesc_1_empty[4 ], qdesc_1_empty[5 ], qdesc_1_empty[6 ], qdesc_1_empty[7 ], 
    qdesc_1_empty[8 ], qdesc_1_empty[9 ], qdesc_1_empty[10], qdesc_1_empty[11], 
    qdesc_1_empty[12], qdesc_1_empty[13], qdesc_1_empty[14], qdesc_1_empty[15], // 2624

    alloced_buf_wen  [0 ], alloced_buf_wen  [1 ], alloced_buf_wen  [2 ], alloced_buf_wen  [3 ], 
    alloced_buf_wen  [4 ], alloced_buf_wen  [5 ], alloced_buf_wen  [6 ], alloced_buf_wen  [7 ], 
    alloced_buf_wen  [8 ], alloced_buf_wen  [9 ], alloced_buf_wen  [10], alloced_buf_wen  [11], 
    alloced_buf_wen  [12], alloced_buf_wen  [13], alloced_buf_wen  [14], alloced_buf_wen  [15], 
    alloced_buf_din  [0 ], alloced_buf_din  [1 ], alloced_buf_din  [2 ], alloced_buf_din  [3 ], 
    alloced_buf_din  [4 ], alloced_buf_din  [5 ], alloced_buf_din  [6 ], alloced_buf_din  [7 ], 
    alloced_buf_din  [8 ], alloced_buf_din  [9 ], alloced_buf_din  [10], alloced_buf_din  [11], 
    alloced_buf_din  [12], alloced_buf_din  [13], alloced_buf_din  [14], alloced_buf_din  [15], 
    alloced_buf_ren  [0 ], alloced_buf_ren  [1 ], alloced_buf_ren  [2 ], alloced_buf_ren  [3 ], 
    alloced_buf_ren  [4 ], alloced_buf_ren  [5 ], alloced_buf_ren  [6 ], alloced_buf_ren  [7 ], 
    alloced_buf_ren  [8 ], alloced_buf_ren  [9 ], alloced_buf_ren  [10], alloced_buf_ren  [11], 
    alloced_buf_ren  [12], alloced_buf_ren  [13], alloced_buf_ren  [14], alloced_buf_ren  [15], 
    alloced_buf_dout [0 ], alloced_buf_dout [1 ], alloced_buf_dout [2 ], alloced_buf_dout [3 ], 
    alloced_buf_dout [4 ], alloced_buf_dout [5 ], alloced_buf_dout [6 ], alloced_buf_dout [7 ], 
    alloced_buf_dout [8 ], alloced_buf_dout [9 ], alloced_buf_dout [10], alloced_buf_dout [11], 
    alloced_buf_dout [12], alloced_buf_dout [13], alloced_buf_dout [14], alloced_buf_dout [15], 
    alloced_buf_full [0 ], alloced_buf_full [1 ], alloced_buf_full [2 ], alloced_buf_full [3 ], 
    alloced_buf_full [4 ], alloced_buf_full [5 ], alloced_buf_full [6 ], alloced_buf_full [7 ], 
    alloced_buf_full [8 ], alloced_buf_full [9 ], alloced_buf_full [10], alloced_buf_full [11], 
    alloced_buf_full [12], alloced_buf_full [13], alloced_buf_full [14], alloced_buf_full [15], 
    alloced_buf_empty[0 ], alloced_buf_empty[1 ], alloced_buf_empty[2 ], alloced_buf_empty[3 ], 
    alloced_buf_empty[4 ], alloced_buf_empty[5 ], alloced_buf_empty[6 ], alloced_buf_empty[7 ], 
    alloced_buf_empty[8 ], alloced_buf_empty[9 ], alloced_buf_empty[10], alloced_buf_empty[11], 
    alloced_buf_empty[12], alloced_buf_empty[13], alloced_buf_empty[14], alloced_buf_empty[15], // 384

    is_que_rdy[0 ], is_que_rdy[1 ], is_que_rdy[2 ], is_que_rdy[3 ], 
    is_que_rdy[4 ], is_que_rdy[5 ], is_que_rdy[6 ], is_que_rdy[7 ], 
    is_que_rdy[8 ], is_que_rdy[9 ], is_que_rdy[10], is_que_rdy[11], 
    is_que_rdy[12], is_que_rdy[13], is_que_rdy[14], is_que_rdy[15], // 16

    is_match_succ, match_qnum, match_qnum_reg, pri_chnl, // 13

    nxt_state, cur_state, // 4
    is_idle, is_desc_que_out, is_nxt_desc_que_out, // 3
    desc_out_byte_left // 16
};
/* -------APB reated signal{end}------- */
`endif

/* --------queue descriptor{begin}-------- */
assign p2p_mem_desc_req_ready = !qdesc_0_full[desc_qnum];

genvar i;
generate
for (i = 0; i < `QUEUE_NUM; i = i + 1) begin: DESC_QUE // 16 pass

    // -------------------Input descriptor queue------------------------------- //
    pcieifc_sync_fifo #(
        .DSIZE ( `QUEUE_DESC_WIDTH ), // 80
        .ASIZE ( `PBUF_NUM_LOG - 1 )  // 9
    ) desc_que_0 (
        .clk   ( clk   ),
        .rst_n ( rst_n ),
        .clr   ( 1'd0  ),
        
        .wen    ( qdesc_0_wen [i] ),
        .din    ( qdesc_0_din [i] ),
        
        .ren    ( qdesc_0_ren [i] ),
        .dout   ( qdesc_0_dout[i] ),
        
        .full   ( qdesc_0_full [i] ),
        .empty  ( qdesc_0_empty[i] )

    `ifdef PCIEI_APB_DBG
        ,.rtsel ( desc_que_rtsel[(i+1)*2-1:i*2] )  // i, 2
        ,.wtsel ( desc_que_wtsel[(i+1)*2-1:i*2] )  // i, 2
        ,.ptsel ( desc_que_ptsel[(i+1)*2-1:i*2] )  // i, 2
        ,.vg    ( desc_que_vg   [i] )  // i, 1
        ,.vs    ( desc_que_vs   [i] )  // i, 1
    `endif
    );
    assign qdesc_0_wen[i] = (desc_qnum == i) & p2p_mem_desc_req_valid & p2p_mem_desc_req_ready;
    assign qdesc_0_din[i] = qdesc_0_wen[i] ? desc_data : 0;

    assign qdesc_0_ren[i] = is_recved[i] & !qdesc_1_full[i];
    // ---------------------------------------------------------- //

    // ---------------------receive matching-------------------------------- //
    assign byte_len[i] = (qdesc_0_dout[i] >> 32) & 16'hFFFF;
    always @(posedge clk, negedge rst_n) begin
        if (~rst_n) begin
            byte_cnt[i] <= `TD 0;
        end
        else if ((byte_cnt[i] >= byte_len[i]) & (!qdesc_1_full[i])) begin
            byte_cnt[i] <= `TD 0;
        end
        else if (pbuf_alloc_valid & pbuf_alloc_ready) begin
            byte_cnt[i] <= `TD byte_cnt[i] + ((pbuf_alloc_qnum == i) ? `PBUF_BLOCK_SZ : 0);
        end
    end
    
    assign is_recved[i] = (byte_cnt[i] >= byte_len[i]) & !qdesc_0_empty[i];
    // --------------------------------------------------------------------- //

    // ---------------------Input descriptor queue {begin}-------------------------- //
    pcieifc_sync_fifo #(
        .DSIZE ( `QUEUE_DESC_WIDTH ), // 80
        .ASIZE ( `PBUF_NUM_LOG - 1 )  // 9
    ) desc_que_1 (
        .clk   ( clk   ),
        .rst_n ( rst_n ),
        .clr   ( 1'd0  ),
        
        .wen    ( qdesc_1_wen [i] ),
        .din    ( qdesc_1_din [i] ),
        
        .ren    ( qdesc_1_ren [i] ),
        .dout   ( qdesc_1_dout[i] ),
        
        .full   ( qdesc_1_full [i] ),
        .empty  ( qdesc_1_empty[i] )

    `ifdef PCIEI_APB_DBG
        ,.rtsel ( desc_que_rtsel[(i+1)*2-1:i*2] )  // i, 2
        ,.wtsel ( desc_que_wtsel[(i+1)*2-1:i*2] )  // i, 2
        ,.ptsel ( desc_que_ptsel[(i+1)*2-1:i*2] )  // i, 2
        ,.vg    ( desc_que_vg   [i] )  // i, 1
        ,.vs    ( desc_que_vs   [i] )  // i, 1
    `endif
    );
    assign qdesc_1_wen[i] = qdesc_0_ren[i];
    assign qdesc_1_din[i] = qdesc_0_dout[i];

    assign qdesc_1_ren[i] = (match_qnum == i) & is_nxt_desc_que_out;
    // ---------------------Input descriptor queue {end}-------------------------- //

    pcieifc_sync_fifo #(
        .DSIZE ( `BUF_ADDR_WIDTH ), // 10
        .ASIZE ( `PBUF_NUM_LOG   )  // 10
    ) alloced_buf_list (
        .clk   ( clk   ),
        .rst_n ( rst_n ),
        .clr   ( 1'd0  ),
        
        .wen    ( alloced_buf_wen[i]  ),
        .din    ( alloced_buf_din[i]  ),
        
        .ren    ( alloced_buf_ren [i] ),
        .dout   ( alloced_buf_dout[i] ),
        
        .full   ( alloced_buf_full [i] ),
        .empty  ( alloced_buf_empty[i] )
    
    `ifdef PCIEI_APB_DBG
        ,.rtsel ( alloced_buf_rtsel[(i+1)*2-1:i*2] )  // i, 2
        ,.wtsel ( alloced_buf_wtsel[(i+1)*2-1:i*2] )  // i, 2
        ,.ptsel ( alloced_buf_ptsel[(i+1)*2-1:i*2] )  // i, 2
        ,.vg    ( alloced_buf_vg   [i] )  // i, 1
        ,.vs    ( alloced_buf_vs   [i] )  // i, 1
    `endif
    );
    assign alloced_buf_wen[i] = (pbuf_alloc_qnum == i) & pbuf_alloc_valid;
    assign alloced_buf_din[i] = pbuf_alloc_buf_addr;

    assign alloced_buf_ren[i] = (match_qnum_reg == i) & is_desc_que_out & desc_out_valid & desc_out_ready;

    assign is_que_rdy[i] = !qdesc_1_empty[i] & !alloced_buf_empty[i];
        
end
endgenerate

// -> input descriptor queue
assign desc_data = p2p_mem_desc_req_data[127:0];
assign desc_qnum = (p2p_mem_desc_req_head[63:32] & 18'h3FFFF) >> 14;

// input descriptor -> output descriptor queue
assign pbuf_alloc_ready = !alloced_buf_full[pbuf_alloc_qnum] & !qdesc_1_full[pbuf_alloc_qnum];

// output descriptor queue ->
generate
if (`QUEUE_NUM_LOG == 4) begin: QUEUE16 // 16 queue
    assign is_match_succ =  is_que_rdy[0 ] | is_que_rdy[1 ] | is_que_rdy[2 ] | is_que_rdy[3 ] |
                            is_que_rdy[4 ] | is_que_rdy[5 ] | is_que_rdy[6 ] | is_que_rdy[7 ] |
                            is_que_rdy[8 ] | is_que_rdy[9 ] | is_que_rdy[10] | is_que_rdy[11] |
                            is_que_rdy[12] | is_que_rdy[13] | is_que_rdy[14] | is_que_rdy[15];

    assign match_qnum = is_que_rdy[(pri_chnl      ) & 4'hF] ? (pri_chnl      ) & 4'hF: is_que_rdy[(pri_chnl+4'd1 ) & 4'hF] ? (pri_chnl+4'd1 ) & 4'hF: 
                        is_que_rdy[(pri_chnl+4'd2 ) & 4'hF] ? (pri_chnl+4'd2 ) & 4'hF: is_que_rdy[(pri_chnl+4'd3 ) & 4'hF] ? (pri_chnl+4'd3 ) & 4'hF:
                        is_que_rdy[(pri_chnl+4'd4 ) & 4'hF] ? (pri_chnl+4'd4 ) & 4'hF: is_que_rdy[(pri_chnl+4'd5 ) & 4'hF] ? (pri_chnl+4'd5 ) & 4'hF: 
                        is_que_rdy[(pri_chnl+4'd6 ) & 4'hF] ? (pri_chnl+4'd6 ) & 4'hF: is_que_rdy[(pri_chnl+4'd7 ) & 4'hF] ? (pri_chnl+4'd7 ) & 4'hF: 
                        is_que_rdy[(pri_chnl+4'd8 ) & 4'hF] ? (pri_chnl+4'd8 ) & 4'hF: is_que_rdy[(pri_chnl+4'd9 ) & 4'hF] ? (pri_chnl+4'd9 ) & 4'hF: 
                        is_que_rdy[(pri_chnl+4'd10) & 4'hF] ? (pri_chnl+4'd10) & 4'hF: is_que_rdy[(pri_chnl+4'd11) & 4'hF] ? (pri_chnl+4'd11) & 4'hF: 
                        is_que_rdy[(pri_chnl+4'd12) & 4'hF] ? (pri_chnl+4'd12) & 4'hF: is_que_rdy[(pri_chnl+4'd13) & 4'hF] ? (pri_chnl+4'd13) & 4'hF: 
                        is_que_rdy[(pri_chnl+4'd14) & 4'hF] ? (pri_chnl+4'd14) & 4'hF: is_que_rdy[(pri_chnl+4'd15) & 4'hF] ? (pri_chnl+4'd15) & 4'hF: 0;
end
endgenerate
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        match_qnum_reg <= `TD 0;
    end
    else if (is_match_succ & is_nxt_desc_que_out) begin
        match_qnum_reg <= `TD match_qnum;
    end
end

always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        pri_chnl <= `TD 0;
    end
    else if (is_match_succ & is_nxt_desc_que_out) begin
        pri_chnl <= `TD pri_chnl + 1;
    end
end

// dropped queue
assign dropped_wen  = p2p_mem_desc_req_valid & p2p_mem_desc_req_ready;
assign dropped_qnum = (p2p_mem_desc_req_head[63:32] & 18'h3FFFF) >> 14;
/* --------queue descriptor{end}-------- */

/* --------descriptor queue output FSM{begin}-------- */
/******************** Stage 1: State Register **********************/
assign is_idle         = (cur_state == IDLE        );
assign is_desc_que_out = (cur_state == DESC_QUE_OUT);
assign is_nxt_desc_que_out = (is_idle || (is_desc_que_out & desc_out_valid & desc_out_ready & desc_out_last)) & is_match_succ;

always @(posedge clk, negedge rst_n) begin
    if(~rst_n)
        cur_state <= `TD IDLE;
    else
        cur_state <= `TD nxt_state;
end

/******************** Stage 2: State Transition **********************/
always @(*) begin
    case(cur_state)
        IDLE: begin
            if (is_match_succ) begin
                nxt_state = DESC_QUE_OUT;
            end
            else begin
                nxt_state = IDLE;
            end
        end
        DESC_QUE_OUT: begin
            if (desc_out_valid & desc_out_ready & desc_out_last) begin
                if (is_match_succ) begin
                    nxt_state = DESC_QUE_OUT;
                end
                else begin
                    nxt_state = IDLE;
                end
            end
            else begin
                nxt_state = DESC_QUE_OUT;
            end
        end
        default: begin
            nxt_state = IDLE;
        end
    endcase
end
/******************** Stage 3: Output **********************/
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        desc_out_byte_left <= `TD 0;
    end
    else if (is_nxt_desc_que_out) begin
        desc_out_byte_left <= `TD (qdesc_1_dout[match_qnum] >> 32) & 16'hFFFF;
    end
    else if (is_desc_que_out & desc_out_valid & desc_out_ready & desc_out_last) begin
        desc_out_byte_left <= `TD 0;
    end
    else if (is_desc_que_out & desc_out_valid & desc_out_ready) begin
        desc_out_byte_left <= `TD desc_out_byte_left - `PBUF_BLOCK_SZ;
    end
end

always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        desc_out_head_desc <= `TD 0;
    end
    else if (is_nxt_desc_que_out) begin
        desc_out_head_desc <= `TD qdesc_1_dout[match_qnum];
    end
    else if (is_idle) begin
        desc_out_head_desc <= `TD 0;
    end
end

assign desc_out_valid     = is_desc_que_out & !alloced_buf_empty[match_qnum_reg];
assign desc_out_last      = desc_out_valid ? (desc_out_byte_left <= `PBUF_BLOCK_SZ) : 1'd0;
assign desc_out_head_qnum = match_qnum_reg;
assign desc_out_buf_addr  = alloced_buf_dout[match_qnum_reg];
/* --------descriptor queue output FSM{begin}-------- */

endmodule
