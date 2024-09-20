`timescale 1ns / 1ps

`include "msg_def_v2p_h.vh"
`include "msg_def_ctxmgt_h.vh"
`include "chip_include_rdma.vh"


`define NORMAL 			1'b0
`define WRAP_AROUND 	1'b1

`define STALL_LIMIT 	32'd1024

module DoorbellProcessing
#(
	parameter 	RW_REG_NUM = 1
)
(
    input   wire                clk,
    input   wire                rst,

	input 	wire 	[RW_REG_NUM * 32 - 1 : 0]	rw_data,
	output 	wire 	[RW_REG_NUM * 32 - 1 : 0]	init_rw_data,

//Interface with PIO
    input   wire                i_pio_empty,
    output  wire                o_pio_rd_en,
    input   wire    [63:0]      iv_pio_data,

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
    input	wire 	[255:0]		iv_cxtmgt_cxt_data,

//VirtToPhys
    output  wire                o_vtp_cmd_wr_en,
    input   wire                i_vtp_cmd_prog_full,
    output  wire    [255:0]     ov_vtp_cmd_data,

    input   wire                i_vtp_resp_empty,
    output  wire                o_vtp_resp_rd_en,
    input   wire    [7:0]       iv_vtp_resp_data,

//WQEScheduler
    output  wire                o_sch_md_wr_en,
    input   wire                i_sch_md_prog_full,
    output  wire    [255:0]     ov_sch_md_data,

    input   wire    [31:0]      dbg_sel,
    output  wire    [32 - 1 : 0]      dbg_bus
    //output  wire    [`DBG_NUM_DOORBELL_PROCESSING * 32 - 1 : 0]      dbg_bus
);

reg                			q_pio_rd_en;
reg                			q_cxtmgt_cmd_wr_en;
reg    		[127:0]			qv_cxtmgt_cmd_data;
reg                			q_cxtmgt_resp_rd_en;
reg                			q_cxtmgt_cxt_rd_en;
reg                			q_vtp_cmd_wr_en;
reg    		[255:0]     	qv_vtp_cmd_data;
reg                			q_vtp_resp_rd_en;
reg                			q_sch_md_wr_en;
reg    		[255:0]     	qv_sch_md_data;
reg                 		q_md_fifo_wr_en;
reg     	[63:0]      	qv_md_fifo_din;
reg                 		q_md_fifo_rd_en;

reg         [3:0]       	qv_mthca_mpt_flag_sw_owns;
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

wire		[3:0]       	wv_vtp_type;
wire       	[3:0]       	wv_vtp_opcode;      //Indicates the VirtToPhys operation
wire		[31:0]      	wv_vtp_pd;
wire        [31:0]      	wv_vtp_lkey;
wire        [63:0]      	wv_vtp_vaddr;
wire        [31:0]      	wv_vtp_length;
wire        [31:0]      	wv_vtp_flags;

wire    	[15:0]          wv_md_PMTU;
wire    	[15:0]          wv_md_PKey;
wire    	[31:0]          wv_md_LKey;
wire    	[31:0]          wv_md_PD;
wire    	[23:0]          wv_md_DstQPN;
wire    	[1:0]           wv_md_ST;
wire 		[7:0]			wv_PMTU_indicator;

wire    	[15:0]          wv_md_Size;
wire                    	w_md_Fence;
wire    	[4:0]           wv_md_OpCode;
wire    	[25:0]          wv_md_Offset;
wire    	[23:0]          wv_md_SrcQPN;

wire    	[63:0]      	wv_md_fifo_dout;
wire         		    	w_md_fifo_empty;
wire                		w_md_fifo_prog_full;  

wire 		[7:0]			wv_sq_entry_size_log;
wire 		[31:0]			wv_sq_length;

wire 						w_sq_wrap_around;
reg 						q_state;

reg 		[31:0]			qv_pipeline_stall;
reg 						q_stall_flag;

assign wv_sq_entry_size_log = iv_cxtmgt_cxt_data[135:128];
assign wv_sq_length = iv_cxtmgt_cxt_data[191:160];

//ila_pmtu ila_pmtu(

//  .clk(clk),
//    .probe0(wv_md_PMTU)
//);

assign o_pio_rd_en = q_pio_rd_en;
assign o_cxtmgt_cmd_wr_en = q_cxtmgt_cmd_wr_en;
assign ov_cxtmgt_cmd_data = qv_cxtmgt_cmd_data;
assign o_cxtmgt_resp_rd_en = q_cxtmgt_resp_rd_en;
assign o_cxtmgt_cxt_rd_en = q_cxtmgt_cxt_rd_en;
assign o_vtp_cmd_wr_en = q_vtp_cmd_wr_en;
assign ov_vtp_cmd_data = qv_vtp_cmd_data;
assign o_vtp_resp_rd_en = q_vtp_resp_rd_en;
assign o_sch_md_wr_en = q_sch_md_wr_en;
assign ov_sch_md_data = qv_sch_md_data;

/*  Doorbell Format
-----------------------------------------------------------------
|       +3      |       +2      |       +1      |       +0      |
-----------------------------------------------------------------
|7|6|5|4|3|2|1|0|7|6|5|4|3|2|1|0|7|6|5|4|3|2|1|0|7|6|5|4|3|2|1|0|
-----------------------------------------------------------------
|                       WQE Offset                  |F| Opcode  |
-----------------------------------------------------------------
|                       QPN                     |       Size    |
-----------------------------------------------------------------
*/

//Doorbell data will be used twice:
//1. Fetch cxt; 2.When cxt back, construct metadata
//Hence we use an extra FIFO
SyncFIFO_64w_32d MetadataFIFO_Inst(
`ifdef CHIP_VERSION
	.RTSEL(rw_data[0 * 32 + 1 : 0 * 32 + 0]),
	.WTSEL(rw_data[0 * 32 + 3 : 0 * 32 + 2]),
	.PTSEL(rw_data[0 * 32 + 5 : 0 * 32 + 4]),
	.VG(rw_data[0 * 32 + 6 : 0 * 32 + 6]),
	.VS(rw_data[0 * 32 + 7 : 0 * 32 + 7]),
  `endif

  .clk(clk),              
  .srst(rst),            
  .din(qv_md_fifo_din),              
  .wr_en(q_md_fifo_wr_en),          
  .rd_en(q_md_fifo_rd_en),          
  .dout(wv_md_fifo_dout),            
  .full(),            
  .empty(w_md_fifo_empty),          
  .prog_full(w_md_fifo_prog_full)  
);

//wire    [4:0]       wv_OpCode;
//wire                w_Fence;
//wire    [25:0]      wv_Offset;
//wire    [7:0]       wv_Size;
//wire    [23:0]      wv_QPN;

//assign wv_OpCode = wv_md_fifo_dout[4:0];
//assign w_Fence = wv_md_fifo_dout[5];
//assign wv_Offset = wv_md_fifo_dout[31:6];
//assign wv_Size = wv_md_fifo_dout[39:32];
//assign wv_QPN = wv_md_fifo_dout[63:32];



assign wv_md_SrcQPN = wv_md_fifo_dout[63:40];
assign wv_md_Size = wv_md_fifo_dout[39:32];
assign w_md_Fence = wv_md_fifo_dout[5];
assign wv_md_OpCode = wv_md_fifo_dout[4:0];
assign wv_md_Offset = wv_md_fifo_dout[31:6];

//-- q_md_fifo_wr_en --
//-- qv_md_fifo_din --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_md_fifo_wr_en <= 1'b0;
        qv_md_fifo_din <= 'd0;        
    end
    else if (!i_pio_empty && !i_cxtmgt_cmd_prog_full && !w_md_fifo_prog_full && !q_stall_flag) begin
        q_md_fifo_wr_en <= 1'b1;
        qv_md_fifo_din <= iv_pio_data;
    end
    else begin
        q_md_fifo_wr_en <= 1'b0;
        qv_md_fifo_din <= qv_md_fifo_din;
    end
end

/************************* CxtMgt Read ******************************/
//-- q_pio_rd_en --
always @(*) begin
	if(rst) begin
		q_pio_rd_en = 1'b0;
	end 
	else begin
		q_pio_rd_en = !i_pio_empty && !i_cxtmgt_cmd_prog_full && !w_md_fifo_prog_full && !q_stall_flag;
	end 
end

/*  CxtMgt Command Format
-----------------------------------------------------------------
|       +3      |       +2      |       +1      |       +0      |
-----------------------------------------------------------------
|7|6|5|4|3|2|1|0|7|6|5|4|3|2|1|0|7|6|5|4|3|2|1|0|7|6|5|4|3|2|1|0|
-----------------------------------------------------------------
|                       3 * 4 Bytes Zero                        |
-----------------------------------------------------------------
| Type  |OpCode |                   QPN                         |
-----------------------------------------------------------------
*/
assign w_sq_wrap_around = (!i_cxtmgt_cxt_empty && !i_cxtmgt_resp_empty && (wv_vtp_vaddr + wv_vtp_length) > wv_sq_length);

always @(posedge clk or posedge rst) begin
	if(rst) begin
		q_state <= `NORMAL;
	end 
	else if(q_state == `NORMAL && w_sq_wrap_around && !i_vtp_cmd_prog_full && !q_stall_flag) begin
		q_state <= `WRAP_AROUND;
	end 
	else if(q_state == `WRAP_AROUND && !i_sch_md_prog_full && !i_vtp_cmd_prog_full && !q_stall_flag) begin
		q_state <= `NORMAL;
	end 
	else begin
		q_state <= q_state;
	end 
end 


//-- q_cxtmgt_cmd_wr_en --
//-- qv_cxtmgt_cmd_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_cxtmgt_cmd_wr_en <= 1'b0;
        qv_cxtmgt_cmd_data <= 'd0;
    end
    else if (!i_pio_empty && !i_cxtmgt_cmd_prog_full && !w_md_fifo_prog_full && !q_stall_flag) begin
        q_cxtmgt_cmd_wr_en <= 1'b1;
        qv_cxtmgt_cmd_data <= {`RD_QP_CTX, `RD_QP_SST, iv_pio_data[63:40], 96'h0};
    end
    else begin
        q_cxtmgt_cmd_wr_en <= 1'b0;
        qv_cxtmgt_cmd_data <= qv_cxtmgt_cmd_data;

    end
end

//-- q_cxtmgt_resp_rd_en --
//-- q_cxtmgt_cxt_rd_en --
always @(*) begin
	if(rst) begin
		q_cxtmgt_resp_rd_en = 1'b0;
		q_cxtmgt_cxt_rd_en = 1'b0;
	end 
    else if(q_state == `NORMAL && !w_sq_wrap_around && !i_cxtmgt_cxt_empty && !i_cxtmgt_resp_empty && !w_md_fifo_empty && !i_sch_md_prog_full && !i_vtp_cmd_prog_full && !q_stall_flag) begin
        q_cxtmgt_resp_rd_en = 1'b1;
        q_cxtmgt_cxt_rd_en = 1'b1;
    end 
    else if(q_state == `WRAP_AROUND && !i_cxtmgt_cxt_empty && !i_cxtmgt_resp_empty && !w_md_fifo_empty && !i_sch_md_prog_full && !i_vtp_cmd_prog_full && !q_stall_flag) begin
        q_cxtmgt_resp_rd_en = 1'b1;
        q_cxtmgt_cxt_rd_en = 1'b1;
	end
    else begin
        q_cxtmgt_resp_rd_en = 1'b0;
        q_cxtmgt_cxt_rd_en = 1'b0;
    end
end

/*  CxtMgt Read All Response format
-----------------------------------------------------------------
|       +3      |       +2      |       +1      |       +0      |
-----------------------------------------------------------------
|7|6|5|4|3|2|1|0|7|6|5|4|3|2|1|0|7|6|5|4|3|2|1|0|7|6|5|4|3|2|1|0|
-----------------------------------------------------------------
|              DstQPN                           |    PMTU   |ST |
-----------------------------------------------------------------
|                             P_Key                             |
-----------------------------------------------------------------
|                             LKey                              |
-----------------------------------------------------------------
|                      Protection Domain                        |
-----------------------------------------------------------------
*/

//Command passed to VirtToPhys
assign wv_vtp_type = `RD_REQ_WQE;
assign wv_vtp_opcode = `RD_SQ_FWQE;
assign wv_vtp_pd = iv_cxtmgt_cxt_data[127:96];
//assign wv_vtp_vaddr = {38'h0, wv_md_fifo_dout[31:6]} << 4;         //Offset from doorbell
assign wv_vtp_vaddr = {38'h0, wv_md_fifo_dout[31:8]} << 4;         //Offset from doorbell
assign wv_vtp_lkey = iv_cxtmgt_cxt_data[95:64];
assign wv_vtp_length = {24'h0, wv_md_fifo_dout[39:32]} << 4;         //Length in doorbell is in unit of 16B

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
    else if (!i_cxtmgt_cxt_empty && !i_cxtmgt_resp_empty && !w_md_fifo_empty && !i_sch_md_prog_full && !i_vtp_cmd_prog_full && !q_stall_flag) begin 
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
        q_ibv_access_local_write = 'd0;
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
    else if (q_state == `NORMAL && !w_sq_wrap_around && !i_cxtmgt_cxt_empty && !i_cxtmgt_resp_empty && !w_md_fifo_empty && !i_sch_md_prog_full && !i_vtp_cmd_prog_full && !q_stall_flag) begin
        q_vtp_cmd_wr_en <= 1'b1;
        qv_vtp_cmd_data <= {32'd0, wv_vtp_length, wv_vtp_vaddr, wv_vtp_lkey, wv_vtp_pd, wv_vtp_flags, 24'd0, wv_vtp_opcode, wv_vtp_type};
    end
    else if (q_state == `NORMAL && w_sq_wrap_around && !i_cxtmgt_cxt_empty && !i_cxtmgt_resp_empty && !w_md_fifo_empty && !i_sch_md_prog_full && !i_vtp_cmd_prog_full && !q_stall_flag) begin
        q_vtp_cmd_wr_en <= 1'b1;
        qv_vtp_cmd_data <= {32'd0, (wv_sq_length - wv_vtp_vaddr), wv_vtp_vaddr, wv_vtp_lkey, wv_vtp_pd, wv_vtp_flags, 24'd0, wv_vtp_opcode, wv_vtp_type};
    end
    else if (q_state == `WRAP_AROUND && !i_cxtmgt_cxt_empty && !i_cxtmgt_resp_empty && !w_md_fifo_empty && !i_sch_md_prog_full && !i_vtp_cmd_prog_full && !q_stall_flag) begin
        q_vtp_cmd_wr_en <= 1'b1;
        //qv_vtp_cmd_data <= {32'd0, (wv_vtp_length - (wv_sq_length - wv_vtp_vaddr)), 'd0, wv_vtp_lkey, wv_vtp_pd, wv_vtp_flags, 24'd0, wv_vtp_opcode, wv_vtp_type};
        qv_vtp_cmd_data <= {32'd0, (wv_vtp_length - (wv_sq_length - wv_vtp_vaddr)),  wv_vtp_lkey, wv_vtp_pd, wv_vtp_flags, 24'd0, wv_vtp_opcode, wv_vtp_type};
    end
    else begin
        q_vtp_cmd_wr_en <= 1'b0;
        qv_vtp_cmd_data <= qv_vtp_cmd_data;
    end
end

//-- q_vtp_resp_rd_en --
always @(*) begin
    q_vtp_resp_rd_en = !i_vtp_resp_empty;   //We can directly read VTP response
end

//assign wv_md_PMTU = (1 << iv_cxtmgt_cxt_data[55:48]);
assign wv_PMTU_indicator = (iv_cxtmgt_cxt_data[55:53]);
assign wv_md_PMTU = (wv_PMTU_indicator == 3'd1) ? 16'd256 : 
					(wv_PMTU_indicator == 3'd2) ? 16'd512 :
					(wv_PMTU_indicator == 3'd3) ? 16'd1024 :
					(wv_PMTU_indicator == 3'd4) ? 16'd2048 :
					(wv_PMTU_indicator == 3'd5) ? 16'd4096 : 16'hFFFF;
assign wv_md_PKey = iv_cxtmgt_cxt_data[47:32];
assign wv_md_LKey = iv_cxtmgt_cxt_data[95:64];
assign wv_md_PD = iv_cxtmgt_cxt_data[127:96];
assign wv_md_DstQPN = iv_cxtmgt_cxt_data[31:8];

assign wv_md_ST = iv_cxtmgt_cxt_data[1:0];


//-- q_sch_md_wr_en --
//-- qv_sch_md_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_sch_md_wr_en <= 1'b0;
        qv_sch_md_data <= 'd0;        
    end
    else if (q_state == `NORMAL && !w_sq_wrap_around && !i_cxtmgt_cxt_empty && !i_cxtmgt_resp_empty && !w_md_fifo_empty && !i_sch_md_prog_full && !i_vtp_cmd_prog_full && !q_stall_flag) begin
        q_sch_md_wr_en <= 1'b1;
        //qv_sch_md_data <= {wv_vtp_vaddr, wv_sq_length, 8'h0, wv_md_PMTU, wv_md_Size, 16'h0, wv_md_PKey, wv_md_LKey, wv_md_PD, wv_md_DstQPN, 8'd0, wv_md_SrcQPN, wv_md_ST, w_md_Fence, wv_md_OpCode};
        qv_sch_md_data <= {wv_vtp_vaddr, wv_sq_length, wv_md_PMTU, wv_md_Size, 16'h0, wv_md_PKey, wv_md_LKey, wv_md_PD, wv_md_DstQPN, 8'd0, wv_md_SrcQPN, wv_md_ST, w_md_Fence, wv_md_OpCode};
    end
    else if (q_state == `WRAP_AROUND && !i_cxtmgt_cxt_empty && !i_cxtmgt_resp_empty && !w_md_fifo_empty && !i_sch_md_prog_full && !i_vtp_cmd_prog_full && !q_stall_flag) begin
        q_sch_md_wr_en <= 1'b1;
        //qv_sch_md_data <= {wv_vtp_vaddr, wv_sq_length, 8'h0, wv_md_PMTU, wv_md_Size, 16'h0, wv_md_PKey, wv_md_LKey, wv_md_PD, wv_md_DstQPN, 8'd0, wv_md_SrcQPN, wv_md_ST, w_md_Fence, wv_md_OpCode};
        qv_sch_md_data <= {wv_vtp_vaddr, wv_sq_length, wv_md_PMTU, wv_md_Size, 16'h0, wv_md_PKey, wv_md_LKey, wv_md_PD, wv_md_DstQPN, 8'd0, wv_md_SrcQPN, wv_md_ST, w_md_Fence, wv_md_OpCode};
    end
    else begin
        q_sch_md_wr_en <= 1'b0;
        qv_sch_md_data <= 'd0;
    end
end

//-- q_md_fifo_rd_en --
always @(*) begin
	if(rst) begin
		q_md_fifo_rd_en = 1'b0;
	end 
    else if(q_state == `NORMAL && !w_sq_wrap_around && !w_md_fifo_empty && !i_cxtmgt_resp_empty && !i_cxtmgt_cxt_empty && !i_sch_md_prog_full && !i_vtp_cmd_prog_full && !q_stall_flag) begin
        q_md_fifo_rd_en = 1'b1;
    end
    else if(q_state == `WRAP_AROUND && !w_md_fifo_empty && !i_cxtmgt_resp_empty && !i_cxtmgt_cxt_empty && !i_sch_md_prog_full && !i_vtp_cmd_prog_full && !q_stall_flag) begin
        q_md_fifo_rd_en = 1'b1;
    end
    else begin
        q_md_fifo_rd_en = 1'b0;
    end
end

//-- q_stall_flag --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		q_stall_flag <= 'd0;
	end 
	else if(i_sch_md_prog_full) begin
		q_stall_flag <= 'd1;
	end 
	else if(qv_pipeline_stall + 32'd1 == `STALL_LIMIT) begin
		q_stall_flag <= 'd0;
	end 
	else begin
		q_stall_flag <= q_stall_flag;
	end 
end 

//-- qv_pipeline_stall --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_pipeline_stall <= 'd0;
	end 
	else if(qv_pipeline_stall + 32'd1 == `STALL_LIMIT) begin
		qv_pipeline_stall <= 'd0;
	end 
	else if(q_stall_flag) begin
		qv_pipeline_stall <= qv_pipeline_stall + 32'd1;
	end 
	else begin
		qv_pipeline_stall <= 'd0;
	end 
end 

//Connect dbg signals
assign dbg_bus =    (dbg_sel == 0) ? {
                                        q_pio_rd_en,
                                        q_cxtmgt_cmd_wr_en,
                                        q_cxtmgt_resp_rd_en,
                                        q_cxtmgt_cxt_rd_en,
                                        q_vtp_cmd_wr_en,
                                        q_vtp_resp_rd_en,
                                        q_sch_md_wr_en,
                                        q_md_fifo_wr_en,
                                        q_md_fifo_rd_en,
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
                                        w_md_Fence,
                                        w_sq_wrap_around,
                                        q_state,
                                        w_md_fifo_empty,
                                        w_md_fifo_prog_full,
                                        wv_md_ST
                                        }   :
                    (dbg_sel == 1)  ?  qv_mthca_mpt_flag_sw_owns :
                    (dbg_sel == 2)  ?  wv_vtp_type :
                    (dbg_sel == 3)  ?  wv_vtp_opcode :      
                    (dbg_sel == 4)  ?  wv_md_OpCode :
                    (dbg_sel == 5)  ?  wv_sq_entry_size_log :
                    (dbg_sel == 6)  ?  wv_PMTU_indicator :
                    (dbg_sel == 7)  ?  wv_md_PMTU :
                    (dbg_sel == 8)  ?  wv_md_PKey :
                    (dbg_sel == 9)  ?  wv_md_Size :
                    (dbg_sel == 10) ?  wv_md_SrcQPN :
                    (dbg_sel == 11) ?  wv_md_DstQPN :
                    (dbg_sel == 12) ?  wv_md_Offset :
                    (dbg_sel == 13) ?  wv_vtp_pd :
                    (dbg_sel == 14) ?  wv_vtp_lkey :
                    (dbg_sel == 15) ?  wv_sq_length :
                    (dbg_sel == 16) ?  wv_vtp_length :
                    (dbg_sel == 17) ?  wv_vtp_flags :
                    (dbg_sel == 18) ?  wv_md_LKey :
                    (dbg_sel == 19) ?  wv_md_PD :
                    (dbg_sel == 20) ?  wv_md_fifo_dout[31:0] :
                    (dbg_sel == 21) ?  wv_md_fifo_dout[63:32] :
                    (dbg_sel == 22) ?  wv_vtp_vaddr[31:0] :
                    (dbg_sel == 23) ?  wv_vtp_vaddr[63:32] :
                    (dbg_sel == 24) ?  qv_md_fifo_din[31:0] :
                    (dbg_sel == 25) ?  qv_md_fifo_din[63:32] :
                    (dbg_sel == 26) ?  qv_cxtmgt_cmd_data[31:0] :
                    (dbg_sel == 27) ?  qv_cxtmgt_cmd_data[63:32] :
                    (dbg_sel == 28) ?  qv_cxtmgt_cmd_data[95:64] :
                    (dbg_sel == 29) ?  qv_cxtmgt_cmd_data[127:96] :
                    (dbg_sel == 30) ?  qv_vtp_cmd_data[31:0] :
                    (dbg_sel == 31) ?  qv_vtp_cmd_data[63:32] :
                    (dbg_sel == 32) ?  qv_vtp_cmd_data[95:64] :
                    (dbg_sel == 33) ?  qv_vtp_cmd_data[127:96] :
                    (dbg_sel == 34) ?  qv_vtp_cmd_data[159:128] :
                    (dbg_sel == 35) ?  qv_vtp_cmd_data[191:160] :
                    (dbg_sel == 36) ?  qv_vtp_cmd_data[223:192] :
                    (dbg_sel == 37) ?  qv_vtp_cmd_data[255:224] :
                    (dbg_sel == 38) ?  qv_sch_md_data[31:0] :
                    (dbg_sel == 39) ?  qv_sch_md_data[63:32] :
                    (dbg_sel == 40) ?  qv_sch_md_data[95:64] :
                    (dbg_sel == 41) ?  qv_sch_md_data[127:96] :
                    (dbg_sel == 42) ?  qv_sch_md_data[159:128] :
                    (dbg_sel == 43) ?  qv_sch_md_data[191:160] :
                    (dbg_sel == 44) ?  qv_sch_md_data[223:192] :
                    (dbg_sel == 45) ?  qv_sch_md_data[255:224] : 32'd0;

//assign dbg_bus =    {
//                       q_pio_rd_en,
//                       q_cxtmgt_cmd_wr_en,
//                       q_cxtmgt_resp_rd_en,
//                       q_cxtmgt_cxt_rd_en,
//                       q_vtp_cmd_wr_en,
//                       q_vtp_resp_rd_en,
//                       q_sch_md_wr_en,
//                       q_md_fifo_wr_en,
//                       q_md_fifo_rd_en,
//                       q_absolute_addr,
//                       q_relative_addr,
//                       q_mthca_mpt_flag_mio,
//                       q_mthca_mpt_flag_bind_enable,
//                       q_mthca_mpt_flag_physical,
//                       q_mthca_mpt_flag_region,
//                       q_ibv_access_on_demand,
//                       q_ibv_access_zero_based,
//                       q_ibv_access_mw_bind,
//                       q_ibv_access_remote_atomic,
//                       q_ibv_access_remote_read,
//                       q_ibv_access_remote_write,
//                       q_ibv_access_local_write,
//                       w_md_Fence,
//                       w_sq_wrap_around,
//                       q_state,
//                       w_md_fifo_empty,
//                       w_md_fifo_prog_full,
//                       wv_md_ST,
//                      qv_mthca_mpt_flag_sw_owns, 
//                      wv_vtp_type, 
//                      wv_vtp_opcode,     
//                      wv_md_OpCode, 
//                      wv_sq_entry_size_log, 
//                      wv_PMTU_indicator, 
//                      wv_md_PMTU, 
//                      wv_md_PKey, 
//                      wv_md_Size, 
//                      wv_md_SrcQPN, 
//                      wv_md_DstQPN, 
//                      wv_md_Offset, 
//                      wv_vtp_pd, 
//                      wv_vtp_lkey, 
//                      wv_sq_length, 
//                      wv_vtp_length, 
//                      wv_vtp_flags, 
//                      wv_md_LKey, 
//                      wv_md_PD, 
//                      wv_md_fifo_dout[31:0], 
//                      wv_md_fifo_dout[63:32], 
//                      wv_vtp_vaddr[31:0], 
//                      wv_vtp_vaddr[63:32], 
//                      qv_md_fifo_din[31:0], 
//                      qv_md_fifo_din[63:32], 
//                      qv_cxtmgt_cmd_data[31:0], 
//                      qv_cxtmgt_cmd_data[63:32], 
//                      qv_cxtmgt_cmd_data[95:64], 
//                      qv_cxtmgt_cmd_data[127:96], 
//                      qv_vtp_cmd_data[31:0], 
//                      qv_vtp_cmd_data[63:32], 
//                      qv_vtp_cmd_data[95:64], 
//                      qv_vtp_cmd_data[127:96], 
//                      qv_vtp_cmd_data[159:128], 
//                      qv_vtp_cmd_data[191:160], 
//                      qv_vtp_cmd_data[223:192], 
//                      qv_vtp_cmd_data[255:224], 
//                      qv_sch_md_data[31:0], 
//                      qv_sch_md_data[63:32], 
//                      qv_sch_md_data[95:64], 
//                      qv_sch_md_data[127:96], 
//                      qv_sch_md_data[159:128], 
//                      qv_sch_md_data[191:160], 
//                      qv_sch_md_data[223:192], 
//                      qv_sch_md_data[255:224]
//};

assign init_rw_data = 'd0;
                    
endmodule
