`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/02/24 14:22:20
// Design Name: 
// Module Name: PacketEncap
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include 	"route_params_def.vh"
`include 	"ib_constant_def_h.vh"
`include "chip_include_rdma.vh"

`define     MAPPING_TABLE_DEPTH         16

`define     MAPPING_TABLE_CFG_WEA_START     (0 * 32)
`define     MAPPING_TABLE_CFG_WEA_END       (1 * 32 - 1)
`define     MAPPING_TABLE_CFG_ADDRA_START   (1 * 32)
`define     MAPPING_TABLE_CFG_ADDRA_END     (1 * 32 + 3)
`define     MAPPING_TABLE_CFG_DINA_START    (2 * 32)
`define     MAPPING_TABLE_CFG_DINA_END      (2 * 32 + 3)
`define     MAPPING_TABLE_CFG_REB_START   (3 * 32)
`define     MAPPING_TABLE_CFG_REB_END     (4 * 32 - 1)
`define     MAPPING_TABLE_CFG_ADDRB_START   (4 * 32)
`define     MAPPING_TABLE_CFG_ADDRB_END     (4 * 32 + 3)

module PacketEncap
#(
    parameter       RW_REG_NUM      =       6,
    parameter       RO_REG_NUM      =       6
)
(
	input 	wire 		clk,
	input 	wire 		rst,



	input 	wire 		i_work_mode,

//CxtMgt
    output  wire                o_cxtmgt_cmd_wr_en,
    input   wire                i_cxtmgt_cmd_prog_full,
    output  wire    [127:0]     ov_cxtmgt_cmd_data,

    input   wire                i_cxtmgt_resp_empty,
    output  wire                o_cxtmgt_resp_rd_en,
    input   wire    [127:0]     iv_cxtmgt_resp_data,

    input   wire                i_cxtmgt_cxt_empty,
    output  wire                o_cxtmgt_cxt_rd_en,
    // input   wire    [127:0]     iv_cxtmgt_cxt_data,
    input   wire    [255:0]     iv_cxtmgt_cxt_data,

//Egress traffic from RDMAEngine
    input   wire                i_ib_pkt_empty,
    output  wire                o_ib_pkt_rd_en,
    input   wire    [255:0]     iv_ib_pkt_data, 

//Interface with Roce Subsystem
    input   wire                i_desc_prog_full,
    output  wire                o_desc_wr_en,
    output  wire    [191:0]     ov_desc_data,

    input   wire                i_eth_prog_full,
    output  wire                o_eth_wr_en,
    output  wire    [255:0]     ov_eth_data, 

    input   wire                i_hpc_prog_full,
    output  wire                o_hpc_wr_en,
    output  wire    [255:0]     ov_hpc_data,

    output  wire                o_fe_init_finish,

    input       wire    [RW_REG_NUM * 32 - 1 : 0]       rw_data,
    output      wire    [RW_REG_NUM * 32 - 1 : 0]       rw_init_data,
    output      wire    [RO_REG_NUM * 32 - 1 : 0]       ro_data,

    input    wire   [31:0]      dbg_sel,
    output   wire    [32 - 1:0]      dbg_bus
//    output   wire    [`DBG_NUM_PACKET_ENCAP * 32 - 1:0]      dbg_bus

);


reg                                             q_desc_wr_en;
reg     [191:0]                                 qv_desc_data;

reg 											q_mandatory_flag;			//Used to wait SL-to-VL mapping table out


assign o_desc_wr_en = q_desc_wr_en;
assign ov_desc_data = qv_desc_data;

reg 	[0 : 0]									q_mapping_table_wea;
reg 	[3 : 0]									qv_mapping_table_addra;
reg 	[3 : 0]									qv_mapping_table_dina;
reg 	[3 : 0]									qv_mapping_table_addrb;
wire 	[3 : 0]									wv_mapping_table_doutb;

assign rw_init_data = 160'd0;

assign ro_data = {rw_data[191:160], {28'd0, wv_mapping_table_doutb}, {28'd0, qv_mapping_table_addrb}, {28'd0, qv_mapping_table_dina},
						{28'd0, qv_mapping_table_addra}, {31'd0, q_mapping_table_wea}};

reg     [13:0]          qv_pkt_left_len;
reg     [15:0]          qv_transport_pkt_len;

reg     [7:0]           qv_opcode;
reg     [13:0]          qv_payload_len;
reg     [13:0]          qv_unwritten_len;
reg     [255:0]         qv_unwritten_data;

reg                     q_hpc_wr_en;
reg     [255:0]         qv_hpc_data;
reg                     q_eth_wr_en;
reg     [255:0]         qv_eth_data;

//reg                     q_desc_wr_en;
//reg     [191:0]         qv_desc_data;

reg                     q_ib_pkt_rd_en;

wire 		[10:0]			wv_link_pkt_len;
wire 		[15:0]			wv_link_pkt_len_byte;
reg         [10:0]          qv_link_pkt_len;

reg 				[23:0]					qv_cur_qpn;
reg 				[15:0]					qv_cur_slid;
reg 				[15:0]					qv_cur_dlid;
reg 				[47:0]					qv_cur_smac;
reg 				[47:0]					qv_cur_dmac;
reg 				[31:0]					qv_cur_sip;
reg 				[31:0]					qv_cur_dip;
reg 				[3:0]					qv_cur_sl;
reg 				[3:0]					qv_cur_vl;

wire 				[15:0]					wv_cur_slid;
wire 				[15:0]					wv_cur_dlid;
wire 				[47:0]					wv_cur_smac;
wire 				[47:0]					wv_cur_dmac;
wire 				[31:0]					wv_cur_sip;
wire 				[31:0]					wv_cur_dip;
wire 				[3:0]					wv_cur_sl;
wire 				[3:0]					wv_cur_vl;

wire 				[23:0]					wv_pkt_qpn;
reg 		q_need_fetch_cxt;

assign wv_cur_vl = wv_mapping_table_doutb;

reg             [2:0]   Encap_cur_state;
reg             [2:0]   Encap_next_state;

parameter     [2:0]     ENCAP_INIT_s = 3'd00,
                        ENCAP_IDLE_s = 3'd01,
						ENCAP_RESP_CXT_s = 3'd2,
                        ENCAP_HPC_TRANS_s = 3'd3,
                        ENCAP_ETH_DESC_s = 3'd4,
                        ENCAP_ETH_TRANS_s = 3'd5;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        Encap_cur_state <= ENCAP_INIT_s;        
    end
    else begin
        Encap_cur_state <= Encap_next_state;
    end
end

always @(posedge clk or posedge rst) begin
	if(rst) begin
		q_mandatory_flag <= 'd0;
	end 
	else if(Encap_cur_state == ENCAP_RESP_CXT_s && !i_cxtmgt_resp_empty && !i_cxtmgt_cxt_empty) begin
		q_mandatory_flag <= 'd1;
	end 
	else if(Encap_cur_state == ENCAP_IDLE_s) begin
		q_mandatory_flag <= 'd0;
	end 
	else begin
		q_mandatory_flag <= q_mandatory_flag;
	end 
end 

reg         [4:0]               qv_init_counter;
always @(posedge clk or posedge rst) begin
   if(rst) begin
       qv_init_counter <= 'd0;
   end 
   else if(Encap_cur_state == ENCAP_INIT_s && qv_init_counter < `MAPPING_TABLE_DEPTH) begin
       qv_init_counter <= qv_init_counter + 'd1;
   end
   else begin
       qv_init_counter <= qv_init_counter;
   end
end

assign o_fe_init_finish = (qv_init_counter == `MAPPING_TABLE_DEPTH);

BRAM_SDP_4w_16d SLToVLMappingTable(
    `ifdef CHIP_VERSION
	.RTSEL( rw_data[5 * 32 + 1 : 5 * 32 + 0]),
	.WTSEL( rw_data[5 * 32 + 3 : 5 * 32 + 2]),
	.PTSEL( rw_data[5 * 32 + 5 : 5 * 32 + 4]),
	.VG(    rw_data[5 * 32 + 6 : 5 * 32 + 6]),
	.VS(    rw_data[5 * 32 + 7 : 5 * 32 + 7]),
  `endif

  .clka(clk),    // input wire clka
  .ena(1'b1),      // input wire ena
  .wea(q_mapping_table_wea),      // input wire [0 : 0] wea
  .addra(qv_mapping_table_addra),  // input wire [3 : 0] addra
  .dina(qv_mapping_table_dina),    // input wire [3 : 0] dina
  .clkb(clk),    // input wire clkb
  .enb(1'b1),      // input wire enb
  .addrb(qv_mapping_table_addrb),  // input wire [3 : 0] addrb
  .doutb(wv_mapping_table_doutb)  // output wire [3 : 0] doutb
);

//TODO
always @(posedge clk or posedge rst) begin 
	if(rst) begin
		q_eth_wr_en <= 'd0;
		qv_eth_data <= 'd0;
	end 
	else if(Encap_cur_state == ENCAP_ETH_TRANS_s && !i_ib_pkt_empty && !i_eth_prog_full) begin
		q_eth_wr_en <= 'd1;
		qv_eth_data <= iv_ib_pkt_data;
	end
	else begin
		q_eth_wr_en <= 'd0;
		qv_eth_data <= qv_eth_data;
	end 
end 

always @(posedge clk or posedge rst) begin 
	if(rst) begin
		q_desc_wr_en <= 'd0;
		qv_desc_data <= 'd0;
	end 
	else if(Encap_cur_state == ENCAP_ETH_DESC_s && !i_desc_prog_full) begin
		q_desc_wr_en <= 'd1;
		//qv_desc_data <= (wv_pkt_qpn == qv_cur_qpn) ? {16'd0, qv_transport_pkt_len, qv_cur_dip, qv_cur_sip, qv_cur_dmac, qv_cur_smac} :
		//											{16'd0, qv_transport_pkt_len, wv_cur_dip, wv_cur_sip, wv_cur_dmac, wv_cur_smac};
		//qv_desc_data <= (wv_pkt_qpn == qv_cur_qpn) ? {qv_cur_dip, qv_cur_sip, qv_cur_dmac, qv_cur_smac, qv_transport_pkt_len, 12'd0, 4'b1111} :
		//											{wv_cur_dip, wv_cur_sip, wv_cur_dmac, wv_cur_smac, qv_transport_pkt_len, 12'd0, 4'b1111};
		qv_desc_data <= {wv_cur_dip, wv_cur_sip, wv_cur_dmac, wv_cur_smac, qv_transport_pkt_len, 12'd0, 4'b1111};
	end
	else begin
		q_desc_wr_en <= 'd0;
		qv_desc_data <= qv_desc_data;
	end 
end 

assign o_hpc_wr_en = q_hpc_wr_en;
assign ov_hpc_data = qv_hpc_data;
assign o_ib_pkt_rd_en = q_ib_pkt_rd_en;


assign wv_cur_slid = iv_cxtmgt_cxt_data[111:96];
assign wv_cur_dlid = (qv_opcode[7:5] == `UD) ? iv_ib_pkt_data[191:176] : iv_cxtmgt_cxt_data[159:144];
assign wv_cur_smac = iv_cxtmgt_cxt_data[143:96];
assign wv_cur_dmac = (qv_opcode[7:5] == `UD) ? iv_ib_pkt_data[223:176] : iv_cxtmgt_cxt_data[191:144];
assign wv_cur_sip = iv_cxtmgt_cxt_data[63:32];
assign wv_cur_dip = (qv_opcode[7:5] == `UD) ? iv_ib_pkt_data[175:144] : iv_cxtmgt_cxt_data[95:64];
assign wv_cur_sl = iv_cxtmgt_cxt_data[7:4];

always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_cur_qpn <= 24'hFFFFFF;
		qv_cur_slid <= 'd0;
		qv_cur_dlid <= 'd0;
		qv_cur_smac <= 'd0;
		qv_cur_dmac <= 'd0;
		qv_cur_sip <= 'd0;
		qv_cur_dip <= 'd0;
		qv_cur_sl <= 'd0;
		qv_cur_vl <= 'd0;
	end
	else if(Encap_cur_state == ENCAP_IDLE_s && !i_ib_pkt_empty && !q_need_fetch_cxt) begin
		qv_cur_qpn <= qv_cur_qpn;
		qv_cur_slid <= qv_cur_slid;
		//qv_cur_dlid <= (qv_opcode[7:5] == `UD) ? iv_ib_pkt_data[191:176] : qv_cur_dlid;
		qv_cur_dlid <= qv_cur_dlid;
		qv_cur_smac <= qv_cur_smac;
		//qv_cur_dmac <= (qv_opcode[7:5] == `UD) ? iv_ib_pkt_data[223:176] : qv_cur_dmac;
		qv_cur_dmac <= qv_cur_dmac;
		qv_cur_sip <= qv_cur_sip;
		//qv_cur_dip <= (qv_opcode[7:5] == `UD) ? iv_ib_pkt_data[175:144] : qv_cur_dip;
		qv_cur_dip <= qv_cur_dip;
		qv_cur_sl <= qv_cur_sl;
		qv_cur_vl <= wv_mapping_table_doutb;
	end 
	else if(Encap_cur_state == ENCAP_RESP_CXT_s && !i_cxtmgt_cxt_empty && !i_cxtmgt_resp_empty) begin
		qv_cur_qpn <= wv_pkt_qpn;
		qv_cur_slid <= iv_cxtmgt_cxt_data[111:96];
		qv_cur_dlid <= iv_cxtmgt_cxt_data[159:144];
		qv_cur_smac <= iv_cxtmgt_cxt_data[143:96];
		qv_cur_dmac <= iv_cxtmgt_cxt_data[191:144];
		qv_cur_sip <= iv_cxtmgt_cxt_data[63:32];
		qv_cur_dip <= iv_cxtmgt_cxt_data[95:64];
		qv_cur_sl <= iv_cxtmgt_cxt_data[7:4];
		qv_cur_vl <= wv_mapping_table_doutb;
	end 
	else begin
		qv_cur_qpn <= qv_cur_qpn;
		qv_cur_slid <= qv_cur_slid;
		qv_cur_dlid <= qv_cur_dlid;
		qv_cur_smac <= qv_cur_smac;
		qv_cur_dmac <= qv_cur_dmac;
		qv_cur_sip <= qv_cur_sip;
		qv_cur_dip <= qv_cur_dip;
		qv_cur_sl <= qv_cur_sl;
		qv_cur_vl <= 'd0;
	end 
end 


assign wv_pkt_qpn = {8'd0, iv_ib_pkt_data[15:0]}; 	//We use P_Key to indicates src qpn


always @(*) begin
	if(rst) begin
		q_need_fetch_cxt = 'd1;
	end 
	else if(Encap_cur_state == ENCAP_IDLE_s && !i_ib_pkt_empty) begin
		if(qv_opcode[7:5] == `UD) begin
			q_need_fetch_cxt = 'd1;
		end 
		else if(wv_pkt_qpn != qv_cur_qpn) begin
			q_need_fetch_cxt = 'd1;
		end 
		else begin
			q_need_fetch_cxt = 'd1;
		end 
	end 
	else begin
		q_need_fetch_cxt = 'd1;
	end 
end 

always @(*) begin
    case(Encap_cur_state)
        ENCAP_INIT_s:       if(qv_init_counter == `MAPPING_TABLE_DEPTH - 1) begin
                                Encap_next_state = ENCAP_IDLE_s; 
                            end
                            else begin
                                Encap_next_state = ENCAP_INIT_s;
                            end
        ENCAP_IDLE_s:       if(!i_ib_pkt_empty) begin
        						if(q_need_fetch_cxt && !i_cxtmgt_cmd_prog_full) begin
        							Encap_next_state = ENCAP_RESP_CXT_s;
        						end 
        						else if(!q_need_fetch_cxt) begin
        							Encap_next_state = (i_work_mode == `HPC_MODE) ? ENCAP_HPC_TRANS_s : ENCAP_ETH_DESC_s;
        						end 
        						else begin
        							Encap_next_state = ENCAP_IDLE_s;
        						end 
                            end
                            else begin
                                Encap_next_state = ENCAP_IDLE_s;
                            end
        ENCAP_RESP_CXT_s:	if(q_mandatory_flag > 0 && !i_cxtmgt_cxt_empty && !i_cxtmgt_resp_empty) begin
        						Encap_next_state = (i_work_mode == `HPC_MODE) ? ENCAP_HPC_TRANS_s : ENCAP_ETH_DESC_s;
        					end 
        					else begin
        						Encap_next_state = ENCAP_RESP_CXT_s;
        					end 
        ENCAP_HPC_TRANS_s:  if(qv_pkt_left_len > 0 && qv_unwritten_len + qv_pkt_left_len <= 32 && !i_ib_pkt_empty && !i_hpc_prog_full) begin
                                Encap_next_state = ENCAP_IDLE_s;
                            end 
                            else if(qv_pkt_left_len == 0 && qv_unwritten_len > 0 && !i_hpc_prog_full) begin
                                Encap_next_state = ENCAP_IDLE_s;
                            end
                            else begin
                                Encap_next_state = ENCAP_HPC_TRANS_s;
                            end
        ENCAP_ETH_DESC_s:	if(!i_desc_prog_full) begin
        						Encap_next_state = ENCAP_ETH_TRANS_s;
        					end 
        					else begin
        						Encap_next_state = ENCAP_ETH_DESC_s;
        					end 
        ENCAP_ETH_TRANS_s:  if(qv_pkt_left_len <= 'd32 && !i_ib_pkt_empty && !i_eth_prog_full) begin
		                        Encap_next_state = ENCAP_IDLE_s;
		                    end 
		                    else begin
		                        Encap_next_state = ENCAP_ETH_TRANS_s;
		                    end
        default:            Encap_next_state = ENCAP_IDLE_s;
    endcase
end

//-- qv_opcode -- Indicates current packet type
//-- qv_payload_len - Indicates payload length of current packet
always @(*) begin
    if (rst) begin
        qv_opcode = 'd0;
        qv_payload_len = 'd0;
    end
    else  begin
        qv_opcode = iv_ib_pkt_data[31:24];
        qv_payload_len = {iv_ib_pkt_data[94:88], iv_ib_pkt_data[61:56]};
    end
end

//-- qv_transport_pkt_len --
always @(*) begin
    case(qv_opcode[4:0])
        `SEND_FIRST:                qv_transport_pkt_len = qv_payload_len + 14'd12;
        `SEND_MIDDLE:               qv_transport_pkt_len = qv_payload_len + 14'd12;
        `SEND_LAST:                 qv_transport_pkt_len = qv_payload_len + 14'd12;
        `SEND_LAST_WITH_IMM:        qv_transport_pkt_len = qv_payload_len + 14'd16;
        `SEND_ONLY:                 qv_transport_pkt_len = qv_payload_len + 14'd12 + (qv_opcode[7:5] == `UD ? 14'd16 : 14'd0);
        `SEND_ONLY_WITH_IMM:        qv_transport_pkt_len = qv_payload_len + 14'd16 + (qv_opcode[7:5] == `UD ? 14'd16 : 14'd0);
        `RDMA_WRITE_FIRST:          qv_transport_pkt_len = qv_payload_len + 14'd28;
        `RDMA_WRITE_MIDDLE:         qv_transport_pkt_len = qv_payload_len + 14'd12;
        `RDMA_WRITE_LAST:           qv_transport_pkt_len = qv_payload_len + 14'd12;
        `RDMA_WRITE_ONLY:           qv_transport_pkt_len = qv_payload_len + 14'd28;
        `RDMA_WRITE_LAST_WITH_IMM:  qv_transport_pkt_len = qv_payload_len + 14'd16;
        `RDMA_WRITE_ONLY_WITH_IMM:  qv_transport_pkt_len = qv_payload_len + 14'd32;
        `RDMA_READ_REQUEST:         qv_transport_pkt_len = 14'd28;
        `FETCH_AND_ADD:             qv_transport_pkt_len = 14'd40;
        `CMP_AND_SWAP:              qv_transport_pkt_len = 14'd40;
        `RDMA_READ_RESPONSE_FIRST:  qv_transport_pkt_len = qv_payload_len + 14'd16;
        `RDMA_READ_RESPONSE_MIDDLE: qv_transport_pkt_len = qv_payload_len + 14'd12;
        `RDMA_READ_RESPONSE_LAST:   qv_transport_pkt_len = qv_payload_len + 14'd16;
        `RDMA_READ_RESPONSE_ONLY:   qv_transport_pkt_len = qv_payload_len + 14'd16;
        `ACKNOWLEDGE:               qv_transport_pkt_len = 14'd16;
        default:                    qv_transport_pkt_len = 14'd0;
    endcase
end

//-- qv_pkt_left_len -- Indicate how many bytes left untransferred
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_pkt_left_len <= 'd0;        
    end
    else if (Encap_cur_state == ENCAP_IDLE_s && !i_ib_pkt_empty) begin
        qv_pkt_left_len <= qv_transport_pkt_len;
    end
    else if (Encap_cur_state == ENCAP_HPC_TRANS_s && q_ib_pkt_rd_en) begin
        if(qv_pkt_left_len >= 'd32) begin
            qv_pkt_left_len <= qv_pkt_left_len - 'd32;
        end
        else begin
            qv_pkt_left_len <= 'd0;
        end
    end
    else if(Encap_cur_state == ENCAP_ETH_TRANS_s && q_ib_pkt_rd_en) begin
    	qv_pkt_left_len <= qv_pkt_left_len - 'd32;
    end 
    else begin
        qv_pkt_left_len <= qv_pkt_left_len;
    end
end

//-- qv_unwritten_len --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_unwritten_len <= 'd0;        
    end
    else if (Encap_cur_state == ENCAP_IDLE_s && !i_ib_pkt_empty) begin
        qv_unwritten_len <= `HPC_LINK_HEADER_LENGTH;   //MAC Header + 16-bit Packet Length
    end
    else if(Encap_cur_state == ENCAP_RESP_CXT_s && !i_ib_pkt_empty) begin
    	qv_unwritten_len <= `HPC_LINK_HEADER_LENGTH;
    end 
    else if (Encap_cur_state == ENCAP_HPC_TRANS_s) begin
        if(qv_pkt_left_len == 0 && qv_unwritten_len > 0 && !i_hpc_prog_full) begin
            qv_unwritten_len <= 'd0;
        end 
        else if(qv_pkt_left_len > 0 && qv_pkt_left_len + qv_unwritten_len > 32 && !i_ib_pkt_empty && !i_hpc_prog_full) begin
            if(qv_pkt_left_len >= 32) begin
                qv_unwritten_len <= qv_unwritten_len;
            end
            else begin
                qv_unwritten_len <= 'd32 - qv_pkt_left_len;
            end
        end
        else if(qv_pkt_left_len > 0 && qv_pkt_left_len + qv_unwritten_len <= 32 && !i_ib_pkt_empty && !i_hpc_prog_full) begin
            qv_unwritten_len <= 'd0;
        end
        else begin
            qv_unwritten_len <= qv_unwritten_len;
        end
    end
    else begin
        qv_unwritten_len <= qv_unwritten_len;
    end
end

//assign wv_link_pkt_len_byte = qv_transport_pkt_len + `HPC_LINK_HEADER_LENGTH + `HPC_LINK_ICRC_LENGTH;
assign wv_link_pkt_len_byte = qv_transport_pkt_len + `HPC_LINK_HEADER_LENGTH;
//assign wv_link_pkt_len = (qv_transport_pkt_len[1:0] ? qv_transport_pkt_len[15:2] + 1 : qv_transport_pkt_len[15:2]) + ((`HPC_LINK_HEADER_LENGTH + `HPC_LINK_ICRC_LENGTH)/ 4);
assign wv_link_pkt_len = (wv_link_pkt_len_byte[1:0] != 2'b00) ? (wv_link_pkt_len_byte >> 2) + 1 : wv_link_pkt_len_byte >> 2;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_link_pkt_len <= 'd0;
    end 
    else if (Encap_cur_state == ENCAP_IDLE_s && Encap_next_state == ENCAP_RESP_CXT_s) begin
        qv_link_pkt_len <= wv_link_pkt_len;
    end
    else begin
        qv_link_pkt_len <= qv_link_pkt_len;
    end
end

//-- qv_unwritten_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_unwritten_data <= 'd0;        
    end
    else if (Encap_cur_state == ENCAP_IDLE_s && Encap_next_state == ENCAP_HPC_TRANS_s) begin
        qv_unwritten_data <= {128'd0, {5'd0, wv_link_pkt_len, qv_cur_slid, qv_cur_vl, 4'd0, qv_cur_sl, 2'd0, 2'b10, (qv_opcode[7:5] != `UD) ? qv_cur_dlid : iv_ib_pkt_data[191:176]}};
    end
    else if(Encap_cur_state == ENCAP_RESP_CXT_s && Encap_next_state == ENCAP_HPC_TRANS_s) begin
    	qv_unwritten_data <= {128'd0, {5'd0, qv_link_pkt_len, wv_cur_slid, wv_cur_vl, 4'd0, wv_cur_sl, 2'd0, 2'b10, wv_cur_dlid}};
    end
    else if(Encap_cur_state == ENCAP_HPC_TRANS_s) begin
        if(qv_pkt_left_len == 0 && qv_unwritten_len > 0 && !i_hpc_prog_full) begin
            qv_unwritten_data <= 'd0;
        end 
        else if(qv_pkt_left_len > 0 && qv_pkt_left_len + qv_unwritten_len > 32 && !i_ib_pkt_empty && !i_hpc_prog_full) begin
            case(qv_unwritten_len)
                0:          qv_unwritten_data <= 'd0;
                1:          qv_unwritten_data <= {8'd0, iv_ib_pkt_data[255 : (32 -  1) * 8]};
                2:          qv_unwritten_data <= {16'd0, iv_ib_pkt_data[255 : (32 -  2) * 8]};
                3:          qv_unwritten_data <= {24'd0, iv_ib_pkt_data[255 : (32 -  3) * 8]};
                4:          qv_unwritten_data <= {32'd0, iv_ib_pkt_data[255 : (32 -  4) * 8]};
                5:          qv_unwritten_data <= {40'd0, iv_ib_pkt_data[255 : (32 -  5) * 8]};
                6:          qv_unwritten_data <= {48'd0, iv_ib_pkt_data[255 : (32 -  6) * 8]};
                7:          qv_unwritten_data <= {56'd0, iv_ib_pkt_data[255 : (32 -  7) * 8]};
                8:          qv_unwritten_data <= {64'd0, iv_ib_pkt_data[255 : (32 -  8) * 8]};
                9:          qv_unwritten_data <= {72'd0, iv_ib_pkt_data[255 : (32 -  9) * 8]};
                10:         qv_unwritten_data <= {80'd0, iv_ib_pkt_data[255 : (32 - 10) * 8]};
                11:          qv_unwritten_data <= {88'd0, iv_ib_pkt_data[255 : (32 - 11) * 8]};
                12:          qv_unwritten_data <= {96'd0, iv_ib_pkt_data[255 : (32 - 12) * 8]};
                13:          qv_unwritten_data <= {104'd0, iv_ib_pkt_data[255 : (32 - 13) * 8]};
                14:          qv_unwritten_data <= {112'd0, iv_ib_pkt_data[255 : (32 - 14) * 8]};
                15:          qv_unwritten_data <= {120'd0, iv_ib_pkt_data[255 : (32 - 15) * 8]};
                16:          qv_unwritten_data <= {128'd0, iv_ib_pkt_data[255 : (32 - 16) * 8]};
                17:          qv_unwritten_data <= {136'd0, iv_ib_pkt_data[255 : (32 - 17) * 8]};
                18:          qv_unwritten_data <= {144'd0, iv_ib_pkt_data[255 : (32 - 18) * 8]};
                19:          qv_unwritten_data <= {152'd0, iv_ib_pkt_data[255 : (32 - 19) * 8]};
                20:          qv_unwritten_data <= {160'd0, iv_ib_pkt_data[255 : (32 - 20) * 8]};
                21:          qv_unwritten_data <= {168'd0, iv_ib_pkt_data[255 : (32 - 21) * 8]};
                22:          qv_unwritten_data <= {176'd0, iv_ib_pkt_data[255 : (32 - 22) * 8]};
                23:          qv_unwritten_data <= {184'd0, iv_ib_pkt_data[255 : (32 - 23) * 8]};
                24:          qv_unwritten_data <= {192'd0, iv_ib_pkt_data[255 : (32 - 24) * 8]};
                25:          qv_unwritten_data <= {200'd0, iv_ib_pkt_data[255 : (32 - 25) * 8]};
                26:          qv_unwritten_data <= {208'd0, iv_ib_pkt_data[255 : (32 - 26) * 8]};
                27:          qv_unwritten_data <= {216'd0, iv_ib_pkt_data[255 : (32 - 27) * 8]};
                28:          qv_unwritten_data <= {224'd0, iv_ib_pkt_data[255 : (32 - 28) * 8]};
                29:          qv_unwritten_data <= {232'd0, iv_ib_pkt_data[255 : (32 - 29) * 8]};
                30:          qv_unwritten_data <= {240'd0, iv_ib_pkt_data[255 : (32 - 30) * 8]};
                31:          qv_unwritten_data <= {248'd0, iv_ib_pkt_data[255 : (32 - 31) * 8]};
                default:    qv_unwritten_data <= qv_unwritten_data;        
            endcase
        end
        else if(qv_pkt_left_len > 0 && qv_pkt_left_len + qv_unwritten_len <= 32 && !i_ib_pkt_empty && !i_hpc_prog_full) begin
            qv_unwritten_data <= 'd0;
        end
        else begin
            qv_unwritten_data <= qv_unwritten_data;
        end
    end
    else begin
        qv_unwritten_data <= qv_unwritten_data;
    end        
end

//-- q_hpc_wr_en --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_hpc_wr_en <= 'd0;        
    end
    else if (Encap_cur_state == ENCAP_HPC_TRANS_s) begin
        if(qv_pkt_left_len == 0 && qv_unwritten_len > 0 && !i_hpc_prog_full) begin
            q_hpc_wr_en <= 'd1;
        end 
        else if(qv_pkt_left_len > 0 && qv_pkt_left_len + qv_unwritten_len > 32 && !i_ib_pkt_empty && !i_hpc_prog_full) begin
            q_hpc_wr_en <= 'd1;
        end
        else if(qv_pkt_left_len > 0 && qv_pkt_left_len + qv_unwritten_len <= 32 && !i_ib_pkt_empty && !i_hpc_prog_full) begin
            q_hpc_wr_en <= 'd1;
        end
        else begin
            q_hpc_wr_en <= 'd0;
        end
    end
	else begin
		q_hpc_wr_en <= 'd0;
	end 
end

//-- qv_hpc_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_hpc_data <= 'd0;
    end
    else if (Encap_cur_state == ENCAP_HPC_TRANS_s) begin
        if(qv_pkt_left_len == 0 && qv_unwritten_len > 0 && !i_hpc_prog_full) begin
            qv_hpc_data <= qv_unwritten_data;
        end                 
        else if(qv_pkt_left_len > 0 && !i_ib_pkt_empty && !i_hpc_prog_full) begin
            case(qv_unwritten_len)
                0:          qv_hpc_data <= iv_ib_pkt_data;
                1:          qv_hpc_data <= {iv_ib_pkt_data[(32 -  1) * 8 - 1 : 0], qv_unwritten_data[8 *  1 - 1 : 0]};
                2:          qv_hpc_data <= {iv_ib_pkt_data[(32 -  2) * 8 - 1 : 0], qv_unwritten_data[8 *  2 - 1 : 0]};
                3:          qv_hpc_data <= {iv_ib_pkt_data[(32 -  3) * 8 - 1 : 0], qv_unwritten_data[8 *  3 - 1 : 0]};
                4:          qv_hpc_data <= {iv_ib_pkt_data[(32 -  4) * 8 - 1 : 0], qv_unwritten_data[8 *  4 - 1 : 0]};
                5:          qv_hpc_data <= {iv_ib_pkt_data[(32 -  5) * 8 - 1 : 0], qv_unwritten_data[8 *  5 - 1 : 0]};
                6:          qv_hpc_data <= {iv_ib_pkt_data[(32 -  6) * 8 - 1 : 0], qv_unwritten_data[8 *  6 - 1 : 0]};
                7:          qv_hpc_data <= {iv_ib_pkt_data[(32 -  7) * 8 - 1 : 0], qv_unwritten_data[8 *  7 - 1 : 0]};
                8:          qv_hpc_data <= {iv_ib_pkt_data[(32 -  8) * 8 - 1 : 0], qv_unwritten_data[8 *  8 - 1 : 0]};
                9:          qv_hpc_data <= {iv_ib_pkt_data[(32 -  9) * 8 - 1 : 0], qv_unwritten_data[8 *  9 - 1 : 0]};
                10:         qv_hpc_data <= {iv_ib_pkt_data[(32 - 10) * 8 - 1 : 0], qv_unwritten_data[8 * 10 - 1 : 0]};
                11:          qv_hpc_data <= {iv_ib_pkt_data[(32 - 11) * 8 - 1 : 0], qv_unwritten_data[8 * 11 - 1 : 0]};
                12:          qv_hpc_data <= {iv_ib_pkt_data[(32 - 12) * 8 - 1 : 0], qv_unwritten_data[8 * 12 - 1 : 0]};
                13:          qv_hpc_data <= {iv_ib_pkt_data[(32 - 13) * 8 - 1 : 0], qv_unwritten_data[8 * 13 - 1 : 0]};
                14:          qv_hpc_data <= {iv_ib_pkt_data[(32 - 14) * 8 - 1 : 0], qv_unwritten_data[8 * 14 - 1 : 0]};
                15:          qv_hpc_data <= {iv_ib_pkt_data[(32 - 15) * 8 - 1 : 0], qv_unwritten_data[8 * 15 - 1 : 0]};
                16:          qv_hpc_data <= {iv_ib_pkt_data[(32 - 16) * 8 - 1 : 0], qv_unwritten_data[8 * 16 - 1 : 0]};
                17:          qv_hpc_data <= {iv_ib_pkt_data[(32 - 17) * 8 - 1 : 0], qv_unwritten_data[8 * 17 - 1 : 0]};
                18:          qv_hpc_data <= {iv_ib_pkt_data[(32 - 18) * 8 - 1 : 0], qv_unwritten_data[8 * 18 - 1 : 0]};
                19:          qv_hpc_data <= {iv_ib_pkt_data[(32 - 19) * 8 - 1 : 0], qv_unwritten_data[8 * 19 - 1 : 0]};
                20:          qv_hpc_data <= {iv_ib_pkt_data[(32 - 20) * 8 - 1 : 0], qv_unwritten_data[8 * 20 - 1 : 0]};
                21:          qv_hpc_data <= {iv_ib_pkt_data[(32 - 21) * 8 - 1 : 0], qv_unwritten_data[8 * 21 - 1 : 0]};
                22:          qv_hpc_data <= {iv_ib_pkt_data[(32 - 22) * 8 - 1 : 0], qv_unwritten_data[8 * 22 - 1 : 0]};
                23:          qv_hpc_data <= {iv_ib_pkt_data[(32 - 23) * 8 - 1 : 0], qv_unwritten_data[8 * 23 - 1 : 0]};
                24:          qv_hpc_data <= {iv_ib_pkt_data[(32 - 24) * 8 - 1 : 0], qv_unwritten_data[8 * 24 - 1 : 0]};
                25:          qv_hpc_data <= {iv_ib_pkt_data[(32 - 25) * 8 - 1 : 0], qv_unwritten_data[8 * 25 - 1 : 0]};
                26:          qv_hpc_data <= {iv_ib_pkt_data[(32 - 26) * 8 - 1 : 0], qv_unwritten_data[8 * 26 - 1 : 0]};
                27:          qv_hpc_data <= {iv_ib_pkt_data[(32 - 27) * 8 - 1 : 0], qv_unwritten_data[8 * 27 - 1 : 0]};
                28:          qv_hpc_data <= {iv_ib_pkt_data[(32 - 28) * 8 - 1 : 0], qv_unwritten_data[8 * 28 - 1 : 0]};
                29:          qv_hpc_data <= {iv_ib_pkt_data[(32 - 29) * 8 - 1 : 0], qv_unwritten_data[8 * 29 - 1 : 0]};
                30:          qv_hpc_data <= {iv_ib_pkt_data[(32 - 30) * 8 - 1 : 0], qv_unwritten_data[8 * 30 - 1 : 0]};
                31:          qv_hpc_data <= {iv_ib_pkt_data[(32 - 31) * 8 - 1 : 0], qv_unwritten_data[8 * 31 - 1 : 0]};
                default:    qv_hpc_data <= qv_hpc_data;        
            endcase
        end 
        else begin
            qv_hpc_data <= qv_hpc_data;
        end
    end
    else begin
        qv_hpc_data <=  qv_hpc_data;
    end
end

always @(*) begin
    if (rst) begin
        q_ib_pkt_rd_en = 'd0;        
    end
    else if (Encap_cur_state == ENCAP_HPC_TRANS_s) begin
        if(qv_pkt_left_len == 0 && qv_unwritten_len > 0 && !i_hpc_prog_full) begin
            q_ib_pkt_rd_en = 'd0;
        end 
        else if(qv_pkt_left_len > 0 && !i_ib_pkt_empty && !i_hpc_prog_full) begin
            q_ib_pkt_rd_en = 'd1;
        end
        else begin
            q_ib_pkt_rd_en = 'd0;
        end
    end
    else if(Encap_cur_state == ENCAP_ETH_TRANS_s) begin
    	if(!i_ib_pkt_empty && !i_eth_prog_full) begin
    		q_ib_pkt_rd_en = 'd1;
    	end 
    	else begin
    		q_ib_pkt_rd_en = 'd0;
    	end 
    end
    else begin
        q_ib_pkt_rd_en = 'd0;
    end
end

assign o_eth_wr_en = q_eth_wr_en;
assign ov_eth_data = qv_eth_data;

reg                     q_cxtmgt_cxt_rd_en;
always @(*) begin
   if(rst) begin
       q_cxtmgt_cxt_rd_en = 'd0;
   end 
   else begin
      q_cxtmgt_cxt_rd_en = (Encap_cur_state == ENCAP_RESP_CXT_s) && (Encap_next_state != ENCAP_RESP_CXT_s); 
   end
end

reg                     q_cxtmgt_resp_rd_en;
always @(*) begin
    if(rst) begin
        q_cxtmgt_resp_rd_en = 'd0;
    end 
    else begin
        q_cxtmgt_resp_rd_en = (Encap_cur_state == ENCAP_RESP_CXT_s) && (Encap_next_state != ENCAP_RESP_CXT_s);
    end
end

assign o_cxtmgt_cxt_rd_en = q_cxtmgt_cxt_rd_en;
assign o_cxtmgt_resp_rd_en = q_cxtmgt_resp_rd_en;

reg                                 q_cxtmgt_cmd_wr_en;
reg             [127:0]             qv_cxtmgt_cmd_data;
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_cxtmgt_cmd_wr_en <= 'd0;
        qv_cxtmgt_cmd_data <= 'd0;
    end 
    else if(Encap_cur_state == ENCAP_IDLE_s && Encap_next_state == ENCAP_RESP_CXT_s) begin
        q_cxtmgt_cmd_wr_en <= 'd1;
        qv_cxtmgt_cmd_data <= {`RD_QP_CTX, `RD_ENCAP, wv_pkt_qpn, 96'h0};
    end
    else begin
        q_cxtmgt_cmd_wr_en <= 'd0;
        qv_cxtmgt_cmd_data <= qv_cxtmgt_cmd_data;
    end
end

assign o_cxtmgt_cmd_wr_en = q_cxtmgt_cmd_wr_en;
assign ov_cxtmgt_cmd_data = qv_cxtmgt_cmd_data;

//always @(posedge clk or posedge rst) begin
//    if(rst) begin
//        q_desc_wr_en <= 'd0;
//        qv_desc_data <= 'd0;
//    end
//    else if(Encap_cur_state == ENCAP_ETH_DESC_s && !i_desc_prog_full) begin
//        q_desc_wr_en <= 'd1;
//        qv_desc_data <= {qv_cur_dip, qv_cur_sip, qv_cur_dmac, qv_cur_smac, qv_transport_pkt_len, 12'd0, 4'b1111};
//    end
//end

//-- q_mapping_table_wea --
//-- qv_mapping_table_addra --
//-- qv_mapping_table_dina --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_mapping_table_wea <= 'd0;
        qv_mapping_table_addra <= 'd0;
        qv_mapping_table_dina <= 'd0;
    end 
    else if(Encap_cur_state == ENCAP_INIT_s) begin
        q_mapping_table_wea <= 'd1;
        qv_mapping_table_addra <= qv_init_counter;
        qv_mapping_table_dina <= 'd0;
    end 
    else if(rw_data[`MAPPING_TABLE_CFG_WEA_END : `MAPPING_TABLE_CFG_WEA_START] == 32'hFFFFFFFF) begin
        q_mapping_table_wea <= 'd1;
        qv_mapping_table_addra <= rw_data[`MAPPING_TABLE_CFG_ADDRA_END : `MAPPING_TABLE_CFG_ADDRA_START];
        qv_mapping_table_dina <= rw_data[`MAPPING_TABLE_CFG_DINA_END : `MAPPING_TABLE_CFG_DINA_START];
    end
    else begin
        q_mapping_table_wea <= 'd0;
        qv_mapping_table_addra <= 'd0;
        qv_mapping_table_dina <= 'd0;        
    end
end

//-- qv_mappint_table_addrb --
always @(*) begin
    if(rst) begin
        qv_mapping_table_addrb = 'd0;
    end
    else if(rw_data[`MAPPING_TABLE_CFG_REB_END : `MAPPING_TABLE_CFG_REB_START] == 32'hFFFFFFFF) begin
        qv_mapping_table_addrb = rw_data[`MAPPING_TABLE_CFG_ADDRB_END : `MAPPING_TABLE_CFG_ADDRB_START];
    end
    else begin
        qv_mapping_table_addrb = wv_cur_sl;
    end
end

/*----------------------------------- connect dbg bus -------------------------------------*/
wire   [`DBG_NUM_PACKET_ENCAP * 32 - 1 : 0]   coalesced_bus;

assign coalesced_bus = 
                        {
                            q_desc_wr_en,
                            q_hpc_wr_en,
                            q_eth_wr_en,
                            q_desc_wr_en,
                            q_ib_pkt_rd_en,
                            q_need_fetch_cxt,
                            q_cxtmgt_cxt_rd_en,
                            q_cxtmgt_resp_rd_en,
                            q_cxtmgt_cmd_wr_en,
                            qv_desc_data,
                            q_mapping_table_wea,
                            qv_mapping_table_addra,
                            qv_mapping_table_dina,
                            qv_mapping_table_addrb,
                            qv_pkt_left_len,
                            qv_transport_pkt_len,
                            qv_opcode,
                            qv_payload_len,
                            qv_unwritten_len,
                            qv_unwritten_data,
                            qv_hpc_data,
                            qv_eth_data,
                            qv_desc_data,
                            qv_link_pkt_len,
                            qv_cur_qpn,
                            qv_cur_slid,
                            qv_cur_dlid,
                            qv_cur_smac,
                            qv_cur_dmac,
                            qv_cur_sip,
                            qv_cur_dip,
                            qv_cur_sl,
                            qv_cur_vl,
                            Encap_cur_state,
                            Encap_next_state,
                            qv_init_counter,
                            qv_cxtmgt_cmd_data,
                            wv_mapping_table_doutb,
                            wv_link_pkt_len,
                            wv_link_pkt_len_byte,
                            wv_cur_slid,
                            wv_cur_dlid,
                            wv_cur_smac,
                            wv_cur_dmac,
                            wv_cur_sip,
                            wv_cur_dip,
                            wv_cur_sl,
                            wv_cur_vl,
                            wv_pkt_qpn
                        };

assign dbg_bus =    (dbg_sel == 0)  ?   coalesced_bus[32 * 1 - 1 : 32 * 0] :
                    (dbg_sel == 1)  ?   coalesced_bus[32 * 2 - 1 : 32 * 1] :
                    (dbg_sel == 2)  ?   coalesced_bus[32 * 3 - 1 : 32 * 2] :
                    (dbg_sel == 3)  ?   coalesced_bus[32 * 4 - 1 : 32 * 3] :
                    (dbg_sel == 4)  ?   coalesced_bus[32 * 5 - 1 : 32 * 4] :
                    (dbg_sel == 5)  ?   coalesced_bus[32 * 6 - 1 : 32 * 5] :
                    (dbg_sel == 6)  ?   coalesced_bus[32 * 7 - 1 : 32 * 6] :
                    (dbg_sel == 7)  ?   coalesced_bus[32 * 8 - 1 : 32 * 7] :
                    (dbg_sel == 8)  ?   coalesced_bus[32 * 9 - 1 : 32 * 8] :
                    (dbg_sel == 9)  ?   coalesced_bus[32 * 10 - 1 : 32 * 9] :
                    (dbg_sel == 10) ?   coalesced_bus[32 * 11 - 1 : 32 * 10] :
                    (dbg_sel == 11) ?   coalesced_bus[32 * 12 - 1 : 32 * 11] :
                    (dbg_sel == 12) ?   coalesced_bus[32 * 13 - 1 : 32 * 12] :
                    (dbg_sel == 13) ?   coalesced_bus[32 * 14 - 1 : 32 * 13] :
                    (dbg_sel == 14) ?   coalesced_bus[32 * 15 - 1 : 32 * 14] :
                    (dbg_sel == 15) ?   coalesced_bus[32 * 16 - 1 : 32 * 15] :
                    (dbg_sel == 16) ?   coalesced_bus[32 * 17 - 1 : 32 * 16] :
                    (dbg_sel == 17) ?   coalesced_bus[32 * 18 - 1 : 32 * 17] :
                    (dbg_sel == 18) ?   coalesced_bus[32 * 19 - 1 : 32 * 18] :
                    (dbg_sel == 19) ?   coalesced_bus[32 * 20 - 1 : 32 * 19] :
                    (dbg_sel == 20) ?   coalesced_bus[32 * 21 - 1 : 32 * 20] :
                    (dbg_sel == 21) ?   coalesced_bus[32 * 22 - 1 : 32 * 21] :
                    (dbg_sel == 22) ?   coalesced_bus[32 * 23 - 1 : 32 * 22] :
                    (dbg_sel == 23) ?   coalesced_bus[32 * 24 - 1 : 32 * 23] :
                    (dbg_sel == 24) ?   coalesced_bus[32 * 25 - 1 : 32 * 24] :
                    (dbg_sel == 25) ?   coalesced_bus[32 * 26 - 1 : 32 * 25] :
                    (dbg_sel == 26) ?   coalesced_bus[32 * 27 - 1 : 32 * 26] :
                    (dbg_sel == 27) ?   coalesced_bus[32 * 28 - 1 : 32 * 27] :
                    (dbg_sel == 28) ?   coalesced_bus[32 * 29 - 1 : 32 * 28] :
                    (dbg_sel == 29) ?   coalesced_bus[32 * 30 - 1 : 32 * 29] :
                    (dbg_sel == 30) ?   coalesced_bus[32 * 31 - 1 : 32 * 30] :
                    (dbg_sel == 31) ?   coalesced_bus[32 * 32 - 1 : 32 * 31] :
                    (dbg_sel == 32) ?   coalesced_bus[32 * 33 - 1 : 32 * 32] :
                    (dbg_sel == 33) ?   coalesced_bus[32 * 34 - 1 : 32 * 33] :
                    (dbg_sel == 34) ?   coalesced_bus[32 * 35 - 1 : 32 * 34] :
                    (dbg_sel == 35) ?   coalesced_bus[32 * 36 - 1 : 32 * 35] :
                    (dbg_sel == 36) ?   coalesced_bus[32 * 37 - 1 : 32 * 36] :
                    (dbg_sel == 37) ?   coalesced_bus[32 * 38 - 1 : 32 * 37] :
                    (dbg_sel == 38) ?   coalesced_bus[32 * 39 - 1 : 32 * 38] :
                    (dbg_sel == 39) ?   coalesced_bus[32 * 40 - 1 : 32 * 39] :
                    (dbg_sel == 40) ?   coalesced_bus[32 * 41 - 1 : 32 * 40] :
                    (dbg_sel == 41) ?   coalesced_bus[32 * 42 - 1 : 32 * 41] :
                    (dbg_sel == 42) ?   coalesced_bus[32 * 43 - 1 : 32 * 42] :
                    (dbg_sel == 43) ?   coalesced_bus[32 * 44 - 1 : 32 * 43] :
                    (dbg_sel == 44) ?   coalesced_bus[32 * 45 - 1 : 32 * 44] :
                    (dbg_sel == 45) ?   coalesced_bus[32 * 46 - 1 : 32 * 45] :
                    (dbg_sel == 46) ?   coalesced_bus[32 * 47 - 1 : 32 * 46] :
                    (dbg_sel == 47) ?   coalesced_bus[32 * 48 - 1 : 32 * 47] :
                    (dbg_sel == 48) ?   coalesced_bus[32 * 49 - 1 : 32 * 48] :
                    (dbg_sel == 49) ?   coalesced_bus[32 * 50 - 1 : 32 * 49] :
                    (dbg_sel == 50) ?   coalesced_bus[32 * 51 - 1 : 32 * 50] :
                    (dbg_sel == 51) ?   coalesced_bus[32 * 52 - 1 : 32 * 51] :
                    (dbg_sel == 52) ?   coalesced_bus[32 * 53 - 1 : 32 * 52] :
                    (dbg_sel == 53) ?   coalesced_bus[32 * 54 - 1 : 32 * 53] :
                    (dbg_sel == 54) ?   coalesced_bus[32 * 55 - 1 : 32 * 54] :
                    (dbg_sel == 55) ?   coalesced_bus[32 * 56 - 1 : 32 * 55] :
                    (dbg_sel == 56) ?   coalesced_bus[32 * 57 - 1 : 32 * 56] :
                    (dbg_sel == 57) ?   coalesced_bus[32 * 58 - 1 : 32 * 57] :
                    (dbg_sel == 58) ?   coalesced_bus[32 * 59 - 1 : 32 * 58] : 32'd0;

//assign dbg_bus = coalesced_bus;

reg             [31:0]          pkt_header_cnt;
reg             [31:0]          pkt_payload_cnt;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        pkt_payload_cnt <= 'd0;
    end 
    else if(o_eth_wr_en) begin
        pkt_payload_cnt <= pkt_payload_cnt + 'd1;
    end 
    else begin
        pkt_payload_cnt <= pkt_payload_cnt;
    end 
end 

always @(posedge clk or posedge rst) begin
    if(rst) begin
        pkt_header_cnt <= 'd0;
    end 
    else if(o_desc_wr_en) begin
        pkt_header_cnt <= pkt_header_cnt + 'd1;
    end 
    else begin
        pkt_header_cnt <= pkt_header_cnt;
    end 
end 

`ifdef ILA_PACKET_ENCAP_ON
ila_counter_probe ila_counter_probe_inst(
    .clk(clk),
    .probe0(pkt_header_cnt),
    .probe1(pkt_payload_cnt)
);
`endif

endmodule
