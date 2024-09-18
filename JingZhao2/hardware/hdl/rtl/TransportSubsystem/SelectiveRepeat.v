/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       SelectiveRepeat
Author:     YangFan
Function:   Deal with retransmission event. Triggered by two events:
            1. ACK : Release and Retransmit packet. Little penalty on performance.
            2. Timeout : Retransmit packet if timer expires. Huge penalty on performance.
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
module SelectiveRepeat #(
    parameter       SLOT_WIDTH = 512,
    parameter       SLOT_NUM = 512,
    parameter       SLOT_NUM_LOG = log2b(SLOT_NUM - 1)
)(
    input   wire                                                            clk,
    input   wire                                                            rst,

    //ACK in
    input   wire                                                            i_ack_in_valid,
    input   wire        [`PKT_HEAD_WIDTH - 1 : 0]                           iv_ack_in_head,
    input   wire        [`PKT_DATA_WIDTH - 1 : 0]                           iv_ack_in_data,
    input   wire                                                            i_ack_in_start,
    input   wire                                                            i_ack_in_last,
    output  wire                                                            o_ack_in_ready,

    //Timer event in
    //Timer event format : {QPN}
    input   wire                                                            i_timer_event_empty,
    input   wire        [`TIMER_EVENT_WIDTH - 1 : 0]                        iv_timer_event_dout,
    output  wire                                                            o_timer_event_rd_en,

    //Timer set out
    //Timer set format : {ACTION , QPN}
    input   wire                                                            i_timer_set_prog_full,
    output  reg                                                             o_timer_set_wr_en,
    output  reg                                                             ov_timer_set_din,

    //Interface with PacketBufferMgt
    output  reg                                                             o_delete_req_valid,
    output  reg         [`QP_NUM_LOG + `PSN_WIDTH + SLOT_NUM - 1 : 0]       ov_delete_req_head,
    input   wire                                                            i_delete_req_ready, 

    input   wire                                                            i_delete_resp_valid,
    input   wire        [`PKT_HEAD_WIDTH - 1 : 0]                           iv_delete_resp_head,
    input   wire        [`PKT_DATA_WIDTH - 1 : 0]                           iv_delete_resp_data,
    input   wire                                                            i_delete_resp_start,
    input   wire                                                            i_delete_resp_last,
    output  wire                                                            o_delete_resp_ready,

    output  reg                                                             o_get_req_valid,
    output  reg         [`QP_NUM_LOG + `PSN_WIDTH + SLOT_NUM - 1 : 0]       ov_get_req_head,
    input   wire                                                            i_get_req_ready,

    input   wire                                                            i_get_resp_valid,
    input   wire        [`PKT_HEAD_WIDTH - 1 : 0]                           iv_get_resp_head,
    input   wire        [`PKT_DATA_WIDTH - 1 : 0]                           iv_get_resp_data,
    input   wire                                                            i_get_resp_start,
    input   wire                                                            i_get_resp_last,
    output  reg                                                             o_get_resp_ready,

    //Retransmitted packet out
    output  reg                                                             o_packet_out_valid,
    output  reg        [`PKT_HEAD_WIDTH - 1 : 0]                            ov_packet_out_head,
    output  reg        [`PKT_DATA_WIDTH - 1 : 0]                            ov_packet_out_data,
    output  reg                                                             o_packet_out_start,
    output  reg                                                             o_packet_out_last,
    input   wire                                                            i_packet_out_ready,

//UPSN control
    output  reg         [`QP_NUM_LOG - 1 : 0]                               ov_upsn_rd_index,
    input   wire        [`PSN_WIDTH - 1 : 0]                                iv_upsn_rd_data,
    output  reg                                                             o_upsn_wr_en,
    output  reg         [`QP_NUM_LOG - 1 : 0]                               ov_upsn_wr_index,
    output  reg         [`PSN_WIDTH - 1 : 0]                                ov_upsn_wr_data
);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/
wire                    [23:0]          wv_qpn;
reg                     [23:0]          qv_qpn;

wire                    [23:0]          wv_upsn;
reg                     [23:0]          qv_upsn;

wire                    [23:0]          wv_epsn;
reg                     [23:0]          qv_epsn;

wire                    [23:0]          wv_spsn;
reg                     [23:0]          qv_spsn;

wire                    [23:0]          wv_tpsn;
reg                     [23:0]          qv_tpsn;

wire                                    w_sack_valid;
reg                                     q_sack_valid;

wire                                    w_loss_detected;
reg                                     q_loss_detected;

reg                     [23:0]          qv_curPSN;

wire                    [23:0]          wv_lower_bound_indicator;
wire                    [23:0]          wv_upper_bound_indicator;

reg                    [23:0]           qv_lower_bound_indicator;
reg                    [23:0]           qv_upper_bound_indicator;

reg                     [23:0]          qv_release_upper_bound;
reg                     [23:0]          qv_repeat_upper_bound;

reg                                     q_get_req_start;
reg                                     q_delete_req_start;

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/


/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
//NULL
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg             [2:0]               sr_cur_state;
reg             [2:0]               sr_next_state;

parameter       [2:0]               SR_IDLE_s               = 4'd1,
                                    SR_JUDGE_s              = 4'd2,
                                    SR_CUMULATIVE_RELEASE_s = 4'd3,
                                    SR_SELECTIVE_RELEASE_s  = 4'd4,
                                    SR_SELECTIVE_REPEAT_s   = 4'd5,
                                    SR_ERROR_s              = 4'd6;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        sr_cur_state <= SR_IDLE_s;
    end
    else begin
        sr_cur_state <= sr_next_state;
    end
end

always @(*) begin
    case(sr_cur_state)
        SR_IDLE_s:                  if(i_ack_in_valid) begin
                                        sr_next_state = SR_JUDGE_s;
                                    end
                                    else if(!i_timer_event_empty) begin
                                        sr_next_state = SR_SELECTIVE_REPEAT_s;
                                    end
                                    else begin
                                        sr_next_state = SR_IDLE_s;
                                    end
        SR_JUDGE_s:                 if(wv_upsn == qv_epsn) begin
                                        if(q_sack_valid) begin
                                            sr_next_state = SR_SELECTIVE_RELEASE_s;
                                        end
                                        else begin
                                            sr_next_state = SR_SELECTIVE_REPEAT_s;
                                        end
                                    end
                                    else if(wv_upsn < qv_epsn) begin
                                        sr_next_state = SR_CUMULATIVE_RELEASE_s;
                                    end
                                    else begin  //UPSN cannot exceed EPSN
                                        sr_next_state = SR_ERROR_s;
                                    end
        SR_CUMULATIVE_RELEASE_s:    if(qv_curPSN == qv_release_upper_bound && i_delete_resp_last) begin
                                        if(q_sack_valid) begin
                                            sr_next_state = SR_SELECTIVE_RELEASE_s;
                                        end
                                        else if(q_loss_detected) begin
                                            sr_next_state = SR_SELECTIVE_REPEAT_s;
                                        end
                                        else begin
                                            sr_next_state = SR_IDLE_s;
                                        end
                                    end
                                    else begin
                                        sr_next_state = SR_CUMULATIVE_RELEASE_s;
                                    end
        SR_SELECTIVE_RELEASE_s:     if(i_delete_resp_last) begin
                                        if(q_loss_detected) begin
                                            sr_next_state = SR_SELECTIVE_REPEAT_s;
                                        end
                                        else begin
                                            sr_next_state = SR_IDLE_s;
                                        end
                                    end
                                    else begin
                                        sr_next_state = SR_SELECTIVE_RELEASE_s;
                                    end
        SR_SELECTIVE_REPEAT_s:      if((qv_curPSN == qv_repeat_upper_bound) && i_get_resp_valid && i_get_resp_last && i_packet_out_ready) begin
                                        sr_next_state = SR_IDLE_s;
                                    end
                                    else begin
                                        sr_next_state = SR_SELECTIVE_REPEAT_s;
                                    end
        default:                    sr_next_state = SR_IDLE_s;
    endcase
end

/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- wv_qpn --
assign wv_qpn = i_ack_in_valid ? iv_ack_in_head[`QPN_OFFSET] : iv_timer_event_dout[`TIMER_QPN_OFFSET];

//-- wv_upsn --
assign wv_upsn = iv_upsn_rd_data;

//-- wv_epsn --
assign wv_epsn = iv_ack_in_data[`EPSN_OFFSET];

//-- wv_spsn --
assign wv_spsn = iv_ack_in_data[`SPSN_OFFSET];

//-- wv_tpsn --
assign wv_tpsn = iv_timer_event_dout[`TPSN_OFFSET];

//-- w_sack_valid --
assign w_sack_valid = iv_ack_in_data[`SACK_OFFSET];

//-- w_loss_detected --
assign w_loss_detected = iv_ack_in_data[`LOSS_OFFSET];

//-- wv_lower_bound_indicator --
assign wv_lower_bound_indicator = iv_ack_in_data[`LOWER_BOUND_OFFSET];

//-- wv_upper_bound_indicator --
assign wv_upper_bound_indicator = iv_ack_in_data[`UPPER_BOUND_OFFSET];

//-- qv_qpn --
//-- qv_spsn --
//-- qv_upsn --
//-- qv_epsn --
//-- q_sack_valid --
//-- q_loss_detected --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_qpn <= 'd0;
        qv_spsn <= 'd0;
        qv_upsn  <= 'd0;
        qv_epsn <= 'd0;
        qv_tpsn <= 'd0;
        qv_lower_bound_indicator <= 'd0;
        qv_upper_bound_indicator <= 'd0;
        q_sack_valid <= 'd0;
        q_loss_detected  <= 'd0;
    end
    else if(sr_cur_state == SR_IDLE_s && !i_ack_in_valid) begin
        qv_qpn <= 'd0;
        qv_spsn <= 'd0;
        qv_upsn  <= 'd0;
        qv_epsn <= 'd0;
        qv_tpsn <= 'd0;
        qv_lower_bound_indicator <= 'd0;
        qv_upper_bound_indicator <= 'd0;
        q_sack_valid <= 'd0;
        q_loss_detected  <= 'd0;
    end
    else if(sr_cur_state == SR_IDLE_s && i_ack_in_valid) begin
        qv_qpn <= wv_qpn;
        qv_spsn <= wv_spsn;
        qv_upsn  <= wv_upsn;
        qv_epsn <= wv_epsn;
        qv_tpsn <= wv_tpsn;
        qv_lower_bound_indicator <= wv_lower_bound_indicator;
        qv_upper_bound_indicator <= wv_upper_bound_indicator;
        q_sack_valid <= w_sack_valid;
        q_loss_detected  <= w_loss_detected;
    end
    else begin
        qv_qpn <= qv_qpn;
        qv_spsn <= qv_spsn;
        qv_upsn  <= qv_upsn;
        qv_epsn <= qv_epsn;
        qv_tpsn <= qv_tpsn;
        qv_lower_bound_indicator <= qv_lower_bound_indicator;
        qv_upper_bound_indicator <= qv_upper_bound_indicator;
        q_sack_valid <= q_sack_valid;
        q_loss_detected  <= q_loss_detected;
    end
end 

//-- qv_curPSN --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_curPSN <= 'd0;
    end
    else if(sr_cur_state == SR_IDLE_s) begin
        if(i_ack_in_valid) begin
            qv_curPSN <= 'd0;    
        end
        else if(!i_timer_event_empty) begin
            qv_curPSN <= wv_tpsn; 
        end
        else begin
            qv_curPSN <= qv_curPSN;
        end
    end
    else if(sr_cur_state == SR_JUDGE_s) begin
        if(wv_upsn == qv_epsn) begin
            if(q_sack_valid) begin
                qv_curPSN <= qv_spsn;
            end
            else begin
                qv_curPSN <= qv_lower_bound_indicator;
            end
        end
        else if(wv_upsn < qv_epsn) begin
            qv_curPSN = wv_upsn;
        end
        else begin  //UPSN cannot exceed EPSN
            qv_curPSN = `INVALID_PSN;
        end        
    end
    else if(sr_cur_state == SR_CUMULATIVE_RELEASE_s) begin
        if(qv_curPSN < qv_release_upper_bound) begin
            qv_curPSN <= i_delete_resp_last ? qv_curPSN + 'd1 : qv_curPSN;
        end
        else begin  //qv_curPSN == qv_release_upper_bound
            qv_curPSN <= !i_delete_resp_last ? qv_curPSN :
                            q_sack_valid ? qv_spsn :
                            q_loss_detected ? qv_lower_bound_indicator : 'd0;
        end
    end
    else if(sr_cur_state == SR_SELECTIVE_RELEASE_s) begin
        qv_curPSN <= (sr_next_state == SR_SELECTIVE_REPEAT_s) ? qv_lower_bound_indicator : qv_curPSN;
    end
    else if(sr_cur_state == SR_SELECTIVE_REPEAT_s) begin
        if(qv_curPSN < qv_repeat_upper_bound) begin
            qv_curPSN <= i_get_req_ready ? qv_curPSN + 'd1 : qv_curPSN;
        end
        else begin //qv_curPSN == qv_repeat_upper_bound
            qv_curPSN <= i_get_req_ready ? 'd0 : qv_curPSN;
        end
    end
    else begin
        qv_curPSN <= qv_curPSN;
    end
end 

//-- qv_release_upper_bound --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_release_upper_bound <= 'd0;
    end
    else if(sr_cur_state == SR_IDLE_s) begin
        qv_release_upper_bound <= 'd0;
    end
    else if(sr_cur_state == SR_JUDGE_s) begin
        if(wv_upsn == qv_epsn) begin
            if(q_sack_valid) begin
                qv_release_upper_bound <= qv_spsn;
            end
            else begin
                qv_release_upper_bound <= 'd0;
            end
        end
        else if(wv_upsn < qv_epsn) begin
            qv_release_upper_bound <= qv_epsn - 'd1;
        end
        else begin  //UPSN cannot exceed EPSN
            qv_release_upper_bound <= 'd0;
        end
    end
    else if(sr_cur_state == SR_CUMULATIVE_RELEASE_s) begin
        if(qv_curPSN == qv_release_upper_bound && i_delete_resp_last) begin
            if(q_sack_valid) begin
                qv_release_upper_bound <= qv_spsn;
            end
            else if(q_loss_detected) begin
                qv_release_upper_bound <= 'd0;
            end
            else begin
                qv_release_upper_bound <= 'd0;
            end
        end
        else begin
            qv_release_upper_bound <= qv_release_upper_bound;
        end
    end
    else begin
        qv_release_upper_bound <= qv_release_upper_bound;
    end
end

//-- qv_repeat_upper_bound --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_repeat_upper_bound <= 'd0;
    end
    else if(sr_cur_state == SR_IDLE_s) begin
        if(i_ack_in_valid) begin
            qv_repeat_upper_bound <= 'd0;
        end
        else if(!i_timer_event_empty) begin
            qv_repeat_upper_bound <= wv_tpsn;
        end
        else begin
            qv_repeat_upper_bound <= 'd0;
        end
    end
    else if(sr_cur_state == SR_JUDGE_s) begin
        qv_repeat_upper_bound <= qv_upper_bound_indicator;
    end
    else begin
        qv_repeat_upper_bound <= 'd0;
    end
end

//-- o_ack_in_ready -- //Always ready, ack lost is negligible
assign o_ack_in_ready = (sr_cur_state != SR_IDLE_s) && (sr_next_state == SR_IDLE_s);

//-- o_timer_event_rd_en -- //Always read, timer event lost is negligible
assign o_timer_event_rd_en = 'd1;

//-- o_delete_req_valid --
//-- ov_delete_req_head --
always @(*) begin
    if(rst) begin
        o_delete_req_valid = 'd0;
        ov_delete_req_head = 'd0;
    end
    else if(sr_cur_state == SR_CUMULATIVE_RELEASE_s || sr_cur_state == SR_SELECTIVE_RELEASE_s) begin
        o_delete_req_valid = q_delete_req_start ? 'd1 : 'd0;
        ov_delete_req_head = {qv_curPSN, qv_qpn};
    end
    else begin
        o_delete_req_valid = 'd0;
        ov_delete_req_head = 'd0;
    end
end

//-- q_delete_req_start --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_delete_req_start <= 'd0;
    end
    else if(sr_cur_state == SR_IDLE_s) begin
        q_delete_req_start <= 'd0;
    end
    else if(sr_cur_state == SR_JUDGE_s && (sr_next_state == SR_SELECTIVE_RELEASE_s || sr_next_state == SR_CUMULATIVE_RELEASE_s)) begin
        q_delete_req_start <= 'd1;
    end
    else if(sr_cur_state == SR_SELECTIVE_RELEASE_s || sr_cur_state == SR_CUMULATIVE_RELEASE_s) begin
        if(q_delete_req_start) begin
            q_delete_req_start <= 'd0;
        end
        else if(i_delete_resp_valid && i_delete_resp_last) begin
            q_delete_req_start <= 'd1;
        end
        else begin
            q_delete_req_start <= q_delete_req_start;
        end
    end
    else begin
        q_delete_req_start <= q_delete_req_start;
    end
end

//-- o_delete_resp_ready -- //Always ready since we don't need to transfer deleted packet
assign o_delete_resp_ready = 'd1;

//-- q_get_req_start --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_get_req_start <= 'd0;
    end
    else if(sr_cur_state != SR_SELECTIVE_REPEAT_s && sr_next_state == SR_SELECTIVE_REPEAT_s) begin
        q_get_req_start <= 'd1;
    end
    else if(sr_cur_state == SR_SELECTIVE_REPEAT_s) begin
        if(i_get_req_ready) begin
            q_get_req_start <= 'd0;
        end
        else if(i_get_resp_valid && i_get_resp_last && i_packet_out_ready) begin
            q_get_req_start <= 'd1;
        end
        else begin
            q_get_req_start <= q_get_req_start;
        end
    end
    else begin
        q_get_req_start <= q_get_req_start;
    end
end

//-- o_get_req_valid --
//-- ov_get_req_head --
always @(*) begin
    if(rst) begin
        o_get_req_valid = 'd0;
        ov_get_req_head = 'd0;
    end
    else if(sr_cur_state == SR_SELECTIVE_REPEAT_s) begin
        o_get_req_valid = q_get_req_start ? 'd1 : 'd0;
        ov_get_req_head = {qv_curPSN, qv_qpn};      
    end
    else begin
        o_get_req_valid = 'd0;
        ov_get_req_head = 'd0;
    end
end

//-- o_get_resp_ready --
always @(*) begin
    if(rst) begin
        o_get_resp_ready = 'd0;
    end
    else if(sr_cur_state == SR_SELECTIVE_REPEAT_s && i_packet_out_ready) begin
        o_get_resp_ready = 'd1;
    end
    else begin
        o_get_resp_ready = 'd0;
    end
end

//-- o_packet_out_valid --
//-- ov_packet_out_head --
//-- ov_packet_out_data --
//-- o_packet_out_start --
//-- o_packet_out_last --
always @(*) begin
    if(rst) begin
        o_packet_out_valid = 'd0;
        ov_packet_out_head = 'd0;
        ov_packet_out_data = 'd0;
        o_packet_out_start = 'd0;
        o_packet_out_last = 'd0;
    end
    else if(sr_cur_state == SR_SELECTIVE_REPEAT_s) begin
        o_packet_out_valid = i_get_resp_valid;
        ov_packet_out_head = iv_get_resp_head;
        ov_packet_out_data = iv_get_resp_data;
        o_packet_out_start = i_get_resp_start;
        o_packet_out_last = i_get_resp_last;      
    end
    else begin
        o_packet_out_valid = 'd0;
        ov_packet_out_head = 'd0;
        ov_packet_out_data = 'd0;
        o_packet_out_start = 'd0;
        o_packet_out_last = 'd0;
    end
end

//-- ov_upsn_rd_index --
assign ov_upsn_rd_index = (sr_cur_state == SR_IDLE_s) ? wv_qpn : qv_qpn;

//-- o_upsn_wr_en --
//-- ov_upsn_wr_index --
//-- ov_upsn_wr_data --
always @(*) begin
    if(rst) begin
        o_upsn_wr_en = 'd0;
        ov_upsn_wr_index = 'd0;
        ov_upsn_wr_data = 'd0;
    end
    else if(sr_cur_state == SR_CUMULATIVE_RELEASE_s) begin
        o_upsn_wr_en = 'd1;
        ov_upsn_wr_index = qv_qpn;
        ov_upsn_wr_data = qv_curPSN + 'd1;        
    end
    else begin
        o_upsn_wr_en = 'd0;
        ov_upsn_wr_index = 'd0;
        ov_upsn_wr_data = 'd0;
    end
end

//-- o_timer_set_wr_en --
//-- ov_timer_set_din --
always @(*) begin
    if(rst) begin
        o_timer_set_wr_en = 'd0;
        ov_timer_set_din = 'd0;
    end
    else begin
        o_timer_set_wr_en = 'd0;
        ov_timer_set_din = 'd0;
    end
end

/*------------------------------------------- Variables Decode : End ------------------------------------------------*/
endmodule