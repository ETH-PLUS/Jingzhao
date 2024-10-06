//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: key_qpc_data.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V5.0 
// VERSION DESCRIPTION: 2st Edition  
//----------------------------------------------------
// RELEASE DATE: 2022-08-30
//---------------------------------------------------- 
// PURPOSE: store and operate on key context data
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
//----------------------------------------------------
// VERSION UPDATE: 
// modify ctxmgt module, store more info from the payload recieved from CEU
// add one more fifo (line 199) for key_qpc_data module
//-FHDR-----------------------------------------------

//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_ctxmgt_h.vh"

module key_qpc_data#(
    parameter INDEX  = 13// cqc/qpc index width
    )(
    input clk,
    input rst,  

	input 	wire 											global_mem_init_finish,
	input	wire 											init_wea,
	input	wire 	[`CXT_MEM_MAX_ADDR_WIDTH - 1 : 0]		init_addra,
	input	wire 	[`CXT_MEM_MAX_DIN_WIDTH - 1 : 0]		init_dina,

    //------------------interface to request controller----------------------
        //req_scheduler changes the value of Selected Channel Reg to mark the selected channel,key_qpc_data moduel read the info
        input  wire  [7 :0]  selected_channel,
        //send signal to request controller indicate that key_qpc_data module has received the req from selected_channel fifo
        output reg receive_req,
    //------------------interface to ceu channel----------------------
        // internal request cmd fifo from ceu_parser
        //35 width 
        output wire                       ceu_wr_req_rd_en,
        input  wire                       ceu_wr_req_empty,//also to request controller
        input  wire [`CEUP_REQ_KEY-1:0]   ceu_wr_req_dout,
        // // internal context data fifo from ceu_parser
        // //384 width 
        // output wire                       ceu_wr_data_rd_en,
        // input  wire                       ceu_wr_data_empty,
        // input  wire [`KEY_QPC_DT-1:0]     ceu_wr_data_dout,
        //384 width 
        //first fifo for old info
        output wire                       ceu_wr_data_rd_en1,
        input  wire                       ceu_wr_data_empty1,
        input  wire [`KEY_QPC_DT-1:0]     ceu_wr_data_dout1,
        //second fifo for new info
        output wire                       ceu_wr_data_rd_en2,
        input  wire                       ceu_wr_data_empty2,
        input  wire [`KEY_QPC_DT-1:0]     ceu_wr_data_dout2,    
    //Interface with RDMA Engine
        //Channel 1 for DoorbellProcessing, read cxt req, response ctx req, response ctx info, no write ctx req
        input   wire                i_db_cxtmgt_cmd_empty,
        output  wire                o_db_cxtmgt_cmd_rd_en,
        input   wire    [127:0]     iv_db_cxtmgt_cmd_data,

        output  reg                 o_db_cxtmgt_resp_wr_en,
        input   wire                i_db_cxtmgt_resp_prog_full,
        output  reg     [127:0]     ov_db_cxtmgt_resp_data,

        output  reg                 o_db_cxtmgt_resp_cxt_wr_en,
        input   wire                i_db_cxtmgt_resp_cxt_prog_full,
        output  wire     [255:0]    ov_db_cxtmgt_resp_cxt_data,

        //Channel 2 for WQEParser, read cxt req, response ctx req, response ctx info, no write ctx req
        input   wire                i_wp_cxtmgt_cmd_empty,
        output  wire                o_wp_cxtmgt_cmd_rd_en,
        input   wire    [127:0]     iv_wp_cxtmgt_cmd_data,

        output  reg                 o_wp_cxtmgt_resp_wr_en,
        input   wire                i_wp_cxtmgt_resp_prog_full,
        output  reg     [127:0]     ov_wp_cxtmgt_resp_data,

        output  reg                 o_wp_cxtmgt_resp_cxt_wr_en,
        input   wire                i_wp_cxtmgt_resp_cxt_prog_full,
        output  wire    [127:0]     ov_wp_cxtmgt_resp_cxt_data,

        //Channel 3 for RequesterTransControl, read cxt req, response ctx req, response ctx info, write ctx req
        input   wire                i_rtc_cxtmgt_cmd_empty,
        output  wire                o_rtc_cxtmgt_cmd_rd_en,
        input   wire    [127:0]     iv_rtc_cxtmgt_cmd_data,

        output  reg                 o_rtc_cxtmgt_resp_wr_en,
        input   wire                i_rtc_cxtmgt_resp_prog_full,
        output  reg     [127:0]     ov_rtc_cxtmgt_resp_data,

        output  reg                 o_rtc_cxtmgt_resp_cxt_wr_en,
        input   wire                i_rtc_cxtmgt_resp_cxt_prog_full,
        output  wire    [9*32-1:0]  ov_rtc_cxtmgt_resp_cxt_data,

        input   wire                i_rtc_cxtmgt_cxt_empty,
        output  wire                o_rtc_cxtmgt_cxt_rd_en,
        input   wire    [127:0]     iv_rtc_cxtmgt_cxt_data,

        //Channel 4 for RequesterRecvContro, read/write cxt req, response ctx req, response ctx info,  write ctx info
        input   wire                i_rrc_cxtmgt_cmd_empty,
        output  wire                o_rrc_cxtmgt_cmd_rd_en,
        input   wire    [127:0]     iv_rrc_cxtmgt_cmd_data,

        output  reg                 o_rrc_cxtmgt_resp_wr_en,
        input   wire                i_rrc_cxtmgt_resp_prog_full,
        output  reg     [127:0]     ov_rrc_cxtmgt_resp_data,

        output  reg                 o_rrc_cxtmgt_resp_cxt_wr_en,
        input   wire                i_rrc_cxtmgt_resp_cxt_prog_full,
        output  wire     [32*11-1:0]  ov_rrc_cxtmgt_resp_cxt_data,

        input   wire                i_rrc_cxtmgt_cxt_empty,
        output  wire                o_rrc_cxtmgt_cxt_rd_en,
        input   wire    [127:0]     iv_rrc_cxtmgt_cxt_data,

        //Channel 5 for ExecutionEngine, read/write cxt req, response ctx req, response ctx info,  write ctx info
        input   wire                i_ee_cxtmgt_cmd_empty,
        output  wire                o_ee_cxtmgt_cmd_rd_en,
        input   wire    [127:0]     iv_ee_cxtmgt_cmd_data,

        output  reg                 o_ee_cxtmgt_resp_wr_en,
        input   wire                i_ee_cxtmgt_resp_prog_full,
        output  reg     [127:0]     ov_ee_cxtmgt_resp_data,

        output  reg                 o_ee_cxtmgt_resp_cxt_wr_en,
        input   wire                i_ee_cxtmgt_resp_cxt_prog_full,
        output  wire [32*13-1:0]    ov_ee_cxtmgt_resp_cxt_data,

        input   wire                i_ee_cxtmgt_cxt_empty,
        output  wire                o_ee_cxtmgt_cxt_rd_en,
        input   wire    [127:0]     iv_ee_cxtmgt_cxt_data,

        //Channel 6 for FrameEncap, read cxt req, response ctx req, response ctx info
        input   wire                i_fe_cxtmgt_cmd_empty,
        output  wire                o_fe_cxtmgt_cmd_rd_en,
        input   wire    [127:0]     iv_fe_cxtmgt_cmd_data,

        output  reg                 o_fe_cxtmgt_resp_wr_en,
        input   wire                i_fe_cxtmgt_resp_prog_full,
        output  reg     [127:0]     ov_fe_cxtmgt_resp_data,

        output  reg                 o_fe_cxtmgt_resp_cxt_wr_en,
        input   wire                i_fe_cxtmgt_resp_cxt_prog_full,
        output  wire    [255:0]     ov_fe_cxtmgt_resp_cxt_data,
    //------------------interface to ctxmdata module-------------
        //internal dma write Request to ctxmdata module
        input  wire                      key_ctx_req_mdt_rd_en,
        output wire  [`HD_WIDTH-1:0]     key_ctx_req_mdt_dout,
        output wire                      key_ctx_req_mdt_empty
    
    `ifdef CTX_DUG
        /*Interface with APB Slave*/
        , input   wire 	[`KEY_DBG_RW_NUM * 32 - 1 : 0]	rw_data            
	    ,output wire 	[`KEY_DBG_REG_NUM * 32 -1:0]		wv_dbg_bus_5
    `endif 
);

/*************** RAM init control begin ****************/
reg		ram_init_finish;
always @(posedge clk or posedge rst) begin
	if(rst) begin
		ram_init_finish <= 'd0;
	end
	else if(global_mem_init_finish) begin
		ram_init_finish <= 1'b1;
	end 
	else begin
		ram_init_finish <= ram_init_finish;
	end 
end 
/*************** RAM init control finish ***************/

//--------------{fifo declaration}begin---------------//
    //dma write Request to ctxmdata module       
    //| ---------------128bit---------------------------------------------------------|
    //|   type   |  opcode |   R      |   QPN   |    R   |  PSN   |  R     |   State  | 
    //|    4 bit |  4 bit  |  24 bit  |  32 bit | 32 bit | 24 bit |  5 bit |   3 bit  |
    wire                        key_ctx_req_mdt_prog_full;
    reg                         key_ctx_req_mdt_wr_en;
    reg   [`HD_WIDTH-1-79:0]    key_ctx_req_mdt_din;
    wire  [`HD_WIDTH-1:0]       wv_key_ctx_req_mdt_din;

    // wire fifo_clear;
    // assign fifo_clear = 0;
    dma_rd_dt_req_fifo_128w32d dma_rd_dt_req_fifo_128w32d_Inst(
            .clk        (clk),
            .srst        (rst),
            .wr_en      (key_ctx_req_mdt_wr_en),
            .rd_en      (key_ctx_req_mdt_rd_en),
            .din        (wv_key_ctx_req_mdt_din),
            .dout       (key_ctx_req_mdt_dout),
            .full       (),
            .empty      (key_ctx_req_mdt_empty),     
            .prog_full  (key_ctx_req_mdt_prog_full)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[0 * 32 +: 1 * 32])        
    `endif 
);
//--------------{fifo declaration} end---------------//

//----------------{reg gorups decleration} begin-----------//
    /*SpyGlass*/
    //Key QP context
    //****************old version******************* 
    // [3:0]  qp_state[0:(1<<INDEX)-1];
    // [7:0]  qp_serv_type[0:(1<<INDEX)-1];
    // [7:0]  qp_mtu[0:(1<<INDEX)-1];
    // [7:0]  qp_rnr_retry[0:(1<<INDEX)-1];
    // [31:0] qp_local_qpn[0:(1<<INDEX)-1];
    // [31:0] qp_remote_qpn[0:(1<<INDEX)-1];
    // [31:0] qp_port_key[0:(1<<INDEX)-1];
    // [31:0] qp_pd[0:(1<<INDEX)-1];
    // [31:0] qp_sl_tclass[0:(1<<INDEX)-1];
    // [31:0] qp_next_psn[0:(1<<INDEX)-1];
    // [31:0] qp_cqn_send[0:(1<<INDEX)-1];
    // [31:0] qp_send_wqe_base_lkey[0:(1<<INDEX)-1];
    // [31:0] qp_unacked_psn[0:(1<<INDEX)-1];
    // [31:0] qp_expect_psn[0:(1<<INDEX)-1];
    // [31:0] qp_recv_wqe_base_lkey[0:(1<<INDEX)-1];
    //****************old version******************* 
    //****************new version add******************* 
    // [7:0]  qp_rq_entry_sz_log[0:(1<<INDEX)-1];
    // [7:0]  qp_sq_entry_sz_log[0:(1<<INDEX)-1];
    // [47:0] qp_smac[0:(1<<INDEX)-1];
    // [47:0] qp_dmac[0:(1<<INDEX)-1];
    // [31:0] qp_sip[0:(1<<INDEX)-1];
    // [31:0] qp_dip[0:(1<<INDEX)-1];
    // [31:0] qp_send_wqe_length[0:(1<<INDEX)-1];
    // [31:0] qp_cqn_recv[0:(1<<INDEX)-1];       
    // [31:0] qp_recv_wqe_length[0:(1<<INDEX)-1];
    //****************new version add******************* 

    // //Key CQ context regs
    //****************old version******************* 
    // [31:0] cq_lkey[0:(1<<INDEX)-1];
    //****************old version******************* 
    //****************new version add******************* 
    // [7:0]  cq_sz_log[0:(1<<INDEX)-1];
    // [31:0] cq_pd[0:(1<<INDEX)-1];
    //****************new version add******************* 
    // [7:0] eqn[0:(1<<INDEX)-1];
    //****************new version 2.0 add******************* 

     //Key EQ context regs
    // [31:0] eq_lkey[0:(1<<5)-1];
    // [7:0]  eq_sz_log[0:(1<<5)-1];
    // [31:0] eq_pd[0:(1<<5)-1];
    // [31:0] eq_intr[0:(1<<5)-1];
    //****************new version 2.0 add******************* 

//----------------{info gorups decleration} end-----------//

//----------------{key context data bram gorups decleration} begin-----------//
    /*SpyGlass*/
    //Key QP context regs
    //qp_state bram 4 width 16384 depth 
    reg               qp_state_en; 
    reg               qp_state_wr_en;
    reg    [INDEX-1 :0]   qp_state_addr;
    reg    [3 : 0]    qp_state_wr_data;
    wire   [3 : 0]    qp_state_rd_data;
    bram_qp_state_4w_1p qp_state_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_state_en : init_wea),
        .wea      (ram_init_finish ? qp_state_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_state_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_state_wr_data : init_dina[3:0]),
        .douta    (qp_state_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[1 * 32 +: 1 * 32])        
    `endif 
);
    //qp_serv_type bram 8 width 16384 depth  
    reg               qp_serv_tpye_en; 
    reg               qp_serv_tpye_wr_en;
    reg    [INDEX-1 :0]   qp_serv_tpye_addr;
    reg    [7 : 0]    qp_serv_tpye_wr_data;
    wire   [7 : 0]    qp_serv_tpye_rd_data;
    bram_servtype_8w_1p qp_serv_type_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_serv_tpye_en : init_wea),
        .wea      (ram_init_finish ? qp_serv_tpye_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_serv_tpye_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_serv_tpye_wr_data : init_dina[7:0]),
        .douta    (qp_serv_tpye_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[2 * 32 +: 1 * 32])        
    `endif 
);
    //qp_mtu bram 8 width 16384 depth  
    reg                qp_mtu_en; 
    reg                qp_mtu_wr_en;
    reg     [INDEX-1 :0]   qp_mtu_addr;
    reg     [7 : 0]    qp_mtu_wr_data;
    wire    [7 : 0]    qp_mtu_rd_data;
    bram_mtu_8w_1p qp_mtu_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_mtu_en : init_wea),
        .wea      (ram_init_finish ? qp_mtu_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_mtu_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_mtu_wr_data : init_dina[7:0]),
        .douta    (qp_mtu_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[3* 32 +: 1 * 32])        
    `endif 
);
    //qp_rnr_retry bram 8 width 16384 depth  
    reg                qp_rnr_retry_en; 
    reg                qp_rnr_retry_wr_en;
    reg     [INDEX-1 :0]   qp_rnr_retry_addr;
    reg     [7 : 0]    qp_rnr_retry_wr_data;
    wire    [7 : 0]    qp_rnr_retry_rd_data;
    bram_rnr_retry_8w_1p qp_rnr_retry_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_rnr_retry_en : init_wea),
        .wea      (ram_init_finish ? qp_rnr_retry_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_rnr_retry_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_rnr_retry_wr_data : init_dina[7:0]),
        .douta    (qp_rnr_retry_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[4 * 32 +: 1 * 32])        
    `endif 
);
    //qp_local_qpn bram 32 width 16384 depth 
    reg               qp_local_qpn_en; 
    reg               qp_local_qpn_wr_en;
    reg    [INDEX-1 :0]   qp_local_qpn_addr;
    reg    [31 : 0]   qp_local_qpn_wr_data;
    wire   [31 : 0]   qp_local_qpn_rd_data;
    bram_lqpn_32w_1p qp_local_qpn_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_local_qpn_en : init_wea),
        .wea      (ram_init_finish ? qp_local_qpn_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_local_qpn_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_local_qpn_wr_data : init_dina[31:0]),
        .douta    (qp_local_qpn_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[5 * 32 +: 1 * 32])        
    `endif 
);        
    //qp_remote_qpn bram 32 width 16384 depth
    reg               qp_remote_qpn_en; 
    reg               qp_remote_qpn_wr_en;
    reg    [INDEX-1 :0]   qp_remote_qpn_addr;
    reg    [31 : 0]   qp_remote_qpn_wr_data;
    wire   [31 : 0]   qp_remote_qpn_rd_data;
    bram_lqpn_32w_1p qp_remote_qpn_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_remote_qpn_en : init_wea),
        .wea      (ram_init_finish ? qp_remote_qpn_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_remote_qpn_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_remote_qpn_wr_data : init_dina[31:0]),
        .douta    (qp_remote_qpn_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[6 * 32 +: 1 * 32])        
    `endif 
);      
    //qp_port_key bram 32 width 16384 depth
    reg               qp_port_key_en; 
    reg               qp_port_key_wr_en;
    reg    [INDEX-1 :0]   qp_port_key_addr;
    reg    [31 : 0]   qp_port_key_wr_data;
    wire   [31 : 0]   qp_port_key_rd_data;
    bram_lqpn_32w_1p qp_port_key_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_port_key_en : init_wea),
        .wea      (ram_init_finish ? qp_port_key_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_port_key_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_port_key_wr_data : init_dina[31:0]),
        .douta    (qp_port_key_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[7 * 32 +: 1 * 32])        
    `endif 
);  
    //qp_pd bram 32 width 16384 depth
    reg               qp_pd_en; 
    reg               qp_pd_wr_en;
    reg    [INDEX-1 :0]   qp_pd_addr;
    reg    [31 : 0]   qp_pd_wr_data;
    wire   [31 : 0]   qp_pd_rd_data;
    bram_lqpn_32w_1p qp_pd_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_pd_en : init_wea),
        .wea      (ram_init_finish ? qp_pd_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_pd_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_pd_wr_data : init_dina[31:0]),
        .douta    (qp_pd_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[8 * 32 +: 1 * 32])        
    `endif 
); 
    //qp_sl_tclass bram 32 width 16384 depth 
    reg               qp_sl_tclass_en; 
    reg               qp_sl_tclass_wr_en;
    reg    [INDEX-1 :0]   qp_sl_tclass_addr;
    reg    [31 : 0]   qp_sl_tclass_wr_data;
    wire   [31 : 0]   qp_sl_tclass_rd_data;
    bram_lqpn_32w_1p qp_sl_tclass_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_sl_tclass_en : init_wea),
        .wea      (ram_init_finish ? qp_sl_tclass_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_sl_tclass_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_sl_tclass_wr_data : init_dina[31:0]),
        .douta    (qp_sl_tclass_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[9 * 32 +: 1 * 32])        
    `endif 
); 
    //qp_next_psn bram 32 width 16384 depth 
    reg               qp_next_psn_en; 
    reg               qp_next_psn_wr_en;
    reg    [INDEX-1 :0]   qp_next_psn_addr;
    reg    [31 : 0]   qp_next_psn_wr_data;
    wire   [31 : 0]   qp_next_psn_rd_data;
    bram_lqpn_32w_1p qp_next_psn_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_next_psn_en : init_wea),
        .wea      (ram_init_finish ? qp_next_psn_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_next_psn_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_next_psn_wr_data : init_dina[31:0]),
        .douta    (qp_next_psn_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[10 * 32 +: 1 * 32])        
    `endif 
); 
    //qp_cqn_send bram 32 width 16384 depth 
    reg               qp_cqn_send_en; 
    reg               qp_cqn_send_wr_en;
    reg    [INDEX-1 :0]   qp_cqn_send_addr;
    reg    [31 : 0]   qp_cqn_send_wr_data;
    wire   [31 : 0]   qp_cqn_send_rd_data;
    bram_lqpn_32w_1p qp_cqn_send_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_cqn_send_en : init_wea),
        .wea      (ram_init_finish ? qp_cqn_send_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_cqn_send_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_cqn_send_wr_data : init_dina[31:0]),
        .douta    (qp_cqn_send_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[11 * 32 +: 1 * 32])        
    `endif 
);   
    //qp_send_wqe_base_lkey bram 32 width 16384 depth 
    reg               qp_send_wqe_base_lkey_en; 
    reg               qp_send_wqe_base_lkey_wr_en;
    reg    [INDEX-1 :0]   qp_send_wqe_base_lkey_addr;
    reg    [31 : 0]   qp_send_wqe_base_lkey_wr_data;
    wire   [31 : 0]   qp_send_wqe_base_lkey_rd_data;
    bram_lqpn_32w_1p qp_send_wqe_base_lkey_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_send_wqe_base_lkey_en : init_wea),
        .wea      (ram_init_finish ? qp_send_wqe_base_lkey_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_send_wqe_base_lkey_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_send_wqe_base_lkey_wr_data : init_dina[31:0]),
        .douta    (qp_send_wqe_base_lkey_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[12 * 32 +: 1 * 32])        
    `endif 
);  
    //qp_unacked_psn bram 32 width 16384 depth 
    reg               qp_unacked_psn_en; 
    reg               qp_unacked_psn_wr_en;
    reg    [INDEX-1 :0]   qp_unacked_psn_addr;
    reg    [31 : 0]   qp_unacked_psn_wr_data;
    wire   [31 : 0]   qp_unacked_psn_rd_data;
    bram_lqpn_32w_1p qp_unacked_psn_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_unacked_psn_en : init_wea),
        .wea      (ram_init_finish ? qp_unacked_psn_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_unacked_psn_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_unacked_psn_wr_data : init_dina[31:0]),
        .douta    (qp_unacked_psn_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[13 * 32 +: 1 * 32])        
    `endif 
);  
    //qp_expect_psn bram 32 width 16384 depth 
    reg               qp_expect_psn_en; 
    reg               qp_expect_psn_wr_en;
    reg    [INDEX-1 :0]   qp_expect_psn_addr;
    reg    [31 : 0]   qp_expect_psn_wr_data;
    wire   [31 : 0]   qp_expect_psn_rd_data;
    bram_lqpn_32w_1p qp_expect_psn_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_expect_psn_en : init_wea),
        .wea      (ram_init_finish ? qp_expect_psn_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_expect_psn_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_expect_psn_wr_data : init_dina[31:0]),
        .douta    (qp_expect_psn_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[14 * 32 +: 1 * 32])        
    `endif 
); 
    //qp_recv_wqe_base_lkey bram 32 width 16384 depth 
    reg               qp_recv_wqe_base_lkey_en; 
    reg               qp_recv_wqe_base_lkey_wr_en;
    reg    [INDEX-1 :0]   qp_recv_wqe_base_lkey_addr;
    reg    [31 : 0]   qp_recv_wqe_base_lkey_wr_data;
    wire   [31 : 0]   qp_recv_wqe_base_lkey_rd_data;
    bram_lqpn_32w_1p qp_recv_wqe_base_lkey_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_recv_wqe_base_lkey_en : init_wea),
        .wea      (ram_init_finish ? qp_recv_wqe_base_lkey_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_recv_wqe_base_lkey_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_recv_wqe_base_lkey_wr_data : init_dina[31:0]),
        .douta    (qp_recv_wqe_base_lkey_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[15 * 32 +: 1 * 32])        
    `endif 
);
    //Key CQ context regs
    //cq_lkey bram 32 width 16384 depth 
    reg               cq_lkey_en; 
    reg               cq_lkey_wr_en;
    reg    [INDEX-1 :0]   cq_lkey_addr;
    reg    [31 : 0]   cq_lkey_wr_data;
    wire   [31 : 0]   cq_lkey_rd_data;
    bram_lqpn_32w_1p cq_lkey_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? cq_lkey_en : init_wea),
        .wea      (ram_init_finish ? cq_lkey_wr_en : init_wea),
        .addra    (ram_init_finish ? cq_lkey_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? cq_lkey_wr_data : init_dina[31:0]),
        .douta    (cq_lkey_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[16 * 32 +: 1 * 32])        
    `endif 
); 
    //****************new version add for QP info******************* 
    // qp_rq_entry_sz_log_ram 8 width 16384 depth
    reg                qp_rq_entry_sz_log_en; 
    reg                qp_rq_entry_sz_log_wr_en;
    reg     [INDEX-1 :0]   qp_rq_entry_sz_log_addr;
    reg     [7 : 0]    qp_rq_entry_sz_log_wr_data;
    wire    [7 : 0]    qp_rq_entry_sz_log_rd_data;
    bram_rnr_retry_8w_1p qp_rq_entry_sz_log_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_rq_entry_sz_log_en : init_wea),
        .wea      (ram_init_finish ? qp_rq_entry_sz_log_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_rq_entry_sz_log_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_rq_entry_sz_log_wr_data : init_dina[7:0]),
        .douta    (qp_rq_entry_sz_log_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[17 * 32 +: 1 * 32])        
    `endif 
);
    // [7:0]  qp_sq_entry_sz_log bram 8 width 16384 depth 
    reg                qp_sq_entry_sz_log_en; 
    reg                qp_sq_entry_sz_log_wr_en;
    reg     [INDEX-1 :0]   qp_sq_entry_sz_log_addr;
    reg     [7 : 0]    qp_sq_entry_sz_log_wr_data;
    wire    [7 : 0]    qp_sq_entry_sz_log_rd_data;
    bram_rnr_retry_8w_1p qp_sq_entry_sz_log_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_sq_entry_sz_log_en : init_wea),
        .wea      (ram_init_finish ? qp_sq_entry_sz_log_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_sq_entry_sz_log_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_sq_entry_sz_log_wr_data : init_dina[7:0]),
        .douta    (qp_sq_entry_sz_log_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[18 * 32 +: 1 * 32])        
    `endif 
);
    // [47:0] qp_smac bram 48 width 16384 depth 
    reg                qp_smac_en; 
    reg                qp_smac_wr_en;
    reg     [INDEX-1 :0]   qp_smac_addr;
    reg     [47 : 0]   qp_smac_wr_data;
    wire    [47 : 0]   qp_smac_rd_data;
    bram_mac_48w_1p qp_smac_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_smac_en : init_wea),
        .wea      (ram_init_finish ? qp_smac_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_smac_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_smac_wr_data : init_dina[47:0]),
        .douta    (qp_smac_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[19 * 32 +: 1 * 32])        
    `endif 
);
    // [47:0] qp_dmac bram 48 width 16384 depth 
    reg                qp_dmac_en; 
    reg                qp_dmac_wr_en;
    reg     [INDEX-1 :0]   qp_dmac_addr;
    reg     [47 : 0]   qp_dmac_wr_data;
    wire    [47 : 0]   qp_dmac_rd_data;
    bram_mac_48w_1p qp_dmac_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_dmac_en : init_wea),
        .wea      (ram_init_finish ? qp_dmac_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_dmac_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_dmac_wr_data : init_dina[47:0]),
        .douta    (qp_dmac_rd_data)
    `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[20 * 32 +: 1 * 32])        
    `endif 
);
    // [31:0] qp_sip bram 32 width 16384 depth 
    reg               qp_sip_en; 
    reg               qp_sip_wr_en;
    reg    [INDEX-1 :0]   qp_sip_addr;
    reg    [31 : 0]   qp_sip_wr_data;
    wire   [31 : 0]   qp_sip_rd_data;
    bram_lqpn_32w_1p qp_sip_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_sip_en : init_wea),
        .wea      (ram_init_finish ? qp_sip_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_sip_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_sip_wr_data : init_dina[31:0]),
        .douta    (qp_sip_rd_data)
    `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[21 * 32 +: 1 * 32])        
    `endif 
    );
    // [31:0] qp_dip bram 32 width 16384 depth 
    reg               qp_dip_en; 
    reg               qp_dip_wr_en;
    reg    [INDEX-1 :0]   qp_dip_addr;
    reg    [31 : 0]   qp_dip_wr_data;
    wire   [31 : 0]   qp_dip_rd_data;
    bram_lqpn_32w_1p qp_dip_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_dip_en : init_wea),
        .wea      (ram_init_finish ? qp_dip_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_dip_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_dip_wr_data : init_dina[31:0]),
        .douta    (qp_dip_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[22 * 32 +: 1 * 32])        
    `endif 
);
    // [31:0] qp_send_wqe_length bram 32 width 16384 depth 
    reg               qp_send_wqe_length_en; 
    reg               qp_send_wqe_length_wr_en;
    reg    [INDEX-1 :0]   qp_send_wqe_length_addr;
    reg    [31 : 0]   qp_send_wqe_length_wr_data;
    wire   [31 : 0]   qp_send_wqe_length_rd_data;
    bram_lqpn_32w_1p qp_send_wqe_length_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_send_wqe_length_en : init_wea),
        .wea      (ram_init_finish ? qp_send_wqe_length_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_send_wqe_length_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_send_wqe_length_wr_data : init_dina[31:0]),
        .douta    (qp_send_wqe_length_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[23 * 32 +: 1 * 32])        
    `endif 
);
    // [31:0] qp_cqn_recv bram 32 width 16384 depth 
    reg               qp_cqn_recv_en; 
    reg               qp_cqn_recv_wr_en;
    reg    [INDEX-1 :0]   qp_cqn_recv_addr;
    reg    [31 : 0]   qp_cqn_recv_wr_data;
    wire   [31 : 0]   qp_cqn_recv_rd_data;
    bram_lqpn_32w_1p qp_cqn_recv_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_cqn_recv_en : init_wea),
        .wea      (ram_init_finish ? qp_cqn_recv_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_cqn_recv_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_cqn_recv_wr_data : init_dina[31:0]),
        .douta    (qp_cqn_recv_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[24 * 32 +: 1 * 32])        
    `endif 
);     
    // [31:0] qp_recv_wqe_length bram 32 width 16384 depth 
    reg               qp_recv_wqe_length_en; 
    reg               qp_recv_wqe_length_wr_en;
    reg    [INDEX-1 :0]   qp_recv_wqe_length_addr;
    reg    [31 : 0]   qp_recv_wqe_length_wr_data;
    wire   [31 : 0]   qp_recv_wqe_length_rd_data;
    bram_lqpn_32w_1p qp_recv_wqe_length_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? qp_recv_wqe_length_en : init_wea),
        .wea      (ram_init_finish ? qp_recv_wqe_length_wr_en : init_wea),
        .addra    (ram_init_finish ? qp_recv_wqe_length_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? qp_recv_wqe_length_wr_data : init_dina[31:0]),
        .douta    (qp_recv_wqe_length_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[25 * 32 +: 1 * 32])        
    `endif 
);
    //****************new version add for QP info******************* 

    //****************new version add for CQ info******************* 
    // [7:0]  cq_sz_log bram 8 width 16384 depth  
    reg                cq_sz_log_en; 
    reg                cq_sz_log_wr_en;
    reg     [INDEX-1 :0]   cq_sz_log_addr;
    reg     [7 : 0]    cq_sz_log_wr_data;
    wire    [7 : 0]    cq_sz_log_rd_data;
    bram_rnr_retry_8w_1p cq_sz_log_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? cq_sz_log_en : init_wea),
        .wea      (ram_init_finish ? cq_sz_log_wr_en : init_wea),
        .addra    (ram_init_finish ? cq_sz_log_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? cq_sz_log_wr_data : init_dina[7:0]),
        .douta    (cq_sz_log_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[26 * 32 +: 1 * 32])        
    `endif 
);
    // [31:0] cq_pd bram 32 width 16384 depth 
    reg               cq_pd_en; 
    reg               cq_pd_wr_en;
    reg    [INDEX-1 :0]   cq_pd_addr;
    reg    [31 : 0]   cq_pd_wr_data;
    wire   [31 : 0]   cq_pd_rd_data;
    bram_lqpn_32w_1p cq_pd_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? cq_pd_en : init_wea),
        .wea      (ram_init_finish ? cq_pd_wr_en : init_wea),
        .addra    (ram_init_finish ? cq_pd_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? cq_pd_wr_data : init_dina[31:0]),
        .douta    (cq_pd_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[27 * 32 +: 1 * 32])        
    `endif 
);
    //****************new version add for CQ info*******************

    //****************new version 2.0 add for CQ info*******************
    // [7:0] eqn[0:(1<<INDEX)-1];
    reg                eqn_en; 
    reg                eqn_wr_en;
    reg     [INDEX-1 :0]   eqn_addr;
    reg     [7 : 0]    eqn_wr_data;
    wire    [7 : 0]    eqn_rd_data;
    bram_rnr_retry_8w_1p eqn_ram(
        .clka     (clk),
        .ena      (ram_init_finish ? eqn_en : init_wea),
        .wea      (ram_init_finish ? eqn_wr_en : init_wea),
        .addra    (ram_init_finish ? eqn_addr : init_addra[INDEX-1:0]),
        .dina     (ram_init_finish ? eqn_wr_data : init_dina[7:0]),
        .douta    (eqn_rd_data)
        `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[28 * 32 +: 1 * 32])        
    `endif 
);
    //****************new version 2.0 add for CQ info*******************

    //****************new version 2.0 add for EQ info*******************
    //Key EQ context regs
    reg [31:0] eq_lkey [0:(1<<5)-1];
    // reg [32*32-1:0] eq_lkey;
    reg [7:0]  eq_sz_log [0:(1<<5)-1];
    // reg [32*8-1:0] eq_sz_log;
    reg [31:0] eq_pd [0:(1<<5)-1];
    // reg [32*32-1:0] eq_pd;
    reg [15:0] eq_intr [0:(1<<5)-1];    
    // reg [15*32-1:0] eq_intr;
    reg eqn_valid [0:31];
    //****************new version 2.0 add for EQ info*******************


//----------------{key context data bram gorups decleration} end-----------//

//-----------------{key_qpc_data state mechine} begin--------------------//

    //--------------{variable declaration}---------------
    // read: request header 
    parameter  RD_REQ   = 3'b001;
    // write key context data      
    parameter  DATA_WR  = 3'b010; 
    // initiate resp to RDMA engine submodule
    parameter  RESP_OUT = 3'b100 ;

    reg [2:0] fsm_cs;
    reg [2:0] fsm_ns;
    
    wire [127:0]  wv_selected_req_data;//choose the selected req channel req fifo
    //type, op, qpn from selected channel req dout
    wire [3:0]    wv_selected_req_type;
    wire [3:0]    wv_selected_req_op;
    wire [INDEX-1 :0]   wv_selected_req_qpn;

    reg [127:0]  qv_tmp_req;
    //type, op, qpn from selected channel req tmp reg
    wire [3:0]    wv_req_reg_type;
    wire [3:0]    wv_req_reg_op;
    wire [INDEX-1 :0]   wv_req_reg_qpn;
    /*Spyglass*/
    //wire [INDEX-1 :0]   wv_req_reg_cqn;
    /*Action = Delete*/

    wire has_mdt_req;// RDMA engine submodule write key context data: resp cmd & ctxmdata req in RESP_OUT state
    wire no_mdt_req; // RDMA engine submodule read  key context data: resp cmd & resp ctx in RESP_OUT state
    wire no_resp_ctx_data; // RDMA engine submodule write key context data: resp cmd & ctxmdata req in RESP_OUT state
    wire has_resp_ctx_data; // RDMA engine submodule read  key context data: resp cmd & resp ctx in RESP_OUT state

    reg [6:0] qv_selected_channel;
    wire selected_resp_cmd_fifo_prog_full; 
    wire selected_resp_ctx_fifo_prog_full;

    /*Spyglass*/
    reg [1:0] qv_read_ram_cnt;// count for ram read times: read qp ram data occupis 1 clk, read cq ram data occupis 2 clk.
    reg [127:0] qv_tmp_ctx_payload;//RDMA engine write payload reg for context metadata req
    /*Action = Add*/
    
    /*********************new version add for indicating whether lookup CQ info  ***************************/
    wire lookup_cq_info;
    wire only_lookup_qp_info;
    /*********************new version add for counting clocks if lookup CQ info  ***************************/

    /*********************new version add for indicating whether lookup EQ info  ***************************/
    wire lookup_eq_info;
    /*********************new version add for counting clocks if lookup EQ info  ***************************/
    /*ila*/
//    qp_state_ila qp_state_ila (
//        .clk(clk),
//        .probe0(qp_state_en),//1
//        .probe1(qp_state_wr_en),//1
//        .probe2(qp_state_addr),//14
//        .probe3(qp_state_wr_data),//4
//        .probe4(qp_state_rd_data)//4
//    );

//    qp_next_psn_ila qp_next_psn_ila (
//        .clk(clk),
//        .probe0(qp_next_psn_en),//1
//        .probe1(qp_next_psn_wr_en),//1
//        .probe2(qp_next_psn_addr),//14
//        .probe3(qp_next_psn_wr_data),//32
//        .probe4(qp_next_psn_rd_data)//32
//    );

//    qp_next_psn_ila cq_lkey_ila (
//        .clk(clk),
//        .probe0(cq_lkey_en),//1
//        .probe1(cq_lkey_wr_en),//1
//        .probe2(cq_lkey_addr),//14
//        .probe3(cq_lkey_wr_data),//32
//        .probe4(cq_lkey_rd_data)//32
//    );

    //-----------------Stage 1 :State Register----------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fsm_cs <= `TD  RD_REQ;
        end
        else begin
            fsm_cs <= `TD  fsm_ns;
        end
    end
    //-----------------Stage 2 :State Transition----------
    always @(*) begin
        case (fsm_cs)
            RD_REQ: begin
                //write key context data
                // if (selected_channel[7] && (selected_channel[0] || ((wv_selected_req_type == `WR_QP_CTX) && (wv_selected_req_op == `WR_QP_UAPST) ) || ((wv_selected_req_type == `WR_QP_CTX) && (wv_selected_req_op == `WR_QP_NPST)) || ((wv_selected_req_type == `WR_QP_CTX) && (wv_selected_req_op == `WR_QP_EPST)))) begin
                if (selected_channel[7] && (ceu_wr_req_rd_en || (o_rtc_cxtmgt_cmd_rd_en && (wv_selected_req_type == `WR_QP_CTX) && (wv_selected_req_op == `WR_QP_NPST) && !i_rtc_cxtmgt_cmd_empty) || (o_rrc_cxtmgt_cmd_rd_en && (wv_selected_req_type == `WR_QP_CTX) && (wv_selected_req_op == `WR_QP_UAPST) && !i_rrc_cxtmgt_cmd_empty) || (o_ee_cxtmgt_cmd_rd_en && (wv_selected_req_type == `WR_QP_CTX) && (wv_selected_req_op == `WR_QP_EPST) && !i_ee_cxtmgt_cmd_empty))) begin
                    fsm_ns = DATA_WR;
                end
                //read key context data; initiate resp msg and ctxmdata req
                else if (selected_channel[7] && !selected_channel[0] && ((wv_selected_req_type == `RD_QP_CTX) || (wv_selected_req_type == `RD_CQ_CTX)) && (ceu_wr_req_rd_en || o_db_cxtmgt_cmd_rd_en || o_wp_cxtmgt_cmd_rd_en || o_rtc_cxtmgt_cmd_rd_en || o_rrc_cxtmgt_cmd_rd_en || o_ee_cxtmgt_cmd_rd_en || o_fe_cxtmgt_cmd_rd_en) && !selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                    fsm_ns = RESP_OUT;
                end
                //get new req
                else begin
                    fsm_ns = RD_REQ;
                end
            end
            DATA_WR: begin
            //modify for EQ
                if (((wv_req_reg_type == `WR_QP_CTX) && (wv_req_reg_op == `WR_QP_ALL)) 
                || ((wv_req_reg_type == `WR_CQ_CTX) && ((wv_req_reg_op == `WR_CQ_ALL) || (wv_req_reg_op == `WR_CQ_MODIFY) || (wv_req_reg_op == `WR_CQ_INVALID)))
                || ((wv_req_reg_type == `WR_EQ_CTX) && ((wv_req_reg_op == `WR_EQ_ALL) || (wv_req_reg_op == `WR_EQ_INVALID) || (wv_req_reg_op == `WR_EQ_FUNC))))begin
                    fsm_ns = RD_REQ;
                end 
                else if (!key_ctx_req_mdt_prog_full && !selected_resp_cmd_fifo_prog_full) begin
                    fsm_ns = RESP_OUT;
                end
                else begin
                    fsm_ns = DATA_WR;
                end
            end
            RESP_OUT: begin
                //(1) RDMA engine submodule write key context data: resp cmd & ctxmdata req
                //(2) RDMA engine submodule read  key context data: resp cmd & resp ctx (read qp data 1 clk, read cq data 2 clk)
                if ((has_mdt_req && !key_ctx_req_mdt_prog_full && !selected_resp_cmd_fifo_prog_full && no_resp_ctx_data) || (no_mdt_req && !selected_resp_cmd_fifo_prog_full && has_resp_ctx_data && !selected_resp_ctx_fifo_prog_full && ((only_lookup_qp_info && (qv_read_ram_cnt == 2'b01)) || (lookup_cq_info && (qv_read_ram_cnt == 2'b11))))) begin
                    fsm_ns = RD_REQ;
                end
                else begin
                    fsm_ns = RESP_OUT;
                end
            end
            default: fsm_ns = RD_REQ;
        endcase
    end
    /*Action = Modify*/
    //---------------------------------Stage 3 :Output Decode--------------------------------
    //----------selected_channel ----------------
        //| bit |        Description           |
        //|-----|------------------------------|
        //|  0  |   CEU                        |
        //|  1  |   Doorbell Processing(DBP)   |
        //|  2  |   WQE Parser(WP）            |
        //|  3  |   RequesterTransControl(RTC) |
        //|  4  |   RequesterRecvControl(RRC)  |
        //|  5  |   Execution Engine(EE)       |
        //|  6  |    valid                     |
    assign wv_selected_req_data =  (selected_channel[0] & selected_channel[7]) ? {ceu_wr_req_dout[`CEUP_REQ_KEY-1:`CEUP_REQ_KEY-8],ceu_wr_req_dout[23:0],96'b0} :
                            (selected_channel[1] & selected_channel[7]) ? iv_db_cxtmgt_cmd_data :
                            (selected_channel[2] & selected_channel[7]) ? iv_wp_cxtmgt_cmd_data :
                            (selected_channel[3] & selected_channel[7]) ? iv_rtc_cxtmgt_cmd_data :
                            (selected_channel[4] & selected_channel[7]) ? iv_rrc_cxtmgt_cmd_data :
                            (selected_channel[5] & selected_channel[7]) ? iv_ee_cxtmgt_cmd_data :
                            (selected_channel[6] & selected_channel[7]) ? iv_fe_cxtmgt_cmd_data : 0;
    //type, op, qpn from selected channel req dout
        //wire [3:0]    wv_selected_req_type;
        //wire [3:0]    wv_selected_req_op;
        //wire [INDEX-1 :0]   wv_selected_req_qpn;
    assign wv_selected_req_type = wv_selected_req_data[127:124]; 
    assign wv_selected_req_op   = wv_selected_req_data[123:120]; 
    assign wv_selected_req_qpn  = wv_selected_req_data[108:96]; 

    /*Spyglass*/
    assign ceu_wr_req_rd_en       = (fsm_cs == RD_REQ) && selected_channel[7] && selected_channel[0] && !ceu_wr_req_empty;
    assign o_db_cxtmgt_cmd_rd_en  = (fsm_cs == RD_REQ) && selected_channel[7] && selected_channel[1] && !i_db_cxtmgt_cmd_empty &&  !i_db_cxtmgt_resp_prog_full && !i_db_cxtmgt_resp_cxt_prog_full;
    assign o_wp_cxtmgt_cmd_rd_en  = (fsm_cs == RD_REQ) && selected_channel[7] && selected_channel[2] && !i_wp_cxtmgt_cmd_empty &&  !i_wp_cxtmgt_resp_prog_full && !i_wp_cxtmgt_resp_cxt_prog_full;
    assign o_rtc_cxtmgt_cmd_rd_en = (fsm_cs == RD_REQ) && selected_channel[7] && selected_channel[3] && !i_rtc_cxtmgt_cmd_empty &&  !i_rrc_cxtmgt_resp_prog_full  && !i_rrc_cxtmgt_resp_cxt_prog_full;
    assign o_rrc_cxtmgt_cmd_rd_en = (fsm_cs == RD_REQ) && selected_channel[7] && selected_channel[4] && !i_rrc_cxtmgt_cmd_empty &&  !i_rtc_cxtmgt_resp_prog_full  && !i_rtc_cxtmgt_resp_cxt_prog_full;
    assign o_ee_cxtmgt_cmd_rd_en  = (fsm_cs == RD_REQ) && selected_channel[7] && selected_channel[5] && !i_ee_cxtmgt_cmd_empty &&  !i_ee_cxtmgt_resp_prog_full && !i_ee_cxtmgt_resp_cxt_prog_full;
    assign o_fe_cxtmgt_cmd_rd_en  = (fsm_cs == RD_REQ) && selected_channel[7] && selected_channel[6] && !i_fe_cxtmgt_cmd_empty &&  !i_fe_cxtmgt_resp_prog_full && !i_fe_cxtmgt_resp_cxt_prog_full;
    /*Action = Modify, remoce condition fsm_ns != RD_REQ to receive new req*/
    /*Action = Modify*/

    //paylaod data read enable
    //modify for EQ
    assign ceu_wr_data_rd_en1      = (fsm_cs == DATA_WR) && !ceu_wr_data_empty1 && (((wv_req_reg_type == `WR_QP_CTX) && (wv_req_reg_op == `WR_QP_ALL)) 
        || ((wv_req_reg_type == `WR_CQ_CTX) && ((wv_req_reg_op == `WR_CQ_ALL) || (wv_req_reg_op == `WR_CQ_MODIFY)))
        || ((wv_req_reg_type == `WR_EQ_CTX) && (wv_req_reg_op == `WR_EQ_ALL)) ) ;
    assign ceu_wr_data_rd_en2      = (fsm_cs == DATA_WR) && !ceu_wr_data_empty2 && ((wv_req_reg_type == `WR_QP_CTX) && (wv_req_reg_op == `WR_QP_ALL)) ;
    /*Spyglass*/
    //assign o_rtc_cxtmgt_cxt_rd_en = (fsm_cs == DATA_WR) && (wv_req_reg_type == `WR_QP_CTX) && (wv_req_reg_op == `WR_QP_NPST);
    //assign o_rrc_cxtmgt_cxt_rd_en = (fsm_cs == DATA_WR) && (wv_req_reg_type == `WR_QP_CTX) && (wv_req_reg_op == `WR_QP_UAPST);
    //assign o_ee_cxtmgt_cxt_rd_en  = (fsm_cs == DATA_WR) && (wv_req_reg_type == `WR_QP_CTX) && (wv_req_reg_op == `WR_QP_EPST);
    assign o_rtc_cxtmgt_cxt_rd_en = (fsm_cs == DATA_WR) && (wv_req_reg_type == `WR_QP_CTX) && (wv_req_reg_op == `WR_QP_NPST) && !key_ctx_req_mdt_prog_full && !selected_resp_cmd_fifo_prog_full && !i_rtc_cxtmgt_cxt_empty;
    assign o_rrc_cxtmgt_cxt_rd_en = (fsm_cs == DATA_WR) && (wv_req_reg_type == `WR_QP_CTX) && (wv_req_reg_op == `WR_QP_UAPST) && !key_ctx_req_mdt_prog_full && !selected_resp_cmd_fifo_prog_full && !i_rrc_cxtmgt_cxt_empty;
    assign o_ee_cxtmgt_cxt_rd_en  = (fsm_cs == DATA_WR) && (wv_req_reg_type == `WR_QP_CTX) && (wv_req_reg_op == `WR_QP_EPST) && !key_ctx_req_mdt_prog_full && !selected_resp_cmd_fifo_prog_full && !i_ee_cxtmgt_cxt_empty;
    /*Action = Modify*/

    //reg [127:0]  qv_tmp_req;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_tmp_req <= `TD  0;
        end
        else if ((fsm_cs == RD_REQ) && (ceu_wr_req_rd_en || o_db_cxtmgt_cmd_rd_en || o_wp_cxtmgt_cmd_rd_en || o_rtc_cxtmgt_cmd_rd_en || o_rrc_cxtmgt_cmd_rd_en || o_ee_cxtmgt_cmd_rd_en || o_fe_cxtmgt_cmd_rd_en)) begin
            qv_tmp_req <= `TD  wv_selected_req_data;
        end
        else if ((fsm_cs == DATA_WR) || (fsm_cs == RESP_OUT)) begin
            qv_tmp_req <= `TD  qv_tmp_req;
        end
        else begin
            qv_tmp_req <= `TD  0;
        end
    end

    //type, op, qpn from selected channel req tmp reg
        //wire [3:0]    wv_req_reg_type;
        //wire [3:0]    wv_req_reg_op;
        //wire [INDEX-1 :0]   wv_req_reg_qpn;
        //wire [INDEX-1 :0]   wv_req_reg_cqn;
    assign wv_req_reg_type = qv_tmp_req[127:124];
    assign wv_req_reg_op   = qv_tmp_req[123:120];
    assign wv_req_reg_qpn  = qv_tmp_req[108:96];
    /*Spyglass*/
    //assign wv_req_reg_cqn  = qv_tmp_req[119:96];
    /*Action = Delete*/    
    assign lookup_cq_info = ((wv_req_reg_type == `RD_QP_CTX) && ((wv_req_reg_op == `RD_QP_NPST) || (wv_req_reg_op == `RD_QP_RST))) || ((wv_req_reg_type == `RD_CQ_CTX) && (wv_req_reg_op == `RD_CQ_CST));
    assign only_lookup_qp_info = (wv_req_reg_type == `RD_QP_CTX) && ((wv_req_reg_op == `RD_QP_SST) || (wv_req_reg_op == `RD_QP_STATE) || (wv_req_reg_op == `RD_ENCAP));
    //add for EQ
    assign lookup_eq_info = ((wv_req_reg_type == `RD_QP_CTX) && ((wv_req_reg_op == `RD_QP_NPST) || (wv_req_reg_op == `RD_QP_RST))) || ((wv_req_reg_type == `RD_CQ_CTX) && (wv_req_reg_op == `RD_CQ_CST));

    //wire has_mdt_req;// RDMA engine submodule write key context data: resp cmd & ctxmdata req in RESP_OUT state
    assign has_mdt_req = ((wv_req_reg_type == `WR_QP_CTX) && (wv_req_reg_op == `WR_QP_NPST)) || 
                        ((wv_req_reg_type == `WR_QP_CTX) && (wv_req_reg_op == `WR_QP_UAPST)) || 
                        ((wv_req_reg_type == `WR_QP_CTX) && (wv_req_reg_op == `WR_QP_EPST));
    
    //wire no_mdt_req; // RDMA engine submodule read key context data: resp cmd & resp ctx in RESP_OUT state
    //                 // CEU req: write total key_qpc data or cq_lkey
    assign no_mdt_req = ((wv_req_reg_type == `RD_QP_CTX) && (wv_req_reg_op == `RD_QP_NPST)) || 
                        ((wv_req_reg_type == `RD_QP_CTX) && (wv_req_reg_op == `RD_QP_SST)) || 
                        ((wv_req_reg_type == `RD_QP_CTX) && (wv_req_reg_op == `RD_QP_RST)) || 
                        ((wv_req_reg_type == `RD_QP_CTX) && (wv_req_reg_op == `RD_QP_STATE)) || 
                        ((wv_req_reg_type == `RD_QP_CTX) && (wv_req_reg_op == `RD_ENCAP)) || 
                        ((wv_req_reg_type == `RD_CQ_CTX) && (wv_req_reg_op == `RD_CQ_CST)) || 
                        ((wv_req_reg_type == `WR_QP_CTX) && (wv_req_reg_op == `WR_QP_ALL)) || 
                        ((wv_req_reg_type == `WR_CQ_CTX) && (wv_req_reg_op == `WR_CQ_ALL)) || 
                        ((wv_req_reg_type == `WR_CQ_CTX) && (wv_req_reg_op == `WR_CQ_MODIFY));
    
    //wire no_resp_ctx_data; // RDMA engine submodule write key context data: resp cmd & ctxmdata req in RESP_OUT state
    assign no_resp_ctx_data = ((wv_req_reg_type == `WR_QP_CTX) && (wv_req_reg_op == `WR_QP_NPST)) || 
                        ((wv_req_reg_type == `WR_QP_CTX) && (wv_req_reg_op == `WR_QP_UAPST)) || 
                        ((wv_req_reg_type == `WR_QP_CTX) && (wv_req_reg_op == `WR_QP_EPST));
    
    //wire has_resp_ctx_data; // RDMA engine submodule read  key context data: resp cmd & resp ctx in RESP_OUT state
    assign has_resp_ctx_data = ((wv_req_reg_type == `RD_QP_CTX) && (wv_req_reg_op == `RD_QP_NPST)) || 
                        ((wv_req_reg_type == `RD_QP_CTX) && (wv_req_reg_op == `RD_QP_SST)) || 
                        ((wv_req_reg_type == `RD_QP_CTX) && (wv_req_reg_op == `RD_QP_RST)) || 
                        ((wv_req_reg_type == `RD_QP_CTX) && (wv_req_reg_op == `RD_QP_STATE)) || 
                        ((wv_req_reg_type == `RD_QP_CTX) && (wv_req_reg_op == `RD_ENCAP)) || 
                        ((wv_req_reg_type == `RD_CQ_CTX) && (wv_req_reg_op == `RD_CQ_CST));
    
    //reg [6:0] qv_selected_channel;
    //output reg receive_req,
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_selected_channel <= `TD  0;
            receive_req <= `TD  0;
        end 
        /*Spyglass*/
        //else if ((fsm_cs == RD_REQ) && selected_channel[7] && (|selected_channel[5:0])) begin
        // else if ((fsm_cs == RD_REQ) && selected_channel[7] && ((selected_channel[0]) || (|selected_channel[5:1] && ((wv_selected_req_type == `WR_QP_CTX) || (((wv_selected_req_type == `RD_QP_CTX) || (wv_selected_req_type == `RD_CQ_CTX)) && !selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full))))) begin        
        else if ((fsm_cs == RD_REQ) && selected_channel[7] && (ceu_wr_req_rd_en || o_db_cxtmgt_cmd_rd_en || o_wp_cxtmgt_cmd_rd_en ||o_rtc_cxtmgt_cmd_rd_en || o_rrc_cxtmgt_cmd_rd_en || o_ee_cxtmgt_cmd_rd_en || o_fe_cxtmgt_cmd_rd_en)) begin
            qv_selected_channel <= `TD  selected_channel[6:0];
            receive_req <= `TD  1;
        end
        /*Action = Modify*/
        else if ((fsm_cs == DATA_WR) || (fsm_cs == RESP_OUT)) begin
            qv_selected_channel <= `TD  qv_selected_channel;
            receive_req <= `TD  0;
        end
        else begin
            qv_selected_channel <= `TD  0;
            receive_req <= `TD  0;
        end
    end          
    /*Spyglass*/  
    //wire selected_resp_cmd_fifo_prog_full;
    // assign selected_resp_cmd_fifo_prog_full = 
    //                         (qv_selected_channel[1]) ? i_db_cxtmgt_resp_prog_full :
    //                         (qv_selected_channel[2]) ? i_wp_cxtmgt_resp_prog_full :
    //                         (qv_selected_channel[3]) ? i_rtc_cxtmgt_resp_prog_full :
    //                         (qv_selected_channel[4]) ? i_rrc_cxtmgt_resp_prog_full :
    //                         (qv_selected_channel[5]) ? i_ee_cxtmgt_resp_prog_full : 1;    
    assign selected_resp_cmd_fifo_prog_full = 
        ((qv_selected_channel[1] && ((fsm_cs == RESP_OUT) || (fsm_cs == DATA_WR))) || (selected_channel[1] && (fsm_cs == RD_REQ))) ? i_db_cxtmgt_resp_prog_full :
        ((qv_selected_channel[2] && ((fsm_cs == RESP_OUT) || (fsm_cs == DATA_WR))) || (selected_channel[2] && (fsm_cs == RD_REQ))) ? i_wp_cxtmgt_resp_prog_full :
        ((qv_selected_channel[3] && ((fsm_cs == RESP_OUT) || (fsm_cs == DATA_WR))) || (selected_channel[3] && (fsm_cs == RD_REQ))) ? i_rtc_cxtmgt_resp_prog_full :
        ((qv_selected_channel[4] && ((fsm_cs == RESP_OUT) || (fsm_cs == DATA_WR))) || (selected_channel[4] && (fsm_cs == RD_REQ))) ? i_rrc_cxtmgt_resp_prog_full :
        ((qv_selected_channel[5] && ((fsm_cs == RESP_OUT) || (fsm_cs == DATA_WR))) || (selected_channel[5] && (fsm_cs == RD_REQ))) ? i_ee_cxtmgt_resp_prog_full :
        ((qv_selected_channel[6] && ((fsm_cs == RESP_OUT) || (fsm_cs == DATA_WR))) || (selected_channel[6] && (fsm_cs == RD_REQ))) ? i_fe_cxtmgt_resp_prog_full : 1'b1;      
    //wire selected_resp_ctx_fifo_prog_full;
    // assign selected_resp_ctx_fifo_prog_full = 
    //                         (qv_selected_channel[1]) ? i_db_cxtmgt_resp_cxt_prog_full :
    //                         (qv_selected_channel[2]) ? i_wp_cxtmgt_resp_cxt_prog_full :
    //                         (qv_selected_channel[3]) ? i_rtc_cxtmgt_resp_cxt_prog_full  :
    //                         (qv_selected_channel[4]) ? i_rrc_cxtmgt_resp_cxt_prog_full  :
    //                         (qv_selected_channel[5]) ? i_ee_cxtmgt_resp_cxt_prog_full : 1;
    assign selected_resp_ctx_fifo_prog_full = 
     ((qv_selected_channel[1] && ((fsm_cs == RESP_OUT) || (fsm_cs == DATA_WR)))||(selected_channel[1] && (fsm_cs == RD_REQ))) ? i_db_cxtmgt_resp_cxt_prog_full  :
     ((qv_selected_channel[2] && ((fsm_cs == RESP_OUT) || (fsm_cs == DATA_WR)))||(selected_channel[2] && (fsm_cs == RD_REQ))) ? i_wp_cxtmgt_resp_cxt_prog_full  :
     ((qv_selected_channel[3] && ((fsm_cs == RESP_OUT) || (fsm_cs == DATA_WR)))||(selected_channel[3] && (fsm_cs == RD_REQ))) ? i_rtc_cxtmgt_resp_cxt_prog_full :
     ((qv_selected_channel[4] && ((fsm_cs == RESP_OUT) || (fsm_cs == DATA_WR)))||(selected_channel[4] && (fsm_cs == RD_REQ))) ? i_rrc_cxtmgt_resp_cxt_prog_full :
     ((qv_selected_channel[5] && ((fsm_cs == RESP_OUT) || (fsm_cs == DATA_WR)))||(selected_channel[5] && (fsm_cs == RD_REQ))) ? i_ee_cxtmgt_resp_cxt_prog_full  :
     ((qv_selected_channel[6] && ((fsm_cs == RESP_OUT) || (fsm_cs == DATA_WR)))||(selected_channel[6] && (fsm_cs == RD_REQ))) ? i_fe_cxtmgt_resp_cxt_prog_full  : 1'b1; 
    /*Action = Modify*/                    
    
    /*Spyglass*/
    //reg [1:0] qv_read_ram_cnt;// count for ram read times: read qp ram data occupis 1 clk, read cq ram data occupis 2 clk.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_read_ram_cnt <= `TD 2'b0;
        end
        else begin
            case (fsm_cs)
                RD_REQ: begin
                    //read key context data; initiate resp msg and ctxmdata req
                    if (selected_channel[7] && !selected_channel[0] && ((wv_selected_req_type == `RD_QP_CTX) || (wv_selected_req_type  == `RD_CQ_CTX)) && !selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                        qv_read_ram_cnt <= `TD 2'b01;
                    end
                    else begin
                        qv_read_ram_cnt <= `TD 2'b0;
                    end
                end
                DATA_WR: begin
                    qv_read_ram_cnt <= `TD 2'b0;
                end
                RESP_OUT: begin
                    //(1) RDMA engine submodule write key context data: resp cmd & ctxmdata req
                    //(2) RDMA engine submodule read  key context data: resp cmd & resp ctx (read qp data 1 clk, read cq data 2 clk)
                    if ((has_mdt_req && !key_ctx_req_mdt_prog_full && !selected_resp_cmd_fifo_prog_full && no_resp_ctx_data) || (no_mdt_req && !selected_resp_cmd_fifo_prog_full && has_resp_ctx_data && !selected_resp_ctx_fifo_prog_full && ((only_lookup_qp_info && (qv_read_ram_cnt == 2'b01)) || (lookup_cq_info && (qv_read_ram_cnt == 2'b11))))) begin
                        qv_read_ram_cnt <= `TD 2'b0;
                    end
                    else if (lookup_cq_info && (qv_read_ram_cnt < 2'b11) && !selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                        qv_read_ram_cnt <= `TD qv_read_ram_cnt + 1;
                    end
                    else begin
                        qv_read_ram_cnt <= `TD qv_read_ram_cnt;
                    end
                end                
                default: begin
                    qv_read_ram_cnt <= `TD 2'b0;
                end
            endcase
        end
    end
    //reg [127:0] qv_tmp_ctx_payload;//RDMA engine write payload reg for context metadata req
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_tmp_ctx_payload <= `TD 128'b0;
        end else begin
            case ({fsm_cs,wv_req_reg_type,wv_req_reg_op})
                {DATA_WR,`WR_QP_CTX,`WR_QP_NPST}: begin
                    qv_tmp_ctx_payload <= `TD iv_rtc_cxtmgt_cxt_data;
                end
                {DATA_WR,`WR_QP_CTX,`WR_QP_UAPST}: begin
                    qv_tmp_ctx_payload <= `TD iv_rrc_cxtmgt_cxt_data;
                end
                {DATA_WR,`WR_QP_CTX,`WR_QP_EPST}: begin
                    qv_tmp_ctx_payload <= `TD iv_ee_cxtmgt_cxt_data;
                end
                {RESP_OUT,`WR_QP_CTX,`WR_QP_NPST}: begin
                    qv_tmp_ctx_payload <= `TD qv_tmp_ctx_payload;
                end
                {RESP_OUT,`WR_QP_CTX,`WR_QP_UAPST}: begin
                    qv_tmp_ctx_payload <= `TD qv_tmp_ctx_payload;
                end
                {RESP_OUT,`WR_QP_CTX,`WR_QP_EPST}: begin
                    qv_tmp_ctx_payload <= `TD qv_tmp_ctx_payload;
                end
                default: begin
                    qv_tmp_ctx_payload <= `TD 128'b0;
                end
            endcase
        end
    end
    /*Action = Add*/
    /*Spyglass*/                            
    //key context data bram groups operation
    //Key QP context regs
    //qp_state bram 4 width 16384 depth 
        //reg               qp_state_en; 
        //reg               qp_state_wr_en;
        //reg    [INDEX-1 :0]   qp_state_addr;
        //reg    [3 : 0]    qp_state_wr_data;
        //wire   [3 : 0]    qp_state_rd_data;
    always @(*) begin
        if (rst) begin
            qp_state_en = 1'b0; 
            qp_state_wr_en = 1'b0;
            qp_state_addr = 14'b0;
            qp_state_wr_data = 4'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_state_en = 1'b1; 
                            qp_state_wr_en = 1'b1;
                            qp_state_addr = wv_req_reg_qpn;
                            qp_state_wr_data = ceu_wr_data_dout1[32*12-1:32*12-4];
                        end        
                        {`WR_QP_CTX,`WR_QP_NPST}:begin
                            qp_state_en = 1'b1; 
                            qp_state_wr_en = 1'b1;
                            qp_state_addr = wv_req_reg_qpn;
                            qp_state_wr_data = {1'b0,iv_rtc_cxtmgt_cxt_data[2:0]};
                        end
                        {`WR_QP_CTX,`WR_QP_UAPST}:begin
                            qp_state_en = 1'b1; 
                            qp_state_wr_en = 1'b1;
                            qp_state_addr = wv_req_reg_qpn;
                            qp_state_wr_data = {1'b0,iv_rrc_cxtmgt_cxt_data[2:0]};
                        end
                        {`WR_QP_CTX,`WR_QP_EPST}:begin
                            qp_state_en = 1'b1; 
                            qp_state_wr_en = 1'b1;
                            qp_state_addr = wv_req_reg_qpn;
                            qp_state_wr_data = {1'b0,iv_ee_cxtmgt_cxt_data[2:0]};
                        end
                        default: begin
                            qp_state_en = 1'b0; 
                            qp_state_wr_en = 1'b0;
                            qp_state_addr = 14'b0;
                            qp_state_wr_data = 4'b0;
                        end
                    endcase
                end
                RD_REQ: begin
                    case ({wv_selected_req_type,wv_selected_req_op})
                        //WQE Parser req has resp ctx: QP state
                        {`RD_QP_CTX,`RD_QP_STATE}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_state_en = 1'b1; 
                                qp_state_wr_en = 1'b0;
                                qp_state_addr = wv_selected_req_qpn;
                                qp_state_wr_data = 4'b0;
                            end else begin
                                qp_state_en = 1'b0; 
                                qp_state_wr_en = 1'b0;
                                qp_state_addr = 14'b0;
                                qp_state_wr_data = 4'b0;
                            end
                        end
                        default: begin
                            qp_state_en = 1'b0; 
                            qp_state_wr_en = 1'b0;
                            qp_state_addr = 14'b0;
                            qp_state_wr_data = 4'b0;
                        end
                    endcase
                end
                RESP_OUT: begin
                    case ({wv_req_reg_type,wv_req_reg_op})        
                        //RTC req has resp ctx: NextPSN & QP state
                        {`RD_QP_CTX,`RD_QP_NPST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_state_en = 1'b1; 
                                qp_state_wr_en = 1'b0;
                                qp_state_addr = wv_req_reg_qpn;
                                qp_state_wr_data = 4'b0;
                            end else begin
                                qp_state_en = 1'b0; 
                                qp_state_wr_en = 1'b0;
                                qp_state_addr = 14'b0;
                                qp_state_wr_data = 4'b0;
                            end
                        end
                        //Execution Engine req has resp ctx: Pkey、PMTU、PD、Lkey、Expected PSN、RNR Timer、QP State;
                        {`RD_QP_CTX,`RD_QP_RST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_state_en = 1'b1; 
                                qp_state_wr_en = 1'b0;
                                qp_state_addr = wv_req_reg_qpn;
                                qp_state_wr_data = 4'b0;
                            end else begin
                                qp_state_en = 1'b0; 
                                qp_state_wr_en = 1'b0;
                                qp_state_addr = 14'b0;
                                qp_state_wr_data = 4'b0;
                            end
                        end
                        //RRC req has resp ctx:PD、CQ_Lkey、NextPSN、UnAckedPSN、QP State
                        {`RD_CQ_CTX,`RD_CQ_CST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_state_en = 1'b1; 
                                qp_state_wr_en = 1'b0;
                                qp_state_addr = wv_req_reg_qpn;
                                qp_state_wr_data = 4'b0;
                            end else begin
                                qp_state_en = 1'b0; 
                                qp_state_wr_en = 1'b0;
                                qp_state_addr = 14'b0;
                                qp_state_wr_data = 4'b0;
                            end
                        end 
                        default: begin
                            qp_state_en = 1'b0; 
                            qp_state_wr_en = 1'b0;
                            qp_state_addr = 14'b0;
                            qp_state_wr_data = 4'b0;
                        end
                    endcase
                end
                default: begin
                    qp_state_en = 1'b0; 
                    qp_state_wr_en = 1'b0;
                    qp_state_addr = 14'b0;
                    qp_state_wr_data = 4'b0;
                end
            endcase
        end
    end
    //qp_serv_type bram 8 width 16384 depth  
        //reg               qp_serv_tpye_en; 
        //reg               qp_serv_tpye_wr_en;
        //reg    [INDEX-1 :0]   qp_serv_tpye_addr;
        //reg    [7 : 0]    qp_serv_tpye_wr_data;
        //wire   [7 : 0]    qp_serv_tpye_rd_data;
    always @(*) begin
        if (rst) begin
            qp_serv_tpye_en      = 1'b0; 
            qp_serv_tpye_wr_en   = 1'b0;
            qp_serv_tpye_addr    = 14'b0;
            qp_serv_tpye_wr_data = 8'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_serv_tpye_en      = 1'b1; 
                            qp_serv_tpye_wr_en   = 1'b1; 
                            qp_serv_tpye_addr    = wv_req_reg_qpn;
                            qp_serv_tpye_wr_data = ceu_wr_data_dout1[32*12-1-8:32*12-16];
                        end        
                        default: begin
                            qp_serv_tpye_en      = 1'b0; 
                            qp_serv_tpye_wr_en   = 1'b0;
                            qp_serv_tpye_addr    = 14'b0;
                            qp_serv_tpye_wr_data = 8'b0;
                        end
                    endcase
                end
                RD_REQ: begin
                    case ({wv_selected_req_type,wv_selected_req_op})
                        //Doorbell Processing req has resp ctx:PD, Lkey, Pkey, PMTU, Service Type, DestQPN
                        {`RD_QP_CTX,`RD_QP_SST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_serv_tpye_en      = 1'b1; 
                                qp_serv_tpye_wr_en   = 1'b0;
                                qp_serv_tpye_addr    = wv_selected_req_qpn;
                                qp_serv_tpye_wr_data = 8'b0;
                            end else begin
                                qp_serv_tpye_en      = 1'b0; 
                                qp_serv_tpye_wr_en   = 1'b0;
                                qp_serv_tpye_addr    = 14'b0;
                                qp_serv_tpye_wr_data = 8'b0;
                            end
                        end
                        default: begin
                            qp_serv_tpye_en      = 1'b0; 
                            qp_serv_tpye_wr_en   = 1'b0;
                            qp_serv_tpye_addr    = 14'b0;
                            qp_serv_tpye_wr_data = 8'b0;
                        end
                    endcase
                end
                default: begin
                    qp_serv_tpye_en      = 1'b0; 
                    qp_serv_tpye_wr_en   = 1'b0;
                    qp_serv_tpye_addr    = 14'b0;
                    qp_serv_tpye_wr_data = 8'b0;
                end
            endcase
        end
    end
    //qp_mtu bram 8 width 16384 depth  
        //reg               qp_mtu_en; 
        //reg               qp_mtu_wr_en;
        //reg    [INDEX-1 :0]   qp_mtu_addr;
        //reg    [7 : 0]    qp_mtu_wr_data;
        //wire   [7 : 0]    qp_mtu_rd_data;  
    always @(*) begin
        qp_mtu_en      = 1'b0; 
        qp_mtu_wr_en   = 1'b0;
        qp_mtu_addr    = 14'b0;
        qp_mtu_wr_data = 8'b0;
        if (rst) begin
            qp_mtu_en      = 1'b0; 
            qp_mtu_wr_en   = 1'b0;
            qp_mtu_addr    = 14'b0;
            qp_mtu_wr_data = 8'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_mtu_en      = 1'b1; 
                            qp_mtu_wr_en   = 1'b1; 
                            qp_mtu_addr    = wv_req_reg_qpn;
                            qp_mtu_wr_data = ceu_wr_data_dout1[32*12-1-16:32*12-24];
                        end        
                        default: begin
                            qp_mtu_en      = 1'b0; 
                            qp_mtu_wr_en   = 1'b0;
                            qp_mtu_addr    = 14'b0;
                            qp_mtu_wr_data = 8'b0;
                        end
                    endcase
                end
                RD_REQ: begin
                    case ({wv_selected_req_type,wv_selected_req_op})
                        //Doorbell Processing req has resp ctx:PD, Lkey, Pkey, PMTU, Service Type, DestQPN
                        {`RD_QP_CTX,`RD_QP_SST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_mtu_en      = 1'b1; 
                                qp_mtu_wr_en   = 1'b0;
                                qp_mtu_addr    = wv_selected_req_qpn;
                                qp_mtu_wr_data = 8'b0;
                            end else begin
                                qp_mtu_en      = 1'b0; 
                                qp_mtu_wr_en   = 1'b0;
                                qp_mtu_addr    = 14'b0;
                                qp_mtu_wr_data = 8'b0;
                            end
                        end
                    endcase
                end
                RESP_OUT: begin
                    case ({wv_req_reg_type,wv_req_reg_op})     
                        //Execution Engine req has resp ctx: Pkey、PMTU、PD、Lkey、Expected PSN、RNR Timer、QP State;
                        {`RD_QP_CTX,`RD_QP_RST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_mtu_en      = 1'b1; 
                                qp_mtu_wr_en   = 1'b0;
                                qp_mtu_addr    = wv_req_reg_qpn;
                                qp_mtu_wr_data = 8'b0;
                            end else begin
                                qp_mtu_en      = 1'b0; 
                                qp_mtu_wr_en   = 1'b0;
                                qp_mtu_addr    = 14'b0;
                                qp_mtu_wr_data = 8'b0;
                            end
                        end
                        default: begin
                            qp_mtu_en      = 1'b0; 
                            qp_mtu_wr_en   = 1'b0;
                            qp_mtu_addr    = 14'b0;
                            qp_mtu_wr_data = 8'b0;
                        end   
                    endcase
                end
                default: begin
                    qp_mtu_en      = 1'b0; 
                    qp_mtu_wr_en   = 1'b0;
                    qp_mtu_addr    = 14'b0;
                    qp_mtu_wr_data = 8'b0;
                end
            endcase
        end
    end    
    //qp_rnr_retry bram 8 width 16384 depth  
        //reg               qp_rnr_retry_en; 
        //reg               qp_rnr_retry_wr_en;
        //reg    [INDEX-1 :0]   qp_rnr_retry_addr;
        //reg    [7 : 0]    qp_rnr_retry_wr_data;
        //wire   [7 : 0]    qp_rnr_retry_rd_data;
    always @(*) begin
        if (rst) begin
            qp_rnr_retry_en      = 1'b0;
            qp_rnr_retry_wr_en   = 1'b0;
            qp_rnr_retry_addr    = 14'b0;
            qp_rnr_retry_wr_data = 8'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_rnr_retry_en      = 1'b1; 
                            qp_rnr_retry_wr_en   = 1'b1; 
                            qp_rnr_retry_addr    = wv_req_reg_qpn;
                            qp_rnr_retry_wr_data = ceu_wr_data_dout1[32*11+7:32*11];
                        end        
                        default: begin
                            qp_rnr_retry_en      = 1'b0;
                            qp_rnr_retry_wr_en   = 1'b0;
                            qp_rnr_retry_addr    = 14'b0;
                            qp_rnr_retry_wr_data = 8'b0;
                        end
                    endcase
                end
                RESP_OUT: begin
                    case ({wv_req_reg_type,wv_req_reg_op}) 
                        //Execution Engine req has resp ctx: Pkey、PMTU、PD、Lkey、Expected PSN、RNR Timer、QP State;
                        {`RD_QP_CTX,`RD_QP_RST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_rnr_retry_en      = 1'b1; 
                                qp_rnr_retry_wr_en   = 1'b0;
                                qp_rnr_retry_addr    = wv_req_reg_qpn;
                                qp_rnr_retry_wr_data = 8'b0;
                            end else begin
                                qp_rnr_retry_en      = 1'b0; 
                                qp_rnr_retry_wr_en   = 1'b0;
                                qp_rnr_retry_addr    = 14'b0;
                                qp_rnr_retry_wr_data = 8'b0;
                            end
                        end
                        default: begin
                            qp_rnr_retry_en      = 1'b0; 
                            qp_rnr_retry_wr_en   = 1'b0;
                            qp_rnr_retry_addr    = 14'b0;
                            qp_rnr_retry_wr_data = 8'b0;
                        end
                    endcase
                end
                default: begin
                    qp_rnr_retry_en      = 1'b0; 
                    qp_rnr_retry_wr_en   = 1'b0;
                    qp_rnr_retry_addr    = 14'b0;
                    qp_rnr_retry_wr_data = 8'b0;
                end
            endcase
        end
    end
    //qp_local_qpn bram 32 width 16384 depth 
        //reg               qp_local_qpn_en; 
        //reg               qp_local_qpn_wr_en;
        //reg    [INDEX-1 :0]   qp_local_qpn_addr;
        //reg    [31 : 0]   qp_local_qpn_wr_data;
        //wire   [31 : 0]   qp_local_qpn_rd_data;
    always @(*) begin
        if (rst) begin
            qp_local_qpn_en      = 1'b0;
            qp_local_qpn_wr_en   = 1'b0;
            qp_local_qpn_addr    = 14'b0;
            qp_local_qpn_wr_data = 32'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_local_qpn_en      = 1'b1; 
                            qp_local_qpn_wr_en   = 1'b1; 
                            qp_local_qpn_addr    = wv_req_reg_qpn;
                            qp_local_qpn_wr_data = ceu_wr_data_dout1[32*11-1:32*10];
                        end        
                        default: begin
                            qp_local_qpn_en      = 1'b0;
                            qp_local_qpn_wr_en   = 1'b0;
                            qp_local_qpn_addr    = 14'b0;
                            qp_local_qpn_wr_data = 8'b0;
                        end
                    endcase
                end
                default: begin
                    qp_local_qpn_en      = 1'b0; 
                    qp_local_qpn_wr_en   = 1'b0;
                    qp_local_qpn_addr    = 14'b0;
                    qp_local_qpn_wr_data = 8'b0;
                end
            endcase
        end
    end    
    //qp_remote_qpn bram 32 width 16384 depth
        //reg               qp_remote_qpn_en; 
        //reg               qp_remote_qpn_wr_en;
        //reg    [INDEX-1 :0]   qp_remote_qpn_addr;
        //reg    [31 : 0]   qp_remote_qpn_wr_data;
        //wire   [31 : 0]   qp_remote_qpn_rd_data;
    always @(*) begin
        if (rst) begin
            qp_remote_qpn_en      = 1'b0;
            qp_remote_qpn_wr_en   = 1'b0;
            qp_remote_qpn_addr    = 14'b0;
            qp_remote_qpn_wr_data = 32'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_remote_qpn_en      = 1'b1; 
                            qp_remote_qpn_wr_en   = 1'b1; 
                            qp_remote_qpn_addr    = wv_req_reg_qpn;
                            qp_remote_qpn_wr_data = ceu_wr_data_dout1[32*10-1:32*9];
                        end        
                        default: begin
                            qp_remote_qpn_en      = 1'b0;
                            qp_remote_qpn_wr_en   = 1'b0;
                            qp_remote_qpn_addr    = 14'b0;
                            qp_remote_qpn_wr_data = 32'b0;
                        end
                    endcase
                end
                RD_REQ: begin
                    case ({wv_selected_req_type,wv_selected_req_op})
                        //Doorbell Processing req has resp ctx:PD, Lkey, Pkey, PMTU, Service Type, DestQPN
                        {`RD_QP_CTX,`RD_QP_SST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_remote_qpn_en      = 1'b1; 
                                qp_remote_qpn_wr_en   = 1'b0;
                                qp_remote_qpn_addr    = wv_selected_req_qpn;
                                qp_remote_qpn_wr_data = 32'b0;
                            end else begin
                                qp_remote_qpn_en      = 1'b0;
                                qp_remote_qpn_wr_en   = 1'b0;
                                qp_remote_qpn_addr    = 14'b0;
                                qp_remote_qpn_wr_data = 32'b0;
                            end
                        end
                        
                        default: begin
                            qp_remote_qpn_en      = 1'b0;
                            qp_remote_qpn_wr_en   = 1'b0;
                            qp_remote_qpn_addr    = 14'b0;
                            qp_remote_qpn_wr_data = 32'b0;
                        end
                    endcase
                end
                RESP_OUT: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        //EE
                        {`RD_QP_CTX,`RD_QP_RST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_remote_qpn_en      = 1'b1; 
                                qp_remote_qpn_wr_en   = 1'b0;
                                qp_remote_qpn_addr    = wv_req_reg_qpn;
                                qp_remote_qpn_wr_data = 32'b0;
                            end else begin
                                qp_remote_qpn_en      = 1'b0;
                                qp_remote_qpn_wr_en   = 1'b0;
                                qp_remote_qpn_addr    = 14'b0;
                                qp_remote_qpn_wr_data = 32'b0;
                            end
                        end
                        //RRC
                        {`RD_CQ_CTX,`RD_CQ_CST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_remote_qpn_en      = 1'b1; 
                                qp_remote_qpn_wr_en   = 1'b0;
                                qp_remote_qpn_addr    = wv_req_reg_qpn;
                                qp_remote_qpn_wr_data = 32'b0;
                            end else begin
                                qp_remote_qpn_en      = 1'b0;
                                qp_remote_qpn_wr_en   = 1'b0;
                                qp_remote_qpn_addr    = 14'b0;
                                qp_remote_qpn_wr_data = 32'b0;
                            end
                        end
                    default: begin
                            qp_remote_qpn_en      = 1'b0;
                            qp_remote_qpn_wr_en   = 1'b0;
                            qp_remote_qpn_addr    = 14'b0;
                            qp_remote_qpn_wr_data = 32'b0;
                        end
                    endcase
                end
                default: begin
                    qp_remote_qpn_en      = 1'b0;
                    qp_remote_qpn_wr_en   = 1'b0;
                    qp_remote_qpn_addr    = 14'b0;
                    qp_remote_qpn_wr_data = 32'b0;
                end
            endcase
        end
    end    
    //qp_port_key bram 32 width 16384 depth
        //reg               qp_port_key_en; 
        //reg               qp_port_key_wr_en;
        //reg    [INDEX-1 :0]   qp_port_key_addr;
        //reg    [31 : 0]   qp_port_key_wr_data;
        //wire   [31 : 0]   qp_port_key_rd_data;
    always @(*) begin
        if (rst) begin
            qp_port_key_en      = 1'b0;
            qp_port_key_wr_en   = 1'b0;
            qp_port_key_addr    = 14'b0;
            qp_port_key_wr_data = 32'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_port_key_en      = 1'b1; 
                            qp_port_key_wr_en   = 1'b1; 
                            qp_port_key_addr    = wv_req_reg_qpn;
                            qp_port_key_wr_data = ceu_wr_data_dout1[32*9-1:32*8];
                        end        
                        default: begin
                            qp_port_key_en      = 1'b0;
                            qp_port_key_wr_en   = 1'b0;
                            qp_port_key_addr    = 14'b0;
                            qp_port_key_wr_data = 32'b0;
                        end
                    endcase
                end
                RD_REQ: begin
                    case ({wv_selected_req_type,wv_selected_req_op})
                        //Doorbell Processing req has resp ctx:PD, Lkey, Pkey, PMTU, Service Type, DestQPN
                        {`RD_QP_CTX,`RD_QP_SST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_port_key_en      = 1'b1; 
                                qp_port_key_wr_en   = 1'b0;
                                qp_port_key_addr    = wv_selected_req_qpn;
                                qp_port_key_wr_data = 32'b0;
                            end else begin
                                qp_port_key_en      = 1'b0;
                                qp_port_key_wr_en   = 1'b0;
                                qp_port_key_addr    = 14'b0;
                                qp_port_key_wr_data = 32'b0;
                            end
                        end
                        //FrameEncap req has resp ctx: Pkey,port number;
                        {`RD_QP_CTX,`RD_ENCAP}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_port_key_en      = 1'b1; 
                                qp_port_key_wr_en   = 1'b0;
                                qp_port_key_addr    = wv_selected_req_qpn;
                                qp_port_key_wr_data = 32'b0;
                            end else begin
                                qp_port_key_en      = 1'b0;
                                qp_port_key_wr_en   = 1'b0;
                                qp_port_key_addr    = 14'b0;
                                qp_port_key_wr_data = 32'b0;
                            end
                        end
                        default: begin
                            qp_port_key_en      = 1'b0;
                            qp_port_key_wr_en   = 1'b0;
                            qp_port_key_addr    = 14'b0;
                            qp_port_key_wr_data = 32'b0;
                        end
                    endcase
                end
                RESP_OUT: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        //Execution Engine req has resp ctx: Pkey、PMTU、PD、Lkey、Expected PSN、RNR Timer、QP State;
                        {`RD_QP_CTX,`RD_QP_RST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_port_key_en      = 1'b1; 
                                qp_port_key_wr_en   = 1'b0;
                                qp_port_key_addr    = wv_req_reg_qpn;
                                qp_port_key_wr_data = 32'b0;
                            end else begin
                                qp_port_key_en      = 1'b0;
                                qp_port_key_wr_en   = 1'b0;
                                qp_port_key_addr    = 14'b0;
                                qp_port_key_wr_data = 32'b0;
                            end
                        end
                        default: begin
                            qp_port_key_en      = 1'b0;
                            qp_port_key_wr_en   = 1'b0;
                            qp_port_key_addr    = 14'b0;
                            qp_port_key_wr_data = 32'b0;
                        end
                    endcase
                end
                default: begin
                    qp_port_key_en      = 1'b0;
                    qp_port_key_wr_en   = 1'b0;
                    qp_port_key_addr    = 14'b0;
                    qp_port_key_wr_data = 32'b0;
                end
            endcase
        end
    end    
    //qp_pd bram 32 width 16384 depth
        //reg               qp_pd_en; 
        //reg               qp_pd_wr_en;
        //reg    [INDEX-1 :0]   qp_pd_addr;
        //reg    [31 : 0]   qp_pd_wr_data;
        //wire   [31 : 0]   qp_pd_rd_data;
    always @(*) begin
        if (rst) begin
            qp_pd_en      = 1'b0;
            qp_pd_wr_en   = 1'b0;
            qp_pd_addr    = 14'b0;
            qp_pd_wr_data = 32'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_pd_en      = 1'b1; 
                            qp_pd_wr_en   = 1'b1; 
                            qp_pd_addr    = wv_req_reg_qpn;
                            qp_pd_wr_data = ceu_wr_data_dout1[32*8-1:32*7];
                        end        
                        default: begin
                             qp_pd_en      = 1'b0;
                             qp_pd_wr_en   = 1'b0;
                             qp_pd_addr    = 14'b0;
                             qp_pd_wr_data = 32'b0;
                        end
                    endcase
                end
                RD_REQ: begin
                    case ({wv_selected_req_type,wv_selected_req_op})
                        //Doorbell Processing req has resp ctx:PD, Lkey, Pkey, PMTU, Service Type, DestQPN
                        {`RD_QP_CTX,`RD_QP_SST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_pd_en      = 1'b1; 
                                qp_pd_wr_en   = 1'b0;
                                qp_pd_addr    = wv_selected_req_qpn;
                                qp_pd_wr_data = 32'b0;
                            end else begin
                                qp_pd_en      = 1'b0;
                                qp_pd_wr_en   = 1'b0;
                                qp_pd_addr    = 14'b0;
                                qp_pd_wr_data = 32'b0;
                            end
                        end
                        default: begin
                            qp_pd_en      = 1'b0;
                            qp_pd_wr_en   = 1'b0;
                            qp_pd_addr    = 14'b0;
                            qp_pd_wr_data = 32'b0;
                        end
                    endcase
                end
                RESP_OUT: begin
                    case ({wv_req_reg_type,wv_req_reg_op})      
                        //RRC req has resp ctx:PD、CQ_Lkey、NextPSN、UnAckedPSN、QP State
                        {`RD_CQ_CTX,`RD_CQ_CST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_pd_en      = 1'b1; 
                                qp_pd_wr_en   = 1'b0;
                                qp_pd_addr    = wv_req_reg_qpn;
                                qp_pd_wr_data = 32'b0;
                            end else begin
                                qp_pd_en      = 1'b0;
                                qp_pd_wr_en   = 1'b0;
                                qp_pd_addr    = 14'b0;
                                qp_pd_wr_data = 32'b0;
                            end
                        end
                        //Execution Engine req has resp ctx: Pkey、PMTU、PD、Lkey、Expected PSN、RNR Timer、QP State;
                        {`RD_QP_CTX,`RD_QP_RST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_pd_en      = 1'b1; 
                                qp_pd_wr_en   = 1'b0;
                                qp_pd_addr    = wv_req_reg_qpn;
                                qp_pd_wr_data = 32'b0;
                            end else begin
                                qp_pd_en      = 1'b0;
                                qp_pd_wr_en   = 1'b0;
                                qp_pd_addr    = 14'b0;
                                qp_pd_wr_data = 32'b0;
                            end
                        end
                        default: begin
                            qp_pd_en      = 1'b0;
                            qp_pd_wr_en   = 1'b0;
                            qp_pd_addr    = 14'b0;
                            qp_pd_wr_data = 32'b0;
                        end
                    endcase
                end
                default: begin
                    qp_pd_en      = 1'b0;
                    qp_pd_wr_en   = 1'b0;
                    qp_pd_addr    = 14'b0;
                    qp_pd_wr_data = 32'b0;
                end
            endcase
        end
    end  
    //qp_sl_tclass bram 32 width 16384 depth 
        //reg               qp_sl_tclass_en; 
        //reg               qp_sl_tclass_wr_en;
        //reg    [INDEX-1 :0]   qp_sl_tclass_addr;
        //reg    [31 : 0]   qp_sl_tclass_wr_data;
        //wire   [31 : 0]   qp_sl_tclass_rd_data;
    always @(*) begin
        if (rst) begin
            qp_sl_tclass_en      = 1'b0;
            qp_sl_tclass_wr_en   = 1'b0;
            qp_sl_tclass_addr    = 14'b0;
            qp_sl_tclass_wr_data = 32'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_sl_tclass_en      = 1'b1; 
                            qp_sl_tclass_wr_en   = 1'b1; 
                            qp_sl_tclass_addr    = wv_req_reg_qpn;
                            qp_sl_tclass_wr_data = ceu_wr_data_dout1[32*7-1:32*6];
                        end        
                        default: begin
                            qp_sl_tclass_en      = 1'b0;
                            qp_sl_tclass_wr_en   = 1'b0;
                            qp_sl_tclass_addr    = 14'b0;
                            qp_sl_tclass_wr_data = 32'b0;
                        end
                    endcase
                end
                RD_REQ: begin
                    case ({wv_selected_req_type,wv_selected_req_op})
                        //FrameEncap req has resp ctx: Pkey,port number,qp_sl_tclass
                        {`RD_QP_CTX,`RD_ENCAP}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_sl_tclass_en      = 1'b1; 
                                qp_sl_tclass_wr_en   = 1'b0;
                                qp_sl_tclass_addr    = wv_selected_req_qpn;
                                qp_sl_tclass_wr_data = 32'b0;
                            end else begin
                                qp_sl_tclass_en      = 1'b0;
                                qp_sl_tclass_wr_en   = 1'b0;
                                qp_sl_tclass_addr    = 14'b0;
                                qp_sl_tclass_wr_data = 32'b0;
                            end
                        end
                        default: begin
                            qp_sl_tclass_en      = 1'b0;
                            qp_sl_tclass_wr_en   = 1'b0;
                            qp_sl_tclass_addr    = 14'b0;
                            qp_sl_tclass_wr_data = 32'b0;
                        end
                    endcase
                end
                default: begin
                    qp_sl_tclass_en      = 1'b0;
                    qp_sl_tclass_wr_en   = 1'b0;
                    qp_sl_tclass_addr    = 14'b0;
                    qp_sl_tclass_wr_data = 32'b0;
                end
            endcase
        end
    end 
    //qp_next_psn bram 32 width 16384 depth 
        //reg               qp_next_psn_en; 
        //reg               qp_next_psn_wr_en;
        //reg    [INDEX-1 :0]   qp_next_psn_addr;
        //reg    [31 : 0]   qp_next_psn_wr_data;
        //wire   [31 : 0]   qp_next_psn_rd_data;
    always @(*) begin
        if (rst) begin
            qp_next_psn_en      = 1'b0;
            qp_next_psn_wr_en   = 1'b0;
            qp_next_psn_addr    = 14'b0;
            qp_next_psn_wr_data = 32'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_next_psn_en      = 1'b1; 
                            qp_next_psn_wr_en   = 1'b1; 
                            qp_next_psn_addr    = wv_req_reg_qpn;
                            qp_next_psn_wr_data = ceu_wr_data_dout1[32*6-1:32*5];
                        end
                        {`WR_QP_CTX,`WR_QP_NPST}:begin
                            qp_next_psn_en      = 1'b1; 
                            qp_next_psn_wr_en   = 1'b1; 
                            qp_next_psn_addr    = wv_req_reg_qpn;
                            qp_next_psn_wr_data = iv_rtc_cxtmgt_cxt_data[31:8];
                        end
                        default: begin
                            qp_next_psn_en      = 1'b0;
                            qp_next_psn_wr_en   = 1'b0;
                            qp_next_psn_addr    = 14'b0;
                            qp_next_psn_wr_data = 32'b0;
                        end
                    endcase
                end                  
                RESP_OUT: begin
                    case ({wv_req_reg_type,wv_req_reg_op})      
                        //RTC req has resp ctx: NextPSN & QP state
                        {`RD_QP_CTX,`RD_QP_NPST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_next_psn_en      = 1'b1; 
                                qp_next_psn_wr_en   = 1'b0;
                                qp_next_psn_addr    = wv_req_reg_qpn;
                                qp_next_psn_wr_data = 32'b0;
                            end else begin
                                qp_next_psn_en      = 1'b0; 
                                qp_next_psn_wr_en   = 1'b0;
                                qp_next_psn_addr    = 14'b0;
                                qp_next_psn_wr_data = 32'b0;
                            end
                        end
                        //RRC req has resp ctx:PD、CQ_Lkey、NextPSN、UnAckedPSN、QP State
                        {`RD_CQ_CTX,`RD_CQ_CST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_next_psn_en      = 1'b1; 
                                qp_next_psn_wr_en   = 1'b0;
                                qp_next_psn_addr    = wv_req_reg_qpn;
                                qp_next_psn_wr_data = 32'b0;
                            end else begin
                                qp_next_psn_en      = 1'b0;
                                qp_next_psn_wr_en   = 1'b0;
                                qp_next_psn_addr    = 14'b0;
                                qp_next_psn_wr_data = 32'b0;
                            end
                        end
                        default: begin
                            qp_next_psn_en      = 1'b0;
                            qp_next_psn_wr_en   = 1'b0;
                            qp_next_psn_addr    = 14'b0;
                            qp_next_psn_wr_data = 32'b0;
                        end
                    endcase
                end
                default: begin
                    qp_next_psn_en      = 1'b0;
                    qp_next_psn_wr_en   = 1'b0;
                    qp_next_psn_addr    = 14'b0;
                    qp_next_psn_wr_data = 32'b0;
                end
            endcase
        end
    end  
    //qp_cqn_send bram 32 width 16384 depth 
        //reg               qp_cqn_send_en; 
        //reg               qp_cqn_send_wr_en;
        //reg    [INDEX-1 :0]   qp_cqn_send_addr;
        //reg    [31 : 0]   qp_cqn_send_wr_data;
        //wire   [31 : 0]   qp_cqn_send_rd_data;
    always @(*) begin
        if (rst) begin
            qp_cqn_send_en      = 1'b0;
            qp_cqn_send_wr_en   = 1'b0;
            qp_cqn_send_addr    = 14'b0;
            qp_cqn_send_wr_data = 32'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_cqn_send_en      = 1'b1; 
                            qp_cqn_send_wr_en   = 1'b1; 
                            qp_cqn_send_addr    = wv_req_reg_qpn;
                            qp_cqn_send_wr_data = ceu_wr_data_dout1[32*5-1:32*4];
                        end        
                        default: begin
                            qp_cqn_send_en      = 1'b0;
                            qp_cqn_send_wr_en   = 1'b0;
                            qp_cqn_send_addr    = 14'b0;
                            qp_cqn_send_wr_data = 32'b0;
                        end
                    endcase
                end
                RD_REQ: begin
                    case ({wv_selected_req_type,wv_selected_req_op})
                        //Doorbell Processing req has resp ctx:PD, Lkey, Pkey, PMTU, Service Type, DestQPN, qp_cqn_send
                        {`RD_QP_CTX,`RD_QP_SST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin 
                                qp_cqn_send_en      = 1'b1; 
                                qp_cqn_send_wr_en   = 1'b0;
                                qp_cqn_send_addr    = wv_selected_req_qpn;
                                qp_cqn_send_wr_data = 32'b0;
                            end else begin
                                qp_cqn_send_en      = 1'b0;
                                qp_cqn_send_wr_en   = 1'b0;
                                qp_cqn_send_addr    = 14'b0;
                                qp_cqn_send_wr_data = 32'b0;
                            end
                        end
                        //RTC req has resp ctx: NextPSN & QP state,qp_cqn_send
                        {`RD_QP_CTX,`RD_QP_NPST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_cqn_send_en      = 1'b1; 
                                qp_cqn_send_wr_en   = 1'b0;
                                qp_cqn_send_addr    = wv_selected_req_qpn;
                                qp_cqn_send_wr_data = 32'b0;
                            end else begin
                                qp_cqn_send_en      = 1'b0;
                                qp_cqn_send_wr_en   = 1'b0;
                                qp_cqn_send_addr    = 14'b0;
                                qp_cqn_send_wr_data = 32'b0;
                            end
                        end
                        //RRC req has resp ctx:PD、CQ_Lkey、NextPSN、UnAckedPSN、QP State, qp_cqn_send
                        {`RD_CQ_CTX,`RD_CQ_CST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_cqn_send_en      = 1'b1; 
                                qp_cqn_send_wr_en   = 1'b0;
                                qp_cqn_send_addr    = wv_selected_req_qpn;
                                qp_cqn_send_wr_data = 32'b0;
                            end else begin
                                qp_cqn_send_en      = 1'b0;
                                qp_cqn_send_wr_en   = 1'b0;
                                qp_cqn_send_addr    = 14'b0;
                                qp_cqn_send_wr_data = 32'b0;
                            end
                        end
                        default: begin
                            qp_cqn_send_en      = 1'b0;
                            qp_cqn_send_wr_en   = 1'b0;
                            qp_cqn_send_addr    = 14'b0;
                            qp_cqn_send_wr_data = 32'b0;
                        end
                    endcase
                end
                RESP_OUT: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        //RTC req has resp ctx: NextPSN & QP state,qp_cqn_send
                        {`RD_QP_CTX,`RD_QP_NPST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_cqn_send_en      = 1'b1; 
                                qp_cqn_send_wr_en   = 1'b0;
                                qp_cqn_send_addr    = wv_req_reg_qpn;
                                qp_cqn_send_wr_data = 32'b0;
                            end else begin
                                qp_cqn_send_en      = 1'b0;
                                qp_cqn_send_wr_en   = 1'b0;
                                qp_cqn_send_addr    = 14'b0;
                                qp_cqn_send_wr_data = 32'b0;
                            end
                        end
                        //RRC req has resp ctx:PD、CQ_Lkey、NextPSN、UnAckedPSN、QP State, qp_cqn_send
                        {`RD_CQ_CTX,`RD_CQ_CST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_cqn_send_en      = 1'b1; 
                                qp_cqn_send_wr_en   = 1'b0;
                                qp_cqn_send_addr    = wv_req_reg_qpn;
                                qp_cqn_send_wr_data = 32'b0;
                            end else begin
                                qp_cqn_send_en      = 1'b0;
                                qp_cqn_send_wr_en   = 1'b0;
                                qp_cqn_send_addr    = 14'b0;
                                qp_cqn_send_wr_data = 32'b0;
                            end
                        end
                        default: begin
                            qp_cqn_send_en      = 1'b0;
                            qp_cqn_send_wr_en   = 1'b0;
                            qp_cqn_send_addr    = 14'b0;
                            qp_cqn_send_wr_data = 32'b0;
                        end
                    endcase
                end
                default: begin
                    qp_cqn_send_en      = 1'b0;
                    qp_cqn_send_wr_en   = 1'b0;
                    qp_cqn_send_addr    = 14'b0;
                    qp_cqn_send_wr_data = 32'b0;
                end
            endcase
        end
    end
    //qp_send_wqe_base_lkey bram 32 width 16384 depth 
        //reg               qp_send_wqe_base_lkey_en; 
        //reg               qp_send_wqe_base_lkey_wr_en;
        //reg    [INDEX-1 :0]   qp_send_wqe_base_lkey_addr;
        //reg    [31 : 0]   qp_send_wqe_base_lkey_wr_data;
        //wire   [31 : 0]   qp_send_wqe_base_lkey_rd_data;
    always @(*) begin
        if (rst) begin
            qp_send_wqe_base_lkey_en      = 1'b0;
            qp_send_wqe_base_lkey_wr_en   = 1'b0;
            qp_send_wqe_base_lkey_addr    = 14'b0;
            qp_send_wqe_base_lkey_wr_data = 32'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_send_wqe_base_lkey_en      = 1'b1; 
                            qp_send_wqe_base_lkey_wr_en   = 1'b1; 
                            qp_send_wqe_base_lkey_addr    = wv_req_reg_qpn;
                            qp_send_wqe_base_lkey_wr_data = ceu_wr_data_dout1[32*4-1:32*3];
                        end        
                        default: begin
                            qp_send_wqe_base_lkey_en      = 1'b0;
                            qp_send_wqe_base_lkey_wr_en   = 1'b0;
                            qp_send_wqe_base_lkey_addr    = 14'b0;
                            qp_send_wqe_base_lkey_wr_data = 32'b0;
                        end
                    endcase
                end
                RD_REQ: begin
                    case ({wv_selected_req_type,wv_selected_req_op})
                        //Doorbell Processing req has resp ctx:PD, qp_send_wqe_base_lkey, Pkey, PMTU, Service Type, DestQPN
                        {`RD_QP_CTX,`RD_QP_SST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_send_wqe_base_lkey_en      = 1'b1; 
                                qp_send_wqe_base_lkey_wr_en   = 1'b0;
                                qp_send_wqe_base_lkey_addr    = wv_selected_req_qpn;
                                qp_send_wqe_base_lkey_wr_data = 32'b0;
                            end else begin
                                qp_send_wqe_base_lkey_en      = 1'b0;
                                qp_send_wqe_base_lkey_wr_en   = 1'b0;
                                qp_send_wqe_base_lkey_addr    = 14'b0;
                                qp_send_wqe_base_lkey_wr_data = 32'b0;
                            end
                        end
                        default: begin
                            qp_send_wqe_base_lkey_en      = 1'b0;
                            qp_send_wqe_base_lkey_wr_en   = 1'b0;
                            qp_send_wqe_base_lkey_addr    = 14'b0;
                            qp_send_wqe_base_lkey_wr_data = 32'b0;
                        end
                    endcase
                end
                default: begin
                    qp_send_wqe_base_lkey_en      = 1'b0;
                    qp_send_wqe_base_lkey_wr_en   = 1'b0;
                    qp_send_wqe_base_lkey_addr    = 14'b0;
                    qp_send_wqe_base_lkey_wr_data = 32'b0;
                end
            endcase
        end
    end 
    //qp_unacked_psn bram 32 width 16384 depth 
        //reg               qp_unacked_psn_en; 
        //reg               qp_unacked_psn_wr_en;
        //reg    [INDEX-1 :0]   qp_unacked_psn_addr;
        //reg    [31 : 0]   qp_unacked_psn_wr_data;
        //wire   [31 : 0]   qp_unacked_psn_rd_data;
    always @(*) begin
        if (rst) begin
            qp_unacked_psn_en      = 1'b0;
            qp_unacked_psn_wr_en   = 1'b0;
            qp_unacked_psn_addr    = 14'b0;
            qp_unacked_psn_wr_data = 32'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_unacked_psn_en      = 1'b1; 
                            qp_unacked_psn_wr_en   = 1'b1; 
                            qp_unacked_psn_addr    = wv_req_reg_qpn;
                            qp_unacked_psn_wr_data = ceu_wr_data_dout1[32*3-1:32*2];
                        end        
                        {`WR_QP_CTX,`WR_QP_UAPST}:begin
                            qp_unacked_psn_en      = 1'b1; 
                            qp_unacked_psn_wr_en   = 1'b1; 
                            qp_unacked_psn_addr    = wv_req_reg_qpn;
                            qp_unacked_psn_wr_data = iv_rrc_cxtmgt_cxt_data[31:8];
                        end
                        default: begin
                            qp_unacked_psn_en      = 1'b0;
                            qp_unacked_psn_wr_en   = 1'b0;
                            qp_unacked_psn_addr    = 14'b0;
                            qp_unacked_psn_wr_data = 32'b0;
                        end
                    endcase
                end
                RESP_OUT: begin
                    case ({wv_req_reg_type,wv_req_reg_op})        
                        //RRC req has resp ctx:PD、CQ_Lkey、NextPSN、UnAckedPSN、QP State
                        {`RD_CQ_CTX,`RD_CQ_CST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_unacked_psn_en      = 1'b1; 
                                qp_unacked_psn_wr_en   = 1'b0;
                                qp_unacked_psn_addr    = wv_req_reg_qpn;
                                qp_unacked_psn_wr_data = 32'b0;
                            end else begin
                                qp_unacked_psn_en      = 1'b0;
                                qp_unacked_psn_wr_en   = 1'b0;
                                qp_unacked_psn_addr    = 14'b0;
                                qp_unacked_psn_wr_data = 32'b0;
                            end
                        end
                        default: begin
                            qp_unacked_psn_en      = 1'b0;
                            qp_unacked_psn_wr_en   = 1'b0;
                            qp_unacked_psn_addr    = 14'b0;
                            qp_unacked_psn_wr_data = 32'b0;
                        end
                    endcase
                end
                default: begin
                    qp_unacked_psn_en      = 1'b0;
                    qp_unacked_psn_wr_en   = 1'b0;
                    qp_unacked_psn_addr    = 14'b0;
                    qp_unacked_psn_wr_data = 32'b0;
                end
            endcase
        end
    end
    //qp_expect_psn bram 32 width 16384 depth 
        //reg               qp_expect_psn_en; 
        //reg               qp_expect_psn_wr_en;
        //reg    [INDEX-1 :0]   qp_expect_psn_addr;
        //reg    [31 : 0]   qp_expect_psn_wr_data;
        //wire   [31 : 0]   qp_expect_psn_rd_data;
    always @(*) begin
        if (rst) begin
            qp_expect_psn_en      = 1'b0;
            qp_expect_psn_wr_en   = 1'b0;
            qp_expect_psn_addr    = 14'b0;
            qp_expect_psn_wr_data = 32'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_expect_psn_en      = 1'b1; 
                            qp_expect_psn_wr_en   = 1'b1; 
                            qp_expect_psn_addr    = wv_req_reg_qpn;
                            qp_expect_psn_wr_data = ceu_wr_data_dout1[32*2-1:32*1];
                        end        
                        {`WR_QP_CTX,`WR_QP_EPST}:begin
                            qp_expect_psn_en      = 1'b1; 
                            qp_expect_psn_wr_en   = 1'b1; 
                            qp_expect_psn_addr    = wv_req_reg_qpn;
                            qp_expect_psn_wr_data = iv_ee_cxtmgt_cxt_data[31:8];
                        end
                        default: begin
                            qp_expect_psn_en      = 1'b0;
                            qp_expect_psn_wr_en   = 1'b0;
                            qp_expect_psn_addr    = 14'b0;
                            qp_expect_psn_wr_data = 32'b0;
                        end
                    endcase
                end
                RESP_OUT: begin
                    case ({wv_req_reg_type,wv_req_reg_op})  
                        //Execution Engine req has resp ctx: Pkey、PMTU、PD、Lkey、Expected PSN、RNR Timer、QP State;
                        {`RD_QP_CTX,`RD_QP_RST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_expect_psn_en      = 1'b1; 
                                qp_expect_psn_wr_en   = 1'b0;
                                qp_expect_psn_addr    = wv_req_reg_qpn;
                                qp_expect_psn_wr_data = 32'b0;
                            end else begin
                                qp_expect_psn_en      = 1'b0;
                                qp_expect_psn_wr_en   = 1'b0;
                                qp_expect_psn_addr    = 14'b0;
                                qp_expect_psn_wr_data = 32'b0;
                            end
                        end
                        default: begin
                            qp_expect_psn_en      = 1'b0;
                            qp_expect_psn_wr_en   = 1'b0;
                            qp_expect_psn_addr    = 14'b0;
                            qp_expect_psn_wr_data = 32'b0;
                        end
                    endcase
                end
                default: begin
                    qp_expect_psn_en      = 1'b0;
                    qp_expect_psn_wr_en   = 1'b0;
                    qp_expect_psn_addr    = 14'b0;
                    qp_expect_psn_wr_data = 32'b0;
                end
            endcase
        end
    end
    //qp_recv_wqe_base_lkey bram 32 width 16384 depth 
        //reg               qp_recv_wqe_base_lkey_en; 
        //reg               qp_recv_wqe_base_lkey_wr_en;
        //reg    [INDEX-1 :0]   qp_recv_wqe_base_lkey_addr;
        //reg    [31 : 0]   qp_recv_wqe_base_lkey_wr_data;
        //wire   [31 : 0]   qp_recv_wqe_base_lkey_rd_data;
    always @(*) begin
        if (rst) begin
            qp_recv_wqe_base_lkey_en      = 1'b0;
            qp_recv_wqe_base_lkey_wr_en   = 1'b0;
            qp_recv_wqe_base_lkey_addr    = 14'b0;
            qp_recv_wqe_base_lkey_wr_data = 32'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_recv_wqe_base_lkey_en      = 1'b1; 
                            qp_recv_wqe_base_lkey_wr_en   = 1'b1; 
                            qp_recv_wqe_base_lkey_addr    = wv_req_reg_qpn;
                            qp_recv_wqe_base_lkey_wr_data = ceu_wr_data_dout1[32*1-1:32*0];
                        end
                        default: begin
                            qp_recv_wqe_base_lkey_en      = 1'b0;
                            qp_recv_wqe_base_lkey_wr_en   = 1'b0;
                            qp_recv_wqe_base_lkey_addr    = 14'b0;
                            qp_recv_wqe_base_lkey_wr_data = 32'b0;
                        end
                    endcase
                end
                RESP_OUT: begin
                    case ({wv_req_reg_type,wv_req_reg_op})  
                        //Execution Engine req has resp ctx: Pkey、PMTU、PD、Lkey、Expected PSN、RNR Timer、QP State;
                        {`RD_QP_CTX,`RD_QP_RST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_recv_wqe_base_lkey_en      = 1'b1; 
                                qp_recv_wqe_base_lkey_wr_en   = 1'b0;
                                qp_recv_wqe_base_lkey_addr    = wv_req_reg_qpn;
                                qp_recv_wqe_base_lkey_wr_data = 32'b0;
                            end else begin
                                qp_recv_wqe_base_lkey_en      = 1'b0;
                                qp_recv_wqe_base_lkey_wr_en   = 1'b0;
                                qp_recv_wqe_base_lkey_addr    = 14'b0;
                                qp_recv_wqe_base_lkey_wr_data = 32'b0;
                            end
                        end               
                        default: begin
                            qp_recv_wqe_base_lkey_en      = 1'b0;
                            qp_recv_wqe_base_lkey_wr_en   = 1'b0;
                            qp_recv_wqe_base_lkey_addr    = 14'b0;
                            qp_recv_wqe_base_lkey_wr_data = 32'b0;
                        end     
                    endcase
                end
                default: begin
                    qp_recv_wqe_base_lkey_en      = 1'b0;
                    qp_recv_wqe_base_lkey_wr_en   = 1'b0;
                    qp_recv_wqe_base_lkey_addr    = 14'b0;
                    qp_recv_wqe_base_lkey_wr_data = 32'b0;
                end
            endcase
        end
    end
    //Key CQ context regs
    //cq_lkey bram 32 width 16384 depth 
        //reg               cq_lkey_en; 
        //reg               cq_lkey_wr_en;
        //reg    [INDEX-1 :0]   cq_lkey_addr;
        //reg    [31 : 0]   cq_lkey_wr_data;
        //wire   [31 : 0]   cq_lkey_rd_data;
    always @(*) begin
        if (rst) begin
            cq_lkey_en      = 1'b0;
            cq_lkey_wr_en   = 1'b0;
            cq_lkey_addr    = 14'b0;
            cq_lkey_wr_data = 32'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_CQ_CTX,`WR_CQ_ALL}: begin
                            cq_lkey_en      = 1'b1; 
                            cq_lkey_wr_en   = 1'b1; 
                            cq_lkey_addr    = wv_req_reg_qpn;
                            cq_lkey_wr_data = ceu_wr_data_dout1[32-1:0];
                        end
                        {`WR_CQ_CTX,`WR_CQ_MODIFY}: begin
                            cq_lkey_en      = 1'b1; 
                            cq_lkey_wr_en   = 1'b1; 
                            cq_lkey_addr    = wv_req_reg_qpn;
                            cq_lkey_wr_data = ceu_wr_data_dout1[32-1:0];
                        end
                        {`WR_CQ_CTX,`WR_CQ_INVALID}: begin
                            cq_lkey_en      = 1'b1; 
                            cq_lkey_wr_en   = 1'b1; 
                            cq_lkey_addr    = wv_req_reg_qpn;
                            cq_lkey_wr_data = 0;
                        end
                        default: begin
                            cq_lkey_en      = 1'b0;
                            cq_lkey_wr_en   = 1'b0;
                            cq_lkey_addr    = 14'b0;
                            cq_lkey_wr_data = 32'b0;
                        end
                    endcase
                end
                RESP_OUT: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        //RRC req has resp ctx:PD、CQ_Lkey(send)、NextPSN、UnAckedPSN、QP State
                        {`RD_CQ_CTX,`RD_CQ_CST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                cq_lkey_en      = 1'b1; 
                                cq_lkey_wr_en   = 1'b0;
                                cq_lkey_addr    = qp_cqn_send_rd_data[INDEX-1 :0];
                                cq_lkey_wr_data = 32'b0;
                            end else begin
                                cq_lkey_en      = 1'b0;
                                cq_lkey_wr_en   = 1'b0;
                                cq_lkey_addr    = 14'b0;
                                cq_lkey_wr_data = 32'b0;
                            end
                        end
                        //RTC req has resp ctx: NextPSN & QP state, CQ_Lkey(send)、qp_cqn_send
                        {`RD_QP_CTX,`RD_QP_NPST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                cq_lkey_en      = 1'b1; 
                                cq_lkey_wr_en   = 1'b0;
                                cq_lkey_addr    = qp_cqn_send_rd_data[INDEX-1 :0];
                                cq_lkey_wr_data = 32'b0;
                            end else begin
                                cq_lkey_en      = 1'b0;
                                cq_lkey_wr_en   = 1'b0;
                                cq_lkey_addr    = 14'b0;
                                cq_lkey_wr_data = 32'b0;
                            end
                        end
                        //Execution Engine req has resp ctx: Pkey、PMTU、PD、Lkey、Expected PSN、RNR Timer、QP State;
                        {`RD_QP_CTX,`RD_QP_RST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                cq_lkey_en       = 1'b1; 
                                cq_lkey_wr_en    = 1'b0;
                                cq_lkey_addr     = qp_cqn_recv_rd_data[INDEX-1 :0];
                                cq_lkey_wr_data = 32'b0;
                            end else begin
                                cq_lkey_en      = 1'b0;
                                cq_lkey_wr_en   = 1'b0;
                                cq_lkey_addr    = 14'b0;
                                cq_lkey_wr_data = 32'b0;
                            end
                        end
                        default: begin
                            cq_lkey_en      = 1'b0;
                            cq_lkey_wr_en   = 1'b0;
                            cq_lkey_addr    = 14'b0;
                            cq_lkey_wr_data = 32'b0;
                        end
                    endcase
                end
                default: begin
                    cq_lkey_en      = 1'b0;
                    cq_lkey_wr_en   = 1'b0;
                    cq_lkey_addr    = 14'b0;
                    cq_lkey_wr_data = 32'b0;
                end
            endcase
        end
    end
    /*Action = Add*/  

    /***************************new version add key info process******************************************/   
    // //****************new version add for QP info******************* 
    // // qp_rq_entry_sz_log_ram 8 width 16384 depth
    // reg                qp_rq_entry_sz_log_en; 
    // reg                qp_rq_entry_sz_log_wr_en;
    // reg     [INDEX-1 :0]   qp_rq_entry_sz_log_addr;
    // reg     [7 : 0]    qp_rq_entry_sz_log_wr_data;
    // wire    [7 : 0]    qp_rq_entry_sz_log_rd_data;
    always @(*) begin
        if (rst) begin
            qp_rq_entry_sz_log_en      = 1'b0;
            qp_rq_entry_sz_log_wr_en   = 1'b0;
            qp_rq_entry_sz_log_addr    = 14'b0;
            qp_rq_entry_sz_log_wr_data = 8'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_rq_entry_sz_log_en      = 1'b1; 
                            qp_rq_entry_sz_log_wr_en   = 1'b1; 
                            qp_rq_entry_sz_log_addr    = wv_req_reg_qpn;
                            qp_rq_entry_sz_log_wr_data = ceu_wr_data_dout2[32*12-1-16:32*12-24];
                        end
                        default: begin
                            qp_rq_entry_sz_log_en      = 1'b0;
                            qp_rq_entry_sz_log_wr_en   = 1'b0;
                            qp_rq_entry_sz_log_addr    = 14'b0;
                            qp_rq_entry_sz_log_wr_data = 8'b0;
                        end
                    endcase
                end
                RESP_OUT: begin
                    case ({wv_req_reg_type,wv_req_reg_op})  
                        //Execution Engine req has resp ctx: Pkey、PMTU、PD、Lkey、Expected PSN、RNR Timer、QP State,qp_rq_entry_sz_log;
                        {`RD_QP_CTX,`RD_QP_RST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_rq_entry_sz_log_en      = 1'b1; 
                                qp_rq_entry_sz_log_wr_en   = 1'b0;
                                qp_rq_entry_sz_log_addr    = wv_req_reg_qpn;
                                qp_rq_entry_sz_log_wr_data = 8'b0;
                            end else begin
                                qp_rq_entry_sz_log_en      = 1'b0;
                                qp_rq_entry_sz_log_wr_en   = 1'b0;
                                qp_rq_entry_sz_log_addr    = 14'b0;
                                qp_rq_entry_sz_log_wr_data = 8'b0;
                            end
                        end               
                        default: begin
                            qp_rq_entry_sz_log_en      = 1'b0;
                            qp_rq_entry_sz_log_wr_en   = 1'b0;
                            qp_rq_entry_sz_log_addr    = 14'b0;
                            qp_rq_entry_sz_log_wr_data = 8'b0;
                        end     
                    endcase
                end
                default: begin
                    qp_rq_entry_sz_log_en      = 1'b0;
                    qp_rq_entry_sz_log_wr_en   = 1'b0;
                    qp_rq_entry_sz_log_addr    = 14'b0;
                    qp_rq_entry_sz_log_wr_data = 8'b0;
                end
            endcase
        end
    end
    // // [7:0]  qp_sq_entry_sz_log bram 8 width 16384 depth 
    // reg                qp_sq_entry_sz_log_en; 
    // reg                qp_sq_entry_sz_log_wr_en;
    // reg     [INDEX-1 :0]   qp_sq_entry_sz_log_addr;
    // reg     [7 : 0]    qp_sq_entry_sz_log_wr_data;
    // wire    [7 : 0]    qp_sq_entry_sz_log_rd_data;
    always @(*) begin
        if (rst) begin
            qp_sq_entry_sz_log_en = 1'b0; 
            qp_sq_entry_sz_log_wr_en = 1'b0;
            qp_sq_entry_sz_log_addr = 14'b0;
            qp_sq_entry_sz_log_wr_data = 8'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_sq_entry_sz_log_en = 1'b1; 
                            qp_sq_entry_sz_log_wr_en = 1'b1;
                            qp_sq_entry_sz_log_addr = wv_req_reg_qpn;
                            qp_sq_entry_sz_log_wr_data = ceu_wr_data_dout2[32*12-1-24:32*11];
                        end        
                        default: begin
                            qp_sq_entry_sz_log_en = 1'b0; 
                            qp_sq_entry_sz_log_wr_en = 1'b0;
                            qp_sq_entry_sz_log_addr = 14'b0;
                            qp_sq_entry_sz_log_wr_data = 8'b0;
                        end
                    endcase
                end
                RD_REQ: begin
                    case ({wv_selected_req_type,wv_selected_req_op})
                        //Doorbell Processing req has resp ctx:PD, Lkey, Pkey, PMTU, Service Type, DestQPN, qp_sq_entry_sz_log
                        {`RD_QP_CTX,`RD_QP_SST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_sq_entry_sz_log_en = 1'b1; 
                                qp_sq_entry_sz_log_wr_en = 1'b0;
                                qp_sq_entry_sz_log_addr = wv_selected_req_qpn;
                                qp_sq_entry_sz_log_wr_data = 8'b0;
                            end else begin
                                qp_sq_entry_sz_log_en = 1'b0; 
                                qp_sq_entry_sz_log_wr_en = 1'b0;
                                qp_sq_entry_sz_log_addr = 14'b0;
                                qp_sq_entry_sz_log_wr_data = 8'b0;
                            end
                        end
                        //WQE Parser req has resp ctx: QP state
                        {`RD_QP_CTX,`RD_QP_STATE}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_sq_entry_sz_log_en = 1'b1; 
                                qp_sq_entry_sz_log_wr_en = 1'b0;
                                qp_sq_entry_sz_log_addr = wv_selected_req_qpn;
                                qp_sq_entry_sz_log_wr_data = 8'b0;
                            end else begin
                                qp_sq_entry_sz_log_en = 1'b0; 
                                qp_sq_entry_sz_log_wr_en = 1'b0;
                                qp_sq_entry_sz_log_addr = 14'b0;
                                qp_sq_entry_sz_log_wr_data = 8'b0;
                            end
                        end
                        default: begin
                            qp_sq_entry_sz_log_en = 1'b0; 
                            qp_sq_entry_sz_log_wr_en = 1'b0;
                            qp_sq_entry_sz_log_addr = 14'b0;
                            qp_sq_entry_sz_log_wr_data = 8'b0;
                        end
                    endcase
                end
                default: begin
                    qp_sq_entry_sz_log_en = 1'b0; 
                    qp_sq_entry_sz_log_wr_en = 1'b0;
                    qp_sq_entry_sz_log_addr = 14'b0;
                    qp_sq_entry_sz_log_wr_data = 8'b0;
                end
            endcase
        end
    end
    // // [47:0] qp_smac bram 48 width 16384 depth 
    // reg                qp_smac_en; 
    // reg                qp_smac_wr_en;
    // reg     [INDEX-1 :0]   qp_smac_addr;
    // reg     [47 : 0]   qp_smac_wr_data;
    // wire    [47 : 0]   qp_smac_rd_data;
    always @(*) begin
        if (rst) begin
            qp_smac_en = 1'b0; 
            qp_smac_wr_en = 1'b0;
            qp_smac_addr = 14'b0;
            qp_smac_wr_data = 48'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_smac_en = 1'b1; 
                            qp_smac_wr_en = 1'b1;
                            qp_smac_addr = wv_req_reg_qpn;
                            qp_smac_wr_data = {ceu_wr_data_dout2[32*10-1:32*9],ceu_wr_data_dout2[32*11-1-16:32*10]};
                        end        
                        default: begin
                            qp_smac_en = 1'b0; 
                            qp_smac_wr_en = 1'b0;
                            qp_smac_addr = 14'b0;
                            qp_smac_wr_data = 48'b0;
                        end
                    endcase
                end
                RD_REQ: begin
                    case ({wv_selected_req_type,wv_selected_req_op})
                        //FrameEncap req has resp ctx: Pkey,port number,qp_smac;
                        {`RD_QP_CTX,`RD_ENCAP}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_smac_en = 1'b1; 
                                qp_smac_wr_en = 1'b0;
                                qp_smac_addr = wv_selected_req_qpn;
                                qp_smac_wr_data = 48'b0;
                            end else begin
                                qp_smac_en = 1'b0; 
                                qp_smac_wr_en = 1'b0;
                                qp_smac_addr = 14'b0;
                                qp_smac_wr_data = 48'b0;
                            end
                        end
                        default: begin
                            qp_smac_en = 1'b0; 
                            qp_smac_wr_en = 1'b0;
                            qp_smac_addr = 14'b0;
                            qp_smac_wr_data = 48'b0;
                        end
                    endcase
                end
                default: begin
                    qp_smac_en = 1'b0; 
                    qp_smac_wr_en = 1'b0;
                    qp_smac_addr = 14'b0;
                    qp_smac_wr_data = 48'b0;
                end
            endcase
        end
    end
    // // [47:0] qp_dmac bram 48 width 16384 depth 
    // reg                qp_dmac_en; 
    // reg                qp_dmac_wr_en;
    // reg     [INDEX-1 :0]   qp_dmac_addr;
    // reg     [47 : 0]   qp_dmac_wr_data;
    // wire    [47 : 0]   qp_dmac_rd_data;
    always @(*) begin
        if (rst) begin
            qp_dmac_en = 1'b0; 
            qp_dmac_wr_en = 1'b0;
            qp_dmac_addr = 14'b0;
            qp_dmac_wr_data = 48'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_dmac_en = 1'b1; 
                            qp_dmac_wr_en = 1'b1;
                            qp_dmac_addr = wv_req_reg_qpn;
                            qp_dmac_wr_data = {ceu_wr_data_dout2[32*9-1:32*8],ceu_wr_data_dout2[32*11-1:32*11-16]};
                        end        
                        default: begin
                            qp_dmac_en = 1'b0; 
                            qp_dmac_wr_en = 1'b0;
                            qp_dmac_addr = 14'b0;
                            qp_dmac_wr_data = 48'b0;
                        end
                    endcase
                end
                RD_REQ: begin
                    case ({wv_selected_req_type,wv_selected_req_op})
                        //FrameEncap req has resp ctx: Pkey,port number,qp_smac,qp_dmac;
                        {`RD_QP_CTX,`RD_ENCAP}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_dmac_en = 1'b1; 
                                qp_dmac_wr_en = 1'b0;
                                qp_dmac_addr = wv_selected_req_qpn;
                                qp_dmac_wr_data = 48'b0;
                            end else begin
                                qp_dmac_en = 1'b0; 
                                qp_dmac_wr_en = 1'b0;
                                qp_dmac_addr = 14'b0;
                                qp_dmac_wr_data = 48'b0;
                            end
                        end
                        default: begin
                            qp_dmac_en = 1'b0; 
                            qp_dmac_wr_en = 1'b0;
                            qp_dmac_addr = 14'b0;
                            qp_dmac_wr_data = 48'b0;
                        end
                    endcase
                end
                RESP_OUT: begin
                    case ({wv_req_reg_type,wv_req_reg_op})        
                        //RTC req has resp ctx: NextPSN & QP state,qp_dmac
                        {`RD_QP_CTX,`RD_QP_NPST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_dmac_en = 1'b1; 
                                qp_dmac_wr_en = 1'b0;
                                qp_dmac_addr = wv_req_reg_qpn;
                                qp_dmac_wr_data = 48'b0;
                            end else begin
                                qp_dmac_en = 1'b0; 
                                qp_dmac_wr_en = 1'b0;
                                qp_dmac_addr = 14'b0;
                                qp_dmac_wr_data = 48'b0;
                            end
                        end
                        //Execution Engine req has resp ctx: Pkey、PMTU、PD、Lkey、Expected PSN、RNR Timer、QP State;,qp_dmac
                        {`RD_QP_CTX,`RD_QP_RST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_dmac_en = 1'b1; 
                                qp_dmac_wr_en = 1'b0;
                                qp_dmac_addr = wv_req_reg_qpn;
                                qp_dmac_wr_data = 48'b0;
                            end else begin
                                qp_dmac_en = 1'b0; 
                                qp_dmac_wr_en = 1'b0;
                                qp_dmac_addr = 14'b0;
                                qp_dmac_wr_data = 48'b0;
                            end
                        end
                        //RRC req has resp ctx:PD、CQ_Lkey、NextPSN、UnAckedPSN、QP State,qp_dmac
                        {`RD_CQ_CTX,`RD_CQ_CST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_dmac_en = 1'b1; 
                                qp_dmac_wr_en = 1'b0;
                                qp_dmac_addr = wv_req_reg_qpn;
                                qp_dmac_wr_data = 48'b0;
                            end else begin
                                qp_dmac_en = 1'b0; 
                                qp_dmac_wr_en = 1'b0;
                                qp_dmac_addr = 14'b0;
                                qp_dmac_wr_data = 48'b0;
                            end
                        end 
                        default: begin
                            qp_dmac_en = 1'b0; 
                            qp_dmac_wr_en = 1'b0;
                            qp_dmac_addr = 14'b0;
                            qp_dmac_wr_data = 48'b0;
                        end
                    endcase
                end
                default: begin
                    qp_dmac_en = 1'b0; 
                    qp_dmac_wr_en = 1'b0;
                    qp_dmac_addr = 14'b0;
                    qp_dmac_wr_data = 48'b0;
                end
            endcase
        end
    end
    // // [31:0] qp_sip bram 32 width 16384 depth 
    // reg               qp_sip_en; 
    // reg               qp_sip_wr_en;
    // reg    [INDEX-1 :0]   qp_sip_addr;
    // reg    [31 : 0]   qp_sip_wr_data;
    // wire   [31 : 0]   qp_sip_rd_data;
    always @(*) begin
        if (rst) begin
            qp_sip_en = 1'b0; 
            qp_sip_wr_en = 1'b0;
            qp_sip_addr = 14'b0;
            qp_sip_wr_data = 32'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_sip_en = 1'b1; 
                            qp_sip_wr_en = 1'b1;
                            qp_sip_addr = wv_req_reg_qpn;
                            qp_sip_wr_data = ceu_wr_data_dout2[32*8-1:32*7];
                        end        
                        default: begin
                            qp_sip_en = 1'b0; 
                            qp_sip_wr_en = 1'b0;
                            qp_sip_addr = 14'b0;
                            qp_sip_wr_data = 32'b0;
                        end
                    endcase
                end
                RD_REQ: begin
                    case ({wv_selected_req_type,wv_selected_req_op})
                        //FrameEncap req has resp ctx: Pkey,port number,qp_smac,qp_sip,qp_dmac;
                        {`RD_QP_CTX,`RD_ENCAP}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_sip_en = 1'b1; 
                                qp_sip_wr_en = 1'b0;
                                qp_sip_addr = wv_selected_req_qpn;
                                qp_sip_wr_data = 32'b0;
                            end else begin
                                qp_sip_en = 1'b0; 
                                qp_sip_wr_en = 1'b0;
                                qp_sip_addr = 14'b0;
                                qp_sip_wr_data = 32'b0;
                            end
                        end
                        default: begin
                            qp_sip_en = 1'b0; 
                            qp_sip_wr_en = 1'b0;
                            qp_sip_addr = 14'b0;
                            qp_sip_wr_data = 32'b0;
                        end
                    endcase
                end
                default: begin
                    qp_sip_en = 1'b0; 
                    qp_sip_wr_en = 1'b0;
                    qp_sip_addr = 14'b0;
                    qp_sip_wr_data = 32'b0;
                end
            endcase
        end
    end    // // [31:0] qp_dip bram 32 width 16384 depth 
    // reg               qp_dip_en; 
    // reg               qp_dip_wr_en;
    // reg    [INDEX-1 :0]   qp_dip_addr;
    // reg    [31 : 0]   qp_dip_wr_data;
    // wire   [31 : 0]   qp_dip_rd_data;
    always @(*) begin
        if (rst) begin
            qp_dip_en = 1'b0; 
            qp_dip_wr_en = 1'b0;
            qp_dip_addr = 14'b0;
            qp_dip_wr_data = 32'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_dip_en = 1'b1; 
                            qp_dip_wr_en = 1'b1;
                            qp_dip_addr = wv_req_reg_qpn;
                            qp_dip_wr_data = ceu_wr_data_dout2[32*7-1:32*6];
                        end        
                        default: begin
                            qp_dip_en = 1'b0; 
                            qp_dip_wr_en = 1'b0;
                            qp_dip_addr = 14'b0;
                            qp_dip_wr_data = 32'b0;
                        end
                    endcase
                end
                RD_REQ: begin
                    case ({wv_selected_req_type,wv_selected_req_op})
                        //FrameEncap req has resp ctx: Pkey,port number,qp_smac,qp_dip;
                        {`RD_QP_CTX,`RD_ENCAP}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_dip_en = 1'b1; 
                                qp_dip_wr_en = 1'b0;
                                qp_dip_addr = wv_selected_req_qpn;
                                qp_dip_wr_data = 32'b0;
                            end else begin
                                qp_dip_en = 1'b0; 
                                qp_dip_wr_en = 1'b0;
                                qp_dip_addr = 14'b0;
                                qp_dip_wr_data = 32'b0;
                            end
                        end
                        default: begin
                            qp_dip_en = 1'b0; 
                            qp_dip_wr_en = 1'b0;
                            qp_dip_addr = 14'b0;
                            qp_dip_wr_data = 32'b0;
                        end
                    endcase
                end
                default: begin
                    qp_dip_en = 1'b0; 
                    qp_dip_wr_en = 1'b0;
                    qp_dip_addr = 14'b0;
                    qp_dip_wr_data = 32'b0;
                end
            endcase
        end
    end    
    // // [31:0] qp_send_wqe_length bram 32 width 16384 depth 
    // reg               qp_send_wqe_length_en; 
    // reg               qp_send_wqe_length_wr_en;
    // reg    [INDEX-1 :0]   qp_send_wqe_length_addr;
    // reg    [31 : 0]   qp_send_wqe_length_wr_data;
    // wire   [31 : 0]   qp_send_wqe_length_rd_data;
    always @(*) begin
        if (rst) begin
            qp_send_wqe_length_en = 1'b0; 
            qp_send_wqe_length_wr_en = 1'b0;
            qp_send_wqe_length_addr = 14'b0;
            qp_send_wqe_length_wr_data = 32'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_send_wqe_length_en = 1'b1; 
                            qp_send_wqe_length_wr_en = 1'b1;
                            qp_send_wqe_length_addr = wv_req_reg_qpn;
                            qp_send_wqe_length_wr_data = ceu_wr_data_dout2[32*6-1:32*5];
                        end        
                        default: begin
                            qp_send_wqe_length_en = 1'b0; 
                            qp_send_wqe_length_wr_en = 1'b0;
                            qp_send_wqe_length_addr = 14'b0;
                            qp_send_wqe_length_wr_data = 32'b0;
                        end
                    endcase
                end
                RD_REQ: begin
                    case ({wv_selected_req_type,wv_selected_req_op})
                        //Doorbell Processing req has resp ctx:PD, Lkey, Pkey, PMTU, Service Type, DestQPN, qp_sq_entry_sz_log, qp_send_wqe_length
                        {`RD_QP_CTX,`RD_QP_SST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_send_wqe_length_en = 1'b1; 
                                qp_send_wqe_length_wr_en = 1'b0;
                                qp_send_wqe_length_addr = wv_selected_req_qpn;
                                qp_send_wqe_length_wr_data = 32'b0;
                            end else begin
                                qp_send_wqe_length_en = 1'b0; 
                                qp_send_wqe_length_wr_en = 1'b0;
                                qp_send_wqe_length_addr = 14'b0;
                                qp_send_wqe_length_wr_data = 32'b0;
                            end
                        end
                        //WQE Parser req has resp ctx: QP state
                        {`RD_QP_CTX,`RD_QP_STATE}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_send_wqe_length_en = 1'b1; 
                                qp_send_wqe_length_wr_en = 1'b0;
                                qp_send_wqe_length_addr = wv_selected_req_qpn;
                                qp_send_wqe_length_wr_data = 32'b0;
                            end else begin
                                qp_send_wqe_length_en = 1'b0; 
                                qp_send_wqe_length_wr_en = 1'b0;
                                qp_send_wqe_length_addr = 14'b0;
                                qp_send_wqe_length_wr_data = 32'b0;
                            end
                        end
                        default: begin
                            qp_send_wqe_length_en = 1'b0; 
                            qp_send_wqe_length_wr_en = 1'b0;
                            qp_send_wqe_length_addr = 14'b0;
                            qp_send_wqe_length_wr_data = 32'b0;
                        end
                    endcase
                end
                default: begin
                    qp_send_wqe_length_en = 1'b0; 
                    qp_send_wqe_length_wr_en = 1'b0;
                    qp_send_wqe_length_addr = 14'b0;
                    qp_send_wqe_length_wr_data = 32'b0;
                end
            endcase
        end
    end 
    // // [31:0] qp_cqn_recv bram 32 width 16384 depth 
    // reg               qp_cqn_recv_en; 
    // reg               qp_cqn_recv_wr_en;
    // reg    [INDEX-1 :0]   qp_cqn_recv_addr;
    // reg    [31 : 0]   qp_cqn_recv_wr_data;
    // wire   [31 : 0]   qp_cqn_recv_rd_data;
    always @(*) begin
        if (rst) begin
            qp_cqn_recv_en      = 1'b0;
            qp_cqn_recv_wr_en   = 1'b0;
            qp_cqn_recv_addr    = 14'b0;
            qp_cqn_recv_wr_data = 32'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_cqn_recv_en      = 1'b1; 
                            qp_cqn_recv_wr_en   = 1'b1; 
                            qp_cqn_recv_addr    = wv_req_reg_qpn;
                            qp_cqn_recv_wr_data = ceu_wr_data_dout2[32*5-1:32*4];
                        end
                        default: begin
                            qp_cqn_recv_en      = 1'b0;
                            qp_cqn_recv_wr_en   = 1'b0;
                            qp_cqn_recv_addr    = 14'b0;
                            qp_cqn_recv_wr_data = 32'b0;
                        end
                    endcase
                end
                RESP_OUT: begin
                    case ({wv_req_reg_type,wv_req_reg_op})  
                        //Execution Engine req has resp ctx: Pkey、PMTU、PD、Lkey、Expected PSN、RNR Timer、QP State;
                        {`RD_QP_CTX,`RD_QP_RST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_cqn_recv_en      = 1'b1; 
                                qp_cqn_recv_wr_en   = 1'b0;
                                qp_cqn_recv_addr    = wv_req_reg_qpn;
                                qp_cqn_recv_wr_data = 32'b0;
                            end else begin
                                qp_cqn_recv_en      = 1'b0;
                                qp_cqn_recv_wr_en   = 1'b0;
                                qp_cqn_recv_addr    = 14'b0;
                                qp_cqn_recv_wr_data = 32'b0;
                            end
                        end               
                        default: begin
                            qp_cqn_recv_en      = 1'b0;
                            qp_cqn_recv_wr_en   = 1'b0;
                            qp_cqn_recv_addr    = 14'b0;
                            qp_cqn_recv_wr_data = 32'b0;
                        end     
                    endcase
                end
                default: begin
                    qp_cqn_recv_en      = 1'b0;
                    qp_cqn_recv_wr_en   = 1'b0;
                    qp_cqn_recv_addr    = 14'b0;
                    qp_cqn_recv_wr_data = 32'b0;
                end
            endcase
        end
    end
    // // [31:0] qp_recv_wqe_length bram 32 width 16384 depth 
    // reg               qp_recv_wqe_length_en; 
    // reg               qp_recv_wqe_length_wr_en;
    // reg    [INDEX-1 :0]   qp_recv_wqe_length_addr;
    // reg    [31 : 0]   qp_recv_wqe_length_wr_data;
    // wire   [31 : 0]   qp_recv_wqe_length_rd_data;
    always @(*) begin
        if (rst) begin
            qp_recv_wqe_length_en      = 1'b0;
            qp_recv_wqe_length_wr_en   = 1'b0;
            qp_recv_wqe_length_addr    = 14'b0;
            qp_recv_wqe_length_wr_data = 32'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_QP_CTX,`WR_QP_ALL}: begin
                            qp_recv_wqe_length_en      = 1'b1; 
                            qp_recv_wqe_length_wr_en   = 1'b1; 
                            qp_recv_wqe_length_addr    = wv_req_reg_qpn;
                            qp_recv_wqe_length_wr_data = ceu_wr_data_dout2[32*4-1:32*3];
                        end
                        default: begin
                            qp_recv_wqe_length_en      = 1'b0;
                            qp_recv_wqe_length_wr_en   = 1'b0;
                            qp_recv_wqe_length_addr    = 14'b0;
                            qp_recv_wqe_length_wr_data = 32'b0;
                        end
                    endcase
                end
                RESP_OUT: begin
                    case ({wv_req_reg_type,wv_req_reg_op})  
                        //Execution Engine req has resp ctx: Pkey、PMTU、PD、Lkey、Expected PSN、RNR Timer、QP State;
                        {`RD_QP_CTX,`RD_QP_RST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                qp_recv_wqe_length_en      = 1'b1; 
                                qp_recv_wqe_length_wr_en   = 1'b0;
                                qp_recv_wqe_length_addr    = wv_req_reg_qpn;
                                qp_recv_wqe_length_wr_data = 32'b0;
                            end else begin
                                qp_recv_wqe_length_en      = 1'b0;
                                qp_recv_wqe_length_wr_en   = 1'b0;
                                qp_recv_wqe_length_addr    = 14'b0;
                                qp_recv_wqe_length_wr_data = 32'b0;
                            end
                        end               
                        default: begin
                            qp_recv_wqe_length_en      = 1'b0;
                            qp_recv_wqe_length_wr_en   = 1'b0;
                            qp_recv_wqe_length_addr    = 14'b0;
                            qp_recv_wqe_length_wr_data = 32'b0;
                        end     
                    endcase
                end
                default: begin
                    qp_recv_wqe_length_en      = 1'b0;
                    qp_recv_wqe_length_wr_en   = 1'b0;
                    qp_recv_wqe_length_addr    = 14'b0;
                    qp_recv_wqe_length_wr_data = 32'b0;
                end
            endcase
        end
    end   
    // //****************new version add for CQ info******************* 
    // // [7:0]  cq_sz_log bram 8 width 16384 depth  
    // reg                cq_sz_log_en; 
    // reg                cq_sz_log_wr_en;
    // reg     [INDEX-1 :0]   cq_sz_log_addr;
    // reg     [7 : 0]    cq_sz_log_wr_data;
    // wire    [7 : 0]    cq_sz_log_rd_data;
    always @(*) begin
        if (rst) begin
            cq_sz_log_en      = 1'b0;
            cq_sz_log_wr_en   = 1'b0;
            cq_sz_log_addr    = 14'b0;
            cq_sz_log_wr_data = 8'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_CQ_CTX,`WR_CQ_ALL}: begin
                            cq_sz_log_en      = 1'b1; 
                            cq_sz_log_wr_en   = 1'b1; 
                            cq_sz_log_addr    = wv_req_reg_qpn;
                            cq_sz_log_wr_data = ceu_wr_data_dout1[32*3-1:32*3-8];
                        end
                        {`WR_CQ_CTX,`WR_CQ_MODIFY}: begin
                            cq_sz_log_en      = 1'b1; 
                            cq_sz_log_wr_en   = 1'b1; 
                            cq_sz_log_addr    = wv_req_reg_qpn;
                            cq_sz_log_wr_data = ceu_wr_data_dout1[32*3-1:32*3-8];
                        end
                        {`WR_CQ_CTX,`WR_CQ_INVALID}: begin
                            cq_sz_log_en      = 1'b1; 
                            cq_sz_log_wr_en   = 1'b1; 
                            cq_sz_log_addr    = wv_req_reg_qpn;
                            cq_sz_log_wr_data = 0;
                        end
                        default: begin
                            cq_sz_log_en      = 1'b0;
                            cq_sz_log_wr_en   = 1'b0;
                            cq_sz_log_addr    = 14'b0;
                            cq_sz_log_wr_data = 8'b0;
                        end
                    endcase
                end
                RESP_OUT: begin
                    case ({wv_req_reg_type,wv_req_reg_op})  
                        //RRC req has resp ctx:PD、CQ_Lkey(send)、NextPSN、UnAckedPSN、QP State
                        {`RD_CQ_CTX,`RD_CQ_CST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                cq_sz_log_en      = 1'b1; 
                                cq_sz_log_wr_en   = 1'b0;
                                cq_sz_log_addr    = qp_cqn_send_rd_data[INDEX-1 :0];
                                cq_sz_log_wr_data = 8'b0;
                            end else begin
                                cq_sz_log_en      = 1'b0;
                                cq_sz_log_wr_en   = 1'b0;
                                cq_sz_log_addr    = 14'b0;
                                cq_sz_log_wr_data = 8'b0;
                            end
                        end
                        //RTC req has resp ctx: NextPSN & QP state, CQ_Lkey(send)、qp_cqn_send
                        {`RD_QP_CTX,`RD_QP_NPST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                cq_sz_log_en      = 1'b1; 
                                cq_sz_log_wr_en   = 1'b0;
                                cq_sz_log_addr    = qp_cqn_send_rd_data[INDEX-1 :0];
                                cq_sz_log_wr_data = 8'b0;
                            end else begin
                                cq_sz_log_en      = 1'b0;
                                cq_sz_log_wr_en   = 1'b0;
                                cq_sz_log_addr    = 14'b0;
                                cq_sz_log_wr_data = 8'b0;
                            end
                        end
                        //Execution Engine req has resp ctx: Pkey、PMTU、PD、Lkey、Expected PSN、RNR Timer、QP State;
                        {`RD_QP_CTX,`RD_QP_RST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                cq_sz_log_en      = 1'b1; 
                                cq_sz_log_wr_en   = 1'b0;
                                cq_sz_log_addr    = qp_cqn_recv_rd_data[INDEX-1 :0];
                                cq_sz_log_wr_data = 8'b0;
                            end else begin
                                cq_sz_log_en      = 1'b0;
                                cq_sz_log_wr_en   = 1'b0;
                                cq_sz_log_addr    = 14'b0;
                                cq_sz_log_wr_data = 8'b0;
                            end
                        end               
                        default: begin
                            cq_sz_log_en      = 1'b0;
                            cq_sz_log_wr_en   = 1'b0;
                            cq_sz_log_addr    = 14'b0;
                            cq_sz_log_wr_data = 8'b0;
                        end     
                    endcase
                end
                default: begin
                    cq_sz_log_en      = 1'b0;
                    cq_sz_log_wr_en   = 1'b0;
                    cq_sz_log_addr    = 14'b0;
                    cq_sz_log_wr_data = 8'b0;
                end
            endcase
        end
    end
    // // [31:0] cq_pd bram 32 width 16384 depth 
    // reg               cq_pd_en; 
    // reg               cq_pd_wr_en;
    // reg    [INDEX-1 :0]   cq_pd_addr;
    // reg    [31 : 0]   cq_pd_wr_data;
    // wire   [31 : 0]   cq_pd_rd_data;
    always @(*) begin
        if (rst) begin
            cq_pd_en      = 1'b0;
            cq_pd_wr_en   = 1'b0;
            cq_pd_addr    = 14'b0;
            cq_pd_wr_data = 32'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_CQ_CTX,`WR_CQ_ALL}: begin
                            cq_pd_en      = 1'b1; 
                            cq_pd_wr_en   = 1'b1; 
                            cq_pd_addr    = wv_req_reg_qpn;
                            cq_pd_wr_data = ceu_wr_data_dout1[32*2-1:32*1];
                        end
                        {`WR_CQ_CTX,`WR_CQ_MODIFY}: begin
                            cq_pd_en      = 1'b1; 
                            cq_pd_wr_en   = 1'b1; 
                            cq_pd_addr    = wv_req_reg_qpn;
                            cq_pd_wr_data = ceu_wr_data_dout1[32*2-1:32*1];
                        end
                        {`WR_CQ_CTX,`WR_CQ_INVALID}: begin
                            cq_pd_en      = 1'b1; 
                            cq_pd_wr_en   = 1'b1; 
                            cq_pd_addr    = wv_req_reg_qpn;
                            cq_pd_wr_data = 0;
                        end
                        default: begin
                            cq_pd_en      = 1'b0;
                            cq_pd_wr_en   = 1'b0;
                            cq_pd_addr    = 14'b0;
                            cq_pd_wr_data = 32'b0;
                        end
                    endcase
                end
                RESP_OUT: begin
                    case ({wv_req_reg_type,wv_req_reg_op})  
                        //RRC req has resp ctx:PD、CQ_Lkey(send)、NextPSN、UnAckedPSN、QP State
                        {`RD_CQ_CTX,`RD_CQ_CST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                cq_pd_en      = 1'b1; 
                                cq_pd_wr_en   = 1'b0;
                                cq_pd_addr    = qp_cqn_send_rd_data[INDEX-1 :0];
                                cq_pd_wr_data = 32'b0;
                            end else begin
                                cq_pd_en      = 1'b0;
                                cq_pd_wr_en   = 1'b0;
                                cq_pd_addr    = 14'b0;
                                cq_pd_wr_data = 32'b0;
                            end
                        end
                        //RTC req has resp ctx: NextPSN & QP state, CQ_Lkey(send)、qp_cqn_send
                        {`RD_QP_CTX,`RD_QP_NPST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                cq_pd_en      = 1'b1; 
                                cq_pd_wr_en   = 1'b0;
                                cq_pd_addr    = qp_cqn_send_rd_data[INDEX-1 :0];
                                cq_pd_wr_data = 32'b0;
                            end else begin
                                cq_pd_en      = 1'b0;
                                cq_pd_wr_en   = 1'b0;
                                cq_pd_addr    = 14'b0;
                                cq_pd_wr_data = 32'b0;
                            end
                        end
                        //Execution Engine req has resp ctx: Pkey、PMTU、PD、Lkey、Expected PSN、RNR Timer、QP State;
                        {`RD_QP_CTX,`RD_QP_RST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                cq_pd_en      = 1'b1; 
                                cq_pd_wr_en   = 1'b0;
                                cq_pd_addr    = qp_cqn_recv_rd_data[INDEX-1 :0];
                                cq_pd_wr_data = 32'b0;
                            end else begin
                                cq_pd_en      = 1'b0;
                                cq_pd_wr_en   = 1'b0;
                                cq_pd_addr    = 14'b0;
                                cq_pd_wr_data = 32'b0;
                            end
                        end               
                        default: begin
                            cq_pd_en      = 1'b0;
                            cq_pd_wr_en   = 1'b0;
                            cq_pd_addr    = 14'b0;
                            cq_pd_wr_data = 32'b0;
                        end     
                    endcase
                end
                default: begin
                    cq_pd_en      = 1'b0;
                    cq_pd_wr_en   = 1'b0;
                    cq_pd_addr    = 14'b0;
                    cq_pd_wr_data = 32'b0;
                end
            endcase
        end
    end
    /***************************new version add key info process******************************************/                          
    //****************new version 2.0 add for CQ info*******************
    // [7:0] eqn[0:(1<<INDEX)-1];
    // reg                eqn_en; 
    // reg                eqn_wr_en;
    // reg     [INDEX-1 :0]   eqn_addr;
    // reg     [7 : 0]    eqn_wr_data;
    // wire    [7 : 0]    eqn_rd_data;
    always @(*) begin
        if (rst) begin
            eqn_en      = 1'b0;
            eqn_wr_en   = 1'b0;
            eqn_addr    = 14'b0;
            eqn_wr_data = 8'b0;
        end
        else begin
            case (fsm_cs)
                DATA_WR: begin
                    case ({wv_req_reg_type,wv_req_reg_op})
                        {`WR_CQ_CTX,`WR_CQ_ALL}: begin
                            eqn_en      = 1'b1; 
                            eqn_wr_en   = 1'b1; 
                            eqn_addr    = wv_req_reg_qpn;
                            eqn_wr_data = ceu_wr_data_dout1[32*3+7:32*3];
                        end
                        {`WR_CQ_CTX,`WR_CQ_MODIFY}: begin
                            eqn_en      = 1'b1; 
                            eqn_wr_en   = 1'b1; 
                            eqn_addr    = wv_req_reg_qpn;
                            eqn_wr_data = ceu_wr_data_dout1[32*3+7:32*3];
                        end
                        {`WR_CQ_CTX,`WR_CQ_INVALID}: begin
                            eqn_en      = 1'b1; 
                            eqn_wr_en   = 1'b1; 
                            eqn_addr    = wv_req_reg_qpn;
                            eqn_wr_data = 0;
                        end
                        default: begin
                            eqn_en      = 1'b0;
                            eqn_wr_en   = 1'b0;
                            eqn_addr    = 14'b0;
                            eqn_wr_data = 8'b0;
                        end
                    endcase
                end
                RESP_OUT: begin
                    case ({wv_req_reg_type,wv_req_reg_op})  
                        //RRC req has resp ctx:PD、CQ_Lkey(send)、NextPSN、UnAckedPSN、QP State
                        {`RD_CQ_CTX,`RD_CQ_CST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                eqn_en      = 1'b1; 
                                eqn_wr_en   = 1'b0;
                                eqn_addr    = qp_cqn_send_rd_data[INDEX-1 :0];
                                eqn_wr_data = 8'b0;
                            end else begin
                                eqn_en      = 1'b0;
                                eqn_wr_en   = 1'b0;
                                eqn_addr    = 14'b0;
                                eqn_wr_data = 8'b0;
                            end
                        end
                        //RTC req has resp ctx: NextPSN & QP state, CQ_Lkey(send)、qp_cqn_send
                        {`RD_QP_CTX,`RD_QP_NPST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                eqn_en      = 1'b1; 
                                eqn_wr_en   = 1'b0;
                                eqn_addr    = qp_cqn_send_rd_data[INDEX-1 :0];
                                eqn_wr_data = 8'b0;
                            end else begin
                                eqn_en      = 1'b0;
                                eqn_wr_en   = 1'b0;
                                eqn_addr    = 14'b0;
                                eqn_wr_data = 8'b0;
                            end
                        end
                        //Execution Engine req has resp ctx: Pkey、PMTU、PD、Lkey、Expected PSN、RNR Timer、QP State;
                        {`RD_QP_CTX,`RD_QP_RST}:begin
                            if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                                eqn_en      = 1'b1; 
                                eqn_wr_en   = 1'b0;
                                eqn_addr    = qp_cqn_recv_rd_data[INDEX-1 :0];
                                eqn_wr_data = 8'b0;
                            end else begin
                                eqn_en      = 1'b0;
                                eqn_wr_en   = 1'b0;
                                eqn_addr    = 14'b0;
                                eqn_wr_data = 8'b0;
                            end
                        end               
                        default: begin
                            eqn_en      = 1'b0;
                            eqn_wr_en   = 1'b0;
                            eqn_addr    = 14'b0;
                            eqn_wr_data = 8'b0;
                        end     
                    endcase
                end
                default: begin
                    eqn_en      = 1'b0;
                    eqn_wr_en   = 1'b0;
                    eqn_addr    = 14'b0;
                    eqn_wr_data = 8'b0;
                end
            endcase
        end
    end
    //****************new version 2.0 add for CQ info*******************

    //****************new version 2.0 add for EQ info*******************
    //TODO: add for EQ info reg arraies
    //Key EQ context regs
    // [31:0] eq_lkey[0:(1<<5)-1];
    // [7:0]  eq_sz_log[0:(1<<5)-1];
    // [31:0] eq_pd[0:(1<<5)-1];
    // [15:0] eq_intr[0:(1<<5)-1];  
    // reg eqn_valid[0:31];  
    integer i_eqn;
    wire [4:0] wv_req_reg_eqn;
    assign wv_req_reg_eqn  = qv_tmp_req[100:96];
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i_eqn=0; i_eqn<32; i_eqn=i_eqn+1) begin
                eq_lkey[i_eqn]   <= `TD {32{1'b0}};
                eq_sz_log[i_eqn] <= `TD {8{1'b0}};
                eq_pd[i_eqn]     <= `TD {32{1'b0}};
                eq_intr[i_eqn]   <= `TD {16{1'b0}};
                eqn_valid[i_eqn] <= `TD 1'b0;
            end               
        end 
        else if ((fsm_cs == DATA_WR)) begin
            case ({wv_req_reg_type,wv_req_reg_op})
                {`WR_EQ_CTX,`WR_EQ_ALL}: begin
                    eq_lkey[wv_req_reg_eqn]   <= `TD ceu_wr_data_dout1[31:0];
                    eq_sz_log[wv_req_reg_eqn] <= `TD ceu_wr_data_dout1[32*2+23:32*2+16];
                    eq_pd[wv_req_reg_eqn]     <= `TD ceu_wr_data_dout1[32*2-1:32];
                    eq_intr[wv_req_reg_eqn]   <= `TD ceu_wr_data_dout1[32*2+15:32*2];
                    eqn_valid[wv_req_reg_eqn] <= `TD 1'b0;
                end
                {`WR_EQ_CTX,`WR_EQ_FUNC}: begin
                    eqn_valid[wv_req_reg_eqn] <= `TD qv_tmp_req[23] ? 1'b0 : 1'b1;
                end
                {`WR_EQ_CTX,`WR_EQ_INVALID}: begin
                    eq_lkey[wv_req_reg_eqn]   <= `TD {32{1'b0}};
                    eq_sz_log[wv_req_reg_eqn] <= `TD {8{1'b0}};
                    eq_pd[wv_req_reg_eqn]     <= `TD {32{1'b0}};
                    eq_intr[wv_req_reg_eqn]   <= `TD {16{1'b0}};
                    eqn_valid[wv_req_reg_eqn] <= `TD 1'b0;
                end
                default: begin
                    for (i_eqn=0; i_eqn<32; i_eqn=i_eqn+1) begin
                        eq_lkey[i_eqn]   <= `TD eq_lkey[i_eqn];
                        eq_sz_log[i_eqn] <= `TD eq_sz_log[i_eqn];
                        eq_pd[i_eqn]     <= `TD eq_pd[i_eqn];
                        eq_intr[i_eqn]   <= `TD eq_intr[i_eqn];
                        eqn_valid[i_eqn] <= `TD eqn_valid[i_eqn];
                    end    
                end
            endcase
        end 
        else begin
            for (i_eqn=0; i_eqn<32; i_eqn=i_eqn+1) begin
                eq_lkey[i_eqn]   <= `TD eq_lkey[i_eqn];
                eq_sz_log[i_eqn] <= `TD eq_sz_log[i_eqn];
                eq_pd[i_eqn]     <= `TD eq_pd[i_eqn];
                eq_intr[i_eqn]   <= `TD eq_intr[i_eqn];
                eqn_valid[i_eqn] <= `TD eqn_valid[i_eqn];
            end 
        end
    end
    //****************new version 2.0 add for EQ info*******************

    //response to dest resp cmd fifo
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            o_db_cxtmgt_resp_wr_en <= `TD 0;
            ov_db_cxtmgt_resp_data <= `TD 0;
            o_wp_cxtmgt_resp_wr_en <= `TD 0;
            ov_wp_cxtmgt_resp_data <= `TD 0;
            o_rtc_cxtmgt_resp_wr_en <= `TD 0;
            ov_rtc_cxtmgt_resp_data <= `TD 0;
            o_rrc_cxtmgt_resp_wr_en <= `TD 0;
            ov_rrc_cxtmgt_resp_data <= `TD 0;
            o_ee_cxtmgt_resp_wr_en <= `TD 0;
            ov_ee_cxtmgt_resp_data <= `TD 0;
            o_fe_cxtmgt_resp_wr_en <= `TD 0;
            ov_fe_cxtmgt_resp_data <= `TD 0;
        end
        else begin
            /*Spyglass*/
            //case ({wv_req_reg_type,wv_req_reg_op})
            case ({fsm_cs,wv_req_reg_type,wv_req_reg_op})
                //RTC req has the same cmd resp as req format
                {RESP_OUT,`RD_QP_CTX,`RD_QP_NPST}:begin
                    if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full && (qv_read_ram_cnt == 2'b11)) begin
                        o_db_cxtmgt_resp_wr_en <= `TD 0;
                        ov_db_cxtmgt_resp_data <= `TD 0;
                        o_wp_cxtmgt_resp_wr_en <= `TD 0;
                        ov_wp_cxtmgt_resp_data <= `TD 0;
                        o_rtc_cxtmgt_resp_wr_en <= `TD 1;
                        ov_rtc_cxtmgt_resp_data <= `TD  qv_tmp_req;
                        o_rrc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rrc_cxtmgt_resp_data <= `TD 0;
                        o_ee_cxtmgt_resp_wr_en <= `TD 0;
                        ov_ee_cxtmgt_resp_data <= `TD 0;
                        o_fe_cxtmgt_resp_wr_en <= `TD 0;
                        ov_fe_cxtmgt_resp_data <= `TD 0;                        
                    end else begin
                        o_db_cxtmgt_resp_wr_en <= `TD 0;
                        ov_db_cxtmgt_resp_data <= `TD 0;
                        o_wp_cxtmgt_resp_wr_en <= `TD 0;
                        ov_wp_cxtmgt_resp_data <= `TD 0;
                        o_rtc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rtc_cxtmgt_resp_data <= `TD 0;
                        o_rrc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rrc_cxtmgt_resp_data <= `TD 0;
                        o_ee_cxtmgt_resp_wr_en <= `TD 0;
                        ov_ee_cxtmgt_resp_data <= `TD 0;
                        o_fe_cxtmgt_resp_wr_en <= `TD 0;
                        ov_fe_cxtmgt_resp_data <= `TD 0;
                    end
                end
                //Doorbell Processing req has the same cmd resp as req format
                {RESP_OUT,`RD_QP_CTX,`RD_QP_SST}:begin
                    if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                        o_db_cxtmgt_resp_wr_en <= `TD 1;
                        ov_db_cxtmgt_resp_data <= `TD qv_tmp_req;
                        o_wp_cxtmgt_resp_wr_en <= `TD 0;
                        ov_wp_cxtmgt_resp_data <= `TD 0;
                        o_rtc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rtc_cxtmgt_resp_data <= `TD 0;
                        o_rrc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rrc_cxtmgt_resp_data <= `TD 0;
                        o_ee_cxtmgt_resp_wr_en <= `TD 0;
                        ov_ee_cxtmgt_resp_data <= `TD 0;
                        o_fe_cxtmgt_resp_wr_en <= `TD 0;
                        ov_fe_cxtmgt_resp_data <= `TD 0; 
                    end else begin
                        o_db_cxtmgt_resp_wr_en <= `TD 0;
                        ov_db_cxtmgt_resp_data <= `TD 0;
                        o_wp_cxtmgt_resp_wr_en <= `TD 0;
                        ov_wp_cxtmgt_resp_data <= `TD 0;
                        o_rtc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rtc_cxtmgt_resp_data <= `TD 0;
                        o_rrc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rrc_cxtmgt_resp_data <= `TD 0;
                        o_ee_cxtmgt_resp_wr_en <= `TD 0;
                        ov_ee_cxtmgt_resp_data <= `TD 0;
                        o_fe_cxtmgt_resp_wr_en <= `TD 0;
                        ov_fe_cxtmgt_resp_data <= `TD 0;
                    end
                end
                //Execution Engine req has the same cmd resp as req format
                {RESP_OUT,`RD_QP_CTX,`RD_QP_RST}:begin
                    if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full && (qv_read_ram_cnt == 2'b11)) begin
                        o_db_cxtmgt_resp_wr_en <= `TD 0;
                        ov_db_cxtmgt_resp_data <= `TD 0;
                        o_wp_cxtmgt_resp_wr_en <= `TD 0;
                        ov_wp_cxtmgt_resp_data <= `TD 0;
                        o_rtc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rtc_cxtmgt_resp_data <= `TD 0;
                        o_rrc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rrc_cxtmgt_resp_data <= `TD 0;
                        o_ee_cxtmgt_resp_wr_en <= `TD 1;
                        ov_ee_cxtmgt_resp_data <= `TD qv_tmp_req;
                        o_fe_cxtmgt_resp_wr_en <= `TD 0;
                        ov_fe_cxtmgt_resp_data <= `TD 0;
                    end else begin
                        o_db_cxtmgt_resp_wr_en <= `TD 0;
                        ov_db_cxtmgt_resp_data <= `TD 0;
                        o_wp_cxtmgt_resp_wr_en <= `TD 0;
                        ov_wp_cxtmgt_resp_data <= `TD 0;
                        o_rtc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rtc_cxtmgt_resp_data <= `TD 0;
                        o_rrc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rrc_cxtmgt_resp_data <= `TD 0;
                        o_ee_cxtmgt_resp_wr_en <= `TD 0;
                        ov_ee_cxtmgt_resp_data <= `TD 0;
                        o_fe_cxtmgt_resp_wr_en <= `TD 0;
                        ov_fe_cxtmgt_resp_data <= `TD 0;
                    end
                end
                //WQE Parser req has the same cmd resp as req format
                {RESP_OUT,`RD_QP_CTX,`RD_QP_STATE}:begin
                    if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                        o_db_cxtmgt_resp_wr_en <= `TD 0;
                        ov_db_cxtmgt_resp_data <= `TD 0;
                        o_wp_cxtmgt_resp_wr_en <= `TD 1;
                        ov_wp_cxtmgt_resp_data <= `TD qv_tmp_req;
                        o_rtc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rtc_cxtmgt_resp_data <= `TD 0;
                        o_rrc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rrc_cxtmgt_resp_data <= `TD 0;
                        o_ee_cxtmgt_resp_wr_en <= `TD 0;
                        ov_ee_cxtmgt_resp_data <= `TD 0;
                        o_fe_cxtmgt_resp_wr_en <= `TD 0;
                        ov_fe_cxtmgt_resp_data <= `TD 0;
                    end else begin
                        o_db_cxtmgt_resp_wr_en <= `TD 0;
                        ov_db_cxtmgt_resp_data <= `TD 0;
                        o_wp_cxtmgt_resp_wr_en <= `TD 0;
                        ov_wp_cxtmgt_resp_data <= `TD 0;
                        o_rtc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rtc_cxtmgt_resp_data <= `TD 0;
                        o_rrc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rrc_cxtmgt_resp_data <= `TD 0;
                        o_ee_cxtmgt_resp_wr_en <= `TD 0;
                        ov_ee_cxtmgt_resp_data <= `TD 0;
                        o_fe_cxtmgt_resp_wr_en <= `TD 0;
                        ov_fe_cxtmgt_resp_data <= `TD 0;
                    end
                end
                //RRC req has the same cmd resp as req format
                {RESP_OUT,`RD_CQ_CTX,`RD_CQ_CST}:begin
                    /*Spygalss*/
                    //if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                    if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full && (qv_read_ram_cnt == 2'b11)) begin
                    /*Action = Modify*/
                        o_db_cxtmgt_resp_wr_en <= `TD 0;
                        ov_db_cxtmgt_resp_data <= `TD 0;
                        o_wp_cxtmgt_resp_wr_en <= `TD 0;
                        ov_wp_cxtmgt_resp_data <= `TD 0;
                        o_rtc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rtc_cxtmgt_resp_data <= `TD 0;
                        o_rrc_cxtmgt_resp_wr_en <= `TD 1;
                        ov_rrc_cxtmgt_resp_data <= `TD qv_tmp_req;
                        o_ee_cxtmgt_resp_wr_en <= `TD 0;
                        ov_ee_cxtmgt_resp_data <= `TD 0;
                        o_fe_cxtmgt_resp_wr_en <= `TD 0;
                        ov_fe_cxtmgt_resp_data <= `TD 0;
                    end else begin
                        o_db_cxtmgt_resp_wr_en <= `TD 0;
                        ov_db_cxtmgt_resp_data <= `TD 0;
                        o_wp_cxtmgt_resp_wr_en <= `TD 0;
                        ov_wp_cxtmgt_resp_data <= `TD 0;
                        o_rtc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rtc_cxtmgt_resp_data <= `TD 0;
                        o_rrc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rrc_cxtmgt_resp_data <= `TD 0;
                        o_ee_cxtmgt_resp_wr_en <= `TD 0;
                        ov_ee_cxtmgt_resp_data <= `TD 0;
                        o_fe_cxtmgt_resp_wr_en <= `TD 0;
                        ov_fe_cxtmgt_resp_data <= `TD 0;
                    end
                end
                //FrameEncap req has the same cmd resp as req format
                {RESP_OUT,`RD_QP_CTX,`RD_ENCAP}:begin
                    if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                        o_db_cxtmgt_resp_wr_en <= `TD 0;
                        ov_db_cxtmgt_resp_data <= `TD 0;
                        o_wp_cxtmgt_resp_wr_en <= `TD 0;
                        ov_wp_cxtmgt_resp_data <= `TD 0;
                        o_rtc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rtc_cxtmgt_resp_data <= `TD 0;
                        o_rrc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rrc_cxtmgt_resp_data <= `TD 0;
                        o_ee_cxtmgt_resp_wr_en <= `TD 0;
                        ov_ee_cxtmgt_resp_data <= `TD 0;
                        o_fe_cxtmgt_resp_wr_en <= `TD 1;
                        ov_fe_cxtmgt_resp_data <= `TD qv_tmp_req; 
                    end else begin
                        o_db_cxtmgt_resp_wr_en <= `TD 0;
                        ov_db_cxtmgt_resp_data <= `TD 0;
                        o_wp_cxtmgt_resp_wr_en <= `TD 0;
                        ov_wp_cxtmgt_resp_data <= `TD 0;
                        o_rtc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rtc_cxtmgt_resp_data <= `TD 0;
                        o_rrc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rrc_cxtmgt_resp_data <= `TD 0;
                        o_ee_cxtmgt_resp_wr_en <= `TD 0;
                        ov_ee_cxtmgt_resp_data <= `TD 0;
                        o_fe_cxtmgt_resp_wr_en <= `TD 0;
                        ov_fe_cxtmgt_resp_data <= `TD 0;
                    end
                end
                //RTC req has the same cmd resp as req format
                {RESP_OUT,`WR_QP_CTX,`WR_QP_NPST}:begin
                    if (!selected_resp_cmd_fifo_prog_full && !key_ctx_req_mdt_prog_full) begin
                        o_db_cxtmgt_resp_wr_en <= `TD 0;
                        ov_db_cxtmgt_resp_data <= `TD 0;
                        o_wp_cxtmgt_resp_wr_en <= `TD 0;
                        ov_wp_cxtmgt_resp_data <= `TD 0;
                        //Modified by YangFan
                        // o_rtc_cxtmgt_resp_wr_en <= `TD 1;
                        // ov_rtc_cxtmgt_resp_data <= `TD  qv_tmp_req;
                        o_rtc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rtc_cxtmgt_resp_data <= `TD 0;
                        o_rrc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rrc_cxtmgt_resp_data <= `TD 0;
                        o_ee_cxtmgt_resp_wr_en <= `TD 0;
                        ov_ee_cxtmgt_resp_data <= `TD 0;
                        o_fe_cxtmgt_resp_wr_en <= `TD 0;
                        ov_fe_cxtmgt_resp_data <= `TD 0;
                    end else begin
                        o_db_cxtmgt_resp_wr_en <= `TD 0;
                        ov_db_cxtmgt_resp_data <= `TD 0;
                        o_wp_cxtmgt_resp_wr_en <= `TD 0;
                        ov_wp_cxtmgt_resp_data <= `TD 0;
                        o_rtc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rtc_cxtmgt_resp_data <= `TD 0;
                        o_rrc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rrc_cxtmgt_resp_data <= `TD 0;
                        o_ee_cxtmgt_resp_wr_en <= `TD 0;
                        ov_ee_cxtmgt_resp_data <= `TD 0;
                        o_fe_cxtmgt_resp_wr_en <= `TD 0;
                        ov_fe_cxtmgt_resp_data <= `TD 0;
                    end
                end
                //RRC req has the same cmd resp as req format
                {RESP_OUT,`WR_QP_CTX,`WR_QP_UAPST}:begin
                    if (!selected_resp_cmd_fifo_prog_full && !key_ctx_req_mdt_prog_full) begin
                        o_db_cxtmgt_resp_wr_en <= `TD 0;
                        ov_db_cxtmgt_resp_data <= `TD 0;
                        o_wp_cxtmgt_resp_wr_en <= `TD 0;
                        ov_wp_cxtmgt_resp_data <= `TD 0;
                        o_rtc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rtc_cxtmgt_resp_data <= `TD 0;
                        //Modified by YangFan
                        // o_rrc_cxtmgt_resp_wr_en <= `TD 1;
                        // ov_rrc_cxtmgt_resp_data <= `TD qv_tmp_req;
                        o_rrc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rrc_cxtmgt_resp_data <= `TD 0;
                        o_ee_cxtmgt_resp_wr_en <= `TD 0;
                        ov_ee_cxtmgt_resp_data <= `TD 0;
                        o_fe_cxtmgt_resp_wr_en <= `TD 0;
                        ov_fe_cxtmgt_resp_data <= `TD 0;
                    end else begin
                        o_db_cxtmgt_resp_wr_en <= `TD 0;
                        ov_db_cxtmgt_resp_data <= `TD 0;
                        o_wp_cxtmgt_resp_wr_en <= `TD 0;
                        ov_wp_cxtmgt_resp_data <= `TD 0;
                        o_rtc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rtc_cxtmgt_resp_data <= `TD 0;
                        o_rrc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rrc_cxtmgt_resp_data <= `TD 0;
                        o_ee_cxtmgt_resp_wr_en <= `TD 0;
                        ov_ee_cxtmgt_resp_data <= `TD 0;
                        o_fe_cxtmgt_resp_wr_en <= `TD 0;
                        ov_fe_cxtmgt_resp_data <= `TD 0;
                    end
                end
                //EE req has the same cmd resp as req format
                {RESP_OUT,`WR_QP_CTX,`WR_QP_EPST}:begin
                    if (!selected_resp_cmd_fifo_prog_full && !key_ctx_req_mdt_prog_full) begin
                        o_db_cxtmgt_resp_wr_en <= `TD 0;
                        ov_db_cxtmgt_resp_data <= `TD 0;
                        o_wp_cxtmgt_resp_wr_en <= `TD 0;
                        ov_wp_cxtmgt_resp_data <= `TD 0;
                        o_rtc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rtc_cxtmgt_resp_data <= `TD 0;
                        o_rrc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rrc_cxtmgt_resp_data <= `TD 0;
                        //Modified by YangFan
                        // o_ee_cxtmgt_resp_wr_en <= `TD 1;
                        // ov_ee_cxtmgt_resp_data <= `TD qv_tmp_req;
                        o_ee_cxtmgt_resp_wr_en <= `TD 0;
                        ov_ee_cxtmgt_resp_data <= `TD 0;
                        o_fe_cxtmgt_resp_wr_en <= `TD 0;
                        ov_fe_cxtmgt_resp_data <= `TD 0;
                    end else begin
                        o_db_cxtmgt_resp_wr_en <= `TD 0;
                        ov_db_cxtmgt_resp_data <= `TD 0;
                        o_wp_cxtmgt_resp_wr_en <= `TD 0;
                        ov_wp_cxtmgt_resp_data <= `TD 0;
                        o_rtc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rtc_cxtmgt_resp_data <= `TD 0;
                        o_rrc_cxtmgt_resp_wr_en <= `TD 0;
                        ov_rrc_cxtmgt_resp_data <= `TD 0;
                        o_ee_cxtmgt_resp_wr_en <= `TD 0;
                        ov_ee_cxtmgt_resp_data <= `TD 0;
                        o_fe_cxtmgt_resp_wr_en <= `TD 0;
                        ov_fe_cxtmgt_resp_data <= `TD 0;
                    end
                end
                default: begin
                    o_db_cxtmgt_resp_wr_en <= `TD 0;
                    ov_db_cxtmgt_resp_data <= `TD 0;
                    o_wp_cxtmgt_resp_wr_en <= `TD 0;
                    ov_wp_cxtmgt_resp_data <= `TD 0;
                    o_rtc_cxtmgt_resp_wr_en <= `TD 0;
                    ov_rtc_cxtmgt_resp_data <= `TD 0;
                    o_rrc_cxtmgt_resp_wr_en <= `TD 0;
                    ov_rrc_cxtmgt_resp_data <= `TD 0;
                    o_ee_cxtmgt_resp_wr_en <= `TD 0;
                    ov_ee_cxtmgt_resp_data <= `TD 0;
                    o_fe_cxtmgt_resp_wr_en <= `TD 0;
                    ov_fe_cxtmgt_resp_data <= `TD 0;
                end
            endcase
        end
    end

    wire [4:0] rd_eqn;
    assign rd_eqn = eqn_rd_data[4:0];
    //response to dest resp ctx fifo
    reg [32*13-1-24:0]    q_ov_ee_cxtmgt_resp_cxt_data;
    assign ov_ee_cxtmgt_resp_cxt_data = {
        q_ov_ee_cxtmgt_resp_cxt_data[32*13-1-24:264],
        24'b0,q_ov_ee_cxtmgt_resp_cxt_data[263:0]
    };
    reg [32*11-1-5-8-24:0]     q_ov_rrc_cxtmgt_resp_cxt_data;
    assign ov_rrc_cxtmgt_resp_cxt_data = {
        q_ov_rrc_cxtmgt_resp_cxt_data[32*11-1-5-8-24:312-8-29],
        8'b0,q_ov_rrc_cxtmgt_resp_cxt_data[303-29:224-29],
        24'b0,q_ov_rrc_cxtmgt_resp_cxt_data[199-5:8-5],
        5'b0,q_ov_rrc_cxtmgt_resp_cxt_data[2:0]
    };
    reg [9*32-1-5-24-8-16:0]   q_ov_rtc_cxtmgt_resp_cxt_data;
    assign ov_rtc_cxtmgt_resp_cxt_data = {
        16'b0,q_ov_rtc_cxtmgt_resp_cxt_data[271-5-24-8:184-5-24-8],
        8'b0, q_ov_rtc_cxtmgt_resp_cxt_data[175-5-24:96-5-24],
        24'b0,q_ov_rtc_cxtmgt_resp_cxt_data[71-5:8-5],
        5'b0, q_ov_rtc_cxtmgt_resp_cxt_data[2:0]
    };
    reg [127-64-21:0]     q_ov_wp_cxtmgt_resp_cxt_data;
    assign ov_wp_cxtmgt_resp_cxt_data = {
        64'b0,q_ov_wp_cxtmgt_resp_cxt_data[63-21:29-21],
        21'b0,q_ov_wp_cxtmgt_resp_cxt_data[7:0]
    }; 

    reg     [255-64-24-8:0]     q_ov_db_cxtmgt_resp_cxt_data;
    // q_ov_db_cxtmgt_resp_cxt_data <= `TD {
        // 64'b0,qp_send_wqe_length_rd_data,
        // 24'b0,qp_sq_entry_sz_log_rd_data,qp_pd_rd_data,qp_send_wqe_base_lkey_rd_data,
        // 8'b0,qp_mtu_rd_data,qp_port_key_rd_data[15:0],qp_remote_qpn_rd_data[23:0],qp_serv_tpye_rd_data};
    assign ov_db_cxtmgt_resp_cxt_data = {
        64'b0,q_ov_db_cxtmgt_resp_cxt_data[191-24-8:160-24-8],
        24'b0,q_ov_db_cxtmgt_resp_cxt_data[135-8:64-8],
        8'b0,q_ov_db_cxtmgt_resp_cxt_data[55:0]
    };
    
    reg     [255-65:0]     q_ov_fe_cxtmgt_resp_cxt_data;
    // q_ov_fe_cxtmgt_resp_cxt_data  <= `TD {
        // 64'b0,qp_dmac_rd_data[47:16],qp_dmac_rd_data[15:0],qp_smac_rd_data[47:32],qp_smac_rd_data[31:0],qp_dip_rd_data,qp_sip_rd_data,qp_port_key_rd_data[15:0],qp_sl_tclass_rd_data[3:0],
        // 1'b0,qp_port_key_rd_data[26:24]};
    assign ov_fe_cxtmgt_resp_cxt_data = {
        64'b0,q_ov_fe_cxtmgt_resp_cxt_data[255-65:3],
        1'b0,q_ov_fe_cxtmgt_resp_cxt_data[2:0]
    };

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            o_db_cxtmgt_resp_cxt_wr_en  <= `TD 0;
            q_ov_db_cxtmgt_resp_cxt_data  <= `TD 0;
            o_wp_cxtmgt_resp_cxt_wr_en  <= `TD 0;
            q_ov_wp_cxtmgt_resp_cxt_data  <= `TD 0;
            o_rtc_cxtmgt_resp_cxt_wr_en <= `TD 0;
            q_ov_rtc_cxtmgt_resp_cxt_data <= `TD 0;
            o_rrc_cxtmgt_resp_cxt_wr_en <= `TD 0;
            q_ov_rrc_cxtmgt_resp_cxt_data <= `TD 0;
            o_ee_cxtmgt_resp_cxt_wr_en  <= `TD 0;
            q_ov_ee_cxtmgt_resp_cxt_data  <= `TD 0;
            o_fe_cxtmgt_resp_cxt_wr_en  <= `TD 0;
            q_ov_fe_cxtmgt_resp_cxt_data  <= `TD 0;
        end
        else begin
            /*Spyglass*/
            //case ({wv_req_reg_type,wv_req_reg_op})
            case ({fsm_cs,wv_req_reg_type,wv_req_reg_op})
                //Doorbell Processing req has resp ctx:PD, Lkey, Pkey, PMTU, Service Type, DestQPN
                {RESP_OUT,`RD_QP_CTX,`RD_QP_SST}:begin
                    if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                        o_db_cxtmgt_resp_cxt_wr_en <= `TD 1;
                        // q_ov_db_cxtmgt_resp_cxt_data <= `TD {64'b0,qp_send_wqe_length_rd_data,24'b0,qp_sq_entry_sz_log_rd_data,qp_pd_rd_data,qp_send_wqe_base_lkey_rd_data,8'b0,qp_mtu_rd_data,qp_port_key_rd_data[15:0],qp_remote_qpn_rd_data[23:0],qp_serv_tpye_rd_data};
                        q_ov_db_cxtmgt_resp_cxt_data <= `TD {qp_send_wqe_length_rd_data,qp_sq_entry_sz_log_rd_data,qp_pd_rd_data,qp_send_wqe_base_lkey_rd_data,qp_mtu_rd_data,qp_port_key_rd_data[15:0],qp_remote_qpn_rd_data[23:0],qp_serv_tpye_rd_data};
                        o_wp_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_wp_cxtmgt_resp_cxt_data <= `TD 0;
                        o_rtc_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_rtc_cxtmgt_resp_cxt_data <= `TD 0;
                        o_rrc_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_rrc_cxtmgt_resp_cxt_data <= `TD 0;
                        o_ee_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_ee_cxtmgt_resp_cxt_data <= `TD 0; 
                        o_fe_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_fe_cxtmgt_resp_cxt_data  <= `TD 0;
                    end else begin
                        o_db_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_db_cxtmgt_resp_cxt_data <= `TD 0;
                        o_wp_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_wp_cxtmgt_resp_cxt_data <= `TD 0;
                        o_rtc_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_rtc_cxtmgt_resp_cxt_data <= `TD 0;
                        o_rrc_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_rrc_cxtmgt_resp_cxt_data <= `TD 0;
                        o_ee_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_ee_cxtmgt_resp_cxt_data <= `TD 0;
                        o_fe_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_fe_cxtmgt_resp_cxt_data  <= `TD 0;
                    end
                end
                //WQE Parser req has resp ctx: QP state
                {RESP_OUT,`RD_QP_CTX,`RD_QP_STATE}:begin
                    if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                        o_db_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_db_cxtmgt_resp_cxt_data <= `TD 0;
                        o_wp_cxtmgt_resp_cxt_wr_en <= `TD 1;
                        // q_ov_wp_cxtmgt_resp_cxt_data <= `TD {64'b0,qp_send_wqe_length_rd_data,qp_state_rd_data[2:0],21'b0,qp_sq_entry_sz_log_rd_data};
                        q_ov_wp_cxtmgt_resp_cxt_data <= `TD {qp_send_wqe_length_rd_data,qp_state_rd_data[2:0],qp_sq_entry_sz_log_rd_data};
                        o_rtc_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_rtc_cxtmgt_resp_cxt_data <= `TD 0;
                        o_rrc_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_rrc_cxtmgt_resp_cxt_data <= `TD 0;
                        o_ee_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_ee_cxtmgt_resp_cxt_data <= `TD 0;
                        o_fe_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_fe_cxtmgt_resp_cxt_data  <= `TD 0;
                    end else begin
                        o_db_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_db_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_wp_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_wp_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_rtc_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_rtc_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_rrc_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_rrc_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_ee_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_ee_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_fe_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_fe_cxtmgt_resp_cxt_data  <= `TD 0;
                    end
                end    
                // TODO: Add EQ info
                //RTC req has resp ctx: NextPSN & QP state,SCQ_LKey,SCQ_Length,SCQ PD,SCQN,RLID[15:0]
                {RESP_OUT,`RD_QP_CTX,`RD_QP_NPST}:begin
                    if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full && (qv_read_ram_cnt == 2'b11)) begin
                        o_db_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_db_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_wp_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_wp_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_rtc_cxtmgt_resp_cxt_wr_en <= `TD 1;
                        // q_ov_rtc_cxtmgt_resp_cxt_data <= `TD {16'b0,qp_dmac_rd_data[15:0],8'b0,qp_cqn_send_rd_data[23:0],cq_pd_rd_data,24'b0,cq_sz_log_rd_data,cq_lkey_rd_data,qp_next_psn_rd_data[23:0],5'b0,qp_state_rd_data[2:0]};
                        // 32*9 bits
                        // q_ov_rtc_cxtmgt_resp_cxt_data <= `TD eqn_valid[rd_eqn] ? {16'b0,eq_intr[rd_eqn],eq_pd[rd_eqn],eq_lkey[rd_eqn],eq_sz_log[rd_eqn],8'b0,qp_dmac_rd_data[15:0],eqn_rd_data,qp_cqn_send_rd_data[23:0],cq_pd_rd_data,24'b0,cq_sz_log_rd_data,cq_lkey_rd_data,qp_next_psn_rd_data[23:0],5'b0,qp_state_rd_data[2:0]} : 
                        // {16'b0,16'b0,32'b0,32'b0,8'b0,8'b0,qp_dmac_rd_data[15:0],eqn_rd_data,qp_cqn_send_rd_data[23:0],cq_pd_rd_data,24'b0,cq_sz_log_rd_data,cq_lkey_rd_data,qp_next_psn_rd_data[23:0],5'b0,qp_state_rd_data[2:0]};
                        q_ov_rtc_cxtmgt_resp_cxt_data <= `TD eqn_valid[rd_eqn] ? {eq_intr[rd_eqn],eq_pd[rd_eqn],eq_lkey[rd_eqn],eq_sz_log[rd_eqn],qp_dmac_rd_data[15:0],eqn_rd_data,qp_cqn_send_rd_data[23:0],cq_pd_rd_data,cq_sz_log_rd_data,cq_lkey_rd_data,qp_next_psn_rd_data[23:0],qp_state_rd_data[2:0]} : 
                        {16'b0,32'b0,32'b0,8'b0,qp_dmac_rd_data[15:0],eqn_rd_data,qp_cqn_send_rd_data[23:0],cq_pd_rd_data,cq_sz_log_rd_data,cq_lkey_rd_data,qp_next_psn_rd_data[23:0],qp_state_rd_data[2:0]};
                        o_rrc_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_rrc_cxtmgt_resp_cxt_data <= `TD 0;
                        o_ee_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_ee_cxtmgt_resp_cxt_data  <= `TD 0;  
                        o_fe_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_fe_cxtmgt_resp_cxt_data  <= `TD 0;                      
                    end else begin
                        o_db_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_db_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_wp_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_wp_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_rtc_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_rtc_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_rrc_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_rrc_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_ee_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_ee_cxtmgt_resp_cxt_data  <= `TD 0; 
                        o_fe_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_fe_cxtmgt_resp_cxt_data  <= `TD 0;  
                    end
                end
                //RRC req has resp ctx:CQ_Lkey、NextPSN、UnAckedPSN、QP State
                // TODO: Add EQ info
                {RESP_OUT,`RD_CQ_CTX,`RD_CQ_CST}:begin
                    /*Spyglass*/
                    //if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full ) begin
                    if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full && (qv_read_ram_cnt == 2'b11)) begin
                        /*Action = Modify*/
                        o_db_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_db_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_wp_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_wp_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_rtc_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_rtc_cxtmgt_resp_cxt_data <= `TD 0;
                        o_rrc_cxtmgt_resp_cxt_wr_en <= `TD 1;
                        // q_ov_rrc_cxtmgt_resp_cxt_data <= `TD {8'b0,qp_cqn_send_rd_data[23:0],24'b0,cq_sz_log_rd_data,cq_pd_rd_data,qp_pd_rd_data,cq_lkey_rd_data,qp_remote_qpn_rd_data[23:0],qp_dmac_rd_data[15:8],qp_next_psn_rd_data[23:0],qp_dmac_rd_data[7:0],qp_unacked_psn_rd_data[23:0],5'b0,qp_state_rd_data[2:0]};
                        //32*11 bits
                        // q_ov_rrc_cxtmgt_resp_cxt_data <= `TD eqn_valid[rd_eqn] ? {eq_pd[rd_eqn],eq_sz_log[rd_eqn],8'b0,eq_intr[rd_eqn],eq_lkey[rd_eqn],eqn_rd_data,qp_cqn_send_rd_data[23:0],24'b0,cq_sz_log_rd_data,cq_pd_rd_data,qp_pd_rd_data,cq_lkey_rd_data,qp_remote_qpn_rd_data[23:0],qp_dmac_rd_data[15:8],qp_next_psn_rd_data[23:0],qp_dmac_rd_data[7:0],qp_unacked_psn_rd_data[23:0],5'b0,qp_state_rd_data[2:0]} :
                        // {32'b0,8'b0,8'b0,16'b0,32'b0,eqn_rd_data,qp_cqn_send_rd_data[23:0],24'b0,cq_sz_log_rd_data,cq_pd_rd_data,qp_pd_rd_data,cq_lkey_rd_data,qp_remote_qpn_rd_data[23:0],qp_dmac_rd_data[15:8],qp_next_psn_rd_data[23:0],qp_dmac_rd_data[7:0],qp_unacked_psn_rd_data[23:0],5'b0,qp_state_rd_data[2:0]};
                        q_ov_rrc_cxtmgt_resp_cxt_data <= `TD eqn_valid[rd_eqn] ? {eq_pd[rd_eqn],eq_sz_log[rd_eqn],eq_intr[rd_eqn],eq_lkey[rd_eqn],eqn_rd_data,qp_cqn_send_rd_data[23:0],cq_sz_log_rd_data,cq_pd_rd_data,qp_pd_rd_data,cq_lkey_rd_data,qp_remote_qpn_rd_data[23:0],qp_dmac_rd_data[15:8],qp_next_psn_rd_data[23:0],qp_dmac_rd_data[7:0],qp_unacked_psn_rd_data[23:0],qp_state_rd_data[2:0]} :
                        {32'b0,8'b0,16'b0,32'b0,eqn_rd_data,qp_cqn_send_rd_data[23:0],cq_sz_log_rd_data,cq_pd_rd_data,qp_pd_rd_data,cq_lkey_rd_data,qp_remote_qpn_rd_data[23:0],qp_dmac_rd_data[15:8],qp_next_psn_rd_data[23:0],qp_dmac_rd_data[7:0],qp_unacked_psn_rd_data[23:0],qp_state_rd_data[2:0]};
                        o_ee_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_ee_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_fe_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_fe_cxtmgt_resp_cxt_data  <= `TD 0;
                    end else begin
                        o_db_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_db_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_wp_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_wp_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_rtc_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_rtc_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_rrc_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_rrc_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_ee_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_ee_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_fe_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_fe_cxtmgt_resp_cxt_data  <= `TD 0;
                    end
                end
                //Execution Engine req has resp ctx: Pkey、PMTU、PD、Lkey、Expected PSN、RNR Timer、QP State;
                // TODO: Add EQ info
                {RESP_OUT,`RD_QP_CTX,`RD_QP_RST}:begin
                    if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full && (qv_read_ram_cnt == 2'b11)) begin
                        o_db_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_db_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_wp_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_wp_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_rtc_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_rtc_cxtmgt_resp_cxt_data <= `TD 0;
                        o_rrc_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_rrc_cxtmgt_resp_cxt_data <= `TD 0;
                        o_ee_cxtmgt_resp_cxt_wr_en  <= `TD 1;
                        // q_ov_ee_cxtmgt_resp_cxt_data  <= `TD {qp_dmac_rd_data[15:8],qp_cqn_recv_rd_data[23:0],24'b0,cq_sz_log_rd_data,qp_recv_wqe_length_rd_data,cq_pd_rd_data,qp_pd_rd_data,cq_lkey_rd_data,qp_recv_wqe_base_lkey_rd_data,qp_rq_entry_sz_log_rd_data,qp_remote_qpn_rd_data[23:0],qp_dmac_rd_data[7:0],qp_mtu_rd_data,qp_port_key_rd_data[15:0],qp_expect_psn_rd_data[23:0],qp_rnr_retry_rd_data[4:0],qp_state_rd_data[2:0]};
                        //32*13 bits
                        // q_ov_ee_cxtmgt_resp_cxt_data  <= `TD eqn_valid[rd_eqn] ? {eq_pd[rd_eqn],eq_intr[rd_eqn],eqn_rd_data,eq_sz_log[rd_eqn],eq_lkey[rd_eqn],qp_dmac_rd_data[15:8],qp_cqn_recv_rd_data[23:0],24'b0,cq_sz_log_rd_data,qp_recv_wqe_length_rd_data,cq_pd_rd_data,qp_pd_rd_data,cq_lkey_rd_data,qp_recv_wqe_base_lkey_rd_data,qp_rq_entry_sz_log_rd_data,qp_remote_qpn_rd_data[23:0],qp_dmac_rd_data[7:0],qp_mtu_rd_data,qp_port_key_rd_data[15:0],qp_expect_psn_rd_data[23:0],qp_rnr_retry_rd_data[4:0],qp_state_rd_data[2:0]} :
                        // {32'b0,16'b0,eqn_rd_data,8'b0,32'b0,qp_dmac_rd_data[15:8],qp_cqn_recv_rd_data[23:0],24'b0,cq_sz_log_rd_data,qp_recv_wqe_length_rd_data,cq_pd_rd_data,qp_pd_rd_data,cq_lkey_rd_data,qp_recv_wqe_base_lkey_rd_data,qp_rq_entry_sz_log_rd_data,qp_remote_qpn_rd_data[23:0],qp_dmac_rd_data[7:0],qp_mtu_rd_data,qp_port_key_rd_data[15:0],qp_expect_psn_rd_data[23:0],qp_rnr_retry_rd_data[4:0],qp_state_rd_data[2:0]};
                        q_ov_ee_cxtmgt_resp_cxt_data  <= `TD eqn_valid[rd_eqn] ? {eq_pd[rd_eqn],eq_intr[rd_eqn],eqn_rd_data,eq_sz_log[rd_eqn],eq_lkey[rd_eqn],qp_dmac_rd_data[15:8],qp_cqn_recv_rd_data[23:0],cq_sz_log_rd_data,qp_recv_wqe_length_rd_data,cq_pd_rd_data,qp_pd_rd_data,cq_lkey_rd_data,qp_recv_wqe_base_lkey_rd_data,qp_rq_entry_sz_log_rd_data,qp_remote_qpn_rd_data[23:0],qp_dmac_rd_data[7:0],qp_mtu_rd_data,qp_port_key_rd_data[15:0],qp_expect_psn_rd_data[23:0],qp_rnr_retry_rd_data[4:0],qp_state_rd_data[2:0]} :
                        {32'b0,16'b0,eqn_rd_data,8'b0,32'b0,qp_dmac_rd_data[15:8],qp_cqn_recv_rd_data[23:0],cq_sz_log_rd_data,qp_recv_wqe_length_rd_data,cq_pd_rd_data,qp_pd_rd_data,cq_lkey_rd_data,qp_recv_wqe_base_lkey_rd_data,qp_rq_entry_sz_log_rd_data,qp_remote_qpn_rd_data[23:0],qp_dmac_rd_data[7:0],qp_mtu_rd_data,qp_port_key_rd_data[15:0],qp_expect_psn_rd_data[23:0],qp_rnr_retry_rd_data[4:0],qp_state_rd_data[2:0]};
                        o_fe_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_fe_cxtmgt_resp_cxt_data  <= `TD 0;
                    end else begin
                        o_db_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_db_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_wp_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_wp_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_rtc_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_rtc_cxtmgt_resp_cxt_data <= `TD 0;
                        o_rrc_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_rrc_cxtmgt_resp_cxt_data <= `TD 0;
                        o_ee_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_ee_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_fe_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_fe_cxtmgt_resp_cxt_data  <= `TD 0;
                    end
                end  
                //FrameEncap req has the same cmd resp as req format
                {RESP_OUT,`RD_QP_CTX,`RD_ENCAP}:begin
                    if (!selected_resp_cmd_fifo_prog_full && !selected_resp_ctx_fifo_prog_full) begin
                        o_db_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_db_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_wp_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_wp_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_rtc_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_rtc_cxtmgt_resp_cxt_data <= `TD 0;
                        o_rrc_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_rrc_cxtmgt_resp_cxt_data <= `TD 0;
                        o_ee_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_ee_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_fe_cxtmgt_resp_cxt_wr_en  <= `TD 1;
                        // q_ov_fe_cxtmgt_resp_cxt_data  <= `TD {64'b0,qp_dmac_rd_data[47:16],qp_dmac_rd_data[15:0],qp_smac_rd_data[47:32],qp_smac_rd_data[31:0],qp_dip_rd_data,qp_sip_rd_data,qp_port_key_rd_data[15:0],qp_sl_tclass_rd_data[3:0],1'b0,qp_port_key_rd_data[26:24]};
                        //q_ov_fe_cxtmgt_resp_cxt_data  <= `TD {qp_dmac_rd_data[47:16],qp_dmac_rd_data[15:0],qp_smac_rd_data[47:32],qp_smac_rd_data[31:0],qp_dip_rd_data,qp_sip_rd_data,qp_port_key_rd_data[15:0],qp_sl_tclass_rd_data[3:0],qp_port_key_rd_data[26:24]};
						//2023-0208 : Modified by YangFan
                        q_ov_fe_cxtmgt_resp_cxt_data  <= `TD {qp_dmac_rd_data[47:16],qp_dmac_rd_data[15:0],qp_smac_rd_data[47:32],qp_smac_rd_data[31:0],qp_dip_rd_data,qp_sip_rd_data,qp_port_key_rd_data[15:0],8'd0, qp_sl_tclass_rd_data[3:0],qp_port_key_rd_data[26:24]};
                    end else begin
                        o_db_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_db_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_wp_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_wp_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_rtc_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_rtc_cxtmgt_resp_cxt_data <= `TD 0;
                        o_rrc_cxtmgt_resp_cxt_wr_en <= `TD 0;
                        q_ov_rrc_cxtmgt_resp_cxt_data <= `TD 0;
                        o_ee_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_ee_cxtmgt_resp_cxt_data  <= `TD 0;
                        o_fe_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                        q_ov_fe_cxtmgt_resp_cxt_data  <= `TD 0;
                    end
                end              
                default: begin
                    o_db_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                    q_ov_db_cxtmgt_resp_cxt_data  <= `TD 0;
                    o_wp_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                    q_ov_wp_cxtmgt_resp_cxt_data  <= `TD 0;
                    o_rtc_cxtmgt_resp_cxt_wr_en <= `TD 0;
                    q_ov_rtc_cxtmgt_resp_cxt_data <= `TD 0;
                    o_rrc_cxtmgt_resp_cxt_wr_en <= `TD 0;
                    q_ov_rrc_cxtmgt_resp_cxt_data <= `TD 0;
                    o_ee_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                    q_ov_ee_cxtmgt_resp_cxt_data  <= `TD 0;
                    o_fe_cxtmgt_resp_cxt_wr_en  <= `TD 0;
                    q_ov_fe_cxtmgt_resp_cxt_data  <= `TD 0;
                end
            endcase
        end
    end

    //initiate ctxmdata lookup req to ctxmdata req fifo
        //| ---------------128bit-------------------------------------------------------|
        //|   type   |  opcode |   R      |   QPN   |    R   |  PSN   |  R     | State  | 
        //|    4 bit |  4 bit  |  24 bit  |  32 bit | 32 bit | 24 bit |  5 bit | 3 bit  |
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            key_ctx_req_mdt_wr_en <= `TD  0;
            key_ctx_req_mdt_din   <= `TD  0;
        end
        else begin
            case ({fsm_cs,wv_req_reg_type,wv_req_reg_op})
                //RTC req has ctxmadat req to update NextPSN, qp_state in host memory
                {RESP_OUT,`WR_QP_CTX,`WR_QP_NPST}:begin
                    if (!selected_resp_cmd_fifo_prog_full && !key_ctx_req_mdt_prog_full) begin
                        key_ctx_req_mdt_wr_en  <= `TD 1;
                        // key_ctx_req_mdt_din    <= `TD {qv_tmp_req[127:120],24'b0,19'b0,wv_req_reg_qpn,32'b0,qv_tmp_ctx_payload[31:8],4'b0, qv_tmp_ctx_payload[3:0]};
                        key_ctx_req_mdt_din    <= `TD {qv_tmp_req[127:120],wv_req_reg_qpn,qv_tmp_ctx_payload[31:8],qv_tmp_ctx_payload[3:0]};
                    end else begin
                        key_ctx_req_mdt_wr_en  <= `TD 0;
                        key_ctx_req_mdt_din    <= `TD 0;
                    end
                end
                //RRC req has the same cmd resp as req format
                {RESP_OUT,`WR_QP_CTX,`WR_QP_UAPST}:begin
                    if (!selected_resp_cmd_fifo_prog_full && !key_ctx_req_mdt_prog_full) begin
                        key_ctx_req_mdt_wr_en  <= `TD 1;
                        // key_ctx_req_mdt_din    <= `TD {qv_tmp_req[127:120],24'b0,19'b0,wv_req_reg_qpn,32'b0,qv_tmp_ctx_payload[31:8],4'b0, qv_tmp_ctx_payload[3:0]};
                        key_ctx_req_mdt_din    <= `TD {qv_tmp_req[127:120],wv_req_reg_qpn,qv_tmp_ctx_payload[31:8],qv_tmp_ctx_payload[3:0]};
                    end else begin
                        key_ctx_req_mdt_wr_en  <= `TD 0;
                        key_ctx_req_mdt_din    <= `TD 0;
                    end
                end
                //EE req has the same cmd resp as req format
                {RESP_OUT,`WR_QP_CTX,`WR_QP_EPST}:begin
                    if (!selected_resp_cmd_fifo_prog_full && !key_ctx_req_mdt_prog_full) begin
                        key_ctx_req_mdt_wr_en  <= `TD 1;
                        // key_ctx_req_mdt_din    <= `TD {qv_tmp_req[127:120],24'b0,19'b0,wv_req_reg_qpn,32'b0,qv_tmp_ctx_payload[31:8],4'b0, qv_tmp_ctx_payload[3:0]};
                        key_ctx_req_mdt_din    <= `TD {qv_tmp_req[127:120],wv_req_reg_qpn,qv_tmp_ctx_payload[31:8],qv_tmp_ctx_payload[3:0]};
                    end else begin
                        key_ctx_req_mdt_wr_en  <= `TD 0;
                        key_ctx_req_mdt_din    <= `TD 0;
                    end
                end
                default: begin
                    key_ctx_req_mdt_wr_en  <= `TD 0;
                    key_ctx_req_mdt_din    <= `TD 0;
                end
            endcase
        end
    end
    assign wv_key_ctx_req_mdt_din = {key_ctx_req_mdt_din[48:41],24'b0,19'b0,key_ctx_req_mdt_din[40:28],32'b0,key_ctx_req_mdt_din[27:4],4'b0,key_ctx_req_mdt_din[3:0]};
    // key_ctx_req_mdt_din    <= `TD {qv_tmp_req[127:120],24'b0,19'b0,wv_req_reg_qpn,32'b0,qv_tmp_ctx_payload[31:8],4'b0, qv_tmp_ctx_payload[3:0]};

//-----------------{key_qpc_data state mechine} end--------------------//
`ifdef CTX_DUG

    // /*****************Add for APB-slave regs**********************************/ 
        // reg receive_req,
        // reg                 o_db_cxtmgt_resp_wr_en,
        // reg     [127:0]     ov_db_cxtmgt_resp_data,
        // reg                 o_db_cxtmgt_resp_cxt_wr_en,
        // reg                 o_wp_cxtmgt_resp_wr_en,
        // reg     [127:0]     ov_wp_cxtmgt_resp_data,
        // reg                 o_wp_cxtmgt_resp_cxt_wr_en,
        // reg                 o_rtc_cxtmgt_resp_wr_en,
        // reg     [127:0]     ov_rtc_cxtmgt_resp_data,
        // reg                 o_rtc_cxtmgt_resp_cxt_wr_en,
        // reg                 o_rrc_cxtmgt_resp_wr_en,
        // reg     [127:0]     ov_rrc_cxtmgt_resp_data,
        // reg                 o_rrc_cxtmgt_resp_cxt_wr_en,
        // reg                 o_ee_cxtmgt_resp_wr_en,
        // reg     [127:0]     ov_ee_cxtmgt_resp_data,
        // reg                 o_ee_cxtmgt_resp_cxt_wr_en,
        // reg                 o_fe_cxtmgt_resp_wr_en,
        // reg     [127:0]     ov_fe_cxtmgt_resp_data,
        // reg                 o_fe_cxtmgt_resp_cxt_wr_en,
        // reg                         key_ctx_req_mdt_wr_en;
        // reg   [`HD_WIDTH-1-79:0]    key_ctx_req_mdt_din;
        // reg               qp_state_en;
        // reg               qp_state_wr_en;
        // reg    [INDEX-1 :0]   qp_state_addr;
        // reg    [3 : 0]    qp_state_wr_data;
        // reg               qp_serv_tpye_en; 
        // reg               qp_serv_tpye_wr_en;
        // reg    [INDEX-1 :0]   qp_serv_tpye_addr;
        // reg    [7 : 0]    qp_serv_tpye_wr_data;
        // reg                qp_mtu_en;
        // reg                qp_mtu_wr_en;
        // reg     [INDEX-1 :0]   qp_mtu_addr;
        // reg     [7 : 0]    qp_mtu_wr_data;
        // reg                qp_rnr_retry_en;
        // reg                qp_rnr_retry_wr_en;
        // reg     [INDEX-1 :0]   qp_rnr_retry_addr;
        // reg     [7 : 0]    qp_rnr_retry_wr_data;
        // reg               qp_local_qpn_en;
        // reg               qp_local_qpn_wr_en;
        // reg    [INDEX-1 :0]   qp_local_qpn_addr;
        // reg    [31 : 0]   qp_local_qpn_wr_data;
        // reg               qp_remote_qpn_en;
        // reg               qp_remote_qpn_wr_en;
        // reg    [INDEX-1 :0]   qp_remote_qpn_addr;
        // reg    [31 : 0]   qp_remote_qpn_wr_data;
        // reg               qp_port_key_en;
        // reg               qp_port_key_wr_en;
        // reg    [INDEX-1 :0]   qp_port_key_addr;
        // reg    [31 : 0]   qp_port_key_wr_data;
        // reg               qp_pd_en;
        // reg               qp_pd_wr_en;
        // reg    [INDEX-1 :0]   qp_pd_addr;
        // reg    [31 : 0]   qp_pd_wr_data;
        // reg               qp_sl_tclass_en;
        // reg               qp_sl_tclass_wr_en;
        // reg    [INDEX-1 :0]   qp_sl_tclass_addr;
        // reg    [31 : 0]   qp_sl_tclass_wr_data;
        // reg               qp_next_psn_en;
        // reg               qp_next_psn_wr_en;
        // reg    [INDEX-1 :0]   qp_next_psn_addr;
        // reg    [31 : 0]   qp_next_psn_wr_data;
        // reg               qp_cqn_send_en;
        // reg               qp_cqn_send_wr_en;
        // reg    [INDEX-1 :0]   qp_cqn_send_addr;
        // reg    [31 : 0]   qp_cqn_send_wr_data;
        // reg               qp_send_wqe_base_lkey_en;
        // reg               qp_send_wqe_base_lkey_wr_en;
        // reg    [INDEX-1 :0]   qp_send_wqe_base_lkey_addr;
        // reg    [31 : 0]   qp_send_wqe_base_lkey_wr_data;
        // reg               qp_unacked_psn_en;
        // reg               qp_unacked_psn_wr_en;
        // reg    [INDEX-1 :0]   qp_unacked_psn_addr;
        // reg    [31 : 0]   qp_unacked_psn_wr_data;
        // reg               qp_expect_psn_en;
        // reg               qp_expect_psn_wr_en;
        // reg    [INDEX-1 :0]   qp_expect_psn_addr;
        // reg    [31 : 0]   qp_expect_psn_wr_data;
        // reg               qp_recv_wqe_base_lkey_en;
        // reg               qp_recv_wqe_base_lkey_wr_en;
        // reg    [INDEX-1 :0]   qp_recv_wqe_base_lkey_addr;
        // reg    [31 : 0]   qp_recv_wqe_base_lkey_wr_data;
        // reg               cq_lkey_en;
        // reg               cq_lkey_wr_en;
        // reg    [INDEX-1 :0]   cq_lkey_addr;
        // reg    [31 : 0]   cq_lkey_wr_data;
        // reg                qp_rq_entry_sz_log_en;
        // reg                qp_rq_entry_sz_log_wr_en;
        // reg     [INDEX-1 :0]   qp_rq_entry_sz_log_addr;
        // reg     [7 : 0]    qp_rq_entry_sz_log_wr_data;
        // reg                qp_sq_entry_sz_log_en;
        // reg                qp_sq_entry_sz_log_wr_en;
        // reg     [INDEX-1 :0]   qp_sq_entry_sz_log_addr;
        // reg     [7 : 0]    qp_sq_entry_sz_log_wr_data;
        // reg                qp_smac_en;
        // reg                qp_smac_wr_en;
        // reg     [INDEX-1 :0]   qp_smac_addr;
        // reg     [47 : 0]   qp_smac_wr_data;
        // reg                qp_dmac_en;
        // reg                qp_dmac_wr_en;
        // reg     [INDEX-1 :0]   qp_dmac_addr;
        // reg     [47 : 0]   qp_dmac_wr_data;
        // reg               qp_sip_en;
        // reg               qp_sip_wr_en;
        // reg    [INDEX-1 :0]   qp_sip_addr;
        // reg    [31 : 0]   qp_sip_wr_data;
        // reg               qp_dip_en;
        // reg               qp_dip_wr_en;
        // reg    [INDEX-1 :0]   qp_dip_addr;
        // reg    [31 : 0]   qp_dip_wr_data;
        // reg               qp_send_wqe_length_en;
        // reg               qp_send_wqe_length_wr_en;
        // reg    [INDEX-1 :0]   qp_send_wqe_length_addr;
        // reg    [31 : 0]   qp_send_wqe_length_wr_data;
        // reg               qp_cqn_recv_en;
        // reg               qp_cqn_recv_wr_en;
        // reg    [INDEX-1 :0]   qp_cqn_recv_addr;
        // reg    [31 : 0]   qp_cqn_recv_wr_data;
        // reg               qp_recv_wqe_length_en;
        // reg               qp_recv_wqe_length_wr_en;
        // reg    [INDEX-1 :0]   qp_recv_wqe_length_addr;
        // reg    [31 : 0]   qp_recv_wqe_length_wr_data;
        // reg                cq_sz_log_en;
        // reg                cq_sz_log_wr_en;
        // reg     [INDEX-1 :0]   cq_sz_log_addr;
        // reg     [7 : 0]    cq_sz_log_wr_data;
        // reg               cq_pd_en;
        // reg               cq_pd_wr_en;
        // reg    [INDEX-1 :0]   cq_pd_addr;
        // reg    [31 : 0]   cq_pd_wr_data;
        // reg                eqn_en;
        // reg                eqn_wr_en;
        // reg     [INDEX-1 :0]   eqn_addr;
        // reg     [7 : 0]    eqn_wr_data;
        // reg eqn_valid [0:31];
        // reg [2:0] fsm_cs;
        // reg [2:0] fsm_ns;
        // reg [127:0]  qv_tmp_req;
        // reg [6:0] qv_selected_channel;
        // reg [1:0] qv_read_ram_cnt;
        // reg [127:0] qv_tmp_ctx_payload;
        // reg [32*13-1-24:0]    q_ov_ee_cxtmgt_resp_cxt_data;
        // reg [32*11-1-5-8-24:0]     q_ov_rrc_cxtmgt_resp_cxt_data;
        // reg [9*32-1-5-24-8-16:0]   q_ov_rtc_cxtmgt_resp_cxt_data;
        // reg [127-64-21:0]     q_ov_wp_cxtmgt_resp_cxt_data;
        // reg     [255-64-24-8:0]     q_ov_db_cxtmgt_resp_cxt_data;
        // reg     [255-65:0]     q_ov_fe_cxtmgt_resp_cxt_data;

    //total regs count = 1bit_signal(2) + fsm(2*2) + reg (128+256*2+12+4*4) = 674

    // /*****************Add for APB-slave wires**********************************/ 
        // wire  [7 :0]  selected_channel,                           //8 
        // wire                       ceu_wr_req_rd_en,              //1 
        // wire                       ceu_wr_req_empty,              //1 
        // wire [`CEUP_REQ_KEY-1:0]   ceu_wr_req_dout,               //35 
        // wire                       ceu_wr_data_rd_en1,            //1 
        // wire                       ceu_wr_data_empty1,            //1 
        // wire [`KEY_QPC_DT-1:0]     ceu_wr_data_dout1,             //384 
        // wire                       ceu_wr_data_rd_en2,            //1 
        // wire                       ceu_wr_data_empty2,            //1 
        // wire [`KEY_QPC_DT-1:0]     ceu_wr_data_dout2,             //384 
        // wire                i_db_cxtmgt_cmd_empty,               //1 
        // wire                o_db_cxtmgt_cmd_rd_en,               //1 
        // wire    [127:0]     iv_db_cxtmgt_cmd_data,               //128 
        // wire                i_db_cxtmgt_resp_prog_full,          //1 
        // wire                i_db_cxtmgt_resp_cxt_prog_full,      //1 
        // wire     [255:0]    ov_db_cxtmgt_resp_cxt_data,          //256 
        // wire                i_wp_cxtmgt_cmd_empty,               //1 
        // wire                o_wp_cxtmgt_cmd_rd_en,               //1 
        // wire    [127:0]     iv_wp_cxtmgt_cmd_data,               //128 
        // wire                i_wp_cxtmgt_resp_prog_full,          //1 
        // wire                i_wp_cxtmgt_resp_cxt_prog_full,      //1 
        // wire    [127:0]     ov_wp_cxtmgt_resp_cxt_data,          //128 
        // wire                i_rtc_cxtmgt_cmd_empty,              //1 
        // wire                o_rtc_cxtmgt_cmd_rd_en,              //1 
        // wire    [127:0]     iv_rtc_cxtmgt_cmd_data,              //128 
        // wire                i_rtc_cxtmgt_resp_prog_full,         //1 
        // wire                i_rtc_cxtmgt_resp_cxt_prog_full,     //1 
        // wire    [9*32-1:0]  ov_rtc_cxtmgt_resp_cxt_data,         //288 
        // wire                i_rtc_cxtmgt_cxt_empty,              //1 
        // wire                o_rtc_cxtmgt_cxt_rd_en,              //1 
        // wire    [127:0]     iv_rtc_cxtmgt_cxt_data,              //128 
        // wire                i_rrc_cxtmgt_cmd_empty,              //1 
        // wire                o_rrc_cxtmgt_cmd_rd_en,              //1 
        // wire    [127:0]     iv_rrc_cxtmgt_cmd_data,              //128 
        // wire                i_rrc_cxtmgt_resp_prog_full,         //1 
        // wire                i_rrc_cxtmgt_resp_cxt_prog_full,     //1 
        // wire     [32*11-1:0]  ov_rrc_cxtmgt_resp_cxt_data,       //352 
        // wire                i_rrc_cxtmgt_cxt_empty,              //1 
        // wire                o_rrc_cxtmgt_cxt_rd_en,              //1 
        // wire    [127:0]     iv_rrc_cxtmgt_cxt_data,              //128 
        // wire                i_ee_cxtmgt_cmd_empty,               //1 
        // wire                o_ee_cxtmgt_cmd_rd_en,               //1 
        // wire    [127:0]     iv_ee_cxtmgt_cmd_data,               //128 
        // wire                i_ee_cxtmgt_resp_prog_full,          //1 
        // wire                i_ee_cxtmgt_resp_cxt_prog_full,      //1 
        // wire [32*13-1:0]    ov_ee_cxtmgt_resp_cxt_data,          //416 
        // wire                i_ee_cxtmgt_cxt_empty,               //1 
        // wire                o_ee_cxtmgt_cxt_rd_en,               //1 
        // wire    [127:0]     iv_ee_cxtmgt_cxt_data,               //128 
        // wire                i_fe_cxtmgt_cmd_empty,               //1 
        // wire                o_fe_cxtmgt_cmd_rd_en,               //1 
        // wire    [127:0]     iv_fe_cxtmgt_cmd_data,               //128 
        // wire                i_fe_cxtmgt_resp_prog_full,          //1 
        // wire                i_fe_cxtmgt_resp_cxt_prog_full,      //1 
        // wire    [255:0]     ov_fe_cxtmgt_resp_cxt_data,          //256 
        // wire                      key_ctx_req_mdt_rd_en,          //1 
        // wire  [`HD_WIDTH-1:0]     key_ctx_req_mdt_dout,           //128 
        // wire                      key_ctx_req_mdt_empty           //1 
        // wire                        key_ctx_req_mdt_prog_full;           //1 
        // wire  [`HD_WIDTH-1:0]       wv_key_ctx_req_mdt_din;              //128 
        // wire   [3 : 0]    qp_state_rd_data;                              //4 
        // wire   [7 : 0]    qp_serv_tpye_rd_data;                          //8 
        // wire    [7 : 0]    qp_mtu_rd_data;                               //8 
        // wire    [7 : 0]    qp_rnr_retry_rd_data;                         //8 
        // wire   [31 : 0]   qp_local_qpn_rd_data;                          //32 
        // wire   [31 : 0]   qp_remote_qpn_rd_data;                         //32 
        // wire   [31 : 0]   qp_port_key_rd_data;                           //32 
        // wire   [31 : 0]   qp_pd_rd_data;                                 //32 
        // wire   [31 : 0]   qp_sl_tclass_rd_data;                          //32 
        // wire   [31 : 0]   qp_next_psn_rd_data;                           //32 
        // wire   [31 : 0]   qp_cqn_send_rd_data;                           //32 
        // wire   [31 : 0]   qp_send_wqe_base_lkey_rd_data;                 //32 
        // wire   [31 : 0]   qp_unacked_psn_rd_data;                        //32 
        // wire   [31 : 0]   qp_expect_psn_rd_data;                         //32 
        // wire   [31 : 0]   qp_recv_wqe_base_lkey_rd_data;                 //32 
        // wire   [31 : 0]   cq_lkey_rd_data;                               //32 
        // wire    [7 : 0]    qp_rq_entry_sz_log_rd_data;                   //8 
        // wire    [7 : 0]    qp_sq_entry_sz_log_rd_data;                   //8 
        // wire    [47 : 0]   qp_smac_rd_data;                              //48 
        // wire    [47 : 0]   qp_dmac_rd_data;                              //48 
        // wire   [31 : 0]   qp_sip_rd_data;                                //32 
        // wire   [31 : 0]   qp_dip_rd_data;                                //32 
        // wire   [31 : 0]   qp_send_wqe_length_rd_data;                    //32 
        // wire   [31 : 0]   qp_cqn_recv_rd_data;                           //32 
        // wire   [31 : 0]   qp_recv_wqe_length_rd_data;                    //32 
        // wire    [7 : 0]    cq_sz_log_rd_data;                            //8 
        // wire   [31 : 0]   cq_pd_rd_data;                                 //32 
        // wire    [7 : 0]    eqn_rd_data;                                  //8 
        // wire [127:0]  wv_selected_req_data;                              //128 
        // wire [3:0]    wv_selected_req_type;                              //4 
        // wire [3:0]    wv_selected_req_op;                                //4 
        // wire [INDEX-1 :0]   wv_selected_req_qpn;                         //13 
        // wire [3:0]    wv_req_reg_type;                                   //4 
        // wire [3:0]    wv_req_reg_op;                                     //4 
        // wire [INDEX-1 :0]   wv_req_reg_qpn;                              //13 
        // wire has_mdt_req;                                                //1 
        // wire no_mdt_req;                                                 //1 
        // wire no_resp_ctx_data;                                           //1 
        // wire has_resp_ctx_data;                                          //1 
        // wire selected_resp_cmd_fifo_prog_full;                           //1 
        // wire selected_resp_ctx_fifo_prog_full;                           //1 
        // wire lookup_cq_info;                                             //1 
        // wire only_lookup_qp_info;                                        //1 
        // wire lookup_eq_info;                                             //1 
        // wire [4:0] wv_req_reg_eqn;                                       //5 
        // wire [4:0] rd_eqn;                                               //5 

    //total wires count = 1bit_signal(9) + 256 + 128*2 + 4*2 = 529

    //Total regs and wires : 674 + 529 = 1203 = 32 * 37 + 19. bit align 38

    assign wv_dbg_bus_5 = {
        // 0'b0,
        receive_req,
        o_db_cxtmgt_resp_wr_en,
        ov_db_cxtmgt_resp_data,
        o_db_cxtmgt_resp_cxt_wr_en,
        o_wp_cxtmgt_resp_wr_en,
        ov_wp_cxtmgt_resp_data,
        o_wp_cxtmgt_resp_cxt_wr_en,
        o_rtc_cxtmgt_resp_wr_en,
        ov_rtc_cxtmgt_resp_data,
        o_rtc_cxtmgt_resp_cxt_wr_en,
        o_rrc_cxtmgt_resp_wr_en,
        ov_rrc_cxtmgt_resp_data,
        o_rrc_cxtmgt_resp_cxt_wr_en,
        o_ee_cxtmgt_resp_wr_en,
        ov_ee_cxtmgt_resp_data,
        o_ee_cxtmgt_resp_cxt_wr_en,
        o_fe_cxtmgt_resp_wr_en,
        ov_fe_cxtmgt_resp_data,
        o_fe_cxtmgt_resp_cxt_wr_en,
        key_ctx_req_mdt_wr_en,
        key_ctx_req_mdt_din,
        qp_state_en,
        qp_state_wr_en,
        qp_state_addr,
        qp_state_wr_data,
        qp_serv_tpye_en,
        qp_serv_tpye_wr_en,
        qp_serv_tpye_addr,
        qp_serv_tpye_wr_data,
        qp_mtu_en,
        qp_mtu_wr_en,
        qp_mtu_addr,
        qp_mtu_wr_data,
        qp_rnr_retry_en,
        qp_rnr_retry_wr_en,
        qp_rnr_retry_addr,
        qp_rnr_retry_wr_data,
        qp_local_qpn_en,
        qp_local_qpn_wr_en,
        qp_local_qpn_addr,
        qp_local_qpn_wr_data,
        qp_remote_qpn_en,
        qp_remote_qpn_wr_en,
        qp_remote_qpn_addr,
        qp_remote_qpn_wr_data,
        qp_port_key_en,
        qp_port_key_wr_en,
        qp_port_key_addr,
        qp_port_key_wr_data,
        qp_pd_en,
        qp_pd_wr_en,
        qp_pd_addr,
        qp_pd_wr_data,
        qp_sl_tclass_en,
        qp_sl_tclass_wr_en,
        qp_sl_tclass_addr,
        qp_sl_tclass_wr_data,
        qp_next_psn_en,
        qp_next_psn_wr_en,
        qp_next_psn_addr,
        qp_next_psn_wr_data,
        qp_cqn_send_en,
        qp_cqn_send_wr_en,
        qp_cqn_send_addr,
        qp_cqn_send_wr_data,
        qp_send_wqe_base_lkey_en,
        qp_send_wqe_base_lkey_wr_en,
        qp_send_wqe_base_lkey_addr,
        qp_send_wqe_base_lkey_wr_data,
        qp_unacked_psn_en,
        qp_unacked_psn_wr_en,
        qp_unacked_psn_addr,
        qp_unacked_psn_wr_data,
        qp_expect_psn_en,
        qp_expect_psn_wr_en,
        qp_expect_psn_addr,
        qp_expect_psn_wr_data,
        qp_recv_wqe_base_lkey_en,
        qp_recv_wqe_base_lkey_wr_en,
        qp_recv_wqe_base_lkey_addr,
        qp_recv_wqe_base_lkey_wr_data,
        cq_lkey_en,
        cq_lkey_wr_en,
        cq_lkey_addr,
        cq_lkey_wr_data,
        qp_rq_entry_sz_log_en,
        qp_rq_entry_sz_log_wr_en,
        qp_rq_entry_sz_log_addr,
        qp_rq_entry_sz_log_wr_data,
        qp_sq_entry_sz_log_en,
        qp_sq_entry_sz_log_wr_en,
        qp_sq_entry_sz_log_addr,
        qp_sq_entry_sz_log_wr_data,
        qp_smac_en,
        qp_smac_wr_en,
        qp_smac_addr,
        qp_smac_wr_data,
        qp_dmac_en,
        qp_dmac_wr_en,
        qp_dmac_addr,
        qp_dmac_wr_data,
        qp_sip_en,
        qp_sip_wr_en,
        qp_sip_addr,
        qp_sip_wr_data,
        qp_dip_en,
        qp_dip_wr_en,
        qp_dip_addr,
        qp_dip_wr_data,
        qp_send_wqe_length_en,
        qp_send_wqe_length_wr_en,
        qp_send_wqe_length_addr,
        qp_send_wqe_length_wr_data,
        qp_cqn_recv_en,
        qp_cqn_recv_wr_en,
        qp_cqn_recv_addr,
        qp_cqn_recv_wr_data,
        qp_recv_wqe_length_en,
        qp_recv_wqe_length_wr_en,
        qp_recv_wqe_length_addr,
        qp_recv_wqe_length_wr_data,
        cq_sz_log_en,
        cq_sz_log_wr_en,
        cq_sz_log_addr,
        cq_sz_log_wr_data,
        cq_pd_en,
        cq_pd_wr_en,
        cq_pd_addr,
        cq_pd_wr_data,
        eqn_en,
        eqn_wr_en,
        eqn_addr,
        eqn_wr_data,
        fsm_cs,
        fsm_ns,
        qv_tmp_req,
        qv_selected_channel,
        qv_read_ram_cnt,
        qv_tmp_ctx_payload,
        q_ov_ee_cxtmgt_resp_cxt_data,
        q_ov_rrc_cxtmgt_resp_cxt_data,
        q_ov_rtc_cxtmgt_resp_cxt_data,
        q_ov_wp_cxtmgt_resp_cxt_data,
        q_ov_db_cxtmgt_resp_cxt_data,
        q_ov_fe_cxtmgt_resp_cxt_data,

        selected_channel,
        ceu_wr_req_rd_en,
        ceu_wr_req_empty,
        ceu_wr_req_dout,
        ceu_wr_data_rd_en1,
        ceu_wr_data_empty1,
        ceu_wr_data_dout1,
        ceu_wr_data_rd_en2,
        ceu_wr_data_empty2,
        ceu_wr_data_dout2,
        i_db_cxtmgt_cmd_empty,
        o_db_cxtmgt_cmd_rd_en,
        iv_db_cxtmgt_cmd_data,
        i_db_cxtmgt_resp_prog_full,
        i_db_cxtmgt_resp_cxt_prog_full,
        ov_db_cxtmgt_resp_cxt_data,
        i_wp_cxtmgt_cmd_empty,
        o_wp_cxtmgt_cmd_rd_en,
        iv_wp_cxtmgt_cmd_data,
        i_wp_cxtmgt_resp_prog_full,
        i_wp_cxtmgt_resp_cxt_prog_full,
        ov_wp_cxtmgt_resp_cxt_data,
        i_rtc_cxtmgt_cmd_empty,
        o_rtc_cxtmgt_cmd_rd_en,
        iv_rtc_cxtmgt_cmd_data,
        i_rtc_cxtmgt_resp_prog_full,
        i_rtc_cxtmgt_resp_cxt_prog_full,
        ov_rtc_cxtmgt_resp_cxt_data,
        i_rtc_cxtmgt_cxt_empty,
        o_rtc_cxtmgt_cxt_rd_en,
        iv_rtc_cxtmgt_cxt_data,
        i_rrc_cxtmgt_cmd_empty,
        o_rrc_cxtmgt_cmd_rd_en,
        iv_rrc_cxtmgt_cmd_data,
        i_rrc_cxtmgt_resp_prog_full,
        i_rrc_cxtmgt_resp_cxt_prog_full,
        ov_rrc_cxtmgt_resp_cxt_data,
        i_rrc_cxtmgt_cxt_empty,
        o_rrc_cxtmgt_cxt_rd_en,
        iv_rrc_cxtmgt_cxt_data,
        i_ee_cxtmgt_cmd_empty,
        o_ee_cxtmgt_cmd_rd_en,
        iv_ee_cxtmgt_cmd_data,
        i_ee_cxtmgt_resp_prog_full,
        i_ee_cxtmgt_resp_cxt_prog_full,
        ov_ee_cxtmgt_resp_cxt_data,
        i_ee_cxtmgt_cxt_empty,
        o_ee_cxtmgt_cxt_rd_en,
        iv_ee_cxtmgt_cxt_data,
        i_fe_cxtmgt_cmd_empty,
        o_fe_cxtmgt_cmd_rd_en,
        iv_fe_cxtmgt_cmd_data,
        i_fe_cxtmgt_resp_prog_full,
        i_fe_cxtmgt_resp_cxt_prog_full,
        ov_fe_cxtmgt_resp_cxt_data,
        key_ctx_req_mdt_rd_en,
        key_ctx_req_mdt_dout,
        key_ctx_req_mdt_empty,
        key_ctx_req_mdt_prog_full,
        wv_key_ctx_req_mdt_din,
        qp_state_rd_data,
        qp_serv_tpye_rd_data,
        qp_mtu_rd_data,
        qp_rnr_retry_rd_data,
        qp_local_qpn_rd_data,
        qp_remote_qpn_rd_data,
        qp_port_key_rd_data,
        qp_pd_rd_data,
        qp_sl_tclass_rd_data,
        qp_next_psn_rd_data,
        qp_cqn_send_rd_data,
        qp_send_wqe_base_lkey_rd_data,
        qp_unacked_psn_rd_data,
        qp_expect_psn_rd_data,
        qp_recv_wqe_base_lkey_rd_data,
        cq_lkey_rd_data,
        qp_rq_entry_sz_log_rd_data,
        qp_sq_entry_sz_log_rd_data,
        qp_smac_rd_data,
        qp_dmac_rd_data,
        qp_sip_rd_data,
        qp_dip_rd_data,
        qp_send_wqe_length_rd_data,
        qp_cqn_recv_rd_data,
        qp_recv_wqe_length_rd_data,
        cq_sz_log_rd_data,
        cq_pd_rd_data,
        eqn_rd_data,
        wv_selected_req_data,
        wv_selected_req_type,
        wv_selected_req_op,
        wv_selected_req_qpn,
        wv_req_reg_type,
        wv_req_reg_op,
        wv_req_reg_qpn,
        has_mdt_req,
        no_mdt_req,
        no_resp_ctx_data,
        has_resp_ctx_data,
        selected_resp_cmd_fifo_prog_full,
        selected_resp_ctx_fifo_prog_full,
        lookup_cq_info,
        only_lookup_qp_info,
        lookup_eq_info,
        wv_req_reg_eqn,
        rd_eqn
    };
`endif 

endmodule
