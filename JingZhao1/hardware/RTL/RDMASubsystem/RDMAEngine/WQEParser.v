`timescale 1ns / 1ps

`include "sw_hw_interface_const_def_h.vh"
`include "msg_def_ctxmgt_h.vh"
`include "msg_def_v2p_h.vh"
`include "ib_constant_def_h.vh"
`include "nic_hw_params.vh"
`include "chip_include_rdma.vh"

module WQEParser( //"wp" for short
    input   wire                clk,
    input   wire                rst,

//Interface with WQE Scheduler
    input   wire                i_wqe_empty,
    input   wire    [127:0]     iv_wqe_data,
    output  wire                o_wqe_rd_en,

    input   wire                i_md_from_ws_empty,
    input   wire    [255:0]     iv_md_from_ws_data,
    output  wire                o_md_from_ws_rd_en,

    input   wire                i_md_to_ws_prog_full,
    output  wire                o_md_to_ws_wr_en,
    output  wire    [255:0]     ov_md_to_ws_data,

//WQE Indicator Table
    output  wire                o_wit_wr_en,
    output  wire    [13:0]      ov_wit_wr_addr,
    output  wire    [0:0]       ov_wit_wr_data,

//DataPack
    input   wire                i_md_to_dp_prog_full,
    output  wire                o_md_to_dp_wr_en,
    //output  wire    [287:0]     ov_md_to_dp_data,
    output  wire    [367:0]     ov_md_to_dp_data,

    input   wire                i_inline_prog_full,
    output  wire                o_inline_wr_en,
    output  wire    [127:0]     ov_inline_data,

    input   wire                i_entry_prog_full,
    output  wire                o_entry_wr_en,
    output  wire    [127:0]     ov_entry_data,

    input   wire                i_atomics_prog_full,
    output  wire                o_atomics_wr_en,
    output  wire    [127:0]     ov_atomics_data,

    input   wire                i_raddr_prog_full,
    output  wire                o_raddr_wr_en,
    output  wire    [127:0]     ov_raddr_data,

//CxtMgt
    input   wire                i_cxtmgt_cmd_prog_full,
    output  wire                o_cxtmgt_cmd_wr_en,
    output  wire    [127:0]     ov_cxtmgt_cmd_data,

    input   wire                i_cxtmgt_resp_empty,
    input   wire    [127:0]     iv_cxtmgt_resp_data,
    output  wire                o_cxtmgt_resp_rd_en,

    input   wire                i_cxtmgt_cxt_empty,
    input   wire    [127:0]     iv_cxtmgt_cxt_data,
    output  wire                o_cxtmgt_cxt_rd_en,

//VirtToPhys
    //Fetch next WQE from if exists
    output  wire                o_vtp_wqe_cmd_wr_en,
    input   wire                i_vtp_wqe_cmd_prog_full,
    output  wire    [255:0]     ov_vtp_wqe_cmd_data,

    input   wire                i_vtp_wqe_resp_empty,
    output  wire                o_vtp_wqe_resp_rd_en,
    input   wire    [7:0]       iv_vtp_wqe_resp_data,

    //Fetch network data
    output  wire                o_vtp_nd_cmd_wr_en,
    input   wire                i_vtp_nd_cmd_prog_full,
    output  wire    [255:0]     ov_vtp_nd_cmd_data,

    input   wire                i_vtp_nd_resp_empty,
    output  wire                o_vtp_nd_resp_rd_en,
    input   wire    [7:0]       iv_vtp_nd_resp_data,

    input   wire    [31:0]      dbg_sel,
    output  wire    [32 - 1:0]      dbg_bus,
    //output  wire    [`DBG_NUM_WQE_PARSER * 32 - 1:0]      dbg_bus,

    output  wire                o_wp_init_finish
);

/*----------------------------------------  Part 1 Signals Definition and Submodules Connection ----------------------------------------*/
//ila_wp ila_wp (
//	.clk(clk), // input wire clk


//	.probe0(o_vtp_nd_cmd_wr_en), // input wire [0:0]  probe0  
//	.probe1(i_vtp_nd_cmd_prog_full), // input wire [0:0]  probe1 
//	.probe2(ov_vtp_nd_cmd_data), // input wire [255:0]  probe2 
//	.probe3(i_vtp_nd_resp_empty), // input wire [0:0]  probe3 
//	.probe4(o_vtp_nd_resp_rd_en), // input wire [0:0]  probe4 
//	.probe5(iv_vtp_nd_resp_data), // input wire [7:0]  probe5
//	.probe6(i_wqe_empty),
//	.probe7(o_wqe_rd_en),
//	.probe8(iv_wqe_data)
//);


wire    	            	w_inline_finish;
wire    	            	w_legal_access;      
wire    	            	w_inline_flag;
wire 		[15:0]			wv_cur_wqe_size;
wire    	[32:0]      	wv_inline_size_aligned;
wire 						w_next_stage_prog_full;
wire    	[4:0]       	wv_cur_qp_opcode;
wire    	[3:0]       	wv_cur_qp_state;
wire    	[15:0]      	wv_next_wqe_size;    //In unit of 16B
wire 		[63:0]			wv_next_wqe_addr;
wire    	[31:0]      	wv_cur_qp_pd;
wire    	[31:0]      	wv_cur_qp_lkey;
wire 		[31:0]			wv_vtp_flags;

wire        [7:0]           wv_sq_entry_size_log;
wire        [31:0]          wv_sq_length;

reg     	            	q_md_to_ws_wr_en;
reg     	[255:0]     	qv_md_to_ws_data;
reg     	            	q_wit_wr_en;
reg     	[9:0]       	qv_wit_wr_addr;
reg     	[0:0]      		qv_wit_wr_data;
reg     	            	q_md_to_dp_wr_en;
reg     	[367:0]     	qv_md_to_dp_data;
reg     	            	q_inline_wr_en;
reg     	[127:0]     	qv_inline_data;
reg     	            	q_entry_wr_en;
reg     	[127:0]     	qv_entry_data;
reg     	            	q_atomics_wr_en;
reg     	[127:0]     	qv_atomics_data;
reg     	            	q_raddr_wr_en;
reg     	[127:0]     	qv_raddr_data;
reg     	            	q_cxtmgt_wr_en;
reg     	[127:0]     	qv_cxtmgt_data;
reg     	            	q_vtp_wqe_cmd_wr_en;
reg     	[255:0]     	qv_vtp_wqe_cmd_data;
reg     	            	q_vtp_nd_cmd_wr_en;
reg     	[255:0]     	qv_vtp_nd_cmd_data;        
reg     	[6:0]       	qv_seg_counter;
reg     	[3:0]       	qv_qp_err_type;
reg     	[4:0]       	qv_cur_qp_op;
reg 		[31:0]			qv_cur_sq_length;
reg     	[23:0]      	qv_cur_qpn;
reg     	[31:0]      	qv_cur_qp_pd;
reg     	[2:0]       	qv_cur_qp_ser;  //Service Type       
reg     	[15:0]      	qv_cur_qp_PMTU;
reg 		[31:0]			qv_cur_wqe_offset;
reg 		[23:0]			qv_dst_qpn;
reg 		[31:0]			qv_cur_qp_pkey;
reg 		[31:0]			qv_cur_qp_qkey;
reg     	            	q_cur_qp_fence;
reg     	            	q_cur_qp_inline;
reg     	[31:0]      	qv_cur_qp_lkey;
reg     	[31:0]      	qv_inline_size;
reg     	[31:0]      	qv_msg_size;
reg     	            	q_zero_length_send;
reg     	[7:0]      		qv_legal_entry_num;
reg     	[31:0]      	qv_imm_data;
reg     	            	q_wqe_rd_en;
reg 		[1:0]			qv_ud_seg_counter;
reg     	[31:0]      	qv_inline_remained;
reg     	[31:0]      	qv_unwritten_len;
reg     	[127:0]     	qv_inline_pieces_data;

reg 		[31:0]			qv_dst_IP;
reg 		[47:0]			qv_dst_LID_MAC;

