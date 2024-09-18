`timescale 1ns / 1ps

`include "route_params_def.vh"
`include "ib_constant_def_h.vh"
`include "chip_include_rdma.vh"

module Route #(
    parameter       RW_REG_NUM          =   2,
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
    input 	wire												i_hpc_pkt_valid,
    input 	wire 												i_hpc_pkt_start,
    input 	wire 												i_hpc_pkt_end,
    input 	wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			iv_hpc_pkt_user,
    input 	wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			iv_hpc_pkt_keep,
    input	wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			iv_hpc_pkt_data,	
    output 	wire 												o_hpc_pkt_ready,

    //Eth Traffic in
    input 	wire												i_eth_pkt_valid,
    input 	wire 												i_eth_pkt_start,
    input 	wire 												i_eth_pkt_end,
    input 	wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			iv_eth_pkt_user,
    input 	wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			iv_eth_pkt_keep,
    input	wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			iv_eth_pkt_data,	
    output 	wire 												o_eth_pkt_ready,

    //Traffic out - To Egress Queue 0			 
    input   wire                                                i_queue_0_prog_full,
    output  wire                                                o_queue_0_wr_en,
    output  wire    [EGRESS_QUEUE_WIDTH - 1 : 0]                ov_queue_0_data,

    //Traffic out - To Egress Queue 1
    input   wire                                                i_queue_1_prog_full,
    output  wire                                                o_queue_1_wr_en,
    output  wire    [EGRESS_QUEUE_WIDTH - 1 : 0]                ov_queue_1_data
);
/* --------Egress Queue Format{begin}-------- */
/*
* | Reserved| DstDev  | SrcDev  | PktLength  | Keep     | End |  Start | Packet Body |
* | 287:285 | 284:282 | 281:279 | 278:263    | 262:258  | 257 |  256   | 255:0       |
*/
/* --------Egress Queue Format{begin}-------- */

reg                                                q_queue_0_wr_en;
reg    [`HOST_ROUTE_DATA_WIDTH - 1 : 0]            qv_queue_0_data;

reg                                                q_queue_1_wr_en;
reg    [`HOST_ROUTE_DATA_WIDTH - 1 : 0]            qv_queue_1_data;

reg 											                                                            q_fdb_wea;
reg 		[`TABLE_DEPTH_LOG_2 - 1 : 0]			                                                        qv_fdb_addra;
reg 		[`HIGHER_ETH_ADDR_WIDTH + `VLAN_ID_WIDTH + `PORT_INDEX_WIDTH + `ENTRY_VALID_WIDTH - 1 : 0]	    qv_fdb_dina;
reg 		[`TABLE_DEPTH_LOG_2 - 1 : 0]			                                                        qv_fdb_addrb;
reg 		[`TABLE_DEPTH_LOG_2 - 1 : 0]			                                                        qv_fdb_addrb_diff;
wire 		[`HIGHER_ETH_ADDR_WIDTH + `VLAN_ID_WIDTH + `PORT_INDEX_WIDTH + `ENTRY_VALID_WIDTH - 1 : 0]	    wv_fdb_doutb;

wire 		[`HPC_ADDR_WIDTH - 1 : 0]			wv_dlid;
wire 		[`ETH_ADDR_WIDTH - 1 : 0]			wv_dmac;

wire 		[`HIGHER_HPC_ADDR_WIDTH - 1 : 0]	wv_higher_dlid;
wire 		[`HIGHER_ETH_ADDR_WIDTH - 1 : 0]	wv_higher_dmac;
wire 		[`HIGHER_HPC_ADDR_WIDTH - 1 : 0]	wv_entry_hpc_addr;
wire 		[`HIGHER_ETH_ADDR_WIDTH - 1 : 0]	wv_entry_eth_addr;
wire 		[`PORT_INDEX_WIDTH - 1 : 0]			wv_entry_port_index;

wire												w_pkt_valid;
wire 												w_pkt_start;
wire 												w_pkt_end;
//wire 	[`HOST_ROUTE_USER_WIDTH - 1 : 0]			wv_pkt_user;

wire 												w_entry_valid;


