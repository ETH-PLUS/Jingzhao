`timescale 1ns / 1ps

`include "route_params_def.vh"
`ifndef FPGA_VERSION
`define CHIP_VERSION
`endif

module FormatTrans #(
    parameter       C_DATA_WIDTH                        = 256,         // RX/TX interface data width
    parameter       EGRESS_QUEUE_WIDTH  =   288,
    parameter          DMA_HEAD_WIDTH                 = 128      ,
    parameter          UPPER_HEAD_WIDTH               = 64 , 
    parameter          DOWN_HEAD_WIDTH                = 64 ,
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

    input 	wire    [`PORT_MODE_WIDTH - 1 : 0]					iv_port_mode,
    input   wire    [2:0]                                       iv_dev_id,

    /* --------p2p forward down channel{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved | dst_dev | src_dev | Reserved | Byte length |
     * |  63:35   |  37:35  |  34:32  |  31:16   |    15:0     |
     */
    input wire      [1                - 1 : 0] 		            p2p_rx_valid,     
    input wire      [1                - 1 : 0] 		            p2p_rx_last,     
    input wire      [C_DATA_WIDTH     - 1 : 0] 		            p2p_rx_data, 
    input wire      [DOWN_HEAD_WIDTH  - 1 : 0] 		            p2p_rx_head,
    output wire     [1                - 1 : 0] 		            p2p_rx_ready, 
    /* --------p2p forward down channel{end}-------- */

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

//TODO :
assign p2p_rx_ready = 'd1;

wire                                                            w_tx_pkt_ready;
assign w_tx_pkt_ready = (iv_port_mode == `HPC_MODE) ? i_hpc_tx_pkt_ready : ((iv_port_mode == `ETH_MODE) ? i_eth_tx_pkt_ready : i_eth_tx_pkt_ready); 

reg                                                            q_first_flit;
//-- q_first_flit --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_first_flit <= 'd1;
    end 
    else if(p2p_rx_valid && w_tx_pkt_ready && q_first_flit == 1) begin
        q_first_flit <= 0;
    end
    else if(p2p_rx_valid && w_tx_pkt_ready && p2p_rx_last) begin
        q_first_flit <= 1;
    end
    else begin
        q_first_flit <= q_first_flit;
    end
end 

reg                 [15:0]                      qv_left_length;
reg                 [15:0]                      qv_left_length_diff;
reg                 [15:0]                      qv_total_length;
reg                 [15:0]                      qv_total_length_diff;

always @(*) begin
    if(rst) begin
        qv_left_length = 'd0;
    end
    else if(q_first_flit && p2p_rx_valid) begin
        qv_left_length = p2p_rx_head[15:0];
    end
    else if(p2p_rx_valid && w_tx_pkt_ready) begin
        if(qv_left_length_diff > 32) begin
            qv_left_length = qv_left_length_diff - 32;
        end
        else begin
            qv_left_length = 0;
        end
    end
    else begin
        qv_left_length = qv_left_length_diff;
    end
end

always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_left_length_diff <= 'd0;
    end
    else begin
        qv_left_length_diff <= qv_left_length;
    end 
end

always @(*) begin
    if(rst) begin
        qv_total_length = 'd0;
    end 
    else if(q_first_flit && p2p_rx_valid) begin
        qv_total_length = p2p_rx_head[15:0];
    end
    else begin
        qv_total_length = qv_total_length_diff;
    end
end

always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_total_length_diff <= 'd0;
    end
    else begin
        qv_total_length_diff <= qv_total_length;
    end 
end

assign o_hpc_tx_pkt_valid = (iv_port_mode == `HPC_MODE) ? (p2p_rx_valid && i_hpc_tx_pkt_ready) : 0; 
assign o_hpc_tx_pkt_start = (iv_port_mode == `HPC_MODE) ? q_first_flit : 0;
assign o_hpc_tx_pkt_end = (iv_port_mode == `HPC_MODE) ? p2p_rx_last : 0;
assign ov_hpc_tx_pkt_keep = (iv_port_mode == `HPC_MODE) ? (!p2p_rx_last ? 32'b1111_1111_1111_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd1 ) ? 32'b0000_0000_0000_0000_0000_0000_0000_0001 : 
                                                (qv_left_length == 'd2 ) ? 32'b0000_0000_0000_0000_0000_0000_0000_0011 :
                                                (qv_left_length == 'd3 ) ? 32'b0000_0000_0000_0000_0000_0000_0000_0111 :
                                                (qv_left_length == 'd4 ) ? 32'b0000_0000_0000_0000_0000_0000_0000_1111 :
                                                (qv_left_length == 'd5 ) ? 32'b0000_0000_0000_0000_0000_0000_0001_1111 :
                                                (qv_left_length == 'd6 ) ? 32'b0000_0000_0000_0000_0000_0000_0011_1111 :
                                                (qv_left_length == 'd7 ) ? 32'b0000_0000_0000_0000_0000_0000_0111_1111 :
                                                (qv_left_length == 'd8 ) ? 32'b0000_0000_0000_0000_0000_0000_1111_1111 :
                                                (qv_left_length == 'd9 ) ? 32'b0000_0000_0000_0000_0000_0001_1111_1111 :
                                                (qv_left_length == 'd10) ? 32'b0000_0000_0000_0000_0000_0011_1111_1111 :
                                                (qv_left_length == 'd11) ? 32'b0000_0000_0000_0000_0000_0111_1111_1111 :
                                                (qv_left_length == 'd12) ? 32'b0000_0000_0000_0000_0000_1111_1111_1111 :
                                                (qv_left_length == 'd13) ? 32'b0000_0000_0000_0000_0001_1111_1111_1111 :
                                                (qv_left_length == 'd14) ? 32'b0000_0000_0000_0000_0011_1111_1111_1111 :
                                                (qv_left_length == 'd15) ? 32'b0000_0000_0000_0000_0111_1111_1111_1111 :
                                                (qv_left_length == 'd16) ? 32'b0000_0000_0000_0000_1111_1111_1111_1111 :
                                                (qv_left_length == 'd17) ? 32'b0000_0000_0000_0001_1111_1111_1111_1111 :
                                                (qv_left_length == 'd18) ? 32'b0000_0000_0000_0011_1111_1111_1111_1111 :
                                                (qv_left_length == 'd19) ? 32'b0000_0000_0000_0111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd20) ? 32'b0000_0000_0000_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd21) ? 32'b0000_0000_0001_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd22) ? 32'b0000_0000_0011_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd23) ? 32'b0000_0000_0111_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd24) ? 32'b0000_0000_1111_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd25) ? 32'b0000_0001_1111_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd26) ? 32'b0000_0011_1111_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd27) ? 32'b0000_0111_1111_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd28) ? 32'b0000_1111_1111_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd29) ? 32'b0001_1111_1111_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd30) ? 32'b0011_1111_1111_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd31) ? 32'b0111_1111_1111_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd0 ) ? 32'b1111_1111_1111_1111_1111_1111_1111_1111 : 'd0) : 'd0;
assign ov_hpc_tx_pkt_user =  (iv_port_mode == `HPC_MODE) ? qv_total_length : 'd0;
assign ov_hpc_tx_pkt_data = (iv_port_mode == `HPC_MODE) ? p2p_rx_data : 'd0;

assign o_eth_tx_pkt_valid = (iv_port_mode == `ETH_MODE) ? (p2p_rx_valid && i_eth_tx_pkt_ready) : 0; 
assign o_eth_tx_pkt_start = (iv_port_mode == `ETH_MODE) ? q_first_flit : 0;
assign o_eth_tx_pkt_end = (iv_port_mode == `ETH_MODE) ? p2p_rx_last : 0;
assign ov_eth_tx_pkt_keep = (iv_port_mode == `ETH_MODE) ? (!p2p_rx_last ? 32'b1111_1111_1111_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd1 ) ? 32'b0000_0000_0000_0000_0000_0000_0000_0001 : 
                                                (qv_left_length == 'd2 ) ? 32'b0000_0000_0000_0000_0000_0000_0000_0011 :
                                                (qv_left_length == 'd3 ) ? 32'b0000_0000_0000_0000_0000_0000_0000_0111 :
                                                (qv_left_length == 'd4 ) ? 32'b0000_0000_0000_0000_0000_0000_0000_1111 :
                                                (qv_left_length == 'd5 ) ? 32'b0000_0000_0000_0000_0000_0000_0001_1111 :
                                                (qv_left_length == 'd6 ) ? 32'b0000_0000_0000_0000_0000_0000_0011_1111 :
                                                (qv_left_length == 'd7 ) ? 32'b0000_0000_0000_0000_0000_0000_0111_1111 :
                                                (qv_left_length == 'd8 ) ? 32'b0000_0000_0000_0000_0000_0000_1111_1111 :
                                                (qv_left_length == 'd9 ) ? 32'b0000_0000_0000_0000_0000_0001_1111_1111 :
                                                (qv_left_length == 'd10) ? 32'b0000_0000_0000_0000_0000_0011_1111_1111 :
                                                (qv_left_length == 'd11) ? 32'b0000_0000_0000_0000_0000_0111_1111_1111 :
                                                (qv_left_length == 'd12) ? 32'b0000_0000_0000_0000_0000_1111_1111_1111 :
                                                (qv_left_length == 'd13) ? 32'b0000_0000_0000_0000_0001_1111_1111_1111 :
                                                (qv_left_length == 'd14) ? 32'b0000_0000_0000_0000_0011_1111_1111_1111 :
                                                (qv_left_length == 'd15) ? 32'b0000_0000_0000_0000_0111_1111_1111_1111 :
                                                (qv_left_length == 'd16) ? 32'b0000_0000_0000_0000_1111_1111_1111_1111 :
                                                (qv_left_length == 'd17) ? 32'b0000_0000_0000_0001_1111_1111_1111_1111 :
                                                (qv_left_length == 'd18) ? 32'b0000_0000_0000_0011_1111_1111_1111_1111 :
                                                (qv_left_length == 'd19) ? 32'b0000_0000_0000_0111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd20) ? 32'b0000_0000_0000_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd21) ? 32'b0000_0000_0001_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd22) ? 32'b0000_0000_0011_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd23) ? 32'b0000_0000_0111_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd24) ? 32'b0000_0000_1111_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd25) ? 32'b0000_0001_1111_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd26) ? 32'b0000_0011_1111_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd27) ? 32'b0000_0111_1111_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd28) ? 32'b0000_1111_1111_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd29) ? 32'b0001_1111_1111_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd30) ? 32'b0011_1111_1111_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd31) ? 32'b0111_1111_1111_1111_1111_1111_1111_1111 :
                                                (qv_left_length == 'd0 ) ? 32'b1111_1111_1111_1111_1111_1111_1111_1111 : 'd0) : 'd0;
assign ov_eth_tx_pkt_user =  (iv_port_mode == `ETH_MODE) ? qv_total_length : 'd0;
assign ov_eth_tx_pkt_data = (iv_port_mode == `ETH_MODE) ? p2p_rx_data : 'd0;

endmodule 
