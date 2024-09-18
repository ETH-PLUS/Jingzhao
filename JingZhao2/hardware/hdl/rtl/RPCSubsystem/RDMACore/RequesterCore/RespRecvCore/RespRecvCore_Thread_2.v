
/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       RespRecvCore_Thread_2
Author:     YangFan
Function:   1.Fetch MR.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module RespRecvCore_Thread_2
#(
    parameter                       INGRESS_MR_HEAD_WIDTH                   =   128,
    parameter                       INGRESS_MR_DATA_WIDTH                   =   256,
    parameter                       EGRESS_CXT_HEAD_WIDTH                   =   128,
    parameter                       EGRESS_CXT_DATA_WIDTH                   =   256
)
(
    input   wire                                                        clk,
    input   wire                                                        rst,

//Interface with OoOStation(For CxtMgt)
    input   wire                                                        fetch_cxt_egress_valid,
    input   wire    [`RX_RESP_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]        fetch_cxt_egress_head,
    input   wire    [`RX_RESP_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]        fetch_cxt_egress_data,
    input   wire                                                        fetch_cxt_egress_start,
    input   wire                                                        fetch_cxt_egress_last,
    output  wire                                                        fetch_cxt_egress_ready,

//Interface with OoOStation(For MRMgt)
    output  wire                                                        fetch_mr_ingress_valid,
    output  wire    [`RX_RESP_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]        fetch_mr_ingress_head,
    output  wire    [`RX_RESP_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]        fetch_mr_ingress_data,
    output  wire                                                        fetch_mr_ingress_start,
    output  wire                                                        fetch_mr_ingress_last,
    input   wire                                                        fetch_mr_ingress_ready,

//Interface with WQEBuffer
    output  wire                                                        dequeue_req_valid,
    output  wire    [`MAX_QP_NUM_LOG + `MAX_OOO_SLOT_NUM_LOG - 1 : 0]   dequeue_req_head,
    input   wire                                                        dequeue_req_ready,

    input   wire                                                        dequeue_resp_valid,
    input   wire    [`MAX_QP_NUM_LOG + `MAX_OOO_SLOT_NUM_LOG - 1 : 0]   dequeue_resp_head,
    input   wire                                                        dequeue_resp_start,
    input   wire                                                        dequeue_resp_last,
    output  wire                                                        dequeue_resp_ready,
    input   wire    [`RC_WQE_BUFFER_SLOT_WIDTH - 1 : 0]                 dequeue_resp_data,

//Interface with CompletionQueueMgt
    output  wire                                                        cq_req_valid,
    output  wire    [`CQ_REQ_HEAD_WIDTH - 1 : 0]                        cq_req_head,
    input   wire                                                        cq_req_ready,
     
    input   wire                                                        cq_resp_valid,
    input   wire    [`CQ_RESP_HEAD_WIDTH - 1 : 0]                       cq_resp_head,
    output  wire                                                        cq_resp_ready,

//Interface with EventQueueMgt
    output  wire                                                        eq_req_valid,
    output  wire    [`EQ_REQ_HEAD_WIDTH - 1 : 0]                        eq_req_head,
    input   wire                                                        eq_req_ready,
 
    input   wire                                                        eq_resp_valid,
    input   wire    [`EQ_RESP_HEAD_WIDTH - 1 : 0]                       eq_resp_head,
    output  wire                                                        eq_resp_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     SUB_WQE_LOCAL_QPN_OFFSET                23:0
`define     SUB_WQE_VERBS_OPCODE_OFFSET             28:24
`define     SUB_WQE_REMOTE_QPN_OFFSET               55:32
`define     SUB_WQE_NET_OPCODE_OFFSET               60:56
`define     SUB_WQE_SERVICE_TYPE_OFFSET             63:61
`define     SUB_WQE_DLID_OPCODE_OFFSET              79:64
`define     SUB_WQE_PKT_LENGTH_OFFSET               95:80
`define     SUB_WQE_LKEY_OFFSET                     127:96
`define     SUB_WQE_LADDR_OFFSET                    191:128
`define     SUB_WQE_MSG_LENGTH_OFFSET               223:192
`define     SUB_WQE_ORI_WQE_ADDR_OFFSET             247:224

`define     HEADER_LOCAL_QPN_OFFSET                 55:32
`define     HEADER_REMOTE_QPN_OFFSET                23:0
`define     HEADER_NET_OPCODE_OFFSET                28:24
`define     HEADER_SERVICE_TYPE_OFFSET              31:29
`define     HEADER_PKT_LENGTH_OFFSET                383:368
`define     HEADER_PAYLOAD_ADDR_OFFSET              383:368
`define     HEADER_PKT_START_ADDR_OFFSET            367:352
`define     HEADER_DMAC_OFFSET                      239:192
`define     HEADER_SMAC_OFFSET                      287:240
`define     HEADER_DIP_OFFSET                       319:288
`define     HEADER_SIP_OFFSET                       351:320
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg                 [`WQE_BUFFER_SLOT_WIDTH - 1 : 0]                wqe_meta_bus;
reg                 [`RX_RESP_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]    cxt_head_bus;
reg                 [`RX_RESP_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]    pkt_header_bus;

wire                [23:0]                                          WQE_local_qpn;
wire                [4:0]                                           WQE_verbs_opcode;
wire                [23:0]                                          WQE_remote_qpn;
wire                [4:0]                                           WQE_net_opcode;
wire                [2:0]                                           WQE_service_type;
wire                [15:0]                                          WQE_dlid;
wire                [15:0]                                          WQE_pkt_length;
wire                [31:0]                                          WQE_lkey;
wire                [63:0]                                          WQE_laddr;
wire                [31:0]                                          WQE_msg_length;
wire                [23:0]                                          WQE_ori_wqe_addr;

wire                [31:0]                                          Cxt_qp_pd;
wire                [23:0]                                          Cxt_cqn;
wire                [31:0]                                          Cxt_cq_lkey;
wire                [31:0]                                          Cxt_cq_pd;
wire                [31:0]                                          Cxt_cq_length;
wire                [31:0]                                          Cxt_eqn;
wire                [31:0]                                          Cxt_eq_lkey;
wire                [31:0]                                          Cxt_eq_pd;
wire                [31:0]                                          Cxt_eq_length;

wire                [31:0]                                          PktHeader_pkt_start_addr;
wire                [23:0]                                          PktHeader_local_qpn;

wire                [31:0]                                          mr_length;
wire                [63:0]                                          mr_laddr;
wire                [31:0]                                          mr_lkey;
wire                [31:0]                                          mr_pd;

wire                [31:0]                                          mr_flags;
reg                 [3:0]                                           mr_flag_sw_owns;
reg                                                                 mr_flag_absolute_addr;
reg                                                                 mr_flag_relative_addr;
reg                                                                 mr_flag_mio;
reg                                                                 mr_flag_bind_enable;
reg                                                                 mr_flag_physical;
reg                                                                 mr_flag_region;
reg                                                                 mr_flag_on_demand;
reg                                                                 mr_flag_zero_based;
reg                                                                 mr_flag_mw_bind;
reg                                                                 mr_flag_remote_read;
reg                                                                 mr_flag_remote_write;
reg                                                                 mr_flag_local_write;

reg                 [63:0]                                          cq_offset;
reg                 [63:0]                                          eq_offset;

wire                [`MAX_QP_NUM_LOG - 1 : 0]                       queue_index;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg                 [3:0]                       cur_state;
reg                 [3:0]                       next_state;

parameter           [3:0]                       IDLE_s          = 4'd1,
                                                DEQUEUE_REQ_s   = 4'd2,
                                                DEQUEUE_RESP_s  = 4'd3,
                                                JUDGE_s         = 4'd4,
                                                CQ_REQ_s        = 4'd5,
                                                CQ_RESP_s       = 4'd6,
                                                EQ_REQ_s        = 4'd7,
                                                EQ_RESP_s       = 4'd8,
                                                MR_FOR_DATA_s   = 4'd9,
                                                MR_FOR_CQ_s     = 4'd10,
                                                MR_FOR_EQ_s     = 4'd11;

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
        IDLE_s:             if(fetch_cxt_egress_valid) begin
                                next_state = DEQUEUE_REQ_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
        DEQUEUE_REQ_s:      if(dequeue_req_valid && dequeue_req_ready) begin
                                next_state = DEQUEUE_RESP_s;
                            end
                            else begin
                                next_state = DEQUEUE_RESP_s;
                            end
        DEQUEUE_RESP_s:     if(dequeue_resp_valid) begin
                                next_state = JUDGE_s;
                            end
                            else begin
                                next_state = DEQUEUE_RESP_s;
                            end
        JUDGE_s:            if(WQE_net_opcode == `SEND_LAST || WQE_net_opcode == `SEND_LAST_WITH_IMM || WQE_net_opcode == `SEND_ONLY || WQE_net_opcode == `SEND_ONLY_WITH_IMM ||
                                WQE_net_opcode == `RDMA_WRITE_LAST || WQE_net_opcode == `RDMA_WRITE_LAST_WITH_IMM || WQE_net_opcode == `RDMA_WRITE_ONLY || WQE_net_opcode == `RDMA_WRITE_ONLY_WITH_IMM) begin
                                next_state = CQ_REQ_s;        
                            end
                            else if(WQE_net_opcode == `SEND_FIRST || WQE_net_opcode == `SEND_MIDDLE || WQE_net_opcode == `RDMA_WRITE_FIRST || WQE_net_opcode == `RDMA_WRITE_MIDDLE) begin
                                next_state = IDLE_s;
                            end
                            else if(WQE_net_opcode == `RDMA_READ_REQUEST_FIRST || WQE_net_opcode == `RDMA_READ_REQUEST_MIDDLE || WQE_net_opcode == `RDMA_READ_REQUEST_LAST || WQE_net_opcode == `RDMA_READ_REQUEST_ONLY) begin
                                next_state = MR_FOR_DATA_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
         CQ_REQ_s:          if(cq_req_valid && cq_req_ready) begin
                                next_state = CQ_RESP_s;
                            end
                            else begin
                                next_state = CQ_REQ_s;
                            end
         CQ_RESP_s:         if(cq_resp_valid && cq_resp_ready) begin
                                next_state = MR_FOR_CQ_s;
                            end
                            else begin
                                next_state = CQ_RESP_s;
                            end
         EQ_REQ_s:          if(eq_req_valid && eq_req_ready) begin
                                next_state = EQ_RESP_s;
                            end
                            else begin
                                next_state = EQ_REQ_s;
                            end
         EQ_RESP_s:         if(eq_resp_valid && eq_resp_ready) begin
                                next_state = MR_FOR_EQ_s;
                            end
                            else begin
                                next_state = EQ_RESP_s;
                            end
         MR_FOR_DATA_s:     if(fetch_mr_ingress_valid && fetch_mr_ingress_ready) begin
                                if(WQE_net_opcode == `RDMA_READ_REQUEST_LAST || WQE_net_opcode == `RDMA_READ_REQUEST_ONLY) begin
                                    next_state = CQ_REQ_s;
                                end
                                else begin
                                    next_state = IDLE_s;
                                end
                            end
                            else begin
                                next_state = MR_FOR_DATA_s;
                            end
         MR_FOR_CQ_s:       if(fetch_mr_ingress_valid && fetch_mr_ingress_ready) begin
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = MR_FOR_CQ_s;
                            end
         MR_FOR_EQ_s:       if(fetch_mr_ingress_valid && fetch_mr_ingress_ready) begin
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = MR_FOR_EQ_s;
                            end
         default:           next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- wqe_meta_bus --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        wqe_meta_bus <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        wqe_meta_bus <= 'd0;
    end
    else if(cur_state == DEQUEUE_RESP_s && dequeue_resp_valid) begin
        wqe_meta_bus <= dequeue_resp_data;
    end
    else begin
        wqe_meta_bus <= wqe_meta_bus;
    end
end

//-- cxt_head_bus --
//-- pkt_header_bus --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cxt_head_bus <= 'd0;
        pkt_header_bus <= 'd0;
    end
    else if (cur_state == IDLE_s && fetch_cxt_egress_valid) begin
        cxt_head_bus <= fetch_cxt_egress_head[`RX_RESP_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : `EGRESS_COMMON_HEAD_WIDTH];
        pkt_header_bus <= fetch_cxt_egress_data;
    end
    else begin
        cxt_head_bus <= cxt_head_bus;
        pkt_header_bus <= pkt_header_bus;
    end
end

//-- WQE_local_qpn --
//-- WQE_verbs_opcode --
//-- WQE_remote_qpn --
//-- WQE_net_opcode --
//-- WQE_service_type --
//-- WQE_dlid --
//-- WQE_pkt_length --
//-- WQE_lkey --
//-- WQE_laddr --
//-- WQE_msg_length --
//-- WQE_ori_wqe_addr --
assign WQE_local_qpn = wqe_meta_bus[`SUB_WQE_LOCAL_QPN_OFFSET];
assign WQE_verbs_opcode = wqe_meta_bus[`SUB_WQE_VERBS_OPCODE_OFFSET];
assign WQE_remote_qpn = wqe_meta_bus[`SUB_WQE_REMOTE_QPN_OFFSET];
assign WQE_net_opcode = wqe_meta_bus[`SUB_WQE_NET_OPCODE_OFFSET];
assign WQE_service_type = wqe_meta_bus[`SUB_WQE_SERVICE_TYPE_OFFSET];
assign WQE_dlid = wqe_meta_bus[`SUB_WQE_DLID_OPCODE_OFFSET];
assign WQE_pkt_length = wqe_meta_bus[`SUB_WQE_PKT_LENGTH_OFFSET];
assign WQE_lkey = wqe_meta_bus[`SUB_WQE_LKEY_OFFSET];
assign WQE_laddr = wqe_meta_bus[`SUB_WQE_LADDR_OFFSET];
assign WQE_msg_length = wqe_meta_bus[`SUB_WQE_MSG_LENGTH_OFFSET];
assign WQE_ori_wqe_addr = wqe_meta_bus[`SUB_WQE_ORI_WQE_ADDR_OFFSET];

//-- PktHeader_pkt_start_addr --
//-- PktHeader_local_qpn --
assign PktHeader_pkt_start_addr = pkt_header_bus[`HEADER_PKT_START_ADDR_OFFSET];
assign PktHeader_local_qpn = pkt_header_bus[`HEADER_LOCAL_QPN_OFFSET];

//-- Cxt_qp_pd --
//-- Cxt_cqn --
//-- Cxt_cq_lkey --
//-- Cxt_cq_pd --
//-- Cxt_cq_length --
//-- Cxt_eqn --
//-- Cxt_eq_lkey --
//-- Cxt_eq_pd --
//-- Cxt_eq_length --
assign Cxt_qp_pd = cxt_head_bus[`QP_CXT_PD_OFFSET];
assign Cxt_cqn = cxt_head_bus[`QP_CXT_CQN_RCV_OFFSET];
assign Cxt_cq_lkey = cxt_head_bus[`CQ_CXT_LKEY_OFFSET];
assign Cxt_cq_pd = cxt_head_bus[`CQ_CXT_PD_OFFSET];
assign Cxt_cq_length = (1 << cxt_head_bus[`CQ_CXT_LOG_SIZE_OFFSET]) * `CQE_LENGTH;
assign Cxt_eqn = cxt_head_bus[`CQ_CXT_COMP_EQN_OFFSET];
assign Cxt_eq_lkey = cxt_head_bus[`EQ_CXT_LKEY_OFFSET];
assign Cxt_eq_pd = cxt_head_bus[`EQ_CXT_PD_OFFSET];
assign Cxt_eq_length = (1 << cxt_head_bus[`EQ_CXT_LOG_SIZE_OFFSET]) * `EVENT_LENGTH;

//-- queue_index --
assign queue_index = PktHeader_local_qpn[`MAX_QP_NUM_LOG - 1 : 0];

//-- dequeue_req_valid --
//-- dequeue_req_head --
assign dequeue_req_valid = (cur_state == DEQUEUE_REQ_s) ? 'd1 : 'd0;
assign dequeue_req_head = (cur_state == DEQUEUE_REQ_s) ? {'d1, queue_index} : 'd0;

//-- dequeue_resp_ready --
assign dequeue_resp_ready = (cur_state == DEQUEUE_RESP_s) ? 'd1 : 'd0;

//-- cq_req_valid --
//-- cq_req_head --
assign cq_req_valid = (cur_state == CQ_REQ_s) ? 'd1 : 'd0;
assign cq_req_head = (cur_state == CQ_REQ_s) ? {Cxt_cq_length, 8'd0, Cxt_cqn} : 'd0;
     
//-- cq_resp_ready --
assign cq_resp_ready = (cur_state == CQ_RESP_s) ? 'd1 : 'd0;

//-- eq_req_valid --
//-- eq_req_head --
assign eq_req_valid = (cur_state == EQ_REQ_s) ? 'd1 : 'd0;
assign eq_req_head = (cur_state == EQ_REQ_s) ? {Cxt_eq_length, 8'd0, Cxt_eqn} : 'd0;
     
//-- eq_resp_ready --
assign eq_resp_ready = (cur_state == EQ_RESP_s) ? 'd1 : 'd0;

//-- fetch_cxt_egress_ready --
assign fetch_cxt_egress_ready = (cur_state == IDLE_s) ? 'd1 : 'd0;

//-- cq_offset --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cq_offset <= 'd0;        
    end
    else if (cur_state == CQ_RESP_s && cq_resp_valid) begin
        cq_offset <= cq_resp_head[95:32];
    end
    else begin
        cq_offset <= cq_offset;
    end
end

//-- eq_offset --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        eq_offset <= 'd0;        
    end
    else if (cur_state == EQ_RESP_s && eq_resp_valid) begin
        eq_offset <= eq_resp_head[95:32];
    end
    else begin
        eq_offset <= eq_offset;
    end
end
/********************************************************* MR Request Decode : Begin ***********************************************************/
wire                [`INGRESS_COMMON_HEAD_WIDTH - 1 : 0]            ingress_common_head;
wire                [`MAX_OOO_SLOT_NUM_LOG - 1 :0]                  ingress_slot_count;

//-- ingress_slot_count --
//-- ingress_common_head --
assign ingress_slot_count = (cur_state == MR_FOR_DATA_s) ? 'd1 :
                             (cur_state == MR_FOR_CQ_s) ? 'd1 : 
                             (cur_state == MR_FOR_EQ_s) ? 'd1 : 'd0;

assign ingress_common_head = (cur_state == MR_FOR_DATA_s) ? {`NO_BYPASS, ingress_slot_count, queue_index} : 
                             (cur_state == MR_FOR_CQ_s) ? {`NO_BYPASS, ingress_slot_count, queue_index} : 
                             (cur_state == MR_FOR_EQ_s) ? {`NO_BYPASS, ingress_slot_count, queue_index} : 'd0;

//-- fetch_mr_ingress_valid --
assign fetch_mr_ingress_valid = (cur_state == MR_FOR_DATA_s) ? 'd1 :
                                (cur_state == MR_FOR_CQ_s) ? 'd1 :
                                (cur_state == MR_FOR_EQ_s) ? 'd1 : 'd0;

//-- fetch_mr_ingress_head --
assign fetch_mr_ingress_head =  (cur_state == MR_FOR_DATA_s) ? {mr_length, mr_laddr, mr_lkey, mr_pd, mr_flags, ingress_common_head} :
                                (cur_state == MR_FOR_CQ_s) ? {mr_length, mr_laddr, mr_lkey, mr_pd, mr_flags, ingress_common_head} :
                                (cur_state == MR_FOR_EQ_s) ? {mr_length, mr_laddr, mr_lkey, mr_pd, mr_flags, ingress_common_head} : 'd0;

//-- fetch_mr_ingress_data --
assign fetch_mr_ingress_data =  (cur_state == MR_FOR_DATA_s) ? {16'd0, PktHeader_pkt_start_addr, 32'd0, 16'd0, WQE_pkt_length, WQE_msg_length, 3'd0, WQE_net_opcode, WQE_remote_qpn, 8'd0, WQE_local_qpn} :
                                (cur_state == MR_FOR_CQ_s) ?  {32'd0, 8'd0, WQE_ori_wqe_addr, WQE_dlid, WQE_msg_length, 3'd0, `GEN_CQE, WQE_remote_qpn, 3'd0, WQE_verbs_opcode, WQE_local_qpn} :
                                (cur_state == MR_FOR_EQ_s) ?  {32'd0, 32'd0, 16'd0, 16'd0, 32'd0, 8'd0, WQE_remote_qpn, 8'd0, WQE_local_qpn} : 'd0;
                                

//-- fetch_mr_ingress_start --
assign fetch_mr_ingress_start = (cur_state == MR_FOR_DATA_s) ? 'd1 :
                                (cur_state == MR_FOR_CQ_s) ? 'd1 :
                                (cur_state == MR_FOR_EQ_s) ? 'd1 : 'd0;

//-- fetch_mr_ingress_last --
assign fetch_mr_ingress_last =  (cur_state == MR_FOR_DATA_s) ? 'd1 :
                                (cur_state == MR_FOR_CQ_s) ? 'd1 :
                                (cur_state == MR_FOR_EQ_s) ? 'd1 : 'd0;

//-- mr_length --
assign mr_length =  (cur_state == MR_FOR_DATA_s) ? WQE_pkt_length :
                    (cur_state == MR_FOR_CQ_s) ? `CQE_LENGTH :
                    (cur_state == MR_FOR_EQ_s) ? `EVENT_LENGTH : 'd0;

//-- mr_laddr --
assign mr_laddr =   (cur_state == MR_FOR_DATA_s) ? WQE_laddr :
                    (cur_state == MR_FOR_CQ_s) ?  cq_offset :
                    (cur_state == MR_FOR_EQ_s) ?  eq_offset : 'd0;

//-- mr_lkey --
assign mr_lkey =    (cur_state == MR_FOR_DATA_s) ? WQE_lkey :
                    (cur_state == MR_FOR_CQ_s) ?  Cxt_cq_lkey :
                    (cur_state == MR_FOR_EQ_s) ?  Cxt_eq_lkey : 'd0;;

//-- mr_pd --
assign mr_pd =      (cur_state == MR_FOR_DATA_s) ? Cxt_qp_pd :
                    (cur_state == MR_FOR_CQ_s) ?  Cxt_cq_pd :
                    (cur_state == MR_FOR_EQ_s) ?  Cxt_eq_pd : 'd0;

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
    else if(cur_state == MR_FOR_DATA_s) begin
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
        mr_flag_local_write = 'd1;   
    end
    else if(cur_state == MR_FOR_CQ_s) begin
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
    else if(cur_state == MR_FOR_EQ_s) begin
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
assign mr_flags = (cur_state == MR_FOR_DATA_s || cur_state == MR_FOR_DATA_s || cur_state == MR_FOR_CQ_s || cur_state == MR_FOR_EQ_s) ?
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
/*------------------------------------------- Variables Decode : End ----------------------------------------------***/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef     SUB_WQE_LOCAL_QPN_OFFSET
`undef     SUB_WQE_VERBS_OPCODE_OFFSET
`undef     SUB_WQE_REMOTE_QPN_OFFSET
`undef     SUB_WQE_NET_OPCODE_OFFSET
`undef     SUB_WQE_SERVICE_TYPE_OFFSET
`undef     SUB_WQE_DLID_OPCODE_OFFSET
`undef     SUB_WQE_PKT_LENGTH_OFFSET
`undef     SUB_WQE_LKEY_OFFSET
`undef     SUB_WQE_LADDR_OFFSET
`undef     SUB_WQE_MSG_LENGTH_OFFSET
`undef     SUB_WQE_ORI_WQE_ADDR_OFFSET

`undef     HEADER_LOCAL_QPN_OFFSET
`undef     HEADER_REMOTE_QPN_OFFSET
`undef     HEADER_NET_OPCODE_OFFSET
`undef     HEADER_SERVICE_TYPE_OFFSET
`undef     HEADER_PKT_LENGTH_OFFSET
`undef     HEADER_PAYLOAD_ADDR_OFFSET
`undef     HEADER_PKT_START_ADDR_OFFSET
`undef     HEADER_DMAC_OFFSET
`undef     HEADER_SMAC_OFFSET
`undef     HEADER_DIP_OFFSET
`undef     HEADER_SIP_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule