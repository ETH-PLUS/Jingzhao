/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       CQMgt
Author:     YangFan
Function:   1.Manage CQ.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module CQMgt
(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with ReqTransCore
    input   wire                                                            TX_REQ_cq_req_valid,
    input   wire    [`CQ_REQ_HEAD_WIDTH - 1 : 0]                            TX_REQ_cq_req_head,
    output  wire                                                            TX_REQ_cq_req_ready,
     
    output  wire                                                            TX_REQ_cq_resp_valid,
    output  wire    [`CQ_RESP_HEAD_WIDTH - 1 : 0]                           TX_REQ_cq_resp_head,
    input   wire                                                            TX_REQ_cq_resp_ready,

//Interface with ReqRecvCore
    input   wire                                                            RX_REQ_cq_req_valid,
    input   wire    [`CQ_REQ_HEAD_WIDTH - 1 : 0]                            RX_REQ_cq_req_head,
    output  wire                                                            RX_REQ_cq_req_ready,
     
    output  wire                                                            RX_REQ_cq_resp_valid,
    output  wire    [`CQ_RESP_HEAD_WIDTH - 1 : 0]                           RX_REQ_cq_resp_head,
    input   wire                                                            RX_REQ_cq_resp_ready,

//Interface with RespRecvCore
    input   wire                                                            RX_RESP_cq_req_valid,
    input   wire    [`CQ_REQ_HEAD_WIDTH - 1 : 0]                            RX_RESP_cq_req_head,
    output  wire                                                            RX_RESP_cq_req_ready,
     
    output  wire                                                            RX_RESP_cq_resp_valid,
    output  wire    [`CQ_RESP_HEAD_WIDTH - 1 : 0]                           RX_RESP_cq_resp_head,
    input   wire                                                            RX_RESP_cq_resp_ready
);

/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define         CQN_OFFSET              23:0
`define         CQ_LENGTH_OFFSET        63:32

`define         CHNL_TX_REQ             0
`define         CHNL_RX_REQ             1
`define         CHNL_RX_RESP            2
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire            [0:0]                                                       cq_offset_record_wea;
wire            [`CQ_NUM_LOG - 1 : 0]                                       cq_offset_record_addra;
wire            [23:0]                                                      cq_offset_record_dina;

wire            [`CQ_NUM_LOG - 1 : 0]                                       cq_offset_record_addrb;
wire            [23:0]                                                      cq_offset_record_doutb;

reg             [2:0]                                                       last_sch;

reg             [`CQ_NUM_LOG - 1 : 0]                                       cqn;
reg             [31:0]                                                      cq_length;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
SRAM_SDP_Template #(
    .RAM_WIDTH      (   24                                      ),
    .RAM_DEPTH      (   `CQ_NUM                                 )
)
CQOffsetRecordTable
(
    .clk            (   clk                                     ),
    .rst            (   rst                                     ),

    .wea            (   cq_offset_record_wea                    ),
    .addra          (   cq_offset_record_addra                  ),
    .dina           (   cq_offset_record_dina                   ),

    .addrb          (   cq_offset_record_addrb                  ),
    .doutb          (   cq_offset_record_doutb                  )
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg             [2:0]                   cur_state;
reg             [2:0]                   next_state;

parameter       IDLE_s      =   3'd1,
                TX_REQ_s    =   3'd2,
                RX_REQ_s    =   3'd3,
                RX_RESP_s   =   3'd4;

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
        IDLE_s:             if(last_sch == `CHNL_TX_REQ) begin
                                if(RX_REQ_cq_req_valid) begin
                                    next_state = RX_REQ_s;
                                end
                                else if(RX_RESP_cq_req_valid) begin
                                    next_state = RX_RESP_s;
                                end
                                else if(TX_REQ_cq_req_valid) begin
                                    next_state = TX_REQ_s;
                                end
                                else begin
                                    next_state = IDLE_s;
                                end
                            end
                            else if(last_sch == `CHNL_RX_REQ) begin
                                if(RX_RESP_cq_req_valid) begin
                                    next_state = RX_RESP_s;
                                end
                                else if(TX_REQ_cq_req_valid) begin
                                    next_state = TX_REQ_s;
                                end
                                else if(RX_REQ_cq_req_valid) begin
                                    next_state = RX_REQ_s;
                                end
                                else begin
                                    next_state = IDLE_s;
                                end
                            end
                            else if(last_sch == `CHNL_RX_RESP) begin
                                if(TX_REQ_cq_req_valid) begin
                                    next_state = TX_REQ_s;
                                end
                                else if(RX_REQ_cq_req_valid) begin
                                    next_state = RX_REQ_s;
                                end
                                else if(RX_RESP_cq_req_valid) begin
                                    next_state = RX_RESP_s;
                                end
                                else begin
                                    next_state = IDLE_s;
                                end
                            end
                            else begin
                                next_state = IDLE_s;
                            end
        TX_REQ_s:           if(TX_REQ_cq_resp_ready) begin
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = TX_REQ_s;
                            end
        RX_REQ_s:           if(RX_REQ_cq_resp_ready) begin
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = RX_REQ_s;
                            end
        RX_RESP_s:          if(RX_RESP_cq_resp_ready) begin
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = RX_RESP_s;
                            end
        default:            next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- cqn --
//-- cq_length --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cqn <= 'd0; 
        cq_length <= 'd0;       
    end
    else if (cur_state == IDLE_s && next_state == TX_REQ_s) begin
        cqn <= TX_REQ_cq_req_head[`CQN_OFFSET];
        cq_length <= TX_REQ_cq_req_head[`CQ_LENGTH_OFFSET];
    end
    else if (cur_state == IDLE_s && next_state == RX_REQ_s) begin
        cqn <= RX_REQ_cq_req_head[`CQN_OFFSET];
        cq_length <= RX_REQ_cq_req_head[`CQ_LENGTH_OFFSET];
    end
    else if (cur_state == IDLE_s && next_state == RX_RESP_s) begin
        cqn <= RX_RESP_cq_req_head[`CQN_OFFSET];
        cq_length <= RX_RESP_cq_req_head[`CQ_LENGTH_OFFSET];
    end
    else begin
        cqn <= cqn;
        cq_length <= cq_length;
    end
end

//-- last_sch --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        last_sch <= 'd0;        
    end
    else if (cur_state == TX_REQ_s && TX_REQ_cq_resp_ready) begin
        last_sch <= `CHNL_TX_REQ;
    end
    else if (cur_state == RX_REQ_s && RX_REQ_cq_resp_ready) begin
        last_sch <= `CHNL_RX_REQ;
    end
    else if (cur_state == RX_RESP_s && RX_RESP_cq_resp_ready) begin
        last_sch <= `CHNL_RX_RESP;
    end
    else begin
        last_sch <= last_sch;
    end
end

//-- cq_offset_record_wea --
//-- cq_offset_record_addra --
//-- cq_offset_record_dina --
assign cq_offset_record_wea =   (cur_state == TX_REQ_s && TX_REQ_cq_resp_ready) ? 'd1 : 
                                (cur_state == RX_REQ_s && RX_REQ_cq_resp_ready) ? 'd1 : 
                                (cur_state == RX_RESP_s && RX_RESP_cq_resp_ready) ? 'd1 : 'd0;
assign cq_offset_record_addra = (cur_state == TX_REQ_s && TX_REQ_cq_resp_ready) ? cqn :
                                (cur_state == RX_REQ_s && RX_REQ_cq_resp_ready) ? cqn : 
                                (cur_state == RX_RESP_s && RX_RESP_cq_resp_ready) ? cqn : 'd0;
assign cq_offset_record_dina =  (cur_state == TX_REQ_s && TX_REQ_cq_resp_ready)? (cq_offset_record_doutb + `CQE_LENGTH == cq_length ? 'd0 : cq_offset_record_doutb + `CQE_LENGTH) :
                                (cur_state == RX_REQ_s && RX_REQ_cq_resp_ready) ? (cq_offset_record_doutb + `CQE_LENGTH == cq_length ? 'd0 : cq_offset_record_doutb + `CQE_LENGTH) :
                                (cur_state == RX_RESP_s && RX_RESP_cq_resp_ready) ? (cq_offset_record_doutb + `CQE_LENGTH == cq_length ? 'd0 : cq_offset_record_doutb + `CQE_LENGTH) : 'd0;

//-- cq_offset_record_addrb --
assign cq_offset_record_addrb = (cur_state == IDLE_s && next_state == TX_REQ_s) ? TX_REQ_cq_req_head[`CQN_OFFSET] :
                                (cur_state == IDLE_s && next_state == RX_REQ_s) ? RX_REQ_cq_req_head[`CQN_OFFSET] :
                                (cur_state == IDLE_s && next_state == RX_RESP_s) ? RX_RESP_cq_req_head[`CQN_OFFSET] : cqn;


//-- TX_REQ_cq_req_ready --
assign TX_REQ_cq_req_ready = (cur_state == TX_REQ_s) ? 'd1 : 'd0;

wire    [31:0]              cqn_resp;
assign cqn_resp = {'d0, cqn};

//-- TX_REQ_cq_resp_valid --
//-- TX_REQ_cq_resp_head --
assign TX_REQ_cq_resp_valid = (cur_state == TX_REQ_s) ? 'd1 : 'd0;
assign TX_REQ_cq_resp_head = (cur_state == TX_REQ_s) ? {cq_offset_record_doutb, cqn_resp}: 'd0;

//-- RX_REQ_cq_req_ready --
assign RX_REQ_cq_req_ready = (cur_state == RX_REQ_s) ? 'd1 : 'd0;

//-- RX_REQ_cq_resp_valid --
//-- RX_REQ_cq_resp_head --
assign RX_REQ_cq_resp_valid = (cur_state == RX_REQ_s) ? 'd1 : 'd0;
assign RX_REQ_cq_resp_head = (cur_state == RX_REQ_s) ? {cq_offset_record_doutb, cqn_resp}: 'd0;

//-- RX_RESP_cq_req_ready --
assign RX_RESP_cq_req_ready = (cur_state == RX_RESP_s) ? 'd1 : 'd0;

//-- RX_RESP_cq_resp_valid --
//-- RX_RESP_cq_resp_head --
assign RX_RESP_cq_resp_valid = (cur_state == RX_RESP_s) ? 'd1 : 'd0;
assign RX_RESP_cq_resp_head = (cur_state == RX_RESP_s) ? {cq_offset_record_doutb, cqn_resp}: 'd0;
/*------------------------------------------- Variables Decode : End ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/

/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule