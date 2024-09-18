		/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       RespTransCore
Author:     YangFan
Function:   1.Generate network resp
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module RespTransCore
(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with ReqRecvCore
    output  wire                                                            net_resp_ren,
    input   wire                               								net_resp_empty,
    input   wire     [`NET_REQ_META_WIDTH - 1 : 0]                          net_resp_dout,

//Interface with Gather Data
    input   wire                                                            payload_empty,
    input   wire    [511:0]                                                 payload_data,
    output  wire                                                            payload_ren,

//Interface with Payload Buffer
    output  wire                                                            insert_req_valid,
    output  wire                                                            insert_req_start,
    output  wire                                                            insert_req_last,
    output  wire    [`PACKET_BUFFER_SLOT_NUM_LOG - 1 : 0]                   insert_req_head,
    output  wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     insert_req_data,
    input   wire                                                            insert_req_ready,

    input   wire                                                            insert_resp_valid,
    input   wire    [`PACKET_BUFFER_SLOT_NUM_LOG - 1 : 0]                   insert_resp_data,

//Interface with TransportSubsystem
    output  wire                                                            egress_pkt_valid,
    output  wire    [`PKT_META_BUS_WIDTH - 1 : 0]                           egress_pkt_head,
    input   wire                                                            egress_pkt_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
RespTransCore_Thread_1 RespTransCore_Thread_1_Inst(
    .clk                                (   clk                     ),
    .rst                                (   rst                     ),

    .net_resp_ren                       (   net_resp_ren            ),
    .net_resp_empty                     (   net_resp_empty          ),
    .net_resp_dout                      (   net_resp_dout           ),

    .payload_empty                      (   payload_empty           ),
    .payload_data                       (   payload_data            ),
    .payload_ren                        (   payload_ren             ),

    .insert_req_valid                   (   insert_req_valid        ),
    .insert_req_start                   (   insert_req_start        ),
    .insert_req_last                    (   insert_req_last         ),
    .insert_req_head                    (   insert_req_head         ),
    .insert_req_data                    (   insert_req_data         ),
    .insert_req_ready                   (   insert_req_ready        ),

    .insert_resp_valid                  (   insert_resp_valid       ),
    .insert_resp_data                   (   insert_resp_data        ),

    .egress_pkt_valid                   (   egress_pkt_valid        ),
    .egress_pkt_head                    (   egress_pkt_head         ),
    .egress_pkt_ready                   (   egress_pkt_ready        )
);

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
/*------------------------------------------- Variables Decode : End ----------------------------------------------***/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule