/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       SWAccCMCtl_Thread_2
Author:     YangFan
Function:   Handle QPC Rd/Wr Command from CEU.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/



/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module SWAccCMCtl_Thread_2 (
    input   wire                                                                                                clk,
    input   wire                                                                                                rst,

//Interface with SWAccCMCtl_Thread_0
    input   wire                                                                                                qpc_req_valid,
    input   wire    [`CEU_CXT_HEAD_WIDTH - 1 : 0]                                                               qpc_req_head,
    input   wire                                                                                                qpc_req_last,
    input   wire    [`CEU_CXT_DATA_WIDTH - 1 : 0]                                                               qpc_req_data,
    output  wire                                                                                                qpc_req_ready,

//Interface with QPCCache(ICMCache)
//ICM Get Req Interface
    output  wire                                                                                                            icm_get_req_valid,
    output  wire    [`COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + `ICM_SPACE_ADDR_WIDTH + `PHY_SPACE_ADDR_WIDTH - 1 : 0]     icm_get_req_head,
    input   wire                                                                                                            icm_get_req_ready,

//ICM Get Resp Interface
    input   wire                                                                                                            icm_get_rsp_valid,
    input   wire    [`COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + `ICM_SPACE_ADDR_WIDTH + `PHY_SPACE_ADDR_WIDTH - 1 : 0]     icm_get_rsp_head,
    input   wire    [`CACHE_ENTRY_WIDTH_QPC - 1 : 0]                                                                        icm_get_rsp_data,
    output  wire                                                                                                            icm_get_rsp_ready,

//Cache Set Req Interface
    output  wire                                                                                                            icm_set_req_valid,
    output  wire    [`COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + `ICM_SPACE_ADDR_WIDTH + `PHY_SPACE_ADDR_WIDTH - 1 : 0]     icm_set_req_head,
    output  wire     [`CACHE_ENTRY_WIDTH_QPC - 1 : 0]                                                                       icm_set_req_data,
    input   wire                                                                                                            icm_set_req_ready,

//ICM Address Translation Interface
    output  wire                                                                                                icm_mapping_lookup_valid,
    output  wire    [log2b(`ICM_ENTRY_NUM_QPC - 1) - 1 : 0]                                                     icm_mapping_lookup_head,
    input   wire                                                                                                icm_mapping_lookup_ready,

    input   wire                                                                                                icm_mapping_rsp_valid,
    input   wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                                             icm_mapping_rsp_icm_addr,
    input   wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                                             icm_mapping_rsp_phy_addr,
    output  wire                                                                                                icm_mapping_rsp_ready,

//Interface with CEU(Rd QPC Response)
    output  wire                                                                                                qpc_rsp_valid,
    output  wire    [`CEU_CXT_HEAD_WIDTH - 1 : 0]                                                               qpc_rsp_head,
    output  wire                                                                                                qpc_rsp_last,
    output  wire    [`CEU_CXT_DATA_WIDTH - 1 : 0]                                                               qpc_rsp_data,
    input   wire                                                                                                qpc_rsp_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     CEU_CMD_TYPE_OFFSET                                     127:124
