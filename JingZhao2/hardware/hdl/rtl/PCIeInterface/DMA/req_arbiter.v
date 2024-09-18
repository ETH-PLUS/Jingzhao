`timescale 1ns / 100ps
//*************************************************************************
// > File Name: req_arbiter.v
// > Author   : Kangning
// > Date     : 2020-08-27
// > Note     : req_arbiter is used to arbiter different channels for data transmission
// > V1.1 - 2021-02-04 : Add supporting for five channels
// > V1.5 - 2022-04-24 : Parameterized arbiter, supports arbitrary number of channels
//*************************************************************************

//`include "../lib/global_include_h.v"

module req_arbiter #(
    parameter CHANNEL_NUM      = 8  ,    // number of slave signals to arbit
    parameter CHNL_NUM_LOG     = 3  
) ( 
    input  wire    dma_clk ,
    input  wire    rst_n   ,

    /* -------Slave AXIS Interface{begin}------- */
    /* AXI-Stream request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     * or
     * AXI-Stream interrupt request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |  Resv  | address | Reserved |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:0    |
     */
    input  wire [CHANNEL_NUM * 1            -1:0] s_axis_req_tvalid,
    input  wire [CHANNEL_NUM * 1            -1:0] s_axis_req_tlast ,
    input  wire [CHANNEL_NUM * `DMA_DATA_W  -1:0] s_axis_req_tdata ,
    input  wire [CHANNEL_NUM * `AXIS_TUSER_W-1:0] s_axis_req_tuser ,
    input  wire [CHANNEL_NUM * `DMA_KEEP_W  -1:0] s_axis_req_tkeep ,
    output wire [CHANNEL_NUM * 1            -1:0] s_axis_req_tready,
    /* -------Slave AXIS Interface{end}------- */

    /* ------- Master AXIS Interface{begin} ------- */
    /* AXI-Stream request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     * or
     * AXI-Stream interrupt request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |  Resv  | address | Reserved |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:0    |
     */
    output wire                     m_axis_req_tvalid,
    output wire                     m_axis_req_tlast ,
    output wire [`DMA_DATA_W  -1:0] m_axis_req_tdata , // contain only payload
    output wire [`AXIS_TUSER_W-1:0] m_axis_req_tuser , // The field contents are different from dma_*_tuser interface
    output wire [`DMA_KEEP_W  -1:0] m_axis_req_tkeep ,
    input  wire                     m_axis_req_tready 
    /* ------- Master AXIS Interface{end} ------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,output wire [`ARB_BASE_SIGNAL_W+CHANNEL_NUM*CHNL_NUM_LOG+CHNL_NUM_LOG*3+CHANNEL_NUM-1:0] dbg_signal // o, `WREQ_ALIGN_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
    
`ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* |       reserved       |          idx       | end | out |
     * |  255:CHNL_NUM_LOG+2  | CHNL_NUM_LOG+2-1:2 |  1  |  0  |
     */
    ,output wire [255:0] debug
    /* ------- Debug interface {end}------- */
`endif

);

/* ------- Next scheduled channel{begin}------- */
reg  [CHNL_NUM_LOG-1:0] chnl_idx_reg; // Index of channel to be scheduled next time, valid only in REQ_TRANS state.
reg  [CHNL_NUM_LOG-1:0] chnl_idx;     // Index of channel to be scheduled next time, valid all the time.
reg  [CHNL_NUM_LOG-1:0] last_chnl;    // Index of last selected channel.


/**
 * hit relevant channel is hit (hit_priority[3] == 1 means that last
 * selected channel is still valid.
 */
wire [CHANNEL_NUM-1:0] hit_priority;

/**
 * index of channel priority in next time, e.g. nxt_priority[1] 
 * indicates the index of next next channel; while nxt_priority[0]
 * indicates the index of next channel.
 */
wire [CHNL_NUM_LOG-1:0] nxt_priority[CHANNEL_NUM-1:0];

wire                     s_channel_tvalid[CHANNEL_NUM-1:0];
wire                     s_channel_tlast [CHANNEL_NUM-1:0];
wire [`DMA_DATA_W  -1:0] s_channel_tdata [CHANNEL_NUM-1:0];
wire [`AXIS_TUSER_W-1:0] s_channel_tuser [CHANNEL_NUM-1:0];
wire [`DMA_KEEP_W  -1:0] s_channel_tkeep [CHANNEL_NUM-1:0];


wire req_last; // last beat of the request
/* ------- Next scheduled channel{end}------- */

/* -------State relevant in FSM{begin}------- */
localparam      IDLE      = 3'b001,
                SCHEDULE  = 3'b010,
                REQ_TRANS = 3'b100;

reg [2:0] cur_state;
reg [2:0] nxt_state;

wire is_idle, is_schedule, is_req_trans;
wire j_req_trans;
// wire j_schedule;
/* -------State relevant in FSM{end}------- */

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
generate
if (CHANNEL_NUM == 10) begin:CHNL_DBG_10

assign dbg_signal = {
    chnl_idx_reg, chnl_idx, last_chnl, hit_priority, 
    req_last, 
    cur_state, nxt_state, 
    is_idle, is_schedule, is_req_trans, 
    j_req_trans, 
    nxt_priority[0], nxt_priority[1], nxt_priority[2], nxt_priority[3], nxt_priority[4], 
    nxt_priority[5], nxt_priority[6], nxt_priority[7], nxt_priority[8], nxt_priority[9]
};

end
else if (CHANNEL_NUM == 9) begin:CHNL_DBG_9

assign dbg_signal = {
    chnl_idx_reg, chnl_idx, last_chnl, hit_priority, 
    req_last, 
    cur_state, nxt_state, 
    is_idle, is_schedule, is_req_trans, 
    j_req_trans, 
    nxt_priority[0], nxt_priority[1], nxt_priority[2], nxt_priority[3], nxt_priority[4], 
    nxt_priority[5], nxt_priority[6], nxt_priority[7], nxt_priority[8]
};

end
else if (CHANNEL_NUM == 8) begin:CHNL_DBG_8

assign dbg_signal = {
    chnl_idx_reg, chnl_idx, last_chnl, hit_priority, 
    req_last, 
    cur_state, nxt_state, 
    is_idle, is_schedule, is_req_trans, 
    j_req_trans, 
    nxt_priority[0], nxt_priority[1], nxt_priority[2], nxt_priority[3], nxt_priority[4], 
    nxt_priority[5], nxt_priority[6], nxt_priority[7]
};

end
else if (CHANNEL_NUM == 7) begin:CHNL_DBG_7

assign dbg_signal = {
    chnl_idx_reg, chnl_idx, last_chnl, hit_priority, 
    req_last, 
    cur_state, nxt_state, 
    is_idle, is_schedule, is_req_trans, 
    j_req_trans, 
    nxt_priority[0], nxt_priority[1], nxt_priority[2], nxt_priority[3], nxt_priority[4], 
    nxt_priority[5], nxt_priority[6]
};

end
else if (CHANNEL_NUM == 6) begin:CHNL_DBG_6

assign dbg_signal = {
    chnl_idx_reg, chnl_idx, last_chnl, hit_priority, 
    req_last, 
    cur_state, nxt_state, 
    is_idle, is_schedule, is_req_trans, 
    j_req_trans, 
    nxt_priority[0], nxt_priority[1], nxt_priority[2], nxt_priority[3], nxt_priority[4], 
    nxt_priority[5]
};

end
else if (CHANNEL_NUM == 5) begin:CHNL_DBG_5

assign dbg_signal = {
    chnl_idx_reg, chnl_idx, last_chnl, hit_priority, 
    req_last, 
    cur_state, nxt_state, 
    is_idle, is_schedule, is_req_trans, 
    j_req_trans, 
    nxt_priority[0], nxt_priority[1], nxt_priority[2], nxt_priority[3], nxt_priority[4]
};

end
else if (CHANNEL_NUM == 4) begin:CHNL_DBG_4

assign dbg_signal = {
    chnl_idx_reg, chnl_idx, last_chnl, hit_priority, 
    req_last, 
    cur_state, nxt_state, 
    is_idle, is_schedule, is_req_trans, 
    j_req_trans, 
    nxt_priority[0], nxt_priority[1], nxt_priority[2], nxt_priority[3]
};

end
else if (CHANNEL_NUM == 3) begin:CHNL_DBG_3

assign dbg_signal = {
    chnl_idx_reg, chnl_idx, last_chnl, hit_priority, 
    req_last, 
    cur_state, nxt_state, 
    is_idle, is_schedule, is_req_trans, 
    j_req_trans, 
    nxt_priority[0], nxt_priority[1], nxt_priority[2]
};

end
else if (CHANNEL_NUM == 2) begin:CHNL_DBG_2

assign dbg_signal = {
    chnl_idx_reg, chnl_idx, last_chnl, hit_priority, 
    req_last, 
    cur_state, nxt_state, 
    is_idle, is_schedule, is_req_trans, 
    j_req_trans, 
    nxt_priority[0], nxt_priority[1]
};

end
endgenerate
/* -------APB reated signal{end}------- */
`endif

`ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* |       reserved       |          idx       | end | out |
     * |  255:CHNL_NUM_LOG+2  | CHNL_NUM_LOG+2-1:2 |  1  |  0  |
     */
    assign debug = {{254-CHNL_NUM_LOG{1'd0}}, 
                    chnl_idx, 
                    m_axis_req_tvalid & m_axis_req_tready & m_axis_req_tlast, 
                    m_axis_req_tvalid & m_axis_req_tready};
    /* ------- Debug interface {end}------- */
`endif



/* -------Find next channel{begin}------- */

always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        last_chnl <= `TD {CHNL_NUM_LOG{1'd0}};
    end
    else if (req_last) begin
        last_chnl <= `TD chnl_idx;
    end
end

always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        chnl_idx_reg <= `TD {CHNL_NUM_LOG{1'd0}};
    end
    else if (j_req_trans) begin
        chnl_idx_reg <= `TD chnl_idx;
    end
end

/* -------Generate block{begin}------- */
genvar k;
generate
for (k = 0; k < CHANNEL_NUM; k = k + 1) begin:CHNL_PRIORITY

assign nxt_priority[k] = ((last_chnl + k + 1) >= CHANNEL_NUM) ? 
                          (last_chnl + k + 1 - CHANNEL_NUM) : (last_chnl + k + 1);

end
endgenerate
/* -------Generate block{end}------- */


/* -------Generate block{begin}------- */
/* This is used for different Channel Numbers, the default Number is 5
 */
generate
if (CHANNEL_NUM == 10) begin:CHNL_SEL_10

always @(*) begin
    if (is_schedule) begin
        case (last_chnl)
        0: chnl_idx = hit_priority[0] ? 1 :
                      hit_priority[1] ? 2 :
                      hit_priority[2] ? 3 :
                      hit_priority[3] ? 4 :
                      hit_priority[4] ? 5 :
                      hit_priority[5] ? 6 :
                      hit_priority[6] ? 7 :
                      hit_priority[7] ? 8 : 
                      hit_priority[8] ? 9 : 
                      hit_priority[9] ? 0 : 1 ; // last branch is chosen when no channel is valid.
        1: chnl_idx = hit_priority[0] ? 2 :
                      hit_priority[1] ? 3 :
                      hit_priority[2] ? 4 :
                      hit_priority[3] ? 5 :
                      hit_priority[4] ? 6 :
                      hit_priority[5] ? 7 :
                      hit_priority[6] ? 8 :
                      hit_priority[7] ? 9 : 
                      hit_priority[8] ? 0 : 
                      hit_priority[9] ? 1 : 2 ; // last branch is chosen when no channel is valid.
        2: chnl_idx = hit_priority[0] ? 3 :
                      hit_priority[1] ? 4 :
                      hit_priority[2] ? 5 :
                      hit_priority[3] ? 6 :
                      hit_priority[4] ? 7 :
                      hit_priority[5] ? 8 :
                      hit_priority[6] ? 9 :
                      hit_priority[7] ? 0 : 
                      hit_priority[8] ? 1 : 
                      hit_priority[9] ? 2 : 3 ; // last branch is chosen when no channel is valid.
        3: chnl_idx = hit_priority[0] ? 4 :
                      hit_priority[1] ? 5 :
                      hit_priority[2] ? 6 :
                      hit_priority[3] ? 7 :
                      hit_priority[4] ? 8 :
                      hit_priority[5] ? 9 :
                      hit_priority[6] ? 0 :
                      hit_priority[7] ? 1 : 
                      hit_priority[8] ? 2 : 
                      hit_priority[9] ? 3 : 4 ; // last branch is chosen when no channel is valid.
        4: chnl_idx = hit_priority[0] ? 5 :
                      hit_priority[1] ? 6 :
                      hit_priority[2] ? 7 :
                      hit_priority[3] ? 8 :
                      hit_priority[4] ? 9 :
                      hit_priority[5] ? 0 :
                      hit_priority[6] ? 1 :
                      hit_priority[7] ? 2 : 
                      hit_priority[8] ? 3 : 
                      hit_priority[9] ? 4 : 5 ; // last branch is chosen when no channel is valid.
        5: chnl_idx = hit_priority[0] ? 6 :
                      hit_priority[1] ? 7 :
                      hit_priority[2] ? 8 :
                      hit_priority[3] ? 9 :
                      hit_priority[4] ? 0 :
                      hit_priority[5] ? 1 :
                      hit_priority[6] ? 2 :
                      hit_priority[7] ? 3 : 
                      hit_priority[8] ? 4 : 
                      hit_priority[9] ? 5 : 6 ; // last branch is chosen when no channel is valid.
        6: chnl_idx = hit_priority[0] ? 7 :
                      hit_priority[1] ? 8 :
                      hit_priority[2] ? 9 :
                      hit_priority[3] ? 0 :
                      hit_priority[4] ? 1 :
                      hit_priority[5] ? 2 :
                      hit_priority[6] ? 3 :
                      hit_priority[7] ? 4 : 
                      hit_priority[8] ? 5 : 
                      hit_priority[9] ? 6 : 7 ; // last branch is chosen when no channel is valid.
        7: chnl_idx = hit_priority[0] ? 8 :
                      hit_priority[1] ? 9 :
                      hit_priority[2] ? 0 :
                      hit_priority[3] ? 1 :
                      hit_priority[4] ? 2 :
                      hit_priority[5] ? 3 :
                      hit_priority[6] ? 4 :
                      hit_priority[7] ? 5 : 
                      hit_priority[8] ? 6 : 
                      hit_priority[9] ? 7 : 8 ; // last branch is chosen when no channel is valid.
        8: chnl_idx = hit_priority[0] ? 9 :
                      hit_priority[1] ? 0 :
                      hit_priority[2] ? 1 :
                      hit_priority[3] ? 2 :
                      hit_priority[4] ? 3 :
                      hit_priority[5] ? 4 :
                      hit_priority[6] ? 5 :
                      hit_priority[7] ? 6 : 
                      hit_priority[8] ? 7 : 
                      hit_priority[9] ? 8 : 9 ; // last branch is chosen when no channel is valid.
        9: chnl_idx = hit_priority[0] ? 0 :
                      hit_priority[1] ? 1 :
                      hit_priority[2] ? 2 :
                      hit_priority[3] ? 3 :
                      hit_priority[4] ? 4 :
                      hit_priority[5] ? 5 :
                      hit_priority[6] ? 6 :
                      hit_priority[7] ? 7 : 
                      hit_priority[8] ? 8 : 
                      hit_priority[9] ? 9 : 0 ; // last branch is chosen when no channel is valid.
        default: chnl_idx = {CHNL_NUM_LOG{1'd0}};
        endcase
    end
    else begin
        chnl_idx = chnl_idx_reg; // chosen in REQ_TRANS state
    end
end

end // CHANNEL_NUM == 10
else if (CHANNEL_NUM == 9) begin:CHNL_SEL_9

always @(*) begin
    if (is_schedule) begin
        case (last_chnl)
        4'd0: chnl_idx = hit_priority[0] ? 4'd1 :
                         hit_priority[1] ? 4'd2 :
                         hit_priority[2] ? 4'd3 :
                         hit_priority[3] ? 4'd4 :
                         hit_priority[4] ? 4'd5 :
                         hit_priority[5] ? 4'd6 :
                         hit_priority[6] ? 4'd7 :
                         hit_priority[7] ? 4'd8 : 
                         hit_priority[8] ? 4'd0 : 4'd1 ; // last branch is chosen when no channel is valid.
        4'd1: chnl_idx = hit_priority[0] ? 4'd2 :
                         hit_priority[1] ? 4'd3 :
                         hit_priority[2] ? 4'd4 :
                         hit_priority[3] ? 4'd5 :
                         hit_priority[4] ? 4'd6 :
                         hit_priority[5] ? 4'd7 :
                         hit_priority[6] ? 4'd8 :
                         hit_priority[7] ? 4'd0 : 
                         hit_priority[8] ? 4'd1 : 4'd2 ; // last branch is chosen when no channel is valid.
        4'd2: chnl_idx = hit_priority[0] ? 4'd3 :
                         hit_priority[1] ? 4'd4 :
                         hit_priority[2] ? 4'd5 :
                         hit_priority[3] ? 4'd6 :
                         hit_priority[4] ? 4'd7 :
                         hit_priority[5] ? 4'd8 :
                         hit_priority[6] ? 4'd0 :
                         hit_priority[7] ? 4'd1 : 
                         hit_priority[8] ? 4'd2 : 4'd3 ; // last branch is chosen when no channel is valid.
        4'd3: chnl_idx = hit_priority[0] ? 4'd4 :
                         hit_priority[1] ? 4'd5 :
                         hit_priority[2] ? 4'd6 :
                         hit_priority[3] ? 4'd7 :
                         hit_priority[4] ? 4'd8 :
                         hit_priority[5] ? 4'd0 :
                         hit_priority[6] ? 4'd1 :
                         hit_priority[7] ? 4'd2 : 
                         hit_priority[8] ? 4'd3 : 4'd4 ; // last branch is chosen when no channel is valid.
        4'd4: chnl_idx = hit_priority[0] ? 4'd5 :
                         hit_priority[1] ? 4'd6 :
                         hit_priority[2] ? 4'd7 :
                         hit_priority[3] ? 4'd8 :
                         hit_priority[4] ? 4'd0 :
                         hit_priority[5] ? 4'd1 :
                         hit_priority[6] ? 4'd2 :
                         hit_priority[7] ? 4'd3 : 
                         hit_priority[8] ? 4'd4 : 4'd5 ; // last branch is chosen when no channel is valid.
        4'd5: chnl_idx = hit_priority[0] ? 4'd6 :
                         hit_priority[1] ? 4'd7 :
                         hit_priority[2] ? 4'd8 :
                         hit_priority[3] ? 4'd0 :
                         hit_priority[4] ? 4'd1 :
                         hit_priority[5] ? 4'd2 :
                         hit_priority[6] ? 4'd3 :
                         hit_priority[7] ? 4'd4 : 
                         hit_priority[8] ? 4'd5 : 4'd6 ; // last branch is chosen when no channel is valid.
        4'd6: chnl_idx = hit_priority[0] ? 4'd7 :
                         hit_priority[1] ? 4'd8 :
                         hit_priority[2] ? 4'd0 :
                         hit_priority[3] ? 4'd1 :
                         hit_priority[4] ? 4'd2 :
                         hit_priority[5] ? 4'd3 :
                         hit_priority[6] ? 4'd4 :
                         hit_priority[7] ? 4'd5 : 
                         hit_priority[8] ? 4'd6 : 4'd7 ; // last branch is chosen when no channel is valid.
        4'd7: chnl_idx = hit_priority[0] ? 4'd8 :
                         hit_priority[1] ? 4'd0 :
                         hit_priority[2] ? 4'd1 :
                         hit_priority[3] ? 4'd2 :
                         hit_priority[4] ? 4'd3 :
                         hit_priority[5] ? 4'd4 :
                         hit_priority[6] ? 4'd5 :
                         hit_priority[7] ? 4'd6 : 
                         hit_priority[8] ? 4'd7 : 4'd8 ; // last branch is chosen when no channel is valid.
        4'd8: chnl_idx = hit_priority[0] ? 4'd0 :
                         hit_priority[1] ? 4'd1 :
                         hit_priority[2] ? 4'd2 :
                         hit_priority[3] ? 4'd3 :
                         hit_priority[4] ? 4'd4 :
                         hit_priority[5] ? 4'd5 :
                         hit_priority[6] ? 4'd6 :
                         hit_priority[7] ? 4'd7 : 
                         hit_priority[8] ? 4'd8 : 4'd0 ; // last branch is chosen when no channel is valid.
        default: chnl_idx = {CHNL_NUM_LOG{1'd0}};
        endcase
    end
    else begin
        chnl_idx = chnl_idx_reg; // chosen in REQ_TRANS state
    end
end

end // CHANNEL_NUM == 9
else if (CHANNEL_NUM == 8) begin:CHNL_SEL_8

always @(*) begin
    if (is_schedule) begin
        case (last_chnl)
        3'd0: chnl_idx = hit_priority[0] ? 3'd1 :
                         hit_priority[1] ? 3'd2 :
                         hit_priority[2] ? 3'd3 :
                         hit_priority[3] ? 3'd4 :
                         hit_priority[4] ? 3'd5 :
                         hit_priority[5] ? 3'd6 :
                         hit_priority[6] ? 3'd7 :
                         hit_priority[7] ? 3'd0 : 3'd1 ; // last branch is chosen when no channel is valid.
        3'd1: chnl_idx = hit_priority[0] ? 3'd2 :
                         hit_priority[1] ? 3'd3 :
                         hit_priority[2] ? 3'd4 :
                         hit_priority[3] ? 3'd5 :
                         hit_priority[4] ? 3'd6 :
                         hit_priority[5] ? 3'd7 :
                         hit_priority[6] ? 3'd0 :
                         hit_priority[7] ? 3'd1 : 3'd2 ; // last branch is chosen when no channel is valid.
        3'd2: chnl_idx = hit_priority[0] ? 3'd3 :
                         hit_priority[1] ? 3'd4 :
                         hit_priority[2] ? 3'd5 :
                         hit_priority[3] ? 3'd6 :
                         hit_priority[4] ? 3'd7 :
                         hit_priority[5] ? 3'd0 :
                         hit_priority[6] ? 3'd1 :
                         hit_priority[7] ? 3'd2 : 3'd3 ; // last branch is chosen when no channel is valid.
        3'd3: chnl_idx = hit_priority[0] ? 3'd4 :
                         hit_priority[1] ? 3'd5 :
                         hit_priority[2] ? 3'd6 :
                         hit_priority[3] ? 3'd7 :
                         hit_priority[4] ? 3'd0 :
                         hit_priority[5] ? 3'd1 :
                         hit_priority[6] ? 3'd2 :
                         hit_priority[7] ? 3'd3 : 3'd4 ; // last branch is chosen when no channel is valid.
        3'd4: chnl_idx = hit_priority[0] ? 3'd5 :
                         hit_priority[1] ? 3'd6 :
                         hit_priority[2] ? 3'd7 :
                         hit_priority[3] ? 3'd0 :
                         hit_priority[4] ? 3'd1 :
                         hit_priority[5] ? 3'd2 :
                         hit_priority[6] ? 3'd3 :
                         hit_priority[7] ? 3'd4 : 3'd5 ; // last branch is chosen when no channel is valid.
        3'd5: chnl_idx = hit_priority[0] ? 3'd6 :
                         hit_priority[1] ? 3'd7 :
                         hit_priority[2] ? 3'd0 :
                         hit_priority[3] ? 3'd1 :
                         hit_priority[4] ? 3'd2 :
                         hit_priority[5] ? 3'd3 :
                         hit_priority[6] ? 3'd4 :
                         hit_priority[7] ? 3'd5 : 3'd6 ; // last branch is chosen when no channel is valid.
        3'd6: chnl_idx = hit_priority[0] ? 3'd7 :
                         hit_priority[1] ? 3'd0 :
                         hit_priority[2] ? 3'd1 :
                         hit_priority[3] ? 3'd2 :
                         hit_priority[4] ? 3'd3 :
                         hit_priority[5] ? 3'd4 :
                         hit_priority[6] ? 3'd5 :
                         hit_priority[7] ? 3'd6 : 3'd7 ; // last branch is chosen when no channel is valid.
        3'd7: chnl_idx = hit_priority[0] ? 3'd0 :
                         hit_priority[1] ? 3'd1 :
                         hit_priority[2] ? 3'd2 :
                         hit_priority[3] ? 3'd3 :
                         hit_priority[4] ? 3'd4 :
                         hit_priority[5] ? 3'd5 :
                         hit_priority[6] ? 3'd6 :
                         hit_priority[7] ? 3'd7 : 3'd0 ; // last branch is chosen when no channel is valid.
        default: chnl_idx = {CHNL_NUM_LOG{1'd0}};
        endcase
    end
    else begin
        chnl_idx = chnl_idx_reg; // chosen in REQ_TRANS state
    end
end

end // CHANNEL_NUM == 8
else if (CHANNEL_NUM == 7) begin:CHNL_SEL_7

always @(*) begin
    if (is_schedule) begin
        case (last_chnl)
        0: chnl_idx = hit_priority[0] ? 1 :
                      hit_priority[1] ? 2 :
                      hit_priority[2] ? 3 :
                      hit_priority[3] ? 4 :
                      hit_priority[4] ? 5 :
                      hit_priority[5] ? 6 :
                      hit_priority[6] ? 0 : 1 ; // last branch is chosen when no channel is valid.
        1: chnl_idx = hit_priority[0] ? 2 :
                      hit_priority[1] ? 3 :
                      hit_priority[2] ? 4 :
                      hit_priority[3] ? 5 :
                      hit_priority[4] ? 6 :
                      hit_priority[5] ? 0 :
                      hit_priority[6] ? 1 : 2 ; // last branch is chosen when no channel is valid.
        2: chnl_idx = hit_priority[0] ? 3 :
                      hit_priority[1] ? 4 :
                      hit_priority[2] ? 5 :
                      hit_priority[3] ? 6 :
                      hit_priority[4] ? 0 :
                      hit_priority[5] ? 1 :
                      hit_priority[6] ? 2 : 3 ; // last branch is chosen when no channel is valid.
        3: chnl_idx = hit_priority[0] ? 4 :
                      hit_priority[1] ? 5 :
                      hit_priority[2] ? 6 :
                      hit_priority[3] ? 0 :
                      hit_priority[4] ? 1 :
                      hit_priority[5] ? 2 :
                      hit_priority[6] ? 3 : 4 ; // last branch is chosen when no channel is valid.
        4: chnl_idx = hit_priority[0] ? 5 :
                      hit_priority[1] ? 6 :
                      hit_priority[2] ? 0 :
                      hit_priority[3] ? 1 :
                      hit_priority[4] ? 2 :
                      hit_priority[5] ? 3 :
                      hit_priority[6] ? 4 : 5 ; // last branch is chosen when no channel is valid.
        5: chnl_idx = hit_priority[0] ? 6 :
                      hit_priority[1] ? 0 :
                      hit_priority[2] ? 1 :
                      hit_priority[3] ? 2 :
                      hit_priority[4] ? 3 :
                      hit_priority[5] ? 4 : 
                      hit_priority[6] ? 5 : 6 ; // last branch is chosen when no channel is valid.
        6: chnl_idx = hit_priority[0] ? 0 :
                      hit_priority[1] ? 1 :
                      hit_priority[2] ? 2 :
                      hit_priority[3] ? 3 :
                      hit_priority[4] ? 4 :
                      hit_priority[5] ? 5 : 
                      hit_priority[6] ? 6 : 0 ; // last branch is chosen when no channel is valid.
        default: chnl_idx = {CHNL_NUM_LOG{1'd0}};
        endcase
    end
    else begin
        chnl_idx = chnl_idx_reg; // chosen in REQ_TRANS state
    end
end

end // CHANNEL_NUM == 7
else if (CHANNEL_NUM == 6) begin:CHNL_SEL_6

always @(*) begin
    if (is_schedule) begin
        case (last_chnl)
        0: chnl_idx = hit_priority[0] ? 1 :
                      hit_priority[1] ? 2 :
                      hit_priority[2] ? 3 :
                      hit_priority[3] ? 4 :
                      hit_priority[4] ? 5 :
                      hit_priority[5] ? 0 : 1 ; // last branch is chosen when no channel is valid.
        1: chnl_idx = hit_priority[0] ? 2 :
                      hit_priority[1] ? 3 :
                      hit_priority[2] ? 4 :
                      hit_priority[3] ? 5 :
                      hit_priority[4] ? 0 :
                      hit_priority[5] ? 1 : 2 ; // last branch is chosen when no channel is valid.
        2: chnl_idx = hit_priority[0] ? 3 :
                      hit_priority[1] ? 4 :
                      hit_priority[2] ? 5 :
                      hit_priority[3] ? 0 :
                      hit_priority[4] ? 1 :
                      hit_priority[5] ? 2 : 3 ; // last branch is chosen when no channel is valid.
        3: chnl_idx = hit_priority[0] ? 4 :
                      hit_priority[1] ? 5 :
                      hit_priority[2] ? 0 :
                      hit_priority[3] ? 1 :
                      hit_priority[4] ? 2 :
                      hit_priority[5] ? 3 : 4 ; // last branch is chosen when no channel is valid.
        4: chnl_idx = hit_priority[0] ? 5 :
                      hit_priority[1] ? 0 :
                      hit_priority[2] ? 1 :
                      hit_priority[3] ? 2 :
                      hit_priority[4] ? 3 :
                      hit_priority[5] ? 4 : 5 ; // last branch is chosen when no channel is valid.
        5: chnl_idx = hit_priority[0] ? 0 :
                      hit_priority[1] ? 1 :
                      hit_priority[2] ? 2 :
                      hit_priority[3] ? 3 :
                      hit_priority[4] ? 4 :
                      hit_priority[5] ? 5 : 0 ; // last branch is chosen when no channel is valid.
        default: chnl_idx = {CHNL_NUM_LOG{1'd0}};
        endcase
    end
    else begin
        chnl_idx = chnl_idx_reg; // chosen in REQ_TRANS state
    end
end

end // CHANNEL_NUM == 6
else if (CHANNEL_NUM == 5) begin:CHNL_SEL_5

always @(*) begin
    if (is_schedule) begin
        case (last_chnl)
        0: chnl_idx = hit_priority[0] ? 1 :
                      hit_priority[1] ? 2 :
                      hit_priority[2] ? 3 :
                      hit_priority[3] ? 4 :
                      hit_priority[4] ? 0 : 1 ; // last branch is chosen when no channel is valid.
        1: chnl_idx = hit_priority[0] ? 2 :
                      hit_priority[1] ? 3 :
                      hit_priority[2] ? 4 :
                      hit_priority[3] ? 0 :
                      hit_priority[4] ? 1 : 2 ; // last branch is chosen when no channel is valid.
        2: chnl_idx = hit_priority[0] ? 3 :
                      hit_priority[1] ? 4 :
                      hit_priority[2] ? 0 :
                      hit_priority[3] ? 1 :
                      hit_priority[4] ? 2 : 3 ; // last branch is chosen when no channel is valid.
        3: chnl_idx = hit_priority[0] ? 4 :
                      hit_priority[1] ? 0 :
                      hit_priority[2] ? 1 :
                      hit_priority[3] ? 2 :
                      hit_priority[4] ? 3 : 4 ; // last branch is chosen when no channel is valid.
        4: chnl_idx = hit_priority[0] ? 0 :
                      hit_priority[1] ? 1 :
                      hit_priority[2] ? 2 :
                      hit_priority[3] ? 3 :
                      hit_priority[4] ? 4 : 0 ; // last branch is chosen when no channel is valid.
        default: chnl_idx = {CHNL_NUM_LOG{1'd0}};
        endcase
    end
    else begin
        chnl_idx = chnl_idx_reg; // chosen in REQ_TRANS state
    end
end

end // CHANNEL_NUM == 5
else if (CHANNEL_NUM == 4) begin:CHNL_SEL_4

always @(*) begin
    if (is_schedule) begin
        case (last_chnl)
        0: chnl_idx = hit_priority[0] ? 1 :
                      hit_priority[1] ? 2 :
                      hit_priority[2] ? 3 :
                      hit_priority[3] ? 0 : 1 ; // last branch is chosen when no channel is valid.
        1: chnl_idx = hit_priority[0] ? 2 :
                      hit_priority[1] ? 3 :
                      hit_priority[2] ? 0 :
                      hit_priority[3] ? 1 : 2 ; // last branch is chosen when no channel is valid.
        2: chnl_idx = hit_priority[0] ? 3 :
                      hit_priority[1] ? 0 :
                      hit_priority[2] ? 1 :
                      hit_priority[3] ? 2 : 3 ; // last branch is chosen when no channel is valid.
        3: chnl_idx = hit_priority[0] ? 0 :
                      hit_priority[1] ? 1 :
                      hit_priority[2] ? 2 :
                      hit_priority[3] ? 3 : 0 ; // last branch is chosen when no channel is valid.
        default: chnl_idx = {CHNL_NUM_LOG{1'd0}};
        endcase
    end
    else begin
        chnl_idx = chnl_idx_reg; // chosen in REQ_TRANS state
    end
end

end // CHANNEL_NUM == 4
else if (CHANNEL_NUM == 3) begin:CHNL_SEL_3

always @(*) begin
    if (is_schedule) begin
        case (last_chnl)
        0: chnl_idx = hit_priority[0] ? 1 :
                      hit_priority[1] ? 2 :
                      hit_priority[2] ? 0 : 1; // last branch is chosen when no channel is valid.
        1: chnl_idx = hit_priority[0] ? 2 :
                      hit_priority[1] ? 0 :
                      hit_priority[2] ? 1 : 2; // last branch is chosen when no channel is valid.
        2: chnl_idx = hit_priority[0] ? 0 :
                      hit_priority[1] ? 1 :
                      hit_priority[2] ? 2 : 0; // last branch is chosen when no channel is valid.
        default: chnl_idx = {CHNL_NUM_LOG{1'd0}};
        endcase
    end
    else begin
        chnl_idx = chnl_idx_reg; // chosen in REQ_TRANS state
    end
end

end // CHANNEL_NUM == 3
else if (CHANNEL_NUM == 2) begin:CHNL_SEL_2

always @(*) begin
    if (is_schedule) begin
        case (last_chnl)
        1'd0: chnl_idx = hit_priority[0] ? 1'd1 :
                         hit_priority[1] ? 1'd0 : 1'd1 ; // last branch is chosen when no channel is valid.
        1'd1: chnl_idx = hit_priority[0] ? 1'd0 :
                         hit_priority[1] ? 1'd1 : 1'd0 ; // last branch is chosen when no channel is valid.
        default: chnl_idx = {CHNL_NUM_LOG{1'd0}};
        endcase
    end
    else begin
        chnl_idx = chnl_idx_reg; // chosen in REQ_TRANS state
    end
end

end // CHANNEL_NUM == 2
endgenerate
/* 
 This is used for different Channel Numbers, the default Number is 4 */
/* -------Generate block{end}------- */

// /* -------Core logic to arbit, a parameterized arbiter{begin}------- */
// function [CHNL_NUM_LOG-1:0] find_chnl_num;
//     input [CHNL_NUM_LOG-1:0] prio_level;
//     input [CHNL_NUM_LOG-1:0] last_c;
//     begin
//         find_chnl_num = ((last_c+prio_level+1) >= CHANNEL_NUM) ? last_c+prio_level+1-CHANNEL_NUM : last_c+prio_level+1;
//     end
// endfunction

// function [CHANNEL_NUM-1:0] sel_prio;
//     input [CHANNEL_NUM-1:0] sel;
//     reg tmp;
//     integer i, j;
//     begin
//         sel_prio[0] = sel[0];
//         for (i = 1; i < CHANNEL_NUM; i = i + 1) begin
//             tmp =  0;
//             for (j = 0; j < i; j = j + 1) begin
//                 tmp = tmp | sel[j];
//             end
//             sel_prio[i] = !tmp & sel[i];
//         end
//     end
// endfunction

// function [CHNL_NUM_LOG-1:0] find_nxt_chnl;
//     input [CHNL_NUM_LOG-1:0] last_c;
//     input [CHANNEL_NUM-1:0]  hit_prio;
//     integer i;
//     begin
//         find_nxt_chnl = {CHNL_NUM_LOG{hit_prio[0]}} & find_chnl_num(0, last_c);
//         for (i = 1; i < CHANNEL_NUM; i = i + 1) begin
//             find_nxt_chnl = find_nxt_chnl | {CHNL_NUM_LOG{hit_prio[i]}} & find_chnl_num(i, last_c);;
//         end
//     end
// endfunction

// always @(*) begin
//     if (is_schedule) begin
//         chnl_idx = find_nxt_chnl(last_chnl, sel_prio(hit_priority));
//     end
//     else begin
//         chnl_idx = chnl_idx_reg; // chosen in REQ_TRANS state
//     end
// end
// /* -------Core logic to arbit, a parameterized arbiter{end}------- */

// state transform signal
assign req_last = m_axis_req_tvalid & m_axis_req_tready & m_axis_req_tlast;

/* -------Find next channel{end}------- */

/* -------{Read Request Arbiter FSM}begin------- */
/******************** Stage 1: State Register **********************/
assign is_idle      = (cur_state == IDLE     );
assign is_schedule  = (cur_state == SCHEDULE );
assign is_req_trans = (cur_state == REQ_TRANS);
assign j_req_trans  = is_schedule & (!req_last) & (|s_axis_req_tvalid);
// assign j_schedule   = is_schedule  & (req_last) |
//                       is_req_trans & (req_last);

always @(posedge dma_clk, negedge rst_n) begin
	if(~rst_n)
		cur_state <= `TD IDLE;
	else
		cur_state <= `TD nxt_state;
end

/******************** Stage 2: State Transition **********************/

always @(*) begin
	case(cur_state)
    IDLE: begin
        if (|s_axis_req_tvalid) begin
            nxt_state = SCHEDULE;
        end
        else begin
            nxt_state = IDLE;
        end
    end
    SCHEDULE: begin
        if (req_last) begin // one beat request has already been transmited in
                                 // schedule state.
          nxt_state = SCHEDULE;
	    end
	    else if (|s_axis_req_tvalid) begin // There's valid channel, and not the last beat.
          nxt_state = REQ_TRANS;
        end
        else begin
          nxt_state = IDLE;
        end
    end
    REQ_TRANS: begin
        if (req_last) begin // request has already been transmited in
                                 // req_trans state.
	        nxt_state = SCHEDULE;
        end
        else begin
            nxt_state = REQ_TRANS;
        end
    end
	default: begin
		nxt_state = IDLE;
	end
	endcase
end
/******************** Stage 3: Output **********************/

/* -------Generate block{begin}------- */
genvar n;
generate
for (n = 0; n < CHANNEL_NUM; n = n + 1) begin:CHNL_ASSIGN

assign s_axis_req_tready[n] = (is_schedule | is_req_trans) & (n == chnl_idx) & m_axis_req_tready;

assign s_channel_tvalid[n] = s_axis_req_tvalid[((n+1) * 1            -1):(n * 1            )];
assign s_channel_tlast [n] = s_axis_req_tlast [((n+1) * 1            -1):(n * 1            )];
assign s_channel_tdata [n] = s_axis_req_tdata [((n+1) * `DMA_DATA_W  -1):(n * `DMA_DATA_W  )];
assign s_channel_tuser [n] = s_axis_req_tuser [((n+1) * `AXIS_TUSER_W-1):(n * `AXIS_TUSER_W)];
assign s_channel_tkeep [n] = s_axis_req_tkeep [((n+1) * `DMA_KEEP_W  -1):(n * `DMA_KEEP_W  )];

assign hit_priority[n] = s_channel_tvalid[nxt_priority[n]];

end
endgenerate
/* -------Generate block{end}------- */

assign m_axis_req_tvalid = (is_schedule | is_req_trans) ? s_channel_tvalid[chnl_idx] : 1'd0;
assign m_axis_req_tlast  = (is_schedule | is_req_trans) ? s_channel_tlast [chnl_idx] : 1'd0;
assign m_axis_req_tdata  = (is_schedule | is_req_trans) ? s_channel_tdata [chnl_idx] : {`DMA_DATA_W{1'd0}};
assign m_axis_req_tuser  = (is_schedule | is_req_trans) ? s_channel_tuser [chnl_idx] : {`AXIS_TUSER_W{1'd0}};
assign m_axis_req_tkeep  = (is_schedule | is_req_trans) ? s_channel_tkeep [chnl_idx] : {`DMA_KEEP_W{1'd0}};

/* -------{Read Request Arbiter FSM}end------- */


endmodule
