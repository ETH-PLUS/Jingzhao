`timescale 1ns / 100ps
//*************************************************************************
// > File   : st_demux.v
// > Author : Kangning
// > Date   : 2022-12-02
// > Note   : demux one channel into multiply channel.
//*************************************************************************

module st_demux #(
    parameter CHNL_NUM      = 8  ,    // number of slave signals to arbit
    parameter CHNL_NUM_LOG  = 3  ,
    parameter TUSER_WIDTH   = 128,
    parameter TDATA_WIDTH   = 256
) (
    input  wire         clk  , // i, 1
    input  wire         rst_n, // i, 1

    input  wire         nxt_chnl_vld, // i, 1
    input  wire [7 : 0] nxt_chnl_sel, // i, 8

    /* -------Slave AXIS Interface{begin}------- */
    input  wire                       s_axis_demux_valid, // i, 1
    input  wire                       s_axis_demux_last , // i, 1
    input  wire [TDATA_WIDTH - 1 : 0] s_axis_demux_data , // i, TDATA_WIDTH
    input  wire [TUSER_WIDTH - 1 : 0] s_axis_demux_head , // i, TUSER_WIDTH
    output wire                       s_axis_demux_ready, // o, 1
    /* -------Slave AXIS Interface{end}------- */

    /* ------- Master AXIS Interface{begin} ------- */
    output wire [CHNL_NUM * 1           - 1 : 0] m_axis_demux_valid, // o, CHNL_NUM * 1
    output wire [CHNL_NUM * 1           - 1 : 0] m_axis_demux_last , // o, CHNL_NUM * 1
    output wire [CHNL_NUM * TDATA_WIDTH - 1 : 0] m_axis_demux_data , // o, CHNL_NUM * TDATA_WIDTH
    output wire [CHNL_NUM * TUSER_WIDTH - 1 : 0] m_axis_demux_head , // o, CHNL_NUM * TUSER_WIDTH
    input  wire [CHNL_NUM * 1           - 1 : 0] m_axis_demux_ready  // i, CHNL_NUM * 1
    /* ------- Master AXIS Interface{end} ------- */

);

/* -------State relevant in FSM{begin}------- */
localparam      IDLE  = 2'b01,
                TRANS = 2'b10;

reg [1:0] cur_state;
reg [1:0] nxt_state;

wire is_idle, is_trans;
/* -------State relevant in FSM{end}------- */

/* --------Channel selection{begin}-------- */
reg  [CHNL_NUM_LOG-1:0] sel;
/* --------Channel selection{end}-------- */

//-----------------------------------------------------------------------------------------------------------------------------------------------------------------------//

/* --------Channel selection{begin}--------- */
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        sel <= `TD 8'd0;
    end
    else if ((is_idle  & nxt_chnl_vld) || 
             (is_trans & s_axis_demux_last & s_axis_demux_valid & s_axis_demux_ready & nxt_chnl_vld)) begin
        sel <= `TD nxt_chnl_sel;
    end
end

// assign mem_addr = s_axis_demux_head[63:32];
// assign nxt_chnl_sel = s_axis_demux_valid ? (mem_addr[13:12] == 2'b11) : 0;
/* --------Channel selection{end}--------- */

/* -------{DEMUX FSM}begin------- */
/******************** Stage 1: State Register **********************/
assign is_idle  = (cur_state == IDLE );
assign is_trans = (cur_state == TRANS);

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
            if (nxt_chnl_vld) begin
                nxt_state = TRANS;
            end
            else begin
                nxt_state = IDLE;
            end
        end
		TRANS: begin
			if (s_axis_demux_last & s_axis_demux_valid & s_axis_demux_ready & nxt_chnl_vld) begin
				nxt_state = TRANS;
			end
            else if (s_axis_demux_last & s_axis_demux_valid & s_axis_demux_ready) begin
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
generate
if (CHNL_NUM == 16) begin:CHNL_DEMUX_16

assign s_axis_demux_ready = ((sel == 0) & is_trans & m_axis_demux_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_demux_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_demux_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_demux_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_demux_ready[4]) |
                            ((sel == 5) & is_trans & m_axis_demux_ready[5]) |
                            ((sel == 6) & is_trans & m_axis_demux_ready[6]) |
                            ((sel == 7) & is_trans & m_axis_demux_ready[7]) |
                            ((sel == 8) & is_trans & m_axis_demux_ready[8]) |
                            ((sel == 9) & is_trans & m_axis_demux_ready[9]) |
                            ((sel == 10) & is_trans & m_axis_demux_ready[10])|
                            ((sel == 11) & is_trans & m_axis_demux_ready[11])|
                            ((sel == 12) & is_trans & m_axis_demux_ready[12])|
                            ((sel == 13) & is_trans & m_axis_demux_ready[13])|
                            ((sel == 14) & is_trans & m_axis_demux_ready[14])|
                            ((sel == 15) & is_trans & m_axis_demux_ready[15]);

end // CHNL_DEMUX_16
else if (CHNL_NUM == 15) begin:CHNL_DEMUX_15

assign s_axis_demux_ready = ((sel == 0) & is_trans & m_axis_demux_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_demux_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_demux_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_demux_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_demux_ready[4]) |
                            ((sel == 5) & is_trans & m_axis_demux_ready[5]) |
                            ((sel == 6) & is_trans & m_axis_demux_ready[6]) |
                            ((sel == 7) & is_trans & m_axis_demux_ready[7]) |
                            ((sel == 8) & is_trans & m_axis_demux_ready[8]) |
                            ((sel == 9) & is_trans & m_axis_demux_ready[9]) |
                            ((sel == 10) & is_trans & m_axis_demux_ready[10])|
                            ((sel == 11) & is_trans & m_axis_demux_ready[11])|
                            ((sel == 12) & is_trans & m_axis_demux_ready[12])|
                            ((sel == 13) & is_trans & m_axis_demux_ready[13])|
                            ((sel == 14) & is_trans & m_axis_demux_ready[14]);

end // CHNL_DEMUX_15
else if (CHNL_NUM == 14) begin:CHNL_DEMUX_14

assign s_axis_demux_ready = ((sel == 0) & is_trans & m_axis_demux_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_demux_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_demux_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_demux_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_demux_ready[4]) |
                            ((sel == 5) & is_trans & m_axis_demux_ready[5]) |
                            ((sel == 6) & is_trans & m_axis_demux_ready[6]) |
                            ((sel == 7) & is_trans & m_axis_demux_ready[7]) |
                            ((sel == 8) & is_trans & m_axis_demux_ready[8]) |
                            ((sel == 9) & is_trans & m_axis_demux_ready[9]) |
                            ((sel == 10) & is_trans & m_axis_demux_ready[10])|
                            ((sel == 11) & is_trans & m_axis_demux_ready[11])|
                            ((sel == 12) & is_trans & m_axis_demux_ready[12])|
                            ((sel == 13) & is_trans & m_axis_demux_ready[13]);

end // CHNL_DEMUX_14
else if (CHNL_NUM == 13) begin:CHNL_DEMUX_13

assign s_axis_demux_ready = ((sel == 0) & is_trans & m_axis_demux_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_demux_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_demux_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_demux_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_demux_ready[4]) |
                            ((sel == 5) & is_trans & m_axis_demux_ready[5]) |
                            ((sel == 6) & is_trans & m_axis_demux_ready[6]) |
                            ((sel == 7) & is_trans & m_axis_demux_ready[7]) |
                            ((sel == 8) & is_trans & m_axis_demux_ready[8]) |
                            ((sel == 9) & is_trans & m_axis_demux_ready[9]) |
                            ((sel == 10) & is_trans & m_axis_demux_ready[10])|
                            ((sel == 11) & is_trans & m_axis_demux_ready[11])|
                            ((sel == 12) & is_trans & m_axis_demux_ready[12]);

end // CHNL_DEMUX_13
else if (CHNL_NUM == 12) begin:CHNL_DEMUX_12

assign s_axis_demux_ready = ((sel == 0) & is_trans & m_axis_demux_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_demux_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_demux_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_demux_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_demux_ready[4]) |
                            ((sel == 5) & is_trans & m_axis_demux_ready[5]) |
                            ((sel == 6) & is_trans & m_axis_demux_ready[6]) |
                            ((sel == 7) & is_trans & m_axis_demux_ready[7]) |
                            ((sel == 8) & is_trans & m_axis_demux_ready[8]) |
                            ((sel == 9) & is_trans & m_axis_demux_ready[9]) |
                            ((sel == 10) & is_trans & m_axis_demux_ready[10])|
                            ((sel == 11) & is_trans & m_axis_demux_ready[11]);

end // CHNL_DEMUX_12
else if (CHNL_NUM == 11) begin:CHNL_DEMUX_11

assign s_axis_demux_ready = ((sel == 0) & is_trans & m_axis_demux_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_demux_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_demux_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_demux_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_demux_ready[4]) |
                            ((sel == 5) & is_trans & m_axis_demux_ready[5]) |
                            ((sel == 6) & is_trans & m_axis_demux_ready[6]) |
                            ((sel == 7) & is_trans & m_axis_demux_ready[7]) |
                            ((sel == 8) & is_trans & m_axis_demux_ready[8]) |
                            ((sel == 9) & is_trans & m_axis_demux_ready[9]) |
                            ((sel == 10) & is_trans & m_axis_demux_ready[10]);

end // CHNL_DEMUX_11
else if (CHNL_NUM == 10) begin:CHNL_DEMUX_10

assign s_axis_demux_ready = ((sel == 0) & is_trans & m_axis_demux_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_demux_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_demux_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_demux_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_demux_ready[4]) |
                            ((sel == 5) & is_trans & m_axis_demux_ready[5]) |
                            ((sel == 6) & is_trans & m_axis_demux_ready[6]) |
                            ((sel == 7) & is_trans & m_axis_demux_ready[7]) |
                            ((sel == 8) & is_trans & m_axis_demux_ready[8]) |
                            ((sel == 9) & is_trans & m_axis_demux_ready[9]);

end // CHNL_DEMUX_10
else if (CHNL_NUM == 9) begin:CHNL_DEMUX_9

assign s_axis_demux_ready = ((sel == 0) & is_trans & m_axis_demux_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_demux_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_demux_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_demux_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_demux_ready[4]) |
                            ((sel == 5) & is_trans & m_axis_demux_ready[5]) |
                            ((sel == 6) & is_trans & m_axis_demux_ready[6]) |
                            ((sel == 7) & is_trans & m_axis_demux_ready[7]) |
                            ((sel == 8) & is_trans & m_axis_demux_ready[8]);

end // CHNL_DEMUX_9
else if (CHNL_NUM == 8) begin:CHNL_DEMUX_8

assign s_axis_demux_ready = ((sel == 0) & is_trans & m_axis_demux_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_demux_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_demux_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_demux_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_demux_ready[4]) |
                            ((sel == 5) & is_trans & m_axis_demux_ready[5]) |
                            ((sel == 6) & is_trans & m_axis_demux_ready[6]) |
                            ((sel == 7) & is_trans & m_axis_demux_ready[7]);

end // CHNL_DEMUX_8
else if (CHNL_NUM == 7) begin:CHNL_DEMUX_7

assign s_axis_demux_ready = ((sel == 0) & is_trans & m_axis_demux_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_demux_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_demux_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_demux_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_demux_ready[4]) |
                            ((sel == 5) & is_trans & m_axis_demux_ready[5]) |
                            ((sel == 6) & is_trans & m_axis_demux_ready[6]);

end // CHNL_DEMUX_7
else if (CHNL_NUM == 6) begin:CHNL_DEMUX_6

assign s_axis_demux_ready = ((sel == 0) & is_trans & m_axis_demux_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_demux_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_demux_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_demux_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_demux_ready[4]) |
                            ((sel == 5) & is_trans & m_axis_demux_ready[5]);

end // CHNL_DEMUX_6
else if (CHNL_NUM == 5) begin:CHNL_DEMUX_5

assign s_axis_demux_ready = ((sel == 0) & is_trans & m_axis_demux_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_demux_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_demux_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_demux_ready[3]) |
                            ((sel == 4) & is_trans & m_axis_demux_ready[4]);

end // CHNL_DEMUX_5
else if (CHNL_NUM == 4) begin:CHNL_DEMUX_4

assign s_axis_demux_ready = ((sel == 0) & is_trans & m_axis_demux_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_demux_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_demux_ready[2]) |
                            ((sel == 3) & is_trans & m_axis_demux_ready[3]);

end // CHNL_DEMUX_4
else if (CHNL_NUM == 3) begin:CHNL_DEMUX_3

assign s_axis_demux_ready = ((sel == 0) & is_trans & m_axis_demux_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_demux_ready[1]) |
                            ((sel == 2) & is_trans & m_axis_demux_ready[2]);

end // CHNL_DEMUX_3
else if (CHNL_NUM == 2) begin:CHNL_DEMUX_2

assign s_axis_demux_ready = ((sel == 0) & is_trans & m_axis_demux_ready[0]) |
                            ((sel == 1) & is_trans & m_axis_demux_ready[1]);

end // CHNL_DEMUX_2
endgenerate
/* 
 This is used for different Channel Numbers, the default Number is 4 */
/* -------Generate block{end}------- */

/* -------Generate block{begin}------- */
/* This is used for different Channel Numbers, the default Number is 4
 */
genvar i;
generate
for (i = 0; i < CHNL_NUM; i = i + 1) begin:CHNL_DEMUX_ASSIGN

assign m_axis_demux_valid[(i+1)*1           -1:i*1          ] = ((i == sel) & is_trans) ? s_axis_demux_valid : 0;
assign m_axis_demux_last [(i+1)*1           -1:i*1          ] = ((i == sel) & is_trans) ? s_axis_demux_last  : 0;
assign m_axis_demux_data [(i+1)*TDATA_WIDTH -1:i*TDATA_WIDTH] = ((i == sel) & is_trans) ? s_axis_demux_data  : 0;
assign m_axis_demux_head [(i+1)*TUSER_WIDTH -1:i*TUSER_WIDTH] = ((i == sel) & is_trans) ? s_axis_demux_head  : 0;

end
endgenerate
/* 
 This is used for different Channel Numbers, the default Number is 4 */
/* -------Generate block{end}------- */

endmodule
