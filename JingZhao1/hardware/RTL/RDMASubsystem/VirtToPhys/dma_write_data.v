//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: dma_write_data.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V0.0 
// VERSION DESCRIPTION: 4st Edition  
//----------------------------------------------------
// RELEASE DATE: 2021-06-09 
//---------------------------------------------------- 
// PURPOSE:get the mtt_ram_ctl dma request, read the data from the src request channel. Finally, write the data to host memory.
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
// 
//-FHDR-----------------------------------------------

//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_v2p_h.vh"

module dma_write_data#(
    parameter DMA_DT_REQ_WIDTH  = 134//mtt_ram_ctl to dma_read/write_data req header fifo
    )(
    input clk,
    input rst,
//------------------interface to mtt_ram_ctl module-------------
    //-mtt_ram_ctl--dma_write_data req header format
    //high-----------------------------low
    //|-------------------134 bit--------------------|
    //| total len |opcode | dest/src |tmp len | addr |
    //| 32        |   3   |     3    | 32     |  64  |
    //|----------------------------------------------|
    output  wire                            dma_wr_dt_req_rd_en,
    input   wire                            dma_wr_dt_req_empty,
    input   wire  [DMA_DT_REQ_WIDTH-1:0]    dma_wr_dt_req_dout,

//Interface with RDMA Engine
    //Channel 4 for RequesterTransControl, upload Completion Event
    input   wire                i_rtc_vtp_upload_empty,
    output  wire                o_rtc_vtp_upload_rd_en,
    input   wire    [255:0]     iv_rtc_vtp_upload_data,

    //Channel 5 for RequesterRecvControl, upload RDMA Read Response
    input   wire                i_rrc_vtp_upload_empty,
    output  wire                o_rrc_vtp_upload_rd_en,
    input   wire    [255:0]     iv_rrc_vtp_upload_data,

    //Channel 7 for ExecutionEngine, upload Send/Write Payload and download Read Payload
    input   wire                i_ee_vtp_upload_empty,
    output  wire                o_ee_vtp_upload_rd_en,
    input   wire    [255:0]     iv_ee_vtp_upload_data,

//Interface with DMA Engine
    //Channel 3 DMA Write Data(CQE/Network Data)   
    output  wire                            dma_v2p_dt_wr_req_valid,
    output  wire                            dma_v2p_dt_wr_req_last ,
    output  wire  [(`DT_WIDTH-1):0]         dma_v2p_dt_wr_req_data ,
    output  wire  [(`HD_WIDTH-1):0]         dma_v2p_dt_wr_req_head ,
    input   wire                           dma_v2p_dt_wr_req_ready

    `ifdef V2P_DUG
    //apb_slave
    ,  output wire [`WRDT_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_wrdt
    `endif


);

reg                            q_dma_v2p_dt_wr_req_valid;
reg                            q_dma_v2p_dt_wr_req_last ;
reg  [(`DT_WIDTH-1):0]         qv_dma_v2p_dt_wr_req_data ;
reg  [(`HD_WIDTH-1):0]         qv_dma_v2p_dt_wr_req_head ;

assign dma_v2p_dt_wr_req_valid = q_dma_v2p_dt_wr_req_valid;
assign dma_v2p_dt_wr_req_last  = q_dma_v2p_dt_wr_req_last ;
assign dma_v2p_dt_wr_req_data  = qv_dma_v2p_dt_wr_req_data;
assign dma_v2p_dt_wr_req_head  = qv_dma_v2p_dt_wr_req_head;


reg                            q_dma_v2p_dt_wr_req_valid_diff;
reg                            q_dma_v2p_dt_wr_req_last_diff ;
reg  [(`DT_WIDTH-1):0]         qv_dma_v2p_dt_wr_req_data_diff ;
reg  [(`HD_WIDTH-1):0]         qv_dma_v2p_dt_wr_req_head_diff ;

always @(posedge clk or posedge rst) begin
	if(rst) begin
		q_dma_v2p_dt_wr_req_valid_diff <= 'd0;
		q_dma_v2p_dt_wr_req_last_diff <= 'd0;
		qv_dma_v2p_dt_wr_req_data_diff <= 'd0;
		qv_dma_v2p_dt_wr_req_head_diff <= 'd0;
	end 
	else begin
		q_dma_v2p_dt_wr_req_valid_diff <= q_dma_v2p_dt_wr_req_valid;
		q_dma_v2p_dt_wr_req_last_diff <= q_dma_v2p_dt_wr_req_last;
		qv_dma_v2p_dt_wr_req_data_diff <= qv_dma_v2p_dt_wr_req_data;
		qv_dma_v2p_dt_wr_req_head_diff <= qv_dma_v2p_dt_wr_req_head;
	end
end 


wire                [31:0]                      wv_cur_mpt_length;
wire                [31:0]                      wv_cur_mtt_length;
wire                [2:0]                       wv_cur_channel;
wire                                            w_channel_empty;
wire                [255:0]                     wv_channel_dout;

reg                                             q_channel_rd_en;

reg                 [31:0]                      qv_mpt_req_length_left;
reg                 [31:0]                      qv_mtt_req_length_left;

reg                 [31:0]                      qv_unwritten_len;
reg                 [255:0]                     qv_unwritten_data;

wire                                            w_last_mtt_of_mpt;



assign wv_cur_mpt_length = dma_wr_dt_req_dout[133:102];
assign wv_cur_mtt_length = dma_wr_dt_req_dout[95:64];
assign wv_cur_channel = dma_wr_dt_req_dout[98:96];

assign w_channel_empty =  (wv_cur_channel == `SRC_RTC) ? i_rtc_vtp_upload_empty :
                        (wv_cur_channel == `SRC_RRC) ? i_rrc_vtp_upload_empty :
                        (wv_cur_channel == `SRC_EEDT) ? i_ee_vtp_upload_empty : 1'b1;

assign wv_channel_dout = (wv_cur_channel == `SRC_RTC) ? iv_rtc_vtp_upload_data :
                        (wv_cur_channel == `SRC_RRC) ? iv_rrc_vtp_upload_data :
                        (wv_cur_channel == `SRC_EEDT) ? iv_ee_vtp_upload_data : 'd0;

assign o_rtc_vtp_upload_rd_en = (wv_cur_channel == `SRC_RTC) ? q_channel_rd_en : 1'b0;
assign o_rrc_vtp_upload_rd_en = (wv_cur_channel == `SRC_RRC) ? q_channel_rd_en : 1'b0;
assign o_ee_vtp_upload_rd_en = (wv_cur_channel == `SRC_EEDT) ? q_channel_rd_en : 1'b0;



//-- w_last_mtt_of_mpt --
assign w_last_mtt_of_mpt = (qv_mpt_req_length_left == qv_mtt_req_length_left);

parameter           REQ_IDLE_s = 2'b01,
                    REQ_UPLOAD_s = 2'b10;

reg                 [1:0]               req_cur_state;
reg                 [1:0]               req_next_state;
reg 				[1:0]				req_pre_state;

always @(posedge clk or posedge rst) begin
	if(rst) begin
		req_pre_state <= REQ_IDLE_s;
	end 
	else begin
		req_pre_state <= req_cur_state;
	end 
end 

always @(posedge clk or posedge rst) begin
    if(rst) begin
        req_cur_state <= REQ_IDLE_s;
    end
    else begin
        req_cur_state <= req_next_state;
    end
end

always @(*) begin
    case(req_cur_state) 
        REQ_IDLE_s:         if(!dma_wr_dt_req_empty && !w_channel_empty && dma_v2p_dt_wr_req_ready) begin
                                req_next_state = REQ_UPLOAD_s;
                            end    
                            else begin
                                req_next_state = REQ_IDLE_s;
                            end
        REQ_UPLOAD_s:       if(qv_mtt_req_length_left + qv_unwritten_len > 32) begin 
                                req_next_state = REQ_UPLOAD_s;
                            end     
                            else begin // <=32, judge whether need valid signal 
                                if(qv_mtt_req_length_left > 0 && !w_channel_empty && dma_v2p_dt_wr_req_ready) begin    //Need valid indicator
                                    req_next_state = REQ_IDLE_s;
                                end
                                else if(qv_mtt_req_length_left == 0 && dma_v2p_dt_wr_req_ready) begin
                                    req_next_state = REQ_IDLE_s;
                                end
                                else begin
                                    req_next_state = REQ_UPLOAD_s;
                                end
                            end         
        default:            req_next_state = REQ_IDLE_s;
    endcase
end

//-- qv_mtt_req_length_left --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_mtt_req_length_left <= 'd0;
    end
    else if(req_cur_state == REQ_IDLE_s && !dma_wr_dt_req_empty && !w_channel_empty) begin
        qv_mtt_req_length_left <= wv_cur_mtt_length - qv_unwritten_len;
    end
    else if(req_cur_state == REQ_UPLOAD_s) begin
        if(qv_mtt_req_length_left > 0 && !w_channel_empty && dma_v2p_dt_wr_req_ready) begin
            if(qv_mtt_req_length_left > 32) begin
                qv_mtt_req_length_left <= qv_mtt_req_length_left - 32;
            end
            else begin
                qv_mtt_req_length_left <= 'd0;
            end
        end
        else begin
            qv_mtt_req_length_left <= qv_mtt_req_length_left;
        end
    end
    else begin
        qv_mtt_req_length_left <= qv_mtt_req_length_left;
    end
end

//-- qv_mpt_req_length_left --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_mpt_req_length_left <= 'd0;
    end
    else if(req_cur_state == REQ_IDLE_s && !dma_wr_dt_req_empty && !w_channel_empty) begin
        if(qv_mpt_req_length_left == 0) begin
            qv_mpt_req_length_left <= wv_cur_mpt_length - qv_unwritten_len;
        end    
        else begin
            qv_mpt_req_length_left <= qv_mpt_req_length_left - qv_unwritten_len;
        end
    end
    else if(req_cur_state == REQ_UPLOAD_s) begin
        if(qv_mtt_req_length_left > 0 && !w_channel_empty && dma_v2p_dt_wr_req_ready) begin
            if(qv_mtt_req_length_left > 32) begin
                qv_mpt_req_length_left <= qv_mpt_req_length_left - 32;
            end
            else begin
                qv_mpt_req_length_left <= qv_mpt_req_length_left - qv_mtt_req_length_left;
            end
        end
        else begin
            qv_mpt_req_length_left <= qv_mpt_req_length_left;
        end
    end
    else begin
        qv_mpt_req_length_left <= qv_mpt_req_length_left;
    end
end

reg 			[31:0]			qv_offset;
always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_offset <= 'd0;
	end 
	else if((qv_mtt_req_length_left + qv_unwritten_len >= 32) && !w_channel_empty && dma_v2p_dt_wr_req_ready) begin
		qv_offset <= 32 - qv_unwritten_len;
	end 
	else begin
		qv_offset <= qv_offset;
	end 
end 

//-- qv_unwritten_len --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_unwritten_len <= 'd0;
    end
    else if(req_cur_state == REQ_IDLE_s) begin
        qv_unwritten_len <= qv_unwritten_len;
    end
    else if(req_cur_state == REQ_UPLOAD_s) begin //qv_unwritten_len need to consider wthether is the last mtt
        if(qv_mtt_req_length_left > 0 && !w_channel_empty && dma_v2p_dt_wr_req_ready) begin
            if(qv_mtt_req_length_left >= 32) begin
                qv_unwritten_len <= qv_unwritten_len;
            end
            else if(qv_mtt_req_length_left + qv_unwritten_len >= 32)begin
                qv_unwritten_len <= qv_mtt_req_length_left + qv_unwritten_len - 32;
            end
            else begin  
                qv_unwritten_len <= w_last_mtt_of_mpt ? 'd0 : (32 -  qv_mtt_req_length_left);
            end
        end  
        else if(qv_mtt_req_length_left == 0 && dma_v2p_dt_wr_req_ready) begin
            qv_unwritten_len <= w_last_mtt_of_mpt ? 'd0 : (32 - qv_unwritten_len - qv_offset);
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
    if(rst) begin
        qv_unwritten_data <= 'd0;
    end
    else if(req_cur_state == REQ_UPLOAD_s) begin
        if(qv_mtt_req_length_left > 0 && !w_channel_empty && dma_v2p_dt_wr_req_ready) begin
            if((qv_mtt_req_length_left >= 32) || (qv_mtt_req_length_left + qv_unwritten_len >= 32)) begin
                case(qv_unwritten_len)
                    0   :           qv_unwritten_data <= 'd0;
                    1   :           qv_unwritten_data <= {{((32 - 1 ) * 8){1'b0}}, wv_channel_dout[255 : (32 - 1 ) * 8]};
                    2   :           qv_unwritten_data <= {{((32 - 2 ) * 8){1'b0}}, wv_channel_dout[255 : (32 - 2 ) * 8]};
                    3   :           qv_unwritten_data <= {{((32 - 3 ) * 8){1'b0}}, wv_channel_dout[255 : (32 - 3 ) * 8]};
                    4   :           qv_unwritten_data <= {{((32 - 4 ) * 8){1'b0}}, wv_channel_dout[255 : (32 - 4 ) * 8]};
                    5   :           qv_unwritten_data <= {{((32 - 5 ) * 8){1'b0}}, wv_channel_dout[255 : (32 - 5 ) * 8]};
                    6   :           qv_unwritten_data <= {{((32 - 6 ) * 8){1'b0}}, wv_channel_dout[255 : (32 - 6 ) * 8]};
                    7   :           qv_unwritten_data <= {{((32 - 7 ) * 8){1'b0}}, wv_channel_dout[255 : (32 - 7 ) * 8]};
                    8   :           qv_unwritten_data <= {{((32 - 8 ) * 8){1'b0}}, wv_channel_dout[255 : (32 - 8 ) * 8]};
                    9   :           qv_unwritten_data <= {{((32 - 9 ) * 8){1'b0}}, wv_channel_dout[255 : (32 - 9 ) * 8]};
                    10  :           qv_unwritten_data <= {{((32 - 10) * 8){1'b0}}, wv_channel_dout[255 : (32 - 10) * 8]};
                    11  :           qv_unwritten_data <= {{((32 - 11) * 8){1'b0}}, wv_channel_dout[255 : (32 - 11) * 8]};
                    12  :           qv_unwritten_data <= {{((32 - 12) * 8){1'b0}}, wv_channel_dout[255 : (32 - 12) * 8]};
                    13  :           qv_unwritten_data <= {{((32 - 13) * 8){1'b0}}, wv_channel_dout[255 : (32 - 13) * 8]};
                    14  :           qv_unwritten_data <= {{((32 - 14) * 8){1'b0}}, wv_channel_dout[255 : (32 - 14) * 8]};
                    15  :           qv_unwritten_data <= {{((32 - 15) * 8){1'b0}}, wv_channel_dout[255 : (32 - 15) * 8]};
                    16  :           qv_unwritten_data <= {{((32 - 16) * 8){1'b0}}, wv_channel_dout[255 : (32 - 16) * 8]};
                    17  :           qv_unwritten_data <= {{((32 - 17) * 8){1'b0}}, wv_channel_dout[255 : (32 - 17) * 8]};
                    18  :           qv_unwritten_data <= {{((32 - 18) * 8){1'b0}}, wv_channel_dout[255 : (32 - 18) * 8]};
                    19  :           qv_unwritten_data <= {{((32 - 19) * 8){1'b0}}, wv_channel_dout[255 : (32 - 19) * 8]};
                    20  :           qv_unwritten_data <= {{((32 - 20) * 8){1'b0}}, wv_channel_dout[255 : (32 - 20) * 8]};
                    21  :           qv_unwritten_data <= {{((32 - 21) * 8){1'b0}}, wv_channel_dout[255 : (32 - 21) * 8]};
                    22  :           qv_unwritten_data <= {{((32 - 22) * 8){1'b0}}, wv_channel_dout[255 : (32 - 22) * 8]};
                    23  :           qv_unwritten_data <= {{((32 - 23) * 8){1'b0}}, wv_channel_dout[255 : (32 - 23) * 8]};
                    24  :           qv_unwritten_data <= {{((32 - 24) * 8){1'b0}}, wv_channel_dout[255 : (32 - 24) * 8]};
                    25  :           qv_unwritten_data <= {{((32 - 25) * 8){1'b0}}, wv_channel_dout[255 : (32 - 25) * 8]};
                    26  :           qv_unwritten_data <= {{((32 - 26) * 8){1'b0}}, wv_channel_dout[255 : (32 - 26) * 8]};
                    27  :           qv_unwritten_data <= {{((32 - 27) * 8){1'b0}}, wv_channel_dout[255 : (32 - 27) * 8]};
                    28  :           qv_unwritten_data <= {{((32 - 28) * 8){1'b0}}, wv_channel_dout[255 : (32 - 28) * 8]};
                    29  :           qv_unwritten_data <= {{((32 - 29) * 8){1'b0}}, wv_channel_dout[255 : (32 - 29) * 8]};
                    30  :           qv_unwritten_data <= {{((32 - 30) * 8){1'b0}}, wv_channel_dout[255 : (32 - 30) * 8]};
                    31  :           qv_unwritten_data <= {{((32 - 31) * 8){1'b0}}, wv_channel_dout[255 : (32 - 31) * 8]};
                    default:        qv_unwritten_data <= qv_unwritten_data;
                endcase
            end 
            else if(qv_mtt_req_length_left + qv_unwritten_len < 32) begin
                if(w_last_mtt_of_mpt) begin
                    qv_unwritten_data <= 'd0; 
                end
                else begin //piece together and wait for next ntt data
                    case(qv_mtt_req_length_left)
                        0   :           qv_unwritten_data <= wv_channel_dout;
                        1   :           qv_unwritten_data <= {{(32 - 1 )* 8{1'b0}},  wv_channel_dout[255 : 1  * 8]};
                        2   :           qv_unwritten_data <= {{(32 - 2 )* 8{1'b0}},  wv_channel_dout[255 : 2  * 8]};
                        3   :           qv_unwritten_data <= {{(32 - 3 )* 8{1'b0}},  wv_channel_dout[255 : 3  * 8]};
                        4   :           qv_unwritten_data <= {{(32 - 4 )* 8{1'b0}},  wv_channel_dout[255 : 4  * 8]};
                        5   :           qv_unwritten_data <= {{(32 - 5 )* 8{1'b0}},  wv_channel_dout[255 : 5  * 8]};
                        6   :           qv_unwritten_data <= {{(32 - 6 )* 8{1'b0}},  wv_channel_dout[255 : 6  * 8]};
                        7   :           qv_unwritten_data <= {{(32 - 7 )* 8{1'b0}},  wv_channel_dout[255 : 7  * 8]};
                        8   :           qv_unwritten_data <= {{(32 - 8 )* 8{1'b0}},  wv_channel_dout[255 : 8  * 8]};
                        9   :           qv_unwritten_data <= {{(32 - 9 )* 8{1'b0}},  wv_channel_dout[255 : 9  * 8]};
                        10  :           qv_unwritten_data <= {{(32 - 10)* 8{1'b0}},  wv_channel_dout[255 : 10 * 8]};
                        11  :           qv_unwritten_data <= {{(32 - 11)* 8{1'b0}},  wv_channel_dout[255 : 11 * 8]};
                        12  :           qv_unwritten_data <= {{(32 - 12)* 8{1'b0}},  wv_channel_dout[255 : 12 * 8]};
                        13  :           qv_unwritten_data <= {{(32 - 13)* 8{1'b0}},  wv_channel_dout[255 : 13 * 8]};
                        14  :           qv_unwritten_data <= {{(32 - 14)* 8{1'b0}},  wv_channel_dout[255 : 14 * 8]};
                        15  :           qv_unwritten_data <= {{(32 - 15)* 8{1'b0}},  wv_channel_dout[255 : 15 * 8]};
                        16  :           qv_unwritten_data <= {{(32 - 16)* 8{1'b0}},  wv_channel_dout[255 : 16 * 8]};
                        17  :           qv_unwritten_data <= {{(32 - 17)* 8{1'b0}},  wv_channel_dout[255 : 17 * 8]};
                        18  :           qv_unwritten_data <= {{(32 - 18)* 8{1'b0}},  wv_channel_dout[255 : 18 * 8]};
                        19  :           qv_unwritten_data <= {{(32 - 19)* 8{1'b0}},  wv_channel_dout[255 : 19 * 8]};
                        20  :           qv_unwritten_data <= {{(32 - 20)* 8{1'b0}},  wv_channel_dout[255 : 20 * 8]};
                        21  :           qv_unwritten_data <= {{(32 - 21)* 8{1'b0}},  wv_channel_dout[255 : 21 * 8]};
                        22  :           qv_unwritten_data <= {{(32 - 22)* 8{1'b0}},  wv_channel_dout[255 : 22 * 8]};
                        23  :           qv_unwritten_data <= {{(32 - 23)* 8{1'b0}},  wv_channel_dout[255 : 23 * 8]};
                        24  :           qv_unwritten_data <= {{(32 - 24)* 8{1'b0}},  wv_channel_dout[255 : 24 * 8]};
                        25  :           qv_unwritten_data <= {{(32 - 25)* 8{1'b0}},  wv_channel_dout[255 : 25 * 8]};
                        26  :           qv_unwritten_data <= {{(32 - 26)* 8{1'b0}},  wv_channel_dout[255 : 26 * 8]};
                        27  :           qv_unwritten_data <= {{(32 - 27)* 8{1'b0}},  wv_channel_dout[255 : 27 * 8]};
                        28  :           qv_unwritten_data <= {{(32 - 28)* 8{1'b0}},  wv_channel_dout[255 : 28 * 8]};
                        29  :           qv_unwritten_data <= {{(32 - 29)* 8{1'b0}},  wv_channel_dout[255 : 29 * 8]};
                        30  :           qv_unwritten_data <= {{(32 - 30) * 8{1'b0}}, wv_channel_dout[255 : 30 * 8]};
                        31  :           qv_unwritten_data <= {{(32 - 31) * 8{1'b0}}, wv_channel_dout[255 : 31 * 8]};
                        default:        qv_unwritten_data <= qv_unwritten_data;
                    endcase                    
                end
            end
            else begin
                qv_unwritten_data <= qv_unwritten_data;
            end
        end
        else if(qv_mtt_req_length_left == 0 && dma_v2p_dt_wr_req_ready) begin
			if(w_last_mtt_of_mpt) begin
				qv_unwritten_data <= 'd0;
			end 
			else begin
                case(qv_unwritten_len + qv_offset)
                    0   :           qv_unwritten_data <= wv_channel_dout;
                    1   :           qv_unwritten_data <= {{(32 - 1 )* 8{1'b0}},  wv_channel_dout[255 : 1  * 8]};
                    2   :           qv_unwritten_data <= {{(32 - 2 )* 8{1'b0}},  wv_channel_dout[255 : 2  * 8]};
                    3   :           qv_unwritten_data <= {{(32 - 3 )* 8{1'b0}},  wv_channel_dout[255 : 3  * 8]};
                    4   :           qv_unwritten_data <= {{(32 - 4 )* 8{1'b0}},  wv_channel_dout[255 : 4  * 8]};
                    5   :           qv_unwritten_data <= {{(32 - 5 )* 8{1'b0}},  wv_channel_dout[255 : 5  * 8]};
                    6   :           qv_unwritten_data <= {{(32 - 6 )* 8{1'b0}},  wv_channel_dout[255 : 6  * 8]};
                    7   :           qv_unwritten_data <= {{(32 - 7 )* 8{1'b0}},  wv_channel_dout[255 : 7  * 8]};
                    8   :           qv_unwritten_data <= {{(32 - 8 )* 8{1'b0}},  wv_channel_dout[255 : 8  * 8]};
                    9   :           qv_unwritten_data <= {{(32 - 9 )* 8{1'b0}},  wv_channel_dout[255 : 9  * 8]};
                    10  :           qv_unwritten_data <= {{(32 - 10)* 8{1'b0}},  wv_channel_dout[255 : 10 * 8]};
                    11  :           qv_unwritten_data <= {{(32 - 11)* 8{1'b0}},  wv_channel_dout[255 : 11 * 8]};
                    12  :           qv_unwritten_data <= {{(32 - 12)* 8{1'b0}},  wv_channel_dout[255 : 12 * 8]};
                    13  :           qv_unwritten_data <= {{(32 - 13)* 8{1'b0}},  wv_channel_dout[255 : 13 * 8]};
                    14  :           qv_unwritten_data <= {{(32 - 14)* 8{1'b0}},  wv_channel_dout[255 : 14 * 8]};
                    15  :           qv_unwritten_data <= {{(32 - 15)* 8{1'b0}},  wv_channel_dout[255 : 15 * 8]};
                    16  :           qv_unwritten_data <= {{(32 - 16)* 8{1'b0}},  wv_channel_dout[255 : 16 * 8]};
                    17  :           qv_unwritten_data <= {{(32 - 17)* 8{1'b0}},  wv_channel_dout[255 : 17 * 8]};
                    18  :           qv_unwritten_data <= {{(32 - 18)* 8{1'b0}},  wv_channel_dout[255 : 18 * 8]};
                    19  :           qv_unwritten_data <= {{(32 - 19)* 8{1'b0}},  wv_channel_dout[255 : 19 * 8]};
                    20  :           qv_unwritten_data <= {{(32 - 20)* 8{1'b0}},  wv_channel_dout[255 : 20 * 8]};
                    21  :           qv_unwritten_data <= {{(32 - 21)* 8{1'b0}},  wv_channel_dout[255 : 21 * 8]};
                    22  :           qv_unwritten_data <= {{(32 - 22)* 8{1'b0}},  wv_channel_dout[255 : 22 * 8]};
                    23  :           qv_unwritten_data <= {{(32 - 23)* 8{1'b0}},  wv_channel_dout[255 : 23 * 8]};
                    24  :           qv_unwritten_data <= {{(32 - 24)* 8{1'b0}},  wv_channel_dout[255 : 24 * 8]};
                    25  :           qv_unwritten_data <= {{(32 - 25)* 8{1'b0}},  wv_channel_dout[255 : 25 * 8]};
                    26  :           qv_unwritten_data <= {{(32 - 26)* 8{1'b0}},  wv_channel_dout[255 : 26 * 8]};
                    27  :           qv_unwritten_data <= {{(32 - 27)* 8{1'b0}},  wv_channel_dout[255 : 27 * 8]};
                    28  :           qv_unwritten_data <= {{(32 - 28)* 8{1'b0}},  wv_channel_dout[255 : 28 * 8]};
                    29  :           qv_unwritten_data <= {{(32 - 29)* 8{1'b0}},  wv_channel_dout[255 : 29 * 8]};
                    30  :           qv_unwritten_data <= {{(32 - 30) * 8{1'b0}}, wv_channel_dout[255 : 30 * 8]};
                    31  :           qv_unwritten_data <= {{(32 - 31) * 8{1'b0}}, wv_channel_dout[255 : 31 * 8]};
                    default:        qv_unwritten_data <= qv_unwritten_data;
				endcase
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

//-- q_dma_v2p_dt_wr_req_valid --
always @(*) begin
    if(rst) begin
        q_dma_v2p_dt_wr_req_valid = 'd0;
    end  
    else if(req_cur_state == REQ_UPLOAD_s) begin
        //if(qv_mtt_req_length_left > 0 && !w_channel_empty && dma_v2p_dt_wr_req_ready) begin
        //    if((qv_mtt_req_length_left >= 32) || (qv_mtt_req_length_left + qv_unwritten_len >= 32)) begin
        //        q_dma_v2p_dt_wr_req_valid = 'd1;
        //    end
        //    else if(qv_mtt_req_length_left + qv_unwritten_len < 32) begin
        //        q_dma_v2p_dt_wr_req_valid = w_last_mtt_of_mpt ? 'd1 : 'd0;     
        //    end
        //    else begin
        //        q_dma_v2p_dt_wr_req_valid = 'd0;
        //    end
        //end
        //else if(qv_mtt_req_length_left == 0 && dma_v2p_dt_wr_req_ready) begin
        //    q_dma_v2p_dt_wr_req_valid = w_last_mtt_of_mpt ? 'd1 : 'd0;
        //end
		//else begin
		//	q_dma_v2p_dt_wr_req_valid = 'd0;
		//end 
		if(qv_mtt_req_length_left > 0 && !w_channel_empty && dma_v2p_dt_wr_req_ready) begin
			q_dma_v2p_dt_wr_req_valid = 'd1;
		end
		else if(qv_mtt_req_length_left == 0 && dma_v2p_dt_wr_req_ready) begin
			q_dma_v2p_dt_wr_req_valid = 'd1;
		end 
		else begin
			q_dma_v2p_dt_wr_req_valid = 'd0;
		end 
    end
    else begin
        q_dma_v2p_dt_wr_req_valid = 'd0;
    end
end

//-- dma_v2p_dt_wr_req_data --
always @(*) begin
    if(rst) begin
        qv_dma_v2p_dt_wr_req_data = 'd0;
    end  
    else if(req_cur_state == REQ_UPLOAD_s) begin
        if(qv_mtt_req_length_left > 0 && !w_channel_empty && dma_v2p_dt_wr_req_ready) begin
            if((qv_mtt_req_length_left >= 32) || (qv_mtt_req_length_left + qv_unwritten_len >= 32)) begin
                case(qv_unwritten_len)
                    0   :           qv_dma_v2p_dt_wr_req_data = wv_channel_dout;
                    1   :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 1 ) * 8 - 1 : 0], qv_unwritten_data[1  * 8 - 1 : 0]};
                    2   :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 2 ) * 8 - 1 : 0], qv_unwritten_data[2  * 8 - 1 : 0]};
                    3   :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 3 ) * 8 - 1 : 0], qv_unwritten_data[3  * 8 - 1 : 0]};
                    4   :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 4 ) * 8 - 1 : 0], qv_unwritten_data[4  * 8 - 1 : 0]};
                    5   :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 5 ) * 8 - 1 : 0], qv_unwritten_data[5  * 8 - 1 : 0]};
                    6   :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 6 ) * 8 - 1 : 0], qv_unwritten_data[6  * 8 - 1 : 0]};
                    7   :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 7 ) * 8 - 1 : 0], qv_unwritten_data[7  * 8 - 1 : 0]};
                    8   :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 8 ) * 8 - 1 : 0], qv_unwritten_data[8  * 8 - 1 : 0]};
                    9   :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 9 ) * 8 - 1 : 0], qv_unwritten_data[9  * 8 - 1 : 0]};
                    10  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 10) * 8 - 1 : 0], qv_unwritten_data[10 * 8 - 1 : 0]};
                    11  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 11) * 8 - 1 : 0], qv_unwritten_data[11 * 8 - 1 : 0]};
                    12  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 12) * 8 - 1 : 0], qv_unwritten_data[12 * 8 - 1 : 0]};
                    13  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 13) * 8 - 1 : 0], qv_unwritten_data[13 * 8 - 1 : 0]};
                    14  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 14) * 8 - 1 : 0], qv_unwritten_data[14 * 8 - 1 : 0]};
                    15  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 15) * 8 - 1 : 0], qv_unwritten_data[15 * 8 - 1 : 0]};
                    16  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 16) * 8 - 1 : 0], qv_unwritten_data[16 * 8 - 1 : 0]};
                    17  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 17) * 8 - 1 : 0], qv_unwritten_data[17 * 8 - 1 : 0]};
                    18  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 18) * 8 - 1 : 0], qv_unwritten_data[18 * 8 - 1 : 0]};
                    19  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 19) * 8 - 1 : 0], qv_unwritten_data[19 * 8 - 1 : 0]};
                    20  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 20) * 8 - 1 : 0], qv_unwritten_data[20 * 8 - 1 : 0]};
                    21  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 21) * 8 - 1 : 0], qv_unwritten_data[21 * 8 - 1 : 0]};
                    22  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 22) * 8 - 1 : 0], qv_unwritten_data[22 * 8 - 1 : 0]};
                    23  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 23) * 8 - 1 : 0], qv_unwritten_data[23 * 8 - 1 : 0]};
                    24  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 24) * 8 - 1 : 0], qv_unwritten_data[24 * 8 - 1 : 0]};
                    25  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 25) * 8 - 1 : 0], qv_unwritten_data[25 * 8 - 1 : 0]};
                    26  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 26) * 8 - 1 : 0], qv_unwritten_data[26 * 8 - 1 : 0]};
                    27  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 27) * 8 - 1 : 0], qv_unwritten_data[27 * 8 - 1 : 0]};
                    28  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 28) * 8 - 1 : 0], qv_unwritten_data[28 * 8 - 1 : 0]};
                    29  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 29) * 8 - 1 : 0], qv_unwritten_data[29 * 8 - 1 : 0]};
                    30  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 30) * 8 - 1 : 0], qv_unwritten_data[30 * 8 - 1 : 0]};
                    31  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 31) * 8 - 1 : 0], qv_unwritten_data[31 * 8 - 1 : 0]};
                    default:        qv_dma_v2p_dt_wr_req_data = qv_dma_v2p_dt_wr_req_data_diff;
                endcase
            end
            else if(qv_mtt_req_length_left + qv_unwritten_len < 32) begin
                case(qv_unwritten_len)
                    0   :           qv_dma_v2p_dt_wr_req_data = wv_channel_dout;
                    1   :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 1 ) * 8 - 1 : 0], qv_unwritten_data[1  * 8 - 1 : 0]};
                    2   :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 2 ) * 8 - 1 : 0], qv_unwritten_data[2  * 8 - 1 : 0]};
                    3   :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 3 ) * 8 - 1 : 0], qv_unwritten_data[3  * 8 - 1 : 0]};
                    4   :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 4 ) * 8 - 1 : 0], qv_unwritten_data[4  * 8 - 1 : 0]};
                    5   :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 5 ) * 8 - 1 : 0], qv_unwritten_data[5  * 8 - 1 : 0]};
                    6   :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 6 ) * 8 - 1 : 0], qv_unwritten_data[6  * 8 - 1 : 0]};
                    7   :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 7 ) * 8 - 1 : 0], qv_unwritten_data[7  * 8 - 1 : 0]};
                    8   :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 8 ) * 8 - 1 : 0], qv_unwritten_data[8  * 8 - 1 : 0]};
                    9   :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 9 ) * 8 - 1 : 0], qv_unwritten_data[9  * 8 - 1 : 0]};
                    10  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 10) * 8 - 1 : 0], qv_unwritten_data[10 * 8 - 1 : 0]};
                    11  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 11) * 8 - 1 : 0], qv_unwritten_data[11 * 8 - 1 : 0]};
                    12  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 12) * 8 - 1 : 0], qv_unwritten_data[12 * 8 - 1 : 0]};
                    13  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 13) * 8 - 1 : 0], qv_unwritten_data[13 * 8 - 1 : 0]};
                    14  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 14) * 8 - 1 : 0], qv_unwritten_data[14 * 8 - 1 : 0]};
                    15  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 15) * 8 - 1 : 0], qv_unwritten_data[15 * 8 - 1 : 0]};
                    16  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 16) * 8 - 1 : 0], qv_unwritten_data[16 * 8 - 1 : 0]};
                    17  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 17) * 8 - 1 : 0], qv_unwritten_data[17 * 8 - 1 : 0]};
                    18  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 18) * 8 - 1 : 0], qv_unwritten_data[18 * 8 - 1 : 0]};
                    19  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 19) * 8 - 1 : 0], qv_unwritten_data[19 * 8 - 1 : 0]};
                    20  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 20) * 8 - 1 : 0], qv_unwritten_data[20 * 8 - 1 : 0]};
                    21  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 21) * 8 - 1 : 0], qv_unwritten_data[21 * 8 - 1 : 0]};
                    22  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 22) * 8 - 1 : 0], qv_unwritten_data[22 * 8 - 1 : 0]};
                    23  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 23) * 8 - 1 : 0], qv_unwritten_data[23 * 8 - 1 : 0]};
                    24  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 24) * 8 - 1 : 0], qv_unwritten_data[24 * 8 - 1 : 0]};
                    25  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 25) * 8 - 1 : 0], qv_unwritten_data[25 * 8 - 1 : 0]};
                    26  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 26) * 8 - 1 : 0], qv_unwritten_data[26 * 8 - 1 : 0]};
                    27  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 27) * 8 - 1 : 0], qv_unwritten_data[27 * 8 - 1 : 0]};
                    28  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 28) * 8 - 1 : 0], qv_unwritten_data[28 * 8 - 1 : 0]};
                    29  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 29) * 8 - 1 : 0], qv_unwritten_data[29 * 8 - 1 : 0]};
                    30  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 30) * 8 - 1 : 0], qv_unwritten_data[30 * 8 - 1 : 0]};
                    31  :           qv_dma_v2p_dt_wr_req_data = {wv_channel_dout[(32 - 31) * 8 - 1 : 0], qv_unwritten_data[31 * 8 - 1 : 0]};
                    default:        qv_dma_v2p_dt_wr_req_data = qv_dma_v2p_dt_wr_req_data_diff;
                endcase                           
            end
            else begin
                qv_dma_v2p_dt_wr_req_data = qv_dma_v2p_dt_wr_req_data_diff;
            end
        end
        else if(qv_mtt_req_length_left == 0 && dma_v2p_dt_wr_req_ready) begin
            qv_dma_v2p_dt_wr_req_data = qv_unwritten_data;
        end
		else begin
			qv_dma_v2p_dt_wr_req_data = qv_dma_v2p_dt_wr_req_data_diff;
		end 
    end
    else begin
        qv_dma_v2p_dt_wr_req_data = qv_dma_v2p_dt_wr_req_data_diff;
    end
end



//-- dma_v2p_dt_wr_req_head --
always @(*) begin
    if(rst) begin
        qv_dma_v2p_dt_wr_req_head = 'd0;
    end
    else if(req_pre_state == REQ_IDLE_s && req_cur_state == REQ_UPLOAD_s) begin
        qv_dma_v2p_dt_wr_req_head = {dma_wr_dt_req_dout[63:0], dma_wr_dt_req_dout[95:64]};
    end
    else begin
        qv_dma_v2p_dt_wr_req_head = 'd0;
    end
end

//-- q_dma_v2p_dt_wr_req_last --
always @(*) begin
    if(rst) begin
        q_dma_v2p_dt_wr_req_last = 'd0;
    end
    else if(req_cur_state == REQ_UPLOAD_s) begin
        if(qv_mtt_req_length_left + qv_unwritten_len <= 32) begin
            if(qv_mtt_req_length_left > 0 && !w_channel_empty && dma_v2p_dt_wr_req_ready) begin
                q_dma_v2p_dt_wr_req_last = 'd1;
            end 
            else if(qv_mtt_req_length_left == 0 && dma_v2p_dt_wr_req_ready) begin
                q_dma_v2p_dt_wr_req_last = 'd1;
            end
            else begin
                q_dma_v2p_dt_wr_req_last = 'd0;
            end
        end 
        else begin
            q_dma_v2p_dt_wr_req_last = 'd0;
        end
    end
    else begin
        q_dma_v2p_dt_wr_req_last = 'd0;
    end
end

//-- q_channel_rd_en --
always @(*) begin
    if(rst) begin
        q_channel_rd_en = 'd0;
    end
    else if(req_cur_state == REQ_UPLOAD_s) begin
        if(qv_mtt_req_length_left > 0 && !w_channel_empty && dma_v2p_dt_wr_req_ready) begin
            q_channel_rd_en = 'd1;
        end
        else begin
            q_channel_rd_en = 'd0;
        end
    end
    else begin
        q_channel_rd_en = 'd0;
    end
end

assign dma_wr_dt_req_rd_en = (req_cur_state == REQ_UPLOAD_s) && (req_next_state == REQ_IDLE_s);

`ifdef V2P_DUG
    assign wv_dbg_bus_wrdt = {
            (`WRDT_DBG_REG_NUM * 32){1'b0}
    };

`endif 

endmodule
