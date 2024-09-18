/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       EnDecap
Author:     YangFan
Function:   Used to verify PacketEncap and PacketDecap
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "common_function_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module EnDecap #(
    parameter       HEADER_BUS_WIDTH        =   512,
    parameter       PAYLOAD_BUS_WIDTH       =   512
)
(
    input   wire                                            clk,
    input   wire                                            rst,

    input   wire                                            i_packet_in_valid,
    input   wire        [HEADER_BUS_WIDTH - 1 : 0]          iv_packet_in_head,
    input   wire        [PAYLOAD_BUS_WIDTH - 1 : 0]         iv_packet_in_data,
    input   wire                                            i_packet_in_start,
    input   wire                                            i_packet_in_last,
    output  wire                                            o_packet_in_ready,

    output  wire                                            o_packet_out_valid,
    output  wire        [HEADER_BUS_WIDTH - 1 : 0]          ov_packet_out_head,
    output  wire        [PAYLOAD_BUS_WIDTH - 1 : 0]         ov_packet_out_data,
    output  wire                                            o_packet_out_start,
    output  wire                                            o_packet_out_last,
    input   wire                                            i_packet_out_ready
);

wire                                            w_packet_encap_valid;
wire        [HEADER_BUS_WIDTH - 1 : 0]          wv_packet_encap_head;
wire        [PAYLOAD_BUS_WIDTH - 1 : 0]         wv_packet_encap_data;
wire                                            w_packet_encap_start;
wire                                            w_packet_encap_last;
wire                                            w_packet_encap_ready;

wire                                            w_packet_decap_valid;
wire        [HEADER_BUS_WIDTH - 1 : 0]          wv_packet_decap_head;
wire        [PAYLOAD_BUS_WIDTH - 1 : 0]         wv_packet_decap_data;
wire                                            w_packet_decap_start;
wire                                            w_packet_decap_last;
wire                                            w_packet_decap_ready;

PacketEncap PacketEncap_Inst(
    .clk(clk),
    .rst(rst),

    .i_packet_in_valid(i_packet_in_valid),
    .iv_packet_in_head(iv_packet_in_head),
    .iv_packet_in_data(iv_packet_in_data),
    .i_packet_in_start(i_packet_in_start),
    .i_packet_in_last(i_packet_in_last),
    .o_packet_in_ready(o_packet_in_ready),

    .o_packet_out_valid(w_packet_encap_valid),
    .ov_packet_out_head(wv_packet_encap_head),
    .ov_packet_out_data(wv_packet_encap_data),
    .o_packet_out_start(w_packet_encap_start),
    .o_packet_out_last(w_packet_encap_last),
    .i_packet_out_ready(w_packet_encap_ready)
);

PacketDecap PacketDecap_Inst(
    .clk(clk),
    .rst(rst),

    .i_packet_in_valid(w_packet_decap_valid),
    .iv_packet_in_head(wv_packet_decap_head),
    .iv_packet_in_data(wv_packet_decap_data),
    .i_packet_in_start(w_packet_decap_start),
    .i_packet_in_last(w_packet_decap_last),
    .o_packet_in_ready(w_packet_decap_ready),

    .o_packet_out_valid(o_packet_out_valid),
    .ov_packet_out_head(ov_packet_out_head),
    .ov_packet_out_data(ov_packet_out_data),
    .o_packet_out_start(o_packet_out_start),
    .o_packet_out_last(o_packet_out_last),
    .i_packet_out_ready(i_packet_out_ready)
);

stream_reg 
#(
    .TUSER_WIDTH(512),
    .TDATA_WIDTH(512)
)
stream_reg_inst(
    .clk(clk),
    .rst_n(~rst),

    .axis_tvalid(w_packet_encap_valid),
    .axis_tlast(w_packet_encap_last),
    .axis_tuser(wv_packet_encap_head),
    .axis_tdata(wv_packet_encap_data),
    .axis_tready(w_packet_encap_ready),
    .axis_tstart(w_packet_encap_start),
    .axis_tkeep('d0),

    .in_reg_tvalid(w_packet_decap_valid),
    .in_reg_tlast(w_packet_decap_last), 
    .in_reg_tuser(wv_packet_decap_head),
    .in_reg_tdata(wv_packet_decap_data),
    .in_reg_tkeep(),
    .in_reg_tstart(w_packet_decap_start),
    .in_reg_tready(w_packet_decap_ready)
);

endmodule