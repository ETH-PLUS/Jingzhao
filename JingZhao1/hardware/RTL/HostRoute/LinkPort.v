`timescale 1ns / 1ps

`include "route_params_def.vh"
`ifndef FPGA_VERSION
`define CHIP_VERSION
`endif

module LinkPort #(
    parameter       RW_REG_NUM          =   4,
    parameter       EGRESS_QUEUE_WIDTH  =   288,
    parameter       SRC_DEV_WIDTH       =   3,
    parameter       DST_DEV_WIDTH       =   3,
    parameter       KEEP_WIDTH          =   32,
    parameter       LENGTH_WIDTH        =   7,
    parameter       START_WIDTH         =   1,
    parameter       END_WIDTH           =   1
)
(
/*Clock and Reset*/
	input 	wire 	                            				clk,
	input 	wire 					                            rst,

    input 	wire    [`PORT_MODE_WIDTH - 1 : 0]					iv_port_mode,
    input   wire    [2:0]                                       iv_dev_id,

	input 	wire 	[RW_REG_NUM * 32 - 1 : 0]	rw_data,
	output 	wire 	[RW_REG_NUM * 32 - 1 : 0]	init_rw_data,

    //HPC Traffic in
    input 	wire												i_link_hpc_rx_pkt_valid,
    input 	wire 												i_link_hpc_rx_pkt_start,
    input 	wire 												i_link_hpc_rx_pkt_end,
    input 	wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			iv_link_hpc_rx_pkt_user,
    input 	wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			iv_link_hpc_rx_pkt_keep,
    input	wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			iv_link_hpc_rx_pkt_data,	
    output 	wire 												o_link_hpc_rx_pkt_ready,

    //ETH Traffic in、			
    input 	wire												i_link_eth_rx_pkt_valid,
    input 	wire 												i_link_eth_rx_pkt_start,
    input 	wire 												i_link_eth_rx_pkt_end,
    input 	wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			iv_link_eth_rx_pkt_user,
    input 	wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			iv_link_eth_rx_pkt_keep,
    input	wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			iv_link_eth_rx_pkt_data,
    output 	wire 												o_link_eth_rx_pkt_ready,

    //HPC Traffic out
    output 	wire												o_link_hpc_tx_pkt_valid,
    output 	wire 												o_link_hpc_tx_pkt_start,
    output 	wire 												o_link_hpc_tx_pkt_end,
    output 	wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			ov_link_hpc_tx_pkt_user,
    output 	wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			ov_link_hpc_tx_pkt_keep,
    output	wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			ov_link_hpc_tx_pkt_data,	
    input 	wire 												i_link_hpc_tx_pkt_ready,

    //ETH Traffic out、			
    output 	wire												o_link_eth_tx_pkt_valid,
    output 	wire 												o_link_eth_tx_pkt_start,
    output 	wire 												o_link_eth_tx_pkt_end,
    output 	wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			ov_link_eth_tx_pkt_user,
    output 	wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			ov_link_eth_tx_pkt_keep,
    output	wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			ov_link_eth_tx_pkt_data,
    input 	wire 												i_link_eth_tx_pkt_ready,
		 
    output wire                                                 o_from_nic_prog_full,
    input  wire                                                 i_from_nic_wr_en,
    input  wire     [EGRESS_QUEUE_WIDTH - 1 : 0]                iv_from_nic_data,

    output wire                                                 o_from_p2p_prog_full,
    input  wire                                                 i_from_p2p_wr_en,
    input  wire     [EGRESS_QUEUE_WIDTH - 1 : 0]                iv_from_p2p_data,

    input   wire                                                 i_to_nic_prog_full,
    output  wire                                                 o_to_nic_wr_en,
    output  wire     [EGRESS_QUEUE_WIDTH - 1 : 0]                ov_to_nic_data,

    input   wire                                                 i_to_p2p_prog_full,
    output  wire                                                 o_to_p2p_wr_en,
    output  wire     [EGRESS_QUEUE_WIDTH - 1 : 0]                ov_to_p2p_data
);

Route Route_Inst(
	.clk(clk),
	.rst(rst),

    .rw_data(rw_data[(0 + 2) * 32 - 1 : 0 * 32]),
    .init_rw_data(),

    .iv_port_mode(iv_port_mode),
    .iv_dev_id(iv_dev_id),

    .i_hpc_pkt_valid(i_link_hpc_rx_pkt_valid),
    .i_hpc_pkt_start(i_link_hpc_rx_pkt_start),
    .i_hpc_pkt_end(i_link_hpc_rx_pkt_end),
    .iv_hpc_pkt_user(iv_link_hpc_rx_pkt_user),
    .iv_hpc_pkt_keep(iv_link_hpc_rx_pkt_keep),
    .iv_hpc_pkt_data(iv_link_hpc_rx_pkt_data),
    .o_hpc_pkt_ready(o_link_hpc_rx_pkt_ready),

    .i_eth_pkt_valid(i_link_eth_rx_pkt_valid),
    .i_eth_pkt_start(i_link_eth_rx_pkt_start),
    .i_eth_pkt_end(i_link_eth_rx_pkt_end),
    .iv_eth_pkt_user(iv_link_eth_rx_pkt_user),
    .iv_eth_pkt_keep(iv_link_eth_rx_pkt_keep),
    .iv_eth_pkt_data(iv_link_eth_rx_pkt_data),	
    .o_eth_pkt_ready(o_link_eth_rx_pkt_ready),

    .i_queue_0_prog_full(i_to_nic_prog_full),
    .o_queue_0_wr_en(o_to_nic_wr_en),
    .ov_queue_0_data(ov_to_nic_data),

    .i_queue_1_prog_full(i_to_p2p_prog_full),
    .o_queue_1_wr_en(o_to_p2p_wr_en),
    .ov_queue_1_data(ov_to_p2p_data)
);

NonP2PPortMux NonP2PPortMux_Inst(
/*Clock and Reset*/
	.clk(clk),
	.rst(rst),

    .iv_port_mode(iv_port_mode),

    .rw_data(rw_data[(2 + 2) * 32 - 1 : 2 * 32]),
    .init_rw_data(),

    .o_queue_0_prog_full(o_from_nic_prog_full),
    .i_queue_0_wr_en(i_from_nic_wr_en),
    .iv_queue_0_data(iv_from_nic_data),

    .o_queue_1_prog_full(o_from_p2p_prog_full),
    .i_queue_1_wr_en(i_from_p2p_wr_en),
    .iv_queue_1_data(iv_from_p2p_data),

    .o_hpc_tx_pkt_valid(o_link_hpc_tx_pkt_valid),
    .o_hpc_tx_pkt_start(o_link_hpc_tx_pkt_start),
    .o_hpc_tx_pkt_end(o_link_hpc_tx_pkt_end),
    .ov_hpc_tx_pkt_user(ov_link_hpc_tx_pkt_user),
    .ov_hpc_tx_pkt_keep(ov_link_hpc_tx_pkt_keep),
    .ov_hpc_tx_pkt_data(ov_link_hpc_tx_pkt_data),	
    .i_hpc_tx_pkt_ready(i_link_hpc_tx_pkt_ready),

    .o_eth_tx_pkt_valid(o_link_eth_tx_pkt_valid),
    .o_eth_tx_pkt_start(o_link_eth_tx_pkt_start),
    .o_eth_tx_pkt_end(o_link_eth_tx_pkt_end),
    .ov_eth_tx_pkt_user(ov_link_eth_tx_pkt_user),
    .ov_eth_tx_pkt_keep(ov_link_eth_tx_pkt_keep),
    .ov_eth_tx_pkt_data(ov_link_eth_tx_pkt_data),
    .i_eth_tx_pkt_ready(i_link_eth_tx_pkt_ready)
);

endmodule 
