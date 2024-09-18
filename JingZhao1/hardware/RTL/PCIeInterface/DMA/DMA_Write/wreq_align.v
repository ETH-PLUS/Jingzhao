`timescale 1ns / 100ps
//*************************************************************************
// > File Name : wreq_align.v
// > Author    : Kangning
// > Date      : 2021-09-16
// > Note      : transform pkt to dw aligned
// > ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
// > ^                                                               ^
// > ^        ##########       ###########                           ^
// > ^        #        #------># tmp_reg #      ############         ^
// > ^ ------># in_reg #       ###########----->#          #         ^
// > ^        #        #                        # out_wire #---->    ^
// > ^        ##########----------------------->#          #         ^
// > ^                                          ############         ^
// > ^                                                               ^
// > ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
//*************************************************************************


module wreq_align #(
    
) (
    input wire clk   , // i, 1
    input wire rst_n , // i, 1
    
    /* -------dma write request interface{begin}------- */
    /* *_head of DMA interface (interact with RDMA modules), 
     * valid only in first beat of a packet.
     * When Transmiting msi-x interrupt message, 'Byte length' 
     * should be 0, 'address' means the address of msi-x, and
     * msi-x data locates in *_data[31:0].
     * | Resvd | Req Type |   address    | Reserved | Byte length |
     * |       | (wr,int) | (msi-x addr) |          | (0 for int) |
     * |-------|----------|--------------|----------|-------------|
     * |127:100|  99:96   |    95:32     |  31:13   |    12:0     |
     */
    input  wire                   dma_valid , // i, 1
    input  wire                   dma_last  , // i, 1
    input  wire [`DMA_HEAD_W-1:0] dma_head  , // i, `DMA_HEAD_W
    input  wire [`DMA_DATA_W-1:0] dma_data  , // i, `DMA_DATA_W
    output wire                   dma_ready , // o, 1
    /* -------dma write request interface{end}------- */

    /* -------aligned write request intrface{begin}------- */
    /* AXI-Stream write request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     * or
     * AXI-Stream interrupt request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |  Resv  | address | Reserved |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:0    |
     */
    output  wire                     align_valid, // o, 1
    output  wire                     align_last , // o, 1
    output  wire [`AXIS_TUSER_W-1:0] align_user , // o, `AXIS_TUSER_W
    output  wire [`DMA_DATA_W  -1:0] align_data , // o, `DMA_DATA_W
    input   wire                     align_ready  // i, 1
    /* -------aligned write request intrface{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,output wire [`WREQ_ALIGN_SIGNAL_W-1:0] dbg_signal // o, `WREQ_ALIGN_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

/* -------relate to in_reg{begin}------- */
reg                    in_reg_vld ;  // read valid from input register
reg  [`DMA_HEAD_W-1:0] in_reg_head;
reg  [`DMA_DATA_W-1:0] in_reg_data;
wire                   in_reg_rdy ;

reg                       in_reg_sop ; // Indicate the start of a pkt
/* -------relate to in_reg{end}------- */

/* -------DW Dealignment FSM{begin}------- */
localparam FIRST_BEAT = 3'b001, // This state emits first beat (or only bits) of packet.
           MID_BEAT   = 3'b010, // This state emits middle beat of packet.
           LAST_BEAT  = 3'b100; // This state emits last beat of packet, in this state, 
                                // in_reg_rdy is not asserted if all data comes from tmp_reg.

reg [2:0] cur_state;
reg [2:0] nxt_state;

wire is_first_beat, is_mid_beat, is_last_beat;

/* Fake last beat for align_* signal. If 
 * not aligned, this beat should have been 
 * the last beat. But actually, it's not.
 * Note that this signal is different 
 * from 'in_reg_last'
 */
wire fake_align_last;

/*
 * indicate that next beat is the last beat.
 * only valid in 'FIRST_BEAT' and 'MID_BEAT' 
 * state. */
wire next_align_last;

/* Indicate that data in last beat is all from tmp_reg.
 * This wire is valid in the whole req. */
wire is_all_from_tmp;

/* dw size for last beat. This wire is valid in 
 * the whole req. */
wire [$clog2(`DMA_KEEP_W)-1:0] dw_for_last_beat;

/* Packet trans finished, and req_clear all relevant 
 * regs. */
wire req_clear;

/* align_* signal goes out one beat */
wire req_go_out;
/* -------DW Dealignment FSM{end}------- */

/* -------Head gennerator{begin}------- */
wire [3:0] req_type;
wire [`DMA_ADDR_WIDTH-1:0] addr    ;
wire [`DMA_LEN_WIDTH -1:0] byte_len;
wire [`DMA_ADDR_WIDTH-1:0] aligned_addr    ;
wire [`DMA_LEN_WIDTH -1:0] aligned_byte_len;
wire [`DW_LEN_WIDTH  -1:0] dw_len  ;
wire [`FIRST_BE_WIDTH-1:0] first_be;
wire [`LAST_BE_WIDTH -1:0] last_be ;
wire [2:0] last_bytes;
wire [`AXIS_TUSER_W-1:0] wreq_user;
wire [`AXIS_TUSER_W-1:0] int_user ;

reg  [`DW_LEN_WIDTH-1:0] dw_cnt ;
wire [`DW_LEN_WIDTH-1:0] dw_left;
/* -------Head generator{end}------- */

/* -------tmp_reg logic{begin}------- */
reg  [31:0] tmp_reg_data;
/* -------tmp_reg logic{end}------- */

/* -------relate to out_reg{begin}------- */
reg  [`DMA_DATA_W-1:0] in_out_data; // transform data between tmp_reg and out_reg
/* -------relate to tmp_reg{end}------- */

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign dbg_signal = { // 1150
    in_reg_vld, in_reg_head, in_reg_data, in_reg_rdy, // 386
    in_reg_sop, // 1
    cur_state, nxt_state, // 6
    is_first_beat, is_mid_beat, is_last_beat, // 3
    fake_align_last, // 1
    next_align_last, // 1
    is_all_from_tmp, // 1
    dw_for_last_beat, // 3
    req_clear,  // 1
    req_go_out, // 1

    req_type, addr, byte_len, aligned_addr, aligned_byte_len, 
    dw_len, first_be, last_be, last_bytes, wreq_user, int_user, // 436
    
    dw_cnt, dw_left, // 22
    tmp_reg_data, // 32
    in_out_data // 256
};
/* -------APB reated signal{end}------- */
`endif

/* -------in_reg logic{begin}------- */
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        in_reg_sop  <= `TD 1;
    end
    else if (dma_valid & dma_ready & dma_last) begin
        in_reg_sop  <= `TD 1;
    end
    else if (dma_valid & dma_ready & in_reg_sop) begin
        in_reg_sop  <= `TD 0;
    end
end

always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        in_reg_head <= `TD 0;
    end
    else if (dma_valid & dma_ready & in_reg_sop) begin
        in_reg_head <= `TD dma_head;
    end
    else if (req_clear) begin // after trans finished, in_reg_head is set to 0
        in_reg_head <= `TD 0;
    end
end

always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        in_reg_vld  <= `TD 0;
        in_reg_data <= `TD 0;
    end
    else if (dma_valid & dma_ready) begin // write en & not full
        in_reg_vld  <= `TD 1;
        in_reg_data <= `TD dma_data;
    end
    else if (in_reg_rdy & in_reg_vld) begin // read en & not empty
        in_reg_vld  <= `TD 0;
        in_reg_data <= `TD 0;
    end
end

assign dma_ready  = !in_reg_vld | in_reg_rdy; // empty | going to empty
/* -------in_reg logic{end}------- */

/* -------Head generator{begin}------ */
assign req_type           = in_reg_head[99:96];
assign addr               = in_reg_head[95:32];
assign byte_len           = in_reg_head[12:0];
assign aligned_addr       = {addr[`DMA_ADDR_WIDTH-1:2], 2'd0};
assign aligned_byte_len   = byte_len + addr[1:0];
assign dw_len             = (aligned_byte_len >> 2) + | aligned_byte_len[1:0];

// In our implementation, uncontinuous first_be and last_be are forbidden.
// In our implementation, zero-payload are not allowed, first_be would never be 4'b0000.
assign first_be = ({4{addr[1:0] == 2'b00}} & 4'b1111) |
                  ({4{addr[1:0] == 2'b01}} & 4'b1110) |
                  ({4{addr[1:0] == 2'b10}} & 4'b1100) |
                  ({4{addr[1:0] == 2'b11}} & 4'b1000);
assign last_be  = ({4{aligned_byte_len[1:0] == 2'b00}} & 4'b1111) |
                  ({4{aligned_byte_len[1:0] == 2'b01}} & 4'b0001) |
                  ({4{aligned_byte_len[1:0] == 2'b10}} & 4'b0011) |
                  ({4{aligned_byte_len[1:0] == 2'b11}} & 4'b0111);
assign last_bytes = (aligned_byte_len[1:0] == 2'b00) ? 3'b100 : {1'b0, aligned_byte_len[1:0]};
/* AXI-Stream write request tuser, only valid in first beat of a packet
 * | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
 * | 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
 */
assign wreq_user = {20'd0, `DMA_WRITE_REQ, 8'd0, aligned_addr, 13'd0, dw_len, first_be, last_be};

/* AXI-Stream interrupt request tuser, only valid in first beat of a packet
 * | Reserved | REQ_TYPE |  Resv  | address | Reserved |
 * | 127:108  | 107:104  | 103:96 |  95:32  |  31:0    |
 */
assign int_user  = {20'd0, req_type, 8'd0, addr, 32'd0};

assign dw_left = dw_len - dw_cnt;
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        dw_cnt <= `TD 0;
    end
    else if (req_clear) begin
        dw_cnt <= `TD 0;
    end
    else if (req_go_out) begin
        dw_cnt <= `TD dw_cnt + `DMA_KEEP_W;
    end
end
/* -------Head generator{end}------ */

/* -------tmp_reg logic{begin}------- */
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        tmp_reg_data <= `TD 0;
    end
    else if (req_clear) begin // Clear tmp_reg, in case 
                          // next pkt contains invalid data.
        tmp_reg_data <= `TD 0;
    end
    else if (req_go_out) begin // Update tmp_reg when it goes out
        tmp_reg_data <= `TD in_reg_data[(`DMA_DATA_W-1)-:32];
    end
end
/* -------tmp_reg logic{end}------- */

/* -------out_reg logic{begin}------- */
assign in_reg_rdy  = (is_first_beat | is_mid_beat) & align_ready & !fake_align_last |
                     (is_last_beat & align_ready);

assign align_valid = in_reg_vld | 
                     !in_reg_vld & is_last_beat & is_all_from_tmp;
assign align_last  = align_valid & (dw_left <= `DMA_KEEP_W);
assign align_user  = (req_type == `DMA_INT_REQ) ? int_user : wreq_user;
assign align_data  = (req_type == `DMA_INT_REQ) ? in_reg_data : in_out_data;
always @(*) begin
    if (is_last_beat & is_all_from_tmp) begin
        case (addr[1:0])
        2'd0: in_out_data = in_reg_data;
        2'd1: in_out_data = {{`DMA_DATA_W - 8 * 1{1'd0}}, tmp_reg_data[(32 - 1)-:(8 * 1)]};
        2'd2: in_out_data = {{`DMA_DATA_W - 8 * 2{1'd0}}, tmp_reg_data[(32 - 1)-:(8 * 2)]};
        2'd3: in_out_data = {{`DMA_DATA_W - 8 * 3{1'd0}}, tmp_reg_data[(32 - 1)-:(8 * 3)]};
        endcase
    end
    else if (is_first_beat | is_mid_beat | is_last_beat) begin
        case (addr[1:0])
        2'd0: in_out_data = in_reg_data;
        2'd1: in_out_data = {in_reg_data[`DMA_DATA_W - 8 * 1 - 1: 0], tmp_reg_data[(32 - 1)-:(8 * 1)]};
        2'd2: in_out_data = {in_reg_data[`DMA_DATA_W - 8 * 2 - 1: 0], tmp_reg_data[(32 - 1)-:(8 * 2)]};
        2'd3: in_out_data = {in_reg_data[`DMA_DATA_W - 8 * 3 - 1: 0], tmp_reg_data[(32 - 1)-:(8 * 3)]};
        endcase
    end
    else begin
        in_out_data = 0;
    end
end
/* -------out_reg logic{end}------- */

/* -------DW Dealignment FSM{begin}------- */
/******************** Stage 1: State Register **********************/
assign fake_align_last  = is_all_from_tmp & next_align_last;
assign next_align_last  = (dw_left <= `DMA_KEEP_W * 2) & (dw_left > `DMA_KEEP_W);
assign is_all_from_tmp  = (dw_for_last_beat == 1) & (last_bytes <= addr[1:0]);
assign dw_for_last_beat = dw_len[$clog2(`DMA_KEEP_W)-1:0];
assign req_clear        = req_go_out & align_last;
assign req_go_out       = align_valid & align_ready;

assign is_first_beat = (cur_state == FIRST_BEAT);
assign is_mid_beat   = (cur_state == MID_BEAT  );
assign is_last_beat  = (cur_state == LAST_BEAT );

always @(posedge clk, negedge rst_n) begin
    if(~rst_n)
        cur_state <= `TD FIRST_BEAT;
    else
        cur_state <= `TD nxt_state;
end

/******************** Stage 2: State Transition **********************/

always @(*) begin
    case(cur_state)
        FIRST_BEAT: begin
            if (req_clear) // Imlying the only beat
                nxt_state = FIRST_BEAT;
            else if (req_go_out & next_align_last)
                nxt_state = LAST_BEAT;
            else if (req_go_out)
                nxt_state = MID_BEAT;
            else
                nxt_state = FIRST_BEAT;
        end
        MID_BEAT: begin
            if (req_go_out & next_align_last)
                nxt_state = LAST_BEAT;
            else
                nxt_state = MID_BEAT;
        end
        LAST_BEAT: begin
            if (req_clear)
                nxt_state = FIRST_BEAT;
            else
                nxt_state = LAST_BEAT;
        end
        default: begin
            nxt_state = FIRST_BEAT;
        end
    endcase
end
/******************** Stage 3: Output **********************/
/* -------DW Dealignment FSM{end}------- */

endmodule