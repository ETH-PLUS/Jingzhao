//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: dma_read_data.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V0.0 
// VERSION DESCRIPTION: 4st Edition  
//----------------------------------------------------
// RELEASE DATE: 2022-07-13 
//---------------------------------------------------- 
// PURPOSE:get the mtt_ram_ctl dma request, read data from host memory, and send the data to the dest request channel.
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
//----------------------------------------------------
// Description: 
// (1) independented DMA channel for DMA data processing(including request and response)
//-FHDR-----------------------------------------------

//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_v2p_h.vh"

module dma_read_data#(
    parameter DMA_DT_REQ_WIDTH  = 134//mtt_ram_ctl to dma_read/write_data req header fifo
    )(
    input clk,
    input rst,
//------------------interface to dma_read_data module-------------
    //-mtt_ram_ctl--dma_read_data req header format
    //high-----------------------------low
    //|-------------------134 bit--------------------|
    //| total len |opcode | dest/src |tmp len | addr |
    //| 32        |   3   |     3    | 32     |  64  |
    //|----------------------------------------------|
    output  wire                            dma_rd_dt_req_rd_en,
    input   wire                            dma_rd_dt_req_empty,
    input   wire  [DMA_DT_REQ_WIDTH-1:0]    dma_rd_dt_req_dout,

//Interface with RDMA Engine
    //Channel 1 for Doorbell Processing, only read
    //Channel 3 for WQEParser, download network data
    output  wire                 o_wp_vtp_nd_download_wr_en,
    input   wire                i_wp_vtp_nd_download_prog_full,
    output  wire     [255:0]     ov_wp_vtp_nd_download_data,

    //Channel 7 for ExecutionEngine, upload Send/Write Payload and download Read Payload
    output  wire                 o_ee_vtp_download_wr_en,
    input   wire                i_ee_vtp_download_prog_full,
    output  wire     [255:0]     ov_ee_vtp_download_data,

//Interface with DMA Engine
   
    //Channel 3 DMA Read Data(/Network Data) Request
    output  wire                           dma_v2p_dt_rd_req_valid,
    output  wire                           dma_v2p_dt_rd_req_last ,
    output  wire [(`DT_WIDTH-1):0]         dma_v2p_dt_rd_req_data ,
    output  wire [(`HD_WIDTH-1):0]         dma_v2p_dt_rd_req_head ,
    input   wire                           dma_v2p_dt_rd_req_ready,
    //Channel 3 DMA Read Data(Network Data) Response
    output  wire                           dma_v2p_dt_rd_rsp_tready,
    input   wire                           dma_v2p_dt_rd_rsp_tvalid,
    input   wire [`DT_WIDTH-1:0]           dma_v2p_dt_rd_rsp_tdata,
    input   wire                           dma_v2p_dt_rd_rsp_tlast,
    input   wire [`HD_WIDTH-1:0]           dma_v2p_dt_rd_rsp_theader

    `ifdef V2P_DUG
    //apb_slave
        ,  input wire [`RDDT_DBG_RW_NUM * 32 - 1 : 0]   rw_data
        ,  output wire [`RDDT_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_rddt
    `endif


);

//store dma read network data request(include Total legnth,Op,Src,length,phy-addr)   
wire                            bkup_dma_rd_dt_req_rd_en;
wire                            bkup_dma_rd_dt_req_empty;
wire  [DMA_DT_REQ_WIDTH-1:0]    bkup_dma_rd_dt_req_dout;  
wire                            bkup_dma_rd_dt_req_prog_full;
wire                            bkup_dma_rd_dt_req_wr_en;
wire  [DMA_DT_REQ_WIDTH-1:0]    bkup_dma_rd_dt_req_din;

bkup_dma_rd_dt_req_fifo_134w64d bkup_dma_rd_dt_req_fifo_134w64d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (bkup_dma_rd_dt_req_wr_en),
        .rd_en      (bkup_dma_rd_dt_req_rd_en),
        .din        (bkup_dma_rd_dt_req_din),
        .dout       (bkup_dma_rd_dt_req_dout),
        .full       (),
        .empty      (bkup_dma_rd_dt_req_empty),     
        .prog_full  (bkup_dma_rd_dt_req_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[0 * 32 +: 1 * 32])        
    `endif
);   


//---------------------{initiate mtt dma read req process} begin-------------------------
    //state machine
    // read dma request from mtt_ram_ctl
    localparam  REQ_READ   = 2'b01; 
    // initiate dma requestes to DMA engine 
    localparam  DMA_INIT   = 2'b10; 
    
    reg [1:0] dma_fsm_cs;
    reg [1:0] dma_fsm_ns;
    //-----------------Stage 1 :State Register----------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dma_fsm_cs <= `TD REQ_READ;
        end
        else begin
            dma_fsm_cs <= `TD dma_fsm_ns;
        end
    end
    //-----------------Stage 2 :State Transition----------
    always @(*) begin
        case (dma_fsm_cs)
            REQ_READ: begin
                if(!dma_rd_dt_req_empty && dma_v2p_dt_rd_req_ready && !bkup_dma_rd_dt_req_prog_full) begin
                    dma_fsm_ns = DMA_INIT;
                end else begin
                    dma_fsm_ns = REQ_READ;
                end
            end 
            DMA_INIT: begin
                if (dma_v2p_dt_rd_req_ready && !bkup_dma_rd_dt_req_prog_full) begin
                    dma_fsm_ns = REQ_READ;
                end
                else begin
                    dma_fsm_ns = DMA_INIT;
                end
            end
            default: dma_fsm_ns = REQ_READ;
        endcase
    end
    //-----------------Stage 3 :Output Decode------------------

    //read DMA read data request from mtt_ram_ctl
        //input   wire                            dma_rd_dt_req_rd_en,
        //output  wire                            dma_rd_dt_req_empty,
        //output  wire  [DMA_DT_REQ_WIDTH-1:0]    dma_rd_dt_req_dout,
    assign dma_rd_dt_req_rd_en = (!dma_rd_dt_req_empty && dma_v2p_dt_rd_req_ready && !bkup_dma_rd_dt_req_prog_full && (dma_fsm_cs == REQ_READ)) ? 1 : 0;
    reg  [DMA_DT_REQ_WIDTH-1:0]    qv_dma_rd_dt_req_dout;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_dma_rd_dt_req_dout <= `TD 134'b0;
        end else begin
            if (dma_rd_dt_req_rd_en) begin
                qv_dma_rd_dt_req_dout <= `TD dma_rd_dt_req_dout;
            end 
            else if (dma_fsm_cs == DMA_INIT) begin
                qv_dma_rd_dt_req_dout <= `TD qv_dma_rd_dt_req_dout;
            end else begin
                qv_dma_rd_dt_req_dout <= `TD 134'b0;
            end
        end
    end
    //Interface with DMA Engine
        //Channel 3 DMA Read Data(WQE/Network Data) Request
        //output  wire                           dma_v2p_dt_rd_req_valid,
        //output  wire                           dma_v2p_dt_rd_req_last ,
        //output  wire [(`DT_WIDTH-1):0]         dma_v2p_dt_rd_req_data ,
        //output  wire [(`HD_WIDTH-1):0]         dma_v2p_dt_rd_req_head ,
        /* dma_*_head(interact with DMA modules), valid only in first beat of a packet
         * | Reserved | address | Reserved | Byte length |
         * |  127:96  |  95:32  |  31:12   |    11:0     |
         */
    // assign dma_v2p_dt_rd_req_valid = dma_rd_dt_req_rd_en ? 1 : 0;
    // assign dma_v2p_dt_rd_req_last  = dma_rd_dt_req_rd_en ? 1 : 0;
    // assign dma_v2p_dt_rd_req_data  = 0;
    // assign dma_v2p_dt_rd_req_head  = dma_rd_dt_req_rd_en ? {32'b0,dma_rd_dt_req_dout[63:0],dma_rd_dt_req_dout[95:64]} : 0;

    reg                           qv_dma_v2p_dt_rd_req_valid;
    reg                           qv_dma_v2p_dt_rd_req_last ;
    // reg [(`DT_WIDTH-1):0]         qv_dma_v2p_dt_rd_req_data ;
    reg [(`HD_WIDTH-1-32):0]         qv_dma_v2p_dt_rd_req_head ;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_dma_v2p_dt_rd_req_valid <= `TD 1'b0;
            qv_dma_v2p_dt_rd_req_last  <= `TD 1'b0;
            // qv_dma_v2p_dt_rd_req_data  <= `TD 256'b0;
            qv_dma_v2p_dt_rd_req_head  <= `TD 96'b0;
        end else begin
           if (dma_v2p_dt_rd_req_ready && !bkup_dma_rd_dt_req_prog_full && (dma_fsm_cs == DMA_INIT)) begin
                qv_dma_v2p_dt_rd_req_valid <= `TD 1'b1;
                qv_dma_v2p_dt_rd_req_last  <= `TD 1'b1;
                // qv_dma_v2p_dt_rd_req_data  <= `TD 256'b0;
                // qv_dma_v2p_dt_rd_req_head  <= `TD {32'b0,qv_dma_rd_dt_req_dout[63:0],qv_dma_rd_dt_req_dout[95:64]};
                qv_dma_v2p_dt_rd_req_head  <= `TD {qv_dma_rd_dt_req_dout[63:0],qv_dma_rd_dt_req_dout[95:64]};
           end else begin
                qv_dma_v2p_dt_rd_req_valid <= `TD 1'b0;
                qv_dma_v2p_dt_rd_req_last  <= `TD 1'b0;
                // qv_dma_v2p_dt_rd_req_data  <= `TD 256'b0;
                qv_dma_v2p_dt_rd_req_head  <= `TD 96'b0;
           end 
        end
    end
   
    assign dma_v2p_dt_rd_req_valid = qv_dma_v2p_dt_rd_req_valid;
    assign dma_v2p_dt_rd_req_last  = qv_dma_v2p_dt_rd_req_last ;
    assign dma_v2p_dt_rd_req_data  = 256'b0;
    assign dma_v2p_dt_rd_req_head  = {32'b0,qv_dma_v2p_dt_rd_req_head} ;

    //backup dma read data request for processing response data
        //wire                            bkup_dma_rd_dt_req_prog_full;
        //wire                            bkup_dma_rd_dt_req_wr_en;
        //wire  [DMA_DT_REQ_WIDTH-1:0]    bkup_dma_rd_dt_req_din;
    assign bkup_dma_rd_dt_req_wr_en = dma_rd_dt_req_rd_en ? 1 : 0;
    assign bkup_dma_rd_dt_req_din   = dma_rd_dt_req_rd_en ? dma_rd_dt_req_dout : 0;
//---------------------{initiate mtt dma read req process} end-------------------------

//---------------------{dma read response process} begin-------------------------
reg                                     q_download_wr_en;
reg                 [255:0]             qv_download_data;               

reg 				[2:0]				qv_cur_channel;

reg                 [31:0]              qv_mpt_req_length_left;
reg                 [31:0]              qv_mtt_req_length_left;
reg                 [31:0]              qv_unwritten_len;
reg                 [255:0]             qv_unwritten_data;
wire                                    w_last_mtt_of_mpt;
wire                                    w_next_stage_prog_full;



/*DMA Read Response State Machine */
parameter               RESPONSE_IDLE_s = 2'b01,
						RESPONSE_DOWNLOAD_s = 2'b10;

reg                     [1:0]           response_cur_state;
reg                     [1:0]           response_next_state;

always @(posedge clk or posedge rst) begin
    if(rst) begin 
        response_cur_state <= RESPONSE_IDLE_s;
    end
    else begin
        response_cur_state <= response_next_state;
    end
end

always @(*) begin
    case(response_cur_state)
        RESPONSE_IDLE_s:            if(!bkup_dma_rd_dt_req_empty) begin
                                        response_next_state = RESPONSE_DOWNLOAD_s;
                                    end
                                    else begin
                                        response_next_state = RESPONSE_IDLE_s;
                                    end
        RESPONSE_DOWNLOAD_s:        if(qv_mtt_req_length_left + qv_unwritten_len > 32) begin 
                                        response_next_state = RESPONSE_DOWNLOAD_s;
                                    end     
                                    else begin // <=32, judge whether need valid signal 
                                        if(qv_mtt_req_length_left > 0 && dma_v2p_dt_rd_rsp_tvalid && !w_next_stage_prog_full) begin    //Need valid indicator
                                            response_next_state = RESPONSE_IDLE_s;
                                        end
                                        else if(qv_mtt_req_length_left == 0 && !w_next_stage_prog_full) begin
                                            response_next_state = RESPONSE_IDLE_s;
                                        end
                                        else begin
                                            response_next_state = RESPONSE_DOWNLOAD_s;
                                        end
                                    end         
        default:                    response_next_state = RESPONSE_IDLE_s;
    endcase
end


//-- w_last_mtt_of_mpt --
assign w_last_mtt_of_mpt = (qv_mpt_req_length_left == qv_mtt_req_length_left);

//-- w_next_stage_prog_full --
assign w_next_stage_prog_full = (!bkup_dma_rd_dt_req_empty && bkup_dma_rd_dt_req_dout[98:96] == `DEST_WPDT) ? i_wp_vtp_nd_download_prog_full : 
                                (!bkup_dma_rd_dt_req_empty && bkup_dma_rd_dt_req_dout[98:96] == `DEST_EEDT) ? i_ee_vtp_download_prog_full : 1'b1;

//-- bkup_dma_rd_dt_req_rd_en --
assign bkup_dma_rd_dt_req_rd_en = (response_cur_state == RESPONSE_DOWNLOAD_s) && (qv_mtt_req_length_left + qv_unwritten_len <= 32) && !w_next_stage_prog_full && 
                                    ((qv_mtt_req_length_left > 0 && dma_v2p_dt_rd_rsp_tvalid) || (qv_mtt_req_length_left == 0));


//-- dma_v2p_dt_rd_rsp_tready --
assign dma_v2p_dt_rd_rsp_tready = (response_cur_state == RESPONSE_DOWNLOAD_s) && !w_next_stage_prog_full && (qv_mtt_req_length_left > 0);

assign o_wp_vtp_nd_download_wr_en = (qv_cur_channel == `DEST_WPDT) ? q_download_wr_en : 'd0;
assign ov_wp_vtp_nd_download_data = (qv_cur_channel == `DEST_WPDT) ? qv_download_data : 'd0;

assign o_ee_vtp_download_wr_en = (qv_cur_channel == `DEST_EEDT) ? q_download_wr_en : 'd0;
assign ov_ee_vtp_download_data = (qv_cur_channel == `DEST_EEDT) ? qv_download_data : 'd0;

//-- qv_cur_channel --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_cur_channel <= 'd0;
	end 
	else if(response_cur_state == RESPONSE_IDLE_s && !bkup_dma_rd_dt_req_empty) begin
		qv_cur_channel <= bkup_dma_rd_dt_req_dout[98:96];
	end 
	else begin
		qv_cur_channel <= qv_cur_channel;
	end 
end 

//-- qv_mtt_req_length_left --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_mtt_req_length_left <= 'd0;
    end
    else if(response_cur_state == RESPONSE_IDLE_s && !bkup_dma_rd_dt_req_empty) begin
        qv_mtt_req_length_left <= bkup_dma_rd_dt_req_dout[95:64];
    end
    else if(response_cur_state == RESPONSE_DOWNLOAD_s) begin
        if(qv_mtt_req_length_left > 0 && dma_v2p_dt_rd_rsp_tvalid && !w_next_stage_prog_full) begin
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
    else if(response_cur_state == RESPONSE_IDLE_s && !bkup_dma_rd_dt_req_empty) begin
        if(qv_mpt_req_length_left == 0) begin
            qv_mpt_req_length_left <= bkup_dma_rd_dt_req_dout[133:102];
        end    
        else begin
            qv_mpt_req_length_left <= qv_mpt_req_length_left;
        end
    end
    else if(response_cur_state == RESPONSE_DOWNLOAD_s) begin
        if(qv_mtt_req_length_left > 0 && dma_v2p_dt_rd_rsp_tvalid && !w_next_stage_prog_full) begin
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

//-- qv_unwritten_len --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_unwritten_len <= 'd0;
    end
    else if(response_cur_state == RESPONSE_IDLE_s) begin
        qv_unwritten_len <= qv_unwritten_len;
    end
    else if(response_cur_state == RESPONSE_DOWNLOAD_s) begin //qv_unwritten_len need to consider wthether is the last mtt
        if(qv_mtt_req_length_left > 0 && dma_v2p_dt_rd_rsp_tvalid && !w_next_stage_prog_full) begin
            if(qv_mtt_req_length_left >= 32) begin
                qv_unwritten_len <= qv_unwritten_len;
            end
            else if(qv_mtt_req_length_left + qv_unwritten_len >= 32)begin
                qv_unwritten_len <= qv_mtt_req_length_left + qv_unwritten_len - 32;
            end
            else begin  
                qv_unwritten_len <= w_last_mtt_of_mpt ? 'd0 : (qv_mtt_req_length_left + qv_unwritten_len);
            end
        end  
        else if(qv_mtt_req_length_left == 0 && !w_next_stage_prog_full) begin
            qv_unwritten_len <= w_last_mtt_of_mpt ? 'd0 : qv_unwritten_len;
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
    else if(response_cur_state == RESPONSE_DOWNLOAD_s) begin
        if(qv_mtt_req_length_left > 0 && dma_v2p_dt_rd_rsp_tvalid && !w_next_stage_prog_full) begin
            if((qv_mtt_req_length_left >= 32) || (qv_mtt_req_length_left + qv_unwritten_len >= 32)) begin
                case(qv_unwritten_len)
                    0   :           qv_unwritten_data <= 'd0;
                    1   :           qv_unwritten_data <= {{((32 - 1 ) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 1 ) * 8]};
                    2   :           qv_unwritten_data <= {{((32 - 2 ) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 2 ) * 8]};
                    3   :           qv_unwritten_data <= {{((32 - 3 ) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 3 ) * 8]};
                    4   :           qv_unwritten_data <= {{((32 - 4 ) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 4 ) * 8]};
                    5   :           qv_unwritten_data <= {{((32 - 5 ) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 5 ) * 8]};
                    6   :           qv_unwritten_data <= {{((32 - 6 ) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 6 ) * 8]};
                    7   :           qv_unwritten_data <= {{((32 - 7 ) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 7 ) * 8]};
                    8   :           qv_unwritten_data <= {{((32 - 8 ) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 8 ) * 8]};
                    9   :           qv_unwritten_data <= {{((32 - 9 ) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 9 ) * 8]};
                    10  :           qv_unwritten_data <= {{((32 - 10) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 10) * 8]};
                    11  :           qv_unwritten_data <= {{((32 - 11) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 11) * 8]};
                    12  :           qv_unwritten_data <= {{((32 - 12) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 12) * 8]};
                    13  :           qv_unwritten_data <= {{((32 - 13) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 13) * 8]};
                    14  :           qv_unwritten_data <= {{((32 - 14) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 14) * 8]};
                    15  :           qv_unwritten_data <= {{((32 - 15) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 15) * 8]};
                    16  :           qv_unwritten_data <= {{((32 - 16) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 16) * 8]};
                    17  :           qv_unwritten_data <= {{((32 - 17) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 17) * 8]};
                    18  :           qv_unwritten_data <= {{((32 - 18) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 18) * 8]};
                    19  :           qv_unwritten_data <= {{((32 - 19) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 19) * 8]};
                    20  :           qv_unwritten_data <= {{((32 - 20) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 20) * 8]};
                    21  :           qv_unwritten_data <= {{((32 - 21) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 21) * 8]};
                    22  :           qv_unwritten_data <= {{((32 - 22) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 22) * 8]};
                    23  :           qv_unwritten_data <= {{((32 - 23) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 23) * 8]};
                    24  :           qv_unwritten_data <= {{((32 - 24) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 24) * 8]};
                    25  :           qv_unwritten_data <= {{((32 - 25) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 25) * 8]};
                    26  :           qv_unwritten_data <= {{((32 - 26) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 26) * 8]};
                    27  :           qv_unwritten_data <= {{((32 - 27) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 27) * 8]};
                    28  :           qv_unwritten_data <= {{((32 - 28) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 28) * 8]};
                    29  :           qv_unwritten_data <= {{((32 - 29) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 29) * 8]};
                    30  :           qv_unwritten_data <= {{((32 - 30) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 30) * 8]};
                    31  :           qv_unwritten_data <= {{((32 - 31) * 8){1'b0}}, dma_v2p_dt_rd_rsp_tdata[255 : (32 - 31) * 8]};
                    default:        qv_unwritten_data <= qv_unwritten_data;
                endcase
            end 
            else if(qv_mtt_req_length_left + qv_unwritten_len < 32) begin
                if(w_last_mtt_of_mpt) begin
                    qv_unwritten_data <= 'd0; 
                end
                else begin //piece together and wait for next ntt data
                    case(qv_unwritten_len)
                        0   :           qv_unwritten_data <= dma_v2p_dt_rd_rsp_tdata;
                        1   :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 1 ) * 8 - 1 : 0], qv_unwritten_data[1  * 8 - 1 : 0]};
                        2   :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 2 ) * 8 - 1 : 0], qv_unwritten_data[2  * 8 - 1 : 0]};
                        3   :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 3 ) * 8 - 1 : 0], qv_unwritten_data[3  * 8 - 1 : 0]};
                        4   :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 4 ) * 8 - 1 : 0], qv_unwritten_data[4  * 8 - 1 : 0]};
                        5   :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 5 ) * 8 - 1 : 0], qv_unwritten_data[5  * 8 - 1 : 0]};
                        6   :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 6 ) * 8 - 1 : 0], qv_unwritten_data[6  * 8 - 1 : 0]};
                        7   :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 7 ) * 8 - 1 : 0], qv_unwritten_data[7  * 8 - 1 : 0]};
                        8   :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 8 ) * 8 - 1 : 0], qv_unwritten_data[8  * 8 - 1 : 0]};
                        9   :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 9 ) * 8 - 1 : 0], qv_unwritten_data[9  * 8 - 1 : 0]};
                        10  :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 10) * 8 - 1 : 0], qv_unwritten_data[10 * 8 - 1 : 0]};
                        11  :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 11) * 8 - 1 : 0], qv_unwritten_data[11 * 8 - 1 : 0]};
                        12  :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 12) * 8 - 1 : 0], qv_unwritten_data[12 * 8 - 1 : 0]};
                        13  :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 13) * 8 - 1 : 0], qv_unwritten_data[13 * 8 - 1 : 0]};
                        14  :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 14) * 8 - 1 : 0], qv_unwritten_data[14 * 8 - 1 : 0]};
                        15  :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 15) * 8 - 1 : 0], qv_unwritten_data[15 * 8 - 1 : 0]};
                        16  :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 16) * 8 - 1 : 0], qv_unwritten_data[16 * 8 - 1 : 0]};
                        17  :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 17) * 8 - 1 : 0], qv_unwritten_data[17 * 8 - 1 : 0]};
                        18  :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 18) * 8 - 1 : 0], qv_unwritten_data[18 * 8 - 1 : 0]};
                        19  :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 19) * 8 - 1 : 0], qv_unwritten_data[19 * 8 - 1 : 0]};
                        20  :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 20) * 8 - 1 : 0], qv_unwritten_data[20 * 8 - 1 : 0]};
                        21  :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 21) * 8 - 1 : 0], qv_unwritten_data[21 * 8 - 1 : 0]};
                        22  :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 22) * 8 - 1 : 0], qv_unwritten_data[22 * 8 - 1 : 0]};
                        23  :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 23) * 8 - 1 : 0], qv_unwritten_data[23 * 8 - 1 : 0]};
                        24  :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 24) * 8 - 1 : 0], qv_unwritten_data[24 * 8 - 1 : 0]};
                        25  :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 25) * 8 - 1 : 0], qv_unwritten_data[25 * 8 - 1 : 0]};
                        26  :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 26) * 8 - 1 : 0], qv_unwritten_data[26 * 8 - 1 : 0]};
                        27  :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 27) * 8 - 1 : 0], qv_unwritten_data[27 * 8 - 1 : 0]};
                        28  :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 28) * 8 - 1 : 0], qv_unwritten_data[28 * 8 - 1 : 0]};
                        29  :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 29) * 8 - 1 : 0], qv_unwritten_data[29 * 8 - 1 : 0]};
                        30  :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 30) * 8 - 1 : 0], qv_unwritten_data[30 * 8 - 1 : 0]};
                        31  :           qv_unwritten_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 31) * 8 - 1 : 0], qv_unwritten_data[31 * 8 - 1 : 0]};
                        default:        qv_unwritten_data <= qv_unwritten_data;
                    endcase                    
                end
            end
            else begin
                qv_unwritten_data <= qv_unwritten_data;
            end
        end
        else if(qv_mtt_req_length_left == 0 && !w_next_stage_prog_full) begin
            qv_unwritten_data <= w_last_mtt_of_mpt ? 'd0 : qv_unwritten_data;
        end
        else begin
            qv_unwritten_data <= qv_unwritten_data;
        end
    end
    else begin
        qv_unwritten_data <= qv_unwritten_data;
    end
end

//-- q_download_wr_en --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_download_wr_en <= 'd0;
    end  
    else if(response_cur_state == RESPONSE_DOWNLOAD_s) begin
        if(qv_mtt_req_length_left > 0 && dma_v2p_dt_rd_rsp_tvalid && !w_next_stage_prog_full) begin
            if((qv_mtt_req_length_left >= 32) || (qv_mtt_req_length_left + qv_unwritten_len >= 32)) begin
                q_download_wr_en <= 'd1;
            end
            else if(qv_mtt_req_length_left + qv_unwritten_len < 32) begin
                q_download_wr_en <= w_last_mtt_of_mpt ? 'd1 : 'd0;     
            end
            else begin
                q_download_wr_en <= 'd0;
            end
        end
        else if(qv_mtt_req_length_left == 0 && !w_next_stage_prog_full) begin
            q_download_wr_en <= w_last_mtt_of_mpt ? 'd1 : 'd0;
        end
		else begin
			q_download_wr_en <= 'd0;
		end 
    end
    else begin
        q_download_wr_en <= 'd0;
    end
end

//-- qv_download_data --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_download_data <= 'd0;
    end  
    else if(response_cur_state == RESPONSE_DOWNLOAD_s) begin
        if(qv_mtt_req_length_left > 0 && dma_v2p_dt_rd_rsp_tvalid && !w_next_stage_prog_full) begin
            if((qv_mtt_req_length_left >= 32) || (qv_mtt_req_length_left + qv_unwritten_len >= 32)) begin
                case(qv_unwritten_len)
                    0   :           qv_download_data <= dma_v2p_dt_rd_rsp_tdata;
                    1   :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 1 ) * 8 - 1 : 0], qv_unwritten_data[1  * 8 - 1 : 0]};
                    2   :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 2 ) * 8 - 1 : 0], qv_unwritten_data[2  * 8 - 1 : 0]};
                    3   :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 3 ) * 8 - 1 : 0], qv_unwritten_data[3  * 8 - 1 : 0]};
                    4   :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 4 ) * 8 - 1 : 0], qv_unwritten_data[4  * 8 - 1 : 0]};
                    5   :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 5 ) * 8 - 1 : 0], qv_unwritten_data[5  * 8 - 1 : 0]};
                    6   :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 6 ) * 8 - 1 : 0], qv_unwritten_data[6  * 8 - 1 : 0]};
                    7   :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 7 ) * 8 - 1 : 0], qv_unwritten_data[7  * 8 - 1 : 0]};
                    8   :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 8 ) * 8 - 1 : 0], qv_unwritten_data[8  * 8 - 1 : 0]};
                    9   :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 9 ) * 8 - 1 : 0], qv_unwritten_data[9  * 8 - 1 : 0]};
                    10  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 10) * 8 - 1 : 0], qv_unwritten_data[10 * 8 - 1 : 0]};
                    11  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 11) * 8 - 1 : 0], qv_unwritten_data[11 * 8 - 1 : 0]};
                    12  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 12) * 8 - 1 : 0], qv_unwritten_data[12 * 8 - 1 : 0]};
                    13  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 13) * 8 - 1 : 0], qv_unwritten_data[13 * 8 - 1 : 0]};
                    14  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 14) * 8 - 1 : 0], qv_unwritten_data[14 * 8 - 1 : 0]};
                    15  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 15) * 8 - 1 : 0], qv_unwritten_data[15 * 8 - 1 : 0]};
                    16  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 16) * 8 - 1 : 0], qv_unwritten_data[16 * 8 - 1 : 0]};
                    17  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 17) * 8 - 1 : 0], qv_unwritten_data[17 * 8 - 1 : 0]};
                    18  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 18) * 8 - 1 : 0], qv_unwritten_data[18 * 8 - 1 : 0]};
                    19  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 19) * 8 - 1 : 0], qv_unwritten_data[19 * 8 - 1 : 0]};
                    20  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 20) * 8 - 1 : 0], qv_unwritten_data[20 * 8 - 1 : 0]};
                    21  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 21) * 8 - 1 : 0], qv_unwritten_data[21 * 8 - 1 : 0]};
                    22  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 22) * 8 - 1 : 0], qv_unwritten_data[22 * 8 - 1 : 0]};
                    23  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 23) * 8 - 1 : 0], qv_unwritten_data[23 * 8 - 1 : 0]};
                    24  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 24) * 8 - 1 : 0], qv_unwritten_data[24 * 8 - 1 : 0]};
                    25  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 25) * 8 - 1 : 0], qv_unwritten_data[25 * 8 - 1 : 0]};
                    26  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 26) * 8 - 1 : 0], qv_unwritten_data[26 * 8 - 1 : 0]};
                    27  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 27) * 8 - 1 : 0], qv_unwritten_data[27 * 8 - 1 : 0]};
                    28  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 28) * 8 - 1 : 0], qv_unwritten_data[28 * 8 - 1 : 0]};
                    29  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 29) * 8 - 1 : 0], qv_unwritten_data[29 * 8 - 1 : 0]};
                    30  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 30) * 8 - 1 : 0], qv_unwritten_data[30 * 8 - 1 : 0]};
                    31  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 31) * 8 - 1 : 0], qv_unwritten_data[31 * 8 - 1 : 0]};
                    default:        qv_download_data <= qv_download_data;
                endcase
            end
            else if(qv_mtt_req_length_left + qv_unwritten_len < 32) begin
                case(qv_unwritten_len)
                    0   :           qv_download_data <= dma_v2p_dt_rd_rsp_tdata;
                    1   :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 1 ) * 8 - 1 : 0], qv_unwritten_data[1  * 8 - 1 : 0]};
                    2   :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 2 ) * 8 - 1 : 0], qv_unwritten_data[2  * 8 - 1 : 0]};
                    3   :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 3 ) * 8 - 1 : 0], qv_unwritten_data[3  * 8 - 1 : 0]};
                    4   :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 4 ) * 8 - 1 : 0], qv_unwritten_data[4  * 8 - 1 : 0]};
                    5   :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 5 ) * 8 - 1 : 0], qv_unwritten_data[5  * 8 - 1 : 0]};
                    6   :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 6 ) * 8 - 1 : 0], qv_unwritten_data[6  * 8 - 1 : 0]};
                    7   :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 7 ) * 8 - 1 : 0], qv_unwritten_data[7  * 8 - 1 : 0]};
                    8   :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 8 ) * 8 - 1 : 0], qv_unwritten_data[8  * 8 - 1 : 0]};
                    9   :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 9 ) * 8 - 1 : 0], qv_unwritten_data[9  * 8 - 1 : 0]};
                    10  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 10) * 8 - 1 : 0], qv_unwritten_data[10 * 8 - 1 : 0]};
                    11  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 11) * 8 - 1 : 0], qv_unwritten_data[11 * 8 - 1 : 0]};
                    12  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 12) * 8 - 1 : 0], qv_unwritten_data[12 * 8 - 1 : 0]};
                    13  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 13) * 8 - 1 : 0], qv_unwritten_data[13 * 8 - 1 : 0]};
                    14  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 14) * 8 - 1 : 0], qv_unwritten_data[14 * 8 - 1 : 0]};
                    15  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 15) * 8 - 1 : 0], qv_unwritten_data[15 * 8 - 1 : 0]};
                    16  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 16) * 8 - 1 : 0], qv_unwritten_data[16 * 8 - 1 : 0]};
                    17  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 17) * 8 - 1 : 0], qv_unwritten_data[17 * 8 - 1 : 0]};
                    18  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 18) * 8 - 1 : 0], qv_unwritten_data[18 * 8 - 1 : 0]};
                    19  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 19) * 8 - 1 : 0], qv_unwritten_data[19 * 8 - 1 : 0]};
                    20  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 20) * 8 - 1 : 0], qv_unwritten_data[20 * 8 - 1 : 0]};
                    21  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 21) * 8 - 1 : 0], qv_unwritten_data[21 * 8 - 1 : 0]};
                    22  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 22) * 8 - 1 : 0], qv_unwritten_data[22 * 8 - 1 : 0]};
                    23  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 23) * 8 - 1 : 0], qv_unwritten_data[23 * 8 - 1 : 0]};
                    24  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 24) * 8 - 1 : 0], qv_unwritten_data[24 * 8 - 1 : 0]};
                    25  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 25) * 8 - 1 : 0], qv_unwritten_data[25 * 8 - 1 : 0]};
                    26  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 26) * 8 - 1 : 0], qv_unwritten_data[26 * 8 - 1 : 0]};
                    27  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 27) * 8 - 1 : 0], qv_unwritten_data[27 * 8 - 1 : 0]};
                    28  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 28) * 8 - 1 : 0], qv_unwritten_data[28 * 8 - 1 : 0]};
                    29  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 29) * 8 - 1 : 0], qv_unwritten_data[29 * 8 - 1 : 0]};
                    30  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 30) * 8 - 1 : 0], qv_unwritten_data[30 * 8 - 1 : 0]};
                    31  :           qv_download_data <= {dma_v2p_dt_rd_rsp_tdata[(32 - 31) * 8 - 1 : 0], qv_unwritten_data[31 * 8 - 1 : 0]};
                    default:        qv_download_data <= qv_download_data;
                endcase                           
            end
            else begin
                qv_download_data <= qv_download_data;
            end
        end
        else if(qv_mtt_req_length_left == 0 && !w_next_stage_prog_full) begin
            qv_download_data <= qv_unwritten_data;
        end
    end
    else begin
        qv_download_data <= qv_download_data;
    end
end

//---------------------{dma read response process} end --------------------------*
`ifdef V2P_DUG
    assign wv_dbg_bus_rddt = {
            (`RDDT_DBG_REG_NUM * 32){1'b0}
    };

`endif 

endmodule
