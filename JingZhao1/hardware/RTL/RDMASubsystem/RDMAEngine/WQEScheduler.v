`timescale 1ns / 1ps

`include "chip_include_rdma.vh"
module WQEScheduler( //"ws" for short
    input   wire                clk,
    input   wire                rst,

//Interface with DoorbellProcesing
    input   wire                i_md_from_db_empty,
    output  wire                o_md_from_db_rd_en,
    input   wire    [255:0]     iv_md_from_db_data,

//WQEParser
    input   wire                i_md_from_wp_empty,
    output  wire                o_md_from_wp_rd_en,
    input   wire    [255:0]     iv_md_from_wp_data,

    input   wire                i_md_to_wp_prog_full,
    output  wire                o_md_to_wp_wr_en,
    output  wire    [255:0]     ov_md_to_wp_data,

    input   wire                i_wqe_to_wp_prog_full,
    output  wire                o_wqe_to_wp_wr_en,
    output  wire    [127:0]     ov_wqe_to_wp_data,

//Interface with VirtToPhys, receive WQE From Host Memory
    input   wire                i_wqe_from_db_empty,
    output  wire                o_wqe_from_db_rd_en,
    input   wire    [127:0]     iv_wqe_from_db_data,

    input   wire                i_wqe_from_wp_empty,
    output  wire                o_wqe_from_wp_rd_en,
    input   wire    [127:0]     iv_wqe_from_wp_data,

//WQE Indicator Table
    output  wire    [13:0]      ov_wit_rd_addr,
    input   wire    [0:0]       iv_wit_rd_data,

	input   wire    [31:0]      dbg_sel,
    output  wire    [32 - 1:0]      dbg_bus
    //output  wire    [`DBG_NUM_WQE_SCHEDULER * 32 - 1:0]      dbg_bus
);

reg 						q_cur_is_wp;
reg                			q_md_to_wp_wr_en;
reg    		[255:0]     	qv_md_to_wp_data;
reg    		            	q_wqe_to_wp_wr_en;
reg    		[127:0]     	qv_wqe_to_wp_data;
reg     	[7:0]           qv_wqe_seg_counter;
reg 		[7:0]			qv_wqe_16B_total;		
reg 						q_md_from_wp_rd_en;
reg 						q_md_from_db_rd_en;
reg 						q_wqe_from_wp_rd_en;
reg 						q_wqe_from_db_rd_en;

wire 		[15:0]			wv_wqe_16B_total;
wire                    	w_pending;

assign o_md_to_wp_wr_en = q_md_to_wp_wr_en;
assign ov_md_to_wp_data = qv_md_to_wp_data;

assign o_wqe_to_wp_wr_en = q_wqe_to_wp_wr_en;
assign ov_wqe_to_wp_data = qv_wqe_to_wp_data;


//State machine to handle different WQE Queues(One from Doorbell Processing, the other from Memory)
parameter       [3:0]   
                SCH_IDLE_s = 4'd1,
                SCH_FROM_DBQ_JUDGE_s = 4'd2,
                SCH_FROM_DBQ_PROC_s = 4'd3,
                SCH_FROM_MEMQ_PROC_s = 4'd4,
				SCH_DROP_s = 4'd5;

reg             [3:0]          Sch_Wqe_cur_state;
reg             [3:0]          Sch_Wqe_next_state;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        Sch_Wqe_cur_state <= SCH_IDLE_s;
    end
    else begin
        Sch_Wqe_cur_state <= Sch_Wqe_next_state;
    end
end

