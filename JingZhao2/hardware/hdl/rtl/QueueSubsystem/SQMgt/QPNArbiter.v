/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       QPNArbiter
Author:     YangFan
Function:   1.Arbitrate QPN from DBProc and WQEParser.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module QPNArbiter
(
    input   wire                                                            clk,
    input   wire                                                            rst,

    input   wire                                                            chnl_0_qpn_valid,
    input   wire    [`QP_NUM_LOG - 1 : 0]                                   chnl_0_qpn_data,
    output  wire                                                            chnl_0_qpn_ready,

    input   wire                                                            chnl_1_qpn_valid,
    input   wire    [`QP_NUM_LOG - 1 : 0]                                   chnl_1_qpn_data,
    output  wire                                                            chnl_1_qpn_ready,

    output  wire                                                            qpn_valid,
    output  wire    [`QP_NUM_LOG - 1 : 0]                                   qpn_data,
    input   wire                                                            qpn_ready
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