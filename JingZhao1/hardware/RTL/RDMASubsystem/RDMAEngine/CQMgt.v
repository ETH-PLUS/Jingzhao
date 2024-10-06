`timescale 1ns / 1ps

`include "nic_hw_params.vh"
`include "chip_include_rdma.vh"

`define     NONE_REQ        2'b00           
`define     RTC_REQ         2'b01
`define     RRC_REQ         2'b10
`define     EE_REQ          2'b11

/*
    RTC, RRC, EE may access the same CQ and modify the offset, we need a centralized control
*/
module CompletionQueueMgt
#(
	parameter 	RW_REG_NUM = 2
)
(  //CQM for short 
    input   wire                clk,
    input   wire                rst,

	input 	wire 	[RW_REG_NUM * 32 - 1 : 0]	rw_data,
	output 	wire 	[RW_REG_NUM * 32 - 1 : 0]	init_rw_data,

//Interface with RTC
    input   wire                i_rtc_req_valid,
    input   wire    [23:0]      iv_rtc_cq_index,
    input   wire    [31:0]       iv_rtc_cq_size,
    output  wire                o_rtc_resp_valid,
    output  wire     [23:0]     ov_rtc_cq_offset,

//Interface with RRC
    input   wire                i_rrc_req_valid,
    input   wire    [23:0]      iv_rrc_cq_index,
    input   wire    [31:0]       iv_rrc_cq_size,
    output  wire                o_rrc_resp_valid,
    output  wire    [23:0]      ov_rrc_cq_offset,    

//Interface with EE
    input   wire                i_ee_req_valid,
    input   wire    [23:0]      iv_ee_cq_index,
    input   wire    [31:0]       iv_ee_cq_size,
    output  wire                o_ee_resp_valid,
    output  wire    [23:0]      ov_ee_cq_offset,

    input   wire    [31:0]      dbg_sel,
    output  wire    [32 - 1:0]      dbg_bus,
    //output  wire    [`DBG_NUM_COMPLETION_QUEUE_MGR * 32 - 1:0]      dbg_bus,

    output  wire                o_cqm_init_finish
);

reg     [13:0]          qv_init_counter;

reg     [0:0]           q_cq_offset_table_wea;
reg     [13:0]          qv_cq_offset_table_addra;
reg     [23:0]          qv_cq_offset_table_dina;
reg     [13:0]          qv_cq_offset_table_addrb;
wire    [23:0]          wv_cq_offset_table_doutb;

reg     [0:0]           q_cq_offset_table_wea_fwd;
reg     [13:0]          qv_cq_offset_table_addra_fwd;
reg     [23:0]          qv_cq_offset_table_dina_fwd;
reg     [13:0]          qv_cq_offset_table_addrb_fwd;
wire    [23:0]          wv_cq_offset_table_doutb_fwd;   //To avoid read/write collision

BRAM_SDP_24w_16384d CQ_OFFSET_TABLE(
`ifdef CHIP_VERSION
	.RTSEL(rw_data[0 * 32 + 1 : 0 * 32 + 0]),
	.WTSEL(rw_data[0 * 32 + 3 : 0 * 32 + 2]),
	.PTSEL(rw_data[0 * 32 + 5 : 0 * 32 + 4]),
	.VG(rw_data[0 * 32 + 6 : 0 * 32 + 6]),
	.VS(rw_data[0 * 32 + 7 : 0 * 32 + 7]),

  `endif

  .clka(clk),    
  .ena(1'b1),      
  .wea(q_cq_offset_table_wea),      
  .addra(qv_cq_offset_table_addra),  
  .dina(qv_cq_offset_table_dina),
  .clkb(clk),    
  .enb(1'b1),        
  .addrb(qv_cq_offset_table_addrb),  
  .doutb(wv_cq_offset_table_doutb)  
);


//BRAM_SDP_24w_16384d EQ_OFFSET_TABLE(
//`ifdef CHIP_VERSION
//	.RTSEL(rw_data[1 * 32 + 1 : 1 * 32 + 0]),
//	.WTSEL(rw_data[1 * 32 + 3 : 1 * 32 + 2]),
//	.PTSEL(rw_data[1 * 32 + 5 : 1 * 32 + 4]),
//	.VG(rw_data[1 * 32 + 6 : 1 * 32 + 6]),
//	.VS(rw_data[1 * 32 + 7 : 1 * 32 + 7]),
//
//  `endif
//
//  .clka(clk),    
//  .ena(1'b1),      
//  .wea(q_cq_offset_table_wea),      
//  .addra(qv_cq_offset_table_addra),  
//  .dina(qv_cq_offset_table_dina),
//  .clkb(clk),    
//  .enb(1'b1),        
//  .addrb(qv_cq_offset_table_addrb),  
//  .doutb()  
//);


reg         [2:0]           CQM_cur_state;
reg         [2:0]           CQM_next_state;

parameter   [2:0]           CQM_INIT_s = 3'd0,
                            CQM_IDLE_s = 3'd1,
                            CQM_RTC_REQ_s = 3'd2,
                            CQM_RRC_REQ_s = 3'd3,
                            CQM_EE_REQ_s = 3'd4;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        CQM_cur_state <= CQM_INIT_s;
    end
    else begin
        CQM_cur_state <= CQM_next_state;
    end
end

always @(*) begin
    case(CQM_cur_state)
        CQM_INIT_s:         if(qv_init_counter == `QP_NUM - 1) begin
                                CQM_next_state = CQM_IDLE_s;
                            end
                            else begin
                                CQM_next_state = CQM_INIT_s;
                            end
        CQM_IDLE_s:         if(i_rtc_req_valid) begin               //RTC has the highest priority, but it doesn't matters
                                CQM_next_state = CQM_RTC_REQ_s;
                            end
                            else if(i_rrc_req_valid) begin
                                CQM_next_state = CQM_RRC_REQ_s;
                            end
                            else if(i_ee_req_valid) begin
                                CQM_next_state = CQM_EE_REQ_s;
                            end  
                            else begin
                                CQM_next_state = CQM_IDLE_s;
                            end
        CQM_RTC_REQ_s:      if(i_rrc_req_valid) begin
                                CQM_next_state = CQM_RRC_REQ_s;
                            end
                            else if(i_ee_req_valid) begin
                                CQM_next_state = CQM_EE_REQ_s;
                            end
                            else if(i_rtc_req_valid) begin
                                CQM_next_state = CQM_RTC_REQ_s;
                            end
                            else begin
                                CQM_next_state = CQM_IDLE_s;
                            end
        CQM_RRC_REQ_s:      if(i_ee_req_valid) begin
                                CQM_next_state = CQM_EE_REQ_s;
                            end
                            else if(i_rtc_req_valid) begin
                                CQM_next_state = CQM_RTC_REQ_s;
                            end
                            else if(i_rrc_req_valid) begin
                                CQM_next_state = CQM_RRC_REQ_s;
                            end
                            else begin
                                CQM_next_state = CQM_IDLE_s;
                            end
        CQM_EE_REQ_s:       if(i_rtc_req_valid) begin
                                CQM_next_state = CQM_RTC_REQ_s;
                            end
                            else if(i_rrc_req_valid) begin
                                CQM_next_state = CQM_RRC_REQ_s;
                            end
                            else if(i_ee_req_valid) begin
                                CQM_next_state = CQM_EE_REQ_s;
                            end
                            else begin
                                CQM_next_state = CQM_IDLE_s;
                            end
        default:            CQM_next_state = CQM_IDLE_s;
    endcase
end

assign o_cqm_init_finish = (qv_init_counter == `QP_NUM - 1);
//-- qv_init_counter --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_init_counter <= 'd0;        
    end
    else if (CQM_cur_state == CQM_INIT_s && qv_init_counter < `QP_NUM - 1) begin
        qv_init_counter <= qv_init_counter + 1;
    end
    else begin
        qv_init_counter <= qv_init_counter;
    end
end

reg             [1:0]           qv_next_req;      
//-- qv_next_req -- 0 - RTC, 1 - RRC, 2 - EE
always @(*) begin
    if (rst) begin
        qv_next_req = `RTC_REQ;
    end
    else if(CQM_cur_state == CQM_IDLE_s) begin
        if(i_rtc_req_valid) begin
            qv_next_req = `RTC_REQ;
        end
        else if(i_rrc_req_valid) begin
            qv_next_req = `RRC_REQ;
        end
        else if(i_ee_req_valid) begin
            qv_next_req = `EE_REQ;
        end
        else begin
            qv_next_req = `NONE_REQ;
        end
    end
    else if (CQM_cur_state == CQM_RTC_REQ_s) begin    //Arbitrate
        if(i_rrc_req_valid) begin
            qv_next_req = `RRC_REQ;
        end
        else if(i_ee_req_valid) begin
            qv_next_req = `EE_REQ;
        end
        else if(i_rrc_req_valid) begin
            qv_next_req = `RTC_REQ;
        end
        else begin
            qv_next_req = `NONE_REQ;
        end       
    end
    else if (CQM_cur_state == CQM_RRC_REQ_s) begin    //Arbitrate
        if(i_ee_req_valid) begin
            qv_next_req = `EE_REQ;
        end
        else if(i_rtc_req_valid) begin
            qv_next_req = `RTC_REQ;
        end
        else if(i_ee_req_valid) begin
            qv_next_req = `EE_REQ;
        end
        else begin
            qv_next_req = `NONE_REQ;
        end       
    end
    else if (CQM_cur_state == CQM_EE_REQ_s) begin    //Arbitrate
        if(i_rtc_req_valid) begin
            qv_next_req = `RTC_REQ;
        end
        else if(i_rrc_req_valid) begin
            qv_next_req = `RRC_REQ;
        end
        else if(i_ee_req_valid) begin
            qv_next_req = `EE_REQ;
        end
        else begin
            qv_next_req = `NONE_REQ;
        end       
    end
	else begin
		qv_next_req = `NONE_REQ;
	end 
end

  
//-- q_cq_offset_table_wea_fwd --
//-- qv_cq_offset_table_addra_fwd --
//-- qv_cq_offset_table_dina_fwd --
//-- qv_cq_offset_table_addrb_fwd --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_cq_offset_table_wea_fwd <= 'd0;
        qv_cq_offset_table_addra_fwd <= 'd0;
        qv_cq_offset_table_dina_fwd <= 'd0;
        qv_cq_offset_table_addrb_fwd <= 'd0;
    end
    else begin
        q_cq_offset_table_wea_fwd <= q_cq_offset_table_wea;
        qv_cq_offset_table_addra_fwd <= qv_cq_offset_table_addra;
        qv_cq_offset_table_dina_fwd <= qv_cq_offset_table_dina;  
        qv_cq_offset_table_addrb_fwd <= qv_cq_offset_table_addrb;      
    end
end

wire 	[23:0]		wv_increased_cq_offset;
assign wv_increased_cq_offset = wv_cq_offset_table_doutb_fwd + `CQE_LENGTH;

wire 	[23:0]		wv_cq_rtc_length;
wire 	[23:0]		wv_cq_rrc_length;
wire 	[23:0]		wv_cq_ee_length;

assign wv_cq_rtc_length = (1 << iv_rtc_cq_size) * `CQE_LENGTH;
assign wv_cq_rrc_length = (1 << iv_rrc_cq_size) * `CQE_LENGTH;
assign wv_cq_ee_length = (1 << iv_ee_cq_size) * `CQE_LENGTH;

//-- q_cq_offset_table_wea --
//-- qv_cq_offset_table_addra --
//-- qv_cq_offset_table_dina --
always @(*) begin
    if (rst) begin
        q_cq_offset_table_wea = 'd0;
        qv_cq_offset_table_addra = 'd0;
        qv_cq_offset_table_dina = 'd0;
    end
	else if (CQM_cur_state == CQM_INIT_s) begin
		q_cq_offset_table_wea = 'd1;
		qv_cq_offset_table_addra = qv_init_counter;
		qv_cq_offset_table_dina = 'd0;
	end 
    else if (CQM_cur_state == CQM_RTC_REQ_s) begin
        q_cq_offset_table_wea = 'd1;
        qv_cq_offset_table_addra = iv_rtc_cq_index;
        qv_cq_offset_table_dina = (wv_increased_cq_offset < wv_cq_rtc_length) ? wv_increased_cq_offset : 'd0;        
    end
    else if (CQM_cur_state == CQM_RRC_REQ_s) begin
        q_cq_offset_table_wea = 'd1;
        qv_cq_offset_table_addra = iv_rrc_cq_index;
        qv_cq_offset_table_dina = (wv_increased_cq_offset < wv_cq_rrc_length) ? wv_increased_cq_offset : 'd0;        
    end
    else if (CQM_cur_state == CQM_EE_REQ_s) begin
        q_cq_offset_table_wea = 'd1;
        qv_cq_offset_table_addra = iv_ee_cq_index;
        qv_cq_offset_table_dina = (wv_increased_cq_offset < wv_cq_ee_length) ? wv_increased_cq_offset : 'd0;        
    end
    else begin
        q_cq_offset_table_wea = 'd0;
        qv_cq_offset_table_addra = 'd0;
        qv_cq_offset_table_dina = 'd0;
    end
end

always @(*) begin
    if (rst) begin
        qv_cq_offset_table_addrb = 'd0;
    end
    else if (qv_next_req == `RTC_REQ && i_rtc_req_valid) begin
        qv_cq_offset_table_addrb = iv_rtc_cq_index;
    end
        else if (qv_next_req == `RRC_REQ && i_rrc_req_valid) begin
        qv_cq_offset_table_addrb = iv_rrc_cq_index;
    end
        else if (qv_next_req == `EE_REQ && i_ee_req_valid) begin
        qv_cq_offset_table_addrb = iv_ee_cq_index;
    end
    else begin
        qv_cq_offset_table_addrb = 'd0;
    end
end

//To avoid read/write collision
assign wv_cq_offset_table_doutb_fwd = ((qv_cq_offset_table_addra_fwd == qv_cq_offset_table_addrb_fwd) && q_cq_offset_table_wea_fwd) ? qv_cq_offset_table_dina_fwd : wv_cq_offset_table_doutb;

assign o_rtc_resp_valid = (CQM_cur_state == CQM_RTC_REQ_s) ? 'd1 : 'd0;
assign ov_rtc_cq_offset = (CQM_cur_state == CQM_RTC_REQ_s) ?  wv_cq_offset_table_doutb_fwd : 'd0;
assign o_rrc_resp_valid = (CQM_cur_state == CQM_RRC_REQ_s) ? 'd1 : 'd0;
assign ov_rrc_cq_offset = (CQM_cur_state == CQM_RRC_REQ_s) ?  wv_cq_offset_table_doutb_fwd : 'd0;
assign o_ee_resp_valid = (CQM_cur_state == CQM_EE_REQ_s) ? 'd1 : 'd0;
assign ov_ee_cq_offset = (CQM_cur_state == CQM_EE_REQ_s) ?  wv_cq_offset_table_doutb_fwd : 'd0;


//Connect dbg bus
wire   [`DBG_NUM_COMPLETION_QUEUE_MGR * 32 - 1 : 0]   coalesced_bus;

assign coalesced_bus = {
                            qv_init_counter,
                            q_cq_offset_table_wea,
                            qv_cq_offset_table_addra,
                            qv_cq_offset_table_dina,
                            qv_cq_offset_table_addrb,
                            q_cq_offset_table_wea_fwd,
                            qv_cq_offset_table_addra_fwd,
                            qv_cq_offset_table_dina_fwd,
                            qv_cq_offset_table_addrb_fwd,
                            CQM_cur_state,
                            CQM_next_state,
                            qv_next_req, 
                            wv_cq_offset_table_doutb,
                            wv_cq_offset_table_doutb_fwd,
                            wv_increased_cq_offset,
                            wv_cq_rtc_length,
                            wv_cq_rrc_length,
                            wv_cq_ee_length
                        };

assign dbg_bus =    (dbg_sel == 0)  ?   coalesced_bus[32 * 1 - 1 : 32 * 0] :
                    (dbg_sel == 1)  ?   coalesced_bus[32 * 2 - 1 : 32 * 1] :
                    (dbg_sel == 2)  ?   coalesced_bus[32 * 3 - 1 : 32 * 2] :
                    (dbg_sel == 3)  ?   coalesced_bus[32 * 4 - 1 : 32 * 3] :
                    (dbg_sel == 4)  ?   coalesced_bus[32 * 5 - 1 : 32 * 4] :
                    (dbg_sel == 5)  ?   coalesced_bus[32 * 6 - 1 : 32 * 5] :
                    (dbg_sel == 6)  ?   coalesced_bus[32 * 7 - 1 : 32 * 6] :
                    (dbg_sel == 7)  ?   coalesced_bus[32 * 8 - 1 : 32 * 7] :
                    (dbg_sel == 8)  ?   coalesced_bus[32 * 9 - 1 : 32 * 8] : 32'd0;

//assign dbg_bus = coalesced_bus;

assign init_rw_data = 'd0;

endmodule
