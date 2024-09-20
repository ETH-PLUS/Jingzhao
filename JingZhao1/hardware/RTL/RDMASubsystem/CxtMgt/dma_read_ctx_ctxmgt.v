//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: dma_read_ctx_ctxmgt.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V0.0 
// VERSION DESCRIPTION: 1st Edition  
//----------------------------------------------------
// RELEASE DATE: 2021-01-27 
//---------------------------------------------------- 
// PURPOSE: read context from host memory.
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
// 
//-FHDR-----------------------------------------------

//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_ctxmgt_h.vh"

module dma_read_ctx_ctxmgt(
    input clk,
    input rst,
    
    //-------------ctxmdata module interface------------------
        //|---------108bit---------------|
        //|  addr     | len      | QPN   | 
        //|  64 bit   | 12 bit   | 32 bit|
    //DMA Read Ctx Request from ctxmdata
    output wire                            mdt_req_rd_ctx_rd_en,
    input  wire [`MDT_REQ_RD_CTX-1:0]      mdt_req_rd_ctx_dout,
    input  wire                            mdt_req_rd_ctx_empty,

    //-------------DMA Engine module interface------------------
    /* dma_*_head(interact with DMA modules), valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:12   |    11:0     |
     */
    // Context Management DMA Read Request
    output  reg                            dma_cm_rd_req_valid,
    output  reg                            dma_cm_rd_req_last ,
    output  wire [(`DT_WIDTH-1):0]         dma_cm_rd_req_data ,
    output  wire [(`HD_WIDTH-1):0]         dma_cm_rd_req_head ,
    input   wire                           dma_cm_rd_req_ready,

    // Context Management DMA Read Response
    input   wire                           dma_cm_rd_rsp_valid,
    input   wire                           dma_cm_rd_rsp_last ,
    input   wire [(`DT_WIDTH-1):0]         dma_cm_rd_rsp_data ,
    input   wire [(`HD_WIDTH-1):0]         dma_cm_rd_rsp_head ,
    output  wire                           dma_cm_rd_rsp_ready,

    //response to CEU RD_QP_ALL operation
    output  wire                     ceu_rsp_valid,
    output  wire                     ceu_rsp_last ,
    output  wire [(`DT_WIDTH-1):0]   ceu_rsp_data ,
    output  wire [(`HD_WIDTH-1):0]   ceu_rsp_head ,
    input   wire                     ceu_rsp_ready
    
    `ifdef CTX_DUG
        /*Interface with APB Slave*/
            , input   wire 	[`RDCTX_DBG_RW_NUM * 32 - 1 : 0]	rw_data        
	    ,output wire 		[`RDCTX_DBG_REG_NUM * 32 - 1 : 0]		wv_dbg_bus_3
    `endif 
);  

//origianl ctxmdata req backups fifo
wire                            mdt_req_rd_ctx_bkup_prog_full;
reg                             mdt_req_rd_ctx_bkup_wr_en;
reg    [`MDT_REQ_RD_CTX-1 :0]   mdt_req_rd_ctx_bkup_din;
wire                            mdt_req_rd_ctx_bkup_rd_en;
wire   [`MDT_REQ_RD_CTX-1 :0]   mdt_req_rd_ctx_bkup_dout;
wire                            mdt_req_rd_ctx_bkup_empty;
// wire fifo_clear;
// assign fifo_clear = 0;
mdt_req_rd_ctx_bkup_fifo_108w64d mdt_req_rd_ctx_bkup_fifo_108w64d_Inst(
        .clk        (clk),
        .srst        (rst),
        .wr_en      (mdt_req_rd_ctx_bkup_wr_en),
        .rd_en      (mdt_req_rd_ctx_bkup_rd_en),
        .din        (mdt_req_rd_ctx_bkup_din),
        .dout       (mdt_req_rd_ctx_bkup_dout),
        .full       (),
        .empty      (mdt_req_rd_ctx_bkup_empty),     
        .prog_full  (mdt_req_rd_ctx_bkup_prog_full)
    `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[0 * 32 +: 1 * 32])        
    `endif 
);     

//-------------------------{initiate dma read req process} begin--------------------
    //mdt_req_rd_ctx_rd_en
    assign mdt_req_rd_ctx_rd_en = dma_cm_rd_req_ready && !mdt_req_rd_ctx_empty && !mdt_req_rd_ctx_bkup_prog_full;

    //reg                            dma_cm_rd_req_valid
    //reg                            dma_cm_rd_req_last 
    //reg  [(`DT_WIDTH-1):0]         dma_cm_rd_req_data 
    reg  [(`HD_WIDTH-1-52):0]         qv_dma_cm_rd_req_head;
    // dma_cm_rd_req_head   <= `TD {32'b0,mdt_req_rd_ctx_dout[107:44],20'b0,mdt_req_rd_ctx_dout[43:32]};
    assign dma_cm_rd_req_head = {32'b0,qv_dma_cm_rd_req_head[75:12],20'b0,qv_dma_cm_rd_req_head[11:0]};
    assign dma_cm_rd_req_data = 256'b0;
    // dma_*_head, valid only in first beat of a packet
    // | Reserved | address | Reserved | Byte length |
    // |  127:96  |  95:32  |  31:12   |    11:0     |
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dma_cm_rd_req_valid  <= `TD 0;
            dma_cm_rd_req_last   <= `TD 0;
            // dma_cm_rd_req_data   <= `TD 0;
            qv_dma_cm_rd_req_head   <= `TD 0;   
            mdt_req_rd_ctx_bkup_wr_en <= `TD 0;
            mdt_req_rd_ctx_bkup_din   <= `TD 0;     
        end
        else if (mdt_req_rd_ctx_rd_en) begin
            dma_cm_rd_req_valid  <= `TD 1;
            dma_cm_rd_req_last   <= `TD 1;
            // dma_cm_rd_req_data   <= `TD 0;
            /*VCS  Verification*/
            // dma_cm_rd_req_head   <= `TD {32'b0,mdt_req_rd_ctx_dout[75:12],20'b0,mdt_req_rd_ctx_dout[11:0]};
            // dma_cm_rd_req_head   <= `TD {32'b0,mdt_req_rd_ctx_dout[107:44],20'b0,mdt_req_rd_ctx_dout[43:32]};
            qv_dma_cm_rd_req_head   <= `TD {mdt_req_rd_ctx_dout[107:44],mdt_req_rd_ctx_dout[43:32]};
            /*Action = Modify, selecte the corretct seg in mdt_req_rd_ctx_bkup_dout*/
            mdt_req_rd_ctx_bkup_wr_en <= `TD 1;
            mdt_req_rd_ctx_bkup_din   <= `TD mdt_req_rd_ctx_dout;  
        end
        else begin
            dma_cm_rd_req_valid  <= `TD 0;
            dma_cm_rd_req_last   <= `TD 0;
            // dma_cm_rd_req_data   <= `TD 0;
            qv_dma_cm_rd_req_head   <= `TD 0;
            mdt_req_rd_ctx_bkup_wr_en <= `TD 0;
            mdt_req_rd_ctx_bkup_din   <= `TD 0;  
        end
    end
//-------------------------{initiate dma read req process} end--------------------

//-------------------------{dma read response process} begin--------------------
    // ctxmdata read req backup fifo read enable
        //mdt_req_rd_ctx_bkup_rd_en: read enable the fifo if we get the last dma response data of the req
    assign mdt_req_rd_ctx_bkup_rd_en = dma_cm_rd_rsp_last;
    // Context Management DMA Read Response
        //output  wire   ma_cm_rd_rsp_ready: reveive ready to dma engine if ceu is ready to receive data and there is bkup info in fifo
    assign dma_cm_rd_rsp_ready = ceu_rsp_ready && !mdt_req_rd_ctx_bkup_empty;
    //response to CEU RD_QP_ALL operation
        //output  wire                      ceu_rsp_valid,
        //output  wire                      ceu_rsp_last ,
        //output  wire  [(`DT_WIDTH-1):0]   ceu_rsp_data ,
        //output  wire  [(`HD_WIDTH-1):0]   ceu_rsp_head ,
    assign  ceu_rsp_valid =   dma_cm_rd_rsp_valid; // the same as dma response data
    assign  ceu_rsp_last  =   dma_cm_rd_rsp_last ; // the same as dma response data
    assign  ceu_rsp_data  =   dma_cm_rd_rsp_data ; // the same as dma response data
    assign  ceu_rsp_head  =   {`RD_CQ_CTX,`RD_QP_ALL,24'b0,mdt_req_rd_ctx_bkup_dout[31:0],64'b0};//use the backup info to refill the header info

