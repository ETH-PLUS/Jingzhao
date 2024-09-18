/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       HWAccMRCtl_Thread_1
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
module HWAccMRCtl_Thread_1
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
    parameter               REQ_TAG_NUM             =       32,
    parameter               REQ_TAG_NUM_LOG         =       log2b(REQ_TAG_NUM - 1),
    parameter               REORDER_BUFFER_WIDTH    =       (ICM_CACHE_TYPE == `CACHE_TYPE_MTT) ? CACHE_ENTRY_WIDTH * 2 + COUNT_MAX_LOG : CACHE_ENTRY_WIDTH + COUNT_MAX_LOG 
)
(
	input 	wire 																								clk,
	input 	wire 																								rst,

	//Interface with SQMgt
    input   wire                                                                                                SQ_mr_req_valid,
    input   wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                               	SQ_mr_req_head,
    input   wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                                                               	SQ_mr_req_data,
    output  wire                                                                                                SQ_mr_req_ready,

    //INterface with RQMgt
    input   wire                                                                                                RQ_mr_req_valid,
    input   wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                               	RQ_mr_req_head,
    input   wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                                                               	RQ_mr_req_data,
    output  wire                                                                                                RQ_mr_req_ready,

    //Interface with RDMACore/ReqTransCore
    input   wire                                                                                                TX_REQ_mr_req_valid,
    input   wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                               	TX_REQ_mr_req_head,
    input   wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                                                               	TX_REQ_mr_req_data,
    output  wire                                                                                                TX_REQ_mr_req_ready,

    //Interface with RDMACore/ReqRecvCore
    input   wire                                                                                                RX_REQ_mr_req_valid,
    input   wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                               	RX_REQ_mr_req_head,
    input   wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                                                               	RX_REQ_mr_req_data,
    output  wire                                                                                                RX_REQ_mr_req_ready,

    //Interface with RDMACore/RespRecvCore
	input   wire                                                                                                RX_RESP_mr_req_valid,
    input   wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                               	RX_RESP_mr_req_head,
    input   wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                                                               	RX_RESP_mr_req_data,
    output  wire                                                                                                RX_RESP_mr_req_ready,

//Interface with HWAccMRCtl_Thread_2
    output  wire                                                                                                mr_req_valid,
    output  wire    [`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                                mr_req_head,
    output  wire    [`MR_CMD_DATA_WIDTH - 1 : 0]                                                                mr_req_data,
    input   wire                                                                                                mr_req_ready,

//Interface with TagQPNMappingTable
    output  wire                                                                                                tag_qpn_mapping_table_wen,
    output  wire    [`MAX_REQ_TAG_NUM_LOG - 1 : 0]                                                              tag_qpn_mapping_table_addr,
    output  wire    [`QP_NUM_LOG - 1 : 0]                                                                       tag_qpn_mapping_table_din
);

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     SQ_CHNL                 0
`define     RQ_CHNL                 1
`define     TX_REQ_CHNL             2
`define     RX_REQ_CHNL             3
`define     RX_RESP_CHNL            4

`define     REQ_TAG_OFFSET          REQ_TAG_NUM_LOG - 1 : 0
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg             [2:0]                           last_sch_chnl;

wire            [`MAX_REQ_TAG_NUM_LOG - 1 : 0]  req_tag;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg             [3:0]               cur_state;
reg             [3:0]               next_state;

parameter       [3:0]               IDLE_s      =   4'd1,
                                    SQ_s        =   4'd2,
                                    RQ_s        =   4'd3,
                                    TX_REQ_s    =   4'd4,
                                    RX_REQ_s    =   4'd5,
                                    RX_RESP_s   =   4'd6;

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
        IDLE_s:         if(last_sch_chnl == `RX_RESP_CHNL) begin
                            if(SQ_mr_req_valid) begin
                                next_state = SQ_s;
                            end
                            else if(RQ_mr_req_valid) begin
                                next_state = RQ_s;
                            end
                            else if(TX_REQ_mr_req_valid) begin
                                next_state = TX_REQ_s;
                            end
                            else if(RX_REQ_mr_req_valid) begin
                                next_state = RX_REQ_s;
                            end
                            else if(RX_RESP_mr_req_valid) begin
                                next_state = RX_RESP_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
                        end
                        else if(last_sch_chnl == `SQ_CHNL) begin
                            if(RQ_mr_req_valid) begin
                                next_state = RQ_s;
                            end
                            else if(TX_REQ_mr_req_valid) begin
                                next_state = TX_REQ_s;
                            end
                            else if(RX_REQ_mr_req_valid) begin
                                next_state = RX_REQ_s;
                            end
                            else if(RX_RESP_mr_req_valid) begin
                                next_state = RX_RESP_s;
                            end
                            else if(SQ_mr_req_valid) begin
                                next_state = SQ_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
                        end
                        else if(last_sch_chnl == `RQ_CHNL) begin
                            if(SQ_mr_req_valid) begin
                                next_state = SQ_s;
                            end
                            else if(RQ_mr_req_valid) begin
                                next_state = RQ_s;
                            end
                            else if(TX_REQ_mr_req_valid) begin
                                next_state = TX_REQ_s;
                            end
                            else if(RX_REQ_mr_req_valid) begin
                                next_state = RX_REQ_s;
                            end
                            else if(RX_RESP_mr_req_valid) begin
                                next_state = RX_RESP_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
                        end
                        else if(last_sch_chnl == `TX_REQ_CHNL) begin
                            if(RX_REQ_mr_req_valid) begin
                                next_state = RX_REQ_s;
                            end
                            else if(RX_RESP_mr_req_valid) begin
                                next_state = RX_RESP_s;
                            end
                            else if(SQ_mr_req_valid) begin
                                next_state = SQ_s;
                            end
                            else if(RQ_mr_req_valid) begin
                                next_state = RQ_s;
                            end
                            else if(TX_REQ_mr_req_valid) begin
                                next_state = TX_REQ_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
                        end
                        else if(last_sch_chnl == `RX_REQ_CHNL) begin
                            if(RX_RESP_mr_req_valid) begin
                                next_state = RX_RESP_s;
                            end
                            else if(SQ_mr_req_valid) begin
                                next_state = SQ_s;
                            end
                            else if(RQ_mr_req_valid) begin
                                next_state = RQ_s;
                            end
                            else if(TX_REQ_mr_req_valid) begin
                                next_state = TX_REQ_s;
                            end
                            else if(RX_REQ_mr_req_valid) begin
                                next_state = RX_REQ_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
                        end
                        else begin
                            next_state = IDLE_s;
                        end
        SQ_s:           if(mr_req_valid && mr_req_ready) begin
                            next_state = IDLE_s;
                        end
                        else begin
                            next_state = SQ_s;
                        end
        RQ_s:           if(mr_req_valid && mr_req_ready) begin
                            next_state = IDLE_s;
                        end
                        else begin
                            next_state = RQ_s;
                        end
        TX_REQ_s:       if(mr_req_valid && mr_req_ready) begin
                            next_state = IDLE_s;
                        end
                        else begin
                            next_state = TX_REQ_s;
                        end
        RX_REQ_s:       if(mr_req_valid && mr_req_ready) begin
                            next_state = IDLE_s;
                        end
                        else begin
                            next_state = RX_REQ_s;
                        end
        RX_RESP_s:      if(mr_req_valid && mr_req_ready) begin
                            next_state = IDLE_s;
                        end
                        else begin
                            next_state = RX_RESP_s;
                        end
        default:        next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- last_sch_chnl --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        last_sch_chnl <= `RX_RESP_CHNL;        
    end
    else if (cur_state == SQ_s && mr_req_ready) begin
        last_sch_chnl <= `SQ_CHNL;
    end
    else if (cur_state == RQ_s && mr_req_ready) begin
        last_sch_chnl <= `RQ_CHNL;
    end
    else if (cur_state == TX_REQ_s && mr_req_ready) begin
        last_sch_chnl <= `TX_REQ_CHNL;
    end
    else if (cur_state == RX_REQ_s && mr_req_ready) begin
        last_sch_chnl <= `RX_REQ_CHNL;
    end
    else if (cur_state == RX_RESP_s && mr_req_ready) begin
        last_sch_chnl <= `RX_RESP_CHNL;
    end
    else begin
        last_sch_chnl <= last_sch_chnl;
    end
end

//-- SQ_mr_req_ready --
assign SQ_mr_req_ready = (cur_state == SQ_s) ? mr_req_ready : 'd0;

//-- RQ_mr_req_ready --
assign RQ_mr_req_ready = (cur_state == RQ_s) ? mr_req_ready : 'd0;

//-- TX_REQ_mr_req_ready --
assign TX_REQ_mr_req_ready = (cur_state == TX_REQ_s) ? mr_req_ready : 'd0;

//-- RX_REQ_mr_req_ready --
assign RX_REQ_mr_req_ready = (cur_state == RX_REQ_s) ? mr_req_ready : 'd0;

//-- RX_RESP_mr_req_ready --
assign RX_RESP_mr_req_ready = (cur_state == RX_RESP_s) ? mr_req_ready : 'd0;

//-- req_tag --
assign req_tag = (cur_state == SQ_s) ? {'d0, 3'b000, SQ_mr_req_head[`REQ_TAG_OFFSET]} :
                (cur_state == RQ_s) ? {'d0, 3'b001, RQ_mr_req_head[`REQ_TAG_OFFSET]} : 
                (cur_state == TX_REQ_s) ? {'d0, 3'b010, TX_REQ_mr_req_head[`REQ_TAG_OFFSET]} : 
                (cur_state == RX_REQ_s) ? {'d0, 3'b011, RX_REQ_mr_req_head[`REQ_TAG_OFFSET]} :
                (cur_state == RX_RESP_s) ? {'d0, 3'b100, RX_RESP_mr_req_head[`REQ_TAG_OFFSET]} : 'd0;

//-- mr_req_valid --
//-- mr_req_head --
//-- mr_req_data --
assign mr_req_valid =  (cur_state == SQ_s) ? 'd1: 
                            (cur_state == RQ_s) ? 'd1: 
                            (cur_state == TX_REQ_s) ? 'd1 :
                            (cur_state == RX_REQ_s) ? 'd1 :
                            (cur_state == RX_RESP_s) ? 'd1 : 'd0;
assign mr_req_head =   (cur_state == SQ_s) ? {SQ_mr_req_head[`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : `MAX_REQ_TAG_NUM_LOG], req_tag} : 
                        (cur_state == RQ_s) ? {RQ_mr_req_head[`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : `MAX_REQ_TAG_NUM_LOG], req_tag} : 
                            (cur_state == TX_REQ_s) ? {TX_REQ_mr_req_head[`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : `MAX_REQ_TAG_NUM_LOG], req_tag} :
                            (cur_state == RX_REQ_s) ? {RX_REQ_mr_req_head[`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : `MAX_REQ_TAG_NUM_LOG], req_tag} :
                            (cur_state == RX_RESP_s) ? {RX_RESP_mr_req_head[`MR_CMD_HEAD_WIDTH + `MAX_REQ_TAG_NUM_LOG - 1 : `MAX_REQ_TAG_NUM_LOG], req_tag} : 'd0;
assign mr_req_data =   (cur_state == SQ_s) ? SQ_mr_req_data : 
                            (cur_state == RQ_s) ? RQ_mr_req_data :
                            (cur_state == TX_REQ_s) ? TX_REQ_mr_req_data :
                            (cur_state == RX_REQ_s) ? RX_REQ_mr_req_data :
                            (cur_state == RX_RESP_s) ? RX_RESP_mr_req_data : 'd0;

//-- tag_qpn_mapping_table_wen --
//-- tag_qpn_mapping_table_addr --
//-- tag_qpn_mapping_table_din --
assign tag_qpn_mapping_table_wen =  (cur_state == SQ_s || cur_state == RQ_s || cur_state == TX_REQ_s || cur_state == RX_REQ_s || cur_state == RX_RESP_s) ? 'd1 : 'd0;
assign tag_qpn_mapping_table_addr = req_tag;
assign tag_qpn_mapping_table_din =  (cur_state == SQ_s) ? SQ_mr_req_head[`QP_NUM_LOG + `MAX_REQ_TAG_NUM_LOG - 1 : `MAX_REQ_TAG_NUM_LOG] : 
                                    (cur_state == RQ_s) ? RQ_mr_req_head[`QP_NUM_LOG + `MAX_REQ_TAG_NUM_LOG - 1 : `MAX_REQ_TAG_NUM_LOG] : 
                                    (cur_state == TX_REQ_s) ? TX_REQ_mr_req_head[`QP_NUM_LOG + `MAX_REQ_TAG_NUM_LOG - 1 : `MAX_REQ_TAG_NUM_LOG] :
                                    (cur_state == RX_REQ_s) ? RX_REQ_mr_req_head[`QP_NUM_LOG + `MAX_REQ_TAG_NUM_LOG - 1 : `MAX_REQ_TAG_NUM_LOG] :
                                    (cur_state == RX_RESP_s) ? RX_RESP_mr_req_head[`QP_NUM_LOG + `MAX_REQ_TAG_NUM_LOG - 1 : `MAX_REQ_TAG_NUM_LOG] : 'd0;
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule