/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       SWAccCMCtl_Thread_1
Author:     YangFan
Function:   Demux CEU command to thread_2(QPC processing), thread_3(CQC processing), thread_4(EQC processing), thread_5(Cxt ICM Mapping).
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module SWAccCMCtl_Thread_1
(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with CEU
    input   wire                                                            ceu_req_valid,
    input   wire    [`CEU_CXT_HEAD_WIDTH - 1 : 0]                           ceu_req_head,
    input   wire                                                            ceu_req_last,
    input   wire    [`CEU_CXT_DATA_WIDTH - 1 : 0]                           ceu_req_data,
    output  wire                                                            ceu_req_ready,

//Interface with SWAccCMCtl_Thread_2
    output  wire                                                            qpc_req_valid,
    output  wire    [`CEU_CXT_HEAD_WIDTH - 1 : 0]                           qpc_req_head,
    output  wire                                                            qpc_req_last,
    output  wire    [`CEU_CXT_DATA_WIDTH - 1 : 0]                           qpc_req_data,
    input   wire                                                            qpc_req_ready,

//Interface with SWAccCMCtl_Thread_3
    output  wire                                                            cqc_req_valid,
    output  wire    [`CEU_CXT_HEAD_WIDTH - 1 : 0]                           cqc_req_head,
    output  wire                                                            cqc_req_last,
    output  wire    [`CEU_CXT_DATA_WIDTH - 1 : 0]                           cqc_req_data,
    input   wire                                                            cqc_req_ready,

//Interface with SWAccCMCtl_Thread_4
    output  wire                                                            eqc_req_valid,
    output  wire    [`CEU_CXT_HEAD_WIDTH - 1 : 0]                           eqc_req_head,
    output  wire                                                            eqc_req_last,
    output  wire    [`CEU_CXT_DATA_WIDTH - 1 : 0]                           eqc_req_data,
    input   wire                                                            eqc_req_ready,

//Interface with SWAccCMCtl_Thread_5
    output  wire                                                            mapping_req_valid,
    output  wire    [`CEU_CXT_HEAD_WIDTH - 1 : 0]                           mapping_req_head,
    output  wire                                                            mapping_req_last,
    output  wire    [`CEU_CXT_DATA_WIDTH - 1 : 0]                           mapping_req_data,
    input   wire                                                            mapping_req_ready

);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     CEU_CMD_TYPE_OFFSET                                 127:124
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                                            dispatch_req_valid;
wire    [`CEU_CXT_HEAD_WIDTH - 1 : 0]                           dispatch_req_head;
wire                                                            dispatch_req_last;
wire    [`CEU_CXT_DATA_WIDTH - 1 : 0]                           dispatch_req_data;
wire                                                            dispatch_req_ready;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
stream_fifo #(
    .TUSER_WIDTH        (`CEU_CXT_HEAD_WIDTH                ),
    .TDATA_WIDTH        (`CEU_CXT_DATA_WIDTH                )
)
ceu_req_st
(
    .clk                (clk                                ),
    .rst                (rst                                ),

    .axis_tvalid        (ceu_req_valid                      ),
    .axis_tlast         (ceu_req_last                       ), 
    .axis_tuser         (ceu_req_head                       ), 
    .axis_tdata         (ceu_req_data                       ), 
    .axis_tready        (ceu_req_ready                      ),
    .axis_tstart        (1'b0                               ),
    .axis_tkeep         ('d0                                ),
   
    .in_reg_tvalid      (dispatch_req_valid                 ),
    .in_reg_tlast       (dispatch_req_last                  ), 
    .in_reg_tuser       (dispatch_req_head                  ),
    .in_reg_tdata       (dispatch_req_data                  ),
    .in_reg_tkeep       (                                   ),
    .in_reg_tstart      (                                   ),
    .in_reg_tready      (dispatch_req_ready                 )
    /* -------output in_reg inteface{end}------- */
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg                 [2:0]               cur_state;
reg                 [2:0]               next_state;

parameter           [2:0]               IDLE_s      =   3'd1,
                                        QPC_s       =   3'd2,
                                        CQC_s       =   3'd3,
                                        EQC_s       =   3'd4,
                                        MAPPING_s   =   3'd5;

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
        IDLE_s:             if(dispatch_req_valid && (dispatch_req_head[`CEU_CMD_TYPE_OFFSET] == `RD_QP_CXT || dispatch_req_head[`CEU_CMD_TYPE_OFFSET] == `WR_QP_CXT)) begin
                                next_state = QPC_s;
                            end
                            else if(dispatch_req_valid && dispatch_req_head[`CEU_CMD_TYPE_OFFSET] == `WR_CQ_CXT) begin
                                next_state = CQC_s;
                            end
                            else if(dispatch_req_valid && dispatch_req_head[`CEU_CMD_TYPE_OFFSET] == `WR_EQ_CXT) begin
                                next_state = EQC_s;
                            end
                            else if(dispatch_req_valid && (dispatch_req_head[`CEU_CMD_TYPE_OFFSET] == `WR_ICMMAP_CXT || dispatch_req_head[`CEU_CMD_TYPE_OFFSET] == `MAP_ICM_CXT)) begin
                                next_state = MAPPING_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
        QPC_s:              next_state = (dispatch_req_last && dispatch_req_ready) ? IDLE_s : QPC_s;
        CQC_s:              next_state = (dispatch_req_last && dispatch_req_ready) ? IDLE_s : CQC_s;
        EQC_s:              next_state = (dispatch_req_last && dispatch_req_ready) ? IDLE_s : EQC_s;
        MAPPING_s:          next_state = (dispatch_req_last && dispatch_req_ready) ? IDLE_s : MAPPING_s;
        default:            next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
assign dispatch_req_ready = (cur_state == QPC_s) ? qpc_req_ready : 
                            (cur_state == CQC_s) ? cqc_req_ready :
                            (cur_state == EQC_s) ? eqc_req_ready : 
                            (cur_state == MAPPING_s) ? mapping_req_ready : 'd0;

assign qpc_req_valid = (cur_state == QPC_s) ? dispatch_req_valid : 'd0;
assign qpc_req_head = (cur_state == QPC_s) ? dispatch_req_head : 'd0;
assign qpc_req_last = (cur_state == QPC_s) ? dispatch_req_last : 'd0;
assign qpc_req_data = (cur_state == QPC_s) ? dispatch_req_data : 'd0;

assign cqc_req_valid = (cur_state == CQC_s) ? dispatch_req_valid : 'd0;
assign cqc_req_head = (cur_state == CQC_s) ? dispatch_req_head : 'd0;
assign cqc_req_last = (cur_state == CQC_s) ? dispatch_req_last : 'd0;
assign cqc_req_data = (cur_state == CQC_s) ? dispatch_req_data : 'd0;

assign eqc_req_valid = (cur_state == EQC_s) ? dispatch_req_valid : 'd0;
assign eqc_req_head = (cur_state == EQC_s) ? dispatch_req_head : 'd0;
assign eqc_req_last = (cur_state == EQC_s) ? dispatch_req_last : 'd0;
assign eqc_req_data = (cur_state == EQC_s) ? dispatch_req_data : 'd0;

assign mapping_req_valid = (cur_state == MAPPING_s) ? dispatch_req_valid : 'd0;
assign mapping_req_head = (cur_state == MAPPING_s) ? dispatch_req_head : 'd0;
assign mapping_req_last = (cur_state == MAPPING_s) ? dispatch_req_last : 'd0;
assign mapping_req_data = (cur_state == MAPPING_s) ? dispatch_req_data : 'd0;
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef  CEU_CMD_TYPE_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

`ifdef  ILA_ON
    ila_ceu_req     ila_cxt_req_inst(
        .clk (clk),

        .probe0(ceu_req_valid),
        .probe1(ceu_req_head),
        .probe2(ceu_req_data),
        .probe3(ceu_req_last),
        .probe4(ceu_req_ready),

        .probe5(dispatch_req_valid),
        .probe6(dispatch_req_head),
        .probe7(dispatch_req_data),
        .probe8(dispatch_req_last),
        .probe9(dispatch_req_ready) 
    );
`endif

endmodule