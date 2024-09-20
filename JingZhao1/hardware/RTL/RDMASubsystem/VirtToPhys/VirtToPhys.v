//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: VirtToPhys.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V4.0 
// VERSION DESCRIPTION: 4st Edition  
//----------------------------------------------------
// RELEASE DATE: 2022-08-31 
//---------------------------------------------------- 
// PURPOSE: top module. connect all module 
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
//----------------------------------------------------
// Add APB_slave interface
//----------------------------------------------------
//-FHDR-----------------------------------------------

//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_v2p_h.vh"

module VirtToPhys#(
    parameter STWIDTH  = 8,// 8 bits width for State FIFO   
    parameter CHANNEL_WIDTH = 9, // used for Selected Channel Reg to mark the selected channel and Ready, MPT/MTT module may read the info
    parameter PEND_CNT_WIDTH = 32, // used for Pend Channel Reg, req_scheduler may read it to make decision choose which req channel 
    parameter  TPT_HD_WIDTH  = 99,//for MPT/MTT-Mdata req header fifo
    parameter  DMA_RD_HD_WIDTH  = 163,//for Mdata-DMA Read req header fifo
    parameter  DMA_WR_HD_WIDTH  = 99,//for Mdata-DMA Write req header fifo
    parameter  CEU_HD_WIDTH  = 104,//for ceu_tptm_proc - MPTMdata/MTTMdata req header fifo
    parameter  MPTM_RAM_DWIDTH = 52,//mptmdata RAM data width
    parameter  MPTM_RAM_AWIDTH = 9,//mptmdata RAM addr width
    parameter  MPTM_RAM_DEPTH  = 512, //mptmdata RAM depth
    parameter  MTTM_RAM_DWIDTH = 52,//mttmdata RAM data width
    parameter  MTTM_RAM_AWIDTH = 9,//mttmdata RAM addr width
    parameter  MTTM_RAM_DEPTH  = 512, //mttmdata RAM depth

    parameter MPT_SIZE           = 524288, //Total Size(MPT+MTT) 1MB, MPT_RAM occupies 512KB
    parameter MPT_CACHE_WAY_NUM  = 2,//2 way
    parameter MPT_LINE_SIZE      = 64,//Cache line size = 64B(MPT entry= 64B)
    parameter MPT_INDEX           =   12,//mpt_ram index width
    parameter MPT_TAG             =   3,//mpt_ram tag width
    parameter DMA_RD_BKUP_WIDTH  = 99,//for Mdata-TPT Read req header fifo
    parameter MPT_CACHE_BANK_NUM  =   1,
    parameter MTT_SIZE           = 524288, //Total Size(MPT+MTT) 1MB, mtt_RAM occupies 512KB
    parameter MTT_CACHE_WAY_NUM  = 2,//2 way
    parameter MTT_LINE_SIZE      = 32,//Cache line size = 32B(mtt entry= 8B)
    parameter MTT_INDEX           =   13,//mtt_ram index width
    parameter MTT_TAG             =   3,//mtt_ram tag width
    parameter MTT_OFFSET          =   2,//mtt_ram offset width
    parameter MTT_NUM             =   3,//mtt_ram num width to indicate how many mtt entries in 1 cache line
    parameter DMA_DT_REQ_WIDTH    = 134,//mtt_ram_ctl to dma_read/write_data req header fifo 
    parameter MTT_CACHE_BANK_NUM  =   4//1 way BRAM num = 4
    )(
    input clk,
    input rst,

	output 	wire 					v2p_init_finish,

//Intrerface with CEU 
    input   wire                  ceu_req_tvalid,
    output  wire                  ceu_req_tready,
    input   wire [`DT_WIDTH-1:0]  ceu_req_tdata,
    input   wire                  ceu_req_tlast,
    input   wire [`HD_WIDTH-1:0]  ceu_req_theader,

//Interface with RDMA Engine
    //Channel 1 for Doorbell Processing, only read
    input   wire                i_db_vtp_cmd_empty,
    output  wire                o_db_vtp_cmd_rd_en,
    input   wire    [255:0]     iv_db_vtp_cmd_data,

    output  wire                o_db_vtp_resp_wr_en,
    input   wire                i_db_vtp_resp_prog_full,
    output  wire    [7:0]       ov_db_vtp_resp_data,

    output  wire                o_db_vtp_download_wr_en,
    input   wire                i_db_vtp_download_prog_full,
    output  wire    [255:0]     ov_db_vtp_download_data,
        
    //Channel 2 for WQEParser, download SQ WQE
    input   wire                i_wp_vtp_wqe_cmd_empty,
    output  wire                o_wp_vtp_wqe_cmd_rd_en,
    input   wire    [255:0]     iv_wp_vtp_wqe_cmd_data,

    output  wire                o_wp_vtp_wqe_resp_wr_en,
    input   wire                i_wp_vtp_wqe_resp_prog_full,
    output  wire    [7:0]       ov_wp_vtp_wqe_resp_data,

    output  wire                o_wp_vtp_wqe_download_wr_en,
    input   wire                i_wp_vtp_wqe_download_prog_full,
    output  wire    [255:0]     ov_wp_vtp_wqe_download_data,

    //Channel 3 for WQEParser, download network data
    input   wire                i_wp_vtp_nd_cmd_empty,
    output  wire                o_wp_vtp_nd_cmd_rd_en,
    input   wire    [255:0]     iv_wp_vtp_nd_cmd_data,

    output  wire                o_wp_vtp_nd_resp_wr_en,
    input   wire                i_wp_vtp_nd_resp_prog_full,
    output  wire    [7:0]       ov_wp_vtp_nd_resp_data,

    output  wire                o_wp_vtp_nd_download_wr_en,
    input   wire                i_wp_vtp_nd_download_prog_full,
    output  wire    [255:0]     ov_wp_vtp_nd_download_data,

    //Channel 4 for RequesterTransControl, upload Completion Event
    input   wire                i_rtc_vtp_cmd_empty,
    output  wire                o_rtc_vtp_cmd_rd_en,
    input   wire    [255:0]     iv_rtc_vtp_cmd_data,

    output  wire                o_rtc_vtp_resp_wr_en,
    input   wire                i_rtc_vtp_resp_prog_full,
    output  wire    [7:0]       ov_rtc_vtp_resp_data,

    input   wire                i_rtc_vtp_upload_empty,
    output  wire                o_rtc_vtp_upload_rd_en,
    input   wire    [255:0]     iv_rtc_vtp_upload_data,

    //Channel 5 for RequesterRecvControl, upload RDMA Read Response
    input   wire                i_rrc_vtp_cmd_empty,
    output  wire                o_rrc_vtp_cmd_rd_en,
    input   wire    [255:0]     iv_rrc_vtp_cmd_data,

    output  wire                o_rrc_vtp_resp_wr_en,
    input   wire                i_rrc_vtp_resp_prog_full,
    output  wire    [7:0]       ov_rrc_vtp_resp_data,

    input   wire                i_rrc_vtp_upload_empty,
    output  wire                o_rrc_vtp_upload_rd_en,
    input   wire    [255:0]     iv_rrc_vtp_upload_data,

    //Channel 6 for ExecutionEngine, download RQ WQE
    input   wire                i_rwm_vtp_cmd_empty,
    output  wire                o_rwm_vtp_cmd_rd_en,
    input   wire    [255:0]     iv_rwm_vtp_cmd_data,

    output  wire                o_rwm_vtp_resp_wr_en,
    input   wire                i_rwm_vtp_resp_prog_full,
    output  wire    [7:0]       ov_rwm_vtp_resp_data,

    output  wire                o_rwm_vtp_download_wr_en,
    input   wire                i_rwm_vtp_download_prog_full,
    output  wire    [255:0]     ov_rwm_vtp_download_data,

    //Channel 7 for ExecutionEngine, upload Send/Write Payload and download Read Payload
    input   wire                i_ee_vtp_cmd_empty,
    output  wire                o_ee_vtp_cmd_rd_en,
    input   wire    [255:0]     iv_ee_vtp_cmd_data,

    output  wire                o_ee_vtp_resp_wr_en,
    input   wire                i_ee_vtp_resp_prog_full,
    output  wire    [7:0]       ov_ee_vtp_resp_data,

    input   wire                i_ee_vtp_upload_empty,
    output  wire                o_ee_vtp_upload_rd_en,
    input   wire    [255:0]     iv_ee_vtp_upload_data,

    output  wire                o_ee_vtp_download_wr_en,
    input   wire                i_ee_vtp_download_prog_full,
    output  wire    [255:0]     ov_ee_vtp_download_data,

//Interface with DMA Engine
    //Channel 1 DMA Read  MPT Ctx Request
    output  wire                           dma_v2p_mpt_rd_req_valid,
    output  wire                           dma_v2p_mpt_rd_req_last ,
    output  wire [(`DT_WIDTH-1):0]         dma_v2p_mpt_rd_req_data ,
    output  wire [(`HD_WIDTH-1):0]         dma_v2p_mpt_rd_req_head ,
    input   wire                           dma_v2p_mpt_rd_req_ready,
    //Channel 1 DMA Read  MPT Ctx Response 
    output  wire                           dma_v2p_mpt_rd_rsp_tready,
    input   wire                           dma_v2p_mpt_rd_rsp_tvalid,
    input   wire [`DT_WIDTH-1:0]           dma_v2p_mpt_rd_rsp_tdata,
    input   wire                           dma_v2p_mpt_rd_rsp_tlast,
    input   wire [`HD_WIDTH-1:0]           dma_v2p_mpt_rd_rsp_theader,
    //Channel 1 DMA Write MPT CTX
    output  wire                           dma_v2p_mpt_wr_req_valid,
    output  wire                           dma_v2p_mpt_wr_req_last ,
    output  wire [(`DT_WIDTH-1):0]         dma_v2p_mpt_wr_req_data ,
    output  wire [(`HD_WIDTH-1):0]         dma_v2p_mpt_wr_req_head ,
    input   wire                           dma_v2p_mpt_wr_req_ready,

    //Channel 2 DMA Read  MTT Ctx Request
    output  wire                           dma_v2p_mtt_rd_req_valid,
    output  wire                           dma_v2p_mtt_rd_req_last ,
    output  wire [(`DT_WIDTH-1):0]         dma_v2p_mtt_rd_req_data ,
    output  wire [(`HD_WIDTH-1):0]         dma_v2p_mtt_rd_req_head ,
    input   wire                           dma_v2p_mtt_rd_req_ready,
    //Channel 2 DMA Read  MTT Ctx Response 
    output  wire                           dma_v2p_mtt_rd_rsp_tready,
    input   wire                           dma_v2p_mtt_rd_rsp_tvalid,
    input   wire [`DT_WIDTH-1:0]           dma_v2p_mtt_rd_rsp_tdata,
    input   wire                           dma_v2p_mtt_rd_rsp_tlast,
    input   wire [`HD_WIDTH-1:0]           dma_v2p_mtt_rd_rsp_theader,
    //Channel 2 DMA Write MTT CTX    
    output  wire                           dma_v2p_mtt_wr_req_valid,
    output  wire                           dma_v2p_mtt_wr_req_last ,
    output  wire [(`DT_WIDTH-1):0]         dma_v2p_mtt_wr_req_data ,
    output  wire [(`HD_WIDTH-1):0]         dma_v2p_mtt_wr_req_head ,
    input   wire                           dma_v2p_mtt_wr_req_ready,

    //Channel 3 DMA Read  Data(WQE/Network Data) Request 
    output  wire                           dma_v2p_dt_rd_req_valid,
    output  wire                           dma_v2p_dt_rd_req_last ,
    output  wire [(`DT_WIDTH-1):0]         dma_v2p_dt_rd_req_data ,
    output  wire [(`HD_WIDTH-1):0]         dma_v2p_dt_rd_req_head ,
    input   wire                           dma_v2p_dt_rd_req_ready,
    //Channel 3 DMA Read  Data(WQE/Network Data) Response
    output  wire                           dma_v2p_dt_rd_rsp_tready,
    input   wire                           dma_v2p_dt_rd_rsp_tvalid,
    input   wire [`DT_WIDTH-1:0]           dma_v2p_dt_rd_rsp_tdata,
    input   wire                           dma_v2p_dt_rd_rsp_tlast,
    input   wire [`HD_WIDTH-1:0]           dma_v2p_dt_rd_rsp_theader,
    //Channel 3 DMA Write Data(CQE/Network Data)   
    output  wire                           dma_v2p_dt_wr_req_valid,
    output  wire                           dma_v2p_dt_wr_req_last ,
    output  wire [(`DT_WIDTH-1):0]         dma_v2p_dt_wr_req_data ,
    output  wire [(`HD_WIDTH-1):0]         dma_v2p_dt_wr_req_head ,
    input   wire                           dma_v2p_dt_wr_req_ready,

    //Channel 4 DMA Read  Data(RQ WQE for RDMA engine rwm) Request 
    output  wire                           dma_v2p_wqe_rd_req_valid,
    output  wire                           dma_v2p_wqe_rd_req_last ,
    output  wire [(`DT_WIDTH-1):0]         dma_v2p_wqe_rd_req_data ,
    output  wire [(`HD_WIDTH-1):0]         dma_v2p_wqe_rd_req_head ,
    input   wire                           dma_v2p_wqe_rd_req_ready,
    //Channel 4 DMA Read  Data(RQ WQE for RDMA engine rwm) Response
    output  wire                           dma_v2p_wqe_rd_rsp_tready,
    input   wire                           dma_v2p_wqe_rd_rsp_tvalid,
    input   wire [`DT_WIDTH-1:0]           dma_v2p_wqe_rd_rsp_tdata,
    input   wire                           dma_v2p_wqe_rd_rsp_tlast,
    input   wire [`HD_WIDTH-1:0]           dma_v2p_wqe_rd_rsp_theader

    /*Interface with APB Slave*/
	`ifdef V2P_DUG
    // , input 	wire		[`VTP_RW_REG_NUM * 32 - 1 : 0] 		Rw_data
	// , output 	wire 		[`VTP_RO_REG_NUM * 32 - 1 : 0] 		Ro_data
        ,output 	wire 	[32 - 1 : 0]	ro_data
	    ,output wire 	[(`VTP_DBG_RW_NUM) * 32 - 1 : 0]	init_rw_data  //
	    ,input 	wire 	[(`VTP_DBG_RW_NUM) * 32 - 1 : 0]	rw_data  // total 18 ram
    	,input 	  wire 		[31 : 0]		  Dbg_sel
	    ,output 	wire 		[31 : 0]		  Dbg_bus
//	 , output 	wire 		[(`VTP_DBG_REG_NUM) * 32 - 1 : 0]		Dbg_bus
    `endif
);

reg	 											global_mem_init_finish;
reg	 											init_wea;
reg	 	[`V2P_MEM_MAX_ADDR_WIDTH - 1 : 0]		init_addra;
reg	 	[`V2P_MEM_MAX_DIN_WIDTH - 1 : 0]		init_dina;
reg 	[`V2P_MEM_MAX_ADDR_WIDTH : 0]		init_counter;

assign v2p_init_finish = global_mem_init_finish;

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

/*********************Add for APB-slave**************************/
`ifdef V2P_DUG
assign ro_data = 'd0;
    // wire 		[`VTP_RW_REG_NUM * 32 - 1 :0]		wv_reg_config_enble;
    // reg 		[`VTP_RW_REG_NUM * 32 - 1 :0]		rw_reg;
    // assign 		wv_reg_config_enble = Rw_data[`VTP_RW_REG_NUM * 32 - 1 : 0];

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

  wire [`CEUPAR_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_ceupar;
  wire [`V2P_RDCTX_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_rdctx;
  wire [`RDDT_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_rddt;
  wire [`RDWQE_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_rdwqe;
  wire [`V2P_WRCTX_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_wrctx;
  wire [`WRDT_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_wrdt;
  wire [`MPTCTL_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mptctl;
  wire [`MPT_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mpt;
  wire [`MPTRD_DT_PAR_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mpt_rd_data_par;
  wire [`MPTRD_WQE_PAR_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mpt_rd_wqe_par;
  wire [`MPTWR_PAR_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mptwr_par;
  wire [`MTTCTL_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mttctl;
  wire [`MTT_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mtt;
  wire [`MTTREQ_CTL_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mttreq_ctl;
  wire [`REQSCH_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_reqsch;
  wire [`CHCTL_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_chctl;
  wire [(`TPTM_DBG_REG_NUM) * 32 - 1 : 0]   wv_dbg_bus_tptm;

  wire [(`VTP_DBG_REG_NUM) * 32 - 1 : 0]		wv_dbg_bus;
//tptmdata intra signals
// wire [`CEUTPTM_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_ceutptm;
// wire [`MPTM_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mptm;
// wire [`MTTM_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mttm;

    // wire [`CEUPAR_RO_REG_NUM * 32 - 1 : 0]   wv_ro_data_ceupar;
    // wire [`CEUTPTM_RO_REG_NUM * 32 - 1 : 0]   wv_ro_data_ceutptm;
    // wire [`RDCTX_RO_REG_NUM * 32 - 1 : 0]   wv_ro_data_rdctx;
    // wire [`RDDT_RO_REG_NUM * 32 - 1 : 0]   wv_ro_data_rddt;
    // wire [`WRCTX_RO_REG_NUM * 32 - 1 : 0]   wv_ro_data_wrctx;
    // wire [`WRDT_RO_REG_NUM * 32 - 1 : 0]   wv_ro_data_wrdt;
    // wire [`MPTCTL_RO_REG_NUM * 32 - 1 : 0]   wv_ro_data_mptctl;
    // wire [`MPT_RO_REG_NUM * 32 - 1 : 0]   wv_ro_data_mpt;
    // wire [`MPTRD_PAR_RO_REG_NUM * 32 - 1 : 0]   wv_ro_data_mptrd_par;
    // wire [`MPTWR_PAR_RO_REG_NUM * 32 - 1 : 0]   wv_ro_data_mptwr_par;
    // wire [`MPTM_RO_REG_NUM * 32 - 1 : 0]   wv_ro_data_mptm;
    // wire [`MTTCTL_RO_REG_NUM * 32 - 1 : 0]   wv_ro_data_mttctl;
    // wire [`MTT_RO_REG_NUM * 32 - 1 : 0]   wv_ro_data_mtt;
    // wire [`MTTREQ_CTL_RO_REG_NUM * 32 - 1 : 0]   wv_ro_data_mttreq_ctl;
    // wire [`MTTM_RO_REG_NUM * 32 - 1 : 0]   wv_ro_data_mttm;
    // wire [`REQSCH_RO_REG_NUM * 32 - 1 : 0]   wv_ro_data_reqsch;
    // wire [`CHCTL_RO_REG_NUM * 32 - 1 : 0]   wv_ro_data_chctl;
    // wire [`TPTM_RO_REG_NUM * 32 - 1 : 0]   wv_ro_data_tptm;

    // assign Ro_data = {
    //     wv_ro_data_ceupar,
    //     wv_ro_data_rdctx,
    //     wv_ro_data_rddt,
    //     wv_ro_data_wrctx,
    //     wv_ro_data_wrdt,
    //     wv_ro_data_mptctl,
    //     wv_ro_data_mpt,
    //     wv_ro_data_mptrd_par,
    //     wv_ro_data_mptwr_par,
    //     wv_ro_data_mttctl,
    //     wv_ro_data_mtt,
    //     wv_ro_data_mttreq_ctl,
    //     wv_ro_data_reqsch,
    //     wv_ro_data_chctl,
    //     wv_ro_data_tptm};

    assign wv_dbg_bus= {
        wv_dbg_bus_ceupar,
        wv_dbg_bus_rdctx,
        wv_dbg_bus_rddt,
        wv_dbg_bus_rdwqe,
        wv_dbg_bus_wrctx,
        wv_dbg_bus_wrdt,
        wv_dbg_bus_mptctl,
        wv_dbg_bus_mpt,
        wv_dbg_bus_mpt_rd_data_par,
        wv_dbg_bus_mpt_rd_wqe_par,
        wv_dbg_bus_mptwr_par,
        wv_dbg_bus_mttctl,
        wv_dbg_bus_mtt,
        wv_dbg_bus_mttreq_ctl,
        wv_dbg_bus_reqsch,
        wv_dbg_bus_chctl,
        wv_dbg_bus_tptm};

   	assign Dbg_bus = wv_dbg_bus >> (Dbg_sel << 5);
    //assign Dbg_bus = wv_dbg_bus;
    assign init_rw_data = 'b0;

`endif


/*****************Add for APB-slave*******************/

//-----------------{variables decleration} begin---------------------------
  //------------------cue_parser_v2p-----------------------------------
    //internal cue_parser_v2p -- MPT request header
    //128 width header format
    wire                    mpt_req_rd_en;// to mpt_ram__ctl
    wire  [`HD_WIDTH-1:0]   mpt_req_dout ; // to mpt_ram__ctl
    wire                    mpt_req_empty;// to req_scheduler
    
    //internal cue_parser_v2p -- MPT payload data
    //256 width 
    wire                    mpt_data_rd_en;// to mpt_ram__ctl
    wire  [`DT_WIDTH-1:0]   mpt_data_dout ;// to mpt_ram__ctl
    wire                    mpt_data_empty;// to req_scheduler
    
    // internal cue_parser_v2p --  MTT request header
    //128 width header format
    wire                    mtt_req_rd_en;// to mtt_ram__ctl
    wire  [`HD_WIDTH-1:0]   mtt_req_dout;// to mtt_ram__ctl
    wire                    mtt_req_empty;// to mtt_ram__ctl
    
    // internal cue_parser_v2p -- MTT payload data
    //256 width 
    wire                    mtt_data_rd_en;// to mtt_ram__ctl
    wire  [`DT_WIDTH-1:0]   mtt_data_dout;// to mtt_ram__ctl
    wire                    mtt_data_empty;// to mtt_ram__ctl

    // internal cue_parser_v2p -- TPTMeteData write request header
    //128 width header format
    wire                    mdata_req_rd_en;// to tptmdata
    wire  [`HD_WIDTH-1:0]   mdata_req_dout ;// to tptmdata
    wire                    mdata_req_empty;// to tptmdata

    // internel cue_parser_v2p -- TPT metaddata for TPTmetaData Module
    // 256 width (only TPT meatadata)
    wire                    mdata_rd_en;/// to tptmdata
    wire  [`DT_WIDTH-1:0]   mdata_dout ;/// to tptmdata
    wire                    mdata_empty;// to  tptmdata
  
  //-------------------------req_scheduler------------------------
    // internal req_scheduler -- mpt_ram_ctl 
    wire [PEND_CNT_WIDTH-1 :0]  pend_channel_cnt;//req_scheduler read Pending Channel Count Reg to make decision choose which req channel 
    
    // internal req_scheduler -- selected_channel_ctl
    //req_scheduler changes the value of Selected Channel Reg to mark the selected channel, MPT/MTT module may read the info
    wire  [CHANNEL_WIDTH-1 :0]  new_selected_channel;
    //req_scheduler read the value of Selected Channel Reg to make decision
    wire  [CHANNEL_WIDTH-1 :0]   old_selected_channel;
    wire [2:0] lookup_ram_cnt;
  //----------------------selected_channel_ctl-----------------------
    //internal mpt_ram_ctl -- selected_channel_ctl
    wire    req_read_already;//MPT module set this signal, after MPT module read req from req_fifo
    wire    mpt_rsp_stall;
  //-----------------------tptmdata-----------------------------------
    //internal mpt_ram -- tptmdata request interface
    wire                        mpt_req_mdata_rd_en;
    wire  [TPT_HD_WIDTH-1:0]    mpt_req_mdata_dout ;
    wire                        mpt_req_mdata_empty;
    
    //internal mtt_ram -- tptmdata request interface
    wire                        mtt_req_mdata_rd_en;
    wire  [TPT_HD_WIDTH-1:0]    mtt_req_mdata_dout ;
    wire                        mtt_req_mdata_empty;

    //MTT get mtt_base for compute index in mtt_ram
    wire  [63:0]                mtt_base_addr;

    //MPT get mpt_base for compute index in mpt_ram
    wire  [63:0]                mpt_base_addr;

    //internal tptmdata -- dma_read_ctx  Request header interface
    wire                           dma_rd_mpt_req_rd_en;
    wire  [DMA_RD_HD_WIDTH-1:0]    dma_rd_mpt_req_dout;
    wire                           dma_rd_mpt_req_empty;

    wire                           dma_rd_mtt_req_rd_en;
    wire  [DMA_RD_HD_WIDTH-1:0]    dma_rd_mtt_req_dout;
    wire                           dma_rd_mtt_req_empty;

    //internal tptmdata -- dma_write_ctx Request header interface
    wire                           dma_wr_mpt_req_rd_en;
    wire  [DMA_WR_HD_WIDTH-1:0]    dma_wr_mpt_req_dout;
    wire                           dma_wr_mpt_req_empty;
    wire                           dma_wr_mtt_req_rd_en;
    wire  [DMA_WR_HD_WIDTH-1:0]    dma_wr_mtt_req_dout;
    wire                           dma_wr_mtt_req_empty;
  //-----------------------mpt_ram_ctl-------------------------------
    //------------------interface to dma_read_ctx module-------------
       //read dma req header metadata from backup fifo
        wire                            dma_rd_mpt_bkup_rd_en;
        wire  [DMA_RD_BKUP_WIDTH-1:0]   dma_rd_mpt_bkup_dout;
        wire                            dma_rd_mpt_bkup_empty;

    //---------------------------mpt_ram--------------------------
        //lookup info and response state
        wire                     mpt_lookup_allow_in;
        wire                     mpt_lookup_rden;
        wire                     mpt_lookup_wren;
        wire [MPT_LINE_SIZE*8-1:0]   mpt_lookup_wdata;
        //lookup info addr={(32-INDEX-TAG)'b0,lookup_tag,lookup_index}
        wire [MPT_INDEX -1     :0]   mpt_lookup_index;
        wire [MPT_TAG -1       :0]   mpt_lookup_tag;
        wire [2:0]               mpt_lookup_state;// | 3<->miss | 2<->hit | 0<->idle |
        wire                     mpt_lookup_ldst ;// 1 for store, and 0 for load
        wire                     mpt_state_valid ;// valid in normal state, invalid if stall
        wire                     mpt_lookup_stall;
        // add EQ function
        wire                         mpt_eq_addr;
        //lookup info state fifo
        wire                     mpt_state_rd_en;
        wire                     mpt_state_empty;
        wire [4:0]               mpt_state_dout ;
        //hit mpt entry in fifo, for mpt info match and mtt lookup
        wire                     mpt_hit_data_rd_en;
        wire                     mpt_hit_data_empty;         
        wire [MPT_LINE_SIZE*8-1:0]   mpt_hit_data_dout;
        //miss read addr in fifo, for pending fifo addr to refill
        wire                     mpt_miss_addr_rd_en;
        wire  [31:0]             mpt_miss_addr_dout;
        wire                     mpt_miss_addr_empty;

    //----------------interface to MTT module-------------------------
        // //write MTT read request(include Src,Op,mtt_index,v-addr,length) to MTT module        
        // //| ---------------------165 bit------------------------- |
        // //|   Src    |     Op  | mtt_index | address |Byte length |
        // //|  164:162 | 161:160 |  159:96   |  95:32  |   31:0     |
        // wire                     mpt_req_mtt_rd_en;
        // wire  [164:0]            mpt_req_mtt_dout;
        // wire                     mpt_req_mtt_empty;
        //write read request(include Src,mtt_index,v-addr,length) to mtt_ram_ctl module        
        //|--------------163 bit------------------------- |
        //|    Src  | mtt_index | address |Byte length |
        //| 162:160 |  159:96   |  95:32  |   31:0     |
        wire                     mpt_rd_req_mtt_rd_en;
        wire  [162:0]            mpt_rd_req_mtt_dout;
        wire                     mpt_rd_req_mtt_empty;
    
        //write read wqe request(include Src,mtt_index,v-addr,length) to mtt_ram_ctl module        
        //|--------------163 bit------------------------- |
        //|    Src  | mtt_index | address |Byte length |
        //| 162:160 |  159:96   |  95:32  |   31:0     |
        wire                     mpt_rd_wqe_req_mtt_rd_en;
        wire  [162:0]            mpt_rd_wqe_req_mtt_dout;
        wire                     mpt_rd_wqe_req_mtt_empty;

        //write read request(include Src,mtt_index,v-addr,length) to mtt_ram_ctl module        
        //|--------------163 bit------------------------- |
        //|    Src  | mtt_index | address |Byte length |
        //| 162:160 |  159:96   |  95:32  |   31:0     |
        wire                     mpt_wr_req_mtt_rd_en;
        wire  [162:0]            mpt_wr_req_mtt_dout;
        wire                     mpt_wr_req_mtt_empty;

  //-----------------------mpt_ram-----------------------------------  
    //write MPT Ctx payload to dma_write_ctx module
    wire                         dma_wr_mpt_rd_en;
    wire  [`DT_WIDTH-1:0]        dma_wr_mpt_dout ;// write back replace data
    wire                         dma_wr_mpt_empty;
  //--------------------mpt_rd_req_parser-------------------------
      //---------------------------mtt_ram_ctl--------------------------
        //mtt_ram look up request at cacheline level for dma read data requests
        //|--------------198 bit------------------------- |
        //|    Src  |  total length |    Op  | mtt_index | address | tmp length |
        //| 197:195 |    194:163    |162:160 |  159:96   |  95:32  |   31:0     |
        wire             mpt_rd_req_mtt_cl_rd_en;
        wire             mpt_rd_req_mtt_cl_empty;
        wire  [197:0]    mpt_rd_req_mtt_cl_dout;

  //--------------------mpt_rd_wqe_req_parser-------------------------
      //---------------------------mtt_ram_ctl--------------------------
        //mtt_ram look up request at cacheline level for dma read wqe requests
        //|--------------198 bit------------------------- |
        //|    Src  |  total length |    Op  | mtt_index | address | tmp length |
        //| 197:195 |    194:163    |162:160 |  159:96   |  95:32  |   31:0     |
        wire             mpt_rd_wqe_req_mtt_cl_rd_en;
        wire             mpt_rd_wqe_req_mtt_cl_empty;
        wire  [197:0]    mpt_rd_wqe_req_mtt_cl_dout;

  //--------------------mpt_wr_req_parser-------------------------
      //---------------------------mtt_ram_ctl--------------------------
        //mtt_ram look up request at cacheline level for dma read data requests
        //|--------------198 bit------------------------- |
        //|    Src  |  total length |    Op  | mtt_index | address | tmp length |
        //| 197:195 |    194:163    |162:160 |  159:96   |  95:32  |   31:0     |
        wire             mpt_wr_req_mtt_cl_rd_en;
        wire             mpt_wr_req_mtt_cl_empty;
        wire  [197:0]    mpt_wr_req_mtt_cl_dout;
  //--------------------mtt_req_scheduler-------------------------
        wire  [3:0]  new_selected_mtt_channel;
        //mtt_ram_ctl block signal for 3 req fifo processing block 
        //| bit 2 read WQE | bit 1 write data | bit 0 read data |
        wire  [2:0]   block_valid;
        wire  [197:0] rd_wqe_block_info;
        wire  [197:0] wr_data_block_info;
        wire  [197:0] rd_data_block_info;
        //mtt_ram_ctl unblock signal for reading 3 blocked req  
        //| bit 2 read WQE | bit 1 write data | bit 0 read data |
        wire  [2:0]   unblock_valid;
        wire  [197:0] rd_wqe_block_reg;
        wire  [197:0] wr_data_block_reg;
        wire  [197:0] rd_data_block_reg;
        wire dma_rd_dt_req_prog_full;
        wire dma_rd_wqe_req_prog_full;
        wire dma_wr_dt_req_prog_full;

  //-----------------------mtt_ram_ctl------------------------------
    //---------------------------mtt_ram--------------------------
        //lookup info 
        //lookup info addr={(64-INDEX-TAG-OFFSET)'b0,lookup_tag,lookup_index,lookup_offset}
        wire                     mtt_lookup_allow_in;
        wire                     mtt_lookup_rden;
        wire                     mtt_lookup_wren;
        wire [MTT_LINE_SIZE*8-1:0]   mtt_lookup_wdata;
        wire [MTT_INDEX -1     :0]   mtt_lookup_index;
        wire [MTT_TAG -1       :0]   mtt_lookup_tag;
        wire [MTT_OFFSET - 1   :0]   mtt_lookup_offset;
        wire [MTT_NUM - 1      :0]   mtt_lookup_num;
        wire                         mtt_eq_addr;
        //response state
        wire [2:0]               mtt_lookup_state;// | 3<->miss | 2<->hit | 0<->idle |
        wire                     mtt_lookup_ldst ;// 1 for store, and 0 for load
        wire                     mtt_state_valid ;// valid in normal state, invalid if stall
        wire                     mtt_lookup_stall;

        //hit read mtt entry 
        wire [MTT_LINE_SIZE*8-1:0]   mtt_hit_rdata;
        //miss read mtt entry, it's the dma reaponse data
        wire [MTT_LINE_SIZE*8-1:0]   mtt_miss_rdata;

    //------------------interface to dma_read_data module-------------
        //-mtt_ram_ctl--dma_read/write_data req header format
        //high-----------------------------low
        //|-------------------134 bit--------------------|
        //| total len |opcode | dest/src |tmp len | addr |
        //| 32        |   3   |     3    | 32     |  64  |
        //|----------------------------------------------|
        wire                            dma_rd_dt_req_rd_en;
        wire                            dma_rd_dt_req_empty;
        wire  [DMA_DT_REQ_WIDTH-1:0]    dma_rd_dt_req_dout;

        wire                            dma_rd_wqe_req_rd_en;
        wire                            dma_rd_wqe_req_empty;
        wire  [DMA_DT_REQ_WIDTH-1:0]    dma_rd_wqe_req_dout;

        wire                            dma_wr_dt_req_rd_en;
        wire                            dma_wr_dt_req_empty;
        wire  [DMA_DT_REQ_WIDTH-1:0]    dma_wr_dt_req_dout;

  //-----------------------mtt_ram----------------------------------
    //write mtt Ctx payload to dma_write_ctx module
        wire                          dma_wr_mtt_rd_en;
        wire  [`DT_WIDTH-1:0]         dma_wr_mtt_dout ;// write back replace data
        wire                          dma_wr_mtt_empty;

  //-----------------------dam_read_ctx-----------------------------  
    // variables in this module has been decleared in othter modules
  //-----------------------dam_write_ctx----------------------------
    // variables in this module has been decleared in othter modules
  //-----------------------dam_read_data----------------------------
    // variables in this module has been decleared in othter modules
  //-----------------------dam_write_data----------------------------
    // variables in this module has been decleared in othter modules
//-----------------{variables decleration} end---------------------------

//-----------------{sub-module instantiation} begin---------------------
ceu_parser_v2p u_ceu_parser_v2p (
    .clk (clk),          // i, 1
    .rst (rst),          // i, 1
    // externel Parse msg requests header from CEU 
    .ceu_req_tvalid  (ceu_req_tvalid),  //i, 1
    .ceu_req_tready  (ceu_req_tready),  //o, 1
    .ceu_req_tdata   (ceu_req_tdata ),  //i, [`DT_WIDTH-1:0]
    .ceu_req_tlast   (ceu_req_tlast ),  //i, 1               
    .ceu_req_theader (ceu_req_theader),  //i, [`HD_WIDTH-1:0]

    // internal MPT request header
    //128 width header format
    .mpt_req_rd_en  (mpt_req_rd_en), //i,1                
    .mpt_req_dout   (mpt_req_dout), //o, [`HD_WIDTH-1:0]
    .mpt_req_empty  (mpt_req_empty), //o,1                
    
    // internal MPT payload data
    //256 width 
    .mpt_data_rd_en (mpt_data_rd_en), //i,1
    .mpt_data_dout ( mpt_data_dout),  //o,[`DT_WIDTH-1:0]
    .mpt_data_empty (mpt_data_empty), //o,1               
    
    // internal MTT request header
    //128 width header format
    .mtt_req_rd_en (mtt_req_rd_en), //i,1                
    .mtt_req_dout  (mtt_req_dout ),//o, [`HD_WIDTH-1:0]
    .mtt_req_empty (mtt_req_empty), //o,1                
    
    // internal MTT payload data
    //256 width 
    .mtt_data_rd_en (mtt_data_rd_en), //i, 1
    .mtt_data_dout  (mtt_data_dout ), //o, [`DT_WIDTH-1:0]
    .mtt_data_empty (mtt_data_empty), //o, 1               

    // internal TPTMeteData write request header
    //128 width header format
    .mdata_req_rd_en (mdata_req_rd_en), //i,1                
    .mdata_req_dout  (mdata_req_dout ),//o, [`HD_WIDTH-1:0]
    .mdata_req_empty (mdata_req_empty), //o,1                

    // internel TPT metaddata for TPTmetaData Module
    // 256 width (only TPT meatadata)
    .mdata_rd_en (mdata_rd_en),  //i, 1
    .mdata_dout  (mdata_dout ),  //o, [`DT_WIDTH-1:0]
    .mdata_empty (mdata_empty)  //o, 1     

    `ifdef V2P_DUG
    //apb_slave
    , .rw_data(rw_data[`CEUPAR_DBG_RW_NUM * 32 - 1 : 0])
    , .wv_dbg_bus_ceupar(wv_dbg_bus_ceupar)
    `endif 
);

req_scheduler #(
    .CHANNEL_WIDTH  (CHANNEL_WIDTH ), 
    .PEND_CNT_WIDTH (PEND_CNT_WIDTH)
    ) u_req_scheduler(
    .clk (clk),
    .rst (rst),
    //these signals from rd_req_empty singal of CEU, and other 7 reqs from RDMA Engine submodule, used to selected channel for mpt_ram_ctl
    .rd_ceu_req_empty    (mpt_req_empty         ), // i,1
    .rd_dbp_req_empty    (i_db_vtp_cmd_empty    ), // i,1
    .rd_wp_wqe_req_empty (i_wp_vtp_wqe_cmd_empty), // i,1
    .rd_wp_dt_req_empty  (i_wp_vtp_nd_cmd_empty ), // i,1
    .rd_rtc_req_empty    (i_rtc_vtp_cmd_empty   ), // i,1
    .rd_rrc_req_empty    (i_rrc_vtp_cmd_empty   ), // i,1
    .rd_rqwqe_req_empty  (i_rwm_vtp_cmd_empty   ), // i,1
    .rd_ee_req_empty     (i_ee_vtp_cmd_empty    ), // i,1
    /*VCS Verification*/
    .state_rd_en (mpt_state_rd_en), //i,1
    // .state_empty(mpt_state_empty), //i,1
    /*Action = Add*/
    // //MPT module set this signal, after MPT module read req from req_fifo
    // .req_read_already (req_read_already), // i,1
    //req_scheduler read Pending Channel Count Reg to make decision choose which req channel 
    .pend_channel_cnt (pend_channel_cnt),//i,[PEND_CNT_WIDTH-1 :0] 
    //req_scheduler changes the value of Selected Channel Reg to mark the selected channel, MPT/MTT module may read the info
    .new_selected_channel (new_selected_channel),//o, [CHANNEL_WIDTH-1 :0] 
    //req_scheduler read the value of Selected Channel Reg to make decision
    .old_selected_channel (old_selected_channel),//i, [CHANNEL_WIDTH-1 :0] 
    .mpt_rsp_stall (mpt_rsp_stall),
    .lookup_ram_cnt (lookup_ram_cnt)

    //apb_slave
    `ifdef V2P_DUG
    , .wv_dbg_bus_reqsch(wv_dbg_bus_reqsch)
    `endif 
);

selected_channel_ctl #(
    .CHANNEL_WIDTH (CHANNEL_WIDTH)
    ) u_selected_channel_ctl(
    .clk (clk),
    .rst (rst),

    //req_scheduler changes the value of Selected Channel Reg to mark the selected channel, MPT/MTT module may read the info
    .new_selected_channel (new_selected_channel), //i,[CHANNEL_WIDTH-1 :0]  
    
    //MPT module set this signal, after MPT module read req from req_fifo
    .req_read_already (req_read_already), // i,1

    //req_scheduler read the value of Selected Channel Reg to make decision
    //MPT read the selected_channel and read the req_fifo of different channels
    .old_selected_channel (old_selected_channel) //o,[CHANNEL_WIDTH-1 :0]  
    //apb_slave
    `ifdef V2P_DUG
    , .wv_dbg_bus_chctl(wv_dbg_bus_chctl)
    `endif 

);

tptmdata#(
    .TPT_HD_WIDTH    (TPT_HD_WIDTH   ) ,//for MPT/MTT-Mdata req header fifo
    .DMA_RD_HD_WIDTH (DMA_RD_HD_WIDTH) ,//for Mdata-DMA Read req header fifo
    .DMA_WR_HD_WIDTH (DMA_WR_HD_WIDTH) ,//for Mdata-DMA Write req header fifo
    .CEU_HD_WIDTH    (CEU_HD_WIDTH   ) ,//for ceu_tptm_proc to MPTMdata/MTTMdata req header fifo
    .MPTM_RAM_DWIDTH (MPTM_RAM_DWIDTH) ,//mptmdata RAM data width
    .MPTM_RAM_AWIDTH (MPTM_RAM_AWIDTH) ,//mptmdata RAM addr width
    .MPTM_RAM_DEPTH  (MPTM_RAM_DEPTH ) , //mptmdata RAM depth
    .MTTM_RAM_DWIDTH (MTTM_RAM_DWIDTH) ,//mttmdata RAM data width
    .MTTM_RAM_AWIDTH (MTTM_RAM_AWIDTH) ,//mttmdata RAM addr width
    .MTTM_RAM_DEPTH  (MTTM_RAM_DEPTH )  //mttmdata RAM depth
    ) u_tptmdata(
    .clk (clk),
    .rst (rst),

	.global_mem_init_finish(global_mem_init_finish),
	.init_wea(init_wea),
	.init_addra(init_addra),
	.init_dina(init_dina),

    // internal TPTMeteData write request header from CEU 
    //128 width header format
    .ceu_req_dout  (mdata_req_dout ), //i,[`HD_WIDTH-1:0]
    .ceu_req_empty (mdata_req_empty), //i,1               
    .ceu_req_rd_en (mdata_req_rd_en), //o,1        
                    
    // internel TPT metaddata from CEU 
    // 256 width (only TPT meatadata)
    .mdata_rd_en (mdata_rd_en),//o,1                  
    .mdata_dout  (mdata_dout ),//i,[`DT_WIDTH-1:0]   
    .mdata_empty (mdata_empty),//i, 1                 
    
    //MPT Request interface
    .mpt_req_rd_en (mpt_req_mdata_rd_en),//o,1                      
    .mpt_req_dout  (mpt_req_mdata_dout ),//i,[TPT_HD_WIDTH-1:0]    
    .mpt_req_empty (mpt_req_mdata_empty),//i, 1                     
    
    //MTT Request interface
    .mtt_req_rd_en (mtt_req_mdata_rd_en),// o, 1                     
    .mtt_req_dout  (mtt_req_mdata_dout ),// i,[TPT_HD_WIDTH-1:0]    
    .mtt_req_empty (mtt_req_mdata_empty),// i,  1           

    //MTT get mtt_base for compute index in mtt_ram
    .mtt_base_addr (mtt_base_addr), //o, 64

    //MPT get mpt_base for compute index in mpt_ram
    .mpt_base_addr (mpt_base_addr), //o, 64
    
    //DMA Read Ctx Request interface
    .dma_rd_mpt_req_rd_en (dma_rd_mpt_req_rd_en),//i,1                         
    .dma_rd_mpt_req_dout  (dma_rd_mpt_req_dout ),//o,[DMA_RD_HD_WIDTH-1:0]    
    .dma_rd_mpt_req_empty (dma_rd_mpt_req_empty),//o,1                         
    .dma_rd_mtt_req_rd_en (dma_rd_mtt_req_rd_en),//i, 1                        
    .dma_rd_mtt_req_dout  (dma_rd_mtt_req_dout ),//o,[DMA_RD_HD_WIDTH-1:0]    
    .dma_rd_mtt_req_empty (dma_rd_mtt_req_empty),//o,  1                       

    //DMA Write Ctx Request interface
    .dma_wr_mpt_req_rd_en (dma_wr_mpt_req_rd_en),//i,1                          
    .dma_wr_mpt_req_dout  (dma_wr_mpt_req_dout ),//o, [DMA_WR_HD_WIDTH-1:0]    
    .dma_wr_mpt_req_empty (dma_wr_mpt_req_empty),//o,1                          
    .dma_wr_mtt_req_rd_en (dma_wr_mtt_req_rd_en),//i,1                          
    .dma_wr_mtt_req_dout  (dma_wr_mtt_req_dout ),//o, [DMA_WR_HD_WIDTH-1:0]    
    .dma_wr_mtt_req_empty (dma_wr_mtt_req_empty)//o, 1           
    //apb_slave
    `ifdef V2P_DUG
    , .rw_data(rw_data[(`CEUPAR_DBG_RW_NUM) *32 +: (`TPTM_DBG_RW_NUM) * 32])
    , .wv_dbg_bus_tptm(wv_dbg_bus_tptm)       
    `endif                  
);

mpt_ram_ctl#(
    .MPT_SIZE          (MPT_SIZE         ), //Total Size(MPT+MTT) 1MB, MPT_RAM occupies 512KB
    .CACHE_WAY_NUM     (MPT_CACHE_WAY_NUM    ),//2 way
    .LINE_SIZE         (MPT_LINE_SIZE        ),//Cache line size = 64B(MPT entry= 64B)
    .INDEX             (MPT_INDEX            ),//mpt_ram index width
    .TAG               (MPT_TAG              ),//mpt_ram tag width
    .DMA_RD_BKUP_WIDTH (DMA_RD_BKUP_WIDTH),//for Mdata-TPT Read req header fifo
    .PEND_CNT_WIDTH    (PEND_CNT_WIDTH   ),
    .CHANNEL_WIDTH     (CHANNEL_WIDTH    )
    ) u_mpt_ram_ctl (
    .clk (clk),
    .rst (rst),
    //------------------interface to selected_channel_ctl module--------
        .req_read_already (req_read_already),//o,1                      
        .selected_channel (old_selected_channel),//i,[CHANNEL_WIDTH-1 :0]  
    
    //------------------interface to request scheduler module
        .qv_pend_channel_cnt (pend_channel_cnt),//o,[PEND_CNT_WIDTH-1 :0] 
    
    //------------------interface to ceu channel----------------------
        // internal ceu request header
        // 128 width header format
        .mpt_req_rd_en (mpt_req_rd_en),//o,                  
        .mpt_req_dout  (mpt_req_dout ),//i,[`HD_WIDTH-1:0]   
        //.mpt_req_empty (mpt_req_empty),//i,                  
    
        // internal ceu payload data
        // 256 width 
        .mpt_data_rd_en (mpt_data_rd_en),//o,                  
        .mpt_data_dout  (mpt_data_dout ),//i,[`DT_WIDTH-1:0]   
        .mpt_data_empty (mpt_data_empty),//i,                  

    //------------------interface to rdma engine channel--------------
        //read  Doorbell Processing(WQE) req_fifo
        //.i_db_vtp_cmd_empty (i_db_vtp_cmd_empty),//i,            
        .o_db_vtp_cmd_rd_en (o_db_vtp_cmd_rd_en),//o,            
        .iv_db_vtp_cmd_data (iv_db_vtp_cmd_data),//i,[255:0]     
        //write Doorbell Processing(WQE) state_fifo
        .i_db_vtp_resp_prog_full  (i_db_vtp_resp_prog_full),     //i,            
        .o_db_vtp_resp_wr_en      (o_db_vtp_resp_wr_en    ),     //o,            
        .ov_db_vtp_resp_data      (ov_db_vtp_resp_data    ),     //o,[7:0]       

        //read  WQE Parser(WQE） req_fifo
        //.i_wp_vtp_wqe_cmd_empty (i_wp_vtp_wqe_cmd_empty),//i,            
        .o_wp_vtp_wqe_cmd_rd_en (o_wp_vtp_wqe_cmd_rd_en),//o,            
        .iv_wp_vtp_wqe_cmd_data (iv_wp_vtp_wqe_cmd_data),//i,[255:0]     
        //write WQE Parser(WQE） state_fifo
        .i_wp_vtp_wqe_resp_prog_full (i_wp_vtp_wqe_resp_prog_full),  //i,        
        .o_wp_vtp_wqe_resp_wr_en     (o_wp_vtp_wqe_resp_wr_en    ),  //o,        
        .ov_wp_vtp_wqe_resp_data     (ov_wp_vtp_wqe_resp_data    ),  //o,[7:0]   
        
        //read WQE Parser(DATA) req_fifo
        //.i_wp_vtp_nd_cmd_empty (i_wp_vtp_nd_cmd_empty),//i,        
        .o_wp_vtp_nd_cmd_rd_en (o_wp_vtp_nd_cmd_rd_en),//o,        
        .iv_wp_vtp_nd_cmd_data (iv_wp_vtp_nd_cmd_data),//i,[255:0] 
        //write WQE Parser(DATA) state_fifo
        .i_wp_vtp_nd_resp_prog_full    (i_wp_vtp_nd_resp_prog_full),//i,        
        .o_wp_vtp_nd_resp_wr_en        (o_wp_vtp_nd_resp_wr_en    ),//o,        
        .ov_wp_vtp_nd_resp_data        (ov_wp_vtp_nd_resp_data    ),//o,[7:0]   
        
        //read  RequesterTransControl(CQ) req_fifo
        //.i_rtc_vtp_cmd_empty (i_rtc_vtp_cmd_empty),//i,           
        .o_rtc_vtp_cmd_rd_en (o_rtc_vtp_cmd_rd_en),//o,           
        .iv_rtc_vtp_cmd_data (iv_rtc_vtp_cmd_data),//i,[255:0]    
        //write RequesterTransControl(CQ) state_fifo
        .i_rtc_vtp_resp_prog_full (i_rtc_vtp_resp_prog_full),//input   wire          
        .o_rtc_vtp_resp_wr_en     (o_rtc_vtp_resp_wr_en    ),//output  reg           
        .ov_rtc_vtp_resp_data     (ov_rtc_vtp_resp_data    ),//output  reg     [7:0] 

        //read  RequesterRecvControl(DATA) req_fifo
        //.i_rrc_vtp_cmd_empty (i_rrc_vtp_cmd_empty), //input    wire               
        .o_rrc_vtp_cmd_rd_en (o_rrc_vtp_cmd_rd_en), //output    reg               
        .iv_rrc_vtp_cmd_data (iv_rrc_vtp_cmd_data), //input    wire    [255:0]    
        //write RequesterRecvControl(DATA) state_fifo
        .i_rrc_vtp_resp_prog_full (i_rrc_vtp_resp_prog_full),//input   wire          
        .o_rrc_vtp_resp_wr_en     (o_rrc_vtp_resp_wr_en    ),//output  reg           
        .ov_rrc_vtp_resp_data     (ov_rrc_vtp_resp_data    ),//output  reg     [7:0] 

        //read  Execution Engine(DATA) req_fifo
        //.i_ee_vtp_cmd_empty (i_ee_vtp_cmd_empty),//input    wire               
        .o_ee_vtp_cmd_rd_en (o_ee_vtp_cmd_rd_en),//output    reg               
        .iv_ee_vtp_cmd_data (iv_ee_vtp_cmd_data),//input    wire    [255:0]    
        //write Execution Engine(DATA) state_fifo
        .i_ee_vtp_resp_prog_full  (i_ee_vtp_resp_prog_full),  //input   wire          
        .o_ee_vtp_resp_wr_en      (o_ee_vtp_resp_wr_en    ),  //output  reg           
        .ov_ee_vtp_resp_data      (ov_ee_vtp_resp_data    ),  //output  reg     [7:0] 

        //read  Execution Engine(RQ WQE) req_fifo
        //.i_rwm_vtp_cmd_empty (i_rwm_vtp_cmd_empty), //input    wire           
        .o_rwm_vtp_cmd_rd_en (o_rwm_vtp_cmd_rd_en), //output    reg           
        .iv_rwm_vtp_cmd_data (iv_rwm_vtp_cmd_data), //input    wire    [255:0]
        //write Execution Engine(RQ WQE) state_fifo
        .i_rwm_vtp_resp_prog_full  (i_rwm_vtp_resp_prog_full),  //input   wire          
        .o_rwm_vtp_resp_wr_en      (o_rwm_vtp_resp_wr_en    ),  //output  reg           
        .ov_rwm_vtp_resp_data      (ov_rwm_vtp_resp_data    ),  //output  reg     [7:0] 

    //------------------interface to Metadata module-------------
        //read mpt_base for compute index in mpt_ram
        .mpt_base_addr (mpt_base_addr),  //input  wire  [63:0]                    

    //------------------interface to dma_read_ctx module-------------
        //read dma req header metadata from backup fifo
        //| --------99  bit------|
        //| index | opcode | len |
        //|  64   |    3   | 32  |
        .dma_rd_mpt_bkup_rd_en (dma_rd_mpt_bkup_rd_en),//output reg                           
        .dma_rd_mpt_bkup_dout (dma_rd_mpt_bkup_dout),//input  wire  [DMA_RD_BKUP_WIDTH-1:0] 
        .dma_rd_mpt_bkup_empty (dma_rd_mpt_bkup_empty),//input  wire                          
    
    //-----------------interface to DMA Engine module------------------
        //read MPT Ctx payload response from DMA Engine module     
        .dma_v2p_mpt_rd_rsp_tready (dma_v2p_mpt_rd_rsp_tready),//output  wire                
        .dma_v2p_mpt_rd_rsp_tvalid (dma_v2p_mpt_rd_rsp_tvalid),//input   wire                
        .dma_v2p_mpt_rd_rsp_tdata (dma_v2p_mpt_rd_rsp_tdata),//input   wire [`DT_WIDTH-1:0]
        .dma_v2p_mpt_rd_rsp_tlast (dma_v2p_mpt_rd_rsp_tlast),//input   wire                
        .dma_v2p_mpt_rd_rsp_theader (dma_v2p_mpt_rd_rsp_theader),//input   wire [`HD_WIDTH-1:0]

    //---------------------------mpt_ram--------------------------
        //lookup info and response state
        .lookup_allow_in (mpt_lookup_allow_in), //input  wire                     
        .lookup_rden (mpt_lookup_rden), //output reg                      
        .lookup_wren (mpt_lookup_wren), //output reg                      
        .lookup_wdata (mpt_lookup_wdata), //output reg  [LINE_SIZE*8-1:0]   
        //lookup info addr={(32-INDEX-TAG)'b0,lookup_tag,lookup_index}
        .lookup_index (mpt_lookup_index),//output reg  [INDEX -1     :0] 
        .lookup_tag   (mpt_lookup_tag  ),//output reg  [TAG -1       :0] 
        //.lookup_state (mpt_lookup_state),//input  wire [2:0]  // | 3<->miss | 2<->hit | 0<->idle |
        //.lookup_ldst  (mpt_lookup_ldst ),//input  wire         // 1 for store, and 0 for load
        //.state_valid  (mpt_state_valid ),//input  wire         // valid in normal state, invalid if stall
        .lookup_stall (mpt_lookup_stall),//output wire      
        .mpt_eq_addr (mpt_eq_addr),
        //lookup info state fifo
        .state_rd_en (mpt_state_rd_en), //output reg       
        .state_empty (mpt_state_empty), //input  wire      
        .state_dout  (mpt_state_dout ), //input  wire [4:0]
        //hit mpt entry in fifo, for mpt info match and mtt lookup
        .hit_data_rd_en (mpt_hit_data_rd_en), //output reg                   
        .hit_data_empty (mpt_hit_data_empty), //input  wire                  
        .hit_data_dout  (mpt_hit_data_dout ), //input  wire [LINE_SIZE*8-1:0]
        //miss read addr in fifo, for pending fifo addr to refill
        .miss_addr_rd_en  (mpt_miss_addr_rd_en),//output reg         
        .miss_addr_dout  (mpt_miss_addr_dout),//input  wire  [31:0]
        .miss_addr_empty  (mpt_miss_addr_empty),//input  wire        

    //----------------interface to MTT module-------------------------
        //write MTT read request(include Src,Op,mtt_index,v-addr,length) to MTT module        
        //| ---------------------165 bit------------------------- |
        //|   Src    |     Op  | mtt_index | address |Byte length |
        //|  164:162 | 161:160 |  159:96   |  95:32  |   31:0     |
        // .mpt_req_mtt_rd_en (mpt_req_mtt_rd_en), //input  wire         
        // .mpt_req_mtt_dout  (mpt_req_mtt_dout ), //output wire  [164:0]
        // .mpt_req_mtt_empty (mpt_req_mtt_empty), //output wire       
    //write read request(include Src,mtt_index,v-addr,length) to mpt_rd_req_parser module        
        //|--------------163 bit------------------------- |
        //|    Src  | mtt_index | address |Byte length |
        //| 162:160 |  159:96   |  95:32  |   31:0     |
        .mpt_rd_req_mtt_rd_en (mpt_rd_req_mtt_rd_en), //input  wire                     
        .mpt_rd_req_mtt_dout (mpt_rd_req_mtt_dout), //output wire  [162:0]            
        .mpt_rd_req_mtt_empty (mpt_rd_req_mtt_empty), //output wire    

    //write read request(include Src,mtt_index,v-addr,length) to mpt_rd_wqe_req_parser module        
        //|--------------163 bit------------------------- |
        //|    Src  | mtt_index | address |Byte length |
        //| 162:160 |  159:96   |  95:32  |   31:0     |
        .mpt_rd_wqe_req_mtt_rd_en (mpt_rd_wqe_req_mtt_rd_en), //input  wire                     
        .mpt_rd_wqe_req_mtt_dout (mpt_rd_wqe_req_mtt_dout), //output wire  [162:0]            
        .mpt_rd_wqe_req_mtt_empty (mpt_rd_wqe_req_mtt_empty), //output wire                     

    
    //write read request(include Src,mtt_index,v-addr,length) to mpt_wr_req_parser module        
        //|--------------163 bit------------------------- |
        //|    Src  | mtt_index | address |Byte length |
        //| 162:160 |  159:96   |  95:32  |   31:0     |
        .mpt_wr_req_mtt_rd_en (mpt_wr_req_mtt_rd_en), //input  wire                     
        .mpt_wr_req_mtt_dout (mpt_wr_req_mtt_dout), //output wire  [162:0]            
        .mpt_wr_req_mtt_empty (mpt_wr_req_mtt_empty), //output wire                     

        .mpt_rsp_stall (mpt_rsp_stall),
        .lookup_ram_cnt (lookup_ram_cnt)
    //apb_slave
    `ifdef V2P_DUG
        , .rw_data(rw_data[(`CEUPAR_DBG_RW_NUM+`TPTM_DBG_RW_NUM) *32 +: `MPTCTL_DBG_RW_NUM * 32])
        , .wv_dbg_bus_mptctl(wv_dbg_bus_mptctl)
    `endif                  
);

mpt_rd_req_parser u_mpt_rd_req_parser(
    .clk (clk),
    .rst (rst),
    //write read request(include Src,mtt_index,v-addr,length) to mtt_ram_ctl module        
        //|--------------163 bit------------------------- |
        //|    Src  | mtt_index | address |Byte length |
        //| 162:160 |  159:96   |  95:32  |   31:0     |
        .mpt_rd_req_mtt_rd_en (mpt_rd_req_mtt_rd_en), //output wire                     
        .mpt_rd_req_mtt_dout (mpt_rd_req_mtt_dout), //input  wire  [162:0]            
        .mpt_rd_req_mtt_empty (mpt_rd_req_mtt_empty), //input  wire                     

    //---------------------------mtt_ram_ctl--------------------------
        //mtt_ram look up request at cacheline level for dma read data requests
        //|--------------198 bit------------------------- |
        //|    Src  |  total length |    Op  | mtt_index | address | tmp length |
        //| 197:195 |    194:163    |162:160 |  159:96   |  95:32  |   31:0     |
        .mpt_rd_req_mtt_cl_rd_en (mpt_rd_req_mtt_cl_rd_en), //input   wire             
        .mpt_rd_req_mtt_cl_empty (mpt_rd_req_mtt_cl_empty), //output  wire             
        .mpt_rd_req_mtt_cl_dout (mpt_rd_req_mtt_cl_dout) //output  wire  [197:0]    
    //apb_slave
    `ifdef V2P_DUG
        , .rw_data(rw_data[(`CEUPAR_DBG_RW_NUM+`TPTM_DBG_RW_NUM+`MPTCTL_DBG_RW_NUM) *32 +: `MPTRD_DT_PAR_DBG_RW_NUM * 32])
        , .wv_dbg_bus_mpt_rd_data_par(wv_dbg_bus_mpt_rd_data_par)
    `endif                  
);

mpt_rd_wqe_req_parser u_mpt_rd_wqe_req_parser(
    .clk (clk),
    .rst (rst),
    //write read request(include Src,mtt_index,v-addr,length) to mtt_ram_ctl module        
        //|--------------163 bit------------------------- |
        //|    Src  | mtt_index | address |Byte length |
        //| 162:160 |  159:96   |  95:32  |   31:0     |
        .mpt_rd_wqe_req_mtt_rd_en (mpt_rd_wqe_req_mtt_rd_en), //output wire                     
        .mpt_rd_wqe_req_mtt_dout (mpt_rd_wqe_req_mtt_dout), //input  wire  [162:0]            
        .mpt_rd_wqe_req_mtt_empty (mpt_rd_wqe_req_mtt_empty), //input  wire                     

    //---------------------------mtt_ram_ctl--------------------------
        //mtt_ram look up request at cacheline level for dma read data requests
        //|--------------198 bit------------------------- |
        //|    Src  |  total length |    Op  | mtt_index | address | tmp length |
        //| 197:195 |    194:163    |162:160 |  159:96   |  95:32  |   31:0     |
        .mpt_rd_wqe_req_mtt_cl_rd_en (mpt_rd_wqe_req_mtt_cl_rd_en), //input   wire             
        .mpt_rd_wqe_req_mtt_cl_empty (mpt_rd_wqe_req_mtt_cl_empty), //output  wire             
        .mpt_rd_wqe_req_mtt_cl_dout (mpt_rd_wqe_req_mtt_cl_dout) //output  wire  [197:0]    
    //apb_slave
    `ifdef V2P_DUG
        , .rw_data(rw_data[(`CEUPAR_DBG_RW_NUM+`TPTM_DBG_RW_NUM+`MPTCTL_DBG_RW_NUM+`MPTRD_DT_PAR_DBG_RW_NUM) *32 +: `MPTRD_WQE_PAR_DBG_RW_NUM * 32])
        , .wv_dbg_bus_mpt_rd_wqe_par(wv_dbg_bus_mpt_rd_wqe_par)
    `endif                  
);

mpt_wr_req_parser u_mpt_wr_req_parser(
    .clk (clk),
    .rst (rst),
    //----------------interface to mpt_ram_ctl module-------------------------
        //write read request(include Src,mtt_index,v-addr,length) to mtt_ram_ctl module        
        //|--------------163 bit------------------------- |
        //|    Src  | mtt_index | address |Byte length |
        //| 162:160 |  159:96   |  95:32  |   31:0     |
        .mpt_wr_req_mtt_rd_en (mpt_wr_req_mtt_rd_en), //output wire                     
        .mpt_wr_req_mtt_dout (mpt_wr_req_mtt_dout), //input  wire  [162:0]            
        .mpt_wr_req_mtt_empty (mpt_wr_req_mtt_empty), //input  wire                     

    //---------------------------mtt_ram_ctl--------------------------
        //mtt_ram look up request at cacheline level for dma read data requests
        //|--------------198 bit------------------------- |
        //|    Src  |  total length |    Op  | mtt_index | address | tmp length |
        //| 197:195 |    194:163    |162:160 |  159:96   |  95:32  |   31:0     |
        .mpt_wr_req_mtt_cl_rd_en (mpt_wr_req_mtt_cl_rd_en), //input   wire             
        .mpt_wr_req_mtt_cl_empty (mpt_wr_req_mtt_cl_empty), //output  wire             
        .mpt_wr_req_mtt_cl_dout (mpt_wr_req_mtt_cl_dout) //output  wire  [197:0] 
    //apb_slave
    `ifdef V2P_DUG
        , .rw_data(rw_data[(`CEUPAR_DBG_RW_NUM+`TPTM_DBG_RW_NUM+`MPTCTL_DBG_RW_NUM+`MPTRD_DT_PAR_DBG_RW_NUM+`MPTRD_WQE_PAR_DBG_RW_NUM) *32 +: `MPTWR_PAR_DBG_RW_NUM * 32])
        , .wv_dbg_bus_mptwr_par(wv_dbg_bus_mptwr_par)
    `endif                  
);

mtt_req_scheduler u_mtt_req_scheduler(
    .clk (clk),
    .rst (rst),

    .mpt_rd_req_mtt_cl_rd_en (mpt_rd_req_mtt_cl_rd_en), //input  wire  
    .mpt_rd_req_mtt_cl_empty (mpt_rd_req_mtt_cl_empty), //input  wire  
    .mpt_wr_req_mtt_cl_rd_en (mpt_wr_req_mtt_cl_rd_en), //input  wire  
    .mpt_wr_req_mtt_cl_empty (mpt_wr_req_mtt_cl_empty), //input  wire  
    //add for block processing, MXX at 2022.05.09 begin
        .mpt_rd_wqe_req_mtt_cl_rd_en (mpt_rd_wqe_req_mtt_cl_rd_en), //input  wire  
        .mpt_rd_wqe_req_mtt_cl_empty (mpt_rd_wqe_req_mtt_cl_empty), //input  wire  
        //mtt_ram_ctl block signal for 3 req fifo processing block 
        //| bit 2 read WQE | bit 1 write data | bit 0 read data |
        .block_valid (block_valid), //input  wire  [2:0]   
        .rd_wqe_block_info (rd_wqe_block_info), //input  wire  [197:0] 
        .wr_data_block_info (wr_data_block_info), //input  wire  [197:0] 
        .rd_data_block_info (rd_data_block_info), //input  wire  [197:0] 
        //mtt_ram_ctl unblock signal for reading 3 blocked req  
        //| bit 2 read WQE | bit 1 write data | bit 0 read data |
        .unblock_valid (unblock_valid), //input  wire  [2:0]   
        .rd_wqe_block_reg (rd_wqe_block_reg), //output reg   [197:0] 
        .wr_data_block_reg (wr_data_block_reg), //output reg   [197:0] 
        .rd_data_block_reg (rd_data_block_reg), //output reg   [197:0] 

        .dma_rd_dt_req_prog_full (dma_rd_dt_req_prog_full), //input wire   
        .dma_rd_wqe_req_prog_full (dma_rd_wqe_req_prog_full), //input wire   
        .dma_wr_dt_req_prog_full (dma_wr_dt_req_prog_full), //input wire   

    //add for block processing, MXX at 2022.05.09 end
   
    //req_scheduler changes the value of Selected Channel Reg to mark the selected channel
    .new_selected_channel (new_selected_mtt_channel) //output reg  [3:0]  
    //apb_slave
    `ifdef V2P_DUG
        , .wv_dbg_bus_mttreq_ctl(wv_dbg_bus_mttreq_ctl)
    `endif 
);

mpt_ram #(
    .MPT_SIZE       (MPT_SIZE         ), //Total Size(MPT+MTT) 1MB, MPT_RAM occupies 512KB
    .CACHE_WAY_NUM  (MPT_CACHE_WAY_NUM),//2 way
    .LINE_SIZE      (MPT_LINE_SIZE    ),//Cache line size = 64B(MPT entry= 64B)
    .INDEX          (MPT_INDEX        ),//mpt_ram index width
    .TAG            (MPT_TAG          ),//mpt_ram tag width
    .TPT_HD_WIDTH   (TPT_HD_WIDTH     ),//for MPT-MPTdata req header fifo
    .CACHE_BANK_NUM (MPT_CACHE_BANK_NUM)
    ) u_mpt_ram(
    .clk (clk),
    .rst (rst),

	.global_mem_init_finish(global_mem_init_finish),
	.init_wea(init_wea),
	.init_addra(init_addra),
	.init_dina(init_dina),

    //pipeline 1 
        //out allow input signal 
        .lookup_allow_in (mpt_lookup_allow_in),//output wire                  
        .lookup_rden     (mpt_lookup_rden    ),//input  wire                  
        .lookup_wren     (mpt_lookup_wren    ),//input  wire                  
        .lookup_wdata    (mpt_lookup_wdata   ),//input  wire [LINE_SIZE*8-1:0] //1 MPT entry size
        .lookup_index    (mpt_lookup_index   ),//input  wire [INDEX -1     :0] //
        .lookup_tag      (mpt_lookup_tag     ),//input  wire [TAG -1       :0] //
        .mpt_eq_addr (mpt_eq_addr),

        //lookup state info out wire(all these state infos are stored in state out fifo)
        //.lookup_state (mpt_lookup_state), //output wire [2:0]  // | 3<->miss | 2<->hit | 0<->idle |
        //.lookup_ldst  (mpt_lookup_ldst ), //output wire        // 1 for store, and 0 for load
        //.state_valid  (mpt_state_valid ), //output wire        // valid in normal state, invalid if stall
        .state_rd_en  (mpt_state_rd_en ), //input  wire        
        .state_empty  (mpt_state_empty ), //output wire       
        .state_dout   (mpt_state_dout  ), //output wire [4:0] //{lookup_state[2:0],lookup_ldst,state_valid}

        //hit mpt entry out fifo, for mpt info match and mtt lookup
        .hit_data_rd_en (mpt_hit_data_rd_en),  //input  wire                  
        .hit_data_empty (mpt_hit_data_empty),   //output wire                  
        .hit_data_dout  (mpt_hit_data_dout ),  //output wire [LINE_SIZE*8-1:0]
        //miss read addr out fifo, for pending fifo addr to refill
        .miss_addr_rd_en (mpt_miss_addr_rd_en),//input  wire        
        .miss_addr_dout  (mpt_miss_addr_dout),//output wire  [31:0]
        .miss_addr_empty (mpt_miss_addr_empty),//output wire        

    // stall in pipeline 2 and 3: // stall the output of lookup stage
        .lookup_stall (mpt_lookup_stall),  //input  wire                         
                 
    //pipeline 3 replace: write back         
        //write MPT Ctx payload to dma_write_ctx module
        .dma_wr_mpt_rd_en (dma_wr_mpt_rd_en),//input  wire                  
        .dma_wr_mpt_dout  (dma_wr_mpt_dout ), //output wire  [`DT_WIDTH-1:0] 
        .dma_wr_mpt_empty (dma_wr_mpt_empty),//output wire                  

    //pipeline 2 and pipeline 3: mptmdata module req  
        //miss read req out fifo, for mptmdata initiate dma read req in pipeline 2
        //replace write req out fifo, for mptmdata initiate dma write req in pipeline 3
        .mptm_req_rd_en (mpt_req_mdata_rd_en), //input  wire                     
        .mptm_req_dout  (mpt_req_mdata_dout ), //output wire  [TPT_HD_WIDTH-1:0] //miss_addr or replace addr
        .mptm_req_empty (mpt_req_mdata_empty)  //output wire                     
    //apb_slave
    `ifdef V2P_DUG
        , .rw_data(rw_data[(`CEUPAR_DBG_RW_NUM+`TPTM_DBG_RW_NUM+`MPTCTL_DBG_RW_NUM+`MPTRD_DT_PAR_DBG_RW_NUM+`MPTRD_WQE_PAR_DBG_RW_NUM+`MPTWR_PAR_DBG_RW_NUM) *32 +: `MPT_DBG_RW_NUM * 32])
        , .wv_dbg_bus_mpt(wv_dbg_bus_mpt)
    `endif 
);


mtt_ram_ctl#(
    .MTT_SIZE         (MTT_SIZE         ), //Total Size(MPT+MTT) 1MB, mtt_RAM occupies 512KB
    .CACHE_WAY_NUM    (MTT_CACHE_WAY_NUM), //2 way
    .LINE_SIZE        (MTT_LINE_SIZE    ), //Cache line size = 32B(mtt entry= 8B)
    .INDEX            (MTT_INDEX        ), //mtt_ram index width
    .TAG              (MTT_TAG          ), //mtt_ram tag width
    .OFFSET           (MTT_OFFSET       ), //mtt_ram offset width
    .NUM              (MTT_NUM          ), //mtt_ram num width to indicate how many mtt entries in 1 cache line
    .DMA_DT_REQ_WIDTH (DMA_DT_REQ_WIDTH )  //mtt_ram_ctl to dma_read/write_data req header fifo
    ) u_mtt_ram_ctl(
    .clk (clk),
    .rst (rst),
    //------------------interface to ceu channel----------------------
        // internal ceu request header
        // 128 width header format
        .mtt_req_rd_en (mtt_req_rd_en), //output  reg                 
        .mtt_req_dout (mtt_req_dout), //input  wire  [`HD_WIDTH-1:0]
        .mtt_req_empty (mtt_req_empty), //input  wire                 
    
        // internal ceu payload data
        // 256 width 
        .mtt_data_rd_en (mtt_data_rd_en),//output  reg                    
        .mtt_data_dout (mtt_data_dout),//input  wire  [`DT_WIDTH-1:0]   
        .mtt_data_empty (mtt_data_empty),//input  wire                    

    //------------------interface to Metadata module-------------
        //read mtt_base for compute index in mtt_ram
        .mtt_base_addr (mtt_base_addr),  //input  wire  [63:0]             
    //------------------interface to mtt_req_scheduler---------
        .new_selected_channel (new_selected_mtt_channel), //input wire [3:0] 
        //mtt_ram_ctl block signal for 3 req fifo processing block 
        //| bit 2 read WQE | bit 1 write data | bit 0 read data |
        .block_valid (block_valid), //input  wire  [2:0]   
        .rd_wqe_block_info (rd_wqe_block_info), //input  wire  [197:0] 
        .wr_data_block_info (wr_data_block_info), //input  wire  [197:0] 
        .rd_data_block_info (rd_data_block_info), //input  wire  [197:0] 
        //mtt_ram_ctl unblock signal for reading 3 blocked req  
        //| bit 2 read WQE | bit 1 write data | bit 0 read data |
        .unblock_valid (unblock_valid), //input  wire  [2:0]   
        .rd_wqe_block_reg (rd_wqe_block_reg), //output reg   [197:0] 
        .wr_data_block_reg (wr_data_block_reg), //output reg   [197:0] 
        .rd_data_block_reg (rd_data_block_reg), //output reg   [197:0] 
        .dma_rd_dt_req_prog_full (dma_rd_dt_req_prog_full), //output wire   
        .dma_rd_wqe_req_prog_full (dma_rd_wqe_req_prog_full), //output wire   
        .dma_wr_dt_req_prog_full (dma_wr_dt_req_prog_full), //output wire   
    //----------------interface to mpt_rd_req_parser module-------------------------
        //mtt_ram look up request at cacheline level for dma read data requests
        //|--------------198 bit------------------------- |
        //|    Src  |  total length |    Op  | mtt_index | address | tmp length |
        //| 197:195 |    194:163    |162:160 |  159:96   |  95:32  |   31:0     |
        .mpt_rd_req_mtt_cl_rd_en (mpt_rd_req_mtt_cl_rd_en), //output  wire             
        .mpt_rd_req_mtt_cl_empty (mpt_rd_req_mtt_cl_empty), //input   wire             
        .mpt_rd_req_mtt_cl_dout (mpt_rd_req_mtt_cl_dout), //input   wire  [197:0]    

    //----------------interface to mpt_rd_wqe_req_parser module-------------------------
        //mtt_ram look up request at cacheline level for dma read data requests
        //|--------------198 bit------------------------- |
        //|    Src  |  total length |    Op  | mtt_index | address | tmp length |
        //| 197:195 |    194:163    |162:160 |  159:96   |  95:32  |   31:0     |
        .mpt_rd_wqe_req_mtt_cl_rd_en (mpt_rd_wqe_req_mtt_cl_rd_en), //output  wire             
        .mpt_rd_wqe_req_mtt_cl_empty (mpt_rd_wqe_req_mtt_cl_empty), //input   wire             
        .mpt_rd_wqe_req_mtt_cl_dout (mpt_rd_wqe_req_mtt_cl_dout), //input   wire  [197:0]    

    //----------------interface to mpt_wr_req_parser module-------------------------
        //mtt_ram look up request at cacheline level for dma read data requests
        //|--------------198 bit------------------------- |
        //|    Src  |  total length |    Op  | mtt_index | address | tmp length |
        //| 197:195 |    194:163    |162:160 |  159:96   |  95:32  |   31:0     |
        .mpt_wr_req_mtt_cl_rd_en (mpt_wr_req_mtt_cl_rd_en), //output  wire             
        .mpt_wr_req_mtt_cl_empty (mpt_wr_req_mtt_cl_empty), //input   wire             
        .mpt_wr_req_mtt_cl_dout (mpt_wr_req_mtt_cl_dout), //input   wire  [197:0]    

    //---------------------------mtt_ram--------------------------
        //lookup info 
        .lookup_allow_in (mtt_lookup_allow_in), //input  wire                  
        .lookup_rden (mtt_lookup_rden), //output reg                   
        .lookup_wren (mtt_lookup_wren), //output reg                   
        .lookup_wdata (mtt_lookup_wdata), //output reg  [LINE_SIZE*8-1:0]
        .lookup_index (mtt_lookup_index), //output reg  [INDEX -1     :0]
        .lookup_tag (mtt_lookup_tag), //output reg  [TAG -1       :0]
        .lookup_offset (mtt_lookup_offset), //output reg  [OFFSET - 1   :0]
        .lookup_num (mtt_lookup_num), //output reg  [NUM - 1      :0]
        .mtt_eq_addr(mtt_eq_addr),
        //response state
        .lookup_state (mtt_lookup_state),//input  wire [2:0] // | 3<->miss | 2<->hit | 0<->idle |
        .lookup_ldst  (mtt_lookup_ldst ), //input  wire       // 1 for store, and 0 for load
        .state_valid  (mtt_state_valid ), //input  wire       // valid in normal state, invalid if stall
        .lookup_stall (mtt_lookup_stall),//output wire       

        //hit read mtt entry 
        .hit_rdata (mtt_hit_rdata), //input  wire [LINE_SIZE*8-1:0]   
        //miss read mtt entry, it's the dma reaponse data
        .miss_rdata (mtt_miss_rdata),//input  wire [LINE_SIZE*8-1:0]   

    //------------------interface to dma_read_data module-------------
        .dma_rd_dt_req_rd_en (dma_rd_dt_req_rd_en), //input   wire                        
        .dma_rd_dt_req_empty (dma_rd_dt_req_empty), //output  wire                        
        .dma_rd_dt_req_dout (dma_rd_dt_req_dout), //output  wire  [DMA_DT_REQ_WIDTH-1:0]
        .dma_rd_wqe_req_rd_en (dma_rd_wqe_req_rd_en),//input   wire                            
        .dma_rd_wqe_req_empty (dma_rd_wqe_req_empty),//output  wire                            
        .dma_rd_wqe_req_dout (dma_rd_wqe_req_dout),//output  wire  [DMA_DT_REQ_WIDTH-1:0]    

        .dma_wr_dt_req_rd_en (dma_wr_dt_req_rd_en), //input   wire                        
        .dma_wr_dt_req_empty (dma_wr_dt_req_empty), //output  wire                        
        .dma_wr_dt_req_dout (dma_wr_dt_req_dout) //output  wire  [DMA_DT_REQ_WIDTH-1:0]
    //apb_slave
    `ifdef V2P_DUG
        , .rw_data(rw_data[(`CEUPAR_DBG_RW_NUM+`TPTM_DBG_RW_NUM+`MPTCTL_DBG_RW_NUM+`MPTRD_DT_PAR_DBG_RW_NUM+`MPTRD_WQE_PAR_DBG_RW_NUM+`MPTWR_PAR_DBG_RW_NUM+`MPT_DBG_RW_NUM) *32 +: `MTTCTL_DBG_RW_NUM * 32])
        , .wv_dbg_bus_mttctl(wv_dbg_bus_mttctl)
    `endif 
);

mtt_ram#(
    .MTT_SIZE       (MTT_SIZE          ),//Total Size(MPT+MTT) 1MB, mtt_RAM occupies 512KB, valid addr width= l8
    .CACHE_WAY_NUM  (MTT_CACHE_WAY_NUM ),//2 way
    .LINE_SIZE      (MTT_LINE_SIZE     ),//Cache line size = 32B(mtt entry= 8B)
    .INDEX          (MTT_INDEX         ),//mtt_ram index width
    .TAG            (MTT_TAG           ),//mtt_ram tag width
    .OFFSET         (MTT_OFFSET        ),//mtt_ram offset width
    .NUM            (MTT_NUM           ),//mtt_ram num width to indicate how many mtt entries in 1 cache line
    .TPT_HD_WIDTH   (    TPT_HD_WIDTH  ),//for mtt-mttdata req header fifo
    .CACHE_BANK_NUM (MTT_CACHE_BANK_NUM) //1 way BRAM num = 4
    ) u_mtt_ram(
    .clk (clk),
    .rst (rst),

	.global_mem_init_finish(global_mem_init_finish),
	.init_wea(init_wea),
	.init_addra(init_addra),
	.init_dina(init_dina),

    //pipeline 1 
        //out allow input signal 
        .lookup_allow_in (mtt_lookup_allow_in),//output wire                  
        .lookup_rden     (mtt_lookup_rden    ),//input  wire                  
        .lookup_wren     (mtt_lookup_wren    ),//input  wire                  
        .lookup_wdata    (mtt_lookup_wdata   ),//input  wire [LINE_SIZE*8-1:0] //4 mtt entry size, {0,NUM of valid mtt data}
        .lookup_index    (mtt_lookup_index   ),//input  wire [INDEX -1     :0] //
        .lookup_tag      (mtt_lookup_tag     ),//input  wire [TAG -1       :0] //
        .lookup_offset   (mtt_lookup_offset  ),//input  wire [OFFSET -1    :0] //indicate the offset in 1 cacheline
        .lookup_num      (mtt_lookup_num     ),//input  wire [NUM -1       :0] //indicate the mtt number in 1 cacheline
        .mtt_eq_addr(mtt_eq_addr),
    //pipeline 2
        //lookup state info out wire(all these state infos are stored in state out fifo)
        .lookup_state (mtt_lookup_state),//output wire [2:0] // | 3<->miss | 2<->hit | 0<->idle |
        .lookup_ldst  (mtt_lookup_ldst ),//output wire       // 1 for store, and 0 for load
        .state_valid  (mtt_state_valid ),//output wire       // valid in normal state, invalid if stall
        .hit_rdata  (mtt_hit_rdata ),//output wire [LINE_SIZE*8-1:0]
        .miss_rdata (mtt_miss_rdata),//output wire [LINE_SIZE*8-1:0]
        // receive dma resp data in this module
        //read MPT Ctx payload response from DMA Engine module     
        .dma_v2p_mtt_rd_rsp_tready (dma_v2p_mtt_rd_rsp_tready), //output  wire                
        .dma_v2p_mtt_rd_rsp_tvalid (dma_v2p_mtt_rd_rsp_tvalid), //input   wire                
        .dma_v2p_mtt_rd_rsp_tdata (dma_v2p_mtt_rd_rsp_tdata), //input   wire [`DT_WIDTH-1:0]
        .dma_v2p_mtt_rd_rsp_tlast (dma_v2p_mtt_rd_rsp_tlast), //input   wire                
        .dma_v2p_mtt_rd_rsp_theader (dma_v2p_mtt_rd_rsp_theader), //input   wire [`HD_WIDTH-1:0]

    // stall in pipeline 2 and 3: //if miss mtt_ram_ctl need stall the output of lookup stage
        .lookup_stall (mtt_lookup_stall), //input  wire                         
                 
    //pipeline 3 replace: write back         
        //write mtt Ctx payload to dma_write_ctx module
        .dma_wr_mtt_rd_en (dma_wr_mtt_rd_en),//input  wire                 
        .dma_wr_mtt_dout  (dma_wr_mtt_dout ),//output wire  [`DT_WIDTH-1:0]// write back replace data
        .dma_wr_mtt_empty (dma_wr_mtt_empty),//output wire                 

    //pipeline 2 and pipeline 3: mttmdata module req  
        //miss read req out fifo, for mttmdata initiate dma read req in pipeline 2
        //replace write req out fifo, for mttmdata initiate dma write req in pipeline 3
        .mttm_req_rd_en (mtt_req_mdata_rd_en), //input  wire                    
        .mttm_req_dout  (mtt_req_mdata_dout ), //output wire  [TPT_HD_WIDTH-1:0]//miss_addr or replace addr
        .mttm_req_empty (mtt_req_mdata_empty) //output wire                    
    //apb_slave
    `ifdef V2P_DUG
        , .rw_data(rw_data[(`CEUPAR_DBG_RW_NUM+`TPTM_DBG_RW_NUM+`MPTCTL_DBG_RW_NUM+`MPTRD_DT_PAR_DBG_RW_NUM+`MPTRD_WQE_PAR_DBG_RW_NUM+`MPTWR_PAR_DBG_RW_NUM+`MPT_DBG_RW_NUM+`MTTCTL_DBG_RW_NUM) *32 +: `MTT_DBG_RW_NUM * 32])
        , .wv_dbg_bus_mtt(wv_dbg_bus_mtt)
    `endif 
);

dma_read_ctx_v2p#(
    .DMA_RD_HD_WIDTH   (DMA_RD_HD_WIDTH  ),//for Mdata-DMA Read req header fifo
    .DMA_RD_BKUP_WIDTH (DMA_RD_BKUP_WIDTH)//for Mdata-TPT Read req header fifo
    ) u_dma_read_ctx_v2p(
    .clk (clk),
    .rst (rst),
    //-------------tptmdata module interface------------------
    //| -----------163 bit----------|
    //| index | opcode | len | addr |
    //|  64   |    3   | 32  |  64  |
    //|--------------------------==-|
    //DMA Read MPT Ctx Request interface from tptmetadata module
    .dma_rd_mpt_req_rd_en (dma_rd_mpt_req_rd_en),//output  wire                           
    .dma_rd_mpt_req_dout (dma_rd_mpt_req_dout),//input   wire  [DMA_RD_HD_WIDTH-1:0]    
    .dma_rd_mpt_req_empty (dma_rd_mpt_req_empty),//input   wire                           
    //DMA Read MTT Ctx Request interface from tptmetadata module
    .dma_rd_mtt_req_rd_en (dma_rd_mtt_req_rd_en),//output  wire                           
    .dma_rd_mtt_req_dout (dma_rd_mtt_req_dout),//input   wire  [DMA_RD_HD_WIDTH-1:0]    
    .dma_rd_mtt_req_empty (dma_rd_mtt_req_empty),//input   wire                           
    
    //-------------tpt module interface------------------
    //| --------99  bit------|
    //| index | opcode | len |
    //|  64   |    3   | 32  |
    //|--------------------------==-|
    //DMA Read Ctx metadata backups to mpt module
    .dma_rd_mpt_bkup_rd_en (dma_rd_mpt_bkup_rd_en),//input  wire                         
    .dma_rd_mpt_bkup_dout (dma_rd_mpt_bkup_dout),//output wire  [DMA_RD_BKUP_WIDTH-1:0]
    .dma_rd_mpt_bkup_empty (dma_rd_mpt_bkup_empty),//output wire                         

    //-------------DMA Engine module interface------------------
    /* dma_*_head(interact with DMA modules), valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:12   |    11:0     |
     */
    //DMA tpt Context Read Request to dma engine
    .dma_v2p_mpt_rd_req_valid (dma_v2p_mpt_rd_req_valid),//output  wire                  
    .dma_v2p_mpt_rd_req_last  (dma_v2p_mpt_rd_req_last ),//output  wire                  
    .dma_v2p_mpt_rd_req_data  (dma_v2p_mpt_rd_req_data ),//output  wire [(`DT_WIDTH-1):0]
    .dma_v2p_mpt_rd_req_head  (dma_v2p_mpt_rd_req_head ),//output  wire [(`HD_WIDTH-1):0]
    .dma_v2p_mpt_rd_req_ready (dma_v2p_mpt_rd_req_ready),//input   wire           

    .dma_v2p_mtt_rd_req_valid (dma_v2p_mtt_rd_req_valid),//output  wire                  
    .dma_v2p_mtt_rd_req_last  (dma_v2p_mtt_rd_req_last ),//output  wire                  
    .dma_v2p_mtt_rd_req_data  (dma_v2p_mtt_rd_req_data ),//output  wire [(`DT_WIDTH-1):0]
    .dma_v2p_mtt_rd_req_head  (dma_v2p_mtt_rd_req_head ),//output  wire [(`HD_WIDTH-1):0]
    .dma_v2p_mtt_rd_req_ready (dma_v2p_mtt_rd_req_ready)      //input   wire                  
    //apb_slave
    `ifdef V2P_DUG
        , .rw_data(rw_data[(`CEUPAR_DBG_RW_NUM+`TPTM_DBG_RW_NUM+`MPTCTL_DBG_RW_NUM+`MPTRD_DT_PAR_DBG_RW_NUM+`MPTRD_WQE_PAR_DBG_RW_NUM+`MPTWR_PAR_DBG_RW_NUM+`MPT_DBG_RW_NUM+`MTTCTL_DBG_RW_NUM+`MTT_DBG_RW_NUM) *32 +: `V2P_RDCTX_DBG_RW_NUM * 32])
        , .wv_dbg_bus_rdctx(wv_dbg_bus_rdctx)
    `endif 
);  