`define     CEU_CMD_OPCODE_OFFSET                                   123:120
`define     CEU_CMD_INDEX_OFFSET                                    95:64
`define     QPC_PIECE_NUM                                           6           //192B / 32B(256bit data width) 

`define     WR_QPC_SERVICE_TYPE_OFFSET                              32 * 6 - 8 - 1 : 32 * 6 - 16
`define     WR_QPC_STATE_OFFSET                                     32 * 6 - 1 : 32 * 6 - 4
`define     WR_QPC_MTU_MSGMAX_OFFSET                                32 * 5 - 1 : 32 * 5 - 8
`define     WR_QPC_SQ_ENTRY_SZ_LOG_OFFSET                           32 * 5 - 16 - 1 : 32 * 5 - 24
`define     WR_QPC_RQ_ENTRY_SZ_LOG_OFFSET                           32 * 5 - 8 - 1 : 32 * 5 - 16
`define     WR_QPC_DST_QPN_OFFSET                                   32 * 2 - 1 : 32 * 1
`define     WR_QPC_PKEY_INDEX_OFFSET                                32 * 1 - 6 - 1 : 32 * 1 - 8
`define     WR_QPC_PORT_INDEX_OFFSET                                32 * 1 - 26 - 1 : 32 * 1 - 32
`define     WR_QPC_CQN_SND_OFFSET                                   32 * 4 - 1 : 32 * 3
`define     WR_QPC_CQN_RCV_OFFSET                                   32 * 5 - 1 : 32 * 4
`define     WR_QPC_QP_PD_OFFSET                                     32 * 1 - 1 : 32 * 0
`define     WR_QPC_SQ_LKEY_OFFSET                                   32 * 3 - 1 : 32 * 2
`define     WR_QPC_SQ_LENGTH_OFFSET                                 32 * 2 - 1 : 32 * 1
`define     WR_QPC_RQ_LKEY_OFFSET                                   32 * 4 - 1 : 32 * 3
`define     WR_QPC_RQ_LENGTH_OFFSET                                 32 * 3 - 1 : 32 * 2
`define     WR_QPC_DMAC_LOW_DLID_OFFSET                             32 * 1 - 1 : 32 * 1 - 16
`define     WR_QPC_SMAC_LOW_SLID_OFFSET                             32 * 1 - 16 - 1 : 32 * 0
`define     WR_QPC_DMAC_HIGH_OFFSET                                 32 * 7 - 1 : 32 * 6
`define     WR_QPC_SMAC_HIGH_OFFSET                                 32 * 8 - 1 : 32 * 7
`define     WR_QPC_DIP_OFFSET                                       32 * 5 - 1 : 32 * 4
`define     WR_QPC_SIP_OFFSET                                       32 * 6 - 1 : 32 * 5
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg             [3:0]                                                       qpc_rd_piece_count;
reg             [3:0]                                                       qpc_wr_piece_count;

reg             [`CEU_CXT_HEAD_WIDTH - 1 : 0]                               qpc_req_head_diff;

reg             [`CACHE_ENTRY_WIDTH_QPC - 1 : 0]                            cache_entry;

reg             [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                             icm_addr;
reg             [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                             phy_addr;

wire            [`COUNT_MAX_LOG - 1 : 0]                                    count_max;
wire            [`COUNT_MAX_LOG - 1 : 0]                                    count_index;

wire            [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                  req_tag;

//QPC Info
reg                        [2:0]               wr_service_type;
reg                        [2:0]               wr_state;
reg                        [7:0]               wr_mtu_msgmax;
reg                        [7:0]               wr_sq_entry_sz_log;
reg                        [7:0]               wr_rq_entry_sz_log;
reg                        [15:0]              wr_dst_qpn;
reg                        [7:0]               wr_pkey_index;
reg                        [7:0]               wr_port_index;
reg                        [15:0]              wr_cqn_snd;
reg                        [15:0]              wr_cqn_rcv;
reg                        [31:0]              wr_qp_pd;
reg                        [31:0]              wr_sq_lkey;
reg                        [31:0]              wr_sq_length;
reg                        [31:0]              wr_rq_lkey;
reg                        [31:0]              wr_rq_length;
reg                        [15:0]              wr_dmac_low_dlid;
reg                        [15:0]              wr_smac_low_slid;
reg                        [31:0]              wr_dmac_high;
reg                        [31:0]              wr_smac_high;
reg                        [31:0]              wr_dip;
reg                        [31:0]              wr_sip;

wire                        [2:0]              rd_service_type;
wire                        [3:0]              rd_state;
wire                        [7:0]              rd_mtu_msgmax;
wire                        [7:0]              rd_sq_entry_sz_log;
wire                        [7:0]              rd_rq_entry_sz_log;
wire                        [15:0]             rd_dst_qpn;
wire                        [7:0]              rd_pkey_index;
wire                        [7:0]              rd_port_index;
wire                        [15:0]             rd_cqn_snd;
wire                        [15:0]             rd_cqn_rcv;
wire                        [31:0]             rd_qp_pd;
wire                        [31:0]             rd_sq_lkey;
wire                        [31:0]             rd_sq_length;
wire                        [31:0]             rd_rq_lkey;
wire                        [31:0]             rd_rq_length;
wire                        [15:0]             rd_dmac_low_dlid;
wire                        [15:0]             rd_smac_low_slid;
wire                        [31:0]             rd_dmac_high;
wire                        [31:0]             rd_smac_high;
wire                        [31:0]             rd_dip;
wire                        [31:0]             rd_sip;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg         [3:0]               cur_state;
reg         [3:0]               next_state;

parameter   [3:0]               IDLE_s = 4'd1,
                                ADDR_REQ_s = 4'd2,
                                ADDR_RSP_s = 4'd3,
                                CACHE_GET_s = 4'd4,
                                CACHE_RSP_s = 4'd5,
                                CEU_RSP_s = 4'd6,
                                QPC_COLLECT_s = 4'd7,
                                CACHE_SET_s = 4'd8;

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
        IDLE_s:             if(qpc_req_valid) begin
                                next_state = ADDR_REQ_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
        ADDR_REQ_s:         if(icm_mapping_lookup_valid && icm_mapping_lookup_ready) begin
                                next_state = ADDR_RSP_s;
                            end
                            else begin
                                next_state = ADDR_REQ_s;
                            end
        ADDR_RSP_s:         if(icm_mapping_rsp_valid) begin
                                if(qpc_req_valid && qpc_req_head_diff[`CEU_CMD_TYPE_OFFSET] == `RD_QP_CXT) begin
                                    next_state = CACHE_GET_s;
                                end
                                else if(qpc_req_valid && qpc_req_head_diff[`CEU_CMD_TYPE_OFFSET] == `WR_QP_CXT) begin
                                    next_state = QPC_COLLECT_s;
                                end
                                else begin
                                    next_state = IDLE_s;
                                end
                            end
                            else begin
                                next_state = ADDR_RSP_s;
                            end
        CACHE_GET_s:        if(icm_get_req_valid && icm_get_req_ready) begin
                                next_state = CACHE_RSP_s;
                            end
                            else begin
                                next_state = CACHE_GET_s;
                            end
        CACHE_RSP_s:        if(icm_get_rsp_valid && icm_get_rsp_ready) begin
                                next_state = CEU_RSP_s;
                            end
                            else begin
                                next_state = CACHE_RSP_s;
                            end
        CEU_RSP_s:          if(qpc_rd_piece_count == `QPC_PIECE_NUM && qpc_rsp_valid && qpc_rsp_ready) begin
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = CEU_RSP_s;
                            end
        QPC_COLLECT_s:      if(qpc_wr_piece_count == `QPC_PIECE_NUM && qpc_req_valid && qpc_req_ready) begin
                                next_state = CACHE_SET_s;
                            end
                            else begin
                                next_state = QPC_COLLECT_s;
                            end
        CACHE_SET_s:        if(icm_set_req_valid && icm_set_req_ready) begin
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = CACHE_SET_s;
                            end
        default:            next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- Wr QPC Info --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        wr_service_type <= 'd0;
        wr_state <= 'd0;
        wr_mtu_msgmax <= 'd0;
        wr_sq_entry_sz_log <= 'd0;
        wr_rq_entry_sz_log <= 'd0;
        wr_dst_qpn <= 'd0;
        wr_pkey_index <= 'd0;
        wr_port_index <= 'd0;
        wr_cqn_snd <= 'd0;
        wr_cqn_rcv <= 'd0;
        wr_qp_pd <= 'd0;
        wr_sq_lkey <= 'd0;
        wr_sq_length <= 'd0;
        wr_rq_lkey <= 'd0;
        wr_rq_length <= 'd0;
        wr_dmac_low_dlid <= 'd0;
        wr_smac_low_slid <= 'd0;
        wr_dmac_high <= 'd0;
        wr_smac_high <= 'd0;
        wr_dip <= 'd0;
        wr_sip <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        wr_service_type <= 'd0;
        wr_state <= 'd0;
        wr_mtu_msgmax <= 'd0;
        wr_sq_entry_sz_log <= 'd0;
        wr_rq_entry_sz_log <= 'd0;
        wr_dst_qpn <= 'd0;
        wr_pkey_index <= 'd0;
        wr_port_index <= 'd0;
        wr_cqn_snd <= 'd0;
        wr_cqn_rcv <= 'd0;
        wr_qp_pd <= 'd0;
        wr_sq_lkey <= 'd0;
        wr_sq_length <= 'd0;
        wr_rq_lkey <= 'd0;
        wr_rq_length <= 'd0;
        wr_dmac_low_dlid <= 'd0;
        wr_smac_low_slid <= 'd0;
        wr_dmac_high <= 'd0;
        wr_smac_high <= 'd0;
        wr_dip <= 'd0;
        wr_sip <= 'd0;       
    end
    else if(cur_state == QPC_COLLECT_s && qpc_req_valid) begin
        wr_service_type <= (qpc_wr_piece_count == 1) ? qpc_req_data[`WR_QPC_SERVICE_TYPE_OFFSET] : wr_service_type;
        wr_state <= (qpc_wr_piece_count == 1) ? qpc_req_data[`WR_QPC_STATE_OFFSET] : wr_state;
        wr_mtu_msgmax <= (qpc_wr_piece_count == 1) ? qpc_req_data[`WR_QPC_MTU_MSGMAX_OFFSET] : wr_mtu_msgmax;
        wr_sq_entry_sz_log <= (qpc_wr_piece_count == 1) ? qpc_req_data[`WR_QPC_SQ_ENTRY_SZ_LOG_OFFSET] : wr_sq_entry_sz_log;
        wr_rq_entry_sz_log <= (qpc_wr_piece_count == 1) ? qpc_req_data[`WR_QPC_RQ_ENTRY_SZ_LOG_OFFSET] : wr_rq_entry_sz_log;
        wr_dst_qpn <= (qpc_wr_piece_count == 1) ? qpc_req_data[`WR_QPC_DST_QPN_OFFSET] : wr_dst_qpn;
        wr_pkey_index <= (qpc_wr_piece_count == 2) ? qpc_req_data[`WR_QPC_PKEY_INDEX_OFFSET] : wr_pkey_index;
        wr_port_index <= (qpc_wr_piece_count == 2) ? qpc_req_data[`WR_QPC_PORT_INDEX_OFFSET] : wr_port_index;
        wr_cqn_snd <= (qpc_wr_piece_count == 4) ? qpc_req_data[`WR_QPC_CQN_SND_OFFSET] : wr_cqn_snd;
        wr_cqn_rcv <= (qpc_wr_piece_count == 5) ? qpc_req_data[`WR_QPC_CQN_RCV_OFFSET] : wr_cqn_rcv;
        wr_qp_pd <= (qpc_wr_piece_count == 3) ? qpc_req_data[`WR_QPC_QP_PD_OFFSET] : wr_qp_pd;
        wr_sq_lkey <= (qpc_wr_piece_count == 4) ? qpc_req_data[`WR_QPC_SQ_LKEY_OFFSET] : wr_sq_lkey;
        wr_sq_length <= (qpc_wr_piece_count == 4) ? qpc_req_data[`WR_QPC_SQ_LENGTH_OFFSET] : wr_sq_length;
        wr_rq_lkey <= (qpc_wr_piece_count == 5) ? qpc_req_data[`WR_QPC_RQ_LKEY_OFFSET] : wr_rq_lkey;
        wr_rq_length <= (qpc_wr_piece_count == 5) ? qpc_req_data[`WR_QPC_RQ_LENGTH_OFFSET] : wr_rq_length;
        wr_dmac_low_dlid <= (qpc_wr_piece_count == 2) ? qpc_req_data[`WR_QPC_DMAC_LOW_DLID_OFFSET] : wr_dmac_low_dlid;
        wr_smac_low_slid <= (qpc_wr_piece_count == 2) ? qpc_req_data[`WR_QPC_SMAC_LOW_SLID_OFFSET] : wr_smac_low_slid;
        wr_dmac_high <= (qpc_wr_piece_count == 3) ? qpc_req_data[`WR_QPC_DMAC_HIGH_OFFSET] : wr_dmac_high;
        wr_smac_high <= (qpc_wr_piece_count == 3) ? qpc_req_data[`WR_QPC_SMAC_HIGH_OFFSET] : wr_smac_high;
        wr_dip <= (qpc_wr_piece_count == 3) ?  qpc_req_data[`WR_QPC_DIP_OFFSET] : wr_dip;
        wr_sip <= (qpc_wr_piece_count == 3) ? qpc_req_data[`WR_QPC_SIP_OFFSET] : wr_sip;    
    end
    else begin
        wr_service_type <= wr_service_type;
        wr_state <= wr_state;
        wr_mtu_msgmax <= wr_mtu_msgmax;
        wr_sq_entry_sz_log <= wr_sq_entry_sz_log;
        wr_rq_entry_sz_log <= wr_rq_entry_sz_log;
        wr_dst_qpn <= wr_dst_qpn;
        wr_pkey_index <= wr_pkey_index;
        wr_port_index <= wr_port_index;
        wr_cqn_snd <= wr_cqn_snd;
        wr_cqn_rcv <= wr_cqn_rcv;
        wr_qp_pd <= wr_qp_pd;
        wr_sq_lkey <= wr_sq_lkey;
        wr_sq_length <= wr_sq_length;
        wr_rq_lkey <= wr_rq_lkey;
        wr_rq_length <= wr_rq_length;
        wr_dmac_low_dlid <= wr_dmac_low_dlid;
        wr_smac_low_slid <= wr_smac_low_slid;
        wr_dmac_high <= wr_dmac_high;
        wr_smac_high <= wr_smac_high;
        wr_dip <= wr_dip;
        wr_sip <= wr_sip;
    end
end

//-- Rd QPC Info --
assign rd_service_type = cache_entry[2:0];
assign rd_state = cache_entry[5:3];
assign rd_mtu_msgmax = cache_entry[15:8];
assign rd_sq_entry_sz_log = cache_entry[23:16];
assign rd_rq_entry_sz_log = cache_entry[31:24];
assign rd_dst_qpn = cache_entry[47:32];
assign rd_pkey_index = cache_entry[55:48];
assign rd_port_index = cache_entry[63:56];
assign rd_cqn_snd = cache_entry[79:64];
assign rd_cqn_rcv = cache_entry[95:80];
assign rd_qp_pd = cache_entry[127:96];
assign rd_sq_lkey = cache_entry[159:128];
assign rd_sq_length = cache_entry[191:160];
assign rd_rq_lkey = cache_entry[223:192];
assign rd_rq_length = cache_entry[255:224];
assign rd_dmac_low_dlid = cache_entry[31+256:16+256];
assign rd_smac_low_slid = cache_entry[15+256:0+256];
assign rd_dmac_high = cache_entry[95+256:64+256];
assign rd_smac_high = cache_entry[63+256:32+256];
assign rd_dip = cache_entry[159+256:128+256];
assign rd_sip = cache_entry[127+256:96+256];

//-- count_max --
//-- count_index --
assign count_max = 'd1;     //Specific for QPC/EQC/CQC/MPT, 2 for MTT
assign count_index = 'd0;   //Specific for QPC/EQC/CQC/MPT, 0, 1 for MTT

//-- req_tag --
assign req_tag = 'd0;       //Specific for CEU request, RPCCore will use tag start from 1.

//-- qpc_rd_piece_count --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qpc_rd_piece_count <= 'd0;        
    end
    else if (cur_state == IDLE_s) begin
        qpc_rd_piece_count <= 'd0;
    end
    else if (cur_state == CACHE_RSP_s && icm_get_rsp_valid && icm_get_rsp_ready) begin
        qpc_rd_piece_count <= 'd1;
    end
    else if (cur_state == CEU_RSP_s && qpc_rsp_valid && qpc_rsp_ready) begin
        qpc_rd_piece_count <= qpc_rd_piece_count + 'd1;
    end
    else begin
        qpc_rd_piece_count <= qpc_rd_piece_count;
    end
end

//-- qpc_wr_piece_count --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qpc_wr_piece_count <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        qpc_wr_piece_count <= 'd0;
    end
    else if(cur_state == ADDR_RSP_s && next_state == QPC_COLLECT_s) begin
        qpc_wr_piece_count <= 'd1;
    end
    else if(cur_state == QPC_COLLECT_s && qpc_req_valid && qpc_req_ready) begin
        qpc_wr_piece_count <= qpc_wr_piece_count + 'd1;
    end
    else begin
        qpc_wr_piece_count <= qpc_wr_piece_count;
    end
end

//-- qpc_req_head_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qpc_req_head_diff <= 'd0;
    end
    else if(cur_state == IDLE_s && qpc_req_valid) begin
        qpc_req_head_diff <= qpc_req_head;
    end
    else begin
        qpc_req_head_diff <= qpc_req_head_diff;
    end
end

//-- icm_addr --
//-- phy_addr --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        icm_addr <= 'd0;
        phy_addr <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        icm_addr <= 'd0;
        phy_addr <= 'd0;
    end
    else if(cur_state == ADDR_RSP_s && icm_mapping_rsp_valid) begin
        icm_addr <= icm_mapping_rsp_icm_addr;
        phy_addr <= icm_mapping_rsp_phy_addr;
    end
    else begin
        icm_addr <= icm_addr;
        phy_addr <= phy_addr;
    end
end

wire  		[31:0] 	ceu_cmd_index;
wire 		[`QP_NUM_LOG - 1 : 0]		qpn;
assign ceu_cmd_index = qpc_req_head_diff[`CEU_CMD_INDEX_OFFSET];
assign qpn = ceu_cmd_index[`QP_NUM_LOG - 1 : 0];

//-- icm_mapping_lookup_valid --
//-- icm_mapping_lookup_head --
assign icm_mapping_lookup_valid = (cur_state == ADDR_REQ_s) ? 'd1 : 'd0;
assign icm_mapping_lookup_head = (cur_state == ADDR_REQ_s) ? qpn : 'd0;  //Notice  CEU_CMD_INDEX_OFFSET is 32bit, may exceed actual index length, it does not matter

//-- icm_mapping_rsp_ready --
assign icm_mapping_rsp_ready = (cur_state == ADDR_RSP_s) ? 'd1 : 'd0;

//-- icm_get_req_valid --
//-- icm_get_req_head --
assign icm_get_req_valid = (cur_state == CACHE_GET_s) ? 'd1 : 'd0;
assign icm_get_req_head = (cur_state == CACHE_GET_s) ? {count_max, count_index, req_tag, phy_addr, icm_addr} : 'd0;

//-- icm_set_req_valid --
//-- icm_set_req_head --
//-- icm_set_req_data --
assign icm_set_req_valid = (cur_state == CACHE_SET_s) ? 'd1 : 'd0;
assign icm_set_req_head = (cur_state == CACHE_SET_s) ? {req_tag, count_max, count_index, phy_addr, icm_addr} : 'd0;
assign icm_set_req_data = {wr_sip, wr_dip, wr_dmac_high, wr_dmac_low_dlid, wr_smac_high, wr_smac_low_slid, wr_rq_length, wr_rq_lkey, wr_sq_length, wr_sq_lkey, wr_qp_pd, wr_cqn_rcv, wr_cqn_snd, wr_port_index,
                                wr_pkey_index, wr_dst_qpn, wr_rq_entry_sz_log, wr_sq_entry_sz_log, wr_mtu_msgmax, 2'd0, wr_state, wr_service_type};

//-- cache_entry --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cache_entry <= 'd0;        
    end
    else if (cur_state == IDLE_s) begin
        cache_entry <= 'd0;
    end
    else if (cur_state == CACHE_RSP_s && icm_get_rsp_valid) begin
        cache_entry <= icm_get_rsp_data;
    end
    else begin
        cache_entry <= cache_entry;
    end
end

//-- qpc_req_ready --
//Break timing loop
// assign qpc_req_ready = (cur_state == ADDR_RSP_s && next_state == CACHE_GET_s) ? 'd1 :
//                         (cur_state == QPC_COLLECT_s) ? 'd1 : 'd0;
assign qpc_req_ready = (cur_state == ADDR_RSP_s && ((icm_mapping_rsp_valid) && (qpc_req_head_diff[`CEU_CMD_TYPE_OFFSET] == `RD_QP_CXT))) ? 'd1 :
                        (cur_state == QPC_COLLECT_s) ? 'd1 : 'd0;

//-- icm_get_rsp_ready --
assign icm_get_rsp_ready = (cur_state == CACHE_RSP_s) ? 'd1 : 'd0;

//-- icm_mapping_rsp_ready --
assign icm_mapping_rsp_ready = (cur_state == ADDR_RSP_s) ? 'd1 : 'd0;

//-- qpc_rsp_valid --
//-- qpc_rsp_head --
//-- qpc_rsp_last --
assign qpc_rsp_valid = (cur_state == CEU_RSP_s) ? 'd1 : 'd0;
assign qpc_rsp_head = (cur_state == CEU_RSP_s) ? qpc_req_head_diff : 'd0;
assign qpc_rsp_last = (cur_state == CEU_RSP_s && qpc_rd_piece_count == 6) ? 'd1 : 'd0;

//-- qpc_rsp_data --
assign qpc_rsp_data = (cur_state == CEU_RSP_s && qpc_rd_piece_count == 1) ? {rd_port_index, rd_pkey_index, rd_dst_qpn, qpc_req_head_diff[`CEU_CMD_INDEX_OFFSET], 32'd0, rd_mtu_msgmax, 
                                                                        rd_rq_entry_sz_log, rd_sq_entry_sz_log, 8'd0, {2'd0, rd_state}, 3'd0, {5'd0, rd_service_type}, 80'd0} :
                    (cur_state == CEU_RSP_s && qpc_rd_piece_count == 2) ? {rd_dmac_low_dlid, rd_smac_low_slid, 192'd0, rd_port_index, 16'd0, rd_pkey_index} :
                    (cur_state == CEU_RSP_s && qpc_rd_piece_count == 3) ? {rd_qp_pd, 96'd0, rd_dip, rd_sip, rd_dmac_high, rd_smac_high} :
                    (cur_state == CEU_RSP_s && qpc_rd_piece_count == 4) ? {32'd0, rd_sq_length, rd_sq_lkey, rd_cqn_snd, 128'd0} :
                    (cur_state == CEU_RSP_s && qpc_rd_piece_count == 5) ? {32'd0, 32'd0, rd_rq_length, rd_rq_lkey, rd_cqn_rcv, 96'd0} :
                    (cur_state == CEU_RSP_s && qpc_rd_piece_count == 6) ? {256'd0} : 'd0;

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef  CEU_CMD_OPCODE_OFFSET
`undef  QPC_PIECE_NUM

`undef     WR_QPC_SERVICE_TYPE_OFFSET
`undef     WR_QPC_STATE_OFFSET
`undef     WR_QPC_MTU_MSGMAX_OFFSET
`undef     WR_QPC_SQ_ENTRY_SZ_LOG_OFFSET
`undef     WR_QPC_RQ_ENTRY_SZ_LOG_OFFSET
`undef     WR_QPC_DST_QPN_OFFSET
`undef     WR_QPC_PKEY_INDEX_OFFSET
`undef     WR_QPC_PORT_INDEX_OFFSET
`undef     WR_QPC_CQN_SND_OFFSET
`undef     WR_QPC_CQN_RCV_OFFSET
`undef     WR_QPC_QP_PD_OFFSET
`undef     WR_QPC_SQ_LKEY_OFFSET
`undef     WR_QPC_SQ_LENGTH_OFFSET
`undef     WR_QPC_RQ_LKEY_OFFSET
`undef     WR_QPC_RQ_LENGTH_OFFSET
`undef     WR_QPC_DMAC_LOW_DLID_OFFSET
`undef     WR_QPC_SMAC_LOW_SLID_OFFSET
`undef     WR_QPC_DMAC_HIGH_OFFSET
`undef     WR_QPC_SMAC_HIGH_OFFSET
`undef     WR_QPC_DIP_OFFSET
`undef     WR_QPC_SIP_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

`ifdef  ILA_ON
    ila_sw_acc_cm_thread_2 ila_sw_acc_cm_thread_2_inst(
        .clk(clk),

        .probe0(qpc_req_valid),
        .probe1(qpc_req_head),
        .probe2(qpc_req_data),
        .probe3(qpc_req_last),
        .probe4(qpc_req_ready),

        .probe5(icm_set_req_valid),
        .probe6(icm_set_req_head),
        .probe7(icm_set_req_data),
        .probe8(icm_set_req_ready),

        .probe9(icm_mapping_lookup_valid),
        .probe10(icm_mapping_lookup_head),
        .probe11(icm_mapping_lookup_ready),

        .probe12(icm_mapping_rsp_valid),
        .probe13(icm_mapping_rsp_icm_addr),
        .probe14(icm_mapping_rsp_phy_addr),
        .probe15(icm_mapping_rsp_ready)
    );
`endif

endmodule