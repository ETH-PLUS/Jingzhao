//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: ctxmgt.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V1.0 
// VERSION DESCRIPTION: Second Edition  
//----------------------------------------------------
// RELEASE DATE: 2022-02-23 
//---------------------------------------------------- 
// PURPOSE: top design of CtxMgt module.
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
// 
//-FHDR-----------------------------------------------


//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_ctxmgt_h.vh"

module ctxmgt#(
    parameter  QPCM_RAM_DWIDTH = 52,  //qpcmdata RAM data width
    parameter  QPCM_RAM_AWIDTH = 10,  //qpcmdata RAM addr width
    parameter  QPCM_RAM_DEPTH  = 1024,//qpcmdata RAM depth
    parameter  CQCM_RAM_DWIDTH = 52, //cqcmdata RAM data width
    parameter  CQCM_RAM_AWIDTH = 8,  //cqcmdata RAM addr width
    parameter  CQCM_RAM_DEPTH  = 256, //cqcmdata RAM depth

    parameter INDEX  = 13// cqc/qpc index width
    )(
    input clk,
    input rst,

	output	wire						cxtmgt_init_finish,

//Intrerface with CEU 
    //CEU request
    input   wire                     ceu_req_valid,
    input   wire [`DT_WIDTH-1:0]     ceu_req_data,
    input   wire                     ceu_req_last,
    input   wire [`HD_WIDTH-1:0]     ceu_req_header,
    output  wire                     ceu_req_ready,
    //response to CEU
    output  wire                     ceu_rsp_valid,
    output  wire                     ceu_rsp_last ,
    output  wire [(`DT_WIDTH-1):0]   ceu_rsp_data ,
    output  wire [(`HD_WIDTH-1):0]   ceu_rsp_head ,
    input   wire                     ceu_rsp_ready,

//Interface with RDMA Engine
    //Channel 1 for DoorbellProcessing, read cxt req, response ctx req, response ctx info, no write ctx req
    input   wire                i_db_cxtmgt_cmd_empty,
    output  wire                o_db_cxtmgt_cmd_rd_en,
    input   wire    [127:0]     iv_db_cxtmgt_cmd_data,

    output  wire                o_db_cxtmgt_resp_wr_en,
    input   wire                i_db_cxtmgt_resp_prog_full,
    output  wire    [127:0]     ov_db_cxtmgt_resp_data,
    /*SpyGlass*/
    output  wire                o_db_cxtmgt_resp_cxt_wr_en,
    input   wire                i_db_cxtmgt_resp_cxt_prog_full,
    output  wire    [255:0]     ov_db_cxtmgt_resp_cxt_data,
    /*Action = modify*/

    //Channel 2 for WQEParser, read cxt req, response ctx req, response ctx info, no write ctx req
    input   wire                i_wp_cxtmgt_cmd_empty,
    output  wire                o_wp_cxtmgt_cmd_rd_en,
    input   wire    [127:0]     iv_wp_cxtmgt_cmd_data,

    output  wire                o_wp_cxtmgt_resp_wr_en,
    input   wire                i_wp_cxtmgt_resp_prog_full,
    output  wire    [127:0]     ov_wp_cxtmgt_resp_data,
    
    /*SpyGlass*/
    output  wire                o_wp_cxtmgt_resp_cxt_wr_en,
    input   wire                i_wp_cxtmgt_resp_cxt_prog_full,
    output  wire    [127:0]     ov_wp_cxtmgt_resp_cxt_data,
    /*Action = modify*/

    //Channel 3 for RequesterTransControl, read cxt req, response ctx req, response ctx info, write ctx req
    input   wire                i_rtc_cxtmgt_cmd_empty,
    output  wire                o_rtc_cxtmgt_cmd_rd_en,
    input   wire    [127:0]     iv_rtc_cxtmgt_cmd_data,

    output  wire                o_rtc_cxtmgt_resp_wr_en,
    input   wire                i_rtc_cxtmgt_resp_prog_full,
    output  wire    [127:0]     ov_rtc_cxtmgt_resp_data,

    output  wire                o_rtc_cxtmgt_resp_cxt_wr_en,
    input   wire                i_rtc_cxtmgt_resp_cxt_prog_full,
    output  wire    [9*32-1:0]     ov_rtc_cxtmgt_resp_cxt_data,

    input   wire                i_rtc_cxtmgt_cxt_empty,
    output  wire                o_rtc_cxtmgt_cxt_rd_en,
    input   wire    [127:0]     iv_rtc_cxtmgt_cxt_data,

    //Channel 4 for RequesterRecvControl, read/write cxt req, response ctx req, response ctx info,  write ctx info
    input   wire                i_rrc_cxtmgt_cmd_empty,
    output  wire                o_rrc_cxtmgt_cmd_rd_en,
    input   wire    [127:0]     iv_rrc_cxtmgt_cmd_data,

    output  wire                o_rrc_cxtmgt_resp_wr_en,
    input   wire                i_rrc_cxtmgt_resp_prog_full,
    output  wire    [127:0]     ov_rrc_cxtmgt_resp_data,

    output  wire                o_rrc_cxtmgt_resp_cxt_wr_en,
    input   wire                i_rrc_cxtmgt_resp_cxt_prog_full,
    output  wire    [32*11-1:0]     ov_rrc_cxtmgt_resp_cxt_data,

    input   wire                i_rrc_cxtmgt_cxt_empty,
    output  wire                o_rrc_cxtmgt_cxt_rd_en,
    input   wire    [127:0]     iv_rrc_cxtmgt_cxt_data,

    //Channel 5 for ExecutionEngine, read/write cxt req, response ctx req, response ctx info,  write ctx info
    input   wire                i_ee_cxtmgt_cmd_empty,
    output  wire                o_ee_cxtmgt_cmd_rd_en,
    input   wire    [127:0]     iv_ee_cxtmgt_cmd_data,

    output  wire                o_ee_cxtmgt_resp_wr_en,
    input   wire                i_ee_cxtmgt_resp_prog_full,
    output  wire    [127:0]     ov_ee_cxtmgt_resp_data,

    output  wire                o_ee_cxtmgt_resp_cxt_wr_en,
    input   wire                i_ee_cxtmgt_resp_cxt_prog_full,
    output  wire    [32*13-1:0]     ov_ee_cxtmgt_resp_cxt_data,

    input   wire                i_ee_cxtmgt_cxt_empty,
    output  wire                o_ee_cxtmgt_cxt_rd_en,
    input   wire    [127:0]     iv_ee_cxtmgt_cxt_data,

    //Channel 6 for FrameEncap, read cxt req, response ctx req, response ctx info
    input   wire                i_fe_cxtmgt_cmd_empty,
    output  wire                o_fe_cxtmgt_cmd_rd_en,
    input   wire    [127:0]     iv_fe_cxtmgt_cmd_data,

    output  wire                o_fe_cxtmgt_resp_wr_en,
    input   wire                i_fe_cxtmgt_resp_prog_full,
    output  wire    [127:0]     ov_fe_cxtmgt_resp_data,

    output  wire                o_fe_cxtmgt_resp_cxt_wr_en,
    input   wire                i_fe_cxtmgt_resp_cxt_prog_full,
    output  wire    [255:0]     ov_fe_cxtmgt_resp_cxt_data,


//Interface with DMA Engine
    // Context Management DMA Read Request
    output  wire                           dma_cm_rd_req_valid,
    output  wire                           dma_cm_rd_req_last ,
    output  wire [(`DT_WIDTH-1):0]         dma_cm_rd_req_data ,
    output  wire [(`HD_WIDTH-1):0]         dma_cm_rd_req_head ,
    input   wire                           dma_cm_rd_req_ready,

    // Context Management DMA Read Response
    input   wire                           dma_cm_rd_rsp_valid,
    input   wire                           dma_cm_rd_rsp_last ,
    input   wire [(`DT_WIDTH-1):0]         dma_cm_rd_rsp_data ,
    input   wire [(`HD_WIDTH-1):0]         dma_cm_rd_rsp_head ,
    output  wire                           dma_cm_rd_rsp_ready,

    // Context Management DMA Write Request
    output  wire                           dma_cm_wr_req_valid,
    output  wire                           dma_cm_wr_req_last ,
    output  wire [(`DT_WIDTH-1):0]         dma_cm_wr_req_data ,
    output  wire [(`HD_WIDTH-1):0]         dma_cm_wr_req_head ,
    input   wire                           dma_cm_wr_req_ready
    
    `ifdef CTX_DUG
        /*Interface with APB Slave*/
	    // ,input 	wire		[`CXTMGT_RW_REG_NUM * 32 - 1 : 0] 		Rw_data
	    // ,output wire 		[`CXTMGT_RO_REG_NUM * 32 - 1 : 0] 		Ro_data
        ,output 	wire 	[32 - 1 : 0]	ro_data
	    ,output wire 	[(`CXTMGT_DBG_RW_NUM) * 32 - 1 : 0]	init_rw_data  //
	    ,input 	wire 	[(`CXTMGT_DBG_RW_NUM) * 32 - 1 : 0]	rw_data  // total 18 ram
	    ,input 	    wire 		[31 : 0]		  Dbg_sel
	    ,output 	wire 		[31 : 0]		  Dbg_bus
    // ,output wire 		[`CXTMGT_DBG_REG_NUM * 32 - 1 : 0]		Dbg_bus
    `endif 
);

reg	 											global_mem_init_finish;
reg	 											init_wea;
reg	 	[`CXT_MEM_MAX_ADDR_WIDTH - 1 : 0]		init_addra;
reg	 	[`CXT_MEM_MAX_DIN_WIDTH - 1 : 0]		init_dina;
reg 	[`CXT_MEM_MAX_ADDR_WIDTH : 0]		init_counter;

assign cxtmgt_init_finish = global_mem_init_finish;

always @(posedge clk or posedge rst) begin
	if(rst) begin
		global_mem_init_finish <= 'd0;
		init_wea <= 'd0;
		init_addra <= 'd0;
		init_dina <= 'd0;	
		init_counter <= 'd0;
	end 
	else if(init_counter < `V2P_MEM_MAX_DEPTH) begin
		global_mem_init_finish <= 'd0;
		init_wea <= 'd1;
		init_addra <= init_counter;
		init_dina <= 'd0;
		init_counter <= init_counter + 'd1;
	end 
	else begin
		global_mem_init_finish <= 'd1;
		init_wea <= 'd0;
		init_addra <= init_addra;
		init_dina <= init_dina;
		init_counter <= init_counter;
	end 
end 

`ifdef CTX_DUG
assign ro_data = 'd0;
    /*****************Add for APB-slave*******************/
    // wire 		[`CXTMGT_RW_REG_NUM * 32 - 1 :0]		wv_reg_config_enble;
    // reg 		[`CXTMGT_RW_REG_NUM * 32 - 1 :0]		rw_reg;
    // assign 		wv_reg_config_enble = Rw_data[`CXTMGT_RW_REG_NUM * 32 - 1 : 0];

    // always @(posedge clk or posedge rst) begin
    // 	if(rst) begin
    // 		rw_reg <= Rw_data; 
    // 	end 
    // 	else if(wv_reg_config_enble == 32'hFFFFFFFF) begin
    // 		rw_reg <= Rw_data;
    // 	end 	
    // 	else begin
    //         rw_reg <= rw_reg;
    // 	end 
    // end

    // wire 	[`PAR_RO_REG_NUM * 32 -1:0]		    wv_ro_data_1;
    // wire 	[`CTXM_RO_REG_NUM * 32 -1:0]		wv_ro_data_2;
    // wire 	[`RDCTX_RO_REG_NUM * 32 -1:0]		wv_ro_data_3;
    // wire 	[`WRCTX_RO_REG_NUM * 32 -1:0]		wv_ro_data_4;
    // wire 	[`KEY_RO_REG_NUM * 32 -1:0]		    wv_ro_data_5;
    // wire 	[`REQCTL_RO_REG_NUM * 32 -1:0]		wv_ro_data_6;

    // assign Ro_data = {wv_ro_data_1,wv_ro_data_2,wv_ro_data_3,wv_ro_data_4,wv_ro_data_5,wv_ro_data_6};

    wire 	[`PAR_DBG_REG_NUM * 32 -1:0]		wv_dbg_bus_1;
    wire 	[`CTXM_DBG_REG_NUM * 32 -1:0]		wv_dbg_bus_2;
    wire 	[`RDCTX_DBG_REG_NUM * 32 -1:0]		wv_dbg_bus_3;
    wire 	[`WRCTX_DBG_REG_NUM * 32 -1:0]		wv_dbg_bus_4;
    wire 	[`KEY_DBG_REG_NUM * 32 -1:0]		wv_dbg_bus_5;
    wire 	[`REQCTL_DBG_REG_NUM * 32 -1:0]		wv_dbg_bus_6;

    wire 	[(`CXTMGT_DBG_REG_NUM) * 32 - 1 : 0] wv_dbg_bus;

    assign wv_dbg_bus = {wv_dbg_bus_1,wv_dbg_bus_2,wv_dbg_bus_3,wv_dbg_bus_4,wv_dbg_bus_5,wv_dbg_bus_6};

    assign Dbg_bus = wv_dbg_bus >> (Dbg_sel << 5);
    //assign Dbg_bus = wv_dbg_bus;
    
    assign init_rw_data = 'b0;

`endif 
/*****************Add for APB-slave*******************/

//-----------------------{internal signals decleration} begin------------------------
  //----------------ceu_parser_ctxmgt--------------
    //OUT to key_qpc_data
        wire                       ceu_wr_req_rd_en;
        wire                       ceu_wr_req_empty;
        wire [`CEUP_REQ_KEY-1:0]   ceu_wr_req_dout;
        wire                       ceu_wr_data_rd_en1;
        wire                       ceu_wr_data_empty1;
        wire [`KEY_QPC_DT-1:0]     ceu_wr_data_dout1;
        wire                       ceu_wr_data_rd_en2;
        wire                       ceu_wr_data_empty2;
        wire [`KEY_QPC_DT-1:0]     ceu_wr_data_dout2;
    //OUT to ctxmdata;
        wire                       ceu_req_ctxmdata_rd_en;
        wire                       ceu_req_ctxmdata_empty;
        wire [`CEUP_REQ_MDT-1:0]   ceu_req_ctxmdata_dout;
        wire                       ctxmdata_data_rd_en;
        wire                       ctxmdata_data_empty;
        wire [`INTER_DT-1:0]       ctxmdata_data_dout;
    //OUT to dma_write_ctx;
        wire                  ctx_data_rd_en;
        wire                  ctx_data_empty;
        wire [`INTER_DT-1:0]  ctx_data_dout ;

  //----------------request_controller--------------
    //OUT to key_qpc_data
   		//Modifier-YF
        //wire  [6 :0]  selected_channel;
        wire  [7 :0]  selected_channel;
    //IN from key_qpc_data module indicate that key_qpc_data module has received the req from selected_channel fifo
        wire receive_req;

  //----------------------ctxmdata-----------------
    //IN from key_qpc_data
        //internal key_qpc_data Request In interface
        wire                      key_ctx_req_mdt_rd_en;
        wire  [`HD_WIDTH-1:0]     key_ctx_req_mdt_dout;
        wire                      key_ctx_req_mdt_empty;

    //OUT to dma_read_ctx
        //DMA Read Ctx Request Out interface
        wire                            mdt_req_rd_ctx_rd_en;
        wire [`MDT_REQ_RD_CTX-1:0]      mdt_req_rd_ctx_dout;
        wire                            mdt_req_rd_ctx_empty;
    //OUT to dma_write_ctx
        //DMA Write Ctx Request Out interfac;
        wire                     mdt_req_wr_ctx_rd_en;
        wire  [`HD_WIDTH-1:0]    mdt_req_wr_ctx_dout;
        wire                     mdt_req_wr_ctx_empty;
  //----------------------key_qpc_data-----------------
        //all signals have been decleared before



//-----------------------{internal signals decleration} end------------------------
ceu_parser_ctxmgt u_ceu_parser_ctxmgt(
    .clk        (clk),
    .rst        (rst),

    // externel Parse msg requests header from CEU 
    .ceu_req_valid (ceu_req_valid), //input   wire                
    .ceu_req_ready (ceu_req_ready), //output  wire                
    .ceu_req_data (ceu_req_data),  //input   wire [`DT_WIDTH-1:0]
    .ceu_req_last (ceu_req_last),  //input   wire                
    .ceu_req_header (ceu_req_header), //input   wire [`HD_WIDTH-1:0]

    // internal request cmd fifo to write key_qpc_data
    //53 width 
    .ceu_wr_req_rd_en (ceu_wr_req_rd_en),//input   wire                       
    .ceu_wr_req_empty (ceu_wr_req_empty),//output  wire                      
    .ceu_wr_req_dout  (ceu_wr_req_dout ), //output  wire [`CEUP_REQ_KEY-1:0]   
    // internal context data fifo to write key_qpc_data
    //384 width 
    .ceu_wr_data_rd_en1 (ceu_wr_data_rd_en1),//input   wire                       
    .ceu_wr_data_empty1 (ceu_wr_data_empty1),//output  wire                       
    .ceu_wr_data_dout1 (ceu_wr_data_dout1),//output  wire [`KEY_QPC_DT-1:0]     
    .ceu_wr_data_rd_en2 (ceu_wr_data_rd_en2),//input   wire                       
    .ceu_wr_data_empty2 (ceu_wr_data_empty2),//output  wire                       
    .ceu_wr_data_dout2 (ceu_wr_data_dout2),//output  wire [`KEY_QPC_DT-1:0]     

    // internal req cmd to ctxmdata Module
    //53 width 16 depth syn FIFO format1
    .ceu_req_ctxmdata_rd_en (ceu_req_ctxmdata_rd_en),//input   wire                      
    .ceu_req_ctxmdata_empty (ceu_req_ctxmdata_empty),//output  wire                      
    .ceu_req_ctxmdata_dout (ceu_req_ctxmdata_dout),//output  wire [`CEUP_REQ_MDT-1:0]  

    // internel context metaddata payload to write ctxmdata Module
    // 256 width 24 depth syn FIFO (only context meatadata)
    .ctxmdata_data_rd_en (ctxmdata_data_rd_en),//input   wire                   
    .ctxmdata_data_empty (ctxmdata_data_empty),//output  wire                   
    .ctxmdata_data_dout (ctxmdata_data_dout),//output  wire [`INTER_DT-1:0]   

    // internal context data to writectx module to write to host memory
    .ctx_data_rd_en (ctx_data_rd_en),//input   wire                  
    .ctx_data_empty (ctx_data_empty),//output  wire                  
    .ctx_data_dout  (ctx_data_dout )//output  wire [`INTER_DT-1:0]  

    `ifdef CTX_DUG
    //apb_slave
    , .rw_data(rw_data[`PAR_DBG_RW_NUM * 32 - 1 : 0])
    , .wv_dbg_bus_1(wv_dbg_bus_1)
    `endif 
);

request_controller u_request_controller(
    .clk        (clk),
    .rst        (rst),

    //these signals from the rd_req_empty singal of CEU, and other 5 reqs from RDMA Engine submodule
    .rd_ceu_req_empty     (ceu_wr_req_empty), //input  wire  
    .rd_dbp_req_empty     (i_db_cxtmgt_cmd_empty), //input  wire  
    .rd_wp_wqe_req_empty  (i_wp_cxtmgt_cmd_empty), //input  wire  
    .rd_rtc_req_empty     (i_rtc_cxtmgt_cmd_empty), //input  wire  
    .rd_rrc_req_empty     (i_rrc_cxtmgt_cmd_empty), //input  wire  
    .rd_ee_req_empty      (i_ee_cxtmgt_cmd_empty), //input  wire  
    .rd_fe_req_empty      (i_fe_cxtmgt_cmd_empty), //input  wire  
    //req_scheduler changes the value of Selected Channel Reg to mark the selected channel,key_qpc_data moduel read the info
    .selected_channel (selected_channel),//output reg  [7 :0]  
    //receive signal from key_qpc_data module indicate that key_qpc_data module has received the req from selected_channel fifo
    .receive_req (receive_req) //input  wire

    `ifdef CTX_DUG
    //apb_slave
    // .wv_ro_data_6(wv_ro_data_6),
    , .wv_dbg_bus_6(wv_dbg_bus_6)
    `endif 
);

ctxmdata #(
    .QPCM_RAM_DWIDTH (QPCM_RAM_DWIDTH), ///qpcmdata RAM data width
    .QPCM_RAM_AWIDTH (QPCM_RAM_AWIDTH), ///qpcmdata RAM addr width
    .QPCM_RAM_DEPTH  (QPCM_RAM_DEPTH ), ///qpcmdata RAM depth
    .CQCM_RAM_DWIDTH (CQCM_RAM_DWIDTH), //cqcmdata RAM data width
    .CQCM_RAM_AWIDTH (CQCM_RAM_AWIDTH), //cqcmdata RAM addr width
    .CQCM_RAM_DEPTH  (CQCM_RAM_DEPTH ) //cqcmdata RAM depth
    ) u_ctxmdata(
    .clk        (clk),
    .rst        (rst),

    // internal ceu_parser req cmd to ctxmdata Module
    //128 width 16 depth syn FIFO format1
    .ceu_req_ctxmdata_rd_en (ceu_req_ctxmdata_rd_en),//output  wire                      
    .ceu_req_ctxmdata_empty (ceu_req_ctxmdata_empty),//input   wire                      
    .ceu_req_ctxmdata_dout (ceu_req_ctxmdata_dout),//input   wire [`CEUP_REQ_MDT-1:0]  

    // internel ceu_parser context metaddata payload to write ctxmdata Module
    // 256 width 24 depth syn FIFO (only context meatadata)
    .ctxmdata_data_rd_en (ctxmdata_data_rd_en),//output  wire                     
    .ctxmdata_data_empty (ctxmdata_data_empty),//input   wire                     
    .ctxmdata_data_dout (ctxmdata_data_dout),//input   wire [`INTER_DT-1:0]     
    
    //internal key_qpc_data Request In interface
    .key_ctx_req_mdt_rd_en (key_ctx_req_mdt_rd_en),//output wire                      
    .key_ctx_req_mdt_dout (key_ctx_req_mdt_dout),//input  wire  [`HD_WIDTH-1:0]     
    .key_ctx_req_mdt_empty (key_ctx_req_mdt_empty),//input  wire                      
   
    //DMA Read Ctx Request Out interface
    .mdt_req_rd_ctx_rd_en (mdt_req_rd_ctx_rd_en),//input  wire                            
    .mdt_req_rd_ctx_dout (mdt_req_rd_ctx_dout),//output wire [`MDT_REQ_RD_CTX-1:0]      
    .mdt_req_rd_ctx_empty (mdt_req_rd_ctx_empty),//output wire                            

    //DMA Write Ctx Request Out interface
    .mdt_req_wr_ctx_rd_en (mdt_req_wr_ctx_rd_en), //input  wire                     
    .mdt_req_wr_ctx_dout  (mdt_req_wr_ctx_dout ), //output wire  [`HD_WIDTH-1:0]    
    .mdt_req_wr_ctx_empty (mdt_req_wr_ctx_empty) //output wire    
    
    `ifdef CTX_DUG    
    //apb_slave
    // .wv_ro_data_2(wv_ro_data_2),
    , .rw_data(rw_data[(`PAR_DBG_RW_NUM+`REQCTL_DBG_RW_NUM) *32 +: `CTXM_DBG_RW_NUM * 32])
    , .wv_dbg_bus_2(wv_dbg_bus_2)
    `endif 
);

key_qpc_data#(
    .INDEX (INDEX)// cqc/qpc index width
    ) u_key_qpc_data(
    .clk        (clk),
    .rst        (rst), 

	.global_mem_init_finish(global_mem_init_finish),
	.init_wea(init_wea),
	.init_addra(init_addra),
	.init_dina(init_dina),

    //------------------interface to request controller----------------------
        //req_scheduler changes the value of Selected Channel Reg to mark the selected channel,key_qpc_data moduel read the info
        .selected_channel (selected_channel),//input  wire  [7 :0]  
        //send signal to request controller indicate that key_qpc_data module has received the req from selected_channel fifo
        .receive_req (receive_req), //output reg
    //------------------interface to ceu channel----------------------
        // internal request cmd fifo from ceu_parser
        //35 width 
        .ceu_wr_req_rd_en (ceu_wr_req_rd_en),//output wire                      
        .ceu_wr_req_empty (ceu_wr_req_empty),//input  wire                      
        .ceu_wr_req_dout  (ceu_wr_req_dout ),//input  wire [`CEUP_REQ_KEY-1:0]  
        // internal context data fifo from ceu_parser
        //384 width 
        .ceu_wr_data_rd_en1 (ceu_wr_data_rd_en1),//input   wire                       
        .ceu_wr_data_empty1 (ceu_wr_data_empty1),//output  wire                       
        .ceu_wr_data_dout1 (ceu_wr_data_dout1),//output  wire [`KEY_QPC_DT-1:0]     
        .ceu_wr_data_rd_en2 (ceu_wr_data_rd_en2),//input   wire                       
        .ceu_wr_data_empty2 (ceu_wr_data_empty2),//output  wire                       
        .ceu_wr_data_dout2 (ceu_wr_data_dout2),//output  wire [`KEY_QPC_DT-1:0]     

    //Interface with RDMA Engine
        //Channel 1 for DoorbellProcessing, read cxt req, response ctx req, response ctx info, no write ctx req
        .i_db_cxtmgt_cmd_empty (i_db_cxtmgt_cmd_empty),//input   wire           
        .o_db_cxtmgt_cmd_rd_en (o_db_cxtmgt_cmd_rd_en),//output  wire           
        .iv_db_cxtmgt_cmd_data (iv_db_cxtmgt_cmd_data),//input   wire    [127:0]

        .o_db_cxtmgt_resp_wr_en (o_db_cxtmgt_resp_wr_en),//output  reg            
        .i_db_cxtmgt_resp_prog_full (i_db_cxtmgt_resp_prog_full),//input   wire           
        .ov_db_cxtmgt_resp_data (ov_db_cxtmgt_resp_data),//output  reg     [127:0]

        .o_db_cxtmgt_resp_cxt_wr_en (o_db_cxtmgt_resp_cxt_wr_en),//output  reg            
        .i_db_cxtmgt_resp_cxt_prog_full (i_db_cxtmgt_resp_cxt_prog_full),//input   wire           
        .ov_db_cxtmgt_resp_cxt_data (ov_db_cxtmgt_resp_cxt_data),//output  reg     [255:0]

        //Channel 2 for WQEParser, read cxt req, response ctx req, response ctx info, no write ctx req
        .i_wp_cxtmgt_cmd_empty (i_wp_cxtmgt_cmd_empty),//input   wire                
        .o_wp_cxtmgt_cmd_rd_en (o_wp_cxtmgt_cmd_rd_en),//output  wire                
        .iv_wp_cxtmgt_cmd_data (iv_wp_cxtmgt_cmd_data),//input   wire    [127:0]     

        .o_wp_cxtmgt_resp_wr_en (o_wp_cxtmgt_resp_wr_en),//output  reg                 
        .i_wp_cxtmgt_resp_prog_full (i_wp_cxtmgt_resp_prog_full),//input   wire                
        .ov_wp_cxtmgt_resp_data (ov_wp_cxtmgt_resp_data),//output  reg     [127:0]     

        .o_wp_cxtmgt_resp_cxt_wr_en (o_wp_cxtmgt_resp_cxt_wr_en),//output  reg                 
        .i_wp_cxtmgt_resp_cxt_prog_full (i_wp_cxtmgt_resp_cxt_prog_full),//input   wire                
        .ov_wp_cxtmgt_resp_cxt_data (ov_wp_cxtmgt_resp_cxt_data),//output  reg     [127:0]     

        //Channel 3 for RequesterTransControl, read cxt req, response ctx req, response ctx info, write ctx req
        .i_rtc_cxtmgt_cmd_empty (i_rtc_cxtmgt_cmd_empty),//input   wire                
        .o_rtc_cxtmgt_cmd_rd_en (o_rtc_cxtmgt_cmd_rd_en),//output  wire                
        .iv_rtc_cxtmgt_cmd_data (iv_rtc_cxtmgt_cmd_data),//input   wire    [127:0]     

        .o_rtc_cxtmgt_resp_wr_en (o_rtc_cxtmgt_resp_wr_en),//output  reg                 
        .i_rtc_cxtmgt_resp_prog_full (i_rtc_cxtmgt_resp_prog_full),//input   wire                
        .ov_rtc_cxtmgt_resp_data (ov_rtc_cxtmgt_resp_data),//output  reg     [127:0]     

        .o_rtc_cxtmgt_resp_cxt_wr_en (o_rtc_cxtmgt_resp_cxt_wr_en),//output  reg                 
        .i_rtc_cxtmgt_resp_cxt_prog_full (i_rtc_cxtmgt_resp_cxt_prog_full),//input   wire                
        .ov_rtc_cxtmgt_resp_cxt_data (ov_rtc_cxtmgt_resp_cxt_data),//output  reg     [191:0]     

        .i_rtc_cxtmgt_cxt_empty (i_rtc_cxtmgt_cxt_empty),//input   wire                
        .o_rtc_cxtmgt_cxt_rd_en (o_rtc_cxtmgt_cxt_rd_en),//output  wire                
        .iv_rtc_cxtmgt_cxt_data (iv_rtc_cxtmgt_cxt_data),//input   wire    [127:0]     

        //Channel 4 for RequesterRecvContro, read/write cxt req, response ctx req, response ctx info,  write ctx info
        .i_rrc_cxtmgt_cmd_empty (i_rrc_cxtmgt_cmd_empty),//input   wire                
        .o_rrc_cxtmgt_cmd_rd_en (o_rrc_cxtmgt_cmd_rd_en),//output  wire                
        .iv_rrc_cxtmgt_cmd_data (iv_rrc_cxtmgt_cmd_data),//input   wire    [127:0]     

        .o_rrc_cxtmgt_resp_wr_en (o_rrc_cxtmgt_resp_wr_en),//output  reg                 
        .i_rrc_cxtmgt_resp_prog_full (i_rrc_cxtmgt_resp_prog_full),//input   wire                
        .ov_rrc_cxtmgt_resp_data (ov_rrc_cxtmgt_resp_data),//output  reg     [127:0]     

        .o_rrc_cxtmgt_resp_cxt_wr_en (o_rrc_cxtmgt_resp_cxt_wr_en),//output  reg                 
        .i_rrc_cxtmgt_resp_cxt_prog_full (i_rrc_cxtmgt_resp_cxt_prog_full),//input   wire                
        .ov_rrc_cxtmgt_resp_cxt_data (ov_rrc_cxtmgt_resp_cxt_data),//output  reg     [255:0]     

        .i_rrc_cxtmgt_cxt_empty (i_rrc_cxtmgt_cxt_empty),//input   wire                
        .o_rrc_cxtmgt_cxt_rd_en (o_rrc_cxtmgt_cxt_rd_en),//output  wire                
        .iv_rrc_cxtmgt_cxt_data (iv_rrc_cxtmgt_cxt_data),//input   wire    [127:0]     

        //Channel 5 for ExecutionEngine, read/write cxt req, response ctx req, response ctx info,  write ctx info
        .i_ee_cxtmgt_cmd_empty (i_ee_cxtmgt_cmd_empty), //input   wire            
        .o_ee_cxtmgt_cmd_rd_en (o_ee_cxtmgt_cmd_rd_en), //output  wire            
        .iv_ee_cxtmgt_cmd_data (iv_ee_cxtmgt_cmd_data), //input   wire    [127:0] 

        .o_ee_cxtmgt_resp_wr_en (o_ee_cxtmgt_resp_wr_en), //output  reg             
        .i_ee_cxtmgt_resp_prog_full (i_ee_cxtmgt_resp_prog_full), //input   wire            
        .ov_ee_cxtmgt_resp_data (ov_ee_cxtmgt_resp_data), //output  reg     [127:0] 

        .o_ee_cxtmgt_resp_cxt_wr_en (o_ee_cxtmgt_resp_cxt_wr_en), //output  reg             
        .i_ee_cxtmgt_resp_cxt_prog_full (i_ee_cxtmgt_resp_cxt_prog_full), //input   wire            
        .ov_ee_cxtmgt_resp_cxt_data (ov_ee_cxtmgt_resp_cxt_data), //output  reg     [319:0] 

        .i_ee_cxtmgt_cxt_empty (i_ee_cxtmgt_cxt_empty), //input   wire            
        .o_ee_cxtmgt_cxt_rd_en (o_ee_cxtmgt_cxt_rd_en), //output  wire            
        .iv_ee_cxtmgt_cxt_data (iv_ee_cxtmgt_cxt_data), //input   wire    [127:0] 

        //Channel 6 for FrameEncap, read cxt req, response ctx req, response ctx info
        .i_fe_cxtmgt_cmd_empty (i_fe_cxtmgt_cmd_empty), //input   wire                
        .o_fe_cxtmgt_cmd_rd_en (o_fe_cxtmgt_cmd_rd_en), //output  wire                
        .iv_fe_cxtmgt_cmd_data (iv_fe_cxtmgt_cmd_data), //input   wire    [127:0]     

        .o_fe_cxtmgt_resp_wr_en (o_fe_cxtmgt_resp_wr_en), //output  reg                 
        .i_fe_cxtmgt_resp_prog_full (i_fe_cxtmgt_resp_prog_full), //input   wire                
        .ov_fe_cxtmgt_resp_data (ov_fe_cxtmgt_resp_data), //output  reg     [127:0]     

        .o_fe_cxtmgt_resp_cxt_wr_en (o_fe_cxtmgt_resp_cxt_wr_en), //output  reg                 
        .i_fe_cxtmgt_resp_cxt_prog_full (i_fe_cxtmgt_resp_cxt_prog_full), //input   wire                
        .ov_fe_cxtmgt_resp_cxt_data (ov_fe_cxtmgt_resp_cxt_data), //output  reg     [255:0]     
    //------------------interface to ctxmdata module-------------
        //internal dma write Request to ctxmdata module
        .key_ctx_req_mdt_rd_en (key_ctx_req_mdt_rd_en),//input  wire                      
        .key_ctx_req_mdt_dout  (key_ctx_req_mdt_dout ),//output wire  [`HD_WIDTH-1:0]     
        .key_ctx_req_mdt_empty (key_ctx_req_mdt_empty)//output wire               
    `ifdef CTX_DUG        
    //apb_slave  
    // .wv_ro_data_5(wv_ro_data_5),
    , .rw_data(rw_data[ (`PAR_DBG_RW_NUM+`REQCTL_DBG_RW_NUM+`CTXM_DBG_RW_NUM) *32+: `KEY_DBG_RW_NUM * 32])
    , .wv_dbg_bus_5(wv_dbg_bus_5)
    `endif                     
);

