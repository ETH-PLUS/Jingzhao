`timescale 1ns / 1ps

module ResponderEngine
#(
    parameter   RW_REG_NUM = 13
)
(
    input   wire                clk,
    input   wire                rst,

	input 	wire 	[RW_REG_NUM * 32 - 1 : 0]	rw_data,
	output 	wire 	[RW_REG_NUM * 32 - 1 : 0]	init_rw_data,

//HeaderParser
    input   wire                i_header_empty,
    input   wire    [319:0]     iv_header_data,
    output  wire                o_header_rd_en,

    input   wire                i_nd_empty,
    input   wire    [255:0]     iv_nd_data,
    output  wire                o_nd_rd_en,

//VirtToPhys
    //Channel 1
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

    //Channel 2
    output  wire                o_rwm_vtp_cmd_wr_en,
    input   wire                i_rwm_vtp_cmd_prog_full,
    output  wire    [255:0]     ov_rwm_vtp_cmd_data,

    input   wire                i_rwm_vtp_resp_empty,
    output  wire                o_rwm_vtp_resp_rd_en,
    input   wire    [7:0]       iv_rwm_vtp_resp_data,

    output  wire                o_rwm_vtp_download_rd_en,
    input   wire                i_rwm_vtp_download_empty,
    input   wire    [127:0]     iv_rwm_vtp_download_data,

//CxtMgt
    //Channel 1 for ExecutionEngine
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

//RespPktGen
    input   wire                i_trans_prog_full,
    output  wire                o_trans_wr_en,
    output  wire    [255:0]     ov_trans_data,
	input 	wire 	[12:0]		iv_data_count,

//CQM
    output   wire                o_ee_req_valid,
    output   wire    [23:0]      ov_ee_cq_index,
    output   wire    [31:0]       ov_ee_cq_size,
    input  wire                i_ee_resp_valid,
    input  wire     [23:0]     iv_ee_cq_offset,

    input   wire    [31:0]      dbg_sel,
    output  wire    [32 - 1:0]      dbg_bus,
    //output  wire    [`DBG_NUM_RESPONDER_ENGINE * 32 - 1:0]      dbg_bus,

	output 	wire 				o_resp_engine_init_finish
);

//wire        [31:0]      wv_rwm_dbg_sel;
//wire        [`DBG_NUM_RECV_WQE_MANAGER * 32 - 1:0]      wv_rwm_dbg_bus;
//wire        [31:0]      wv_ee_dbg_sel;
//wire        [`DBG_NUM_EXECUTION_ENGINE * 32 - 1:0]      wv_ee_dbg_bus;
//wire        [31:0]      wv_rpg_dbg_sel;
//wire        [`DBG_NUM_RESP_PKT_GEN * 32 - 1:0]      wv_rpg_dbg_bus;
wire        [31:0]      wv_rwm_dbg_sel;
wire        [32 - 1:0]      wv_rwm_dbg_bus;
wire        [31:0]      wv_ee_dbg_sel;
wire        [32 - 1:0]      wv_ee_dbg_bus;
wire        [31:0]      wv_rpg_dbg_sel;
wire        [32 - 1:0]      wv_rpg_dbg_bus;


assign wv_rwm_dbg_sel = dbg_sel - `DBG_NUM_ZERO;
assign wv_ee_dbg_sel = dbg_sel - (`DBG_NUM_REQUESTER_TRANS_CONTROL);
assign wv_rpg_dbg_sel = dbg_sel - (`DBG_NUM_REQUESTER_TRANS_CONTROL + `DBG_NUM_REQUESTER_RECV_CONTROL);

assign dbg_bus =    (dbg_sel >= `DBG_NUM_ZERO && dbg_sel <= `DBG_NUM_RECV_WQE_MANAGER - 1) ? wv_rwm_dbg_bus :
                    (dbg_sel >= `DBG_NUM_RECV_WQE_MANAGER && dbg_sel <=`DBG_NUM_RECV_WQE_MANAGER + `DBG_NUM_EXECUTION_ENGINE - 1) ? wv_ee_dbg_bus :
                    (dbg_sel >= `DBG_NUM_RECV_WQE_MANAGER + `DBG_NUM_EXECUTION_ENGINE && dbg_sel <= `DBG_NUM_RECV_WQE_MANAGER + `DBG_NUM_EXECUTION_ENGINE + `DBG_NUM_RESP_PKT_GEN - 1) ? wv_rpg_dbg_bus : 32'd0;

//assign dbg_bus = {wv_rwm_dbg_bus, wv_ee_dbg_bus, wv_rpg_dbg_bus};

wire                    w_wat_wr_en;
wire    [127:0]         wv_wat_wr_data;
wire    [13:0]          wv_wat_addra;
wire    [13:0]          wv_wat_addrb;
wire    [127:0]         wv_wat_rd_data;

wire    [191:0]         wv_ee_to_rpg_din;
wire                    w_ee_to_rpg_wr_en;
wire                    w_ee_to_rpg_rd_en;
wire    [191:0]         wv_ee_to_rpg_dout;
wire                    w_ee_to_rpg_empty;
wire                    w_ee_to_rpg_prog_full;
SyncFIFO_192w_32d EE_TO_RPG_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[0 * 32 + 1 : 0 * 32 + 0]),
	.WTSEL( rw_data[0 * 32 + 3 : 0 * 32 + 2]),
	.PTSEL( rw_data[0 * 32 + 5 : 0 * 32 + 4]),
	.VG(    rw_data[0 * 32 + 6 : 0 * 32 + 6]),
	.VS(    rw_data[0 * 32 + 7 : 0 * 32 + 7]),
 
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_ee_to_rpg_din),                
  .wr_en(w_ee_to_rpg_wr_en),            
  .rd_en(w_ee_to_rpg_rd_en),            
  .dout(wv_ee_to_rpg_dout),              
  .full(),              
  .empty(w_ee_to_rpg_empty),            
  .prog_full(w_ee_to_rpg_prog_full)    
);

wire    [255:0]         wv_ee_to_rwm_cmd_din;
wire                    w_ee_to_rwm_cmd_wr_en;
wire                    w_ee_to_rwm_cmd_rd_en;
wire    [255:0]         wv_ee_to_rwm_cmd_dout;
wire                    w_ee_to_rwm_cmd_empty;
wire                    w_ee_to_rwm_cmd_prog_full;
CmdResp_FIFO_256w_4d EE_TO_RWM_CMD_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[1 * 32 + 1 : 1 * 32 + 0]),
	.WTSEL( rw_data[1 * 32 + 3 : 1 * 32 + 2]),
	.PTSEL( rw_data[1 * 32 + 5 : 1 * 32 + 4]),
	.VG(    rw_data[1 * 32 + 6 : 1 * 32 + 6]),
	.VS(    rw_data[1 * 32 + 7 : 1 * 32 + 7]),
 
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_ee_to_rwm_cmd_din),                
  .wr_en(w_ee_to_rwm_cmd_wr_en),            
  .rd_en(w_ee_to_rwm_cmd_rd_en),            
  .dout(wv_ee_to_rwm_cmd_dout),              
  .full(),              
  .empty(w_ee_to_rwm_cmd_empty),            
  .prog_full(w_ee_to_rwm_cmd_prog_full)    
);

