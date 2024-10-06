`timescale 1ns / 1ps

`include "chip_include_rdma.vh"

module RDMAEngine
#(
    parameter   RW_REG_NUM = 71
)
(
    input   wire                clk,
    input   wire                rst,

	output 	wire 	[RW_REG_NUM * 32 - 1 : 0]	ro_data,
	input 	wire 	[RW_REG_NUM * 32 - 1 : 0]	rw_data,
	output 	wire 	[RW_REG_NUM * 32 - 1 : 0]	init_rw_data,

//Interface with PIO
    input   wire                i_pio_empty,
    output  wire                o_pio_rd_en,
    input   wire    [63:0]      iv_pio_data,

//Interface with CxtMgt
    //Channel 1 for DoorbellProcessing, no cxt write back
    output  wire                o_db_cxtmgt_cmd_wr_en,
    input   wire                i_db_cxtmgt_cmd_prog_full,
    output  wire    [127:0]     ov_db_cxtmgt_cmd_data,

    input   wire                i_db_cxtmgt_resp_empty,
    output  wire                o_db_cxtmgt_resp_rd_en,
    input   wire    [127:0]     iv_db_cxtmgt_resp_data,

    input   wire                i_db_cxtmgt_cxt_empty,
    output  wire                o_db_cxtmgt_cxt_rd_en,
    input   wire    [255:0]     iv_db_cxtmgt_cxt_data,

    //Channel 2 for WQEParser, no cxt write back
    output  wire                o_wp_cxtmgt_cmd_wr_en,
    input   wire                i_wp_cxtmgt_cmd_prog_full,
    output  wire    [127:0]     ov_wp_cxtmgt_cmd_data,

    input   wire                i_wp_cxtmgt_resp_empty,
    output  wire                o_wp_cxtmgt_resp_rd_en,
    input   wire    [127:0]     iv_wp_cxtmgt_resp_data,

    input   wire                i_wp_cxtmgt_cxt_empty,
    output  wire                o_wp_cxtmgt_cxt_rd_en,
    input   wire    [127:0]     iv_wp_cxtmgt_cxt_data,

    //Channel 3 for RequesterTransControl, cxt write back
    output  wire                o_rtc_cxtmgt_cmd_wr_en,
    input   wire                i_rtc_cxtmgt_cmd_prog_full,
    output  wire    [127:0]     ov_rtc_cxtmgt_cmd_data,

    input   wire                i_rtc_cxtmgt_resp_empty,
    output  wire                o_rtc_cxtmgt_resp_rd_en,
    input   wire    [127:0]     iv_rtc_cxtmgt_resp_data,

    input   wire                i_rtc_cxtmgt_cxt_empty,
    output  wire                o_rtc_cxtmgt_cxt_rd_en,
    input   wire    [191:0]     iv_rtc_cxtmgt_cxt_data,

/*Spyglass Add Begin*/
    input   wire                i_rtc_cxtmgt_cxt_prog_full,
    output  wire                o_rtc_cxtmgt_cxt_wr_en,
    output  wire    [127:0]     ov_rtc_cxtmgt_cxt_data,
/*SPyglass Add End*/

    //Channel 4 for RequesterRecvContro, cxt write back 
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

    //Channel 5 for ExecutionEngine, cxt write back
    output  wire                o_ee_cxtmgt_cmd_wr_en,
    input   wire                i_ee_cxtmgt_cmd_prog_full,
    output  wire    [127:0]     ov_ee_cxtmgt_cmd_data,

    input   wire                i_ee_cxtmgt_resp_empty,
    output  wire                o_ee_cxtmgt_resp_rd_en,
    input   wire    [127:0]     iv_ee_cxtmgt_resp_data,

    input   wire                i_ee_cxtmgt_cxt_empty,
    output  wire                o_ee_cxtmgt_cxt_rd_en,
    input   wire    [319:0]     iv_ee_cxtmgt_cxt_data,

    output  wire                o_ee_cxtmgt_cxt_wr_en,
    input   wire                i_ee_cxtmgt_cxt_prog_full,
    output  wire    [127:0]     ov_ee_cxtmgt_cxt_data,

//Interface with VirtToPhys
    //Channel 1 for Doorbell Processing, only read
    output  wire                o_db_vtp_cmd_wr_en,
    input   wire                i_db_vtp_cmd_prog_full,
    output  wire    [255:0]     ov_db_vtp_cmd_data,

    input   wire                i_db_vtp_resp_empty,
    output  wire                o_db_vtp_resp_rd_en,
    input   wire    [7:0]       iv_db_vtp_resp_data,

    input   wire                i_db_vtp_download_empty,
    output  wire                o_db_vtp_download_rd_en,
    input   wire    [127:0]     iv_db_vtp_download_data,
        
    //Channel 2 for WQEParser, download SQ WQE
    output  wire                o_wp_vtp_wqe_cmd_wr_en,
    input   wire                i_wp_vtp_wqe_cmd_prog_full,
    output  wire    [255:0]     ov_wp_vtp_wqe_cmd_data,

    input   wire                i_wp_vtp_wqe_resp_empty,
    output  wire                o_wp_vtp_wqe_resp_rd_en,
    input   wire    [7:0]       iv_wp_vtp_wqe_resp_data,

    input   wire                i_wp_vtp_wqe_download_empty,
    output  wire                o_wp_vtp_wqe_download_rd_en,
    input   wire    [127:0]     iv_wp_vtp_wqe_download_data,

    //Channel 3 for WQEParser, download network data
    output  wire                o_wp_vtp_nd_cmd_wr_en,
    input   wire                i_wp_vtp_nd_cmd_prog_full,
    output  wire    [255:0]     ov_wp_vtp_nd_cmd_data,

    input   wire                i_wp_vtp_nd_resp_empty,
    output  wire                o_wp_vtp_nd_resp_rd_en,
    input   wire    [7:0]       iv_wp_vtp_nd_resp_data,

    input   wire                i_wp_vtp_nd_download_empty,
    output  wire                o_wp_vtp_nd_download_rd_en,
    input   wire    [255:0]     iv_wp_vtp_nd_download_data,

    //Channel 4 for RequesterTransControl, upload Completion Event
    output  wire                o_rtc_vtp_cmd_wr_en,
    input   wire                i_rtc_vtp_cmd_prog_full,
    output  wire    [255:0]     ov_rtc_vtp_cmd_data,

    input   wire                i_rtc_vtp_resp_empty,
    output  wire                o_rtc_vtp_resp_rd_en,
    input   wire    [7:0]       iv_rtc_vtp_resp_data,

    output  wire                o_rtc_vtp_upload_wr_en,
    input   wire                i_rtc_vtp_upload_prog_full,
    output  wire    [255:0]     ov_rtc_vtp_upload_data,

    //Channel 5 for RequesterRecvControl, upload RDMA Read Response
    output  wire                o_rrc_vtp_cmd_wr_en,
    input   wire                i_rrc_vtp_cmd_prog_full,
    output  wire    [255:0]     ov_rrc_vtp_cmd_data,

    input   wire                i_rrc_vtp_resp_empty,
    output  wire                o_rrc_vtp_resp_rd_en,
    input   wire    [7:0]       iv_rrc_vtp_resp_data,

    output  wire                o_rrc_vtp_upload_wr_en,
    input   wire                i_rrc_vtp_upload_prog_full,
    output  wire    [255:0]     ov_rrc_vtp_upload_data,

    //Channel 6 for ExecutionEngine, upload Send/Write Payload and download Read Payload
    output  wire                o_ee_vtp_cmd_wr_en,
    input   wire                i_ee_vtp_cmd_prog_full,
    output  wire    [255:0]     ov_ee_vtp_cmd_data,

    input   wire                i_ee_vtp_resp_empty,
    output  wire                o_ee_vtp_resp_rd_en,
    input   wire    [7:0]       iv_ee_vtp_resp_data,

    output  wire                o_ee_vtp_upload_wr_en,
    input   wire                i_ee_vtp_upload_prog_full,
    output  wire    [255:0]     ov_ee_vtp_upload_data,

    output  wire                o_ee_vtp_download_rd_en,
    input   wire                i_ee_vtp_download_empty,
    input   wire    [255:0]     iv_ee_vtp_download_data,

    //Channel 7 for ExecutionEngine, download RQ WQE
    output  wire                o_rwm_vtp_cmd_wr_en,
    input   wire                i_rwm_vtp_cmd_prog_full,
    output  wire    [255:0]     ov_rwm_vtp_cmd_data,

    input   wire                i_rwm_vtp_resp_empty,
    output  wire                o_rwm_vtp_resp_rd_en,
    input   wire    [7:0]       iv_rwm_vtp_resp_data,

    output  wire                o_rwm_vtp_download_rd_en,
    input   wire                i_rwm_vtp_download_empty,
    input   wire    [127:0]     iv_rwm_vtp_download_data,

//LinkLayer
    input   wire                i_outbound_pkt_prog_full,
    output  wire                o_outbound_pkt_wr_en,
    output  wire    [255:0]      ov_outbound_pkt_data,

    input   wire                i_inbound_pkt_empty,
    output  wire                o_inbound_pkt_rd_en,
    input   wire    [255:0]      iv_inbound_pkt_data,

	output 	wire 				o_rdma_init_finish,

    input   wire    [31:0]      dbg_sel,
    output  wire    [32 - 1:0]      dbg_bus
    //output  wire    [`DBG_NUM_RDMA_ENGINE * 32 - 1:0]      dbg_bus
);

//wire        [31:0]      wv_swp_dbg_sel;
//wire        [`DBG_NUM_SEND_WQE_PROCESSING * 32 - 1:0]      wv_swp_dbg_bus;
//wire        [31:0]      wv_req_engine_dbg_sel;
//wire        [`DBG_NUM_REQUESTER_ENGINE * 32 - 1:0]      wv_req_engine_dbg_bus;
//wire        [31:0]      wv_resp_engine_dbg_sel;
//wire        [`DBG_NUM_RESPONDER_ENGINE * 32 - 1:0]      wv_resp_engine_dbg_bus;
//wire        [31:0]      wv_ea_dbg_sel;
//wire        [`DBG_NUM_EGRESS_ARBITER * 32 - 1:0]      wv_ea_dbg_bus;
//wire        [31:0]      wv_hp_dbg_sel;
//wire        [`DBG_NUM_HEADER_PARSER * 32 - 1:0]      wv_hp_dbg_bus;
//wire        [31:0]      wv_cqm_dbg_sel;
//wire        [`DBG_NUM_COMPLETION_QUEUE_MGR * 32 - 1:0]      wv_cqm_dbg_bus;
wire        [31:0]      wv_swp_dbg_sel;
wire        [32 - 1:0]      wv_swp_dbg_bus;
wire        [31:0]      wv_req_engine_dbg_sel;
wire        [32 - 1:0]      wv_req_engine_dbg_bus;
wire        [31:0]      wv_resp_engine_dbg_sel;
wire        [32 - 1:0]      wv_resp_engine_dbg_bus;
wire        [31:0]      wv_ea_dbg_sel;
wire        [32 - 1:0]      wv_ea_dbg_bus;
wire        [31:0]      wv_hp_dbg_sel;
wire        [32 - 1:0]      wv_hp_dbg_bus;
wire        [31:0]      wv_cqm_dbg_sel;
wire        [32 - 1:0]      wv_cqm_dbg_bus;

assign wv_swp_dbg_sel = dbg_sel - `DBG_NUM_ZERO;
assign wv_req_engine_dbg_sel = dbg_sel - `DBG_NUM_SEND_WQE_PROCESSING;
assign wv_resp_engine_dbg_sel = dbg_sel - (`DBG_NUM_SEND_WQE_PROCESSING + `DBG_NUM_REQUESTER_ENGINE);
assign wv_ea_dbg_sel = dbg_sel - (`DBG_NUM_SEND_WQE_PROCESSING + `DBG_NUM_REQUESTER_ENGINE + `DBG_NUM_RESPONDER_ENGINE);
assign wv_hp_dbg_sel = dbg_sel - (`DBG_NUM_SEND_WQE_PROCESSING + `DBG_NUM_REQUESTER_ENGINE + `DBG_NUM_RESPONDER_ENGINE + `DBG_NUM_EGRESS_ARBITER);
assign wv_cqm_dbg_sel = dbg_sel - (`DBG_NUM_SEND_WQE_PROCESSING + `DBG_NUM_REQUESTER_ENGINE + `DBG_NUM_RESPONDER_ENGINE + `DBG_NUM_EGRESS_ARBITER + `DBG_NUM_COMPLETION_QUEUE_MGR);

assign dbg_bus =    (dbg_sel >= `DBG_NUM_ZERO && dbg_sel <= `DBG_NUM_SEND_WQE_PROCESSING - 1) ? wv_swp_dbg_bus :
                    (dbg_sel >= `DBG_NUM_SEND_WQE_PROCESSING && dbg_sel <= `DBG_NUM_DOORBELL_PROCESSING + `DBG_NUM_REQUESTER_ENGINE - 1) ? wv_req_engine_dbg_bus :
                    (dbg_sel >= `DBG_NUM_SEND_WQE_PROCESSING + `DBG_NUM_REQUESTER_ENGINE && dbg_sel <= `DBG_NUM_SEND_WQE_PROCESSING + `DBG_NUM_REQUESTER_ENGINE + `DBG_NUM_RESPONDER_ENGINE - 1) ? wv_resp_engine_dbg_bus :
                    (dbg_sel >= `DBG_NUM_SEND_WQE_PROCESSING + `DBG_NUM_REQUESTER_ENGINE + `DBG_NUM_RESPONDER_ENGINE && dbg_sel <= `DBG_NUM_SEND_WQE_PROCESSING + `DBG_NUM_REQUESTER_ENGINE + `DBG_NUM_RESPONDER_ENGINE + `DBG_NUM_EGRESS_ARBITER - 1) ? wv_ea_dbg_bus :
                    (dbg_sel >= `DBG_NUM_SEND_WQE_PROCESSING + `DBG_NUM_REQUESTER_ENGINE + `DBG_NUM_RESPONDER_ENGINE + `DBG_NUM_EGRESS_ARBITER && dbg_sel <= `DBG_NUM_SEND_WQE_PROCESSING + `DBG_NUM_REQUESTER_ENGINE + `DBG_NUM_RESPONDER_ENGINE + `DBG_NUM_EGRESS_ARBITER + `DBG_NUM_HEADER_PARSER - 1) ? wv_hp_dbg_bus :
                    (dbg_sel >= `DBG_NUM_SEND_WQE_PROCESSING + `DBG_NUM_REQUESTER_ENGINE + `DBG_NUM_RESPONDER_ENGINE + `DBG_NUM_EGRESS_ARBITER + `DBG_NUM_HEADER_PARSER && dbg_sel <= `DBG_NUM_SEND_WQE_PROCESSING + `DBG_NUM_REQUESTER_ENGINE + `DBG_NUM_RESPONDER_ENGINE + `DBG_NUM_EGRESS_ARBITER + `DBG_NUM_HEADER_PARSER + `DBG_NUM_COMPLETION_QUEUE_MGR - 1) ? wv_cqm_dbg_bus : 32'd0;

//assign dbg_bus = {wv_swp_dbg_bus, wv_req_engine_dbg_bus, wv_resp_engine_dbg_bus, wv_ea_dbg_bus, wv_hp_dbg_bus, wv_cqm_dbg_bus};

assign ro_data = rw_data;

//Interface with RTC
wire                w_rtc_req_valid;
wire    [23:0]      wv_rtc_cq_index;
wire    [31:0]       wv_rtc_cq_size;
wire               w_rtc_resp_valid;
wire     [23:0]    wv_rtc_cq_offset;

//Interface with RRC
wire                w_rrc_req_valid;
wire    [23:0]      wv_rrc_cq_index;
wire    [31:0]       wv_rrc_cq_size;
wire               w_rrc_resp_valid;
wire    [23:0]     wv_rrc_cq_offset;    

//Interface with EE
wire                w_ee_req_valid;
wire    [23:0]      wv_ee_cq_index;
wire    [31:0]       wv_ee_cq_size;
wire               w_ee_resp_valid;
wire    [23:0]     wv_ee_cq_offset;

wire               w_cqm_init_finish;


wire        [367:0]     wv_md_from_dp_to_re_din;
wire                    w_md_from_dp_to_re_wr_en;
wire                    w_md_from_dp_to_re_rd_en;
wire        [367:0]     wv_md_from_dp_to_re_dout;
wire                    w_md_from_dp_to_re_empty;
wire                    w_md_from_dp_to_re_prog_full;
SyncFIFO_368w_32d MD_FROM_DP_TO_RE_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[0 * 32 + 1 : 0 * 32 + 0]),
	.WTSEL( rw_data[0 * 32 + 3 : 0 * 32 + 2]),
	.PTSEL( rw_data[0 * 32 + 5 : 0 * 32 + 4]),
	.VG(    rw_data[0 * 32 + 6 : 0 * 32 + 6]),
	.VS(    rw_data[0 * 32 + 7 : 0 * 32 + 7]),
 

  `endif

  .clk(clk),              
  .srst(rst),          
  .din(wv_md_from_dp_to_re_din),              
  .wr_en(w_md_from_dp_to_re_wr_en),          
  .rd_en(w_md_from_dp_to_re_rd_en),          
  .dout(wv_md_from_dp_to_re_dout),            
  .full(),            
  .empty(w_md_from_dp_to_re_empty),          
  .prog_full(w_md_from_dp_to_re_prog_full)   
);

wire        [255:0]     wv_nd_from_dp_to_re_din;
wire                    w_nd_from_dp_to_re_wr_en;
wire                    w_nd_from_dp_to_re_rd_en;
wire        [255:0]     wv_nd_from_dp_to_re_dout;
wire                    w_nd_from_dp_to_re_empty;
wire                    w_nd_from_dp_to_re_prog_full;
SyncFIFO_256w_16d ND_FROM_DP_TO_RE_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[1 * 32 + 1 : 1 * 32 + 0]),
	.WTSEL( rw_data[1 * 32 + 3 : 1 * 32 + 2]),
	.PTSEL( rw_data[1 * 32 + 5 : 1 * 32 + 4]),
	.VG(    rw_data[1 * 32 + 6 : 1 * 32 + 6]),
	.VS(    rw_data[1 * 32 + 7 : 1 * 32 + 7]),
 
  `endif

  .clk(clk),              
  .srst(rst),          
  .din(wv_nd_from_dp_to_re_din),              
  .wr_en(w_nd_from_dp_to_re_wr_en),          
  .rd_en(w_nd_from_dp_to_re_rd_en),          
  .dout(wv_nd_from_dp_to_re_dout),            
  .full(),            
  .empty(w_nd_from_dp_to_re_empty),          
  .prog_full(w_nd_from_dp_to_re_prog_full)   
);

wire        [127:0]     wv_entry_from_dp_to_re_din;
wire                    w_entry_from_dp_to_re_wr_en;
wire                    w_entry_from_dp_to_re_rd_en;
wire        [127:0]     wv_entry_from_dp_to_re_dout;
wire                    w_entry_from_dp_to_re_empty;
wire                    w_entry_from_dp_to_re_prog_full;
SyncFIFO_128w_32d ENTRY_FROM_DP_TO_RE_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[2 * 32 + 1 : 2 * 32 + 0]),
	.WTSEL( rw_data[2 * 32 + 3 : 2 * 32 + 2]),
	.PTSEL( rw_data[2 * 32 + 5 : 2 * 32 + 4]),
	.VG(    rw_data[2 * 32 + 6 : 2 * 32 + 6]),
	.VS(    rw_data[2 * 32 + 7 : 2 * 32 + 7]),
 
  `endif

  .clk(clk),              
  .srst(rst),          
  .din(wv_entry_from_dp_to_re_din),              
  .wr_en(w_entry_from_dp_to_re_wr_en),          
  .rd_en(w_entry_from_dp_to_re_rd_en),          
  .dout(wv_entry_from_dp_to_re_dout),            
  .full(),            
  .empty(w_entry_from_dp_to_re_empty),          
  .prog_full(w_entry_from_dp_to_re_prog_full)   
);

wire        [127:0]     wv_atomics_from_dp_to_re_din;
wire                    w_atomics_from_dp_to_re_wr_en;
wire                    w_atomics_from_dp_to_re_rd_en;
wire        [127:0]     wv_atomics_from_dp_to_re_dout;
wire                    w_atomics_from_dp_to_re_empty;
wire                    w_atomics_from_dp_to_re_prog_full;
SyncFIFO_128w_32d ATOMICS_FROM_DP_TO_RE_FIFO(
    
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[3 * 32 + 1 : 3 * 32 + 0]),
	.WTSEL( rw_data[3 * 32 + 3 : 3 * 32 + 2]),
	.PTSEL( rw_data[3 * 32 + 5 : 3 * 32 + 4]),
	.VG(    rw_data[3 * 32 + 6 : 3 * 32 + 6]),
	.VS(    rw_data[3 * 32 + 7 : 3 * 32 + 7]),
 
  `endif

  .clk(clk),              
  .srst(rst),          
  .din(wv_atomics_from_dp_to_re_din),              
  .wr_en(w_atomics_from_dp_to_re_wr_en),          
  .rd_en(w_atomics_from_dp_to_re_rd_en),          
  .dout(wv_atomics_from_dp_to_re_dout),            
  .full(),            
  .empty(w_atomics_from_dp_to_re_empty),          
  .prog_full(w_atomics_from_dp_to_re_prog_full)   
);

wire        [127:0]     wv_raddr_from_dp_to_re_din;
wire                    w_raddr_from_dp_to_re_wr_en;
wire                    w_raddr_from_dp_to_re_rd_en;
wire        [127:0]     wv_raddr_from_dp_to_re_dout;
wire                    w_raddr_from_dp_to_re_empty;
wire                    w_raddr_from_dp_to_re_prog_full;
SyncFIFO_128w_32d RADDR_FROM_DP_TO_RE_FIFO(
    
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[4 * 32 + 1 : 4 * 32 + 0]),
	.WTSEL( rw_data[4 * 32 + 3 : 4 * 32 + 2]),
	.PTSEL( rw_data[4 * 32 + 5 : 4 * 32 + 4]),
	.VG(    rw_data[4 * 32 + 6 : 4 * 32 + 6]),
	.VS(    rw_data[4 * 32 + 7 : 4 * 32 + 7]),
 
  `endif

  .clk(clk),              
  .srst(rst),          
  .din(wv_raddr_from_dp_to_re_din),              
  .wr_en(w_raddr_from_dp_to_re_wr_en),          
  .rd_en(w_raddr_from_dp_to_re_rd_en),          
  .dout(wv_raddr_from_dp_to_re_dout),            
  .full(),            
  .empty(w_raddr_from_dp_to_re_empty),          
  .prog_full(w_raddr_from_dp_to_re_prog_full)   
);

wire        [255:0]     wv_nd_from_req_to_trans_din;
wire                    w_nd_from_req_to_trans_wr_en;
wire                    w_nd_from_req_to_trans_rd_en;
wire        [255:0]     wv_nd_from_req_to_trans_dout;
wire                    w_nd_from_req_to_trans_empty;
wire                    w_nd_from_req_to_trans_prog_full;
SyncFIFO_256w_32d REQ_TO_TRANS_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[5 * 32 + 1 : 5 * 32 + 0]),
	.WTSEL( rw_data[5 * 32 + 3 : 5 * 32 + 2]),
	.PTSEL( rw_data[5 * 32 + 5 : 5 * 32 + 4]),
	.VG(    rw_data[5 * 32 + 6 : 5 * 32 + 6]),
	.VS(    rw_data[5 * 32 + 7 : 5 * 32 + 7]),
 
  `endif

  .clk(clk),              
  .srst(rst),          
  .din(wv_nd_from_req_to_trans_din),              
  .wr_en(w_nd_from_req_to_trans_wr_en),          
  .rd_en(w_nd_from_req_to_trans_rd_en),          
  .dout(wv_nd_from_req_to_trans_dout),            
  .full(),            
  .empty(w_nd_from_req_to_trans_empty),          
  .prog_full(w_nd_from_req_to_trans_prog_full)   
);

wire        [255:0]     wv_nd_from_resp_to_trans_din;
wire                    w_nd_from_resp_to_trans_wr_en;
wire                    w_nd_from_resp_to_trans_rd_en;
wire        [255:0]     wv_nd_from_resp_to_trans_dout;
wire                    w_nd_from_resp_to_trans_empty;
wire                    w_nd_from_resp_to_trans_prog_full;
wire 		[12:0]		wv_nd_from_resp_to_trans_data_count;
SyncFIFO_256w_32d RESP_TO_TRANS_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[6 * 32 + 1 : 6 * 32 + 0]),
	.WTSEL( rw_data[6 * 32 + 3 : 6 * 32 + 2]),
	.PTSEL( rw_data[6 * 32 + 5 : 6 * 32 + 4]),
	.VG(    rw_data[6 * 32 + 6 : 6 * 32 + 6]),
	.VS(    rw_data[6 * 32 + 7 : 6 * 32 + 7]),
 
  `endif

  .clk(clk),              
  .srst(rst),          
  .din(wv_nd_from_resp_to_trans_din),              
  .wr_en(w_nd_from_resp_to_trans_wr_en),          
  .rd_en(w_nd_from_resp_to_trans_rd_en),          
  .dout(wv_nd_from_resp_to_trans_dout),            
  .full(),            
  .empty(w_nd_from_resp_to_trans_empty),          
  .prog_full(w_nd_from_resp_to_trans_prog_full)
// .data_count(wv_nd_from_resp_to_trans_data_count)
);

//wire        [255:0]     wv_nd_from_trans_to_hp_din;
//wire                    w_nd_from_trans_to_hp_wr_en;
//wire                    w_nd_from_trans_to_hp_rd_en;
//wire        [255:0]     wv_nd_from_trans_to_hp_dout;
//wire                    w_nd_from_trans_to_hp_empty;
//wire                    w_nd_from_trans_to_hp_prog_full;
//SyncFIFO_256w_32d TRANS_TO_HP_FIFO(
//  .clk(clk),              
//  .srst(rst),          
//  .din(wv_nd_from_trans_to_hp_din),              
//  .wr_en(w_nd_from_trans_to_hp_wr_en),          
//  .rd_en(w_nd_from_trans_to_hp_rd_en),          
//  .dout(wv_nd_from_trans_to_hp_dout),            
//  .full(),            
//  .empty(w_nd_from_trans_to_hp_empty),          
//  .prog_full(w_nd_from_trans_to_hp_prog_full)   
//);

wire        [239:0]     wv_md_from_hp_to_rrc_din;
wire                    w_md_from_hp_to_rrc_wr_en;
wire                    w_md_from_hp_to_rrc_rd_en;
wire        [255:0]     wv_md_from_hp_to_rrc_dout;
wire                    w_md_from_hp_to_rrc_empty;
wire                    w_md_from_hp_to_rrc_prog_full;
SyncFIFO_256w_16d HP_TO_RRC_HEADER_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[7 * 32 + 1 : 7 * 32 + 0]),
	.WTSEL( rw_data[7 * 32 + 3 : 7 * 32 + 2]),
	.PTSEL( rw_data[7 * 32 + 5 : 7 * 32 + 4]),
	.VG(    rw_data[7 * 32 + 6 : 7 * 32 + 6]),
	.VS(    rw_data[7 * 32 + 7 : 7 * 32 + 7]),
 
  `endif

  .clk(clk),              
  .srst(rst),          
  .din({16'd0, wv_md_from_hp_to_rrc_din}),              
  .wr_en(w_md_from_hp_to_rrc_wr_en),          
  .rd_en(w_md_from_hp_to_rrc_rd_en),          
  .dout(wv_md_from_hp_to_rrc_dout),            
  .full(),            
  .empty(w_md_from_hp_to_rrc_empty),          
  .prog_full(w_md_from_hp_to_rrc_prog_full)   
);

wire        [255:0]     wv_nd_from_hp_to_rrc_din;
wire                    w_nd_from_hp_to_rrc_wr_en;
wire                    w_nd_from_hp_to_rrc_rd_en;
wire        [255:0]     wv_nd_from_hp_to_rrc_dout;
wire                    w_nd_from_hp_to_rrc_empty;
wire                    w_nd_from_hp_to_rrc_prog_full;
SyncFIFO_256w_16d HP_TO_RRC_DATA_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[8 * 32 + 1 : 8 * 32 + 0]),
	.WTSEL( rw_data[8 * 32 + 3 : 8 * 32 + 2]),
	.PTSEL( rw_data[8 * 32 + 5 : 8 * 32 + 4]),
	.VG(    rw_data[8 * 32 + 6 : 8 * 32 + 6]),
	.VS(    rw_data[8 * 32 + 7 : 8 * 32 + 7]),
 
  `endif

  .clk(clk),              
  .srst(rst),          
  .din(wv_nd_from_hp_to_rrc_din),              
  .wr_en(w_nd_from_hp_to_rrc_wr_en),          
  .rd_en(w_nd_from_hp_to_rrc_rd_en),          
  .dout(wv_nd_from_hp_to_rrc_dout),            
  .full(),            
  .empty(w_nd_from_hp_to_rrc_empty),          
  .prog_full(w_nd_from_hp_to_rrc_prog_full)   
);

wire        [319:0]     wv_md_from_hp_to_ee_din;
wire                    w_md_from_hp_to_ee_wr_en;
wire                    w_md_from_hp_to_ee_rd_en;
wire        [319:0]     wv_md_from_hp_to_ee_dout;
wire                    w_md_from_hp_to_ee_empty;
wire                    w_md_from_hp_to_ee_prog_full;
SyncFIFO_320w_16d HP_TO_EE_HEADER_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[9 * 32 + 1 : 9 * 32 + 0]),
	.WTSEL( rw_data[9 * 32 + 3 : 9 * 32 + 2]),
	.PTSEL( rw_data[9 * 32 + 5 : 9 * 32 + 4]),
	.VG(    rw_data[9 * 32 + 6 : 9 * 32 + 6]),
	.VS(    rw_data[9 * 32 + 7 : 9 * 32 + 7]),
 
  `endif

  .clk(clk),              
  .srst(rst),          
  .din(wv_md_from_hp_to_ee_din),              
  .wr_en(w_md_from_hp_to_ee_wr_en),          
  .rd_en(w_md_from_hp_to_ee_rd_en),          
  .dout(wv_md_from_hp_to_ee_dout),            
  .full(),            
  .empty(w_md_from_hp_to_ee_empty),          
  .prog_full(w_md_from_hp_to_ee_prog_full)   
);

wire        [255:0]     wv_nd_from_hp_to_ee_din;
wire                    w_nd_from_hp_to_ee_wr_en;
wire                    w_nd_from_hp_to_ee_rd_en;
wire        [255:0]     wv_nd_from_hp_to_ee_dout;
wire                    w_nd_from_hp_to_ee_empty;
wire                    w_nd_from_hp_to_ee_prog_full;
SyncFIFO_256w_16d HP_TO_EE_DATA_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[10 * 32 + 1 : 10 * 32 + 0]),
	.WTSEL( rw_data[10 * 32 + 3 : 10 * 32 + 2]),
	.PTSEL( rw_data[10 * 32 + 5 : 10 * 32 + 4]),
	.VG(    rw_data[10 * 32 + 6 : 10 * 32 + 6]),
	.VS(    rw_data[10 * 32 + 7 : 10 * 32 + 7]),
 
  `endif

  .clk(clk),              
  .srst(rst),          
  .din(wv_nd_from_hp_to_ee_din),              
  .wr_en(w_nd_from_hp_to_ee_wr_en),          
  .rd_en(w_nd_from_hp_to_ee_rd_en),          
  .dout(wv_nd_from_hp_to_ee_dout),            
  .full(),            
  .empty(w_nd_from_hp_to_ee_empty),          
  .prog_full(w_nd_from_hp_to_ee_prog_full)   
);

wire        w_swp_init_finish;
SendWQEProcessing SendWQEProcessing_Inst(
    .rw_data(rw_data[(11 + 11) * 32 - 1 : 11 * 32]),
    .init_rw_data(),
 
    .clk(clk),
    .rst(rst),

//Interface with PIO
    .i_pio_empty(i_pio_empty),
    .o_pio_rd_en(o_pio_rd_en),
    .iv_pio_data(iv_pio_data),

//Interface with CxtMgt
    //Channel 1 for DoorbellProcessing
    .o_db_cxtmgt_cmd_wr_en(o_db_cxtmgt_cmd_wr_en),
    .i_db_cxtmgt_cmd_prog_full(i_db_cxtmgt_cmd_prog_full),
    .ov_db_cxtmgt_cmd_data(ov_db_cxtmgt_cmd_data),

    .i_db_cxtmgt_resp_empty(i_db_cxtmgt_resp_empty),
    .o_db_cxtmgt_resp_rd_en(o_db_cxtmgt_resp_rd_en),
    .iv_db_cxtmgt_resp_data(iv_db_cxtmgt_resp_data),

    .i_db_cxtmgt_cxt_empty(i_db_cxtmgt_cxt_empty),
    .o_db_cxtmgt_cxt_rd_en(o_db_cxtmgt_cxt_rd_en),
    .iv_db_cxtmgt_cxt_data(iv_db_cxtmgt_cxt_data),

    //Channel 2 for WQEParser
    .o_wp_cxtmgt_cmd_wr_en(o_wp_cxtmgt_cmd_wr_en),
    .i_wp_cxtmgt_cmd_prog_full(i_wp_cxtmgt_cmd_prog_full),
    .ov_wp_cxtmgt_cmd_data(ov_wp_cxtmgt_cmd_data),

    .i_wp_cxtmgt_resp_empty(i_wp_cxtmgt_resp_empty),
    .o_wp_cxtmgt_resp_rd_en(o_wp_cxtmgt_resp_rd_en),
    .iv_wp_cxtmgt_resp_data(iv_wp_cxtmgt_resp_data),

    .i_wp_cxtmgt_cxt_empty(i_wp_cxtmgt_cxt_empty),
    .o_wp_cxtmgt_cxt_rd_en(o_wp_cxtmgt_cxt_rd_en),
    .iv_wp_cxtmgt_cxt_data(iv_wp_cxtmgt_cxt_data),

//Interface with VirtToPhys
    //Channel 1 for Doorbell Processing
    .o_db_vtp_cmd_wr_en(o_db_vtp_cmd_wr_en),
    .i_db_vtp_cmd_prog_full(i_db_vtp_cmd_prog_full),
    .ov_db_vtp_cmd_data(ov_db_vtp_cmd_data),

    .i_db_vtp_resp_empty(i_db_vtp_resp_empty),
    .o_db_vtp_resp_rd_en(o_db_vtp_resp_rd_en),
    .iv_db_vtp_resp_data(iv_db_vtp_resp_data),

    .i_db_vtp_wqe_empty(i_db_vtp_download_empty),
    .o_db_vtp_wqe_rd_en(o_db_vtp_download_rd_en),
    .iv_db_vtp_wqe_data(iv_db_vtp_download_data),
        
    //Channel 2 for WQEParser, read WQE
    .o_wp_vtp_wqe_cmd_wr_en(o_wp_vtp_wqe_cmd_wr_en),
    .i_wp_vtp_wqe_cmd_prog_full(i_wp_vtp_wqe_cmd_prog_full),
    .ov_wp_vtp_wqe_cmd_data(ov_wp_vtp_wqe_cmd_data),

    .i_wp_vtp_wqe_resp_empty(i_wp_vtp_wqe_resp_empty),
    .o_wp_vtp_wqe_resp_rd_en(o_wp_vtp_wqe_resp_rd_en),
    .iv_wp_vtp_wqe_resp_data(iv_wp_vtp_wqe_resp_data),

    .i_wp_vtp_wqe_empty(i_wp_vtp_wqe_download_empty),
    .o_wp_vtp_wqe_rd_en(o_wp_vtp_wqe_download_rd_en),
    .iv_wp_vtp_wqe_data(iv_wp_vtp_wqe_download_data),

    //Channel 3 for WQEParser, read network data
    .o_wp_vtp_nd_cmd_wr_en(o_wp_vtp_nd_cmd_wr_en),
    .i_wp_vtp_nd_cmd_prog_full(i_wp_vtp_nd_cmd_prog_full),
    .ov_wp_vtp_nd_cmd_data(ov_wp_vtp_nd_cmd_data),

    .i_wp_vtp_nd_resp_empty(i_wp_vtp_nd_resp_empty),
    .o_wp_vtp_nd_resp_rd_en(o_wp_vtp_nd_resp_rd_en),
    .iv_wp_vtp_nd_resp_data(iv_wp_vtp_nd_resp_data),

    .i_wp_vtp_nd_empty(i_wp_vtp_nd_download_empty),
    .o_wp_vtp_nd_rd_en(o_wp_vtp_nd_download_rd_en),
    .iv_wp_vtp_nd_data(iv_wp_vtp_nd_download_data),

//Interface with Requester Engine
    .i_entry_to_re_prog_full(w_entry_from_dp_to_re_prog_full),
    .o_entry_to_re_wr_en(w_entry_from_dp_to_re_wr_en),
    .ov_entry_to_re_data(wv_entry_from_dp_to_re_din),

    .i_atomics_to_re_prog_full(w_atomics_from_dp_to_re_prog_full),
    .o_atomics_to_re_wr_en(w_atomics_from_dp_to_re_wr_en),
    .ov_atomics_to_re_data(wv_atomics_from_dp_to_re_din),

    .i_raddr_to_re_prog_full(w_raddr_from_dp_to_re_prog_full),
    .o_raddr_to_re_wr_en(w_raddr_from_dp_to_re_wr_en),
    .ov_raddr_to_re_data(wv_raddr_from_dp_to_re_din),

    .i_nd_to_re_prog_full(w_nd_from_dp_to_re_prog_full),
    .o_nd_to_re_wr_en(w_nd_from_dp_to_re_wr_en),
    .ov_nd_to_re_data(wv_nd_from_dp_to_re_din),

    .i_md_to_re_prog_full(w_md_from_dp_to_re_prog_full),
    .o_md_to_re_wr_en(w_md_from_dp_to_re_wr_en),
    .ov_md_to_re_data(wv_md_from_dp_to_re_din),

    .o_swp_init_finish(w_swp_init_finish),
    
    .dbg_sel(wv_swp_dbg_sel),
    .dbg_bus(wv_swp_dbg_bus)
);

wire 	w_req_engine_init_finish;
wire 	[34 * 32 - 1 : 0] wv_init_rw_data_RequesterEngine;

