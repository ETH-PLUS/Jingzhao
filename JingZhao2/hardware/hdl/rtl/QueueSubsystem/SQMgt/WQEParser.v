/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       WQEParser
Author:     YangFan
Function:   1.Parse Send WQE, split a WQE into sub-WQEs, which carries MTU-less data.
            2.Synchronize with WQECache(update cache offset table and cache owned table), which helps WQEFetch decide how to fetch WQE.
            3.Update SQ Offset Status(Each time finish a WQE, move SQ offset pointer forward).
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module WQEParser
#(
	parameter 	CACHE_SLOT_NUM 			=		256,
	parameter 	CACHE_SLOT_NUM_LOG 		=		log2b(CACHE_SLOT_NUM),

	parameter 	CACHE_CELL_NUM 			=		256,
	parameter 	CACHE_CELL_NUM_LOG 		=		log2b(CACHE_CELL_NUM)
)
(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with WQEFetch
    input   wire                                                            wqe_valid,
    input   wire    [`WQE_PARSER_META_WIDTH - 1 : 0]                       	wqe_head,
    input   wire    [`WQE_SEG_WIDTH - 1 : 0]                                wqe_data,
    input   wire                                                            wqe_start,
    input   wire                                                            wqe_last,
    output  wire                                                            wqe_ready,

//Interface with Cache Offset
    output  reg                                                             cache_offset_wen,
    output  reg     [`QP_NUM_LOG - 1 : 0]                                   cache_offset_addr,
    output  reg     [CACHE_SLOT_NUM_LOG - 1:0]                          	cache_offset_din,
    input  	wire    [CACHE_SLOT_NUM_LOG - 1:0]                          	cache_offset_dout,


//Interface with OnScheduleRecord
    output  reg                                                             on_schedule_wen,
    output  reg     [23:0]                                                  on_schedule_addr,
    output  reg     [0:0]                                                   on_schedule_din,

//Interface with SQHeadRecord
    output  reg                                                             sq_head_record_wen,
    output  reg     [`QP_NUM_LOG - 1 : 0]                                   sq_head_record_addr,
    output  reg     [23:0]                                                  sq_head_record_din,
    input   wire    [23:0]                                                  sq_head_record_dout,

//Interface with SQOffsetTable
    output  reg     [0:0]                                                   sq_offset_wen,
    output  reg     [`QP_NUM_LOG - 1 : 0]                                   sq_offset_addr,
    output  reg     [23:0]                                                  sq_offset_din,
    input   wire    [23:0]                                                  sq_offset_dout,

//Interface with CacheOwnedTable
    output  reg                                                             cache_owned_wen,
    output  reg            [CACHE_CELL_NUM_LOG - 1 : 0]                     cache_owned_addr,
    output  reg            [`QP_NUM_LOG - 1 : 0]                            cache_owned_din,
    input   wire           [`QP_NUM_LOG - 1 : 0]                            cache_owned_dout,

//Interface with QPNArbiter
    output  wire                                                            qpn_fifo_valid,
    output  wire            [23:0]                                          qpn_fifo_data,
    input   wire                                                            qpn_fifo_ready,

//Interface with RDMACore
    output  wire                                                            sub_wqe_valid,
    output  wire    [`WQE_META_WIDTH - 1 : 0]                               sub_wqe_meta,
    input   wire                                                            sub_wqe_ready,

//Interface with DynamicBuffer(Payload Buffer)
    input  wire     [`INLINE_PAYLOAD_BUFFER_SLOT_NUM_LOG : 0]               ov_available_slot_num,

    output  wire                                                            insert_req_valid,
    output  wire                                                            insert_req_start,
    output  wire                                                            insert_req_last,
    output  wire    [`INLINE_PAYLOAD_BUFFER_SLOT_NUM_LOG - 1 : 0]           insert_req_head,
    output  wire    [`INLINE_PAYLOAD_BUFFER_SLOT_WIDTH - 1 : 0]             insert_req_data,
    input   wire                                                            insert_req_ready,

    input   wire                                                            insert_resp_valid,
    input   wire    [`INLINE_PAYLOAD_BUFFER_SLOT_WIDTH - 1 : 0]             insert_resp_data
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     LOCAL_QPN_OFFSET                    15:0
`define     REMOTE_QPN_OFFSET                   31:16
`define     DMAC_OFFSET                         175:128
`define     SMAC_OFFSET                         223:176
`define     DIP_OFFSET                          255:224
`define     SIP_OFFSET                          287:256
`define     SQ_ENTRY_SZ_LOG_OFFSET              47:40
`define     SERVICE_TYPE_OFFSET                 34:32
`define     PMTU_OFFSET                         63:48
`define     SQ_LENGTH_OFFSET                    95:64

/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
//Passed from WQEFetch
reg             [23:0]                          meta_local_qpn;
reg             [23:0]                          meta_remote_qpn;
reg             [2:0]                           meta_service_type;
reg             [15:0]                          meta_pmtu;
reg             [7:0]                           meta_sq_entry_sz_log;
reg             [31:0]                          meta_sq_length;
reg             [47:0]                          meta_dmac;
reg             [47:0]                          meta_smac;
reg             [31:0]                          meta_dip;
reg             [31:0]                          meta_sip;

//Next Unit Field
reg             [4:0]                           NextUnit_next_wqe_opcode;
reg             [0:0]                           NextUnit_next_wqe_valid;
reg             [25:0]                          NextUnit_next_wqe_addr;
reg             [5:0]                           NextUnit_next_wqe_size;
reg             [7:0]                           NextUnit_next_wqe_size_aligned;
reg             [0:0]                           NextUnit_next_wqe_dbd;
reg             [23:0]                          NextUnit_next_wqe_ee;
reg             [0:0]                           NextUnit_cur_wqe_fence;
reg             [7:0]                           NextUnit_cur_wqe_size;
reg             [7:0]                           NextUnit_cur_wqe_size_aligned;
reg             [4:0]                           NextUnit_cur_wqe_opcode;
reg             [31:0]                          NextUnit_cur_wqe_imm;

//Raddr Unit field
wire            [63:0]                          RaddrUnit_raddr;
wire            [31:0]                          RaddrUnit_rkey;

//UD Unit field
wire            [7:0]                           UDUnit_port;
wire            [15:0]                          UDUnit_dmac_low;
wire            [31:0]                          UDUnit_dmac_high;
wire            [15:0]                          UDUnit_smac_low;
wire            [31:0]                          UDUnit_smac_high;
wire            [31:0]                          UDUnit_dip;
wire            [31:0]                          UDUnit_sip;
wire            [31:0]                          UDUnit_dqpn;
wire            [31:0]                          UDUnit_qkey;

//Inline Unit field
wire            [0:0]                           InlineUnit_inline_flag;
wire            [30:0]                          InlineUnit_length;

//DataUnit
wire            [31:0]                          DataUnit_byte_cnt;
wire            [31:0]                          DataUnit_lkey;
wire            [63:0]                          DataUnit_laddr;
        
//Passed to RDMACore
reg             [23:0]                          SubWQE_local_qpn;
reg             [23:0]                          SubWQE_remote_qpn;
reg             [4:0]                           SubWQE_verbs_opcode;
reg             [4:0]                           SubWQE_net_opcode;
reg             [2:0]                           SubWQE_service_type;
reg             [0:0]                           SubWQE_fence;
reg             [0:0]                           SubWQE_solicited_event;
reg             [0:0]                           SubWQE_wqe_head;
reg             [0:0]                           SubWQE_wqe_tail;
reg             [0:0]                           SubWQE_inline;
reg             [23:0]                          SubWQE_ori_wqe_offset;
reg             [47:0]                          SubWQE_dmac;
reg             [47:0]                          SubWQE_smac;
reg             [31:0]                          SubWQE_dip;
reg             [31:0]                          SubWQE_sip;
reg             [31:0]                          SubWQE_immediate;
reg             [31:0]                          SubWQE_lkey;
reg             [63:0]                          SubWQE_laddr;
reg             [31:0]                          SubWQE_rkey;
reg             [63:0]                          SubWQE_raddr;
reg             [31:0]                          SubWQE_msg_length;
reg             [15:0]                          SubWQE_packet_length;

reg                                             msg_offset_wea;
reg             [`QP_NUM_LOG - 1 : 0]           msg_offset_addra;
reg             [31:0]                          msg_offset_dina;
wire            [`QP_NUM_LOG - 1 : 0]           msg_offset_addrb;
wire            [31:0]                          msg_offset_doutb;

reg             [31:0]                          inline_payload_start_addr;

reg             [31:0]                          parsed_msg_length;
reg                                             data_unit_parse_finish;

reg             [15:0]                          insert_count;
reg             [15:0]                          insert_total;

reg             [0:0]                           reschedule_flag;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
SRAM_SDP_Template #(
    .RAM_WIDTH      (   32                      ),      //Record msg offset of each WQE
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
reg             [3:0]                           cur_state;
reg             [3:0]                           next_state;

parameter       [3:0]                           IDLE_s          =   4'd1,
                                                NEXT_UNIT_s     =   4'd2,
                                                RADDR_UNIT_s    =   4'd3,
                                                UD_UNIT_1_s     =   4'd4,
                                                UD_UNIT_2_s     =   4'd5,
                                                UD_UNIT_3_s     =   4'd6,
                                                JUDGE_s         =   4'd7,
                                                INLINE_JUDGE_s  =   4'd8,
                                                INLINE_UNIT_s   =   4'd9,
                                                INLINE_DATA_s   =   4'd10,
                                                DATA_UNIT_s     =   4'd11,
                                                INJECT_s        =   4'd12,
                                                RESCHEDULE_s    =   4'd13;
        
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
        IDLE_s:                 if(wqe_valid) begin
                                    next_state = NEXT_UNIT_s;
                                end
                                else begin
                                    next_state = IDLE_s;
                                end
        NEXT_UNIT_s:            if(meta_service_type == `RC || meta_service_type == `UC) begin
                                    if(wqe_data[`NEXT_UNIT_CUR_WQE_OPCODE_OFFSET] == `VERBS_SEND || wqe_data[`NEXT_UNIT_CUR_WQE_OPCODE_OFFSET] == `VERBS_SEND_WITH_IMM) begin
                                        next_state = INLINE_JUDGE_s;
                                    end
                                    else if(wqe_data[`NEXT_UNIT_CUR_WQE_OPCODE_OFFSET] == `VERBS_RDMA_WRITE || wqe_data[`NEXT_UNIT_CUR_WQE_OPCODE_OFFSET] == `VERBS_RDMA_WRITE_WITH_IMM || wqe_data[`NEXT_UNIT_CUR_WQE_OPCODE_OFFSET] == `VERBS_RDMA_READ) begin
                                        next_state = RADDR_UNIT_s;
                                    end
                                    else begin
                                        next_state = IDLE_s;
                                    end
                                end
                                else if(meta_service_type == `UD) begin
                                    next_state = UD_UNIT_1_s;
                                end
                                else begin
                                    next_state = IDLE_s;
                                end
        RADDR_UNIT_s:           if(wqe_valid) begin
                                    next_state = INLINE_JUDGE_s;
                                end
                                else begin
                                    next_state = RADDR_UNIT_s;
                                end
        UD_UNIT_1_s:            if(wqe_valid) begin
                                    next_state = UD_UNIT_2_s;
                                end
                                else begin
                                    next_state = UD_UNIT_1_s;
                                end
        UD_UNIT_2_s:            if(wqe_valid) begin
                                    next_state = UD_UNIT_3_s;
                                end
                                else begin
                                    next_state = UD_UNIT_2_s;
                                end
        UD_UNIT_3_s:            if(wqe_valid) begin
                                    next_state = DATA_UNIT_s;
                                end
                                else begin
                                    next_state = UD_UNIT_3_s;
                                end
        INLINE_JUDGE_s:         if(wqe_valid) begin
                                    if(InlineUnit_inline_flag) begin
                                        next_state = INLINE_UNIT_s;
                                    end
                                    else begin
                                        next_state = DATA_UNIT_s;
                                    end
                                end
                                else begin
                                    next_state = INLINE_JUDGE_s;                        
                                end
        INLINE_UNIT_s:          if(wqe_valid) begin
                                    next_state = INLINE_DATA_s;
                                end
                                else begin
                                    next_state = INLINE_UNIT_s;
                                end
        INLINE_DATA_s:          if(wqe_valid && insert_req_valid && insert_req_ready) begin
                                    if(wqe_last) begin
                                        next_state = INJECT_s;
                                    end
                                    else begin
                                        next_state = INLINE_DATA_s;
                                    end
                                end
                                else begin
                                    next_state = INLINE_DATA_s;
                                end
        DATA_UNIT_s:            if(wqe_valid && wqe_last) begin
                                    next_state = INJECT_s;
                                end
                                else begin
                                    next_state = DATA_UNIT_s;
                                end
        INJECT_s:               if(sub_wqe_valid && sub_wqe_ready) begin
                                    if(reschedule_flag) begin
                                        next_state = RESCHEDULE_s;
                                    end
                                    else begin
                                        next_state = IDLE_s;
                                    end
                                end
                                else begin
                                    next_state = INJECT_s;
                                end
        RESCHEDULE_s:           if(qpn_fifo_ready) begin
                                    next_state = IDLE_s;
                                end
                                else begin
                                    next_state = RESCHEDULE_s;
                                end
        default:                next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- meta_local_qpn --
//-- meta_remote_qpn --
//-- meta_service_type --
//-- meta_sq_entry_sz_log --
//-- meta_sq_length --
//-- meta_dmac --
//-- meta_smac --
//-- meta_dip --
//-- meta_sip --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        meta_local_qpn <= 'd0; 
        meta_remote_qpn <= 'd0; 
        meta_service_type <= 'd0; 
        meta_sq_entry_sz_log <= 'd0; 
        meta_sq_length <= 'd0; 
        meta_dmac <= 'd0; 
        meta_smac <= 'd0; 
        meta_dip <= 'd0; 
        meta_sip <= 'd0; 
        meta_pmtu <= 'd0;
    end
    else if(cur_state == IDLE_s && wqe_valid) begin
        meta_local_qpn <= wqe_head[`LOCAL_QPN_OFFSET];
        meta_remote_qpn <= wqe_head[`REMOTE_QPN_OFFSET];
        meta_service_type <= wqe_head[`SERVICE_TYPE_OFFSET];
        meta_sq_entry_sz_log <= wqe_head[`SQ_ENTRY_SZ_LOG_OFFSET];
        meta_sq_length <= wqe_head[`SQ_LENGTH_OFFSET];
        meta_dmac <= wqe_head[`DMAC_OFFSET];
        meta_smac <= wqe_head[`SMAC_OFFSET];
        meta_dip <= wqe_head[`DIP_OFFSET];
        meta_sip <= wqe_head[`SIP_OFFSET];
        meta_pmtu <= wqe_head[`PMTU_OFFSET];
    end
    else begin
        meta_local_qpn <= meta_local_qpn;
        meta_remote_qpn <= meta_remote_qpn;
        meta_service_type <= meta_service_type;
        meta_sq_entry_sz_log <= meta_sq_entry_sz_log;
        meta_sq_length <= meta_sq_length;
        meta_dmac <= meta_dmac;
        meta_smac <= meta_smac;
        meta_dip <= meta_dip;
        meta_sip <= meta_sip;
        meta_pmtu <= meta_pmtu;
    end
end

wire            [31:0]              cur_wqe_size;
wire            [31:0]              next_wqe_size;
assign cur_wqe_size = wqe_data[`NEXT_UNIT_CUR_WQE_SIZE_OFFSET];
assign next_wqe_size = wqe_data[`NEXT_UNIT_NEXT_WQE_SIZE_OFFSET];

//Next Unit Field
//-- NextUnit_next_wqe_opcode --
//-- NextUnit_next_wqe_valid --
//-- NextUnit_next_wqe_addr --
//-- NextUnit_next_wqe_size --
//-- NextUnit_next_wqe_size_aligned --
//-- NextUnit_next_wqe_dbd --
//-- NextUnit_next_wqe_ee --
//-- NextUnit_cur_wqe_fence --
//-- NextUnit_cur_wqe_size --
//-- NextUnit_cur_wqe_size_aligned --
//-- NextUnit_cur_wqe_opcode --
//-- NextUnit_cur_wqe_imm --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        NextUnit_next_wqe_opcode <= 'd0;
        NextUnit_next_wqe_valid <= 'd0;
        NextUnit_next_wqe_addr <= 'd0;
        NextUnit_next_wqe_size <= 'd0;
        NextUnit_next_wqe_size_aligned <= 'd0;
        NextUnit_next_wqe_dbd <= 'd0;
        NextUnit_next_wqe_ee <= 'd0;
        NextUnit_cur_wqe_fence <= 'd0;
        NextUnit_cur_wqe_size <= 'd0;
        NextUnit_cur_wqe_size_aligned <= 'd0;
        NextUnit_cur_wqe_opcode <= 'd0;
        NextUnit_cur_wqe_imm <= 'd0;
    end
    else if(cur_state == NEXT_UNIT_s && wqe_valid) begin
        NextUnit_next_wqe_opcode <= wqe_data[`NEXT_UNIT_NEXT_WQE_OPCODE_OFFSET];
        NextUnit_next_wqe_valid <= (wqe_data[`NEXT_UNIT_NEXT_WQE_SIZE_OFFSET] != 0);
        NextUnit_next_wqe_addr <= wqe_data[`NEXT_UNIT_NEXT_WQE_ADDR_OFFSET];
        NextUnit_next_wqe_size <= wqe_data[`NEXT_UNIT_NEXT_WQE_SIZE_OFFSET];

        case(meta_sq_entry_sz_log)     //minimum 64, maximum 1024
            6:          NextUnit_next_wqe_size_aligned <= (next_wqe_size % 4) ? (next_wqe_size[31:2] + 32'd1) * 4 : next_wqe_size[31:2] * 4;
            7:          NextUnit_next_wqe_size_aligned <= (next_wqe_size % 8) ? (next_wqe_size[31:3] + 32'd1) * 8 : next_wqe_size[31:3] * 8;
            8:          NextUnit_next_wqe_size_aligned <= (next_wqe_size % 16) ? (next_wqe_size[31:4] + 32'd1) * 16 : next_wqe_size[31:4] * 16;
            9:          NextUnit_next_wqe_size_aligned <= (next_wqe_size % 32) ? (next_wqe_size[31:5] + 32'd1) * 32 : next_wqe_size[31:5] * 32;
            10:         NextUnit_next_wqe_size_aligned <= (next_wqe_size % 64) ? (next_wqe_size[31:6] + 32'd1) * 64 : next_wqe_size[31:6] * 64;
            default:    NextUnit_next_wqe_size_aligned <= 'd0;
        endcase  

        NextUnit_next_wqe_dbd <= wqe_data[`NEXT_UNIT_NEXT_WQE_DBD_OFFSET];
        NextUnit_next_wqe_ee <= wqe_data[`NEXT_UNIT_NEXT_WQE_EE_OFFSET];
        NextUnit_cur_wqe_fence <= wqe_data[`NEXT_UNIT_CUR_WQE_FENCE_OFFSET];
        NextUnit_cur_wqe_size <= wqe_data[`NEXT_UNIT_CUR_WQE_SIZE_OFFSET];

        case(meta_sq_entry_sz_log)     //minimum 64, maximum 1024
            6:          NextUnit_cur_wqe_size_aligned <= (cur_wqe_size % 4) ? (cur_wqe_size[31:2] + 32'd1) * 4 : cur_wqe_size[31:2] * 4;
            7:          NextUnit_cur_wqe_size_aligned <= (cur_wqe_size % 8) ? (cur_wqe_size[31:3] + 32'd1) * 8 : cur_wqe_size[31:3] * 8;
            8:          NextUnit_cur_wqe_size_aligned <= (cur_wqe_size % 16) ? (cur_wqe_size[31:4] + 32'd1) * 16 : cur_wqe_size[31:4] * 16;
            9:          NextUnit_cur_wqe_size_aligned <= (cur_wqe_size % 32) ? (cur_wqe_size[31:5] + 32'd1) * 32 : cur_wqe_size[31:5] * 32;
            10:         NextUnit_cur_wqe_size_aligned <= (cur_wqe_size % 64) ? (cur_wqe_size[31:6] + 32'd1) * 64 : cur_wqe_size[31:6] * 64;
            default:    NextUnit_cur_wqe_size_aligned <= 'd0;
        endcase        
        NextUnit_cur_wqe_opcode <= wqe_data[`NEXT_UNIT_CUR_WQE_OPCODE_OFFSET];
        NextUnit_cur_wqe_imm <= wqe_data[`NEXT_UNIT_CUR_WQE_IMM_OFFSET];
    end
    else begin
        NextUnit_next_wqe_opcode <= NextUnit_next_wqe_opcode;
        NextUnit_next_wqe_valid <= NextUnit_next_wqe_valid;
        NextUnit_next_wqe_addr <= NextUnit_next_wqe_addr;
        NextUnit_next_wqe_size <= NextUnit_next_wqe_size;
        NextUnit_next_wqe_size_aligned <= NextUnit_next_wqe_size_aligned;
        NextUnit_next_wqe_dbd <= NextUnit_next_wqe_dbd;
        NextUnit_next_wqe_ee <= NextUnit_next_wqe_ee;
        NextUnit_cur_wqe_fence <= NextUnit_cur_wqe_fence;
        NextUnit_cur_wqe_size <= NextUnit_cur_wqe_size;
        NextUnit_cur_wqe_size_aligned <= NextUnit_cur_wqe_size_aligned;
        NextUnit_cur_wqe_opcode <= NextUnit_cur_wqe_opcode;
        NextUnit_cur_wqe_imm <= NextUnit_cur_wqe_imm;
    end
end

//Raddr Unit field
//-- RaddrUnit_raddr --
//-- RaddrUnit_rkey --
assign RaddrUnit_raddr = (cur_state == RADDR_UNIT_s && wqe_valid) ? wqe_data[`RADDR_UNIT_RADDR_OFFSET] : 'd0;
assign RaddrUnit_rkey = (cur_state == RADDR_UNIT_s && wqe_valid) ? wqe_data[`RADDR_UNIT_RKEY_OFFSET] : 'd0;

//UD Unit field
//-- UDUnit_port --
//-- UDUnit_dmac_low --
//-- UDUnit_dmac_high --
//-- UDUnit_smac_low --
//-- UDUnit_smac_high --
//-- UDUnit_dip --
//-- UDUnit_sip --
//-- UDUnit_dqpn --
//-- UDUnit_qkey --
assign UDUnit_port = (cur_state == UD_UNIT_1_s && wqe_valid) ? wqe_data[`UD_UNIT_PORT_OFFSET] : 'd0; 
assign UDUnit_dmac_low = (cur_state == UD_UNIT_1_s && wqe_valid) ? wqe_data[`UD_UNIT_DMAC_LOW_OFFSET] : 'd0; 
assign UDUnit_dmac_high = (cur_state == UD_UNIT_1_s && wqe_valid) ? wqe_data[`UD_UNIT_DMAC_HIGH_OFFSET] : 'd0; 
assign UDUnit_smac_low = (cur_state == UD_UNIT_1_s && wqe_valid) ? wqe_data[`UD_UNIT_SMAC_LOW_OFFSET] : 'd0; 
assign UDUnit_smac_high = (cur_state == UD_UNIT_1_s && wqe_valid) ? wqe_data[`UD_UNIT_SMAC_HIGH_OFFSET] : 'd0; 
assign UDUnit_dip = (cur_state == UD_UNIT_2_s && wqe_valid) ? wqe_data[`UD_UNIT_DIP_OFFSET] : 'd0; 
assign UDUnit_sip = (cur_state == UD_UNIT_2_s && wqe_valid) ? wqe_data[`UD_UNIT_SIP_OFFSET] : 'd0; 
assign UDUnit_dqpn = (cur_state == UD_UNIT_3_s && wqe_valid) ? wqe_data[`UD_UNIT_REMOTE_QPN_OFFSET] : 'd0; 
assign UDUnit_qkey = (cur_state == UD_UNIT_3_s && wqe_valid) ? wqe_data[`UD_UNIT_QKEY_OFFSET] : 'd0; 

//Inline Unit field
//-- InlineUnit_inline_flag --
//-- InlineUnit_length --
assign InlineUnit_inline_flag = ((cur_state == JUDGE_s || cur_state == INLINE_UNIT_s) && wqe_valid) ? wqe_data[`DATA_UNIT_INLINE_OFFSET] : 'd0;
assign InlineUnit_length = ((cur_state == JUDGE_s || cur_state == INLINE_UNIT_s) && wqe_valid) ? wqe_data[`DATA_UNIT_INLINE_OFFSET] : 'd0;

//DataUnit
//-- DataUnit_byte_cnt --
//-- DataUnit_lkey --
//-- DataUnit_laddr --
assign DataUnit_byte_cnt = ((cur_state == JUDGE_s || cur_state == DATA_UNIT_s) && wqe_valid) ? wqe_data[`DATA_UNIT_BYTE_CNT_OFFSET] : 'd0;
assign DataUnit_lkey = ((cur_state == JUDGE_s || cur_state == DATA_UNIT_s) && wqe_valid) ? wqe_data[`DATA_UNIT_LKEY_OFFSET] : 'd0;
assign DataUnit_laddr = ((cur_state == JUDGE_s || cur_state == DATA_UNIT_s) && wqe_valid) ? wqe_data[`DATA_UNIT_LADDR_OFFSET] : 'd0;

//-- inline_payload_start_addr --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        inline_payload_start_addr <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        inline_payload_start_addr <= 'd0;
    end
    else if(cur_state == INLINE_DATA_s && wqe_valid && insert_req_valid && insert_req_start && insert_req_ready && insert_resp_valid) begin
        inline_payload_start_addr <= insert_resp_data;  //Address of first flit of inline data
    end
    else begin
        inline_payload_start_addr <= inline_payload_start_addr;
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
    else if (cur_state == INLINE_UNIT_s) begin
        msg_offset_wea = 'd1;
        msg_offset_addra = meta_local_qpn;
        msg_offset_dina = 'd0;
    end
    else if (cur_state == DATA_UNIT_s && wqe_valid && !data_unit_parse_finish) begin
        if(parsed_msg_length + DataUnit_byte_cnt <= msg_offset_doutb) begin
            msg_offset_wea = 'd0;
            msg_offset_addra = meta_local_qpn;
            msg_offset_dina = 'd0;            
        end
        else if(wqe_last && (parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb <= meta_pmtu)) begin  //Current WQE is finished, clean MSG offset for next WQE.
            msg_offset_wea = 'd1;
            msg_offset_addra = meta_local_qpn;
            msg_offset_dina = 'd0;
        end
        else if(wqe_last && (parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb > meta_pmtu)) begin
            msg_offset_wea = 'd1;
            msg_offset_addra = meta_local_qpn;
            msg_offset_dina = msg_offset_doutb + meta_pmtu;
        end
        else if(!wqe_last && (parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb <= meta_pmtu)) begin
            msg_offset_wea = 'd1;
            msg_offset_addra = meta_local_qpn;
            msg_offset_dina = msg_offset_doutb + (parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb);
        end
        else if(!wqe_last && (parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb > meta_pmtu)) begin
            msg_offset_wea = 'd1;
            msg_offset_addra = meta_local_qpn;
            msg_offset_dina = msg_offset_doutb + meta_pmtu;
        end
        else begin
            msg_offset_wea = 'd0;
            msg_offset_addra = meta_local_qpn;
            msg_offset_dina = 'd0;
        end
    end
    else begin
        msg_offset_wea = 'd0;
        msg_offset_addra = meta_local_qpn;
        msg_offset_dina = 'd0;
    end
end

//-- msg_offset_addrb --
assign msg_offset_addrb = meta_local_qpn;

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
        cache_offset_addr = meta_local_qpn;
        cache_offset_din = 'd0;
    end
    else if(cur_state == INLINE_UNIT_s && wqe_valid) begin  //Current WQE is finished, update cache offset
        if(!NextUnit_next_wqe_valid) begin
            cache_offset_wen = 'd1;
            cache_offset_addr = meta_local_qpn;
            cache_offset_din = 'd0;
        end
        else if(NextUnit_next_wqe_addr < sq_offset_dout) begin  //SQ wrap back
            cache_offset_wen = 'd1;
            cache_offset_addr = meta_local_qpn;
            cache_offset_din = 'd0;
        end
        else if(cache_offset_dout + (NextUnit_next_wqe_addr - sq_offset_dout) + NextUnit_next_wqe_size > CACHE_SLOT_NUM) begin     //Next WQE cross Cache Block boundary
            cache_offset_wen = 'd1;
            cache_offset_addr = meta_local_qpn;
            cache_offset_din = 'd0;
        end
        else begin //Next WQE is in cache
            cache_offset_wen = 'd1;
            cache_offset_addr = meta_local_qpn;
            cache_offset_din = cache_offset_dout + (NextUnit_next_wqe_addr - sq_offset_dout);
        end
    end
    else if(cur_state == DATA_UNIT_s && wqe_valid && wqe_last && (parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb <= meta_pmtu) && !data_unit_parse_finish) begin
        if(!NextUnit_next_wqe_valid) begin
            cache_offset_wen = 'd1;
            cache_offset_addr = meta_local_qpn;
            cache_offset_din = 'd0;
        end
        else if(NextUnit_next_wqe_addr < sq_offset_dout) begin  //SQ wrap back
            cache_offset_wen = 'd1;
            cache_offset_addr = meta_local_qpn;
            cache_offset_din = 'd0;
        end
        else if(cache_offset_dout + (NextUnit_next_wqe_addr - sq_offset_dout) + NextUnit_next_wqe_size > CACHE_SLOT_NUM) begin     //Next WQE cross Cache Block boundary
            cache_offset_wen = 'd1;
            cache_offset_addr = meta_local_qpn;
            cache_offset_din = 'd0;
        end
        else begin //Next WQE is in cache
            cache_offset_wen = 'd1;
            cache_offset_addr = meta_local_qpn;
            cache_offset_din = cache_offset_dout + (NextUnit_next_wqe_addr - sq_offset_dout);
        end
    end
    else begin
        cache_offset_wen = 'd0;
        cache_offset_addr = meta_local_qpn;
        cache_offset_din = 'd0;        
    end
end

//-- on_schedule_wen --
//-- on_schedule_addr --
//-- on_schedule_din --
always @(*) begin
    if(rst) begin
        on_schedule_wen = 'd0;
        on_schedule_addr = 'd0;
        on_schedule_din = 'd0;
    end
    else if(cur_state == INLINE_UNIT_s && wqe_valid) begin
        if(NextUnit_next_wqe_valid) begin       //Still got WQE to be scheduled
            on_schedule_wen = 'd1;
            on_schedule_addr = meta_local_qpn;
            on_schedule_din = 'd1;
        end
        else if(!NextUnit_next_wqe_valid && (sq_head_record_dout == sq_offset_dout)) begin  //No sq_head update through doorbell ringing
            on_schedule_wen = 'd1;
            on_schedule_addr = meta_local_qpn;
            on_schedule_din = 'd0;           
        end
        else if(!NextUnit_next_wqe_valid && (sq_head_record_dout != sq_offset_dout)) begin //SQ_Head is updated through doorbell ringing, new WQE list is available
            on_schedule_wen = 'd1;
            on_schedule_addr = meta_local_qpn;
            on_schedule_din = 'd1;
        end
        else begin
            on_schedule_wen = 'd0;
            on_schedule_addr = 'd0;
            on_schedule_din = 'd0;           
        end
    end
    else if(cur_state == DATA_UNIT_s && wqe_valid) begin
        if(wqe_last && (parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb) <= meta_pmtu) begin //Current WQE is finished
            if(NextUnit_next_wqe_valid) begin       //Still got WQE to be scheduled
                on_schedule_wen = 'd1;
                on_schedule_addr = meta_local_qpn;
                on_schedule_din = 'd1;
            end
            else if(!NextUnit_next_wqe_valid && (sq_head_record_dout != sq_offset_dout)) begin //SQ_Head is updated through doorbell ringing, new WQE list is available
                on_schedule_wen = 'd1;
                on_schedule_addr = meta_local_qpn;
                on_schedule_din = 'd1;
            end
            else if(!NextUnit_next_wqe_valid && (sq_head_record_dout == sq_offset_dout)) begin  //No sq_head update through doorbell ringing
                on_schedule_wen = 'd1;
                on_schedule_addr = meta_local_qpn;
                on_schedule_din = 'd0;           
            end
            else begin
                on_schedule_wen = 'd0;
                on_schedule_addr = 'd0;
                on_schedule_din = 'd0;           
            end
        end
        else if(parsed_msg_length + DataUnit_byte_cnt > msg_offset_doutb) begin
            on_schedule_wen = 'd1;
            on_schedule_addr = meta_local_qpn;
            on_schedule_din = 'd1;
        end
        else begin
            on_schedule_wen = 'd0;
            on_schedule_addr = 'd0;
            on_schedule_din = 'd0;
        end
    end
    else begin
        on_schedule_wen = 'd0;
        on_schedule_addr = 'd0;
        on_schedule_din = 'd0;        
    end
end

//-- reschedule_flag --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        reschedule_flag <= 'd0;        
    end
    else if (cur_state == IDLE_s) begin
        reschedule_flag <= 'd0;
    end
    else if (on_schedule_wen && on_schedule_din == 1) begin
        reschedule_flag <= 'd1;
    end
    else begin
        reschedule_flag <= reschedule_flag;
    end
end

// //-- sq_head_record_wen --
// //-- sq_head_record_addr --
// //-- sq_head_record_din --
// always @(*) begin
//     if(rst) begin
//         sq_head_record_wen = 'd0;
//         sq_head_record_addr = 'd0;
//         sq_head_record_din = 'd0;
//     end
//     else if(cur_state == IDLE_s) begin
//         sq_head_record_wen = 'd0;
//         sq_head_record_addr = 'd0;
//         sq_head_record_din = 'd0;
//     end
//     else if(cur_state == NEXT_UNIT_s) begin
//         sq_head_record_wen = 'd0;
//         sq_head_record_addr = meta_local_qpn;
//         sq_head_record_din = 'd0;
//     end
//     else if(cur_state == INLINE_UNIT_s && wqe_valid) begin
//         if(sq_offset_dout == sq_head_record_dout) begin     //No Doorbell ringing during WQEParsing
//             sq_head_record_wen = 'd1;
//             sq_head_record_addr = meta_local_qpn;
//             sq_head_record_din = sq_offset_dout + NextUnit_cur_wqe_size_aligned;
//         end
//         else begin  //SQ head is updated through doorbell ringing, do not touch SQ head.
//             sq_head_record_wen = 'd0;
//             sq_head_record_addr = meta_local_qpn;
//             sq_head_record_din = 'd0;
//         end
//     end
//     else if(cur_state == DATA_UNIT_s && wqe_last && (parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb <= meta_pmtu)) begin
//         if(sq_offset_dout == sq_head_record_dout) begin     //No Doorbell ringing during WQEParsing
//             sq_head_record_wen = 'd1;
//             sq_head_record_addr = meta_local_qpn;
//             sq_head_record_din = sq_offset_dout + NextUnit_cur_wqe_size_aligned;
//         end
//         else begin  //SQ head is updated through doorbell ringing, do not touch SQ head.
//             sq_head_record_wen = 'd0;
//             sq_head_record_addr = meta_local_qpn;
//             sq_head_record_din = 'd0;
//         end       
//     end
//     else begin
//         sq_head_record_wen = 'd0;
//         sq_head_record_addr = meta_local_qpn;
//         sq_head_record_din = 'd0;
//     end
// end

//-- sq_offset_wen --
//-- sq_offset_addr --
//-- sq_offset_din --
//-- sq_head_record_wen --
//-- sq_head_record_addr --
//-- sq_head_record_din --
always @(*) begin
    if(rst) begin
        sq_offset_wen = 'd0;
        sq_offset_addr = 'd0;
        sq_offset_din = 'd0;

        sq_head_record_wen = 'd0;
        sq_head_record_addr = 'd0;
        sq_head_record_din = 'd0;
    end
    else if(cur_state == IDLE_s) begin
        sq_offset_wen = 'd0;
        sq_offset_addr = 'd0;
        sq_offset_din = 'd0;

        sq_head_record_wen = 'd0;
        sq_head_record_addr = 'd0;
        sq_head_record_din = 'd0;
    end
    else if(cur_state == NEXT_UNIT_s) begin
        sq_offset_wen = 'd0;
        sq_offset_addr = meta_local_qpn;
        sq_offset_din = 'd0;

        sq_head_record_wen = 'd0;
        sq_head_record_addr = meta_local_qpn;
        sq_head_record_din = 'd0;
    end
    else if(cur_state == INLINE_UNIT_s && wqe_valid) begin
        sq_offset_wen = 'd1;
        sq_offset_addr = meta_local_qpn;
        sq_offset_din = meta_sq_length - (sq_offset_dout + NextUnit_cur_wqe_size_aligned) * 16 <= (32'd1 << meta_sq_entry_sz_log) ? 'd0 : sq_offset_dout + NextUnit_cur_wqe_size_aligned;

        if(sq_head_record_dout == sq_offset_dout) begin
            sq_head_record_wen = 'd1;
            sq_head_record_addr = meta_local_qpn;
            sq_head_record_din = meta_sq_length - (sq_offset_dout + NextUnit_cur_wqe_size_aligned) * 16 <= (32'd1 << meta_sq_entry_sz_log) ? 'd0 : sq_offset_dout + NextUnit_cur_wqe_size_aligned;
        end
        else begin
            sq_head_record_wen = 'd0;
            sq_head_record_addr = 'd0;
            sq_head_record_din = 'd0;
        end
    end
    else if(cur_state == DATA_UNIT_s && wqe_last && (parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb <= meta_pmtu) && !data_unit_parse_finish) begin
        sq_offset_wen = 'd1;
        sq_offset_addr = meta_local_qpn;
        sq_offset_din = meta_sq_length - (sq_offset_dout + NextUnit_cur_wqe_size_aligned) * 16 < (32'd1 << meta_sq_entry_sz_log) ? 'd0 : sq_offset_dout + NextUnit_cur_wqe_size_aligned;

        if(sq_head_record_dout == sq_offset_dout) begin
            sq_head_record_wen = 'd1;
            sq_head_record_addr = meta_local_qpn;
            sq_head_record_din = meta_sq_length - (sq_offset_dout + NextUnit_cur_wqe_size_aligned) * 16 < (32'd1 << meta_sq_entry_sz_log) ? 'd0 : sq_offset_dout + NextUnit_cur_wqe_size_aligned;
        end
        else begin
            sq_head_record_wen = 'd0;
            sq_head_record_addr = 'd0;
            sq_head_record_din = 'd0; 
        end
    end
    else begin
        sq_offset_wen = 'd0;
        sq_offset_addr = meta_local_qpn;
        sq_offset_din = 'd0;

        sq_head_record_wen = 'd0;
        sq_head_record_addr = meta_local_qpn;
        sq_head_record_din = 'd0;
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
        cache_owned_addr = meta_local_qpn;
        cache_owned_din = 'd0;
    end
    else if(cur_state == DATA_UNIT_s && wqe_last && (parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb <= meta_pmtu) && !data_unit_parse_finish) begin //Current WQE has been finished
        if(cache_owned_dout[`QP_NUM_LOG - CACHE_CELL_NUM_LOG - 1 : 0] != meta_local_qpn[`QP_NUM_LOG - 1 : 4]) begin //Curretn cell is already been replaced by another QP, do not touch it
            cache_owned_wen = 'd0;
            cache_owned_addr = meta_local_qpn;
            cache_owned_din = 'd0;           
        end
        else if(!NextUnit_next_wqe_valid) begin //No valid WQE in current DB ringing, clear cache cell state
            cache_owned_wen = 'd1;
            cache_owned_addr = meta_local_qpn;
            cache_owned_din = 'd0;              
        end
        else if(NextUnit_next_wqe_valid && NextUnit_next_wqe_addr == 0) begin    //Wrap back to SQ head, clear cache cell state
            cache_owned_wen = 'd1;
            cache_owned_addr = meta_local_qpn;
            cache_owned_din = 'd0;     
        end
        else if(NextUnit_next_wqe_valid && (cache_offset_dout + NextUnit_cur_wqe_size_aligned + NextUnit_next_wqe_size_aligned > CACHE_SLOT_NUM)) begin     //Cross Cache cell boundary
            cache_owned_wen = 'd1;
            cache_owned_addr = meta_local_qpn;
            cache_owned_din = 'd0;              
        end
        else begin
	        cache_owned_wen = 'd0;
	        cache_owned_addr = meta_local_qpn;
	        cache_owned_din = 'd0;
        end
    end
    else begin
        cache_owned_wen = 'd0;
        cache_owned_addr = meta_local_qpn;
        cache_owned_din = 'd0;          
    end
end

//-- parsed_msg_length --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        parsed_msg_length <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        parsed_msg_length <= 'd0;
    end
    else if(cur_state == DATA_UNIT_s && wqe_valid) begin
        if(parsed_msg_length + DataUnit_byte_cnt <= msg_offset_doutb) begin
            parsed_msg_length <= parsed_msg_length + DataUnit_byte_cnt;
        end
        else if(parsed_msg_length + DataUnit_byte_cnt > msg_offset_doutb) begin
            if(parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb >= meta_pmtu) begin
                parsed_msg_length <= parsed_msg_length + meta_pmtu;
            end
            else begin
                parsed_msg_length <= parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb;
            end
        end
        else begin
            parsed_msg_length <= parsed_msg_length;
        end
    end
    else begin
        parsed_msg_length <= parsed_msg_length;
    end
end

//-- insert_count --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        insert_count <= 'd0;        
    end
    else if (cur_state == INLINE_UNIT_s && wqe_valid) begin
        insert_count <= 'd1;
    end
    else if(cur_state == INLINE_DATA_s && wqe_valid && insert_req_ready) begin
        insert_count <= insert_count + 'd1;
    end
    else begin
        insert_count <= insert_count;
    end
end

//-- insert_total --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        insert_total <= 'd0;        
    end
    else if(cur_state == IDLE_s) begin
        insert_total <= 'd0;
    end
    else if (cur_state == INLINE_UNIT_s && wqe_valid) begin
        insert_total <= SubWQE_msg_length[3:0] ? (SubWQE_msg_length >> 4) + 1 : SubWQE_msg_length >> 4;
    end
    else begin
        insert_total <= insert_total;
    end
end

//-- insert_req_valid --
//-- insert_req_start --
//-- insert_req_last --
//-- insert_req_head --
//-- insert_req_data --
assign insert_req_valid = (cur_state == INLINE_DATA_s && wqe_valid) ? 'd1 : 'd0;
assign insert_req_start = (cur_state == INLINE_DATA_s && wqe_valid) ? (insert_count == 'd1) : 'd0;
assign insert_req_last = (cur_state == INLINE_DATA_s && wqe_valid) ? (insert_count == insert_total) : 'd0;
assign insert_req_head = (cur_state == INLINE_DATA_s && wqe_valid) ? {SubWQE_msg_length[3:0] ? (SubWQE_msg_length >> 4) + 1 : SubWQE_msg_length >> 4, meta_local_qpn} : 'd0;
assign insert_req_data = (cur_state == INLINE_DATA_s && wqe_valid) ? wqe_data : 'd0;

assign wqe_ready =  (cur_state == NEXT_UNIT_s) ? 'd1 : 
                    (cur_state == INLINE_UNIT_s) ? 'd1 :
                    (cur_state == INLINE_DATA_s) ? insert_req_ready :
                    (cur_state == UD_UNIT_1_s) ? 'd1 :
                    (cur_state == UD_UNIT_2_s) ? 'd1 :
                    (cur_state == UD_UNIT_3_s) ? 'd1 :
                    (cur_state == RADDR_UNIT_s) ? 'd1 :
                    (cur_state == DATA_UNIT_s) ? 'd1 : 'd0;

/*********************************************************** Sub-WQE Field Decode : Begin**********************************************************/
//-- SubWQE_local_qpn --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        SubWQE_local_qpn <= 'd0;
    end
    else if(cur_state == NEXT_UNIT_s && wqe_valid) begin
        SubWQE_local_qpn <= meta_local_qpn;
    end
    else begin
        SubWQE_local_qpn <= SubWQE_local_qpn;
    end
end

//-- SubWQE_remote_qpn --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        SubWQE_remote_qpn <= 'd0;
    end
    else if(cur_state == NEXT_UNIT_s && wqe_valid) begin
        SubWQE_remote_qpn <= meta_remote_qpn;
    end
    else if(cur_state == UD_UNIT_1_s) begin
        SubWQE_remote_qpn <= UDUnit_dqpn;
    end
    else begin
        SubWQE_remote_qpn <= SubWQE_remote_qpn;
    end
end

//-- SubWQE_verbs_opcode --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        SubWQE_verbs_opcode <= 'd0;        
    end
    else if (cur_state == NEXT_UNIT_s && wqe_valid) begin
        SubWQE_verbs_opcode <= wqe_data[`NEXT_UNIT_CUR_WQE_OPCODE_OFFSET];;
    end
    else begin
        SubWQE_verbs_opcode <= SubWQE_verbs_opcode;
    end
end 

//-- SubWQE_net_opcode --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        SubWQE_net_opcode <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        SubWQE_net_opcode <= `NONE_OPCODE;
    end
    else if(cur_state == INLINE_UNIT_s) begin       //Inline data length is less than PMTU
        if(NextUnit_cur_wqe_opcode == `VERBS_SEND) begin
            SubWQE_net_opcode <= `SEND_ONLY;
        end
        else if(NextUnit_cur_wqe_opcode == `VERBS_SEND_WITH_IMM) begin
            SubWQE_net_opcode <= `SEND_ONLY_WITH_IMM;
        end
        else if(NextUnit_cur_wqe_opcode == `RDMA_WRITE_ONLY) begin
            SubWQE_net_opcode <= `RDMA_WRITE_ONLY;
        end
        else if(NextUnit_cur_wqe_opcode == `RDMA_WRITE_ONLY_WITH_IMM) begin
            SubWQE_net_opcode <= `RDMA_WRITE_ONLY_WITH_IMM;
        end
        else begin
            SubWQE_net_opcode <= `NONE_OPCODE;
        end
    end
    else if(cur_state == DATA_UNIT_s && !data_unit_parse_finish) begin
        if(msg_offset_doutb == 'd0) begin           //First packet, need to decide whether it is last packet
            if(wqe_last && (parsed_msg_length + DataUnit_byte_cnt <= meta_pmtu)) begin     //XXX-Only
                if(NextUnit_cur_wqe_opcode == `VERBS_SEND) begin
                    SubWQE_net_opcode <= `SEND_ONLY;
                end
                else if(NextUnit_cur_wqe_opcode == `VERBS_SEND_WITH_IMM) begin
                    SubWQE_net_opcode <= `SEND_ONLY_WITH_IMM;
                end
                else if(NextUnit_cur_wqe_opcode == `VERBS_RDMA_WRITE) begin
                    SubWQE_net_opcode <= `RDMA_WRITE_ONLY;
                end
                else if(NextUnit_cur_wqe_opcode == `VERBS_RDMA_WRITE_WITH_IMM) begin
                    SubWQE_net_opcode <= `RDMA_WRITE_ONLY_WITH_IMM;
                end
                else if(NextUnit_cur_wqe_opcode == `VERBS_RDMA_READ) begin
                    SubWQE_net_opcode <= `RDMA_READ_REQUEST_ONLY;
                end
                else begin
                    SubWQE_net_opcode <= `NONE_OPCODE;
                end
            end
            else begin
                if(NextUnit_cur_wqe_opcode == `VERBS_SEND) begin
                    SubWQE_net_opcode <= `SEND_FIRST;
                end
                else if(NextUnit_cur_wqe_opcode == `VERBS_SEND_WITH_IMM) begin
                    SubWQE_net_opcode <= `SEND_FIRST;
                end
                else if(NextUnit_cur_wqe_opcode == `VERBS_RDMA_WRITE) begin
                    SubWQE_net_opcode <= `RDMA_WRITE_FIRST;
                end
                else if(NextUnit_cur_wqe_opcode == `VERBS_RDMA_WRITE_WITH_IMM) begin
                    SubWQE_net_opcode <= `RDMA_WRITE_FIRST;
                end
                else if(NextUnit_cur_wqe_opcode == `VERBS_RDMA_READ) begin
                    SubWQE_net_opcode <= `RDMA_READ_REQUEST_FIRST;
                end
                else begin
                    SubWQE_net_opcode <= `NONE_OPCODE;
                end               
            end
        end
        else begin
            if(wqe_last && (parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb <= meta_pmtu)) begin
                if(NextUnit_cur_wqe_opcode == `VERBS_SEND) begin
                    SubWQE_net_opcode <= `SEND_LAST;
                end
                else if(NextUnit_cur_wqe_opcode == `VERBS_SEND_WITH_IMM) begin
                    SubWQE_net_opcode <= `SEND_LAST_WITH_IMM;
                end
                else if(NextUnit_cur_wqe_opcode == `VERBS_RDMA_WRITE) begin
                    SubWQE_net_opcode <= `RDMA_WRITE_LAST;
                end
                else if(NextUnit_cur_wqe_opcode == `VERBS_RDMA_WRITE_WITH_IMM) begin
                    SubWQE_net_opcode <= `RDMA_WRITE_LAST_WITH_IMM;
                end
                else if(NextUnit_cur_wqe_opcode == `VERBS_RDMA_READ) begin
                    SubWQE_net_opcode <= `RDMA_READ_REQUEST_LAST;
                end
                else begin
                    SubWQE_net_opcode <= `NONE_OPCODE;
                end               
            end
            else begin
                if(NextUnit_cur_wqe_opcode == `VERBS_SEND) begin
                    SubWQE_net_opcode <= `SEND_MIDDLE;
                end
                else if(NextUnit_cur_wqe_opcode == `VERBS_SEND_WITH_IMM) begin
                    SubWQE_net_opcode <= `SEND_MIDDLE;
                end
                else if(NextUnit_cur_wqe_opcode == `VERBS_RDMA_WRITE) begin
                    SubWQE_net_opcode <= `RDMA_WRITE_MIDDLE;
                end
                else if(NextUnit_cur_wqe_opcode == `VERBS_RDMA_WRITE_WITH_IMM) begin
                    SubWQE_net_opcode <= `RDMA_WRITE_MIDDLE;
                end
                else if(NextUnit_cur_wqe_opcode == `VERBS_RDMA_READ) begin
                    SubWQE_net_opcode <= `RDMA_READ_REQUEST_MIDDLE;
                end
                else begin
                    SubWQE_net_opcode <= `NONE_OPCODE;
                end                
            end
        end
    end
    else begin
        SubWQE_net_opcode <= SubWQE_net_opcode;
    end
end

//-- SubWQE_service_type --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        SubWQE_service_type <= 'd0;
    end
    else if(cur_state == NEXT_UNIT_s && wqe_valid) begin
        SubWQE_service_type <= meta_service_type;
    end
    else begin
        SubWQE_service_type <= SubWQE_service_type;
    end
end

//-- SubWQE_wqe_head --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        SubWQE_wqe_head <= 'd0;        
    end
    else if (cur_state == IDLE_s) begin
        SubWQE_wqe_head <= 'd0;
    end
    else if (cur_state == UD_UNIT_1_s || cur_state == INLINE_UNIT_s) begin
        SubWQE_wqe_head <= 'd1;
    end
    else if (cur_state == DATA_UNIT_s && wqe_valid && msg_offset_doutb == 'd0) begin
        SubWQE_wqe_head <= 'd1;
    end
    else begin
        SubWQE_wqe_head <= SubWQE_wqe_head;
    end
end

//-- SubWQE_wqe_tail --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        SubWQE_wqe_tail <= 'd0;        
    end
    else if (cur_state == IDLE_s) begin
        SubWQE_wqe_tail <= 'd0;
    end
    else if (cur_state == UD_UNIT_1_s || cur_state == INLINE_UNIT_s) begin
        SubWQE_wqe_tail <= 'd1;
    end
    else if (cur_state == DATA_UNIT_s && wqe_valid && !data_unit_parse_finish) begin
        if(wqe_last && (parsed_msg_length + DataUnit_byte_cnt > msg_offset_doutb)) begin
            if(parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb <= meta_pmtu) begin
                SubWQE_wqe_tail <= 'd1;
            end
            else begin
                SubWQE_wqe_tail <= 'd0;
            end
        end
        else begin
            SubWQE_wqe_tail <= SubWQE_wqe_tail;
        end
    end
    else begin
        SubWQE_wqe_tail <= SubWQE_wqe_tail;
    end
end

//-- SubWQE_inline --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        SubWQE_inline <= 'd0;        
    end
    else if (cur_state == IDLE_s) begin
        SubWQE_inline <= 'd0;
    end
    else if(cur_state == INLINE_UNIT_s && wqe_valid) begin
        SubWQE_inline <= 'd1;
    end
    else begin
        SubWQE_inline <= SubWQE_inline;
    end
end

//-- SubWQE_ori_wqe_offset --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        SubWQE_ori_wqe_offset <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        SubWQE_ori_wqe_offset <= 'd0;
    end
    else if(cur_state == NEXT_UNIT_s && wqe_valid) begin
        SubWQE_ori_wqe_offset <= sq_offset_dout;
    end
    else begin
        SubWQE_ori_wqe_offset <= SubWQE_ori_wqe_offset;
    end
end

//-- SubWQE_dmac --
//-- SubWQE_smac --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        SubWQE_dmac <= 'd0;
        SubWQE_smac <= 'd0;        
    end
    else if (cur_state == IDLE_s) begin
        SubWQE_dmac <= 'd0;
        SubWQE_smac <= 'd0;           
    end
    else if(cur_state == NEXT_UNIT_s && wqe_valid) begin
        SubWQE_dmac <= meta_dmac;
        SubWQE_smac <= meta_smac;       
    end
    else if(cur_state == UD_UNIT_1_s && wqe_valid) begin
        SubWQE_dmac <= {UDUnit_dmac_high, UDUnit_dmac_low};
        SubWQE_smac <= {UDUnit_smac_high, UDUnit_smac_low};
    end
    else begin
        SubWQE_dmac <= SubWQE_dmac;
        SubWQE_smac <= SubWQE_smac;
    end
end

//-- SubWQE_dip --
//-- SubWQE_sip --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        SubWQE_dip <= 'd0;
        SubWQE_sip <= 'd0;        
    end
    else if (cur_state == IDLE_s) begin
        SubWQE_dip <= 'd0;
        SubWQE_sip <= 'd0;           
    end
    else if(cur_state == NEXT_UNIT_s && wqe_valid) begin
        SubWQE_dip <= meta_dip;
        SubWQE_sip <= meta_sip;       
    end
    else if(cur_state == UD_UNIT_2_s && wqe_valid) begin
        SubWQE_dip <= UDUnit_dip;
        SubWQE_sip <= UDUnit_sip;
    end
    else begin
        SubWQE_dip <= SubWQE_dip;
        SubWQE_sip <= SubWQE_sip;
    end
end

//-- SubWQE_immediate --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        SubWQE_immediate <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        SubWQE_immediate <= 'd0;
    end
    else if(cur_state == NEXT_UNIT_s && wqe_valid) begin
        SubWQE_immediate <= NextUnit_cur_wqe_imm;
    end
    else begin
        SubWQE_immediate <= SubWQE_immediate;
    end
end

//-- SubWQE_lkey --
//-- SubWQE_laddr --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        SubWQE_lkey <= 'd0;
        SubWQE_laddr <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        SubWQE_lkey <= 'd0;
        SubWQE_laddr <= 'd0;        
    end
    else if(cur_state == DATA_UNIT_s && wqe_valid && !data_unit_parse_finish) begin
        if(parsed_msg_length + DataUnit_byte_cnt <= msg_offset_doutb) begin
            SubWQE_lkey <= 'd0;
            SubWQE_laddr <= 'd0;     
        end
        else if(parsed_msg_length + DataUnit_byte_cnt > msg_offset_doutb) begin
            SubWQE_lkey <= DataUnit_lkey;
            SubWQE_laddr <= DataUnit_laddr + (msg_offset_doutb - parsed_msg_length);
        end
        else begin
            SubWQE_lkey <= 'd0;
            SubWQE_laddr <= 'd0;     
        end        
    end
    else begin
        SubWQE_lkey <= SubWQE_lkey;
        SubWQE_laddr <= SubWQE_laddr;        
    end
end

//-- SubWQE_rkey --
//-- SubWQE_raddr --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        SubWQE_rkey <= 'd0;
        SubWQE_raddr <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        SubWQE_rkey <= 'd0;
        SubWQE_raddr <= 'd0;
    end
    else if(cur_state == RADDR_UNIT_s && wqe_valid) begin
        SubWQE_rkey <= RaddrUnit_rkey;
        SubWQE_raddr <= RaddrUnit_raddr;
    end
    else if(cur_state == DATA_UNIT_s && wqe_valid && !data_unit_parse_finish) begin
        if(parsed_msg_length + DataUnit_byte_cnt <= msg_offset_doutb) begin
            SubWQE_rkey <= SubWQE_rkey;
            SubWQE_raddr <= SubWQE_raddr; 
        end
        else if(parsed_msg_length + DataUnit_byte_cnt > msg_offset_doutb) begin
            SubWQE_rkey <= SubWQE_rkey;
            SubWQE_raddr <= SubWQE_raddr + msg_offset_doutb;
        end
        else begin
            SubWQE_rkey <= 'd0;
            SubWQE_raddr <= 'd0;     
        end  
    end
    else begin
        SubWQE_rkey <= SubWQE_rkey;
        SubWQE_raddr <= SubWQE_raddr;          
    end
end

//-- SubWQE_fence --
//-- SubWQE_solicited_event --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        SubWQE_fence <= 'd0;
        SubWQE_solicited_event <= 'd0;   
    end
    else begin
        SubWQE_fence <= 'd0;
        SubWQE_solicited_event <= 'd0;
    end
end

//-- SubWQE_msg_length --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        SubWQE_msg_length <= 'd0;   
    end
    else if (cur_state == IDLE_s) begin
        SubWQE_msg_length <= 'd0;
    end
    else if(cur_state == DATA_UNIT_s && wqe_valid) begin
        SubWQE_msg_length <= SubWQE_msg_length + DataUnit_byte_cnt;
    end
    else if(cur_state == INLINE_UNIT_s && wqe_valid) begin
        SubWQE_msg_length <= InlineUnit_length;
    end
    else begin
        SubWQE_msg_length <= SubWQE_msg_length;
    end
end

//-- SubWQE_packet_length --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        SubWQE_packet_length <= 'd0;       
    end
    else if (cur_state == IDLE_s) begin
        SubWQE_packet_length <= 'd0;
    end
    else if(cur_state == DATA_UNIT_s && wqe_valid && !data_unit_parse_finish) begin
        if(parsed_msg_length + DataUnit_byte_cnt <= msg_offset_doutb) begin
            SubWQE_packet_length <= 'd0;
        end
        else if(parsed_msg_length + DataUnit_byte_cnt > msg_offset_doutb) begin
            if(parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb >= meta_pmtu) begin
                SubWQE_packet_length <= meta_pmtu;
            end
            else begin
                SubWQE_packet_length <= parsed_msg_length + DataUnit_byte_cnt - msg_offset_doutb;
            end           
        end
        else begin
            SubWQE_packet_length <= SubWQE_packet_length;
        end
    end
    else begin
        SubWQE_packet_length <= SubWQE_packet_length;
    end
end

//-- data_unit_parse_finish --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        data_unit_parse_finish <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        data_unit_parse_finish <= 'd0;
    end
    else if(cur_state == DATA_UNIT_s && wqe_valid && (parsed_msg_length + DataUnit_byte_cnt > msg_offset_doutb)) begin
        data_unit_parse_finish <= 'd1;
    end
    else begin
        data_unit_parse_finish <= data_unit_parse_finish;
    end
end

//-- sub_wqe_valid --
//-- sub_wqe_meta --
assign sub_wqe_valid = (cur_state == INJECT_s) ? 'd1 : 'd0;
assign sub_wqe_meta = (cur_state == INJECT_s) ? {inline_payload_start_addr, 16'd0, SubWQE_packet_length, SubWQE_msg_length, 
                                                SubWQE_raddr, SubWQE_rkey, SubWQE_laddr, SubWQE_lkey, SubWQE_immediate,
                                                SubWQE_sip, SubWQE_dip, SubWQE_smac, SubWQE_dmac, SubWQE_ori_wqe_offset, 3'd0, SubWQE_inline,
                                                SubWQE_wqe_tail, SubWQE_wqe_head, 1'b0, SubWQE_fence, SubWQE_service_type,
                                                SubWQE_net_opcode, SubWQE_remote_qpn, 3'd0, SubWQE_verbs_opcode, SubWQE_local_qpn} : 'd0;

//-- qpn_fifo_valid --
//-- qpn_fifo_data --
assign qpn_fifo_valid = (cur_state == RESCHEDULE_s) ? 'd1 : 'd0;
assign qpn_fifo_data = (cur_state == RESCHEDULE_s) ? meta_local_qpn : 'd0;
 
/*********************************************************** Sub-WQE Field Decode : End**********************************************************/
/*------------------------------------------- Variables Decode : End ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef      LOCAL_QPN_OFFSET
`undef      REMOTE_QPN_OFFSET
`undef      DMAC_OFFSET
`undef      SMAC_OFFSET
`undef      DIP_OFFSET
`undef      SIP_OFFSET
`undef      SQ_ENTRY_SZ_LOG_OFFSET
`undef      SQ_LENGTH_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule