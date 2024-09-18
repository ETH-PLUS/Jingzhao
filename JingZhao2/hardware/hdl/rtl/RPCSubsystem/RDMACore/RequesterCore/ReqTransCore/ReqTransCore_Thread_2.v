/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ReqTransCore_Thread_2
Author:     YangFan
Function:   1.Parse Sub-WQE and generate MR request.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module ReqTransCore_Thread_2
#(
    parameter                       EGRESS_CXT_HEAD_WIDTH                   =   128,
    parameter                       EGRESS_CXT_DATA_WIDTH                   =   256,


    parameter                       INGRESS_MR_HEAD_WIDTH                   =   128,
    parameter                       INGRESS_MR_DATA_WIDTH                   =   256
)
(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with OoOStation(For CxtMgt)
    input  	wire                                                            fetch_cxt_egress_valid,
    input  	wire    [`TX_REQ_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]             fetch_cxt_egress_head,
    input  	wire    [`TX_REQ_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]             fetch_cxt_egress_data,
    input  	wire                                                            fetch_cxt_egress_start,
    input  	wire                                                            fetch_cxt_egress_last,
    output  wire                                                            fetch_cxt_egress_ready,

//Interface with OoOStation(For MRMgt)
	output 	wire                                                            fetch_mr_ingress_valid,
	output 	wire    [`TX_REQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]             fetch_mr_ingress_head,
	output 	wire    [`TX_REQ_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]             fetch_mr_ingress_data,
	output 	wire                                                            fetch_mr_ingress_start,
	output 	wire                                                            fetch_mr_ingress_last,
	input 	wire                                                            fetch_mr_ingress_ready,

//Interface with CompletionQueueMgt
	output 	wire 												    		cq_req_valid,
	output 	wire 	[`CQ_REQ_HEAD_WIDTH - 1 : 0]				    		cq_req_head,
	input 	wire 												    		cq_req_ready,
     
	input 	wire 												    		cq_resp_valid,
	input 	wire 	[`CQ_RESP_HEAD_WIDTH - 1 : 0]				    		cq_resp_head,
	output 	wire 												    		cq_resp_ready,

//Interface with EventQueueMgt
	output 	wire 												    		eq_req_valid,
	output 	wire 	[`EQ_REQ_HEAD_WIDTH - 1 : 0]				    		eq_req_head,
	input 	wire 												    		eq_req_ready,
 
	input 	wire 												    		eq_resp_valid,
	input 	wire 	[`EQ_RESP_HEAD_WIDTH - 1 : 0]				    		eq_resp_head,
	output 	wire 												    		eq_resp_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define 	SUB_WQE_LOCAL_QPN_OFFSET					23:0
`define 	SUB_WQE_VERBS_OPCODE_OFFSET 				28:24
`define 	SUB_WQE_REMOTE_QPN_OFFSET					55:32
`define 	SUB_WQE_NET_OPCODE_OFFSET 					60:56
`define 	SUB_WQE_SERVICE_TYPE_OFFSET					63:61
`define 	SUB_WQE_FENCE_OFFSET						64
`define		SUB_WQE_SOLICITED_EVENT_OFFSET 			 	65
`define 	SUB_WQE_HEAD_OFFSET	 						66
`define 	SUB_WQE_TAIL_OFFSET 						67
`define 	SUB_WQE_INLINE_OFFSET						68
`define 	SUB_WQE_WQE_OFFSET 							95:72
`define 	SUB_WQE_DMAC_OFFSET 						143:96
`define 	SUB_WQE_SMAC_OFFSET 						191:144
`define 	SUB_WQE_DIP_OFFSET 							223:192
`define 	SUB_WQE_SIP_OFFSET 							255:224
`define 	SUB_WQE_IMMEDIATE_OFFSET 					287:256
`define 	SUB_WQE_LKEY_OFFSET 						319:288
`define 	SUB_WQE_LADDR_OFFSET 						383:320
`define		SUB_WQE_RKEY_OFFSET 						415:384
`define 	SUB_WQE_RADDR_OFFSET 						479:416
`define 	SUB_WQE_MSG_LENGTH_OFFSET 					511:480
`define 	SUB_WQE_PKT_LENGTH_OFFSET 					527:512
`define 	SUB_WQE_PAYLOAD_BUFFER_ADDR_OFFSET 			575:544
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg 				[`QP_CONTEXT_BIT_SIZE + `CQ_CONTEXT_BIT_SIZE + `EQ_CONTEXT_BIT_SIZE - 1 : 0]			cxt_bus;
reg 				[`WQE_META_WIDTH - 1 : 0]																wqe_bus;

wire            	[`INGRESS_COMMON_HEAD_WIDTH - 1 : 0]            ingress_common_head;
wire            	[`MAX_OOO_SLOT_NUM_LOG - 1 :0]                                          ingress_slot_count;

wire             	[23:0]                          SubWQE_local_qpn;
wire             	[4:0]                           SubWQE_verbs_opcode;
wire             	[23:0]                          SubWQE_remote_qpn;
wire             	[4:0]                           SubWQE_net_opcode;
wire             	[2:0]                           SubWQE_service_type;
wire             	[0:0]                           SubWQE_fence;
wire             	[0:0]                           SubWQE_solicted_event;
wire             	[0:0]                           SubWQE_wqe_head;
wire             	[0:0]                           SubWQE_wqe_tail;
wire             	[0:0]                           SubWQE_inline;
wire             	[23:0]                          SubWQE_ori_wqe_offset;
wire             	[47:0]                          SubWQE_dmac;
wire             	[47:0]                          SubWQE_smac;
wire             	[31:0]                          SubWQE_dip;
wire             	[31:0]                          SubWQE_sip;
wire             	[31:0]                          SubWQE_immediate;
wire             	[31:0]                          SubWQE_lkey;
wire             	[63:0]                          SubWQE_laddr;
wire             	[31:0]                          SubWQE_rkey;
wire             	[63:0]                          SubWQE_raddr;
wire             	[31:0]                          SubWQE_msg_length;
wire             	[15:0]                          SubWQE_packet_length;
wire 				[31:0]							SubWQE_payload_buffer_addr;

reg 				[0:0]							need_cpl;
reg 				[0:0]							need_event;

wire 				[0:0]							is_inline;
wire 				[0:0]							is_rdma_read;

wire            	[31:0]                          mr_length;
wire            	[63:0]                          mr_laddr;
wire            	[31:0]                          mr_lkey;
wire            	[31:0]                          mr_pd;

wire             	[31:0]                          mr_flags;
reg             	[3:0]                           mr_flag_sw_owns;
reg                 								mr_flag_absolute_addr;
reg                 								mr_flag_relative_addr;
reg                 								mr_flag_mio;
reg                 								mr_flag_bind_enable;
reg                 								mr_flag_physical;
reg                 								mr_flag_region;
reg                 								mr_flag_on_demand;
reg                 								mr_flag_zero_based;
reg                 								mr_flag_mw_bind;
reg                 								mr_flag_remote_read;
reg                 								mr_flag_remote_write;
reg                 								mr_flag_local_write;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg 				[3:0]					cur_state;
reg 				[3:0]					next_state;

parameter 			[3:0]					IDLE_s 			= 	4'd1,
											JUDGE_s 		=	4'd2,
											BYPASS_s 		= 	4'd3,
											FETCH_DATA_MR_s = 	4'd4,
											CQ_REQ_s 		= 	4'd5,
											CQ_RESP_s 		= 	4'd6,
											FETCH_CQ_MR_s 	= 	4'd7,
											FETCH_EQ_MR_s 	= 	4'd8,
											EQ_REQ_s 		= 	4'd9,
											EQ_RESP_s 		= 	4'd10;

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
		IDLE_s:				if(fetch_cxt_egress_start) begin
								next_state = JUDGE_s;
							end
							else begin
								next_state = IDLE_s;
							end
		JUDGE_s:			if(is_inline || is_rdma_read) begin 		//No need to fetch data mr
								next_state = BYPASS_s;
							end
							else begin
								next_state = FETCH_DATA_MR_s;
							end
		BYPASS_s:			if(fetch_mr_ingress_valid && fetch_mr_ingress_ready) begin
								if(is_rdma_read) begin
									next_state = IDLE_s;
								end
								else if(is_inline) begin
									next_state = CQ_REQ_s;
								end
								else begin
									next_state = IDLE_s;
								end
							end
							else begin
								next_state = BYPASS_s;
							end
		FETCH_DATA_MR_s:	if(fetch_mr_ingress_valid && fetch_mr_ingress_ready) begin
								if(need_cpl) begin
									next_state = CQ_REQ_s;
								end
								else begin
									next_state = IDLE_s;
								end
							end
							else begin
								next_state = FETCH_DATA_MR_s;
							end
		CQ_REQ_s:			if(cq_req_valid && cq_req_ready) begin
								next_state = CQ_RESP_s;
							end
							else begin
								next_state = CQ_REQ_s;
							end
		CQ_RESP_s:			if(cq_resp_valid && cq_resp_ready) begin
								next_state = FETCH_CQ_MR_s;
							end
							else begin
								next_state = CQ_RESP_s;
							end
		FETCH_CQ_MR_s:		if(fetch_mr_ingress_valid && fetch_mr_ingress_ready) begin
								if(need_event) begin
									next_state = EQ_REQ_s;
								end
								else begin
									next_state = IDLE_s;
								end
							end
							else begin
								next_state = FETCH_CQ_MR_s;
							end
		EQ_REQ_s:			if(eq_req_valid && eq_req_ready) begin
								next_state = EQ_RESP_s;
							end
							else begin
								next_state = EQ_REQ_s;
							end
		EQ_RESP_s:			if(eq_resp_valid && eq_resp_ready) begin
								next_state = FETCH_EQ_MR_s;
							end
							else begin
								next_state = EQ_RESP_s;
							end
		FETCH_EQ_MR_s:		if(fetch_mr_ingress_valid && fetch_mr_ingress_ready) begin
								next_state = IDLE_s;
							end
							else begin
								next_state = FETCH_EQ_MR_s;
							end
		default:			next_state = IDLE_s;
	endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- cxt_bus --
//-- wqe_bus --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		cxt_bus <= 'd0;
		wqe_bus <= 'd0;
	end
	else if(cur_state == IDLE_s && fetch_cxt_egress_valid) begin
		cxt_bus <= fetch_cxt_egress_head[`QP_CONTEXT_BIT_SIZE + `CQ_CONTEXT_BIT_SIZE + `EQ_CONTEXT_BIT_SIZE + `INGRESS_COMMON_HEAD_WIDTH - 1 : `EGRESS_COMMON_HEAD_WIDTH];
		wqe_bus <= fetch_cxt_egress_data;
	end
	else begin
		cxt_bus <= cxt_bus;
		wqe_bus <= wqe_bus;
	end
end

//-- SubWQE_local_qpn --
//-- SubWQE_remote_qpn --
//-- SubWQE_verbs_opcode --
//-- SubWQE_net_opcode --
//-- SubWQE_service_type --
//-- SubWQE_fence --
//-- SubWQE_solicted_event --
//-- SubWQE_wqe_head --
//-- SubWQE_wqe_tail --
//-- SubWQE_inline --
//-- SubWQE_ori_wqe_offset --
//-- SubWQE_dmac --
//-- SubWQE_smac --
//-- SubWQE_dip --
//-- SubWQE_sip --
//-- SubWQE_immediate --
//-- SubWQE_lkey --
//-- SubWQE_laddr --
//-- SubWQE_rkey --
//-- SubWQE_raddr --
//-- SubWQE_msg_length --
//-- SubWQE_packet_length --
//-- SubWQE_payload_buffer_addr --
assign SubWQE_local_qpn = wqe_bus[`SUB_WQE_LOCAL_QPN_OFFSET];
assign SubWQE_verbs_opcode = wqe_bus[`SUB_WQE_VERBS_OPCODE_OFFSET];
assign SubWQE_remote_qpn = wqe_bus[`SUB_WQE_REMOTE_QPN_OFFSET];
assign SubWQE_net_opcode = wqe_bus[`SUB_WQE_NET_OPCODE_OFFSET];
assign SubWQE_service_type = wqe_bus[`SUB_WQE_SERVICE_TYPE_OFFSET];
assign SubWQE_fence = wqe_bus[`SUB_WQE_FENCE_OFFSET];
assign SubWQE_solicted_event = wqe_bus[`SUB_WQE_SOLICITED_EVENT_OFFSET];
assign SubWQE_wqe_head = wqe_bus[`SUB_WQE_HEAD_OFFSET];
assign SubWQE_wqe_tail = wqe_bus[`SUB_WQE_TAIL_OFFSET];
assign SubWQE_inline = wqe_bus[`SUB_WQE_INLINE_OFFSET];
assign SubWQE_ori_wqe_offset = wqe_bus[`SUB_WQE_WQE_OFFSET];
assign SubWQE_dmac = wqe_bus[`SUB_WQE_DMAC_OFFSET];
assign SubWQE_smac = wqe_bus[`SUB_WQE_SMAC_OFFSET];
assign SubWQE_dip = wqe_bus[`SUB_WQE_DIP_OFFSET];
assign SubWQE_sip = wqe_bus[`SUB_WQE_SIP_OFFSET];
assign SubWQE_immediate = wqe_bus[`SUB_WQE_IMMEDIATE_OFFSET];
assign SubWQE_lkey = wqe_bus[`SUB_WQE_LKEY_OFFSET];
assign SubWQE_laddr = wqe_bus[`SUB_WQE_LADDR_OFFSET];
assign SubWQE_rkey = wqe_bus[`SUB_WQE_RKEY_OFFSET];
assign SubWQE_raddr = wqe_bus[`SUB_WQE_RADDR_OFFSET];
assign SubWQE_msg_length = wqe_bus[`SUB_WQE_MSG_LENGTH_OFFSET];
assign SubWQE_packet_length = wqe_bus[`SUB_WQE_PKT_LENGTH_OFFSET];
assign SubWQE_payload_buffer_addr = wqe_bus[`SUB_WQE_PAYLOAD_BUFFER_ADDR_OFFSET];

//-- is_inline --
assign is_inline = SubWQE_inline;

//-- is_rdma_read --
assign is_rdma_read = (SubWQE_net_opcode == `RDMA_READ_REQUEST_FIRST || SubWQE_net_opcode == `RDMA_READ_REQUEST_MIDDLE || 
						SubWQE_net_opcode == `RDMA_READ_REQUEST_LAST || SubWQE_net_opcode == `RDMA_READ_REQUEST_ONLY);

//-- need_cpl --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		need_cpl <= 'd0;
	end
	else if(cur_state == IDLE_s && !fetch_cxt_egress_valid) begin
		need_cpl <= 'd0;
	end
	else if(cur_state == IDLE_s && fetch_cxt_egress_valid) begin
		need_cpl <= ( SubWQE_service_type == `UC || SubWQE_service_type == `UD) && 
					( SubWQE_net_opcode == `SEND_LAST || SubWQE_net_opcode == `SEND_LAST_WITH_IMM || SubWQE_net_opcode == `SEND_ONLY || SubWQE_net_opcode == `SEND_ONLY_WITH_IMM ||
					  SubWQE_net_opcode == `RDMA_WRITE_LAST || SubWQE_net_opcode == `RDMA_WRITE_LAST_WITH_IMM || SubWQE_net_opcode == `RDMA_WRITE_ONLY || SubWQE_net_opcode == `RDMA_WRITE_ONLY_WITH_IMM);
	end
	else begin
		need_cpl <= need_cpl;
	end
end

//-- need_event --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		need_event <= 'd0;
	end
	else if(cur_state == IDLE_s && fetch_cxt_egress_valid) begin 	//TODO, generate Event.
		need_event <= 'd0; 
	end
	else begin
		need_event <= need_event;
	end
end

//-- fetch_cxt_egress_ready --
assign fetch_cxt_egress_ready = (cur_state == IDLE_s) ? 'd1 : 'd0;

//-- fetch_mr_ingress_valid --
assign fetch_mr_ingress_valid = (cur_state == BYPASS_s) ? 'd1 :
								(cur_state == FETCH_DATA_MR_s) ? 'd1 : 
								(cur_state == FETCH_CQ_MR_s) ? 'd1 :
								(cur_state == FETCH_EQ_MR_s) ? 'd1 : 'd0;

wire        [`MAX_QP_NUM_LOG - 1 : 0]               queue_index;
assign queue_index = {'d0, SubWQE_local_qpn[`QP_NUM_LOG - 1 : 0]};

