`timescale 1ns / 100ps
//*************************************************************************
// > File   : dma_demux.v
// > Author : Kangning
// > Date   : 2022-06-29
// > Note   : demux module for pio, used for read & write request.
// >          V1.1 2022-06-08: Now, It only support 2 or 3 output channels.
// >          V1.2 2022-06-29: Suppports up to 16 channels
//*************************************************************************

module dma_demux #(
    parameter CHANNEL_NUM  = 2    // number of channels for output
) (
    input wire clk  , // i, 1
    input wire rst_n, // i, 1

    input  wire             nxt_demux_vld, // i, 1
    input  wire [7:0]       nxt_demux_sel, // i, 8

    /* --------PIO Write Request interface{begin}-------- */
    /* head
     * | 130:128 | 127:96 |   95:0  |
     * | bar_id  |  addr  | cc_head |
     */
    input  wire                   s_axis_req_valid, // i, 1
    input  wire                   s_axis_req_last , // i, 1
    input  wire [`DMA_HEAD_W-1:0] s_axis_req_head , // i, `DMA_HEAD_W
    input  wire [`DMA_DATA_W-1:0] s_axis_req_data , // i, `DMA_DATA_W
    output wire                   s_axis_req_ready, // o, 1

    output wire [CHANNEL_NUM * 1          -1:0] m_axis_req_valid, // o, CHANNEL_NUM * 1
    output wire [CHANNEL_NUM * 1          -1:0] m_axis_req_last , // o, CHANNEL_NUM * 1
    output wire [CHANNEL_NUM * `DMA_HEAD_W-1:0] m_axis_req_head , // o, CHANNEL_NUM * `DMA_HEAD_W
    output wire [CHANNEL_NUM * `DMA_DATA_W-1:0] m_axis_req_data , // o, CHANNEL_NUM * `DMA_DATA_W
    input  wire [CHANNEL_NUM * 1          -1:0] m_axis_req_ready  // i, CHANNEL_NUM * 1
    /* --------PIO Write Request interface{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,output wire [`DMA_DEMUX_SIGNAL_W-1:0] dbg_signal  // o, `DMA_DEMUX_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

reg [7:0] sel;

/* -------State relevant in FSM{begin}------- */
localparam      IDLE  = 2'b01,
                TRANS = 2'b10;

reg [1:0] cur_state;
reg [1:0] nxt_state;

wire is_idle, is_trans;
/* -------State relevant in FSM{end}------- */

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign dbg_signal = { // 14
    sel, // 8
    cur_state, nxt_state, // 4
    is_idle, is_trans // 2
};
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
        sel <= `TD 8'd0;
    end
    else if ((is_idle  & nxt_demux_vld) || 
             (is_trans & s_axis_req_last & s_axis_req_valid & s_axis_req_ready & nxt_demux_vld)) begin
        sel <= `TD nxt_demux_sel;
    end
end

/* -------Generate block{begin}------- */
/* This is used for different Channel Numbers, the default Number is 4
 */
generate
if (CHANNEL_NUM == 16) begin:CHNL_DEMUX_16

assign s_axis_req_ready =   ((sel == 0) & is_trans & m_axis_req_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_req_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_req_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_req_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_req_ready[4]) |
                            ((sel == 5) & is_trans & m_axis_req_ready[5]) |
                            ((sel == 6) & is_trans & m_axis_req_ready[6]) |
                            ((sel == 7) & is_trans & m_axis_req_ready[7]) |
                            ((sel == 8) & is_trans & m_axis_req_ready[8]) |
                            ((sel == 9) & is_trans & m_axis_req_ready[9]) |
                            ((sel == 10) & is_trans & m_axis_req_ready[10])|
                            ((sel == 11) & is_trans & m_axis_req_ready[11])|
                            ((sel == 12) & is_trans & m_axis_req_ready[12])|
                            ((sel == 13) & is_trans & m_axis_req_ready[13])|
                            ((sel == 14) & is_trans & m_axis_req_ready[14])|
                            ((sel == 15) & is_trans & m_axis_req_ready[15]);

end // CHNL_DEMUX_16
else if (CHANNEL_NUM == 15) begin:CHNL_DEMUX_15

assign s_axis_req_ready =   ((sel == 0) & is_trans & m_axis_req_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_req_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_req_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_req_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_req_ready[4]) |
                            ((sel == 5) & is_trans & m_axis_req_ready[5]) |
                            ((sel == 6) & is_trans & m_axis_req_ready[6]) |
                            ((sel == 7) & is_trans & m_axis_req_ready[7]) |
                            ((sel == 8) & is_trans & m_axis_req_ready[8]) |
                            ((sel == 9) & is_trans & m_axis_req_ready[9]) |
                            ((sel == 10) & is_trans & m_axis_req_ready[10])|
                            ((sel == 11) & is_trans & m_axis_req_ready[11])|
                            ((sel == 12) & is_trans & m_axis_req_ready[12])|
                            ((sel == 13) & is_trans & m_axis_req_ready[13])|
                            ((sel == 14) & is_trans & m_axis_req_ready[14]);

end // CHNL_DEMUX_15
else if (CHANNEL_NUM == 14) begin:CHNL_DEMUX_14

assign s_axis_req_ready =   ((sel == 0) & is_trans & m_axis_req_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_req_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_req_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_req_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_req_ready[4]) |
                            ((sel == 5) & is_trans & m_axis_req_ready[5]) |
                            ((sel == 6) & is_trans & m_axis_req_ready[6]) |
                            ((sel == 7) & is_trans & m_axis_req_ready[7]) |
                            ((sel == 8) & is_trans & m_axis_req_ready[8]) |
                            ((sel == 9) & is_trans & m_axis_req_ready[9]) |
                            ((sel == 10) & is_trans & m_axis_req_ready[10])|
                            ((sel == 11) & is_trans & m_axis_req_ready[11])|
                            ((sel == 12) & is_trans & m_axis_req_ready[12])|
                            ((sel == 13) & is_trans & m_axis_req_ready[13]);

end // CHNL_DEMUX_14
else if (CHANNEL_NUM == 13) begin:CHNL_DEMUX_13

assign s_axis_req_ready =   ((sel == 0) & is_trans & m_axis_req_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_req_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_req_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_req_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_req_ready[4]) |
                            ((sel == 5) & is_trans & m_axis_req_ready[5]) |
                            ((sel == 6) & is_trans & m_axis_req_ready[6]) |
                            ((sel == 7) & is_trans & m_axis_req_ready[7]) |
                            ((sel == 8) & is_trans & m_axis_req_ready[8]) |
                            ((sel == 9) & is_trans & m_axis_req_ready[9]) |
                            ((sel == 10) & is_trans & m_axis_req_ready[10])|
                            ((sel == 11) & is_trans & m_axis_req_ready[11])|
                            ((sel == 12) & is_trans & m_axis_req_ready[12]);

end // CHNL_DEMUX_13
else if (CHANNEL_NUM == 12) begin:CHNL_DEMUX_12

assign s_axis_req_ready =   ((sel == 0) & is_trans & m_axis_req_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_req_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_req_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_req_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_req_ready[4]) |
                            ((sel == 5) & is_trans & m_axis_req_ready[5]) |
                            ((sel == 6) & is_trans & m_axis_req_ready[6]) |
                            ((sel == 7) & is_trans & m_axis_req_ready[7]) |
                            ((sel == 8) & is_trans & m_axis_req_ready[8]) |
                            ((sel == 9) & is_trans & m_axis_req_ready[9]) |
                            ((sel == 10) & is_trans & m_axis_req_ready[10])|
                            ((sel == 11) & is_trans & m_axis_req_ready[11]);

end // CHNL_DEMUX_12
else if (CHANNEL_NUM == 11) begin:CHNL_DEMUX_11

assign s_axis_req_ready =   ((sel == 0) & is_trans & m_axis_req_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_req_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_req_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_req_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_req_ready[4]) |
                            ((sel == 5) & is_trans & m_axis_req_ready[5]) |
                            ((sel == 6) & is_trans & m_axis_req_ready[6]) |
                            ((sel == 7) & is_trans & m_axis_req_ready[7]) |
                            ((sel == 8) & is_trans & m_axis_req_ready[8]) |
                            ((sel == 9) & is_trans & m_axis_req_ready[9]) |
                            ((sel == 10) & is_trans & m_axis_req_ready[10]);

end // CHNL_DEMUX_11
else if (CHANNEL_NUM == 10) begin:CHNL_DEMUX_10

assign s_axis_req_ready =   ((sel == 0) & is_trans & m_axis_req_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_req_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_req_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_req_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_req_ready[4]) |
                            ((sel == 5) & is_trans & m_axis_req_ready[5]) |
                            ((sel == 6) & is_trans & m_axis_req_ready[6]) |
                            ((sel == 7) & is_trans & m_axis_req_ready[7]) |
                            ((sel == 8) & is_trans & m_axis_req_ready[8]) |
                            ((sel == 9) & is_trans & m_axis_req_ready[9]);

end // CHNL_DEMUX_10
else if (CHANNEL_NUM == 9) begin:CHNL_DEMUX_9

assign s_axis_req_ready =   ((sel == 0) & is_trans & m_axis_req_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_req_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_req_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_req_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_req_ready[4]) |
                            ((sel == 5) & is_trans & m_axis_req_ready[5]) |
                            ((sel == 6) & is_trans & m_axis_req_ready[6]) |
                            ((sel == 7) & is_trans & m_axis_req_ready[7]) |
                            ((sel == 8) & is_trans & m_axis_req_ready[8]);

end // CHNL_DEMUX_9
else if (CHANNEL_NUM == 8) begin:CHNL_DEMUX_8

assign s_axis_req_ready =   ((sel == 0) & is_trans & m_axis_req_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_req_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_req_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_req_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_req_ready[4]) |
                            ((sel == 5) & is_trans & m_axis_req_ready[5]) |
                            ((sel == 6) & is_trans & m_axis_req_ready[6]) |
                            ((sel == 7) & is_trans & m_axis_req_ready[7]);

end // CHNL_DEMUX_8
else if (CHANNEL_NUM == 7) begin:CHNL_DEMUX_7

assign s_axis_req_ready =   ((sel == 0) & is_trans & m_axis_req_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_req_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_req_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_req_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_req_ready[4]) |
                            ((sel == 5) & is_trans & m_axis_req_ready[5]) |
                            ((sel == 6) & is_trans & m_axis_req_ready[6]);

end // CHNL_DEMUX_7
else if (CHANNEL_NUM == 6) begin:CHNL_DEMUX_6

assign s_axis_req_ready =   ((sel == 0) & is_trans & m_axis_req_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_req_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_req_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_req_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_req_ready[4]) |
                            ((sel == 5) & is_trans & m_axis_req_ready[5]);

end // CHNL_DEMUX_6
else if (CHANNEL_NUM == 5) begin:CHNL_DEMUX_5

assign s_axis_req_ready =   ((sel == 0) & is_trans & m_axis_req_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_req_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_req_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_req_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_req_ready[4]);

end // CHNL_DEMUX_5
else if (CHANNEL_NUM == 4) begin:CHNL_DEMUX_4

assign s_axis_req_ready =   ((sel == 0) & is_trans & m_axis_req_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_req_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_req_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_req_ready[3]);

end // CHNL_DEMUX_4
else if (CHANNEL_NUM == 3) begin:CHNL_DEMUX_3

assign s_axis_req_ready =   ((sel == 0) & is_trans & m_axis_req_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_req_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_req_ready[2]);

end // CHNL_DEMUX_3
else if (CHANNEL_NUM == 2) begin:CHNL_DEMUX_2

assign s_axis_req_ready =   ((sel == 0) & is_trans & m_axis_req_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_req_ready[1]);

end // CHNL_DEMUX_2
endgenerate
/* 
 This is used for different Channel Numbers, the default Number is 4 */
/* -------Generate block{end}------- */

/******************** Stage 2: State Transition **********************/

always @(*) begin
	case(cur_state)
        IDLE: begin
            if (nxt_demux_vld) begin
                nxt_state = TRANS;
            end
            else begin
                nxt_state = IDLE;
            end
        end
		TRANS: begin
			if (s_axis_req_last & s_axis_req_valid & s_axis_req_ready & nxt_demux_vld) begin
				nxt_state = TRANS;
			end
            else if (s_axis_req_last & s_axis_req_valid & s_axis_req_ready) begin
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
for (i = 0; i < CHANNEL_NUM; i = i + 1) begin:CHNL_DEMUX_ASSIGN

assign m_axis_req_valid[(i+1)*1           -1:i*1          ] = ((i == sel) & is_trans) ? s_axis_req_valid : 0;
assign m_axis_req_last [(i+1)*1           -1:i*1          ] = ((i == sel) & is_trans) ? s_axis_req_last  : 0;
assign m_axis_req_data [(i+1)*`DMA_DATA_W -1:i*`DMA_DATA_W] = ((i == sel) & is_trans) ? s_axis_req_data  : 0;
assign m_axis_req_head [(i+1)*`DMA_HEAD_W -1:i*`DMA_HEAD_W] = ((i == sel) & is_trans) ? s_axis_req_head  : 0;

end
endgenerate
/* 
 This is used for different Channel Numbers, the default Number is 4 */
/* -------Generate block{end}------- */


/* -------{Read Response Distributor FSM}end------- */

endmodule