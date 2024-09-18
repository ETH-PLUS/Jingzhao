`timescale 1ns / 100ps
//*************************************************************************
// > File Name: rrsp_dealign.v
// > Author   : Kangning
// > Date     : V1.0 -- 2021-04-14
// > Note     : double word dealignment, transfrom data from double word 
// >               alignment into address alignment.
// > V1.0 -- 2021-04-14: Transfrom data from double word 
// >                     alignment into address alignment. The structure 
// >                     is as follows:
// > ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
// > ^                                                              ^
// > ^        ##########       ###########                          ^
// > ^        #        #------># tmp_reg #      ###########         ^
// > ^ ------># in_reg #       ###########----->#         #         ^
// > ^        #        #                        # out_reg #---->    ^
// > ^        ##########----------------------->#         #         ^
// > ^                                          ###########         ^
// > ^                                                              ^
// > ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
//*************************************************************************
//`include "../lib/global_include_h.v"
//`include "../lib/dma_def_h.v"

module rrsp_dealign #(
    
) (
    input wire dma_clk, // i, 1
    input wire rst_n   , // i, 1


    /* -------axis read response interface{begin}------- */
    /* AXI-Stream read response tuser, interact with read response distributor.
     * Only valid in first beat of a packet
     * | Reserved | REQ CPL |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 119:105  |   104   | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     */
    input  wire                     axis_rd_rsp_tvalid, // i, 1
    input  wire                     axis_rd_rsp_tlast , // i, 1
    input  wire [`DMA_DATA_W  -1:0] axis_rd_rsp_tdata , // i, `DMA_DATA_W
    input  wire [`AXIS_TUSER_W-1:0] axis_rd_rsp_tuser , // i, `AXIS_TUSER_W
    input  wire [`DMA_KEEP_W  -1:0] axis_rd_rsp_tkeep , // i, `DMA_KEEP_W
    output wire                     axis_rd_rsp_tready, // o, 1
    /* -------axis read response interface{end}------- */


    /* ------- Read Response store to Reorder Buffer{begin} ------- */
    /* *_head (interact with <reorder_buffer> module, valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    output wire                    rd_rsp_dealign_valid, // o, 1
    output wire                    rd_rsp_dealign_last , // o, 1 ; assert in every last beat of sub-rsp pkt
    output wire                    rd_rsp_dealign_eop  , // o, 1 ; assert when this is the last sub-rsp pkt
    output wire[`DW_LEN_WIDTH-1:0] rd_rsp_dealign_dlen , // o, `DW_LEN_WIDTH
    output wire[`TAG_NUM_LOG -1:0] rd_rsp_dealign_tag  , // o, `TAG_NUM_LOG
    output wire[`DMA_HEAD_W  -1:0] rd_rsp_dealign_head , // o, `DMA_HEAD_W
    output wire[`DMA_DATA_W  -1:0] rd_rsp_dealign_data , // o, `DMA_DATA_W
    input  wire                    rd_rsp_dealign_ready  // i, 1
    /* ------- Read Response store to Reorder Buffer{end} ------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,output wire [`RSP_DEALIGN_SIGNAL_W-1:0] dbg_signal  // o, `RSP_DEALIGN_SIGNAL_W  
    /* -------APB reated signal{end}------- */
`endif
);

/* -------DW Dealignment FSM{begin}------- */
localparam IDLE       = 3'b001, // This state wait for the first beat of the packet, 
                                // and store its header.
           RSP_BEAT   = 3'b010, // This state caches middle beat of packet.
           LAST_BEAT  = 3'b100; // This state caches last beat of packet, in this state, 
                                // caching new packet beat is not allowed.

reg [4:0] cur_state;
reg [4:0] nxt_state;

wire is_idle, is_rsp_beat, is_last_beat;
/* -------DW Dealignment FSM{end}------- */

/* -------Relate to head generation{begin}------- */ 
wire [`AXIS_TUSER_W-1:0] axis_rd_rsp_thead;

// axis axis_rd_rsp_tuser
// wire [`TAG_WIDTH     -1:0] tag       ;
wire [`DMA_ADDR_WIDTH-1:0] addr_align ;
wire [`DW_LEN_WIDTH  -1:0] axis_dw_len;
wire [`FIRST_BE_WIDTH-1:0] first_be   ;
wire [`LAST_BE_WIDTH -1:0] last_be    ;

// relate to sub_req_rsp_head
wire [1:0]               first_empty ; // Number of invalid bytes in first Double word
wire [1:0]               last_empty  ; // Number of invalid bytes in last  Double word

wire [`DMA_ADDR_WIDTH-1:0] addr_unalign;
wire [`DMA_LEN_WIDTH -1:0] byte_len    ;

wire rd_rsp_dealign_next_last; // Indicate that in next cycle, rd_rsp_dealign_last asserted

wire [5:0] axis_beats_total;
wire [5:0] dealign_beats_total;
reg  [5:0] dealign_beats_left; // The number of beats left to trans (not including the beat of this cycle)

reg  is_aligned_last; // Indicate that this pkt is a aligned pkt, whose out_last (rd_rsp_dealigned_*) 
                      // asserts at the same time when in_last (axis_rd_rsp_*) asserts
/* -------Relate to head generation{end}------- */

// in reg is used to cache input axis data.
/* -------relate to in_reg{begin}------- */
wire                      in_reg_tvalid;  // read valid from input register
wire                      in_reg_tlast;
wire  [`AXIS_TUSER_W-1:0] in_reg_tuser;
wire  [`DMA_DATA_W  -1:0] in_reg_tdata;
wire                      in_reg_tready;
/* -------relate to in_reg{end}------- */

/* -------relate to out_reg{begin}------- */
// reg  [`DMA_LEN_WIDTH-1:0] byte_cnt_down;

reg  [`DMA_DATA_W-1:0] in_out_data; // transform data between tmp_reg and out_reg
/* -------relate to tmp_reg{end}------- */

/* All these signals are valid in the entire trans peroid of packet */
wire                     is_eop;
wire [`DW_LEN_WIDTH-1:0] dw_len;
wire [`TAG_WIDTH   -1:0] tag   ;

/* --------------------------------------------------------------------------------------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign dbg_signal = { // 988
    cur_state, nxt_state, // 10
    is_idle, is_rsp_beat, is_last_beat, // 3
    axis_rd_rsp_thead, // 128
    is_eop, addr_align , axis_dw_len, first_be, last_be, // 83
    first_empty, last_empty, // 4
    addr_unalign, byte_len, // 77
    rd_rsp_dealign_next_last, // 1
    axis_beats_total, dealign_beats_total, dealign_beats_left, // 18
    is_aligned_last, // 1
    in_reg_tvalid, in_reg_tlast, in_reg_tuser, in_reg_tdata, in_reg_tready, // 387
    in_out_data, // 256
    is_eop, dw_len, tag // 20
};
/* -------APB reated signal{end}------- */
`endif

st_reg #(
    .TUSER_WIDTH ( `AXIS_TUSER_W ),
    .TDATA_WIDTH ( `DMA_DATA_W  ),
    .MODE        ( 1 )
) in_reg (
    .clk   ( dma_clk ), // i, 1
    .rst_n ( rst_n   ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( axis_rd_rsp_tvalid ), // i, 1
    .axis_tlast  ( axis_rd_rsp_tlast  ), // i, 1
    .axis_tuser  ( axis_rd_rsp_thead  ), // i, TUSER_WIDTH
    .axis_tdata  ( axis_rd_rsp_tdata  ), // i, `DMA_DATA_W
    .axis_tready ( axis_rd_rsp_tready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .axis_reg_tvalid ( in_reg_tvalid ), // o, 1
    .axis_reg_tlast  ( in_reg_tlast  ), // o, 1
    .axis_reg_tuser  ( in_reg_tuser  ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( in_reg_tdata  ), // o, `DMA_DATA_W
    .axis_reg_tready ( in_reg_tready )  // i, 1
    /* -------output in_reg inteface{end}------- */
);

/* -------DW Dealignment FSM{begin}------- */
/******************** Stage 1: State Register **********************/

assign is_idle      = (cur_state == IDLE     );
assign is_rsp_beat  = (cur_state == RSP_BEAT );
assign is_last_beat = (cur_state == LAST_BEAT);

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
            if (axis_rd_rsp_tvalid & rd_rsp_dealign_next_last) begin
                nxt_state = LAST_BEAT;
            end
            else if (axis_rd_rsp_tvalid) begin
                nxt_state = RSP_BEAT;
            end
            else begin
                nxt_state = IDLE;
            end
        end
        RSP_BEAT: begin
            if (axis_rd_rsp_tvalid && axis_rd_rsp_tready && rd_rsp_dealign_next_last) begin
                nxt_state = LAST_BEAT;
            end
            else begin
                nxt_state = RSP_BEAT;
            end
        end
        LAST_BEAT: begin
            if (rd_rsp_dealign_valid & rd_rsp_dealign_ready & rd_rsp_dealign_last) begin
                if (axis_rd_rsp_tvalid & axis_rd_rsp_tready & is_aligned_last) begin
                    nxt_state = IDLE;
                end
                else if (axis_rd_rsp_tvalid & axis_rd_rsp_tready & rd_rsp_dealign_next_last) begin
                    nxt_state = LAST_BEAT;
                end
                else if (axis_rd_rsp_tvalid & axis_rd_rsp_tready) begin
                    nxt_state = RSP_BEAT;
                end
                else begin
                    nxt_state = IDLE;
                end
            end
            else begin
                nxt_state = LAST_BEAT;
            end
        end
        default: begin
            nxt_state = IDLE;
        end
    endcase
end
/******************** Stage 3: Output **********************/

assign in_reg_tready = (rd_rsp_dealign_valid & rd_rsp_dealign_ready) | is_idle;

/* -------DW Dealignment FSM{end}------- */


/* -------next_last{begin}------- */
assign rd_rsp_dealign_next_last = (is_idle      & (dealign_beats_total == 1)) | // Asserts when next pkt has only one beat
                                  (is_rsp_beat  & (dealign_beats_left == 1))                              | // Asserts when this pkt forward last beat next cycle.
                                  (is_last_beat & !is_aligned_last & (dealign_beats_total == 1));  // Asserts when next pkt has only one beat


/* -------next_last{end}------- */

/* -------Head generation{begin}------- */

assign addr_align  = axis_rd_rsp_tuser[95             :32];
assign axis_dw_len = axis_rd_rsp_tuser[18             : 8];
assign first_be    = axis_rd_rsp_tuser[7              : 4];
assign last_be     = axis_rd_rsp_tuser[3              : 0];

assign first_empty  = first_be[0] ? 2'd0 :
                      first_be[1] ? 2'd1 :
                      first_be[2] ? 2'd2 :
                      first_be[3] ? 2'd3 : 
                      2'd0; // unlikely
assign last_empty   = (axis_dw_len == 1) ?
                      (first_be[3] ? 2'd0 :
                       first_be[2] ? 2'd1 :
                       first_be[1] ? 2'd2 : 2'd3) :
                      ({2{(last_be  == 4'b1111)}} & 2'd0 |
                       {2{(last_be  == 4'b0001)}} & 2'd3 |
                       {2{(last_be  == 4'b0011)}} & 2'd2 |
                       {2{(last_be  == 4'b0111)}} & 2'd1);

assign addr_unalign = {addr_align[`DMA_ADDR_WIDTH-1:2], first_empty};
assign byte_len     = (axis_dw_len << 2) - first_empty - last_empty;

assign dealign_beats_total = byte_len[`DMA_LEN_WIDTH-1:5] + (|byte_len[4:0]);
assign axis_beats_total    = axis_dw_len[`DW_LEN_WIDTH-1:3] + (|axis_dw_len[2:0]);

always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        dealign_beats_left <= `TD 0;
        is_aligned_last    <= `TD 0;
    end
    else if (is_idle & axis_rd_rsp_tvalid & axis_rd_rsp_tready) begin
        dealign_beats_left <= `TD dealign_beats_total - 1;
        is_aligned_last    <= `TD axis_beats_total > dealign_beats_total; // (first_empty > 0) & (first_empty + byte_len[4:0] > 0) & (first_empty + byte_len[4:0] <= 3);
    end
    else if (is_rsp_beat & axis_rd_rsp_tvalid & axis_rd_rsp_tready) begin
        dealign_beats_left <= `TD dealign_beats_left - 1;
    end
    else if (is_last_beat & axis_rd_rsp_tvalid & axis_rd_rsp_tready & !is_aligned_last) begin
        dealign_beats_left <= `TD dealign_beats_total - 1;
        is_aligned_last    <= `TD axis_beats_total > dealign_beats_total;
    end
    else if (is_last_beat & axis_rd_rsp_tvalid & axis_rd_rsp_tready & is_aligned_last) begin
        dealign_beats_left <= `TD 0;
        is_aligned_last    <= `TD 0;
    end
end

/* AXI-Stream read response tuser
 * | Reserved |  REQ CPL | first_empty |   Tag  | address | Reserved | DW length | byte length |
 * | 127:107  |   106    |   105:104   | 103:96 |  95:32  |  31:24   |   23:13   |    12:0     |
 */
assign axis_rd_rsp_thead = {22'd0, axis_rd_rsp_tuser[104], first_empty, axis_rd_rsp_tuser[103:96], addr_unalign, 8'd0, axis_dw_len, byte_len};
/* -------Head Generation{end}------- */

/* -------out_reg logic{begin}------- */
assign rd_rsp_dealign_valid = (is_rsp_beat  & axis_rd_rsp_tvalid & in_reg_tvalid) | 
                              (is_last_beat & !is_aligned_last   & in_reg_tvalid) | 
                              (is_last_beat &  is_aligned_last   & axis_rd_rsp_tvalid & in_reg_tvalid);
assign rd_rsp_dealign_head  = rd_rsp_dealign_valid ? {32'd0, in_reg_tuser[95:32], {32-`DMA_LEN_WIDTH{1'd0}}, in_reg_tuser[12:0]} : 0;
assign rd_rsp_dealign_dlen  = dw_len;
assign rd_rsp_dealign_tag   = tag;
assign rd_rsp_dealign_data  = in_out_data;
assign rd_rsp_dealign_last  = rd_rsp_dealign_valid & is_last_beat;
assign rd_rsp_dealign_eop   = rd_rsp_dealign_last & is_eop;

// Refers to axis_rd_rsp_thead
assign is_eop    = in_reg_tuser[106];
assign dw_len    = in_reg_tuser[23:13];
assign tag       = in_reg_tuser[103:96];


always @(*) begin
    if (is_last_beat & !is_aligned_last) begin
        in_out_data = (in_reg_tdata >> {in_reg_tuser[105:104], 3'd0});
    end
    else if (is_rsp_beat | (is_last_beat & is_aligned_last)) begin
        case (in_reg_tuser[105:104])
        2'd0: in_out_data = in_reg_tdata; // pkt_aligned
        2'd1: in_out_data = {axis_rd_rsp_tdata[8 * 1 - 1 : 0], in_reg_tdata[`DMA_DATA_W-1 : 8 * 1]};
        2'd2: in_out_data = {axis_rd_rsp_tdata[8 * 2 - 1 : 0], in_reg_tdata[`DMA_DATA_W-1 : 8 * 2]};
        2'd3: in_out_data = {axis_rd_rsp_tdata[8 * 3 - 1 : 0], in_reg_tdata[`DMA_DATA_W-1 : 8 * 3]};
        endcase
    end
    else begin
        in_out_data = 0;
    end
end
/* -------out_reg logic{end}------- */


endmodule