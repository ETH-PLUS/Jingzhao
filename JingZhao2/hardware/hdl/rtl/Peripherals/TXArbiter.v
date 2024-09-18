/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       TXArbiter
Author:     YangFan
Function:   1.Arbitrate TX packet.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module TXArbiter
(
    input   wire                                                            clk,
    input   wire                                                            rst,

    input   wire                                                            chnl_0_pkt_valid,
    input   wire    [`PKT_META_BUS_WIDTH - 1 : 0]                           chnl_0_pkt_head,
    output  wire                                                            chnl_0_pkt_ready,

    input   wire                                                            chnl_1_pkt_valid,
    input   wire    [`PKT_META_BUS_WIDTH - 1 : 0]                           chnl_1_pkt_head,
    output  wire                                                            chnl_1_pkt_ready,

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
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
/*------------------------------------------- Variables Decode : End ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/

/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule