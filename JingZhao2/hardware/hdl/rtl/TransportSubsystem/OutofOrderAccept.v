/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       OutOfOrderAccept
Author:     YangFan
Function:   Detect out-of-order packet and buffer these packets.
            For UC/UD, in-order packet are directly commit to ULP;
            For RC, packet are first enqueued, and commit by InOrderCommit, metadata(QPN and PSN) are passed to InOrderCommit.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "ib_constant_def_h.vh"
`include "common_function_def.vh"
`include "transport_subsystem_def.vh"
`include "global_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module OutOfOrderAccept (
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with Network
    input   wire                                                            i_packet_in_valid,
    input   wire                [`PKT_HEAD_WIDTH - 1 : 0]                   iv_packet_in_head,
    input   wire                [`PKT_DATA_WIDTH - 1 : 0]                   iv_packet_in_data,
    input   wire                                                            i_packet_in_start,
    input   wire                                                            i_packet_in_last,
    output  reg                                                             o_packet_in_ready,

//EPSN control
    output  reg                 [`QP_NUM_LOG - 1 : 0]                       ov_epsn_rd_index,
    input   wire                [`PSN_WIDTH - 1 : 0]                        iv_epsn_rd_data,
    output  reg                                                             o_epsn_wr_en,
    output  reg                 [`QP_NUM_LOG - 1 : 0]                       ov_epsn_wr_index,
    output  reg                 [`PSN_WIDTH - 1 : 0]                        ov_epsn_wr_data,
    

//Find nearest received packet
    output  reg                                                             o_find_req_valid,
    output  reg                 [`QP_NUM_LOG + `PSN_WIDTH - 1 : 0]          ov_find_req_head,
    input   wire                                                            i_find_resp_valid,
    input   wire                [`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG : 0]         iv_find_resp_data,

//Interface with PacketBufferMgt
    //Enqueue Packet
    input   wire                [`RECV_BUFFER_SLOT_NUM_LOG - 1 : 0]         iv_available_slot_num,
    output  reg                                                             o_insert_req_valid,
    output  reg                 [`PKT_HEAD_WIDTH - 1 : 0]                   ov_insert_req_head,
    output  reg                 [`PKT_DATA_WIDTH - 1 : 0]                   ov_insert_req_data,
    output  reg                                                             o_insert_req_start,
    output  reg                                                             o_insert_req_last,
    input   wire                                                            i_insert_req_ready,

//Interface with ULP(UC/UD packet commit)
    output  reg                                                             o_commit_valid,
    output  reg                 [`PKT_HEAD_WIDTH - 1 : 0]                   ov_commit_head,
    output  reg                 [`PKT_DATA_WIDTH - 1 : 0]                   ov_commit_data,
    output  reg                                                             o_commit_start,
    output  reg                                                             o_commit_last,
    input   wire                                                            i_commit_ready,

//ACK out
    output  reg                                                             o_ack_out_valid,
    output  reg                 [`PKT_HEAD_WIDTH - 1 : 0]                   ov_ack_out_head,
    output  reg                 [`PKT_DATA_WIDTH - 1 : 0]                   ov_ack_out_data,
    output  reg                                                             o_ack_out_start,
    output  reg                                                             o_ack_out_last,
    input   wire                                                            i_ack_out_ready,

//Metadata to InOrderCommit
    output  reg                                                             o_pkt_meta_wr_en,
    output  reg                 [`PKT_META_WIDTH - 1 : 0]                   ov_pkt_meta_din,
    input   wire                                                            i_pkt_meta_prog_full

);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire            [2:0]                                       wv_service_type;
wire            [`RECV_BUFFER_SLOT_NUM_LOG - 1 : 0]         wv_slot_required;
wire            [23:0]                                      wv_qpn;
wire            [23:0]                                      wv_rpsn;
wire            [23:0]                                      wv_epsn;
reg             [2:0]                                       qv_service_type;
reg             [`RECV_BUFFER_SLOT_NUM_LOG - 1 : 0]         qv_slot_required;
reg             [23:0]                                      qv_qpn;
reg             [23:0]                                      qv_rpsn;
reg             [23:0]                                      qv_epsn;
reg             [23:0]                                      qv_find_psn;

reg             [15:0]                                      qv_insert_count;

wire            [15:0]                                      wv_payload_len;

reg                                                         q_already_buffered;

wire            [47:0]                                      wv_dstMAC;
wire            [47:0]                                      wv_srcMAC;
wire            [31:0]                                      wv_dstIP;
wire            [31:0]                                      wv_srcIP;
wire            [23:0]                                      wv_dstQPN;
wire            [23:0]                                      wv_srcQPN;

reg             [47:0]                                      qv_dstMAC;
reg             [47:0]                                      qv_srcMAC;
reg             [31:0]                                      qv_dstIP;
reg             [31:0]                                      qv_srcIP;
reg             [23:0]                                      qv_dstQPN;
reg             [23:0]                                      qv_srcQPN;

reg                                                         q_loss_detected;

reg             [23:0]                                      qv_retrans_lower_bound;
reg             [23:0]                                      qv_retrans_upper_bound;

reg                                                         q_sack_valid;

reg                                                         q_insert_header;

reg                                                         q_locate_loss;

reg             [23:0]                                      qv_find_psn_diff;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
//NULL
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg             [3:0]           ooa_cur_state;
reg             [3:0]           ooa_next_state;

parameter       [3:0]           OOA_IDLE_s = 4'd1,
                                OOA_UNRELIABLE_JUDGE_s = 4'd2,
                                OOA_UNRELIABLE_COMMIT_s = 4'd3,
                                OOA_UNRELIABLE_DROP_s = 4'd4,
                                OOA_RELIABLE_JUDGE_s = 4'd5,
                                OOA_RELIABLE_INSERT_s = 4'd6,
                                OOA_RELIABLE_LOCATE_LOSS_s ='d7,
                                OOA_RELIABLE_COMMIT_s = 4'd8,
                                OOA_RELIABLE_DROP_s = 4'd9,
                                OOA_RELIABLE_ACK_s = 4'd10;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        ooa_cur_state <= OOA_IDLE_s;
    end
    else begin
        ooa_cur_state <= ooa_next_state;
    end
end

