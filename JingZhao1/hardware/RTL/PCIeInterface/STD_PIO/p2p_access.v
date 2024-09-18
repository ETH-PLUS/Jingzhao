`timescale 1ns / 100ps
//*************************************************************************
// > File   : p2p_access.v
// > Author : Kangning
// > Date   : 2022-06-10
// > Note   : Interface for p2p access.
//*************************************************************************

module p2p_access #(
    
) (
    input  wire clk  , // i, 1
    input  wire rst_n, // i, 1

    /* --------Req Channel{begin}-------- */
    /* req_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    input  wire [1          -1:0] pio_p2p_mem_req_valid, // i, 1             
    input  wire [1          -1:0] pio_p2p_mem_req_last , // i, 1             
    input  wire [`PIO_DATA_W-1:0] pio_p2p_mem_req_data , // i, `PIO_DATA_W
    input  wire [`PIO_HEAD_W-1:0] pio_p2p_mem_req_head , // i, `PIO_HEAD_W
    output wire [1          -1:0] pio_p2p_mem_req_ready, // o, 1             
    /* --------Req Channel{end}-------- */

    /* --------Req Channel{begin}-------- */
    /* req_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    input  wire [1          -1:0] pio_p2p_cfg_req_valid, // i, 1             
    input  wire [1          -1:0] pio_p2p_cfg_req_last , // i, 1             
    input  wire [`PIO_DATA_W-1:0] pio_p2p_cfg_req_data , // i, `PIO_DATA_W
    input  wire [`PIO_HEAD_W-1:0] pio_p2p_cfg_req_head , // i, `PIO_HEAD_W
    output wire [1          -1:0] pio_p2p_cfg_req_ready, // o, 1             
    /* --------Req Channel{end}-------- */

    /* --------Rsp Channel{begin}-------- */
    /* req_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    output  wire [1          -1:0] pio_p2p_rrsp_valid, // o, 1             
    output  wire [1          -1:0] pio_p2p_rrsp_last , // o, 1             
    output  wire [`PIO_DATA_W-1:0] pio_p2p_rrsp_data , // o, `PIO_DATA_W
    output  wire [`PIO_HEAD_W-1:0] pio_p2p_rrsp_head , // o, `PIO_HEAD_W
    input   wire [1          -1:0] pio_p2p_rrsp_ready, // 1, 1             
    /* --------Rsp Channel{end}-------- */

    /* --------P2P Configuration Channel{begin}-------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    output wire [1          -1:0] p2p_cfg_req_valid, // o, 1
    output wire [1          -1:0] p2p_cfg_req_last , // o, 1
    output wire [`PIO_DATA_W-1:0] p2p_cfg_req_data , // o, `PIO_DATA_W
    output wire [`P2P_HEAD_W-1:0] p2p_cfg_req_head , // o, `P2P_HEAD_W
    input  wire [1          -1:0] p2p_cfg_req_ready, // i, 1
    
    input  wire [1          -1:0] p2p_cfg_rrsp_valid, // i, 1
    input  wire [1          -1:0] p2p_cfg_rrsp_last , // i, 1
    input  wire [`PIO_DATA_W-1:0] p2p_cfg_rrsp_data , // i, `PIO_DATA_W
    output wire [1          -1:0] p2p_cfg_rrsp_ready, // o, 1
    /* --------P2P Configuration Channel{end}-------- */

    /* -------P2P Memory Access Channel{begin}-------- */
    /* p2p_req head
     * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
     * | is_wr | Reserved | addr  | Reserved | byte_len |
     */
    output wire [1          -1:0] p2p_mem_req_valid, // o, 1
    output wire [1          -1:0] p2p_mem_req_last , // o, 1
    output wire [`PIO_DATA_W-1:0] p2p_mem_req_data , // o, `PIO_DATA_W
    output wire [`P2P_HEAD_W-1:0] p2p_mem_req_head , // o, `P2P_HEAD_W
    input  wire [1          -1:0] p2p_mem_req_ready  // i, 1
    /* -------P2P Memory Access Channel{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [31:0] dbg_sel  // debug bus select
    ,output wire [31:0] dbg_bus  // debug bus data    
    /* -------APB reated signal{end}------- */
`endif
);

wire p2p_full, p2p_empty;

/* --------Input Head parser{begin}-------- */
wire [12:0] p2p_mem_byte_cnt;
wire [31:0] p2p_mem_addr;

wire        p2p_cfg_is_wr; // Valid even in idle state

wire [12:0] p2p_cfg_byte_cnt;
wire [31:0] p2p_cfg_addr;
reg  [`PIO_HEAD_W-1:0] cfg_req_head;
wire [`PIO_HEAD_W-1:0] cfg_rrsp_head;
/* --------Input Head parser{end}-------- */

/* -------Generated stream signal{begin}------- */
wire [1          -1:0] in_cfg_req_valid;
wire [1          -1:0] in_cfg_req_last ;
wire [`P2P_HEAD_W-1:0] in_cfg_req_head ;
wire [`PIO_DATA_W-1:0] in_cfg_req_data ;
wire [1          -1:0] in_cfg_req_ready;

wire [1          -1:0] in_mem_req_valid;
wire [1          -1:0] in_mem_req_last ;
wire [`P2P_HEAD_W-1:0] in_mem_req_head ;
wire [`PIO_DATA_W-1:0] in_mem_req_data ;
wire [1          -1:0] in_mem_req_ready;
/* -------Generated stream signal{end}------- */


/* --------Related to FSM{begin}-------- */
localparam      IDLE           = 4'b0001,
                TRANS_WREQ_CFG = 4'b0010, // Supports arbitrary write size
                TRANS_RREQ_CFG = 4'b0100, // Supports only 64-bit read
                TRANS_RRSP_CFG = 4'b1000; // Supports only 64-bit read

reg [3:0] cur_state;
reg [3:0] nxt_state;

wire is_idle, is_trans_wreq_cfg, is_trans_rreq_cfg, is_trans_rrsp_cfg;
wire j_idle, j_trans_wreq_cfg, j_trans_rreq_cfg, j_trans_rrsp_cfg;
/* --------Related to FSM{end}-------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire [`P2P_ACCESS_SIGNAL_W-1:0] dbg_signal_p2p_access;
/* -------APB reated signal{end}------- */
`endif

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */

assign dbg_bus = dbg_signal_p2p_access >> {dbg_sel, 5'd0};

assign dbg_signal_p2p_access = { // 1147
    p2p_full, p2p_empty, // 2
    p2p_mem_byte_cnt, p2p_mem_addr, // 45
    p2p_cfg_is_wr, // 1
    p2p_cfg_byte_cnt, p2p_cfg_addr, cfg_req_head, cfg_rrsp_head, // 309
    in_cfg_req_valid, in_cfg_req_last , in_cfg_req_head , in_cfg_req_data , in_cfg_req_ready, // 387
    in_mem_req_valid, in_mem_req_last , in_mem_req_head , in_mem_req_data , in_mem_req_ready, // 387
    cur_state, nxt_state, // 8
    is_idle, is_trans_wreq_cfg, is_trans_rreq_cfg, is_trans_rrsp_cfg, // 4
    j_idle, j_trans_wreq_cfg, j_trans_rreq_cfg, j_trans_rrsp_cfg // 4
};
/* -------APB reated signal{end}------- */
`endif

/* -------P2P CFG Fifo{begin}------- */
pcieifc_sync_fifo #(
    .DSIZE ( `PIO_HEAD_W ), // 132
    .ASIZE ( 2  ) // 4 depth
) p2p_cfg_sync_fifo (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1
    .clr   ( 1'd0  ), // i, 1

    .wen   ( is_trans_rreq_cfg & in_cfg_req_valid & in_cfg_req_ready  ), // i, 1
    .din   ( cfg_req_head  ), // i, DSIZE
    .full  ( p2p_full  ), // o, 1

    .ren   ( is_trans_rrsp_cfg & pio_p2p_rrsp_valid & pio_p2p_rrsp_ready ), // i, 1
    .dout  ( cfg_rrsp_head ), // o, DSIZE
    .empty ( p2p_empty     )  // o, 1

`ifdef PCIEI_APB_DBG
    ,.rtsel ( 2'b0 )  // i, 2
    ,.wtsel ( 2'b0 )  // i, 2
    ,.ptsel ( 2'b0 )  // i, 2
    ,.vg    ( 1'b0 )  // i, 1
    ,.vs    ( 1'b0 )  // i, 1
`endif
);
/* --------P2P CFG Fifo{end}-------- */

/* --------Input Head parser{begin}-------- */
assign p2p_mem_byte_cnt = pio_p2p_mem_req_head[28:16];
assign p2p_mem_addr     = pio_p2p_mem_req_head[127:96];

assign p2p_cfg_is_wr    = is_idle ? pio_p2p_cfg_req_head[131] : cfg_req_head[131];
assign p2p_cfg_byte_cnt = cfg_req_head[28:16];
assign p2p_cfg_addr     = cfg_req_head[127:96];
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        cfg_req_head <= `TD 0;
    end
    else if (j_idle) begin
        cfg_req_head <= `TD 0;
    end
    else if (pio_p2p_cfg_req_valid & is_idle) begin
        cfg_req_head <= `TD pio_p2p_cfg_req_head;
    end
end
/* --------Input Head parser{end}-------- */

/* -------{P2P space access FSM}begin------- */
/******************** Stage 1: State Register **********************/
assign is_idle           = (cur_state == IDLE          );
assign is_trans_wreq_cfg = (cur_state == TRANS_WREQ_CFG);
assign is_trans_rreq_cfg = (cur_state == TRANS_RREQ_CFG);
assign is_trans_rrsp_cfg = (cur_state == TRANS_RRSP_CFG);

assign j_idle = (is_trans_wreq_cfg & in_cfg_req_valid & in_cfg_req_ready & in_cfg_req_last) |
                (is_trans_rreq_cfg & in_cfg_req_valid & in_cfg_req_ready & in_cfg_req_last) |
                (is_trans_rrsp_cfg & pio_p2p_rrsp_valid & pio_p2p_rrsp_ready & pio_p2p_rrsp_last);
assign j_trans_wreq_cfg = is_idle & (pio_p2p_cfg_req_valid & p2p_cfg_is_wr);
assign j_trans_rreq_cfg = is_idle & (pio_p2p_cfg_req_valid & (!p2p_cfg_is_wr) & (!p2p_full));
assign j_trans_rrsp_cfg = is_idle & (p2p_cfg_rrsp_valid & (!p2p_empty));

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
        if (p2p_cfg_rrsp_valid & (!p2p_empty)) begin
            nxt_state = TRANS_RRSP_CFG;
        end
        else if (pio_p2p_cfg_req_valid & p2p_cfg_is_wr) begin
            nxt_state = TRANS_WREQ_CFG;
        end
        else if (pio_p2p_cfg_req_valid & (!p2p_cfg_is_wr) & (!p2p_full)) begin
            nxt_state = TRANS_RREQ_CFG;
        end
        else begin
            nxt_state = IDLE;
        end
    end
    TRANS_WREQ_CFG: begin
        if (in_cfg_req_valid & in_cfg_req_ready & in_cfg_req_last) begin // write last beat of p2p cfg
            nxt_state = IDLE;
        end
        else begin
            nxt_state = TRANS_WREQ_CFG;
        end
    end
    TRANS_RREQ_CFG: begin
        if (in_cfg_req_valid & in_cfg_req_ready & in_cfg_req_last) begin
            nxt_state = IDLE;
        end
        else begin
            nxt_state = TRANS_RREQ_CFG;
        end
    end
    TRANS_RRSP_CFG: begin
        if (pio_p2p_rrsp_valid & pio_p2p_rrsp_ready & pio_p2p_rrsp_last) begin
            nxt_state = IDLE;
        end
        else begin
            nxt_state = TRANS_RRSP_CFG;
        end
    end
    default: begin
        nxt_state = IDLE;
    end
    endcase
end
/******************** Stage 3: Output **********************/

// Rsp Channel
assign pio_p2p_rrsp_valid = is_trans_rrsp_cfg & p2p_cfg_rrsp_valid;
assign pio_p2p_rrsp_last  = pio_p2p_rrsp_valid; 
assign pio_p2p_rrsp_data  = pio_p2p_rrsp_valid ? p2p_cfg_rrsp_data : 0;
assign pio_p2p_rrsp_head  = pio_p2p_rrsp_valid ? cfg_rrsp_head     : 0;

assign p2p_cfg_rrsp_ready = is_trans_rrsp_cfg & pio_p2p_rrsp_ready;

// P2P Configuration Req Channel
/* p2p_req head
 * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
 * | is_wr | Reserved | addr  | Reserved | byte_len |
 */
assign in_cfg_req_valid = (is_trans_wreq_cfg & pio_p2p_cfg_req_valid) |
                          (is_trans_rreq_cfg & pio_p2p_cfg_req_valid);
assign in_cfg_req_last  = in_cfg_req_valid & pio_p2p_cfg_req_last;
assign in_cfg_req_data  = (in_cfg_req_valid & is_trans_wreq_cfg) ? pio_p2p_cfg_req_data : 0;
assign in_cfg_req_head  = {is_trans_wreq_cfg, 31'd0, 32'd0, 12'd0, p2p_cfg_addr[`BAR0_WIDTH-1:0], 19'd0, p2p_cfg_byte_cnt};

assign pio_p2p_cfg_req_ready = (is_trans_wreq_cfg & in_cfg_req_ready) | 
                               (is_trans_rreq_cfg & in_cfg_req_ready);

// P2P MEM Stream Channel
/* p2p_req head
 * |  127  |  126:64  | 63:32 |  31:13   |   12:0   |
 * | is_wr | Reserved | addr  | Reserved | byte_len |
 */
assign in_mem_req_valid = pio_p2p_mem_req_valid;
assign in_mem_req_last  = pio_p2p_mem_req_last ;
assign in_mem_req_data  = pio_p2p_mem_req_data ;
assign in_mem_req_head  = {1'd1, 31'd0, 32'd0, {32-`BAR0_WIDTH{1'd0}}, p2p_mem_addr[`BAR0_WIDTH-1:0], 19'd0, p2p_mem_byte_cnt};

assign pio_p2p_mem_req_ready = in_mem_req_ready;
/* -------{P2P space access FSM}end------- */

/* -------P2P CFG Stream Channel{begin}------- */
st_reg #(
    .TUSER_WIDTH ( `P2P_HEAD_W ),
    .TDATA_WIDTH ( `PIO_DATA_W )
) cfg_st_reg (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( in_cfg_req_valid ), // i, 1
    .axis_tlast  ( in_cfg_req_last  ), // i, 1
    .axis_tuser  ( in_cfg_req_head  ), // i, TUSER_WIDTH
    .axis_tdata  ( in_cfg_req_data  ), // i, TDATA_WIDTH
    .axis_tready ( in_cfg_req_ready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .axis_reg_tvalid ( p2p_cfg_req_valid ), // o, 1  
    .axis_reg_tlast  ( p2p_cfg_req_last  ), // o, 1
    .axis_reg_tuser  ( p2p_cfg_req_head  ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( p2p_cfg_req_data  ), // o, TDATA_WIDTH
    .axis_reg_tready ( p2p_cfg_req_ready )  // i, 1
    /* -------output in_reg inteface{end}------- */
);
/* -------P2P CFG Stream Channel{end}------- */

/* -------P2P MEM Stream Channel{begin}------- */
st_reg #(
    .TUSER_WIDTH ( `P2P_HEAD_W ),
    .TDATA_WIDTH ( `PIO_DATA_W )
) mem_st_reg (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( in_mem_req_valid ), // i, 1
    .axis_tlast  ( in_mem_req_last  ), // i, 1
    .axis_tuser  ( in_mem_req_head  ), // i, TUSER_WIDTH
    .axis_tdata  ( in_mem_req_data  ), // i, TDATA_WIDTH
    .axis_tready ( in_mem_req_ready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .axis_reg_tvalid ( p2p_mem_req_valid ), // o, 1  
    .axis_reg_tlast  ( p2p_mem_req_last  ), // o, 1
    .axis_reg_tuser  ( p2p_mem_req_head  ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( p2p_mem_req_data  ), // o, TDATA_WIDTH
    .axis_reg_tready ( p2p_mem_req_ready )  // i, 1
    /* -------output in_reg inteface{end}------- */
);
/* -------P2P MEM Stream Channel{end}------- */

endmodule