//CREATE INFORMATION
//----------------------------------------------------------------------------
//
//  (C) COPYRIGHT 2021 BY ICT-HPC CORPORATION ALL RIGHTS RESERVED
//  DATE     : 2021-01-18
//  AUTHOR   : mazhenlong@ncic.ac.cn
//  FILENAME : hca_dut.v
//  FUNCTION : This file supplies the top module of HCA.
//
//----------------------------------------------------------------------------

//CHANGE HISTORY
//----------------------------------------------------------------------------
//
//  AUTHOR          DATE          VERSION          REASON
//  mazhenlong      2021-01-18    v1.0             create
//  mazhenlong      2021-05-12    v1.1             add self-loop-back
//  mazhenlong      2022-01-27    v2               add multi-host
//
//----------------------------------------------------------------------------

`ifndef __HCA_DUT__
`define __HCA_DUT__
//------------------------------------------------------------------------------
//
// MODULE: hca_dut
//
//------------------------------------------------------------------------------
`include "protocol_engine_def.vh"

module hca_dut #(
    parameter           C_DATA_WIDTH                    = `DATA_WIDTH,         // RX/TX interface data width
    parameter           KEEP_WIDTH                      = C_DATA_WIDTH / 32,
    parameter           DMA_HEAD_WIDTH                  = `DMA_HEAD_WIDTH,
    parameter           NIC_DATA_WIDTH                  = 256,
    parameter           NIC_KEEP_WIDTH                  = 32,
    parameter           LINK_LAYER_USER_WIDTH           = 7
)(
    //----------------------------------------------------------
    //  Control Interface                           
    //----------------------------------------------------------
    input                                        a_sys_clk,
    input                                        a_pcie_clk,
    input                                        a_rdma_clk,
    input                                        a_user_reset,
    input                                        a_user_lnk_up,
    output                                       a_cmd_rst,

    //----------------------------------------------------------
    //  Host A RDMA Interface                           
    //----------------------------------------------------------
    input                              [2:0]     a_cfg_max_payload,
    input                              [2:0]     a_cfg_max_read_req,

    output                                       a_s_axis_rq_tlast,
    output                 [C_DATA_WIDTH-1:0]    a_s_axis_rq_tdata,
    output                             [59:0]    a_s_axis_rq_tuser,
    output                   [KEEP_WIDTH-1:0]    a_s_axis_rq_tkeep,
    input                                        a_s_axis_rq_tready,
    output                                       a_s_axis_rq_tvalid,

    input                  [C_DATA_WIDTH-1:0]    a_m_axis_rc_tdata,
    input                              [74:0]    a_m_axis_rc_tuser,
    input                                        a_m_axis_rc_tlast,
    input                    [KEEP_WIDTH-1:0]    a_m_axis_rc_tkeep,
    input                                        a_m_axis_rc_tvalid,
    output                                       a_m_axis_rc_tready,

    input                  [C_DATA_WIDTH-1:0]    a_m_axis_cq_tdata,
    input                              [84:0]    a_m_axis_cq_tuser,
    input                                        a_m_axis_cq_tlast,
    input                    [KEEP_WIDTH-1:0]    a_m_axis_cq_tkeep,
    input                                        a_m_axis_cq_tvalid,
    output                                       a_m_axis_cq_tready,

    output                 [C_DATA_WIDTH-1:0]    a_s_axis_cc_tdata,
    output                             [32:0]    a_s_axis_cc_tuser,
    output                                       a_s_axis_cc_tlast,
    output                   [KEEP_WIDTH-1:0]    a_s_axis_cc_tkeep,
    output                                       a_s_axis_cc_tvalid,
    input                                        a_s_axis_cc_tready,

    //----------------------------------------------------------
    //  Host B RDMA Interface                           
    //----------------------------------------------------------
    input                                        b_sys_clk,
    input                                        b_pcie_clk,
    input                                        b_rdma_clk,
    input                                        b_user_reset,
    input                                        b_user_lnk_up,
    output                                       b_cmd_rst,

    input                              [2:0]     b_cfg_max_payload,
    input                              [2:0]     b_cfg_max_read_req,

    output                                       b_s_axis_rq_tlast,
    output                 [C_DATA_WIDTH-1:0]    b_s_axis_rq_tdata,
    output                             [59:0]    b_s_axis_rq_tuser,
    output                   [KEEP_WIDTH-1:0]    b_s_axis_rq_tkeep,
    input                                        b_s_axis_rq_tready,
    output                                       b_s_axis_rq_tvalid,

    input                  [C_DATA_WIDTH-1:0]    b_m_axis_rc_tdata,
    input                              [74:0]    b_m_axis_rc_tuser,
    input                                        b_m_axis_rc_tlast,
    input                    [KEEP_WIDTH-1:0]    b_m_axis_rc_tkeep,
    input                                        b_m_axis_rc_tvalid,
    output                                       b_m_axis_rc_tready,

    input                  [C_DATA_WIDTH-1:0]    b_m_axis_cq_tdata,
    input                              [84:0]    b_m_axis_cq_tuser,
    input                                        b_m_axis_cq_tlast,
    input                    [KEEP_WIDTH-1:0]    b_m_axis_cq_tkeep,
    input                                        b_m_axis_cq_tvalid,
    output                                       b_m_axis_cq_tready,

    output                 [C_DATA_WIDTH-1:0]    b_s_axis_cc_tdata,
    output                             [32:0]    b_s_axis_cc_tuser,
    output                                       b_s_axis_cc_tlast,
    output                   [KEEP_WIDTH-1:0]    b_s_axis_cc_tkeep,
    output                                       b_s_axis_cc_tvalid,
    input                                        b_s_axis_cc_tready
);

    wire                                                w_hpc_a2b_valid;
    wire                                                w_hpc_a2b_last ;
    wire              [NIC_DATA_WIDTH - 1 : 0]          wv_hpc_a2b_data;
    wire              [NIC_KEEP_WIDTH - 1 : 0]          wv_hpc_a2b_keep;
    wire                                                w_hpc_a2b_ready;
    wire                                                w_hpc_a2b_start;
    wire              [LINK_LAYER_USER_WIDTH - 1 : 0]   wv_hpc_a2b_user;

    wire                                                w_hpc_b2a_valid;
    wire                                                w_hpc_b2a_last ;
    wire              [NIC_DATA_WIDTH - 1 : 0]          wv_hpc_b2a_data;
    wire              [NIC_KEEP_WIDTH - 1 : 0]          wv_hpc_b2a_keep;
    wire                                                w_hpc_b2a_ready;
    wire                                                w_hpc_b2a_start;
    wire              [LINK_LAYER_USER_WIDTH - 1 : 0]   wv_hpc_b2a_user;

    wire                                                w_eth_a2b_valid;
    wire                                                w_eth_a2b_last ;
    wire              [`MAC_DATA_WIDTH - 1 : 0]          wv_eth_a2b_data;
    wire              [`MAC_KEEP_WIDTH - 1 : 0]          wv_eth_a2b_keep;
    wire                                                w_eth_a2b_ready;
    wire                                                w_eth_a2b_start;
    wire              [0 : 0]   						wv_eth_a2b_user;

    wire                                                w_eth_b2a_valid;
    wire                                                w_eth_b2a_last ;
    wire              [`MAC_DATA_WIDTH - 1 : 0]          wv_eth_b2a_data;
    wire              [`MAC_KEEP_WIDTH - 1 : 0]          wv_eth_b2a_keep;
    wire                                                w_eth_b2a_ready;
    wire                                                w_eth_b2a_start;
    wire              [0 : 0]  	 						wv_eth_b2a_user;

HanGuHTN_Top NIC_a (
    .pcie_clk                        (       a_pcie_clk              ),
    .pcie_rst                        (       a_user_reset            ),

    .user_clk                        (       a_rdma_clk              ),
    .user_rst                        (       a_user_reset            ),

    .mac_tx_clk                        (       a_rdma_clk              ),
    .mac_tx_rst                        (       a_user_reset            ),

    .mac_rx_clk                        (       a_rdma_clk              ),
    .mac_rx_rst                        (       a_user_reset            ),

    .cfg_max_payload            (       a_cfg_max_payload       ),
    .cfg_max_read_req           (       a_cfg_max_read_req      ),

    .s_axis_rq_tvalid           (       a_s_axis_rq_tvalid      ),
    .s_axis_rq_tlast            (       a_s_axis_rq_tlast       ),
    .s_axis_rq_tkeep            (       a_s_axis_rq_tkeep       ),
    .s_axis_rq_tuser            (       a_s_axis_rq_tuser       ),
    .s_axis_rq_tdata            (       a_s_axis_rq_tdata       ),
    .s_axis_rq_tready           (       a_s_axis_rq_tready      ),

    .m_axis_rc_tvalid           (       a_m_axis_rc_tvalid      ),
    .m_axis_rc_tlast            (       a_m_axis_rc_tlast       ),
    .m_axis_rc_tkeep            (       a_m_axis_rc_tkeep       ),
    .m_axis_rc_tuser            (       a_m_axis_rc_tuser       ),
    .m_axis_rc_tdata            (       a_m_axis_rc_tdata       ),
    .m_axis_rc_tready           (       a_m_axis_rc_tready      ),

    .m_axis_cq_tvalid           (       a_m_axis_cq_tvalid      ),
    .m_axis_cq_tlast            (       a_m_axis_cq_tlast       ),
    .m_axis_cq_tkeep            (       a_m_axis_cq_tkeep       ),
    .m_axis_cq_tuser            (       a_m_axis_cq_tuser       ),
    .m_axis_cq_tdata            (       a_m_axis_cq_tdata       ),
    .m_axis_cq_tready           (       a_m_axis_cq_tready      ),

    .s_axis_cc_tvalid           (       a_s_axis_cc_tvalid      ),
    .s_axis_cc_tlast            (       a_s_axis_cc_tlast       ),
    .s_axis_cc_tkeep            (       a_s_axis_cc_tkeep       ),
    .s_axis_cc_tuser            (       a_s_axis_cc_tuser       ),
    .s_axis_cc_tdata            (       a_s_axis_cc_tdata       ),
    .s_axis_cc_tready           (       a_s_axis_cc_tready      ),

    .mac_tx_valid               (      w_eth_a2b_valid          ),
    .mac_tx_ready               (      w_eth_a2b_ready          ),
    .mac_tx_start               (      w_eth_a2b_start          ),
    .mac_tx_last                (      w_eth_a2b_last          ),
    .mac_tx_keep                (      wv_eth_a2b_keep          ),
    .mac_tx_user                (      wv_eth_a2b_user          ),
    .mac_tx_data                (      wv_eth_a2b_data         ),

    .mac_rx_valid               (      w_eth_b2a_valid          ),
    .mac_rx_ready               (      w_eth_b2a_ready          ),
    .mac_rx_start               (      w_eth_b2a_start          ),
    .mac_rx_last                (      w_eth_b2a_last          ),
    .mac_rx_keep                (      wv_eth_b2a_keep          ),
    .mac_rx_user                (      wv_eth_b2a_user          ),
    .mac_rx_data                (      wv_eth_b2a_data         )
);

HanGuHTN_Top NIC_b (
    .pcie_clk                        (       a_pcie_clk              ),
    .pcie_rst                        (       a_user_reset            ),

    .user_clk                        (       a_rdma_clk              ),
    .user_rst                        (       a_user_reset            ),

    .mac_tx_clk                        (       a_rdma_clk              ),
    .mac_tx_rst                        (       a_user_reset            ),

    .mac_rx_clk                        (       a_rdma_clk              ),
    .mac_rx_rst                        (       a_user_reset            ),

    .cfg_max_payload            (       b_cfg_max_payload       ),
    .cfg_max_read_req           (       b_cfg_max_read_req      ),

    .s_axis_rq_tvalid           (       b_s_axis_rq_tvalid      ),
    .s_axis_rq_tlast            (       b_s_axis_rq_tlast       ),
    .s_axis_rq_tkeep            (       b_s_axis_rq_tkeep       ),
    .s_axis_rq_tuser            (       b_s_axis_rq_tuser       ),
    .s_axis_rq_tdata            (       b_s_axis_rq_tdata       ),
    .s_axis_rq_tready           (       b_s_axis_rq_tready      ),

    .m_axis_rc_tvalid           (       b_m_axis_rc_tvalid      ),
    .m_axis_rc_tlast            (       b_m_axis_rc_tlast       ),
    .m_axis_rc_tkeep            (       b_m_axis_rc_tkeep       ),
    .m_axis_rc_tuser            (       b_m_axis_rc_tuser       ),
    .m_axis_rc_tdata            (       b_m_axis_rc_tdata       ),
    .m_axis_rc_tready           (       b_m_axis_rc_tready      ),

    .m_axis_cq_tvalid           (       b_m_axis_cq_tvalid      ),
    .m_axis_cq_tlast            (       b_m_axis_cq_tlast       ),
    .m_axis_cq_tkeep            (       b_m_axis_cq_tkeep       ),
    .m_axis_cq_tuser            (       b_m_axis_cq_tuser       ),
    .m_axis_cq_tdata            (       b_m_axis_cq_tdata       ),
    .m_axis_cq_tready           (       b_m_axis_cq_tready      ),

    .s_axis_cc_tvalid           (       b_s_axis_cc_tvalid      ),
    .s_axis_cc_tlast            (       b_s_axis_cc_tlast       ),
    .s_axis_cc_tkeep            (       b_s_axis_cc_tkeep       ),
    .s_axis_cc_tuser            (       b_s_axis_cc_tuser       ),
    .s_axis_cc_tdata            (       b_s_axis_cc_tdata       ),
    .s_axis_cc_tready           (       b_s_axis_cc_tready      ),

    .mac_tx_valid               (      w_eth_b2a_valid          ),
    .mac_tx_ready               (      w_eth_b2a_ready          ),
    .mac_tx_start               (      w_eth_b2a_start          ),
    .mac_tx_last                (      w_eth_b2a_last          ),
    .mac_tx_keep                (      wv_eth_b2a_keep          ),
    .mac_tx_user                (      wv_eth_b2a_user          ),
    .mac_tx_data                (      wv_eth_b2a_data         ),

    .mac_rx_valid               (      w_eth_a2b_valid          ),
    .mac_rx_ready               (      w_eth_a2b_ready          ),
    .mac_rx_start               (      w_eth_a2b_start          ),
    .mac_rx_last                (      w_eth_a2b_last          ),
    .mac_rx_keep                (      wv_eth_a2b_keep          ),
    .mac_rx_user                (      wv_eth_a2b_user          ),
    .mac_rx_data                (      wv_eth_a2b_data         )
);
   
endmodule: hca_dut
`endif
