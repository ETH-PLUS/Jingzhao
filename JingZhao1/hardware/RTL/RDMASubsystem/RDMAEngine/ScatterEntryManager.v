`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/10/29 09:43:08
// Design Name: 
// Module Name: ScatterEntryManager
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
//`define     FETCH_ENTRY     2'b00
//`define     UPDATE_ENTRY    2'b01
//`define     RELEASE_ENTRY   2'b10
//
//`define     VALID_ENTRY     8'h00
//`define     INVALID_ENTRY   8'h01
`include "nic_hw_params.vh"
`include "chip_include_rdma.vh"

`define     FETCH_TIME      3
`define     UPDATE_TIME     0
`define     RELEASE_TIME    1

//`include    "nic_hw_params.vh"

module ScatterEntryManager(
    input   wire                clk,
    input   wire                rst,

//Interface with MultiQueue
    output  wire                o_reb_list_head_web,
    output  wire    [13:0]      ov_reb_list_head_addrb,
    output  wire    [13:0]      ov_reb_list_head_dinb,
    input   wire    [13:0]      iv_reb_list_head_doutb,

    output  wire                o_reb_list_tail_web,
    output  wire    [13:0]      ov_reb_list_tail_addrb,
    output  wire    [13:0]      ov_reb_list_tail_dinb,
    input   wire    [13:0]      iv_reb_list_tail_doutb,

    output  wire                o_reb_list_empty_web,
    output  wire    [13:0]      ov_reb_list_empty_addrb,
    output  wire    [0:0]       ov_reb_list_empty_dinb,
    input   wire    [0:0]       iv_reb_list_empty_doutb,

    output  wire                o_reb_content_web,
    output  wire    [13:0]      ov_reb_content_addrb,
    output  wire    [127:0]     ov_reb_content_dinb,
    input   wire    [127:0]     iv_reb_content_doutb,

    output  wire                o_reb_next_web,
    output  wire    [13:0]      ov_reb_next_addrb,
    output  wire    [14:0]      ov_reb_next_dinb,
    input   wire    [14:0]      iv_reb_next_doutb,

    output  wire    [13:0]      ov_reb_free_data,
    output  wire                o_reb_free_wr_en,
    input   wire                i_reb_free_prog_full,

//Inner connections to RequesterRecvControl
    input   wire                i_cmd_empty,
    output  wire                o_cmd_rd_en,
    input   wire    [159:0]     iv_cmd_data,

    input   wire                i_resp_prog_full,
    output  wire                o_resp_wr_en,
    output  wire    [159:0]     ov_resp_data,
	
    input   wire    [31:0]      dbg_sel,
    output  wire    [32 - 1:0]      dbg_bus,
    //output  wire    [`DBG_NUM_SCATTERENTRY_MANAGER * 32 - 1:0]      dbg_bus,

	output 	wire 				o_sem_init_finish

);

//REB Buffer control signals
reg                     q_reb_list_head_web;
reg    [13:0]           qv_reb_list_head_addrb;
reg    [13:0]           qv_reb_list_head_dinb;

reg                     q_reb_list_tail_web;
reg    [13:0]           qv_reb_list_tail_addrb;
reg    [13:0]           qv_reb_list_tail_dinb;

reg                     q_reb_list_empty_web;
reg    [13:0]           qv_reb_list_empty_addrb;
reg    [0:0]            qv_reb_list_empty_dinb;

reg                     q_reb_content_web;
reg    [13:0]           qv_reb_content_addrb;
reg    [127:0]          qv_reb_content_dinb;

reg                     q_reb_next_web;
reg    [13:0]           qv_reb_next_addrb;
reg    [13:0]           qv_reb_next_dinb;

reg    [13:0]           qv_reb_free_data;
reg                     q_reb_free_wr_en;


reg                     q_cmd_rd_en;
reg                     q_resp_wr_en;
reg    [159:0]          qv_resp_data;

assign o_reb_list_head_web = q_reb_list_head_web;
assign ov_reb_list_head_addrb = qv_reb_list_head_addrb;
assign ov_reb_list_head_dinb = qv_reb_list_head_dinb;

assign o_reb_list_tail_web = q_reb_list_tail_web;
assign ov_reb_list_tail_addrb = qv_reb_list_tail_addrb;
assign ov_reb_list_tail_dinb = qv_reb_list_tail_dinb;

