//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: dma_read_ctx_v2p.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V0.0 
// VERSION DESCRIPTION: 1st Edition  
//----------------------------------------------------
// RELEASE DATE: 2020-09-09 
//---------------------------------------------------- 
// PURPOSE: read tpt from host memory.
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
// 
//-FHDR-----------------------------------------------

//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_v2p_h.vh"

module dma_read_ctx_v2p#(
    parameter  DMA_RD_HD_WIDTH  = 163,//for Mdata-DMA Read req header fifo
    parameter  DMA_RD_BKUP_WIDTH  = 99//for Mdata-TPT Read req header fifo
    )(
    input clk,
    input rst,
    
    //-------------tptmdata module interface------------------
    //| -----------163 bit----------|
    //| index | opcode | len | addr |
    //|  64   |    3   | 32  |  64  |
    //|--------------------------==-|
    //DMA Read MPT Ctx Request interface from tptmetadata module
    output  wire                           dma_rd_mpt_req_rd_en,
    input   wire  [DMA_RD_HD_WIDTH-1:0]    dma_rd_mpt_req_dout,
    input   wire                           dma_rd_mpt_req_empty,
    //DMA Read MTT Ctx Request interface from tptmetadata module
    output  wire                           dma_rd_mtt_req_rd_en,
    input   wire  [DMA_RD_HD_WIDTH-1:0]    dma_rd_mtt_req_dout,
    input   wire                           dma_rd_mtt_req_empty,
    
    //-------------tpt module interface------------------
    //| --------99  bit------|
    //| index | opcode | len |
    //|  64   |    3   | 32  |
    //|--------------------------==-|
    //DMA Read Ctx metadata backups to mpt module
    input  wire                            dma_rd_mpt_bkup_rd_en,
    output wire  [DMA_RD_BKUP_WIDTH-1:0]   dma_rd_mpt_bkup_dout,
    output wire                            dma_rd_mpt_bkup_empty,

    //-------------DMA Engine module interface------------------
    /* dma_*_head(interact with DMA modules), valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:12   |    11:0     |
     */
    //DMA tpt Context Read Request to dma engine
    output  wire                           dma_v2p_mpt_rd_req_valid,
    output  wire                           dma_v2p_mpt_rd_req_last ,
    output  wire [(`DT_WIDTH-1):0]         dma_v2p_mpt_rd_req_data ,
    output  wire [(`HD_WIDTH-1):0]         dma_v2p_mpt_rd_req_head ,
    input   wire                           dma_v2p_mpt_rd_req_ready,
    
    output  wire                           dma_v2p_mtt_rd_req_valid,
    output  wire                           dma_v2p_mtt_rd_req_last ,
    output  wire [(`DT_WIDTH-1):0]         dma_v2p_mtt_rd_req_data ,
    output  wire [(`HD_WIDTH-1):0]         dma_v2p_mtt_rd_req_head ,
    input   wire                           dma_v2p_mtt_rd_req_ready
    
    `ifdef V2P_DUG
    //apb_slave
        ,  input wire [`V2P_RDCTX_DBG_RW_NUM * 32 - 1 : 0]   rw_data

    ,  output wire [`V2P_RDCTX_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_rdctx
    `endif

);  


//origianl tptmdata req backups fifo
wire                            dma_rd_mpt_bkup_prog_full;
reg                             dma_rd_mpt_bkup_wr_en;
reg    [DMA_RD_BKUP_WIDTH-1 :0] dma_rd_mpt_bkup_din;
mpt_rd_backups_fifo_99w32d mpt_rd_backups_fifo_99w32d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (dma_rd_mpt_bkup_wr_en),
        .rd_en      (dma_rd_mpt_bkup_rd_en),
        .din        (dma_rd_mpt_bkup_din),
        .dout       (dma_rd_mpt_bkup_dout),
        .full       (),
        .empty      (dma_rd_mpt_bkup_empty),     
        .prog_full  (dma_rd_mpt_bkup_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[1 * 32 - 1 : 0])        
    `endif
);                             


reg                           q_mpt_rd_req_valid;
reg                           q_mpt_rd_req_last ;
// reg [(`DT_WIDTH-1):0]         qv_mpt_rd_req_data ;
reg [(`HD_WIDTH-1-32):0]         qv_mpt_rd_req_head ;

reg                           q_mtt_rd_req_valid;
reg                           q_mtt_rd_req_last ;
// reg [(`DT_WIDTH-1):0]         qv_mtt_rd_req_data ;
reg [(`HD_WIDTH-1-32):0]         qv_mtt_rd_req_head ;


//-----------------Output Decode-------------
assign dma_rd_mpt_req_rd_en = !dma_rd_mpt_req_empty && dma_v2p_mpt_rd_req_ready && !dma_rd_mpt_bkup_prog_full;
assign dma_rd_mtt_req_rd_en = !dma_rd_mtt_req_empty && dma_v2p_mtt_rd_req_ready;

//reg                               dma_rd_mpt_bkup_wr_en;
//reg    [DMA_RD_BKUP_WIDTH-1 :0]   dma_rd_mpt_bkup_din;
//reg                               q_mpt_rd_req_valid;
//reg                               q_mpt_rd_req_last ;
//reg [(`DT_WIDTH-1):0]             qv_mpt_rd_req_data ;
//reg [(`HD_WIDTH-1):0]             qv_mpt_rd_req_head ;
// dma_*_head, valid only in first beat of a packet
// | Reserved | address | Reserved | Byte length |
// |  127:96  |  95:32  |  31:12   |    11:0     |
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dma_rd_mpt_bkup_wr_en   <= `TD 0;
        dma_rd_mpt_bkup_din     <= `TD 0;
        q_mpt_rd_req_valid      <= `TD 0;
        q_mpt_rd_req_last       <= `TD 0;
        // qv_mpt_rd_req_data      <= `TD 0;
        qv_mpt_rd_req_head      <= `TD 0;        
    end
    else if (dma_rd_mpt_req_rd_en && dma_v2p_mpt_rd_req_ready && !dma_rd_mpt_bkup_prog_full) begin
        dma_rd_mpt_bkup_wr_en   <= `TD 1;
        dma_rd_mpt_bkup_din     <= `TD dma_rd_mpt_req_dout[DMA_RD_HD_WIDTH-1:64];       
        q_mpt_rd_req_valid      <= `TD 1;
        q_mpt_rd_req_last       <= `TD 1;
        // qv_mpt_rd_req_data      <= `TD 0;
        // qv_mpt_rd_req_head      <= `TD {32'b0,dma_rd_mpt_req_dout[63:0],dma_rd_mpt_req_dout[95:64]};
        qv_mpt_rd_req_head      <= `TD {dma_rd_mpt_req_dout[63:0],dma_rd_mpt_req_dout[95:64]};
    end
    else begin
        dma_rd_mpt_bkup_wr_en   <= `TD 0;
        dma_rd_mpt_bkup_din     <= `TD 0;
        q_mpt_rd_req_valid      <= `TD 0;
        q_mpt_rd_req_last       <= `TD 0;
        // qv_mpt_rd_req_data      <= `TD 0;
        qv_mpt_rd_req_head      <= `TD 0;
    end
end

assign dma_v2p_mpt_rd_req_valid = q_mpt_rd_req_valid;
assign dma_v2p_mpt_rd_req_last  = q_mpt_rd_req_last ;
assign dma_v2p_mpt_rd_req_data  = 256'b0;
assign dma_v2p_mpt_rd_req_head  = {32'b0,qv_mpt_rd_req_head};

//reg                               dma_rd_mtt_bkup_wr_en;
//reg    [DMA_RD_BKUP_WIDTH-1 :0]   dma_rd_mtt_bkup_din;
//reg                               q_mtt_rd_req_valid;
//reg                               q_mtt_rd_req_last ;
//reg [(`DT_WIDTH-1):0]             qv_mtt_rd_req_data ;
//reg [(`HD_WIDTH-1):0]             qv_mtt_rd_req_head ;
// dma_*_head, valid only in first beat of a packet
// | Reserved | address | Reserved | Byte length |
// |  127:96  |  95:32  |  31:12   |    11:0     |
 always @(posedge clk or posedge rst) begin
     if (rst) begin
         q_mtt_rd_req_valid      <= `TD 0;
         q_mtt_rd_req_last       <= `TD 0;
        //  qv_mtt_rd_req_data      <= `TD 0;
         qv_mtt_rd_req_head      <= `TD 0;        
     end
     else if (dma_rd_mtt_req_rd_en && dma_v2p_mtt_rd_req_ready) begin
         q_mtt_rd_req_valid      <= `TD 1;
         q_mtt_rd_req_last       <= `TD 1;
        //  qv_mtt_rd_req_data      <= `TD 0;
        //  qv_mtt_rd_req_head      <= `TD {32'b0,dma_rd_mtt_req_dout[63:0],dma_rd_mtt_req_dout[95:64]};
         qv_mtt_rd_req_head      <= `TD {dma_rd_mtt_req_dout[63:0],dma_rd_mtt_req_dout[95:64]};
     end
     else begin
         q_mtt_rd_req_valid      <= `TD 0;
         q_mtt_rd_req_last       <= `TD 0;
        //  qv_mtt_rd_req_data      <= `TD 0;
         qv_mtt_rd_req_head      <= `TD 0;
     end
 end
 assign dma_v2p_mtt_rd_req_valid = q_mtt_rd_req_valid;
 assign dma_v2p_mtt_rd_req_last  = q_mtt_rd_req_last ;
 assign dma_v2p_mtt_rd_req_data  = 256'b0;
//  assign dma_v2p_mtt_rd_req_head  = qv_mtt_rd_req_head;
 assign dma_v2p_mtt_rd_req_head  = {32'b0,qv_mtt_rd_req_head};


`ifdef V2P_DUG
    // /*****************Add for APB-slave regs**********************************/ 
        // reg                             dma_rd_mpt_bkup_wr_en;
        // reg    [DMA_RD_BKUP_WIDTH-1 :0] dma_rd_mpt_bkup_din;
        // reg                           q_mpt_rd_req_valid;
        // reg                           q_mpt_rd_req_last ;
        // reg [(`DT_WIDTH-1):0]         qv_mpt_rd_req_data ;
        // reg [(`HD_WIDTH-1):0]         qv_mpt_rd_req_head ;
        // reg                           q_mtt_rd_req_valid;
        // reg                           q_mtt_rd_req_last ;
        // reg [(`DT_WIDTH-1):0]         qv_mtt_rd_req_data ;
        // reg [(`HD_WIDTH-1):0]         qv_mtt_rd_req_head ;

    // /*****************Add for APB-slave wires**********************************/ 
        // wire                           dma_rd_mpt_req_rd_en,
        // wire  [DMA_RD_HD_WIDTH-1:0]    dma_rd_mpt_req_dout,
        // wire                           dma_rd_mpt_req_empty,
        // wire                           dma_rd_mtt_req_rd_en,
        // wire  [DMA_RD_HD_WIDTH-1:0]    dma_rd_mtt_req_dout,
        // wire                           dma_rd_mtt_req_empty,
        // wire                            dma_rd_mpt_bkup_rd_en,
        // wire  [DMA_RD_BKUP_WIDTH-1:0]   dma_rd_mpt_bkup_dout,
        // wire                            dma_rd_mpt_bkup_empty,
        // wire                           dma_v2p_mpt_rd_req_valid,
        // wire                           dma_v2p_mpt_rd_req_last ,
        // wire [(`DT_WIDTH-1):0]         dma_v2p_mpt_rd_req_data ,
        // wire [(`HD_WIDTH-1):0]         dma_v2p_mpt_rd_req_head ,
        // wire                           dma_v2p_mpt_rd_req_ready,
        // wire                           dma_v2p_mtt_rd_req_valid,
        // wire                           dma_v2p_mtt_rd_req_last ,
        // wire [(`DT_WIDTH-1):0]         dma_v2p_mtt_rd_req_data ,
        // wire [(`HD_WIDTH-1):0]         dma_v2p_mtt_rd_req_head ,
        // wire                           dma_v2p_mtt_rd_req_ready
        // wire                            dma_rd_mpt_bkup_prog_full;

    //Total regs and wires : 1502 = 46*32 + 30

    assign wv_dbg_bus_rdctx = {
        2'b0,
        dma_rd_mpt_bkup_wr_en,
        dma_rd_mpt_bkup_din,
        q_mpt_rd_req_valid,
        q_mpt_rd_req_last,
        // qv_mpt_rd_req_data,
        qv_mpt_rd_req_head,
        q_mtt_rd_req_valid,
        q_mtt_rd_req_last,
        // qv_mtt_rd_req_data,
        qv_mtt_rd_req_head,

        dma_rd_mpt_req_rd_en,
        dma_rd_mpt_req_dout,
        dma_rd_mpt_req_empty,
        dma_rd_mtt_req_rd_en,
        dma_rd_mtt_req_dout,
        dma_rd_mtt_req_empty,
        dma_rd_mpt_bkup_rd_en,
        dma_rd_mpt_bkup_dout,
        dma_rd_mpt_bkup_empty,
        dma_v2p_mpt_rd_req_valid,
        dma_v2p_mpt_rd_req_last ,
        dma_v2p_mpt_rd_req_data ,
        dma_v2p_mpt_rd_req_head ,
        dma_v2p_mpt_rd_req_ready,
        dma_v2p_mtt_rd_req_valid,
        dma_v2p_mtt_rd_req_last ,
        dma_v2p_mtt_rd_req_data ,
        dma_v2p_mtt_rd_req_head ,
        dma_v2p_mtt_rd_req_ready,
        dma_rd_mpt_bkup_prog_full
    };

`endif 

endmodule