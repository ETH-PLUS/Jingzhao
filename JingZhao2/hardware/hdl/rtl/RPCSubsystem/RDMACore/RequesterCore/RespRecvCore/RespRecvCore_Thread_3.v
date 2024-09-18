/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       RespRecvCore_Thread_3
Author:     YangFan
Function:   1.Scatter RDMA Read Response data.
			2.Generate Completion, Event and Interrupt.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module RespRecvCore_Thread_3
#(
    parameter                       EGRESS_MR_HEAD_WIDTH                    =   128,
    parameter                       EGRESS_MR_DATA_WIDTH                    =   256
)
(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with OoOStation(For MRMgt)
    input  	wire                                                        fetch_mr_egress_valid,
    input  	wire    [`RX_RESP_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]         fetch_mr_egress_head,
    input  	wire    [`RX_RESP_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]         fetch_mr_egress_data,
    input  	wire                                                        fetch_mr_egress_start,
    input  	wire                                                        fetch_mr_egress_last,
    output  wire                                                        fetch_mr_egress_ready,

//ScatterData Req Interface
	output 	reg 	                                                   		scatter_req_wen,
	output 	reg 	[`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]       scatter_req_din,
	input 	wire 	                                                    	scatter_req_prog_full,

	output 	reg 	                                                   		scatter_data_wen,
	output 	reg 	[`DMA_DATA_WIDTH - 1 : 0]                               scatter_data_din,
	input 	wire 	                                                    	scatter_data_prog_full,

//Interface with PacketBuffer
	//Interface with Packet Buffer
    output  wire                                                            delete_req_valid,
    output  wire    [`MAX_DB_SLOT_NUM_LOG * 2 - 1 : 0]                 		delete_req_head,
    input   wire                                                            delete_req_ready,
                    
    input   wire                                                            delete_resp_valid,
    input   wire                                                            delete_resp_start,
    input   wire                                                            delete_resp_last,
    input   wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     delete_resp_data,
    output  wire                                                            delete_resp_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define 			META_BUS_LOCAL_QPN_OFFSET					 	23:0			
`define 			META_BUS_VERBS_OPCODE_OFFSET					28:24
`define 			META_BUS_REMOTE_QPN_OFFSET						55:32
`define 			META_BUS_NET_OPCODE_OFFSET						60:56
`define 			META_BUS_MSG_LENGTH_OFFSET 						95:64
`define 			META_BUS_PKT_LENGTH_OFFSET						111:96
`define 			META_BUS_DLID_OFFSET 							127:112
`define 			META_BUS_ORI_WQE_ADDR_OFFSET 					159:128
`define 			META_BUS_PKT_START_ADDR_OFFSET 					175:160

/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg                 [`MR_RESP_WIDTH - 1 : 0]                        mr_resp_bus;
reg                 [`PKT_META_BUS_WIDTH - 1 : 0]                   meta_bus;

wire 				[23:0] 											meta_local_qpn;
wire 				[23:0]											meta_remote_qpn;
wire 				[4:0]											meta_verbs_opcode;
wire 				[4:0]											meta_net_opcode;
wire 				[31:0]											meta_msg_length;
wire 				[15:0]											meta_pkt_length;
wire 				[15:0]											meta_dlid;
wire 				[31:0]											meta_wqe_addr;
wire 				[15:0]											meta_pkt_start_addr;

wire                [3:0]                                           mr_resp_state;
wire                [3:0]                                           mr_resp_valid_0;
wire                [3:0]                                           mr_resp_valid_1;
wire                [31:0]                                          mr_resp_size_0;
wire                [31:0]                                          mr_resp_size_1;
wire                [63:0]                                          mr_resp_phy_addr_0;
wire                [63:0]                                          mr_resp_phy_addr_1;

wire 				[255:0]											cqe_data;
reg 				[31:0]											cqe_my_qpn;
reg 				[31:0]											cqe_my_ee;
reg 				[31:0]											cqe_rqpn;
reg 				[7:0]											cqe_sl_ipok;
reg 				[7:0]											cqe_g_mlpath;
reg 				[15:0]											cqe_rlid;
reg 				[31:0]											cqe_imm_etype_pkey_eec;
reg 				[31:0]											cqe_byte_cnt;
reg 				[31:0]											cqe_wqe;
reg 				[7:0]											cqe_opcode;
reg 				[7:0]											cqe_is_send;
reg 				[7:0]											cqe_owner;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg  				[3:0]						cur_state;
reg 				[3:0]						next_state;

parameter 			[3:0]						IDLE_s 						=	4'd1,
												JUDGE_s 					=	4'd2,
												GET_PAYLOAD_s 				= 	4'd3,
												DMA_PAYLOAD_PAGE_0_REQ_s 	= 	4'd4,
												DMA_PAYLOAD_PAGE_1_REQ_s 	= 	4'd5,
												DMA_PAYLOAD_DATA_s 			= 	4'd6,
												DMA_CQE_s 					= 	4'd7,
												DMA_EVENT_s 				= 	4'd8,
												DMA_INT_s 					= 	4'd9;

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
		IDLE_s:						if(fetch_mr_egress_valid) begin
										next_state = JUDGE_s;
									end
									else begin
										next_state = IDLE_s;
									end
		JUDGE_s:					if(meta_net_opcode == `RDMA_READ_REQUEST_FIRST || meta_net_opcode == `RDMA_READ_REQUEST_MIDDLE || meta_net_opcode == `RDMA_READ_REQUEST_LAST ||
										meta_net_opcode == `RDMA_READ_REQUEST_ONLY) begin
										next_state = GET_PAYLOAD_s;		
									end
									else if(meta_net_opcode == `GEN_CQE) begin
										next_state = DMA_CQE_s;
									end
									else if(meta_net_opcode == `GEN_EVENT) begin
										next_state = DMA_EVENT_s;
									end
									else begin
										next_state = IDLE_s;
									end
		GET_PAYLOAD_s:				if(delete_req_valid && delete_req_ready) begin
										next_state = DMA_PAYLOAD_PAGE_0_REQ_s;
									end
									else begin
										next_state = GET_PAYLOAD_s;
									end
		DMA_PAYLOAD_PAGE_0_REQ_s:	if(!scatter_req_prog_full) begin
										if(mr_resp_valid_1) begin
											next_state = DMA_PAYLOAD_PAGE_1_REQ_s;
										end
										else begin
											next_state = DMA_PAYLOAD_DATA_s;
										end
									end
									else begin
										next_state = DMA_PAYLOAD_PAGE_0_REQ_s;
									end
		DMA_PAYLOAD_PAGE_1_REQ_s:	if(!scatter_req_prog_full) begin
										next_state = DMA_PAYLOAD_DATA_s;
									end
									else begin
										next_state = DMA_PAYLOAD_PAGE_1_REQ_s;
									end
		DMA_PAYLOAD_DATA_s:			if(delete_resp_last && !scatter_data_prog_full) begin
										next_state = IDLE_s;
									end
									else begin
										next_state = DMA_PAYLOAD_DATA_s;
									end
		DMA_CQE_s:					if(!scatter_req_prog_full && !scatter_data_prog_full) begin
										next_state = IDLE_s;
									end
									else begin
										next_state = DMA_CQE_s;
									end
		DMA_EVENT_s:				if(!scatter_req_prog_full && !scatter_data_prog_full) begin
										next_state = DMA_INT_s;
									end
									else begin
										next_state = DMA_EVENT_s;
									end
		DMA_INT_s:					if(!scatter_req_prog_full && !scatter_data_prog_full) begin
										next_state = IDLE_s;
									end
									else begin
										next_state = DMA_INT_s;
									end
		default:					next_state = IDLE_s;
	endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- meta_bus --
//-- mr_resp_bus --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        meta_bus <= 'd0;
        mr_resp_bus <= 'd0;     
    end
    else if (cur_state == IDLE_s && fetch_mr_egress_valid) begin
        meta_bus <= fetch_mr_egress_data;
        mr_resp_bus <= fetch_mr_egress_head[`MR_RESP_WIDTH + `EGRESS_COMMON_HEAD_WIDTH - 1 : `EGRESS_COMMON_HEAD_WIDTH];
    end
    else begin
        meta_bus <= meta_bus;
        mr_resp_bus <= mr_resp_bus;
    end
end

//-- meta_local_qpn --
//-- meta_remote_qpn --
//-- meta_verbs_opcode --
//-- meta_net_opcode --
//-- meta_msg_length --
//-- meta_pkt_length --
//-- meta_dlid --
//-- meta_wqe_addr --
//-- meta_pkt_start_addr --
assign meta_local_qpn = meta_bus[`META_BUS_LOCAL_QPN_OFFSET];
assign meta_remote_qpn = meta_bus[`META_BUS_REMOTE_QPN_OFFSET];
assign meta_verbs_opcode = meta_bus[`META_BUS_VERBS_OPCODE_OFFSET];
assign meta_net_opcode = meta_bus[`META_BUS_NET_OPCODE_OFFSET];
assign meta_msg_length = meta_bus[`META_BUS_MSG_LENGTH_OFFSET];
assign meta_pkt_length = meta_bus[`META_BUS_PKT_LENGTH_OFFSET];
assign meta_dlid = meta_bus[`META_BUS_DLID_OFFSET];
assign meta_wqe_addr = meta_bus[`META_BUS_ORI_WQE_ADDR_OFFSET];
assign meta_pkt_start_addr = meta_bus[`META_BUS_PKT_START_ADDR_OFFSET];

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

//-- fetch_mr_egress_ready --
assign fetch_mr_egress_ready = (cur_state == IDLE_s) ? 'd1 : 'd0;

//-- scatter_req_wen --
//-- scatter_req_din --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		scatter_req_wen <= 'd0;
		scatter_req_din <= 'd0;
	end
	else if(cur_state == IDLE_s) begin
		scatter_req_wen <= 'd0;
		scatter_req_din <= 'd0;
	end
	else if(cur_state == DMA_PAYLOAD_PAGE_0_REQ_s && !scatter_req_prog_full) begin
		scatter_req_wen <= 'd1;
		scatter_req_din <= {meta_pkt_length, mr_resp_size_0, mr_resp_phy_addr_0};
	end
	else if(cur_state == DMA_PAYLOAD_PAGE_1_REQ_s && !scatter_req_prog_full) begin
		scatter_req_wen <= 'd1;
		scatter_req_din <= {meta_pkt_length, mr_resp_size_1, mr_resp_phy_addr_1};
	end
	else if(cur_state == DMA_CQE_s && !scatter_req_prog_full && !scatter_req_prog_full) begin
		scatter_req_wen <= 'd1;
		scatter_req_din <= {`CQE_LENGTH, `CQE_LENGTH, mr_resp_phy_addr_0};
	end 
	else if(cur_state == DMA_EVENT_s && !scatter_req_prog_full && !scatter_req_prog_full) begin
		scatter_req_wen <= 'd0; 	//TODO
		scatter_req_din <= 'd0;
	end
	else if(cur_state == DMA_INT_s && !scatter_req_prog_full && !scatter_req_prog_full) begin
		scatter_req_wen <= 'd0;
		scatter_req_din <= 'd0;
	end
	else begin
		scatter_req_wen <= 'd0;
		scatter_req_din <= 'd0;
	end
end

//-- scatter_data_wen --
//-- scatter_data_din --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		scatter_data_wen <= 'd0;
		scatter_data_din <= 'd0;
	end
	else if(cur_state == DMA_PAYLOAD_DATA_s && !scatter_data_prog_full && delete_resp_valid) begin
		scatter_data_wen <= 'd1;
		scatter_data_din <= delete_resp_data;
	end
	else if(cur_state == DMA_CQE_s && !scatter_req_prog_full && !scatter_data_prog_full) begin
		scatter_data_wen <= 'd1;
		scatter_data_din <= cqe_data;
	end
	else if(cur_state == DMA_EVENT_s && !scatter_req_prog_full && !scatter_data_prog_full) begin
		scatter_data_wen <= 'd0; 	//TODO
		scatter_data_din <= 'd0;
	end
	else if(cur_state == DMA_INT_s && !scatter_req_prog_full && !scatter_data_prog_full) begin
		scatter_data_wen <= 'd0; 	//TODO
		scatter_data_din <= 'd0;		
	end
	else begin
		scatter_data_wen <= 'd0;
		scatter_data_din <= 'd0;
	end
end

//-- delete_req_valid --
//-- delete_req_head --
assign delete_req_valid = (cur_state == GET_PAYLOAD_s) ? 'd1 : 'd0;
assign delete_req_head = (cur_state == GET_PAYLOAD_s) ? {(meta_pkt_length[5:0] ? (meta_pkt_length >> 6) + 1 : meta_pkt_length >> 6), meta_pkt_start_addr} : 'd0;

//-- delete_resp_ready --
assign delete_resp_ready = (cur_state == DMA_PAYLOAD_DATA_s && !scatter_data_prog_full) ? 'd1 : 'd0;

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
	else if(cur_state == JUDGE_s && next_state == DMA_CQE_s) begin
		cqe_my_qpn <= meta_local_qpn;
		cqe_my_ee <= 'd0;
		cqe_rqpn <= meta_remote_qpn;
		cqe_sl_ipok <= 'd0;
		cqe_g_mlpath <= 'd0;
		cqe_rlid <= meta_dlid;
		cqe_imm_etype_pkey_eec <= 'd0;
		cqe_byte_cnt <= meta_msg_length;
		cqe_wqe <= meta_wqe_addr;
		cqe_opcode <= meta_verbs_opcode;
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
assign cqe_data = (cur_state == DMA_CQE_s) ? { 	cqe_owner, 8'd0, cqe_is_send, cqe_opcode, cqe_wqe, cqe_byte_cnt, cqe_imm_etype_pkey_eec,
												cqe_rlid, cqe_g_mlpath, cqe_sl_ipok, cqe_rqpn, cqe_my_ee, cqe_my_qpn} : 'd0;
/********************************************** CQE Field Gen : End ********************************************************/

/*------------------------------------------- Variables Decode : End ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule