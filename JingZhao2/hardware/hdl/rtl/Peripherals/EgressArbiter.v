/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       EgressArbiter
Author:     YangFan
Function:   In NIC/Switch processing pipeline, protocol processing requires frequent appending and removing header.
            This module abstracts the append process.
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
module EgressArbiter
(
    input   wire                                            clk,
    input   wire                                            rst,

    input   wire                                            req_trans_pkt_out_valid,
    input   wire        [`PKT_HEAD_BUS_WIDTH - 1 : 0]       req_trans_pkt_out_head,
    input   wire        [`PKT_DATA_BUS_WIDTH - 1 : 0]       req_trans_pkt_out_data,
    input   wire                                            req_trans_pkt_out_start,
    input   wire                                            req_trans_pkt_out_last,
    output  wire                                            req_trans_pkt_out_ready,

    input   wire                                            resp_trans_pkt_out_valid,
    input   wire        [`PKT_HEAD_BUS_WIDTH - 1 : 0]       resp_trans_pkt_out_head,
    input   wire        [`PKT_DATA_BUS_WIDTH - 1 : 0]       resp_trans_pkt_out_data,
    input   wire                                            resp_trans_pkt_out_start,
    input   wire                                            resp_trans_pkt_out_last,
    output  wire                                            resp_trans_pkt_out_ready,

    input   wire                                            egress_pkt_valid,
    input   wire        [`PKT_HEAD_BUS_WIDTH - 1 : 0]       egress_pkt_head,
    input   wire        [`PKT_DATA_BUS_WIDTH - 1 : 0]       egress_pkt_data,
    input   wire                                            egress_pkt_start,
    input   wire                                            egress_pkt_last,
    output  wire                                            egress_pkt_ready
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