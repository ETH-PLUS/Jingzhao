`timescale 1ns / 1ps

`include "sw_hw_interface_const_def_h.vh"
`include "msg_def_ctxmgt_h.vh"
`include "msg_def_v2p_h.vh"
`include "ib_constant_def_h.vh"
`include "chip_include_rdma.vh"

module DataPack
(    //"dp" for short
    input   wire                clk,
    input   wire                rst,

//Interface with WQEParser
    input   wire                i_md_from_wp_empty,
    output  wire                o_md_from_wp_rd_en,
    //input   wire    [287:0]     iv_md_from_wp_data,
    input   wire    [367:0]     iv_md_from_wp_data,

    input   wire                i_inline_empty,
    output  wire                o_inline_rd_en,
    input   wire    [127:0]     iv_inline_data,

    //SGL Entry
    //WQE Parser should forward the source SGL entry to DataPack
    //For Send and Recv, these entries are used to pack data
    //For RDMA Read, these entries are used to scatter response data
    input   wire                i_entry_from_wp_empty,
    output  wire                o_entry_from_wp_rd_en,
    input   wire    [127:0]     iv_entry_from_wp_data,

    input   wire                i_atomics_from_wp_empty,
    output  wire                o_atomics_from_wp_rd_en,
    input   wire    [127:0]     iv_atomics_from_wp_data,

    input   wire                i_raddr_from_wp_empty,
    output  wire                o_raddr_from_wp_rd_en,
    input   wire    [127:0]     iv_raddr_from_wp_data,

//VirtToPhys
    input   wire                i_nd_empty,
    output  wire                o_nd_rd_en,
    input   wire    [255:0]     iv_nd_data,

//RequesterEngine
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
    output  wire    [367:0]     ov_md_to_re_data,

    input   wire    [31:0]      dbg_sel,
    output  wire    [32 - 1: 0]      dbg_bus
//    output  wire    [`DBG_NUM_DATA_PACK * 32 - 1: 0]      dbg_bus
);

/*----------------------------------------  Part 1 Signals Definition and Submodules Connection ----------------------------------------*/
wire        [4:0]           wv_cur_op;
wire                        w_inline_flag;
wire                        w_zero_msg_size;
wire        [31:0]          wv_msg_size;
wire        [3:0]           wv_cur_err_type;
wire        [7:0]           wv_legal_entry_num;
wire                        w_next_stage_prog_full;
wire 		[31:0]			wv_inline_count;

reg                         q_md_from_wp_rd_en;
reg                         q_inline_rd_en;
reg                         q_atomics_from_wp_rd_en;
reg                         q_addr_from_wp_rd_en;
reg                         q_entry_from_wp_rd_en;
reg                         q_nd_rd_en;
reg                         q_entry_to_re_wr_en;
reg         [127:0]         qv_entry_to_re_data;
reg                         q_atomics_to_re_wr_en;
reg         [127:0]         qv_atomics_to_re_data;
reg                         q_raddr_to_re_wr_en;
reg         [127:0]         qv_raddr_to_re_data;
reg                         q_nd_to_re_wr_en;
reg         [255:0]         qv_nd_to_re_data;
reg                         q_md_to_re_wr_en;
reg         [367:0]         qv_md_to_re_data;
reg         [4:0]           qv_cur_op;
reg         [31:0]          qv_inline_count;
reg                         q_inline_odd;         
reg         [31:0]          qv_cur_entry_remained_len;
reg         [31:0]          qv_unwritten_len;
reg         [255:0]         qv_unwritten_data;
reg         [7:0]           qv_sgl_entry_count;
//For debug 
reg 	[31:0]		qv_DebugCounter_entry_rd_en;
reg 	[31:0]		qv_DebugCounter_entry_wr_en;


assign o_md_from_wp_rd_en = q_md_from_wp_rd_en;
assign o_inline_rd_en = q_inline_rd_en;
assign o_atomics_from_wp_rd_en = q_atomics_from_wp_rd_en;
assign o_raddr_from_wp_rd_en = q_addr_from_wp_rd_en;
assign o_entry_from_wp_rd_en = q_entry_from_wp_rd_en;
assign o_nd_rd_en = q_nd_rd_en;

assign o_entry_to_re_wr_en = q_entry_to_re_wr_en;
assign ov_entry_to_re_data = qv_entry_to_re_data;
  
assign o_atomics_to_re_wr_en = q_atomics_to_re_wr_en;
assign ov_atomics_to_re_data = qv_atomics_to_re_data;

assign o_raddr_to_re_wr_en = q_raddr_to_re_wr_en;
assign ov_raddr_to_re_data = qv_raddr_to_re_data;

assign o_nd_to_re_wr_en = q_nd_to_re_wr_en;
assign ov_nd_to_re_data = qv_nd_to_re_data;

assign o_md_to_re_wr_en = q_md_to_re_wr_en;
assign ov_md_to_re_data = qv_md_to_re_data;


/*--------------------------------------------------  Part 2 State Machine Definition --------------------------------------------------*/

/*------------------------------------------------------------------------------------------------------------
+                                       WQE Parsing State Machine                                           
+-------------------------------------------------------------------------------------------------------------
+ Description:  Parse WQE from previous stage, extacts differenct segments, reads data from memory, pass    
+               network data and metadata to SendRequestEngine                                              
+               Each state should be divided into fine-grained sub-stages, but to avoid state transitions,  
+               we use counters to indicate different stages.                                               
+-------------------------------------------------------------------------------------------------------------
+   PACK_IDLE_s:            Initial state, if there is state transition, forward metadata to SRE and forward raddr, atomics info to SRE if needed                                                                       
+   PACK_INLINE_DATA_s:     Handle Inline data of Send/RDMA Write
+   PACK_FWD_MD_s:          Forward metadata, raddr and atomics
+   PACK_FWD_ENTRY_s:       Forward RDMA Read SGL entry
+   PACK_SGL_MD_s:          Handle SGL Entry, prepare for next data gather
+   PACK_SGL_TRANS_s:       Piece SGL data together
+   PACK_FLUSH_DATA_s:      For Send/RDMA Write with illegal SGL entry, flush data that has been successfully read from memory

    For Atomics, Send with Zero-Payload, QP_OPCODE_ERR and QP_STATE_ERR, they just need one cycle to forward the information, 
    to reduce latency, we handle them in IDLE state
*-----------------------------------------------------------------------------------------------------------*/

parameter           [4:0]
                    PACK_IDLE_s =           5'd1,
                    PACK_FWD_MD_s =         5'd2,
                    PACK_FWD_ENTRY_s =      5'd3,
                    PACK_INLINE_DATA_s =    5'd4,
                    PACK_SGL_MD_s =         5'd5,
                    PACK_SGL_TRANS_s =      5'd6,
                    PACK_FLUSH_MD_s =       5'd7,
                    PACK_FLUSH_DATA_s =     5'd8;

reg                 [5:0]   Pack_cur_state;
reg                 [5:0]   Pack_next_state;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        Pack_cur_state <= PACK_IDLE_s;            
    end
    else begin
        Pack_cur_state <= Pack_next_state;
    end
end

always @(*) begin
    case(Pack_cur_state) 
        PACK_IDLE_s:            if(!i_md_from_wp_empty) begin 
                                    Pack_next_state = PACK_FWD_MD_s;
                                end 
                                else begin 
                                    Pack_next_state = PACK_IDLE_s;
                                end 
        PACK_FWD_MD_s:          if(!w_next_stage_prog_full) begin 
                                    if(wv_cur_err_type == `QP_NORMAL) begin 
                                        if(wv_cur_op == `VERBS_SEND || wv_cur_op == `VERBS_SEND_WITH_IMM) begin 
                                            if(w_zero_msg_size) begin 
                                                Pack_next_state = PACK_IDLE_s;
                                            end 
                                            else if(!w_zero_msg_size && w_inline_flag) begin 
                                                Pack_next_state = PACK_INLINE_DATA_s;
                                            end
                                            else begin
                                                Pack_next_state = PACK_SGL_MD_s;
                                            end
                                        end 
                                        else if(wv_cur_op == `VERBS_RDMA_WRITE || wv_cur_op == `VERBS_RDMA_WRITE_WITH_IMM) begin
                                            if(w_inline_flag && !i_raddr_from_wp_empty) begin 
                                                Pack_next_state = PACK_INLINE_DATA_s;
                                            end 
                                            else if(!w_inline_flag && !i_raddr_from_wp_empty) begin 
                                                Pack_next_state = PACK_SGL_MD_s;
                                            end 
                                            else begin
                                                Pack_next_state = PACK_FWD_MD_s;                                                
                                            end
                                        end
                                        else if(wv_cur_op == `VERBS_RDMA_READ) begin 
                                            if(!i_raddr_from_wp_empty) begin 
                                                Pack_next_state = PACK_FWD_ENTRY_s;
                                            end
                                            else begin
                                                Pack_next_state = PACK_FWD_MD_s;
                                            end
                                        end 
                                        else if(wv_cur_op == `VERBS_FETCH_AND_ADD || wv_cur_op == `VERBS_CMP_AND_SWAP) begin 
                                            if(!i_raddr_from_wp_empty && !i_atomics_from_wp_empty) begin 
                                                Pack_next_state = PACK_IDLE_s;
                                            end 
                                            else begin 
                                                Pack_next_state = PACK_FWD_MD_s;
                                            end 
                                        end 
                                        else begin      //Unknown opcode
                                            Pack_next_state = PACK_IDLE_s;
                                        end 
                                    end 
                                    else if(wv_cur_err_type == `QP_LOCAL_ACCESS_ERR) begin 
                                        if(wv_legal_entry_num == 0) begin 
                                            Pack_next_state = PACK_IDLE_s;
                                        end 
                                        else begin
                                            Pack_next_state = PACK_FLUSH_MD_s;
                                        end
                                    end 
                                    else if(wv_cur_err_type == `QP_STATE_ERR || wv_cur_err_type == `QP_OPCODE_ERR) begin 
                                        Pack_next_state = PACK_IDLE_s;
                                    end 
                                    else begin 
                                        Pack_next_state = PACK_IDLE_s;
                                    end 
								end 
                                else begin 
                                    Pack_next_state = PACK_IDLE_s;
                                end 
        PACK_FWD_ENTRY_s:       if(qv_sgl_entry_count == 1 && !i_entry_from_wp_empty && !i_entry_to_re_prog_full) begin 
                                    Pack_next_state = PACK_IDLE_s;                                        
                                end 
                                else begin
                                    Pack_next_state = PACK_FWD_ENTRY_s;                                    
                                end
        PACK_INLINE_DATA_s:     if(qv_inline_count == 1 && !i_inline_empty && !w_next_stage_prog_full) begin 
                                    Pack_next_state = PACK_IDLE_s;
                                end 
                                else begin
                                    Pack_next_state = PACK_INLINE_DATA_s;
                                end
        PACK_SGL_MD_s:          if(!i_entry_from_wp_empty) begin 
                                    Pack_next_state = PACK_SGL_TRANS_s;
                                end 
                                else begin 
                                    Pack_next_state = PACK_SGL_MD_s;
                                end 
        PACK_SGL_TRANS_s:       if(qv_sgl_entry_count == 1) begin  
                                    //if(qv_cur_entry_remained_len == 0 && !w_next_stage_prog_full) begin    //This is a corner case, we do not need to consider i_nd_empty signal
                                    if(qv_cur_entry_remained_len == 0 && !i_nd_to_re_prog_full) begin    //This is a corner case, we do not need to consider i_nd_empty signal
                                        Pack_next_state = PACK_IDLE_s;
                                    end
                                    //else if((qv_cur_entry_remained_len + qv_unwritten_len <= 32) && !i_nd_empty && !w_next_stage_prog_full) begin
                                    else if((qv_cur_entry_remained_len + qv_unwritten_len <= 32) && !i_nd_empty && !i_nd_to_re_prog_full) begin
                                        Pack_next_state = PACK_IDLE_s;
                                    end
                                    else begin
                                        Pack_next_state = PACK_SGL_TRANS_s;
                                    end
                                end 
                                else begin
                                    if((qv_cur_entry_remained_len <= 32) && !i_nd_empty && !i_nd_to_re_prog_full) begin
                                        Pack_next_state = PACK_SGL_MD_s;    //Need next SGL data to piece 32B together                                        
                                    end
                                    else begin
                                        Pack_next_state = PACK_SGL_TRANS_s;
                                    end
                                end
        PACK_FLUSH_MD_s:        if(!i_entry_from_wp_empty && !i_nd_empty) begin
                                    Pack_next_state = PACK_FLUSH_DATA_s;
                                end
                                else begin
                                    Pack_next_state = PACK_FLUSH_MD_s;
                                end
        PACK_FLUSH_DATA_s:      if(qv_cur_entry_remained_len <= 32 && !i_entry_from_wp_empty && !i_nd_empty) begin
                                    if(qv_sgl_entry_count == 1) begin
                                        Pack_next_state = PACK_IDLE_s;
                                    end
                                    else begin
                                        Pack_next_state = PACK_FLUSH_MD_s;
                                    end
                                end
                                else begin
                                    Pack_next_state = PACK_FLUSH_DATA_s;
                                end
        default:                Pack_next_state = PACK_IDLE_s;
    endcase 
end


/*------------------------------------------------------  Part 3 Signals Decode ------------------------------------------------------*/
//-- w_next_stage_prog_full -- Simplify coding
assign w_next_stage_prog_full = (i_md_to_re_prog_full || i_nd_to_re_prog_full || i_atomics_to_re_prog_full || i_entry_to_re_prog_full || i_raddr_to_re_prog_full);

//-- wv_cur_op --
assign wv_cur_op = iv_md_from_wp_data[4:0];

//-- w_inline_flag --   1:  current network data comes from inline fifo
//                      0:  current network data comes from sgl data fifo
assign w_inline_flag = iv_md_from_wp_data[9];

//-- w_zero_msg_size -- 1:  current send carries immediate data only, no payload
//                      0:  current send carries payload
assign w_zero_msg_size = (iv_md_from_wp_data[127:96] == 0);

//-- wv_msg_size -- 
assign wv_msg_size = iv_md_from_wp_data[127:96];

//-- wv_cur_err_type --
assign wv_cur_err_type = iv_md_from_wp_data[15:12];

//--wv_legal_entry_num --   Indicates numbers of entries in this request
//                          For RDMA Read, these entries are directly forwrded to SRE
//                          For Send/RDMA Write, these entries indicate successfully-read data(if these is illegal local memory access, these entries are used to flush 
//                          already-read data)
assign wv_legal_entry_num = iv_md_from_wp_data[23:16];

//-- qv_inline_count -- Indicates how many 16B segs of inline data are un-processed
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_inline_count <= 'd0;        
    end
    else if (Pack_cur_state == PACK_FWD_MD_s && w_inline_flag) begin
        qv_inline_count <= (wv_msg_size[3:0] > 0) ? ((wv_msg_size >> 4) + 1) : (wv_msg_size >> 4);
    end
    else if (Pack_cur_state == PACK_INLINE_DATA_s && !i_inline_empty && !w_next_stage_prog_full) begin 
        qv_inline_count <= qv_inline_count - 1;
    end 
    else begin
        qv_inline_count <= qv_inline_count;
    end
end

assign wv_inline_count = (wv_msg_size[3:0] > 0) ? ((wv_msg_size >> 4) + 1) : (wv_msg_size >> 4);

//-- q_inline_odd -- Indicates whether the total number of inline segs is odd
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_inline_odd <= 'd0;
    end
    else if (Pack_cur_state == PACK_FWD_MD_s && w_inline_flag) begin
        q_inline_odd <= wv_inline_count[0];
    end
    else begin 
        q_inline_odd <= q_inline_odd;
    end 
end

//-- q_nd_to_re_wr_en --
//-- qv_nd_to_re_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_nd_to_re_wr_en <= 'd0;
        qv_nd_to_re_data <= 'd0;        
    end
    else if (Pack_cur_state == PACK_INLINE_DATA_s && !i_inline_empty && !w_next_stage_prog_full) begin
        if(qv_inline_count == 1) begin      //Last piece of inline data
            if(q_inline_odd) begin 
                q_nd_to_re_wr_en <= 'd1;
                qv_nd_to_re_data <= {128'd0, iv_inline_data};
            end 
            else begin
                q_nd_to_re_wr_en <= 'd1;
                qv_nd_to_re_data <= {iv_inline_data, qv_nd_to_re_data[127:0]};
            end
        end 
        else begin
            if((q_inline_odd && qv_inline_count[0]) || (!q_inline_odd && !qv_inline_count[0]))  begin
                q_nd_to_re_wr_en <= 'd0;
                qv_nd_to_re_data <= {128'd0, iv_inline_data};
            end
            else if((q_inline_odd && !qv_inline_count[0]) || (!q_inline_odd && qv_inline_count[0]))  begin
                q_nd_to_re_wr_en <= 'd1;
                qv_nd_to_re_data <= {iv_inline_data, qv_nd_to_re_data[127:0]};
            end
            else begin
                q_nd_to_re_wr_en <= 'd0;
                qv_nd_to_re_data <= qv_nd_to_re_data;
            end
        end
    end
    else if(Pack_cur_state == PACK_SGL_TRANS_s && qv_sgl_entry_count == 1 && !i_nd_to_re_prog_full) begin 
        if(qv_cur_entry_remained_len == 0) begin
            q_nd_to_re_wr_en <= 'd1;    //Write in
            qv_nd_to_re_data <= qv_unwritten_data;
        end
        else if(!i_nd_empty) begin
            q_nd_to_re_wr_en <= 'd1;
            case(qv_unwritten_len) 
                    0:      qv_nd_to_re_data <= iv_nd_data;
                    1:      qv_nd_to_re_data <= {iv_nd_data[31 * 8 - 1:0], qv_unwritten_data[1 * 8 - 1:0]};
                    2:      qv_nd_to_re_data <= {iv_nd_data[30 * 8 - 1:0], qv_unwritten_data[2 * 8 - 1:0]};
                    3:      qv_nd_to_re_data <= {iv_nd_data[29 * 8 - 1:0], qv_unwritten_data[3 * 8 - 1:0]};
                    4:      qv_nd_to_re_data <= {iv_nd_data[28 * 8 - 1:0], qv_unwritten_data[4 * 8 - 1:0]};
                    5:      qv_nd_to_re_data <= {iv_nd_data[27 * 8 - 1:0], qv_unwritten_data[5 * 8 - 1:0]};
                    6:      qv_nd_to_re_data <= {iv_nd_data[26 * 8 - 1:0], qv_unwritten_data[6 * 8 - 1:0]};
                    7:      qv_nd_to_re_data <= {iv_nd_data[25 * 8 - 1:0], qv_unwritten_data[7 * 8 - 1:0]};
                    8:      qv_nd_to_re_data <= {iv_nd_data[24 * 8 - 1:0], qv_unwritten_data[8 * 8 - 1:0]};
                    9:      qv_nd_to_re_data <= {iv_nd_data[23 * 8 - 1:0], qv_unwritten_data[9 * 8 - 1:0]};
                    10:     qv_nd_to_re_data <= {iv_nd_data[22 * 8 - 1:0], qv_unwritten_data[10 * 8 - 1:0]};
                    11:     qv_nd_to_re_data <= {iv_nd_data[21 * 8 - 1:0], qv_unwritten_data[11 * 8 - 1:0]};
                    12:     qv_nd_to_re_data <= {iv_nd_data[20 * 8 - 1:0], qv_unwritten_data[12 * 8 - 1:0]};
                    13:     qv_nd_to_re_data <= {iv_nd_data[19 * 8 - 1:0], qv_unwritten_data[13 * 8 - 1:0]};
                    14:     qv_nd_to_re_data <= {iv_nd_data[18 * 8 - 1:0], qv_unwritten_data[14 * 8 - 1:0]};
                    15:     qv_nd_to_re_data <= {iv_nd_data[17 * 8 - 1:0], qv_unwritten_data[15 * 8 - 1:0]};
                    16:     qv_nd_to_re_data <= {iv_nd_data[16 * 8 - 1:0], qv_unwritten_data[16 * 8 - 1:0]};
                    17:     qv_nd_to_re_data <= {iv_nd_data[15 * 8 - 1:0], qv_unwritten_data[17 * 8 - 1:0]};
                    18:     qv_nd_to_re_data <= {iv_nd_data[14 * 8 - 1:0], qv_unwritten_data[18 * 8 - 1:0]};
                    19:     qv_nd_to_re_data <= {iv_nd_data[13 * 8 - 1:0], qv_unwritten_data[19 * 8 - 1:0]};
                    20:     qv_nd_to_re_data <= {iv_nd_data[12 * 8 - 1:0], qv_unwritten_data[20 * 8 - 1:0]};
                    21:     qv_nd_to_re_data <= {iv_nd_data[11 * 8 - 1:0], qv_unwritten_data[21 * 8 - 1:0]};
                    22:     qv_nd_to_re_data <= {iv_nd_data[10 * 8 - 1:0], qv_unwritten_data[22 * 8 - 1:0]};
                    23:     qv_nd_to_re_data <= {iv_nd_data[9 * 8 - 1:0], qv_unwritten_data[23 * 8 - 1:0]};
                    24:     qv_nd_to_re_data <= {iv_nd_data[8 * 8 - 1:0], qv_unwritten_data[24 * 8 - 1:0]};
                    25:     qv_nd_to_re_data <= {iv_nd_data[7 * 8 - 1:0], qv_unwritten_data[25 * 8 - 1:0]};
                    26:     qv_nd_to_re_data <= {iv_nd_data[6 * 8 - 1:0], qv_unwritten_data[26 * 8 - 1:0]};
                    27:     qv_nd_to_re_data <= {iv_nd_data[5 * 8 - 1:0], qv_unwritten_data[27 * 8 - 1:0]};
                    28:     qv_nd_to_re_data <= {iv_nd_data[4 * 8 - 1:0], qv_unwritten_data[28 * 8 - 1:0]};
                    29:     qv_nd_to_re_data <= {iv_nd_data[3 * 8 - 1:0], qv_unwritten_data[29 * 8 - 1:0]};
                    30:     qv_nd_to_re_data <= {iv_nd_data[2 * 8 - 1:0], qv_unwritten_data[30 * 8 - 1:0]};
                    31:     qv_nd_to_re_data <= {iv_nd_data[1 * 8 - 1:0], qv_unwritten_data[31 * 8 - 1:0]};
                    default:qv_nd_to_re_data <= qv_nd_to_re_data;    
            endcase
        end
        else begin
            q_nd_to_re_wr_en <= 'd0;
            qv_nd_to_re_data <= qv_nd_to_re_data;
        end
    end 
    else if(Pack_cur_state == PACK_SGL_TRANS_s && qv_sgl_entry_count > 1 && !i_nd_to_re_prog_full) begin 
        if(qv_cur_entry_remained_len == 0) begin
            q_nd_to_re_wr_en <= 'd0;    //Don't write in, wait for next piece of data
            qv_nd_to_re_data <= qv_nd_to_re_data;
        end       
        else if(!i_nd_empty) begin
            if(qv_cur_entry_remained_len + qv_unwritten_len >= 32) begin
                q_nd_to_re_wr_en <= 'd1;
                case(qv_unwritten_len) 
                        0:      qv_nd_to_re_data <= iv_nd_data;
                        1:      qv_nd_to_re_data <= {iv_nd_data[31 * 8 - 1:0], qv_unwritten_data[1 * 8 - 1:0]};
                        2:      qv_nd_to_re_data <= {iv_nd_data[30 * 8 - 1:0], qv_unwritten_data[2 * 8 - 1:0]};
                        3:      qv_nd_to_re_data <= {iv_nd_data[29 * 8 - 1:0], qv_unwritten_data[3 * 8 - 1:0]};
                        4:      qv_nd_to_re_data <= {iv_nd_data[28 * 8 - 1:0], qv_unwritten_data[4 * 8 - 1:0]};
                        5:      qv_nd_to_re_data <= {iv_nd_data[27 * 8 - 1:0], qv_unwritten_data[5 * 8 - 1:0]};
                        6:      qv_nd_to_re_data <= {iv_nd_data[26 * 8 - 1:0], qv_unwritten_data[6 * 8 - 1:0]};
                        7:      qv_nd_to_re_data <= {iv_nd_data[25 * 8 - 1:0], qv_unwritten_data[7 * 8 - 1:0]};
                        8:      qv_nd_to_re_data <= {iv_nd_data[24 * 8 - 1:0], qv_unwritten_data[8 * 8 - 1:0]};
                        9:      qv_nd_to_re_data <= {iv_nd_data[23 * 8 - 1:0], qv_unwritten_data[9 * 8 - 1:0]};
                        10:     qv_nd_to_re_data <= {iv_nd_data[22 * 8 - 1:0], qv_unwritten_data[10 * 8 - 1:0]};
                        11:     qv_nd_to_re_data <= {iv_nd_data[21 * 8 - 1:0], qv_unwritten_data[11 * 8 - 1:0]};
                        12:     qv_nd_to_re_data <= {iv_nd_data[20 * 8 - 1:0], qv_unwritten_data[12 * 8 - 1:0]};
                        13:     qv_nd_to_re_data <= {iv_nd_data[19 * 8 - 1:0], qv_unwritten_data[13 * 8 - 1:0]};
                        14:     qv_nd_to_re_data <= {iv_nd_data[18 * 8 - 1:0], qv_unwritten_data[14 * 8 - 1:0]};
                        15:     qv_nd_to_re_data <= {iv_nd_data[17 * 8 - 1:0], qv_unwritten_data[15 * 8 - 1:0]};
                        16:     qv_nd_to_re_data <= {iv_nd_data[16 * 8 - 1:0], qv_unwritten_data[16 * 8 - 1:0]};
                        17:     qv_nd_to_re_data <= {iv_nd_data[15 * 8 - 1:0], qv_unwritten_data[17 * 8 - 1:0]};
                        18:     qv_nd_to_re_data <= {iv_nd_data[14 * 8 - 1:0], qv_unwritten_data[18 * 8 - 1:0]};
                        19:     qv_nd_to_re_data <= {iv_nd_data[13 * 8 - 1:0], qv_unwritten_data[19 * 8 - 1:0]};
                        20:     qv_nd_to_re_data <= {iv_nd_data[12 * 8 - 1:0], qv_unwritten_data[20 * 8 - 1:0]};
                        21:     qv_nd_to_re_data <= {iv_nd_data[11 * 8 - 1:0], qv_unwritten_data[21 * 8 - 1:0]};
                        22:     qv_nd_to_re_data <= {iv_nd_data[10 * 8 - 1:0], qv_unwritten_data[22 * 8 - 1:0]};
                        23:     qv_nd_to_re_data <= {iv_nd_data[9 * 8 - 1:0], qv_unwritten_data[23 * 8 - 1:0]};
                        24:     qv_nd_to_re_data <= {iv_nd_data[8 * 8 - 1:0], qv_unwritten_data[24 * 8 - 1:0]};
                        25:     qv_nd_to_re_data <= {iv_nd_data[7 * 8 - 1:0], qv_unwritten_data[25 * 8 - 1:0]};
                        26:     qv_nd_to_re_data <= {iv_nd_data[6 * 8 - 1:0], qv_unwritten_data[26 * 8 - 1:0]};
                        27:     qv_nd_to_re_data <= {iv_nd_data[5 * 8 - 1:0], qv_unwritten_data[27 * 8 - 1:0]};
                        28:     qv_nd_to_re_data <= {iv_nd_data[4 * 8 - 1:0], qv_unwritten_data[28 * 8 - 1:0]};
                        29:     qv_nd_to_re_data <= {iv_nd_data[3 * 8 - 1:0], qv_unwritten_data[29 * 8 - 1:0]};
                        30:     qv_nd_to_re_data <= {iv_nd_data[2 * 8 - 1:0], qv_unwritten_data[30 * 8 - 1:0]};
                        31:     qv_nd_to_re_data <= {iv_nd_data[1 * 8 - 1:0], qv_unwritten_data[31 * 8 - 1:0]};
                        default:qv_nd_to_re_data <= qv_nd_to_re_data;    
                endcase                
            end
            else begin
                q_nd_to_re_wr_en <= 'd0;
                qv_nd_to_re_data <= qv_nd_to_re_data;
            end
        end
        else begin
            q_nd_to_re_wr_en <= 'd0;
            qv_nd_to_re_data <= qv_nd_to_re_data;
        end
    end
    else begin
        q_nd_to_re_wr_en <= 'd0;
        qv_nd_to_re_data <= qv_nd_to_re_data;
    end  
end

//-- qv_cur_entry_remained_len --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_cur_entry_remained_len <= 'd0;        
    end
    else if (Pack_cur_state == PACK_SGL_MD_s && !i_entry_from_wp_empty) begin
        qv_cur_entry_remained_len <= iv_entry_from_wp_data[31:0];
    end
    else if (Pack_cur_state == PACK_SGL_TRANS_s && o_nd_rd_en) begin 
        if(qv_cur_entry_remained_len > 32) begin 
            qv_cur_entry_remained_len <= qv_cur_entry_remained_len - 32;
        end 
        else begin 
            qv_cur_entry_remained_len <= 0;
        end 
    end 
    else if(Pack_cur_state == PACK_FLUSH_MD_s && !i_entry_from_wp_empty) begin
        qv_cur_entry_remained_len <= iv_entry_from_wp_data[31:0];
    end
    else if(Pack_cur_state == PACK_FLUSH_DATA_s && !i_entry_from_wp_empty && !i_nd_empty) begin
        if(qv_cur_entry_remained_len > 32) begin
            qv_cur_entry_remained_len <= qv_cur_entry_remained_len - 32;
        end
        else begin
            qv_cur_entry_remained_len <= 'd0;
        end
    end
    else begin
        qv_cur_entry_remained_len <= qv_cur_entry_remained_len;
    end
end

//-- qv_unwritten_len --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_unwritten_len <= 'd0;        
    end
    else if (Pack_cur_state == PACK_FWD_MD_s) begin
        qv_unwritten_len <= 'd0;        
    end
    else if (Pack_cur_state == PACK_SGL_TRANS_s) begin
        if(qv_cur_entry_remained_len == 0) begin        //corner case, this cycle does not read or write data
            qv_unwritten_len <= qv_unwritten_len;
        end
        //else if(!i_nd_empty && !w_next_stage_prog_full) begin
        else if(!i_nd_empty && !i_nd_to_re_prog_full) begin
			if(qv_cur_entry_remained_len >= 32) begin 
				qv_unwritten_len <= qv_unwritten_len; 
			end 
            else if(qv_cur_entry_remained_len + qv_unwritten_len == 32) begin 
                qv_unwritten_len <= 'd0;
            end 
            else if(qv_cur_entry_remained_len + qv_unwritten_len < 32) begin 
                qv_unwritten_len <= qv_cur_entry_remained_len + qv_unwritten_len;
            end 
            else begin 
                qv_unwritten_len <= qv_cur_entry_remained_len + qv_unwritten_len - 32;
            end 
        end 
        else begin
            qv_unwritten_len <= qv_unwritten_len;
        end
    end
    else begin
        qv_unwritten_len <= qv_unwritten_len;
    end
end

//-- qv_unwritten_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_unwritten_data <= 'd0;
    end
    else if (Pack_cur_state == PACK_FWD_MD_s) begin
        qv_unwritten_data <= 'd0;
    end
    else if (Pack_cur_state == PACK_SGL_TRANS_s) begin
        if(qv_cur_entry_remained_len == 0) begin        //corner case, this cycle does not read or write data
            qv_unwritten_data <= qv_unwritten_data;
        end
        //else if(!i_nd_empty && !w_next_stage_prog_full) begin
        else if(!i_nd_empty && !i_nd_to_re_prog_full) begin
            if(qv_cur_entry_remained_len + qv_unwritten_len == 32) begin 
                qv_unwritten_data <= 'd0;
            end 
            else if(qv_cur_entry_remained_len + qv_unwritten_len < 32) begin 
                case(qv_unwritten_len)
					0:		qv_unwritten_data <= {iv_nd_data};
                    1:      qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[1 * 8 - 1:0]};
                    2:      qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[2 * 8 - 1:0]};
                    3:      qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[3 * 8 - 1:0]};
                    4:      qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[4 * 8 - 1:0]};
                    5:      qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[5 * 8 - 1:0]};
                    6:      qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[6 * 8 - 1:0]};
                    7:      qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[7 * 8 - 1:0]};
                    8:      qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[8 * 8 - 1:0]};
                    9:      qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[9 * 8 - 1:0]};
                    10:     qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[10 * 8 - 1:0]};
                    11:     qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[11 * 8 - 1:0]};
                    12:     qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[12 * 8 - 1:0]};
                    13:     qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[13 * 8 - 1:0]};
                    14:     qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[14 * 8 - 1:0]};
                    15:     qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[15 * 8 - 1:0]};
                    16:     qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[16 * 8 - 1:0]};
                    17:     qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[17 * 8 - 1:0]};
                    18:     qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[18 * 8 - 1:0]};
                    19:     qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[19 * 8 - 1:0]};
                    20:     qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[20 * 8 - 1:0]};
                    21:     qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[21 * 8 - 1:0]};
                    22:     qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[22 * 8 - 1:0]};
                    23:     qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[23 * 8 - 1:0]};
                    24:     qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[24 * 8 - 1:0]};
                    25:     qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[25 * 8 - 1:0]};
                    26:     qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[26 * 8 - 1:0]};
                    27:     qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[27 * 8 - 1:0]};
                    28:     qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[28 * 8 - 1:0]};
                    29:     qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[29 * 8 - 1:0]};
                    30:     qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[30 * 8 - 1:0]};
                    31:     qv_unwritten_data <= {iv_nd_data, qv_unwritten_data[31 * 8 - 1:0]};
                    default:qv_unwritten_data <= qv_unwritten_data;    
                endcase
            end 
            else begin // qv_cur_entry_remained_len + qv_unwritten_len > 32 
                case(qv_unwritten_len)
                    1:      qv_unwritten_data <= {248'd0, iv_nd_data[255:256 - 1 * 8]};
                    2:      qv_unwritten_data <= {240'd0, iv_nd_data[255:256 - 2 * 8]};
                    3:      qv_unwritten_data <= {232'd0, iv_nd_data[255:256 - 3 * 8]};
                    4:      qv_unwritten_data <= {224'd0, iv_nd_data[255:256 - 4 * 8]};
                    5:      qv_unwritten_data <= {216'd0, iv_nd_data[255:256 - 5 * 8]};
                    6:      qv_unwritten_data <= {208'd0, iv_nd_data[255:256 - 6 * 8]};
                    7:      qv_unwritten_data <= {200'd0, iv_nd_data[255:256 - 7 * 8]};
                    8:      qv_unwritten_data <= {192'd0, iv_nd_data[255:256 - 8 * 8]};
                    9:      qv_unwritten_data <= {184'd0, iv_nd_data[255:256 - 9 * 8]};
                    10:     qv_unwritten_data <= {176'd0, iv_nd_data[255:256 - 10 * 8]};
                    11:     qv_unwritten_data <= {168'd0, iv_nd_data[255:256 - 11 * 8]};
                    12:     qv_unwritten_data <= {160'd0, iv_nd_data[255:256 - 12 * 8]};
                    13:     qv_unwritten_data <= {152'd0, iv_nd_data[255:256 - 13 * 8]};
                    14:     qv_unwritten_data <= {144'd0, iv_nd_data[255:256 - 14 * 8]};
                    15:     qv_unwritten_data <= {136'd0, iv_nd_data[255:256 - 15 * 8]};
                    16:     qv_unwritten_data <= {128'd0, iv_nd_data[255:256 - 16 * 8]};
                    17:     qv_unwritten_data <= {120'd0, iv_nd_data[255:256 - 17 * 8]};
                    18:     qv_unwritten_data <= {112'd0, iv_nd_data[255:256 - 18 * 8]};
                    19:     qv_unwritten_data <= {104'd0, iv_nd_data[255:256 - 19 * 8]};
                    20:     qv_unwritten_data <= {96'd0, iv_nd_data[255:256 - 20 * 8]};
                    21:     qv_unwritten_data <= {88'd0, iv_nd_data[255:256 - 21 * 8]};
                    22:     qv_unwritten_data <= {80'd0, iv_nd_data[255:256 - 22 * 8]};
                    23:     qv_unwritten_data <= {72'd0, iv_nd_data[255:256 - 23 * 8]};
                    24:     qv_unwritten_data <= {64'd0, iv_nd_data[255:256 - 24 * 8]};
                    25:     qv_unwritten_data <= {56'd0, iv_nd_data[255:256 - 25 * 8]};
                    26:     qv_unwritten_data <= {48'd0, iv_nd_data[255:256 - 26 * 8]};
                    27:     qv_unwritten_data <= {40'd0, iv_nd_data[255:256 - 27 * 8]};
                    28:     qv_unwritten_data <= {32'd0, iv_nd_data[255:256 - 28 * 8]};
                    29:     qv_unwritten_data <= {24'd0, iv_nd_data[255:256 - 29 * 8]};
                    30:     qv_unwritten_data <= {16'd0, iv_nd_data[255:256 - 30 * 8]};
                    31:     qv_unwritten_data <= {8'd0, iv_nd_data[255:256 - 31 * 8]};
                    default:qv_unwritten_data <= qv_unwritten_data;
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

//-- qv_sgl_entry_count --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_sgl_entry_count <= 'd0;        
    end
    else if (Pack_cur_state == PACK_FWD_MD_s) begin
        qv_sgl_entry_count <= wv_legal_entry_num;
    end
    else if (Pack_cur_state == PACK_FWD_ENTRY_s && !i_entry_from_wp_empty && !i_entry_to_re_prog_full) begin
        qv_sgl_entry_count <= qv_sgl_entry_count - 1;
    end
    else if (Pack_cur_state == PACK_SGL_TRANS_s && Pack_next_state == PACK_SGL_MD_s) begin
        qv_sgl_entry_count <= qv_sgl_entry_count - 1;
    end
    else if (Pack_cur_state == PACK_FLUSH_DATA_s && Pack_next_state == PACK_FLUSH_MD_s) begin
        qv_sgl_entry_count <= qv_sgl_entry_count - 1;
    end
    else begin
        qv_sgl_entry_count <= qv_sgl_entry_count;
    end
end






//-- q_entry_to_re_wr_en --
//-- qv_entry_to_re_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_entry_to_re_wr_en <= 'd0;
        qv_entry_to_re_data <= 'd0;
    end
    else if(Pack_cur_state == PACK_FWD_ENTRY_s && !i_entry_from_wp_empty && !i_entry_to_re_prog_full) begin
        q_entry_to_re_wr_en <= 'd1;
        qv_entry_to_re_data <= iv_entry_from_wp_data;        
    end
    else begin
        q_entry_to_re_wr_en <= 'd0;
        qv_entry_to_re_data <= qv_entry_to_re_data;
    end
end
  
//-- q_atomics_to_re_wr_en --
//-- qv_atomics_to_re_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_atomics_to_re_wr_en <= 1'b0;
        qv_atomics_to_re_data <= 'd0;        
    end
    else if (Pack_cur_state == PACK_FWD_MD_s && wv_cur_err_type == `QP_NORMAL) begin 
        if((wv_cur_op == `VERBS_FETCH_AND_ADD || wv_cur_op == `VERBS_CMP_AND_SWAP) && !i_atomics_from_wp_empty && !i_raddr_from_wp_empty && !w_next_stage_prog_full) begin 
            q_atomics_to_re_wr_en <= 1'b1;
            qv_atomics_to_re_data <= iv_atomics_from_wp_data;           
        end
        else begin
            q_atomics_to_re_wr_en <= 1'b0;
            qv_atomics_to_re_data <= qv_atomics_to_re_data;            
        end
    end 
    else begin
        q_atomics_to_re_wr_en <= 1'b0;
        qv_atomics_to_re_data <= qv_atomics_to_re_data;
    end
end

//-- q_raddr_to_re_wr_en --
//-- qv_raddr_to_re_data -- 
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_raddr_to_re_wr_en <= 1'b0;
        qv_raddr_to_re_data <= 'd0;
    end
    else if (Pack_cur_state == PACK_FWD_MD_s && wv_cur_err_type == `QP_NORMAL) begin 
        if((wv_cur_op == `VERBS_FETCH_AND_ADD || wv_cur_op == `VERBS_CMP_AND_SWAP) && !i_atomics_from_wp_empty && !i_raddr_from_wp_empty && !w_next_stage_prog_full) begin 
            q_raddr_to_re_wr_en <= 1'b1;
            qv_raddr_to_re_data <= iv_raddr_from_wp_data;       
        end
        else if((wv_cur_op == `VERBS_RDMA_WRITE || wv_cur_op == `VERBS_RDMA_WRITE_WITH_IMM || wv_cur_op == `VERBS_RDMA_READ) && !i_raddr_from_wp_empty && !w_next_stage_prog_full) begin
            q_raddr_to_re_wr_en <= 1'b1;
            qv_raddr_to_re_data <= iv_raddr_from_wp_data;
        end 
        else begin
            q_raddr_to_re_wr_en <= 1'b0;
            qv_raddr_to_re_data <= qv_raddr_to_re_data;          
        end
    end
    else begin
        q_raddr_to_re_wr_en <= 1'b0;
        qv_raddr_to_re_data <= 'd0;
    end
end

//-- qv_cur_op --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_cur_op <= 'd0;        
    end
    else if (Pack_cur_state == PACK_IDLE_s && !i_md_from_wp_empty) begin
        qv_cur_op <= wv_cur_op;
    end
    else begin
        qv_cur_op <= qv_cur_op;
    end
end

//-- q_md_to_re_wr_en --
//-- qv_md_to_re_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_md_to_re_wr_en <= 'd0;
        qv_md_to_re_data <= 'd0;        
    end
    else if (Pack_cur_state == PACK_FWD_MD_s && wv_cur_err_type == `QP_NORMAL) begin
        if((wv_cur_op == `VERBS_SEND || wv_cur_op == `VERBS_SEND_WITH_IMM) && !w_next_stage_prog_full) begin
            q_md_to_re_wr_en <= 'd1;
            qv_md_to_re_data <= iv_md_from_wp_data;            
        end
        else if((wv_cur_op == `VERBS_RDMA_WRITE || wv_cur_op == `VERBS_RDMA_WRITE_WITH_IMM || wv_cur_op == `VERBS_RDMA_READ) && !i_raddr_from_wp_empty && !w_next_stage_prog_full) begin
            q_md_to_re_wr_en <= 1'b1;
            qv_md_to_re_data <= iv_md_from_wp_data;
        end 
        else if((wv_cur_op == `VERBS_FETCH_AND_ADD || wv_cur_op == `VERBS_CMP_AND_SWAP) && !i_atomics_from_wp_empty && !i_raddr_from_wp_empty && !w_next_stage_prog_full) begin 
            q_md_to_re_wr_en <= 1'b1;
            qv_md_to_re_data <= iv_md_from_wp_data;
        end
        else begin 	//TODO : ATomics
            q_md_to_re_wr_en <= 1'b0;
            qv_md_to_re_data <= iv_md_from_wp_data;            
        end
    end
    else if(Pack_cur_state == PACK_FWD_MD_s && wv_cur_err_type != `QP_NORMAL) begin
        q_md_to_re_wr_en <= 1'b1;
        qv_md_to_re_data <= iv_md_from_wp_data;
    end
    else begin
        q_md_to_re_wr_en <= 1'b0;
        qv_md_to_re_data <= qv_md_to_re_data;            
    end
end

//FIFO Read Signals decode

//-- q_md_from_wp_rd_en --
always @(*) begin
    if(rst) begin
        q_md_from_wp_rd_en = 1'b0;
    end
    else begin
        case(Pack_cur_state)
            PACK_FWD_MD_s:  if(wv_cur_err_type == `QP_NORMAL) begin
                                if((wv_cur_op == `VERBS_SEND || wv_cur_op == `VERBS_SEND_WITH_IMM) && !w_next_stage_prog_full) begin
                                    q_md_from_wp_rd_en = 1'b1;        
                                end
                                else if((wv_cur_op == `VERBS_RDMA_WRITE || wv_cur_op == `VERBS_RDMA_WRITE_WITH_IMM || wv_cur_op == `VERBS_RDMA_READ) && !i_raddr_from_wp_empty && !w_next_stage_prog_full) begin
                                    q_md_from_wp_rd_en = 1'b1;  
                                end 
                                else if((wv_cur_op == `VERBS_FETCH_AND_ADD || wv_cur_op == `VERBS_CMP_AND_SWAP) && !i_atomics_from_wp_empty && !i_raddr_from_wp_empty && !w_next_stage_prog_full) begin 
                                    q_md_from_wp_rd_en = 1'b1;  
                                end
                                else begin
                                    q_md_from_wp_rd_en = 1'b0;          
                                end
                            end
                            else begin  //Abnormal
                                q_md_from_wp_rd_en = 1'b1;
                            end
            default:        q_md_from_wp_rd_en = 1'b0;
        endcase       
    end
end

always @(*) begin
    if(rst) begin
        q_inline_rd_en = 1'b0;
    end
    else begin
        case(Pack_cur_state) 
            PACK_INLINE_DATA_s:     q_inline_rd_en = !i_inline_empty && !w_next_stage_prog_full;
            default:                q_inline_rd_en = 1'b0;
        endcase
    end
end

always @(*) begin
    if(rst) begin 
        q_atomics_from_wp_rd_en = 1'b0;
    end 
    else begin
        case(Pack_cur_state)
            PACK_FWD_MD_s:      if(wv_cur_err_type == `QP_NORMAL && (wv_cur_op == `VERBS_FETCH_AND_ADD || wv_cur_op == `VERBS_CMP_AND_SWAP) && !i_atomics_from_wp_empty && !i_raddr_from_wp_empty && !w_next_stage_prog_full) begin 
                                    q_atomics_from_wp_rd_en = 1'b1;  
                                end 
                                else begin
                                    q_atomics_from_wp_rd_en = 1'b0;
                                end
            default:            q_atomics_from_wp_rd_en = 1'b0;
        endcase
    end 
end

always @(*) begin
    if(rst) begin
        q_addr_from_wp_rd_en = 1'b0;
    end
    else begin 
        case(Pack_cur_state)
            PACK_FWD_MD_s:        if(wv_cur_err_type == `QP_NORMAL && (wv_cur_op == `VERBS_FETCH_AND_ADD || wv_cur_op == `VERBS_CMP_AND_SWAP) && !i_atomics_from_wp_empty && !i_raddr_from_wp_empty && !w_next_stage_prog_full) begin 
                                    q_addr_from_wp_rd_en = 1'b1;  
                                end 
                                else if((wv_cur_op == `VERBS_RDMA_WRITE || wv_cur_op == `VERBS_RDMA_WRITE_WITH_IMM || wv_cur_op == `VERBS_RDMA_READ) && !i_raddr_from_wp_empty && !w_next_stage_prog_full) begin 
                                    q_addr_from_wp_rd_en = 1'b1;
                                end 
                                else begin
                                    q_addr_from_wp_rd_en = 1'b0;
                                end
            default:            q_addr_from_wp_rd_en = 1'b0;
        endcase
    end 
end


always @(*) begin
    if(rst) begin
        q_entry_from_wp_rd_en = 1'b0;
    end
    else begin
        case(Pack_cur_state) 
            PACK_FWD_ENTRY_s:       if(!i_entry_from_wp_empty && !i_entry_to_re_prog_full) begin
                                        q_entry_from_wp_rd_en = 1'b1;
                                    end
                                    else begin
                                        q_entry_from_wp_rd_en = 1'b0;
                                    end
            PACK_SGL_TRANS_s:       if(qv_cur_entry_remained_len == 0) begin    //corner case, do not read
                                        q_entry_from_wp_rd_en = 1'b0;
                                    end
                                    else if(qv_cur_entry_remained_len <= 32 && !i_nd_empty && !i_nd_to_re_prog_full) begin
                                        q_entry_from_wp_rd_en = 1'b1;
                                    end
                                    else begin
                                        q_entry_from_wp_rd_en = 1'b0;
                                    end
            PACK_FLUSH_DATA_s:      if(qv_cur_entry_remained_len <= 32 && !i_nd_empty) begin
                                        q_entry_from_wp_rd_en = 1'b1;
                                    end
                                    else begin
                                        q_entry_from_wp_rd_en = 1'b0;
                                    end
            default:                q_entry_from_wp_rd_en = 1'b0;
        endcase        
    end
end


always @(*) begin
    if(rst) begin
        q_nd_rd_en = 1'b0;
    end
    else begin
        case(Pack_cur_state) 
            PACK_SGL_TRANS_s:       if(qv_sgl_entry_count == 1) begin
                                        if(qv_cur_entry_remained_len == 0) begin    //corner case
                                            q_nd_rd_en = 1'b0;
                                        end
                                        else if(!i_nd_empty && !i_nd_to_re_prog_full) begin
                                            q_nd_rd_en = 1'b1;
                                        end
                                        else begin
                                            q_nd_rd_en = 1'b0;
                                        end
                                    end
                                    else begin
                                        if(!i_nd_empty && !i_nd_to_re_prog_full) begin
                                            q_nd_rd_en = 1'b1;
                                        end
                                        else begin
                                            q_nd_rd_en = 1'b0;
                                        end
                                    end
            PACK_FLUSH_DATA_s:      q_nd_rd_en = !i_nd_empty;
            default:                q_nd_rd_en = 1'b0;
        endcase        
    end
end


always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_DebugCounter_entry_rd_en <= 'd0;
	end 
	else if(q_entry_from_wp_rd_en) begin
		qv_DebugCounter_entry_rd_en <= qv_DebugCounter_entry_rd_en + 1;
	end 
	else begin
		qv_DebugCounter_entry_rd_en <= qv_DebugCounter_entry_rd_en;
	end
end 

always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_DebugCounter_entry_wr_en <= 'd0;
	end 
	else if(q_entry_to_re_wr_en) begin
		qv_DebugCounter_entry_wr_en <= qv_DebugCounter_entry_wr_en + 1;
	end 
	else begin
		qv_DebugCounter_entry_wr_en <= qv_DebugCounter_entry_wr_en;
	end
end 

//Connect dbg signals
wire   [`DBG_NUM_DATA_PACK * 32 - 1 : 0]   coalesced_bus;
assign coalesced_bus = {
                            q_md_from_wp_rd_en,
                            q_inline_rd_en,
                            q_atomics_from_wp_rd_en,
                            q_addr_from_wp_rd_en,
                            q_entry_from_wp_rd_en,
                            q_nd_rd_en,
                            q_entry_to_re_wr_en,
                            q_inline_odd,
                            q_md_to_re_wr_en,
                            q_nd_to_re_wr_en,
                            q_raddr_to_re_wr_en,
                            q_atomics_to_re_wr_en,
                            w_next_stage_prog_full,
                            w_inline_flag,
                            w_zero_msg_size,
                            Pack_cur_state,
                            Pack_next_state,
                            wv_cur_op,
                            wv_msg_size,
                            wv_cur_err_type,
                            wv_legal_entry_num,
                            wv_inline_count,
                            qv_entry_to_re_data,
                            qv_atomics_to_re_data,
                            qv_raddr_to_re_data,
                            qv_nd_to_re_data,
                            qv_md_to_re_data,
                            qv_cur_op,
                            qv_inline_count,
                            qv_cur_entry_remained_len,
                            qv_unwritten_len,
                            qv_unwritten_data,
                            qv_sgl_entry_count,
                            qv_DebugCounter_entry_rd_en,
                            qv_DebugCounter_entry_wr_en
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
                    (dbg_sel == 48) ?   coalesced_bus[32 * 49 - 1 : 32 * 48] : 32'd0;

//assign dbg_bus = coalesced_bus;

endmodule
