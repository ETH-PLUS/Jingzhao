`timescale 1ns / 100ps
//*************************************************************************
// > File Name: pio_mux.v
// > Author   : Kangning
// > Date     : 2022-03-12
// > Note     : pio_mux is used to arbiter different channels for data transmission
// > V1.1 - 2021-02-04 : Add supporting for five channels
// > V1.2 - 2022-03-12 : Copy from req_arbiter.v
//*************************************************************************

module pio_mux #(
    parameter CHANNEL_NUM      = 2  ,    // number of slave signals to arbit
    parameter CHNL_NUM_LOG     = 1  
) ( 
    input  wire    clk,
    input  wire    rst_n   ,

    /* -------Slave AXIS Interface{begin}------- */
    input  wire [CHANNEL_NUM * 1          -1:0] s_axis_ifc_tvalid,
    input  wire [CHANNEL_NUM * 1          -1:0] s_axis_ifc_tlast ,
    input  wire [CHANNEL_NUM * `PIO_DATA_W-1:0] s_axis_ifc_tdata ,
    input  wire [CHANNEL_NUM * `PIO_HEAD_W-1:0] s_axis_ifc_thead ,
    input  wire [CHANNEL_NUM * `PIO_KEEP_W-1:0] s_axis_ifc_tkeep ,
    output wire [CHANNEL_NUM * 1          -1:0] s_axis_ifc_tready,
    /* -------Slave AXIS Interface{end}------- */

    /* ------- Master AXIS Interface{begin} ------- */
    output wire                   m_axis_ifc_tvalid,
    output wire                   m_axis_ifc_tlast ,
    output wire [`PIO_DATA_W-1:0] m_axis_ifc_tdata , // contain only payload
    output wire [`PIO_HEAD_W-1:0] m_axis_ifc_thead , // The field contents are different from dma_*_tuser interface
    output wire [`PIO_KEEP_W-1:0] m_axis_ifc_tkeep ,
    input  wire                   m_axis_ifc_tready 
    /* ------- Master AXIS Interface{end} ------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,output wire [`PIO_MUX_SIGNAL_W-1:0] dbg_signal // o, debug bus select    
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

/* ------- Next scheduled channel{begin}------- */
reg  [CHNL_NUM_LOG-1:0] chnl_idx_reg; // Index of channel to be scheduled next time, valid only in REQ_TRANS state.
reg  [CHNL_NUM_LOG-1:0] chnl_idx;     // Index of channel to be scheduled next time, valid all the time.
reg  [CHNL_NUM_LOG-1:0] last_chnl;    // Index of last selected channel.


/**
 * hit relevant channel is hit (hit_priority[3] == 1 means that last
 * selected channel is still valid.
 */
wire                    hit_priority[CHANNEL_NUM-1:0];

/**
 * index of channel priority in next time, e.g. nxt_priority[1] 
 * indicates the index of next next channel; while nxt_priority[0]
 * indicates the index of next channel.
 */
wire [CHNL_NUM_LOG-1:0] nxt_priority[CHANNEL_NUM-1:0];

wire                   s_channel_tvalid[CHANNEL_NUM-1:0];
wire                   s_channel_tlast [CHANNEL_NUM-1:0];
wire [`PIO_DATA_W-1:0] s_channel_tdata [CHANNEL_NUM-1:0];
wire [`PIO_HEAD_W-1:0] s_channel_tuser [CHANNEL_NUM-1:0];
wire [`PIO_KEEP_W-1:0] s_channel_tkeep [CHANNEL_NUM-1:0];


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

/* ------------------------------------------------------------------------ */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */

generate
if (CHANNEL_NUM == 4) begin:DBG_CHNL4

assign dbg_signal = { // 1621
    chnl_idx_reg, chnl_idx,  last_chnl, // 6

    hit_priority[3], nxt_priority[3], s_channel_tvalid[3], s_channel_tlast [3], s_channel_tdata [3], s_channel_tuser [3], s_channel_tkeep [3], 
    hit_priority[2], nxt_priority[2], s_channel_tvalid[2], s_channel_tlast [2], s_channel_tdata [2], s_channel_tuser [2], s_channel_tkeep [2], 
    hit_priority[1], nxt_priority[1], s_channel_tvalid[1], s_channel_tlast [1], s_channel_tdata [1], s_channel_tuser [1], s_channel_tkeep [1], 
    hit_priority[0], nxt_priority[0], s_channel_tvalid[0], s_channel_tlast [0], s_channel_tdata [0], s_channel_tuser [0], s_channel_tkeep [0], // 401*4=1604

    req_last, // 1
    cur_state, nxt_state, // 6
    is_idle, is_schedule, is_req_trans, j_req_trans // 4
};

end
endgenerate

/* -------APB reated signal{end}------- */
`endif

`ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved | reserved | idx | end | out |
     * |  255:10  |   9:5    | 4:2 |  1  |  0  |
     */
    assign debug = {{252+2-CHNL_NUM_LOG{1'd0}}, 
                    chnl_idx, 
                    m_axis_ifc_tvalid & m_axis_ifc_tready & m_axis_ifc_tlast, 
                    m_axis_ifc_tvalid & m_axis_ifc_tready};
    /* ------- Debug interface {end}------- */
`endif



/* -------Find next channel{begin}------- */

always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        last_chnl <= `TD {CHNL_NUM_LOG{1'd0}};
    end
    else if (req_last) begin
        last_chnl <= `TD chnl_idx;
    end
end

always @(posedge clk, negedge rst_n) begin
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
        0: chnl_idx = hit_priority[0] ? 1 :
                      hit_priority[1] ? 2 :
                      hit_priority[2] ? 3 :
                      hit_priority[3] ? 4 :
                      hit_priority[4] ? 5 :
                      hit_priority[5] ? 6 :
                      hit_priority[6] ? 7 :
                      hit_priority[7] ? 8 : 
                      hit_priority[8] ? 0 : 1 ; // last branch is chosen when no channel is valid.
        1: chnl_idx = hit_priority[0] ? 2 :
                      hit_priority[1] ? 3 :
                      hit_priority[2] ? 4 :
                      hit_priority[3] ? 5 :
                      hit_priority[4] ? 6 :
                      hit_priority[5] ? 7 :
                      hit_priority[6] ? 8 :
                      hit_priority[7] ? 0 : 
                      hit_priority[8] ? 1 : 2 ; // last branch is chosen when no channel is valid.
        2: chnl_idx = hit_priority[0] ? 3 :
                      hit_priority[1] ? 4 :
                      hit_priority[2] ? 5 :
                      hit_priority[3] ? 6 :
                      hit_priority[4] ? 7 :
                      hit_priority[5] ? 8 :
                      hit_priority[6] ? 0 :
                      hit_priority[7] ? 1 : 
                      hit_priority[8] ? 2 : 3 ; // last branch is chosen when no channel is valid.
        3: chnl_idx = hit_priority[0] ? 4 :
                      hit_priority[1] ? 5 :
                      hit_priority[2] ? 6 :
                      hit_priority[3] ? 7 :
                      hit_priority[4] ? 8 :
                      hit_priority[5] ? 0 :
                      hit_priority[6] ? 1 :
                      hit_priority[7] ? 2 : 
                      hit_priority[8] ? 3 : 4 ; // last branch is chosen when no channel is valid.
        4: chnl_idx = hit_priority[0] ? 5 :
                      hit_priority[1] ? 6 :
                      hit_priority[2] ? 7 :
                      hit_priority[3] ? 8 :
                      hit_priority[4] ? 0 :
                      hit_priority[5] ? 1 :
                      hit_priority[6] ? 2 :
                      hit_priority[7] ? 3 : 
                      hit_priority[8] ? 4 : 5 ; // last branch is chosen when no channel is valid.
        5: chnl_idx = hit_priority[0] ? 6 :
                      hit_priority[1] ? 7 :
                      hit_priority[2] ? 8 :
                      hit_priority[3] ? 0 :
                      hit_priority[4] ? 1 :
                      hit_priority[5] ? 2 :
                      hit_priority[6] ? 3 :
                      hit_priority[7] ? 4 : 
                      hit_priority[8] ? 5 : 6 ; // last branch is chosen when no channel is valid.
        6: chnl_idx = hit_priority[0] ? 7 :
                      hit_priority[1] ? 8 :
                      hit_priority[2] ? 0 :
                      hit_priority[3] ? 1 :
                      hit_priority[4] ? 2 :
                      hit_priority[5] ? 3 :
                      hit_priority[6] ? 4 :
                      hit_priority[7] ? 5 : 
                      hit_priority[8] ? 6 : 7 ; // last branch is chosen when no channel is valid.
        7: chnl_idx = hit_priority[0] ? 8 :
                      hit_priority[1] ? 0 :
                      hit_priority[2] ? 1 :
                      hit_priority[3] ? 2 :
                      hit_priority[4] ? 3 :
                      hit_priority[5] ? 4 :
                      hit_priority[6] ? 5 :
                      hit_priority[7] ? 6 : 
                      hit_priority[8] ? 7 : 8 ; // last branch is chosen when no channel is valid.
        8: chnl_idx = hit_priority[0] ? 0 :
                      hit_priority[1] ? 1 :
                      hit_priority[2] ? 2 :
                      hit_priority[3] ? 3 :
                      hit_priority[4] ? 4 :
                      hit_priority[5] ? 5 :
                      hit_priority[6] ? 6 :
                      hit_priority[7] ? 7 : 
                      hit_priority[8] ? 8 : 0 ; // last branch is chosen when no channel is valid.
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
        0: chnl_idx = hit_priority[0] ? 1 :
                      hit_priority[1] ? 2 :
                      hit_priority[2] ? 3 :
                      hit_priority[3] ? 4 :
                      hit_priority[4] ? 5 :
                      hit_priority[5] ? 6 :
                      hit_priority[6] ? 7 :
                      hit_priority[7] ? 0 : 1 ; // last branch is chosen when no channel is valid.
        1: chnl_idx = hit_priority[0] ? 2 :
                      hit_priority[1] ? 3 :
                      hit_priority[2] ? 4 :
                      hit_priority[3] ? 5 :
                      hit_priority[4] ? 6 :
                      hit_priority[5] ? 7 :
                      hit_priority[6] ? 0 :
                      hit_priority[7] ? 1 : 2 ; // last branch is chosen when no channel is valid.
        2: chnl_idx = hit_priority[0] ? 3 :
                      hit_priority[1] ? 4 :
                      hit_priority[2] ? 5 :
                      hit_priority[3] ? 6 :
                      hit_priority[4] ? 7 :
                      hit_priority[5] ? 0 :
                      hit_priority[6] ? 1 :
                      hit_priority[7] ? 2 : 3 ; // last branch is chosen when no channel is valid.
        3: chnl_idx = hit_priority[0] ? 4 :
                      hit_priority[1] ? 5 :
                      hit_priority[2] ? 6 :
                      hit_priority[3] ? 7 :
                      hit_priority[4] ? 0 :
                      hit_priority[5] ? 1 :
                      hit_priority[6] ? 2 :
                      hit_priority[7] ? 3 : 4 ; // last branch is chosen when no channel is valid.
        4: chnl_idx = hit_priority[0] ? 5 :
                      hit_priority[1] ? 6 :
                      hit_priority[2] ? 7 :
                      hit_priority[3] ? 0 :
                      hit_priority[4] ? 1 :
                      hit_priority[5] ? 2 :
                      hit_priority[6] ? 3 :
                      hit_priority[7] ? 4 : 5 ; // last branch is chosen when no channel is valid.
        5: chnl_idx = hit_priority[0] ? 6 :
                      hit_priority[1] ? 7 :
                      hit_priority[2] ? 0 :
                      hit_priority[3] ? 1 :
                      hit_priority[4] ? 2 :
                      hit_priority[5] ? 3 :
                      hit_priority[6] ? 4 :
                      hit_priority[7] ? 5 : 6 ; // last branch is chosen when no channel is valid.
        6: chnl_idx = hit_priority[0] ? 7 :
                      hit_priority[1] ? 0 :
                      hit_priority[2] ? 1 :
                      hit_priority[3] ? 2 :
                      hit_priority[4] ? 3 :
                      hit_priority[5] ? 4 :
                      hit_priority[6] ? 5 :
                      hit_priority[7] ? 6 : 7 ; // last branch is chosen when no channel is valid.
        7: chnl_idx = hit_priority[0] ? 0 :
                      hit_priority[1] ? 1 :
                      hit_priority[2] ? 2 :
                      hit_priority[3] ? 3 :
                      hit_priority[4] ? 4 :
                      hit_priority[5] ? 5 :
                      hit_priority[6] ? 6 :
                      hit_priority[7] ? 7 : 0 ; // last branch is chosen when no channel is valid.
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
        0: chnl_idx = hit_priority[0] ? 1 :
                      hit_priority[1] ? 0 : 1 ; // last branch is chosen when no channel is valid.
        1: chnl_idx = hit_priority[0] ? 0 :
                      hit_priority[1] ? 1 : 0 ; // last branch is chosen when no channel is valid.
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

// state transform signal
assign req_last = m_axis_ifc_tvalid & m_axis_ifc_tready & m_axis_ifc_tlast;

/* -------Find next channel{end}------- */

/* -------{Read Request Arbiter FSM}begin------- */
/******************** Stage 1: State Register **********************/
assign is_idle      = (cur_state == IDLE     );
assign is_schedule  = (cur_state == SCHEDULE );
assign is_req_trans = (cur_state == REQ_TRANS);
assign j_req_trans  = is_schedule & (!req_last) & (|s_axis_ifc_tvalid);
// assign j_schedule   = is_schedule  & (req_last) |
//                       is_req_trans & (req_last);

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
        if (|s_axis_ifc_tvalid) begin
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
        else if (|s_axis_ifc_tvalid) begin // There's valid channel, and not the last beat.
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

assign s_axis_ifc_tready[n] = (is_schedule | is_req_trans) & (n == chnl_idx) & m_axis_ifc_tready;

assign s_channel_tvalid[n] = s_axis_ifc_tvalid[((n+1) * 1          -1):(n * 1          )];
assign s_channel_tlast [n] = s_axis_ifc_tlast [((n+1) * 1          -1):(n * 1          )];
assign s_channel_tdata [n] = s_axis_ifc_tdata [((n+1) * `PIO_DATA_W-1):(n * `PIO_DATA_W)];
assign s_channel_tuser [n] = s_axis_ifc_thead [((n+1) * `PIO_HEAD_W-1):(n * `PIO_HEAD_W)];
assign s_channel_tkeep [n] = s_axis_ifc_tkeep [((n+1) * `PIO_KEEP_W-1):(n * `PIO_KEEP_W)];

assign hit_priority[n] = s_channel_tvalid[nxt_priority[n]];

end
endgenerate
/* -------Generate block{end}------- */

assign m_axis_ifc_tvalid = (is_schedule | is_req_trans) ? s_channel_tvalid[chnl_idx] : 1'd0;
assign m_axis_ifc_tlast  = (is_schedule | is_req_trans) ? s_channel_tlast [chnl_idx] : 1'd0;
assign m_axis_ifc_tdata  = (is_schedule | is_req_trans) ? s_channel_tdata [chnl_idx] : {`PIO_DATA_W{1'd0}};
assign m_axis_ifc_thead  = (is_schedule | is_req_trans) ? s_channel_tuser [chnl_idx] : {`PIO_HEAD_W{1'd0}};
assign m_axis_ifc_tkeep  = (is_schedule | is_req_trans) ? s_channel_tkeep [chnl_idx] : {`PIO_KEEP_W{1'd0}};

/* -------{Read Request Arbiter FSM}end------- */


endmodule