wire    [191:0]         wv_rwm_to_ee_resp_din;
wire                    w_rwm_to_ee_resp_wr_en;
wire                    w_rwm_to_ee_resp_rd_en;
wire    [191:0]         wv_rwm_to_ee_resp_dout;
wire                    w_rwm_to_ee_resp_empty;
wire                    w_rwm_to_ee_resp_prog_full;
CmdResp_FIFO_192w_4d RWM_TO_EE_RESP_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[2 * 32 + 1 : 2 * 32 + 0]),
	.WTSEL( rw_data[2 * 32 + 3 : 2 * 32 + 2]),
	.PTSEL( rw_data[2 * 32 + 5 : 2 * 32 + 4]),
	.VG(    rw_data[2 * 32 + 6 : 2 * 32 + 6]),
	.VS(    rw_data[2 * 32 + 7 : 2 * 32 + 7]),
 
  `endif

  .clk(clk),                
  .srst(rst),              
  .din(wv_rwm_to_ee_resp_din),                
  .wr_en(w_rwm_to_ee_resp_wr_en),            
  .rd_en(w_rwm_to_ee_resp_rd_en),            
  .dout(wv_rwm_to_ee_resp_dout),              
  .full(),              
  .empty(w_rwm_to_ee_resp_empty),            
  .prog_full(w_rwm_to_ee_resp_prog_full)    
);

wire 	w_ee_init_finish;
ExecutionEngine ExecutionEngine_Inst(
    .rw_data(rw_data[(3 + 3) * 32 - 1 : 3 * 32]),
    .init_rw_data(),

    .clk(clk),
    .rst(rst),

//Interface with RecvWQEManager
    .o_rwm_cmd_wr_en(w_ee_to_rwm_cmd_wr_en),
    .ov_rwm_cmd_data(wv_ee_to_rwm_cmd_din),
    .i_rwm_cmd_prog_full(w_ee_to_rwm_cmd_prog_full),

    .i_rwm_resp_empty(w_rwm_to_ee_resp_empty),
    .iv_rwm_resp_data(wv_rwm_to_ee_resp_dout),
    .o_rwm_resp_rd_en(w_rwm_to_ee_resp_rd_en),

//Write Address Table
    .o_wat_wr_en(w_wat_wr_en),
    .ov_wat_wr_data(wv_wat_wr_data),
    .ov_wat_addra(wv_wat_addra),
    .ov_wat_addrb(wv_wat_addrb),
    .iv_wat_rd_data(wv_wat_rd_data),

//Resp Packet Gen
    .o_rpg_md_wr_en(w_ee_to_rpg_wr_en),
    .ov_rpg_md_data(wv_ee_to_rpg_din),
    .i_rpg_md_prog_full(w_ee_to_rpg_prog_full),

//HeaderParser
    .i_header_empty(i_header_empty),
    .iv_header_data(iv_header_data),
    .o_header_rd_en(o_header_rd_en),

    .i_nd_empty(i_nd_empty),
    .iv_nd_data(iv_nd_data),
    .o_nd_rd_en(o_nd_rd_en),

//VirtToPhys
    .o_vtp_cmd_wr_en(o_ee_vtp_cmd_wr_en),
    .i_vtp_cmd_prog_full(i_ee_vtp_cmd_prog_full),
    .ov_vtp_cmd_data(ov_ee_vtp_cmd_data),

    .i_vtp_resp_empty(i_ee_vtp_resp_empty),
    .o_vtp_resp_rd_en(o_ee_vtp_resp_rd_en),
    .iv_vtp_resp_data(iv_ee_vtp_resp_data),

    .o_vtp_upload_wr_en(o_ee_vtp_upload_wr_en),
    .i_vtp_upload_prog_full(i_ee_vtp_upload_prog_full),
    .ov_vtp_upload_data(ov_ee_vtp_upload_data),

//CxtMgt
    .o_cxtmgt_cmd_wr_en(o_ee_cxtmgt_cmd_wr_en),
    .i_cxtmgt_cmd_prog_full(i_ee_cxtmgt_cmd_prog_full),
    .ov_cxtmgt_cmd_data(ov_ee_cxtmgt_cmd_data),

    .i_cxtmgt_resp_empty(i_ee_cxtmgt_resp_empty),
    .o_cxtmgt_resp_rd_en(o_ee_cxtmgt_resp_rd_en),
    .iv_cxtmgt_resp_data(iv_ee_cxtmgt_resp_data),

    .i_cxtmgt_cxt_empty(i_ee_cxtmgt_cxt_empty),
    .o_cxtmgt_cxt_rd_en(o_ee_cxtmgt_cxt_rd_en),
    .iv_cxtmgt_cxt_data(iv_ee_cxtmgt_cxt_data),

    .o_cxtmgt_cxt_wr_en(o_ee_cxtmgt_cxt_wr_en),
    .i_cxtmgt_cxt_prog_full(i_ee_cxtmgt_cxt_prog_full),
    .ov_cxtmgt_cxt_data(ov_ee_cxtmgt_cxt_data),

    .o_ee_req_valid(o_ee_req_valid),
    .ov_ee_cq_index(ov_ee_cq_index),
    .ov_ee_cq_size(ov_ee_cq_size),
    .i_ee_resp_valid(i_ee_resp_valid),
    .iv_ee_cq_offset(iv_ee_cq_offset),

	.o_ee_init_finish(w_ee_init_finish),

    .dbg_sel(wv_ee_dbg_sel),
    .dbg_bus(wv_ee_dbg_bus)
);

wire 	w_rwm_init_finish;
RecvWQEManager RecvWQEManeger_Inst(
    .rw_data(rw_data[(6 + 5) * 32 - 1 : 6 * 32]),
    .init_rw_data(),

    .clk(clk),
    .rst(rst),

    .i_ee_cmd_empty(w_ee_to_rwm_cmd_empty),
    .iv_ee_cmd_data(wv_ee_to_rwm_cmd_dout),
    .o_ee_cmd_rd_en(w_ee_to_rwm_cmd_rd_en),

    .i_ee_resp_prog_full(w_rwm_to_ee_resp_prog_full),
    .o_ee_resp_wr_en(w_rwm_to_ee_resp_wr_en),
    .ov_ee_resp_data(wv_rwm_to_ee_resp_din),

    .o_vtp_cmd_wr_en(o_rwm_vtp_cmd_wr_en),
    .i_vtp_cmd_prog_full(i_rwm_vtp_cmd_prog_full),
    .ov_vtp_cmd_data(ov_rwm_vtp_cmd_data),

    .i_vtp_resp_empty(i_rwm_vtp_resp_empty),
    .o_vtp_resp_rd_en(o_rwm_vtp_resp_rd_en),
    .iv_vtp_resp_data(iv_rwm_vtp_resp_data),

    .i_vtp_download_empty(i_rwm_vtp_download_empty),
    .o_vtp_download_rd_en(o_rwm_vtp_download_rd_en),
    .iv_vtp_download_data(iv_rwm_vtp_download_data),

	.o_rwm_init_finish(w_rwm_init_finish),

    .dbg_sel(wv_rwm_dbg_sel),
    .dbg_bus(wv_rwm_dbg_bus)
);

WriteAddrTable WriteAddrTable_Inst(
    .rw_data(rw_data[(11 + 1) * 32 - 1 : 11 * 32]),
    .init_rw_data(),

    .clk(clk),
    .rst(rst),
    .i_wat_wr_en(w_wat_wr_en),
    .iv_wat_wr_data(wv_wat_wr_data),
    .iv_wat_addra(wv_wat_addra),
    .iv_wat_addrb(wv_wat_addrb),
    .ov_wat_rd_data(wv_wat_rd_data)
);

reg 		wat_reg;
always @(posedge clk or posedge rst) begin
	if(rst) begin
		wat_reg <= 'd0;
	end 
	else begin
		wat_reg <= rw_data[12 * 32];
	end 
end 

RespPktGen RespPktGen_Inst(
    .clk(clk),
    .rst(rst),

    .i_md_empty(w_ee_to_rpg_empty),
    .iv_md_data(wv_ee_to_rpg_dout),
    .o_md_rd_en(w_ee_to_rpg_rd_en),

//Obtain RDMA Read data from memory
    .i_nd_empty(i_ee_vtp_download_empty),
    .iv_nd_data(iv_ee_vtp_download_data),
    .o_nd_rd_en(o_ee_vtp_download_rd_en),

    .i_trans_prog_full(i_trans_prog_full),
    .o_trans_wr_en(o_trans_wr_en),
    .ov_trans_data(ov_trans_data),

    .dbg_sel(wv_rpg_dbg_sel),
    .dbg_bus(wv_rpg_dbg_bus)

);

assign o_resp_engine_init_finish = w_rwm_init_finish && w_ee_init_finish;

endmodule
