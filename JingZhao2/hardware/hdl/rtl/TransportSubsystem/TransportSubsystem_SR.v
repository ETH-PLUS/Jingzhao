/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       SendControl
Author:     YangFan
Function:   Wrapper for InOrderInject, SelectiveRepeat, and PacketBufferMgt.
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
module TransportSubsystem(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Upper Layer Protocol Interface
    input   wire                                                            i_inject_from_ulp_valid,
    input   wire        [`PKT_HEAD_WIDTH - 1 : 0]                           iv_inject_from_ulp_head,
    input   wire        [`PKT_DATA_WIDTH - 1 : 0]                           iv_inject_from_ulp_data,
    input   wire                                                            i_inject_from_ulp_start,
    input   wire                                                            i_inject_from_ulp_last,
    output  reg                                                             o_inject_from_ulp_ready,

    output  wire                                                            o_commit_to_ulp_valid,
    output  wire        [`PKT_HEAD_WIDTH - 1 : 0]                           ov_commit_to_ulp_head,
    output  wire        [`PKT_DATA_WIDTH - 1 : 0]                           ov_commit_to_ulp_data,
    output  wire                                                            o_commit_to_ulp_start,
    output  wire                                                            o_commit_to_ulp_last,
    input   wire                                                            i_commit_to_ulp_ready,

//Lower Layer Protocol Interface
    output  reg                                                             o_send_to_llp_valid,
    output  reg         [`PKT_HEAD_WIDTH - 1 : 0]                           ov_send_to_llp_head,
    output  reg         [`PKT_DATA_WIDTH - 1 : 0]                           ov_send_to_llp_data,
    output  reg                                                             o_send_to_llp_start,
    output  reg                                                             o_send_to_llp_last,
    input   wire                                                            i_send_to_llp_ready,

    input   wire                                                            i_recv_from_llp_valid,
    input   wire        [`PKT_HEAD_WIDTH - 1 : 0]                           iv_recv_from_llp_head,
    input   wire        [`PKT_DATA_WIDTH - 1 : 0]                           iv_recv_from_llp_data,
    input   wire                                                            i_recv_from_llp_start,
    input   wire                                                            i_recv_from_llp_last,
    output  wire                                                            o_recv_from_llp_ready,

//PSN Control
    output  reg                                                             o_npsn_wr_en,
    output  reg         [`QP_NUM_LOG - 1 : 0]                               ov_npsn_wr_index,
    output  reg         [`PSN_WIDTH - 1 : 0]                                ov_npsn_wr_data,
    output  wire        [`QP_NUM_LOG - 1 : 0]                               ov_npsn_rd_index,
    input   wire        [`PSN_WIDTH - 1 : 0]                                iv_npsn_rd_data,

    output  reg         [`QP_NUM_LOG - 1 : 0]                               ov_upsn_rd_index,
    input   wire        [`PSN_WIDTH - 1 : 0]                                iv_upsn_rd_data,
    output  reg                                                             o_upsn_wr_en,
    output  reg         [`QP_NUM_LOG - 1 : 0]                               ov_upsn_wr_index,
    output  reg         [`PSN_WIDTH - 1 : 0]                                ov_upsn_wr_data,

    output  wire        [`QP_NUM_LOG - 1 : 0]                               ov_ooa_epsn_rd_index,
    input   wire        [`PSN_WIDTH - 1 : 0]                                iv_ooa_epsn_rd_data,
    output  wire                                                            o_ooa_epsn_wr_en,
    output  wire        [`QP_NUM_LOG - 1 : 0]                               ov_ooa_epsn_wr_index,
    output  wire        [`PSN_WIDTH - 1 : 0]                                ov_ooa_epsn_wr_data,

    output  reg         [`QP_NUM_LOG - 1 : 0]                               ov_ioc_epsn_rd_index,
    input   wire        [`PSN_WIDTH - 1 : 0]                                iv_ioc_epsn_rd_data,
    output  reg                                                             o_ioc_epsn_wr_en,
    output  reg         [`QP_NUM_LOG - 1 : 0]                               ov_ioc_epsn_wr_index,
    output  reg         [`PSN_WIDTH - 1 : 0]                                ov_ioc_epsn_wr_data
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                                           w_ack_valid;
wire        [`PKT_HEAD_WIDTH - 1 : 0]                          wv_ack_head;
wire        [`PKT_DATA_WIDTH - 1 : 0]                          wv_ack_data;
wire                                                           w_ack_start;
wire                                                           w_ack_last;
wire                                                           w_ack_ready;

wire                                                           w_req_valid;
wire        [`PKT_HEAD_WIDTH - 1 : 0]                          wv_req_head;
wire        [`PKT_DATA_WIDTH - 1 : 0]                          wv_req_data;
wire                                                           w_req_start;
wire                                                           w_req_last;
wire                                                           w_req_ready;

wire                                                           w_send_control_valid;
wire        [`PKT_HEAD_WIDTH - 1 : 0]                          wv_send_control_head;
wire        [`PKT_DATA_WIDTH - 1 : 0]                          wv_send_control_data;
wire                                                           w_send_control_start;
wire                                                           w_send_control_last;
wire                                                           w_send_control_ready;

wire                                                           w_recv_control_valid;
wire        [`PKT_HEAD_WIDTH - 1 : 0]                          wv_recv_control_head;
wire        [`PKT_DATA_WIDTH - 1 : 0]                          wv_recv_control_data;
wire                                                           w_recv_control_start;
wire                                                           w_recv_control_last;
wire                                                           w_recv_control_ready;

/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
SendControl SendControl_Inst(
    .clk(clk),
    .rst(rst),

    .i_packet_in_valid(i_inject_from_ulp_valid),
    .iv_packet_in_head(iv_inject_from_ulp_head),
    .iv_packet_in_data(iv_inject_from_ulp_data),
    .i_packet_in_start(i_inject_from_ulp_start),
    .i_packet_in_last(i_inject_from_ulp_last),
    .o_packet_in_ready(o_inject_from_ulp_ready),

    .o_npsn_wr_en(o_npsn_wr_en),
    .ov_npsn_wr_index(ov_npsn_wr_index),
    .ov_npsn_wr_data(ov_npsn_wr_data),
    .ov_npsn_rd_index(ov_npsn_rd_index),
    .iv_npsn_rd_data(iv_npsn_rd_data),

    .o_packet_out_valid(w_send_control_valid),
    .ov_packet_out_head(wv_send_control_head),
    .ov_packet_out_data(wv_send_control_data),
    .o_packet_out_start(w_send_control_start),
    .o_packet_out_last(w_send_control_last),
    .i_packet_out_ready(w_send_control_ready),

    .i_ack_in_valid(w_ack_valid),
    .iv_ack_in_head(wv_ack_head),
    .iv_ack_in_data(wv_ack_data),
    .i_ack_in_start(w_ack_start),
    .i_ack_in_last(w_ack_last),
    .o_ack_in_ready(w_ack_ready),

    .ov_upsn_rd_index(ov_upsn_rd_index),
    .iv_upsn_rd_data(iv_upsn_rd_data),
    .o_upsn_wr_en(o_upsn_wr_en),
    .ov_upsn_wr_index(ov_upsn_wr_index),
    .ov_upsn_wr_data(ov_upsn_wr_data)
);

RecvControl RecvControl_Inst(
    .clk(clk),
    .rst(rst),

    .i_packet_in_valid(w_req_valid),
    .iv_packet_in_head(wv_req_head),
    .iv_packet_in_data(wv_req_data),
    .i_packet_in_start(w_req_start),
    .i_packet_in_last(w_req_last),
    .o_packet_in_ready(w_req_ready),

    .o_ooa_epsn_wr_en(o_ooa_epsn_wr_en),
    .ov_ooa_epsn_wr_index(ov_ooa_epsn_wr_index),
    .ov_ooa_epsn_wr_data(ov_ooa_epsn_wr_data),
    .ov_ooa_epsn_rd_index(ov_ooa_epsn_rd_index),
    .iv_ooa_epsn_rd_data(iv_ooa_epsn_rd_data),

    .ov_ioc_epsn_rd_index(ov_ioc_epsn_rd_index),
    .iv_ioc_epsn_rd_data(iv_ioc_epsn_rd_data),
    .o_ioc_epsn_wr_en(o_ioc_epsn_wr_en),
    .ov_ioc_epsn_wr_index(ov_ioc_epsn_wr_index),
    .ov_ioc_epsn_wr_data(ov_ioc_epsn_wr_data),

    .o_commit_valid(o_commit_to_ulp_valid),
    .ov_commit_head(ov_commit_to_ulp_head),
    .ov_commit_data(ov_commit_to_ulp_data),
    .o_commit_start(o_commit_to_ulp_start),
    .o_commit_last(o_commit_to_ulp_last),
    .i_commit_ready(i_commit_to_ulp_ready),

    .o_packet_out_valid(w_recv_control_valid),
    .ov_packet_out_head(wv_recv_control_head),
    .ov_packet_out_data(wv_recv_control_data),
    .o_packet_out_start(w_recv_control_start),
    .o_packet_out_last(w_recv_control_last),
    .i_packet_out_ready(w_recv_control_ready)
);

PacketArbiter PacketArbiter_Inst(
    .clk(clk),
    .rst(rst),

    .i_channel_0_valid(w_send_control_valid),
    .iv_channel_0_head(wv_send_control_head),
    .iv_channel_0_data(wv_send_control_data),
    .i_channel_0_start(w_send_control_start),
    .i_channel_0_last(w_send_control_last),
    .o_channel_0_ready(w_send_control_ready), 

    .i_channel_1_valid(w_recv_control_valid),
    .iv_channel_1_head(wv_recv_control_head),
    .iv_channel_1_data(wv_recv_control_data),
    .i_channel_1_start(w_recv_control_start),
    .i_channel_1_last(w_recv_control_last),
    .o_channel_1_ready(w_recv_control_ready),

    .o_channel_out_valid(o_send_to_llp_valid),
    .ov_channel_out_head(ov_send_to_llp_head),
    .ov_channel_out_data(ov_send_to_llp_data),
    .o_channel_out_start(o_send_to_llp_start),
    .o_channel_out_last(o_send_to_llp_last),
    .i_channel_out_ready(i_send_to_llp_ready)
);

PacketDistributer PacketDistributer_Inst(
    .clk(clk),
    .rst(rst),

    .i_recv_valid(i_recv_from_llp_valid),
    .iv_recv_head(iv_recv_from_llp_head),
    .iv_recv_data(iv_recv_from_llp_data),
    .i_recv_start(i_recv_from_llp_start),
    .i_recv_last(i_recv_from_llp_last),
    .o_recv_ready(o_recv_from_llp_ready),

    .o_channel_0_out_valid(w_req_valid),
    .ov_channel_0_out_head(wv_req_head),
    .ov_channel_0_out_data(wv_req_data),
    .o_channel_0_out_start(w_req_start),
    .o_channel_0_out_last(w_req_last),
    .i_channel_0_out_ready(w_req_ready),

    .o_channel_1_out_valid(w_ack_valid),
    .ov_channel_1_out_head(wv_ack_head),
    .ov_channel_1_out_data(wv_ack_data),
    .o_channel_1_out_start(w_ack_start),
    .o_channel_1_out_last(w_ack_last),
    .i_channel_1_out_ready(w_ack_ready)
);

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
//Null
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//Null
/*------------------------------------------- Variables Decode : End ------------------------------------------------*/

endmodule