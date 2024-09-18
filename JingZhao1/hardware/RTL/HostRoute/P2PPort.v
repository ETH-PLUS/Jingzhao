`timescale 1ns / 1ps

`include "route_params_def.vh"
`ifndef FPGA_VERSION
`define CHIP_VERSION
`endif

module P2PPort #(
    parameter       RW_REG_NUM          =   4,
    parameter       EGRESS_QUEUE_WIDTH  =   288,
    parameter       SRC_DEV_WIDTH       =   3,
    parameter       DST_DEV_WIDTH       =   3,
    parameter       LENGTH_WIDTH        =   7,
    parameter       START_WIDTH         =   1,
    parameter       END_WIDTH           =   1,
    parameter       C_DATA_WIDTH                        = 256,         // RX/TX interface data width
    parameter       KEEP_WIDTH                          = C_DATA_WIDTH / 32,

    // defined for pcie interface
    parameter       DMA_HEAD_WIDTH                 = 128,
    parameter       UPPER_HEAD_WIDTH               = 64, 
    parameter       DOWN_HEAD_WIDTH                = 64
)
(
/*Clock and Reset*/
	input 	wire 	                            				clk,
	input 	wire 					                            rst,

    input 	wire    [`PORT_MODE_WIDTH - 1 : 0]					iv_port_mode,
    input   wire    [2:0]                                       iv_dev_id,

	input 	wire 	[RW_REG_NUM * 32 - 1 : 0]	rw_data,
	output 	wire 	[RW_REG_NUM * 32 - 1 : 0]	init_rw_data,

    output  wire [1                - 1 : 0] 	p2p_tx_valid,     
    output  wire [1                - 1 : 0] 	p2p_tx_last ,     
    output  wire [C_DATA_WIDTH     - 1 : 0] 	p2p_tx_data , 
    output  wire [UPPER_HEAD_WIDTH - 1 : 0] 	p2p_tx_head , 
    input 	wire [1                - 1 : 0] 	p2p_tx_ready, 
    /* --------p2p forward up channel{end}-------- */

    /* --------p2p forward down channel{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved | dst_dev | src_dev | Reserved | Byte length |
     * |  63:35   |  37:35  |  34:32  |  31:16   |    15:0     |
     */
    input wire [1                - 1 : 0] 		p2p_rx_valid,     
    input wire [1                - 1 : 0] 		p2p_rx_last ,     
    input wire [C_DATA_WIDTH     - 1 : 0] 		p2p_rx_data , 
    input wire [DOWN_HEAD_WIDTH  - 1 : 0] 		p2p_rx_head , 
    output wire [1                - 1 : 0] 		p2p_rx_ready, 
    /* --------p2p forward down channel{end}-------- */

    output wire                                                 o_from_link_prog_full,
    input  wire                                                 i_from_link_wr_en,
    input  wire     [EGRESS_QUEUE_WIDTH - 1 : 0]                iv_from_link_data,

    output wire                                                 o_from_nic_prog_full,
    input  wire                                                 i_from_nic_wr_en,
    input  wire     [EGRESS_QUEUE_WIDTH - 1 : 0]                iv_from_nic_data,

    input   wire                                                 i_to_link_prog_full,
    output  wire                                                 o_to_link_wr_en,
    output  wire     [EGRESS_QUEUE_WIDTH - 1 : 0]                ov_to_link_data,

    input   wire                                                 i_to_nic_prog_full,
    output  wire                                                 o_to_nic_wr_en,
    output  wire     [EGRESS_QUEUE_WIDTH - 1 : 0]                ov_to_nic_data
);


//HPC Traffic out
wire												w_hpc_tx_pkt_valid;
wire 												w_hpc_tx_pkt_start;
wire 												w_hpc_tx_pkt_end;
wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			wv_hpc_tx_pkt_user;
wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			wv_hpc_tx_pkt_keep;
wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			wv_hpc_tx_pkt_data;	
wire 												w_hpc_tx_pkt_ready;

//ETH Traffic out、			
wire												w_eth_tx_pkt_valid;
wire 												w_eth_tx_pkt_start;
wire 												w_eth_tx_pkt_end;
wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			wv_eth_tx_pkt_user;
wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			wv_eth_tx_pkt_keep;
wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			wv_eth_tx_pkt_data;
wire 												w_eth_tx_pkt_ready;

FormatTrans FormatTrans_Inst(
	.clk(clk),
	.rst(rst),

    .iv_port_mode(iv_port_mode),
    .iv_dev_id(iv_dev_id),

    .p2p_rx_valid(p2p_rx_valid), 
    .p2p_rx_last(p2p_rx_last),
    .p2p_rx_data(p2p_rx_data),
    .p2p_rx_head(p2p_rx_head),
    .p2p_rx_ready(p2p_rx_ready), 

    .o_hpc_tx_pkt_valid(w_hpc_tx_pkt_valid),
    .o_hpc_tx_pkt_start(w_hpc_tx_pkt_start),
    .o_hpc_tx_pkt_end(w_hpc_tx_pkt_end),
    .ov_hpc_tx_pkt_user(wv_hpc_tx_pkt_user),
    .ov_hpc_tx_pkt_keep(wv_hpc_tx_pkt_keep),
    .ov_hpc_tx_pkt_data(wv_hpc_tx_pkt_data),	
    .i_hpc_tx_pkt_ready(w_hpc_tx_pkt_ready),
	
    .o_eth_tx_pkt_valid(w_eth_tx_pkt_valid),
    .o_eth_tx_pkt_start(w_eth_tx_pkt_start),
    .o_eth_tx_pkt_end(w_eth_tx_pkt_end),
    .ov_eth_tx_pkt_user(wv_eth_tx_pkt_user),
    .ov_eth_tx_pkt_keep(wv_eth_tx_pkt_keep),
    .ov_eth_tx_pkt_data(wv_eth_tx_pkt_data),
    .i_eth_tx_pkt_ready(w_eth_tx_pkt_ready)
);

Route Route_Inst(
	.clk(clk),
	.rst(rst),
    .rw_data(rw_data[(0 + 2) * 32 - 1 : 0 * 32]),
    .init_rw_data(),

    .iv_port_mode(iv_port_mode),
    .iv_dev_id(iv_dev_id),

    .i_hpc_pkt_valid(w_hpc_tx_pkt_valid),
    .i_hpc_pkt_start(w_hpc_tx_pkt_start),
    .i_hpc_pkt_end(w_hpc_tx_pkt_end),
    .iv_hpc_pkt_user(wv_hpc_tx_pkt_user),
    .iv_hpc_pkt_keep(wv_hpc_tx_pkt_keep),
    .iv_hpc_pkt_data(wv_hpc_tx_pkt_data),	
    .o_hpc_pkt_ready(w_hpc_tx_pkt_ready),

    .i_eth_pkt_valid(w_eth_tx_pkt_valid),
    .i_eth_pkt_start(w_eth_tx_pkt_start),
    .i_eth_pkt_end(w_eth_tx_pkt_end),
    .iv_eth_pkt_user(wv_eth_tx_pkt_user),
    .iv_eth_pkt_keep(wv_eth_tx_pkt_keep),
    .iv_eth_pkt_data(wv_eth_tx_pkt_data),
    .o_eth_pkt_ready(w_eth_tx_pkt_ready),

    .i_queue_0_prog_full(i_to_nic_prog_full),
    .o_queue_0_wr_en(o_to_nic_wr_en),
    .ov_queue_0_data(ov_to_nic_data),

    .i_queue_1_prog_full(i_to_link_prog_full),
    .o_queue_1_wr_en(o_to_link_wr_en),
    .ov_queue_1_data(ov_to_link_data)
);

P2PPortMux P2PPortMux_Inst(
	.clk(clk),
	.rst(rst),
    .rw_data(rw_data[(2 + 2) * 32 - 1 : 2 * 32]),
    .init_rw_data(),

    .iv_port_mode(),
	
    .o_queue_0_prog_full(o_from_nic_prog_full),
    .i_queue_0_wr_en(i_from_nic_wr_en),
    .iv_queue_0_data(iv_from_nic_data),

    .o_queue_1_prog_full(o_from_link_prog_full),
    .i_queue_1_wr_en(i_from_link_wr_en),
    .iv_queue_1_data(iv_from_link_data),

    .p2p_tx_valid(p2p_tx_valid),
    .p2p_tx_last(p2p_tx_last),
    .p2p_tx_data(p2p_tx_data),
    .p2p_tx_head(p2p_tx_head),
    .p2p_tx_ready(p2p_tx_ready)
);

endmodule 
