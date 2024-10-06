`timescale 1ns / 1ps

`include "ib_constant_def_h.vh"
`include "msg_def_v2p_h.vh"
`include "msg_def_ctxmgt_h.vh"
`include "sw_hw_interface_const_def_h.vh"
`include "nic_hw_params.vh"

module RequesterRecvControl
#(
    parameter       RW_REG_NUM = 4
)
(    //"rrc" for short
    input   wire                clk,
    input   wire                rst,

	input 	wire 	[RW_REG_NUM * 32 - 1 : 0]	rw_data,
	output 	wire 	[RW_REG_NUM * 32 - 1 : 0]	init_rw_data,

//Interface with TimerControl
    output  wire                o_rc_te_loss_wr_en,
    output  wire    [63:0]      ov_rc_te_loss_data,
    input   wire                i_rc_te_loss_prog_full,

    output  wire                o_rc_te_rnr_wr_en,
    output  wire    [63:0]      ov_rc_te_rnr_data,
    input   wire                i_rc_te_rnr_prog_full,

    input   wire                i_loss_expire_empty,
    input   wire    [31:0]      iv_loss_expire_data,
    output  wire                o_loss_expire_rd_en,

    input   wire                i_rnr_expire_empty,
    input   wire    [31:0]      iv_rnr_expire_data,
    output  wire                o_rnr_expire_rd_en,

//TransControl
    input   wire                i_br_empty,
    output  wire                o_br_rd_en,
    input   wire    [127:0]      iv_br_data,

//MultiQueue
    //Read Packet Buffer 
    output  wire                o_rpb_list_head_web,
    output  wire    [13:0]      ov_rpb_list_head_addrb,
    output  wire    [8:0]       ov_rpb_list_head_dinb,
    input   wire    [8:0]       iv_rpb_list_head_doutb,

    output  wire                o_rpb_list_tail_web,
    output  wire    [13:0]      ov_rpb_list_tail_addrb,
    output  wire    [8:0]       ov_rpb_list_tail_dinb,
    input   wire    [8:0]       iv_rpb_list_tail_doutb,

    output  wire                o_rpb_list_empty_web,
    output  wire    [13:0]      ov_rpb_list_empty_addrb,
    output  wire    [0:0]       ov_rpb_list_empty_dinb,
    input   wire    [0:0]       iv_rpb_list_empty_doutb,

    output  wire                o_rpb_content_web,
    output  wire    [8:0]       ov_rpb_content_addrb,
    output  wire    [261:0]     ov_rpb_content_dinb,
    input   wire    [261:0]     iv_rpb_content_doutb,

    output  wire                o_rpb_next_web,
    output  wire    [8:0]       ov_rpb_next_addrb,
    output  wire    [9:0]       ov_rpb_next_dinb,
    input   wire    [9:0]       iv_rpb_next_doutb,

    output  wire    [8:0]       ov_rpb_free_data,
    output  wire                o_rpb_free_wr_en,
    input   wire                i_rpb_free_prog_full,

    //Read Entry Buffer
    output  wire                o_reb_list_head_web,
    output  wire    [13:0]      ov_reb_list_head_addrb,
    output  wire    [13:0]      ov_reb_list_head_dinb,
    input   wire    [13:0]      iv_reb_list_head_doutb,

    output  wire                o_reb_list_tail_web,
    output  wire    [13:0]      ov_reb_list_tail_addrb,
    output  wire    [13:0]      ov_reb_list_tail_dinb,
    input   wire    [13:0]      iv_reb_list_tail_doutb,

    output  wire                o_reb_list_empty_web,
    output  wire    [13:0]      ov_reb_list_empty_addrb,
    output  wire    [0:0]       ov_reb_list_empty_dinb,
    input   wire    [0:0]       iv_reb_list_empty_doutb,

    output  wire                o_reb_content_web,
    output  wire    [13:0]      ov_reb_content_addrb,
    output  wire    [127:0]     ov_reb_content_dinb,
    input   wire    [127:0]     iv_reb_content_doutb,

    output  wire                o_reb_next_web,
    output  wire    [13:0]      ov_reb_next_addrb,
    output  wire    [14:0]      ov_reb_next_dinb,
    input   wire    [14:0]      iv_reb_next_doutb,

    output  wire    [13:0]      ov_reb_free_data,
    output  wire                o_reb_free_wr_en,
    input   wire                i_reb_free_prog_full,

    //Send/Write Packet Buffer
    output  wire                o_swpb_list_head_web,
    output  wire    [13:0]      ov_swpb_list_head_addrb,
    output  wire    [11:0]      ov_swpb_list_head_dinb,
    input   wire    [11:0]      iv_swpb_list_head_doutb,

    output  wire                o_swpb_list_tail_web,
    output  wire    [13:0]      ov_swpb_list_tail_addrb,
    output  wire    [11:0]      ov_swpb_list_tail_dinb,
    input   wire    [11:0]      iv_swpb_list_tail_doutb,

    output  wire                o_swpb_list_empty_web,
    output  wire    [13:0]      ov_swpb_list_empty_addrb,
    output  wire    [0:0]       ov_swpb_list_empty_dinb,
    input   wire    [0:0]       iv_swpb_list_empty_doutb,

    output  wire    [11:0]      ov_swpb_content_addrb,
    output  wire    [287:0]     ov_swpb_content_dinb,
    input   wire    [287:0]     iv_swpb_content_doutb,
    output  wire                o_swpb_content_web,

    output  wire    [11:0]      ov_swpb_next_addrb,
    output  wire    [12:0]      ov_swpb_next_dinb,
    input   wire    [12:0]      iv_swpb_next_doutb,
    output  wire                o_swpb_next_web,

    output  wire    [11:0]      ov_swpb_free_data,
    output  wire                o_swpb_free_wr_en,
    input   wire                i_swpb_free_prog_full,

//CQ Offset Table
    // output  wire    [0:0]       o_cq_offset_table_web,
    // output  wire    [13:0]      ov_cq_offset_table_addrb,
    // output  wire    [15:0]      ov_cq_offset_table_dinb,
    // input   wire    [15:0]      iv_cq_offset_table_doutb,
    output   wire                o_rrc_req_valid,
    output   wire    [23:0]      ov_rrc_cq_index,
    output   wire    [31:0]       ov_rrc_cq_size,
    input  wire                i_rrc_resp_valid,
    input  wire     [23:0]     iv_rrc_cq_offset,

//Header Parser
    input   wire                i_header_from_hp_empty,
    output  wire                o_header_from_hp_rd_en,
    input   wire    [239:0]     iv_header_from_hp_data,

    input   wire    [255:0]     iv_nd_from_hp_data,
    input   wire                i_nd_from_hp_empty,
    output  wire                o_nd_from_hp_rd_en,

//ReqPktGen
    input   wire                i_header_to_rpg_prog_full,
    output  wire                o_header_to_rpg_wr_en,
    output  wire    [319:0]     ov_header_to_rpg_data,

    input   wire                i_nd_to_rpg_prog_full,
    output  wire                o_nd_to_rpg_wr_en,
    output  wire    [255:0]     ov_nd_to_rpg_data,

//CxtMgt
    output  wire                o_cxtmgt_cmd_wr_en,
    input   wire                i_cxtmgt_cmd_prog_full,
    output  wire    [127:0]     ov_cxtmgt_cmd_data,

    input   wire                i_cxtmgt_resp_empty,
    output  wire                o_cxtmgt_resp_rd_en,
    input   wire    [127:0]     iv_cxtmgt_resp_data,

    input   wire                i_cxtmgt_cxt_empty,
    output  wire                o_cxtmgt_cxt_rd_en,
    // input   wire    [127:0]     iv_cxtmgt_cxt_data,
    input   wire    [255:0]     iv_cxtmgt_cxt_data,

    output  wire                o_cxtmgt_cxt_wr_en,
    input   wire                i_cxtmgt_cxt_prog_full,
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

    input   wire    [31:0]      dbg_sel,
    output  wire    [32 - 1 :0]      dbg_bus,
    //output  wire    [`DBG_NUM_REQUESTER_RECV_CONTROL * 32 - 1 :0]      dbg_bus,

	output 	wire 				o_rrc_init_finish
);


/*----------------------------------------  Part 1: Signals Definition and Submodules Connection ----------------------------------------*/
//For CPL byte_cnt field
reg                     q_bc_wea;
reg     [13:0]          qv_bc_addra;
reg     [31:0]         qv_bc_dina;
reg     [13:0]          qv_bc_addrb;
wire    [31:0]         wv_bc_doutb;
wire    [31:0]         wv_bc_doutb_fake;

reg 					q_bc_wea_TempReg;
reg     [13:0]          qv_bc_addra_TempReg;
reg     [31:0]         qv_bc_dina_TempReg;
reg     [13:0]          qv_bc_addrb_TempReg;

BRAM_SDP_32w_16384d ByteCount_Table(      //Byte Cnt
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[0 * 32 + 1 : 0 * 32 + 0]),
	.WTSEL( rw_data[0 * 32 + 3 : 0 * 32 + 2]),
	.PTSEL( rw_data[0 * 32 + 5 : 0 * 32 + 4]),
	.VG(    rw_data[0 * 32 + 6 : 0 * 32 + 6]),
	.VS(    rw_data[0 * 32 + 7 : 0 * 32 + 7]),

  `endif

  .clka(clk),    
  .ena(1'b1),      
  .wea(q_bc_wea),      
  .addra(qv_bc_addra),  
  .dina(qv_bc_dina),    
  .clkb(clk),    
  .enb(1'b1),      
  .addrb(qv_bc_addrb),  
  .doutb(wv_bc_doutb_fake)  
);

assign wv_bc_doutb = ((q_bc_wea_TempReg == 1'b1) && (qv_bc_addra_TempReg == qv_bc_addrb_TempReg)) ? qv_bc_dina_TempReg : wv_bc_doutb_fake; 

always @(posedge clk or posedge rst) begin
	if(rst) begin
		q_bc_wea_TempReg <= 'd0;
		qv_bc_addra_TempReg <= 'd0;
		qv_bc_dina_TempReg <= 'd0;
		qv_bc_addrb_TempReg <= 'd0;
	end 
	else begin
		q_bc_wea_TempReg <= q_bc_wea;
		qv_bc_addra_TempReg <= qv_bc_addra;
		qv_bc_dina_TempReg <= qv_bc_dina;
		qv_bc_addrb_TempReg <= qv_bc_addrb;
	end 
end 


wire        w_gen_cpl_during_release;
wire        w_gen_cpl_during_flush;

reg                q_rrc_req_valid;
reg    [23:0]      qv_rrc_cq_index;
reg    [31:0]       qv_rrc_cq_size;

assign o_rrc_req_valid = q_rrc_req_valid;
assign ov_rrc_cq_index = qv_rrc_cq_index;
assign ov_rrc_cq_size = qv_rrc_cq_size;

reg 						q_rpb_retrans_finish;
reg 						q_swpb_retrans_finish;

reg 	    [11:0]      	qv_swpb_content_addrb_TempReg;
reg 	    [11:0]      	qv_swpb_next_addrb_TempReg;
reg 	    [8:0]       	qv_rpb_content_addrb_TempReg;
reg 	    [8:0]       	qv_rpb_next_addrb_TempReg;
reg 	                	q_rc_te_loss_wr_en;
reg 	    [63:0]      	qv_rc_te_loss_data;

reg 	                	q_rc_te_rnr_wr_en;
reg 	    [63:0]      	qv_rc_te_rnr_data;
reg 	                	q_loss_expire_rd_en;
reg 	                	q_rnr_expire_rd_en;
reg 	                	q_br_rd_en;

//Read Packet Buffer 
reg    		             	q_rpb_list_head_web;
reg    		[13:0]       	qv_rpb_list_head_addrb;
reg    		[9:0]        	qv_rpb_list_head_dinb;
reg    		             	q_rpb_list_tail_web;
reg    		[13:0]       	qv_rpb_list_tail_addrb;
reg    		[9:0]        	qv_rpb_list_tail_dinb;
reg    		             	q_rpb_list_empty_web;
reg    		[13:0]       	qv_rpb_list_empty_addrb;
reg    		[0:0]        	qv_rpb_list_empty_dinb;
reg    		             	q_rpb_content_web;
reg    		[8:0]        	qv_rpb_content_addrb;
reg    		[229:0]      	qv_rpb_content_dinb;
reg    		             	q_rpb_next_web;
reg    		[8:0]        	qv_rpb_next_addrb;
reg    		[9:0]        	qv_rpb_next_dinb;
reg    		[9:0]        	qv_rpb_free_data;
reg    		             	q_rpb_free_wr_en;

//Send/Write Packet Buffer
reg    		             	q_swpb_list_head_web;
reg    		[13:0]       	qv_swpb_list_head_addrb;
reg    		[11:0]       	qv_swpb_list_head_dinb;
reg    		             	q_swpb_list_tail_web;
reg    		[13:0]       	qv_swpb_list_tail_addrb;
reg    		[11:0]       	qv_swpb_list_tail_dinb;
reg    		             	q_swpb_list_empty_web;
reg    		[13:0]       	qv_swpb_list_empty_addrb;
reg    		[0:0]        	qv_swpb_list_empty_dinb;
reg    		[11:0]       	qv_swpb_content_addrb;
reg    		[255:0]      	qv_swpb_content_dinb;
reg    		             	q_swpb_content_web;
reg    		[11:0]       	qv_swpb_next_addrb;
reg    		[12:0]       	qv_swpb_next_dinb;
reg    		             	q_swpb_next_web;
reg    		[11:0]       	qv_swpb_free_data;
reg    		             	q_swpb_free_wr_en;
         
reg     	[31:0]          qv_rpb_list_table_init_counter;
reg     	[31:0]          qv_swpb_list_table_init_counter;
reg 		[31:0]			qv_bc_table_init_counter;
        	 
reg     	            	q_header_from_hp_rd_en;          
reg     	            	q_nd_from_hp_rd_en;

reg     	            	q_header_to_rpg_wr_en;
reg     	[319:0]     	qv_header_to_rpg_data;

reg     	            	q_nd_to_rpg_wr_en;
reg     	[255:0]     	qv_nd_to_rpg_data;

reg     	            	q_cxtmgt_cmd_wr_en;    
reg     	[127:0]     	qv_cxtmgt_cmd_data;
reg     	            	q_cxtmgt_resp_rd_en;         
reg     	            	q_cxtmgt_cxt_rd_en;
reg     	            	q_cxtmgt_cxt_wr_en;    
reg     	[127:0]     	qv_cxtmgt_cxt_data;

reg     	            	q_vtp_cmd_wr_en;         
reg     	[255:0]     	qv_vtp_cmd_data;   
reg     	            	q_vtp_resp_rd_en;
reg     	            	q_vtp_upload_wr_en;      
reg     	[255:0]     	qv_vtp_upload_data;

//reg     	[0:0]       	q_cq_offset_table_web;
//reg     	[13:0]      	qv_cq_offset_table_addrb;
//reg     	[15:0]      	qv_cq_offset_table_dinb;
//
//reg     	[0:0]       	q_cq_offset_table_web_TempReg;
//reg     	[13:0]      	qv_cq_offset_table_addrb_TempReg;
//reg     	[15:0]      	qv_cq_offset_table_dinb_TempReg;


assign o_rc_te_loss_wr_en = q_rc_te_loss_wr_en;
assign ov_rc_te_loss_data = qv_rc_te_loss_data;

assign o_rc_te_rnr_wr_en = q_rc_te_rnr_wr_en;
assign ov_rc_te_rnr_data = qv_rc_te_rnr_data;
            
assign o_loss_expire_rd_en = q_loss_expire_rd_en;
            
assign o_rnr_expire_rd_en = q_rnr_expire_rd_en;
assign o_br_rd_en = q_br_rd_en;

//Read Packet Buffer 
assign o_rpb_list_head_web = q_rpb_list_head_web;
assign ov_rpb_list_head_addrb = qv_rpb_list_head_addrb;
assign ov_rpb_list_head_dinb = qv_rpb_list_head_dinb;
assign o_rpb_list_tail_web = q_rpb_list_tail_web;
assign ov_rpb_list_tail_addrb = qv_rpb_list_tail_addrb;
assign ov_rpb_list_tail_dinb = qv_rpb_list_tail_dinb;
assign o_rpb_list_empty_web = q_rpb_list_empty_web;
assign ov_rpb_list_empty_addrb = qv_rpb_list_empty_addrb;
assign ov_rpb_list_empty_dinb = qv_rpb_list_empty_dinb;
assign o_rpb_content_web = q_rpb_content_web;
assign ov_rpb_content_addrb = qv_rpb_content_addrb;
assign ov_rpb_content_dinb = qv_rpb_content_dinb;
assign o_rpb_next_web = q_rpb_next_web;
assign ov_rpb_next_addrb = qv_rpb_next_addrb;
assign ov_rpb_next_dinb = qv_rpb_next_dinb;
assign ov_rpb_free_data = qv_rpb_free_data;
assign o_rpb_free_wr_en = q_rpb_free_wr_en;

//Send/Write Packet Buffer
assign o_swpb_list_head_web = q_swpb_list_head_web;
assign ov_swpb_list_head_addrb = qv_swpb_list_head_addrb;
assign ov_swpb_list_head_dinb = qv_swpb_list_head_dinb;
assign o_swpb_list_tail_web = q_swpb_list_tail_web;
assign ov_swpb_list_tail_addrb = qv_swpb_list_tail_addrb;
assign ov_swpb_list_tail_dinb = qv_swpb_list_tail_dinb;
assign o_swpb_list_empty_web = q_swpb_list_empty_web;
assign ov_swpb_list_empty_addrb = qv_swpb_list_empty_addrb;
assign ov_swpb_list_empty_dinb = qv_swpb_list_empty_dinb;
assign ov_swpb_content_addrb = qv_swpb_content_addrb;
assign ov_swpb_content_dinb = qv_swpb_content_dinb;
assign o_swpb_content_web = q_swpb_content_web;
assign ov_swpb_next_addrb = qv_swpb_next_addrb;
assign ov_swpb_next_dinb = qv_swpb_next_dinb;
assign o_swpb_next_web = q_swpb_next_web;
assign ov_swpb_free_data = qv_swpb_free_data;
assign o_swpb_free_wr_en = q_swpb_free_wr_en;
            
assign o_header_from_hp_rd_en = q_header_from_hp_rd_en;
assign o_nd_from_hp_rd_en = q_nd_from_hp_rd_en;

assign o_header_to_rpg_wr_en = q_header_to_rpg_wr_en;
assign ov_header_to_rpg_data = qv_header_to_rpg_data;

assign o_nd_to_rpg_wr_en = q_nd_to_rpg_wr_en;
assign ov_nd_to_rpg_data = qv_nd_to_rpg_data;

assign o_cxtmgt_cmd_wr_en = q_cxtmgt_cmd_wr_en;
assign ov_cxtmgt_cmd_data = qv_cxtmgt_cmd_data;
assign o_cxtmgt_resp_rd_en = q_cxtmgt_resp_rd_en;
assign o_cxtmgt_cxt_rd_en = q_cxtmgt_cxt_rd_en;
assign o_cxtmgt_cxt_wr_en  = q_cxtmgt_cxt_wr_en;  
assign ov_cxtmgt_cxt_data = qv_cxtmgt_cxt_data;

assign o_vtp_cmd_wr_en = q_vtp_cmd_wr_en; 
assign ov_vtp_cmd_data = qv_vtp_cmd_data;
assign o_vtp_resp_rd_en = q_vtp_resp_rd_en;
assign o_vtp_upload_wr_en = q_vtp_upload_wr_en;
assign ov_vtp_upload_data = qv_vtp_upload_data;

//assign o_cq_offset_table_web = q_cq_offset_table_web;
//assign ov_cq_offset_table_addrb = qv_cq_offset_table_addrb;
//assign ov_cq_offset_table_dinb = qv_cq_offset_table_dinb;

//Scatter Entry Manager inner interface
reg     [159:0]     qv_sem_cmd_din;
reg                 q_sem_cmd_wr_en;
wire 						w_sem_init_finish;
wire	     				w_cur_read_finish;
wire                w_sem_cmd_rd_en;
wire    [159:0]     wv_sem_cmd_dout;
wire                w_sem_cmd_empty;
wire                w_sem_cmd_prog_full;
wire    [159:0]     wv_sem_resp_din;
wire                w_sem_resp_wr_en;
reg                 q_sem_resp_rd_en;
wire    [159:0]     wv_sem_resp_dout;
wire                w_sem_resp_empty;
wire                w_sem_resp_prog_full;
CmdResp_FIFO_160w_4d SEM_CMD_FIFO(
    `ifdef CHIP_VERSION
	.RTSEL( rw_data[1 * 32 + 1 : 1 * 32 + 0]),
	.WTSEL( rw_data[1 * 32 + 3 : 1 * 32 + 2]),
	.PTSEL( rw_data[1 * 32 + 5 : 1 * 32 + 4]),
	.VG(    rw_data[1 * 32 + 6 : 1 * 32 + 6]),
	.VS(    rw_data[1 * 32 + 7 : 1 * 32 + 7]),
  `endif

  .clk(clk),              
  .srst(rst),            
  .din(qv_sem_cmd_din),              
  .wr_en(q_sem_cmd_wr_en),          
  .rd_en(w_sem_cmd_rd_en),          
  .dout(wv_sem_cmd_dout),            
  .full(),            
  .empty(w_sem_cmd_empty),          
  .prog_full(w_sem_cmd_prog_full)  
);

CmdResp_FIFO_160w_4d SEM_RESP_FIFO(
    `ifdef CHIP_VERSION
	.RTSEL( rw_data[2 * 32 + 1 : 2 * 32 + 0]),
	.WTSEL( rw_data[2 * 32 + 3 : 2 * 32 + 2]),
	.PTSEL( rw_data[2 * 32 + 5 : 2 * 32 + 4]),
	.VG(    rw_data[2 * 32 + 6 : 2 * 32 + 6]),
	.VS(    rw_data[2 * 32 + 7 : 2 * 32 + 7]),
  `endif

  .clk(clk),              
  .srst(rst),            
  .din(wv_sem_resp_din),              
  .wr_en(w_sem_resp_wr_en),          
  .rd_en(q_sem_resp_rd_en),          
  .dout(wv_sem_resp_dout),            
  .full(),            
  .empty(w_sem_resp_empty),          
  .prog_full(w_sem_resp_prog_full) 
);

wire        [32 - 1 : 0]           wv_sem_dbg_bus;
//wire        [`DBG_NUM_SCATTERENTRY_MANAGER * 32 - 1 : 0]           wv_sem_dbg_bus;
ScatterEntryManager ScatterEntryManager_Inst(
    .clk(clk),
    .rst(rst),

//Interface with MultiQueue
    .ov_reb_list_head_addrb(ov_reb_list_head_addrb),
    .ov_reb_list_head_dinb(ov_reb_list_head_dinb),
    .iv_reb_list_head_doutb(iv_reb_list_head_doutb),
    .o_reb_list_head_web(o_reb_list_head_web),

    .ov_reb_list_tail_addrb(ov_reb_list_tail_addrb),
    .ov_reb_list_tail_dinb(ov_reb_list_tail_dinb),
    .iv_reb_list_tail_doutb(iv_reb_list_tail_doutb),
    .o_reb_list_tail_web(o_reb_list_tail_web),

    .ov_reb_list_empty_addrb(ov_reb_list_empty_addrb),
    .ov_reb_list_empty_dinb(ov_reb_list_empty_dinb),
    .iv_reb_list_empty_doutb(iv_reb_list_empty_doutb),
    .o_reb_list_empty_web(o_reb_list_empty_web),

    .ov_reb_content_addrb(ov_reb_content_addrb),
    .ov_reb_content_dinb(ov_reb_content_dinb),
    .iv_reb_content_doutb(iv_reb_content_doutb),
    .o_reb_content_web(o_reb_content_web),

    .ov_reb_next_addrb(ov_reb_next_addrb),
    .ov_reb_next_dinb(ov_reb_next_dinb),
    .iv_reb_next_doutb(iv_reb_next_doutb),
    .o_reb_next_web(o_reb_next_web),

    .ov_reb_free_data(ov_reb_free_data),
    .o_reb_free_wr_en(o_reb_free_wr_en),
    .i_reb_free_prog_full(i_reb_free_prog_full),

//Inner connections to RequesterRecvControl
    .i_cmd_empty(w_sem_cmd_empty),
    .o_cmd_rd_en(w_sem_cmd_rd_en),
    .iv_cmd_data(wv_sem_cmd_dout),

    .i_resp_prog_full(w_sem_resp_prog_full),
    .o_resp_wr_en(w_sem_resp_wr_en),
    .ov_resp_data(wv_sem_resp_din),

    .dbg_sel(dbg_sel - 32'd142),
    .dbg_bus(wv_sem_dbg_bus),

	.o_sem_init_finish(w_sem_init_finish)
);

//BTH 
wire    [15:0]          wv_PKey;
wire    [1:0]           wv_pad_count;
wire    [2:0]           wv_service_type;
wire    [4:0]           wv_opcode;
wire    [13:0]          wv_PktQPN;
wire    [23:0]          wv_ReceivedPSN; 
    //Payload length
wire    [12:0]          wv_length;

    //These fields are not used
// wire    [0:0]           wv_solicited_event;
// wire    [0:0]           wv_becn;
// wire    [0:0]           wv_fecn;
// wire    [0:0]           wv_req_ack; 
// wire    [0:0]           wv_migration;
// wire    [3:0]           wv_TVer;

reg     [12:0]          qv_pkt_left_length;

//AETH
wire    [23:0]          wv_msn;
wire    [7:0]           wv_syndrome;
wire    [1:0]           wv_syndrome_high2;
wire    [4:0]           wv_syndrome_low5;

//reg     [23:0]          qv_UnAckedPSN;

wire    [23:0]          wv_UnAckedPSN;
wire    [2:0]           wv_qp_state;

wire    [23:0]          wv_NextPSN;
wire    [31:0]          wv_CQ_LKey;
wire    [31:0]          wv_QP_PD;
wire    [31:0]          wv_CQ_PD;
wire    [23:0]          wv_cqn;
wire 	[31:0]			wv_cq_length;
wire 	[23:0]			wv_rqpn;



wire    [7:0]           wv_loss_timer_event;
wire    [7:0]           wv_rnr_timer_event;

wire                    w_new_event;
// wire    [4:0]           wv_UPSN_pkt_opcode;

reg                     q_sch_flag_1;
reg                     q_sch_flag_2;
reg     [2:0]           qv_event_num;

reg     [23:0]          qv_cur_event_QPN;

reg 	[23:0]			qv_PSN_incr_for_read;

reg     [3:0]           qv_sub_state;

wire                    w_pending_read;
wire    [23:0]          wv_loss_timer_QPN;
wire    [23:0]          wv_rnr_timer_QPN;
wire    [23:0]          wv_bad_req_QPN;

wire                    w_entry_valid;
wire    [63:0]          wv_entry_va;
wire    [31:0]          wv_entry_key;
wire    [31:0]          wv_entry_length;

reg    [63:0]          qv_entry_va;
reg    [31:0]          qv_entry_key;
reg    [31:0]          qv_entry_length;

wire                    w_pkt_drop_finish;
wire                    w_pending_send_write;

wire    [9:0]           wv_rpb_head; 
wire    [9:0]           wv_rpb_tail;
wire                    w_rpb_empty;

wire    [11:0]          wv_swpb_head;
wire    [11:0]          wv_swpb_tail;
wire                    w_swpb_empty;


//For release
wire                    w_release_finish;
reg     [23:0]          qv_release_curPSN;
reg 	[4:0]			qv_release_curOP;
reg 	[4:0]			qv_release_curOP_TempReg;
reg     [12:0]          qv_release_PktLeftLen;
wire                    w_cur_release_is_read;
wire    [12:0]          wv_release_curPktLen;
reg     [7:0]           qv_release_counter;
reg     [23:0]          qv_release_upper_bound;


//For retrans 
wire                    w_retrans_finish;
reg     [23:0]          qv_retrans_curPSN;
reg     [12:0]          qv_retrans_PktLeftLen;
reg                    q_cur_retrans_is_read;
reg                    q_cur_retrans_is_read_TempReg;
wire    [12:0]          wv_retrans_curPktLen;
reg     [7:0]           qv_retrans_counter;
reg     [23:0]          qv_retrans_upper_bound;

//For Flush
wire                    w_flush_finish;
reg     [23:0]          qv_flush_curPSN;
reg 	[4:0]			qv_flush_curOP;
reg 	[4:0]			qv_flush_curOP_TempReg;
reg     [12:0]          qv_flush_PktLeftLen;
wire                    w_cur_flush_is_read;
wire    [12:0]          wv_flush_curPktLen;
reg     [7:0]           qv_flush_counter;
reg     [23:0]          qv_flush_upper_bound;

reg                 q_cur_flush_is_read;

wire    [23:0]          wv_oldest_read_PSN;
wire    [23:0]          wv_oldest_send_write_PSN;

reg     [31:0]          qv_mandatory_counter;

reg     [31:0]          qv_cur_entry_left_length;
reg     [255:0]         qv_unwritten_data;
reg     [5:0]           qv_unwritten_len;       //Will not exceed 32


reg     [15:0]          qv_rpb_free_init_counter;
reg     [15:0]          qv_swpb_free_init_counter;

reg 	[31:0]			qv_rpb_next_table_init_counter;
reg 	[31:0]			qv_swpb_next_table_init_counter;

wire                    w_cpl_can_be_upload;

//This flag is used to indicate a uncommon case:
//The last unacked Req is read, some read responses have be received and scattered, but some are not.
//Considering the following case, where k is the number of exepected read responses
// UnAckedReq  | Read | Write First | Write Middle | Write Middle | Write Middle | Write Last | Write Only |   ... ...  |
// PSN         | n    | n + k       | n + k + 1    | n + k + 2    | n + k + 3    | n + k + 4  | n + k + 5  |   ... ...  |
// When we receive a Read Response with a ACK lay in (n, n + k - 1], it indicates that we have a read half-processed
wire                    w_unfinished_read;     
assign w_unfinished_read = 1'b0;

/*----------------------------------------  Part 2: State Machine Transition ------------------------------------------------------------*/
reg 	[4:0]			RRC_pre_state;
reg     [4:0]           RRC_cur_state;
reg     [4:0]           RRC_next_state;

parameter       [4:0]
                RRC_INIT_s                  = 5'd1,   
                RRC_IDLE_s                  = 5'd2,
                //Cxt-Related
                RRC_FETCH_CXT_s             = 5'd3,
                RRC_RESP_CXT_s              = 5'd4,
                RRC_CXT_WB_s                = 5'd5,
                //Release and Retrans
                RRC_RELEASE_s               = 5'd6,
                RRC_RETRANS_s               = 5'd7,                  
                //Timer-Related
                RRC_RESET_TIMER_s           = 5'd8,
                RRC_CLEAR_TIMER_s           = 5'd9,
                //RDMA Read-Related
                RRC_FETCH_ENTRY_s           = 5'd10,
                RRC_RESP_ENTRY_s            = 5'd11,
                RRC_SCATTER_CMD_s           = 5'd12,
                RRC_SCATTER_DATA_s          = 5'd13,
                RRC_UPDATE_ENTRY_s          = 5'd14,
                RRC_RELEASE_ENTRY_s         = 5'd15,
                RRC_READ_COMPLETION_s       = 5'd16,
                //Err-Related
                RRC_BAD_REQ_s               = 5'd17,
                RRC_WQE_FLUSH_s          	= 5'd18,
                RRC_PKT_FLUSH_s             = 5'd19,
                //Drop
                RRC_SILENT_DROP_s           = 5'd20;


always @(posedge clk or posedge rst) begin
    if (rst) begin
        RRC_cur_state <= RRC_INIT_s;
		RRC_pre_state <= RRC_INIT_s;
    end
    else begin
        RRC_cur_state <= RRC_next_state;
		RRC_pre_state <= RRC_cur_state;
    end
end

always @(*) begin
    case(RRC_cur_state)
        RRC_INIT_s:             if(qv_rpb_free_init_counter == `RPB_CONTENT_FREE_NUM - 1 && qv_swpb_free_init_counter == `SWPB_CONTENT_FREE_NUM - 1 &&
                                    qv_rpb_list_table_init_counter == `QP_NUM - 1 && qv_swpb_list_table_init_counter == `QP_NUM - 1 && qv_bc_table_init_counter == `QP_NUM - 1 && qv_rpb_next_table_init_counter == `RPB_CONTENT_FREE_NUM - 1 && qv_swpb_next_table_init_counter == `SWPB_CONTENT_FREE_NUM - 1) begin
                                    RRC_next_state = RRC_IDLE_s;
                                end
                                else begin
                                    RRC_next_state = RRC_INIT_s;
                                end
        RRC_IDLE_s:             if(w_new_event) begin
                                    RRC_next_state = RRC_FETCH_CXT_s;
                                end
                                else begin
                                    RRC_next_state = RRC_IDLE_s;
                                end
        RRC_FETCH_CXT_s:        if(!i_cxtmgt_cmd_prog_full) begin
                                    RRC_next_state = RRC_RESP_CXT_s;                                
                                end
                                else begin
                                    RRC_next_state = RRC_FETCH_CXT_s;
                                end
        RRC_RESP_CXT_s:         if(!i_cxtmgt_resp_empty && !i_cxtmgt_cxt_empty && qv_mandatory_counter >= `MANDATORY_TIME && !i_cxtmgt_cmd_prog_full && !i_cxtmgt_cxt_prog_full) begin
                                    //if(wv_qp_state == `QP_ERR && (w_pending_send_write || w_pending_read)) begin 
                                    if(wv_qp_state == `QP_ERR && (!w_rpb_empty || !w_swpb_empty)) begin 
                                        RRC_next_state = RRC_WQE_FLUSH_s;
                                    end 
                                    else if(qv_event_num == `LOSS_TIMER_EVENT) begin 
                                        if(wv_loss_timer_event == `TIMER_EXPIRED) begin
                                            RRC_next_state = RRC_RETRANS_s;
                                        end
                                        else if (wv_loss_timer_event == `COUNTER_EXCEEDED) begin
                                            RRC_next_state = RRC_WQE_FLUSH_s;
                                        end
                                        else begin
                                            RRC_next_state = RRC_IDLE_s;
                                        end
                                    end
                                    else if(qv_event_num == `RNR_TIMER_EVENT) begin
                                        if(wv_rnr_timer_event == `TIMER_EXPIRED) begin
                                            RRC_next_state = RRC_RETRANS_s;
                                        end
                                        else if (wv_rnr_timer_event == `COUNTER_EXCEEDED) begin
                                            RRC_next_state = RRC_WQE_FLUSH_s;
                                        end
                                        else begin
                                            RRC_next_state = RRC_IDLE_s;
                                        end
                                    end
                                    else if(qv_event_num == `BAD_REQ_EVENT) begin
                                        RRC_next_state = RRC_BAD_REQ_s;
                                    end
                                    else if(qv_event_num == `PKT_EVENT) begin
                                        if(wv_opcode == `ACKNOWLEDGE && wv_syndrome_high2 == `SYNDROME_ACK) begin   //Normal ACK
                                            if(wv_ReceivedPSN == wv_UnAckedPSN) begin
                                                RRC_next_state = RRC_RELEASE_s;                                                
                                            end
                                            else if(wv_ReceivedPSN < wv_UnAckedPSN)  begin   //Duplicate ACK
                                                RRC_next_state = RRC_SILENT_DROP_s;
                                            end 
                                            //wv_oldest_read_PSN <= wv_UnAckedPSN happens when some of the oldest read has been finished
                                            else if(wv_ReceivedPSN > wv_UnAckedPSN && w_pending_read && (wv_oldest_read_PSN <= wv_UnAckedPSN)) begin //No pending Read-Req
                                                RRC_next_state = RRC_RETRANS_s;
                                            end
                                            else begin 
                                                RRC_next_state = RRC_RELEASE_s;
                                            end
                                        end
                                        else if(wv_opcode == `ACKNOWLEDGE && (wv_syndrome_high2 == `SYNDROME_NAK || wv_syndrome_high2 == `SYNDROME_RNR)) begin
                                            if(wv_ReceivedPSN == wv_UnAckedPSN) begin
                                                if(wv_syndrome_high2 == `SYNDROME_RNR) begin
                                                    RRC_next_state = RRC_RESET_TIMER_s;
                                                end
                                                else if(wv_syndrome_high2 == `SYNDROME_NAK && wv_syndrome_low5 == `NAK_PSN_SEQUENCE_ERROR) begin
                                                    RRC_next_state = RRC_RETRANS_s;
                                                end
                                                else if(wv_syndrome_high2 == `SYNDROME_NAK && wv_syndrome_low5 != `NAK_PSN_SEQUENCE_ERROR) begin
                                                    RRC_next_state = RRC_WQE_FLUSH_s;
                                                end
                                                else begin
                                                    RRC_next_state = RRC_SILENT_DROP_s;
                                                end
                                            end
                                            else if(wv_ReceivedPSN > wv_UnAckedPSN) begin
												if(w_pending_read && (wv_oldest_read_PSN <= wv_UnAckedPSN)) begin
													RRC_next_state = RRC_RETRANS_s;
												end 
												else begin
	                                                RRC_next_state = RRC_RELEASE_s;
												end 
                                            end
                                            else begin
                                                RRC_next_state = RRC_SILENT_DROP_s;
                                            end
                                        end
                                        else if(wv_opcode == `RDMA_READ_RESPONSE_FIRST || wv_opcode == `RDMA_READ_RESPONSE_MIDDLE || wv_opcode == `RDMA_READ_RESPONSE_LAST ||
                                                wv_opcode == `RDMA_READ_RESPONSE_LAST || wv_opcode == `RDMA_READ_RESPONSE_ONLY) begin //Actually in this branch, there must be pending read, but we still judge the flag
                                            if(wv_ReceivedPSN == wv_UnAckedPSN) begin
                                                RRC_next_state = RRC_FETCH_ENTRY_s;         //This is an expected RDMA Read response, directly scatter data
                                            end            
                                            else if (wv_ReceivedPSN > wv_UnAckedPSN && w_pending_read && (wv_oldest_read_PSN > wv_UnAckedPSN)) begin
                                                RRC_next_state = RRC_RELEASE_s;
                                            end
                                            else if (wv_ReceivedPSN > wv_UnAckedPSN && w_pending_read && (wv_oldest_read_PSN <= wv_UnAckedPSN)) begin 
												if(w_pending_send_write && (wv_oldest_send_write_PSN < wv_oldest_read_PSN)) begin
													RRC_next_state = RRC_RELEASE_s;
												end 
												else begin
	                                                RRC_next_state = RRC_RETRANS_s;            
												end 
                                            end
                                            else begin
                                                RRC_next_state = RRC_SILENT_DROP_s;
                                            end
                                        end
                                        else begin
                                            RRC_next_state = RRC_SILENT_DROP_s;     
                                        end 
                                    end
                                    else begin
                                        RRC_next_state = RRC_SILENT_DROP_s;
                                    end
                                end
                                else begin
                                    RRC_next_state = RRC_RESP_CXT_s;
                                end       
        RRC_BAD_REQ_s:          if(w_rpb_empty && w_swpb_empty) begin  //CPL event can be generated if all the previous pkt have been flushed
                                    //Should consider signal i_rrc_resp_valid for Rd CQ Offset latency
                                    if(!i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_rc_te_loss_prog_full && i_rrc_resp_valid) begin
                                        RRC_next_state = RRC_IDLE_s;
                                        RRC_next_state = RRC_CXT_WB_s;
                                    end
                                    else begin
                                        RRC_next_state = RRC_BAD_REQ_s;
                                    end
                                end
                                else begin
                                    RRC_next_state = RRC_IDLE_s;
                                end
        RRC_RELEASE_s:          if(w_release_finish) begin  //CPL event may be generated during release process, w_release_finish should consider Rd CQ Offset latency
                                    if(qv_sub_state == `ACK_RELEASE_NORMAL) begin
                                        if(wv_ReceivedPSN + 1 == wv_NextPSN) begin  //All the requests have been finished, clear timer
                                            RRC_next_state = RRC_CLEAR_TIMER_s;
                                        end
                                        else if(wv_ReceivedPSN + 1 < wv_NextPSN) begin  //There are still unfinished Verbs, reset timer
                                            RRC_next_state = RRC_RESET_TIMER_s;
                                        end
                                        else begin
                                            RRC_next_state = RRC_RELEASE_s;     //Should not come into this branch
                                        end
                                    end
                                    else if(qv_sub_state == `ACK_RELEASE_EXCEPTION) begin  //ACK_RELEASE_EXCEPTION is designed for unfinished Read
                                        RRC_next_state = RRC_RETRANS_s;
                                    end
                                    else if(qv_sub_state == `NAK_RELEASE) begin
                                        if(wv_syndrome_high2 == `SYNDROME_RNR && w_pending_read) begin  //First retrans, then reset RNR timer
                                            RRC_next_state = RRC_RETRANS_s;
                                        end
                                        else if(wv_syndrome_high2 == `SYNDROME_RNR && !w_pending_read) begin    //Reset RNR timer
                                            RRC_next_state = RRC_RESET_TIMER_s;
                                        end
                                        else if(wv_syndrome_high2 == `SYNDROME_NAK && wv_syndrome_low5 == `NAK_PSN_SEQUENCE_ERROR) begin    
                                            RRC_next_state = RRC_RETRANS_s;
                                        end
                                        else if(wv_syndrome_high2 == `SYNDROME_NAK && wv_syndrome_low5 != `NAK_PSN_SEQUENCE_ERROR) begin //Uncorrected error, flush 
                                            RRC_next_state = RRC_WQE_FLUSH_s;
                                        end
                                        else begin
                                            RRC_next_state = RRC_SILENT_DROP_s;
                                        end
                                    end
                                    else if(qv_sub_state == `READ_RELEASE) begin
                                        if(w_pending_read && (wv_oldest_read_PSN < wv_ReceivedPSN)) begin   //More than one read unfinished, must retrans
                                            RRC_next_state = RRC_RETRANS_s;
                                        end
                                        else begin  //Req before read has all been finished, now deal with current Read response
                                            RRC_next_state = RRC_FETCH_ENTRY_s;
                                        end
                                    end
                                    else begin
                                        RRC_next_state = RRC_SILENT_DROP_s;
                                    end
                                end
                                else begin
                                    RRC_next_state = RRC_RELEASE_s;
                                end
        RRC_RETRANS_s:          if(w_retrans_finish) begin  
                                    RRC_next_state = RRC_RESET_TIMER_s;
                                end
                                else begin
                                    RRC_next_state = RRC_RETRANS_s;
                                end
        RRC_WQE_FLUSH_s:     if(w_flush_finish && (qv_flush_curPSN != wv_NextPSN)) begin            //CPL event can be generated during this flush process
                                    RRC_next_state = RRC_CXT_WB_s;
                                end 
								else if(w_flush_finish && (qv_flush_curPSN == wv_NextPSN)) begin
									RRC_next_state = RRC_IDLE_s;
								end 
                                else begin
                                    RRC_next_state = RRC_WQE_FLUSH_s;    
                                end      
        RRC_RESET_TIMER_s:      if(!i_rc_te_rnr_prog_full && !i_rc_te_loss_prog_full) begin
									if(qv_event_num == `PKT_EVENT && wv_opcode == `RDMA_READ_RESPONSE_FIRST || wv_opcode == `RDMA_READ_RESPONSE_MIDDLE || 
										wv_opcode ==`RDMA_READ_RESPONSE_LAST || wv_opcode == `RDMA_READ_RESPONSE_ONLY) begin
										RRC_next_state = RRC_SILENT_DROP_s;	
									end 
									else begin
	                                    RRC_next_state = RRC_CXT_WB_s;
									end 
                                end
                                else begin
                                    RRC_next_state = RRC_RESET_TIMER_s;
                                end
        RRC_CLEAR_TIMER_s:      if(!i_rc_te_rnr_prog_full && !i_rc_te_loss_prog_full) begin
                                    RRC_next_state = RRC_CXT_WB_s;
                                end
                                else begin
                                    RRC_next_state = RRC_CLEAR_TIMER_s;
                                end
        RRC_SILENT_DROP_s:      if(w_pkt_drop_finish)  begin
                                    //RRC_next_state = RRC_CXT_WB_s;
                                    RRC_next_state = RRC_IDLE_s;
                                end
                                else begin
                                    RRC_next_state = RRC_SILENT_DROP_s;
                                end
        RRC_FETCH_ENTRY_s:      if(!w_sem_cmd_prog_full) begin
                                    RRC_next_state = RRC_RESP_ENTRY_s;
                                end
                                else begin
                                    RRC_next_state = RRC_FETCH_ENTRY_s;
                                end
        RRC_RESP_ENTRY_s:       if(!w_sem_resp_empty) begin
                                    if(w_entry_valid) begin
                                        RRC_next_state = RRC_SCATTER_CMD_s;
                                    end
                                    else begin  //If no available entry, flush the response data
                                        RRC_next_state = RRC_PKT_FLUSH_s;
                                    end
                                end
                                else begin
                                    RRC_next_state = RRC_RESP_ENTRY_s;
                                end
        RRC_SCATTER_CMD_s:      if(!i_vtp_cmd_prog_full) begin		//RDMA Read Scatter is always valid
                                    RRC_next_state = RRC_SCATTER_DATA_s;
                                end
                                else begin
                                    RRC_next_state = RRC_SCATTER_CMD_s;
                                end
        RRC_SCATTER_DATA_s:     if(qv_pkt_left_length + qv_unwritten_len <= qv_cur_entry_left_length) begin     //Current entry is enough to scatter packet data(notice part of this packet may be scattered by previous entry)
                                    if((qv_pkt_left_length == 0 && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) || //Corner case, only qv_unwritten_data needs to be processed
                                       (qv_pkt_left_length != 0 && (qv_unwritten_len + qv_pkt_left_length <= 32) && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_nd_from_hp_empty))begin  //Meet the end of a Packet
                                        if(wv_opcode == `RDMA_READ_RESPONSE_FIRST || wv_opcode == `RDMA_READ_RESPONSE_MIDDLE) begin
											if(qv_cur_entry_left_length == (qv_pkt_left_length + qv_unwritten_len)) begin
                                            	RRC_next_state = RRC_RELEASE_ENTRY_s;
											end 
											else begin
												RRC_next_state = RRC_UPDATE_ENTRY_s;
											end 
                                        end
                                        else begin //Last packet has been scattered, release all the entries for current request
                                            RRC_next_state = RRC_RELEASE_ENTRY_s;
                                        end
                                    end
                                    else begin
                                        RRC_next_state = RRC_SCATTER_DATA_s;
                                    end
                                end
                                else if(qv_pkt_left_length + qv_unwritten_len > qv_cur_entry_left_length) begin //Current entry is not enough, should be carefully dealt with
                                    if(qv_unwritten_len == 0) begin  //Now we are 32B aligned, do not need qv_unwritten_data
                                        if(qv_cur_entry_left_length <= 32 && !i_nd_from_hp_empty && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin //Meet last 32B of current scatter entry
                                            RRC_next_state = RRC_RELEASE_ENTRY_s;
                                        end
                                        else begin
                                            RRC_next_state = RRC_SCATTER_DATA_s;
                                        end
                                    end
                                    else begin //Not 32B Aligned, need to discuss different case
                                        if(qv_cur_entry_left_length <= 32) begin //Meet last 32B of current scatter entry
                                            if(qv_cur_entry_left_length <= qv_unwritten_len && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin //Just scatter qv_unwritten_data, does not need to piece iv_nd_from_hp_data together
                                                RRC_next_state = RRC_RELEASE_ENTRY_s;
                                            end
                                            else if(qv_cur_entry_left_length > qv_unwritten_len && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_nd_from_hp_empty) begin //Exceed qv_unwritten_len, need to piece iv_nd_from_hp_data together
                                                RRC_next_state = RRC_RELEASE_ENTRY_s;
                                            end
                                            else begin
                                                RRC_next_state = RRC_SCATTER_DATA_s;
                                            end
                                        end
                                        else begin
                                            RRC_next_state = RRC_SCATTER_DATA_s;
                                        end
                                    end
                                end
                                else begin
                                    RRC_next_state = RRC_SCATTER_DATA_s;
                                end
        RRC_UPDATE_ENTRY_s:     if(!w_sem_cmd_prog_full) begin
                                    RRC_next_state = RRC_CXT_WB_s;
                                end
                                else begin
                                    RRC_next_state = RRC_UPDATE_ENTRY_s;
                                end
        RRC_PKT_FLUSH_s:        if(w_pkt_drop_finish) begin         //Flush read response
                                    RRC_next_state = RRC_WQE_FLUSH_s;
                                end 
                                else begin
                                    RRC_next_state = RRC_PKT_FLUSH_s;
                                end
        RRC_RELEASE_ENTRY_s:    if(!w_sem_cmd_prog_full) begin
                                    if(qv_pkt_left_length == 0 && qv_unwritten_len == 0) begin   //Current packet has been finished
                                        if(wv_opcode == `RDMA_READ_RESPONSE_LAST || wv_opcode == `RDMA_READ_RESPONSE_ONLY) begin
                                            RRC_next_state = RRC_READ_COMPLETION_s;
                                        end
                                        else begin
                                            RRC_next_state = RRC_CXT_WB_s;
                                        end
                                    end
                                    else begin  //Current packet has not been finished, need to fetch new entry
                                        RRC_next_state = RRC_FETCH_ENTRY_s;
                                    end
                                end
                                else begin
                                    RRC_next_state = RRC_RELEASE_ENTRY_s;
                                end
        RRC_READ_COMPLETION_s:  if(w_cpl_can_be_upload) begin 
                                    RRC_next_state = RRC_CXT_WB_s;
                                end
                                else begin
                                    RRC_next_state = RRC_READ_COMPLETION_s;
                                end
        RRC_CXT_WB_s:           if(!i_cxtmgt_cmd_prog_full && !i_cxtmgt_cxt_prog_full) begin
                                    RRC_next_state = RRC_IDLE_s;
                                end
                                else begin
                                    RRC_next_state = RRC_CXT_WB_s;
                                end
        default:                RRC_next_state = RRC_IDLE_s;
    endcase
end

/*----------------------------------------  Part 3: Output Registers Decode -------------------------------------------------------------*/
assign o_rrc_init_finish = (qv_rpb_free_init_counter == `RPB_CONTENT_FREE_NUM - 1) && (qv_swpb_free_init_counter == `SWPB_CONTENT_FREE_NUM - 1) 
							&& (qv_rpb_list_table_init_counter == `QP_NUM - 1) && (qv_swpb_list_table_init_counter == `QP_NUM - 1) 
							&& (qv_rpb_next_table_init_counter == `RPB_CONTENT_FREE_NUM - 1) && (qv_swpb_next_table_init_counter == `SWPB_CONTENT_FREE_NUM - 1)
							&& (qv_bc_table_init_counter == `QP_NUM - 1) && w_sem_init_finish;

//-- w_cpl_can_be_upload -- This signal is used for read completion and wqe flush, not for send/write
assign w_cpl_can_be_upload = !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_rc_te_loss_prog_full && i_rrc_resp_valid;


//-- Response Packet Header - Base Transport Header(BTH) --
assign wv_PKey = iv_header_from_hp_data[15:0];
assign wv_pad_count = iv_header_from_hp_data[21:20];
assign wv_service_type = iv_header_from_hp_data[31:29];
assign wv_opcode = iv_header_from_hp_data[28:24];
assign wv_PktQPN = iv_header_from_hp_data[55:32];
assign wv_ReceivedPSN = iv_header_from_hp_data[87:64];
assign wv_length = {iv_header_from_hp_data[94:88], iv_header_from_hp_data[61:56]};

//-- Response Packet Header - Acknowledge Extended Transport Header(AETH)
assign wv_msn = iv_header_from_hp_data[23 + 96 : 0 + 96];
assign wv_syndrome = iv_header_from_hp_data[31 + 96 : 24 + 96];
assign wv_syndrome_high2 = wv_syndrome[6:5];
assign wv_syndrome_low5 = wv_syndrome[4:0];
           
wire 	[255:0]			wv_cxtmgt_cxt_data;
reg 	[255:0]			qv_cxtmgt_download_data;

assign 	wv_cxtmgt_cxt_data = (!i_cxtmgt_resp_empty && !i_cxtmgt_cxt_empty) ? iv_cxtmgt_cxt_data : qv_cxtmgt_download_data;

always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_cxtmgt_download_data <= 'd0;
	end 
	else if(!i_cxtmgt_resp_empty && !i_cxtmgt_cxt_empty) begin
		qv_cxtmgt_download_data <= iv_cxtmgt_cxt_data;
	end 
	else begin
		qv_cxtmgt_download_data <= qv_cxtmgt_download_data;
	end 
end 

 
//-- QP Context Information --
assign wv_qp_state = wv_cxtmgt_cxt_data[2:0];
assign wv_UnAckedPSN = wv_cxtmgt_cxt_data[31:8];
assign wv_NextPSN = wv_cxtmgt_cxt_data[63:40];
assign wv_rqpn = wv_cxtmgt_cxt_data[95:72];
assign wv_CQ_LKey = wv_cxtmgt_cxt_data[127:96];
assign wv_QP_PD      = wv_cxtmgt_cxt_data[159:128];     //PD check is bypassed in VTP... Should rectify
assign wv_CQ_PD      = wv_cxtmgt_cxt_data[191:160];     //PD chIeck is bypassed in VTP... Should rectify
assign wv_cq_length = wv_cxtmgt_cxt_data[223:192];
assign wv_cqn = wv_cxtmgt_cxt_data[247:224];

wire 	[15:0]		wv_rlid;
assign wv_rlid = {wv_cxtmgt_cxt_data[71:64], wv_cxtmgt_cxt_data[39:32]};

//-- Timer Event Type
assign wv_loss_timer_event = iv_loss_expire_data[7:0];
assign wv_rnr_timer_event = iv_rnr_expire_data[7:0];

//-- w_new_event -- New event indicator
assign w_new_event = !i_loss_expire_empty || !i_rnr_expire_empty || !i_br_empty || !i_header_from_hp_empty;

//-- wv_UPSN_pkt_opcode --
// assign wv_UPSN_pkt_opcode = `UNCERTAIN;

//-- Timer Event related QP
assign wv_loss_timer_QPN = iv_loss_expire_data[31:8];
assign wv_rnr_timer_QPN = iv_rnr_expire_data[31:8];

//-- wv_bad_req_QPN -- Bad Request related QP --
assign wv_bad_req_QPN = iv_br_data[23:0];

wire 	[31:0]			wv_bad_wqe_offset;
assign wv_bad_wqe_offset = iv_br_data[95:64];

//-- w_entry_valid -- Indicates whether the fetched entry is valid
//-- wv_entry_length --
//-- wv_entry_va --
//-- wv_entry_key --
assign w_entry_valid = (wv_sem_resp_dout[7:0] == `VALID_ENTRY);
assign wv_entry_length = wv_sem_resp_dout[63:32];
assign wv_entry_va = wv_sem_resp_dout[159:96];
assign wv_entry_key = wv_sem_resp_dout[95:64];

always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_entry_length <= 'd0;
		qv_entry_va <= 'd0;
		qv_entry_key <= 'd0;
	end 
	else if(RRC_cur_state == RRC_RESP_ENTRY_s && !w_sem_resp_empty) begin
		qv_entry_length <= wv_sem_resp_dout[63:32];
		qv_entry_va <= wv_sem_resp_dout[159:96];
		qv_entry_key <= wv_sem_resp_dout[95:64];
	end 
	else begin
		qv_entry_length <= qv_entry_length;
		qv_entry_va <= qv_entry_va;
		qv_entry_key <= qv_entry_key;
	end 
end 

//-- w_pkt_drop_finish -- Indicates whether current Packet has been dropped
//                          For ACKNOWLEDGE, if the header is read, it is flushed since it has just one header
//                          For OP_READ, only when we are dealing with the last 256-bit of the FIFO do we think it is flushed
assign w_pkt_drop_finish = (wv_opcode == `ACKNOWLEDGE && RRC_cur_state == RRC_SILENT_DROP_s) ||     //For ACK 
                            (wv_opcode != `ACKNOWLEDGE && RRC_cur_state == RRC_SILENT_DROP_s &&  qv_pkt_left_length <= 32 && !i_header_from_hp_empty && !i_nd_from_hp_empty);    //For Read Response Flush

//-- w_pending_read -- Whether there is pending read in the buffer and whether the PSN of the pending read is <= RPSN
assign w_pending_read = !w_rpb_empty && (iv_rpb_content_doutb[87:64] <= wv_ReceivedPSN);


//-- w_pending_send_write -- Whether there is pending send/write operation
assign w_pending_send_write = !w_swpb_empty && (iv_swpb_content_doutb[87:64] <= wv_ReceivedPSN);

//-- Read Packet Buffer metadata --
assign wv_rpb_head = iv_rpb_list_head_doutb;
assign wv_rpb_tail = iv_rpb_list_tail_doutb;
assign w_rpb_empty = iv_rpb_list_empty_doutb;

//-- Send/Write Packet Buffer metadata
assign wv_swpb_head = iv_swpb_list_head_doutb;
assign wv_swpb_tail = iv_swpb_list_tail_doutb;
assign w_swpb_empty = iv_swpb_list_empty_doutb;

//-- wv_oldest_read_PSN --
assign wv_oldest_read_PSN = iv_rpb_content_doutb[87:64];
//-- wv_oldest_send_write_PSN --
assign wv_oldest_send_write_PSN = iv_swpb_content_doutb[87:64];

//-- q_sch_flag_1 -- When begin a new event handling, turn over flag1
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_sch_flag_1 <= 1'b0;        
    end
    else if (RRC_cur_state == RRC_IDLE_s && w_new_event && (q_sch_flag_1 == q_sch_flag_2)) begin
        q_sch_flag_1 <= ~q_sch_flag_1;
    end
    else begin
        q_sch_flag_1 <= q_sch_flag_1;
    end
end

//-- q_sch_flag_2 -- When finish an event, turn over flag2
//                  When flag1 == flag2, means we are idle, flag1 != flag2, means we are handling an event
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_sch_flag_2 <= 1'b0;        
    end
    else if (RRC_cur_state == RRC_CXT_WB_s && !i_cxtmgt_cmd_prog_full && !i_cxtmgt_cxt_prog_full) begin
        q_sch_flag_2 <= ~q_sch_flag_2;
    end
    else if (RRC_cur_state == RRC_SILENT_DROP_s && w_pkt_drop_finish) begin
        q_sch_flag_2 <= ~q_sch_flag_2;
    end
    else begin
        q_sch_flag_2 <= q_sch_flag_2;       
    end    
end

//-- qv_event_num --
//Event Schedule, Round Robin
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_event_num <= 'd0;        
    end
    else if (RRC_cur_state == RRC_IDLE_s && w_new_event && (q_sch_flag_1 == q_sch_flag_2)) begin
        case(qv_event_num)
            `NONE_EVENT:        if(!i_loss_expire_empty) begin
                                    qv_event_num <= `LOSS_TIMER_EVENT;
                                end
                                else if(!i_rnr_expire_empty) begin
                                    qv_event_num <= `RNR_TIMER_EVENT;
                                end
                                else if(!i_br_empty) begin
                                    qv_event_num <= `BAD_REQ_EVENT;
                                end
                                else if(!i_header_from_hp_empty) begin
                                    qv_event_num <= `PKT_EVENT;
                                end
                                else begin
                                    qv_event_num <= `NONE_EVENT;
                                end
            `LOSS_TIMER_EVENT:  if(!i_rnr_expire_empty) begin
                                    qv_event_num <= `RNR_TIMER_EVENT;
                                end
                                else if(!i_br_empty) begin
                                    qv_event_num <= `BAD_REQ_EVENT;
                                end
                                else if(!i_header_from_hp_empty) begin
                                    qv_event_num <= `PKT_EVENT;
                                end
                                else if(!i_loss_expire_empty) begin
                                    qv_event_num <= `LOSS_TIMER_EVENT;
                                end
                                else begin
                                    qv_event_num <= `NONE_EVENT;
                                end
            `RNR_TIMER_EVENT:  if(!i_br_empty) begin
                                    qv_event_num <= `BAD_REQ_EVENT;
                                end
                                else if(!i_header_from_hp_empty) begin
                                    qv_event_num <= `PKT_EVENT;
                                end
                                else if(!i_loss_expire_empty) begin
                                    qv_event_num <= `LOSS_TIMER_EVENT;
                                end
                                else if(!i_rnr_expire_empty) begin
                                    qv_event_num <= `RNR_TIMER_EVENT;
                                end
                                else begin
                                    qv_event_num <= `NONE_EVENT;
                                end
            `BAD_REQ_EVENT:     if(!i_header_from_hp_empty) begin
                                    qv_event_num <= `PKT_EVENT;
                                end
                                else if(!i_loss_expire_empty) begin
                                    qv_event_num <= `LOSS_TIMER_EVENT;
                                end
                                else if(!i_rnr_expire_empty) begin
                                    qv_event_num <= `RNR_TIMER_EVENT;
                                end
                                else if(!i_br_empty) begin
                                    qv_event_num <= `BAD_REQ_EVENT;
                                end
                                else begin
                                    qv_event_num <= `NONE_EVENT;
                                end
            `PKT_EVENT:         if(!i_loss_expire_empty) begin
                                    qv_event_num <= `LOSS_TIMER_EVENT;
                                end
                                else if(!i_rnr_expire_empty) begin
                                    qv_event_num <= `RNR_TIMER_EVENT;
                                end
                                else if(!i_br_empty) begin
                                    qv_event_num <= `BAD_REQ_EVENT;
                                end
                                else if(!i_header_from_hp_empty) begin
                                    qv_event_num <= `PKT_EVENT;
                                end
                                else begin
                                    qv_event_num <= `NONE_EVENT;
                                end
            default:            qv_event_num <= `NONE_EVENT;
        endcase
    end
    else begin
        qv_event_num <= qv_event_num;
    end
end

//-- qv_sub_state -- //Indicates whether we are handling ACK/NAK/Read-Related event
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_sub_state <= `NO_STATE;
    end
    else if (RRC_cur_state != RRC_RELEASE_s && RRC_next_state == RRC_RELEASE_s) begin
        case(wv_opcode)
            `ACKNOWLEDGE:               if(wv_syndrome_high2 == `SYNDROME_ACK) begin
                                            if(w_pending_read && wv_oldest_read_PSN <= wv_ReceivedPSN) begin
                                                qv_sub_state <= `ACK_RELEASE_EXCEPTION;
                                            end
                                            else begin
                                                qv_sub_state <= `ACK_RELEASE_NORMAL;
                                            end
                                        end
                                        else if(wv_syndrome_high2 == `SYNDROME_RNR || wv_syndrome_high2 == `SYNDROME_NAK) begin
                                            qv_sub_state <= `NAK_RELEASE;
                                        end
                                        else begin
                                            qv_sub_state <= `NO_STATE;
                                        end
            `RDMA_READ_RESPONSE_FIRST:  qv_sub_state <= `READ_RELEASE;
            `RDMA_READ_RESPONSE_MIDDLE: qv_sub_state <= `READ_RELEASE;
            `RDMA_READ_RESPONSE_LAST:   qv_sub_state <= `READ_RELEASE;
            `RDMA_READ_RESPONSE_ONLY:   qv_sub_state <= `READ_RELEASE;
            default:                    qv_sub_state <= `NO_STATE;
        endcase
    end
    else if (RRC_cur_state != RRC_RETRANS_s && RRC_next_state == RRC_RETRANS_s) begin
        case(wv_opcode)
            `ACKNOWLEDGE:               if(wv_syndrome_high2 == `SYNDROME_ACK) begin
                                            qv_sub_state <= `ACK_RETRANS;
                                        end
                                        else if(wv_syndrome_high2 == `SYNDROME_RNR || wv_syndrome_high2 == `SYNDROME_NAK) begin
                                            qv_sub_state <= `NAK_RETRANS;
                                        end
                                        else begin
                                            qv_sub_state <= `NO_STATE;
                                        end
            `RDMA_READ_RESPONSE_FIRST:  qv_sub_state <= `READ_RETRANS;
            `RDMA_READ_RESPONSE_MIDDLE: qv_sub_state <= `READ_RETRANS;
            `RDMA_READ_RESPONSE_LAST:   qv_sub_state <= `READ_RETRANS;
            `RDMA_READ_RESPONSE_ONLY:   qv_sub_state <= `READ_RETRANS;
            default:                    qv_sub_state <= `NO_STATE;
        endcase
    end
	else if(RRC_cur_state != RRC_WQE_FLUSH_s && RRC_next_state == RRC_WQE_FLUSH_s) begin
		qv_sub_state <= `WQE_FLUSH;
	end
    else if (RRC_cur_state == RRC_SCATTER_CMD_s) begin
        qv_sub_state <= `READ_SCATTER;
    end
    else begin
        qv_sub_state <= qv_sub_state;
    end
end


/*************************************************** Pkt Release Related : Begin ***********************************************************************/
assign w_gen_cpl_during_release = ((qv_release_counter != 0 && qv_release_PktLeftLen <= 32) || (qv_release_counter == 0 && wv_release_curPktLen == 0)) &&
                                    ((qv_release_curOP == `SEND_ONLY || qv_release_curOP == `SEND_ONLY_WITH_IMM || qv_release_curOP == `SEND_LAST || qv_release_curOP == `SEND_LAST_WITH_IMM ||
                                    qv_release_curOP == `RDMA_WRITE_ONLY || qv_release_curOP == `RDMA_WRITE_ONLY_WITH_IMM || qv_release_curOP == `RDMA_WRITE_LAST ||
                                    qv_release_curOP == `RDMA_WRITE_LAST_WITH_IMM));

//-- w_release_finish -- Indicates whether all the requests in the pkt buffer has been releaseed, since CPL may be generated, should consider i_rrc_resp_valid for Rd CQ Offset
assign w_release_finish = (qv_release_curPSN == qv_release_upper_bound) && 
						((qv_release_counter != 0 && qv_release_PktLeftLen <= 32) || (qv_release_counter == 0 && wv_release_curPktLen == 0)) && 
						((w_gen_cpl_during_release && w_cpl_can_be_upload) || !w_gen_cpl_during_release);

//-- wv_release_curPktLen -- 
assign wv_release_curPktLen = w_cur_release_is_read ? 0 : {iv_swpb_content_doutb[94:88], iv_swpb_content_doutb[61:56]};

//PSN comparison of Read Buffer and Send/Write Buffer
//-- w_cur_release_is_read --
//Release pkt cannot be read
// assign w_cur_release_is_read = w_rpb_empty ? 1'b0 : (w_swpb_empty ? 1'b1 : (iv_rpb_content_doutb[87:64] > iv_swpb_content_doutb[87:64] ? 0 : 1));
assign w_cur_release_is_read = 1'b0;

reg                 q_cur_release_is_read;
//-- q_cur_release_is_read --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_cur_release_is_read <= 1'b0;        
    end
    else if (RRC_cur_state == RRC_RELEASE_s && qv_release_counter == 0) begin
        q_cur_release_is_read <= w_cur_release_is_read;
    end
    else begin
        q_cur_release_is_read <= q_cur_release_is_read;
    end
end

//-- qv_release_curOP --
always @(*) begin
	if(rst) begin 
		qv_release_curOP = `NONE_OPCODE;
	end 
	else if(RRC_cur_state == RRC_RELEASE_s && qv_release_counter == 0) begin
		qv_release_curOP = (w_cur_release_is_read) ? `RDMA_READ_REQUEST : iv_swpb_content_doutb[28:24];
	end 
	else begin
		qv_release_curOP = qv_release_curOP_TempReg;
	end
end 

//-- qv_release_curOP_TempReg
always @(posedge clk or posedge rst) begin 
	if(rst) begin 
		qv_release_curOP_TempReg <= `NONE_OPCODE;
	end 
	else begin
		qv_release_curOP_TempReg <= qv_release_curOP;
	end 
end 

//-- qv_release_curPSN --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_release_curPSN <= 'd0;        
    end
    else if (RRC_cur_state != RRC_RELEASE_s && RRC_next_state == RRC_RELEASE_s) begin //The start PSN of release must be UPSN
        qv_release_curPSN <= wv_UnAckedPSN;
    end
    //Add CPL judgement
    else if(RRC_cur_state == RRC_RELEASE_s && ((w_gen_cpl_during_release && w_cpl_can_be_upload) || !w_gen_cpl_during_release)) begin
        if(qv_release_counter == 0 && wv_release_curPktLen == 0) begin   //The packet has no payload
            qv_release_curPSN <= qv_release_curPSN + 1;
        end
        else if(qv_release_counter > 0 && qv_release_PktLeftLen <= 32) begin  //The packet has payload and we are releasing last 256-bit
            qv_release_curPSN <= qv_release_curPSN + 1;
        end
        else begin
            qv_release_curPSN <= qv_release_curPSN;
        end
    end
    else begin
        qv_release_curPSN <= qv_release_curPSN;
    end
end

//-- qv_release_counter -- Indicates how many 256-bit of a packet we have released, == 0 means we are dealing with packet header
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_release_counter <= 'd0;        
    end
    else if (RRC_cur_state != RRC_RELEASE_s && RRC_next_state == RRC_RELEASE_s) begin
        qv_release_counter <= 'd0;
    end
    //Add CPL judgement
    else if (RRC_cur_state == RRC_RELEASE_s && ((w_gen_cpl_during_release && w_cpl_can_be_upload) || !w_gen_cpl_during_release)) begin
        if(qv_release_counter == 0) begin //Dealing with header
            if(wv_release_curPktLen == 0) begin //No payload
                qv_release_counter <= 'd0;
            end
            else begin
                qv_release_counter <= qv_release_counter + 1;
            end
        end
        else begin
            if(qv_release_PktLeftLen <= 32) begin       //Last 256-bit of a Packet
                qv_release_counter <= 'd0;
            end
            else begin
                 qv_release_counter <= qv_release_counter + 1;
            end 
        end 
    end
    else begin
        qv_release_counter <= qv_release_counter;
    end
end

//-- qv_release_PktLeftLen -- Indicates Packets length unreleased of current packet in the packet buffer
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_release_PktLeftLen <= 'd0;
    end
    //Add CPL judgement
    else if(RRC_cur_state == RRC_RELEASE_s && ((w_gen_cpl_during_release && w_cpl_can_be_upload) || !w_gen_cpl_during_release)) begin
        if(qv_release_counter == 0) begin //Dealing with Packet Header
            qv_release_PktLeftLen <= wv_release_curPktLen;
        end
        else begin
            if(qv_release_PktLeftLen <= 32) begin
                qv_release_PktLeftLen <= 'd0;
            end
            else begin
                qv_release_PktLeftLen <= qv_release_PktLeftLen - 32;
            end 
        end
    end
    else begin
        qv_release_PktLeftLen <= qv_release_PktLeftLen;
    end
end

//-- qv_release_upper_bound -- //Upper bound of PSN of released packet
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_release_upper_bound <= 'd0;
    end
    else if (RRC_cur_state != RRC_RELEASE_s && RRC_next_state == RRC_RELEASE_s) begin
        case(wv_opcode)
            `ACKNOWLEDGE:               if(wv_syndrome_high2 == `SYNDROME_ACK) begin
                                            if(w_pending_read && (wv_oldest_read_PSN <= wv_ReceivedPSN)) begin
                                                qv_release_upper_bound <= wv_oldest_read_PSN - 1;
                                            end
                                            else begin
                                                qv_release_upper_bound <= wv_ReceivedPSN;
                                            end
                                        end
                                        else if(wv_syndrome_high2 == `SYNDROME_RNR || wv_syndrome_high2 == `SYNDROME_NAK) begin
                                            if(w_pending_read && (wv_oldest_read_PSN <= wv_ReceivedPSN)) begin
                                                qv_release_upper_bound <= wv_oldest_read_PSN - 1;
                                            end
                                            else begin
                                                qv_release_upper_bound <= wv_ReceivedPSN - 1;
                                            end
                                        end
                                        else begin
                                            qv_release_upper_bound <= qv_release_upper_bound;
                                        end
            `RDMA_READ_RESPONSE_FIRST:  if((wv_ReceivedPSN > wv_UnAckedPSN) && w_pending_read && (wv_oldest_read_PSN <= wv_ReceivedPSN)) begin
                                            qv_release_upper_bound <= wv_oldest_read_PSN - 1;
                                        end
                                        else begin
                                            qv_release_upper_bound <= wv_ReceivedPSN - 1;
                                        end
            `RDMA_READ_RESPONSE_ONLY:   if((wv_ReceivedPSN > wv_UnAckedPSN) && w_pending_read && (wv_oldest_read_PSN <= wv_ReceivedPSN)) begin
                                            qv_release_upper_bound <= wv_oldest_read_PSN - 1;
                                        end
                                        else begin
                                            qv_release_upper_bound <= wv_ReceivedPSN - 1;
                                        end
            default:                    qv_release_upper_bound <= qv_release_upper_bound;
        endcase
    end
    else begin
        qv_release_upper_bound <= qv_release_upper_bound; 
    end
end

/*************************************************** End ***********************************************************************/

/*************************************************** Pkt Retrans Related : Begin ***********************************************************************/
always @(posedge clk or posedge rst) begin
	if(rst) begin
		q_rpb_retrans_finish <= 'd0;
	end 
	else if(RRC_cur_state == RRC_RESP_CXT_s) begin
		q_rpb_retrans_finish <= w_rpb_empty;
	end 
	else if(RRC_cur_state == RRC_RETRANS_s) begin
		if(q_cur_retrans_is_read && (qv_rpb_content_addrb_TempReg == wv_rpb_tail) && !i_header_to_rpg_prog_full) begin
			q_rpb_retrans_finish <= 'd1;
		end  
		else begin
			q_rpb_retrans_finish <= q_rpb_retrans_finish;
		end 
	end 
	else begin
		q_rpb_retrans_finish <= 'd0;
	end 
end 

always @(posedge clk or posedge rst) begin
	if(rst) begin
		q_swpb_retrans_finish <= 'd0;
	end 
	else if(RRC_cur_state == RRC_RESP_CXT_s) begin
		q_swpb_retrans_finish <= w_swpb_empty;
	end 
	else if(RRC_cur_state == RRC_RETRANS_s) begin
		if(!q_cur_retrans_is_read && (qv_swpb_content_addrb_TempReg == wv_swpb_tail) && !i_header_to_rpg_prog_full) begin
			q_swpb_retrans_finish <= 'd1;
		end  
		else begin
			q_swpb_retrans_finish <= q_swpb_retrans_finish;
		end 
	end 
	else begin
		q_swpb_retrans_finish <= 'd0;
	end 
end 



//-- w_retrans_finish -- Indicates whether all the needed Req has been retransmitted 
assign w_retrans_finish = ((!q_cur_retrans_is_read && qv_retrans_curPSN == qv_retrans_upper_bound) || (q_cur_retrans_is_read && qv_retrans_curPSN + qv_PSN_incr_for_read == qv_retrans_upper_bound + 1)) && ((qv_retrans_counter != 0 && qv_retrans_PktLeftLen <= 32 && !i_nd_to_rpg_prog_full) || (qv_retrans_counter == 0 && wv_retrans_curPktLen == 0 && !i_header_to_rpg_prog_full));

//-- wv_retrans_curPktLen -- 
assign wv_retrans_curPktLen = q_cur_retrans_is_read ? 0 : {iv_swpb_content_doutb[94:88], iv_swpb_content_doutb[61:56]};



//-- q_cur_retrans_is_read --
//assign w_cur_retrans_is_read = q_rpb_retrans_finish ? 1'b0 : (q_swpb_retrans_finish ? 1'b1 : (iv_rpb_content_doutb[87:64] > iv_swpb_content_doutb[87:64] ? 0 : 1));
always @(*) begin
	if(rst) begin
		q_cur_retrans_is_read = 'd0;
	end 
	else if(RRC_cur_state == RRC_RETRANS_s && qv_retrans_counter == 0) begin
		q_cur_retrans_is_read = q_rpb_retrans_finish ? 1'b0 : (q_swpb_retrans_finish ? 1'b1 : (iv_rpb_content_doutb[87:64] > iv_swpb_content_doutb[87:64] ? 0 : 1));
	end 
	else begin
		q_cur_retrans_is_read = q_cur_retrans_is_read_TempReg;
	end 
end 

//-- q_cur_retrans_is_read_TempReg --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_cur_retrans_is_read_TempReg <= 1'b0;        
    end
    else begin
        q_cur_retrans_is_read_TempReg <= q_cur_retrans_is_read;
    end
end

//-- qv_retrans_counter --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_retrans_counter <= 'd0;        
    end
    else if (RRC_cur_state != RRC_RETRANS_s && RRC_next_state == RRC_RETRANS_s) begin
        qv_retrans_counter <= 'd0;
    end
    else if (RRC_cur_state == RRC_RETRANS_s) begin
        if(qv_retrans_counter == 0) begin //Dealing with header
            if(wv_retrans_curPktLen == 0) begin //No Paylaod
                qv_retrans_counter <= 'd0;
            end
            else if(!i_header_to_rpg_prog_full) begin
                qv_retrans_counter <= qv_retrans_counter + 1;
            end
            else begin
                qv_retrans_counter <= qv_retrans_counter;
            end
        end
        else begin
            if(!i_nd_to_rpg_prog_full) begin
                if(qv_retrans_PktLeftLen <= 32) begin 
                    qv_retrans_counter <= 'd0;
                end
                else begin
                    qv_retrans_counter <= qv_retrans_counter + 1;
                end
            end
            else begin
                qv_retrans_counter <= qv_retrans_counter;
            end
        end
    end
    else begin
        qv_retrans_counter <= qv_retrans_counter;
    end
end

//-- qv_retrans_PktLeftLen -- //Indicates Packets length unretransmitted of current packet in the packet buffer
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_retrans_PktLeftLen <= 'd0;
    end
    else if (RRC_cur_state == RRC_RETRANS_s && qv_retrans_counter == 0) begin
        if(q_cur_retrans_is_read) begin
            //qv_retrans_PktLeftLen <= {iv_rpb_content_doutb[94:88], iv_rpb_content_doutb[61:56]};  
            qv_retrans_PktLeftLen <= 'd0;  	//No layload
        end
        else begin
            qv_retrans_PktLeftLen <= {iv_swpb_content_doutb[94:88], iv_swpb_content_doutb[61:56]};
        end
    end
    else if (RRC_cur_state == RRC_RETRANS_s && qv_retrans_counter != 0 && !i_nd_to_rpg_prog_full) begin
        if(qv_retrans_PktLeftLen <= 32) begin
            qv_retrans_PktLeftLen <= 'd0;
        end
        else begin 
            qv_retrans_PktLeftLen <= qv_retrans_PktLeftLen - 32;
        end 
    end
    else begin
        qv_retrans_PktLeftLen <= qv_retrans_PktLeftLen;
    end
end

wire 		[5:0]			wv_PMTU;
assign wv_PMTU = iv_rpb_content_doutb[229:224];

wire 		[31:0]			wv_Read_DMALen;
assign wv_Read_DMALen = iv_rpb_content_doutb[127 + 96 : 96 + 96];


always @(*) begin 
	if(rst) begin
		qv_PSN_incr_for_read = 'd0;
	end 
	else begin
		case(wv_PMTU)
			1:		qv_PSN_incr_for_read = (wv_Read_DMALen[7:0] != 'd0) ? wv_Read_DMALen[31:8] + 1 : wv_Read_DMALen[31:8];
			2:		qv_PSN_incr_for_read = (wv_Read_DMALen[8:0] != 'd0) ? wv_Read_DMALen[31:9] + 1 : wv_Read_DMALen[31:9];
			3:		qv_PSN_incr_for_read = (wv_Read_DMALen[9:0] != 'd0) ? wv_Read_DMALen[31:10] + 1 : wv_Read_DMALen[31:10];
			4:		qv_PSN_incr_for_read = (wv_Read_DMALen[10:0] != 'd0) ? wv_Read_DMALen[31:11] + 1 : wv_Read_DMALen[31:11];
			5:		qv_PSN_incr_for_read = (wv_Read_DMALen[11:0] != 'd0) ? wv_Read_DMALen[31:12] + 1 : wv_Read_DMALen[31:12];
			default:	qv_PSN_incr_for_read = 'd0;
		endcase 
	end 
end 


//-- qv_retrans_curPSN --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_retrans_curPSN <= 'd0;
    end
    else if (RRC_cur_state != RRC_RETRANS_s && RRC_next_state == RRC_RETRANS_s) begin   //Before retrnasmission
        if(qv_event_num == `LOSS_TIMER_EVENT || qv_event_num == `RNR_TIMER_EVENT) begin
            qv_retrans_curPSN <= (!w_rpb_empty && wv_oldest_read_PSN <= wv_UnAckedPSN) ? wv_oldest_read_PSN : wv_UnAckedPSN;
        end
        else begin
            case(wv_opcode)
                `ACKNOWLEDGE:                   if(wv_syndrome_high2 == `SYNDROME_ACK) begin
                                                    if(w_pending_read) begin
                                                        qv_retrans_curPSN <= wv_oldest_read_PSN;
                                                    end
                                                    else begin  //Actually this branch will not be entered, because in {ACK, SYNDROME_ACK}, retrans is definitely read
                                                        qv_retrans_curPSN <= wv_ReceivedPSN + 1;
                                                    end
                                                end
                                                else if(wv_syndrome_high2 == `SYNDROME_RNR || wv_syndrome_high2 == `SYNDROME_NAK) begin
                                                    if(w_pending_read && wv_oldest_read_PSN <= wv_ReceivedPSN) begin
                                                        qv_retrans_curPSN <= wv_oldest_read_PSN;
                                                    end
                                                    else begin
                                                        qv_retrans_curPSN <= wv_ReceivedPSN;
                                                    end
                                                end
                                                else begin
                                                    qv_retrans_curPSN <= qv_retrans_curPSN;
                                                end
                `RDMA_READ_RESPONSE_FIRST:      qv_retrans_curPSN <= wv_oldest_read_PSN;
                `RDMA_READ_RESPONSE_MIDDLE:     qv_retrans_curPSN <= wv_oldest_read_PSN;
                `RDMA_READ_RESPONSE_LAST:       qv_retrans_curPSN <= wv_oldest_read_PSN;
                `RDMA_READ_RESPONSE_ONLY:       qv_retrans_curPSN <= wv_oldest_read_PSN;
                default:                        qv_retrans_curPSN <= qv_retrans_curPSN;   
            endcase
        end
    end
    else if(RRC_cur_state == RRC_RETRANS_s) begin
        if(qv_retrans_counter == 0) begin
            if(wv_retrans_curPktLen == 0 && !i_header_to_rpg_prog_full) begin //Include RDMA read
				if(q_cur_retrans_is_read) begin
	                qv_retrans_curPSN <= qv_retrans_curPSN + qv_PSN_incr_for_read;
				end 
				else begin
					qv_retrans_curPSN <= qv_retrans_curPSN + 1;
				end 
            end
            else begin
                qv_retrans_curPSN <= qv_retrans_curPSN;
            end
        end
        else begin
            // if(qv_retrans_PktLeftLen <= 32 && !i_header_to_rpg_prog_full && !i_nd_to_rpg_prog_full) begin
            if(qv_retrans_PktLeftLen <= 32 && !i_nd_to_rpg_prog_full) begin
                qv_retrans_curPSN <= qv_retrans_curPSN + 1;
            end
            else begin
                qv_retrans_curPSN <= qv_retrans_curPSN;
            end
        end
    end
    else begin
        qv_retrans_curPSN <= qv_retrans_curPSN;
    end
end

//-- qv_retrans_upper_bound -- Upper bound of PSN of retrnasmitter packet
//                              Except for RNR, each retransmission should continue to NPSN 
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_retrans_upper_bound <= 'd0;
    end
    else if (RRC_cur_state != RRC_RETRANS_s && RRC_next_state == RRC_RETRANS_s) begin
        if(qv_event_num == `RNR_TIMER_EVENT) begin
            qv_retrans_upper_bound <= wv_UnAckedPSN;
        end
        else if(qv_event_num == `LOSS_TIMER_EVENT) begin
            qv_retrans_upper_bound <= wv_NextPSN - 1;
        end
        else begin
            case(wv_opcode)
                `ACKNOWLEDGE:               if(wv_syndrome_high2 == `SYNDROME_ACK) begin
                                                if(w_pending_read) begin
                                                    qv_retrans_upper_bound <= wv_NextPSN - 1;
                                                end
                                                else begin
                                                    qv_retrans_upper_bound <= qv_retrans_upper_bound;
                                                end
                                            end
                                            else if(wv_syndrome_high2 == `SYNDROME_RNR || wv_syndrome_high2 == `SYNDROME_NAK) begin
                                                if(wv_syndrome_high2 == `SYNDROME_RNR) begin
                                                    qv_retrans_upper_bound <= wv_ReceivedPSN - 1; //RNR NAK cannot be immediately retrnasmitted
                                                end
                                                else if(wv_syndrome_high2 == `SYNDROME_NAK && wv_syndrome_low5 == `NAK_PSN_SEQUENCE_ERROR) begin
                                                    qv_retrans_upper_bound <= wv_NextPSN - 1;
                                                end
                                                else begin  //Other NAK types does not need to retransmit
                                                    qv_retrans_upper_bound <= qv_retrans_upper_bound;                                                     
                                                end
                                            end
                                            else begin
                                                qv_retrans_upper_bound <= qv_retrans_upper_bound;
                                            end
                `RDMA_READ_RESPONSE_FIRST:  qv_retrans_upper_bound <= wv_NextPSN - 1;
                `RDMA_READ_RESPONSE_ONLY:   qv_retrans_upper_bound <= wv_NextPSN - 1;
                `RDMA_READ_RESPONSE_MIDDLE: qv_retrans_upper_bound <= wv_NextPSN - 1;
                `RDMA_READ_RESPONSE_LAST:   qv_retrans_upper_bound <= wv_NextPSN - 1;
                default:                    qv_retrans_upper_bound <= qv_retrans_upper_bound;
            endcase
        end  
    end
    else begin
        qv_retrans_upper_bound <= qv_retrans_upper_bound;
    end
end

/*************************************************** End ***********************************************************************/


/*************************************************** Pkt Flush Related : Begin ***********************************************************************/
wire 					w_flush_read;
assign w_flush_read = (qv_flush_counter == 'd0 ? w_cur_flush_is_read : q_cur_flush_is_read);

reg 	[23:0]			qv_flush_incr_psn;
always @(*) begin
	if(rst) begin
		qv_flush_incr_psn = 'd0;
	end 
	else if(RRC_cur_state == RRC_WQE_FLUSH_s) begin
		if(w_flush_read) begin
			case(wv_PMTU)
				1:		qv_flush_incr_psn = (wv_Read_DMALen[7:0] != 'd0) ? wv_Read_DMALen[31:8] + 1 : wv_Read_DMALen[31:8];
				2:		qv_flush_incr_psn = (wv_Read_DMALen[8:0] != 'd0) ? wv_Read_DMALen[31:9] + 1 : wv_Read_DMALen[31:9];
				3:		qv_flush_incr_psn = (wv_Read_DMALen[9:0] != 'd0) ? wv_Read_DMALen[31:10] + 1 : wv_Read_DMALen[31:10];
				4:		qv_flush_incr_psn = (wv_Read_DMALen[10:0] != 'd0) ? wv_Read_DMALen[31:11] + 1 : wv_Read_DMALen[31:11];
				5:		qv_flush_incr_psn = (wv_Read_DMALen[11:0] != 'd0) ? wv_Read_DMALen[31:12] + 1 : wv_Read_DMALen[31:12];
				default:	qv_flush_incr_psn = 'd0;
			endcase 
		end 
		else begin
			qv_flush_incr_psn = 'd1;
		end 
	end 
	else begin
		qv_flush_incr_psn = 'd1;
	end 
end 

assign w_gen_cpl_during_flush = ((qv_flush_counter != 0 && qv_flush_PktLeftLen <= 32) || (qv_flush_counter == 0 && wv_flush_curPktLen == 0)) &&
                                    ((qv_flush_curOP == `SEND_ONLY || qv_flush_curOP == `SEND_ONLY_WITH_IMM || qv_flush_curOP == `SEND_LAST || qv_flush_curOP == `SEND_LAST_WITH_IMM ||
                                    qv_flush_curOP == `RDMA_WRITE_ONLY || qv_flush_curOP == `RDMA_WRITE_ONLY_WITH_IMM || qv_flush_curOP == `RDMA_WRITE_LAST ||
                                    qv_flush_curOP == `RDMA_WRITE_LAST_WITH_IMM || qv_flush_curOP == `RDMA_READ_REQUEST));

//-- w_flush_finish -- Indicates whether all the requests in the pkt buffer has been flushed
// assign w_flush_finish = (qv_flush_curPSN + 1) == qv_flush_upper_bound) && ((qv_flush_counter != 0 && qv_flush_PktLeftLen <= 32) || (qv_flush_counter == 0 && wv_flush_curPktLen == 0));
assign w_flush_finish = (w_rpb_empty && w_swpb_empty) || 	//Case 1
						(((w_gen_cpl_during_flush && w_cpl_can_be_upload) || !w_gen_cpl_during_flush) && (qv_flush_curPSN + qv_flush_incr_psn == wv_NextPSN) &&
						((qv_flush_counter != 0 && qv_flush_PktLeftLen <= 32) || (qv_flush_counter == 0 && wv_flush_curPktLen == 0))) || //Case 2
						(qv_flush_curPSN == wv_NextPSN);

//-- wv_flush_curPktLen -- 
assign wv_flush_curPktLen = w_flush_read ? 0 : {iv_swpb_content_doutb[94:88], iv_swpb_content_doutb[61:56]};

//PSN comparison of Read Buffer and Send/Write Buffer
//-- w_cur_flush_is_read --
assign w_cur_flush_is_read = w_rpb_empty ? 1'b0 : (w_swpb_empty ? 1'b1 : (iv_rpb_content_doutb[87:64] > iv_swpb_content_doutb[87:64] ? 0 : 1));

//-- q_cur_flush_is_read --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_cur_flush_is_read <= 1'b0;        
    end
    else if (RRC_cur_state == RRC_WQE_FLUSH_s && qv_flush_counter == 0) begin
        q_cur_flush_is_read <= w_cur_flush_is_read;
    end
    else begin
        q_cur_flush_is_read <= q_cur_flush_is_read;
    end
end

//-- qv_flush_curOP --
always @(*) begin
	if(rst) begin 
		qv_flush_curOP = `NONE_OPCODE;
	end 
	else if(RRC_cur_state == RRC_WQE_FLUSH_s && qv_flush_counter == 0) begin
		qv_flush_curOP = (w_flush_read) ? `RDMA_READ_REQUEST : iv_swpb_content_doutb[28:24];
	end 
	else begin
		qv_flush_curOP = qv_flush_curOP_TempReg;
	end
end 

//-- qv_flush_curOP_TempReg
always @(posedge clk or posedge rst) begin 
	if(rst) begin 
		qv_flush_curOP_TempReg <= `NONE_OPCODE;
	end 
	else begin
		qv_flush_curOP_TempReg <= qv_flush_curOP;
	end 
end 


//-- qv_flush_curPSN --	//Aborted, unused
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_flush_curPSN <= 'd0;        
    end
    else if (RRC_cur_state != RRC_WQE_FLUSH_s && RRC_next_state == RRC_WQE_FLUSH_s) begin 
        //qv_flush_curPSN <= wv_UnAckedPSN;
        qv_flush_curPSN <= w_flush_read ? iv_rpb_content_doutb[87:64] : iv_swpb_content_doutb[87:64];
    end
    //Add CPL judgement
    else if(RRC_cur_state == RRC_WQE_FLUSH_s && ((w_gen_cpl_during_flush && w_cpl_can_be_upload) || !w_gen_cpl_during_flush)) begin
        if(qv_flush_counter == 0 && wv_flush_curPktLen == 0) begin   
            qv_flush_curPSN <= qv_flush_curPSN + 1;
        end
        else if(qv_flush_counter > 0 && qv_flush_PktLeftLen <= 32) begin  
            qv_flush_curPSN <= qv_flush_curPSN + 1;
        end
        else begin
            qv_flush_curPSN <= qv_flush_curPSN;
        end
    end
    else begin
        qv_flush_curPSN <= qv_flush_curPSN;
    end
end

//-- qv_flush_counter -- Indicates how many 256-bit of a packet we have flushed, == 0 means we are dealing with packet header
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_flush_counter <= 'd0;        
    end
    else if (RRC_cur_state != RRC_WQE_FLUSH_s && RRC_next_state == RRC_WQE_FLUSH_s) begin
        qv_flush_counter <= 'd0;
    end
    //Add CPL judgement
    else if (RRC_cur_state == RRC_WQE_FLUSH_s && ((w_gen_cpl_during_flush && w_cpl_can_be_upload) || !w_gen_cpl_during_flush)) begin
        if(qv_flush_counter == 0) begin //Dealing with header
            if(wv_flush_curPktLen == 0) begin //No payload
                qv_flush_counter <= 'd0;
            end
            else begin
                qv_flush_counter <= qv_flush_counter + 1;
            end
        end
        else begin
            if(qv_flush_PktLeftLen <= 32) begin       //Last 256-bit of a Packet
                qv_flush_counter <= 'd0;
            end
            else begin
                 qv_flush_counter <= qv_flush_counter + 1;
            end 
        end 
    end
    else begin
        qv_flush_counter <= qv_flush_counter;
    end
end

//-- qv_flush_PktLeftLen -- 
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_flush_PktLeftLen <= 'd0;
    end
    //Add CPL judgement
    else if(RRC_cur_state == RRC_WQE_FLUSH_s && ((w_gen_cpl_during_flush && w_cpl_can_be_upload) || !w_gen_cpl_during_flush)) begin
        if(qv_flush_counter == 0) begin 
            qv_flush_PktLeftLen <= wv_flush_curPktLen;
        end
        else begin
            if(qv_flush_PktLeftLen <= 32) begin
                qv_flush_PktLeftLen <= 'd0;
            end
            else begin
                qv_flush_PktLeftLen <= qv_flush_PktLeftLen - 32;
            end 
        end
    end
    else begin
        qv_flush_PktLeftLen <= qv_flush_PktLeftLen;
    end
end

//-- qv_flush_upper_bound -- 
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_flush_upper_bound <= 'd0;
    end
    else if (RRC_cur_state != RRC_WQE_FLUSH_s && RRC_next_state == RRC_WQE_FLUSH_s) begin
        qv_flush_upper_bound <= wv_NextPSN;
    end
    else begin
        qv_flush_upper_bound <= qv_flush_upper_bound; 
    end
end


/*************************************************** End ***********************************************************************/


/*************************************************** Timer Related : Begin ***********************************************************************/

//-- q_rc_te_loss_wr_en --
//-- qv_rc_te_loss_data --
//Each time we release a packet, we need to send a timer event
//If all of the messages of current QP has been finished, we close the timer
//If not, we just reset the timer
always @(posedge clk or posedge rst) begin
    if (rst) begin
		q_rc_te_loss_wr_en <= 'd0;
		qv_rc_te_loss_data <= 'd0;
    end
    //Updata Timer: 1. In release state; 2. In buffer flush state; 3. In bad req state
    //Add CPL judgement
    else if(RRC_cur_state == RRC_RELEASE_s && ((w_gen_cpl_during_release && w_cpl_can_be_upload) || !w_gen_cpl_during_release)) begin
        if(((qv_release_counter != 0 && qv_release_PktLeftLen <= 32) || (qv_release_counter == 0 && wv_release_curPktLen == 0))
            && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_rc_te_loss_prog_full) begin //Meet the end of a pkt
                if(w_gen_cpl_during_release && i_rrc_resp_valid) begin
        			if((wv_swpb_head == wv_swpb_tail) && (wv_rpb_head == wv_rpb_tail)) begin 	//The last packet has been released, Shut down the timer
        				q_rc_te_loss_wr_en <= 'd1;
        				qv_rc_te_loss_data <= {32'd0, qv_cur_event_QPN, `STOP_TIMER};
        			end 
        			else begin 			//There exists unACKed packet, reset timer
        				q_rc_te_loss_wr_en <= 'd1;
        				//qv_rc_te_loss_data <= {32'd0, qv_cur_event_QPN, `RESTART_TIMER};
        				qv_rc_te_loss_data <= {32'd0, qv_cur_event_QPN, `STOP_TIMER};		//Disable time out check
        			end 
                end
                else if(!w_gen_cpl_during_release) begin
                    if((wv_swpb_head == wv_swpb_tail) && (wv_rpb_head == wv_rpb_tail)) begin    //The last packet has been released, Shut down the timer
                        q_rc_te_loss_wr_en <= 'd1;
                        qv_rc_te_loss_data <= {32'd0, qv_cur_event_QPN, `STOP_TIMER};
                    end 
                    else begin          //There exists unACKed packet, reset timer
                        q_rc_te_loss_wr_en <= 'd1;
                        //qv_rc_te_loss_data <= {32'd0, qv_cur_event_QPN, `RESTART_TIMER};
                        qv_rc_te_loss_data <= {32'd0, qv_cur_event_QPN, `STOP_TIMER};		//Disable time out check
                    end                     
                end
                else begin
                    q_rc_te_loss_wr_en <= 'd0;
                    qv_rc_te_loss_data <= qv_rc_te_loss_data;
                end
        end
        else begin
			q_rc_te_loss_wr_en <= 'd0;
			qv_rc_te_loss_data <= 'd0;
        end
    end
	else if(RRC_cur_state == RRC_UPDATE_ENTRY_s || RRC_cur_state == RRC_RELEASE_ENTRY_s) begin	//When dealing with a expected READ Response, Restart timer
		q_rc_te_loss_wr_en <= 'd1;
		//qv_rc_te_loss_data <= {32'd0, qv_cur_event_QPN, `RESTART_TIMER};
		qv_rc_te_loss_data <= {32'd0, qv_cur_event_QPN, `STOP_TIMER};
	end 
    else if(RRC_cur_state == RRC_READ_COMPLETION_s) begin
        if(!w_pending_read && !w_pending_send_write && !i_rc_te_loss_prog_full && w_cpl_can_be_upload) begin
			if((wv_swpb_head == wv_swpb_tail) && (wv_rpb_head == wv_rpb_tail)) begin 	//Close the timer
				q_rc_te_loss_wr_en <= 'd1;
				qv_rc_te_loss_data <= {32'd0, qv_cur_event_QPN, `STOP_TIMER};
			end  
			else begin 	//Reset the timer
				q_rc_te_loss_wr_en <= 'd1;
				//qv_rc_te_loss_data <= {32'd0, qv_cur_event_QPN, `RESTART_TIMER};
				qv_rc_te_loss_data <= {32'd0, qv_cur_event_QPN, `STOP_TIMER};
			end 
        end
        else begin
			q_rc_te_loss_wr_en <= 'd0;
			qv_rc_te_loss_data <= 'd0;
        end
    end
    else if(RRC_cur_state == RRC_WQE_FLUSH_s) begin
//        if((qv_flush_counter != 0 && qv_flush_PktLeftLen <= 32) || (qv_flush_counter == 0 && wv_flush_curPktLen == 0)) begin //Meet the end of a pkt
//                if(w_gen_cpl_during_flush && w_cpl_can_be_upload && (wv_swpb_head == wv_swpb_tail) && (wv_rpb_head == wv_rpb_tail)) begin //Last message in the buffer
//                    q_rc_te_loss_wr_en <= 'd1;
//                    qv_rc_te_loss_data <= {32'd0, qv_cur_event_QPN, `STOP_TIMER};
//                end
//                //else if(!w_gen_cpl_during_release) begin
//                //    q_rc_te_loss_wr_en <= 'd1;
//                //    qv_rc_te_loss_data <= {32'd0, qv_cur_event_QPN, `STOP_TIMER};             
//                //end
//                else begin
//                    q_rc_te_loss_wr_en <= 'd1;
//                    //qv_rc_te_loss_data <= {32'd0, qv_cur_event_QPN, `RESTART_TIMER};             
//        			qv_rc_te_loss_data <= {21'd0, 8'd3, 3'd3, qv_cur_event_QPN, `SET_TIMER};
//				end
//                //else begin
//                //    q_rc_te_loss_wr_en <= 'd0;
//                //    qv_rc_te_loss_data <= qv_rc_te_loss_data;
//                //end
//        end
        if(w_flush_finish) begin //End of a flush
            if((wv_swpb_head == wv_swpb_tail) && (wv_rpb_head == wv_rpb_tail)) begin //Last message in the buffer
                q_rc_te_loss_wr_en <= 'd1;
                qv_rc_te_loss_data <= {32'd0, qv_cur_event_QPN, `STOP_TIMER};
            end
            else begin
                q_rc_te_loss_wr_en <= 'd1;
                //qv_rc_te_loss_data <= {32'd0, qv_cur_event_QPN, `RESTART_TIMER};             
        		qv_rc_te_loss_data <= {21'd0, 8'd3, 3'd3, qv_cur_event_QPN, `STOP_TIMER};
			end
        end
        else begin
			q_rc_te_loss_wr_en <= 'd0;
			qv_rc_te_loss_data <= 'd0;
        end
    end
    else if(RRC_cur_state == RRC_BAD_REQ_s) begin 	//Just close the timer
        if(w_rpb_empty && w_swpb_empty && w_cpl_can_be_upload) begin
			q_rc_te_loss_wr_en <= 'd1;
			qv_rc_te_loss_data <= {32'd0, qv_cur_event_QPN, `STOP_TIMER};
        end
        else begin
			q_rc_te_loss_wr_en <= 'd0;
			qv_rc_te_loss_data <= 'd0;
        end
    end
    else begin
		q_rc_te_loss_wr_en <= 'd0;
		qv_rc_te_loss_data <= 'd0;
    end
end



//-- q_loss_expire_rd_en --
//UNCERTAIN
always @(*) begin
	if(rst) begin
		q_loss_expire_rd_en = 'd0;
	end
	else if(RRC_pre_state == RRC_FETCH_CXT_s && RRC_cur_state == RRC_RESP_CXT_s && qv_event_num == `LOSS_TIMER_EVENT) begin
		q_loss_expire_rd_en = !i_loss_expire_empty;
	end 
	else begin
		q_loss_expire_rd_en = 'd0;
	end 
end


//-- q_rc_te_rnr_wr_en --
//-- qv_rc_te_rnr_data --
//UNCERTAIN
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_rc_te_rnr_wr_en <= 'd0;
        qv_rc_te_rnr_data <= 'd0;
    end
    else begin
        q_rc_te_rnr_wr_en <= 'd0;
        qv_rc_te_rnr_data <= 'd0;        
    end
 end 
                

//-- q_rnr_expire_rd_en --
//UNCERTAIN
always @(*) begin
	if(rst) begin
		q_rnr_expire_rd_en = 'd0;
	end
	else if(RRC_pre_state == RRC_FETCH_CXT_s && RRC_cur_state == RRC_RESP_CXT_s && qv_event_num == `RNR_TIMER_EVENT) begin
		q_rnr_expire_rd_en = !i_rnr_expire_empty;
	end 
	else begin
		q_rnr_expire_rd_en = 'd0;
	end 
end

/*************************************************** End ***********************************************************************/


/************************************************ Packet Buffer Control : Begin ************************************************/
//-- qv_mandatory_counter -- This counter is used to force <FETCH_CXT> --> <RESP_CXT> transition to wait for two cycles.
/*   Detailed explanation   -- At the time when we get context back, we need to judge which state we are going to, i.e., the dout of ListTable should be on the wire.
                            -- Since table dout lags one cycle behind addr, the timing sequence shoule be:
                            -- Cycle 0: Change ListTable addr(reg) to QPN based on event type
                            -- Cycle 1: ListTable addr(reg) has changed to QPN, and at the next cycle we can obtain Metadata
                            -- Cycle 2: Metadata on the wire(head, tail, empty), we judge next state transition
                            -- If we apply Cycle 0 to <IDLE>, the timing sequence should be as follows:

    State:                    IDLE        FETCH       RESP        ????
                              _____       _____       _____       _____
    clk:                _____|     |_____|     |_____|     |_____|     |_____
    
    cycle count:                0           1           2           3
                        _____________________________ _______________________
  Cxt Resp(Wire):       _____________________________X____CxtInfo____________
      
                        _____ _______________________________________________
 srcQPN(wire):          _____X____qpn________________________________________

                        _________________ ___________________________________
 List table addr(reg):  _________________X____qpn____________________________

                        _____________________________ _______________________
 List table dout:       _____________________________X____<Head,Tail>________

                            However, the problem is we can not obtain "qpn" at clock 0, since there are many types of events, 
                            we consume one cycle at IDLE to decide which event to schedule, hence "qpn" is decided at clock 1, 
                            all the following changes are delayed 1 cycle. Although we could reuse the logic in event schedule 
                            to obtain "qpn" at IDLE, but that will makes the code hard to understand and mixed. Hence we add a 
                            Mandatory counter to force RESP substain for at least two cycles(although CxtInfo may not come back 
                            at one cycle :-), we still force this to happen ) to obtain correct List Table Dout. Then the timing 
                            sequence becomes like this:

     State:                    IDLE        FETCH       RESP        RESP       ????
                              _____       _____       _____       _____       _____
    clk:                _____|     |_____|     |_____|     |_____|     |_____|     |_____
    
    cycle count:                0           1           2           3           4
                        _____________________________ ___________________________________
  Cxt Resp(Wire):       _____________________________X____CxtInfo________________________
      
                        _____ ___________________________________________________________
 srcQPN of events(wire):_____X____qpn____________________________________________________

                        _________________________________________________________________
 List table addr(reg):  _____________________________X__qpn______________________________

                        __________________________________________ ______________________
 List table dout:       __________________________________________X__<Head,Tail>_________                           

*/

always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_mandatory_counter <= 'd0;        
    end
    else if (RRC_cur_state == RRC_RESP_CXT_s) begin
        qv_mandatory_counter <= qv_mandatory_counter + 1;
    end
    else begin
        qv_mandatory_counter <= 0;
    end
end

reg     [23:0]          qv_fetch_QPN;
//-- qv_fetch_QPN --    Used only for Fetch Cxt, we then use qv_cur_event_QPN instead.
always @(*) begin
    if(RRC_cur_state == RRC_FETCH_CXT_s) begin
        case(qv_event_num) 
            `RNR_TIMER_EVENT:   qv_fetch_QPN = wv_rnr_timer_QPN;
            `LOSS_TIMER_EVENT:  qv_fetch_QPN = wv_loss_timer_QPN;
            `BAD_REQ_EVENT:     qv_fetch_QPN = wv_bad_req_QPN;
            `PKT_EVENT:         qv_fetch_QPN = wv_PktQPN;
            default:            qv_fetch_QPN = 'd0;
        endcase
    end
    else begin
        qv_fetch_QPN = 0;
    end
end

//-- qv_cur_event_QPN --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_cur_event_QPN <= 'd0;        
    end
    else if (RRC_cur_state == RRC_FETCH_CXT_s) begin
         case(qv_event_num)
            `RNR_TIMER_EVENT:   qv_cur_event_QPN <= wv_rnr_timer_QPN;
            `LOSS_TIMER_EVENT:  qv_cur_event_QPN <= wv_loss_timer_QPN;
            `BAD_REQ_EVENT:     qv_cur_event_QPN <= wv_bad_req_QPN;
            `PKT_EVENT:         qv_cur_event_QPN <= wv_PktQPN;
            default:            qv_cur_event_QPN <= qv_cur_event_QPN;
         endcase        
    end
    else begin
        qv_cur_event_QPN <= qv_cur_event_QPN;
    end
end

//RDMA Read Buffer control
//-- qv_rpb_list_table_init_counter --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_rpb_list_table_init_counter <= 'd0;        
    end
    else if (RRC_cur_state == RRC_INIT_s && qv_rpb_list_table_init_counter < `QP_NUM - 1) begin
        qv_rpb_list_table_init_counter <= qv_rpb_list_table_init_counter + 1;
    end
    else begin
        qv_rpb_list_table_init_counter <= qv_rpb_list_table_init_counter;
    end
end

//-- q_rpb_list_head_web --
//-- qv_rpb_list_head_addrb --
//-- qv_rpb_list_head_dinb -- 
//-- q_rpb_list_empty_web --
//-- qv_rpb_list_empty_addrb --
//-- qv_rpb_list_empty_dinb --
//-- qv_rpb_list_tail_web --
//-- qv_rpb_list_tail_addrb --
//-- qv_rpb_list_tail_dinb --
always @(*) begin
    case(RRC_cur_state)
        RRC_INIT_s:         if(qv_rpb_list_table_init_counter <= `QP_NUM - 1) begin
                                q_rpb_list_head_web = 1'b1;
                                qv_rpb_list_head_addrb = qv_rpb_list_table_init_counter;
                                qv_rpb_list_head_dinb = 'd0;
                                q_rpb_list_empty_web = 1'b1;
                                qv_rpb_list_empty_addrb = qv_rpb_list_table_init_counter;
                                qv_rpb_list_empty_dinb = 1'b1;   
                                q_rpb_list_tail_web = 1'b1;
                                qv_rpb_list_tail_addrb = qv_rpb_list_table_init_counter;
                                qv_rpb_list_tail_dinb = 'd0;      
                            end
                            else begin
                                q_rpb_list_head_web = 1'b0;
                                qv_rpb_list_head_addrb = qv_rpb_list_table_init_counter;
                                qv_rpb_list_head_dinb = 'd0;
                                q_rpb_list_empty_web = 1'b0;
                                qv_rpb_list_empty_addrb = qv_rpb_list_table_init_counter;
                                qv_rpb_list_empty_dinb = 1'b0;   
                                q_rpb_list_tail_web = 1'b0;
                                qv_rpb_list_tail_addrb = qv_rpb_list_table_init_counter;
                                qv_rpb_list_tail_dinb = 'd0;                                   
                            end
        RRC_FETCH_CXT_s:    begin
                                case(qv_event_num)
                                    `RNR_TIMER_EVENT:   begin 
                                                            q_rpb_list_head_web = 1'b0;
                                                            qv_rpb_list_head_addrb = wv_rnr_timer_QPN;
                                                            qv_rpb_list_head_dinb = 'd0;
                                                            q_rpb_list_empty_web = 1'b0;
                                                            qv_rpb_list_empty_addrb = wv_rnr_timer_QPN;
                                                            qv_rpb_list_empty_dinb = 'd0;   
                                                            q_rpb_list_tail_web = 1'b0;
                                                            qv_rpb_list_tail_addrb = wv_rnr_timer_QPN;
                                                            qv_rpb_list_tail_dinb = 'd0;                                                            
                                                        end 
                                    `LOSS_TIMER_EVENT:  begin 
                                                            q_rpb_list_head_web = 1'b0;
                                                            qv_rpb_list_head_addrb = wv_loss_timer_QPN;
                                                            qv_rpb_list_head_dinb = 'd0;
                                                            q_rpb_list_empty_web = 1'b0;
                                                            qv_rpb_list_empty_addrb = wv_loss_timer_QPN;
                                                            qv_rpb_list_empty_dinb = 'd0;  
                                                            q_rpb_list_tail_web = 1'b0;
                                                            qv_rpb_list_tail_addrb = wv_loss_timer_QPN;
                                                            qv_rpb_list_tail_dinb = 'd0;                                                                                                                       
                                                        end 
                                    `BAD_REQ_EVENT:     begin
                                                            q_rpb_list_head_web = 1'b0;
                                                            qv_rpb_list_head_addrb = wv_bad_req_QPN;
                                                            qv_rpb_list_head_dinb = 'd0;
                                                            q_rpb_list_empty_web = 1'b0;
                                                            qv_rpb_list_empty_addrb = wv_bad_req_QPN;
                                                            qv_rpb_list_empty_dinb = 'd0;     
                                                            q_rpb_list_tail_web = 1'b0;
                                                            qv_rpb_list_tail_addrb = wv_bad_req_QPN;
                                                            qv_rpb_list_tail_dinb = 'd0;                                                                                                                    
                                                        end
                                    `PKT_EVENT:         begin 
                                                            q_rpb_list_head_web = 1'b0;
                                                            qv_rpb_list_head_addrb = wv_PktQPN;
                                                            qv_rpb_list_head_dinb = 'd0;
                                                            q_rpb_list_empty_web = 1'b0;
                                                            qv_rpb_list_empty_addrb = wv_PktQPN;
                                                            qv_rpb_list_empty_dinb = 'd0;   
                                                            q_rpb_list_tail_web = 1'b0;
                                                            qv_rpb_list_tail_addrb = wv_PktQPN;
                                                            qv_rpb_list_tail_dinb = 'd0;                                                                                                                      
                                                        end 
                                    default:            begin 
                                                            q_rpb_list_head_web = 1'b0;
                                                            qv_rpb_list_head_addrb = 'd0;
                                                            qv_rpb_list_head_dinb = 'd0;
                                                            q_rpb_list_empty_web = 1'b0;
                                                            qv_rpb_list_empty_addrb = 'd0;
                                                            qv_rpb_list_empty_dinb = 'd0;
                                                            q_rpb_list_tail_web = 1'b0;
                                                            qv_rpb_list_tail_addrb = 'd0;
                                                            qv_rpb_list_tail_dinb = 'd0;                                                             
                                                        end
                                endcase
                            end
                            //In RRC_RELEASE_s, RPB should not be touched, it should be modified in RRC_SCATTER_DATA_s
        // RRC_RELEASE_s:      if(w_cur_release_is_read) begin //Directly updates head pointer
        //                         if(wv_rpb_head == wv_rpb_tail) begin //After this release, the RPB will be empty
        //                             q_rpb_list_head_web = 1'b1;
        //                             qv_rpb_list_head_addrb = qv_cur_event_QPN;
        //                             qv_rpb_list_head_dinb = iv_rpb_next_doutb;  //Head points to next element     
        //                             q_rpb_list_empty_web = 1'b1;
        //                             qv_rpb_list_empty_addrb = qv_cur_event_QPN;
        //                             qv_rpb_list_empty_dinb = 1'b1; 
        //                             q_rpb_list_tail_web = 1'b0;
        //                             qv_rpb_list_tail_addrb = qv_cur_event_QPN;
        //                             qv_rpb_list_tail_dinb = 'd0;                                
        //                         end
        //                         else begin
        //                             q_rpb_list_head_web = 1'b1;
        //                             qv_rpb_list_head_addrb = qv_cur_event_QPN;
        //                             qv_rpb_list_head_dinb = iv_rpb_next_doutb;  //Head points to next element     
        //                             q_rpb_list_empty_web = 1'b0;
        //                             qv_rpb_list_empty_addrb = qv_cur_event_QPN;
        //                             qv_rpb_list_empty_dinb = 1'b0;
        //                             q_rpb_list_tail_web = 1'b0;
        //                             qv_rpb_list_tail_addrb = qv_cur_event_QPN;
        //                             qv_rpb_list_tail_dinb = 'd0;                                      
        //                         end
        //                     end
        //                     else begin  
        RRC_RELEASE_s:	begin
                                q_rpb_list_head_web = 1'b0;
                                qv_rpb_list_head_addrb = qv_cur_event_QPN;
                                qv_rpb_list_head_dinb = 'd0;
                                q_rpb_list_empty_web = 1'b0;
                                qv_rpb_list_empty_addrb = qv_cur_event_QPN;
                                qv_rpb_list_empty_dinb = 'd0;
                                q_rpb_list_tail_web = 1'b0;
                                qv_rpb_list_tail_addrb = qv_cur_event_QPN;
                                qv_rpb_list_tail_dinb = 'd0;                                
                        end
        RRC_WQE_FLUSH_s: if(w_flush_read && w_cpl_can_be_upload) begin //Directly updates head pointer
                                if(wv_rpb_head == wv_rpb_tail) begin //After this release, the RPB will be empty
                                    q_rpb_list_head_web = 1'b1;
                                    qv_rpb_list_head_addrb = qv_cur_event_QPN;
                                    qv_rpb_list_head_dinb = iv_rpb_next_doutb;  //Head points to next element     
                                    q_rpb_list_empty_web = 1'b1;
                                    qv_rpb_list_empty_addrb = qv_cur_event_QPN;
                                    qv_rpb_list_empty_dinb = 1'b1; 
                                    q_rpb_list_tail_web = 1'b0;
                                    qv_rpb_list_tail_addrb = qv_cur_event_QPN;
                                    qv_rpb_list_tail_dinb = 'd0;                                
                                end
                                else begin
                                    q_rpb_list_head_web = 1'b1;
                                    qv_rpb_list_head_addrb = qv_cur_event_QPN;
                                    qv_rpb_list_head_dinb = iv_rpb_next_doutb;  //Head points to next element     
                                    q_rpb_list_empty_web = 1'b0;
                                    qv_rpb_list_empty_addrb = qv_cur_event_QPN;
                                    qv_rpb_list_empty_dinb = 1'b0;
                                    q_rpb_list_tail_web = 1'b0;
                                    qv_rpb_list_tail_addrb = qv_cur_event_QPN;
                                    qv_rpb_list_tail_dinb = 'd0;                                      
                                end
                            end
                            else begin  
                                q_rpb_list_head_web = 1'b0;
                                qv_rpb_list_head_addrb = qv_cur_event_QPN;
                                qv_rpb_list_head_dinb = 'd0;
                                q_rpb_list_empty_web = 1'b0;
                                qv_rpb_list_empty_addrb = qv_cur_event_QPN;
                                qv_rpb_list_empty_dinb = 'd0;
                                q_rpb_list_tail_web = 1'b0;
                                qv_rpb_list_tail_addrb = qv_cur_event_QPN;
                                qv_rpb_list_tail_dinb = 'd0;                                
                            end
        RRC_RELEASE_ENTRY_s:    //When release an entry, we may finish a read req 
                            if(w_cur_read_finish) begin
                                if(wv_rpb_head == wv_rpb_tail) begin //After this release, the RPB will be empty
                                    q_rpb_list_head_web = 1'b1;
                                    qv_rpb_list_head_addrb = qv_cur_event_QPN;
                                    qv_rpb_list_head_dinb = iv_rpb_list_head_doutb;  //Head points to next element     
                                    q_rpb_list_empty_web = 1'b1;
                                    qv_rpb_list_empty_addrb = qv_cur_event_QPN;
                                    qv_rpb_list_empty_dinb = 1'b1; 
                                    q_rpb_list_tail_web = 1'b0;
                                    qv_rpb_list_tail_addrb = qv_cur_event_QPN;
                                    qv_rpb_list_tail_dinb = 'd0;                                
                                end
                                else begin
                                    q_rpb_list_head_web = 1'b1;
                                    qv_rpb_list_head_addrb = qv_cur_event_QPN;
                                    qv_rpb_list_head_dinb = iv_rpb_next_doutb;  //Head points to next element     
                                    q_rpb_list_empty_web = 1'b0;
                                    qv_rpb_list_empty_addrb = qv_cur_event_QPN;
                                    qv_rpb_list_empty_dinb = 1'b0;
                                    q_rpb_list_tail_web = 1'b0;
                                    qv_rpb_list_tail_addrb = qv_cur_event_QPN;
                                    qv_rpb_list_tail_dinb = 'd0;                                      
                                end                                
                            end            
                            else begin  
                                q_rpb_list_head_web = 1'b0;
                                qv_rpb_list_head_addrb = qv_cur_event_QPN;
                                qv_rpb_list_head_dinb = 'd0;
                                q_rpb_list_empty_web = 1'b0;
                                qv_rpb_list_empty_addrb = qv_cur_event_QPN;
                                qv_rpb_list_empty_dinb = 'd0;
                                q_rpb_list_tail_web = 1'b0;
                                qv_rpb_list_tail_addrb = qv_cur_event_QPN;
                                qv_rpb_list_tail_dinb = 'd0;                                
                            end
        default:            begin
                                q_rpb_list_head_web = 1'b0;
                                qv_rpb_list_head_addrb = qv_cur_event_QPN;
                                qv_rpb_list_head_dinb = 'd0;   
                                q_rpb_list_empty_web = 1'b0;
                                qv_rpb_list_empty_addrb = qv_cur_event_QPN;
                                qv_rpb_list_empty_dinb = 'd0;
                                q_rpb_list_tail_web = 1'b0;
                                qv_rpb_list_tail_addrb = qv_cur_event_QPN;
                                qv_rpb_list_tail_dinb = 'd0;   
                            end
    endcase
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_rpb_content_addrb_TempReg <= 'd0;
        qv_rpb_next_addrb_TempReg <= 'd0;
    end
    else begin
        qv_rpb_content_addrb_TempReg <= qv_rpb_content_addrb;
        qv_rpb_next_addrb_TempReg <= qv_rpb_next_addrb;
    end
end

//-- q_rpb_content_web --
//-- qv_rpb_content_addrb --
//-- qv_rpb_content_dinb --
//-- q_rpb_next_web --
//-- qv_rpb_next_addrb --
//-- qv_rpb_next_dinb --
always @(*) begin
    case(RRC_cur_state) 
        RRC_INIT_s:         if(qv_rpb_next_table_init_counter <= `RPB_CONTENT_FREE_NUM - 1) begin
                                q_rpb_next_web = 1'b1;
                                qv_rpb_next_addrb = qv_rpb_next_table_init_counter;
                                qv_rpb_next_dinb = 'd0;
//content init is moved to RTC
                            	//q_rpb_content_web = 1'b1;
                            	q_rpb_content_web = 1'b0;
                            	qv_rpb_content_addrb = qv_rpb_free_init_counter;
                            	qv_rpb_content_dinb = 'd0;                          
                            end
                            else begin
                                q_rpb_next_web = 1'b0;
                                qv_rpb_next_addrb = qv_rpb_next_table_init_counter;
                                qv_rpb_next_dinb = 'd0;
                            	q_rpb_content_web = 1'b0;
                            	qv_rpb_content_addrb = qv_rpb_free_init_counter;
                            	qv_rpb_content_dinb = 'd0;                          
                            end
        RRC_RESP_CXT_s: begin
                            q_rpb_content_web = 1'b0;
                            qv_rpb_content_addrb = wv_rpb_head;
                            qv_rpb_content_dinb = 'd0;                          
                            q_rpb_next_web = 1'b0;
                            qv_rpb_next_addrb = wv_rpb_head;
                            qv_rpb_next_dinb = 'd0;      
                        end
        RRC_RELEASE_s:  if(q_cur_release_is_read) begin     //Should never come into this branch
                            q_rpb_content_web = 1'b0;
                            qv_rpb_content_addrb = iv_rpb_next_doutb;
                            qv_rpb_content_dinb = 'd0;
                            q_rpb_next_web = 1'b0;
                            qv_rpb_next_addrb = iv_rpb_next_doutb;
                            qv_rpb_next_dinb = 'd0;  
                        end
                        else begin
                            q_rpb_content_web = 1'b0;
                            qv_rpb_content_addrb = qv_rpb_content_addrb_TempReg;
                            qv_rpb_content_dinb = 'd0;
                            q_rpb_next_web = 1'b0;
                            qv_rpb_next_addrb = qv_rpb_next_addrb_TempReg;
                            qv_rpb_next_dinb = 'd0;  
                        end
        RRC_WQE_FLUSH_s:  
                        // if(q_cur_flush_is_read && ((w_gen_cpl_during_flush && w_cpl_can_be_upload) || !w_gen_cpl_during_flush)) begin
                        if(w_flush_read &&  w_cpl_can_be_upload) begin //Read must gen CPL, does not judge gen_cpl_during_flush
                            q_rpb_content_web = 1'b0;
                            qv_rpb_content_addrb = iv_rpb_next_doutb;
                            qv_rpb_content_dinb = 'd0;
                            q_rpb_next_web = 1'b0;
                            qv_rpb_next_addrb = iv_rpb_next_doutb;
                            qv_rpb_next_dinb = 'd0;  
                        end
                        else begin
                            q_rpb_content_web = 1'b0;
                            qv_rpb_content_addrb = qv_rpb_content_addrb_TempReg;
                            qv_rpb_content_dinb = 'd0;
                            q_rpb_next_web = 1'b0;
                            qv_rpb_next_addrb = qv_rpb_next_addrb_TempReg;
                            qv_rpb_next_dinb = 'd0;  
                        end
        RRC_RETRANS_s:  if(q_cur_retrans_is_read && qv_rpb_content_addrb_TempReg != wv_rpb_tail) begin	//Current is not tail, we point to next
                            if(!i_header_to_rpg_prog_full) begin
                                q_rpb_content_web = 1'b0;
                                qv_rpb_content_addrb = iv_rpb_next_doutb;
                                qv_rpb_content_dinb = 'd0; 
                                q_rpb_next_web = 1'b0;
                                qv_rpb_next_addrb = iv_rpb_next_doutb;
                                qv_rpb_next_dinb = 'd0;   
                            end
                            else begin
                                q_rpb_content_web = 1'b0;
                                qv_rpb_content_addrb = qv_rpb_content_addrb_TempReg;
                                qv_rpb_content_dinb = 'd0; 
                                q_rpb_next_web = 1'b0;
                                qv_rpb_next_addrb = qv_rpb_next_addrb_TempReg;
                                qv_rpb_next_dinb = 'd0;  
                            end
                        end
                        else begin
                            q_rpb_content_web = 1'b0;
                            qv_rpb_content_addrb = qv_rpb_content_addrb_TempReg;
                            qv_rpb_content_dinb = 'd0;
                            q_rpb_next_web = 1'b0;
                            qv_rpb_next_addrb = qv_rpb_next_addrb_TempReg;
                            qv_rpb_next_dinb = 'd0;  
                        end
        default:        begin
                            q_rpb_content_web = 1'b0;
                            qv_rpb_content_addrb = wv_rpb_head;
                            qv_rpb_content_dinb = 'd0;
                            q_rpb_next_web = 1'b0;
                            qv_rpb_next_addrb = wv_rpb_head;
                            qv_rpb_next_dinb = 'd0; 
                        end    
    endcase
end

//-- qv_rpb_free_init_counter --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_rpb_free_init_counter <= 'd0;
    end
    else if (RRC_cur_state == RRC_INIT_s && qv_rpb_free_init_counter < `RPB_CONTENT_FREE_NUM - 1) begin
        qv_rpb_free_init_counter <= qv_rpb_free_init_counter + 1;
    end
    else begin
        qv_rpb_free_init_counter <= qv_rpb_free_init_counter;
    end
end

//-- qv_rpb_next_table_init_counter --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_rpb_next_table_init_counter <= 'd0;
    end
    else if (RRC_cur_state == RRC_INIT_s && qv_rpb_next_table_init_counter < `RPB_CONTENT_FREE_NUM - 1) begin
        qv_rpb_next_table_init_counter <= qv_rpb_next_table_init_counter + 1;
    end
    else begin
        qv_rpb_next_table_init_counter <= qv_rpb_next_table_init_counter;
    end
end

//-- qv_rpb_free_data --
//-- q_rpb_free_wr_en --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_rpb_free_wr_en <= 1'b0;
        qv_rpb_free_data <= 'd0;
    end
    else if (RRC_cur_state == RRC_INIT_s && (qv_rpb_free_init_counter == 0 || qv_rpb_free_data < qv_rpb_free_init_counter)) begin
        q_rpb_free_wr_en <= 1'b1;
        qv_rpb_free_data <= qv_rpb_free_init_counter;
    end
    //else if (RRC_cur_state == RRC_RELEASE_s && q_cur_release_is_read) begin
    //    q_rpb_free_wr_en <= 1'b1;
    //    if(qv_release_counter == 0) begin
    //        qv_rpb_free_data <= wv_rpb_head;            
    //    end
    //    else begin
    //        qv_rpb_free_data <= qv_rpb_content_addrb;
    //    end
    //end
    else if (RRC_cur_state == RRC_WQE_FLUSH_s && w_flush_read && w_cpl_can_be_upload) begin
        q_rpb_free_wr_en <= 1'b1;
        if(qv_release_counter == 0) begin
            qv_rpb_free_data <= wv_rpb_head;            
        end
        else begin
            qv_rpb_free_data <= qv_rpb_content_addrb;
        end
    end
    else if(RRC_cur_state == RRC_RELEASE_ENTRY_s && w_cur_read_finish) begin
        q_rpb_free_wr_en <= 1'b1;
        qv_rpb_free_data <= wv_rpb_head;        
    end
    else begin
        q_rpb_free_wr_en <= 1'b0;
        qv_rpb_free_data <= qv_rpb_free_data;
    end
end 

//Send/RDMA Write Buffer Control
//-- qv_swpb_list_table_init_counter --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_swpb_list_table_init_counter <= 'd0;        
    end
    else if (RRC_cur_state == RRC_INIT_s && qv_swpb_list_table_init_counter < `QP_NUM - 1) begin
        qv_swpb_list_table_init_counter <= qv_swpb_list_table_init_counter + 1;
    end
    else begin
        qv_swpb_list_table_init_counter <= qv_swpb_list_table_init_counter;
    end
end

//-- q_swpb_list_head_web --
//-- qv_swpb_list_head_addrb --
//-- qv_swpb_list_head_dinb --
//-- q_swpb_list_empty_web --
//-- qv_swpb_list_empty_addrb --
//-- qv_swpb_list_empty_dinb --
//-- q_swpb_list_tail_web --
//-- qv_swpb_list_tail_addrb --
//-- qv_swpb_list_tail_dinb --
always @(*) begin
    case(RRC_cur_state)
        RRC_INIT_s:         if(qv_swpb_list_table_init_counter <= `QP_NUM - 1) begin
                                q_swpb_list_head_web = 1'b1;
                                qv_swpb_list_head_addrb = qv_swpb_list_table_init_counter;
                                qv_swpb_list_head_dinb = 'd0;
                                q_swpb_list_empty_web = 1'b1;
                                qv_swpb_list_empty_addrb = qv_swpb_list_table_init_counter;
                                qv_swpb_list_empty_dinb = 1'b1;   
                                q_swpb_list_tail_web = 1'b1;
                                qv_swpb_list_tail_addrb = qv_swpb_list_table_init_counter;
                                qv_swpb_list_tail_dinb = 'd0;  
                            end
                            else begin
                                q_swpb_list_head_web = 1'b0;
                                qv_swpb_list_head_addrb = qv_swpb_list_table_init_counter;
                                qv_swpb_list_head_dinb = 'd0;
                                q_swpb_list_empty_web = 1'b0;
                                qv_swpb_list_empty_addrb = qv_swpb_list_table_init_counter;
                                qv_swpb_list_empty_dinb = 1'b1;   
                                q_swpb_list_tail_web = 1'b0;
                                qv_swpb_list_tail_addrb = qv_swpb_list_table_init_counter;
                                qv_swpb_list_tail_dinb = 'd0;                                  
                            end
        RRC_FETCH_CXT_s:    begin
                                case(qv_event_num)
                                    `RNR_TIMER_EVENT:   begin 
                                                            q_swpb_list_head_web = 1'b0;
                                                            qv_swpb_list_head_addrb = wv_rnr_timer_QPN;
                                                            qv_swpb_list_head_dinb = 'd0;
                                                            q_swpb_list_empty_web = 1'b0;
                                                            qv_swpb_list_empty_addrb = wv_rnr_timer_QPN;
                                                            qv_swpb_list_empty_dinb = 'd0;   
                                                            q_swpb_list_tail_web = 1'b0;
                                                            qv_swpb_list_tail_addrb = wv_rnr_timer_QPN;
                                                            qv_swpb_list_tail_dinb = 'd0;                                                                                                                      
                                                        end 
                                    `LOSS_TIMER_EVENT:  begin 
                                                            q_swpb_list_head_web = 1'b0;
                                                            qv_swpb_list_head_addrb = wv_loss_timer_QPN;
                                                            qv_swpb_list_head_dinb = 'd0;
                                                            q_swpb_list_empty_web = 1'b0;
                                                            qv_swpb_list_empty_addrb = wv_loss_timer_QPN;
                                                            qv_swpb_list_empty_dinb = 'd0;  
                                                            q_swpb_list_tail_web = 1'b0;
                                                            qv_swpb_list_tail_addrb = wv_loss_timer_QPN;
                                                            qv_swpb_list_tail_dinb = 'd0;                                                                                                                        
                                                        end 
                                    `BAD_REQ_EVENT:     begin
                                                            q_swpb_list_head_web = 1'b0;
                                                            qv_swpb_list_head_addrb = wv_bad_req_QPN;
                                                            qv_swpb_list_head_dinb = 'd0;
                                                            q_swpb_list_empty_web = 1'b0;
                                                            qv_swpb_list_empty_addrb = wv_bad_req_QPN;
                                                            qv_swpb_list_empty_dinb = 'd0;  
                                                            q_swpb_list_tail_web = 1'b0;
                                                            qv_swpb_list_tail_addrb = wv_bad_req_QPN;
                                                            qv_swpb_list_tail_dinb = 'd0;                                                                                                                        
                                                        end
                                    `PKT_EVENT:         begin 
                                                            q_swpb_list_head_web = 1'b0;
                                                            qv_swpb_list_head_addrb = wv_PktQPN;
                                                            qv_swpb_list_head_dinb = 'd0;
                                                            q_swpb_list_empty_web = 1'b0;
                                                            qv_swpb_list_empty_addrb = wv_PktQPN;
                                                            qv_swpb_list_empty_dinb = 'd0; 
                                                            q_swpb_list_tail_web = 1'b0;
                                                            qv_swpb_list_tail_addrb = wv_PktQPN;
                                                            qv_swpb_list_tail_dinb = 'd0;                                                                                                                         
                                                        end 
                                    default:            begin 
                                                            q_swpb_list_head_web = 1'b0;
                                                            qv_swpb_list_head_addrb = 'd0;
                                                            qv_swpb_list_head_dinb = 'd0;
                                                            q_swpb_list_empty_web = 1'b0;
                                                            qv_swpb_list_empty_addrb = 'd0;
                                                            qv_swpb_list_empty_dinb = 'd0;
                                                            q_swpb_list_tail_web = 1'b0;
                                                            qv_swpb_list_tail_addrb = wv_PktQPN;
                                                            qv_swpb_list_tail_dinb = 'd0;                                                              
                                                        end
                                endcase
                            end  
        RRC_RELEASE_s:      if(!w_cur_release_is_read && ((w_gen_cpl_during_release && w_cpl_can_be_upload) || !w_gen_cpl_during_release)) begin
                                if(wv_swpb_head == wv_swpb_tail) begin
                                    q_swpb_list_head_web = 1'b0;    //When we encounter last element, head pointer should remain the same
                                    qv_swpb_list_head_addrb = qv_cur_event_QPN;
                                    qv_swpb_list_head_dinb = iv_swpb_list_head_doutb;
                                    q_swpb_list_empty_web = 1'b1;
                                    qv_swpb_list_empty_addrb = qv_cur_event_QPN;
                                    qv_swpb_list_empty_dinb = 1'b1;
                                    q_swpb_list_tail_web = 1'b0;
                                    qv_swpb_list_tail_addrb = qv_cur_event_QPN;
                                    qv_swpb_list_tail_dinb = 'd0;
                                end
                                else begin
                                    q_swpb_list_head_web = 1'b1;
                                    qv_swpb_list_head_addrb = qv_cur_event_QPN;
                                    qv_swpb_list_head_dinb = iv_swpb_next_doutb;
                                    q_swpb_list_empty_web = 1'b0;
                                    qv_swpb_list_empty_addrb = qv_cur_event_QPN;
                                    qv_swpb_list_empty_dinb = 1'b0;
                                    q_swpb_list_tail_web = 1'b0;
                                    qv_swpb_list_tail_addrb = qv_cur_event_QPN;
                                    qv_swpb_list_tail_dinb = 'd0;                                    
                                end
                            end 
                            else begin
                                    q_swpb_list_head_web = 1'b0;
                                    qv_swpb_list_head_addrb = qv_cur_event_QPN;
                                    qv_swpb_list_head_dinb = iv_swpb_next_doutb;
                                    q_swpb_list_empty_web = 1'b0;
                                    qv_swpb_list_empty_addrb = qv_cur_event_QPN;
                                    qv_swpb_list_empty_dinb = 1'b0;
                                    q_swpb_list_tail_web = 1'b0;
                                    qv_swpb_list_tail_addrb = qv_cur_event_QPN;
                                    qv_swpb_list_tail_dinb = 'd0;       
                            end
        RRC_WQE_FLUSH_s:      
                            if(!w_cur_release_is_read && ((w_gen_cpl_during_flush && w_cpl_can_be_upload) || !w_gen_cpl_during_flush) 
								&& qv_flush_curPSN < wv_NextPSN) begin 	//Patch for corner case
                                if(wv_swpb_head == wv_swpb_tail) begin
                                    q_swpb_list_head_web = 1'b0;    //When we encounter last element, head pointer should remain the same
                                    qv_swpb_list_head_addrb = qv_cur_event_QPN;
                                    qv_swpb_list_head_dinb = iv_swpb_list_head_doutb;
                                    q_swpb_list_empty_web = 1'b1;
                                    qv_swpb_list_empty_addrb = qv_cur_event_QPN;
                                    qv_swpb_list_empty_dinb = 1'b1;
                                    q_swpb_list_tail_web = 1'b0;
                                    qv_swpb_list_tail_addrb = qv_cur_event_QPN;
                                    qv_swpb_list_tail_dinb = 'd0;
                                end
                                else begin
                                    q_swpb_list_head_web = 1'b1;
                                    qv_swpb_list_head_addrb = qv_cur_event_QPN;
                                    qv_swpb_list_head_dinb = iv_swpb_next_doutb;
                                    q_swpb_list_empty_web = 1'b0;
                                    qv_swpb_list_empty_addrb = qv_cur_event_QPN;
                                    qv_swpb_list_empty_dinb = 1'b0;
                                    q_swpb_list_tail_web = 1'b0;
                                    qv_swpb_list_tail_addrb = qv_cur_event_QPN;
                                    qv_swpb_list_tail_dinb = 'd0;                                    
                                end
                            end 
                            else begin
                                    q_swpb_list_head_web = 1'b0;
                                    qv_swpb_list_head_addrb = qv_cur_event_QPN;
                                    qv_swpb_list_head_dinb = iv_swpb_next_doutb;
                                    q_swpb_list_empty_web = 1'b0;
                                    qv_swpb_list_empty_addrb = qv_cur_event_QPN;
                                    qv_swpb_list_empty_dinb = 1'b0;
                                    q_swpb_list_tail_web = 1'b0;
                                    qv_swpb_list_tail_addrb = qv_cur_event_QPN;
                                    qv_swpb_list_tail_dinb = 'd0;       
                            end
        default:            begin 
                                q_swpb_list_head_web = 1'b0;
                                qv_swpb_list_head_addrb = qv_cur_event_QPN;
                                qv_swpb_list_head_dinb = 'd0;
                                q_swpb_list_empty_web = 1'b0;
                                qv_swpb_list_empty_addrb = qv_cur_event_QPN;
                                qv_swpb_list_empty_dinb = 'd0;
                                q_swpb_list_tail_web = 1'b0;
                                qv_swpb_list_tail_addrb = qv_cur_event_QPN;
                                qv_swpb_list_tail_dinb = 'd0;                            
                            end
    endcase
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_swpb_content_addrb_TempReg <= 'd0;
        qv_swpb_next_addrb_TempReg <= 'd0;        
    end
    else begin
        qv_swpb_content_addrb_TempReg <= qv_swpb_content_addrb;
        qv_swpb_next_addrb_TempReg <= qv_swpb_next_addrb;           
    end
end

//-- q_swpb_content_web --
//-- qv_swpb_content_addrb --
//-- qv_swpb_content_dinb --
//-- q_swpb_next_web --
//-- qv_swpb_next_addrb --
//-- qv_swpb_next_dinb --
always @(*) begin
    case(RRC_cur_state)
        RRC_INIT_s:         	if(qv_swpb_next_table_init_counter <= `SWPB_CONTENT_FREE_NUM - 1) begin
                            	    q_swpb_next_web = 1'b1;
                            	    qv_swpb_next_addrb = qv_swpb_next_table_init_counter;
                            	    qv_swpb_next_dinb = 'd0;
//content init is moved to RTC
                            		//q_swpb_content_web = 1'b1;
                            		q_swpb_content_web = 1'b0;
                            		qv_swpb_content_addrb = qv_swpb_free_init_counter;
                            		qv_swpb_content_dinb = 'd0;                          
                            	end
                            	else begin
                            	    q_swpb_next_web = 1'b0;
                            	    qv_swpb_next_addrb = qv_swpb_next_table_init_counter;
                            	    qv_swpb_next_dinb = 'd0;
                            		q_swpb_content_web = 1'b0;
                            		qv_swpb_content_addrb = qv_swpb_free_init_counter;
                            		qv_swpb_content_dinb = 'd0;                          
                            	end
        RRC_RESP_CXT_s:        begin
                                    q_swpb_content_web =  1'b0;
                                    qv_swpb_content_addrb = wv_swpb_head;
                                    qv_swpb_content_dinb = 'd0;
                                    q_swpb_next_web = 1'b0;
                                    qv_swpb_next_addrb = wv_swpb_head;
                                    qv_swpb_next_dinb = 'd0;                               
                                end
        RRC_RELEASE_s:          if(!w_cur_release_is_read && ((w_gen_cpl_during_release && w_cpl_can_be_upload) || !w_gen_cpl_during_release)) begin
                                    q_swpb_content_web =  1'b0;
                                    qv_swpb_content_addrb = iv_swpb_next_doutb;
                                    qv_swpb_content_dinb = 'd0;
                                    q_swpb_next_web = 1'b0;
                                    qv_swpb_next_addrb = iv_swpb_next_doutb;
                                    qv_swpb_next_dinb = 'd0; 
                                end
                                else begin
                                    q_swpb_content_web =  1'b0;
                                    qv_swpb_content_addrb = qv_swpb_content_addrb_TempReg;
                                    qv_swpb_content_dinb = 'd0;
                                    q_swpb_next_web = 1'b0;
                                    qv_swpb_next_addrb = qv_swpb_next_addrb_TempReg;
                                    qv_swpb_next_dinb = 'd0;       
                                end
        RRC_WQE_FLUSH_s:     if(!w_flush_read && ((w_gen_cpl_during_flush && w_cpl_can_be_upload) || !w_gen_cpl_during_flush)) begin
                                    q_swpb_content_web =  1'b0;
                                    qv_swpb_content_addrb = iv_swpb_next_doutb;
                                    qv_swpb_content_dinb = 'd0;
                                    q_swpb_next_web = 1'b0;
                                    qv_swpb_next_addrb = iv_swpb_next_doutb;
                                    qv_swpb_next_dinb = 'd0; 
                                end
                                else begin
                                    q_swpb_content_web =  1'b0;
                                    qv_swpb_content_addrb = qv_swpb_content_addrb_TempReg;
                                    qv_swpb_content_dinb = 'd0;
                                    q_swpb_next_web = 1'b0;
                                    qv_swpb_next_addrb = qv_swpb_next_addrb_TempReg;
                                    qv_swpb_next_dinb = 'd0;       
                                end
        RRC_RETRANS_s:          if(!q_cur_retrans_is_read && qv_swpb_content_addrb_TempReg != wv_swpb_tail) begin //Only when current is not tail do we point to next
                                    if((qv_retrans_counter == 0 && !i_header_to_rpg_prog_full) ||
                                        (qv_retrans_counter != 0 && !i_nd_to_rpg_prog_full)) begin //Packet header
                                        q_swpb_content_web =  1'b0;
                                        qv_swpb_content_addrb = iv_swpb_next_doutb;
                                        qv_swpb_content_dinb = 'd0;
                                        q_swpb_next_web = 1'b0;
                                        qv_swpb_next_addrb = iv_swpb_next_doutb;
                                        qv_swpb_next_dinb = 'd0; 
                                    end
                                    else begin
                                        q_swpb_content_web =  1'b0;
                                        qv_swpb_content_addrb = qv_swpb_content_addrb_TempReg;
                                        qv_swpb_content_dinb = 'd0;
                                        q_swpb_next_web = 1'b0;
                                        qv_swpb_next_addrb = qv_swpb_next_addrb_TempReg;
                                        qv_swpb_next_dinb = 'd0; 
                                    end
                                end
                                else begin
                                    q_swpb_content_web =  1'b0;
                                    qv_swpb_content_addrb = qv_swpb_content_addrb_TempReg;
                                    qv_swpb_content_dinb = 'd0;
                                    q_swpb_next_web = 1'b0;
                                    qv_swpb_next_addrb = qv_swpb_next_addrb_TempReg;
                                    qv_swpb_next_dinb = 'd0;       
                                end      
        default:                begin 
                                    q_swpb_content_web =  1'b0;
                                    qv_swpb_content_addrb = wv_swpb_head;
                                    qv_swpb_content_dinb = 'd0;
                                    q_swpb_next_web = 1'b0;
                                    qv_swpb_next_addrb = wv_swpb_head;
                                    qv_swpb_next_dinb = 'd0; 
                                end
    endcase
end

//-- qv_swpb_free_init_counter --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_swpb_free_init_counter <= 'd0;
    end
    else if (RRC_cur_state == RRC_INIT_s && qv_swpb_free_init_counter < `SWPB_CONTENT_FREE_NUM - 1) begin
        qv_swpb_free_init_counter <= qv_swpb_free_init_counter + 1;
    end
    else begin
        qv_swpb_free_init_counter <= qv_swpb_free_init_counter;
    end
end

//-- qv_swpb_next_table_init_counter --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_swpb_next_table_init_counter <= 'd0;
    end
    else if (RRC_cur_state == RRC_INIT_s && qv_swpb_next_table_init_counter < `SWPB_CONTENT_FREE_NUM - 1) begin
        qv_swpb_next_table_init_counter <= qv_swpb_next_table_init_counter + 1;
    end
    else begin
        qv_swpb_next_table_init_counter <= qv_swpb_next_table_init_counter;
    end
end

//-- qv_swpb_free_data --
//-- q_swpb_free_wr_en --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_swpb_free_wr_en <= 1'b0;
        qv_swpb_free_data <= 'd0;
    end
    else if(RRC_cur_state == RRC_INIT_s && (qv_swpb_free_init_counter == 0 || qv_swpb_free_data < qv_swpb_free_init_counter)) begin
        q_swpb_free_wr_en <= 1'b1;
        qv_swpb_free_data <= qv_swpb_free_init_counter;
    end
    else if (RRC_cur_state == RRC_RELEASE_s && !q_cur_release_is_read && ((w_gen_cpl_during_release && w_cpl_can_be_upload) || !w_gen_cpl_during_release)) begin
        q_swpb_free_wr_en <= 1'b1;
        qv_swpb_free_data <= wv_swpb_head;
    end
    else if (RRC_cur_state == RRC_WQE_FLUSH_s && !w_flush_read && ((w_gen_cpl_during_flush && w_cpl_can_be_upload) || !w_gen_cpl_during_flush) && !w_swpb_empty) begin
        q_swpb_free_wr_en <= 1'b1;
        qv_swpb_free_data <= wv_swpb_head;
    end
    else begin
        q_swpb_free_wr_en <= 1'b0;
        qv_swpb_free_data <= qv_swpb_free_data;
    end
end 
/***************************************************************** End ************************************************************/ 


/*********************** Scatter Entry Control ********** Begin *****************/
//-- qv_sem_cmd_din --
//-- q_sem_cmd_wr_en -- 
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_sem_cmd_wr_en <= 1'b0;
        qv_sem_cmd_din <= 'd0;        
    end
	//else if (RRC_cur_state != RRC_WQE_FLUSH_s && RRC_next_state == RRC_WQE_FLUSH_s) begin
	else if (RRC_cur_state == RRC_WQE_FLUSH_s && w_flush_read) begin
		q_sem_cmd_wr_en <= 1'b1;
		qv_sem_cmd_din <= {128'd0, qv_cur_event_QPN, 5'd0, `FLUSH_ENTRY};
	end 
    else if (RRC_cur_state == RRC_FETCH_ENTRY_s && !w_sem_cmd_prog_full) begin
        q_sem_cmd_wr_en <= 1'b1;
        qv_sem_cmd_din <= {128'd0, qv_cur_event_QPN, 5'd0, `FETCH_ENTRY};
    end
    else if (RRC_cur_state == RRC_UPDATE_ENTRY_s && !w_sem_cmd_prog_full) begin
        q_sem_cmd_wr_en <= 1'b1;
        //qv_sem_cmd_din <= {qv_cur_entry_left_length, wv_entry_key, wv_entry_va + (wv_entry_length - qv_cur_entry_left_length), qv_cur_event_QPN, 6'd0, `UPDATE_ENTRY};
        //qv_sem_cmd_din <= {wv_entry_va + (wv_entry_length - qv_cur_entry_left_length), wv_entry_key, qv_cur_entry_left_length, qv_cur_event_QPN, 5'd0, `UPDATE_ENTRY};
        qv_sem_cmd_din <= {qv_entry_va + (qv_entry_length - qv_cur_entry_left_length), qv_entry_key, qv_cur_entry_left_length, qv_cur_event_QPN, 5'd0, `UPDATE_ENTRY};
    end
    else if (RRC_cur_state == RRC_RELEASE_ENTRY_s && !w_sem_cmd_prog_full) begin
        q_sem_cmd_wr_en <= 1'b1;
        qv_sem_cmd_din <= {128'd0, qv_cur_event_QPN, 5'd1, `RELEASE_ENTRY};    //We suppose the scatter entry submitted matches the read response, that's why we just release "1" entry
    end
    else begin
        q_sem_cmd_wr_en <= 1'b0;
        qv_sem_cmd_din <= qv_sem_cmd_din;
    end
end

//-- q_sem_resp_rd_en -- 
always @(*) begin
    if(rst) begin
        q_sem_resp_rd_en = 'd0;
    end
    //else if(RRC_cur_state == RRC_RESP_ENTRY_s && !w_sem_resp_empty) begin
    else if((RRC_cur_state == RRC_PKT_FLUSH_s || RRC_cur_state == RRC_SCATTER_CMD_s) && !w_sem_resp_empty) begin
        q_sem_resp_rd_en = 'd1;        
    end
    else begin
        q_sem_resp_rd_en = 'd0;
    end
end

/******************************************************** End ********************************************************/


/**************************************** Scatter or Flush Read Response Data : Begin ********************************/
//-- w_cur_read_finish --
assign w_cur_read_finish = (RRC_cur_state == RRC_RELEASE_ENTRY_s) && !w_sem_cmd_prog_full && 
                            (qv_pkt_left_length == 0) && (qv_unwritten_len == 0) && (wv_opcode == `RDMA_READ_RESPONSE_LAST || wv_opcode == `RDMA_READ_RESPONSE_ONLY);

//-- qv_pkt_left_length -- //Indicates Packets length unprocessed of current packet "left in the network FIFO"
//                          notice that this variable does not contain the data has been read out from the network FIFO.
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_pkt_left_length <= 'd0;        
    end
    else if (RRC_cur_state == RRC_RESP_CXT_s && qv_event_num == `PKT_EVENT) begin
        qv_pkt_left_length <= wv_length;
    end
    else if(RRC_cur_state == RRC_SCATTER_DATA_s || RRC_cur_state == RRC_PKT_FLUSH_s) begin
        if(q_nd_from_hp_rd_en) begin
            if(qv_pkt_left_length > 32) begin
                qv_pkt_left_length <= qv_pkt_left_length - 32;
            end
            else begin
                qv_pkt_left_length <= 'd0;
            end
        end
        else begin
            qv_pkt_left_length <= qv_pkt_left_length;
        end
    end
	else if(RRC_cur_state == RRC_SILENT_DROP_s && !i_nd_from_hp_empty) begin
		qv_pkt_left_length <= qv_pkt_left_length - 32;
	end 
    else begin
        qv_pkt_left_length <= qv_pkt_left_length;
    end
end

//-- qv_cur_entry_left_length -- Indicates space available of current Scatter Entry
//                               The control logic is similar to state transition
//                              The key point is that there are two cases which indicate that we have met the end of a packet:
//                              1. qv_pkt_left_length is 0, which means we have read out all the data from iv_nd_from_hp_data, and we need to handle qv_unwritten_data only;
//                              2. qv_pkt_left_length is not 0, and (qv_unwritten_len + qv_pkt_left_length) <= 32, we need to piece this two data segment together
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_cur_entry_left_length <= 'd0;      
    end
    else if (RRC_cur_state == RRC_RESP_ENTRY_s) begin
        if(w_entry_valid) begin
            qv_cur_entry_left_length <= wv_entry_length;
        end
        else begin
            qv_cur_entry_left_length <= qv_cur_entry_left_length;
        end
    end
    else if (RRC_cur_state == RRC_SCATTER_DATA_s) begin
        if(qv_pkt_left_length + qv_unwritten_len <= qv_cur_entry_left_length) begin
            if(qv_pkt_left_length == 0 && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin   //Deal with qv_unwritten_data, end of a packet
                qv_cur_entry_left_length <= qv_cur_entry_left_length - qv_unwritten_len;
            end
            else if(qv_pkt_left_length + qv_unwritten_len <= 32 && !i_nd_from_hp_empty && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin //Deal with qv_unwritten_len and iv_nd_from_hp_data, end of a packet
                qv_cur_entry_left_length <= qv_cur_entry_left_length - (qv_pkt_left_length + qv_unwritten_len);
            end
            else if(qv_pkt_left_length + qv_unwritten_len > 32 && !i_nd_from_hp_empty && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin //Deal with 32B data, not the end
                qv_cur_entry_left_length <= qv_cur_entry_left_length - 32;
            end
            else begin
                qv_cur_entry_left_length <= qv_cur_entry_left_length;
            end
        end
        else begin      //Current entry space is not enough
            if(qv_cur_entry_left_length <= 32) begin
                if(qv_cur_entry_left_length <= qv_unwritten_len && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin
                    qv_cur_entry_left_length <= 'd0;
                end
                else if(qv_cur_entry_left_length > qv_unwritten_len && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_nd_from_hp_empty) begin
                    qv_cur_entry_left_length <= 'd0;
                end
                else begin
                    qv_cur_entry_left_length <= qv_cur_entry_left_length;
                end
            end 
            else begin //More than 32B left, must handle {iv_nd_from_hp_data[?:?], qv_unwritten_data[?:?]}
                if(!i_nd_from_hp_empty && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin
                    qv_cur_entry_left_length <= qv_cur_entry_left_length - 32;
                end
                else begin
                    qv_cur_entry_left_length <= qv_cur_entry_left_length;
                end
            end
        end
    end
    else begin
        qv_cur_entry_left_length <= qv_cur_entry_left_length;
    end
end 


//-- qv_unwritten_len -- For data piecing
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_unwritten_len <= 'd0;      
    end
    else if (RRC_cur_state == RRC_RESP_CXT_s) begin   //At RESP_CXT, clear this register
        qv_unwritten_len <= 'd0;
    end
    else if (RRC_cur_state == RRC_SCATTER_DATA_s) begin
        if(qv_pkt_left_length + qv_unwritten_len <= qv_cur_entry_left_length) begin
            if(qv_pkt_left_length == 0 && !i_vtp_upload_prog_full) begin   
                qv_unwritten_len <= 'd0; 
            end
            else if(qv_pkt_left_length + qv_unwritten_len > 32 && !i_nd_from_hp_empty && !i_vtp_upload_prog_full) begin
                if(qv_pkt_left_length <= 32) begin
                    qv_unwritten_len <= qv_pkt_left_length + qv_unwritten_len - 32;
                end
                else begin
                    qv_unwritten_len <= qv_unwritten_len;
                end
            end
            else if(qv_pkt_left_length + qv_unwritten_len <= 32 && !i_nd_from_hp_empty && !i_vtp_upload_prog_full) begin
                qv_unwritten_len <= 'd0;
            end
            else begin
                qv_unwritten_len <= qv_unwritten_len;
            end
        end
        else begin //Current entry space is not enough
            if(qv_cur_entry_left_length > 32) begin
                if(qv_pkt_left_length > 32 && !i_nd_from_hp_empty && !i_vtp_upload_prog_full) begin
                    qv_unwritten_len <= qv_unwritten_len;
                end
                else if(qv_pkt_left_length <= 32 && !i_nd_from_hp_empty && !i_vtp_upload_prog_full) begin
                    //qv_unwritten_len <= {26'd0, qv_unwritten_len} + {19'd0, qv_pkt_left_length} - qv_cur_entry_left_length;
                    qv_unwritten_len <= {19'd0, qv_pkt_left_length} - (32'd32 - {26'd0, qv_unwritten_len});
                end
                else begin
                    qv_unwritten_len <= qv_unwritten_len;
                end
            end
            else begin
                if(qv_cur_entry_left_length <= qv_unwritten_len && !i_vtp_upload_prog_full) begin
                    qv_unwritten_len <= {26'd0, qv_unwritten_len} - qv_cur_entry_left_length;
                end
                else if(qv_cur_entry_left_length > qv_unwritten_len) begin
                    if(qv_pkt_left_length <= 32 && !i_nd_from_hp_empty && !i_vtp_upload_prog_full) begin
                        qv_unwritten_len <= {26'd0, qv_unwritten_len} + {19'd0, qv_pkt_left_length} - qv_cur_entry_left_length;
                    end
                    else if(qv_pkt_left_length > 32 && !i_vtp_upload_prog_full && !i_nd_from_hp_empty) begin
                        qv_unwritten_len <= {26'd0, qv_unwritten_len} + 32'd32 - qv_cur_entry_left_length;
                    end
                    else begin
                        qv_unwritten_len <= qv_unwritten_len;
                    end
                end
                else begin
                    qv_unwritten_len <= qv_unwritten_len;
                end
            end
        end
    end
    else begin
        qv_unwritten_len <= qv_unwritten_len;
    end
end

//-- qv_unwritten_data -- For data piecing
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_unwritten_data <= 'd0;      
    end
    else if (RRC_cur_state == RRC_RESP_CXT_s) begin   //At RESP_CXT, clear this register
        qv_unwritten_data <= 'd0;
    end
    else if (RRC_cur_state == RRC_SCATTER_DATA_s) begin
		if(qv_pkt_left_length + qv_unwritten_len <= qv_cur_entry_left_length) begin 	//Entry is enough
			if(qv_unwritten_len == 0) begin 
				qv_unwritten_data <= 'd0;
			end 
			else begin
				if((qv_unwritten_len + qv_pkt_left_length <= 32) && !i_nd_from_hp_empty && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin 
					qv_unwritten_data <= 'd0;	//All packet data has been uploaded
				end 
				else if((qv_unwritten_len + qv_pkt_left_length > 32) && !i_nd_from_hp_empty && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin
					case(32 - qv_unwritten_len) 
                        0:          qv_unwritten_data <= 'd0;
                        1:          qv_unwritten_data <= {248'd0, iv_nd_from_hp_data[255 : 1 * 8]};
                        2:          qv_unwritten_data <= {240'd0, iv_nd_from_hp_data[255 : 2 * 8]};
                        3:          qv_unwritten_data <= {232'd0, iv_nd_from_hp_data[255 : 3 * 8]};
                        4:          qv_unwritten_data <= {224'd0, iv_nd_from_hp_data[255 : 4 * 8]};
                        5:          qv_unwritten_data <= {216'd0, iv_nd_from_hp_data[255 : 5 * 8]};
                        6:          qv_unwritten_data <= {208'd0, iv_nd_from_hp_data[255 : 6 * 8]};
                        7:          qv_unwritten_data <= {200'd0, iv_nd_from_hp_data[255 : 7 * 8]};
                        8:          qv_unwritten_data <= {192'd0, iv_nd_from_hp_data[255 : 8 * 8]};
                        9:          qv_unwritten_data <= {184'd0, iv_nd_from_hp_data[255 : 9 * 8]};
                        10:         qv_unwritten_data <= {176'd0, iv_nd_from_hp_data[255 : 10 * 8]};
                        11:         qv_unwritten_data <= {168'd0, iv_nd_from_hp_data[255 : 11 * 8]};
                        12:         qv_unwritten_data <= {160'd0, iv_nd_from_hp_data[255 : 12 * 8]};
                        13:         qv_unwritten_data <= {152'd0, iv_nd_from_hp_data[255 : 13 * 8]};
                        14:         qv_unwritten_data <= {144'd0, iv_nd_from_hp_data[255 : 14 * 8]};
                        15:         qv_unwritten_data <= {136'd0, iv_nd_from_hp_data[255 : 15 * 8]};
                        16:         qv_unwritten_data <= {128'd0, iv_nd_from_hp_data[255 : 16 * 8]};
                        17:         qv_unwritten_data <= {120'd0, iv_nd_from_hp_data[255 : 17 * 8]};
                        18:         qv_unwritten_data <= {112'd0, iv_nd_from_hp_data[255 : 18 * 8]};
                        19:         qv_unwritten_data <= {104'd0, iv_nd_from_hp_data[255 : 19 * 8]};
                        20:         qv_unwritten_data <= {96'd0, iv_nd_from_hp_data[255 : 20 * 8]};
                        21:         qv_unwritten_data <= {88'd0, iv_nd_from_hp_data[255 : 21 * 8]};
                        22:         qv_unwritten_data <= {80'd0, iv_nd_from_hp_data[255 : 22 * 8]};
                        23:         qv_unwritten_data <= {72'd0, iv_nd_from_hp_data[255 : 23 * 8]};
                        24:         qv_unwritten_data <= {64'd0, iv_nd_from_hp_data[255 : 24 * 8]};
                        25:         qv_unwritten_data <= {56'd0, iv_nd_from_hp_data[255 : 25 * 8]};
                        26:         qv_unwritten_data <= {48'd0, iv_nd_from_hp_data[255 : 26 * 8]};
                        27:         qv_unwritten_data <= {40'd0, iv_nd_from_hp_data[255 : 27 * 8]};
                        28:         qv_unwritten_data <= {32'd0, iv_nd_from_hp_data[255 : 28 * 8]};
                        29:         qv_unwritten_data <= {24'd0, iv_nd_from_hp_data[255 : 29 * 8]};
                        30:         qv_unwritten_data <= {16'd0, iv_nd_from_hp_data[255 : 30 * 8]};
                        31:         qv_unwritten_data <= {8'd0, iv_nd_from_hp_data[255 : 31 * 8]};
                        default:    qv_unwritten_data <= qv_unwritten_data;
					endcase
				end 
				else begin
					qv_unwritten_data <= qv_unwritten_data;
				end 
			end 
		end 
		else if(qv_pkt_left_length + qv_unwritten_len > qv_cur_entry_left_length) begin 
			if(qv_unwritten_len == 0 && !i_nd_from_hp_empty && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin
				if(qv_cur_entry_left_length < 32) begin
					case(qv_cur_entry_left_length)
                        0:          qv_unwritten_data <= 'd0;
                        1:          qv_unwritten_data <= {248'd0, iv_nd_from_hp_data[255 : 1 * 8]};
                        2:          qv_unwritten_data <= {240'd0, iv_nd_from_hp_data[255 : 2 * 8]};
                        3:          qv_unwritten_data <= {232'd0, iv_nd_from_hp_data[255 : 3 * 8]};
                        4:          qv_unwritten_data <= {224'd0, iv_nd_from_hp_data[255 : 4 * 8]};
                        5:          qv_unwritten_data <= {216'd0, iv_nd_from_hp_data[255 : 5 * 8]};
                        6:          qv_unwritten_data <= {208'd0, iv_nd_from_hp_data[255 : 6 * 8]};
                        7:          qv_unwritten_data <= {200'd0, iv_nd_from_hp_data[255 : 7 * 8]};
                        8:          qv_unwritten_data <= {192'd0, iv_nd_from_hp_data[255 : 8 * 8]};
                        9:          qv_unwritten_data <= {184'd0, iv_nd_from_hp_data[255 : 9 * 8]};
                        10:         qv_unwritten_data <= {176'd0, iv_nd_from_hp_data[255 : 10 * 8]};
                        11:         qv_unwritten_data <= {168'd0, iv_nd_from_hp_data[255 : 11 * 8]};
                        12:         qv_unwritten_data <= {160'd0, iv_nd_from_hp_data[255 : 12 * 8]};
                        13:         qv_unwritten_data <= {152'd0, iv_nd_from_hp_data[255 : 13 * 8]};
                        14:         qv_unwritten_data <= {144'd0, iv_nd_from_hp_data[255 : 14 * 8]};
                        15:         qv_unwritten_data <= {136'd0, iv_nd_from_hp_data[255 : 15 * 8]};
                        16:         qv_unwritten_data <= {128'd0, iv_nd_from_hp_data[255 : 16 * 8]};
                        17:         qv_unwritten_data <= {120'd0, iv_nd_from_hp_data[255 : 17 * 8]};
                        18:         qv_unwritten_data <= {112'd0, iv_nd_from_hp_data[255 : 18 * 8]};
                        19:         qv_unwritten_data <= {104'd0, iv_nd_from_hp_data[255 : 19 * 8]};
                        20:         qv_unwritten_data <= {96'd0, iv_nd_from_hp_data[255 : 20 * 8]};
                        21:         qv_unwritten_data <= {88'd0, iv_nd_from_hp_data[255 : 21 * 8]};
                        22:         qv_unwritten_data <= {80'd0, iv_nd_from_hp_data[255 : 22 * 8]};
                        23:         qv_unwritten_data <= {72'd0, iv_nd_from_hp_data[255 : 23 * 8]};
                        24:         qv_unwritten_data <= {64'd0, iv_nd_from_hp_data[255 : 24 * 8]};
                        25:         qv_unwritten_data <= {56'd0, iv_nd_from_hp_data[255 : 25 * 8]};
                        26:         qv_unwritten_data <= {48'd0, iv_nd_from_hp_data[255 : 26 * 8]};
                        27:         qv_unwritten_data <= {40'd0, iv_nd_from_hp_data[255 : 27 * 8]};
                        28:         qv_unwritten_data <= {32'd0, iv_nd_from_hp_data[255 : 28 * 8]};
                        29:         qv_unwritten_data <= {24'd0, iv_nd_from_hp_data[255 : 29 * 8]};
                        30:         qv_unwritten_data <= {16'd0, iv_nd_from_hp_data[255 : 30 * 8]};
                        31:         qv_unwritten_data <= {8'd0, iv_nd_from_hp_data[255 : 31 * 8]};
                        default:    qv_unwritten_data <= qv_unwritten_data;
					endcase
				end 
				else begin
					qv_unwritten_data <= qv_unwritten_data;
				end 
			end 
			else if(qv_unwritten_len > 0 && qv_cur_entry_left_length <= qv_unwritten_len && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin 
				case(qv_cur_entry_left_length)
                        0:          qv_unwritten_data <= 'd0;
                        1:          qv_unwritten_data <= {248'd0, qv_unwritten_data[255 : 1 * 8]};
                        2:          qv_unwritten_data <= {240'd0, qv_unwritten_data[255 : 2 * 8]};
                        3:          qv_unwritten_data <= {232'd0, qv_unwritten_data[255 : 3 * 8]};
                        4:          qv_unwritten_data <= {224'd0, qv_unwritten_data[255 : 4 * 8]};
                        5:          qv_unwritten_data <= {216'd0, qv_unwritten_data[255 : 5 * 8]};
                        6:          qv_unwritten_data <= {208'd0, qv_unwritten_data[255 : 6 * 8]};
                        7:          qv_unwritten_data <= {200'd0, qv_unwritten_data[255 : 7 * 8]};
                        8:          qv_unwritten_data <= {192'd0, qv_unwritten_data[255 : 8 * 8]};
                        9:          qv_unwritten_data <= {184'd0, qv_unwritten_data[255 : 9 * 8]};
                        10:         qv_unwritten_data <= {176'd0, qv_unwritten_data[255 : 10 * 8]};
                        11:         qv_unwritten_data <= {168'd0, qv_unwritten_data[255 : 11 * 8]};
                        12:         qv_unwritten_data <= {160'd0, qv_unwritten_data[255 : 12 * 8]};
                        13:         qv_unwritten_data <= {152'd0, qv_unwritten_data[255 : 13 * 8]};
                        14:         qv_unwritten_data <= {144'd0, qv_unwritten_data[255 : 14 * 8]};
                        15:         qv_unwritten_data <= {136'd0, qv_unwritten_data[255 : 15 * 8]};
                        16:         qv_unwritten_data <= {128'd0, qv_unwritten_data[255 : 16 * 8]};
                        17:         qv_unwritten_data <= {120'd0, qv_unwritten_data[255 : 17 * 8]};
                        18:         qv_unwritten_data <= {112'd0, qv_unwritten_data[255 : 18 * 8]};
                        19:         qv_unwritten_data <= {104'd0, qv_unwritten_data[255 : 19 * 8]};
                        20:         qv_unwritten_data <= {96'd0, qv_unwritten_data[255 : 20 * 8]};
                        21:         qv_unwritten_data <= {88'd0, qv_unwritten_data[255 : 21 * 8]};
                        22:         qv_unwritten_data <= {80'd0, qv_unwritten_data[255 : 22 * 8]};
                        23:         qv_unwritten_data <= {72'd0, qv_unwritten_data[255 : 23 * 8]};
                        24:         qv_unwritten_data <= {64'd0, qv_unwritten_data[255 : 24 * 8]};
                        25:         qv_unwritten_data <= {56'd0, qv_unwritten_data[255 : 25 * 8]};
                        26:         qv_unwritten_data <= {48'd0, qv_unwritten_data[255 : 26 * 8]};
                        27:         qv_unwritten_data <= {40'd0, qv_unwritten_data[255 : 27 * 8]};
                        28:         qv_unwritten_data <= {32'd0, qv_unwritten_data[255 : 28 * 8]};
                        29:         qv_unwritten_data <= {24'd0, qv_unwritten_data[255 : 29 * 8]};
                        30:         qv_unwritten_data <= {16'd0, qv_unwritten_data[255 : 30 * 8]};
                        31:         qv_unwritten_data <= {8'd0, qv_unwritten_data[255 : 31 * 8]};
                        default:    qv_unwritten_data <= qv_unwritten_data;
				endcase
			end 
			else if(qv_unwritten_len > 0 && qv_cur_entry_left_length > qv_unwritten_len && !i_nd_from_hp_empty && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin
				case(qv_cur_entry_left_length > 32 ? (32 - qv_unwritten_len) : (qv_cur_entry_left_length - qv_unwritten_len))
                        0:          qv_unwritten_data <= 'd0;
                        1:          qv_unwritten_data <= {248'd0, iv_nd_from_hp_data[255 : 1 * 8]};
                        2:          qv_unwritten_data <= {240'd0, iv_nd_from_hp_data[255 : 2 * 8]};
                        3:          qv_unwritten_data <= {232'd0, iv_nd_from_hp_data[255 : 3 * 8]};
                        4:          qv_unwritten_data <= {224'd0, iv_nd_from_hp_data[255 : 4 * 8]};
                        5:          qv_unwritten_data <= {216'd0, iv_nd_from_hp_data[255 : 5 * 8]};
                        6:          qv_unwritten_data <= {208'd0, iv_nd_from_hp_data[255 : 6 * 8]};
                        7:          qv_unwritten_data <= {200'd0, iv_nd_from_hp_data[255 : 7 * 8]};
                        8:          qv_unwritten_data <= {192'd0, iv_nd_from_hp_data[255 : 8 * 8]};
                        9:          qv_unwritten_data <= {184'd0, iv_nd_from_hp_data[255 : 9 * 8]};
                        10:         qv_unwritten_data <= {176'd0, iv_nd_from_hp_data[255 : 10 * 8]};
                        11:         qv_unwritten_data <= {168'd0, iv_nd_from_hp_data[255 : 11 * 8]};
                        12:         qv_unwritten_data <= {160'd0, iv_nd_from_hp_data[255 : 12 * 8]};
                        13:         qv_unwritten_data <= {152'd0, iv_nd_from_hp_data[255 : 13 * 8]};
                        14:         qv_unwritten_data <= {144'd0, iv_nd_from_hp_data[255 : 14 * 8]};
                        15:         qv_unwritten_data <= {136'd0, iv_nd_from_hp_data[255 : 15 * 8]};
                        16:         qv_unwritten_data <= {128'd0, iv_nd_from_hp_data[255 : 16 * 8]};
                        17:         qv_unwritten_data <= {120'd0, iv_nd_from_hp_data[255 : 17 * 8]};
                        18:         qv_unwritten_data <= {112'd0, iv_nd_from_hp_data[255 : 18 * 8]};
                        19:         qv_unwritten_data <= {104'd0, iv_nd_from_hp_data[255 : 19 * 8]};
                        20:         qv_unwritten_data <= {96'd0, iv_nd_from_hp_data[255 : 20 * 8]};
                        21:         qv_unwritten_data <= {88'd0, iv_nd_from_hp_data[255 : 21 * 8]};
                        22:         qv_unwritten_data <= {80'd0, iv_nd_from_hp_data[255 : 22 * 8]};
                        23:         qv_unwritten_data <= {72'd0, iv_nd_from_hp_data[255 : 23 * 8]};
                        24:         qv_unwritten_data <= {64'd0, iv_nd_from_hp_data[255 : 24 * 8]};
                        25:         qv_unwritten_data <= {56'd0, iv_nd_from_hp_data[255 : 25 * 8]};
                        26:         qv_unwritten_data <= {48'd0, iv_nd_from_hp_data[255 : 26 * 8]};
                        27:         qv_unwritten_data <= {40'd0, iv_nd_from_hp_data[255 : 27 * 8]};
                        28:         qv_unwritten_data <= {32'd0, iv_nd_from_hp_data[255 : 28 * 8]};
                        29:         qv_unwritten_data <= {24'd0, iv_nd_from_hp_data[255 : 29 * 8]};
                        30:         qv_unwritten_data <= {16'd0, iv_nd_from_hp_data[255 : 30 * 8]};
                        31:         qv_unwritten_data <= {8'd0, iv_nd_from_hp_data[255 : 31 * 8]};
                        default:    qv_unwritten_data <= qv_unwritten_data;
				endcase
			end 
		end 
		else begin 
			qv_unwritten_data <= qv_unwritten_data;
		end 
	end 
	else begin
		qv_unwritten_data <= qv_unwritten_data;
	end 
end 

/******************************************************** End *****************/
//-- q_header_from_hp_rd_en -- 
always @(*) begin
    if(rst) begin
        q_header_from_hp_rd_en = 1'b0;
    end
    else if(RRC_cur_state == RRC_SILENT_DROP_s && qv_event_num == `PKT_EVENT && w_pkt_drop_finish && !i_header_from_hp_empty) begin
        q_header_from_hp_rd_en = 1'b1;
    end 
	else if(RRC_cur_state == RRC_CXT_WB_s && qv_event_num == `PKT_EVENT && !i_cxtmgt_cmd_prog_full && !i_cxtmgt_cxt_prog_full) begin 
		q_header_from_hp_rd_en = 1'b1;
	end 
    else begin
        q_header_from_hp_rd_en = 1'b0;
    end
end

//-- q_nd_from_hp_rd_en --
always @(*) begin
    if(rst) begin
        q_nd_from_hp_rd_en = 'd0;
    end 
    else begin
        case(RRC_cur_state)
            RRC_SCATTER_DATA_s:  if(qv_cur_entry_left_length <= qv_unwritten_len) begin
                                    q_nd_from_hp_rd_en = 1'b0;
                                end
                            	else if(qv_pkt_left_length > 0 && !i_vtp_upload_prog_full && !i_nd_from_hp_empty) begin
                            	    q_nd_from_hp_rd_en = 1'b1;
                            	end
								else begin
									q_nd_from_hp_rd_en = 1'b0;
								end 
			RRC_SILENT_DROP_s:	q_nd_from_hp_rd_en = (wv_opcode != `ACKNOWLEDGE) && !i_nd_from_hp_empty;
            RRC_PKT_FLUSH_s:    q_nd_from_hp_rd_en = (wv_opcode != `ACKNOWLEDGE) && !i_nd_from_hp_empty;  
            default:            q_nd_from_hp_rd_en = 1'b0;
        endcase
    end 
end

//-- q_header_to_rpg_wr_en --
//-- qv_header_to_rpg_data --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_header_to_rpg_wr_en <= 'd0;
        qv_header_to_rpg_data <= 'd0;
    end
    else if(RRC_cur_state == RRC_RETRANS_s && qv_retrans_counter == 0 && !i_header_to_rpg_prog_full) begin
        q_header_to_rpg_wr_en <= 1'b1;
        qv_header_to_rpg_data <= q_cur_retrans_is_read ? iv_rpb_content_doutb : iv_swpb_content_doutb;
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
         q_nd_to_rpg_wr_en <= 'd0;
         qv_nd_to_rpg_data <= 'd0;
     end
     else if (RRC_cur_state == RRC_RETRANS_s && qv_retrans_counter > 0 && !i_nd_to_rpg_prog_full) begin
         q_nd_to_rpg_wr_en <= 1'b1;
         qv_nd_to_rpg_data <= q_cur_retrans_is_read ? iv_rpb_content_doutb : iv_swpb_content_doutb;
     end
     else begin
         q_nd_to_rpg_wr_en <= 1'b0;
         qv_nd_to_rpg_data <= qv_nd_to_rpg_data;
     end
end 

/*********************************************** CxtMgt Fetch and Write Back ***************************************/
//-- q_cxtmgt_cmd_wr_en --
//-- qv_cxtmgt_cmd_data --
always @(posedge clk or posedge rst) begin
     if (rst) begin
        q_cxtmgt_cmd_wr_en <= 1'b0;
        qv_cxtmgt_cmd_data <= 'd0;
     end
     else if(RRC_cur_state == RRC_FETCH_CXT_s && !i_cxtmgt_cmd_prog_full) begin     //Fetch CxtMgt
        q_cxtmgt_cmd_wr_en <= 1'b1;
        qv_cxtmgt_cmd_data <= {`RD_CQ_CTX, `RD_CQ_CST, qv_fetch_QPN, 96'h0};
     end
     else if(RRC_cur_state == RRC_CXT_WB_s && !i_cxtmgt_cmd_prog_full && !i_cxtmgt_cxt_prog_full) begin //Write back CxtMgt
        q_cxtmgt_cmd_wr_en <= 1'b1;
        qv_cxtmgt_cmd_data <= {`WR_QP_CTX, `WR_QP_UAPST, qv_cur_event_QPN, 96'h0};
     end
     else begin
         q_cxtmgt_cmd_wr_en <= 1'b0;
         qv_cxtmgt_cmd_data <= qv_cxtmgt_cmd_data;
     end
end 

//-- q_cxtmgt_resp_rd_en --
//-- q_cxtmgt_cxt_rd_en --
//-- simplified coding --
always @(*) begin
    if(rst) begin 
        q_cxtmgt_resp_rd_en = 1'b0;
        q_cxtmgt_cxt_rd_en = 1'b0;
    end 
    else begin  //Since cxt read is synchronized with CxtMgt, we can safely rd_en, and the value of the FIFO will not change until next cxt fetch
        q_cxtmgt_resp_rd_en = (RRC_cur_state == RRC_RESP_CXT_s) && !i_cxtmgt_resp_empty;
        q_cxtmgt_cxt_rd_en = (RRC_cur_state == RRC_RESP_CXT_s) && !i_cxtmgt_resp_empty;
    end 
end

reg     [2:0]           qv_qp_state;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_qp_state <= 'd0;        
    end
    else if(RRC_cur_state == RRC_RESP_CXT_s) begin 
        if(wv_qp_state == `QP_ERR) begin 
            qv_qp_state <= wv_qp_state;
        end 
        else if(qv_event_num == `LOSS_TIMER_EVENT) begin 
            if (wv_loss_timer_event == `COUNTER_EXCEEDED) begin
                qv_qp_state <= `QP_ERR;
            end
            else begin
                qv_qp_state <= wv_qp_state;
            end
        end
        else if(qv_event_num == `RNR_TIMER_EVENT) begin
            if (wv_rnr_timer_event == `COUNTER_EXCEEDED) begin
                qv_qp_state <= `QP_ERR;
            end
            else begin
                qv_qp_state <= wv_qp_state;
            end
        end
        else if(qv_event_num == `BAD_REQ_EVENT) begin
            qv_qp_state <= wv_qp_state;
        end
        else if(qv_event_num == `PKT_EVENT) begin
            if(wv_opcode == `ACKNOWLEDGE && wv_syndrome_high2 == `SYNDROME_NAK && wv_syndrome_low5 != `NAK_PSN_SEQUENCE_ERROR) begin
                qv_qp_state <= `QP_ERR;
            end 
            else begin
                qv_qp_state <= wv_qp_state;
            end
        end 
        else begin
            qv_qp_state <= qv_qp_state;
        end
    end
    else if(RRC_cur_state == RRC_RESP_ENTRY_s && !w_sem_resp_empty && !w_entry_valid) begin
        qv_qp_state <= `QP_ERR;
    end
	else if(RRC_cur_state == RRC_BAD_REQ_s && RRC_next_state == RRC_CXT_WB_s) begin
		qv_qp_state <= `QP_ERR;
	end 
    else begin
        qv_qp_state <= qv_qp_state;
    end       

end

//-- Bug Fixed --
reg 		q_release_indicator;
always @(posedge clk or posedge rst) begin
	if(rst) begin
		q_release_indicator <= 'd0;
	end 
	else if(RRC_cur_state == RRC_RESP_CXT_s) begin
		q_release_indicator <= 'd0;
	end 
	else if(RRC_cur_state == RRC_RELEASE_s) begin	//Indicates release has happened
		q_release_indicator <= 'd1;
	end 
	else begin
		q_release_indicator <= q_release_indicator;
	end 
end 

//-- q_cxtmgt_cxt_wr_en -- 
//-- qv_cxtmgt_cxt_data --
always @(posedge clk or posedge rst) begin
     if (rst) begin
        q_cxtmgt_cxt_wr_en <= 'd0;
        qv_cxtmgt_cxt_data <= 'd0;
     end
     else if(RRC_cur_state == RRC_CXT_WB_s && !i_cxtmgt_cmd_prog_full && !i_cxtmgt_cxt_prog_full) begin
		//When release a packet, update UnAcked PSN
        if(qv_sub_state == `ACK_RELEASE_NORMAL || qv_sub_state == `ACK_RELEASE_EXCEPTION || qv_sub_state == `NAK_RELEASE || qv_sub_state == `READ_RELEASE) begin
            q_cxtmgt_cxt_wr_en <= 'd1;
            qv_cxtmgt_cxt_data <= {96'h0, qv_release_curPSN, 5'h0, qv_qp_state};
        end
		//When flush a packet, write back qp_state, do not modify UnAcked PSN
		else if(qv_sub_state == `NAK_RETRANS || qv_sub_state == `WQE_FLUSH || qv_sub_state == `READ_RETRANS) begin 
			if(q_release_indicator) begin
            	q_cxtmgt_cxt_wr_en <= 'd1;
            	qv_cxtmgt_cxt_data <= {96'h0, qv_release_curPSN, 5'h0, qv_qp_state};
			end 
			else begin
	            q_cxtmgt_cxt_wr_en <= 'd1;
	            qv_cxtmgt_cxt_data <= {96'h0, wv_UnAckedPSN, 5'h0, qv_qp_state};
			end 
		end 
        else if(qv_sub_state == `READ_SCATTER) begin 
            q_cxtmgt_cxt_wr_en <= 'd1;
            qv_cxtmgt_cxt_data <= {96'h0, wv_UnAckedPSN + 1, 5'h0, qv_qp_state};
        end 
        else begin			//Timer expire, still write back cxt, but do not modify cxt 
            q_cxtmgt_cxt_wr_en <= 'd1;
            qv_cxtmgt_cxt_data <= {96'h0, wv_UnAckedPSN, 5'h0, qv_qp_state};       
        end         
     end
     else begin
         q_cxtmgt_cxt_wr_en <= 1'b0;
         qv_cxtmgt_cxt_data <= 'd0;
     end
 end 


/*********************************************** VTP Upload for Completion and Network Data ***************************************/
reg             [3:0]       qv_vtp_type;
reg             [3:0]       qv_vtp_opcode;      //Indicates the VirtToPhys operation
reg             [31:0]      qv_vtp_pd;
reg             [31:0]      qv_vtp_key;
reg             [63:0]      qv_vtp_vaddr;
reg             [31:0]      qv_vtp_length;

//-- qv_vtp_type --
always @(*) begin
    if (rst) begin
        qv_vtp_type = 'd0;        
        qv_vtp_opcode = 'd0;  
        qv_vtp_pd = 'd0; 
    end
    else if (RRC_cur_state == RRC_SCATTER_CMD_s) begin
        qv_vtp_type = `WR_REQ_DATA;
        qv_vtp_opcode = `WR_L_NET_DATA;
		qv_vtp_pd = wv_QP_PD;
//		qv_vtp_pd = 'd0;
    end
    else if (RRC_cur_state == RRC_RELEASE_s || RRC_cur_state == RRC_WQE_FLUSH_s || RRC_cur_state == RRC_BAD_REQ_s || RRC_cur_state == RRC_READ_COMPLETION_s) begin
        qv_vtp_type = `WR_REQ_DATA;
        qv_vtp_opcode = `WR_CQE_DATA;
		qv_vtp_pd = wv_CQ_PD;
//		qv_vtp_pd = 'd0;
    end
    else begin
        qv_vtp_type = 'd0;
        qv_vtp_opcode = 'd0;
        qv_vtp_pd = 'd0;             
    end
end

//-- qv_vtp_key --
//-- qv_vtp_vaddr --
always @(*) begin
    if (rst) begin
        qv_vtp_key = 'd0;
        qv_vtp_vaddr = 'd0;
    end
    else if (RRC_cur_state == RRC_SCATTER_CMD_s) begin
        qv_vtp_key = wv_entry_key;
        qv_vtp_vaddr = wv_entry_va;
    end
    else if(RRC_cur_state == RRC_RELEASE_s || RRC_cur_state == RRC_WQE_FLUSH_s || RRC_cur_state == RRC_BAD_REQ_s || RRC_cur_state == RRC_READ_COMPLETION_s) begin
        qv_vtp_key = wv_CQ_LKey;
        qv_vtp_vaddr = {40'd0, iv_rrc_cq_offset};
		//qv_vtp_key = 'd0;
		//qv_vtp_vaddr = 'd0;
    end
    else begin
        qv_vtp_key = 'd0;
        qv_vtp_vaddr = 'd0;
    end
end

//-- qv_vtp_length --
always @(*) begin
    if (rst) begin
        qv_vtp_length = 'd0;        
    end
    else if(RRC_cur_state == RRC_SCATTER_CMD_s) begin
        if(qv_pkt_left_length + qv_unwritten_len <= qv_cur_entry_left_length) begin
            qv_vtp_length = qv_pkt_left_length + qv_unwritten_len;
        end
        else begin
            qv_vtp_length = qv_cur_entry_left_length;
        end
    end
    else if(RRC_cur_state == RRC_RELEASE_s || RRC_cur_state == RRC_WQE_FLUSH_s || RRC_cur_state == RRC_BAD_REQ_s || RRC_cur_state == RRC_READ_COMPLETION_s) begin
        qv_vtp_length = `CQE_LENGTH;
    end
    else begin
        qv_vtp_length = 'd0;
    end
end

wire            [31:0]      wv_vtp_flags;
reg             [3:0]       qv_mthca_mpt_flag_sw_owns;
reg                         q_absolute_addr;
reg                         q_relative_addr;
reg                         q_mthca_mpt_flag_mio;
reg                         q_mthca_mpt_flag_bind_enable;
reg                         q_mthca_mpt_flag_physical;
reg                         q_mthca_mpt_flag_region;
reg                         q_ibv_access_on_demand;
reg                         q_ibv_access_zero_based;
reg                         q_ibv_access_mw_bind;
reg                         q_ibv_access_remote_atomic;
reg                         q_ibv_access_remote_read;
reg                         q_ibv_access_remote_write;
reg                         q_ibv_access_local_write;


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
    else if (RRC_cur_state == RRC_SCATTER_CMD_s) begin 
        qv_mthca_mpt_flag_sw_owns = 'd0;
        q_absolute_addr = 'd1;
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
        q_ibv_access_local_write = 'd1;
    end 
    else if (RRC_cur_state == RRC_RELEASE_s || RRC_cur_state == RRC_WQE_FLUSH_s || RRC_cur_state == RRC_BAD_REQ_s || RRC_cur_state == RRC_READ_COMPLETION_s) begin 
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

//VirtToPhys
//-- q_vtp_cmd_wr_en --
//-- qv_vtp_cmd_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_vtp_cmd_wr_en <= 1'b0;
        qv_vtp_cmd_data <= 'd0;        
    end
    else if (RRC_cur_state == RRC_SCATTER_CMD_s && !i_vtp_cmd_prog_full) begin
        q_vtp_cmd_wr_en <= 1'b1;
        qv_vtp_cmd_data <= {32'd0, qv_vtp_length, qv_vtp_vaddr, qv_vtp_key, qv_vtp_pd, wv_vtp_flags, 24'd0, qv_vtp_opcode, qv_vtp_type};
    end
    //Generate CPL: 1. In flush state; 2. In buffer flush state; 3. In bad req state
    else if(RRC_cur_state == RRC_RELEASE_s) begin
        if(((qv_release_counter != 0 && qv_release_PktLeftLen <= 32) || (qv_release_counter == 0 && wv_release_curPktLen == 0))
            && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_rc_te_loss_prog_full) begin //Meet the end of a pkt
			// if(qv_release_curOP == `SEND_ONLY || qv_release_curOP == `SEND_ONLY_WITH_IMM || qv_release_curOP == `SEND_LAST || qv_release_curOP == `SEND_LAST_WITH_IMM ||
			// 	qv_release_curOP == `RDMA_WRITE_ONLY || qv_release_curOP == `RDMA_WRITE_ONLY_WITH_IMM || qv_release_curOP == `RDMA_WRITE_LAST ||
			// 	qv_release_curOP == `RDMA_WRITE_LAST_WITH_IMM) begin
   //              if(w_cpl_can_be_upload) begin
	  //              q_vtp_cmd_wr_en <= 1'b1; 			//Generate a CQE
   //  	           qv_vtp_cmd_data <= {32'd0, qv_vtp_length, qv_vtp_vaddr, qv_vtp_key, qv_vtp_pd, wv_vtp_flags, 24'd0, qv_vtp_opcode, qv_vtp_type};
   //              end 
   //              else begin
   //                 q_vtp_cmd_wr_en <= 1'b0;             
   //                 qv_vtp_cmd_data <= {32'd0, qv_vtp_length, qv_vtp_vaddr, qv_vtp_key, qv_vtp_pd, wv_vtp_flags, 24'd0, qv_vtp_opcode, qv_vtp_type};                   
   //              end
			// end 
            if(w_gen_cpl_during_release && w_cpl_can_be_upload) begin
                q_vtp_cmd_wr_en <= 1'b1;          //Generate a CQE
                qv_vtp_cmd_data <= {32'd0, qv_vtp_length, qv_vtp_vaddr, qv_vtp_key, qv_vtp_pd, wv_vtp_flags, 24'd0, qv_vtp_opcode, qv_vtp_type};                
            end
			else begin 
	            q_vtp_cmd_wr_en <= 1'b0;
    	        qv_vtp_cmd_data <= qv_vtp_cmd_data;
			end 
        end
        else begin
            q_vtp_cmd_wr_en <= 1'b0;
            qv_vtp_cmd_data <= qv_vtp_cmd_data;
        end
    end
    else if(RRC_cur_state == RRC_WQE_FLUSH_s) begin
        if(((qv_flush_counter != 0 && qv_flush_PktLeftLen <= 32) || (qv_flush_counter == 0 && wv_flush_curPktLen == 0))
            && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_rc_te_loss_prog_full) begin //Meet the end of a pkt
			// if(qv_flush_curOP == `SEND_ONLY || qv_flush_curOP == `SEND_ONLY_WITH_IMM || qv_flush_curOP == `SEND_LAST || qv_flush_curOP == `SEND_LAST_WITH_IMM ||
			// 	qv_flush_curOP == `RDMA_WRITE_ONLY || qv_flush_curOP == `RDMA_WRITE_ONLY_WITH_IMM || qv_flush_curOP == `RDMA_WRITE_LAST ||
			// 	qv_flush_curOP == `RDMA_WRITE_LAST_WITH_IMM || qv_flush_curOP == `RDMA_READ_REQUEST) begin 
   //              if(w_cpl_can_be_upload) begin
	  //              q_vtp_cmd_wr_en <= 1'b1;			//Generate a CQE
   //  	           qv_vtp_cmd_data <= {32'd0, qv_vtp_length, qv_vtp_vaddr, qv_vtp_key, qv_vtp_pd, wv_vtp_flags, 24'd0, qv_vtp_opcode, qv_vtp_type};
   //              end 
   //              else begin
   //                 q_vtp_cmd_wr_en <= 1'b0;         //Generate a CQE
   //                 qv_vtp_cmd_data <= {32'd0, qv_vtp_length, qv_vtp_vaddr, qv_vtp_key, qv_vtp_pd, wv_vtp_flags, 24'd0, qv_vtp_opcode, qv_vtp_type};                   
   //              end
			// end
            if(w_gen_cpl_during_flush && w_cpl_can_be_upload) begin
                q_vtp_cmd_wr_en <= 1'b1;          //Generate a CQE
                qv_vtp_cmd_data <= {32'd0, qv_vtp_length, qv_vtp_vaddr, qv_vtp_key, qv_vtp_pd, wv_vtp_flags, 24'd0, qv_vtp_opcode, qv_vtp_type};                
            end
            else begin 
                q_vtp_cmd_wr_en <= 1'b0;
                qv_vtp_cmd_data <= qv_vtp_cmd_data;
            end  
        end
        else begin
            q_vtp_cmd_wr_en <= 1'b0;
            qv_vtp_cmd_data <= qv_vtp_cmd_data;
        end
    end
    else if(RRC_cur_state == RRC_READ_COMPLETION_s) begin
        if(w_cpl_can_be_upload) begin
            q_vtp_cmd_wr_en <= 1'b1;		//Generate a CQE
            qv_vtp_cmd_data <= {32'd0, qv_vtp_length, qv_vtp_vaddr, qv_vtp_key, qv_vtp_pd, wv_vtp_flags, 24'd0, qv_vtp_opcode, qv_vtp_type};
        end
        else begin
            q_vtp_cmd_wr_en <= 1'b0;
            qv_vtp_cmd_data <= qv_vtp_cmd_data;
        end
    end
    else if(RRC_cur_state == RRC_BAD_REQ_s) begin
        if(w_rpb_empty && w_swpb_empty && w_cpl_can_be_upload) begin
            q_vtp_cmd_wr_en <= 1'b1;		//Generate a CQE
            qv_vtp_cmd_data <= {32'd0, qv_vtp_length, qv_vtp_vaddr, qv_vtp_key, qv_vtp_pd, wv_vtp_flags, 24'd0, qv_vtp_opcode, qv_vtp_type};
        end
        else begin
            q_vtp_cmd_wr_en <= 1'b0;
            qv_vtp_cmd_data <= qv_vtp_cmd_data;
        end
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
    //else if(RRC_cur_state == RRC_SCATTER_CMD_s) begin
    //    q_vtp_resp_rd_en = !i_vtp_resp_empty;
    //end
    //else if(RRC_cur_state == RRC_RELEASE_s || RRC_cur_state == RRC_WQE_FLUSH_s || RRC_cur_state == RRC_BAD_REQ_s || RRC_cur_state == RRC_READ_COMPLETION_s) begin
    //    q_vtp_resp_rd_en = !i_vtp_resp_empty;
    //end
    else begin
        q_vtp_resp_rd_en = !i_vtp_resp_empty;
    end
end

//-- q_vtp_upload_wr_en -- 
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_vtp_upload_wr_en <= 1'b0;
    end
    else if (RRC_cur_state == RRC_SCATTER_DATA_s) begin //Similar to state transition
        if(qv_pkt_left_length + qv_unwritten_len <= qv_cur_entry_left_length) begin
            if(qv_pkt_left_length == 0 && !i_vtp_upload_prog_full) begin
                q_vtp_upload_wr_en <= 1'b1;
            end 
            else if(!i_vtp_upload_prog_full && !i_nd_from_hp_empty) begin
                q_vtp_upload_wr_en <= 1'b1;
            end
            else begin
                q_vtp_upload_wr_en <= 1'b0;
            end
        end
        else begin
            if(qv_cur_entry_left_length <= 32 && qv_cur_entry_left_length <= qv_unwritten_len && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin
                q_vtp_upload_wr_en <= 1'b1;
            end
            else if(qv_cur_entry_left_length <= 32 && qv_cur_entry_left_length > qv_unwritten_len && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_nd_from_hp_empty) begin
                q_vtp_upload_wr_en <= 1'b1;
            end
            else if(qv_cur_entry_left_length > 32 && !i_vtp_upload_prog_full && !i_nd_from_hp_empty) begin
                q_vtp_upload_wr_en <= 1'b1;
            end
            else begin
                q_vtp_upload_wr_en <= 1'b0;
            end
        end
    end
    //Generate CPL: 1. In flush state; 2. In buffer flush state; 3. In bad req state
    else if(RRC_cur_state == RRC_RELEASE_s) begin
        if(((qv_release_counter != 0 && qv_release_PktLeftLen <= 32) || (qv_release_counter == 0 && wv_release_curPktLen == 0))
            && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_rc_te_loss_prog_full) begin //Meet the end of a pkt
			// if(qv_release_curOP == `SEND_ONLY || qv_release_curOP == `SEND_ONLY_WITH_IMM || qv_release_curOP == `SEND_LAST || qv_release_curOP == `SEND_LAST_WITH_IMM ||
			// 	qv_release_curOP == `RDMA_WRITE_ONLY || qv_release_curOP == `RDMA_WRITE_ONLY_WITH_IMM || qv_release_curOP == `RDMA_WRITE_LAST ||
			// 	qv_release_curOP == `RDMA_WRITE_LAST_WITH_IMM) begin 
   //              if(i_rrc_resp_valid) begin
	  //              q_vtp_upload_wr_en <= 1'b1;
   //              end 
   //              else begin
   //                  q_vtp_upload_wr_en <= 1'b0;
   //              end
			// end 
            if(w_gen_cpl_during_release && w_cpl_can_be_upload) begin
                q_vtp_upload_wr_en <= 1'b1;               
            end
            else begin 
                q_vtp_upload_wr_en <= 1'b0;
            end 
        end
        else begin
            q_vtp_upload_wr_en <= 1'b0;
        end
    end
    else if(RRC_cur_state == RRC_WQE_FLUSH_s) begin
        if(((qv_flush_counter != 0 && qv_flush_PktLeftLen <= 32) || (qv_flush_counter == 0 && wv_flush_curPktLen == 0))
            && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_rc_te_loss_prog_full) begin //Meet the end of a pkt
			// if(qv_flush_curOP == `SEND_ONLY || qv_flush_curOP == `SEND_ONLY_WITH_IMM || qv_flush_curOP == `SEND_LAST || qv_flush_curOP == `SEND_LAST_WITH_IMM ||
			// 	qv_flush_curOP == `RDMA_WRITE_ONLY || qv_flush_curOP == `RDMA_WRITE_ONLY_WITH_IMM || qv_flush_curOP == `RDMA_WRITE_LAST ||
			// 	qv_flush_curOP == `RDMA_WRITE_LAST_WITH_IMM || qv_flush_curOP == `RDMA_READ_REQUEST) begin 
   //              if(i_rrc_resp_valid) begin
   //                 q_vtp_upload_wr_en <= 1'b1;
   //              end 
   //              else begin
   //                  q_vtp_upload_wr_en <= 1'b0;
   //              end
			// end 
            if(w_gen_cpl_during_flush && w_cpl_can_be_upload) begin
                q_vtp_upload_wr_en <= 1'b1;               
            end
            else begin 
                q_vtp_upload_wr_en <= 1'b0;
            end 
        end
        else begin
            q_vtp_upload_wr_en <= 1'b0;
        end
    end
    else if(RRC_cur_state == RRC_BAD_REQ_s) begin
        if(w_rpb_empty && w_swpb_empty && w_cpl_can_be_upload) begin
            if(i_rrc_resp_valid) begin
               q_vtp_upload_wr_en <= 1'b1;
            end 
            else begin
                q_vtp_upload_wr_en <= 1'b0;
            end
        end
        else begin
            q_vtp_upload_wr_en <= 1'b0;
        end
    end
    else if(RRC_cur_state == RRC_READ_COMPLETION_s && w_cpl_can_be_upload) begin
        q_vtp_upload_wr_en <= 1'b1;
    end
    else begin
        q_vtp_upload_wr_en <= 1'b0;
    end
end

reg             [31:0]          qv_my_qpn;
reg             [31:0]          qv_my_ee;
reg             [31:0]          qv_rqpn;
reg             [15:0]          qv_rlid;
reg             [15:0]          qv_sl_g_mlpath;
reg             [31:0]          qv_imm_etype_pkey_eec;
reg             [31:0]          qv_byte_cnt;
reg             [31:0]          qv_wqe;
reg             [7:0]           qv_owner;
reg             [7:0]           qv_is_send;
reg             [7:0]           qv_opcode;

reg 			[7:0]			qv_cur_verbs;

reg             [7:0]           qv_vendor_err;
reg             [7:0]           qv_syndrome;

always @(*) begin
	if(rst) begin
		qv_cur_verbs = 'd0;
	end 
    else if(RRC_cur_state == RRC_RELEASE_s) begin 
		if(qv_release_curOP == `SEND_ONLY || qv_release_curOP == `SEND_LAST) begin
			qv_cur_verbs = `VERBS_SEND;
		end 
		else if(qv_release_curOP == `SEND_ONLY_WITH_IMM || qv_release_curOP == `SEND_LAST_WITH_IMM) begin
			qv_cur_verbs = `VERBS_SEND_WITH_IMM;
		end 
		else if(qv_release_curOP == `RDMA_WRITE_ONLY || qv_release_curOP == `RDMA_WRITE_LAST) begin
			qv_cur_verbs = `VERBS_RDMA_WRITE;
		end 
		else if(qv_release_curOP == `RDMA_WRITE_ONLY_WITH_IMM || qv_release_curOP == `RDMA_WRITE_LAST_WITH_IMM) begin
			qv_cur_verbs = `VERBS_RDMA_WRITE_WITH_IMM;
		end 
		else begin
			qv_cur_verbs = 'd0;
		end 
	end 
    else if(RRC_cur_state == RRC_WQE_FLUSH_s) begin
		if(qv_flush_curOP == `SEND_ONLY || qv_flush_curOP == `SEND_LAST) begin
			qv_cur_verbs = `VERBS_SEND;
		end 
		else if(qv_flush_curOP == `SEND_ONLY_WITH_IMM || qv_flush_curOP == `SEND_LAST_WITH_IMM) begin
			qv_cur_verbs = `VERBS_SEND_WITH_IMM;
		end 
		else if(qv_flush_curOP == `RDMA_WRITE_ONLY || qv_flush_curOP == `RDMA_WRITE_LAST) begin
			qv_cur_verbs = `VERBS_RDMA_WRITE;
		end 
		else if(qv_flush_curOP == `RDMA_WRITE_ONLY_WITH_IMM || qv_flush_curOP == `RDMA_WRITE_LAST_WITH_IMM) begin
			qv_cur_verbs = `VERBS_RDMA_WRITE_WITH_IMM;
		end 
		else begin
			qv_cur_verbs = 'd0;
		end 
	end  
    else if(RRC_cur_state == RRC_BAD_REQ_s) begin 
		qv_cur_verbs = iv_br_data[39:32];
	end 
	else if(RRC_cur_state == RRC_RELEASE_ENTRY_s) begin
		qv_cur_verbs = `VERBS_RDMA_READ;
	end 
    //else if(RRC_cur_state == RRC_READ_COMPLETION_s) begin 
	//	qv_cur_verbs = `VERBS_RDMA_READ;
	//end 
	else begin
		qv_cur_verbs = 'd0;
	end 
end 

reg             [31:0]          qv_my_qpn_TempReg;
reg             [31:0]          qv_my_ee_TempReg;
reg             [31:0]          qv_rqpn_TempReg;
reg             [15:0]          qv_rlid_TempReg;
reg             [15:0]          qv_sl_g_mlpath_TempReg;
reg             [31:0]          qv_imm_etype_pkey_eec_TempReg;
reg             [31:0]          qv_byte_cnt_TempReg;
reg             [7:0]           qv_owner_TempReg;
reg             [7:0]           qv_is_send_TempReg;
reg             [7:0]           qv_opcode_TempReg;
reg 			[31:0]			qv_wqe_TempReg;			//Patch for READ_COMPLETION
always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_my_qpn_TempReg <= 'd0;
		qv_my_ee_TempReg <= 'd0;
		qv_rqpn_TempReg <= 'd0;
		qv_rlid_TempReg <= 'd0;
		qv_sl_g_mlpath_TempReg <= 'd0;
		qv_imm_etype_pkey_eec_TempReg <= 'd0;
		qv_byte_cnt_TempReg <= 'd0;
		qv_owner_TempReg <= 'd0;
		qv_is_send_TempReg <= 'd0;
		qv_opcode_TempReg <= 'd0;
		qv_wqe_TempReg <= 'd0;			//Patch for READ_COMPLETION
	end 
	else begin
		qv_my_qpn_TempReg <= qv_my_qpn;
		qv_my_ee_TempReg <= qv_my_ee;
		qv_rqpn_TempReg <= qv_rqpn;
		qv_rlid_TempReg <= qv_rlid;
		qv_sl_g_mlpath_TempReg <= qv_sl_g_mlpath;
		qv_imm_etype_pkey_eec_TempReg <= qv_imm_etype_pkey_eec;
		qv_byte_cnt_TempReg <= qv_byte_cnt;
		qv_owner_TempReg <= qv_owner;
		qv_is_send_TempReg <= qv_is_send;
		qv_opcode_TempReg <= qv_opcode;
		qv_wqe_TempReg <= qv_wqe;			//Patch for READ_COMPLETION
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
    else if(RRC_cur_state == RRC_RELEASE_s) begin 
        qv_my_qpn = {8'd0, qv_cur_event_QPN};
        qv_my_ee = 'd0;
        qv_rqpn = wv_cxtmgt_cxt_data[109:96];
        qv_rlid = wv_rlid;
        qv_sl_g_mlpath = 'd0;
        qv_imm_etype_pkey_eec = 'd0;
        qv_byte_cnt = wv_bc_doutb;              
        qv_wqe = w_cur_release_is_read ? iv_rpb_content_doutb[261:230] : iv_swpb_content_doutb[287:256];
        qv_owner = 8'b00000000;
        qv_is_send = 'd1;
        //qv_opcode = 'd0;
        qv_opcode = qv_cur_verbs;

        qv_vendor_err = 'd0;
    end
    else if(RRC_cur_state == RRC_WQE_FLUSH_s) begin 
        qv_my_qpn = {8'd0, qv_cur_event_QPN};
        qv_my_ee = 'd0;
        qv_rqpn = wv_cxtmgt_cxt_data[109:96];
        qv_rlid = wv_rlid;
        qv_sl_g_mlpath = 'd0;
        qv_imm_etype_pkey_eec = 'd0;
        qv_byte_cnt = wv_bc_doutb;              
        qv_wqe = w_flush_read ? iv_rpb_content_doutb[261:230] : iv_swpb_content_doutb[287:256];
        qv_owner = 8'b00000000;
        qv_is_send = 'd1;
        qv_opcode = 8'hff;

        qv_vendor_err = 'd0;
    end 
    else if(RRC_cur_state == RRC_BAD_REQ_s) begin
        qv_my_qpn = {8'd0, qv_cur_event_QPN};
        qv_my_ee = 'd0;
        qv_rqpn = wv_cxtmgt_cxt_data[109:96];
        qv_rlid = wv_rlid;
        qv_sl_g_mlpath = 'd0;
        qv_imm_etype_pkey_eec = 'd0;
        qv_byte_cnt = wv_bc_doutb;              
        qv_wqe = wv_bad_wqe_offset;
        qv_owner = 8'b00000000;
        qv_is_send = 'd1;
        qv_opcode = 8'hff;

        qv_vendor_err = 'd0;       
    end
    //else if(RRC_cur_state == RRC_READ_COMPLETION_s) begin
    else if(RRC_cur_state == RRC_RELEASE_ENTRY_s) begin
        qv_my_qpn = {8'd0, qv_cur_event_QPN};
        qv_my_ee = 'd0;
        qv_rqpn = wv_cxtmgt_cxt_data[109:96];
        qv_rlid = wv_rlid;
        qv_sl_g_mlpath = 'd0;
        qv_imm_etype_pkey_eec = 'd0;
        qv_byte_cnt = wv_bc_doutb;              
        qv_wqe = iv_rpb_content_doutb[261:230];
        qv_owner = 8'b00000000;
        qv_is_send = 'd1;
        qv_opcode = qv_cur_verbs;

        qv_vendor_err = 'd0;       
    end    
    else begin 
        qv_my_qpn = qv_my_qpn_TempReg;
        qv_my_ee = qv_my_ee_TempReg;
        qv_rqpn = qv_rqpn_TempReg;
        qv_rlid = qv_rlid_TempReg;
        qv_sl_g_mlpath = qv_sl_g_mlpath_TempReg;
        qv_imm_etype_pkey_eec = qv_imm_etype_pkey_eec_TempReg;
        qv_byte_cnt = qv_byte_cnt_TempReg;
        qv_wqe = qv_wqe_TempReg;
        qv_owner = qv_owner_TempReg;
        qv_is_send = qv_is_send_TempReg;
        qv_opcode = qv_opcode_TempReg;

        qv_vendor_err = 'd0;
    end 
end 

//-- qv_syndorme --
always @(*) begin
    if (rst) begin
        qv_syndrome = 'd0;        
    end
    else begin
        qv_syndrome = 'd0;
    end
end

//-- qv_vtp_upload_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_vtp_upload_data <= 'd0;        
    end
    else if (RRC_cur_state == RRC_SCATTER_DATA_s) begin
        if(qv_pkt_left_length + qv_unwritten_len <= qv_cur_entry_left_length) begin     //Entry is enough
            if(qv_pkt_left_length == 0 && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin
                case(qv_unwritten_len)
                    0:          qv_vtp_upload_data <= iv_nd_from_hp_data;   //In this conditional branch, this will not happen
                    1:          qv_vtp_upload_data <= {248'd0, qv_unwritten_data[1 * 8 - 1 : 0]}; 
                    2:          qv_vtp_upload_data <= {240'd0, qv_unwritten_data[2 * 8 - 1 : 0]}; 
                    3:          qv_vtp_upload_data <= {232'd0, qv_unwritten_data[3 * 8 - 1 : 0]}; 
                    4:          qv_vtp_upload_data <= {224'd0, qv_unwritten_data[4 * 8 - 1 : 0]}; 
                    5:          qv_vtp_upload_data <= {216'd0, qv_unwritten_data[5 * 8 - 1 : 0]}; 
                    6:          qv_vtp_upload_data <= {208'd0, qv_unwritten_data[6 * 8 - 1 : 0]}; 
                    7:          qv_vtp_upload_data <= {200'd0, qv_unwritten_data[7 * 8 - 1 : 0]}; 
                    8:          qv_vtp_upload_data <= {192'd0, qv_unwritten_data[8 * 8 - 1 : 0]}; 
                    9:          qv_vtp_upload_data <= {184'd0, qv_unwritten_data[9 * 8 - 1 : 0]}; 
                    10:         qv_vtp_upload_data <= {176'd0, qv_unwritten_data[10 * 8 - 1 : 0]};
                    11:         qv_vtp_upload_data <= {168'd0, qv_unwritten_data[11 * 8 - 1 : 0]};
                    12:         qv_vtp_upload_data <= {160'd0, qv_unwritten_data[12 * 8 - 1 : 0]};
                    13:         qv_vtp_upload_data <= {152'd0, qv_unwritten_data[13 * 8 - 1 : 0]};
                    14:         qv_vtp_upload_data <= {144'd0, qv_unwritten_data[14 * 8 - 1 : 0]};
                    15:         qv_vtp_upload_data <= {136'd0, qv_unwritten_data[15 * 8 - 1 : 0]};
                    16:         qv_vtp_upload_data <= {128'd0, qv_unwritten_data[16 * 8 - 1 : 0]};
                    17:         qv_vtp_upload_data <= {120'd0, qv_unwritten_data[17 * 8 - 1 : 0]};
                    18:         qv_vtp_upload_data <= {112'd0, qv_unwritten_data[18 * 8 - 1 : 0]};
                    19:         qv_vtp_upload_data <= {104'd0, qv_unwritten_data[19 * 8 - 1 : 0]};
                    20:         qv_vtp_upload_data <= {96'd0, qv_unwritten_data[20 * 8 - 1 : 0]};
                    21:         qv_vtp_upload_data <= {88'd0, qv_unwritten_data[21 * 8 - 1 : 0]};
                    22:         qv_vtp_upload_data <= {80'd0, qv_unwritten_data[22 * 8 - 1 : 0]};
                    23:         qv_vtp_upload_data <= {72'd0, qv_unwritten_data[23 * 8 - 1 : 0]};
                    24:         qv_vtp_upload_data <= {64'd0, qv_unwritten_data[24 * 8 - 1 : 0]};
                    25:         qv_vtp_upload_data <= {56'd0, qv_unwritten_data[25 * 8 - 1 : 0]};
                    26:         qv_vtp_upload_data <= {48'd0, qv_unwritten_data[26 * 8 - 1 : 0]};
                    27:         qv_vtp_upload_data <= {40'd0, qv_unwritten_data[27 * 8 - 1 : 0]};
                    28:         qv_vtp_upload_data <= {32'd0, qv_unwritten_data[28 * 8 - 1 : 0]};
                    29:         qv_vtp_upload_data <= {24'd0, qv_unwritten_data[29 * 8 - 1 : 0]};
                    30:         qv_vtp_upload_data <= {16'd0, qv_unwritten_data[30 * 8 - 1 : 0]};
                    31:         qv_vtp_upload_data <= {8'd0, qv_unwritten_data[31 * 8 - 1 : 0]};
                    default:    qv_vtp_upload_data <= qv_vtp_upload_data;
                endcase
            end
            else if(qv_pkt_left_length > 0 && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_nd_from_hp_empty) begin
                case(qv_unwritten_len)
                    0:          qv_vtp_upload_data <= iv_nd_from_hp_data;  
                    1:          qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 1 ) * 8 - 1 : 0], qv_unwritten_data[1 * 8 - 1 : 0]}; 
                    2:          qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 2 ) * 8 - 1 : 0], qv_unwritten_data[2 * 8 - 1 : 0]}; 
                    3:          qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 3 ) * 8 - 1 : 0], qv_unwritten_data[3 * 8 - 1 : 0]}; 
                    4:          qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 4 ) * 8 - 1 : 0], qv_unwritten_data[4 * 8 - 1 : 0]}; 
                    5:          qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 5 ) * 8 - 1 : 0], qv_unwritten_data[5 * 8 - 1 : 0]}; 
                    6:          qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 6 ) * 8 - 1 : 0], qv_unwritten_data[6 * 8 - 1 : 0]}; 
                    7:          qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 7 ) * 8 - 1 : 0], qv_unwritten_data[7 * 8 - 1 : 0]}; 
                    8:          qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 8 ) * 8 - 1 : 0], qv_unwritten_data[8 * 8 - 1 : 0]}; 
                    9:          qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 9 ) * 8 - 1 : 0], qv_unwritten_data[9 * 8 - 1 : 0]}; 
                    10:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 10) * 8 - 1 : 0], qv_unwritten_data[10 * 8 - 1 : 0]};
                    11:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 11) * 8 - 1 : 0], qv_unwritten_data[11 * 8 - 1 : 0]};
                    12:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 12) * 8 - 1 : 0], qv_unwritten_data[12 * 8 - 1 : 0]};
                    13:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 13) * 8 - 1 : 0], qv_unwritten_data[13 * 8 - 1 : 0]};
                    14:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 14) * 8 - 1 : 0], qv_unwritten_data[14 * 8 - 1 : 0]};
                    15:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 15) * 8 - 1 : 0], qv_unwritten_data[15 * 8 - 1 : 0]};
                    16:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 16) * 8 - 1 : 0], qv_unwritten_data[16 * 8 - 1 : 0]};
                    17:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 17) * 8 - 1 : 0], qv_unwritten_data[17 * 8 - 1 : 0]};
                    18:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 18) * 8 - 1 : 0], qv_unwritten_data[18 * 8 - 1 : 0]};
                    19:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 19) * 8 - 1 : 0], qv_unwritten_data[19 * 8 - 1 : 0]};
                    20:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 20) * 8 - 1 : 0], qv_unwritten_data[20 * 8 - 1 : 0]};
                    21:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 21) * 8 - 1 : 0], qv_unwritten_data[21 * 8 - 1 : 0]};
                    22:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 22) * 8 - 1 : 0], qv_unwritten_data[22 * 8 - 1 : 0]};
                    23:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 23) * 8 - 1 : 0], qv_unwritten_data[23 * 8 - 1 : 0]};
                    24:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 24) * 8 - 1 : 0], qv_unwritten_data[24 * 8 - 1 : 0]};
                    25:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 25) * 8 - 1 : 0], qv_unwritten_data[25 * 8 - 1 : 0]};
                    26:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 26) * 8 - 1 : 0], qv_unwritten_data[26 * 8 - 1 : 0]};
                    27:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 27) * 8 - 1 : 0], qv_unwritten_data[27 * 8 - 1 : 0]};
                    28:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 28) * 8 - 1 : 0], qv_unwritten_data[28 * 8 - 1 : 0]};
                    29:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 29) * 8 - 1 : 0], qv_unwritten_data[29 * 8 - 1 : 0]};
                    30:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 30) * 8 - 1 : 0], qv_unwritten_data[30 * 8 - 1 : 0]};
                    31:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 31) * 8 - 1 : 0], qv_unwritten_data[31 * 8 - 1 : 0]};
                    default:    qv_vtp_upload_data <= qv_vtp_upload_data;
                endcase
            end
            else begin
                qv_vtp_upload_data <= qv_vtp_upload_data;
            end
        end
        else begin  //Entry is not enough
            if(qv_cur_entry_left_length <= qv_unwritten_len && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin
                case(qv_cur_entry_left_length)
                    0:          qv_vtp_upload_data <= iv_nd_from_hp_data;   //In this conditional branch, this will not happen
                    1:          qv_vtp_upload_data <= {248'd0, qv_unwritten_data[1 * 8 - 1 : 0]}; 
                    2:          qv_vtp_upload_data <= {240'd0, qv_unwritten_data[2 * 8 - 1 : 0]}; 
                    3:          qv_vtp_upload_data <= {232'd0, qv_unwritten_data[3 * 8 - 1 : 0]}; 
                    4:          qv_vtp_upload_data <= {224'd0, qv_unwritten_data[4 * 8 - 1 : 0]}; 
                    5:          qv_vtp_upload_data <= {216'd0, qv_unwritten_data[5 * 8 - 1 : 0]}; 
                    6:          qv_vtp_upload_data <= {208'd0, qv_unwritten_data[6 * 8 - 1 : 0]}; 
                    7:          qv_vtp_upload_data <= {200'd0, qv_unwritten_data[7 * 8 - 1 : 0]}; 
                    8:          qv_vtp_upload_data <= {192'd0, qv_unwritten_data[8 * 8 - 1 : 0]}; 
                    9:          qv_vtp_upload_data <= {184'd0, qv_unwritten_data[9 * 8 - 1 : 0]}; 
                    10:         qv_vtp_upload_data <= {176'd0, qv_unwritten_data[10 * 8 - 1 : 0]};
                    11:         qv_vtp_upload_data <= {168'd0, qv_unwritten_data[11 * 8 - 1 : 0]};
                    12:         qv_vtp_upload_data <= {160'd0, qv_unwritten_data[12 * 8 - 1 : 0]};
                    13:         qv_vtp_upload_data <= {152'd0, qv_unwritten_data[13 * 8 - 1 : 0]};
                    14:         qv_vtp_upload_data <= {144'd0, qv_unwritten_data[14 * 8 - 1 : 0]};
                    15:         qv_vtp_upload_data <= {136'd0, qv_unwritten_data[15 * 8 - 1 : 0]};
                    16:         qv_vtp_upload_data <= {128'd0, qv_unwritten_data[16 * 8 - 1 : 0]};
                    17:         qv_vtp_upload_data <= {120'd0, qv_unwritten_data[17 * 8 - 1 : 0]};
                    18:         qv_vtp_upload_data <= {112'd0, qv_unwritten_data[18 * 8 - 1 : 0]};
                    19:         qv_vtp_upload_data <= {104'd0, qv_unwritten_data[19 * 8 - 1 : 0]};
                    20:         qv_vtp_upload_data <= {96'd0, qv_unwritten_data[20 * 8 - 1 : 0]};
                    21:         qv_vtp_upload_data <= {88'd0, qv_unwritten_data[21 * 8 - 1 : 0]};
                    22:         qv_vtp_upload_data <= {80'd0, qv_unwritten_data[22 * 8 - 1 : 0]};
                    23:         qv_vtp_upload_data <= {72'd0, qv_unwritten_data[23 * 8 - 1 : 0]};
                    24:         qv_vtp_upload_data <= {64'd0, qv_unwritten_data[24 * 8 - 1 : 0]};
                    25:         qv_vtp_upload_data <= {56'd0, qv_unwritten_data[25 * 8 - 1 : 0]};
                    26:         qv_vtp_upload_data <= {48'd0, qv_unwritten_data[26 * 8 - 1 : 0]};
                    27:         qv_vtp_upload_data <= {40'd0, qv_unwritten_data[27 * 8 - 1 : 0]};
                    28:         qv_vtp_upload_data <= {32'd0, qv_unwritten_data[28 * 8 - 1 : 0]};
                    29:         qv_vtp_upload_data <= {24'd0, qv_unwritten_data[29 * 8 - 1 : 0]};
                    30:         qv_vtp_upload_data <= {16'd0, qv_unwritten_data[30 * 8 - 1 : 0]};
                    31:         qv_vtp_upload_data <= {8'd0, qv_unwritten_data[31 * 8 - 1 : 0]};
                    default:    qv_vtp_upload_data <= qv_vtp_upload_data;
                endcase
            end
            else if(qv_cur_entry_left_length > qv_unwritten_len && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_nd_from_hp_empty) begin
                case(qv_unwritten_len)
                    0:          qv_vtp_upload_data <= iv_nd_from_hp_data;   
                    1:          qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 1 ) * 8 - 1 : 0], qv_unwritten_data[1 * 8 - 1 : 0]}; 
                    2:          qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 2 ) * 8 - 1 : 0], qv_unwritten_data[2 * 8 - 1 : 0]}; 
                    3:          qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 3 ) * 8 - 1 : 0], qv_unwritten_data[3 * 8 - 1 : 0]}; 
                    4:          qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 4 ) * 8 - 1 : 0], qv_unwritten_data[4 * 8 - 1 : 0]}; 
                    5:          qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 5 ) * 8 - 1 : 0], qv_unwritten_data[5 * 8 - 1 : 0]}; 
                    6:          qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 6 ) * 8 - 1 : 0], qv_unwritten_data[6 * 8 - 1 : 0]}; 
                    7:          qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 7 ) * 8 - 1 : 0], qv_unwritten_data[7 * 8 - 1 : 0]}; 
                    8:          qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 8 ) * 8 - 1 : 0], qv_unwritten_data[8 * 8 - 1 : 0]}; 
                    9:          qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 9 ) * 8 - 1 : 0], qv_unwritten_data[9 * 8 - 1 : 0]}; 
                    10:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 10) * 8 - 1 : 0], qv_unwritten_data[10 * 8 - 1 : 0]};
                    11:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 11) * 8 - 1 : 0], qv_unwritten_data[11 * 8 - 1 : 0]};
                    12:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 12) * 8 - 1 : 0], qv_unwritten_data[12 * 8 - 1 : 0]};
                    13:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 13) * 8 - 1 : 0], qv_unwritten_data[13 * 8 - 1 : 0]};
                    14:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 14) * 8 - 1 : 0], qv_unwritten_data[14 * 8 - 1 : 0]};
                    15:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 15) * 8 - 1 : 0], qv_unwritten_data[15 * 8 - 1 : 0]};
                    16:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 16) * 8 - 1 : 0], qv_unwritten_data[16 * 8 - 1 : 0]};
                    17:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 17) * 8 - 1 : 0], qv_unwritten_data[17 * 8 - 1 : 0]};
                    18:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 18) * 8 - 1 : 0], qv_unwritten_data[18 * 8 - 1 : 0]};
                    19:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 19) * 8 - 1 : 0], qv_unwritten_data[19 * 8 - 1 : 0]};
                    20:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 20) * 8 - 1 : 0], qv_unwritten_data[20 * 8 - 1 : 0]};
                    21:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 21) * 8 - 1 : 0], qv_unwritten_data[21 * 8 - 1 : 0]};
                    22:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 22) * 8 - 1 : 0], qv_unwritten_data[22 * 8 - 1 : 0]};
                    23:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 23) * 8 - 1 : 0], qv_unwritten_data[23 * 8 - 1 : 0]};
                    24:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 24) * 8 - 1 : 0], qv_unwritten_data[24 * 8 - 1 : 0]};
                    25:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 25) * 8 - 1 : 0], qv_unwritten_data[25 * 8 - 1 : 0]};
                    26:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 26) * 8 - 1 : 0], qv_unwritten_data[26 * 8 - 1 : 0]};
                    27:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 27) * 8 - 1 : 0], qv_unwritten_data[27 * 8 - 1 : 0]};
                    28:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 28) * 8 - 1 : 0], qv_unwritten_data[28 * 8 - 1 : 0]};
                    29:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 29) * 8 - 1 : 0], qv_unwritten_data[29 * 8 - 1 : 0]};
                    30:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 30) * 8 - 1 : 0], qv_unwritten_data[30 * 8 - 1 : 0]};
                    31:         qv_vtp_upload_data <= {iv_nd_from_hp_data[(32 - 31) * 8 - 1 : 0], qv_unwritten_data[31 * 8 - 1 : 0]};
                    default:    qv_vtp_upload_data <= qv_vtp_upload_data;
                endcase                
            end 
            else begin
                qv_vtp_upload_data <= qv_vtp_upload_data;
            end 
        end
    end
    //Generate CPL: 1. In release state; 2. In buffer release state; 3. In bad req state
    else if(RRC_cur_state == RRC_RELEASE_s) begin
        if(((qv_release_counter != 0 && qv_release_PktLeftLen <= 32) || (qv_release_counter == 0 && wv_release_curPktLen == 0))
            && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_rc_te_loss_prog_full) begin //Meet the end of a pkt
			// if(qv_release_curOP == `SEND_ONLY || qv_release_curOP == `SEND_ONLY_WITH_IMM || qv_release_curOP == `SEND_LAST || qv_release_curOP == `SEND_LAST_WITH_IMM ||
			// 	qv_release_curOP == `RDMA_WRITE_ONLY || qv_release_curOP == `RDMA_WRITE_ONLY_WITH_IMM || qv_release_curOP == `RDMA_WRITE_LAST ||
			// 	qv_release_curOP == `RDMA_WRITE_LAST_WITH_IMM) begin 
            if(w_gen_cpl_during_release && w_cpl_can_be_upload) begin
//            	qv_vtp_upload_data <= {qv_opcode, qv_is_send, 8'd0, qv_owner, qv_wqe, qv_imm_etype_pkey_eec, qv_sl_g_mlpath, qv_rlid, qv_rqpn, qv_my_ee, qv_my_qpn};
            	//qv_vtp_upload_data <= {qv_owner, 8'd0, qv_is_send, qv_opcode, qv_wqe, qv_byte_cnt, qv_imm_etype_pkey_eec, qv_sl_g_mlpath, qv_rlid, qv_rqpn, qv_my_ee, qv_my_qpn};
            	qv_vtp_upload_data <= {qv_owner, 8'd0, qv_is_send, qv_opcode, qv_wqe, qv_byte_cnt, qv_imm_etype_pkey_eec, qv_rlid, qv_sl_g_mlpath, qv_rqpn, qv_my_ee, qv_my_qpn};
			end 
			else begin 
				qv_vtp_upload_data <= qv_vtp_upload_data;
			end 
        end
        else begin
            qv_vtp_upload_data <= qv_vtp_upload_data;
        end
    end
    else if(RRC_cur_state == RRC_WQE_FLUSH_s) begin
        if(((qv_flush_counter != 0 && qv_flush_PktLeftLen <= 32) || (qv_flush_counter == 0 && wv_flush_curPktLen == 0))
            && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_rc_te_loss_prog_full) begin //Meet the end of a pkt
			// if(qv_flush_curOP == `SEND_ONLY || qv_flush_curOP == `SEND_ONLY_WITH_IMM || qv_flush_curOP == `SEND_LAST || qv_flush_curOP == `SEND_LAST_WITH_IMM ||
			// 	qv_flush_curOP == `RDMA_WRITE_ONLY || qv_flush_curOP == `RDMA_WRITE_ONLY_WITH_IMM || qv_flush_curOP == `RDMA_WRITE_LAST ||
			// 	qv_flush_curOP == `RDMA_WRITE_LAST_WITH_IMM) begin 
            if(w_gen_cpl_during_flush) begin
                //qv_vtp_upload_data <= {qv_opcode, 8'd0, 8'd0, qv_owner, qv_wqe, 32'd0, qv_syndrome, qv_vendor_err, 16'd0, 96'd0, qv_my_qpn};
                qv_vtp_upload_data <= {qv_owner, 8'd0, 8'd0, qv_opcode, qv_wqe, 32'd0, qv_syndrome, qv_vendor_err, 16'd0, 96'd0, qv_my_qpn};
			end 
			else begin
            	//qv_vtp_upload_data <= {qv_opcode, 8'd0, 8'd0, qv_owner, qv_wqe, 32'd0, qv_syndrome, qv_vendor_err, 16'd0, 96'd0, qv_my_qpn};
                qv_vtp_upload_data <= {qv_owner, 8'd0, 8'd0, qv_opcode, qv_wqe, 32'd0, qv_syndrome, qv_vendor_err, 16'd0, 96'd0, qv_my_qpn};
			end 
        end
        else begin
            qv_vtp_upload_data <= qv_vtp_upload_data;
        end
    end
    else if(RRC_cur_state == RRC_BAD_REQ_s) begin
        if(w_rpb_empty && w_swpb_empty && w_cpl_can_be_upload) begin
            //qv_vtp_upload_data <= {qv_opcode, 8'd0, 8'd0, qv_owner, qv_wqe, 32'd0, qv_syndrome, qv_vendor_err, 16'd0, 96'd0, qv_my_qpn};
            qv_vtp_upload_data <= {qv_owner, 8'd0, 8'd0, qv_opcode, qv_wqe, 32'd0, qv_syndrome, qv_vendor_err, 16'd0, 96'd0, qv_my_qpn};
        end
        else begin
            qv_vtp_upload_data <= qv_vtp_upload_data;
        end
    end
    else if(RRC_cur_state == RRC_READ_COMPLETION_s && w_cpl_can_be_upload) begin
//        qv_vtp_upload_data <= {qv_opcode, qv_is_send, 8'd0, qv_owner, qv_wqe, qv_imm_etype_pkey_eec, qv_sl_g_mlpath, qv_rlid, qv_rqpn, qv_my_ee, qv_my_qpn};
        //qv_vtp_upload_data <= {qv_owner, 8'd0, qv_is_send, qv_opcode, qv_wqe, qv_byte_cnt, qv_imm_etype_pkey_eec, qv_sl_g_mlpath, qv_rlid, qv_rqpn, qv_my_ee, qv_my_qpn};
        qv_vtp_upload_data <= {qv_owner, 8'd0, qv_is_send, qv_opcode, qv_wqe, qv_byte_cnt, qv_imm_etype_pkey_eec, qv_rlid, qv_sl_g_mlpath, qv_rqpn, qv_my_ee, qv_my_qpn};
    end
    else begin
        qv_vtp_upload_data <= qv_vtp_upload_data;
    end
end

//-- q_br_rd_en --
always @(*) begin
    if(rst) begin
        q_br_rd_en = 'd0;
    end
    else if(RRC_cur_state == RRC_BAD_REQ_s && w_rpb_empty && w_swpb_empty && !i_br_empty && w_cpl_can_be_upload) begin
        q_br_rd_en = 'd1;
    end
    else begin
        q_br_rd_en = 'd0;
    end
end

/******************************************************************** CQ Table : Begin ***********************************************/

//-- q_rrc_req_valid --
//-- qv_rrc_cq_index --
//-- qv_rrc_cq_size --
always @(*) begin
    if (rst) begin
        q_rrc_req_valid = 1'b0;
        qv_rrc_cq_index = 'd0;
        qv_rrc_cq_size = 'd0;      
    end
    //Obtain CQ Offset: 1. In flush state; 2. In buffer flush state; 3. In bad req state
    else if(RRC_cur_state == RRC_RELEASE_s) begin
        if(w_gen_cpl_during_release && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_rc_te_loss_prog_full) begin
    		q_rrc_req_valid = !i_rrc_resp_valid;
    		qv_rrc_cq_index = wv_cqn;
    		qv_rrc_cq_size = wv_cq_length;       
        end
        else begin
        	q_rrc_req_valid = 1'b0;
        	qv_rrc_cq_index = wv_cqn;
        	qv_rrc_cq_size = wv_cq_length;       
        end
    end
    else if(RRC_cur_state == RRC_WQE_FLUSH_s) begin
        if(w_gen_cpl_during_flush && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_rc_te_loss_prog_full) begin
            q_rrc_req_valid = !i_rrc_resp_valid;
            qv_rrc_cq_index = wv_cqn;
            qv_rrc_cq_size = wv_cq_length;    
        end
        else begin
        	q_rrc_req_valid = 1'b0;
        	qv_rrc_cq_index = wv_cqn;
        	qv_rrc_cq_size = wv_cq_length;       
        end
    end
    else if(RRC_cur_state == RRC_READ_COMPLETION_s) begin
        if(!i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_rc_te_loss_prog_full) begin
            q_rrc_req_valid = !i_rrc_resp_valid;
            qv_rrc_cq_index = wv_cqn;
        	qv_rrc_cq_size = wv_cq_length;       
        end
        else begin
        	q_rrc_req_valid = 1'b0;
        	qv_rrc_cq_index = wv_cqn;
        	qv_rrc_cq_size = wv_cq_length;       
        end
    end
    else if(RRC_cur_state == RRC_BAD_REQ_s) begin
        if(w_rpb_empty && w_swpb_empty && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_rc_te_loss_prog_full) begin
        	q_rrc_req_valid = !i_rrc_resp_valid;
        	qv_rrc_cq_index = wv_cqn;
        	qv_rrc_cq_size = wv_cq_length;       
        end
        else begin
        	q_rrc_req_valid = 1'b0;
        	qv_rrc_cq_index = wv_cqn;
        	qv_rrc_cq_size = wv_cq_length;       
        end
    end
    else begin
        q_rrc_req_valid = 1'b0;
        qv_rrc_cq_index = wv_cqn;
        qv_rrc_cq_size = wv_cq_length;       
    end
end

////-- q_cq_offset_table_web_TempReg --
////-- qv_cq_offset_table_addrb_TempReg --
////-- qv_cq_offset_table_dinb_TempReg --
// always @(posedge clk or posedge rst) begin
//     if (rst) begin
//         q_cq_offset_table_web <= 'd0;
//         qv_cq_offset_table_addrb <= 'd0;
//         qv_cq_offset_table_dinb <= 'd0; 
//         q_cq_offset_table_web_TempReg <= 'd0;
//         qv_cq_offset_table_addrb_TempReg <= 'd0;
//         qv_cq_offset_table_dinb_TempReg <= 'd0; 
//     end
//     else begin
//         q_cq_offset_table_web <= q_cq_offset_table_web;
//         qv_cq_offset_table_addrb <= qv_cq_offset_table_addrb;
//         qv_cq_offset_table_dinb <= qv_cq_offset_table_dinb; 
//         q_cq_offset_table_web_TempReg <= q_cq_offset_table_web;
//         qv_cq_offset_table_addrb_TempReg <= qv_cq_offset_table_addrb;
//         qv_cq_offset_table_dinb_TempReg <= qv_cq_offset_table_dinb; 
//     end
// end
/******************************************************************* End ***********************************************************/
//-- qv_bc_table_init_counter --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_bc_table_init_counter <= 'd0;        
    end
    else if (RRC_cur_state == RRC_INIT_s && qv_bc_table_init_counter < `QP_NUM - 1) begin
        qv_bc_table_init_counter <= qv_bc_table_init_counter + 1;
    end
    else begin
        qv_bc_table_init_counter <= qv_bc_table_init_counter;
    end
end

always @(*) begin
	if(rst) begin
		q_bc_wea = 'd0;
		qv_bc_addra = 'd0;
		qv_bc_dina = 'd0;
		qv_bc_addrb = 'd0;
	end 
	else if(RRC_cur_state == RRC_INIT_s) begin
		if(qv_bc_table_init_counter <= `QP_NUM - 1) begin
			q_bc_wea = 'd1;
			qv_bc_addra = qv_bc_table_init_counter;
			qv_bc_dina = 'd0;
			qv_bc_addrb = 'd0;
		end 
		else begin
			q_bc_wea = 'd0;
			qv_bc_addra = 'd0;
			qv_bc_dina = 'd0;
			qv_bc_addrb = 'd0;
		end 
	end 
	else if(RRC_cur_state == RRC_RELEASE_s && qv_release_counter == 0) begin	//When meeth the first 256-bit of a packet, accumualte the packet length
		q_bc_wea = 'd1;
		qv_bc_addra = qv_cur_event_QPN;
		qv_bc_dina = wv_bc_doutb + wv_release_curPktLen;
		qv_bc_addrb = qv_cur_event_QPN;
	end 
	else if(RRC_cur_state == RRC_RELEASE_s && w_gen_cpl_during_release && w_cpl_can_be_upload) begin	//When generate a CPL for a WQE, we clear the byte counter
		q_bc_wea = 'd1;
		qv_bc_addra = qv_cur_event_QPN;
		qv_bc_dina = 'd0;
		qv_bc_addrb = qv_cur_event_QPN;
	end 
	else if(RRC_cur_state == RRC_WQE_FLUSH_s && w_gen_cpl_during_flush && w_cpl_can_be_upload) begin
		q_bc_wea = 'd1;
		qv_bc_addra = qv_cur_event_QPN;
		qv_bc_dina = 'd0;
		qv_bc_addrb = qv_cur_event_QPN;
	end 
	else if(RRC_cur_state == RRC_BAD_REQ_s) begin
		q_bc_wea = 'd1;
		qv_bc_addra = qv_cur_event_QPN;
		qv_bc_dina = 'd0;
		qv_bc_addrb = qv_cur_event_QPN;
	end 	
	else if(RRC_cur_state == RRC_SCATTER_CMD_s) begin
		q_bc_wea = 'd1;
		qv_bc_addra = qv_cur_event_QPN;
		qv_bc_dina = wv_bc_doutb + qv_vtp_length;
		qv_bc_addrb = qv_cur_event_QPN;
	end 
	else if(RRC_cur_state == RRC_READ_COMPLETION_s && w_cpl_can_be_upload) begin
		q_bc_wea = 'd1;
		qv_bc_addra = qv_cur_event_QPN;
		qv_bc_dina = 'd0;
		qv_bc_addrb = qv_cur_event_QPN;
	end 
	else begin
		q_bc_wea = 'd0;
		qv_bc_addra = qv_bc_addra_TempReg;
		qv_bc_dina = qv_bc_dina_TempReg;
		qv_bc_addrb = qv_bc_addrb_TempReg;
	end 
end 

reg 		rrc_reg;

always @(posedge clk or posedge rst) begin
	if(rst) begin
		rrc_reg <= 'd0;
	end 
	else begin
		rrc_reg <= rw_data[3 * 32];
	end 
end 


//ila_cpl ila_cpl(
//    .clk(clk),
//    .probe0(o_vtp_cmd_wr_en),
//    .probe1(i_vtp_cmd_prog_full),
//    .probe2(ov_vtp_cmd_data),
//    .probe3(o_vtp_upload_wr_en),
//    .probe4(i_vtp_upload_prog_full),
//    .probe5(ov_vtp_upload_data),
//    .probe6(i_vtp_resp_empty),
//    .probe7(o_vtp_resp_rd_en),
//    .probe8(iv_vtp_resp_data)
//);

//ila_rrc_state ila_rrc_state(
//    .clk(clk),
//    .probe0(RRC_cur_state),
//    .probe1(RRC_next_state),
//    .probe2({1'b0, i_loss_expire_empty, i_rnr_expire_empty, i_br_empty, i_header_from_hp_empty})
//);

//ila_rrc_header ila_rrc_header(
//    .clk(clk),
//    .probe0(i_header_from_hp_empty),
//    .probe1(o_header_from_hp_rd_en),
//    .probe2(iv_header_from_hp_data)
//);


/*----------------------------------- connect dbg bus -------------------------------------*/
wire   [4576 - 1 : 0]   coalesced_bus;

assign coalesced_bus = {
                            q_bc_wea,
                            q_rrc_req_valid,
                            q_sem_cmd_wr_en,
                            q_sem_resp_rd_en,
                            q_sch_flag_1,
                            q_sch_flag_2,
                            q_cur_retrans_is_read,
                            q_cur_retrans_is_read_TempReg,
                            q_cur_flush_is_read,
                            q_cur_release_is_read,
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
                            q_rpb_list_head_web,
                            q_rpb_list_tail_web,
                            q_rpb_list_empty_web,
                            q_rpb_content_web,
                            q_rpb_next_web,
                            q_rpb_free_wr_en,
                            q_swpb_list_head_web,
                            q_swpb_list_tail_web,
                            q_swpb_list_empty_web,
                            q_swpb_content_web,
                            q_swpb_next_web,
                            q_swpb_free_wr_en,
                            q_header_from_hp_rd_en,          
                            q_nd_from_hp_rd_en,
                            q_header_to_rpg_wr_en,
                            q_nd_to_rpg_wr_en,
                            q_cxtmgt_cmd_wr_en,    
                            q_cxtmgt_resp_rd_en,         
                            q_cxtmgt_cxt_rd_en,
                            q_cxtmgt_cxt_wr_en,    
                            q_vtp_cmd_wr_en,         
                            q_vtp_resp_rd_en,
                            q_vtp_upload_wr_en,      
							1'b0,
							1'b0,
                            //q_cq_offset_table_web,
                            //q_cq_offset_table_web_TempReg,
                            qv_rpb_list_empty_dinb,
                            qv_swpb_list_empty_dinb,
                            w_gen_cpl_during_release,
                            w_gen_cpl_during_flush,
                            w_sem_init_finish,
                            w_cur_read_finish,
                            w_sem_cmd_rd_en,
                            w_sem_cmd_empty,
                            w_sem_cmd_prog_full,
                            w_sem_resp_wr_en,
                            w_sem_resp_empty,
                            w_sem_resp_prog_full,
                            w_new_event,
                            w_pending_read,
                            w_entry_valid,
                            w_pkt_drop_finish,
                            w_pending_send_write,
                            w_rpb_empty,
                            w_swpb_empty,
                            w_release_finish,
                            w_cur_release_is_read,
                            w_retrans_finish,
                            w_flush_finish,
                            w_cur_flush_is_read,
                            w_cpl_can_be_upload,
                            w_unfinished_read,
                            qv_bc_addra,
                            qv_bc_addrb,
                            qv_bc_addra_TempReg,
                            qv_bc_addrb_TempReg,
                            qv_rpb_list_head_addrb,
                            qv_rpb_list_tail_addrb,
                            qv_rpb_list_empty_addrb,
                            qv_swpb_list_head_addrb,
                            qv_swpb_list_tail_addrb,
                            qv_swpb_list_empty_addrb,
							14'd0,
							14'd0,
                            //qv_cq_offset_table_addrb,
                            //qv_cq_offset_table_addrb_TempReg,
                            wv_PktQPN,
                            qv_bc_dina,
                            qv_bc_dina_TempReg,
                            qv_rrc_cq_size,
                            qv_rpb_list_table_init_counter,
                            qv_swpb_list_table_init_counter,
                            qv_mandatory_counter,
                            qv_cur_entry_left_length,
                            qv_vtp_pd,
                            qv_vtp_key,
                            qv_vtp_length,
                            qv_my_qpn,
                            qv_my_ee,
                            qv_rqpn,
                            qv_imm_etype_pkey_eec,
                            qv_byte_cnt,
                            qv_wqe,
                            qv_my_qpn_TempReg,
                            qv_my_ee_TempReg,
                            qv_rqpn_TempReg,
                            qv_imm_etype_pkey_eec_TempReg,
                            qv_byte_cnt_TempReg,
                            wv_bc_doutb,
                            wv_bc_doutb_fake,
                            wv_CQ_LKey,
                            wv_QP_PD,
                            wv_CQ_PD,
                            wv_cq_length,
                            wv_entry_key,
                            wv_entry_length,
                            wv_bad_wqe_offset,
                            wv_Read_DMALen,
                            qv_rrc_cq_index,
                            qv_cur_event_QPN,
                            qv_release_curPSN,
                            qv_release_upper_bound,
                            qv_retrans_curPSN,
                            qv_retrans_upper_bound,
                            qv_flush_curPSN,
                            qv_flush_upper_bound,
                            qv_fetch_QPN,
                            wv_ReceivedPSN, 
                            wv_msn,
                            wv_UnAckedPSN,
                            wv_NextPSN,
                            wv_cqn,
                            wv_rqpn,
                            wv_loss_timer_QPN,
                            wv_rnr_timer_QPN,
                            wv_bad_req_QPN,
                            wv_oldest_read_PSN,
                            wv_oldest_send_write_PSN,
                            qv_rpb_content_addrb,
                            qv_rpb_next_addrb,
                            qv_rpb_list_head_dinb,
                            qv_rpb_list_tail_dinb,
                            qv_rpb_next_dinb,
                            qv_rpb_free_data,
                            wv_rpb_head, 
                            wv_rpb_tail,
                            qv_swpb_list_head_dinb,
                            qv_swpb_list_tail_dinb,
                            qv_swpb_content_addrb,
                            qv_swpb_next_addrb,
                            qv_swpb_free_data,
                            wv_swpb_head,
                            wv_swpb_tail,
                            qv_rpb_content_dinb,
                            qv_swpb_content_dinb,
                            qv_nd_to_rpg_data,
                            qv_vtp_cmd_data,   
                            qv_vtp_upload_data,
                            qv_unwritten_data,
                            qv_swpb_next_dinb,
                            qv_pkt_left_length,
                            qv_release_PktLeftLen,
                            qv_retrans_PktLeftLen,
                            qv_flush_PktLeftLen,
                            wv_length,
                            wv_release_curPktLen,
                            wv_retrans_curPktLen,
                            wv_flush_curPktLen,
                            qv_cxtmgt_cmd_data,
                            qv_cxtmgt_cxt_data,
							16'd0,
							16'd0,
                            //qv_cq_offset_table_dinb,
                            //qv_cq_offset_table_dinb_TempReg,
                            qv_rpb_free_init_counter,
                            qv_swpb_free_init_counter,
                            qv_rlid,
                            qv_sl_g_mlpath,
                            qv_rlid_TempReg,
                            qv_sl_g_mlpath_TempReg,
                            wv_PKey,
                            wv_rlid,
                            RRC_cur_state,
                            RRC_next_state,
                            wv_opcode,
                            wv_syndrome_low5,
                            qv_vtp_vaddr,
                            qv_header_to_rpg_data,
                            qv_sem_cmd_din,
                            qv_event_num,
                            qv_qp_state,
                            qv_vtp_type,
                            qv_vtp_opcode,
                            qv_sub_state,
                            qv_mthca_mpt_flag_sw_owns,
                            qv_unwritten_len,
                            qv_release_counter,
                            qv_retrans_counter,
                            qv_flush_counter,
                            qv_owner,
                            qv_is_send,
                            qv_opcode,
                            qv_vendor_err,
                            qv_syndrome,
                            qv_owner_TempReg,
                            qv_is_send_TempReg,
                            qv_opcode_TempReg,
                            wv_sem_cmd_dout,
                            wv_sem_resp_din,
                            wv_sem_resp_dout,
                            wv_pad_count,
                            wv_service_type,
                            wv_syndrome,
                            wv_syndrome_high2,
                            wv_qp_state,
                            wv_loss_timer_event,
                            wv_rnr_timer_event,
                            wv_entry_va,
                            wv_PMTU,
                            w_flush_read
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
                    (dbg_sel == 100) ?   coalesced_bus[32 * 101 - 1 : 32 * 100] : 
                    (dbg_sel == 101) ?   coalesced_bus[32 * 102 - 1 : 32 * 101] : 
                    (dbg_sel == 102) ?   coalesced_bus[32 * 103 - 1 : 32 * 102] : 
                    (dbg_sel == 103) ?   coalesced_bus[32 * 104 - 1 : 32 * 103] : 
                    (dbg_sel == 104) ?   coalesced_bus[32 * 105 - 1 : 32 * 104] : 
                    (dbg_sel == 105) ?   coalesced_bus[32 * 106 - 1 : 32 * 105] : 
                    (dbg_sel == 106) ?   coalesced_bus[32 * 107 - 1 : 32 * 106] : 
                    (dbg_sel == 107) ?   coalesced_bus[32 * 108 - 1 : 32 * 107] : 
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
                    (dbg_sel == 142) ?  coalesced_bus[32 * 143 - 1 : 32 * 142] : wv_sem_dbg_bus;

//assign dbg_bus = {coalesced_bus, wv_sem_dbg_bus};
                    
assign init_rw_data = 'd0;

endmodule