RequesterEngine RequesterEngine_Inst(
    .rw_data(rw_data[(22 + 34) * 32 - 1 : 22 * 32]),
    .init_rw_data(wv_init_rw_data_RequesterEngine),

    .clk(clk),
    .rst(rst),

//Interface with SendWQEProcessing->DataPack
    .i_atomics_from_dp_empty(w_atomics_from_dp_to_re_empty),
    .o_atomics_from_dp_rd_en(w_atomics_from_dp_to_re_rd_en),
    .iv_atomics_from_dp_data(wv_atomics_from_dp_to_re_dout),

    .i_raddr_from_dp_empty(w_raddr_from_dp_to_re_empty),
    .o_raddr_from_dp_rd_en(w_raddr_from_dp_to_re_rd_en),
    .iv_raddr_from_dp_data(wv_raddr_from_dp_to_re_dout),

    .i_entry_from_dp_empty(w_entry_from_dp_to_re_empty),
    .o_entry_from_dp_rd_en(w_entry_from_dp_to_re_rd_en),
    .iv_entry_from_dp_data(wv_entry_from_dp_to_re_dout),

    .i_md_from_dp_empty(w_md_from_dp_to_re_empty),
    .o_md_from_dp_rd_en(w_md_from_dp_to_re_rd_en),
    .iv_md_from_dp_data(wv_md_from_dp_to_re_dout),

    .i_nd_from_dp_empty(w_nd_from_dp_to_re_empty),
    .o_nd_from_dp_rd_en(w_nd_from_dp_to_re_rd_en),
    .iv_nd_from_dp_data(wv_nd_from_dp_to_re_dout),

//Interface with BitWidthTrans
    .i_rpg_trans_prog_full(w_nd_from_req_to_trans_prog_full),
    .o_rpg_trans_wr_en(w_nd_from_req_to_trans_wr_en),
    .ov_rpg_trans_data(wv_nd_from_req_to_trans_din),

//Interface with CxtMgt
    //Channel 1
    .o_rtc_cxtmgt_cmd_wr_en(o_rtc_cxtmgt_cmd_wr_en),
    .i_rtc_cxtmgt_cmd_prog_full(i_rtc_cxtmgt_cmd_prog_full),
    .ov_rtc_cxtmgt_cmd_data(ov_rtc_cxtmgt_cmd_data),

    .i_rtc_cxtmgt_resp_empty(i_rtc_cxtmgt_resp_empty),
    .o_rtc_cxtmgt_resp_rd_en(o_rtc_cxtmgt_resp_rd_en),
    .iv_rtc_cxtmgt_resp_data(iv_rtc_cxtmgt_resp_data),

    .i_rtc_cxtmgt_cxt_empty(i_rtc_cxtmgt_cxt_empty),
    .o_rtc_cxtmgt_cxt_rd_en(o_rtc_cxtmgt_cxt_rd_en),
    .iv_rtc_cxtmgt_cxt_data(iv_rtc_cxtmgt_cxt_data),

/*Spyglass Add Begin*/
    .o_rtc_cxtmgt_cxt_wr_en(o_rtc_cxtmgt_cxt_wr_en),
    .i_rtc_cxtmgt_cxt_prog_full(i_rtc_cxtmgt_cxt_prog_full),
    .ov_rtc_cxtmgt_cxt_data(ov_rtc_cxtmgt_cxt_data),
/*Spyglass Add End*/

    //Channel 2
    .o_rrc_cxtmgt_cmd_wr_en(o_rrc_cxtmgt_cmd_wr_en),
    .i_rrc_cxtmgt_cmd_prog_full(i_rrc_cxtmgt_cmd_prog_full),
    .ov_rrc_cxtmgt_cmd_data(ov_rrc_cxtmgt_cmd_data),

    .i_rrc_cxtmgt_resp_empty(i_rrc_cxtmgt_resp_empty),
    .o_rrc_cxtmgt_resp_rd_en(o_rrc_cxtmgt_resp_rd_en),
    .iv_rrc_cxtmgt_resp_data(iv_rrc_cxtmgt_resp_data),

    .i_rrc_cxtmgt_cxt_empty(i_rrc_cxtmgt_cxt_empty),
    .o_rrc_cxtmgt_cxt_rd_en(o_rrc_cxtmgt_cxt_rd_en),
    .iv_rrc_cxtmgt_cxt_data(iv_rrc_cxtmgt_cxt_data),

    .o_rrc_cxtmgt_cxt_wr_en(o_rrc_cxtmgt_cxt_wr_en),
    .i_rrc_cxtmgt_cxt_prog_full(i_rrc_cxtmgt_cxt_prog_full),
    .ov_rrc_cxtmgt_cxt_data(ov_rrc_cxtmgt_cxt_data),

//VirtToPhys
    //Channel 1
    .o_rtc_vtp_cmd_wr_en(o_rtc_vtp_cmd_wr_en),
    .i_rtc_vtp_cmd_prog_full(i_rtc_vtp_cmd_prog_full),
    .ov_rtc_vtp_cmd_data(ov_rtc_vtp_cmd_data),

    .i_rtc_vtp_resp_empty(i_rtc_vtp_resp_empty),
    .o_rtc_vtp_resp_rd_en(o_rtc_vtp_resp_rd_en),
    .iv_rtc_vtp_resp_data(iv_rtc_vtp_resp_data),

    .o_rtc_vtp_upload_wr_en(o_rtc_vtp_upload_wr_en),
    .i_rtc_vtp_upload_prog_full(i_rtc_vtp_upload_prog_full),
    .ov_rtc_vtp_upload_data(ov_rtc_vtp_upload_data),

    //Channel 2
    .o_rrc_vtp_cmd_wr_en(o_rrc_vtp_cmd_wr_en),
    .i_rrc_vtp_cmd_prog_full(i_rrc_vtp_cmd_prog_full),
    .ov_rrc_vtp_cmd_data(ov_rrc_vtp_cmd_data),

    .i_rrc_vtp_resp_empty(i_rrc_vtp_resp_empty),
    .o_rrc_vtp_resp_rd_en(o_rrc_vtp_resp_rd_en),
    .iv_rrc_vtp_resp_data(iv_rrc_vtp_resp_data),

    .o_rrc_vtp_upload_wr_en(o_rrc_vtp_upload_wr_en),
    .i_rrc_vtp_upload_prog_full(i_rrc_vtp_upload_prog_full),
    .ov_rrc_vtp_upload_data(ov_rrc_vtp_upload_data),

//Header Parser
    .i_header_from_hp_empty(w_md_from_hp_to_rrc_empty),
    .o_header_from_hp_rd_en(w_md_from_hp_to_rrc_rd_en),
    .iv_header_from_hp_data(wv_md_from_hp_to_rrc_dout[239:0]),

    .iv_nd_from_hp_data(wv_nd_from_hp_to_rrc_dout),
    .i_nd_from_hp_empty(w_nd_from_hp_to_rrc_empty),
    .o_nd_from_hp_rd_en(w_nd_from_hp_to_rrc_rd_en),

//CQM
    .o_rtc_req_valid(w_rtc_req_valid),
    .ov_rtc_cq_index(wv_rtc_cq_index),
    .ov_rtc_cq_size(wv_rtc_cq_size),
    .i_rtc_resp_valid(w_rtc_resp_valid),
    .iv_rtc_cq_offset(wv_rtc_cq_offset),

    .o_rrc_req_valid(w_rrc_req_valid),
    .ov_rrc_cq_index(wv_rrc_cq_index),
    .ov_rrc_cq_size(wv_rrc_cq_size),
    .i_rrc_resp_valid(w_rrc_resp_valid),
    .iv_rrc_cq_offset(wv_rrc_cq_offset),

	 .o_req_engine_init_finish(w_req_engine_init_finish),

    .dbg_sel(wv_req_engine_dbg_sel),
    .dbg_bus(wv_req_engine_dbg_bus)
);

wire 	w_resp_engine_init_finish;
ResponderEngine ResponderEngine(
    .rw_data(rw_data[(56 + 13) * 32 - 1 : 56 * 32]),
    .init_rw_data(),

    .clk(clk),
    .rst(rst),

//HeaderParser
    .i_header_empty(w_md_from_hp_to_ee_empty),
    .iv_header_data(wv_md_from_hp_to_ee_dout),
    .o_header_rd_en(w_md_from_hp_to_ee_rd_en),

    .i_nd_empty(w_nd_from_hp_to_ee_empty),
    .iv_nd_data(wv_nd_from_hp_to_ee_dout),
    .o_nd_rd_en(w_nd_from_hp_to_ee_rd_en),

//VirtToPhys
    //Channel 1
    .o_ee_vtp_cmd_wr_en(o_ee_vtp_cmd_wr_en),
    .i_ee_vtp_cmd_prog_full(i_ee_vtp_cmd_prog_full),
    .ov_ee_vtp_cmd_data(ov_ee_vtp_cmd_data),

    .i_ee_vtp_resp_empty(i_ee_vtp_resp_empty),
    .o_ee_vtp_resp_rd_en(o_ee_vtp_resp_rd_en),
    .iv_ee_vtp_resp_data(iv_ee_vtp_resp_data),

    .o_ee_vtp_upload_wr_en(o_ee_vtp_upload_wr_en),
    .i_ee_vtp_upload_prog_full(i_ee_vtp_upload_prog_full),
    .ov_ee_vtp_upload_data(ov_ee_vtp_upload_data),

    .o_ee_vtp_download_rd_en(o_ee_vtp_download_rd_en),
    .i_ee_vtp_download_empty(i_ee_vtp_download_empty),
    .iv_ee_vtp_download_data(iv_ee_vtp_download_data),

    //Channel 2
    .o_rwm_vtp_cmd_wr_en(o_rwm_vtp_cmd_wr_en),
    .i_rwm_vtp_cmd_prog_full(i_rwm_vtp_cmd_prog_full),
    .ov_rwm_vtp_cmd_data(ov_rwm_vtp_cmd_data),

    .i_rwm_vtp_resp_empty(i_rwm_vtp_resp_empty),
    .o_rwm_vtp_resp_rd_en(o_rwm_vtp_resp_rd_en),
    .iv_rwm_vtp_resp_data(iv_rwm_vtp_resp_data),

    .o_rwm_vtp_download_rd_en(o_rwm_vtp_download_rd_en),
    .i_rwm_vtp_download_empty(i_rwm_vtp_download_empty),
    .iv_rwm_vtp_download_data(iv_rwm_vtp_download_data),

//CxtMgt
    //Channel 1 for ExecutionEngine
    .o_ee_cxtmgt_cmd_wr_en(o_ee_cxtmgt_cmd_wr_en),
    .i_ee_cxtmgt_cmd_prog_full(i_ee_cxtmgt_cmd_prog_full),
    .ov_ee_cxtmgt_cmd_data(ov_ee_cxtmgt_cmd_data),

    .i_ee_cxtmgt_resp_empty(i_ee_cxtmgt_resp_empty),
    .o_ee_cxtmgt_resp_rd_en(o_ee_cxtmgt_resp_rd_en),
    .iv_ee_cxtmgt_resp_data(iv_ee_cxtmgt_resp_data),

    .i_ee_cxtmgt_cxt_empty(i_ee_cxtmgt_cxt_empty),
    .o_ee_cxtmgt_cxt_rd_en(o_ee_cxtmgt_cxt_rd_en),
    .iv_ee_cxtmgt_cxt_data(iv_ee_cxtmgt_cxt_data),

    .o_ee_cxtmgt_cxt_wr_en(o_ee_cxtmgt_cxt_wr_en),
    .i_ee_cxtmgt_cxt_prog_full(i_ee_cxtmgt_cxt_prog_full),
    .ov_ee_cxtmgt_cxt_data(ov_ee_cxtmgt_cxt_data),

//RespPktGen
    .i_trans_prog_full(w_nd_from_resp_to_trans_prog_full),
    .o_trans_wr_en(w_nd_from_resp_to_trans_wr_en),
    .ov_trans_data(wv_nd_from_resp_to_trans_din),
	.iv_data_count(13'd0),

//CQM
    .o_ee_req_valid(w_ee_req_valid),
    .ov_ee_cq_index(wv_ee_cq_index),
    .ov_ee_cq_size(wv_ee_cq_size),
    .i_ee_resp_valid(w_ee_resp_valid),
    .iv_ee_cq_offset(wv_ee_cq_offset),

	.o_resp_engine_init_finish(w_resp_engine_init_finish),

    .dbg_sel(wv_resp_engine_dbg_sel),
    .dbg_bus(wv_resp_engine_dbg_bus)
);

HeaderParser HeaderParser_Inst(
    .clk(clk),
    .rst(rst),

//Interface with RequesterRecvControl
    .i_header_to_rrc_prog_full(w_md_from_hp_to_rrc_prog_full),
    .o_header_to_rrc_wr_en(w_md_from_hp_to_rrc_wr_en),
    .ov_header_to_rrc_data(wv_md_from_hp_to_rrc_din),

    .i_nd_to_rrc_prog_full(w_nd_from_hp_to_rrc_prog_full),
    .o_nd_to_rrc_wr_en(w_nd_from_hp_to_rrc_wr_en),
    .ov_nd_to_rrc_data(wv_nd_from_hp_to_rrc_din),

//ExecutionEngine
    .i_header_to_ee_prog_full(w_md_from_hp_to_ee_prog_full),
    .o_header_to_ee_wr_en(w_md_from_hp_to_ee_wr_en),
    .ov_header_to_ee_data(wv_md_from_hp_to_ee_din),

    .i_nd_to_ee_prog_full(w_nd_from_hp_to_ee_prog_full),
    .o_nd_to_ee_wr_en(w_nd_from_hp_to_ee_wr_en),
    .ov_nd_to_ee_data(wv_nd_from_hp_to_ee_din),

//BitTrans
    .i_bit_trans_empty(i_inbound_pkt_empty),
    .iv_bit_trans_data(iv_inbound_pkt_data),
    .o_bit_trans_rd_en(o_inbound_pkt_rd_en),
    
    .dbg_sel(wv_hp_dbg_sel),
    .dbg_bus(wv_hp_dbg_bus)
);

EgressArbiter	EgressArbiter_Inst(
    .clk(clk),
    .rst(rst),

//In.
    .i_req_trans_empty(w_nd_from_req_to_trans_empty),
    .o_req_trans_rd_en(w_nd_from_req_to_trans_rd_en),
    .iv_req_trans_data(wv_nd_from_req_to_trans_dout),

//Re.
    .i_resp_trans_empty(w_nd_from_resp_to_trans_empty),
    .o_resp_trans_rd_en(w_nd_from_resp_to_trans_rd_en),
    .iv_resp_trans_data(wv_nd_from_resp_to_trans_dout),

//To.
    .i_outbound_pkt_prog_full(i_outbound_pkt_prog_full),
    .o_outbound_pkt_wr_en(o_outbound_pkt_wr_en),
    .ov_outbound_pkt_data(ov_outbound_pkt_data),

    .dbg_sel(wv_ea_dbg_sel),
    .dbg_bus(wv_ea_dbg_bus)
);

CompletionQueueMgt CQM_Inst(  //CQM for short 
    .rw_data(rw_data[(69 + 2) * 32 - 1 : 69 * 32]),
    .init_rw_data(),

    .clk(clk),
    .rst(rst),

//Interface with RTC
    .i_rtc_req_valid(w_rtc_req_valid),
    .iv_rtc_cq_index(wv_rtc_cq_index),
    .iv_rtc_cq_size(wv_rtc_cq_size),
    .o_rtc_resp_valid(w_rtc_resp_valid),
    .ov_rtc_cq_offset(wv_rtc_cq_offset),

//Interface with RRC
    .i_rrc_req_valid(w_rrc_req_valid),
    .iv_rrc_cq_index(wv_rrc_cq_index),
    .iv_rrc_cq_size(wv_rrc_cq_size),
    .o_rrc_resp_valid(w_rrc_resp_valid),
    .ov_rrc_cq_offset(wv_rrc_cq_offset),

//Interface with EE
    .i_ee_req_valid(w_ee_req_valid),
    .iv_ee_cq_index(wv_ee_cq_index),
    .iv_ee_cq_size(wv_ee_cq_size),
    .o_ee_resp_valid(w_ee_resp_valid),
    .ov_ee_cq_offset(wv_ee_cq_offset),

    .o_cqm_init_finish(w_cqm_init_finish),

    .dbg_sel(wv_cqm_dbg_sel),
    .dbg_bus(wv_cqm_dbg_bus)
);

assign o_rdma_init_finish = w_req_engine_init_finish && w_resp_engine_init_finish && w_cqm_init_finish && w_swp_init_finish;

assign init_rw_data = {
							{15{32'd0}},
							{wv_init_rw_data_RequesterEngine},
							{22{32'd0}}
						};

endmodule
