/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       BitWidthTrans_512To128
Author:     YangFan
Function:   512 bit dma data to 128 bit WQE seg, to facilitate decoding.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module BitWidthTrans_512To128
(
	input 	wire 										clk,
	input 	wire 										rst,

	input 	wire 										size_valid,
	input 	wire 			[31:0]						block_size,

	output 	wire 										gather_resp_rd_en,
	input 	wire 										gather_resp_empty,
	input 	wire 			[511:0]						gather_resp_dout,

	output 	wire 										wqe_seg_valid,
	output 	wire 			[127:0]						wqe_seg_data,
	input 	wire 										wqe_seg_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg 					[31:0]				data_left;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg 					[2:0]				cur_state;
reg 					[2:0]				next_state;

parameter 				[2:0]				IDLE_s = 3'd1,
											PIECE_0_s = 3'd2,
											PIECE_1_s = 3'd3,
											PIECE_2_s = 3'd4,
											PIECE_3_s = 3'd5;

always @(posedge clk or posedge rst) begin
	if(rst) begin
		cur_state <= IDLE_s;
	end
	else begin
		cur_state <= next_state;
	end
end

always @(*) begin
	case(cur_state)
		IDLE_s:					if(!gather_resp_empty && size_valid) begin
									next_state = PIECE_0_s;
								end
								else begin
									next_state = IDLE_s;
								end
		PIECE_0_s:				if(wqe_seg_ready && data_left <= 16) begin
									next_state = IDLE_s;
								end
								else if(wqe_seg_ready && data_left > 16) begin
									next_state = PIECE_1_s;
								end
								else begin
									next_state = PIECE_0_s;
								end
		PIECE_1_s:				if(wqe_seg_ready && data_left <= 16) begin
									next_state = IDLE_s;
								end
								else if(wqe_seg_ready && data_left > 16) begin
									next_state = PIECE_2_s;
								end
								else begin
									next_state = PIECE_1_s;
								end
		PIECE_2_s:				if(wqe_seg_ready && data_left <= 16) begin
									next_state = IDLE_s;
								end
								else if(wqe_seg_ready && data_left > 16) begin
									next_state = PIECE_3_s;
								end
								else begin
									next_state = PIECE_2_s;
								end
		PIECE_3_s:				if(wqe_seg_ready && data_left <= 16) begin
									next_state = IDLE_s;
								end
								else if(wqe_seg_ready && data_left > 16) begin
									next_state = PIECE_0_s;
								end
								else begin
									next_state = PIECE_3_s;
								end
		default:				next_state = IDLE_s;
	endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- data_left --
always @(posedge clk or posedge rst) begin
	if (rst) begin
		data_left <= 'd0;		
	end
	else if (cur_state == IDLE_s && !gather_resp_empty) begin
		data_left <= block_size;
	end
	else if(cur_state == PIECE_0_s && !gather_resp_empty && wqe_seg_ready) begin
		data_left <= (data_left <= 16) ? 'd0 : data_left - 16;
	end
	else if(cur_state == PIECE_1_s && wqe_seg_ready) begin
		data_left <= (data_left <= 16) ? 'd0 : data_left - 16;
	end
	else if(cur_state == PIECE_2_s && wqe_seg_ready) begin
		data_left <= (data_left <= 16) ? 'd0 : data_left - 16;
	end
	else if(cur_state == PIECE_3_s && wqe_seg_ready) begin
		data_left <= (data_left <= 16) ? 'd0 : data_left - 16;
	end
	else begin
		data_left <= data_left;
	end
end

//-- gather_resp_rd_en --
assign gather_resp_rd_en = 	(cur_state == PIECE_0_s && data_left <= 16 && wqe_seg_ready) ? 'd1 :
							(cur_state == PIECE_1_s && data_left <= 16 && wqe_seg_ready) ? 'd1 :
							(cur_state == PIECE_2_s && data_left <= 16 && wqe_seg_ready) ? 'd1 :
							(cur_state == PIECE_3_s && wqe_seg_ready) ? 'd1 : 'd0;

//-- wqe_seg_valid --
//-- wqe_seg_data --
assign wqe_seg_valid = 	(cur_state == PIECE_0_s && !gather_resp_empty) ? 'd1 : 
 						(cur_state == PIECE_1_s) ? 'd1 : 
 						(cur_state == PIECE_2_s) ? 'd1 : 
 						(cur_state == PIECE_3_s) ? 'd1 : 'd0;
assign wqe_seg_data = 	(cur_state == PIECE_0_s) ? gather_resp_dout[128 * 1 - 1 : 128 * 0] :
						(cur_state == PIECE_1_s) ? gather_resp_dout[128 * 2 - 1 : 128 * 1] :
						(cur_state == PIECE_2_s) ? gather_resp_dout[128 * 3 - 1 : 128 * 2] :
						(cur_state == PIECE_3_s) ? gather_resp_dout[128 * 4 - 1 : 128 * 3] : 'd0;
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule