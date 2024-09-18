`timescale 1ns / 100ps
//*************************************************************************
//   > File Name  : acc_cm.v
//   > Description: CEU_ACC_CM, Used to pass command to Context Management module.
//   >              The command includes:
//   >        inbox: Y, outbox: N:
//   >            CMD_MAP_ICM
//   >            CMD_SW2HW_CQ
//   >            CMD_RESIZE_CQ
//   >            CMD_SW2HW_EQ
//   >        inbox: N, outbox: N:
//   >            CMD_UNMAP_ICM
//   >            CMD_MAP_EQ  
//   >            CMD_HW2SW_CQ
//   >            CMD_HW2SW_EQ
//   >        inbox: N, outbox: Y:
//   >            CMD_QUERY_QP
//   >        inbox: Y/N, outbox: N:
//   >            IS_MODIFY_QP
//   > Author: Corning
//   > Date  : 2020-07-13
//*************************************************************************

`include "ceu_def_h.vh"
`include "protocol_engine_def.vh"

module acc_cm #(
    parameter DMA_HEAD_WIDTH     = 128            // DMA Stream *_head width
) (
    input wire clk,
    input wire rst_n,

    /* -------DMA Interface{begin}------- */
    /* dma_*_head(interact with RDMA modules), valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    // DMA read response
    input   wire                       dma_rd_rsp_valid, // i, 1
    input   wire                       dma_rd_rsp_last , // i, 1
    input   wire [`CEU_DATA_WIDTH-1:0] dma_rd_rsp_data , // i, `CEU_DATA_WIDTH
    input   wire [DMA_HEAD_WIDTH -1:0] dma_rd_rsp_head , // i, DMA_HEAD_WIDTH
    output  wire                       dma_rd_rsp_ready, // o, 1

    // DMA write req
    output  wire                       dma_wr_req_valid, // o, 1
    output  wire                       dma_wr_req_last , // o, 1
    output  wire [`CEU_DATA_WIDTH-1:0] dma_wr_req_data , // o, `CEU_DATA_WIDTH
    output  wire [DMA_HEAD_WIDTH -1:0] dma_wr_req_head , // o, DMA_HEAD_WIDTH
    input   wire                       dma_wr_req_ready, // i, 1
    /* -------DMA Interface{end}------- */

    /* -------Context Management Interface{begin}------- */
    // CTXMgt req
    output  wire                          cm_req_valid, // o, 1
    output  wire                          cm_req_last , // o, 1
    output  wire [`CEU_DATA_WIDTH   -1:0] cm_req_data , // o, `CEU_DATA_WIDTH
    output  wire [`CEU_CM_HEAD_WIDTH-1:0] cm_req_head , // o, `CEU_CM_HEAD_WIDTH
    input   wire                          cm_req_ready, // i, 1

    // CTXMgt read resp
    input   wire                          cm_rsp_valid, // i, 1
    input   wire                          cm_rsp_last , // i, 1
    input   wire [`CEU_DATA_WIDTH   -1:0] cm_rsp_data , // i, `CEU_DATA_WIDTH
    input   wire [`CEU_CM_HEAD_WIDTH-1:0] cm_rsp_head , // i, `CEU_CM_HEAD_WIDTH
    output  wire                          cm_rsp_ready, // o, 1
    /* -------Context Management Interface{end}------- */

    /* -------CMD Information{begin}------- */
    input  wire        has_inbox  ,
    input  wire [11:0] op         ,
    input  wire [63:0] in_param   ,
    input  wire [31:0] in_modifier,
    input  wire [63:0] outbox_addr   ,
    /* -------CMD Information{end}------- */

    input  wire  start ,
    output wire  finish

`ifdef CEU_DBG_LOGIC 
    ,output wire [`ACC_CM_DBG_WIDTH-1:0] dbg_bus      // o, `ACC_CM_DBG_WIDTH;
`endif
);
/* -------Decode & Head generation{begin}-------- */
/*************************head*********************************
与上下文管理模块通信, 请求, 含payload:
Write Context Management request head (CMD_MAP_ICM), with payload
|--------| --------------------64bit----------------------- |
|  127:  |      type     |     opcode    |   R  | chunk_num |
|   64   | (MAP_ICM_CTX) | (MAP_ICM_EN)  | void |  (32bit)  |
|--------|--------------------------------------------------|
|   63:  |                        R                         |
|    0   |                      void                        |
|--------|--------------------------------------------------|

Write Context Management request head (CMD_SW2HW_CQ), with payload
|--------|----------------------64bit-----------------------|
|  127:  |     type     |    opcode    |   R   |   CQ_num   |
|   64   | (WR_CQ_CTX)  | (WR_CQ_ALL)  | void  |  (32bit)   |
|--------|--------------------------------------------------|
|   63:  |                         R                        |
|    0   |                        void                      |
|--------|--------------------------------------------------|

Write Context Management request head (CMD_RESIZE_CQ), with payload
|--------| --------------------64bit---------------------- |
|  127:  |      type     |     opcode     |   R  |  CQ_num |
|   64   |  (WR_CQ_CTX)  | (WR_CQ_MODIFY) | void | (32bit) |
|--------|-------------------------------------------------|
|   63:  |                        R                        |
|    0   |                       void                      |
|--------|-------------------------------------------------|

Write Context Management request head (CMD_SW2HW_EQ), with payload
|--------|----------------------64bit-----------------------|
|  127:  |     type     |    opcode    |   R   |   EQ_num   |
|   64   | (WR_EQ_CTX)  | (WR_EQ_ALL)  | void  |  (32bit)   |
|--------|--------------------------------------------------|
|   63:  |                         R                        |
|    0   |                        void                      |
|--------|--------------------------------------------------|

Communicate with CM module, request, without payload:

Write Context Management request head (CMD_UNMAP_ICM), without payload
|--------| -------------------64bit----------------------- |
|  127:  |      type     |     opcode    |   R  | page_cnt |
|   64   | (MAP_ICM_CTX) | (MAP_ICM_DIS) | void | (32bit)  |
|--------|-------------------------------------------------|
|   63:  |                      virt                       |
|    0   |                    (64bit)                      |
|--------|-------------------------------------------------|

Read Context Management request head (CMD_QUERY_QP), without payload
|--------|----------------------64bit-----------------------|
|  127:  |     type     |   opcode    |   R    |   QP_num   |
|   64   | (RD_QP_CTX)  | (RD_QP_ALL) | void   |  (32bit)   |
|--------|--------------------------------------------------|
|   63:  |                         R                        |
|    0   |                        void                      |
|--------|--------------------------------------------------|

Write Context Management request head (CMD_HW2SW_CQ), without payload
|--------|----------------------64bit-----------------------|
|  127:  |     type     |     opcode    |   R   |  CQ_num   |
|   64   | (WR_CQ_CTX)  |(WR_CQ_INVALID)| void  | (32bit)   |
|--------|--------------------------------------------------|
|   63:  |                         R                        |
|    0   |                        void                      |
|--------|--------------------------------------------------|

Write Context Managment request head (CMD_HW2SW_EQ), without payload
|--------|----------------------64bit-----------------------|
|  127:  |     type     |     opcode     |   R  |   EQ_num  |
|   64   | (WR_EQ_CTX)  |(WR_EQ_INVALID) | void |  (32bit)  |
|--------|--------------------------------------------------|
|   63:  |                         R                        |
|    0   |                        void                      |
|--------|--------------------------------------------------|

Write Context Management request head (CMD_MAP_EQ), without payload
|--------| --------------------64bit---------------------- |
|  127:  |      type     |     opcode     |   R  |  EQ_num |
|   64   |  (WR_EQ_CTX)  |  (WR_EQ_FUNC)  | void | (32bit) |
|--------|-------------------------------------------------|
|   63:  |                    event_mask                   |
|    0   |                     (64bit)                     |
|--------|-------------------------------------------------|

Communicate with CM, request, with/without payload:

Write Context Management request head (CMD_MODIFY_QP), with/without payload
|--------|----------------------64bit-----------------------|
|  127:  |     type     |    opcode   |   R    |   QP_num   |
|   64   | (WR_QP_CTX)  | (WR_QP_ALL) | void   |  (32bit)   |
|--------|--------------------------------------------------|
|   63:  |                         R                        |
|    0   |                        void                      |
|--------|--------------------------------------------------|

Communicate with CM module, response, with payload:

Read Context Management response head (CMD_QUERY_QP), with payload
|--------|----------------------64bit-----------------------|
|  127:  |     type     |   opcode    |   R    |   QP_num   |
|   64   | (RD_QP_CTX)  | (RD_QP_ALL) | void   |  (32bit)   |
|--------|--------------------------------------------------|
|   63:  |                         R                        |
|    0   |                        void                      |
|--------|--------------------------------------------------|

Communicate with DMA, write request, with payload:

dma write outbox req head, with payload (only for CMD_QUERY_QP)
|--------| --------------------64bit---------------------- |
|  127:  |            R            |     outbox_addr       |
|   64   |         (63:32)         |     (63:32 bit)       |
|--------|-------------------------------------------------|
|   63:  |       outbox_addr       |    R    | outbox_len  |
|    0   |       (31: 0 bit)       | (31:12) | (11:0 bit)  |
|--------|-------------------------------------------------|
*****************************************************************/
wire is_sw2hw_cq, is_resize_cq, is_sw2hw_eq, is_map_eq, is_modify_qp, is_hw2sw_cq, is_hw2sw_eq, is_query_qp;
wire is_map_icm, is_unmap_icm;


wire rd_cmd;
// wire wr_cmd;


wire [`AXIS_TYPE_WIDTH-1:0] typ; // modified by mazhenlong
wire [`AXIS_OPCODE_WIDTH-1:0] opcode;

// -------CM req head-------
// EQ_num    --> in_modifier;
// CQ_num    --> in_modifier;
// QP_num    --> in_modifier;
// page_cnt  --> in_modifier;
// chunk_num --> in_modifier;
// event_mask--> in_param;
// virt      --> in_param;
wire has_cm_head_low;
reg  [63:0] cm_head_high;
reg  [63:0] cm_head_low;



// -------dma wr req head-------
reg [11:0] outbox_len;
/* -------Decode & Head generation{end}-------- */

/* ------- FSM relevant{begin}------- */
localparam  IDLE         = 4'b0001, // Wait for start and inbox coming (if needed)
            INBOX_CM_REQ = 4'b0010, // Forward last beat of inbox to CM request Interface
            BARE_CM_REQ  = 4'b0100, // Forward (Read/Write) request to CM request Interface
            WR_OUTBOX    = 4'b1000; // Wait for dma write request end

reg [3:0] cur_state;
reg [3:0] nxt_state;

wire is_idle, is_inbox_cm_req, is_bare_cm_req, is_wr_outbox;
wire j_inbox_cm_req, j_bare_cm_req;
/* ------- FSM relevant{end}------- */


/* --------------------------------------------------------------------------------------------------- */

/* -------Decode & Head generation{begin}-------- */
assign is_sw2hw_cq  = (op == `CMD_SW2HW_CQ );
assign is_resize_cq = (op == `CMD_RESIZE_CQ);
assign is_sw2hw_eq  = (op == `CMD_SW2HW_EQ );
assign is_map_eq    = (op == `CMD_MAP_EQ   );
assign is_hw2sw_cq  = (op == `CMD_HW2SW_CQ );
assign is_hw2sw_eq  = (op == `CMD_HW2SW_EQ );
assign is_query_qp  = (op == `CMD_QUERY_QP );
assign is_modify_qp = `IS_MODIFY_QP(op);
assign is_map_icm   = (op == `CMD_MAP_ICM  );
assign is_unmap_icm = (op == `CMD_UNMAP_ICM);

assign rd_cmd       = is_query_qp;
// assign wr_cmd       = is_unmap_icm | is_map_icm | is_modify_qp | is_hw2sw_eq | is_hw2sw_cq |
//                       is_map_eq | is_sw2hw_eq | is_resize_cq | is_sw2hw_cq;


assign typ    = ({`AXIS_TYPE_WIDTH{is_map_icm  }} & `MAP_ICM_CTX) | // modified by mazhenlong
                ({`AXIS_TYPE_WIDTH{is_unmap_icm}} & `MAP_ICM_CTX) |
                ({`AXIS_TYPE_WIDTH{is_query_qp }} & `RD_QP_CTX  ) |
                ({`AXIS_TYPE_WIDTH{is_modify_qp}} & `WR_QP_CTX  ) |
                ({`AXIS_TYPE_WIDTH{is_sw2hw_cq }} & `WR_CQ_CTX  ) |
                ({`AXIS_TYPE_WIDTH{is_hw2sw_cq }} & `WR_CQ_CTX  ) |
                ({`AXIS_TYPE_WIDTH{is_resize_cq}} & `WR_CQ_CTX  ) |
                ({`AXIS_TYPE_WIDTH{is_sw2hw_eq }} & `WR_EQ_CTX  ) |
                ({`AXIS_TYPE_WIDTH{is_hw2sw_eq }} & `WR_EQ_CTX  ) |
                ({`AXIS_TYPE_WIDTH{is_map_eq   }} & `WR_EQ_CTX  );

assign opcode = ({`AXIS_OPCODE_WIDTH{is_map_icm  }} & `WR_ICMMAP_EN ) |
                ({`AXIS_OPCODE_WIDTH{is_unmap_icm}} & `WR_ICMMAP_DIS) |
                ({`AXIS_OPCODE_WIDTH{is_query_qp }} & `RD_QP_ALL    ) |
                ({`AXIS_OPCODE_WIDTH{is_modify_qp &   has_inbox }} & `WR_QP_ALL    ) |
                ({`AXIS_OPCODE_WIDTH{is_modify_qp & (!has_inbox)}} & `WR_QP_INVALID) |
                ({`AXIS_OPCODE_WIDTH{is_sw2hw_cq }} & `WR_CQ_ALL    ) |
                ({`AXIS_OPCODE_WIDTH{is_hw2sw_cq }} & `WR_CQ_INVALID) |
                ({`AXIS_OPCODE_WIDTH{is_resize_cq}} & `WR_CQ_MODIFY ) |
                ({`AXIS_OPCODE_WIDTH{is_sw2hw_eq }} & `WR_EQ_ALL    ) |
                ({`AXIS_OPCODE_WIDTH{is_hw2sw_eq }} & `WR_EQ_INVALID) |
                ({`AXIS_OPCODE_WIDTH{is_map_eq   }} & `WR_EQ_FUNC   );

assign has_cm_head_low = is_map_eq | is_unmap_icm;
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        cm_head_high <= `TD 0;
    end
    else if (j_inbox_cm_req | j_bare_cm_req) begin
        cm_head_high <= `TD {typ, opcode, {32-`AXIS_TYPE_WIDTH-`AXIS_OPCODE_WIDTH{1'b0}}, in_modifier};
    end
end
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        cm_head_low <= `TD 0;
    end
    else if (has_cm_head_low) begin
        cm_head_low <= `TD in_param;
    end
    else begin
        cm_head_low <= `TD 0;
    end
end
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        outbox_len <= `TD 0;
    end
    else if (is_query_qp) begin
        outbox_len <= `TD `OUTBOX_LEN_QUERY_QP;
    end
    else begin
        outbox_len <= `TD 0;
    end
end
/* -------Decode & Head generation{end}-------- */


//------------------------------{Access Context Management FSM}begin------------------------------//
/******************** Stage 1: State Register **********************/
always @(posedge clk, negedge rst_n) begin
    if(~rst_n)
        cur_state <= `TD IDLE;
    else
        cur_state <= `TD nxt_state;
end

/******************** Stage 2: State Transition **********************/

assign is_idle         = (cur_state == IDLE        );
assign is_inbox_cm_req = (cur_state == INBOX_CM_REQ);
assign is_bare_cm_req  = (cur_state == BARE_CM_REQ );
assign is_wr_outbox    = (cur_state == WR_OUTBOX   );

assign j_inbox_cm_req = is_idle & start & has_inbox & dma_rd_rsp_valid;
assign j_bare_cm_req  = is_idle & start & (!has_inbox);

always @(*) begin
    case(cur_state)
        IDLE: begin
            if (start & has_inbox & dma_rd_rsp_valid) begin
                nxt_state = INBOX_CM_REQ;
            end
            else if (start & (!has_inbox)) begin
                nxt_state = BARE_CM_REQ;
            end
            else begin
                nxt_state = IDLE;
            end
        end
        INBOX_CM_REQ: begin
            if (cm_req_valid & cm_req_ready & cm_req_last) begin // cm write req data end
                nxt_state = IDLE;
            end
            else begin
                nxt_state = INBOX_CM_REQ;
            end
        end
        BARE_CM_REQ: begin
            if (cm_req_valid & cm_req_ready) begin 
                nxt_state = rd_cmd ? WR_OUTBOX : IDLE;
            end
            else begin
                nxt_state = BARE_CM_REQ;
            end
        end
        WR_OUTBOX: begin
            if (dma_wr_req_valid & dma_wr_req_ready & dma_wr_req_last) begin // dma write request data end
                nxt_state = IDLE;
            end
            else begin
                nxt_state = WR_OUTBOX;
            end
        end
        default: begin
            nxt_state = IDLE;
        end
    endcase
end
/******************** Stage 3: Output **********************/


/* ***** output ***** */
// DMA Read Response
assign dma_rd_rsp_ready = is_inbox_cm_req ? cm_req_ready : 0;

// DMA Write Request
assign dma_wr_req_valid = is_wr_outbox ? cm_rsp_valid : 0;
assign dma_wr_req_head  = is_wr_outbox ? {32'd0, outbox_addr, 20'd0, outbox_len} : 0;
assign dma_wr_req_data  = is_wr_outbox ? cm_rsp_data  : 0;
assign dma_wr_req_last  = is_wr_outbox ? cm_rsp_last  : 0;

// Context Management Request
assign cm_req_valid = (is_inbox_cm_req & dma_rd_rsp_valid) |
                      is_bare_cm_req;
assign cm_req_head  = {cm_head_high, cm_head_low};
assign cm_req_data  = ({256{(is_inbox_cm_req & dma_rd_rsp_valid)}} & dma_rd_rsp_data);
assign cm_req_last  = {is_inbox_cm_req & dma_rd_rsp_valid} & dma_rd_rsp_last |
                      is_bare_cm_req;

// Context Management Response
assign cm_rsp_ready = is_wr_outbox ? dma_wr_req_ready : 0;


// finish 
assign finish = (is_wr_outbox    & dma_wr_req_valid & dma_wr_req_ready & dma_wr_req_last) |
                (is_bare_cm_req  & cm_req_valid     & cm_req_ready     & (!rd_cmd)      ) |
                (is_inbox_cm_req & cm_req_valid     & cm_req_ready     & cm_req_last    );
/* ***** output ***** */
//------------------------------{Access Context Management FSM}end------------------------------//


`ifdef CEU_DBG_LOGIC 
/* --------DBG signal{begin}-------- */
assign dbg_bus = {cm_head_high, cm_head_low, outbox_len, cur_state, nxt_state};
/* --------DBG signal{end}-------- */
`endif
endmodule
