`timescale 	1ns / 1ps

`include "route_params_def.vh"
`ifndef FPGA_VERSION
`define CHIP_VERSION
`endif


module HostRoute_Top
#(
    parameter          C_DATA_WIDTH                        = 256,         // RX/TX interface data width
    parameter          KEEP_WIDTH                          = C_DATA_WIDTH / 32,

    // defined for pcie interface
    parameter          DMA_HEAD_WIDTH                 = 128      ,
    parameter          UPPER_HEAD_WIDTH               = 64 , 
    parameter          DOWN_HEAD_WIDTH                = 64 ,
	parameter PORT_NUM_LOG_2 = 32'd4,
	parameter PORT_INDEX = 32'd0,
	parameter PORT_NUM = 32'd16,
	parameter QUEUE_DEPTH_LOG_2 = 10, 	//Maximum depth of one output queue is (1 << QUEUE_DEPTH)

	// defined for cfg interface
	parameter ROUTE_RO_REG_NUM = 13,
	parameter ROUTE_RW_REG_NUM = 13
)
(
/*Clock and Reset*/
    input 	wire 					clk,
    input 	wire 					rst_n,

///*Work mode related*/
//	input 	wire 	[`PORT_STATE_WIDTH - 1 : 0]					iv_port_state,
////Output queue depth, used to calculate congestion level of different output ports
//	input 	wire 	[PORT_NUM * QUEUE_DEPTH_LOG_2 - 1 : 0]		iv_queue_depth,

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

    /* --------p2p forward up channel{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved | dst_dev | src_dev | Reserved | Byte length |
     * |  63:35   |  37:35  |  34:32  |  31:16   |    15:0     |
     */
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
	/*Interface with Cfg Ring*/
	output 	wire  	[ROUTE_RW_REG_NUM * 32 - 1 : 0]				init_rw_data,
	output 	wire  	[ROUTE_RO_REG_NUM * 32 - 1 : 0] 			ro_reg_data,
	input 	wire 	[ROUTE_RW_REG_NUM * 32 - 1 : 0] 			rw_reg_data,
	input 	wire    [31:0]										dbg_sel,
	//output 	wire    [`DBG_NUM_ROUTE_SUBSYS * 32 - 1:0]										dbg_bus	
	output 	wire    [32 - 1:0]										dbg_bus	

);

wire                                                rst;
assign rst = ~rst_n;

assign init_rw_data = 'd0;


reg                                                  qv_port_mode;
reg         [2:0]                                    qv_dev_id;
reg                                             	qv_work_mode;

assign ro_reg_data = {rw_reg_data[12 * 32 - 1 : 2], qv_work_mode, qv_port_mode};

always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_port_mode <= `ETH_MODE;
		qv_work_mode <= `PASS_THROUGH_MODE;
        qv_dev_id <= 'd0;
    end 
`ifndef CHIP_VERSION
    else begin
        qv_port_mode <= `ETH_MODE;
		qv_work_mode <= `PASS_THROUGH_MODE;
        qv_dev_id <= 'd0;
    end
`else
    else begin
        qv_port_mode <= rw_reg_data[0 * 32  : 0 * 32];
        qv_dev_id <= 'd0;
		qv_work_mode <= rw_reg_data[0 * 32 + 1 : 0 * 32 + 1];
    end
`endif
end


wire												w_nic_hpc_rx_pkt_valid;
wire 												w_nic_hpc_rx_pkt_start;
wire 												w_nic_hpc_rx_pkt_end;
wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			wv_nic_hpc_rx_pkt_user;
wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			wv_nic_hpc_rx_pkt_keep;
wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			wv_nic_hpc_rx_pkt_data;	
wire 												w_nic_hpc_rx_pkt_ready;

wire												w_nic_eth_rx_pkt_valid;
wire 												w_nic_eth_rx_pkt_start;
wire 												w_nic_eth_rx_pkt_end;
wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			wv_nic_eth_rx_pkt_user;
wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			wv_nic_eth_rx_pkt_keep;
wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			wv_nic_eth_rx_pkt_data;
wire 												w_nic_eth_rx_pkt_ready;

wire												w_nic_hpc_tx_pkt_valid;
wire 												w_nic_hpc_tx_pkt_start;
wire 												w_nic_hpc_tx_pkt_end;
wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			wv_nic_hpc_tx_pkt_user;
wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			wv_nic_hpc_tx_pkt_keep;
wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			wv_nic_hpc_tx_pkt_data;	
wire 												w_nic_hpc_tx_pkt_ready;

wire												w_nic_eth_tx_pkt_valid;
wire 												w_nic_eth_tx_pkt_start;
wire 												w_nic_eth_tx_pkt_end;
wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			wv_nic_eth_tx_pkt_user;
wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			wv_nic_eth_tx_pkt_keep;
wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			wv_nic_eth_tx_pkt_data;
wire 												w_nic_eth_tx_pkt_ready;


wire												w_link_hpc_rx_pkt_valid;
wire 												w_link_hpc_rx_pkt_start;
wire 												w_link_hpc_rx_pkt_end;
wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			wv_link_hpc_rx_pkt_user;
wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			wv_link_hpc_rx_pkt_keep;
wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			wv_link_hpc_rx_pkt_data;	
wire 												w_link_hpc_rx_pkt_ready;

wire												w_link_eth_rx_pkt_valid;
wire 												w_link_eth_rx_pkt_start;
wire 												w_link_eth_rx_pkt_end;
wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			wv_link_eth_rx_pkt_user;
wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			wv_link_eth_rx_pkt_keep;
wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			wv_link_eth_rx_pkt_data;
wire 												w_link_eth_rx_pkt_ready;

wire												w_link_hpc_tx_pkt_valid;
wire 												w_link_hpc_tx_pkt_start;
wire 												w_link_hpc_tx_pkt_end;
wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			wv_link_hpc_tx_pkt_user;
wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			wv_link_hpc_tx_pkt_keep;
wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			wv_link_hpc_tx_pkt_data;	
wire 												w_link_hpc_tx_pkt_ready;

wire												w_link_eth_tx_pkt_valid;
wire 												w_link_eth_tx_pkt_start;
wire 												w_link_eth_tx_pkt_end;
wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			wv_link_eth_tx_pkt_user;
wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			wv_link_eth_tx_pkt_keep;
wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			wv_link_eth_tx_pkt_data;


RouteSubsystem #(
	.PORT_NUM_LOG_2(PORT_NUM_LOG_2),
	.PORT_INDEX(PORT_INDEX),
	.PORT_NUM(PORT_NUM),
	.QUEUE_DEPTH_LOG_2(QUEUE_DEPTH_LOG_2)
)
RouteSubsystem_Inst
(
/*Clock and Reset*/
	.clk(clk),
	.rst(~rst_n),

    .iv_port_mode(qv_port_mode),
    .iv_dev_id(qv_dev_id),

	.rw_data(rw_reg_data[13 * 32 - 1 : 1 * 32]),
	.init_rw_data(),
	.ro_data(),

/*-------------------------------Interface with NIC_Top(Begin)----------------------------------*/
    //HPC Traffic in
    .i_nic_hpc_rx_pkt_valid(i_nic_hpc_rx_pkt_valid),
    .i_nic_hpc_rx_pkt_start(i_nic_hpc_rx_pkt_start),
    .i_nic_hpc_rx_pkt_end(i_nic_hpc_rx_pkt_end),
    .iv_nic_hpc_rx_pkt_user(iv_nic_hpc_rx_pkt_user),
    .iv_nic_hpc_rx_pkt_keep(iv_nic_hpc_rx_pkt_keep),
    .iv_nic_hpc_rx_pkt_data(iv_nic_hpc_rx_pkt_data),
    .o_nic_hpc_rx_pkt_ready(w_nic_hpc_rx_pkt_ready),

    //ETH Traffic in、			
    .i_nic_eth_rx_pkt_valid(i_nic_eth_rx_pkt_valid),
    .i_nic_eth_rx_pkt_start(i_nic_eth_rx_pkt_start),
    .i_nic_eth_rx_pkt_end(i_nic_eth_rx_pkt_end),
    .iv_nic_eth_rx_pkt_user(iv_nic_eth_rx_pkt_user),
    .iv_nic_eth_rx_pkt_keep(iv_nic_eth_rx_pkt_keep),
    .iv_nic_eth_rx_pkt_data(iv_nic_eth_rx_pkt_data),
    .o_nic_eth_rx_pkt_ready(w_nic_eth_rx_pkt_ready),

    //HPC Traffic out
    .o_nic_hpc_tx_pkt_valid(w_nic_hpc_tx_pkt_valid),
    .o_nic_hpc_tx_pkt_start(w_nic_hpc_tx_pkt_start),
    .o_nic_hpc_tx_pkt_end(w_nic_hpc_tx_pkt_end),
    .ov_nic_hpc_tx_pkt_user(wv_nic_hpc_tx_pkt_user),
    .ov_nic_hpc_tx_pkt_keep(wv_nic_hpc_tx_pkt_keep),
    .ov_nic_hpc_tx_pkt_data(wv_nic_hpc_tx_pkt_data),
    .i_nic_hpc_tx_pkt_ready(i_nic_hpc_tx_pkt_ready),

    //ETH Traffic out、			
    .o_nic_eth_tx_pkt_valid(w_nic_eth_tx_pkt_valid),
    .o_nic_eth_tx_pkt_start(w_nic_eth_tx_pkt_start),
    .o_nic_eth_tx_pkt_end(w_nic_eth_tx_pkt_end),
    .ov_nic_eth_tx_pkt_user(wv_nic_eth_tx_pkt_user),
    .ov_nic_eth_tx_pkt_keep(wv_nic_eth_tx_pkt_keep),
    .ov_nic_eth_tx_pkt_data(wv_nic_eth_tx_pkt_data),
    .i_nic_eth_tx_pkt_ready(i_nic_eth_tx_pkt_ready),
/*-------------------------------Interface with NIC_Top(End)----------------------------------*/

/*-------------------------------Interface with Link(Begin)----------------------------------*/
    //HPC Traffic in
   .i_link_hpc_rx_pkt_valid(i_link_hpc_rx_pkt_valid),
   .i_link_hpc_rx_pkt_start(i_link_hpc_rx_pkt_start),
   .i_link_hpc_rx_pkt_end(i_link_hpc_rx_pkt_end),
   .iv_link_hpc_rx_pkt_user(iv_link_hpc_rx_pkt_user),
   .iv_link_hpc_rx_pkt_keep(iv_link_hpc_rx_pkt_keep),
   .iv_link_hpc_rx_pkt_data(iv_link_hpc_rx_pkt_data),
   .o_link_hpc_rx_pkt_ready(w_link_hpc_rx_pkt_ready),

    //ETH Traffic in、			
    .i_link_eth_rx_pkt_valid(i_link_eth_rx_pkt_valid),
    .i_link_eth_rx_pkt_start(i_link_eth_rx_pkt_start),
    .i_link_eth_rx_pkt_end(i_link_eth_rx_pkt_end),
    .iv_link_eth_rx_pkt_user(iv_link_eth_rx_pkt_user),
    .iv_link_eth_rx_pkt_keep(iv_link_eth_rx_pkt_keep),
    .iv_link_eth_rx_pkt_data(iv_link_eth_rx_pkt_data),
    .o_link_eth_rx_pkt_ready(w_link_eth_rx_pkt_ready),

    //HPC Traffic out
    .o_link_hpc_tx_pkt_valid(w_link_hpc_tx_pkt_valid),
    .o_link_hpc_tx_pkt_start(w_link_hpc_tx_pkt_start),
    .o_link_hpc_tx_pkt_end(w_link_hpc_tx_pkt_end),
    .ov_link_hpc_tx_pkt_user(wv_link_hpc_tx_pkt_user),
    .ov_link_hpc_tx_pkt_keep(wv_link_hpc_tx_pkt_keep),
    .ov_link_hpc_tx_pkt_data(wv_link_hpc_tx_pkt_data),
    .i_link_hpc_tx_pkt_ready(i_link_hpc_tx_pkt_ready),

    //ETH Traffic out、			
    .o_link_eth_tx_pkt_valid(w_link_eth_tx_pkt_valid),
    .o_link_eth_tx_pkt_start(w_link_eth_tx_pkt_start),
    .o_link_eth_tx_pkt_end(w_link_eth_tx_pkt_end),
    .ov_link_eth_tx_pkt_user(wv_link_eth_tx_pkt_user),
    .ov_link_eth_tx_pkt_keep(wv_link_eth_tx_pkt_keep),
    .ov_link_eth_tx_pkt_data(wv_link_eth_tx_pkt_data),
    .i_link_eth_tx_pkt_ready(i_link_eth_tx_pkt_ready),
/*-------------------------------Interface with Link(End)----------------------------------*/

/*-------------------------------Interface with P2P-Relay(Begin)----------------------------------*/
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
/*-------------------------------Interface with P2P-Relay(End)----------------------------------*/

    .dbg_sel(dbg_sel),
    .dbg_bus(dbg_bus)
);

    //HPC Traffic out
assign o_link_hpc_tx_pkt_valid  = (qv_work_mode == `PASS_THROUGH_MODE) ?  i_nic_hpc_rx_pkt_valid  :  w_link_hpc_tx_pkt_valid;
assign o_link_hpc_tx_pkt_start  = (qv_work_mode == `PASS_THROUGH_MODE) ?  i_nic_hpc_rx_pkt_start  :  w_link_hpc_tx_pkt_start;
assign o_link_hpc_tx_pkt_end    = (qv_work_mode == `PASS_THROUGH_MODE) ?  i_nic_hpc_rx_pkt_end    :  w_link_hpc_tx_pkt_end  ;
assign ov_link_hpc_tx_pkt_user  = (qv_work_mode == `PASS_THROUGH_MODE) ?  iv_nic_hpc_rx_pkt_user  :  wv_link_hpc_tx_pkt_user;
assign ov_link_hpc_tx_pkt_keep  = (qv_work_mode == `PASS_THROUGH_MODE) ?  iv_nic_hpc_rx_pkt_keep  :  wv_link_hpc_tx_pkt_keep;
assign ov_link_hpc_tx_pkt_data  = (qv_work_mode == `PASS_THROUGH_MODE) ?  iv_nic_hpc_rx_pkt_data  :  wv_link_hpc_tx_pkt_data;
assign o_nic_hpc_rx_pkt_ready   = (qv_work_mode == `PASS_THROUGH_MODE) ?  i_link_hpc_tx_pkt_ready :  w_nic_hpc_rx_pkt_ready ;

    //ETH Traffic out、			
assign o_link_eth_tx_pkt_valid  = (qv_work_mode == `PASS_THROUGH_MODE) ?  i_nic_eth_rx_pkt_valid  :  w_link_eth_tx_pkt_valid;
assign o_link_eth_tx_pkt_start  = (qv_work_mode == `PASS_THROUGH_MODE) ?  i_nic_eth_rx_pkt_start  :  w_link_eth_tx_pkt_start;
assign o_link_eth_tx_pkt_end    = (qv_work_mode == `PASS_THROUGH_MODE) ?  i_nic_eth_rx_pkt_end    :  w_link_eth_tx_pkt_end  ;
assign ov_link_eth_tx_pkt_user  = (qv_work_mode == `PASS_THROUGH_MODE) ?  iv_nic_eth_rx_pkt_user  :  wv_link_eth_tx_pkt_user;
assign ov_link_eth_tx_pkt_keep  = (qv_work_mode == `PASS_THROUGH_MODE) ?  iv_nic_eth_rx_pkt_keep  :  wv_link_eth_tx_pkt_keep;
assign ov_link_eth_tx_pkt_data  = (qv_work_mode == `PASS_THROUGH_MODE) ?  iv_nic_eth_rx_pkt_data  :  wv_link_eth_tx_pkt_data;
assign o_nic_eth_rx_pkt_ready   = (qv_work_mode == `PASS_THROUGH_MODE) ?  i_link_eth_tx_pkt_ready :  w_nic_eth_rx_pkt_ready ;

    //HPC Traffic int
assign o_nic_hpc_tx_pkt_valid   = (qv_work_mode == `PASS_THROUGH_MODE) ?  i_link_hpc_rx_pkt_valid :  w_nic_hpc_tx_pkt_valid ;
assign o_nic_hpc_tx_pkt_start   = (qv_work_mode == `PASS_THROUGH_MODE) ?  i_link_hpc_rx_pkt_start :  w_nic_hpc_tx_pkt_start ;
assign o_nic_hpc_tx_pkt_end     = (qv_work_mode == `PASS_THROUGH_MODE) ?  i_link_hpc_rx_pkt_end   :  w_nic_hpc_tx_pkt_end   ;
assign ov_nic_hpc_tx_pkt_user   = (qv_work_mode == `PASS_THROUGH_MODE) ?  iv_link_hpc_rx_pkt_user :  wv_nic_hpc_tx_pkt_user ;
assign ov_nic_hpc_tx_pkt_keep   = (qv_work_mode == `PASS_THROUGH_MODE) ?  iv_link_hpc_rx_pkt_keep :  wv_nic_hpc_tx_pkt_keep ;
assign ov_nic_hpc_tx_pkt_data   = (qv_work_mode == `PASS_THROUGH_MODE) ?  iv_link_hpc_rx_pkt_data :  wv_nic_hpc_tx_pkt_data ;
assign o_link_hpc_rx_pkt_ready  = (qv_work_mode == `PASS_THROUGH_MODE) ?  i_nic_hpc_tx_pkt_ready  :  w_link_hpc_rx_pkt_ready;

    //ETH Traffic in、			
assign o_nic_eth_tx_pkt_valid   = (qv_work_mode == `PASS_THROUGH_MODE) ?  i_link_eth_rx_pkt_valid :  w_nic_eth_tx_pkt_valid ;
assign o_nic_eth_tx_pkt_start   = (qv_work_mode == `PASS_THROUGH_MODE) ?  i_link_eth_rx_pkt_start :  w_nic_eth_tx_pkt_start ;
assign o_nic_eth_tx_pkt_end     = (qv_work_mode == `PASS_THROUGH_MODE) ?  i_link_eth_rx_pkt_end   :  w_nic_eth_tx_pkt_end   ;
assign ov_nic_eth_tx_pkt_user   = (qv_work_mode == `PASS_THROUGH_MODE) ?  iv_link_eth_rx_pkt_user :  wv_nic_eth_tx_pkt_user ;
assign ov_nic_eth_tx_pkt_keep   = (qv_work_mode == `PASS_THROUGH_MODE) ?  iv_link_eth_rx_pkt_keep :  wv_nic_eth_tx_pkt_keep ;
assign ov_nic_eth_tx_pkt_data   = (qv_work_mode == `PASS_THROUGH_MODE) ?  iv_link_eth_rx_pkt_data :  wv_nic_eth_tx_pkt_data ;
assign o_link_eth_rx_pkt_ready  = (qv_work_mode == `PASS_THROUGH_MODE) ?  i_nic_eth_tx_pkt_ready  :  w_link_eth_rx_pkt_ready;

//ila_0 ila_host_route_inst(
//    .clk(clk),
//    .probe0(i_link_eth_rx_pkt_valid),
//    .probe1(i_link_eth_rx_pkt_start),
//    .probe2(i_link_eth_rx_pkt_end),
//    .probe3(o_link_eth_rx_pkt_ready),
//    .probe4(o_nic_eth_tx_pkt_valid),
//    .probe5(o_nic_eth_tx_pkt_start),
//    .probe6(o_nic_eth_tx_pkt_end),
//    .probe7(i_nic_eth_tx_pkt_ready),
//    .probe8(ov_nic_eth_tx_pkt_data),
//    .probe9(iv_link_eth_rx_pkt_data)
//);

endmodule
