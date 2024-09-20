`timescale 1ns / 1ps

`include "ib_constant_def_h.vh"
`include "sw_hw_interface_const_def_h.vh"
`include "msg_def_v2p_h.vh"
`include "msg_def_ctxmgt_h.vh"
`include "nic_hw_params.vh"
`include "chip_include_rdma.vh"


module ExecutionEngine
#(
	parameter RW_REG_NUM = 3
)
( //"ee" for short
    input   wire                clk,
    input   wire                rst,

	input 	wire 	[RW_REG_NUM * 32 - 1 : 0]	rw_data,
	output 	wire 	[RW_REG_NUM * 32 - 1 : 0]	init_rw_data,

//Interface with RecvWQEManager
    output  wire                o_rwm_cmd_wr_en,
    output  wire    [255:0]     ov_rwm_cmd_data,
    input   wire                i_rwm_cmd_prog_full,

    input   wire                i_rwm_resp_empty,
    input   wire    [191:0]     iv_rwm_resp_data,
    output  wire                o_rwm_resp_rd_en,

//Write Address Table
    output  wire                o_wat_wr_en,
    output  wire    [127:0]     ov_wat_wr_data,
    output  wire    [13:0]      ov_wat_addra,
    output  wire    [13:0]      ov_wat_addrb,
    input   wire    [127:0]     iv_wat_rd_data,

//HeaderParser
    input   wire                i_header_empty,
    input   wire    [319:0]     iv_header_data,
    output  wire                o_header_rd_en,

    input   wire                i_nd_empty,
    input   wire    [255:0]     iv_nd_data,
    output  wire                o_nd_rd_en,

//RespPktGen
    output  wire                o_rpg_md_wr_en,
    output  wire    [191:0]     ov_rpg_md_data,
    input   wire                i_rpg_md_prog_full,

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
    input   wire    [319:0]     iv_cxtmgt_cxt_data,

    output  wire                o_cxtmgt_cxt_wr_en,
    input   wire                i_cxtmgt_cxt_prog_full,
    output  wire    [127:0]     ov_cxtmgt_cxt_data,

//Completion Queue Management
    output   wire                o_ee_req_valid,
    output   wire    [23:0]      ov_ee_cq_index,
    output   wire    [31:0]       ov_ee_cq_size,
    input  wire                i_ee_resp_valid,
    input  wire     [23:0]     iv_ee_cq_offset,

    input   wire    [31:0]      dbg_sel,
    output  wire    [32 - 1:0]      dbg_bus,
    //output  wire    [`DBG_NUM_EXECUTION_ENGINE * 32 - 1:0]      dbg_bus,

	output 	wire 				o_ee_init_finish
);

//ila_ee ila_ee(
//    .clk(clk),
//    .probe0(EE_cur_state),
//    .probe1(EE_next_state),
//    .probe2(o_cxtmgt_cmd_wr_en),
//    .probe3(i_cxtmgt_cmd_prog_full),
//    .probe4(ov_cxtmgt_cmd_data),
//    .probe5(i_cxtmgt_resp_empty),
//    .probe6(o_cxtmgt_resp_rd_en),
//    .probe7(iv_cxtmgt_resp_data),
//    .probe8(i_cxtmgt_cxt_empty),
//    .probe9(o_cxtmgt_cxt_rd_en),
//    .probe10(iv_cxtmgt_cxt_data),
//    .probe11(o_cxtmgt_cxt_wr_en),
//    .probe12(i_cxtmgt_cxt_prog_full),
//    .probe13(ov_cxtmgt_cxt_data),
//    .probe14(o_rwm_cmd_wr_en),
//    .probe15(i_rwm_cmd_prog_full),
//    .probe16(ov_rwm_cmd_data),
//    .probe17(i_rwm_resp_empty),
//    .probe18(o_rwm_resp_rd_en),
//    .probe19(iv_rwm_resp_data)
//);

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

BRAM_SDP_32w_16384d ByteCount_Table(      //Byte Cnt
`ifdef CHIP_VERSION
	.RTSEL(rw_data[0 * 32 + 1 : 0 * 32 + 0]),
	.WTSEL(rw_data[0 * 32 + 3 : 0 * 32 + 2]),
	.PTSEL(rw_data[0 * 32 + 5 : 0 * 32 + 4]),
	.VG(rw_data[0 * 32 + 6 : 0 * 32 + 6]),
	.VS(rw_data[0 * 32 + 7 : 0 * 32 + 7]),
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

reg                     q_rwm_cmd_wr_en;
reg     [255:0]         qv_rwm_cmd_data;

reg                     q_rwm_resp_rd_en;
//Write Address Table
reg                     q_wat_wr_en;
reg     [127:0]         qv_wat_wr_data;
reg     [13:0]          qv_wat_addra;
reg     [13:0]          qv_wat_addrb;

reg                     q_rpg_md_wr_en;
reg     [191:0]         qv_rpg_md_data;

//HeaderParser
reg                     q_header_rd_en;
reg                     q_nd_rd_en;

//VirtToPhys
reg                     q_vtp_cmd_wr_en;
reg     [255:0]         qv_vtp_cmd_data;

reg                     q_vtp_resp_rd_en;

reg                     q_vtp_upload_wr_en;
reg     [255:0]         qv_vtp_upload_data;

//CxtMgt
reg                     q_cxtmgt_cmd_wr_en;
reg     [127:0]         qv_cxtmgt_cmd_data;

reg                     q_cxtmgt_resp_rd_en;

reg                     q_cxtmgt_cxt_rd_en;

reg                     q_cxtmgt_cxt_wr_en;
reg     [127:0]         qv_cxtmgt_cxt_data;

assign o_rwm_cmd_wr_en = q_rwm_cmd_wr_en;
assign ov_rwm_cmd_data = qv_rwm_cmd_data;

assign o_rwm_resp_rd_en = q_rwm_resp_rd_en;

//Write Address Table
assign o_wat_wr_en = q_wat_wr_en;
assign ov_wat_wr_data = qv_wat_wr_data;
assign ov_wat_addra = qv_wat_addra;
assign ov_wat_addrb = qv_wat_addrb;

assign o_rpg_md_wr_en = q_rpg_md_wr_en;
assign ov_rpg_md_data = qv_rpg_md_data;

//HeaderParser
assign o_header_rd_en = q_header_rd_en;
assign o_nd_rd_en = q_nd_rd_en;

//VirtToPhys
assign o_vtp_cmd_wr_en = q_vtp_cmd_wr_en;
assign ov_vtp_cmd_data = qv_vtp_cmd_data;

assign o_vtp_resp_rd_en = q_vtp_resp_rd_en;

assign o_vtp_upload_wr_en = q_vtp_upload_wr_en;
assign ov_vtp_upload_data = qv_vtp_upload_data;

//CxtMgt
assign o_cxtmgt_cmd_wr_en = q_cxtmgt_cmd_wr_en;
assign ov_cxtmgt_cmd_data = qv_cxtmgt_cmd_data;

assign o_cxtmgt_resp_rd_en = q_cxtmgt_resp_rd_en;

assign o_cxtmgt_cxt_rd_en = q_cxtmgt_cxt_rd_en;

assign o_cxtmgt_cxt_wr_en = q_cxtmgt_cxt_wr_en;
assign ov_cxtmgt_cxt_data = qv_cxtmgt_cxt_data;

wire    [3:0]           wv_TVer;
wire    [15:0]          wv_PKey;
wire    [23:0]          wv_QPN;
wire 	[23:0]			wv_rqpn;
wire    [2:0]           wv_qp_state;
wire    [15:0]          wv_PMTU;
wire    [23:0]          wv_EPSN;
wire    [23:0]          wv_RPSN;
wire    [7:0]           wv_last_resp_type;
wire                    w_qkey_error;
wire    [7:0]           wv_opcode;
wire                    w_drop_finish;
wire                    w_scatter_finish;
wire                    w_cpl_finish;
wire                    w_write_finish;
wire    [12:0]          wv_pkt_len;
wire    [23:0]          wv_MSN;
wire    [4:0]           wv_RNR_Timer;
wire    [15:0]          wv_RQ_PKey;

wire                    w_legal_access;

wire    [31:0]          wv_RKey;
wire    [63:0]          wv_VA;
wire    [31:0]          wv_DMALen;

reg     [12:0]          qv_pkt_left_length;
reg     [31:0]          qv_cur_entry_left_length;
reg     [5:0]           qv_unwritten_len;
reg     [255:0]         qv_unwritten_data;

wire    [7:0]           wv_entry_valid;

wire    [15:0]          wv_resp_PKey;
wire    [3:0]           wv_resp_TVer;
wire    [1:0]           wv_resp_PC;
wire                    w_resp_Mig;
wire                    w_resp_Solicit;
wire    [7:0]           wv_resp_OpCode;
wire    [23:0]          wv_resp_QPN;
wire                    w_resp_BECN;
wire                    w_resp_FECN;
wire    [23:0]          wv_resp_PSN;
wire                    w_resp_Acknowledge;
wire    [15:0]          wv_resp_PMTU;
wire    [31:0]          wv_resp_MsgSize;
wire    [23:0]          wv_resp_MSN;

reg     [4:0]           qv_resp_Credit;
reg     [4:0]           qv_resp_NAK_Code;
reg     [7:0]           qv_resp_Syndrome;
reg                     q_last_pkt_of_req;

wire    [31:0]          wv_RQ_LKey;
wire 	[31:0]			wv_CQ_LKey;
wire    [31:0]          wv_QP_PD;
wire    [31:0]          wv_CQ_PD;
wire    [23:0]          wv_cqn;
wire 	[7:0]		wv_RQ_Entry_Size_Log;
wire 	[31:0]		wv_RQ_Length;
wire 	[31:0]		wv_cq_length;

wire                    w_cxt_not_full;
reg     [3:0]           qv_inner_state;

reg 	[2:0]			qv_qp_state;

reg     [13:0]          qv_init_counter;

reg     [23:0]          qv_EPSN;

reg     [0:0]           q_MSN_Table_wea;
reg     [13:0]          qv_MSN_Table_addra;
reg     [23:0]          qv_MSN_Table_dina;
reg     [13:0]          qv_MSN_Table_addrb;
wire    [23:0]          wv_MSN_Table_doutb;
wire    [23:0]          wv_MSN_Table_doutb_fake;

reg     [0:0]           q_MSN_Table_wea_TempReg;
reg     [13:0]          qv_MSN_Table_addra_TempReg;
reg     [23:0]          qv_MSN_Table_dina_TempReg;
reg     [13:0]          qv_MSN_Table_addrb_TempReg;

//reg     [0:0]      		q_cq_offset_table_wea;
//reg     [13:0]     	 	qv_cq_offset_table_addra;
//reg     [15:0]     	 	qv_cq_offset_table_dina;
//reg     [13:0]     	 	qv_cq_offset_table_addrb;
//wire    [15:0]     	 	wv_cq_offset_table_doutb;

reg 	[2:0]			qv_service;

/*----------------------------------------  Part 2: State Machine Transition ------------------------------------------------------------*/
reg     [4:0]         EE_cur_state;
reg     [4:0]         EE_next_state;

parameter       [4:0]       EE_INIT_s               = 5'd0,
                            EE_IDLE_s               = 5'd1,
                            EE_FETCH_CXT_s          = 5'd2,
                            EE_RESP_CXT_s           = 5'd3,
                            EE_GEN_RESP_s           = 5'd4,
                            EE_SILENT_DROP_s               = 5'd5,
                            EE_CXT_WB_s             = 5'd6,
                            EE_FETCH_ENTRY_s        = 5'd7,
                            EE_RESP_ENTRY_s         = 5'd8,
                            EE_ENTRY_RELEASE_s      = 5'd9,
                            EE_ENTRY_UPDATE_s       = 5'd10,
                            EE_WQE_RELEASE_s        = 5'd11,
                            EE_SCATTER_CMD_s        = 5'd12,
                            EE_EXE_WRITE_s          = 5'd13,
                            EE_VTP_RESP_s           = 5'd14,
                            EE_VA_RESP_s            = 5'd15,
                            EE_WRITE_DATA_s         = 5'd16,
                            EE_STORE_ADDR_s         = 5'd17,
                            EE_EXE_READ_s           = 5'd18,
                            EE_GEN_CPL_s            = 5'd19,
                            EE_SCATTER_DATA_s       = 5'd20,
							EE_PAYLOAD_DROP_s 		= 5'd21;

//-- qv_init_counter --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_init_counter <= 'd0;        
    end
    else if (EE_cur_state == EE_INIT_s && qv_init_counter < `QP_NUM - 1) begin
        qv_init_counter <= qv_init_counter + 1;
    end
    else begin
        qv_init_counter <= qv_init_counter;
    end
end

//-- Init RAMs --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        EE_cur_state <= EE_INIT_s;        
    end
    else begin
        EE_cur_state <= EE_next_state;
    end
end

//State transition
always @(*) begin
    case(EE_cur_state)
        EE_INIT_s:          if(qv_init_counter == `QP_NUM - 1) begin
                                EE_next_state = EE_IDLE_s;
                            end
                            else begin
                                EE_next_state = EE_INIT_s;
                            end
        EE_IDLE_s:          if(!i_header_empty) begin
                                EE_next_state = EE_FETCH_CXT_s;
                            end
                            else begin
                                EE_next_state = EE_IDLE_s;
                            end
        EE_FETCH_CXT_s:     if(!i_cxtmgt_cmd_prog_full) begin
                                EE_next_state = EE_RESP_CXT_s;
                            end
                            else begin
                                EE_next_state = EE_FETCH_CXT_s;
                            end
        EE_RESP_CXT_s:      if(!i_cxtmgt_resp_empty && !i_cxtmgt_cxt_empty) begin
                                if(wv_qp_state == `QP_RTR || wv_qp_state == `QP_RTS) begin
                                    if(w_qkey_error || wv_RPSN > wv_EPSN) begin
                                        EE_next_state = EE_SILENT_DROP_s;
                                    end
                                    else if(wv_RPSN < wv_EPSN) begin
                                        if(wv_opcode[7:5] == `RC) begin
                                            if(wv_opcode[4:0] != `RDMA_READ_REQUEST) begin
                                                EE_next_state = EE_SILENT_DROP_s;  //Drop duplicate packet               
                                            end
                                            else begin
                                                EE_next_state = EE_EXE_READ_s;
                                            end                                       
                                        end
                                        else begin  //UC/UD will never receive duplicate requests
                                            EE_next_state = EE_SILENT_DROP_s;                                           
                                        end
                                    end
                                    else begin //wv_RPSN == wv_EPSN
                                        if(wv_opcode[4:0] == `SEND_FIRST || wv_opcode[4:0] == `SEND_MIDDLE || wv_opcode[4:0] == `SEND_LAST
                                            || wv_opcode[4:0] == `SEND_ONLY || wv_opcode[4:0] == `SEND_ONLY_WITH_IMM || wv_opcode[4:0] == `SEND_LAST_WITH_IMM) begin
                                            EE_next_state = EE_FETCH_ENTRY_s;        
                                        end
                                        else if(wv_opcode[4:0] == `RDMA_WRITE_FIRST || wv_opcode[4:0] == `RDMA_WRITE_MIDDLE || wv_opcode[4:0] == `RDMA_WRITE_LAST
                                            || wv_opcode[4:0] == `RDMA_WRITE_ONLY || wv_opcode[4:0] == `RDMA_WRITE_LAST_WITH_IMM 
                                            || wv_opcode[4:0] == `RDMA_WRITE_ONLY_WITH_IMM) begin
                                            EE_next_state = EE_EXE_WRITE_s;
                                        end
                                        else if(wv_opcode[4:0] == `RDMA_READ_REQUEST) begin
                                            EE_next_state = EE_EXE_READ_s;
                                        end
                                        else begin      //TODO : Deal with Atomics Op
                                            EE_next_state = EE_SILENT_DROP_s;
                                        end
                                    end
                                end
                                else begin
                                    if(wv_opcode[7:5] == `RC) begin
                                        if(wv_last_resp_type ==`RESP_NAK) begin
                                            EE_next_state = EE_SILENT_DROP_s;
                                        end
                                        else begin
											if(wv_pkt_len == 'd0) begin
	                                            EE_next_state = EE_GEN_RESP_s;
											end 
											else begin
												EE_next_state = EE_PAYLOAD_DROP_s;
											end 
                                        end                                   
                                    end
                                    else begin
                                        EE_next_state = EE_SILENT_DROP_s;
                                    end
                                end
                            end
                            else begin
                                EE_next_state = EE_RESP_CXT_s;
                            end
        EE_SILENT_DROP_s:          if(w_drop_finish) begin
                                if(wv_opcode[7:5] == `RC) begin     //Need to generate response
                                    //EE_next_state = EE_GEN_RESP_s;
                                    EE_next_state = EE_CXT_WB_s;	//Silent drop, no need to send back resp
                                end
                                else begin  //For other service type, we directly write back context
                                    EE_next_state = EE_CXT_WB_s;
                                end
                            end
                            else begin
                                EE_next_state = EE_SILENT_DROP_s;
                            end
        EE_GEN_RESP_s:      if(!i_rpg_md_prog_full) begin
                                EE_next_state = EE_CXT_WB_s;
                            end
                            else begin
                                EE_next_state = EE_GEN_RESP_s;
                            end
        EE_FETCH_ENTRY_s:   if(!i_rwm_cmd_prog_full) begin
                                EE_next_state = EE_RESP_ENTRY_s;
                            end
                            else begin
                                EE_next_state = EE_FETCH_ENTRY_s;
                            end
        EE_RESP_ENTRY_s:    if(!i_rwm_resp_empty) begin
                                if(wv_opcode[4:0] == `RDMA_WRITE_LAST_WITH_IMM || wv_opcode[4:0] == `RDMA_WRITE_ONLY_WITH_IMM) begin
                                    if(wv_entry_valid == `VALID_ENTRY) begin
                                        EE_next_state = EE_WQE_RELEASE_s;
                                    end
                                    else begin
                                        EE_next_state = EE_GEN_RESP_s;
                                    end
                                end
                                else begin
                                    if(wv_entry_valid == `VALID_ENTRY) begin
                                        EE_next_state = EE_SCATTER_CMD_s;
                                    end
                                    else begin
           //                             EE_next_state = EE_GEN_RESP_s;   
           								EE_next_state = EE_PAYLOAD_DROP_s;
                                    end
                                end
                            end
                            else begin
                                EE_next_state = EE_RESP_ENTRY_s;
                            end
        EE_SCATTER_CMD_s:   if(!i_vtp_cmd_prog_full) begin
                                EE_next_state = EE_VTP_RESP_s;
                            end
                            else begin
                                EE_next_state = EE_SCATTER_CMD_s;
                            end
        EE_SCATTER_DATA_s:  if(qv_pkt_left_length + qv_unwritten_len <= qv_cur_entry_left_length) begin     //Current entry is enough to scatter packet data(notice part of this packet may be scattered by previous entry)
                                if((qv_pkt_left_length == 0 && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) ||  //Corner case, only qv_unwritten_data needs to be processed
                                   (qv_pkt_left_length != 0 && (qv_unwritten_len + qv_pkt_left_length <= 32) && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_nd_empty))begin  //Meet the end of a Packet
                                    if(wv_opcode[4:0] == `SEND_FIRST || wv_opcode[4:0] == `SEND_MIDDLE) begin
										if(qv_cur_entry_left_length == (qv_pkt_left_length + qv_unwritten_len)) begin
	                                        EE_next_state = EE_ENTRY_RELEASE_s; 
										end 
										else begin
											EE_next_state = EE_ENTRY_UPDATE_s;
										end 			
                                    end
                                    else begin //Last packet has been scattered, release current WQE
                                        EE_next_state = EE_WQE_RELEASE_s;   //Last pkt has been finished, release WQE
                                    end
                                end
                                else begin
                                    EE_next_state = EE_SCATTER_DATA_s;
                                end
                            end
                            else if(qv_pkt_left_length + qv_unwritten_len > qv_cur_entry_left_length) begin //Current entry is not enough, should be carefully dealt with
                                if(qv_unwritten_len == 0) begin  //Now we are 32B aligned, do not need qv_unwritten_data
                                    if(qv_cur_entry_left_length <= 32 && !i_nd_empty && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin //Meet last 32B of current scatter entry
                                        EE_next_state = EE_ENTRY_RELEASE_s;
                                    end
                                    else begin
                                        EE_next_state = EE_SCATTER_DATA_s;
                                    end
                                end
                                else begin //Not 32B Aligned, need to discuss different case
                                    if(qv_cur_entry_left_length <= 32) begin //Meet last 32B of current scatter entry
                                        if(qv_cur_entry_left_length <= qv_unwritten_len && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin //Just scatter qv_unwritten_data, does not need to piece iv_nd_data together
                                            EE_next_state = EE_ENTRY_RELEASE_s;
                                        end
                                        else if(qv_cur_entry_left_length > qv_unwritten_len && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_nd_empty) begin //Exceed qv_unwritten_len, need to piece iv_nd_data together
                                            EE_next_state = EE_ENTRY_RELEASE_s;
                                        end
                                        else begin
                                            EE_next_state = EE_SCATTER_DATA_s;
                                        end
                                    end
                                    else begin
                                        EE_next_state = EE_SCATTER_DATA_s;
                                    end
                                end
                            end
                            else begin
                                EE_next_state = EE_SCATTER_DATA_s;
                            end
        EE_ENTRY_RELEASE_s: if(!i_rwm_cmd_prog_full) begin
                                if(qv_unwritten_len + qv_pkt_left_length == 0) begin  //Current packet has been finished, Msg has not been released, generate response for RC
                                    if(wv_opcode[7:5] == `RC) begin
                                        EE_next_state = EE_GEN_RESP_s;                                        
                                    end
                                    else begin		//For UC/UD, direclty write back cxt
                                        EE_next_state = EE_CXT_WB_s;
                                    end
                                end
                                else begin //Current packet has not been finished, wait for next valid entry
                                    EE_next_state = EE_FETCH_ENTRY_s;
                                end
                            end
                            else begin
                                EE_next_state = EE_ENTRY_RELEASE_s;
                            end
        EE_ENTRY_UPDATE_s:  if(!i_rwm_cmd_prog_full) begin
                                if(wv_opcode[7:5] == `RC) begin
                                    EE_next_state = EE_GEN_RESP_s;                                    
                                end
                                else begin
                                    EE_next_state = EE_CXT_WB_s; 	//For UD?UD, directly write back cxt
                                end
                            end
                            else begin
                                EE_next_state = EE_ENTRY_UPDATE_s;
                            end
        EE_WQE_RELEASE_s:   if(!i_rwm_cmd_prog_full) begin      
                                EE_next_state = EE_GEN_CPL_s;
                            end
                            else begin
                                EE_next_state = EE_WQE_RELEASE_s;
                            end
        EE_GEN_CPL_s:       if(w_cpl_finish) begin
                                if(wv_opcode[7:5] != `RC) begin
                                    EE_next_state = EE_CXT_WB_s;
                                end 
                                else begin
                                    EE_next_state = EE_GEN_RESP_s;
                                end
                            end
                            else begin
                                EE_next_state = EE_GEN_CPL_s;
                            end
        EE_EXE_WRITE_s:     
//                            if(wv_opcode[4:0] == `RDMA_WRITE_MIDDLE || wv_opcode[4:0] == `RDMA_WRITE_LAST ||
//                                wv_opcode[4:0] == `RDMA_WRITE_LAST_WITH_IMM) begin
//                                EE_next_state = EE_VA_RESP_s;
//                            end
//                            else begin //RDMA_WRITE_FIRST, RKey and VA is in RETH, does not need to access address table
                                if(!i_vtp_cmd_prog_full) begin
                                    EE_next_state = EE_VTP_RESP_s;                                    
                                end
                                else begin
                                    EE_next_state = EE_EXE_WRITE_s;
                                end
//                            end
        EE_VA_RESP_s:       if(!i_vtp_upload_prog_full) begin
                                EE_next_state = EE_VTP_RESP_s;
                            end
                            else begin
                                EE_next_state = EE_VA_RESP_s;
                            end
        EE_VTP_RESP_s:      if(!i_vtp_resp_empty) begin
                                if(wv_opcode[4:0] == `RDMA_READ_REQUEST) begin		//RDMA Read
                                    EE_next_state = EE_GEN_RESP_s;  //No matter legal or illegal access, generate Response
                                end
								else if(wv_opcode[4:0] == `SEND_FIRST || wv_opcode[4:0] == `SEND_MIDDLE || wv_opcode[4:0] == `SEND_LAST ||
										wv_opcode[4:0] == `SEND_ONLY || wv_opcode[4:0] == `SEND_ONLY_WITH_IMM || wv_opcode[4:0] == `SEND_LAST_WITH_IMM) begin
									if(w_legal_access) begin
										EE_next_state = EE_SCATTER_DATA_s;
									end 
                                    else begin
                                        if(wv_opcode[7:5] == `RC) begin     //For RC, generate remote access error NAK     
											if(wv_pkt_len == 'd0) begin
	                                            EE_next_state = EE_GEN_RESP_s;                                            
											end 
											else begin
												EE_next_state = EE_PAYLOAD_DROP_s;
											end 
                                        end
                                        else begin  //For UC, siliently drop this packet
                                            EE_next_state = EE_SILENT_DROP_s;
                                        end
                                    end
								end 
                                else begin
                                    if(w_legal_access) begin
                                        EE_next_state = EE_WRITE_DATA_s;
                                    end
                                    else begin
                                        if(wv_opcode[7:5] == `RC) begin     //For RC, generate remote access error NAK     
											if(wv_pkt_len == 'd0) begin
	                                            EE_next_state = EE_GEN_RESP_s;                                            
											end 
											else begin
												EE_next_state = EE_PAYLOAD_DROP_s;
											end 
                                        end
                                        else begin  //For UC, siliently drop this packet
                                            EE_next_state = EE_SILENT_DROP_s;
                                        end
                                    end
                                end
                            end
                            else begin
                                EE_next_state = EE_VTP_RESP_s;
                            end
		EE_PAYLOAD_DROP_s:	if(w_drop_finish) begin
								EE_next_state = EE_GEN_RESP_s;
							end
							else begin
								EE_next_state = EE_PAYLOAD_DROP_s;
							end 
        EE_WRITE_DATA_s:    if(w_write_finish) begin
                                if(wv_opcode[4:0] == `RDMA_WRITE_FIRST || wv_opcode[4:0] == `RDMA_WRITE_MIDDLE || 
                                        wv_opcode[4:0] == `RDMA_WRITE_ONLY || wv_opcode[4:0] == `RDMA_WRITE_LAST) begin
                                    if(wv_opcode[7:5] == `RC) begin
                                        EE_next_state = EE_GEN_RESP_s;
                                    end
                                    else begin
                                        EE_next_state = EE_CXT_WB_s;	
                                    end
                                end
                                else if(wv_opcode[4:0] == `RDMA_WRITE_ONLY_WITH_IMM || wv_opcode[4:0] == `RDMA_WRITE_LAST_WITH_IMM) begin
                                    if(!i_rwm_cmd_prog_full) begin
                                        EE_next_state = EE_FETCH_ENTRY_s;
                                    end
                                    else begin
                                        EE_next_state = EE_WRITE_DATA_s;
                                    end
                                end
                                else begin
                                    EE_next_state = EE_WRITE_DATA_s;
                                end
                            end
                            else begin
                                EE_next_state = EE_WRITE_DATA_s;
                            end
        EE_EXE_READ_s:      if(!i_vtp_cmd_prog_full) begin
                                EE_next_state = EE_VTP_RESP_s;
                            end
                            else begin
                                EE_next_state = EE_EXE_READ_s;
                            end
        EE_CXT_WB_s:        if(w_cxt_not_full) begin
                                EE_next_state = EE_IDLE_s;
                            end
                            else begin
                                EE_next_state = EE_CXT_WB_s;
                            end
        default:            EE_next_state = EE_IDLE_s;
    endcase
end

/*----------------------------------------  Part 3: Output Registers Decode -------------------------------------------------------------*/
assign o_ee_init_finish = (qv_init_counter == `QP_NUM - 1);

//-- qv_service --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_service <= 'd0;
	end 
	else if(EE_cur_state == EE_FETCH_CXT_s) begin
		qv_service <= wv_opcode[7:5];
	end 
	else begin
		qv_service <= qv_service;
	end 
end 

//-- qv_EPSN --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_EPSN <= 'd0;        
    end
    else if (EE_cur_state == EE_RESP_CXT_s && !i_cxtmgt_resp_empty) begin	
        if(wv_EPSN > wv_RPSN) begin //Duplicate packet
            qv_EPSN <= wv_EPSN;
        end
        else if(wv_EPSN < wv_RPSN) begin //Detect packet loss
            qv_EPSN <= wv_EPSN;
        end
        else begin //Expect packet
            if(wv_opcode[4:0] == `RDMA_READ_REQUEST) begin   //Should increase EPSN based on message length
                case(wv_PMTU) 
                    1:   qv_EPSN <= wv_EPSN + ((wv_DMALen[7:0] != 8'd0) ? (wv_DMALen[31:8] + 1) : wv_DMALen[31:8]);
                    2:   qv_EPSN <= wv_EPSN + ((wv_DMALen[8:0] != 9'd0) ? (wv_DMALen[31:9] + 1) : wv_DMALen[31:9]);
                    3:  qv_EPSN <= wv_EPSN + ((wv_DMALen[9:0] != 10'd0) ? (wv_DMALen[31:10] + 1) : wv_DMALen[31:10]);
                    4:  qv_EPSN <= wv_EPSN + ((wv_DMALen[10:0] != 11'd0) ? (wv_DMALen[31:11] + 1) : wv_DMALen[31:11]);
                    5:  qv_EPSN <= wv_EPSN + ((wv_DMALen[11:0] != 12'd0) ? (wv_DMALen[31:12] + 1) : wv_DMALen[31:12]);
                    default:    qv_EPSN <= qv_EPSN;
                endcase
            end
            else begin
                qv_EPSN <= wv_EPSN + 1;
            end
        end
    end
	else if(qv_qp_state == `QP_ERR) begin
		qv_EPSN <= wv_EPSN;
	end 
    else begin
       qv_EPSN <= qv_EPSN; 
    end
end

assign w_cxt_not_full = !i_cxtmgt_cmd_prog_full && !i_cxtmgt_cxt_prog_full;


/********************************************** Resp Table ***********************************************/
reg 				q_rt_table_wr_en;
reg 	[13:0]		qv_rt_table_wr_addr;
reg 				qv_rt_table_wr_data;
reg 	[13:0]		qv_rt_table_rd_addr;
wire 				wv_rt_table_rd_data;

//Table Content : 0 means last time this QP generates a ACK or Read Response, otherwise it generates NAK
//This record is used to avoid NAK flooding
BRAM_SDP_1w_16384d RespType_Table (
`ifdef CHIP_VERSION
	.RTSEL(rw_data[1 * 32 + 1 : 1 * 32 + 0]),
	.WTSEL(rw_data[1 * 32 + 3 : 1 * 32 + 2]),
	.PTSEL(rw_data[1 * 32 + 5 : 1 * 32 + 4]),
	.VG(rw_data[1 * 32 + 6 : 1 * 32 + 6]),
	.VS(rw_data[1 * 32 + 7 : 1 * 32 + 7]),
`endif

  .clka(clk),    // input wire clka
  .ena(1'b1),      // input wire ena
  .wea(q_rt_table_wr_en),      // input wire [0 : 0] wea
  .addra(qv_rt_table_wr_addr[12:0]),  // input wire [13 : 0] addra
  .dina(qv_rt_table_wr_data),    // input wire [0 : 0] dina
  .clkb(clk),    // input wire clkb
  .enb(1'b1),      // input wire enb
  .addrb(qv_rt_table_rd_addr[12:0]),  // input wire [13 : 0] addrb
  .doutb(wv_rt_table_rd_data)  // output wire [0 : 0] doutb
);

always @(posedge clk or posedge rst) begin
	if(rst) begin
		q_rt_table_wr_en <= 'd0;
		qv_rt_table_wr_addr <= 'd0;
		qv_rt_table_wr_data <= 'd0;
		qv_rt_table_rd_addr <= 'd0;
	end 
	else if(EE_cur_state == EE_INIT_s && qv_init_counter <= `QP_NUM - 1) begin
		q_rt_table_wr_en <= 'd1;
		qv_rt_table_wr_addr <= qv_init_counter;
		qv_rt_table_wr_data <= 'd0; 		//In INIT state, all QPs are in normal state
		qv_rt_table_rd_addr <= 'd0;
	end 
	else if(EE_cur_state == EE_FETCH_CXT_s) begin
		q_rt_table_wr_en <= 'd0;
		qv_rt_table_wr_addr <= wv_QPN;
		qv_rt_table_wr_data <= 'd0; 		
		qv_rt_table_rd_addr <= wv_QPN;
	end 
	else if(EE_cur_state == EE_GEN_RESP_s && !i_rpg_md_prog_full) begin		//To avoid NAK flooding, only when we meet PSN error do we update this table
		q_rt_table_wr_en <= 'd1;
		qv_rt_table_wr_addr <= wv_QPN;
		qv_rt_table_wr_data <= ((wv_resp_OpCode == `ACK) && (qv_resp_Syndrome[6:5] == `SYNDROME_NAK) && (qv_resp_Syndrome[4:0] == `PSN_SEQUENCE_ERROR)) ? 1 : 0;
		qv_rt_table_rd_addr <= wv_QPN;
	end 
	else begin
		q_rt_table_wr_en <= 'd0;
		qv_rt_table_wr_addr <= wv_QPN;
		qv_rt_table_wr_data <= 'd0; 		//In INIT state, all QPs are in normal state
		qv_rt_table_rd_addr <= wv_QPN;
	end 
end 

/************************* Packet Header Data ****************************/
//-- wv_TVer --
assign wv_TVer = iv_header_data[19:16];
//-- wv_PKey --
//Trick, we use wv_PKey to indicate srcQPN
//assign wv_PKey = iv_header_data[15:0];
assign wv_PKey = wv_QPN[15:0]; 
//-- wv_QPN --
assign wv_QPN = iv_header_data[55:32];
//-- wv_RKey --
assign wv_RKey = {iv_header_data[96 + 95 : 96 + 64]};
//-- wv_VA --
//-- VA_low is at higer bits, VA_high is at lower bits
assign wv_VA = {iv_header_data[96 + 31 : 96 + 0], iv_header_data[96 + 63 : 96 + 32]};
//-- wv_DMALen --
assign wv_DMALen = iv_header_data[96 + 127 : 96 + 96];
//-- wv_pkt_len --
assign wv_pkt_len = {iv_header_data[94:88], iv_header_data[61:56]};
//-- wv_opcode --
assign wv_opcode = iv_header_data[31:24];
//-- wv_RPSN -- Current Packet PSN
assign wv_RPSN = iv_header_data[95:64];

/************************* Cxt Data ************************************/
//-- wv_qp_state -- Current QP State
assign wv_qp_state = iv_cxtmgt_cxt_data[2:0];
//-- wv_RNR_Timer --
assign wv_RNR_Timer = iv_cxtmgt_cxt_data[7:3];
//-- wv_EPSN -- Current Expected PSN
assign wv_EPSN = iv_cxtmgt_cxt_data[31:8];
//-- wv_RQ_PKey --  //Not used
assign wv_RQ_PKey = iv_cxtmgt_cxt_data[47:32];
//-- wv_PMTU -- Link MTU
assign wv_PMTU = {13'b0, iv_cxtmgt_cxt_data[55:53]}; 	
//-- wv_rqpn --
assign wv_rqpn = (wv_opcode[7:5] != `UD) ? (iv_cxtmgt_cxt_data[87:64]) : 
					wv_opcode[4:0] == `SEND_ONLY ? {8'h0, iv_header_data[143:128]} :
					wv_opcode[4:0] == `SEND_ONLY_WITH_IMM ? {8'h0, iv_header_data[175:160]} : iv_cxtmgt_cxt_data[87:64];
//-- wv_RQ_Entry_Size_Log --
assign wv_RQ_Entry_Size_Log = iv_cxtmgt_cxt_data[95:88];
//-- wv_RQ_LKey --
assign wv_RQ_LKey = iv_cxtmgt_cxt_data[127:96];
//-- wv_CQ_LKey --
assign wv_CQ_LKey = iv_cxtmgt_cxt_data[159:128];
//-- wv_QP_PD --
assign wv_QP_PD = iv_cxtmgt_cxt_data[191:160];
//-- wv_CQ_PD --
assign wv_CQ_PD = iv_cxtmgt_cxt_data[223:192]; 
//-- wv_RQ_Length --
assign wv_RQ_Length = iv_cxtmgt_cxt_data[255:224];
//-- wv_cq_length --
assign wv_cq_length = iv_cxtmgt_cxt_data[287:256];
//-- wv_cqn --
assign wv_cqn = iv_cxtmgt_cxt_data[311:288];

wire 	[15:0]		wv_rlid;
assign wv_rlid = {iv_cxtmgt_cxt_data[319:312], iv_cxtmgt_cxt_data[63:56]};

/************************** Others ************************************/
//-- wv_entry_valid --
assign wv_entry_valid = iv_rwm_resp_data[7:0]; 

wire    [63:0]          wv_Entry_VA;
wire    [31:0]          wv_Entry_Len;
wire    [31:0]          wv_Entry_Key;
wire 	[31:0]			wv_WQE_Offset;

assign wv_WQE_Offset = iv_rwm_resp_data[191:160];
assign wv_Entry_VA = iv_rwm_resp_data[159:96];
assign wv_Entry_Key = iv_rwm_resp_data[95:64];
assign wv_Entry_Len = iv_rwm_resp_data[63:32];


//-- w_legal_access --
assign w_legal_access = (iv_vtp_resp_data[7:0] == `SUCCESS);

//-- wv_last_resp_type -- Last Time Response Type
//TODO : This should be managed locally, not in cxt
assign wv_last_resp_type = 'd0;

//-- wv_MSN --
//TODO : This should be managed locally, not in cxt
assign wv_MSN = wv_MSN_Table_doutb;

//-- w_qkey_error -- QKey verification for UD
//UNCERTAIN : How to validate QKey???
assign w_qkey_error = 1'b0;

//-- w_drop_finish --
assign w_drop_finish = (wv_pkt_len == 0 && !i_header_empty) || (wv_pkt_len != 0 && qv_pkt_left_length <= 32 && !i_header_empty && !i_nd_empty);

//-- w_scatter_finish -- When unwritten pkt payload less equal than the current entry length, we think current pkt has been finished
assign w_scatter_finish = (qv_pkt_left_length + qv_unwritten_len <= qv_cur_entry_left_length) && !i_nd_empty && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full;

//-- w_cpl_finish -- One cycle to write completion events
assign w_cpl_finish = !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && i_ee_resp_valid;

//-- w_write_finish -- When current unwritten payload is less equal than 32 Bytes, we think write packet has finished
assign w_write_finish = (qv_pkt_left_length <= 32) && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_nd_empty;

//-- qv_qp_state --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_qp_state <= 'd0;
	end 
	else if(EE_cur_state == EE_RESP_CXT_s && !i_cxtmgt_resp_empty && !i_cxtmgt_cxt_empty) begin 	//QKey error
		if(w_qkey_error) begin
			qv_qp_state <= `QP_ERR;
		end  
		else begin 
			qv_qp_state <= wv_qp_state; 	
		end 
	end 
	else if(EE_cur_state == EE_RESP_ENTRY_s && !i_rwm_resp_empty && (wv_entry_valid != `VALID_ENTRY)) begin 	//No SGL entry error
		qv_qp_state <= `QP_ERR;
	end 
	else if(EE_cur_state == EE_VTP_RESP_s && !i_vtp_resp_empty && !w_legal_access) begin //Invalid Memory Access error
		qv_qp_state <= `QP_ERR;
	end 
	else begin 
		qv_qp_state <= qv_qp_state;
	end 
end 

//-- qv_pkt_left_length --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_pkt_left_length <= 'd0;        
    end
    else if (EE_cur_state == EE_IDLE_s && !i_header_empty) begin //New inbound packet comes
        qv_pkt_left_length <= wv_pkt_len;
    end
    else if (EE_cur_state == EE_SCATTER_DATA_s) begin
        if(q_nd_rd_en) begin
            if(qv_pkt_left_length > 32) begin
                qv_pkt_left_length <= qv_pkt_left_length - 32;
            end
            else begin
                qv_pkt_left_length <= 0;
            end
        end
        else begin
            qv_pkt_left_length <= qv_pkt_left_length;
        end
    end
    else if (EE_cur_state == EE_WRITE_DATA_s) begin
        if(!i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && q_nd_rd_en) begin   //Write is simpler than Send, does not need to scatter data
            qv_pkt_left_length <= qv_pkt_left_length - 32;
        end
        else begin
            qv_pkt_left_length <= qv_pkt_left_length;
        end
    end
    else if (EE_cur_state == EE_SILENT_DROP_s) begin
        if(wv_pkt_len != 0) begin
            if(!i_nd_empty) begin
                qv_pkt_left_length <= qv_pkt_left_length - 32;
            end
            else begin
                qv_pkt_left_length <= qv_pkt_left_length;
            end
        end
        else begin
            qv_pkt_left_length <= qv_pkt_left_length;
        end
    end
    else if (EE_cur_state == EE_PAYLOAD_DROP_s) begin
        if(wv_pkt_len != 0) begin
            if(!i_nd_empty) begin
                qv_pkt_left_length <= qv_pkt_left_length - 32;
            end
            else begin
                qv_pkt_left_length <= qv_pkt_left_length;
            end
        end
        else begin
            qv_pkt_left_length <= qv_pkt_left_length;
        end
    end
    else begin
        qv_pkt_left_length <= qv_pkt_left_length;
    end
end

//-- qv_cur_entry_left_length -- Indicates space available of current Scatter Entry
//                               The control logic is similar to state transition
//                              The key point is that there are two cases which indicate that we have met the end of a packet:
//                              1. qv_pkt_left_length is 0, which means we have read out all the data from iv_nd_data, and we need to handle qv_unwritten_data only;
//                              2. qv_pkt_left_length is not 0, and (qv_unwritten_len + qv_pkt_left_length) <= 32, we need to piece this two data segment together
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_cur_entry_left_length <= 'd0;      
    end
    else if (EE_cur_state == EE_RESP_ENTRY_s && !i_rwm_resp_empty) begin
        if(wv_entry_valid == `VALID_ENTRY) begin
            qv_cur_entry_left_length <= wv_Entry_Len;
        end
        else begin
            qv_cur_entry_left_length <= qv_cur_entry_left_length;
        end
    end
    else if (EE_cur_state == EE_SCATTER_DATA_s) begin
        if(qv_pkt_left_length + qv_unwritten_len <= qv_cur_entry_left_length) begin
            if(qv_pkt_left_length == 0 && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin   //Deal with qv_unwritten_data, end of a packet
                qv_cur_entry_left_length <= qv_cur_entry_left_length - qv_unwritten_len;
            end
            else if(qv_pkt_left_length + qv_unwritten_len <= 32 && !i_nd_empty && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin //Deal with qv_unwritten_len and iv_nd_data, end of a packet
                qv_cur_entry_left_length <= qv_cur_entry_left_length - (qv_pkt_left_length + qv_unwritten_len);
            end
            else if(qv_pkt_left_length + qv_unwritten_len > 32 && !i_nd_empty && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin //Deal with 32B data, not the end
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
                else if(qv_cur_entry_left_length > qv_unwritten_len && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_nd_empty) begin
                    qv_cur_entry_left_length <= 'd0;
                end
                else begin
                    qv_cur_entry_left_length <= qv_cur_entry_left_length;
                end
            end 
            else begin //More than 32B left, must handle {iv_nd_data[?:?], qv_unwritten_data[?:?]}
                if(!i_nd_empty && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin
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
    else if (EE_cur_state == EE_RESP_CXT_s) begin   //At RESP_CXT, clear this register
        qv_unwritten_len <= 'd0;
    end
    else if (EE_cur_state == EE_SCATTER_DATA_s) begin
        if(qv_pkt_left_length + qv_unwritten_len <= qv_cur_entry_left_length) begin	//Entry is enough
            if(qv_pkt_left_length == 0 && !i_vtp_upload_prog_full) begin   
                qv_unwritten_len <= 'd0; 
            end
            else if(qv_pkt_left_length + qv_unwritten_len > 32 && !i_nd_empty && !i_vtp_upload_prog_full) begin
                if(qv_pkt_left_length <= 32) begin
                    qv_unwritten_len <= qv_pkt_left_length + qv_unwritten_len - 32;
                end
                else begin
                    qv_unwritten_len <= qv_unwritten_len;
                end
            end
            else if(qv_pkt_left_length + qv_unwritten_len <= 32 && !i_nd_empty && !i_vtp_upload_prog_full) begin
                qv_unwritten_len <= 'd0;
            end
            else begin
                qv_unwritten_len <= qv_unwritten_len;
            end
        end
        else begin //Current entry space is not enough
            if(qv_cur_entry_left_length > 32) begin
                if(qv_pkt_left_length > 32 && !i_nd_empty && !i_vtp_upload_prog_full) begin
                    qv_unwritten_len <= qv_unwritten_len;
                end
                else if(qv_pkt_left_length <= 32 && !i_nd_empty && !i_vtp_upload_prog_full) begin
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
                    if(qv_pkt_left_length <= 32 && !i_nd_empty && !i_vtp_upload_prog_full) begin
                        qv_unwritten_len <= {26'd0, qv_unwritten_len} + {19'd0, qv_pkt_left_length} - qv_cur_entry_left_length;
                    end
                    else if(qv_pkt_left_length > 32 && !i_vtp_upload_prog_full && !i_nd_empty) begin
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
    else if (EE_cur_state == EE_RESP_CXT_s) begin   //At RESP_CXT, clear this register
        qv_unwritten_data <= 'd0;
    end
    else if (EE_cur_state == EE_SCATTER_DATA_s) begin
		if(qv_pkt_left_length + qv_unwritten_len <= qv_cur_entry_left_length) begin 	//Entry is enough
			if(qv_unwritten_len == 0) begin 
				qv_unwritten_data <= 'd0;
			end 
			else begin
				if((qv_unwritten_len + qv_pkt_left_length <= 32) && !i_nd_empty && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin 
					qv_unwritten_data <= 'd0;	//All packet data has been uploaded
				end 
				else if((qv_unwritten_len + qv_pkt_left_length > 32) && !i_nd_empty && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin
					case(32 - qv_unwritten_len) 
                        0:          qv_unwritten_data <= 'd0;
                        1:          qv_unwritten_data <= {248'd0, iv_nd_data[255 : 1 * 8]};
                        2:          qv_unwritten_data <= {240'd0, iv_nd_data[255 : 2 * 8]};
                        3:          qv_unwritten_data <= {232'd0, iv_nd_data[255 : 3 * 8]};
                        4:          qv_unwritten_data <= {224'd0, iv_nd_data[255 : 4 * 8]};
                        5:          qv_unwritten_data <= {216'd0, iv_nd_data[255 : 5 * 8]};
                        6:          qv_unwritten_data <= {208'd0, iv_nd_data[255 : 6 * 8]};
                        7:          qv_unwritten_data <= {200'd0, iv_nd_data[255 : 7 * 8]};
                        8:          qv_unwritten_data <= {192'd0, iv_nd_data[255 : 8 * 8]};
                        9:          qv_unwritten_data <= {184'd0, iv_nd_data[255 : 9 * 8]};
                        10:         qv_unwritten_data <= {176'd0, iv_nd_data[255 : 10 * 8]};
                        11:         qv_unwritten_data <= {168'd0, iv_nd_data[255 : 11 * 8]};
                        12:         qv_unwritten_data <= {160'd0, iv_nd_data[255 : 12 * 8]};
                        13:         qv_unwritten_data <= {152'd0, iv_nd_data[255 : 13 * 8]};
                        14:         qv_unwritten_data <= {144'd0, iv_nd_data[255 : 14 * 8]};
                        15:         qv_unwritten_data <= {136'd0, iv_nd_data[255 : 15 * 8]};
                        16:         qv_unwritten_data <= {128'd0, iv_nd_data[255 : 16 * 8]};
                        17:         qv_unwritten_data <= {120'd0, iv_nd_data[255 : 17 * 8]};
                        18:         qv_unwritten_data <= {112'd0, iv_nd_data[255 : 18 * 8]};
                        19:         qv_unwritten_data <= {104'd0, iv_nd_data[255 : 19 * 8]};
                        20:         qv_unwritten_data <= {96'd0, iv_nd_data[255 : 20 * 8]};
                        21:         qv_unwritten_data <= {88'd0, iv_nd_data[255 : 21 * 8]};
                        22:         qv_unwritten_data <= {80'd0, iv_nd_data[255 : 22 * 8]};
                        23:         qv_unwritten_data <= {72'd0, iv_nd_data[255 : 23 * 8]};
                        24:         qv_unwritten_data <= {64'd0, iv_nd_data[255 : 24 * 8]};
                        25:         qv_unwritten_data <= {56'd0, iv_nd_data[255 : 25 * 8]};
                        26:         qv_unwritten_data <= {48'd0, iv_nd_data[255 : 26 * 8]};
                        27:         qv_unwritten_data <= {40'd0, iv_nd_data[255 : 27 * 8]};
                        28:         qv_unwritten_data <= {32'd0, iv_nd_data[255 : 28 * 8]};
                        29:         qv_unwritten_data <= {24'd0, iv_nd_data[255 : 29 * 8]};
                        30:         qv_unwritten_data <= {16'd0, iv_nd_data[255 : 30 * 8]};
                        31:         qv_unwritten_data <= {8'd0, iv_nd_data[255 : 31 * 8]};
                        default:    qv_unwritten_data <= qv_unwritten_data;
					endcase
				end 
				else begin
					qv_unwritten_data <= qv_unwritten_data;
				end 
			end 
		end 
		else if(qv_pkt_left_length + qv_unwritten_len > qv_cur_entry_left_length) begin 
			if(qv_unwritten_len == 0 && !i_nd_empty && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin
				if(qv_cur_entry_left_length < 32) begin
					case(qv_cur_entry_left_length)
                        0:          qv_unwritten_data <= 'd0;
                        1:          qv_unwritten_data <= {248'd0, iv_nd_data[255 : 1 * 8]};
                        2:          qv_unwritten_data <= {240'd0, iv_nd_data[255 : 2 * 8]};
                        3:          qv_unwritten_data <= {232'd0, iv_nd_data[255 : 3 * 8]};
                        4:          qv_unwritten_data <= {224'd0, iv_nd_data[255 : 4 * 8]};
                        5:          qv_unwritten_data <= {216'd0, iv_nd_data[255 : 5 * 8]};
                        6:          qv_unwritten_data <= {208'd0, iv_nd_data[255 : 6 * 8]};
                        7:          qv_unwritten_data <= {200'd0, iv_nd_data[255 : 7 * 8]};
                        8:          qv_unwritten_data <= {192'd0, iv_nd_data[255 : 8 * 8]};
                        9:          qv_unwritten_data <= {184'd0, iv_nd_data[255 : 9 * 8]};
                        10:         qv_unwritten_data <= {176'd0, iv_nd_data[255 : 10 * 8]};
                        11:         qv_unwritten_data <= {168'd0, iv_nd_data[255 : 11 * 8]};
                        12:         qv_unwritten_data <= {160'd0, iv_nd_data[255 : 12 * 8]};
                        13:         qv_unwritten_data <= {152'd0, iv_nd_data[255 : 13 * 8]};
                        14:         qv_unwritten_data <= {144'd0, iv_nd_data[255 : 14 * 8]};
                        15:         qv_unwritten_data <= {136'd0, iv_nd_data[255 : 15 * 8]};
                        16:         qv_unwritten_data <= {128'd0, iv_nd_data[255 : 16 * 8]};
                        17:         qv_unwritten_data <= {120'd0, iv_nd_data[255 : 17 * 8]};
                        18:         qv_unwritten_data <= {112'd0, iv_nd_data[255 : 18 * 8]};
                        19:         qv_unwritten_data <= {104'd0, iv_nd_data[255 : 19 * 8]};
                        20:         qv_unwritten_data <= {96'd0, iv_nd_data[255 : 20 * 8]};
                        21:         qv_unwritten_data <= {88'd0, iv_nd_data[255 : 21 * 8]};
                        22:         qv_unwritten_data <= {80'd0, iv_nd_data[255 : 22 * 8]};
                        23:         qv_unwritten_data <= {72'd0, iv_nd_data[255 : 23 * 8]};
                        24:         qv_unwritten_data <= {64'd0, iv_nd_data[255 : 24 * 8]};
                        25:         qv_unwritten_data <= {56'd0, iv_nd_data[255 : 25 * 8]};
                        26:         qv_unwritten_data <= {48'd0, iv_nd_data[255 : 26 * 8]};
                        27:         qv_unwritten_data <= {40'd0, iv_nd_data[255 : 27 * 8]};
                        28:         qv_unwritten_data <= {32'd0, iv_nd_data[255 : 28 * 8]};
                        29:         qv_unwritten_data <= {24'd0, iv_nd_data[255 : 29 * 8]};
                        30:         qv_unwritten_data <= {16'd0, iv_nd_data[255 : 30 * 8]};
                        31:         qv_unwritten_data <= {8'd0, iv_nd_data[255 : 31 * 8]};
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
			else if(qv_unwritten_len > 0 && qv_cur_entry_left_length > qv_unwritten_len && !i_nd_empty && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin
				case(qv_cur_entry_left_length > 32 ? (32 - qv_unwritten_len) : (qv_cur_entry_left_length - qv_unwritten_len))
                        0:          qv_unwritten_data <= 'd0;
                        1:          qv_unwritten_data <= {248'd0, iv_nd_data[255 : 1 * 8]};
                        2:          qv_unwritten_data <= {240'd0, iv_nd_data[255 : 2 * 8]};
                        3:          qv_unwritten_data <= {232'd0, iv_nd_data[255 : 3 * 8]};
                        4:          qv_unwritten_data <= {224'd0, iv_nd_data[255 : 4 * 8]};
                        5:          qv_unwritten_data <= {216'd0, iv_nd_data[255 : 5 * 8]};
                        6:          qv_unwritten_data <= {208'd0, iv_nd_data[255 : 6 * 8]};
                        7:          qv_unwritten_data <= {200'd0, iv_nd_data[255 : 7 * 8]};
                        8:          qv_unwritten_data <= {192'd0, iv_nd_data[255 : 8 * 8]};
                        9:          qv_unwritten_data <= {184'd0, iv_nd_data[255 : 9 * 8]};
                        10:         qv_unwritten_data <= {176'd0, iv_nd_data[255 : 10 * 8]};
                        11:         qv_unwritten_data <= {168'd0, iv_nd_data[255 : 11 * 8]};
                        12:         qv_unwritten_data <= {160'd0, iv_nd_data[255 : 12 * 8]};
                        13:         qv_unwritten_data <= {152'd0, iv_nd_data[255 : 13 * 8]};
                        14:         qv_unwritten_data <= {144'd0, iv_nd_data[255 : 14 * 8]};
                        15:         qv_unwritten_data <= {136'd0, iv_nd_data[255 : 15 * 8]};
                        16:         qv_unwritten_data <= {128'd0, iv_nd_data[255 : 16 * 8]};
                        17:         qv_unwritten_data <= {120'd0, iv_nd_data[255 : 17 * 8]};
                        18:         qv_unwritten_data <= {112'd0, iv_nd_data[255 : 18 * 8]};
                        19:         qv_unwritten_data <= {104'd0, iv_nd_data[255 : 19 * 8]};
                        20:         qv_unwritten_data <= {96'd0, iv_nd_data[255 : 20 * 8]};
                        21:         qv_unwritten_data <= {88'd0, iv_nd_data[255 : 21 * 8]};
                        22:         qv_unwritten_data <= {80'd0, iv_nd_data[255 : 22 * 8]};
                        23:         qv_unwritten_data <= {72'd0, iv_nd_data[255 : 23 * 8]};
                        24:         qv_unwritten_data <= {64'd0, iv_nd_data[255 : 24 * 8]};
                        25:         qv_unwritten_data <= {56'd0, iv_nd_data[255 : 25 * 8]};
                        26:         qv_unwritten_data <= {48'd0, iv_nd_data[255 : 26 * 8]};
                        27:         qv_unwritten_data <= {40'd0, iv_nd_data[255 : 27 * 8]};
                        28:         qv_unwritten_data <= {32'd0, iv_nd_data[255 : 28 * 8]};
                        29:         qv_unwritten_data <= {24'd0, iv_nd_data[255 : 29 * 8]};
                        30:         qv_unwritten_data <= {16'd0, iv_nd_data[255 : 30 * 8]};
                        31:         qv_unwritten_data <= {8'd0, iv_nd_data[255 : 31 * 8]};
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

//-- q_wat_wr_en --
//-- qv_wat_addra --
//-- qv_wat_wr_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_wat_wr_en <= 1'b0;        
        qv_wat_addra <= 'd0;
        qv_wat_wr_data <= 'd0;
    end
    else if (EE_cur_state == EE_INIT_s) begin
        q_wat_wr_en <= 1'b1;
        qv_wat_addra <= qv_init_counter;
        qv_wat_wr_data <= 'd0;
    end
    // else if (EE_cur_state == EE_EXE_WRITE_s && (wv_opcode[4:0] == `RDMA_WRITE_FIRST || wv_opcode[4:0] == `RDMA_WRITE_ONLY || wv_opcode[4:0] == `RDMA_WRITE_ONLY_WITH_IMM)) begin
    //     q_wat_wr_en <= 1'b1;
    //     qv_wat_addra <= wv_QPN;
    //     qv_wat_wr_data <= {wv_DMALen, wv_RKey, wv_VA};
    // end
    else if (EE_cur_state == EE_WRITE_DATA_s && qv_pkt_left_length <= 32 && !i_nd_empty && !i_vtp_upload_prog_full && !i_vtp_cmd_prog_full) begin
        if(wv_opcode[4:0] == `RDMA_WRITE_FIRST) begin
            q_wat_wr_en <= 1'b1;
            qv_wat_addra <= wv_QPN;
            qv_wat_wr_data <= {(wv_DMALen - wv_pkt_len), wv_RKey, wv_VA + wv_pkt_len};
        end
        else begin
            q_wat_wr_en <= 1'b1;
            qv_wat_addra <= wv_QPN;
            qv_wat_wr_data <= {(iv_wat_rd_data[127:96] - wv_pkt_len), iv_wat_rd_data[95:64], iv_wat_rd_data[63:0] + wv_pkt_len};
        end 
    end
    else begin
        q_wat_wr_en <= 1'b0;
        qv_wat_addra <= qv_wat_addra;
        qv_wat_wr_data <= qv_wat_wr_data;
    end
end

//-- qv_wat_addrb --
always @(*) begin
    if(rst) begin
        qv_wat_addrb = 'd0;
    end
    else begin
        qv_wat_addrb = i_header_empty ? 'd0 : wv_QPN;
    end
end

assign wv_resp_PKey = wv_PKey;
assign wv_resp_TVer = 4'h0;
assign wv_resp_PC = 'd0;
assign w_resp_Mig = 'd0;
assign w_resp_Solicit = 'd1;
//assign wv_resp_OpCode = (wv_opcode[4:0] == `RDMA_READ_REQUEST) ? `READ_RESPONSE : `ACK;
assign wv_resp_OpCode = (qv_inner_state == `GEN_READ_RESP) ? `READ_RESPONSE : `ACK;
//assign wv_resp_QPN = wv_QPN;
assign wv_resp_QPN = wv_rqpn;
assign w_resp_BECN = 1'b0;
assign w_resp_FECN = 1'b0;
// assign wv_resp_PSN = wv_EPSN;
assign wv_resp_PSN = (qv_inner_state == `GEN_ACK) ? (qv_EPSN - 1) : ((qv_inner_state == `GEN_READ_RESP) ? wv_RPSN : qv_EPSN);
assign w_resp_Acknowledge = 1'b0;
assign wv_resp_PMTU = wv_PMTU;
assign wv_resp_MsgSize = wv_DMALen;     //Only applicable to RDMA Read
assign wv_resp_MSN = ((qv_inner_state == `GEN_ACK || qv_inner_state == `GEN_READ_RESP) && q_last_pkt_of_req) ? wv_MSN + 1 : wv_MSN;

/*Spyglass Delete Begin*/
// //-- qv_resp_Credit -- Current Available Recv WQE number
// always @(posedge clk or posedge rst) begin
//     if (rst) begin
//         qv_resp_Credit <= 'd0;        
//     end
//     else begin
//         //TODO : Have not implemented WQE flow control mechanism
//         qv_resp_Credit <= 'd0;
//     end
// end
/*Spyglass Delete End*/

//-- qv_resp_NAK_Code -- Indicates NAK Error Code
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_resp_NAK_Code <= 'd0;        
    end
    else if (EE_cur_state == EE_RESP_CXT_s && !i_cxtmgt_cxt_empty) begin
        if(wv_qp_state == `QP_ERR) begin
            qv_resp_NAK_Code <= `REMOTE_OPERATIONAL_ERROR;
        end
        else if(wv_RPSN > wv_EPSN) begin
            qv_resp_NAK_Code <= `PSN_SEQUENCE_ERROR;
        end
        else begin
            qv_resp_NAK_Code <= qv_resp_NAK_Code;
        end
    end
    else if (EE_cur_state == EE_RESP_ENTRY_s && !i_rwm_resp_empty) begin
        if(wv_opcode[4:0] == `SEND_FIRST || wv_opcode[4:0] == `SEND_ONLY || wv_opcode[4:0] == `SEND_ONLY_WITH_IMM) begin
            if(qv_pkt_left_length != wv_pkt_len) begin  //Not first entry of the packet
                if(wv_entry_valid == `INVALID_ENTRY) begin
                    qv_resp_NAK_Code <= `REMOTE_OPERATIONAL_ERROR;
                end
                else begin
                    qv_resp_NAK_Code <= qv_resp_NAK_Code;
                end
            end
            else begin
                qv_resp_NAK_Code <= qv_resp_NAK_Code;
            end
        end
        else if(wv_opcode[4:0] == `SEND_MIDDLE || wv_opcode[4:0] == `SEND_LAST || wv_opcode[4:0] == `SEND_LAST_WITH_IMM || wv_opcode[4:0] == `RDMA_WRITE_LAST_WITH_IMM || wv_opcode[4:0] == `RDMA_WRITE_ONLY_WITH_IMM) begin
            if(wv_entry_valid == `INVALID_ENTRY) begin
                qv_resp_NAK_Code <= `REMOTE_OPERATIONAL_ERROR;
            end
            else begin
                qv_resp_NAK_Code <= qv_resp_NAK_Code;
            end
        end
        else begin
            qv_resp_NAK_Code <= qv_resp_NAK_Code;
        end
    end 
    else if (EE_cur_state == EE_VTP_RESP_s && !i_vtp_resp_empty) begin
        if(!w_legal_access) begin
            qv_resp_NAK_Code <= `REMOTE_ACCESS_ERROR;
        end
        else begin
            qv_resp_NAK_Code <= qv_resp_NAK_Code;
        end
    end
    else begin
        qv_resp_NAK_Code <= qv_resp_NAK_Code;
    end
end

//-- qv_resp_Credit --
//TODO : Msg Flow control is not implemented
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_resp_Credit <= 0;        
    end
    else begin
        qv_resp_Credit <= 0;
    end
end

//-- qv_resp_Syndrome --
always @(*) begin
    case(qv_inner_state) 
        `GEN_ACK:   qv_resp_Syndrome = {3'b000, qv_resp_Credit};
        `GEN_NAK:   qv_resp_Syndrome = {3'b011, qv_resp_NAK_Code};
        `GEN_RNR:   qv_resp_Syndrome = {3'b001, wv_RNR_Timer};
        default:    qv_resp_Syndrome = 'd0;
    endcase
end

//-- qv_inner_state --
//-- Indicates what response we need to generate
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_inner_state <= 'd0;        
    end
    else if (EE_cur_state == EE_RESP_CXT_s && !i_cxtmgt_cxt_empty && !i_cxtmgt_resp_empty) begin
        if(wv_qp_state == `QP_ERR) begin
            qv_inner_state <= `GEN_NAK;
        end
        else if(wv_RPSN > wv_EPSN) begin    //PSN Error
            qv_inner_state <= `GEN_NAK;
        end
        else if(wv_opcode[4:0] == `RDMA_READ_REQUEST) begin     //Whether duplicate read or normal read, re-execute the request 
            qv_inner_state <= `GEN_READ_RESP;    
        end
        else begin  //Duplicate Send or Write
            qv_inner_state <= `GEN_ACK;
        end
    end
    else if (EE_cur_state == EE_RESP_ENTRY_s && !i_rwm_resp_empty) begin
        if(wv_opcode[4:0] == `SEND_FIRST || wv_opcode[4:0] == `SEND_ONLY || wv_opcode[4:0] == `SEND_ONLY_WITH_IMM) begin
            if(wv_entry_valid == `INVALID_WQE) begin
                if(qv_pkt_left_length == wv_pkt_len) begin //For First entry of the first packet of the msg, no available WQE
                    qv_inner_state <= `GEN_RNR; 
                end
                else begin
                    qv_inner_state <= `GEN_NAK;
                end
            end
            else if(qv_pkt_left_length <= qv_cur_entry_left_length) begin //Last entry of this packet 
                qv_inner_state <= `GEN_ACK;
            end
            else begin
                qv_inner_state <= qv_inner_state;
            end
        end
        else if (wv_opcode[4:0] == `SEND_MIDDLE || wv_opcode[4:0] == `SEND_LAST || wv_opcode[4:0] == `SEND_LAST_WITH_IMM) begin
            if(wv_entry_valid == `INVALID_ENTRY) begin
                qv_inner_state <= `GEN_NAK;
            end
            else if(qv_pkt_left_length <= qv_cur_entry_left_length) begin
                qv_inner_state <= `GEN_ACK;
            end
            else begin
                qv_inner_state <= qv_inner_state;
            end
        end
        else if(wv_opcode[4:0] == `RDMA_WRITE_ONLY_WITH_IMM || wv_opcode[4:0] == `RDMA_WRITE_LAST_WITH_IMM) begin
            if(wv_entry_valid == `INVALID_WQE) begin
                qv_inner_state <= `GEN_NAK;
            end
            else begin
                qv_inner_state <= `GEN_ACK;
            end
        end
        else begin
            qv_inner_state <= qv_inner_state;
        end
    end
    else if (EE_cur_state == EE_VTP_RESP_s && !i_vtp_resp_empty) begin
        if(wv_opcode[4:0] == `RDMA_READ_REQUEST) begin
            if(w_legal_access) begin
                qv_inner_state <= `GEN_READ_RESP;
            end
            else begin
                qv_inner_state <= `GEN_NAK;
            end
        end
		else if(wv_opcode[4:0] == `SEND_FIRST || wv_opcode[4:0] == `SEND_MIDDLE || wv_opcode[4:0] == `SEND_LAST ||
				wv_opcode[4:0] == `SEND_ONLY || wv_opcode[4:0] == `SEND_ONLY_WITH_IMM || wv_opcode[4:0] == `SEND_LAST_WITH_IMM) begin
            if(w_legal_access) begin
                qv_inner_state <= `GEN_ACK;
            end
            else begin
                qv_inner_state <= `GEN_NAK;
            end    
		end 
        else if(wv_opcode[4:0] == `RDMA_WRITE_FIRST || wv_opcode[4:0] == `RDMA_WRITE_LAST || wv_opcode[4:0] == `RDMA_WRITE_MIDDLE 
                || wv_opcode[4:0] == `RDMA_WRITE_ONLY || wv_opcode[4:0] == `RDMA_WRITE_LAST_WITH_IMM || wv_opcode[4:0] == `RDMA_WRITE_ONLY_WITH_IMM) begin
            if(w_legal_access) begin
                qv_inner_state <= `GEN_ACK;
            end
            else begin
                qv_inner_state <= `GEN_NAK;
            end    
        end
        else begin
            qv_inner_state <= qv_inner_state;
        end
    end
    else begin
        qv_inner_state <= qv_inner_state;
    end
end

//-- q_last_pkt_of_req --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_last_pkt_of_req <= 1'b0;         
    end
    else if (EE_cur_state == EE_FETCH_CXT_s) begin
        if(wv_opcode[4:0] == `SEND_LAST || wv_opcode[4:0] == `SEND_LAST_WITH_IMM || wv_opcode[4:0] == `SEND_ONLY || wv_opcode[4:0] == `SEND_ONLY_WITH_IMM
            || wv_opcode[4:0] == `RDMA_WRITE_LAST || wv_opcode[4:0] == `RDMA_WRITE_LAST_WITH_IMM || wv_opcode[4:0] == `RDMA_WRITE_ONLY 
            || wv_opcode[4:0] == `RDMA_WRITE_ONLY_WITH_IMM || wv_opcode[4:0] == `RDMA_READ_REQUEST) begin
            q_last_pkt_of_req <= 1'b1;
        end
        else begin
            q_last_pkt_of_req <= 1'b0;
        end
    end
    else begin
        q_last_pkt_of_req <= q_last_pkt_of_req;
    end
end

//-- q_rpg_md_wr_en --
//-- qv_rpg_md_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_rpg_md_wr_en <= 1'b0;
        qv_rpg_md_data <= 'd0;        
    end
    else if (EE_cur_state == EE_GEN_RESP_s && !i_rpg_md_prog_full) begin 
		if((wv_rt_table_rd_data == 'd1) && (wv_resp_OpCode == `ACK) && (qv_resp_Syndrome[6:5] == `SYNDROME_NAK) && (qv_resp_Syndrome[4:0] == `PSN_SEQUENCE_ERROR)) begin
        	q_rpg_md_wr_en <= 1'b0; 	//Aoid NAK flooding, we do not generate continuous NAK for the same QP
        	qv_rpg_md_data <= {qv_resp_Syndrome, wv_resp_MSN, wv_resp_MsgSize, 16'h0, wv_resp_PMTU, 
                            w_resp_Acknowledge, 7'h0, wv_resp_PSN, w_resp_FECN, w_resp_BECN, 6'h0, wv_resp_QPN,
                            wv_resp_OpCode, w_resp_Solicit, w_resp_Mig, wv_resp_PC, wv_resp_TVer, wv_resp_PKey};
    	end
		else begin
        	q_rpg_md_wr_en <= 1'b1;		//Other cases we generate responses
        	qv_rpg_md_data <= {qv_resp_Syndrome, wv_resp_MSN, wv_resp_MsgSize, 16'h0, wv_resp_PMTU, 
                            w_resp_Acknowledge, 7'h0, wv_resp_PSN, w_resp_FECN, w_resp_BECN, 6'h0, wv_resp_QPN,
                            wv_resp_OpCode, w_resp_Solicit, w_resp_Mig, wv_resp_PC, wv_resp_TVer, wv_resp_PKey};
		end 
    end
    else begin
        q_rpg_md_wr_en <= 1'b0;
        qv_rpg_md_data <= 'd0;
    end
end

wire    [5:0]           wv_rq_wqe_block_size;      
assign  wv_rq_wqe_block_size = iv_cxtmgt_cxt_data[95:88];   //128B Block

//RQ WQE Manager
//-- q_rwm_cmd_wr_en --
//-- qv_rwm_cmd_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_rwm_cmd_wr_en <= 1'b0;
        qv_rwm_cmd_data <= 'd0;        
    end
    else if (EE_cur_state == EE_FETCH_ENTRY_s && !i_rwm_cmd_prog_full) begin
        q_rwm_cmd_wr_en <= 1'b1;
        // qv_rwm_cmd_data <= {128'd0, wv_RQ_LKey, wv_PD, wv_QPN, 6'd0, `FETCH_ENTRY};
        //qv_rwm_cmd_data <= {128'd0, wv_RQ_LKey, wv_QP_PD, wv_QPN, wv_rq_wqe_block_size, `FETCH_ENTRY};
        qv_rwm_cmd_data <= {112'd0,  wv_RQ_Entry_Size_Log, wv_RQ_Length, wv_RQ_LKey, wv_QP_PD, wv_QPN, 5'd0, `FETCH_ENTRY};
    end
    else if (EE_cur_state == EE_ENTRY_RELEASE_s && !i_rwm_cmd_prog_full) begin
        q_rwm_cmd_wr_en <= 1'b1;
        // qv_rwm_cmd_data <= {192'd0, wv_QPN, 6'd0, `RELEASE_ENTRY};
        //qv_rwm_cmd_data <= {192'd0, wv_QPN, wv_rq_wqe_block_size, `RELEASE_ENTRY};
        qv_rwm_cmd_data <= {112'd0, wv_RQ_Entry_Size_Log, 96'd0, wv_QPN, 5'd0, `RELEASE_ENTRY};

    end
    else if (EE_cur_state == EE_WQE_RELEASE_s && !i_rwm_cmd_prog_full) begin
        q_rwm_cmd_wr_en <= 1'b1;
        // qv_rwm_cmd_data <= {192'd0, wv_QPN, 6'd0, `RELEASE_WQE};
        //qv_rwm_cmd_data <= {192'd0, wv_QPN, wv_rq_wqe_block_size, `RELEASE_WQE};
		qv_rwm_cmd_data <= {112'd0, wv_RQ_Entry_Size_Log, 96'd0, wv_QPN, 5'd0, `RELEASE_WQE};
    end
    else if (EE_cur_state == EE_ENTRY_UPDATE_s && !i_rwm_cmd_prog_full) begin
        q_rwm_cmd_wr_en <= 1'b1;
        // qv_rwm_cmd_data <= {(wv_Entry_VA + (wv_Entry_Len - qv_cur_entry_left_length)), wv_Entry_Key, qv_cur_entry_left_length, 64'd0, wv_QPN, 6'd0, `UPDATE_ENTRY};
        //qv_rwm_cmd_data <= {(wv_Entry_VA + (wv_Entry_Len - qv_cur_entry_left_length)), wv_Entry_Key, qv_cur_entry_left_length, 64'd0, wv_QPN, wv_rq_wqe_block_size, `UPDATE_ENTRY};
        qv_rwm_cmd_data <= {96'd0, (wv_Entry_VA + (wv_Entry_Len - qv_cur_entry_left_length)), wv_Entry_Key, qv_cur_entry_left_length, wv_QPN, 5'd0, `UPDATE_ENTRY};
    end
	else if (EE_cur_state == EE_VTP_RESP_s && !i_vtp_resp_empty && !w_legal_access) begin //Encounter error, release all entries for this QP
		q_rwm_cmd_wr_en <= 1'b1;
		qv_rwm_cmd_data <= {112'd0, wv_RQ_Entry_Size_Log, 96'd0, wv_QPN, 5'd0, `FLUSH_ENTRY};
	end 
	else if (EE_cur_state == EE_RESP_ENTRY_s && !i_rwm_resp_empty && (wv_entry_valid == `INVALID_ENTRY)) begin //Encounter error, release all entries for this QP
		q_rwm_cmd_wr_en <= 1'b1;
		qv_rwm_cmd_data <= {112'd0, wv_RQ_Entry_Size_Log, 96'd0, wv_QPN, 5'd0, `FLUSH_ENTRY};
	end 
    else begin
        q_rwm_cmd_wr_en <= 1'b0;
        qv_rwm_cmd_data <= qv_rwm_cmd_data;
    end
end

//-- q_rwm_resp_rd_en -- We need to clear an entry from the FIFO after a resp arrives
//						Since the resp and process is synchonized, we can safely rd_en and the output of the FIFO will be held
always @(*) begin
	if(rst) begin 
		q_rwm_resp_rd_en = 1'b0;
	end 
    //else if(EE_cur_state == EE_RESP_ENTRY_s && !i_rwm_resp_empty) begin 
    else if(((EE_cur_state == EE_WQE_RELEASE_s) || (EE_cur_state == EE_SCATTER_CMD_s) || (EE_cur_state == EE_PAYLOAD_DROP_s) ||
			(EE_cur_state == EE_SILENT_DROP_s))	 && !i_rwm_resp_empty) begin 
		q_rwm_resp_rd_en = 1'b1;
	end 
	else begin
		q_rwm_resp_rd_en = 1'b0;
	end 
end

//HeaderParser
//-- q_header_rd_en -- Same trick...
always @(*) begin
    if(rst) begin
        q_header_rd_en = 1'b0;
    end 
    else begin 
        q_header_rd_en = (EE_cur_state != EE_IDLE_s && EE_cur_state != EE_INIT_s) && (EE_next_state == EE_IDLE_s);
    end 
end

//-- q_nd_rd_en --
always @(*) begin
    case(EE_cur_state)
        EE_SCATTER_DATA_s:  if(qv_cur_entry_left_length <= qv_unwritten_len) begin
                                q_nd_rd_en = 1'b0;
                            end
                            else if(qv_pkt_left_length > 0 && !i_vtp_upload_prog_full && !i_nd_empty) begin
                                q_nd_rd_en = 1'b1;
                            end
							else begin
								q_nd_rd_en = 1'b0;
							end 
        EE_WRITE_DATA_s:    q_nd_rd_en = !i_nd_empty && !i_vtp_upload_prog_full && (qv_pkt_left_length > 0);  
        EE_SILENT_DROP_s:          q_nd_rd_en = (wv_pkt_len != 0) && (!i_nd_empty);  
        EE_PAYLOAD_DROP_s:          q_nd_rd_en = (wv_pkt_len != 0) && (!i_nd_empty);  
        default:            q_nd_rd_en = 1'b0;
    endcase
end

reg             [3:0]       qv_vtp_type;
reg             [3:0]       qv_vtp_opcode;      //Indicates the VirtToPhys operation
reg             [31:0]      qv_vtp_pd;
reg             [31:0]      qv_vtp_key;
reg             [63:0]      qv_vtp_vaddr;
reg             [31:0]      qv_vtp_length;

wire            [63:0]      wv_Stored_VA;
wire            [31:0]      wv_Stored_RKey;

assign wv_Stored_VA = iv_wat_rd_data[63:0];
assign wv_Stored_RKey = iv_wat_rd_data[95:64];

//-- qv_vtp_type --
always @(*) begin
    if (rst) begin
        qv_vtp_type = 'd0;        
        qv_vtp_opcode = 'd0;  
        qv_vtp_pd = 'd0; 
    end
    else if (EE_cur_state == EE_EXE_READ_s) begin
        qv_vtp_type = `RD_REQ_DATA;        
        qv_vtp_opcode = `RD_R_NET_DATA;  
        qv_vtp_pd = wv_QP_PD;         
    end
    else if ((EE_cur_state == EE_EXE_WRITE_s) || (EE_cur_state == EE_SCATTER_CMD_s)) begin
        qv_vtp_type = `WR_REQ_DATA;
        qv_vtp_opcode = `WR_R_NET_DATA;
        qv_vtp_pd = wv_QP_PD;
    end
    else if (EE_cur_state == EE_GEN_CPL_s) begin
        qv_vtp_type = `WR_REQ_DATA;
        qv_vtp_opcode = `WR_CQE_DATA;
        qv_vtp_pd = wv_CQ_PD;        
    end
    else begin
        qv_vtp_type = 'd0;
        qv_vtp_opcode = 'd0;
        qv_vtp_pd = 'd0;             
    end
end

wire 			[31:0]		wv_vtp_flags;
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
	else if (EE_cur_state == EE_EXE_READ_s) begin 
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
		q_ibv_access_remote_read = 'd1;
		q_ibv_access_remote_write = 'd0;
		q_ibv_access_local_write = 'd0;
	end 
	else if (EE_cur_state == EE_EXE_WRITE_s) begin 
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
		q_ibv_access_remote_write = 'd1;
		q_ibv_access_local_write = 'd0;
	end 
	else if (EE_cur_state == EE_SCATTER_CMD_s) begin 
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
	else if (EE_cur_state == EE_GEN_CPL_s) begin 
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

//-- qv_vtp_key --
//-- qv_vtp_vaddr --
always @(*) begin
    if (rst) begin
        qv_vtp_key = 'd0;
        qv_vtp_vaddr = 'd0;
    end
    else if (EE_cur_state == EE_EXE_READ_s) begin
        qv_vtp_key = wv_RKey;
        qv_vtp_vaddr = wv_VA;
    end
    else if (EE_cur_state == EE_EXE_WRITE_s) begin
        if(wv_opcode[4:0] == `RDMA_WRITE_FIRST || wv_opcode[4:0] == `RDMA_WRITE_ONLY || wv_opcode[4:0] == `RDMA_WRITE_ONLY_WITH_IMM) begin
            qv_vtp_key = wv_RKey;
            qv_vtp_vaddr = wv_VA;
        end
        else begin
            qv_vtp_key = wv_Stored_RKey;
            qv_vtp_vaddr = wv_Stored_VA;
        end
    end
    else if(EE_cur_state == EE_SCATTER_CMD_s) begin
        qv_vtp_key = wv_Entry_Key;
        qv_vtp_vaddr = wv_Entry_VA;
    end
    else if(EE_cur_state == EE_GEN_CPL_s) begin
        qv_vtp_key = wv_CQ_LKey;
        qv_vtp_vaddr = {40'd0, iv_ee_cq_offset};
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
    else if (EE_cur_state == EE_EXE_READ_s) begin
        qv_vtp_length = wv_DMALen;
    end
    else if(EE_cur_state == EE_EXE_WRITE_s) begin
        qv_vtp_length = wv_pkt_len;
    end
    else if(EE_cur_state == EE_SCATTER_CMD_s) begin
        if(qv_pkt_left_length + qv_unwritten_len <= qv_cur_entry_left_length) begin
            qv_vtp_length = qv_pkt_left_length + qv_unwritten_len;
        end
        else begin
            qv_vtp_length = qv_cur_entry_left_length;
        end
    end
    else if(EE_cur_state == EE_GEN_CPL_s) begin
        qv_vtp_length = `CQE_LENGTH;
    end
    else begin
        qv_vtp_length = 'd0;
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
    else if (EE_cur_state == EE_EXE_READ_s && !i_vtp_cmd_prog_full) begin
        q_vtp_cmd_wr_en <= 1'b1;
        qv_vtp_cmd_data <= {32'd0, qv_vtp_length, qv_vtp_vaddr, qv_vtp_key, qv_vtp_pd, wv_vtp_flags, 24'd0, qv_vtp_opcode, qv_vtp_type};
    end
    else if (EE_cur_state == EE_EXE_WRITE_s && !i_vtp_cmd_prog_full) begin
        q_vtp_cmd_wr_en <= 1'b1;
        qv_vtp_cmd_data <= {32'd0, qv_vtp_length, qv_vtp_vaddr, qv_vtp_key, qv_vtp_pd, wv_vtp_flags, 24'd0, qv_vtp_opcode, qv_vtp_type};
    end
    else if (EE_cur_state == EE_SCATTER_CMD_s && !i_vtp_cmd_prog_full) begin
        q_vtp_cmd_wr_en <= 1'b1;
        qv_vtp_cmd_data <= {32'd0, qv_vtp_length, qv_vtp_vaddr, qv_vtp_key, qv_vtp_pd, wv_vtp_flags, 24'd0, qv_vtp_opcode, qv_vtp_type};
    end
	//Upload Completion Event for Send/Send with IMM/Write with IMM
    else if (EE_cur_state == EE_GEN_CPL_s && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && i_ee_resp_valid) begin 
        q_vtp_cmd_wr_en <= 1'b1;
        qv_vtp_cmd_data <= {32'd0, `CQE_LENGTH, qv_vtp_vaddr, qv_vtp_key, qv_vtp_pd, wv_vtp_flags, 24'd0, qv_vtp_opcode, qv_vtp_type};        
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
    //else if(EE_cur_state == EE_VTP_RESP_s && !i_vtp_resp_empty) begin
    else if(!i_vtp_resp_empty) begin 	//Since vtp resp is synchronized, we can safely read out the value and the output will not change
        q_vtp_resp_rd_en = 1'b1;
    end
    else begin
        q_vtp_resp_rd_en = 1'b0;
    end
end

//-- q_vtp_upload_wr_en --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_vtp_upload_wr_en <= 1'b0;
    end
    else if (EE_cur_state == EE_WRITE_DATA_s && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_nd_empty && (qv_pkt_left_length > 0)) begin
        q_vtp_upload_wr_en <= 1'b1;
    end
    else if (EE_cur_state == EE_SCATTER_DATA_s) begin //Similar to state transition
        if(qv_pkt_left_length + qv_unwritten_len <= qv_cur_entry_left_length) begin
            if(qv_pkt_left_length == 0 && !i_vtp_upload_prog_full) begin
                q_vtp_upload_wr_en <= 1'b1;
            end 
            else if(!i_vtp_upload_prog_full && !i_nd_empty) begin
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
            else if(qv_cur_entry_left_length <= 32 && qv_cur_entry_left_length > qv_unwritten_len && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_nd_empty) begin
                q_vtp_upload_wr_en <= 1'b1;
            end
            else if(qv_cur_entry_left_length > 32 && !i_vtp_upload_prog_full && !i_nd_empty) begin
                q_vtp_upload_wr_en <= 1'b1;
            end
            else begin
                q_vtp_upload_wr_en <= 1'b0;
            end
        end
    end
    else if(EE_cur_state == EE_GEN_CPL_s && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && i_ee_resp_valid) begin
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

reg             [7:0]           qv_vendor_err;
reg             [7:0]           qv_syndrome;

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
    else if(EE_cur_state == EE_GEN_CPL_s && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin 
        qv_my_qpn = {8'd0, wv_QPN};
        qv_my_ee = 'd0;
        qv_rqpn = {8'd0, wv_resp_QPN};
        qv_rlid = wv_rlid;
        qv_sl_g_mlpath = 'd0;
        qv_imm_etype_pkey_eec = 'd0;
        qv_byte_cnt = wv_bc_doutb;              
        qv_wqe = wv_WQE_Offset;
        qv_owner = 'd0;
        qv_is_send = 'd0;
        qv_opcode = wv_opcode[4:0];

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
    else if (EE_cur_state == EE_WRITE_DATA_s && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_nd_empty) begin
        qv_vtp_upload_data <= iv_nd_data;
    end
    else if (EE_cur_state == EE_SCATTER_DATA_s) begin
        if(qv_pkt_left_length + qv_unwritten_len <= qv_cur_entry_left_length) begin     //Entry is enough
            if(qv_pkt_left_length == 0 && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin
                case(qv_unwritten_len)
                    0:          qv_vtp_upload_data <= iv_nd_data;   //In this conditional branch, this will not happen
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
            else if(qv_pkt_left_length > 0 && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_nd_empty) begin
                case(qv_unwritten_len)
                    0:          qv_vtp_upload_data <= iv_nd_data;  
                    1:          qv_vtp_upload_data <= {iv_nd_data[(32 - 1 ) * 8 - 1 : 0], qv_unwritten_data[1 * 8 - 1 : 0]}; 
                    2:          qv_vtp_upload_data <= {iv_nd_data[(32 - 2 ) * 8 - 1 : 0], qv_unwritten_data[2 * 8 - 1 : 0]}; 
                    3:          qv_vtp_upload_data <= {iv_nd_data[(32 - 3 ) * 8 - 1 : 0], qv_unwritten_data[3 * 8 - 1 : 0]}; 
                    4:          qv_vtp_upload_data <= {iv_nd_data[(32 - 4 ) * 8 - 1 : 0], qv_unwritten_data[4 * 8 - 1 : 0]}; 
                    5:          qv_vtp_upload_data <= {iv_nd_data[(32 - 5 ) * 8 - 1 : 0], qv_unwritten_data[5 * 8 - 1 : 0]}; 
                    6:          qv_vtp_upload_data <= {iv_nd_data[(32 - 6 ) * 8 - 1 : 0], qv_unwritten_data[6 * 8 - 1 : 0]}; 
                    7:          qv_vtp_upload_data <= {iv_nd_data[(32 - 7 ) * 8 - 1 : 0], qv_unwritten_data[7 * 8 - 1 : 0]}; 
                    8:          qv_vtp_upload_data <= {iv_nd_data[(32 - 8 ) * 8 - 1 : 0], qv_unwritten_data[8 * 8 - 1 : 0]}; 
                    9:          qv_vtp_upload_data <= {iv_nd_data[(32 - 9 ) * 8 - 1 : 0], qv_unwritten_data[9 * 8 - 1 : 0]}; 
                    10:         qv_vtp_upload_data <= {iv_nd_data[(32 - 10) * 8 - 1 : 0], qv_unwritten_data[10 * 8 - 1 : 0]};
                    11:         qv_vtp_upload_data <= {iv_nd_data[(32 - 11) * 8 - 1 : 0], qv_unwritten_data[11 * 8 - 1 : 0]};
                    12:         qv_vtp_upload_data <= {iv_nd_data[(32 - 12) * 8 - 1 : 0], qv_unwritten_data[12 * 8 - 1 : 0]};
                    13:         qv_vtp_upload_data <= {iv_nd_data[(32 - 13) * 8 - 1 : 0], qv_unwritten_data[13 * 8 - 1 : 0]};
                    14:         qv_vtp_upload_data <= {iv_nd_data[(32 - 14) * 8 - 1 : 0], qv_unwritten_data[14 * 8 - 1 : 0]};
                    15:         qv_vtp_upload_data <= {iv_nd_data[(32 - 15) * 8 - 1 : 0], qv_unwritten_data[15 * 8 - 1 : 0]};
                    16:         qv_vtp_upload_data <= {iv_nd_data[(32 - 16) * 8 - 1 : 0], qv_unwritten_data[16 * 8 - 1 : 0]};
                    17:         qv_vtp_upload_data <= {iv_nd_data[(32 - 17) * 8 - 1 : 0], qv_unwritten_data[17 * 8 - 1 : 0]};
                    18:         qv_vtp_upload_data <= {iv_nd_data[(32 - 18) * 8 - 1 : 0], qv_unwritten_data[18 * 8 - 1 : 0]};
                    19:         qv_vtp_upload_data <= {iv_nd_data[(32 - 19) * 8 - 1 : 0], qv_unwritten_data[19 * 8 - 1 : 0]};
                    20:         qv_vtp_upload_data <= {iv_nd_data[(32 - 20) * 8 - 1 : 0], qv_unwritten_data[20 * 8 - 1 : 0]};
                    21:         qv_vtp_upload_data <= {iv_nd_data[(32 - 21) * 8 - 1 : 0], qv_unwritten_data[21 * 8 - 1 : 0]};
                    22:         qv_vtp_upload_data <= {iv_nd_data[(32 - 22) * 8 - 1 : 0], qv_unwritten_data[22 * 8 - 1 : 0]};
                    23:         qv_vtp_upload_data <= {iv_nd_data[(32 - 23) * 8 - 1 : 0], qv_unwritten_data[23 * 8 - 1 : 0]};
                    24:         qv_vtp_upload_data <= {iv_nd_data[(32 - 24) * 8 - 1 : 0], qv_unwritten_data[24 * 8 - 1 : 0]};
                    25:         qv_vtp_upload_data <= {iv_nd_data[(32 - 25) * 8 - 1 : 0], qv_unwritten_data[25 * 8 - 1 : 0]};
                    26:         qv_vtp_upload_data <= {iv_nd_data[(32 - 26) * 8 - 1 : 0], qv_unwritten_data[26 * 8 - 1 : 0]};
                    27:         qv_vtp_upload_data <= {iv_nd_data[(32 - 27) * 8 - 1 : 0], qv_unwritten_data[27 * 8 - 1 : 0]};
                    28:         qv_vtp_upload_data <= {iv_nd_data[(32 - 28) * 8 - 1 : 0], qv_unwritten_data[28 * 8 - 1 : 0]};
                    29:         qv_vtp_upload_data <= {iv_nd_data[(32 - 29) * 8 - 1 : 0], qv_unwritten_data[29 * 8 - 1 : 0]};
                    30:         qv_vtp_upload_data <= {iv_nd_data[(32 - 30) * 8 - 1 : 0], qv_unwritten_data[30 * 8 - 1 : 0]};
                    31:         qv_vtp_upload_data <= {iv_nd_data[(32 - 31) * 8 - 1 : 0], qv_unwritten_data[31 * 8 - 1 : 0]};
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
                    0:          qv_vtp_upload_data <= iv_nd_data;   //In this conditional branch, this will not happen
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
            else if(qv_cur_entry_left_length > qv_unwritten_len && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full && !i_nd_empty) begin
                case(qv_unwritten_len)
                    0:          qv_vtp_upload_data <= iv_nd_data;   
                    1:          qv_vtp_upload_data <= {iv_nd_data[(32 - 1 ) * 8 - 1 : 0], qv_unwritten_data[1 * 8 - 1 : 0]}; 
                    2:          qv_vtp_upload_data <= {iv_nd_data[(32 - 2 ) * 8 - 1 : 0], qv_unwritten_data[2 * 8 - 1 : 0]}; 
                    3:          qv_vtp_upload_data <= {iv_nd_data[(32 - 3 ) * 8 - 1 : 0], qv_unwritten_data[3 * 8 - 1 : 0]}; 
                    4:          qv_vtp_upload_data <= {iv_nd_data[(32 - 4 ) * 8 - 1 : 0], qv_unwritten_data[4 * 8 - 1 : 0]}; 
                    5:          qv_vtp_upload_data <= {iv_nd_data[(32 - 5 ) * 8 - 1 : 0], qv_unwritten_data[5 * 8 - 1 : 0]}; 
                    6:          qv_vtp_upload_data <= {iv_nd_data[(32 - 6 ) * 8 - 1 : 0], qv_unwritten_data[6 * 8 - 1 : 0]}; 
                    7:          qv_vtp_upload_data <= {iv_nd_data[(32 - 7 ) * 8 - 1 : 0], qv_unwritten_data[7 * 8 - 1 : 0]}; 
                    8:          qv_vtp_upload_data <= {iv_nd_data[(32 - 8 ) * 8 - 1 : 0], qv_unwritten_data[8 * 8 - 1 : 0]}; 
                    9:          qv_vtp_upload_data <= {iv_nd_data[(32 - 9 ) * 8 - 1 : 0], qv_unwritten_data[9 * 8 - 1 : 0]}; 
                    10:         qv_vtp_upload_data <= {iv_nd_data[(32 - 10) * 8 - 1 : 0], qv_unwritten_data[10 * 8 - 1 : 0]};
                    11:         qv_vtp_upload_data <= {iv_nd_data[(32 - 11) * 8 - 1 : 0], qv_unwritten_data[11 * 8 - 1 : 0]};
                    12:         qv_vtp_upload_data <= {iv_nd_data[(32 - 12) * 8 - 1 : 0], qv_unwritten_data[12 * 8 - 1 : 0]};
                    13:         qv_vtp_upload_data <= {iv_nd_data[(32 - 13) * 8 - 1 : 0], qv_unwritten_data[13 * 8 - 1 : 0]};
                    14:         qv_vtp_upload_data <= {iv_nd_data[(32 - 14) * 8 - 1 : 0], qv_unwritten_data[14 * 8 - 1 : 0]};
                    15:         qv_vtp_upload_data <= {iv_nd_data[(32 - 15) * 8 - 1 : 0], qv_unwritten_data[15 * 8 - 1 : 0]};
                    16:         qv_vtp_upload_data <= {iv_nd_data[(32 - 16) * 8 - 1 : 0], qv_unwritten_data[16 * 8 - 1 : 0]};
                    17:         qv_vtp_upload_data <= {iv_nd_data[(32 - 17) * 8 - 1 : 0], qv_unwritten_data[17 * 8 - 1 : 0]};
                    18:         qv_vtp_upload_data <= {iv_nd_data[(32 - 18) * 8 - 1 : 0], qv_unwritten_data[18 * 8 - 1 : 0]};
                    19:         qv_vtp_upload_data <= {iv_nd_data[(32 - 19) * 8 - 1 : 0], qv_unwritten_data[19 * 8 - 1 : 0]};
                    20:         qv_vtp_upload_data <= {iv_nd_data[(32 - 20) * 8 - 1 : 0], qv_unwritten_data[20 * 8 - 1 : 0]};
                    21:         qv_vtp_upload_data <= {iv_nd_data[(32 - 21) * 8 - 1 : 0], qv_unwritten_data[21 * 8 - 1 : 0]};
                    22:         qv_vtp_upload_data <= {iv_nd_data[(32 - 22) * 8 - 1 : 0], qv_unwritten_data[22 * 8 - 1 : 0]};
                    23:         qv_vtp_upload_data <= {iv_nd_data[(32 - 23) * 8 - 1 : 0], qv_unwritten_data[23 * 8 - 1 : 0]};
                    24:         qv_vtp_upload_data <= {iv_nd_data[(32 - 24) * 8 - 1 : 0], qv_unwritten_data[24 * 8 - 1 : 0]};
                    25:         qv_vtp_upload_data <= {iv_nd_data[(32 - 25) * 8 - 1 : 0], qv_unwritten_data[25 * 8 - 1 : 0]};
                    26:         qv_vtp_upload_data <= {iv_nd_data[(32 - 26) * 8 - 1 : 0], qv_unwritten_data[26 * 8 - 1 : 0]};
                    27:         qv_vtp_upload_data <= {iv_nd_data[(32 - 27) * 8 - 1 : 0], qv_unwritten_data[27 * 8 - 1 : 0]};
                    28:         qv_vtp_upload_data <= {iv_nd_data[(32 - 28) * 8 - 1 : 0], qv_unwritten_data[28 * 8 - 1 : 0]};
                    29:         qv_vtp_upload_data <= {iv_nd_data[(32 - 29) * 8 - 1 : 0], qv_unwritten_data[29 * 8 - 1 : 0]};
                    30:         qv_vtp_upload_data <= {iv_nd_data[(32 - 30) * 8 - 1 : 0], qv_unwritten_data[30 * 8 - 1 : 0]};
                    31:         qv_vtp_upload_data <= {iv_nd_data[(32 - 31) * 8 - 1 : 0], qv_unwritten_data[31 * 8 - 1 : 0]};
                    default:    qv_vtp_upload_data <= qv_vtp_upload_data;
                endcase                
            end 
            else begin
                qv_vtp_upload_data <= qv_vtp_upload_data;
            end 
        end
    end
    else if(EE_cur_state == EE_GEN_CPL_s && !i_vtp_cmd_prog_full && !i_vtp_upload_prog_full) begin
        if(qv_qp_state == `QP_RTS || qv_qp_state == `QP_RTR) begin
            //qv_vtp_upload_data <= {qv_opcode, qv_is_send, 8'd0, qv_owner, qv_wqe, qv_imm_etype_pkey_eec, qv_sl_g_mlpath, qv_rlid, qv_rqpn, qv_my_ee, qv_my_qpn};
            //qv_vtp_upload_data <= {qv_owner, 8'd0, qv_is_send, qv_opcode, qv_wqe, qv_byte_cnt, qv_imm_etype_pkey_eec, qv_sl_g_mlpath, qv_rlid, qv_rqpn, qv_my_ee, qv_my_qpn};
            qv_vtp_upload_data <= {qv_owner, 8'd0, qv_is_send, qv_opcode, qv_wqe, qv_byte_cnt, qv_imm_etype_pkey_eec, qv_rlid, qv_sl_g_mlpath, qv_rqpn, qv_my_ee, qv_my_qpn};
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

/***************************************    CxtMgt      ***********************************/
//CxtMgt
//-- q_cxtmgt_cmd_wr_en --
//-- qv_cxtmgt_cmd_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_cxtmgt_cmd_wr_en <= 1'd0;     
        qv_cxtmgt_cmd_data <= 'd0;    
    end
    else if (EE_cur_state == EE_FETCH_CXT_s && !i_header_empty && !i_cxtmgt_cmd_prog_full) begin
        q_cxtmgt_cmd_wr_en <= 1'b1;
        qv_cxtmgt_cmd_data <= {`RD_QP_CTX, `RD_QP_RST, wv_QPN, 96'h0};        
    end
    else if (EE_cur_state == EE_CXT_WB_s && w_cxt_not_full) begin
        q_cxtmgt_cmd_wr_en <= 1'b1;
        qv_cxtmgt_cmd_data <= {`WR_QP_CTX, `WR_QP_EPST, wv_QPN, 96'h0};
    end
    else begin
        q_cxtmgt_cmd_wr_en <= 1'b0;
        qv_cxtmgt_cmd_data <= qv_cxtmgt_cmd_data;        
    end
end

//Simplified coding
//-- q_cxtmgt_resp_rd_en --
always @(*) begin
	if(rst) begin
	    q_cxtmgt_resp_rd_en = 1'b0;
	end
	else begin
		q_cxtmgt_resp_rd_en = ((EE_cur_state != EE_IDLE_s) && (EE_next_state == EE_IDLE_s));
	end 
end

//Simplified coding
//-- q_cxtmgt_cxt_rd_en --
always @(*) begin
	if(rst) begin
	    q_cxtmgt_cxt_rd_en = 1'b0;
	end 
	else begin
		q_cxtmgt_cxt_rd_en = ((EE_cur_state != EE_IDLE_s) && (EE_next_state == EE_IDLE_s));
	end 
end

//-- q_cxtmgt_cxt_wr_en --
//-- qv_cxtmgt_cxt_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_cxtmgt_cxt_wr_en <= 1'b0;
        qv_cxtmgt_cxt_data <= 'd0;        
    end
    else if (EE_cur_state == EE_CXT_WB_s && w_cxt_not_full) begin
        q_cxtmgt_cxt_wr_en <= 1'b1;
        qv_cxtmgt_cxt_data <= {96'h0, qv_EPSN, 5'h0, qv_qp_state};     //TODO : QP state should be modified if we encounter some errors
    end
    else begin
        q_cxtmgt_cxt_wr_en <= 1'b0;
        qv_cxtmgt_cxt_data <= qv_cxtmgt_cxt_data;
    end
end



/********************************************** MSN Table ************************************************/

//BRAM_SDP_24w_16384d MSN_Table (
//`ifdef CHIP_VERSION
//	.RTSEL(rw_data[2 * 32 + 1 : 2 * 32 + 0]),
//	.WTSEL(rw_data[2 * 32 + 3 : 2 * 32 + 2]),
//	.PTSEL(rw_data[2 * 32 + 5 : 2 * 32 + 4]),
//	.VG(rw_data[2 * 32 + 6 : 2 * 32 + 6]),
//	.VS(rw_data[2 * 32 + 7 : 2 * 32 + 7]),
//`endif
//
//  .clka(clk),    // input wire clka
//  .ena(1'b1),      // input wire ena
//  .wea(q_MSN_Table_wea),      // input wire [0 : 0] wea
//  .addra(qv_MSN_Table_addra),  // input wire [13 : 0] addra
//  .dina(qv_MSN_Table_dina),    // input wire [23 : 0] dina
//  .clkb(clk),    // input wire clkb
//  .enb(1'b1),      // input wire enb
//  .addrb(qv_MSN_Table_addrb),  // input wire [13 : 0] addrb
//  .doutb(wv_MSN_Table_doutb_fake)  // output wire [23 : 0] doutb
//);

//assign wv_MSN_Table_doutb = ((q_MSN_Table_wea_TempReg == 1'b1) && (qv_MSN_Table_addra_TempReg == qv_MSN_Table_addrb_TempReg)) ? qv_MSN_Table_dina_TempReg : wv_MSN_Table_doutb_fake;
assign wv_MSN_Table_doutb = 'd0;
assign wv_MSN_Table_doutb_fake = 'd0;

//-- q_MSN_Table_wea --
//-- qv_MSN_Table_addra --
//-- qv_MSN_Table_dina --
always @(*) begin
    if (rst) begin
        q_MSN_Table_wea = 1'b0;
        qv_MSN_Table_addra = 'd0;
        qv_MSN_Table_dina = 'd0;
    end
    else if (EE_cur_state == EE_INIT_s) begin   //Clear MSN Table
        q_MSN_Table_wea = 1'b1;
        qv_MSN_Table_addra = qv_init_counter;
        qv_MSN_Table_dina = 'd0;
    end
    else if(EE_cur_state == EE_GEN_RESP_s) begin
        if((qv_inner_state == `GEN_ACK || qv_inner_state == `GEN_READ_RESP) && q_last_pkt_of_req) begin
            q_MSN_Table_wea = 1'b1;
            qv_MSN_Table_addra = wv_QPN;
            qv_MSN_Table_dina = wv_MSN + 1;
        end
        else begin
            q_MSN_Table_wea = 1'b0;
            qv_MSN_Table_addra = qv_MSN_Table_addra_TempReg;
            qv_MSN_Table_dina = qv_MSN_Table_dina_TempReg;
        end
    end
    else begin
        q_MSN_Table_wea = 1'b0;
        qv_MSN_Table_addra = qv_MSN_Table_addra_TempReg;
        qv_MSN_Table_dina = qv_MSN_Table_dina_TempReg;        
    end
end

//-- qv_MSN_Table_addrb --
always @(*) begin
    if (rst) begin
        qv_MSN_Table_addrb = 'd0;        
    end
    else if (EE_cur_state == EE_IDLE_s && !i_header_empty) begin
        qv_MSN_Table_addrb = wv_QPN;
    end
    else begin
        qv_MSN_Table_addrb = qv_MSN_Table_addrb_TempReg;
    end
end

always @(posedge clk or posedge rst) begin
	if(rst) begin
		q_MSN_Table_wea_TempReg <= 'd0;
		qv_MSN_Table_addra_TempReg <= 'd0;
		qv_MSN_Table_dina_TempReg <= 'd0;
		qv_MSN_Table_addrb_TempReg <= 'd0;
	end 
	else begin
		q_MSN_Table_wea_TempReg <= q_MSN_Table_wea;
		qv_MSN_Table_addra_TempReg <= qv_MSN_Table_addra;
		qv_MSN_Table_dina_TempReg <= qv_MSN_Table_dina;
		qv_MSN_Table_addrb_TempReg <= qv_MSN_Table_addrb;
	end 
end 

/********************************************** CQ Offset Table ************************************************/

// BRAM_SDP_16w_16384d CQ_OFFSET_TABLE(
//`ifdef CHIP_VERSION
//   .clka(clk),    
//   .ena(1'b1),      
//   .wea(q_cq_offset_table_wea),      
//   .addra(qv_cq_offset_table_addra),  
//   .dina(qv_cq_offset_table_dina),
//   .clkb(clk),    
//   .enb(1'b1),        
//   .addrb(qv_cq_offset_table_addrb),  
//   .doutb(wv_cq_offset_table_doutb)  
// );
//assign wv_cq_offset_table_doutb = 'd0;
//
////Unused but keepped, should be deleted in the future
////-- q_cq_offset_table_wea --
////-- qv_cq_offset_table_addra --
////-- qv_cq_offset_table_dina --
//always @(posedge clk or posedge rst) begin
//    if (rst) begin
//        q_cq_offset_table_wea <= 'd0;
//        qv_cq_offset_table_addra <= 'd0;
//        qv_cq_offset_table_dina <= 'd0;       
//    end
//    else begin
//        q_cq_offset_table_wea <= 'd0;
//        qv_cq_offset_table_addra <= wv_QPN;
//        qv_cq_offset_table_dina <= qv_cq_offset_table_dina;    
//    end
//end
//
////Unused but keepped, should be deleted in the future
////-- qv_cq_offset_table_addrb --
//always @(*) begin
//    if(rst) begin
//        qv_cq_offset_table_addrb = 'd0;
//    end
//    else begin 
//        qv_cq_offset_table_addrb = wv_QPN;
//    end 
//end

//-- q_bc_wea --
//-- qv_bc_addra --
//-- qv_bc_dina --
//-- qv_bc_addrb
always @(*) begin
	if(rst) begin
		q_bc_wea = 'd0;
		qv_bc_addra = 'd0;
		qv_bc_dina = 'd0;
		qv_bc_addrb = 'd0;
	end 
	else if(EE_cur_state == EE_INIT_s) begin
		if(qv_init_counter <= `QP_NUM - 1) begin
			q_bc_wea = 'd1;
			qv_bc_addra = qv_init_counter;
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
	else if(EE_cur_state == EE_SCATTER_CMD_s && !i_vtp_cmd_prog_full) begin	//Accumulate bytes of SEND
		q_bc_wea = 'd1;
		qv_bc_addra = wv_QPN;
		qv_bc_dina = wv_bc_doutb + qv_vtp_length;
		qv_bc_addrb = wv_QPN;
	end 
	//Deal with VERBS_RDMA_WRITE and VERBS_RDMA_WRITE_WITH_IMM
	else if(EE_cur_state == EE_EXE_WRITE_s && (wv_opcode[4:0] == `RDMA_WRITE_LAST || wv_opcode[4:0] == `RDMA_WRITE_ONLY) && !i_vtp_cmd_prog_full) begin
		q_bc_wea = 'd1;
		qv_bc_addra = wv_QPN;
		qv_bc_dina = 'd0;
		qv_bc_addrb = wv_QPN;
	end 
	else if(EE_cur_state == EE_EXE_WRITE_s && (wv_opcode[4:0] != `RDMA_WRITE_LAST && wv_opcode[4:0] != `RDMA_WRITE_ONLY) && !i_vtp_cmd_prog_full) begin
		q_bc_wea = 'd1;
		qv_bc_addra = wv_QPN;
		qv_bc_dina = wv_bc_doutb + wv_pkt_len;
		qv_bc_addrb = wv_QPN;
	end 
	else if(EE_cur_state == EE_GEN_CPL_s && w_cpl_finish) begin
		q_bc_wea = 'd1;
		qv_bc_addra = wv_QPN;
		qv_bc_dina = 'd0;
		qv_bc_addrb = wv_QPN;
	end 
	else begin
		q_bc_wea = 'd0;
		qv_bc_addra = qv_bc_addra_TempReg;
		qv_bc_dina = qv_bc_dina_TempReg;
		qv_bc_addrb = qv_bc_addrb_TempReg;
	end 
end 

assign o_ee_req_valid = (EE_cur_state == EE_GEN_CPL_s) && !i_ee_resp_valid;
assign ov_ee_cq_index = wv_cqn;
assign ov_ee_cq_size = wv_cq_length;


/*----------------------------- Connect dbg bus -------------------------------------*/
wire   [`DBG_NUM_EXECUTION_ENGINE * 32 - 1 : 0]   coalesced_bus;

assign coalesced_bus = {
                            q_bc_wea,
                            qv_bc_addra,
                            qv_bc_dina,
                            qv_bc_addrb,
                            qv_bc_addra_TempReg,
                            qv_bc_dina_TempReg,
                            qv_bc_addrb_TempReg,
                            q_rwm_cmd_wr_en,
                            qv_rwm_cmd_data,
                            q_rwm_resp_rd_en,
                            q_wat_wr_en,
                            qv_wat_wr_data,
                            qv_wat_addra,
                            qv_wat_addrb,
                            q_rpg_md_wr_en,
                            qv_rpg_md_data,
                            q_header_rd_en,
                            q_nd_rd_en,
                            q_vtp_cmd_wr_en,
                            qv_vtp_cmd_data,
                            q_vtp_resp_rd_en,
                            q_vtp_upload_wr_en,
                            qv_vtp_upload_data,
                            q_cxtmgt_cmd_wr_en,
                            qv_cxtmgt_cmd_data,
                            q_cxtmgt_resp_rd_en,
                            q_cxtmgt_cxt_rd_en,
                            q_cxtmgt_cxt_wr_en,
                            qv_cxtmgt_cxt_data,
                            qv_pkt_left_length,
                            qv_cur_entry_left_length,
                            qv_unwritten_len,
                            qv_unwritten_data,
                            qv_resp_Credit,
                            qv_resp_NAK_Code,
                            qv_resp_Syndrome,
                            q_last_pkt_of_req,
                            qv_inner_state,
                            qv_init_counter,
                            qv_EPSN,
                            q_MSN_Table_wea,
                            qv_MSN_Table_addra,
                            qv_MSN_Table_dina,
                            qv_MSN_Table_addrb,
                            q_MSN_Table_wea_TempReg,
                            qv_MSN_Table_addra_TempReg,
                            qv_MSN_Table_dina_TempReg,
                            qv_MSN_Table_addrb_TempReg,
							1'b0,
							14'd0,
							16'd0,
							14'd0,
                            //q_cq_offset_table_wea,
                            //qv_cq_offset_table_addra,
                            //qv_cq_offset_table_dina,
                            //qv_cq_offset_table_addrb,
                            EE_cur_state,
                            EE_next_state,
                            qv_vtp_type,
                            qv_vtp_opcode,
                            qv_vtp_pd,
                            qv_vtp_key,
                            qv_vtp_vaddr,
                            qv_vtp_length,
                            qv_my_qpn,
                            qv_my_ee,
                            qv_rqpn,
                            qv_rlid,
                            qv_sl_g_mlpath,
                            qv_imm_etype_pkey_eec,
                            qv_byte_cnt,
                            qv_wqe,
                            qv_owner,
                            qv_is_send,
                            qv_opcode,
                            qv_vendor_err,
                            qv_syndrome,
                            wv_bc_doutb,
                            wv_bc_doutb_fake,
                            wv_TVer,
                            wv_PKey,
                            wv_QPN,
                            wv_qp_state,
                            wv_PMTU,
                            wv_EPSN,
                            wv_RPSN,
                            wv_last_resp_type,
                            w_qkey_error,
                            wv_opcode,
                            w_drop_finish,
                            w_scatter_finish,
                            w_cpl_finish,
                            w_write_finish,
                            wv_pkt_len,
                            wv_MSN,
                            wv_RNR_Timer,
                            wv_RQ_PKey,
                            w_legal_access,
                            wv_RKey,
                            wv_VA,
                            wv_DMALen,
                            wv_entry_valid,
                            wv_resp_PKey,
                            wv_resp_TVer,
                            wv_resp_PC,
                            w_resp_Mig,
                            w_resp_Solicit,
                            wv_resp_OpCode,
                            wv_resp_QPN,
                            w_resp_BECN,
                            w_resp_FECN,
                            wv_resp_PSN,
                            w_resp_Acknowledge,
                            wv_resp_PMTU,
                            wv_resp_MsgSize,
                            wv_resp_MSN,
                            wv_RQ_LKey,
                            wv_QP_PD,
                            wv_CQ_PD,
                            wv_cqn,
                            w_cxt_not_full,
                            wv_MSN_Table_doutb,
                            wv_MSN_Table_doutb_fake,
							16'd0,
                            //wv_cq_offset_table_doutb,
                            wv_Entry_VA,
                            wv_Entry_Len,
                            wv_Entry_Key,
                            wv_rq_wqe_block_size,
                            wv_Stored_RKey
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
                    (dbg_sel == 107) ?   coalesced_bus[32 * 108 - 1 : 32 * 107] : 32'd0;

//assign dbg_bus = coalesced_bus;

assign init_rw_data = 'd0;

reg             [31:0]          pkt_header_cnt;
reg             [31:0]          pkt_payload_cnt;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        pkt_payload_cnt <= 'd0;
    end 
    else if(o_vtp_upload_wr_en) begin
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
    else if(o_vtp_cmd_wr_en) begin
        pkt_header_cnt <= pkt_header_cnt + 'd1;
    end 
    else begin
        pkt_header_cnt <= pkt_header_cnt;
    end 
end 

`ifdef ILA_EXECUTION_ENGINE_ON
ila_counter_probe ila_counter_probe_inst(
    .clk(clk),
    .probe0(pkt_header_cnt),
    .probe1(pkt_payload_cnt)
);
`endif

endmodule