reg     [`INNER_USER_WIDTH - 1 : 0]                 qv_pkt_user;
reg     [`INNER_USER_WIDTH - 1 : 0]                 qv_pkt_user_diff;
wire 	[`HOST_ROUTE_KEEP_WIDTH - 1 : 0]			wv_pkt_keep;
wire	[`HOST_ROUTE_DATA_WIDTH - 1 : 0]			wv_pkt_data;	

assign w_pkt_valid = (iv_port_mode == `HPC_MODE) ? i_hpc_pkt_valid : i_eth_pkt_valid;
assign w_pkt_start = (iv_port_mode == `HPC_MODE) ? i_hpc_pkt_start : i_eth_pkt_start;
assign w_pkt_end = (iv_port_mode == `HPC_MODE) ? i_hpc_pkt_end : i_eth_pkt_end;

assign wv_pkt_keep = (iv_port_mode == `HPC_MODE) ? iv_hpc_pkt_keep : iv_eth_pkt_keep;
assign wv_pkt_data = (iv_port_mode == `HPC_MODE) ? iv_hpc_pkt_data : iv_eth_pkt_data;

wire        [15:0]          wv_eth_type;
wire                        w_vlan_exists;

assign w_vlan_exists = (iv_port_mode == `ETH_MODE) && (iv_eth_pkt_data[96 + 16 - 1 : 96] == `TPID_VLAN);
assign wv_eth_type = (w_vlan_exists ? iv_eth_pkt_data[96 + 32 + 16 - 1 : 96 + 32]
                                                                    : iv_eth_pkt_data[96 + 16 - 1 : 96]);

reg                     [15:0]      qv_transport_pkt_len;
wire                    [15:0]      wv_payload_len;
wire                    [7:0]       wv_opcode;

assign wv_payload_len = {iv_hpc_pkt_data[94 + 64 : 88 + 64], iv_hpc_pkt_data[61 + 64 : 56 + 64]};
assign wv_opcode = iv_hpc_pkt_data[31 + 64 : 24 + 64];

//-- qv_transport_pkt_len --
always @(*) begin
    case(wv_opcode[4:0])
        `SEND_FIRST:                qv_transport_pkt_len = wv_payload_len + 14'd12;
        `SEND_MIDDLE:               qv_transport_pkt_len = wv_payload_len + 14'd12;
        `SEND_LAST:                 qv_transport_pkt_len = wv_payload_len + 14'd12;
        `SEND_LAST_WITH_IMM:        qv_transport_pkt_len = wv_payload_len + 14'd16;
        `SEND_ONLY:                 qv_transport_pkt_len = wv_payload_len + 14'd12 + (wv_opcode[7:5] == `UD ? 14'd16 : 14'd0);
        `SEND_ONLY_WITH_IMM:        qv_transport_pkt_len = wv_payload_len + 14'd16 + (wv_opcode[7:5] == `UD ? 14'd16 : 14'd0);
        `RDMA_WRITE_FIRST:          qv_transport_pkt_len = wv_payload_len + 14'd28;
        `RDMA_WRITE_MIDDLE:         qv_transport_pkt_len = wv_payload_len + 14'd12;
        `RDMA_WRITE_LAST:           qv_transport_pkt_len = wv_payload_len + 14'd12;
        `RDMA_WRITE_ONLY:           qv_transport_pkt_len = wv_payload_len + 14'd28;
        `RDMA_WRITE_LAST_WITH_IMM:  qv_transport_pkt_len = wv_payload_len + 14'd16;
        `RDMA_WRITE_ONLY_WITH_IMM:  qv_transport_pkt_len = wv_payload_len + 14'd32;
        `RDMA_READ_REQUEST:         qv_transport_pkt_len = 14'd28;
        `FETCH_AND_ADD:             qv_transport_pkt_len = 14'd40;
        `CMP_AND_SWAP:              qv_transport_pkt_len = 14'd40;
        `RDMA_READ_RESPONSE_FIRST:  qv_transport_pkt_len = wv_payload_len + 14'd16;
        `RDMA_READ_RESPONSE_MIDDLE: qv_transport_pkt_len = wv_payload_len + 14'd12;
        `RDMA_READ_RESPONSE_LAST:   qv_transport_pkt_len = wv_payload_len + 14'd16;
        `RDMA_READ_RESPONSE_ONLY:   qv_transport_pkt_len = wv_payload_len + 14'd16;
        `ACKNOWLEDGE:               qv_transport_pkt_len = 14'd16;
        default:                    qv_transport_pkt_len = 14'd0;
    endcase
end

//-- qv_pkt_user --
always @(*) begin
    if(rst) begin
        qv_pkt_user = 'd0;
    end
    else if(iv_port_mode == `HPC_MODE && i_hpc_pkt_valid && i_hpc_pkt_start) begin
        qv_pkt_user = qv_transport_pkt_len;
    end
    else if(iv_port_mode == `ETH_MODE && i_eth_pkt_valid && i_eth_pkt_start) begin
        if(wv_eth_type == `TYPE_ARP) begin
            qv_pkt_user = 16'd60;
        end
        else if(!w_vlan_exists && wv_eth_type == `TYPE_IPV4) begin
            qv_pkt_user = iv_eth_pkt_data[143:128];
        end
        else if(w_vlan_exists && wv_eth_type == `TYPE_IPV4) begin
            qv_pkt_user = iv_eth_pkt_data[143 + 32 : 128 + 32];
        end
        else if(!w_vlan_exists && wv_eth_type == `TYPE_IPV6) begin
            qv_pkt_user = 40 + iv_eth_pkt_data[143 + 32 : 128 + 32];
        end
        else if(w_vlan_exists && wv_eth_type == `TYPE_IPV6) begin
            qv_pkt_user = iv_eth_pkt_data[143 + 32 + 32 : 128 + 32 + 32];
        end
        else begin
            qv_pkt_user = iv_eth_pkt_user * 128;
        end
    end
    else begin
        qv_pkt_user = qv_pkt_user_diff;
    end
end

//-- qv_pkt_user_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_pkt_user_diff <= 'd0;
    end 
    else begin
        qv_pkt_user_diff <= qv_pkt_user;
    end
end 

assign o_queue_0_wr_en = q_queue_0_wr_en;
assign ov_queue_0_data = qv_queue_0_data;

assign o_queue_1_wr_en = q_queue_1_wr_en;
assign ov_queue_1_data = qv_queue_1_data;

assign wv_dlid = wv_pkt_data[15:0];
assign wv_dmac = wv_pkt_data[47:0];

assign wv_higher_dlid = wv_dlid[`HPC_ADDR_WIDTH - 1 : `HPC_ADDR_WIDTH - `HIGHER_HPC_ADDR_WIDTH];
assign wv_higher_dmac = wv_dmac[`ETH_ADDR_WIDTH - 1 : `ETH_ADDR_WIDTH - `HIGHER_ETH_ADDR_WIDTH];
assign wv_entry_hpc_addr = wv_fdb_doutb[`HIGHER_HPC_ADDR_POS_END : `HIGHER_HPC_ADDR_POS_START];
assign wv_entry_eth_addr = wv_fdb_doutb[`HIGHER_ETH_ADDR_POS_END : `HIGHER_ETH_ADDR_POS_START];
assign w_entry_valid = wv_fdb_doutb[`ENTRY_VALID_POS];

assign init_rw_data = 'd0;

//BRAM_SDP_53w_4096d ForwardingDataBase (
//`ifdef CHIP_VERSION
//    .RTSEL( rw_data[0 * 32 + 1 : 0 * 32 + 0]),
//	.WTSEL( rw_data[0 * 32 + 3 : 0 * 32 + 2]),
//	.PTSEL( rw_data[0 * 32 + 5 : 0 * 32 + 4]),
//	.VG(    rw_data[0 * 32 + 6 : 0 * 32 + 6]),
//	.VS(    rw_data[0 * 32 + 7 : 0 * 32 + 7]),
//`endif
//  .clka(clk),    // input wire clka
//  .ena(1'b1),      // input wire ena
//  .wea(q_fdb_wea),      // input wire [0 : 0] wea
//  .addra(qv_fdb_addra),  // input wire [11 : 0] addra
//  .dina(qv_fdb_dina),    // input wire [52 : 0] dina
//  .clkb(clk),    // input wire clkb
//  .enb(1'b1),      // input wire enb
//  .addrb(qv_fdb_addrb),  // input wire [11 : 0] addrb
//  .doutb(wv_fdb_doutb)  // output wire [52 : 0] doutb
//);