assign o_reb_list_empty_web = q_reb_list_empty_web;
assign ov_reb_list_empty_addrb = qv_reb_list_empty_addrb;
assign ov_reb_list_empty_dinb = qv_reb_list_empty_dinb;

assign o_reb_content_web = q_reb_content_web;
assign ov_reb_content_addrb = qv_reb_content_addrb;
assign ov_reb_content_dinb = qv_reb_content_dinb;

assign o_reb_next_web = q_reb_next_web;
assign ov_reb_next_addrb = qv_reb_next_addrb;
assign ov_reb_next_dinb = qv_reb_next_dinb;

assign ov_reb_free_data = qv_reb_free_data;
assign o_reb_free_wr_en = q_reb_free_wr_en;


assign o_cmd_rd_en = q_cmd_rd_en;
assign o_resp_wr_en = q_resp_wr_en;
assign ov_resp_data = qv_resp_data;

/*----------------------------------------  Part 1: Signals Definition and Submodules Connection ----------------------------------------*/
//wire    [1:0]           wv_opcode;
wire    [2:0]           wv_opcode;
wire    [4:0]           wv_number;
//wire    [5:0]           wv_number;
wire    [23:0]          wv_qpn;
wire    [63:0]          wv_VA;
wire    [31:0]          wv_Key;
wire    [31:0]          wv_Length;

assign wv_opcode = iv_cmd_data[2:0];
assign wv_number = iv_cmd_data[7:3];
assign wv_qpn = iv_cmd_data[31:8];
assign wv_VA = iv_cmd_data[159:96];
assign wv_Key = iv_cmd_data[95:64];
assign wv_Length = iv_cmd_data[63:32];

reg     [3:0]           qv_fetch_state_counter;
reg     [5:0]           qv_release_entry_counter;
reg     [15:0]              qv_reb_free_init_counter;
reg 	[15:0]				qv_reb_list_table_init_counter;

wire 					w_flush_finish;

/*----------------------------------------  Part 2: State Machine Transition ------------------------------------------------------------*/
reg     [6:0]           SEM_cur_state;
reg     [6:0]           SEM_next_state;

parameter       [6:0]       SEM_INIT_s          = 7'b0000001,
                            SEM_IDLE_s          = 7'b0000010,
                            SEM_FETCH_ENTRY_s   = 7'b0000100,
                            SEM_UPDATE_ENTRY_s  = 7'b0001000,
                            SEM_RELEASE_ENTRY_s = 7'b0010000,
							SEM_FLUSH_ENTRY_s 	= 7'b0100000,
							SEM_FORCE_WAIT_s 	= 7'b1000000;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        SEM_cur_state <= SEM_INIT_s;        
    end
    else begin
        SEM_cur_state <= SEM_next_state;
    end
end


always @(*) begin
    case(SEM_cur_state)
        SEM_INIT_s:             if((qv_reb_free_init_counter == `REB_CONTENT_FREE_NUM - 1) && (qv_reb_list_table_init_counter == `QP_NUM - 1))begin
                                    SEM_next_state = SEM_IDLE_s;
                                end
                                else begin
                                    SEM_next_state = SEM_INIT_s;
                                end
        SEM_IDLE_s:             if(!i_cmd_empty) begin
                                    if(wv_opcode == `FETCH_ENTRY) begin
                                        SEM_next_state = SEM_FETCH_ENTRY_s;
                                    end
                                    else if(wv_opcode == `UPDATE_ENTRY) begin
                                        SEM_next_state = SEM_UPDATE_ENTRY_s;
                                    end
                                    else if(wv_opcode == `RELEASE_ENTRY) begin
                                        SEM_next_state = SEM_FORCE_WAIT_s;
                                    end
									else if(wv_opcode == `FLUSH_ENTRY) begin
										SEM_next_state = SEM_FLUSH_ENTRY_s;
									end 
                                    else begin
                                        SEM_next_state = SEM_IDLE_s;
                                    end
                                end
                                else begin
                                    SEM_next_state = SEM_IDLE_s;
                                end
		SEM_FORCE_WAIT_s:		SEM_next_state = SEM_RELEASE_ENTRY_s;
        SEM_FETCH_ENTRY_s:      if(qv_fetch_state_counter == `FETCH_TIME) begin
                                    if(!i_resp_prog_full) begin
                                        SEM_next_state = SEM_IDLE_s;
                                    end
                                    else begin
                                        SEM_next_state = SEM_FETCH_ENTRY_s;
                                    end
                                end
                                else begin
                                    SEM_next_state = SEM_FETCH_ENTRY_s;
                                end
        SEM_UPDATE_ENTRY_s:     SEM_next_state = SEM_IDLE_s;    //One cycle for update
        SEM_RELEASE_ENTRY_s:    if(qv_release_entry_counter == 1) begin
                                    SEM_next_state = SEM_IDLE_s;
                                end
                                else begin
                                    SEM_next_state = SEM_RELEASE_ENTRY_s;
                                end
		SEM_FLUSH_ENTRY_s:		if(w_flush_finish) begin
									SEM_next_state = SEM_IDLE_s;
								end 
								else begin
									SEM_next_state = SEM_FLUSH_ENTRY_s;
								end 
        default:                SEM_next_state = SEM_IDLE_s;
    endcase
end

/*----------------------------------------  Part 3: Output Registers Decode -------------------------------------------------------------*/


assign o_sem_init_finish = (qv_reb_free_init_counter == `REB_CONTENT_FREE_NUM - 1) && (qv_reb_list_table_init_counter == `QP_NUM - 1);

//-- qv_reb_free_init_counter --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_reb_free_init_counter <= 'd0;        
    end
    else if (SEM_cur_state == SEM_INIT_s && qv_reb_free_init_counter < `REB_CONTENT_FREE_NUM - 1) begin
        qv_reb_free_init_counter <= qv_reb_free_init_counter + 1;
    end
    else begin
        qv_reb_free_init_counter <= qv_reb_free_init_counter;
    end
end

//-- qv_reb_list_table_init_counter --
always @(posedge clk or posedge rst) begin
	if(rst) begin 
		qv_reb_list_table_init_counter <= 'd0;
	end 
	else if(SEM_cur_state == SEM_INIT_s && qv_reb_list_table_init_counter < `QP_NUM - 1) begin 
		qv_reb_list_table_init_counter <= qv_reb_list_table_init_counter + 1;
	end 
	else begin 
		qv_reb_list_table_init_counter <= qv_reb_list_table_init_counter;
	end 
end 

//-- qv_fetch_state_counter -- 
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_fetch_state_counter <= 'd0;        
    end
    else if (SEM_cur_state == SEM_IDLE_s) begin
        qv_fetch_state_counter <= 'd0;
    end
    else if (SEM_cur_state == SEM_FETCH_ENTRY_s && qv_fetch_state_counter < `FETCH_TIME) begin
        qv_fetch_state_counter <= qv_fetch_state_counter + 1;
    end
    else begin
        qv_fetch_state_counter <= qv_fetch_state_counter;
    end
end

//-- qv_release_entry_counter --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_release_entry_counter <= 'd0;        
    end
    //else if (SEM_cur_state == SEM_IDLE_s && SEM_next_state == SEM_RELEASE_ENTRY_s) begin
    else if (SEM_cur_state == SEM_FORCE_WAIT_s && SEM_next_state == SEM_RELEASE_ENTRY_s) begin
        qv_release_entry_counter <= wv_number;
    end
    else if (SEM_cur_state == SEM_RELEASE_ENTRY_s) begin
        qv_release_entry_counter <= qv_release_entry_counter - 1;
    end
    else begin
        qv_release_entry_counter <= qv_release_entry_counter;
    end
end

/*
1.Fetch Entry Timing Sequence
    State:                        IDLE        FETCH       FETCH               
                                  _____       _____       _____                  
    clk:                    _____|     |_____|     |_____|     |_____
    
    Fetch State Count:              0           0           1                          
                            _____ ___________________________________
    Cmd(Wire):              _____X__Cmd______________________________
      
                            _____ ___________________________________
    QPN(wire):              _____X____qpn____________________________

                            _____ ___________________________________
 List table addr(wire):     _____X____ListAddr_______________________

                            __________________ ______________________
 List table dout(wire):     __________________X____<Head,Tail>_______

                            __________________ ______________________
 Element Table Addr(wire):  __________________X_EntryAddr____________

                            _____________________________ ___________
 Element Table Dout(wire):  _____________________________X___Entry___


2.Update Entry Timing Sequence
    State:                        IDLE        UPDATE      IDLE         
                                  _____       _____       _____             
    clk:                    _____|     |_____|     |_____|     |_____
    
    Update State Count:             0           0           0              
                            _____ ___________________________________
    Cmd(Wire):              _____X__Cmd______________________________
      
                            _____ ___________________________________
    QPN(wire):              _____X____qpn____________________________

                            _____ ___________________________________
 List table addr(reg):      _____X____ListAddr_______________________

                            _________________ _______________________
 List table dout(wire):     _________________X____<Head,Tail>________

                            _________________ _______________________
 Element Table Addr(wire):  _________________X____EntryAddr__________
                                              _____
 Element Table wr_en(wire): _________________|     |_________________
                            _________________ _______________________
 Element Table Din(wire):   _________________X___Entry_______________


3.Release Entry Timing Sequence
    State:                        IDLE       RELEASE     RELEASE     RELEASE     RELEASE     
                                  _____       _____       _____       _____       _____       
    clk:                    _____|     |_____|     |_____|     |_____|     |_____|     |_____
    
                            _____ _______________________________________________________________
    Cmd(Wire):              _____X__Cmd__________________________________________________________
      
                            _____ _______________________________________________________________
    QPN(wire):              _____X____qpn________________________________________________________

                            _____ _______________________________________________________________
 Release Entry Num:         _____X____EntryNum___________________________________________________

                            _________________ __________ ____________ ____________ ____________ _
 Release Entry Counter:     ___________0_____X_EntryNum_X_EntryNum-1_X_EntryNum-2_X_EntryNum-3_X_

                            _____ _______________________________________________________________
 List table addr(wire):     _____X____ListAddr___________________________________________________

                            _________________ ____________ ______________________________________
 List table dout(wire):     _________________X_<HeadTail>_X______________________________________

                                                          _______________________________________
 List table wr_en(wire):    _____________________________|

                            _____________________________ ___________ ___________ ___________ ___
 List table din(wire):      _____________________________X__<addr1>__X__<addr2>__X__<addr3>__X___

                            _________________ ___________ ___________ ___________ ___________ ___
 NextAddr table addr(wire): _________________X__<Head>___X__<next1>__X__<next2>__X__<next3>__X___

                            _____________________________ ___________ ___________ ___________ ___
 NextAddr table dout(wire): _____________________________X__<next1>__X__<next2>__X__<next3>__X___

*/

wire                    w_list_empty;
wire    [13:0]          wv_list_head;
wire    [13:0]          wv_list_tail;

assign w_list_empty = iv_reb_list_empty_doutb;
assign wv_list_head = iv_reb_list_head_doutb;
assign wv_list_tail = iv_reb_list_tail_doutb;

/***************************************** REB Buffer Control ***********************************/
//-- q_reb_list_head_web --
//-- qv_reb_list_head_addrb --
//-- qv_reb_list_head_dinb --
always @(*) begin
    case(SEM_cur_state) 
		SEM_INIT_s:				if(qv_reb_list_table_init_counter <= `QP_NUM - 1) begin 
                                    q_reb_list_head_web = 1'b1;
                                    qv_reb_list_head_addrb = qv_reb_list_table_init_counter;
                                    qv_reb_list_head_dinb = 'd0; 
								end
								else begin 
									q_reb_list_head_web = 1'b0;
									qv_reb_list_head_addrb = qv_reb_list_table_init_counter;
									qv_reb_list_head_dinb = 'd0;
								end  
		SEM_IDLE_s:				begin
                                    q_reb_list_head_web = 1'b0;
                                    qv_reb_list_head_addrb = i_cmd_empty ? 'd0 : wv_qpn;
                                    qv_reb_list_head_dinb = 'd0;
								end 
		SEM_FORCE_WAIT_s:		begin
                                    q_reb_list_head_web = 1'b0;
                                    qv_reb_list_head_addrb = i_cmd_empty ? 'd0 : wv_qpn;
                                    qv_reb_list_head_dinb = 'd0;
								end 
        SEM_RELEASE_ENTRY_s:    if(qv_release_entry_counter == 1) begin
                                    q_reb_list_head_web = 1'b1;
                                    qv_reb_list_head_addrb = wv_qpn;
                                    qv_reb_list_head_dinb = iv_reb_next_doutb;  //Move head to next element                                  
                                end
                                else begin
                                    q_reb_list_head_web = 1'b0;
                                    qv_reb_list_head_addrb = wv_qpn;
                                    qv_reb_list_head_dinb = 'd0;                                    
                                end
        SEM_FLUSH_ENTRY_s:      begin 
                                    q_reb_list_head_web = 1'b1;
                                    qv_reb_list_head_addrb = wv_qpn;
                                    qv_reb_list_head_dinb = iv_reb_next_doutb;  //Move head to next element                                  
                                end
        default:                begin
                                    q_reb_list_head_web = 1'b0;
                                    qv_reb_list_head_addrb = wv_qpn;
                                    qv_reb_list_head_dinb = 'd0;
                                end
    endcase
end

//-- q_reb_list_tail_web --
//-- qv_reb_list_tail_addrb --
//-- qv_reb_list_tail_dinb --
always @(*) begin
	case(SEM_cur_state)
		SEM_INIT_s:				if(qv_reb_list_table_init_counter <= `QP_NUM - 1) begin 
                                    q_reb_list_tail_web = 1'b1;
                                    qv_reb_list_tail_addrb = qv_reb_list_table_init_counter;
                                    qv_reb_list_tail_dinb = 'd0; 
								end
								else begin 
									q_reb_list_tail_web = 1'b0;
									qv_reb_list_tail_addrb = qv_reb_list_table_init_counter;
									qv_reb_list_tail_dinb = 'd0;
								end  
		SEM_IDLE_s:				begin
									q_reb_list_tail_web = 1'b0;
									qv_reb_list_tail_addrb = i_cmd_empty ? 'd0 : wv_qpn;
									qv_reb_list_tail_dinb = 'd0;
								end 
		SEM_FORCE_WAIT_s:		begin
									q_reb_list_tail_web = 1'b0;
									qv_reb_list_tail_addrb = i_cmd_empty ? 'd0 : wv_qpn;
									qv_reb_list_tail_dinb = 'd0;
								end 
		default:				begin
    								q_reb_list_tail_web = 1'b0;
    								qv_reb_list_tail_addrb = wv_qpn;
    								qv_reb_list_tail_dinb = 'd0;
								end 
	endcase
end

//-- q_reb_list_empty_web --
//-- qv_reb_list_empty_addrb --
//-- qv_reb_list_empty_dinb --
always @(*) begin
    case(SEM_cur_state) 
		SEM_INIT_s:				if(qv_reb_list_table_init_counter <= `QP_NUM - 1) begin 
                                    q_reb_list_empty_web = 1'b1;
                                    qv_reb_list_empty_addrb = qv_reb_list_table_init_counter;
                                    qv_reb_list_empty_dinb = 'd1; 
								end
								else begin 
									q_reb_list_empty_web = 1'b0;
									qv_reb_list_empty_addrb = qv_reb_list_table_init_counter;
									qv_reb_list_empty_dinb = 'd0;
								end  
		SEM_IDLE_s:				begin
									q_reb_list_empty_web = 1'b0;
									qv_reb_list_empty_addrb = i_cmd_empty ? 'd0 : wv_qpn;
									qv_reb_list_empty_dinb = 'd0;
								end 
		SEM_FORCE_WAIT_s:		begin
									q_reb_list_empty_web = 1'b0;
									qv_reb_list_empty_addrb = i_cmd_empty ? 'd0 : wv_qpn;
									qv_reb_list_empty_dinb = 'd0;
								end 
        SEM_RELEASE_ENTRY_s:    if(qv_release_entry_counter == 1 && wv_list_head == wv_list_tail) begin
                                    q_reb_list_empty_web = 1'b1;
                                    qv_reb_list_empty_addrb = wv_qpn;
                                    qv_reb_list_empty_dinb = 1'b1;                                 
                                end
                                else begin
                                    q_reb_list_empty_web = 1'b0;
                                    qv_reb_list_empty_addrb = wv_qpn;
                                    qv_reb_list_empty_dinb = 'd0;                                    
                                end
		SEM_FLUSH_ENTRY_s:		if(wv_list_head == wv_list_tail) begin
                                    q_reb_list_empty_web = 1'b1;
                                    qv_reb_list_empty_addrb = wv_qpn;
                                    qv_reb_list_empty_dinb = 1'b1;                                 
								end 
								else begin
                                    q_reb_list_empty_web = 1'b0;
                                    qv_reb_list_empty_addrb = wv_qpn;
                                    qv_reb_list_empty_dinb = 1'b0;                                 
								end 
        default:                begin
                                    q_reb_list_empty_web = 1'b0;
                                    qv_reb_list_empty_addrb = wv_qpn;
                                    qv_reb_list_empty_dinb = 'd0;
                                end
    endcase
end

//-- q_reb_content_web --
//-- qv_reb_content_addrb --
//-- qv_reb_content_dinb --
always @(*) begin
    case(SEM_cur_state) 
		SEM_INIT_s:	
								begin
									q_reb_content_web = 1'b1;
									qv_reb_content_addrb = qv_reb_free_init_counter;
									qv_reb_content_dinb = 'd0;
								end 
		SEM_IDLE_s:				begin
									q_reb_content_web = 1'b0;
									qv_reb_content_addrb = 'd0;
									qv_reb_content_dinb = 'd0;
								end 
		SEM_FORCE_WAIT_s:		begin
									q_reb_content_web = 1'b0;
									qv_reb_content_addrb = 'd0;
									qv_reb_content_dinb = 'd0;
								end 
		SEM_FETCH_ENTRY_s:		begin
                                    q_reb_content_web = 1'b0;
                                    qv_reb_content_addrb = wv_list_head;
                                    qv_reb_content_dinb = 'd0;            
								end 
        SEM_UPDATE_ENTRY_s:     begin
                                    q_reb_content_web = 1'b1;
                                    qv_reb_content_addrb = wv_list_head;
                                    qv_reb_content_dinb = {wv_VA, wv_Key, wv_Length};            
                                end
        default:                begin
                                    q_reb_content_web = 1'b0;
                                    qv_reb_content_addrb = wv_qpn;
                                    qv_reb_content_dinb = 'd0;
                                end
    endcase
end

//-- q_reb_next_web --
//-- qv_reb_next_addrb --
//-- qv_reb_next_dinb --
// Do not need to update next pointer, just need pointer value
always @(*) begin 
    case(SEM_cur_state)
		SEM_INIT_s:				begin
									q_reb_next_web = 1'b1;
									qv_reb_next_addrb = qv_reb_free_init_counter;
									qv_reb_next_dinb = 'd0;
								end 
		SEM_IDLE_s:				begin
									q_reb_next_web = 1'b0;
									qv_reb_next_addrb = 'd0;
									qv_reb_next_dinb = 'd0;
								end 
		SEM_FORCE_WAIT_s:		begin
									q_reb_next_web = 1'b0;
									qv_reb_next_addrb = wv_list_head;
									qv_reb_next_dinb = 'd0;
								end 
        SEM_RELEASE_ENTRY_s:    if(qv_release_entry_counter == wv_number) begin
                                    q_reb_next_web = 1'b0;
                                    qv_reb_next_addrb = wv_list_head;
                                    qv_reb_next_dinb = 'd0;  
                                end
                                else begin
                                    q_reb_next_web = 1'b0;
                                    qv_reb_next_addrb = iv_reb_next_doutb;
                                    qv_reb_next_dinb = 'd0;                                      
                                end
		SEM_FLUSH_ENTRY_s:		begin
									q_reb_next_web = 1'b0;
									qv_reb_next_addrb = wv_list_head;
									qv_reb_next_dinb = 'd0;
								end 
        default:                begin
                                    q_reb_next_web = 1'b0;
                                    qv_reb_next_addrb = wv_list_head;
                                    qv_reb_next_dinb = 'd0;        
                                end   
    endcase
end

//-- qv_reb_free_data --
//-- q_reb_free_wr_en --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_reb_free_wr_en <= 1'b0;
        qv_reb_free_data <= 'd0;        
    end
    else if (SEM_cur_state == SEM_INIT_s && (qv_reb_free_init_counter == 0 || qv_reb_free_data < qv_reb_free_init_counter)) begin
        q_reb_free_wr_en <= 1'b1;
        qv_reb_free_data <= qv_reb_free_init_counter;
    end
    else if (SEM_cur_state == SEM_RELEASE_ENTRY_s) begin
        q_reb_free_wr_en <= 1'b1;
        qv_reb_free_data <= qv_reb_next_addrb;
    end
    else if (SEM_cur_state == SEM_FLUSH_ENTRY_s) begin
        q_reb_free_wr_en <= 1'b1;
        qv_reb_free_data <= qv_reb_next_addrb;
    end
    else begin
        q_reb_free_wr_en <= 1'b0;
        qv_reb_free_data <= qv_reb_free_data;
    end
end

//-- q_cmd_rd_en --
always @(*) begin
    if(rst) begin
        q_cmd_rd_en = 1'b0;
    end 
    else begin 
        case(SEM_cur_state) 
        	SEM_FETCH_ENTRY_s:      if(qv_fetch_state_counter == `FETCH_TIME) begin
        	                            if(!i_resp_prog_full) begin
        	                            	q_cmd_rd_en = 'd1;
        	                            end
        	                            else begin
        	                                q_cmd_rd_en = 'd0;
        	                            end
        	                        end
        	                        else begin
        	                        	q_cmd_rd_en = 'd0;
        	                        end
        	SEM_UPDATE_ENTRY_s:     q_cmd_rd_en = 'd1;
        	SEM_RELEASE_ENTRY_s:    if(qv_release_entry_counter == 1) begin
                                    	q_cmd_rd_en = 'd1;
                                	end
                               	 	else begin
                                    	q_cmd_rd_en = 'd0;
                                	end
			SEM_FLUSH_ENTRY_s:		if(w_flush_finish) begin
										q_cmd_rd_en = 'd1;
									end 
									else begin
										q_cmd_rd_en = 'd0;
									end 
            default:            	q_cmd_rd_en = 1'b0;
        endcase
    end 
end

wire    [7:0]           wv_resp;
assign wv_resp = ((wv_list_tail == wv_list_head) && w_list_empty) ? `INVALID_ENTRY : `VALID_ENTRY;

//-- q_resp_wr_en --
//-- qv_resp_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_resp_wr_en <= 1'b0;
        qv_resp_data <= 'd0;
    end
    else if (SEM_cur_state == SEM_FETCH_ENTRY_s && qv_fetch_state_counter == `FETCH_TIME && !i_resp_prog_full) begin
        q_resp_wr_en <= 1'b1;
        qv_resp_data <= {iv_reb_content_doutb[127:0], wv_qpn, wv_resp};
    end
    else begin
        q_resp_wr_en <= 1'b0;
        qv_resp_data <= qv_resp_data;
    end
end

assign 	w_flush_finish = (w_list_empty) || (!w_list_empty && q_reb_list_empty_web && qv_reb_list_empty_dinb == 'd1);

/*--------------------------------- connect dbg bus -----------------------------------*/
wire   [`DBG_NUM_SCATTERENTRY_MANAGER * 32 - 1 : 0]   coalesced_bus;

assign coalesced_bus = {
                            q_reb_list_head_web,
                            q_reb_list_tail_web,
                            q_reb_list_empty_web,
                            q_reb_content_web,
                            q_reb_next_web,
                            q_reb_free_wr_en,
                            q_cmd_rd_en,
                            q_resp_wr_en,
                            w_flush_finish,
                            w_list_empty,
                            qv_reb_list_head_addrb,
                            qv_reb_list_head_dinb,
                            qv_reb_list_tail_addrb,
                            qv_reb_list_tail_dinb,
                            qv_reb_list_empty_addrb,
                            qv_reb_list_empty_dinb,
                            qv_reb_content_addrb,
                            qv_reb_content_dinb,
                            qv_reb_next_addrb,
                            qv_reb_next_dinb,
                            qv_reb_free_data,
                            qv_resp_data,
                            qv_fetch_state_counter,
                            qv_release_entry_counter,
                            qv_reb_free_init_counter,
                            qv_reb_list_table_init_counter,
                            SEM_cur_state,
                            SEM_next_state,
                            wv_opcode,
                            wv_number,
                            wv_qpn,
                            wv_VA,
                            wv_Key,
                            wv_Length,
                            wv_list_head,
                            wv_list_tail,
                            wv_resp    
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
                    (dbg_sel == 20) ?   coalesced_bus[32 * 21 - 1 : 32 * 20] : 32'd0;

//assign dbg_bus = coalesced_bus;

endmodule
