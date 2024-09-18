/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       PacketBufferMgt
Author:     YangFan
Function:   Manage packet buffer.
            For reliable transfer, there are several choices to reload lost packet:
            1.Reload packet from on-nic memory;
            2.Reload packet from host memory based on each packet's DMA address;
            3.Reload WQE from host memory and re-execute this WQE.
            Our design is aimed at improving loss recovery efficiency, hence we choose to buffer packet on-nic.

            For reliable receive, there are also several choices to deal with out-of-ordered packet:
            1.Buffer these packet and commit them to the ULP in-order;
            2.No buffering and directly commit them to the ULP out-of-order.
            IB specification points out that the application should not depend on the order that the packets arrived, indicating that
            we could upload the received packet orderless, which saves on-nic memory and computing resources.
            However, we still choose to buffer the packet, for 2 reasons:
            1.There exists several applications sensitive to the packet order;
            2.For short message(only one packet), message order is still strongly required
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "ib_constant_def_h.vh"
`include "common_function_def.vh"
`include "transport_subsystem_def.vh"
`include "global_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

`define     GET_PKT                         1
`define     DELETE_PKT                      2
`define     FIND_PKT                        3
`define     NULL                            0

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module PacketBufferMgt #(
    parameter       SLOT_WIDTH = 512,
    parameter       SLOT_NUM = 512,
    parameter       SLOT_NUM_LOG = log2b(SLOT_NUM - 1)
)(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Enqueue Packet
    output  wire    [SLOT_NUM_LOG - 1 : 0]                                  ov_available_slot_num,
    input   wire                                                            i_insert_req_valid,
    input   wire    [`PKT_HEAD_WIDTH - 1 : 0]                               iv_insert_req_head,     //{SlotNum, PSN, QPN}
    input   wire    [`PKT_DATA_WIDTH - 1 : 0]                               iv_insert_req_data,
    input   wire                                                            i_insert_req_start,
    input   wire                                                            i_insert_req_last,
    output  wire                                                            o_insert_req_ready,

//Delete Packet
    input   wire                                                            i_delete_req_valid,
    input   wire    [`QP_NUM_LOG + `PSN_WIDTH + SLOT_NUM - 1 : 0]           iv_delete_req_head,
    output  wire                                                            o_delete_req_ready,

    output  wire                                                            o_delete_resp_valid,
    output  wire     [`PKT_HEAD_WIDTH - 1 : 0]                              ov_delete_resp_head,
    output  wire     [`PKT_DATA_WIDTH - 1 : 0]                              ov_delete_resp_data,
    output  wire                                                            o_delete_resp_start,
    output  wire                                                            o_delete_resp_last,
    input   wire                                                            i_delete_resp_ready,

//Find a packet, interfaced with producer.
    input   wire                                                            i_find_req_valid_A,
    input   wire    [`QP_NUM_LOG + `PSN_WIDTH - 1 : 0]                      iv_find_req_head_A,
    output  wire                                                            o_find_resp_valid_A,
    output  wire    [`PKT_SLOT_NUM_LOG + SLOT_NUM_LOG : 0]                  ov_find_resp_data_A,

//Find a packet, interfaced with consumer.
    input   wire                                                            i_find_req_valid_B,
    input   wire    [`QP_NUM_LOG + `PSN_WIDTH - 1 : 0]                      iv_find_req_head_B,
    output  wire                                                            o_find_resp_valid_B,
    output  wire    [`PKT_SLOT_NUM_LOG + SLOT_NUM_LOG : 0]                  ov_find_resp_data_B,

//Get a Packet
    input   wire                                                            i_get_req_valid,
    input   wire    [`QP_NUM_LOG + `PSN_WIDTH + SLOT_NUM - 1 : 0]           iv_get_req_head,

    output  wire                                                            o_get_resp_valid,
    output  wire     [`PKT_HEAD_WIDTH - 1 : 0]                              ov_get_resp_head,
    output  wire     [`PKT_DATA_WIDTH - 1 : 0]                              ov_get_resp_data,
    output  wire                                                            o_get_resp_start,
    output  wire                                                            o_get_resp_last,
    input   wire                                                            i_get_resp_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg     [31:0]                                          qv_get_resp_count;
reg     [31:0]                                          qv_delete_resp_count;
reg     [31:0]                                          qv_insert_resp_count;


reg                                                     q_alloc_valid;
reg     [`QP_NUM_LOG + `PSN_WIDTH - 1 : 0]              qv_alloc_index;
reg     [`PKT_SLOT_NUM_LOG + SLOT_NUM_LOG - 1 : 0]      qv_alloc_data;  //+8 to store pkt-occupied slot num
wire                                                    w_alloc_ready;

reg                                                     q_find_req_valid;
reg     [`QP_NUM_LOG + `PSN_WIDTH - 1 : 0]              qv_find_req_index;
wire                                                    w_find_resp_valid;
wire    [`PKT_SLOT_NUM_LOG + SLOT_NUM_LOG - 1 : 0]      wv_find_resp_data;

reg                                                     q_recycle_req_valid;
reg     [`QP_NUM_LOG + `PSN_WIDTH - 1 : 0]              qv_recycle_req_index;
wire                                                    w_recycle_req_ready;
wire                                                    w_recycle_resp_valid;
wire    [`QP_NUM_LOG + `PSN_WIDTH - 1 : 0]              wv_recycle_resp_data;

reg                                                     q_insert_req_valid;
reg                                                     q_insert_req_start;
reg                                                     q_insert_req_last;
reg     [SLOT_NUM_LOG - 1 : 0]                          qv_insert_req_head;
reg     [SLOT_WIDTH - 1 : 0]                            qv_insert_req_data;
wire                                                    w_insert_req_ready;
wire                                                    w_insert_resp_valid;
wire    [SLOT_NUM_LOG - 1 : 0]                          wv_insert_resp_data;

reg                                                     q_get_req_valid;
reg     [SLOT_NUM_LOG * 2 - 1 : 0]                      qv_get_req_head;
wire                                                    w_get_req_ready;
wire                                                    w_get_resp_valid;
wire                                                    w_get_resp_last;
wire    [`PKT_SLOT_NUM_LOG + SLOT_WIDTH - 1 : 0]        wv_get_resp_data;
reg                                                     q_get_resp_ready;
reg     [`PKT_HEAD_WIDTH - 1 : 0]                       qv_get_resp_head;

reg                                                     q_delete_req_valid;
reg     [SLOT_NUM_LOG * 2 - 1 : 0]                      qv_delete_req_head;
wire                                                    w_delete_req_ready;
wire                                                    w_delete_resp_valid;
wire                                                    w_delete_resp_start;
wire                                                    w_delete_resp_last;
wire    [SLOT_WIDTH - 1 : 0]                            wv_delete_resp_data;
reg                                                     q_delete_resp_ready;
reg     [`PKT_HEAD_WIDTH - 1 : 0]                       qv_delete_resp_head;

reg                                                     i_get_req_valid_diff;
reg     [`QP_NUM_LOG + `PSN_WIDTH + SLOT_NUM - 1 : 0]   iv_get_req_head_diff;

reg                                                     i_delete_req_valid_diff;
reg     [`QP_NUM_LOG + `PSN_WIDTH + SLOT_NUM - 1 : 0]   iv_delete_req_head_diff;

/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
TransportHashTable 
#(
    .SLOT_WIDTH(SLOT_NUM_LOG)
)
PacketRecordTable(
    .clk(clk),
    .rst(rst),

    .i_alloc_valid(q_alloc_valid),
    .iv_alloc_index(qv_alloc_index),
    .iv_alloc_data(qv_alloc_data),
    .o_alloc_ready(w_alloc_ready),

    .i_find_req_valid_A(i_find_req_valid_A),
    .iv_find_req_index_A(iv_find_req_head_A),
    .o_find_resp_valid_A(o_find_resp_valid_A),
    .ov_find_resp_data_A(ov_find_resp_data_A),

    .i_find_req_valid_B(i_find_req_valid_B ? 'd1 : q_find_req_valid),
    .iv_find_req_index_B(i_find_req_valid_B ? iv_find_req_head_B : qv_find_req_index),
    .o_find_resp_valid_B(w_find_resp_valid),
    .ov_find_resp_data_B(wv_find_resp_data),

    .i_recycle_req_valid(q_recycle_req_valid),
    .iv_recycle_req_index(qv_recycle_req_index),
    .o_recycle_req_ready(w_recycle_req_ready),
    .o_recyle_resp_valid(w_recycle_resp_valid),
    .ov_recycle_resp_data(wv_recycle_resp_data)
);

DynamicBuffer 
#(
    .SLOT_WIDTH(`PKT_DATA_WIDTH),
    .SLOT_NUM(SLOT_NUM)
)
PacketBuffer(
    .clk(clk),
    .rst(rst),

    .ov_available_slot_num(ov_available_slot_num),

    .i_insert_req_valid(q_insert_req_valid),
    .i_insert_req_start(q_insert_req_start),
    .i_insert_req_last(q_insert_req_last),
    .iv_insert_req_head(qv_insert_req_head),
    .iv_insert_req_data(qv_insert_req_data),
    .o_insert_req_ready(w_insert_req_ready),
    .o_insert_resp_valid(w_insert_resp_valid),
    .ov_insert_resp_data(wv_insert_resp_data),

    .i_get_req_valid(q_get_req_valid),
    .iv_get_req_head(qv_get_req_head),
    .o_get_req_ready(w_get_req_ready),
    .o_get_resp_valid(w_get_resp_valid),
    .o_get_resp_start(w_get_resp_start),
    .o_get_resp_last(w_get_resp_last),
    .ov_get_resp_data(wv_get_resp_data),
    .i_get_resp_ready(q_get_resp_ready),

    .i_delete_req_valid(q_delete_req_valid),
    .iv_delete_req_head(qv_delete_req_head),

    .o_delete_req_ready(w_delete_req_ready),
    .o_delete_resp_valid(w_delete_resp_valid),
    .o_delete_resp_start(w_delete_resp_start),
    .o_delete_resp_last(w_delete_resp_last),
    .ov_delete_resp_data(wv_delete_resp_data),
    .i_delete_resp_ready(q_delete_resp_ready)
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/

/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- q_insert_req_valid --
//-- q_insert_req_start --
//-- q_insert_req_last --
//-- qv_insert_req_head --
//-- qv_insert_req_data --
always @(*) begin
    if(rst) begin
        q_insert_req_valid = 'd0;
        q_insert_req_start = 'd0; 
        q_insert_req_last  = 'd0;
        qv_insert_req_head = 'd0; 
        qv_insert_req_data = 'd0; 
    end
    else begin
        q_insert_req_valid = i_insert_req_valid;
        qv_insert_req_head = iv_insert_req_head[`REQUIRED_SLOT_NUM_OFFSET]; 
        qv_insert_req_data = iv_insert_req_data; 
        q_insert_req_start = i_insert_req_start; 
        q_insert_req_last  = i_insert_req_last;        
    end
end

//-- o_insert_req_ready --
assign o_insert_req_ready = w_insert_req_ready;

//-- qv_insert_resp_count --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_insert_resp_count <= 'd0;
    end
    else if(i_insert_req_last) begin
        qv_insert_resp_count <= 'd0;
    end
    else if(w_insert_resp_valid) begin
        qv_insert_resp_count <= qv_insert_resp_count + 'd1;
    end
    else begin
        qv_insert_resp_count <= qv_insert_resp_count;
    end
end

//-- q_alloc_valid --
//-- qv_alloc_index --
//-- qv_alloc_data --
always @(*) begin
    if(rst) begin
        q_alloc_valid = 'd0;
        qv_alloc_index = 'd0;
        qv_alloc_data = 'd0;
    end
    else if(w_insert_resp_valid && i_insert_req_start) begin    //This is a trick for judgement
        q_alloc_valid = 'd1;
        qv_alloc_index = {iv_insert_req_head[`INSERT_REQ_QPN_OFFSET], iv_insert_req_head[`INSERT_REQ_PSN_OFFSET]};
        qv_alloc_data = {iv_insert_req_head[`REQUIRED_SLOT_NUM_OFFSET], wv_insert_resp_data};
    end
    else begin
        q_alloc_valid = 'd0;
        qv_alloc_index = 'd0;
        qv_alloc_data = 'd0;
    end
end

//-- q_find_req_valid --
//-- qv_find_req_index --
always @(*) begin
    if(rst) begin
        q_find_req_valid = 'd0;
        qv_find_req_index = 'd0;
    end
    else if(i_delete_req_valid) begin
        q_find_req_valid = 'd1;
        qv_find_req_index = {iv_delete_req_head[`DELETE_REQ_QPN_OFFSET], iv_delete_req_head[`DELETE_REQ_PSN_OFFSET]};
    end
    else if(i_get_req_valid) begin
        q_find_req_valid = 'd1;
        qv_find_req_index = {iv_get_req_head[`GET_REQ_QPN_OFFSET], iv_get_req_head[`GET_REQ_PSN_OFFSET]};       
    end
    else begin
        q_find_req_valid = 'd0;
        qv_find_req_index = 'd0;        
    end
end

//-- o_find_resp_valid_B --
assign o_find_resp_valid_B = w_find_resp_valid;

//-- ov_find_resp_data_B --
assign ov_find_resp_data_B = wv_find_resp_data;

//-- q_recycle_req_valid --
//-- qv_recycle_req_index --
always @(*) begin
    if(rst) begin
        q_recycle_req_valid = 'd0;
        qv_recycle_req_index = 'd0;
    end
    else if(i_delete_req_valid_diff) begin
        q_recycle_req_valid = 'd1;
        qv_recycle_req_index = {iv_delete_req_head_diff[`DELETE_REQ_QPN_OFFSET], iv_delete_req_head_diff[`DELETE_REQ_PSN_OFFSET]};
    end
    else begin
        q_recycle_req_valid = 'd0;
        qv_recycle_req_index = 'd0;
    end
end


//-- i_delete_req_valid_diff --
//-- iv_delete_req_head_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        i_delete_req_valid_diff <= 'd0;
        iv_delete_req_head_diff <= 'd0;
    end
    else begin
        i_delete_req_valid_diff <= i_delete_req_valid;
        iv_delete_req_head_diff <= iv_delete_req_head;        
    end
end

//-- q_delete_req_valid --
//-- qv_delete_req_head --
always @(*) begin
    if(rst) begin
        q_delete_req_valid = 'd0;
        qv_delete_req_head = 'd0;
    end
    else if(i_delete_req_valid_diff) begin
        q_delete_req_valid = 'd1;
        qv_delete_req_head = {wv_find_resp_data[`PKT_SLOT_NUM_LOG + SLOT_NUM_LOG - 1 : SLOT_NUM_LOG], wv_find_resp_data[SLOT_NUM_LOG - 1 : 0]};
    end
    else begin
        q_delete_req_valid = 'd0;
        qv_delete_req_head = 'd0;
    end
end

//-- qv_delete_resp_head --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_delete_resp_head <= 'd0;
    end
    else if(w_delete_resp_valid && w_delete_resp_start) begin
        qv_delete_resp_head <= wv_delete_resp_data;
    end
    else begin
        qv_delete_resp_head <= qv_delete_resp_head;
    end
end

//-- qv_delete_resp_count --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_delete_resp_count <= 'd0;
    end
    else if(w_delete_resp_last && i_delete_resp_ready) begin
        qv_delete_resp_count <= 'd0;
    end
    else if(w_delete_resp_valid && q_delete_resp_ready) begin
        qv_delete_resp_count <= qv_delete_resp_count + 1;
    end
    else begin
        qv_delete_resp_count <= qv_delete_resp_count;
    end
end

//-- q_delete_resp_ready --
always @(*) begin
    if(rst) begin
        q_delete_resp_ready = 'd0;
    end
    else if(qv_delete_resp_count == 0) begin
        q_delete_resp_ready = 'd1;
    end
    else begin
        q_delete_resp_ready = i_delete_resp_ready;
    end
end

reg                             q_delete_null;

//-- q_delete_null --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_delete_null <= 'd0;
    end
    else if(w_find_resp_valid && wv_find_resp_data == 'd0) begin
        q_delete_null <= 'd1;
    end
    else if(w_find_resp_valid && wv_find_resp_data != 'd0) begin
        q_delete_null <= 'd0;
    end
    else begin
        q_delete_null <= q_delete_null;
    end
end

//-- ov_delete_resp_head --
assign ov_delete_resp_head = (w_delete_resp_valid && qv_delete_resp_count == 1) ? qv_delete_resp_head : 'd0;

//-- ov_delete_resp_data --
assign ov_delete_resp_data = (w_delete_resp_valid && w_delete_resp_start) ? 'd0 : wv_delete_resp_data;

//-- o_delete_resp_start --
assign o_delete_resp_start = (w_delete_resp_valid) && (qv_delete_resp_count == 1);

//-- o_delete_resp_last --
assign o_delete_resp_last = w_delete_resp_last;

//-- o_delete_req_ready --
assign o_delete_req_ready = 'd1;

//-- o_delete_resp_valid --
assign o_delete_resp_valid = q_delete_null ? w_delete_resp_valid :
                            (w_delete_resp_valid && w_delete_resp_start) ? 'd0 : w_delete_resp_valid;


//-- i_get_req_valid_diff --
//-- iv_get_req_head_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        i_get_req_valid_diff <= 'd0;
        iv_get_req_head_diff <= 'd0;
    end
    else begin
        i_get_req_valid_diff <= i_get_req_valid;
        iv_get_req_head_diff <= iv_get_req_head;        
    end
end

//-- q_get_req_valid --
//-- qv_get_req_head --
always @(*) begin
    if(rst) begin
        q_get_req_valid = 'd0;
        qv_get_req_head = 'd0;
    end
    else if(i_get_req_valid_diff) begin
        q_get_req_valid = 'd1;
        qv_get_req_head = {wv_find_resp_data[`PKT_SLOT_NUM_LOG + SLOT_NUM_LOG - 1 : SLOT_NUM_LOG], wv_find_resp_data[SLOT_NUM_LOG - 1 : 0]};
    end
    else begin
        q_get_req_valid = 'd0;
        qv_get_req_head = 'd0;
    end
end

//-- qv_get_resp_head --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_get_resp_head <= 'd0;
    end
    else if(w_get_resp_valid && w_get_resp_start) begin
        qv_get_resp_head <= wv_get_resp_data;
    end
    else begin
        qv_get_resp_head <= qv_get_resp_head;
    end
end

//-- qv_get_resp_count --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_get_resp_count <= 'd0;
    end
    else if(w_get_resp_last && i_get_resp_ready) begin
        qv_get_resp_count <= 'd0;
    end
    else if(w_get_resp_valid && q_get_resp_ready) begin
        qv_get_resp_count <= qv_get_resp_count + 1;
    end
    else begin
        qv_get_resp_count <= qv_get_resp_count;
    end
end

//-- q_get_resp_ready --
always @(*) begin
    if(rst) begin
        q_get_resp_ready = 'd0;
    end
    else if(qv_get_resp_count == 0) begin
        q_get_resp_ready = 'd1;
    end
    else begin
        q_get_resp_ready = i_get_resp_ready;
    end
end

//-- o_get_req_ready --
assign o_get_req_ready = 'd1;

//-- o_get_resp_valid --
assign o_get_resp_valid = (w_get_resp_valid && w_get_resp_start) ? 'd0 : w_get_resp_valid;

//-- ov_get_resp_head --
assign ov_get_resp_head = (w_get_resp_valid && qv_get_resp_count == 1) ? qv_get_resp_head : 'd0;

//-- ov_get_resp_data --
assign ov_get_resp_data = (w_get_resp_valid && w_get_resp_start) ? 'd0 : wv_get_resp_data;

//-- o_get_resp_start --
assign o_get_resp_start = (w_get_resp_valid) && (qv_get_resp_count == 1);

//-- o_get_resp_last --
assign o_get_resp_last = w_get_resp_last;

/*------------------------------------------- Variables Decode : End ------------------------------------------------*/
endmodule