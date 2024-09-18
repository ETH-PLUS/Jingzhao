`timescale 1ns / 1ps

module HanGuHTN_FPGA_Top(
   /*
     * Clock: 100MHz LVDS
     */
    input  wire         clk_100mhz_p,
    input  wire         clk_100mhz_n,

    /*
     * GPIO
     */
    output wire [7:0]   led,
    // output wire         qsfp_led_act,
    // output wire         qsfp_led_stat_g,
    // output wire         qsfp_led_stat_y,
    // output wire         hbm_cattrip,
    // input  wire [1:0]   msp_gpio,
    // output wire         msp_uart_txd,
    // input  wire         msp_uart_rxd,

    /*
     * PCI express
     */
    input  wire [15:0]  pcie_rx_p,
    input  wire [15:0]  pcie_rx_n,
    output wire [15:0]  pcie_tx_p,
    output wire [15:0]  pcie_tx_n,
    input  wire         pcie_refclk_1_p,
    input  wire         pcie_refclk_1_n,
    input  wire         pcie_reset_n,
    /*
     * Ethernet: QSFP28
     */
    output wire         qsfp_tx1_p,
    output wire         qsfp_tx1_n,
    input  wire         qsfp_rx1_p,
    input  wire         qsfp_rx1_n,
    output wire         qsfp_tx2_p,
    output wire         qsfp_tx2_n,
    input  wire         qsfp_rx2_p,
    input  wire         qsfp_rx2_n,
    output wire         qsfp_tx3_p,
    output wire         qsfp_tx3_n,
    input  wire         qsfp_rx3_p,
    input  wire         qsfp_rx3_n,
    output wire         qsfp_tx4_p,
    output wire         qsfp_tx4_n,
    input  wire         qsfp_rx4_p,
    input  wire         qsfp_rx4_n,
    input  wire         qsfp_mgt_refclk_0_p,
    input  wire         qsfp_mgt_refclk_0_n,

    output wire         qsfp1_modsell,
    output wire         qsfp1_resetl,
    input  wire         qsfp1_modprsl,
    input  wire         qsfp1_intl,
    output wire         qsfp1_lpmode
);

parameter AXIS_PCIE_DATA_WIDTH = 256;
parameter AXIS_PCIE_KEEP_WIDTH = (AXIS_PCIE_DATA_WIDTH / 32);
parameter AXIS_PCIE_RC_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 75 : 161;
parameter AXIS_PCIE_RQ_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 62 : 137;
parameter AXIS_PCIE_CQ_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 85 : 183;
parameter AXIS_PCIE_CC_USER_WIDTH = AXIS_PCIE_DATA_WIDTH < 512 ? 33 : 81;

parameter AXIS_ETH_DATA_WIDTH = 512;
parameter AXIS_ETH_KEEP_WIDTH = (AXIS_ETH_DATA_WIDTH / 8);

// Clock and reset
wire        pcie_user_clk;
wire        pcie_user_reset;

// extra register for pcie_user_reset signal
wire pcie_user_reset_int;
(* shreg_extract = "no" *)
reg pcie_user_reset_reg_1 = 1'b1;
(* shreg_extract = "no" *)
reg pcie_user_reset_reg_2 = 1'b1;

always @(posedge pcie_user_clk) begin
    pcie_user_reset_reg_1 <= pcie_user_reset_int;
    pcie_user_reset_reg_2 <= pcie_user_reset_reg_1;
end

assign pcie_user_reset = pcie_user_reset_reg_2;

// Internal 50 MHz clock
wire        clk_50mhz_int;
wire        rst_50mhz_int;

// Internal 125 MHz clock
wire        clk_125mhz_int;
wire        rst_125mhz_int;

// PCIe
wire pcie_sys_clk;
wire pcie_sys_clk_gt;

IBUFDS_GTE4 #(
    .REFCLK_HROW_CK_SEL(2'b00)
)
ibufds_gte4_pcie_mgt_refclk_inst (
    .I             (pcie_refclk_1_p),
    .IB            (pcie_refclk_1_n),
    .CEB           (1'b0),
    .O             (pcie_sys_clk_gt),
    .ODIV2         (pcie_sys_clk)
);

wire         qsfp_led_act;
wire         qsfp_led_stat_g;
wire         qsfp_led_stat_y;
wire         qsfp_rx_status;

assign led[0] = qsfp_led_act;
assign led[1] = qsfp_led_stat_g;
assign led[2] = qsfp_led_stat_y;

assign led[3] = qsfp1_modsell;
assign led[4] = qsfp1_resetl;
assign led[5] = qsfp1_modprsl;
assign led[6] = qsfp1_intl;
assign led[7] = qsfp1_lpmode;

assign qsfp1_modsell = 1'b0;    
assign qsfp1_resetl  = 1'b1;   
assign qsfp1_lpmode  = 1'b0; 

assign qsfp_led_stat_g = qsfp_rx_status;

wire        qsfp1_stat_rx_aligned;
wire        qsfp1_stat_rx_aligned_err;
wire        qsfp1_tx_ovfout;
wire        qsfp1_tx_unfout;
wire        stat_rx_received_local_fault;
wire        stat_rx_remote_fault        ;
wire        stat_rx_internal_local_fault;
wire        stat_rx_local_fault         ;
wire        stat_tx_frame_error         ;
wire        stat_tx_local_fault         ;

//Interface between PCIeController and HanGuHTN_Top
wire        [AXIS_PCIE_DATA_WIDTH-1:0]              pcie_axis_rq_tdata;
wire        [AXIS_PCIE_KEEP_WIDTH-1:0]              pcie_axis_rq_tkeep;
wire                                                pcie_axis_rq_tlast;
wire                                                pcie_axis_rq_tready;
wire        [AXIS_PCIE_RQ_USER_WIDTH-1:0]           pcie_axis_rq_tuser;
wire                                                pcie_axis_rq_tvalid;

wire        [AXIS_PCIE_DATA_WIDTH-1:0]              pcie_axis_rc_tdata;
wire        [AXIS_PCIE_KEEP_WIDTH-1:0]              pcie_axis_rc_tkeep;
wire                                                pcie_axis_rc_tlast;
wire                                                pcie_axis_rc_tready;
wire        [AXIS_PCIE_RC_USER_WIDTH-1:0]           pcie_axis_rc_tuser;
wire                                                pcie_axis_rc_tvalid;

wire        [AXIS_PCIE_DATA_WIDTH-1:0]              pcie_axis_cq_tdata;
wire        [AXIS_PCIE_KEEP_WIDTH-1:0]              pcie_axis_cq_tkeep;
wire                                                pcie_axis_cq_tlast;
wire                                                pcie_axis_cq_tready;
wire        [AXIS_PCIE_CQ_USER_WIDTH-1:0]           pcie_axis_cq_tuser;
wire                                                pcie_axis_cq_tvalid;

wire        [AXIS_PCIE_DATA_WIDTH-1:0]              pcie_axis_cc_tdata;
wire        [AXIS_PCIE_KEEP_WIDTH-1:0]              pcie_axis_cc_tkeep;
wire                                                pcie_axis_cc_tlast;
wire                                                pcie_axis_cc_tready;
wire        [AXIS_PCIE_CC_USER_WIDTH-1:0]           pcie_axis_cc_tuser;
wire                                                pcie_axis_cc_tvalid;

wire        [2:0]                                   cfg_max_payload;
wire        [2:0]                                   cfg_max_read_req;

//Interface between HanGuHTN_Top and MACSubsystem
wire        [AXIS_ETH_DATA_WIDTH-1:0]               qsfp_tx_axis_tdata;
wire        [AXIS_ETH_KEEP_WIDTH-1:0]               qsfp_tx_axis_tkeep;
wire                                                qsfp_tx_axis_tvalid;
wire                                                qsfp_tx_axis_tready;
wire                                                qsfp_tx_axis_tlast;
wire        [0:0]                              qsfp_tx_axis_tuser;

wire        [AXIS_ETH_DATA_WIDTH-1:0]               qsfp_rx_axis_tdata;
wire        [AXIS_ETH_KEEP_WIDTH-1:0]               qsfp_rx_axis_tkeep;
wire                                                qsfp_rx_axis_tvalid;
wire                                                qsfp_rx_axis_tlast;
wire        [0:0]                              qsfp_rx_axis_tuser;

wire                                                qsfp_tx_clk;
wire                                                qsfp_rx_clk;
wire                                                qsfp_rx_rst;
wire                                                qsfp_tx_rst;


wire mmcm_rst;
wire mmcm_locked;

assign mmcm_rst = pcie_user_reset;

clk_wiz_0 inst_clk
(
    // Clock out ports
    .clk_out1(clk_125mhz_int),    
    .clk_out2(clk_50mhz_int),
    // Status and control signals
    .reset(mmcm_rst), // input reset
    .locked(mmcm_locked),       // output locked
    // Clock in ports
    .clk_in1_p(clk_100mhz_p),    // input clk_in1_p  100MHz
    .clk_in1_n(clk_100mhz_n)
);    // input clk_in1_n

sync_reset #(
    .N(4)
)
sync_reset_50mhz_inst (
    .clk(clk_50mhz_int),
    .rst(~mmcm_locked),
    .out(rst_50mhz_int)
);

sync_reset #(
    .N(4)
)
sync_reset_125mhz_inst (
    .clk(clk_125mhz_int),
    .rst(~mmcm_locked),
    .out(rst_125mhz_int)
);

pcie4c_uscale_plus_0 PCIeController_Inst (
//I/O Interface
    .pci_exp_txn                                    (       pcie_tx_n           ),
    .pci_exp_txp                                    (       pcie_tx_p           ),
    .pci_exp_rxn                                    (       pcie_rx_n           ),
    .pci_exp_rxp                                    (       pcie_rx_p           ),

//Clock and Reset
    .user_clk                                       (       pcie_user_clk       ),
    .user_reset                                     (       pcie_user_reset_int ),
    .user_lnk_up                                    (       user_lnk_up         ),

//User Interface
    .s_axis_rq_tdata                                (       pcie_axis_rq_tdata      ),
    .s_axis_rq_tkeep                                (       pcie_axis_rq_tkeep      ),
    .s_axis_rq_tlast                                (       pcie_axis_rq_tlast      ),
    .s_axis_rq_tready                               (       pcie_axis_rq_tready     ),
    .s_axis_rq_tuser                                (       pcie_axis_rq_tuser      ),
    .s_axis_rq_tvalid                               (       pcie_axis_rq_tvalid     ),

    .m_axis_rc_tdata                                (       pcie_axis_rc_tdata      ),
    .m_axis_rc_tkeep                                (       pcie_axis_rc_tkeep      ),
    .m_axis_rc_tlast                                (       pcie_axis_rc_tlast      ),
    .m_axis_rc_tready                               (       pcie_axis_rc_tready     ),
    .m_axis_rc_tuser                                (       pcie_axis_rc_tuser      ),
    .m_axis_rc_tvalid                               (       pcie_axis_rc_tvalid     ),

    .m_axis_cq_tdata                                (       pcie_axis_cq_tdata      ),
    .m_axis_cq_tkeep                                (       pcie_axis_cq_tkeep      ),
    .m_axis_cq_tlast                                (       pcie_axis_cq_tlast      ),
    .m_axis_cq_tready                               (       pcie_axis_cq_tready     ),
    .m_axis_cq_tuser                                (       pcie_axis_cq_tuser      ),
    .m_axis_cq_tvalid                               (       pcie_axis_cq_tvalid     ),

    .s_axis_cc_tdata                                (       pcie_axis_cc_tdata      ),
    .s_axis_cc_tkeep                                (       pcie_axis_cc_tkeep      ),
    .s_axis_cc_tlast                                (       pcie_axis_cc_tlast      ),
    .s_axis_cc_tready                               (       pcie_axis_cc_tready     ),
    .s_axis_cc_tuser                                (       pcie_axis_cc_tuser      ),
    .s_axis_cc_tvalid                               (       pcie_axis_cc_tvalid     ),

    .pcie_rq_seq_num0                               (       ),      //Not used
    .pcie_rq_seq_num_vld0                           (       ),      //Not used
    .pcie_rq_seq_num1                               (       ),      //Not used
    .pcie_rq_seq_num_vld1                           (       ),      //Not used
    .pcie_rq_tag0                                   (       ),      //Not used
    .pcie_rq_tag1                                   (       ),      //Not used
    .pcie_rq_tag_av                                 (       ),      //Not used
    .pcie_rq_tag_vld0                               (       ),      //Not used
    .pcie_rq_tag_vld1                               (       ),      //Not used

    .pcie_tfc_nph_av                                (       ),      //Not used
    .pcie_tfc_npd_av                                (       ),      //Not used

    .pcie_cq_np_req                                 (       1'b1     ),     //Keep it high, no back pressure on non-posted request
    .pcie_cq_np_req_count                           (                ),     //Not used

    .cfg_phy_link_down                              (                           ),
    .cfg_phy_link_status                            (                           ),
    .cfg_negotiated_width                           (                           ),
    .cfg_current_speed                              (                           ),
    .cfg_max_payload                                (       cfg_max_payload     ),
    .cfg_max_read_req                               (       cfg_max_read_req    ),
    .cfg_function_status                            (                           ),
    .cfg_function_power_state                       (                           ),
    .cfg_vf_status                                  (                           ),
    .cfg_vf_power_state                             (                           ),
    .cfg_link_power_state                           (                           ),

    .cfg_mgmt_addr                                  (       10'd0               ),  //i, 10
    .cfg_mgmt_function_number                       (       8'd0                ),  //i, 8
    .cfg_mgmt_write                                 (       1'd0                ),  //i, 1
    .cfg_mgmt_write_data                            (       32'd0               ),  //i, 32
    .cfg_mgmt_byte_enable                           (       'd0                 ),  //i, 4
    .cfg_mgmt_read                                  (       'd0                 ), //i, 1
    .cfg_mgmt_read_data                             (                           ),  //o, 32
    .cfg_mgmt_read_write_done                       (                           ),  //o, 1
    .cfg_mgmt_debug_access                          (       'd0                 ),  //i, 1

    .cfg_err_cor_out                                (       ),
    .cfg_err_nonfatal_out                           (       ),
    .cfg_err_fatal_out                              (       ),
    .cfg_local_error_valid                          (       ),
    .cfg_local_error_out                            (       ),
    .cfg_ltssm_state                                (       ),
    .cfg_rx_pm_state                                (       ),
    .cfg_tx_pm_state                                (       ),
    .cfg_rcb_status                                 (       ),
    .cfg_obff_enable                                (       ),
    .cfg_pl_status_change                           (       ),
    .cfg_tph_requester_enable                       (       ),
    .cfg_tph_st_mode                                (       ),
    .cfg_vf_tph_requester_enable                    (       ),
    .cfg_vf_tph_st_mode                             (       ),

    .cfg_msg_received                               (                   ),
    .cfg_msg_received_data                          (                   ),
    .cfg_msg_received_type                          (                   ),
    .cfg_msg_transmit                               (       1'b0        ),
    .cfg_msg_transmit_type                          (       3'd0        ),
    .cfg_msg_transmit_data                          (       32'd0       ),
    .cfg_msg_transmit_done                          (                   ),

    .cfg_fc_ph                                      (                   ),
    .cfg_fc_pd                                      (                   ),
    .cfg_fc_nph                                     (                   ),
    .cfg_fc_npd                                     (                   ),
    .cfg_fc_cplh                                    (                   ),
    .cfg_fc_cpld                                    (                   ),
    .cfg_fc_sel                                     (       3'd0        ),

    .cfg_dsn                                        (       64'd0       ),

    .cfg_power_state_change_ack                     (       1'b1        ),
    .cfg_power_state_change_interrupt               (                   ),

    .cfg_err_cor_in                                 (       1'b0        ),
    .cfg_err_uncor_in                               (       1'b00       ),
    .cfg_flr_in_process                             (                   ),
    .cfg_flr_done                                   (       4'd0        ),
    .cfg_vf_flr_in_process                          (                   ),
    .cfg_vf_flr_func_num                            (       8'd0        ),
    .cfg_vf_flr_done                                (       8'd0        ),

    .cfg_link_training_enable                       (       1'b1        ),

    .cfg_interrupt_int                              (       4'd0        ),
    .cfg_interrupt_pending                          (       4'd0        ),
    .cfg_interrupt_sent                             (                   ),
    .cfg_interrupt_msi_enable                       (                   ),
    .cfg_interrupt_msi_mmenable                     (                   ),
    .cfg_interrupt_msi_mask_update                  (                   ),
    .cfg_interrupt_msi_data                         (                   ),
    .cfg_interrupt_msi_select                       (       4'd0        ),
    .cfg_interrupt_msi_int                          (       32'd0       ),
    .cfg_interrupt_msi_pending_status               (       64'd0       ),
    .cfg_interrupt_msi_pending_status_data_enable   (       1'b0        ),
    .cfg_interrupt_msi_pending_status_function_num  (       2'd0        ),
    .cfg_interrupt_msi_sent                         (                   ),
    .cfg_interrupt_msi_fail                         (                   ),
    .cfg_interrupt_msi_attr                         (       3'd0        ),
    .cfg_interrupt_msi_tph_present                  (       1'd0        ),
    .cfg_interrupt_msi_tph_type                     (       2'd0        ),
    .cfg_interrupt_msi_tph_st_tag                   (       9'd0        ),
    .cfg_interrupt_msi_function_number              (       8'd0        ),

    .cfg_pm_aspm_l1_entry_reject                    (       1'b0                ),
    .cfg_pm_aspm_tx_l0s_entry_disable               (       1'b0                ),

    .cfg_hot_reset_out                              (                           ),

    .cfg_config_space_enable                        (       1'b1                ),
    .cfg_req_pm_transition_l23_ready                (       1'b0                ),
    .cfg_hot_reset_in                               (       1'b0                ),

    .cfg_ds_port_number                             (       8'd0                ),
    .cfg_ds_bus_number                              (       8'd0                ),
    .cfg_ds_device_number                           (       5'd0                ),

    .sys_clk                                        (       pcie_sys_clk        ),
    .sys_clk_gt                                     (       pcie_sys_clk_gt     ),
    .sys_reset                                      (       pcie_reset_n        ),

    .phy_rdy_out                                    (                           )
);

HanGuHTN_Top HanGuHTN_Top_Inst(
    .pcie_clk                                       (       pcie_user_clk           ),
    .pcie_rst                                       (       pcie_user_reset         ),

    .user_clk                                       (       clk_50mhz_int           ),
    .user_rst                                       (       rst_50mhz_int           ),

    .mac_tx_clk                                     (       qsfp_tx_clk             ),
    .mac_tx_rst                                     (       qsfp_tx_rst             ),

    .mac_rx_clk                                     (       qsfp_tx_clk             ),
    .mac_rx_rst                                     (       qsfp_tx_rst             ),

    .cfg_max_payload                                (       cfg_max_payload         ),
    // .cfg_max_read_req                               (       cfg_max_read_req        ),
    .cfg_max_read_req                               (       3'b001                  ),      //Now we only support 256 Byte Max Read Req
    .tl_cfg_busdev                                  (                               ), 

    .s_axis_rq_tvalid                               (       pcie_axis_rq_tvalid     ),
    .s_axis_rq_tlast                                (       pcie_axis_rq_tlast      ),
    .s_axis_rq_tkeep                                (       pcie_axis_rq_tkeep      ),
    .s_axis_rq_tuser                                (       pcie_axis_rq_tuser      ),
    .s_axis_rq_tdata                                (       pcie_axis_rq_tdata      ),
    .s_axis_rq_tready                               (       pcie_axis_rq_tready     ),

    .m_axis_rc_tvalid                               (       pcie_axis_rc_tvalid     ),
    .m_axis_rc_tlast                                (       pcie_axis_rc_tlast      ),
    .m_axis_rc_tkeep                                (       pcie_axis_rc_tkeep      ),
    .m_axis_rc_tuser                                (       pcie_axis_rc_tuser      ),
    .m_axis_rc_tdata                                (       pcie_axis_rc_tdata      ),
    .m_axis_rc_tready                               (       pcie_axis_rc_tready     ),

    .m_axis_cq_tvalid                               (       pcie_axis_cq_tvalid     ),
    .m_axis_cq_tlast                                (       pcie_axis_cq_tlast      ),
    .m_axis_cq_tkeep                                (       pcie_axis_cq_tkeep      ),
    .m_axis_cq_tuser                                (       pcie_axis_cq_tuser      ),
    .m_axis_cq_tdata                                (       pcie_axis_cq_tdata      ),
    .m_axis_cq_tready                               (       pcie_axis_cq_tready     ),

    .s_axis_cc_tvalid                               (       pcie_axis_cc_tvalid     ),
    .s_axis_cc_tlast                                (       pcie_axis_cc_tlast      ),
    .s_axis_cc_tkeep                                (       pcie_axis_cc_tkeep      ),
    .s_axis_cc_tuser                                (       pcie_axis_cc_tuser      ),
    .s_axis_cc_tdata                                (       pcie_axis_cc_tdata      ),
    .s_axis_cc_tready                               (       pcie_axis_cc_tready     ),

    .mac_tx_valid                                   (       qsfp_tx_axis_tvalid   ),
    .mac_tx_ready                                   (       qsfp_tx_axis_tready   ),
    .mac_tx_start                                   (                             ),
    .mac_tx_last                                    (       qsfp_tx_axis_tlast    ),
    .mac_tx_keep                                    (       qsfp_tx_axis_tkeep    ),
    .mac_tx_user                                    (       qsfp_tx_axis_tuser    ),
    .mac_tx_data                                    (       qsfp_tx_axis_tdata    ),

    .mac_rx_valid                                   (       qsfp_rx_axis_tvalid   ),
    .mac_rx_ready                                   (       qsfp_rx_axis_tready   ),
    .mac_rx_start                                   (       'd0                   ),
    .mac_rx_last                                    (       qsfp_rx_axis_tlast    ),
    .mac_rx_keep                                    (       qsfp_rx_axis_tkeep    ),
    .mac_rx_user                                    (       'd0                   ),
    .mac_rx_data                                    (       qsfp_rx_axis_tdata    )
);

cmac_usplus_0 MACSubsystem_Inst (
    .gt0_rxp_in                             (       qsfp_rx1_p      ),
    .gt0_rxn_in                             (       qsfp_rx1_n      ),
    .gt1_rxp_in                             (       qsfp_rx2_p      ),
    .gt1_rxn_in                             (       qsfp_rx2_n      ),
    .gt2_rxp_in                             (       qsfp_rx3_p      ),
    .gt2_rxn_in                             (       qsfp_rx3_n      ),
    .gt3_rxp_in                             (       qsfp_rx4_p      ),
    .gt3_rxn_in                             (       qsfp_rx4_n      ),
    .gt0_txp_out                            (       qsfp_tx1_p      ),
    .gt0_txn_out                            (       qsfp_tx1_n      ),
    .gt1_txp_out                            (       qsfp_tx2_p      ),
    .gt1_txn_out                            (       qsfp_tx2_n      ),
    .gt2_txp_out                            (       qsfp_tx3_p      ),
    .gt2_txn_out                            (       qsfp_tx3_n      ),
    .gt3_txp_out                            (       qsfp_tx4_p      ),
    .gt3_txn_out                            (       qsfp_tx4_n      ),

    .gt_txusrclk2                           (       qsfp_tx_clk         ),
    .gt_loopback_in                         (       12'd0               ),
    .gt_rxrecclkout                         (                           ),
    .gt_powergoodout                        (                           ),
    .gt_ref_clk_out                         (                           ),
                                    
    .gtwiz_reset_tx_datapath                (       1'b0                        ),
    .gtwiz_reset_rx_datapath                (       1'b0                        ),
    .sys_reset                              (       rst_125mhz_int              ),
    .gt_ref_clk_p                           (       qsfp_mgt_refclk_0_p         ),
    .gt_ref_clk_n                           (       qsfp_mgt_refclk_0_n         ),
    .init_clk                               (       clk_125mhz_int              ),

    .rx_axis_tvalid                         (       qsfp_rx_axis_tvalid         ),
    .rx_axis_tdata                          (       qsfp_rx_axis_tdata          ),
    .rx_axis_tlast                          (       qsfp_rx_axis_tlast          ),
    .rx_axis_tkeep                          (       qsfp_rx_axis_tkeep          ),
    .rx_axis_tuser                          (       qsfp_rx_axis_tuser[0]       ),

    .rx_otn_bip8_0                          (                                   ),
    .rx_otn_bip8_1                          (                                   ),
    .rx_otn_bip8_2                          (                                   ),
    .rx_otn_bip8_3                          (                                   ),
    .rx_otn_bip8_4                          (                                   ),
    .rx_otn_data_0                          (                                   ),
    .rx_otn_data_1                          (                                   ),
    .rx_otn_data_2                          (                                   ),
    .rx_otn_data_3                          (                                   ),
    .rx_otn_data_4                          (                                   ),
    .rx_otn_ena                             (                                   ),
    .rx_otn_lane0                           (                                   ),
    .rx_otn_vlmarker                        (                                   ),
    .rx_preambleout                         (                                   ),
    .usr_rx_reset                           (       qsfp_rx_rst                 ),
    .gt_rxusrclk2                           (       qsfp_rx_clk                 ),

    .stat_rx_aligned                        (       qsfp1_stat_rx_aligned),
    .stat_rx_aligned_err                    (       qsfp1_stat_rx_aligned_err),
    .stat_rx_bad_code                       (       ),
    .stat_rx_bad_fcs                        (       ),
    .stat_rx_bad_preamble                   (       ),
    .stat_rx_bad_sfd                        (       ),
    .stat_rx_bip_err_0                      (       ),
    .stat_rx_bip_err_1                      (       ),
    .stat_rx_bip_err_10                     (       ),
    .stat_rx_bip_err_11                     (       ),
    .stat_rx_bip_err_12                     (       ),
    .stat_rx_bip_err_13                     (       ),
    .stat_rx_bip_err_14                     (       ),
    .stat_rx_bip_err_15                     (       ),
    .stat_rx_bip_err_16                     (       ),
    .stat_rx_bip_err_17                     (       ),
    .stat_rx_bip_err_18                     (       ),
    .stat_rx_bip_err_19                     (       ),
    .stat_rx_bip_err_2                      (       ),
    .stat_rx_bip_err_3                      (       ),
    .stat_rx_bip_err_4                      (       ),
    .stat_rx_bip_err_5                      (       ),
    .stat_rx_bip_err_6                      (       ),
    .stat_rx_bip_err_7                      (       ),
    .stat_rx_bip_err_8                      (       ),
    .stat_rx_bip_err_9                      (       ),
    .stat_rx_block_lock                     (       ),
    .stat_rx_broadcast                      (       ),
    .stat_rx_fragment                       (       ),
    .stat_rx_framing_err_0                  (       ),
    .stat_rx_framing_err_1                  (       ),
    .stat_rx_framing_err_10                 (       ),
    .stat_rx_framing_err_11                 (       ),
    .stat_rx_framing_err_12                 (       ),
    .stat_rx_framing_err_13                 (       ),
    .stat_rx_framing_err_14                 (       ),
    .stat_rx_framing_err_15                 (       ),
    .stat_rx_framing_err_16                 (       ),
    .stat_rx_framing_err_17                 (       ),
    .stat_rx_framing_err_18                 (       ),
    .stat_rx_framing_err_19                 (       ),
    .stat_rx_framing_err_2                  (       ),
    .stat_rx_framing_err_3                  (       ),
    .stat_rx_framing_err_4                  (       ),
    .stat_rx_framing_err_5                  (       ),
    .stat_rx_framing_err_6                  (       ),
    .stat_rx_framing_err_7                  (       ),
    .stat_rx_framing_err_8                  (       ),
    .stat_rx_framing_err_9                  (       ),
    .stat_rx_framing_err_valid_0            (       ),
    .stat_rx_framing_err_valid_1            (       ),
    .stat_rx_framing_err_valid_10           (       ),
    .stat_rx_framing_err_valid_11           (       ),
    .stat_rx_framing_err_valid_12           (       ),
    .stat_rx_framing_err_valid_13           (       ),
    .stat_rx_framing_err_valid_14           (       ),
    .stat_rx_framing_err_valid_15           (       ),
    .stat_rx_framing_err_valid_16           (       ),
    .stat_rx_framing_err_valid_17           (       ),
    .stat_rx_framing_err_valid_18           (       ),
    .stat_rx_framing_err_valid_19           (       ),
    .stat_rx_framing_err_valid_2            (       ),
    .stat_rx_framing_err_valid_3            (       ),
    .stat_rx_framing_err_valid_4            (       ),
    .stat_rx_framing_err_valid_5            (       ),
    .stat_rx_framing_err_valid_6            (       ),
    .stat_rx_framing_err_valid_7            (       ),
    .stat_rx_framing_err_valid_8            (       ),
    .stat_rx_framing_err_valid_9            (       ),
    .stat_rx_got_signal_os                  (       ),
    .stat_rx_hi_ber                         (       ),
    .stat_rx_inrangeerr                     (       ),
    .stat_rx_internal_local_fault           (  stat_rx_internal_local_fault     ),
    .stat_rx_jabber                         (       ),
    .stat_rx_local_fault                    (  stat_rx_local_fault     ),
    .stat_rx_mf_err                         (       ),
    .stat_rx_mf_len_err                     (       ),
    .stat_rx_mf_repeat_err                  (       ),
    .stat_rx_misaligned                     (       ),
    .stat_rx_multicast                      (       ),
    .stat_rx_oversize                       (       ),
    .stat_rx_packet_1024_1518_bytes         (       ),
    .stat_rx_packet_128_255_bytes           (       ),
    .stat_rx_packet_1519_1522_bytes         (       ),
    .stat_rx_packet_1523_1548_bytes         (       ),
    .stat_rx_packet_1549_2047_bytes         (       ),
    .stat_rx_packet_2048_4095_bytes         (       ),
    .stat_rx_packet_256_511_bytes           (       ),
    .stat_rx_packet_4096_8191_bytes         (       ),
    .stat_rx_packet_512_1023_bytes          (       ),
    .stat_rx_packet_64_bytes                (       ),
    .stat_rx_packet_65_127_bytes            (       ),
    .stat_rx_packet_8192_9215_bytes         (       ),
    .stat_rx_packet_bad_fcs                 (       ),
    .stat_rx_packet_large                   (       ),
    .stat_rx_packet_small                   (       ),

    .ctl_rx_enable                          (   1'b1       ),
    .ctl_rx_force_resync                    (   1'b0       ),
    .ctl_rx_test_pattern                    (   1'b0       ),
    .ctl_rsfec_ieee_error_indication_mode   (   1'b0       ),
    .ctl_rx_rsfec_enable                    (   1'b1       ),
    .ctl_rx_rsfec_enable_correction         (   1'b1       ),
    .ctl_rx_rsfec_enable_indication         (   1'b1       ),
    .core_rx_reset                          (   1'b0       ),
    .rx_clk                                 (   qsfp_tx_clk        ),

    .stat_rx_received_local_fault           (   stat_rx_received_local_fault    ),
    .stat_rx_remote_fault                   (   stat_rx_remote_fault    ),
    .stat_rx_status                         (   qsfp_rx_status     ),
    .stat_rx_stomped_fcs                    (       ),
    .stat_rx_synced                         (       ),
    .stat_rx_synced_err                     (       ),
    .stat_rx_test_pattern_mismatch          (       ),
    .stat_rx_toolong                        (       ),
    .stat_rx_total_bytes                    (       ),
    .stat_rx_total_good_bytes               (       ),
    .stat_rx_total_good_packets             (       ),
    .stat_rx_total_packets                  (       ),
    .stat_rx_truncated                      (       ),
    .stat_rx_undersize                      (       ),
    .stat_rx_unicast                        (       ),
    .stat_rx_vlan                           (       ),
    .stat_rx_pcsl_demuxed                   (       ),
    .stat_rx_pcsl_number_0                  (       ),
    .stat_rx_pcsl_number_1                  (       ),
    .stat_rx_pcsl_number_10                 (       ),
    .stat_rx_pcsl_number_11                 (       ),
    .stat_rx_pcsl_number_12                 (       ),
    .stat_rx_pcsl_number_13                 (       ),
    .stat_rx_pcsl_number_14                 (       ),
    .stat_rx_pcsl_number_15                 (       ),
    .stat_rx_pcsl_number_16                 (       ),
    .stat_rx_pcsl_number_17                 (       ),
    .stat_rx_pcsl_number_18                 (       ),
    .stat_rx_pcsl_number_19                 (       ),
    .stat_rx_pcsl_number_2                  (       ),
    .stat_rx_pcsl_number_3                  (       ),
    .stat_rx_pcsl_number_4                  (       ),
    .stat_rx_pcsl_number_5                  (       ),
    .stat_rx_pcsl_number_6                  (       ),
    .stat_rx_pcsl_number_7                  (       ),
    .stat_rx_pcsl_number_8                  (       ),
    .stat_rx_pcsl_number_9                  (       ),
    .stat_rx_rsfec_am_lock0                 (       ),
    .stat_rx_rsfec_am_lock1                 (       ),
    .stat_rx_rsfec_am_lock2                 (       ),
    .stat_rx_rsfec_am_lock3                 (       ),
    .stat_rx_rsfec_corrected_cw_inc         (       ),
    .stat_rx_rsfec_cw_inc                   (       ),
    .stat_rx_rsfec_err_count0_inc           (       ),
    .stat_rx_rsfec_err_count1_inc           (       ),
    .stat_rx_rsfec_err_count2_inc           (       ),
    .stat_rx_rsfec_err_count3_inc           (       ),
    .stat_rx_rsfec_hi_ser                   (       ),
    .stat_rx_rsfec_lane_alignment_status    (       ),
    .stat_rx_rsfec_lane_fill_0              (       ),
    .stat_rx_rsfec_lane_fill_1              (       ),
    .stat_rx_rsfec_lane_fill_2              (       ),
    .stat_rx_rsfec_lane_fill_3              (       ),
    .stat_rx_rsfec_lane_mapping             (       ),
    .stat_rx_rsfec_uncorrected_cw_inc       (       ),

    .stat_tx_bad_fcs                        (       ),
    .stat_tx_broadcast                      (       ),
    .stat_tx_frame_error                    (  stat_tx_frame_error     ),
    .stat_tx_local_fault                    (   stat_tx_local_fault      ),
    .stat_tx_multicast                      (       ),
    .stat_tx_packet_1024_1518_bytes         (       ),
    .stat_tx_packet_128_255_bytes           (       ),
    .stat_tx_packet_1519_1522_bytes         (       ),
    .stat_tx_packet_1523_1548_bytes         (       ),
    .stat_tx_packet_1549_2047_bytes         (       ),
    .stat_tx_packet_2048_4095_bytes         (       ),
    .stat_tx_packet_256_511_bytes           (       ),
    .stat_tx_packet_4096_8191_bytes         (       ),
    .stat_tx_packet_512_1023_bytes          (       ),
    .stat_tx_packet_64_bytes                (       ),
    .stat_tx_packet_65_127_bytes            (       ),
    .stat_tx_packet_8192_9215_bytes         (       ),
    .stat_tx_packet_large                   (       ),
    .stat_tx_packet_small                   (       ),
    .stat_tx_total_bytes                    (       ),
    .stat_tx_total_good_bytes               (       ),
    .stat_tx_total_good_packets             (       ),
    .stat_tx_total_packets                  (       ),
    .stat_tx_unicast                        (       ),
    .stat_tx_vlan                           (       ),

    .ctl_tx_enable                          (   1'b1       ),
    .ctl_tx_test_pattern                    (   1'b0       ),
    .ctl_tx_rsfec_enable                    (   1'b1       ),
    .ctl_tx_send_idle                       (   1'b0       ),
    .ctl_tx_send_rfi                        (   1'b0       ),
    .ctl_tx_send_lfi                        (   1'b0       ),
    .core_tx_reset                          (   1'b0       ),

    .tx_axis_tready                         (   qsfp_tx_axis_tready         ),
    .tx_axis_tvalid                         (   qsfp_tx_axis_tvalid         ),
    .tx_axis_tdata                          (   qsfp_tx_axis_tdata          ),
    .tx_axis_tlast                          (   qsfp_tx_axis_tlast          ),
    .tx_axis_tkeep                          (   qsfp_tx_axis_tkeep          ),
    .tx_axis_tuser                          (   qsfp_tx_axis_tuser       ),

    .tx_ovfout                              (   qsfp1_tx_ovfout              ),
    .tx_unfout                              (   qsfp1_tx_unfout              ),
    .tx_preamblein                          (   56'd0                           ),
    .usr_tx_reset                           (   qsfp_tx_rst                     ),

    .core_drp_reset                         (   1'b0        ),
    .drp_clk                                (   1'b0        ),
    .drp_addr                               (   10'd0       ),
    .drp_di                                 (   16'd0       ),
    .drp_en                                 (   1'b0        ),
    .drp_do                                 (               ),
    .drp_rdy                                (               ),
    .drp_we                                 (   1'b0        )                               
);

`ifdef  ILA_ON
    ila_cmac ila_cmac_inst(
        .clk    (   qsfp_tx_clk          ),

        .probe0 (   qsfp_tx_axis_tdata  ),
        .probe1 (   qsfp_tx_axis_tkeep  ),
        .probe2 (   qsfp_tx_axis_tvalid ),
        .probe3 (   qsfp_tx_axis_tready ),
        .probe4 (   qsfp_tx_axis_tlast  ),
        .probe5 (   qsfp_tx_axis_tuser  ),

        .probe6     (   qsfp_rx_axis_tdata  ),
        .probe7     (   qsfp_rx_axis_tkeep  ),
        .probe8     (   qsfp_rx_axis_tvalid ),
        .probe9     (   qsfp_rx_axis_tready ),
        .probe10    (   qsfp_rx_axis_tlast  ),
        .probe11    (   qsfp_rx_axis_tuser  ),

        .probe12     (qsfp1_stat_rx_aligned),
        .probe13     (qsfp1_stat_rx_aligned_err),

        .probe14     ( stat_rx_received_local_fault),
        .probe15     ( stat_rx_remote_fault        ),
        .probe16     ( stat_rx_internal_local_fault),
        .probe17     ( stat_rx_local_fault         ),
        .probe18     ( stat_tx_frame_error         ),
        .probe19     ( stat_tx_local_fault         ),

        .probe20     (qsfp1_modsell),        
        .probe21    (qsfp1_resetl ),        
        .probe22    (qsfp1_modprsl),        
        .probe23    (qsfp1_intl   ),        
        .probe24    (qsfp1_lpmode )
    );

`endif

endmodule