reg 		[3:0]			qv_mthca_mpt_flag_sw_owns;
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


assign o_md_to_ws_wr_en = q_md_to_ws_wr_en;
assign ov_md_to_ws_data = qv_md_to_ws_data;

assign o_wit_wr_en = q_wit_wr_en;
assign ov_wit_wr_addr = qv_wit_wr_addr;
assign ov_wit_wr_data = qv_wit_wr_data;

assign o_md_to_dp_wr_en = q_md_to_dp_wr_en;
assign ov_md_to_dp_data = qv_md_to_dp_data;

assign o_inline_wr_en = q_inline_wr_en;
assign ov_inline_data = qv_inline_data;

assign o_entry_wr_en = q_entry_wr_en;
assign ov_entry_data = qv_entry_data;

assign o_atomics_wr_en = q_atomics_wr_en;
assign ov_atomics_data = qv_atomics_data;

assign o_raddr_wr_en = q_raddr_wr_en;
assign ov_raddr_data = qv_raddr_data;

assign o_cxtmgt_cmd_wr_en = q_cxtmgt_wr_en;
assign ov_cxtmgt_cmd_data = qv_cxtmgt_data;

assign o_vtp_wqe_cmd_wr_en = q_vtp_wqe_cmd_wr_en;
assign ov_vtp_wqe_cmd_data = qv_vtp_wqe_cmd_data;

assign o_vtp_nd_cmd_wr_en = q_vtp_nd_cmd_wr_en;
assign ov_vtp_nd_cmd_data = qv_vtp_nd_cmd_data;


/*----------------------------------------  Part 2 State Machine Definition ----------------------------------------*/

/*------------------------------------------------------------------------------------------------------------
+                                       WQE Parsing State Machine                                           
+-------------------------------------------------------------------------------------------------------------
+ Description:  Parse WQE from previous stage, extacts differenct segments, reads data from memory, pass    
+               network data and metadata to SendRequestEngine                                              
+               Each state should be divided into fine-grained sub-stages, but to avoid state transitions,  
+               we use counters to indicate different stages.                                               
+-------------------------------------------------------------------------------------------------------------
+   PARSE_IDLE_s:           Initial state                                                                       
+   PARSE_STATE_s:          Judge QP state                                                                      
+   PARSE_NEXT_SEG_s:       Parse NextSeg, decide whether the operation is legal                                
+   PARSE_RADDR_SEG_s:      Parse RaddrSeg, extract remote key, virtual address and length                      
+   PARSE_ATOMIC_SEG_s:     Parse AtomicsSeg, extract CAS and FAD information                                   
+   PARSE_UD_SEG_s:         Extract address vector, dst qpn                                                        
+   PARSE_JUDGE_s:          Judge whether we should handle InlineSeg or DataSeg                                
+   PARSE_DATA_SEG_CMD_s:   Extract SGL entry. 
                            For Send/RDMA Write, judge if it is legal entry, and fetch data from memory; 
                            For RDMA Read, no checking and directly forward these entries.
+   PARSE_DATA_SEG_RESP_s:  For Send/RDMA Write, if response indicates an illegal entry, set QP State to Error,
                            and go to PARSE_ERR_HANDLE_s for further processing.
+   PARSE_INLINE_SEG_s:     Extract inline data
+   PARSE_ERR_HANDLE_s:     Handle three types of errors:
                            1.QP state error
                            2.Unsupported operation type
                            3.Illegal local memory access
                            Notice that we do not check if msg size exceeds the limit since it is the responsibility
                            of verbs layer.
*-----------------------------------------------------------------------------------------------------------*/


parameter       [3:0]
                PARSE_INIT_s =              4'd0,
                PARSE_IDLE_s =              4'd1,
                PARSE_STATE_s =             4'd2,
                PARSE_NEXT_SEG_s =          4'd3,
                PARSE_RADDR_SEG_s =         4'd4,
                PARSE_ATOMIC_SEG_s =        4'd5,
                PARSE_UD_SEG_s =            4'd6,          
				PARSE_INLINE_DATA_s = 		4'd7,
                PARSE_JUDGE_s =             4'd8,
                PARSE_DATA_SEG_CMD_s =      4'd9,
                PARSE_DATA_SEG_RESP_s =     4'd10,
                PARSE_FWD_DATA_SEG_s =      4'd11,
                PARSE_ERR_HANDLE_s =        4'd12,
				PARSE_HANDLE_MD_s = 		4'd13,
				PARSE_SQ_WRAP_s =			4'd14;

reg             [13:0]          qv_init_counter;

reg             [3:0]           Parse_cur_state;
reg             [3:0]           Parse_next_state;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        Parse_cur_state <= PARSE_INIT_s;
    end
    else begin
        Parse_cur_state <= Parse_next_state;
    end
end

wire 	w_sq_wrap_around;
assign w_sq_wrap_around = ((wv_next_wqe_addr << 4) + (wv_next_wqe_size << 4)) > wv_sq_length;

always @(*) begin
    case(Parse_cur_state)
        PARSE_INIT_s:           if(qv_init_counter == `QP_NUM - 1) begin
                                    Parse_next_state = PARSE_IDLE_s;
                                end
                                else begin
                                    Parse_next_state = PARSE_INIT_s;
                                end
        PARSE_IDLE_s:           if(!i_wqe_empty && !i_md_from_ws_empty && !i_cxtmgt_cmd_prog_full && !w_next_stage_prog_full) begin 
									if(wv_next_wqe_size != 0 && !w_sq_wrap_around && !i_vtp_wqe_cmd_prog_full && !i_md_to_ws_prog_full) begin 
										Parse_next_state = PARSE_STATE_s;
									end 
									else if(wv_next_wqe_size != 0 && w_sq_wrap_around && !i_vtp_wqe_cmd_prog_full && !i_md_to_ws_prog_full) begin
										Parse_next_state = PARSE_SQ_WRAP_s;	
									end 
									else if(wv_next_wqe_size == 0) begin 
										Parse_next_state = PARSE_STATE_s;
									end 
									else begin 
										Parse_next_state = PARSE_IDLE_s;
									end 
								end 
                                else begin
                                    Parse_next_state = PARSE_IDLE_s;
                                end
		PARSE_SQ_WRAP_s:		if(!i_vtp_wqe_cmd_prog_full && !i_md_to_ws_prog_full) begin
									Parse_next_state = PARSE_STATE_s;
								end 
								else begin
									Parse_next_state = PARSE_SQ_WRAP_s;
								end
        PARSE_STATE_s:          if(!i_cxtmgt_resp_empty) begin          //Wait for CxtMgt state back
                                    if((wv_cur_qp_state == `QP_SQE) || (wv_cur_qp_state == `QP_ERR)) begin
                                        Parse_next_state = PARSE_ERR_HANDLE_s;
                                    end
                                    else begin
                                        Parse_next_state = PARSE_NEXT_SEG_s;
                                    end
                                end
                                else begin
                                    Parse_next_state = PARSE_STATE_s;
                                end
        PARSE_NEXT_SEG_s:       if(wv_cur_qp_opcode == `VERBS_SEND || wv_cur_qp_opcode == `VERBS_SEND_WITH_IMM) begin 
									if(qv_cur_qp_ser == `UD) begin 
										Parse_next_state = PARSE_UD_SEG_s;
									end 
									else if(q_zero_length_send) begin 
										Parse_next_state = PARSE_HANDLE_MD_s;
									end 
									else begin 
										Parse_next_state = PARSE_JUDGE_s;	
									end 
								end
								else if(wv_cur_qp_opcode == `VERBS_RDMA_WRITE || wv_cur_qp_opcode == `VERBS_RDMA_WRITE_WITH_IMM || wv_cur_qp_opcode == `VERBS_RDMA_READ
									|| wv_cur_qp_opcode == `VERBS_CMP_AND_SWAP || wv_cur_qp_opcode == `VERBS_FETCH_AND_ADD) begin 
									Parse_next_state = PARSE_RADDR_SEG_s; 
								end 
								else begin 
									Parse_next_state = PARSE_ERR_HANDLE_s;
								end 
        PARSE_RADDR_SEG_s:      if(!i_wqe_empty && !i_raddr_prog_full) begin 
									if(qv_cur_qp_op == `VERBS_CMP_AND_SWAP || qv_cur_qp_op == `VERBS_FETCH_AND_ADD) begin
                            	        Parse_next_state = PARSE_ATOMIC_SEG_s;
                            	    end
                            	    else if(qv_cur_qp_op == `VERBS_RDMA_READ) begin
                            	        Parse_next_state = PARSE_FWD_DATA_SEG_s;
                            	    end
                            	    else begin	//For RDMA Write, judge whether data is inlined
                            	        Parse_next_state = PARSE_JUDGE_s;
                            	    end
								end 
								else begin 
									Parse_next_state = PARSE_RADDR_SEG_s;
								end 
        PARSE_ATOMIC_SEG_s:     if(!i_wqe_empty && !i_atomics_prog_full) begin             //Atomic Operation need to parse atomics seg
                                    Parse_next_state = PARSE_HANDLE_MD_s;
                                end
                                else begin
                                    Parse_next_state = PARSE_ATOMIC_SEG_s;
                                end
        PARSE_UD_SEG_s:         if(!i_wqe_empty && qv_ud_seg_counter == 1) begin
                                    Parse_next_state = PARSE_JUDGE_s;
                                end
                                else begin
                                    Parse_next_state = PARSE_UD_SEG_s;
                                end
        PARSE_FWD_DATA_SEG_s:   if(qv_seg_counter == 1) begin
                                    if(!i_wqe_empty && !i_entry_prog_full) begin
                                        Parse_next_state = PARSE_HANDLE_MD_s;
                                    end
                                    else begin
                                        Parse_next_state = PARSE_FWD_DATA_SEG_s;
                                    end
                                end
                                else begin
                                    Parse_next_state = PARSE_FWD_DATA_SEG_s;
                                end
        PARSE_JUDGE_s:          if(!i_wqe_empty && w_inline_flag && !w_next_stage_prog_full) begin                     //Inline data
                                    Parse_next_state = PARSE_INLINE_DATA_s;
                                end
                                else if(!i_wqe_empty && !w_inline_flag) begin                                  //SGL data
                                    Parse_next_state = PARSE_DATA_SEG_CMD_s;
                                end
								else begin 
									Parse_next_state = PARSE_JUDGE_s;
								end 
        PARSE_INLINE_DATA_s:    if(w_inline_finish) begin
                                    Parse_next_state = PARSE_IDLE_s;    
								end 
                               	else begin
                                    Parse_next_state = PARSE_INLINE_DATA_s;
                                end
        PARSE_DATA_SEG_CMD_s:   if(!i_wqe_empty && !i_vtp_nd_cmd_prog_full) begin  
									if(qv_cur_qp_op == `VERBS_SEND || qv_cur_qp_op == `VERBS_SEND_WITH_IMM || qv_cur_qp_op == `VERBS_RDMA_WRITE ||
                                    	qv_cur_qp_op == `VERBS_RDMA_WRITE_WITH_IMM) begin
                                        Parse_next_state = PARSE_DATA_SEG_RESP_s;
                               	 	end
									else begin 
										Parse_next_state = PARSE_ERR_HANDLE_s;
									end 
								end 
                                else begin
                                    Parse_next_state = PARSE_DATA_SEG_CMD_s;
                                end
        PARSE_DATA_SEG_RESP_s:  if(!i_vtp_nd_resp_empty && !i_entry_prog_full) begin
                                    if(w_legal_access) begin
                                        if(qv_seg_counter == 1) begin
                                        	Parse_next_state = PARSE_HANDLE_MD_s;
                                        end
                                        else begin
                                            Parse_next_state = PARSE_DATA_SEG_CMD_s;
                                        end
                                    end
                                    else begin
                                        Parse_next_state = PARSE_ERR_HANDLE_s;
                                    end
                                end
                                else begin
                                    Parse_next_state = PARSE_DATA_SEG_RESP_s;
                                end
        PARSE_ERR_HANDLE_s:     if((qv_qp_err_type == `QP_STATE_ERR) || (qv_qp_err_type == `QP_OPCODE_ERR)) begin    //State error or unsupported operation, flush this WQE from FIFO, only metadata forwarded   
                                    if(qv_seg_counter == 1 && !i_wqe_empty) begin           
										Parse_next_state = PARSE_HANDLE_MD_s;
                                    end
                                    else begin
                                        Parse_next_state = PARSE_ERR_HANDLE_s;
                                    end
                                end 
                                else if(qv_qp_err_type == `QP_LOCAL_ACCESS_ERR) begin   //Illegal Local Memory Access
                                    if(qv_seg_counter == 1 && !i_wqe_empty) begin
										Parse_next_state = PARSE_HANDLE_MD_s;
                                    end
                                    else begin
                                        Parse_next_state = PARSE_ERR_HANDLE_s;
                                    end
                                end
                                else begin
                                    Parse_next_state = PARSE_IDLE_s;
                                end	
		PARSE_HANDLE_MD_s:		if(!i_md_from_ws_empty && !w_next_stage_prog_full) begin 
									Parse_next_state = PARSE_IDLE_s;
								end 
								else begin 
									Parse_next_state = PARSE_HANDLE_MD_s;
								end 
        default:                Parse_next_state = PARSE_IDLE_s;
    endcase 
end

/*----------------------------------------  Part 3 Registers Decode ----------------------------------------*/
//-- qv_init_counter --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_init_counter <= 'd0;        
    end
    else if (Parse_cur_state == PARSE_INIT_s && qv_init_counter < `QP_NUM - 1) begin
        qv_init_counter <= qv_init_counter + 1;
    end
    else begin
        qv_init_counter <= qv_init_counter;
    end
end


assign w_inline_flag = iv_wqe_data[31]; 
// assign wv_cur_qp_state = iv_cxtmgt_resp_data[31:29];
assign wv_cur_qp_state = iv_cxtmgt_cxt_data[31:29];
assign wv_cur_qp_opcode = iv_md_from_ws_data[4:0];
assign wv_next_wqe_size = iv_wqe_data[37:32];		//16B Aligned
assign wv_next_wqe_addr = iv_wqe_data[31:6];
assign wv_cur_qp_pd = iv_md_from_ws_data[95:64];
assign wv_cur_qp_lkey = iv_md_from_ws_data[127:96];

assign w_next_stage_prog_full = (i_md_to_dp_prog_full || i_raddr_prog_full || i_atomics_prog_full || i_md_to_ws_prog_full);

assign wv_inline_size_aligned = iv_wqe_data[30:0];

assign wv_sq_entry_size_log = iv_cxtmgt_cxt_data[7:0];
assign wv_sq_length = iv_md_from_ws_data[223:192];


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
    else if (Parse_cur_state == PARSE_IDLE_s && wv_next_wqe_size != 0) begin
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
    else if (Parse_cur_state == PARSE_SQ_WRAP_s) begin
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
    else if (Parse_cur_state == PARSE_DATA_SEG_CMD_s && qv_cur_qp_op != `VERBS_RDMA_READ && !i_vtp_nd_cmd_prog_full) begin
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

reg 	[31:0]			qv_imm_data_TempReg;
always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_imm_data_TempReg <= 'd0;
	end 
	else begin
		qv_imm_data_TempReg <= qv_imm_data;
	end 
end 

//-- qv_imm_data --
always @(*) begin
    if (rst) begin
        qv_imm_data = 32'h0;       
    end
    else if (Parse_cur_state == PARSE_NEXT_SEG_s) begin
        qv_imm_data = iv_wqe_data[127:96];
    end
    else begin
        qv_imm_data = qv_imm_data_TempReg;
    end
end

//-- qv_dst_IP --
//-- qv_dst_LID_MAC --
always @(posedge clk or posedge rst) begin
 	if(rst) begin
		qv_dst_IP <= 'd0;
		qv_dst_LID_MAC <= 'd0;
	end 
	else if(Parse_cur_state == PARSE_IDLE_s) begin
		qv_dst_IP <= 'd0;
		qv_dst_LID_MAC <= 'd0;
	end 
	else if(Parse_cur_state == PARSE_UD_SEG_s && qv_ud_seg_counter == 3 && !i_wqe_empty) begin
		qv_dst_IP <= qv_dst_IP;
		qv_dst_LID_MAC <= {iv_wqe_data[127:96], iv_wqe_data[63:48]};
	end 
	else if(Parse_cur_state == PARSE_UD_SEG_s && qv_ud_seg_counter == 2 && !i_wqe_empty) begin
		qv_dst_IP <= iv_wqe_data[63:32];
		qv_dst_LID_MAC <= qv_dst_LID_MAC;
	end 
	else begin
		qv_dst_IP <= qv_dst_IP;
		qv_dst_LID_MAC <= qv_dst_LID_MAC;
	end 
end

//-- qv_cur_qp_op --
//-- qv_cur_qpn --
//-- qv_cur_qp_pd --
//-- qv_cur_qp_ser --
//-- qv_cur_qp_PMTU --
//-- qv_dst_qpn --
//-- qv_cur_qp_pkey --
//-- qv_cur_qp_qkey --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_cur_qp_op <= 0;
        q_cur_qp_fence <= 0;
        qv_cur_qp_ser <= 0;
        qv_cur_qpn <= 0;
        qv_cur_qp_pd <= 0;
        qv_cur_qp_lkey <= 0;
        qv_cur_qp_PMTU <= 0;     
		qv_dst_qpn <= 'd0;
		qv_cur_qp_pkey <= 'd0;
		qv_cur_qp_qkey <= 'd0;
		qv_cur_sq_length <= 'd0;
		qv_cur_wqe_offset <= 'd0;
    end
    else if (Parse_cur_state == PARSE_IDLE_s) begin
        qv_cur_qp_op <= iv_md_from_ws_data[4:0];
        q_cur_qp_fence <= iv_md_from_ws_data[5];
        qv_cur_qp_ser <= iv_md_from_ws_data[7:6];
        qv_cur_qpn <= iv_md_from_ws_data[31:8];
        qv_cur_qp_pd <= iv_md_from_ws_data[95:64];
        qv_cur_qp_lkey <= iv_md_from_ws_data[128:96];
        qv_cur_qp_PMTU <= iv_md_from_ws_data[191:176];         
		qv_dst_qpn <= iv_md_from_ws_data[63:40];
		qv_cur_qp_pkey <= iv_md_from_ws_data[159:128];
		qv_cur_qp_qkey <= 'd0;
		qv_cur_sq_length <= iv_md_from_ws_data[223:192];
		qv_cur_wqe_offset <= iv_md_from_ws_data[255:224];
    end
    else if (Parse_cur_state == PARSE_SQ_WRAP_s) begin
        qv_cur_qp_op <= iv_md_from_ws_data[4:0];
        q_cur_qp_fence <= iv_md_from_ws_data[5];
        qv_cur_qp_ser <= iv_md_from_ws_data[7:6];
        qv_cur_qpn <= iv_md_from_ws_data[31:8];
        qv_cur_qp_pd <= iv_md_from_ws_data[95:64];
        qv_cur_qp_lkey <= iv_md_from_ws_data[128:96];
        qv_cur_qp_PMTU <= iv_md_from_ws_data[191:176];         
		qv_dst_qpn <= iv_md_from_ws_data[63:40];
		qv_cur_qp_pkey <= iv_md_from_ws_data[159:128];
		qv_cur_qp_qkey <= 'd0;
		qv_cur_sq_length <= iv_md_from_ws_data[223:192];
		qv_cur_wqe_offset <= iv_md_from_ws_data[255:224];
    end
	else if (Parse_cur_state == PARSE_UD_SEG_s && qv_ud_seg_counter == 1 && !i_wqe_empty) begin 
        qv_cur_qp_op <= qv_cur_qp_op;
        q_cur_qp_fence <= q_cur_qp_fence;
        qv_cur_qp_ser <= qv_cur_qp_ser;
        qv_cur_qpn <= qv_cur_qpn;
        qv_cur_qp_pd <= qv_cur_qp_pd;
        qv_cur_qp_lkey <= qv_cur_qp_lkey;
        qv_cur_qp_PMTU <= qv_cur_qp_PMTU;
		qv_dst_qpn <= iv_wqe_data[31:0];
		qv_cur_qp_pkey <= qv_cur_qp_pkey;
		qv_cur_qp_qkey <= iv_wqe_data[63:32];
		qv_cur_sq_length <= iv_md_from_ws_data[223:192];
		qv_cur_wqe_offset <= iv_md_from_ws_data[255:224];
	end 
    else begin
        qv_cur_qp_op <= qv_cur_qp_op;
        q_cur_qp_fence <= q_cur_qp_fence;
        qv_cur_qp_ser <= qv_cur_qp_ser;
        qv_cur_qpn <= qv_cur_qpn;
        qv_cur_qp_pd <= qv_cur_qp_pd;
        qv_cur_qp_lkey <= qv_cur_qp_lkey;
        qv_cur_qp_PMTU <= qv_cur_qp_PMTU;
		qv_dst_qpn <= qv_dst_qpn;
		qv_cur_qp_pkey <= qv_cur_qp_pkey;
		qv_cur_qp_qkey <= qv_cur_qp_qkey;
		qv_cur_sq_length <= qv_cur_sq_length;
		qv_cur_wqe_offset <= qv_cur_wqe_offset;
    end
end

//-- q_zero_length_send --   //Indicates whether this send is zero-length, Send with Imm can carry zero payload
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_zero_length_send <= 1'b0;  
    end
    else if (Parse_cur_state == PARSE_STATE_s && Parse_next_state == PARSE_NEXT_SEG_s) begin
        if(qv_cur_qp_ser == `RC || qv_cur_qp_ser == `UC) begin
            if(qv_seg_counter == 1) begin		//Only has NextSeg
                q_zero_length_send <= 1'b1;			
            end
            else begin
                q_zero_length_send <= 1'b0;
            end
        end
        else if(qv_cur_qp_ser == `UD) begin
            if(qv_seg_counter == 4) begin 		//Only has NextSeg and UDSeg
                q_zero_length_send <= 1'b1;
            end
            else begin
                q_zero_length_send <= 1'b0;
            end
        end
        else begin
            q_zero_length_send <= 1'b0;
        end
    end
    else begin
        q_zero_length_send <= 1'b0;
    end
end

//-- qv_ud_seg_counter --
always @(posedge clk or posedge rst) begin 
	if(rst) begin 
		qv_ud_seg_counter <= 'd0;		
	end 
	else if(Parse_cur_state == PARSE_NEXT_SEG_s && Parse_next_state == PARSE_UD_SEG_s) begin 
		qv_ud_seg_counter <= 'd3;
	end 
	else if(Parse_cur_state == PARSE_UD_SEG_s && !i_wqe_empty) begin 
		qv_ud_seg_counter <= qv_ud_seg_counter - 1;
	end 
	else begin 
		qv_ud_seg_counter <= qv_ud_seg_counter;
	end 
end 

//-- q_md_to_ws_wr_en --
//-- qv_md_to_ws_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_md_to_ws_wr_en <= 1'b0;       
        qv_md_to_ws_data <= 64'h0;
    end
    else if (Parse_cur_state == PARSE_IDLE_s && Parse_next_state == PARSE_STATE_s && wv_next_wqe_size != 0 && !i_md_to_ws_prog_full && !i_vtp_wqe_cmd_prog_full) begin
        q_md_to_ws_wr_en <= 1'b1;			//Forward metadata for next WQE
        //qv_md_to_ws_data <= {iv_md_from_ws_data[255:192], iv_md_from_ws_data[191:176], 10'd0, iv_wqe_data[37:32], iv_md_from_ws_data[159:6], iv_wqe_data[38], iv_wqe_data[4:0]};
        qv_md_to_ws_data <= {iv_wqe_data[31:6], 4'd0, iv_md_from_ws_data[223:192], iv_md_from_ws_data[191:176], 10'd0, iv_wqe_data[37:32], iv_md_from_ws_data[159:6], iv_wqe_data[38], iv_wqe_data[4:0]};
    end
    else if (Parse_cur_state == PARSE_SQ_WRAP_s && Parse_next_state == PARSE_STATE_s && wv_next_wqe_size != 0 && !i_md_to_ws_prog_full && !i_vtp_wqe_cmd_prog_full) begin
        q_md_to_ws_wr_en <= 1'b1;			//Forward metadata for next WQE
        //qv_md_to_ws_data <= {iv_md_from_ws_data[255:192], iv_md_from_ws_data[191:176], 10'd0, iv_wqe_data[37:32], iv_md_from_ws_data[159:6], iv_wqe_data[38], iv_wqe_data[4:0]};
        qv_md_to_ws_data <= {iv_wqe_data[31:6], 4'd0, iv_md_from_ws_data[223:192], iv_md_from_ws_data[191:176], 10'd0, iv_wqe_data[37:32], iv_md_from_ws_data[159:6], iv_wqe_data[38], iv_wqe_data[4:0]};
    end
    else begin
        q_md_to_ws_wr_en <= 1'b0;
        qv_md_to_ws_data <= qv_md_to_ws_data;
    end
end

//-- q_wit_wr_en --
//-- qv_wit_wr_addr --
//-- qv_wit_wr_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_wit_wr_en <= 0;
        qv_wit_wr_addr <= 0;
        qv_wit_wr_data <= 0;        
    end
    else if (Parse_cur_state == PARSE_INIT_s) begin
        q_wit_wr_en <= 1'b1;
        qv_wit_wr_addr <= qv_init_counter;
        qv_wit_wr_data <= 'd0;
    end
    else if (Parse_cur_state == PARSE_IDLE_s && Parse_next_state == PARSE_STATE_s) begin
        if(wv_next_wqe_size != 0) begin
            q_wit_wr_en <= 1'b1;
            qv_wit_wr_addr <= iv_md_from_ws_data[17:8];     //Use lower 10-bit of QPN as WIT index
            qv_wit_wr_data <= 1'b1; 		//Set
        end
        else begin
            q_wit_wr_en <= 1'b1;
            qv_wit_wr_addr <= iv_md_from_ws_data[17:8];
            qv_wit_wr_data <= 1'b0;  		//Clear
        end
    end
    else if (Parse_cur_state == PARSE_SQ_WRAP_s && Parse_next_state == PARSE_STATE_s) begin
        if(wv_next_wqe_size != 0) begin
            q_wit_wr_en <= 1'b1;
            qv_wit_wr_addr <= iv_md_from_ws_data[17:8];     //Use lower 10-bit of QPN as WIT index
            qv_wit_wr_data <= 1'b1; 		//Set
        end
        else begin
            q_wit_wr_en <= 1'b1;
            qv_wit_wr_addr <= iv_md_from_ws_data[17:8];
            qv_wit_wr_data <= 1'b0;  		//Clear
        end
    end
    else begin
        q_wit_wr_en <= 0;
        qv_wit_wr_addr <= 0;
        qv_wit_wr_data <= 0; 
    end
end

//-- qv_qp_err_type --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_qp_err_type <= 0;        
    end
    else if (Parse_cur_state == PARSE_STATE_s && (wv_cur_qp_state == `QP_SQE || wv_cur_qp_state == `QP_ERR)) begin
        qv_qp_err_type <= `QP_STATE_ERR;
    end
    else if (Parse_cur_state == PARSE_NEXT_SEG_s) begin
        if(qv_cur_qp_ser == `UC) begin
            if(qv_cur_qp_op == `VERBS_RDMA_READ || qv_cur_qp_op == `VERBS_FETCH_AND_ADD || qv_cur_qp_op == `VERBS_CMP_AND_SWAP) begin
                qv_qp_err_type <= `QP_OPCODE_ERR;
            end
            else begin
                qv_qp_err_type <= `QP_NORMAL;
            end
        end
        else if(qv_cur_qp_ser == `UD) begin
            if(qv_cur_qp_op != `VERBS_SEND && qv_cur_qp_op != `VERBS_SEND_WITH_IMM) begin
                qv_qp_err_type <= `QP_OPCODE_ERR;
            end
            else begin
                qv_qp_err_type <= `QP_NORMAL;
            end
        end
        else begin
            qv_qp_err_type <= `QP_NORMAL;
        end
    end
	else if(Parse_cur_state == PARSE_DATA_SEG_RESP_s && !i_vtp_nd_resp_empty) begin 
		if(!w_legal_access) begin 
			qv_qp_err_type <= `QP_LOCAL_ACCESS_ERR;
		end
		else begin 
			qv_qp_err_type <= `QP_NORMAL;
		end  	
	end 
    else begin
        qv_qp_err_type <= qv_qp_err_type;
    end
end

//-- q_cxtmgt_wr_en --
//-- qv_cxtmgt_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_cxtmgt_wr_en <= 0;
        qv_cxtmgt_data <= 0;        
    end
    else if (Parse_cur_state == PARSE_IDLE_s && Parse_next_state == PARSE_STATE_s) begin    //Obtain QP State
        q_cxtmgt_wr_en <= 1;
        qv_cxtmgt_data <= {`RD_QP_CTX, `RD_QP_STATE, iv_md_from_ws_data[31:8], 96'h0};        
    end
    else if (Parse_cur_state == PARSE_IDLE_s && Parse_next_state == PARSE_SQ_WRAP_s) begin    //Obtain QP State
        q_cxtmgt_wr_en <= 1;
        qv_cxtmgt_data <= {`RD_QP_CTX, `RD_QP_STATE, iv_md_from_ws_data[31:8], 96'h0};        
    end
    else begin
        q_cxtmgt_wr_en <= 0;
        qv_cxtmgt_data <= qv_cxtmgt_data;
    end
end


//-- qv_msg_size -- //For RDMA Read and Atomics, msg_size is zero
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_msg_size <= 0;        
    end
	else if (Parse_cur_state == PARSE_IDLE_s) begin 
		qv_msg_size <= 'd0;
	end 
    else if (Parse_cur_state == PARSE_JUDGE_s && w_inline_flag) begin
        qv_msg_size <= iv_wqe_data[30:0];
    end
	else if(Parse_cur_state == PARSE_FWD_DATA_SEG_s && !i_wqe_empty && !i_entry_prog_full) begin 
		qv_msg_size <= qv_msg_size + iv_wqe_data[31:0];
	end 
    else if (Parse_cur_state == PARSE_DATA_SEG_CMD_s && Parse_next_state == PARSE_DATA_SEG_RESP_s) begin
        qv_msg_size <= qv_msg_size + iv_wqe_data[31:0];
    end
    else begin
        qv_msg_size <= qv_msg_size;
    end
end

/*
-----------------------------------------
|               InlineData              |
-----------------------------------------
|               InlineData              |
-----------------------------------------
|        InlineData         | InlineSeg |
-----------------------------------------
*/
//-- qv_unwritten_len -- This is much simpler than Scatter Data :)
always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_unwritten_len <= 'd0;
	end 
	else if(Parse_cur_state == PARSE_JUDGE_s && Parse_next_state == PARSE_INLINE_DATA_s) begin
		if(iv_wqe_data[30:0] <= 12) begin
			qv_unwritten_len <= iv_wqe_data[30:0];
		end 
		else begin
			qv_unwritten_len <= 'd12;
		end 
	end 
	else if(Parse_cur_state == PARSE_INLINE_DATA_s) begin
		if(qv_unwritten_len + qv_inline_remained <= 16) begin
			if(qv_inline_remained == 0 && !i_inline_prog_full) begin
				qv_unwritten_len <= 'd0;
			end 
			else if(qv_inline_remained > 0 && !i_wqe_empty && !i_inline_prog_full) begin
				qv_unwritten_len <= 'd0;
			end 
			else begin
				qv_unwritten_len <= qv_unwritten_len;
			end 
		end
		else begin
			if(qv_inline_remained > 16) begin
				qv_unwritten_len <= qv_unwritten_len; 	//Actually 'd12
			end 	
			else if(qv_inline_remained <= 16 && !i_wqe_empty && !i_inline_prog_full) begin
				qv_unwritten_len <= qv_inline_remained - (16 - qv_unwritten_len); 	//Actually (qv_inline_remained - 4)
			end 
			else begin
				qv_unwritten_len <= qv_unwritten_len;
			end 
		end  
	end 
	else begin
		qv_unwritten_len <= qv_unwritten_len;
	end 	
end 

//-- qv_inline_remained --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_inline_remained <= 0;        
    end
    else if (Parse_cur_state == PARSE_JUDGE_s && Parse_next_state == PARSE_INLINE_DATA_s) begin
		if(iv_wqe_data[30:0] <= 12) begin 
			qv_inline_remained <= 'd0;
		end 
		else begin
			qv_inline_remained <= iv_wqe_data[30:0] - 'd12;
		end 
    end
    else if (Parse_cur_state == PARSE_INLINE_DATA_s) begin 
		if(qv_inline_remained + qv_unwritten_len <= 16) begin 
			if(!i_wqe_empty && !i_inline_prog_full) begin
				qv_inline_remained <= 'd0;
			end 
			else begin
 				qv_inline_remained <= qv_inline_remained;
			end
		end 
		else begin
			if(q_wqe_rd_en) begin
				if(qv_inline_remained <= 16) begin
					qv_inline_remained <= 'd0;
				end 
				else begin
					qv_inline_remained <= qv_inline_remained - 16;
				end 
			end 
			else begin
				qv_inline_remained <= qv_inline_remained;
			end 
		end 
    end
    else begin
        qv_inline_remained <= qv_inline_remained;
    end
end

reg 	[31:0]			qv_inline_size_TempReg;
always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_inline_size_TempReg <= 'd0;
	end 
	else begin
		qv_inline_size_TempReg <= qv_inline_size;
	end 
end 

//-- qv_inline_size --
always @(*) begin
    if (rst) begin
        qv_inline_size = 'd0;    
    end
    else if (Parse_cur_state == PARSE_JUDGE_s && Parse_next_state == PARSE_INLINE_DATA_s) begin
        qv_inline_size = iv_wqe_data[30:0];
    end
    else begin
        qv_inline_size = qv_inline_size_TempReg;
    end
end

//-- qv_inline_pieces_data -- Since inline data is not aligned to 16B, we need to piece these data together
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_inline_pieces_data <= 0;        
    end
	else if(Parse_cur_state == PARSE_JUDGE_s && Parse_next_state == PARSE_INLINE_DATA_s) begin 
		qv_inline_pieces_data <= iv_wqe_data[127:32];
	end 
    else if (Parse_cur_state == PARSE_INLINE_DATA_s) begin
		if((qv_inline_remained + qv_unwritten_len > 16) && !i_wqe_empty && !i_inline_prog_full) begin
			qv_inline_pieces_data <= iv_wqe_data[127:32];
		end 
		else begin
			qv_inline_pieces_data <= qv_inline_pieces_data;
		end 
    end
    else begin
        qv_inline_pieces_data <= qv_inline_pieces_data;
    end
end

//-- q_inline_wr_en --
//-- qv_inline_data --
always @(posedge clk or posedge rst) begin 
	if(rst) begin 
		q_inline_wr_en <= 1'b0;
		qv_inline_data <= 'd0;
	end
	else if(Parse_cur_state == PARSE_INLINE_DATA_s) begin 
		if(qv_inline_remained + qv_unwritten_len <= 16) begin
			if(qv_inline_remained == 0 && !i_inline_prog_full) begin
				q_inline_wr_en <= 'd1;
				qv_inline_data <= qv_inline_pieces_data;
			end 
			else if(qv_inline_remained > 0 && !i_wqe_empty && !i_inline_prog_full) begin
				q_inline_wr_en <= 'd1;
				qv_inline_data <= {iv_wqe_data[31:0], qv_inline_pieces_data[95:0]};
			end 
			else begin
				q_inline_wr_en <= 'd0;
				qv_inline_data <= qv_inline_data;
 			end 
		end 	
		else begin
			if(!i_wqe_empty && !i_inline_prog_full) begin
				q_inline_wr_en <= 'd1;
				qv_inline_data <= {iv_wqe_data[31:0], qv_inline_pieces_data[95:0]};
			end 
			else begin
				q_inline_wr_en <= 'd0;
				qv_inline_data <= qv_inline_data;
			end 
		end 
	end  
	else begin 
		q_inline_wr_en <= 1'b0;
		qv_inline_data <= qv_inline_data;
	end 
end 

//assign w_inline_finish = !i_inline_prog_full && ((qv_inline_remained <= 12) || (qv_inline_remained > 12 && qv_inline_remained <= 16 && !i_wqe_empty));
assign w_inline_finish = (qv_inline_remained == 0 && !i_inline_prog_full) || 
							( (qv_inline_remained + qv_unwritten_len <= 16) && qv_inline_remained > 0 && !i_wqe_empty && !i_inline_prog_full); 

//-- q_entry_wr_en --
//-- qv_entry_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_entry_wr_en <= 1'b0;
        qv_entry_data <= 0;    
    end
	else if (Parse_cur_state == PARSE_FWD_DATA_SEG_s && !i_wqe_empty && !i_entry_prog_full) begin 
		q_entry_wr_en <= 1'b1;
		qv_entry_data <= iv_wqe_data;	
	end 
    else if (Parse_cur_state == PARSE_DATA_SEG_RESP_s && !i_vtp_nd_resp_empty && w_legal_access && !i_entry_prog_full) begin
	    q_entry_wr_en <= 1'b1;
	    qv_entry_data <= iv_wqe_data;
    end
	else begin
		q_entry_wr_en <= 1'b0;
		qv_entry_data <= qv_entry_data;
	end 
end

assign w_legal_access = (iv_vtp_nd_resp_data[7:0] == `SUCCESS);

//-- qv_legal_entry_num -- 
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_legal_entry_num <= 0;         
    end
    else if (Parse_cur_state == PARSE_STATE_s) begin
        qv_legal_entry_num <= 0;
    end
	else if(Parse_cur_state == PARSE_FWD_DATA_SEG_s && !i_wqe_empty && !i_entry_prog_full) begin
		qv_legal_entry_num <= qv_legal_entry_num + 1;
 	end 
    else if (Parse_cur_state == PARSE_DATA_SEG_RESP_s && !i_vtp_nd_resp_empty && w_legal_access &&!i_entry_prog_full) begin
        qv_legal_entry_num <= qv_legal_entry_num + 1;
    end
    else begin
        qv_legal_entry_num <= qv_legal_entry_num;
    end
end

//-- q_vtp_wqe_cmd_wr_en --
//-- qv_vtp_wqe_cmd_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_vtp_wqe_cmd_wr_en <= 1'b0;
        qv_vtp_wqe_cmd_data <= 0;        
    end
    else if (Parse_cur_state == PARSE_IDLE_s && wv_next_wqe_size != 0 && Parse_next_state == PARSE_STATE_s) begin
        q_vtp_wqe_cmd_wr_en <= 1'b1;
        //qv_vtp_wqe_cmd_data <= {`RD_REQ_WQE, `RD_SQ_TWQE, 32'hFFFF, wv_cur_qp_pd, wv_cur_qp_lkey, 64'h00000000, wv_next_wqe_size << 16};
        qv_vtp_wqe_cmd_data <= {32'd0, 16'd0, wv_next_wqe_size << 4, wv_next_wqe_addr << 4, wv_cur_qp_lkey, wv_cur_qp_pd, wv_vtp_flags, 24'd0, `RD_SQ_FWQE, `RD_REQ_WQE};
    end
    else if (Parse_cur_state == PARSE_IDLE_s && wv_next_wqe_size != 0 && Parse_next_state == PARSE_SQ_WRAP_s) begin
        q_vtp_wqe_cmd_wr_en <= 1'b1;
        //qv_vtp_wqe_cmd_data <= {`RD_REQ_WQE, `RD_SQ_TWQE, 32'hFFFF, wv_cur_qp_pd, wv_cur_qp_lkey, 64'h00000000, wv_next_wqe_size << 16};
        qv_vtp_wqe_cmd_data <= {32'd0, 16'd0, (wv_sq_length - (wv_next_wqe_addr << 4)), wv_next_wqe_addr << 4, wv_cur_qp_lkey, wv_cur_qp_pd, wv_vtp_flags, 24'd0, `RD_SQ_FWQE, `RD_REQ_WQE};
    end
    else if (Parse_cur_state == PARSE_SQ_WRAP_s && wv_next_wqe_size != 0 && Parse_next_state == PARSE_STATE_s) begin
        q_vtp_wqe_cmd_wr_en <= 1'b1;
        //qv_vtp_wqe_cmd_data <= {`RD_REQ_WQE, `RD_SQ_TWQE, 32'hFFFF, wv_cur_qp_pd, wv_cur_qp_lkey, 64'h00000000, wv_next_wqe_size << 16};
        qv_vtp_wqe_cmd_data <= {32'd0, 16'd0, (wv_next_wqe_size << 4) - (wv_sq_length - (wv_next_wqe_addr << 4)), 64'd0, wv_cur_qp_lkey, wv_cur_qp_pd, wv_vtp_flags, 24'd0, `RD_SQ_FWQE, `RD_REQ_WQE};
    end
    else begin
        q_vtp_wqe_cmd_wr_en <= 1'b0;
        qv_vtp_wqe_cmd_data <= 0;
    end
end

//-- q_vtp_nd_cmd_wr_en --
//-- qv_vtp_nd_cmd_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_vtp_nd_cmd_wr_en <= 1'b0;
        qv_vtp_nd_cmd_data <= 0;        
    end
    else if (Parse_cur_state == PARSE_DATA_SEG_CMD_s && qv_cur_qp_op != `VERBS_RDMA_READ && !i_vtp_nd_cmd_prog_full && !i_wqe_empty) begin
        q_vtp_nd_cmd_wr_en <= 1'b1;
        //qv_vtp_nd_cmd_data <= {`RD_REQ_DATA, `RD_L_NET_DATA, 32'h0000, qv_cur_qp_pd, iv_wqe_data[63:32], iv_wqe_data[127:64], iv_wqe_data[31:0]};
        qv_vtp_nd_cmd_data <= {32'd0, iv_wqe_data[31:0], iv_wqe_data[127:64], iv_wqe_data[63:32], qv_cur_qp_pd, wv_vtp_flags, 24'd0, `RD_L_NET_DATA, `RD_REQ_DATA};
    end
    else begin
        q_vtp_nd_cmd_wr_en <= 1'b0;
        qv_vtp_nd_cmd_data <= qv_vtp_nd_cmd_data;
    end
end

assign wv_cur_wqe_size = iv_md_from_ws_data[175:160];
//-- qv_seg_counter --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_seg_counter <= 0;        
    end
    else if (Parse_cur_state == PARSE_IDLE_s && !i_wqe_empty) begin
        qv_seg_counter <= wv_cur_wqe_size; 	//wv_cur_wqe_size is in unit of 16B
    end
    else if (o_wqe_rd_en) begin
        qv_seg_counter <= qv_seg_counter - 1;
    end
    else begin
        qv_seg_counter <= qv_seg_counter;
    end
end

/*  Metadata forwarded

-----------------------------------------------------------------
|       +3      |       +2      |       +1      |       +0      |
-----------------------------------------------------------------
|7|6|5|4|3|2|1|0|7|6|5|4|3|2|1|0|7|6|5|4|3|2|1|0|7|6|5|4|3|2|1|0|
-----------------------------------------------------------------
|     PMTU      | LegalEntryNum |QPState| Flags |  ST | Opcode  |
-----------------------------------------------------------------
|                             srcQPN            |     PMTU      |
-----------------------------------------------------------------
|                             dstQPN            |   Reserved_1  |
-----------------------------------------------------------------
|                             MsgSize                           |
-----------------------------------------------------------------
|                             qkey                              |
-----------------------------------------------------------------
|                             PD                                |
-----------------------------------------------------------------
|                             Imm                               |
-----------------------------------------------------------------

ST:                 Service Type
LegalEntryNum:      Legal SGL entry in the request
Flags:              [0]     Fence
                    [1]     Inline
                    [2~3]   Reserved   
*/


//-- q_md_to_dp_wr_en --
//-- qv_md_to_dp_data --
//TODO: Metadata format should be reconstructed!    For UD, dstQP is obtained via UDSeg, For RC/UC, dstQP is obtained via QPContext
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_md_to_dp_wr_en <= 1'b0;
        qv_md_to_dp_data <= 0;        
    end
    else if (Parse_cur_state == PARSE_HANDLE_MD_s && !w_next_stage_prog_full) begin
        q_md_to_dp_wr_en <= 1'b1;
        qv_md_to_dp_data <= {qv_dst_LID_MAC, qv_dst_IP, qv_cur_wqe_offset, qv_imm_data, qv_cur_qp_pkey, qv_cur_qp_pd, qv_cur_qp_qkey, 	qv_msg_size,	8'd0, qv_dst_qpn, qv_cur_qpn, qv_cur_qp_PMTU, 
							qv_legal_entry_num, qv_qp_err_type, 2'b00, 		q_cur_qp_inline, 		q_cur_qp_fence, qv_cur_qp_ser, qv_cur_qp_op};
    end
    else if (Parse_cur_state == PARSE_JUDGE_s && w_inline_flag && !w_next_stage_prog_full) begin
        q_md_to_dp_wr_en <= 1'b1;
        qv_md_to_dp_data <= {qv_dst_LID_MAC, qv_dst_IP, qv_cur_wqe_offset, qv_imm_data, qv_cur_qp_pkey, qv_cur_qp_pd, qv_cur_qp_qkey, 	qv_inline_size, 8'd0, qv_dst_qpn, qv_cur_qpn, qv_cur_qp_PMTU,
							qv_legal_entry_num, qv_qp_err_type, 2'b00, 		w_inline_flag, 			q_cur_qp_fence, qv_cur_qp_ser, qv_cur_qp_op};
    end
    else begin
        q_md_to_dp_wr_en <= 1'b0;
        qv_md_to_dp_data <= 0;
    end
end

//-- q_cur_qp_inline --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_cur_qp_inline <= 1'b0;        
    end
    else if (Parse_cur_state == PARSE_JUDGE_s && !i_wqe_empty && w_inline_flag) begin
        q_cur_qp_inline <= 1'b1;
    end
    else begin
        q_cur_qp_inline <= 1'b0;
    end
end

//-- q_atomics_wr_en --
//-- qv_atomics_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_atomics_wr_en <= 1'b0;
        qv_atomics_data <= 0;         
    end
    else if (Parse_cur_state == PARSE_ATOMIC_SEG_s && !i_wqe_empty) begin
        q_atomics_wr_en <= 1'b0;
        qv_atomics_data <= iv_wqe_data;
    end
	else if (Parse_next_state == PARSE_HANDLE_MD_s && qv_qp_err_type == `QP_NORMAL && !w_next_stage_prog_full && (qv_cur_qp_op == `VERBS_FETCH_AND_ADD || qv_cur_qp_op == `VERBS_CMP_AND_SWAP)) begin 
		q_atomics_wr_en <= 1'b1;
		qv_atomics_data <= qv_atomics_data;
	end 
    else begin
        q_atomics_wr_en <= 1'b0;
        qv_atomics_data <= qv_atomics_data;
    end
end

//-- q_raddr_wr_en --
//-- qv_raddr_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_raddr_wr_en <= 1'b0;
        qv_raddr_data <= 0;
    end
	else if (Parse_cur_state == PARSE_RADDR_SEG_s && !i_wqe_empty) begin 
		q_raddr_wr_en <= 1'b0;
		qv_raddr_data <= iv_wqe_data;
	end 
    else if (Parse_cur_state == PARSE_JUDGE_s && w_inline_flag && qv_qp_err_type == `QP_NORMAL && !w_next_stage_prog_full && (qv_cur_qp_op == `VERBS_RDMA_WRITE || qv_cur_qp_op == `VERBS_RDMA_WRITE_WITH_IMM)) begin 	
        q_raddr_wr_en <= 1'b1;
        qv_raddr_data <= qv_raddr_data;
    end
    else if (Parse_cur_state == PARSE_HANDLE_MD_s && qv_qp_err_type == `QP_NORMAL && !w_next_stage_prog_full && (qv_cur_qp_op == `VERBS_RDMA_WRITE || qv_cur_qp_op == `VERBS_RDMA_WRITE_WITH_IMM || qv_cur_qp_op == `VERBS_RDMA_READ || qv_cur_qp_op == `VERBS_FETCH_AND_ADD || qv_cur_qp_op == `VERBS_CMP_AND_SWAP)) begin 	
        q_raddr_wr_en <= 1'b1;
        qv_raddr_data <= qv_raddr_data;
    end
    else begin
        q_raddr_wr_en <= 1'b0;
        qv_raddr_data <= qv_raddr_data;
    end
end

//-- q_wqe_rd_en --
always @(*) begin
    case(Parse_cur_state)
        PARSE_NEXT_SEG_s:       q_wqe_rd_en = !i_wqe_empty;
		PARSE_UD_SEG_s:			q_wqe_rd_en = !i_wqe_empty;
        PARSE_RADDR_SEG_s:      q_wqe_rd_en = !i_wqe_empty && !i_raddr_prog_full;
        PARSE_ATOMIC_SEG_s:     q_wqe_rd_en = !i_wqe_empty && !i_atomics_prog_full;
        PARSE_DATA_SEG_RESP_s:  q_wqe_rd_en = !i_vtp_nd_resp_empty && !i_entry_prog_full;
        PARSE_FWD_DATA_SEG_s:   q_wqe_rd_en = !i_wqe_empty && !i_entry_prog_full;
    //    PARSE_INLINE_DATA_s:    if(qv_inline_remained <= 12) begin 
	//								q_wqe_rd_en = 1'b0;
	//							end 
	//							else if(qv_inline_remained > 12 && !i_wqe_empty && !i_inline_prog_full) begin 
	//								q_wqe_rd_en = 1'b1;
	//							end 
	//							else begin 
	//								q_wqe_rd_en = 1'b0;
	//							end 
		PARSE_JUDGE_s:			if(w_inline_flag && !i_wqe_empty && !w_next_stage_prog_full) begin 
									q_wqe_rd_en = 1'b1;
								end 
								else begin
									q_wqe_rd_en = 1'b0;
 								end 
		PARSE_INLINE_DATA_s:	if(qv_inline_remained > 0 && !i_wqe_empty && !i_inline_prog_full) begin
									q_wqe_rd_en = 1'b1;
								end 
								else begin
									q_wqe_rd_en = 1'b0;
								end 
        PARSE_ERR_HANDLE_s:     q_wqe_rd_en = !i_wqe_empty;
        default:                q_wqe_rd_en = 1'b0;
    endcase
end

assign o_md_from_ws_rd_en = ((Parse_cur_state == PARSE_HANDLE_MD_s) && !w_next_stage_prog_full) || (Parse_cur_state == PARSE_JUDGE_s && !i_wqe_empty && w_inline_flag && !w_next_stage_prog_full);

//assign o_cxtmgt_resp_rd_en = (Parse_cur_state == PARSE_HANDLE_MD_s) && !w_next_stage_prog_full;
//assign o_cxtmgt_cxt_rd_en = (Parse_cur_state == PARSE_HANDLE_MD_s) && !w_next_stage_prog_full;
assign o_cxtmgt_resp_rd_en = ((Parse_cur_state == PARSE_HANDLE_MD_s) && !w_next_stage_prog_full) || (Parse_cur_state == PARSE_JUDGE_s && !i_wqe_empty && w_inline_flag && !w_next_stage_prog_full);

assign o_cxtmgt_cxt_rd_en = ((Parse_cur_state == PARSE_HANDLE_MD_s) && !w_next_stage_prog_full) || (Parse_cur_state == PARSE_JUDGE_s && !i_wqe_empty && w_inline_flag && !w_next_stage_prog_full);

assign o_vtp_nd_resp_rd_en = (Parse_cur_state == PARSE_DATA_SEG_RESP_s) && !i_vtp_nd_resp_empty && !i_entry_prog_full;

assign o_vtp_wqe_resp_rd_en = !i_vtp_wqe_resp_empty;        //Each wqe read is valid


assign o_wqe_rd_en = q_wqe_rd_en;

assign o_wp_init_finish = (qv_init_counter == `QP_NUM - 1);

//Connect dbg signals
wire   [`DBG_NUM_WQE_PARSER * 32 - 1 : 0]   coalesced_bus;
assign coalesced_bus = {
                            w_inline_finish,
                            w_legal_access,
                            w_inline_flag,
                            w_next_stage_prog_full,
                            q_md_to_dp_wr_en,
                            q_inline_wr_en,
                            q_entry_wr_en,
                            q_atomics_wr_en,
                            q_raddr_wr_en,
                            q_cxtmgt_wr_en,
                            q_vtp_wqe_cmd_wr_en,
                            q_vtp_nd_cmd_wr_en,
                            q_wqe_rd_en,
                            q_cur_qp_fence,
                            q_cur_qp_inline,
                            q_zero_length_send,
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
                            q_md_to_ws_wr_en,
                            q_wit_wr_en,
                            Parse_cur_state,
                            Parse_next_state,
                            wv_cur_wqe_size,
                            wv_inline_size_aligned,
                            wv_cur_qp_opcode,
                            wv_cur_qp_state,
                            wv_next_wqe_size,
                            wv_next_wqe_addr,
                            wv_cur_qp_pd,
                            wv_cur_qp_lkey,
                            wv_vtp_flags,
                            wv_sq_entry_size_log,
                            wv_sq_length,
                            qv_md_to_ws_data,
                            qv_wit_wr_addr,
                            qv_wit_wr_data,
                            qv_md_to_dp_data,
                            qv_inline_data,
                            qv_entry_data,
                            qv_atomics_data,
                            qv_raddr_data,
                            qv_cxtmgt_data,
                            qv_vtp_wqe_cmd_data,
                            qv_vtp_nd_cmd_data,
                            qv_seg_counter,
                            qv_qp_err_type,
                            qv_cur_qp_op,
                            qv_cur_sq_length,
                            qv_cur_qpn,
                            qv_cur_qp_pd,
                            qv_cur_qp_ser,
                            qv_cur_qp_PMTU,
                            qv_cur_wqe_offset,
                            qv_dst_qpn,
                            qv_cur_qp_pkey,
                            qv_cur_qp_qkey,
                            qv_cur_qp_lkey,
                            qv_inline_size,
                            qv_msg_size,
                            qv_legal_entry_num,
                            qv_imm_data,
                            qv_ud_seg_counter,
                            qv_inline_remained,
                            qv_unwritten_len,
                            qv_inline_pieces_data,
                            qv_dst_IP,
                            qv_dst_LID_MAC,
                            qv_mthca_mpt_flag_sw_owns
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
                    (dbg_sel == 86) ?   coalesced_bus[32 * 87 - 1 : 32 * 86] : 32'd0;

//assign dbg_bus = coalesced_bus;

endmodule
										