//-------------------------{dma read response process} end----------------------

`ifdef CTX_DUG
    // /*****************Add for APB-slave regs**********************************/ 
        // reg                            dma_cm_rd_req_valid,                //1
        // reg                            dma_cm_rd_req_last,                 //1
        // reg                             mdt_req_rd_ctx_bkup_wr_en;         //1
        // reg  [`MDT_REQ_RD_CTX-1 :0]   mdt_req_rd_ctx_bkup_din;             //108
        // reg  [(`HD_WIDTH-1-52):0]         qv_dma_cm_rd_req_head            //76
                            
    //total regs count = 187

    // /*****************Add for APB-slave wires**********************************/ 
        // wire                            mdt_req_rd_ctx_rd_en,            //1 
        // wire [`MDT_REQ_RD_CTX-1:0]      mdt_req_rd_ctx_dout,             //108 
        // wire                            mdt_req_rd_ctx_empty,            //1 
        // wire [(`DT_WIDTH-1):0]         dma_cm_rd_req_data,               //256 
        // wire [(`HD_WIDTH-1):0]         dma_cm_rd_req_head,               //128 
        // wire                           dma_cm_rd_req_ready,              //1 
        // wire                           dma_cm_rd_rsp_valid,              //1 
        // wire                           dma_cm_rd_rsp_last,               //1 
        // wire [(`DT_WIDTH-1):0]         dma_cm_rd_rsp_data,               //256 
        // wire [(`HD_WIDTH-1):0]         dma_cm_rd_rsp_head,               //128 
        // wire                           dma_cm_rd_rsp_ready,              //1 
        // wire                     ceu_rsp_valid,                          //1 
        // wire                     ceu_rsp_last,                           //1 
        // wire [(`DT_WIDTH-1):0]   ceu_rsp_data,                           //256 
        // wire [(`HD_WIDTH-1):0]   ceu_rsp_head,                           //128 
        // wire                     ceu_rsp_ready                           //1 
        // wire                            mdt_req_rd_ctx_bkup_prog_full;   //1 
        // wire                            mdt_req_rd_ctx_bkup_rd_en;       //1 
        // wire   [`MDT_REQ_RD_CTX-1 :0]   mdt_req_rd_ctx_bkup_dout;        //108 
        // wire                            mdt_req_rd_ctx_bkup_empty;       //1 

    //total wires count = 1bit_signal(12) + 256*3 + 108*2 + 128*3 = 1380

    //Total regs and wires : 187 + 1380 = 1567 = 32 * 48 + 31. bit align 49

    assign wv_dbg_bus_3 = {
        31'b0,
        dma_cm_rd_req_valid,
        dma_cm_rd_req_last,
        mdt_req_rd_ctx_bkup_wr_en,
        mdt_req_rd_ctx_bkup_din,
        qv_dma_cm_rd_req_head,
        
        mdt_req_rd_ctx_rd_en,
        mdt_req_rd_ctx_dout,
        mdt_req_rd_ctx_empty,
        dma_cm_rd_req_data,
        dma_cm_rd_req_head,
        dma_cm_rd_req_ready,
        dma_cm_rd_rsp_valid,
        dma_cm_rd_rsp_last,
        dma_cm_rd_rsp_data,
        dma_cm_rd_rsp_head,
        dma_cm_rd_rsp_ready,
        ceu_rsp_valid,
        ceu_rsp_last,
        ceu_rsp_data,
        ceu_rsp_head,
        ceu_rsp_ready,
        mdt_req_rd_ctx_bkup_prog_full,
        mdt_req_rd_ctx_bkup_rd_en,
        mdt_req_rd_ctx_bkup_dout,
        mdt_req_rd_ctx_bkup_empty
    };
`endif 


endmodule