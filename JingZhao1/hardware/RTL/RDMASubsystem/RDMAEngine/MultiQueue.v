`timescale 1ns / 1ps

`include "chip_include_rdma.vh"

module MultiQueue
#(
	parameter 	RW_REG_NUM = 18
)
(
    input   wire                clk,
    input   wire                rst,

	input 	wire 	[RW_REG_NUM * 32 - 1 : 0]	rw_data,
	output 	wire 	[RW_REG_NUM * 32 - 1 : 0]	init_rw_data,

//Interface with RequesterTransControl
//--------------------------------------------

    input   wire                i_rpb_list_head_wea,
    input   wire    [13:0]      iv_rpb_list_head_addra,
    input   wire    [8:0]       iv_rpb_list_head_dina,
    output  wire    [8:0]       ov_rpb_list_head_douta,

    input   wire                i_rpb_list_tail_wea,
    input   wire    [13:0]      iv_rpb_list_tail_addra,
    input   wire    [8:0]       iv_rpb_list_tail_dina,
    output  wire    [8:0]       ov_rpb_list_tail_douta,

    input   wire                i_rpb_list_empty_wea,
    input   wire    [13:0]      iv_rpb_list_empty_addra,
    input   wire    [0:0]       iv_rpb_list_empty_dina,
    output  wire    [0:0]       ov_rpb_list_empty_douta,

    input   wire                i_rpb_content_wea,
    input   wire    [8:0]       iv_rpb_content_addra,
    input   wire    [261:0]     iv_rpb_content_dina,
    output  wire    [261:0]     ov_rpb_content_douta,

    input   wire                i_rpb_next_wea,
    input   wire    [8:0]       iv_rpb_next_addra,
    input   wire    [9:0]       iv_rpb_next_dina,
    output  wire    [9:0]       ov_rpb_next_douta,

    output  wire                o_rpb_free_empty,
    output  wire    [8:0]       ov_rpb_free_dout,
    input   wire                i_rpb_free_rd_en,
    output  wire    [9:0]       ov_rpb_free_data_count,

//--------------------------------------------

    input   wire                i_reb_list_head_wea,
    input   wire    [13:0]      iv_reb_list_head_addra,
    input   wire    [13:0]      iv_reb_list_head_dina,
    output  wire    [13:0]      ov_reb_list_head_douta,

    input   wire                i_reb_list_tail_wea,
    input   wire    [13:0]      iv_reb_list_tail_addra,
    input   wire    [13:0]      iv_reb_list_tail_dina,
    output  wire    [13:0]      ov_reb_list_tail_douta,

    input   wire                i_reb_list_empty_wea,
    input   wire    [13:0]      iv_reb_list_empty_addra,
    input   wire    [0:0]       iv_reb_list_empty_dina,
    output  wire    [0:0]       ov_reb_list_empty_douta,

    input   wire                i_reb_content_wea,
    input   wire    [13:0]      iv_reb_content_addra,
    input   wire    [127:0]     iv_reb_content_dina,
    output  wire    [127:0]     ov_reb_content_douta,

    input   wire                i_reb_next_wea,
    input   wire    [13:0]      iv_reb_next_addra,
    input   wire    [14:0]      iv_reb_next_dina,
    output  wire    [14:0]      ov_reb_next_douta,

    output  wire                o_reb_free_empty,
    output  wire    [13:0]      ov_reb_free_dout,
    input   wire                i_reb_free_rd_en,
    output  wire    [14:0]      ov_reb_free_data_count,

//--------------------------------------------

    input   wire                i_swpb_list_head_wea,
    input   wire    [13:0]      iv_swpb_list_head_addra,
    input   wire    [11:0]      iv_swpb_list_head_dina,
    output  wire    [11:0]      ov_swpb_list_head_douta,

    input   wire                i_swpb_list_tail_wea,
    input   wire    [13:0]      iv_swpb_list_tail_addra,
    input   wire    [11:0]      iv_swpb_list_tail_dina,
    output  wire    [11:0]      ov_swpb_list_tail_douta,

    input   wire                i_swpb_list_empty_wea,
    input   wire    [13:0]      iv_swpb_list_empty_addra,
    input   wire    [0:0]       iv_swpb_list_empty_dina,
    output  wire    [0:0]       ov_swpb_list_empty_douta,

    input   wire                i_swpb_content_wea,
    input   wire    [11:0]      iv_swpb_content_addra,
    input   wire    [287:0]     iv_swpb_content_dina,
    output  wire    [287:0]     ov_swpb_content_douta,

    input   wire                i_swpb_next_wea,
    input   wire    [11:0]      iv_swpb_next_addra,
    input   wire    [12:0]      iv_swpb_next_dina,
    output  wire    [12:0]      ov_swpb_next_douta,

    output  wire                o_swpb_free_empty,
    output  wire    [11:0]      ov_swpb_free_dout,
    input   wire                i_swpb_free_rd_en,
    output  wire    [12:0]      ov_swpb_free_data_count,

//--------------------------------------------

//RequesterRecvControl
//--------------------------------------------

    input   wire                i_rpb_list_head_web,
    input   wire    [13:0]      iv_rpb_list_head_addrb,
    input   wire    [8:0]       iv_rpb_list_head_dinb,
    output  wire    [8:0]       ov_rpb_list_head_doutb,

    input   wire                i_rpb_list_tail_web,
    input   wire    [13:0]      iv_rpb_list_tail_addrb,
    input   wire    [8:0]       iv_rpb_list_tail_dinb,
    output  wire    [8:0]       ov_rpb_list_tail_doutb,

    input   wire                i_rpb_list_empty_web,
    input   wire    [13:0]      iv_rpb_list_empty_addrb,
    input   wire    [0:0]       iv_rpb_list_empty_dinb,
    output  wire    [0:0]       ov_rpb_list_empty_doutb,

    input   wire                i_rpb_content_web,
    input   wire    [8:0]       iv_rpb_content_addrb,
    input   wire    [261:0]     iv_rpb_content_dinb,
    output  wire    [261:0]     ov_rpb_content_doutb,

    input   wire                i_rpb_next_web,
    input   wire    [8:0]       iv_rpb_next_addrb,
    input   wire    [9:0]       iv_rpb_next_dinb,
    output  wire    [9:0]       ov_rpb_next_doutb,

    input   wire    [8:0]       iv_rpb_free_din,
    input   wire                i_rpb_free_wr_en,
    output  wire                o_rpb_free_prog_full,

//--------------------------------------------

    input   wire                i_reb_list_head_web,
    input   wire    [13:0]      iv_reb_list_head_addrb,
    input   wire    [13:0]      iv_reb_list_head_dinb,
    output  wire    [13:0]      ov_reb_list_head_doutb,

    input   wire                i_reb_list_tail_web,
    input   wire    [13:0]      iv_reb_list_tail_addrb,
    input   wire    [13:0]      iv_reb_list_tail_dinb,
    output  wire    [13:0]      ov_reb_list_tail_doutb,

    input   wire                i_reb_list_empty_web,
    input   wire    [13:0]      iv_reb_list_empty_addrb,
    input   wire    [0:0]       iv_reb_list_empty_dinb,
    output  wire    [0:0]       ov_reb_list_empty_doutb,

    input   wire                i_reb_content_web,
    input   wire    [13:0]      iv_reb_content_addrb,
    input   wire    [127:0]     iv_reb_content_dinb,
    output  wire    [127:0]     ov_reb_content_doutb,

    input   wire                i_reb_next_web,
    input   wire    [13:0]      iv_reb_next_addrb,
    input   wire    [14:0]      iv_reb_next_dinb,
    output  wire    [14:0]      ov_reb_next_doutb,

    input   wire    [13:0]      iv_reb_free_din,
    input   wire                i_reb_free_wr_en,
    output  wire                o_reb_free_prog_full,
//--------------------------------------------

    input   wire                i_swpb_list_head_web,
    input   wire    [13:0]      iv_swpb_list_head_addrb,
    input   wire    [11:0]      iv_swpb_list_head_dinb,
    output  wire    [11:0]      ov_swpb_list_head_doutb,

    input   wire                i_swpb_list_tail_web,
    input   wire    [13:0]      iv_swpb_list_tail_addrb,
    input   wire    [11:0]      iv_swpb_list_tail_dinb,
    output  wire    [11:0]      ov_swpb_list_tail_doutb,

    input   wire                i_swpb_list_empty_web,
    input   wire    [13:0]      iv_swpb_list_empty_addrb,
    input   wire    [0:0]       iv_swpb_list_empty_dinb,
    output  wire    [0:0]       ov_swpb_list_empty_doutb,

    input   wire                i_swpb_content_web,
    input   wire    [11:0]      iv_swpb_content_addrb,
    input   wire    [287:0]     iv_swpb_content_dinb,
    output  wire    [287:0]     ov_swpb_content_doutb,

    input   wire                i_swpb_next_web,
    input   wire    [11:0]      iv_swpb_next_addrb,
    input   wire    [12:0]       iv_swpb_next_dinb,
    output  wire    [12:0]       ov_swpb_next_doutb,
  
    input   wire    [11:0]      iv_swpb_free_din,
    input   wire                i_swpb_free_wr_en,
    output  wire                o_swpb_free_prog_full,

    input   wire    [31:0]      dbg_sel,
    output  wire    [32 - 1:0]      dbg_bus
    //output  wire    [`DBG_NUM_MULTI_QUEUE * 32 - 1:0]      dbg_bus
);

/**************************************** RDMA Read Packet Buffer(RPB) Queue ************************************/
reg         		q_rpb_list_head_wea_TempReg;
reg         		q_rpb_list_tail_wea_TempReg;
reg         		q_rpb_list_empty_wea_TempReg;
reg         		q_rpb_content_wea_TempReg;
reg         		q_rpb_next_wea_TempReg;
reg    [13:0]      	qv_rpb_list_head_addra_TempReg;
reg    [13:0]      	qv_rpb_list_tail_addra_TempReg;
reg    [13:0]      	qv_rpb_list_empty_addra_TempReg;
reg    [8:0]      	qv_rpb_content_addra_TempReg;
reg    [8:0]      	qv_rpb_next_addra_TempReg;
reg    [8:0]     	qv_rpb_list_head_dina_TempReg;
reg    [8:0]     	qv_rpb_list_tail_dina_TempReg;
reg    [0:0]      	qv_rpb_list_empty_dina_TempReg;
reg    [261:0]    	qv_rpb_content_dina_TempReg;
reg    [9:0]     	qv_rpb_next_dina_TempReg;

reg         		q_rpb_list_head_web_TempReg;
reg         		q_rpb_list_tail_web_TempReg;
reg         		q_rpb_list_empty_web_TempReg;
reg         		q_rpb_content_web_TempReg;
reg         		q_rpb_next_web_TempReg;
reg    [13:0]      	qv_rpb_list_head_addrb_TempReg;
reg    [13:0]      	qv_rpb_list_tail_addrb_TempReg;
reg    [13:0]      	qv_rpb_list_empty_addrb_TempReg;
reg    [8:0]      	qv_rpb_content_addrb_TempReg;
reg    [8:0]      	qv_rpb_next_addrb_TempReg;
reg    [8:0]     	qv_rpb_list_head_dinb_TempReg;
reg    [8:0]     	qv_rpb_list_tail_dinb_TempReg;
reg    [0:0]      	qv_rpb_list_empty_dinb_TempReg;
reg    [261:0]    	qv_rpb_content_dinb_TempReg;
reg    [9:0]     	qv_rpb_next_dinb_TempReg;

always @(posedge clk or posedge rst) begin
	if(rst) begin
		q_rpb_list_head_wea_TempReg <= 'd0;
		q_rpb_list_tail_wea_TempReg <= 'd0;
		q_rpb_list_empty_wea_TempReg <= 'd0;
		q_rpb_content_wea_TempReg <= 'd0;
		q_rpb_next_wea_TempReg <= 'd0;
		qv_rpb_list_head_addra_TempReg <= 'd0;
		qv_rpb_list_tail_addra_TempReg <= 'd0;
		qv_rpb_list_empty_addra_TempReg <= 'd0;
		qv_rpb_content_addra_TempReg <= 'd0;
		qv_rpb_next_addra_TempReg <= 'd0;
		qv_rpb_list_head_dina_TempReg <= 'd0;
		qv_rpb_list_tail_dina_TempReg <= 'd0;
		qv_rpb_list_empty_dina_TempReg <= 'd0;
		qv_rpb_content_dina_TempReg <= 'd0;
		qv_rpb_next_dina_TempReg <= 'd0;

		q_rpb_list_head_web_TempReg <= 'd0;
		q_rpb_list_tail_web_TempReg <= 'd0;
		q_rpb_list_empty_web_TempReg <= 'd0;
		q_rpb_content_web_TempReg <= 'd0;
		q_rpb_next_web_TempReg <= 'd0;
		qv_rpb_list_head_addrb_TempReg <= 'd0;
		qv_rpb_list_tail_addrb_TempReg <= 'd0;
		qv_rpb_list_empty_addrb_TempReg <= 'd0;
		qv_rpb_content_addrb_TempReg <= 'd0;
		qv_rpb_next_addrb_TempReg <= 'd0;
		qv_rpb_list_head_dinb_TempReg <= 'd0;
		qv_rpb_list_tail_dinb_TempReg <= 'd0;
		qv_rpb_list_empty_dinb_TempReg <= 'd0;
		qv_rpb_content_dinb_TempReg <= 'd0;
		qv_rpb_next_dinb_TempReg <= 'd0;
	end 	
	else begin
		q_rpb_list_head_wea_TempReg <= i_rpb_list_head_wea;
		q_rpb_list_tail_wea_TempReg <= i_rpb_list_tail_wea;
		q_rpb_list_empty_wea_TempReg <= i_rpb_list_empty_wea;
		q_rpb_content_wea_TempReg <= i_rpb_content_wea;
		q_rpb_next_wea_TempReg <= i_rpb_next_wea;
		qv_rpb_list_head_addra_TempReg <= iv_rpb_list_head_addra;
		qv_rpb_list_tail_addra_TempReg <= iv_rpb_list_tail_addra;
		qv_rpb_list_empty_addra_TempReg <= iv_rpb_list_empty_addra;
		qv_rpb_content_addra_TempReg <= iv_rpb_content_addra;
		qv_rpb_next_addra_TempReg <= iv_rpb_next_addra;
		qv_rpb_list_head_dina_TempReg <= iv_rpb_list_head_dina;
		qv_rpb_list_tail_dina_TempReg <= iv_rpb_list_tail_dina;
		qv_rpb_list_empty_dina_TempReg <= iv_rpb_list_empty_dina;
		qv_rpb_content_dina_TempReg <= iv_rpb_content_dina;
		qv_rpb_next_dina_TempReg <= iv_rpb_next_dina;

		q_rpb_list_head_web_TempReg <= i_rpb_list_head_web;
		q_rpb_list_tail_web_TempReg <= i_rpb_list_tail_web;
		q_rpb_list_empty_web_TempReg <= i_rpb_list_empty_web;
		q_rpb_content_web_TempReg <= i_rpb_content_web;
		q_rpb_next_web_TempReg <= i_rpb_next_web;
		qv_rpb_list_head_addrb_TempReg <= iv_rpb_list_head_addrb;
		qv_rpb_list_tail_addrb_TempReg <= iv_rpb_list_tail_addrb;
		qv_rpb_list_empty_addrb_TempReg <= iv_rpb_list_empty_addrb;
		qv_rpb_content_addrb_TempReg <= iv_rpb_content_addrb;
		qv_rpb_next_addrb_TempReg <= iv_rpb_next_addrb;
		qv_rpb_list_head_dinb_TempReg <= iv_rpb_list_head_dinb;
		qv_rpb_list_tail_dinb_TempReg <= iv_rpb_list_tail_dinb;
		qv_rpb_list_empty_dinb_TempReg <= iv_rpb_list_empty_dinb;
		qv_rpb_content_dinb_TempReg <= iv_rpb_content_dinb;
		qv_rpb_next_dinb_TempReg <= iv_rpb_next_dinb;
	end 
end 

wire    [8:0]      wv_rpb_list_head_douta;
wire    [8:0]      wv_rpb_list_tail_douta;
wire    [0:0]      wv_rpb_list_empty_douta;
wire    [261:0]    wv_rpb_content_douta;
wire    [9:0]      wv_rpb_next_douta;

wire    [8:0]      wv_rpb_list_head_doutb;
wire    [8:0]      wv_rpb_list_tail_doutb;
wire    [0:0]      wv_rpb_list_empty_doutb;
wire    [261:0]    wv_rpb_content_doutb;
wire    [9:0]      wv_rpb_next_doutb;


assign ov_rpb_list_head_douta 	= 	q_rpb_list_head_wea_TempReg ? qv_rpb_list_head_dina_TempReg : 
							   		(q_rpb_list_head_web_TempReg && (qv_rpb_list_head_addrb_TempReg == qv_rpb_list_head_addra_TempReg)) ? qv_rpb_list_head_dinb_TempReg :
							 		wv_rpb_list_head_douta;

assign ov_rpb_list_tail_douta 	= 	q_rpb_list_tail_wea_TempReg ? qv_rpb_list_tail_dina_TempReg : 
							   		(q_rpb_list_tail_web_TempReg && (qv_rpb_list_tail_addrb_TempReg == qv_rpb_list_tail_addra_TempReg)) ? qv_rpb_list_tail_dinb_TempReg :
							 		wv_rpb_list_tail_douta;

assign ov_rpb_list_empty_douta 	= 	q_rpb_list_empty_wea_TempReg ? qv_rpb_list_empty_dina_TempReg : 
							   		(q_rpb_list_empty_web_TempReg && (qv_rpb_list_empty_addrb_TempReg == qv_rpb_list_empty_addra_TempReg)) ? qv_rpb_list_empty_dinb_TempReg :
							 		wv_rpb_list_empty_douta;

assign ov_rpb_content_douta 	= 	q_rpb_content_wea_TempReg ? qv_rpb_content_dina_TempReg : 
							   		(q_rpb_content_web_TempReg && (qv_rpb_content_addrb_TempReg == qv_rpb_content_addra_TempReg)) ? qv_rpb_content_dinb_TempReg :
							 		wv_rpb_content_douta;

assign ov_rpb_next_douta 		= 	q_rpb_next_wea_TempReg ? qv_rpb_next_dina_TempReg : 
							   		(q_rpb_next_web_TempReg && (qv_rpb_next_addrb_TempReg == qv_rpb_next_addra_TempReg)) ? qv_rpb_next_dinb_TempReg :
							 		wv_rpb_next_douta;


assign ov_rpb_list_head_doutb 	= 	q_rpb_list_head_web_TempReg ? qv_rpb_list_head_dinb_TempReg :
									(q_rpb_list_head_wea_TempReg && (qv_rpb_list_head_addra_TempReg == qv_rpb_list_head_addrb_TempReg)) ? qv_rpb_list_head_dina_TempReg : 
									wv_rpb_list_head_doutb;

assign ov_rpb_list_tail_doutb 	= 	q_rpb_list_tail_web_TempReg ? qv_rpb_list_tail_dinb_TempReg :
									(q_rpb_list_tail_wea_TempReg && (qv_rpb_list_tail_addra_TempReg == qv_rpb_list_tail_addrb_TempReg)) ? qv_rpb_list_tail_dina_TempReg : 
									wv_rpb_list_tail_doutb;

assign ov_rpb_list_empty_doutb 	= 	q_rpb_list_empty_web_TempReg ? qv_rpb_list_empty_dinb_TempReg :
									(q_rpb_list_empty_wea_TempReg && (qv_rpb_list_empty_addra_TempReg == qv_rpb_list_empty_addrb_TempReg)) ? qv_rpb_list_empty_dina_TempReg : 
									wv_rpb_list_empty_doutb;

assign ov_rpb_content_doutb 	= 	q_rpb_content_web_TempReg ? qv_rpb_content_dinb_TempReg :
									(q_rpb_content_wea_TempReg && (qv_rpb_content_addra_TempReg == qv_rpb_content_addrb_TempReg)) ? qv_rpb_content_dina_TempReg : 
									wv_rpb_content_doutb;

assign ov_rpb_next_doutb 		= 	q_rpb_next_web_TempReg ? qv_rpb_next_dinb_TempReg :
									(q_rpb_next_wea_TempReg && (qv_rpb_next_addra_TempReg == qv_rpb_next_addrb_TempReg)) ? qv_rpb_next_dina_TempReg : 
									wv_rpb_next_doutb;

//HPCA
BRAM_TDP_9w_16384d RPBListTable_Head(
	`ifdef CHIP_VERSION
	.RTSEL(rw_data[0 * 32 + 1 : 0 * 32 + 0]),
	.WTSEL(rw_data[0 * 32 + 3 : 0 * 32 + 2]),
	.PTSEL(rw_data[0 * 32 + 5 : 0 * 32 + 4]),
	.VG(rw_data[0 * 32 + 6 : 0 * 32 + 6]),
	.VS(rw_data[0 * 32 + 7 : 0 * 32 + 7]),

  `endif

  .clka(clk),   
  .ena(1'b1),     
  .wea(i_rpb_list_head_wea),     
  .addra(iv_rpb_list_head_addra), 
  .dina(iv_rpb_list_head_dina),   
  .douta(wv_rpb_list_head_douta), 
  .clkb(clk),   
  .enb(1'b1),     
  .web(i_rpb_list_head_web),     
  .addrb(iv_rpb_list_head_addrb), 
  .dinb(iv_rpb_list_head_dinb),   
  .doutb(wv_rpb_list_head_doutb) 
);

//HPCA
BRAM_TDP_9w_16384d RPBListTable_Tail(
	`ifdef CHIP_VERSION
	.RTSEL(rw_data[1 * 32 + 1 : 1 * 32 + 0]),
	.WTSEL(rw_data[1 * 32 + 3 : 1 * 32 + 2]),
	.PTSEL(rw_data[1 * 32 + 5 : 1 * 32 + 4]),
	.VG(rw_data[1 * 32 + 6 : 1 * 32 + 6]),
	.VS(rw_data[1 * 32 + 7 : 1 * 32 + 7]),

  `endif

  .clka(clk),   
  .ena(1'b1),     
  .wea(i_rpb_list_tail_wea),     
  .addra(iv_rpb_list_tail_addra), 
  .dina(iv_rpb_list_tail_dina),   
  .douta(wv_rpb_list_tail_douta), 
  .clkb(clk),   
  .enb(1'b1),     
  .web(i_rpb_list_tail_web),     
  .addrb(iv_rpb_list_tail_addrb), 
  .dinb(iv_rpb_list_tail_dinb),   
  .doutb(wv_rpb_list_tail_doutb) 
);

//HPCA
BRAM_TDP_1w_16384d RPBListTable_Empty(
	`ifdef CHIP_VERSION
	.RTSEL(rw_data[2 * 32 + 1 : 2 * 32 + 0]),
	.WTSEL(rw_data[2 * 32 + 3 : 2 * 32 + 2]),
	.PTSEL(rw_data[2 * 32 + 5 : 2 * 32 + 4]),
	.VG(rw_data[2 * 32 + 6 : 2 * 32 + 6]),
	.VS(rw_data[2 * 32 + 7 : 2 * 32 + 7]),

  `endif

  .clka(clk),   
  .ena(1'b1),     
  .wea(i_rpb_list_empty_wea),     
  .addra(iv_rpb_list_empty_addra), 
  .dina(iv_rpb_list_empty_dina),   
  .douta(wv_rpb_list_empty_douta), 
  .clkb(clk),   
  .enb(1'b1),     
  .web(i_rpb_list_empty_web),     
  .addrb(iv_rpb_list_empty_addrb), 
  .dinb(iv_rpb_list_empty_dinb),   
  .doutb(wv_rpb_list_empty_doutb) 
);

//HPCA
BRAM_TDP_262w_512d RPBElementTable_Content(   //Fixed 230-bit Meta: 224 Bit Header(BTH + RETH) + 6 Bit Entry Number , 32-bit WQE Offset
	`ifdef CHIP_VERSION
	.RTSEL(rw_data[3 * 32 + 1 : 3 * 32 + 0]),
	.WTSEL(rw_data[3 * 32 + 3 : 3 * 32 + 2]),
	.PTSEL(rw_data[3 * 32 + 5 : 3 * 32 + 4]),
	.VG(rw_data[3 * 32 + 6 : 3 * 32 + 6]),
	.VS(rw_data[3 * 32 + 7 : 3 * 32 + 7]),

  `endif

  .clka(clk),   
  .ena(1'b1),     
  .wea(i_rpb_content_wea),     
  .addra(iv_rpb_content_addra), 
  .dina(iv_rpb_content_dina),   
  .douta(wv_rpb_content_douta), 
  .clkb(clk),   
  .enb(1'b1),     
  .web(i_rpb_content_web),     
  .addrb(iv_rpb_content_addrb), 
  .dinb(iv_rpb_content_dinb),   
  .doutb(wv_rpb_content_doutb) 
);

//HPCA
BRAM_TDP_10w_512d RPBElementTable_Next(   //9 Bit Addr + 1 Bit Valid
	`ifdef CHIP_VERSION
	.RTSEL(	rw_data[4 * 32 + 1 : 4 * 32 + 0]),
	.WTSEL(	rw_data[4 * 32 + 3 : 4 * 32 + 2]),
	.PTSEL(	rw_data[4 * 32 + 5 : 4 * 32 + 4]),
	.VG(	rw_data[4 * 32 + 6 : 4 * 32 + 6]),
	.VS(	rw_data[4 * 32 + 7 : 4 * 32 + 7]),

  `endif

  .clka(clk),   
  .ena(1'b1),     
  .wea(i_rpb_next_wea),     
  .addra(iv_rpb_next_addra), 
  .dina(iv_rpb_next_dina),   
  .douta(wv_rpb_next_douta), 
  .clkb(clk),   
  .enb(1'b1),     
  .web(i_rpb_next_web),     
  .addrb(iv_rpb_next_addrb), 
  .dinb(iv_rpb_next_dinb),   
  .doutb(wv_rpb_next_doutb) 
);

//TS6N
SyncFIFO_9w_512d RPBFreeListFIFO(
	`ifdef CHIP_VERSION
	.RTSEL(	rw_data[5 * 32 + 1 : 5 * 32 + 0]),
	.WTSEL(	rw_data[5 * 32 + 3 : 5 * 32 + 2]),
	.PTSEL(	rw_data[5 * 32 + 5 : 5 * 32 + 4]),
	.VG(	  rw_data[5 * 32 + 6 : 5 * 32 + 6]),
	.VS(	  rw_data[5 * 32 + 7 : 5 * 32 + 7]),

  `endif

  .clk(clk),               
  .srst(rst),             
  .din(iv_rpb_free_din),               
  .wr_en(i_rpb_free_wr_en),           
  .rd_en(i_rpb_free_rd_en),           
  .dout(ov_rpb_free_dout),             
  .full(),             
  .empty(o_rpb_free_empty),           
  .data_count(ov_rpb_free_data_count), 
  .prog_full(o_rpb_free_prog_full)   
);


/**************************************** RDMA Read Entry Buffer(RPB) Queue ************************************/
reg         		q_reb_list_head_wea_TempReg;
reg         		q_reb_list_tail_wea_TempReg;
reg         		q_reb_list_empty_wea_TempReg;
reg         		q_reb_content_wea_TempReg;
reg         		q_reb_next_wea_TempReg;
reg    [13:0]      	qv_reb_list_head_addra_TempReg;
reg    [13:0]      	qv_reb_list_tail_addra_TempReg;
reg    [13:0]      	qv_reb_list_empty_addra_TempReg;
reg    [13:0]      	qv_reb_content_addra_TempReg;
reg    [13:0]      	qv_reb_next_addra_TempReg;
reg    [13:0]     	qv_reb_list_head_dina_TempReg;
reg    [13:0]     	qv_reb_list_tail_dina_TempReg;
reg    [0:0]      	qv_reb_list_empty_dina_TempReg;
reg    [127:0]    	qv_reb_content_dina_TempReg;
reg    [14:0]     	qv_reb_next_dina_TempReg;

reg         		q_reb_list_head_web_TempReg;
reg         		q_reb_list_tail_web_TempReg;
reg         		q_reb_list_empty_web_TempReg;
reg         		q_reb_content_web_TempReg;
reg         		q_reb_next_web_TempReg;
reg    [13:0]      	qv_reb_list_head_addrb_TempReg;
reg    [13:0]      	qv_reb_list_tail_addrb_TempReg;
reg    [13:0]      	qv_reb_list_empty_addrb_TempReg;
reg    [13:0]      	qv_reb_content_addrb_TempReg;
reg    [13:0]      	qv_reb_next_addrb_TempReg;
reg    [13:0]     	qv_reb_list_head_dinb_TempReg;
reg    [13:0]     	qv_reb_list_tail_dinb_TempReg;
reg    [0:0]      	qv_reb_list_empty_dinb_TempReg;
reg    [127:0]    	qv_reb_content_dinb_TempReg;
reg    [14:0]     	qv_reb_next_dinb_TempReg;

always @(posedge clk or posedge rst) begin
	if(rst) begin
		q_reb_list_head_wea_TempReg <= 'd0;
		q_reb_list_tail_wea_TempReg <= 'd0;
		q_reb_list_empty_wea_TempReg <= 'd0;
		q_reb_content_wea_TempReg <= 'd0;
		q_reb_next_wea_TempReg <= 'd0;
		qv_reb_list_head_addra_TempReg <= 'd0;
		qv_reb_list_tail_addra_TempReg <= 'd0;
		qv_reb_list_empty_addra_TempReg <= 'd0;
		qv_reb_content_addra_TempReg <= 'd0;
		qv_reb_next_addra_TempReg <= 'd0;
		qv_reb_list_head_dina_TempReg <= 'd0;
		qv_reb_list_tail_dina_TempReg <= 'd0;
		qv_reb_list_empty_dina_TempReg <= 'd0;
		qv_reb_content_dina_TempReg <= 'd0;
		qv_reb_next_dina_TempReg <= 'd0;

		q_reb_list_head_web_TempReg <= 'd0;
		q_reb_list_tail_web_TempReg <= 'd0;
		q_reb_list_empty_web_TempReg <= 'd0;
		q_reb_content_web_TempReg <= 'd0;
		q_reb_next_web_TempReg <= 'd0;
		qv_reb_list_head_addrb_TempReg <= 'd0;
		qv_reb_list_tail_addrb_TempReg <= 'd0;
		qv_reb_list_empty_addrb_TempReg <= 'd0;
		qv_reb_content_addrb_TempReg <= 'd0;
		qv_reb_next_addrb_TempReg <= 'd0;
		qv_reb_list_head_dinb_TempReg <= 'd0;
		qv_reb_list_tail_dinb_TempReg <= 'd0;
		qv_reb_list_empty_dinb_TempReg <= 'd0;
		qv_reb_content_dinb_TempReg <= 'd0;
		qv_reb_next_dinb_TempReg <= 'd0;
	end 	
	else begin
		q_reb_list_head_wea_TempReg <= i_reb_list_head_wea;
		q_reb_list_tail_wea_TempReg <= i_reb_list_tail_wea;
		q_reb_list_empty_wea_TempReg <= i_reb_list_empty_wea;
		q_reb_content_wea_TempReg <= i_reb_content_wea;
		q_reb_next_wea_TempReg <= i_reb_next_wea;
		qv_reb_list_head_addra_TempReg <= iv_reb_list_head_addra;
		qv_reb_list_tail_addra_TempReg <= iv_reb_list_tail_addra;
		qv_reb_list_empty_addra_TempReg <= iv_reb_list_empty_addra;
		qv_reb_content_addra_TempReg <= iv_reb_content_addra;
		qv_reb_next_addra_TempReg <= iv_reb_next_addra;
		qv_reb_list_head_dina_TempReg <= iv_reb_list_head_dina;
		qv_reb_list_tail_dina_TempReg <= iv_reb_list_tail_dina;
		qv_reb_list_empty_dina_TempReg <= iv_reb_list_empty_dina;
		qv_reb_content_dina_TempReg <= iv_reb_content_dina;
		qv_reb_next_dina_TempReg <= iv_reb_next_dina;

		q_reb_list_head_web_TempReg <= i_reb_list_head_web;
		q_reb_list_tail_web_TempReg <= i_reb_list_tail_web;
		q_reb_list_empty_web_TempReg <= i_reb_list_empty_web;
		q_reb_content_web_TempReg <= i_reb_content_web;
		q_reb_next_web_TempReg <= i_reb_next_web;
		qv_reb_list_head_addrb_TempReg <= iv_reb_list_head_addrb;
		qv_reb_list_tail_addrb_TempReg <= iv_reb_list_tail_addrb;
		qv_reb_list_empty_addrb_TempReg <= iv_reb_list_empty_addrb;
		qv_reb_content_addrb_TempReg <= iv_reb_content_addrb;
		qv_reb_next_addrb_TempReg <= iv_reb_next_addrb;
		qv_reb_list_head_dinb_TempReg <= iv_reb_list_head_dinb;
		qv_reb_list_tail_dinb_TempReg <= iv_reb_list_tail_dinb;
		qv_reb_list_empty_dinb_TempReg <= iv_reb_list_empty_dinb;
		qv_reb_content_dinb_TempReg <= iv_reb_content_dinb;
		qv_reb_next_dinb_TempReg <= iv_reb_next_dinb;
	end 
end 

wire    [13:0]      wv_reb_list_head_douta;
wire    [13:0]      wv_reb_list_tail_douta;
wire    [0:0]      wv_reb_list_empty_douta;
wire    [127:0]    wv_reb_content_douta;
wire    [14:0]      wv_reb_next_douta;

wire    [13:0]      wv_reb_list_head_doutb;
wire    [13:0]      wv_reb_list_tail_doutb;
wire    [0:0]      wv_reb_list_empty_doutb;
wire    [127:0]    wv_reb_content_doutb;
wire    [14:0]      wv_reb_next_doutb;


assign ov_reb_list_head_douta 	= 	q_reb_list_head_wea_TempReg ? qv_reb_list_head_dina_TempReg : 
							   		(q_reb_list_head_web_TempReg && (qv_reb_list_head_addrb_TempReg == qv_reb_list_head_addra_TempReg)) ? qv_reb_list_head_dinb_TempReg :
							 		wv_reb_list_head_douta;

assign ov_reb_list_tail_douta 	= 	q_reb_list_tail_wea_TempReg ? qv_reb_list_tail_dina_TempReg : 
							   		(q_reb_list_tail_web_TempReg && (qv_reb_list_tail_addrb_TempReg == qv_reb_list_tail_addra_TempReg)) ? qv_reb_list_tail_dinb_TempReg :
							 		wv_reb_list_tail_douta;

assign ov_reb_list_empty_douta 	= 	q_reb_list_empty_wea_TempReg ? qv_reb_list_empty_dina_TempReg : 
							   		(q_reb_list_empty_web_TempReg && (qv_reb_list_empty_addrb_TempReg == qv_reb_list_empty_addra_TempReg)) ? qv_reb_list_empty_dinb_TempReg :
							 		wv_reb_list_empty_douta;

assign ov_reb_content_douta 	= 	q_reb_content_wea_TempReg ? qv_reb_content_dina_TempReg : 
							   		(q_reb_content_web_TempReg && (qv_reb_content_addrb_TempReg == qv_reb_content_addra_TempReg)) ? qv_reb_content_dinb_TempReg :
							 		wv_reb_content_douta;

assign ov_reb_next_douta 		= 	q_reb_next_wea_TempReg ? qv_reb_next_dina_TempReg : 
							   		(q_reb_next_web_TempReg && (qv_reb_next_addrb_TempReg == qv_reb_next_addra_TempReg)) ? qv_reb_next_dinb_TempReg :
							 		wv_reb_next_douta;


assign ov_reb_list_head_doutb 	= 	q_reb_list_head_web_TempReg ? qv_reb_list_head_dinb_TempReg :
									(q_reb_list_head_wea_TempReg && (qv_reb_list_head_addra_TempReg == qv_reb_list_head_addrb_TempReg)) ? qv_reb_list_head_dina_TempReg : 
									wv_reb_list_head_doutb;

assign ov_reb_list_tail_doutb 	= 	q_reb_list_tail_web_TempReg ? qv_reb_list_tail_dinb_TempReg :
									(q_reb_list_tail_wea_TempReg && (qv_reb_list_tail_addra_TempReg == qv_reb_list_tail_addrb_TempReg)) ? qv_reb_list_tail_dina_TempReg : 
									wv_reb_list_tail_doutb;

assign ov_reb_list_empty_doutb 	= 	q_reb_list_empty_web_TempReg ? qv_reb_list_empty_dinb_TempReg :
									(q_reb_list_empty_wea_TempReg && (qv_reb_list_empty_addra_TempReg == qv_reb_list_empty_addrb_TempReg)) ? qv_reb_list_empty_dina_TempReg : 
									wv_reb_list_empty_doutb;

assign ov_reb_content_doutb 	= 	q_reb_content_web_TempReg ? qv_reb_content_dinb_TempReg :
									(q_reb_content_wea_TempReg && (qv_reb_content_addra_TempReg == qv_reb_content_addrb_TempReg)) ? qv_reb_content_dina_TempReg : 
									wv_reb_content_doutb;

assign ov_reb_next_doutb 		= 	q_reb_next_web_TempReg ? qv_reb_next_dinb_TempReg :
									(q_reb_next_wea_TempReg && (qv_reb_next_addra_TempReg == qv_reb_next_addrb_TempReg)) ? qv_reb_next_dina_TempReg : 
									wv_reb_next_doutb;

//HPCA
BRAM_TDP_14w_16384d REBListTable_Head(
  `ifdef CHIP_VERSION
	.RTSEL(	rw_data[6 * 32 + 1 : 6 * 32 + 0]),
	.WTSEL(	rw_data[6 * 32 + 3 : 6 * 32 + 2]),
	.PTSEL(	rw_data[6 * 32 + 5 : 6 * 32 + 4]),
	.VG(	  rw_data[6 * 32 + 6 : 6 * 32 + 6]),
	.VS(	  rw_data[6 * 32 + 7 : 6 * 32 + 7]),

  `endif

  .clka(clk),   
  .ena(1'b1),     
  .wea(i_reb_list_head_wea),     
  .addra(iv_reb_list_head_addra), 
  .dina(iv_reb_list_head_dina),   
  .douta(wv_reb_list_head_douta), 
  .clkb(clk),   
  .enb(1'b1),     
  .web(i_reb_list_head_web),     
  .addrb(iv_reb_list_head_addrb), 
  .dinb(iv_reb_list_head_dinb),   
  .doutb(wv_reb_list_head_doutb) 
);

//HPCA
BRAM_TDP_14w_16384d REBListTable_Tail(
  `ifdef CHIP_VERSION
	.RTSEL(	rw_data[7 * 32 + 1 : 7 * 32 + 0]),
	.WTSEL(	rw_data[7 * 32 + 3 : 7 * 32 + 2]),
	.PTSEL(	rw_data[7 * 32 + 5 : 7 * 32 + 4]),
	.VG(	  rw_data[7 * 32 + 6 : 7 * 32 + 6]),
	.VS(	  rw_data[7 * 32 + 7 : 7 * 32 + 7]),

  `endif

  .clka(clk),   
  .ena(1'b1),     
  .wea(i_reb_list_tail_wea),     
  .addra(iv_reb_list_tail_addra), 
  .dina(iv_reb_list_tail_dina),   
  .douta(wv_reb_list_tail_douta), 
  .clkb(clk),   
  .enb(1'b1),     
  .web(i_reb_list_tail_web),     
  .addrb(iv_reb_list_tail_addrb), 
  .dinb(iv_reb_list_tail_dinb),   
  .doutb(wv_reb_list_tail_doutb) 
);

//HPCA
BRAM_TDP_1w_16384d REBListTable_Empty(
  `ifdef CHIP_VERSION
	.RTSEL(	rw_data[8 * 32 + 1 : 8 * 32 + 0]),
	.WTSEL(	rw_data[8 * 32 + 3 : 8 * 32 + 2]),
	.PTSEL(	rw_data[8 * 32 + 5 : 8 * 32 + 4]),
	.VG(	  rw_data[8 * 32 + 6 : 8 * 32 + 6]),
	.VS(	  rw_data[8 * 32 + 7 : 8 * 32 + 7]),

  `endif

  .clka(clk),   
  .ena(1'b1),     
  .wea(i_reb_list_empty_wea),     
  .addra(iv_reb_list_empty_addra), 
  .dina(iv_reb_list_empty_dina),   
  .douta(wv_reb_list_empty_douta), 
  .clkb(clk),   
  .enb(1'b1),     
  .web(i_reb_list_empty_web),     
  .addrb(iv_reb_list_empty_addrb), 
  .dinb(iv_reb_list_empty_dinb),   
  .doutb(wv_reb_list_empty_doutb) 
);

//HPCA
BRAM_TDP_128w_16384d REBElementTable_Content(   //128 Bit Entry
  `ifdef CHIP_VERSION
	.RTSEL(	rw_data[9 * 32 + 1 : 9 * 32 + 0]),
	.WTSEL(	rw_data[9 * 32 + 3 : 9 * 32 + 2]),
	.PTSEL(	rw_data[9 * 32 + 5 : 9 * 32 + 4]),
	.VG(	  rw_data[9 * 32 + 6 : 9 * 32 + 6]),
	.VS(	  rw_data[9 * 32 + 7 : 9 * 32 + 7]),

  
  `endif

  .clka(clk),   
  .ena(1'b1),     
  .wea(i_reb_content_wea),     
  .addra(iv_reb_content_addra), 
  .dina(iv_reb_content_dina),   
  .douta(wv_reb_content_douta), 
  .clkb(clk),   
  .enb(1'b1),     
  .web(i_reb_content_web),     
  .addrb(iv_reb_content_addrb), 
  .dinb(iv_reb_content_dinb),   
  .doutb(wv_reb_content_doutb) 
);

//HPCA
BRAM_TDP_15w_16384d REBElementTable_Next(   //14 Bit Addr + 1 Bit Valid
  `ifdef CHIP_VERSION
	.RTSEL(	rw_data[10 * 32 + 1 : 10 * 32 + 0]),
	.WTSEL(	rw_data[10 * 32 + 3 : 10 * 32 + 2]),
	.PTSEL(	rw_data[10 * 32 + 5 : 10 * 32 + 4]),
	.VG(	  rw_data[10 * 32 + 6 : 10 * 32 + 6]),
	.VS(	  rw_data[10 * 32 + 7 : 10 * 32 + 7]),

  
  `endif

  .clka(clk),   
  .ena(1'b1),     
  .wea(i_reb_next_wea),     
  .addra(iv_reb_next_addra), 
  .dina(iv_reb_next_dina),   
  .douta(wv_reb_next_douta), 
  .clkb(clk),   
  .enb(1'b1),     
  .web(i_reb_next_web),     
  .addrb(iv_reb_next_addrb), 
  .dinb(iv_reb_next_dinb),   
  .doutb(wv_reb_next_doutb) 
);

//TS6N
SyncFIFO_14w_16384d REBFreeListTable(     
  `ifdef CHIP_VERSION
	.RTSEL(	rw_data[11 * 32 + 1 : 11 * 32 + 0]),
	.WTSEL(	rw_data[11 * 32 + 3 : 11 * 32 + 2]),
	.PTSEL(	rw_data[11 * 32 + 5 : 11 * 32 + 4]),
	.VG(	  rw_data[11 * 32 + 6 : 11 * 32 + 6]),
	.VS(	  rw_data[11 * 32 + 7 : 11 * 32 + 7]),

  
  `endif

  .clk(clk),               
  .srst(rst),             
  .din(iv_reb_free_din),               
  .wr_en(i_reb_free_wr_en),           
  .rd_en(i_reb_free_rd_en),           
  .dout(ov_reb_free_dout),             
  .full(),             
  .empty(o_reb_free_empty),           
  .data_count(ov_reb_free_data_count), 
  .prog_full(o_reb_free_prog_full) 
);

/**************************************** Send/Write Packet Buffer(SWPB) Queue ************************************/
reg         		q_swpb_list_head_wea_TempReg;
reg         		q_swpb_list_tail_wea_TempReg;
reg         		q_swpb_list_empty_wea_TempReg;
reg         		q_swpb_content_wea_TempReg;
reg         		q_swpb_next_wea_TempReg;
reg    [13:0]      	qv_swpb_list_head_addra_TempReg;
reg    [13:0]      	qv_swpb_list_tail_addra_TempReg;
reg    [13:0]      	qv_swpb_list_empty_addra_TempReg;
reg    [13:0]      	qv_swpb_content_addra_TempReg;
reg    [13:0]      	qv_swpb_next_addra_TempReg;
reg    [11:0]     	qv_swpb_list_head_dina_TempReg;
reg    [11:0]     	qv_swpb_list_tail_dina_TempReg;
reg    [0:0]      	qv_swpb_list_empty_dina_TempReg;
reg    [287:0]    	qv_swpb_content_dina_TempReg;
reg    [12:0]     	qv_swpb_next_dina_TempReg;

reg         		q_swpb_list_head_web_TempReg;
reg         		q_swpb_list_tail_web_TempReg;
reg         		q_swpb_list_empty_web_TempReg;
reg         		q_swpb_content_web_TempReg;
reg         		q_swpb_next_web_TempReg;
reg    [13:0]      	qv_swpb_list_head_addrb_TempReg;
reg    [13:0]      	qv_swpb_list_tail_addrb_TempReg;
reg    [13:0]      	qv_swpb_list_empty_addrb_TempReg;
reg    [13:0]      	qv_swpb_content_addrb_TempReg;
reg    [13:0]      	qv_swpb_next_addrb_TempReg;
reg    [11:0]     	qv_swpb_list_head_dinb_TempReg;
reg    [11:0]     	qv_swpb_list_tail_dinb_TempReg;
reg    [0:0]      	qv_swpb_list_empty_dinb_TempReg;
reg    [287:0]    	qv_swpb_content_dinb_TempReg;
reg    [12:0]     	qv_swpb_next_dinb_TempReg;

always @(posedge clk or posedge rst) begin
	if(rst) begin
		q_swpb_list_head_wea_TempReg <= 'd0;
		q_swpb_list_tail_wea_TempReg <= 'd0;
		q_swpb_list_empty_wea_TempReg <= 'd0;
		q_swpb_content_wea_TempReg <= 'd0;
		q_swpb_next_wea_TempReg <= 'd0;
		qv_swpb_list_head_addra_TempReg <= 'd0;
		qv_swpb_list_tail_addra_TempReg <= 'd0;
		qv_swpb_list_empty_addra_TempReg <= 'd0;
		qv_swpb_content_addra_TempReg <= 'd0;
		qv_swpb_next_addra_TempReg <= 'd0;
		qv_swpb_list_head_dina_TempReg <= 'd0;
		qv_swpb_list_tail_dina_TempReg <= 'd0;
		qv_swpb_list_empty_dina_TempReg <= 'd0;
		qv_swpb_content_dina_TempReg <= 'd0;
		qv_swpb_next_dina_TempReg <= 'd0;

		q_swpb_list_head_web_TempReg <= 'd0;
		q_swpb_list_tail_web_TempReg <= 'd0;
		q_swpb_list_empty_web_TempReg <= 'd0;
		q_swpb_content_web_TempReg <= 'd0;
		q_swpb_next_web_TempReg <= 'd0;
		qv_swpb_list_head_addrb_TempReg <= 'd0;
		qv_swpb_list_tail_addrb_TempReg <= 'd0;
		qv_swpb_list_empty_addrb_TempReg <= 'd0;
		qv_swpb_content_addrb_TempReg <= 'd0;
		qv_swpb_next_addrb_TempReg <= 'd0;
		qv_swpb_list_head_dinb_TempReg <= 'd0;
		qv_swpb_list_tail_dinb_TempReg <= 'd0;
		qv_swpb_list_empty_dinb_TempReg <= 'd0;
		qv_swpb_content_dinb_TempReg <= 'd0;
		qv_swpb_next_dinb_TempReg <= 'd0;
	end 	
	else begin
		q_swpb_list_head_wea_TempReg <= i_swpb_list_head_wea;
		q_swpb_list_tail_wea_TempReg <= i_swpb_list_tail_wea;
		q_swpb_list_empty_wea_TempReg <= i_swpb_list_empty_wea;
		q_swpb_content_wea_TempReg <= i_swpb_content_wea;
		q_swpb_next_wea_TempReg <= i_swpb_next_wea;
		qv_swpb_list_head_addra_TempReg <= iv_swpb_list_head_addra;
		qv_swpb_list_tail_addra_TempReg <= iv_swpb_list_tail_addra;
		qv_swpb_list_empty_addra_TempReg <= iv_swpb_list_empty_addra;
		qv_swpb_content_addra_TempReg <= iv_swpb_content_addra;
		qv_swpb_next_addra_TempReg <= iv_swpb_next_addra;
		qv_swpb_list_head_dina_TempReg <= iv_swpb_list_head_dina;
		qv_swpb_list_tail_dina_TempReg <= iv_swpb_list_tail_dina;
		qv_swpb_list_empty_dina_TempReg <= iv_swpb_list_empty_dina;
		qv_swpb_content_dina_TempReg <= iv_swpb_content_dina;
		qv_swpb_next_dina_TempReg <= iv_swpb_next_dina;

		q_swpb_list_head_web_TempReg <= i_swpb_list_head_web;
		q_swpb_list_tail_web_TempReg <= i_swpb_list_tail_web;
		q_swpb_list_empty_web_TempReg <= i_swpb_list_empty_web;
		q_swpb_content_web_TempReg <= i_swpb_content_web;
		q_swpb_next_web_TempReg <= i_swpb_next_web;
		qv_swpb_list_head_addrb_TempReg <= iv_swpb_list_head_addrb;
		qv_swpb_list_tail_addrb_TempReg <= iv_swpb_list_tail_addrb;
		qv_swpb_list_empty_addrb_TempReg <= iv_swpb_list_empty_addrb;
		qv_swpb_content_addrb_TempReg <= iv_swpb_content_addrb;
		qv_swpb_next_addrb_TempReg <= iv_swpb_next_addrb;
		qv_swpb_list_head_dinb_TempReg <= iv_swpb_list_head_dinb;
		qv_swpb_list_tail_dinb_TempReg <= iv_swpb_list_tail_dinb;
		qv_swpb_list_empty_dinb_TempReg <= iv_swpb_list_empty_dinb;
		qv_swpb_content_dinb_TempReg <= iv_swpb_content_dinb;
		qv_swpb_next_dinb_TempReg <= iv_swpb_next_dinb;
	end 
end 

wire    [11:0]      wv_swpb_list_head_douta;
wire    [11:0]      wv_swpb_list_tail_douta;
wire    [0:0]      wv_swpb_list_empty_douta;
wire    [287:0]    wv_swpb_content_douta;
wire    [12:0]      wv_swpb_next_douta;

wire    [11:0]      wv_swpb_list_head_doutb;
wire    [11:0]      wv_swpb_list_tail_doutb;
wire    [0:0]      wv_swpb_list_empty_doutb;
wire    [287:0]    wv_swpb_content_doutb;
wire    [12:0]      wv_swpb_next_doutb;


assign ov_swpb_list_head_douta 	= 	q_swpb_list_head_wea_TempReg ? qv_swpb_list_head_dina_TempReg : 
							   		(q_swpb_list_head_web_TempReg && (qv_swpb_list_head_addrb_TempReg == qv_swpb_list_head_addra_TempReg)) ? qv_swpb_list_head_dinb_TempReg :
							 		wv_swpb_list_head_douta;

assign ov_swpb_list_tail_douta 	= 	q_swpb_list_tail_wea_TempReg ? qv_swpb_list_tail_dina_TempReg : 
							   		(q_swpb_list_tail_web_TempReg && (qv_swpb_list_tail_addrb_TempReg == qv_swpb_list_tail_addra_TempReg)) ? qv_swpb_list_tail_dinb_TempReg :
							 		wv_swpb_list_tail_douta;

assign ov_swpb_list_empty_douta 	= 	q_swpb_list_empty_wea_TempReg ? qv_swpb_list_empty_dina_TempReg : 
							   		(q_swpb_list_empty_web_TempReg && (qv_swpb_list_empty_addrb_TempReg == qv_swpb_list_empty_addra_TempReg)) ? qv_swpb_list_empty_dinb_TempReg :
							 		wv_swpb_list_empty_douta;

assign ov_swpb_content_douta 	= 	q_swpb_content_wea_TempReg ? qv_swpb_content_dina_TempReg : 
							   		(q_swpb_content_web_TempReg && (qv_swpb_content_addrb_TempReg == qv_swpb_content_addra_TempReg)) ? qv_swpb_content_dinb_TempReg :
							 		wv_swpb_content_douta;

assign ov_swpb_next_douta 		= 	q_swpb_next_wea_TempReg ? qv_swpb_next_dina_TempReg : 
							   		(q_swpb_next_web_TempReg && (qv_swpb_next_addrb_TempReg == qv_swpb_next_addra_TempReg)) ? qv_swpb_next_dinb_TempReg :
							 		wv_swpb_next_douta;


assign ov_swpb_list_head_doutb 	= 	q_swpb_list_head_web_TempReg ? qv_swpb_list_head_dinb_TempReg :
									(q_swpb_list_head_wea_TempReg && (qv_swpb_list_head_addra_TempReg == qv_swpb_list_head_addrb_TempReg)) ? qv_swpb_list_head_dina_TempReg : 
									wv_swpb_list_head_doutb;

assign ov_swpb_list_tail_doutb 	= 	q_swpb_list_tail_web_TempReg ? qv_swpb_list_tail_dinb_TempReg :
									(q_swpb_list_tail_wea_TempReg && (qv_swpb_list_tail_addra_TempReg == qv_swpb_list_tail_addrb_TempReg)) ? qv_swpb_list_tail_dina_TempReg : 
									wv_swpb_list_tail_doutb;

assign ov_swpb_list_empty_doutb 	= 	q_swpb_list_empty_web_TempReg ? qv_swpb_list_empty_dinb_TempReg :
									(q_swpb_list_empty_wea_TempReg && (qv_swpb_list_empty_addra_TempReg == qv_swpb_list_empty_addrb_TempReg)) ? qv_swpb_list_empty_dina_TempReg : 
									wv_swpb_list_empty_doutb;

assign ov_swpb_content_doutb 	= 	q_swpb_content_web_TempReg ? qv_swpb_content_dinb_TempReg :
									(q_swpb_content_wea_TempReg && (qv_swpb_content_addra_TempReg == qv_swpb_content_addrb_TempReg)) ? qv_swpb_content_dina_TempReg : 
									wv_swpb_content_doutb;

assign ov_swpb_next_doutb 		= 	q_swpb_next_web_TempReg ? qv_swpb_next_dinb_TempReg :
									(q_swpb_next_wea_TempReg && (qv_swpb_next_addra_TempReg == qv_swpb_next_addrb_TempReg)) ? qv_swpb_next_dina_TempReg : 
									wv_swpb_next_doutb;

//HPCA
BRAM_TDP_12w_16384d SWPBListTable_Head(
  `ifdef CHIP_VERSION
	.RTSEL(	rw_data[12 * 32 + 1 : 12 * 32 + 0]),
	.WTSEL(	rw_data[12 * 32 + 3 : 12 * 32 + 2]),
	.PTSEL(	rw_data[12 * 32 + 5 : 12 * 32 + 4]),
	.VG(	  rw_data[12 * 32 + 6 : 12 * 32 + 6]),
	.VS(	  rw_data[12 * 32 + 7 : 12 * 32 + 7]),

  `endif

  .clka(clk),   
  .ena(1'b1),     
  .wea(i_swpb_list_head_wea),     
  .addra(iv_swpb_list_head_addra), 
  .dina(iv_swpb_list_head_dina),   
  .douta(wv_swpb_list_head_douta), 
  .clkb(clk),   
  .enb(1'b1),     
  .web(i_swpb_list_head_web),     
  .addrb(iv_swpb_list_head_addrb), 
  .dinb(iv_swpb_list_head_dinb),   
  .doutb(wv_swpb_list_head_doutb) 
);

//HPCA
BRAM_TDP_12w_16384d SWPBListTable_Tail(
  `ifdef CHIP_VERSION
	.RTSEL(	rw_data[13 * 32 + 1 : 13 * 32 + 0]),
	.WTSEL(	rw_data[13 * 32 + 3 : 13 * 32 + 2]),
	.PTSEL(	rw_data[13 * 32 + 5 : 13 * 32 + 4]),
	.VG(	  rw_data[13 * 32 + 6 : 13 * 32 + 6]),
	.VS(	  rw_data[13 * 32 + 7 : 13 * 32 + 7]),


  `endif

  .clka(clk),   
  .ena(1'b1),     
  .wea(i_swpb_list_tail_wea),     
  .addra(iv_swpb_list_tail_addra), 
  .dina(iv_swpb_list_tail_dina),   
  .douta(wv_swpb_list_tail_douta), 
  .clkb(clk),   
  .enb(1'b1),     
  .web(i_swpb_list_tail_web),     
  .addrb(iv_swpb_list_tail_addrb), 
  .dinb(iv_swpb_list_tail_dinb),   
  .doutb(wv_swpb_list_tail_doutb) 
);

//HPCA
BRAM_TDP_1w_16384d SWPBListTable_Empty(
  `ifdef CHIP_VERSION
	.RTSEL(	rw_data[14 * 32 + 1 : 14 * 32 + 0]),
	.WTSEL(	rw_data[14 * 32 + 3 : 14 * 32 + 2]),
	.PTSEL(	rw_data[14 * 32 + 5 : 14 * 32 + 4]),
	.VG(	  rw_data[14 * 32 + 6 : 14 * 32 + 6]),
	.VS(	  rw_data[14 * 32 + 7 : 14 * 32 + 7]),

  `endif

  .clka(clk),   
  .ena(1'b1),     
  .wea(i_swpb_list_empty_wea),     
  .addra(iv_swpb_list_empty_addra), 
  .dina(iv_swpb_list_empty_dina),   
  .douta(wv_swpb_list_empty_douta), 
  .clkb(clk),   
  .enb(1'b1),     
  .web(i_swpb_list_empty_web),     
  .addrb(iv_swpb_list_empty_addrb), 
  .dinb(iv_swpb_list_empty_dinb),   
  .doutb(wv_swpb_list_empty_doutb) 
);

//TS6N
BRAM_TDP_288w_4096d SWPBElementTable_Content(   //256 Bit Meta(Largest header is 32B, i.e. WRITE_FIRST_WITH_IMM), 32-bit WQE offset
  `ifdef CHIP_VERSION
	.RTSEL(	rw_data[15 * 32 + 1 : 15 * 32 + 0]),
	.WTSEL(	rw_data[15 * 32 + 3 : 15 * 32 + 2]),
	.PTSEL(	rw_data[15 * 32 + 5 : 15 * 32 + 4]),
	.VG(	  rw_data[15 * 32 + 6 : 15 * 32 + 6]),
	.VS(	  rw_data[15 * 32 + 7 : 15 * 32 + 7]),

  `endif

  .clka(clk),   
  .ena(1'b1),     
  .wea(i_swpb_content_wea),     
  .addra(iv_swpb_content_addra), 
  .dina(iv_swpb_content_dina),   
  .douta(wv_swpb_content_douta), 
  .clkb(clk),   
  .enb(1'b1),     
  .web(i_swpb_content_web),     
  .addrb(iv_swpb_content_addrb), 
  .dinb(iv_swpb_content_dinb),   
  .doutb(wv_swpb_content_doutb) 
);

//HPCA
BRAM_TDP_13w_4096d SWPBElementTable_Next(   //12 Bit Addr
  `ifdef CHIP_VERSION
	.RTSEL(	rw_data[16 * 32 + 1 : 16 * 32 + 0]),
	.WTSEL(	rw_data[16 * 32 + 3 : 16 * 32 + 2]),
	.PTSEL(	rw_data[16 * 32 + 5 : 16 * 32 + 4]),
	.VG(	  rw_data[16 * 32 + 6 : 16 * 32 + 6]),
	.VS(	  rw_data[16 * 32 + 7 : 16 * 32 + 7]),

  `endif

  .clka(clk),   
  .ena(1'b1),     
  .wea(i_swpb_next_wea),     
  .addra(iv_swpb_next_addra), 
  .dina(iv_swpb_next_dina),   
  .douta(wv_swpb_next_douta), 
  .clkb(clk),   
  .enb(1'b1),     
  .web(i_swpb_next_web),     
  .addrb(iv_swpb_next_addrb), 
  .dinb(iv_swpb_next_dinb),   
  .doutb(wv_swpb_next_doutb) 
);

//TS6N
SyncFIFO_12w_4096d SWPBFreeListFIFO(
  `ifdef CHIP_VERSION
	.RTSEL(	rw_data[17 * 32 + 1 : 17 * 32 + 0]),
	.WTSEL(	rw_data[17 * 32 + 3 : 17 * 32 + 2]),
	.PTSEL(	rw_data[17 * 32 + 5 : 17 * 32 + 4]),
	.VG(	  rw_data[17 * 32 + 6 : 17 * 32 + 6]),
	.VS(	  rw_data[17 * 32 + 7 : 17 * 32 + 7]),


  `endif

  .clk(clk),               
  .srst(rst),             
  .din(iv_swpb_free_din),               
  .wr_en(i_swpb_free_wr_en),           
  .rd_en(i_swpb_free_rd_en),           
  .dout(ov_swpb_free_dout),             
  .full(),             
  .empty(o_swpb_free_empty),           
  .data_count(ov_swpb_free_data_count), 
  .prog_full(o_swpb_free_prog_full) 
);

/*----------------------------- Connect dbg bus -------------------------------------*/
wire   [`DBG_NUM_MULTI_QUEUE * 32 - 1 : 0]   coalesced_bus;

assign coalesced_bus = {
                            q_rpb_list_head_wea_TempReg,
                            q_rpb_list_tail_wea_TempReg,
                            q_rpb_list_empty_wea_TempReg,
                            q_rpb_content_wea_TempReg,
                            q_rpb_next_wea_TempReg,
                            qv_rpb_list_head_addra_TempReg,
                            qv_rpb_list_tail_addra_TempReg,
                            qv_rpb_list_empty_addra_TempReg,
                            qv_rpb_content_addra_TempReg,
                            qv_rpb_next_addra_TempReg,
                            qv_rpb_list_head_dina_TempReg,
                            qv_rpb_list_tail_dina_TempReg,
                            qv_rpb_list_empty_dina_TempReg,
                            qv_rpb_content_dina_TempReg,
                            qv_rpb_next_dina_TempReg,
                            q_rpb_list_head_web_TempReg,
                            q_rpb_list_tail_web_TempReg,
                            q_rpb_list_empty_web_TempReg,
                            q_rpb_content_web_TempReg,
                            q_rpb_next_web_TempReg,
                            qv_rpb_list_head_addrb_TempReg,
                            qv_rpb_list_tail_addrb_TempReg,
                            qv_rpb_list_empty_addrb_TempReg,
                            qv_rpb_content_addrb_TempReg,
                            qv_rpb_next_addrb_TempReg,
                            qv_rpb_list_head_dinb_TempReg,
                            qv_rpb_list_tail_dinb_TempReg,
                            qv_rpb_list_empty_dinb_TempReg,
                            qv_rpb_content_dinb_TempReg,
                            qv_rpb_next_dinb_TempReg,
                            q_reb_list_head_wea_TempReg,
                            q_reb_list_tail_wea_TempReg,
                            q_reb_list_empty_wea_TempReg,
                            q_reb_content_wea_TempReg,
                            q_reb_next_wea_TempReg,
                            qv_reb_list_head_addra_TempReg,
                            qv_reb_list_tail_addra_TempReg,
                            qv_reb_list_empty_addra_TempReg,
                            qv_reb_content_addra_TempReg,
                            qv_reb_next_addra_TempReg,
                            qv_reb_list_head_dina_TempReg,
                            qv_reb_list_tail_dina_TempReg,
                            qv_reb_list_empty_dina_TempReg,
                            qv_reb_content_dina_TempReg,
                            qv_reb_next_dina_TempReg,
                            q_reb_list_head_web_TempReg,
                            q_reb_list_tail_web_TempReg,
                            q_reb_list_empty_web_TempReg,
                            q_reb_content_web_TempReg,
                            q_reb_next_web_TempReg,
                            qv_reb_list_head_addrb_TempReg,
                            qv_reb_list_tail_addrb_TempReg,
                            qv_reb_list_empty_addrb_TempReg,
                            qv_reb_content_addrb_TempReg,
                            qv_reb_next_addrb_TempReg,
                            qv_reb_list_head_dinb_TempReg,
                            qv_reb_list_tail_dinb_TempReg,
                            qv_reb_list_empty_dinb_TempReg,
                            qv_reb_content_dinb_TempReg,
                            qv_reb_next_dinb_TempReg,
                            q_swpb_list_head_wea_TempReg,
                            q_swpb_list_tail_wea_TempReg,
                            q_swpb_list_empty_wea_TempReg,
                            q_swpb_content_wea_TempReg,
                            q_swpb_next_wea_TempReg,
                            qv_swpb_list_head_addra_TempReg,
                            qv_swpb_list_tail_addra_TempReg,
                            qv_swpb_list_empty_addra_TempReg,
                            qv_swpb_content_addra_TempReg,
                            qv_swpb_next_addra_TempReg,
                            qv_swpb_list_head_dina_TempReg,
                            qv_swpb_list_tail_dina_TempReg,
                            qv_swpb_list_empty_dina_TempReg,
                            qv_swpb_content_dina_TempReg,
                            qv_swpb_next_dina_TempReg,
                            q_swpb_list_head_web_TempReg,
                            q_swpb_list_tail_web_TempReg,
                            q_swpb_list_empty_web_TempReg,
                            q_swpb_content_web_TempReg,
                            q_swpb_next_web_TempReg,
                            qv_swpb_list_head_addrb_TempReg,
                            qv_swpb_list_tail_addrb_TempReg,
                            qv_swpb_list_empty_addrb_TempReg,
                            qv_swpb_content_addrb_TempReg,
                            qv_swpb_next_addrb_TempReg,
                            qv_swpb_list_head_dinb_TempReg,
                            qv_swpb_list_tail_dinb_TempReg,
                            qv_swpb_list_empty_dinb_TempReg,
                            qv_swpb_content_dinb_TempReg,
                            qv_swpb_next_dinb_TempReg,
                            wv_reb_list_head_douta,
                            wv_reb_list_tail_douta,
                            wv_reb_list_empty_douta,
                            wv_reb_content_douta,
                            wv_reb_next_douta,
                            wv_reb_list_head_doutb,
                            wv_reb_list_tail_doutb,
                            wv_reb_list_empty_doutb,
                            wv_reb_content_doutb,
                            wv_reb_next_doutb,
                            wv_swpb_list_head_douta,
                            wv_swpb_list_tail_douta,
                            wv_swpb_list_empty_douta,
                            wv_swpb_content_douta,
                            wv_swpb_next_douta,
                            wv_swpb_list_head_doutb,
                            wv_swpb_list_tail_doutb,
                            wv_swpb_list_empty_doutb,
                            wv_swpb_content_doutb,
                            wv_swpb_next_doutb
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
                    (dbg_sel == 95) ?   coalesced_bus[32 * 96 - 1 : 32 * 95] : 32'd0;

//assign dbg_bus = coalesced_bus;

assign init_rw_data = {18{32'b00000000_00000000_00000000_11010101}};

endmodule
