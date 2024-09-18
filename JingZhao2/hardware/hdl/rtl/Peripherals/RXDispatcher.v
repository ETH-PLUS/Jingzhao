/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       RXDispatcher
Author:     YangFan
Function:   1.Dispatch RX packet.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module RXDispatcher
(
    input   wire                                                            clk,
    input   wire                                                            rst,

    input   wire                                                            ingress_pkt_valid,
    input   wire    [`PKT_META_BUS_WIDTH - 1 : 0]                           ingress_pkt_head,
    output  wire                                                            ingress_pkt_ready,

    output  wire                                                            req_recv_pkt_valid,
    output  wire    [`PKT_META_BUS_WIDTH - 1 : 0]                           req_recv_pkt_head,
    input   wire                                                            req_recv_pkt_ready,

    output  wire                                                            resp_recv_pkt_valid,
    output  wire    [`PKT_META_BUS_WIDTH - 1 : 0]                           resp_recv_pkt_head,
    input   wire                                                            resp_recv_pkt_ready
);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define             OPCODE_OFFSET           28:24
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- req_recv_pkt_valid --
//-- req_recv_pkt_head --
assign req_recv_pkt_valid = (ingress_pkt_head[`OPCODE_OFFSET] == `SEND_FIRST || ingress_pkt_head[`OPCODE_OFFSET] == `SEND_MIDDLE || ingress_pkt_head[`OPCODE_OFFSET] == `SEND_LAST ||
                            ingress_pkt_head[`OPCODE_OFFSET] == `SEND_ONLY || ingress_pkt_head[`OPCODE_OFFSET] == `SEND_LAST_WITH_IMM || ingress_pkt_head[`OPCODE_OFFSET] == `SEND_ONLY_WITH_IMM ||
                            ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_WRITE_FIRST || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_WRITE_MIDDLE || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_WRITE_LAST ||
                            ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_WRITE_ONLY || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_WRITE_LAST_WITH_IMM || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_WRITE_ONLY_WITH_IMM ||
                            ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_REQUEST_FIRST || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_REQUEST_MIDDLE || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_REQUEST_LAST ||
                            ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_REQUEST_ONLY) ? ingress_pkt_valid : 'd0;
assign req_recv_pkt_head =  (ingress_pkt_head[`OPCODE_OFFSET] == `SEND_FIRST || ingress_pkt_head[`OPCODE_OFFSET] == `SEND_MIDDLE || ingress_pkt_head[`OPCODE_OFFSET] == `SEND_LAST ||
                            ingress_pkt_head[`OPCODE_OFFSET] == `SEND_ONLY || ingress_pkt_head[`OPCODE_OFFSET] == `SEND_LAST_WITH_IMM || ingress_pkt_head[`OPCODE_OFFSET] == `SEND_ONLY_WITH_IMM ||
                            ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_WRITE_FIRST || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_WRITE_MIDDLE || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_WRITE_LAST ||
                            ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_WRITE_ONLY || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_WRITE_LAST_WITH_IMM || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_WRITE_ONLY_WITH_IMM ||
                            ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_REQUEST_FIRST || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_REQUEST_MIDDLE || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_REQUEST_LAST ||
                            ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_REQUEST_ONLY) ? ingress_pkt_head : 'd0;

//-- resp_recv_pkt_valid --
//-- resp_recv_pkt_head --
assign resp_recv_pkt_valid = (ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_RESPONSE_FIRST || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_RESPONSE_MIDDLE ||
                            ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_RESPONSE_LAST || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_RESPONSE_ONLY ||
                            ingress_pkt_head[`OPCODE_OFFSET] == `ACKNOWLEDGE) ? ingress_pkt_valid : 'd0;
assign resp_recv_pkt_head = (ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_RESPONSE_FIRST || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_RESPONSE_MIDDLE ||
                            ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_RESPONSE_LAST || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_RESPONSE_ONLY ||
                            ingress_pkt_head[`OPCODE_OFFSET] == `ACKNOWLEDGE) ? ingress_pkt_head : 'd0;

//-- ingress_pkt_ready --
assign ingress_pkt_ready = (ingress_pkt_head[`OPCODE_OFFSET] == `SEND_FIRST || ingress_pkt_head[`OPCODE_OFFSET] == `SEND_MIDDLE || ingress_pkt_head[`OPCODE_OFFSET] == `SEND_LAST ||
                            ingress_pkt_head[`OPCODE_OFFSET] == `SEND_ONLY || ingress_pkt_head[`OPCODE_OFFSET] == `SEND_LAST_WITH_IMM || ingress_pkt_head[`OPCODE_OFFSET] == `SEND_ONLY_WITH_IMM ||
                            ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_WRITE_FIRST || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_WRITE_MIDDLE || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_WRITE_LAST ||
                            ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_WRITE_ONLY || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_WRITE_LAST_WITH_IMM || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_WRITE_ONLY_WITH_IMM ||
                            ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_REQUEST_FIRST || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_REQUEST_MIDDLE || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_REQUEST_LAST ||
                            ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_REQUEST_ONLY) ? req_recv_pkt_ready :
                            (ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_RESPONSE_FIRST || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_RESPONSE_MIDDLE ||
                            ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_RESPONSE_LAST || ingress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_RESPONSE_ONLY ||
                            ingress_pkt_head[`OPCODE_OFFSET] == `ACKNOWLEDGE) ? resp_recv_pkt_ready : 'd0;
/*------------------------------------------- Variables Decode : End ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef              OPCODE_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule