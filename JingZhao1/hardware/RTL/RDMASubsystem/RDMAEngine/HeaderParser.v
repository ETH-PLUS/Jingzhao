`timescale 1ns / 1ps

`include "ib_constant_def_h.vh"
`include "chip_include_rdma.vh"

module HeaderParser(
    input   wire                clk,
    input   wire                rst,

//Interface with RequesterRecvControl
    input   wire                i_header_to_rrc_prog_full,
    output  wire                o_header_to_rrc_wr_en,
    output  wire    [239:0]     ov_header_to_rrc_data,

    output  wire    [255:0]     ov_nd_to_rrc_data,
    input   wire                i_nd_to_rrc_prog_full,
    output  wire                o_nd_to_rrc_wr_en,

//ExecutionEngine
    input   wire                i_header_to_ee_prog_full,
    output  wire    [319:0]     ov_header_to_ee_data,
    output  wire                o_header_to_ee_wr_en,

    input   wire                i_nd_to_ee_prog_full,
    output  wire    [255:0]     ov_nd_to_ee_data,
    output  wire                o_nd_to_ee_wr_en,

//BitTrans
    input   wire                i_bit_trans_empty,
    input   wire    [255:0]     iv_bit_trans_data,
    output  wire                o_bit_trans_rd_en,

    input   wire    [31:0]      dbg_sel,
    output  wire    [32 - 1:0]      dbg_bus
    //output  wire    [`DBG_NUM_HEADER_PARSER * 32 - 1:0]      dbg_bus
);

//ila_header_parser ila_header_parser(
//    .clk(clk),
//    .probe0(i_header_to_rrc_prog_full), //1
//    .probe1(o_header_to_rrc_wr_en),     //1
//    .probe2(ov_header_to_rrc_data),     //240

//    .probe3(o_nd_to_rrc_wr_en),         //1
//    .probe4(i_nd_to_rrc_prog_full),     //1
//    .probe5(ov_nd_to_rrc_data),         //256

////ExecutionEngine
//    .probe6(o_header_to_ee_wr_en),      //1
//    .probe7(i_header_to_ee_prog_full),  //1
//    .probe8(ov_header_to_ee_data),      //320

//    .probe9(o_nd_to_ee_wr_en),      //1
//    .probe10(i_nd_to_ee_prog_full),         //1
//    .probe11(ov_nd_to_ee_data),         //256

////BitTrans
//    .probe12(i_bit_trans_empty),        //1
//    .probe13(o_bit_trans_rd_en),        //1
//    .probe14(iv_bit_trans_data)         //256
//); 

/*----------------------------------------  Part 1: Signals Definition and Submodules Connection ----------------------------------------*/
reg                 q_header_to_rrc_wr_en;
reg     [239:0]     qv_header_to_rrc_data;

reg     [255:0]     qv_nd_to_rrc_data;
reg                 q_nd_to_rrc_wr_en;

//ExecutionEngine
reg     [319:0]     qv_header_to_ee_data;
reg                 q_header_to_ee_wr_en;

reg     [255:0]     qv_nd_to_ee_data;
reg                 q_nd_to_ee_wr_en;

//BitTrans
reg                 q_bit_trans_rd_en;

assign o_header_to_rrc_wr_en = q_header_to_rrc_wr_en;
assign ov_header_to_rrc_data = qv_header_to_rrc_data;

assign ov_nd_to_rrc_data = qv_nd_to_rrc_data;
assign o_nd_to_rrc_wr_en = q_nd_to_rrc_wr_en;

//ExecutionEngine
assign ov_header_to_ee_data = qv_header_to_ee_data;
assign o_header_to_ee_wr_en = q_header_to_ee_wr_en;

assign ov_nd_to_ee_data = qv_nd_to_ee_data;
assign o_nd_to_ee_wr_en = q_nd_to_ee_wr_en;

//BitTrans
assign o_bit_trans_rd_en = q_bit_trans_rd_en;

wire    [12:0]          wv_pkt_length;

reg     [7:0]           qv_header_len;
reg     [12:0]          qv_pkt_left_len;
reg                     q_cur_is_rrc;
reg     [5:0]           qv_unwritten_len;
reg     [255:0]         qv_unwritten_data;

wire    [7:0]           wv_opcode;

reg                     q_atomics_indicator;

/*----------------------------------------  Part 2: State Machine Transition ------------------------------------------------------------*/
reg     [2:0]           HP_cur_state;
reg     [2:0]           HP_next_state;

parameter   [2:0]       HP_PARSE_IDLE_s     = 3'b001,
                        HP_PARSE_HEADER_s   = 3'b010,
                        HP_PARSE_PAYLOAD_s  = 3'b100;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        HP_cur_state <= HP_PARSE_IDLE_s;        
    end
    else begin
        HP_cur_state <= HP_next_state;
    end
end

always @(*) begin
    case(HP_cur_state)
        HP_PARSE_IDLE_s:        if(!i_bit_trans_empty) begin
                                    HP_next_state = HP_PARSE_HEADER_s;
                                end
                                else begin
                                    HP_next_state = HP_PARSE_IDLE_s;
                                end
        HP_PARSE_HEADER_s:      if(wv_opcode == `CMP_AND_SWAP || wv_opcode == `FETCH_AND_ADD) begin
                                    if(q_atomics_indicator == 0) begin
                                        HP_next_state = HP_PARSE_HEADER_s;
                                    end
                                    else if(!i_nd_to_ee_prog_full) begin
                                        HP_next_state = HP_PARSE_IDLE_s;
                                    end
                                    else begin
                                        HP_next_state = HP_PARSE_HEADER_s;
                                    end
                                end
                                else if((q_cur_is_rrc && !i_header_to_rrc_prog_full) || (!q_cur_is_rrc && !i_header_to_ee_prog_full)) begin
									if(wv_pkt_length == 0) begin
                                        HP_next_state = HP_PARSE_IDLE_s;
                                    end
                                    else begin
                                        HP_next_state = HP_PARSE_PAYLOAD_s;
                                    end
                                end
								else begin
									HP_next_state = HP_PARSE_HEADER_s;
								end 
        HP_PARSE_PAYLOAD_s:     if((qv_unwritten_len + qv_pkt_left_len <= 32)) begin
									if((q_cur_is_rrc && !i_nd_to_rrc_prog_full) || (!q_cur_is_rrc && !i_nd_to_ee_prog_full)) begin
										if(qv_pkt_left_len == 0) begin 
											HP_next_state = HP_PARSE_IDLE_s;
										end 
										else begin 
											if(!i_bit_trans_empty) begin 
												HP_next_state = HP_PARSE_IDLE_s;
											end 
											else begin
												HP_next_state = HP_PARSE_PAYLOAD_s;
											end 
										end
									end 
									else begin
										HP_next_state = HP_PARSE_PAYLOAD_s;
									end 
								end 
								else begin
									HP_next_state = HP_PARSE_PAYLOAD_s;		
								end
        default:                HP_next_state = HP_PARSE_IDLE_s;
    endcase
end

/*----------------------------------------  Part 3 Signals Decode ----------------------------------------------------------------------*/
//-- q_atomics_indicator --
//TODO : Handle Atomics case
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_atomics_indicator <= 'd0;
    end
    else begin
        q_atomics_indicator <= q_atomics_indicator;
    end
end

//-- wv_pkt_length --
assign wv_pkt_length = {iv_bit_trans_data[94:88], iv_bit_trans_data[61:56]};

reg 		[7:0] 		qv_opcode;
always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_opcode <= 'd0;
	end 
	else if(HP_cur_state == HP_PARSE_IDLE_s && !i_bit_trans_empty) begin
		qv_opcode <= wv_opcode;
	end 
	else begin
		qv_opcode <= qv_opcode;
	end 
end 

//-- wv_opcode --
assign wv_opcode = (HP_cur_state == HP_PARSE_IDLE_s && !i_bit_trans_empty) ? iv_bit_trans_data[31:24] : qv_opcode;

//-- qv_header_len --
always @(*) begin
    case(wv_opcode[4:0])
        `SEND_FIRST                 :   qv_header_len = 12;  
        `SEND_MIDDLE                :   qv_header_len = 12;  
        `SEND_LAST                  :   qv_header_len = 12;  
        `SEND_LAST_WITH_IMM         :   qv_header_len = 16;  
        `SEND_ONLY                  :   qv_header_len = 12 + (wv_opcode[7:5] == `UD ? 16 : 0);  
        `SEND_ONLY_WITH_IMM         :   qv_header_len = 16 + (wv_opcode[7:5] == `UD ? 16 : 0);  
        `RDMA_WRITE_FIRST           :   qv_header_len = 28;  
        `RDMA_WRITE_MIDDLE          :   qv_header_len = 12;  
        `RDMA_WRITE_LAST            :   qv_header_len = 12;  
        `RDMA_WRITE_LAST_WITH_IMM   :   qv_header_len = 16;  
        `RDMA_WRITE_ONLY            :   qv_header_len = 28;  
        `RDMA_WRITE_ONLY_WITH_IMM   :   qv_header_len = 32;  
        `RDMA_READ_REQUEST          :   qv_header_len = 28;  
        `CMP_AND_SWAP               :   qv_header_len = 40;  
        `FETCH_AND_ADD              :   qv_header_len = 40;
        `ACKNOWLEDGE                :   qv_header_len = 16;
        `RDMA_READ_RESPONSE_FIRST   :   qv_header_len = 16;
        `RDMA_READ_RESPONSE_MIDDLE  :   qv_header_len = 12;
        `RDMA_READ_RESPONSE_LAST    :   qv_header_len = 16;
        `RDMA_READ_RESPONSE_ONLY    :   qv_header_len = 16;   
        /*Spyglass Add Begin*/
        default                     :   qv_header_len = 12;     //Default BTH length
        /*Spyglass Add End*/
    endcase
end

//-- qv_pkt_left_len --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_pkt_left_len <= 0;        
    end
    else if (HP_cur_state == HP_PARSE_IDLE_s && HP_next_state == HP_PARSE_HEADER_s) begin
        qv_pkt_left_len <= wv_pkt_length + qv_header_len;
    end
    else if (HP_cur_state == HP_PARSE_HEADER_s) begin
        if(((q_cur_is_rrc && !i_header_to_rrc_prog_full) || (!q_cur_is_rrc && !i_header_to_ee_prog_full)) && o_bit_trans_rd_en) begin
            if(qv_pkt_left_len < 32) begin
                qv_pkt_left_len <= 0;
            end
            else begin
                qv_pkt_left_len <= qv_pkt_left_len - 32;
            end
        end
        else begin
            qv_pkt_left_len <= qv_pkt_left_len;
        end
    end
    else if (HP_cur_state == HP_PARSE_PAYLOAD_s) begin
        if(((q_cur_is_rrc && !i_nd_to_rrc_prog_full) || (!q_cur_is_rrc && !i_nd_to_ee_prog_full)) && o_bit_trans_rd_en) begin
            if(qv_pkt_left_len < 32) begin
                qv_pkt_left_len <= 0;
            end
            else begin
                qv_pkt_left_len <= qv_pkt_left_len - 32;
            end
        end
        else begin
            qv_pkt_left_len <= qv_pkt_left_len;
        end
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
    else if (HP_cur_state == HP_PARSE_HEADER_s && HP_next_state == HP_PARSE_PAYLOAD_s) begin 
		if(qv_header_len + wv_pkt_length > 32) begin
			qv_unwritten_len <= 32 - qv_header_len;
		end 
	    else begin
			qv_unwritten_len <= wv_pkt_length;
		end 
    end
    else if (HP_cur_state == HP_PARSE_PAYLOAD_s && ((!q_cur_is_rrc && !i_nd_to_ee_prog_full) || (q_cur_is_rrc && !i_nd_to_rrc_prog_full))) begin
		if(qv_pkt_left_len == 0) begin
			qv_unwritten_len <= 'd0;
		end 
		else if(qv_unwritten_len == 0) begin
			qv_unwritten_len <= 'd0;
		end 
		else begin 
			if((qv_unwritten_len + qv_pkt_left_len <= 32) && !i_bit_trans_empty) begin
				qv_unwritten_len <= 'd0;
			end 
			else if((qv_unwritten_len + qv_pkt_left_len > 32) && !i_bit_trans_empty) begin
				if(qv_pkt_left_len <= 32) begin 
					qv_unwritten_len <= qv_pkt_left_len - (32 - qv_unwritten_len);
				end 
				else begin
					qv_unwritten_len <= qv_unwritten_len;
				end 
			end 
			else begin
				qv_unwritten_len <= qv_unwritten_len;
			end 
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
    else if (HP_cur_state == HP_PARSE_HEADER_s && ((q_cur_is_rrc && !i_header_to_rrc_prog_full) || (!q_cur_is_rrc && !i_header_to_ee_prog_full))) begin
        case(qv_header_len) 
            12:         qv_unwritten_data <= iv_bit_trans_data[255 : 12 * 8];
            16:         qv_unwritten_data <= iv_bit_trans_data[255 : 16 * 8];
            20:         qv_unwritten_data <= iv_bit_trans_data[255 : 20 * 8];
            24:          qv_unwritten_data <= iv_bit_trans_data[255 : 24 * 8];
            28:          qv_unwritten_data <= iv_bit_trans_data[255 : 28 * 8];
            30:          qv_unwritten_data <= iv_bit_trans_data[255 : 30 * 8];
            32:          qv_unwritten_data <= qv_unwritten_data; 
            default:    qv_unwritten_data <= qv_unwritten_data;
        endcase
    end
    else if (HP_cur_state == HP_PARSE_PAYLOAD_s && ((q_cur_is_rrc && !i_nd_to_rrc_prog_full) || (!q_cur_is_rrc && !i_nd_to_ee_prog_full))) begin
        case(qv_unwritten_len) 
            20:         qv_unwritten_data <= iv_bit_trans_data[255 : 12 * 8];
            16:         qv_unwritten_data <= iv_bit_trans_data[255 : 16 * 8];
            12:         qv_unwritten_data <= iv_bit_trans_data[255 : 20 * 8];
            8:          qv_unwritten_data <= iv_bit_trans_data[255 : 24 * 8];
            4:          qv_unwritten_data <= iv_bit_trans_data[255 : 28 * 8];
            2:          qv_unwritten_data <= iv_bit_trans_data[255 : 30 * 8];
            0:          qv_unwritten_data <= qv_unwritten_data; 
            default:    qv_unwritten_data <= qv_unwritten_data;
        endcase
    end
    else begin
        qv_unwritten_data <= qv_unwritten_data;
    end
end

//-- q_cur_is_rrc --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_cur_is_rrc <= 1'b0;        
    end
    else if (HP_cur_state == HP_PARSE_IDLE_s && HP_next_state == HP_PARSE_HEADER_s) begin
        if(wv_opcode[4:0] == `ACKNOWLEDGE || wv_opcode[4:0] == `RDMA_READ_RESPONSE_FIRST || wv_opcode[4:0] == `RDMA_READ_RESPONSE_MIDDLE || 
            wv_opcode[4:0] == `RDMA_READ_RESPONSE_LAST || wv_opcode[4:0] == `RDMA_READ_RESPONSE_ONLY) begin
            q_cur_is_rrc <= 1'b1;        
        end
        else begin
            q_cur_is_rrc <= 1'b0;
        end
    end
    else begin
        q_cur_is_rrc <= q_cur_is_rrc;
    end
end

//-- q_header_to_rrc_wr_en --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_header_to_rrc_wr_en <= 1'b0;        
    end
    else if (HP_cur_state == HP_PARSE_HEADER_s) begin
        q_header_to_rrc_wr_en <= q_cur_is_rrc && !i_header_to_rrc_prog_full;
    end
    else if (HP_cur_state == HP_PARSE_PAYLOAD_s) begin
        q_header_to_rrc_wr_en <= 1'b0;
    end
    else begin
        q_header_to_rrc_wr_en <= 1'b0;
    end
end

//-- qv_header_to_rrc_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_header_to_rrc_data <= 'd0;
    end
    else if (HP_cur_state == HP_PARSE_HEADER_s) begin
        case(qv_header_len) 
            12:         qv_header_to_rrc_data <= iv_bit_trans_data[12 * 8 - 1 : 0];
            16:         qv_header_to_rrc_data <= iv_bit_trans_data[16 * 8 - 1 : 0];
            20:         qv_header_to_rrc_data <= iv_bit_trans_data[20 * 8 - 1 : 0];
            24:         qv_header_to_rrc_data <= iv_bit_trans_data[24 * 8 - 1 : 0];
            28:         qv_header_to_rrc_data <= iv_bit_trans_data[28 * 8 - 1 : 0];
            30:         qv_header_to_rrc_data <= iv_bit_trans_data[30 * 8 - 1 : 0];
            32:         qv_header_to_rrc_data <= iv_bit_trans_data[255 : 0]; 
            default:    qv_header_to_rrc_data <= qv_header_to_rrc_data;
        endcase
    end
    else begin
        qv_header_to_rrc_data <= qv_header_to_rrc_data;
    end
end

//-- q_nd_to_rrc_wr_en --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_nd_to_rrc_wr_en <= 1'b0;        
    end
    else if (HP_cur_state == HP_PARSE_PAYLOAD_s) begin
        if(qv_pkt_left_len > 0) begin
            q_nd_to_rrc_wr_en <= q_cur_is_rrc && o_bit_trans_rd_en && !i_nd_to_rrc_prog_full;
        end
        else begin
            q_nd_to_rrc_wr_en <= q_cur_is_rrc && !i_nd_to_rrc_prog_full;
        end
    end
    else begin
        q_nd_to_rrc_wr_en <= 1'b0;
    end
end

//-- qv_nd_to_rrc_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_nd_to_rrc_data <= 'd0;        
    end
    else if (HP_cur_state == HP_PARSE_PAYLOAD_s) begin
		if(qv_pkt_left_len == 0) begin
			case(qv_unwritten_len) 
				0:		qv_nd_to_rrc_data <= iv_bit_trans_data;			//Not happen
				1:		qv_nd_to_rrc_data <=	{248'd0,	qv_unwritten_data[1 * 8 - 1 : 0]};
				2:		qv_nd_to_rrc_data <=	{240'd0,	qv_unwritten_data[2 * 8 - 1 : 0]};
				3:		qv_nd_to_rrc_data <=	{232'd0,	qv_unwritten_data[3 * 8 - 1 : 0]};
				4:		qv_nd_to_rrc_data <=	{224'd0,	qv_unwritten_data[4 * 8 - 1 : 0]};
				5:		qv_nd_to_rrc_data <=	{216'd0,	qv_unwritten_data[5 * 8 - 1 : 0]};
				6:		qv_nd_to_rrc_data <=	{208'd0,	qv_unwritten_data[6 * 8 - 1 : 0]};
				7:		qv_nd_to_rrc_data <=	{200'd0,	qv_unwritten_data[7 * 8 - 1 : 0]};
				8:		qv_nd_to_rrc_data <=	{192'd0,	qv_unwritten_data[8 * 8 - 1 : 0]};
				9:		qv_nd_to_rrc_data <=	{184'd0,	qv_unwritten_data[9 * 8 - 1 : 0]};
				10:		qv_nd_to_rrc_data <=	{176'd0,	qv_unwritten_data[10 * 8 - 1 : 0]};
				11:		qv_nd_to_rrc_data <=	{168'd0,	qv_unwritten_data[11 * 8 - 1 : 0]};
				12:		qv_nd_to_rrc_data <=	{160'd0,	qv_unwritten_data[12 * 8 - 1 : 0]};
				13:		qv_nd_to_rrc_data <=	{152'd0,	qv_unwritten_data[13 * 8 - 1 : 0]};
				14:		qv_nd_to_rrc_data <=	{144'd0,	qv_unwritten_data[14 * 8 - 1 : 0]};
				15:		qv_nd_to_rrc_data <=	{136'd0,	qv_unwritten_data[15 * 8 - 1 : 0]};
				16:		qv_nd_to_rrc_data <=	{128'd0,	qv_unwritten_data[16 * 8 - 1 : 0]};
				17:		qv_nd_to_rrc_data <=	{120'd0,	qv_unwritten_data[17 * 8 - 1 : 0]};
				18:		qv_nd_to_rrc_data <=	{112'd0,	qv_unwritten_data[18 * 8 - 1 : 0]};
				19:		qv_nd_to_rrc_data <=	{104'd0,	qv_unwritten_data[19 * 8 - 1 : 0]};
				20:		qv_nd_to_rrc_data <=	{96'd0,	qv_unwritten_data[20 * 8 - 1 : 0]};
				21:		qv_nd_to_rrc_data <=	{88'd0,	qv_unwritten_data[21 * 8 - 1 : 0]};
				22:		qv_nd_to_rrc_data <=	{80'd0,	qv_unwritten_data[22 * 8 - 1 : 0]};
				23:		qv_nd_to_rrc_data <=	{72'd0,	qv_unwritten_data[23 * 8 - 1 : 0]};
				24:		qv_nd_to_rrc_data <=	{64'd0,	qv_unwritten_data[24 * 8 - 1 : 0]};
				25:		qv_nd_to_rrc_data <=	{56'd0,	qv_unwritten_data[25 * 8 - 1 : 0]};
				26:		qv_nd_to_rrc_data <=	{48'd0,	qv_unwritten_data[26 * 8 - 1 : 0]};
				27:		qv_nd_to_rrc_data <=	{40'd0,	qv_unwritten_data[27 * 8 - 1 : 0]};
				28:		qv_nd_to_rrc_data <=	{32'd0,	qv_unwritten_data[28 * 8 - 1 : 0]};
				29:		qv_nd_to_rrc_data <=	{24'd0,	qv_unwritten_data[29 * 8 - 1 : 0]};
				30:		qv_nd_to_rrc_data <=	{16'd0,	qv_unwritten_data[30 * 8 - 1 : 0]};
				31:		qv_nd_to_rrc_data <=	{8'd0,	qv_unwritten_data[31 * 8 - 1 : 0]};
				default:		qv_nd_to_rrc_data <= iv_bit_trans_data;
			endcase
		end 
		else begin 
        	case(qv_unwritten_len)
        	        20:     qv_nd_to_rrc_data <= {iv_bit_trans_data[12 * 8 - 1 : 0], qv_unwritten_data[20 * 8 - 1 : 0]};
        	        16:     qv_nd_to_rrc_data <= {iv_bit_trans_data[16 * 8 - 1 : 0], qv_unwritten_data[16 * 8 - 1 : 0]};
        	        12:     qv_nd_to_rrc_data <= {iv_bit_trans_data[20 * 8 - 1 : 0], qv_unwritten_data[12 * 8 - 1 : 0]};
        	        8:      qv_nd_to_rrc_data <= {iv_bit_trans_data[24 * 8 - 1 : 0], qv_unwritten_data[8 * 8 - 1 : 0]};
        	        4:      qv_nd_to_rrc_data <= {iv_bit_trans_data[28 * 8 - 1 : 0], qv_unwritten_data[4 * 8 - 1 : 0]};
        	        0:      qv_nd_to_rrc_data <= iv_bit_trans_data[255 : 0];
        	        default:qv_nd_to_rrc_data <= qv_nd_to_rrc_data;
        	endcase
		end 
    end
    else begin
        qv_nd_to_rrc_data <= qv_nd_to_rrc_data;
    end
end


//ExecutionEngine
//-- qv_header_to_ee_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_header_to_ee_data <= 'd0;
    end
    else if (HP_cur_state == HP_PARSE_HEADER_s) begin
        if(wv_opcode[4:0] == `CMP_AND_SWAP || wv_opcode == `FETCH_AND_ADD) begin
            if(q_atomics_indicator == 1) begin
                qv_header_to_ee_data <= {iv_bit_trans_data[31:0], qv_header_to_ee_data};
            end
            else begin
                qv_header_to_ee_data <= iv_bit_trans_data[255:0];
            end
        end
        else begin
            case(qv_header_len) 
                12:         qv_header_to_ee_data <= iv_bit_trans_data[12 * 8 - 1 : 0];
                16:         qv_header_to_ee_data <= iv_bit_trans_data[16 * 8 - 1 : 0];
                20:         qv_header_to_ee_data <= iv_bit_trans_data[20 * 8 - 1 : 0];
                24:         qv_header_to_ee_data <= iv_bit_trans_data[24 * 8 - 1 : 0];
                28:         qv_header_to_ee_data <= iv_bit_trans_data[28 * 8 - 1 : 0];
                30:         qv_header_to_ee_data <= iv_bit_trans_data[30 * 8 - 1 : 0];
                32:         qv_header_to_ee_data <= iv_bit_trans_data[255 : 0]; 
                default:    qv_header_to_ee_data <= qv_header_to_ee_data;
            endcase
        end
    end
    else begin
        qv_header_to_ee_data <= qv_header_to_ee_data;
    end
end

//-- q_header_to_ee_wr_en --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_header_to_ee_wr_en <= 1'b0;        
    end
    else if (HP_cur_state == HP_PARSE_HEADER_s) begin
        if(wv_opcode[4:0] == `CMP_AND_SWAP || wv_opcode == `FETCH_AND_ADD) begin
            if(q_atomics_indicator == 1) begin
                q_header_to_ee_wr_en <= !q_cur_is_rrc && !i_bit_trans_empty && !i_header_to_ee_prog_full;
            end
            else begin
                q_header_to_ee_wr_en <= 1'b0;
            end
        end
        else begin
            q_header_to_ee_wr_en <= !q_cur_is_rrc && !i_header_to_ee_prog_full;
        end
    end
    else begin
        q_header_to_ee_wr_en <= 1'b0;
    end
end


//-- qv_nd_to_ee_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_nd_to_ee_data <= 'd0;        
    end
    else if (HP_cur_state == HP_PARSE_PAYLOAD_s) begin
		if(qv_pkt_left_len == 0) begin
			case(qv_unwritten_len) 
				0:		qv_nd_to_ee_data <= iv_bit_trans_data;			//Not happen
				1:		qv_nd_to_ee_data <=	{248'd0,	qv_unwritten_data[1 * 8 - 1 : 0]};
				2:		qv_nd_to_ee_data <=	{240'd0,	qv_unwritten_data[2 * 8 - 1 : 0]};
				3:		qv_nd_to_ee_data <=	{232'd0,	qv_unwritten_data[3 * 8 - 1 : 0]};
				4:		qv_nd_to_ee_data <=	{224'd0,	qv_unwritten_data[4 * 8 - 1 : 0]};
				5:		qv_nd_to_ee_data <=	{216'd0,	qv_unwritten_data[5 * 8 - 1 : 0]};
				6:		qv_nd_to_ee_data <=	{208'd0,	qv_unwritten_data[6 * 8 - 1 : 0]};
				7:		qv_nd_to_ee_data <=	{200'd0,	qv_unwritten_data[7 * 8 - 1 : 0]};
				8:		qv_nd_to_ee_data <=	{192'd0,	qv_unwritten_data[8 * 8 - 1 : 0]};
				9:		qv_nd_to_ee_data <=	{184'd0,	qv_unwritten_data[9 * 8 - 1 : 0]};
				10:		qv_nd_to_ee_data <=	{176'd0,	qv_unwritten_data[10 * 8 - 1 : 0]};
				11:		qv_nd_to_ee_data <=	{168'd0,	qv_unwritten_data[11 * 8 - 1 : 0]};
				12:		qv_nd_to_ee_data <=	{160'd0,	qv_unwritten_data[12 * 8 - 1 : 0]};
				13:		qv_nd_to_ee_data <=	{152'd0,	qv_unwritten_data[13 * 8 - 1 : 0]};
				14:		qv_nd_to_ee_data <=	{144'd0,	qv_unwritten_data[14 * 8 - 1 : 0]};
				15:		qv_nd_to_ee_data <=	{136'd0,	qv_unwritten_data[15 * 8 - 1 : 0]};
				16:		qv_nd_to_ee_data <=	{128'd0,	qv_unwritten_data[16 * 8 - 1 : 0]};
				17:		qv_nd_to_ee_data <=	{120'd0,	qv_unwritten_data[17 * 8 - 1 : 0]};
				18:		qv_nd_to_ee_data <=	{112'd0,	qv_unwritten_data[18 * 8 - 1 : 0]};
				19:		qv_nd_to_ee_data <=	{104'd0,	qv_unwritten_data[19 * 8 - 1 : 0]};
				20:		qv_nd_to_ee_data <=	{96'd0,	qv_unwritten_data[20 * 8 - 1 : 0]};
				21:		qv_nd_to_ee_data <=	{88'd0,	qv_unwritten_data[21 * 8 - 1 : 0]};
				22:		qv_nd_to_ee_data <=	{80'd0,	qv_unwritten_data[22 * 8 - 1 : 0]};
				23:		qv_nd_to_ee_data <=	{72'd0,	qv_unwritten_data[23 * 8 - 1 : 0]};
				24:		qv_nd_to_ee_data <=	{64'd0,	qv_unwritten_data[24 * 8 - 1 : 0]};
				25:		qv_nd_to_ee_data <=	{56'd0,	qv_unwritten_data[25 * 8 - 1 : 0]};
				26:		qv_nd_to_ee_data <=	{48'd0,	qv_unwritten_data[26 * 8 - 1 : 0]};
				27:		qv_nd_to_ee_data <=	{40'd0,	qv_unwritten_data[27 * 8 - 1 : 0]};
				28:		qv_nd_to_ee_data <=	{32'd0,	qv_unwritten_data[28 * 8 - 1 : 0]};
				29:		qv_nd_to_ee_data <=	{24'd0,	qv_unwritten_data[29 * 8 - 1 : 0]};
				30:		qv_nd_to_ee_data <=	{16'd0,	qv_unwritten_data[30 * 8 - 1 : 0]};
				31:		qv_nd_to_ee_data <=	{8'd0,	qv_unwritten_data[31 * 8 - 1 : 0]};
				default:		qv_nd_to_ee_data <= iv_bit_trans_data;
			endcase
		end 
		else begin 
        	case(qv_unwritten_len)
        	        20:     qv_nd_to_ee_data <= {iv_bit_trans_data[12 * 8 - 1 : 0], qv_unwritten_data[20 * 8 - 1 : 0]};
        	        16:     qv_nd_to_ee_data <= {iv_bit_trans_data[16 * 8 - 1 : 0], qv_unwritten_data[16 * 8 - 1 : 0]};
        	        12:     qv_nd_to_ee_data <= {iv_bit_trans_data[20 * 8 - 1 : 0], qv_unwritten_data[12 * 8 - 1 : 0]};
        	        8:      qv_nd_to_ee_data <= {iv_bit_trans_data[24 * 8 - 1 : 0], qv_unwritten_data[8 * 8 - 1 : 0]};
        	        4:      qv_nd_to_ee_data <= {iv_bit_trans_data[28 * 8 - 1 : 0], qv_unwritten_data[4 * 8 - 1 : 0]};
        	        0:      qv_nd_to_ee_data <= iv_bit_trans_data[255 : 0];
        	        default:qv_nd_to_ee_data <= qv_nd_to_ee_data;
        	endcase
		end 
    end
    else begin
        qv_nd_to_ee_data <= qv_nd_to_ee_data;
    end
end

//-- q_nd_to_ee_wr_en --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_nd_to_ee_wr_en <= 1'b0;        
    end
    else if (HP_cur_state == HP_PARSE_PAYLOAD_s) begin
        if(qv_pkt_left_len > 0) begin
            q_nd_to_ee_wr_en <= !q_cur_is_rrc && o_bit_trans_rd_en && !i_nd_to_ee_prog_full;
        end
        else begin
            q_nd_to_ee_wr_en <= !q_cur_is_rrc && !i_nd_to_ee_prog_full;
        end
    end
    else begin
        q_nd_to_ee_wr_en <= 1'b0;
    end
end


//BitTrans
//-- q_bit_trans_rd_en --
always @(*) begin
    case(HP_cur_state)
        HP_PARSE_HEADER_s:  if(!i_bit_trans_empty) begin
                                if(wv_opcode[4:0] == `CMP_AND_SWAP || wv_opcode[4:0] == `FETCH_AND_ADD) begin
                                    if(q_atomics_indicator == 0) begin
                                        q_bit_trans_rd_en = 1'b1;
                                    end
                                    else begin
                                        q_bit_trans_rd_en = (q_cur_is_rrc && !i_header_to_rrc_prog_full) || (!q_cur_is_rrc && !i_header_to_ee_prog_full);
                                    end
                                end
                                else begin
                                	q_bit_trans_rd_en = (q_cur_is_rrc && !i_header_to_rrc_prog_full) || (!q_cur_is_rrc && !i_header_to_ee_prog_full);
                                end
                            end
                            else begin
                                q_bit_trans_rd_en = 1'b0;
                            end
        HP_PARSE_PAYLOAD_s: if(qv_pkt_left_len > 0) begin
                                q_bit_trans_rd_en = ((!q_cur_is_rrc && !i_nd_to_ee_prog_full) || (q_cur_is_rrc && !i_nd_to_rrc_prog_full)) && !i_bit_trans_empty;
                            end
                            else begin
                                q_bit_trans_rd_en = 1'b0;
                            end
        default:            q_bit_trans_rd_en = 1'b0;
    endcase
end

/*----------------------------- Connect dbg bus -------------------------------------*/
wire   [`DBG_NUM_HEADER_PARSER * 32 - 1 : 0]   coalesced_bus;

assign coalesced_bus = {
                            q_header_to_rrc_wr_en,
                            qv_header_to_rrc_data,
                            qv_nd_to_rrc_data,
                            q_nd_to_rrc_wr_en,
                            qv_header_to_ee_data,
                            q_header_to_ee_wr_en,
                            qv_nd_to_ee_data,
                            q_nd_to_ee_wr_en,
                            q_bit_trans_rd_en,
                            qv_header_len,
                            qv_pkt_left_len,
                            q_cur_is_rrc,
                            qv_unwritten_len,
                            qv_unwritten_data,
                            q_atomics_indicator,
                            HP_cur_state,
                            HP_next_state,
                            qv_opcode,
                            wv_pkt_length,
                            wv_opcode
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
                    (dbg_sel == 43) ?   coalesced_bus[32 * 44 - 1 : 32 * 43] : 32'd0;

//assign dbg_bus = coalesced_bus;

reg             [31:0]          pkt_header_cnt;
reg             [31:0]          pkt_payload_cnt;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        pkt_payload_cnt <= 'd0;
    end 
    else if(q_nd_to_ee_wr_en) begin
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
    else if(q_header_to_ee_wr_en) begin
        pkt_header_cnt <= pkt_header_cnt + 'd1;
    end 
    else begin
        pkt_header_cnt <= pkt_header_cnt;
    end 
end 

`ifdef ILA_HEADER_PARSER_ON
ila_counter_probe ila_counter_probe_inst(
    .clk(clk),
    .probe0(pkt_header_cnt),
    .probe1(pkt_payload_cnt)
);
`endif

endmodule
