`timescale 1ns / 100ps

`include "chip_include_rdma.vh"

module RDMAEngine_Wrapper
#(
    parameter 			NIC_DATA_WIDTH 					= 256,
    parameter 			NIC_KEEP_WIDTH 					= 5,
    parameter 			LINK_LAYER_USER_WIDTH 	= 7,
    parameter       ROCE_DATA_WIDTH         = 256,
    parameter       ROCE_DESC_WIDTH         = 192,

    parameter       RW_REG_NUM              = 129,
    parameter       RO_REG_NUM              = 129
)
(
    input   wire            clk,
    input   wire            rst,


//Interface with PIO
    output  wire              o_pio_prog_full,
    input   wire              i_pio_wr_en,
    input   wire    [63:0]    iv_pio_data,

//Interface with CxtMgt
    //Channel 1 for DoorbellProcessing, no cxt write back
    input   wire              i_db_cxtmgt_cmd_rd_en,
    output  wire              o_db_cxtmgt_cmd_empty,
    output  wire    [127:0]   ov_db_cxtmgt_cmd_data,

    output  wire              o_db_cxtmgt_resp_prog_full,
    input   wire              i_db_cxtmgt_resp_wr_en,
    input   wire    [127:0]   iv_db_cxtmgt_resp_data,

    output  wire              o_db_cxtmgt_cxt_download_prog_full,
    input   wire              i_db_cxtmgt_cxt_download_wr_en,
    input   wire    [255:0]   iv_db_cxtmgt_cxt_download_data,

    //Channel 2 for WQEParser, no cxt write back
    input   wire              i_wp_cxtmgt_cmd_rd_en,
    output  wire              o_wp_cxtmgt_cmd_empty,
    output  wire    [127:0]   ov_wp_cxtmgt_cmd_data,

    output  wire              o_wp_cxtmgt_resp_prog_full,
    input   wire              i_wp_cxtmgt_resp_wr_en,
    input   wire    [127:0]   iv_wp_cxtmgt_resp_data,

    output  wire              o_wp_cxtmgt_cxt_download_prog_full,
    input   wire              i_wp_cxtmgt_cxt_download_wr_en,
    input   wire    [127:0]   iv_wp_cxtmgt_cxt_download_data,

    //Channel 3 for RequesterTransControl, cxt write back
    input   wire              i_rtc_cxtmgt_cmd_rd_en,
    output  wire              o_rtc_cxtmgt_cmd_empty,
    output  wire    [127:0]   ov_rtc_cxtmgt_cmd_data,

    output  wire              o_rtc_cxtmgt_resp_prog_full,
    input   wire              i_rtc_cxtmgt_resp_wr_en,
    input   wire    [127:0]   iv_rtc_cxtmgt_resp_data,

    output  wire              o_rtc_cxtmgt_cxt_download_prog_full,
    input   wire              i_rtc_cxtmgt_cxt_download_wr_en,
    input   wire    [191:0]   iv_rtc_cxtmgt_cxt_download_data,

/*Spyglass Add Begin*/
    output  wire              o_rtc_cxtmgt_cxt_upload_empty,
    input   wire              i_rtc_cxtmgt_cxt_upload_rd_en,
    output  wire    [127:0]   ov_rtc_cxtmgt_cxt_upload_data,
/*SPyglass Add End*/

    //Channel 4 for RequesterRecvContro, cxt write back 
    input   wire              i_rrc_cxtmgt_cmd_rd_en,
    output  wire              o_rrc_cxtmgt_cmd_empty,
    output  wire    [127:0]   ov_rrc_cxtmgt_cmd_data,

    output  wire              o_rrc_cxtmgt_resp_prog_full,
    input   wire              i_rrc_cxtmgt_resp_wr_en,
    input   wire    [127:0]   iv_rrc_cxtmgt_resp_data,

    output  wire              o_rrc_cxtmgt_cxt_download_prog_full,
    input   wire              i_rrc_cxtmgt_cxt_download_wr_en,
    input   wire    [255:0]   iv_rrc_cxtmgt_cxt_download_data,

    input   wire              i_rrc_cxtmgt_cxt_upload_rd_en,
    output  wire              o_rrc_cxtmgt_cxt_upload_empty,
    output  wire    [127:0]   ov_rrc_cxtmgt_cxt_upload_data,

    //Channel 5 for ExecutionEngine, cxt write back
    input   wire              i_ee_cxtmgt_cmd_rd_en,
    output  wire              o_ee_cxtmgt_cmd_empty,
    output  wire    [127:0]   ov_ee_cxtmgt_cmd_data,

    output  wire              o_ee_cxtmgt_resp_prog_full,
    input   wire              i_ee_cxtmgt_resp_wr_en,
    input   wire    [127:0]   iv_ee_cxtmgt_resp_data,

    output  wire              o_ee_cxtmgt_cxt_download_prog_full,
    input   wire              i_ee_cxtmgt_cxt_download_wr_en,
    input   wire    [319:0]   iv_ee_cxtmgt_cxt_download_data,

    input   wire              i_ee_cxtmgt_cxt_upload_rd_en,
    output  wire              o_ee_cxtmgt_cxt_upload_empty,
    output  wire    [127:0]   ov_ee_cxtmgt_cxt_upload_data,

    //Channel 6 for FrameEncap
    input   wire              i_fe_cxtmgt_cmd_rd_en,
    output  wire              o_fe_cxtmgt_cmd_empty,
    output  wire    [127:0]   ov_fe_cxtmgt_cmd_data,

    output  wire              o_fe_cxtmgt_resp_prog_full,
    input   wire              i_fe_cxtmgt_resp_wr_en,
    input   wire    [127:0]   iv_fe_cxtmgt_resp_data,

    output  wire              o_fe_cxtmgt_cxt_download_prog_full,
    input   wire              i_fe_cxtmgt_cxt_download_wr_en,
    input   wire    [255:0]   iv_fe_cxtmgt_cxt_download_data,

//Interface with VirtToPhys
    //Channel 1 for Doorbell Processing, only read
    input   wire              i_db_vtp_cmd_rd_en,
    output  wire              o_db_vtp_cmd_empty,
    output  wire    [255:0]   ov_db_vtp_cmd_data,

    output  wire              o_db_vtp_resp_prog_full,
    input   wire              i_db_vtp_resp_wr_en,
    input   wire    [7:0]   iv_db_vtp_resp_data,

    output  wire              o_db_vtp_download_prog_full,
    input   wire              i_db_vtp_download_wr_en,
    input   wire    [255:0]   iv_db_vtp_download_data,
        
    //Channel 2 for WQEParser, download SQ WQE
    input   wire              i_wp_vtp_wqe_cmd_rd_en,
    output  wire              o_wp_vtp_wqe_cmd_empty,
    output  wire    [255:0]   ov_wp_vtp_wqe_cmd_data,

    output  wire              o_wp_vtp_wqe_resp_prog_full,
    input   wire              i_wp_vtp_wqe_resp_wr_en,
    input   wire    [7:0]   iv_wp_vtp_wqe_resp_data,

    output  wire              o_wp_vtp_wqe_download_prog_full,
    input   wire              i_wp_vtp_wqe_download_wr_en,
    input   wire    [255:0]   iv_wp_vtp_wqe_download_data,

    //Channel 3 for WQEParser, download network data
    input   wire              i_wp_vtp_nd_cmd_rd_en,
    output  wire              o_wp_vtp_nd_cmd_empty,
    output  wire    [255:0]   ov_wp_vtp_nd_cmd_data,

    output  wire              o_wp_vtp_nd_resp_prog_full,
    input   wire              i_wp_vtp_nd_resp_wr_en,
    input   wire    [7:0]   iv_wp_vtp_nd_resp_data,

    output  wire              o_wp_vtp_nd_download_prog_full,
    input   wire              i_wp_vtp_nd_download_wr_en,
    input   wire    [255:0]   iv_wp_vtp_nd_download_data,

    //Channel 4 for RequesterTransControl, upload Completion Event
    input   wire              i_rtc_vtp_cmd_rd_en,
    output  wire              o_rtc_vtp_cmd_empty,
    output  wire    [255:0]   ov_rtc_vtp_cmd_data,

    output  wire              o_rtc_vtp_resp_prog_full,
    input   wire              i_rtc_vtp_resp_wr_en,
    input   wire    [7:0]   iv_rtc_vtp_resp_data,

    input   wire              i_rtc_vtp_upload_rd_en,
    output  wire              o_rtc_vtp_upload_empty,
    output  wire    [255:0]   ov_rtc_vtp_upload_data,

    //Channel 5 for RequesterRecvControl, upload RDMA Read Response
    input   wire              i_rrc_vtp_cmd_rd_en,
    output  wire              o_rrc_vtp_cmd_empty,
    output  wire    [255:0]   ov_rrc_vtp_cmd_data,

    output  wire              o_rrc_vtp_resp_prog_full,
    input   wire              i_rrc_vtp_resp_wr_en,
    input   wire    [7:0]   iv_rrc_vtp_resp_data,

    input   wire              i_rrc_vtp_upload_rd_en,
    output  wire              o_rrc_vtp_upload_empty,
    output  wire    [255:0]   ov_rrc_vtp_upload_data,

    //Channel 6 for ExecutionEngine, upload Send/Write Payload and download Read Payload
    input   wire              i_ee_vtp_cmd_rd_en,
    output  wire              o_ee_vtp_cmd_empty,
    output  wire    [255:0]   ov_ee_vtp_cmd_data,

    output  wire              o_ee_vtp_resp_prog_full,
    input   wire              i_ee_vtp_resp_wr_en,
    input   wire    [7:0]   iv_ee_vtp_resp_data,

    input   wire              i_ee_vtp_upload_rd_en,
    output  wire              o_ee_vtp_upload_empty,
    output  wire    [255:0]   ov_ee_vtp_upload_data,

    input   wire              i_ee_vtp_download_wr_en,
    output  wire              o_ee_vtp_download_prog_full,
    input   wire    [255:0]   iv_ee_vtp_download_data,

    //Channel 7 for ExecutionEngine, download RQ WQE
    input   wire              i_rwm_vtp_cmd_rd_en,
    output  wire              o_rwm_vtp_cmd_empty,
    output  wire    [255:0]   ov_rwm_vtp_cmd_data,

    output  wire              o_rwm_vtp_resp_prog_full,
    input   wire              i_rwm_vtp_resp_wr_en,
    input   wire    [7:0]   iv_rwm_vtp_resp_data,

    input   wire              i_rwm_vtp_download_wr_en,
    output  wire              o_rwm_vtp_download_prog_full,
    input   wire    [255:0]   iv_rwm_vtp_download_data,

//LinkLayer
/*Interface with TX HPC Link, AXIS Interface*/
	/*interface to LinkLayer Tx  */
	output  wire                                 		  o_hpc_tx_valid,
	output  wire                                 		  o_hpc_tx_last,
	output  wire	[NIC_DATA_WIDTH - 1 : 0]           ov_hpc_tx_data,
	output  wire	[NIC_KEEP_WIDTH - 1 : 0]           ov_hpc_tx_keep,
	input   wire                                 		  i_hpc_tx_ready,
	 //Additional signals
	 output wire 										                  o_hpc_tx_start, 		//Indicates start of the packet
	 output wire 	[LINK_LAYER_USER_WIDTH - 1:0]		  ov_hpc_tx_user, 	 	//Indicates length of the packet, in unit of 128 Byte, round up to 128

/*Interface with RX HPC Link, AXIS Interface*/
	/*interface to LinkLayer Rx  */
	input     wire                                 		i_hpc_rx_valid, 
	input     wire                                 		i_hpc_rx_last,
	input     wire	[NIC_DATA_WIDTH - 1 : 0]       	iv_hpc_rx_data,
	input     wire	[NIC_KEEP_WIDTH - 1 : 0]       	iv_hpc_rx_keep,
	output    wire                                 		o_hpc_rx_ready,	
	//Additional signals
	input 	  wire 										                i_hpc_rx_start,
	input 	  wire 	[LINK_LAYER_USER_WIDTH - 1:0]		iv_hpc_rx_user, 

/*Interface with Tx Eth Link, FIFO Interface*/
	output 		wire 									                  o_desc_empty,
	output 		wire 	[ROCE_DESC_WIDTH - 1 : 0]		    ov_desc_data,
	input 		wire 									                  i_desc_rd_en,

	output 		wire 								  	                o_roce_egress_empty,
	input 		wire 									                  i_roce_egress_rd_en,
	output 		wire 	[NIC_DATA_WIDTH - 1 : 0]		      ov_roce_egress_data,

/*Interface with Rx Eth Link, FIFO Interface*/
	output 		wire 									                  o_roce_ingress_prog_full,
	input 		wire 									                  i_roce_ingress_wr_en,
	input 		wire 	[NIC_DATA_WIDTH - 1 : 0]		      iv_roce_ingress_data,

  output 	wire 				o_rdma_init_finish,

  input       wire    [RW_REG_NUM * 32 - 1 : 0]       rw_data,
  output      wire    [RW_REG_NUM * 32 - 1 : 0]       rw_init_data,
  output      wire    [RO_REG_NUM * 32 - 1 : 0]       ro_data,

  input   wire    [31:0]      dbg_sel,
  output  wire    [32 - 1:0]      dbg_bus
  //output  wire    [`DBG_NUM_RDMA_ENGINE_WRAPPER * 32 - 1:0]      dbg_bus

);

//wire    [31:0]      wv_rdma_engine_dbg_sel;
//wire    [`DBG_NUM_RDMA_ENGINE * 32 - 1 :0]      wv_rdma_engine_dbg_bus;
//wire    [31:0]      wv_misc_layer_dbg_sel;
//wire    [`DBG_NUM_MISC_LAYER * 32 - 1:0]      wv_misc_layer_dbg_bus;
wire    [31:0]      wv_rdma_engine_dbg_sel;
wire    [32 - 1 :0]      wv_rdma_engine_dbg_bus;
wire    [31:0]      wv_misc_layer_dbg_sel;
wire    [32 - 1:0]      wv_misc_layer_dbg_bus;

wire 	[32 * 14 - 1 : 0]		wv_misc_layer_init_rw_data;
wire 	[32 * 14 - 1 : 0]		wv_misc_layer_ro_data;

assign wv_rdma_engine_dbg_sel = dbg_sel - `DBG_NUM_ZERO;
assign wv_misc_layer_dbg_sel = dbg_sel - `DBG_NUM_RDMA_ENGINE;

wire                w_rdma_engine_init_finish;
wire                w_misc_layer_init_finish;

assign o_rdma_init_finish = w_rdma_engine_init_finish && w_misc_layer_init_finish;

/*---------------------------------------- Part 1: VTP Interface with RDMA Engine ------------------------------------*/
//Channel 1 for Doorbell Processing, only read
wire                w_db_vtp_cmd_prog_full;
wire                w_db_vtp_cmd_wr_en;
wire    [255:0]     wv_db_vtp_cmd_din;
SyncFIFO_256w_32d DB_VTP_CMD_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[0 * 32 + 1 : 0 * 32 + 0]),
	.WTSEL( rw_data[0 * 32 + 3 : 0 * 32 + 2]),
	.PTSEL( rw_data[0 * 32 + 5 : 0 * 32 + 4]),
	.VG(    rw_data[0 * 32 + 6 : 0 * 32 + 6]),
	.VS(    rw_data[0 * 32 + 7 : 0 * 32 + 7]),
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_db_vtp_cmd_din),                
  .wr_en(w_db_vtp_cmd_wr_en),            
  .rd_en(i_db_vtp_cmd_rd_en),            
  .dout(ov_db_vtp_cmd_data),              
  .empty(o_db_vtp_cmd_empty),            
  .prog_full(w_db_vtp_cmd_prog_full),
  .full()
  
);

wire                w_db_vtp_resp_empty;
wire                w_db_vtp_resp_rd_en;
wire    [7:0]       wv_db_vtp_resp_dout;
SyncFIFO_8w_16d DB_VTP_RESP_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[1 * 32 + 1 : 1 * 32 + 0]),
	.WTSEL( rw_data[1 * 32 + 3 : 1 * 32 + 2]),
	.PTSEL( rw_data[1 * 32 + 5 : 1 * 32 + 4]),
	.VG(    rw_data[1 * 32 + 6 : 1 * 32 + 6]),
	.VS(    rw_data[1 * 32 + 7 : 1 * 32 + 7]),
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(iv_db_vtp_resp_data),                
  .wr_en(i_db_vtp_resp_wr_en),            
  .rd_en(w_db_vtp_resp_rd_en),            
  .dout(wv_db_vtp_resp_dout),              
  .empty(w_db_vtp_resp_empty),            
  .prog_full(o_db_vtp_resp_prog_full),
  .full()
  
);

wire 	[255:0]		wv_db_vtp_download_din;
wire                w_db_vtp_download_empty;
wire                w_db_vtp_download_rd_en;
wire    [127:0]     wv_db_vtp_download_dout;
assign wv_db_vtp_download_din = {iv_db_vtp_download_data[127:0], iv_db_vtp_download_data[255:128]};
SyncFIFO_256wTo128w_64d DB_VTP_DOWNLOAD_FIFO(		//This FIFO will output higher 128-bit first
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[2 * 32 + 1 : 2 * 32 + 0]),
	.WTSEL( rw_data[2 * 32 + 3 : 2 * 32 + 2]),
	.PTSEL( rw_data[2 * 32 + 5 : 2 * 32 + 4]),
	.VG(    rw_data[2 * 32 + 6 : 2 * 32 + 6]),
	.VS(    rw_data[2 * 32 + 7 : 2 * 32 + 7]),
  `endif

  .clk(clk),                
  .srst(rst),              
  //.din(iv_db_vtp_download_data),                
  .din(wv_db_vtp_download_din),                
  .wr_en(i_db_vtp_download_wr_en),            
  .rd_en(w_db_vtp_download_rd_en),            
  .dout(wv_db_vtp_download_dout),              
  .empty(w_db_vtp_download_empty),            
  .prog_full(o_db_vtp_download_prog_full),
  .full()

);


//Channel 2 for WQEParser, download SQ WQE
wire                w_wp_vtp_wqe_cmd_wr_en;
wire                w_wp_vtp_wqe_cmd_prog_full;
wire    [255:0]     wv_wp_vtp_wqe_cmd_din;
SyncFIFO_256w_32d WP_VTP_WQE_CMD_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[3 * 32 + 1 : 3 * 32 + 0]),
	.WTSEL( rw_data[3 * 32 + 3 : 3 * 32 + 2]),
	.PTSEL( rw_data[3 * 32 + 5 : 3 * 32 + 4]),
	.VG(    rw_data[3 * 32 + 6 : 3 * 32 + 6]),
	.VS(    rw_data[3 * 32 + 7 : 3 * 32 + 7]),
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_wp_vtp_wqe_cmd_din),                
  .wr_en(w_wp_vtp_wqe_cmd_wr_en),            
  .rd_en(i_wp_vtp_wqe_cmd_rd_en),            
  .dout(ov_wp_vtp_wqe_cmd_data),              
  .empty(o_wp_vtp_wqe_cmd_empty),            
  .prog_full(w_wp_vtp_wqe_cmd_prog_full),
  .full()
  
);

wire                w_wp_vtp_wqe_resp_empty;
wire                w_wp_vtp_wqe_resp_rd_en;
wire    [7:0]       wv_wp_vtp_wqe_resp_dout;
SyncFIFO_8w_16d WP_VTP_WQE_RESP_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[4 * 32 + 1 : 4 * 32 + 0]),
	.WTSEL( rw_data[4 * 32 + 3 : 4 * 32 + 2]),
	.PTSEL( rw_data[4 * 32 + 5 : 4 * 32 + 4]),
	.VG(    rw_data[4 * 32 + 6 : 4 * 32 + 6]),
	.VS(    rw_data[4 * 32 + 7 : 4 * 32 + 7]),

  `endif

  .clk(clk),                
  .srst(rst),              
  .din(iv_wp_vtp_wqe_resp_data),                
  .wr_en(i_wp_vtp_wqe_resp_wr_en),            
  .rd_en(w_wp_vtp_wqe_resp_rd_en),            
  .dout(wv_wp_vtp_wqe_resp_dout),              
  .empty(w_wp_vtp_wqe_resp_empty),            
  .prog_full(o_wp_vtp_wqe_resp_prog_full),
  .full()
  
);

wire 	[255:0]		wv_wp_vtp_wqe_download_din;
wire                w_wp_vtp_wqe_download_empty;
wire                w_wp_vtp_wqe_download_rd_en;
wire    [127:0]     wv_wp_vtp_wqe_download_dout;
assign wv_wp_vtp_wqe_download_din = {iv_wp_vtp_wqe_download_data[127:0], iv_wp_vtp_wqe_download_data[255:128]};
SyncFIFO_256wTo128w_64d WP_VTP_WQE_DOWNLOAD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[5 * 32 + 1 : 5 * 32 + 0]),
	.WTSEL( rw_data[5 * 32 + 3 : 5 * 32 + 2]),
	.PTSEL( rw_data[5 * 32 + 5 : 5 * 32 + 4]),
	.VG(    rw_data[5 * 32 + 6 : 5 * 32 + 6]),
	.VS(    rw_data[5 * 32 + 7 : 5 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  //.din(iv_wp_vtp_wqe_download_data),                
  .din(wv_wp_vtp_wqe_download_din),                
  .wr_en(i_wp_vtp_wqe_download_wr_en),            
  .rd_en(w_wp_vtp_wqe_download_rd_en),            
  .dout(wv_wp_vtp_wqe_download_dout),              
  .empty(w_wp_vtp_wqe_download_empty),            
  .prog_full(o_wp_vtp_wqe_download_prog_full),
  .full()

);

//Channel 3 for WQEParser, download network data
wire                w_wp_vtp_nd_cmd_wr_en;
wire                w_wp_vtp_nd_cmd_prog_full;
wire    [255:0]     wv_wp_vtp_nd_cmd_din;
SyncFIFO_256w_32d WP_VTP_ND_CMD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[6 * 32 + 1 : 6 * 32 + 0]),
	.WTSEL( rw_data[6 * 32 + 3 : 6 * 32 + 2]),
	.PTSEL( rw_data[6 * 32 + 5 : 6 * 32 + 4]),
	.VG(    rw_data[6 * 32 + 6 : 6 * 32 + 6]),
	.VS(    rw_data[6 * 32 + 7 : 6 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_wp_vtp_nd_cmd_din),                
  .wr_en(w_wp_vtp_nd_cmd_wr_en),            
  .rd_en(i_wp_vtp_nd_cmd_rd_en),            
  .dout(ov_wp_vtp_nd_cmd_data),              
  .empty(o_wp_vtp_nd_cmd_empty),            
  .prog_full(w_wp_vtp_nd_cmd_prog_full),
  .full()
  
);

wire                w_wp_vtp_nd_resp_empty;
wire                w_wp_vtp_nd_resp_rd_en;
wire    [7:0]       wv_wp_vtp_nd_resp_dout;
SyncFIFO_8w_16d WP_VTP_ND_RESP_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[7 * 32 + 1 : 7 * 32 + 0]),
	.WTSEL( rw_data[7 * 32 + 3 : 7 * 32 + 2]),
	.PTSEL( rw_data[7 * 32 + 5 : 7 * 32 + 4]),
	.VG(    rw_data[7 * 32 + 6 : 7 * 32 + 6]),
	.VS(    rw_data[7 * 32 + 7 : 7 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(iv_wp_vtp_nd_resp_data),                
  .wr_en(i_wp_vtp_nd_resp_wr_en),            
  .rd_en(w_wp_vtp_nd_resp_rd_en),            
  .dout(wv_wp_vtp_nd_resp_dout),              
  .empty(w_wp_vtp_nd_resp_empty),            
  .prog_full(o_wp_vtp_nd_resp_prog_full),
  .full()
  
);

wire                w_wp_vtp_nd_download_empty;
wire                w_wp_vtp_nd_download_rd_en;
wire    [255:0]     wv_wp_vtp_nd_download_dout;
SyncFIFO_256w_32d WP_VTP_ND_DOWNLOAD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[8 * 32 + 1 : 8 * 32 + 0]),
	.WTSEL( rw_data[8 * 32 + 3 : 8 * 32 + 2]),
	.PTSEL( rw_data[8 * 32 + 5 : 8 * 32 + 4]),
	.VG(    rw_data[8 * 32 + 6 : 8 * 32 + 6]),
	.VS(    rw_data[8 * 32 + 7 : 8 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(iv_wp_vtp_nd_download_data),                
  .wr_en(i_wp_vtp_nd_download_wr_en),            
  .rd_en(w_wp_vtp_nd_download_rd_en),            
  .dout(wv_wp_vtp_nd_download_dout),              
  .empty(w_wp_vtp_nd_download_empty),            
  .prog_full(o_wp_vtp_nd_download_prog_full),
  .full()
  
);

//Channel 4 for RequesterTransControl, upload Completion Event
wire                w_rtc_vtp_cmd_wr_en;
wire                w_rtc_vtp_cmd_prog_full;
wire    [255:0]     wv_rtc_vtp_cmd_din;
SyncFIFO_256w_32d RTC_VTP_CMD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[9 * 32 + 1 : 9 * 32 + 0]),
	.WTSEL( rw_data[9 * 32 + 3 : 9 * 32 + 2]),
	.PTSEL( rw_data[9 * 32 + 5 : 9 * 32 + 4]),
	.VG(    rw_data[9 * 32 + 6 : 9 * 32 + 6]),
	.VS(    rw_data[9 * 32 + 7 : 9 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_rtc_vtp_cmd_din),                
  .wr_en(w_rtc_vtp_cmd_wr_en),            
  .rd_en(i_rtc_vtp_cmd_rd_en),            
  .dout(ov_rtc_vtp_cmd_data),              
  .empty(o_rtc_vtp_cmd_empty),            
  .prog_full(w_rtc_vtp_cmd_prog_full),
  .full()
  
);

wire                w_rtc_vtp_resp_empty;
wire                w_rtc_vtp_resp_rd_en;
wire    [7:0]       wv_rtc_vtp_resp_dout;
SyncFIFO_8w_16d RTC_VTP_RESP_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[10 * 32 + 1 : 10 * 32 + 0]),
	.WTSEL( rw_data[10 * 32 + 3 : 10 * 32 + 2]),
	.PTSEL( rw_data[10 * 32 + 5 : 10 * 32 + 4]),
	.VG(    rw_data[10 * 32 + 6 : 10 * 32 + 6]),
	.VS(    rw_data[10 * 32 + 7 : 10 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(iv_rtc_vtp_resp_data),                
  .wr_en(i_rtc_vtp_resp_wr_en),            
  .rd_en(w_rtc_vtp_resp_rd_en),            
  .dout(wv_rtc_vtp_resp_dout),              
  .empty(w_rtc_vtp_resp_empty),            
  .prog_full(o_rtc_vtp_resp_prog_full),
  .full()
  
);

wire                w_rtc_vtp_upload_wr_en;
wire                w_rtc_vtp_upload_prog_full;
wire    [255:0]     wv_rtc_vtp_upload_din;
SyncFIFO_256w_32d RTC_VTP_UPLOAD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[11 * 32 + 1 : 11 * 32 + 0]),
	.WTSEL( rw_data[11 * 32 + 3 : 11 * 32 + 2]),
	.PTSEL( rw_data[11 * 32 + 5 : 11 * 32 + 4]),
	.VG(    rw_data[11 * 32 + 6 : 11 * 32 + 6]),
	.VS(    rw_data[11 * 32 + 7 : 11 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_rtc_vtp_upload_din),                
  .wr_en(w_rtc_vtp_upload_wr_en),            
  .rd_en(i_rtc_vtp_upload_rd_en),            
  .dout(ov_rtc_vtp_upload_data),              
  .empty(o_rtc_vtp_upload_empty),            
  .prog_full(w_rtc_vtp_upload_prog_full),
  .full()
  
);

//Channel 5 for RequesterRecvControl, upload RDMA Read Response
wire                w_rrc_vtp_cmd_wr_en;
wire                w_rrc_vtp_cmd_prog_full;
wire    [255:0]     wv_rrc_vtp_cmd_din;
SyncFIFO_256w_32d RRC_VTP_CMD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[12 * 32 + 1 : 12 * 32 + 0]),
	.WTSEL( rw_data[12 * 32 + 3 : 12 * 32 + 2]),
	.PTSEL( rw_data[12 * 32 + 5 : 12 * 32 + 4]),
	.VG(    rw_data[12 * 32 + 6 : 12 * 32 + 6]),
	.VS(    rw_data[12 * 32 + 7 : 12 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_rrc_vtp_cmd_din),                
  .wr_en(w_rrc_vtp_cmd_wr_en),            
  .rd_en(i_rrc_vtp_cmd_rd_en),            
  .dout(ov_rrc_vtp_cmd_data),              
  .empty(o_rrc_vtp_cmd_empty),            
  .prog_full(w_rrc_vtp_cmd_prog_full),
  .full()
  
);

wire                w_rrc_vtp_resp_empty;
wire                w_rrc_vtp_resp_rd_en;
wire    [7:0]       wv_rrc_vtp_resp_dout;
SyncFIFO_8w_16d RRC_VTP_RESP_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[13 * 32 + 1 : 13 * 32 + 0]),
	.WTSEL( rw_data[13 * 32 + 3 : 13 * 32 + 2]),
	.PTSEL( rw_data[13 * 32 + 5 : 13 * 32 + 4]),
	.VG(    rw_data[13 * 32 + 6 : 13 * 32 + 6]),
	.VS(    rw_data[13 * 32 + 7 : 13 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(iv_rrc_vtp_resp_data),                
  .wr_en(i_rrc_vtp_resp_wr_en),            
  .rd_en(w_rrc_vtp_resp_rd_en),            
  .dout(wv_rrc_vtp_resp_dout),              
  .empty(w_rrc_vtp_resp_empty),            
  .prog_full(o_rrc_vtp_resp_prog_full),
  .full()
  
);

wire                w_rrc_vtp_upload_wr_en;
wire                w_rrc_vtp_upload_prog_full;
wire    [255:0]     wv_rrc_vtp_upload_din;
SyncFIFO_256w_32d RRC_VTP_UPLOAD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[14 * 32 + 1 : 14 * 32 + 0]),
	.WTSEL( rw_data[14 * 32 + 3 : 14 * 32 + 2]),
	.PTSEL( rw_data[14 * 32 + 5 : 14 * 32 + 4]),
	.VG(    rw_data[14 * 32 + 6 : 14 * 32 + 6]),
	.VS(    rw_data[14 * 32 + 7 : 14 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_rrc_vtp_upload_din),                
  .wr_en(w_rrc_vtp_upload_wr_en),            
  .rd_en(i_rrc_vtp_upload_rd_en),            
  .dout(ov_rrc_vtp_upload_data),              
  .empty(o_rrc_vtp_upload_empty),            
  .prog_full(w_rrc_vtp_upload_prog_full),
  .full()
  
);

//Channel 6 for ExecutionEngine, download RQ WQE
wire                w_rwm_vtp_cmd_wr_en;
wire                w_rwm_vtp_cmd_prog_full;
wire    [255:0]     wv_rwm_vtp_cmd_din;
SyncFIFO_256w_32d RWM_VTP_CMD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[15 * 32 + 1 : 15 * 32 + 0]),
	.WTSEL( rw_data[15 * 32 + 3 : 15 * 32 + 2]),
	.PTSEL( rw_data[15 * 32 + 5 : 15 * 32 + 4]),
	.VG(    rw_data[15 * 32 + 6 : 15 * 32 + 6]),
	.VS(    rw_data[15 * 32 + 7 : 15 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_rwm_vtp_cmd_din),                
  .wr_en(w_rwm_vtp_cmd_wr_en),            
  .rd_en(i_rwm_vtp_cmd_rd_en),            
  .dout(ov_rwm_vtp_cmd_data),              
  .empty(o_rwm_vtp_cmd_empty),            
  .prog_full(w_rwm_vtp_cmd_prog_full),
  .full()
  
);

wire                w_rwm_vtp_resp_empty;
wire                w_rwm_vtp_resp_rd_en;
wire    [7:0]       wv_rwm_vtp_resp_dout;
SyncFIFO_8w_16d RWM_VTP_RESP_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[16 * 32 + 1 : 16 * 32 + 0]),
	.WTSEL( rw_data[16 * 32 + 3 : 16 * 32 + 2]),
	.PTSEL( rw_data[16 * 32 + 5 : 16 * 32 + 4]),
	.VG(    rw_data[16 * 32 + 6 : 16 * 32 + 6]),
	.VS(    rw_data[16 * 32 + 7 : 16 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(iv_rwm_vtp_resp_data),                
  .wr_en(i_rwm_vtp_resp_wr_en),            
  .rd_en(w_rwm_vtp_resp_rd_en),            
  .dout(wv_rwm_vtp_resp_dout),              
  .empty(w_rwm_vtp_resp_empty),            
  .prog_full(o_rwm_vtp_resp_prog_full),
  .full()
  
);

wire 	[255:0]		wv_rwm_vtp_download_din;
wire                w_rwm_vtp_download_rd_en;
wire                w_rwm_vtp_download_empty;
wire    [127:0]     wv_rwm_vtp_download_dout;
assign wv_rwm_vtp_download_din = {iv_rwm_vtp_download_data[127:0], iv_rwm_vtp_download_data[255:128]}; 
SyncFIFO_256wTo128w_64d RWM_VTP_DOWNLOAD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[17 * 32 + 1 : 17 * 32 + 0]),
	.WTSEL( rw_data[17 * 32 + 3 : 17 * 32 + 2]),
	.PTSEL( rw_data[17 * 32 + 5 : 17 * 32 + 4]),
	.VG(    rw_data[17 * 32 + 6 : 17 * 32 + 6]),
	.VS(    rw_data[17 * 32 + 7 : 17 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_rwm_vtp_download_din),                
  .wr_en(i_rwm_vtp_download_wr_en),            
  .rd_en(w_rwm_vtp_download_rd_en),            
  .dout(wv_rwm_vtp_download_dout),              
  .empty(w_rwm_vtp_download_empty),            
  .prog_full(o_rwm_vtp_download_prog_full),
  .full()

);

//Channel 7 for ExecutionEngine, upload Send/Write Payload and download Read Payload
wire                w_ee_vtp_cmd_wr_en;
wire                w_ee_vtp_cmd_prog_full;
wire    [255:0]     wv_ee_vtp_cmd_din;
SyncFIFO_256w_32d EE_VTP_CMD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[18 * 32 + 1 : 18 * 32 + 0]),
	.WTSEL( rw_data[18 * 32 + 3 : 18 * 32 + 2]),
	.PTSEL( rw_data[18 * 32 + 5 : 18 * 32 + 4]),
	.VG(    rw_data[18 * 32 + 6 : 18 * 32 + 6]),
	.VS(    rw_data[18 * 32 + 7 : 18 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_ee_vtp_cmd_din),                
  .wr_en(w_ee_vtp_cmd_wr_en),            
  .rd_en(i_ee_vtp_cmd_rd_en),            
  .dout(ov_ee_vtp_cmd_data),              
  .empty(o_ee_vtp_cmd_empty),            
  .prog_full(w_ee_vtp_cmd_prog_full),
  .full()
  
);

wire                w_ee_vtp_resp_empty;
wire                w_ee_vtp_resp_rd_en;
wire    [7:0]       wv_ee_vtp_resp_dout;
SyncFIFO_8w_16d EE_VTP_RESP_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[19 * 32 + 1 : 19 * 32 + 0]),
	.WTSEL( rw_data[19 * 32 + 3 : 19 * 32 + 2]),
	.PTSEL( rw_data[19 * 32 + 5 : 19 * 32 + 4]),
	.VG(    rw_data[19 * 32 + 6 : 19 * 32 + 6]),
	.VS(    rw_data[19 * 32 + 7 : 19 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(iv_ee_vtp_resp_data),                
  .wr_en(i_ee_vtp_resp_wr_en),            
  .rd_en(w_ee_vtp_resp_rd_en),            
  .dout(wv_ee_vtp_resp_dout),              
  .empty(w_ee_vtp_resp_empty),            
  .prog_full(o_ee_vtp_resp_prog_full),
  .full()
  
);

wire                w_ee_vtp_upload_wr_en;
wire                w_ee_vtp_upload_prog_full;
wire    [255:0]     wv_ee_vtp_upload_din;
SyncFIFO_256w_32d EE_VTP_UPLOAD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[20 * 32 + 1 : 20 * 32 + 0]),
	.WTSEL( rw_data[20 * 32 + 3 : 20 * 32 + 2]),
	.PTSEL( rw_data[20 * 32 + 5 : 20 * 32 + 4]),
	.VG(    rw_data[20 * 32 + 6 : 20 * 32 + 6]),
	.VS(    rw_data[20 * 32 + 7 : 20 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_ee_vtp_upload_din),                
  .wr_en(w_ee_vtp_upload_wr_en),            
  .rd_en(i_ee_vtp_upload_rd_en),            
  .dout(ov_ee_vtp_upload_data),              
  .empty(o_ee_vtp_upload_empty),            
  .prog_full(w_ee_vtp_upload_prog_full),
  .full()
  
);

wire                w_ee_vtp_download_rd_en;
wire                w_ee_vtp_download_empty;
wire    [255:0]     wv_ee_vtp_download_dout;
SyncFIFO_256w_32d EE_VTP_DOWNLOAD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[21 * 32 + 1 : 21 * 32 + 0]),
	.WTSEL( rw_data[21 * 32 + 3 : 21 * 32 + 2]),
	.PTSEL( rw_data[21 * 32 + 5 : 21 * 32 + 4]),
	.VG(    rw_data[21 * 32 + 6 : 21 * 32 + 6]),
	.VS(    rw_data[21 * 32 + 7 : 21 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(iv_ee_vtp_download_data),                
  .wr_en(i_ee_vtp_download_wr_en),            
  .rd_en(w_ee_vtp_download_rd_en),            
  .dout(wv_ee_vtp_download_dout),              
  .empty(w_ee_vtp_download_empty),            
  .prog_full(o_ee_vtp_download_prog_full),
  .full()
  
);

/*---------------------------------------- Part 2: CxtMgt Interface with RDMA Engine ------------------------------------*/
    //Channel 1 for DoorbellProcessing, read cxt req, response ctx req, response ctx info, no write ctx req
wire                w_db_cxtmgt_cmd_wr_en;
wire                w_db_cxtmgt_cmd_prog_full;
wire    [127:0]     wv_db_cxtmgt_cmd_din;
CmdResp_FIFO_128w_4d DB_CXTMGT_CMD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[22 * 32 + 1 : 22 * 32 + 0]),
	.WTSEL( rw_data[22 * 32 + 3 : 22 * 32 + 2]),
	.PTSEL( rw_data[22 * 32 + 5 : 22 * 32 + 4]),
	.VG(    rw_data[22 * 32 + 6 : 22 * 32 + 6]),
	.VS(    rw_data[22 * 32 + 7 : 22 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_db_cxtmgt_cmd_din),                
  .wr_en(w_db_cxtmgt_cmd_wr_en),            
  .rd_en(i_db_cxtmgt_cmd_rd_en),            
  .dout(ov_db_cxtmgt_cmd_data),              
  .empty(o_db_cxtmgt_cmd_empty),            
  .prog_full(w_db_cxtmgt_cmd_prog_full),
  .full()
  
);

wire                w_db_cxtmgt_resp_empty;
wire                w_db_cxtmgt_resp_rd_en;
wire    [127:0]     wv_db_cxtmgt_resp_dout;
CmdResp_FIFO_128w_4d DB_CXTMGT_RESP_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[23 * 32 + 1 : 23 * 32 + 0]),
	.WTSEL( rw_data[23 * 32 + 3 : 23 * 32 + 2]),
	.PTSEL( rw_data[23 * 32 + 5 : 23 * 32 + 4]),
	.VG(    rw_data[23 * 32 + 6 : 23 * 32 + 6]),
	.VS(    rw_data[23 * 32 + 7 : 23 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(iv_db_cxtmgt_resp_data),                
  .wr_en(i_db_cxtmgt_resp_wr_en),            
  .rd_en(w_db_cxtmgt_resp_rd_en),            
  .dout(wv_db_cxtmgt_resp_dout),              
  .empty(w_db_cxtmgt_resp_empty),            
  .prog_full(o_db_cxtmgt_resp_prog_full),
  .full()
  
);

wire                w_db_cxtmgt_cxt_download_empty;
wire                w_db_cxtmgt_cxt_download_rd_en;
wire    [255:0]     wv_db_cxtmgt_cxt_download_dout;
SyncFIFO_256w_32d DB_CXTMGT_CXT_DOWNLOAD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[24 * 32 + 1 : 24 * 32 + 0]),
	.WTSEL( rw_data[24 * 32 + 3 : 24 * 32 + 2]),
	.PTSEL( rw_data[24 * 32 + 5 : 24 * 32 + 4]),
	.VG(    rw_data[24 * 32 + 6 : 24 * 32 + 6]),
	.VS(    rw_data[24 * 32 + 7 : 24 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(iv_db_cxtmgt_cxt_download_data),                
  .wr_en(i_db_cxtmgt_cxt_download_wr_en),            
  .rd_en(w_db_cxtmgt_cxt_download_rd_en),            
  .dout(wv_db_cxtmgt_cxt_download_dout),              
  .empty(w_db_cxtmgt_cxt_download_empty),            
  .prog_full(o_db_cxtmgt_cxt_download_prog_full),
  .full()
  
);

    //Channel 2 for WQEParser, read cxt req, response ctx req, response ctx info, no write ctx req
wire                w_wp_cxtmgt_cmd_wr_en;
wire                w_wp_cxtmgt_cmd_prog_full;
wire    [127:0]     wv_wp_cxtmgt_cmd_din;
CmdResp_FIFO_128w_4d WP_CXTMGT_CMD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[25 * 32 + 1 : 25 * 32 + 0]),
	.WTSEL( rw_data[25 * 32 + 3 : 25 * 32 + 2]),
	.PTSEL( rw_data[25 * 32 + 5 : 25 * 32 + 4]),
	.VG(    rw_data[25 * 32 + 6 : 25 * 32 + 6]),
	.VS(    rw_data[25 * 32 + 7 : 25 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_wp_cxtmgt_cmd_din),                
  .wr_en(w_wp_cxtmgt_cmd_wr_en),            
  .rd_en(i_wp_cxtmgt_cmd_rd_en),            
  .dout(ov_wp_cxtmgt_cmd_data),              
  .empty(o_wp_cxtmgt_cmd_empty),            
  .prog_full(w_wp_cxtmgt_cmd_prog_full),
  .full()
  
);

wire                w_wp_cxtmgt_resp_empty;
wire                w_wp_cxtmgt_resp_rd_en;
wire    [127:0]     wv_wp_cxtmgt_resp_dout;
CmdResp_FIFO_128w_4d WP_CXTMGT_RESP_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[26 * 32 + 1 : 26 * 32 + 0]),
	.WTSEL( rw_data[26 * 32 + 3 : 26 * 32 + 2]),
	.PTSEL( rw_data[26 * 32 + 5 : 26 * 32 + 4]),
	.VG(    rw_data[26 * 32 + 6 : 26 * 32 + 6]),
	.VS(    rw_data[26 * 32 + 7 : 26 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(iv_wp_cxtmgt_resp_data),                
  .wr_en(i_wp_cxtmgt_resp_wr_en),            
  .rd_en(w_wp_cxtmgt_resp_rd_en),            
  .dout(wv_wp_cxtmgt_resp_dout),              
  .empty(w_wp_cxtmgt_resp_empty),            
  .prog_full(o_wp_cxtmgt_resp_prog_full),
  .full()
  
);

wire                w_wp_cxtmgt_cxt_download_empty;
wire                w_wp_cxtmgt_cxt_download_rd_en;
wire    [127:0]     wv_wp_cxtmgt_cxt_download_dout;
CmdResp_FIFO_128w_4d WP_CXTMGT_DOWNLOAD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[27 * 32 + 1 : 27 * 32 + 0]),
	.WTSEL( rw_data[27 * 32 + 3 : 27 * 32 + 2]),
	.PTSEL( rw_data[27 * 32 + 5 : 27 * 32 + 4]),
	.VG(    rw_data[27 * 32 + 6 : 27 * 32 + 6]),
	.VS(    rw_data[27 * 32 + 7 : 27 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(iv_wp_cxtmgt_cxt_download_data),                
  .wr_en(i_wp_cxtmgt_cxt_download_wr_en),            
  .rd_en(w_wp_cxtmgt_cxt_download_rd_en),            
  .dout(wv_wp_cxtmgt_cxt_download_dout),              
  .empty(w_wp_cxtmgt_cxt_download_empty),            
  .prog_full(o_wp_cxtmgt_cxt_download_prog_full),
  .full()
  
);

    //Channel 3 for RequesterTransControl, read cxt req, response ctx req, response ctx info, write ctx req
wire                w_rtc_cxtmgt_cmd_wr_en;
wire                w_rtc_cxtmgt_cmd_prog_full;
wire    [127:0]     wv_rtc_cxtmgt_cmd_din;
CmdResp_FIFO_128w_4d RTC_CXTMGT_CMD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[28 * 32 + 1 : 28 * 32 + 0]),
	.WTSEL( rw_data[28 * 32 + 3 : 28 * 32 + 2]),
	.PTSEL( rw_data[28 * 32 + 5 : 28 * 32 + 4]),
	.VG(    rw_data[28 * 32 + 6 : 28 * 32 + 6]),
	.VS(    rw_data[28 * 32 + 7 : 28 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_rtc_cxtmgt_cmd_din),                
  .wr_en(w_rtc_cxtmgt_cmd_wr_en),            
  .rd_en(i_rtc_cxtmgt_cmd_rd_en),            
  .dout(ov_rtc_cxtmgt_cmd_data),              
  .empty(o_rtc_cxtmgt_cmd_empty),            
  .prog_full(w_rtc_cxtmgt_cmd_prog_full),
  .full()
  
);

wire                w_rtc_cxtmgt_resp_empty;
wire                w_rtc_cxtmgt_resp_rd_en;
wire    [127:0]     wv_rtc_cxtmgt_resp_dout;
CmdResp_FIFO_128w_4d RTC_CXTMGT_RESP_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[29 * 32 + 1 : 29 * 32 + 0]),
	.WTSEL( rw_data[29 * 32 + 3 : 29 * 32 + 2]),
	.PTSEL( rw_data[29 * 32 + 5 : 29 * 32 + 4]),
	.VG(    rw_data[29 * 32 + 6 : 29 * 32 + 6]),
	.VS(    rw_data[29 * 32 + 7 : 29 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(iv_rtc_cxtmgt_resp_data),                
  .wr_en(i_rtc_cxtmgt_resp_wr_en),            
  .rd_en(w_rtc_cxtmgt_resp_rd_en),            
  .dout(wv_rtc_cxtmgt_resp_dout),              
  .empty(w_rtc_cxtmgt_resp_empty),            
  .prog_full(o_rtc_cxtmgt_resp_prog_full),
  .full()
  
);

wire                w_rtc_cxtmgt_cxt_download_empty;
wire                w_rtc_cxtmgt_cxt_download_rd_en;
wire    [191:0]     wv_rtc_cxtmgt_cxt_download_dout;
CmdResp_FIFO_192w_4d RTC_CXTMGT_DOWNLOAD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[30 * 32 + 1 : 30 * 32 + 0]),
	.WTSEL( rw_data[30 * 32 + 3 : 30 * 32 + 2]),
	.PTSEL( rw_data[30 * 32 + 5 : 30 * 32 + 4]),
	.VG(    rw_data[30 * 32 + 6 : 30 * 32 + 6]),
	.VS(    rw_data[30 * 32 + 7 : 30 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(iv_rtc_cxtmgt_cxt_download_data),                
  .wr_en(i_rtc_cxtmgt_cxt_download_wr_en),            
  .rd_en(w_rtc_cxtmgt_cxt_download_rd_en),            
  .dout(wv_rtc_cxtmgt_cxt_download_dout),              
  .empty(w_rtc_cxtmgt_cxt_download_empty),            
  .prog_full(o_rtc_cxtmgt_cxt_download_prog_full),
  .full()
  
);

wire                w_rtc_cxtmgt_cxt_upload_prog_full;
wire                w_rtc_cxtmgt_cxt_upload_wr_en;
wire    [127:0]     wv_rtc_cxtmgt_cxt_upload_din;
CmdResp_FIFO_128w_4d RTC_CXTMGT_UPLOAD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[31 * 32 + 1 : 31 * 32 + 0]),
	.WTSEL( rw_data[31 * 32 + 3 : 31 * 32 + 2]),
	.PTSEL( rw_data[31 * 32 + 5 : 31 * 32 + 4]),
	.VG(    rw_data[31 * 32 + 6 : 31 * 32 + 6]),
	.VS(    rw_data[31 * 32 + 7 : 31 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_rtc_cxtmgt_cxt_upload_din),                
  .wr_en(w_rtc_cxtmgt_cxt_upload_wr_en),            
  .rd_en(i_rtc_cxtmgt_cxt_upload_rd_en),            
  .dout(ov_rtc_cxtmgt_cxt_upload_data),              
  .empty(o_rtc_cxtmgt_cxt_upload_empty),            
  .prog_full(w_rtc_cxtmgt_cxt_upload_prog_full),
  .full()
  
);

    //Channel 4 for RequesterRecvContro, read/write cxt req, response ctx req, response ctx info,  write ctx info
wire                w_rrc_cxtmgt_cmd_wr_en;
wire                w_rrc_cxtmgt_cmd_prog_full;
wire    [127:0]     wv_rrc_cxtmgt_cmd_din;
CmdResp_FIFO_128w_4d RRC_CXTMGT_CMD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[32 * 32 + 1 : 32 * 32 + 0]),
	.WTSEL( rw_data[32 * 32 + 3 : 32 * 32 + 2]),
	.PTSEL( rw_data[32 * 32 + 5 : 32 * 32 + 4]),
	.VG(    rw_data[32 * 32 + 6 : 32 * 32 + 6]),
	.VS(    rw_data[32 * 32 + 7 : 32 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_rrc_cxtmgt_cmd_din),                
  .wr_en(w_rrc_cxtmgt_cmd_wr_en),            
  .rd_en(i_rrc_cxtmgt_cmd_rd_en),            
  .dout(ov_rrc_cxtmgt_cmd_data),              
  .empty(o_rrc_cxtmgt_cmd_empty),            
  .prog_full(w_rrc_cxtmgt_cmd_prog_full),
  .full()
  
);

wire                w_rrc_cxtmgt_resp_empty;
wire                w_rrc_cxtmgt_resp_rd_en;
wire    [127:0]     wv_rrc_cxtmgt_resp_dout;
CmdResp_FIFO_128w_4d RRC_CXTMGT_RESP_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[33 * 32 + 1 : 33 * 32 + 0]),
	.WTSEL( rw_data[33 * 32 + 3 : 33 * 32 + 2]),
	.PTSEL( rw_data[33 * 32 + 5 : 33 * 32 + 4]),
	.VG(    rw_data[33 * 32 + 6 : 33 * 32 + 6]),
	.VS(    rw_data[33 * 32 + 7 : 33 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(iv_rrc_cxtmgt_resp_data),                
  .wr_en(i_rrc_cxtmgt_resp_wr_en),            
  .rd_en(w_rrc_cxtmgt_resp_rd_en),            
  .dout(wv_rrc_cxtmgt_resp_dout),              
  .empty(w_rrc_cxtmgt_resp_empty),            
  .prog_full(o_rrc_cxtmgt_resp_prog_full),
  .full()
  
);

wire                w_rrc_cxtmgt_cxt_download_empty;
wire                w_rrc_cxtmgt_cxt_download_rd_en;
wire    [255:0]     wv_rrc_cxtmgt_cxt_download_dout;
CmdResp_FIFO_256w_4d RRC_CXTMGT_DOWNLOAD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[34 * 32 + 1 : 34 * 32 + 0]),
	.WTSEL( rw_data[34 * 32 + 3 : 34 * 32 + 2]),
	.PTSEL( rw_data[34 * 32 + 5 : 34 * 32 + 4]),
	.VG(    rw_data[34 * 32 + 6 : 34 * 32 + 6]),
	.VS(    rw_data[34 * 32 + 7 : 34 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(iv_rrc_cxtmgt_cxt_download_data),                
  .wr_en(i_rrc_cxtmgt_cxt_download_wr_en),            
  .rd_en(w_rrc_cxtmgt_cxt_download_rd_en),            
  .dout(wv_rrc_cxtmgt_cxt_download_dout),              
  .empty(w_rrc_cxtmgt_cxt_download_empty),            
  .prog_full(o_rrc_cxtmgt_cxt_download_prog_full),
  .full()
  
);

wire                w_rrc_cxtmgt_cxt_upload_prog_full;
wire                w_rrc_cxtmgt_cxt_upload_wr_en;
wire    [127:0]     wv_rrc_cxtmgt_cxt_upload_din;
CmdResp_FIFO_128w_4d RRC_CXTMGT_UPLOAD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[35 * 32 + 1 : 35 * 32 + 0]),
	.WTSEL( rw_data[35 * 32 + 3 : 35 * 32 + 2]),
	.PTSEL( rw_data[35 * 32 + 5 : 35 * 32 + 4]),
	.VG(    rw_data[35 * 32 + 6 : 35 * 32 + 6]),
	.VS(    rw_data[35 * 32 + 7 : 35 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_rrc_cxtmgt_cxt_upload_din),                
  .wr_en(w_rrc_cxtmgt_cxt_upload_wr_en),            
  .rd_en(i_rrc_cxtmgt_cxt_upload_rd_en),            
  .dout(ov_rrc_cxtmgt_cxt_upload_data),              
  .empty(o_rrc_cxtmgt_cxt_upload_empty),            
  .prog_full(w_rrc_cxtmgt_cxt_upload_prog_full),
  .full()
  
);
    //Channel 5 for ExecutionEngine, read/write cxt req, response ctx req, response ctx info,  write ctx info
wire                w_ee_cxtmgt_cmd_wr_en;
wire                w_ee_cxtmgt_cmd_prog_full;
wire    [127:0]     wv_ee_cxtmgt_cmd_din;
CmdResp_FIFO_128w_4d EE_CXTMGT_CMD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[36 * 32 + 1 : 36 * 32 + 0]),
	.WTSEL( rw_data[36 * 32 + 3 : 36 * 32 + 2]),
	.PTSEL( rw_data[36 * 32 + 5 : 36 * 32 + 4]),
	.VG(    rw_data[36 * 32 + 6 : 36 * 32 + 6]),
	.VS(    rw_data[36 * 32 + 7 : 36 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_ee_cxtmgt_cmd_din),                
  .wr_en(w_ee_cxtmgt_cmd_wr_en),            
  .rd_en(i_ee_cxtmgt_cmd_rd_en),            
  .dout(ov_ee_cxtmgt_cmd_data),              
  .empty(o_ee_cxtmgt_cmd_empty),            
  .prog_full(w_ee_cxtmgt_cmd_prog_full),
  .full()
  
);

wire                w_ee_cxtmgt_resp_empty;
wire                w_ee_cxtmgt_resp_rd_en;
wire    [127:0]     wv_ee_cxtmgt_resp_dout;
CmdResp_FIFO_128w_4d EE_CXTMGT_RESP_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[37 * 32 + 1 : 37 * 32 + 0]),
	.WTSEL( rw_data[37 * 32 + 3 : 37 * 32 + 2]),
	.PTSEL( rw_data[37 * 32 + 5 : 37 * 32 + 4]),
	.VG(    rw_data[37 * 32 + 6 : 37 * 32 + 6]),
	.VS(    rw_data[37 * 32 + 7 : 37 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(iv_ee_cxtmgt_resp_data),                
  .wr_en(i_ee_cxtmgt_resp_wr_en),            
  .rd_en(w_ee_cxtmgt_resp_rd_en),            
  .dout(wv_ee_cxtmgt_resp_dout),              
  .empty(w_ee_cxtmgt_resp_empty),            
  .prog_full(o_ee_cxtmgt_resp_prog_full),
  .full()
  
);

wire                w_ee_cxtmgt_cxt_download_empty;
wire                w_ee_cxtmgt_cxt_download_rd_en;
wire    [319:0]     wv_ee_cxtmgt_cxt_download_dout;
CmdResp_FIFO_320w_4d EE_CXTMGT_DOWNLOAD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[38 * 32 + 1 : 38 * 32 + 0]),
	.WTSEL( rw_data[38 * 32 + 3 : 38 * 32 + 2]),
	.PTSEL( rw_data[38 * 32 + 5 : 38 * 32 + 4]),
	.VG(    rw_data[38 * 32 + 6 : 38 * 32 + 6]),
	.VS(    rw_data[38 * 32 + 7 : 38 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(iv_ee_cxtmgt_cxt_download_data),                
  .wr_en(i_ee_cxtmgt_cxt_download_wr_en),            
  .rd_en(w_ee_cxtmgt_cxt_download_rd_en),            
  .dout(wv_ee_cxtmgt_cxt_download_dout),              
  .empty(w_ee_cxtmgt_cxt_download_empty),            
  .prog_full(o_ee_cxtmgt_cxt_download_prog_full),
  .full()
  
);

wire                w_ee_cxtmgt_cxt_upload_prog_full;
wire                w_ee_cxtmgt_cxt_upload_wr_en;
wire    [127:0]     wv_ee_cxtmgt_cxt_upload_din;
CmdResp_FIFO_128w_4d EE_CXTMGT_UPLOAD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[39 * 32 + 1 : 39 * 32 + 0]),
	.WTSEL( rw_data[39 * 32 + 3 : 39 * 32 + 2]),
	.PTSEL( rw_data[39 * 32 + 5 : 39 * 32 + 4]),
	.VG(    rw_data[39 * 32 + 6 : 39 * 32 + 6]),
	.VS(    rw_data[39 * 32 + 7 : 39 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_ee_cxtmgt_cxt_upload_din),                
  .wr_en(w_ee_cxtmgt_cxt_upload_wr_en),            
  .rd_en(i_ee_cxtmgt_cxt_upload_rd_en),            
  .dout(ov_ee_cxtmgt_cxt_upload_data),              
  .empty(o_ee_cxtmgt_cxt_upload_empty),            
  .prog_full(w_ee_cxtmgt_cxt_upload_prog_full),
  .full()
  
);

//Channel 6 for FrameEncap
wire                w_fe_cxtmgt_cmd_wr_en;
wire                w_fe_cxtmgt_cmd_prog_full;
wire    [127:0]     wv_fe_cxtmgt_cmd_din;
CmdResp_FIFO_128w_4d FE_CXTMGT_CMD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[40 * 32 + 1 : 40 * 32 + 0]),
	.WTSEL( rw_data[40 * 32 + 3 : 40 * 32 + 2]),
	.PTSEL( rw_data[40 * 32 + 5 : 40 * 32 + 4]),
	.VG(    rw_data[40 * 32 + 6 : 40 * 32 + 6]),
	.VS(    rw_data[40 * 32 + 7 : 40 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_fe_cxtmgt_cmd_din),                
  .wr_en(w_fe_cxtmgt_cmd_wr_en),            
  .rd_en(i_fe_cxtmgt_cmd_rd_en),            
  .dout(ov_fe_cxtmgt_cmd_data),              
  .empty(o_fe_cxtmgt_cmd_empty),            
  .prog_full(w_fe_cxtmgt_cmd_prog_full),
  .full()
  
);

wire                w_fe_cxtmgt_resp_empty;
wire                w_fe_cxtmgt_resp_rd_en;
wire    [127:0]     wv_fe_cxtmgt_resp_dout;
CmdResp_FIFO_128w_4d FE_CXTMGT_RESP_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[41 * 32 + 1 : 41 * 32 + 0]),
	.WTSEL( rw_data[41 * 32 + 3 : 41 * 32 + 2]),
	.PTSEL( rw_data[41 * 32 + 5 : 41 * 32 + 4]),
	.VG(    rw_data[41 * 32 + 6 : 41 * 32 + 6]),
	.VS(    rw_data[41 * 32 + 7 : 41 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(iv_fe_cxtmgt_resp_data),                
  .wr_en(i_fe_cxtmgt_resp_wr_en),            
  .rd_en(w_fe_cxtmgt_resp_rd_en),            
  .dout(wv_fe_cxtmgt_resp_dout),              
  .empty(w_fe_cxtmgt_resp_empty),            
  .prog_full(o_fe_cxtmgt_resp_prog_full),
  .full()
  
);

wire                w_fe_cxtmgt_cxt_download_empty;
wire                w_fe_cxtmgt_cxt_download_rd_en;
wire    [255:0]     wv_fe_cxtmgt_cxt_download_dout;
CmdResp_FIFO_256w_4d FE_CXTMGT_DOWNLOAD_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[42 * 32 + 1 : 42 * 32 + 0]),
	.WTSEL( rw_data[42 * 32 + 3 : 42 * 32 + 2]),
	.PTSEL( rw_data[42 * 32 + 5 : 42 * 32 + 4]),
	.VG(    rw_data[42 * 32 + 6 : 42 * 32 + 6]),
	.VS(    rw_data[42 * 32 + 7 : 42 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(iv_fe_cxtmgt_cxt_download_data),                
  .wr_en(i_fe_cxtmgt_cxt_download_wr_en),            
  .rd_en(w_fe_cxtmgt_cxt_download_rd_en),            
  .dout(wv_fe_cxtmgt_cxt_download_dout),              
  .empty(w_fe_cxtmgt_cxt_download_empty),            
  .prog_full(o_fe_cxtmgt_cxt_download_prog_full),
  .full()
  
);

/*---------------------------------------- Part 3: PIO ------------------------------------*/
wire                w_pio_empty;
wire                w_pio_rd_en;
wire    [63:0]      wv_pio_dout;
SyncFIFO_64w_32d PIO_FIFO(
  `ifdef CHIP_VERSION
	.RTSEL( rw_data[43 * 32 + 1 : 43 * 32 + 0]),
	.WTSEL( rw_data[43 * 32 + 3 : 43 * 32 + 2]),
	.PTSEL( rw_data[43 * 32 + 5 : 43 * 32 + 4]),
	.VG(    rw_data[43 * 32 + 6 : 43 * 32 + 6]),
	.VS(    rw_data[43 * 32 + 7 : 43 * 32 + 7]),
  
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(iv_pio_data),                
  .wr_en(i_pio_wr_en),            
  .rd_en(w_pio_rd_en),            
  .dout(wv_pio_dout),              
  .empty(w_pio_empty),            
  .prog_full(o_pio_prog_full),
  .full()
  
);

/*---------------------------------------- Part 4: Link Layer ------------------------------------*/
wire                w_ingress_empty;
wire                w_ingress_rd_en;
wire    [255:0]     wv_ingress_data;

wire                w_egress_prog_full;
wire                w_egress_wr_en;
wire    [255:0]     wv_egress_data;

wire 	[71 * 32 - 1 : 0]	wv_init_rw_data_RDMAEngine;

//RDMAEngine 
RDMAEngine RDMAEngine_Inst (
    .rw_data(rw_data[(44 + 71) * 32 - 1 : 44 * 32]),
    .init_rw_data(wv_init_rw_data_RDMAEngine),
	.ro_data(),

    .clk(clk),
    .rst(rst),
//Interface with PIO
    .i_pio_empty(w_pio_empty),
    .o_pio_rd_en(w_pio_rd_en),
    .iv_pio_data(wv_pio_dout),

//Interface with CxtMgt
    //Channel 1 for DoorbellProcessing, no cxt write back
    .o_db_cxtmgt_cmd_wr_en(w_db_cxtmgt_cmd_wr_en),
    .i_db_cxtmgt_cmd_prog_full(w_db_cxtmgt_cmd_prog_full),
    .ov_db_cxtmgt_cmd_data(wv_db_cxtmgt_cmd_din),

    .i_db_cxtmgt_resp_empty(w_db_cxtmgt_resp_empty),
    .o_db_cxtmgt_resp_rd_en(w_db_cxtmgt_resp_rd_en),
    .iv_db_cxtmgt_resp_data(wv_db_cxtmgt_resp_dout),

    .i_db_cxtmgt_cxt_empty(w_db_cxtmgt_cxt_download_empty),
    .o_db_cxtmgt_cxt_rd_en(w_db_cxtmgt_cxt_download_rd_en),
    .iv_db_cxtmgt_cxt_data(wv_db_cxtmgt_cxt_download_dout),

    //Channel 2 for WQEParser, no cxt write back
    .o_wp_cxtmgt_cmd_wr_en(w_wp_cxtmgt_cmd_wr_en),
    .i_wp_cxtmgt_cmd_prog_full(w_wp_cxtmgt_cmd_prog_full),
    .ov_wp_cxtmgt_cmd_data(wv_wp_cxtmgt_cmd_din),

    .i_wp_cxtmgt_resp_empty(w_wp_cxtmgt_resp_empty),
    .o_wp_cxtmgt_resp_rd_en(w_wp_cxtmgt_resp_rd_en),
    .iv_wp_cxtmgt_resp_data(wv_wp_cxtmgt_resp_dout),

    .i_wp_cxtmgt_cxt_empty(w_wp_cxtmgt_cxt_download_empty),
    .o_wp_cxtmgt_cxt_rd_en(w_wp_cxtmgt_cxt_download_rd_en),
    .iv_wp_cxtmgt_cxt_data(wv_wp_cxtmgt_cxt_download_dout),

    //Channel 3 for RequesterTransControl, cxt write back
    .o_rtc_cxtmgt_cmd_wr_en(w_rtc_cxtmgt_cmd_wr_en),
    .i_rtc_cxtmgt_cmd_prog_full(w_rtc_cxtmgt_cmd_prog_full),
    .ov_rtc_cxtmgt_cmd_data(wv_rtc_cxtmgt_cmd_din),

    .i_rtc_cxtmgt_resp_empty(w_rtc_cxtmgt_resp_empty),
    .o_rtc_cxtmgt_resp_rd_en(w_rtc_cxtmgt_resp_rd_en),
    .iv_rtc_cxtmgt_resp_data(wv_rtc_cxtmgt_resp_dout),

    .i_rtc_cxtmgt_cxt_empty(w_rtc_cxtmgt_cxt_download_empty),
    .o_rtc_cxtmgt_cxt_rd_en(w_rtc_cxtmgt_cxt_download_rd_en),
    .iv_rtc_cxtmgt_cxt_data(wv_rtc_cxtmgt_cxt_download_dout),

/*Spyglass Add Begin*/
    .i_rtc_cxtmgt_cxt_prog_full(w_rtc_cxtmgt_cxt_upload_prog_full),
    .o_rtc_cxtmgt_cxt_wr_en(w_rtc_cxtmgt_cxt_upload_wr_en),
    .ov_rtc_cxtmgt_cxt_data(wv_rtc_cxtmgt_cxt_upload_din),
/*SPyglass Add End*/

    //Channel 4 for RequesterRecvContro, cxt write back 
    .o_rrc_cxtmgt_cmd_wr_en(w_rrc_cxtmgt_cmd_wr_en),
    .i_rrc_cxtmgt_cmd_prog_full(w_rrc_cxtmgt_cmd_prog_full),
    .ov_rrc_cxtmgt_cmd_data(wv_rrc_cxtmgt_cmd_din),

    .i_rrc_cxtmgt_resp_empty(w_rrc_cxtmgt_resp_empty),
    .o_rrc_cxtmgt_resp_rd_en(w_rrc_cxtmgt_resp_rd_en),
    .iv_rrc_cxtmgt_resp_data(wv_rrc_cxtmgt_resp_dout),

    .i_rrc_cxtmgt_cxt_empty(w_rrc_cxtmgt_cxt_download_empty),
    .o_rrc_cxtmgt_cxt_rd_en(w_rrc_cxtmgt_cxt_download_rd_en),
    .iv_rrc_cxtmgt_cxt_data(wv_rrc_cxtmgt_cxt_download_dout),

    .o_rrc_cxtmgt_cxt_wr_en(w_rrc_cxtmgt_cxt_upload_wr_en),
    .i_rrc_cxtmgt_cxt_prog_full(w_rrc_cxtmgt_cxt_upload_prog_full),
    .ov_rrc_cxtmgt_cxt_data(wv_rrc_cxtmgt_cxt_upload_din),

    //Channel 5 for ExecutionEngine, cxt write back
    .o_ee_cxtmgt_cmd_wr_en(w_ee_cxtmgt_cmd_wr_en),
    .i_ee_cxtmgt_cmd_prog_full(w_ee_cxtmgt_cmd_prog_full),
    .ov_ee_cxtmgt_cmd_data(wv_ee_cxtmgt_cmd_din),

    .i_ee_cxtmgt_resp_empty(w_ee_cxtmgt_resp_empty),
    .o_ee_cxtmgt_resp_rd_en(w_ee_cxtmgt_resp_rd_en),
    .iv_ee_cxtmgt_resp_data(wv_ee_cxtmgt_resp_dout),

    .i_ee_cxtmgt_cxt_empty(w_ee_cxtmgt_cxt_download_empty),
    .o_ee_cxtmgt_cxt_rd_en(w_ee_cxtmgt_cxt_download_rd_en),
    .iv_ee_cxtmgt_cxt_data(wv_ee_cxtmgt_cxt_download_dout),

    .o_ee_cxtmgt_cxt_wr_en(w_ee_cxtmgt_cxt_upload_wr_en),
    .i_ee_cxtmgt_cxt_prog_full(w_ee_cxtmgt_cxt_upload_prog_full),
    .ov_ee_cxtmgt_cxt_data(wv_ee_cxtmgt_cxt_upload_din),

//Interface with VirtToPhys
    //Channel 1 for Doorbell Processing, only read
    .o_db_vtp_cmd_wr_en(w_db_vtp_cmd_wr_en),
    .i_db_vtp_cmd_prog_full(w_db_vtp_cmd_prog_full),
    .ov_db_vtp_cmd_data(wv_db_vtp_cmd_din),

    .i_db_vtp_resp_empty(w_db_vtp_resp_empty),
    .o_db_vtp_resp_rd_en(w_db_vtp_resp_rd_en),
    .iv_db_vtp_resp_data(wv_db_vtp_resp_dout),

    .i_db_vtp_download_empty(w_db_vtp_download_empty),
    .o_db_vtp_download_rd_en(w_db_vtp_download_rd_en),
    .iv_db_vtp_download_data(wv_db_vtp_download_dout),
        
    //Channel 2 for WQEParser, download SQ WQE
    .o_wp_vtp_wqe_cmd_wr_en(w_wp_vtp_wqe_cmd_wr_en),
    .i_wp_vtp_wqe_cmd_prog_full(w_wp_vtp_wqe_cmd_prog_full),
    .ov_wp_vtp_wqe_cmd_data(wv_wp_vtp_wqe_cmd_din),

    .i_wp_vtp_wqe_resp_empty(w_wp_vtp_wqe_resp_empty),
    .o_wp_vtp_wqe_resp_rd_en(w_wp_vtp_wqe_resp_rd_en),
    .iv_wp_vtp_wqe_resp_data(wv_wp_vtp_wqe_resp_dout),

    .i_wp_vtp_wqe_download_empty(w_wp_vtp_wqe_download_empty),
    .o_wp_vtp_wqe_download_rd_en(w_wp_vtp_wqe_download_rd_en),
    .iv_wp_vtp_wqe_download_data(wv_wp_vtp_wqe_download_dout),

    //Channel 3 for WQEParser, download network data
    .o_wp_vtp_nd_cmd_wr_en(w_wp_vtp_nd_cmd_wr_en),
    .i_wp_vtp_nd_cmd_prog_full(w_wp_vtp_nd_cmd_prog_full),
    .ov_wp_vtp_nd_cmd_data(wv_wp_vtp_nd_cmd_din),

    .i_wp_vtp_nd_resp_empty(w_wp_vtp_nd_resp_empty),
    .o_wp_vtp_nd_resp_rd_en(w_wp_vtp_nd_resp_rd_en),
    .iv_wp_vtp_nd_resp_data(wv_wp_vtp_nd_resp_dout),

    .i_wp_vtp_nd_download_empty(w_wp_vtp_nd_download_empty),
    .o_wp_vtp_nd_download_rd_en(w_wp_vtp_nd_download_rd_en),
    .iv_wp_vtp_nd_download_data(wv_wp_vtp_nd_download_dout),

    //Channel 4 for RequesterTransControl, upload Completion Event
    .o_rtc_vtp_cmd_wr_en(w_rtc_vtp_cmd_wr_en),
    .i_rtc_vtp_cmd_prog_full(w_rtc_vtp_cmd_prog_full),
    .ov_rtc_vtp_cmd_data(wv_rtc_vtp_cmd_din),

    .i_rtc_vtp_resp_empty(w_rtc_vtp_resp_empty),
    .o_rtc_vtp_resp_rd_en(w_rtc_vtp_resp_rd_en),
    .iv_rtc_vtp_resp_data(wv_rtc_vtp_resp_dout),

    .o_rtc_vtp_upload_wr_en(w_rtc_vtp_upload_wr_en),
    .i_rtc_vtp_upload_prog_full(w_rtc_vtp_upload_prog_full),
    .ov_rtc_vtp_upload_data(wv_rtc_vtp_upload_din),

    //Channel 5 for RequesterRecvControl, upload RDMA Read Response
    .o_rrc_vtp_cmd_wr_en(w_rrc_vtp_cmd_wr_en),
    .i_rrc_vtp_cmd_prog_full(w_rrc_vtp_cmd_prog_full),
    .ov_rrc_vtp_cmd_data(wv_rrc_vtp_cmd_din),

    .i_rrc_vtp_resp_empty(w_rrc_vtp_resp_empty),
    .o_rrc_vtp_resp_rd_en(w_rrc_vtp_resp_rd_en),
    .iv_rrc_vtp_resp_data(wv_rrc_vtp_resp_dout),

    .o_rrc_vtp_upload_wr_en(w_rrc_vtp_upload_wr_en),
    .i_rrc_vtp_upload_prog_full(w_rrc_vtp_upload_prog_full),
    .ov_rrc_vtp_upload_data(wv_rrc_vtp_upload_din),

    //Channel 6 for ExecutionEngine, upload Send/Write Payload and download Read Payload
    .o_ee_vtp_cmd_wr_en(w_ee_vtp_cmd_wr_en),
    .i_ee_vtp_cmd_prog_full(w_ee_vtp_cmd_prog_full),
    .ov_ee_vtp_cmd_data(wv_ee_vtp_cmd_din),

    .i_ee_vtp_resp_empty(w_ee_vtp_resp_empty),
    .o_ee_vtp_resp_rd_en(w_ee_vtp_resp_rd_en),
    .iv_ee_vtp_resp_data(wv_ee_vtp_resp_dout),

    .o_ee_vtp_upload_wr_en(w_ee_vtp_upload_wr_en),
    .i_ee_vtp_upload_prog_full(w_ee_vtp_upload_prog_full),
    .ov_ee_vtp_upload_data(wv_ee_vtp_upload_din),

    .o_ee_vtp_download_rd_en(w_ee_vtp_download_rd_en),
    .i_ee_vtp_download_empty(w_ee_vtp_download_empty),
    .iv_ee_vtp_download_data(wv_ee_vtp_download_dout),

    //Channel 7 for ExecutionEngine, download RQ WQE
    .o_rwm_vtp_cmd_wr_en(w_rwm_vtp_cmd_wr_en),
    .i_rwm_vtp_cmd_prog_full(w_rwm_vtp_cmd_prog_full),
    .ov_rwm_vtp_cmd_data(wv_rwm_vtp_cmd_din),

    .i_rwm_vtp_resp_empty(w_rwm_vtp_resp_empty),
    .o_rwm_vtp_resp_rd_en(w_rwm_vtp_resp_rd_en),
    .iv_rwm_vtp_resp_data(wv_rwm_vtp_resp_dout),

    .o_rwm_vtp_download_rd_en(w_rwm_vtp_download_rd_en),
    .i_rwm_vtp_download_empty(w_rwm_vtp_download_empty),
    .iv_rwm_vtp_download_data(wv_rwm_vtp_download_dout),

//LinkLayer
    .i_outbound_pkt_prog_full(w_egress_prog_full),
    .o_outbound_pkt_wr_en(w_egress_wr_en),
    .ov_outbound_pkt_data(wv_egress_data),

    .i_inbound_pkt_empty(w_ingress_empty),
    .o_inbound_pkt_rd_en(w_ingress_rd_en),
    .iv_inbound_pkt_data(wv_ingress_data),

	  .o_rdma_init_finish(w_rdma_engine_init_finish),

    .dbg_sel(wv_rdma_engine_dbg_sel),
    .dbg_bus(wv_rdma_engine_dbg_bus)
);

MiscLayer   MiscLayer_Inst(
    .rw_data(rw_data[(115 + 14) * 32 - 1 : 115 * 32]),
    .rw_init_data(wv_misc_layer_init_rw_data),
    .ro_data(wv_misc_layer_ro_data),

  .clk(clk),
  .rst(rst),

/*Interface with RDMAEngine*/
//Egress traffic from RDMAEngine
  .i_outbound_pkt_wr_en(w_egress_wr_en),
  .o_outbound_pkt_prog_full(w_egress_prog_full),
  .iv_outbound_pkt_data(wv_egress_data), 

  .o_inbound_pkt_empty(w_ingress_empty),
  .i_inbound_pkt_rd_en(w_ingress_rd_en),
  .ov_inbound_pkt_data(wv_ingress_data),

/*Interface with CxtMgt*/
   .o_cxtmgt_cmd_wr_en(w_fe_cxtmgt_cmd_wr_en),
   .i_cxtmgt_cmd_prog_full(w_fe_cxtmgt_cmd_prog_full),
   .ov_cxtmgt_cmd_data(wv_fe_cxtmgt_cmd_din),

   .i_cxtmgt_resp_empty(w_fe_cxtmgt_resp_empty),
   .o_cxtmgt_resp_rd_en(w_fe_cxtmgt_resp_rd_en),
   .iv_cxtmgt_resp_data(wv_fe_cxtmgt_resp_dout),

   .i_cxtmgt_cxt_empty(w_fe_cxtmgt_cxt_download_empty),
   .o_cxtmgt_cxt_rd_en(w_fe_cxtmgt_cxt_download_rd_en),
   .iv_cxtmgt_cxt_data(wv_fe_cxtmgt_cxt_download_dout),

/*Interface with TX HPC Link, AXIS Interface*/
	/*interface to LinkLayer Tx  */
	.o_hpc_tx_valid(o_hpc_tx_valid),
	.o_hpc_tx_last(o_hpc_tx_last),
	.ov_hpc_tx_data(ov_hpc_tx_data),
	.ov_hpc_tx_keep(ov_hpc_tx_keep),
	.i_hpc_tx_ready(i_hpc_tx_ready),
	.o_hpc_tx_start(o_hpc_tx_start), 		//Indicates start of the packet
	.ov_hpc_tx_user(ov_hpc_tx_user), 	 	//Indicates length of the packet, in unit of 128 Byte, round up to 128

/*Interface with RX HPC Link, AXIS Interface*/
	/*interface to LinkLayer Rx  */
	.i_hpc_rx_valid(i_hpc_rx_valid), 
	.i_hpc_rx_last(i_hpc_rx_last),
	.iv_hpc_rx_data(iv_hpc_rx_data),
	.iv_hpc_rx_keep(iv_hpc_rx_keep),
	.o_hpc_rx_ready(o_hpc_rx_ready),	
	.i_hpc_rx_start(i_hpc_rx_start),
	.iv_hpc_rx_user(iv_hpc_rx_user), 

/*Interface with Tx Eth Link, FIFO Interface*/
	.o_desc_empty(o_desc_empty),
	.ov_desc_data(ov_desc_data),
	.i_desc_rd_en(i_desc_rd_en),

	.o_roce_egress_empty(o_roce_egress_empty),
	.i_roce_egress_rd_en(i_roce_egress_rd_en),
	.ov_roce_egress_data(ov_roce_egress_data),

/*Interface with Rx Eth Link, FIFO Interface*/
	.o_roce_ingress_prog_full(o_roce_ingress_prog_full),
	.i_roce_ingress_wr_en(i_roce_ingress_wr_en),
	.iv_roce_ingress_data(iv_roce_ingress_data),

  .o_misc_layer_init_finish(w_misc_layer_init_finish),


  .dbg_sel(wv_misc_layer_dbg_sel),
  .dbg_bus(wv_misc_layer_dbg_bus)
);

/*----------------------------- Connect dbg bus -------------------------------------*/
wire   [7424 - 1 : 0]   coalesced_bus;

assign coalesced_bus = {
                            w_rdma_engine_init_finish,
                            w_misc_layer_init_finish,
                            w_db_vtp_cmd_prog_full,
                            w_db_vtp_cmd_wr_en,
                            w_db_vtp_resp_empty,
                            w_db_vtp_resp_rd_en,
                            w_db_vtp_download_empty,
                            w_db_vtp_download_rd_en,
                            w_wp_vtp_wqe_cmd_wr_en,
                            w_wp_vtp_wqe_cmd_prog_full,
                            w_wp_vtp_wqe_resp_empty,
                            w_wp_vtp_wqe_resp_rd_en,
                            w_wp_vtp_wqe_download_empty,
                            w_wp_vtp_wqe_download_rd_en,
                            w_wp_vtp_nd_cmd_wr_en,
                            w_wp_vtp_nd_cmd_prog_full,
                            w_wp_vtp_nd_resp_empty,
                            w_wp_vtp_nd_resp_rd_en,
                            w_wp_vtp_nd_download_empty,
                            w_wp_vtp_nd_download_rd_en,
                            w_rtc_vtp_cmd_wr_en,
                            w_rtc_vtp_cmd_prog_full,
                            w_rtc_vtp_resp_empty,
                            w_rtc_vtp_resp_rd_en,
                            w_rtc_vtp_upload_wr_en,
                            w_rtc_vtp_upload_prog_full,
                            w_rrc_vtp_cmd_wr_en,
                            w_rrc_vtp_cmd_prog_full,
                            w_rrc_vtp_resp_empty,
                            w_rrc_vtp_resp_rd_en,
                            w_rrc_vtp_upload_wr_en,
                            w_rrc_vtp_upload_prog_full,
                            w_rwm_vtp_cmd_wr_en,
                            w_rwm_vtp_cmd_prog_full,
                            w_rwm_vtp_resp_empty,
                            w_rwm_vtp_resp_rd_en,
                            w_rwm_vtp_download_rd_en,
                            w_rwm_vtp_download_empty,
                            w_ee_vtp_cmd_wr_en,
                            w_ee_vtp_cmd_prog_full,
                            w_ee_vtp_resp_empty,
                            w_ee_vtp_resp_rd_en,
                            w_ee_vtp_upload_wr_en,
                            w_ee_vtp_upload_prog_full,
                            w_ee_vtp_download_rd_en,
                            w_ee_vtp_download_empty,
                            w_db_cxtmgt_cmd_wr_en,
                            w_db_cxtmgt_cmd_prog_full,
                            w_db_cxtmgt_resp_empty,
                            w_db_cxtmgt_resp_rd_en,
                            w_db_cxtmgt_cxt_download_empty,
                            w_db_cxtmgt_cxt_download_rd_en,
                            w_wp_cxtmgt_cmd_wr_en,
                            w_wp_cxtmgt_cmd_prog_full,
                            w_wp_cxtmgt_resp_empty,
                            w_wp_cxtmgt_resp_rd_en,
                            w_wp_cxtmgt_cxt_download_empty,
                            w_wp_cxtmgt_cxt_download_rd_en,
                            w_rtc_cxtmgt_cmd_wr_en,
                            w_rtc_cxtmgt_cmd_prog_full,
                            w_rtc_cxtmgt_resp_empty,
                            w_rtc_cxtmgt_resp_rd_en,
                            w_rtc_cxtmgt_cxt_download_empty,
                            w_rtc_cxtmgt_cxt_download_rd_en,
                            w_rtc_cxtmgt_cxt_upload_prog_full,
                            w_rtc_cxtmgt_cxt_upload_wr_en,
                            w_rrc_cxtmgt_cmd_wr_en,
                            w_rrc_cxtmgt_cmd_prog_full,
                            w_rrc_cxtmgt_resp_empty,
                            w_rrc_cxtmgt_resp_rd_en,
                            w_rrc_cxtmgt_cxt_download_empty,
                            w_rrc_cxtmgt_cxt_download_rd_en,
                            w_rrc_cxtmgt_cxt_upload_prog_full,
                            w_rrc_cxtmgt_cxt_upload_wr_en,
                            w_ee_cxtmgt_cmd_wr_en,
                            w_ee_cxtmgt_cmd_prog_full,
                            w_ee_cxtmgt_resp_empty,
                            w_ee_cxtmgt_resp_rd_en,
                            w_ee_cxtmgt_cxt_download_empty,
                            w_ee_cxtmgt_cxt_download_rd_en,
                            w_ee_cxtmgt_cxt_upload_prog_full,
                            w_ee_cxtmgt_cxt_upload_wr_en,
                            w_fe_cxtmgt_cmd_wr_en,
                            w_fe_cxtmgt_cmd_prog_full,
                            w_fe_cxtmgt_resp_empty,
                            w_fe_cxtmgt_resp_rd_en,
                            w_fe_cxtmgt_cxt_download_empty,
                            w_fe_cxtmgt_cxt_download_rd_en,
                            w_pio_empty,
                            w_pio_rd_en,
                            w_ingress_empty,
                            w_ingress_rd_en,
                            w_egress_prog_full,
                            w_egress_wr_en,
                            wv_db_vtp_resp_dout,
                            wv_wp_vtp_wqe_resp_dout,
                            wv_wp_vtp_nd_resp_dout,
                            wv_rtc_vtp_resp_dout,
                            wv_rrc_vtp_resp_dout,
                            wv_rwm_vtp_resp_dout,
                            wv_ee_vtp_resp_dout,
                            wv_db_vtp_cmd_din,
                            wv_wp_vtp_wqe_cmd_din,
                            wv_wp_vtp_nd_cmd_din,
                            wv_wp_vtp_nd_download_dout,
                            wv_rtc_vtp_cmd_din,
                            wv_rtc_vtp_upload_din,
                            wv_rrc_vtp_cmd_din,
                            wv_rrc_vtp_upload_din,
                            wv_rwm_vtp_cmd_din,
                            wv_ee_vtp_cmd_din,
                            wv_ee_vtp_upload_din,
                            wv_ee_vtp_download_dout,
                            wv_db_cxtmgt_cxt_download_dout,
                            wv_rrc_cxtmgt_cxt_download_dout,
                            wv_fe_cxtmgt_cxt_download_dout,
                            wv_ingress_data,
                            wv_egress_data,
                            wv_db_vtp_download_dout,
                            wv_wp_vtp_wqe_download_dout,
                            wv_rwm_vtp_download_dout,
                            wv_db_cxtmgt_cmd_din,
                            wv_db_cxtmgt_resp_dout,
                            wv_wp_cxtmgt_cmd_din,
                            wv_wp_cxtmgt_resp_dout,
                            wv_wp_cxtmgt_cxt_download_dout,
                            wv_rtc_cxtmgt_cmd_din,
                            wv_rtc_cxtmgt_resp_dout,
                            wv_rtc_cxtmgt_cxt_upload_din,
                            wv_rrc_cxtmgt_cmd_din,
                            wv_rrc_cxtmgt_resp_dout,
                            wv_rrc_cxtmgt_cxt_upload_din,
                            wv_ee_cxtmgt_cmd_din,
                            wv_ee_cxtmgt_resp_dout,
                            wv_ee_cxtmgt_cxt_upload_din,
                            wv_fe_cxtmgt_cmd_din,
                            wv_fe_cxtmgt_resp_dout,
                            wv_rtc_cxtmgt_cxt_download_dout,
                            wv_ee_cxtmgt_cxt_download_dout,
                            wv_pio_dout
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
                    (dbg_sel == 43) ?   coalesced_bus[32 * 44 - 1 : 32 * 43] :
                    (dbg_sel == 44) ?   coalesced_bus[32 * 45 - 1 : 32 * 44] :
                    (dbg_sel == 45) ?   coalesced_bus[32 * 46 - 1 : 32 * 45] :
                    (dbg_sel == 46) ?   coalesced_bus[32 * 47 - 1 : 32 * 46] :
                    (dbg_sel == 47) ?   coalesced_bus[32 * 48 - 1 : 32 * 47] :
                    (dbg_sel == 48) ?   coalesced_bus[32 * 49 - 1 : 32 * 48] :
                    (dbg_sel == 49) ?   coalesced_bus[32 * 50 - 1 : 32 * 49] :
                    (dbg_sel == 50) ?   coalesced_bus[32 * 51 - 1 : 32 * 50] :
                    (dbg_sel == 51) ?   coalesced_bus[32 * 52 - 1 : 32 * 51] :
                    (dbg_sel == 52) ?   coalesced_bus[32 * 53 - 1 : 32 * 52] :
                    (dbg_sel == 53) ?   coalesced_bus[32 * 54 - 1 : 32 * 53] :
                    (dbg_sel == 54) ?   coalesced_bus[32 * 55 - 1 : 32 * 54] :
                    (dbg_sel == 55) ?   coalesced_bus[32 * 56 - 1 : 32 * 55] :
                    (dbg_sel == 56) ?   coalesced_bus[32 * 57 - 1 : 32 * 56] :
                    (dbg_sel == 57) ?   coalesced_bus[32 * 58 - 1 : 32 * 57] :
                    (dbg_sel == 58) ?   coalesced_bus[32 * 59 - 1 : 32 * 58] :
                    (dbg_sel == 59) ?   coalesced_bus[32 * 60 - 1 : 32 * 59] :
                    (dbg_sel == 60) ?   coalesced_bus[32 * 61 - 1 : 32 * 60] :
                    (dbg_sel == 61) ?   coalesced_bus[32 * 62 - 1 : 32 * 61] :
                    (dbg_sel == 62) ?   coalesced_bus[32 * 63 - 1 : 32 * 62] :
                    (dbg_sel == 63) ?   coalesced_bus[32 * 64 - 1 : 32 * 63] :
                    (dbg_sel == 64) ?   coalesced_bus[32 * 65 - 1 : 32 * 64] :
                    (dbg_sel == 65) ?   coalesced_bus[32 * 66 - 1 : 32 * 65] :
                    (dbg_sel == 66) ?   coalesced_bus[32 * 67 - 1 : 32 * 66] :
                    (dbg_sel == 67) ?   coalesced_bus[32 * 68 - 1 : 32 * 67] :
                    (dbg_sel == 68) ?   coalesced_bus[32 * 69 - 1 : 32 * 68] :
                    (dbg_sel == 69) ?   coalesced_bus[32 * 70 - 1 : 32 * 69] :
                    (dbg_sel == 70) ?   coalesced_bus[32 * 71 - 1 : 32 * 70] :
                    (dbg_sel == 71) ?   coalesced_bus[32 * 72 - 1 : 32 * 71] :
                    (dbg_sel == 72) ?   coalesced_bus[32 * 73 - 1 : 32 * 72] :
                    (dbg_sel == 73) ?   coalesced_bus[32 * 74 - 1 : 32 * 73] :
                    (dbg_sel == 74) ?   coalesced_bus[32 * 75 - 1 : 32 * 74] :
                    (dbg_sel == 75) ?   coalesced_bus[32 * 76 - 1 : 32 * 75] :
                    (dbg_sel == 76) ?   coalesced_bus[32 * 77 - 1 : 32 * 76] :
                    (dbg_sel == 77) ?   coalesced_bus[32 * 78 - 1 : 32 * 77] :
                    (dbg_sel == 78) ?   coalesced_bus[32 * 79 - 1 : 32 * 78] :
                    (dbg_sel == 79) ?   coalesced_bus[32 * 80 - 1 : 32 * 79] :
                    (dbg_sel == 80) ?   coalesced_bus[32 * 81 - 1 : 32 * 80] :
                    (dbg_sel == 81) ?   coalesced_bus[32 * 82 - 1 : 32 * 81] :
                    (dbg_sel == 82) ?   coalesced_bus[32 * 83 - 1 : 32 * 82] :
                    (dbg_sel == 83) ?   coalesced_bus[32 * 84 - 1 : 32 * 83] :
                    (dbg_sel == 84) ?   coalesced_bus[32 * 85 - 1 : 32 * 84] :
                    (dbg_sel == 85) ?   coalesced_bus[32 * 86 - 1 : 32 * 85] :
                    (dbg_sel == 86) ?   coalesced_bus[32 * 87 - 1 : 32 * 86] : 
                    (dbg_sel == 87) ?   coalesced_bus[32 * 88 - 1 : 32 * 87] : 
                    (dbg_sel == 88) ?   coalesced_bus[32 * 89 - 1 : 32 * 88] : 
                    (dbg_sel == 89) ?   coalesced_bus[32 * 90 - 1 : 32 * 89] : 
                    (dbg_sel == 90) ?   coalesced_bus[32 * 91 - 1 : 32 * 90] : 
                    (dbg_sel == 91) ?   coalesced_bus[32 * 92 - 1 : 32 * 91] : 
                    (dbg_sel == 92) ?   coalesced_bus[32 * 93 - 1 : 32 * 92] : 
                    (dbg_sel == 93) ?   coalesced_bus[32 * 94 - 1 : 32 * 93] : 
                    (dbg_sel == 94) ?   coalesced_bus[32 * 95 - 1 : 32 * 94] : 
                    (dbg_sel == 95) ?   coalesced_bus[32 * 96 - 1 : 32 * 95] : 
                    (dbg_sel == 96) ?   coalesced_bus[32 * 97 - 1 : 32 * 96] : 
                    (dbg_sel == 97) ?   coalesced_bus[32 * 98 - 1 : 32 * 97] : 
                    (dbg_sel == 98) ?   coalesced_bus[32 * 99 - 1 : 32 * 98] : 
                    (dbg_sel == 99) ?   coalesced_bus[32 * 100 - 1 : 32 * 99] : 
                    (dbg_sel == 100) ?  coalesced_bus[32 * 101 - 1 : 32 * 100] : 
                    (dbg_sel == 101) ?  coalesced_bus[32 * 102 - 1 : 32 * 101] : 
                    (dbg_sel == 102) ?  coalesced_bus[32 * 103 - 1 : 32 * 102] : 
                    (dbg_sel == 103) ?  coalesced_bus[32 * 104 - 1 : 32 * 103] : 
                    (dbg_sel == 104) ?  coalesced_bus[32 * 105 - 1 : 32 * 104] : 
                    (dbg_sel == 105) ?  coalesced_bus[32 * 106 - 1 : 32 * 105] : 
                    (dbg_sel == 106) ?  coalesced_bus[32 * 107 - 1 : 32 * 106] : 
                    (dbg_sel == 107) ?  coalesced_bus[32 * 108 - 1 : 32 * 107] : 
                    (dbg_sel == 108) ?  coalesced_bus[32 * 109 - 1 : 32 * 108] :
                    (dbg_sel == 109) ?  coalesced_bus[32 * 110 - 1 : 32 * 109] :
                    (dbg_sel == 110) ?  coalesced_bus[32 * 111 - 1 : 32 * 110] :
                    (dbg_sel == 111) ?  coalesced_bus[32 * 112 - 1 : 32 * 111] :
                    (dbg_sel == 112) ?  coalesced_bus[32 * 113 - 1 : 32 * 112] :
                    (dbg_sel == 113) ?  coalesced_bus[32 * 114 - 1 : 32 * 113] :
                    (dbg_sel == 114) ?  coalesced_bus[32 * 115 - 1 : 32 * 114] :
                    (dbg_sel == 115) ?  coalesced_bus[32 * 116 - 1 : 32 * 115] :
                    (dbg_sel == 116) ?  coalesced_bus[32 * 117 - 1 : 32 * 116] :
                    (dbg_sel == 117) ?  coalesced_bus[32 * 118 - 1 : 32 * 117] :
                    (dbg_sel == 118) ?  coalesced_bus[32 * 119 - 1 : 32 * 118] :
                    (dbg_sel == 119) ?  coalesced_bus[32 * 120 - 1 : 32 * 119] :
                    (dbg_sel == 120) ?  coalesced_bus[32 * 121 - 1 : 32 * 120] :
                    (dbg_sel == 121) ?  coalesced_bus[32 * 122 - 1 : 32 * 121] :
                    (dbg_sel == 122) ?  coalesced_bus[32 * 123 - 1 : 32 * 122] :
                    (dbg_sel == 123) ?  coalesced_bus[32 * 124 - 1 : 32 * 123] :
                    (dbg_sel == 124) ?  coalesced_bus[32 * 125 - 1 : 32 * 124] :
                    (dbg_sel == 125) ?  coalesced_bus[32 * 126 - 1 : 32 * 125] :
                    (dbg_sel == 126) ?  coalesced_bus[32 * 127 - 1 : 32 * 126] :
                    (dbg_sel == 127) ?  coalesced_bus[32 * 128 - 1 : 32 * 127] :
                    (dbg_sel == 128) ?  coalesced_bus[32 * 129 - 1 : 32 * 128] :
                    (dbg_sel == 129) ?  coalesced_bus[32 * 130 - 1 : 32 * 129] :
                    (dbg_sel == 130) ?  coalesced_bus[32 * 131 - 1 : 32 * 130] :
                    (dbg_sel == 131) ?  coalesced_bus[32 * 132 - 1 : 32 * 131] :
                    (dbg_sel == 132) ?  coalesced_bus[32 * 133 - 1 : 32 * 132] :
                    (dbg_sel == 133) ?  coalesced_bus[32 * 134 - 1 : 32 * 133] :
                    (dbg_sel == 134) ?  coalesced_bus[32 * 135 - 1 : 32 * 134] :
                    (dbg_sel == 135) ?  coalesced_bus[32 * 136 - 1 : 32 * 135] :
                    (dbg_sel == 136) ?  coalesced_bus[32 * 137 - 1 : 32 * 136] :
                    (dbg_sel == 137) ?  coalesced_bus[32 * 138 - 1 : 32 * 137] :
                    (dbg_sel == 138) ?  coalesced_bus[32 * 139 - 1 : 32 * 138] :
                    (dbg_sel == 139) ?  coalesced_bus[32 * 140 - 1 : 32 * 139] :
                    (dbg_sel == 140) ?  coalesced_bus[32 * 141 - 1 : 32 * 140] :
                    (dbg_sel == 141) ?  coalesced_bus[32 * 142 - 1 : 32 * 141] :
                    (dbg_sel == 142) ?  coalesced_bus[32 * 143 - 1 : 32 * 142] :
                    (dbg_sel == 143) ?  coalesced_bus[32 * 144 - 1 : 32 * 143] :
                    (dbg_sel == 144) ?  coalesced_bus[32 * 145 - 1 : 32 * 144] :
                    (dbg_sel == 145) ?  coalesced_bus[32 * 146 - 1 : 32 * 145] :
                    (dbg_sel == 146) ?  coalesced_bus[32 * 147 - 1 : 32 * 146] :
                    (dbg_sel == 147) ?  coalesced_bus[32 * 148 - 1 : 32 * 147] :
                    (dbg_sel == 148) ?  coalesced_bus[32 * 149 - 1 : 32 * 148] :
                    (dbg_sel == 149) ?  coalesced_bus[32 * 150 - 1 : 32 * 149] :
                    (dbg_sel == 150) ?  coalesced_bus[32 * 151 - 1 : 32 * 150] :
                    (dbg_sel == 151) ?  coalesced_bus[32 * 152 - 1 : 32 * 151] :
                    (dbg_sel == 152) ?  coalesced_bus[32 * 153 - 1 : 32 * 152] :
                    (dbg_sel == 153) ?  coalesced_bus[32 * 154 - 1 : 32 * 153] :
                    (dbg_sel == 154) ?  coalesced_bus[32 * 155 - 1 : 32 * 154] :
                    (dbg_sel == 155) ?  coalesced_bus[32 * 156 - 1 : 32 * 155] :
                    (dbg_sel == 156) ?  coalesced_bus[32 * 157 - 1 : 32 * 156] :
                    (dbg_sel == 157) ?  coalesced_bus[32 * 158 - 1 : 32 * 157] :
                    (dbg_sel == 158) ?  coalesced_bus[32 * 159 - 1 : 32 * 158] :
                    (dbg_sel == 159) ?  coalesced_bus[32 * 160 - 1 : 32 * 159] :
                    (dbg_sel == 160) ?  coalesced_bus[32 * 161 - 1 : 32 * 160] :
                    (dbg_sel == 161) ?  coalesced_bus[32 * 162 - 1 : 32 * 161] :
                    (dbg_sel == 162) ?  coalesced_bus[32 * 163 - 1 : 32 * 162] :
                    (dbg_sel == 163) ?  coalesced_bus[32 * 164 - 1 : 32 * 163] :
                    (dbg_sel == 164) ?  coalesced_bus[32 * 165 - 1 : 32 * 164] :
                    (dbg_sel == 165) ?  coalesced_bus[32 * 166 - 1 : 32 * 165] :
                    (dbg_sel == 166) ?  coalesced_bus[32 * 167 - 1 : 32 * 166] :
                    (dbg_sel == 167) ?  coalesced_bus[32 * 168 - 1 : 32 * 167] :
                    (dbg_sel == 168) ?  coalesced_bus[32 * 169 - 1 : 32 * 168] :
                    (dbg_sel == 169) ?  coalesced_bus[32 * 170 - 1 : 32 * 169] :
                    (dbg_sel == 170) ?  coalesced_bus[32 * 171 - 1 : 32 * 170] :
                    (dbg_sel == 171) ?  coalesced_bus[32 * 172 - 1 : 32 * 171] :
                    (dbg_sel == 172) ?  coalesced_bus[32 * 173 - 1 : 32 * 172] :
                    (dbg_sel == 173) ?  coalesced_bus[32 * 174 - 1 : 32 * 173] :
                    (dbg_sel == 174) ?  coalesced_bus[32 * 175 - 1 : 32 * 174] :
                    (dbg_sel == 175) ?  coalesced_bus[32 * 176 - 1 : 32 * 175] :
                    (dbg_sel == 176) ?  coalesced_bus[32 * 177 - 1 : 32 * 176] :
                    (dbg_sel == 177) ?  coalesced_bus[32 * 178 - 1 : 32 * 177] :
                    (dbg_sel == 178) ?  coalesced_bus[32 * 179 - 1 : 32 * 178] :
                    (dbg_sel == 179) ?  coalesced_bus[32 * 180 - 1 : 32 * 179] :
                    (dbg_sel == 180) ?  coalesced_bus[32 * 181 - 1 : 32 * 180] :
                    (dbg_sel == 181) ?  coalesced_bus[32 * 182 - 1 : 32 * 181] :
                    (dbg_sel == 182) ?  coalesced_bus[32 * 183 - 1 : 32 * 182] :
                    (dbg_sel == 183) ?  coalesced_bus[32 * 184 - 1 : 32 * 183] :
                    (dbg_sel == 184) ?  coalesced_bus[32 * 185 - 1 : 32 * 184] :
                    (dbg_sel == 185) ?  coalesced_bus[32 * 186 - 1 : 32 * 185] :
                    (dbg_sel == 186) ?  coalesced_bus[32 * 187 - 1 : 32 * 186] :
                    (dbg_sel == 187) ?  coalesced_bus[32 * 188 - 1 : 32 * 187] :
                    (dbg_sel == 188) ?  coalesced_bus[32 * 189 - 1 : 32 * 188] :
                    (dbg_sel == 189) ?  coalesced_bus[32 * 190 - 1 : 32 * 189] :
                    (dbg_sel == 190) ?  coalesced_bus[32 * 191 - 1 : 32 * 190] :
                    (dbg_sel == 191) ?  coalesced_bus[32 * 192 - 1 : 32 * 191] :
                    (dbg_sel == 192) ?  coalesced_bus[32 * 193 - 1 : 32 * 192] :
                    (dbg_sel == 193) ?  coalesced_bus[32 * 194 - 1 : 32 * 193] :
                    (dbg_sel == 194) ?  coalesced_bus[32 * 195 - 1 : 32 * 194] :
                    (dbg_sel == 195) ?  coalesced_bus[32 * 196 - 1 : 32 * 195] :
                    (dbg_sel == 196) ?  coalesced_bus[32 * 197 - 1 : 32 * 196] :
                    (dbg_sel == 197) ?  coalesced_bus[32 * 198 - 1 : 32 * 197] :
                    (dbg_sel == 198) ?  coalesced_bus[32 * 199 - 1 : 32 * 198] :
                    (dbg_sel == 199) ?  coalesced_bus[32 * 200 - 1 : 32 * 199] :
                    (dbg_sel == 200) ?  coalesced_bus[32 * 201 - 1 : 32 * 200] :
                    (dbg_sel == 201) ?  coalesced_bus[32 * 202 - 1 : 32 * 201] :
                    (dbg_sel == 202) ?  coalesced_bus[32 * 203 - 1 : 32 * 202] :
                    (dbg_sel == 203) ?  coalesced_bus[32 * 204 - 1 : 32 * 203] :
                    (dbg_sel == 204) ?  coalesced_bus[32 * 205 - 1 : 32 * 204] :
                    (dbg_sel == 205) ?  coalesced_bus[32 * 206 - 1 : 32 * 205] :
                    (dbg_sel == 206) ?  coalesced_bus[32 * 207 - 1 : 32 * 206] :
                    (dbg_sel == 207) ?  coalesced_bus[32 * 208 - 1 : 32 * 207] :
                    (dbg_sel == 208) ?  coalesced_bus[32 * 209 - 1 : 32 * 208] :
                    (dbg_sel == 209) ?  coalesced_bus[32 * 210 - 1 : 32 * 209] :
                    (dbg_sel == 210) ?  coalesced_bus[32 * 211 - 1 : 32 * 210] :
                    (dbg_sel == 211) ?  coalesced_bus[32 * 212 - 1 : 32 * 211] :
                    (dbg_sel == 212) ?  coalesced_bus[32 * 213 - 1 : 32 * 212] :
                    (dbg_sel == 213) ?  coalesced_bus[32 * 214 - 1 : 32 * 213] :
                    (dbg_sel == 214) ?  coalesced_bus[32 * 215 - 1 : 32 * 214] :
                    (dbg_sel == 215) ?  coalesced_bus[32 * 216 - 1 : 32 * 215] :
                    (dbg_sel == 216) ?  coalesced_bus[32 * 217 - 1 : 32 * 216] :
                    (dbg_sel == 217) ?  coalesced_bus[32 * 218 - 1 : 32 * 217] :
                    (dbg_sel == 218) ?  coalesced_bus[32 * 219 - 1 : 32 * 218] :
                    (dbg_sel == 219) ?  coalesced_bus[32 * 220 - 1 : 32 * 219] :
                    (dbg_sel == 220) ?  coalesced_bus[32 * 221 - 1 : 32 * 220] :
                    (dbg_sel == 221) ?  coalesced_bus[32 * 222 - 1 : 32 * 221] :
                    (dbg_sel == 222) ?  coalesced_bus[32 * 223 - 1 : 32 * 222] :
                    (dbg_sel == 223) ?  coalesced_bus[32 * 224 - 1 : 32 * 223] :
                    (dbg_sel == 224) ?  coalesced_bus[32 * 225 - 1 : 32 * 224] :
                    (dbg_sel == 225) ?  coalesced_bus[32 * 226 - 1 : 32 * 225] :
                    (dbg_sel == 226) ?  coalesced_bus[32 * 227 - 1 : 32 * 226] :
                    (dbg_sel == 227) ?  coalesced_bus[32 * 228 - 1 : 32 * 227] :
                    (dbg_sel == 228) ?  coalesced_bus[32 * 229 - 1 : 32 * 228] :
                    (dbg_sel == 229) ?  coalesced_bus[32 * 230 - 1 : 32 * 229] :
                    (dbg_sel == 230) ?  coalesced_bus[32 * 231 - 1 : 32 * 230] :
                    (dbg_sel == 231) ?  coalesced_bus[32 * 232 - 1 : 32 * 231] : 
                    (dbg_sel >= 232 && dbg_sel <= 232 + `DBG_NUM_RDMA_ENGINE - 1) ? wv_rdma_engine_dbg_bus : 
                    (dbg_sel >= 232 + `DBG_NUM_RDMA_ENGINE && dbg_sel <= 232 + `DBG_NUM_RDMA_ENGINE + `DBG_NUM_MISC_LAYER - 1) ? wv_misc_layer_dbg_bus : 32'd0;

//assign dbg_bus = {coalesced_bus, wv_rdma_engine_dbg_bus, wv_misc_layer_dbg_bus};

assign rw_init_data = {
						{wv_misc_layer_init_rw_data},
						{wv_init_rw_data_RDMAEngine},
						{44{32'd0}}
};

assign ro_data = {wv_misc_layer_ro_data, rw_data[115 * 32 - 1 : 0]};

wire    [42:0]      debug_nets;

assign debug_nets = {
w_pio_empty,
o_db_cxtmgt_cmd_empty,
w_db_cxtmgt_resp_empty,
w_db_cxtmgt_cxt_download_empty,
o_wp_cxtmgt_cmd_empty,
w_wp_cxtmgt_resp_empty,
w_wp_cxtmgt_cxt_download_empty,
o_rtc_cxtmgt_cmd_empty,
w_rtc_cxtmgt_resp_empty,
w_rtc_cxtmgt_cxt_download_empty,
o_rtc_cxtmgt_cxt_upload_empty,
o_rrc_cxtmgt_cmd_empty,
w_rrc_cxtmgt_resp_empty,
w_rrc_cxtmgt_cxt_download_empty,
o_rrc_cxtmgt_cxt_upload_empty,
o_ee_cxtmgt_cmd_empty,
w_ee_cxtmgt_resp_empty,
w_ee_cxtmgt_cxt_download_empty,
o_ee_cxtmgt_cxt_upload_empty,
o_db_vtp_cmd_empty,
w_db_vtp_resp_empty,
w_db_vtp_download_empty,
o_wp_vtp_wqe_cmd_empty,
w_wp_vtp_wqe_resp_empty,
w_wp_vtp_wqe_download_empty,
o_wp_vtp_nd_cmd_empty,
w_wp_vtp_nd_resp_empty,
w_wp_vtp_nd_download_empty,
o_rtc_vtp_cmd_empty,
w_rtc_vtp_resp_empty,
o_rtc_vtp_upload_empty,
o_rrc_vtp_cmd_empty,
w_rrc_vtp_resp_empty,
o_rrc_vtp_upload_empty,
o_ee_vtp_cmd_empty,
w_ee_vtp_resp_empty,
o_ee_vtp_upload_empty,
w_ee_vtp_download_empty,
o_rwm_vtp_cmd_empty,
w_rwm_vtp_resp_empty,
w_rwm_vtp_download_empty,
o_desc_empty,
o_roce_egress_empty
};

ila_rdma_wrapper ila_wrapper (
    .clk(clk), // input wire clk
    .probe0(debug_nets) // input wire [42:0] probe0
);

reg             [31:0]          vtp_rsp_cnt;


always @(posedge clk or posedge rst) begin
    if(rst) begin
        vtp_rsp_cnt <= 'd0;
    end 
    else if(i_wp_vtp_nd_download_wr_en) begin
        vtp_rsp_cnt <= vtp_rsp_cnt + 'd1;
    end 
    else begin
        vtp_rsp_cnt <= vtp_rsp_cnt;
    end 
end 

ila_counter_probe ila_counter_probe_inst(
    .clk(clk),
    .probe0(vtp_rsp_cnt),
    .probe1(vtp_rsp_cnt)
);

endmodule

