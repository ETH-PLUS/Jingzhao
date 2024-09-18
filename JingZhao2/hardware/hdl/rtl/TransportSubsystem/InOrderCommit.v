/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       InOrderCommit
Author:     YangFan
Function:   Commit packet in-order.
            This thread is triggered by metadata passed from OutOfOrderAccept. It iterates from the start PSN in the metadata,
            commits the PSN-continuous packets in the packet buffer until there is a "hole" in the PSN range.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "ib_constant_def_h.vh"
`include "common_function_def.vh"
`include "transport_subsystem_def.vh"
`include "global_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module InOrderCommit (
    input   wire                                                                clk,
    input   wire                                                                rst,

//Metadata from OutOfOrderAccept
    input   wire                                                                i_pkt_meta_empty,
    input   wire        [`PKT_META_WIDTH - 1 : 0]                               iv_pkt_meta_dout,
    output  wire                                                                o_pkt_meta_rd_en,

    //Delete Packet
    output  wire                                                                o_delete_req_valid,
    output  wire        [`QP_NUM_LOG + `PSN_WIDTH + `RECV_BUFFER_SLOT_NUM_LOG - 1 : 0]           ov_delete_req_head,
    input   wire                                                                i_delete_req_ready,

    input   wire                                                                i_delete_resp_valid,
    input   wire        [`PKT_HEAD_WIDTH - 1 : 0]                               iv_delete_resp_head,
    input   wire        [`PKT_DATA_WIDTH - 1 : 0]                               iv_delete_resp_data,
    input   wire                                                                i_delete_resp_start,
    input   wire                                                                i_delete_resp_last,
    output  wire                                                                o_delete_resp_ready,                                                 

    //Find a Packet
    output  wire                                                                o_find_req_valid,
    output  wire        [`QP_NUM_LOG + `PSN_WIDTH - 1 : 0]                      ov_find_req_head,
    input   wire                                                                i_find_resp_valid,
    input   wire        [`PKT_SLOT_NUM_LOG + `RECV_BUFFER_SLOT_NUM_LOG : 0]                                  iv_find_resp_data,

    //EPSN control
    output  wire        [`QP_NUM_LOG - 1 : 0]                                   ov_epsn_rd_index,
    input   wire        [`PSN_WIDTH - 1 : 0]                                    iv_epsn_rd_data,
    output  wire                                                                o_epsn_wr_en,
    output  wire        [`QP_NUM_LOG - 1 : 0]                                   ov_epsn_wr_index,
    output  wire        [`PSN_WIDTH - 1 : 0]                                    ov_epsn_wr_data,

//Interface with ULP
    output  wire                                                                o_commit_valid,
    output  wire        [`PKT_HEAD_WIDTH - 1 : 0]                               ov_commit_head,
    output  wire        [`PKT_DATA_WIDTH - 1 : 0]                               ov_commit_data,
    output  wire                                                                o_commit_start,
    output  wire                                                                o_commit_last,
    input   wire                                                                i_commit_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire            [23:0]                          wv_qpn;
wire            [23:0]                          wv_commit_lower_bound;
wire            [23:0]                          wv_commit_upper_bound;

reg             [23:0]                          qv_qpn;
reg             [23:0]                          qv_curPSN;
reg             [23:0]                          qv_commit_lower_bound;
reg             [23:0]                          qv_commit_upper_bound;

reg                                             q_delete_start;

/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
//NULL
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg                 [2:0]               ioc_cur_state;
reg                 [2:0]               ioc_next_state;

parameter           [2:0]               IOC_IDLE_s = 3'd1,
                                        IOC_COMMIT_s = 3'd2;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        ioc_cur_state <= IOC_IDLE_s;
    end
    else begin
        ioc_cur_state <= ioc_next_state;
    end
end

always @(*) begin
    case(ioc_cur_state) 
        IOC_IDLE_s:             if(!i_pkt_meta_empty) begin
                                    ioc_next_state = IOC_COMMIT_s;
                                end                     
                                else begin
                                    ioc_next_state = IOC_IDLE_s;
                                end
        IOC_COMMIT_s:           if(i_delete_resp_valid && i_delete_resp_last && i_commit_ready) begin
                                    if(qv_curPSN == qv_commit_upper_bound) begin
                                        ioc_next_state = IOC_IDLE_s;
                                    end
                                    else begin
                                        ioc_next_state = IOC_COMMIT_s;
                                    end
                                end
                                else begin
                                    ioc_next_state = IOC_COMMIT_s;
                                end
        default:                ioc_next_state = IOC_IDLE_s;
    endcase
end

/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- wv_qpn --
assign wv_qpn = iv_pkt_meta_dout[`META_QPN_OFFSET];

