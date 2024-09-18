/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       SWAccCMCtl_Thread_4
Author:     YangFan
Function:   Handle EQC Wr Command from CEU.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/



/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module SWAccCMCtl_Thread_4 (
    input   wire                                                                                                clk,
    input   wire                                                                                                rst,

//Interface with SWAccCMCtl_Thread_0
    input   wire                                                                                                eqc_req_valid,
    input   wire    [`CEU_CXT_HEAD_WIDTH - 1 : 0]                                                               eqc_req_head,
    input   wire                                                                                                eqc_req_last,
    input   wire    [`CEU_CXT_DATA_WIDTH - 1 : 0]                                                               eqc_req_data,
    output  wire                                                                                                eqc_req_ready,

//Interface with EQCCache(ICMCache)
//Cache Set Req Interface
    output  wire                                                                                                        cache_set_req_valid,
    output  wire    [`REQ_TAG_NUM_LOG + `COUNT_MAX_LOG * 2 + `ICM_SPACE_ADDR_WIDTH + `PHY_SPACE_ADDR_WIDTH - 1 : 0]     cache_set_req_head,
    output  wire    [`CACHE_ENTRY_WIDTH_EQC - 1 : 0]                                                                    cache_set_req_data,
    input   wire                                                                                                        cache_set_req_ready,

//ICM Address Translation Interface
    output  wire                                                                                                icm_mapping_lookup_valid,
    output  wire    [log2b(`ICM_ENTRY_NUM_EQC - 1) - 1 : 0]                                                     icm_mapping_lookup_head,
    input   wire                                                                                                icm_mapping_lookup_ready,

    input   wire                                                                                                icm_mapping_rsp_valid,
    input   wire    [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                                                             icm_mapping_rsp_icm_addr,
    input   wire    [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                                                             icm_mapping_rsp_phy_addr,
    output  wire                                                                                                icm_mapping_rsp_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     CEU_CMD_OPCODE_OFFSET                                   123:120
`define     CEU_CMD_INDEX_OFFSET                                    95:64
`define     EQC_PIECE_NUM                                           2           //64B / 32B(256bit data width) 
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg             [3:0]                                                       eqc_wr_piece_count;

reg             [`CEU_CXT_HEAD_WIDTH - 1 : 0]                               eqc_req_head_diff;

reg             [`ICM_SPACE_ADDR_WIDTH - 1 : 0]                             icm_addr;
reg             [`PHY_SPACE_ADDR_WIDTH - 1 : 0]                             phy_addr;

wire            [`COUNT_MAX_LOG - 1 : 0]                                    count_max;
wire            [`COUNT_MAX_LOG - 1 : 0]                                    count_index;

wire            [`REQ_TAG_NUM_LOG - 1 : 0]                                  req_tag;

//EPC Info
reg                        [7:0]                wr_log_size;
reg                        [31:0]               wr_msix_interrupt;
reg                        [31:0]               wr_eq_pd;
reg                        [31:0]               wr_eq_lkey;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg         [2:0]               cur_state;
reg         [2:0]               next_state;

parameter   [2:0]               IDLE_s = 3'd1,
                                ADDR_REQ_s = 3'd2,
                                ADDR_RSP_s = 3'd3,
                                EQC_COLLECT_s = 3'd4,
                                CACHE_SET_s = 3'd5;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        cur_state <= IDLE_s;
    end
    else begin
        cur_state <= next_state;
    end
end

always @(*) begin
    case(cur_state)
        IDLE_s:             if(eqc_req_valid) begin
                                next_state = ADDR_REQ_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
        ADDR_REQ_s:         if(icm_mapping_lookup_valid && icm_mapping_lookup_ready) begin
                                next_state = ADDR_RSP_s;
                            end
                            else begin
                                next_state = ADDR_REQ_s;
                            end
        ADDR_RSP_s:         if(icm_mapping_rsp_valid) begin
                                if(eqc_req_valid && eqc_req_head_diff[`CEU_CMD_OPCODE_OFFSET] == `WR_CQ_ALL) begin
                                    next_state = EQC_COLLECT_s;
                                end
                                else begin
                                    next_state = IDLE_s;
                                end
                            end
                            else begin
                                next_state = ADDR_RSP_s;
                            end
        EQC_COLLECT_s:      if(eqc_wr_piece_count == `EQC_PIECE_NUM && eqc_req_valid && eqc_req_ready) begin
                                next_state = CACHE_SET_s;
                            end
                            else begin
                                next_state = EQC_COLLECT_s;
                            end
        CACHE_SET_s:        if(cache_set_req_valid && cache_set_req_ready) begin
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = CACHE_SET_s;
                            end
        default:            next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- Wr QPC Info --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        wr_log_size <= 'd0;
        wr_msix_interrupt <= 'd0;
        wr_eq_pd <= 'd0;
        wr_eq_lkey <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        wr_log_size <= 'd0;
        wr_msix_interrupt <= 'd0;
        wr_eq_pd <= 'd0;
        wr_eq_lkey <= 'd0;
    end
    else if(cur_state == EQC_COLLECT_s && eqc_req_valid) begin
        wr_log_size <= (eqc_wr_piece_count == 1) ? eqc_req_data[127:120] : wr_log_size;
        wr_msix_interrupt <= (eqc_wr_piece_count == 1) ? eqc_req_data[167:160] : wr_msix_interrupt;
        wr_eq_pd <= (eqc_wr_piece_count == 1) ? eqc_req_data[191:160] : wr_eq_pd;
        wr_eq_lkey <= (eqc_wr_piece_count == 1) ? eqc_req_data[223:192] : wr_eq_lkey;
    end
    else begin
        wr_log_size <= wr_log_size;
        wr_msix_interrupt <= wr_msix_interrupt;
        wr_eq_pd <= wr_eq_pd;
        wr_eq_lkey <= wr_eq_lkey;
    end
end

//-- count_max --
//-- count_index --
assign count_max = 'd1;     //Specific for QPC/EQC/CQC/MPT, 2 for MTT
assign count_index = 'd0;   //Specific for QPC/EQC/CQC/MPT, 0, 1 for MTT

//-- req_tag --
assign req_tag = 'd0;       //Specific for CEU request, RPCCore will use tag start from 1.

//-- eqc_wr_piece_count --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        eqc_wr_piece_count <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        eqc_wr_piece_count <= 'd0;
    end
    else if(cur_state == ADDR_RSP_s && next_state == EQC_COLLECT_s) begin
        eqc_wr_piece_count <= 'd1;
    end
    else if(cur_state == EQC_COLLECT_s && eqc_req_valid && eqc_req_ready) begin
        eqc_wr_piece_count <= eqc_wr_piece_count + 'd1;
    end
    else begin
        eqc_wr_piece_count <= eqc_wr_piece_count;
    end
end

//-- eqc_req_head_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        eqc_req_head_diff <= 'd0;
    end
    else if(cur_state == IDLE_s && eqc_req_valid) begin
        eqc_req_head_diff <= eqc_req_head;
    end
    else begin
        eqc_req_head_diff <= eqc_req_head_diff;
    end
end

//-- icm_addr --
//-- phy_addr --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        icm_addr <= 'd0;
        phy_addr <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        icm_addr <= 'd0;
        phy_addr <= 'd0;
    end
    else if(cur_state == ADDR_RSP_s && icm_mapping_rsp_valid) begin
        icm_addr <= icm_mapping_rsp_icm_addr;
        phy_addr <= icm_mapping_rsp_phy_addr;
    end
    else begin
        icm_addr <= icm_addr;
        phy_addr <= phy_addr;
    end
end

//-- icm_mapping_lookup_valid --
//-- icm_mapping_lookup_head --
assign icm_mapping_lookup_valid = (cur_state == ADDR_REQ_s) ? 'd1 : 'd0;
assign icm_mapping_lookup_head = (cur_state == ADDR_REQ_s) ? eqc_req_head_diff[`CEU_CMD_INDEX_OFFSET] : 'd0;  //Notice  CEU_CMD_INDEX_OFFSET is 32bit, may exceed actual index length, it does not matter

//-- icm_mapping_rsp_ready --
assign icm_mapping_rsp_ready = (cur_state == ADDR_RSP_s) ? 'd1 : 'd0;


//-- cache_set_req_valid --
//-- cache_set_req_head --
//-- cache_set_req_data --
assign cache_set_req_valid = (cur_state == CACHE_SET_s && eqc_wr_piece_count == `EQC_PIECE_NUM && eqc_req_valid) ? 'd1 : 'd0;
assign cache_set_req_head = (cur_state == CACHE_SET_s && eqc_wr_piece_count == `EQC_PIECE_NUM && eqc_req_valid) ? {phy_addr, icm_addr} : 'd0; 
assign cache_set_req_data = {wr_eq_lkey, wr_eq_pd, wr_msix_interrupt, 24'd0, wr_log_size};

//-- eqc_req_ready --
assign eqc_req_ready = (cur_state == EQC_COLLECT_s) ? 'd1 : 'd0;


//-- icm_mapping_rsp_ready --
assign icm_mapping_rsp_ready = (cur_state == ADDR_RSP_s) ? 'd1 : 'd0;

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef  CEU_CMD_OPCODE_OFFSET
`undef  EQC_PIECE_NUM
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule