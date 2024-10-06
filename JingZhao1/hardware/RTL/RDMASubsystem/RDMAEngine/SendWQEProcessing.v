`timescale 1ns / 1ps

`include "nic_hw_params.vh"
`include "chip_include_rdma.vh"

module SendWQEProcessing
#(
    parameter   RW_REG_NUM  = 11
)
( //"SWP" for short
    input   wire                clk,
    input   wire                rst,

	input 	wire 	[RW_REG_NUM * 32 - 1 : 0]	rw_data,
	output 	wire 	[RW_REG_NUM * 32 - 1 : 0]	init_rw_data,

//Interface with PIO
    input   wire                i_pio_empty,
    output  wire                o_pio_rd_en,
    input   wire    [63:0]      iv_pio_data,

//Interface with CxtMgt
    //Channel 1
    output  wire                o_db_cxtmgt_cmd_wr_en,
    input   wire                i_db_cxtmgt_cmd_prog_full,
    output  wire    [127:0]     ov_db_cxtmgt_cmd_data,

    input   wire                i_db_cxtmgt_resp_empty,
    output  wire                o_db_cxtmgt_resp_rd_en,
    input   wire    [127:0]     iv_db_cxtmgt_resp_data,

    input   wire                i_db_cxtmgt_cxt_empty,
    output  wire                o_db_cxtmgt_cxt_rd_en,
    input   wire    [255:0]     iv_db_cxtmgt_cxt_data,

    //Channel 2
    output  wire                o_wp_cxtmgt_cmd_wr_en,
    input   wire                i_wp_cxtmgt_cmd_prog_full,
    output  wire    [127:0]     ov_wp_cxtmgt_cmd_data,

    input   wire                i_wp_cxtmgt_resp_empty,
    output  wire                o_wp_cxtmgt_resp_rd_en,
    input   wire    [127:0]     iv_wp_cxtmgt_resp_data,

    input   wire                i_wp_cxtmgt_cxt_empty,
    output  wire                o_wp_cxtmgt_cxt_rd_en,
    input   wire    [127:0]     iv_wp_cxtmgt_cxt_data,

//Interface with VirtToPhys
    //Channel 1
    output  wire                o_db_vtp_cmd_wr_en,
    input   wire                i_db_vtp_cmd_prog_full,
    output  wire    [255:0]     ov_db_vtp_cmd_data,

    input   wire                i_db_vtp_resp_empty,
    output  wire                o_db_vtp_resp_rd_en,
    input   wire    [7:0]       iv_db_vtp_resp_data,

    input   wire                i_db_vtp_wqe_empty,
    output  wire                o_db_vtp_wqe_rd_en,
    input   wire    [127:0]     iv_db_vtp_wqe_data,
        
    //Channel 2
    output  wire                o_wp_vtp_wqe_cmd_wr_en,
    input   wire                i_wp_vtp_wqe_cmd_prog_full,
    output  wire    [255:0]     ov_wp_vtp_wqe_cmd_data,

    input   wire                i_wp_vtp_wqe_resp_empty,
    output  wire                o_wp_vtp_wqe_resp_rd_en,
    input   wire    [7:0]       iv_wp_vtp_wqe_resp_data,

    input   wire                i_wp_vtp_wqe_empty,
    output  wire                o_wp_vtp_wqe_rd_en,
    input   wire    [127:0]     iv_wp_vtp_wqe_data,

    //Channel 3
    output  wire                o_wp_vtp_nd_cmd_wr_en,
    input   wire                i_wp_vtp_nd_cmd_prog_full,
    output  wire    [255:0]     ov_wp_vtp_nd_cmd_data,

    input   wire                i_wp_vtp_nd_resp_empty,
    output  wire                o_wp_vtp_nd_resp_rd_en,
    input   wire    [7:0]       iv_wp_vtp_nd_resp_data,

    input   wire                i_wp_vtp_nd_empty,
    output  wire                o_wp_vtp_nd_rd_en,
    input   wire    [255:0]     iv_wp_vtp_nd_data,

//Interface with Requester Engine
    input   wire                i_entry_to_re_prog_full,
    output  wire                o_entry_to_re_wr_en,
    output  wire    [127:0]     ov_entry_to_re_data,

    input   wire                i_atomics_to_re_prog_full,
    output  wire                o_atomics_to_re_wr_en,
    output  wire    [127:0]     ov_atomics_to_re_data,

    input   wire                i_raddr_to_re_prog_full,
    output  wire                o_raddr_to_re_wr_en,
    output  wire    [127:0]     ov_raddr_to_re_data,

    input   wire                i_nd_to_re_prog_full,
    output  wire                o_nd_to_re_wr_en,
    output  wire    [255:0]     ov_nd_to_re_data,

    input   wire                i_md_to_re_prog_full,
    output  wire                o_md_to_re_wr_en,
    //output  wire    [287:0]     ov_md_to_re_data
    output  wire    [367:0]     ov_md_to_re_data,

    output  wire                o_swp_init_finish,

    input   wire    [31:0]      dbg_sel,
    output  wire    [32 -1:0]      dbg_bus
    //output  wire    [`DBG_NUM_SEND_WQE_PROCESSING * 32 -1:0]      dbg_bus
);

//wire        [`DBG_NUM_DOORBELL_PROCESSING * 32 - 1:0]      wv_dbp_dbg_bus;
//wire        [31:0]      wv_dbp_dbg_sel;
//wire        [`DBG_NUM_WQE_SCHEDULER * 32 - 1:0]      wv_ws_dbg_bus;
//wire        [31:0]      wv_ws_dbg_sel;
//wire        [`DBG_NUM_WQE_PARSER * 32 - 1:0]      wv_wp_dbg_bus;
//wire        [31:0]      wv_wp_dbg_sel;
//wire        [`DBG_NUM_DATA_PACK * 32 - 1:0]      wv_dp_dbg_bus;
//wire        [31:0]      wv_dp_dbg_sel;
wire        [32 - 1:0]      wv_dbp_dbg_bus;
wire        [31:0]      wv_dbp_dbg_sel;
wire        [32 - 1:0]      wv_ws_dbg_bus;
wire        [31:0]      wv_ws_dbg_sel;
wire        [32 - 1:0]      wv_wp_dbg_bus;
wire        [31:0]      wv_wp_dbg_sel;
wire        [32 - 1:0]      wv_dp_dbg_bus;
wire        [31:0]      wv_dp_dbg_sel;

assign wv_dbp_dbg_sel = dbg_sel - `DBG_NUM_ZERO;
assign wv_ws_dbg_sel = dbg_sel - `DBG_NUM_DOORBELL_PROCESSING;
assign wv_wp_dbg_sel = dbg_sel - (`DBG_NUM_DOORBELL_PROCESSING + `DBG_NUM_WQE_SCHEDULER);
assign wv_dp_dbg_sel = dbg_sel - (`DBG_NUM_DOORBELL_PROCESSING + `DBG_NUM_WQE_SCHEDULER + `DBG_NUM_WQE_PARSER);

assign dbg_bus =    (dbg_sel >= `DBG_NUM_ZERO && dbg_sel <= `DBG_NUM_DOORBELL_PROCESSING - 1) ? wv_dbp_dbg_bus :
                    (dbg_sel >= `DBG_NUM_DOORBELL_PROCESSING && dbg_sel <= `DBG_NUM_DOORBELL_PROCESSING + `DBG_NUM_WQE_SCHEDULER - 1) ? wv_ws_dbg_bus :
                    (dbg_sel >= `DBG_NUM_DOORBELL_PROCESSING + `DBG_NUM_WQE_SCHEDULER && dbg_sel <= `DBG_NUM_DOORBELL_PROCESSING + `DBG_NUM_WQE_SCHEDULER + `DBG_NUM_WQE_PARSER - 1) ? wv_wp_dbg_bus :
                    (dbg_sel >= `DBG_NUM_DOORBELL_PROCESSING + `DBG_NUM_WQE_SCHEDULER + `DBG_NUM_WQE_PARSER && dbg_sel <= `DBG_NUM_DOORBELL_PROCESSING + `DBG_NUM_WQE_SCHEDULER + `DBG_NUM_WQE_PARSER + `DBG_NUM_DATA_PACK - 1) ? wv_dp_dbg_bus : 32'd0;

//assign dbg_bus = {wv_dbp_dbg_bus, wv_ws_dbg_bus, wv_wp_dbg_bus, wv_dp_dbg_bus};

wire                    w_wit_wr_en;
wire        [13:0]      wv_wit_wr_addr;
wire        [0:0]       wv_wit_wr_data;
wire        [13:0]      wv_wit_rd_addr;
wire        [0:0]       wv_wit_rd_data;       
WQEIndicatorTable WQEIndicatorTable_Inst(
    .rw_data(rw_data[(0 + 1) * 32 - 1 : 0 * 32]),
    .init_rw_data(),

    .clk(clk),
    .rst(rst),
    .wr_en(w_wit_wr_en),
    .wr_addr(wv_wit_wr_addr),
    .wr_data(wv_wit_wr_data),
    .rd_addr(wv_wit_rd_addr),
    .rd_data(wv_wit_rd_data)
);

wire        [255:0]     wv_md_from_dbp_to_ws_din;
wire                    w_md_from_dbp_to_ws_wr_en;
wire                    w_md_from_dbp_to_ws_rd_en;
wire        [255:0]     wv_md_from_dbp_to_ws_dout;
wire                    w_md_from_dbp_to_ws_empty;
wire                    w_md_from_dbp_to_ws_prog_full;
SyncFIFO_256w_32d MD_FROM_DBP_TO_WS_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[1 * 32 + 1 : 1 * 32 + 0]),
	.WTSEL( rw_data[1 * 32 + 3 : 1 * 32 + 2]),
	.PTSEL( rw_data[1 * 32 + 5 : 1 * 32 + 4]),
	.VG(    rw_data[1 * 32 + 6 : 1 * 32 + 6]),
	.VS(    rw_data[1 * 32 + 7 : 1 * 32 + 7]),

  `endif

  .clk(clk),              
  .srst(rst),          
  .din(wv_md_from_dbp_to_ws_din),              
  .wr_en(w_md_from_dbp_to_ws_wr_en),          
  .rd_en(w_md_from_dbp_to_ws_rd_en),          
  .dout(wv_md_from_dbp_to_ws_dout),            
  .full(),            
  .empty(w_md_from_dbp_to_ws_empty),          
  .prog_full(w_md_from_dbp_to_ws_prog_full)  
);

wire        [255:0]     wv_md_from_ws_to_wp_din;
wire                    w_md_from_ws_to_wp_wr_en;
wire                    w_md_from_ws_to_wp_rd_en;
wire        [255:0]     wv_md_from_ws_to_wp_dout;
wire                    w_md_from_ws_to_wp_empty;
wire                    w_md_from_ws_to_wp_prog_full;
SyncFIFO_256w_32d MD_FROM_WS_TO_WP_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[2 * 32 + 1 : 2 * 32 + 0]),
	.WTSEL( rw_data[2 * 32 + 3 : 2 * 32 + 2]),
	.PTSEL( rw_data[2 * 32 + 5 : 2 * 32 + 4]),
	.VG(    rw_data[2 * 32 + 6 : 2 * 32 + 6]),
	.VS(    rw_data[2 * 32 + 7 : 2 * 32 + 7]),

  `endif

  .clk(clk),              
  .srst(rst),          
  .din(wv_md_from_ws_to_wp_din),              
  .wr_en(w_md_from_ws_to_wp_wr_en),          
  .rd_en(w_md_from_ws_to_wp_rd_en),          
  .dout(wv_md_from_ws_to_wp_dout),            
  .full(),            
  .empty(w_md_from_ws_to_wp_empty),          
  .prog_full(w_md_from_ws_to_wp_prog_full)      
);

wire        [255:0]     wv_md_from_wp_to_ws_din;
wire                    w_md_from_wp_to_ws_wr_en;
wire                    w_md_from_wp_to_ws_rd_en;
wire        [255:0]     wv_md_from_wp_to_ws_dout;
wire                    w_md_from_wp_to_ws_empty;
wire                    w_md_from_wp_to_ws_prog_full;
SyncFIFO_256w_32d MD_FROM_WP_TO_WS_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[3 * 32 + 1 : 3 * 32 + 0]),
	.WTSEL( rw_data[3 * 32 + 3 : 3 * 32 + 2]),
	.PTSEL( rw_data[3 * 32 + 5 : 3 * 32 + 4]),
	.VG(    rw_data[3 * 32 + 6 : 3 * 32 + 6]),
	.VS(    rw_data[3 * 32 + 7 : 3 * 32 + 7]),

  `endif

  .clk(clk),              
  .srst(rst),          
  .din(wv_md_from_wp_to_ws_din),              
  .wr_en(w_md_from_wp_to_ws_wr_en),          
  .rd_en(w_md_from_wp_to_ws_rd_en),          
  .dout(wv_md_from_wp_to_ws_dout),            
  .full(),            
  .empty(w_md_from_wp_to_ws_empty),          
  .prog_full(w_md_from_wp_to_ws_prog_full)   
);

wire        [127:0]     wv_wqe_from_ws_to_wp_din;
wire                    w_wqe_from_ws_to_wp_wr_en;
wire                    w_wqe_from_ws_to_wp_rd_en;
wire        [127:0]     wv_wqe_from_ws_to_wp_dout;
wire                    w_wqe_from_ws_to_wp_empty;
wire                    w_wqe_from_ws_to_wp_prog_full;
//SyncFIFO_256w_32d WQE_FROM_WS_TO_WP_FIFO(
SyncFIFO_128w_64d WQE_FROM_WS_TO_WP_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[4 * 32 + 1 : 4 * 32 + 0]),
	.WTSEL( rw_data[4 * 32 + 3 : 4 * 32 + 2]),
	.PTSEL( rw_data[4 * 32 + 5 : 4 * 32 + 4]),
	.VG(    rw_data[4 * 32 + 6 : 4 * 32 + 6]),
	.VS(    rw_data[4 * 32 + 7 : 4 * 32 + 7]),

  `endif

  .clk(clk),              
  .srst(rst),          
  .din(wv_wqe_from_ws_to_wp_din),              
  .wr_en(w_wqe_from_ws_to_wp_wr_en),          
  .rd_en(w_wqe_from_ws_to_wp_rd_en),          
  .dout(wv_wqe_from_ws_to_wp_dout),            
  .full(),            
  .empty(w_wqe_from_ws_to_wp_empty),          
  .prog_full(w_wqe_from_ws_to_wp_prog_full)   
);

wire        [367:0]     wv_md_from_wp_to_dp_din;
wire                    w_md_from_wp_to_dp_wr_en;
wire                    w_md_from_wp_to_dp_rd_en;
wire        [367:0]     wv_md_from_wp_to_dp_dout;
wire                    w_md_from_wp_to_dp_empty;
wire                    w_md_from_wp_to_dp_prog_full;
SyncFIFO_368w_32d MD_FROM_WP_TO_DP_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[5 * 32 + 1 : 5 * 32 + 0]),
	.WTSEL( rw_data[5 * 32 + 3 : 5 * 32 + 2]),
	.PTSEL( rw_data[5 * 32 + 5 : 5 * 32 + 4]),
	.VG(    rw_data[5 * 32 + 6 : 5 * 32 + 6]),
	.VS(    rw_data[5 * 32 + 7 : 5 * 32 + 7]),

  `endif

  .clk(clk),              
  .srst(rst),          
  .din(wv_md_from_wp_to_dp_din),              
  .wr_en(w_md_from_wp_to_dp_wr_en),          
  .rd_en(w_md_from_wp_to_dp_rd_en),          
  .dout(wv_md_from_wp_to_dp_dout),            
  .full(),            
  .empty(w_md_from_wp_to_dp_empty),          
  .prog_full(w_md_from_wp_to_dp_prog_full)   
);

wire        [127:0]     wv_inline_from_wp_to_dp_din;
wire                    w_inline_from_wp_to_dp_wr_en;
wire                    w_inline_from_wp_to_dp_rd_en;
wire        [127:0]     wv_inline_from_wp_to_dp_dout;
wire                    w_inline_from_wp_to_dp_empty;
wire                    w_inline_from_wp_to_dp_prog_full;
SyncFIFO_128w_32d INLINE_FROM_WP_TO_DP_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[6 * 32 + 1 : 6 * 32 + 0]),
	.WTSEL( rw_data[6 * 32 + 3 : 6 * 32 + 2]),
	.PTSEL( rw_data[6 * 32 + 5 : 6 * 32 + 4]),
	.VG(    rw_data[6 * 32 + 6 : 6 * 32 + 6]),
	.VS(    rw_data[6 * 32 + 7 : 6 * 32 + 7]),

  `endif

  .clk(clk),              
  .srst(rst),          
  .din(wv_inline_from_wp_to_dp_din),              
  .wr_en(w_inline_from_wp_to_dp_wr_en),          
  .rd_en(w_inline_from_wp_to_dp_rd_en),          
  .dout(wv_inline_from_wp_to_dp_dout),            
  .full(),            
  .empty(w_inline_from_wp_to_dp_empty),          
  .prog_full(w_inline_from_wp_to_dp_prog_full)   
);

wire        [127:0]     wv_entry_from_wp_to_dp_din;
wire                    w_entry_from_wp_to_dp_wr_en;
wire                    w_entry_from_wp_to_dp_rd_en;
wire        [127:0]     wv_entry_from_wp_to_dp_dout;
wire                    w_entry_from_wp_to_dp_empty;
wire                    w_entry_from_wp_to_dp_prog_full;
SyncFIFO_128w_32d ENTRY_FROM_WP_TO_DP_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[7 * 32 + 1 : 7 * 32 + 0]),
	.WTSEL( rw_data[7 * 32 + 3 : 7 * 32 + 2]),
	.PTSEL( rw_data[7 * 32 + 5 : 7 * 32 + 4]),
	.VG(    rw_data[7 * 32 + 6 : 7 * 32 + 6]),
	.VS(    rw_data[7 * 32 + 7 : 7 * 32 + 7]),

  `endif

  .clk(clk),              
  .srst(rst),          
  .din(wv_entry_from_wp_to_dp_din),              
  .wr_en(w_entry_from_wp_to_dp_wr_en),          
  .rd_en(w_entry_from_wp_to_dp_rd_en),          
  .dout(wv_entry_from_wp_to_dp_dout),            
  .full(),            
  .empty(w_entry_from_wp_to_dp_empty),          
  .prog_full(w_entry_from_wp_to_dp_prog_full)   
);

wire        [127:0]     wv_atomics_from_wp_to_dp_din;
wire                    w_atomics_from_wp_to_dp_wr_en;
wire                    w_atomics_from_wp_to_dp_rd_en;
wire        [127:0]     wv_atomics_from_wp_to_dp_dout;
wire                    w_atomics_from_wp_to_dp_empty;
wire                    w_atomics_from_wp_to_dp_prog_full;
SyncFIFO_128w_32d ATOMICS_FROM_WP_TO_DP_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[8 * 32 + 1 : 8 * 32 + 0]),
	.WTSEL( rw_data[8 * 32 + 3 : 8 * 32 + 2]),
	.PTSEL( rw_data[8 * 32 + 5 : 8 * 32 + 4]),
	.VG(    rw_data[8 * 32 + 6 : 8 * 32 + 6]),
	.VS(    rw_data[8 * 32 + 7 : 8 * 32 + 7]),

  `endif

  .clk(clk),              
  .srst(rst),          
  .din(wv_atomics_from_wp_to_dp_din),              
  .wr_en(w_atomics_from_wp_to_dp_wr_en),          
  .rd_en(w_atomics_from_wp_to_dp_rd_en),          
  .dout(wv_atomics_from_wp_to_dp_dout),            
  .full(),            
  .empty(w_atomics_from_wp_to_dp_empty),          
  .prog_full(w_atomics_from_wp_to_dp_prog_full)   
);

wire        [127:0]     wv_raddr_from_wp_to_dp_din;
wire                    w_raddr_from_wp_to_dp_wr_en;
wire                    w_raddr_from_wp_to_dp_rd_en;
wire        [127:0]     wv_raddr_from_wp_to_dp_dout;
wire                    w_raddr_from_wp_to_dp_empty;
wire                    w_raddr_from_wp_to_dp_prog_full;
SyncFIFO_128w_32d RADDR_FROM_WP_TO_DP_FIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[9 * 32 + 1 : 9 * 32 + 0]),
	.WTSEL( rw_data[9 * 32 + 3 : 9 * 32 + 2]),
	.PTSEL( rw_data[9 * 32 + 5 : 9 * 32 + 4]),
	.VG(    rw_data[9 * 32 + 6 : 9 * 32 + 6]),
	.VS(    rw_data[9 * 32 + 7 : 9 * 32 + 7]),

  `endif

  .clk(clk),              
  .srst(rst),          
  .din(wv_raddr_from_wp_to_dp_din),              
  .wr_en(w_raddr_from_wp_to_dp_wr_en),          
  .rd_en(w_raddr_from_wp_to_dp_rd_en),          
  .dout(wv_raddr_from_wp_to_dp_dout),            
  .full(),            
  .empty(w_raddr_from_wp_to_dp_empty),          
  .prog_full(w_raddr_from_wp_to_dp_prog_full)   
);

DoorbellProcessing DoorbellProcessing_Inst(
    .rw_data(rw_data[(10 + 1) * 32 - 1 : 10 * 32]),
    .init_rw_data(),

    .clk(clk),
    .rst(rst),

//Interface with PIO
    .i_pio_empty(i_pio_empty),
    .o_pio_rd_en(o_pio_rd_en),
    .iv_pio_data(iv_pio_data),

//CxtMgt
    .o_cxtmgt_cmd_wr_en(o_db_cxtmgt_cmd_wr_en),
    .i_cxtmgt_cmd_prog_full(i_db_cxtmgt_cmd_prog_full),
    .ov_cxtmgt_cmd_data(ov_db_cxtmgt_cmd_data),

    .i_cxtmgt_resp_empty(i_db_cxtmgt_resp_empty),
    .o_cxtmgt_resp_rd_en(o_db_cxtmgt_resp_rd_en),
    .iv_cxtmgt_resp_data(iv_db_cxtmgt_resp_data),

    .i_cxtmgt_cxt_empty(i_db_cxtmgt_cxt_empty),
    .o_cxtmgt_cxt_rd_en(o_db_cxtmgt_cxt_rd_en),
    .iv_cxtmgt_cxt_data(iv_db_cxtmgt_cxt_data),

//VirtToPhys
    .o_vtp_cmd_wr_en(o_db_vtp_cmd_wr_en),
    .i_vtp_cmd_prog_full(i_db_vtp_cmd_prog_full),
    .ov_vtp_cmd_data(ov_db_vtp_cmd_data),

    .i_vtp_resp_empty(i_db_vtp_resp_empty),
    .o_vtp_resp_rd_en(o_db_vtp_resp_rd_en),
    .iv_vtp_resp_data(iv_db_vtp_resp_data),

//WQEScheduler
    .o_sch_md_wr_en(w_md_from_dbp_to_ws_wr_en),
    .i_sch_md_prog_full(w_md_from_dbp_to_ws_prog_full),
    .ov_sch_md_data(wv_md_from_dbp_to_ws_din),

    .dbg_sel(wv_dbp_dbg_sel),
    .dbg_bus(wv_dbp_dbg_bus)
);

WQEScheduler WQEScheduler_Inst(
    .clk(clk),
    .rst(rst),

    .i_wqe_from_db_empty(i_db_vtp_wqe_empty),
    .o_wqe_from_db_rd_en(o_db_vtp_wqe_rd_en),
    .iv_wqe_from_db_data(iv_db_vtp_wqe_data),

    .i_md_from_db_empty(w_md_from_dbp_to_ws_empty),
    .o_md_from_db_rd_en(w_md_from_dbp_to_ws_rd_en),
    .iv_md_from_db_data(wv_md_from_dbp_to_ws_dout),

    .i_wqe_from_wp_empty(i_wp_vtp_wqe_empty),
    .o_wqe_from_wp_rd_en(o_wp_vtp_wqe_rd_en),
    .iv_wqe_from_wp_data(iv_wp_vtp_wqe_data),

    .i_wqe_to_wp_prog_full(w_wqe_from_ws_to_wp_prog_full),
    .o_wqe_to_wp_wr_en(w_wqe_from_ws_to_wp_wr_en),
    .ov_wqe_to_wp_data(wv_wqe_from_ws_to_wp_din),

    .i_md_to_wp_prog_full(w_md_from_ws_to_wp_prog_full),
    .o_md_to_wp_wr_en(w_md_from_ws_to_wp_wr_en),
    .ov_md_to_wp_data(wv_md_from_ws_to_wp_din),

    .i_md_from_wp_empty(w_md_from_wp_to_ws_empty),
    .o_md_from_wp_rd_en(w_md_from_wp_to_ws_rd_en),
    .iv_md_from_wp_data(wv_md_from_wp_to_ws_dout),

//WQE Indicator Table
    .ov_wit_rd_addr(wv_wit_rd_addr),
    .iv_wit_rd_data(wv_wit_rd_data),

    .dbg_sel(wv_ws_dbg_sel),
    .dbg_bus(wv_ws_dbg_bus)
);

WQEParser WQEParser_Inst(
    .clk(clk),
    .rst(rst),

//Interface with WQE Scheduler
    .i_wqe_empty(w_wqe_from_ws_to_wp_empty),
    .iv_wqe_data(wv_wqe_from_ws_to_wp_dout),
    .o_wqe_rd_en(w_wqe_from_ws_to_wp_rd_en),

    .i_md_from_ws_empty(w_md_from_ws_to_wp_empty),
    .iv_md_from_ws_data(wv_md_from_ws_to_wp_dout),
    .o_md_from_ws_rd_en(w_md_from_ws_to_wp_rd_en),

    .i_md_to_ws_prog_full(w_md_from_wp_to_ws_prog_full),
    .o_md_to_ws_wr_en(w_md_from_wp_to_ws_wr_en),
    .ov_md_to_ws_data(wv_md_from_wp_to_ws_din),

//WQE Indicator Table
    .o_wit_wr_en(w_wit_wr_en),
    .ov_wit_wr_addr(wv_wit_wr_addr),
    .ov_wit_wr_data(wv_wit_wr_data),

//DataPack
    .i_md_to_dp_prog_full(w_md_from_wp_to_dp_prog_full),
    .o_md_to_dp_wr_en(w_md_from_wp_to_dp_wr_en),
    .ov_md_to_dp_data(wv_md_from_wp_to_dp_din),

    .i_inline_prog_full(w_inline_from_wp_to_dp_prog_full),
    .o_inline_wr_en(w_inline_from_wp_to_dp_wr_en),
    .ov_inline_data(wv_inline_from_wp_to_dp_din),

    .i_entry_prog_full(w_entry_from_wp_to_dp_prog_full),
    .o_entry_wr_en(w_entry_from_wp_to_dp_wr_en),
    .ov_entry_data(wv_entry_from_wp_to_dp_din),

    .i_atomics_prog_full(w_md_from_wp_to_dp_prog_full),
    .o_atomics_wr_en(w_atomics_from_wp_to_dp_wr_en),
    .ov_atomics_data(wv_atomics_from_wp_to_dp_din),

    .i_raddr_prog_full(w_md_from_wp_to_dp_prog_full),
    .o_raddr_wr_en(w_raddr_from_wp_to_dp_wr_en),
    .ov_raddr_data(wv_raddr_from_wp_to_dp_din),

//CxtMgt
    .i_cxtmgt_cmd_prog_full(i_wp_cxtmgt_cmd_prog_full),
    .o_cxtmgt_cmd_wr_en(o_wp_cxtmgt_cmd_wr_en),
    .ov_cxtmgt_cmd_data(ov_wp_cxtmgt_cmd_data),

    .i_cxtmgt_resp_empty(i_wp_cxtmgt_resp_empty),
    .iv_cxtmgt_resp_data(iv_wp_cxtmgt_resp_data),
    .o_cxtmgt_resp_rd_en(o_wp_cxtmgt_resp_rd_en),

    .i_cxtmgt_cxt_empty(i_wp_cxtmgt_cxt_empty),
    .iv_cxtmgt_cxt_data(iv_wp_cxtmgt_cxt_data),
    .o_cxtmgt_cxt_rd_en(o_wp_cxtmgt_cxt_rd_en),

//VirtToPhys
    //Fetch next WQE from if exists
    .o_vtp_wqe_cmd_wr_en(o_wp_vtp_wqe_cmd_wr_en),
    .i_vtp_wqe_cmd_prog_full(i_wp_vtp_wqe_cmd_prog_full),
    .ov_vtp_wqe_cmd_data(ov_wp_vtp_wqe_cmd_data),

    .i_vtp_wqe_resp_empty(i_wp_vtp_wqe_resp_empty),
    .o_vtp_wqe_resp_rd_en(o_wp_vtp_wqe_resp_rd_en),
    .iv_vtp_wqe_resp_data(iv_wp_vtp_wqe_resp_data),

    //Fetch network data
    .o_vtp_nd_cmd_wr_en(o_wp_vtp_nd_cmd_wr_en),
    .i_vtp_nd_cmd_prog_full(i_wp_vtp_nd_cmd_prog_full),
    .ov_vtp_nd_cmd_data(ov_wp_vtp_nd_cmd_data),

    .i_vtp_nd_resp_empty(i_wp_vtp_nd_resp_empty),
    .o_vtp_nd_resp_rd_en(o_wp_vtp_nd_resp_rd_en),
    .iv_vtp_nd_resp_data(iv_wp_vtp_nd_resp_data),
    
    .o_wp_init_finish(o_swp_init_finish),

    .dbg_sel(wv_wp_dbg_sel),
    .dbg_bus(wv_wp_dbg_bus)
);

DataPack DataPack_Inst(
    .clk(clk),
    .rst(rst),

//Interface with WQEParser
    .i_md_from_wp_empty(w_md_from_wp_to_dp_empty),
    .o_md_from_wp_rd_en(w_md_from_wp_to_dp_rd_en),
    .iv_md_from_wp_data(wv_md_from_wp_to_dp_dout),

    .i_inline_empty(w_inline_from_wp_to_dp_empty),
    .o_inline_rd_en(w_inline_from_wp_to_dp_rd_en),
    .iv_inline_data(wv_inline_from_wp_to_dp_dout),

    .i_entry_from_wp_empty(w_entry_from_wp_to_dp_empty),
    .o_entry_from_wp_rd_en(w_entry_from_wp_to_dp_rd_en),
    .iv_entry_from_wp_data(wv_entry_from_wp_to_dp_dout),

    .i_atomics_from_wp_empty(w_atomics_from_wp_to_dp_empty),
    .o_atomics_from_wp_rd_en(w_atomics_from_wp_to_dp_rd_en),
    .iv_atomics_from_wp_data(wv_atomics_from_wp_to_dp_dout),

    .i_raddr_from_wp_empty(w_raddr_from_wp_to_dp_empty),
    .o_raddr_from_wp_rd_en(w_raddr_from_wp_to_dp_rd_en),
    .iv_raddr_from_wp_data(wv_raddr_from_wp_to_dp_dout),

//VirtToPhys
    .i_nd_empty(i_wp_vtp_nd_empty),
    .o_nd_rd_en(o_wp_vtp_nd_rd_en),
    .iv_nd_data(iv_wp_vtp_nd_data),

//RequesterEngine
    .i_entry_to_re_prog_full(i_entry_to_re_prog_full),
    .o_entry_to_re_wr_en(o_entry_to_re_wr_en),
    .ov_entry_to_re_data(ov_entry_to_re_data),

    .i_atomics_to_re_prog_full(i_atomics_to_re_prog_full),
    .o_atomics_to_re_wr_en(o_atomics_to_re_wr_en),
    .ov_atomics_to_re_data(ov_atomics_to_re_data),

    .i_raddr_to_re_prog_full(i_raddr_to_re_prog_full),
    .o_raddr_to_re_wr_en(o_raddr_to_re_wr_en),
    .ov_raddr_to_re_data(ov_raddr_to_re_data),

    .i_nd_to_re_prog_full(i_nd_to_re_prog_full),
    .o_nd_to_re_wr_en(o_nd_to_re_wr_en),
    .ov_nd_to_re_data(ov_nd_to_re_data),

    .i_md_to_re_prog_full(i_md_to_re_prog_full),
    .o_md_to_re_wr_en(o_md_to_re_wr_en),
    .ov_md_to_re_data(ov_md_to_re_data),

    .dbg_sel(wv_dp_dbg_sel),
    .dbg_bus(wv_dp_dbg_bus)
);

endmodule
