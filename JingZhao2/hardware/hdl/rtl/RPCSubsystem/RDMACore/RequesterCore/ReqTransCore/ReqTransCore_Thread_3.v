/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ReqTransCore_Thread_3
Author:     YangFan
Function:   1.Generate DMA Read Request (Read payload from memory).
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module ReqTransCore_Thread_3
#(
    parameter                       EGRESS_MR_HEAD_WIDTH                    =   128,
    parameter                       EGRESS_MR_DATA_WIDTH                    =   256
)
(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with OoOStation(For MRMgt)
    input  	wire                                                            fetch_mr_egress_valid,
    input  	wire    [`TX_REQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]             	fetch_mr_egress_head,
    input  	wire    [`TX_REQ_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]             	fetch_mr_egress_data,
    input  	wire                                                            fetch_mr_egress_start,
    input  	wire                                                            fetch_mr_egress_last,
    output  wire                                                            fetch_mr_egress_ready,

//Interface with ReqTransCore_Thread_4
	output 	wire 															net_req_wen,
	output 	wire 	[`WQE_META_WIDTH - 1 : 0]								net_req_din,
	input 	wire 															net_req_prog_full,

//DMA Read Interface
	output 	reg 															gather_req_wr_en,
	output 	reg  	[`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]		gather_req_din,
	input 	wire 															gather_req_prog_full
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define 	SUB_WQE_NET_OPCODE_OFFSET 				60:56
`define 	SUB_WQE_INLINE_OFFSET					68
`define 	SUB_WQE_PACKET_LENGTH_OFFSET			527:512
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg  			[`MR_RESP_WIDTH - 1 : 0]	 			mr_resp_bus;
reg  			[`WQE_META_WIDTH - 1 : 0] 				wqe_bus;

wire 			[4:0]									SubWQE_net_opcode;
wire 			[0:0]									SubWQE_inline;
wire 			[15:0]									SubWQE_packet_length;

wire 			[0:0]									no_gather;

reg 			[1:0]									data_piece_left;
reg 			[1:0]									data_piece_total;

wire 			[3:0]									mr_resp_state;
wire 			[3:0]									mr_resp_valid_0;
wire 			[3:0]									mr_resp_valid_1;
wire 			[31:0]									mr_resp_size_0;
wire 			[31:0]									mr_resp_size_1;
wire 			[63:0]									mr_resp_phy_addr_0;
wire 			[63:0]									mr_resp_phy_addr_1;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg  			[2:0]				cur_state;
reg 			[2:0]				next_state;

parameter 		[2:0]				IDLE_s 			= 	3'd1,
									JUDGE_s 		= 	3'd2,
									GATHER_s 		=	3'd3,
									FWD_s 			=	3'd4;

always @(posedge clk or posedge rst) begin
	if(rst) begin
		cur_state <= IDLE_s;
	end
	else begin
		cur_state <= next_state;
	end
end								

always @(*)	 begin
	case(cur_state)
		IDLE_s:						if(fetch_mr_egress_valid) begin
										next_state = JUDGE_s;
									end
									else begin
										next_state = IDLE_s;
									end
		JUDGE_s:					if(no_gather) begin
										next_state = FWD_s;
									end
									else begin
										next_state = GATHER_s;
									end
		GATHER_s:					if(data_piece_left == 'd1 && !gather_req_prog_full) begin
										next_state = FWD_s;
									end
									else begin
										next_state = GATHER_s;
									end
		FWD_s:						if(!net_req_prog_full) begin
										next_state = IDLE_s;
									end
									else begin
										next_state = FWD_s;
									end
		default:					next_state = IDLE_s;
	endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- wqe_bus --
always @(posedge clk or posedge rst) begin
	if (rst) begin
		wqe_bus <= 'd0;
		mr_resp_bus <= 'd0;		
	end
	else if (cur_state == IDLE_s && fetch_mr_egress_valid) begin
		wqe_bus <= fetch_mr_egress_data;
		mr_resp_bus <= fetch_mr_egress_head[`MR_RESP_WIDTH + `EGRESS_COMMON_HEAD_WIDTH - 1 : `EGRESS_COMMON_HEAD_WIDTH];
	end
	else begin
		wqe_bus <= wqe_bus;
		mr_resp_bus <= mr_resp_bus;
	end
end

//-- SubWQE_net_opcode --
//-- SubWQE_inline --
//-- SubWQE_packet_length --
assign SubWQE_net_opcode = wqe_bus[`SUB_WQE_NET_OPCODE_OFFSET];
assign SubWQE_inline = wqe_bus[`SUB_WQE_INLINE_OFFSET];
assign SubWQE_packet_length = wqe_bus[`SUB_WQE_PACKET_LENGTH_OFFSET];

//-- no_gather --
assign no_gather = (SubWQE_inline || (SubWQE_net_opcode == `RDMA_READ_REQUEST_FIRST || SubWQE_net_opcode == `RDMA_READ_REQUEST_MIDDLE || 
										SubWQE_net_opcode == `RDMA_READ_REQUEST_LAST || SubWQE_net_opcode == `RDMA_READ_REQUEST_ONLY ||
										SubWQE_net_opcode == `GEN_CQE || SubWQE_net_opcode == `GEN_EVENT));

//-- mr_resp_state --
//-- mr_resp_valid_0 --
//-- mr_resp_valid_1 --
//-- mr_resp_size_0 --
//-- mr_resp_size_1 --
//-- mr_resp_phy_addr_0 --
//-- mr_resp_phy_addr_1 --
assign mr_resp_state = mr_resp_bus[`MR_RESP_STATE_OFFSET];
assign mr_resp_valid_0 = mr_resp_bus[`MR_RESP_VALID_0_OFFSET];
assign mr_resp_valid_1 = mr_resp_bus[`MR_RESP_VALID_1_OFFSET];
assign mr_resp_size_0 = mr_resp_bus[`MR_RESP_SIZE_0_OFFSET];
assign mr_resp_size_1 = mr_resp_bus[`MR_RESP_SIZE_1_OFFSET];
assign mr_resp_phy_addr_0 = mr_resp_bus[`MR_RESP_ADDR_0_OFFSET];
assign mr_resp_phy_addr_1 = mr_resp_bus[`MR_RESP_ADDR_1_OFFSET];

//-- data_piece_left --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		data_piece_left <= 'd0;
	end
	else if(cur_state == IDLE_s) begin
		data_piece_left <= data_piece_left;
	end
	else if(cur_state == JUDGE_s) begin
		data_piece_left <= mr_resp_valid_1 ? 'd2 : 'd1;
	end
	else if(cur_state == GATHER_s && !gather_req_prog_full) begin
		data_piece_left <= data_piece_left - 'd1;
	end
	else begin
		data_piece_left <= data_piece_left;
	end
end

//-- data_piece_total --
always @(posedge clk or posedge rst) begin
	if (rst) begin
		data_piece_total <= 'd0;		
	end
	else if (cur_state == IDLE_s) begin
		data_piece_total <= data_piece_total;
	end
	else if(cur_state == JUDGE_s) begin
		data_piece_total <= mr_resp_valid_1 ? 'd2 : 'd1;
	end
	else begin
		data_piece_total <= data_piece_total;
	end
end

//-- fetch_mr_egress_ready --
assign fetch_mr_egress_ready = (cur_state == IDLE_s) ? 'd1 : 'd0;

//-- net_req_wen --
//-- net_req_din --
assign net_req_wen = (cur_state == FWD_s && !net_req_prog_full) ? 'd1 : 'd0;
assign net_req_din = (cur_state == FWD_s && (SubWQE_net_opcode != `GEN_CQE && SubWQE_net_opcode != `GEN_EVENT)) ? wqe_bus :
						(cur_state == FWD_s && (SubWQE_net_opcode == `GEN_CQE || SubWQE_net_opcode == `GEN_EVENT)) ? {wqe_bus[575:384], 64'd0, mr_resp_phy_addr_0, wqe_bus[255:0]} : 'd0;

//-- gather_req_wr_en --
//-- gather_req_din --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		gather_req_wr_en <= 'd0;
		gather_req_din <= 'd0;
	end
	else if(cur_state == GATHER_s && !gather_req_prog_full) begin
		if(data_piece_total == 'd2) begin
			gather_req_wr_en <= 'd1;
			gather_req_din <= (data_piece_left == 'd2) ? {SubWQE_packet_length, mr_resp_size_0, mr_resp_phy_addr_0} : {SubWQE_packet_length, mr_resp_size_1, mr_resp_phy_addr_1};
		end
		else begin
			gather_req_wr_en <= 'd1;
			gather_req_din <= {SubWQE_packet_length, mr_resp_size_0, mr_resp_phy_addr_0};
		end
	end
	else begin
		gather_req_wr_en <= 'd0;
		gather_req_din <= 'd0;		
	end
end
/*------------------------------------------- Variables Decode : End ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef 		SUB_WQE_NET_OPCODE_OFFSET
`undef 		SUB_WQE_INLINE_OFFSET
`undef 		SUB_WQE_PACKET_LENGTH_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule