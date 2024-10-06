`timescale 1ns / 1ps

`include "ib_constant_def_h.vh"
`include "sw_hw_interface_const_def_h.vh"
`include "chip_include_rdma.vh"

`define     READ_RESPONSE       8'b00000000
`define     ACK                 8'b00010001

module RespPktGen( //"rpg" for short
    input   wire                clk,
    input   wire                rst,

    input   wire                i_md_empty,
    input   wire    [191:0]     iv_md_data,
    output  wire                o_md_rd_en,

    input   wire                i_nd_empty,
    input   wire    [255:0]     iv_nd_data,
    output  wire                o_nd_rd_en,

    input   wire                i_trans_prog_full,
    output  wire                o_trans_wr_en,
    output  wire    [255:0]     ov_trans_data,

	input   wire    [31:0]      dbg_sel,
//    output  wire    [`DBG_NUM_RESP_PKT_GEN * 32 - 1:0]      dbg_bus
    output  wire    [32 - 1:0]      dbg_bus
);

/*----------------------------------------  Part 1: Signals Definition and Submodules Connection ----------------------------------------*/

reg                     q_md_rd_en;

reg                     q_nd_rd_en;

reg                     q_trans_wr_en;
reg    [257:0]          qv_trans_data;

assign o_md_rd_en = q_md_rd_en;

assign o_nd_rd_en = q_nd_rd_en;

assign o_trans_wr_en = q_trans_wr_en;
assign ov_trans_data = qv_trans_data;

wire    [127:0]             wv_ack_header;
reg     [5:0]               qv_unwritten_len;
reg     [255:0]             qv_unwritten_data;
reg     [127:0]             qv_read_resp_header;
reg     [31:0]              qv_response_cnt;
reg     [15:0]              qv_PMTU;
reg     [7:0]               qv_header_len;
reg     [31:0]              qv_cur_left_len;
reg     [31:0]              qv_msg_left_len;


/*----------------------------------------  Part 2: State Machine Transition ------------------------------------------------------------*/
reg     [3:0]           RPG_cur_state;
reg     [3:0]           RPG_next_state;

parameter   [3:0]       RPG_IDLE_s          = 4'b0001,
                        RPG_HEADER_s        = 4'b0010,
                        RPG_READ_SEG_s      = 4'b0100,
                        RPG_READ_PACKET_s   = 4'b1000;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        RPG_cur_state <= RPG_IDLE_s;
	end
	else begin
        RPG_cur_state <= RPG_next_state;
    end
end

always @(*) begin
    case(RPG_cur_state)
        RPG_IDLE_s:             if(!i_md_empty) begin
                                    if(iv_md_data[31:24] == `ACK) begin
                                        RPG_next_state = RPG_HEADER_s;
                                    end
                                    else begin
                                        RPG_next_state = RPG_READ_SEG_s;
                                    end
                                end 
                                else begin
                                    RPG_next_state = RPG_IDLE_s;
                                end
        RPG_HEADER_s:           if(!i_trans_prog_full) begin
                                    RPG_next_state = RPG_IDLE_s;
                                end
                                else begin
                                    RPG_next_state = RPG_HEADER_s;
                                end
        RPG_READ_SEG_s:         RPG_next_state = RPG_READ_PACKET_s;
        RPG_READ_PACKET_s:		if(qv_cur_left_len == 0 && !i_trans_prog_full) begin 
									if(qv_msg_left_len == 0) begin
										RPG_next_state = RPG_IDLE_s;
									end
									else begin
										RPG_next_state = RPG_READ_SEG_s;
									end 
								end       
								else if(qv_cur_left_len + qv_unwritten_len <= 32 && !i_nd_empty && !i_trans_prog_full) begin
									if(qv_cur_left_len == qv_msg_left_len) begin
										RPG_next_state = RPG_IDLE_s;
									end 
									else begin
										RPG_next_state = RPG_READ_SEG_s;
									end 
								end 
								else begin
									RPG_next_state = RPG_READ_PACKET_s;
								end 
        default:                RPG_next_state = RPG_IDLE_s;
    endcase
end

/*----------------------------------------  Part 3: Output Registers Decode -------------------------------------------------------------*/
wire    [95:0]          wv_BTH;
wire    [31:0]          wv_AETH;

wire    [23:0]          wv_PSN;
reg 	[23:0]			qv_read_resp_PSN;
wire    [12:0]          wv_tmp;

wire    [15:0]          wv_PMTU;

//-- wv_tmp -- Just for coding, no other use
assign wv_tmp = qv_msg_left_len;

assign wv_PSN = iv_md_data[87:64];
assign wv_BTH = iv_md_data[95:0];
assign wv_AETH = iv_md_data[191:160];

assign wv_PMTU = iv_md_data[112:96];

//-- wv_ack_header --
assign wv_ack_header = {wv_AETH, wv_BTH};

//-- qv_read_resp_PSN --
always @(posedge clk or posedge rst) begin
	if(rst) begin 
		qv_read_resp_PSN <= 'd0;
	end 
	else if(RPG_cur_state == RPG_IDLE_s && RPG_next_state == RPG_READ_SEG_s) begin
		qv_read_resp_PSN <= wv_PSN;
	end 
	else if(RPG_cur_state == RPG_READ_SEG_s && RPG_next_state == RPG_READ_PACKET_s) begin
		qv_read_resp_PSN <= qv_read_resp_PSN + 1;
	end 
	else begin
		qv_read_resp_PSN <= qv_read_resp_PSN;
	end 
end 

//-- qv_response_cnt --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_response_cnt <= 'd0;        
    end
    else if (RPG_cur_state == RPG_IDLE_s) begin
        qv_response_cnt <= 'd0;
    end
    else if (RPG_cur_state == RPG_READ_SEG_s) begin
        qv_response_cnt <= qv_response_cnt + 1;
    end
    else begin
        qv_response_cnt <= qv_response_cnt;
    end
end

 //-- qv_PMTU --
always @(*) begin
  	if(rst) begin
		qv_PMTU = 'd0;
	end 		 
	else begin
    	case(wv_PMTU[15:0]) 
    	    16'd1:      qv_PMTU = `MTU_256;
    	    16'd2:      qv_PMTU = `MTU_512;
    	    16'd3:      qv_PMTU = `MTU_1024;
    	    16'd4:      qv_PMTU = `MTU_2048;
    	    16'd5:      qv_PMTU = `MTU_4096;
    	    default:    qv_PMTU = `MTU_256;
    	endcase
	end 
end

//-- qv_header_len --
always @(*) begin
    case(RPG_cur_state)
        RPG_HEADER_s:       qv_header_len = 16;     //BTH + AETH
        RPG_READ_SEG_s:     if(qv_response_cnt == 0) begin
                                qv_header_len = 16; //Resposne First or Only, BTH + AETH
                            end
                            else begin
                                if(qv_msg_left_len <= qv_PMTU) begin
                                    qv_header_len = 16;     //Response Last, BTH + AETH
                                end
                                else begin
                                    qv_header_len = 12;     //Response Middle, BTH
                                end
                            end
        default:            qv_header_len = 'd0;
    endcase
end

wire    [31:0]          wv_msg_size;
assign wv_msg_size = iv_md_data[159:128];

//-- qv_cur_left_len --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_cur_left_len <= 'd0;        
    end
    else if (RPG_cur_state == RPG_READ_SEG_s) begin
        if(qv_msg_left_len < qv_PMTU) begin
            qv_cur_left_len <= qv_msg_left_len;
        end
        else begin
            qv_cur_left_len <= qv_PMTU;
        end
    end
    else if (RPG_cur_state == RPG_READ_PACKET_s)    begin
		if(q_nd_rd_en) begin
			if(qv_cur_left_len <= 32) begin
				qv_cur_left_len <= 'd0;
			end 
			else begin
				qv_cur_left_len <= qv_cur_left_len - 32;
			end 
		end 
    end
    else begin
        qv_cur_left_len <= qv_cur_left_len;
    end
end


//-- qv_msg_left_len --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_msg_left_len <= 'd0;        
    end
    else if (RPG_cur_state == RPG_IDLE_s && !i_md_empty) begin
        qv_msg_left_len <= wv_msg_size;     
    end
    else if (RPG_cur_state == RPG_READ_PACKET_s) begin
		if(q_nd_rd_en) begin 
			if(qv_msg_left_len <= 32) begin
				qv_msg_left_len <= 'd0;
			end 
			else begin
				qv_msg_left_len <= qv_msg_left_len - 32;
			end 		
		end 
    end
    else begin
        qv_msg_left_len <= qv_msg_left_len;
    end
end

//-- qv_unwritten_len --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_unwritten_len <= 'd0;
    end
    else if (RPG_cur_state == RPG_READ_SEG_s) begin
        qv_unwritten_len <= qv_header_len;
    end
    else if (RPG_cur_state == RPG_READ_PACKET_s) begin
		if(qv_cur_left_len == 0 && !i_trans_prog_full) begin
			qv_unwritten_len <= 'd0;
		end 
		else if(qv_cur_left_len > 0 && !i_nd_empty && !i_trans_prog_full) begin
			if(qv_cur_left_len > 32) begin
				qv_unwritten_len <= qv_unwritten_len;
			end 
			else if(qv_cur_left_len + qv_unwritten_len <= 32) begin
				qv_unwritten_len <= 'd0;
			end 
			else begin
				qv_unwritten_len <= qv_cur_left_len - (32 - qv_unwritten_len);
			end 
		end 
    end
    else begin
        qv_unwritten_len <= qv_unwritten_len;
    end
end

//-- qv_read_resp_header --
always @(*) begin
    case(RPG_cur_state)
        RPG_READ_SEG_s:     if(qv_response_cnt == 0) begin
                                if(qv_msg_left_len <= qv_PMTU) begin //RDMA Read Response Only
                                    qv_read_resp_header = {wv_AETH, 1'b0, wv_msg_size[12:6], qv_read_resp_PSN, 2'b00, wv_msg_size[5:0], wv_BTH[55:32], 3'b000, `RDMA_READ_RESPONSE_ONLY, wv_BTH[23:0]};
                                end
                                else begin //RDMA Read First 
                                    qv_read_resp_header = {wv_AETH, 1'b0, qv_PMTU[12:6], qv_read_resp_PSN, 2'b00, qv_PMTU[5:0], wv_BTH[55:32], 3'b000, `RDMA_READ_RESPONSE_FIRST, wv_BTH[23:0]};
                                end
                            end
                            else begin
                                if(qv_msg_left_len <= qv_PMTU) begin //RDMA Read Response Last
                                    qv_read_resp_header = {wv_AETH, 1'b0, wv_tmp[12:6], qv_read_resp_PSN, 2'b00, wv_tmp[5:0], wv_BTH[55:32], 3'b000, `RDMA_READ_RESPONSE_LAST, wv_BTH[23:0]};
                                end
                                else begin //RDMA Read Middle
                                    qv_read_resp_header = {32'd0, 1'b0, qv_PMTU[12:6], qv_read_resp_PSN, 2'b00, qv_PMTU[5:0], wv_BTH[55:32], 3'b000, `RDMA_READ_RESPONSE_MIDDLE, wv_BTH[23:0]};
                                end
                            end
        default:            qv_read_resp_header = 'd0;
    endcase
end

//-- qv_unwritten_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_unwritten_data <= 'd0;
    end
    else if (RPG_cur_state == RPG_READ_SEG_s) begin
        qv_unwritten_data <= qv_read_resp_header;
    end
    else if (RPG_cur_state == RPG_READ_PACKET_s) begin
		if(qv_cur_left_len == 0 && !i_trans_prog_full) begin	//Finish a packet
			qv_unwritten_data <= 'd0;
		end 
		else if(qv_cur_left_len > 32 &&!i_nd_empty && !i_trans_prog_full) begin
        	case(qv_unwritten_len)
        	    0:          qv_unwritten_data <= 'd0;       //No remained data 
        	    1:          qv_unwritten_data <= {248'd0, iv_nd_data[255 : 256 - 1 * 8]};
        	    2:          qv_unwritten_data <= {240'd0, iv_nd_data[255 : 256 - 2 * 8]};
        	    3:          qv_unwritten_data <= {232'd0, iv_nd_data[255 : 256 - 3 * 8]};
        	    4:          qv_unwritten_data <= {224'd0, iv_nd_data[255 : 256 - 4 * 8]};
        	    5:          qv_unwritten_data <= {216'd0, iv_nd_data[255 : 256 - 5 * 8]};
        	    6:          qv_unwritten_data <= {208'd0, iv_nd_data[255 : 256 - 6 * 8]};
        	    7:          qv_unwritten_data <= {200'd0, iv_nd_data[255 : 256 - 7 * 8]};
        	    8:          qv_unwritten_data <= {192'd0, iv_nd_data[255 : 256 - 8 * 8]};
        	    9:          qv_unwritten_data <= {184'd0, iv_nd_data[255 : 256 - 9 * 8]};
        	    10:         qv_unwritten_data <= {176'd0, iv_nd_data[255 : 256 - 10 * 8]};            
        	    11:         qv_unwritten_data <= {168'd0, iv_nd_data[255 : 256 - 11 * 8]};
        	    12:         qv_unwritten_data <= {160'd0, iv_nd_data[255 : 256 - 12 * 8]};
        	    13:         qv_unwritten_data <= {152'd0, iv_nd_data[255 : 256 - 13 * 8]};
        	    14:         qv_unwritten_data <= {144'd0, iv_nd_data[255 : 256 - 14 * 8]};
        	    15:         qv_unwritten_data <= {136'd0, iv_nd_data[255 : 256 - 15 * 8]};
        	    16:         qv_unwritten_data <= {128'd0, iv_nd_data[255 : 256 - 16 * 8]};
        	    17:         qv_unwritten_data <= {120'd0, iv_nd_data[255 : 256 - 17 * 8]};
        	    18:         qv_unwritten_data <= {112'd0, iv_nd_data[255 : 256 - 18 * 8]};
        	    19:         qv_unwritten_data <= {104'd0, iv_nd_data[255 : 256 - 19 * 8]};
        	    20:         qv_unwritten_data <= {96'd0, iv_nd_data[255 : 256 - 20 * 8]};
        	    21:         qv_unwritten_data <= {88'd0, iv_nd_data[255 : 256 - 21 * 8]};
        	    22:         qv_unwritten_data <= {80'd0, iv_nd_data[255 : 256 - 22 * 8]};
        	    23:         qv_unwritten_data <= {72'd0, iv_nd_data[255 : 256 - 23 * 8]};
        	    24:         qv_unwritten_data <= {64'd0, iv_nd_data[255 : 256 - 24 * 8]};
        	    25:         qv_unwritten_data <= {56'd0, iv_nd_data[255 : 256 - 25 * 8]};
        	    26:         qv_unwritten_data <= {48'd0, iv_nd_data[255 : 256 - 26 * 8]};
        	    27:         qv_unwritten_data <= {40'd0, iv_nd_data[255 : 256 - 27 * 8]};
        	    28:         qv_unwritten_data <= {32'd0, iv_nd_data[255 : 256 - 28 * 8]};
        	    29:         qv_unwritten_data <= {24'd0, iv_nd_data[255 : 256 - 29 * 8]};
        	    30:         qv_unwritten_data <= {16'd0, iv_nd_data[255 : 256 - 30 * 8]};
        	    31:         qv_unwritten_data <= {8'd0, iv_nd_data[255 : 256 - 31 * 8]};
        	    default:    qv_unwritten_data <= qv_unwritten_data;
        	endcase
		end 
		else if(qv_cur_left_len <= 32 && !i_nd_empty && !i_trans_prog_full) begin
			if(qv_cur_left_len + qv_unwritten_len <= 32) begin //Packet finish
				qv_unwritten_data <= 'd0;
			end 
			else begin
				case(32 - qv_unwritten_len) 
        	    	1:          qv_unwritten_data <= {8'd0, iv_nd_data[255 : 1 * 8]};
        		    2:          qv_unwritten_data <= {16'd0, iv_nd_data[255 : 2 * 8]};
        		    3:          qv_unwritten_data <= {24'd0, iv_nd_data[255 : 3 * 8]};
        		    4:          qv_unwritten_data <= {32'd0, iv_nd_data[255 : 4 * 8]};
        		    5:          qv_unwritten_data <= {40'd0, iv_nd_data[255 : 5 * 8]};
        		    6:          qv_unwritten_data <= {48'd0, iv_nd_data[255 : 6 * 8]};
        		    7:          qv_unwritten_data <= {56'd0, iv_nd_data[255 : 7 * 8]};
        		    8:          qv_unwritten_data <= {64'd0, iv_nd_data[255 : 8 * 8]};
        		    9:          qv_unwritten_data <= {72'd0, iv_nd_data[255 : 9 * 8]};
        		    10:         qv_unwritten_data <= {80'd0, iv_nd_data[255 : 10 * 8]};            
        		    11:         qv_unwritten_data <= {88'd0, iv_nd_data[255 : 11 * 8]};
        		    12:         qv_unwritten_data <= {96'd0, iv_nd_data[255 : 12 * 8]};
        		    13:         qv_unwritten_data <= {104'd0, iv_nd_data[255 : 13 * 8]};
        		    14:         qv_unwritten_data <= {112'd0, iv_nd_data[255 : 14 * 8]};
        		    15:         qv_unwritten_data <= {120'd0, iv_nd_data[255 : 15 * 8]};
        		    16:         qv_unwritten_data <= {128'd0, iv_nd_data[255 : 16 * 8]};
        		    17:         qv_unwritten_data <= {136'd0, iv_nd_data[255 : 17 * 8]};
        		    18:         qv_unwritten_data <= {144'd0, iv_nd_data[255 : 18 * 8]};
        		    19:         qv_unwritten_data <= {152'd0, iv_nd_data[255 : 19 * 8]};
        		    20:         qv_unwritten_data <= {160'd0, iv_nd_data[255 : 20 * 8]};
        		    21:         qv_unwritten_data <= {168'd0, iv_nd_data[255 : 21 * 8]};
        		    22:         qv_unwritten_data <= {176'd0, iv_nd_data[255 : 22 * 8]};
        		    23:         qv_unwritten_data <= {184'd0, iv_nd_data[255 : 23 * 8]};
        		    24:         qv_unwritten_data <= {192'd0, iv_nd_data[255 : 24 * 8]};
        		    25:         qv_unwritten_data <= {200'd0, iv_nd_data[255 : 25 * 8]};
        		    26:         qv_unwritten_data <= {208'd0, iv_nd_data[255 : 26 * 8]};
        		    27:         qv_unwritten_data <= {216'd0, iv_nd_data[255 : 27 * 8]};
        		    28:         qv_unwritten_data <= {224'd0, iv_nd_data[255 : 28 * 8]};
        		    29:         qv_unwritten_data <= {232'd0, iv_nd_data[255 : 29 * 8]};
        		    30:         qv_unwritten_data <= {240'd0, iv_nd_data[255 : 30 * 8]};
        		    31:         qv_unwritten_data <= {248'd0, iv_nd_data[255 : 31 * 8]};
        		    default:    qv_unwritten_data <= qv_unwritten_data;
				endcase
			end 
		end 
	end 
    else begin
        qv_unwritten_data <= qv_unwritten_data;
    end
end

//-- q_md_rd_en -- Simplified coding, may cause combinational loop?
always @(*) begin
    q_md_rd_en = (RPG_cur_state != RPG_IDLE_s) && (RPG_next_state == RPG_IDLE_s);
end

//-- q_nd_rd_en --
always @(*) begin
	if(rst) begin
		q_nd_rd_en = 'd0;
	end 
	else if(RPG_cur_state == RPG_READ_PACKET_s) begin
		if(qv_cur_left_len == 0) begin
			q_nd_rd_en = 'd0;
		end
		else if(!i_nd_empty && !i_trans_prog_full) begin 
			q_nd_rd_en = 'd1;
		end 
		else begin
			q_nd_rd_en = 'd0;
		end 
	end 
	else begin
		q_nd_rd_en = 'd0;
	end 
end

//-- q_trans_wr_en --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_trans_wr_en <= 1'b0;
    end
    else if (RPG_cur_state == RPG_HEADER_s && !i_trans_prog_full) begin
        q_trans_wr_en <= 1'b1;
    end
    else if (RPG_cur_state == RPG_READ_PACKET_s) begin
		if(qv_cur_left_len == 0) begin
			q_trans_wr_en <= !i_trans_prog_full;
		end 
		else begin
			q_trans_wr_en <= !i_trans_prog_full && !i_nd_empty;
		end 
    end
    else begin
        q_trans_wr_en <= 1'b0;
    end
end

//-- qv_trans_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_trans_data <= 'd0;        
    end
    else if (RPG_cur_state == RPG_HEADER_s) begin
        qv_trans_data <= wv_ack_header;
    end
    else if (RPG_cur_state == RPG_READ_PACKET_s) begin
		if(qv_cur_left_len == 0 && !i_trans_prog_full) begin 
	        case(qv_unwritten_len)
	            0:          qv_trans_data <= iv_nd_data; 	//Does not happen
	            1:          qv_trans_data <= {248'd0, qv_unwritten_data[1 * 8 - 1 : 0]};
	            2:          qv_trans_data <= {240'd0, qv_unwritten_data[2 * 8 - 1 : 0]};
	            3:          qv_trans_data <= {232'd0, qv_unwritten_data[3 * 8 - 1 : 0]};
	            4:          qv_trans_data <= {224'd0, qv_unwritten_data[4 * 8 - 1 : 0]};
	            5:          qv_trans_data <= {216'd0, qv_unwritten_data[5 * 8 - 1 : 0]};
	            6:          qv_trans_data <= {208'd0, qv_unwritten_data[6 * 8 - 1 : 0]};
	            7:          qv_trans_data <= {200'd0, qv_unwritten_data[7 * 8 - 1 : 0]};
	            8:          qv_trans_data <= {192'd0, qv_unwritten_data[8 * 8 - 1 : 0]};
	            9:          qv_trans_data <= {184'd0, qv_unwritten_data[9 * 8 - 1 : 0]};
	            10:         qv_trans_data <= {176'd0, qv_unwritten_data[10 * 8 - 1 : 0]};
	            11:         qv_trans_data <= {168'd0, qv_unwritten_data[11 * 8 - 1 : 0]};
	            12:         qv_trans_data <= {160'd0, qv_unwritten_data[12 * 8 - 1 : 0]};
	            13:         qv_trans_data <= {152'd0, qv_unwritten_data[13 * 8 - 1 : 0]};
	            14:         qv_trans_data <= {144'd0, qv_unwritten_data[14 * 8 - 1 : 0]};
	            15:         qv_trans_data <= {136'd0, qv_unwritten_data[15 * 8 - 1 : 0]};
	            16:         qv_trans_data <= {128'd0, qv_unwritten_data[16 * 8 - 1 : 0]};
	            17:         qv_trans_data <= {120'd0, qv_unwritten_data[17 * 8 - 1 : 0]};
	            18:         qv_trans_data <= {112'd0, qv_unwritten_data[18 * 8 - 1 : 0]};
	            19:         qv_trans_data <= {104'd0, qv_unwritten_data[19 * 8 - 1 : 0]};
	            20:         qv_trans_data <= {96'd0, qv_unwritten_data[20 * 8 - 1 : 0]};
	            21:         qv_trans_data <= {88'd0, qv_unwritten_data[21 * 8 - 1 : 0]};
	            22:         qv_trans_data <= {80'd0, qv_unwritten_data[22 * 8 - 1 : 0]};
	            23:         qv_trans_data <= {72'd0, qv_unwritten_data[23 * 8 - 1 : 0]};
	            24:         qv_trans_data <= {64'd0, qv_unwritten_data[24 * 8 - 1 : 0]};
	            25:         qv_trans_data <= {56'd0, qv_unwritten_data[25 * 8 - 1 : 0]};
	            26:         qv_trans_data <= {48'd0, qv_unwritten_data[26 * 8 - 1 : 0]};
	            27:         qv_trans_data <= {40'd0, qv_unwritten_data[27 * 8 - 1 : 0]};
	            28:         qv_trans_data <= {32'd0, qv_unwritten_data[28 * 8 - 1 : 0]};
	            29:         qv_trans_data <= {24'd0, qv_unwritten_data[29 * 8 - 1 : 0]};
	            30:         qv_trans_data <= {16'd0, qv_unwritten_data[30 * 8 - 1 : 0]};
	            31:         qv_trans_data <= {8'd0, qv_unwritten_data[31 * 8 - 1 : 0]};
	            default:    qv_trans_data <= qv_trans_data;
			endcase	
		end 
		else if(qv_cur_left_len > 0 && !i_nd_empty && !i_trans_prog_full) begin
        	case(qv_unwritten_len)
        	    0:          qv_trans_data <= iv_nd_data;
        	    1:          qv_trans_data <= {iv_nd_data, qv_unwritten_data[1 * 8 - 1 : 0]};
        	    2:          qv_trans_data <= {iv_nd_data, qv_unwritten_data[2 * 8 - 1 : 0]};
        	    3:          qv_trans_data <= {iv_nd_data, qv_unwritten_data[3 * 8 - 1 : 0]};
        	    4:          qv_trans_data <= {iv_nd_data, qv_unwritten_data[4 * 8 - 1 : 0]};
        	    5:          qv_trans_data <= {iv_nd_data, qv_unwritten_data[5 * 8 - 1 : 0]};
        	    6:          qv_trans_data <= {iv_nd_data, qv_unwritten_data[6 * 8 - 1 : 0]};
        	    7:          qv_trans_data <= {iv_nd_data, qv_unwritten_data[7 * 8 - 1 : 0]};
        	    8:          qv_trans_data <= {iv_nd_data, qv_unwritten_data[8 * 8 - 1 : 0]};
        	    9:          qv_trans_data <= {iv_nd_data, qv_unwritten_data[9 * 8 - 1 : 0]};
        	    10:         qv_trans_data <= {iv_nd_data, qv_unwritten_data[10 * 8 - 1 : 0]};
        	    11:         qv_trans_data <= {iv_nd_data, qv_unwritten_data[11 * 8 - 1 : 0]};
        	    12:         qv_trans_data <= {iv_nd_data, qv_unwritten_data[12 * 8 - 1 : 0]};
        	    13:         qv_trans_data <= {iv_nd_data, qv_unwritten_data[13 * 8 - 1 : 0]};
        	    14:         qv_trans_data <= {iv_nd_data, qv_unwritten_data[14 * 8 - 1 : 0]};
        	    15:         qv_trans_data <= {iv_nd_data, qv_unwritten_data[15 * 8 - 1 : 0]};
        	    16:         qv_trans_data <= {iv_nd_data, qv_unwritten_data[16 * 8 - 1 : 0]};
        	    17:         qv_trans_data <= {iv_nd_data, qv_unwritten_data[17 * 8 - 1 : 0]};
        	    18:         qv_trans_data <= {iv_nd_data, qv_unwritten_data[18 * 8 - 1 : 0]};
        	    19:         qv_trans_data <= {iv_nd_data, qv_unwritten_data[19 * 8 - 1 : 0]};
        	    20:         qv_trans_data <= {iv_nd_data, qv_unwritten_data[20 * 8 - 1 : 0]};
        	    21:         qv_trans_data <= {iv_nd_data, qv_unwritten_data[21 * 8 - 1 : 0]};
        	    22:         qv_trans_data <= {iv_nd_data, qv_unwritten_data[22 * 8 - 1 : 0]};
        	    23:         qv_trans_data <= {iv_nd_data, qv_unwritten_data[23 * 8 - 1 : 0]};
        	    24:         qv_trans_data <= {iv_nd_data, qv_unwritten_data[24 * 8 - 1 : 0]};
        	    25:         qv_trans_data <= {iv_nd_data, qv_unwritten_data[25 * 8 - 1 : 0]};
        	    26:         qv_trans_data <= {iv_nd_data, qv_unwritten_data[26 * 8 - 1 : 0]};
        	    27:         qv_trans_data <= {iv_nd_data, qv_unwritten_data[27 * 8 - 1 : 0]};
        	    28:         qv_trans_data <= {iv_nd_data, qv_unwritten_data[28 * 8 - 1 : 0]};
        	    29:         qv_trans_data <= {iv_nd_data, qv_unwritten_data[29 * 8 - 1 : 0]};
        	    30:         qv_trans_data <= {iv_nd_data, qv_unwritten_data[30 * 8 - 1 : 0]};
        	    31:         qv_trans_data <= {iv_nd_data, qv_unwritten_data[31 * 8 - 1 : 0]};
        	    default:    qv_trans_data <= qv_trans_data;
        	endcase
		end
		else begin
			qv_trans_data <= qv_trans_data;
		end 
    end
    else begin
        qv_trans_data <= qv_unwritten_data;
    end
end


/*---------------------------------- connect dbg bus --------------------------------------*/
wire   [`DBG_NUM_RESP_PKT_GEN * 32 - 1 : 0]   coalesced_bus;

assign coalesced_bus = {
                            q_md_rd_en,
                            q_nd_rd_en,
                            q_trans_wr_en,
                            qv_trans_data,
                            qv_unwritten_len,
                            qv_unwritten_data,
                            qv_read_resp_header,
                            qv_response_cnt,
                            qv_PMTU,
                            qv_header_len,
                            qv_cur_left_len,
                            qv_msg_left_len,
                            RPG_cur_state,
                            RPG_next_state,
                            wv_ack_header,
                            wv_BTH,
                            wv_AETH,
                            wv_PSN,
                            wv_tmp,
                            wv_PMTU,
                            wv_msg_size
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
                    (dbg_sel == 34) ?   coalesced_bus[32 * 35 - 1 : 32 * 34] : 32'd0;
//assign dbg_bus = coalesced_bus;

endmodule
