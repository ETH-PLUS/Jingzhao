
/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ReqRecvCore_Thread_2
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
module ReqRecvCore_Thread_2
#(
    parameter                       INGRESS_MR_HEAD_WIDTH                   =   128,
    parameter                       INGRESS_MR_DATA_WIDTH                   =   256,
    parameter                       EGRESS_CXT_HEAD_WIDTH                   =   128,
    parameter                       EGRESS_CXT_DATA_WIDTH                   =   256
)
(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with OoOStation(For CxtMgt)
    input   wire                                                            fetch_cxt_egress_valid,
    input   wire    [`RX_REQ_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]             fetch_cxt_egress_head,
    input   wire    [`RX_REQ_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]             fetch_cxt_egress_data,
    input   wire                                                            fetch_cxt_egress_start,
    input   wire                                                            fetch_cxt_egress_last,
    output  wire                                                            fetch_cxt_egress_ready,

//Interface with OoOStation(For MRMgt)
    output  wire                                                            fetch_mr_ingress_valid,
    output  wire    [`RX_REQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]             fetch_mr_ingress_head,
    output  wire    [`RX_REQ_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]             fetch_mr_ingress_data,
    output  wire                                                            fetch_mr_ingress_start,
    output  wire                                                            fetch_mr_ingress_last,
    input   wire                                                            fetch_mr_ingress_ready,

//Interface with RecvQueueMgt
    output  wire                                                            wqe_req_valid,
    output  wire    [`WQE_META_WIDTH - 1 : 0]                               wqe_req_head,
    output  wire                                                            wqe_req_start,
    output  wire                                                            wqe_req_last,
    input   wire                                                            wqe_req_ready,

    input   wire                                                            wqe_resp_valid,
    input   wire    [`WQE_META_WIDTH - 1 : 0]                               wqe_resp_head,
    input   wire    [`WQE_SEG_WIDTH - 1 : 0]                                wqe_resp_data,
    input   wire                                                            wqe_resp_start,
    input   wire                                                            wqe_resp_last,
    output  reg                                                            	wqe_resp_ready,

//Interface with cache offset table
    output  reg                                                             cache_offset_wen,
    output  reg     [`QP_NUM_LOG - 1 : 0]                                   cache_offset_addr,
    output  reg     [`RQ_CACHE_SLOT_NUM_LOG - 1:0]                          cache_offset_din,
    input   wire    [`RQ_CACHE_SLOT_NUM_LOG - 1:0]                          cache_offset_dout,

//Interface with CacheOwnedTable
    output  reg                                                             cache_owned_wen,
    output  reg     [`RQ_CACHE_CELL_NUM_LOG - 1 : 0]                        cache_owned_addr,
    output  reg     [`QP_NUM_LOG - 1 : 0]                                   cache_owned_din,
    input   wire    [`QP_NUM_LOG - 1 : 0]                                   cache_owned_dout,

//Interface with RQHeadRecord
    output  reg                                                             rq_offset_wen,
    output  reg     [`QP_NUM_LOG - 1 : 0]                                   rq_offset_addr,
    output  reg     [23:0]                                                  rq_offset_din,
    input   wire    [23:0]                                                  rq_offset_dout,

//Interface with CompletionQueueMgt
    output  wire                                                            cq_req_valid,
    output  wire    [`CQ_REQ_HEAD_WIDTH - 1 : 0]                            cq_req_head,
    input   wire                                                            cq_req_ready,
     
    input   wire                                                            cq_resp_valid,
    input   wire    [`CQ_RESP_HEAD_WIDTH - 1 : 0]                           cq_resp_head,
    output  wire                                                            cq_resp_ready,

//Interface with EventQueueMgt
    output  wire                                                            eq_req_valid,
    output  wire    [`EQ_REQ_HEAD_WIDTH - 1 : 0]                            eq_req_head,
    input   wire                                                            eq_req_ready,
 
    input   wire                                                            eq_resp_valid,
    input   wire    [`EQ_RESP_HEAD_WIDTH - 1 : 0]                           eq_resp_head,
    output  wire                                                            eq_resp_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     HEADER_LOCAL_QPN_OFFSET                     55:32
`define     HEADER_REMOTE_QPN_OFFSET                    23:0
`define     HEADER_NET_OPCODE_OFFSET                    28:24
`define     HEADER_SERVICE_TYPE_OFFSET                  31:29
`define     HEADER_IMMEDIATE_OFFSET                     191:160
`define     HEADER_RKEY_OFFSET                          95:64
`define     HEADER_RADDR_OFFSET                         159:96
`define     HEADER_DMAC_OFFSET                          239:192
`define     HEADER_SMAC_OFFSET                          287:240
`define     HEADER_DIP_OFFSET                           319:288
`define     HEADER_SIP_OFFSET                           351:320
`define     HEADER_PKT_START_ADDR_OFFSET                367:352
`define     HEADER_PKT_LENGTH_OFFSET                    383:368
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg                 [`RX_REQ_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]     cxt_head_bus;
reg                 [`PKT_META_BUS_WIDTH : 0]                       pkt_header_bus;
                
wire                [23:0]                                          PktHeader_local_qpn;
wire                [23:0]                                          PktHeader_remote_qpn;
wire                [4:0]                                           PktHeader_net_opcode;
wire                [4:0]                                           PktHeader_resp_opcode;
wire                [2:0]                                           PktHeader_service_type;
wire                [47:0]                                          PktHeader_dmac;
wire                [47:0]                                          PktHeader_smac;
wire                [31:0]                                          PktHeader_dip;
wire                [31:0]                                          PktHeader_sip;
wire                [31:0]                                          PktHeader_immediate;
wire                [31:0]                                          PktHeader_rkey;
wire                [63:0]                                          PktHeader_raddr;
wire                [15:0]                                          PktHeader_pkt_length;
wire                [15:0]                                          PktHeader_pkt_start_addr;

reg                 [31:0]                                          ori_wqe_addr;

wire                [7:0]                                           Cxt_rq_entry_sz_log;
wire                [31:0]                                          Cxt_rq_length;
wire                [31:0]                                          Cxt_rq_lkey;
wire                [31:0]                                          Cxt_qp_pd;
wire 				[23:0]											Cxt_cqn;
wire                [31:0]                                          Cxt_cq_lkey;
wire                [31:0]                                          Cxt_cq_pd;
wire 				[31:0]											Cxt_cq_length;
wire 				[31:0]											Cxt_eqn;
wire                [31:0]                                          Cxt_eq_lkey;
wire                [31:0]                                          Cxt_eq_pd;
wire 				[31:0]											Cxt_eq_length;

//NextUnit
reg                 [4:0]                                           NextUnit_next_wqe_opcode;
reg                 [0:0]                                           NextUnit_next_wqe_valid;
reg                 [25:0]                                          NextUnit_next_wqe_addr;
reg                 [5:0]                                           NextUnit_next_wqe_size;
reg                 [7:0]                                           NextUnit_cur_wqe_size;
reg                 [7:0]                                           NextUnit_cur_wqe_size_aligned;
reg                 [7:0]                                           NextUnit_next_wqe_size_aligned;

//DataUnit
wire                [31:0]                                          DataUnit_byte_cnt;
wire                [31:0]                                          DataUnit_lkey;
wire                [63:0]                                          DataUnit_laddr;

wire                [`INGRESS_COMMON_HEAD_WIDTH - 1 : 0]            ingress_common_head;
wire                [`MAX_OOO_SLOT_NUM_LOG - 1:0]                                          ingress_slot_count;

reg                 [31:0]                                          parsed_msg_length;
reg                 [31:0]                                          pkt_length_left;
reg  				[7:0]											tail_indicator;

reg 				[63:0]											cq_offset;
reg 				[63:0]											eq_offset;

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

reg                                                                 msg_offset_wea;
reg                 [`QP_NUM_LOG - 1 : 0]                           msg_offset_addra;
reg                 [31:0]                                          msg_offset_dina;
wire                [`QP_NUM_LOG - 1 : 0]                           msg_offset_addrb;
wire                [31:0]                                          msg_offset_doutb;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
SRAM_SDP_Template #(
    .RAM_WIDTH      (   32                      ),      //Record each cell offset(in unit of slot)
    .RAM_DEPTH      (   `QP_NUM                 )
)
MsgOffsetTable
(
    .clk            (   clk                     ),
    .rst            (   rst                     ),

    .wea            (   msg_offset_wea          ),
    .addra          (   msg_offset_addra        ),
    .dina           (   msg_offset_dina         ),

    .addrb          (   msg_offset_addrb        ),
    .doutb          (   msg_offset_doutb        )
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg                 [5:0]                                           cur_state;
reg                 [5:0]                                           next_state;

parameter           [5:0]               IDLE_s          =   5'd1,
                                        JUDGE_s         =   5'd2,
                                        WQE_REQ_s       =   5'd3,
                                        NEXT_UNIT_s     =   5'd4,
                                        DATA_UNIT_s     =   5'd5,
                                        CQ_REQ_s        =   5'd6,
                                        CQ_RESP_s       =   5'd7,
                                        EQ_REQ_s        =   5'd8,
                                        EQ_RESP_s       =   5'd9,
                                        UPDATE_RQ_s     =   5'd10,
                                        MR_FOR_SEND_s   =   5'd11,
                                        MR_FOR_WRITE_s  =   5'd12,
                                        MR_FOR_READ_s   =   5'd13,
                                        MR_FOR_CQ_s     =   5'd14,
                                        MR_FOR_EQ_s     =   5'd15,
                                        GEN_ACK_s       =   5'd16;

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
        IDLE_s:             if(fetch_cxt_egress_valid) begin
                                next_state = JUDGE_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
        JUDGE_s:            if( PktHeader_net_opcode == `SEND_FIRST || PktHeader_net_opcode == `SEND_MIDDLE || PktHeader_net_opcode == `SEND_LAST || 
                                PktHeader_net_opcode == `SEND_ONLY || PktHeader_net_opcode == `SEND_LAST_WITH_IMM || PktHeader_net_opcode == `SEND_ONLY_WITH_IMM  || 
                                PktHeader_net_opcode == `RDMA_WRITE_LAST_WITH_IMM || PktHeader_net_opcode == `RDMA_WRITE_ONLY_WITH_IMM) begin
                                next_state = WQE_REQ_s;
                            end
                            else if( PktHeader_net_opcode == `RDMA_WRITE_FIRST || PktHeader_net_opcode == `RDMA_WRITE_MIDDLE || PktHeader_net_opcode == `RDMA_WRITE_LAST
                            		|| PktHeader_net_opcode == `RDMA_WRITE_ONLY) begin
                                next_state = MR_FOR_WRITE_s;
                            end
                            else if( PktHeader_net_opcode == `RDMA_READ_REQUEST_FIRST || PktHeader_net_opcode == `RDMA_READ_REQUEST_MIDDLE || PktHeader_net_opcode == `RDMA_READ_REQUEST_LAST
                            			|| PktHeader_net_opcode == `RDMA_READ_REQUEST_ONLY) begin
                                next_state = MR_FOR_READ_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
        WQE_REQ_s:          if(wqe_req_valid && wqe_req_ready) begin
                                next_state = NEXT_UNIT_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
        NEXT_UNIT_s:        if(wqe_resp_valid && wqe_resp_ready) begin
                                next_state = DATA_UNIT_s;
                            end
                            else begin
                                next_state = NEXT_UNIT_s; 
                            end
        DATA_UNIT_s:        if(PktHeader_net_opcode == `RDMA_WRITE_LAST_WITH_IMM || PktHeader_net_opcode == `RDMA_WRITE_ONLY_WITH_IMM) begin
                                if(wqe_resp_valid && wqe_resp_last && wqe_resp_ready) begin     //RDMA_Write_With_Imm does not need to parse Recv WQE, just consume one
                                    next_state = UPDATE_RQ_s;
                                end
                                else begin
                                    next_state = DATA_UNIT_s;
                                end
                            end                        
                            else if(wqe_resp_valid) begin    //Send/Send with Imm, must parse DataUnit, The situation is complex, need careful control.
                                // if(parsed_msg_length + DataUnit_byte_cnt > msg_offset_doutb) begin
                                //     if(pkt_length_left == 0) begin
                                //         if(wqe_resp_last) begin             //When pkt length is exhausted and meet wqe_resp_last, update RQ
                                //             next_state = UPDATE_RQ_s;
                                //         end
                                //         else begin
                                //             next_state = DATA_UNIT_s;
                                //         end
                                //     end
                                //     else begin
                                //         next_state = MR_FOR_SEND_s;
                                //     end
                                // end
                                // else if(parsed_msg_length + DataUnit_byte_cnt <= msg_offset_doutb) begin     //Previous DataUnits have been consumed, continue parsing new DataUnit
                                //     next_state = DATA_UNIT_s;
                                // end
                                // else begin          //Unexepeted
                                //     next_state = IDLE_s;
                                // end
                                if(pkt_length_left == 0) begin  //All payload has been scattered
                                    if(wqe_resp_last) begin
                                        if(PktHeader_net_opcode == `SEND_LAST || PktHeader_net_opcode == `SEND_ONLY || PktHeader_net_opcode == `SEND_LAST_WITH_IMM ||
                                            PktHeader_net_opcode == `SEND_ONLY_WITH_IMM) begin
                                            next_state = UPDATE_RQ_s;       
                                        end
                                        else begin
                                            next_state = GEN_ACK_s;
                                        end
                                    end
                                    else begin
                                        next_state = DATA_UNIT_s;
                                    end
                                end
                                else begin
                                    if(parsed_msg_length + DataUnit_byte_cnt <= msg_offset_doutb) begin
                                        next_state = DATA_UNIT_s;
                                    end
                                    else begin
                                        next_state = MR_FOR_SEND_s;
                                    end
                                end
                            end
                            else begin
                                next_state = DATA_UNIT_s;
                            end
        CQ_REQ_s:           if(cq_req_valid && cq_req_ready) begin
                                next_state = CQ_RESP_s;
                            end
                            else begin
                                next_state = CQ_REQ_s;
                            end
        CQ_RESP_s:          if(cq_resp_valid && cq_resp_ready) begin
                                next_state = MR_FOR_CQ_s;
                            end
                            else begin
                                next_state = CQ_RESP_s;
                            end
        EQ_REQ_s:           if(eq_req_valid && eq_req_ready) begin
                                next_state = EQ_RESP_s;
                            end
                            else begin
                                next_state = EQ_REQ_s;
                            end
        EQ_RESP_s:          if(eq_resp_valid && eq_resp_ready) begin
                                next_state = MR_FOR_EQ_s;
                            end
                            else begin
                                next_state = EQ_RESP_s;
                            end
        UPDATE_RQ_s:        if(PktHeader_net_opcode == `SEND_LAST || PktHeader_net_opcode == `SEND_ONLY || PktHeader_net_opcode == `SEND_LAST_WITH_IMM || PktHeader_net_opcode == `SEND_ONLY_WITH_IMM) begin
                                next_state = CQ_REQ_s;        
                            end
                            else if(PktHeader_net_opcode == `RDMA_WRITE_LAST_WITH_IMM || PktHeader_net_opcode == `RDMA_WRITE_ONLY_WITH_IMM) begin
                                next_state = MR_FOR_WRITE_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
        MR_FOR_SEND_s:      if(fetch_mr_ingress_valid && fetch_mr_ingress_ready) begin
                                next_state = DATA_UNIT_s;
                            end
                            else begin
                                next_state = MR_FOR_SEND_s;                                
                            end
        MR_FOR_WRITE_s:     if(fetch_mr_ingress_valid && fetch_mr_ingress_ready) begin
                                if( PktHeader_net_opcode == `RDMA_WRITE_FIRST || PktHeader_net_opcode == `RDMA_WRITE_MIDDLE ||
                                    PktHeader_net_opcode == `RDMA_WRITE_LAST || PktHeader_net_opcode == `RDMA_WRITE_LAST_WITH_IMM ||
                                    PktHeader_net_opcode == `RDMA_WRITE_ONLY || PktHeader_net_opcode == `RDMA_WRITE_ONLY_WITH_IMM) begin
                                    next_state = GEN_ACK_s;
                                end
                                else begin
                                    next_state = IDLE_s;
                                end
                            end
                            else begin
                                next_state = MR_FOR_WRITE_s;                                
                            end
        MR_FOR_READ_s:      if(fetch_mr_ingress_valid && fetch_mr_ingress_ready) begin
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = MR_FOR_READ_s;                                
                            end  
        MR_FOR_CQ_s:        if(fetch_mr_ingress_valid && fetch_mr_ingress_ready) begin
                                next_state = GEN_ACK_s;
                            end
                            else begin
                                next_state = MR_FOR_CQ_s;
                            end
        MR_FOR_EQ_s:        if(fetch_mr_ingress_valid && fetch_mr_ingress_ready) begin
                                next_state = GEN_ACK_s;
                            end
                            else begin
                                next_state = MR_FOR_CQ_s;                                
                            end
        GEN_ACK_s:          if(fetch_mr_ingress_valid && fetch_mr_ingress_ready) begin
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = GEN_ACK_s;
                            end
        default:            next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- cxt_head_bus --
//-- pkt_header_bus --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        cxt_head_bus <= 'd0;
        pkt_header_bus <= 'd0;
    end
    else if(cur_state == IDLE_s && fetch_cxt_egress_valid) begin
        cxt_head_bus <= fetch_cxt_egress_head[`RX_REQ_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : `EGRESS_COMMON_HEAD_WIDTH];
        pkt_header_bus <= fetch_cxt_egress_data;
    end
    else begin
        cxt_head_bus <= cxt_head_bus;
        pkt_header_bus <= pkt_header_bus;
    end
end

//-- Cxt_rq_entry_sz_log --
//-- Cxt_rq_length --
//-- Cxt_rq_lkey --
//-- Cxt_qp_pd --
//-- Cxt_cqn --
//-- Cxt_cq_lkey --
//-- Cxt_cq_pd --
//-- Cxt_cq_length --
//-- Cxt_eqn --
//-- Cxt_eq_lkey --
//-- Cxt_eq_pd --
//-- Cxt_eq_length --
assign Cxt_rq_entry_sz_log = cxt_head_bus[`QP_CXT_RQ_ENTRY_SZ_LOG_OFFSET];
assign Cxt_rq_length = cxt_head_bus[`QP_CXT_RQ_LENGTH_OFFSET];
assign Cxt_rq_lkey = cxt_head_bus[`QP_CXT_RQ_LKEY_OFFSET];
assign Cxt_qp_pd = cxt_head_bus[`QP_CXT_PD_OFFSET];
assign Cxt_cqn = cxt_head_bus[`QP_CXT_CQN_RCV_OFFSET];
assign Cxt_cq_lkey = cxt_head_bus[`CQ_CXT_LKEY_OFFSET];
assign Cxt_cq_pd = cxt_head_bus[`CQ_CXT_PD_OFFSET];
assign Cxt_cq_length = (1 << cxt_head_bus[`CQ_CXT_LOG_SIZE_OFFSET]) * `CQE_LENGTH;
assign Cxt_eqn = cxt_head_bus[`CQ_CXT_COMP_EQN_OFFSET];
assign Cxt_eq_lkey = cxt_head_bus[`EQ_CXT_LKEY_OFFSET];
assign Cxt_eq_pd = cxt_head_bus[`EQ_CXT_PD_OFFSET];
assign Cxt_eq_length = (1 << cxt_head_bus[`EQ_CXT_LOG_SIZE_OFFSET]) * `EVENT_LENGTH;

//-- PktHeader_local_qpn --
//-- PktHeader_remote_qpn --
//-- PktHeader_net_opcode --
//-- PktHeader_service_type --
//-- PktHeader_dmac --
//-- PktHeader_smac --
//-- PktHeader_dip --
//-- PktHeader_sip --
//-- PktHeader_immediate --
//-- PktHeader_rkey --
//-- PktHeader_raddr --
//-- PktHeader_pkt_length --
//-- PktHeader_pkt_start_addr --
assign PktHeader_local_qpn = pkt_header_bus[`HEADER_LOCAL_QPN_OFFSET];
assign PktHeader_remote_qpn = pkt_header_bus[`HEADER_REMOTE_QPN_OFFSET];
assign PktHeader_net_opcode = pkt_header_bus[`HEADER_NET_OPCODE_OFFSET];
assign PktHeader_service_type = pkt_header_bus[`HEADER_SERVICE_TYPE_OFFSET];
assign PktHeader_dmac = pkt_header_bus[`HEADER_DMAC_OFFSET];
assign PktHeader_smac = pkt_header_bus[`HEADER_SMAC_OFFSET];
assign PktHeader_dip = pkt_header_bus[`HEADER_DIP_OFFSET];
assign PktHeader_sip = pkt_header_bus[`HEADER_SIP_OFFSET];
assign PktHeader_immediate = pkt_header_bus[`HEADER_IMMEDIATE_OFFSET];
assign PktHeader_rkey = pkt_header_bus[`HEADER_RKEY_OFFSET];
assign PktHeader_raddr = pkt_header_bus[`HEADER_RADDR_OFFSET];
assign PktHeader_pkt_length = pkt_header_bus[`HEADER_PKT_LENGTH_OFFSET];
assign PktHeader_pkt_start_addr = pkt_header_bus[`HEADER_PKT_START_ADDR_OFFSET];

//-- PktHeader_resp_opcode --
assign PktHeader_resp_opcode =  (PktHeader_net_opcode == `RDMA_READ_REQUEST_FIRST) ? `RDMA_READ_RESPONSE_FIRST :
                                (PktHeader_net_opcode == `RDMA_READ_REQUEST_MIDDLE) ? `RDMA_READ_RESPONSE_MIDDLE :
                                (PktHeader_net_opcode == `RDMA_READ_REQUEST_LAST) ? `RDMA_READ_RESPONSE_LAST :
                                (PktHeader_net_opcode == `RDMA_READ_REQUEST_ONLY) ? `RDMA_READ_RESPONSE_ONLY : 'd0;

wire            [31:0]              cur_wqe_size;
wire            [31:0]              next_wqe_size;
assign cur_wqe_size = wqe_resp_data[`NEXT_UNIT_CUR_WQE_SIZE_OFFSET];
assign next_wqe_size = wqe_resp_data[`NEXT_UNIT_NEXT_WQE_SIZE_OFFSET];

//Next Unit Field
//-- NextUnit_next_wqe_opcode --
//-- NextUnit_next_wqe_valid --
//-- NextUnit_next_wqe_addr --
//-- NextUnit_next_wqe_size --
//-- NextUnit_cur_wqe_size --
//-- NextUnit_cur_wqe_size_aligned --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        NextUnit_next_wqe_opcode <= 'd0;
        NextUnit_next_wqe_valid <= 'd0;
        NextUnit_next_wqe_addr <= 'd0;
        NextUnit_next_wqe_size <= 'd0;
        NextUnit_next_wqe_size_aligned <= 'd0;
        NextUnit_cur_wqe_size <= 'd0;
        NextUnit_cur_wqe_size_aligned <= 'd0;
    end
    else if(cur_state == NEXT_UNIT_s && wqe_resp_valid) begin
        NextUnit_next_wqe_opcode <= wqe_resp_data[`NEXT_UNIT_NEXT_WQE_OPCODE_OFFSET];
        NextUnit_next_wqe_valid <= (wqe_resp_data[`NEXT_UNIT_NEXT_WQE_SIZE_OFFSET] != 0);
        NextUnit_next_wqe_addr <= wqe_resp_data[`NEXT_UNIT_NEXT_WQE_ADDR_OFFSET];
        NextUnit_next_wqe_size <= wqe_resp_data[`NEXT_UNIT_NEXT_WQE_SIZE_OFFSET];
        NextUnit_cur_wqe_size <= wqe_resp_data[`NEXT_UNIT_CUR_WQE_SIZE_OFFSET];

        case(Cxt_rq_entry_sz_log)     //minimum 64, maximum 1024
            6:          NextUnit_next_wqe_size_aligned <= (next_wqe_size % 4) ? (next_wqe_size[31:2] + 32'd1) * 4 : next_wqe_size[31:2] * 4;
            7:          NextUnit_next_wqe_size_aligned <= (next_wqe_size % 8) ? (next_wqe_size[31:3] + 32'd1) * 8 : next_wqe_size[31:3] * 8;
            8:          NextUnit_next_wqe_size_aligned <= (next_wqe_size % 16) ? (next_wqe_size[31:4] + 32'd1) * 16 : next_wqe_size[31:4] * 16;
            9:          NextUnit_next_wqe_size_aligned <= (next_wqe_size % 32) ? (next_wqe_size[31:5] + 32'd1) * 32 : next_wqe_size[31:5] * 32;
            10:         NextUnit_next_wqe_size_aligned <= (next_wqe_size % 64) ? (next_wqe_size[31:6] + 32'd1) * 64 : next_wqe_size[31:6] * 64;
            default:    NextUnit_next_wqe_size_aligned <= 'd0;
        endcase  

        case(Cxt_rq_entry_sz_log)     //minimum 64, maximum 1024
            6:          NextUnit_cur_wqe_size_aligned <= (cur_wqe_size % 4) ? (cur_wqe_size[31:2] + 32'd1) * 4 : cur_wqe_size[31:2] * 4;
            7:          NextUnit_cur_wqe_size_aligned <= (cur_wqe_size % 8) ? (cur_wqe_size[31:3] + 32'd1) * 8 : cur_wqe_size[31:3] * 8;
            8:          NextUnit_cur_wqe_size_aligned <= (cur_wqe_size % 16) ? (cur_wqe_size[31:4] + 32'd1) * 16 : cur_wqe_size[31:4] * 16;
            9:          NextUnit_cur_wqe_size_aligned <= (cur_wqe_size % 32) ? (cur_wqe_size[31:5] + 32'd1) * 32 : cur_wqe_size[31:5] * 32;
            10:         NextUnit_cur_wqe_size_aligned <= (cur_wqe_size % 64) ? (cur_wqe_size[31:6] + 32'd1) * 64 : cur_wqe_size[31:6] * 64;
            default:    NextUnit_cur_wqe_size_aligned <= 'd0;
        endcase      

    end
    else begin
        NextUnit_next_wqe_opcode <= NextUnit_next_wqe_opcode;
        NextUnit_next_wqe_valid <= NextUnit_next_wqe_valid;
        NextUnit_next_wqe_addr <= NextUnit_next_wqe_addr;
        NextUnit_next_wqe_size <= NextUnit_next_wqe_size;
        NextUnit_next_wqe_size_aligned <= NextUnit_next_wqe_size_aligned;
        NextUnit_cur_wqe_size <= NextUnit_cur_wqe_size;
        NextUnit_cur_wqe_size_aligned <= NextUnit_cur_wqe_size_aligned;
    end
end

//-- DataUnit_byte_cnt --
//-- DataUnit_lkey --
//-- DataUnit_laddr --
assign DataUnit_byte_cnt = (cur_state == DATA_UNIT_s || cur_state == MR_FOR_SEND_s) && wqe_resp_valid ? wqe_resp_data[`DATA_UNIT_BYTE_CNT_OFFSET] : 'd0;
assign DataUnit_lkey = (cur_state == DATA_UNIT_s || cur_state == MR_FOR_SEND_s) && wqe_resp_valid ? wqe_resp_data[`DATA_UNIT_LKEY_OFFSET] : 'd0;
assign DataUnit_laddr = (cur_state == DATA_UNIT_s || cur_state == MR_FOR_SEND_s) && wqe_resp_valid ? wqe_resp_data[`DATA_UNIT_LADDR_OFFSET] : 'd0;

//-- parsed_msg_length --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        parsed_msg_length <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        parsed_msg_length <= 'd0;
    end
    else if(cur_state == DATA_UNIT_s && wqe_resp_valid && pkt_length_left > 0) begin 	//MR_FOR_SEND_s will use this variable
        if(parsed_msg_length + DataUnit_byte_cnt <= msg_offset_doutb) begin
            parsed_msg_length <= parsed_msg_length + DataUnit_byte_cnt;
        end
        else begin
            parsed_msg_length <= parsed_msg_length;
        end
    end
    else if(cur_state == MR_FOR_SEND_s && fetch_mr_ingress_valid && fetch_mr_ingress_ready) begin
        parsed_msg_length <= parsed_msg_length + DataUnit_byte_cnt;
    end
    else begin
        parsed_msg_length <= parsed_msg_length;
    end
end

//-- pkt_length_left --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        pkt_length_left <= 'd0;
    end
    else if(cur_state == JUDGE_s) begin
        pkt_length_left <= PktHeader_pkt_length;
    end
    else if(cur_state == MR_FOR_SEND_s && fetch_mr_ingress_valid && fetch_mr_ingress_ready) begin
        if(pkt_length_left > parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb) begin
            pkt_length_left <= pkt_length_left - (parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb);
        end
        else begin
            pkt_length_left <= 'd0;
        end
    end
    else begin
        pkt_length_left <= pkt_length_left;
    end
end

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

//-- ori_wqe_addr --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        ori_wqe_addr <= 'd0;        
    end
    else if (cur_state == NEXT_UNIT_s && wqe_resp_valid) begin
        ori_wqe_addr <= rq_offset_dout;
    end
    else begin
        ori_wqe_addr <= ori_wqe_addr;
    end
end

//-- tail_indicator --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		tail_indicator <= 'd0;
	end
	else if(cur_state == DATA_UNIT_s) begin
		if((parsed_msg_length + DataUnit_byte_cnt > msg_offset_doutb) && (pkt_length_left <= parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb)) begin
			tail_indicator <= `TAIL_FLAG;
		end
		else begin
			tail_indicator <= 'd0;
		end
	end
	else begin
		tail_indicator <= tail_indicator;
	end
end

//-- fetch_cxt_egress_ready --
assign fetch_cxt_egress_ready = (cur_state == IDLE_s) ? 'd1 : 'd0;

//-- wqe_req_valid --
//-- wqe_req_head --
//-- wqe_req_start --
//-- wqe_req_last --
assign wqe_req_valid = (cur_state == WQE_REQ_s) ? 'd1 : 'd0;
assign wqe_req_head = (cur_state == WQE_REQ_s) ? {  'd0,
                                                    Cxt_qp_pd, 
                                                    Cxt_rq_length, 
                                                    Cxt_rq_lkey, 
                                                    Cxt_rq_entry_sz_log, 
                                                    PktHeader_local_qpn} : 'd0;
assign wqe_req_start = (cur_state == WQE_REQ_s) ? 'd1 : 'd0;
assign wqe_req_last = (cur_state == WQE_REQ_s) ? 'd1 : 'd0;

//-- wqe_resp_ready --
always @(*) begin
	if(rst) begin
		wqe_resp_ready = 'd0;
	end
	else if(cur_state == NEXT_UNIT_s) begin
		wqe_resp_ready = 'd1;
	end
	else if(cur_state == DATA_UNIT_s && (PktHeader_net_opcode == `RDMA_WRITE_LAST_WITH_IMM || PktHeader_net_opcode == `RDMA_WRITE_ONLY_WITH_IMM)) begin
		wqe_resp_ready = 'd1;
	end
	else if(cur_state == DATA_UNIT_s && (PktHeader_net_opcode != `RDMA_WRITE_LAST_WITH_IMM && PktHeader_net_opcode != `RDMA_WRITE_ONLY_WITH_IMM)) begin
		if(pkt_length_left == 0) begin
            wqe_resp_ready = 'd1;      
        end
        else if(parsed_msg_length + DataUnit_byte_cnt <= msg_offset_doutb) begin
			wqe_resp_ready = 'd1;
		end
		else begin
			wqe_resp_ready = 'd0;
		end
	end
	else if(cur_state == MR_FOR_SEND_s && fetch_mr_ingress_valid && fetch_mr_ingress_ready) begin
		wqe_resp_ready = 'd1;
	end
	else begin
		wqe_resp_ready = 'd0;
	end
end

//-- cache_offset_wen --
//-- cache_offset_addr --
//-- cache_offset_din --
always @(*) begin
    if(rst) begin
        cache_offset_wen = 'd0;
        cache_offset_addr = 'd0;
        cache_offset_din = 'd0;
    end
    else if(cur_state == NEXT_UNIT_s) begin
        cache_offset_wen = 'd0;
        cache_offset_addr = PktHeader_local_qpn;
        cache_offset_din = 'd0;
    end
    else if(cur_state == UPDATE_RQ_s) begin //Current WQE is finished
        if(!NextUnit_next_wqe_valid) begin
            cache_offset_wen = 'd1;
            cache_offset_addr = PktHeader_local_qpn;
            cache_offset_din = 'd0;
        end
        else if(NextUnit_next_wqe_addr < rq_offset_dout) begin  //SQ wrap back
            cache_offset_wen = 'd1;
            cache_offset_addr = PktHeader_local_qpn;
            cache_offset_din = 'd0;
        end
        else if(cache_offset_dout + (NextUnit_next_wqe_addr - rq_offset_dout) + NextUnit_next_wqe_size > `RQ_CACHE_SLOT_NUM) begin     //Next WQE cross Cache Block boundary
            cache_offset_wen = 'd1;
            cache_offset_addr = PktHeader_local_qpn;
            cache_offset_din = 'd0;
        end
        else begin //Next WQE is in cache
            cache_offset_wen = 'd1;
            cache_offset_addr = PktHeader_local_qpn;
            cache_offset_din = cache_offset_dout + (NextUnit_next_wqe_addr - rq_offset_dout);
        end
    end
    else begin
        cache_offset_wen = 'd0;
        cache_offset_addr = PktHeader_local_qpn;
        cache_offset_din = 'd0;        
    end
end

//-- rq_offset_wen --
//-- rq_offset_addr --
//-- rq_offset_din --
always @(*) begin
    if(rst) begin
        rq_offset_wen = 'd0;
        rq_offset_addr = 'd0;
        rq_offset_din = 'd0;
    end
    else if(cur_state == IDLE_s) begin
        rq_offset_wen = 'd0;
        rq_offset_addr = 'd0;
        rq_offset_din = 'd0;
    end
    else if(cur_state == NEXT_UNIT_s) begin
        rq_offset_wen = 'd0;
        rq_offset_addr = PktHeader_local_qpn;
        rq_offset_din = 'd0;
    end
    else if(cur_state == UPDATE_RQ_s) begin
        rq_offset_wen = 'd1;
        rq_offset_addr = PktHeader_local_qpn;
        rq_offset_din = Cxt_rq_length - (rq_offset_dout + NextUnit_cur_wqe_size_aligned) * 16 < (32'd1 << Cxt_rq_entry_sz_log) ? 'd0 : rq_offset_dout + NextUnit_cur_wqe_size_aligned;
    end
    else begin
        rq_offset_wen = 'd0;
        rq_offset_addr = PktHeader_local_qpn;
        rq_offset_din = 'd0;
    end
end

// TODO, need to synchronize with WQEFetcher, helping it distinguish whether WQE cache buffer is valid
// cache_owned_wen --
// cache_owned_addr --
// cache_owned_din --
always @(*) begin
    if(rst) begin
        cache_owned_wen = 'd0;
        cache_owned_addr = 'd0;
        cache_owned_din = 'd0;
    end
    else if(cur_state == IDLE_s) begin
        cache_owned_wen = 'd0;
        cache_owned_addr = 'd0;
        cache_owned_din = 'd0;
    end
    else if(cur_state == NEXT_UNIT_s) begin
        cache_owned_wen = 'd0;
        cache_owned_addr = PktHeader_local_qpn;
        cache_owned_din = 'd0;
    end
    else if(cur_state == UPDATE_RQ_s) begin //Current WQE has been finished
        if(cache_owned_dout[`QP_NUM_LOG - `RQ_CACHE_CELL_NUM_LOG - 1 : 0] != PktHeader_local_qpn[`QP_NUM_LOG - 1 : 4]) begin //Curretn cell is already been replaced by another QP, do not touch it
            cache_owned_wen = 'd0;
            cache_owned_addr = PktHeader_local_qpn;
            cache_owned_din = 'd0;           
        end
        else if(!NextUnit_next_wqe_valid) begin
            cache_owned_wen = 'd1;
            cache_owned_addr = PktHeader_local_qpn;
            cache_owned_din = 'd0;              
        end
        else if(NextUnit_next_wqe_valid && NextUnit_next_wqe_addr == 0) begin    //Wrap back to SQ head, clear cache cell state
            cache_owned_wen = 'd1;
            cache_owned_addr = PktHeader_local_qpn;
            cache_owned_din = 'd0;     
        end
        else if(NextUnit_next_wqe_valid && (cache_offset_dout + NextUnit_cur_wqe_size_aligned + NextUnit_next_wqe_size_aligned > `RQ_CACHE_SLOT_NUM)) begin     //Cross Cache cell boundary
            cache_owned_wen = 'd1;
            cache_owned_addr = PktHeader_local_qpn;
            cache_owned_din = 'd0;              
        end
        else begin
            cache_owned_wen = 'd0;
            cache_owned_addr = PktHeader_local_qpn;
            cache_owned_din = 'd0;
        end
    end
    else begin
        cache_owned_wen = 'd0;
        cache_owned_addr = PktHeader_local_qpn;
        cache_owned_din = 'd0;          
    end
end


//-- msg_offset_wea --
//-- msg_offset_addra --
//-- msg_offset_dina --
always @(*) begin
	if (rst) begin
		msg_offset_wea = 'd0;
		msg_offset_addra = 'd0;
		msg_offset_dina = 'd0;
	end
	else if (cur_state == DATA_UNIT_s && wqe_resp_valid) begin
		if(msg_offset_doutb >= parsed_msg_length + DataUnit_byte_cnt) begin
			msg_offset_wea = 'd0;
			msg_offset_addra = PktHeader_local_qpn;
			msg_offset_dina = 'd0;			
		end
        else begin
            msg_offset_wea = 'd0;
            msg_offset_addra = PktHeader_local_qpn;
            msg_offset_dina = 'd0;
        end
	end
    else if(cur_state == MR_FOR_SEND_s && fetch_mr_ingress_valid && fetch_mr_ingress_ready) begin
        if(pkt_length_left <= parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb) begin
            msg_offset_wea = 'd1;
            msg_offset_addra = PktHeader_local_qpn;
            msg_offset_dina = msg_offset_doutb + pkt_length_left;
        end
        else begin
            msg_offset_wea = 'd1;
            msg_offset_addra = PktHeader_local_qpn;
            msg_offset_dina = parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb;
        end
    end
    else if(cur_state == UPDATE_RQ_s) begin
        msg_offset_wea = 'd1;
        msg_offset_addra = PktHeader_local_qpn;
        msg_offset_dina = 'd0;
    end
	else begin
		msg_offset_wea = 'd0;
		msg_offset_addra = 'd0;
		msg_offset_dina = 'd0;
	end
end

//-- msg_offset_addrb --
assign msg_offset_addrb = PktHeader_local_qpn;

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

/********************************************************* MR Request Decode : Begin ***********************************************************/
wire        [`MAX_QP_NUM_LOG - 1 : 0]               queue_index;
assign queue_index = {'d0, PktHeader_local_qpn[`QP_NUM_LOG - 1 : 0]};

//-- ingress_slot_count --
//-- ingress_common_head --
assign ingress_slot_count = (cur_state == MR_FOR_SEND_s) ? 'd1 :
                             (cur_state ==MR_FOR_WRITE_s) ? 'd1 : 
                             (cur_state == MR_FOR_READ_s) ? 'd1 :
                             (cur_state == MR_FOR_CQ_s) ? 'd1 : 
                             (cur_state == MR_FOR_EQ_s) ? 'd1 : 
                             (cur_state == GEN_ACK_s) ? 'd1 : 'd0;

assign ingress_common_head = (cur_state == MR_FOR_SEND_s) ? {`NO_BYPASS, ingress_slot_count, queue_index} :
                             (cur_state == MR_FOR_WRITE_s) ? {`NO_BYPASS, ingress_slot_count, queue_index} : 
                             (cur_state == MR_FOR_READ_s) ? {`NO_BYPASS, ingress_slot_count, queue_index} : 
                             (cur_state == MR_FOR_CQ_s) ? {`NO_BYPASS, ingress_slot_count, queue_index} : 
                             (cur_state == MR_FOR_EQ_s) ? {`NO_BYPASS, ingress_slot_count, queue_index} : 
                             (cur_state == GEN_ACK_s) ? {`BYPASS_MODE, ingress_slot_count, queue_index} : 'd0;

//-- fetch_mr_ingress_valid --
assign fetch_mr_ingress_valid = (cur_state == MR_FOR_SEND_s) ? 'd1 : 
                                (cur_state == MR_FOR_WRITE_s) ? 'd1 :
                                (cur_state == MR_FOR_READ_s) ? 'd1 :
                                (cur_state == MR_FOR_CQ_s) ? 'd1 :
                                (cur_state == MR_FOR_EQ_s) ? 'd1 : 
                                (cur_state == GEN_ACK_s) ? 'd1 : 'd0;

//-- fetch_mr_ingress_head --
assign fetch_mr_ingress_head = (cur_state == MR_FOR_SEND_s) ? {mr_length, mr_laddr, mr_lkey, mr_pd, mr_flags, ingress_common_head} :
                                (cur_state == MR_FOR_WRITE_s) ? {mr_length, mr_laddr, mr_lkey, mr_pd, mr_flags, ingress_common_head} :
                                (cur_state == MR_FOR_READ_s) ? {mr_length, mr_laddr, mr_lkey, mr_pd, mr_flags, ingress_common_head} :
                                (cur_state == MR_FOR_CQ_s) ? {mr_length, mr_laddr, mr_lkey, mr_pd, mr_flags, ingress_common_head} :
                                (cur_state == MR_FOR_EQ_s) ? {mr_length, mr_laddr, mr_lkey, mr_pd, mr_flags, ingress_common_head} :
                                (cur_state == GEN_ACK_s) ? {'d0, ingress_common_head} : 'd0;

//-- fetch_mr_ingress_data -- //Metadata passed to next pipeline stage
assign fetch_mr_ingress_data = 	(cur_state == MR_FOR_SEND_s) ? {32'd0, PktHeader_pkt_start_addr, PktHeader_sip, PktHeader_dip, PktHeader_smac, PktHeader_dmac, 16'd0, PktHeader_pkt_length, PktHeader_immediate, PktHeader_service_type, PktHeader_net_opcode, PktHeader_remote_qpn, tail_indicator, PktHeader_local_qpn} : 
								(cur_state == MR_FOR_WRITE_s) ? {32'd0, PktHeader_pkt_start_addr, PktHeader_sip, PktHeader_dip, PktHeader_smac, PktHeader_dmac, 16'd0, PktHeader_pkt_length, PktHeader_immediate, PktHeader_service_type, PktHeader_net_opcode, PktHeader_remote_qpn, `TAIL_FLAG, PktHeader_local_qpn} :
								(cur_state == MR_FOR_READ_s) ? {32'd0, PktHeader_pkt_start_addr, PktHeader_sip, PktHeader_dip, PktHeader_smac, PktHeader_dmac, 16'd0, PktHeader_pkt_length, PktHeader_immediate, PktHeader_service_type, PktHeader_resp_opcode, PktHeader_remote_qpn, `TAIL_FLAG, PktHeader_local_qpn} :
								(cur_state == MR_FOR_CQ_s) ? {ori_wqe_addr, PktHeader_pkt_start_addr, PktHeader_sip, PktHeader_dip, PktHeader_smac, PktHeader_dmac, 11'd0, PktHeader_net_opcode, PktHeader_pkt_length, PktHeader_immediate, PktHeader_service_type, `GEN_CQE, PktHeader_remote_qpn, `TAIL_FLAG, PktHeader_local_qpn} :
								(cur_state == MR_FOR_EQ_s) ? {32'd0, PktHeader_pkt_start_addr, PktHeader_sip, PktHeader_dip, PktHeader_smac, PktHeader_dmac, 16'd0, PktHeader_pkt_length, PktHeader_immediate, PktHeader_service_type, `GEN_EVENT, PktHeader_remote_qpn, `TAIL_FLAG, PktHeader_local_qpn} : 
								(cur_state == GEN_ACK_s) ? {32'd0, PktHeader_pkt_start_addr, PktHeader_sip, PktHeader_dip, PktHeader_smac, PktHeader_dmac, 16'd0, PktHeader_pkt_length, PktHeader_immediate, PktHeader_service_type, `ACKNOWLEDGE, PktHeader_remote_qpn, `TAIL_FLAG, PktHeader_local_qpn} : 'd0;

//-- fetch_mr_ingress_start --
assign fetch_mr_ingress_start = (cur_state == MR_FOR_SEND_s) ? 'd1 : 
                                (cur_state == MR_FOR_WRITE_s) ? 'd1 :
                                (cur_state == MR_FOR_READ_s) ? 'd1 :
                                (cur_state == MR_FOR_CQ_s) ? 'd1 :
                                (cur_state == MR_FOR_EQ_s) ? 'd1 : 
                                (cur_state == GEN_ACK_s) ? 'd1 : 'd0;

//-- fetch_mr_ingress_last --
assign fetch_mr_ingress_last =  (cur_state == MR_FOR_SEND_s) ? 'd1 : 
                                (cur_state == MR_FOR_WRITE_s) ? 'd1 :
                                (cur_state == MR_FOR_READ_s) ? 'd1 :
                                (cur_state == MR_FOR_CQ_s) ? 'd1 :
                                (cur_state == MR_FOR_EQ_s) ? 'd1 : 
                                (cur_state == GEN_ACK_s) ? 'd1 : 'd0;

//-- mr_length --
assign mr_length =  (cur_state == MR_FOR_SEND_s) ? (pkt_length_left < parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb ? pkt_length_left : parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb) :
                    (cur_state == MR_FOR_WRITE_s) ? PktHeader_pkt_length :
                    (cur_state == MR_FOR_READ_s) ? PktHeader_pkt_length :
                    (cur_state == MR_FOR_CQ_s) ? `CQE_LENGTH :
                    (cur_state == MR_FOR_EQ_s) ? `EVENT_LENGTH : 'd0;

//-- mr_laddr --
assign mr_laddr =   (cur_state == MR_FOR_SEND_s) ? DataUnit_laddr + (msg_offset_doutb - parsed_msg_length) :
                    (cur_state == MR_FOR_WRITE_s) ? PktHeader_raddr :
                    (cur_state == MR_FOR_READ_s) ? PktHeader_raddr :
                    (cur_state == MR_FOR_CQ_s) ?  cq_offset :
                    (cur_state == MR_FOR_EQ_s) ?  eq_offset : 'd0;

//-- mr_lkey --
assign mr_lkey =    (cur_state == MR_FOR_SEND_s) ? DataUnit_lkey :
                    (cur_state == MR_FOR_WRITE_s) ? PktHeader_rkey :
                    (cur_state == MR_FOR_READ_s) ? PktHeader_rkey :
                    (cur_state == MR_FOR_CQ_s) ?  Cxt_cq_lkey :
                    (cur_state == MR_FOR_EQ_s) ?  Cxt_eq_lkey : 'd0;;

//-- mr_pd --
assign mr_pd =      (cur_state == MR_FOR_SEND_s) ? Cxt_qp_pd :
                    (cur_state == MR_FOR_WRITE_s) ? Cxt_qp_pd :
                    (cur_state == MR_FOR_READ_s) ? Cxt_qp_pd :
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
    else if(cur_state == MR_FOR_SEND_s) begin
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
    else if(cur_state == MR_FOR_WRITE_s) begin
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
        mr_flag_remote_write = 'd1;
        mr_flag_local_write = 'd0;       
    end
    else if(cur_state == MR_FOR_READ_s) begin
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
        mr_flag_remote_read = 'd1;
        mr_flag_remote_write = 'd0;
        mr_flag_local_write = 'd0;       
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
assign mr_flags = (cur_state == MR_FOR_SEND_s || cur_state == MR_FOR_WRITE_s || cur_state == MR_FOR_READ_s || cur_state == MR_FOR_CQ_s || cur_state == MR_FOR_EQ_s) ?
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
`undef     HEADER_LOCAL_QPN_OFFSET
`undef     HEADER_REMOTE_QPN_OFFSET
`undef     HEADER_NET_OPCODE_OFFSET
`undef     HEADER_SERVICE_TYPE_OFFSET
`undef     HEADER_IMMEDIATE_OFFSET
`undef     HEADER_RKEY_OFFSET
`undef     HEADER_RADDR_OFFSET
`undef     HEADER_DMAC_OFFSET
`undef     HEADER_SMAC_OFFSET
`undef     HEADER_DIP_OFFSET
`undef     HEADER_SIP_OFFSET
`undef     HEADER_PKT_START_ADDR_OFFSET
`undef     HEADER_PKT_LENGTH_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule