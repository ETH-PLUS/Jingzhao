/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       SQMetaProc_Thread_2
Author:     YangFan
Function:   Fetch SQ Memory Region.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module SQMetaProc_Thread_2
(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with SQMetaProc_Thread_1
    input   wire                                                            fetch_cxt_egress_valid,
    input   wire    [`SQ_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]                 fetch_cxt_egress_head,  
    input   wire    [`SQ_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]                 fetch_cxt_egress_data,
    input   wire                                                            fetch_cxt_egress_start,
    input   wire                                                            fetch_cxt_egress_last,
    output  wire                                                            fetch_cxt_egress_ready,

//Interface with SQOffsetRecord
    output  wire    [0:0]                                                   sq_offset_wen,
    output  wire    [`QP_NUM_LOG - 1 : 0]                                   sq_offset_addr,
    output  wire    [23:0]                                                  sq_offset_din,
    input   wire    [23:0]                                                  sq_offset_dout,

//Interface with MRMgt    
    output  wire                                                            fetch_mr_ingress_valid,
    output  wire    [`SQ_OOO_MR_INGRESS_HEAD_WIDTH - 1 : 0]                 fetch_mr_ingress_head, 
    output  wire    [`SQ_OOO_MR_INGRESS_DATA_WIDTH - 1 : 0]                 fetch_mr_ingress_data,
    output  wire                                                            fetch_mr_ingress_start,
    output  wire                                                            fetch_mr_ingress_last,
    input   wire                                                            fetch_mr_ingress_ready,

    input   wire                                                            fetch_mr_egress_valid,
    input   wire    [`SQ_OOO_MR_EGRESS_HEAD_WIDTH - 1 : 0]                  fetch_mr_egress_head,
    input   wire    [`SQ_OOO_MR_EGRESS_DATA_WIDTH - 1 : 0]                  fetch_mr_egress_data,
    input   wire                                                            fetch_mr_egress_start,
    input   wire                                                            fetch_mr_egress_last,
    output  wire                                                            fetch_mr_egress_ready,
    
//Interface with WQEFetch
    output  wire                                                            sq_meta_valid,
    output  wire    [`SQ_META_WIDTH - 1 : 0]                                sq_meta_data,
    input   wire                                                            sq_meta_ready

);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/

/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire            [`INGRESS_COMMON_HEAD_WIDTH - 1 : 0]            ingress_common_head;
wire            [`MAX_OOO_SLOT_NUM_LOG - 1 :0]                  ingress_slot_count;

reg             [`SQ_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : 0]         cxt_head_diff;
reg             [`SQ_OOO_CXT_EGRESS_DATA_WIDTH - 1 : 0]         cxt_data_diff;



wire            [15:0]                                          local_qpn;
wire            [15:0]                                          remote_qpn;
wire            [2:0]                                           service_type;
wire            [47:0]                                          smac;
wire            [47:0]                                          dmac;
wire            [31:0]                                          sip;
wire            [31:0]                                          dip;
wire            [7:0]                                           sq_entry_sz_log;
wire            [31:0]                                          sq_length;
wire            [15:0]                                          pmtu;
wire            [31:0]                                          sq_lkey;
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

wire            [`CACHE_ENTRY_WIDTH_QPC - 1 : 0]                qp_cxt;
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
        IDLE_s:         if(fetch_cxt_egress_valid) begin
                            next_state = STAGED_s;
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
//-- cxt_head_diff --
//-- cxt_data_diff --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        cxt_head_diff <= 'd0;
        cxt_data_diff <= 'd0;
    end
    else if(cur_state == IDLE_s && fetch_cxt_egress_valid) begin
        cxt_head_diff <= fetch_cxt_egress_head;
        cxt_data_diff <= fetch_cxt_egress_data;
    end
    else begin
        cxt_head_diff <= cxt_head_diff;
        cxt_data_diff <= cxt_data_diff;
    end
end

//-- qp_cxt --
assign qp_cxt = cxt_head_diff[`CACHE_ENTRY_WIDTH_QPC + `EGRESS_COMMON_HEAD_WIDTH - 1 : `EGRESS_COMMON_HEAD_WIDTH];

//-- local_qpn --
//-- remote_qpn --
//-- service_type --
//-- smac --
//-- dmac --
//-- sip --
//-- dip --
//-- sq_entry_sz_log --
//-- sq_length --
//-- pmtu --
//-- sq_lkey --
//-- qp_pd --
assign local_qpn = cxt_head_diff[`QP_NUM_LOG - 1:0];
assign remote_qpn = qp_cxt[`QP_CXT_DST_QPN_OFFSET];
assign service_type = qp_cxt[`QP_CXT_SERVICE_TYPE_OFFSET];
assign smac = qp_cxt[`QP_CXT_SMAC_OFFSET];
assign dmac = qp_cxt[`QP_CXT_DMAC_OFFSET];
assign sip = qp_cxt[`QP_CXT_SIP_OFFSET];
assign dip = qp_cxt[`QP_CXT_DIP_OFFSET];
assign sq_entry_sz_log = qp_cxt[`QP_CXT_SQ_ENTRY_SZ_LOG_OFFSET];
assign sq_length = qp_cxt[`QP_CXT_SQ_LENGTH_OFFSET];
assign pmtu = qp_cxt[`QP_CXT_PMTU_OFFSET];
assign qp_pd = qp_cxt[`QP_CXT_PD_OFFSET];
assign sq_lkey = qp_cxt[`QP_CXT_SQ_LKEY_OFFSET];

//-- ingress_common_head --
//-- ingress_slot_count --
assign ingress_slot_count = (cur_state == FETCH_MR_s) ? 'd1 : 'd0;
assign ingress_common_head = (cur_state == FETCH_MR_s) ? {`NO_BYPASS, ingress_slot_count, local_qpn[`MAX_QP_NUM_LOG - 1 : 0]} : 'd0;

//-- mr_length --
//-- mr_laddr --
//-- mr_lkey --
//-- mr_pd --
assign mr_length = (cur_state == FETCH_MR_s && (sq_offset_dout * 16) + `SQ_PREFETCH_LENGTH > sq_length) ? (sq_length - (sq_offset_dout * 16)) :
                    (cur_state == FETCH_MR_s && (sq_offset_dout * 16) + `SQ_PREFETCH_LENGTH <= sq_length) ? `SQ_PREFETCH_LENGTH : 'd0;
assign mr_laddr = (cur_state == FETCH_MR_s) ? (sq_offset_dout * 16) : 'd0;
assign mr_lkey = sq_lkey;
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

//-- fetch_cxt_egress_ready --
assign fetch_cxt_egress_ready = (cur_state == IDLE_s) ? 'd1 : 'd0;

//-- sq_offset_addr --
assign sq_offset_addr = local_qpn;

//-- sq_offset_wen --
assign sq_offset_wen = 'd0;

//-- sq_offset_din --
assign sq_offset_din = 'd0;

//-- fetch_mr_ingress_valid --
//-- fetch_mr_ingress_head --
//-- fetch_mr_ingress_data --
//-- fetch_mr_ingress_start --
//-- fetch_mr_ingress_last --
assign fetch_mr_ingress_valid = (cur_state == FETCH_MR_s) ? 'd1 : 'd0;
assign fetch_mr_ingress_head = (cur_state == FETCH_MR_s) ? {mr_length, mr_laddr, mr_lkey, mr_pd, mr_flags, ingress_common_head} : 'd0;
assign fetch_mr_ingress_data = (cur_state == FETCH_MR_s) ? cxt_head_diff[`SQ_OOO_CXT_EGRESS_HEAD_WIDTH - 1 : `EGRESS_COMMON_HEAD_WIDTH] : 'd0;
assign fetch_mr_ingress_start = (cur_state == FETCH_MR_s) ? 'd1 : 'd0;
assign fetch_mr_ingress_last = (cur_state == FETCH_MR_s) ? 'd1 : 'd0;

//-- fetch_mr_egress_ready --
assign fetch_mr_egress_ready = sq_meta_ready;

wire            [15:0]                                          meta_local_qpn;
wire            [15:0]                                          meta_remote_qpn;
wire            [7:0]                                           meta_service_type;
wire            [47:0]                                          meta_smac;
wire            [47:0]                                          meta_dmac;
wire            [31:0]                                          meta_sip;
wire            [31:0]                                          meta_dip;
wire            [7:0]                                           meta_sq_entry_sz_log;
wire            [15:0]                                          meta_pmtu;
wire            [31:0]                                          meta_qp_pd;
wire            [31:0]                                          meta_sq_length;

assign meta_local_qpn = {'d0, fetch_mr_egress_head[`QP_NUM_LOG - 1 : 0]};
assign meta_remote_qpn = {'d0, fetch_mr_egress_data[`QP_CXT_DST_QPN_OFFSET]};
assign meta_service_type = {'d0, fetch_mr_egress_data[`QP_CXT_SERVICE_TYPE_OFFSET]};
assign meta_smac = fetch_mr_egress_data[`QP_CXT_SMAC_OFFSET];
assign meta_dmac = fetch_mr_egress_data[`QP_CXT_DMAC_OFFSET];
assign meta_sip = fetch_mr_egress_data[`QP_CXT_SIP_OFFSET];
assign meta_dip = fetch_mr_egress_data[`QP_CXT_DIP_OFFSET];
assign meta_sq_entry_sz_log = fetch_mr_egress_data[`QP_CXT_SQ_ENTRY_SZ_LOG_OFFSET];
assign meta_pmtu = 128 << fetch_mr_egress_data[`QP_CXT_PMTU_OFFSET];
assign meta_qp_pd = fetch_mr_egress_data[`QP_CXT_PD_OFFSET];
assign meta_sq_length = fetch_mr_egress_data[`QP_CXT_SQ_LENGTH_OFFSET];

//-- sq_meta_valid --
//-- sq_meta_data --
assign sq_meta_valid = fetch_mr_egress_valid;
assign sq_meta_data = { fetch_mr_egress_head[`MR_RESP_HEAD_WIDTH + `EGRESS_COMMON_HEAD_WIDTH - 1 : `EGRESS_COMMON_HEAD_WIDTH], 
                        meta_sip,
                        meta_dip,
                        meta_smac,
                        meta_dmac,
                        meta_qp_pd,
                        meta_sq_length,
                        meta_pmtu,
                        meta_sq_entry_sz_log,
                        meta_service_type,
                        meta_remote_qpn,
                        meta_local_qpn
                        };     //Piece MR info, Context info together
/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule