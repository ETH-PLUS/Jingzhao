		/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ReqRecvCore_Thread_3
Author:     YangFan
Function:   1.Generate DMA Write.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module ReqRecvCore_Thread_3
#(
    parameter                       EGRESS_MR_HEAD_WIDTH                    =   128,
    parameter                       EGRESS_MR_DATA_WIDTH                    =   256
)
(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with OoOStation(For MRMgt)
    input   wire                                                            fetch_mr_egress_valid,
    input   wire    [`RX_REQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]              fetch_mr_egress_head,
    input   wire    [`RX_REQ_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]              fetch_mr_egress_data,
    input   wire                                                            fetch_mr_egress_start,
    input   wire                                                            fetch_mr_egress_last,
    output  wire                                                            fetch_mr_egress_ready,

//Interface with Packet Buffer
    output  wire                                                            delete_req_valid,
    output  wire    [`MAX_DB_SLOT_NUM_LOG * 2 - 1 : 0]                      delete_req_head,
    input   wire                                                            delete_req_ready,
                    
    input   wire                                                            delete_resp_valid,
    input   wire                                                            delete_resp_start,
    input   wire                                                            delete_resp_last,
    input   wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     delete_resp_data,
    output  wire                                                            delete_resp_ready,

//DMA Write Interface
    output  reg                                                             scatter_req_wr_en,
    output  reg     [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]       scatter_req_din,
    input   wire                                                            scatter_req_prog_full,

    output  reg                                                             scatter_data_wr_en,
    output  reg     [`DMA_DATA_WIDTH - 1: 0]                                scatter_data_din,
    input   wire                                                            scatter_data_prog_full,

//DMA Read Interface
    output  reg                                                             gather_req_wr_en,
    output  reg     [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]       gather_req_din,
    input   wire                                                            gather_req_prog_full,
    

//Interface with RespTransCore
    output  reg                                                             net_resp_wen,
    output  reg    [`NET_REQ_META_WIDTH - 1 : 0]                            net_resp_din,
    input   wire                                                            net_resp_prog_full
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     HEADER_LOCAL_QPN_OFFSET                     23:0
`define     HEADER_TAIL_INDICATOR_OFFSET                31:24 
`define     HEADER_REMOTE_QPN_OFFSET                    55:32
`define     HEADER_NET_OPCODE_OFFSET                    60:56
`define     HEADER_SERVICE_TYPE_OFFSET                  63:61
`define     HEADER_IMMEDIATE_OFFSET                     95:64
`define     HEADER_PKT_LENGTH_OFFSET                    111:96
`define     HEADER_DMAC_OFFSET                          175:128
`define     HEADER_SMAC_OFFSET                          223:176
`define     HEADER_DIP_OFFSET                           255:224
`define     HEADER_SIP_OFFSET                           287:256
`define     HEADER_CQE_OPCODE_OFFSET                    116:112
`define     HEADER_PKT_START_ADDR_OFFSET                303:288
`define     HEADER_ORI_WQE_ADDR_OFFSET                  351:320

`define     MCB_STATE_OFFSET                            3:0
`define     MCB_VALID_0_OFFSET                          27:24
`define     MCB_VALID_1_OFFSET                          31:28
`define     MCB_PAGE_0_SIZE_OFFSET                      63:32
`define     MCB_PAGE_0_ADDR_OFFSET                      127:64
`define     MCB_PAGE_1_SIZE_OFFSET                      159:128
`define     MCB_PAGE_1_ADDR_OFFSET                      223:160
`define     MCB_TAIL_INDICATOR_OFFSET                   231:224
`define     MCB_PKT_LENGTH_OFFSET                       247:232
`define     MCB_PKT_START_ADDR_OFFSET                   287:256
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg                 [`MR_RESP_WIDTH - 1 : 0]                        mr_resp_bus;
reg                 [`PKT_META_BUS_WIDTH - 1 : 0]                   pkt_header_bus;
reg                 [`MCB_META_WIDTH - 1 : 0]                       mcb_meta_bus;
                
wire                [23:0]                                          PktHeader_local_qpn;
wire                [23:0]                                          PktHeader_remote_qpn;
wire                [7:0]                                           PktHeader_tail_indicator;
wire                [4:0]                                           PktHeader_net_opcode;
wire                [4:0]                                           PktHeader_cqe_opcode;
wire                [2:0]                                           PktHeader_service_type;
wire                [47:0]                                          PktHeader_dmac;
wire                [47:0]                                          PktHeader_smac;
wire                [31:0]                                          PktHeader_dip;
wire                [31:0]                                          PktHeader_sip;
wire                [31:0]                                          PktHeader_immediate;
wire                [15:0]                                          PktHeader_pkt_length;
wire                [15:0]                                          PktHeader_pkt_start_addr;
wire                [31:0]                                          PktHeader_ori_wqe_addr;

wire                [3:0]                                           mr_resp_state;
wire                [3:0]                                           mr_resp_valid_0;
wire                [3:0]                                           mr_resp_valid_1;
wire                [31:0]                                          mr_resp_size_0;
wire                [31:0]                                          mr_resp_size_1;
wire                [63:0]                                          mr_resp_phy_addr_0;
wire                [63:0]                                          mr_resp_phy_addr_1;

wire                [3:0]                                           mcb_mr_state;
wire                [3:0]                                           mcb_mr_valid_0;
wire                [3:0]                                           mcb_mr_valid_1;
wire                [31:0]                                          mcb_mr_size_0;
wire                [31:0]                                          mcb_mr_size_1;
wire                [63:0]                                          mcb_mr_phy_addr_0;
wire                [63:0]                                          mcb_mr_phy_addr_1;
wire                [7:0]                                           mcb_tail_indicator;
wire                [15:0]                                          mcb_pkt_start_addr;
wire                [15:0]                                          mcb_pkt_length;

wire                                                                mcb_enqueue_req_valid;
wire                [`QP_NUM_LOG + `MAX_DMQ_SLOT_NUM_LOG - 1 : 0]   mcb_enqueue_req_head;
wire                [`MCB_SLOT_WIDTH - 1 : 0]                       mcb_enqueue_req_data;
wire                                                                mcb_enqueue_req_start;
wire                                                                mcb_enqueue_req_last;
wire                                                                mcb_enqueue_req_ready;

wire                                                                mcb_dequeue_req_valid;
wire                [`QP_NUM_LOG + `MAX_DMQ_SLOT_NUM_LOG - 1 : 0]   mcb_dequeue_req_head;
wire                                                                mcb_dequeue_req_ready;

wire                                                                mcb_dequeue_resp_valid;
wire                [`QP_NUM_LOG + `MAX_DMQ_SLOT_NUM_LOG - 1 : 0]   mcb_dequeue_resp_head;
wire                                                                mcb_dequeue_resp_start;
wire                                                                mcb_dequeue_resp_last;
wire                                                                mcb_dequeue_resp_ready;
wire                [`MCB_SLOT_WIDTH - 1 : 0]                       mcb_dequeue_resp_data;

wire                [255:0]                                         cqe_data;
reg                 [31:0]                                          cqe_my_qpn;
reg                 [31:0]                                          cqe_my_ee;
reg                 [31:0]                                          cqe_rqpn;
reg                 [7:0]                                           cqe_sl_ipok;
reg                 [7:0]                                           cqe_g_mlpath;
reg                 [15:0]                                          cqe_rlid;
reg                 [31:0]                                          cqe_imm_etype_pkey_eec;
reg                 [31:0]                                          cqe_byte_cnt;
reg                 [31:0]                                          cqe_wqe;
reg                 [7:0]                                           cqe_opcode;
reg                 [7:0]                                           cqe_is_send;
reg                 [7:0]                                           cqe_owner;

wire                [0:0]                                           byte_cnt_buffer_wea;
wire                [`QP_NUM_LOG - 1 : 0]                           byte_cnt_buffer_addra;
wire                [31:0]                                          byte_cnt_buffer_dina;

wire                [`QP_NUM_LOG - 1 : 0]                           byte_cnt_buffer_addrb;
wire                [31:0]                                          byte_cnt_buffer_doutb;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*  Why we need this DMQ?
    The reason is that a send packet may be mapped to different SGL. In ReqRecvCore_Thread_2, we have issued multiple MR reqs for a Send, these MRs will be returned 
    in order for the same QP, but may be interweaved with MR reqs of other QPs. Since a Send pkt should be DMAed atomicly, we use this DMQ to ensure that a Send will be 
    executed when multiple MRs are collected entirely.
*/

DynamicMultiQueue #(
    .SLOT_WIDTH                 (   512                         ),
    .SLOT_NUM                   (   32                          ),
    .QUEUE_NUM                  (   `QP_NUM                     )
) MetaCollectionBuffer_Inst (
    .clk                        (   clk                         ),
    .rst                        (   rst                         ),

    .i_enqueue_req_valid        (   mcb_enqueue_req_valid       ),
    .iv_enqueue_req_head        (   mcb_enqueue_req_head        ),
    .iv_enqueue_req_data        (   mcb_enqueue_req_data        ),
    .i_enqueue_req_start        (   mcb_enqueue_req_start       ),
    .i_enqueue_req_last         (   mcb_enqueue_req_last        ),
    .o_enqueue_req_ready        (   mcb_enqueue_req_ready       ),

    .i_empty_req_valid          (   mcb_empty_req_valid         ),
    .iv_empty_req_head          (   mcb_empty_req_head          ),
    .o_empty_req_ready          (   mcb_empty_req_ready         ),

    .o_empty_resp_valid         (   mcb_empty_resp_valid        ),
    .ov_empty_resp_head         (   mcb_empty_resp_head         ),
    .i_empty_resp_ready         (   mcb_empty_resp_ready        ),

    .i_dequeue_req_valid        (   mcb_dequeue_req_valid       ),
    .iv_dequeue_req_head        (   mcb_dequeue_req_head        ),
    .o_dequeue_req_ready        (   mcb_dequeue_req_ready       ),

    .o_dequeue_resp_valid       (   mcb_dequeue_resp_valid      ),
    .ov_dequeue_resp_head       (   mcb_dequeue_resp_head       ),
    .o_dequeue_resp_start       (   mcb_dequeue_resp_start      ),
    .o_dequeue_resp_last        (   mcb_dequeue_resp_last       ),
    .i_dequeue_resp_ready       (   mcb_dequeue_resp_ready      ),
    .ov_dequeue_resp_data       (   mcb_dequeue_resp_data       ),

    .i_modify_head_req_valid    (   'd0                         ),
    .iv_modify_head_req_head    (   'd0                         ),
    .iv_modify_head_req_data    (   'd0                         ),
    .o_modify_head_req_ready    (                               ),

    .i_get_req_valid            (   'd0                         ),
    .iv_get_req_head            (   'd0                         ),
    .o_get_req_ready            (                               ),

    .o_get_resp_valid           (                               ),
    .ov_get_resp_head           (                               ),
    .o_get_resp_start           (                               ),
    .o_get_resp_last            (                               ),
    .ov_get_resp_data           (                               ),
    .o_get_resp_empty           (                               ),
    .i_get_resp_ready           (   'd0                         )
);


SRAM_SDP_Template #(
    .RAM_WIDTH      (   32                                      ),
    .RAM_DEPTH      (   `QP_NUM                                 )
)
CacheBuffer
(
    .clk            (   clk                                     ),
    .rst            (   rst                                     ),

    .wea            (   byte_cnt_buffer_wea                     ),
    .addra          (   byte_cnt_buffer_addra                   ),
    .dina           (   byte_cnt_buffer_dina                    ),

    .addrb          (   byte_cnt_buffer_addrb                   ),
    .doutb          (   byte_cnt_buffer_doutb                   )
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg                 [4:0]                                           cur_state;
reg                 [4:0]                                           next_state;

parameter           [4:0]                       IDLE_s                  = 5'd1,
                                                JUDGE_s                 = 5'd2,
                                                ENQUEUE_META_REQ_s      = 5'd3,
                                                DEQUEUE_META_REQ_s      = 5'd4,
                                                DEQUEUE_META_RESP_s     = 5'd5,
                                                GET_SEND_PAYLOAD_s      = 5'd6,
                                                GET_WRITE_PAYLOAD_s     = 5'd7,
                                                DMA_SEND_PAGE_0_REQ_s   = 5'd8,
                                                DMA_SEND_PAGE_1_REQ_s   = 5'd9,
                                                DMA_SEND_DATA_s         = 5'd10,
                                                DMA_WRITE_PAGE_0_REQ_s  = 5'd11,
                                                DMA_WRITE_PAGE_1_REQ_s  = 5'd12,
                                                DMA_WRITE_DATA_s        = 5'd13,
                                                DMA_CQE_s               = 5'd14,
                                                DMA_EVENT_s             = 5'd15,
                                                DMA_INT_s               = 5'd16,
                                                DMA_READ_PAGE_0_REQ_s   = 5'd17,
                                                DMA_READ_PAGE_1_REQ_s   = 5'd18,
                                                GEN_RESP_s              = 5'd19;

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
        IDLE_s:                     if(fetch_mr_egress_valid) begin
                                        next_state = JUDGE_s;
                                    end
                                    else begin
                                        next_state = IDLE_s;
                                    end
        JUDGE_s:                    if(PktHeader_net_opcode == `SEND_FIRST || PktHeader_net_opcode == `SEND_MIDDLE || PktHeader_net_opcode == `SEND_LAST ||
                                                PktHeader_net_opcode == `SEND_ONLY || PktHeader_net_opcode == `SEND_LAST_WITH_IMM || PktHeader_net_opcode == `SEND_ONLY_WITH_IMM) begin   //Not empty, need to enqueue current REQ, current Req must be Send. If current Req is not send DMQ must be empty
                                        next_state = ENQUEUE_META_REQ_s;
                                    end
                                    else if(PktHeader_net_opcode == `RDMA_WRITE_FIRST || PktHeader_net_opcode == `RDMA_WRITE_MIDDLE || PktHeader_net_opcode == `RDMA_WRITE_LAST ||
                                            PktHeader_net_opcode == `RDMA_WRITE_ONLY || PktHeader_net_opcode == `RDMA_WRITE_LAST_WITH_IMM || PktHeader_net_opcode == `RDMA_WRITE_ONLY_WITH_IMM) begin
                                        next_state = GET_WRITE_PAYLOAD_s;
                                    end
                                    else if(PktHeader_net_opcode == `RDMA_READ_RESPONSE_FIRST || PktHeader_net_opcode == `RDMA_READ_RESPONSE_MIDDLE || PktHeader_net_opcode == `RDMA_READ_RESPONSE_LAST ||
                                            PktHeader_net_opcode == `RDMA_READ_RESPONSE_ONLY) begin
                                        next_state = DMA_READ_PAGE_0_REQ_s;
                                    end
                                    else if(PktHeader_net_opcode == `ACKNOWLEDGE) begin
                                        next_state = GEN_RESP_s;
                                    end
                                    else if(PktHeader_net_opcode == `GEN_CQE) begin
                                        next_state = DMA_CQE_s;
                                    end
                                    else if(PktHeader_net_opcode == `GEN_EVENT) begin
                                        next_state = DMA_EVENT_s;
                                    end
                                    else if(PktHeader_net_opcode == `GEN_INT) begin
                                        next_state = DMA_INT_s;
                                    end
                                    else begin      //Unexpected state
                                        next_state = IDLE_s; 
                                    end
        ENQUEUE_META_REQ_s:         if(mcb_enqueue_req_valid && mcb_enqueue_req_ready) begin
                                        if(PktHeader_tail_indicator == `TAIL_FLAG) begin
                                            next_state = DEQUEUE_META_REQ_s;
                                        end
                                        else begin
                                            next_state = IDLE_s;
                                        end
                                    end
                                    else begin
                                        next_state = ENQUEUE_META_REQ_s;
                                    end
        DEQUEUE_META_REQ_s:         if(mcb_dequeue_req_valid && mcb_dequeue_req_ready) begin
                                        next_state = DEQUEUE_META_RESP_s;
                                    end
                                    else begin
                                        next_state = DEQUEUE_META_REQ_s;
                                    end
        DEQUEUE_META_RESP_s:        if(mcb_dequeue_resp_valid && mcb_dequeue_resp_ready) begin
                                        next_state = DMA_SEND_PAGE_0_REQ_s;
                                    end
                                    else begin
                                        next_state = DEQUEUE_META_RESP_s;
                                    end
        DMA_SEND_PAGE_0_REQ_s:      if(!scatter_req_prog_full) begin
                                        if(mcb_mr_valid_1) begin
                                            next_state = DMA_SEND_PAGE_1_REQ_s;
                                        end
                                        else if(mcb_tail_indicator == `TAIL_FLAG) begin
                                            next_state = GET_SEND_PAYLOAD_s;
                                        end
                                        else begin
                                            next_state = DEQUEUE_META_REQ_s;
                                        end
                                    end
                                    else begin
                                        next_state = DMA_SEND_PAGE_0_REQ_s;
                                    end
        DMA_SEND_PAGE_1_REQ_s:      if(!scatter_req_prog_full) begin
                                        if(mcb_tail_indicator == `TAIL_FLAG) begin
                                            next_state = GET_SEND_PAYLOAD_s;
                                        end
                                        else begin
                                            next_state = DEQUEUE_META_REQ_s;
                                        end
                                    end
                                    else begin
                                        next_state = DMA_SEND_PAGE_1_REQ_s;
                                    end
        GET_SEND_PAYLOAD_s:         if(delete_req_valid && delete_req_ready) begin
                                        next_state = DMA_SEND_DATA_s;
                                    end
                                    else begin
                                        next_state = GET_SEND_PAYLOAD_s;
                                    end
        GET_WRITE_PAYLOAD_s:        if(delete_req_valid && delete_req_ready) begin
                                        next_state = DMA_WRITE_PAGE_0_REQ_s;
                                    end
                                    else begin
                                        next_state = GET_WRITE_PAYLOAD_s;
                                    end
        DMA_SEND_DATA_s:            if(delete_resp_valid && delete_resp_last && !scatter_data_prog_full) begin
                                        next_state = IDLE_s;
                                    end
                                    else begin
                                        next_state = DMA_SEND_DATA_s;
                                    end
        DMA_WRITE_PAGE_0_REQ_s:     if(!scatter_req_prog_full) begin
                                        if(mr_resp_valid_1) begin
                                            next_state = DMA_WRITE_PAGE_1_REQ_s;
                                        end
                                        else begin
                                            next_state = DMA_WRITE_DATA_s;
                                        end
                                    end
                                    else begin
                                        next_state = DMA_WRITE_PAGE_0_REQ_s;
                                    end
        DMA_WRITE_PAGE_1_REQ_s:     if(!scatter_req_prog_full) begin
                                        next_state = DMA_WRITE_DATA_s;
                                    end
                                    else begin
                                        next_state = DMA_WRITE_PAGE_1_REQ_s;
                                    end
        DMA_WRITE_DATA_s:           if(delete_resp_valid && delete_resp_last && !scatter_data_prog_full) begin
                                        next_state = IDLE_s;
                                    end
                                    else begin
                                        next_state = DMA_WRITE_DATA_s;
                                    end
        DMA_CQE_s:                  if(!scatter_req_prog_full && !scatter_data_prog_full) begin
                                        next_state = IDLE_s;
                                    end
                                    else begin
                                        next_state = DMA_CQE_s;
                                    end
        DMA_EVENT_s:                if(!scatter_req_prog_full && !scatter_data_prog_full) begin
                                        next_state = IDLE_s;
                                    end
                                    else begin
                                        next_state = DMA_EVENT_s;
                                    end
        DMA_INT_s:                  if(!scatter_req_prog_full && !scatter_data_prog_full) begin
                                        next_state = IDLE_s;
                                    end
                                    else begin
                                        next_state = DMA_INT_s;
                                    end
        DMA_READ_PAGE_0_REQ_s:      if(!gather_req_prog_full) begin
                                        if(mr_resp_valid_1) begin
                                            next_state = DMA_READ_PAGE_1_REQ_s;
                                        end
                                        else begin
                                            next_state = GEN_RESP_s;
                                        end
                                    end
                                    else begin
                                        next_state = DMA_READ_PAGE_0_REQ_s;
                                    end
        DMA_READ_PAGE_1_REQ_s:      if(!gather_req_prog_full) begin
                                        next_state = GEN_RESP_s;
                                    end
                                    else begin
                                        next_state = DMA_READ_PAGE_1_REQ_s;
                                    end
        GEN_RESP_s:                 if(!net_resp_prog_full) begin
                                        next_state = IDLE_s;
                                    end
                                    else begin
                                        next_state = GEN_RESP_s;
                                    end
        default:                    next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- pkt_header_bus --
//-- mr_resp_bus --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        pkt_header_bus <= 'd0;
        mr_resp_bus <= 'd0;     
    end
    else if (cur_state == IDLE_s && fetch_mr_egress_valid) begin
        pkt_header_bus <= fetch_mr_egress_data;
        mr_resp_bus <= fetch_mr_egress_head[`MR_RESP_WIDTH + `EGRESS_COMMON_HEAD_WIDTH - 1 : `EGRESS_COMMON_HEAD_WIDTH];
    end
    else begin
        pkt_header_bus <= pkt_header_bus;
        mr_resp_bus <= mr_resp_bus;
    end
end

//-- PktHeader_local_qpn --
//-- PktHeader_remote_qpn --
//-- PktHeader_tail_indicator --
//-- PktHeader_net_opcode --
//-- PktHeader_service_type --
//-- PktHeader_dmac --
//-- PktHeader_smac --
//-- PktHeader_dip --
//-- PktHeader_sip --
//-- PktHeader_immediate --
//-- PktHeader_pkt_length --
//-- PktHeader_ori_wqe_addr --
//-- PktHeader_pkt_start_addr --
assign PktHeader_local_qpn = pkt_header_bus[`HEADER_LOCAL_QPN_OFFSET];
assign PktHeader_remote_qpn = pkt_header_bus[`HEADER_REMOTE_QPN_OFFSET];
assign PktHeader_tail_indicator = pkt_header_bus[`HEADER_TAIL_INDICATOR_OFFSET];
assign PktHeader_net_opcode = pkt_header_bus[`HEADER_NET_OPCODE_OFFSET];
assign PktHeader_cqe_opcode = pkt_header_bus[`HEADER_CQE_OPCODE_OFFSET];
assign PktHeader_service_type = pkt_header_bus[`HEADER_SERVICE_TYPE_OFFSET];
assign PktHeader_dmac = pkt_header_bus[`HEADER_DMAC_OFFSET];
assign PktHeader_smac = pkt_header_bus[`HEADER_SMAC_OFFSET];
assign PktHeader_dip = pkt_header_bus[`HEADER_DIP_OFFSET];
assign PktHeader_sip = pkt_header_bus[`HEADER_SIP_OFFSET];
assign PktHeader_immediate = pkt_header_bus[`HEADER_IMMEDIATE_OFFSET];
assign PktHeader_pkt_length = pkt_header_bus[`HEADER_PKT_LENGTH_OFFSET];
assign PktHeader_ori_wqe_addr = pkt_header_bus[`HEADER_ORI_WQE_ADDR_OFFSET];
assign PktHeader_pkt_start_addr = pkt_header_bus[`HEADER_PKT_START_ADDR_OFFSET];

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

//-- mcb_meta_bus --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        mcb_meta_bus <= 'd0;
    end
    else if(cur_state == DEQUEUE_META_RESP_s && mcb_dequeue_resp_valid) begin
        mcb_meta_bus <= mcb_dequeue_resp_data;
    end
    else begin
        mcb_meta_bus <= mcb_meta_bus;
    end
end

//-- mcb_mr_state --
//-- mcb_mr_valid_0 --
//-- mcb_mr_valid_1 --
//-- mcb_mr_size_0 --
//-- mcb_mr_size_1 --
//-- mcb_mr_phy_addr_0 --
//-- mcb_mr_phy_addr_1 --
//-- mcb_tail_indicator --
//-- mcb_pkt_start_addr --
//-- mcb_pkt_length --
assign mcb_mr_state = mcb_meta_bus[`MCB_STATE_OFFSET];
assign mcb_mr_valid_0 = mcb_meta_bus[`MCB_VALID_0_OFFSET];
assign mcb_mr_valid_1 = mcb_meta_bus[`MCB_VALID_1_OFFSET];
assign mcb_mr_size_0 = mcb_meta_bus[`MCB_PAGE_0_SIZE_OFFSET];
assign mcb_mr_size_1 = mcb_meta_bus[`MCB_PAGE_1_SIZE_OFFSET];
assign mcb_mr_phy_addr_0 = mcb_meta_bus[`MCB_PAGE_0_ADDR_OFFSET];
assign mcb_mr_phy_addr_1 = mcb_meta_bus[`MCB_PAGE_1_ADDR_OFFSET];
assign mcb_tail_indicator = mcb_meta_bus[`MCB_TAIL_INDICATOR_OFFSET];
assign mcb_pkt_start_addr = mcb_meta_bus[`MCB_PKT_START_ADDR_OFFSET];
assign mcb_pkt_length = mcb_meta_bus[`MCB_PKT_LENGTH_OFFSET];

//-- mcb_enqueue_req_valid --
//-- mcb_enqueue_req_head --
//-- mcb_enqueue_req_data --
//-- mcb_enqueue_req_start --
//-- mcb_enqueue_req_last --
assign mcb_enqueue_req_valid = (cur_state == ENQUEUE_META_REQ_s) ? 'd1 : 'd0;
assign mcb_enqueue_req_head = (cur_state == ENQUEUE_META_REQ_s) ? {'d1, PktHeader_local_qpn[`MAX_QP_NUM_LOG - 1 : 0]} : 'd0;
assign mcb_enqueue_req_data = (cur_state == ENQUEUE_META_REQ_s) ? {PktHeader_pkt_start_addr, 8'd0, PktHeader_pkt_length, PktHeader_tail_indicator, mr_resp_phy_addr_1, mr_resp_size_1, mr_resp_phy_addr_0, mr_resp_size_0, mr_resp_valid_1, mr_resp_valid_0, 20'd0, mr_resp_state} : 'd0;
assign mcb_enqueue_req_start = (cur_state == ENQUEUE_META_REQ_s) ? 'd1 : 'd0;
assign mcb_enqueue_req_last = (cur_state == ENQUEUE_META_REQ_s) ? 'd1 : 'd0;

//-- mcb_dequeue_req_valid --
//-- mcb_dequeue_req_head --
assign mcb_dequeue_req_valid = (cur_state == DEQUEUE_META_REQ_s) ? 'd1 : 'd0;
assign mcb_dequeue_req_head = (cur_state == DEQUEUE_META_REQ_s) ? {'d1, PktHeader_local_qpn[`MAX_QP_NUM_LOG - 1 : 0]} : 'd0;

//-- mcb_dequeue_resp_ready --
assign mcb_dequeue_resp_ready = (cur_state == DEQUEUE_META_RESP_s) ? 'd1 : 'd0;



//-- fetch_mr_egress_ready --
assign fetch_mr_egress_ready = (cur_state == IDLE_s) ? 'd1 : 'd0;

//-- delete_req_valid --
//-- delete_req_head --
assign delete_req_valid = (cur_state == GET_SEND_PAYLOAD_s) ? 'd1 : 
                            (cur_state == GET_WRITE_PAYLOAD_s) ? 'd1 : 'd0; 
assign delete_req_head = (cur_state == GET_SEND_PAYLOAD_s) ? {(mcb_pkt_length[5:0] ? (mcb_pkt_length >> 6) + 1 : mcb_pkt_length >> 6), mcb_pkt_start_addr} : 
                            (cur_state == GET_WRITE_PAYLOAD_s) ? {(PktHeader_pkt_length[5:0] ? (PktHeader_pkt_length >> 6) + 1 : PktHeader_pkt_length >> 6), PktHeader_pkt_start_addr} : 'd0;

//-- delete_resp_ready --
assign delete_resp_ready = (cur_state == DMA_SEND_DATA_s || cur_state == DMA_WRITE_DATA_s) ? !scatter_data_prog_full : 'd0;

//-- scatter_req_wr_en --
//-- scatter_req_din --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        scatter_req_wr_en <= 'd0;
        scatter_req_din <= 'd0;
    end
    else if (cur_state == DMA_SEND_PAGE_0_REQ_s && !scatter_req_prog_full) begin
        scatter_req_wr_en <= 'd1;
        scatter_req_din <= {mcb_pkt_length, mcb_mr_size_0, mcb_mr_phy_addr_0};
    end
    else if (cur_state == DMA_SEND_PAGE_1_REQ_s && !scatter_req_prog_full) begin
        scatter_req_wr_en <= 'd1;
        scatter_req_din <= {mcb_pkt_length, mcb_mr_size_1, mcb_mr_phy_addr_1};
    end
    else if (cur_state == DMA_WRITE_PAGE_0_REQ_s && !scatter_req_prog_full) begin
        scatter_req_wr_en <= 'd1;
        scatter_req_din <= {PktHeader_pkt_length, mr_resp_size_0, mr_resp_phy_addr_0};
    end
    else if (cur_state == DMA_WRITE_PAGE_1_REQ_s && !scatter_req_prog_full) begin
        scatter_req_wr_en <= 'd1;
        scatter_req_din <= {PktHeader_pkt_length, mr_resp_size_1, mr_resp_phy_addr_1};
    end
    else if (cur_state == DMA_CQE_s && !scatter_req_prog_full && !scatter_data_prog_full) begin
        scatter_req_wr_en <= 'd1;
        scatter_req_din <= {`CQE_LENGTH, mr_resp_size_0, mr_resp_phy_addr_0};
    end
    else begin
        scatter_req_wr_en <= 'd0;
        scatter_req_din <= 'd0;
    end
end

//-- scatter_data_wr_en --
//-- scatter_data_din --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        scatter_data_wr_en <= 'd0;
        scatter_data_din <= 'd0;
    end
    else if ((cur_state == DMA_SEND_DATA_s || cur_state ==  DMA_WRITE_DATA_s) && delete_resp_valid && !scatter_data_prog_full) begin
        scatter_data_wr_en <= 'd1;
        scatter_data_din <= delete_resp_data;
    end
    else if (cur_state == DMA_CQE_s && !scatter_req_prog_full && !scatter_data_prog_full) begin
        scatter_data_wr_en <= 'd1;
        scatter_data_din <= cqe_data;
    end
    else begin
        scatter_data_wr_en <= 'd0;
        scatter_data_din <= 'd0;
    end
end

//-- gather_req_wr_en --
//-- gather_req_din --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        gather_req_wr_en <= 'd0;
        gather_req_din <= 'd0;        
    end
    else if (cur_state == DMA_READ_PAGE_0_REQ_s && !gather_req_prog_full) begin
        gather_req_wr_en <= 'd1;
        gather_req_din <= {PktHeader_pkt_length, mr_resp_size_0, mr_resp_phy_addr_0};
    end
    else if (cur_state == DMA_READ_PAGE_1_REQ_s && !gather_req_prog_full) begin
        gather_req_wr_en <= 'd1;
        gather_req_din <= {PktHeader_pkt_length, mr_resp_size_1, mr_resp_phy_addr_1};
    end
    else begin
        gather_req_wr_en <= 'd0;
        gather_req_din <= 'd0;
    end
end

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
    if (rst) begin
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
    else if (cur_state == JUDGE_s && PktHeader_net_opcode == `GEN_CQE) begin
        cqe_my_qpn <= PktHeader_local_qpn;
        cqe_my_ee <= 'd0;
        cqe_rqpn <= PktHeader_remote_qpn;
        cqe_sl_ipok <= 'd0;
        cqe_g_mlpath <= 'd0;
        cqe_rlid <= PktHeader_dmac[15:0];
        cqe_imm_etype_pkey_eec <= 'd0;
        cqe_byte_cnt <= byte_cnt_buffer_doutb;
        cqe_wqe <= PktHeader_ori_wqe_addr;
        cqe_opcode <= PktHeader_cqe_opcode;
        cqe_is_send <= 'd0;
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
assign cqe_data = (cur_state == DMA_CQE_s) ? {  cqe_owner, 8'd0, cqe_is_send, cqe_opcode, cqe_wqe, cqe_byte_cnt, cqe_imm_etype_pkey_eec,
                                                cqe_rlid, cqe_g_mlpath, cqe_sl_ipok, cqe_rqpn, cqe_my_ee, cqe_my_qpn} : 'd0;

//-- byte_cnt_buffer_wea --
//-- byte_cnt_buffer_addra --
//-- byte_cnt_buffer_dina --
assign byte_cnt_buffer_wea = (cur_state == DMA_SEND_DATA_s && next_state != DMA_SEND_DATA_s) || (cur_state == DMA_WRITE_DATA_s && next_state != DMA_WRITE_DATA_s) ? 'd1 : 'd0;
assign byte_cnt_buffer_addra = PktHeader_local_qpn;
assign byte_cnt_buffer_dina = (cur_state == DMA_SEND_DATA_s && next_state != DMA_SEND_DATA_s) ? mcb_pkt_length + byte_cnt_buffer_doutb :
                              (cur_state == DMA_WRITE_DATA_s && next_state != DMA_WRITE_DATA_s) ? PktHeader_pkt_length + byte_cnt_buffer_doutb : 'd0;

//-- byte_cnt_buffer_addrb --
assign byte_cnt_buffer_addrb = PktHeader_local_qpn;

//-- net_resp_wen --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        net_resp_wen <= 'd0;
    end
    else if (cur_state == GEN_RESP_s && !net_resp_prog_full) begin
        net_resp_wen <= 'd1;
    end
    else begin
        net_resp_wen <= 'd0;
    end
end

//-- net_resp_din --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        net_resp_din <= 'd0;
    end
    else if(cur_state == GEN_RESP_s) begin
        net_resp_din <= {'d0, PktHeader_pkt_length, PktHeader_sip, PktHeader_dip, PktHeader_smac, PktHeader_dmac, PktHeader_service_type, PktHeader_net_opcode, PktHeader_remote_qpn, 8'd0, PktHeader_local_qpn};
    end
    else begin
        net_resp_din <= net_resp_din;
    end
end
/*------------------------------------------- Variables Decode : End ----------------------------------------------***/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef     HEADER_LOCAL_QPN_OFFSET
`undef     HEADER_TAIL_INDICATOR_OFFSET
`undef     HEADER_REMOTE_QPN_OFFSET
`undef     HEADER_NET_OPCODE_OFFSET
`undef     HEADER_SERVICE_TYPE_OFFSET
`undef     HEADER_IMMEDIATE_OFFSET
`undef     HEADER_PKT_LENGTH_OFFSET
`undef     HEADER_DMAC_OFFSET
`undef     HEADER_SMAC_OFFSET
`undef     HEADER_DIP_OFFSET
`undef     HEADER_SIP_OFFSET
`undef     HEADER_CQE_OPCODE_OFFSET
`undef     HEADER_PKT_START_ADDR_OFFSET
`undef     HEADER_ORI_WQE_ADDR_OFFSET

`undef     MCB_STATE_OFFSET
`undef     MCB_VALID_0_OFFSET
`undef     MCB_VALID_1_OFFSET
`undef     MCB_PAGE_0_SIZE_OFFSET
`undef     MCB_PAGE_0_ADDR_OFFSET
`undef     MCB_PAGE_1_SIZE_OFFSET
`undef     MCB_PAGE_1_ADDR_OFFSET
`undef     MCB_TAIL_INDICATOR_OFFSET
`undef     MCB_PKT_LENGTH_OFFSET
`undef     MCB_PKT_START_ADDR_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule