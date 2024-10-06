//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: dma_write_ctx_v2p.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V0.0 
// VERSION DESCRIPTION: 1st Edition  
//----------------------------------------------------
// RELEASE DATE: 2020-10-27 
//---------------------------------------------------- 
// PURPOSE: write tpt data to host memory.
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
// 
//-FHDR-----------------------------------------------

//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_v2p_h.vh"

module dma_write_ctx_v2p#(
    parameter  DMA_WR_HD_WIDTH  = 99//for Mdata-DMA Write req header fifo
    )(
    input clk,
    input rst,
    
    //-------------tptmdata module interface------------------
    //|-----99 bit----------|
    //| opcode | len | addr |
    //|    3   | 32  |  64  |
    //|---------------------|
    //DMA Write mpt Ctx Request interface
    output  wire                           dma_wr_mpt_req_rd_en,
    input   wire  [DMA_WR_HD_WIDTH-1:0]    dma_wr_mpt_req_dout,
    input   wire                           dma_wr_mpt_req_empty,
    //DMA Write mtt Ctx Request interface
    output  wire                           dma_wr_mtt_req_rd_en,
    input   wire  [DMA_WR_HD_WIDTH-1:0]    dma_wr_mtt_req_dout,
    input   wire                           dma_wr_mtt_req_empty,

    //-------------mpt module interface------------------
    //DMA write MPT Ctx payload from MPT module
    output wire                            dma_wr_mpt_rd_en,
    input  wire  [`DT_WIDTH-1:0]           dma_wr_mpt_dout,
    input  wire                            dma_wr_mpt_empty,

    //-------------mtt module interface------------------
    //DMA write MTT Ctx payload from MTT module  
    output wire                            dma_wr_mtt_rd_en,
    input  wire  [`DT_WIDTH-1:0]           dma_wr_mtt_dout,
    input  wire                            dma_wr_mtt_empty,

    //-------------DMA Engine module interface------------------
    /* dma_*_head(interact with DMA modules), valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:12   |    11:0     |
     */
    //DMA MPT Context Write Request
    output  wire                           dma_v2p_mpt_wr_req_valid,
    output  wire                           dma_v2p_mpt_wr_req_last ,
    output  wire [(`DT_WIDTH-1):0]         dma_v2p_mpt_wr_req_data ,
    output  wire [(`HD_WIDTH-1):0]         dma_v2p_mpt_wr_req_head ,
    input   wire                           dma_v2p_mpt_wr_req_ready,
    //DMA MTT Context Write Request
    output  wire                           dma_v2p_mtt_wr_req_valid,
    output  wire                           dma_v2p_mtt_wr_req_last ,
    output  wire [(`DT_WIDTH-1):0]         dma_v2p_mtt_wr_req_data ,
    output  wire [(`HD_WIDTH-1):0]         dma_v2p_mtt_wr_req_head ,
    input   wire                           dma_v2p_mtt_wr_req_ready

    `ifdef V2P_DUG
    //apb_slave
        // ,  output wire [`V2P_WRCTX_DBG_RW_NUM * 32 - 1 : 0]   rw_data
        ,  output wire [`V2P_WRCTX_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_wrctx
    `endif

);

reg    [`DT_WIDTH-1 :0]     qv_mpt_tmp_data;
reg    [`HD_WIDTH-1 :0]     qv_mpt_tmp_header;
reg    [31-5:0]               qv_mpt_rest_length;
reg    [31:0]               qv_mpt_offset;

reg    [`DT_WIDTH-1 :0]     qv_mtt_tmp_data;
reg    [99-1 :0]     qv_mtt_tmp_header;
reg    [31:0]               qv_mtt_rest_length;
reg    [31:0]               qv_mtt_offset;

reg                          q_mpt_wr_req_valid;
reg                          q_mpt_wr_req_last ;
reg   [(`DT_WIDTH-1):0]     qv_mpt_wr_req_data ;
reg   [(`HD_WIDTH-1-32):0]     qv_mpt_wr_req_head ;

reg                          q_mtt_wr_req_valid;
reg                          q_mtt_wr_req_last ;
reg   [(`DT_WIDTH-1):0]     qv_mtt_wr_req_data ;
reg   [(`HD_WIDTH-1-32):0]     qv_mtt_wr_req_head ;

//-------------------------Output Decode---------------------

//---------------------------mpt dma write process------------------
//DMA Write mpt Ctx Request from mptm module
// output  wire                       dma_wr_mpt_req_rd_en,
// if req_fifo and data_fifo are not empty and the paylaod of 1 req has been transferred completely, read req 
//mpt request only req 1 mpt entry 1 time
assign dma_wr_mpt_req_rd_en = (!dma_wr_mpt_req_empty && dma_v2p_mpt_wr_req_ready && !dma_wr_mpt_empty && (qv_mpt_rest_length == 0)) ? 1 :0;

//DMA write MPT Ctx payload from MPT module
// output wire                        dma_wr_mpt_rd_en,
// if req_fifo and data_fifo are not empty and the paylaod of 1 req has transferred completely, read data; if data_fifo is not empty and the payloads of 1 req has not been transferred completely, read data
assign dma_wr_mpt_rd_en = (!dma_wr_mpt_req_empty && dma_v2p_mpt_wr_req_ready && !dma_wr_mpt_empty && (qv_mpt_rest_length == 0)) ? 1 : (dma_v2p_mpt_wr_req_ready && !dma_wr_mpt_empty && (qv_mpt_rest_length != 0)) ? 1 :0;


//reg    [`HD_WIDTH-1 :0]     qv_mpt_tmp_header;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_mpt_tmp_header <= `TD 0;
    end 
    else if (dma_wr_mpt_req_rd_en) begin
        qv_mpt_tmp_header <= `TD dma_wr_mpt_req_dout;
    end
    else begin
        qv_mpt_tmp_header <= `TD qv_mpt_tmp_header;
    end
end

//reg    [`DT_WIDTH-1 :0]     qv_mpt_tmp_data;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_mpt_tmp_data <= `TD 0;
    end 
    else if (dma_wr_mpt_rd_en) begin
        qv_mpt_tmp_data <= `TD dma_wr_mpt_dout;
    end
    else begin
        qv_mpt_tmp_data <= `TD qv_mpt_tmp_data;
    end
end

//mpt entry size =64B, only need 2 cycle to transfer
//reg    [31:0]               qv_mpt_rest_length;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_mpt_rest_length <= `TD 0;
    end
    else if (dma_wr_mpt_rd_en && dma_wr_mpt_req_rd_en) begin
        // Modified in 2023.3.17
        // qv_mpt_rest_length <= `TD (qv_mpt_tmp_header[95:64] >= 32) ? (qv_mpt_tmp_header[95:69]-1) : 0;
        qv_mpt_rest_length <= `TD (dma_wr_mpt_req_dout[95:64] >= 32) ? (dma_wr_mpt_req_dout[95:69]-1) : 0;
    end else begin
        qv_mpt_rest_length <= `TD 0;
    end
end

//mpt entry size =64B=512bit, every cycle offset = 0;
//reg    [31:0]               qv_mpt_offset;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_mpt_offset <= `TD 0;      
    end else begin
        qv_mpt_offset <= `TD 0;
    end
end

//DMA TPT Context Write Request
//output  wire                           dma_v2p_mpt_wr_req_valid,
//output  wire                           dma_v2p_mpt_wr_req_last ,
//output  wire [(`DT_WIDTH-1):0]         dma_v2p_mpt_wr_req_data ,
//output  wire [(`HD_WIDTH-1):0]         dma_v2p_mpt_wr_req_head ,
//input   wire                           dma_v2p_mpt_wr_req_ready,
//reg                          q_mpt_wr_req_valid;
//reg                          q_mpt_wr_req_last ;
//reg   [(`DT_WIDTH-1):0]     qv_mpt_wr_req_data ;
//reg   [(`HD_WIDTH-1):0]     qv_mpt_wr_req_head ;
always @(posedge clk or posedge rst) begin
    if (rst) begin
         q_mpt_wr_req_valid <= `TD 0;
         q_mpt_wr_req_last  <= `TD 0;
        qv_mpt_wr_req_data  <= `TD 0;
        qv_mpt_wr_req_head  <= `TD 0;
    end 
    else if (dma_wr_mpt_rd_en && dma_wr_mpt_req_rd_en) begin
        q_mpt_wr_req_valid <= `TD 1;
        q_mpt_wr_req_last  <= `TD 0;
        qv_mpt_wr_req_data <= `TD dma_wr_mpt_dout;
        // qv_mpt_wr_req_head <= `TD {32'b0,dma_wr_mpt_req_dout[63:0],dma_wr_mpt_req_dout[95:64]};
        qv_mpt_wr_req_head <= `TD {dma_wr_mpt_req_dout[63:0],dma_wr_mpt_req_dout[95:64]};
    end
    else if (dma_wr_mpt_rd_en) begin
        q_mpt_wr_req_valid <= `TD 1;
        q_mpt_wr_req_last  <= `TD 1;
        qv_mpt_wr_req_data <= `TD dma_wr_mpt_dout;
        qv_mpt_wr_req_head <= `TD 0;
    end else begin
        q_mpt_wr_req_valid <= `TD 0;
        q_mpt_wr_req_last  <= `TD 0;
        qv_mpt_wr_req_data <= `TD 0;
        qv_mpt_wr_req_head <= `TD 0;
    end
end
assign   dma_v2p_mpt_wr_req_valid =   q_mpt_wr_req_valid;
assign   dma_v2p_mpt_wr_req_last  =   q_mpt_wr_req_last ;
assign   dma_v2p_mpt_wr_req_data  =  qv_mpt_wr_req_data ;
assign   dma_v2p_mpt_wr_req_head  =  {32'b0,qv_mpt_wr_req_head} ;


//---------------------------mtt dma write process------------------
//DMA Write mtt Ctx Request from mttm interface
//reg                        q_dma_rd_mtt_req_rd_en;
//output  wire                           dma_wr_mtt_req_rd_en,
//input   wire  [DMA_WR_HD_WIDTH-1:0]    dma_wr_mtt_req_dout,
assign dma_wr_mtt_req_rd_en = (!dma_wr_mtt_req_empty && dma_v2p_mtt_wr_req_ready && !dma_wr_mtt_empty && (qv_mtt_rest_length == 0)) ? 1 :0;

//DMA write MTT Ctx payload from MTT module  
// output wire                     dma_wr_mtt_rd_en,
// input  wire  [`DT_WIDTH-1:0]       dma_wr_mtt_dout,
// if req_fifo and data_fifo are not empty and the paylaod of 1 req has transferred completely, read data; if data_fifo is not empty and the payloads of 1 req has not been transferred completely, read data
// assign dma_wr_mtt_rd_en = (!dma_wr_mtt_req_empty && dma_v2p_mtt_wr_req_ready && !dma_wr_mtt_empty && (qv_mtt_rest_length == 0) && (qv_mtt_tmp_header[98:96] == `LAST)) ? 1 : (dma_v2p_mtt_wr_req_ready && !dma_wr_mtt_empty && (dma_wr_mtt_req_dout[95:64] + qv_mtt_offset > 32)) ? 1 : 0;
assign dma_wr_mtt_rd_en = dma_wr_mtt_req_rd_en;

//reg    [`HD_WIDTH-1 :0]     qv_mtt_tmp_header;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_mtt_tmp_header <= `TD 0;
    end 
    else if (dma_wr_mtt_req_rd_en) begin
        qv_mtt_tmp_header <= `TD dma_wr_mtt_req_dout;
    end
    else begin
        qv_mtt_tmp_header <= `TD qv_mtt_tmp_header;
    end
end

//reg    [`DT_WIDTH-1 :0]     qv_mtt_tmp_data;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_mtt_tmp_data <= `TD 0;
    end 
    else if (dma_wr_mtt_rd_en) begin
        qv_mtt_tmp_data <= `TD dma_wr_mtt_dout;
    end
    else begin
        qv_mtt_tmp_data <= `TD qv_mtt_tmp_data;
    end
end

//reg    [31:0]               qv_mtt_rest_length;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_mtt_rest_length <= `TD 0;
    end
    //if it's the fist time read req from req_fifo and length >= 32,rest legnth = rest length -32; else, rest length = 0   
    else if (dma_wr_mtt_req_rd_en && dma_v2p_mtt_wr_req_ready && (((dma_wr_mtt_req_dout[95:64] + qv_mtt_offset > 32) && dma_wr_mtt_rd_en) || (dma_wr_mtt_req_dout[95:64] + qv_mtt_offset <= 32))) begin
        qv_mtt_rest_length <= `TD (dma_wr_mtt_req_dout[95:64] >= 32) ? (dma_wr_mtt_req_dout[95:64]-32) : 0;
    end
    //if it's not the first payload cycle to read data and rest length >= 32, rest legnth = rest length -32; else, rest length = 0
    else if ((qv_mtt_rest_length > 0) && (((qv_mtt_rest_length + qv_mtt_offset > 32) && dma_wr_mtt_rd_en) || (qv_mtt_rest_length + qv_mtt_offset <= 32)) && dma_v2p_mtt_wr_req_ready) begin
        qv_mtt_rest_length <= `TD (qv_mtt_rest_length >= 32) ? (qv_mtt_rest_length - 32) : 0;
    end else begin
        qv_mtt_rest_length <= `TD qv_mtt_rest_length;
    end
end

//reg    [31:0]               qv_mtt_offset;
wire [31:0] offset_sum;
assign offset_sum = qv_mtt_rest_length + qv_mtt_offset;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_mtt_offset <= `TD 0;
    end
    //if it's the 1st req after rst, offset = 0;
    else if (dma_wr_mtt_rd_en && dma_wr_mtt_req_rd_en && (qv_mtt_tmp_header == 99'b0)) begin
        qv_mtt_offset <= `TD 0;
    end
    //if the payloads of 1 req has not been transferred completely, new offset=0
    else if (dma_wr_mtt_rd_en && dma_wr_mtt_req_rd_en && dma_v2p_mtt_wr_req_ready && (qv_mtt_tmp_header[98:96] == `LAST) && (qv_mtt_rest_length == 0)) begin
        qv_mtt_offset <= `TD 0;
    end
    //if it's in the process of transfer payload of 1 req, offset = [offset + rest_length] % 32;
    else if ((qv_mtt_rest_length > 0) && (((qv_mtt_rest_length + qv_mtt_offset > 32) && dma_wr_mtt_rd_en) || (qv_mtt_rest_length + qv_mtt_offset <= 32)) && dma_v2p_mtt_wr_req_ready) begin
        qv_mtt_offset <= `TD {27'b0,offset_sum[4:0]};
    end else begin
        qv_mtt_offset <= `TD qv_mtt_offset;
    end
end

//output  wire [(`HD_WIDTH-1):0]         dma_v2p_mtt_wr_req_head ,
//reg   [(`HD_WIDTH-1):0]     qv_mtt_wr_req_head ;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_mtt_wr_req_head  <= `TD 0;        
    end
    // if it's the first time read req from req_fifo, we need to transfer dma req header next cycle 
    else if (dma_wr_mtt_req_rd_en && dma_v2p_mtt_wr_req_ready && (((dma_wr_mtt_req_dout[95:64] + qv_mtt_offset > 32) && dma_wr_mtt_rd_en) || (dma_wr_mtt_req_dout[95:64] + qv_mtt_offset <= 32))) begin
        // qv_mtt_wr_req_head  <= `TD {32'b0,dma_wr_mtt_req_dout[63:0],dma_wr_mtt_req_dout[95:64]};
        qv_mtt_wr_req_head  <= `TD {dma_wr_mtt_req_dout[63:0],dma_wr_mtt_req_dout[95:64]};
    end else begin
        qv_mtt_wr_req_head  <= `TD 0;        
    end
