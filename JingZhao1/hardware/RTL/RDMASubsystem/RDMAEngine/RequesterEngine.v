`timescale 1ns / 1ps

`include "nic_hw_params.vh"
`include "chip_include_rdma.vh"

module RequesterEngine
#(
    parameter RW_REG_NUM = 34
)
( //"re" for short
    input   wire                clk,
    input   wire                rst,

	input 	wire 	[RW_REG_NUM * 32 - 1 : 0]	rw_data,
	output 	wire 	[RW_REG_NUM * 32 - 1 : 0]	init_rw_data,

//Interface with SendWQEProcessing->DataPack
    input   wire                i_atomics_from_dp_empty,
    output  wire                o_atomics_from_dp_rd_en,
    input   wire    [127:0]     iv_atomics_from_dp_data,

    input   wire                i_raddr_from_dp_empty,
    output  wire                o_raddr_from_dp_rd_en,
    input   wire    [127:0]     iv_raddr_from_dp_data,

    input   wire    [127:0]     iv_entry_from_dp_data,
    input   wire                i_entry_from_dp_empty,
    output  wire                o_entry_from_dp_rd_en,

    input   wire                i_md_from_dp_empty,
    output  wire                o_md_from_dp_rd_en,
    //input   wire    [287:0]     iv_md_from_dp_data,
    input   wire    [367:0]     iv_md_from_dp_data,

    input   wire                i_nd_from_dp_empty,
    output  wire                o_nd_from_dp_rd_en,
    input   wire    [255:0]     iv_nd_from_dp_data,

//Interface with CompletionQueueManagement
    output   wire                o_rtc_req_valid,
    output   wire    [23:0]      ov_rtc_cq_index,
    output   wire    [31:0]       ov_rtc_cq_size,
    input  wire                i_rtc_resp_valid,
    input  wire     [23:0]     iv_rtc_cq_offset,

    output   wire                o_rrc_req_valid,
    output   wire    [23:0]      ov_rrc_cq_index,
    output   wire    [31:0]       ov_rrc_cq_size,
    input  wire                i_rrc_resp_valid,
    input  wire     [23:0]     iv_rrc_cq_offset,



//Interface with BitWidthTrans
    input   wire                i_rpg_trans_prog_full,
    output  wire                o_rpg_trans_wr_en,
    output  wire    [255:0]     ov_rpg_trans_data,

//Interface with CxtMgt
    //Channel 1
    output  wire                o_rtc_cxtmgt_cmd_wr_en,
    input   wire                i_rtc_cxtmgt_cmd_prog_full,
    output  wire    [127:0]     ov_rtc_cxtmgt_cmd_data,

    input   wire                i_rtc_cxtmgt_resp_empty,
    output  wire                o_rtc_cxtmgt_resp_rd_en,
    input   wire    [127:0]     iv_rtc_cxtmgt_resp_data,

    input   wire                i_rtc_cxtmgt_cxt_empty,
    output  wire                o_rtc_cxtmgt_cxt_rd_en,
    input   wire    [191:0]     iv_rtc_cxtmgt_cxt_data,

    input   wire                i_rtc_cxtmgt_cxt_prog_full,
    output  wire                o_rtc_cxtmgt_cxt_wr_en,
    output  wire    [127:0]     ov_rtc_cxtmgt_cxt_data,

    //Channel 2
    output  wire                o_rrc_cxtmgt_cmd_wr_en,
    input   wire                i_rrc_cxtmgt_cmd_prog_full,
    output  wire    [127:0]     ov_rrc_cxtmgt_cmd_data,

    input   wire                i_rrc_cxtmgt_resp_empty,
    output  wire                o_rrc_cxtmgt_resp_rd_en,
    input   wire    [127:0]     iv_rrc_cxtmgt_resp_data,

    input   wire                i_rrc_cxtmgt_cxt_empty,
    output  wire                o_rrc_cxtmgt_cxt_rd_en,
    input   wire    [255:0]     iv_rrc_cxtmgt_cxt_data,

    output  wire                o_rrc_cxtmgt_cxt_wr_en,
    input   wire                i_rrc_cxtmgt_cxt_prog_full,
    output  wire    [127:0]     ov_rrc_cxtmgt_cxt_data,

//VirtToPhys
    //Channel 1
    output  wire                o_rtc_vtp_cmd_wr_en,
    input   wire                i_rtc_vtp_cmd_prog_full,
    output  wire    [255:0]     ov_rtc_vtp_cmd_data,

    input   wire                i_rtc_vtp_resp_empty,
    output  wire                o_rtc_vtp_resp_rd_en,
    input   wire    [7:0]       iv_rtc_vtp_resp_data,

    output  wire                o_rtc_vtp_upload_wr_en,
    input   wire                i_rtc_vtp_upload_prog_full,
    output  wire    [255:0]     ov_rtc_vtp_upload_data,

    //Channel 2
    output  wire                o_rrc_vtp_cmd_wr_en,
    input   wire                i_rrc_vtp_cmd_prog_full,
    output  wire    [255:0]     ov_rrc_vtp_cmd_data,

    input   wire                i_rrc_vtp_resp_empty,
    output  wire                o_rrc_vtp_resp_rd_en,
    input   wire    [7:0]       iv_rrc_vtp_resp_data,

    output  wire                o_rrc_vtp_upload_wr_en,
    input   wire                i_rrc_vtp_upload_prog_full,
    output  wire    [255:0]     ov_rrc_vtp_upload_data,

//Header Parser
    input   wire                i_header_from_hp_empty,
    output  wire                o_header_from_hp_rd_en,
    input   wire    [239:0]     iv_header_from_hp_data,

    input   wire    [255:0]     iv_nd_from_hp_data,
    input   wire                i_nd_from_hp_empty,
    output  wire                o_nd_from_hp_rd_en,

    input   wire    [31:0]      dbg_sel,
    output  wire    [32 - 1 :0]      dbg_bus,
    //output  wire    [`DBG_NUM_REQUESTER_ENGINE * 32 - 1 :0]      dbg_bus,

	output	wire 				o_req_engine_init_finish

);
/********************************************* Submodule connections ****************************************/
//wire        [31:0]      wv_rtc_dbg_sel;
//wire        [`DBG_NUM_REQUESTER_TRANS_CONTROL * 32 - 1:0]      wv_rtc_dbg_bus;
//wire        [31:0]      wv_rrc_dbg_sel;
//wire        [`DBG_NUM_REQUESTER_RECV_CONTROL * 32 - 1:0]      wv_rrc_dbg_bus;
//wire        [31:0]      wv_mq_dbg_sel;
//wire        [`DBG_NUM_MULTI_QUEUE * 32 - 1:0]      wv_mq_dbg_bus;
//wire        [31:0]      wv_tc_dbg_sel;
//wire        [`DBG_NUM_TIMER_CONTROL * 32 - 1:0]      wv_tc_dbg_bus;
//wire        [31:0]      wv_rpg_dbg_sel;
//wire        [`DBG_NUM_REQ_PKT_GEN * 32 - 1:0]      wv_rpg_dbg_bus;
wire        [31:0]      wv_rtc_dbg_sel;
wire        [32 - 1:0]      wv_rtc_dbg_bus;
wire        [31:0]      wv_rrc_dbg_sel;
wire        [32 - 1:0]      wv_rrc_dbg_bus;
wire        [31:0]      wv_mq_dbg_sel;
wire        [32 - 1:0]      wv_mq_dbg_bus;
wire        [31:0]      wv_tc_dbg_sel;
wire        [32 - 1:0]      wv_tc_dbg_bus;
wire        [31:0]      wv_rpg_dbg_sel;
wire        [32 - 1:0]      wv_rpg_dbg_bus;

