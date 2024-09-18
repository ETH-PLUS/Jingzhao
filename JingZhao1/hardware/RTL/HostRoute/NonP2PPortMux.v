`timescale 1ns / 1ps

`include "route_params_def.vh"

`ifndef FPGA_VERSION
`define CHIP_VERSION
`endif

`define     QUEUE_0         2'b00
`define     QUEUE_1         2'b01
`define     IDLE            2'b11

module NonP2PPortMux #(
    parameter       RW_REG_NUM          = 2,

    parameter       C_DATA_WIDTH                        = 256,         // RX/TX interface data width

    parameter       EGRESS_QUEUE_WIDTH  =   288,
    parameter       SRC_DEV_WIDTH       =   3,
    parameter       DST_DEV_WIDTH       =   3,
    parameter       LENGTH_WIDTH        =   7,
    parameter       START_WIDTH         =   1,
    parameter       END_WIDTH           =   1
)
(
/*Clock and Reset*/
	input 	wire 	                            				clk,
	input 	wire 					                            rst,

	input 	wire 	[RW_REG_NUM * 32 - 1 : 0]	rw_data,
	output 	wire 	[RW_REG_NUM * 32 - 1 : 0]	init_rw_data,

    input 	wire    [`PORT_MODE_WIDTH - 1 : 0]					iv_port_mode,

    //Traffic out - To Egress Queue 0			 
    output wire                                                 o_queue_0_prog_full,
    input  wire                                                 i_queue_0_wr_en,
    input  wire     [EGRESS_QUEUE_WIDTH - 1 : 0]                iv_queue_0_data,

    //Traffic out - To Egress Queue 1
    output wire                                                 o_queue_1_prog_full,
    input  wire                                                 i_queue_1_wr_en,
    input  wire     [EGRESS_QUEUE_WIDTH - 1 : 0]                iv_queue_1_data,

    //HPC Traffic out
    output 	wire												o_hpc_tx_pkt_valid,
    output 	wire 												o_hpc_tx_pkt_start,
    output 	wire 												o_hpc_tx_pkt_end,
    output 	wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			ov_hpc_tx_pkt_user,
    output 	wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			ov_hpc_tx_pkt_keep,
    output	wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			ov_hpc_tx_pkt_data,	
    input 	wire 												i_hpc_tx_pkt_ready,

    //ETH Traffic out、			
    output 	wire												o_eth_tx_pkt_valid,
    output 	wire 												o_eth_tx_pkt_start,
    output 	wire 												o_eth_tx_pkt_end,
    output 	wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			ov_eth_tx_pkt_user,
    output 	wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			ov_eth_tx_pkt_keep,
    output	wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			ov_eth_tx_pkt_data,
    input 	wire 												i_eth_tx_pkt_ready
);

reg                                         q_cur_queue;

wire                                        w_queue_0_rd_en;
wire                                        w_queue_0_empty;
wire    [EGRESS_QUEUE_WIDTH - 1 : 0]        wv_queue_0_dout;
wire    [6:0]                               wv_queue_0_data_count;

//SyncFIFO_288w_32d EgressQueue_0(
//`ifdef CHIP_VERSION
//    .RTSEL( rw_data[0 * 32 + 1 : 0 * 32 + 0]),
//	.WTSEL( rw_data[0 * 32 + 3 : 0 * 32 + 2]),
//	.PTSEL( rw_data[0 * 32 + 5 : 0 * 32 + 4]),
//	.VG(    rw_data[0 * 32 + 6 : 0 * 32 + 6]),
//	.VS(    rw_data[0 * 32 + 7 : 0 * 32 + 7]),
//`endif
//    .clk(clk),
//    .srst(rst),
//    .wr_en(i_queue_0_wr_en),
//    .din(iv_queue_0_data),
//    .prog_full(o_queue_0_prog_full),
//    .rd_en(w_queue_0_rd_en),
//    .dout(wv_queue_0_dout),
//    .full(),
//    .empty(w_queue_0_empty),
//    .data_count(wv_queue_0_data_count)
//);

wire                                        w_queue_1_rd_en;
wire                                        w_queue_1_empty;
wire    [EGRESS_QUEUE_WIDTH - 1 : 0]        wv_queue_1_dout;
wire    [6:0]                               wv_queue_1_data_count;

//SyncFIFO_288w_32d EgressQueue_1(
//`ifdef	CHIP_VERSION
//    .RTSEL( rw_data[1 * 32 + 1 : 1 * 32 + 0]),
//	.WTSEL( rw_data[1 * 32 + 3 : 1 * 32 + 2]),
//	.PTSEL( rw_data[1 * 32 + 5 : 1 * 32 + 4]),
//	.VG(    rw_data[1 * 32 + 6 : 1 * 32 + 6]),
//	.VS(    rw_data[1 * 32 + 7 : 1 * 32 + 7]),
//`endif

//    .clk(clk),
//    .srst(rst),
//    .wr_en(i_queue_1_wr_en),
//    .din(iv_queue_1_data),
//    .prog_full(o_queue_1_prog_full),
//    .rd_en(w_queue_1_rd_en),
//    .dout(wv_queue_1_dout),
//    .full(),
//    .empty(w_queue_1_empty),
//    .data_count(wv_queue_1_data_count)
//);

wire												        w_tx_pkt_valid;
wire                                                        w_tx_pkt_ready;
wire 												        w_tx_pkt_start;
wire 												        w_tx_pkt_end;
wire 	    [`HOST_ROUTE_USER_WIDTH - 1 : 0]			    wv_tx_pkt_user;
wire 	    [`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			    wv_tx_pkt_keep;
wire	    [`HOST_ROUTE_DATA_WIDTH - 1 : 0]			    wv_tx_pkt_data;

//HPC Traffic out
assign o_hpc_tx_pkt_valid = (iv_port_mode == `HPC_MODE) ?  w_tx_pkt_valid : 'd0;
assign o_hpc_tx_pkt_start = (iv_port_mode == `HPC_MODE) ?  w_tx_pkt_start : 'd0;
assign o_hpc_tx_pkt_end = (iv_port_mode == `HPC_MODE) ?  w_tx_pkt_end : 'd0;
assign ov_hpc_tx_pkt_user = (iv_port_mode == `HPC_MODE) ?  wv_tx_pkt_user : 'd0;
assign ov_hpc_tx_pkt_keep = (iv_port_mode == `HPC_MODE) ?  wv_tx_pkt_keep : 'd0;
assign ov_hpc_tx_pkt_data = (iv_port_mode == `HPC_MODE) ?  wv_tx_pkt_data : 'd0;

//ETH Traffic out、			
assign o_eth_tx_pkt_valid = (iv_port_mode == `ETH_MODE) ?  w_tx_pkt_valid : 'd0;
assign o_eth_tx_pkt_start = (iv_port_mode == `ETH_MODE) ?  w_tx_pkt_start : 'd0;
assign o_eth_tx_pkt_end = (iv_port_mode == `ETH_MODE) ?  w_tx_pkt_end : 'd0;
assign ov_eth_tx_pkt_user = (iv_port_mode == `ETH_MODE) ?  wv_tx_pkt_user : 'd0;
assign ov_eth_tx_pkt_keep = (iv_port_mode == `ETH_MODE) ?  wv_tx_pkt_keep : 'd0;
assign ov_eth_tx_pkt_data = (iv_port_mode == `ETH_MODE) ?  wv_tx_pkt_data : 'd0;

assign w_tx_pkt_ready = (iv_port_mode == `HPC_MODE) ? i_hpc_tx_pkt_ready : i_eth_tx_pkt_ready;

/* *_head, valid only in first beat of a packet
* | Reserved| DstDev  | SrcDev  | PktLength  | Keep     | End |  Start | Packet Body |
* | 287:277 | 276:274 | 273:271 | 270:263    | 262:258  | 257 |  256   | 255:0       |
*/
wire        [EGRESS_QUEUE_WIDTH - 1 : 0]        wv_egress_queue_out;
assign wv_egress_queue_out = (q_cur_queue == `QUEUE_0) ? wv_queue_0_dout : ((q_cur_queue == `QUEUE_1) ? wv_queue_1_dout : 'd0);

assign w_tx_pkt_valid = (q_cur_queue == `QUEUE_0) ? !w_queue_0_empty :
						(q_cur_queue == `QUEUE_1) ? !w_queue_1_empty : 
						1'd0;
assign w_tx_pkt_start = wv_egress_queue_out[256];
assign w_tx_pkt_end = wv_egress_queue_out[257];
assign wv_tx_pkt_user = ((wv_egress_queue_out[278:263]) % 128 == 0) ? (wv_egress_queue_out[278:263] / 128) : (wv_egress_queue_out[278:263] / 128 + 1);
assign wv_tx_pkt_keep = (wv_egress_queue_out[262:258] == 'd1 ) ? 32'b0000_0000_0000_0000_0000_0000_0000_0001 : 
						(wv_egress_queue_out[262:258] == 'd2 ) ? 32'b0000_0000_0000_0000_0000_0000_0000_0011 :
						(wv_egress_queue_out[262:258] == 'd3 ) ? 32'b0000_0000_0000_0000_0000_0000_0000_0111 :
						(wv_egress_queue_out[262:258] == 'd4 ) ? 32'b0000_0000_0000_0000_0000_0000_0000_1111 :
						(wv_egress_queue_out[262:258] == 'd5 ) ? 32'b0000_0000_0000_0000_0000_0000_0001_1111 :
						(wv_egress_queue_out[262:258] == 'd6 ) ? 32'b0000_0000_0000_0000_0000_0000_0011_1111 :
						(wv_egress_queue_out[262:258] == 'd7 ) ? 32'b0000_0000_0000_0000_0000_0000_0111_1111 :
						(wv_egress_queue_out[262:258] == 'd8 ) ? 32'b0000_0000_0000_0000_0000_0000_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd9 ) ? 32'b0000_0000_0000_0000_0000_0001_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd10) ? 32'b0000_0000_0000_0000_0000_0011_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd11) ? 32'b0000_0000_0000_0000_0000_0111_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd12) ? 32'b0000_0000_0000_0000_0000_1111_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd13) ? 32'b0000_0000_0000_0000_0001_1111_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd14) ? 32'b0000_0000_0000_0000_0011_1111_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd15) ? 32'b0000_0000_0000_0000_0111_1111_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd16) ? 32'b0000_0000_0000_0000_1111_1111_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd17) ? 32'b0000_0000_0000_0001_1111_1111_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd18) ? 32'b0000_0000_0000_0011_1111_1111_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd19) ? 32'b0000_0000_0000_0111_1111_1111_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd20) ? 32'b0000_0000_0000_1111_1111_1111_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd21) ? 32'b0000_0000_0001_1111_1111_1111_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd22) ? 32'b0000_0000_0011_1111_1111_1111_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd23) ? 32'b0000_0000_0111_1111_1111_1111_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd24) ? 32'b0000_0000_1111_1111_1111_1111_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd25) ? 32'b0000_0001_1111_1111_1111_1111_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd26) ? 32'b0000_0011_1111_1111_1111_1111_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd27) ? 32'b0000_0111_1111_1111_1111_1111_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd28) ? 32'b0000_1111_1111_1111_1111_1111_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd29) ? 32'b0001_1111_1111_1111_1111_1111_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd30) ? 32'b0011_1111_1111_1111_1111_1111_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd31) ? 32'b0111_1111_1111_1111_1111_1111_1111_1111 :
						(wv_egress_queue_out[262:258] == 'd0 ) ? 32'b1111_1111_1111_1111_1111_1111_1111_1111 : 'd0;

assign wv_tx_pkt_data = wv_egress_queue_out[255:0];

assign w_queue_0_rd_en = (q_cur_queue == `QUEUE_0) && !w_queue_0_empty && w_tx_pkt_ready;
assign w_queue_1_rd_en = (q_cur_queue == `QUEUE_1) && !w_queue_1_empty && w_tx_pkt_ready;

//-- q_cur_queue --
always @(posedge clk or posedge rst) begin
    if(rst) begin
       q_cur_queue <= `IDLE; 
    end
    else if(q_cur_queue == `IDLE && !w_queue_0_empty) begin
        q_cur_queue <= `QUEUE_0;
    end
    else if(q_cur_queue == `IDLE && !w_queue_1_empty) begin
        q_cur_queue <= `QUEUE_1;
    end
    else if(q_cur_queue == `QUEUE_0 && w_tx_pkt_end && w_tx_pkt_ready && !w_queue_1_empty) begin
        q_cur_queue <= `QUEUE_1;
    end
    else if(q_cur_queue == `QUEUE_0 && w_tx_pkt_end && w_tx_pkt_ready && w_queue_1_empty && wv_queue_0_data_count > 'd1) begin
        q_cur_queue <= `QUEUE_0;
    end
    else if(q_cur_queue == `QUEUE_0 && w_tx_pkt_end && w_tx_pkt_ready && w_queue_1_empty && wv_queue_0_data_count == 'd1) begin
        q_cur_queue <= `IDLE;
    end
    else if(q_cur_queue == `QUEUE_1 && w_tx_pkt_end && w_tx_pkt_ready && !w_queue_0_empty) begin
        q_cur_queue <= `QUEUE_0;
    end
    else if(q_cur_queue == `QUEUE_1 && w_tx_pkt_end && w_tx_pkt_ready && w_queue_0_empty && wv_queue_1_data_count > 'd1) begin
        q_cur_queue <= `QUEUE_1;
    end
    else if(q_cur_queue == `QUEUE_1 && w_tx_pkt_end && w_tx_pkt_ready && w_queue_0_empty && wv_queue_1_data_count == 'd1) begin
        q_cur_queue <= `IDLE;
    end
    else begin
        q_cur_queue <= q_cur_queue;
    end
end

endmodule 