always @(*) begin
    case(ooa_cur_state) 
        OOA_IDLE_s:                  if(i_packet_in_valid) begin
                                        if(wv_service_type == `UC || wv_service_type == `UD) begin
                                            ooa_next_state = OOA_UNRELIABLE_JUDGE_s;
                                        end
                                        else if(wv_service_type == `RC) begin
                                            ooa_next_state = OOA_RELIABLE_JUDGE_s;
                                        end
                                        else begin
                                            ooa_next_state = OOA_IDLE_s;
                                        end
                                    end 
                                    else begin
                                        ooa_next_state = OOA_IDLE_s;
                                    end
        OOA_UNRELIABLE_JUDGE_s:      if(wv_rpsn == wv_epsn) begin
                                        ooa_next_state = OOA_UNRELIABLE_COMMIT_s;
                                    end
                                    else begin
                                        ooa_next_state = OOA_UNRELIABLE_DROP_s;
                                    end
        OOA_UNRELIABLE_COMMIT_s:     if(i_packet_in_valid && i_packet_in_last && i_commit_ready) begin
                                        ooa_next_state = OOA_IDLE_s;
                                    end
                                    else begin
                                        ooa_next_state = OOA_UNRELIABLE_COMMIT_s;
                                    end
        OOA_UNRELIABLE_DROP_s:       if(i_packet_in_valid && i_packet_in_last) begin
                                        ooa_next_state = OOA_IDLE_s;
                                    end
                                    else begin
                                        ooa_next_state = OOA_UNRELIABLE_DROP_s;
                                    end
        OOA_RELIABLE_JUDGE_s:       if(qv_rpsn < wv_epsn) begin
                                        ooa_next_state = OOA_RELIABLE_DROP_s;
                                    end
                                    else if(qv_rpsn == wv_epsn) begin
                                        if(i_find_resp_valid && !iv_find_resp_data[`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG]) begin
                                            if(qv_slot_required <= iv_available_slot_num) begin
                                                ooa_next_state = OOA_RELIABLE_INSERT_s;    
                                            end
                                            else begin
                                                ooa_next_state = OOA_RELIABLE_DROP_s;
                                            end
                                        end
                                        else if(i_find_resp_valid && iv_find_resp_data[`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG]) begin
                                            ooa_next_state = OOA_RELIABLE_DROP_s;
                                        end
                                        else begin
                                            ooa_next_state = OOA_RELIABLE_JUDGE_s;
                                        end
                                    end
                                    else if(wv_rpsn > wv_epsn) begin    //Complicated, need to precisely decide the lower boundary of loss packets.
                                        if(i_find_resp_valid && !iv_find_resp_data[`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG]) begin     //We still need to judge whether this packet is duplicate for further decision
                                            if(qv_slot_required <= iv_available_slot_num) begin
                                                ooa_next_state = OOA_RELIABLE_INSERT_s;    
                                            end
                                            else begin
                                                ooa_next_state = OOA_RELIABLE_DROP_s;
                                            end
                                        end
                                        else if(i_find_resp_valid && iv_find_resp_data[`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG]) begin
                                            ooa_next_state = OOA_RELIABLE_LOCATE_LOSS_s;
                                        end
                                        else begin
                                            ooa_next_state = OOA_RELIABLE_JUDGE_s;
                                        end
                                    end
                                    else begin
                                        ooa_next_state = OOA_RELIABLE_DROP_s;
                                    end
        OOA_RELIABLE_LOCATE_LOSS_s: if(i_find_resp_valid) begin
                                        if(!iv_find_resp_data[`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG]) begin
                                            if(wv_epsn == qv_find_psn_diff) begin   //Lower bound is EPSN
                                                ooa_next_state = OOA_RELIABLE_ACK_s;
                                            end
                                            else begin
                                                ooa_next_state = OOA_RELIABLE_LOCATE_LOSS_s;    //Not reach lower bound, continue searching 
                                            end
                                        end
                                        else begin
                                            ooa_next_state = OOA_RELIABLE_ACK_s;
                                        end
                                    end
                                    else begin
                                        ooa_next_state = OOA_RELIABLE_LOCATE_LOSS_s;                                  
                                    end
        OOA_RELIABLE_INSERT_s:      if(i_packet_in_valid && i_packet_in_last) begin
                                        if(q_locate_loss) begin
                                            ooa_next_state = OOA_RELIABLE_LOCATE_LOSS_s;
                                        end
                                        else begin
                                            ooa_next_state = OOA_RELIABLE_COMMIT_s;
                                        end
                                    end
                                    else begin
                                        ooa_next_state = OOA_RELIABLE_INSERT_s;
                                    end
        OOA_RELIABLE_DROP_s:        if(i_packet_in_valid && i_packet_in_last) begin
                                        ooa_next_state = OOA_RELIABLE_ACK_s;
                                    end
                                    else begin
                                        ooa_next_state = OOA_RELIABLE_DROP_s;
                                    end
        OOA_RELIABLE_COMMIT_s:      if(i_find_resp_valid) begin
                                        if(iv_find_resp_data[`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG]) begin
                                            ooa_next_state = OOA_RELIABLE_COMMIT_s;     //Continue searching
                                        end
                                        else begin
                                            ooa_next_state = OOA_RELIABLE_ACK_s;
                                        end
                                    end
                                    else begin
                                        ooa_next_state = OOA_RELIABLE_COMMIT_s;
                                    end
        OOA_RELIABLE_ACK_s:         if(i_ack_out_ready) begin
                                        ooa_next_state = OOA_IDLE_s;
                                    end
                                    else begin
                                        ooa_next_state = OOA_RELIABLE_ACK_s;
                                    end
        default:                    ooa_next_state = OOA_IDLE_s;
    endcase
end

/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- wv_dstMAC --
assign wv_dstMAC = iv_packet_in_head[`DST_MAC_OFFSET];

//-- wv_srcMAC --
assign wv_srcMAC = iv_packet_in_head[`SRC_MAC_OFFSET];

//-- wv_dstIP --
assign wv_dstIP = iv_packet_in_head[`DST_IP_OFFSET];

//-- wv_srcIP --
assign wv_srcIP = iv_packet_in_head[`SRC_IP_OFFSET];

//-- wv_dstQPN --
assign wv_dstQPN = iv_packet_in_head[`DST_QPN_OFFSET];

//-- wv_srcQPN --
assign wv_srcQPN = iv_packet_in_head[`SRC_QPN_OFFSET];

//-- q_locate_loss --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_locate_loss <= 'd0;
    end
    else if(ooa_cur_state <= OOA_IDLE_s) begin
        q_locate_loss <= 'd0;
    end
    else if(ooa_cur_state == OOA_RELIABLE_JUDGE_s && wv_epsn < qv_rpsn)  begin
        q_locate_loss <= 'd1;
    end
    else begin
        q_locate_loss <= q_locate_loss;
    end
end

//-- qv_dstMAC --
//-- qv_srcMAC --
//-- qv_dstIP --
//-- qv_srcIP --
//-- qv_dstQPN --
//-- qv_srcQPN --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_dstMAC <= 'd0;
        qv_srcMAC <= 'd0;
        qv_dstIP <= 'd0;
        qv_srcIP <= 'd0;
        qv_dstQPN <= 'd0;
        qv_srcQPN <= 'd0;
    end
    else if(ooa_cur_state == OOA_IDLE_s && i_packet_in_valid) begin
        qv_dstMAC <= wv_srcMAC;
        qv_srcMAC <= wv_dstMAC;
        qv_dstIP <= wv_dstIP;
        qv_srcIP <= wv_srcIP;
        qv_dstQPN <= wv_srcQPN;
        qv_srcQPN <= wv_dstQPN;
    end
    else begin
        qv_dstMAC <= qv_dstMAC;
        qv_srcMAC <= qv_srcMAC;
        qv_dstIP <= qv_dstIP;
        qv_srcIP <= qv_srcIP;
        qv_dstQPN <= qv_dstQPN;
        qv_srcQPN <= qv_srcQPN;
    end
end

//-- wv_service_type --
assign wv_service_type = iv_packet_in_head[`SERVICE_TYPE_OFFSET];

//-- wv_payload_len --
assign wv_payload_len = iv_packet_in_head[`PAYLOAD_LENGTH_OFFSET];

//-- wv_slot_required --
assign wv_slot_required = (wv_payload_len[5:0] ? (wv_payload_len >> 6) + 1 : (wv_payload_len >> 6)) + 'd1;  //+1 for packet header

//-- wv_qpn --
assign wv_qpn = iv_packet_in_head[`QPN_OFFSET];

//-- wv_rpsn --
assign wv_rpsn = iv_packet_in_head[`PSN_OFFSET];

//-- wv_epsn --
assign wv_epsn = iv_epsn_rd_data;

//-- qv_service_type --
//-- qv_slot_required --
//-- qv_qpn --
//-- qv_rpsn --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_service_type <= 'd0;
        qv_slot_required <= 'd0;
        qv_qpn <= 'd0;
        qv_rpsn <= 'd0;
    end
    else if(ooa_cur_state == OOA_IDLE_s && i_packet_in_valid) begin
        qv_service_type <= wv_service_type;
        qv_slot_required <= wv_slot_required;
        qv_qpn <= wv_qpn;
        qv_rpsn <= wv_rpsn;
    end
    else begin
        qv_service_type <= qv_service_type;
        qv_slot_required <= qv_slot_required;
        qv_qpn <= qv_qpn;
        qv_rpsn <= qv_rpsn;
    end
end

//-- qv_epsn --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_epsn <= 'd0;
    end
    else if(ooa_cur_state == OOA_UNRELIABLE_JUDGE_s && wv_rpsn == wv_epsn) begin
        qv_epsn <= wv_epsn + 'd1;
    end
    else if(ooa_cur_state == OOA_RELIABLE_JUDGE_s) begin
        if(wv_rpsn < wv_epsn) begin
            qv_epsn <= wv_epsn;
        end
        else if(wv_rpsn == wv_epsn) begin
            qv_epsn <= wv_epsn + 'd1;
        end
        else if(wv_rpsn > wv_epsn) begin
            qv_epsn <= wv_epsn;
        end
        else begin
            qv_epsn <= qv_epsn;
        end
    end
    else if(ooa_cur_state == OOA_RELIABLE_COMMIT_s && i_find_resp_valid && iv_find_resp_data[`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG]) begin
        qv_epsn <= qv_find_psn_diff + 'd1;
    end
    else begin
        qv_epsn <= qv_epsn;
    end
end

//-- o_packet_in_ready --
always @(*) begin
    if(rst) begin
        o_packet_in_ready = 'd0;
    end
    else if(ooa_cur_state == OOA_IDLE_s) begin
        o_packet_in_ready = 'd0;
    end
    else if(ooa_cur_state == OOA_UNRELIABLE_COMMIT_s) begin
        o_packet_in_ready = i_commit_ready;
    end
    else if(ooa_cur_state == OOA_UNRELIABLE_DROP_s) begin
        o_packet_in_ready = 'd1;
    end
    else if(ooa_cur_state == OOA_RELIABLE_INSERT_s) begin
        o_packet_in_ready = q_insert_header ? 'd0 : i_insert_req_ready;
    end
    else if(ooa_cur_state == OOA_RELIABLE_DROP_s) begin
        o_packet_in_ready = 'd1;
    end
    else begin
        o_packet_in_ready = 'd0;
    end
end

//-- qv_insert_count --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_insert_count <= 'd0;
    end
    else if(ooa_cur_state == OOA_IDLE_s) begin
        qv_insert_count <= 'd0;
    end
    else if(ooa_cur_state == OOA_RELIABLE_INSERT_s && i_packet_in_valid && i_insert_req_ready) begin
        qv_insert_count <= qv_insert_count + 'd1;
    end
    else begin
        qv_insert_count <= qv_insert_count;
    end
end

//-- o_insert_req_valid --
always @(*) begin
    if(rst) begin
        o_insert_req_valid = 'd0;
    end
    else if(ooa_cur_state == OOA_RELIABLE_INSERT_s) begin
        o_insert_req_valid = i_packet_in_valid;
    end
    else begin
        o_insert_req_valid = 'd0;
    end
end

//-- ov_insert_req_head --
always @(*) begin
    if(rst) begin
        ov_insert_req_head = 'd0;
    end
    else if(ooa_cur_state == OOA_RELIABLE_INSERT_s && i_packet_in_start) begin
        ov_insert_req_head = q_insert_header ? {qv_slot_required, qv_rpsn, qv_qpn} : 'd0;
    end
    else begin
        ov_insert_req_head = 'd0;
    end
end

//-- ov_insert_req_data --
always @(*) begin
    if(rst) begin
        ov_insert_req_data = 'd0;
    end
    else if(ooa_cur_state == OOA_RELIABLE_INSERT_s) begin
        if(q_insert_header) begin
            ov_insert_req_data = {240'd0, qv_rpsn, iv_packet_in_head[247:8], iv_packet_in_head[7:0]};
        end
        else begin
            ov_insert_req_data = iv_packet_in_data;
        end
    end
    else begin
        ov_insert_req_data = 'd0;
    end
end

//-- o_insert_req_start --
always @(*) begin
    if(rst) begin
        o_insert_req_start = 'd0;
    end
    else if(ooa_cur_state == OOA_RELIABLE_INSERT_s && i_packet_in_start) begin
        o_insert_req_start = q_insert_header ? i_packet_in_start : 'd0;
    end
    else begin
        o_insert_req_start = 'd0;
    end
end

//-- o_insert_req_last --
always @(*) begin
    if(rst) begin
        o_insert_req_last = 'd0;
    end
    else if(ooa_cur_state == OOA_RELIABLE_INSERT_s && i_packet_in_last) begin
        o_insert_req_last = q_insert_header ? 'd0 : i_packet_in_last;
    end
    else begin
        o_insert_req_last = 'd0;
    end
end

//-- o_commit_valid --
always @(*) begin
    if(rst) begin
        o_commit_valid = 'd0;
    end
    else if(ooa_cur_state == OOA_UNRELIABLE_COMMIT_s) begin
        o_commit_valid = i_packet_in_valid;
    end
    else begin
        o_commit_valid = 'd0;
    end
end

//-- ov_commit_head --
always @(*) begin
    if(rst) begin
        ov_commit_head = 'd0;
    end
    else if(ooa_cur_state == OOA_UNRELIABLE_COMMIT_s && i_packet_in_start) begin
        ov_commit_head = {'d0, iv_packet_in_head[247:8], iv_packet_in_head[7:0] - 8'd3};     //Remove PSN
    end
    else begin
        ov_commit_head = 'd0;
    end
end

//-- ov_commit_data --
always @(*) begin
    if(rst) begin
        ov_commit_data = 'd0;
    end
    else if(ooa_cur_state == OOA_UNRELIABLE_COMMIT_s) begin
        ov_commit_data = iv_packet_in_data;
    end
    else begin
        ov_commit_data = 'd0;
    end
end

//-- o_commit_start --
always @(*) begin
    if(rst) begin
        o_commit_start = 'd0;
    end
    else if(ooa_cur_state == OOA_UNRELIABLE_COMMIT_s && i_packet_in_start) begin
        o_commit_start = 'd1;
    end
    else begin
        o_commit_start = 'd0;
    end
end

//-- o_commit_last --
always @(*) begin
    if(rst) begin
        o_commit_last = 'd0;
    end
    else if(ooa_cur_state == OOA_UNRELIABLE_COMMIT_s && i_packet_in_last) begin
        o_commit_last = 'd1;
    end
    else begin
        o_commit_last = 'd0;
    end
end

//-- q_sack_valid --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_sack_valid <= 'd0;
    end
    else if(ooa_cur_state == OOA_IDLE_s) begin
        q_sack_valid <= 'd0;
    end
    else if(ooa_cur_state == OOA_RELIABLE_JUDGE_s) begin    //Only when we receive a OoO packet for the first time do we set this flag
        q_sack_valid <= (wv_rpsn > wv_epsn) && i_find_resp_valid && !iv_find_resp_data[`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG];
    end
    else begin
        q_sack_valid <= q_sack_valid;
    end
end

//-- q_loss_detected --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_loss_detected <= 'd0;
    end
    else if(ooa_cur_state == OOA_IDLE_s) begin
        q_loss_detected <= 'd0;
    end
    else if(ooa_cur_state == OOA_RELIABLE_LOCATE_LOSS_s) begin
        if(i_find_resp_valid && !iv_find_resp_data[`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG]) begin     //Detect PSN hole
            q_loss_detected <= 'd1;
        end
        else begin
            q_loss_detected <= q_loss_detected;
        end
    end
    else begin
        q_loss_detected <= 'd0;
    end
