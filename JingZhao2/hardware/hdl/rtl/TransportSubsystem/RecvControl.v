/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       RecvControl
Author:     YangFan
Function:   Wrapper for OutOfOrderAccept, InOrderCommit and PacketBufferMgt.
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
module RecvControl #(
    parameter       SLOT_WIDTH = 512,
    parameter       SLOT_NUM = 512,
    parameter       SLOT_NUM_LOG = log2b(SLOT_NUM - 1)
)(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with Network
    input   wire                                                            i_packet_in_valid,
    input   wire                [`PKT_HEAD_WIDTH - 1 : 0]                   iv_packet_in_head,
    input   wire                [`PKT_DATA_WIDTH - 1 : 0]                   iv_packet_in_data,
    input   wire                                                            i_packet_in_start,
    input   wire                                                            i_packet_in_last,
    output  wire                                                            o_packet_in_ready,

//EPSN control
    output  wire                                                            o_ooa_epsn_wr_en,
    output  wire                [`QP_NUM_LOG - 1 : 0]                       ov_ooa_epsn_wr_index,
    output  wire                [`PSN_WIDTH - 1 : 0]                        ov_ooa_epsn_wr_data,
    output  wire                [`QP_NUM_LOG - 1 : 0]                       ov_ooa_epsn_rd_index,
    input   wire                [`PSN_WIDTH - 1 : 0]                        iv_ooa_epsn_rd_data,

    output  wire                [`QP_NUM_LOG - 1 : 0]                       ov_ioc_epsn_rd_index,
    input   wire                [`PSN_WIDTH - 1 : 0]                        iv_ioc_epsn_rd_data,
    output  wire                                                            o_ioc_epsn_wr_en,
    output  wire                [`QP_NUM_LOG - 1 : 0]                       ov_ioc_epsn_wr_index,
    output  wire                [`PSN_WIDTH - 1 : 0]                        ov_ioc_epsn_wr_data,

//Interface with ULP
    output  wire                                                            o_commit_valid,
    output  wire                [`PKT_HEAD_WIDTH - 1 : 0]                   ov_commit_head,
    output  wire                [`PKT_DATA_WIDTH - 1 : 0]                   ov_commit_data,
    output  wire                                                            o_commit_start,
    output  wire                                                            o_commit_last,
    input   wire                                                            i_commit_ready,

//ACK out
    output  wire                                                            o_packet_out_valid,
    output  wire                [`PKT_HEAD_WIDTH - 1 : 0]                   ov_packet_out_head,
    output  wire                [`PKT_DATA_WIDTH - 1 : 0]                   ov_packet_out_data,
    output  wire                                                            o_packet_out_start,
    output  wire                                                            o_packet_out_last,
    input   wire                                                            i_packet_out_ready

);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                                                w_packet_in_valid_in_reg;
wire                [`PKT_HEAD_WIDTH - 1 : 0]                       wv_packet_in_head_in_reg;
wire                [`PKT_DATA_WIDTH - 1 : 0]                       wv_packet_in_data_in_reg;
wire                                                                w_packet_in_start_in_reg;
wire                                                                w_packet_in_last_in_reg;
wire                                                                w_packet_in_ready_in_reg;

wire                                                                w_commit_valid_axis;
wire                [`PKT_HEAD_WIDTH - 1 : 0]                       wv_commit_head_axis;
wire                [`PKT_DATA_WIDTH - 1 : 0]                       wv_commit_data_axis;
wire                                                                w_commit_start_axis;
wire                                                                w_commit_last_axis;
wire                                                                w_commit_ready_axis;

wire                                                                w_packet_out_valid_axis;
wire                [`PKT_HEAD_WIDTH - 1 : 0]                       wv_packet_out_head_axis;
wire                [`PKT_DATA_WIDTH - 1 : 0]                       wv_packet_out_data_axis;
wire                                                                w_packet_out_start_axis;
wire                                                                w_packet_out_last_axis;
wire                                                                w_packet_out_ready_axis;

