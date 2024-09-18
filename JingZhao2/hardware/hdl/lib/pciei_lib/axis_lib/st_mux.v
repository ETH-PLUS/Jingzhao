`timescale 1ns / 100ps
//*************************************************************************
// > File Name: st_mux.v
// > Author   : Kangning
// > Date     : 2022-11-14
// > Note     : st_mux is used to arbiter different channels for data transmission
// > V1.1 - 2021-02-04 : Add supporting for five channels
// > V1.5 - 2022-04-24 : Parameterized arbiter, supports arbitrary number of channels
// > V2.0 - 2022-11-14 : A generalized string mux logic.
//*************************************************************************

module st_mux #(
    parameter CHNL_NUM      = 8  ,    // number of slave signals to arbit
    parameter CHNL_NUM_LOG  = 3  ,
    parameter TUSER_WIDTH   = 128,
    parameter TDATA_WIDTH   = 256
) ( 
    input  wire    clk  ,
    input  wire    rst_n,

    /* -------Slave AXIS Interface{begin}------- */
    input  wire [CHNL_NUM * 1          -1:0] s_axis_mux_tvalid, // i, CHNL_NUM * 1
    input  wire [CHNL_NUM * 1          -1:0] s_axis_mux_tlast , // i, CHNL_NUM * 1
    input  wire [CHNL_NUM * TDATA_WIDTH-1:0] s_axis_mux_tdata , // i, CHNL_NUM * TDATA_WIDTH
    input  wire [CHNL_NUM * TUSER_WIDTH-1:0] s_axis_mux_tuser , // i, CHNL_NUM * TUSER_WIDTH
    output wire [CHNL_NUM * 1          -1:0] s_axis_mux_tready, // o, CHNL_NUM * 1
    /* -------Slave AXIS Interface{end}------- */

    /* ------- Master AXIS Interface{begin} ------- */
    output wire                   m_axis_mux_tvalid, // o, 1
    output wire                   m_axis_mux_tlast , // o, 1
    output wire [TDATA_WIDTH-1:0] m_axis_mux_tdata , // o, TDATA_WIDTH
    output wire [TUSER_WIDTH-1:0] m_axis_mux_tuser , // o, TUSER_WIDTH
    input  wire                   m_axis_mux_tready  // i, 1
    /* ------- Master AXIS Interface{end} ------- */

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
wire [CHNL_NUM-1:0] hit_priority;

/**
 * index of channel priority in next time, e.g. nxt_priority[1] 
 * indicates the index of next next channel; while nxt_priority[0]
 * indicates the index of next channel.
 */
wire [CHNL_NUM_LOG-1:0] nxt_priority[CHNL_NUM-1:0];

wire                   s_channel_tvalid[CHNL_NUM-1:0];
wire                   s_channel_tlast [CHNL_NUM-1:0];
wire [TDATA_WIDTH-1:0] s_channel_tdata [CHNL_NUM-1:0];
wire [TUSER_WIDTH-1:0] s_channel_tuser [CHNL_NUM-1:0];


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

`ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* |       reserved       |          idx       | end | out |
     * |  255:CHNL_NUM_LOG+2  | CHNL_NUM_LOG+2-1:2 |  1  |  0  |
     */
    assign debug = {{254-CHNL_NUM_LOG{1'd0}}, 
                    chnl_idx, 
                    m_axis_mux_tvalid & m_axis_mux_tready & m_axis_mux_tlast, 
                    m_axis_mux_tvalid & m_axis_mux_tready};
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
for (k = 0; k < CHNL_NUM; k = k + 1) begin:CHNL_PRIORITY

assign nxt_priority[k] = ((last_chnl + k + 1) >= CHNL_NUM) ? 
                          (last_chnl + k + 1 - CHNL_NUM) : (last_chnl + k + 1);

end
endgenerate
/* -------Generate block{end}------- */


/* -------Generate block{begin}------- */
/* This is used for different Channel Numbers, the default Number is 5
 */
generate
if (CHNL_NUM == 10) begin:CHNL_SEL_10

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

end // CHNL_NUM == 10
else if (CHNL_NUM == 9) begin:CHNL_SEL_9

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

end // CHNL_NUM == 9
else if (CHNL_NUM == 8) begin:CHNL_SEL_8

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

end // CHNL_NUM == 8
else if (CHNL_NUM == 7) begin:CHNL_SEL_7

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

end // CHNL_NUM == 7
else if (CHNL_NUM == 6) begin:CHNL_SEL_6

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

end // CHNL_NUM == 6
else if (CHNL_NUM == 5) begin:CHNL_SEL_5

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

end // CHNL_NUM == 5
else if (CHNL_NUM == 4) begin:CHNL_SEL_4

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

end // CHNL_NUM == 4
else if (CHNL_NUM == 3) begin:CHNL_SEL_3

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

end // CHNL_NUM == 3
else if (CHNL_NUM == 2) begin:CHNL_SEL_2

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

end // CHNL_NUM == 2
endgenerate
/* 
 This is used for different Channel Numbers, the default Number is 4 */
/* -------Generate block{end}------- */

// /* -------Core logic to arbit, a parameterized arbiter{begin}------- */
// function [CHNL_NUM_LOG-1:0] find_chnl_num;
//     input [CHNL_NUM_LOG-1:0] prio_level;
//     input [CHNL_NUM_LOG-1:0] last_c;
//     begin
//         find_chnl_num = ((last_c+prio_level+1) >= CHNL_NUM) ? last_c+prio_level+1-CHNL_NUM : last_c+prio_level+1;
//     end
// endfunction

// function [CHNL_NUM-1:0] sel_prio;
//     input [CHNL_NUM-1:0] sel;
//     reg tmp;
//     integer i, j;
//     begin
//         sel_prio[0] = sel[0];
//         for (i = 1; i < CHNL_NUM; i = i + 1) begin
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
//     input [CHNL_NUM-1:0]  hit_prio;
//     integer i;
//     begin
//         find_nxt_chnl = {CHNL_NUM_LOG{hit_prio[0]}} & find_chnl_num(0, last_c);
//         for (i = 1; i < CHNL_NUM; i = i + 1) begin
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
assign req_last = m_axis_mux_tvalid & m_axis_mux_tready & m_axis_mux_tlast;

/* -------Find next channel{end}------- */

/* -------{Read Request Arbiter FSM}begin------- */
/******************** Stage 1: State Register **********************/
assign is_idle      = (cur_state == IDLE     );
assign is_schedule  = (cur_state == SCHEDULE );
assign is_req_trans = (cur_state == REQ_TRANS);
assign j_req_trans  = is_schedule & (!req_last) & (|s_axis_mux_tvalid);
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
        if (|s_axis_mux_tvalid) begin
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
	    else if (|s_axis_mux_tvalid) begin // There's valid channel, and not the last beat.
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
for (n = 0; n < CHNL_NUM; n = n + 1) begin:CHNL_ASSIGN

assign s_axis_mux_tready[n] = (is_schedule | is_req_trans) & (n == chnl_idx) & m_axis_mux_tready;

assign s_channel_tvalid[n] = s_axis_mux_tvalid[((n+1) * 1          -1):(n * 1          )];
assign s_channel_tlast [n] = s_axis_mux_tlast [((n+1) * 1          -1):(n * 1          )];
assign s_channel_tdata [n] = s_axis_mux_tdata [((n+1) * TDATA_WIDTH-1):(n * TDATA_WIDTH)];
assign s_channel_tuser [n] = s_axis_mux_tuser [((n+1) * TUSER_WIDTH-1):(n * TUSER_WIDTH)];

assign hit_priority[n] = s_channel_tvalid[nxt_priority[n]];

end
endgenerate
/* -------Generate block{end}------- */

assign m_axis_mux_tvalid = (is_schedule | is_req_trans) ? s_channel_tvalid[chnl_idx] : 1'd0;
assign m_axis_mux_tlast  = (is_schedule | is_req_trans) ? s_channel_tlast [chnl_idx] : 1'd0;
assign m_axis_mux_tdata  = (is_schedule | is_req_trans) ? s_channel_tdata [chnl_idx] : {TDATA_WIDTH{1'd0}};
assign m_axis_mux_tuser  = (is_schedule | is_req_trans) ? s_channel_tuser [chnl_idx] : {TUSER_WIDTH{1'd0}};

/* -------{Read Request Arbiter FSM}end------- */


endmodule