//TODO - Left for Cfg
//-- q_fdb_wea --
//-- qv_fdb_addra --
//-- qv_fdb_dina --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_fdb_wea <= 'd0;
        qv_fdb_addra <= 'd0;
        qv_fdb_dina <= 'd0;
    end 
    else begin
        q_fdb_wea <= 'd0;
        qv_fdb_addra <= 'd0;
        qv_fdb_dina <= 'd0;       
    end
end

//-- qv_fdb_addrb -- 
always @(*) begin
    if(rst) begin
        qv_fdb_addrb = 'd0;
    end 
    else if((iv_port_mode == `HPC_MODE) && i_hpc_pkt_valid) begin
        qv_fdb_addrb = wv_dlid[11:0];
    end
    else if((iv_port_mode == `ETH_MODE) && i_eth_pkt_valid) begin
        qv_fdb_addrb = wv_dlid[11:0];
    end
    else begin
        qv_fdb_addrb = qv_fdb_addrb_diff;
    end
end

//-- qv_fdb_addrb_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_fdb_addrb_diff <= 'd0;
    end 
    else begin
        qv_fdb_addrb_diff <= qv_fdb_addrb;
    end
end 

reg             [16 + 32 + 1 + 1 + 256 - 1 : 0]                  qv_stage_buffer;  
reg                                                             q_buffer_valid;

wire            [4 : 0]                                         wv_inner_keep;
assign wv_inner_keep =  (wv_pkt_keep == 32'b0000_0000_0000_0000_0000_0000_0000_0001) ? 'd1 :
						(wv_pkt_keep == 32'b0000_0000_0000_0000_0000_0000_0000_0011) ? 'd2 :
						(wv_pkt_keep == 32'b0000_0000_0000_0000_0000_0000_0000_0111) ? 'd3 :
						(wv_pkt_keep == 32'b0000_0000_0000_0000_0000_0000_0000_1111) ? 'd4 :
						(wv_pkt_keep == 32'b0000_0000_0000_0000_0000_0000_0001_1111) ? 'd5 :
						(wv_pkt_keep == 32'b0000_0000_0000_0000_0000_0000_0011_1111) ? 'd6 :
						(wv_pkt_keep == 32'b0000_0000_0000_0000_0000_0000_0111_1111) ? 'd7 :
						(wv_pkt_keep == 32'b0000_0000_0000_0000_0000_0000_1111_1111) ? 'd8 :
						(wv_pkt_keep == 32'b0000_0000_0000_0000_0000_0001_1111_1111) ? 'd9 :
						(wv_pkt_keep == 32'b0000_0000_0000_0000_0000_0011_1111_1111) ? 'd10 :
						(wv_pkt_keep == 32'b0000_0000_0000_0000_0000_0111_1111_1111) ? 'd11 :
						(wv_pkt_keep == 32'b0000_0000_0000_0000_0000_1111_1111_1111) ? 'd12 :
						(wv_pkt_keep == 32'b0000_0000_0000_0000_0001_1111_1111_1111) ? 'd13 :
						(wv_pkt_keep == 32'b0000_0000_0000_0000_0011_1111_1111_1111) ? 'd14 :
						(wv_pkt_keep == 32'b0000_0000_0000_0000_0111_1111_1111_1111) ? 'd15 :
						(wv_pkt_keep == 32'b0000_0000_0000_0000_1111_1111_1111_1111) ? 'd16 :
						(wv_pkt_keep == 32'b0000_0000_0000_0001_1111_1111_1111_1111) ? 'd17 :
						(wv_pkt_keep == 32'b0000_0000_0000_0011_1111_1111_1111_1111) ? 'd18 :
						(wv_pkt_keep == 32'b0000_0000_0000_0111_1111_1111_1111_1111) ? 'd19 :
						(wv_pkt_keep == 32'b0000_0000_0000_1111_1111_1111_1111_1111) ? 'd20 :
						(wv_pkt_keep == 32'b0000_0000_0001_1111_1111_1111_1111_1111) ? 'd21 :
						(wv_pkt_keep == 32'b0000_0000_0011_1111_1111_1111_1111_1111) ? 'd22 :
						(wv_pkt_keep == 32'b0000_0000_0111_1111_1111_1111_1111_1111) ? 'd23 :
						(wv_pkt_keep == 32'b0000_0000_1111_1111_1111_1111_1111_1111) ? 'd24 :
						(wv_pkt_keep == 32'b0000_0001_1111_1111_1111_1111_1111_1111) ? 'd25 :
						(wv_pkt_keep == 32'b0000_0011_1111_1111_1111_1111_1111_1111) ? 'd26 :
						(wv_pkt_keep == 32'b0000_0111_1111_1111_1111_1111_1111_1111) ? 'd27 :
						(wv_pkt_keep == 32'b0000_1111_1111_1111_1111_1111_1111_1111) ? 'd28 :
						(wv_pkt_keep == 32'b0001_1111_1111_1111_1111_1111_1111_1111) ? 'd29 :
						(wv_pkt_keep == 32'b0011_1111_1111_1111_1111_1111_1111_1111) ? 'd30 :
						(wv_pkt_keep == 32'b0111_1111_1111_1111_1111_1111_1111_1111) ? 'd31 :
						(wv_pkt_keep == 32'b1111_1111_1111_1111_1111_1111_1111_1111) ? 'd0 :
						(wv_pkt_keep == 32'b0000_0000_0000_0000_0000_0000_0000_0000) ? 'd0 : 'd0;

wire                    w_available_route;
assign w_available_route = w_entry_valid && (((iv_port_mode == `HPC_MODE) && (wv_higher_dlid == wv_entry_hpc_addr)) || 
                            ((iv_port_mode == `ETH_MODE) && (wv_higher_dmac == wv_entry_eth_addr))); 

wire        [2:0]               wv_src_dev;
wire        [2:0]               wv_dst_dev;

//TODO :
assign wv_entry_port_index = 'd0;

assign wv_dst_dev = wv_entry_port_index;
assign wv_src_dev = iv_dev_id;

//Length + Keep + End + Start + Data
//-- qv_stage_buffer --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_stage_buffer <= 'd0;
    end
    else if(w_pkt_valid && !i_queue_0_prog_full && !i_queue_1_prog_full) begin
        qv_stage_buffer <= {qv_pkt_user, wv_inner_keep, w_pkt_end, w_pkt_start, wv_pkt_data};
    end 
    else begin
        qv_stage_buffer <= 'd0;
    end
end

//-- q_buffer_valid --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_buffer_valid <= 'd0;
    end 
    else if(w_pkt_valid && !i_queue_0_prog_full && !i_queue_1_prog_full) begin
        q_buffer_valid <= 'd1;
    end
    else begin
        q_buffer_valid <= 'd0;
    end
end 

//-- q_queue_0_wr_en --
//-- qv_queue_0_data --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_queue_0_wr_en <= 'd0;
        qv_queue_0_data <= 'd0;
    end 
    else if(q_buffer_valid && (wv_src_dev == wv_dst_dev) && w_available_route) begin
        q_queue_0_wr_en <= 'd1;
        qv_queue_0_data <= {wv_dst_dev, wv_src_dev, qv_stage_buffer};        
    end
    else begin
        q_queue_0_wr_en <= 'd0;
        qv_queue_0_data <= 'd0;
    end
end

//-- q_queue_1_wr_en --
//-- qv_queue_1_data --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_queue_1_wr_en <= 'd0;
        qv_queue_1_data <= 'd0;
    end 
    else if(q_buffer_valid && (wv_src_dev != wv_dst_dev) && w_available_route) begin
        q_queue_1_wr_en <= 'd1;
        qv_queue_1_data <= {wv_dst_dev, wv_src_dev, qv_stage_buffer};        
    end
    else begin
        q_queue_1_wr_en <= 'd0;
        qv_queue_1_data <= 'd0;
    end
end

assign o_hpc_pkt_ready = (iv_port_mode == `HPC_MODE) && !i_queue_0_prog_full && !i_queue_1_prog_full;
assign o_eth_pkt_ready = (iv_port_mode == `ETH_MODE) && !i_queue_0_prog_full && !i_queue_1_prog_full;

endmodule 
