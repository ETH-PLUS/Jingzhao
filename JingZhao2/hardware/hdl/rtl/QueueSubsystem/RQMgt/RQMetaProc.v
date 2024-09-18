/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       RQMetaProc
Author:     YangFan
Function:   Fetch RQ Memory Region.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module RQMetaProc
#(
    parameter                       INGRESS_CXT_HEAD_WIDTH                  =   128,
    parameter                       INGRESS_CXT_DATA_WIDTH                  =   256,
    parameter                       EGRESS_CXT_HEAD_WIDTH                   =   128,
    parameter                       EGRESS_CXT_DATA_WIDTH                   =   256,

    parameter                       INGRESS_MR_HEAD_WIDTH                   =   128,
    parameter                       INGRESS_MR_DATA_WIDTH                   =   256,
    parameter                       EGRESS_MR_HEAD_WIDTH                    =   128,
    parameter                       EGRESS_MR_DATA_WIDTH                    =   256


)
(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with ReqRecvCore
    input   wire                                                            wqe_req_valid,
    input   wire    [`WQE_META_WIDTH - 1 : 0]                               wqe_req_head,
    input   wire                                                            wqe_req_start,
    input   wire                                                            wqe_req_last,
    output  wire                                                            wqe_req_ready,

//Interface with RQOffsetRecord
    output  wire                                                            rq_offset_wen,
    output  wire    [23:0]                                                  rq_offset_din,
    output  wire    [`QP_NUM_LOG - 1 : 0]                                   rq_offset_addr,
    input   wire    [23:0]                                                  rq_offset_dout,

//Interface with MRMgt    
    output  wire                                                            fetch_mr_ingress_valid,
    output  wire   [`RQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]                  fetch_mr_ingress_head, 
    output  wire   [`RQ_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]                  fetch_mr_ingress_data,
    output  wire                                                            fetch_mr_ingress_start,
    output  wire                                                            fetch_mr_ingress_last,
    input   wire                                                            fetch_mr_ingress_ready,

    input   wire                                                            fetch_mr_egress_valid,
    input   wire   [`RQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]                   fetch_mr_egress_head,
    input   wire   [`RQ_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]                   fetch_mr_egress_data,
    input   wire                                                            fetch_mr_egress_start,
    input   wire                                                            fetch_mr_egress_last,
    output  wire                                                            fetch_mr_egress_ready,
    
//Interface with WQEFetch
    output  wire                                                            rq_meta_valid,
    output  wire    [`SQ_META_WIDTH - 1 : 0]                                rq_meta_data,
    input   wire                                                            rq_meta_ready

);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     LOCAL_QPN_OFFSET                23:0
`define     RQ_ENTRY_SZ_LOG_OFFSET          31:24
`define     RQ_LKEY_OFFSET                  63:32
`define     RQ_LENGTH_OFFSET                95:64
`define     QP_PD_OFFSET                    127:96
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire            [`INGRESS_COMMON_HEAD_WIDTH - 1 : 0]            ingress_common_head;
wire            [`MAX_OOO_SLOT_NUM_LOG - 1 :0]                  ingress_slot_count;

reg             [`WQE_META_WIDTH - 1 : 0]                       wqe_req_head_diff;

wire            [15:0]                                          local_qpn;
wire            [7:0]                                           rq_entry_sz_log;
wire            [31:0]                                          rq_length;
wire            [31:0]                                          rq_lkey;
wire            [31:0]                                          qp_pd;

reg             [31:0]                                          mr_flags;
reg             [3:0]                                           mr_flag_sw_owns;
reg                                                             mr_flag_absolute_addr;
reg                                                             mr_flag_relative_addr;
reg                                                             mr_flag_mio;
reg                                                             mr_flag_bind_enable;
reg                                                             mr_flag_physical;
reg                                                             mr_flag_region;
reg                                                             mr_flag_on_demand;
reg                                                             mr_flag_zero_based;
reg                                                             mr_flag_mw_bind;
reg                                                             mr_remote_read;
reg                                                             mr_remote_write;
reg                                                             mr_local_write;

wire            [31:0]                                          mr_length;
wire            [63:0]                                          mr_laddr;
wire            [31:0]                                          mr_lkey;
wire            [31:0]                                          mr_pd;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg         [1:0]               cur_state;
reg         [1:0]               next_state;

parameter   [1:0]               IDLE_s      =   2'd1,
                                STAGED_s    =   2'd2,
                                FETCH_MR_s  =   2'd3;

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
        IDLE_s:         if(wqe_req_valid) begin
                            next_state = FETCH_MR_s;
                        end
                        else begin
                            next_state = IDLE_s;
                        end
        STAGED_s:       next_state = FETCH_MR_s;
        FETCH_MR_s:     if(fetch_mr_ingress_valid && fetch_mr_ingress_ready) begin
                            next_state = IDLE_s;
                        end
                        else begin
                            next_state = FETCH_MR_s;
                        end
        default:        next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- wqe_req_head_diff --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        wqe_req_head_diff <= 'd0;        
    end
    else if (cur_state == IDLE_s && wqe_req_valid) begin
        wqe_req_head_diff <= wqe_req_head;
    end
    else begin
        wqe_req_head_diff <= wqe_req_head_diff;
    end
end

//-- local_qpn --
//-- rq_entry_sz_log --
//-- rq_length --
//-- rq_lkey --
//-- qp_pd --
assign local_qpn = wqe_req_head_diff[`LOCAL_QPN_OFFSET];
assign rq_entry_sz_log = wqe_req_head_diff[`RQ_ENTRY_SZ_LOG_OFFSET];
assign rq_length = wqe_req_head_diff[`RQ_LENGTH_OFFSET];
assign rq_lkey = wqe_req_head_diff[`RQ_LKEY_OFFSET];
assign qp_pd = wqe_req_head_diff[`QP_PD_OFFSET];

//-- ingress_common_head --
//-- ingress_slot_count --
assign ingress_slot_count = (cur_state == FETCH_MR_s) ? 'd1 : 'd0;
assign ingress_common_head = (cur_state == FETCH_MR_s) ? {`NO_BYPASS, ingress_slot_count, local_qpn[`MAX_QP_NUM_LOG - 1 : 0]} : 'd0;

//-- mr_length --
//-- mr_laddr --
//-- mr_lkey --
//-- mr_pd --
assign mr_length = (cur_state == FETCH_MR_s && (rq_offset_dout * 16) + `RQ_PREFETCH_LENGTH > rq_length) ? (rq_length - (rq_offset_dout * 16)) :
                    (cur_state == FETCH_MR_s && (rq_offset_dout * 16) + `RQ_PREFETCH_LENGTH <= rq_length) ? `RQ_PREFETCH_LENGTH : 'd0;
assign mr_laddr = (cur_state == FETCH_MR_s) ? (rq_offset_dout * 16) : 'd0;
assign mr_lkey = rq_lkey;
assign mr_pd = qp_pd;

//-- mr_flag_sw_owns --
//-- mr_flag_absolute_addr --
//-- mr_flag_relative_addr --
//-- mr_flag_mio --
//-- mr_flag_bind_enable --
//-- mr_flag_physical --
//-- mr_flag_on_demand --
//-- mr_flag_zero_based --
//-- mr_flag_mw_bind --
//-- mr_remote_read --
//-- mr_remote_write --
//-- mr_local_write --
always @(*) begin
    if(rst) begin
        mr_flag_sw_owns = 'd0;
        mr_flag_absolute_addr = 'd0;
        mr_flag_relative_addr = 'd0;
        mr_flag_mio = 'd0;
        mr_flag_bind_enable = 'd0;
        mr_flag_physical = 'd0;
        mr_flag_region = 'd0;
        mr_flag_on_demand = 'd0;
        mr_flag_zero_based = 'd0;
        mr_flag_mw_bind = 'd0;
        mr_remote_read = 'd0;
        mr_remote_write = 'd0;
        mr_local_write = 'd0;
    end
    else if(cur_state == FETCH_MR_s) begin
        mr_flag_sw_owns = 'd0;
        mr_flag_absolute_addr = 'd0;
        mr_flag_relative_addr = 'd1;
        mr_flag_mio = 'd0;
        mr_flag_bind_enable = 'd0;
        mr_flag_physical = 'd0;
        mr_flag_region = 'd0;
        mr_flag_on_demand = 'd0;
        mr_flag_zero_based = 'd0;
        mr_flag_mw_bind = 'd0;
        mr_remote_read = 'd0;
        mr_remote_write = 'd0;
        mr_local_write = 'd0;       
    end
    else begin
        mr_flag_sw_owns = 'd0;
        mr_flag_absolute_addr = 'd0;
        mr_flag_relative_addr = 'd1;
        mr_flag_mio = 'd0;
        mr_flag_bind_enable = 'd0;
        mr_flag_physical = 'd0;
        mr_flag_region = 'd0;
        mr_flag_on_demand = 'd0;
        mr_flag_zero_based = 'd0;
        mr_flag_mw_bind = 'd0;
        mr_remote_read = 'd0;
        mr_remote_write = 'd0;
        mr_local_write = 'd0;   
    end
end

//-- mr_flags --
always @(*) begin
    if(rst) begin
        mr_flags = 'd0;
    end
    else if(cur_state == FETCH_MR_s) begin
        mr_flags =  {
                                mr_flag_sw_owns,
                                mr_flag_absolute_addr,
                                mr_flag_relative_addr,
                                8'd0,
                                mr_flag_mio,
                                1'd0,
                                mr_flag_bind_enable,
                                5'd0,
                                mr_flag_physical,
                                mr_flag_region,
                                1'd0,
                                mr_flag_on_demand,
                                mr_flag_zero_based,
                                mr_flag_mw_bind,
                                mr_remote_read,
                                mr_remote_write,
                                mr_local_write
                            };
    end
    else begin
        mr_flags = 'd0;
    end
end

//-- wqe_req_ready --
assign wqe_req_ready = (cur_state == IDLE_s) ? 'd1 : 'd0;

//-- rq_offset_wen --
assign rq_offset_wen = 'd0;

//-- rq_offset_din --
assign rq_offset_din = 'd0;

//-- rq_offset_addr --
assign rq_offset_addr = (cur_state == IDLE_s) ? wqe_req_head[`LOCAL_QPN_OFFSET] : local_qpn;

//-- fetch_mr_ingress_valid --
//-- fetch_mr_ingress_head --
//-- fetch_mr_ingress_data --
//-- fetch_mr_ingress_start --
//-- fetch_mr_ingress_last --
assign fetch_mr_ingress_valid = (cur_state == FETCH_MR_s) ? 'd1 : 'd0;
assign fetch_mr_ingress_head = (cur_state == FETCH_MR_s) ? {mr_length, mr_laddr, mr_lkey, mr_pd, mr_flags, ingress_common_head} : 'd0;
assign fetch_mr_ingress_data = (cur_state == FETCH_MR_s) ? wqe_req_head_diff : 'd0;
assign fetch_mr_ingress_start = (cur_state == FETCH_MR_s) ? 'd1 : 'd0;
assign fetch_mr_ingress_last = (cur_state == FETCH_MR_s) ? 'd1 : 'd0;

//-- fetch_mr_egress_ready --
assign fetch_mr_egress_ready = rq_meta_ready;

//-- rq_meta_valid --
//-- rq_meta_data --
assign rq_meta_valid = fetch_mr_egress_valid;
assign rq_meta_data = { fetch_mr_egress_head[`MR_RESP_HEAD_WIDTH + `EGRESS_COMMON_HEAD_WIDTH - 1 : `EGRESS_COMMON_HEAD_WIDTH], 
                        32'd0,
                        32'd0,
                        48'd0,
                        48'd0,
                        qp_pd,
                        rq_length,
                        16'd0,
                        rq_entry_sz_log,
                        8'd0,
                        16'd0,
                        local_qpn
                        }; 
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef     LOCAL_QPN_OFFSET
`undef     RQ_ENTRY_SZ_LOG_OFFSET
`undef     RQ_LKEY_OFFSET
`undef     RQ_LENGTH_OFFSET
`undef     QP_PD_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule