`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/02/24 14:22:37
// Design Name: 
// Module Name: PacketDecap
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
`include    "ib_constant_def_h.vh"
`include "chip_include_rdma.vh"

module PacketDecap(
	input 	wire 		clk,
	input 	wire 		rst,

	input 	wire 		i_work_mode,

/*Interface with RDMAEngine*/
        input   wire    [255:0] iv_hpc_pkt_data,
        input   wire            i_hpc_pkt_empty,
        output  wire            o_hpc_pkt_rd_en,

        input   wire    [255:0] iv_roce_pkt_data,
        input   wire            i_roce_pkt_empty,
        output  wire            o_roce_pkt_rd_en,


        //Interface to RDMAEngine HeaderParser
        output   wire    [255:0]    ov_pkt_data,
        output   wire               o_pkt_wr_en,
        input    wire               i_pkt_prog_full,

        input    wire   [31:0]      dbg_sel,
        output   wire    [32 - 1:0]      dbg_bus
        //output   wire    [`DBG_NUM_PACKET_DECAP * 32 - 1:0]      dbg_bus
);


reg                     q_hpc_pkt_rd_en;
reg 					q_roce_pkt_rd_en;
reg                     q_pkt_wr_en;
reg         [255:0]     qv_pkt_data;

reg         [15:0]      qv_unwritten_len;
reg         [255:0]     qv_unwritten_data;
reg         [15:0]      qv_pkt_left_length;



reg 		[7:0]			qv_opcode;
reg 		[15:0]			qv_payload_len;
reg 		[15:0]			qv_transport_pkt_len;


assign o_hpc_pkt_rd_en = q_hpc_pkt_rd_en;
assign ov_pkt_data = qv_pkt_data;
assign o_pkt_wr_en = q_pkt_wr_en;



parameter   [1:0]       DECAP_IDLE_s = 2'd1,
                        DECAP_HPC_TRANS_s = 2'd2,
                        DECAP_ETH_TRANS_s = 2'd3;
                        

reg     [1:0]           Decap_cur_state;
reg     [1:0]           Decap_next_state;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        Decap_cur_state <= DECAP_IDLE_s;        
    end
    else begin
        Decap_cur_state <= Decap_next_state;
    end
end

always @(*) begin
    case(Decap_cur_state)
        DECAP_IDLE_s:       if(!i_hpc_pkt_empty || !i_roce_pkt_empty) begin
                                Decap_next_state = i_work_mode == `HPC_MODE ? DECAP_HPC_TRANS_s : DECAP_ETH_TRANS_s;
                            end
                            else begin
                                Decap_next_state = DECAP_IDLE_s;
                            end
        DECAP_HPC_TRANS_s:  if(qv_pkt_left_length > 0 && qv_pkt_left_length <= 8 && !i_hpc_pkt_empty && !i_pkt_prog_full) begin
                                Decap_next_state = DECAP_IDLE_s;
                            end
							else if(qv_pkt_left_length == 0 && !i_pkt_prog_full) begin
								Decap_next_state = DECAP_IDLE_s;
							end 
                            else begin
                                Decap_next_state = DECAP_HPC_TRANS_s;
                            end
        DECAP_ETH_TRANS_s: 	if(qv_pkt_left_length <= 32 && !i_roce_pkt_empty && !i_pkt_prog_full) begin
        						Decap_next_state = DECAP_IDLE_s;
        					end 
        					else begin
        						Decap_next_state = DECAP_ETH_TRANS_s;
        					end 
        default:            Decap_next_state = DECAP_IDLE_s;
    endcase
end


//-- qv_opcode -- Indicates current packet type
//-- qv_payload_len - Indicates payload length of current packet
always @(*) begin
    if (rst) begin
        qv_opcode = 'd0;
        qv_payload_len = 'd0;
    end
    else if(Decap_cur_state == DECAP_IDLE_s && !i_hpc_pkt_empty) begin  //Consider 64-bit link header
        qv_opcode = iv_hpc_pkt_data[31+64:24 + 64];
        qv_payload_len = {iv_hpc_pkt_data[94 + 64:88 + 64], iv_hpc_pkt_data[61 + 64:56 + 64]};
    end
    else if(Decap_cur_state == DECAP_IDLE_s && !i_roce_pkt_empty) begin  //Consider 64-bit link header
        qv_opcode = iv_roce_pkt_data[31:24];
        qv_payload_len = {iv_roce_pkt_data[94:88], iv_roce_pkt_data[61:56]};
    end
    else begin
        qv_opcode = 'd0;
        qv_payload_len = 'd0;
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

//-- qv_pkt_left_length --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_pkt_left_length <= 'd0;        
    end
    else if (Decap_cur_state == DECAP_IDLE_s && !i_hpc_pkt_empty) begin
		if(qv_transport_pkt_len + `HPC_LINK_HEADER_LENGTH > 32) begin
	        qv_pkt_left_length <= qv_transport_pkt_len + `HPC_LINK_HEADER_LENGTH - 32;  
		end
		else begin
			qv_pkt_left_length <= 'd0;
		end 
    end
    else if (Decap_cur_state == DECAP_IDLE_s && !i_roce_pkt_empty) begin
    	qv_pkt_left_length <= qv_transport_pkt_len;
    end
    else if(Decap_cur_state == DECAP_HPC_TRANS_s && q_hpc_pkt_rd_en) begin
        if(qv_pkt_left_length > 32) begin
            qv_pkt_left_length <= qv_pkt_left_length - 32;
        end
        else begin
            qv_pkt_left_length <= 'd0;
        end
    end
    else if(Decap_cur_state == DECAP_ETH_TRANS_s && q_roce_pkt_rd_en) begin
		qv_pkt_left_length <= qv_pkt_left_length - 32;
    end
    else begin
        qv_pkt_left_length <= qv_pkt_left_length;
    end
end

//-- qv_unwritten_len --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_unwritten_len <= 'd0;        
    end
    else if (Decap_cur_state == DECAP_IDLE_s && !i_hpc_pkt_empty) begin
        if(qv_transport_pkt_len >= 'd24) begin
            qv_unwritten_len <= 'd24;
        end
        else begin
            qv_unwritten_len <= qv_transport_pkt_len;
        end
    end
    else if(Decap_cur_state == DECAP_HPC_TRANS_s) begin
        if(qv_pkt_left_length == 0 && !i_pkt_prog_full) begin
            qv_unwritten_len <= 'd0;
        end
        else if(qv_pkt_left_length > 0 && !i_hpc_pkt_empty && !i_pkt_prog_full) begin
            if(qv_pkt_left_length > 8 && qv_pkt_left_length <= 32) begin
                qv_unwritten_len <= qv_pkt_left_length - 'd8;
            end
            else if(qv_pkt_left_length > 8 && qv_pkt_left_length > 32) begin
                qv_unwritten_len <= 'd24;
            end
            else begin
                qv_unwritten_len <= 'd0;
            end
        end
        else begin
            qv_unwritten_len <= qv_unwritten_len;
        end
    end
    else begin
        qv_unwritten_len <= qv_unwritten_len;
    end
end

//-- qv_unwritten_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_unwritten_data <= 'd0;        
    end
    else if (Decap_cur_state == DECAP_IDLE_s && !i_hpc_pkt_empty) begin
        qv_unwritten_data <= iv_hpc_pkt_data[255:64];   //Extract Link Header
    end
    else if(Decap_cur_state == DECAP_HPC_TRANS_s) begin
        if(qv_pkt_left_length == 0 && !i_pkt_prog_full) begin
            qv_unwritten_data <= 'd0;
        end
        else if(qv_pkt_left_length > 0 && !i_hpc_pkt_empty && !i_pkt_prog_full) begin
            if(qv_pkt_left_length > 8 && qv_pkt_left_length <= 32) begin
                case(qv_pkt_left_length - 8)
                    1:          qv_unwritten_data <= {248'd0, iv_hpc_pkt_data[64 + 8 * 1 - 1 : 64]};
                    2:          qv_unwritten_data <= {240'd0, iv_hpc_pkt_data[64 + 8 * 2 - 1 : 64]};
                    3:          qv_unwritten_data <= {232'd0, iv_hpc_pkt_data[64 + 8 * 3 - 1 : 64]};
                    4:          qv_unwritten_data <= {224'd0, iv_hpc_pkt_data[64 + 8 * 4 - 1 : 64]};
                    5:          qv_unwritten_data <= {216'd0, iv_hpc_pkt_data[64 + 8 * 5 - 1 : 64]};
                    6:          qv_unwritten_data <= {208'd0, iv_hpc_pkt_data[64 + 8 * 6 - 1 : 64]};
                    7:          qv_unwritten_data <= {200'd0, iv_hpc_pkt_data[64 + 8 * 7 - 1 : 64]};
                    8:          qv_unwritten_data <= {192'd0, iv_hpc_pkt_data[64 + 8 * 8 - 1 : 64]};
                    9:          qv_unwritten_data <= {184'd0, iv_hpc_pkt_data[64 + 8 * 9 - 1 : 64]};
                    10:         qv_unwritten_data <= {176'd0, iv_hpc_pkt_data[64 + 8 * 10 - 1 : 64]};
                    11:         qv_unwritten_data <= {168'd0, iv_hpc_pkt_data[64 + 8 * 11 - 1 : 64]};
                    12:         qv_unwritten_data <= {160'd0, iv_hpc_pkt_data[64 + 8 * 12 - 1 : 64]};
                    13:         qv_unwritten_data <= {152'd0, iv_hpc_pkt_data[64 + 8 * 13 - 1 : 64]};
                    14:         qv_unwritten_data <= {144'd0, iv_hpc_pkt_data[64 + 8 * 14 - 1 : 64]};
                    15:         qv_unwritten_data <= {136'd0, iv_hpc_pkt_data[64 + 8 * 15 - 1 : 64]};
                    16:         qv_unwritten_data <= {128'd0, iv_hpc_pkt_data[64 + 8 * 16 - 1 : 64]};
                    17:         qv_unwritten_data <= {120'd0, iv_hpc_pkt_data[64 + 8 * 17 - 1 : 64]};
                    18:         qv_unwritten_data <= {112'd0, iv_hpc_pkt_data[64 + 8 * 18 - 1 : 64]};
                    19:         qv_unwritten_data <= {104'd0, iv_hpc_pkt_data[64 + 8 * 19 - 1 : 64]};
                    20:         qv_unwritten_data <= {96'd0, iv_hpc_pkt_data[64 + 8 * 20 - 1 : 64]};
                    21:         qv_unwritten_data <= {88'd0, iv_hpc_pkt_data[64 + 8 * 21 - 1 : 64]};
                    22:         qv_unwritten_data <= {80'd0, iv_hpc_pkt_data[64 + 8 * 22 - 1 : 64]};
                    23:         qv_unwritten_data <= {72'd0, iv_hpc_pkt_data[64 + 8 * 23 - 1 : 64]};
                    24:         qv_unwritten_data <= {64'd0, iv_hpc_pkt_data[64 + 8 * 24 - 1 : 64]};
                    default:    qv_unwritten_data <= 'd0;
                endcase 
            end
            else if(qv_pkt_left_length > 8 && qv_pkt_left_length > 32) begin
                qv_unwritten_data <= iv_hpc_pkt_data[255:64];
            end
            else begin
                qv_unwritten_data <= 'd0;
            end            
        end
        else begin
            qv_unwritten_data <= qv_unwritten_data;
        end
    end
    else begin
        qv_unwritten_data <= qv_unwritten_data;
    end
end

//-- q_pkt_wr_en --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_pkt_wr_en <= 'd0;        
    end
    else if (Decap_cur_state == DECAP_HPC_TRANS_s) begin
        if(qv_pkt_left_length == 0 && !i_pkt_prog_full) begin
            q_pkt_wr_en <= 'd1;
        end 
        else if(qv_pkt_left_length > 0 && !i_hpc_pkt_empty && !i_pkt_prog_full) begin
            q_pkt_wr_en <= 'd1;
        end
        else begin
            q_pkt_wr_en <= 'd0;
        end
    end
    else if(Decap_cur_state == DECAP_ETH_TRANS_s) begin
    	if(!i_roce_pkt_empty && !i_pkt_prog_full) begin
    		q_pkt_wr_en <= 'd1;
    	end 
    	else begin
    		q_pkt_wr_en <= 'd0;
    	end 
    end 
    else begin
        q_pkt_wr_en <= 'd0;
    end
end

//-- qv_pkt_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_pkt_data <= 'd0;        
    end
    else if (Decap_cur_state == DECAP_HPC_TRANS_s) begin
        if(qv_pkt_left_length == 0 && !i_pkt_prog_full) begin
            qv_pkt_data <= qv_unwritten_data;
        end
        else if(qv_pkt_left_length > 0 && !i_hpc_pkt_empty && !i_pkt_prog_full) begin
            qv_pkt_data <= {iv_hpc_pkt_data[63:0], qv_unwritten_data[191:0]};
        end
        else begin
            qv_pkt_data <= qv_pkt_data;
        end
    end
    else if(Decap_cur_state == DECAP_ETH_TRANS_s) begin
    	qv_pkt_data <= iv_roce_pkt_data;
    end 
    else begin
        qv_pkt_data <= qv_pkt_data;
    end
end

//-- q_hpc_pkt_rd_en --
always @(*) begin
    if (rst) begin
        q_hpc_pkt_rd_en = 'd0;        
    end
    else if(Decap_cur_state == DECAP_IDLE_s && !i_hpc_pkt_empty) begin
        q_hpc_pkt_rd_en = 'd1;
    end
    else if (Decap_cur_state == DECAP_HPC_TRANS_s) begin
        if(qv_pkt_left_length == 0 && qv_unwritten_len > 0) begin
            q_hpc_pkt_rd_en = 'd0;
        end
        else if(qv_pkt_left_length > 0 && !i_hpc_pkt_empty && !i_pkt_prog_full) begin
            q_hpc_pkt_rd_en = 'd1;
        end
        else begin
            q_hpc_pkt_rd_en = 'd0;
        end
    end
    else begin
        q_hpc_pkt_rd_en = 'd0;
    end
end

//-- q_roce_pkt_rd_en --
always @(*) begin
	if(rst) begin
		q_roce_pkt_rd_en = 'd0;
	end 
	else if(Decap_cur_state == DECAP_ETH_TRANS_s && !i_roce_pkt_empty && !i_pkt_prog_full) begin
		q_roce_pkt_rd_en = 'd1;
	end 
	else begin
		q_roce_pkt_rd_en = 'd0;
	end 
end 

assign o_roce_pkt_rd_en = q_roce_pkt_rd_en;

/*----------------------------------- connect dbg bus -------------------------------------*/
wire   [`DBG_NUM_PACKET_DECAP * 32 - 1 : 0]   coalesced_bus;

assign coalesced_bus = {
                            q_hpc_pkt_rd_en,
                            q_roce_pkt_rd_en,
                            q_pkt_wr_en,
                            qv_pkt_data,
                            qv_unwritten_len,
                            qv_unwritten_data,
                            qv_pkt_left_length,
                            qv_opcode,
                            qv_payload_len,
                            qv_transport_pkt_len,
                            Decap_cur_state,
                            Decap_next_state
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
                    (dbg_sel == 18) ?   coalesced_bus[32 * 19 - 1 : 32 * 18] : 32'd0;

//assign dbg_bus = coalesced_bus;

endmodule
