/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       IngressPacketGen
Author:     YangFan
Function:   In NIC/Switch processing pipeline, protocol processing requires frequent appending and removing header.
            This module abstracts the append process.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module IngressPacketGen
(
    input   wire                                                            clk,
    input   wire                                                            rst,

    input   wire                                                            mac_axis_rx_valid,
    input   wire    [511:0]                                                 mac_axis_rx_data,
    input   wire    [63:0]                                                  mac_axis_rx_keep,
    input   wire                                                            mac_axis_rx_last,
    input   wire                                                            mac_axis_rx_user,

    output  wire                                                            req_recv_pkt_meta_valid,
    output  wire    [`PKT_HEAD_BUS_WIDTH - 1 : 0]                           req_recv_pkt_meta_data,
    input   wire                                                            req_recv_pkt_meta_ready,

    input   wire                                                            req_recv_pkt_dequeue_req_valid,
    input   wire    [`REQ_RECV_SLOT_NUM_LOG + `QP_NUM_LOG - 1 : 0]          req_recv_pkt_dequeue_req_head,
    output  wire                                                            req_recv_pkt_dequeue_req_ready,

    output  wire                                                            req_recv_pkt_dequeue_resp_valid,
    output  wire    [`REQ_RECV_SLOT_NUM_LOG + `QP_NUM_LOG - 1 : 0]          req_recv_pkt_dequeue_resp_head,
    output  wire    [`REQ_RECV_SLOT_WIDTH - 1 : 0]                          req_recv_pkt_dequeue_resp_data,
    output  wire                                                            req_recv_pkt_dequeue_resp_start,
    output  wire                                                            req_recv_pkt_dequeue_resp_last,
    input   wire                                                            req_recv_pkt_dequeue_resp_ready,

    output  wire                                                            resp_recv_pkt_meta_valid,
    output  wire    [`PKT_HEAD_BUS_WIDTH - 1 : 0]                           resp_recv_pkt_meta_data,
    input   wire                                                            resp_recv_pkt_meta_ready,

    input   wire                                                            resp_recv_pkt_dequeue_req_valid,
    input   wire    [`RESP_RECV_SLOT_NUM_LOG + `QP_NUM_LOG - 1 : 0]         resp_recv_pkt_dequeue_req_head,
    output  wire                                                            resp_recv_pkt_dequeue_req_ready,

    output  wire                                                            resp_recv_pkt_dequeue_resp_valid,
    output  wire    [`RESP_RECV_SLOT_NUM_LOG + `QP_NUM_LOG - 1 : 0]         resp_recv_pkt_dequeue_resp_head,
    output  wire    [`RESP_RECV_SLOT_WIDTH - 1 : 0]                         resp_recv_pkt_dequeue_resp_data,
    output  wire                                                            resp_recv_pkt_dequeue_resp_start,
    output  wire                                                            resp_recv_pkt_dequeue_resp_last,
    input   wire                                                            resp_recv_pkt_dequeue_resp_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
//Gen Packet Header Length for PacketDecap
wire        [`PKT_HEAD_BUS_WIDTH - 1 : 0]       mac_axis_rx_head;

wire                                            ingress_packet_valid;
wire        [`PKT_HEAD_BUS_WIDTH - 1 : 0]       ingress_packet_head;
wire        [`PKT_DATA_BUS_WIDTH - 1 : 0]       ingress_packet_data;
wire                                            ingress_packet_start;
wire                                            ingress_packet_last;
wire                                            ingress_packet_ready;

wire                                            req_recv_insert_req_valid;
wire                                            req_recv_insert_req_start;
wire                                            req_recv_insert_req_last;
wire        [`REQ_RECV_SLOT_NUM_LOG - 1 : 0]    req_recv_insert_req_head;
wire        [`REQ_RECV_SLOT_WIDTH - 1 : 0]      req_recv_insert_req_data;
wire                                            req_recv_insert_req_ready;

wire                                            req_recv_insert_resp_valid;
wire        [`REQ_RECV_SLOT_WIDTH - 1 : 0]      req_recv_insert_resp_data;

wire                                            resp_recv_insert_req_valid;
wire                                            resp_recv_insert_req_start;
wire                                            resp_recv_insert_req_last;
wire        [`RESP_RECV_SLOT_NUM_LOG - 1 : 0]   resp_recv_insert_req_head;
wire        [`RESP_RECV_SLOT_WIDTH - 1 : 0]     resp_recv_insert_req_data;
wire                                            resp_recv_insert_req_ready;

wire                                            resp_recv_insert_resp_valid;
wire        [`RESP_RECV_SLOT_WIDTH - 1 : 0]     resp_recv_insert_resp_data;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/

assign mac_axis_rx_head = `TODO;


PacketDecap 
#(
    .HEADER_BUS_WIDTH       (   `PKT_HEAD_BUS_WIDTH     ),
    .PAYLOAD_BUS_WIDTH      (   `PKT_DATA_BUS_WIDTH     )
)
PacketDecap_Inst(
    .clk                    (   clk                     ),
    .rst                    (   rst                     ),

    .i_packet_in_valid      (   mac_axis_rx_valid       ),
    .iv_packet_in_head      (   mac_axis_rx_head        ),
    .iv_packet_in_data      (   mac_axis_rx_data        ),
    .i_packet_in_start      (   'd0                     ),
    .i_packet_in_last       (   mac_axis_rx_last        ),
    .o_packet_in_ready      (                           ),

    .o_packet_out_valid     (   ingress_packet_valid    ),
    .ov_packet_out_head     (   ingress_packet_head     ),
    .ov_packet_out_data     (   ingress_packet_data     ),
    .o_packet_out_start     (   ingress_packet_start    ),
    .o_packet_out_last      (   ingress_packet_last     ),
    .i_packet_out_ready     (   ingress_packet_ready    )
);

IngressDispatcher IngressDispatcher_Inst(
    .clk                                (   clk                             ),
    .rst                                (   rst                             ),

    .ingress_packet_valid               (   ingress_packet_valid            ),
    .ingress_packet_head                (   ingress_packet_head             ),
    .ingress_packet_data                (   ingress_packet_data             ),
    .ingress_packet_start               (   ingress_packet_start            ),
    .ingress_packet_last                (   ingress_packet_last             ),
    .ingress_packet_ready               (   ingress_packet_ready            ),

    .req_recv_insert_req_valid          (   req_recv_insert_req_valid       ),
    .req_recv_insert_req_start          (   req_recv_insert_req_start       ),
    .req_recv_insert_req_last           (   req_recv_insert_req_last        ),
    .req_recv_insert_req_head           (   req_recv_insert_req_head        ),
    .req_recv_insert_req_data           (   req_recv_insert_req_data        ),
    .req_recv_insert_req_ready          (   req_recv_insert_req_ready       ),

    .req_recv_insert_resp_valid         (   req_recv_insert_resp_valid      ),
    .req_recv_insert_resp_data          (   req_recv_insert_resp_data       ),

    .req_recv_pkt_meta_valid            (   req_recv_pkt_meta_valid         ),
    .req_recv_pkt_meta_data             (   req_recv_pkt_meta_data          ),
    .req_recv_pkt_meta_ready            (   req_recv_pkt_meta_ready         ),

    .resp_recv_insert_req_valid         (   resp_recv_insert_req_valid      ),
    .resp_recv_insert_req_start         (   resp_recv_insert_req_start      ),
    .resp_recv_insert_req_last          (   resp_recv_insert_req_last       ),
    .resp_recv_insert_req_head          (   resp_recv_insert_req_head       ),
    .resp_recv_insert_req_data          (   resp_recv_insert_req_data       ),
    .resp_recv_insert_req_ready         (   resp_recv_insert_req_ready      ),

    .resp_recv_insert_resp_valid        (   resp_recv_insert_resp_valid     ),
    .resp_recv_insert_resp_data         (   resp_recv_insert_resp_data      ),

    .resp_recv_pkt_meta_valid           (   resp_recv_pkt_meta_valid        ),
    .resp_recv_pkt_meta_data            (   resp_recv_pkt_meta_data         ),
    .resp_recv_pkt_meta_ready           (   resp_recv_pkt_meta_ready        )
);

DynamicBuffer 
#(
    .SLOT_NUM                           (   `REQ_RECV_SLOT_NUM                  ),
    .SLOT_WIDTH                         (   `REQ_RECV_SLOT_WIDTH                )
)
ReqRecvBuffer_Inst(
    .clk                                (   clk                                 ),
    .rst                                (   rst                                 ),
    
    .ov_available_slot_num              (                                       ),
    
    .i_insert_req_valid                 (   req_recv_insert_req_valid           ),
    .i_insert_req_start                 (   req_recv_insert_req_start           ),
    .i_insert_req_last                  (   req_recv_insert_req_last            ),
    .iv_insert_req_head                 (   req_recv_insert_req_head            ),
    .iv_insert_req_data                 (   req_recv_insert_req_data            ),
    .o_insert_req_ready                 (   req_recv_insert_req_ready           ),
        
    .o_insert_resp_valid                (   req_recv_insert_resp_valid          ),
    .ov_insert_resp_data                (   req_recv_insert_resp_data           ),
    
    .i_get_req_valid                    (   'd0                                 ),
    .iv_get_req_head                    (   'd0                                 ),
    .o_get_req_ready                    (                                       ),
    .o_get_resp_valid                   (                                       ),
    .o_get_resp_start                   (                                       ),
    .o_get_resp_last                    (                                       ),
    .ov_get_resp_data                   (                                       ),
    .i_get_resp_ready                   (   'd1                                 ),
            
    .i_delete_req_valid                 (   req_recv_pkt_dequeue_req_valid      ),
    .iv_delete_req_head                 (   req_recv_pkt_dequeue_req_head       ),
    .o_delete_req_ready                 (   req_recv_pkt_dequeue_req_ready      ),
    
    .o_delete_resp_valid                (   req_recv_pkt_dequeue_resp_valid     ),
    .o_delete_resp_start                (   req_recv_pkt_dequeue_resp_start     ),
    .o_delete_resp_last                 (   req_recv_pkt_dequeue_resp_last      ),
    .ov_delete_resp_data                (   req_recv_pkt_dequeue_resp_data      ),
    .i_delete_resp_ready                (   req_recv_pkt_dequeue_resp_read      )
);

DynamicBuffer 
#(
    .SLOT_NUM                           (   `RESP_RECV_SLOT_NUM                 ),
    .SLOT_WIDTH                         (   `RESP_RECV_SLOT_WIDTH               )
)
RespRecvBuffer_Inst(
    .clk                                (   clk                                 ),
    .rst                                (   rst                                 ),
    
    .ov_available_slot_num              (                                       ),
    
    .i_insert_req_valid                 (   resp_recv_insert_req_valid          ),
    .i_insert_req_start                 (   resp_recv_insert_req_start          ),
    .i_insert_req_last                  (   resp_recv_insert_req_last           ),
    .iv_insert_req_head                 (   resp_recv_insert_req_head           ),
    .iv_insert_req_data                 (   resp_recv_insert_req_data           ),
    .o_insert_req_ready                 (   resp_recv_insert_req_ready          ),
        
    .o_insert_resp_valid                (   resp_recv_insert_resp_valid         ),
    .ov_insert_resp_data                (   resp_recv_insert_resp_data          ),
    
    .i_get_req_valid                    (   'd0                                 ),
    .iv_get_req_head                    (   'd0                                 ),
    .o_get_req_ready                    (                                       ),
    .o_get_resp_valid                   (                                       ),
    .o_get_resp_start                   (                                       ),
    .o_get_resp_last                    (                                       ),
    .ov_get_resp_data                   (                                       ),
    .i_get_resp_ready                   (   'd1                                 ),
        
    .i_delete_req_valid                 (   resp_recv_pkt_dequeue_req_valid     ),
    .iv_delete_req_head                 (   resp_recv_pkt_dequeue_req_head      ),
    .o_delete_req_ready                 (   resp_recv_pkt_dequeue_req_ready     ),
    
    .o_delete_resp_valid                (   resp_recv_pkt_dequeue_resp_valid    ),
    .o_delete_resp_start                (   resp_recv_pkt_dequeue_resp_start    ),
    .o_delete_resp_last                 (   resp_recv_pkt_dequeue_resp_last     ),
    .ov_delete_resp_data                (   resp_recv_pkt_dequeue_resp_data     ),
    .i_delete_resp_ready                (   resp_recv_pkt_dequeue_resp_read     )
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/

/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Variables Decode : End ------------------------------------------------*/

endmodule