/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       TransportSubsystem_vrf
Author:     YangFan
Function:   Wrapper for TransportSubsystem, for verification.
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

module TransportSubsystem_vrf(
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
    output  wire                                                            o_recv_from_llp_ready
);

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                                            w_ingress_valid;
wire        [`PKT_HEAD_WIDTH - 1 : 0]                           wv_ingress_head;
wire        [`PKT_DATA_WIDTH - 1 : 0]                           wv_ingress_data;
wire                                                            w_ingress_start;
wire                                                            w_ingress_last;
wire                                                            w_ingress_ready;

wire                                                            w_egress_valid;
wire        [`PKT_HEAD_WIDTH - 1 : 0]                           wv_egress_head;
wire        [`PKT_DATA_WIDTH - 1 : 0]                           wv_egress_data;
wire                                                            w_egress_start;
wire                                                            w_egress_last;
wire                                                            w_egress_ready;

wire        [`QP_NUM_LOG - 1 : 0]                               wv_npsn_rd_index;
wire        [`PSN_WIDTH - 1 : 0]                                wv_npsn_rd_data;
wire                                                            w_npsn_wr_en;
wire        [`QP_NUM_LOG - 1 : 0]                               wv_npsn_wr_index;
wire        [`PSN_WIDTH - 1 : 0]                                wv_npsn_wr_data;

wire        [`QP_NUM_LOG - 1 : 0]                               wv_upsn_rd_index;
wire        [`PSN_WIDTH - 1 : 0]                                wv_upsn_rd_data;
wire                                                            w_upsn_wr_en;
wire        [`QP_NUM_LOG - 1 : 0]                               wv_upsn_wr_index;
wire        [`PSN_WIDTH - 1 : 0]                                wv_upsn_wr_data;

wire        [`QP_NUM_LOG - 1 : 0]                               wv_ooa_epsn_rd_index;
wire        [`PSN_WIDTH - 1 : 0]                                wv_ooa_epsn_rd_data;
wire                                                            w_ooa_epsn_wr_en;
wire        [`QP_NUM_LOG - 1 : 0]                               wv_ooa_epsn_wr_index;
wire        [`PSN_WIDTH - 1 : 0]                                wv_ooa_epsn_wr_data;

wire        [`QP_NUM_LOG - 1 : 0]                               wv_ioc_epsn_rd_index;
wire        [`PSN_WIDTH - 1 : 0]                                wv_ioc_epsn_rd_data;
wire                                                            w_ioc_epsn_wr_en;
wire        [`QP_NUM_LOG - 1 : 0]                               wv_ioc_epsn_wr_index;
wire        [`PSN_WIDTH - 1 : 0]                                wv_ioc_epsn_wr_data;

/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
TransportSubsystem TransportSubsystem_Inst(
    .clk(clk),
    .rst(rst),

    .i_inject_from_ulp_valid(i_inject_from_ulp_valid),
    .iv_inject_from_ulp_head(iv_inject_from_ulp_head),
    .iv_inject_from_ulp_data(iv_inject_from_ulp_data),
    .i_inject_from_ulp_start(i_inject_from_ulp_start),
    .i_inject_from_ulp_last(i_inject_from_ulp_last),
    .o_inject_from_ulp_ready(o_inject_from_ulp_ready),

    .o_commit_to_ulp_valid(o_commit_to_ulp_valid),
    .ov_commit_to_ulp_head(ov_commit_to_ulp_head),
    .ov_commit_to_ulp_data(ov_commit_to_ulp_data),
    .o_commit_to_ulp_start(o_commit_to_ulp_start),
    .o_commit_to_ulp_last(o_commit_to_ulp_last),
    .i_commit_to_ulp_ready(i_commit_to_ulp_ready),

    .o_send_to_llp_valid(w_egress_valid),
    .ov_send_to_llp_head(wv_egress_head),
    .ov_send_to_llp_data(wv_egress_data),
    .o_send_to_llp_start(w_egress_start),
    .o_send_to_llp_last(w_egress_last),
    .i_send_to_llp_ready(w_egress_ready),

    .i_recv_from_llp_valid(w_ingress_valid),
    .iv_recv_from_llp_head(wv_ingress_head),
    .iv_recv_from_llp_data(wv_ingress_data),
    .i_recv_from_llp_start(w_ingress_start),
    .i_recv_from_llp_last(w_ingress_last),
    .o_recv_from_llp_ready(w_ingress_ready),

    .o_npsn_wr_en(w_npsn_wr_en),
    .ov_npsn_wr_index(wv_npsn_wr_index),
    .ov_npsn_wr_data(wv_npsn_wr_data),
    .ov_npsn_rd_index(wv_npsn_rd_index),
    .iv_npsn_rd_data(wv_npsn_rd_data),

    .ov_upsn_rd_index(wv_upsn_rd_index),
    .iv_upsn_rd_data(wv_upsn_rd_data),
    .o_upsn_wr_en(w_upsn_wr_en),
    .ov_upsn_wr_index(wv_upsn_wr_index),
    .ov_upsn_wr_data(wv_upsn_wr_data),

    .ov_ooa_epsn_rd_index(wv_ooa_epsn_rd_index),
    .iv_ooa_epsn_rd_data(wv_ooa_epsn_rd_data),
    .o_ooa_epsn_wr_en(w_ooa_epsn_wr_en),
    .ov_ooa_epsn_wr_index(wv_ooa_epsn_wr_index),
    .ov_ooa_epsn_wr_data(wv_ooa_epsn_wr_data),

    .ov_ioc_epsn_rd_index(wv_ioc_epsn_rd_index),
    .iv_ioc_epsn_rd_data(wv_ioc_epsn_rd_data),
    .o_ioc_epsn_wr_en(w_ioc_epsn_wr_en),
    .ov_ioc_epsn_wr_index(wv_ioc_epsn_wr_index),
    .ov_ioc_epsn_wr_data(wv_ioc_epsn_wr_data)
);

PacketEncap PacketEncap_Inst(
    .clk(clk),
    .rst(rst),

    .i_packet_in_valid(w_egress_valid),
    .iv_packet_in_head(wv_egress_head),
    .iv_packet_in_data(wv_egress_data),
    .i_packet_in_start(w_egress_start),
    .i_packet_in_last(w_egress_last),
    .o_packet_in_ready(w_egress_ready),

    .o_packet_out_valid(o_send_to_llp_valid),
    .ov_packet_out_head(ov_send_to_llp_head),
    .ov_packet_out_data(ov_send_to_llp_data),
    .o_packet_out_start(o_send_to_llp_start),
    .o_packet_out_last(o_send_to_llp_last),
    .i_packet_out_ready(i_send_to_llp_ready)
);

PacketDecap PacketDecap_Inst
(
    .clk(clk),
    .rst(rst),

    .i_packet_in_valid(i_recv_from_llp_valid),
    .iv_packet_in_head(iv_recv_from_llp_head),
    .iv_packet_in_data(iv_recv_from_llp_data),
    .i_packet_in_start(i_recv_from_llp_start),
    .i_packet_in_last(i_recv_from_llp_last),
    .o_packet_in_ready(o_recv_from_llp_ready),

    .o_packet_out_valid(w_ingress_valid),
    .ov_packet_out_head(wv_ingress_head),
    .ov_packet_out_data(wv_ingress_data),
    .o_packet_out_start(w_ingress_start),
    .o_packet_out_last(w_ingress_last),
    .i_packet_out_ready(w_ingress_ready)
);

SRAM_TDP_Template #(
    .RAM_WIDTH(`PSN_WIDTH),
    .RAM_DEPTH(`QP_NUM)
)
EPSN_TABLE
(
    .clk(clk),
    .rst(rst),

    .wea(w_ioc_epsn_wr_en),
    .addra(w_ioc_epsn_wr_en ? wv_ioc_epsn_wr_index : wv_ioc_epsn_rd_index),
    .dina(wv_ioc_epsn_wr_data),
    .douta(wv_ioc_epsn_rd_data),             

    .web(w_ooa_epsn_wr_en),
    .addrb(w_ooa_epsn_wr_en ? wv_ooa_epsn_wr_index : wv_ooa_epsn_rd_index),
    .dinb(wv_ooa_epsn_wr_data),
    .doutb(wv_ooa_epsn_rd_data)                      
);

SRAM_SDP_Template #(
    .RAM_WIDTH(`PSN_WIDTH),
    .RAM_DEPTH(`QP_NUM)
)
NPSN_Table
(
    .clk(clk),
    .rst(rst),

    .wea(w_npsn_wr_en),
    .addra(wv_npsn_wr_index),
    .dina(wv_npsn_wr_data),             

    .addrb(wv_npsn_rd_index),
    .doutb(wv_npsn_rd_data)                     
);

SRAM_SDP_Template #(
    .RAM_WIDTH(`PSN_WIDTH),
    .RAM_DEPTH(`QP_NUM)
)
UPSN_Table
(
    .clk(clk),
    .rst(rst),

    .wea(w_upsn_wr_en),
    .addra(wv_upsn_wr_index),
    .dina(wv_upsn_wr_data),             

    .addrb(wv_upsn_rd_index),
    .doutb(wv_upsn_rd_data)                     
);


/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

endmodule