end

//-- o_ack_out_valid --
//-- ov_ack_out_head --
//-- ov_ack_out_data --
//-- o_ack_out_start --
//-- o_ack_out_last --
always @(*) begin
    if(rst) begin
        o_ack_out_valid = 'd0;
        ov_ack_out_head = 'd0;
        ov_ack_out_data = 'd0;
        o_ack_out_start = 'd0;
        o_ack_out_last = 'd0;
    end
    else if(ooa_cur_state == OOA_RELIABLE_ACK_s) begin
        o_ack_out_valid = 'd1;
        ov_ack_out_head = {qv_dstMAC, qv_srcMAC, qv_dstIP, qv_srcIP, qv_dstQPN, 8'd0, qv_srcQPN, {`ACKNOWLEDGE, `RC}, 16'h000d, 8'h1f};
        ov_ack_out_data = {qv_epsn, qv_rpsn, qv_retrans_lower_bound, qv_retrans_upper_bound, {6'd0, q_sack_valid, q_loss_detected}};     //EPSN, SACKed PSN, retrans lower bound, retrans upper bound, loss indicator
        o_ack_out_start = 'd1;
        o_ack_out_last = 'd1;        
    end
    else begin
        o_ack_out_valid = 'd0;
        ov_ack_out_head = 'd0;
        ov_ack_out_data = 'd0;
        o_ack_out_start = 'd0;
        o_ack_out_last = 'd0;       
    end
end

//-- o_pkt_meta_wr_en --
//-- ov_pkt_meta_din --
always @(*) begin
    if(rst) begin
        o_pkt_meta_wr_en = 'd0;
        ov_pkt_meta_din = 'd0;
    end
    else if(ooa_cur_state == OOA_RELIABLE_COMMIT_s && i_find_resp_valid && !iv_find_resp_data[`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG] && !i_pkt_meta_prog_full) begin
        o_pkt_meta_wr_en = 'd1;  //Only when the expected packet comes do we commit
        ov_pkt_meta_din = {(qv_find_psn_diff - 24'd1), qv_rpsn, qv_qpn};
    end
    else begin
        o_pkt_meta_wr_en = 'd0;
        ov_pkt_meta_din = 'd0;
    end
end

//-- ov_epsn_rd_index --
always @(*) begin
    if(rst) begin
        ov_epsn_rd_index = 'd0;
    end
    else if(ooa_cur_state == OOA_IDLE_s && i_packet_in_valid) begin
        ov_epsn_rd_index = wv_qpn;
    end
    else if(ooa_cur_state != OOA_IDLE_s) begin
        ov_epsn_rd_index = qv_qpn;
    end
    else begin
        ov_epsn_rd_index = 'd0;
    end
end

//-- o_epsn_wr_en --
//-- ov_epsn_wr_index --
//-- ov_epsn_wr_data --
always @(*) begin
    if(rst) begin
        o_epsn_wr_en = 'd0;
        ov_epsn_wr_index = 'd0;
        ov_epsn_wr_data = 'd0;
    end
    else if(ooa_cur_state == OOA_UNRELIABLE_COMMIT_s && i_packet_in_valid && i_packet_in_start) begin
        o_epsn_wr_en = 'd1;
        ov_epsn_wr_index = qv_qpn;
        ov_epsn_wr_data = qv_epsn;        
    end
    else if(ooa_cur_state == OOA_RELIABLE_INSERT_s && ooa_next_state == OOA_RELIABLE_COMMIT_s) begin
        o_epsn_wr_en = 'd1;
        ov_epsn_wr_index = qv_qpn;
        ov_epsn_wr_data = qv_epsn;
    end
    else if(ooa_cur_state == OOA_RELIABLE_COMMIT_s && i_find_resp_valid && iv_find_resp_data[`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG]) begin
        o_epsn_wr_en = 'd1;
        ov_epsn_wr_index = qv_qpn;
        ov_epsn_wr_data = qv_find_psn_diff + 'd1;
    end
    else begin
        o_epsn_wr_en = 'd0;
        ov_epsn_wr_index = 'd0;
        ov_epsn_wr_data = 'd0;
    end
end


//-- qv_find_psn_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_find_psn_diff <= 'd0;
    end
    else if(i_pkt_meta_prog_full) begin         //Corner case for Commit
        qv_find_psn_diff <= qv_find_psn_diff;
    end
    else begin
        qv_find_psn_diff <= qv_find_psn;
    end
end

//-- qv_find_psn --
always @(*) begin
    if(rst) begin
        qv_find_psn = 'd0;
    end
    else if(ooa_cur_state == OOA_RELIABLE_JUDGE_s && ooa_next_state == OOA_RELIABLE_LOCATE_LOSS_s) begin
        qv_find_psn = qv_rpsn - 'd1;
    end
    else if(ooa_cur_state == OOA_RELIABLE_INSERT_s && o_insert_req_last && i_insert_req_ready && q_locate_loss) begin
        qv_find_psn = qv_rpsn - 'd1;
    end
    else if(ooa_cur_state == OOA_RELIABLE_LOCATE_LOSS_s && i_find_resp_valid && !iv_find_resp_data[`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG]) begin
        qv_find_psn = qv_find_psn_diff - 'd1;
    end
    else if(ooa_cur_state == OOA_RELIABLE_INSERT_s && ooa_next_state == OOA_RELIABLE_COMMIT_s) begin
        qv_find_psn = qv_epsn;
    end
    else if(ooa_cur_state == OOA_RELIABLE_COMMIT_s && i_find_resp_valid && iv_find_resp_data[`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG]) begin
        qv_find_psn = qv_find_psn_diff + 'd1;
    end
    else begin
        qv_find_psn = qv_find_psn_diff;
    end
end

//-- o_find_req_valid --
always @(*) begin
    if(rst) begin
        o_find_req_valid = 'd0;
    end
    else if(ooa_cur_state == OOA_IDLE_s && i_packet_in_valid && (wv_service_type == `RC)) begin
        o_find_req_valid = 'd1;
    end
    else if(ooa_cur_state == OOA_RELIABLE_JUDGE_s && ooa_next_state == OOA_RELIABLE_LOCATE_LOSS_s) begin
        o_find_req_valid = 'd1;
    end
    else if(ooa_cur_state == OOA_RELIABLE_INSERT_s && o_insert_req_last && i_insert_req_ready && q_locate_loss) begin
        o_find_req_valid = 'd1;
    end
    else if(ooa_cur_state == OOA_RELIABLE_LOCATE_LOSS_s && i_find_resp_valid && !iv_find_resp_data[`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG]) begin
        o_find_req_valid = 'd1;
    end
    else if(ooa_cur_state == OOA_RELIABLE_INSERT_s && ooa_next_state == OOA_RELIABLE_COMMIT_s) begin
        o_find_req_valid = 'd1;
    end
    else if(ooa_cur_state == OOA_RELIABLE_COMMIT_s && i_find_resp_valid && iv_find_resp_data[`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG]) begin
        o_find_req_valid = 'd1;
    end
    else begin
        o_find_req_valid = 'd0;
    end
end

//-- ov_find_req_head --
always @(*) begin
    if(rst) begin
        ov_find_req_head = 'd0;
    end
    else if(ooa_cur_state == OOA_IDLE_s && i_packet_in_valid && (wv_service_type == `RC)) begin
        ov_find_req_head = {wv_rpsn, wv_qpn};
    end
    else if(ooa_cur_state == OOA_IDLE_s && i_packet_in_valid && (wv_service_type == `RC)) begin
        ov_find_req_head = {qv_qpn, qv_find_psn};
    end
    else if(ooa_cur_state == OOA_RELIABLE_JUDGE_s && ooa_next_state == OOA_RELIABLE_LOCATE_LOSS_s) begin
        ov_find_req_head = {qv_qpn, qv_find_psn};
    end
    else if(ooa_cur_state == OOA_RELIABLE_INSERT_s && o_insert_req_last && i_insert_req_ready && q_locate_loss) begin
        ov_find_req_head = {qv_qpn, qv_find_psn};
    end
    else if(ooa_cur_state == OOA_RELIABLE_LOCATE_LOSS_s && i_find_resp_valid && !iv_find_resp_data[`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG]) begin
        ov_find_req_head = {qv_qpn, qv_find_psn};
    end
    else if(ooa_cur_state == OOA_RELIABLE_INSERT_s && ooa_next_state == OOA_RELIABLE_COMMIT_s) begin
        ov_find_req_head = {qv_qpn, qv_find_psn};
    end
    else if(ooa_cur_state == OOA_RELIABLE_COMMIT_s && i_find_resp_valid && iv_find_resp_data[`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG]) begin
        ov_find_req_head = {qv_qpn, qv_find_psn};
    end
    else begin
        o_find_req_valid = 'd0;
    end
end

//-- q_already_buffered --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_already_buffered <= 'd0;
    end
    else if(ooa_cur_state == OOA_IDLE_s) begin
        q_already_buffered <= q_already_buffered;
    end
    else if(ooa_cur_state == OOA_RELIABLE_JUDGE_s && wv_rpsn > wv_epsn + 1) begin
        q_already_buffered <= i_find_resp_valid && iv_find_resp_data[`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG];
    end
    else begin
        q_already_buffered <= q_already_buffered;
    end
end

//-- qv_retrans_lower_bound --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_retrans_lower_bound <= 'd0;
    end
    else if(ooa_cur_state == OOA_IDLE_s) begin
        qv_retrans_lower_bound <= 'd0;
    end
    else if(ooa_cur_state == OOA_RELIABLE_LOCATE_LOSS_s && i_find_resp_valid && !iv_find_resp_data[`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG]) begin
        qv_retrans_lower_bound <= qv_find_psn_diff;    //Last PSN hole
    end
    else begin
        qv_retrans_lower_bound <= qv_retrans_lower_bound;
    end
end

reg             [31:0]          qv_loss_count;
//-- qv_loss_count --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_loss_count <= 'd0;
    end
    else if(ooa_cur_state == OOA_IDLE_s) begin
        qv_loss_count <= 'd0;
    end
    else if(ooa_cur_state == OOA_RELIABLE_LOCATE_LOSS_s && i_find_resp_valid && !iv_find_resp_data[`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG]) begin
        qv_loss_count <= qv_loss_count + 'd1;
    end
    else begin
        qv_loss_count <= qv_loss_count;
    end
end

//-- qv_retrans_upper_bound --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_retrans_upper_bound <= 'd0;
    end
    else if(ooa_cur_state == OOA_IDLE_s) begin
        qv_retrans_upper_bound <= 'd0;
    end
    else if(ooa_cur_state == OOA_RELIABLE_JUDGE_s && (wv_rpsn == wv_epsn + 1)) begin
        qv_retrans_upper_bound <= qv_epsn;
    end
    else if(ooa_cur_state == OOA_RELIABLE_LOCATE_LOSS_s && i_find_resp_valid && !iv_find_resp_data[`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG] && qv_loss_count == 0) begin
        qv_retrans_upper_bound <= qv_find_psn_diff;
    end
    else begin
        qv_retrans_upper_bound <= qv_retrans_upper_bound;
    end
end

//-- q_insert_header --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_insert_header <= 'd0;
    end
    else if(ooa_cur_state == OOA_IDLE_s && i_packet_in_valid && (wv_service_type == `RC) && (wv_slot_required <= iv_available_slot_num)) begin
        q_insert_header <= 'd1;
    end
    else if(ooa_cur_state == OOA_RELIABLE_INSERT_s && q_insert_header && i_insert_req_ready) begin
        q_insert_header <= 'd0;
    end
    else begin
        q_insert_header <= q_insert_header;
    end
end

/*------------------------------------------- Variables Decode : End ------------------------------------------------*/
endmodule