/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       EgressPacketGen
Author:     YangFan
Function:   Dispatch ingress packet to ReqRecvEngine or RespRecvEngine.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module IngressDispatcher
(
    input   wire                                                            clk,
    input   wire                                                            rst,

    input   wire                                                            ingress_packet_valid,
    input   wire        [`PKT_HEAD_BUS_WIDTH - 1 : 0]                       ingress_packet_head,
    input   wire        [`PKT_DATA_BUS_WIDTH - 1 : 0]                       ingress_packet_data,
    input   wire                                                            ingress_packet_start,
    input   wire                                                            ingress_packet_last,
    output  wire                                                            ingress_packet_ready,

    output  wire                                                            req_recv_pkt_meta_valid,
    output  wire    [`PKT_HEAD_BUS_WIDTH - 1 : 0]                           req_recv_pkt_meta_data,
    input   wire                                                            req_recv_pkt_meta_ready,

    output  wire                                                            req_recv_insert_req_valid,
    output  wire    [`REQ_RECV_SLOT_NUM_LOG + `QP_NUM_LOG - 1 : 0]          req_recv_insert_req_head,
    output  wire    [`REQ_RECV_SLOT_WIDTH - 1 : 0]                          req_recv_insert_req_data,
    output  wire                                                            req_recv_insert_req_start,
    output  wire                                                            req_recv_insert_req_last,
    input   wire                                                            req_recv_insert_req_ready,

    input   wire                                                            req_recv_insert_resp_valid,
    input   wire    [`REQ_RECV_SLOT_NUM_LOG - 1 : 0]                        req_recv_insert_resp_data,

    output  wire                                                            resp_recv_pkt_meta_valid,
    output  wire    [`PKT_HEAD_BUS_WIDTH - 1 : 0]                           resp_recv_pkt_meta_data,
    input   wire                                                            resp_recv_pkt_meta_ready,

    output  wire                                                            resp_recv_insert_req_valid,
    output  wire    [`RESP_RECV_SLOT_NUM_LOG + `QP_NUM_LOG - 1 : 0]         resp_recv_insert_req_head,
    output  wire    [`RESP_RECV_SLOT_WIDTH - 1 : 0]                         resp_recv_insert_req_data,
    output  wire                                                            resp_recv_insert_req_start,
    output  wire                                                            resp_recv_insert_req_last,
    input   wire                                                            resp_recv_insert_req_ready,

    input   wire                                                            resp_recv_insert_resp_valid,
    input   wire    [`RESP_RECV_SLOT_NUM_LOG - 1 : 0]                       resp_recv_insert_resp_data
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/


/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/


/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/

/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Variables Decode : End ------------------------------------------------*/

endmodule