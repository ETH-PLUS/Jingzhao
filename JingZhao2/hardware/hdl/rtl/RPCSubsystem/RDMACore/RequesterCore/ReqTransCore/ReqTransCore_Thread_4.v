/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ReqTransCore_Thread_4
Author:     YangFan
Function:   1.Push network payload to Payload Buffer.
			2.Generate Completion, Event and Interrupt.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module ReqTransCore_Thread_4
(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with ReqTransCore_Thread_3
	output 	wire 															net_req_ren,
	input 	wire 	[`WQE_META_WIDTH - 1 : 0]								net_req_dout,
	input 	wire 															net_req_empty,

//Interface with GatherData
	output 	wire                                                            net_data_rd_en,
	input 	wire    [`DMA_DATA_WIDTH - 1 : 0]                               net_data_dout,
	input 	wire                                                            net_data_empty,

//ScatterData Req Interface
	output 	reg 	                                                   		scatter_req_wen,
	output 	reg 	[`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]       scatter_req_din,
	input 	wire 	                                                    	scatter_req_prog_full,

	output 	reg 	                                                   		scatter_data_wen,
	output 	reg 	[`DMA_DATA_WIDTH - 1 : 0]                               scatter_data_din,
	input 	wire 	                                                    	scatter_data_prog_full,

//Interface WQEBuffer
	output  wire                                            				enqueue_req_valid,
    output  wire    [`MAX_QP_NUM_LOG + `MAX_DMQ_SLOT_NUM_LOG - 1 : 0]  		enqueue_req_head,
    output  wire    [`RC_WQE_BUFFER_SLOT_WIDTH - 1 : 0]                    	enqueue_req_data,
    output 	wire 															enqueue_req_start,
    output 	wire 															enqueue_req_last,
	input  	wire                                            				enqueue_req_ready,

    output  wire                                                            insert_req_valid,
    output  wire                                                            insert_req_start,
    output  wire                                                            insert_req_last,
    output  wire    [`MAX_DB_SLOT_NUM_LOG - 1 : 0]           				insert_req_head,
    output  wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]             				insert_req_data,
    input   wire                                                            insert_req_ready,

    input   wire                                                            insert_resp_valid,
    input   wire    [`MAX_DB_SLOT_NUM_LOG - 1 : 0]             				insert_resp_data,

//Interface with TransportSubsystem
	output 	wire 															egress_pkt_valid,
	output 	wire 	[`PKT_META_BUS_WIDTH - 1 : 0]							egress_pkt_head,
	input 	wire 															egress_pkt_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define 	NET_REQ_LOCAL_QPN_OFFSET					23:0
`define 	NET_REQ_VERBS_OPCODE_OFFSET					28:24
`define 	NET_REQ_REMOTE_QPN_OFFSET					55:32
`define 	NET_REQ_NET_OPCODE_OFFSET 					60:56
`define 	NET_REQ_SERVICE_TYPE_OFFSET					63:61
`define 	NET_REQ_FENCE_OFFSET						64
`define		NET_REQ_SOLICITED_EVENT_OFFSET 			 	65
`define 	NET_REQ_HEAD_OFFSET	 						66
`define 	NET_REQ_TAIL_OFFSET 						67
`define 	NET_REQ_INLINE_OFFSET						68
`define 	NET_REQ_WQE_ADDR_OFFSET 					95:72
`define 	NET_REQ_DMAC_OFFSET 						143:96
`define 	NET_REQ_SMAC_OFFSET 						191:144
`define 	NET_REQ_DIP_OFFSET 							223:192
`define 	NET_REQ_SIP_OFFSET 							255:224
`define 	NET_REQ_IMMEDIATE_OFFSET 					287:256
`define		NET_REQ_LKEY_OFFSET 						319:288
`define 	NET_REQ_LADDR_OFFSET 						383:320
`define		NET_REQ_RKEY_OFFSET 						415:384
`define 	NET_REQ_RADDR_OFFSET 						479:416
`define 	NET_REQ_CPL_EVENT_ADDR_OFFSET				479:416
`define 	NET_REQ_MSG_LENGTH_OFFSET 					511:480
`define 	NET_REQ_PKT_LENGTH_OFFSET 					527:512
`define 	NET_REQ_PAYLOAD_BUFFER_ADDR_OFFSET 			575:544

/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg 				[`WQE_META_WIDTH - 1 : 0]		net_req_bus;

wire             	[23:0]                          NetReq_local_qpn;
wire             	[23:0]                          NetReq_remote_qpn;
wire             	[4:0]                           NetReq_net_opcode;
wire             	[4:0]                           NetReq_verbs_opcode;
wire             	[2:0]                           NetReq_service_type;
wire             	[0:0]                           NetReq_fence;
wire             	[0:0]                           NetReq_solicted_event;
wire             	[0:0]                           NetReq_wqe_head;
wire             	[0:0]                           NetReq_wqe_tail;
wire             	[0:0]                           NetReq_inline;
wire             	[23:0]                          NetReq_ori_wqe_addr;
wire             	[47:0]                          NetReq_dmac;
wire             	[47:0]                          NetReq_smac;
wire             	[31:0]                          NetReq_dip;
wire             	[31:0]                          NetReq_sip;
wire             	[31:0]                          NetReq_immediate;
wire             	[31:0]                          NetReq_lkey;
wire             	[63:0]                          NetReq_laddr;
wire             	[31:0]                          NetReq_rkey;
wire             	[63:0]                          NetReq_raddr;
wire 				[63:0]							NetReq_cpl_event_addr;
wire             	[31:0]                          NetReq_msg_length;
wire             	[`MAX_DB_SLOT_NUM_LOG - 1:0]    NetReq_packet_length;
wire 				[`MAX_DB_SLOT_NUM_LOG - 1:0]	NetReq_payload_buffer_addr;
reg 				[`MAX_DB_SLOT_NUM_LOG - 1:0]	NetReq_payload_buffer_addr_diff;

reg 				[31:0]							payload_piece_count;
reg 				[31:0]							payload_piece_total;

wire 				[255:0]							cqe_data;
reg 				[31:0]							cqe_my_qpn;
reg 				[31:0]							cqe_my_ee;
reg 				[31:0]							cqe_rqpn;
reg 				[7:0]							cqe_sl_ipok;
reg 				[7:0]							cqe_g_mlpath;
reg 				[15:0]							cqe_rlid;
reg 				[31:0]							cqe_imm_etype_pkey_eec;
reg 				[31:0]							cqe_byte_cnt;
reg 				[31:0]							cqe_wqe;
reg 				[7:0]							cqe_opcode;
reg 				[7:0]							cqe_is_send;
reg 				[7:0]							cqe_owner;

wire 												is_rdma_read;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg 			[3:0]					cur_state;
reg 			[3:0]					next_state;

parameter 		[3:0]					IDLE_s = 4'd1,
										JUDGE_s = 4'd2,
										WQE_ENQUEUE_s = 4'd3,
										PAYLOAD_INSERT_s = 4'd4,
										GEN_CQE_s = 4'd5,
										GEN_EVENT_s = 4'd6,
										INJECT_s = 4'd7;

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
		IDLE_s:				if(!net_req_empty) begin
								next_state = JUDGE_s;
							end
							else begin
								next_state = IDLE_s;
							end
		JUDGE_s:			if(NetReq_net_opcode == `GEN_CQE) begin
								next_state = GEN_CQE_s;
							end
							else if(NetReq_net_opcode == `GEN_EVENT) begin
								next_state = GEN_EVENT_s;
							end
							else if(NetReq_service_type == `RC) begin
								next_state = WQE_ENQUEUE_s;
							end
							else if(NetReq_service_type == `UD || NetReq_service_type == `UC) begin
								if(NetReq_inline) begin
									next_state = INJECT_s;
								end
								else begin
									next_state = PAYLOAD_INSERT_s;
								end
							end
							else begin
								next_state = JUDGE_s;
							end
		WQE_ENQUEUE_s:		if(enqueue_req_valid && enqueue_req_ready) begin
								if(NetReq_inline || is_rdma_read) begin
									next_state = INJECT_s;
								end
								else begin
									next_state = PAYLOAD_INSERT_s;
								end
							end
							else begin
								next_state = WQE_ENQUEUE_s;
							end							
		PAYLOAD_INSERT_s:	if(!net_data_empty && insert_req_valid && insert_req_ready && insert_resp_valid && (payload_piece_count == payload_piece_total)) begin
								next_state = INJECT_s;
							end
							else begin
								next_state = PAYLOAD_INSERT_s;
							end
		GEN_CQE_s:			if(!scatter_req_prog_full && !scatter_data_prog_full) begin
								next_state = IDLE_s;
							end
							else begin
								next_state = GEN_CQE_s;
							end
		GEN_EVENT_s:		if(!scatter_req_prog_full && !scatter_data_prog_full) begin
								next_state = IDLE_s;
							end
							else begin
								next_state = GEN_EVENT_s;
							end
		INJECT_s:			if(egress_pkt_valid && egress_pkt_ready) begin
								next_state = IDLE_s;
							end
							else begin
								next_state = INJECT_s;
							end
		default:			next_state = IDLE_s;
	endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- is_rdma_read --
assign is_rdma_read = (NetReq_net_opcode == `RDMA_READ_REQUEST_FIRST || NetReq_net_opcode == `RDMA_READ_REQUEST_MIDDLE || 
						NetReq_net_opcode == `RDMA_READ_REQUEST_LAST || NetReq_net_opcode == `RDMA_READ_REQUEST_ONLY);

//-- net_req_bus --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		net_req_bus <= 'd0;
	end
	else if(cur_state == IDLE_s && !net_req_empty) begin
		net_req_bus <= net_req_dout;
	end
	else begin
		net_req_bus <= net_req_bus;
	end
end

//-- NetReq_local_qpn --
//-- NetReq_remote_qpn --
//-- NetReq_net_opcode --
//-- NetReq_verbs_opcode --
//-- NetReq_service_type --
//-- NetReq_fence --
//-- NetReq_solicted_event --
//-- NetReq_wqe_head --
//-- NetReq_wqe_tail --
//-- NetReq_inline --
//-- NetReq_ori_wqe_addr --
//-- NetReq_dmac --
//-- NetReq_smac --
//-- NetReq_dip --
//-- NetReq_sip --
//-- NetReq_immediate --
//-- NetReq_cpl_event_addr --
//-- NetReq_rkey --
//-- NetReq_raddr --
//-- NetReq_msg_length --
//-- NetReq_packet_length --
//-- NetReq_payload_buffer_addr --
assign NetReq_local_qpn = net_req_bus[`NET_REQ_LOCAL_QPN_OFFSET];
assign NetReq_remote_qpn = net_req_bus[`NET_REQ_REMOTE_QPN_OFFSET];
assign NetReq_net_opcode = net_req_bus[`NET_REQ_NET_OPCODE_OFFSET];
assign NetReq_verbs_opcode = net_req_bus[`NET_REQ_VERBS_OPCODE_OFFSET];
assign NetReq_service_type = net_req_bus[`NET_REQ_SERVICE_TYPE_OFFSET];
assign NetReq_fence = net_req_bus[`NET_REQ_FENCE_OFFSET];
assign NetReq_solicted_event = net_req_bus[`NET_REQ_SOLICITED_EVENT_OFFSET];
assign NetReq_wqe_head = net_req_bus[`NET_REQ_HEAD_OFFSET];
assign NetReq_wqe_tail = net_req_bus[`NET_REQ_TAIL_OFFSET];
assign NetReq_inline = net_req_bus[`NET_REQ_INLINE_OFFSET];
assign NetReq_ori_wqe_addr = net_req_bus[`NET_REQ_WQE_ADDR_OFFSET];
assign NetReq_dmac = net_req_bus[`NET_REQ_DMAC_OFFSET];
assign NetReq_smac = net_req_bus[`NET_REQ_SMAC_OFFSET];
assign NetReq_dip = net_req_bus[`NET_REQ_DIP_OFFSET];
assign NetReq_sip = net_req_bus[`NET_REQ_SIP_OFFSET];
assign NetReq_cpl_event_addr = net_req_bus[`NET_REQ_CPL_EVENT_ADDR_OFFSET];
assign NetReq_immediate = net_req_bus[`NET_REQ_IMMEDIATE_OFFSET];
assign NetReq_lkey = net_req_bus[`NET_REQ_LKEY_OFFSET];
assign NetReq_laddr = net_req_bus[`NET_REQ_LADDR_OFFSET];
assign NetReq_rkey = net_req_bus[`NET_REQ_RKEY_OFFSET];
assign NetReq_raddr = net_req_bus[`NET_REQ_RADDR_OFFSET];
assign NetReq_msg_length = net_req_bus[`NET_REQ_MSG_LENGTH_OFFSET];
assign NetReq_packet_length = net_req_bus[`NET_REQ_PKT_LENGTH_OFFSET];
assign NetReq_payload_buffer_addr = net_req_bus[`NET_REQ_PAYLOAD_BUFFER_ADDR_OFFSET];

//-- NetReq_payload_buffer_addr_diff --
always @(posedge clk or posedge rst) begin
	if (rst) begin
		NetReq_payload_buffer_addr_diff <= 'd0;		
	end
	else if(cur_state == IDLE_s) begin
		NetReq_payload_buffer_addr_diff <= 'd0;
	end
	else if (cur_state == JUDGE_s) begin 		//Inline Payload Start Addr
		NetReq_payload_buffer_addr_diff <= NetReq_payload_buffer_addr;
	end
	else if(cur_state == PAYLOAD_INSERT_s && !net_data_empty && insert_req_valid && insert_req_start && insert_resp_valid) begin
		NetReq_payload_buffer_addr_diff <= insert_resp_data; 	//Non-Inline Payload Start Addr
	end
	else begin
		NetReq_payload_buffer_addr_diff <= NetReq_payload_buffer_addr_diff;
	end
end


//-- payload_piece_count --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		payload_piece_count <= 'd0;
	end
	else if(cur_state == JUDGE_s) begin
		payload_piece_count <= 'd1;
	end
	else if(cur_state == PAYLOAD_INSERT_s && insert_req_valid && insert_req_ready) begin
		payload_piece_count <= payload_piece_count + 'd1;
	end
	else if(cur_state == INJECT_s) begin
		payload_piece_count <= 'd0;
	end
	else begin
		payload_piece_count <= payload_piece_count;
	end
end

//-- payload_piece_total --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		payload_piece_total <= 'd0;
	end
	else if(cur_state == JUDGE_s) begin
		payload_piece_total <= NetReq_packet_length[5:0] ? (NetReq_packet_length >> 6) + 1 : NetReq_packet_length >> 6;
	end
	else if(cur_state == INJECT_s) begin
		payload_piece_total <= 'd0;
	end
	else begin
		payload_piece_total <= payload_piece_total;
	end
end

//-- net_req_ren --
assign net_req_ren = (cur_state == IDLE_s) ? !net_req_empty : 'd0;

//-- net_data_rd_en --
assign net_data_rd_en = (cur_state == PAYLOAD_INSERT_s) && !net_data_empty && insert_req_valid && insert_req_ready;

//-- enqueue_req_valid --
//-- enqueue_req_head --
//-- enqueue_req_data --
//-- enqueue_req_start --
//-- enqueue_req_last --
assign enqueue_req_valid = (cur_state == WQE_ENQUEUE_s) ? 'd1 : 'd0;
assign enqueue_req_head = (cur_state == WQE_ENQUEUE_s) ? {'d1, NetReq_local_qpn[`MAX_QP_NUM_LOG - 1 : 0]} : 'd0;
assign enqueue_req_data = (cur_state == WQE_ENQUEUE_s) ? {	NetReq_ori_wqe_addr, NetReq_msg_length, NetReq_laddr, NetReq_lkey, NetReq_packet_length, NetReq_dmac[15:0], 
															NetReq_service_type, NetReq_net_opcode, NetReq_remote_qpn, 3'd0, NetReq_verbs_opcode, NetReq_local_qpn} : 'd0;
assign enqueue_req_start = (cur_state == WQE_ENQUEUE_s) ? 'd1 : 'd0;
assign enqueue_req_last = (cur_state == WQE_ENQUEUE_s) ? 'd1 : 'd0;

//-- insert_req_valid --
//-- insert_req_start --
//-- insert_req_last --
//-- insert_req_head --
//-- insert_req_data --
assign insert_req_valid = (cur_state == PAYLOAD_INSERT_s && !net_data_empty) ? 'd1 : 'd0;
assign insert_req_start = (cur_state == PAYLOAD_INSERT_s && !net_data_empty) ? (payload_piece_count == 'd1) : 'd0;
assign insert_req_last = (cur_state == PAYLOAD_INSERT_s && !net_data_empty) ? (payload_piece_count == payload_piece_total) : 'd0;
assign insert_req_head = (cur_state == PAYLOAD_INSERT_s && insert_req_start && !net_data_empty) ? {NetReq_packet_length[5:0] ? (NetReq_packet_length >> 6) + 1 : NetReq_packet_length >> 6} : 'd0;
assign insert_req_data = (cur_state == PAYLOAD_INSERT_s) ? net_data_dout : 'd0;

//-- scatter_data_wen --
//-- scatter_data_din --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		scatter_req_wen <= 'd0;
		scatter_req_din <= 'd0;

		scatter_data_wen <= 'd0;
		scatter_data_din <= 'd0;
	end
	else if(cur_state == GEN_CQE_s && !scatter_req_prog_full && !scatter_data_prog_full) begin
		scatter_req_wen <= 'd1;
		scatter_req_din <= {`CQE_LENGTH, `CQE_LENGTH, NetReq_cpl_event_addr};

		scatter_data_wen <= 'd1;
		scatter_data_din <= cqe_data;
	end
	else if(cur_state == GEN_EVENT_s && !scatter_req_prog_full && !scatter_data_prog_full) begin
		scatter_req_wen <= 'd0;
		scatter_req_din <='d0;

		scatter_data_wen <= 'd0;
		scatter_data_din <= 'd0;
	end
	else begin
		scatter_req_wen <= 'd0;
		scatter_req_din <='d0;

		scatter_data_wen <= 'd0;
		scatter_data_din <= 'd0;
	end
end

//-- egress_pkt_valid --
//-- egress_pkt_head --
assign egress_pkt_valid = (cur_state == INJECT_s) ? 'd1 : 'd0;
assign egress_pkt_head = (cur_state == INJECT_s) ? {	'd0, NetReq_packet_length, NetReq_payload_buffer_addr_diff, NetReq_sip, NetReq_dip, NetReq_smac, NetReq_dmac,
													 	NetReq_immediate, NetReq_raddr, NetReq_rkey, 8'd0, NetReq_remote_qpn, NetReq_service_type, 
													 	NetReq_net_opcode, NetReq_local_qpn} : 'd0;
/********************************************** CQE Field Gen : Begin ******************************************************/
//-- cqe_my_qpn --
//-- cqe_my_ee --
//-- cqe_rqpn --
//-- cqe_sl_ipok --
//-- cqe_g_mlpath --
//-- cqe_rlid --
//-- cqe_imm_etype_pkey_eec --
//-- cqe_byte_cnt --
//-- cqe_wqe --
//-- cqe_opcode --
//-- cqe_is_send --
//-- cqe_owner --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		cqe_my_qpn <= 'd0;
		cqe_my_ee <= 'd0;
		cqe_rqpn <= 'd0;
		cqe_sl_ipok <= 'd0;
		cqe_g_mlpath <= 'd0;
		cqe_rlid <= 'd0;
		cqe_imm_etype_pkey_eec <= 'd0;
		cqe_byte_cnt <= 'd0;
		cqe_wqe <= 'd0;
		cqe_opcode <= 'd0;
		cqe_is_send <= 'd0;
		cqe_owner <= 'd0;		
	end
	else if(cur_state == JUDGE_s && next_state == GEN_CQE_s) begin
		cqe_my_qpn <= net_req_bus[`NET_REQ_LOCAL_QPN_OFFSET];
		cqe_my_ee <= 'd0;
		cqe_rqpn <= net_req_bus[`NET_REQ_REMOTE_QPN_OFFSET];
		cqe_sl_ipok <= 'd0;
		cqe_g_mlpath <= 'd0;
		cqe_rlid <= net_req_bus[`NET_REQ_DMAC_OFFSET];
		cqe_imm_etype_pkey_eec <= 'd0;
		cqe_byte_cnt <= net_req_bus[`NET_REQ_MSG_LENGTH_OFFSET];
		cqe_wqe <= net_req_bus[`NET_REQ_WQE_ADDR_OFFSET];
		cqe_opcode <= net_req_bus[`NET_REQ_VERBS_OPCODE_OFFSET];
		cqe_is_send <= 'd1;
		cqe_owner <= `HGHCA_CQ_ENTRY_OWNER_HW;		
	end
	else begin
		cqe_my_qpn <= cqe_my_qpn;
		cqe_my_ee <= cqe_my_ee;
		cqe_rqpn <= cqe_rqpn;
		cqe_sl_ipok <= cqe_sl_ipok;
		cqe_g_mlpath <= cqe_g_mlpath;
		cqe_rlid <= cqe_rlid;
		cqe_imm_etype_pkey_eec <= cqe_imm_etype_pkey_eec;
		cqe_byte_cnt <= cqe_byte_cnt;
		cqe_wqe <= cqe_wqe;
		cqe_opcode <= cqe_opcode;
		cqe_is_send <= cqe_is_send;
		cqe_owner <= cqe_owner;
	end
end

//-- cqe_data --
assign cqe_data = (cur_state == GEN_CQE_s) ? { 	cqe_owner, 8'd0, cqe_is_send, cqe_opcode, cqe_wqe, cqe_byte_cnt, cqe_imm_etype_pkey_eec,
												cqe_rlid, cqe_g_mlpath, cqe_sl_ipok, cqe_rqpn, cqe_my_ee, cqe_my_qpn} : 'd0;

/********************************************** CQE Field Gen : End ********************************************************/

/*------------------------------------------- Variables Decode : End ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule