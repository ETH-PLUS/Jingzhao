/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       OoOStation_Thread_2
Author:     YangFan
Function:   Handle out-of-order response.
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
module OoOStation_Thread_2 #(
    parameter       ID                          =  1,

    //TAG_NUM is not equal to SLOT_NUM, since each resource req consumes 1 tag, and it may require more than 1 slot.
    parameter       TAG_NUM                     =   64 + 1,     //+1 since tag 0 is left unused(for special purpose in Resource Manager)
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
    input   wire                                                                clk,
    input   wire                                                                rst,

//Interface with Resource Manager
    input   wire                                                                resource_resp_valid,
    input   wire        [OOO_RESP_HEAD_WIDTH - 1 : 0]                           resource_resp_head,
    input   wire        [OOO_RESP_DATA_WIDTH - 1 : 0]                           resource_resp_data,
    input   wire                                                                resource_resp_start,
    input   wire                                                                resource_resp_last,
    output  wire                                                                resource_resp_ready,

//Interface with Reservation Station
    output  wire                                                                get_req_valid,
    output  wire        [`MAX_QP_NUM_LOG - 1 : 0]                               get_req_head,
    input   wire                                                                get_req_ready,
    
    input   wire                                                                get_resp_valid,
    input   wire                                                                get_resp_empty,
    input   wire        [SLOT_WIDTH - 1 : 0]                                    get_resp_data,
    output  wire                                                                get_resp_ready,

    output  wire                                                                dequeue_req_valid,
    output  wire        [`MAX_QP_NUM_LOG + `MAX_OOO_SLOT_NUM_LOG - 1 : 0]       dequeue_req_head,
    input   wire                                                                dequeue_req_ready,

    input   wire                                                                dequeue_resp_valid,
    input   wire        [`MAX_QP_NUM_LOG + `MAX_OOO_SLOT_NUM_LOG - 1 : 0]       dequeue_resp_head,
    input   wire                                                                dequeue_resp_start,
    input   wire                                                                dequeue_resp_last,
    input   wire        [SLOT_WIDTH - 1 : 0]                                    dequeue_resp_data,
    output  wire                                                                dequeue_resp_ready,

//Interface with Reorder Buffer
    output  wire                                                                reorder_buffer_wea,
    output  wire        [TAG_NUM_LOG - 1 : 0]                                   reorder_buffer_addra,
    output  wire        [RESOURCE_RESP_DATA_WIDTH + 1 - 1 : 0]                  reorder_buffer_dina,    //+1 for valid

    output  wire        [TAG_NUM_LOG - 1 : 0]                                   reorder_buffer_addrb,
    input   wire        [RESOURCE_RESP_DATA_WIDTH + 1 - 1 : 0]                  reorder_buffer_doutb,

//Interface with Tag FIFO
    output  reg                                                                 tag_fifo_wr_en,
    output  reg        [TAG_NUM_LOG - 1 : 0]                                    tag_fifo_din,
    input   wire                                                                tag_fifo_prog_full, 

//Interface with Tag-QP mapping table
    output  wire        [TAG_NUM_LOG - 1 : 0]                                   tag_mapping_addrb,
    input   wire        [QUEUE_NUM_LOG - 1 : 0]                                 tag_mapping_doutb,

    output  wire                                                                egress_valid,
    output  wire        [EGRESS_HEAD_WIDTH - 1 : 0]                             egress_head,
    output  wire        [EGRESS_DATA_WIDTH - 1 : 0]                             egress_data,
    output  wire                                                                egress_start,
    output  wire                                                                egress_last,
    input   wire                                                                egress_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     TAG_OFFSET                      `MAX_REQ_TAG_NUM_LOG - 1:0
`define     VALID_OFFSET                    RESOURCE_RESP_DATA_WIDTH
`define     SLOT_NUM_OFFSET                 `MAX_OOO_SLOT_NUM_LOG + `MAX_REQ_TAG_NUM_LOG:`MAX_REQ_TAG_NUM_LOG
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg         [`MAX_REQ_TAG_NUM_LOG : 0]                  tag_init_counter;
reg         [`MAX_QP_NUM_LOG - 1 : 0]                   queue_index;
reg         [`MAX_REQ_TAG_NUM_LOG - 1 : 0]              queue_head_tag;
wire                                                    resource_available;
reg         [`MAX_OOO_SLOT_NUM_LOG - 1 : 0]             slot_num;

reg         [`MAX_REQ_TAG_NUM_LOG - 1 : 0]              tag_mapping_addrb_diff;

reg         [RESOURCE_RESP_DATA_WIDTH - 1 : 0]          resource_data;
reg                                                     start_flag;

wire        [`EGRESS_COMMON_HEAD_WIDTH - 1 : 0]         egress_common_head;

reg  											        bypass_mode;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
wire                                                    st_resource_resp_valid;
wire        [OOO_RESP_HEAD_WIDTH - 1 : 0]               st_resource_resp_head;
wire        [OOO_RESP_DATA_WIDTH - 1 : 0]               st_resource_resp_data;
wire                                                    st_resource_resp_start;
wire                                                    st_resource_resp_last;
wire                                                    st_resource_resp_ready;

stream_reg #(
    .TUSER_WIDTH    (       OOO_RESP_HEAD_WIDTH ),
    .TDATA_WIDTH    (       OOO_RESP_DATA_WIDTH ),
    
    .MODE           (       0                   ),
    .NUM_LEVELS     (       4                   )
) st_resource_resp(
    .clk                (       clk         ),
    .rst_n              (       ~rst        ),


    .axis_tvalid        (   resource_resp_valid     ), 
    .axis_tlast         (   resource_resp_last      ), 
    .axis_tuser         (   resource_resp_head      ), 
    .axis_tdata         (   resource_resp_data      ), 
    .axis_tready        (   resource_resp_ready     ), 
    .axis_tstart        (   resource_resp_valid     ),
    .axis_tkeep         (   'd0                     ),

    .in_reg_tvalid      (   st_resource_resp_valid  ),  
    .in_reg_tlast       (   st_resource_resp_last   ), 
    .in_reg_tuser       (   st_resource_resp_head   ),
    .in_reg_tdata       (   st_resource_resp_data   ),
    .in_reg_tkeep       (                           ),
    .in_reg_tstart      (                           ),
    .in_reg_tready      (   st_resource_resp_ready  )
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg                 [3:0]                       cur_state;
reg                 [3:0]                       next_state;

parameter           INIT_s       	=   4'd1,
                    IDLE_s       	=   4'd2,
                    GET_CMD_s      	=	4'd3,
                    GET_RESP_s      =   4'd4,
                    JUDGE_s      	=   4'd5,
                    DEQUEUE_REQ_s   =   4'd6,
                    DEQUEUE_META_s  =   4'd7,
                    DEQUEUE_DATA_s  =   4'd8;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        cur_state <= INIT_s;
    end
    else begin
        cur_state <= next_state;
    end
end

always @(*) begin
    case(cur_state)
        INIT_s:             if(tag_init_counter + 1 == TAG_NUM) begin
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = INIT_s;
                            end
        IDLE_s:             if(st_resource_resp_valid) begin
                                next_state = GET_CMD_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
        GET_CMD_s:          if(get_req_valid && get_req_ready) begin
                                next_state = GET_RESP_s;
                            end
                            else begin
                                next_state = GET_CMD_s;
                            end
        GET_RESP_s:         if(get_resp_valid && get_resp_ready) begin
                                if(!get_resp_empty) begin
                                    next_state = JUDGE_s;
                                end
                                else begin
                                    next_state = IDLE_s;
                                end
                            end
                            else begin
                                next_state = GET_RESP_s;
                            end
        JUDGE_s:            if(bypass_mode) begin
        						next_state = DEQUEUE_REQ_s;
        					end
        					else if(resource_available) begin
                                next_state = DEQUEUE_REQ_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
        DEQUEUE_REQ_s:      if(dequeue_req_valid && dequeue_req_ready) begin
                                next_state = DEQUEUE_META_s;
                            end
                            else begin
                                next_state = DEQUEUE_REQ_s;
                            end
        DEQUEUE_META_s:     if(dequeue_resp_valid && dequeue_resp_ready) begin
                                next_state = DEQUEUE_DATA_s;
                            end
                            else begin
                                next_state = DEQUEUE_META_s;
                            end
        DEQUEUE_DATA_s:     if(dequeue_resp_valid && dequeue_resp_last && dequeue_resp_ready) begin
                                next_state = GET_CMD_s;
                            end
                            else begin
                                next_state = DEQUEUE_DATA_s;
                            end
        default:            next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
reg         [31:0]          get_cnt;    //Used to deal with a corner case, since tag_mapping_dout is only valid in first get cmd, after dequeuing, tag is freed, tag_mapping may be changed by thread_1
//-- dequeue_cnt --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        get_cnt <= 'd0; 
    end
    else if (cur_state == IDLE_s && st_resource_resp_valid) begin
        get_cnt <= 'd0;
    end
    else if(cur_state == GET_CMD_s && get_req_valid && get_req_ready) begin
        get_cnt <= get_cnt + 'd1;
    end
    else begin
        get_cnt <= get_cnt;
    end
end

//-- tag_init_counter --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        tag_init_counter <= 'd1;
    end
    else if(cur_state == INIT_s && tag_init_counter < TAG_NUM) begin
        tag_init_counter <= tag_init_counter + 'd1;
    end
    else begin
        tag_init_counter <= tag_init_counter;
    end
end

//-- queue_index --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        queue_index <= 'd0;
    end
    else if(cur_state == GET_CMD_s && get_cnt == 'd0) begin
        queue_index <= {'d0, tag_mapping_doutb};
    end
    else begin
        queue_index <= queue_index;
    end
end

//-- slot_num --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        slot_num <= 'd0;        
    end
    else if (cur_state == GET_RESP_s && get_resp_valid) begin
        slot_num <= get_resp_data[`SLOT_NUM_OFFSET];
    end
    else begin
        slot_num <= slot_num;
    end
end

//-- queue_head_tag --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        queue_head_tag <= 'd0;        
    end
    else if (cur_state == GET_RESP_s && get_resp_valid) begin
        queue_head_tag <= get_resp_data[`TAG_OFFSET];
    end
    else begin
        queue_head_tag <= queue_head_tag;
    end
end

//-- resource_data --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        resource_data <= 'd0;
    end
    else if(cur_state == JUDGE_s) begin
        resource_data <= reorder_buffer_doutb[RESOURCE_RESP_DATA_WIDTH - 1 : 0];
    end
    else begin
        resource_data <= resource_data;
    end
end

//-- start_flag --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        start_flag <= 'd0;        
    end
    else if (cur_state == DEQUEUE_META_s && next_state == DEQUEUE_DATA_s) begin
        start_flag <= 'd1;
    end
    else if(cur_state == DEQUEUE_DATA_s && egress_valid && egress_ready) begin
        start_flag <= 'd0;
    end
    else begin
        start_flag <= start_flag;
    end
end

//-- resource_available --
assign resource_available = (cur_state == JUDGE_s) ? reorder_buffer_doutb[`VALID_OFFSET] : 'd0;

//-- st_resource_resp_ready --
assign st_resource_resp_ready = (cur_state == IDLE_s) ? 'd1 : 'd0;

wire        [`MAX_QP_NUM_LOG - 1 : 0]       get_cmd_queue_index;
assign get_cmd_queue_index = (cur_state == GET_CMD_s && get_cnt == 'd0) ? tag_mapping_doutb : queue_index;

//--get_req_valid --
//--get_req_head --
assign get_req_valid = (cur_state == GET_CMD_s) ? 'd1 : 'd0;
assign get_req_head = (cur_state == GET_CMD_s) ? {'d1, get_cmd_queue_index} : 'd0;

//-- get_resp_ready --
assign get_resp_ready = (cur_state == GET_RESP_s) ? 'd1 : 'd0;

//-- dequeue_req_valid --
//-- dequeue_req_head --
assign dequeue_req_valid = (cur_state == DEQUEUE_REQ_s) ? 'd1 : 'd0;
assign dequeue_req_head = (cur_state == DEQUEUE_REQ_s) ? {slot_num, queue_index} : 'd0;

//--dequeue_resp_ready --
assign dequeue_resp_ready = (cur_state == DEQUEUE_META_s) ? 'd1 : 
                            (cur_state == DEQUEUE_DATA_s) ? egress_ready : 'd0;

//-- reorder_buffer_wea --
//-- reorder_buffer_addra --
//-- reorder_buffer_dina --
assign reorder_buffer_wea = (cur_state == INIT_s) ? 'd1 : 
                            (cur_state == IDLE_s && st_resource_resp_valid) ? 'd1 :
                            (cur_state == DEQUEUE_REQ_s && dequeue_req_valid && !bypass_mode) ? 'd1 : 'd0;
assign reorder_buffer_addra =   (cur_state == INIT_s) ? tag_init_counter : 
                                (cur_state == IDLE_s && st_resource_resp_valid) ? st_resource_resp_head[`TAG_OFFSET] :
                                (cur_state == DEQUEUE_REQ_s && dequeue_req_valid) ? queue_head_tag : 'd0;
assign reorder_buffer_dina = (cur_state == INIT_s) ? 'd0 : 
                             (cur_state == IDLE_s && st_resource_resp_valid) ? {1'b1, st_resource_resp_data} :
                             (cur_state == DEQUEUE_REQ_s && dequeue_req_valid) ? 'd0 : 'd0;

//-- reorder_buffer_addrb --
assign reorder_buffer_addrb = (cur_state == GET_RESP_s && get_resp_valid) ? get_resp_data[`TAG_OFFSET] : 'd0;

//-- tag_fifo_wr_en --
//-- tag_fifo_din --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        tag_fifo_wr_en <= 'd0;
        tag_fifo_din <= 'd0;
    end
    else if (cur_state == INIT_s) begin
        tag_fifo_wr_en <= 'd1;
        tag_fifo_din <= tag_init_counter;
    end
    else if(cur_state == DEQUEUE_REQ_s && dequeue_req_valid && dequeue_req_ready && !bypass_mode) begin
        tag_fifo_wr_en <= 'd1;
        tag_fifo_din <= tag_mapping_addrb_diff;
    end
    else begin
        tag_fifo_wr_en <= 'd0;
        tag_fifo_din <= 'd0;
    end
end

//-- tag_mapping_addrb --
assign tag_mapping_addrb = (cur_state == IDLE_s && st_resource_resp_valid) ? st_resource_resp_head[`TAG_OFFSET] : tag_mapping_addrb_diff;

//-- tag_mapping_addrb_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        tag_mapping_addrb_diff <= 'd0;
    end
    else if(cur_state == IDLE_s && st_resource_resp_valid) begin
        tag_mapping_addrb_diff <= tag_mapping_addrb;
    end
    else begin
        tag_mapping_addrb_diff <= tag_mapping_addrb_diff;
    end
end

//-- egress_common_head --
assign egress_common_head = {'d0, queue_index};

//-- egress_valid --
//-- egress_head --
//-- egress_data --
//-- egress_start --
//-- egress_last --
assign egress_valid = (cur_state == DEQUEUE_DATA_s && dequeue_resp_valid) ? 'd1 : 'd0;
assign egress_head = (cur_state == DEQUEUE_DATA_s && start_flag) ? {resource_data, egress_common_head} : 'd0;
assign egress_data = (cur_state == DEQUEUE_DATA_s && dequeue_resp_valid) ? dequeue_resp_data : 'd0;
assign egress_start = (cur_state == DEQUEUE_DATA_s && dequeue_resp_valid && start_flag) ? 'd1 : 'd0;
assign egress_last = (cur_state == DEQUEUE_DATA_s && dequeue_resp_valid && dequeue_resp_last) ? 'd1 : 'd0; 

//-- bypass_mode --
always @(posedge clk or posedge rst) begin
	if (rst) begin
		bypass_mode <= 'd0;		
	end
	else if (cur_state == GET_RESP_s && get_resp_valid) begin
		bypass_mode <= get_resp_data[`MAX_OOO_SLOT_NUM_LOG + `MAX_REQ_TAG_NUM_LOG];
	end
	else begin
		bypass_mode <= bypass_mode;
	end
end
/*------------------------------------------- Variables Decode : End ------------------------------------------------*/


/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef     TAG_OFFSET
`undef     VALID_OFFSET
`undef     SLOT_NUM_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/
endmodule