module DMARdRspChannel ( 	//512 to 256
	input 	wire 									clk,
	input 	wire 									rst,

	input 	wire 									dma_rd_rsp_in_valid,
	input 	wire 		[127:0]						dma_rd_rsp_in_head,
	input 	wire 		[255:0]						dma_rd_rsp_in_data,
	input 	wire 									dma_rd_rsp_in_last,
	output 	wire 									dma_rd_rsp_in_ready,

	output 	wire 									dma_rd_rsp_out_valid,
	output 	wire 		[127:0]						dma_rd_rsp_out_head,
	output 	wire 		[511:0]						dma_rd_rsp_out_data,
	output 	wire 									dma_rd_rsp_out_last,
	input 	wire 									dma_rd_rsp_out_ready
);

wire 									st_dma_rd_rsp_in_valid;
wire 		[127:0]						st_dma_rd_rsp_in_head;
wire 		[511:0]						st_dma_rd_rsp_in_data;
wire 									st_dma_rd_rsp_in_last;
wire 									st_dma_rd_rsp_in_ready;

stream_reg #(
    .TUSER_WIDTH	(		128				),
    .TDATA_WIDTH	(		256				)
)
rd_chanl_st
(
    .clk   			(		clk				),
    .rst_n 			(		!rst 			),

    .axis_tvalid 	(		dma_rd_rsp_in_valid		),
    .axis_tlast  	(		dma_rd_rsp_in_last		),
    .axis_tuser  	(		dma_rd_rsp_in_head		),
    .axis_tdata  	(		dma_rd_rsp_in_data		),
    .axis_tready 	(		dma_rd_rsp_in_ready		),
    .axis_tstart	(		'd0						),
    .axis_tkeep		(		'd0						),

    .in_reg_tvalid	(		st_dma_rd_rsp_in_valid		),
    .in_reg_tlast 	(		st_dma_rd_rsp_in_last		), 
    .in_reg_tuser 	(		st_dma_rd_rsp_in_head		),
    .in_reg_tdata 	(		st_dma_rd_rsp_in_data		),
    .in_reg_tready	(		st_dma_rd_rsp_in_ready		),
    .in_reg_tkeep 	(								),
    .in_reg_tstart	(								),


    .tuser_clear	(								)
);


reg 					[255:0]						data_piece;
reg 					[31:0]						length_left;

reg 					[1:0]						cur_state;
reg 					[1:0]						next_state;

parameter 				[1:0]						IDLE_s		=		2'd1,
													LOW_s 		=		2'd2,
													HIGH_s 		=		2'd3;

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
		IDLE_s:				if(st_dma_rd_rsp_in_valid) begin
								next_state = LOW_s;
							end
							else begin
								next_state = IDLE_s;
							end
		LOW_s:				if(length_left <= 32 && st_dma_rd_rsp_in_valid && dma_rd_rsp_out_ready) begin
								next_state = IDLE_s;
							end
							else if(length_left > 32 && st_dma_rd_rsp_in_valid) begin
								next_state = HIGH_s;
							end
							else begin
								next_state = LOW_s;
							end
		HIGH_s:				if(length_left <= 32 && st_dma_rd_rsp_in_valid && dma_rd_rsp_out_ready) begin
								next_state = IDLE_s;
							end
							else if(length_left > 32 && st_dma_rd_rsp_in_valid && dma_rd_rsp_out_ready) begin
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
	else if (cur_state == IDLE_s && st_dma_rd_rsp_in_valid) begin
		length_left <= st_dma_rd_rsp_in_head[31:0];
	end
	else if(cur_state == LOW_s && length_left <= 32 && st_dma_rd_rsp_in_valid && dma_rd_rsp_out_ready) begin
		length_left <= 'd0;
	end
	else if(cur_state == LOW_s && length_left > 32 && st_dma_rd_rsp_in_valid) begin
		length_left <= length_left - 32;
	end
	else if(cur_state == HIGH_s && length_left <= 32 && st_dma_rd_rsp_in_valid && dma_rd_rsp_out_ready) begin
		length_left <= 'd0;
	end
	else if(cur_state == HIGH_s && length_left > 32 && st_dma_rd_rsp_in_valid && dma_rd_rsp_out_ready) begin
		length_left <= length_left - 32;
	end
	else begin
		length_left <= length_left;
	end
end

always @(posedge clk or posedge rst) begin
	if (rst) begin
		data_piece <= 'd0;		
	end
	else if (cur_state == LOW_s && length_left > 32 && st_dma_rd_rsp_in_valid) begin
		data_piece <= st_dma_rd_rsp_in_data;
	end
	else begin
		data_piece <= data_piece;
	end
end

assign st_dma_rd_rsp_in_ready = (cur_state == LOW_s && length_left <= 32) ? dma_rd_rsp_out_ready :
								(cur_state == LOW_s && length_left > 32) ? 'd1 :
								(cur_state == HIGH_s) ? dma_rd_rsp_out_ready : 'd0;

assign dma_rd_rsp_out_valid = (cur_state == LOW_s && length_left <= 32 && st_dma_rd_rsp_in_valid) ? 'd1 :
								(cur_state == HIGH_s && st_dma_rd_rsp_in_valid) ? 'd1 : 'd0;
assign dma_rd_rsp_out_head = (cur_state == LOW_s || cur_state == HIGH_s) ? st_dma_rd_rsp_in_head : 'd0;
assign dma_rd_rsp_out_data = (cur_state == LOW_s && length_left <= 32 && st_dma_rd_rsp_in_valid) ? {256'd0, st_dma_rd_rsp_in_data} :
								(cur_state == HIGH_s && st_dma_rd_rsp_in_valid) ? {st_dma_rd_rsp_in_data, data_piece} : 'd0;
assign dma_rd_rsp_out_last = (cur_state == LOW_s && length_left <= 32 && st_dma_rd_rsp_in_valid) ? 'd1 : 
							(cur_state == HIGH_s && length_left <= 32 && st_dma_rd_rsp_in_valid) ? 'd1 : 'd0; 

endmodule