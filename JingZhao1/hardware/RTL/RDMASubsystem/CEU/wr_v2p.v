`timescale 1ns / 100ps
//*************************************************************************
//   > File Name  : wr_v2p.v
//   > Description: CEU_WR_V2P, used to pass command to Virtual to Physical module. 
//   >              The command includes:
//   >        inbox: Y, outbox: N:
//   >            CMD_MAP_ICM  
//   >            CMD_SW2HW_MPT
//   >            CMD_WRITE_MTT
//   >        inbox: N, outbox: N:
//   >            CMD_UNMAP_ICM
//   >            CMD_HW2SW_MPT
//   > Author     : Corning
//   > Date       : 2020-07-09
//*************************************************************************


`include "ceu_def_h.vh"
`include "msg_def_ctxmgt_h.vh"

module wr_v2p #(
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
    /* -------DMA Interface{end}------- */

    /* -------Virtual-to-physial Interface{begin}------- */
    // VirtToPhys write req
    output  wire                           v2p_req_valid, // o, 1
    output  wire                           v2p_req_last , // o, 1
    output  wire [`CEU_DATA_WIDTH    -1:0] v2p_req_data , // o, `CEU_DATA_WIDTH
    output  wire [`CEU_V2P_HEAD_WIDTH-1:0] v2p_req_head , // o, CEU_V2P_HEAD_WIDTH
    input   wire                           v2p_req_ready,  // i, 1
    /* -------Virtual-to-physial Interface{end}------- */

    /* -------CMD Information{begin}------- */
    input  wire        has_inbox  ,
    input  wire [11:0] op         ,
    input  wire [63:0] in_param   ,
    input  wire [31:0] in_modifier,
    /* -------CMD Information{end}------- */

    // module ctrl
    input  wire        start ,
    output wire        finish

`ifdef CEU_DBG_LOGIC 
    ,output wire [`WR_V2P_DBG_WIDTH-1:0] dbg_bus      // o, `WR_V2P_DBG_WIDTH;
`endif
);
//------------------------{Decode & Packet generation}begin---------------------------//
/*************************head************************************
与虚实地址转换模块通信, 请求, 含payload:
Write Context Management request head (CMD_MAP_ICM), with payload
|--------| --------------------64bit----------------------- |
|  127:  |      type     |     opcode    |   R  | chunk_num |
|   64   | (MAP_ICM_TPT) | (MAP_ICM_EN)  | void |  (32bit)  |
|--------|--------------------------------------------------|
|   63:  |                        R                         |
|    0   |                      void                        |
|--------|--------------------------------------------------|

Write Context Management request head (CMD_SW2HW_MPT), with payload
|--------|----------------------64bit-----------------------|
|  127:  |     type     |     opcode     |   R  | mpt_index |
|   64   | (WR_MPT_TPT) | (WR_MPT_WRITE) | void |  (32bit)  |
|--------|--------------------------------------------------|
|   63:  |                         R                        |
|    0   |                        void                      |
|--------|--------------------------------------------------|

Write Context Management request head (CMD_WRITE_MTT), with payload
|--------| --------------------64bit---------------------- |
|  127:  |      type     |     opcode     |   R  | mtt_num |
|   64   | (WR_MTT_TPT)  | (WR_MTT_WRITE) | void | (32bit) |
|--------|-------------------------------------------------|
|   63:  |                 mtt_start_index                 |
|    0   |                     (64bit)                     |
|--------|-------------------------------------------------|

Write Context Management request data (CMD_WRITE_MTT), only one beat
|--------|-------------------64bit-------------------------|
|  255:  |                   mtt_phy_addr[3]               |
|  192   |                     (64bit)                     |
|--------|-------------------------------------------------|
|  191:  |                   mtt_phy_addr[2]               |
|  128   |                     (64bit)                     |
|--------|-------------------------------------------------|
|  127:  |                   mtt_phy_addr[1]               |
|   64   |                     (64bit)                     |
|--------|-------------------------------------------------|
|   63:  |                   mtt_phy_addr[0]               |
|    0   |                     (64bit)                     |
|--------|-------------------------------------------------|


与虚实地址转换模块通信, 请求, 无payload:
Write Context Management request head (CMD_UNMAP_ICM), without payload
|--------| -------------------64bit----------------------- |
|  127:  |      type     |     opcode    |   R  | page_cnt |
|   64   | (MAP_ICM_TPT) | (MAP_ICM_DIS) | void | (32bit)  |
|--------|-------------------------------------------------|
|   63:  |                      virt                       |
|    0   |                    (64bit)                      |
|--------|-------------------------------------------------|

Write Context Management request head (CMD_HW2SW_MPT), without payload
|--------|----------------------64bit-------------------------|
|  127:  |     type     |       opcode     |   R  | mpt_index |
    input  wire [63:0]                  uar_db_data ,
    output wire                         uar_db_ready,
    input  wire                         uar_db_valid,
|   64   | (WR_MPT_TPT) | (WR_MPT_INVALID) | void |  (32bit)  |
|--------|----------------------------------------------------|
|   63:  |                         R                          |
|    0   |                        void                        |
|--------|----------------------------------------------------|


与DMA读模块通信, 响应, 含payload:
DMA read response data (CMD_WRITE_MTT), first & second beat
// first beat
|--------|-------------------64bit-------------------------|------|
|  255:  |                        R                        | 1Ch- |
|  192   |                     (64bit)                     | 18h  |
|--------|-------------------------------------------------|------|
|  191:  |                        R                        | 14h- |
|  128   |                     (64bit)                     | 10h  |
|--------|-------------------------------------------------|------|
|  127:  |                        R                        | 0Ch- |
|   64   |                     (64bit)                     | 08h  |
|--------|-------------------------------------------------|------|
|   63:  |                 mtt_start_index                 | 04h- |
|    0   |                     (64bit)                     | 00h  |
|--------|-------------------------------------------------|------|
// second beat
|--------|-------------------64bit-------------------------|------|
|  255:  |                   mtt_phy_addr[3]               | 3Ch- |
|  192   |                     (64bit)                     | 38h  |
|--------|-------------------------------------------------|------|
|  191:  |                   mtt_phy_addr[2]               | 34h- |
|  128   |                     (64bit)                     | 30h  |
|--------|-------------------------------------------------|------|
|  127:  |                   mtt_phy_addr[1]               | 2Ch- |
|   64   |                     (64bit)                     | 28h  |
|--------|-------------------------------------------------|------|
|   63:  |                   mtt_phy_addr[0]               | 24h- |
|    0   |                     (64bit)                     | 20h  |
|--------|-------------------------------------------------|------|
*****************************************************************/
wire is_sw2hw_mpt, is_write_mtt, is_hw2sw_mpt, is_map_icm, is_unmap_icm;
reg is_write_mtt_reg;

wire [`AXIS_TYPE_WIDTH-1:0] typ;
wire [`AXIS_OPCODE_WIDTH-1:0] opcode;


// mpt_index        ->  in_modifier;
// mtt_num          ->  in_modifier;
// chunk_num        ->  in_modifier;
// page_cnt         ->  in_modifier;
// virt             ->  in_param;
// mtt_start_index  ->  dma_rd_rsp_data[127:64];
wire [63:0] mtt_start_index;
reg  [63:0] v2p_head_high;
reg  [63:0] v2p_head_low;
//------------------------{Decode & Packet generation}end---------------------------//

/* -------FSM relevant{begin}------- */
localparam  IDLE          = 3'b001,
            INBOX_V2P_REQ = 3'b010,
            BARE_V2P_REQ  = 3'b100;
reg [2:0] cur_state;
reg [2:0] nxt_state;

wire is_idle, is_inbox_v2p_req, is_bare_v2p_req;
wire j_inbox_v2p_req, j_bare_v2p_req;
/* -------FSM relevant{end}------- */

/* --------------------------------------------------------------------------------------------------- */

/* -------Decode & Packet generation{begin}------- */
assign is_map_icm   = (op == `CMD_MAP_ICM  );
assign is_unmap_icm = (op == `CMD_UNMAP_ICM);
assign is_sw2hw_mpt = (op == `CMD_SW2HW_MPT);
assign is_hw2sw_mpt = (op == `CMD_HW2SW_MPT);
assign is_write_mtt = (op == `CMD_WRITE_MTT);

always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        is_write_mtt_reg <= `TD 0;
    end
    else begin
        is_write_mtt_reg <= `TD is_write_mtt;
    end
end

assign typ   = ({`AXIS_TYPE_WIDTH  {is_map_icm  }} & `MAP_ICM_TPT) |
                ({`AXIS_TYPE_WIDTH  {is_unmap_icm}} & `MAP_ICM_TPT) |
                ({`AXIS_TYPE_WIDTH  {is_sw2hw_mpt}} & `WR_MPT_TPT ) |
                ({`AXIS_TYPE_WIDTH  {is_hw2sw_mpt}} & `WR_MPT_TPT ) |
                ({`AXIS_TYPE_WIDTH  {is_write_mtt}} & `WR_MTT_TPT );
assign opcode = ({`AXIS_OPCODE_WIDTH{is_map_icm  }} & `MAP_ICM_EN    ) |
                ({`AXIS_OPCODE_WIDTH{is_unmap_icm}} & `MAP_ICM_DIS   ) |
                ({`AXIS_OPCODE_WIDTH{is_sw2hw_mpt}} & `WR_MPT_WRITE  ) |
                ({`AXIS_OPCODE_WIDTH{is_hw2sw_mpt}} & `WR_MPT_INVALID) |
                ({`AXIS_OPCODE_WIDTH{is_write_mtt}} & `WR_MTT_WRITE  );

assign mtt_start_index = dma_rd_rsp_data[63:0];
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        v2p_head_low  <= `TD 0;
    end
    else if ((is_inbox_v2p_req | is_bare_v2p_req) & 
            v2p_req_valid & v2p_req_ready & v2p_req_last) begin
        v2p_head_low <= `TD 0;
    end
    else if (is_idle & start & is_write_mtt & dma_rd_rsp_valid & dma_rd_rsp_ready) begin
        v2p_head_low <= `TD mtt_start_index;
    end
    else if (is_idle & start & is_unmap_icm) begin
        v2p_head_low <= `TD in_param;
    end
end
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        v2p_head_high  <= `TD 0;
    end
    else if (j_inbox_v2p_req || j_bare_v2p_req) begin
        v2p_head_high <= `TD {typ, opcode, {32-`AXIS_TYPE_WIDTH-`AXIS_OPCODE_WIDTH{1'b0}}, in_modifier};
    end
end
/* -------Decode & Packet generation{end}------- */

//------------------------------{write v2p FSM}begin------------------------------//

/******************** Stage 1: State Register **********************/
always @(posedge clk or negedge rst_n) begin
    if(~rst_n)
        cur_state <= `TD IDLE;
    else
        cur_state <= `TD nxt_state;
end

/******************** Stage 2: State Transition **********************/
assign is_idle          = (cur_state == IDLE         );
assign is_inbox_v2p_req = (cur_state == INBOX_V2P_REQ);
assign is_bare_v2p_req  = (cur_state == BARE_V2P_REQ );

assign j_inbox_v2p_req = is_idle & start & has_inbox & dma_rd_rsp_valid;
assign j_bare_v2p_req  = is_idle & start & !has_inbox;

always @(*) begin
    case(cur_state)
        IDLE: begin
            if (start & has_inbox & dma_rd_rsp_valid) begin // DMA data is ready for transmission
                nxt_state = INBOX_V2P_REQ;
            end
            else if (start & !has_inbox) begin // There's no need of data, so jump to BARE_V2P_REQ
                nxt_state = BARE_V2P_REQ;
            end
            else begin
                nxt_state = IDLE;
            end
        end
        INBOX_V2P_REQ: begin
            if (v2p_req_valid & v2p_req_ready & v2p_req_last) begin // v2p write req data end
                nxt_state = IDLE;
            end
            else begin
                nxt_state = INBOX_V2P_REQ;
            end
        end
        BARE_V2P_REQ: begin
            if (v2p_req_valid & v2p_req_ready & v2p_req_last) begin // v2p write req data end
                nxt_state = IDLE;
            end
            else begin
                nxt_state = BARE_V2P_REQ;
            end
        end
        default: begin
            nxt_state = IDLE;
        end
    endcase
end
/******************** Stage 3: Output **********************/


/* ***** output ***** */
// virtual to physical write request
assign v2p_req_valid = (is_inbox_v2p_req & dma_rd_rsp_valid) | is_bare_v2p_req;
assign v2p_req_head = v2p_req_valid ? {v2p_head_high, v2p_head_low} : 0;
assign v2p_req_data = is_inbox_v2p_req ? dma_rd_rsp_data : 0;
assign v2p_req_last = (is_inbox_v2p_req & dma_rd_rsp_last) |
                      (is_bare_v2p_req);

// dma read response
assign dma_rd_rsp_ready = (is_idle          & is_write_mtt_reg) | // drain the first rsp data
                          (is_inbox_v2p_req & v2p_req_ready);

// finish
assign finish  = (is_inbox_v2p_req | is_bare_v2p_req) & v2p_req_ready & v2p_req_last;
/* ***** for output ***** */
//------------------------------{write v2p FSM}end------------------------------//

`ifdef CEU_DBG_LOGIC 
/* --------DBG signal{begin}-------- */
assign dbg_bus = {mtt_start_index, cur_state, nxt_state};
/* --------DBG signal{end}-------- */
`endif
endmodule
