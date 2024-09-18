`timescale 1ns / 100ps
//*************************************************************************
// > File Name: ini_dev2addr_table.v
// > Author   : Kangning
// > Date     : 2022-07-19
// > Note     : dev -> addr table that translate dev number into address.
//*************************************************************************


module ini_dev2addr_table #(
    
) (
    input  wire clk   , // i, 1
    input  wire rst_n , // i, 1

    /* --------P2P Configuration Channel In{begin}-------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    input  wire  [1           - 1 : 0] p2p_cfg_req_valid, // i, 1
    input  wire  [1           - 1 : 0] p2p_cfg_req_last , // i, 1
    input  wire  [`P2P_DATA_W - 1 : 0] p2p_cfg_req_data , // i, `P2P_DATA_W
    input  wire  [`P2P_HEAD_W - 1 : 0] p2p_cfg_req_head , // i, `P2P_HEAD_W
    output wire  [1           - 1 : 0] p2p_cfg_req_ready, // o, 1
    
    // output wire [1           - 1 : 0] p2p_cfg_rrsp_valid, // o, 1
    // output wire [1           - 1 : 0] p2p_cfg_rrsp_last , // o, 1
    // output wire [`P2P_DATA_W - 1 : 0] p2p_cfg_rrsp_data , // o, `P2P_DATA_W
    // input  wire [1           - 1 : 0] p2p_cfg_rrsp_ready, // i, 1
    /* --------P2P Configuration Channel In{end}-------- */

    /* --------p2p forward up channel{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved |dst_dev| src_dev | Reserved | Byte length |
     * |  63:-    | 47:40 |  39:32  |  31:16   |    15:0     |
     */
    input  wire [1            - 1 : 0] p2p_upper_valid, // i, 1             
    input  wire [1            - 1 : 0] p2p_upper_last , // i, 1     
    input  wire [`P2P_UHEAD_W - 1 : 0] p2p_upper_head , // i, `P2P_UHEAD_W
    input  wire [1            - 1 : 0] p2p_upper_ready, // i, 1        
    /* --------p2p forward up channel{end}-------- */

    /* --------Output to dst_***_proc{begin}-------- */
    output wire [1                    - 1 : 0] is_valid     , // o, 1
    output wire [`DEV_TYPE_WIDTH      - 1 : 0] dev_type     , // o, `DEV_TYPE_WIDTH
    output wire [`BAR_ADDR_BASE_WIDTH - 1 : 0] bar_pyld_addr, // o, `BAR_ADDR_BASE_WIDTH, lower 14 bit is invaliid
    input  wire                                is_ready       // i, 1
    /* --------Output to dst_***_proc{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [`SRAM_RW_DATA_W-1:0] rw_data  // i, `SRAM_RW_DATA_W
    ,output wire [`INI_DEV2ADDR_SIGNAL_W-1:0] dbg_signal  // o, `INI_DEV2ADDR_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

localparam DEV2ADDR_TAB_WIDTH = 1 + `BAR_ADDR_BASE_WIDTH  + `DEV_TYPE_WIDTH + `DEV_NUM_WIDTH; // 63

/* -------- related write interface{begin}-------- */
wire wr_en;

wire cfg_wr;

wire [31:0] bar0_addr;
wire [`D2A_TAB_DEPTH    -1: 0] wr_addr;
wire [DEV2ADDR_TAB_WIDTH-1: 0] wr_data;
wire [`BAR_ADDR_BASE_WIDTH-1:0] wr_bar_pyld_addr;
wire [`DEV_TYPE_WIDTH     -1:0] wr_dev_type;
wire [`DEV_NUM_WIDTH      -1:0] wr_dev_num ;
/* -------- related write interface{end}-------- */

/* -------- related read interface{begin}-------- */
reg p2p_upper_sop;

wire rd_en;
// reg  rd_en_reg;
wire [`DEV_TYPE_WIDTH-1:0] dst_dev;
wire [`DEV_NUM_WIDTH -1:0] dev_num;
wire [DEV2ADDR_TAB_WIDTH-1:0] rd_data;
/* -------- related to read interface{end}-------- */

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
assign dbg_signal = { // 240
    wr_en, cfg_wr, bar0_addr, // 34
    wr_addr, wr_data, wr_bar_pyld_addr, wr_dev_type, wr_dev_num , // 129
    p2p_upper_sop, rd_en, dst_dev, dev_num, rd_data // 77
};
/* -------APB reated signal{end}------- */
`endif

/* -------- related write interface{begin}-------- */
assign bar0_addr = p2p_cfg_req_head[63:32];
assign cfg_wr    = p2p_cfg_req_head[127];

assign wr_en     = p2p_cfg_req_valid & p2p_cfg_req_ready & cfg_wr & (bar0_addr[19:`D2A_TAB_DEPTH + 4] == (`CFG_BAR_INI_ADDR_BASE >> (4 + `D2A_TAB_DEPTH)));
assign wr_addr   = wr_en ? bar0_addr[`D2A_TAB_DEPTH + 4 - 1 : 4] : 0;
assign wr_dev_num       = p2p_cfg_req_data[7:0];
assign wr_dev_type      = p2p_cfg_req_data[11:8];
assign wr_bar_pyld_addr = p2p_cfg_req_data[63:14];
assign wr_data          = {1'd1, wr_bar_pyld_addr, wr_dev_type, wr_dev_num};
/* -------- related write interface{end}-------- */

/* -------- related read interface{begin}-------- */
assign dst_dev = p2p_upper_head[32+2*`DEV_NUM_WIDTH-1:32+`DEV_NUM_WIDTH];
assign rd_en   = p2p_upper_sop & p2p_upper_valid & p2p_upper_ready;
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        p2p_upper_sop <= `TD 1'd1;
    end
    else if (p2p_upper_valid & p2p_upper_ready & p2p_upper_last) begin
        p2p_upper_sop <= `TD 1'd1;
    end
    else if (p2p_upper_valid & p2p_upper_ready) begin
        p2p_upper_sop <= `TD 1'd0;
    end
end

// always @(posedge clk, negedge rst_n) begin
//     if (~rst_n) begin
//         rd_en_reg <= `TD 1'd0;
//     end
//     else if (rd_en) begin
//         rd_en_reg <= `TD 1'd1;
//     end
//     else if (is_ready) begin
//         rd_en_reg <= `TD 1'd0;
//     end
// end
/* -------- related to read interface{end}-------- */

pcieifc_sd_sram #(
    .DATAWIDTH  ( DEV2ADDR_TAB_WIDTH ), // Memory data word width, 63
    .ADDRWIDTH  ( `D2A_TAB_DEPTH     )  // Number of mem address bits, 4
) dev2addr_tab (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    .wea   ( wr_en   ), // i, 1; high active
    .addra ( wr_addr ), // i, ADDRWIDTH
    .dina  ( wr_data ), // i, DATAWIDTH

    .reb   ( rd_en   ), // i, 1
    .addrb ( dst_dev ), // i, ADDRWIDTH
    .doutb ( rd_data )  // o, DATAWIDTH

`ifdef PCIEI_APB_DBG
    ,.rtsel ( rtsel )  // i, 2
    ,.wtsel ( wtsel )  // i, 2
    ,.ptsel ( ptsel )  // i, 2
    ,.vg    ( vg    )  // i, 1
    ,.vs    ( vs    )  // i, 1
`endif
);

assign {is_valid, bar_pyld_addr, dev_type, dev_num} = rd_data; // rd_en_reg ? rd_data : 0;
/* --------CFG interface{begin}-------- */
assign p2p_cfg_req_ready = !rd_en;

// We don't support cfg space read.
// assign p2p_cfg_rrsp_valid = 0;
// assign p2p_cfg_rrsp_last  = 0;
// assign p2p_cfg_rrsp_data  = 0;
/* --------CFG interface{end}-------- */

endmodule