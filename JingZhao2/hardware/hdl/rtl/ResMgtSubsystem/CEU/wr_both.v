`timescale 1ns / 100ps
//*************************************************************************
//   > File Name  : wr_both.v
//   > Description: CEU_WR_BOTH, used to pass comand to both Context Management 
//   >              module and Virtual to Physical module. The command includes:
//   >        inbox: Y, outbox: N:
//   >            CMD_INIT_HCA 
//   >        inbox: N, outbox: N:
//   >            CMD_CLOSE_HCA
//   > Author     : Corning
//   > Date       : 2020-07-09
//*************************************************************************

`include "ceu_def_h.vh"
`include "protocol_engine_def.vh"

module wr_both #(
    parameter DMA_HEAD_WIDTH     = 128            // DMA Stream *_head width
) (
    input clk     ,
    input rst_n,


    /* -------DMA Interface{begin}------- */
    /* dma_*_head(interact with RDMA modules), valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    // DMA read response
    input   wire                      dma_rd_rsp_valid, // i, 1
    // input   wire                      dma_rd_rsp_last , // i, 1
    input   wire [`CEU_DATA_WIDTH-1  :0] dma_rd_rsp_data , // i, `CEU_DATA_WIDTH
    // input   wire [DMA_HEAD_WIDTH-1:0] dma_rd_rsp_head , // i, DMA_HEAD_WIDTH
    output  wire                      dma_rd_rsp_ready, // o, 1
    /* -------DMA Interface{end}------- */

    /* -------Virtual-to-physial Interface{begin}------- */
    // VirtToPhys write req
    output  wire                           v2p_req_valid, // o, 1
    output  wire                           v2p_req_last , // o, 1
    output  wire [`CEU_DATA_WIDTH    -1:0] v2p_req_data , // o, `CEU_DATA_WIDTH
    output  wire [`CEU_V2P_HEAD_WIDTH-1:0] v2p_req_head , // o, CEU_V2P_HEAD_WIDTH
    input   wire                           v2p_req_ready, // i, 1
    /* -------Virtual-to-physial Interface{end}------- */

    /* -------Context Management Interface{begin}------- */
    // CtxMgt req
    output  wire                          cm_req_valid, // o, 1
    output  wire                          cm_req_last , // o, 1
    output  wire [`CEU_DATA_WIDTH   -1:0] cm_req_data , // o, `CEU_DATA_WIDTH
    output  wire [`CEU_CM_HEAD_WIDTH-1:0] cm_req_head , // o, CEU_CM_HEAD_WIDTH
    input   wire                          cm_req_ready, // i, 1
    /* -------Context Management Interface{end}------- */

    /* -------CMD Information{begin}------- */
    input  wire [11:0] op,
    /* -------CMD Information{end}------- */

    // module ctrl
    input  wire        start,
    output wire        finish

`ifdef CEU_DBG_LOGIC 
    ,output wire [`WR_BOTH_DBG_WIDTH-1:0] dbg_bus      // o, `WR_BOTH_DBG_WIDTH;
`endif
);
/* -------Decode & Head generation{begin}-------- */
/*************************Head & Data************************************

Write Context Management request head (CMD_INIT_HCA), with payload
|--------| --------------------64bit---------------------- |
|  127:  |      type       |      opcode    |     R        |
|   64   | (WR_ICMMAP_CTX) | (WR_ICMMAP_EN) |  (void)      |
|--------|-------------------------------------------------|
|   63:  |                        R                        |
|    0   |                     (void)                      |
|--------|-------------------------------------------------|

Write Context Management request Data (CMD_INIT_HCA), only one beat
|--------| --------------------64bit---------------------- |------|
|  255:  |                        R                        | 1Ch- |
|  192   |                     (void)                      | 18h  |
|--------|-------------------------------------------------|------|
|  191:  |            eqc_base             |  log_num_eqs  | 14h- |
|  128   |            (63:8)               |    (7:0)      | 10h  |
|--------|-------------------------------------------------|------|
|  127:  |            cqc_base             |  log_num_cqs  | 0Ch- |
|   64   |            (63:8)               |    (7:0)      | 08h  |
|--------|-------------------------------------------------|------|
|   63:  |            qpc_base             |  log_num_qps  | 04h- |
|    0   |            (63:8)               |    (7:0)      | 00h  |
|--------|-------------------------------------------------|------|


Write Virtual-to-physical Request Head (CMD_INIT_HCA), with payload
|--------| --------------------64bit---------------------- |
|  127:  |      type       |      opcode    |     R        |
|   64   | (WR_ICMMAP_TPT) | (WR_ICMMAP_EN) |  (void)      |
|--------|-------------------------------------------------|
|   63:  |                        R                        |
|    0   |                     (void)                      |
|--------|-------------------------------------------------|

Write Virtual-to-physical Request Data (CMD_INIT_HCA), only one beat
|--------|---------------------64bit-----------------------|
|  255:  |                        R                        |
|  192   |                     (void)                      |
|--------|-------------------------------------------------|
|  191:  |                        R                        |
|  128   |                     (void)                      |
|--------|-------------------------------------------------|
|  127:  |            mpt_base             |  log_mpt_sz   |
|   64   |            (63:8)               |    (7:0)      |
|--------|-------------------------------------------------|
|   63:  |                    mtt_base                     |
|    0   |                    (63:0)                       |
|--------|-------------------------------------------------|

Write Virtual-to-physical & Context Management Request Head (CMD_CLOSE_HCA), without payload
|--------| --------------------64bit---------------------- |
|  127:  |      type     |      opcode     |       R       |
|   64   |               | (WR_ICMMAP_DIS) |    (void)     |
|--------|-------------------------------------------------|
|   63:  |                        R                        |
|    0   |                     (void)                      |
|--------|-------------------------------------------------|

DMA读响应通道: data signal(two beats in total)
First beat
|--------| --------------------64bit---------------------- |------|
|  255:  |                        R                        | 1Ch- |
|  192   |                     (void)                      | 18h  |
|--------|-------------------------------------------------|------|
|  191:  |            qpc_base             |  log_num_qps  | 14h- |
|  128   |            (63:8)               |    (7:0)      | 10h  |
|--------|-------------------------------------------------|------|
|  127:  |            cqc_base             |  log_num_cqs  | 0Ch- |
|   64   |            (63:8)               |    (7:0)      | 08h  |
|--------|-------------------------------------------------|------|
|   63:  |            eqc_base             |  log_num_eqs  | 04h- |
|    0   |            (63:8)               |    (7:0)      | 00h  |
|--------|-------------------------------------------------|------|

Second beat
|--------|---------------------64bit-----------------------|------|
|  255:  |                        R                        | 3Ch- |
|  192   |                     (void)                      | 38h  |
|--------|-------------------------------------------------|------|
|  191:  |                        R                        | 34h- |
|  128   |                     (void)                      | 30h  |
|--------|-------------------------------------------------|------|
|  127:  |            mpt_base             |  log_mpt_sz   | 2Ch- |
|   64   |            (63:8)               |    (7:0)      | 28h  |
|--------|-------------------------------------------------|------|
|   63:  |                    mtt_base                     | 24h- |
|    0   |                    (63:0)                       | 20h  |
|--------|-------------------------------------------------|------|
******************************************************************/

wire is_init_hca, is_close_hca;

// wire has_payload; // if the cmd has payload


// Context Management & Virtual to physical Write Request head
wire [`AXIS_TYPE_WIDTH-1:0] cm_type;
wire [`AXIS_TYPE_WIDTH-1:0] v2p_type;
wire [`AXIS_OPCODE_WIDTH-1:0] opcode;
reg  [`CEU_CM_HEAD_WIDTH-1 :0] cm_head;
reg  [`CEU_V2P_HEAD_WIDTH-1:0] v2p_head;

/* -------Decode & Head generation{end}-------- */

/* -------FSM relevant{begin}------- */
localparam  IDLE          = 4'b0001, // Wait until start asserted.
            INBOX_CM_REQ  = 4'b0010, // Forward first beat of DMA response to CM
            INBOX_V2P_REQ = 4'b0100, // Forward second beat of DMA response to V2P
            BARE_CM_V2P   = 4'b1000; // Forward Head of non-payload Write Request to CM & V2P
reg [3:0] cur_state;
reg [3:0] nxt_state;

wire is_idle, is_inbox_cm_req, is_inbox_v2p_req, is_bare_cm_v2p;


// In BARE_CM_V2P, these signals indicate that CM/V2P write request has finished.
reg cm_head_end;
reg v2p_head_end; 

/* -------FSM relevant{end}------- */

/* --------------------------------------------------------------------------------------------------- */

/* -------Decode & Head generation{begin}-------- */
assign is_init_hca  = (op == `CMD_INIT_HCA) ;
assign is_close_hca = (op == `CMD_CLOSE_HCA);


// assign has_payload = is_init_hca;

assign cm_type   = `WR_ICMMAP_CTX;
assign v2p_type  = `WR_ICMMAP_TPT;
assign opcode = ({`AXIS_TYPE_WIDTH{is_init_hca }} & `WR_ICMMAP_EN ) |
                ({`AXIS_TYPE_WIDTH{is_close_hca}} & `WR_ICMMAP_DIS);

// Write Request Head
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        cm_head  <= `TD 0;
        v2p_head <= `TD 0;
    end
    // else if () begin
    //     cm_head  <= `TD 0;
    //     v2p_head <= `TD 0;
    // end
    else if (start) begin
        cm_head  <= `TD {cm_type, opcode, {64-`AXIS_TYPE_WIDTH-`AXIS_OPCODE_WIDTH{1'b0}}, 64'b0};
        v2p_head <= `TD {v2p_type, opcode, {64-`AXIS_TYPE_WIDTH-`AXIS_OPCODE_WIDTH{1'b0}}, 64'b0};
    end
end
/* -------Decode & Head generation{end}-------- */

//------------------------------{Write both FSM}begin------------------------------//


/******************** Stage 1: State Register **********************/
always @(posedge clk, negedge rst_n) begin
    if(~rst_n)
        cur_state <= `TD IDLE;
    else
        cur_state <= `TD nxt_state;
end

/******************** Stage 2: State Transition **********************/

always @(*) begin
    case(cur_state)
        IDLE: begin
            if (start & is_init_hca) begin // start write Request with payload to CM
                nxt_state = INBOX_CM_REQ;
            end
            else if (start & is_close_hca) begin // start write Request without payload to CM & V2P
                nxt_state = BARE_CM_V2P;
            end
            else begin
                nxt_state = IDLE;
            end
        end
        INBOX_CM_REQ: begin
            if (cm_req_valid & cm_req_ready) begin // cm write req data end
                nxt_state = INBOX_V2P_REQ;
            end
            else begin
                nxt_state = INBOX_CM_REQ;
            end
        end
        INBOX_V2P_REQ: begin
            if (v2p_req_valid & v2p_req_ready) begin // v2p write req data end
                nxt_state = IDLE;
            end
            else begin
                nxt_state = INBOX_V2P_REQ;
            end
        end
        BARE_CM_V2P: begin
            if ((cm_head_end | cm_req_ready) & (v2p_head_end | v2p_req_ready)) begin // cm & v2p write request end
                nxt_state = IDLE;
            end
            else begin
                nxt_state = BARE_CM_V2P;
            end
        end
        default: begin
            nxt_state = IDLE;
        end
    endcase
end
/******************** Stage 3: Output **********************/

assign is_idle          = (cur_state == IDLE         ); 
assign is_inbox_cm_req  = (cur_state == INBOX_CM_REQ );
assign is_inbox_v2p_req = (cur_state == INBOX_V2P_REQ);
assign is_bare_cm_v2p   = (cur_state == BARE_CM_V2P  );



always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        cm_head_end  <= `TD 0;
        v2p_head_end <= `TD 0;
    end
    else if (is_idle) begin
        cm_head_end  <= `TD 0;
        v2p_head_end <= `TD 0;
    end
    else if (is_bare_cm_v2p & cm_req_ready & !v2p_req_ready) begin
        cm_head_end  <= `TD 1;
    end
    else if (is_bare_cm_v2p & !cm_req_ready & v2p_req_ready) begin
        v2p_head_end <= `TD 1;
    end
end


/* ***** output ***** */

// Context Management write req
assign cm_req_valid = (is_bare_cm_v2p  & !cm_head_end) |
                      (is_inbox_cm_req & dma_rd_rsp_valid);
assign cm_req_last  = cm_req_valid;
assign cm_req_head  = cm_req_valid ? cm_head         : 0;
assign cm_req_data  = (cm_req_valid & dma_rd_rsp_valid) ? dma_rd_rsp_data : 0;

// Virtual to Physical write req
assign v2p_req_valid = (is_bare_cm_v2p   & !v2p_head_end) |
                       (is_inbox_v2p_req & dma_rd_rsp_valid);
assign v2p_req_last  = v2p_req_valid;
assign v2p_req_head  = v2p_req_valid ? v2p_head        : 0;
assign v2p_req_data  = (v2p_req_valid & dma_rd_rsp_valid) ? dma_rd_rsp_data : 0;



// dma read response
assign dma_rd_rsp_ready = (is_inbox_cm_req  & cm_req_ready) | 
                          (is_inbox_v2p_req & v2p_req_ready);

// finish
assign finish  = (is_bare_cm_v2p & (cm_head_end | cm_req_ready) & (v2p_head_end | v2p_req_ready)) |
                 (is_inbox_v2p_req & v2p_req_valid & v2p_req_ready);
/* ***** for output ***** */
//------------------------------{Write Both FSM}end------------------------------//

`ifdef CEU_DBG_LOGIC 
/* --------DBG signal{begin}-------- */
assign dbg_bus = {cm_head_end, v2p_head_end, cur_state, nxt_state};
/* --------DBG signal{end}-------- */
`endif

//ceu_ila_4 ceu_ila_4 (
//    .clk ( clk ),
//    .probe0 (cur_state    ), // i, 4
//    .probe1 (v2p_req_valid ), // i, 1
//    .probe2 (v2p_req_ready )  // i, 1

//);
endmodule
