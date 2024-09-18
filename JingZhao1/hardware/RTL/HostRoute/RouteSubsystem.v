`timescale 	1ns / 1ps

`include "route_params_def.vh"
`ifndef FPGA_VERSION
`define CHIP_VERSION
`endif

module RouteSubsystem
#(

	parameter NODE_ID = 16'd0,
	parameter PORT_NUM_LOG_2 = 32'd4,
	parameter PORT_INDEX = 4'd0,
	parameter PORT_NUM = 32'd16,
	parameter QUEUE_DEPTH_LOG_2 = 11, 	//Maximum depth of one output queue is (1 << QUEUE_DEPTH)

    parameter          DMA_HEAD_WIDTH                 = 128      ,
    parameter          UPPER_HEAD_WIDTH               = 64 , 
    parameter          DOWN_HEAD_WIDTH                = 64 ,

    parameter       C_DATA_WIDTH                        = 256,         // RX/TX interface data width
    parameter       KEEP_WIDTH                          = C_DATA_WIDTH / 32,
    parameter       EGRESS_QUEUE_WIDTH  =   288,

	parameter RW_REG_NUM = 12,
	parameter RO_REG_NUM = 12
)
(
/*Clock and Reset*/
	input 	wire 					clk,
	input 	wire 					rst,

    input   wire                                                iv_port_mode,
    input   wire    [2:0]                                       iv_dev_id,

/*-------------------------------Interface with NIC_Top(Begin)----------------------------------*/
    //HPC Traffic in
    input 	wire												i_nic_hpc_rx_pkt_valid,
    input 	wire 												i_nic_hpc_rx_pkt_start,
    input 	wire 												i_nic_hpc_rx_pkt_end,
    input 	wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			iv_nic_hpc_rx_pkt_user,
    input 	wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			iv_nic_hpc_rx_pkt_keep,
    input	wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			iv_nic_hpc_rx_pkt_data,	
    output 	wire 												o_nic_hpc_rx_pkt_ready,

    //ETH Traffic in、			
    input 	wire												i_nic_eth_rx_pkt_valid,
    input 	wire 												i_nic_eth_rx_pkt_start,
    input 	wire 												i_nic_eth_rx_pkt_end,
    input 	wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			iv_nic_eth_rx_pkt_user,
    input 	wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			iv_nic_eth_rx_pkt_keep,
    input	wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			iv_nic_eth_rx_pkt_data,
    output 	wire 												o_nic_eth_rx_pkt_ready,

    //HPC Traffic out
    output 	wire												o_nic_hpc_tx_pkt_valid,
    output 	wire 												o_nic_hpc_tx_pkt_start,
    output 	wire 												o_nic_hpc_tx_pkt_end,
    output 	wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			ov_nic_hpc_tx_pkt_user,
    output 	wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			ov_nic_hpc_tx_pkt_keep,
    output	wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			ov_nic_hpc_tx_pkt_data,	
    input 	wire 												i_nic_hpc_tx_pkt_ready,

    //ETH Traffic out、			
    output 	wire												o_nic_eth_tx_pkt_valid,
    output 	wire 												o_nic_eth_tx_pkt_start,
    output 	wire 												o_nic_eth_tx_pkt_end,
    output 	wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			ov_nic_eth_tx_pkt_user,
    output 	wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			ov_nic_eth_tx_pkt_keep,
    output	wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			ov_nic_eth_tx_pkt_data,
    input 	wire 												i_nic_eth_tx_pkt_ready,
/*-------------------------------Interface with NIC_Top(End)----------------------------------*/

/*-------------------------------Interface with Link(Begin)----------------------------------*/
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
/*-------------------------------Interface with Link(End)----------------------------------*/

/*-------------------------------Interface with P2P-Relay(Begin)----------------------------------*/
    /* --------p2p forward up channel{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved | dst_dev | src_dev | Reserved | Byte length |
     * |  63:35   |  37:35  |  34:32  |  31:16   |    15:0     |
     */
    output  wire 	 											p2p_tx_valid,     
    output  wire 	 											p2p_tx_last,     
    output  wire 	[C_DATA_WIDTH - 1 : 0] 						p2p_tx_data, 
    output  wire 	[UPPER_HEAD_WIDTH - 1 : 0] 					p2p_tx_head, 
    input 	wire 	 											p2p_tx_ready, 
    /* --------p2p forward up channel{end}-------- */

    /* --------p2p forward down channel{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved | dst_dev | src_dev | Reserved | Byte length |
     * |  63:35   |  37:35  |  34:32  |  31:16   |    15:0     |
     */
    input 	wire												p2p_rx_valid,     
    input 	wire 												p2p_rx_last,     
    input 	wire 	[C_DATA_WIDTH - 1 : 0]						p2p_rx_data, 
    input 	wire 	[DOWN_HEAD_WIDTH  - 1 : 0]					p2p_rx_head, 
    output 	wire 												p2p_rx_ready, 
    /* --------p2p forward down channel{end}-------- */
/*-------------------------------Interface with P2P-Relay(End)----------------------------------*/

	/*Interface with Cfg Ring*/
	output 	wire  	[RW_REG_NUM * 32 - 1 : 0]			init_rw_data,
	output 	wire  	[RO_REG_NUM * 32 - 1 : 0] 			ro_data,
	input 	wire 	[RW_REG_NUM * 32 - 1 : 0] 			rw_data,
	input 	wire    [31:0]										dbg_sel,
	output 	wire    [32 - 1:0]										dbg_bus
	//output 	wire    [`DBG_NUM_ROUTE_SUBSYS * 32 - 1:0]										dbg_bus
);

assign dbg_bus = 'd0;
assign init_rw_data = 'd0;
assign ro_data = 'd0;

wire                                                 w_nic_to_link_prog_full;
wire                                                 w_nic_to_link_wr_en;
wire     [EGRESS_QUEUE_WIDTH - 1 : 0]                wv_nic_to_link_data;

wire                                                 w_nic_to_p2p_prog_full;
wire                                                 w_nic_to_p2p_wr_en;
wire     [EGRESS_QUEUE_WIDTH - 1 : 0]                wv_nic_to_p2p_data;

wire                                                 w_p2p_to_nic_prog_full;
wire                                                 w_p2p_to_nic_wr_en;
wire     [EGRESS_QUEUE_WIDTH - 1 : 0]                wv_p2p_to_nic_data;

wire                                                 w_p2p_to_link_prog_full;
wire                                                 w_p2p_to_link_wr_en;
wire     [EGRESS_QUEUE_WIDTH - 1 : 0]                wv_p2p_to_link_data;

wire                                                 w_link_to_nic_prog_full;
wire                                                 w_link_to_nic_wr_en;
wire     [EGRESS_QUEUE_WIDTH - 1 : 0]                wv_link_to_nic_data;

wire                                                 w_link_to_p2p_prog_full;
wire                                                 w_link_to_p2p_wr_en;
wire     [EGRESS_QUEUE_WIDTH - 1 : 0]                wv_link_to_p2p_data;

//reg                                                  qv_port_mode;
//reg         [2:0]                                    qv_dev_id;

// always @(posedge clk or posedge rst) begin
//     if(rst) begin
//         qv_port_mode <= `HPC_MODE;
//         qv_dev_id <= 'd0;
//     end 
//     else begin
//         qv_port_mode <= `HPC_MODE;
//         qv_dev_id <= 'd0;
//     end
// end

NICPort NICPort_Inst(
    .clk(clk),
    .rst(rst),
    
    .iv_port_mode(iv_port_mode),
    .iv_dev_id(iv_dev_id),

    .rw_data(rw_data[(0 + 4) * 32 - 1 : 0 * 32]),
    .init_rw_data(),
    
    .i_nic_hpc_rx_pkt_valid(i_nic_hpc_rx_pkt_valid),
    .i_nic_hpc_rx_pkt_start(i_nic_hpc_rx_pkt_start),
    .i_nic_hpc_rx_pkt_end(i_nic_hpc_rx_pkt_end),
    .iv_nic_hpc_rx_pkt_user(iv_nic_hpc_rx_pkt_user),
    .iv_nic_hpc_rx_pkt_keep(iv_nic_hpc_rx_pkt_keep),
    .iv_nic_hpc_rx_pkt_data(iv_nic_hpc_rx_pkt_data),	
    .o_nic_hpc_rx_pkt_ready(o_nic_hpc_rx_pkt_ready),
    
    .i_nic_eth_rx_pkt_valid(i_nic_eth_rx_pkt_valid),
    .i_nic_eth_rx_pkt_start(i_nic_eth_rx_pkt_start),
    .i_nic_eth_rx_pkt_end(i_nic_eth_rx_pkt_end),
    .iv_nic_eth_rx_pkt_user(iv_nic_eth_rx_pkt_user),
    .iv_nic_eth_rx_pkt_keep(iv_nic_eth_rx_pkt_keep),
    .iv_nic_eth_rx_pkt_data(iv_nic_eth_rx_pkt_data),
    .o_nic_eth_rx_pkt_ready(o_nic_eth_rx_pkt_ready),
    
    .o_nic_hpc_tx_pkt_valid(o_nic_hpc_tx_pkt_valid),
    .o_nic_hpc_tx_pkt_start(o_nic_hpc_tx_pkt_start),
    .o_nic_hpc_tx_pkt_end(o_nic_hpc_tx_pkt_end),
    .ov_nic_hpc_tx_pkt_user(ov_nic_hpc_tx_pkt_user),
    .ov_nic_hpc_tx_pkt_keep(ov_nic_hpc_tx_pkt_keep),
    .ov_nic_hpc_tx_pkt_data(ov_nic_hpc_tx_pkt_data),	
    .i_nic_hpc_tx_pkt_ready(i_nic_hpc_tx_pkt_ready),
    
    .o_nic_eth_tx_pkt_valid(o_nic_eth_tx_pkt_valid),
    .o_nic_eth_tx_pkt_start(o_nic_eth_tx_pkt_start),
    .o_nic_eth_tx_pkt_end(o_nic_eth_tx_pkt_end),
    .ov_nic_eth_tx_pkt_user(ov_nic_eth_tx_pkt_user),
    .ov_nic_eth_tx_pkt_keep(ov_nic_eth_tx_pkt_keep),
    .ov_nic_eth_tx_pkt_data(ov_nic_eth_tx_pkt_data),
    .i_nic_eth_tx_pkt_ready(i_nic_eth_tx_pkt_ready),
    
    .o_from_link_prog_full(w_link_to_nic_prog_full),
    .i_from_link_wr_en(w_link_to_nic_wr_en),
    .iv_from_link_data(wv_link_to_nic_data),
    
    .o_from_p2p_prog_full(w_p2p_to_nic_prog_full),
    .i_from_p2p_wr_en(w_p2p_to_nic_wr_en),
    .iv_from_p2p_data(wv_p2p_to_nic_data),
    
    .i_to_link_prog_full(w_nic_to_link_prog_full),
    .o_to_link_wr_en(w_nic_to_link_wr_en),
    .ov_to_link_data(wv_nic_to_link_data),
    
    .i_to_p2p_prog_full(w_nic_to_p2p_prog_full),
    .o_to_p2p_wr_en(w_nic_to_p2p_wr_en),
    .ov_to_p2p_data(wv_nic_to_p2p_data)
);

LinkPort LinkPort_Inst(
    .clk(clk),
    .rst(rst),
    
    .iv_port_mode(iv_port_mode),
    .iv_dev_id(iv_dev_id),

    .rw_data(rw_data[(4 + 4) * 32 - 1 : 4 * 32]),
    .init_rw_data(),
    
    .i_link_hpc_rx_pkt_valid(i_link_hpc_rx_pkt_valid),
    .i_link_hpc_rx_pkt_start(i_link_hpc_rx_pkt_start),
    .i_link_hpc_rx_pkt_end(i_link_hpc_rx_pkt_end),
    .iv_link_hpc_rx_pkt_user(iv_link_hpc_rx_pkt_user),
    .iv_link_hpc_rx_pkt_keep(iv_link_hpc_rx_pkt_keep),
    .iv_link_hpc_rx_pkt_data(iv_link_hpc_rx_pkt_data),	
    .o_link_hpc_rx_pkt_ready(o_link_hpc_rx_pkt_ready),
    
    .i_link_eth_rx_pkt_valid(i_link_eth_rx_pkt_valid),
    .i_link_eth_rx_pkt_start(i_link_eth_rx_pkt_start),
    .i_link_eth_rx_pkt_end(i_link_eth_rx_pkt_end),
    .iv_link_eth_rx_pkt_user(iv_link_eth_rx_pkt_user),
    .iv_link_eth_rx_pkt_keep(iv_link_eth_rx_pkt_keep),
    .iv_link_eth_rx_pkt_data(iv_link_eth_rx_pkt_data),
    .o_link_eth_rx_pkt_ready(o_link_eth_rx_pkt_ready),
    
    .o_link_hpc_tx_pkt_valid(o_link_hpc_tx_pkt_valid),
    .o_link_hpc_tx_pkt_start(o_link_hpc_tx_pkt_start),
    .o_link_hpc_tx_pkt_end(o_link_hpc_tx_pkt_end),
    .ov_link_hpc_tx_pkt_user(ov_link_hpc_tx_pkt_user),
    .ov_link_hpc_tx_pkt_keep(ov_link_hpc_tx_pkt_keep),
    .ov_link_hpc_tx_pkt_data(ov_link_hpc_tx_pkt_data),	
    .i_link_hpc_tx_pkt_ready(i_link_hpc_tx_pkt_ready),
    
    .o_link_eth_tx_pkt_valid(o_link_eth_tx_pkt_valid),
    .o_link_eth_tx_pkt_start(o_link_eth_tx_pkt_start),
    .o_link_eth_tx_pkt_end(o_link_eth_tx_pkt_end),
    .ov_link_eth_tx_pkt_user(ov_link_eth_tx_pkt_user),
    .ov_link_eth_tx_pkt_keep(ov_link_eth_tx_pkt_keep),
    .ov_link_eth_tx_pkt_data(ov_link_eth_tx_pkt_data),
    .i_link_eth_tx_pkt_ready(i_link_eth_tx_pkt_ready),
    
    .o_from_nic_prog_full(w_nic_to_link_prog_full),
    .i_from_nic_wr_en(w_nic_to_link_wr_en),
    .iv_from_nic_data(wv_nic_to_link_data),
    
    .o_from_p2p_prog_full(w_p2p_to_link_prog_full),
    .i_from_p2p_wr_en(w_p2p_to_link_wr_en),
    .iv_from_p2p_data(wv_p2p_to_link_data),
    
    .i_to_nic_prog_full(w_link_to_nic_prog_full),
    .o_to_nic_wr_en(w_link_to_nic_wr_en),
    .ov_to_nic_data(wv_link_to_nic_data),
    
    .i_to_p2p_prog_full(w_link_to_p2p_prog_full),
    .o_to_p2p_wr_en(w_link_to_p2p_wr_en),
    .ov_to_p2p_data(wv_link_to_p2p_data)
);

P2PPort P2PPort_Inst(
    .clk(clk),
    .rst(rst),
    
    .iv_port_mode(iv_port_mode),
    .iv_dev_id(iv_dev_id),

    .rw_data(rw_data[(8 + 4) * 32 - 1 : 8 * 32]),
    .init_rw_data(),

    .p2p_tx_valid(p2p_tx_valid),
    .p2p_tx_last(p2p_tx_last),
    .p2p_tx_data(p2p_tx_data),
    .p2p_tx_head(p2p_tx_head),
    .p2p_tx_ready(p2p_tx_ready),

    .p2p_rx_valid(p2p_rx_valid),
    .p2p_rx_last(p2p_rx_last),
    .p2p_rx_data(p2p_rx_data),
    .p2p_rx_head(p2p_rx_head),
    .p2p_rx_ready(p2p_rx_ready),

    .o_from_link_prog_full(w_link_to_p2p_prog_full),
    .i_from_link_wr_en(w_link_to_p2p_wr_en),
    .iv_from_link_data(wv_link_to_p2p_data),

    .o_from_nic_prog_full(w_nic_to_p2p_prog_full),
    .i_from_nic_wr_en(w_nic_to_p2p_wr_en),
    .iv_from_nic_data(wv_nic_to_p2p_data),

    .i_to_link_prog_full(w_p2p_to_link_prog_full),
    .o_to_link_wr_en(w_p2p_to_link_wr_en),
    .ov_to_link_data(wv_p2p_to_link_data),

    .i_to_nic_prog_full(w_p2p_to_nic_prog_full),
    .o_to_nic_wr_en(w_p2p_to_nic_wr_en),
    .ov_to_nic_data(wv_p2p_to_nic_data)
);

endmodule
