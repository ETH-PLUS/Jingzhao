/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       OoOStation_Thread_3
Author:     YangFan
Function:   Arbitrate different egress response. Bypass mode has highest priority.
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
module OoOStation_Thread_3 #(
    parameter       ID                          =   1,

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
    input   wire                                                    clk,
    input   wire                                                    rst,

    input   wire                                                    bypass_egress_valid,
    input   wire        [EGRESS_HEAD_WIDTH - 1 : 0]                 bypass_egress_head,
    input   wire        [EGRESS_DATA_WIDTH - 1 : 0]                 bypass_egress_data,
    input   wire                                                    bypass_egress_start,
    input   wire                                                    bypass_egress_last,
    output  wire                                                    bypass_egress_ready,

    input   wire                                                    normal_egress_valid,
    input   wire        [EGRESS_HEAD_WIDTH - 1 : 0]                 normal_egress_head,
    input   wire        [EGRESS_DATA_WIDTH - 1 : 0]                 normal_egress_data,
    input   wire                                                    normal_egress_start,
    input   wire                                                    normal_egress_last,
    output  wire                                                    normal_egress_ready,

    output  wire                                                    egress_valid,
    output  wire        [EGRESS_HEAD_WIDTH - 1 : 0]                 egress_head,
    output  wire        [EGRESS_DATA_WIDTH - 1 : 0]                 egress_data,
    output  wire                                                    egress_start,
    output  wire                                                    egress_last,
    input   wire                                                    egress_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg                 [1:0]                       cur_state;
reg                 [1:0]                       next_state;

parameter           [1:0]                       IDLE_s = 2'd1,
                                                BYPASS_s = 2'd2,
                                                NORMAL_s = 2'd3;

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
        IDLE_s:                 if(bypass_egress_valid) begin
                                    next_state = BYPASS_s;
                                end
                                else if(normal_egress_valid) begin
                                    next_state = NORMAL_s;
                                end
                                else begin
                                    next_state = IDLE_s;
                                end
        BYPASS_s:               if(egress_valid && egress_ready) begin
                                    next_state = IDLE_s;
                                end
                                else begin
                                    next_state = BYPASS_s;
                                end
        NORMAL_s:               if(egress_valid && egress_ready) begin
                                    next_state = IDLE_s;
                                end
                                else begin
                                    next_state = NORMAL_s;
                                end
        default:                next_state = IDLE_s;
    endcase
end

/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- bypass_egress_ready --
assign bypass_egress_ready = (cur_state == BYPASS_s) ? egress_ready : 'd0;

//-- normal_egress_ready --
assign normal_egress_ready = (cur_state == NORMAL_s) ? egress_ready : 'd0;

//-- egress_valid --
//-- egress_head --
//-- egress_data --
//-- egress_start --
//-- egress_last --
assign egress_valid =   (cur_state == BYPASS_s) ? bypass_egress_valid : 
                        (cur_state == NORMAL_s) ? normal_egress_valid : 'd0;
assign egress_head =    (cur_state == BYPASS_s) ? bypass_egress_head : 
                        (cur_state == NORMAL_s) ? normal_egress_head : 'd0;   
assign egress_data =    (cur_state == BYPASS_s) ? bypass_egress_data : 
                        (cur_state == NORMAL_s) ? normal_egress_data : 'd0;
assign egress_start =   (cur_state == BYPASS_s) ? bypass_egress_start : 
                        (cur_state == NORMAL_s) ? normal_egress_start : 'd0;
assign egress_last =    (cur_state == BYPASS_s) ? bypass_egress_last : 
                        (cur_state == NORMAL_s) ? normal_egress_last : 'd0;
/*------------------------------------------- Variables Decode : End ------------------------------------------------*/


/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/

/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/
endmodule