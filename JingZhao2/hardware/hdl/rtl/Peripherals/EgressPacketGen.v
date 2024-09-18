/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       EgressPacketGen
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
module EgressPacketGen
(
    input   wire                                            clk,
    input   wire                                            rst,

    input   wire                                            req_trans_pkt_out_valid,
    input   wire        [`PKT_HEAD_BUS_WIDTH - 1 : 0]       req_trans_pkt_out_head,
    input   wire        [`PKT_DATA_BUS_WIDTH - 1 : 0]       req_trans_pkt_out_data,
    input   wire                                            req_trans_pkt_out_start,
    input   wire                                            req_trans_pkt_out_last,
    output  wire                                            req_trans_pkt_out_ready,

    input   wire                                            resp_trans_pkt_out_valid,
    input   wire        [`PKT_HEAD_BUS_WIDTH - 1 : 0]       resp_trans_pkt_out_head,
    input   wire        [`PKT_DATA_BUS_WIDTH - 1 : 0]       resp_trans_pkt_out_data,
    input   wire                                            resp_trans_pkt_out_start,
    input   wire                                            resp_trans_pkt_out_last,
    output  wire                                            resp_trans_pkt_out_ready,

    output  wire                                            mac_axis_tx_valid,
    output  wire        [511:0]                             mac_axis_tx_data,
    output  wire        [63:0]                              mac_axis_tx_keep,
    output  wire                                            mac_axis_tx_user,
    output  wire                                            mac_axis_tx_last,
    input   wire                                            mac_axis_tx_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                            egress_pkt_valid;
wire        [`PKT_HEAD_BUS_WIDTH - 1 : 0]       egress_pkt_head;
wire        [`PKT_DATA_BUS_WIDTH - 1 : 0]       egress_pkt_data;
wire        [`PKT_KEEP_BUS_WIDTH - 1 : 0]       egress_pkt_keep;
wire                                            egress_pkt_start;
wire                                            egress_pkt_last;
wire                                            egress_pkt_ready;

/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
EgressArbiter EgressArbiter_Inst(
    .clk                        (   clk                         ),
    .rst                        (   rst                         ),

    .req_trans_pkt_out_valid    (   req_trans_pkt_out_valid     ),
    .req_trans_pkt_out_head     (   req_trans_pkt_out_head      ),
    .req_trans_pkt_out_data     (   req_trans_pkt_out_data      ),
    .req_trans_pkt_out_start    (   req_trans_pkt_out_start     ),
    .req_trans_pkt_out_last     (   req_trans_pkt_out_last      ),
    .req_trans_pkt_out_ready    (   req_trans_pkt_out_ready     ),
    
    .resp_trans_pkt_out_valid   (   resp_trans_pkt_out_valid     ),
    .resp_trans_pkt_out_head    (   resp_trans_pkt_out_head      ),
    .resp_trans_pkt_out_data    (   resp_trans_pkt_out_data      ),
    .resp_trans_pkt_out_start   (   resp_trans_pkt_out_start     ),
    .resp_trans_pkt_out_last    (   resp_trans_pkt_out_last      ),
    .resp_trans_pkt_out_ready   (   resp_trans_pkt_out_ready     ),
    
    .egress_pkt_valid           (   egress_pkt_valid            ),
    .egress_pkt_head            (   egress_pkt_head             ),
    .egress_pkt_data            (   egress_pkt_data             ),
    .egress_pkt_start           (   egress_pkt_start            ),
    .egress_pkt_last            (   egress_pkt_last             ),
    .egress_pkt_ready           (   egress_pkt_ready            )
);

PacketEncap 
#(
    .HEADER_BUS_WIDTH       (   `PKT_HEAD_BUS_WIDTH     ),
    .PAYLOAD_BUS_WIDTH      (   `PKT_DATA_BUS_WIDTH     )
)
PacketEncap_Inst(
    .clk                        (   clk                         ),
    .rst                        (   rst                         ),

    .i_packet_in_valid          (   egress_pkt_valid            ),
    .iv_packet_in_head          (   egress_pkt_head             ),
    .iv_packet_in_data          (   egress_pkt_data             ),
    .i_packet_in_start          (   egress_pkt_start            ),
    .i_packet_in_last           (   egress_pkt_last             ),
    .iv_packet_in_keep          (   egress_pkt_keep             ),
    .o_packet_in_ready          (   egress_pkt_ready            ),

    .o_packet_out_valid         (   mac_axis_tx_valid           ),
    .ov_packet_out_head         (                               ),
    .ov_packet_out_keep         (   mac_axis_tx_keep            ),
    .ov_packet_out_data         (   mac_axis_tx_data            ),
    .o_packet_out_start         (                               ),
    .o_packet_out_last          (   mac_axis_tx_last            ),
    .i_packet_out_ready         (   mac_axis_tx_ready           )
);

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/

/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

/*------------------------------------------- Variables Decode : End ------------------------------------------------*/

endmodule