assign wv_rtc_dbg_sel = dbg_sel - `DBG_NUM_ZERO;
assign wv_rrc_dbg_sel = dbg_sel - (`DBG_NUM_REQUESTER_TRANS_CONTROL);
assign wv_mq_dbg_sel = dbg_sel - (`DBG_NUM_REQUESTER_TRANS_CONTROL + `DBG_NUM_REQUESTER_RECV_CONTROL);
assign wv_tc_dbg_sel = dbg_sel - (`DBG_NUM_REQUESTER_TRANS_CONTROL + `DBG_NUM_REQUESTER_RECV_CONTROL + `DBG_NUM_MULTI_QUEUE);
assign wv_rpg_dbg_sel = dbg_sel - (`DBG_NUM_REQUESTER_TRANS_CONTROL + `DBG_NUM_REQUESTER_RECV_CONTROL + `DBG_NUM_MULTI_QUEUE + `DBG_NUM_REQ_PKT_GEN);

assign dbg_bus =    (dbg_sel >= `DBG_NUM_ZERO && dbg_sel <= `DBG_NUM_REQUESTER_TRANS_CONTROL - 1) ? wv_rtc_dbg_bus :
                    (dbg_sel >= `DBG_NUM_REQUESTER_TRANS_CONTROL && dbg_sel <=`DBG_NUM_REQUESTER_TRANS_CONTROL + `DBG_NUM_REQUESTER_RECV_CONTROL - 1) ? wv_rrc_dbg_bus :
                    (dbg_sel >= `DBG_NUM_REQUESTER_TRANS_CONTROL + `DBG_NUM_REQUESTER_RECV_CONTROL && dbg_sel <= `DBG_NUM_REQUESTER_TRANS_CONTROL + `DBG_NUM_REQUESTER_RECV_CONTROL + `DBG_NUM_MULTI_QUEUE - 1) ? wv_mq_dbg_bus :
                    (dbg_sel >= `DBG_NUM_REQUESTER_TRANS_CONTROL + `DBG_NUM_REQUESTER_RECV_CONTROL + `DBG_NUM_MULTI_QUEUE && dbg_sel <= `DBG_NUM_REQUESTER_TRANS_CONTROL + `DBG_NUM_REQUESTER_RECV_CONTROL + `DBG_NUM_MULTI_QUEUE + `DBG_NUM_TIMER_CONTROL - 1) ? wv_tc_dbg_bus :
                    (dbg_sel >= `DBG_NUM_REQUESTER_TRANS_CONTROL + `DBG_NUM_REQUESTER_RECV_CONTROL + `DBG_NUM_MULTI_QUEUE + `DBG_NUM_TIMER_CONTROL && dbg_sel <= `DBG_NUM_REQUESTER_TRANS_CONTROL + `DBG_NUM_REQUESTER_RECV_CONTROL + `DBG_NUM_MULTI_QUEUE + `DBG_NUM_TIMER_CONTROL + `DBG_NUM_REQ_PKT_GEN - 1) ? wv_rpg_dbg_bus : 32'd0;

//assign dbg_bus = {wv_rtc_dbg_bus, wv_rrc_dbg_bus, wv_mq_dbg_bus, wv_tc_dbg_bus, wv_rpg_dbg_bus};

//
//Port A for TDP
wire                    w_rpb_list_head_wea;
wire        [13:0]      wv_rpb_list_head_addra;
wire        [8:0]       wv_rpb_list_head_dina;
wire        [8:0]       wv_rpb_list_head_douta;

wire                    w_rpb_list_tail_wea;
wire        [13:0]      wv_rpb_list_tail_addra;
wire        [8:0]       wv_rpb_list_tail_dina;
wire        [8:0]       wv_rpb_list_tail_douta;

wire                    w_rpb_list_empty_wea;
wire        [13:0]      wv_rpb_list_empty_addra;
wire        [0:0]       wv_rpb_list_empty_dina;
wire        [0:0]       wv_rpb_list_empty_douta;

wire                    w_rpb_content_wea;
wire        [8:0]       wv_rpb_content_addra;
wire        [261:0]     wv_rpb_content_dina;
wire        [261:0]     wv_rpb_content_douta;

wire                    w_rpb_next_wea;
wire        [8:0]       wv_rpb_next_addra;
wire        [9:0]       wv_rpb_next_dina;
wire        [9:0]       wv_rpb_next_douta;

wire                    w_reb_list_head_wea;
wire        [13:0]      wv_reb_list_head_addra;
wire        [13:0]      wv_reb_list_head_dina;
wire        [13:0]      wv_reb_list_head_douta;

wire                    w_reb_list_tail_wea;
wire        [13:0]      wv_reb_list_tail_addra;
wire        [13:0]      wv_reb_list_tail_dina;
wire        [13:0]      wv_reb_list_tail_douta;

wire                    w_reb_list_empty_wea;
wire        [13:0]      wv_reb_list_empty_addra;
wire        [0:0]       wv_reb_list_empty_dina;
wire        [0:0]       wv_reb_list_empty_douta;


wire                    w_reb_content_wea;
wire        [13:0]      wv_reb_content_addra;
wire        [127:0]     wv_reb_content_dina;
wire        [127:0]     wv_reb_content_douta;

wire                    w_reb_next_wea;
wire        [13:0]      wv_reb_next_addra;
wire        [14:0]      wv_reb_next_dina;
wire        [14:0]      wv_reb_next_douta;


wire                    w_swpb_list_head_wea;
wire        [13:0]      wv_swpb_list_head_addra;
wire        [11:0]      wv_swpb_list_head_dina;
wire        [11:0]      wv_swpb_list_head_douta;

wire                    w_swpb_list_tail_wea;
wire        [13:0]      wv_swpb_list_tail_addra;
wire        [11:0]      wv_swpb_list_tail_dina;
wire        [11:0]      wv_swpb_list_tail_douta;

wire                    w_swpb_list_empty_wea;
wire        [13:0]      wv_swpb_list_empty_addra;
wire        [0:0]       wv_swpb_list_empty_dina;
wire        [0:0]       wv_swpb_list_empty_douta;

wire                    w_swpb_content_wea;
wire        [11:0]      wv_swpb_content_addra;
wire        [287:0]     wv_swpb_content_dina;
wire        [287:0]     wv_swpb_content_douta;

wire                    w_swpb_next_wea;
wire        [11:0]      wv_swpb_next_addra;
wire        [12:0]      wv_swpb_next_dina;
wire        [12:0]      wv_swpb_next_douta;

wire        [8:0]       wv_rpb_free_din;
wire                    w_rpb_free_wr_en;
wire                    w_rpb_free_prog_full;
wire        [9:0]       wv_rpb_free_data_count;

wire        [13:0]      wv_reb_free_din;
wire                    w_reb_free_wr_en;
wire                    w_reb_free_prog_full;
wire        [14:0]      wv_reb_free_data_count;

wire        [11:0]      wv_swpb_free_din;
wire                    w_swpb_free_wr_en;
wire                    w_swpb_free_prog_full;
wire        [12:0]      wv_swpb_free_data_count;

//Port B for TDP
wire                    w_rpb_list_head_web;
wire        [13:0]      wv_rpb_list_head_addrb;
wire        [8:0]       wv_rpb_list_head_dinb;
wire        [8:0]       wv_rpb_list_head_doutb;

wire                    w_rpb_list_tail_web;
wire        [13:0]      wv_rpb_list_tail_addrb;
wire        [8:0]       wv_rpb_list_tail_dinb;
wire        [8:0]       wv_rpb_list_tail_doutb;

wire                    w_rpb_list_empty_web;
wire        [13:0]      wv_rpb_list_empty_addrb;
wire        [0:0]       wv_rpb_list_empty_dinb;
wire        [0:0]       wv_rpb_list_empty_doutb;

wire                    w_rpb_content_web;
wire        [8:0]       wv_rpb_content_addrb;
wire        [261:0]     wv_rpb_content_dinb;
wire        [261:0]     wv_rpb_content_doutb;

wire                    w_rpb_next_web;
wire        [8:0]       wv_rpb_next_addrb;
wire        [9:0]       wv_rpb_next_dinb;
wire        [9:0]       wv_rpb_next_doutb;

wire                    w_reb_list_head_web;
wire        [13:0]      wv_reb_list_head_addrb;
wire        [13:0]      wv_reb_list_head_dinb;
wire        [13:0]      wv_reb_list_head_doutb;

wire                    w_reb_list_tail_web;
wire        [13:0]      wv_reb_list_tail_addrb;
wire        [13:0]      wv_reb_list_tail_dinb;
wire        [13:0]      wv_reb_list_tail_doutb;

wire                    w_reb_list_empty_web;
wire        [13:0]      wv_reb_list_empty_addrb;
wire        [0:0]       wv_reb_list_empty_dinb;
wire        [0:0]       wv_reb_list_empty_doutb;

wire                    w_reb_content_web;
wire        [13:0]      wv_reb_content_addrb;
wire        [127:0]     wv_reb_content_dinb;
wire        [127:0]     wv_reb_content_doutb;

wire                    w_reb_next_web;
wire        [13:0]      wv_reb_next_addrb;
wire        [14:0]      wv_reb_next_dinb;
wire        [14:0]      wv_reb_next_doutb;


wire                    w_swpb_list_head_web;
wire        [13:0]      wv_swpb_list_head_addrb;
wire        [11:0]      wv_swpb_list_head_dinb;
wire        [11:0]      wv_swpb_list_head_doutb;

wire                    w_swpb_list_tail_web;
wire        [13:0]      wv_swpb_list_tail_addrb;
wire        [11:0]      wv_swpb_list_tail_dinb;
wire        [11:0]      wv_swpb_list_tail_doutb;

wire                    w_swpb_list_empty_web;
wire        [13:0]      wv_swpb_list_empty_addrb;
wire        [0:0]       wv_swpb_list_empty_dinb;
wire        [0:0]       wv_swpb_list_empty_doutb;

wire                    w_swpb_content_web;
wire        [11:0]      wv_swpb_content_addrb;
wire        [287:0]     wv_swpb_content_dinb;
wire        [287:0]     wv_swpb_content_doutb;

wire                    w_swpb_next_web;
wire        [11:0]      wv_swpb_next_addrb;
wire        [12:0]      wv_swpb_next_dinb;
wire        [12:0]      wv_swpb_next_doutb;

wire                    w_rpb_free_empty;
wire        [8:0]       wv_rpb_free_dout;
wire                    w_rpb_free_rd_en;

wire                    w_reb_free_empty;
wire        [13:0]      wv_reb_free_dout;
wire                    w_reb_free_rd_en;

wire                    w_swpb_free_empty;
wire        [11:0]      wv_swpb_free_dout;
wire                    w_swpb_free_rd_en;

wire 					w_timer_init_finish;
wire 					w_rrc_init_finish;

wire        [63:0]      wv_loss_timer_rtc_setting_din;
wire                    w_loss_timer_rtc_setting_wr_en;
wire                    w_loss_timer_rtc_setting_rd_en;
wire        [63:0]      wv_loss_timer_rtc_setting_dout;
wire                    w_loss_timer_rtc_setting_empty;
wire                    w_loss_timer_rtc_setting_prog_full;
SyncFIFO_64w_32d LOSS_TIMER_RTC_SETTING_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[0 * 32 + 1 : 0 * 32 + 0]),
	.WTSEL( rw_data[0 * 32 + 3 : 0 * 32 + 2]),
	.PTSEL( rw_data[0 * 32 + 5 : 0 * 32 + 4]),
	.VG(    rw_data[0 * 32 + 6 : 0 * 32 + 6]),
	.VS(    rw_data[0 * 32 + 7 : 0 * 32 + 7]),

  `endif

  .clk(clk),              
  .srst(rst),            
  .din(wv_loss_timer_rtc_setting_din),              
  .wr_en(w_loss_timer_rtc_setting_wr_en),          
  .rd_en(w_loss_timer_rtc_setting_rd_en),          
  .dout(wv_loss_timer_rtc_setting_dout),            
  .full(),            
  .empty(w_loss_timer_rtc_setting_empty),          
  .prog_full(w_loss_timer_rtc_setting_prog_full)  
);

wire        [63:0]      wv_loss_timer_rrc_setting_din;
wire                    w_loss_timer_rrc_setting_wr_en;
wire                    w_loss_timer_rrc_setting_rd_en;
wire        [63:0]      wv_loss_timer_rrc_setting_dout;
wire                    w_loss_timer_rrc_setting_empty;
wire                    w_loss_timer_rrc_setting_prog_full;
SyncFIFO_64w_32d LOSS_TIMER_RRC_SETTING_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[1 * 32 + 1 : 1 * 32 + 0]),
	.WTSEL( rw_data[1 * 32 + 3 : 1 * 32 + 2]),
	.PTSEL( rw_data[1 * 32 + 5 : 1 * 32 + 4]),
	.VG(    rw_data[1 * 32 + 6 : 1 * 32 + 6]),
	.VS(    rw_data[1 * 32 + 7 : 1 * 32 + 7]),

  `endif

  .clk(clk),              
  .srst(rst),            
  .din(wv_loss_timer_rrc_setting_din),              
  .wr_en(w_loss_timer_rrc_setting_wr_en),          
  .rd_en(w_loss_timer_rrc_setting_rd_en),          
  .dout(wv_loss_timer_rrc_setting_dout),            
  .full(),            
  .empty(w_loss_timer_rrc_setting_empty),          
  .prog_full(w_loss_timer_rrc_setting_prog_full)  
);

wire        [63:0]      wv_rnr_timer_setting_din;
wire                    w_rnr_timer_setting_wr_en;
wire                    w_rnr_timer_setting_rd_en;
wire        [63:0]      wv_rnr_timer_setting_dout;
wire                    w_rnr_timer_setting_empty;
wire                    w_rnr_timer_setting_prog_full;
SyncFIFO_64w_32d RNR_TIMER_SETTING_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[2 * 32 + 1 : 2 * 32 + 0]),
	.WTSEL( rw_data[2 * 32 + 3 : 2 * 32 + 2]),
	.PTSEL( rw_data[2 * 32 + 5 : 2 * 32 + 4]),
	.VG(    rw_data[2 * 32 + 6 : 2 * 32 + 6]),
	.VS(    rw_data[2 * 32 + 7 : 2 * 32 + 7]),

  `endif

  .clk(clk),              
  .srst(rst),            
  .din(wv_rnr_timer_setting_din),              
  .wr_en(w_rnr_timer_setting_wr_en),          
  .rd_en(w_rnr_timer_setting_rd_en),          
  .dout(wv_rnr_timer_setting_dout),            
  .full(),            
  .empty(w_rnr_timer_setting_empty),          
  .prog_full(w_rnr_timer_setting_prog_full)  
);

wire        [31:0]      wv_loss_timer_expire_din;
wire                    w_loss_timer_expire_wr_en;
wire                    w_loss_timer_expire_rd_en;
wire        [31:0]      wv_loss_timer_expire_dout;
wire                    w_loss_timer_expire_empty;
wire                    w_loss_timer_expire_prog_full;
SyncFIFO_32w_32d LOSS_TIMER_EXPIRE_FIFO(
    `ifdef CHIP_VERSION
	.RTSEL( rw_data[3 * 32 + 1 : 3 * 32 + 0]),
	.WTSEL( rw_data[3 * 32 + 3 : 3 * 32 + 2]),
	.PTSEL( rw_data[3 * 32 + 5 : 3 * 32 + 4]),
	.VG(    rw_data[3 * 32 + 6 : 3 * 32 + 6]),
	.VS(    rw_data[3 * 32 + 7 : 3 * 32 + 7]),
  `endif

  .clk(clk),              
  .srst(rst),            
  .din(wv_loss_timer_expire_din),              
  .wr_en(w_loss_timer_expire_wr_en),          
  .rd_en(w_loss_timer_expire_rd_en),          
  .dout(wv_loss_timer_expire_dout),            
  .full(),            
  .empty(w_loss_timer_expire_empty),          
  .prog_full(w_loss_timer_expire_prog_full)  
);

wire        [31:0]      wv_rnr_timer_expire_din;
wire                    w_rnr_timer_expire_wr_en;
wire                    w_rnr_timer_expire_rd_en;
wire        [31:0]      wv_rnr_timer_expire_dout;
wire                    w_rnr_timer_expire_empty;
wire                    w_rnr_timer_expire_prog_full;
SyncFIFO_32w_32d RNR_TIMER_EXPIRE_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[4 * 32 + 1 : 4 * 32 + 0]),
	.WTSEL( rw_data[4 * 32 + 3 : 4 * 32 + 2]),
	.PTSEL( rw_data[4 * 32 + 5 : 4 * 32 + 4]),
	.VG(    rw_data[4 * 32 + 6 : 4 * 32 + 6]),
	.VS(    rw_data[4 * 32 + 7 : 4 * 32 + 7]),
  `endif

  .clk(clk),              
  .srst(rst),            
  .din(wv_rnr_timer_expire_din),              
  .wr_en(w_rnr_timer_expire_wr_en),          
  .rd_en(w_rnr_timer_expire_rd_en),          
  .dout(wv_rnr_timer_expire_dout),            
  .full(),            
  .empty(w_rnr_timer_expire_empty),          
  .prog_full(w_rnr_timer_expire_prog_full)  
);

wire        [127:0]      wv_bad_req_din;
wire                    w_bad_req_wr_en;
wire                    w_bad_req_rd_en;
wire        [127:0]      wv_bad_req_dout;
wire                    w_bad_req_empty;
wire                    w_bad_req_prog_full;
SyncFIFO_128w_32d BAD_REQ_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[5 * 32 + 1 : 5 * 32 + 0]),
	.WTSEL( rw_data[5 * 32 + 3 : 5 * 32 + 2]),
	.PTSEL( rw_data[5 * 32 + 5 : 5 * 32 + 4]),
	.VG(    rw_data[5 * 32 + 6 : 5 * 32 + 6]),
	.VS(    rw_data[5 * 32 + 7 : 5 * 32 + 7]),
  `endif

  .clk(clk),              
  .srst(rst),            
  .din(wv_bad_req_din),              
  .wr_en(w_bad_req_wr_en),          
  .rd_en(w_bad_req_rd_en),          
  .dout(wv_bad_req_dout),            
  .full(),            
  .empty(w_bad_req_empty),          
  .prog_full(w_bad_req_prog_full)   
);

wire        [319:0]     wv_header_from_rtc_to_rpg_din;
wire                    w_header_from_rtc_to_rpg_wr_en;
wire                    w_header_from_rtc_to_rpg_rd_en;
wire        [319:0]     wv_header_from_rtc_to_rpg_dout;
wire                    w_header_from_rtc_to_rpg_empty;
wire                    w_header_from_rtc_to_rpg_prog_full;
//RPG can be short for "Request Packet Generation" or "Response Packet Generation", here is the former
SyncFIFO_320w_16d HEADER_FROM_RTC_TO_RPG_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[6 * 32 + 1 : 6 * 32 + 0]),
	.WTSEL( rw_data[6 * 32 + 3 : 6 * 32 + 2]),
	.PTSEL( rw_data[6 * 32 + 5 : 6 * 32 + 4]),
	.VG(    rw_data[6 * 32 + 6 : 6 * 32 + 6]),
	.VS(    rw_data[6 * 32 + 7 : 6 * 32 + 7]),
  `endif

  .clk(clk),              
  .srst(rst),            
  .din(wv_header_from_rtc_to_rpg_din),              
  .wr_en(w_header_from_rtc_to_rpg_wr_en),          
  .rd_en(w_header_from_rtc_to_rpg_rd_en),          
  .dout(wv_header_from_rtc_to_rpg_dout),            
  .full(),            
  .empty(w_header_from_rtc_to_rpg_empty),          
  .prog_full(w_header_from_rtc_to_rpg_prog_full)   
);

wire        [255:0]     wv_nd_from_rtc_to_rpg_din;
wire                    w_nd_from_rtc_to_rpg_wr_en;
wire                    w_nd_from_rtc_to_rpg_rd_en;
wire        [255:0]     wv_nd_from_rtc_to_rpg_dout;
wire                    w_nd_from_rtc_to_rpg_empty;
wire                    w_nd_from_rtc_to_rpg_prog_full;
//At least buffer two Packets
SyncFIFO_256w_16d ND_FROM_RTC_TO_RPG_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[7 * 32 + 1 : 7 * 32 + 0]),
	.WTSEL( rw_data[7 * 32 + 3 : 7 * 32 + 2]),
	.PTSEL( rw_data[7 * 32 + 5 : 7 * 32 + 4]),
	.VG(    rw_data[7 * 32 + 6 : 7 * 32 + 6]),
	.VS(    rw_data[7 * 32 + 7 : 7 * 32 + 7]),
  `endif

  .clk(clk),              
  .srst(rst),            
  .din(wv_nd_from_rtc_to_rpg_din),              
  .wr_en(w_nd_from_rtc_to_rpg_wr_en),          
  .rd_en(w_nd_from_rtc_to_rpg_rd_en),          
  .dout(wv_nd_from_rtc_to_rpg_dout),            
  .full(),            
  .empty(w_nd_from_rtc_to_rpg_empty),          
  .prog_full(w_nd_from_rtc_to_rpg_prog_full)   
);

wire        [319:0]     wv_header_from_rrc_to_rpg_din;
wire                    w_header_from_rrc_to_rpg_wr_en;
wire                    w_header_from_rrc_to_rpg_rd_en;
wire        [319:0]     wv_header_from_rrc_to_rpg_dout;
wire                    w_header_from_rrc_to_rpg_empty;
wire                    w_header_from_rrc_to_rpg_prog_full;
SyncFIFO_320w_16d HEADER_FROM_RRC_TO_RPG_FIFO(
    `ifdef CHIP_VERSION
	.RTSEL( rw_data[8 * 32 + 1 : 8 * 32 + 0]),
	.WTSEL( rw_data[8 * 32 + 3 : 8 * 32 + 2]),
	.PTSEL( rw_data[8 * 32 + 5 : 8 * 32 + 4]),
	.VG(    rw_data[8 * 32 + 6 : 8 * 32 + 6]),
	.VS(    rw_data[8 * 32 + 7 : 8 * 32 + 7]),
  `endif

  .clk(clk),              
  .srst(rst),            
  .din(wv_header_from_rrc_to_rpg_din),              
  .wr_en(w_header_from_rrc_to_rpg_wr_en),          
  .rd_en(w_header_from_rrc_to_rpg_rd_en),          
  .dout(wv_header_from_rrc_to_rpg_dout),            
  .full(),            
  .empty(w_header_from_rrc_to_rpg_empty),          
  .prog_full(w_header_from_rrc_to_rpg_prog_full)   
);

wire        [255:0]     wv_nd_from_rrc_to_rpg_din;
wire                    w_nd_from_rrc_to_rpg_wr_en;
wire                    w_nd_from_rrc_to_rpg_rd_en;
wire        [255:0]     wv_nd_from_rrc_to_rpg_dout;
wire                    w_nd_from_rrc_to_rpg_empty;
wire                    w_nd_from_rrc_to_rpg_prog_full;
SyncFIFO_256w_16d ND_FROM_RRC_TO_RPG_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[9 * 32 + 1 : 9 * 32 + 0]),
	.WTSEL( rw_data[9 * 32 + 3 : 9 * 32 + 2]),
	.PTSEL( rw_data[9 * 32 + 5 : 9 * 32 + 4]),
	.VG(    rw_data[9 * 32 + 6 : 9 * 32 + 6]),
	.VS(    rw_data[9 * 32 + 7 : 9 * 32 + 7]),
  `endif

  .clk(clk),              
  .srst(rst),            
  .din(wv_nd_from_rrc_to_rpg_din),              
  .wr_en(w_nd_from_rrc_to_rpg_wr_en),          
  .rd_en(w_nd_from_rrc_to_rpg_rd_en),          
  .dout(wv_nd_from_rrc_to_rpg_dout),            
  .full(),            
  .empty(w_nd_from_rrc_to_rpg_empty),          
  .prog_full(w_nd_from_rrc_to_rpg_prog_full)   
);

// wire    [0:0]       w_cq_offset_table_wea;
// wire    [13:0]      wv_cq_offset_table_addra;
// wire    [15:0]      wv_cq_offset_table_dina;
// wire    [15:0]      wv_cq_offset_table_douta;
// wire    [0:0]       w_cq_offset_table_web;
// wire    [13:0]      wv_cq_offset_table_addrb;
// wire    [15:0]      wv_cq_offset_table_dinb;
// wire    [15:0]      wv_cq_offset_table_doutb;
// BRAM_TDP_16w_16384d CQ_OFFSET_TABLE(
//   `endif

//  .clka(clk),    
//   .ena(1'b1),      
//   .wea(w_cq_offset_table_wea),      
//   .addra(wv_cq_offset_table_addra),  
//   .dina(wv_cq_offset_table_dina),    
//   .douta(wv_cq_offset_table_douta),  
//   .clkb(clk),    
//   .enb(1'b1),      
//   .web(w_cq_offset_table_web),      
//   .addrb(wv_cq_offset_table_addrb),  
//   .dinb(wv_cq_offset_table_dinb),    
//   .doutb(wv_cq_offset_table_doutb)  
// );

RequesterTransControl RequesterTransControl_Inst(
    .clk(clk),
    .rst(rst),

//Interface with DataPack
    .i_atomics_from_dp_empty(i_atomics_from_dp_empty),
    .o_atomics_from_dp_rd_en(o_atomics_from_dp_rd_en),
    .iv_atomics_from_dp_data(iv_atomics_from_dp_data),

    .i_raddr_from_dp_empty(i_raddr_from_dp_empty),
    .o_raddr_from_dp_rd_en(o_raddr_from_dp_rd_en),
    .iv_raddr_from_dp_data(iv_raddr_from_dp_data),

    .iv_entry_from_dp_data(iv_entry_from_dp_data),
    .i_entry_from_dp_empty(i_entry_from_dp_empty),
    .o_entry_from_dp_rd_en(o_entry_from_dp_rd_en),

    .i_md_from_dp_empty(i_md_from_dp_empty),
    .o_md_from_dp_rd_en(o_md_from_dp_rd_en),
    .iv_md_from_dp_data(iv_md_from_dp_data),

    .i_nd_from_dp_empty(i_nd_from_dp_empty),
    .o_nd_from_dp_rd_en(o_nd_from_dp_rd_en),
    .iv_nd_from_dp_data(iv_nd_from_dp_data),

//CxtMgt
    .o_cxtmgt_cmd_wr_en(o_rtc_cxtmgt_cmd_wr_en),
    .i_cxtmgt_cmd_prog_full(i_rtc_cxtmgt_cmd_prog_full),
    .ov_cxtmgt_cmd_data(ov_rtc_cxtmgt_cmd_data),

    .i_cxtmgt_resp_empty(i_rtc_cxtmgt_resp_empty),
    .o_cxtmgt_resp_rd_en(o_rtc_cxtmgt_resp_rd_en),
    .iv_cxtmgt_resp_data(iv_rtc_cxtmgt_resp_data),

    .i_cxtmgt_cxt_empty(i_rtc_cxtmgt_cxt_empty),
    .o_cxtmgt_cxt_rd_en(o_rtc_cxtmgt_cxt_rd_en),
    .iv_cxtmgt_cxt_data(iv_rtc_cxtmgt_cxt_data),

    .i_cxtmgt_cxt_prog_full(i_rtc_cxtmgt_cxt_prog_full),
    .o_cxtmgt_cxt_wr_en(o_rtc_cxtmgt_cxt_wr_en),
    .ov_cxtmgt_cxt_data(ov_rtc_cxtmgt_cxt_data),

//VirtToPhys
    .o_vtp_cmd_wr_en(o_rtc_vtp_cmd_wr_en),
    .i_vtp_cmd_prog_full(i_rtc_vtp_cmd_prog_full),
    .ov_vtp_cmd_data(ov_rtc_vtp_cmd_data),

    .i_vtp_resp_empty(i_rtc_vtp_resp_empty),
    .o_vtp_resp_rd_en(o_rtc_vtp_resp_rd_en),
    .iv_vtp_resp_data(iv_rtc_vtp_resp_data),

    .o_vtp_upload_wr_en(o_rtc_vtp_upload_wr_en),
    .i_vtp_upload_prog_full(i_rtc_vtp_upload_prog_full),
    .ov_vtp_upload_data(ov_rtc_vtp_upload_data),

//RequesterRecvControl
    .i_br_prog_full(w_bad_req_prog_full),
    .o_br_wr_en(w_bad_req_wr_en),
    .ov_br_data(wv_bad_req_din),

//CQ Offset Table
    .o_rtc_req_valid(o_rtc_req_valid),
    .ov_rtc_cq_index(ov_rtc_cq_index),
    .ov_rtc_cq_size(ov_rtc_cq_size),
    .i_rtc_resp_valid(i_rtc_resp_valid),
    .iv_rtc_cq_offset(iv_rtc_cq_offset),

//ReqPktGen
    .i_header_to_rpg_prog_full(w_header_from_rtc_to_rpg_prog_full),
    .o_header_to_rpg_wr_en(w_header_from_rtc_to_rpg_wr_en),
    .ov_header_to_rpg_data(wv_header_from_rtc_to_rpg_din),

    .i_nd_to_rpg_prog_full(w_nd_from_rtc_to_rpg_prog_full),
    .o_nd_to_rpg_wr_en(w_nd_from_rtc_to_rpg_wr_en),
    .ov_nd_to_rpg_data(wv_nd_from_rtc_to_rpg_din),

//TimerControl
    .i_te_prog_full(w_loss_timer_rtc_setting_prog_full),
    .o_te_wr_en(w_loss_timer_rtc_setting_wr_en),
    .ov_te_data(wv_loss_timer_rtc_setting_din),

//MultiQueue
    //Read Packet Buffer
    .o_rpb_list_head_wea(w_rpb_list_head_wea),
    .ov_rpb_list_head_addra(wv_rpb_list_head_addra),
    .ov_rpb_list_head_dina(wv_rpb_list_head_dina),
    .iv_rpb_list_head_douta(wv_rpb_list_head_douta),

    .o_rpb_list_tail_wea(w_rpb_list_tail_wea),
    .ov_rpb_list_tail_addra(wv_rpb_list_tail_addra),
    .ov_rpb_list_tail_dina(wv_rpb_list_tail_dina),
    .iv_rpb_list_tail_douta(wv_rpb_list_tail_douta),

    .o_rpb_list_empty_wea(w_rpb_list_empty_wea),
    .ov_rpb_list_empty_addra(wv_rpb_list_empty_addra),
    .ov_rpb_list_empty_dina(wv_rpb_list_empty_dina),
    .iv_rpb_list_empty_douta(wv_rpb_list_empty_douta),

    .o_rpb_content_wea(w_rpb_content_wea),
    .ov_rpb_content_addra(wv_rpb_content_addra),
    .ov_rpb_content_dina(wv_rpb_content_dina),
    .iv_rpb_content_douta(wv_rpb_content_douta),

    .o_rpb_next_wea(w_rpb_next_wea),
    .ov_rpb_next_addra(wv_rpb_next_addra),
    .ov_rpb_next_dina(wv_rpb_next_dina),
    .iv_rpb_next_douta(wv_rpb_next_douta),

    .iv_rpb_free_data(wv_rpb_free_dout),
    .o_rpb_free_rd_en(w_rpb_free_rd_en),
    .i_rpb_free_empty(w_rpb_free_empty),
    .iv_rpb_free_data_count(wv_rpb_free_data_count),

    //Read Entry Buffer
    .o_reb_list_head_wea(w_reb_list_head_wea),
    .ov_reb_list_head_addra(wv_reb_list_head_addra),
    .ov_reb_list_head_dina(wv_reb_list_head_dina),
    .iv_reb_list_head_douta(wv_reb_list_head_douta),

    .o_reb_list_tail_wea(w_reb_list_tail_wea),
    .ov_reb_list_tail_addra(wv_reb_list_tail_addra),
    .ov_reb_list_tail_dina(wv_reb_list_tail_dina),
    .iv_reb_list_tail_douta(wv_reb_list_tail_douta),

    .o_reb_list_empty_wea(w_reb_list_empty_wea),
    .ov_reb_list_empty_addra(wv_reb_list_empty_addra),
    .ov_reb_list_empty_dina(wv_reb_list_empty_dina),
    .iv_reb_list_empty_douta(wv_reb_list_empty_douta),

    .o_reb_content_wea(w_reb_content_wea),
    .ov_reb_content_addra(wv_reb_content_addra),
    .ov_reb_content_dina(wv_reb_content_dina),
    .iv_reb_content_douta(wv_reb_content_douta),

    .o_reb_next_wea(w_reb_next_wea),
    .ov_reb_next_addra(wv_reb_next_addra),
    .ov_reb_next_dina(wv_reb_next_dina),
    .iv_reb_next_douta(wv_reb_next_douta),

    .iv_reb_free_data(wv_reb_free_dout),
    .o_reb_free_rd_en(w_reb_free_rd_en),
    .i_reb_free_empty(w_reb_free_empty),
    .iv_reb_free_data_count(wv_reb_free_data_count),

    //Send/Write Buffer
    .o_swpb_list_head_wea(w_swpb_list_head_wea),
    .ov_swpb_list_head_addra(wv_swpb_list_head_addra),
    .ov_swpb_list_head_dina(wv_swpb_list_head_dina),
    .iv_swpb_list_head_douta(wv_swpb_list_head_douta),

    .o_swpb_list_tail_wea(w_swpb_list_tail_wea),
    .ov_swpb_list_tail_addra(wv_swpb_list_tail_addra),
    .ov_swpb_list_tail_dina(wv_swpb_list_tail_dina),
    .iv_swpb_list_tail_douta(wv_swpb_list_tail_douta),

    .o_swpb_list_empty_wea(w_swpb_list_empty_wea),
    .ov_swpb_list_empty_addra(wv_swpb_list_empty_addra),
    .ov_swpb_list_empty_dina(wv_swpb_list_empty_dina),
    .iv_swpb_list_empty_douta(wv_swpb_list_empty_douta),

    .o_swpb_content_wea(w_swpb_content_wea),
    .ov_swpb_content_addra(wv_swpb_content_addra),
    .ov_swpb_content_dina(wv_swpb_content_dina),
    .iv_swpb_content_douta(wv_swpb_content_douta),

    .o_swpb_next_wea(w_swpb_next_wea),
    .ov_swpb_next_addra(wv_swpb_next_addra),
    .ov_swpb_next_dina(wv_swpb_next_dina),
    .iv_swpb_next_douta(wv_swpb_next_douta),

    .iv_swpb_free_data(wv_swpb_free_dout),
    .o_swpb_free_rd_en(w_swpb_free_rd_en),
    .i_swpb_free_empty(w_swpb_free_empty),
    .iv_swpb_free_data_count(wv_swpb_free_data_count),

    .dbg_sel(wv_rtc_dbg_sel),
    .dbg_bus(wv_rtc_dbg_bus)

);

TimerControl TimerControl_Inst(
    .rw_data(rw_data[(10 + 2) * 32 - 1 : 10 * 32]),
    .init_rw_data(),

    .clk(clk),
    .rst(rst),

//Interface with RequesterTransControl
    .i_tc_te_loss_empty(w_loss_timer_rtc_setting_empty),
    .iv_tc_te_loss_data(wv_loss_timer_rtc_setting_dout),
    .o_tc_te_loss_rd_en(w_loss_timer_rtc_setting_rd_en),

//RequesterRecvControl
    //Set Loss Timer
    .i_rc_te_loss_empty(w_loss_timer_rrc_setting_empty),
    .iv_rc_te_loss_data(wv_loss_timer_rrc_setting_dout),
    .o_rc_te_loss_rd_en(w_loss_timer_rrc_setting_rd_en),

    //Set RNR Timer
    .i_rc_te_rnr_empty(w_rnr_timer_setting_empty),
    .iv_rc_te_rnr_data(wv_rnr_timer_setting_dout),
    .o_rc_te_rnr_rd_en(w_rnr_timer_setting_rd_en),

    //Loss Timer expire
    .o_loss_expire_wr_en(w_loss_timer_expire_wr_en),
    .ov_loss_expire_data(wv_loss_timer_expire_din),
    .i_loss_expire_prog_full(w_loss_timer_expire_prog_full),

    //RNR Timer expire
    .o_rnr_expire_wr_en(w_rnr_timer_expire_wr_en),
    .ov_rnr_expire_data(wv_rnr_timer_expire_din),
    .i_rnr_expire_prog_full(w_rnr_timer_expire_prog_full),

	.o_timer_init_finish(w_timer_init_finish),

    .dbg_sel(wv_tc_dbg_sel),
    .dbg_bus(wv_tc_dbg_bus)
);

MultiQueue MultiQueue_Inst(
    .rw_data(rw_data[(12 + 18) * 32 - 1 : 12 * 32]),
    .init_rw_data(),

    .clk(clk),
    .rst(rst),

//Interface with RequesterTransControl
//--------------------------------------------
    .i_rpb_list_head_wea(w_rpb_list_head_wea),
    .iv_rpb_list_head_addra(wv_rpb_list_head_addra),
    .iv_rpb_list_head_dina(wv_rpb_list_head_dina),
    .ov_rpb_list_head_douta(wv_rpb_list_head_douta),

    .i_rpb_list_tail_wea(w_rpb_list_tail_wea),
    .iv_rpb_list_tail_addra(wv_rpb_list_tail_addra),
    .iv_rpb_list_tail_dina(wv_rpb_list_tail_dina),
    .ov_rpb_list_tail_douta(wv_rpb_list_tail_douta),

    .i_rpb_list_empty_wea(w_rpb_list_empty_wea),
    .iv_rpb_list_empty_addra(wv_rpb_list_empty_addra),
    .iv_rpb_list_empty_dina(wv_rpb_list_empty_dina),
    .ov_rpb_list_empty_douta(wv_rpb_list_empty_douta),

    .i_rpb_content_wea(w_rpb_content_wea),
    .iv_rpb_content_addra(wv_rpb_content_addra),
    .iv_rpb_content_dina(wv_rpb_content_dina),
    .ov_rpb_content_douta(wv_rpb_content_douta),

    .i_rpb_next_wea(w_rpb_next_wea),
    .iv_rpb_next_addra(wv_rpb_next_addra),
    .iv_rpb_next_dina(wv_rpb_next_dina),
    .ov_rpb_next_douta(wv_rpb_next_douta),

    .o_rpb_free_empty(w_rpb_free_empty),
    .ov_rpb_free_dout(wv_rpb_free_dout),
    .i_rpb_free_rd_en(w_rpb_free_rd_en),
    .ov_rpb_free_data_count(wv_rpb_free_data_count),

//--------------------------------------------

    .i_reb_list_head_wea(w_reb_list_head_wea),
    .iv_reb_list_head_addra(wv_reb_list_head_addra),
    .iv_reb_list_head_dina(wv_reb_list_head_dina),
    .ov_reb_list_head_douta(wv_reb_list_head_douta),

    .i_reb_list_tail_wea(w_reb_list_tail_wea),
    .iv_reb_list_tail_addra(wv_reb_list_tail_addra),
    .iv_reb_list_tail_dina(wv_reb_list_tail_dina),
    .ov_reb_list_tail_douta(wv_reb_list_tail_douta),

    .i_reb_list_empty_wea(w_reb_list_empty_wea),
    .iv_reb_list_empty_addra(wv_reb_list_empty_addra),
    .iv_reb_list_empty_dina(wv_reb_list_empty_dina),
    .ov_reb_list_empty_douta(wv_reb_list_empty_douta),

    .i_reb_content_wea(w_reb_content_wea),
    .iv_reb_content_addra(wv_reb_content_addra),
    .iv_reb_content_dina(wv_reb_content_dina),
    .ov_reb_content_douta(wv_reb_content_douta),

    .i_reb_next_wea(w_reb_next_wea),
    .iv_reb_next_addra(wv_reb_next_addra),
    .iv_reb_next_dina(wv_reb_next_dina),
    .ov_reb_next_douta(wv_reb_next_douta),

    .o_reb_free_empty(w_reb_free_empty),
    .ov_reb_free_dout(wv_reb_free_dout),
    .i_reb_free_rd_en(w_reb_free_rd_en),
    .ov_reb_free_data_count(wv_reb_free_data_count),

//--------------------------------------------

    .i_swpb_list_head_wea(w_swpb_list_head_wea),
    .iv_swpb_list_head_addra(wv_swpb_list_head_addra),
    .iv_swpb_list_head_dina(wv_swpb_list_head_dina),
    .ov_swpb_list_head_douta(wv_swpb_list_head_douta),

    .i_swpb_list_tail_wea(w_swpb_list_tail_wea),
    .iv_swpb_list_tail_addra(wv_swpb_list_tail_addra),
    .iv_swpb_list_tail_dina(wv_swpb_list_tail_dina),
    .ov_swpb_list_tail_douta(wv_swpb_list_tail_douta),

    .i_swpb_list_empty_wea(w_swpb_list_empty_wea),
    .iv_swpb_list_empty_addra(wv_swpb_list_empty_addra),
    .iv_swpb_list_empty_dina(wv_swpb_list_empty_dina),
    .ov_swpb_list_empty_douta(wv_swpb_list_empty_douta),

    .i_swpb_content_wea(w_swpb_content_wea),
    .iv_swpb_content_addra(wv_swpb_content_addra),
    .iv_swpb_content_dina(wv_swpb_content_dina),
    .ov_swpb_content_douta(wv_swpb_content_douta),

    .i_swpb_next_wea(w_swpb_next_wea),
    .iv_swpb_next_addra(wv_swpb_next_addra),
    .iv_swpb_next_dina(wv_swpb_next_dina),
    .ov_swpb_next_douta(wv_swpb_next_douta),

    .o_swpb_free_empty(w_swpb_free_empty),
    .ov_swpb_free_dout(wv_swpb_free_dout),
    .i_swpb_free_rd_en(w_swpb_free_rd_en),
    .ov_swpb_free_data_count(wv_swpb_free_data_count),

//--------------------------------------------
    .i_rpb_list_head_web(w_rpb_list_head_web),
    .iv_rpb_list_head_addrb(wv_rpb_list_head_addrb),
    .iv_rpb_list_head_dinb(wv_rpb_list_head_dinb),
    .ov_rpb_list_head_doutb(wv_rpb_list_head_doutb),

    .i_rpb_list_tail_web(w_rpb_list_tail_web),
    .iv_rpb_list_tail_addrb(wv_rpb_list_tail_addrb),
    .iv_rpb_list_tail_dinb(wv_rpb_list_tail_dinb),
    .ov_rpb_list_tail_doutb(wv_rpb_list_tail_doutb),

    .i_rpb_list_empty_web(w_rpb_list_empty_web),
    .iv_rpb_list_empty_addrb(wv_rpb_list_empty_addrb),
    .iv_rpb_list_empty_dinb(wv_rpb_list_empty_dinb),
    .ov_rpb_list_empty_doutb(wv_rpb_list_empty_doutb),

    .i_rpb_content_web(w_rpb_content_web),
    .iv_rpb_content_addrb(wv_rpb_content_addrb),
    .iv_rpb_content_dinb(wv_rpb_content_dinb),
    .ov_rpb_content_doutb(wv_rpb_content_doutb),

    .i_rpb_next_web(w_rpb_next_web),
    .iv_rpb_next_addrb(wv_rpb_next_addrb),
    .iv_rpb_next_dinb(wv_rpb_next_dinb),
    .ov_rpb_next_doutb(wv_rpb_next_doutb),

    .i_rpb_free_wr_en(w_rpb_free_wr_en),
    .iv_rpb_free_din(wv_rpb_free_din),
    .o_rpb_free_prog_full(w_rpb_free_prog_full),

//--------------------------------------------

    .i_reb_list_head_web(w_reb_list_head_web),
    .iv_reb_list_head_addrb(wv_reb_list_head_addrb),
    .iv_reb_list_head_dinb(wv_reb_list_head_dinb),
    .ov_reb_list_head_doutb(wv_reb_list_head_doutb),

    .i_reb_list_tail_web(w_reb_list_tail_web),
    .iv_reb_list_tail_addrb(wv_reb_list_tail_addrb),
    .iv_reb_list_tail_dinb(wv_reb_list_tail_dinb),
    .ov_reb_list_tail_doutb(wv_reb_list_tail_doutb),

    .i_reb_list_empty_web(w_reb_list_empty_web),
    .iv_reb_list_empty_addrb(wv_reb_list_empty_addrb),
    .iv_reb_list_empty_dinb(wv_reb_list_empty_dinb),
    .ov_reb_list_empty_doutb(wv_reb_list_empty_doutb),

    .i_reb_content_web(w_reb_content_web),
    .iv_reb_content_addrb(wv_reb_content_addrb),
    .iv_reb_content_dinb(wv_reb_content_dinb),
    .ov_reb_content_doutb(wv_reb_content_doutb),

    .i_reb_next_web(w_reb_next_web),
    .iv_reb_next_addrb(wv_reb_next_addrb),
    .iv_reb_next_dinb(wv_reb_next_dinb),
    .ov_reb_next_doutb(wv_reb_next_doutb),

    .i_reb_free_wr_en(w_reb_free_wr_en),
    .iv_reb_free_din(wv_reb_free_din),
    .o_reb_free_prog_full(w_reb_free_prog_full),

//--------------------------------------------

    .i_swpb_list_head_web(w_swpb_list_head_web),
    .iv_swpb_list_head_addrb(wv_swpb_list_head_addrb),
    .iv_swpb_list_head_dinb(wv_swpb_list_head_dinb),
    .ov_swpb_list_head_doutb(wv_swpb_list_head_doutb),

    .i_swpb_list_tail_web(w_swpb_list_tail_web),
    .iv_swpb_list_tail_addrb(wv_swpb_list_tail_addrb),
    .iv_swpb_list_tail_dinb(wv_swpb_list_tail_dinb),
    .ov_swpb_list_tail_doutb(wv_swpb_list_tail_doutb),

    .i_swpb_list_empty_web(w_swpb_list_empty_web),
    .iv_swpb_list_empty_addrb(wv_swpb_list_empty_addrb),
    .iv_swpb_list_empty_dinb(wv_swpb_list_empty_dinb),
    .ov_swpb_list_empty_doutb(wv_swpb_list_empty_doutb),

    .i_swpb_content_web(w_swpb_content_web),
    .iv_swpb_content_addrb(wv_swpb_content_addrb),
    .iv_swpb_content_dinb(wv_swpb_content_dinb),
    .ov_swpb_content_doutb(wv_swpb_content_doutb),

    .i_swpb_next_web(w_swpb_next_web),
    .iv_swpb_next_addrb(wv_swpb_next_addrb),
    .iv_swpb_next_dinb(wv_swpb_next_dinb),
    .ov_swpb_next_doutb(wv_swpb_next_doutb),

    .i_swpb_free_wr_en(w_swpb_free_wr_en),
    .iv_swpb_free_din(wv_swpb_free_din),
    .o_swpb_free_prog_full(w_swpb_free_prog_full),

    .dbg_sel(wv_mq_dbg_sel),
    .dbg_bus(wv_mq_dbg_bus)
);

ReqPktGen ReqPktGen_Inst(
    .clk(clk),
    .rst(rst),

//Interface with RequesterTransControl
    .i_tc_header_empty(w_header_from_rtc_to_rpg_empty),
    .iv_tc_header_data(wv_header_from_rtc_to_rpg_dout),
    .o_tc_header_rd_en(w_header_from_rtc_to_rpg_rd_en),

    .i_tc_nd_empty(w_nd_from_rtc_to_rpg_empty),
    .iv_tc_nd_data(wv_nd_from_rtc_to_rpg_dout),
    .o_tc_nd_rd_en(w_nd_from_rtc_to_rpg_rd_en),

//RequesterRecvControl
    .i_rc_header_empty(w_header_from_rrc_to_rpg_empty),
    .iv_rc_header_data(wv_header_from_rrc_to_rpg_dout),
    .o_rc_header_rd_en(w_header_from_rrc_to_rpg_rd_en),

    .i_rc_nd_empty(w_nd_from_rrc_to_rpg_empty),
    .iv_rc_nd_data(wv_nd_from_rrc_to_rpg_dout),
    .o_rc_nd_rd_en(w_nd_from_rrc_to_rpg_rd_en),

//BitWidthTrans
    .i_trans_prog_full(i_rpg_trans_prog_full),
    .o_trans_wr_en(o_rpg_trans_wr_en),
    .ov_trans_data(ov_rpg_trans_data),

    .dbg_sel(wv_rpg_dbg_sel),
    .dbg_bus(wv_rpg_dbg_bus)
);

RequesterRecvControl RequesterRecvControl_Inst(
    .rw_data(rw_data[(30 + 4) * 32 - 1 : 30 * 32]),
    .init_rw_data(),

    .clk(clk),
    .rst(rst),

//Interface with TimerControl
    //Set timer
    .o_rc_te_loss_wr_en(w_loss_timer_rrc_setting_wr_en),
    .ov_rc_te_loss_data(wv_loss_timer_rrc_setting_din),
    .i_rc_te_loss_prog_full(w_loss_timer_rrc_setting_prog_full),

    .o_rc_te_rnr_wr_en(w_rnr_timer_setting_wr_en),
    .ov_rc_te_rnr_data(wv_rnr_timer_setting_din),
    .i_rc_te_rnr_prog_full(w_rnr_timer_setting_prog_full),

    //Timer expire
    .i_loss_expire_empty(w_loss_timer_expire_empty),
    .iv_loss_expire_data(wv_loss_timer_expire_dout),
    .o_loss_expire_rd_en(w_loss_timer_expire_rd_en),

    .i_rnr_expire_empty(w_rnr_timer_expire_empty),
    .iv_rnr_expire_data(wv_rnr_timer_expire_dout),
    .o_rnr_expire_rd_en(w_rnr_timer_expire_rd_en),

//CQ Offset Table
    .o_rrc_req_valid(o_rrc_req_valid),
    .ov_rrc_cq_index(ov_rrc_cq_index),
    .ov_rrc_cq_size(ov_rrc_cq_size),
    .i_rrc_resp_valid(i_rrc_resp_valid),
    .iv_rrc_cq_offset(iv_rrc_cq_offset),

//MultiQueue
    //Read Packet Buffer 
    .o_rpb_list_head_web(w_rpb_list_head_web),
    .ov_rpb_list_head_addrb(wv_rpb_list_head_addrb),
    .ov_rpb_list_head_dinb(wv_rpb_list_head_dinb),
    .iv_rpb_list_head_doutb(wv_rpb_list_head_doutb),

    .o_rpb_list_tail_web(w_rpb_list_tail_web),
    .ov_rpb_list_tail_addrb(wv_rpb_list_tail_addrb),
    .ov_rpb_list_tail_dinb(wv_rpb_list_tail_dinb),
    .iv_rpb_list_tail_doutb(wv_rpb_list_tail_doutb),

    .o_rpb_list_empty_web(w_rpb_list_empty_web),
    .ov_rpb_list_empty_addrb(wv_rpb_list_empty_addrb),
    .ov_rpb_list_empty_dinb(wv_rpb_list_empty_dinb),
    .iv_rpb_list_empty_doutb(wv_rpb_list_empty_doutb),

    .o_rpb_content_web(w_rpb_content_web),
    .ov_rpb_content_addrb(wv_rpb_content_addrb),
    .ov_rpb_content_dinb(wv_rpb_content_dinb),
    .iv_rpb_content_doutb(wv_rpb_content_doutb),

    .o_rpb_next_web(w_rpb_next_web),
    .ov_rpb_next_addrb(wv_rpb_next_addrb),
    .ov_rpb_next_dinb(wv_rpb_next_dinb),
    .iv_rpb_next_doutb(wv_rpb_next_doutb),

    .ov_rpb_free_data(wv_rpb_free_din),
    .o_rpb_free_wr_en(w_rpb_free_wr_en),
    .i_rpb_free_prog_full(w_rpb_free_prog_full),

    //Read Entry Buffer
    .o_reb_list_head_web(w_reb_list_head_web),
    .ov_reb_list_head_addrb(wv_reb_list_head_addrb),
    .ov_reb_list_head_dinb(wv_reb_list_head_dinb),
    .iv_reb_list_head_doutb(wv_reb_list_head_doutb),

    .o_reb_list_tail_web(w_reb_list_tail_web),
    .ov_reb_list_tail_addrb(wv_reb_list_tail_addrb),
    .ov_reb_list_tail_dinb(wv_reb_list_tail_dinb),
    .iv_reb_list_tail_doutb(wv_reb_list_tail_doutb),

    .o_reb_list_empty_web(w_reb_list_empty_web),
    .ov_reb_list_empty_addrb(wv_reb_list_empty_addrb),
    .ov_reb_list_empty_dinb(wv_reb_list_empty_dinb),
    .iv_reb_list_empty_doutb(wv_reb_list_empty_doutb),

    .o_reb_content_web(w_reb_content_web),
    .ov_reb_content_addrb(wv_reb_content_addrb),
    .ov_reb_content_dinb(wv_reb_content_dinb),
    .iv_reb_content_doutb(wv_reb_content_doutb),

    .o_reb_next_web(w_reb_next_web),
    .ov_reb_next_addrb(wv_reb_next_addrb),
    .ov_reb_next_dinb(wv_reb_next_dinb),
    .iv_reb_next_doutb(wv_reb_next_doutb),

    .ov_reb_free_data(wv_reb_free_din),
    .o_reb_free_wr_en(w_reb_free_wr_en),
    .i_reb_free_prog_full(w_reb_free_prog_full),

    //Send/Write Packet Buffer
    .o_swpb_list_head_web(w_swpb_list_head_web),
    .ov_swpb_list_head_addrb(wv_swpb_list_head_addrb),
    .ov_swpb_list_head_dinb(wv_swpb_list_head_dinb),
    .iv_swpb_list_head_doutb(wv_swpb_list_head_doutb),

    .o_swpb_list_tail_web(w_swpb_list_tail_web),
    .ov_swpb_list_tail_addrb(wv_swpb_list_tail_addrb),
    .ov_swpb_list_tail_dinb(wv_swpb_list_tail_dinb),
    .iv_swpb_list_tail_doutb(wv_swpb_list_tail_doutb),

    .o_swpb_list_empty_web(w_swpb_list_empty_web),
    .ov_swpb_list_empty_addrb(wv_swpb_list_empty_addrb),
    .ov_swpb_list_empty_dinb(wv_swpb_list_empty_dinb),
    .iv_swpb_list_empty_doutb(wv_swpb_list_empty_doutb),

    .ov_swpb_content_addrb(wv_swpb_content_addrb),
    .ov_swpb_content_dinb(wv_swpb_content_dinb),
    .iv_swpb_content_doutb(wv_swpb_content_doutb),
    .o_swpb_content_web(w_swpb_content_web),

    .ov_swpb_next_addrb(wv_swpb_next_addrb),
    .ov_swpb_next_dinb(wv_swpb_next_dinb),
    .iv_swpb_next_doutb(wv_swpb_next_doutb),
    .o_swpb_next_web(w_swpb_next_web),

    .ov_swpb_free_data(wv_swpb_free_din),
    .o_swpb_free_wr_en(w_swpb_free_wr_en),
    .i_swpb_free_prog_full(w_swpb_free_prog_full),

//Header Parser
    .i_header_from_hp_empty(i_header_from_hp_empty),
    .o_header_from_hp_rd_en(o_header_from_hp_rd_en),
    .iv_header_from_hp_data(iv_header_from_hp_data),

    .iv_nd_from_hp_data(iv_nd_from_hp_data),
    .i_nd_from_hp_empty(i_nd_from_hp_empty),
    .o_nd_from_hp_rd_en(o_nd_from_hp_rd_en),

//ReqPktGen
    .i_header_to_rpg_prog_full(w_header_from_rrc_to_rpg_prog_full),
    .o_header_to_rpg_wr_en(w_header_from_rrc_to_rpg_wr_en),
    .ov_header_to_rpg_data(wv_header_from_rrc_to_rpg_din),

    .i_nd_to_rpg_prog_full(w_nd_from_rrc_to_rpg_prog_full),
    .o_nd_to_rpg_wr_en(w_nd_from_rrc_to_rpg_wr_en),
    .ov_nd_to_rpg_data(wv_nd_from_rrc_to_rpg_din),

//RequesterTransControl
    .i_br_empty(w_bad_req_empty),
    .o_br_rd_en(w_bad_req_rd_en),
    .iv_br_data(wv_bad_req_dout),

//CxtMgt
    .o_cxtmgt_cmd_wr_en(o_rrc_cxtmgt_cmd_wr_en),
    .i_cxtmgt_cmd_prog_full(i_rrc_cxtmgt_cmd_prog_full),
    .ov_cxtmgt_cmd_data(ov_rrc_cxtmgt_cmd_data),

    .i_cxtmgt_resp_empty(i_rrc_cxtmgt_resp_empty),
    .o_cxtmgt_resp_rd_en(o_rrc_cxtmgt_resp_rd_en),
    .iv_cxtmgt_resp_data(iv_rrc_cxtmgt_resp_data),

    .i_cxtmgt_cxt_empty(i_rrc_cxtmgt_cxt_empty),
    .o_cxtmgt_cxt_rd_en(o_rrc_cxtmgt_cxt_rd_en),
    .iv_cxtmgt_cxt_data(iv_rrc_cxtmgt_cxt_data),

    .o_cxtmgt_cxt_wr_en(o_rrc_cxtmgt_cxt_wr_en),
    .i_cxtmgt_cxt_prog_full(i_rrc_cxtmgt_cxt_prog_full),
    .ov_cxtmgt_cxt_data(ov_rrc_cxtmgt_cxt_data),

//VirtToPhys
    .o_vtp_cmd_wr_en(o_rrc_vtp_cmd_wr_en),
    .i_vtp_cmd_prog_full(i_rrc_vtp_cmd_prog_full),
    .ov_vtp_cmd_data(ov_rrc_vtp_cmd_data),

    .i_vtp_resp_empty(i_rrc_vtp_resp_empty),
    .o_vtp_resp_rd_en(o_rrc_vtp_resp_rd_en),
    .iv_vtp_resp_data(iv_rrc_vtp_resp_data),

    .o_vtp_upload_wr_en(o_rrc_vtp_upload_wr_en),
    .i_vtp_upload_prog_full(i_rrc_vtp_upload_prog_full),
    .ov_vtp_upload_data(ov_rrc_vtp_upload_data),

	.o_rrc_init_finish(w_rrc_init_finish),

    .dbg_sel(wv_rrc_dbg_sel),
    .dbg_bus(wv_rrc_dbg_bus)
);

assign o_req_engine_init_finish = w_timer_init_finish && w_rrc_init_finish;

assign init_rw_data = {
							{4{32'd0}},										//RequesterRecvControl
							{18{32'b00000000_00000000_00000000_11010101}},		//MultiQueue
							{2{32'b00000000_00000000_00000000_11010101}},		//TimerControl
							{10{32'd0}}											//10 FIFOs
						};

endmodule
