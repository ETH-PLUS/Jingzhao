/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       HWAccCMCtl_Thread_3
Author:     YangFan
Function:   Deal with QPC Rsp and Read CQC.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module HWAccCMCtl_Thread_3
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
    parameter               REQ_TAG_NUM             =       256,
    parameter               REQ_TAG_NUM_LOG         =       log2b(REQ_TAG_NUM - 1),
    parameter               REORDER_BUFFER_WIDTH    =       (ICM_CACHE_TYPE == `CACHE_TYPE_MTT) ? CACHE_ENTRY_WIDTH * 2 + COUNT_MAX_LOG : CACHE_ENTRY_WIDTH + COUNT_MAX_LOG,

    parameter               CQN_NUM                 =       `ICM_ENTRY_NUM_CQC,
    parameter               CQN_NUM_LOG             =       log2b(CQN_NUM - 1)
)
(
    input   wire                                                                                                clk,
    input   wire                                                                                                rst,

//Interface with QPCCache
    input   wire                                                                                                qpc_get_rsp_valid,
    input   wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   qpc_get_rsp_head,
    input   wire    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                 qpc_get_rsp_data,
    output  wire                                                                                                qpc_get_rsp_ready,

//Mapping Lookup Interface
    output  wire                                                                                                icm_mapping_lookup_valid,
    output  wire    [ICM_ENTRY_NUM_LOG - 1 : 0]                                                                 icm_mapping_lookup_head,
    input   wire                                                                                                icm_mapping_lookup_ready,

    input   wire                                                                                                icm_mapping_rsp_valid,
    input   wire    [ICM_ADDR_WIDTH - 1 : 0]                                                                    icm_mapping_rsp_icm_addr,
    input   wire    [PHYSICAL_ADDR_WIDTH - 1 : 0]                                                               icm_mapping_rsp_phy_addr,
    output  wire                                                                                                icm_mapping_rsp_ready,

//Interface with QPCStagedBuffer
    output  wire                                                                                                qpc_buffer_wen,
    output  wire    [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                              qpc_buffer_addr,
    output  wire    [`CACHE_ENTRY_WIDTH_QPC - 1 : 0]                                                            qpc_buffer_din,

//Interface with CQCCache
    output  wire                                                                                                cqc_get_req_valid,
    output  wire    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]   cqc_get_req_head,
    input   wire                                                                                                cqc_get_req_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     CQN_SEND_OFFSET         79:64     
`define     CQN_RECV_OFFSET         95:80

`define     SQ_CHNL                 0
`define     TX_REQ_CHNL             1
`define     RX_REQ_CHNL             2
`define     RX_RESP_CHNL            3
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg    [COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : 0]       qpc_get_rsp_head_diff;
reg    [CACHE_ENTRY_WIDTH - 1 : 0]                                                                  qpc_get_rsp_data_diff;

wire   [COUNT_MAX_LOG - 1 : 0]                                                                      count_total;
wire   [COUNT_MAX_LOG - 1 : 0]                                                                      count_index;
wire   [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                               req_tag;

reg    [PHYSICAL_ADDR_WIDTH - 1 : 0]                                                                phy_addr;
reg    [ICM_ADDR_WIDTH - 1 : 0]                                                                     icm_addr;

wire    [CQN_NUM_LOG - 1 : 0]                                                                       cqn;

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
                                    CQC_REQ_s = 3'd4;

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
        IDLE_s:             if(qpc_get_rsp_valid) begin
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
                                next_state = CQC_REQ_s;
                            end
                            else begin
                                next_state = ADDR_RSP_s;
                            end
        CQC_REQ_s:          if(cqc_get_req_valid && cqc_get_req_valid) begin
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = CQC_REQ_s;
                            end
        default:            next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- qpc_get_rsp_head_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qpc_get_rsp_head_diff <= 'd0;
        qpc_get_rsp_data_diff <= 'd0;
    end
    else if(cur_state == IDLE_s && qpc_get_rsp_valid) begin
        qpc_get_rsp_head_diff <= qpc_get_rsp_head;
        qpc_get_rsp_data_diff <= qpc_get_rsp_data;
    end
    else begin
        qpc_get_rsp_head_diff <= qpc_get_rsp_head_diff;
        qpc_get_rsp_data_diff <= qpc_get_rsp_data_diff;
    end
end

//-- chnl_index --
assign chnl_index = req_tag[REQ_TAG_NUM_LOG - 1 : REQ_TAG_NUM_LOG - 2];         //HW has 4 chnls

//-- count_total --
//-- count_index --
//-- req_tag --
assign count_total = qpc_get_rsp_head_diff[COUNT_MAX_LOG * 2 + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : COUNT_MAX_LOG + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH];
assign count_index = qpc_get_rsp_head_diff[COUNT_MAX_LOG + `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 :  `MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH];
assign req_tag = qpc_get_rsp_head_diff[`MAX_REQ_TAG_NUM_LOG + PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH - 1 : PHYSICAL_ADDR_WIDTH + ICM_ADDR_WIDTH];

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

//-- cqn --     //Decide whether to require CQN-Send or CQN-Recv
assign cqn = (cur_state == ADDR_REQ_s && chnl_index == `SQ_CHNL) ? qpc_get_rsp_data_diff[`CQN_SEND_OFFSET] : 
             (cur_state == ADDR_REQ_s && chnl_index == `TX_REQ_CHNL) ? qpc_get_rsp_data_diff[`CQN_SEND_OFFSET] : 
             (cur_state == ADDR_REQ_s && chnl_index == `RX_REQ_CHNL) ? qpc_get_rsp_data_diff[`CQN_RECV_OFFSET] : 
             (cur_state == ADDR_REQ_s && chnl_index == `RX_RESP_CHNL) ? qpc_get_rsp_data_diff[`CQN_SEND_OFFSET] : 'd0;

//-- icm_mapping_lookup_valid --
//-- icm_mapping_lookup_head --
assign icm_mapping_lookup_valid = (cur_state == ADDR_REQ_s) ? 'd1 : 'd0;
assign icm_mapping_lookup_head = (cur_state == ADDR_REQ_s) ? cqn : 'd0;

//-- icm_mapping_rsp_ready --
assign icm_mapping_rsp_ready = (cur_state == ADDR_RSP_s) ? 'd1 : 'd0;
//-- qpc_buffer_wen --
//-- qpc_buffer_addr --
//-- qpc_buffer_din --
assign qpc_buffer_wen = (cur_state == CQC_REQ_s) ? 'd1 : 'd0;
assign qpc_buffer_addr = (cur_state == CQC_REQ_s) ? req_tag : 'd0;
assign qpc_buffer_din = (cur_state == CQC_REQ_s) ? qpc_get_rsp_data_diff : 'd0;

//-- cqc_get_req_valid --
//-- cqc_get_req_head --
assign cqc_get_req_valid = (cur_state == CQC_REQ_s) ? 'd1 : 'd0;
assign cqc_get_req_head = (cur_state == CQC_REQ_s) ? {count_total, count_index, req_tag, phy_addr, icm_addr} : 'd0;

//-- qpc_get_rsp_ready --
assign qpc_get_rsp_ready = (cur_state == IDLE_s);
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef  CQN_SEND_OFFSET
`undef  CQN_RECV_OFFSET

`undef  SQ_CHNL        
`undef  TX_REQ_CHNL    
`undef  RX_REQ_CHNL    
`undef  RX_RESP_CHNL   
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/
`ifdef ILA_ON

ila_hw_acc_cm_thread_3 ila_hw_acc_cm_thread_3_inst(
    .clk(clk),

    .probe0(qpc_get_rsp_valid),
    .probe1(qpc_get_rsp_head),
    .probe2(qpc_get_rsp_data),
    .probe3(qpc_get_rsp_ready),

    .probe4(icm_mapping_lookup_valid),
    .probe5(icm_mapping_lookup_head),
    .probe6(icm_mapping_lookup_ready),

    .probe7(icm_mapping_rsp_valid),
    .probe8(icm_mapping_rsp_icm_addr),
    .probe9(icm_mapping_rsp_phy_addr),
    .probe10(icm_mapping_rsp_ready),

    .probe11(qpc_buffer_wen),
    .probe12(qpc_buffer_addr),
    .probe13(qpc_buffer_din),

    .probe14(cqc_get_req_valid),
    .probe15(cqc_get_req_head),
    .probe16(cqc_get_req_ready)
);
`endif

endmodule