//-- wv_commit_lower_bound --
assign wv_commit_lower_bound = iv_pkt_meta_dout[`META_LOWER_BOUND_OFFSET];

//-- wv_commit_upper_bound --
assign wv_commit_upper_bound = iv_pkt_meta_dout[`META_UPPER_BOUND_OFFSET];

//-- qv_qpn --
//-- qv_commit_lower_bound --
//-- qv_commit_upper_bound --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_qpn <= 'd0;
        qv_commit_lower_bound <= 'd0;
    end
    else if(ioc_cur_state == IOC_IDLE_s && !i_pkt_meta_empty) begin
        qv_qpn <= wv_qpn;
        qv_commit_lower_bound <= wv_commit_lower_bound;
        qv_commit_upper_bound <= wv_commit_upper_bound;
    end
    else begin
        qv_qpn <= wv_qpn;
        qv_commit_lower_bound <= qv_commit_lower_bound;
        qv_commit_upper_bound <= qv_commit_upper_bound;
    end
end

//-- qv_curPSN --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_curPSN <= 'd0;     
    end
    else if(ioc_cur_state == IOC_IDLE_s && !i_pkt_meta_empty) begin
        qv_curPSN <= wv_commit_lower_bound;
    end
    else if(ioc_cur_state == IOC_COMMIT_s && i_delete_resp_last && i_commit_ready) begin
        qv_curPSN <= (qv_curPSN < qv_commit_upper_bound) ? qv_curPSN + 1 : 'd0;
    end
    else begin
        qv_curPSN <= qv_curPSN;
    end
end

//-- q_delete_start --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_delete_start <= 'd0;
    end
    else if(ioc_cur_state == IOC_IDLE_s && !i_pkt_meta_empty) begin
        q_delete_start <= 'd1;
    end
    else if(ioc_cur_state == IOC_COMMIT_s && q_delete_start) begin
        q_delete_start <= 'd0;
    end
    else if(ioc_cur_state == IOC_COMMIT_s && i_delete_resp_last && i_commit_ready) begin
        q_delete_start <= (ioc_next_state != IOC_IDLE_s) ? 'd1 : 'd0;
    end
    else begin
        q_delete_start <= q_delete_start;
    end
end

//-- o_pkt_meta_rd_en --
assign o_pkt_meta_rd_en = (ioc_cur_state != IOC_IDLE_s && ioc_next_state == IOC_IDLE_s) && !i_pkt_meta_empty;

//-- o_delete_req_valid --
assign o_delete_req_valid = q_delete_start;

//-- ov_delete_req_head --
assign ov_delete_req_head = q_delete_start ? {qv_curPSN, qv_qpn} : 'd0;

//-- o_delete_resp_ready --
assign o_delete_resp_ready = i_commit_ready;

//-- o_commit_valid --
assign o_commit_valid = (ioc_cur_state == IOC_COMMIT_s) && i_delete_resp_valid;

//-- ov_commit_head --
assign ov_commit_head = (ioc_cur_state == IOC_COMMIT_s) && i_delete_resp_valid && i_delete_resp_start ? {'d0, iv_delete_resp_head[247:8], iv_delete_resp_head[7:0] - 8'd3} : 'd0;    //Remove PSN

//-- ov_commit_data --
assign ov_commit_data = (ioc_cur_state == IOC_COMMIT_s) ? iv_delete_resp_data : 'd0;

//-- o_commit_start --
assign o_commit_start = (ioc_cur_state == IOC_COMMIT_s) ? i_delete_resp_start : 'd0;

//-- o_commit_last --
assign o_commit_last = (ioc_cur_state == IOC_COMMIT_s) ? i_delete_resp_last : 'd0;

//-- ov_epsn_rd_index --
assign ov_epsn_rd_index = 'd0;

//-- o_epsn_wr_en --
assign o_epsn_wr_en = 'd0;

//-- ov_epsn_wr_index --
assign ov_epsn_wr_index = 'd0;

//-- ov_epsn_wr_data --
assign ov_epsn_wr_data = 'd0;

//-- o_find_req_valid --
assign o_find_req_valid = 'd0;

//-- ov_find_req_head --
assign ov_find_req_head = 'd0;

/*------------------------------------------- Variables Decode : End ------------------------------------------------*/
endmodule