/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ICMMetaProc
Author:     YangFan
Function:   Store ICM space to Physical Address Mapping.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module ICMMetaProc
#(
    parameter               ICM_CACHE_TYPE          =       `CACHE_TYPE_MTT,

    parameter               ICM_PAGE_NUM            =       `ICM_PAGE_NUM_MTT,
    parameter               ICM_PAGE_NUM_LOG        =       log2b(ICM_PAGE_NUM - 1),
    parameter               ICM_ENTRY_NUM           =       `ICM_ENTRY_NUM_MTT,
    parameter               ICM_ENTRY_NUM_LOG       =       log2b(ICM_ENTRY_NUM - 1),
    parameter               ICM_SLOT_SIZE           =       `ICM_SLOT_SIZE_MTT
)
(
    input   wire                                            clk,
    input   wire                                            rst,

//Set ICM Mapping Table Entry
    input   wire                                            icm_mapping_set_valid,
    input   wire    [`PAGE_FRAME_WIDTH - 1 : 0]             icm_mapping_set_head,
    input   wire    [`PAGE_FRAME_WIDTH - 1 : 0]             icm_mapping_set_data,

//Mapping Lookup Interface
    input   wire                                            icm_mapping_lookup_valid,
    input   wire    [ICM_ENTRY_NUM_LOG - 1 : 0]             icm_mapping_lookup_head,

    output  reg                                             icm_mapping_rsp_valid,
    output  reg     [`ICM_SPACE_ADDR_WIDTH - 1 : 0]         icm_mapping_rsp_icm_addr,
    output  wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]         icm_mapping_rsp_phy_addr,

    input   wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]         icm_base
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                            mapping_wea;
wire    [ICM_PAGE_NUM_LOG - 1 : 0]              mapping_addra;
wire    [`PAGE_FRAME_WIDTH - 1 : 0]             mapping_dina;

wire    [ICM_PAGE_NUM_LOG - 1 : 0]              mapping_addrb;
wire    [`PAGE_FRAME_WIDTH - 1 : 0]             mapping_doutb;

wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]         icm_lookup_relative_addr;
reg     [11:0]                                  icm_lookup_page_offset;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
SRAM_SDP_Template #(
    .RAM_WIDTH  (   `PAGE_FRAME_WIDTH               ),
    .RAM_DEPTH  (   ICM_PAGE_NUM                    )
)
ICMMappingTable
(
    .clk        (   clk                             ),
    .rst        (   rst                             ),

    .wea        (   mapping_wea                     ),
    .addra      (   mapping_addra                   ),
    .dina       (   mapping_dina                    ),

    .addrb      (   mapping_addrb                   ),
    .doutb      (   mapping_doutb                   )
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- icm_lookup_relative_addr --
assign icm_lookup_relative_addr = icm_mapping_lookup_head * ICM_SLOT_SIZE;

//-- mapping_wea --
//-- mapping_addra --
//-- mapping_dina --
assign mapping_wea = icm_mapping_set_valid;
assign mapping_addra = icm_mapping_set_head - (icm_base >> 12);
assign mapping_dina = icm_mapping_set_data;

//-- mapping_addrb --
assign mapping_addrb = icm_mapping_lookup_valid ? icm_lookup_relative_addr[63:12] : 'd0;

//-- icm_mapping_rsp_icm_addr --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        icm_mapping_rsp_icm_addr <= 'd0;
    end
    else if(icm_mapping_lookup_valid) begin
        icm_mapping_rsp_icm_addr <= icm_lookup_relative_addr;
    end
    else if(icm_mapping_rsp_valid) begin
        icm_mapping_rsp_icm_addr <= 'd0;
    end
    else begin
        icm_mapping_rsp_icm_addr <= icm_mapping_rsp_icm_addr;
    end
end

//-- icm_lookup_page_offset --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        icm_lookup_page_offset <= 'd0;        
    end
    else if (icm_mapping_lookup_valid) begin
        icm_lookup_page_offset <= icm_lookup_relative_addr[11:0];
    end
    else begin
        icm_lookup_page_offset <= 'd0;
    end
end

//-- icm_mapping_rsp_valid --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        icm_mapping_rsp_valid <= 'd0;
    end
    else begin
        icm_mapping_rsp_valid <= icm_mapping_lookup_valid;
    end
end

//-- icm_mapping_rsp_phy_addr --
assign icm_mapping_rsp_phy_addr = {mapping_doutb, icm_lookup_page_offset};

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule