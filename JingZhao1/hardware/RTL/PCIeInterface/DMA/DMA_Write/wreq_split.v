`timescale 1ns / 100ps
//*************************************************************************
// > File Name : wreq_split.v
// > Author    : Kangning
// > Date      : 2021-09-16
// > Note      : split one wr req into multiply small subreq
//*************************************************************************
`define DMA_KEEP_MASK {`DMA_KEEP_W{1'd1}}

module wreq_split #(
    
) (
    input wire  clk  , // i, 1
    input wire  rst_n, // i, 1

    input wire [2:0] max_pyld_sz, // i, 3

    /* -------aligned write request intrface{begin}------- */
    /* AXI-Stream write request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     * or
     * AXI-Stream interrupt request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |  Resv  | address | Reserved |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:0    |
     */
    input  wire                     align_valid, // i, 1
    input  wire                     align_last , // i, 1
    input  wire [`AXIS_TUSER_W-1:0] align_user , // i, `AXIS_TUSER_W
    input  wire [`DMA_DATA_W  -1:0] align_data , // i, `DMA_DATA_W
    output wire                     align_ready, // o, 1
    /* -------aligned write request intrface{end}------- */

    /* -------axis write request interface{begin}------- */
    /* AXI-Stream write request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     * or
     * AXI-Stream interrupt request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |  Resv  | address | Reserved |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:0    |
     */
    output wire                     axis_wr_req_tvalid,
    output wire                     axis_wr_req_tlast ,
    output wire [`DMA_DATA_W  -1:0] axis_wr_req_tdata ,
    output wire [`AXIS_TUSER_W-1:0] axis_wr_req_tuser ,
    output wire [`DMA_KEEP_W  -1:0] axis_wr_req_tkeep ,
    input  wire                     axis_wr_req_tready 
    /* -------axis write request interface{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,output wire [`WREQ_SPLIT_SIGNAL_W-1:0] dbg_signal // o, `WREQ_SPLIT_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

/* -------Constant Value{begin}------- */
localparam MIN_DWORD_SZ_LOG  =  5;    // min dwords size for 128B axis packet (2 ^ 5 Dword)
wire [`DW_LEN_WIDTH-1:0] max_pyld_dw; // Maximum payload size in dw (in one sub req)
/* -------Constant Value{end}------- */

/* -------relate to in_reg{begin}------- */
reg                      in_reg_vld ;  // read valid from input register
reg  [`AXIS_TUSER_W-1:0] in_reg_user;
reg  [`DMA_DATA_W  -1:0] in_reg_data;
wire [`DMA_KEEP_W  -1:0] in_reg_keep;
wire                     in_reg_rdy ;

reg                       in_reg_sop ; // Indicate the start of a pkt
/* -------relate to in_reg{end}------- */

/* -------Head relevant{begin}------- */
// align user decode
wire [`DW_LEN_WIDTH  -1:0]  dw_len  ;
wire [`FIRST_BE_WIDTH-1:0]  first_be;
wire [`LAST_BE_WIDTH -1:0]  last_be ;
wire [`DMA_ADDR_WIDTH-1:0]  addr    ;
wire [3:0]                  req_type;

// axis_tuser decode
wire [`DW_LEN_WIDTH  -1:0]  sub_dw_len  ;
wire [`FIRST_BE_WIDTH-1:0]  sub_first_be;
wire [`LAST_BE_WIDTH -1:0]  sub_last_be ;
wire [`DMA_ADDR_WIDTH-1:0]  sub_addr    ;

reg  [`DW_LEN_WIDTH  -1:0] dw_cnt , sub_dw_cnt ;
wire [`DW_LEN_WIDTH  -1:0] dw_left, sub_dw_left;
wire [`DW_LEN_WIDTH  -1:0] dw_left_dyn; // how many dw left, count down in dynamically

wire [`AXIS_TUSER_W-1:0] int_tuser, wreq_tuser;
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

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign dbg_signal = { // 906
    max_pyld_dw, // 11
    in_reg_vld, in_reg_user, in_reg_data, in_reg_keep, in_reg_rdy, // 394
    in_reg_sop, // 1
    dw_len, first_be, last_be, addr, req_type, // 87
    sub_dw_len, sub_first_be, sub_last_be, sub_addr, // 83
    dw_cnt, sub_dw_cnt, // 22
    dw_left, sub_dw_left, // 22
    dw_left_dyn, // 11
    int_tuser, wreq_tuser, // 256
    first_sub_req, last_sub_req,  // 2
    next_req_last, next_sub_last, // 2
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

assign wreq_tuser = {20'd0, req_type, 8'd0, sub_addr, 13'd0, sub_dw_len, sub_first_be, sub_last_be};
assign int_tuser  = {20'd0, req_type, 8'd0, sub_addr, 32'd0};
/* -------tuser logic{end}------- */

/* -------Split packet{begin}------- */
assign first_sub_req = dw_cnt == 0;
assign last_sub_req  = dw_left <= max_pyld_dw;
assign next_req_last = (dw_left_dyn <= `DMA_KEEP_W * 2) & (dw_left_dyn > `DMA_KEEP_W);
assign next_sub_last = (sub_dw_left > `DMA_KEEP_W) & (sub_dw_left <= (`DMA_KEEP_W * 2));

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
        sub_dw_cnt <= `TD sub_dw_cnt + `DMA_KEEP_W;
    end
end

/* -------Split packet{end}------- */

/* -------{DMA Write Request FSM}begin------- */
/******************** Stage 1: State Register **********************/
assign is_idle      = (cur_state == IDLE    );
assign is_tx        = (cur_state == TX      );
assign is_sub_last  = (cur_state == SUB_LAST);
assign is_req_last  = (cur_state == REQ_LAST);

assign beat_go   = axis_wr_req_tvalid & axis_wr_req_tready;
assign sub_clear = axis_wr_req_tvalid & axis_wr_req_tready & axis_wr_req_tlast;
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
assign axis_wr_req_tvalid = in_reg_vld;
assign axis_wr_req_tlast  = is_req_last | is_sub_last;
assign axis_wr_req_tuser  = req_type == `DMA_INT_REQ ? int_tuser : wreq_tuser;
assign axis_wr_req_tdata  = in_reg_data;
assign axis_wr_req_tkeep  = in_reg_keep;

assign in_reg_rdy = axis_wr_req_tready;


assign in_reg_keep = (sub_dw_left >= 8) ? 
                     `DMA_KEEP_MASK : 
                     (`DMA_KEEP_MASK >> (`DMA_KEEP_W - sub_dw_left));

/* -------{DMA Write Request FSM}end------- */

endmodule