end
assign   dma_v2p_mtt_wr_req_head   =  {32'b0,qv_mtt_wr_req_head} ;

//output  wire                           dma_v2p_mtt_wr_req_valid,
//reg                          q_mtt_wr_req_valid;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_mtt_wr_req_valid <= `TD 0;       
    end
    // if it's the first time read req from req_fifo, we need to set the valid signal next cycle 
    else if (dma_wr_mtt_req_rd_en && dma_v2p_mtt_wr_req_ready && (((dma_wr_mtt_req_dout[95:64] + qv_mtt_offset > 32) && dma_wr_mtt_rd_en) || (dma_wr_mtt_req_dout[95:64] + qv_mtt_offset <= 32))) begin
        q_mtt_wr_req_valid <= `TD 1;       
    end
    //if it's has rest payload need to transfer 
    //and we need to piece together the payload using tmp_data and data_fifo_out(fifo not empty) 
    //or needn't piece together(don't care the data_fifo whether empty)
    else if ((qv_mtt_rest_length > 0) && (((qv_mtt_rest_length + qv_mtt_offset > 32) && dma_wr_mtt_rd_en) || (qv_mtt_rest_length + qv_mtt_offset <= 32)) && dma_v2p_mtt_wr_req_ready) begin
        q_mtt_wr_req_valid <= `TD 1;       
    end else begin
        q_mtt_wr_req_valid <= `TD 0;       
    end
end
assign   dma_v2p_mtt_wr_req_valid  =   q_mtt_wr_req_valid;

//output  wire                           dma_v2p_mtt_wr_req_last ,
//reg                          q_mtt_wr_req_last ;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_mtt_wr_req_last  <= `TD 0;
    end
    //if it's the 1st req cycle and the length < 32Byte, set the last signal; 
    else if (dma_wr_mtt_req_rd_en && dma_v2p_mtt_wr_req_ready && (dma_wr_mtt_req_dout[95:64] + qv_mtt_offset <= 32)) begin
        q_mtt_wr_req_last  <= `TD 1;
    end
    //if it's not the first cycle of 1 dma req and 
    //it has the last rest payload to transfer and 
    //the payload has been prepared already, set the last signal
    else if ((qv_mtt_rest_length > 0) && (qv_mtt_rest_length <= 32) && (((qv_mtt_rest_length + qv_mtt_offset > 32) && dma_wr_mtt_rd_en) || (qv_mtt_rest_length + qv_mtt_offset <= 32)) && dma_v2p_mtt_wr_req_ready) begin
        q_mtt_wr_req_last  <= `TD 1;
    end else begin
        q_mtt_wr_req_last  <= `TD 0;
    end
end
assign   dma_v2p_mtt_wr_req_last   =   q_mtt_wr_req_last ;

//output  wire [(`DT_WIDTH-1):0]         dma_v2p_mtt_wr_req_data ,
//reg   [(`DT_WIDTH-1):0]     qv_mtt_wr_req_data ;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_mtt_wr_req_data  <= `TD 0;
    end
    //if it's the first req cycle of req and paylaod data prepared already, piece together the payload using data_fifo_dout and tmp_data, the length based on req_fifo_dout
    else if (dma_wr_mtt_req_rd_en && dma_v2p_mtt_wr_req_ready && (((dma_wr_mtt_req_dout[95:64] + qv_mtt_offset > 32) && dma_wr_mtt_rd_en) || (dma_wr_mtt_req_dout[95:64] + qv_mtt_offset <= 32))) begin
        //this case used for choosing the start positon in the tmp_data(offset != 0)/data_fifo_dout of 1 payload.  
        case (qv_mtt_offset)
            //offset = 0 means that this is the first dma req of 1 mtt write req, read the data from data_fifo_out
            32'b0:      qv_mtt_wr_req_data <= `TD dma_wr_mtt_dout[255:0];
            //offset = 1 means that first use the data from tmp_data, we will spiece together
            32'b000001: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[1 *8-1 :0],qv_mtt_tmp_data[255: 8*1 ]};
            32'b000010: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[2 *8-1 :0],qv_mtt_tmp_data[255: 8*2 ]};
            32'b000011: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[3 *8-1 :0],qv_mtt_tmp_data[255: 8*3 ]};
            32'b000100: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[4 *8-1 :0],qv_mtt_tmp_data[255: 8*4 ]};
            32'b000101: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[5 *8-1 :0],qv_mtt_tmp_data[255: 8*5 ]};
            32'b000110: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[6 *8-1 :0],qv_mtt_tmp_data[255: 8*6 ]};
            32'b000111: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[7 *8-1 :0],qv_mtt_tmp_data[255: 8*7 ]};
            32'b001000: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[8 *8-1 :0],qv_mtt_tmp_data[255: 8*8 ]};
            32'b001001: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[9 *8-1 :0],qv_mtt_tmp_data[255: 8*9 ]};
            32'b001010: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[10*8-1 :0],qv_mtt_tmp_data[255: 8*10]};
            32'b001011: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[11*8-1 :0],qv_mtt_tmp_data[255: 8*11]}; 
            32'b001100: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[12*8-1 :0],qv_mtt_tmp_data[255: 8*12]}; 
            32'b001101: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[13*8-1 :0],qv_mtt_tmp_data[255: 8*13]}; 
            32'b001110: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[14*8-1 :0],qv_mtt_tmp_data[255: 8*14]};
            32'b001111: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[15*8-1 :0],qv_mtt_tmp_data[255: 8*15]}; 
            32'b010000: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[16*8-1 :0],qv_mtt_tmp_data[255: 8*16]};
            32'b010001: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[17*8-1 :0],qv_mtt_tmp_data[255: 8*17]}; 
            32'b010010: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[18*8-1 :0],qv_mtt_tmp_data[255: 8*18]}; 
            32'b010011: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[19*8-1 :0],qv_mtt_tmp_data[255: 8*19]};
            32'b010100: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[20*8-1 :0],qv_mtt_tmp_data[255: 8*20]}; 
            32'b010101: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[21*8-1 :0],qv_mtt_tmp_data[255: 8*21]};
            32'b010110: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[22*8-1 :0],qv_mtt_tmp_data[255: 8*22]}; 
            32'b010111: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[23*8-1 :0],qv_mtt_tmp_data[255: 8*23]}; 
            32'b011000: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[24*8-1 :0],qv_mtt_tmp_data[255: 8*24]};
            32'b011001: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[25*8-1 :0],qv_mtt_tmp_data[255: 8*25]};
            32'b011010: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[26*8-1 :0],qv_mtt_tmp_data[255: 8*26]};
            32'b011011: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[27*8-1 :0],qv_mtt_tmp_data[255: 8*27]}; 
            32'b011100: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[28*8-1 :0],qv_mtt_tmp_data[255: 8*28]}; 
            32'b011101: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[29*8-1 :0],qv_mtt_tmp_data[255: 8*29]};
            32'b011110: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[30*8-1 :0],qv_mtt_tmp_data[255: 8*30]}; 
            32'b011111: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[31*8-1 :0],qv_mtt_tmp_data[255: 8*31]};
            32'b100000: qv_mtt_wr_req_data <= `TD dma_wr_mtt_dout[32*8-1 :0];   
            default:    qv_mtt_wr_req_data  <= `TD 0;
        endcase
    end
    //if it's the subsequent req cycles of req and paylaod data prepared already, piece together the payload using data_fifo_dout and tmp_data, the length based on the rest_length reg
    else if ((qv_mtt_rest_length > 0) && (((qv_mtt_rest_length + qv_mtt_offset > 32) && !dma_wr_mtt_rd_en) || (qv_mtt_rest_length + qv_mtt_offset <= 32)) && dma_v2p_mtt_wr_req_ready) begin
        case (qv_mtt_offset)
            //offset = 0 means that this is the first dma req of 1 mtt write req, read the data from data_fifo_out
            32'b0:      qv_mtt_wr_req_data <= `TD dma_wr_mtt_dout[255:0];
            //offset = 1 means that first use the data from tmp_data, we will spiece together
            32'b000001: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[1 *8-1 :0],qv_mtt_tmp_data[255: 8*1 ]};
            32'b000010: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[2 *8-1 :0],qv_mtt_tmp_data[255: 8*2 ]};
            32'b000011: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[3 *8-1 :0],qv_mtt_tmp_data[255: 8*3 ]};
            32'b000100: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[4 *8-1 :0],qv_mtt_tmp_data[255: 8*4 ]};
            32'b000101: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[5 *8-1 :0],qv_mtt_tmp_data[255: 8*5 ]};
            32'b000110: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[6 *8-1 :0],qv_mtt_tmp_data[255: 8*6 ]};
            32'b000111: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[7 *8-1 :0],qv_mtt_tmp_data[255: 8*7 ]};
            32'b001000: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[8 *8-1 :0],qv_mtt_tmp_data[255: 8*8 ]};
            32'b001001: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[9 *8-1 :0],qv_mtt_tmp_data[255: 8*9 ]};
            32'b001010: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[10*8-1 :0],qv_mtt_tmp_data[255: 8*10]};
            32'b001011: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[11*8-1 :0],qv_mtt_tmp_data[255: 8*11]}; 
            32'b001100: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[12*8-1 :0],qv_mtt_tmp_data[255: 8*12]}; 
            32'b001101: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[13*8-1 :0],qv_mtt_tmp_data[255: 8*13]}; 
            32'b001110: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[14*8-1 :0],qv_mtt_tmp_data[255: 8*14]};
            32'b001111: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[15*8-1 :0],qv_mtt_tmp_data[255: 8*15]}; 
            32'b010000: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[16*8-1 :0],qv_mtt_tmp_data[255: 8*16]};
            32'b010001: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[17*8-1 :0],qv_mtt_tmp_data[255: 8*17]}; 
            32'b010010: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[18*8-1 :0],qv_mtt_tmp_data[255: 8*18]}; 
            32'b010011: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[19*8-1 :0],qv_mtt_tmp_data[255: 8*19]};
            32'b010100: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[20*8-1 :0],qv_mtt_tmp_data[255: 8*20]}; 
            32'b010101: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[21*8-1 :0],qv_mtt_tmp_data[255: 8*21]};
            32'b010110: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[22*8-1 :0],qv_mtt_tmp_data[255: 8*22]}; 
            32'b010111: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[23*8-1 :0],qv_mtt_tmp_data[255: 8*23]}; 
            32'b011000: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[24*8-1 :0],qv_mtt_tmp_data[255: 8*24]};
            32'b011001: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[25*8-1 :0],qv_mtt_tmp_data[255: 8*25]};
            32'b011010: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[26*8-1 :0],qv_mtt_tmp_data[255: 8*26]};
            32'b011011: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[27*8-1 :0],qv_mtt_tmp_data[255: 8*27]}; 
            32'b011100: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[28*8-1 :0],qv_mtt_tmp_data[255: 8*28]}; 
            32'b011101: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[29*8-1 :0],qv_mtt_tmp_data[255: 8*29]};
            32'b011110: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[30*8-1 :0],qv_mtt_tmp_data[255: 8*30]}; 
            32'b011111: qv_mtt_wr_req_data <= `TD {dma_wr_mtt_dout[31*8-1 :0],qv_mtt_tmp_data[255: 8*31]};
            32'b100000: qv_mtt_wr_req_data <= `TD dma_wr_mtt_dout[32*8-1 :0];   
            default:    qv_mtt_wr_req_data  <= `TD 0; 
        endcase
    end else begin
        qv_mtt_wr_req_data  <= `TD 0;
    end
end
assign   dma_v2p_mtt_wr_req_data   =  qv_mtt_wr_req_data ;


`ifdef V2P_DUG
    // /*****************Add for APB-slave regs**********************************/ 
        // reg    [`DT_WIDTH-1 :0]     qv_mpt_tmp_data;
        // reg    [`HD_WIDTH-1 :0]     qv_mpt_tmp_header;
        // reg    [31:0]               qv_mpt_rest_length;
        // reg    [31:0]               qv_mpt_offset;
        // reg    [`DT_WIDTH-1 :0]     qv_mtt_tmp_data;
        // reg    [`HD_WIDTH-1 :0]     qv_mtt_tmp_header;
        // reg    [31:0]               qv_mtt_rest_length;
        // reg    [31:0]               qv_mtt_offset;
        // reg                          q_mpt_wr_req_valid;
        // reg                          q_mpt_wr_req_last ;
        // reg   [(`DT_WIDTH-1):0]     qv_mpt_wr_req_data ;
        // reg   [(`HD_WIDTH-1):0]     qv_mpt_wr_req_head ;
        // reg                          q_mtt_wr_req_valid;
        // reg                          q_mtt_wr_req_last ;
        // reg   [(`DT_WIDTH-1):0]     qv_mtt_wr_req_data ;
        // reg   [(`HD_WIDTH-1):0]     qv_mtt_wr_req_head ;
        

    /*****************Add for APB-slave wires**********************************/         
        // wire                           dma_wr_mpt_req_rd_en,
        // wire  [DMA_WR_HD_WIDTH-1:0]    dma_wr_mpt_req_dout,
        // wire                           dma_wr_mpt_req_empty,
        // wire                           dma_wr_mtt_req_rd_en,
        // wire  [DMA_WR_HD_WIDTH-1:0]    dma_wr_mtt_req_dout,
        // wire                           dma_wr_mtt_req_empty,
        // wire                            dma_wr_mpt_rd_en,
        // wire  [`DT_WIDTH-1:0]           dma_wr_mpt_dout,
        // wire                            dma_wr_mpt_empty,
        // wire                            dma_wr_mtt_rd_en,
        // wire  [`DT_WIDTH-1:0]           dma_wr_mtt_dout,
        // wire                            dma_wr_mtt_empty,
        // wire                           dma_v2p_mpt_wr_req_valid,
        // wire                           dma_v2p_mpt_wr_req_last ,
        // wire [(`DT_WIDTH-1):0]         dma_v2p_mpt_wr_req_data ,
        // wire [(`HD_WIDTH-1):0]         dma_v2p_mpt_wr_req_head ,
        // wire                           dma_v2p_mpt_wr_req_ready,
        // wire                           dma_v2p_mtt_wr_req_valid,
        // wire                           dma_v2p_mtt_wr_req_last ,
        // wire [(`DT_WIDTH-1):0]         dma_v2p_mtt_wr_req_data ,
        // wire [(`HD_WIDTH-1):0]         dma_v2p_mtt_wr_req_head ,
        // wire                           dma_v2p_mtt_wr_req_ready
        // wire [31:0] offset_sum;

    //Total regs and wires : 3094 = 96*32+22

    assign wv_dbg_bus_wrctx = {
        10'b0,
        qv_mpt_tmp_data,
        qv_mpt_tmp_header,
        qv_mpt_rest_length,
        qv_mpt_offset,
        qv_mtt_tmp_data,
        qv_mtt_tmp_header,
        qv_mtt_rest_length,
        qv_mtt_offset,
        q_mpt_wr_req_valid,
        q_mpt_wr_req_last,
        qv_mpt_wr_req_data,
        qv_mpt_wr_req_head,
        q_mtt_wr_req_valid,
        q_mtt_wr_req_last,
        qv_mtt_wr_req_data,
        qv_mtt_wr_req_head,

        dma_wr_mpt_req_rd_en,
        dma_wr_mpt_req_dout,
        dma_wr_mpt_req_empty,
        dma_wr_mtt_req_rd_en,
        dma_wr_mtt_req_dout,
        dma_wr_mtt_req_empty,
        dma_wr_mpt_rd_en,
        dma_wr_mpt_dout,
        dma_wr_mpt_empty,
        dma_wr_mtt_rd_en,
        dma_wr_mtt_dout,
        dma_wr_mtt_empty,
        dma_v2p_mpt_wr_req_valid,
        dma_v2p_mpt_wr_req_last,
        dma_v2p_mpt_wr_req_data,
        dma_v2p_mpt_wr_req_head,
        dma_v2p_mpt_wr_req_ready,
        dma_v2p_mtt_wr_req_valid,
        dma_v2p_mtt_wr_req_last,
        dma_v2p_mtt_wr_req_data,
        dma_v2p_mtt_wr_req_head,
        dma_v2p_mtt_wr_req_ready,
        offset_sum
    };

`endif 

endmodule