dma_read_ctx_ctxmgt u_dma_read_ctx_ctxmgt(
    .clk        (clk),
    .rst        (rst),
    //-------------ctxmdata module interface------------------
        //|---------108bit---------------|
        //|  addr     | len      | QPN   | 
        //|  64 bit   | 12 bit   | 32 bit|
    //DMA Read Ctx Request from ctxmdata
    .mdt_req_rd_ctx_rd_en (mdt_req_rd_ctx_rd_en), //output wire                            
    .mdt_req_rd_ctx_dout (mdt_req_rd_ctx_dout), //input  wire [`MDT_REQ_RD_CTX-1:0]      
    .mdt_req_rd_ctx_empty (mdt_req_rd_ctx_empty), //input  wire                            

    //-------------DMA Engine module interface------------------
    /* dma_*_head(interact with DMA modules), valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:12   |    11:0     |
     */
    // Context Management DMA Read Request
    .dma_cm_rd_req_valid (dma_cm_rd_req_valid),//output  reg                   
    .dma_cm_rd_req_last  (dma_cm_rd_req_last ),//output  reg                   
    .dma_cm_rd_req_data  (dma_cm_rd_req_data ),//output  reg  [(`DT_WIDTH-1):0]
    .dma_cm_rd_req_head  (dma_cm_rd_req_head ),//output  reg  [(`HD_WIDTH-1):0]
    .dma_cm_rd_req_ready (dma_cm_rd_req_ready),//input   wire                  

    // Context Management DMA Read Response
    .dma_cm_rd_rsp_valid (dma_cm_rd_rsp_valid),//input   wire                  
    .dma_cm_rd_rsp_last  (dma_cm_rd_rsp_last ),//input   wire                  
    .dma_cm_rd_rsp_data  (dma_cm_rd_rsp_data ),//input   wire [(`DT_WIDTH-1):0]
    .dma_cm_rd_rsp_head  (dma_cm_rd_rsp_head ),//input   wire [(`HD_WIDTH-1):0]
    .dma_cm_rd_rsp_ready (dma_cm_rd_rsp_ready),//output  wire                  

    //response to CEU RD_QP_ALL operation
    .ceu_rsp_valid (ceu_rsp_valid),//output  wire                  
    .ceu_rsp_last  (ceu_rsp_last ),//output  wire                  
    .ceu_rsp_data  (ceu_rsp_data ),//output  wire [(`DT_WIDTH-1):0]
    .ceu_rsp_head  (ceu_rsp_head ),//output  wire [(`HD_WIDTH-1):0]
    .ceu_rsp_ready (ceu_rsp_ready)//input   wire 
    
    `ifdef CTX_DUG        
    //apb_slave
    // .wv_ro_data_3(wv_ro_data_3),
    , .rw_data(rw_data[ (`KEY_DBG_RW_NUM +`PAR_DBG_RW_NUM+`REQCTL_DBG_RW_NUM+`CTXM_DBG_RW_NUM) *32 +:`RDCTX_DBG_RW_NUM* 32] )
    , .wv_dbg_bus_3(wv_dbg_bus_3)
    `endif     
);  

dma_write_ctx_ctxmgt u_dma_write_ctx_ctxmgt(
    .clk        (clk),
    .rst        (rst),
    
    //-------------ctxmdata module interface------------------
        //| ------------------128bit------------------------------------|
        //|   type   |  opcode |   Src   | R      |   data   |   addr   | 
        //|    4 bit |  4 bit  |  3 bit  |21 bit  |  32 bit  |  64 bit  |   
    //DMA write Ctx Request from ctxmdata
    .mdt_req_wr_ctx_rd_en (mdt_req_wr_ctx_rd_en),//output wire                 
    .mdt_req_wr_ctx_dout (mdt_req_wr_ctx_dout),//input  wire  [`HD_WIDTH-1:0]
    .mdt_req_wr_ctx_empty (mdt_req_wr_ctx_empty),//input  wire                 

    //-------------ceu_parser interface------------------
    // internal context data to writectx module to write to host memory
    .ctx_data_rd_en (ctx_data_rd_en), //output wire                  
    .ctx_data_empty (ctx_data_empty), //input  wire                  
    .ctx_data_dout (ctx_data_dout), //input  wire [`INTER_DT-1:0]  

    //-------------DMA Engine module interface------------------
    /* dma_*_head(interact with DMA modules), valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:12   |    11:0     |
     */
    //DMA Write Ctx Request Out interface
    .dma_cm_wr_req_valid (dma_cm_wr_req_valid),  // output  reg                   
    .dma_cm_wr_req_last  (dma_cm_wr_req_last ),  // output  reg                   
    .dma_cm_wr_req_data  (dma_cm_wr_req_data ),  // output  reg  [(`DT_WIDTH-1):0]
    .dma_cm_wr_req_head  (dma_cm_wr_req_head ),  // output  reg  [(`HD_WIDTH-1):0]
    .dma_cm_wr_req_ready (dma_cm_wr_req_ready)  // input   wire  

    `ifdef CTX_DUG        
    //apb_slave
    // .wv_ro_data_4(wv_ro_data_4),
    , .wv_dbg_bus_4(wv_dbg_bus_4)
    `endif    
);

endmodule
