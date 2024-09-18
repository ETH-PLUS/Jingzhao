`timescale 1ns / 100ps
//*************************************************************************
// > File   : tgt_queue_struct.v
// > Author : Kangning
// > Date   : 2022-08-31
// > Note   : queue structure
//*************************************************************************

module tgt_queue_struct #(
    
) (

    input  wire clk     , // i, 1
    input  wire rst_n   , // i, 1
    // output reg  init_end, // o, 1

    /* --------P2P Configuration Channel{begin}-------- */
    /* p2p_req head. We just write configuration space, and the byte_len is fixed to 8 bytes
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    input  wire                       p2p_cfg_req_valid, // i, 1
    input  wire                       p2p_cfg_req_last , // i, 1
    input  wire [`P2P_HEAD_W - 1 : 0] p2p_cfg_req_head , // i, `P2P_HEAD_W
    input  wire [`P2P_DATA_W - 1 : 0] p2p_cfg_req_data , // i, `P2P_DATA_W
    output wire                       p2p_cfg_req_ready, // o, 1
    
    // output wire                       p2p_cfg_rrsp_valid, // o, 1
    // output wire                       p2p_cfg_rrsp_last , // o, 1
    // output wire [`P2P_DATA_W - 1 : 0] p2p_cfg_rrsp_data , // o, `P2P_DATA_W
    // input  wire                       p2p_cfg_rrsp_ready, // i, 1
    /* --------P2P Configuration Channel{end}-------- */

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
    /* st_qstruct_head_ctx : qcontext of prepared queue
     * st_qstruct_head_desc: payload descriptor
     * st_qstruct_buf_addr : allocated buffer base address in P2P pyld_buf, 
     *                       this is an array. A valid addr outputs when valid
     *                       and ready assert at the same time.
     * st_qstruct_last     : assert when the last st_qstruct_buf_addr is asserted
     */
    output wire                            st_qstruct_valid    , // o, 1
    output wire                            st_qstruct_last     , // o, 1
    output wire [`QUEUE_CONTEXT_WIDTH-1:0] st_qstruct_head_ctx , // o, `QUEUE_CONTEXT_WIDTH
    output wire [`QUEUE_DESC_WIDTH   -1:0] st_qstruct_head_desc, // o, `QUEUE_DESC_WIDTH
    output wire [`BUF_ADDR_WIDTH     -1:0] st_qstruct_buf_addr , // o, `BUF_ADDR_WIDTH
    input  wire                            st_qstruct_ready      // i, 1
    /* --------queue struct output for send processing{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [(2*`QUEUE_NUM+1)*`SRAM_RW_DATA_W-1:0] rw_data // i, (2*`QUEUE_NUM+1)*`SRAM_RW_DATA_W
    ,output  wire [`TGT_QSTRUCT_SIGNAL_W-1:0] dbg_signal // o, `TGT_QSTRUCT_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

localparam QCTX_BYTE_LEN_LOG = 4; // byte len of one entry of target configure bar space, in log format

/* --------Queue context, cfg BAR space{begin}-------- */
wire [31:0] bar_cfg_addr;

wire                            qcontext_wen  ;
wire [`QUEUE_NUM_LOG      -1:0] qcontext_waddr;
wire [`QUEUE_CONTEXT_WIDTH-1:0] qcontext_din  ;
wire                            qcontext_ren  ;
wire [`QUEUE_NUM_LOG      -1:0] qcontext_raddr;
wire [`QUEUE_CONTEXT_WIDTH-1:0] qcontext_dout ;
/* --------Queue context, cfg BAR space{end}-------- */

/* --------qstruct out{end}-------- */
reg qstruct_sop;

wire                         qstruct_valid    ;
wire                         qstruct_last     ;
wire [`QUEUE_DESC_WIDTH-1:0] qstruct_head_desc;
wire [`QUEUE_NUM_LOG   -1:0] qstruct_head_qnum;
wire [`BUF_ADDR_WIDTH  -1:0] qstruct_buf_addr ;
wire                         qstruct_ready    ;
/* --------qstruct out{end}-------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire  [2*`QUEUE_NUM*`SRAM_RW_DATA_W-1:0] desc_que_rw_data;
wire  [2-1:0]  qcontext_rtsel;
wire  [2-1:0]  qcontext_wtsel;
wire  [2-1:0]  qcontext_ptsel;
wire  [1-1:0]  qcontext_vg   ;
wire  [1-1:0]  qcontext_vs   ;

wire [`QSTRUCT_TOP_SIGNAL_W-1:0] dbg_signal_qstruct_top;
wire [`DESC_QUEUE_SIGNAL_W -1:0] dbg_signal_desc_queue;
/* -------APB reated signal{end}------- */
`endif

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign {
        desc_que_rw_data, 
        qcontext_rtsel  ,
        qcontext_wtsel  ,
        qcontext_ptsel  ,
        qcontext_vg     ,
        qcontext_vs     
} = rw_data;

assign dbg_signal = {
    dbg_signal_qstruct_top, 
    dbg_signal_desc_queue
};

assign dbg_signal_qstruct_top = { // 268
    
    bar_cfg_addr, // 32
    qcontext_wen, qcontext_waddr, qcontext_din, qcontext_ren, qcontext_raddr, qcontext_dout, // 138
    qstruct_sop, // 1
    qstruct_valid, qstruct_last, qstruct_head_desc, qstruct_head_qnum, qstruct_buf_addr, qstruct_ready // 97
};
/* -------APB reated signal{end}------- */
`endif

/* --------Queue context, cfg BAR space{begin}-------- */
assign bar_cfg_addr = p2p_cfg_req_head[63:32];

pcieifc_sd_sram #(
    .DATAWIDTH ( `QUEUE_CONTEXT_WIDTH ), // Memory data word width, 64
    .ADDRWIDTH ( `QUEUE_NUM_LOG       )  // Number of mem address bits, 4
) qcontext (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    .wea   ( qcontext_wen   ), // i, 1
    .addra ( qcontext_waddr ), // i, ADDRWIDTH
    .dina  ( qcontext_din   ), // i, DATAWIDTH

    .reb   ( qcontext_ren   ), // i, 1
    .addrb ( qcontext_raddr ), // i, ADDRWIDTH
    .doutb ( qcontext_dout  )  // o, DATAWIDTH

`ifdef PCIEI_APB_DBG
    ,.rtsel ( 2'b0 )  // i, 2
    ,.wtsel ( 2'b0 )  // i, 2
    ,.ptsel ( 2'b0 )  // i, 2
    ,.vg    ( 1'b0 )  // i, 1
    ,.vs    ( 1'b0 )  // i, 1
`endif
);

assign qcontext_wen   = p2p_cfg_req_valid;
assign qcontext_waddr = (bar_cfg_addr[19:0] - `CFG_BAR_TGT_ADDR_BASE) >> QCTX_BYTE_LEN_LOG;
assign qcontext_din   = p2p_cfg_req_data;

assign qcontext_ren   = qstruct_sop & qstruct_valid & qstruct_ready;
assign qcontext_raddr = qcontext_ren ? qstruct_head_qnum : 0;
/* --------Queue context, cfg BAR space{end}-------- */

/* --------Descriptor queue{begin}-------- */
tgt_desc_queue #(

) tgt_desc_queue (

    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* --------p2p mem descriptor in{begin}-------- */
    .p2p_mem_desc_req_valid ( p2p_mem_desc_req_valid ), // i, 1
    .p2p_mem_desc_req_last  ( p2p_mem_desc_req_last  ), // i, 1
    .p2p_mem_desc_req_data  ( p2p_mem_desc_req_data  ), // i, `P2P_DATA_W
    .p2p_mem_desc_req_head  ( p2p_mem_desc_req_head  ), // i, `P2P_HEAD_W
    .p2p_mem_desc_req_ready ( p2p_mem_desc_req_ready ), // o, 1
    /* --------p2p mem descriptor in{end}-------- */

    /* --------allocated buffer address{begin}-------- */
    .pbuf_alloc_valid    ( pbuf_alloc_valid    ), // i, 1
    .pbuf_alloc_last     ( pbuf_alloc_last     ), // i, 1
    .pbuf_alloc_buf_addr ( pbuf_alloc_buf_addr ), // i, 32
    .pbuf_alloc_qnum     ( pbuf_alloc_qnum     ), // i, 8
    .pbuf_alloc_ready    ( pbuf_alloc_ready    ), // o, 1
    /* --------allocated buffer address{end}-------- */

    /* --------dropped queue{begin}-------- */
    .dropped_wen        ( dropped_wen  ), // o, 1
    .dropped_qnum       ( dropped_qnum ), // o, `QUEUE_NUM_LOG
    /* --------dropped queue{end}-------- */

    /* --------queue struct output for send processing{begin}-------- */
    /* st_qstruct_head_desc: payload descriptor
     * st_qstruct_buf_addr : allocated buffer base address in P2P pyld_buf, 
     *                       this is an array. A valid addr outputs when valid
     *                       and ready assert at the same time.
     * st_qstruct_last     : assert when the last st_qstruct_buf_addr is asserted
     */
    .desc_out_valid     ( qstruct_valid     ), // o, 1
    .desc_out_last      ( qstruct_last      ), // o, 1
    .desc_out_head_desc ( qstruct_head_desc ), // o, `QUEUE_DESC_WIDTH
    .desc_out_head_qnum ( qstruct_head_qnum ), // o, `QUEUE_NUM_LOG
    .desc_out_buf_addr  ( qstruct_buf_addr  ), // o, `BUF_ADDR_WIDTH
    .desc_out_ready     ( qstruct_ready     )  // i, 1
    /* --------queue struct output for send processing{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.rw_data            ( desc_que_rw_data      ) // i, 2*`QUEUE_NUM*`SRAM_RW_DATA_W
	,.dbg_signal         ( dbg_signal_desc_queue ) // o, `DESC_QUEUE_SIGNAL_W
	/* -------APB reated signal{end}------- */
`endif
);
/* --------Descriptor queue{end}-------- */

/* --------P2P Configuration Channel{begin}-------- */
assign p2p_cfg_req_ready = 1;
/* --------P2P Configuration Channel{end}-------- */

/* --------qstruct out{begin}-------- */
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        qstruct_sop <= `TD 1'd1;
    end
    else if (qstruct_valid & qstruct_ready & qstruct_last) begin
        qstruct_sop <= `TD 1'd0;
    end
    else if (qstruct_valid & qstruct_ready) begin
        qstruct_sop <= `TD 1'd1;
    end
end

// read queue context
assign st_qstruct_head_ctx = qcontext_dout;
st_reg #(
    .TUSER_WIDTH ( `QUEUE_DESC_WIDTH ),
    .TDATA_WIDTH ( `BUF_ADDR_WIDTH   ) 
) st_reg2send (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* -------input axis-like interface{begin}------- */
    /* qstruct_head_desc: payload descriptor
     * qstruct_buf_addr : allocated buffer base address in P2P pyld_buf, 
     *                    this is an array. A valid addr outputs when valid
     *                    and ready assert at the same time.
     * qstruct_last     : assert when the last qstruct_buf_addr is asserted
     */
    .axis_tvalid ( qstruct_valid ), // i, 1
    .axis_tlast  ( qstruct_last  ), // i, 1
    .axis_tuser  ( qstruct_head_desc ), // i, TUSER_WIDTH
    .axis_tdata  ( qstruct_buf_addr ), // i, TDATA_WIDTH
    .axis_tready ( qstruct_ready    ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    /* qstruct_head_desc: payload descriptor
     * qstruct_buf_addr : allocated buffer base address in P2P pyld_buf, 
     *                    this is an array. A valid addr outputs when valid
     *                    and ready assert at the same time.
     * qstruct_last     : assert when the last qstruct_buf_addr is asserted
     */
    .axis_reg_tvalid ( st_qstruct_valid ), // o, 1  // read valid from input register
    .axis_reg_tlast  ( st_qstruct_last  ), // o, 1 
    .axis_reg_tuser  ( st_qstruct_head_desc ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( st_qstruct_buf_addr ), // o, TDATA_WIDTH
    .axis_reg_tready ( st_qstruct_ready    )  // i, 1
    /* -------output in_reg inteface{end}------- */
);
/* --------qstruct out{end}-------- */

endmodule
