/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       TransportHashTable
Author:     YangFan
Function:   Record packet metadata.
            Crucial to the retransmission protocol.
            1.When enqueue a packet in normal TX procedure, record the packet's start address;
            2.When require a packet in resend TX procedure, provide the packet's start address.
            Key problem is how to allocate and locate a metadata slot based on {QPN + PSN}.
            I don't know the best solution, sevveral implementations should be compared.
            TransportHashTable should provide a standard interface.
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

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module TransportHashTable #(
    parameter SLOT_NUM        =   65536,
    parameter SLOT_NUM_LOG    =   log2b(SLOT_NUM - 1),
    parameter SLOT_WIDTH      =   9 
)(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Allocate a HashTable slot and enqueue a packet metadata
    input   wire                                                            i_alloc_valid,
    input   wire                    [`QP_NUM_LOG + `PSN_WIDTH - 1 : 0]      iv_alloc_index,
    input   wire                    [8 + SLOT_WIDTH - 1 : 0]                iv_alloc_data,
    output  reg                                                             o_alloc_ready,

//Provide a HashTable slot content
    input   wire                                                            i_find_req_valid_A,
    input   wire                    [`QP_NUM_LOG + `PSN_WIDTH - 1 : 0]      iv_find_req_index_A,
    output  reg                                                             o_find_resp_valid_A,
    output  reg                     [8 + SLOT_WIDTH : 0]                    ov_find_resp_data_A,

//Provide a HashTable slot content
    input   wire                                                            i_find_req_valid_B,
    input   wire                    [`QP_NUM_LOG + `PSN_WIDTH - 1 : 0]      iv_find_req_index_B,
    output  reg                                                             o_find_resp_valid_B,
    output  reg                     [8 + SLOT_WIDTH : 0]                    ov_find_resp_data_B,

//Recycle a HashTable slot
    input   wire                                                            i_recycle_req_valid,
    input   wire                    [`QP_NUM_LOG + `PSN_WIDTH - 1 : 0]      iv_recycle_req_index,
    output  reg                                                             o_recycle_req_ready,
    output  reg                                                             o_recyle_resp_valid,
    output  reg                     [SLOT_WIDTH - 1 : 0]                    ov_recycle_resp_data

);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg                                             wea;
reg                 [SLOT_NUM_LOG - 1 : 0]      addra;
reg                 [8 + SLOT_WIDTH : 0]        dina;
wire                [8 + SLOT_WIDTH : 0]        douta;

reg                                             web;
reg                 [SLOT_NUM_LOG - 1 : 0]      addrb;
reg                 [8 + SLOT_WIDTH : 0]        dinb;
wire                [8 + SLOT_WIDTH : 0]        doutb;

reg                                             q_find_req_mandatory_flag_A;
reg                                             q_find_req_mandatory_flag_B;
reg                                             q_recycle_req_mandatory_flag;;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
SRAM_TDP_Template #(
    .RAM_WIDTH(1 + 8 + `RECV_BUFFER_SLOT_NUM_LOG),
    .RAM_DEPTH(65536)  
) HashTable_inst(
    .clk    (       clk                    ),
    .rst    (       rst                    ),

    .wea    (       wea                     ),
    .addra  (       addra                   ),
    .dina   (       dina                    ),
    .douta  (       douta                   ),             

    .web    (       web                     ),
    .addrb  (       addrb                   ),
    .dinb   (       dinb                    ),
    .doutb  (       doutb                   ) 
);

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
//NULL
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

//-- wea --
//-- addra --
//-- dina --
always @(*) begin
    if(rst) begin
        wea = 'd0;
        addra = 'd0;
        dina = 'd0;
    end
    else if(i_alloc_valid) begin
        wea = 'd1;
        addra = {iv_alloc_index[`PSN_WIDTH + `QP_NUM_LOG - 1 : `PSN_WIDTH], iv_alloc_index[9 : 0]};     //64 QP, each QP occupies 1K slot
        dina = {1'b1, iv_alloc_data};
    end
    else if(i_find_req_valid_A) begin
        wea = 'd0;
        addra = {iv_find_req_index_A[`PSN_WIDTH + `QP_NUM_LOG - 1 : `PSN_WIDTH], iv_find_req_index_A[9 : 0]};     //64 QP, each QP occupies 1K slot
        dina = 'd0;        
    end
    else begin
        wea = 'd0;
        addra = 'd0;
        dina = 'd0;
    end
end

//-- web --
//-- addrb --
//-- dinb --
always @(*) begin
    if(rst) begin
        web = 'd0;
        addrb = 'd0;
        dinb = 'd0;
    end
    else if(i_recycle_req_valid) begin
        web = 'd1;
        addrb = {iv_recycle_req_index[`PSN_WIDTH + `QP_NUM_LOG - 1 : `PSN_WIDTH], iv_recycle_req_index[9 : 0]};     //64 QP, each QP occupies 1K slot
        dinb = 'd0;
    end
    else if(i_find_req_valid_B) begin
        web = 'd0;
        addrb = {iv_find_req_index_B[`PSN_WIDTH + `QP_NUM_LOG - 1 : `PSN_WIDTH], iv_find_req_index_B[9 : 0]};     //64 QP, each QP occupies 1K slot
        dinb = 'd0;        
    end
    else begin
        web = 'd0;
        addrb = 'd0;
        dinb = 'd0;
    end
end

//-- o_alloc_ready --
always @(*) begin
    if(rst) begin
        o_alloc_ready = 'd0;
    end
    else begin
        o_alloc_ready = 'd1;
    end
end

//-- o_find_resp_valid_A --
//-- ov_find_resp_data_A --
always @(*) begin
    if(rst) begin
        o_find_resp_valid_A = 'd0;
        ov_find_resp_data_A = 'd0;
    end
    else if(q_find_req_mandatory_flag_A) begin
        o_find_resp_valid_A = 'd1;
        ov_find_resp_data_A = douta;     
    end
    else begin
        o_find_resp_valid_A = 'd0;
        ov_find_resp_data_A = 'd0;
    end
end

//-- o_find_resp_valid_B --
//-- ov_find_resp_data_B --
always @(*) begin
    if(rst) begin
        o_find_resp_valid_B = 'd0;
        ov_find_resp_data_B = 'd0;
    end
    else if(q_find_req_mandatory_flag_B) begin
        o_find_resp_valid_B = 'd1;
        ov_find_resp_data_B = doutb;      
    end
    else begin
        o_find_resp_valid_B = 'd0;
        ov_find_resp_data_B = 'd0;
    end
end

//-- o_recycle_req_ready --
always @(*) begin
    if(rst) begin
        o_recycle_req_ready = 'd0;
    end
    else begin
        o_recycle_req_ready = 'd1;
    end
end

//-- o_recyle_resp_valid --
//-- ov_recycle_resp_data --
always @(*) begin
    if(rst) begin
        o_recyle_resp_valid = 'd0;
        ov_recycle_resp_data = 'd0;
    end
    else if(q_find_req_mandatory_flag_B) begin
        o_recyle_resp_valid = 'd1;
        ov_recycle_resp_data = doutb;      
    end
    else begin
        o_recyle_resp_valid = 'd0;
        ov_recycle_resp_data = 'd0;
    end
end

//-- q_recycle_req_mandatory_flag --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_recycle_req_mandatory_flag <= 'd0;
    end
    else if(i_find_req_valid_B) begin
        q_recycle_req_mandatory_flag <= 'd1;
    end
    else begin
        q_recycle_req_mandatory_flag <= 'd0;
    end
end

//-- q_find_req_mandatory_flag_A --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_find_req_mandatory_flag_A <= 'd0;
    end
    else if(i_find_req_valid_A) begin
        q_find_req_mandatory_flag_A <= 'd1;
    end
    else begin
        q_find_req_mandatory_flag_A <= 'd0;
    end
end

//-- q_find_req_mandatory_flag_B --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_find_req_mandatory_flag_B <= 'd0;
    end
    else if(i_find_req_valid_B) begin
        q_find_req_mandatory_flag_B <= 'd1;
    end
    else begin
        q_find_req_mandatory_flag_B <= 'd0;
    end
end

/*------------------------------------------- Variables Decode : End ------------------------------------------------*/
endmodule