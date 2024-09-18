`timescale 1ns / 100ps
//*************************************************************************
// > File Name : pio_rsp_split.v
// > Author    : Kangning
// > Date      : 2022-03-12
// > Note      : split one wr req into multiply small subreq
// >            V1.1 - 2022-03-12 : Copied from wreq_split.v
//*************************************************************************
`define PIO_KEEP_MASK {`PIO_KEEP_W{1'd1}}

module pio_rsp_split #(
    parameter USER_WIDTH  = `ALIGN_HEAD_W
) (
    input wire  clk  , // i, 1
    input wire  rst_n, // i, 1

    input wire [2:0] max_pyld_sz, // i, 3

    /* -------aligned intrface{begin}------- */
    /* AXI-Stream aligned interface tuser, only valid in first beat of a packet
     * |     Extra tuser        | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
     * |USER_WIDTH-`ALIGN_HEAD_W| 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     */
    input  wire                   align_valid, // i, 1
    input  wire                   align_last , // i, 1
    input  wire [USER_WIDTH -1:0] align_user , // i, USER_WIDTH
    input  wire [`PIO_DATA_W-1:0] align_data , // i, `PIO_DATA_W
    output wire                   align_ready, // o, 1
    /* -------aligned intrface{end}------- */

    /* -------splited interface{begin}------- */
    /* AXI-Stream splited interface tuser, only valid in first beat of a packet
     * |      Extra tuser       | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
     * |USER_WIDTH-`ALIGN_HEAD_W| 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     */
    output wire [`PIO_DATA_W-1:0] splited_tdata ,
    output wire [`PIO_KEEP_W-1:0] splited_tkeep ,
    output wire [USER_WIDTH -1:0] splited_tuser ,
    output wire                   splited_tlast ,
    output wire                   splited_tvalid,
    input  wire                   splited_tready
    /* -------axis splited interface{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,output wire [`PIO_RSP_SPLIT_SIGNAL_W-1:0] dbg_signal // o, `PIO_RSP_SPLIT_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

/* -------Constant Value{begin}------- */
localparam MIN_DWORD_SZ_LOG  =  5;    // min dwords size for 128B axis packet (2 ^ 5 Dword)
wire [11-1:0] max_pyld_dw; // Maximum payload size in dw (in one sub req)
/* -------Constant Value{end}------- */

/* -------relate to in_reg{begin}------- */
reg                    in_reg_vld ;  // read valid from input register
reg  [USER_WIDTH -1:0] in_reg_user;
reg  [`PIO_DATA_W-1:0] in_reg_data;
wire [`PIO_KEEP_W-1:0] in_reg_keep;
wire                   in_reg_rdy ;

reg                     in_reg_sop ; // Indicate the start of a pkt
/* -------relate to in_reg{end}------- */

/* -------Head relevant{begin}------- */
// align user decode
wire [11-1:0]  dw_len  ;
wire [4 -1:0]  first_be;
wire [4 -1:0]  last_be ;
wire [64-1:0]  addr    ;
wire [3:0]     req_type;

// axis_tuser decode
wire [11-1:0]  sub_dw_len  ;
wire [4 -1:0]  sub_first_be;
wire [4 -1:0]  sub_last_be ;
wire [64-1:0]  sub_addr    ;

reg  [11-1:0] dw_cnt , sub_dw_cnt ;
wire [11-1:0] dw_left, sub_dw_left;
wire [11-1:0] dw_left_dyn; // how many dw left, count down in dynamically

wire [USER_WIDTH-1:0] int_tuser, wreq_tuser;
/* -------Head relevant{end}------- */

/* -------Split packet{begin}------- */
wire first_sub_req, last_sub_req;
wire next_req_last, next_sub_last;
/* -------Split packet{end}------- */

/* -------State relevant in FSM{begin}------- */
localparam  IDLE     = 4'b0001,
            TX       = 4'b0010, // Transmit normal beat.
            SUB_LAST = 4'b0100, // TX the last beat of sub req.
            REQ_LAST = 4'b1000; // TX the last beat of the enire req
reg [3:0] cur_state;
reg [3:0] nxt_state;
wire is_idle, is_tx, is_sub_last, is_req_last;

wire beat_go  ; // When asserted, one beat go out of axis_* interface
wire sub_clear; // When asserted, last beat of sub req are forwarded  
wire req_clear; // When asserted, last beat of entire req are forwarded
/* -------State relevant in FSM{end}------- */

/* --------------------------------------------------------------------------------------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */

assign dbg_signal = { // 1302
    max_pyld_dw, // 11
    in_reg_vld, in_reg_user, in_reg_data, in_reg_keep, in_reg_rdy, in_reg_sop, // 527
    dw_len, first_be, last_be, addr, req_type, // 87
    sub_dw_len, sub_first_be, sub_last_be, sub_addr, // 83
    dw_cnt, sub_dw_cnt, dw_left, sub_dw_left, dw_left_dyn, // 55
    int_tuser, wreq_tuser, // 520
    first_sub_req, last_sub_req, next_req_last, next_sub_last, // 4
    cur_state, nxt_state, // 8
    is_idle, is_tx, is_sub_last, is_req_last, // 4
    beat_go, sub_clear, req_clear // 3
};

/* -------APB reated signal{end}------- */
`endif


/* -------Constant Value{begin}------- */
assign max_pyld_dw = 1'd1 << (MIN_DWORD_SZ_LOG + max_pyld_sz);
/* -------Constant Value{end}------- */

/* -------in_reg logic{begin}------- */
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        in_reg_sop  <= `TD 1;
    end
    else if (align_valid & align_ready & align_last) begin
        in_reg_sop  <= `TD 1;
    end
    else if (align_valid & align_ready & in_reg_sop) begin
        in_reg_sop  <= `TD 0;
    end
end

always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        in_reg_user <= `TD 0;
    end
    else if (align_valid & align_ready & in_reg_sop) begin
        in_reg_user <= `TD align_user;
    end
    else if (req_clear) begin // after trans finished, in_reg_user is set to 0
        in_reg_user <= `TD 0;
    end
end

always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        in_reg_vld  <= `TD 0;
        in_reg_data <= `TD 0;
    end
    else if (align_valid & align_ready) begin // write en & not full
        in_reg_vld  <= `TD 1;
        in_reg_data <= `TD align_data;
    end
    else if (in_reg_rdy & in_reg_vld) begin // read en & not empty
        in_reg_vld  <= `TD 0;
        in_reg_data <= `TD 0;
    end
end

assign align_ready  = !in_reg_vld | in_reg_rdy; // empty | going to empty
/* -------in_reg logic{end}------- */

/* -------tuser logic{begin}------- */
assign dw_len   = in_reg_user[18:8 ];
assign first_be = in_reg_user[7 :4 ];
assign last_be  = in_reg_user[3 :0 ];
assign addr     = in_reg_user[95:32];
assign req_type = in_reg_user[107:104];

assign sub_dw_len   = last_sub_req ? dw_left : max_pyld_dw;
// assign sub_first_be =  ? first_be : 4'b1111;
// assign sub_last_be  = last_sub_req  ? last_be  : 4'b1111;
assign sub_addr     = addr + (dw_cnt << 2);

assign sub_first_be = (dw_len     == 1) ? (first_be & last_be) : // when the req only has one DW
                      (sub_dw_len == 1) ? (4'b1111  & last_be) : // when the sub_req has one DW.
                      first_sub_req      ? first_be : 4'b1111;
assign sub_last_be  = (sub_dw_len == 1) ? 4'b0000 : // when the payload has one DW, last_be should be 0.
                      last_sub_req   ? last_be : 4'b1111;

assign wreq_tuser = {in_reg_user[USER_WIDTH-1:`ALIGN_HEAD_W], 
                        20'd0, req_type, 8'd0, sub_addr, 13'd0, sub_dw_len, sub_first_be, sub_last_be};
assign int_tuser  = {in_reg_user[USER_WIDTH-1:`ALIGN_HEAD_W], 
                        20'd0, req_type, 8'd0, sub_addr, 32'd0};
/* -------tuser logic{end}------- */

/* -------Split packet{begin}------- */
assign first_sub_req = dw_cnt == 0;
assign last_sub_req  = dw_left <= max_pyld_dw;
assign next_req_last = (dw_left_dyn <= (`PIO_KEEP_W << 1)) & (dw_left_dyn > `PIO_KEEP_W);
assign next_sub_last = (sub_dw_left > `PIO_KEEP_W) & (sub_dw_left <= (`PIO_KEEP_W << 1));

assign dw_left_dyn = dw_left - sub_dw_cnt;
assign dw_left = dw_len - dw_cnt;
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        dw_cnt <= `TD 0;
    end
    else if (req_clear) begin
        dw_cnt <= `TD 0;
    end
    else if (sub_clear) begin // beat_go & is_sub_last
        dw_cnt <= `TD dw_cnt + max_pyld_dw;
    end
end

assign sub_dw_left = sub_dw_len - sub_dw_cnt;
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        sub_dw_cnt <= `TD 0;
    end
    else if (sub_clear) begin
        sub_dw_cnt <= `TD 0;
    end
    else if (beat_go) begin
        sub_dw_cnt <= `TD sub_dw_cnt + `PIO_KEEP_W;
    end
end

/* -------Split packet{end}------- */

/* -------{DMA Write Request FSM}begin------- */
/******************** Stage 1: State Register **********************/
assign is_idle      = (cur_state == IDLE    );
assign is_tx        = (cur_state == TX      );
assign is_sub_last  = (cur_state == SUB_LAST);
assign is_req_last  = (cur_state == REQ_LAST);

assign beat_go   = splited_tvalid & splited_tready;
assign sub_clear = splited_tvalid & splited_tready & splited_tlast;
assign req_clear = sub_clear & in_reg_sop;

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
            if (align_valid & align_ready & align_last)
                nxt_state = REQ_LAST;
            else if (align_valid & align_ready)
                nxt_state = TX;
            else
                nxt_state = IDLE;
        end
        TX: begin
            if (beat_go & next_req_last)
                nxt_state = REQ_LAST;
            else if (beat_go & next_sub_last)
                nxt_state = SUB_LAST;
            else
                nxt_state = TX;
        end
        SUB_LAST: begin
            if (sub_clear & next_req_last)
                nxt_state = REQ_LAST;
            else if (sub_clear)
                nxt_state = TX;
            else
                nxt_state = SUB_LAST;
        end
        REQ_LAST: begin
            if (sub_clear) begin
                if (align_valid & align_ready & align_last) // Next req's comming and 
                                                            // is a one-beat req
                    nxt_state = REQ_LAST;
                else if (align_valid & align_ready) // Next req is comming
                    nxt_state = TX;
                else // No incomming next req
                    nxt_state = IDLE;
                end
            else
                nxt_state = REQ_LAST;
        end
        default: begin
            nxt_state = IDLE;
        end
    endcase
end
/******************** Stage 3: Output **********************/
assign splited_tvalid = in_reg_vld;
assign splited_tlast  = is_req_last | is_sub_last;
assign splited_tuser  = req_type == 4'h2 ? int_tuser : wreq_tuser;
assign splited_tdata  = in_reg_data;
assign splited_tkeep  = in_reg_keep;

assign in_reg_rdy = splited_tready;


assign in_reg_keep = (sub_dw_left >= 8) ? 
                     `PIO_KEEP_MASK : 
                     (`PIO_KEEP_MASK >> (`PIO_KEEP_W - sub_dw_left));

/* -------{DMA Write Request FSM}end------- */

endmodule