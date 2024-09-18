`timescale 1ns / 1ps

`include "route_params_def.vh"
`ifndef FPGA_VERSION
`define CHIP_VERSION
`endif

`define     QUEUE_0         2'b00
`define     QUEUE_1         2'b01
`define     IDLE            2'b11

module P2PPortMux #(
    parameter       RW_REG_NUM          =   2,

    parameter       EGRESS_QUEUE_WIDTH  =   288,
    parameter       SRC_DEV_WIDTH       =   3,
    parameter       DST_DEV_WIDTH       =   3,
    parameter       LENGTH_WIDTH        =   7,
    parameter       START_WIDTH         =   1,
    parameter       END_WIDTH           =   1,

    parameter       C_DATA_WIDTH                        = 256,         // RX/TX interface data width

    // defined for pcie interface
    parameter       DMA_HEAD_WIDTH                 = 128,
    parameter       UPPER_HEAD_WIDTH               = 64, 
    parameter       DOWN_HEAD_WIDTH                = 64
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

    /* *_head, valid only in first beat of a packet
     * | Reserved | dst_dev | src_dev | Reserved | Byte length |
     * |  63:35   |  37:35  |  34:32  |  31:16   |    15:0     |
     */
    output  wire                                                p2p_tx_valid,     
    output  wire                                                p2p_tx_last,     
    output  wire    [C_DATA_WIDTH     - 1 : 0] 	                p2p_tx_data, 
    output  wire    [UPPER_HEAD_WIDTH - 1 : 0] 	                p2p_tx_head,
    input 	wire                                                p2p_tx_ready
    /* --------p2p forward up channel{end}-------- */
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
//`ifdef CHIP_VERSION
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


/*
* | Reserved| DstDev  | SrcDev  | PktLength  | Keep     | End |  Start | Packet Body |
* | 287:285 | 284:282 | 281:279 | 278:263    | 262:258  | 257 |  256   | 255:0       |
*/
/*
     * | Reserved | dst_dev | src_dev | Reserved | Byte length |
     * |  63:35   |  37:35  |  34:32  |  31:16   |    15:0     |
*/

wire        [EGRESS_QUEUE_WIDTH - 1 : 0]        wv_egress_queue_out;
assign wv_egress_queue_out = (q_cur_queue == `QUEUE_0) ? wv_queue_0_dout : ((q_cur_queue == `QUEUE_1) ? wv_queue_1_dout : 'd0);

assign p2p_tx_valid = (q_cur_queue == `QUEUE_0) ? !w_queue_0_empty : ((q_cur_queue == `QUEUE_1) ? !w_queue_1_empty : 'd0); 
assign p2p_tx_last = wv_egress_queue_out[257];
assign p2p_tx_data = wv_egress_queue_out[255:0];
assign p2p_tx_head = {28'd0, wv_egress_queue_out[284:282], wv_egress_queue_out[281:279], 16'd0, wv_egress_queue_out[278:263]};


assign w_queue_0_rd_en = (q_cur_queue == `QUEUE_0) && !w_queue_0_empty && p2p_tx_ready;
assign w_queue_1_rd_en = (q_cur_queue == `QUEUE_1) && !w_queue_1_empty && p2p_tx_ready;

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
    else if(q_cur_queue == `QUEUE_0 && p2p_tx_last && p2p_tx_ready && !w_queue_1_empty) begin
        q_cur_queue <= `QUEUE_1;
    end
    else if(q_cur_queue == `QUEUE_0 && p2p_tx_last && p2p_tx_ready && w_queue_1_empty && wv_queue_0_data_count > 'd1) begin
        q_cur_queue <= `QUEUE_0;
    end
    else if(q_cur_queue == `QUEUE_0 && p2p_tx_last && p2p_tx_ready && w_queue_1_empty && wv_queue_0_data_count == 'd1) begin
        q_cur_queue <= `IDLE;
    end
    else if(q_cur_queue == `QUEUE_1 && p2p_tx_last && p2p_tx_ready && !w_queue_0_empty) begin
        q_cur_queue <= `QUEUE_0;
    end
    else if(q_cur_queue == `QUEUE_1 && p2p_tx_last && p2p_tx_ready && w_queue_0_empty && wv_queue_1_data_count > 'd1) begin
        q_cur_queue <= `QUEUE_1;
    end
    else if(q_cur_queue == `QUEUE_1 && p2p_tx_last && p2p_tx_ready && w_queue_0_empty && wv_queue_1_data_count == 'd1) begin
        q_cur_queue <= `IDLE;
    end
    else begin
        q_cur_queue <= q_cur_queue;
    end
end

endmodule 