//-- ingress_slot_count --
//-- ingress_common_head --
assign ingress_slot_count = (cur_state == BYPASS_s) ? 'd1 :
							 (cur_state == FETCH_DATA_MR_s) ? 'd1 : 
							 (cur_state == FETCH_CQ_MR_s) ? 'd1 :
							 (cur_state == FETCH_EQ_MR_s) ? 'd1 : 'd0;

assign ingress_common_head = (cur_state == BYPASS_s) ? {`BYPASS_MODE, ingress_slot_count, queue_index} : 	//inline or rdma_read does not need MT translation
							 (cur_state == FETCH_DATA_MR_s) ? {`NO_BYPASS, ingress_slot_count, queue_index} : 
							 (cur_state == FETCH_CQ_MR_s) ? {`NO_BYPASS, ingress_slot_count, queue_index} :
							 (cur_state == FETCH_EQ_MR_s) ? {`NO_BYPASS, ingress_slot_count, queue_index} : 'd0;



//-- fetch_mr_ingress_head --
assign fetch_mr_ingress_head = (cur_state == BYPASS_s) ? {'d0, ingress_common_head} : 
							   (cur_state == FETCH_DATA_MR_s) ? {mr_length, mr_laddr, mr_lkey, mr_pd, mr_flags, ingress_common_head} :
							   (cur_state == FETCH_CQ_MR_s) ? {mr_length, mr_laddr, mr_lkey, mr_pd, mr_flags, ingress_common_head} :
							   (cur_state == FETCH_EQ_MR_s) ? {mr_length, mr_laddr, mr_lkey, mr_pd, mr_flags, ingress_common_head} : 'd0;


//-- fetch_mr_ingress_data --
assign fetch_mr_ingress_data = {SubWQE_payload_buffer_addr, 16'd0, SubWQE_packet_length, SubWQE_msg_length,
                                SubWQE_raddr, SubWQE_rkey, SubWQE_laddr, SubWQE_lkey, SubWQE_immediate,
                                SubWQE_sip, SubWQE_dip, SubWQE_smac, SubWQE_dmac, SubWQE_ori_wqe_offset, 3'd0, SubWQE_inline,
                                SubWQE_wqe_tail, SubWQE_wqe_head, 1'b0, SubWQE_fence, SubWQE_service_type,
                                (	cur_state == BYPASS_s ? SubWQE_net_opcode :
                                	cur_state == FETCH_DATA_MR_s ? SubWQE_net_opcode :
                                 cur_state == FETCH_CQ_MR_s ? `GEN_CQE :
                                 cur_state == FETCH_EQ_MR_s ? `GEN_EVENT : 5'd0),
                                SubWQE_remote_qpn, 3'd0, SubWQE_verbs_opcode, SubWQE_local_qpn};

//-- fetch_mr_ingress_start --
assign fetch_mr_ingress_start = (cur_state == BYPASS_s) ? 'd1 :
								(cur_state == FETCH_DATA_MR_s) ? 'd1 : 
								(cur_state == FETCH_CQ_MR_s) ? 'd1 :
								(cur_state == FETCH_EQ_MR_s) ? 'd1 : 'd0;

//-- fetch_mr_ingress_last --
assign fetch_mr_ingress_last =  (cur_state == BYPASS_s) ? 'd1 :
								(cur_state == FETCH_DATA_MR_s) ? 'd1 : 
								(cur_state == FETCH_CQ_MR_s) ? 'd1 :
								(cur_state == FETCH_EQ_MR_s) ? 'd1 : 'd0;

//-- cq_req_valid --
//-- cq_req_head --
assign cq_req_valid = (cur_state == CQ_REQ_s) ? 'd1 : 'd0;
assign cq_req_head = (cur_state == CQ_REQ_s) ? {`CQE_LENGTH * (1 << cxt_bus[`CQ_CXT_LOG_SIZE_OFFSET]), 8'd0, cxt_bus[`QP_CXT_CQN_SND_OFFSET]} : 'd0;

//-- eq_req_valid --
//-- eq_req_head --
assign eq_req_valid = (cur_state == EQ_REQ_s) ? 'd1 : 'd0;
assign eq_req_head = (cur_state == EQ_REQ_s) ? {`EVENT_LENGTH * (1 << cxt_bus[`EQ_CXT_LOG_SIZE_OFFSET]), 8'd0, cxt_bus[`CQ_CXT_COMP_EQN_OFFSET]} : 'd0;

/********************************************************* MR Request Decode : Begin ***********************************************************/
//-- mr_length --
assign mr_length = 	(cur_state == FETCH_DATA_MR_s) ? SubWQE_packet_length :
					(cur_state == FETCH_CQ_MR_s) ? `CQE_LENGTH :
					(cur_state == FETCH_EQ_MR_s) ? `EVENT_LENGTH : 'd0;

//-- mr_laddr --
assign mr_laddr = 	(cur_state == FETCH_DATA_MR_s) ? SubWQE_laddr :
					(cur_state == FETCH_CQ_MR_s) ? cq_resp_head[`CQ_LADDR_OFFSET] :
					(cur_state == FETCH_EQ_MR_s) ? eq_resp_head[`EQ_LADDR_OFFSET] : 'd0;

//-- mr_lkey --
assign mr_lkey = 	(cur_state == FETCH_DATA_MR_s) ? SubWQE_lkey :
					(cur_state == FETCH_CQ_MR_s) ? cxt_bus[`CQ_CXT_LKEY_OFFSET] :
					(cur_state == FETCH_EQ_MR_s) ? cxt_bus[`EQ_CXT_LKEY_OFFSET] : 'd0;

//-- mr_pd --
assign mr_pd = 		(cur_state == FETCH_DATA_MR_s) ? cxt_bus[`QP_CXT_PD_OFFSET] :
					(cur_state == FETCH_CQ_MR_s) ? cxt_bus[`CQ_CXT_PD_OFFSET] :
					(cur_state == FETCH_EQ_MR_s) ? cxt_bus[`EQ_CXT_PD_OFFSET] : 'd0;

//-- mr_flag_sw_owns --
//-- mr_flag_absolute_addr --
//-- mr_flag_relative_addr --
//-- mr_flag_mio --
//-- mr_flag_bind_enable --
//-- mr_flag_physical --
//-- mr_flag_on_demand --
//-- mr_flag_zero_based --
//-- mr_flag_mw_bind --
//-- mr_remote_read --
//-- mr_remote_write --
//-- mr_local_write --
always @(*) begin
    if(rst) begin
        mr_flag_sw_owns = 'd0;
        mr_flag_absolute_addr = 'd0;
        mr_flag_relative_addr = 'd0;
        mr_flag_mio = 'd0;
        mr_flag_bind_enable = 'd0;
        mr_flag_physical = 'd0;
        mr_flag_region = 'd0;
        mr_flag_on_demand = 'd0;
        mr_flag_zero_based = 'd0;
        mr_flag_mw_bind = 'd0;
        mr_flag_remote_read = 'd0;
        mr_flag_remote_write = 'd0;
        mr_flag_local_write = 'd0;
    end
    else if(cur_state == FETCH_DATA_MR_s) begin
        mr_flag_sw_owns = 'd0;
        mr_flag_absolute_addr = 'd1;
        mr_flag_relative_addr = 'd0;
        mr_flag_mio = 'd0;
        mr_flag_bind_enable = 'd0;
        mr_flag_physical = 'd0;
        mr_flag_region = 'd0;
        mr_flag_on_demand = 'd0;
        mr_flag_zero_based = 'd0;
        mr_flag_mw_bind = 'd0;
        mr_flag_remote_read = 'd0;
        mr_flag_remote_write = 'd0;
        mr_flag_local_write = 'd0;       
    end
    else if(cur_state == FETCH_CQ_MR_s) begin
        mr_flag_sw_owns = 'd0;
        mr_flag_absolute_addr = 'd0;
        mr_flag_relative_addr = 'd1;
        mr_flag_mio = 'd0;
        mr_flag_bind_enable = 'd0;
        mr_flag_physical = 'd0;
        mr_flag_region = 'd0;
        mr_flag_on_demand = 'd0;
        mr_flag_zero_based = 'd0;
        mr_flag_mw_bind = 'd0;
        mr_flag_remote_read = 'd0;
        mr_flag_remote_write = 'd0;
        mr_flag_local_write = 'd1;       
    end
    else if(cur_state == FETCH_EQ_MR_s) begin
        mr_flag_sw_owns = 'd0;
        mr_flag_absolute_addr = 'd0;
        mr_flag_relative_addr = 'd1;
        mr_flag_mio = 'd0;
        mr_flag_bind_enable = 'd0;
        mr_flag_physical = 'd0;
        mr_flag_region = 'd0;
        mr_flag_on_demand = 'd0;
        mr_flag_zero_based = 'd0;
        mr_flag_mw_bind = 'd0;
        mr_flag_remote_read = 'd0;
        mr_flag_remote_write = 'd0;
        mr_flag_local_write = 'd1;       
    end
    else begin
        mr_flag_sw_owns = 'd0;
        mr_flag_absolute_addr = 'd0;
        mr_flag_relative_addr = 'd1;
        mr_flag_mio = 'd0;
        mr_flag_bind_enable = 'd0;
        mr_flag_physical = 'd0;
        mr_flag_region = 'd0;
        mr_flag_on_demand = 'd0;
        mr_flag_zero_based = 'd0;
        mr_flag_mw_bind = 'd0;
        mr_flag_remote_read = 'd0;
        mr_flag_remote_write = 'd0;
        mr_flag_local_write = 'd0;   
    end
end

//-- mr_flags --
assign mr_flags = (cur_state == FETCH_DATA_MR_s || cur_state == FETCH_CQ_MR_s || cur_state == FETCH_EQ_MR_s) ?
					{
                                mr_flag_sw_owns,
                                mr_flag_absolute_addr,
                                mr_flag_relative_addr,
                                8'd0,
                                mr_flag_mio,
                                1'd0,
                                mr_flag_bind_enable,
                                5'd0,
                                mr_flag_physical,
                                mr_flag_region,
                                1'd0,
                                mr_flag_on_demand,
                                mr_flag_zero_based,
                                mr_flag_mw_bind,
                                mr_flag_remote_read,
                                mr_flag_remote_write,
                                mr_flag_local_write
                    } : 'd0;
/********************************************************* MR Request Decode : End *************************************************************/

/*------------------------------------------- Variables Decode : End ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef 	SUB_WQE_LOCAL_QPN_OFFSET
`undef 	SUB_WQE_VERBS_OPCODE_OFFSET	
`undef 	SUB_WQE_REMOTE_QPN_OFFSET		
`undef 	SUB_WQE_NET_OPCODE_OFFSET 			
`undef 	SUB_WQE_SERVICE_TYPE_OFFSET		
`undef 	SUB_WQE_FENCE_OFFSET			
`undef	SUB_WQE_SOLICITED_EVENT_OFFSET 	
`undef 	SUB_WQE_HEAD_OFFSET	 			
`undef 	SUB_WQE_TAIL_OFFSET 			
`undef 	SUB_WQE_INLINE_OFFSET			
`undef 	SUB_WQE_WQE_OFFSET 				
`undef 	SUB_WQE_DMAC_OFFSET 			
`undef 	SUB_WQE_SMAC_OFFSET 			
`undef 	SUB_WQE_DIP_OFFSET 				
`undef 	SUB_WQE_SIP_OFFSET 				
`undef 	SUB_WQE_IMMEDIATE_OFFSET 		
`undef 	SUB_WQE_LKEY_OFFSET 			
`undef 	SUB_WQE_LADDR_OFFSET 			
`undef	SUB_WQE_RKEY_OFFSET 			
`undef 	SUB_WQE_RADDR_OFFSET 			
`undef 	SUB_WQE_MSG_LENGTH_OFFSET 		
`undef 	SUB_WQE_PKT_LENGTH_OFFSET 		
`undef 	SUB_WQE_PAYLOAD_BUFFER_ADDR_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule