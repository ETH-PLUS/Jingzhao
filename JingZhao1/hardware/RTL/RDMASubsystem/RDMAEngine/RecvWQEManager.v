
`include "ib_constant_def_h.vh"
`include "sw_hw_interface_const_def_h.vh"
`include "msg_def_v2p_h.vh"
`include "msg_def_ctxmgt_h.vh"
`include "nic_hw_params.vh"

`define 	RQ_TABLE_LIMIT 		4096
`define 	FETCH_WAIT_CYCLE 			1

module RecvWQEManager
#(
	parameter 	RW_REG_NUM = 5
)
(
    input   wire                clk,
    input   wire                rst,

	input 	wire 	[RW_REG_NUM * 32 - 1 : 0]	rw_data,
	output 	wire 	[RW_REG_NUM * 32 - 1 : 0]	init_rw_data,

    input   wire                i_ee_cmd_empty,
    input   wire    [255:0]     iv_ee_cmd_data,
    output  wire                o_ee_cmd_rd_en,

    input   wire                i_ee_resp_prog_full,
    output  wire                o_ee_resp_wr_en,
    output  wire    [191:0]     ov_ee_resp_data,

    output  wire                o_vtp_cmd_wr_en,
    input   wire                i_vtp_cmd_prog_full,
    output  wire    [255:0]     ov_vtp_cmd_data,

    input   wire                i_vtp_resp_empty,
    output  wire                o_vtp_resp_rd_en,
    input   wire    [7:0]       iv_vtp_resp_data,

    input   wire                i_vtp_download_empty,
    output  wire                o_vtp_download_rd_en,
    input   wire    [127:0]     iv_vtp_download_data,

    input   wire    [31:0]      dbg_sel,
    output  wire    [32 - 1:0]      dbg_bus,
    //output  wire    [`DBG_NUM_RECV_WQE_MANAGER * 32 - 1:0]      dbg_bus,

	output 	wire 				o_rwm_init_finish
);

 //ila_rwm     ila_rwm(
 //    .clk(clk),
 //    .probe0(o_vtp_cmd_wr_en),
 //    .probe1(i_vtp_cmd_prog_full),
 //    .probe2(ov_vtp_cmd_data),
 //    .probe3(i_vtp_resp_empty),
 //    .probe4(o_vtp_resp_rd_en),
 //    .probe5(iv_vtp_resp_data),
 //    .probe6(i_vtp_download_empty),
 //    .probe7(o_vtp_download_rd_en),
 //    .probe8(iv_vtp_download_data),
 //    .probe9(q_list_wea),         //1
 //    .probe10(qv_list_addra),      //14
 //    .probe11(qv_list_dina),       //25
 //    .probe12(qv_list_addrb),      //14
 //    .probe13(wv_list_doutb),      //25
 //    .probe14(wv_list_doutb_fake), //25
 //    .probe15(wv_buffer_space),      //32
 //    .probe16(w_wqe_available)       //1
 //);

/*----------------------------------------  Part 1: Signals Definition and Submodules Connection ----------------------------------------*/

reg                q_ee_cmd_rd_en;
reg                q_ee_resp_wr_en;
reg    [191:0]      qv_ee_resp_data;
reg                q_vtp_cmd_wr_en;
reg    [255:0]     qv_vtp_cmd_data;
reg                q_vtp_resp_rd_en;
reg                q_vtp_download_rd_en;

assign o_ee_cmd_rd_en = q_ee_cmd_rd_en;
assign o_ee_resp_wr_en = q_ee_resp_wr_en;
assign ov_ee_resp_data = qv_ee_resp_data;
assign o_vtp_cmd_wr_en = q_vtp_cmd_wr_en;
assign ov_vtp_cmd_data = qv_vtp_cmd_data;
assign o_vtp_resp_rd_en = q_vtp_resp_rd_en;
assign o_vtp_download_rd_en = q_vtp_download_rd_en;

//wire    [1:0]           wv_OpCode;                 
wire    [2:0]           wv_OpCode;                 
wire    [23:0]          wv_QPN;
wire    [31:0]          wv_PD;
wire    [31:0]          wv_RQ_LKey;
wire 	[31:0]			wv_RQ_Length;
wire 	[7:0]			wv_RQ_Entry_Size_Log;
wire    [63:0]          wv_Entry_VA;
wire    [31:0]          wv_Entry_Length;
wire    [31:0]          wv_Entry_LKey;

reg     [31:0]      	qv_offset_in_flush;
wire    [15:0]          wv_rq_wqe_block_size;
wire 					w_meet_wqe_block_boundary;
wire 	[15:0]			wv_cur_wqe_block_boundary;


reg     [15:0]          qv_SegCounter;
reg     [15:0]          qv_next_wqe_size;
reg     [25:0]          qv_next_wqe_addr;
reg     [23:0]          qv_cur_rq_offset;

assign wv_OpCode = iv_ee_cmd_data[2:0];
assign wv_QPN = iv_ee_cmd_data[31:8];
assign wv_PD = iv_ee_cmd_data[63:32];
assign wv_RQ_LKey = iv_ee_cmd_data[95:64];
assign wv_RQ_Length = iv_ee_cmd_data[127:96];
assign wv_RQ_Entry_Size_Log = iv_ee_cmd_data[135:128];
assign wv_Entry_Length = iv_ee_cmd_data[63:32];
assign wv_Entry_LKey = iv_ee_cmd_data[95:64];
assign wv_Entry_VA = iv_ee_cmd_data[159:96];
assign wv_rq_wqe_block_size = (1 << wv_RQ_Entry_Size_Log) / 16;		//In unit of 16B, range is [2, 4, 8, 16]

assign w_meet_wqe_block_boundary = (wv_rq_wqe_block_size == 2 && qv_offset_in_flush[0] == 1'b1) ||
									(wv_rq_wqe_block_size == 4 && qv_offset_in_flush[1:0] == 2'b11) ||
									(wv_rq_wqe_block_size == 8 && qv_offset_in_flush[2:0] == 3'b111) ||
									(wv_rq_wqe_block_size == 16 && qv_offset_in_flush[3:0] == 4'b1111);

assign wv_cur_wqe_block_boundary = (wv_rq_wqe_block_size == 2) ? {(qv_SegCounter[15:1] + 1), 1'b0} :
									(wv_rq_wqe_block_size == 4) ? {(qv_SegCounter[15:2] + 1), 2'b00} : 
									(wv_rq_wqe_block_size == 8) ? {(qv_SegCounter[15:3] + 1), 3'b000} : 
									(wv_rq_wqe_block_size == 16) ? {(qv_SegCounter[15:4] + 1), 4'b0000} : 'd0;

wire 					w_clear_finish;

reg 					q_available_wqe_back;
reg 					q_rq_wrap_around;

reg                     q_list_wea;
reg     [13:0]          qv_list_addra;
reg     [24:0]          qv_list_dina;
reg     [13:0]          qv_list_addrb;
wire    [24:0]          wv_list_doutb;
wire    [24:0]          wv_list_doutb_fake;
BRAM_SDP_25w_16384d EntryListTable(         //Store MultiQueue Metadata
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[0 * 32 + 1 : 0 * 32 + 0]),
	.WTSEL( rw_data[0 * 32 + 3 : 0 * 32 + 2]),
	.PTSEL( rw_data[0 * 32 + 5 : 0 * 32 + 4]),
	.VG(    rw_data[0 * 32 + 6 : 0 * 32 + 6]),
	.VS(    rw_data[0 * 32 + 7 : 0 * 32 + 7]),

  `endif

  .clka(clk),    
  .ena(1'b1),      
  .wea(q_list_wea),      
  .addra(qv_list_addra),  
  .dina(qv_list_dina),    
  .clkb(clk),    
  .enb(1'b1),      
  .addrb(qv_list_addrb),  
  .doutb(wv_list_doutb_fake)  
);

reg                     q_content_wea;
reg     [11:0]          qv_content_addra;
reg     [159:0]         qv_content_dina;
reg     [11:0]          qv_content_addrb;
wire    [159:0]         wv_content_doutb;
wire    [159:0]         wv_content_doutb_fake;
BRAM_SDP_160w_4096d EntryElementTable_Content(      //Store MultiQueue Entry
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[1 * 32 + 1 : 1 * 32 + 0]),
	.WTSEL( rw_data[1 * 32 + 3 : 1 * 32 + 2]),
	.PTSEL( rw_data[1 * 32 + 5 : 1 * 32 + 4]),
	.VG(    rw_data[1 * 32 + 6 : 1 * 32 + 6]),
	.VS(    rw_data[1 * 32 + 7 : 1 * 32 + 7]),
  `endif

  .clka(clk),    
  .ena(1'b1),      
  .wea(q_content_wea),      
  .addra(qv_content_addra),  
  .dina(qv_content_dina),    
  .clkb(clk),    
  .enb(1'b1),      
  .addrb(qv_content_addrb),  
  .doutb(wv_content_doutb_fake)  
);

reg                     q_next_wea;
reg     [11:0]          qv_next_addra;
reg     [11:0]          qv_next_dina;
reg     [11:0]          qv_next_addrb;
wire    [11:0]          wv_next_doutb;
wire    [11:0]          wv_next_doutb_fake;
BRAM_SDP_12w_4096d EntryElementTable_Addr(      //Store MultiQueue Next Addr of each entry
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[2 * 32 + 1 : 2 * 32 + 0]),
	.WTSEL( rw_data[2 * 32 + 3 : 2 * 32 + 2]),
	.PTSEL( rw_data[2 * 32 + 5 : 2 * 32 + 4]),
	.VG(    rw_data[2 * 32 + 6 : 2 * 32 + 6]),
	.VS(    rw_data[2 * 32 + 7 : 2 * 32 + 7]),
  `endif

  .clka(clk),    
  .ena(1'b1),      
  .wea(q_next_wea),      
  .addra(qv_next_addra),  
  .dina(qv_next_dina),    
  .clkb(clk),    
  .enb(1'b1),      
  .addrb(qv_next_addrb),  
  .doutb(wv_next_doutb_fake)  
);

reg     [11:0]          qv_Free_din;
reg                     q_Free_wr_en;
reg                     q_Free_rd_en;
wire    [11:0]          wv_Free_dout;
wire                    w_Free_prog_full;
wire                    w_Free_empty;
wire    [12:0]          wv_Free_data_count;                 
SyncFIFO_12w_4096d EntryFreeFIFO(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[3 * 32 + 1 : 3 * 32 + 0]),
	.WTSEL( rw_data[3 * 32 + 3 : 3 * 32 + 2]),
	.PTSEL( rw_data[3 * 32 + 5 : 3 * 32 + 4]),
	.VG(    rw_data[3 * 32 + 6 : 3 * 32 + 6]),
	.VS(    rw_data[3 * 32 + 7 : 3 * 32 + 7]),

  `endif

  .clk(clk),                
  .srst(rst),              
  .din(qv_Free_din),                
  .wr_en(q_Free_wr_en),            
  .rd_en(q_Free_rd_en),            
  .dout(wv_Free_dout),              
  .full(),              
  .empty(w_Free_empty),            
  .data_count(wv_Free_data_count),  
  .prog_full(w_Free_prog_full)    
);

reg     [0:0]       q_rq_offset_table_wea;
reg     [13:0]      qv_rq_offset_table_addra;
reg     [23:0]      qv_rq_offset_table_dina;
reg     [13:0]      qv_rq_offset_table_addrb;
wire    [23:0]      wv_rq_offset_table_doutb;
wire    [23:0]      wv_rq_offset_table_doutb_fake;


BRAM_SDP_24w_16384d RQ_OFFSET_TABLE(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[4 * 32 + 1 : 4 * 32 + 0]),
	.WTSEL( rw_data[4 * 32 + 3 : 4 * 32 + 2]),
	.PTSEL( rw_data[4 * 32 + 5 : 4 * 32 + 4]),
	.VG(    rw_data[4 * 32 + 6 : 4 * 32 + 6]),
	.VS(    rw_data[4 * 32 + 7 : 4 * 32 + 7]),
  `endif

  .clka(clk),    
  .ena(1'b1),      
  .wea(q_rq_offset_table_wea),      
  .addra(qv_rq_offset_table_addra),  
  .dina(qv_rq_offset_table_dina),    
  .clkb(clk),
  .enb(1'b1),        
  .addrb(qv_rq_offset_table_addrb),  
  .doutb(wv_rq_offset_table_doutb_fake)  
);

reg                     q_list_wea_TempReg;
reg     [13:0]          qv_list_addra_TempReg;
reg     [24:0]          qv_list_dina_TempReg;
reg     [13:0]          qv_list_addrb_TempReg;
reg                     q_content_wea_TempReg;
reg     [11:0]          qv_content_addra_TempReg;
reg     [159:0]         qv_content_dina_TempReg;
reg     [11:0]          qv_content_addrb_TempReg;
reg                     q_next_wea_TempReg;
reg     [11:0]          qv_next_addra_TempReg;
reg     [11:0]          qv_next_dina_TempReg;
reg     [11:0]          qv_next_addrb_TempReg;
reg     [0:0]       q_rq_offset_table_wea_TempReg;
reg     [13:0]      qv_rq_offset_table_addra_TempReg;
reg     [23:0]      qv_rq_offset_table_dina_TempReg;
reg     [13:0]      qv_rq_offset_table_addrb_TempReg;

reg     [7:0]           qv_wqe_release_cnt;
reg 	[7:0]			qv_entry_release_cnt;
reg 	[7:0]			qv_entry_clear_cnt;

wire    [31:0]          wv_buffer_space;
wire                    w_wqe_available;


reg     [7:0]           qv_respCode;
reg     [31:0]          qv_free_init_counter;
reg     [31:0]          qv_list_init_counter;


wire    [11:0]          wv_queue_head;
wire    [11:0]          wv_queue_tail;
wire                    w_queue_empty;

reg 	[1:0]			qv_fetch_counter;

/*----------------------------------------  Part 2: State Machine Transition ------------------------------------------------------------*/
reg     [7:0]           RWM_cur_state;
reg     [7:0]           RWM_next_state;

parameter   [7:0]       RWM_INIT_s              = 4'd0,
                        RWM_IDLE_s              = 4'd1,
                        RWM_FETCH_ENTRY_s       = 4'd2,
                        RWM_UPDATE_ENTRY_s      = 4'd3,
                        RWM_RELEASE_ENTRY_s     = 4'd4,
                        RWM_RELEASE_WQE_s       = 4'd5,
                        RWM_MEM_WAIT_s          = 4'd6,
                        RWM_WQE_SPLIT_s         = 4'd7,
                        RWM_SKIP_s              = 4'd8,     //Since WQE is not continuous in the 512B, we may skip some data when splitting WQE
                        RWM_FLUSH_s             = 4'd9,
                        RWM_RESP_s              = 4'd10,
						RWM_RQ_WRAP_s 			= 4'd11,
						RWM_CLEAR_s 			= 4'd12;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        RWM_cur_state <= RWM_INIT_s;
    end
    else begin
        RWM_cur_state <= RWM_next_state;
    end
end

always @(*) begin
    case(RWM_cur_state)
        RWM_INIT_s:             if((qv_free_init_counter == `RQ_TABLE_LIMIT - 1) && (qv_list_init_counter == `QP_NUM - 1)) begin 
                                    RWM_next_state = RWM_IDLE_s;
                                end 
                                else begin 
                                    RWM_next_state = RWM_INIT_s;
                                end 
        RWM_IDLE_s:             if(!i_ee_cmd_empty) begin
                                    if(wv_OpCode == `FETCH_ENTRY) begin
                                        RWM_next_state = RWM_FETCH_ENTRY_s;
                                    end
                                    else if(wv_OpCode == `UPDATE_ENTRY) begin
                                        RWM_next_state = RWM_UPDATE_ENTRY_s;
                                    end
                                    else if(wv_OpCode == `RELEASE_ENTRY) begin
                                        RWM_next_state = RWM_RELEASE_ENTRY_s;
                                    end
                                    else if(wv_OpCode == `RELEASE_WQE) begin
                                        RWM_next_state = RWM_RELEASE_WQE_s;
                                    end
									else if(wv_OpCode == `FLUSH_ENTRY) begin
										RWM_next_state = RWM_CLEAR_s;
									end 
                                    else begin
                                        RWM_next_state = RWM_IDLE_s;
                                    end
                                end
                                else begin
                                    RWM_next_state = RWM_IDLE_s;                
                                end            
        RWM_FETCH_ENTRY_s:      if(!w_wqe_available) begin
                                    if(wv_buffer_space >= 512) begin
                                        if(!i_vtp_cmd_prog_full) begin
											if(wv_rq_offset_table_doutb + 'd512 <= wv_RQ_Length) begin 	//Does not cross RQ boundary
	                                            RWM_next_state = RWM_MEM_WAIT_s;                               
											end 
											else begin		//Wrap around the RQ, need two MemRd
												RWM_next_state = RWM_RQ_WRAP_s;
											end          
                                        end
                                        else begin
                                            RWM_next_state = RWM_FETCH_ENTRY_s;
                                        end
                                    end
                                    else begin
                                        RWM_next_state = RWM_RESP_s;
                                    end
                                end
                                else if(qv_fetch_counter == `FETCH_WAIT_CYCLE) begin
                                    if(wv_content_doutb[127:0] != 128'd0) begin //Current WQE Exhausted
                                        RWM_next_state = RWM_RESP_s;
                                    end
                                    else begin //Available Entry return
                                        RWM_next_state = RWM_RESP_s;
                                    end
                                end
								else begin
									RWM_next_state = RWM_FETCH_ENTRY_s;
								end 
        RWM_UPDATE_ENTRY_s:     RWM_next_state = RWM_IDLE_s;    //One cycle update
        RWM_RELEASE_ENTRY_s:    if(qv_entry_release_cnt == 1) begin 	//Two cycle release
									RWM_next_state = RWM_IDLE_s;
								end 			
								else begin 
									RWM_next_state = RWM_RELEASE_ENTRY_s;
								end 	
        RWM_RELEASE_WQE_s:      if(wv_content_doutb[127:0] == 0 && qv_wqe_release_cnt > 0) begin  //Meets zero
                                    RWM_next_state = RWM_IDLE_s;
                                end
                                else begin
                                    RWM_next_state = RWM_RELEASE_WQE_s;
                                end
		RWM_RQ_WRAP_s:			if(!i_vtp_cmd_prog_full) begin
									RWM_next_state = RWM_MEM_WAIT_s;
								end 
								else begin
									RWM_next_state = RWM_RQ_WRAP_s;
								end 
        RWM_MEM_WAIT_s:         if(!i_vtp_resp_empty && !i_vtp_download_empty) begin     //WQE from memory back
                                    RWM_next_state = RWM_WQE_SPLIT_s;
                                end
                                else begin
                                    RWM_next_state = RWM_MEM_WAIT_s;
                                end
        RWM_WQE_SPLIT_s:        if(qv_SegCounter == 0) begin
                                    if(iv_vtp_download_data == 128'd0) begin //No available WQE back, flush mem data
                                        RWM_next_state = RWM_FLUSH_s; 
                                    end
                                    else begin
                                        RWM_next_state = RWM_WQE_SPLIT_s;
                                    end
                                end
                                else begin
                                    // if(iv_vtp_download_data == 128'd0) begin   //Encounter delimiter
                                    //     if(qv_SegCounter != 31) begin   //512B = 16B * 32
                                    //         if(qv_next_wqe_size != 0) begin
                                    //             if(qv_SegCounter + qv_next_wqe_size > 32) begin //Next WQE is not completely read back
                                    //                 RWM_next_state = RWM_FLUSH_s;
                                    //             end
                                    //             else begin
                                    //                 RWM_next_state = RWM_WQE_SPLIT_s;
                                    //             end
                                    //         end
                                    //         else begin
                                    //             RWM_next_state = RWM_FLUSH_s;
                                    //         end
                                    //     end
                                    //     else begin //The delimiter accidentally sits at the last 16B of the 512B
                                    //         RWM_next_state = RWM_RESP_s;
                                    //     end
                                    // end
                                    // else begin
                                    //     RWM_next_state = RWM_WQE_SPLIT_s;
                                    // end
                                    if(iv_vtp_download_data == 128'd0) begin    //Encounter delimiter
                                        if(qv_SegCounter == 31) begin
                                            RWM_next_state = RWM_RESP_s;    //Accidentally last 16B, respond entry to EE
                                        end
                                        else begin
                                            if(qv_next_wqe_size != 0 && (wv_cur_wqe_block_boundary + qv_next_wqe_size <= 32)) begin //There exists available and integral WQE
                                                if(qv_cur_rq_offset + qv_SegCounter + 1 == qv_next_wqe_addr) begin //Two WQEs are adjacent, no bubble exist, directly continue splitting
                                                    RWM_next_state = RWM_WQE_SPLIT_s;
                                                end
                                                else begin //Bubbles exists between two WQEs, skip these bubbles
                                                    RWM_next_state = RWM_SKIP_s;    
                                                end
                                            end
                                            else begin
                                                RWM_next_state = RWM_FLUSH_s;
                                            end
                                        end
                                    end
                                    else begin
                                        RWM_next_state = RWM_WQE_SPLIT_s;
                                    end
                                end
        RWM_SKIP_s:             if(qv_SegCounter + 1 < (qv_next_wqe_addr - qv_cur_rq_offset)) begin
                                    RWM_next_state = RWM_SKIP_s;
                                end
                                else begin
                                    RWM_next_state = RWM_WQE_SPLIT_s;
                                end
        RWM_FLUSH_s:            if(qv_SegCounter == 31 && !i_vtp_download_empty) begin
                                    RWM_next_state = RWM_RESP_s;
                                end
                                else begin
                                    RWM_next_state = RWM_FLUSH_s;
                                end
        RWM_RESP_s:             if(!i_ee_resp_prog_full) begin  
                                    RWM_next_state = RWM_IDLE_s;
                                end
                                else begin
                                    RWM_next_state = RWM_RESP_s;
                                end
		RWM_CLEAR_s:		if(w_clear_finish) begin
									RWM_next_state = RWM_IDLE_s;
								end 
								else begin
									RWM_next_state = RWM_CLEAR_s;
								end 
        default:                RWM_next_state = RWM_IDLE_s;
    endcase
end

assign o_rwm_init_finish = (qv_free_init_counter == `RQ_TABLE_LIMIT - 1) && (qv_list_init_counter == `QP_NUM - 1);

/*----------------------------------------  Part 3: Output Registers Decode -------------------------------------------------------------*/
//To avoid write-read collision, since when write and read at the same address happens at the same time, write will be successful and 
//read will be uncertain
assign wv_next_doutb = ((qv_next_addra_TempReg == qv_next_addrb_TempReg) && q_next_wea_TempReg) ? qv_next_dina_TempReg : wv_next_doutb_fake;
assign wv_content_doutb = ((qv_content_addra_TempReg == qv_content_addrb_TempReg) && q_content_wea_TempReg) ? qv_content_dina_TempReg : wv_content_doutb_fake;
assign wv_list_doutb = ((qv_list_addra_TempReg == qv_list_addrb_TempReg) && q_list_wea_TempReg) ? qv_list_dina_TempReg : wv_list_doutb_fake;
assign wv_rq_offset_table_doutb = ((qv_rq_offset_table_addra_TempReg == qv_rq_offset_table_addrb_TempReg) && q_rq_offset_table_wea_TempReg) 
									? qv_rq_offset_table_dina_TempReg : wv_rq_offset_table_doutb_fake;


//-- q_available_wqe_back --
always @(posedge rst or posedge clk) begin
	if(rst) begin 
		q_available_wqe_back <= 'd0;
	end 
	else if(RWM_cur_state == RWM_WQE_SPLIT_s && qv_SegCounter == 0) begin
		if(iv_vtp_download_data != 128'd0) begin 
			q_available_wqe_back <= 1'd1;
		end 
		else begin 
			q_available_wqe_back <= 1'd0;
		end 
	end 
	else begin 
		q_available_wqe_back <= q_available_wqe_back;
	end 
end 

//-- qv_fetch_counter --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_fetch_counter <= 'd0;
	end 
	else if(RWM_cur_state == RWM_IDLE_s) begin
		qv_fetch_counter <= 'd0;
	end 
	else if(RWM_cur_state == RWM_FETCH_ENTRY_s) begin
		qv_fetch_counter <= qv_fetch_counter + 1;
	end 
	else begin
		qv_fetch_counter <= qv_fetch_counter;
	end 
end 

//-- q_rq_wrap_around --
always @(posedge rst or posedge clk) begin
	if(rst) begin
		q_rq_wrap_around <= 'd0;
	end 
	else if(RWM_cur_state == RWM_IDLE_s) begin
		q_rq_wrap_around <= 'd0;
	end 
	else if(RWM_cur_state == RWM_RQ_WRAP_s) begin
		q_rq_wrap_around <= 'd1;
	end 
	else begin
		q_rq_wrap_around <= q_rq_wrap_around;
	end 
end 

//-- qv_list_init_counter --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_list_init_counter <= 'd0;        
    end
    else if (RWM_cur_state == RWM_INIT_s && qv_list_init_counter < `QP_NUM - 1) begin
        qv_list_init_counter <= qv_list_init_counter + 1;
    end
    else begin
        qv_list_init_counter <= qv_list_init_counter;
    end
end

//-- qv_free_init_counter --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_free_init_counter <= 'd0;        
    end
    else if (RWM_cur_state == RWM_INIT_s && qv_free_init_counter < `RQ_TABLE_LIMIT - 1) begin
        qv_free_init_counter <= qv_free_init_counter + 1;
    end
    else begin
        qv_free_init_counter <= qv_free_init_counter;
    end
end

//-- qv_SegCounter -- Indicates how many 16B are left unprocessed(Each time we need to fetch a WQE, we read 512B from RQ)
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_SegCounter <= 'd0;
    end
    else if (RWM_cur_state == RWM_MEM_WAIT_s) begin
        qv_SegCounter <= 0;
    end
    else if (RWM_cur_state == RWM_WQE_SPLIT_s && !i_vtp_download_empty) begin   //If vtp_download is not empty. we can read it
        qv_SegCounter <= qv_SegCounter + 1;
    end
    else if (RWM_cur_state == RWM_SKIP_s && !i_vtp_download_empty) begin
        qv_SegCounter <= qv_SegCounter + 1;
    end
    else if (RWM_cur_state == RWM_FLUSH_s && !i_vtp_download_empty) begin
        qv_SegCounter <= qv_SegCounter + 1;
    end
    else begin
        qv_SegCounter <= qv_SegCounter;
    end
end

//-- wv_buffer_space -- Indicates buffer space of Element Table
assign wv_buffer_space = wv_Free_data_count * 16;   //Each addr in FreeFIFO points to a 16B buffer

//-- w_wqe_available --
assign w_wqe_available = !w_queue_empty;     //Empty flag

//-- qv_respCode --
//Indicates which response we need to generate
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_respCode <= 'd0;
    end
    else if(RWM_cur_state == RWM_FETCH_ENTRY_s && qv_fetch_counter == `FETCH_WAIT_CYCLE) begin 
        if(w_wqe_available && wv_content_doutb[127:0] != 0) begin   //Got available Entry
            qv_respCode <= `VALID_ENTRY;
        end
        else if(w_wqe_available && wv_content_doutb[127:0] == 0) begin  //Entry exhausted
            qv_respCode <= `INVALID_ENTRY;
        end     
        else begin  //Judge in RWM_WQE_SPLIT_s
            qv_respCode <= qv_respCode;
        end
    end 
    else if (RWM_cur_state == RWM_WQE_SPLIT_s) begin
        if(qv_SegCounter == 0 && iv_vtp_download_data != 128'd0) begin   //Available WQE back
            qv_respCode <= `VALID_ENTRY;
        end
        else if(qv_SegCounter == 0 && iv_vtp_download_data == 128'd0) begin //No available WQE back
            qv_respCode <= `INVALID_WQE;
        end 
        else begin
            qv_respCode <= qv_respCode;
        end
    end
    else begin
        qv_respCode <= qv_respCode;
    end
end

reg     [31:0]          qv_cur_wqe_offset;
//-- qv_cur_wqe_offset -- Indicates current position in 512B
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_cur_wqe_offset <= 'd0;      
    end
    else if (RWM_cur_state == RWM_MEM_WAIT_s) begin
        qv_cur_wqe_offset <= 'd0;
    end
    else if (RWM_cur_state == RWM_WQE_SPLIT_s && (iv_vtp_download_data != 0) && !i_vtp_download_empty) begin
        qv_cur_wqe_offset <= qv_cur_wqe_offset + 1;
    end
    else if (RWM_cur_state == RWM_WQE_SPLIT_s && (iv_vtp_download_data == 0) && !i_vtp_download_empty) begin
        qv_cur_wqe_offset <= 'd0;
    end
    else begin
        qv_cur_wqe_offset <= qv_cur_wqe_offset;
    end
end              

//-- qv_offset_in_flush --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_offset_in_flush <= 'd0;        
    end
    else if(RWM_cur_state == RWM_IDLE_s) begin
        qv_offset_in_flush <= 'd0;
    end
    else if (RWM_cur_state == RWM_WQE_SPLIT_s && RWM_next_state == RWM_FLUSH_s) begin
        qv_offset_in_flush <= qv_cur_wqe_offset;
    end
    else if (RWM_cur_state == RWM_FLUSH_s && !i_vtp_download_empty && !w_meet_wqe_block_boundary) begin
        qv_offset_in_flush <= qv_offset_in_flush + 1;     
    end
    else begin
        qv_offset_in_flush <= qv_offset_in_flush;
    end
end

//-- qv_next_wqe_size --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_next_wqe_size <= 'd0;
    end
    else if (RWM_cur_state == RWM_MEM_WAIT_s && !i_vtp_download_empty) begin
        qv_next_wqe_size <= iv_vtp_download_data[36:32];    //Next WQE Size
    end
    else if (RWM_cur_state == RWM_WQE_SPLIT_s && qv_cur_wqe_offset == 0 && !i_vtp_download_empty) begin
        qv_next_wqe_size <= iv_vtp_download_data[36:32];
    end
    else begin
        qv_next_wqe_size <= qv_next_wqe_size;
    end
end

//-- qv_next_wqe_addr --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_next_wqe_addr <= 'd0;
    end
    else if (RWM_cur_state == RWM_MEM_WAIT_s && !i_vtp_download_empty) begin
		//In case of wrap around, we pretend to drag the space to the tail
        qv_next_wqe_addr <= (iv_vtp_download_data[31:6] < qv_cur_rq_offset) ? (iv_vtp_download_data[31:6] + wv_RQ_Length / 16) : iv_vtp_download_data[31:6];    //Next WQE Addr, in unit of 16B
    end
    else if (RWM_cur_state == RWM_WQE_SPLIT_s && qv_cur_wqe_offset == 0 && !i_vtp_download_empty) begin
        qv_next_wqe_addr <= (iv_vtp_download_data[31:6] < qv_cur_rq_offset) ? (iv_vtp_download_data[31:6] + wv_RQ_Length / 16) : iv_vtp_download_data[31:6];    //Next WQE Addr, in unit of 16B
    end
    else begin
        qv_next_wqe_addr <= qv_next_wqe_addr;
    end
end

//-- qv_cur_rq_offset --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_cur_rq_offset <= 'd0;
    end
    else if(RWM_cur_state == RWM_FETCH_ENTRY_s && !w_wqe_available && wv_buffer_space >= 512 && !i_vtp_cmd_prog_full) begin
        qv_cur_rq_offset <= wv_rq_offset_table_doutb / 16; 	//16B-Aligned
    end
    else begin
        qv_cur_rq_offset <= qv_cur_rq_offset;
    end
end

//-- q_vtp_download_rd_en --
always @(*) begin
    if(rst) begin 
        q_vtp_download_rd_en = 1'b0;
    end 
    else if(RWM_cur_state == RWM_WQE_SPLIT_s && !i_vtp_download_empty) begin 
        q_vtp_download_rd_en = 1'b1;
    end 
    else if(RWM_cur_state == RWM_SKIP_s && !i_vtp_download_empty) begin 
        q_vtp_download_rd_en = 1'b1;
    end 
    else if(RWM_cur_state == RWM_FLUSH_s && !i_vtp_download_empty) begin
        q_vtp_download_rd_en = 1'b1;
    end 
    else begin 
        q_vtp_download_rd_en = 1'b0;
    end 
end

/************************************************ MultiQueue Control Begin ****************************************/
assign wv_queue_head = wv_list_doutb[11:0];
assign wv_queue_tail = wv_list_doutb[23:12];
assign w_queue_empty = wv_list_doutb[24];

//-- q_list_wea --
//-- qv_list_dina --
always @(*) begin
    if (rst) begin
        q_list_wea = 1'b0;
		qv_list_addra = 'd0;
        qv_list_dina = {`EMPTY, 24'd0};
    end
    else if(RWM_cur_state == RWM_INIT_s && qv_list_init_counter < `QP_NUM) begin 
        q_list_wea = 1'b1;
		qv_list_addra = qv_list_init_counter;
        qv_list_dina = {`EMPTY, 24'd0};
    end 
    else if (RWM_cur_state == RWM_WQE_SPLIT_s && !i_vtp_download_empty) begin    //When insert the last new element, update tail pointer
        if(qv_SegCounter == 0) begin
            if(iv_vtp_download_data == 'd0) begin //No available WQE back, do not update tail pointer
                q_list_wea = 1'b0;
				qv_list_addra = qv_list_init_counter;
                qv_list_dina = qv_list_dina_TempReg;
            end
            else begin //Available WQE back, but this is not the last entry, do not update the pointer
                q_list_wea = 1'b0;
				qv_list_addra = qv_list_init_counter;
                qv_list_dina = qv_list_dina_TempReg;
            end
        end
        else begin 
            if(iv_vtp_download_data == 'd0) begin  //Meet a delimiter, judge whether this is the last entry we need to store
     //            if(qv_SegCounter == 31) begin   //Last entry of 512B
     //                q_list_wea = 1'b1;
					// qv_list_addra = wv_QPN;
     //                qv_list_dina = {`N_EMPTY, wv_Free_dout, wv_queue_head};
     //            end               
     //            else if(qv_next_wqe_size == 0) begin //Last WQE of 512B, because next WQE is zero
     //                q_list_wea = 1'b1;
					// qv_list_addra = wv_QPN;
     //                qv_list_dina = {`N_EMPTY, wv_Free_dout, wv_queue_head};
     //            end
     //            else if(qv_SegCounter + qv_next_wqe_size > 32) begin //Last WQE of 512B, because next WQE cross 512B boundary 
     //                q_list_wea = 1'b1;
					// qv_list_addra = wv_QPN;
     //                qv_list_dina = {`N_EMPTY, wv_Free_dout, wv_queue_head};
     //            end
     //            else begin
     //                q_list_wea = 1'b0;     //Not last entry of 512B, we do not update the tail pointer
					// qv_list_addra = wv_QPN;
     //                qv_list_dina = qv_list_dina_TempReg;
     //            end
                q_list_wea = 1'b1;
                qv_list_addra = wv_QPN;
                qv_list_dina = {`N_EMPTY, wv_Free_dout, wv_queue_head};               
            end
            else begin //Not a delimiter, store data seg
                if(qv_cur_wqe_offset != 0) begin    
                    q_list_wea = 1'b1;
					qv_list_addra = wv_QPN;
                    qv_list_dina = {`N_EMPTY, wv_Free_dout, (w_queue_empty ? wv_Free_dout : wv_queue_head)};
                end 
                else begin //Next seg is not stored
                    q_list_wea = 1'b0;
					qv_list_addra = wv_QPN;
                    qv_list_dina = qv_list_dina_TempReg;
                end 
            end
        end
    end
    else if (RWM_cur_state == RWM_RELEASE_ENTRY_s) begin //Each time we release the last element, update head pointer
        q_list_wea = 1'b1;
		qv_list_addra = wv_QPN;
        qv_list_dina = {`N_EMPTY, wv_queue_tail, wv_next_doutb};    //Not empty because there exists a delimiter
    end
    else if (RWM_cur_state == RWM_RELEASE_WQE_s) begin 
        if(qv_wqe_release_cnt > 0) begin
            q_list_wea = 1'b1;
			qv_list_addra = wv_QPN;
            //qv_list_dina = {`N_EMPTY, wv_queue_tail, wv_next_doutb};
            qv_list_dina = (wv_queue_head == wv_queue_tail) ? {`EMPTY, wv_queue_tail, wv_queue_head} : {`N_EMPTY, wv_queue_tail, wv_next_doutb};
        end
        else begin //The end of current release
            q_list_wea = 1'b0;
            //qv_list_dina = (wv_queue_head == wv_queue_tail) ? {`EMPTY, wv_queue_tail, wv_queue_head} : {`N_EMPTY, wv_queue_tail, wv_next_doutb};
			qv_list_addra = wv_QPN;
            qv_list_dina = qv_list_dina_TempReg;
        end
    end
	else if (RWM_cur_state == RWM_CLEAR_s) begin
        if(qv_entry_clear_cnt > 0) begin
            q_list_wea = 1'b1;
			qv_list_addra = wv_QPN;
            //qv_list_dina = {`N_EMPTY, wv_queue_tail, wv_next_doutb};
            qv_list_dina = (wv_queue_head == wv_queue_tail) ? {`EMPTY, wv_queue_tail, wv_queue_head} : {`N_EMPTY, wv_queue_tail, wv_next_doutb};
        end
        else begin //The end of current release
            q_list_wea = 1'b0;
            //qv_list_dina = (wv_queue_head == wv_queue_tail) ? {`EMPTY, wv_queue_tail, wv_queue_head} : {`N_EMPTY, wv_queue_tail, wv_next_doutb};
			qv_list_addra = wv_QPN;
            qv_list_dina = qv_list_dina_TempReg;
        end
	end 
    else begin
        q_list_wea = 1'b0;
		qv_list_addra = i_ee_cmd_empty ? 'd0 : wv_QPN;
        qv_list_dina = qv_list_dina_TempReg;
    end
end

//-- qv_list_addra --
//always @(*) begin
//    if (rst) begin
//        qv_list_addra = 'd0;        
//    end
//    else begin
//        qv_list_addra = wv_QPN;
//    end
//end

//-- qv_list_addrb --
always @(*) begin
    if(rst) begin    
        qv_list_addrb = 'd0;
    end 
    else begin 
        qv_list_addrb = i_ee_cmd_empty ? 'd0 : wv_QPN;
    end 
end

reg 		[31:0]			qv_cur_wqe_addr;
reg 		[31:0]			qv_cur_wqe_addr_TempReg;
always @(*) begin
	if(rst) begin
		qv_cur_wqe_addr = 'd0;
	end 
	else if(qv_SegCounter == 'd0) begin //First NextSeg of First WQE back
		qv_cur_wqe_addr = qv_cur_rq_offset * 16;
	end 
	else if(qv_cur_wqe_offset == 'd0) begin //First DataSeg of the following WQE
		qv_cur_wqe_addr = (qv_cur_rq_offset + qv_SegCounter > wv_RQ_Length) ? (qv_cur_rq_offset + qv_SegCounter - wv_RQ_Length) * 16 : (qv_cur_rq_offset + qv_SegCounter) * 16;
	end 
	else begin
		qv_cur_wqe_addr = qv_cur_wqe_addr_TempReg;
	end 
end 

always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_cur_wqe_addr_TempReg <= 'd0;
	end 
	else begin
		qv_cur_wqe_addr_TempReg <= qv_cur_wqe_addr;
	end 
end 

//-- q_content_wea --
//-- qv_content_dina --
always @(*) begin
    if (rst) begin
        q_content_wea = 1'b0;
        qv_content_dina = 'd0;
    end
    else if (RWM_cur_state == RWM_WQE_SPLIT_s && !i_vtp_download_empty) begin
        if(qv_SegCounter == 0) begin    //First 16B will not be stored
            q_content_wea = 1'b0;
            qv_content_dina = qv_content_dina_TempReg;
        end
        else begin
            if(qv_cur_wqe_offset != 0) begin
                if(!i_vtp_download_empty) begin
                    q_content_wea = 1'b1;
                    qv_content_dina = {qv_cur_wqe_addr, iv_vtp_download_data};
                end
                else begin
                    q_content_wea = 1'b0;
                    qv_content_dina = qv_content_dina_TempReg;
                end
            end
            else begin  //qv_cur_wqe_offset == 0 points to the NextSeg, we do not store this Seg
                q_content_wea = 1'b0;
                qv_content_dina = qv_content_dina_TempReg;
            end
        end
    end
    else if(RWM_cur_state == RWM_UPDATE_ENTRY_s) begin
        q_content_wea = 1'b1;
        //qv_content_dina = {wv_Entry_Length, wv_Entry_LKey, wv_Entry_VA};
        qv_content_dina = {wv_content_doutb[159:128], wv_Entry_VA, wv_Entry_LKey, wv_Entry_Length};
    end
    else begin
        q_content_wea = 1'b0;
        qv_content_dina = qv_content_dina_TempReg;
    end
end

//-- qv_content_addra --
always @(*) begin
    if (rst) begin
        qv_content_addra = 'd0;    
    end
    else if (RWM_cur_state == RWM_WQE_SPLIT_s) begin
        if(qv_SegCounter != 0 && qv_cur_wqe_offset != 0) begin
            qv_content_addra = wv_Free_dout;
        end
        else begin
            qv_content_addra = qv_content_addra_TempReg;
        end
    end
    else if (RWM_cur_state == RWM_UPDATE_ENTRY_s) begin
        qv_content_addra = wv_queue_head;
    end
    else begin
        qv_content_addra = qv_content_addra_TempReg;
    end
end

//-- qv_content_addrb --
always @(*) begin
    if(rst) begin 
        qv_content_addrb = 'd0;
    end 
    else if(RWM_cur_state == RWM_RELEASE_ENTRY_s) begin 
		if(qv_entry_release_cnt == 0) begin
			qv_content_addrb = wv_queue_head;
		end 
		else begin
        	qv_content_addrb = wv_next_doutb;		
		end 
    end 
    else if(RWM_cur_state == RWM_RELEASE_WQE_s) begin 
		if(qv_wqe_release_cnt == 0) begin
			qv_content_addrb = wv_queue_head;
		end 
		else begin
        	qv_content_addrb = wv_next_doutb;		
		end 
    end 
	else begin
		qv_content_addrb = i_ee_cmd_empty ? 'd0 : wv_queue_head;	//In Other cases, always point to queue head
	end 
end

//-- q_next_wea --
//-- qv_next_addra --
//-- qv_next_dina --
always @(*) begin
    if (rst) begin
        q_next_wea = 1'b0;
        qv_next_addra = 'd0;
        qv_next_dina = 'd0;       
    end
    else if (RWM_cur_state == RWM_WQE_SPLIT_s) begin
        if(qv_SegCounter != 0 && qv_cur_wqe_offset != 0 && !w_queue_empty && !i_vtp_download_empty) begin
            q_next_wea = 1'b1;
            qv_next_addra = wv_queue_tail;
            qv_next_dina = wv_Free_dout;
        end
        else begin
            q_next_wea = 1'b0;
            qv_next_addra = qv_next_addra_TempReg;
            qv_next_dina = qv_next_dina_TempReg;
        end
    end
    else begin
        q_next_wea = 1'b0;
        qv_next_addra = qv_next_addra_TempReg;
        qv_next_dina = qv_next_dina_TempReg;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_wqe_release_cnt <= 'd0;
    end
    else if (RWM_cur_state == RWM_IDLE_s) begin
        qv_wqe_release_cnt <= 'd0;
    end
    else if (RWM_cur_state == RWM_RELEASE_WQE_s) begin
        qv_wqe_release_cnt <= qv_wqe_release_cnt + 1;
    end
    else begin
        qv_wqe_release_cnt <= qv_wqe_release_cnt;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_entry_release_cnt <= 'd0;
    end
    else if (RWM_cur_state == RWM_IDLE_s) begin
        qv_entry_release_cnt <= 'd0;
    end
    else if (RWM_cur_state == RWM_RELEASE_ENTRY_s) begin
        qv_entry_release_cnt <= qv_entry_release_cnt + 1;
    end
    else begin
        qv_entry_release_cnt <= qv_entry_release_cnt;
	end 
end 

always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_entry_clear_cnt <= 'd0;
    end
    else if (RWM_cur_state == RWM_IDLE_s) begin
        qv_entry_clear_cnt <= 'd0;
    end
    else if (RWM_cur_state == RWM_CLEAR_s) begin
        qv_entry_clear_cnt <= qv_entry_clear_cnt + 1;
    end
    else begin
        qv_entry_clear_cnt <= qv_entry_clear_cnt;
	end 
end 

//-- qv_next_addrb --
always @(*) begin
    if(rst) begin
        qv_next_addrb = 'd0;
    end
    else begin 
        case(RWM_cur_state)
			RWM_RELEASE_ENTRY_s:	if(qv_entry_release_cnt == 0) begin 
										qv_next_addrb = wv_queue_head;
									end 
									else begin 
										qv_next_addrb = wv_next_doutb;
									end 
            RWM_RELEASE_WQE_s:  	if(qv_wqe_release_cnt == 0) begin
                                    	qv_next_addrb = wv_queue_head;
                                	end    
                                	else begin
                                    	qv_next_addrb = wv_next_doutb;
                                	end
            RWM_CLEAR_s:  	if(qv_entry_clear_cnt == 0) begin
                                    	qv_next_addrb = wv_queue_head;
                                	end    
                                	else begin
                                    	qv_next_addrb = wv_next_doutb;
                                	end
            default:        		qv_next_addrb = 'd0;
        endcase
    end 
end

//-- q_Free_wr_en --
//-- qv_Free_din --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_Free_wr_en <= 1'b0;
        qv_Free_din <= 'd0;        
    end
    else if (RWM_cur_state == RWM_INIT_s && (qv_free_init_counter == 0 || qv_Free_din < qv_free_init_counter)) begin 
        q_Free_wr_en <= 1'b1;
        qv_Free_din <= qv_free_init_counter;
    end 
    else if (RWM_cur_state == RWM_RELEASE_ENTRY_s && qv_entry_release_cnt == 0) begin
        q_Free_wr_en <= 1'b1;
        qv_Free_din <= wv_queue_head;
    end
    else if (RWM_cur_state == RWM_RELEASE_WQE_s) begin
		if(qv_wqe_release_cnt > 0) begin
			q_Free_wr_en <= 1'b1;
			qv_Free_din <= wv_queue_head;
		end
		else begin
			q_Free_wr_en <= 1'b0;
			qv_Free_din <= qv_Free_din;
		end 
    end
    else if (RWM_cur_state == RWM_CLEAR_s) begin
		if(qv_entry_clear_cnt > 0) begin
			q_Free_wr_en <= 1'b1;
			qv_Free_din <= wv_queue_head;
		end
		else begin
			q_Free_wr_en <= 1'b0;
			qv_Free_din <= qv_Free_din;
		end 
    end
    else begin
        q_Free_wr_en <= 1'b0;
        qv_Free_din <= qv_Free_din;
    end
end

//-- q_Free_rd_en --
always @(*) begin
    if(rst) begin 
        q_Free_rd_en = 'd0;
    end 
    else begin 
        case(RWM_cur_state) 
            RWM_WQE_SPLIT_s:    if(qv_SegCounter != 0 && qv_cur_wqe_offset != 0 && !w_Free_empty && !i_vtp_download_empty) begin
                                    q_Free_rd_en = 1'b1;
                                end
                                else begin
                                    q_Free_rd_en = 1'b0;
                                end
            default:            q_Free_rd_en = 1'b0;
        endcase
    end 
end


//-- q_list_wea_TempReg --
//-- qv_list_addra_TempReg --
//-- qv_list_dina_TempReg --
//-- qv_list_addrb_TempReg --
//-- q_content_wea_TempReg --
//-- qv_content_addra_TempReg --
//-- qv_content_dina_TempReg --
//-- qv_content_addrb_TempReg --
//-- q_next_wea_TempReg --
//-- qv_next_addra_TempReg --
//-- qv_next_dina_TempReg --
//-- qv_next_addrb_TempReg --
//-- q_rq_offset_table__wea_TempReg --
//-- qv_rq_offset_table_addra_TempReg --
//-- qv_rq_offset_table_dina_TempReg --
//-- qv_rq_offset_table_addrb_TempReg --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_list_wea_TempReg <= 'd0;
        qv_list_addra_TempReg <= 'd0;
        qv_list_dina_TempReg <= 'd0;
        qv_list_addrb_TempReg <= 'd0;
        q_content_wea_TempReg <= 'd0;
        qv_content_addra_TempReg <= 'd0;
        qv_content_dina_TempReg <= 'd0;
        qv_content_addrb_TempReg <= 'd0;
        q_next_wea_TempReg <= 'd0;
        qv_next_addra_TempReg <= 'd0;
        qv_next_dina_TempReg <= 'd0;
        qv_next_addrb_TempReg <= 'd0;
        q_rq_offset_table_wea_TempReg <= 'd0;
        qv_rq_offset_table_addra_TempReg <= 'd0;
        qv_rq_offset_table_dina_TempReg <= 'd0;
        qv_rq_offset_table_addrb_TempReg <= 'd0;
    end
    else begin
        q_list_wea_TempReg <= q_list_wea;
        qv_list_addra_TempReg <= qv_list_addra;
        qv_list_dina_TempReg <= qv_list_dina;
        qv_list_addrb_TempReg <= qv_list_addrb;
        q_content_wea_TempReg <= q_content_wea;
        qv_content_addra_TempReg <= qv_content_addra;
        qv_content_dina_TempReg <= qv_content_dina;
        qv_content_addrb_TempReg <= qv_content_addrb;
        q_next_wea_TempReg <= q_next_wea;
        qv_next_addra_TempReg <= qv_next_addra;
        qv_next_dina_TempReg <= qv_next_dina;
        qv_next_addrb_TempReg <= qv_next_addrb;        
        q_rq_offset_table_wea_TempReg <= q_rq_offset_table_wea;
        qv_rq_offset_table_addra_TempReg <= qv_rq_offset_table_addra;
        qv_rq_offset_table_dina_TempReg <= qv_rq_offset_table_dina;
        qv_rq_offset_table_addrb_TempReg <= qv_rq_offset_table_addrb;        
    end
end

/************************************************ MultiQueue Control End ****************************************/

//-- q_ee_cmd_rd_en --
//Simplified coding
always @(*) begin
    if(rst) begin 
        q_ee_cmd_rd_en = 'd0;
    end 
    else begin 
        q_ee_cmd_rd_en = (RWM_cur_state != RWM_IDLE_s && RWM_cur_state != RWM_INIT_s) && (RWM_next_state == RWM_IDLE_s);
    end 
end

//-- q_ee_resp_wr_en --
//-- qv_ee_resp_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_ee_resp_wr_en <= 'd0;
        qv_ee_resp_data <= 'd0;     
    end
    else if(RWM_cur_state == RWM_RESP_s && !i_ee_resp_prog_full) begin
        q_ee_resp_wr_en <= 'd1;
        qv_ee_resp_data <= {wv_content_doutb, wv_QPN, qv_respCode};        
    end
    else begin
        q_ee_resp_wr_en <= 'd0;
        qv_ee_resp_data <= 'd0;
    end
end

/**************************** RQ Offset Table     *************************/


//-- q_rq_offset_table_wea --
//-- qv_rq_offset_table_addra --
//-- qv_rq_offset_table_dina --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_rq_offset_table_wea <= 'd0;
        qv_rq_offset_table_addra <= 'd0;
        qv_rq_offset_table_dina <= 'd0;       
    end
    else if (RWM_cur_state == RWM_INIT_s && qv_list_init_counter < `QP_NUM) begin
        q_rq_offset_table_wea <= 'd1;
        qv_rq_offset_table_addra <= qv_list_init_counter;
        qv_rq_offset_table_dina <= 'd0;           
    end
    else if(RWM_cur_state == RWM_FETCH_ENTRY_s && !w_wqe_available && wv_buffer_space >= 512) begin
        q_rq_offset_table_wea <= 'd0;
        qv_rq_offset_table_addra <= 'd0;
        qv_rq_offset_table_dina <= wv_rq_offset_table_doutb;    //Prepare for WQE_SPLIT if necessary
    end
    else if (RWM_cur_state == RWM_WQE_SPLIT_s && !i_vtp_download_empty) begin 
        if(qv_SegCounter == 0) begin
            if(iv_vtp_download_data == 128'd0) begin    //No available WQE back
                q_rq_offset_table_wea <= 'd0;
                qv_rq_offset_table_addra <= 'd0;
                qv_rq_offset_table_dina <= 'd0; 
            end
            else begin
                q_rq_offset_table_wea <= 'd1;
                qv_rq_offset_table_addra <= wv_QPN;
                qv_rq_offset_table_dina <= (qv_rq_offset_table_dina + 16 == wv_RQ_Length) ? 'd0 : qv_rq_offset_table_dina + 16;
            end
        end
        else if(!i_vtp_download_empty) begin
            q_rq_offset_table_wea <= 'd1;
            qv_rq_offset_table_addra <= wv_QPN;
            qv_rq_offset_table_dina <= (qv_rq_offset_table_dina + 16 == wv_RQ_Length) ? 'd0 : qv_rq_offset_table_dina + 16;
        end
        else begin
            q_rq_offset_table_wea <= 'd0;
            qv_rq_offset_table_addra <= wv_QPN;
            qv_rq_offset_table_dina <= qv_rq_offset_table_dina;               
        end
    end 
    else if(RWM_cur_state == RWM_SKIP_s && !i_vtp_download_empty) begin
        q_rq_offset_table_wea <= 'd1;
        qv_rq_offset_table_addra <= wv_QPN;
        qv_rq_offset_table_dina <= (qv_rq_offset_table_dina + 16 == wv_RQ_Length) ? 'd0 : qv_rq_offset_table_dina + 16;
    end
    else if(RWM_cur_state == RWM_FLUSH_s && !w_meet_wqe_block_boundary && !i_vtp_download_empty) begin
        q_rq_offset_table_wea <= 'd1;
        qv_rq_offset_table_addra <= wv_QPN;
        qv_rq_offset_table_dina <= (qv_rq_offset_table_dina + 16 == wv_RQ_Length) ? 'd0 : qv_rq_offset_table_dina + 16;
    end
    else begin
        q_rq_offset_table_wea <= 'd0;
        qv_rq_offset_table_addra <= i_ee_cmd_empty ? 'd0 : wv_QPN;
        qv_rq_offset_table_dina <= qv_rq_offset_table_dina;    
    end
end


//-- qv_rq_offset_table_addrb --
always @(*) begin
    if(rst) begin
        qv_rq_offset_table_addrb = 'd0;
    end
    else begin 
        qv_rq_offset_table_addrb = i_ee_cmd_empty ? 'd0 : wv_QPN;
    end 
end

/**************************** VTP control signals *************************/
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
    else if (RWM_cur_state == RWM_FETCH_ENTRY_s) begin 
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
end 

//-- q_vtp_cmd_wr_en --
//-- qv_vtp_cmd_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_vtp_cmd_wr_en <= 'd0;
        qv_vtp_cmd_data <= 'd0;
    end
    else if(RWM_cur_state == RWM_FETCH_ENTRY_s && !w_wqe_available && wv_buffer_space >= 512 && !i_vtp_cmd_prog_full) begin
		if(wv_rq_offset_table_doutb + 'd512 <= wv_RQ_Length) begin
        	q_vtp_cmd_wr_en <= 'd1;
        	qv_vtp_cmd_data <= {32'd0, 32'd512, {40'd0, wv_rq_offset_table_doutb}, wv_RQ_LKey, wv_PD, wv_vtp_flags, 24'd0, `RD_RQ_WQE, `RD_REQ_WQE};
		end 
		else begin
			q_vtp_cmd_wr_en <= 'd1;
        	qv_vtp_cmd_data <= {32'd0, (wv_RQ_Length - wv_rq_offset_table_doutb), {40'd0, wv_rq_offset_table_doutb}, wv_RQ_LKey, wv_PD, wv_vtp_flags, 24'd0, `RD_RQ_WQE, `RD_REQ_WQE};
		end 
    end
	else if(RWM_cur_state == RWM_RQ_WRAP_s && !i_vtp_cmd_prog_full) begin
		q_vtp_cmd_wr_en <= 'd1;
        qv_vtp_cmd_data <= {32'd0, ('d512 - (wv_RQ_Length - wv_rq_offset_table_doutb)), 64'd0, wv_RQ_LKey, wv_PD, wv_vtp_flags, 24'd0, `RD_RQ_WQE, `RD_REQ_WQE};
		
	end 
    else begin
        q_vtp_cmd_wr_en <= 'd0;
        qv_vtp_cmd_data <= qv_vtp_cmd_data;
    end
end

//-- q_vtp_resp_rd_en --
always @(*) begin
    if(rst) begin 
        q_vtp_resp_rd_en = 1'b0;
    end 
	else if(RWM_cur_state == RWM_WQE_SPLIT_s) begin	//Clear resp FIFO in this state
		q_vtp_resp_rd_en = 1'b1;
	end 
    else begin
        q_vtp_resp_rd_en = 1'b0; 		//We do not care about this resp, directly clear it
    end
end

assign w_clear_finish = (w_queue_empty) || (!w_queue_empty && q_list_wea && qv_list_dina[24] == `EMPTY);

//Funny 	Funny_Inst(
//	.clk(clk),
//	.rst(rst)
//);

/*----------------------------- Connect dbg bus -------------------------------------*/
wire   [`DBG_NUM_RECV_WQE_MANAGER * 32  - 1 : 0]   coalesced_bus;

assign coalesced_bus = {
                            q_ee_cmd_rd_en,
                            q_ee_resp_wr_en,
                            q_vtp_cmd_wr_en,
                            q_vtp_resp_rd_en,
                            q_vtp_download_rd_en,
                            q_list_wea,
                            q_content_wea,
                            q_next_wea,
                            q_Free_wr_en,
                            q_Free_rd_en,
                            q_rq_offset_table_wea,
                            q_list_wea_TempReg,
                            q_content_wea_TempReg,
                            q_next_wea_TempReg,
                            q_rq_offset_table_wea_TempReg,
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
                            w_meet_wqe_block_boundary,
                            w_clear_finish,
                            wv_OpCode, 
                            qv_mthca_mpt_flag_sw_owns,
                            qv_wqe_release_cnt,
                            qv_respCode,
                            RWM_cur_state,
                            RWM_next_state,
                            wv_RQ_Entry_Size_Log,
                            qv_content_addra,
                            qv_content_addrb,
                            qv_next_addra,
                            qv_next_dina,
                            qv_next_addrb,
                            qv_Free_din,
                            qv_content_addra_TempReg,
                            qv_content_addrb_TempReg,
                            qv_next_addra_TempReg,
                            qv_next_dina_TempReg,
                            qv_next_addrb_TempReg,
                            wv_next_doutb,
                            wv_next_doutb_fake,
                            wv_Free_dout,
                            wv_queue_head,
                            wv_queue_tail,
                            qv_list_addra,
                            qv_list_addrb,
                            qv_rq_offset_table_addra,
                            qv_rq_offset_table_addrb,
                            qv_list_addra_TempReg,
                            qv_list_addrb_TempReg,
                            qv_rq_offset_table_addra_TempReg,
                            qv_rq_offset_table_addrb_TempReg,
                            qv_SegCounter,
                            qv_next_wqe_size,
                            wv_rq_wqe_block_size,
                            wv_cur_wqe_block_boundary,
                            qv_cur_rq_offset,
                            qv_rq_offset_table_dina,
                            qv_rq_offset_table_dina_TempReg,
                            wv_QPN,
                            wv_rq_offset_table_doutb,
                            wv_rq_offset_table_doutb_fake,
                            qv_list_dina,
                            qv_list_dina_TempReg,
                            wv_list_doutb,
                            wv_list_doutb_fake,
                            qv_next_wqe_addr,
                            qv_offset_in_flush,
                            qv_free_init_counter,
                            qv_list_init_counter,
                            qv_cur_wqe_offset,
                            wv_PD,
                            wv_RQ_LKey,
                            wv_RQ_Length,
                            wv_Entry_Length,
                            wv_Entry_LKey,
                            wv_buffer_space,
                            wv_vtp_flags,
                            wv_Entry_VA,
                            wv_content_doutb,
                            wv_content_doutb_fake,
                            qv_content_dina_TempReg,
                            qv_content_dina,
                            qv_ee_resp_data,
                            qv_vtp_cmd_data,
                            
                            wv_Free_data_count
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
                    (dbg_sel == 69) ?   coalesced_bus[32 * 70 - 1 : 32 * 69] : 32'd0;

//assign dbg_bus = coalesced_bus;

assign init_rw_data = 'd0;

endmodule
