/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       SWAccCMCtl_Thread_5
Author:     YangFan
Function:   Handle ICMMapping Command from CEU.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/


/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module SWAccCMCtl_Thread_5
#(
    parameter               ICM_PAGE_NUM            =       `ICM_PAGE_NUM_EQC,
    parameter               ICM_PAGE_NUM_LOG        =       log2b(ICM_PAGE_NUM - 1)
)
(
    input   wire                                                                                                clk,
    input   wire                                                                                                rst,

//Interface with SWAccCMCtl_Thread_0
    input   wire                                                                                                map_req_valid,
    input   wire    [`CEU_CXT_HEAD_WIDTH - 1 : 0]                                                               map_req_head,
    input   wire                                                                                                map_req_last,
    input   wire    [`CEU_CXT_DATA_WIDTH - 1 : 0]                                                               map_req_data,
    output  wire                                                                                                map_req_ready,

//Set QPC ICM Mapping Table Entry
    output  reg                                                                                                 qpc_mapping_set_valid,
    output  reg     [`PAGE_FRAME_WIDTH - 1 : 0]                                                                 qpc_mapping_set_head,
    output  reg     [`PAGE_FRAME_WIDTH - 1 : 0]                                                                 qpc_mapping_set_data,

//Set CQC ICM Mapping Table Entry
    output  reg                                                                                                 cqc_mapping_set_valid,
    output  reg     [`PAGE_FRAME_WIDTH - 1 : 0]                                                                 cqc_mapping_set_head,
    output  reg     [`PAGE_FRAME_WIDTH - 1 : 0]                                                                 cqc_mapping_set_data,

//Set EQC ICM Mapping Table Entry
    output  reg                                                                                                 eqc_mapping_set_valid,
    output  reg     [`PAGE_FRAME_WIDTH - 1 : 0]                                                                 eqc_mapping_set_head,
    output  reg     [`PAGE_FRAME_WIDTH - 1 : 0]                                                                 eqc_mapping_set_data,

    output 	reg 	[`ICM_SPACE_ADDR_WIDTH - 1 : 0]																qpc_base,
    output 	reg 	[`ICM_SPACE_ADDR_WIDTH - 1 : 0]																cqc_base,
    output 	reg 	[`ICM_SPACE_ADDR_WIDTH - 1 : 0]																eqc_base

);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define 	CEU_CMD_TYPE_OFFSET 				127:124
`define 	CEU_CMD_OPCODE_OFFSET				123:120
`define 	CEU_CMD_CHUNK_NUM_OFFSET			95:64

`define 	EQC_BASE_OFFSET						63:8
`define 	EQC_NUM_LOG_OFFSET					7:0
`define 	CQC_BASE_OFFSET						63+64:8+64
`define 	CQC_NUM_LOG_OFFSET					7+64:0+64
`define 	QPC_BASE_OFFSET						63+128:8+128
`define 	QPC_NUM_LOG_OFFSET					7+128:0+128

`define 	HIGH_ENTRY_ICM_ADDR_OFFSET			255:192
`define 	LOW_ENTRY_ICM_ADDR_OFFSET			127:64
`define 	HIGH_ENTRY_PHY_ADDR_OFFSET			191:140
`define 	LOW_ENTRY_PHY_ADDR_OFFSET			63:12
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/

reg 		[31:0]							qpc_num;
reg 		[63:0]							qpc_end;

reg 		[31:0]							cqc_num;
reg 		[63:0]							cqc_end;

reg 		[31:0]							eqc_num;
reg 		[63:0]							eqc_end;

reg 		[31:0]							chunk_num_left;


wire 		[63:0]							icm_addr;
wire 		[51:0]							phy_addr;
wire 		[63:0]							qpc_addr;
wire 		[63:0]							cqc_addr;
wire 		[63:0]							eqc_addr;

wire 										is_qpc_mapping;
wire 										is_cqc_mapping;
wire 										is_eqc_mapping;


/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg 		[2:0]							cur_state;
reg 		[2:0]							next_state;

parameter 	[2:0]							IDLE_s = 3'd1,
											MAP_BASE_s = 3'd2,
											MAP_HIGH_s = 3'd3,
											MAP_LOW_s = 3'd4,
											MAP_DIS_s = 3'd5,
											ICM_DIS_s = 3'd6;

always @(posedge clk or posedge rst) begin
	if (rst) begin
		cur_state <= IDLE_s;		
	end
	else begin
		cur_state <= next_state;
	end
end

always @(*) begin
	case(cur_state)
		IDLE_s:			if(map_req_valid) begin
							if(map_req_head[`CEU_CMD_TYPE_OFFSET] == `WR_ICMMAP_CXT && map_req_head[`CEU_CMD_OPCODE_OFFSET] == `WR_ICMMAP_EN) begin
								next_state = MAP_BASE_s;
							end
							else if(map_req_head[`CEU_CMD_TYPE_OFFSET] == `WR_ICMMAP_CXT && map_req_head[`CEU_CMD_OPCODE_OFFSET] == `WR_ICMMAP_DIS) begin
								next_state = MAP_DIS_s;
							end
							else if(map_req_head[`CEU_CMD_TYPE_OFFSET] == `MAP_ICM_CXT && map_req_head[`CEU_CMD_OPCODE_OFFSET] == `MAP_ICM_EN) begin
								next_state = MAP_LOW_s;
							end
							else if(map_req_head[`CEU_CMD_TYPE_OFFSET] == `MAP_ICM_CXT && map_req_head[`CEU_CMD_OPCODE_OFFSET] == `MAP_ICM_DIS) begin
								next_state = ICM_DIS_s;
							end							
							else begin
								next_state = IDLE_s;
							end
						end
						else begin
							next_state = IDLE_s;
						end
		MAP_BASE_s:		next_state = IDLE_s;
		MAP_HIGH_s:		if(map_req_valid && chunk_num_left == 1) begin
							next_state = IDLE_s;
						end
						else if(map_req_valid && chunk_num_left > 1) begin
							next_state = MAP_LOW_s;
						end
						else begin
							next_state = MAP_HIGH_s;
						end
		MAP_LOW_s:		if(map_req_valid && chunk_num_left == 1) begin
							next_state = IDLE_s;
						end
						else if(map_req_valid && chunk_num_left > 1) begin
							next_state = MAP_HIGH_s;
						end
						else begin
							next_state = MAP_LOW_s;
						end
		default:		next_state = IDLE_s;
	endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- icm_addr --
assign icm_addr = (cur_state == MAP_HIGH_s && map_req_valid) ? map_req_data[`HIGH_ENTRY_ICM_ADDR_OFFSET] : 
				  (cur_state == MAP_LOW_s && map_req_valid) ? map_req_data[`LOW_ENTRY_ICM_ADDR_OFFSET] : 'd0;

//-- phy_addr --
assign phy_addr = (cur_state == MAP_HIGH_s && map_req_valid) ? map_req_data[`HIGH_ENTRY_PHY_ADDR_OFFSET] : 
				  (cur_state == MAP_LOW_s && map_req_valid) ? map_req_data[`LOW_ENTRY_PHY_ADDR_OFFSET] : 'd0;

//-- is_qpc_mapping --
//-- is_cqc_mapping --
//-- is_eqc_mapping --
assign is_qpc_mapping = (cur_state == MAP_HIGH_s || cur_state == MAP_LOW_s) && map_req_valid && (icm_addr >= qpc_base && icm_addr < qpc_end) ? 'd1 : 'd0;
assign is_cqc_mapping = (cur_state == MAP_HIGH_s || cur_state == MAP_LOW_s) && map_req_valid && (icm_addr >= cqc_base && icm_addr < cqc_end) ? 'd1 : 'd0;
assign is_eqc_mapping = (cur_state == MAP_HIGH_s || cur_state == MAP_LOW_s) && map_req_valid && (icm_addr >= eqc_base && icm_addr < eqc_end) ? 'd1 : 'd0;

//-- qpc_addr --
//-- cqc_addr --
//-- eqc_addr --
assign qpc_addr = is_qpc_mapping ? icm_addr[63:12] : 'd0;			//Only need ICM Page Frame
assign cqc_addr = is_cqc_mapping ? icm_addr[63:12] : 'd0;
assign eqc_addr = is_eqc_mapping ? icm_addr[63:12] : 'd0;

//-- chunk_num_left --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		chunk_num_left <= 'd0;
	end
	else if(cur_state == IDLE_s && map_req_valid && map_req_head[`CEU_CMD_TYPE_OFFSET == `MAP_ICM_CXT] && map_req_head[`CEU_CMD_OPCODE_OFFSET] == `MAP_ICM_EN) begin
		chunk_num_left <= map_req_head[`CEU_CMD_CHUNK_NUM_OFFSET];
	end
	else if(cur_state == MAP_HIGH_s && map_req_valid) begin
		chunk_num_left <= chunk_num_left - 'd1;
	end
	else if(cur_state == MAP_LOW_s && map_req_valid) begin
		chunk_num_left <= chunk_num_left - 'd1;
	end
	else begin
		chunk_num_left <= chunk_num_left;
	end
end

//-- qpc_base --
//-- qpc_num --
//-- qpc_end --
//-- cqc_base --
//-- cqc_num --
//-- cqc_end --
//-- eqc_base --
//-- eqc_num --
//-- eqc_end --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		qpc_base <= 'd0;
		qpc_num <= 'd0;
		qpc_end <= 'd0;

		cqc_base <= 'd0;
		cqc_num <= 'd0;
		cqc_end <= 'd0;

		eqc_base <= 'd0;
		eqc_num <= 'd0;
		eqc_end <= 'd0;
	end
	else if(cur_state == MAP_BASE_s) begin
		qpc_base <= {map_req_data[`QPC_BASE_OFFSET], 8'd0};
		qpc_num <= 1 << map_req_data[`QPC_NUM_LOG_OFFSET];
		qpc_end <= {map_req_data[`QPC_BASE_OFFSET], 8'd0} + (1 << map_req_data[`QPC_NUM_LOG_OFFSET]) * `ICM_SLOT_SIZE_QPC;

		cqc_base <= {map_req_data[`CQC_BASE_OFFSET], 8'd0};
		cqc_num <= 1 << map_req_data[`CQC_NUM_LOG_OFFSET];
		cqc_end <= {map_req_data[`CQC_BASE_OFFSET], 8'd0} + (1 << map_req_data[`CQC_NUM_LOG_OFFSET]) * `ICM_SLOT_SIZE_CQC;

		eqc_base <= {map_req_data[`EQC_BASE_OFFSET], 8'd0};
		eqc_num <= 1 << map_req_data[`EQC_NUM_LOG_OFFSET];
		eqc_end <= {map_req_data[`EQC_BASE_OFFSET], 8'd0} + (1 << map_req_data[`EQC_NUM_LOG_OFFSET]) * `ICM_SLOT_SIZE_EQC;
	end
	else begin
		qpc_base <= qpc_base;
		qpc_num <= qpc_num;
		qpc_end <= qpc_end;

		cqc_base <= cqc_base;
		cqc_num <= cqc_num;
		cqc_end <= cqc_end;

		eqc_base <= eqc_base;
		eqc_num <= eqc_num;
		eqc_end <= eqc_end;
	end
end


//-- qpc_mapping_set_valid --
//-- qpc_mapping_set_head --
//-- qpc_mapping_set_data --
//-- cqc_mapping_set_valid --
//-- cqc_mapping_set_head --
//-- cqc_mapping_set_data --
//-- eqc_mapping_set_valid --
//-- eqc_mapping_set_head --
//-- eqc_mapping_set_data --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		qpc_mapping_set_valid <= 'd0;
		qpc_mapping_set_head <= 'd0;
		qpc_mapping_set_data <= 'd0;

		cqc_mapping_set_valid <= 'd0;
		cqc_mapping_set_head <= 'd0;
		cqc_mapping_set_data <= 'd0;

		eqc_mapping_set_valid <= 'd0;
		eqc_mapping_set_head <= 'd0;
		eqc_mapping_set_data <= 'd0;
	end
	else if(cur_state == MAP_HIGH_s && map_req_valid) begin
		qpc_mapping_set_valid <= is_qpc_mapping ? 'd1 : 'd0;
		qpc_mapping_set_head <= is_qpc_mapping ? qpc_addr : 'd0;
		qpc_mapping_set_data <= is_qpc_mapping ? phy_addr : 'd0;

		cqc_mapping_set_valid <= is_cqc_mapping ? 'd1 : 'd0;
		cqc_mapping_set_head <= is_cqc_mapping ? cqc_addr : 'd0;
		cqc_mapping_set_data <= is_cqc_mapping ? phy_addr : 'd0;

		eqc_mapping_set_valid <= is_eqc_mapping ? 'd1 : 'd0;
		eqc_mapping_set_head <= is_eqc_mapping ? eqc_addr : 'd0;
		eqc_mapping_set_data <= is_eqc_mapping ? phy_addr : 'd0;		
	end
	else if(cur_state == MAP_LOW_s && map_req_valid) begin
		qpc_mapping_set_valid <= is_qpc_mapping ? 'd1 : 'd0;
		qpc_mapping_set_head <= is_qpc_mapping ? qpc_addr : 'd0;
		qpc_mapping_set_data <= is_qpc_mapping ? phy_addr : 'd0;

		cqc_mapping_set_valid <= is_cqc_mapping ? 'd1 : 'd0;
		cqc_mapping_set_head <= is_cqc_mapping ? cqc_addr : 'd0;
		cqc_mapping_set_data <= is_cqc_mapping ? phy_addr : 'd0;

		eqc_mapping_set_valid <= is_eqc_mapping ? 'd1 : 'd0;
		eqc_mapping_set_head <= is_eqc_mapping ? eqc_addr : 'd0;
		eqc_mapping_set_data <= is_eqc_mapping ? phy_addr : 'd0;
	end
	else begin
		qpc_mapping_set_valid <= 'd0;
		qpc_mapping_set_head <= 'd0;
		qpc_mapping_set_data <= 'd0;

		cqc_mapping_set_valid <= 'd0;
		cqc_mapping_set_head <= 'd0;
		cqc_mapping_set_data <= 'd0;

		eqc_mapping_set_valid <= 'd0;
		eqc_mapping_set_head <= 'd0;
		eqc_mapping_set_data <= 'd0;		
	end
end

//-- map_req_ready --
assign map_req_ready = (cur_state == MAP_BASE_s) ? 'd1 : 
						(cur_state == MAP_LOW_s) ? 'd1 :
						(cur_state == MAP_HIGH_s && chunk_num_left == 1) ? 'd1 :
						(cur_state == MAP_DIS_s) ? 'd1 :
						(cur_state == ICM_DIS_s) ? 'd1 : 'd0;
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

`ifdef 		ILA_ON

ila_sw_acc_cm_thread_5 ila_sw_acc_cm_thread_5_inst(
	.clk(clk),

    .probe0(map_req_valid),
    .probe1(map_req_head),
    .probe2(map_req_data),
    .probe3(map_req_last),
    .probe4(map_req_ready),

    .probe5(qpc_mapping_set_valid),
    .probe6(qpc_mapping_set_head),
    .probe7(qpc_mapping_set_data),

    .probe8(cqc_mapping_set_valid),
    .probe9(cqc_mapping_set_head),
    .probe10(cqc_mapping_set_data),

    .probe11(eqc_mapping_set_valid),
    .probe12(eqc_mapping_set_head),
    .probe13(eqc_mapping_set_data),

    .probe14(qpc_base),
    .probe15(cqc_base),
    .probe16(eqc_base)
);

`endif

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef 	CEU_CMD_TYPE_OFFSET
`undef 	CEU_CMD_OPCODE_OFFSET
`undef 	CEU_CMD_CHUNK_NUM_OFFSET

`undef 	EQC_BASE_OFFSET
`undef 	EQC_NUM_LOG_OFFSET
`undef 	CQC_BASE_OFFSET
`undef 	CQC_NUM_LOG_OFFSET
`undef 	QPC_BASE_OFFSET
`undef 	QPC_NUM_LOG_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule