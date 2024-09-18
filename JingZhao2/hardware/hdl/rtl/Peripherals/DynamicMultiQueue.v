/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       DynamicMultiQueue
Author:     YangFan
Function:   A buffer abstraction, dynamically allocates buffer space for various queues. 
            Provides 4 interfaces: Enqueue, Dequeue, Modify Head and Get Head.
            Total buffer space and queue number can be configured. 
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "common_function_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
//None
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module DynamicMultiQueue #(
    //Queue Buffer is comprised of numbers of slots, slot is the basic unit that DMQ operates on. Default SLOT_WIDTH is aligned with Data Bus Width.
    parameter       SLOT_WIDTH = 512,
    parameter       SLOT_NUM = 512,
    //Queue Buffer is shared by numbers of queues, each queue occupies contiguous or non-contiguous space in a True-Dual-Port SRAM.
    parameter       QUEUE_NUM = 32,
    parameter       SLOT_NUM_LOG = log2b(SLOT_NUM - 1),
    parameter       QUEUE_NUM_LOG = log2b(QUEUE_NUM - 1)
)(
    input   wire                                                    clk,
    input   wire                                                    rst,

//Queue state interface, indicates how many slots are available. Users should ensure that there are enough slots for the items to be stored.
    output  wire            [`MAX_OOO_SLOT_NUM_LOG : 0]                      ov_available_slot_num,

//Enqueue interface
//Head format:
//{slot number, queue index}
    input   wire                                                    i_enqueue_req_valid,
    input   wire            [`MAX_QP_NUM_LOG + `MAX_OOO_SLOT_NUM_LOG - 1 : 0]  iv_enqueue_req_head,
    input   wire            [SLOT_WIDTH - 1 : 0]                    iv_enqueue_req_data,
    input 	wire 													i_enqueue_req_start,
    input 	wire 													i_enqueue_req_last,
    output  wire                                                    o_enqueue_req_ready,

    input   wire                                                    i_empty_req_valid,
    input   wire            [`MAX_QP_NUM_LOG - 1 : 0]                 iv_empty_req_head,
    output  reg                                                     o_empty_req_ready,

    output  reg                                                     o_empty_resp_valid,
    output  reg             [`MAX_QP_NUM_LOG : 0]                     ov_empty_resp_head,
    input   wire                                                    i_empty_resp_ready,

//Dequeue interface
//Head format:
//{slot number, queue index}
    input   wire                                                    i_dequeue_req_valid,
    input   wire            [`MAX_QP_NUM_LOG + `MAX_OOO_SLOT_NUM_LOG - 1 : 0]  iv_dequeue_req_head,
    output  wire                                                    o_dequeue_req_ready,

    output  wire                                                    o_dequeue_resp_valid,
    output 	wire 			[`MAX_QP_NUM_LOG + `MAX_OOO_SLOT_NUM_LOG - 1 : 0] 	ov_dequeue_resp_head,
    output 	wire 													o_dequeue_resp_start,
    output 	wire 													o_dequeue_resp_last,
    input   wire                                                    i_dequeue_resp_ready,
    output  wire            [SLOT_WIDTH - 1 : 0]                    ov_dequeue_resp_data,

//Modify queue head interface
//Head format:
//{queue index}
    input   wire                                                    i_modify_head_req_valid,
    input   wire            [`MAX_QP_NUM_LOG - 1 : 0]                 iv_modify_head_req_head,
    input   wire            [SLOT_WIDTH - 1 : 0]                    iv_modify_head_req_data,
    output  wire                                                    o_modify_head_req_ready,

//Obtain queue head interface
//Head format:
//{queue index}
    input   wire                                                    i_get_req_valid,
    input   wire            [`MAX_QP_NUM_LOG + `MAX_OOO_SLOT_NUM_LOG - 1 : 0]  iv_get_req_head,
    output  wire                                                    o_get_req_ready,

    output  wire                                                    o_get_resp_valid,
    output 	wire 			[`MAX_QP_NUM_LOG + `MAX_OOO_SLOT_NUM_LOG - 1 : 0]	ov_get_resp_head,
    output 	wire 													o_get_resp_start,
    output 	wire 													o_get_resp_last,
    output  wire            [SLOT_WIDTH - 1 : 0]                    ov_get_resp_data,
    output  wire                                                    o_get_resp_empty,
    input   wire                                                    i_get_resp_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg     [`MAX_QP_NUM_LOG + `MAX_OOO_SLOT_NUM_LOG - 1 : 0]          qv_enqueue_req_head;
reg     [`MAX_QP_NUM_LOG + `MAX_OOO_SLOT_NUM_LOG - 1 : 0]          qv_empty_req_head;
reg     [`MAX_QP_NUM_LOG + `MAX_OOO_SLOT_NUM_LOG - 1 : 0]          qv_dequeue_req_head;

reg     [QUEUE_NUM_LOG - 1 : 0]                         qv_consumer_queue_index;

reg                                 head_table_wea;
reg     [QUEUE_NUM_LOG - 1 : 0]     head_table_addra;
reg     [SLOT_NUM_LOG : 0]          head_table_dina;
wire    [SLOT_NUM_LOG : 0]          head_table_douta;
reg                                 head_table_web;
reg     [QUEUE_NUM_LOG - 1 : 0]     head_table_addrb;
reg     [QUEUE_NUM_LOG - 1 : 0]     head_table_addrb_diff;
reg     [SLOT_NUM_LOG : 0]          head_table_dinb;
wire    [SLOT_NUM_LOG : 0]          head_table_doutb;

reg                                 tail_table_wea;
reg     [QUEUE_NUM_LOG - 1 : 0]     tail_table_addra;
reg     [SLOT_NUM_LOG - 1 : 0]      tail_table_dina;
wire    [SLOT_NUM_LOG - 1 : 0]      tail_table_douta;
reg                                 tail_table_web;
reg     [QUEUE_NUM_LOG - 1 : 0]     tail_table_addrb;
reg     [QUEUE_NUM_LOG - 1 : 0]     tail_table_addrb_diff;
reg     [SLOT_NUM_LOG - 1 : 0]      tail_table_dinb;
wire    [SLOT_NUM_LOG - 1 : 0]      tail_table_doutb;

reg                                 empty_table_wea;
reg     [QUEUE_NUM_LOG - 1 : 0]     empty_table_addra;
reg     [0 : 0]                     empty_table_dina;
wire    [0 : 0]                     empty_table_douta;
reg                                 empty_table_web;
reg     [QUEUE_NUM_LOG - 1 : 0]     empty_table_addrb;
reg     [QUEUE_NUM_LOG - 1 : 0]     empty_table_addrb_diff;
reg     [0 : 0]                     empty_table_dinb;
wire    [0 : 0]                     empty_table_doutb;

reg                                 content_table_wea;
reg     [SLOT_NUM_LOG - 1 : 0]      content_table_addra;
reg     [SLOT_WIDTH - 1 : 0]        content_table_dina;
wire    [SLOT_WIDTH - 1 : 0]        content_table_douta;
reg                                 content_table_web;
reg     [SLOT_NUM_LOG - 1 : 0]      content_table_addrb;
reg     [SLOT_NUM_LOG - 1 : 0]      content_table_addrb_diff;
reg     [SLOT_WIDTH - 1 : 0]        content_table_dinb;
wire    [SLOT_WIDTH - 1 : 0]        content_table_doutb;

reg                                 next_table_wea;
reg     [SLOT_NUM_LOG - 1 : 0]      next_table_addra;
reg     [SLOT_NUM_LOG - 1 : 0]      next_table_dina;
wire    [SLOT_NUM_LOG - 1 : 0]      next_table_douta;
reg                                 next_table_web;
reg     [SLOT_NUM_LOG - 1 : 0]      next_table_addrb;
reg     [SLOT_NUM_LOG - 1 : 0]      next_table_addrb_diff;
reg     [SLOT_NUM_LOG - 1 : 0]      next_table_dinb;
wire    [SLOT_NUM_LOG - 1 : 0]      next_table_doutb;

reg                                 free_wr_en;
reg     [SLOT_NUM_LOG - 1 : 0]      free_din;
wire                                free_prog_full;
reg                                 free_rd_en;
wire    [SLOT_NUM_LOG - 1 : 0]      free_dout;
wire                                free_empty;
wire    [SLOT_NUM_LOG : 0]          free_data_count;

reg     [QUEUE_NUM_LOG : 0]         metadata_init_counter;
wire                                metadata_init_finish;
reg     [SLOT_NUM_LOG : 0]          slot_init_counter;
wire                                slot_init_finish;

reg     [SLOT_NUM_LOG : 0]          qv_enqueue_left_num;
reg     [SLOT_NUM_LOG : 0]          qv_dequeue_left_num;

reg                                 q_dequeue_resp_valid;
reg     [SLOT_WIDTH - 1 : 0]        qv_dequeue_resp_data;
reg                                 q_get_resp_valid;
reg     [SLOT_WIDTH - 1 : 0]        qv_get_resp_data;
reg                                 q_get_resp_empty;

reg     [SLOT_WIDTH - 1 : 0]        qv_modify_head_data;

reg                                 q_dequeue_req_valid_diff;
reg                                 q_modify_head_req_valid_diff;
reg                                 q_get_req_valid_diff;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
//Head Table
SRAM_TDP_Template 
#(
    .RAM_WIDTH  (     SLOT_NUM_LOG    ),
    .RAM_DEPTH  (     QUEUE_NUM       )
)
MQ_HeadTable(
    .clk    (       clk                 ),
    .rst    (       rst                 ),

    .wea    (       head_table_wea      ),
    .addra  (       head_table_addra    ),
    .dina   (       head_table_dina     ),
    .douta  (       head_table_douta    ),             

    .web    (       head_table_web      ),
    .addrb  (       head_table_addrb    ),
    .dinb   (       head_table_dinb     ),
    .doutb  (       head_table_doutb    )     
);

//Tail Table
SRAM_TDP_Template 
#(
    .RAM_WIDTH  (     SLOT_NUM_LOG    ),
    .RAM_DEPTH  (     QUEUE_NUM       )
)
MQ_TailTable(
    .clk    (       clk                 ),
    .rst    (       rst                 ),

    .wea    (       tail_table_wea      ),
    .addra  (       tail_table_addra    ),
    .dina   (       tail_table_dina     ),
    .douta  (       tail_table_douta    ),             

    .web    (       tail_table_web      ),
    .addrb  (       tail_table_addrb    ),
    .dinb   (       tail_table_dinb     ),
    .doutb  (       tail_table_doutb    )   
);

//Empty Table
SRAM_TDP_Template 
#(
    .RAM_WIDTH  (     1               ),
    .RAM_DEPTH  (     QUEUE_NUM       )
)
MQ_EmptyTable(
    .clk    (       clk                 ),
    .rst    (       rst                 ),

    .wea    (       empty_table_wea      ),
    .addra  (       empty_table_addra    ),
    .dina   (       empty_table_dina     ),
    .douta  (       empty_table_douta    ),             

    .web    (       empty_table_web      ),
    .addrb  (       empty_table_addrb    ),
    .dinb   (       empty_table_dinb     ),
    .doutb  (       empty_table_doutb    )   
);

//Content Table
SRAM_TDP_Template 
#(
    .RAM_WIDTH  (     SLOT_WIDTH      ),
    .RAM_DEPTH  (     SLOT_NUM        )
)
MQ_ContentTable(
    .clk    (       clk                    ),
    .rst    (       rst                    ),

    .wea    (       content_table_wea      ),
    .addra  (       content_table_addra    ),
    .dina   (       content_table_dina     ),
    .douta  (       content_table_douta    ),             

    .web    (       content_table_web      ),
    .addrb  (       content_table_addrb    ),
    .dinb   (       content_table_dinb     ),
    .doutb  (       content_table_doutb    ) 
);

//Next Table
SRAM_TDP_Template 
#(
    .RAM_WIDTH  (     SLOT_NUM_LOG    ),
    .RAM_DEPTH  (     SLOT_NUM        )
)
MQ_NextTable(
    .clk    (       clk                    ),
    .rst    (       rst                    ),

    .wea    (       next_table_wea      ),
    .addra  (       next_table_addra    ),
    .dina   (       next_table_dina     ),
    .douta  (       next_table_douta    ),             

    .web    (       next_table_web      ),
    .addrb  (       next_table_addrb    ),
    .dinb   (       next_table_dinb     ),
    .doutb  (       next_table_doutb    ) 
);

//FreeList
SyncFIFO_Template
#(
    .FIFO_WIDTH (    SLOT_NUM_LOG        ),
    .FIFO_DEPTH (    SLOT_NUM            )
)
FreeListFIFO
(
    .clk        (       clk                     ),
    .rst        (       rst                     ),

    .wr_en      (       free_wr_en              ),
    .din        (       free_din                ),
    .prog_full  (       free_prog_full          ),
    .rd_en      (       free_rd_en              ),
    .dout       (       free_dout               ),
    .empty      (       free_empty              ),
    .data_count (       free_data_count         ) 
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
//Producer state machine
reg     [1:0]           Producer_cur_state;
reg     [1:0]           Producer_next_state;

parameter   PRODUCER_IDLE_s         = 2'd1,
            PRODUCER_ENQUEUE_s      = 2'd2,
            PRODUCER_EMPTY_s 		= 2'd3;
            
always @(posedge clk or posedge rst) begin
    if(rst) begin
        Producer_cur_state <= PRODUCER_IDLE_s;
    end
    else begin
        Producer_cur_state <= Producer_next_state;
    end
end

always @(*) begin
    case(Producer_cur_state)
        PRODUCER_IDLE_s:        if(metadata_init_finish && slot_init_finish) begin
                                    if(i_enqueue_req_valid) begin
                                        Producer_next_state = PRODUCER_ENQUEUE_s;
                                    end
                                    else if(i_empty_req_valid) begin
                                    	Producer_next_state = PRODUCER_EMPTY_s;
                                    end
                                    else begin
                                        Producer_next_state = PRODUCER_IDLE_s;
                                    end
                                end
                                else begin
                                    Producer_next_state = PRODUCER_IDLE_s;
                                end
        PRODUCER_ENQUEUE_s:     if(i_enqueue_req_valid && qv_enqueue_left_num == 1 && !free_empty) begin
                                    Producer_next_state = PRODUCER_IDLE_s;
                                end
                                else begin
                                    Producer_next_state = PRODUCER_ENQUEUE_s;
                                end
        PRODUCER_EMPTY_s:		if(o_empty_resp_valid && i_empty_resp_ready) begin
        							Producer_next_state = PRODUCER_IDLE_s;
        						end
        						else begin
        							Producer_next_state = PRODUCER_EMPTY_s;
        						end
        default:                Producer_next_state = PRODUCER_IDLE_s;
    endcase
end

//Consumer state machine
reg     [2:0]           Consumer_cur_state;
reg     [2:0]           Consumer_next_state;

parameter   CONSUMER_IDLE_s         = 3'd1,
            CONSUMER_PREPARE_s      = 3'd2,
            CONSUMER_DEQUEUE_s      = 3'd3,
            CONSUMER_MODIFY_HEAD_s  = 3'd4,
            CONSUMER_GET_s     = 3'd5;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        Consumer_cur_state <= CONSUMER_IDLE_s;
    end
    else begin
        Consumer_cur_state <= Consumer_next_state;
    end
end   

always @(*) begin
    case(Consumer_cur_state)
        CONSUMER_IDLE_s:        if(metadata_init_finish && slot_init_finish) begin
                                    if(i_dequeue_req_valid || i_modify_head_req_valid || i_get_req_valid) begin
                                        Consumer_next_state = CONSUMER_PREPARE_s;
                                    end        
                                    else begin
                                        Consumer_next_state = CONSUMER_IDLE_s;
                                    end
                                end
                                else begin
                                    Consumer_next_state = CONSUMER_IDLE_s;
                                end
        CONSUMER_PREPARE_s:     if(q_dequeue_req_valid_diff) begin
                                    Consumer_next_state = CONSUMER_DEQUEUE_s;
                                end
                                else if(q_modify_head_req_valid_diff) begin
                                    Consumer_next_state = CONSUMER_MODIFY_HEAD_s;
                                end
                                else if(q_get_req_valid_diff) begin
                                    Consumer_next_state = CONSUMER_GET_s;
                                end
                                else begin
                                    Consumer_next_state = CONSUMER_PREPARE_s;
                                end
        CONSUMER_DEQUEUE_s:     if(o_dequeue_resp_valid && i_dequeue_resp_ready && qv_dequeue_left_num == 'd1) begin
                                    Consumer_next_state = CONSUMER_IDLE_s;
                                end 
                                else begin
                                    Consumer_next_state = CONSUMER_DEQUEUE_s;
                                end
        CONSUMER_MODIFY_HEAD_s: Consumer_next_state = CONSUMER_IDLE_s;
        CONSUMER_GET_s:         if(i_get_resp_ready) begin
                                    Consumer_next_state = CONSUMER_IDLE_s;
                                end
                                else begin
                                    Consumer_next_state = CONSUMER_GET_s;
                                end
        default:                Consumer_next_state = CONSUMER_IDLE_s;
    endcase
end

/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- metadata_init_finish --
assign metadata_init_finish = (metadata_init_counter == QUEUE_NUM);

//-- o_enqueue_req_ready --
assign o_enqueue_req_ready = (Producer_cur_state == PRODUCER_ENQUEUE_s) && !free_empty;

//-- slot_init_finish --
assign slot_init_finish = (slot_init_counter == SLOT_NUM);

//-- ov_available-slot_num --
assign ov_available_slot_num = free_data_count;

//-- o_dequeue_resp_valid --
assign o_dequeue_resp_valid = q_dequeue_resp_valid;

//-- ov_dequeue_resp_data --
assign ov_dequeue_resp_data = qv_dequeue_resp_data;

//-- ov_dequeue_resp_head --
//-- o_dequeue_resp_start --
//-- o_dequeue_resp_last --
assign ov_dequeue_resp_head = (Consumer_cur_state == CONSUMER_DEQUEUE_s) ? qv_dequeue_req_head : 'd0;
assign o_dequeue_resp_start = (Consumer_cur_state == CONSUMER_DEQUEUE_s) ? (qv_dequeue_left_num == qv_dequeue_req_head[`MAX_OOO_SLOT_NUM_LOG + `MAX_QP_NUM_LOG - 1 : `MAX_QP_NUM_LOG]) : 'd0;
assign o_dequeue_resp_last = (Consumer_cur_state == CONSUMER_DEQUEUE_s) ? (qv_dequeue_left_num == 'd1) : 'd0;

//-- o_get_resp_valid --
assign o_get_resp_valid = q_get_resp_valid;

//-- ov_get_resp_data --
assign ov_get_resp_data = qv_get_resp_data;

//-- o_get_resp_empty --
assign o_get_resp_empty = q_get_resp_empty;

//-- ov_get_resp_head --
//-- o_get_resp_start --
//-- o_get_resp_last --
assign ov_get_resp_head = (Consumer_cur_state == CONSUMER_GET_s) ? iv_get_req_head : 'd0;
assign o_get_resp_start = (Consumer_cur_state == CONSUMER_GET_s) ? 'd1 : 'd0; 
assign o_get_resp_last = (Consumer_cur_state == CONSUMER_GET_s) ? 'd1 : 'd0; 

//-- o_dequeue_req_ready --
assign o_dequeue_req_ready = (Consumer_cur_state == CONSUMER_IDLE_s);

//-- o_modify_head_req_ready --
assign o_modify_head_req_ready = (Consumer_cur_state == CONSUMER_IDLE_s);

//-- o_get_req_ready --
assign o_get_req_ready = (Consumer_cur_state == CONSUMER_IDLE_s);

//-- q_dequeue_req_valid_diff --
//-- q_modify_head_req_valid_diff --
//-- q_get_req_valid_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_dequeue_req_valid_diff <= 'd0;
        q_modify_head_req_valid_diff <= 'd0;
        q_get_req_valid_diff <= 'd0;
    end
    else begin
        q_dequeue_req_valid_diff <= i_dequeue_req_valid;
        q_modify_head_req_valid_diff <= i_modify_head_req_valid;
        q_get_req_valid_diff <= i_get_req_valid;
    end
end

//-- meta_data_init_counter --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        metadata_init_counter <= 'd0;
    end
    else if(metadata_init_counter < QUEUE_NUM) begin
        metadata_init_counter <= metadata_init_counter + 'd1;
    end
    else begin
        metadata_init_counter <= metadata_init_counter;
    end
end

//-- slot_init_counter --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        slot_init_counter <= 'd0;
    end
    else if(slot_init_counter < SLOT_NUM) begin
        slot_init_counter <= slot_init_counter + 'd1;
    end
    else begin
        slot_init_counter <= slot_init_counter;
    end
end


//-- qv_enqueue_left_num --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_enqueue_left_num <= 'd0;
    end
    else if(Producer_cur_state == PRODUCER_IDLE_s && i_enqueue_req_valid) begin
        qv_enqueue_left_num <= iv_enqueue_req_head[`MAX_OOO_SLOT_NUM_LOG + `MAX_QP_NUM_LOG - 1 : `MAX_QP_NUM_LOG];
    end
    else if(Producer_cur_state == PRODUCER_ENQUEUE_s && i_enqueue_req_valid && o_enqueue_req_ready) begin
        qv_enqueue_left_num <= qv_enqueue_left_num - 'd1;
    end
    else begin
        qv_enqueue_left_num <= qv_enqueue_left_num;
    end
end

//-- qv_dequeue_left_num --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_dequeue_left_num <= 'd0;
    end
    else if(Consumer_cur_state == CONSUMER_IDLE_s && i_dequeue_req_valid) begin
        qv_dequeue_left_num <= iv_dequeue_req_head[`MAX_OOO_SLOT_NUM_LOG + `MAX_QP_NUM_LOG - 1 : `MAX_QP_NUM_LOG];
    end
    else if(Consumer_cur_state == CONSUMER_DEQUEUE_s && o_dequeue_resp_valid && i_dequeue_resp_ready) begin
        qv_dequeue_left_num <= qv_dequeue_left_num - 'd1;
    end
    else begin
        qv_dequeue_left_num <= qv_dequeue_left_num;
    end
end

//-- head_table_wea --
//-- head_table_addra --
//-- head_table_dina --
always @(*) begin
    if(!metadata_init_finish) begin
        head_table_wea = 'd1;
        head_table_addra = metadata_init_counter;
        head_table_dina = 'd0;        
    end
    else if(Producer_cur_state == PRODUCER_IDLE_s && i_enqueue_req_valid) begin
        head_table_wea = 'd0;
        head_table_addra = iv_enqueue_req_head[`MAX_QP_NUM_LOG - 1 : 0];
        head_table_dina = 'd0;                
    end
    else if(Producer_cur_state == PRODUCER_ENQUEUE_s && i_enqueue_req_valid && o_enqueue_req_ready) begin
        if(empty_table_douta) begin         //First enqueue, update head
            head_table_wea = 'd1;
            head_table_addra = qv_enqueue_req_head[`MAX_QP_NUM_LOG - 1 : 0];
            head_table_dina = free_dout;
        end
        else if(!empty_table_douta && (head_table_douta == tail_table_douta) && (Consumer_cur_state == CONSUMER_DEQUEUE_s) && (qv_enqueue_req_head[`MAX_QP_NUM_LOG - 1 : 0] == qv_dequeue_req_head[`MAX_QP_NUM_LOG - 1 : 0])
                && o_dequeue_resp_valid && i_dequeue_resp_ready) begin
            head_table_wea = 'd1;   //Last element is being dequeued, modify head
            head_table_addra = qv_enqueue_req_head[`MAX_QP_NUM_LOG - 1 : 0];
            head_table_dina = free_dout;
        end
        else begin
            head_table_wea = 'd0;
            head_table_addra = qv_enqueue_req_head[`MAX_QP_NUM_LOG - 1 : 0];
            head_table_dina = 'd0;
        end
    end
    else begin
        head_table_wea = 'd0;
        head_table_addra = qv_enqueue_req_head[`MAX_QP_NUM_LOG - 1 : 0];
        head_table_dina = 'd0;
    end
end

//-- head_table_web --
//-- head_table_addrb --
//-- head_table_dinb --
always @(*) begin
    if(Consumer_cur_state == CONSUMER_IDLE_s && i_dequeue_req_valid) begin
        head_table_web = 'd0;
        head_table_addrb = iv_dequeue_req_head[`MAX_QP_NUM_LOG - 1 : 0];
        head_table_dinb = 'd0;   
    end
    else if(Consumer_cur_state == CONSUMER_IDLE_s && i_modify_head_req_valid) begin
        head_table_web = 'd0;
        head_table_addrb = iv_modify_head_req_head[`MAX_QP_NUM_LOG - 1 : 0];
        head_table_dinb = 'd0;   
    end
    else if(Consumer_cur_state == CONSUMER_IDLE_s && i_get_req_valid) begin
        head_table_web = 'd0;
        head_table_addrb = iv_get_req_head[`MAX_QP_NUM_LOG - 1 : 0];
        head_table_dinb = 'd0;   
    end
    else if(Consumer_cur_state == CONSUMER_PREPARE_s) begin
        head_table_web = 'd0;
        head_table_addrb = qv_consumer_queue_index;
        head_table_dinb = 'd0;        
    end
    else if(Consumer_cur_state == CONSUMER_DEQUEUE_s && o_dequeue_resp_valid && i_dequeue_resp_ready) begin
        if(head_table_doutb == tail_table_doutb) begin  //Last element, no need to modify queue head
            head_table_web = 'd0;
            head_table_addrb = qv_consumer_queue_index;
            head_table_dinb = 'd0;           
        end
        else begin
            head_table_web = 'd1;
            head_table_addrb = qv_consumer_queue_index;
            head_table_dinb = next_table_doutb;
        end
    end
    else begin
        head_table_web = 'd0;
        head_table_addrb = qv_consumer_queue_index;
        head_table_dinb = 'd0;
    end
end

//-- tail_table_wea --
//-- tail_table_addra --
//-- tail_table_dina --
always @(*) begin
    if(!metadata_init_finish) begin
        tail_table_wea = 'd1;
        tail_table_addra = metadata_init_counter;
        tail_table_dina = 'd0;        
    end
    else if(Producer_cur_state == PRODUCER_IDLE_s && i_enqueue_req_valid) begin
        tail_table_wea = 'd0;
        tail_table_addra = iv_enqueue_req_head[`MAX_QP_NUM_LOG - 1 : 0];
        tail_table_dina = 'd0;       
    end
    else if(Producer_cur_state == PRODUCER_ENQUEUE_s && i_enqueue_req_valid && o_enqueue_req_ready) begin
        tail_table_wea = 'd1;
        tail_table_addra = qv_enqueue_req_head[`MAX_QP_NUM_LOG - 1 : 0];
        tail_table_dina = free_dout;
    end
    else begin
        tail_table_wea = 'd0;
        tail_table_addra = qv_enqueue_req_head[`MAX_QP_NUM_LOG - 1 : 0];
        tail_table_dina = 'd0;
    end
end

//-- tail_table_web --
//-- tail_table_addrb --
//-- tail_table_dinb --
always @(*) begin
    if(Consumer_cur_state == CONSUMER_IDLE_s && i_dequeue_req_valid) begin
        tail_table_web = 'd0;
        tail_table_addrb = iv_dequeue_req_head[`MAX_QP_NUM_LOG - 1 : 0];
        tail_table_dinb = 'd0;       
    end
    else if(Consumer_cur_state == CONSUMER_IDLE_s && i_modify_head_req_valid) begin
        tail_table_web = 'd0;
        tail_table_addrb = iv_modify_head_req_head[`MAX_QP_NUM_LOG - 1 : 0];
        tail_table_dinb = 'd0;       
    end
    else if(Consumer_cur_state == CONSUMER_IDLE_s && i_get_req_valid) begin
        tail_table_web = 'd0;
        tail_table_addrb = iv_get_req_head[`MAX_QP_NUM_LOG - 1 : 0];
        tail_table_dinb = 'd0;       
    end
    else if(Consumer_cur_state == CONSUMER_PREPARE_s) begin
        tail_table_web = 'd0;
        tail_table_addrb = qv_consumer_queue_index;
        tail_table_dinb = 'd0;         
    end
    else begin
        tail_table_web = 'd0;
        tail_table_addrb = qv_dequeue_req_head[`MAX_QP_NUM_LOG - 1 : 0];
        tail_table_dinb = 'd0;
    end
end

//-- empty_table_wea --
//-- empty_table_addra --
//-- empty_table_dina --
always @(*) begin
    if(!metadata_init_finish) begin
        empty_table_wea = 'd1;
        empty_table_addra = metadata_init_counter;
        empty_table_dina = 'd1;        
    end
    else if(Producer_cur_state == PRODUCER_IDLE_s && i_enqueue_req_valid) begin
        empty_table_wea = 'd0;
        empty_table_addra = iv_enqueue_req_head[`MAX_QP_NUM_LOG - 1 : 0];
        empty_table_dina = 'd0;            
    end
    else if(Producer_cur_state == PRODUCER_IDLE_s && i_empty_req_valid) begin
    	empty_table_wea = 'd0;
    	empty_table_addra = iv_empty_req_head[`MAX_QP_NUM_LOG - 1 : 0];
    	empty_table_dina = 'd0;
    end
    else if(Producer_cur_state == PRODUCER_ENQUEUE_s && i_enqueue_req_valid && o_enqueue_req_ready) begin
        if(empty_table_douta) begin
            empty_table_wea = 'd1;
            empty_table_addra = qv_enqueue_req_head[`MAX_QP_NUM_LOG - 1 : 0];
            empty_table_dina = 'd0;            
        end
        else if(!empty_table_douta && (head_table_douta == tail_table_douta) && (Consumer_cur_state == CONSUMER_DEQUEUE_s) && (qv_enqueue_req_head[`MAX_QP_NUM_LOG - 1 : 0] == qv_dequeue_req_head[`MAX_QP_NUM_LOG - 1 : 0])
            && o_dequeue_resp_valid && i_dequeue_resp_ready) begin
            empty_table_wea = 'd1;
            empty_table_addra = qv_enqueue_req_head[`MAX_QP_NUM_LOG - 1 : 0];
            empty_table_dina = 'd0;
        end
        else begin
            empty_table_wea = 'd0;
            empty_table_addra = qv_enqueue_req_head[`MAX_QP_NUM_LOG - 1 : 0];
            empty_table_dina = 'd0;        
        end
    end
    else if(Producer_cur_state == PRODUCER_EMPTY_s) begin
    	empty_table_wea = 'd0;
    	empty_table_addra = qv_empty_req_head[`MAX_QP_NUM_LOG - 1 : 0];
    	empty_table_dina = 'd0;    	
    end
    else begin
        empty_table_wea = 'd0;
        empty_table_addra = qv_enqueue_req_head[`MAX_QP_NUM_LOG - 1 : 0];
        empty_table_dina = 'd0;
    end
end

//-- empty_table_web --
//-- empty_table_addrb --
//-- empty_table_dinb --
always @(*) begin
    if(Consumer_cur_state == CONSUMER_IDLE_s && i_dequeue_req_valid) begin
        empty_table_web = 'd0;
        empty_table_addrb = iv_dequeue_req_head[`MAX_QP_NUM_LOG - 1 : 0];
        empty_table_dinb = 'd0;       
    end
    else if(Consumer_cur_state == CONSUMER_IDLE_s && i_modify_head_req_valid) begin
        empty_table_web = 'd0;
        empty_table_addrb = iv_modify_head_req_head[`MAX_QP_NUM_LOG - 1 : 0];
        empty_table_dinb = 'd0;       
    end
    else if(Consumer_cur_state == CONSUMER_IDLE_s && i_get_req_valid) begin
        empty_table_web = 'd0;
        empty_table_addrb = iv_get_req_head[`MAX_QP_NUM_LOG - 1 : 0];
        empty_table_dinb = 'd0;       
    end
    else if(Consumer_cur_state == CONSUMER_DEQUEUE_s && o_dequeue_resp_valid && i_dequeue_resp_ready && (head_table_doutb == tail_table_doutb)) begin    //Dequeue last elment
        if((Producer_cur_state != PRODUCER_ENQUEUE_s) || (qv_enqueue_req_head[`MAX_QP_NUM_LOG - 1 : 0] != qv_dequeue_req_head[`MAX_QP_NUM_LOG - 1 : 0])) begin //No concurrent enqueue
            empty_table_web = 'd1;
            empty_table_addrb = qv_consumer_queue_index;
            empty_table_dinb = 'd1;
        end
        else begin
            empty_table_web = 'd0;
            empty_table_addrb = qv_consumer_queue_index;
            empty_table_dinb = 'd0;
        end
    end
    else begin
        empty_table_web = 'd0;
        empty_table_addrb = qv_consumer_queue_index;
        empty_table_dinb = 'd0;
    end
end

//-- next_table_wea --
//-- next_table_addra --
//-- next_table_dina --
always @(*) begin
    if(!slot_init_finish) begin
        next_table_wea = 'd1;
        next_table_addra = slot_init_counter;
        next_table_dina = 'd0;        
    end
    else if(Producer_cur_state == PRODUCER_ENQUEUE_s && !empty_table_douta && i_enqueue_req_valid && o_enqueue_req_ready) begin
        //Only when table and available slot not empty should we update next pointer
        next_table_wea = 'd1;
        next_table_addra = tail_table_douta;
        next_table_dina = free_dout;
    end
    else begin
        next_table_wea = 'd0;
        next_table_addra = tail_table_douta;
        next_table_dina = 'd0;
    end
end

//-- next_table_web --
//-- next_table_addrb --
//-- next_table_dinb --
always @(*) begin
    if(Consumer_cur_state == CONSUMER_PREPARE_s) begin
        next_table_web = 'd0;
        next_table_addrb = head_table_doutb;
        next_table_dinb = 'd0;
    end
    else if(Consumer_cur_state == CONSUMER_DEQUEUE_s && o_dequeue_resp_valid && i_dequeue_resp_ready) begin
        next_table_web = 'd0;
        next_table_addrb = next_table_doutb;
        next_table_dinb = 'd0;
    end
    else begin
        next_table_web = 'd0;
        next_table_addrb = next_table_addrb_diff;
        next_table_dinb = 'd0;
    end
end

//-- content_table_wea --
//-- content_table_addra --
//-- content_table_dina --
always @(*) begin
    if(!slot_init_finish) begin
        content_table_wea = 'd1;
        content_table_addra = slot_init_counter;
        content_table_dina = 'd0;        
    end
    else if(Producer_cur_state == PRODUCER_ENQUEUE_s && i_enqueue_req_valid && o_enqueue_req_ready) begin
        content_table_wea = 'd1;
        content_table_addra = free_dout;
        content_table_dina = iv_enqueue_req_data;
    end
    else begin
        content_table_wea = 'd0;
        content_table_addra = 'd0;
        content_table_dina = 'd0;        
    end
end

//-- content_table_web --
//-- content_table_addrb --
//-- content_table_dinb --
always @(*) begin
    if(Consumer_cur_state == CONSUMER_PREPARE_s) begin
        content_table_web = 'd0;
        content_table_addrb = head_table_doutb;
        content_table_dinb = 'd0;        
    end
    else if(Consumer_cur_state == CONSUMER_DEQUEUE_s && i_dequeue_resp_ready && o_dequeue_resp_valid) begin
        content_table_web = 'd0;
        content_table_addrb = next_table_doutb;
        content_table_dinb = 'd0;
    end
    else if(Consumer_cur_state == CONSUMER_MODIFY_HEAD_s && !empty_table_doutb) begin
        content_table_web = 'd1;
        content_table_addrb = head_table_doutb;
        content_table_dinb = qv_modify_head_data;
    end
    else begin
        content_table_web = 'd0;
        content_table_addrb = content_table_addrb_diff;
        content_table_dinb = 'd0;        
    end
end

//-- free_wr_en --
//-- free_din --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        free_wr_en <= 'd0;
        free_din <= 'd0;
    end
    else if(!slot_init_finish) begin
        free_wr_en <= 'd1;
        free_din <= slot_init_counter;
    end
    else if(Consumer_cur_state == CONSUMER_DEQUEUE_s && i_dequeue_resp_ready && o_dequeue_resp_valid) begin
        free_wr_en <= 'd1;
        free_din <= head_table_doutb;
    end
    else begin
        free_wr_en <= 'd0;
        free_din <= 'd0;
    end
end

//-- free_rd_en --
always @(*) begin
    if(rst) begin
        free_rd_en = 'd0;
    end
    else if(Producer_cur_state == PRODUCER_ENQUEUE_s && i_enqueue_req_valid && o_enqueue_req_ready) begin
        free_rd_en = 'd1;
    end
    else begin
        free_rd_en = 'd0;
    end
end

//-- qv_enqueue_req_head --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_enqueue_req_head <= 'd0;
    end
    else if(Producer_cur_state == PRODUCER_IDLE_s && i_enqueue_req_valid) begin
        qv_enqueue_req_head <= iv_enqueue_req_head;
    end
    else begin
        qv_enqueue_req_head <= qv_enqueue_req_head;
    end
end

//-- qv_empty_req_head --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_empty_req_head <= 'd0;
    end
    else if(Producer_cur_state == PRODUCER_IDLE_s && i_empty_req_valid) begin
        qv_empty_req_head <= iv_empty_req_head;
    end
    else begin
        qv_empty_req_head <= qv_empty_req_head;
    end
end

//-- qv_modify_head_data --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_modify_head_data <= 'd0;
    end
    else if(Consumer_cur_state == CONSUMER_IDLE_s && i_modify_head_req_valid) begin
        qv_modify_head_data <= iv_modify_head_req_data;
    end
    else begin
        qv_modify_head_data <= qv_modify_head_data;
    end
end

//-- qv_dequeue_req_head --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_dequeue_req_head <= 'd0;        
    end
    else if (Consumer_cur_state == CONSUMER_IDLE_s && i_dequeue_req_valid) begin
        qv_dequeue_req_head <= iv_dequeue_req_head;
    end
    else begin
        qv_dequeue_req_head <= qv_dequeue_req_head;
    end
end

//-- qv_consumer_queue_index --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_consumer_queue_index <= 'd0;
    end
    else if(Consumer_cur_state == CONSUMER_IDLE_s && i_dequeue_req_valid) begin
        qv_consumer_queue_index <= iv_dequeue_req_head;
    end
    else if(Consumer_cur_state == CONSUMER_IDLE_s && i_modify_head_req_valid) begin
        qv_consumer_queue_index <= iv_modify_head_req_head;
    end
    else if(Consumer_cur_state == CONSUMER_IDLE_s && i_get_req_valid) begin
        qv_consumer_queue_index <= iv_get_req_head;
    end
    else begin
        qv_consumer_queue_index <= qv_consumer_queue_index;
    end
end

//-- q_dequeue_resp_valid --
//-- qv_dequeue_resp_data --
always @(*) begin
    if(rst) begin
        q_dequeue_resp_valid = 'd0;
        qv_dequeue_resp_data = 'd0;
    end 
    else if(Consumer_cur_state == CONSUMER_DEQUEUE_s) begin
        q_dequeue_resp_valid = 'd1;
        qv_dequeue_resp_data = content_table_doutb;
    end
    else begin
        q_dequeue_resp_valid = 'd0;
        qv_dequeue_resp_data = 'd0;        
    end
end

//-- q_get_resp_valid --
//-- qv_get_resp_data --
always @(*) begin
    if(rst) begin
        q_get_resp_valid = 'd0;
        qv_get_resp_data = 'd0;
        q_get_resp_empty = 'd1;
    end 
    else if(Consumer_cur_state == CONSUMER_GET_s) begin
        q_get_resp_valid = 'd1;
        qv_get_resp_data = content_table_doutb;
        q_get_resp_empty = empty_table_doutb;
    end
    else begin
        q_get_resp_valid = 'd0;
        qv_get_resp_data = 'd0;        
        q_get_resp_empty = 'd1;
    end
end

//-- o_empty_req_ready --
always @(*) begin
	if(rst) begin
		o_empty_req_ready = 'd0;
	end
	else if(Producer_cur_state == PRODUCER_IDLE_s) begin
		o_empty_req_ready = 'd1;
	end
	else begin
		o_empty_req_ready = 'd0;
	end
end

//-- o_empty_resp_valid --
//-- ov_empty_resp_head --
always @(*) begin
	if(rst) begin
		o_empty_resp_valid = 'd0;
		ov_empty_resp_head = 'd0;
	end
	else if(Producer_cur_state == PRODUCER_EMPTY_s) begin
		o_empty_resp_valid = 'd1;
		ov_empty_resp_head = {empty_table_douta, qv_empty_req_head[`MAX_QP_NUM_LOG - 1 : 0]};
	end
	else begin
		o_empty_resp_valid = 'd0;
		ov_empty_resp_head = 'd0;
	end
end


//-- next_table_addrb_diff --
//-- content_table_addrb_diff --
//-- empty_table_addrb_diff --
//-- tail_table_addrb_diff --
//-- head_table_addrb_diff --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        next_table_addrb_diff <= 'd0;
        content_table_addrb_diff <= 'd0; 
        empty_table_addrb_diff <= 'd0; 
        tail_table_addrb_diff <= 'd0; 
        head_table_addrb_diff <= 'd0;  
    end
    else begin
        next_table_addrb_diff <= next_table_addrb;
        content_table_addrb_diff <= content_table_addrb;
        empty_table_addrb_diff <= empty_table_addrb;
        tail_table_addrb_diff <= tail_table_addrb;
        head_table_addrb_diff <= head_table_addrb;
    end
end
/*------------------------------------------- Variables Decode : End ------------------------------------------------*/

endmodule