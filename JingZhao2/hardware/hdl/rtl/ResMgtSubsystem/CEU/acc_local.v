`timescale 1ns / 100ps
//*************************************************************************
//   > File Name  : acc_local.v
//   > Description: CEU_ACC_LOACL, used to parse command for CEU, the command incudes:
//   >        inbox: N, outbox: Y:
//   >          CMD_QUERY_DEV_LIM, 
//   >          CMD_QUERY_ADAPTER
//   > Author: Corning
//   > Date  : 2020-07-14
//*************************************************************************

`include "ceu_def_h.vh"
`include "protocol_engine_def.vh"

module acc_local #(
    parameter DMA_HEAD_WIDTH     = 128            // DMA Stream *_head width
) (
    input  wire          clk,
    input  wire          rst_n,


    /* -------DMA Interface{begin}------- */
    /* dma_*_head(interact with RDMA modules), valid only in first beat of a packet
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    // DMA read response
    // input   wire                      dma_rd_rsp_valid, // i, 1
    // input   wire                      dma_rd_rsp_last , // i, 1
    // input   wire [`CEU_DATA_WIDTH-1  :0] dma_rd_rsp_data , // i, `CEU_DATA_WIDTH
    // input   wire [DMA_HEAD_WIDTH-1:0] dma_rd_rsp_head , // i, DMA_HEAD_WIDTH
    // output  wire                      dma_rd_rsp_ready, // o, 1

    // DMA write req
    output  wire                       dma_wr_req_valid, // o, 1
    output  wire                       dma_wr_req_last , // o, 1
    output  wire [`CEU_DATA_WIDTH-1:0] dma_wr_req_data , // o, `CEU_DATA_WIDTH
    output  wire [DMA_HEAD_WIDTH -1:0] dma_wr_req_head , // o, DMA_HEAD_WIDTH
    input   wire                       dma_wr_req_ready, // i, 1
    /* -------DMA Interface{end}------- */

    /* -------CMD Information{begin}------- */
    input  wire [11:0] op         ,
    input  wire [63:0] outbox_addr,
    input  wire [7 :0] op_modifier,
    output wire        is_bad_nvmem, // indicate if firmware is ready, 1 means not ready.
    /* -------CMD Information{end}------- */



    input  wire  start ,
    output wire  finish

`ifdef CEU_DBG_LOGIC 
    /* -------APB reated signal{begin}------- */
    ,input  wire [`ACC_LOCAL_RW_WIDTH -1:0] rw_data      // i, `ACC_LOCAL_RW_WIDTH; read-writer register interface
	,output wire [`ACC_LOCAL_RW_WIDTH -1:0] rw_init_data // o, `ACC_LOCAL_RW_WIDTH
    ,output wire [`ACC_LOCAL_DBG_WIDTH-1:0] dbg_bus      // o, `ACC_LOCAL_DBG_WIDTH; debug bus data	
    /* -------APB reated signal{end}------- */
`endif
);

/* -------Store NIC Information{begin}------- */
reg [`CEU_DATA_WIDTH-1:0] dev_lim_info[1:0];
reg [`CEU_DATA_WIDTH-1:0] adapter_info;
reg [`CEU_DATA_WIDTH-1:0] mad_port_info;

always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        dev_lim_info[0] <= `TD 0;
        dev_lim_info[1] <= `TD 0;
        adapter_info    <= `TD 0;
        mad_port_info   <= `TD 0;
    end
`ifdef CEU_DBG_LOGIC 
    else if (rw_data[`ACC_LOCAL_RW_WIDTH-1]) begin
        {dev_lim_info[1], dev_lim_info[0], adapter_info, mad_port_info} <= `TD rw_data[`ACC_LOCAL_RW_WIDTH-2:0];
    end
`else
    else begin
        dev_lim_info[0] <= `TD {
            `RESVED_QPS, `RESVED_CQS, `RESVED_EQS, `RESVED_MTTS,
            8'd0, `RESVED_PDS, 8'd0, `RESVED_LKEYS,
            `MAX_QP_SZ, `MAX_CQ_SZ,
            `MAX_QPS, `MAX_CQS, `MAX_EQS, `MAX_MPTS,
            `MAX_PDS, 8'd0, `MAX_GIDS, `MAX_PKEYS,
            8'd0, `MAX_MTT_SEG, 16'd0, 
            `QPC_ENTRY_SZ, `CQC_ENTRY_SZ, 
            `EQC_ENTRY_SZ, `MPT_ENTRY_SZ
        };
        dev_lim_info[1] <= `TD {
            4'd0, `ACK_DELAY, `MAX_MTU, `MAX_PORT_WIDTH, 8'd0, `MAX_VL, `NUM_PORTS,
            8'd0, `MIN_PAGE_SZ, 16'd0, 
            8'd0, `MAX_SG, `MAX_DESC_SZ,
            8'd0, `MAX_SG_RQ, `MAX_DESC_SZ_RQ,
            `MAX_ICM_SZ,
            32'd0,
            32'd0
        };
        adapter_info    <= `TD {
            32'd0, 
            32'd0, 
            32'd0, 
            32'd0, 
            32'd0, 
            32'd0,
            `BOARD_ID
        };
        mad_port_info   <= `TD {
            16'd1, 8'd2, 8'd3, // lid, state, phy_state
            32'd0, // GUID
            32'd0, // GUID
            32'd0, // GUID
            32'd0, // GUID
            32'd0, 
            32'd0, 
            32'd0
        };
    end
`endif
end
/* -------Store NIC Information{end}------- */


/* -------decode & head generation{begin}------- */
/*************************head*************************************
dma write outbox req head
|--------| --------------------64bit---------------------- |
|  127:  |            R            |     outbox_addr       |
|   64   |         (63:32)         |     (63:32 bit)       |
|--------|-------------------------------------------------|
|   63:  |       outbox_addr       |    R    | outbox_len  |
|    0   |       (31: 0 bit)       | (31:12) | (11:0 bit)  |
|--------|-------------------------------------------------|
 *****************************************************************/
// wire is_cmd_valid;
wire is_query_dev_lim, is_query_adapter, is_mad_ifc;

wire [DMA_HEAD_WIDTH-1:0] head;
wire [11:0] outbox_len; // in bytes

/* -------decode & head generation{end}------- */

/* ------- FSM relevant{begin}------- */
localparam  IDLE   = 3'b001, // Wait for start signal comming
            SEND_0 = 3'b010, // Send first beat of data & head
            SEND_1 = 3'b100; // Send second beat of data (only for dev_lim cmd)

reg [2:0] cur_state;
reg [2:0] nxt_state;

wire is_idle, is_send_0, is_send_1;
/* ------- FSM relevant{end}------- */


/* --------------------------------------------------------------------------------------------------- */


/* ------- decode & head generation{begin}------ */

// assign is_cmd_valid       = is_query_dev_lim | is_query_adapter;
assign is_query_dev_lim   = (op == `CMD_QUERY_DEV_LIM  );
assign is_query_adapter   = (op == `CMD_QUERY_ADAPTER  );
assign is_mad_ifc         = (op == `CMD_MAD_IFC        );

assign outbox_len = ({12{is_query_dev_lim}} & (`OUTBOX_LEN_QUERY_DEV_LIM)) |
                    ({12{is_query_adapter}} & (`OUTBOX_LEN_QUERY_ADAPTER)) |
                    ({12{is_mad_ifc      }} & (`OUTBOX_LEN_ATTR_PORT_INFO));

assign head       = {32'd0, outbox_addr, 20'd0, outbox_len};
/* ------- decode & head generation{end}------ */

//------------------------------{acc_local FSM}begin------------------------------//
/******************** Stage 1: State Register **********************/

assign is_idle   = (cur_state == IDLE  );
assign is_send_0 = (cur_state == SEND_0);
assign is_send_1 = (cur_state == SEND_1);

always @(posedge clk or negedge rst_n) begin
    if(~rst_n)
        cur_state <= `TD IDLE;
    else
        cur_state <= `TD nxt_state;
end

/******************** Stage 2: State Transition **********************/

always @(*) begin
    case(cur_state)
        IDLE: begin
            if (start) begin 
                nxt_state = SEND_0;
            end
            else begin
                nxt_state = IDLE;
            end
        end
        SEND_0: begin
            if (dma_wr_req_valid & dma_wr_req_ready) begin
                nxt_state = ({3{is_query_adapter}} & IDLE  ) |
                            ({3{is_mad_ifc      }} & IDLE  ) |
                            ({3{is_query_dev_lim}} & SEND_1);
            end
            else begin
                nxt_state = SEND_0;
            end
        end
        SEND_1: begin
            if (dma_wr_req_valid & dma_wr_req_ready) begin
                nxt_state = IDLE;
            end
            else begin
                nxt_state = SEND_1;
            end
        end
        default: begin
            nxt_state = IDLE;
        end
    endcase
end

/******************** Stage 3: Output **********************/

/* -------output------- */
assign dma_wr_req_valid = is_send_0 | is_send_1;
assign dma_wr_req_last  = (is_query_adapter & is_send_0) |
                          (is_mad_ifc       & is_send_0) |
                          (is_query_dev_lim & is_send_1);
assign dma_wr_req_data  = ({`CEU_DATA_WIDTH{is_query_adapter & is_send_0}} & adapter_info ) |
                          ({`CEU_DATA_WIDTH{is_mad_ifc       & is_send_0}} & mad_port_info) |
                          ({`CEU_DATA_WIDTH{is_query_dev_lim & is_send_0}} & dev_lim_info[0]) |
                          ({`CEU_DATA_WIDTH{is_query_dev_lim & is_send_1}} & dev_lim_info[1]);
assign dma_wr_req_head  = (is_send_0 | is_send_1) ? head : {DMA_HEAD_WIDTH{1'd0}};



// status
assign is_bad_nvmem = 1'd0;

// finish 
assign finish = dma_wr_req_valid & dma_wr_req_ready & dma_wr_req_last;
/* ***** output ***** */
//------------------------------{get_inbox FSM}end------------------------------//

`ifdef CEU_DBG_LOGIC 
/* --------DBG signal{begin}-------- */
wire [`CEU_DATA_WIDTH-1:0] init_dev_lim_info_w0;
wire [`CEU_DATA_WIDTH-1:0] init_dev_lim_info_w1;
wire [`CEU_DATA_WIDTH-1:0] init_adapter_info_w ;
wire [`CEU_DATA_WIDTH-1:0] init_mad_port_info_w;

assign init_dev_lim_info_w0 = {
    `RESVED_QPS, `RESVED_CQS, `RESVED_EQS, `RESVED_MTTS,
    8'd0, `RESVED_PDS, 8'd0, `RESVED_LKEYS,
    `MAX_QP_SZ, `MAX_CQ_SZ,
    `MAX_QPS, `MAX_CQS, `MAX_EQS, `MAX_MPTS,
    `MAX_PDS, 8'd0, `MAX_GIDS, `MAX_PKEYS,
    8'd0, `MAX_MTT_SEG, 16'd0, 
    `QPC_ENTRY_SZ, `CQC_ENTRY_SZ, 
    `EQC_ENTRY_SZ, `MPT_ENTRY_SZ
};
assign init_dev_lim_info_w1 = {
    4'd0, `ACK_DELAY, `MAX_MTU, `MAX_PORT_WIDTH, 8'd0, `MAX_VL, `NUM_PORTS,
    8'd0, `MIN_PAGE_SZ, 16'd0, 
    8'd0, `MAX_SG, `MAX_DESC_SZ,
    8'd0, `MAX_SG_RQ, `MAX_DESC_SZ_RQ,
    `MAX_ICM_SZ,
    32'd0,
    32'd0
};
assign init_adapter_info_w = {
    32'd0, 
    32'd0, 
    32'd0, 
    32'd0, 
    32'd0, 
    32'd0,
    `BOARD_ID
};
assign init_mad_port_info_w = {
    16'd1, 8'd2, 8'd3, // lid, state, phy_state
    32'd0, // GUID
    32'd0, // GUID
    32'd0, // GUID
    32'd0, // GUID
    32'd0, 
    32'd0, 
    32'd0
};
assign rw_init_data = {
    1'd1, // control signal
    init_dev_lim_info_w1,
    init_dev_lim_info_w0,
    init_adapter_info_w ,
    init_mad_port_info_w
};

assign dbg_bus = {
    dev_lim_info[1],
    dev_lim_info[0],
    adapter_info   ,
    mad_port_info  ,
    cur_state      ,
    nxt_state      
};
/* --------DBG signal{end}-------- */
`endif
endmodule
