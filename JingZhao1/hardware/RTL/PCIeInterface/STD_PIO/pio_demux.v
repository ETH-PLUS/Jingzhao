`timescale 1ns / 100ps
//*************************************************************************
// > File   : pio_demux.v
// > Author : Kangning
// > Date   : 2022-03-12
// > Note   : demux module for pio, used for read & write request.
// >          V1.1 2022-06-08: Now, It only support 4 output channels.
// >          V1.2 2022-08-11: Now, it supports 8 output channels.
//*************************************************************************

module pio_demux #(
    parameter OUT_CHNL_NUM  = 2    // number of channels for output
) (
    input wire clk  , // i, 1
    input wire rst_n, // i, 1

    input  wire [2:0]       demux_sel, // i, 3

    /* --------PIO Write Request interface{begin}-------- */
    /* head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    input  wire [`PIO_DATA_W-1:0] s_axis_req_data , // i, `PIO_DATA_W
    input  wire [`PIO_HEAD_W-1:0] s_axis_req_head , // i, `PIO_HEAD_W
    input  wire                   s_axis_req_last , // i, 1
    input  wire                   s_axis_req_valid, // i, 1
    output wire                   s_axis_req_ready, // o, 1

    /* head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    output wire [OUT_CHNL_NUM * `PIO_DATA_W-1:0] m_axis_req_data , // o, OUT_CHNL_NUM * `PIO_DATA_W
    output wire [OUT_CHNL_NUM * `PIO_HEAD_W-1:0] m_axis_req_head , // o, OUT_CHNL_NUM * `PIO_HEAD_W
    output wire [OUT_CHNL_NUM * 1          -1:0] m_axis_req_last , // o, OUT_CHNL_NUM * 1
    output wire [OUT_CHNL_NUM * 1          -1:0] m_axis_req_valid, // o, OUT_CHNL_NUM * 1
    input  wire [OUT_CHNL_NUM * 1          -1:0] m_axis_req_ready  // i, OUT_CHNL_NUM * 1
    /* --------PIO Write Request interface{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,output wire [`PIO_DEMUX_SIGNAL_W-1:0] dbg_signal // o, debug bus select    
    /* -------APB reated signal{end}------- */
`endif
);

reg [2:0] sel;

/* -------State relevant in FSM{begin}------- */
localparam      IDLE  = 2'b01,
                TRANS = 2'b10;

reg [1:0] cur_state;
reg [1:0] nxt_state;

wire is_idle, is_trans;
/* -------State relevant in FSM{end}------- */

//----------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign dbg_signal = {sel, cur_state, nxt_state, is_idle, is_trans}; // 9
/* -------APB reated signal{end}------- */
`endif

/* -------{Read Response Distributor FSM}begin------- */
/******************** Stage 1: State Register **********************/

assign is_idle  = (cur_state == IDLE );
assign is_trans = (cur_state == TRANS);

always @(posedge clk, negedge rst_n) begin
    if(~rst_n)
        cur_state <= `TD IDLE;
    else
        cur_state <= `TD nxt_state;
end

always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        sel <= `TD 3'd0;
    end
    else if (is_idle & s_axis_req_valid) begin
        sel <= `TD demux_sel;
    end
end



generate
    if (OUT_CHNL_NUM == 2) begin:CHNL_NUM2

        assign s_axis_req_ready = ((sel == 0) & is_trans & m_axis_req_ready[0]) |
                                  ((sel == 1) & is_trans & m_axis_req_ready[1]);
    
    end
    else if (OUT_CHNL_NUM == 3) begin:CHNL_NUM3
        
        assign s_axis_req_ready = ((sel == 0) & is_trans & m_axis_req_ready[0]) |
                                  ((sel == 1) & is_trans & m_axis_req_ready[1]) |
                                  ((sel == 2) & is_trans & m_axis_req_ready[2]);

    end
    else if (OUT_CHNL_NUM == 4) begin:CHNL_NUM4
        
        assign s_axis_req_ready = ((sel == 0) & is_trans & m_axis_req_ready[0]) |
                                  ((sel == 1) & is_trans & m_axis_req_ready[1]) |
                                  ((sel == 2) & is_trans & m_axis_req_ready[2]) |
                                  ((sel == 3) & is_trans & m_axis_req_ready[3]);

    end
    else if (OUT_CHNL_NUM == 5) begin:CHNL_NUM5
        
        assign s_axis_req_ready = ((sel == 0) & is_trans & m_axis_req_ready[0]) |
                                  ((sel == 1) & is_trans & m_axis_req_ready[1]) |
                                  ((sel == 2) & is_trans & m_axis_req_ready[2]) |
                                  ((sel == 3) & is_trans & m_axis_req_ready[3]) |
                                  ((sel == 4) & is_trans & m_axis_req_ready[4]);

    end
    else if (OUT_CHNL_NUM == 6) begin:CHNL_NUM6
        
        assign s_axis_req_ready = ((sel == 0) & is_trans & m_axis_req_ready[0]) |
                                  ((sel == 1) & is_trans & m_axis_req_ready[1]) |
                                  ((sel == 2) & is_trans & m_axis_req_ready[2]) |
                                  ((sel == 3) & is_trans & m_axis_req_ready[3]) |
                                  ((sel == 4) & is_trans & m_axis_req_ready[4]) |
                                  ((sel == 5) & is_trans & m_axis_req_ready[5]);

    end
    else if (OUT_CHNL_NUM == 7) begin:CHNL_NUM7
        
        assign s_axis_req_ready = ((sel == 0) & is_trans & m_axis_req_ready[0]) |
                                  ((sel == 1) & is_trans & m_axis_req_ready[1]) |
                                  ((sel == 2) & is_trans & m_axis_req_ready[2]) |
                                  ((sel == 3) & is_trans & m_axis_req_ready[3]) |
                                  ((sel == 4) & is_trans & m_axis_req_ready[4]) |
                                  ((sel == 5) & is_trans & m_axis_req_ready[5]) |
                                  ((sel == 6) & is_trans & m_axis_req_ready[6]);

    end
    else if (OUT_CHNL_NUM == 8) begin:CHNL_NUM8
        
        assign s_axis_req_ready = ((sel == 0) & is_trans & m_axis_req_ready[0]) |
                                  ((sel == 1) & is_trans & m_axis_req_ready[1]) |
                                  ((sel == 2) & is_trans & m_axis_req_ready[2]) |
                                  ((sel == 3) & is_trans & m_axis_req_ready[3]) |
                                  ((sel == 4) & is_trans & m_axis_req_ready[4]) |
                                  ((sel == 5) & is_trans & m_axis_req_ready[5]) |
                                  ((sel == 6) & is_trans & m_axis_req_ready[6]) |
                                  ((sel == 7) & is_trans & m_axis_req_ready[7]);

    end
endgenerate

/******************** Stage 2: State Transition **********************/

always @(*) begin
    case(cur_state)
        IDLE: begin
            if (s_axis_req_valid) begin
                nxt_state = TRANS;
            end
            else begin
                nxt_state = IDLE;
            end
        end
        TRANS: begin
            if (s_axis_req_last & s_axis_req_valid & s_axis_req_ready) begin
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

/* -------Generate block{begin}------- */
/* This is used for different Channel Numbers, the default Number is 4
 */
genvar i;
generate
for (i = 0; i < OUT_CHNL_NUM; i = i + 1) begin:CHNL_DEMUX_ASSIGN

assign m_axis_req_valid[(i+1)*1          -1:i*1          ] = ((i == sel) & is_trans) ? s_axis_req_valid : 0;
assign m_axis_req_last [(i+1)*1          -1:i*1          ] = ((i == sel) & is_trans) ? s_axis_req_last  : 0;
assign m_axis_req_data [(i+1)*`PIO_DATA_W-1:i*`PIO_DATA_W] = ((i == sel) & is_trans) ? s_axis_req_data  : 0;
assign m_axis_req_head [(i+1)*`PIO_HEAD_W-1:i*`PIO_HEAD_W] = ((i == sel) & is_trans) ? s_axis_req_head  : 0;

end
endgenerate
/* 
 This is used for different Channel Numbers, the default Number is 4 */
/* -------Generate block{end}------- */


/* -------{Read Response Distributor FSM}end------- */

endmodule