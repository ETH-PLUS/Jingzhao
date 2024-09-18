`timescale 1ns / 100ps
//*************************************************************************
// > File   : cc_composer.v
// > Author : Kangning
// > Date   : 2022-03-12
// > Note   : Interface between PCIe core and BAR space
// >          Commpose AXIS interface into CC interface
//*************************************************************************

module cc_composer #(
    
) (

    input  wire        clk,
    input  wire        rst_n,

    /* -------Completer Completion{begin}------- */
    /*  CC tuser
     * |  32:1  |      0      |
     * | parity | discontinue |
     * | ignore |   ignore    |
     */
    output wire [`PIO_DATA_W-1:0] cc_tdata , // o, `PIO_DATA_W
    output wire                   cc_tlast , // o, 1
    output wire [`PIO_KEEP_W-1:0] cc_tkeep , // o, `PIO_KEEP_W
    output wire                   cc_tvalid, // o, 1
    input  wire                   cc_tready, // i, 1
    /* -------Completer Completion{end}------- */

    /* --------PIO Response interface{begin}-------- */
    /* tuser
     * |  139  | 138:136 |  135:132 | 131:128 |    127:96    |   95:0  |
     * | is_wr | bar_id  | first_be | last_be | aligned_addr | cc_head |
     * |       |         |          |         |              |         |
     */
    input  wire [`PIO_DATA_W-1:0]  s_axis_rrsp_tdata , // i, `PIO_DATA_W
    input  wire [`PIO_USER_W-1:0]  s_axis_rrsp_tuser , // i, `PIO_USER_W
    input  wire                    s_axis_rrsp_tlast , // i, 1
    input  wire                    s_axis_rrsp_tvalid, // i, 1
    output wire                    s_axis_rrsp_tready  // o, 1
    /* --------PIO Response interface{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [31:0] dbg_sel  // debug bus select
    ,output wire [31:0] dbg_bus  // debug bus data    
    /* -------APB reated signal{end}------- */
`endif
);

/* -------FSM relevant{begin}------- */
localparam  IDLE  = 2'b01, // Wait for CQ input; store the head at this time
            TRANS = 2'b10; // Input Write|Read Request; assert cq ready only in this time

reg [1:0] cur_state;
reg [1:0] nxt_state;

wire is_idle, is_trans;
wire j_trans, j_idle;
/* -------FSM relevant{end}------- */


/* -------CC data{begin}------- */
wire [`PIO_DATA_W-1:0] data;
reg [95:0] tmp_data;      // PIO rsp data (including head)
reg is_sop;
/* -------CC data{end}------- */

/* -------CC Head{begin}------- */
wire is_extra_beat; // indicate that this is the extra beat
reg has_extra_beat; // indicate that this packet has extra beat
reg [95:0] cc_head;
/* -------CC Head{end}------- */

/* -------Last gennerate{begin}-------- */
wire                   last;
wire [`PIO_KEEP_W-1:0] keep;
reg  [12           :0] dw_left; // should be larger, cause head also be added in this reg
/* -------Last gennerate{end}-------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire [`CC_COMPOSER_SIGNAL_W-1:0] dbg_signal_cc_composer;
/* -------APB reated signal{end}------- */
`endif

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */

assign dbg_bus = dbg_signal_cc_composer >> {dbg_sel, 5'd0};

assign dbg_signal_cc_composer = { // 481
    cur_state, nxt_state, is_idle, is_trans, j_trans, j_idle, // 8
    data, tmp_data, is_sop, // 353
    is_extra_beat, has_extra_beat, cc_head, // 98
    last, keep, dw_left // 22
};
/* -------APB reated signal{end}------- */
`endif

/* -------CC data{begin}------- */
assign data = is_sop ? {s_axis_rrsp_tdata[159:0], cc_head} : {s_axis_rrsp_tdata[159:0], tmp_data};
always @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        tmp_data <= `TD 96'd0;
    end
    else if (is_trans & cc_tvalid & cc_tready & cc_tlast) begin
        tmp_data <= `TD 96'd0;
    end
    else if (is_trans & cc_tvalid & cc_tready) begin
        tmp_data <= `TD s_axis_rrsp_tdata[255:160];
    end
end
always @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        is_sop <= `TD 1'd0;
    end
    else if (j_trans) begin
        is_sop <= `TD 1'd1;
    end
    else if (is_trans & s_axis_rrsp_tvalid & s_axis_rrsp_tready) begin
        is_sop <= `TD 1'd0;
    end
end
/* -------CC data{end}------- */

/* -------CC head{begin}------- */
assign is_extra_beat = has_extra_beat & cc_tlast;
/* CC head
 * | Force ECRC |  Attr |   TC  | Completer ID en | Cpl Bus | Cpl Func |  Tag  | Req ID |
 * |     95     | 94:92 | 91:89 |       88        |  87:80  |  79:72   | 71:64 | 63:48  |
 *  ----------------------------------------------------------------------------------------------------
 * |  R | Poisioned Cpl | Cpl Status | DW cnt |  R  | Locked Rd Cpl | Byte Cnt |  R  | AT | R | Addr[6:0] |
 * | 47 |      46       |   45:43    | 42:32  |31:30|      29       |   28:16  |15:10| 9:8| 7 |   6:0     |
 */
always @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        cc_head        <= `TD 96'd0;
        has_extra_beat <= `TD 1'd0;
    end
    else if (j_trans) begin
        cc_head        <= `TD s_axis_rrsp_tuser[95:0];
        has_extra_beat <= `TD (s_axis_rrsp_tuser[34:32] > 5);
    end
    else if (j_idle) begin
        cc_head        <= `TD 96'd0;
        has_extra_beat <= `TD 1'd0;
    end
end
/* -------CC head{end}------- */

/* -------Last gennerate{begin}-------- */
assign last = (dw_left <= 13'd8);
assign keep = (dw_left >= 13'd8) ? 8'hFF : 
              (dw_left == 13'd7) ? 8'h7F :
              (dw_left == 13'd6) ? 8'h3F :
              (dw_left == 13'd5) ? 8'h1F :
              (dw_left == 13'd4) ? 8'h0F :
              (dw_left == 13'd3) ? 8'h07 :
              (dw_left == 13'd2) ? 8'h03 :
              (dw_left == 13'd1) ? 8'h01 : 8'h00;
always @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        dw_left <= `TD 13'd0;
    end
    else if (j_trans) begin
        dw_left <= `TD {2'd0, s_axis_rrsp_tuser[42:32]} + 13'd3;
    end
    else if (is_trans) begin
        dw_left <= `TD dw_left - 13'd8;
    end
end
/* -------Last gennerate{end}-------- */

/* -------{CC Composer FSM}begin------- */
/******************** Stage 1: State Register **********************/

assign is_idle  = ( cur_state == IDLE  );
assign is_trans = ( cur_state == TRANS );
assign j_trans  = is_idle  & s_axis_rrsp_tvalid;
assign j_idle   = is_trans & cc_tvalid & cc_tready & cc_tlast;

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
            if (s_axis_rrsp_tvalid) begin
                nxt_state = TRANS;
            end
            else begin
                nxt_state = IDLE;
            end
        end
        TRANS: begin
            if (cc_tvalid & cc_tready & cc_tlast) begin
                nxt_state = IDLE;
            end
            else begin
                nxt_state = TRANS;
            end
        end
        default: begin
            nxt_state = IDLE;
        end
    endcase
end
/******************** Stage 3: Output **********************/

/* -------CC Interface{begin}------- */
assign cc_tdata  = is_trans ? data : {`PIO_DATA_W{1'd0}};
assign cc_tlast  = is_trans ? last : 1'd0;
assign cc_tkeep  = is_trans ? keep : {`PIO_KEEP_W{1'd0}};
assign cc_tvalid = is_trans ? s_axis_rrsp_tvalid : 1'd0;

assign s_axis_rrsp_tready = is_trans ? (is_extra_beat ? 1'd0 : cc_tready) : 1'd0;
/* -------CC Interface{end}------- */
//------------------------------{CC Composer FSM}end------------------------------//
endmodule