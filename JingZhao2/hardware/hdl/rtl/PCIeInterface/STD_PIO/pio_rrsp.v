`timescale 1ns / 100ps
//*************************************************************************
// > File Name: pio_rrsp.v
// > Author   : Kangning
// > Date     : 2020-08-25
// > Note     : pio_rrsp, used to transform DMA read response. 
// >               Note that the packet is 4KB aligned.
//*************************************************************************

module pio_rrsp #(

    parameter CHANNEL_NUM     = 4
)  (
    input wire clk  , // i, 1
    input wire rst_n, // i, 1

    /* --------PIO Read response interface{begin}-------- */
    /* pio_tuser
     * |  139  | 138:136 |  135:132 | 131:128 |    127:96    |   95:0  |
     * | is_wr | bar_id  | first_be | last_be | aligned_addr | cc_head |
     * |       |         |          |         |              |         |
     */
    output wire [`PIO_DATA_W-1:0] m_axis_rrsp_tdata , // o, `PIO_DATA_W
    output wire [`PIO_USER_W-1:0] m_axis_rrsp_tuser , // o, `PIO_USER_W
    output wire                   m_axis_rrsp_tlast , // o, 1
    output wire                   m_axis_rrsp_tvalid, // o, 1
    input  wire                   m_axis_rrsp_tready, // i, 1
    /* --------PIO Read response interface{end}-------- */

    /* --------PIO Read response interface{begin}-------- */
    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    input  wire [CHANNEL_NUM * `PIO_DATA_W-1:0] s_axis_rrsp_data , // i, CHANNEL_NUM * `PIO_DATA_W
    input  wire [CHANNEL_NUM * `PIO_HEAD_W-1:0] s_axis_rrsp_head , // i, CHANNEL_NUM * `PIO_HEAD_W
    input  wire [CHANNEL_NUM * 1          -1:0] s_axis_rrsp_last , // i, CHANNEL_NUM * 1
    input  wire [CHANNEL_NUM * 1          -1:0] s_axis_rrsp_valid, // i, CHANNEL_NUM * 1
    output wire [CHANNEL_NUM * 1          -1:0] s_axis_rrsp_ready, // o, CHANNEL_NUM * 1
    /* --------PIO Read responses interface{end}-------- */

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
    ,input  wire [31:0] dbg_sel  // debug bus select
    ,output wire [31:0] dbg_bus  // debug bus data    
    /* -------APB reated signal{end}------- */
`endif

`ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved | reserved | idx | end | out |
     * |  255:10  |   9:5    | 4:2 |  1  |  0  |
     */
    ,output wire [255:0] debug
    /* ------- Debug interface {end}------- */
`endif
);

/* -------output for arbiter{begin}-------- */
wire [`PIO_DATA_W-1:0] axis_out_rsp_tdata ;
wire [`PIO_HEAD_W-1:0] axis_out_rsp_thead ;
wire                   axis_out_rsp_tlast ;
wire                   axis_out_rsp_tvalid;
wire                   axis_out_rsp_tready;
/* -------output for arbiter{end}-------- */

/* -------arbiter -> pkt align{begin}------- */
wire                                 unalign_valid;
wire                                 unalign_last ;
wire [`PIO_HEAD_W+`ALIGN_HEAD_W-1:0] unalign_head ;
wire [`PIO_DATA_W              -1:0] unalign_data ;
wire                                 unalign_ready;
/* -------arbiter -> pkt align{end}------- */

/* -------pkt align -> split{begin}------- */
wire [`PIO_DATA_W              -1:0] align_tdata ;
wire [`PIO_HEAD_W+`ALIGN_HEAD_W-1:0] align_tuser ;
wire                                 align_tlast ;
wire                                 align_tvalid;
wire                                 align_tready;
/* -------pkt align -> split{end}------- */

/* --------signal from tuser{begin}--------- */
wire [95:0] cc_head_old;
wire [31:0] aligned_addr;
wire [10:0] dw_cnt;
wire [3 :0] first_be, last_be;
/* --------signal from tuser{end}--------- */

/* --------signal from calculation{begin}--------- */
wire [95:0] cc_head_new   ;
wire [31:0] unaligned_addr;
wire [1 :0] first_empty   ; // Number of invalid bytes in first Double word
/* --------signal from calculation{end}--------- */

/* -------split -> out{begin}------- */
wire [`PIO_DATA_W              -1:0] splited_tdata ;
wire [`PIO_KEEP_W              -1:0] splited_tkeep ;
wire [`PIO_HEAD_W+`ALIGN_HEAD_W-1:0] splited_tuser ;
wire                                 splited_tlast ;
wire                                 splited_tvalid;
wire                                 splited_tready;
/* -------split -> out{end}------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire [`PIO_RRSP_SIGNAL_W     -1:0] dbg_signal_pio_rrsp;
wire [`PIO_MUX_SIGNAL_W      -1:0] dbg_signal_pio_mux;
wire [`PIO_DW_ALIGN_SIGNAL_W -1:0] dbg_signal_pio_dw_align;
wire [`PIO_RSP_SPLIT_SIGNAL_W-1:0] dbg_signal_pio_rsp_split;
/* -------APB reated signal{end}------- */
`endif

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */

assign dbg_bus = dbg_signal_pio_rrsp >> {dbg_sel, 5'd0};

assign dbg_signal_pio_rrsp = { // 6442
    axis_out_rsp_tdata, axis_out_rsp_thead, axis_out_rsp_tlast, axis_out_rsp_tvalid, axis_out_rsp_tready, // 391
    unalign_valid, unalign_last, unalign_head, unalign_data, unalign_ready, // 519
    align_tdata, align_tuser, align_tlast, align_tvalid, align_tready, // 519
    cc_head_old, aligned_addr, dw_cnt, first_be, last_be, // 147
    cc_head_new, unaligned_addr, first_empty, // 130
    splited_tdata, splited_tkeep, splited_tuser, splited_tlast, splited_tvalid, splited_tready, // 527
    dbg_signal_pio_mux, // 1621
    dbg_signal_pio_dw_align, // 1286
    dbg_signal_pio_rsp_split // 1302
};
/* -------APB reated signal{end}------- */
`endif

pio_mux #(
    .CHNL_NUM_LOG ( 2            ),
    .CHANNEL_NUM  ( CHANNEL_NUM  )   // number of slave signals to arbit
) pio_mux (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* -------Slave AXIS Interface{begin}------- */
    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    .s_axis_ifc_tdata  ( s_axis_rrsp_data  ), // i, CHANNEL_NUM * `PIO_DATA_W
    .s_axis_ifc_tkeep  ( {CHANNEL_NUM * `PIO_KEEP_W{1'd0}}), // i, CHANNEL_NUM * `PIO_KEEP_W
    .s_axis_ifc_thead  ( s_axis_rrsp_head  ), // i, CHANNEL_NUM * `PIO_HEAD_W ;The field contents are different from dma_*_tuser interface
    .s_axis_ifc_tlast  ( s_axis_rrsp_last  ), // i, CHANNEL_NUM * 1
    .s_axis_ifc_tvalid ( s_axis_rrsp_valid ), // i, CHANNEL_NUM * 1
    .s_axis_ifc_tready ( s_axis_rrsp_ready ), // o, CHANNEL_NUM * 1
    /* -------Slave AXIS Interface{end}------- */

    /* ------- Master AXIS Interface{begin} ------- */
    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    .m_axis_ifc_tdata  ( axis_out_rsp_tdata  ), // o, `PIO_DATA_W
    .m_axis_ifc_tkeep  (                     ), // o, `PIO_KEEP_W
    .m_axis_ifc_thead  ( axis_out_rsp_thead  ), // o, `PIO_HEAD_W   ;The field contents are different from dma_*_head interface
    .m_axis_ifc_tlast  ( axis_out_rsp_tlast  ), // o, 1
    .m_axis_ifc_tvalid ( axis_out_rsp_tvalid ), // o, 1
    .m_axis_ifc_tready ( axis_out_rsp_tready )  // i, 1
    /* ------- Master AXIS Interface{end} ------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_signal ( dbg_signal_pio_mux ) // o, `PIO_MUX_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
    
`ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved | reserved | top_idx | top_end | top_out |
     * |  255:10  |    9:5   |   4:2   |    1    |    0    |
     */
    ,.debug (debug)
    /* ------- Debug interface {end}------- */
`endif
);

assign unalign_data  = axis_out_rsp_tdata ;
assign unalign_head  = {axis_out_rsp_thead, 64'd0, axis_out_rsp_thead[127:96], 19'd0, axis_out_rsp_thead[28:16]};
assign unalign_last  = axis_out_rsp_tlast ;
assign unalign_valid = axis_out_rsp_tvalid;
assign axis_out_rsp_tready = unalign_ready;

/* ------- Align data to DW aligned{begin}------- */
pio_dw_align #(
    .USER_WIDTH   ( `PIO_HEAD_W + `ALIGN_HEAD_W ),
    .HEAD_WIDTH   ( `PIO_HEAD_W + `ALIGN_HEAD_W )
) pio_dw_align (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1
    
    .unalign_data  ( unalign_data  ), // i, `PIO_DATA_W
    .unalign_head  ( unalign_head  ), // i, HEAD_WIDTH
    .unalign_last  ( unalign_last  ), // i, 1
    .unalign_valid ( unalign_valid ), // i, 1
    .unalign_ready ( unalign_ready ), // o, 1

    .align_data  ( align_tdata  ), // o, `PIO_DATA_W
    .align_user  ( align_tuser  ), // o, USER_WIDTH
    .align_last  ( align_tlast  ), // o, 1
    .align_valid ( align_tvalid ), // o, 1
    .align_ready ( align_tready )  // i, 1

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_signal ( dbg_signal_pio_dw_align ) // o, `PIO_DW_ALIGN_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);
/* ------- Align data to DW aligned{end}------- */

/* ------- Split pkt to fit max_pyld_sz{begin}------- */
pio_rsp_split #(
    .USER_WIDTH   ( `PIO_HEAD_W + `ALIGN_HEAD_W )
) pio_rsp_split (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    .max_pyld_sz ( max_pyld_sz ), // i, 3

    .align_valid ( align_tvalid ), // i, 1
    .align_last  ( align_tlast  ), // i, 1
    .align_user  ( align_tuser  ), // i, USER_WIDTH
    .align_data  ( align_tdata  ), // i, `PIO_DATA_W
    .align_ready ( align_tready ), // o, 1

    .splited_tdata  ( splited_tdata  ), // o, `PIO_DATA_W
    .splited_tkeep  ( splited_tkeep  ), // o, `PIO_KEEP_W  
    .splited_tuser  ( splited_tuser  ), // o, USER_WIDTH
    .splited_tlast  ( splited_tlast  ), // o, 1
    .splited_tvalid ( splited_tvalid ), // o, 1
    .splited_tready ( splited_tready )  // i, 1

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_signal ( dbg_signal_pio_rsp_split ) // o, `PIO_RSP_SPLIT_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);
/* ------- Split pkt to fit max_pyld_sz{end}------- */

/* --------signal from tuser{begin}--------- */
/* AXI-Stream splited interface tuser, only valid in first beat of a packet
 * |               Extra tuser               | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
 * |`PIO_HEAD_W+`ALIGN_HEAD_W-1:`ALIGN_HEAD_W| 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
 */
assign cc_head_old  = splited_tuser[`PIO_HEAD_W+`ALIGN_HEAD_W-1:`ALIGN_HEAD_W];
assign first_be     = splited_tuser[7:4];
assign last_be      = splited_tuser[3:0];
assign aligned_addr = splited_tuser[63:32];
assign dw_cnt       = splited_tuser[18:8];
/* --------signal from tuser{end}--------- */

/* --------signal from calculation{begin}--------- */
assign cc_head_new  = {cc_head_old[95:43], dw_cnt, cc_head_old[31:7], unaligned_addr[6:0]};
assign first_empty  = first_be[0] ? 2'd0 :
                      first_be[1] ? 2'd1 :
                      first_be[2] ? 2'd2 :
                      first_be[3] ? 2'd3 : 
                      2'd0; // unlikely
assign unaligned_addr = {aligned_addr[31:2], first_empty};
/* --------signal from calculation{end}--------- */

/* --------output interface{begin}-------- */
/* pio_tuser
 * |  139  | 138:136 |  135:132 | 131:128 |    127:96    |   95:0  |
 * | is_wr | bar_id  | first_be | last_be | aligned_addr | cc_head |
 * |       |         |          |         |              |         |
 */
assign m_axis_rrsp_tdata  = splited_tdata ;
assign m_axis_rrsp_tuser  = {1'd0, 3'd0, first_be, last_be, aligned_addr, cc_head_new};
assign m_axis_rrsp_tlast  = splited_tlast ;
assign m_axis_rrsp_tvalid = splited_tvalid;
assign splited_tready     = m_axis_rrsp_tready;
/* --------output interface{end}-------- */
endmodule