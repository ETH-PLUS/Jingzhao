`timescale 1ns / 100ps
//*************************************************************************
// > File   : pio_req.v
// > Author : Kangning
// > Date   : 2022-03-12
// > Note   : Distributor for write request.
// >          V1.1 2022-06-08: Now, It demux the channel by the address information
//*************************************************************************

module pio_req #(
    parameter CHANNEL_NUM     = 6
) (
    input wire clk  , // i, 1
    input wire rst_n, // i, 1

    /* --------PIO Request interface{begin}-------- */
    /* pio_tuser
     * |  139  | 138:136 |  135:132 | 131:128 |    127:96    |   95:0  |
     * | is_wr | bar_id  | first_be | last_be | aligned_addr | cc_head |
     * |       |         |          |         |              |         |
     */
    input  wire [`PIO_DATA_W-1:0] s_axis_req_tdata , // i, `PIO_DATA_W
    input  wire [`PIO_USER_W-1:0] s_axis_req_tuser , // i, `PIO_USER_W
    input  wire                   s_axis_req_tlast , // i, 1
    input  wire                   s_axis_req_tvalid, // i, 1
    output wire                   s_axis_req_tready, // o, 1

    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    output wire [CHANNEL_NUM * `PIO_DATA_W-1:0] m_axis_req_data , // o, CHANNEL_NUM * `PIO_DATA_W
    output wire [CHANNEL_NUM * `PIO_HEAD_W-1:0] m_axis_req_head , // o, CHANNEL_NUM * `PIO_HEAD_W
    output wire [CHANNEL_NUM * 1          -1:0] m_axis_req_last , // o, CHANNEL_NUM * 1
    output wire [CHANNEL_NUM * 1          -1:0] m_axis_req_valid, // o, CHANNEL_NUM * 1
    input  wire [CHANNEL_NUM * 1          -1:0] m_axis_req_ready  // i, CHANNEL_NUM * 1
    /* --------PIO Request interface{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [31:0] dbg_sel  // debug bus select
    ,output wire [31:0] dbg_bus  // debug bus data    
    /* -------APB reated signal{end}------- */
`endif
);

wire        is_wr;
wire [2:0]  bar_id;
wire [31:0] addr;
wire [95:0] cc_head;
wire [`PIO_HEAD_W-1:0] s_axis_req_thead;

wire [2:0]  chnl_sel;

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire [`PIO_REQ_SIGNAL_W  -1:0] dbg_signal_pio_req;
wire [`PIO_DEMUX_SIGNAL_W-1:0] dbg_signal_pio_demux;
/* -------APB reated signal{end}------- */
`endif

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */

assign dbg_bus = dbg_signal_pio_req >> {dbg_sel, 5'd0};

assign dbg_signal_pio_req = { // 276
    is_wr, bar_id, addr, cc_head, // 132
    s_axis_req_thead, // 132
    chnl_sel, // 3
    dbg_signal_pio_demux // 9
};
/* -------APB reated signal{end}------- */
`endif

assign is_wr    = s_axis_req_tuser[139];
assign bar_id   = s_axis_req_tuser[138:136];
assign addr     = s_axis_req_tuser[127:96];
assign cc_head  = s_axis_req_tuser[95:0];
assign s_axis_req_thead = {is_wr, bar_id, addr[31:0], cc_head};

// Channel 5 : UAR Space
// Channel 4 : P2P MEM Space
// Channel 3 : P2P CFG Space
// Channel 2 : HCA MSI-X Interrupt Vector Table
// Channel 1 : Ethernet Interface
// Channel 0 : HCR CFG Space
assign chnl_sel = (bar_id[1] == 1'd1) ? 
                    (
                        3'd5 // UAR(BAR2-3) Space
                    ) 
                    :
                    (
                    ((`P2P_MEM_BASE <= addr[`BAR0_WIDTH-1:0]) & (addr[`BAR0_WIDTH-1:0] < `P2P_MEM_BASE + `P2P_MEM_LEN)) ? 3'd4 : // P2P MEM Space
                    ((`P2P_CFG_BASE <= addr[`BAR0_WIDTH-1:0]) & (addr[`BAR0_WIDTH-1:0] < `P2P_CFG_BASE + `P2P_CFG_LEN)) ? 3'd3 : // P2P CFG Space
                    ((`HCA_INT_BASE <= addr[`BAR0_WIDTH-1:0]) & (addr[`BAR0_WIDTH-1:0] < `HCA_INT_BASE + `HCA_INT_LEN)) ? 3'd2 : // HCA MSI-X Interrupt Vector Table
                    ((`ETH_INT_BASE <= addr[`BAR0_WIDTH-1:0]) & (addr[`BAR0_WIDTH-1:0] < `ETH_INT_BASE + `ETH_INT_LEN)) ? 3'd1 : // Ethernet Interface
                    ((`ETH_BASE     <= addr[`BAR0_WIDTH-1:0]) & (addr[`BAR0_WIDTH-1:0] < `ETH_BASE     + `ETH_LEN    )) ? 3'd1 : // Ethernet Interface
                                                                                                                          3'd0   // HCR CFG Space && space not hit channels above
                    );

pio_demux #(
    .OUT_CHNL_NUM ( CHANNEL_NUM )
) pio_demux (
    .clk             ( clk       ), // i, 1
    .rst_n           ( rst_n     ), // i, 1

    .demux_sel       ( chnl_sel ), // i, 3

    /* --------PIO Write Request interface{begin}-------- */
    /* head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    .s_axis_req_data   ( s_axis_req_tdata  ), // i, `PIO_DATA_W
    .s_axis_req_head   ( s_axis_req_thead  ), // i, `PIO_HEAD_W
    .s_axis_req_last   ( s_axis_req_tlast  ), // i, 1
    .s_axis_req_valid  ( s_axis_req_tvalid ), // i, 1
    .s_axis_req_ready  ( s_axis_req_tready ), // o, 1

    /* head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    .m_axis_req_data   ( m_axis_req_data  ), // o, CHANNEL_NUM * `PIO_DATA_W
    .m_axis_req_head   ( m_axis_req_head  ), // o, CHANNEL_NUM * `PIO_HEAD_W
    .m_axis_req_last   ( m_axis_req_last  ), // o, CHANNEL_NUM * 1
    .m_axis_req_valid  ( m_axis_req_valid ), // o, CHANNEL_NUM * 1
    .m_axis_req_ready  ( m_axis_req_ready )  // i, CHANNEL_NUM * 1
    /* --------PIO Write Request interface{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_signal ( dbg_signal_pio_demux ) // o, `PIO_DEMUX_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

endmodule