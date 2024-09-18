`timescale 1ns / 100ps
//*************************************************************************
// > File   : cq_parser.v
// > Author : Kangning
// > Date   : 2022-03-11
// > Note   : Parser CQ interface into AXIS interface
//*************************************************************************

module cq_parser #(
    
) (
    input  wire        clk,
    input  wire        rst_n,

    /* -------Completer Requester{begin}------- */
    /*  CQ tuser
     * |  84:53 |    52:45   |   44:43  |      42     |     41      | 40  |  39:8   |   7:4   |    3:0   |
     * | parity | tph_st_tag | tph_type | tph_present | discontinue | sop | byte_en | last_be | first_be |
     * |   0    |     0      |     0    |             |             |     | ignore  |         |          |
     */
    input  wire [84           :0] cq_tuser , // i, 85
    input  wire [`PIO_DATA_W-1:0] cq_tdata , // i, `PIO_DATA_W
    input  wire                   cq_tlast , // i, 1
    input  wire                   cq_tvalid, // i, 1
    output wire                   cq_tready, // o, 1
    /* -------Completer Requester{end}------- */

    /* --------PIO Request intterface{begin}-------- */
    /* tuser
     * |  139  | 138:136 |  135:132 | 131:128 |    127:96    |   95:0  |
     * | is_wr | bar_id  | first_be | last_be | aligned_addr | cc_head |
     * |       |         |          |         |              |         |
     */
    output wire                   m_axis_req_tvalid, // o, 1
    output wire                   m_axis_req_tlast , // o, 1
    output wire [`PIO_DATA_W-1:0] m_axis_req_tdata , // o, `PIO_DATA_W
    output wire [`PIO_USER_W-1:0] m_axis_req_tuser , // o, `PIO_USER_W
    input  wire                   m_axis_req_tready  // i, 1
    /* --------PIO Request intterface{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [31:0] dbg_sel  // debug bus select
    ,output wire [31:0] dbg_bus  // debug bus data    
    /* -------APB reated signal{end}------- */
`endif
);

/* -------FSM relevant{begin}------- */
localparam  IDLE           = 4'b0001, // Idle state
            TRANS          = 4'b0010, // Trans state
            DEALIGNED_LAST = 4'b0100, // axis_req_last and cq_last assert at different time 
            ALIGNED_LAST   = 4'b1000; // axis_req_last assert when cq_last asserts 

reg [3:0] cur_state;
reg [3:0] nxt_state;

wire is_idle, is_trans, is_dealigned_last, is_aligned_last;

wire is_recv_next_pkt ; // next pkt head is received in next cycle
wire is_clear_this_pkt; // clear this pkt head in next cycle
wire is_trans_this_pkt; // trans one beat of this pkt in next cycle
/* -------FSM relevant{end}------- */

/* --------CQ REQ tmp data{begin}-------- */
reg [127:0] tmp_data;
/* --------CQ REQ tmp data{end}-------- */

/* -------Head Gen{begin}------- */
wire [ 2:0] cq_bar_id;
wire cq_is_wr;
wire [10:0] cq_dw_len;
wire [63:0] cq_addr;
wire [ 3:0] cq_first_be, cq_last_be;
wire [ 2:0] last_empty;

reg  [ 2:0] bar_id;
reg  [ 3:0] first_be;
reg  [ 3:0] last_be;

reg  [ 2:0] attrs;
reg  [ 2:0] tc;
reg  [ 7:0] trgt_func;
reg  [ 7:0] tag;
reg  [15:0] req_id;
reg  [12:0] byte_cnt;
reg  [ 1:0] at;
reg  is_wr;
reg [63:0] addr;  // address of bar space

wire [95:0] cc_head;

wire [`PIO_USER_W-1:0] axis_tuser;
wire [`PIO_USER_W-1:0] demux_tuser; // axis_tuser, only used for channel selection
/* -------Head Gen{end}------- */

/* -------axis_dw_left calc{begin}------- */
reg  [10:0] axis_dw_left;
/* -------axis_dw_left calc{end}------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire [`CQ_PARSER_SIGNAL_W-1:0] dbg_signal_cq_parser;
/* -------APB reated signal{end}------- */
`endif

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */

assign dbg_bus = dbg_signal_cq_parser >> {dbg_sel, 5'd0};

assign dbg_signal_cq_parser = { // 745
    cur_state, nxt_state, // 8
    is_idle, is_trans, is_dealigned_last, is_aligned_last, // 4
    is_recv_next_pkt , is_clear_this_pkt, is_trans_this_pkt, // 3
    tmp_data, // 128
    cq_bar_id, cq_is_wr , cq_dw_len, cq_addr, cq_first_be, cq_last_be, last_empty, // 86
    bar_id, first_be, last_be, // 11
    attrs, tc, trgt_func, tag, req_id, byte_cnt, at, is_wr, addr, // 118
    cc_head, // 96
    axis_tuser, demux_tuser, // 280
    axis_dw_left // 11
};
/* -------APB reated signal{end}------- */
`endif

/* -------CQ REQ tmp data{begin}------- */
always @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        tmp_data <= `TD 128'd0;
    end
    else if (is_clear_this_pkt) begin
        tmp_data <= `TD 128'd0;
    end
    else if (is_recv_next_pkt | is_trans_this_pkt) begin
        tmp_data <= `TD cq_tdata[255:128];
    end
end
/* -------CQ tmp data{end}------- */

/* -------Head Gen{begin}------- */

assign cq_is_wr  = cq_tdata[78:75] == 4'b0001;
assign cq_dw_len = cq_tdata[74:64];
assign cq_addr   = {cq_tdata[63:2], 2'b0};
assign cq_bar_id = cq_tdata[114:112];
assign cq_first_be = cq_tuser[3:0];
assign cq_last_be  = cq_tuser[7:4];

assign last_empty = (cq_dw_len == 1) ? 
                    (cq_first_be[3] ? 0 :
                     cq_first_be[2] ? 1 :
                     cq_first_be[1] ? 2 : 3) 
                    :
                    (cq_last_be[3] ? 0 :
                     cq_last_be[2] ? 1 :
                     cq_last_be[1] ? 2 : 3);

/* | Force ECRC |  Attr |   TC  | Completer ID en | Cpl Bus | Cpl Func |  Tag  | Req ID |
 * |     95     | 94:92 | 91:89 |       88        |  87:80  |  79:72   | 71:64 | 63:48  |
 *  ----------------------------------------------------------------------------------------------------
 * |  R | Poisioned Cpl | Cpl Status | DW cnt |  R  | Locked Rd Cpl | Byte Cnt |  R  | AT | R | Addr[6:0] |
 * | 47 |      46       |   45:43    | 42:32  |31:30|      29       |   28:16  |15:10| 9:8| 7 |   6:0     |
 */
assign cc_head = {1'b0, attrs, tc, 1'b0, 8'b0, trgt_func, tag, req_id, 
                  1'b0, 1'b0, 3'b0, byte_cnt[12:2], 2'b0, 1'b0, byte_cnt, 6'b0, at, 1'b0, addr[6:0]};

/* tuser
 * |  139  | 138:136 |  135:132 | 131:128 |    127:96    |   95:0  |
 * | is_wr | bar_id  | first_be | last_be | aligned_addr | cc_head |
 * |       |         |          |         |              |         |
 */
assign axis_tuser  = {is_wr, bar_id, first_be, last_be, addr[31:0], cc_head};
assign demux_tuser = {cq_is_wr, cq_bar_id, 4'd0, 4'd0, cq_addr[31:0], 96'd0};

always @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        bar_id      <= `TD 0;
        first_be    <= `TD 0;
        last_be     <= `TD 0;

        attrs       <= `TD 0;
        tc          <= `TD 0;
        trgt_func   <= `TD 0;
        tag         <= `TD 0;
        req_id      <= `TD 0;
        byte_cnt    <= `TD 0;
        at          <= `TD 0;
        is_wr       <= `TD 0;

        addr        <= `TD 64'd0;
    end
    else if (is_clear_this_pkt) begin
        bar_id      <= `TD 0;
        first_be    <= `TD 0;
        last_be     <= `TD 0;

        attrs       <= `TD 0;
        tc          <= `TD 0;
        trgt_func   <= `TD 0;
        tag         <= `TD 0;
        req_id      <= `TD 0;
        byte_cnt    <= `TD 0;
        at          <= `TD 0;
        is_wr       <= `TD 0;

        addr        <= `TD 64'd0;
    end
    else if (is_recv_next_pkt) begin
        bar_id      <= `TD cq_bar_id;
        first_be    <= `TD cq_tuser[3:0];
        last_be     <= `TD cq_tuser[7:4];

        attrs       <= `TD cq_tdata[126:124];
        tc          <= `TD cq_tdata[123:121];
        trgt_func   <= `TD {5'b0, cq_tdata[106:104]};
        tag         <= `TD cq_tdata[103:96];
        req_id      <= `TD cq_tdata[95:80];
        byte_cnt    <= `TD {cq_dw_len, 2'd0} - last_empty;
        at          <= `TD cq_tdata[1:0];
        is_wr       <= `TD cq_is_wr;

        addr        <= `TD cq_addr;
    end
end
/* ------Head Gen{end}------- */

/* -------axis_dw_left calc{begin}------- */
always @(posedge clk, negedge rst_n) begin
    if(~rst_n) begin
        axis_dw_left    <= `TD 0;
    end
    else if (is_clear_this_pkt) begin // clear the info related to the pkt
        axis_dw_left    <= `TD 0;
    end
    else if (is_recv_next_pkt & cq_is_wr) begin // recv next pkt in dealigned_last && in idle
        axis_dw_left    <= `TD cq_dw_len;
    end
    else if (is_trans & m_axis_req_tvalid & m_axis_req_tready) begin
        axis_dw_left    <= `TD axis_dw_left - 8;
    end
end
/* -------axis_dw_left calc{end}------- */

/* -------{CQ Parser FSM}begin------- */
/******************** Stage 1: State Register **********************/

assign is_idle           = (cur_state == IDLE          );
assign is_trans          = (cur_state == TRANS         );
assign is_dealigned_last = (cur_state == DEALIGNED_LAST);
assign is_aligned_last   = (cur_state == ALIGNED_LAST  );

assign is_recv_next_pkt  =  (is_idle           & cq_tvalid                                        ) | 
                            (is_dealigned_last & m_axis_req_tvalid & m_axis_req_tready & cq_tvalid);
assign is_clear_this_pkt =  (is_dealigned_last & m_axis_req_tvalid & m_axis_req_tready & !cq_tvalid) | 
                            (is_aligned_last   & m_axis_req_tvalid & m_axis_req_tready             );
assign is_trans_this_pkt =  (is_trans          & m_axis_req_tvalid & m_axis_req_tready);

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
            if (cq_tvalid & cq_tlast) begin
                nxt_state = DEALIGNED_LAST;
            end
            else if (cq_tvalid & cq_is_wr & (cq_dw_len <= 8)) begin
                nxt_state = ALIGNED_LAST;
            end
            else if (cq_tvalid) begin
                nxt_state = TRANS;
            end
            else begin
                nxt_state = IDLE;
            end
        end
        TRANS: begin
            if (m_axis_req_tvalid & m_axis_req_tready) begin
                if ((8 < axis_dw_left) & (axis_dw_left <= 12)) begin
                    nxt_state = DEALIGNED_LAST;
                end
                else if ((12 < axis_dw_left) & (axis_dw_left <= 16)) begin
                    nxt_state = ALIGNED_LAST;
                end
                else begin
                    nxt_state = TRANS;
                end
            end
            else begin
                nxt_state = TRANS;
            end
        end
        DEALIGNED_LAST: begin
            if (m_axis_req_tvalid & m_axis_req_tready) begin
                
                // Same as the procedure in IDLE
                if (cq_tvalid & cq_tlast) begin
                    nxt_state = DEALIGNED_LAST;
                end
                else if (cq_tvalid & cq_is_wr & (cq_dw_len <= 8)) begin
                    nxt_state = ALIGNED_LAST;
                end
                else if (cq_tvalid) begin
                    nxt_state = TRANS;
                end
                else begin
                    nxt_state = IDLE;
                end
            end
            else begin
                nxt_state = DEALIGNED_LAST;
            end
        end
        ALIGNED_LAST: begin
            if (m_axis_req_tvalid & m_axis_req_tready) begin
                nxt_state = IDLE;
            end
            else begin
                nxt_state = ALIGNED_LAST;
            end
        end
        default: begin
            nxt_state = IDLE;
        end
    endcase
end
/******************** Stage 3: Output **********************/

assign m_axis_req_tvalid  = (is_idle           & cq_tvalid) | // valid is asserted in idle state, but only demux_tuser is valid to choose correct channel
                            (is_trans          & cq_tvalid) | 
                            (is_dealigned_last            ) |
                            (is_aligned_last   & cq_tvalid);
assign m_axis_req_tlast   = m_axis_req_tvalid & (is_dealigned_last | is_aligned_last);
assign m_axis_req_tdata   = ({`PIO_DATA_W{is_dealigned_last}} & {128'd0, tmp_data}         ) |
                            ({`PIO_DATA_W{is_aligned_last  }} & {cq_tdata[127:0], tmp_data}) |
                            ({`PIO_DATA_W{is_trans         }} & {cq_tdata[127:0], tmp_data});
assign m_axis_req_tuser   = ({`PIO_USER_W{is_idle                                       }} & demux_tuser) |
                            ({`PIO_USER_W{is_trans | is_dealigned_last | is_aligned_last}} & axis_tuser );

assign cq_tready =  is_idle                                |
                   (is_trans          & m_axis_req_tready) |
                   (is_dealigned_last & m_axis_req_tready) |
                   (is_aligned_last   & m_axis_req_tready);
                   
/* -------{CQ Parser FSM}end------- */
endmodule