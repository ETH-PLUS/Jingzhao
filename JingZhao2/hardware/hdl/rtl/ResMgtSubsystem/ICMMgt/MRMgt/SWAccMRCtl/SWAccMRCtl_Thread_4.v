/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       SWAccCMCtl_Thread_4
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
module SWAccMRCtl_Thread_4
(
    input   wire                                                                                                clk,
    input   wire                                                                                                rst,

//Interface with SWAccCMCtl_Thread_1
    input   wire                                                                                                map_req_valid,
    input   wire    [`CEU_MR_HEAD_WIDTH - 1 : 0]                                                               	map_req_head,
    input   wire                                                                                                map_req_last,
    input   wire    [`CEU_MR_DATA_WIDTH - 1 : 0]                                                               	map_req_data,
    output  wire                                                                                                map_req_ready,

//Set MPT ICM Mapping Table Entry
    output  reg                                                                                                 mpt_mapping_set_valid,
    output  reg     [`PAGE_FRAME_WIDTH - 1 : 0]                                                                 mpt_mapping_set_head,
    output  reg     [`PAGE_FRAME_WIDTH - 1 : 0]                                                                 mpt_mapping_set_data,

//Set MTT ICM Mapping Table Entry
    output  reg                                                                                                 mtt_mapping_set_valid,
    output  reg     [`PAGE_FRAME_WIDTH - 1 : 0]                                                                 mtt_mapping_set_head,
    output  reg     [`PAGE_FRAME_WIDTH - 1 : 0]                                                                 mtt_mapping_set_data,

    output 	reg 	[63:0]																						mpt_base,
    output 	reg 	[63:0]																						mtt_base

);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define 	CEU_CMD_TYPE_OFFSET 				127:124
`define 	CEU_CMD_OPCODE_OFFSET				123:120
`define 	CEU_CMD_CHUNK_NUM_OFFSET			95:64

`define 	MTT_BASE_OFFSET 					63:0
`define 	MPT_NUM_LOG_OFFSET 					71:64
`define 	MPT_BASE_OFFSET						127:72

`define 	HIGH_ENTRY_ICM_ADDR_OFFSET			255:192
`define 	LOW_ENTRY_ICM_ADDR_OFFSET			127:64
`define 	HIGH_ENTRY_PHY_ADDR_OFFSET			191:140
`define 	LOW_ENTRY_PHY_ADDR_OFFSET			63:12
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg 		[31:0]							mpt_num;

reg 		[63:0]							mpt_end;


reg 		[31:0]							chunk_num_left;


wire 		[63:0]							icm_addr;
wire 		[51:0]							phy_addr;
wire 		[63:0]							mpt_addr;
wire 		[63:0]							mtt_addr;

wire 										is_mpt_mapping;
wire 										is_mtt_mapping;

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
							if(map_req_head[`CEU_CMD_TYPE_OFFSET] == `WR_ICMMAP_TPT && map_req_head[`CEU_CMD_OPCODE_OFFSET] == `WR_ICMMAP_EN) begin
								next_state = MAP_BASE_s;
							end
							else if(map_req_head[`CEU_CMD_TYPE_OFFSET] == `WR_ICMMAP_TPT && map_req_head[`CEU_CMD_OPCODE_OFFSET] == `WR_ICMMAP_DIS) begin
								next_state = MAP_DIS_s;
							end
							else if(map_req_head[`CEU_CMD_TYPE_OFFSET] == `MAP_ICM_TPT && map_req_head[`CEU_CMD_OPCODE_OFFSET] == `MAP_ICM_EN) begin
								next_state = MAP_LOW_s;
							end
							else if(map_req_head[`CEU_CMD_TYPE_OFFSET] == `MAP_ICM_TPT && map_req_head[`CEU_CMD_OPCODE_OFFSET] == `MAP_ICM_DIS) begin
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

//-- is_mpt_mapping --
//-- is_mtt_mapping --
assign is_mpt_mapping = ((cur_state == MAP_HIGH_s || cur_state == MAP_LOW_s) && map_req_valid) && (icm_addr >= mpt_base && icm_addr < mpt_end) ? 'd1 : 'd0;
assign is_mtt_mapping = ((cur_state == MAP_HIGH_s || cur_state == MAP_LOW_s) && map_req_valid) && (icm_addr < mpt_base || icm_addr >= mpt_end) ? 'd1 : 'd0;

//-- mpt_addr --
//-- mtt_addr --
assign mpt_addr = is_mpt_mapping ? icm_addr[63:12] : 'd0;			//Only need ICM Page Frame
assign mtt_addr = is_mtt_mapping ? icm_addr[63:12] : 'd0;

//-- chunk_num_left --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		chunk_num_left <= 'd0;
	end
	else if(cur_state == IDLE_s && map_req_valid && map_req_head[`CEU_CMD_TYPE_OFFSET == `MAP_ICM_TPT] && map_req_head[`CEU_CMD_OPCODE_OFFSET] == `MAP_ICM_EN) begin
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

//-- mpt_base --
//-- mpt_end --
//-- mtt_base --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		mpt_base <= 'd0;
		mpt_num <= 'd0;
		mpt_end <= 'd0;
		mtt_base <= 'd0;
	end
	else if(cur_state == MAP_BASE_s) begin
		mpt_base <= {map_req_data[`MPT_BASE_OFFSET], 8'd0};
		mpt_num <= 1 << map_req_data[`MPT_NUM_LOG_OFFSET];
		mpt_end <= {map_req_data[`MPT_BASE_OFFSET], 8'd0} + (1 << map_req_data[`MPT_NUM_LOG_OFFSET]) * `ICM_SLOT_SIZE_MPT;
		mtt_base <= map_req_data[`MTT_BASE_OFFSET];
	end
	else begin
		mpt_base <= mpt_base;
		mpt_num <= mpt_num;
		mpt_end <= mpt_end;
		mtt_base <= mtt_base;
	end
end


//-- mpt_mapping_set_valid --
//-- mpt_mapping_set_head --
//-- mpt_mapping_set_data --
//-- mtt_mapping_set_valid --
//-- mtt_mapping_set_head --
//-- mtt_mapping_set_data --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		mpt_mapping_set_valid <= 'd0;
		mpt_mapping_set_head <= 'd0;
		mpt_mapping_set_data <= 'd0;

		mtt_mapping_set_valid <= 'd0;
		mtt_mapping_set_head <= 'd0;
		mtt_mapping_set_data <= 'd0;
	end
	else if(cur_state == MAP_HIGH_s && map_req_valid) begin
		mpt_mapping_set_valid <= is_mpt_mapping ? 'd1 : 'd0;
		mpt_mapping_set_head <= is_mpt_mapping ? mpt_addr : 'd0;
		mpt_mapping_set_data <= is_mpt_mapping ? phy_addr : 'd0;

		mtt_mapping_set_valid <= is_mtt_mapping ? 'd1 : 'd0;
		mtt_mapping_set_head <= is_mtt_mapping ? mtt_addr : 'd0;
		mtt_mapping_set_data <= is_mtt_mapping ? phy_addr : 'd0;
	end
	else if(cur_state == MAP_LOW_s && map_req_valid) begin
		mpt_mapping_set_valid <= is_mpt_mapping ? 'd1 : 'd0;
		mpt_mapping_set_head <= is_mpt_mapping ? mpt_addr : 'd0;
		mpt_mapping_set_data <= is_mpt_mapping ? phy_addr : 'd0;

		mtt_mapping_set_valid <= is_mtt_mapping ? 'd1 : 'd0;
		mtt_mapping_set_head <= is_mtt_mapping ? mtt_addr : 'd0;
		mtt_mapping_set_data <= is_mtt_mapping ? phy_addr : 'd0;
	end
	else begin
		mpt_mapping_set_valid <= 'd0;
		mpt_mapping_set_head <= 'd0;
		mpt_mapping_set_data <= 'd0;

		mtt_mapping_set_valid <= 'd0;
		mtt_mapping_set_head <= 'd0;
		mtt_mapping_set_data <= 'd0;
	end
end

//-- map_req_ready --
assign map_req_ready = (cur_state == MAP_BASE_s) ? 'd1 : 
						(cur_state == MAP_LOW_s) ? 'd1 :
						(cur_state == MAP_HIGH_s && chunk_num_left == 1) ? 'd1 :
						(cur_state == MAP_DIS_s) ? 'd1 :
						(cur_state == ICM_DIS_s) ? 'd1 : 'd0;

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef 	CEU_CMD_TYPE_OFFSET
`undef 	CEU_CMD_OPCODE_OFFSET
`undef 	CEU_CMD_CHUNK_NUM_OFFSET

`undef 	MPT_BASE_OFFSET
`undef 	MTT_BASE_OFFSET
`undef 	MPT_NUM_LOG_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule