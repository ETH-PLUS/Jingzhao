/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       SQMetaProc
Author:     YangFan
Function:   Fetch SQ context and page info.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module SQMetaProc
(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with QPNArbiter
    input   wire                                                            qpn_valid,
    input   wire            [23:0]                                          qpn_data,
    output  wire                                                            qpn_ready,

//Interface with CxtMgt
    output  wire                                                            fetch_cxt_ingress_valid,
    output  wire    [`SQ_OOO_CXT_INGRESS_HEAD_WIDTH - 1 : 0]                fetch_cxt_ingress_head, 
    output  wire    [`SQ_OOO_CXT_INGRESS_DATA_WIDTH - 1 : 0]                fetch_cxt_ingress_data, 
    output  wire                                                            fetch_cxt_ingress_start,
    output  wire                                                            fetch_cxt_ingress_last,
    input   wire                                                            fetch_cxt_ingress_ready,

    input   wire                                                            fetch_cxt_egress_valid,
    input   wire    [`SQ_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]                 fetch_cxt_egress_head,  
    input   wire    [`SQ_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]                 fetch_cxt_egress_data,
    input   wire                                                            fetch_cxt_egress_start,
    input   wire                                                            fetch_cxt_egress_last,
    output  wire                                                            fetch_cxt_egress_ready,

//Interface with MRMgt    
    output  wire                                                            fetch_mr_ingress_valid,
    output  wire    [`SQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]                 fetch_mr_ingress_head, 
    output  wire    [`SQ_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]                 fetch_mr_ingress_data,
    output  wire                                                            fetch_mr_ingress_start,
    output  wire                                                            fetch_mr_ingress_last,
    input   wire                                                            fetch_mr_ingress_ready,

    input   wire                                                            fetch_mr_egress_valid,
    input   wire    [`SQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]                  fetch_mr_egress_head,
    input   wire    [`SQ_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]                  fetch_mr_egress_data,
    input   wire                                                            fetch_mr_egress_start,
    input   wire                                                            fetch_mr_egress_last,
    output  wire                                                            fetch_mr_egress_ready,

//Interface with SQOffsetRecord
    output  wire    [0:0]                                                   sq_offset_wen,
    output  wire    [`QP_NUM_LOG - 1 : 0]                                   sq_offset_addr,
    output  wire    [23:0]                                                  sq_offset_din,
    input   wire    [23:0]                                                  sq_offset_dout,
    
//Interface with WQEFetch
    output  wire                                                            sq_meta_valid,
    output  wire    [`SQ_META_WIDTH - 1 : 0]                                sq_meta_data,
    input   wire                                                            sq_meta_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/

/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
SQMetaProc_Thread_1 SQMetaProc_Thread_1_Inst
(
    .clk                                            (       clk                         ),
    .rst                                            (       rst                         ),

    .qpn_valid                                      (       qpn_valid                   ),
    .qpn_data                                       (       qpn_data                    ),
    .qpn_ready                                      (       qpn_ready                   ),

    .fetch_cxt_ingress_valid                        (       fetch_cxt_ingress_valid      ),
    .fetch_cxt_ingress_head                         (       fetch_cxt_ingress_head       ),  
    .fetch_cxt_ingress_data                         (       fetch_cxt_ingress_data       ),  
    .fetch_cxt_ingress_start                        (       fetch_cxt_ingress_start      ),
    .fetch_cxt_ingress_last                         (       fetch_cxt_ingress_last       ),
    .fetch_cxt_ingress_ready                        (       fetch_cxt_ingress_ready      )
);

SQMetaProc_Thread_2 SQMetaProc_Thread_2_Inst
(
    .clk                                            (       clk                         ),
    .rst                                            (       rst                         ),

    .fetch_cxt_egress_valid                         (       fetch_cxt_egress_valid      ),
    .fetch_cxt_egress_head                          (       fetch_cxt_egress_head       ),
    .fetch_cxt_egress_data                          (       fetch_cxt_egress_data       ),
    .fetch_cxt_egress_start                         (       fetch_cxt_egress_start      ),
    .fetch_cxt_egress_last                          (       fetch_cxt_egress_last       ),
    .fetch_cxt_egress_ready                         (       fetch_cxt_egress_ready      ),

    .sq_offset_wen                                  (       sq_offset_wen               ),
    .sq_offset_addr                                 (       sq_offset_addr              ),
    .sq_offset_din                                  (       sq_offset_din               ),
    .sq_offset_dout                                 (       sq_offset_dout              ),
 
    .fetch_mr_ingress_valid                         (       fetch_mr_ingress_valid      ),
    .fetch_mr_ingress_head                          (       fetch_mr_ingress_head       ), 
    .fetch_mr_ingress_data                          (       fetch_mr_ingress_data       ),
    .fetch_mr_ingress_start                         (       fetch_mr_ingress_start      ),
    .fetch_mr_ingress_last                          (       fetch_mr_ingress_last       ),
    .fetch_mr_ingress_ready                         (       fetch_mr_ingress_ready      ),

    .fetch_mr_egress_valid                          (       fetch_mr_egress_valid       ),
    .fetch_mr_egress_head                           (       fetch_mr_egress_head        ),
    .fetch_mr_egress_data                           (       fetch_mr_egress_data        ),
    .fetch_mr_egress_start                          (       fetch_mr_egress_start       ),
    .fetch_mr_egress_last                           (       fetch_mr_egress_last        ),
    .fetch_mr_egress_ready                          (       fetch_mr_egress_ready       ),
    
    .sq_meta_valid                                  (       sq_meta_valid               ),
    .sq_meta_data                                   (       sq_meta_data                ),
    .sq_meta_ready                                  (       sq_meta_ready               )
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/

/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule