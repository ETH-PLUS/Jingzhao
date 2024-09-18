`timescale 1ns / 100ps
//*************************************************************************
// > File   : P2P.v
// > Author : Kangning
// > Date   : 2022-06-10
// > Note   : DMA P2P initiator and target
//*************************************************************************

module P2P #(
    
) (
    input  wire clk     , // i, 1
    input  wire rst_n   , // i, 1
    output wire init_done, // o, 1

    /* --------P2P Configuration Channel{begin}-------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    input   wire [1           - 1 : 0] p2p_cfg_req_valid, // i, 1
    input   wire [1           - 1 : 0] p2p_cfg_req_last , // i, 1
    input   wire [`P2P_HEAD_W - 1 : 0] p2p_cfg_req_head , // i, `P2P_HEAD_W
    input   wire [`P2P_DATA_W - 1 : 0] p2p_cfg_req_data , // i, `P2P_DATA_W
    output  wire [1           - 1 : 0] p2p_cfg_req_ready, // o, 1
    
    output  wire [1           - 1 : 0] p2p_cfg_rrsp_valid, // o, 1
    output  wire [1           - 1 : 0] p2p_cfg_rrsp_last , // o, 1
    output  wire [`P2P_DATA_W - 1 : 0] p2p_cfg_rrsp_data , // o, `P2P_DATA_W
    input   wire [1           - 1 : 0] p2p_cfg_rrsp_ready, // i, 1
    /* --------P2P Configuration Channel{end}-------- */

    /* -------P2P Memory Access Channel{begin}-------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    input  wire [1           - 1 : 0] p2p_mem_req_valid, // i, 1
    input  wire [1           - 1 : 0] p2p_mem_req_last , // i, 1
    input  wire [`P2P_HEAD_W - 1 : 0] p2p_mem_req_head , // i, `P2P_HEAD_W
    input  wire [`P2P_DATA_W - 1 : 0] p2p_mem_req_data , // i, `P2P_DATA_W
    output wire [1           - 1 : 0] p2p_mem_req_ready, // , 1
    /* -------P2P Memory Access Channel{end}-------- */

    /* --------P2P DMA Write Req{begin}-------- */
    /* dma_*_head, valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    output wire [1           - 1 : 0] p2p_dma_wr_req_valid, // o, 1             
    output wire [1           - 1 : 0] p2p_dma_wr_req_last , // o, 1             
    output wire [`DMA_HEAD_W - 1 : 0] p2p_dma_wr_req_head , // o, `DMA_HEAD_W
    output wire [`P2P_DATA_W - 1 : 0] p2p_dma_wr_req_data , // o, `P2P_DATA_W  
    input  wire [1           - 1 : 0] p2p_dma_wr_req_ready, // i, 1             
    /* --------P2P DMA Write Req{end}-------- */

    /* --------p2p forward up channel{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved |dst_dev| src_dev | Reserved | Byte length |
     * |  63:-    | 47:40 |  39:32  |  31:16   |    15:0     |
     */
    input  wire [1            - 1 : 0] p2p_upper_valid, // i, 1               
    input  wire [1            - 1 : 0] p2p_upper_last , // i, 1               
    input  wire [`P2P_UHEAD_W - 1 : 0] p2p_upper_head , // i, `P2P_UHEAD_W
    input  wire [`P2P_DATA_W  - 1 : 0] p2p_upper_data , // i, `P2P_DATA_W  
    output wire [1            - 1 : 0] p2p_upper_ready, // o, 1               
    /* --------p2p forward up channel{end}-------- */

    /* --------p2p forward down channel{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved |dst_dev| src_dev | Reserved | Byte length |
     * |  63:-    | 47:40 |  39:32  |  31:16   |    15:0     |
     */
    output wire [1            - 1 : 0] p2p_down_valid, // o, 1              
    output wire [1            - 1 : 0] p2p_down_last , // o, 1              
    output wire [`P2P_DHEAD_W - 1 : 0] p2p_down_head , // o, `P2P_DHEAD_W
    output wire [`P2P_DATA_W  - 1 : 0] p2p_down_data , // o, `P2P_DATA_W  
    input  wire [1            - 1 : 0] p2p_down_ready  // i, 1              
    /* --------p2p forward down channel{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [(2*`QUEUE_NUM+4)*`SRAM_RW_DATA_W-1:0] rw_data  // i, (2*`QUEUE_NUM+4)*`SRAM_RW_DATA_W
    ,input  wire [31:0] dbg_sel  // debug bus select
    ,output wire [31:0] dbg_bus  // debug bus data	
    /* -------APB reated signal{end}------- */
`endif
    
);

/* --------P2P Configuration Channel{begin}-------- */
/* p2p_req head
 * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
 * | is_wr | Reserved | addr  | Reserved | byte_len |
 */
wire [1           - 1 : 0] st_reg_p2p_cfg_req_valid;
wire [1           - 1 : 0] st_reg_p2p_cfg_req_last ;
wire [`P2P_HEAD_W - 1 : 0] st_reg_p2p_cfg_req_head ;
wire [`P2P_DATA_W - 1 : 0] st_reg_p2p_cfg_req_data ;
wire [1           - 1 : 0] st_reg_p2p_cfg_req_ready;

wire [31:0] mem_addr;
wire [7 :0] nxt_chnl_sel;
/* --------P2P Configuration Channel{end}-------- */

/* --------P2P Configuration Channel{begin}-------- */
/* p2p_req head
 * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
 * | is_wr | Reserved | addr  | Reserved | byte_len |
 */
wire [1           - 1 : 0] p2p_tgt_req_valid, p2p_ini_req_valid; // i, 1
wire [1           - 1 : 0] p2p_tgt_req_last , p2p_ini_req_last ; // i, 1
wire [`P2P_DATA_W - 1 : 0] p2p_tgt_req_data , p2p_ini_req_data ; // i, `P2P_DATA_W
wire [`P2P_HEAD_W - 1 : 0] p2p_tgt_req_head , p2p_ini_req_head ; // i, `P2P_HEAD_W
wire [1           - 1 : 0] p2p_tgt_req_ready, p2p_ini_req_ready; // o, 1
/* --------P2P Configuration Channel{end}-------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire [(2*`QUEUE_NUM+3)*`SRAM_RW_DATA_W-1:0] tgt_rw_data;
wire [`SRAM_RW_DATA_W-1:0] ini_rw_data;

wire [31:0] dbg_sel_p2p_top, dbg_sel_ini, dbg_sel_tgt;
wire [31:0] dbg_bus_p2p_top, dbg_bus_ini, dbg_bus_tgt;
wire [`P2P_TOP_SIGNAL_W-1:0] dbg_signal_p2p_top;
/* -------APB reated signal{end}------- */
`endif

//-------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign {ini_rw_data, tgt_rw_data} = rw_data;

assign dbg_sel_p2p_top = (`P2P_TOP_DBG_B <= dbg_sel && dbg_sel < `INI_DBG_B    ) ? (dbg_sel - `P2P_TOP_DBG_B) : 32'd0;
assign dbg_sel_ini     = (`INI_DBG_B     <= dbg_sel && dbg_sel < `TGT_DBG_B    ) ? (dbg_sel - `INI_DBG_B    ) : 32'd0;
assign dbg_sel_tgt     = (`TGT_DBG_B     <= dbg_sel && dbg_sel < `P2P_DBG_SIZE ) ? (dbg_sel - `TGT_DBG_B    ) : 32'd0;
assign dbg_bus         = (`P2P_TOP_DBG_B <= dbg_sel && dbg_sel < `INI_DBG_B    ) ? dbg_bus_p2p_top : 
                         (`INI_DBG_B     <= dbg_sel && dbg_sel < `TGT_DBG_B    ) ? dbg_bus_ini     : 
                         (`TGT_DBG_B     <= dbg_sel && dbg_sel < `P2P_DBG_SIZE ) ? dbg_bus_tgt     : 32'd0;

// Debug bus for p2p top
assign dbg_bus_p2p_top = dbg_signal_p2p_top >> {dbg_sel_p2p_top, 5'd0};

// Debug signal for p2p top
assign dbg_signal_p2p_top = { // 3268

    init_done, // 1
    p2p_cfg_req_valid, p2p_cfg_req_last , p2p_cfg_req_head , p2p_cfg_req_data , p2p_cfg_req_ready, // 387
    p2p_cfg_rrsp_valid, p2p_cfg_rrsp_last , p2p_cfg_rrsp_data , p2p_cfg_rrsp_ready, // 259
    p2p_mem_req_valid, p2p_mem_req_last , p2p_mem_req_head , p2p_mem_req_data , p2p_mem_req_ready, // 387
    p2p_dma_wr_req_valid, p2p_dma_wr_req_last , p2p_dma_wr_req_head , p2p_dma_wr_req_data , p2p_dma_wr_req_ready, // 387
    p2p_upper_valid, p2p_upper_last , p2p_upper_head , p2p_upper_data , p2p_upper_ready, // 323
    p2p_down_valid, p2p_down_last , p2p_down_head , p2p_down_data , p2p_down_ready, // 323
    st_reg_p2p_cfg_req_valid, st_reg_p2p_cfg_req_last , st_reg_p2p_cfg_req_head , st_reg_p2p_cfg_req_data , st_reg_p2p_cfg_req_ready, // 387
    mem_addr, nxt_chnl_sel, // 40
    
    p2p_tgt_req_valid, p2p_ini_req_valid, 
    p2p_tgt_req_last , p2p_ini_req_last , 
    p2p_tgt_req_data , p2p_ini_req_data , 
    p2p_tgt_req_head , p2p_ini_req_head , 
    p2p_tgt_req_ready, p2p_ini_req_ready  // 774
};
/* -------APB reated signal{end}------- */
`endif

/* -------- Related to demux {begin}-------- */
assign p2p_cfg_rrsp_valid = 0;
assign p2p_cfg_rrsp_last  = 0;
assign p2p_cfg_rrsp_data  = 0;

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
    .axis_tvalid ( p2p_cfg_req_valid ), // i, 1
    .axis_tlast  ( p2p_cfg_req_last  ), // i, 1
    .axis_tuser  ( p2p_cfg_req_head  ), // i, TUSER_WIDTH
    .axis_tdata  ( p2p_cfg_req_data  ), // i, TDATA_WIDTH
    .axis_tready ( p2p_cfg_req_ready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    .axis_reg_tvalid ( st_reg_p2p_cfg_req_valid ), // o, 1  // read valid from input register
    .axis_reg_tlast  ( st_reg_p2p_cfg_req_last  ), // o, 1 
    .axis_reg_tuser  ( st_reg_p2p_cfg_req_head  ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( st_reg_p2p_cfg_req_data  ), // o, TDATA_WIDTH
    .axis_reg_tready ( st_reg_p2p_cfg_req_ready )  // i, 1
    /* -------output in_reg inteface{end}------- */
);

assign mem_addr = p2p_cfg_req_head[63:32];
assign nxt_chnl_sel = p2p_cfg_req_valid ? (mem_addr >= `CFG_BAR_TGT_ADDR_BASE) : 0;
st_demux #(
    .CHNL_NUM     ( 2           ), // number of slave signals to arbit
    .CHNL_NUM_LOG ( 1           ),
    .TUSER_WIDTH  ( `P2P_HEAD_W ),
    .TDATA_WIDTH  ( `P2P_DATA_W )
) tgt_mem_demux (
    .clk      ( clk   ), // i, 1
    .rst_n    ( rst_n ), // i, 1

    .nxt_chnl_vld  ( p2p_cfg_req_valid ), // i, 1
    .nxt_chnl_sel  ( nxt_chnl_sel      ), // i, 8

    /* --------P2P Memory Access Channel In{begin}-------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    .s_axis_demux_valid  ( st_reg_p2p_cfg_req_valid ), // i, 1
    .s_axis_demux_last   ( st_reg_p2p_cfg_req_last  ), // i, 1
    .s_axis_demux_head   ( st_reg_p2p_cfg_req_head  ), // i, `P2P_HEAD_W
    .s_axis_demux_data   ( st_reg_p2p_cfg_req_data  ), // i, `P2P_DATA_W
    .s_axis_demux_ready  ( st_reg_p2p_cfg_req_ready ), // o, 1
    /* --------P2P Memory Access Channel In{end}-------- */

    /* --------P2P Memory Access Channel Out{begin}-------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    .m_axis_demux_valid  ( {p2p_tgt_req_valid, p2p_ini_req_valid} ), // o, 2 * 1
    .m_axis_demux_last   ( {p2p_tgt_req_last , p2p_ini_req_last } ), // o, 2 * 1
    .m_axis_demux_head   ( {p2p_tgt_req_head , p2p_ini_req_head } ), // o, 2 * `P2P_HEAD_W
    .m_axis_demux_data   ( {p2p_tgt_req_data , p2p_ini_req_data } ), // o, 2 * `P2P_DATA_W
    .m_axis_demux_ready  ( {p2p_tgt_req_ready, p2p_ini_req_ready} )  // i, 2 * 1
    /* --------P2P Memory Access Channel Out{end}-------- */
);
/* -------- Related to demux {end}-------- */

p2p_initiator #(
    
) p2p_initiator (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* --------P2P Configuration Channel{begin}-------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    .p2p_cfg_req_valid   ( p2p_ini_req_valid  ), // i, 1
    .p2p_cfg_req_last    ( p2p_ini_req_last   ), // i, 1
    .p2p_cfg_req_data    ( p2p_ini_req_data   ), // i, `P2P_DATA_W
    .p2p_cfg_req_head    ( p2p_ini_req_head   ), // i, `P2P_HEAD_W
    .p2p_cfg_req_ready   ( p2p_ini_req_ready  ), // o, 1
    /* --------P2P Configuration Channel{end}-------- */

    /* --------P2P DMA Write Req{begin}-------- */
    /* dma_*_head, valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    .p2p_dma_wr_req_valid ( p2p_dma_wr_req_valid ), // o, 1             
    .p2p_dma_wr_req_last  ( p2p_dma_wr_req_last  ), // o, 1             
    .p2p_dma_wr_req_data  ( p2p_dma_wr_req_data  ), // o, `P2P_DATA_W  
    .p2p_dma_wr_req_head  ( p2p_dma_wr_req_head  ), // o, `DMA_HEAD_W
    .p2p_dma_wr_req_ready ( p2p_dma_wr_req_ready ), // i, 1        
    /* --------P2P DMA Write Req{end}-------- */

    /* --------p2p forward up channel{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved |dst_dev| src_dev | Reserved | Byte length |
     * |  63:-    | 47:40 |  39:32  |  31:16   |    15:0     |
     */
    .p2p_upper_valid ( p2p_upper_valid ), // i, 1             
    .p2p_upper_last  ( p2p_upper_last  ), // i, 1             
    .p2p_upper_data  ( p2p_upper_data  ), // i, `P2P_DATA_W  
    .p2p_upper_head  ( p2p_upper_head  ), // i, `P2P_UHEAD_W
    .p2p_upper_ready ( p2p_upper_ready )  // o, 1        
    /* --------p2p forward up channel{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.rw_data ( ini_rw_data ) // i, `SRAM_RW_DATA_W
    ,.dbg_sel ( dbg_sel_ini ) // i, 32
    ,.dbg_bus ( dbg_bus_ini ) // o, 32
    /* -------APB reated signal{end}------- */
`endif
);

p2p_target #(
    
) p2p_target (

    .clk      ( clk      ), // i, 1
    .rst_n    ( rst_n    ), // i, 1
    .init_end ( init_done ), // o, 1
    
    /* --------P2P Configuration Channel{begin}-------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    .p2p_cfg_req_valid   ( p2p_tgt_req_valid  ), // i, 1
    .p2p_cfg_req_last    ( p2p_tgt_req_last   ), // i, 1
    .p2p_cfg_req_data    ( p2p_tgt_req_data   ), // i, `P2P_DATA_W
    .p2p_cfg_req_head    ( p2p_tgt_req_head   ), // i, `P2P_HEAD_W
    .p2p_cfg_req_ready   ( p2p_tgt_req_ready  ), // o, 1
    /* --------P2P Configuration Channel{end}-------- */

    /* -------P2P Stream Channel{begin}-------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    .p2p_mem_req_valid   ( p2p_mem_req_valid ), // i, 1
    .p2p_mem_req_last    ( p2p_mem_req_last  ), // i, 1
    .p2p_mem_req_data    ( p2p_mem_req_data  ), // i, `P2P_DATA_W
    .p2p_mem_req_head    ( p2p_mem_req_head  ), // i, `P2P_HEAD_W
    .p2p_mem_req_ready   ( p2p_mem_req_ready ), // o, 1
    /* -------P2P Stream Channel{end}-------- */

    /* --------p2p forward down channel{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved |dst_dev| src_dev | Reserved | Byte length |
     * |  63:-    | 47:40 |  39:32  |  31:16   |    15:0     |
     */
    .p2p_down_valid ( p2p_down_valid ), // o, 1             
    .p2p_down_last  ( p2p_down_last  ), // o, 1             
    .p2p_down_data  ( p2p_down_data  ), // o, `P2P_DATA_W  
    .p2p_down_head  ( p2p_down_head  ), // o, `P2P_DHEAD_W
    .p2p_down_ready ( p2p_down_ready )  // i, 1        
    /* --------p2p forward down channel{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.rw_data ( tgt_rw_data ) // i, (2*`QUEUE_NUM+3)*`SRAM_RW_DATA_W
    ,.dbg_sel ( dbg_sel_tgt ) // i, 32
    ,.dbg_bus ( dbg_bus_tgt ) // o, 32
    /* -------APB reated signal{end}------- */
`endif
);

endmodule // P2P