dma_write_ctx_v2p#(
    .DMA_WR_HD_WIDTH (DMA_WR_HD_WIDTH)
    ) u_dma_write_ctx_v2p(
    .clk (clk),
    .rst (rst),
    //-------------tptmdata module interface------------------
    //|-----99 bit----------|
    //| opcode | len | addr |
    //|    3   | 32  |  64  |
    //|---------------------|
    //DMA Write mpt Ctx Request interface
    .dma_wr_mpt_req_rd_en (dma_wr_mpt_req_rd_en),//output  wire                           
    .dma_wr_mpt_req_dout (dma_wr_mpt_req_dout),//input   wire  [DMA_WR_HD_WIDTH-1:0]    
    .dma_wr_mpt_req_empty (dma_wr_mpt_req_empty),//input   wire                           
    //DMA Write mtt Ctx Request interface
    .dma_wr_mtt_req_rd_en  (dma_wr_mtt_req_rd_en),//output  wire                           
    .dma_wr_mtt_req_dout  (dma_wr_mtt_req_dout),//input   wire  [DMA_WR_HD_WIDTH-1:0]    
    .dma_wr_mtt_req_empty  (dma_wr_mtt_req_empty),//input   wire                           

    //-------------mpt module interface------------------
    //DMA write MPT Ctx payload from MPT module
    .dma_wr_mpt_rd_en (dma_wr_mpt_rd_en),//output wire                 
    .dma_wr_mpt_dout (dma_wr_mpt_dout),//input  wire  [`DT_WIDTH-1:0]
    .dma_wr_mpt_empty (dma_wr_mpt_empty),//input  wire                 

    //-------------mtt module interface------------------
    //DMA write MTT Ctx payload from MTT module  
    .dma_wr_mtt_rd_en (dma_wr_mtt_rd_en),//output wire                 
    .dma_wr_mtt_dout (dma_wr_mtt_dout),//input  wire  [`DT_WIDTH-1:0]
    .dma_wr_mtt_empty (dma_wr_mtt_empty),//input  wire                 

    //-------------DMA Engine module interface------------------
    /* dma_*_head(interact with DMA modules), valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:12   |    11:0     |
     */
    //DMA MPT Context Write Request
    .dma_v2p_mpt_wr_req_valid (dma_v2p_mpt_wr_req_valid),//output  wire                  
    .dma_v2p_mpt_wr_req_last  (dma_v2p_mpt_wr_req_last ),//output  wire                  
    .dma_v2p_mpt_wr_req_data  (dma_v2p_mpt_wr_req_data ),//output  wire [(`DT_WIDTH-1):0]
    .dma_v2p_mpt_wr_req_head  (dma_v2p_mpt_wr_req_head ),//output  wire [(`HD_WIDTH-1):0]
    .dma_v2p_mpt_wr_req_ready (dma_v2p_mpt_wr_req_ready),//input   wire                  
    //DMA MTT Context Write Request
    .dma_v2p_mtt_wr_req_valid (dma_v2p_mtt_wr_req_valid),//output  wire                  
    .dma_v2p_mtt_wr_req_last  (dma_v2p_mtt_wr_req_last ),//output  wire                  
    .dma_v2p_mtt_wr_req_data  (dma_v2p_mtt_wr_req_data ),//output  wire [(`DT_WIDTH-1):0]
    .dma_v2p_mtt_wr_req_head  (dma_v2p_mtt_wr_req_head ),//output  wire [(`HD_WIDTH-1):0]
    .dma_v2p_mtt_wr_req_ready (dma_v2p_mtt_wr_req_ready)//input   wire                  
    //apb_slave
    `ifdef V2P_DUG
        , .wv_dbg_bus_wrctx(wv_dbg_bus_wrctx)
    `endif 
);

dma_read_data#(
    .DMA_DT_REQ_WIDTH (DMA_DT_REQ_WIDTH)
    ) u_dma_read_data(
    .clk (clk),
    .rst (rst),
  //------------------interface to dma_read_data module-------------
    //-mtt_ram_ctl--dma_read_data req header format
    //high-----------------------------low
    //|-------------------134 bit--------------------|
    //| total len |opcode | dest/src |tmp len | addr |
    //| 32        |   3   |     3    | 32     |  64  |
    //|----------------------------------------------|
    .dma_rd_dt_req_rd_en (dma_rd_dt_req_rd_en),//output  wire                        
    .dma_rd_dt_req_empty (dma_rd_dt_req_empty),//input   wire                        
    .dma_rd_dt_req_dout (dma_rd_dt_req_dout),  //input   wire  [DMA_DT_REQ_WIDTH-1:0]

  //Interface with RDMA Engine
    //Channel 1 for Doorbell Processing, only read
    .o_wp_vtp_nd_download_wr_en (o_wp_vtp_nd_download_wr_en), //output  reg            
    .i_wp_vtp_nd_download_prog_full (i_wp_vtp_nd_download_prog_full), //input   wire           
    .ov_wp_vtp_nd_download_data (ov_wp_vtp_nd_download_data), //output  reg     [255:0]
    .o_ee_vtp_download_wr_en (o_ee_vtp_download_wr_en), //output  reg            
    .i_ee_vtp_download_prog_full (i_ee_vtp_download_prog_full), //input   wire           
    .ov_ee_vtp_download_data (ov_ee_vtp_download_data), //output  reg     [255:0]

  //Interface with DMA Engine
    .dma_v2p_dt_rd_req_valid (dma_v2p_dt_rd_req_valid),// output  wire                  
    .dma_v2p_dt_rd_req_last  (dma_v2p_dt_rd_req_last ),// output  wire                  
    .dma_v2p_dt_rd_req_data  (dma_v2p_dt_rd_req_data ),// output  wire [(`DT_WIDTH-1):0]
    .dma_v2p_dt_rd_req_head  (dma_v2p_dt_rd_req_head ),// output  wire [(`HD_WIDTH-1):0]
    .dma_v2p_dt_rd_req_ready (dma_v2p_dt_rd_req_ready),// input   wire                  
    .dma_v2p_dt_rd_rsp_tready (dma_v2p_dt_rd_rsp_tready),// output  wire                  
    .dma_v2p_dt_rd_rsp_tvalid (dma_v2p_dt_rd_rsp_tvalid),// input   wire                  
    .dma_v2p_dt_rd_rsp_tdata (dma_v2p_dt_rd_rsp_tdata),// input   wire [`DT_WIDTH-1:0]  
    .dma_v2p_dt_rd_rsp_tlast (dma_v2p_dt_rd_rsp_tlast),// input   wire                  
    .dma_v2p_dt_rd_rsp_theader (dma_v2p_dt_rd_rsp_theader)// input   wire [`HD_WIDTH-1:0]  
    //apb_slave
    `ifdef V2P_DUG
        , .rw_data(rw_data[(`CEUPAR_DBG_RW_NUM+`TPTM_DBG_RW_NUM+`MPTCTL_DBG_RW_NUM+`MPTRD_DT_PAR_DBG_RW_NUM+`MPTRD_WQE_PAR_DBG_RW_NUM+`MPTWR_PAR_DBG_RW_NUM+`MPT_DBG_RW_NUM+`MTTCTL_DBG_RW_NUM+`MTT_DBG_RW_NUM+`V2P_RDCTX_DBG_RW_NUM) *32 +: `RDDT_DBG_RW_NUM * 32])
        , .wv_dbg_bus_rddt(wv_dbg_bus_rddt)
    `endif 
);

dma_read_wqe#(
    .DMA_DT_REQ_WIDTH (DMA_DT_REQ_WIDTH)
) u_dma_read_wqe(
    .clk (clk),
    .rst (rst),
  //------------------interface to dma_read_data module-------------
    //-mtt_ram_ctl--dma_read_data req header format
    //high-----------------------------low
    //|-------------------134 bit--------------------|
    //| total len |opcode | dest/src |tmp len | addr |
    //| 32        |   3   |     3    | 32     |  64  |
    //|----------------------------------------------|
    .dma_rd_wqe_req_rd_en (dma_rd_wqe_req_rd_en),//output  wire                        
    .dma_rd_wqe_req_empty (dma_rd_wqe_req_empty),//input   wire                        
    .dma_rd_wqe_req_dout (dma_rd_wqe_req_dout),  //input   wire  [DMA_DT_REQ_WIDTH-1:0]

  //Interface with RDMA Engine
    //Channel 1 for Doorbell Processing, only read
    .o_db_vtp_download_wr_en (o_db_vtp_download_wr_en), //output  reg            
    .i_db_vtp_download_prog_full (i_db_vtp_download_prog_full), //input   wire           
    .ov_db_vtp_download_data (ov_db_vtp_download_data), //output  reg     [255:0]
    .o_wp_vtp_wqe_download_wr_en (o_wp_vtp_wqe_download_wr_en), //output  reg            
    .i_wp_vtp_wqe_download_prog_full (i_wp_vtp_wqe_download_prog_full), //input   wire           
    .ov_wp_vtp_wqe_download_data (ov_wp_vtp_wqe_download_data), //output  reg     [255:0]
    .o_rwm_vtp_download_wr_en (o_rwm_vtp_download_wr_en), //output  reg            
    .i_rwm_vtp_download_prog_full (i_rwm_vtp_download_prog_full), //input   wire           
    .ov_rwm_vtp_download_data (ov_rwm_vtp_download_data), //output  reg     [255:0]

  //Interface with DMA Engine
    .dma_v2p_wqe_rd_req_valid (dma_v2p_wqe_rd_req_valid), //output  wire                           
    .dma_v2p_wqe_rd_req_last (dma_v2p_wqe_rd_req_last) , //output  wire                           
    .dma_v2p_wqe_rd_req_data (dma_v2p_wqe_rd_req_data) , //output  wire [(`DT_WIDTH-1):0]         
    .dma_v2p_wqe_rd_req_head (dma_v2p_wqe_rd_req_head) , //output  wire [(`HD_WIDTH-1):0]         
    .dma_v2p_wqe_rd_req_ready (dma_v2p_wqe_rd_req_ready), //input   wire                           
    .dma_v2p_wqe_rd_rsp_tready (dma_v2p_wqe_rd_rsp_tready), //output  wire                           
    .dma_v2p_wqe_rd_rsp_tvalid (dma_v2p_wqe_rd_rsp_tvalid), //input   wire                           
    .dma_v2p_wqe_rd_rsp_tdata (dma_v2p_wqe_rd_rsp_tdata), //input   wire [`DT_WIDTH-1:0]           
    .dma_v2p_wqe_rd_rsp_tlast (dma_v2p_wqe_rd_rsp_tlast), //input   wire                           
    .dma_v2p_wqe_rd_rsp_theader (dma_v2p_wqe_rd_rsp_theader) //input   wire [`HD_WIDTH-1:0]           

    //apb_slave
    `ifdef V2P_DUG
        , .rw_data(rw_data[(`CEUPAR_DBG_RW_NUM+`TPTM_DBG_RW_NUM+`MPTCTL_DBG_RW_NUM+`MPTRD_DT_PAR_DBG_RW_NUM+`MPTRD_WQE_PAR_DBG_RW_NUM+`MPTWR_PAR_DBG_RW_NUM+`MPT_DBG_RW_NUM+`MTTCTL_DBG_RW_NUM+`MTT_DBG_RW_NUM+`V2P_RDCTX_DBG_RW_NUM+`RDDT_DBG_RW_NUM) *32 +: `RDWQE_DBG_RW_NUM * 32])
        , .wv_dbg_bus_rdwqe(wv_dbg_bus_rdwqe)
    `endif 
);

dma_write_data#(
    .DMA_DT_REQ_WIDTH (DMA_DT_REQ_WIDTH) //mtt_ram_ctl to dma_read/write_data req header fifo
    ) u_dma_write_data(
    .clk (clk),
    .rst (rst),
//------------------interface to mtt_ram_ctl module-------------
    //-mtt_ram_ctl--dma_write_data req header format
    //high-----------------------------low
    //|-------------------134 bit--------------------|
    //| total len |opcode | dest/src |tmp len | addr |
    //| 32        |   3   |     3    | 32     |  64  |
    //|----------------------------------------------|
    .dma_wr_dt_req_rd_en (dma_wr_dt_req_rd_en),//output  wire                        
    .dma_wr_dt_req_empty (dma_wr_dt_req_empty),//input   wire                        
    .dma_wr_dt_req_dout (dma_wr_dt_req_dout),//input   wire  [DMA_DT_REQ_WIDTH-1:0]

//Interface with RDMA Engine
    //Channel 4 for RequesterTransControl, upload Completion Event
    .i_rtc_vtp_upload_empty (i_rtc_vtp_upload_empty),//input   wire           
    .o_rtc_vtp_upload_rd_en (o_rtc_vtp_upload_rd_en),//output  wire           
    .iv_rtc_vtp_upload_data (iv_rtc_vtp_upload_data),//input   wire    [255:0]

    //Channel 5 for RequesterRecvControl, upload RDMA Read Response
    .i_rrc_vtp_upload_empty (i_rrc_vtp_upload_empty),//input   wire           
    .o_rrc_vtp_upload_rd_en (o_rrc_vtp_upload_rd_en),//output  wire           
    .iv_rrc_vtp_upload_data (iv_rrc_vtp_upload_data),//input   wire    [255:0]

    //Channel 7 for ExecutionEngine, upload Send/Write Payload and download Read Payload
    .i_ee_vtp_upload_empty (i_ee_vtp_upload_empty),//input   wire           
    .o_ee_vtp_upload_rd_en (o_ee_vtp_upload_rd_en),//output  wire           
    .iv_ee_vtp_upload_data (iv_ee_vtp_upload_data),//input   wire    [255:0]

//Interface with DMA Engine
    //Channel 3 DMA Write Data(CQE/Network Data)   
    .dma_v2p_dt_wr_req_valid (dma_v2p_dt_wr_req_valid), //output  reg                   
    .dma_v2p_dt_wr_req_last  (dma_v2p_dt_wr_req_last ), //output  reg                   
    .dma_v2p_dt_wr_req_data  (dma_v2p_dt_wr_req_data ), //output  reg  [(`DT_WIDTH-1):0]
    .dma_v2p_dt_wr_req_head  (dma_v2p_dt_wr_req_head ), //output  reg  [(`HD_WIDTH-1):0]
    .dma_v2p_dt_wr_req_ready (dma_v2p_dt_wr_req_ready) //input   wire                  
    //apb_slave
    `ifdef V2P_DUG
        , .wv_dbg_bus_wrdt(wv_dbg_bus_wrdt)
    `endif 
);
//-----------------{sub-module instantiation} end---------------------
`ifdef ILA_VTP_ON
ila_tx_desc_fetch v2p_data_req (
	.clk(clk), // input wire clk

	.probe0(dma_v2p_dt_rd_req_valid), // input wire [0:0]  probe0  
	.probe1(dma_v2p_dt_rd_req_last), // input wire [0:0]  probe1 
	.probe2(dma_v2p_dt_rd_req_data), // input wire [255:0]  probe2 
	.probe3(dma_v2p_dt_rd_req_head), // input wire [127:0]  probe3 
	.probe4(dma_v2p_dt_rd_req_ready) // input wire [0:0]  probe4
);
`endif

//ila_tx_desc_fetch v2p_data_rsp (
//	.clk(clk), // input wire clk

//	.probe0(dma_v2p_dt_rd_rsp_tvalid), // input wire [0:0]  probe0  
//	.probe1(dma_v2p_dt_rd_rsp_tlast), // input wire [0:0]  probe1 
//	.probe2(dma_v2p_dt_rd_rsp_tdata), // input wire [255:0]  probe2 
//	.probe3(dma_v2p_dt_rd_rsp_theader), // input wire [127:0]  probe3 
//	.probe4(dma_v2p_dt_rd_rsp_tready) // input wire [0:0]  probe4
//);
endmodule