always @(*) begin
    case(Sch_Wqe_cur_state) 
        SCH_IDLE_s:       		if(!q_cur_is_wp) begin      
									if(!i_wqe_from_wp_empty && !i_md_from_wp_empty) begin
                                	    Sch_Wqe_next_state = SCH_FROM_MEMQ_PROC_s;
                                	end
                                	else if(!i_wqe_from_db_empty && !i_md_from_db_empty) begin
                                	    Sch_Wqe_next_state = SCH_FROM_DBQ_JUDGE_s;
                                	end
                                	else begin
                                	    Sch_Wqe_next_state = SCH_IDLE_s;
                                	end
								end
								else begin
									if(!i_wqe_from_db_empty && !i_md_from_db_empty) begin
                                	    Sch_Wqe_next_state = SCH_FROM_DBQ_JUDGE_s;
                                	end
                                	else if(!i_wqe_from_wp_empty && !i_md_from_wp_empty) begin
                                	    Sch_Wqe_next_state = SCH_FROM_MEMQ_PROC_s;
                                	end
                                	else begin
                                	    Sch_Wqe_next_state = SCH_IDLE_s;
                                	end
								end 
        SCH_FROM_MEMQ_PROC_s:   if(qv_wqe_seg_counter == 1) begin
                                    if(!i_wqe_from_wp_empty && !i_wqe_to_wp_prog_full) begin
										if(qv_wqe_16B_total[0]) begin 	//Need to drop
	                                        Sch_Wqe_next_state = SCH_DROP_s;
										end 
										else begin
											Sch_Wqe_next_state = SCH_IDLE_s;
										end 
                                    end
                                    else begin
                                        Sch_Wqe_next_state = SCH_FROM_MEMQ_PROC_s;
                                    end
                                end
                                else begin
                                    Sch_Wqe_next_state = SCH_FROM_MEMQ_PROC_s;
                                end
        SCH_FROM_DBQ_JUDGE_s:   if(w_pending) begin
                                    Sch_Wqe_next_state = SCH_IDLE_s;
                                end
                                else begin
                                    Sch_Wqe_next_state = SCH_FROM_DBQ_PROC_s;
                                end

        SCH_FROM_DBQ_PROC_s:    if(qv_wqe_seg_counter == 1) begin
                                    if(!i_wqe_from_db_empty && !i_wqe_to_wp_prog_full) begin
										if(qv_wqe_16B_total[0]) begin
											Sch_Wqe_next_state = SCH_DROP_s;
										end 
										else begin
	                                        Sch_Wqe_next_state = SCH_IDLE_s;
										end 
                                    end
                                    else begin
                                        Sch_Wqe_next_state = SCH_FROM_DBQ_PROC_s;
                                    end
                                end
                                else begin
                                    Sch_Wqe_next_state = SCH_FROM_DBQ_PROC_s;
                                end
		SCH_DROP_s:				if(q_cur_is_wp && !i_wqe_from_wp_empty) begin
									Sch_Wqe_next_state = SCH_IDLE_s;
								end 
								else if(!q_cur_is_wp && !i_wqe_from_db_empty) begin
									Sch_Wqe_next_state = SCH_IDLE_s;
								end 
								else begin
									Sch_Wqe_next_state = SCH_DROP_s;
								end 
        default:                Sch_Wqe_next_state = SCH_IDLE_s;
    endcase
end

//-- q_cur_is_wp --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		q_cur_is_wp <= 'd0;
	end 
	else if(Sch_Wqe_cur_state == SCH_FROM_MEMQ_PROC_s) begin
		q_cur_is_wp <= 'd1;
	end 
	else if(Sch_Wqe_cur_state == SCH_FROM_DBQ_PROC_s || Sch_Wqe_cur_state == SCH_FROM_DBQ_JUDGE_s) begin
		q_cur_is_wp <= 'd0;
	end 
	else begin
		q_cur_is_wp <= q_cur_is_wp;
	end 
end 


//-- w_pending -- Indicates whether there is unfinished WQEs in the WQE-list of a specific QP
assign w_pending = iv_wit_rd_data[0];

assign ov_wit_rd_addr = iv_md_from_db_data[17:8];    //Lower 10-bits of QPN is used as the table index

always @(*) begin
	if(rst) begin
		q_wqe_from_db_rd_en = 'd0;
	end 
	else if(Sch_Wqe_cur_state == SCH_FROM_DBQ_PROC_s) begin
		if(qv_wqe_seg_counter == qv_wqe_16B_total && !i_wqe_to_wp_prog_full && !i_md_to_wp_prog_full) begin
			q_wqe_from_db_rd_en = 'd1;
		end 
		else if(qv_wqe_seg_counter != qv_wqe_16B_total && !i_wqe_from_db_empty && !i_wqe_to_wp_prog_full) begin
			q_wqe_from_db_rd_en = 'd1;
		end 
		else begin
			q_wqe_from_db_rd_en = 'd0;	
		end 	
	end 
	else if(Sch_Wqe_cur_state == SCH_DROP_s && !q_cur_is_wp && !i_wqe_from_db_empty) begin
		q_wqe_from_db_rd_en = 'd1;
	end 
	else begin
		q_wqe_from_db_rd_en = 'd0;
	end 
end 

always @(*) begin
	if(rst) begin
		q_wqe_from_wp_rd_en = 'd0;
	end 
	else if(Sch_Wqe_cur_state == SCH_FROM_MEMQ_PROC_s) begin
		if(qv_wqe_seg_counter == qv_wqe_16B_total && !i_wqe_to_wp_prog_full && !i_md_to_wp_prog_full) begin
			q_wqe_from_wp_rd_en = 'd1;
		end 
		else if(qv_wqe_seg_counter != qv_wqe_16B_total && !i_wqe_from_wp_empty && !i_wqe_to_wp_prog_full) begin
			q_wqe_from_wp_rd_en = 'd1;
		end 
		else begin
			q_wqe_from_wp_rd_en = 'd0;	
		end 	
	end 
	else if(Sch_Wqe_cur_state == SCH_DROP_s && q_cur_is_wp && !i_wqe_from_wp_empty) begin
		q_wqe_from_wp_rd_en = 'd1;
	end 
	else begin
		q_wqe_from_wp_rd_en = 'd0;
	end 
end 

always @(*) begin
	if(rst) begin
		q_md_from_db_rd_en = 'd0;
	end 
	else if(Sch_Wqe_cur_state == SCH_FROM_DBQ_PROC_s && q_md_to_wp_wr_en) begin
		//if(qv_wqe_seg_counter == 'd1 && !i_wqe_from_db_empty && !i_wqe_to_wp_prog_full && !i_md_to_wp_prog_full) begin
		//	q_md_from_db_rd_en = 'd1;
		//end 
		//else begin
		//	q_md_from_db_rd_en = 'd0;
		//end 
		q_md_from_db_rd_en = 'd1;
	end 
	else begin
		q_md_from_db_rd_en = 'd0;
	end 
end 

always @(*) begin
	if(rst) begin
		q_md_from_wp_rd_en = 'd0;
	end 
	else if(Sch_Wqe_cur_state == SCH_FROM_MEMQ_PROC_s && q_md_to_wp_wr_en) begin
		//if(qv_wqe_seg_counter == 'd1 && !i_wqe_from_wp_empty && !i_wqe_to_wp_prog_full && !i_md_to_wp_prog_full) begin
		//	q_md_from_wp_rd_en = 'd1;
		//end 
		//else begin
		//	q_md_from_wp_rd_en = 'd0;
		//end 
		q_md_from_wp_rd_en = 'd1;
	end 
	else begin
		q_md_from_wp_rd_en = 'd0;
	end 
end 

//-- o_wqe_from_db_rd_en -
assign o_wqe_from_db_rd_en = q_wqe_from_db_rd_en;

//-- o_md_from_db_rd_en --
assign o_md_from_db_rd_en = q_md_from_db_rd_en;

//-- o_wqe_from_wp_rd_en --
assign o_wqe_from_wp_rd_en = q_wqe_from_wp_rd_en;

//-- w_s2_back_md_rd_en --
assign o_md_from_wp_rd_en = q_md_from_wp_rd_en;

assign wv_wqe_16B_total = ((Sch_Wqe_cur_state == SCH_IDLE_s) && (Sch_Wqe_next_state == SCH_FROM_DBQ_JUDGE_s)) ? (iv_md_from_db_data[175:160]) : (iv_md_from_wp_data[175:160]); 


//-- qv_wqe_16B_total -- Indicates how many 16B are in a WQE
always @(posedge clk or posedge rst) begin 
	if(rst) begin 
		qv_wqe_16B_total <= 'd0;
	end
    else if (Sch_Wqe_cur_state == SCH_IDLE_s && Sch_Wqe_next_state == SCH_FROM_DBQ_JUDGE_s) begin
        qv_wqe_16B_total <= wv_wqe_16B_total;
    end
    else if (Sch_Wqe_cur_state == SCH_IDLE_s && Sch_Wqe_next_state == SCH_FROM_MEMQ_PROC_s) begin
        qv_wqe_16B_total <= wv_wqe_16B_total;
    end
	else begin 
		qv_wqe_16B_total <= qv_wqe_16B_total;
	end 
end 

//-- qv_wqe_seg_counter  -- Indicates how many segments left for a received WQE, Pipeline stage 2 has a similar counter
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_wqe_seg_counter <= 0;        
    end
    else if (Sch_Wqe_cur_state == SCH_IDLE_s && Sch_Wqe_next_state == SCH_FROM_DBQ_JUDGE_s) begin
        qv_wqe_seg_counter <= wv_wqe_16B_total;
    end
    else if (Sch_Wqe_cur_state == SCH_IDLE_s && Sch_Wqe_next_state == SCH_FROM_MEMQ_PROC_s) begin
        qv_wqe_seg_counter <= wv_wqe_16B_total;
    end
    else if (Sch_Wqe_cur_state == SCH_FROM_DBQ_PROC_s && q_wqe_from_db_rd_en) begin
        qv_wqe_seg_counter <= qv_wqe_seg_counter - 1;
    end
    else if (Sch_Wqe_cur_state == SCH_FROM_MEMQ_PROC_s && q_wqe_from_wp_rd_en) begin
        qv_wqe_seg_counter <= qv_wqe_seg_counter - 1;
    end
    else begin
        qv_wqe_seg_counter <= qv_wqe_seg_counter;
    end
end

//-- q_wqe_to_wp_wr_en --
//-- qv_wqe_to_wp_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_wqe_to_wp_wr_en <= 1'b0;
        qv_wqe_to_wp_data <= 256'h0;        
    end
    else if (Sch_Wqe_cur_state == SCH_FROM_DBQ_PROC_s) begin
		if(qv_wqe_seg_counter == qv_wqe_16B_total && !i_md_to_wp_prog_full && !i_wqe_to_wp_prog_full) begin
        	q_wqe_to_wp_wr_en <= 1'b1;
        	qv_wqe_to_wp_data <= iv_wqe_from_db_data;
		end 
		else if(qv_wqe_seg_counter != qv_wqe_16B_total && !i_wqe_from_db_empty && !i_wqe_to_wp_prog_full) begin
        	q_wqe_to_wp_wr_en <= 1'b1;
        	qv_wqe_to_wp_data <= iv_wqe_from_db_data;
		end 
		else begin
        	q_wqe_to_wp_wr_en <= 1'b0;
        	qv_wqe_to_wp_data <= qv_wqe_to_wp_data;
		end 
    end
    else if (Sch_Wqe_cur_state == SCH_FROM_MEMQ_PROC_s) begin
		if(qv_wqe_seg_counter == qv_wqe_16B_total && !i_md_to_wp_prog_full && !i_wqe_to_wp_prog_full) begin
        	q_wqe_to_wp_wr_en <= 1'b1;
        	qv_wqe_to_wp_data <= iv_wqe_from_wp_data;
		end 
		else if(qv_wqe_seg_counter != qv_wqe_16B_total && !i_wqe_from_wp_empty && !i_wqe_to_wp_prog_full) begin
        	q_wqe_to_wp_wr_en <= 1'b1;
        	qv_wqe_to_wp_data <= iv_wqe_from_wp_data;
		end 
		else begin
        	q_wqe_to_wp_wr_en <= 1'b0;
        	qv_wqe_to_wp_data <= qv_wqe_to_wp_data;
		end 
    end
    else begin
        q_wqe_to_wp_wr_en <= 1'b0;
        qv_wqe_to_wp_data <= qv_wqe_to_wp_data;
    end
end

//-- q_md_to_wp_wr_en --
//-- qv_md_to_wp_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_md_to_wp_wr_en <= 1'b0;
        qv_md_to_wp_data <= 64'h0;
    end
    else if (Sch_Wqe_cur_state == SCH_FROM_DBQ_PROC_s && (qv_wqe_seg_counter == qv_wqe_16B_total) 
				&& !i_wqe_to_wp_prog_full && !i_md_to_wp_prog_full) begin
        q_md_to_wp_wr_en <= 1'b1;
        qv_md_to_wp_data <= iv_md_from_db_data;
    end
    else if (Sch_Wqe_cur_state == SCH_FROM_MEMQ_PROC_s && (qv_wqe_seg_counter == qv_wqe_16B_total) 
				&& !i_wqe_to_wp_prog_full && !i_md_to_wp_prog_full) begin
        q_md_to_wp_wr_en <= 1'b1;
        qv_md_to_wp_data <= iv_md_from_wp_data;
    end
    else begin
        q_md_to_wp_wr_en <= 1'b0;
        qv_md_to_wp_data <= qv_md_to_wp_data;        
    end
end

//Connect dbg signals
assign dbg_bus =    (dbg_sel == 0) ? {
											q_wqe_to_wp_wr_en,
											q_cur_is_wp,
											w_pending,
											q_md_to_wp_wr_en,
											q_md_from_wp_rd_en,
											q_md_from_db_rd_en,
											q_wqe_from_wp_rd_en,
											q_wqe_from_db_rd_en
                                        }   :
                    (dbg_sel == 1)  ?  Sch_Wqe_cur_state :
                    (dbg_sel == 2)  ?  Sch_Wqe_next_state :
                    (dbg_sel == 3)  ?  qv_wqe_seg_counter :
                    (dbg_sel == 4)  ?  qv_wqe_16B_total :
                    (dbg_sel == 5)  ?  wv_wqe_16B_total :
                    (dbg_sel == 6)  ?  qv_wqe_to_wp_data[31:0]  :
                    (dbg_sel == 7)  ?  qv_wqe_to_wp_data[63:32]  :
                    (dbg_sel == 8)  ?  qv_wqe_to_wp_data[95:64]  :
                    (dbg_sel == 9)  ?  qv_wqe_to_wp_data[127:96] :
                    (dbg_sel == 10) ?  qv_md_to_wp_data[31:0] :
                    (dbg_sel == 11) ?  qv_md_to_wp_data[63:32] :
                    (dbg_sel == 12) ?  qv_md_to_wp_data[95:64] :
                    (dbg_sel == 13) ?  qv_md_to_wp_data[127:96] :
                    (dbg_sel == 14) ?  qv_md_to_wp_data[159:128] :
                    (dbg_sel == 15) ?  qv_md_to_wp_data[191:160] :
                    (dbg_sel == 16) ?  qv_md_to_wp_data[223:192] :
                    (dbg_sel == 17) ?  qv_md_to_wp_data[255:224] : 32'd0;

//assign dbg_bus =    {
//						q_wqe_to_wp_wr_en,
//						q_cur_is_wp,
//						w_pending,
//						q_md_to_wp_wr_en,
//						q_md_from_wp_rd_en,
//						q_md_from_db_rd_en,
//						q_wqe_from_wp_rd_en,
//						q_wqe_from_db_rd_en,
//                    	Sch_Wqe_cur_state,
//                    	Sch_Wqe_next_state,
//                    	qv_wqe_seg_counter,
//                    	qv_wqe_16B_total,
//                    	wv_wqe_16B_total,
//                    	qv_wqe_to_wp_data[31:0] ,
//                    	qv_wqe_to_wp_data[63:32] ,
//                    	qv_wqe_to_wp_data[95:64] ,
//                    	qv_wqe_to_wp_data[127:96],
//                    	qv_md_to_wp_data[31:0],
//                    	qv_md_to_wp_data[63:32],
//                    	qv_md_to_wp_data[95:64],
//                    	qv_md_to_wp_data[127:96],
//                    	qv_md_to_wp_data[159:128],
//                    	qv_md_to_wp_data[191:160],
//                    	qv_md_to_wp_data[223:192],
//                    	qv_md_to_wp_data[255:224]
//};

endmodule



