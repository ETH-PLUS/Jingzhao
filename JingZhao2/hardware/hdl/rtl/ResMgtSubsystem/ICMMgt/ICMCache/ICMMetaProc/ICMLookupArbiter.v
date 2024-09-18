/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ICMLookupArbiter
Author:     YangFan
Function:   Schedule MR requests from different channels.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module ICMLookupArbiter
#(
    parameter           ICM_ENTRY_NUM       =       `ICM_ENTRY_NUM_MPT,
    parameter           ICM_ENTRY_NUM_LOG   =       log2b(ICM_ENTRY_NUM - 1)
)
(
	input 	wire 										    clk,
	input 	wire 										    rst,

    input   wire                                            chnl_0_lookup_valid,
    input   wire    [ICM_ENTRY_NUM_LOG - 1 : 0]             chnl_0_lookup_head,
    output  wire                                            chnl_0_lookup_ready,

    output  wire                                            chnl_0_rsp_valid,
    output  wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]         chnl_0_rsp_icm_addr,
    output  wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]         chnl_0_rsp_phy_addr,
    input   wire                                            chnl_0_rsp_ready,

    input   wire                                            chnl_1_lookup_valid,
    input   wire    [ICM_ENTRY_NUM_LOG - 1 : 0]             chnl_1_lookup_head,
    output  wire                                            chnl_1_lookup_ready,

    output  wire                                            chnl_1_rsp_valid,
    output  wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]         chnl_1_rsp_icm_addr,
    output  wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]         chnl_1_rsp_phy_addr,
    input   wire                                            chnl_1_rsp_ready,

    output  wire                                            lookup_valid,
    output  wire    [ICM_ENTRY_NUM_LOG - 1 : 0]             lookup_head,

    input   wire                                            rsp_valid,
    input   wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]         rsp_icm_addr,
    input   wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]         rsp_phy_addr
);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define             CHNL_0              0
`define             CHNL_1              1
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg                                            last_sch_chnl;

reg    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]         chnl_0_rsp_icm_addr_diff;
reg    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]         chnl_0_rsp_phy_addr_diff;

reg    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]         chnl_1_rsp_icm_addr_diff;
reg    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]         chnl_1_rsp_phy_addr_diff;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg         [2:0]               cur_state;
reg         [2:0]               next_state;

parameter   [2:0]               IDLE_s          =   3'd1,
                                CHNL_0_REQ_s    =   3'd2,
                                CHNL_0_RSP_s    =   3'd3,
                                CHNL_1_REQ_s    =   3'd4,
                                CHNL_1_RSP_s    =   3'd5;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        cur_state <= IDLE_s;        
    end
    else begin
        cur_state <= next_state;
    end
end

always @(*) begin
    case(cur_state)
        IDLE_s:         if(last_sch_chnl == `CHNL_0) begin
                            if(chnl_1_lookup_valid) begin
                                next_state = CHNL_1_REQ_s;
                            end
                            else if(chnl_0_lookup_valid) begin
                                next_state = CHNL_0_REQ_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
                        end
                        else if(last_sch_chnl == `CHNL_1) begin
                            if(chnl_0_lookup_valid) begin
                                next_state = CHNL_0_REQ_s;
                            end
                            else if(chnl_1_lookup_valid) begin
                                next_state = CHNL_1_REQ_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
                        end
                        else begin
                            next_state = IDLE_s;
                        end
        CHNL_0_REQ_s:   next_state = CHNL_0_RSP_s;
        CHNL_0_RSP_s:   if(chnl_0_rsp_valid && chnl_0_rsp_ready) begin
                            next_state = IDLE_s;
                        end
                        else begin
                            next_state = CHNL_0_RSP_s;
                        end
        CHNL_1_REQ_s:   next_state = CHNL_1_RSP_s;
        CHNL_1_RSP_s:   if(chnl_1_rsp_valid && chnl_1_rsp_ready) begin
                            next_state = IDLE_s;
                        end
                        else begin
                            next_state = CHNL_1_RSP_s;
                        end
        default:        next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- chnl_0_lookup_ready --
assign chnl_0_lookup_ready = (cur_state == CHNL_0_REQ_s) ? 'd1 : 'd0;

//-- chnl_1_lookup_ready --
assign chnl_1_lookup_ready = (cur_state == CHNL_1_REQ_s) ? 'd1 : 'd0;

//-- chnl_0_rsp_valid --
//-- chnl_0_rsp_icm_addr --
//-- chnl_0_rsp_phy_addr --
assign chnl_0_rsp_valid = (cur_state == CHNL_0_RSP_s) ? 'd1 : 'd0;
assign chnl_0_rsp_icm_addr = (cur_state == CHNL_0_RSP_s && rsp_valid) ? rsp_icm_addr : chnl_0_rsp_icm_addr_diff; 
assign chnl_0_rsp_phy_addr = (cur_state == CHNL_0_RSP_s && rsp_valid) ? rsp_phy_addr : chnl_0_rsp_phy_addr_diff; 

//-- chnl_1_rsp_valid --
//-- chnl_1_rsp_icm_addr --
//-- chnl_1_rsp_phy_addr --
assign chnl_1_rsp_valid = (cur_state == CHNL_1_RSP_s) ? 'd1 : 'd0;
assign chnl_1_rsp_icm_addr = (cur_state == CHNL_1_RSP_s && rsp_valid) ? rsp_icm_addr : chnl_1_rsp_icm_addr_diff; 
assign chnl_1_rsp_phy_addr = (cur_state == CHNL_1_RSP_s && rsp_valid) ? rsp_phy_addr : chnl_1_rsp_phy_addr_diff;

//-- lookup_valid --
//-- lookup_head --
assign lookup_valid = (cur_state == CHNL_0_REQ_s || cur_state == CHNL_1_REQ_s) ? 'd1 : 'd0;
assign lookup_head = (cur_state == CHNL_0_REQ_s) ? chnl_0_lookup_head :
                    (cur_state == CHNL_1_REQ_s) ? chnl_1_lookup_head : 'd0;

//-- chnl_0_rsp_icm_addr_diff --
//-- chnl_0_rsp_phy_addr_diff --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        chnl_0_rsp_icm_addr_diff <= 'd0;
        chnl_0_rsp_phy_addr_diff <= 'd0;
    end
    else if (cur_state == CHNL_0_RSP_s) begin
        chnl_0_rsp_icm_addr_diff <= rsp_valid ? rsp_icm_addr : chnl_0_rsp_icm_addr_diff;
        chnl_0_rsp_phy_addr_diff <= rsp_valid ? rsp_phy_addr : chnl_0_rsp_phy_addr_diff;
    end
    else begin
        chnl_0_rsp_icm_addr_diff <= chnl_0_rsp_icm_addr_diff;
        chnl_0_rsp_phy_addr_diff <= chnl_0_rsp_phy_addr_diff;        
    end
end

//-- chnl_1_rsp_icm_addr_diff --
//-- chnl_1_rsp_phy_addr_diff --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        chnl_1_rsp_icm_addr_diff <= 'd0;
        chnl_1_rsp_phy_addr_diff <= 'd0;
    end
    else if (cur_state == CHNL_1_RSP_s) begin
        chnl_1_rsp_icm_addr_diff <= rsp_valid ? rsp_icm_addr : chnl_1_rsp_icm_addr_diff;
        chnl_1_rsp_phy_addr_diff <= rsp_valid ? rsp_phy_addr : chnl_1_rsp_phy_addr_diff;
    end
    else begin
        chnl_1_rsp_icm_addr_diff <= chnl_1_rsp_icm_addr_diff;
        chnl_1_rsp_phy_addr_diff <= chnl_1_rsp_phy_addr_diff;        
    end
end

//-- last_sch_chnl --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        last_sch_chnl <= `CHNL_0;        
    end
    else if (cur_state == CHNL_0_RSP_s && chnl_0_rsp_valid && chnl_0_rsp_ready) begin
        last_sch_chnl <= `CHNL_0;
    end
    else if (cur_state == CHNL_1_RSP_s && chnl_1_rsp_valid && chnl_1_rsp_ready) begin
        last_sch_chnl <= `CHNL_1;
    end
    else begin
        last_sch_chnl <= last_sch_chnl;
    end
end
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule