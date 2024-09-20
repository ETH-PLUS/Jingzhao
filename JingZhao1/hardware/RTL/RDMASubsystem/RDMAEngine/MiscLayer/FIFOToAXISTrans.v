`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/02/24 15:09:58
// Design Name: 
// Module Name: FIFOToAXISTrans
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module FIFOToAXISTrans(
	input 	wire 									clk,
	input 	wire 									rst,

	output 	wire 									o_hpc_rd_en,
	input 	wire 									i_hpc_empty,
	input 	wire 		[255:0]						iv_hpc_data,	

	output  wire                                 	o_hpc_tx_valid,
	output  wire                                 	o_hpc_tx_last,
	output  wire		[255:0]            			ov_hpc_tx_data,
	output  wire		[4:0]            			ov_hpc_tx_keep,
	input   wire                                 	i_hpc_tx_ready,
	//Additional signals
	output wire 									o_hpc_tx_start, 		//Indicates start of the packet
	output wire 		[6:0]						ov_hpc_tx_user, 	 	//Indicates length of the packet, in unit of 128 Byte, round up to 128

	input 	wire  		[31:0]						dbg_sel,
	output 	wire  		[32 - 1:0]						dbg_bus
	//output 	wire  		[`DBG_NUM_FIFO_TO_AXIS_TRANS * 32 - 1:0]						dbg_bus
);

reg 			[1:0]				FTA_cur_state;
reg 			[1:0]				FTA_next_state;

parameter 		[1:0]				FTA_IDLE_s = 2'd1,
									FTA_TRANS_s = 2'd2;

always @(posedge clk or posedge rst) begin
	if(rst) begin
		FTA_cur_state <= FTA_IDLE_s;
	end 
	else begin
		FTA_cur_state <= FTA_next_state;
	end 
end 

reg 			[15:0]				qv_pkt_left;	//In unit of 1B
reg 			[15:0]				qv_pkt_len; 	//In unit of 128B

wire 			[11:0]				wv_pkt_len;

`ifdef NIC_DROP_THRESHOLD
reg 			[31:0]				qv_drop_threshold;
always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_drop_threshold <= 'd0;
	end 
	else if(FTA_cur_state == FTA_IDLE_s && FTA_next_state == FTA_TRANS_s) begin
		if(qv_drop_threshold == `NIC_DROP_THRESHOLD) begin
			qv_drop_threshold <= 'd0;
		end 
		else begin
			qv_drop_threshold <= qv_drop_threshold + 'd1;
		end 
	end 
	else begin
		qv_drop_threshold <= qv_drop_threshold;
	end 
end 
`endif

assign wv_pkt_len = iv_hpc_data[58:48]; 

always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_pkt_left <= 'd0;
	end 
	else if(FTA_cur_state == FTA_IDLE_s && !i_hpc_empty) begin
		//qv_pkt_left <= (wv_pkt_len - 'd1) << 2;	  	//Substract ICRC length since we do not add ICRC here, the length is just used by LlinkLayer
		qv_pkt_left <= (wv_pkt_len) << 2;	  	//Remove ICRC-related length
	end 
	else if(FTA_cur_state == FTA_TRANS_s && !i_hpc_empty && i_hpc_tx_ready) begin
		qv_pkt_left <= qv_pkt_left - 'd32;
	end 
	else begin
		qv_pkt_left <= qv_pkt_left;
	end 
end 

always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_pkt_len <= 'd0;
	end 
	else if(FTA_cur_state == FTA_IDLE_s && !i_hpc_empty) begin
		qv_pkt_len <= (wv_pkt_len) % 32 == 'd0 ? (wv_pkt_len / 32) : (wv_pkt_len / 32) + 'd1; //wv_pkt_len is in unit of 4B, qv_pkt_len is in unit of 128B
	end 
	else begin
		qv_pkt_len <= qv_pkt_len;
	end 
end 

always @(*) begin
	case(FTA_cur_state) 
		FTA_IDLE_s:		if(!i_hpc_empty) begin
							FTA_next_state = FTA_TRANS_s;
						end 
						else begin
							FTA_next_state = FTA_IDLE_s;
						end 
		FTA_TRANS_s:	if(qv_pkt_left <= 'd32 && !i_hpc_empty && i_hpc_tx_ready) begin
							FTA_next_state = FTA_IDLE_s;
						end 
						else begin
							FTA_next_state = FTA_TRANS_s;
						end 
		default:		FTA_next_state = FTA_IDLE_s;
	endcase
end 

reg 							q_hpc_rd_en;

reg 							q_hpc_tx_valid;
reg 							q_hpc_tx_last;
reg 			[255:0]			qv_hpc_tx_data;
reg 			[4:0]			qv_hpc_tx_keep;
reg 							q_hpc_tx_start; 		
reg 			[6:0]			qv_hpc_tx_user;	 	

assign o_hpc_tx_valid = q_hpc_tx_valid;
assign o_hpc_tx_last = q_hpc_tx_last;
assign ov_hpc_tx_data = qv_hpc_tx_data;
assign ov_hpc_tx_keep = qv_hpc_tx_keep;
assign o_hpc_tx_start = q_hpc_tx_start;
assign ov_hpc_tx_user = qv_hpc_tx_user;

reg 							q_start_signal;
always @(posedge clk or posedge rst) begin
	if(rst) begin
		q_start_signal <= 'd0;
	end 
	else if(FTA_cur_state == FTA_IDLE_s && !i_hpc_empty) begin
		q_start_signal <= 'd1;
	end 
	else if(FTA_cur_state == FTA_TRANS_s && q_start_signal && !i_hpc_empty && i_hpc_tx_ready) begin
		q_start_signal <= 'd0;
	end 
	else begin
		q_start_signal <= q_start_signal;
	end 
end 

always @(*) begin
	if(rst) begin
		q_hpc_tx_valid = 'd0;
		q_hpc_tx_last = 'd0;
		qv_hpc_tx_data = 'd0;
		qv_hpc_tx_keep = 'd0;
		q_hpc_tx_start = 'd0;
		qv_hpc_tx_user = 'd0;
	end 
`ifndef NIC_DROP_THRESHOLD
	else if(FTA_cur_state == FTA_TRANS_s) begin
		q_hpc_tx_valid = !i_hpc_empty;
		q_hpc_tx_last = !i_hpc_empty && (qv_pkt_left <= 32);
		qv_hpc_tx_data = iv_hpc_data;
		qv_hpc_tx_keep = (qv_pkt_left < 32) ? qv_pkt_left : 5'b00000;
		q_hpc_tx_start = q_start_signal;
		qv_hpc_tx_user = qv_pkt_len;
	end 
`else 
	else if(FTA_cur_state == FTA_TRANS_s && qv_drop_threshold != `NIC_DROP_THRESHOLD) begin
		q_hpc_tx_valid = !i_hpc_empty;
		q_hpc_tx_last = !i_hpc_empty && (qv_pkt_left <= 32);
		qv_hpc_tx_data = iv_hpc_data;
		qv_hpc_tx_keep = (qv_pkt_left < 32) ? qv_pkt_left : 5'b00000;
		q_hpc_tx_start = q_start_signal;
		qv_hpc_tx_user = qv_pkt_len;
	end 
`endif
	else begin
		q_hpc_tx_valid = 'd0;
		q_hpc_tx_last = 'd0;
		qv_hpc_tx_data = 'd0;
		qv_hpc_tx_keep = 'd0;
		q_hpc_tx_start = 'd0;
		qv_hpc_tx_user = 'd0;		
	end 
end 

always @(*) begin
	if(rst) begin
		q_hpc_rd_en = 'd0;
	end 	
	else if(FTA_cur_state == FTA_TRANS_s && !i_hpc_empty && i_hpc_tx_ready) begin
		q_hpc_rd_en = 'd1;
	end 
	else begin
		q_hpc_rd_en = 'd0;
	end 
end

assign o_hpc_rd_en = q_hpc_rd_en;


/*----------------------------------- connect dbg bus -------------------------------------*/
wire   [`DBG_NUM_FIFO_TO_AXIS_TRANS * 32 - 1 : 0]   coalesced_bus;

assign coalesced_bus = {
                            FTA_cur_state,
                            FTA_next_state,
                            qv_pkt_left,	
                            qv_pkt_len, 	
                            q_hpc_rd_en,
                            q_hpc_tx_valid,
                            q_hpc_tx_last,
                            qv_hpc_tx_data,
                            qv_hpc_tx_keep,
                            q_hpc_tx_start, 		
                            qv_hpc_tx_user,	 	
                            q_start_signal
                        };

assign dbg_bus =    (dbg_sel == 0)  ?   coalesced_bus[32 * 1 - 1 : 32 * 0] :
                    (dbg_sel == 1)  ?   coalesced_bus[32 * 2 - 1 : 32 * 1] :
                    (dbg_sel == 2)  ?   coalesced_bus[32 * 3 - 1 : 32 * 2] :
                    (dbg_sel == 3)  ?   coalesced_bus[32 * 4 - 1 : 32 * 3] :
                    (dbg_sel == 4)  ?   coalesced_bus[32 * 5 - 1 : 32 * 4] :
                    (dbg_sel == 5)  ?   coalesced_bus[32 * 6 - 1 : 32 * 5] :
                    (dbg_sel == 6)  ?   coalesced_bus[32 * 7 - 1 : 32 * 6] :
                    (dbg_sel == 7)  ?   coalesced_bus[32 * 8 - 1 : 32 * 7] :
                    (dbg_sel == 8)  ?   coalesced_bus[32 * 9 - 1 : 32 * 8] :
                    (dbg_sel == 9)  ?   coalesced_bus[32 * 10 - 1 : 32 * 9] : 32'd0;

//assign dbg_bus = coalesced_bus;

endmodule
