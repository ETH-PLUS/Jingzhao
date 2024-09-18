/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       DynamicBufferDeleteArbiter
Author:     YangFan
Function:   1.Arbitrate delete Request.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module DynamicBufferDeleteArbiter
(
    input   wire                                                            clk,
    input   wire                                                            rst,

    input   wire                                                            chnl_0_req_valid,
    input   wire    [`MAX_DB_SLOT_NUM_LOG * 2 - 1 : 0]                      chnl_0_req_head,
    output  wire                                                            chnl_0_req_ready,

    output  wire                                                            chnl_0_resp_valid,
    output  wire                                                            chnl_0_resp_start,
    output  wire                                                            chnl_0_resp_last,
    output  wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     chnl_0_resp_data,
    input   wire                                                            chnl_0_resp_ready,

    input   wire                                                            chnl_1_req_valid,
    input   wire    [`MAX_DB_SLOT_NUM_LOG * 2 - 1 : 0]                      chnl_1_req_head,
    output  wire                                                            chnl_1_req_ready,

    output  wire                                                            chnl_1_resp_valid,
    output  wire                                                            chnl_1_resp_start,
    output  wire                                                            chnl_1_resp_last,
    output  wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     chnl_1_resp_data,
    input   wire                                                            chnl_1_resp_ready,

    output  wire                                                            delete_req_valid,
    output  wire    [`MAX_DB_SLOT_NUM_LOG * 2 - 1 : 0]                      delete_req_head,
    input   wire                                                            delete_req_ready,
                    
    input   wire                                                            delete_resp_valid,
    input   wire                                                            delete_resp_start,
    input   wire                                                            delete_resp_last,
    input   wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     delete_resp_data,
    output  wire                                                            delete_resp_ready
);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define         CHNL_0              0
`define         CHNL_1              1
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg             [0:0]               last_sch_chnl;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg             [1:0]               cur_state;
reg             [1:0]               next_state;

parameter       [1:0]               IDLE_s      = 2'd1,
                                    CHNL_0_s    = 2'd2,
                                    CHNL_1_s    = 2'd3;

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
        IDLE_s:         if(last_sch_chnl == `CHNL_0 && chnl_1_req_valid) begin
                            next_state = CHNL_1_s;
                        end
                        else if(last_sch_chnl == `CHNL_1 && chnl_0_req_valid) begin
                            next_state = CHNL_0_s;
                        end
                        else if(last_sch_chnl == `CHNL_1 && !chnl_0_req_valid && chnl_1_req_valid) begin
                            next_state = CHNL_1_s;
                        end
                        else if(last_sch_chnl == `CHNL_0 && !chnl_1_req_valid && chnl_0_req_valid) begin
                            next_state = CHNL_0_s;
                        end
                        else begin
                            next_state = IDLE_s;
                        end
        CHNL_0_s:       if(chnl_0_resp_last && chnl_0_resp_ready) begin
                            next_state = IDLE_s;
                        end
                        else begin
                            next_state = CHNL_0_s;
                        end
        CHNL_1_s:       if(chnl_1_resp_last && chnl_1_resp_ready) begin
                            next_state = IDLE_s;
                        end
                        else begin
                            next_state = CHNL_1_s;
                        end
        default:        next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- last_sch_chnl --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        last_sch_chnl <= `CHNL_0;        
    end
    else if (cur_state == CHNL_0_s && chnl_0_resp_last && chnl_0_resp_ready) begin
        last_sch_chnl <= `CHNL_0;
    end
    else if (cur_state == CHNL_1_s && chnl_1_resp_last && chnl_1_resp_ready) begin
        last_sch_chnl <= `CHNL_1;
    end
    else begin
        last_sch_chnl <= last_sch_chnl;
    end
end

//-- chnl_0_req_ready --
assign chnl_0_req_ready = (cur_state == CHNL_0_s) ? delete_req_ready : 'd0;

//-- chnl_1_req_ready --
assign chnl_1_req_ready = (cur_state == CHNL_1_s) ? delete_req_ready : 'd0;

//-- chnl_0_resp_valid --
//-- chnl_0_resp_start --
//-- chnl_0_resp_last --
//-- chnl_0_resp_data --
assign chnl_0_resp_valid = (cur_state == CHNL_0_s) ? delete_resp_valid : 'd0;
assign chnl_0_resp_start = (cur_state == CHNL_0_s) ? delete_resp_start : 'd0;
assign chnl_0_resp_last = (cur_state == CHNL_0_s) ? delete_resp_last : 'd0;
assign chnl_0_resp_data = (cur_state == CHNL_0_s) ? delete_resp_data : 'd0;

//-- chnl_1_resp_valid --
//-- chnl_1_resp_start --
//-- chnl_1_resp_last --
//-- chnl_1_resp_data --
assign chnl_1_resp_valid = (cur_state == CHNL_1_s) ? delete_resp_valid : 'd0;
assign chnl_1_resp_start = (cur_state == CHNL_1_s) ? delete_resp_start : 'd0;
assign chnl_1_resp_last = (cur_state == CHNL_1_s) ? delete_resp_last : 'd0;
assign chnl_1_resp_data = (cur_state == CHNL_1_s) ? delete_resp_data : 'd0;

//-- delete_req_valid --
//-- delete_req_head --
assign delete_req_valid = (cur_state == CHNL_0_s) ? chnl_0_req_valid : 
                            (cur_state == CHNL_1_s) ? chnl_1_req_valid : 'd0;
assign delete_req_head = (cur_state == CHNL_0_s) ? chnl_0_req_head : 
                            (cur_state == CHNL_1_s) ? chnl_1_req_head : 'd0;

//-- delete_resp_ready --
assign delete_resp_ready = (cur_state == CHNL_0_s) ? chnl_0_resp_ready :
                            (cur_state == CHNL_1_s) ? chnl_1_resp_ready : 'd0;
/*------------------------------------------- Variables Decode : End ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/

/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule