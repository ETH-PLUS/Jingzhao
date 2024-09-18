/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       SendControl
Author:     YangFan
Function:   Wrapper for InOrderInject, SelectiveRepeat, and PacketBufferMgt.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module TransportSubsystem(
    input   wire                                                            user_clk,
    input   wire                                                            user_rst,

    input   wire                                                            mac_tx_clk,
    input   wire                                                            mac_tx_rst,

    input   wire                                                            mac_rx_clk,
    input   wire                                                            mac_rx_rst,

    input 	wire 															TX_egress_pkt_valid,
    input 	wire 	[`PKT_META_BUS_WIDTH - 1 : 0]							TX_egress_pkt_head,
    output 	wire 															TX_egress_pkt_ready,

    input 	wire 															TX_insert_req_valid,
    input 	wire 															TX_insert_req_start,
    input 	wire 															TX_insert_req_last,
    input 	wire 	[`MAX_DB_SLOT_NUM_LOG - 1 : 0]                          TX_insert_req_head,
    input 	wire 	[`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     TX_insert_req_data,
    output 	wire 															TX_insert_req_ready,

    output 	wire 															TX_insert_resp_valid,
    output 	wire 	[`MAX_DB_SLOT_NUM_LOG - 1 : 0]					        TX_insert_resp_data,

    output 	wire 															RX_ingress_pkt_valid,
    output 	wire 	[`PKT_META_BUS_WIDTH - 1 : 0]                           RX_ingress_pkt_head,
    input 	wire 															RX_ingress_pkt_ready,

    input 	wire 															RX_delete_req_valid,
    input 	wire 	[`MAX_DB_SLOT_NUM_LOG * 2 - 1 : 0]				        RX_delete_req_head,
    output 	wire 															RX_delete_req_ready,

    output 	wire 															RX_delete_resp_valid,
    output 	wire 															RX_delete_resp_start,
    output 	wire 															RX_delete_resp_last,
    output 	wire 	[`PACKET_BUFFER_SLOT_WIDTH - 1 : 0] 					RX_delete_resp_data,
    input 	wire 															RX_delete_resp_ready,

    output 	wire 															mac_tx_valid,
    input 	wire 															mac_tx_ready,
    output 	wire 															mac_tx_start,
    output 	wire 															mac_tx_last,
    output 	wire 	[`MAC_KEEP_WIDTH - 1 : 0]					            mac_tx_keep,
    output 	wire 															mac_tx_user,
    output 	wire 	[`MAC_DATA_WIDTH - 1 : 0]								mac_tx_data,

    input 	wire 															mac_rx_valid,
    output 	wire 															mac_rx_ready,
    input 	wire 															mac_rx_start,
    input 	wire 															mac_rx_last,
    input 	wire 	[`MAC_KEEP_WIDTH - 1 : 0]                               mac_rx_keep,
    input 	wire 	                                                        mac_rx_user,
    input 	wire 	[`MAC_DATA_WIDTH - 1 : 0]                               mac_rx_data
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                                            TX_delete_req_valid;
wire    [`MAX_DB_SLOT_NUM_LOG * 2 - 1 : 0]                      TX_delete_req_head;
wire                                                            TX_delete_req_ready;

wire                                                            TX_delete_resp_valid;
wire                                                            TX_delete_resp_start;
wire                                                            TX_delete_resp_last;
wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     TX_delete_resp_data;
wire                                                            TX_delete_resp_ready;

wire                                                            RX_insert_req_valid;
wire                                                            RX_insert_req_start;
wire                                                            RX_insert_req_last;
wire    [`MAX_DB_SLOT_NUM_LOG - 1 : 0]                          RX_insert_req_head;
wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     RX_insert_req_data;
wire                                                            RX_insert_req_ready;

wire                                                            RX_insert_resp_valid;
wire    [`MAX_DB_SLOT_NUM_LOG - 1 : 0]                          RX_insert_resp_data;

wire                                                            user_mac_tx_valid;
wire                                                            user_mac_tx_ready;
wire                                                            user_mac_tx_start;
wire                                                            user_mac_tx_last;
wire    [`MAC_KEEP_WIDTH - 1 : 0]                               user_mac_tx_keep;
wire                                                            user_mac_tx_user;
wire    [`MAC_DATA_WIDTH - 1 : 0]                               user_mac_tx_data;

wire                                                            user_mac_rx_valid;
wire                                                            user_mac_rx_ready;
wire                                                            user_mac_rx_start;
wire                                                            user_mac_rx_last;
wire    [`MAC_KEEP_WIDTH - 1 : 0]                               user_mac_rx_keep;
wire                                                            user_mac_rx_user;
wire    [`MAC_DATA_WIDTH - 1 : 0]                               user_mac_rx_data;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
MACEncap MACEncap_Inst(
    .clk                        (       user_clk                   ),
    .rst                        (       user_rst                   ),

    .egress_pkt_valid           (       TX_egress_pkt_valid        ),
    .egress_pkt_head            (       TX_egress_pkt_head         ),
    .egress_pkt_ready           (       TX_egress_pkt_ready        ),

    .delete_req_valid           (       TX_delete_req_valid        ),
    .delete_req_head            (       TX_delete_req_head         ),
    .delete_req_ready           (       TX_delete_req_ready        ),
    
    .delete_resp_valid          (       TX_delete_resp_valid       ),
    .delete_resp_start          (       TX_delete_resp_start       ),
    .delete_resp_last           (       TX_delete_resp_last        ),
    .delete_resp_data           (       TX_delete_resp_data        ),
    .delete_resp_ready          (       TX_delete_resp_ready       ),

    .mac_tx_valid               (       user_mac_tx_valid            ),
    .mac_tx_ready               (       user_mac_tx_ready            ),
    .mac_tx_start               (       user_mac_tx_start            ),
    .mac_tx_last                (       user_mac_tx_last             ),
    .mac_tx_keep                (       user_mac_tx_keep             ),
    .mac_tx_user                (       user_mac_tx_user             ),
    .mac_tx_data                (       user_mac_tx_data             )
);

MACDecap MACDecap_Inst(
    .clk                        (       user_clk                        ),
    .rst                        (       user_rst                        ),

    .insert_req_valid           (       RX_insert_req_valid           ),
    .insert_req_start           (       RX_insert_req_start           ),
    .insert_req_last            (       RX_insert_req_last            ),
    .insert_req_head            (       RX_insert_req_head            ),
    .insert_req_data            (       RX_insert_req_data            ),
    .insert_req_ready           (       RX_insert_req_ready           ),

    .insert_resp_valid          (       RX_insert_resp_valid          ),
    .insert_resp_data           (       RX_insert_resp_data           ),

    .mac_rx_valid               (       user_mac_rx_valid               ),
    .mac_rx_ready               (       user_mac_rx_ready               ),
    .mac_rx_start               (       user_mac_rx_start               ),
    .mac_rx_last                (       user_mac_rx_last                ),
    .mac_rx_keep                (       user_mac_rx_keep                ),
    .mac_rx_user                (       user_mac_rx_user                ),
    .mac_rx_data                (       user_mac_rx_data                ),

    .ingress_pkt_valid          (       RX_ingress_pkt_valid          ),
    .ingress_pkt_head           (       RX_ingress_pkt_head           ),
    .ingress_pkt_ready          (       RX_ingress_pkt_ready          )
);

DynamicBuffer 
#(
    .SLOT_WIDTH     (       `PACKET_BUFFER_SLOT_WIDTH       ),
    .SLOT_NUM       (       `PACKET_BUFFER_SLOT_NUM         )
)
TX_PacketBuffer_Inst(
    .clk                        (   user_clk                        ),
    .rst                        (   user_rst                        ),

    .ov_available_slot_num      (                               ),

    .i_insert_req_valid         (   TX_insert_req_valid         ),
    .i_insert_req_start         (   TX_insert_req_start         ),
    .i_insert_req_last          (   TX_insert_req_last          ),
    .iv_insert_req_head         (   TX_insert_req_head          ),
    .iv_insert_req_data         (   TX_insert_req_data          ),
    .o_insert_req_ready         (   TX_insert_req_ready         ),

    .o_insert_resp_valid        (   TX_insert_resp_valid        ),
    .ov_insert_resp_data        (   TX_insert_resp_data         ),

    .i_get_req_valid            (    'd0     ),
    .iv_get_req_head            (    'd0     ),
    .o_get_req_ready            (                               ),
    .o_get_resp_valid           (                               ),
    .o_get_resp_start           (                               ),
    .o_get_resp_last            (                               ),
    .ov_get_resp_data           (                               ),
    .i_get_resp_ready           (    'd0                        ),

    .i_delete_req_valid         (   TX_delete_req_valid         ),
    .iv_delete_req_head         (   TX_delete_req_head          ),
    .o_delete_req_ready         (   TX_delete_req_ready         ),
    
    .o_delete_resp_valid        (   TX_delete_resp_valid        ),
    .o_delete_resp_start        (   TX_delete_resp_start        ),
    .o_delete_resp_last         (   TX_delete_resp_last         ),
    .ov_delete_resp_data        (   TX_delete_resp_data         ),
    .i_delete_resp_ready        (   TX_delete_resp_ready        )
);

DynamicBuffer 
#(
    .SLOT_WIDTH     (       `PACKET_BUFFER_SLOT_WIDTH       ),
    .SLOT_NUM       (       `PACKET_BUFFER_SLOT_NUM         )
)
RX_PacketBuffer_Inst(
    .clk                        (   user_clk                        ),
    .rst                        (   user_rst                        ),

    .ov_available_slot_num      (                               ),

    .i_insert_req_valid         (   RX_insert_req_valid         ),
    .i_insert_req_start         (   RX_insert_req_start         ),
    .i_insert_req_last          (   RX_insert_req_last          ),
    .iv_insert_req_head         (   RX_insert_req_head          ),
    .iv_insert_req_data         (   RX_insert_req_data          ),
    .o_insert_req_ready         (   RX_insert_req_ready         ),

    .o_insert_resp_valid        (   RX_insert_resp_valid        ),
    .ov_insert_resp_data        (   RX_insert_resp_data         ),

    .i_get_req_valid            (    'd0     ),
    .iv_get_req_head            (    'd0     ),
    .o_get_req_ready            (                               ),
    .o_get_resp_valid           (                               ),
    .o_get_resp_start           (                               ),
    .o_get_resp_last            (                               ),
    .ov_get_resp_data           (                               ),
    .i_get_resp_ready           (    'd0                        ),

    .i_delete_req_valid         (   RX_delete_req_valid         ),
    .iv_delete_req_head         (   RX_delete_req_head          ),
    .o_delete_req_ready         (   RX_delete_req_ready         ),
    
    .o_delete_resp_valid        (   RX_delete_resp_valid        ),
    .o_delete_resp_start        (   RX_delete_resp_start        ),
    .o_delete_resp_last         (   RX_delete_resp_last         ),
    .ov_delete_resp_data        (   RX_delete_resp_data         ),
    .i_delete_resp_ready        (   RX_delete_resp_ready        )
);

wire            [577 - 1 : 0]       mac_tx_fifo_dout;
wire                                mac_tx_fifo_empty;
wire                                mac_tx_fifo_prog_full;

assign mac_tx_valid = !mac_tx_fifo_empty;
assign mac_tx_user = 'd0;
assign mac_tx_last = mac_tx_fifo_dout[512 + 64 + 1 - 1 : 512 + 64];
assign mac_tx_keep = mac_tx_fifo_dout[512 + 64 - 1 : 512];
assign mac_tx_data = mac_tx_fifo_dout[512 - 1 : 0];
assign user_mac_tx_ready = !mac_tx_fifo_prog_full;

//TODO, bug exists

AsyncFIFO_577w_128d MAC_TX_FIFO (
  .wr_clk       (       user_clk            ),        // input wire wr_clk
  .wr_rst       (       user_rst            ),        // input wire wr_rst
  .rd_clk       (       mac_tx_clk          ),        // input wire rd_clk
  .rd_rst       (       mac_tx_rst          ),        // input wire rd_rst
  .din          (       {user_mac_tx_last, user_mac_tx_keep, user_mac_tx_data}    ),              // input wire [576 : 0] din
  .wr_en        (       user_mac_tx_valid & user_mac_tx_ready  ),          // input wire wr_en
  .rd_en        (       mac_tx_ready        ),          // input wire rd_en
  .dout         (       mac_tx_fifo_dout    ),            // output wire [576 : 0] dout
  .full         (                           ),            // output wire full
  .empty        (       mac_tx_fifo_empty   ),          // output wire empty
  .prog_full    (       mac_tx_fifo_prog_full   )  // output wire prog_full
);

wire            [577 - 1 : 0]       mac_rx_fifo_dout;
wire                                mac_rx_fifo_empty;
wire                                mac_rx_fifo_prog_full;

assign user_mac_rx_valid = !mac_rx_fifo_empty;
assign user_mac_rx_user = 'd0;
assign user_mac_rx_last = mac_rx_fifo_dout[512 + 64 + 1 - 1 : 512 + 64];
assign user_mac_rx_keep = mac_rx_fifo_dout[512 + 64 - 1 : 512];
assign user_mac_rx_data = mac_rx_fifo_dout[512 - 1 : 0];
assign mac_rx_ready = !mac_rx_fifo_prog_full;

AsyncFIFO_577w_128d MAC_RX_FIFO (
  .wr_clk       (       user_clk                ),        // input wire wr_clk
  .wr_rst       (       user_rst                ),        // input wire wr_rst
  .rd_clk       (       mac_rx_clk              ),        // input wire rd_clk
  .rd_rst       (       mac_rx_rst              ),        // input wire rd_rst
  .din          (       {mac_rx_last, mac_rx_keep, mac_rx_data}     ),              // input wire [576 : 0] din
  .wr_en        (       mac_rx_valid && mac_rx_ready      ),          // input wire wr_en
  .rd_en        (       !mac_rx_fifo_empty && user_mac_rx_ready       ),          // input wire rd_en
  .dout         (       mac_rx_fifo_dout        ),            // output wire [576 : 0] dout
  .full         (                               ),            // output wire full
  .empty        (       mac_rx_fifo_empty       ),          // output wire empty
  .prog_full    (       mac_rx_fifo_prog_full   )  // output wire prog_full
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
//Null
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
/*------------------------------------------- Variables Decode : End ------------------------------------------------*/
// `ifdef ILA_ON
// ila_mac ila_mac_tx_inst(
//     .clk(user_clk),

//     .probe0(user_mac_tx_valid),
//     .probe1(user_mac_tx_ready),
//     .probe2(user_mac_tx_start),
//     .probe3(user_mac_tx_last),
//     .probe4(user_mac_tx_keep),
//     .probe5(user_mac_tx_data)
// );

// ila_mac ila_mac_rx_inst(
//     .clk(user_clk),

//     .probe0(user_mac_rx_valid),
//     .probe1(user_mac_rx_ready),
//     .probe2(user_mac_rx_start),
//     .probe3(user_mac_rx_last),
//     .probe4(user_mac_rx_keep),
//     .probe5(user_mac_rx_data)
// );
// `endif

endmodule