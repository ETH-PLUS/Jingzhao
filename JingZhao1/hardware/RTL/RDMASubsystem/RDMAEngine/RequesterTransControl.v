`timescale 1ns / 1ps

`include "sw_hw_interface_const_def_h.vh"
`include "msg_def_v2p_h.vh"
`include "msg_def_ctxmgt_h.vh"
`include "ib_constant_def_h.vh"
`include "chip_include_rdma.vh"


module RequesterTransControl( //"rtc" for short
    input   wire                clk,
    input   wire                rst,

//Interface with DataPack
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

//CxtMgt
    output  wire                o_cxtmgt_cmd_wr_en,
    input   wire                i_cxtmgt_cmd_prog_full,
    output  wire    [127:0]     ov_cxtmgt_cmd_data,

    input   wire                i_cxtmgt_resp_empty,
    output  wire                o_cxtmgt_resp_rd_en,
    input   wire    [127:0]     iv_cxtmgt_resp_data,

    input   wire                i_cxtmgt_cxt_empty,
    output  wire                o_cxtmgt_cxt_rd_en,
    input   wire    [191:0]     iv_cxtmgt_cxt_data,

    input   wire                i_cxtmgt_cxt_prog_full,
    output  wire                o_cxtmgt_cxt_wr_en,
    output  wire    [127:0]     ov_cxtmgt_cxt_data,

//VirtToPhys
    output  wire                o_vtp_cmd_wr_en,
    input   wire                i_vtp_cmd_prog_full,
    output  wire    [255:0]     ov_vtp_cmd_data,

    input   wire                i_vtp_resp_empty,
    output  wire                o_vtp_resp_rd_en,
    input   wire    [7:0]       iv_vtp_resp_data,

    output  wire                o_vtp_upload_wr_en,
    input   wire                i_vtp_upload_prog_full,
    output  wire    [255:0]     ov_vtp_upload_data,

//RequesterRecvControl
    input   wire                i_br_prog_full,
    output  wire                o_br_wr_en,
    output  wire    [127:0]      ov_br_data,

//ReqPktGen
    input   wire                i_header_to_rpg_prog_full,
    output  wire                o_header_to_rpg_wr_en,
    output  wire    [319:0]     ov_header_to_rpg_data,

    input   wire                i_nd_to_rpg_prog_full,
    output  wire                o_nd_to_rpg_wr_en,
    output  wire    [255:0]     ov_nd_to_rpg_data,

//TimerControl
    input   wire                i_te_prog_full,
    output  wire                o_te_wr_en,
    output  wire    [63:0]      ov_te_data,

//CQ Offset Table
    // output  wire    [0:0]       o_cq_offset_table_wea,
    // output  wire    [13:0]      ov_cq_offset_table_addra,
    // output  wire    [15:0]      ov_cq_offset_table_dina,
    // input   wire    [15:0]      iv_cq_offset_table_douta,
    //Interface with CQM
    output   wire                o_rtc_req_valid,
    output   wire    [23:0]      ov_rtc_cq_index,
    output   wire    [31:0]       ov_rtc_cq_size,
    input  wire                i_rtc_resp_valid,
    input  wire     [23:0]     iv_rtc_cq_offset,

//MultiQueue
    //Read Packet Buffer
    output  wire                o_rpb_list_head_wea,
    output  wire    [13:0]      ov_rpb_list_head_addra,
    output  wire    [8:0]       ov_rpb_list_head_dina,
    input   wire    [8:0]       iv_rpb_list_head_douta,

    output  wire                o_rpb_list_tail_wea,
    output  wire    [13:0]      ov_rpb_list_tail_addra,
    output  wire    [8:0]       ov_rpb_list_tail_dina,
    input   wire    [8:0]       iv_rpb_list_tail_douta,

    output  wire                o_rpb_list_empty_wea,
    output  wire    [13:0]      ov_rpb_list_empty_addra,
    output  wire    [0:0]       ov_rpb_list_empty_dina,
	input   wire    [0:0]       iv_rpb_list_empty_douta,

    output  wire                o_rpb_content_wea,
    output  wire    [8:0]       ov_rpb_content_addra,
    output  wire    [261:0]     ov_rpb_content_dina,
    input   wire    [261:0]     iv_rpb_content_douta,

    output  wire                o_rpb_next_wea,
    output  wire    [8:0]       ov_rpb_next_addra,
    output  wire    [9:0]       ov_rpb_next_dina,
    input   wire    [9:0]       iv_rpb_next_douta,

    input   wire    [8:0]       iv_rpb_free_data,
    output  wire                o_rpb_free_rd_en,
    input   wire                i_rpb_free_empty,
    input   wire    [9:0]       iv_rpb_free_data_count,

    //Read Entry Buffer
    output  wire                o_reb_list_head_wea,
    output  wire    [13:0]      ov_reb_list_head_addra,
    output  wire    [13:0]      ov_reb_list_head_dina,
    input   wire    [13:0]      iv_reb_list_head_douta,

    output  wire                o_reb_list_tail_wea,
    output  wire    [13:0]      ov_reb_list_tail_addra,
    output  wire    [13:0]      ov_reb_list_tail_dina,
    input   wire    [13:0]      iv_reb_list_tail_douta,

    output  wire                o_reb_list_empty_wea,
    output  wire    [13:0]      ov_reb_list_empty_addra,
    output  wire    [0:0]       ov_reb_list_empty_dina,
    input   wire    [0:0]       iv_reb_list_empty_douta,

    output  wire                o_reb_content_wea,
    output  wire    [13:0]      ov_reb_content_addra,
    output  wire    [127:0]     ov_reb_content_dina,
    input   wire    [127:0]     iv_reb_content_douta,

    output  wire                o_reb_next_wea,
    output  wire    [13:0]      ov_reb_next_addra,
    output  wire    [14:0]      ov_reb_next_dina,
    input   wire    [14:0]      iv_reb_next_douta,

    input   wire    [13:0]      iv_reb_free_data,
    output  wire                o_reb_free_rd_en,
    input   wire                i_reb_free_empty,
    input   wire    [14:0]      iv_reb_free_data_count,

    //Send/Write Buffer
    output  wire                o_swpb_list_head_wea,
    output  wire    [13:0]      ov_swpb_list_head_addra,
    output  wire    [11:0]      ov_swpb_list_head_dina,
    input   wire    [11:0]      iv_swpb_list_head_douta,

    output  wire                o_swpb_list_tail_wea,
    output  wire    [13:0]      ov_swpb_list_tail_addra,
    output  wire    [11:0]      ov_swpb_list_tail_dina,
    input   wire    [11:0]      iv_swpb_list_tail_douta,

    output  wire                o_swpb_list_empty_wea,
    output  wire    [13:0]      ov_swpb_list_empty_addra,
    output  wire    [0:0]       ov_swpb_list_empty_dina,
    input   wire    [0:0]       iv_swpb_list_empty_douta,

    output  wire    [11:0]      ov_swpb_content_addra,
    output  wire    [287:0]     ov_swpb_content_dina,
    input   wire    [287:0]     iv_swpb_content_douta,
    output  wire                o_swpb_content_wea,

    output  wire    [11:0]      ov_swpb_next_addra,
    output  wire    [12:0]      ov_swpb_next_dina,
    input   wire    [12:0]      iv_swpb_next_douta,
    output  wire                o_swpb_next_wea,

    input   wire    [11:0]      iv_swpb_free_data,
    output  wire                o_swpb_free_rd_en,
    input   wire                i_swpb_free_empty,
    input   wire    [12:0]      iv_swpb_free_data_count,

    input   wire    [31:0]      dbg_sel,
    output  wire    [32 - 1:0]      dbg_bus
    //output  wire    [`DBG_NUM_REQUESTER_TRANS_CONTROL * 32 - 1:0]      dbg_bus
);

/*----------------------------------------  Part 1: Signals Definition and Submodules Connection ----------------------------------------*/

reg 		[31:0]			qv_swpb_content_table_init_counter;
reg 		[31:0]			qv_rpb_content_table_init_counter;
reg 	[31:0]			qv_reb_next_table_init_counter;
reg 	[31:0]			qv_rpb_next_table_init_counter;
reg 	[31:0]			qv_swpb_next_table_init_counter;

wire        [23:0]          wv_cqn;

wire		[31:0]          wv_imm;
wire		[15:0]          wv_PKey;
wire		[31:0]          wv_scq_pd;
wire        [31:0]          wv_scq_lkey;
wire        [31:0]          wv_scq_length;
wire		[31:0]          wv_qkey;
wire		[31:0]          wv_msg_size;
wire		[23:0]          wv_src_qpn;
wire		[23:0]          wv_dst_qpn;
wire		[2:0]           wv_ser;
wire		[4:0]           wv_opcode;
wire		[3:0]           wv_err_type;
wire		                w_fence;
wire		[7:0]           wv_legal_entry;
wire 		[31:0]			wv_cur_wqe_offset;

wire		[2:0]           wv_qp_state;
reg 						q_flush_finish;
wire		                w_rc_msg_can_be_sent;

reg 		[23:0]			qv_timer_qpn;

wire		                w_read_allowed;
wire		                w_write_allowed;
wire		                w_atomics_allowed;
wire		                w_send_allowed;
wire		                w_pkt_allowed;


wire		[8:0]           wv_rpb_head;
wire		[8:0]           wv_rpb_tail;
wire		                w_rpb_empty;

wire		[13:0]          wv_reb_head;
wire		[13:0]          wv_reb_tail;
wire		                w_reb_empty;

wire		[11:0]          wv_swpb_head;
wire		[11:0]          wv_swpb_tail;
wire		                w_swpb_empty;


wire		[127:0]         wv_RETH;
wire 		[127:0]			wv_DETH;
wire		[31:0]			wv_vtp_flags;
    //Interface with DataPack
reg     		           	q_atomics_from_dp_rd_en;
reg     		           	q_raddr_from_dp_rd_en;
reg     		           	q_entry_from_dp_rd_en;
reg     		           	q_md_from_dp_rd_en;
reg     		           	q_nd_from_dp_rd_en;
    //CxtMgt
reg     	       			q_cxtmgt_cmd_wr_en;
reg     	[127:0]    		qv_cxtmgt_cmd_data;
reg     	           		q_cxtmgt_cxt_wr_en;
reg     	[127:0]    		qv_cxtmgt_cxt_data;
reg     	           		q_cxtmgt_resp_rd_en;
reg     	           		q_cxtmgt_cxt_rd_en;
    //VirtToPhys
reg    		            	q_vtp_cmd_wr_en;
reg    		[255:0]     	qv_vtp_cmd_data;
reg    		            	q_vtp_resp_rd_en;
reg    		            	q_vtp_upload_wr_en;
reg    		[255:0]     	qv_vtp_upload_data;

    //RequesterRecvControl
reg    		            	q_br_wr_en;
reg    		[127:0]      	qv_br_data;

    //ReqPktGen
reg    		            	q_header_to_rpg_wr_en;
reg    		[319:0]     	qv_header_to_rpg_data;

reg                			q_nd_to_rpg_wr_en;
reg    		[255:0]     	qv_nd_to_rpg_data;

    //TimerControl
reg    			            q_te_wr_en;
reg    		[63:0]      	qv_te_data;

    //MultiQueue
        //Read Packet Buffer
reg    		[13:0]      	qv_rpb_list_head_addra;
reg    		[9:0]       	qv_rpb_list_head_dina;
reg    		            	q_rpb_list_head_wea;

reg    		[13:0]      	qv_rpb_list_tail_addra;
reg    		[9:0]       	qv_rpb_list_tail_dina;
reg    		            	q_rpb_list_tail_wea;

reg    		[13:0]      	qv_rpb_list_empty_addra;
reg    		[0:0]       	qv_rpb_list_empty_dina;
reg    		            	q_rpb_list_empty_wea;

reg    		            	q_rpb_content_wea;
reg    		[8:0]       	qv_rpb_content_addra;
reg    		[261:0]     	qv_rpb_content_dina;

reg    		            	q_rpb_next_wea;
reg    		[8:0]       	qv_rpb_next_addra;
reg    		[9:0]       	qv_rpb_next_dina;
reg    		            	q_rpb_free_rd_en;

        //Read Entry Buffer
reg    		[13:0]      	qv_reb_list_head_addra;
reg    		[13:0]      	qv_reb_list_head_dina;
reg    		            	q_reb_list_head_wea;

reg    		[13:0]      	qv_reb_list_tail_addra;
reg    		[13:0]      	qv_reb_list_tail_dina;
reg    		            	q_reb_list_tail_wea;

reg    		[13:0]      	qv_reb_list_empty_addra;
reg    		[0:0]       	qv_reb_list_empty_dina;
reg    		            	q_reb_list_empty_wea;

reg    		            	q_reb_content_wea;
reg    		[13:0]      	qv_reb_content_addra;
reg    		[127:0]     	qv_reb_content_dina;

reg    		            	q_reb_next_wea;
reg    		[13:0]      	qv_reb_next_addra;
reg    		[14:0]      	qv_reb_next_dina;

reg    		            	q_reb_free_rd_en;

        //Send/Write Buffer
reg    		[13:0]      	qv_swpb_list_head_addra;
reg    		[11:0]      	qv_swpb_list_head_dina;
reg    		            	q_swpb_list_head_wea;

reg    		[13:0]      	qv_swpb_list_tail_addra;
reg    		[11:0]      	qv_swpb_list_tail_dina;
reg    		            	q_swpb_list_tail_wea;

reg    		[13:0]      	qv_swpb_list_empty_addra;
reg    		[0:0]       	qv_swpb_list_empty_dina;
reg    		            	q_swpb_list_empty_wea;

reg    		[11:0]      	qv_swpb_content_addra;
reg    		[287:0]     	qv_swpb_content_dina;
reg    		            	q_swpb_content_wea;

reg    		[11:0]      	qv_swpb_next_addra;
reg    		[12:0]      	qv_swpb_next_dina;
reg    		            	q_swpb_next_wea;

reg    		            	q_swpb_free_rd_en;

/********** Temporary Registers *************/
reg    		[13:0]      	qv_rpb_list_head_addra_TempReg;
reg    		[9:0]       	qv_rpb_list_head_dina_TempReg;

reg    		[13:0]      	qv_rpb_list_tail_addra_TempReg;
reg    		[9:0]       	qv_rpb_list_tail_dina_TempReg;

reg    		[13:0]      	qv_rpb_list_empty_addra_TempReg;
reg    		[0:0]       	qv_rpb_list_empty_dina_TempReg;

reg    		[8:0]       	qv_rpb_content_addra_TempReg;
reg    		[261:0]     	qv_rpb_content_dina_TempReg;

reg    		[8:0]       	qv_rpb_next_addra_TempReg;
reg    		[9:0]       	qv_rpb_next_dina_TempReg;

        //Read Entry Buffer
reg    		[13:0]      	qv_reb_list_head_addra_TempReg;
reg    		[13:0]      	qv_reb_list_head_dina_TempReg;

reg    		[13:0]      	qv_reb_list_tail_addra_TempReg;
reg    		[13:0]      	qv_reb_list_tail_dina_TempReg;

reg    		[13:0]      	qv_reb_list_empty_addra_TempReg;
reg    		[0:0]       	qv_reb_list_empty_dina_TempReg;

reg    		[13:0]      	qv_reb_content_addra_TempReg;
reg    		[127:0]     	qv_reb_content_dina_TempReg;

reg    		[13:0]      	qv_reb_next_addra_TempReg;
reg    		[14:0]      	qv_reb_next_dina_TempReg;

        //Send/Write Buffer
reg    		[13:0]      	qv_swpb_list_head_addra_TempReg;
reg    		[11:0]      	qv_swpb_list_head_dina_TempReg;

reg    		[13:0]      	qv_swpb_list_tail_addra_TempReg;
reg    		[11:0]      	qv_swpb_list_tail_dina_TempReg;

reg    		[13:0]      	qv_swpb_list_empty_addra_TempReg;
reg    		[0:0]       	qv_swpb_list_empty_dina_TempReg;

reg    		[11:0]      	qv_swpb_content_addra_TempReg;
reg    		[287:0]     	qv_swpb_content_dina_TempReg;

reg    		[11:0]      	qv_swpb_next_addra_TempReg;
reg    		[12:0]      	qv_swpb_next_dina_TempReg;
/************************************/
// reg    		[0:0]       	q_cq_offset_table_wea;
// reg    		[13:0]      	qv_cq_offset_table_addra;
// reg    		[15:0]      	qv_cq_offset_table_dina;

reg                     	q_first_pkt;
reg     	[15:0]      	qv_PMTU;
reg     	[31:0]      	qv_msg_data_left;
// reg     [15:0]          qv_pkt_left;
reg                     	q_last_pkt;
reg     	[15:0]      	qv_seg_left;
reg     	[15:0]      	qv_seg_total;
reg     	[7:0]       	qv_entry_left;
reg     	[2:0]       	qv_ser;

reg 						q_start_timer;
reg     	[319:0]         qv_pkt_header;
//reg     	[255:0]         qv_pkt_header;
reg     	[7:0]           qv_header_len;

reg 		[31:0]			qv_left_payload_counter;

//For debug 
reg 	[31:0]		qv_DebugCounter_entry_rd_en;
reg 			[31:0]			qv_my_qpn;
reg 			[31:0]			qv_my_ee;
reg 			[31:0]			qv_rqpn;
reg 			[15:0]			qv_rlid;
reg 			[15:0]			qv_sl_g_mlpath;
reg 			[31:0]			qv_imm_etype_pkey_eec;
reg 			[31:0]			qv_byte_cnt;
reg 			[31:0]			qv_wqe;
reg 			[7:0]			qv_owner;
reg 			[7:0]			qv_is_send;
reg 			[7:0]			qv_opcode;

reg 			[7:0]			qv_vendor_err;
reg 			[7:0]			qv_syndrome;
reg 			[3:0]		qv_vtp_type;
reg 			[3:0]		qv_vtp_opcode;
reg 			[31:0]		qv_vtp_pd;
reg 			[31:0]		qv_vtp_lkey;
reg 			[63:0]		qv_vtp_vaddr;
reg 			[31:0]		qv_vtp_length;
reg     [23:0]          qv_next_psn;
reg 		[5:0] 		qv_PMTU_fwd;
reg 			[3:0]		qv_mthca_mpt_flag_sw_owns;
reg 						q_absolute_addr;
reg 						q_relative_addr;
reg 						q_mthca_mpt_flag_mio;
reg 						q_mthca_mpt_flag_bind_enable;
reg 						q_mthca_mpt_flag_physical;
reg 						q_mthca_mpt_flag_region;
reg 						q_ibv_access_on_demand;
reg 						q_ibv_access_zero_based;
reg 						q_ibv_access_mw_bind;
reg 						q_ibv_access_remote_atomic;
reg 						q_ibv_access_remote_read;
reg 						q_ibv_access_remote_write;
reg 						q_ibv_access_local_write;

reg 			[1:0]		qv_err_point;





assign o_atomics_from_dp_rd_en = q_atomics_from_dp_rd_en;
assign o_raddr_from_dp_rd_en = q_raddr_from_dp_rd_en;
assign o_entry_from_dp_rd_en = q_entry_from_dp_rd_en;

assign o_md_from_dp_rd_en = q_md_from_dp_rd_en;
assign o_nd_from_dp_rd_en = q_nd_from_dp_rd_en;

assign o_cxtmgt_cmd_wr_en = q_cxtmgt_cmd_wr_en;
assign ov_cxtmgt_cmd_data = qv_cxtmgt_cmd_data;
assign o_cxtmgt_cxt_wr_en = q_cxtmgt_cxt_wr_en;
assign ov_cxtmgt_cxt_data = qv_cxtmgt_cxt_data;
assign o_cxtmgt_resp_rd_en = q_cxtmgt_resp_rd_en;
assign o_cxtmgt_cxt_rd_en = q_cxtmgt_cxt_rd_en;

assign o_vtp_cmd_wr_en = q_vtp_cmd_wr_en;
assign ov_vtp_cmd_data = qv_vtp_cmd_data;
assign o_vtp_resp_rd_en = q_vtp_resp_rd_en;
assign o_vtp_upload_wr_en = q_vtp_upload_wr_en;
assign ov_vtp_upload_data = qv_vtp_upload_data;

assign o_br_wr_en = q_br_wr_en;
assign ov_br_data = qv_br_data;

assign o_header_to_rpg_wr_en = q_header_to_rpg_wr_en;
assign ov_header_to_rpg_data = qv_header_to_rpg_data;

assign o_nd_to_rpg_wr_en = q_nd_to_rpg_wr_en;
assign ov_nd_to_rpg_data = qv_nd_to_rpg_data;

assign o_te_wr_en = q_te_wr_en;
assign ov_te_data = qv_te_data;

//RPB Queue
assign o_rpb_list_head_wea = q_rpb_list_head_wea;
assign ov_rpb_list_head_addra = qv_rpb_list_head_addra;
assign ov_rpb_list_head_dina = qv_rpb_list_head_dina;
assign o_rpb_list_tail_wea = q_rpb_list_tail_wea;
assign ov_rpb_list_tail_addra = qv_rpb_list_tail_addra;
assign ov_rpb_list_tail_dina = qv_rpb_list_tail_dina;
assign o_rpb_list_empty_wea = q_rpb_list_empty_wea;
assign ov_rpb_list_empty_addra = qv_rpb_list_empty_addra;
assign ov_rpb_list_empty_dina = qv_rpb_list_empty_dina;

assign o_rpb_content_wea = q_rpb_content_wea;
assign ov_rpb_content_addra = qv_rpb_content_addra;
assign ov_rpb_content_dina = qv_rpb_content_dina;
assign o_rpb_next_wea = q_rpb_next_wea;
assign ov_rpb_next_addra = qv_rpb_next_addra;
assign ov_rpb_next_dina = qv_rpb_next_dina;
assign o_rpb_free_rd_en = q_rpb_free_rd_en;

//REB Queue
assign o_reb_list_head_wea = q_reb_list_head_wea;
assign ov_reb_list_head_addra = qv_reb_list_head_addra;
assign ov_reb_list_head_dina = qv_reb_list_head_dina;
assign o_reb_list_tail_wea = q_reb_list_tail_wea;
assign ov_reb_list_tail_addra = qv_reb_list_tail_addra;
assign ov_reb_list_tail_dina = qv_reb_list_tail_dina;
assign o_reb_list_empty_wea = q_reb_list_empty_wea;
assign ov_reb_list_empty_addra = qv_reb_list_empty_addra;
assign ov_reb_list_empty_dina = qv_reb_list_empty_dina;

assign o_reb_content_wea = q_reb_content_wea;
assign ov_reb_content_addra = qv_reb_content_addra;
assign ov_reb_content_dina = qv_reb_content_dina;
assign o_reb_next_wea = q_reb_next_wea;
assign ov_reb_next_addra = qv_reb_next_addra;
assign ov_reb_next_dina = qv_reb_next_dina;
assign o_reb_free_rd_en = q_reb_free_rd_en;

//SWPB Queue
assign o_swpb_list_head_wea = q_swpb_list_head_wea;
assign ov_swpb_list_head_addra = qv_swpb_list_head_addra;
assign ov_swpb_list_head_dina = qv_swpb_list_head_dina;
assign o_swpb_list_tail_wea = q_swpb_list_tail_wea;
assign ov_swpb_list_tail_addra = qv_swpb_list_tail_addra;
assign ov_swpb_list_tail_dina = qv_swpb_list_tail_dina;
assign o_swpb_list_empty_wea = q_swpb_list_empty_wea;
assign ov_swpb_list_empty_addra = qv_swpb_list_empty_addra;
assign ov_swpb_list_empty_dina = qv_swpb_list_empty_dina;

assign ov_swpb_content_addra = qv_swpb_content_addra;
assign ov_swpb_content_dina = qv_swpb_content_dina;
assign o_swpb_content_wea = q_swpb_content_wea;
assign ov_swpb_next_addra = qv_swpb_next_addra;
assign ov_swpb_next_dina = qv_swpb_next_dina;
assign o_swpb_next_wea = q_swpb_next_wea;
assign o_swpb_free_rd_en = q_swpb_free_rd_en;

// assign o_cq_offset_table_wea = q_cq_offset_table_wea;
// assign ov_cq_offset_table_addra = qv_cq_offset_table_addra;
// assign ov_cq_offset_table_dina = qv_cq_offset_table_dina;

//assign wv_RETH = {iv_raddr_from_dp_data[31:0], iv_raddr_from_dp_data[63:32], iv_raddr_from_dp_data[127:64]};
assign wv_RETH = {wv_msg_size, iv_raddr_from_dp_data[95:64], iv_raddr_from_dp_data[31:0], iv_raddr_from_dp_data[63:32]};

wire 	[47:0]		wv_dst_LID_MAC;
wire 	[31:0]		wv_dst_IP;

assign wv_dst_LID_MAC = iv_md_from_dp_data[367:320];
assign wv_dst_IP = iv_md_from_dp_data[319:288];

assign wv_DETH = {wv_dst_LID_MAC, wv_dst_IP, wv_src_qpn[15:0], wv_qkey}; 	//We only use lower 16 bits of qpn to shorten DETH

/*----------------------------------------  Part 2: State Machine Transition ------------------------------------------------------------*/
reg     [3:0]       RTC_cur_state;
reg     [3:0]       RTC_next_state;

parameter   [3:0]   RTC_INIT_s 			= 4'd0,
					RTC_IDLE_s          = 4'd1,
                    RTC_FETCH_CXT_s     = 4'd2,
                    RTC_RESP_CXT_s      = 4'd3,
                    RTC_FLUSH_s         = 4'd4,
                    RTC_RC_BAD_REQ_s    = 4'd5,
                    RTC_RC_JUDGE_s      = 4'd6,
                    RTC_RC_SEG_s        = 4'd7,
                    RTC_RC_FWD_s        = 4'd8,
                    RTC_RC_STE_s        = 4'd9,     //Store Entry
                    RTC_UCUD_SEG_s      = 4'd10,
                    RTC_UCUD_FWD_s      = 4'd11,
                    RTC_UCUD_CPL_s      = 4'd12,
                    RTC_WB_CXT_s        = 4'd13,
					RTC_START_TIMER_s   = 4'd14;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        RTC_cur_state <= RTC_INIT_s;        
    end
    else begin
        RTC_cur_state <= RTC_next_state;
    end
end

always @(*) begin
    case(RTC_cur_state)
		RTC_INIT_s:			if((qv_swpb_content_table_init_counter == `SWPB_CONTENT_FREE_NUM - 1) &&
								(qv_rpb_content_table_init_counter == `RPB_CONTENT_FREE_NUM - 1) &&
								(qv_rpb_next_table_init_counter == `RPB_CONTENT_FREE_NUM - 1) &&
								(qv_reb_next_table_init_counter == `REB_CONTENT_FREE_NUM - 1) &&
								(qv_swpb_next_table_init_counter == `SWPB_CONTENT_FREE_NUM - 1)) begin
								RTC_next_state = RTC_IDLE_s;
							end 
							else begin
								RTC_next_state = RTC_INIT_s;
							end 
        RTC_IDLE_s:         if(!i_md_from_dp_empty) begin
                                RTC_next_state = RTC_FETCH_CXT_s;
                            end
                            else begin
                                RTC_next_state = RTC_IDLE_s;
                            end
        RTC_FETCH_CXT_s:    if(!i_cxtmgt_cmd_prog_full) begin
                                RTC_next_state = RTC_RESP_CXT_s;
                            end
                            else begin
                                RTC_next_state = RTC_FETCH_CXT_s;
                            end
        RTC_RESP_CXT_s:     if(!i_cxtmgt_resp_empty && !i_cxtmgt_cxt_empty) begin
                                if((wv_qp_state == `QP_SQE) || (wv_qp_state == `QP_SQD) || (wv_qp_state == `QP_ERR)) begin
                                    RTC_next_state = RTC_FLUSH_s;
                                end
                                else if(wv_ser == `RC && wv_err_type == `QP_NORMAL) begin
                                    RTC_next_state = RTC_RC_JUDGE_s;
                                end
                                else if(wv_ser == `RC && wv_err_type != `QP_NORMAL) begin
                                    RTC_next_state = RTC_FLUSH_s;
                                end
                                else if((wv_ser == `UC || wv_ser == `UD) && wv_err_type == `QP_NORMAL) begin
                                    RTC_next_state = RTC_UCUD_SEG_s;
                                end
                                else if((wv_ser == `UC || wv_ser == `UD) && wv_err_type != `QP_NORMAL) begin
                                    RTC_next_state = RTC_FLUSH_s;
                                end
                                else begin
                                    RTC_next_state = RTC_IDLE_s;
                                end
                            end
                            else begin
                                RTC_next_state = RTC_RESP_CXT_s;
                            end
        RTC_FLUSH_s:        if(q_flush_finish) begin
                                if(qv_ser == `RC) begin
                                    RTC_next_state = RTC_RC_BAD_REQ_s;
                                end
                                else begin
                                    RTC_next_state = RTC_UCUD_CPL_s;
                                end
                            end  
                            else begin
                                RTC_next_state = RTC_FLUSH_s;
                            end
        RTC_RC_BAD_REQ_s:   if(!i_br_prog_full) begin
                                RTC_next_state = RTC_WB_CXT_s;
                            end 
                            else begin
                                RTC_next_state = RTC_RC_BAD_REQ_s;
                            end
        RTC_RC_JUDGE_s:     if(w_rc_msg_can_be_sent) begin  //Judge can be finished in one cycle
                                RTC_next_state = RTC_RC_SEG_s;
                            end  
                            //else begin
                            //    RTC_next_state = RTC_FETCH_CXT_s;
                            //end
                            else begin		//Judge does not need to use context 
								RTC_next_state = RTC_RC_JUDGE_s;
							end 
        RTC_RC_SEG_s:       if(q_first_pkt) begin
                                if(wv_opcode == `VERBS_RDMA_READ) begin
                                    if(w_read_allowed) begin
                                        RTC_next_state = RTC_RC_STE_s;   //Need to store SGL entries to scatter RDMA Read response
                                    end
                                    else begin
                                        RTC_next_state = RTC_RC_SEG_s;
                                    end
                                end
                                else if(wv_opcode == `VERBS_RDMA_WRITE || wv_opcode == `VERBS_RDMA_WRITE_WITH_IMM) begin
                                    if(w_write_allowed) begin
                                        RTC_next_state = RTC_RC_FWD_s;
                                    end
                                    else begin
                                        RTC_next_state = RTC_RC_SEG_s;
                                    end
                                end
                                else if(wv_opcode == `VERBS_FETCH_AND_ADD || wv_opcode == `VERBS_CMP_AND_SWAP) begin
                                    if(w_atomics_allowed) begin
                                        RTC_next_state = RTC_WB_CXT_s;
                                    end
                                    else begin
                                        RTC_next_state = RTC_RC_SEG_s;
                                    end
                                end
                                else if(wv_opcode == `VERBS_SEND || wv_opcode == `VERBS_SEND_WITH_IMM) begin
                                    if(wv_msg_size == 0) begin //Zero-length msg
                                        if(w_send_allowed) begin
                                            RTC_next_state = RTC_WB_CXT_s;
                                        end
                                        else begin
                                            RTC_next_state = RTC_RC_SEG_s;
                                        end
                                    end
                                    else begin
                                        if(w_send_allowed) begin
                                            RTC_next_state = RTC_RC_FWD_s;
                                        end
                                        else begin
                                            RTC_next_state = RTC_RC_SEG_s;
                                        end
                                    end
                                end
                                else begin
                                    RTC_next_state = RTC_RC_SEG_s;
                                end
                            end 
                            else begin
                                if(w_pkt_allowed) begin
                                    RTC_next_state = RTC_RC_FWD_s;
                                end
                                else begin
                                    RTC_next_state = RTC_RC_SEG_s;
                                end
                            end
                            //Only Send(Non-Zero) and Write will come into this stage
        RTC_RC_FWD_s:       if(q_last_pkt == 1 && qv_seg_left == 1) begin      //Last 32B(or less than 32B) of the Msg
                                if(!i_nd_to_rpg_prog_full && !i_nd_from_dp_empty) begin
                                    RTC_next_state = RTC_WB_CXT_s;
                                end
                                else begin
                                    RTC_next_state = RTC_RC_FWD_s;
                                end
                            end
                            else if(q_last_pkt != 1 && qv_seg_left == 1) begin //Meet the end of a MTU, continue segmentation
                                if(!i_nd_to_rpg_prog_full && !i_nd_from_dp_empty) begin
                                    RTC_next_state = RTC_WB_CXT_s;
                                end
                                else begin
                                    RTC_next_state = RTC_RC_FWD_s;
                                end
                            end
                            else begin
                                RTC_next_state = RTC_RC_FWD_s;
                            end
        RTC_RC_STE_s:       if(qv_entry_left == 1 && !i_entry_from_dp_empty) begin
                                RTC_next_state = RTC_WB_CXT_s;
                            end
                            else begin
                                RTC_next_state = RTC_RC_STE_s;
                            end
        RTC_UCUD_SEG_s:     if(q_first_pkt) begin       //First pkt of the msg, should forward related metadata to generate extended header
                                if (wv_opcode == `VERBS_RDMA_WRITE || wv_opcode == `VERBS_RDMA_WRITE_WITH_IMM) begin
                                    if(w_write_allowed) begin
                                        RTC_next_state = RTC_UCUD_FWD_s;
                                    end
                                    else begin
                                        RTC_next_state = RTC_UCUD_SEG_s;
                                    end
                                end
                                else if (wv_opcode == `VERBS_SEND || wv_opcode == `VERBS_SEND_WITH_IMM) begin
                                    if(w_send_allowed) begin
                                        if(wv_msg_size == 0) begin      //Zero-length send, only one packet
                                            RTC_next_state = RTC_WB_CXT_s;
                                        end
                                        else begin
                                            RTC_next_state = RTC_UCUD_FWD_s;
                                        end
                                    end
                                    else begin
                                        RTC_next_state = RTC_UCUD_SEG_s;
                                    end
                                end
                                else begin
                                    RTC_next_state = RTC_UCUD_SEG_s;
                                end
                            end 
                            else if(!i_header_to_rpg_prog_full) begin   //Each pkt needs a header metadata to generate BTH
                                RTC_next_state = RTC_UCUD_FWD_s;             
                            end         
                            else begin
                                RTC_next_state = RTC_UCUD_SEG_s;
                            end
        RTC_UCUD_FWD_s:     if(q_last_pkt == 1 && qv_seg_left == 1) begin
                                if(!i_nd_to_rpg_prog_full && !i_nd_from_dp_empty) begin
                                    RTC_next_state = RTC_WB_CXT_s;
                                end
                                else begin
                                    RTC_next_state = RTC_UCUD_FWD_s;
                                end
                            end
                            else if (q_last_pkt != 1 && qv_seg_left == 1) begin
                                if(!i_nd_to_rpg_prog_full && !i_nd_from_dp_empty) begin
                                    RTC_next_state = RTC_WB_CXT_s;
                                end
                                else begin
                                    RTC_next_state = RTC_UCUD_FWD_s; 
                                end
                            end
                            else begin
                                RTC_next_state = RTC_UCUD_FWD_s;
                            end
        RTC_UCUD_CPL_s:     if(!i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && i_rtc_resp_valid) begin
                                RTC_next_state = RTC_IDLE_s;    
                            end
                            else begin
                                RTC_next_state = RTC_UCUD_CPL_s;
                            end
        RTC_WB_CXT_s:       if(!i_cxtmgt_cmd_prog_full && !i_cxtmgt_cxt_prog_full) begin
                                if(!q_last_pkt && qv_ser == `RC) begin      //Message sending not finished, continue segmentation 
									if(q_start_timer == 1) begin 
	                                    RTC_next_state = RTC_START_TIMER_s;
									end
									else begin 
										RTC_next_state = RTC_RC_SEG_s;
									end 
								end
								else if(q_last_pkt && qv_ser == `RC) begin
									if(q_start_timer == 1) begin
										RTC_next_state = RTC_START_TIMER_s;
									end 
									else begin
										RTC_next_state = RTC_IDLE_s;
									end 
								end  
								else if(!q_last_pkt && qv_ser != `RC) begin
									RTC_next_state = RTC_UCUD_SEG_s;
								end 
								else if(q_last_pkt && qv_ser != `RC) begin
									RTC_next_state = RTC_UCUD_CPL_s;
								end 
                                else begin
                                    RTC_next_state = RTC_IDLE_s;
                                end
                            end
                            else begin
                                RTC_next_state = RTC_WB_CXT_s;
                            end
		RTC_START_TIMER_s:	if(!i_te_prog_full) begin 
								if(!q_last_pkt && qv_ser == `RC) begin 
									RTC_next_state = RTC_RC_SEG_s;
								end 
								else begin 
									RTC_next_state = RTC_IDLE_s;
								end 
							end 	
							else begin 
								RTC_next_state = RTC_START_TIMER_s;
							end 
        default:            RTC_next_state = RTC_IDLE_s;
    endcase
end

/*----------------------------------------  Part 3: Output Registers Decode -------------------------------------------------------------*/
always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_swpb_content_table_init_counter <= 'd0;
	end 
	else if(RTC_cur_state == RTC_INIT_s && qv_swpb_content_table_init_counter < `SWPB_CONTENT_FREE_NUM - 1) begin
		qv_swpb_content_table_init_counter <= qv_swpb_content_table_init_counter + 'd1;
	end 
	else begin
		qv_swpb_content_table_init_counter <= qv_swpb_content_table_init_counter;
	end 
end 

always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_rpb_content_table_init_counter <= 'd0;
	end 
	else if(RTC_cur_state == RTC_INIT_s && qv_rpb_content_table_init_counter < `RPB_CONTENT_FREE_NUM - 1) begin
		qv_rpb_content_table_init_counter <= qv_rpb_content_table_init_counter + 'd1;
	end 
	else begin
		qv_rpb_content_table_init_counter <= qv_rpb_content_table_init_counter;
	end 
end 

always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_swpb_next_table_init_counter <= 'd0;
	end 
	else if(RTC_cur_state == RTC_INIT_s && qv_swpb_next_table_init_counter < `SWPB_CONTENT_FREE_NUM - 1) begin
		qv_swpb_next_table_init_counter <= qv_swpb_next_table_init_counter + 'd1;
	end 
	else begin
		qv_swpb_next_table_init_counter <= qv_swpb_next_table_init_counter;
	end 
end 

always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_rpb_next_table_init_counter <= 'd0;
	end 
	else if(RTC_cur_state == RTC_INIT_s && qv_rpb_next_table_init_counter < `RPB_CONTENT_FREE_NUM - 1) begin
		qv_rpb_next_table_init_counter <= qv_rpb_next_table_init_counter + 'd1;
	end 
	else begin
		qv_rpb_next_table_init_counter <= qv_rpb_next_table_init_counter;
	end 
end

always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_reb_next_table_init_counter <= 'd0;
	end 
	else if(RTC_cur_state == RTC_INIT_s && qv_reb_next_table_init_counter < `REB_CONTENT_FREE_NUM - 1) begin
		qv_reb_next_table_init_counter <= qv_reb_next_table_init_counter + 'd1;
	end 
	else begin
		qv_reb_next_table_init_counter <= qv_reb_next_table_init_counter;
	end 
end


//-- qv_err_point -- //Indicates errors happens at WQEParser or RTC
always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_err_point <= 'd0;
	end 
	else if(RTC_cur_state == RTC_RESP_CXT_s) begin
		if(wv_err_type != `QP_NORMAL) begin
			qv_err_point <= 'd1;		//Error happens in WQEParser
		end
		else if(wv_qp_state == `QP_SQE || wv_qp_state == `QP_SQD || wv_qp_state == `QP_ERR) begin
			qv_err_point <= 'd2;
		end 
		else begin
			qv_err_point <= 'd0;
		end 
	end 
	else begin
		qv_err_point <= qv_err_point;
	end 
end 

always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_left_payload_counter <= 'd0;
	end 
	else if(RTC_cur_state == RTC_RESP_CXT_s && !i_cxtmgt_resp_empty && !i_cxtmgt_cxt_empty) begin
		qv_left_payload_counter <= (wv_msg_size != 0) ? ((wv_msg_size[4:0] != 0) ? wv_msg_size[31:5] + 1 : wv_msg_size[31:5]) : 'd1;
	end 
	else if(o_nd_from_dp_rd_en) begin
		qv_left_payload_counter <= qv_left_payload_counter - 'd1;
	end 
	else begin
		qv_left_payload_counter <= qv_left_payload_counter;
	end 
end 


//Metadata for different Queues
assign wv_rpb_head = iv_rpb_list_head_douta;
assign wv_rpb_tail = iv_rpb_list_tail_douta;
assign w_rpb_empty = iv_rpb_list_empty_douta;

assign wv_reb_head = iv_reb_list_head_douta;
assign wv_reb_tail = iv_reb_list_tail_douta;
assign w_reb_empty = iv_reb_list_empty_douta;

assign wv_swpb_head = iv_swpb_list_head_douta;
assign wv_swpb_tail = iv_swpb_list_tail_douta;
assign w_swpb_empty = iv_swpb_list_empty_douta;


always @(*) begin
    case(iv_md_from_dp_data[39:24]) 
        16'd256:		qv_PMTU = `MTU_256;
        16'd512:		qv_PMTU = `MTU_512;
        16'd1024:		qv_PMTU = `MTU_1024;
        16'd2048:		qv_PMTU = `MTU_2048;
        16'd4096:		qv_PMTU = `MTU_4096;
        default:    	qv_PMTU = 'd0;
    endcase
end

always @(*) begin
	if(rst) begin
		qv_PMTU_fwd = 'd0;
	end 
	else begin 
		case(iv_md_from_dp_data[39:24])
        	16'd256:		qv_PMTU_fwd = 6'd1;
        	16'd512:		qv_PMTU_fwd = 6'd2;
        	16'd1024:		qv_PMTU_fwd = 6'd3;
        	16'd2048:		qv_PMTU_fwd = 6'd4;
        	16'd4096:		qv_PMTU_fwd = 6'd5;
			default: 		qv_PMTU_fwd = 'd0;	
		endcase
	end 
end 


//Metadata for Request
assign wv_opcode = iv_md_from_dp_data[4:0];
assign wv_ser = iv_md_from_dp_data[7:5];
assign w_fence = iv_md_from_dp_data[8];
assign wv_err_type = iv_md_from_dp_data[15:12];
assign wv_legal_entry = iv_md_from_dp_data[23:16];
assign wv_src_qpn = iv_md_from_dp_data[63:40];
assign wv_dst_qpn = iv_md_from_dp_data[87:64];
assign wv_msg_size = iv_md_from_dp_data[127:96];
assign wv_qkey = iv_md_from_dp_data[159:128];
// assign wv_scq_pd = iv_md_from_dp_data[191:160];

//assign wv_PKey = iv_md_from_dp_data[223:192];
//Trick, we use wv_PKey to indicate srcQPN, this is a patch
assign wv_PKey = wv_src_qpn[15:0];

assign wv_imm = iv_md_from_dp_data[255:224];
assign wv_cur_wqe_offset = iv_md_from_dp_data[287:256];

assign wv_qp_state = iv_cxtmgt_cxt_data[2:0];
assign wv_scq_pd = iv_cxtmgt_cxt_data[127:96];
assign wv_scq_lkey = iv_cxtmgt_cxt_data[63:32];
assign wv_scq_length = iv_cxtmgt_cxt_data[95:64];

wire 	[15:0] 	wv_rlid;
assign wv_rlid = iv_cxtmgt_cxt_data[175:160];

//-- w_msg_allowed --  For any RC msg, this indicates whether the following requirements are satisfied
//                      1.No outstanding RDMA Read/Atomics if fence is set
//                      2.Enough space to store Msg Metadata
//                      3.Enough RQ credits;
//                      4.Enough space to buffer the SGL entry
//                      Here we judge these constraints according to different operations
//TODO : Next version should add Atomics judgement
assign w_rc_msg_can_be_sent =   ((w_fence && w_rpb_empty) || !w_fence) && 
                                (wv_opcode == `VERBS_SEND || wv_opcode == `VERBS_SEND_WITH_IMM) ||
                                (wv_opcode == `VERBS_RDMA_WRITE || wv_opcode == `VERBS_RDMA_WRITE_WITH_IMM) ||
                                (wv_opcode == `VERBS_RDMA_READ && !i_rpb_free_empty && (wv_legal_entry <= iv_reb_free_data_count));

////-- w_flush_finish -- 
//assign w_flush_finish = (wv_opcode == `VERBS_RDMA_READ && qv_entry_left == 1 && o_entry_from_dp_rd_en && o_md_from_dp_rd_en) || 
//                        ((wv_opcode == `VERBS_RDMA_WRITE || wv_opcode == `VERBS_RDMA_WRITE_WITH_IMM) && q_last_pkt == 1 && qv_seg_left == 1 && o_nd_from_dp_rd_en && o_md_from_dp_rd_en && o_raddr_from_dp_rd_en) || 
//                        ((wv_opcode == `VERBS_SEND || wv_opcode == `VERBS_SEND_WITH_IMM) && o_md_from_dp_rd_en && ((wv_msg_size > 0 && o_nd_from_dp_rd_en) || wv_msg_size == 0));  
//-- q_flush_finish --
always @(*) begin
	if(rst) begin
		q_flush_finish = 'd0;
	end 
	else if(qv_err_point == 'd1) begin //Error happens in WQEParser
		q_flush_finish = 'd1;
	end 
	else if(wv_opcode == `VERBS_RDMA_READ && qv_entry_left == 1 && !i_entry_from_dp_empty && !i_raddr_from_dp_empty) begin
		q_flush_finish = 'd1;
	end 
	else if(wv_opcode == `VERBS_RDMA_WRITE || wv_opcode == `VERBS_RDMA_WRITE_WITH_IMM) begin 
		if(!i_raddr_from_dp_empty) begin
			if(wv_msg_size > 0 && qv_left_payload_counter == 1 && !i_nd_from_dp_empty) begin
				q_flush_finish = 'd1;
			end  
			else if(wv_msg_size == 0) begin
				q_flush_finish = 'd1;
			end 
			else begin
				q_flush_finish = 'd0;
			end 
		end
		else begin
			q_flush_finish = 'd0;
		end  
	end 
	else if(wv_opcode == `VERBS_SEND || wv_opcode == `VERBS_SEND_WITH_IMM) begin
		if(wv_msg_size > 0 && qv_left_payload_counter == 1 && !i_nd_from_dp_empty) begin
			q_flush_finish = 'd1;
		end
		else if(wv_msg_size == 0) begin
			q_flush_finish = 'd1;
		end 
		else begin
			q_flush_finish = 'd0;
		end 
	end 
	else begin
		q_flush_finish = 'd0;	
	end 
end 

//-- w_write_allowed --
assign w_write_allowed = (!i_raddr_from_dp_empty && !i_header_to_rpg_prog_full && ((qv_PMTU + 32) <= iv_swpb_free_data_count * 32)); 

//-- w_read_allowed -- 
assign w_read_allowed = (!i_rpb_free_empty && !i_raddr_from_dp_empty && !i_header_to_rpg_prog_full && (wv_legal_entry <= iv_reb_free_data_count));

//-- w_atomics_allowed --
assign w_atomics_allowed = `UNCERTAIN;  //TODO : Need to complete atomics ops

//-- w_send_allowed --
assign w_send_allowed = (!i_header_to_rpg_prog_full) && ((wv_msg_size == 0) || ((wv_msg_size > 0) && ((qv_PMTU + 32) <= iv_swpb_free_data_count * 32)));

//-- w_pkt_allowed -- Notice this flag is only applicable to Send(Non-Zero Length) and RDMA Write, since it is used when judge second and following pkt
assign w_pkt_allowed = (!i_header_to_rpg_prog_full && ((qv_PMTU + 32) <= iv_swpb_free_data_count * 32));

//-- q_first_pkt -- Indicates first packet of a message, different opcodes lead to different operations
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_first_pkt <= 1'b0;        
    end
    else if (RTC_cur_state == RTC_RESP_CXT_s && RTC_next_state == RTC_UCUD_SEG_s) begin
        q_first_pkt <= 1'b1;
    end
    else if (RTC_cur_state == RTC_RC_JUDGE_s && RTC_next_state == RTC_RC_SEG_s) begin
        q_first_pkt <= 1'b1;
    end
    else if (RTC_cur_state == RTC_UCUD_SEG_s && RTC_next_state != RTC_UCUD_SEG_s) begin
        q_first_pkt <= 1'b0;
    end
    else if (RTC_cur_state == RTC_RC_SEG_s && RTC_next_state != RTC_RC_SEG_s) begin
        q_first_pkt <= 1'b0;
    end
    else begin
        q_first_pkt <= q_first_pkt;
    end
end

//-- q_last_pkt -- Indicates last pkt of a message
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_last_pkt <= 1'b0;        
    end
    else if (RTC_cur_state == RTC_IDLE_s) begin
        q_last_pkt <= 1'b0;
    end
    else if (RTC_cur_state == RTC_FETCH_CXT_s) begin
        q_last_pkt <= 1'b0;
    end
    else if ((RTC_cur_state == RTC_RC_SEG_s) || (RTC_cur_state == RTC_UCUD_SEG_s)) begin
		if(wv_opcode == `VERBS_RDMA_READ) begin 
			q_last_pkt <= 1'b1;
		end 
		else if(qv_msg_data_left <= qv_PMTU) begin
            q_last_pkt <= 1'b1;
        end
        else begin
            q_last_pkt <= 1'b0;
        end
    end
	else if(RTC_cur_state == RTC_FLUSH_s) begin
 		q_last_pkt <= 'd1;
	end
    else begin
        q_last_pkt <= q_last_pkt;
    end
end

//-- qv_msg_data_left -- //At the end of a packet, we decrease this counter
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_msg_data_left <= 'd0;
    end
    else if (RTC_cur_state == RTC_IDLE_s && RTC_next_state != RTC_IDLE_s) begin
        qv_msg_data_left <= wv_msg_size;
    end
    else if (RTC_cur_state == RTC_UCUD_FWD_s && RTC_next_state == RTC_WB_CXT_s) begin
        qv_msg_data_left <= qv_msg_data_left - qv_PMTU;
    end
    // else if (RTC_cur_state == RTC_RC_FWD_s && RTC_next_state == RTC_RC_SEG_s) begin     //Error, we have link RC_FWD's next state to WB_CXT
    else if (RTC_cur_state == RTC_RC_FWD_s && RTC_next_state == RTC_WB_CXT_s) begin
        qv_msg_data_left <= qv_msg_data_left - qv_PMTU;
    end
    else begin
        qv_msg_data_left <= qv_msg_data_left;
    end
end

// //-- qv_pkt_left -- Indicates how many pkts are still un-processed in a msg
// //                  For RDMA Read, Atomics, Zero-length Send, this variable is always 1
// always @(posedge clk or posedge rst) begin
//     if (rst) begin
//         qv_pkt_left <= 'd0;
//     end
//     else if (RTC_cur_state == RTC_IDLE_s && RTC_next_state != RTC_IDLE_s) begin
//         if(wv_opcode == `VERBS_SEND || wv_opcode == `VERBS_SEND_WITH_IMM || wv_opcode == `VERBS_RDMA_WRITE_WITH_IMM || wv_opcode == `VERBS_RDMA_WRITE) begin
//             case(qv_PMTU)
//                 `MTU_256:   qv_pkt_left <= (wv_msg_size[7:0]) ? ((wv_msg_size >> 8) + 1) : (wv_msg_size >> 8);
//                 `MTU_512:   qv_pkt_left <= (wv_msg_size[8:0]) ? ((wv_msg_size >> 9) + 1) : (wv_msg_size >> 9);
//                 `MTU_1024:  qv_pkt_left <= (wv_msg_size[9:0]) ? ((wv_msg_size >> 10) + 1) : (wv_msg_size >> 10);
//                 `MTU_2048:  qv_pkt_left <= (wv_msg_size[10:0]) ? ((wv_msg_size >> 11) + 1) : (wv_msg_size >> 11);
//                 `MTU_4096:  qv_pkt_left <= (wv_msg_size[11:0]) ? ((wv_msg_size >> 12) + 1) : (wv_msg_size >> 12);
//                 default:    qv_pkt_left <= 'd0;
//             endcase
//         end
//         else begin
//             qv_pkt_left <= 'd1;
//         end
//     end
//     else if (RTC_cur_state == RTC_UCUD_FWD_s && qv_seg_left == 1 && o_nd_from_dp_rd_en && !i_nd_to_rpg_prog_full) begin
//         qv_pkt_left <= qv_pkt_left - 1;
//     end
//     else if (RTC_cur_state == RTC_RC_FWD_s && qv_seg_left == 1 && o_nd_from_dp_rd_en && !i_nd_to_rpg_prog_full) begin
//         qv_pkt_left <= qv_pkt_left - 1;
//     end
//     else begin
//         qv_pkt_left <= qv_pkt_left;
//     end
// end

//-- qv_seg_left -- Indicates how many payload are unprocessed in a packet, each 32B is treated as a seg
//-- qv_seg_total -- Indicates how many payload in a packet
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_seg_left <= 'd0;
        qv_seg_total <= 'd0;
    end
    else if (RTC_cur_state == RTC_UCUD_SEG_s || RTC_cur_state == RTC_RC_SEG_s) begin
        if(qv_msg_data_left < qv_PMTU) begin
            qv_seg_left <= ((qv_msg_data_left[4:0] != 5'd0) ? ((qv_msg_data_left >> 5) + 1) : qv_msg_data_left >> 5); 
            qv_seg_total <= ((qv_msg_data_left[4:0] != 5'd0) ? ((qv_msg_data_left >> 5) + 1) : qv_msg_data_left >> 5);
        end
        else begin
            qv_seg_left <= (qv_PMTU >> 5);
            qv_seg_total <= (qv_PMTU >> 5);
        end
    end
    else if ((RTC_cur_state == RTC_UCUD_FWD_s || RTC_cur_state == RTC_RC_FWD_s) && o_nd_from_dp_rd_en && !i_nd_to_rpg_prog_full) begin
        qv_seg_left <= qv_seg_left - 1;
        qv_seg_total <= qv_seg_total;
    end
    else begin
        qv_seg_left <= qv_seg_left;
        qv_seg_total <= qv_seg_total;
    end
end

//-- qv_entry_left --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_entry_left <= 'd0;        
    end
    else if (RTC_cur_state == RTC_IDLE_s && RTC_next_state != RTC_IDLE_s) begin
        qv_entry_left <= wv_legal_entry;
    end
    else if (RTC_cur_state == RTC_RC_STE_s && o_entry_from_dp_rd_en) begin
        qv_entry_left <= qv_entry_left - 1;
    end
	else if(RTC_cur_state == RTC_FLUSH_s && o_entry_from_dp_rd_en) begin	
		qv_entry_left <= qv_entry_left - 1;
	end 
    else begin
        qv_entry_left <= qv_entry_left;
    end
end

//-- qv_ser --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_ser <= 'd0;        
    end
    else if (RTC_cur_state == RTC_IDLE_s && RTC_next_state != RTC_IDLE_s) begin
        qv_ser <= wv_ser;
    end
    else begin
        qv_ser <= qv_ser;
    end
end

//-- qv_next_psn -- Indicates PSN of next packet, fetch and store this value at the start and end of procesing an entire message
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_next_psn <= 'd0;        
    end
    else if (RTC_cur_state == RTC_RESP_CXT_s) begin
        qv_next_psn <= iv_cxtmgt_cxt_data[31:8];   //PSN in context
    end
    else if (RTC_cur_state == RTC_RC_SEG_s && RTC_next_state != RTC_RC_SEG_s && wv_opcode != `VERBS_RDMA_READ) begin
        qv_next_psn <= qv_next_psn + 1;
    end
    //RDMA Read should increase the Next PSN according to the Message Length
    else if (RTC_cur_state == RTC_RC_SEG_s && RTC_next_state != RTC_RC_SEG_s && wv_opcode == `VERBS_RDMA_READ) begin
        case(qv_PMTU)
            `MTU_256:   qv_next_psn <= qv_next_psn + ((wv_msg_size[7:0] != 8'd0) ? ((wv_msg_size >> 8) + 1) : (wv_msg_size >> 8));
            `MTU_512:   qv_next_psn <= qv_next_psn + ((wv_msg_size[8:0] != 9'd0) ? ((wv_msg_size >> 9) + 1) : (wv_msg_size >> 9));
            `MTU_1024:  qv_next_psn <= qv_next_psn + ((wv_msg_size[9:0] != 10'd0) ? ((wv_msg_size >> 10) + 1) : (wv_msg_size >> 10));
            `MTU_2048:  qv_next_psn <= qv_next_psn + ((wv_msg_size[10:0] != 11'd0) ? ((wv_msg_size >> 11) + 1) : (wv_msg_size >> 11));
            `MTU_4096:  qv_next_psn <= qv_next_psn + ((wv_msg_size[11:0] != 12'd0) ? ((wv_msg_size >> 12) + 1) : (wv_msg_size >> 12));
            default:    qv_next_psn <= qv_next_psn;
        endcase
    end
	else if (RTC_cur_state == RTC_UCUD_SEG_s && RTC_next_state != RTC_UCUD_SEG_s) begin
		qv_next_psn <= qv_next_psn + 1;
	end 
    else begin
        qv_next_psn <= qv_next_psn;
    end
end

//-- qv_pkt_header --
always @(*) begin
    if(rst) begin
        qv_pkt_header = 'd0;
        qv_header_len = 'd0;
    end
    else if(wv_opcode == `VERBS_RDMA_READ) begin
        qv_pkt_header = {wv_RETH, 1'b1, 7'b0, qv_next_psn, 8'b00, wv_dst_qpn, qv_ser, `RDMA_READ_REQUEST, 8'b0, wv_PKey};
        qv_header_len = 28;
    end
    else if(wv_opcode == `VERBS_SEND) begin
        if(wv_msg_size == 0) begin
            qv_pkt_header = qv_ser != `UD ? {1'b1, 7'b0, qv_next_psn, 8'b00, wv_dst_qpn, qv_ser, `SEND_ONLY, 8'b0, wv_PKey}
            						: {wv_DETH, 1'b1, 7'b0, qv_next_psn, 8'b00, wv_dst_qpn, qv_ser, `SEND_ONLY, 8'b0, wv_PKey};
            qv_header_len = qv_ser != `UD ? 12 : 28;
        end
        else if(wv_msg_size <= qv_PMTU) begin
            qv_pkt_header = qv_ser != `UD ? {1'b1, wv_msg_size[12:6], qv_next_psn, 2'b00, wv_msg_size[5:0], wv_dst_qpn, qv_ser, `SEND_ONLY, 8'b0, wv_PKey} 
            						: {wv_DETH, 1'b1, wv_msg_size[12:6], qv_next_psn, 2'b00, wv_msg_size[5:0], wv_dst_qpn, qv_ser, `SEND_ONLY, 8'b0, wv_PKey};
            qv_header_len = qv_ser != `UD ? 12 : 28;
        end
        else begin	//UD will not appear in this branch
            if(q_first_pkt) begin
                qv_pkt_header = {1'b1, qv_PMTU[12:6], qv_next_psn, 2'b00, qv_PMTU[5:0], wv_dst_qpn, qv_ser, `SEND_FIRST, 8'b0, wv_PKey};
                qv_header_len = 12;
            end
            else if(qv_msg_data_left > qv_PMTU) begin
                qv_pkt_header = {1'b1, qv_PMTU[12:6], qv_next_psn, 2'b00, qv_PMTU[5:0], wv_dst_qpn, qv_ser, `SEND_MIDDLE, 8'b0, wv_PKey};
                qv_header_len = 12;
            end
            else begin
                qv_pkt_header = {1'b1, qv_msg_data_left[12:6], qv_next_psn, 2'b00, qv_msg_data_left[5:0], wv_dst_qpn, qv_ser, `SEND_LAST, 8'b0, wv_PKey};
                qv_header_len = 12;
            end
        end
    end
    else if(wv_opcode == `VERBS_SEND_WITH_IMM) begin
        if(wv_msg_size == 0) begin
            qv_pkt_header = qv_ser != `UD ? {wv_imm, 1'b1, 7'b0, qv_next_psn, 8'b00, wv_dst_qpn, qv_ser, `SEND_ONLY_WITH_IMM, 8'b0, wv_PKey}
           					: {wv_DETH, wv_imm, 1'b1, 7'b0, qv_next_psn, 8'b00, wv_dst_qpn, qv_ser, `SEND_ONLY_WITH_IMM, 8'b0, wv_PKey};
            qv_header_len = qv_ser != `UD ? 16 : 32;
        end
        else if(wv_msg_size <= qv_PMTU) begin
            qv_pkt_header = qv_ser != `UD ? {wv_imm, wv_msg_size[12:6], qv_next_psn, 2'b00, wv_msg_size[5:0], wv_dst_qpn, qv_ser, `SEND_ONLY_WITH_IMM, 8'b0, wv_PKey}
            				: {wv_DETH, wv_imm, wv_msg_size[12:6], qv_next_psn, 2'b00, wv_msg_size[5:0], wv_dst_qpn, qv_ser, `SEND_ONLY_WITH_IMM, 8'b0, wv_PKey};
            qv_header_len = qv_ser != `UD ? 16 : 32;
        end
        else begin
            if(q_first_pkt) begin
                qv_pkt_header = {1'b1, qv_PMTU[12:6], qv_next_psn, 2'b00, qv_PMTU[5:0], wv_dst_qpn, qv_ser, `SEND_FIRST, 8'b0, wv_PKey};
                qv_header_len = 12;
            end
            else if(qv_msg_data_left > qv_PMTU) begin
                qv_pkt_header = {1'b1, qv_PMTU[12:6], qv_next_psn, 2'b00, qv_PMTU[5:0], wv_dst_qpn, qv_ser, `SEND_MIDDLE, 8'b0, wv_PKey};
                qv_header_len = 12;
            end
            else begin
                qv_pkt_header = {wv_imm, 1'b1, qv_msg_data_left[12:6], qv_next_psn, 2'b00, qv_msg_data_left[5:0], wv_dst_qpn, qv_ser, `SEND_LAST_WITH_IMM, 8'b0, wv_PKey};
                qv_header_len = 16;
            end
        end        
    end
    else if(wv_opcode == `VERBS_RDMA_WRITE) begin
        if(wv_msg_size <= qv_PMTU) begin
            qv_pkt_header = {wv_RETH, 1'b1, wv_msg_size[12:6], qv_next_psn, 2'b00, wv_msg_size[5:0], wv_dst_qpn, qv_ser, `RDMA_WRITE_ONLY, 8'b0, wv_PKey};
            qv_header_len = 28;
        end
        else begin
            if(q_first_pkt) begin
                qv_pkt_header = {wv_RETH, 1'b1, qv_PMTU[12:6], qv_next_psn, 2'b00, qv_PMTU[5:0], wv_dst_qpn, qv_ser, `RDMA_WRITE_FIRST, 8'b0, wv_PKey};
                qv_header_len = 28;
            end
            else if(qv_msg_data_left > qv_PMTU) begin
                qv_pkt_header = {1'b1, qv_PMTU[12:6], qv_next_psn, 2'b00, qv_PMTU[5:0], wv_dst_qpn, qv_ser, `RDMA_WRITE_MIDDLE, 8'b0, wv_PKey};
                qv_header_len = 12;
            end
            else begin
                qv_pkt_header = {1'b1, qv_msg_data_left[12:6], qv_next_psn, 2'b00, qv_msg_data_left[5:0], wv_dst_qpn, qv_ser, `RDMA_WRITE_LAST, 8'b0, wv_PKey};
                qv_header_len = 12;
            end
        end
    end
    else if(wv_opcode == `VERBS_RDMA_WRITE_WITH_IMM) begin
        if(wv_msg_size <= qv_PMTU) begin
            qv_pkt_header = {wv_imm, wv_RETH, 1'b1, wv_msg_size[12:6], qv_next_psn, 2'b00, wv_msg_size[5:0], wv_dst_qpn, qv_ser, `RDMA_WRITE_ONLY_WITH_IMM, 8'b0, wv_PKey};
            qv_header_len = 32;
        end
        else begin
            if(q_first_pkt) begin
                qv_pkt_header = {wv_RETH, 1'b1, qv_PMTU[12:6], qv_next_psn, 2'b00, qv_PMTU[5:0], wv_dst_qpn, qv_ser, `RDMA_WRITE_FIRST, 8'b0, wv_PKey};
                qv_header_len = 28;
            end
            else if(qv_msg_data_left > qv_PMTU) begin
                qv_pkt_header = {1'b1, qv_PMTU[12:6], qv_next_psn, 2'b00, qv_PMTU[5:0], wv_dst_qpn, qv_ser, `RDMA_WRITE_MIDDLE, 8'b0, wv_PKey};
                qv_header_len = 12;
            end
            else begin
                qv_pkt_header = {wv_imm, 1'b1, qv_msg_data_left[12:6], qv_next_psn, 2'b00, qv_msg_data_left[5:0], wv_dst_qpn, qv_ser, `RDMA_WRITE_LAST_WITH_IMM, 8'b0, wv_PKey};
                qv_header_len = 16;
            end
        end
    end
    //TODO : Atomics header is not considered
    else begin
        qv_pkt_header = 'd0;
        qv_header_len = 'd0;
    end
end 

/*
Time sequence of needed metadata

    State:              IDLE        FETCH       RESP        JUDGE
                        _____       _____       _____       _____
    clk:          _____|     |_____|     |_____|     |_____|     |_____

                  _____________________________ _______________________
  Cxt Resp(Wire): _____________________________X____CxtInfo____________
     
                  _____ _______________________________________________
 srcQPN(wire):    _____X____qpn________________________________________

                  _________________ ___________________________________
 table addr(reg): _________________X____qpn____________________________

                  _____________________________ _______________________
 table dout:      _____________________________X____<Head,Tail>________

 Different tables obey this timing sequence. Before JUDGE state, we can obtain all needed metadata.
*/

/***************************************** RPB Management **********************************************/
//Read Packet Buffer

//-- q_rpb_list_head_wea --
//-- qv_rpb_list_head_addra --
//-- qv_rpb_list_head_dina --
always @(*) begin
    if (rst) begin
        q_rpb_list_head_wea = 1'b0;
        qv_rpb_list_head_addra = 'd0;
        qv_rpb_list_head_dina = 'd0;     
    end
    /*Spyglass Modify Begin*/
    // else if (RTC_cur_state == RTC_IDLE_s && RTC_next_state != RTC_IDLE_s) begin
    else if (RTC_cur_state == RTC_IDLE_s && !i_md_from_dp_empty) begin
    /*Spyglass Modify End*/
        q_rpb_list_head_wea = 1'b0;
        qv_rpb_list_head_addra = wv_src_qpn;
        qv_rpb_list_head_dina = 'd0;
    end
    else if (RTC_cur_state == RTC_RC_SEG_s && wv_opcode == `VERBS_RDMA_READ && w_read_allowed) begin
        if(w_rpb_empty) begin //Need to update both head and tail
            q_rpb_list_head_wea = 1'b1;
            qv_rpb_list_head_addra = wv_src_qpn;
            qv_rpb_list_head_dina = iv_rpb_free_data;  //Points to newly inserted element 
        end
        else begin  //Table not empty, do not update head pointer
            q_rpb_list_head_wea = 1'b0;
            qv_rpb_list_head_addra = qv_rpb_list_head_addra_TempReg;
            qv_rpb_list_head_dina = qv_rpb_list_head_dina_TempReg;
        end
    end
    else begin
        q_rpb_list_head_wea = 1'b0;
        qv_rpb_list_head_addra = qv_rpb_list_head_addra_TempReg;
        qv_rpb_list_head_dina = qv_rpb_list_head_dina_TempReg;
    end
end

//-- q_rpb_list_tail_wea --
//-- qv_rpb_list_tail_addra --
//-- qv_rpb_list_tail_dina --
always @(*) begin
    if (rst) begin
        q_rpb_list_tail_wea = 1'b0;
        qv_rpb_list_tail_addra = 'd0;
        qv_rpb_list_tail_dina = 'd0;
    end
    /*Spyglass Modify Begin*/
    // else if (RTC_cur_state == RTC_IDLE_s && RTC_next_state != RTC_IDLE_s) begin
    else if (RTC_cur_state == RTC_IDLE_s && !i_md_from_dp_empty) begin
    /*Spyglass Modify End*/
        q_rpb_list_tail_wea = 1'b0;
        qv_rpb_list_tail_addra = wv_src_qpn;
        qv_rpb_list_tail_dina = 'd0;
    end
    else if (RTC_cur_state == RTC_RC_SEG_s && wv_opcode == `VERBS_RDMA_READ && w_read_allowed) begin
        q_rpb_list_tail_wea = 1'b1;
        qv_rpb_list_tail_addra = wv_src_qpn;
        qv_rpb_list_tail_dina = iv_rpb_free_data;  //Points to new entry        
    end
    else begin
        q_rpb_list_tail_wea = 1'b0;
        qv_rpb_list_tail_addra = qv_rpb_list_tail_addra_TempReg;
        qv_rpb_list_tail_dina = qv_rpb_list_tail_dina_TempReg;
    end
end

//-- q_rpb_list_empty_wea --
//-- qv_rpb_list_empty_addra --
//-- qv_rpb_list_empty_dina --
always @(*) begin
    if (rst) begin
        q_rpb_list_empty_wea = 1'b0;
        qv_rpb_list_empty_addra = 'd0;
        qv_rpb_list_empty_dina = 'd0;        
    end
    /*Spyglass Modify Begin*/
    // else if (RTC_cur_state == RTC_IDLE_s && RTC_next_state != RTC_IDLE_s) begin
    else if (RTC_cur_state == RTC_IDLE_s && !i_md_from_dp_empty) begin
    /*Spyglass Modify End*/
        q_rpb_list_empty_wea = 1'b0;
        qv_rpb_list_empty_addra = wv_src_qpn;
        qv_rpb_list_empty_dina = 'd0;        
    end
    else if (RTC_cur_state == RTC_RC_SEG_s && wv_opcode == `VERBS_RDMA_READ && w_read_allowed) begin
        q_rpb_list_empty_wea = 1'b1;
        qv_rpb_list_empty_addra = wv_src_qpn;
        qv_rpb_list_empty_dina = 1'b0;            
    end
    else begin
        q_rpb_list_empty_wea = 1'b0;
        qv_rpb_list_empty_addra = qv_rpb_list_empty_addra_TempReg;
        qv_rpb_list_empty_dina = qv_rpb_list_empty_dina_TempReg;        
    end
end

//-- q_rpb_content_wea --
//-- qv_rpb_content_addra --
//-- qv_rpb_content_dina --
always @(*) begin
    if (rst) begin
        q_rpb_content_wea = 1'b0;
        qv_rpb_content_addra = 'd0;
        qv_rpb_content_dina = 'd0;
    end
	else if (RTC_cur_state == RTC_INIT_s) begin
        q_rpb_content_wea = 1'b1;
        qv_rpb_content_addra = qv_rpb_content_table_init_counter;
        qv_rpb_content_dina = 'd0;      
	end
    else if (RTC_cur_state == RTC_RC_SEG_s && wv_opcode == `VERBS_RDMA_READ && w_read_allowed) begin
        q_rpb_content_wea = 1'b1;
        qv_rpb_content_addra = iv_rpb_free_data;
        qv_rpb_content_dina = {wv_cur_wqe_offset, qv_PMTU_fwd, qv_pkt_header[223:0]};     //Read request also stores legal entry number
    end
    else begin
        q_rpb_content_wea = 1'b0;
        qv_rpb_content_addra = qv_rpb_content_addra_TempReg;
        qv_rpb_content_dina = qv_rpb_content_dina_TempReg;
    end
end

//-- q_rpb_next_wea --
//-- qv_rpb_next_addra --
//-- qv_rpb_next_dina --
always @(*) begin
    if (rst) begin
        q_rpb_next_wea = 1'b0;
        qv_rpb_next_addra = 'd0;
        qv_rpb_next_dina = 'd0;
    end
	else if(RTC_cur_state == RTC_INIT_s && (qv_rpb_next_table_init_counter <= `RPB_CONTENT_FREE_NUM - 1)) begin
        q_rpb_next_wea = 1'b1;
        qv_rpb_next_addra = qv_rpb_next_table_init_counter;
        qv_rpb_next_dina = 'd0;
	end
    else if (RTC_cur_state == RTC_RC_SEG_s && wv_opcode == `VERBS_RDMA_READ && w_read_allowed) begin
        if(w_rpb_empty) begin   //Current queue is empty, do not modify next pointer
            q_rpb_next_wea = 1'b0;
            qv_rpb_next_addra = 'd0;
            qv_rpb_next_dina = 'd0;
        end
        else begin  //Modify next pointer of current item to new item
            q_rpb_next_wea = 1'b1;
            qv_rpb_next_addra = wv_rpb_tail;      
            qv_rpb_next_dina = {1'b1, qv_rpb_content_addra};
        end
    end
    else begin
        q_rpb_next_wea = 1'b0;
        qv_rpb_next_addra = qv_rpb_next_addra_TempReg;
        qv_rpb_next_dina = qv_rpb_next_dina_TempReg;
    end
end

//-- q_rpb_free_rd_en --
always @(*) begin
    if(RTC_cur_state == RTC_RC_SEG_s && wv_opcode == `VERBS_RDMA_READ && w_read_allowed) begin
        q_rpb_free_rd_en = 1'b1;
    end
    else begin
        q_rpb_free_rd_en = 1'b0;
    end
end

/***************************************** REB Management **********************************************/

 //Read Entry Buffer
//-- q_reb_list_head_wea --
//-- qv_reb_list_head_addra --
//-- qv_reb_list_head_dina --
always @(*) begin
    if (rst) begin
        q_reb_list_head_wea = 1'b0;
        qv_reb_list_head_addra = 'd0;
        qv_reb_list_head_dina = 'd0;        
    end
    /*Spyglass Modify Begin*/
    // else if (RTC_cur_state == RTC_RC_SEG_s && RTC_next_state != RTC_IDLE_s) begin
    else if (RTC_cur_state == RTC_RC_SEG_s) begin
    /*Spyglass Modify End*/
        q_reb_list_head_wea = 1'b0;
        qv_reb_list_head_addra = wv_src_qpn;
        qv_reb_list_head_dina = 'd0;         
    end
    else if (RTC_cur_state == RTC_RC_STE_s && !i_entry_from_dp_empty) begin
        if(w_reb_empty) begin
            q_reb_list_head_wea = 1'b1;
            qv_reb_list_head_addra = wv_src_qpn;
            qv_reb_list_head_dina = iv_reb_free_data;             
        end
        else begin
            q_reb_list_head_wea = 1'b0;
            qv_reb_list_head_addra = qv_reb_list_head_addra_TempReg;
            qv_reb_list_head_dina = qv_reb_list_head_dina_TempReg;             
        end
    end
    else begin
        q_reb_list_head_wea = 1'b0;
        qv_reb_list_head_addra = qv_reb_list_head_addra_TempReg;
        qv_reb_list_head_dina = qv_reb_list_head_dina_TempReg;         
    end
end

//-- q_reb_list_tail_wea --
//-- qv_reb_list_tail_addra --
//-- qv_reb_list_tail_dina --
always @(*) begin
    if (rst) begin
        q_reb_list_tail_wea = 1'b0;
        qv_reb_list_tail_addra = 'd0;
        qv_reb_list_tail_dina = 'd0;    
    end
    /*Spyglass Modify Begin*/
    // else if (RTC_cur_state == RTC_IDLE_s && RTC_next_state != RTC_IDLE_s) begin
    else if (RTC_cur_state == RTC_IDLE_s && !i_md_from_dp_empty) begin
    /*Spyglass Modify End*/
        q_reb_list_tail_wea = 1'b0;
        qv_reb_list_tail_addra = wv_src_qpn;
        qv_reb_list_tail_dina = 'd0;         
    end
    else if (RTC_cur_state == RTC_RC_STE_s && !i_entry_from_dp_empty) begin
        q_reb_list_tail_wea = 1'b1;
        qv_reb_list_tail_addra = wv_src_qpn;
        qv_reb_list_tail_dina = iv_reb_free_data; 
    end
    else begin
        q_reb_list_tail_wea = 1'b0;
        qv_reb_list_tail_addra = qv_reb_list_tail_addra_TempReg;
        qv_reb_list_tail_dina = qv_reb_list_tail_dina_TempReg; 
    end
end

//-- q_reb_list_empty_wea --
//-- qv_reb_list_empty_addra --
//-- qv_reb_list_empty_dina --
always @(*) begin
    if (rst) begin
        q_reb_list_empty_wea = 1'b0;
        qv_reb_list_empty_addra = 'd0;
        qv_reb_list_empty_dina = 'd0;         
    end
    /*Spyglass Modify Begin*/
    // else if (RTC_cur_state == RTC_IDLE_s && RTC_next_state != RTC_IDLE_s) begin
    else if (RTC_cur_state == RTC_IDLE_s && !i_md_from_dp_empty) begin
    /*Spyglass Modify End*/
        q_reb_list_empty_wea = 1'b0;
        qv_reb_list_empty_addra = wv_src_qpn;
        qv_reb_list_empty_dina = 'd0; 
    end
    else if (RTC_cur_state == RTC_RC_STE_s && !i_entry_from_dp_empty) begin
        q_reb_list_empty_wea = 1'b1;
        qv_reb_list_empty_addra = wv_src_qpn;
        qv_reb_list_empty_dina = 1'b0; 
    end
    else begin
        q_reb_list_empty_wea = 1'b0;
        qv_reb_list_empty_addra = qv_reb_list_empty_addra_TempReg;
        qv_reb_list_empty_dina = qv_reb_list_empty_dina_TempReg; 
    end
end

//-- q_reb_content_wea --
//-- qv_reb_content_addra --
//-- qv_reb_content_dina --
always @(*) begin
    if (rst) begin
        q_reb_content_wea = 1'b0;
        qv_reb_content_addra = 'd0;
        qv_reb_content_dina = 'd0;   
    end
    else if (RTC_cur_state == RTC_RC_STE_s && !i_entry_from_dp_empty) begin
        q_reb_content_wea = 1'b1;
        qv_reb_content_addra = iv_reb_free_data;
        qv_reb_content_dina = iv_entry_from_dp_data;
    end
    else begin
        q_reb_content_wea = 1'b0;
        qv_reb_content_addra = qv_reb_content_addra_TempReg;
        qv_reb_content_dina = qv_reb_content_dina_TempReg;        
    end
end

//-- q_reb_next_wea --
//-- qv_reb_next_addra --
//-- qv_reb_next_dina --
always @(*) begin
    if (rst) begin
        q_reb_next_wea = 1'b0;
        qv_reb_next_addra = 'd0;
        qv_reb_next_dina = 'd0;     
    end
	else if(RTC_cur_state == RTC_INIT_s && (qv_reb_next_table_init_counter <= `REB_CONTENT_FREE_NUM - 1)) begin
        q_reb_next_wea = 1'b1;
        qv_reb_next_addra = qv_reb_next_table_init_counter;
        qv_reb_next_dina = 'd0;
	end
    else if (RTC_cur_state == RTC_RC_STE_s && !w_reb_empty && !i_entry_from_dp_empty) begin //Only when queue is not empty should we updata next pointer
        q_reb_next_wea = 1'b1;
        qv_reb_next_addra = wv_reb_tail;
        qv_reb_next_dina = qv_reb_content_addra;  
    end
    else begin
        q_reb_next_wea = 1'b0;
        qv_reb_next_addra = qv_reb_next_addra_TempReg;
        qv_reb_next_dina = qv_reb_next_dina_TempReg;  
    end
end

//-- q_reb_free_rd_en --
always @(*) begin
    if(RTC_cur_state == RTC_RC_STE_s && !i_entry_from_dp_empty) begin
        q_reb_free_rd_en = 1'b1;
    end
    else begin
        q_reb_free_rd_en = 1'b0;
    end
end

/***************************************** SWPB Management *********************************************/
 //Send/Write Buffer
//-- q_swpb_list_head_wea --
//-- qv_swpb_list_head_addra --
//-- qv_swpb_list_head_dina --
always @(*) begin
    if (rst) begin
        q_swpb_list_head_wea = 1'b0;
        qv_swpb_list_head_addra = 'd0;
        qv_swpb_list_head_dina = 'd0;        
    end
    /*Spyglass Modify Begin*/
    // else if (RTC_cur_state == RTC_IDLE_s && RTC_next_state != RTC_IDLE_s) begin
    else if (RTC_cur_state == RTC_IDLE_s && !i_md_from_dp_empty) begin
    /*Spyglass Modify End*/
        q_swpb_list_head_wea = 1'b0;
        qv_swpb_list_head_addra = wv_src_qpn;
        qv_swpb_list_head_dina = 'd0;                
    end
    else if (RTC_cur_state == RTC_RC_SEG_s) begin
        if((wv_opcode == `VERBS_SEND || wv_opcode == `VERBS_SEND_WITH_IMM) && ((q_first_pkt && w_send_allowed) || (w_pkt_allowed && !q_first_pkt)) && w_swpb_empty) begin
            q_swpb_list_head_wea = 1'b1;
            qv_swpb_list_head_addra = wv_src_qpn;
            qv_swpb_list_head_dina = iv_swpb_free_data;                    
        end
        else if((wv_opcode == `VERBS_RDMA_WRITE || wv_opcode == `VERBS_RDMA_WRITE_WITH_IMM) && ((q_first_pkt && w_write_allowed) || (w_pkt_allowed && !q_first_pkt)) && w_swpb_empty) begin
            q_swpb_list_head_wea = 1'b1;
            qv_swpb_list_head_addra = wv_src_qpn;
            qv_swpb_list_head_dina = iv_swpb_free_data;                    
        end
        else begin
            q_swpb_list_head_wea = 1'b0;
            qv_swpb_list_head_addra = qv_swpb_list_head_addra_TempReg;
            qv_swpb_list_head_dina = qv_swpb_list_head_dina_TempReg;        
        end
    end
    else if (RTC_cur_state == RTC_RC_FWD_s) begin   //No need to judge empty because metadata is stored before
        q_swpb_list_head_wea = 1'b0;
        qv_swpb_list_head_addra = qv_swpb_list_head_addra_TempReg;
        qv_swpb_list_head_dina = qv_swpb_list_head_dina_TempReg;        
    end
    else begin
        q_swpb_list_head_wea = 1'b0;
        qv_swpb_list_head_addra = qv_swpb_list_head_addra_TempReg;
        qv_swpb_list_head_dina = qv_swpb_list_head_dina_TempReg;        
    end
end

//-- q_swpb_list_tail_wea --
//-- qv_swpb_list_tail_addra --
//-- qv_swpb_list_tail_dina --
always @(*) begin
    if (rst) begin
        q_swpb_list_tail_wea = 1'b0;
        qv_swpb_list_tail_addra = 'd0;
        qv_swpb_list_tail_dina = 'd0;             
    end
    /*Spyglass Modify Begin*/
    // else if (RTC_cur_state == RTC_IDLE_s && RTC_next_state != RTC_IDLE_s) begin
    else if (RTC_cur_state == RTC_IDLE_s && !i_md_from_dp_empty) begin
    /*Spyglass Modify End*/
        q_swpb_list_tail_wea = 1'b0;
        qv_swpb_list_tail_addra = wv_src_qpn;
        qv_swpb_list_tail_dina = 'd0;
    end
    else if (RTC_cur_state == RTC_RC_SEG_s) begin
        if((wv_opcode == `VERBS_SEND || wv_opcode == `VERBS_SEND_WITH_IMM) && ((q_first_pkt && w_send_allowed) || (w_pkt_allowed && !q_first_pkt))) begin
            q_swpb_list_tail_wea = 1'b1;
            qv_swpb_list_tail_addra = wv_src_qpn;
            qv_swpb_list_tail_dina = iv_swpb_free_data;            
        end
        else if((wv_opcode == `VERBS_RDMA_WRITE || wv_opcode == `VERBS_RDMA_WRITE_WITH_IMM) && ((q_first_pkt && w_write_allowed) || (w_pkt_allowed && !q_first_pkt))) begin
            q_swpb_list_tail_wea = 1'b1;
            qv_swpb_list_tail_addra = wv_src_qpn;
            qv_swpb_list_tail_dina = iv_swpb_free_data;                
        end
        else begin
            q_swpb_list_tail_wea = 1'b0;
            /*Spyglass Modify Begin*/
            // qv_swpb_list_tail_addra = qv_swpb_list_tail_addra;
            // qv_swpb_list_tail_dina = qv_swpb_list_tail_dina;     
            qv_swpb_list_tail_addra = qv_swpb_list_tail_addra_TempReg;
            qv_swpb_list_tail_dina = qv_swpb_list_tail_dina_TempReg;             
            /*Spyglass Modify End*/
        end
    end
    else if (RTC_cur_state == RTC_RC_FWD_s) begin
        if(!i_nd_from_dp_empty && !i_nd_to_rpg_prog_full) begin
            q_swpb_list_tail_wea = 1'b1;
            qv_swpb_list_tail_addra = wv_src_qpn;
            qv_swpb_list_tail_dina = iv_swpb_free_data;    
        end
        else begin
            q_swpb_list_tail_wea = 1'b0;
            qv_swpb_list_tail_addra = qv_swpb_list_tail_addra_TempReg;
            qv_swpb_list_tail_dina = qv_swpb_list_tail_dina_TempReg;                
        end
    end
    else begin
        q_swpb_list_tail_wea = 1'b0;
        qv_swpb_list_tail_addra = qv_swpb_list_tail_addra_TempReg;
        qv_swpb_list_tail_dina = qv_swpb_list_tail_dina_TempReg;         
    end
end

//-- q_swpb_list_empty_wea --
//-- qv_swpb_list_empty_addra --
//-- qv_swpb_list_empty_dina --
always @(*) begin
    if (rst) begin
        q_swpb_list_empty_wea = 1'b0;
        qv_swpb_list_empty_addra = 'd0;
        qv_swpb_list_empty_dina = 'd0;             
    end
    /*Spyglass Modify Begin*/
    // else if (RTC_cur_state == RTC_IDLE_s && RTC_next_state != RTC_IDLE_s) begin
    else if (RTC_cur_state == RTC_IDLE_s && !i_md_from_dp_empty) begin
    /*Spyglass Modify End*/
        q_swpb_list_empty_wea = 1'b0;
        qv_swpb_list_empty_addra = wv_src_qpn;
        qv_swpb_list_empty_dina = 'd0;
    end
    else if (RTC_cur_state == RTC_RC_SEG_s) begin
        if((wv_opcode == `VERBS_SEND || wv_opcode == `VERBS_SEND_WITH_IMM) && ((q_first_pkt && w_send_allowed) || (w_pkt_allowed && !q_first_pkt))) begin
            q_swpb_list_empty_wea = 1'b1;
            qv_swpb_list_empty_addra = wv_src_qpn;
            qv_swpb_list_empty_dina = 1'b0;            
        end
        else if((wv_opcode == `VERBS_RDMA_WRITE || wv_opcode == `VERBS_RDMA_WRITE_WITH_IMM) && ((q_first_pkt && w_write_allowed) || (w_pkt_allowed && !q_first_pkt))) begin
            q_swpb_list_empty_wea = 1'b1;
            qv_swpb_list_empty_addra = wv_src_qpn;
            qv_swpb_list_empty_dina = 1'b0;                
        end
        else begin
            q_swpb_list_empty_wea = 1'b0;
            qv_swpb_list_empty_addra = qv_swpb_list_empty_addra_TempReg;
            qv_swpb_list_empty_dina = qv_swpb_list_empty_dina_TempReg;                
        end
    end
    else if (RTC_cur_state == RTC_RC_FWD_s) begin
        if(!i_nd_from_dp_empty && !i_nd_to_rpg_prog_full) begin
            q_swpb_list_empty_wea = 1'b1;
            qv_swpb_list_empty_addra = wv_src_qpn;
            qv_swpb_list_empty_dina = qv_swpb_list_empty_dina_TempReg;    
        end
        else begin
            q_swpb_list_empty_wea = 1'b0;
            qv_swpb_list_empty_addra = qv_swpb_list_empty_addra_TempReg;
            qv_swpb_list_empty_dina = qv_swpb_list_empty_dina_TempReg;                
        end
    end
    else begin
        q_swpb_list_empty_wea = 1'b0;
        qv_swpb_list_empty_addra = qv_swpb_list_empty_addra_TempReg;
        qv_swpb_list_empty_dina = qv_swpb_list_empty_dina_TempReg;         
    end
end

//-- q_swpb_content_wea --
//-- qv_swpb_content_addra --
//-- qv_swpb_content_dina --
always @(*) begin
    if (rst) begin
        q_swpb_content_wea = 1'b0;
        qv_swpb_content_addra = 'd0;
        qv_swpb_content_dina = 'd0;      
    end
	else if (RTC_cur_state == RTC_INIT_s) begin
        q_swpb_content_wea = 1'b1;
        qv_swpb_content_addra = qv_swpb_content_table_init_counter;
        qv_swpb_content_dina = 'd0;      
	end 
    else if (RTC_cur_state == RTC_RC_SEG_s) begin
        if((wv_opcode == `VERBS_SEND || wv_opcode == `VERBS_SEND_WITH_IMM) && ((q_first_pkt && w_send_allowed) || (w_pkt_allowed && !q_first_pkt))) begin
            q_swpb_content_wea = 1'b1;
            qv_swpb_content_addra = iv_swpb_free_data;
            qv_swpb_content_dina = {wv_cur_wqe_offset, qv_pkt_header};             
        end
        else if((wv_opcode == `VERBS_RDMA_WRITE || wv_opcode == `VERBS_RDMA_WRITE_WITH_IMM) && ((q_first_pkt && w_write_allowed) || (w_pkt_allowed && !q_first_pkt))) begin
            q_swpb_content_wea = 1'b1;
            qv_swpb_content_addra = iv_swpb_free_data;
            qv_swpb_content_dina = {wv_cur_wqe_offset, qv_pkt_header};             
        end
        else begin
            q_swpb_content_wea = 1'b0;
            qv_swpb_content_addra = 'd0;
            qv_swpb_content_dina = 'd0; 
        end
    end
    else if(RTC_cur_state == RTC_RC_FWD_s) begin
        if(!i_nd_from_dp_empty && !i_nd_to_rpg_prog_full) begin
            q_swpb_content_wea = 1'b1;
            qv_swpb_content_addra = iv_swpb_free_data;
            qv_swpb_content_dina = {wv_cur_wqe_offset, iv_nd_from_dp_data}; 
        end
        else begin
            q_swpb_content_wea = 1'b0;
            qv_swpb_content_addra = qv_swpb_content_addra_TempReg;
            qv_swpb_content_dina = qv_swpb_content_dina_TempReg;            
        end
    end
    else begin
        q_swpb_content_wea = 1'b0;
        qv_swpb_content_addra = qv_swpb_content_addra_TempReg;
        qv_swpb_content_dina = qv_swpb_content_dina_TempReg;  
    end
end

//-- q_swpb_next_wea --
//-- qv_swpb_next_addra --
//-- qv_swpb_next_dina --
always @(*) begin
    if (rst) begin
        q_swpb_next_wea = 1'b0;
        qv_swpb_next_addra = 'd0;
        qv_swpb_next_dina = 'd0;        
    end
    // else if (RTC_cur_state == RTC_IDLE_s && RTC_next_state != RTC_IDLE_s) begin
    //     q_swpb_next_wea = 1'b1;
    //     qv_swpb_next_addra = wv_swpb_tail;
    //     qv_swpb_next_dina = iv_swpb_free_data;
    // end
	else if(RTC_cur_state == RTC_INIT_s && (qv_swpb_next_table_init_counter <= `SWPB_CONTENT_FREE_NUM - 1)) begin
        q_swpb_next_wea = 1'b1;
        qv_swpb_next_addra = qv_swpb_next_table_init_counter;
        qv_swpb_next_dina = 'd0;
	end
    else if (RTC_cur_state == RTC_RC_SEG_s) begin
        if((wv_opcode == `VERBS_SEND || wv_opcode == `VERBS_SEND_WITH_IMM) && ((q_first_pkt && w_send_allowed) || (w_pkt_allowed && !q_first_pkt))) begin
            if(w_swpb_empty) begin  //No need to modify next
                q_swpb_next_wea = 1'b0;
                qv_swpb_next_addra = 'd0;
                qv_swpb_next_dina = 'd0;                 
            end
            else begin  //Modify current tail->next
                q_swpb_next_wea = 1'b1;
                qv_swpb_next_addra = wv_swpb_tail;
                qv_swpb_next_dina = qv_swpb_content_addra;
            end
        end
        else if((wv_opcode == `VERBS_RDMA_WRITE || wv_opcode == `VERBS_RDMA_WRITE_WITH_IMM) && ((q_first_pkt && w_write_allowed) || (w_pkt_allowed && !q_first_pkt))) begin
            if(w_swpb_empty) begin  //First element to write into, no need to modify next
                q_swpb_next_wea = 1'b0;
                qv_swpb_next_addra = 'd0;
                qv_swpb_next_dina = 'd0;                 
            end
            else begin  //Modify current tail->next
                q_swpb_next_wea = 1'b1;
                qv_swpb_next_addra = wv_swpb_tail;
                qv_swpb_next_dina = qv_swpb_content_addra;
            end           
        end
        else begin
            q_swpb_next_wea = 1'b0;
            qv_swpb_next_addra = qv_swpb_next_addra_TempReg;
            qv_swpb_next_dina = qv_swpb_next_dina_TempReg; 
        end      
    end
    else if (RTC_cur_state == RTC_RC_FWD_s && !i_nd_from_dp_empty && !i_nd_to_rpg_prog_full) begin
        if(w_swpb_empty) begin  //No need to modify next
            q_swpb_next_wea = 1'b0;
            qv_swpb_next_addra = qv_swpb_next_addra_TempReg;
            qv_swpb_next_dina = qv_swpb_next_dina_TempReg;                 
        end
        else begin  //Modify current tail->next
            q_swpb_next_wea = 1'b1;
            qv_swpb_next_addra = wv_swpb_tail;
            qv_swpb_next_dina = qv_swpb_content_addra;
        end
    end
    else begin
        q_swpb_next_wea = 1'b0;
        qv_swpb_next_addra = qv_swpb_next_addra_TempReg;
        qv_swpb_next_dina = qv_swpb_next_dina_TempReg; 
    end
end

//-- q_swpb_free_rd_en --
always @(*) begin
    if(RTC_cur_state == RTC_RC_SEG_s) begin
        if((wv_opcode == `VERBS_SEND || wv_opcode == `VERBS_SEND_WITH_IMM) && ((q_first_pkt && w_send_allowed) || (w_pkt_allowed && !q_first_pkt))) begin
            q_swpb_free_rd_en = 1'b1;   
        end
        else if((wv_opcode == `VERBS_RDMA_WRITE || wv_opcode == `VERBS_RDMA_WRITE_WITH_IMM) && ((q_first_pkt && w_write_allowed) || (w_pkt_allowed && !q_first_pkt))) begin
            q_swpb_free_rd_en = 1'b1;
        end
        else begin
            q_swpb_free_rd_en = 1'b0;
        end       
    end
    else if(RTC_cur_state == RTC_RC_FWD_s) begin
        if(!i_nd_from_dp_empty && !i_nd_to_rpg_prog_full) begin
            q_swpb_free_rd_en = 1'b1;
        end
        else begin
            q_swpb_free_rd_en = 1'b0;
        end
    end
    else begin
        q_swpb_free_rd_en = 1'b0;
    end
end

/************************************************* Previous State FIFO rd_en *************************************/

//-- q_atomics_from_dp_rd_en -- 
//TODO : Atomics operation not supported yet
always @(*) begin
    // q_atomics_from_dp_rd_en = (RTC_cur_state != RTC_IDLE_s) && (RTC_next_state == RTC_IDLE_s);
    if(rst) begin 
		q_atomics_from_dp_rd_en = 1'b0;
	end 
	else begin 
    	q_atomics_from_dp_rd_en = 1'b0;
	end 
end

//-- q_raddr_from_dp_rd_en --
always @(*) begin
	if(rst) begin
		q_raddr_from_dp_rd_en = 'd0;
	end 
    else if(RTC_cur_state == RTC_RC_SEG_s) begin
        if(q_first_pkt && (wv_opcode == `VERBS_RDMA_WRITE || wv_opcode == `VERBS_RDMA_WRITE_WITH_IMM) && w_write_allowed) begin
 			q_raddr_from_dp_rd_en = !i_raddr_from_dp_empty; 
		end
        else if((wv_opcode == `VERBS_RDMA_READ) && !i_header_to_rpg_prog_full) begin
            q_raddr_from_dp_rd_en = !i_raddr_from_dp_empty;
        end
        else begin
            q_raddr_from_dp_rd_en = 1'b0;
        end
    end
    else if(RTC_cur_state == RTC_UCUD_SEG_s) begin
        if(q_first_pkt && (wv_opcode == `VERBS_RDMA_WRITE || wv_opcode == `VERBS_RDMA_WRITE_WITH_IMM) && w_write_allowed) begin
 			q_raddr_from_dp_rd_en = !i_raddr_from_dp_empty; 
		end
        else begin
            q_raddr_from_dp_rd_en = 1'b0;
        end
    end
	else if(RTC_cur_state == RTC_FLUSH_s && qv_err_point == 'd2 && q_flush_finish) begin
		if(wv_opcode == `VERBS_RDMA_READ || wv_opcode == `VERBS_RDMA_WRITE || wv_opcode == `VERBS_RDMA_WRITE_WITH_IMM) begin
			q_raddr_from_dp_rd_en = 1'b1;
		end 
		else begin
			q_raddr_from_dp_rd_en = 1'b0;
		end 
	end  
    else begin
        q_raddr_from_dp_rd_en = 1'b0;
    end
end

//-- q_entry_from_dp_rd_en --
always @(*) begin
	if(rst) begin
		q_entry_from_dp_rd_en = 'd0;
	end 
    else  if(RTC_cur_state == RTC_RC_STE_s) begin
        q_entry_from_dp_rd_en = !i_entry_from_dp_empty;
    end
	else if(RTC_cur_state == RTC_FLUSH_s && qv_err_point == 'd2 && wv_opcode == `VERBS_RDMA_READ && !i_raddr_from_dp_empty) begin
		q_entry_from_dp_rd_en = !i_entry_from_dp_empty;
	end 
    else begin
        q_entry_from_dp_rd_en = 1'b0;
    end
end

//-- q_md_from_dp_rd_en --
/*Spyglass Modify Begin*/
// always @(*) begin
//     else if(RTC_cur_state == RTC_RC_FWD_s && RTC_next_state == RTC_WB_CXT_s) begin
//         q_md_from_dp_rd_en = 1'b1;
//     end
//     else if(RTC_cur_state == RTC_RC_BAD_REQ_s && RTC_next_state == RTC_IDLE_s) begin
//         q_md_from_dp_rd_en = 1'b1;
//     end
//     else if(RTC_cur_state == RTC_UCUD_CPL_s && RTC_next_state == RTC_WB_CXT_s) begin
//         q_md_from_dp_rd_en = 1'b1;
//     end
//     else begin
//         q_md_from_dp_rd_en = 1'b0;
//     end
// end

always @(*) begin
	if(rst) begin 
		q_md_from_dp_rd_en = 1'b0;
	end 
	else if(qv_ser == `RC && RTC_cur_state == RTC_WB_CXT_s && q_last_pkt && !i_cxtmgt_cmd_prog_full && !i_cxtmgt_cxt_prog_full) begin
        q_md_from_dp_rd_en = 1'b1;
    end
	//else if(qv_ser != `RC && RTC_cur_state == RTC_UCUD_CPL_s && q_last_pkt && !i_cxtmgt_cmd_prog_full && !i_cxtmgt_cxt_prog_full && i_rtc_resp_valid) begin
	else if(qv_ser != `RC && RTC_cur_state == RTC_UCUD_CPL_s && q_last_pkt && i_rtc_resp_valid) begin
        q_md_from_dp_rd_en = 1'b1;
    end
    else begin
        q_md_from_dp_rd_en = 1'b0;
    end
end
/*Spyglass Modify End*/

//-- q_nd_from_dp_rd_en --
always @(*) begin
    case(RTC_cur_state)
        RTC_RC_FWD_s:       if(!i_nd_from_dp_empty && !i_nd_to_rpg_prog_full) begin
                                q_nd_from_dp_rd_en = 1'b1;
                            end
                            else begin
                                q_nd_from_dp_rd_en = 1'b0;
                            end
        RTC_UCUD_FWD_s:     if(!i_nd_from_dp_empty && !i_nd_to_rpg_prog_full) begin
                                q_nd_from_dp_rd_en = 1'b1;
                            end
                            else begin
                                q_nd_from_dp_rd_en = 1'b0;
                            end
        RTC_FLUSH_s:        if((wv_opcode == `VERBS_SEND || wv_opcode == `VERBS_SEND_WITH_IMM) && wv_msg_size > 0) begin
                                q_nd_from_dp_rd_en = !i_nd_from_dp_empty;
                            end
                            else if(wv_opcode == `VERBS_RDMA_WRITE || wv_opcode == `VERBS_RDMA_WRITE_WITH_IMM) begin
                                q_nd_from_dp_rd_en = !i_nd_from_dp_empty;
                            end
                            else begin
                                q_nd_from_dp_rd_en = 1'b0;
                            end
        default:            q_nd_from_dp_rd_en = 1'b0;
    endcase
end

/**************************************** CxtMgt ******************************************/
//-- q_cxtmgt_cmd_wr_en --
//-- qv_cxtmgt_cmd_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_cxtmgt_cmd_wr_en <= 1'b0;   
        qv_cxtmgt_cmd_data <= 'd0;     
    end
    else if (RTC_cur_state == RTC_FETCH_CXT_s && !i_cxtmgt_cmd_prog_full) begin //Fetch context
        q_cxtmgt_cmd_wr_en <= 1'b1;
        qv_cxtmgt_cmd_data <= {`RD_QP_CTX, `RD_QP_NPST, wv_src_qpn, 96'h0};
    end
    else if (RTC_cur_state == RTC_WB_CXT_s && !i_cxtmgt_cmd_prog_full && !i_cxtmgt_cxt_prog_full) begin
        q_cxtmgt_cmd_wr_en <= 1'b1;
        qv_cxtmgt_cmd_data <= {`WR_QP_CTX, `WR_QP_NPST, wv_src_qpn, 96'h0};
    end
    else begin
        q_cxtmgt_cmd_wr_en <= 1'b0;
        qv_cxtmgt_cmd_data <= qv_cxtmgt_cmd_data;
    end
end

//-- q_cxtmgt_cxt_wr_en --
//-- qv_cxtmgt_cxt_data --
//If metadata indicates that there is an error, we change QP state, otherwise remains unchanged
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_cxtmgt_cxt_wr_en <= 1'b0;
        qv_cxtmgt_cxt_data <= 'd0;        
    end
    else if (RTC_cur_state == RTC_WB_CXT_s && !i_cxtmgt_cxt_prog_full && !i_cxtmgt_cmd_prog_full) begin
        q_cxtmgt_cxt_wr_en <= 1'b1;
        qv_cxtmgt_cxt_data <= {96'h0, qv_next_psn, 5'h0, (wv_err_type == `QP_NORMAL) ? wv_qp_state : `QP_ERR};  
    end
    else begin
        q_cxtmgt_cxt_wr_en <= 1'b0;
        qv_cxtmgt_cxt_data <= 'd0;
    end
end

//-- q_cxtmgt_resp_rd_en --
//-- q_cxtmgt_cxt_rd_en --
//When we finish a message, we read the cxtmgt resp FIFO
always @(*) begin
	if(rst) begin
        q_cxtmgt_resp_rd_en = 1'b0;
        q_cxtmgt_cxt_rd_en = 1'b0;
	end 
	else if(qv_ser == `RC && RTC_cur_state == RTC_WB_CXT_s && q_last_pkt && !i_cxtmgt_cmd_prog_full && !i_cxtmgt_cxt_prog_full) begin
        q_cxtmgt_resp_rd_en = 1'b1;
        q_cxtmgt_cxt_rd_en = 1'b1;
    end
	else if(qv_ser != `RC && RTC_cur_state == RTC_UCUD_CPL_s && q_last_pkt && i_rtc_resp_valid && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin
        q_cxtmgt_resp_rd_en = 1'b1;
        q_cxtmgt_cxt_rd_en = 1'b1;
    end
    else begin
        q_cxtmgt_resp_rd_en = 1'b0;
        q_cxtmgt_cxt_rd_en = 1'b0;
    end
end

/**************************************** VTP **************************************************/


always @(*) begin 
	if(rst) begin 
		qv_vtp_type = 'd0;
		qv_vtp_opcode = 'd0;
		qv_vtp_pd = 'd0;
		qv_vtp_lkey = 'd0;
		qv_vtp_vaddr = 'd0;
		qv_vtp_length = 'd0;
	end 
	else if(RTC_cur_state == RTC_UCUD_CPL_s && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && i_rtc_resp_valid) begin 
		qv_vtp_type = `WR_REQ_DATA;
		qv_vtp_opcode = `WR_CQE_DATA;
		qv_vtp_pd = wv_scq_pd;
		// qv_vtp_lkey = iv_cxtmgt_cxt_data[63:32];
        qv_vtp_lkey = wv_scq_lkey;
		// qv_vtp_vaddr = iv_cq_offset_table_douta;
        qv_vtp_vaddr = {40'd0, iv_rtc_cq_offset};
		qv_vtp_length = `CQE_LENGTH;
	end 
	else begin 
		qv_vtp_type = 'd0;
		qv_vtp_opcode = 'd0;
		qv_vtp_pd = 'd0;
		qv_vtp_lkey = 'd0;
		qv_vtp_vaddr = 'd0;
		qv_vtp_length = 'd0;
	end 
end 



//-- flags -- 
assign wv_vtp_flags = { qv_mthca_mpt_flag_sw_owns,
						q_absolute_addr,
						q_relative_addr,
						8'd0,
						q_mthca_mpt_flag_mio,
						1'd0,
						q_mthca_mpt_flag_bind_enable,
						5'd0,
						q_mthca_mpt_flag_physical,
						q_mthca_mpt_flag_region,
						1'd0,
						q_ibv_access_on_demand,
						q_ibv_access_zero_based,
						q_ibv_access_mw_bind,
						q_ibv_access_remote_atomic,
						q_ibv_access_remote_read,
						q_ibv_access_remote_write,
						q_ibv_access_local_write
					};

//-- flags attributes
always @(*) begin
	if(rst) begin 
		qv_mthca_mpt_flag_sw_owns = 'd0;
		q_absolute_addr = 'd0;
		q_relative_addr = 'd0;
		q_mthca_mpt_flag_mio = 'd0;
		q_mthca_mpt_flag_bind_enable = 'd0;
		q_mthca_mpt_flag_physical = 'd0;
		q_mthca_mpt_flag_region = 'd0;
		q_ibv_access_on_demand = 'd0;
		q_ibv_access_zero_based = 'd0;
		q_ibv_access_mw_bind = 'd0;
		q_ibv_access_remote_atomic = 'd0;
		q_ibv_access_remote_read = 'd0;
		q_ibv_access_remote_write = 'd0;
		q_ibv_access_local_write = 'd0;
	end 
	else if (RTC_cur_state == RTC_UCUD_CPL_s && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin 
		qv_mthca_mpt_flag_sw_owns = 'd0;
		q_absolute_addr = 'd0;
		q_relative_addr = 'd1;
		q_mthca_mpt_flag_mio = 'd0;
		q_mthca_mpt_flag_bind_enable = 'd0;
		q_mthca_mpt_flag_physical = 'd0;
		q_mthca_mpt_flag_region = 'd0;
		q_ibv_access_on_demand = 'd0;
		q_ibv_access_zero_based = 'd0;
		q_ibv_access_mw_bind = 'd0;
		q_ibv_access_remote_atomic = 'd0;
		q_ibv_access_remote_read = 'd0;
		q_ibv_access_remote_write = 'd0;
		q_ibv_access_local_write = 'd1;
	end 
	else begin 
		qv_mthca_mpt_flag_sw_owns = 'd0;
		q_absolute_addr = 'd0;
		q_relative_addr = 'd0;
		q_mthca_mpt_flag_mio = 'd0;
		q_mthca_mpt_flag_bind_enable = 'd0;
		q_mthca_mpt_flag_physical = 'd0;
		q_mthca_mpt_flag_region = 'd0;
		q_ibv_access_on_demand = 'd0;
		q_ibv_access_zero_based = 'd0;
		q_ibv_access_mw_bind = 'd0;
		q_ibv_access_remote_atomic = 'd0;
		q_ibv_access_remote_read = 'd0;
		q_ibv_access_remote_write = 'd0;
		q_ibv_access_local_write = 'd0;
	end 
end 


//-- q_vtp_cmd_wr_en --
//-- qv_vtp_cmd_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_vtp_cmd_wr_en <= 1'b0;
        qv_vtp_cmd_data <= 'd0;        
    end
    else if (RTC_cur_state == RTC_UCUD_CPL_s && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && i_rtc_resp_valid) begin	//Generate UC/UD CPL
        q_vtp_cmd_wr_en <= 1'b1;
        qv_vtp_cmd_data <= {32'd0, qv_vtp_length, qv_vtp_vaddr, qv_vtp_lkey, qv_vtp_pd, wv_vtp_flags, 24'd0, qv_vtp_opcode, qv_vtp_type};
    end
    else begin
        q_vtp_cmd_wr_en <= 1'b0;
        qv_vtp_cmd_data <= qv_vtp_cmd_data;
    end
end

//-- q_vtp_resp_rd_en --
always @(*) begin
	if(rst) begin 
		q_vtp_resp_rd_en = 1'b0;
	end 
	else begin 
	    q_vtp_resp_rd_en = (RTC_cur_state != RTC_IDLE_s) && !i_vtp_resp_empty;
	end 
end


always @(*) begin 
	if(rst) begin 
		qv_my_qpn = 'd0;
		qv_my_ee = 'd0;
		qv_rqpn = 'd0;
		qv_rlid = 'd0;
		qv_sl_g_mlpath = 'd0;
		qv_imm_etype_pkey_eec = 'd0;
		qv_byte_cnt = 'd0;
		qv_wqe = 'd0;
		qv_owner = 'd0;
		qv_is_send = 'd0;
		qv_opcode = 'd0;
		
		qv_vendor_err = 'd0;
	end 
	else if(RTC_cur_state == RTC_UCUD_CPL_s && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin 
		qv_my_qpn = {8'd0, wv_src_qpn};
		qv_my_ee = 'd0;
		qv_rqpn = wv_dst_qpn;
		qv_rlid = wv_rlid;
		qv_sl_g_mlpath = 'd0;
		qv_imm_etype_pkey_eec = 'd0;
		//qv_byte_cnt = ((wv_qp_state != `QP_RTS || wv_qp_state != `QP_RTR) && (wv_err_type != `QP_NORMAL)) ? 0 : wv_msg_size;
		qv_byte_cnt = wv_msg_size;
		qv_wqe = wv_cur_wqe_offset;
		qv_owner = 'd0;
		//qv_is_send = (wv_opcode == `VERBS_SEND || wv_opcode == `VERBS_SEND_WITH_IMM) ? 1 : 0;
		qv_is_send = 'd1;
		qv_opcode = wv_opcode;
		//qv_opcode = 'd0;

		qv_vendor_err = 'd0;
	end 
	else begin 
		qv_my_qpn = 'd0;
		qv_my_ee = 'd0;
		qv_rqpn = 'd0;
		qv_rlid = 'd0;
		qv_sl_g_mlpath = 'd0;
		qv_imm_etype_pkey_eec = 'd0;
		qv_byte_cnt = 'd0;
		qv_wqe = 'd0;
		qv_owner = 'd0;
		qv_is_send = 'd0;
		qv_opcode = 'd0;

		qv_vendor_err = 'd0;
	end 
end 

always @(*) begin 
	if(rst) begin 
		qv_syndrome = 'd0;
	end 
	else if(RTC_cur_state == RTC_UCUD_CPL_s && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin 
		if(wv_qp_state == `QP_SQE || wv_qp_state == `QP_SQD && wv_qp_state == `QP_ERR) begin 
			qv_syndrome = `WR_FLUSH_ERR;
		end 
		else if(wv_err_type == `QP_STATE_ERR) begin 
			qv_syndrome = `WR_FLUSH_ERR;
		end 
		else if(wv_err_type == `QP_OPCODE_ERR) begin 
			qv_syndrome = `LOC_QP_OP_ERR;
		end 
		else if(wv_err_type == `QP_LOCAL_ACCESS_ERR) begin 
			qv_syndrome = `LOC_ACCESS_ERR;
		end 
		else begin 
			qv_syndrome = 'd0;
		end 
	end 
	else begin 
		qv_syndrome = 'd0;
	end 
end 

//-- q_vtp_upload_wr_en --
//-- qv_vtp_upload_data --
//For UC/UD Completion Write Request
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_vtp_upload_wr_en <= 1'b0;
        qv_vtp_upload_data <= 'd0;
    end
    else if (RTC_cur_state == RTC_UCUD_CPL_s && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && i_rtc_resp_valid) begin
		if((wv_qp_state == `QP_RTS || wv_qp_state == `QP_RTR) && wv_err_type == `QP_NORMAL) begin 
			q_vtp_upload_wr_en <= 1'b1;
			//qv_vtp_upload_data <= {qv_opcode, qv_is_send, 8'd0, qv_owner, qv_wqe, qv_imm_etype_pkey_eec, qv_sl_g_mlpath, qv_rlid, qv_rqpn, qv_my_ee, qv_my_qpn};
	//		qv_vtp_upload_data <= {qv_owner, 8'd0, qv_is_send, qv_opcode, qv_wqe, qv_byte_cnt, qv_imm_etype_pkey_eec, qv_sl_g_mlpath, qv_rlid, qv_rqpn, qv_my_ee, qv_my_qpn};
			qv_vtp_upload_data <= {qv_owner, 8'd0, qv_is_send, qv_opcode, qv_wqe, qv_byte_cnt, qv_imm_etype_pkey_eec, qv_rlid, qv_sl_g_mlpath, qv_rqpn, qv_my_ee, qv_my_qpn};
		end 
		else begin //Err State
	        q_vtp_upload_wr_en <= 1'b1;
			qv_vtp_upload_data <= {qv_owner, 8'd0, 8'd0, qv_opcode, qv_wqe, 32'd0, qv_syndrome, qv_vendor_err, 16'd0, 96'd0, qv_my_qpn};
		end 
    end
	else begin 
		q_vtp_upload_wr_en <= 1'b0;
		qv_vtp_upload_data <= 'd0;
	end 
end

/**************************************** RequesterRecvControl **************************************************/
//-- q_br_wr_en --
//-- qv_br_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_br_wr_en <= 1'd0;
        qv_br_data <= 'd0;        
    end
    else if (RTC_cur_state == RTC_RC_BAD_REQ_s && !i_br_prog_full) begin		//Forward bad request to RRC
        q_br_wr_en <= 1'b1;
        qv_br_data <= {wv_cur_wqe_offset, 27'd0, wv_opcode, {4'd0, wv_err_type}, wv_src_qpn};
    end
	else begin 
		q_br_wr_en <= 1'b0;
		qv_br_data <= qv_br_data;
	end 
end

/**************************************** ReqPktGen **************************************************/
//-- q_header_to_rpg_wr_en --
//-- qv_header_to_rpg_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_header_to_rpg_wr_en <= 1'b0;
        qv_header_to_rpg_data <= 'd0;        
    end
    else if (RTC_cur_state == RTC_RC_SEG_s || RTC_cur_state == RTC_UCUD_SEG_s) begin
        if(wv_opcode == `VERBS_RDMA_READ && w_read_allowed) begin //Not appliable for UCUD_SEG
            q_header_to_rpg_wr_en <= 1'b1;
            qv_header_to_rpg_data <= qv_pkt_header;
        end
        else if((wv_opcode == `VERBS_SEND || wv_opcode == `VERBS_SEND_WITH_IMM) && ((q_first_pkt && w_send_allowed) || (w_pkt_allowed && !q_first_pkt))) begin
            q_header_to_rpg_wr_en <= 1'b1;
            qv_header_to_rpg_data <= qv_pkt_header;
        end
        else if((wv_opcode == `VERBS_RDMA_WRITE || wv_opcode == `VERBS_RDMA_WRITE_WITH_IMM) && ((q_first_pkt && w_write_allowed) || (w_pkt_allowed && !q_first_pkt))) begin
            q_header_to_rpg_wr_en <= 1'b1;
            qv_header_to_rpg_data <= qv_pkt_header;
        end
        else begin
            q_header_to_rpg_wr_en <= 1'b0;
            qv_header_to_rpg_data <= qv_header_to_rpg_data;
        end
    end
    else begin
        q_header_to_rpg_wr_en <= 1'b0;
        qv_header_to_rpg_data <= qv_header_to_rpg_data;        
    end
end

//-- q_nd_to_rpg_wr_en --
//-- qv_nd_to_rpg_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_nd_to_rpg_wr_en <= 1'b0;
        qv_nd_to_rpg_data <= 'd0;
    end
    else if ((RTC_cur_state == RTC_RC_FWD_s || RTC_cur_state == RTC_UCUD_FWD_s) && !i_nd_from_dp_empty && !i_nd_to_rpg_prog_full) begin
        q_nd_to_rpg_wr_en <= 1'b1;
        qv_nd_to_rpg_data <= iv_nd_from_dp_data;
    end
    else begin
        q_nd_to_rpg_wr_en <= 1'b0;
        qv_nd_to_rpg_data <= qv_nd_to_rpg_data;
    end
end

/**************************************** TimerControl **************************************************/

//-- q_start_timer --
always @(posedge clk or posedge rst) begin 
	if(rst) begin 
		q_start_timer <= 'd0;
	end 
	else if(RTC_cur_state == RTC_RC_SEG_s) begin 
		q_start_timer <= (w_swpb_empty && w_rpb_empty);
	end 
	else if(RTC_next_state == RTC_IDLE_s) begin
		q_start_timer <= 'd0;
	end
	else begin
		q_start_timer <= q_start_timer;
	end 
end  

//-- qv_timer_qpn --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_timer_qpn <= 'd0;
	end 
	else if(RTC_cur_state == RTC_RESP_CXT_s) begin
		qv_timer_qpn <= wv_src_qpn;
	end 
	else begin
		qv_timer_qpn <= qv_timer_qpn;
	end 
end 

//-- q_te_wr_en --
//-- qv_te_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_te_wr_en <= 1'b0;
        qv_te_data <= 'd0;
    end
    else if (RTC_cur_state == RTC_START_TIMER_s && !i_te_prog_full && q_start_timer) begin
        q_te_wr_en <= 1'b1;
        //qv_te_data <= {21'd0, 8'd7, 3'd3, wv_src_qpn, `SET_TIMER};
        qv_te_data <= {21'd0, 8'd7, 3'd3, qv_timer_qpn, `STOP_TIMER};		//Disable time out 
    end
	else begin 
		q_te_wr_en <= 1'b0;
		qv_te_data <= qv_te_data;
	end 
end

/***************************************** CQ Offset Table ********************************************/
//-- q_cq_offset_table_wea --
//-- qv_cq_offset_table_addra --
//-- qv_cq_offset_table_dina --
// always @(posedge clk or posedge rst) begin
//     if (rst) begin
//         q_cq_offset_table_wea <= 1'b0;
//         qv_cq_offset_table_addra <= 'd0;
//         qv_cq_offset_table_dina <= 'd0;        
//     end
//     else if (RTC_cur_state == RTC_FETCH_CXT_s) begin
//         q_cq_offset_table_wea <= 1'b0;
//         qv_cq_offset_table_addra <= wv_src_qpn;
//         qv_cq_offset_table_dina <= 'd0;
//     end
//     else if (RTC_cur_state == RTC_UCUD_CPL_s && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin
//         q_cq_offset_table_wea <= 1'b1;
//         qv_cq_offset_table_addra <= wv_src_qpn;
//         qv_cq_offset_table_dina <= iv_cq_offset_table_douta + `CQE_LENGTH;
//     end
//     else begin
//         q_cq_offset_table_wea <= 1'b0;
//         qv_cq_offset_table_addra <= qv_cq_offset_table_addra;s
//         qv_cq_offset_table_dina <= qv_cq_offset_table_dina;
//     end
// end
//assign wv_cqn = iv_cxtmgt_cxt_data[87:64];
assign wv_cqn = iv_cxtmgt_cxt_data[151:128];
assign o_rtc_req_valid = (RTC_cur_state == RTC_UCUD_CPL_s) && !i_rtc_resp_valid && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full;
assign ov_rtc_cq_index = wv_cqn;
assign ov_rtc_cq_size = wv_scq_length;

/***************************************** MultiQueue TempReg ******************************************/
//Just used to keep data unchanged and avoid generating latch

always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_rpb_list_head_addra_TempReg      <= 'd0;
        qv_rpb_list_head_dina_TempReg       <= 'd0;
        qv_rpb_list_tail_addra_TempReg      <= 'd0;
        qv_rpb_list_tail_dina_TempReg       <= 'd0;
        qv_rpb_list_empty_addra_TempReg     <= 'd0;
        qv_rpb_list_empty_dina_TempReg      <= 'd0;
        qv_rpb_content_addra_TempReg        <= 'd0;
        qv_rpb_content_dina_TempReg         <= 'd0;
        qv_rpb_next_addra_TempReg           <= 'd0;
        qv_rpb_next_dina_TempReg            <= 'd0;
        qv_reb_list_head_addra_TempReg      <= 'd0;
        qv_reb_list_head_dina_TempReg       <= 'd0;
        qv_reb_list_tail_addra_TempReg      <= 'd0;
        qv_reb_list_tail_dina_TempReg       <= 'd0;
        qv_reb_list_empty_addra_TempReg     <= 'd0;
        qv_reb_list_empty_dina_TempReg      <= 'd0;
        qv_reb_content_addra_TempReg        <= 'd0;
        qv_reb_content_dina_TempReg         <= 'd0;
        qv_reb_next_addra_TempReg           <= 'd0;
        qv_reb_next_dina_TempReg            <= 'd0;
        qv_swpb_list_head_addra_TempReg     <= 'd0;
        qv_swpb_list_head_dina_TempReg      <= 'd0;
        qv_swpb_list_tail_addra_TempReg     <= 'd0;
        qv_swpb_list_tail_dina_TempReg      <= 'd0;
        qv_swpb_list_empty_addra_TempReg    <= 'd0;
        qv_swpb_list_empty_dina_TempReg     <= 'd0;
        qv_swpb_content_addra_TempReg       <= 'd0;
        qv_swpb_content_dina_TempReg        <= 'd0;
        qv_swpb_next_addra_TempReg          <= 'd0;
        qv_swpb_next_dina_TempReg           <= 'd0;        
    end
    else begin
        qv_rpb_list_head_addra_TempReg      <= qv_rpb_list_head_addra;
        qv_rpb_list_head_dina_TempReg       <= qv_rpb_list_head_dina;
        qv_rpb_list_tail_addra_TempReg      <= qv_rpb_list_tail_addra;
        qv_rpb_list_tail_dina_TempReg       <= qv_rpb_list_tail_dina;
        qv_rpb_list_empty_addra_TempReg     <= qv_rpb_list_empty_addra;
        qv_rpb_list_empty_dina_TempReg      <= qv_rpb_list_empty_dina;
        qv_rpb_content_addra_TempReg        <= qv_rpb_content_addra;
        qv_rpb_content_dina_TempReg         <= qv_rpb_content_dina;
        qv_rpb_next_addra_TempReg           <= qv_rpb_next_addra;
        qv_rpb_next_dina_TempReg            <= qv_rpb_next_dina;
        qv_reb_list_head_addra_TempReg      <= qv_reb_list_head_addra;
        qv_reb_list_head_dina_TempReg       <= qv_reb_list_head_dina;
        qv_reb_list_tail_addra_TempReg      <= qv_reb_list_tail_addra;
        qv_reb_list_tail_dina_TempReg       <= qv_reb_list_tail_dina;
        qv_reb_list_empty_addra_TempReg     <= qv_reb_list_empty_addra;
        qv_reb_list_empty_dina_TempReg      <= qv_reb_list_empty_dina;
        qv_reb_content_addra_TempReg        <= qv_reb_content_addra;
        qv_reb_content_dina_TempReg         <= qv_reb_content_dina;
        qv_reb_next_addra_TempReg           <= qv_reb_next_addra;
        qv_reb_next_dina_TempReg            <= qv_reb_next_dina;
        qv_swpb_list_head_addra_TempReg     <= qv_swpb_list_head_addra;
        qv_swpb_list_head_dina_TempReg      <= qv_swpb_list_head_dina;
        qv_swpb_list_tail_addra_TempReg     <= qv_swpb_list_tail_addra;
        qv_swpb_list_tail_dina_TempReg      <= qv_swpb_list_tail_dina;
        qv_swpb_list_empty_addra_TempReg    <= qv_swpb_list_empty_addra;
        qv_swpb_list_empty_dina_TempReg     <= qv_swpb_list_empty_dina;
        qv_swpb_content_addra_TempReg       <= qv_swpb_content_addra;
        qv_swpb_content_dina_TempReg        <= qv_swpb_content_dina;
        qv_swpb_next_addra_TempReg          <= qv_swpb_next_addra;
        qv_swpb_next_dina_TempReg           <= qv_swpb_next_dina;
    end
end



always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_DebugCounter_entry_rd_en <= 'd0;
	end 
	else if(q_entry_from_dp_rd_en) begin
		qv_DebugCounter_entry_rd_en <= qv_DebugCounter_entry_rd_en + 1;
	end 
	else begin
		qv_DebugCounter_entry_rd_en <= qv_DebugCounter_entry_rd_en;
	end
end 

/*---------------------------------- connect dbg bus-------------------------------*/
wire   [`DBG_NUM_REQUESTER_TRANS_CONTROL * 32 - 1 : 0]   coalesced_bus;

assign coalesced_bus = {
                            q_flush_finish,
                            q_start_timer,
                            q_absolute_addr,
                            q_relative_addr,
                            q_mthca_mpt_flag_mio,
                            q_mthca_mpt_flag_bind_enable,
                            q_mthca_mpt_flag_physical,
                            q_mthca_mpt_flag_region,
                            q_ibv_access_on_demand,
                            q_ibv_access_zero_based,
                            q_ibv_access_mw_bind,
                            q_ibv_access_remote_atomic,
                            q_ibv_access_remote_read,
                            q_ibv_access_remote_write,
                            q_ibv_access_local_write,
                            w_fence,
                            w_rc_msg_can_be_sent,
                            w_read_allowed,
                            w_write_allowed,
                            w_atomics_allowed,
                            w_send_allowed,
                            w_pkt_allowed,
                            w_rpb_empty,
                            w_reb_empty,
                            w_swpb_empty,
                            wv_swpb_head,
                            wv_swpb_tail,
                            qv_timer_qpn,
                            wv_cqn,
                            wv_src_qpn,
                            wv_dst_qpn,
                            qv_left_payload_counter,
                            qv_DebugCounter_entry_rd_en,
                            qv_my_qpn,
                            qv_my_ee,
                            qv_rqpn,
                            qv_imm_etype_pkey_eec,
                            qv_byte_cnt,
                            qv_wqe,
                            qv_vtp_pd,
                            qv_vtp_lkey,
                            qv_vtp_length,
                            wv_imm,
                            wv_scq_pd,
                            wv_scq_lkey,
                            wv_scq_length,
                            wv_qkey,
                            wv_msg_size,
                            wv_cur_wqe_offset,
                            wv_vtp_flags,
                            wv_dst_IP,
                            qv_rlid,
                            qv_sl_g_mlpath,
                            qv_vtp_type,
                            qv_vtp_opcode,
                            qv_mthca_mpt_flag_sw_owns,
                            wv_err_type,
                            qv_owner,
                            qv_is_send,
                            qv_opcode,
                            qv_vendor_err,
                            qv_syndrome,
                            qv_vtp_vaddr,
                            qv_PMTU_fwd,
                            qv_err_point,
                            wv_PKey,
                            wv_ser,
                            wv_opcode,
                            wv_legal_entry,
                            wv_qp_state,
                            wv_rpb_head,
                            wv_rpb_tail,
                            wv_reb_head,
                            wv_reb_tail,
                            wv_RETH,
                            wv_DETH,
                            wv_dst_LID_MAC,
                            wv_rlid
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
                    (dbg_sel == 42) ?   coalesced_bus[32 * 43 - 1 : 32 * 42] : 32'd0;

//assign dbg_bus = coalesced_bus;

reg             [31:0]          pkt_header_cnt;
reg             [31:0]          pkt_payload_cnt;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        pkt_payload_cnt <= 'd0;
    end 
    else if(o_nd_to_rpg_wr_en) begin
        pkt_payload_cnt <= pkt_payload_cnt + 'd1;
    end 
    else begin
        pkt_payload_cnt <= pkt_payload_cnt;
    end 
end 

always @(posedge clk or posedge rst) begin
    if(rst) begin
        pkt_header_cnt <= 'd0;
    end 
    else if(o_header_to_rpg_wr_en) begin
        pkt_header_cnt <= pkt_header_cnt + 'd1;
    end 
    else begin
        pkt_header_cnt <= pkt_header_cnt;
    end 
end 

//ila_counter_probe ila_counter_probe_inst(
//    .clk(clk),
//    .probe0(pkt_header_cnt),
//    .probe1(pkt_payload_cnt)
//);

endmodule
