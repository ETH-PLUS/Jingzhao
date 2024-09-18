/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       HWAccCMCtl_Thread_4
Author:     YangFan
Function:   Deal with CQC Rsp and Read EQC.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module HWAccCMCtl_Thread_4
#(
    parameter               ICM_CACHE_TYPE          =       `CACHE_TYPE_MTT,
    parameter               ICM_PAGE_NUM            =       `ICM_PAGE_NUM_MTT,
    parameter               ICM_PAGE_NUM_LOG        =       log2b(ICM_PAGE_NUM - 1),
    parameter               ICM_ENTRY_NUM           =       `ICM_ENTRY_NUM_MTT,
    parameter               ICM_ENTRY_NUM_LOG       =       log2b(ICM_ENTRY_NUM - 1),
    parameter               ICM_SLOT_SIZE           =       `ICM_SLOT_SIZE_MTT,
    parameter               ICM_ADDR_WIDTH          =       64,

    parameter               CACHE_ADDR_WIDTH        =       ICM_ADDR_WIDTH,
    parameter               CACHE_ENTRY_WIDTH       =       256,
    parameter               CACHE_SET_NUM           =       1024,
    parameter               CACHE_SET_NUM_LOG       =       log2b(CACHE_SET_NUM - 1),
    parameter               CACHE_OFFSET_WIDTH      =       log2b(CACHE_ENTRY_WIDTH / 8 - 1),
    parameter               CACHE_TAG_WIDTH         =       CACHE_ADDR_WIDTH - CACHE_OFFSET_WIDTH - CACHE_SET_NUM_LOG,
    parameter               PHYSICAL_ADDR_WIDTH     =       64,
    parameter               COUNT_MAX               =       2,
    parameter               COUNT_MAX_LOG           =       log2b(COUNT_MAX - 1) + 1,
    parameter               REQ_TAG_NUM             =       64,
    parameter               REQ_TAG_NUM_LOG         =       log2b(REQ_TAG_NUM - 1),
    parameter               REORDER_BUFFER_WIDTH    =       (ICM_CACHE_TYPE == `CACHE_TYPE_MTT) ? CACHE_ENTRY_WIDTH * 2 + COUNT_MAX_LOG : CACHE_ENTRY_WIDTH + COUNT_MAX_LOG,

    parameter               CQN_NUM                 =       `ICM_ENTRY_NUM_CQC,
    parameter               CQN_NUM_LOG             =       log2b(CQN_NUM - 1)
)
(
    input   wire                                                                                                clk,
    input   wire                                                                                                rst,

//Interface with CQCCache
    input   wire                                                                                                cqc_get_rsp_valid,
    input   wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   cqc_get_rsp_head,
    input   wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                 cqc_get_rsp_data,
    output  wire                                                                                                cqc_get_rsp_ready,

//Mapping Lookup Interface
    output  wire                                                                                                icm_mapping_lookup_valid,
    output  wire    [ICM_ENTRY_NUM_LOG - 1 : 0]                                                                 icm_mapping_lookup_head,
    input   wire                                                                                                icm_mapping_lookup_ready,

    input   wire                                                                                                icm_mapping_rsp_valid,
    input   wire    [ICM_ADDR_WIDTH - 1 : 0]                                                                    icm_mapping_rsp_icm_addr,
    input   wire    [PHYSICAL_ADDR_WIDTH - 1 : 0]                                                               icm_mapping_rsp_phy_addr,
    output  wire                                                                                                icm_mapping_rsp_ready,

//Interface with CQCStagedBuffer
    output  wire                                                                                                cqc_buffer_wen,
    output  wire    [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                              cqc_buffer_addr,
    output  wire    [`CACHE_ENTRY_WIDTH_CQC - 1 : 0]                                                            cqc_buffer_din,

//Interface with EQCCache
    output  wire                                                                                                eqc_get_req_valid,
    output  wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   eqc_get_req_head,
    input   wire                                                                                                eqc_get_req_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     CXT_CMD_TAG_OFFSET      39:32
`define     COMP_EQN_OFFSET         63:32   

/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]       cqc_get_rsp_head_diff;
reg    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                  cqc_get_rsp_data_diff;

wire   [COUNT_MAX_LOG - 1 : 0]                                                                      count_total;
wire   [COUNT_MAX_LOG - 1 : 0]                                                                      count_index;

wire    [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                              req_tag;
reg    [PHYSICAL_ADDR_WIDTH - 1 : 0]                                                                phy_addr;
reg    [ICM_ADDR_WIDTH - 1 : 0]                                                                   icm_addr;

wire    [CQN_NUM_LOG - 1 : 0]                                                                       eqn;

wire    [2:0]                                                                                       chnl_index;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg             [2:0]               cur_state;
reg             [2:0]               next_state;

parameter       [2:0]               IDLE_s = 3'd1,
                                    ADDR_REQ_s = 3'd2,
                                    ADDR_RSP_s = 3'd3,
                                    EQC_REQ_s = 3'd4;

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
        IDLE_s:             if(cqc_get_rsp_valid) begin
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
                                next_state = EQC_REQ_s;
                            end
                            else begin
                                next_state = ADDR_RSP_s;
                            end
        EQC_REQ_s:          if(eqc_get_req_valid && eqc_get_req_valid) begin
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = EQC_REQ_s;
                            end
        default:            next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- cqc_get_rsp_head_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        cqc_get_rsp_head_diff <= 'd0;
        cqc_get_rsp_data_diff <= 'd0;
    end
    else if(cur_state == IDLE_s && cqc_get_rsp_valid) begin
        cqc_get_rsp_head_diff <= cqc_get_rsp_head;
        cqc_get_rsp_data_diff <= cqc_get_rsp_data;
    end
    else begin
        cqc_get_rsp_head_diff <= cqc_get_rsp_head_diff;
        cqc_get_rsp_data_diff <= cqc_get_rsp_data_diff;
    end
end

//-- chnl_index --
assign chnl_index = req_tag[7:5];

//-- count_total --
//-- count_index --
assign count_total = cqc_get_rsp_head_diff[COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : COUNT_MAX_LOG + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH];
assign count_index = cqc_get_rsp_head_diff[COUNT_MAX_LOG + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 :  `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH];
assign req_tag = cqc_get_rsp_head_diff[`MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH];

//-- req_tag --
//-- phy_addr --
//-- icm_addr --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        phy_addr <= 'd0;
        icm_addr <= 'd0;
    end
    else if (cur_state == ADDR_RSP_s && icm_mapping_rsp_valid) begin
        phy_addr <= icm_mapping_rsp_phy_addr;
        icm_addr <= icm_mapping_rsp_icm_addr;
    end
    else begin
        phy_addr <= phy_addr;
        icm_addr <= icm_addr;
    end
end

//-- eqn -- 
assign eqn = (cur_state == ADDR_REQ_s) ? cqc_get_rsp_data_diff[`COMP_EQN_OFFSET] : 'd0;

//-- icm_mapping_lookup_valid --
//-- icm_mapping_lookup_head --
assign icm_mapping_lookup_valid = (cur_state == ADDR_REQ_s) ? 'd1 : 'd0;
assign icm_mapping_lookup_head = (cur_state == ADDR_REQ_s) ? eqn : 'd0;

//-- icm_mapping_rsp_ready --
assign icm_mapping_rsp_ready = (cur_state == ADDR_RSP_s) ? 'd1 : 'd0;

//-- cqc_buffer_wen --
//-- cqc_buffer_addr --
//-- cqc_buffer_din --
assign cqc_buffer_wen = (cur_state == EQC_REQ_s) ? 'd1 : 'd0;
assign cqc_buffer_addr = (cur_state == EQC_REQ_s) ? req_tag : 'd0;
assign cqc_buffer_din = (cur_state == EQC_REQ_s) ? cqc_get_rsp_data_diff : 'd0;

//Interface with EQCCache
assign eqc_get_req_valid = (cur_state == EQC_REQ_s) ? 'd1 : 'd0;
assign eqc_get_req_head = (cur_state == EQC_REQ_s) ? {count_total, count_index, req_tag, phy_addr, icm_addr} : 'd0;

//== cqc_get_rsp_ready --
assign cqc_get_rsp_ready = (cur_state == IDLE_s);
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef      CXT_CMD_TAG_OFFSET
`undef      COMP_EQN_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

`ifdef ILA_ON

ila_hw_acc_cm_thread_4 ila_hw_acc_cm_thread_4_inst(
    .clk(clk),

    .probe0(cqc_get_rsp_valid),
    .probe1(cqc_get_rsp_head),
    .probe2(cqc_get_rsp_data),
    .probe3(cqc_get_rsp_ready),

    .probe4(icm_mapping_lookup_valid),
    .probe5(icm_mapping_lookup_head),
    .probe6(icm_mapping_lookup_ready),

    .probe7(icm_mapping_rsp_valid),
    .probe8(icm_mapping_rsp_icm_addr),
    .probe9(icm_mapping_rsp_phy_addr),
    .probe10(icm_mapping_rsp_ready),

    .probe11(cqc_buffer_wen),
    .probe12(cqc_buffer_addr),
    .probe13(cqc_buffer_din),

    .probe14(eqc_get_req_valid),
    .probe15(eqc_get_req_head),
    .probe16(eqc_get_req_ready)
);
`endif

endmodule