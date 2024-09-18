`timescale 1ns / 100ps
//*************************************************************************
// > File   : p2p_initiator.v
// > Author : Kangning
// > Date   : 2022-06-10
// > Note   : DMA P2P initiator
//*************************************************************************

module p2p_initiator #(
    
) (
    input  wire clk   , // i, 1
    input  wire rst_n , // i, 1

    /* --------P2P Configuration Channel{begin}-------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    input  wire [1           - 1 : 0] p2p_cfg_req_valid, // i, 1
    input  wire [1           - 1 : 0] p2p_cfg_req_last , // i, 1
    input  wire [`P2P_HEAD_W - 1 : 0] p2p_cfg_req_head , // i, `P2P_HEAD_W
    input  wire [`P2P_DATA_W - 1 : 0] p2p_cfg_req_data , // i, `P2P_DATA_W
    output wire [1           - 1 : 0] p2p_cfg_req_ready, // o, 1
    
    // output wire [1           - 1 : 0] p2p_cfg_rrsp_valid, // o, 1
    // output wire [1           - 1 : 0] p2p_cfg_rrsp_last , // o, 1
    // output wire [`P2P_DATA_W - 1 : 0] p2p_cfg_rrsp_data , // o, `P2P_DATA_W
    // input  wire [1           - 1 : 0] p2p_cfg_rrsp_ready, // i, 1
    /* --------P2P Configuration Channel{end}-------- */

    /* --------P2P DMA Write Req{begin}-------- */
    /* dma_*_head
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
    output wire [1            - 1 : 0] p2p_upper_ready  // o, 1               
    /* --------p2p forward up channel{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [`SRAM_RW_DATA_W-1:0] rw_data  // i, `SRAM_RW_DATA_W
    ,input  wire [31:0] dbg_sel  // i, 32
    ,output wire [31:0] dbg_bus  // o, 32
    /* -------APB reated signal{end}------- */
`endif
);

// /* -------next pkt information{begin}-------- */
// wire                                nxt_is_valid; // i, 1
// wire [`DEV_TYPE_WIDTH      - 1 : 0] nxt_dev_type; // i, `DEV_TYPE_WIDTH
// wire [`BAR_ADDR_BASE_WIDTH - 1 : 0] nxt_bar_addr; // i, `BAR_ADDR_BASE_WIDTH
// /* -------next pkt information{end}-------- */

/* --------current pkt information{begin}-------- */
wire                                is_valid; // i, 1
wire [`DEV_TYPE_WIDTH      - 1 : 0] dev_type; // i, `DEV_TYPE_WIDTH
wire [`BAR_ADDR_BASE_WIDTH - 1 : 0] bar_addr; // i, `BAR_ADDR_BASE_WIDTH
/* --------current pkt information{end}-------- */

/* --------current pkt information{begin}-------- */
wire                                st1_is_valid; // i, 1
wire [`DEV_TYPE_WIDTH      - 1 : 0] st1_dev_type; // i, `DEV_TYPE_WIDTH
wire [`BAR_ADDR_BASE_WIDTH - 1 : 0] st1_bar_addr; // i, `BAR_ADDR_BASE_WIDTH
/* --------current pkt information{end}-------- */

/* -------Related to NIC and DSA module{begin}-------- */
wire                        st0_upper_valid;
wire                        st0_upper_last ;
wire [`P2P_UHEAD_W - 1 : 0] st0_upper_head ;
wire [`P2P_DATA_W  - 1 : 0] st0_upper_data ;
wire                        st0_upper_ready;

wire                        st1_upper_valid;
wire                        st1_upper_last ;
wire [`P2P_UHEAD_W - 1 : 0] st1_upper_head ;
wire [`P2P_DATA_W  - 1 : 0] st1_upper_data ;
wire                        st1_upper_ready;
/* -------Related to NIC and DSA module{end}-------- */

/* -------MUX -> pyld_split_proc{begin}------- */
/* dma_*_head
 * | Reserved | address | Reserved | Byte length |
 * |  127:96  |  95:32  |  31:16   |    15:0     |
 */
wire                       axis_proc_out_valid; // o, 1 
wire                       axis_proc_out_last ; // o, 1 
wire [`DMA_HEAD_W - 1 : 0] axis_proc_out_head ; // o, `DMA_HEAD_W
wire [`P2P_DATA_W - 1 : 0] axis_proc_out_data ; // o, `P2P_DATA_W
wire                       axis_proc_out_ready; // i, 1
/* -------MUX -> pyld_split_proc{end}------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire [`INI_TOP_SIGNAL_W-1:0] dbg_signal_ini_top;
wire [`INI_DEV2ADDR_SIGNAL_W-1:0] dbg_signal_ini_dev2addr;
/* -------APB reated signal{end}------- */
`endif

//-------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */

// Debug bus for p2p ini
assign dbg_bus = {dbg_signal_ini_top, dbg_signal_ini_dev2addr} >> {dbg_sel, 5'd0};

// Debug signal for p2p ini top
assign dbg_signal_ini_top = { // 1143

    is_valid, dev_type, bar_addr, // 55
    st1_is_valid, st1_dev_type, st1_bar_addr, // 55
    st0_upper_valid, st0_upper_last , st0_upper_head , st0_upper_data , st0_upper_ready, // 323
    st1_upper_valid, st1_upper_last , st1_upper_head , st1_upper_data , st1_upper_ready, // 323
    axis_proc_out_valid, axis_proc_out_last , axis_proc_out_head , axis_proc_out_data , axis_proc_out_ready // 387
};
/* -------APB reated signal{end}------- */
`endif

ini_dev2addr_table #(
    
) ini_dev2addr_table (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* --------P2P Configuration Channel In{begin}-------- */
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
    /* --------P2P Configuration Channel In{end}-------- */

    /* --------p2p forward up channel{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved |dst_dev| src_dev | Reserved | Byte length |
     * |  63:-    | 47:40 |  39:32  |  31:16   |    15:0     |
     */
    .p2p_upper_valid ( p2p_upper_valid ), // i, 1             
    .p2p_upper_last  ( p2p_upper_last  ), // i, 1     
    .p2p_upper_head  ( p2p_upper_head  ), // i, `P2P_UHEAD_W
    .p2p_upper_ready ( p2p_upper_ready ), // i, 1        
    /* --------p2p forward up channel{end}-------- */

    /* --------Output to dst_***_proc{begin}-------- */
    .is_valid      ( is_valid ), // o, 1
    .dev_type      ( dev_type ), // o, 4
    .bar_pyld_addr ( bar_addr ), // o, 64, lower 14 bit is invaliid
    .is_ready      ( st0_upper_ready )  // i, 1
    /* --------Output to dst_***_proc{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.rw_data    ( rw_data                 ) // i, `SRAM_RW_DATA_W
    ,.dbg_signal ( dbg_signal_ini_dev2addr ) // o, `INI_DEV2ADDR_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

/* 
 * This reg is used to stall for looking up the dev2addr table
 */
st_reg #(
    .TUSER_WIDTH ( `P2P_UHEAD_W ),
    .TDATA_WIDTH ( `P2P_DATA_W  ),
    .MODE        ( 1            )
) st_reg0 (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( p2p_upper_valid ), // i, 1
    .axis_tlast  ( p2p_upper_last  ), // i, 1
    .axis_tuser  ( p2p_upper_head  ), // i, TUSER_WIDTH
    .axis_tdata  ( p2p_upper_data  ), // i, TDATA_WIDTH
    .axis_tready ( p2p_upper_ready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .axis_reg_tvalid ( st0_upper_valid ), // o, 1  // read valid from input register
    .axis_reg_tlast  ( st0_upper_last  ), // o, 1 
    .axis_reg_tuser  ( st0_upper_head  ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( st0_upper_data  ), // o, TDATA_WIDTH
    .axis_reg_tready ( st0_upper_ready )  // i, 1
    /* -------output in_reg inteface{end}------- */
);

st_reg #(
    .TUSER_WIDTH ( 1 + `DEV_TYPE_WIDTH + `BAR_ADDR_BASE_WIDTH + `P2P_UHEAD_W ),
    .TDATA_WIDTH ( `P2P_DATA_W   ),
    .MODE        ( 1             )
) st_reg1 (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( st0_upper_valid ), // i, 1
    .axis_tlast  ( st0_upper_last  ), // i, 1
    .axis_tuser  ( {is_valid, dev_type, bar_addr, st0_upper_head}  ), // i, TUSER_WIDTH
    .axis_tdata  ( st0_upper_data  ), // i, TDATA_WIDTH
    .axis_tready ( st0_upper_ready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .axis_reg_tvalid ( st1_upper_valid ), // o, 1  // read valid from input register
    .axis_reg_tlast  ( st1_upper_last  ), // o, 1 
    .axis_reg_tuser  ( {st1_is_valid, st1_dev_type, st1_bar_addr, st1_upper_head}  ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( st1_upper_data  ), // o, TDATA_WIDTH
    .axis_reg_tready ( st1_upper_ready )  // i, 1
    /* -------output in_reg inteface{end}------- */
);

ini_dst_nic_proc #(

) ini_dst_nic_proc (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* -------next pkt information{begin}-------- */
    .nxt_is_valid ( is_valid & st0_upper_valid ), // i, 1
    .nxt_dev_type ( dev_type ), // i, `DEV_TYPE_WIDTH
    .nxt_bar_addr ( bar_addr ), // i, `BAR_ADDR_BASE_WIDTH
    /* -------next pkt information{end}-------- */

    /* --------p2p forward up channel{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved |dst_dev| src_dev | Reserved | Byte length |
     * |  63:-    | 47:40 |  39:32  |  31:16   |    15:0     |
     */
    .p2p_upper_valid ( st1_upper_valid ), // i, 1             
    .p2p_upper_last  ( st1_upper_last  ), // i, 1     
    .p2p_upper_head  ( st1_upper_head  ), // i, `P2P_UHEAD_W        
    .p2p_upper_data  ( st1_upper_data  ), // i, `P2P_DATA_W  
    .p2p_upper_ready ( st1_upper_ready ), // o, 1        
    /* --------p2p forward up channel{end}-------- */

    /* --------current pkt information{begin}-------- */
    .is_valid ( st1_is_valid ), // i, 1
    .dev_type ( st1_dev_type ), // i, `DEV_TYPE_WIDTH
    .bar_addr ( st1_bar_addr ), // i, `BAR_ADDR_BASE_WIDTH
    /* --------current pkt information{end}-------- */

    /* -------output inteface{begin}------- */
    /* dma_*_head
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:16   |    15:0     |
     */
    .axis_nic_valid ( axis_proc_out_valid ), // o, 1 
    .axis_nic_last  ( axis_proc_out_last  ), // o, 1 
    .axis_nic_head  ( axis_proc_out_head  ), // o, `DMA_HEAD_W
    .axis_nic_data  ( axis_proc_out_data  ), // o, `P2P_DATA_W
    .axis_nic_ready ( axis_proc_out_ready )  // i, 1
    /* -------output inteface{end}------- */
);

ini_pyld_split_proc #(
    
) ini_pyld_split_proc (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* --------raw pyld{begin}-------- */
    /* dma_*_head
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:16   |    15:0     |
     */
    .axis_raw_valid ( axis_proc_out_valid ), // o, 1
    .axis_raw_last  ( axis_proc_out_last  ), // o, 1
    .axis_raw_head  ( axis_proc_out_head  ), // o, `DMA_HEAD_W 
    .axis_raw_data  ( axis_proc_out_data  ), // o, `P2P_DATA_W
    .axis_raw_ready ( axis_proc_out_ready ), // i, 1
    /* --------raw pyld{end}-------- */

    /* --------splited_pyld{begin}-------- */
    /* dma_*_head
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    .axis_splited_valid ( p2p_dma_wr_req_valid ), // o, 1
    .axis_splited_last  ( p2p_dma_wr_req_last  ), // o, 1
    .axis_splited_head  ( p2p_dma_wr_req_head  ), // o, `DMA_HEAD_W 
    .axis_splited_data  ( p2p_dma_wr_req_data  ), // o, `P2P_DATA_W
    .axis_splited_ready ( p2p_dma_wr_req_ready )  // i, 1
    /* --------splited_pyld{end}-------- */
);

endmodule // p2p_initiator