wire                                                                w_unreliable_pkt_in_valid_axis;
wire                [`PKT_HEAD_WIDTH - 1 : 0]                       wv_unreliable_pkt_in_head_axis;
wire                [`PKT_DATA_WIDTH - 1 : 0]                       wv_unreliable_pkt_in_data_axis;
wire                                                                w_unreliable_pkt_in_start_axis;
wire                                                                w_unreliable_pkt_in_last_axis;
wire                                                                w_unreliable_pkt_in_ready_axis;

wire                                                                w_unreliable_pkt_in_valid_in_reg;
wire                [`PKT_HEAD_WIDTH - 1 : 0]                       wv_unreliable_pkt_in_head_in_reg;
wire                [`PKT_DATA_WIDTH - 1 : 0]                       wv_unreliable_pkt_in_data_in_reg;
wire                                                                w_unreliable_pkt_in_start_in_reg;
wire                                                                w_unreliable_pkt_in_last_in_reg;
wire                                                                w_unreliable_pkt_in_ready_in_reg;

wire                                                                w_reliable_pkt_in_valid_axis;
wire                [`PKT_HEAD_WIDTH - 1 : 0]                       wv_reliable_pkt_in_head_axis;
wire                [`PKT_DATA_WIDTH - 1 : 0]                       wv_reliable_pkt_in_data_axis;
wire                                                                w_reliable_pkt_in_start_axis;
wire                                                                w_reliable_pkt_in_last_axis;
wire                                                                w_reliable_pkt_in_ready_axis;

wire                                                                w_reliable_pkt_in_valid_in_reg;
wire                [`PKT_HEAD_WIDTH - 1 : 0]                       wv_reliable_pkt_in_head_in_reg;
wire                [`PKT_DATA_WIDTH - 1 : 0]                       wv_reliable_pkt_in_data_in_reg;
wire                                                                w_reliable_pkt_in_start_in_reg;
wire                                                                w_reliable_pkt_in_last_in_reg;
wire                                                                w_reliable_pkt_in_ready_in_reg;


wire                [`SEND_BUFFER_SLOT_NUM_LOG - 1 : 0]             wv_available_slot_num;
wire                                                                w_insert_req_valid_axis;
wire                [`PKT_HEAD_WIDTH - 1 : 0]                       wv_insert_req_head_axis;
wire                [`PKT_DATA_WIDTH - 1 : 0]                       wv_insert_req_data_axis;
wire                                                                w_insert_req_start_axis;
wire                                                                w_insert_req_last_axis;
wire                                                                w_insert_req_ready_axis;

wire                                                                w_insert_req_valid_in_reg;
wire                [`PKT_HEAD_WIDTH - 1 : 0]                       wv_insert_req_head_in_reg;
wire                [`PKT_DATA_WIDTH - 1 : 0]                       wv_insert_req_data_in_reg;
wire                                                                w_insert_req_start_in_reg;
wire                                                                w_insert_req_last_in_reg;
wire                                                                w_insert_req_ready_in_reg;

wire                                                                w_delete_req_valid_axis;
wire                [`QP_NUM_LOG + `PSN_WIDTH + SLOT_NUM - 1 : 0]   wv_delete_req_head_axis;
wire                                                                w_delete_req_ready_axis;

wire                                                                w_delete_req_valid_in_reg;
wire                [`QP_NUM_LOG + `PSN_WIDTH + SLOT_NUM - 1 : 0]   wv_delete_req_head_in_reg;
wire                                                                w_delete_req_ready_in_reg; 

wire                                                                w_delete_resp_valid_axis;
wire                [`PKT_HEAD_WIDTH - 1 : 0]                       wv_delete_resp_head_axis;
wire                [`PKT_DATA_WIDTH - 1 : 0]                       wv_delete_resp_data_axis;
wire                                                                w_delete_resp_start_axis;
wire                                                                w_delete_resp_last_axis;
wire                                                                w_delete_resp_ready_axis;

wire                                                                w_delete_resp_valid_in_reg;
wire                [`PKT_HEAD_WIDTH - 1 : 0]                       wv_delete_resp_head_in_reg;
wire                [`PKT_DATA_WIDTH - 1 : 0]                       wv_delete_resp_data_in_reg;
wire                                                                w_delete_resp_start_in_reg;
wire                                                                w_delete_resp_last_in_reg;
wire                                                                w_delete_resp_ready_in_reg;

wire                                                                w_ooa_find_req_valid_axis;
wire                [`QP_NUM_LOG + `PSN_WIDTH - 1 : 0]              wv_ooa_find_req_head_axis;
wire                                                                w_ooa_find_resp_valid_axis;
wire                [`PKT_SLOT_NUM_LOG + SLOT_NUM_LOG : 0]          wv_ooa_find_resp_data_axis;

wire                                                                w_ooa_find_req_valid_in_reg;
wire                [`QP_NUM_LOG + `PSN_WIDTH - 1 : 0]              wv_ooa_find_req_head_in_reg;
wire                                                                w_ooa_find_resp_valid_in_reg;
wire                [`PKT_SLOT_NUM_LOG + SLOT_NUM_LOG : 0]          wv_ooa_find_resp_data_in_reg;

wire                                                                w_ioc_find_req_valid_axis;
wire                [`QP_NUM_LOG + `PSN_WIDTH - 1 : 0]              wv_ioc_find_req_head_axis;
wire                                                                w_ioc_find_resp_valid_axis;
wire                [`PKT_SLOT_NUM_LOG + SLOT_NUM_LOG : 0]          wv_ioc_find_resp_data_axis;

wire                                                                w_ioc_find_req_valid_in_reg;
wire                [`QP_NUM_LOG + `PSN_WIDTH - 1 : 0]              wv_ioc_find_req_head_in_reg;
wire                                                                w_ioc_find_resp_valid_in_reg;
wire                [`PKT_SLOT_NUM_LOG + SLOT_NUM_LOG : 0]          wv_ioc_find_resp_data_in_reg;

wire                                                                w_pkt_meta_wr_en;
wire                [`PKT_META_WIDTH - 1 : 0]                       wv_pkt_meta_din;
wire                                                                w_pkt_meta_prog_full;
wire                                                                w_pkt_meta_rd_en;
wire                [`PKT_META_WIDTH - 1 : 0]                       wv_pkt_meta_dout;
wire                                                                w_pkt_meta_empty;

/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
stream_fifo #(
    .TUSER_WIDTH(`PKT_HEAD_WIDTH),
    .TDATA_WIDTH(`PKT_DATA_WIDTH)
)
PacketInFIFO_Inst
(
    .clk  (clk),
    .rst_n(~rst),

    .axis_tvalid    (i_packet_in_valid),
    .axis_tuser     (iv_packet_in_head),
    .axis_tdata     (iv_packet_in_data),
    .axis_tstart    (i_packet_in_start),
    .axis_tlast     (i_packet_in_last),
    .axis_tready    (o_packet_in_ready),
    .axis_tkeep     ('d0),

    .in_reg_tvalid  (w_packet_in_valid_in_reg),
    .in_reg_tuser   (wv_packet_in_head_in_reg),
    .in_reg_tdata   (wv_packet_in_data_in_reg),
    .in_reg_tstart  (w_packet_in_start_in_reg),
    .in_reg_tlast   (w_packet_in_last_in_reg),
    .in_reg_tready  (w_packet_in_ready_in_reg),
    .in_reg_tkeep   (),
    .tuser_clear    ('d0)
);

stream_fifo #(
    .TUSER_WIDTH(`PKT_HEAD_WIDTH),
    .TDATA_WIDTH(`PKT_DATA_WIDTH)
)
UnreliablePktFIFO_Inst
(
    .clk  (clk),
    .rst_n(~rst),

    .axis_tvalid    (w_unreliable_pkt_in_valid_axis),
    .axis_tuser     (wv_unreliable_pkt_in_head_axis),
    .axis_tdata     (wv_unreliable_pkt_in_data_axis),
    .axis_tstart    (w_unreliable_pkt_in_start_axis),
    .axis_tlast     (w_unreliable_pkt_in_last_axis),
    .axis_tready    (w_unreliable_pkt_in_ready_axis),
    .axis_tkeep     ('d0),

    .in_reg_tvalid  (w_unreliable_pkt_in_valid_in_reg),
    .in_reg_tuser   (wv_unreliable_pkt_in_head_in_reg),
    .in_reg_tdata   (wv_unreliable_pkt_in_data_in_reg),
    .in_reg_tstart  (w_unreliable_pkt_in_start_in_reg),
    .in_reg_tlast   (w_unreliable_pkt_in_last_in_reg),
    .in_reg_tready  (w_unreliable_pkt_in_ready_in_reg),
    .in_reg_tkeep   (),
    .tuser_clear    ('d0)
);

stream_fifo #(
    .TUSER_WIDTH(`PKT_HEAD_WIDTH),
    .TDATA_WIDTH(`PKT_DATA_WIDTH)
)
ReliablePktFIFO_Inst
(
    .clk  (clk),
    .rst_n(~rst),

    .axis_tvalid    (w_reliable_pkt_in_valid_axis),
    .axis_tuser     (wv_reliable_pkt_in_head_axis),
    .axis_tdata     (wv_reliable_pkt_in_data_axis),
    .axis_tstart    (w_reliable_pkt_in_start_axis),
    .axis_tlast     (w_reliable_pkt_in_last_axis),
    .axis_tready    (w_reliable_pkt_in_ready_axis),
    .axis_tkeep     ('d0),

    .in_reg_tvalid  (w_reliable_pkt_in_valid_in_reg),
    .in_reg_tuser   (wv_reliable_pkt_in_head_in_reg),
    .in_reg_tdata   (wv_reliable_pkt_in_data_in_reg),
    .in_reg_tstart  (w_reliable_pkt_in_start_in_reg),
    .in_reg_tlast   (w_reliable_pkt_in_last_in_reg),
    .in_reg_tready  (w_reliable_pkt_in_ready_in_reg),
    .in_reg_tkeep   (),
    .tuser_clear    ('d0)
);

stream_fifo #(
    .TUSER_WIDTH(`PKT_HEAD_WIDTH),
    .TDATA_WIDTH(`PKT_DATA_WIDTH)
)
CommitFIFO_Inst
(
    .clk  (clk),
    .rst_n(~rst),

    .axis_tvalid    (w_commit_valid_axis),
    .axis_tuser     (wv_commit_head_axis),
    .axis_tdata     (wv_commit_data_axis),
    .axis_tstart    (w_commit_start_axis),
    .axis_tlast     (w_commit_last_axis),
    .axis_tready    (w_commit_ready_axis),
    .axis_tkeep     ('d0),

    .in_reg_tvalid  (o_commit_valid),
    .in_reg_tuser   (ov_commit_head),
    .in_reg_tdata   (ov_commit_data),
    .in_reg_tstart  (o_commit_start),
    .in_reg_tlast   (o_commit_last),
    .in_reg_tready  (i_commit_ready),
    .in_reg_tkeep   (),
    .tuser_clear    ('d0)
);

stream_fifo #(
    .TUSER_WIDTH(`PKT_HEAD_WIDTH),
    .TDATA_WIDTH(`PKT_DATA_WIDTH)
)
PacketOutFIFO_Inst
(
    .clk  (clk),
    .rst_n(~rst),

    .axis_tvalid    (w_packet_out_valid_axis),
    .axis_tuser     (wv_packet_out_head_axis),
    .axis_tdata     (wv_packet_out_data_axis),
    .axis_tstart    (w_packet_out_start_axis),
    .axis_tlast     (w_packet_out_last_axis),
    .axis_tready    (w_packet_out_ready_axis),
    .axis_tkeep     ('d0),

    .in_reg_tvalid  (o_packet_out_valid),
    .in_reg_tuser   (ov_packet_out_head),
    .in_reg_tdata   (ov_packet_out_data),
    .in_reg_tstart  (o_packet_out_start),
    .in_reg_tlast   (o_packet_out_last),
    .in_reg_tready  (i_packet_out_ready),
    .in_reg_tkeep   (),
    .tuser_clear    ('d0)
);

stream_reg #(
    .TUSER_WIDTH(`PKT_HEAD_WIDTH),
    .TDATA_WIDTH(`PKT_DATA_WIDTH)
)
InsertStream_Inst
(
    .clk  (clk),
    .rst_n(~rst),

    .axis_tvalid    (w_insert_req_valid_axis),
    .axis_tuser     (wv_insert_req_head_axis),
    .axis_tdata     (wv_insert_req_data_axis),
    .axis_tstart    (w_insert_req_start_axis),
    .axis_tlast     (w_insert_req_last_axis),
    .axis_tready    (w_insert_req_ready_axis),
    .axis_tkeep     ('d0),

    .in_reg_tvalid  (w_insert_req_valid_in_reg),
    .in_reg_tuser   (wv_insert_req_head_in_reg),
    .in_reg_tdata   (wv_insert_req_data_in_reg),
    .in_reg_tstart  (w_insert_req_start_in_reg),        
    .in_reg_tlast   (w_insert_req_last_in_reg), 
    .in_reg_tready  (w_insert_req_ready_in_reg),
    .in_reg_tkeep   (),
    .tuser_clear    ('d0)
);

stream_reg #(
    .TUSER_WIDTH(`PKT_HEAD_WIDTH),
    .TDATA_WIDTH(`PKT_DATA_WIDTH)
)
DeleteReqStream_Inst
(
    .clk  (clk),
    .rst_n(~rst),

    .axis_tvalid    (w_delete_req_valid_axis),
    .axis_tuser     (wv_delete_req_head_axis),
    .axis_tdata     ('d0),
    .axis_tstart    ('d0),
    .axis_tlast     ('d0),
    .axis_tready    (w_delete_req_ready_axis),
    .axis_tkeep     ('d0),

    .in_reg_tvalid  (w_delete_req_valid_in_reg),
    .in_reg_tuser   (wv_delete_req_head_in_reg),
    .in_reg_tdata   (wv_delete_req_data_in_reg),
    .in_reg_tstart  (w_delete_req_start_in_reg),        
    .in_reg_tlast   (w_delete_req_last_in_reg), 
    .in_reg_tready  (w_delete_req_ready_in_reg),
    .in_reg_tkeep   (),
    .tuser_clear    ('d0)
);

stream_reg #(
    .TUSER_WIDTH(`PKT_HEAD_WIDTH),
    .TDATA_WIDTH(`PKT_DATA_WIDTH)
)
DeleteRespStream_Inst
(
    .clk  (clk),
    .rst_n(~rst),

    .axis_tvalid    (w_delete_resp_valid_axis),
    .axis_tuser     (wv_delete_resp_head_axis),
    .axis_tdata     (wv_delete_resp_data_axis),
    .axis_tstart    (w_delete_resp_start_axis),
    .axis_tlast     (w_delete_resp_last_axis),
    .axis_tready    (w_delete_resp_ready_axis),
    .axis_tkeep     ('d0),

    .in_reg_tvalid  (w_delete_resp_valid_in_reg),
    .in_reg_tuser   (wv_delete_resp_head_in_reg),
    .in_reg_tdata   (wv_delete_resp_data_in_reg),
    .in_reg_tstart  (w_delete_resp_start_in_reg),        
    .in_reg_tlast   (w_delete_resp_last_in_reg), 
    .in_reg_tready  (w_delete_resp_ready_in_reg),
    .in_reg_tkeep   (),
    .tuser_clear    ('d0)
);

stream_reg #(
    .TUSER_WIDTH(`PKT_HEAD_WIDTH),
    .TDATA_WIDTH(`PKT_DATA_WIDTH)
)
OOAFindReqStream_Inst
(
    .clk  (clk),
    .rst_n(~rst),

    .axis_tvalid    (w_ooa_find_req_valid_axis),
    .axis_tuser     (wv_ooa_find_req_head_axis),
    .axis_tdata     ('d0),
    .axis_tstart    ('d0),
    .axis_tlast     ('d0),
    .axis_tready    (),
    .axis_tkeep     ('d0),

    .in_reg_tvalid  (w_ooa_find_req_valid_in_reg),
    .in_reg_tuser   (wv_ooa_find_req_head_in_reg),
    .in_reg_tdata   (),
    .in_reg_tstart  (),        
    .in_reg_tlast   (), 
    .in_reg_tready  ('d1),
    .in_reg_tkeep   (),
    .tuser_clear    ('d0)
);

stream_reg #(
    .TUSER_WIDTH(`PKT_HEAD_WIDTH),
    .TDATA_WIDTH(`PKT_SLOT_NUM_LOG + SLOT_NUM_LOG + 1)
)
OOAFindRespStream_Inst
(
    .clk  (clk),
    .rst_n(~rst),

    .axis_tvalid    (w_ooa_find_resp_valid_axis),
    .axis_tuser     ('d0),
    .axis_tdata     (wv_ooa_find_resp_data_axis),
    .axis_tstart    ('d0),
    .axis_tlast     ('d0),
    .axis_tready    (),
    .axis_tkeep     ('d0),

    .in_reg_tvalid  (w_ooa_find_resp_valid_in_reg),
    .in_reg_tuser   (),
    .in_reg_tdata   (wv_ooa_find_resp_data_in_reg),
    .in_reg_tstart  (),        
    .in_reg_tlast   (), 
    .in_reg_tready  ('d1),
    .in_reg_tkeep   (),
    .tuser_clear    ('d0)
);

stream_reg #(
    .TUSER_WIDTH(`PKT_HEAD_WIDTH),
    .TDATA_WIDTH(`PKT_DATA_WIDTH)
)
IOCFindReqStream_Inst
(
    .clk  (clk),
    .rst_n(~rst),

    .axis_tvalid    (w_ioc_find_req_valid_axis),
    .axis_tuser     (wv_ioc_find_req_head_axis),
    .axis_tdata     ('d0),
    .axis_tstart    ('d0),
    .axis_tlast     ('d0),
    .axis_tready    (),
    .axis_tkeep     ('d0),

    .in_reg_tvalid  (w_ioc_find_req_valid_in_reg),
    .in_reg_tuser   (wv_ioc_find_req_head_in_reg),
    .in_reg_tdata   (),
    .in_reg_tstart  (),        
    .in_reg_tlast   (), 
    .in_reg_tready  ('d1),
    .in_reg_tkeep   (),
    .tuser_clear    ('d0)
);

stream_reg #(
    .TUSER_WIDTH(`PKT_HEAD_WIDTH),
    .TDATA_WIDTH(`PKT_SLOT_NUM_LOG + SLOT_NUM_LOG + 1)
)
IOCFindRespStream_Inst
(
    .clk  (clk),
    .rst_n(~rst),

    .axis_tvalid    (w_ioc_find_resp_valid_axis),
    .axis_tuser     ('d0),
    .axis_tdata     (wv_ioc_find_resp_data_axis),
    .axis_tstart    ('d0),
    .axis_tlast     ('d0),
    .axis_tready    (),
    .axis_tkeep     ('d0),

    .in_reg_tvalid  (w_ioc_find_resp_valid_in_reg),
    .in_reg_tuser   (),
    .in_reg_tdata   (wv_ioc_find_resp_data_in_reg),
    .in_reg_tstart  (),        
    .in_reg_tlast   (), 
    .in_reg_tready  ('d1),
    .in_reg_tkeep   (),
    .tuser_clear    ('d0)
);

OutOfOrderAccept OutOfOrderAccept_Inst(
    .clk(clk),
    .rst(rst),
    
    .i_packet_in_valid(w_packet_in_valid_in_reg),
    .iv_packet_in_head(wv_packet_in_head_in_reg),
    .iv_packet_in_data(wv_packet_in_data_in_reg),
    .i_packet_in_start(w_packet_in_start_in_reg),
    .i_packet_in_last(w_packet_in_last_in_reg),
    .o_packet_in_ready(w_packet_in_ready_in_reg),
    
    .ov_epsn_rd_index(ov_ooa_epsn_rd_index),
    .iv_epsn_rd_data(iv_ooa_epsn_rd_data),
    .o_epsn_wr_en(o_ooa_epsn_wr_en),
    .ov_epsn_wr_index(ov_ooa_epsn_wr_index),
    .ov_epsn_wr_data(ov_ooa_epsn_wr_data),

    .o_find_req_valid(w_ooa_find_req_valid_axis),
    .ov_find_req_head(wv_ooa_find_req_head_axis),
    .i_find_resp_valid(w_ooa_find_resp_valid_in_reg),
    .iv_find_resp_data(wv_ooa_find_resp_data_in_reg),

    .iv_available_slot_num(wv_available_slot_num),
    .o_insert_req_valid(w_insert_req_valid_axis),
    .ov_insert_req_head(wv_insert_req_head_axis),
    .ov_insert_req_data(wv_insert_req_data_axis),
    .o_insert_req_start(w_insert_req_start_axis),
    .o_insert_req_last(w_insert_req_last_axis),
    .i_insert_req_ready(w_insert_req_ready_axis),
    
    .o_commit_valid(w_unreliable_pkt_in_valid_axis),
    .ov_commit_head(wv_unreliable_pkt_in_head_axis),
    .ov_commit_data(wv_unreliable_pkt_in_data_axis),
    .o_commit_start(w_unreliable_pkt_in_start_axis),
    .o_commit_last(w_unreliable_pkt_in_last_axis),
    .i_commit_ready(w_unreliable_pkt_in_ready_axis),
    
    .o_ack_out_valid(w_packet_out_valid_axis),
    .ov_ack_out_head(wv_packet_out_head_axis),
    .ov_ack_out_data(wv_packet_out_data_axis),
    .o_ack_out_start(w_packet_out_start_axis),
    .o_ack_out_last(w_packet_out_last_axis),
    .i_ack_out_ready(w_packet_out_ready_axis),
    
    .o_pkt_meta_wr_en(w_pkt_meta_wr_en),
    .ov_pkt_meta_din(wv_pkt_meta_din),
    .i_pkt_meta_prog_full(w_pkt_meta_prog_full)
);

InOrderCommit InOrderCommit_Inst(
    .clk(clk),
    .rst(rst),

    .i_pkt_meta_empty(w_pkt_meta_empty),
    .iv_pkt_meta_dout(wv_pkt_meta_dout),
    .o_pkt_meta_rd_en(w_pkt_meta_rd_en),

    .ov_epsn_rd_index(ov_ioc_epsn_rd_index),
    .iv_epsn_rd_data(iv_ioc_epsn_rd_data),
    .o_epsn_wr_en(o_ioc_epsn_wr_en),
    .ov_epsn_wr_index(ov_ioc_epsn_wr_index),
    .ov_epsn_wr_data(ov_ioc_epsn_wr_data),

    .o_delete_req_valid(w_delete_req_valid_axis),
    .ov_delete_req_head(wv_delete_req_head_axis),
    .i_delete_req_ready(w_delete_req_ready_axis),

    .i_delete_resp_valid(w_delete_resp_valid_in_reg),
    .iv_delete_resp_head(wv_delete_resp_head_in_reg),
    .iv_delete_resp_data(wv_delete_resp_data_in_reg),
    .i_delete_resp_start(w_delete_resp_start_in_reg),
    .i_delete_resp_last(w_delete_resp_last_in_reg),
    .o_delete_resp_ready(w_delete_resp_ready_in_reg), 

    .o_find_req_valid(w_ioc_find_req_valid_axis),
    .ov_find_req_head(wv_ioc_find_req_head_axis),
    .i_find_resp_valid(w_ioc_find_resp_valid_in_reg),
    .iv_find_resp_data(wv_ioc_find_resp_data_in_reg),

    .o_commit_valid(w_reliable_pkt_in_valid_axis),
    .ov_commit_head(wv_reliable_pkt_in_head_axis),
    .ov_commit_data(wv_reliable_pkt_in_data_axis),
    .o_commit_start(w_reliable_pkt_in_start_axis),
    .o_commit_last(w_reliable_pkt_in_last_axis),
    .i_commit_ready(w_reliable_pkt_in_ready_axis)
);

PacketBufferMgt
#(
    .SLOT_WIDTH(`PKT_DATA_WIDTH),
    .SLOT_NUM(`RECV_BUFFER_SLOT_NUM)
)
PacketBufferMgt_Inst(
    .clk(clk),
    .rst(rst),

    .ov_available_slot_num(wv_available_slot_num),
    .i_insert_req_valid(w_insert_req_valid_in_reg),
    .iv_insert_req_head(wv_insert_req_head_in_reg),
    .iv_insert_req_data(wv_insert_req_data_in_reg),
    .i_insert_req_start(w_insert_req_start_in_reg),
    .i_insert_req_last(w_insert_req_last_in_reg),
    .o_insert_req_ready(w_insert_req_ready_in_reg),

    .i_delete_req_valid(w_delete_req_valid_in_reg),
    .iv_delete_req_head(wv_delete_req_head_in_reg),
    .o_delete_req_ready(w_delete_req_ready_in_reg),

    .o_delete_resp_valid(w_delete_resp_valid_axis),
    .ov_delete_resp_head(wv_delete_resp_head_axis),
    .ov_delete_resp_data(wv_delete_resp_data_axis),
    .o_delete_resp_start(w_delete_resp_start_axis),
    .o_delete_resp_last(w_delete_resp_last_axis),
    .i_delete_resp_ready(w_delete_resp_ready_axis),

    .i_find_req_valid_A(w_ooa_find_req_valid_in_reg),
    .iv_find_req_head_A(wv_ooa_find_req_head_in_reg),
    .o_find_resp_valid_A(w_ooa_find_resp_valid_axis),
    .ov_find_resp_data_A(wv_ooa_find_resp_data_axis),

    .i_find_req_valid_B(w_ioc_find_req_valid_in_reg),
    .iv_find_req_head_B(wv_ioc_find_req_head_in_reg),
    .o_find_resp_valid_B(w_ioc_find_resp_valid_axis),
    .ov_find_resp_data_B(wv_ioc_find_resp_data_axis),

    .i_get_req_valid('d0),
    .iv_get_req_head('d0),

    .o_get_resp_valid(),
    .ov_get_resp_head(),
    .ov_get_resp_data(),
    .o_get_resp_start(),
    .o_get_resp_last(),
    .i_get_resp_ready('d0)
);

PacketArbiter CommitArbiter_Inst(
    .clk(clk),
    .rst(rst),

    .i_channel_0_valid(w_unreliable_pkt_in_valid_in_reg),
    .iv_channel_0_head(wv_unreliable_pkt_in_head_in_reg),
    .iv_channel_0_data(wv_unreliable_pkt_in_data_in_reg),
    .i_channel_0_start(w_unreliable_pkt_in_start_in_reg),
    .i_channel_0_last(w_unreliable_pkt_in_last_in_reg),
    .o_channel_0_ready(w_unreliable_pkt_in_ready_in_reg), 

    .i_channel_1_valid(w_reliable_pkt_in_valid_in_reg),
    .iv_channel_1_head(wv_reliable_pkt_in_head_in_reg),
    .iv_channel_1_data(wv_reliable_pkt_in_data_in_reg),
    .i_channel_1_start(w_reliable_pkt_in_start_in_reg),
    .i_channel_1_last(w_reliable_pkt_in_last_in_reg),
    .o_channel_1_ready(w_reliable_pkt_in_ready_in_reg),  

    .o_channel_out_valid(w_commit_valid_axis),
    .ov_channel_out_head(wv_commit_head_axis),
    .ov_channel_out_data(wv_commit_data_axis),
    .o_channel_out_start(w_commit_start_axis),
    .o_channel_out_last(w_commit_last_axis),
    .i_channel_out_ready(w_commit_ready_axis)
);

SyncFIFO_Template #(
    .FIFO_WIDTH(`PKT_META_WIDTH),
    .FIFO_DEPTH(32)
)
PacketMetaDataFIFO_inst
(
    .clk(clk),
    .rst(rst),

    .wr_en(w_pkt_meta_wr_en),
    .din(wv_pkt_meta_din),
    .prog_full(w_pkt_meta_prog_full),
    .rd_en(w_pkt_meta_rd_en),
    .dout(wv_pkt_meta_dout),
    .empty(w_pkt_meta_empty),
    .data_count()
);

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
//Null
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//Null
/*------------------------------------------- Variables Decode : End ------------------------------------------------*/
endmodule