`timescale 1ns / 1ps

`include "nic_hw_params.vh"
`include "chip_include_rdma.vh"

module TimerControl
#(
    parameter   RW_REG_NUM = 2
)
( //"tc" for short
    input   wire                clk,
    input   wire                rst,

	input 	wire 	[RW_REG_NUM * 32 - 1 : 0]	rw_data,
	output 	wire 	[RW_REG_NUM * 32 - 1 : 0]	init_rw_data,

//Interface with RequesterTransControl
    input   wire                i_tc_te_loss_empty,
    input   wire    [63:0]      iv_tc_te_loss_data,
    output  wire                o_tc_te_loss_rd_en,

//RequesterRecvControl
    //Set Loss Timer
    input   wire                i_rc_te_loss_empty,
    input   wire    [63:0]      iv_rc_te_loss_data,
    output  wire                o_rc_te_loss_rd_en,

    //Set RNR Timer
    input   wire                i_rc_te_rnr_empty,
    input   wire    [63:0]      iv_rc_te_rnr_data,
    output  wire                o_rc_te_rnr_rd_en,

    //Loss Timer expire
    output  wire                o_loss_expire_wr_en,
    output  wire    [31:0]      ov_loss_expire_data,
    input   wire                i_loss_expire_prog_full,

    //RNR Timer expire
    output  wire                o_rnr_expire_wr_en,
    output  wire    [31:0]      ov_rnr_expire_data,
    input   wire                i_rnr_expire_prog_full,

    input   wire    [31:0]      dbg_sel,
    output  wire    [32 - 1:0]      dbg_bus,
    //output  wire    [`DBG_NUM_TIMER_CONTROL * 32 - 1:0]      dbg_bus,

	output 	wire 				o_timer_init_finish
);


reg                     q_tc_te_loss_rd_en;
reg                     q_rc_te_loss_rd_en;
reg                     q_rc_te_rnr_rd_en;
reg                     q_loss_expire_wr_en;
reg     [31:0]          qv_loss_expire_data;
reg                     q_rnr_expire_wr_en;
reg     [31:0]          qv_rnr_expire_data;

assign o_tc_te_loss_rd_en = q_tc_te_loss_rd_en;
assign o_rc_te_loss_rd_en = q_rc_te_loss_rd_en;
assign o_rc_te_rnr_rd_en = q_rc_te_rnr_rd_en;
assign o_loss_expire_wr_en = q_loss_expire_wr_en;
assign ov_loss_expire_data = qv_loss_expire_data;
assign o_rnr_expire_wr_en = q_rnr_expire_wr_en;
assign ov_rnr_expire_data = qv_rnr_expire_data;

/*----------------------------------------------------- RNR Timer --------------------------------------------*/
reg                 q_rnr_timer_wea;
reg     [13:0]      qv_rnr_timer_addra;
reg     [22:0]      qv_rnr_timer_dina;
wire    [22:0]      wv_rnr_timer_douta;
reg                 q_rnr_timer_web;
reg     [13:0]      qv_rnr_timer_addrb;
reg     [22:0]      qv_rnr_timer_dinb;
wire    [22:0]      wv_rnr_timer_doutb;
    
BRAM_TDP_23w_16384d RNRTimer_Inst(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[0 * 32 + 1 : 0 * 32 + 0]),
	.WTSEL( rw_data[0 * 32 + 3 : 0 * 32 + 2]),
	.PTSEL( rw_data[0 * 32 + 5 : 0 * 32 + 4]),
	.VG(    rw_data[0 * 32 + 6 : 0 * 32 + 6]),
	.VS(    rw_data[0 * 32 + 7 : 0 * 32 + 7]),

  `endif

  .clka(clk),    
  .ena(1'b1),      
  .wea(q_rnr_timer_wea),      
  .addra(qv_rnr_timer_addra),  
  .dina(qv_rnr_timer_dina),    
  .douta(wv_rnr_timer_douta),  
  .clkb(clk),    
  .enb(1'b1),      
  .web(q_rnr_timer_web),      
  .addrb(qv_rnr_timer_addrb),  
  .dinb(qv_rnr_timer_dinb),    
  .doutb(wv_rnr_timer_doutb)  
);

/******************************* Thread 1 for RNRTimer ***********************************/
wire    [2:0]           wv_rnr_retrans_threshold;
wire    [2:0]           wv_rnr_retrans_cnt;
wire    [0:0]           wv_rnr_state;
wire    [7:0]           wv_rnr_timer_threshold;
wire    [7:0]           wv_rnr_timer_cnt;

assign wv_rnr_retrans_threshold = wv_rnr_timer_douta[2:0];
assign wv_rnr_retrans_cnt = wv_rnr_timer_douta[5:3];
assign wv_rnr_state = wv_rnr_timer_douta[6:6];
assign wv_rnr_timer_threshold = wv_rnr_timer_douta[14:7];
assign wv_rnr_timer_cnt = wv_rnr_timer_douta[22:15];

reg     [13:0]          qv_rnr_timer_addra_reg;
reg     [0:0]           qv_rnr_iter_mandatory_cnt;

//-- qv_rnr_iter_mandatory_cnt --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_rnr_iter_mandatory_cnt <= 'd0;        
    end
	else if(!o_timer_init_finish) begin
		qv_rnr_iter_mandatory_cnt <= 'd0;
	end 
    else begin
        qv_rnr_iter_mandatory_cnt <= ~qv_rnr_iter_mandatory_cnt;
    end
end

//-- qv_rnr_timer_addra_reg --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_rnr_timer_addra_reg <= 'd0;        
    end
	else if(!o_timer_init_finish) begin
		qv_rnr_timer_addra_reg <= 'd0;
	end 
    else if (qv_rnr_iter_mandatory_cnt) begin
        qv_rnr_timer_addra_reg <= qv_rnr_timer_addra_reg + 1;
    end
    else begin
        qv_rnr_timer_addra_reg <= qv_rnr_timer_addra_reg;
    end
end

//-- qv_rnr_timer_addra --
always @(*) begin
    qv_rnr_timer_addra = qv_rnr_timer_addra_reg;
end

//-- qv_rnr_timer_dina --
always @(*) begin
	if(!o_timer_init_finish) begin
		qv_rnr_timer_dina = 'd0;
	end 
	else if(wv_rnr_state == `TIMER_ACTIVE) begin //Timer is active
        if(wv_rnr_timer_cnt + 8'd1 == wv_rnr_timer_threshold) begin //Timer expired
            if(wv_rnr_retrans_cnt + 3'd1 == wv_rnr_retrans_threshold) begin //Reach retransmission threshold
                qv_rnr_timer_dina = {8'h0, wv_rnr_timer_threshold, `TIMER_INACTIVE, 3'h0, wv_rnr_retrans_threshold};  //Clear timer and clear retrnasmission count
            end
            else begin
                qv_rnr_timer_dina = {8'h0, wv_rnr_timer_threshold, `TIMER_ACTIVE, wv_rnr_retrans_cnt + 3'd1, wv_rnr_retrans_threshold};
            end
        end
        else begin
            qv_rnr_timer_dina = {wv_rnr_timer_cnt + 8'd1, wv_rnr_timer_threshold, `TIMER_ACTIVE, wv_rnr_retrans_cnt, wv_rnr_retrans_threshold};
        end
    end
    else begin
        qv_rnr_timer_dina ='d0;
    end
end

//-- q_rnr_timer_wea --
always @(*) begin
	if(!o_timer_init_finish) begin
		q_rnr_timer_wea = 1'b0;
	end 
    else if(qv_rnr_iter_mandatory_cnt) begin
        if(wv_rnr_state == `TIMER_ACTIVE) begin
            q_rnr_timer_wea = 1'b1;
        end
        else begin
            q_rnr_timer_wea = 1'b0;
        end
    end
    else begin
        q_rnr_timer_wea = 1'b0;
    end
end

//-- q_rnr_expire_wr_en --
//-- qv_rnr_expire_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_rnr_expire_wr_en <= 1'b0;       
        qv_rnr_expire_data <= 'd0; 
    end
    else if (qv_rnr_iter_mandatory_cnt && wv_rnr_state == `TIMER_ACTIVE) begin
        if(wv_rnr_timer_cnt + 8'd1 == wv_rnr_timer_threshold) begin //Timer expired
            if(wv_rnr_retrans_cnt + 3'd1 < wv_rnr_retrans_threshold) begin //Reach retransmission threshold
                q_rnr_expire_wr_en <= 1'b1;
                qv_rnr_expire_data <= {qv_rnr_timer_addra, `TIMER_EXPIRED};
            end
            else begin
                q_rnr_expire_wr_en <= 1'b1;
                qv_rnr_expire_data <= {qv_rnr_timer_addra, `COUNTER_EXCEEDED};
            end
        end
        else begin
            q_rnr_expire_wr_en <= 1'b0;
            qv_rnr_expire_data <=  qv_rnr_expire_data;
        end
    end
    else begin
        q_rnr_expire_wr_en <= 1'b0;
        qv_rnr_expire_data <= qv_rnr_expire_data;
    end
end


/******************************* Thread 2 for RNRTimer ***********************************/
reg     [0:0]       qv_rnr_setting_mandatory_cnt;

reg 	[31:0]		qv_rnr_init_counter;

//-- qv_rnr_init_counter --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_rnr_init_counter <= 'd0;
	end 
	else if(qv_rnr_init_counter < `TIMER_NUM) begin 
		qv_rnr_init_counter <= qv_rnr_init_counter + 'd1;
	end 
	else begin
		qv_rnr_init_counter <= qv_rnr_init_counter;
	end 
end 

//-- qv_rnr_setting_mandatory_cnt --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_rnr_setting_mandatory_cnt <= 'd0;        
    end
    else if(!i_rc_te_rnr_empty) begin
        qv_rnr_setting_mandatory_cnt <= ~qv_rnr_setting_mandatory_cnt;
    end
    else begin
        qv_rnr_setting_mandatory_cnt <= 'd0;
    end
end

//-- q_rnr_timer_web --
always @(*) begin
	if(rst) begin 
		q_rnr_timer_web = 1'b0;
	end
	else if(qv_rnr_init_counter < `TIMER_NUM) begin
		q_rnr_timer_web = 1'b1;
	end  
    else if (qv_rnr_setting_mandatory_cnt) begin
        q_rnr_timer_web = 1'b1;
    end
    else begin
        q_rnr_timer_web = 1'b0;
    end
end

//-- qv_rnr_timer_addrb --
always @(*) begin
	if(rst) begin 
		qv_rnr_timer_addrb = 'd0;
	end 
	else if(qv_rnr_init_counter < `TIMER_NUM) begin
		qv_rnr_timer_addrb = qv_rnr_init_counter;
	end 
    else if (!i_rc_te_rnr_empty) begin
        qv_rnr_timer_addrb = iv_rc_te_rnr_data[31:8]; 
    end
    else begin
        qv_rnr_timer_addrb = 'd0;
    end
end

//-- qv_rnr_timer_dinb --
always @(*) begin
	if(rst) begin
		qv_rnr_timer_dinb = 'd0;
	end 
	else if(qv_rnr_init_counter < `TIMER_NUM) begin
		qv_rnr_timer_dinb = 'd0;
	end 
    else if (qv_rnr_setting_mandatory_cnt) begin
        if(iv_rc_te_rnr_data[7:0] == `SET_TIMER) begin
            qv_rnr_timer_dinb = {8'h0, iv_rc_te_rnr_data[42:35], `TIMER_ACTIVE, 3'h0, iv_rc_te_rnr_data[34:32]};
        end
        else if(iv_rc_te_rnr_data[7:0] == `STOP_TIMER) begin
            qv_rnr_timer_dinb = {8'h0, wv_rnr_timer_doutb[14:7], `TIMER_INACTIVE, 3'h0, wv_rnr_timer_doutb[2:0]};
        end
        else if(iv_rc_te_rnr_data[7:0] == `RESTART_TIMER) begin
            qv_rnr_timer_dinb = {8'h0, wv_rnr_timer_doutb[14:7], `TIMER_ACTIVE, 3'h0, wv_rnr_timer_doutb[2:0]};
        end
        else begin
            qv_rnr_timer_dinb = 'd0;
        end
    end
    else begin
        qv_rnr_timer_dinb = 'd0;
    end
end

//-- q_rc_te_rnr_rd_en --
always @(*) begin
    if(!i_rc_te_rnr_empty && qv_rnr_setting_mandatory_cnt == 0) begin
        q_rc_te_rnr_rd_en = 1'b1;
    end
    else begin
        q_rc_te_rnr_rd_en = 1'b0;
    end
end

/*--------------------------------------------------- Loss Timer --------------------------------------------*/

reg                 q_loss_timer_wea;
reg     [13:0]      qv_loss_timer_addra;
reg     [22:0]      qv_loss_timer_dina;
wire    [22:0]      wv_loss_timer_douta;
reg                 q_loss_timer_web;
reg     [13:0]      qv_loss_timer_addrb;
reg     [22:0]      qv_loss_timer_dinb;
wire    [22:0]      wv_loss_timer_doutb;
    
BRAM_TDP_23w_16384d LossTimer_Inst(
	`ifdef CHIP_VERSION
	.RTSEL( rw_data[1 * 32 + 1 : 1 * 32 + 0]),
	.WTSEL( rw_data[1 * 32 + 3 : 1 * 32 + 2]),
	.PTSEL( rw_data[1 * 32 + 5 : 1 * 32 + 4]),
	.VG(    rw_data[1 * 32 + 6 : 1 * 32 + 6]),
	.VS(    rw_data[1 * 32 + 7 : 1 * 32 + 7]),

  `endif

  .clka(clk),    
  .ena(1'b1),      
  .wea(q_loss_timer_wea),      
  .addra(qv_loss_timer_addra),  
  .dina(qv_loss_timer_dina),    
  .douta(wv_loss_timer_douta),  
  .clkb(clk),    
  .enb(1'b1),      
  .web(q_loss_timer_web),      
  .addrb(qv_loss_timer_addrb),  
  .dinb(qv_loss_timer_dinb),    
  .doutb(wv_loss_timer_doutb)  
);

/******************************* Thread 1 for LossTimer ***********************************/
wire    [2:0]           wv_loss_retrans_threshold;
wire    [2:0]           wv_loss_retrans_cnt;
wire    [0:0]           wv_loss_state;
wire    [7:0]           wv_loss_timer_threshold;
wire    [7:0]           wv_loss_timer_cnt;

assign wv_loss_retrans_threshold = wv_loss_timer_douta[2:0];
assign wv_loss_retrans_cnt = wv_loss_timer_douta[5:3];
assign wv_loss_state = wv_loss_timer_douta[6:6];
assign wv_loss_timer_threshold = wv_loss_timer_douta[14:7];
assign wv_loss_timer_cnt = wv_loss_timer_douta[22:15];

reg     [13:0]          qv_loss_timer_addra_reg;
reg     [0:0]           qv_loss_iter_mandatory_cnt;

//-- qv_loss_iter_mandatory_cnt --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_loss_iter_mandatory_cnt <= 'd0;        
    end
	else if(!o_timer_init_finish) begin
		qv_loss_iter_mandatory_cnt <= 'd0;
	end  
    else begin
        qv_loss_iter_mandatory_cnt <= ~qv_loss_iter_mandatory_cnt;
    end
end

//-- qv_loss_timer_addra_reg --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_loss_timer_addra_reg <= 'd0;        
    end
	else if(!o_timer_init_finish) begin
		qv_loss_timer_addra_reg <= 'd0;
	end 
    else if (qv_loss_iter_mandatory_cnt) begin
        qv_loss_timer_addra_reg <= qv_loss_timer_addra_reg + 1;
    end
    else begin
        qv_loss_timer_addra_reg <= qv_loss_timer_addra_reg;
    end
end

//-- qv_loss_timer_addra --
always @(*) begin
    qv_loss_timer_addra = qv_loss_timer_addra_reg;
end

//-- qv_loss_timer_dina --
always @(*) begin
	if(!o_timer_init_finish) begin
		qv_loss_timer_dina = 'd0;
	end 
    else if(wv_loss_state == `TIMER_ACTIVE) begin //Timer is active
        if(wv_loss_timer_cnt + 8'd1 == wv_loss_timer_threshold) begin //Timer expired
            if(wv_loss_retrans_cnt + 3'd1 == wv_loss_retrans_threshold) begin //Reach retransmission threshold
                qv_loss_timer_dina = {8'h0, wv_loss_timer_threshold, `TIMER_INACTIVE, 3'h0, wv_loss_retrans_threshold};  //Clear timer and clear retrnasmission count
            end
            else begin
                qv_loss_timer_dina = {8'h0, wv_loss_timer_threshold, `TIMER_ACTIVE, wv_loss_retrans_cnt + 3'd1, wv_loss_retrans_threshold};
            end
        end
        else begin
            qv_loss_timer_dina = {wv_loss_timer_cnt + 8'd1, wv_loss_timer_threshold, `TIMER_ACTIVE, wv_loss_retrans_cnt, wv_loss_retrans_threshold};
        end
    end
    else begin
        qv_loss_timer_dina ='d0;
    end
end

//-- q_loss_timer_wea --
always @(*) begin
	if(!o_timer_init_finish) begin
		q_loss_timer_wea = 1'b0;
	end 
    else if(qv_loss_iter_mandatory_cnt) begin
        if(wv_loss_state == `TIMER_ACTIVE) begin
            q_loss_timer_wea = 1'b1;
        end
        else begin
            q_loss_timer_wea = 1'b0;
        end
    end
    else begin
        q_loss_timer_wea = 1'b0;
    end
end

//-- q_loss_expire_wr_en --
//-- qv_loss_expire_data --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_loss_expire_wr_en <= 1'b0;
        qv_loss_expire_data <= 'd0;
    end
    else if (qv_loss_iter_mandatory_cnt && wv_loss_state == `TIMER_ACTIVE) begin
        if(wv_loss_timer_cnt + 8'd1 == wv_loss_timer_threshold) begin //Timer expired
            if(wv_loss_retrans_cnt + 3'd1 < wv_loss_retrans_threshold) begin //Reach retransmission threshold
                q_loss_expire_wr_en <= 1'b1;
                qv_loss_expire_data <= {qv_loss_timer_addra, `TIMER_EXPIRED};
            end
            else begin
                q_loss_expire_wr_en <= 1'b1;
                qv_loss_expire_data <= {qv_loss_timer_addra, `COUNTER_EXCEEDED};
            end
        end
        else begin
            q_loss_expire_wr_en <= 1'b0;
            qv_loss_expire_data <=  qv_loss_expire_data;
        end
    end
    else begin
        q_loss_expire_wr_en <= 1'b0;
        qv_loss_expire_data <= qv_loss_expire_data;
    end
end


/******************************* Thread 2 for LossTimer ***********************************/
reg     [0:0]       qv_loss_setting_mandatory_cnt;

reg 	[31:0]		qv_loss_init_counter;

reg     [2:0]       LOSS_cur_state;
reg     [2:0]       LOSS_next_state;

parameter   [2:0]       
			LOSS_INIT_s = 3'b000,
            LOSS_IDLE_s = 3'b001,
            LOSS_SCH_TC_s = 3'b010,
            LOSS_SCH_RC_s = 3'b100;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        LOSS_cur_state <= LOSS_INIT_s;        
    end
    else begin
        LOSS_cur_state <= LOSS_next_state;
    end
end

always @(*) begin
    case(LOSS_cur_state)
		LOSS_INIT_s:	if(qv_loss_init_counter == `TIMER_NUM) begin
							LOSS_next_state = LOSS_IDLE_s;
						end 
						else begin
							LOSS_next_state = LOSS_INIT_s;
						end 
        LOSS_IDLE_s:    if(!i_tc_te_loss_empty) begin
                            LOSS_next_state = LOSS_SCH_TC_s;
                        end
                        else if(!i_rc_te_loss_empty) begin
                            LOSS_next_state = LOSS_SCH_RC_s;
                        end
                        else begin
                            LOSS_next_state = LOSS_IDLE_s;
                        end
        LOSS_SCH_TC_s:  if(qv_loss_setting_mandatory_cnt) begin
                            if(!i_rc_te_loss_empty) begin
                                LOSS_next_state = LOSS_SCH_RC_s;
                            end
                            else if(!i_tc_te_loss_empty) begin
                                LOSS_next_state = LOSS_SCH_TC_s;
                            end
                            else begin
                                LOSS_next_state = LOSS_IDLE_s;
                            end
                        end
                        else begin
                            LOSS_next_state = LOSS_SCH_TC_s;
                        end
        LOSS_SCH_RC_s:  if(qv_loss_setting_mandatory_cnt) begin
                            if(!i_tc_te_loss_empty) begin
                                LOSS_next_state = LOSS_SCH_TC_s;
                            end
                            else if(!i_rc_te_loss_empty) begin
                                LOSS_next_state = LOSS_SCH_RC_s;
                            end
                            else begin
                                LOSS_next_state = LOSS_IDLE_s;
                            end
                        end
                        else begin
                            LOSS_next_state = LOSS_SCH_RC_s;
                        end
        default:        LOSS_next_state = LOSS_IDLE_s;
    endcase
end

//-- qv_loss_init_counter --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_loss_init_counter <= 'd0;
	end 
	else if(LOSS_cur_state == LOSS_INIT_s && qv_loss_init_counter < `TIMER_NUM) begin
		qv_loss_init_counter <= qv_loss_init_counter + 'd1;
	end 
	else begin
		qv_loss_init_counter <= qv_loss_init_counter;
	end 
end 

//-- qv_loss_setting_mandatory_cnt --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_loss_setting_mandatory_cnt <= 'd0;        
    end
    else if(LOSS_cur_state == LOSS_SCH_TC_s || LOSS_cur_state == LOSS_SCH_RC_s) begin
        qv_loss_setting_mandatory_cnt <= ~qv_loss_setting_mandatory_cnt;
    end
    else begin
        qv_loss_setting_mandatory_cnt <= 'd0;
    end
end

//-- q_loss_timer_web --
always @(*) begin
	if(rst) begin 
		q_loss_timer_web = 1'b0;
	end 
	else if(LOSS_cur_state == LOSS_INIT_s) begin
		q_loss_timer_web = 1'b1;
	end 
    else if (qv_loss_setting_mandatory_cnt) begin
        q_loss_timer_web = 1'b1;
    end
    else begin
        q_loss_timer_web = 1'b0;
    end
end

//-- qv_loss_timer_addrb --
always @(*) begin
	if(rst) begin 
		qv_loss_timer_addrb = 'd0;
	end 
	else if(LOSS_cur_state == LOSS_INIT_s) begin
		qv_loss_timer_addrb = qv_loss_init_counter;
	end 
    else if(LOSS_cur_state == LOSS_SCH_TC_s) begin
        qv_loss_timer_addrb = iv_tc_te_loss_data[31:8];
    end
    else if(LOSS_cur_state == LOSS_SCH_RC_s) begin
        qv_loss_timer_addrb = iv_rc_te_loss_data[31:8];
    end
    else begin
        qv_loss_timer_addrb = 'd0;
    end
end

//-- qv_loss_timer_dinb --
always @(*) begin
	if(rst) begin 
		qv_loss_timer_dinb = 'd0;
	end 
	else if(LOSS_cur_state == LOSS_INIT_s) begin
		qv_loss_timer_dinb = 'd0;
	end 
	else if (qv_loss_setting_mandatory_cnt) begin
        if(LOSS_cur_state == LOSS_SCH_TC_s) begin 
            if(iv_tc_te_loss_data[7:0] == `SET_TIMER) begin
                qv_loss_timer_dinb = {8'h0, iv_tc_te_loss_data[42:35], `TIMER_ACTIVE, 3'h0, iv_tc_te_loss_data[34:32]};
            end
            else if(iv_tc_te_loss_data[7:0] == `STOP_TIMER) begin
                qv_loss_timer_dinb = {8'h0, wv_loss_timer_doutb[14:7], `TIMER_INACTIVE, 3'h0, wv_loss_timer_doutb[2:0]};
            end
            else if(iv_tc_te_loss_data[7:0] == `RESTART_TIMER) begin
                qv_loss_timer_dinb = {8'h0, wv_loss_timer_doutb[14:7], `TIMER_ACTIVE, 3'h0, wv_loss_timer_doutb[2:0]};
            end
            else begin
                qv_loss_timer_dinb = 'd0;
            end
        end 
        else if(LOSS_cur_state == LOSS_SCH_RC_s) begin
            if(iv_rc_te_loss_data[7:0] == `SET_TIMER) begin
                qv_loss_timer_dinb = {8'h0, iv_rc_te_loss_data[42:35], `TIMER_ACTIVE, 3'h0, iv_rc_te_loss_data[34:32]};
            end
            else if(iv_rc_te_loss_data[7:0] == `STOP_TIMER) begin
                qv_loss_timer_dinb = {8'h0, wv_loss_timer_doutb[14:7], `TIMER_INACTIVE, 3'h0, wv_loss_timer_doutb[2:0]};
            end
            else if(iv_rc_te_loss_data[7:0] == `RESTART_TIMER) begin
                qv_loss_timer_dinb = {8'h0, wv_loss_timer_doutb[14:7], `TIMER_ACTIVE, 3'h0, wv_loss_timer_doutb[2:0]};
            end
            else begin
                qv_loss_timer_dinb = 'd0;
            end
        end
        else begin
            qv_loss_timer_dinb = 'd0;
        end
    end
    else begin
        qv_loss_timer_dinb = 'd0;
    end
end

//-- q_tc_te_loss_rd_en --
always @(*) begin
	if(rst) begin 	
   		q_tc_te_loss_rd_en = 'd0;
	end 
	else if(LOSS_cur_state == LOSS_SCH_TC_s && qv_loss_setting_mandatory_cnt == 0) begin 
		q_tc_te_loss_rd_en = 'd1;	
	end
	else begin 
		q_tc_te_loss_rd_en = 'd0;
	end 
end

//-- q_rc_te_loss_rd_en --
always @(*) begin
	if(rst) begin 
		q_rc_te_loss_rd_en = 'd0;
	end 
    else if(LOSS_cur_state == LOSS_SCH_RC_s && qv_loss_setting_mandatory_cnt == 0) begin
		q_rc_te_loss_rd_en = 'd1;
	end 
	else begin 
		q_rc_te_loss_rd_en = 'd0;
	end 
end

assign o_timer_init_finish = (qv_loss_init_counter == `TIMER_NUM) && (qv_rnr_init_counter == `TIMER_NUM);


/*------------------------------- connect dbg bus ----------------------------------------*/
wire   [`DBG_NUM_TIMER_CONTROL * 32 - 1 : 0]   coalesced_bus;

assign coalesced_bus = {
                            q_tc_te_loss_rd_en,
                            q_rc_te_loss_rd_en,
                            q_rc_te_rnr_rd_en,
                            q_loss_expire_wr_en,
                            q_rnr_expire_wr_en,
                            q_rnr_timer_wea,
                            q_rnr_timer_web,
                            q_loss_timer_wea,
                            q_loss_timer_web,
                            qv_loss_expire_data,
                            qv_rnr_expire_data,
                            qv_rnr_timer_addra,
                            qv_rnr_timer_dina,
                            qv_rnr_timer_addrb,
                            qv_rnr_timer_dinb,
                            qv_rnr_timer_addra_reg,
                            qv_rnr_iter_mandatory_cnt,
                            qv_rnr_setting_mandatory_cnt,
                            qv_loss_timer_addra,
                            qv_loss_timer_dina,
                            qv_loss_timer_addrb,
                            qv_loss_timer_dinb,
                            qv_loss_timer_addra_reg,
                            qv_loss_iter_mandatory_cnt,
                            qv_loss_setting_mandatory_cnt,
                            LOSS_cur_state,
                            LOSS_next_state,
                            wv_rnr_timer_douta,
                            wv_rnr_timer_doutb,
                            wv_rnr_retrans_threshold,
                            wv_rnr_retrans_cnt,
                            wv_rnr_state,
                            wv_rnr_timer_threshold,
                            wv_rnr_timer_cnt,
                            wv_loss_timer_douta,
                            wv_loss_timer_doutb,
                            wv_loss_retrans_threshold,
                            wv_loss_retrans_cnt,
                            wv_loss_state,
                            wv_loss_timer_threshold,
                            wv_loss_timer_cnt
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
                    (dbg_sel == 13) ?   coalesced_bus[32 * 14 - 1 : 32 * 13] : 32'd0;

//assign dbg_bus = coalesced_bus;

assign init_rw_data = {
						32'b00000000_00000000_00000000_11010101,
						32'b00000000_00000000_00000000_11010101
						};

endmodule
