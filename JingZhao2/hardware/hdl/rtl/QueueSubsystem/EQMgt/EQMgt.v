/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       CQMgt
Author:     YangFan
Function:   1.Manage CQ.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module EQMgt
(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with ReqTransCore
    input   wire                                                            TX_REQ_eq_req_valid,
    input   wire    [`EQ_REQ_HEAD_WIDTH - 1 : 0]                            TX_REQ_eq_req_head,
    output  wire                                                            TX_REQ_eq_req_ready,
     
    output  wire                                                            TX_REQ_eq_resp_valid,
    output  wire    [`EQ_RESP_HEAD_WIDTH - 1 : 0]                           TX_REQ_eq_resp_head,
    input   wire                                                            TX_REQ_eq_resp_ready,

//Interface with ReqRecvCore
    input   wire                                                            RX_REQ_eq_req_valid,
    input   wire    [`EQ_REQ_HEAD_WIDTH - 1 : 0]                            RX_REQ_eq_req_head,
    output  wire                                                            RX_REQ_eq_req_ready,
     
    output  wire                                                            RX_REQ_eq_resp_valid,
    output  wire    [`EQ_RESP_HEAD_WIDTH - 1 : 0]                           RX_REQ_eq_resp_head,
    input   wire                                                            RX_REQ_eq_resp_ready,

//Interface with RespRecvCore
    input   wire                                                            RX_RESP_eq_req_valid,
    input   wire    [`EQ_REQ_HEAD_WIDTH - 1 : 0]                            RX_RESP_eq_req_head,
    output  wire                                                            RX_RESP_eq_req_ready,
     
    output  wire                                                            RX_RESP_eq_resp_valid,
    output  wire    [`EQ_RESP_HEAD_WIDTH - 1 : 0]                           RX_RESP_eq_resp_head,
    input   wire                                                            RX_RESP_eq_resp_ready
);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
reg     counter;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        counter <= 'd1;        
    end
    else begin
        counter <= counter;
    end
end

assign TX_REQ_eq_req_ready = 'd1;

assign TX_REQ_eq_resp_valid = 'd1;
assign TX_REQ_eq_resp_head = 'd1;

assign RX_REQ_eq_req_ready = 'd1;

assign RX_REQ_eq_resp_valid = 'd1;
assign RX_REQ_eq_resp_head = 'd1;

assign RX_RESP_eq_req_ready = 'd1;

assign RX_RESP_eq_resp_valid = 'd1;
assign RX_RESP_eq_resp_head = 'd1;


/*------------------------------------------- Variables Decode : End ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/

/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule