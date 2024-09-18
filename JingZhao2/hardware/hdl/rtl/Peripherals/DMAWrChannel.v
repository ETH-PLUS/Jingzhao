module DMAWrReqChannel ( 	//512 to 256
	input 	wire 									clk,
	input 	wire 									rst,

	input 	wire 									dma_wr_req_in_valid,
	input 	wire 		[127:0]						dma_wr_req_in_head,
	input 	wire 		[511:0]						dma_wr_req_in_data,
	input 	wire 									dma_wr_req_in_last,
	output 	wire 									dma_wr_req_in_ready,

	output 	wire 									dma_wr_req_out_valid,
	output 	wire 		[127:0]						dma_wr_req_out_head,
	output 	wire 		[255:0]						dma_wr_req_out_data,
	output 	wire 									dma_wr_req_out_last,
	input 	wire 									dma_wr_req_out_ready
);

reg 					[31:0]						length_left;

reg 					[1:0]						cur_state;
reg 					[1:0]						next_state;

parameter 				[1:0]						IDLE_s 	=	2'd1,
													LOW_s	=	2'd2,
													HIGH_s	=	2'd3;

always @(posedge clk or posedge rst) begin
	if (rst) begin
		cur_state <= IDLE_s;
	end
	else begin
		cur_state <= next_state;
	end
end

always @(*) begin
	case(cur_state)
		IDLE_s:				if(dma_wr_req_in_valid) begin
								next_state = LOW_s;
							end
							else begin
								next_state = IDLE_s;
							end
		LOW_s:				if(length_left <= 32 && dma_wr_req_in_valid && dma_wr_req_out_ready) begin
								next_state = IDLE_s;
							end
							else if(length_left > 32 && dma_wr_req_in_valid && dma_wr_req_out_ready) begin
								next_state = HIGH_s;
							end
							else begin
								next_state = LOW_s;
							end
		HIGH_s:				if(length_left <= 32 && dma_wr_req_in_valid && dma_wr_req_out_ready) begin
								next_state = IDLE_s;
							end
							else if(length_left > 32 && dma_wr_req_in_valid && dma_wr_req_out_ready) begin
								next_state = LOW_s;
							end
							else begin
								next_state = HIGH_s;
							end
		default:			next_state = IDLE_s;
	endcase
end

always @(posedge clk or posedge rst) begin
	if (rst) begin
		length_left <= 'd0;		
	end
	else if (cur_state == IDLE_s && dma_wr_req_in_valid) begin
		length_left <= dma_wr_req_in_head[31:0];
	end
	else if(cur_state == LOW_s && dma_wr_req_in_valid && dma_wr_req_out_ready) begin
		if(length_left <= 32) begin
			length_left <= 'd0;
		end
		else begin
			length_left <= length_left - 32;
		end
	end
	else if(cur_state == HIGH_s && dma_wr_req_in_valid && dma_wr_req_out_ready) begin
		if(length_left <= 32) begin
			length_left <= 'd0;
		end
		else begin
			length_left <= length_left - 32;
		end
	end
	else begin
		length_left <= length_left;
	end
end

assign dma_wr_req_in_ready = (cur_state == LOW_s && length_left <= 32) ? dma_wr_req_out_ready :
								(cur_state == HIGH_s) ? dma_wr_req_out_ready : 'd0;

assign dma_wr_req_out_valid = (cur_state == LOW_s || cur_state == HIGH_s) ? dma_wr_req_in_valid : 'd0; 
assign dma_wr_req_out_head = (cur_state == LOW_s || cur_state == HIGH_s) ? dma_wr_req_in_head : 'd0;
assign dma_wr_req_out_data = (cur_state == LOW_s) ? dma_wr_req_in_data[255:0] :
								(cur_state == HIGH_s) ? dma_wr_req_in_data[511:256] : 'd0;
assign dma_wr_req_out_last = (cur_state == LOW_s && length_left <= 32 && dma_wr_req_in_valid) ? 'd1 : 
								(cur_state == HIGH_s && length_left <= 32 && dma_wr_req_in_valid) ? 'd1 : 'd0;

endmodule