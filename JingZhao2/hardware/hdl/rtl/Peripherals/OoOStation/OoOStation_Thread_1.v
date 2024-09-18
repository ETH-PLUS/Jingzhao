/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       OoOStation_Thread_1
Author:     YangFan
Function:   Handles Ingress Request. Enqueue Request to ReservationStation and issue resource command.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "common_function_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module OoOStation_Thread_1 #(
	parameter 		ID 							= 	1,

    //TAG_NUM is not equal to SLOT_NUM, since each resource req consumes 1 tag, and it may require more than 1 slot.
    parameter       TAG_NUM                     =   64,
    parameter       TAG_NUM_LOG                 =   log2b(TAG_NUM - 1),


    //RESOURCE_CMD/RESP_WIDTH is resource-specific
    //For example, MR resource cmd format is {PD, LKey, Lengtg, Addr}, MR resource reply format is {PTE-1, PTE-0, indicator}
    parameter       RESOURCE_CMD_HEAD_WIDTH     =   128,
    parameter       RESOURCE_CMD_DATA_WIDTH     =   256,
    parameter       RESOURCE_RESP_HEAD_WIDTH    =   128, 
    parameter       RESOURCE_RESP_DATA_WIDTH    =   128,

    parameter       SLOT_NUM                    =   512,
    parameter       QUEUE_NUM                   =   32,
    parameter       SLOT_NUM_LOG                =   log2b(SLOT_NUM - 1),
    parameter       QUEUE_NUM_LOG               =   log2b(QUEUE_NUM - 1),

    //When issuing cmd to Resource Manager, add tag index
    parameter       OOO_CMD_HEAD_WIDTH          =   TAG_NUM_LOG + RESOURCE_CMD_HEAD_WIDTH,
    parameter       OOO_CMD_DATA_WIDTH          =   RESOURCE_CMD_DATA_WIDTH,
    parameter       OOO_RESP_HEAD_WIDTH         =   TAG_NUM_LOG + RESOURCE_RESP_HEAD_WIDTH,
    parameter       OOO_RESP_DATA_WIDTH         =   RESOURCE_RESP_DATA_WIDTH,

    parameter       INGRESS_HEAD_WIDTH          =   RESOURCE_CMD_HEAD_WIDTH + SLOT_NUM_LOG + QUEUE_NUM_LOG + 1,
    //INGRESS_DATA_WIDTH is ingress-thread-specific
    parameter       INGRESS_DATA_WIDTH          =   512,

    parameter       SLOT_WIDTH                  =   INGRESS_DATA_WIDTH,


    //Egress thread
    parameter       EGRESS_HEAD_WIDTH           =   RESOURCE_RESP_HEAD_WIDTH + SLOT_NUM_LOG + QUEUE_NUM_LOG,
    parameter       EGRESS_DATA_WIDTH           =   INGRESS_DATA_WIDTH
)
(
    input   wire                                            		clk,
    input   wire                                            		rst,

//Interface with resource requester
    input   wire                                            		ingress_valid,
    input   wire        [INGRESS_HEAD_WIDTH - 1 : 0]        		ingress_head,
    input   wire        [SLOT_WIDTH - 1 : 0]                		ingress_data,
    input   wire                                            		ingress_start,
    input   wire                                            		ingress_last,
    output  wire                                            		ingress_ready,

//Interface with Resource Manager
    output  wire                                            		resource_req_valid,
    output  wire        [OOO_CMD_HEAD_WIDTH - 1 : 0]        		resource_req_head,
    output  wire        [OOO_CMD_DATA_WIDTH - 1 : 0]        		resource_req_data,
    output  wire                                            		resource_req_start,
    output  wire                                            		resource_req_last,
    input   wire                                            		resource_req_ready,

//Interface with Tag FIFO
	input 	wire                                            		tag_fifo_empty,
	input 	wire        [TAG_NUM_LOG - 1 : 0]           			tag_fifo_dout,
	output 	wire                                            		tag_fifo_rd_en,	

//Interface with Tag-QP mapping table
	output 	wire                                                	tag_mapping_wea,
	output 	wire    	[TAG_NUM_LOG - 1 : 0]                       tag_mapping_addra,
	output 	wire    	[QUEUE_NUM_LOG + 1 - 1 : 0]                 tag_mapping_dina,

//Interface with ReservationStation
	input 	wire 		[`MAX_OOO_SLOT_NUM_LOG : 0]					available_slot_num,

    output  wire                                                    empty_req_valid,
    output  wire        [`MAX_QP_NUM_LOG - 1 : 0]                 	empty_req_head,
    input  	wire                                                    empty_req_ready,

    input  	wire                                                    empty_resp_valid,
    input  	wire        [`MAX_QP_NUM_LOG : 0]                     	empty_resp_head,
    output  wire                                                    empty_resp_ready,  


	output 	wire 		                                            enqueue_req_valid,
	output 	wire 		[`MAX_QP_NUM_LOG + `MAX_OOO_SLOT_NUM_LOG - 1 : 0]      enqueue_req_head,
	output 	wire 		                                            enqueue_req_start,
	output 	wire 		                                            enqueue_req_last,
	output 	wire 		[SLOT_WIDTH - 1 : 0]                        enqueue_req_data,
	input 	wire 		                                            enqueue_req_ready,

//Interface with the following pipeline stage, used for bypass mode
    output  wire                                            		egress_valid,
    output  wire        [EGRESS_HEAD_WIDTH - 1 : 0]         		egress_head,
    output  wire        [EGRESS_DATA_WIDTH - 1 : 0]         		egress_data,
    output  wire                                            		egress_start,
    output  wire                                            		egress_last,
    input   wire                                            		egress_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define 	QUEUE_INDEX_OFFSET 				`MAX_QP_NUM_LOG - 1:0
`define 	SLOT_NUM_OFFSET					`MAX_OOO_SLOT_NUM_LOG + `MAX_QP_NUM_LOG - 1: `MAX_QP_NUM_LOG
`define 	BYPASS_OFFSET					`MAX_OOO_SLOT_NUM_LOG + `MAX_QP_NUM_LOG
`define 	RESOURCE_REQ_OFFSET				INGRESS_HEAD_WIDTH - 1 : `INGRESS_COMMON_HEAD_WIDTH
`define 	EMPTY_INDICATOR_OFFSET			`MAX_QP_NUM_LOG
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/


/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg 				[`MAX_QP_NUM_LOG - 1 : 0]				queue_index;
reg 				[`MAX_OOO_SLOT_NUM_LOG - 1 : 0]					slot_num;
reg 				[0:0]										bypass_mode;
reg 				[RESOURCE_CMD_HEAD_WIDTH - 1 : 0]			resource_req;

wire 															queue_empty;

wire 				[`MAX_REQ_TAG_NUM_LOG - 1 : 0]				req_tag;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg                 [2:0]                       cur_state;
reg                 [2:0]                       next_state;

parameter           [2:0]                      	IDLE_s = 3'd1,
												JUDGE_s = 3'd2,
												ENQUEUE_META_s = 3'd3,
												ENQUEUE_DATA_s = 3'd4,
												RESOURCE_REQ_s = 3'd5,
												BYPASS_s = 3'd6;

always @(posedge clk or posedge rst) begin
	if(rst) begin
		cur_state <= IDLE_s;
	end
	else begin
		cur_state <= next_state;
	end
end

always @(*) begin
	case(cur_state)
		IDLE_s:					if(ingress_valid && ingress_head[`SLOT_NUM_OFFSET] <= available_slot_num && !tag_fifo_empty) begin
									if(empty_req_valid && empty_req_ready) begin
										next_state = JUDGE_s;
									end
									else begin
										next_state = IDLE_s;
									end
								end
								else begin
									next_state = IDLE_s;
								end
		JUDGE_s:				if(empty_resp_valid) begin
									if(!bypass_mode) begin
										next_state = ENQUEUE_META_s;
									end
									else if(bypass_mode && !queue_empty) begin
										next_state = ENQUEUE_META_s;
									end
									else if(bypass_mode && queue_empty) begin
										next_state = BYPASS_s;
									end
									else begin
										next_state = IDLE_s;
									end
								end
								else begin
									next_state = JUDGE_s;
								end
		ENQUEUE_META_s:			if(enqueue_req_valid && enqueue_req_ready) begin
									next_state = ENQUEUE_DATA_s;
								end
								else begin
									next_state = ENQUEUE_META_s;
								end
		ENQUEUE_DATA_s:			if(enqueue_req_valid && enqueue_req_ready && ingress_last) begin
									if(!bypass_mode) begin
										next_state = RESOURCE_REQ_s;
									end 
									else begin
										next_state = IDLE_s;
									end
								end
								else begin
									next_state = ENQUEUE_DATA_s;
								end
		RESOURCE_REQ_s:			if(resource_req_valid && resource_req_ready) begin
									next_state = IDLE_s;
								end
								else begin
 									next_state = RESOURCE_REQ_s;
								end
		BYPASS_s:				if(ingress_valid && ingress_last && egress_valid && egress_ready) begin
									next_state = IDLE_s;
								end
								else begin
									next_state = BYPASS_s;
								end
		default:				next_state = IDLE_s;
	endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- queue_empty --
assign queue_empty = empty_resp_head[`EMPTY_INDICATOR_OFFSET];

//-- queue_index --
//-- slot_num --
//-- bypass_mode --
//-- resource_req --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		queue_index <= 'd0;
		slot_num <= 'd0;
		bypass_mode <= 'd0;
		resource_req <= 'd0;
	end
	else if(cur_state == IDLE_s && next_state == JUDGE_s) begin
		queue_index <= ingress_head[`QUEUE_INDEX_OFFSET];
		slot_num <= ingress_head[`SLOT_NUM_OFFSET];
		bypass_mode <= ingress_head[`BYPASS_OFFSET];
		resource_req <= ingress_head[`RESOURCE_REQ_OFFSET];
	end
	else begin
		queue_index <= queue_index;
		slot_num <= slot_num;
		bypass_mode <= bypass_mode;
		resource_req <= resource_req;
	end
end

//-- ingress_ready --
assign ingress_ready =  (cur_state == ENQUEUE_META_s) ? 'd0 : 
						(cur_state == ENQUEUE_DATA_s) ? enqueue_req_ready :
						(cur_state == BYPASS_s) ? egress_ready : 'd0;

//-- req_tag --
assign req_tag = {'d0, tag_fifo_dout};

//-- resource_req_valid --
//-- resource_req_head --
//-- resource_req_data --
//-- resource_req_start --
//-- resource_req_last --
assign resource_req_valid = (cur_state == RESOURCE_REQ_s) ? 'd1 : 'd0;
assign resource_req_head = (cur_state == RESOURCE_REQ_s) ? {resource_req, req_tag} : 'd0;
assign resource_req_data = 'd0;			//Currently we do not support resource req with data
assign resource_req_start = (cur_state == RESOURCE_REQ_s) ? 'd1 : 'd0;
assign resource_req_last = (cur_state == RESOURCE_REQ_s) ? 'd1 : 'd0;

//-- tag_fifo_rd_en --
assign tag_fifo_rd_en = (cur_state == RESOURCE_REQ_s && resource_req_valid && resource_req_ready) ? 'd1 : 'd0;

//-- tag_mapping_wea --
//-- tag_mapping_addra --
//-- tag_mapping_dina --
assign tag_mapping_wea = (cur_state == ENQUEUE_META_s) ? 'd1 : 'd0;
assign tag_mapping_addra = (cur_state == ENQUEUE_META_s) ? tag_fifo_dout : 'd0;
assign tag_mapping_dina = (cur_state == ENQUEUE_META_s) ? queue_index : 'd0;


//-- empty_req_valid --
//-- empty_req_head --
assign empty_req_valid = (cur_state == IDLE_s && ingress_valid && ingress_head[`SLOT_NUM_OFFSET] <= available_slot_num && !tag_fifo_empty) ? 'd1 : 'd0;
assign empty_req_head  = (cur_state == IDLE_s && ingress_valid && ingress_head[`SLOT_NUM_OFFSET] <= available_slot_num && !tag_fifo_empty) ? {ingress_head[`QUEUE_INDEX_OFFSET]} : 'd0;

//-- empty_resp_ready --
assign empty_resp_ready = (cur_state == JUDGE_s) ? 'd1 : 'd0;

//-- enqueue_req_valid --
//-- enqueue_req_head --
//-- enqueue_req_start --
//-- enqueue_req_last --
//-- enqueue_req_data --
assign enqueue_req_valid = 	(cur_state == ENQUEUE_META_s) ? 'd1 : 
							(cur_state == ENQUEUE_DATA_s && ingress_valid) ? 'd1 : 'd0;
assign enqueue_req_head = 	(cur_state == ENQUEUE_META_s) ? {slot_num + 15'd1, queue_index} : 'd0;
assign enqueue_req_start = 	(cur_state == ENQUEUE_META_s) ? 'd1 : 'd0;
assign enqueue_req_last = 	(cur_state == ENQUEUE_DATA_s) ? ingress_last : 'd0;
assign enqueue_req_data = 	(cur_state == ENQUEUE_META_s) ? {bypass_mode, slot_num + 15'd1, req_tag} :
							(cur_state == ENQUEUE_DATA_s) ? ingress_data : 'd0;

//-- egress_valid --
//-- egress_head --
//-- egress_data --
//-- egress_start --
//-- egress_last --
assign egress_valid = (cur_state == BYPASS_s) ? 'd1 : 'd0;
assign egress_head = (cur_state == BYPASS_s) ? {'d0, slot_num, queue_index} : 'd0;
assign egress_data = (cur_state == BYPASS_s) ? ingress_data : 'd0;
assign egress_start = (cur_state == BYPASS_s) ? ingress_start : 'd0;
assign egress_last = (cur_state == BYPASS_s) ? ingress_last : 'd0;
/*------------------------------------------- Variables Decode : End ------------------------------------------------*/

// `ifdef  ILA_ON
//     generate
//         if(ID == 1) begin
//             ila_ooo ila_ooo_inst(
//             	.clk(clk),
            
//     			.probe0(ingress_valid),
//     			.probe1(ingress_head),
//     			.probe2(ingress_data),
//     			.probe3(ingress_start),
//     			.probe4(ingress_last),
//     			.probe5(ingress_ready),

//     			.probe6(resource_req_valid),
//     			.probe7(resource_req_head),
//     			.probe8(resource_req_data),
//     			.probe9(resource_req_start),
//     			.probe10(resource_req_last),
//     			.probe11(resource_req_ready),

//     			.probe12(available_slot_num),

// 				.probe13(tag_fifo_empty),
// 				.probe14(tag_fifo_dout),
// 				.probe15(tag_fifo_rd_en),

// 				.probe16(empty_req_valid),
// 				.probe17(empty_req_head),
// 				.probe18(empty_req_ready),

// 				.probe19(empty_resp_valid),
// 				.probe20(empty_resp_head),
// 				.probe21(empty_resp_ready)
//             );
//         end
//     endgenerate
// `endif


/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef 	QUEUE_INDEX_OFFSET
`undef 	SLOT_NUM_OFFSET
`undef 	BYPASS_OFFSET
`undef 	RESOURCE_REQ_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/
endmodule