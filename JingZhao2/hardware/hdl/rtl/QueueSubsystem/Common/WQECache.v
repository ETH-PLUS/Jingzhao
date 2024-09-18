/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       WQECache
Author:     YangFan
Function:   Fetch WQE from WQECache or Host Memory.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module WQECache
#(
    parameter   CACHE_SLOT_NUM          =       256,
    parameter   CACHE_SLOT_NUM_LOG      =       log2b(CACHE_SLOT_NUM - 1),

    parameter   CACHE_CELL_NUM          =       256,
    parameter   CACHE_CELL_NUM_LOG      =       log2b(CACHE_CELL_NUM - 1)
)
(
    input   wire                                                            clk,
    input   wire                                                            rst,

    input   wire                                                           	cache_buffer_wea,
    input   wire    [log2b(CACHE_SLOT_NUM * CACHE_CELL_NUM - 1) - 1 : 0]                        cache_buffer_addra,
    input   wire    [`WQE_SEG_WIDTH - 1 : 0]                                cache_buffer_dina,

    input   wire   	[log2b(CACHE_SLOT_NUM * CACHE_CELL_NUM - 1) - 1 : 0]                        cache_buffer_addrb,
    output  wire   	[`WQE_SEG_WIDTH - 1 : 0]                                cache_buffer_doutb,

    input   wire                                                           	cache_owned_wea,
    input   wire   	[CACHE_CELL_NUM_LOG - 1 : 0]                        cache_owned_addra,
    input   wire   	[`QP_NUM_LOG - 1 : 0]                                   cache_owned_dina,
    output  wire    [`QP_NUM_LOG - 1 : 0]                                   cache_owned_douta,

    input   wire                                                            cache_owned_web,
    input   wire    [CACHE_CELL_NUM_LOG - 1 : 0]                        cache_owned_addrb,
    input   wire    [`QP_NUM_LOG - 1 : 0]                                   cache_owned_dinb,
    output  wire    [`QP_NUM_LOG - 1 : 0]                                   cache_owned_doutb,

    input   wire                                                            cache_offset_wea,
    input   wire    [`QP_NUM_LOG - 1 : 0]                                   cache_offset_addra,
    input   wire    [CACHE_SLOT_NUM_LOG - 1:0]                          cache_offset_dina,
    output  wire    [CACHE_SLOT_NUM_LOG - 1:0]                          cache_offset_douta,

    input   wire                                                            cache_offset_web,
    input   wire    [`QP_NUM_LOG - 1 : 0]                                   cache_offset_addrb,
    input   wire    [CACHE_SLOT_NUM_LOG - 1:0]                          cache_offset_dinb,
    output  wire    [CACHE_SLOT_NUM_LOG - 1:0]                          cache_offset_doutb

);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
SRAM_TDP_Template #(
    .RAM_WIDTH      (   `QP_NUM_LOG - CACHE_CELL_NUM_LOG + 1    ),  //+1 for valid bit
    .RAM_DEPTH      (   CACHE_CELL_NUM                          )
)
CacheOwnedTable
(
    .clk            (   clk                                     ),
    .rst            (   rst                                     ),

    .wea            (   cache_owned_wea                         ),
    .addra          (   cache_owned_addra                       ),
    .dina           (   cache_owned_dina                        ),
    .douta          (   cache_owned_douta                       ),

    .web            (   cache_owned_web                         ),
    .addrb          (   cache_owned_addrb                       ),
    .dinb           (   cache_owned_dinb                        ),
    .doutb          (   cache_owned_doutb                       )
);

SRAM_TDP_Template #(
    .RAM_WIDTH      (   CACHE_SLOT_NUM_LOG                      ),      //Record each cell offset(in unit of slot)
    .RAM_DEPTH      (   CACHE_CELL_NUM                          )
)
CacheOffsetTable
(
    .clk            (   clk                                     ),
    .rst            (   rst                                     ),

    .wea            (   cache_offset_wea                        ),
    .addra          (   cache_offset_addra                      ),
    .dina           (   cache_offset_dina                       ),
    .douta          (   cache_offset_douta                      ),

    .web            (   cache_offset_web                        ),
    .addrb          (   cache_offset_addrb                      ),
    .dinb           (   cache_offset_dinb                       ),
    .doutb          (   cache_offset_doutb                      )
);

SRAM_SDP_Template #(
    .RAM_WIDTH      (   `WQE_SEG_WIDTH                          ),
    .RAM_DEPTH      (   CACHE_CELL_NUM * CACHE_SLOT_NUM         )
)
CacheBuffer
(
    .clk            (   clk                                     ),
    .rst            (   rst                                     ),

    .wea            (   cache_buffer_wea                        ),
    .addra          (   cache_buffer_addra                      ),
    .dina           (   cache_buffer_dina                       ),

    .addrb          (   cache_buffer_addrb                      ),
    .doutb          (   cache_buffer_doutb                      )
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule