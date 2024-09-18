/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       SendControl
Author:     YangFan
Function:   Wrapper for InOrderInject, SelectiveRepeat, and PacketBufferMgt.
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
module SendControl #(
    parameter       SLOT_WIDTH = 512,
    parameter       SLOT_NUM = 512,
    parameter       SLOT_NUM_LOG = log2b(SLOT_NUM - 1)
)(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Packet-In
    input   wire                                                            i_packet_in_valid,
    input   wire        [`PKT_HEAD_WIDTH - 1 : 0]                           iv_packet_in_head,
    input   wire        [`PKT_DATA_WIDTH - 1 : 0]                           iv_packet_in_data,
    input   wire                                                            i_packet_in_start,
    input   wire                                                            i_packet_in_last,
    output  wire                                                            o_packet_in_ready,

//NPSN control
    output  wire                                                             o_npsn_wr_en,
    output  wire         [`QP_NUM_LOG - 1 : 0]                               ov_npsn_wr_index,
    output  wire         [`PSN_WIDTH - 1 : 0]                                ov_npsn_wr_data,
    output  wire         [`QP_NUM_LOG - 1 : 0]                               ov_npsn_rd_index,
    input   wire         [`PSN_WIDTH - 1 : 0]                                iv_npsn_rd_data,

//Packet-Out
    output  wire                                                             o_packet_out_valid,
    output  wire         [`PKT_HEAD_WIDTH - 1 : 0]                           ov_packet_out_head,
    output  wire         [`PKT_DATA_WIDTH - 1 : 0]                           ov_packet_out_data,
    output  wire                                                             o_packet_out_start,
    output  wire                                                             o_packet_out_last,
    input   wire                                                             i_packet_out_ready,

    //ACK in
    input   wire                                                             i_ack_in_valid,
    input   wire         [`PKT_HEAD_WIDTH - 1 : 0]                           iv_ack_in_head,
    input   wire         [`PKT_DATA_WIDTH - 1 : 0]                           iv_ack_in_data,
    input   wire                                                             i_ack_in_start,
    input   wire                                                             i_ack_in_last,
    output  wire                                                             o_ack_in_ready,

//UPSN control
    output  wire         [`QP_NUM_LOG - 1 : 0]                               ov_upsn_rd_index,
    input   wire         [`PSN_WIDTH - 1 : 0]                                iv_upsn_rd_data,
    output  wire                                                             o_upsn_wr_en,
    output  wire         [`QP_NUM_LOG - 1 : 0]                               ov_upsn_wr_index,
    output  wire         [`PSN_WIDTH - 1 : 0]                                ov_upsn_wr_data
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                                           w_packet_in_valid_in_reg;
wire        [`PKT_HEAD_WIDTH - 1 : 0]                          wv_packet_in_head_in_reg;
wire        [`PKT_DATA_WIDTH - 1 : 0]                          wv_packet_in_data_in_reg;
wire                                                           w_packet_in_start_in_reg;
wire                                                           w_packet_in_last_in_reg;
wire                                                           w_packet_in_ready_in_reg;

wire                                                           w_packet_out_valid_axis;
wire        [`PKT_HEAD_WIDTH - 1 : 0]                          wv_packet_out_head_axis;
wire        [`PKT_DATA_WIDTH - 1 : 0]                          wv_packet_out_data_axis;
wire                                                           w_packet_out_start_axis;
wire                                                           w_packet_out_last_axis;
wire                                                           w_packet_out_ready_axis;

wire                                                           w_ack_in_valid_in_reg;
wire        [`PKT_HEAD_WIDTH - 1 : 0]                          wv_ack_in_head_in_reg;
wire        [`PKT_DATA_WIDTH - 1 : 0]                          wv_ack_in_data_in_reg;
wire                                                           w_ack_in_start_in_reg;
wire                                                           w_ack_in_last_in_reg;
wire                                                           w_ack_in_ready_in_reg;

wire                                                           w_inject_valid_axis;
wire        [`PKT_HEAD_WIDTH - 1 : 0]                          wv_inject_head_axis;
wire        [`PKT_DATA_WIDTH - 1 : 0]                          wv_inject_data_axis;
wire                                                           w_inject_start_axis;
wire                                                           w_inject_last_axis;
wire                                                           w_inject_ready_axis;

wire                                                           w_inject_valid_in_reg;
wire        [`PKT_HEAD_WIDTH - 1 : 0]                          wv_inject_head_in_reg;
wire        [`PKT_DATA_WIDTH - 1 : 0]                          wv_inject_data_in_reg;
wire                                                           w_inject_start_in_reg;
wire                                                           w_inject_last_in_reg;
wire                                                           w_inject_ready_in_reg;

wire                                                           w_retrans_valid_axis;
wire        [`PKT_HEAD_WIDTH - 1 : 0]                          wv_retrans_head_axis;
wire        [`PKT_DATA_WIDTH - 1 : 0]                          wv_retrans_data_axis;
wire                                                           w_retrans_start_axis;
wire                                                           w_retrans_last_axis;
wire                                                           w_retrans_ready_axis;

wire                                                           w_retrans_valid_in_reg;
wire        [`PKT_HEAD_WIDTH - 1 : 0]                          wv_retrans_head_in_reg;
wire        [`PKT_DATA_WIDTH - 1 : 0]                          wv_retrans_data_in_reg;
wire                                                           w_retrans_start_in_reg;
wire                                                           w_retrans_last_in_reg;
wire                                                           w_retrans_ready_in_reg;

wire        [`SEND_BUFFER_SLOT_NUM_LOG - 1 : 0]                wv_available_slot_num;
wire                                                           w_insert_req_valid_axis;
wire        [SLOT_NUM - 1 : 0]                                 wv_insert_req_head_axis;
wire        [`PKT_DATA_WIDTH - 1 : 0]                          wv_insert_req_data_axis;
wire                                                           w_insert_req_start_axis;
wire                                                           w_insert_req_last_axis;
wire                                                           w_insert_req_ready_axis;

wire                                                           w_insert_req_valid_in_reg;
wire        [SLOT_NUM - 1 : 0]                                 wv_insert_req_head_in_reg;
wire        [`PKT_DATA_WIDTH - 1 : 0]                          wv_insert_req_data_in_reg;
wire                                                           w_insert_req_start_in_reg;
wire                                                           w_insert_req_last_in_reg;
wire                                                           w_insert_req_ready_in_reg;

wire                                                           w_delete_req_valid_axis;
wire        [`QP_NUM_LOG + `PSN_WIDTH + SLOT_NUM - 1 : 0]      wv_delete_req_head_axis;
wire                                                           w_delete_req_ready_axis; 

wire                                                           w_delete_req_valid_in_reg;
wire        [`QP_NUM_LOG + `PSN_WIDTH + SLOT_NUM - 1 : 0]      wv_delete_req_head_in_reg;
wire                                                           w_delete_req_ready_in_reg; 

wire                                                           w_delete_resp_valid_axis;
wire        [`PKT_HEAD_WIDTH - 1 : 0]                          wv_delete_resp_head_axis;
wire        [`PKT_DATA_WIDTH - 1 : 0]                          wv_delete_resp_data_axis;
wire                                                           w_delete_resp_start_axis;
wire                                                           w_delete_resp_last_axis;
wire                                                           w_delete_resp_ready_axis;

wire                                                           w_delete_resp_valid_in_reg;
wire        [`PKT_HEAD_WIDTH - 1 : 0]                          wv_delete_resp_head_in_reg;
wire        [`PKT_DATA_WIDTH - 1 : 0]                          wv_delete_resp_data_in_reg;
wire                                                           w_delete_resp_start_in_reg;
wire                                                           w_delete_resp_last_in_reg;
wire                                                           w_delete_resp_ready_in_reg;

wire                                                           w_find_req_valid_A_axis;
wire        [`QP_NUM_LOG + `PSN_WIDTH - 1 : 0]                 wv_find_req_head_A_axis;
wire                                                           w_find_resp_valid_A_axis;
wire        [`PKT_SLOT_NUM_LOG + SLOT_NUM_LOG : 0]             wv_find_resp_data_A_axis;

wire                                                           w_find_req_valid_A_in_reg;
wire        [`QP_NUM_LOG + `PSN_WIDTH - 1 : 0]                 wv_find_req_head_A_in_reg;
wire                                                           w_find_resp_valid_A_in_reg;
wire        [`PKT_SLOT_NUM_LOG + SLOT_NUM_LOG : 0]             wv_find_resp_data_A_in_reg;

wire                                                           w_find_req_valid_B_axis;
wire        [`QP_NUM_LOG + `PSN_WIDTH - 1 : 0]                 wv_find_req_head_B_axis;
wire                                                           w_find_resp_valid_B_axis;
wire        [`PKT_SLOT_NUM_LOG + SLOT_NUM_LOG : 0]             wv_find_resp_data_B_axis;

wire                                                           w_find_req_valid_B_in_reg;
wire        [`QP_NUM_LOG + `PSN_WIDTH - 1 : 0]                 wv_find_req_head_B_in_reg;
wire                                                           w_find_resp_valid_B_in_reg;
wire        [`PKT_SLOT_NUM_LOG + SLOT_NUM_LOG : 0]             wv_find_resp_data_B_in_reg;

wire                                                           w_get_req_valid_axis;
wire        [`QP_NUM_LOG + `PSN_WIDTH + SLOT_NUM - 1 : 0]      wv_get_req_head_axis;

wire                                                           w_get_req_valid_in_reg;
wire        [`QP_NUM_LOG + `PSN_WIDTH + SLOT_NUM - 1 : 0]      wv_get_req_head_in_reg;

wire                                                           w_get_resp_valid_axis;
wire        [`PKT_HEAD_WIDTH - 1 : 0]                          wv_get_resp_head_axis;
wire        [`PKT_DATA_WIDTH - 1 : 0]                          wv_get_resp_data_axis;
wire                                                           w_get_resp_start_axis;
wire                                                           w_get_resp_last_axis;
wire                                                           w_get_resp_ready_axis;

wire                                                           w_get_resp_valid_in_reg;
wire        [`PKT_HEAD_WIDTH - 1 : 0]                          wv_get_resp_head_in_reg;
wire        [`PKT_DATA_WIDTH - 1 : 0]                          wv_get_resp_data_in_reg;
wire                                                           w_get_resp_start_in_reg;
wire                                                           w_get_resp_last_in_reg;
wire                                                           w_get_resp_ready_in_reg;

wire                                                           w_time_out_empty;
wire        [`TIMER_EVENT_WIDTH - 1 : 0]                       wv_time_out_dout;
wire                                                           w_time_out_rd_en;

wire                                                           w_timer_set_prog_full_A;
wire                                                           w_timer_set_wr_en_A;
wire        [`TIMER_CMD_WIDTH - 1 : 0]                         wv_timer_set_din_A;

wire                                                           w_timer_set_prog_full_B;
wire                                                           w_timer_set_wr_en_B;
wire        [`TIMER_CMD_WIDTH - 1 : 0]                         wv_timer_set_din_B;
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

stream_fifo #(
    .TUSER_WIDTH(`PKT_HEAD_WIDTH),
    .TDATA_WIDTH(`PKT_DATA_WIDTH)
)
ACKFIFO_Inst
(
    .clk  (clk),
    .rst_n(~rst),

    .axis_tvalid    (i_ack_in_valid),
    .axis_tuser     (iv_ack_in_head),
    .axis_tdata     (iv_ack_in_data),
    .axis_tstart    (i_ack_in_start),
    .axis_tlast     (i_ack_in_last),
    .axis_tready    (o_ack_in_ready),
    .axis_tkeep     ('d0),

    .in_reg_tvalid  (w_ack_in_valid_in_reg),
    .in_reg_tuser   (wv_ack_in_head_in_reg),
    .in_reg_tdata   (wv_ack_in_data_in_reg),
    .in_reg_tstart  (w_ack_in_start_in_reg),
    .in_reg_tlast   (w_ack_in_last_in_reg),
    .in_reg_tready  (w_ack_in_ready_in_reg),
    .in_reg_tkeep   (),
    .tuser_clear    ('d0)
);

stream_fifo #(
    .TUSER_WIDTH(`PKT_HEAD_WIDTH),
    .TDATA_WIDTH(`PKT_DATA_WIDTH)
)
InjectFIFO_Inst
(
    .clk  (clk),
    .rst_n(~rst),

    .axis_tvalid    (w_inject_valid_axis),
    .axis_tuser     (wv_inject_head_axis),
    .axis_tdata     (wv_inject_data_axis),
    .axis_tstart    (w_inject_start_axis),
    .axis_tlast     (w_inject_last_axis),
    .axis_tready    (w_inject_ready_axis),
    .axis_tkeep     ('d0),

    .in_reg_tvalid  (w_inject_valid_in_reg),
    .in_reg_tuser   (wv_inject_head_in_reg),
    .in_reg_tdata   (wv_inject_data_in_reg),
    .in_reg_tstart  (w_inject_start_in_reg),        
    .in_reg_tlast   (w_inject_last_in_reg), 
    .in_reg_tready  (w_inject_ready_in_reg),
    .in_reg_tkeep   (),
    .tuser_clear    ('d0)
);

stream_fifo #(
    .TUSER_WIDTH(`PKT_HEAD_WIDTH),
    .TDATA_WIDTH(`PKT_DATA_WIDTH)
)
RetransFIFO_Inst
(
    .clk  (clk),
    .rst_n(~rst),

    .axis_tvalid    (w_retrans_valid_axis),
    .axis_tuser     (wv_retrans_head_axis),
    .axis_tdata     (wv_retrans_data_axis),
    .axis_tstart    (w_retrans_start_axis),
    .axis_tlast     (w_retrans_last_axis),
    .axis_tready    (w_retrans_ready_axis),
    .axis_tkeep     ('d0),

    .in_reg_tvalid  (w_retrans_valid_in_reg),
    .in_reg_tuser   (wv_retrans_head_in_reg),
    .in_reg_tdata   (wv_retrans_data_in_reg),
    .in_reg_tstart  (w_retrans_start_in_reg),        
    .in_reg_tlast   (w_retrans_last_in_reg), 
    .in_reg_tready  (w_retrans_ready_in_reg),
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
FindReqStreamA_Inst
(
    .clk  (clk),
    .rst_n(~rst),

    .axis_tvalid    (w_find_req_valid_A_axis),
    .axis_tuser     (wv_find_req_head_A_axis),
    .axis_tdata     ('d0),
    .axis_tstart    ('d0),
    .axis_tlast     ('d0),
    .axis_tready    (),
    .axis_tkeep     ('d0),

    .in_reg_tvalid  (w_find_req_valid_A_in_reg),
    .in_reg_tuser   (wv_find_req_head_A_in_reg),
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
FindRespStreamA_Inst
(
    .clk  (clk),
    .rst_n(~rst),

    .axis_tvalid    (w_find_resp_valid_A_axis),
    .axis_tuser     ('d0),
    .axis_tdata     (wv_find_resp_data_A_axis),
    .axis_tstart    ('d0),
    .axis_tlast     ('d0),
    .axis_tready    (),
    .axis_tkeep     ('d0),

    .in_reg_tvalid  (w_find_resp_valid_A_in_reg),
    .in_reg_tuser   (),
    .in_reg_tdata   (wv_find_resp_head_A_in_reg),
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
FindReqStreamB_Inst
(
    .clk  (clk),
    .rst_n(~rst),

    .axis_tvalid    (w_find_req_valid_B_axis),
    .axis_tuser     (wv_find_req_head_B_axis),
    .axis_tdata     ('d0),
    .axis_tstart    ('d0),
    .axis_tlast     ('d0),
    .axis_tready    (),
    .axis_tkeep     ('d0),

    .in_reg_tvalid  (w_find_req_valid_B_in_reg),
    .in_reg_tuser   (wv_find_req_head_B_in_reg),
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
FindRespStreamB_Inst
(
    .clk  (clk),
    .rst_n(~rst),

    .axis_tvalid    (w_find_resp_valid_B_axis),
    .axis_tuser     ('d0),
    .axis_tdata     (wv_find_resp_data_B_axis),
    .axis_tstart    ('d0),
    .axis_tlast     ('d0),
    .axis_tready    (),
    .axis_tkeep     ('d0),

    .in_reg_tvalid  (w_find_resp_valid_B_in_reg),
    .in_reg_tuser   (),
    .in_reg_tdata   (wv_find_resp_head_B_in_reg),
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
GetReqStream_Inst
(
    .clk  (clk),
    .rst_n(~rst),

    .axis_tvalid    (w_get_req_valid_axis),
    .axis_tuser     (wv_get_req_head_axis),
    .axis_tdata     ('d0),
    .axis_tstart    ('d0),
    .axis_tlast     ('d0),
    .axis_tready    (),
    .axis_tkeep     ('d0),

    .in_reg_tvalid  (w_get_req_valid_in_reg),
    .in_reg_tuser   (wv_get_req_head_in_reg),
    .in_reg_tdata   (),
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
GetRespStream_Inst
(
    .clk  (clk),
    .rst_n(~rst),

    .axis_tvalid    (w_get_resp_valid_axis),
    .axis_tuser     (wv_get_resp_head_axis),
    .axis_tdata     (wv_get_resp_data_axis),
    .axis_tstart    (w_get_resp_start_axis),
    .axis_tlast     (w_get_resp_last_axis),
    .axis_tready    (w_get_resp_ready_axis),
    .axis_tkeep     ('d0),

    .in_reg_tvalid  (w_get_resp_valid_in_reg),
    .in_reg_tuser   (wv_get_resp_head_in_reg),
    .in_reg_tdata   (wv_get_resp_data_in_reg),
    .in_reg_tstart  (w_get_resp_start_in_reg),        
    .in_reg_tlast   (w_get_resp_last_in_reg), 
    .in_reg_tready  (w_get_resp_ready_in_reg),
    .in_reg_tkeep   (),
    .tuser_clear    ('d0)
);

InOrderInject InOrderInject_Inst(
    .clk(clk),
    .rst(rst),

    .i_packet_in_valid(w_packet_in_valid_in_reg),
    .iv_packet_in_head(wv_packet_in_head_in_reg),
    .iv_packet_in_data(wv_packet_in_data_in_reg),
    .i_packet_in_start(w_packet_in_start_in_reg),
    .i_packet_in_last(w_packet_in_last_in_reg),
    .o_packet_in_ready(w_packet_in_ready_in_reg),

    .o_npsn_wr_en(o_npsn_wr_en),
    .ov_npsn_wr_index(ov_npsn_wr_index),
    .ov_npsn_wr_data(ov_npsn_wr_data),
    .ov_npsn_rd_index(ov_npsn_rd_index),
    .iv_npsn_rd_data(iv_npsn_rd_data),

    .iv_available_slot_num(wv_available_slot_num),
    .o_insert_req_valid(w_insert_req_valid_axis),
    .ov_insert_req_head(wv_insert_req_head_axis),
    .ov_insert_req_data(wv_insert_req_data_axis),
    .o_insert_req_start(w_insert_req_start_axis),
    .o_insert_req_last(w_insert_req_last_axis),
    .i_insert_req_ready(w_insert_req_ready_axis),

    .i_tc_prog_full(w_timer_set_prog_full_A),
    .o_tc_wr_en(w_timer_set_wr_en_A),
    .ov_tc_din(wv_timer_set_din_A),


    .o_packet_out_valid(w_inject_valid_axis),
    .ov_packet_out_head(wv_inject_head_axis),
    .ov_packet_out_data(wv_inject_data_axis),
    .o_packet_out_start(w_inject_start_axis),
    .o_packet_out_last(w_inject_last_axis),
    .i_packet_out_ready(w_inject_ready_axis)
);

SelectiveRepeat SelectiveRepeat_Inst(
    .clk(clk),
    .rst(rst),

    .i_ack_in_valid(w_ack_in_valid_in_reg),
    .iv_ack_in_head(wv_ack_in_head_in_reg),
    .iv_ack_in_data(wv_ack_in_data_in_reg),
    .i_ack_in_start(w_ack_in_start_in_reg),
    .i_ack_in_last(w_ack_in_last_in_reg),
    .o_ack_in_ready(w_ack_in_ready_in_reg),

    .i_timer_event_empty(w_time_out_empty),
    .iv_timer_event_dout(wv_time_out_dout),
    .o_timer_event_rd_en(w_time_out_rd_en),

    .i_timer_set_prog_full(w_timer_set_prog_full_B),
    .o_timer_set_wr_en(w_timer_set_wr_en_B),
    .ov_timer_set_din(wv_timer_set_din_B),

    .o_delete_req_valid(w_delete_req_valid_axis),
    .ov_delete_req_head(wv_delete_req_head_axis),
    .i_delete_req_ready(w_delete_req_ready_axis),

    .i_delete_resp_valid(w_delete_resp_valid_in_reg),
    .iv_delete_resp_head(wv_delete_resp_head_in_reg),
    .iv_delete_resp_data(wv_delete_resp_data_in_reg),
    .i_delete_resp_start(w_delete_resp_start_in_reg),
    .i_delete_resp_last(w_delete_resp_last_in_reg),
    .o_delete_resp_ready(w_delete_resp_ready_in_reg),

    .o_get_req_valid(w_get_req_valid_axis),
    .ov_get_req_head(wv_get_req_head_axis),
    .i_get_req_ready('d1),

    .i_get_resp_valid(w_get_resp_valid_in_reg),
    .iv_get_resp_head(wv_get_resp_head_in_reg),
    .iv_get_resp_data(wv_get_resp_data_in_reg),
    .i_get_resp_start(w_get_resp_start_in_reg),
    .i_get_resp_last(w_get_resp_last_in_reg),
    .o_get_resp_ready(w_get_resp_ready_in_reg),

    .o_packet_out_valid(w_retrans_valid_axis),
    .ov_packet_out_head(wv_retrans_head_axis),
    .ov_packet_out_data(wv_retrans_data_axis),
    .o_packet_out_start(w_retrans_start_axis),
    .o_packet_out_last(w_retrans_last_axis),
    .i_packet_out_ready(w_retrans_ready_axis),

    .ov_upsn_rd_index(ov_upsn_rd_index),
    .iv_upsn_rd_data(iv_upsn_rd_data),
    .o_upsn_wr_en(o_upsn_wr_en),
    .ov_upsn_wr_index(ov_upsn_wr_index),
    .ov_upsn_wr_data(ov_upsn_wr_data)
);

PacketBufferMgt 
#(
    .SLOT_WIDTH(`PKT_DATA_WIDTH),
    .SLOT_NUM(`SEND_BUFFER_SLOT_NUM)
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

    .i_find_req_valid_A('d0),
    .iv_find_req_head_A('d0),
    .o_find_resp_valid_A(),
    .ov_find_resp_data_A(),

    .i_find_req_valid_B('d0),
    .iv_find_req_head_B('d0),
    .o_find_resp_valid_B(),
    .ov_find_resp_data_B(),

    .i_get_req_valid(w_get_req_valid_in_reg),
    .iv_get_req_head(wv_get_req_head_in_reg),

    .o_get_resp_valid(w_get_resp_valid_axis),
    .ov_get_resp_head(wv_get_resp_head_axis),
    .ov_get_resp_data(wv_get_resp_data_axis),
    .o_get_resp_start(w_get_resp_start_axis),
    .o_get_resp_last(w_get_resp_last_axis),
    .i_get_resp_ready(w_get_resp_ready_axis)
);

PacketArbiter PacketArbiter_Inst(
    .clk(clk),
    .rst(rst),

    .i_channel_0_valid(w_inject_valid_in_reg),
    .iv_channel_0_head(wv_inject_head_in_reg),
    .iv_channel_0_data(wv_inject_data_in_reg),
    .i_channel_0_start(w_inject_start_in_reg),
    .i_channel_0_last(w_inject_last_in_reg),
    .o_channel_0_ready(w_inject_ready_in_reg),

    .i_channel_1_valid(w_retrans_valid_in_reg),
    .iv_channel_1_head(wv_retrans_head_in_reg),
    .iv_channel_1_data(wv_retrans_data_in_reg),
    .i_channel_1_start(w_retrans_start_in_reg),
    .i_channel_1_last(w_retrans_last_in_reg),
    .o_channel_1_ready(w_retrans_ready_in_reg),

    .o_channel_out_valid(w_packet_out_valid_axis),
    .ov_channel_out_head(wv_packet_out_head_axis),
    .ov_channel_out_data(wv_packet_out_data_axis),
    .o_channel_out_start(w_packet_out_start_axis),
    .o_channel_out_last(w_packet_out_last_axis),
    .i_channel_out_ready(w_packet_out_ready_axis)
);

TimerControl TimerControl_Inst(
    .clk(clk),
    .rst(rst),

    .i_time_out_empty(w_time_out_empty),
    .iv_time_out_dout(wv_time_out_dout),
    .o_time_out_rd_en(w_time_out_rd_en),

    .o_timer_set_prog_full_A(w_timer_set_prog_full_A),
    .i_timer_set_wr_en_A(w_timer_set_wr_en_A),
    .iv_timer_set_din_A(wv_timer_set_din_A),

    .o_timer_set_prog_full_B(w_timer_set_prog_full_B),
    .i_timer_set_wr_en_B(w_timer_set_wr_en_B),
    .iv_timer_set_din_B(wv_timer_set_din_B)
);

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
//Null
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//Null
/*------------------------------------------- Variables Decode : End ------------------------------------------------*/
endmodule