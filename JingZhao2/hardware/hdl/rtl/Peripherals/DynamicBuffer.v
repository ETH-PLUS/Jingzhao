/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       DynamicBuffer
Author:     YangFan
Function:   Store packet in a fine-grained granularity.
            Each packet is splitted into SLOT_WIDTH-sized flit, and each slot is allocated and recycled dynamically.
--------------------------------------------- Module Decription : End -----------------------------------------------*/


/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module DynamicBuffer #(
    //Queue Buffer is comprised of numbers of slots, slot is the basic unit that DB operates on. Default SLOT_WIDTH is aligned with Data Bus Width.
    parameter       SLOT_WIDTH = 512,
    parameter       SLOT_NUM = 512,
    parameter       SLOT_NUM_LOG = log2b(SLOT_NUM - 1),

    parameter       NULL_PTR = {(SLOT_NUM_LOG){1'b0}}
)(
    input   wire                                                    clk,
    input   wire                                                    rst,

//Queue state interface, indicates how many slots are available. Users should ensure that there are enough slots for the items to be stored.
    output  wire            [`MAX_DB_SLOT_NUM_LOG : 0]                      ov_available_slot_num,

//Insert Interface 
//Head format:
//{slot number}
    input   wire                                                    i_insert_req_valid,
    input   wire                                                    i_insert_req_start,
    input   wire                                                    i_insert_req_last,
    input   wire            [`MAX_DB_SLOT_NUM_LOG - 1 : 0]                  iv_insert_req_head,
    input   wire            [SLOT_WIDTH - 1 : 0]                    iv_insert_req_data,
    output  wire                                                    o_insert_req_ready,
//Return the address of each element
    output  wire                                                    o_insert_resp_valid,
    output  wire            [`MAX_DB_SLOT_NUM_LOG - 1 : 0]                  ov_insert_resp_data,    //Address of data inserted.

//Get Interface
//Head format:
//{slot number + addr}
    input   wire                                                    i_get_req_valid,
    input   wire            [`MAX_DB_SLOT_NUM_LOG * 2 - 1 : 0]              iv_get_req_head,
    output  wire                                                    o_get_req_ready,
    output  wire                                                    o_get_resp_valid,
    output  wire                                                    o_get_resp_start,
    output  wire                                                    o_get_resp_last,
    output  wire             [SLOT_WIDTH - 1 : 0]                   ov_get_resp_data,
    input   wire                                                    i_get_resp_ready,

//Delete Interface
//Head format:
//{slot number + addr}
    input   wire                                                    i_delete_req_valid,
    input   wire            [`MAX_DB_SLOT_NUM_LOG * 2 - 1 : 0]              iv_delete_req_head,
    output  wire                                                    o_delete_req_ready,
    
    output  wire                                                    o_delete_resp_valid,
    output  wire                                                    o_delete_resp_start,
    output  wire                                                    o_delete_resp_last,
    output  wire            [SLOT_WIDTH - 1 : 0]                    ov_delete_resp_data,
    input   wire                                                    i_delete_resp_ready

);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg     [31:0]                                  qv_get_count;
reg     [31:0]                                  qv_get_total;
reg     [31:0]                                  qv_delete_count;
reg     [31:0]                                  qv_delete_total;

reg                                             first_delete;

reg                                             content_table_wea;
reg     [SLOT_NUM_LOG - 1 : 0]                  content_table_addra;
reg     [SLOT_WIDTH - 1 : 0]                    content_table_dina;
wire    [SLOT_WIDTH - 1 : 0]                    content_table_douta;
reg                                             content_table_web;
reg     [SLOT_NUM_LOG - 1 : 0]                  content_table_addrb;
reg     [SLOT_NUM_LOG - 1 : 0]                  content_table_addrb_diff;
reg     [SLOT_WIDTH - 1 : 0]                    content_table_dinb;
wire    [SLOT_WIDTH - 1 : 0]                    content_table_doutb;

reg     [SLOT_NUM_LOG - 1 : 0]                  qv_content_table_addrb_prev;
reg     [SLOT_NUM_LOG - 1 : 0]                  qv_content_table_addra_prev;

reg                                             next_table_wea;
reg     [SLOT_NUM_LOG - 1 : 0]                  next_table_addra;
reg     [SLOT_NUM_LOG - 1 : 0]                  next_table_dina;
wire    [SLOT_NUM_LOG - 1 : 0]                  next_table_douta;
reg                                             next_table_web;
reg     [SLOT_NUM_LOG - 1 : 0]                  next_table_addrb;
reg     [SLOT_NUM_LOG - 1 : 0]                  next_table_addrb_diff;
reg     [SLOT_NUM_LOG - 1 : 0]                  next_table_dinb;
wire    [SLOT_NUM_LOG - 1 : 0]                  next_table_doutb;

reg                                             free_wr_en;
reg     [SLOT_NUM_LOG - 1 : 0]                  free_din;
wire                                            free_prog_full;
reg                                             free_rd_en;
wire    [SLOT_NUM_LOG - 1 : 0]                  free_dout;
wire                                            free_empty;
wire    [SLOT_NUM_LOG : 0]                      free_data_count;

reg     [SLOT_NUM_LOG : 0]                      init_counter;
wire                                            init_finish;

reg                                             q_first_flit;

reg     [SLOT_NUM_LOG - 1 : 0]                  qv_last_insert_addr;

/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
SRAM_TDP_Template 
#(
    .RAM_WIDTH  (     SLOT_WIDTH      ),
    .RAM_DEPTH  (     SLOT_NUM        )
)
DB_ContentTable(
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
DB_NextTable(
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
reg             [1:0]                   producer_cur_state;
reg             [1:0]                   producer_next_state;
    
parameter       [1:0]                   PRODUCER_INIT_s = 'd0,
                                        PRODUCER_IDLE_s = 'd1,
                                        PRODUCER_INSERT_s = 'd2;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        producer_cur_state <= PRODUCER_INIT_s;
    end
    else begin
        producer_cur_state <= producer_next_state;
    end
end

always @(*) begin
    case(producer_cur_state)
        PRODUCER_INIT_s:    if(init_finish) begin
                                producer_next_state = PRODUCER_IDLE_s;
                            end
                            else begin
                                producer_next_state = PRODUCER_INIT_s;
                            end
        PRODUCER_IDLE_s:    if(i_insert_req_valid) begin
                                producer_next_state = PRODUCER_INSERT_s;
                            end
                            else begin
                                producer_next_state = PRODUCER_IDLE_s;
                            end
        PRODUCER_INSERT_s:  if(i_insert_req_valid && i_insert_req_last && o_insert_req_ready) begin
                                producer_next_state = PRODUCER_IDLE_s;
                            end          
                            else begin
                                producer_next_state = PRODUCER_INSERT_s;
                            end
        default:            producer_next_state = PRODUCER_IDLE_s;
    endcase
end

//Consumer state machine
reg             [2:0]                   consumer_cur_state;
reg             [2:0]                   consumer_next_state;
    
parameter       [2:0]                   CONSUMER_IDLE_s = 3'd1,
                                        CONSUMER_GET_s = 3'd2,
                                        CONSUMER_NULL_s = 3'd3,
                                        CONSUMER_DELETE_s = 3'd4; 

always @(posedge clk or posedge rst) begin
    if(rst) begin
        consumer_cur_state <= CONSUMER_IDLE_s;
    end
    else begin
        consumer_cur_state <= consumer_next_state;
    end
end

always @(*) begin
    case(consumer_cur_state)
        CONSUMER_IDLE_s:            if(i_get_req_valid) begin
                                        consumer_next_state = CONSUMER_GET_s;
                                    end
                                    else if(i_delete_req_valid) begin
                                        if(iv_delete_req_head == 0) begin
                                            consumer_next_state = CONSUMER_NULL_s;
                                        end
                                        else begin
                                            consumer_next_state = CONSUMER_DELETE_s;
                                        end
                                    end
                                    else begin
                                        consumer_next_state = CONSUMER_IDLE_s;
                                    end
        CONSUMER_GET_s:             if(qv_get_count == 1 && i_get_resp_ready) begin
                                        consumer_next_state = CONSUMER_IDLE_s;
                                    end
                                    else begin
                                        consumer_next_state = CONSUMER_GET_s;
                                    end
        CONSUMER_NULL_s:            consumer_next_state = CONSUMER_IDLE_s;
        CONSUMER_DELETE_s:          if(qv_delete_count == 1 && i_delete_resp_ready) begin
                                        consumer_next_state = CONSUMER_IDLE_s;
                                    end
                                    else begin
                                        consumer_next_state = CONSUMER_DELETE_s;
                                    end
        default:                    consumer_next_state = CONSUMER_IDLE_s;
    endcase
end

/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- init_finish --
assign init_finish = (init_counter == SLOT_NUM);

//-- init_counter --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        init_counter <= 'd0;
    end
    else if(init_counter < SLOT_NUM) begin
        init_counter <= init_counter + 'd1;
    end
    else begin
        init_counter <= init_counter;
    end
end

//-- q_first_flit --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_first_flit <= 'd0;
    end
    else if(producer_cur_state == PRODUCER_IDLE_s && i_insert_req_valid) begin
        q_first_flit <= 'd1;
    end
    else if(producer_cur_state == PRODUCER_INSERT_s && q_first_flit) begin
        q_first_flit <= 'd0;
    end
    else begin
        q_first_flit <= q_first_flit;
    end
end

//-- qv_last_insert_addr --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_last_insert_addr <= 'd0;
    end
    else if(producer_cur_state == PRODUCER_INSERT_s && i_insert_req_valid && o_insert_req_ready) begin
        qv_last_insert_addr <= free_dout;
    end
    else begin
        qv_last_insert_addr <= qv_last_insert_addr;
    end
end

//-- qv_get_count --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_get_count <= 'd0;
    end
    else if(consumer_cur_state == CONSUMER_IDLE_s) begin
        qv_get_count <= i_get_req_valid ? iv_get_req_head[`MAX_DB_SLOT_NUM_LOG * 2 - 1 : `MAX_DB_SLOT_NUM_LOG] : 'd0;
    end
    else if(consumer_cur_state == CONSUMER_GET_s && i_get_resp_ready) begin
        qv_get_count <= qv_get_count - 'd1;
    end
    else begin
        qv_get_count <= qv_get_count;
    end
end 

//-- qv_get_total --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_get_total <= 'd0;
    end
    else if(consumer_cur_state == CONSUMER_IDLE_s) begin
        qv_get_total <= i_get_req_valid ? iv_get_req_head[`MAX_DB_SLOT_NUM_LOG * 2 - 1 : `MAX_DB_SLOT_NUM_LOG] : 'd0;
    end
    else begin
        qv_get_total <= qv_get_total;
    end
end 

//-- qv_delete_count --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_delete_count <= 'd0;
    end
    else if(consumer_cur_state == CONSUMER_IDLE_s) begin
        qv_delete_count <= i_delete_req_valid ? iv_delete_req_head[`MAX_DB_SLOT_NUM_LOG * 2 - 1 : `MAX_DB_SLOT_NUM_LOG] : 'd0;
    end
    else if(consumer_cur_state == CONSUMER_DELETE_s && i_delete_resp_ready) begin
        qv_delete_count <= qv_delete_count - 'd1;
    end
    else begin
        qv_delete_count <= qv_delete_count;
    end
end 

//-- qv_delete_total --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_delete_total <= 'd0;
    end
    else if(consumer_cur_state == CONSUMER_IDLE_s) begin
        qv_delete_total <= i_delete_req_valid ? iv_delete_req_head[`MAX_DB_SLOT_NUM_LOG * 2 - 1 : `MAX_DB_SLOT_NUM_LOG] : 'd0;
    end
    else begin
        qv_delete_total <= qv_delete_total;
    end
end 

//-- free_wr_en --
//-- free_din --
always @(*) begin
    if(rst) begin
        free_wr_en = 'd0;
        free_din = 'd0;
    end
    else if(!init_finish && init_counter != 0) begin   //Address 0 is unused
        free_wr_en = 'd1;
        free_din = init_counter;
    end
    else if(consumer_cur_state == CONSUMER_DELETE_s && o_delete_resp_valid && i_delete_resp_ready) begin
        free_wr_en = 'd1;
        free_din = qv_content_table_addrb_prev;
    end
    else begin
        free_wr_en = 'd0;
        free_din = 'd0;
    end
end

//-- free_rd_en --
always @(*) begin
    if(rst) begin
        free_rd_en = 'd0;
    end
    else if(producer_cur_state == PRODUCER_INSERT_s && i_insert_req_valid && o_insert_req_ready) begin
        free_rd_en = 'd1;
    end
    else begin
        free_rd_en = 'd0;
    end
end

//-- content_table_wea --
//-- content_table_addra --
//-- content_table_dina --
always @(*) begin
    if(rst) begin
        content_table_wea = 'd0;
        content_table_addra = 'd0;
        content_table_dina = 'd0;
    end
    else if(producer_cur_state == PRODUCER_INSERT_s && i_insert_req_valid && o_insert_req_ready) begin
        content_table_wea = 'd1;
        content_table_addra = free_dout;
        content_table_dina = iv_insert_req_data;        
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
    if(rst) begin
        content_table_web = 'd0;
        content_table_addrb = 'd0;
        content_table_dinb = 'd0;
    end
    else if((consumer_cur_state == CONSUMER_IDLE_s) && i_get_req_valid) begin
        content_table_web = 'd0;
        content_table_addrb = iv_get_req_head[SLOT_NUM_LOG - 1 : 0];
        content_table_dinb = 'd0;        
    end
    else if((consumer_cur_state == CONSUMER_IDLE_s) && i_delete_req_valid) begin
        content_table_web = 'd0;
        content_table_addrb = iv_delete_req_head[SLOT_NUM_LOG - 1 : 0];
        content_table_dinb = 'd0;        
    end
    else if((consumer_cur_state == CONSUMER_GET_s && i_get_resp_ready) || (consumer_cur_state == CONSUMER_DELETE_s && i_delete_resp_ready)) begin
        content_table_web = 'd0;
        content_table_addrb = next_table_doutb;
        content_table_dinb = 'd0;
    end
    else begin
        content_table_web = 'd0;
        content_table_addrb = content_table_addrb_diff;
        content_table_dinb = 'd0;
    end
end

//-- content_table_addrb_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        content_table_addrb_diff <= 'd0;
    end
    else begin
        content_table_addrb_diff <= content_table_addrb;
    end
end

//-- next_table_wea --
//-- next_table_addra --
//-- next_table_dina --
always @(*) begin
    if(rst) begin
        next_table_wea = 'd0;
        next_table_addra = 'd0;
        next_table_dina = 'd0;
    end
    else if(producer_cur_state == PRODUCER_IDLE_s) begin
        next_table_wea = 'd0;
        next_table_addra = 'd0;
        next_table_dina = 'd0;
    end
    else if(producer_cur_state == PRODUCER_INSERT_s && i_insert_req_valid && o_insert_req_ready) begin
        if(q_first_flit) begin      //First-time insert, no need to modify next and prev
            next_table_wea = 'd0;
            next_table_addra = 'd0;
            next_table_dina = 'd0;  
        end
        else begin
            next_table_wea = 'd1;
            next_table_addra = qv_last_insert_addr;
            next_table_dina = free_dout;              
        end
    end
    else begin
        next_table_wea = 'd0;
        next_table_addra = 'd0;
        next_table_dina = 'd0;
    end
end

//-- next_table_web --
//-- next_table_addrb --
//-- next_table_dinb --
always @(*) begin
    if(rst) begin
        next_table_web = 'd0;
        next_table_addrb = 'd0;
        next_table_dinb = 'd0;
    end
    else if(consumer_cur_state == CONSUMER_IDLE_s && i_delete_req_valid) begin
        next_table_web = 'd0;
        next_table_addrb = iv_delete_req_head[SLOT_NUM_LOG - 1 : 0];
        next_table_dinb = 'd0;        
    end
    else if(consumer_cur_state == CONSUMER_IDLE_s && i_get_req_valid) begin
        next_table_web = 'd0;
        next_table_addrb = iv_get_req_head[SLOT_NUM_LOG - 1 : 0];
        next_table_dinb = 'd0;           
    end
    else if((consumer_cur_state == CONSUMER_GET_s && i_get_resp_ready) || (consumer_cur_state == CONSUMER_DELETE_s && i_delete_resp_ready))begin
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

//-- next_table_addrb_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        next_table_addrb_diff <= 'd0;
    end
    else begin
        next_table_addrb_diff <= next_table_addrb;
    end
end

//-- first_delete --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        first_delete <= 'd0;
    end
    else if(consumer_cur_state == CONSUMER_IDLE_s && i_delete_req_valid) begin
        first_delete <= 'd1;
    end
    else if(consumer_cur_state == CONSUMER_DELETE_s && o_delete_resp_valid && i_delete_resp_ready) begin
        first_delete <= 'd0;
    end
    else begin
        first_delete <= first_delete;
    end
end

//-- qv_content_table_addra_prev --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_content_table_addra_prev <= 'd0;
    end
    else if(content_table_wea) begin
        qv_content_table_addra_prev <= content_table_addra;
    end
    else begin
        qv_content_table_addra_prev <= qv_content_table_addra_prev;
    end
end

//-- qv_content_table_addrb_prev --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_content_table_addrb_prev <= 'd0;
    end
    else if((consumer_cur_state == CONSUMER_IDLE_s) && i_delete_req_valid) begin
        qv_content_table_addrb_prev <= iv_delete_req_head[SLOT_NUM_LOG - 1 : 0];        
    end
    else if(o_delete_resp_valid && i_delete_resp_ready) begin
        qv_content_table_addrb_prev <= content_table_addrb;
    end
    else begin
        qv_content_table_addrb_prev <= qv_content_table_addrb_prev;
    end
end

//-- ov_available_slot_num
assign ov_available_slot_num = free_data_count;

//-- o_insert_req_ready --
assign o_insert_req_ready = (producer_cur_state == PRODUCER_INSERT_s);

//-- o_insert_resp_valid --
assign o_insert_resp_valid = (producer_cur_state == PRODUCER_INSERT_s && i_insert_req_valid);

//-- ov_insert_resp_data --
assign ov_insert_resp_data = (producer_cur_state == PRODUCER_INSERT_s && o_insert_resp_valid) ? content_table_addra : 'd0;

//-- o_get_req_ready --
assign o_get_req_ready = (consumer_cur_state == CONSUMER_IDLE_s);

//-- o_get_resp_valid --
assign o_get_resp_valid = (consumer_cur_state == CONSUMER_GET_s);

//-- o_get_resp_start --
assign o_get_resp_start = (consumer_cur_state == CONSUMER_GET_s) && (qv_get_total == qv_get_count);

//-- o_get_resp_last --
assign o_get_resp_last = (consumer_cur_state == CONSUMER_GET_s) && (qv_get_count == 'd1);

//-- ov_get_resp_data --
assign ov_get_resp_data = (consumer_cur_state == CONSUMER_GET_s) ? content_table_doutb : 'd0;

//-- o_delete_req_ready --
assign o_delete_req_ready = (consumer_cur_state == CONSUMER_IDLE_s);

//-- o_delete_resp_valid --
assign o_delete_resp_valid = (consumer_cur_state == CONSUMER_DELETE_s) || (consumer_cur_state == CONSUMER_NULL_s);

//-- o_delete_resp_start --
assign o_delete_resp_start = ((consumer_cur_state == CONSUMER_DELETE_s) && (qv_delete_total == qv_delete_count)) || (consumer_cur_state == CONSUMER_NULL_s);

//-- o_delete_resp_last --
assign o_delete_resp_last = ((consumer_cur_state == CONSUMER_DELETE_s) && (qv_delete_count == 'd1)) || (consumer_cur_state == CONSUMER_NULL_s);

//-- ov_delete_resp_data --
assign ov_delete_resp_data = (consumer_cur_state == CONSUMER_DELETE_s) ? content_table_doutb : 'd0;

/*------------------------------------------- Variables Decode : End ------------------------------------------------*/
endmodule