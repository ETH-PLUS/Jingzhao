`timescale 1ns / 100ps
//*************************************************************************
// > File   : p2p_target.v
// > Author : Kangning
// > Date   : 2022-06-10
// > Note   : DMA P2P target
//*************************************************************************


module p2p_target #(
    
) (
    input  wire clk     , // i, 1
    input  wire rst_n   , // i, 1
    output wire init_end, // o, 1
    
    /* --------P2P Configuration Channel{begin}-------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    input  wire                       p2p_cfg_req_valid, // i, 1
    input  wire                       p2p_cfg_req_last , // i, 1
    input  wire [`P2P_DATA_W - 1 : 0] p2p_cfg_req_data , // i, `P2P_DATA_W
    input  wire [`P2P_HEAD_W - 1 : 0] p2p_cfg_req_head , // i, `P2P_HEAD_W
    output wire                       p2p_cfg_req_ready, // o, 1
    
    // output wire                          p2p_cfg_rrsp_valid, // o, 1
    // output wire                          p2p_cfg_rrsp_last , // o, 1
    // output wire [`P2P_DATA_W - 1 : 0] p2p_cfg_rrsp_data , // o, `P2P_DATA_W
    // input  wire                          p2p_cfg_rrsp_ready, // i, 1
    /* --------P2P Configuration Channel{end}-------- */

    /* -------P2P Stream Channel{begin}-------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    input  wire                       p2p_mem_req_valid, // i, 1  
    input  wire                       p2p_mem_req_last , // i, 1  
    input  wire [`P2P_DATA_W - 1 : 0] p2p_mem_req_data , // i, `P2P_DATA_W
    input  wire [`P2P_HEAD_W - 1 : 0] p2p_mem_req_head , // i, `P2P_HEAD_W
    output wire                       p2p_mem_req_ready, // o, 1  
    /* -------P2P Stream Channel{end}-------- */

    /* --------p2p forward down channel{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved |dst_dev| src_dev | Reserved | Byte length |
     * |  63:-    | 47:40 |  39:32  |  31:16   |    15:0     |
     */
    output wire                        p2p_down_valid, // o, 1              
    output wire                        p2p_down_last , // o, 1              
    output wire [`P2P_DATA_W  - 1 : 0] p2p_down_data , // o, `P2P_DATA_W  
    output wire [`P2P_DHEAD_W - 1 : 0] p2p_down_head , // o, `P2P_DHEAD_W
    input  wire                        p2p_down_ready  // i, 1              
    /* --------p2p forward down channel{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [(2*`QUEUE_NUM+3)*`SRAM_RW_DATA_W-1:0] rw_data // i, (2*`QUEUE_NUM+3)*`SRAM_RW_DATA_W
    ,input  wire [31:0] dbg_sel // i, 32
    ,output wire [31:0] dbg_bus // o, 32
    /* -------APB reated signal{end}------- */
`endif
);

/* -------- Related to demux {begin}-------- */
/* p2p_req head
 * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
 * | is_wr | Reserved | addr  | Reserved | byte_len |
 */
wire                       st_reg_p2p_mem_req_valid;
wire                       st_reg_p2p_mem_req_last ;
wire [`P2P_HEAD_W - 1 : 0] st_reg_p2p_mem_req_head ;
wire [`P2P_DATA_W - 1 : 0] st_reg_p2p_mem_req_data ;
wire                       st_reg_p2p_mem_req_ready;

wire [31:0] mem_addr;
wire [7 :0] nxt_chnl_sel;
/* -------- Related to demux {end}-------- */

wire                   p2p_mem_desc_req_valid, p2p_mem_pyld_req_valid, st0_p2p_pyld_req_valid;
wire                   p2p_mem_desc_req_last , p2p_mem_pyld_req_last , st0_p2p_pyld_req_last ;
wire [`P2P_HEAD_W-1:0] p2p_mem_desc_req_head , p2p_mem_pyld_req_head , st0_p2p_pyld_req_head ;
wire [`P2P_DATA_W-1:0] p2p_mem_desc_req_data , p2p_mem_pyld_req_data , st0_p2p_pyld_req_data ;
wire                   p2p_mem_desc_req_ready, p2p_mem_pyld_req_ready, st0_p2p_pyld_req_ready;

/* --------Next mem payload{begin}-------- */
wire             nxt_valid;
wire [7:0]       nxt_qnum ;
/* --------Next mem payload{end}-------- */

/* --------dropped queue{begin}-------- */
wire                      dropped_wen ;
wire [`QUEUE_NUM_LOG-1:0] dropped_qnum;
/* --------dropped queue{end}-------- */

/* --------p2p mem payload store{begin}-------- */
wire                        st_pyld_req_valid ;
wire                        st_pyld_req_last  ;
wire [`MSG_BLEN_WIDTH-1:0]  st_pyld_req_blen  ;
wire [8              -1:0]  st_pyld_req_qnum  ;
wire [`P2P_DATA_W    -1:0]  st_pyld_req_data  ;
wire                        st_pyld_req_ready ;
/* --------p2p mem payload store{begin}-------- */

/* --------allocated buffer address{begin}-------- */
wire                       pbuf_alloc_valid   ;
wire                       pbuf_alloc_last    ;
wire [`BUF_ADDR_WIDTH-1:0] pbuf_alloc_buf_addr;
wire [8              -1:0] pbuf_alloc_qnum    ;
wire                       pbuf_alloc_ready   ;
/* --------allocated buffer address{end}-------- */

/* --------Info from queue struct{begin}-------- */
wire                             qstruct_valid    ;
wire                             qstruct_last     ;
wire [`QUEUE_CONTEXT_WIDTH-1:0]  qstruct_head_ctx ;
wire [`QUEUE_DESC_WIDTH   -1:0]  qstruct_head_desc;
wire [`BUF_ADDR_WIDTH     -1:0]  qstruct_buf_addr ;
wire                             qstruct_ready    ;
/* --------Info from queue struct{end}-------- */

/* --------Info from queue struct{begin}-------- */
wire                             st_qstruct_valid    ;
wire                             st_qstruct_last     ;
wire [`QUEUE_CONTEXT_WIDTH-1:0]  st_qstruct_head_ctx ;
wire [`QUEUE_DESC_WIDTH   -1:0]  st_qstruct_head_desc;
wire [`BUF_ADDR_WIDTH     -1:0]  st_qstruct_buf_addr ;
wire                             st_qstruct_ready    ;
/* --------Info from queue struct{end}-------- */

/* --------Ctrl Info to pyld_buf{begin}-------- */
wire                       pbuf_free_valid     ;
wire                       pbuf_free_last      ;
wire [`P2P_DHEAD_W   -1:0] pbuf_free_head      ;
wire [1:0]                 pbuf_free_buf_offset;
wire [`BUF_ADDR_WIDTH-1:0] pbuf_free_buf_addr  ;
wire                       pbuf_free_ready     ;
/* --------Ctrl Info to pyld_buf{begin}-------- */

/* --------Ctrl Info to pyld_buf{begin}-------- */
wire                       st_pbuf_free_valid     ;
wire                       st_pbuf_free_last      ;
wire [`P2P_DHEAD_W   -1:0] st_pbuf_free_head      ;
wire [1:0]                 st_pbuf_free_buf_offset;
wire [`BUF_ADDR_WIDTH-1:0] st_pbuf_free_buf_addr  ;
wire                       st_pbuf_free_ready     ;
/* --------Ctrl Info to pyld_buf{begin}-------- */

/* --------p2p mem payload out{begin}-------- */
wire                       ft_pyld_req_valid;
wire                       ft_pyld_req_last ;
wire [`P2P_DHEAD_W   -1:0] ft_pyld_req_head ;
wire [`P2P_DATA_W    -1:0] ft_pyld_req_data ;
wire                       ft_pyld_req_ready;
/* --------p2p mem payload out{end}-------- */

wire prp_init_end, pb_init_end;


`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire [`SRAM_RW_DATA_W*2-1:0] pbuf_rw_data;
wire [(2*`QUEUE_NUM+1)*`SRAM_RW_DATA_W-1:0] qstruct_rw_data;

wire [`TGT_TOP_SIGNAL_W-1:0] dbg_signal_tgt_top;
wire [`TGT_RECV_SIGNAL_W-1:0] dbg_signal_tgt_recv;
wire [`TGT_QSTRUCT_SIGNAL_W-1:0] dbg_signal_tgt_qstruct;
wire [`TGT_PBUF_SIGNAL_W-1:0] dbg_signal_tgt_pbuf;
wire [`TGT_SEND_SIGNAL_W-1:0] dbg_signal_tgt_send;
/* -------APB reated signal{end}------- */
`endif

//-------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign {pbuf_rw_data, qstruct_rw_data} = rw_data;

// Debug bus for p2p ini
assign dbg_bus = {dbg_signal_tgt_top, dbg_signal_tgt_recv, 
                  dbg_signal_tgt_qstruct, dbg_signal_tgt_pbuf, dbg_signal_tgt_send} >> {dbg_sel, 5'd0};

// Debug signal for p2p ini top
assign dbg_signal_tgt_top = { // 2703

    st_reg_p2p_mem_req_valid, st_reg_p2p_mem_req_last , st_reg_p2p_mem_req_head , st_reg_p2p_mem_req_data , st_reg_p2p_mem_req_ready, // 387
    mem_addr, nxt_chnl_sel, // 40

    p2p_mem_desc_req_valid, p2p_mem_pyld_req_valid, st0_p2p_pyld_req_valid, 
    p2p_mem_desc_req_last , p2p_mem_pyld_req_last , st0_p2p_pyld_req_last , 
    p2p_mem_desc_req_head , p2p_mem_pyld_req_head , st0_p2p_pyld_req_head , 
    p2p_mem_desc_req_data , p2p_mem_pyld_req_data , st0_p2p_pyld_req_data , 
    p2p_mem_desc_req_ready, p2p_mem_pyld_req_ready, st0_p2p_pyld_req_ready, // 1161

    nxt_valid, nxt_qnum , // 9
    dropped_wen , dropped_qnum, // 5
    st_pyld_req_valid, st_pyld_req_last , st_pyld_req_blen , st_pyld_req_qnum, st_pyld_req_data, st_pyld_req_ready, // 283
    pbuf_alloc_valid, pbuf_alloc_last, pbuf_alloc_buf_addr, pbuf_alloc_qnum, pbuf_alloc_ready, // 21
    qstruct_valid, qstruct_last, qstruct_head_ctx, qstruct_head_desc, qstruct_buf_addr, qstruct_ready, // 157
    st_qstruct_valid, st_qstruct_last, st_qstruct_head_ctx, st_qstruct_head_desc, st_qstruct_buf_addr, st_qstruct_ready, // 157
    pbuf_free_valid, pbuf_free_last, pbuf_free_head, pbuf_free_buf_offset, pbuf_free_buf_addr, pbuf_free_ready, // 79
    st_pbuf_free_valid, st_pbuf_free_last, st_pbuf_free_head, st_pbuf_free_buf_offset, st_pbuf_free_buf_addr, st_pbuf_free_ready, // 79
    
    ft_pyld_req_valid, ft_pyld_req_last , ft_pyld_req_head , ft_pyld_req_data , ft_pyld_req_ready, // 323
    prp_init_end, pb_init_end // 2
};
/* -------APB reated signal{end}------- */
`endif

/* -------- Related to demux {begin}-------- */
st_reg #(
    .TUSER_WIDTH ( `P2P_HEAD_W  ),
    .TDATA_WIDTH ( `P2P_DATA_W  ),
    .MODE        ( 1            )
) st_reg2demux (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* -------input axis-like interface{begin}------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    .axis_tvalid ( p2p_mem_req_valid ), // i, 1
    .axis_tlast  ( p2p_mem_req_last  ), // i, 1
    .axis_tuser  ( p2p_mem_req_head  ), // i, TUSER_WIDTH
    .axis_tdata  ( p2p_mem_req_data  ), // i, TDATA_WIDTH
    .axis_tready ( p2p_mem_req_ready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    .axis_reg_tvalid ( st_reg_p2p_mem_req_valid ), // o, 1  // read valid from input register
    .axis_reg_tlast  ( st_reg_p2p_mem_req_last  ), // o, 1 
    .axis_reg_tuser  ( st_reg_p2p_mem_req_head  ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( st_reg_p2p_mem_req_data  ), // o, TDATA_WIDTH
    .axis_reg_tready ( st_reg_p2p_mem_req_ready )  // i, 1
    /* -------output in_reg inteface{end}------- */
);

assign mem_addr = p2p_mem_req_head[63:32];
assign nxt_chnl_sel = p2p_mem_req_valid ? (mem_addr[13:12] == 2'b11) : 0;
st_demux #(
    .CHNL_NUM     ( 2           ), // number of slave signals to arbit
    .CHNL_NUM_LOG ( 1           ),
    .TUSER_WIDTH  ( `P2P_HEAD_W ),
    .TDATA_WIDTH  ( `P2P_DATA_W )
) tgt_mem_demux (
    .clk      ( clk   ), // i, 1
    .rst_n    ( rst_n ), // i, 1

    .nxt_chnl_vld  ( p2p_mem_req_valid ), // i, 1
    .nxt_chnl_sel  ( nxt_chnl_sel      ), // i, 8

    /* --------P2P Memory Access Channel In{begin}-------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    .s_axis_demux_valid  ( st_reg_p2p_mem_req_valid ), // i, 1
    .s_axis_demux_last   ( st_reg_p2p_mem_req_last  ), // i, 1
    .s_axis_demux_head   ( st_reg_p2p_mem_req_head  ), // i, `P2P_HEAD_W
    .s_axis_demux_data   ( st_reg_p2p_mem_req_data  ), // i, `P2P_DATA_W
    .s_axis_demux_ready  ( st_reg_p2p_mem_req_ready ), // o, 1
    /* --------P2P Memory Access Channel In{end}-------- */

    /* --------P2P Memory Access Channel Out{begin}-------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    .m_axis_demux_valid  ( {p2p_mem_desc_req_valid, p2p_mem_pyld_req_valid} ), // o, 2 * 1
    .m_axis_demux_last   ( {p2p_mem_desc_req_last , p2p_mem_pyld_req_last } ), // o, 2 * 1
    .m_axis_demux_head   ( {p2p_mem_desc_req_head , p2p_mem_pyld_req_head } ), // o, 2 * `P2P_HEAD_W
    .m_axis_demux_data   ( {p2p_mem_desc_req_data , p2p_mem_pyld_req_data } ), // o, 2 * `P2P_DATA_W
    .m_axis_demux_ready  ( {p2p_mem_desc_req_ready, p2p_mem_pyld_req_ready} )  // i, 2 * 1
    /* --------P2P Memory Access Channel Out{end}-------- */
);
/* -------- Related to demux {end}-------- */

/* -------- Payload receive procedure{begin}-------- */
st_reg #(
    .TUSER_WIDTH ( `P2P_HEAD_W  ),
    .TDATA_WIDTH ( `P2P_DATA_W  ),
    .MODE        ( 1            )
) st_reg0 (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* -------input axis-like interface{begin}------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    .axis_tvalid ( p2p_mem_pyld_req_valid ), // i, 1
    .axis_tlast  ( p2p_mem_pyld_req_last  ), // i, 1
    .axis_tuser  ( p2p_mem_pyld_req_head  ), // i, TUSER_WIDTH
    .axis_tdata  ( p2p_mem_pyld_req_data  ), // i, TDATA_WIDTH
    .axis_tready ( p2p_mem_pyld_req_ready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    .axis_reg_tvalid ( st0_p2p_pyld_req_valid ), // o, 1  // read valid from input register
    .axis_reg_tlast  ( st0_p2p_pyld_req_last  ), // o, 1 
    .axis_reg_tuser  ( st0_p2p_pyld_req_head  ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( st0_p2p_pyld_req_data  ), // o, TDATA_WIDTH
    .axis_reg_tready ( st0_p2p_pyld_req_ready )  // i, 1
    /* -------output in_reg inteface{end}------- */
);

assign nxt_valid = p2p_mem_pyld_req_valid;
assign nxt_qnum  = (p2p_mem_pyld_req_head[63:32] >> 14) & 4'hf;
tgt_pyld_recv_proc #(
    
) tgt_pyld_recv_proc (

    .clk      ( clk      ), // i, 1
    .rst_n    ( rst_n    ), // i, 1
    .init_end ( prp_init_end ), // o, 1
    
    /* --------Next mem payload{begin}-------- */
    .nxt_vaild  ( nxt_valid ), // i, 1
    .nxt_qnum   ( nxt_qnum  ), // i, 8
    /* --------Next mem payload{end}-------- */
    
    /* --------p2p mem payload in{begin}-------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    .st0_p2p_pyld_req_valid ( st0_p2p_pyld_req_valid ), // i, 1
    .st0_p2p_pyld_req_last  ( st0_p2p_pyld_req_last  ), // i, 1
    .st0_p2p_pyld_req_head  ( st0_p2p_pyld_req_head  ), // i, `P2P_HEAD_W
    .st0_p2p_pyld_req_data  ( st0_p2p_pyld_req_data  ), // i, `P2P_DATA_W
    .st0_p2p_pyld_req_ready ( st0_p2p_pyld_req_ready ), // o, 1
    /* --------p2p mem payload in{end}-------- */
    
    /* --------p2p mem payload out{begin}-------- */
    .st_pyld_req_valid ( st_pyld_req_valid ), // o, 1
    .st_pyld_req_last  ( st_pyld_req_last  ), // o, 1
    .st_pyld_req_blen  ( st_pyld_req_blen  ), // o, `MSG_BLEN_WIDTH
    .st_pyld_req_qnum  ( st_pyld_req_qnum  ), // o, 8
    .st_pyld_req_data  ( st_pyld_req_data  ), // o, `P2P_DATA_W
    .st_pyld_req_ready ( st_pyld_req_ready ), // i, 1
    /* --------p2p mem payload out{end}-------- */

    /* --------dropped queue{begin}-------- */
    .dropped_wen        ( dropped_wen  ), // i, 1
    .dropped_qnum       ( dropped_qnum ), // i, `QUEUE_NUM_LOG
    .dropped_data       ( 1'd0         )  // i, 1; we assume no dropped desc
    /* --------dropped queue{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_signal ( dbg_signal_tgt_recv ) // o, `TGT_RECV_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);
/* -------- Payload receive procedure{end}-------- */

tgt_queue_struct #(
    
) tgt_queue_struct (

    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* --------P2P Configuration Channel{begin}-------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    .p2p_cfg_req_valid   ( p2p_cfg_req_valid  ), // i, 1
    .p2p_cfg_req_last    ( p2p_cfg_req_last   ), // i, 1
    .p2p_cfg_req_data    ( p2p_cfg_req_data   ), // i, `P2P_DATA_W
    .p2p_cfg_req_head    ( p2p_cfg_req_head   ), // i, `P2P_HEAD_W
    .p2p_cfg_req_ready   ( p2p_cfg_req_ready  ), // o, 1
    
    // .p2p_cfg_rrsp_valid  ( p2p_cfg_rrsp_valid ), // o, 1
    // .p2p_cfg_rrsp_last   ( p2p_cfg_rrsp_last  ), // o, 1
    // .p2p_cfg_rrsp_data   ( p2p_cfg_rrsp_data  ), // o, `P2P_DATA_W
    // .p2p_cfg_rrsp_ready  ( p2p_cfg_rrsp_ready ), // i, 1
    /* --------P2P Configuration Channel{end}-------- */

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
    /* st_qstruct_head_ctx : qcontext of prepared queue
     * st_qstruct_head_desc: payload descriptor
     * st_qstruct_buf_addr : allocated buffer base address in P2P pyld_buf, 
     *                       this is an array. A valid addr outputs when valid
     *                       and ready assert at the same time.
     * st_qstruct_last     : assert when the last st_qstruct_buf_addr is asserted
     */
    .st_qstruct_valid     ( qstruct_valid     ), // o, 1
    .st_qstruct_last      ( qstruct_last      ), // o, 1
    .st_qstruct_head_ctx  ( qstruct_head_ctx  ), // o, `QUEUE_CONTEXT_WIDTH
    .st_qstruct_head_desc ( qstruct_head_desc ), // o, `QUEUE_DESC_WIDTH
    .st_qstruct_buf_addr  ( qstruct_buf_addr  ), // o, `BUF_ADDR_WIDTH
    .st_qstruct_ready     ( qstruct_ready     )  // i, 1
    /* --------queue struct output for send processing{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.rw_data            ( qstruct_rw_data ) // i, (2*`QUEUE_NUM+1)*`SRAM_RW_DATA_W
	,.dbg_signal         ( dbg_signal_tgt_qstruct ) // o, `TGT_QSTRUCT_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

st_reg #(
    .TUSER_WIDTH ( `P2P_DHEAD_W        ),
    .TDATA_WIDTH ( `BUF_ADDR_WIDTH + 2 ),
    .MODE        ( 1                   )
) st_pbuf (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( pbuf_free_valid     ), // i, 1
    .axis_tlast  ( pbuf_free_last      ), // i, 1
    .axis_tuser  ( pbuf_free_head      ), // i, TUSER_WIDTH
    .axis_tdata  ( {pbuf_free_buf_addr, pbuf_free_buf_offset} ), // i, TDATA_WIDTH
    .axis_tready ( pbuf_free_ready     ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .axis_reg_tvalid ( st_pbuf_free_valid     ), // o, 1  // read valid from input register
    .axis_reg_tlast  ( st_pbuf_free_last      ), // o, 1 
    .axis_reg_tuser  ( st_pbuf_free_head      ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( {st_pbuf_free_buf_addr, st_pbuf_free_buf_offset} ), // o, TDATA_WIDTH
    .axis_reg_tready ( st_pbuf_free_ready     )  // i, 1
    /* -------output in_reg inteface{end}------- */
);

tgt_pyld_buf #(
    
) tgt_pyld_buf (

    .clk      ( clk      ), // i, 1
    .rst_n    ( rst_n    ), // i, 1
    .init_end ( pb_init_end ), // o, 1

    /* --------allocated buffer address{begin}-------- */
    .pbuf_alloc_valid    ( pbuf_alloc_valid    ), // o, 1
    .pbuf_alloc_last     ( pbuf_alloc_last     ), // o, 1
    .pbuf_alloc_buf_addr ( pbuf_alloc_buf_addr ), // o, 32
    .pbuf_alloc_qnum     ( pbuf_alloc_qnum     ), // o, 8
    .pbuf_alloc_ready    ( pbuf_alloc_ready    ), // i, 1
    /* --------allocated buffer address{end}-------- */

    /* --------p2p mem payload in{begin}-------- */
    .st_pyld_req_valid ( st_pyld_req_valid ), // i, 1
    .st_pyld_req_last  ( st_pyld_req_last  ), // i, 1
    .st_pyld_req_blen  ( st_pyld_req_blen  ), // i, `MSG_BLEN_WIDTH
    .st_pyld_req_qnum  ( st_pyld_req_qnum  ), // i, 8
    .st_pyld_req_data  ( st_pyld_req_data  ), // i, `P2P_DATA_W
    .st_pyld_req_ready ( st_pyld_req_ready ), // o, 1
    /* --------p2p mem payload in{end}-------- */
    
    /* --------Ctrl Info to pyld_buf{begin}-------- */
    .pbuf_free_valid      ( st_pbuf_free_valid      ), // i, 1
    .pbuf_free_last       ( st_pbuf_free_last       ), // i, 1
    .pbuf_free_head       ( st_pbuf_free_head       ), // i, `P2P_DHEAD_W
    .pbuf_free_buf_offset ( st_pbuf_free_buf_offset ), // i, 2
    .pbuf_free_buf_addr   ( st_pbuf_free_buf_addr   ), // i, `BUF_ADDR_WIDTH
    .pbuf_free_ready      ( st_pbuf_free_ready      ), // o, 1
    /* --------Ctrl Info to pyld_buf{begin}-------- */
    
    /* --------p2p mem payload out{begin}-------- */
    .ft_pyld_req_valid ( ft_pyld_req_valid ), // o, 1
    .ft_pyld_req_last  ( ft_pyld_req_last  ), // o, 1
    .ft_pyld_req_head  ( ft_pyld_req_head  ), // o, `P2P_DHEAD_W
    .ft_pyld_req_data  ( ft_pyld_req_data  ), // o, `P2P_DATA_W
    .ft_pyld_req_ready ( ft_pyld_req_ready )  // i, 1
    /* --------p2p mem payload out{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.rw_data            ( pbuf_rw_data        ) // i, `SRAM_RW_DATA_W*2
    ,.dbg_signal         ( dbg_signal_tgt_pbuf ) // o, `TGT_PBUF_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
    
);

st_reg #(
    .TUSER_WIDTH ( `QUEUE_CONTEXT_WIDTH + `QUEUE_DESC_WIDTH ),
    .TDATA_WIDTH ( `BUF_ADDR_WIDTH ),
    .MODE        ( 1               )
) st_qstruct (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( qstruct_valid                         ), // i, 1
    .axis_tlast  ( qstruct_last                          ), // i, 1
    .axis_tuser  ( {qstruct_head_ctx, qstruct_head_desc} ), // i, TUSER_WIDTH
    .axis_tdata  ( qstruct_buf_addr                      ), // i, TDATA_WIDTH
    .axis_tready ( qstruct_ready                         ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .axis_reg_tvalid ( st_qstruct_valid                            ), // o, 1  // read valid from input register
    .axis_reg_tlast  ( st_qstruct_last                             ), // o, 1 
    .axis_reg_tuser  ( {st_qstruct_head_ctx, st_qstruct_head_desc} ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( st_qstruct_buf_addr                         ), // o, TDATA_WIDTH
    .axis_reg_tready ( st_qstruct_ready                            )  // i, 1
    /* -------output in_reg inteface{end}------- */
);

tgt_pyld_send_proc #(
    
) tgt_pyld_send_proc (

    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* --------Info from queue struct{begin}-------- */
    /* qstruct_head_ctx : qcontext of prepared queue
     * qstruct_head_desc: payload descriptor
     * qstruct_buf_addr : allocated buffer base address in P2P pyld_buf, 
     *                    this is an array. A valid addr outputs when valid
     *                    and ready assert at the same time.
     * qstruct_last     : assert when the last qstruct_buf_addr is asserted
     */
    .qstruct_valid     ( st_qstruct_valid     ), // i, 1
    .qstruct_last      ( st_qstruct_last      ), // i, 1
    .qstruct_head_ctx  ( st_qstruct_head_ctx  ), // i, `QUEUE_CONTEXT_WIDTH
    .qstruct_head_desc ( st_qstruct_head_desc ), // i, `QUEUE_DESC_WIDTH
    .qstruct_buf_addr  ( st_qstruct_buf_addr  ), // i, `BUF_ADDR_WIDTH
    .qstruct_ready     ( st_qstruct_ready     ), // o, 1
    /* --------Info from queue struct{end}-------- */

    /* --------Ctrl Info to pyld_buf{begin}-------- */
    .pbuf_free_valid      ( pbuf_free_valid      ), // o, 1
    .pbuf_free_last       ( pbuf_free_last       ), // o, 1
    .pbuf_free_head       ( pbuf_free_head       ), // o, `P2P_DHEAD_W
    .pbuf_free_buf_offset ( pbuf_free_buf_offset ), // o, 2
    .pbuf_free_buf_addr   ( pbuf_free_buf_addr   ), // o, `BUF_ADDR_WIDTH
    .pbuf_free_ready      ( pbuf_free_ready      ), // i, 1
    /* --------Ctrl Info to pyld_buf{begin}-------- */

    /* --------p2p mem payload out{begin}-------- */
    .ft_pyld_req_valid ( ft_pyld_req_valid ), // i, 1
    .ft_pyld_req_last  ( ft_pyld_req_last  ), // i, 1
    .ft_pyld_req_head  ( ft_pyld_req_head  ), // i, `P2P_DHEAD_W
    .ft_pyld_req_data  ( ft_pyld_req_data  ), // i, `P2P_DATA_W
    .ft_pyld_req_ready ( ft_pyld_req_ready ), // o, 1
    /* --------p2p mem payload out{end}-------- */

    /* --------p2p forward down channel{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved |dst_dev| src_dev | Reserved | Byte length |
     * |  63:-    | 47:40 |  39:32  |  31:16   |    15:0     |
     */
    .st_p2p_down_valid ( p2p_down_valid ), // o, 1             
    .st_p2p_down_last  ( p2p_down_last  ), // o, 1             
    .st_p2p_down_data  ( p2p_down_data  ), // o, `P2P_DATA_W  
    .st_p2p_down_head  ( p2p_down_head  ), // o, `P2P_DHEAD_W
    .st_p2p_down_ready ( p2p_down_ready )  // i, 1        
    /* --------p2p forward down channel{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_signal ( dbg_signal_tgt_send ) // o, `TGT_SEND_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

assign init_end = prp_init_end & pb_init_end;

endmodule // p2p_target
