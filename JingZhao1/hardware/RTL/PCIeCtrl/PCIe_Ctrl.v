`timescale 1ns / 100ps
//*************************************************************************
// > File Name   : PCIe_Ctrl.v
// > Description : PCIe_Ctrl, PCIe end point controller
// > Author      : Kangning
// > Date        : 2021-09-07
//*************************************************************************

module PCIe_Ctrl # (
  parameter PL_LINK_CAP_MAX_LINK_WIDTH = 8,                       // PCIe Lane Width
  parameter PL_LINK_CAP_MAX_LINK_SPEED = 4,                       // 1- GEN1, 2 - GEN2, 4 - GEN3
  parameter CLK_SHARING_EN             = "FALSE",                 // Enable Clock Sharing
  parameter C_DATA_WIDTH               = 256,                     // AXI interface data width
  parameter KEEP_WIDTH                 = C_DATA_WIDTH / 8,        // TSTRB width
  parameter PCIE_REFCLK_FREQ           = 0,                       // PCIe Reference Clock Frequency
  parameter PCIE_USERCLK1_FREQ         = 2,                       // PCIe Core Clock Frequency - Core Clock Freq
  parameter PCIE_USERCLK2_FREQ         = 2                        // PCIe User Clock Frequency - User Clock Freq
)
(
    /* -------PCI Express (pci_exp) Interface{begin}------- */
    // Tx
    output [(PL_LINK_CAP_MAX_LINK_WIDTH-1):0]   pci_exp_txn,
    output [(PL_LINK_CAP_MAX_LINK_WIDTH-1):0]   pci_exp_txp,

    // Rx
    input  [(PL_LINK_CAP_MAX_LINK_WIDTH-1):0]   pci_exp_rxn,
    input  [(PL_LINK_CAP_MAX_LINK_WIDTH-1):0]   pci_exp_rxp,
    /* -------PCI Express (pci_exp) Interface{end}------- */

    /* -------Clock & GT COMMON Sharing Interface{begin}------- */
    output                                     pipe_pclk_out_slave,
    output                                     pipe_rxusrclk_out  ,
    output [(PL_LINK_CAP_MAX_LINK_WIDTH-1):0]  pipe_rxoutclk_out  ,
    output                                     pipe_dclk_out      ,
    output                                     pipe_userclk1_out  ,
    output                                     pipe_userclk2_out  ,
    output                                     pipe_oobclk_out    ,
    output                                     pipe_mmcm_lock_out ,
    input  [(PL_LINK_CAP_MAX_LINK_WIDTH-1):0]  pipe_pclk_sel_slave,
    input                                      pipe_mmcm_rst_n    ,
    /* -------Clock & GT COMMON Sharing Interface{end}------- */

    /* -------AXI-Stream Interface{begin}------- */
    // Common
    output                                     user_clk    ,
    output                                     user_reset  ,
    output                                     user_lnk_up ,
    output                                     user_app_rdy,

    input                                      s_axis_rq_tlast ,
    input  [C_DATA_WIDTH-1:0]                  s_axis_rq_tdata ,
    input  [59:0]                              s_axis_rq_tuser ,
    input  [KEEP_WIDTH-1:0]                    s_axis_rq_tkeep ,
    output [3:0]                               s_axis_rq_tready,
    input                                      s_axis_rq_tvalid,

    output  [C_DATA_WIDTH-1:0]                 m_axis_rc_tdata ,
    output  [74:0]                             m_axis_rc_tuser ,
    output                                     m_axis_rc_tlast ,
    output  [KEEP_WIDTH-1:0]                   m_axis_rc_tkeep ,
    output                                     m_axis_rc_tvalid,
    input                                      m_axis_rc_tready,

    output  [C_DATA_WIDTH-1:0]                 m_axis_cq_tdata ,
    output  [84:0]                             m_axis_cq_tuser ,
    output                                     m_axis_cq_tlast ,
    output  [KEEP_WIDTH-1:0]                   m_axis_cq_tkeep ,
    output                                     m_axis_cq_tvalid,
    input                                      m_axis_cq_tready,

    input  [C_DATA_WIDTH-1:0]                  s_axis_cc_tdata ,
    input  [32:0]                              s_axis_cc_tuser ,
    input                                      s_axis_cc_tlast ,
    input  [KEEP_WIDTH-1:0]                    s_axis_cc_tkeep ,
    input                                      s_axis_cc_tvalid,
    output  [3:0]                              s_axis_cc_tready,
    /* -------AXI-Stream Interface{end}------- */

    /* -------Configuration (CFG) Interface{begin}------- */
    // Transmit Flow Control Interface
    output  [1:0]                              pcie_tfc_nph_av    ,
    output  [1:0]                              pcie_tfc_npd_av    ,

    // Configuration Management Interface
    input  [18:0]                              cfg_mgmt_addr                    ,
    input                                      cfg_mgmt_write                   ,
    input  [31:0]                              cfg_mgmt_write_data              ,
    input  [3:0]                               cfg_mgmt_byte_enable             ,
    input                                      cfg_mgmt_read                    ,
    output  [31:0]                             cfg_mgmt_read_data               ,
    output                                     cfg_mgmt_read_write_done         ,
    input                                      cfg_mgmt_type1_cfg_reg_access    ,

    // Configuration Status Interface
    output                                     cfg_phy_link_down          ,
    output  [1:0]                              cfg_phy_link_status        ,
    output  [3:0]                              cfg_negotiated_width       ,
    output  [2:0]                              cfg_current_speed          ,
    output  [2:0]                              cfg_max_payload            ,
    output  [2:0]                              cfg_max_read_req           ,
    output  [7:0]                              cfg_function_status        ,
    output  [5:0]                              cfg_function_power_state   ,
    output  [11:0]                             cfg_vf_status              ,
    output  [17:0]                             cfg_vf_power_state         ,
    output  [1:0]                              cfg_link_power_state       ,
    output                                     cfg_err_cor_out            ,
    output                                     cfg_err_nonfatal_out       ,
    output                                     cfg_err_fatal_out          ,
    output                                     cfg_ltr_enable             ,
    output  [5:0]                              cfg_ltssm_state            ,
    output  [1:0]                              cfg_rcb_status             ,
    output  [1:0]                              cfg_dpa_substate_change    ,
    output  [1:0]                              cfg_obff_enable            ,
    output                                     cfg_pl_status_change       ,
    output  [1:0]                              cfg_tph_requester_enable   ,
    output  [5:0]                              cfg_tph_st_mode            ,
    output  [5:0]                              cfg_vf_tph_requester_enable,
    output  [17:0]                             cfg_vf_tph_st_mode         ,

    // Configuration Received Message Interface
    output                                     cfg_msg_received     ,
    output  [7:0]                              cfg_msg_received_data,
    output  [4:0]                              cfg_msg_received_type,

    // Configuration Transmit Message Interface
    input                                      cfg_msg_transmit     ,
    input   [2:0]                              cfg_msg_transmit_type,
    input   [31:0]                             cfg_msg_transmit_data,
    output                                     cfg_msg_transmit_done,

    // Configuration Flow Control Interface
    output  [7:0]                              cfg_fc_ph   ,
    output  [11:0]                             cfg_fc_pd   ,
    output  [7:0]                              cfg_fc_nph  ,
    output  [11:0]                             cfg_fc_npd  ,
    output  [7:0]                              cfg_fc_cplh ,
    output  [11:0]                             cfg_fc_cpld ,
    input   [2:0]                              cfg_fc_sel  ,

    // Per Function Status Interface
    input   [2:0]                              cfg_per_func_status_control,
    output  [15:0]                             cfg_per_func_status_data   ,

    // Configuration Control Interface
    input                                      cfg_hot_reset_in                 ,
    output                                     cfg_hot_reset_out                ,
    input                                      cfg_config_space_enable          ,
    output                                     cfg_per_function_update_done     ,
    input   [2:0]                              cfg_per_function_number          ,
    input                                      cfg_per_function_output_request  ,
    input   [63:0]                             cfg_dsn                          ,
    input   [7:0]                              cfg_ds_port_number               ,
    input   [7:0]                              cfg_ds_bus_number                ,
    input   [4:0]                              cfg_ds_device_number             ,
    input   [2:0]                              cfg_ds_function_number           ,
    input                                      cfg_err_cor_in                   ,
    input                                      cfg_err_uncor_in                 ,
    input                                      cfg_req_pm_transition_l23_ready  ,
    input                                      cfg_link_training_enable         ,

    // Configuration Interrupt Controller Interface
    input   [3:0]                              cfg_interrupt_int                ,
    input   [1:0]                              cfg_interrupt_pending            ,
    output                                     cfg_interrupt_sent               ,
    output  [1:0]                              cfg_interrupt_msi_enable         ,
    output  [5:0]                              cfg_interrupt_msi_vf_enable      ,
    output  [5:0]                              cfg_interrupt_msi_mmenable       ,
    output                                     cfg_interrupt_msi_mask_update    ,
    output  [31:0]                             cfg_interrupt_msi_data           ,
    input   [3:0]                              cfg_interrupt_msi_select         ,
    input   [31:0]                             cfg_interrupt_msi_int            ,
    input   [63:0]                             cfg_interrupt_msi_pending_status ,
    output                                     cfg_interrupt_msi_sent           ,
    output                                     cfg_interrupt_msi_fail           ,
    input   [2:0]                              cfg_interrupt_msi_attr           ,
    input                                      cfg_interrupt_msi_tph_present    ,
    input   [1:0]                              cfg_interrupt_msi_tph_type       ,
    input   [8:0]                              cfg_interrupt_msi_tph_st_tag     ,
    output  [1:0]                              cfg_interrupt_msix_enable        ,
    output  [1:0]                              cfg_interrupt_msix_mask          ,
    output  [5:0]                              cfg_interrupt_msix_vf_enable     ,
    output  [5:0]                              cfg_interrupt_msix_vf_mask       ,
    input   [31:0]                             cfg_interrupt_msix_data          ,
    input   [63:0]                             cfg_interrupt_msix_address       ,
    input                                      cfg_interrupt_msix_int           ,
    output                                     cfg_interrupt_msix_sent          ,
    output                                     cfg_interrupt_msix_fail          ,
    input   [2:0]                              cfg_interrupt_msi_function_number,

    output  [3:0]                              pcie_rq_seq_num     ,
    output                                     pcie_rq_seq_num_vld ,
    output  [5:0]                              pcie_rq_tag         ,
    output                                     pcie_rq_tag_vld     ,
    input                                      pcie_cq_np_req      ,
    output  [5:0]                              pcie_cq_np_req_count,

    // Vender ID
    input   [15:0]                             cfg_subsys_vend_id  ,
    /* -------Configuration (CFG) Interface{end}------- */

    // System(SYS) Interface
    input wire                                 sys_clk  ,
    input wire                                 sys_reset
);

wire                                     mmcm_lock;

// Wires used for external clocking connectivity
wire                                     pipe_pclk_out   ;
wire                                     pipe_txoutclk_in;
wire [(PL_LINK_CAP_MAX_LINK_WIDTH-1): 0] pipe_rxoutclk_in;
wire [(PL_LINK_CAP_MAX_LINK_WIDTH-1): 0] pipe_pclk_sel_in;
wire                                     pipe_gen3_in    ;

/* Reaction to Power State Change Interrupt */
reg  cfg_power_state_change_ack      ;
wire cfg_power_state_change_interrupt;

/* Function level Reset for PF & VF */
wire [1:0]    cfg_flr_done         ;
wire [5:0]    cfg_vf_flr_done      ;
wire [1:0]    cfg_flr_in_process   ;
wire [5:0]    cfg_vf_flr_in_process;
reg  [1:0]    cfg_flr_done_reg0    ;
reg  [5:0]    cfg_vf_flr_done_reg0 ;
reg  [1:0]    cfg_flr_done_reg1    ;
reg  [5:0]    cfg_vf_flr_done_reg1 ;


//---------- PIPE Clock Shared Mode ------------------------------//

pcie3_7x_1_pipe_clock #(
    .PCIE_ASYNC_EN                  ( "FALSE" ),                     // PCIe async enable
    .PCIE_TXBUF_EN                  ( "FALSE" ),                     // PCIe TX buffer enable for Gen1/Gen2 only
    .PCIE_CLK_SHARING_EN            ( CLK_SHARING_EN ),              // Enable Clock Sharing
    .PCIE_LANE                      ( PL_LINK_CAP_MAX_LINK_WIDTH ),  // PCIe number of lanes
    .PCIE_LINK_SPEED                ( 3 ),                           // No longer used to indicate link speed - Static value at 3
    .PL_LINK_CAP_MAX_LINK_SPEED     ( PL_LINK_CAP_MAX_LINK_SPEED ),  // PCIe link speed; 1=Gen1; 2=Gen2; 3=Gen3
    .PCIE_REFCLK_FREQ               ( PCIE_REFCLK_FREQ ),            // PCIe Reference Clock Frequency
    .PCIE_USERCLK1_FREQ             ( PCIE_USERCLK1_FREQ  ),         // PCIe Core Clock Frequency - Core Clock Freq
    .PCIE_USERCLK2_FREQ             ( PCIE_USERCLK2_FREQ ),          // PCIe User Clock Frequency - User Clock Freq
    .PCIE_DEBUG_MODE                ( 0 )                            // Debug Enable
) pipe_clock_i (

    /* ---------- Input ------------- */
    .CLK_CLK                        ( sys_clk             ),
    .CLK_TXOUTCLK                   ( pipe_txoutclk_in    ),     // Reference clock from lane 0
    .CLK_RXOUTCLK_IN                ( pipe_rxoutclk_in    ),
    .CLK_RST_N                      ( pipe_mmcm_rst_n     ),      // Allow system reset for error_recovery             
    .CLK_PCLK_SEL                   ( pipe_pclk_sel_in    ),
    .CLK_PCLK_SEL_SLAVE             ( pipe_pclk_sel_slave ),
    .CLK_GEN3                       ( pipe_gen3_in        ),

    /* ---------- Output ------------- */
    .CLK_PCLK                       ( pipe_pclk_out       ),
    .CLK_PCLK_SLAVE                 ( pipe_pclk_out_slave ),
    .CLK_RXUSRCLK                   ( pipe_rxusrclk_out   ),
    .CLK_RXOUTCLK_OUT               ( pipe_rxoutclk_out   ),
    .CLK_DCLK                       ( pipe_dclk_out       ),
    .CLK_OOBCLK                     ( pipe_oobclk_out     ),
    .CLK_USERCLK1                   ( pipe_userclk1_out   ),
    .CLK_USERCLK2                   ( pipe_userclk2_out   ),
    .CLK_MMCM_LOCK                  ( pipe_mmcm_lock_out  )

);

// Core Top Level Wrapper
pcie3_7x_1  pcie3_7x_1_i (
    .pci_exp_txn       ( pci_exp_txn        ),
    .pci_exp_txp       ( pci_exp_txp        ),
    .pci_exp_rxn       ( pci_exp_rxn        ),
    .pci_exp_rxp       ( pci_exp_rxp        ),
    .pipe_pclk_in      ( pipe_pclk_out      ),
    .pipe_rxusrclk_in  ( pipe_rxusrclk_out  ),
    .pipe_rxoutclk_in  ( pipe_rxoutclk_out  ),
    .pipe_dclk_in      ( pipe_dclk_out      ),
    .pipe_userclk1_in  ( pipe_userclk1_out  ),
    .pipe_userclk2_in  ( pipe_userclk2_out  ),
    .pipe_oobclk_in    ( pipe_oobclk_out    ),
    .pipe_mmcm_lock_in ( pipe_mmcm_lock_out ),
    .pipe_txoutclk_out ( pipe_txoutclk_in   ),
    .pipe_rxoutclk_out ( pipe_rxoutclk_in   ),
    .pipe_pclk_sel_out ( pipe_pclk_sel_in   ),
    .pipe_gen3_out     ( pipe_gen3_in       ),
    .pipe_mmcm_rst_n   ( pipe_mmcm_rst_n    ),
    .mmcm_lock         ( mmcm_lock          ),
    .user_clk          ( user_clk           ),
    .user_reset        ( user_reset         ),
    .user_lnk_up       ( user_lnk_up        ),
    .user_app_rdy      ( user_app_rdy       ),
    .s_axis_rq_tlast   ( s_axis_rq_tlast    ),
    .s_axis_rq_tdata   ( s_axis_rq_tdata    ),
    .s_axis_rq_tuser   ( s_axis_rq_tuser    ),
    .s_axis_rq_tkeep   ( s_axis_rq_tkeep    ),
    .s_axis_rq_tready  ( s_axis_rq_tready   ),
    .s_axis_rq_tvalid  ( s_axis_rq_tvalid   ),
    .m_axis_rc_tdata   ( m_axis_rc_tdata    ),
    .m_axis_rc_tuser   ( m_axis_rc_tuser    ),
    .m_axis_rc_tlast   ( m_axis_rc_tlast    ),
    .m_axis_rc_tkeep   ( m_axis_rc_tkeep    ),
    .m_axis_rc_tvalid  ( m_axis_rc_tvalid   ),
    .m_axis_rc_tready  ( m_axis_rc_tready   ),
    .m_axis_cq_tdata   ( m_axis_cq_tdata    ),
    .m_axis_cq_tuser   ( m_axis_cq_tuser    ),
    .m_axis_cq_tlast   ( m_axis_cq_tlast    ),
    .m_axis_cq_tkeep   ( m_axis_cq_tkeep    ),
    .m_axis_cq_tvalid  ( m_axis_cq_tvalid   ),
    .m_axis_cq_tready  ( m_axis_cq_tready   ),
    .s_axis_cc_tdata   ( s_axis_cc_tdata    ),
    .s_axis_cc_tuser   ( s_axis_cc_tuser    ),
    .s_axis_cc_tlast   ( s_axis_cc_tlast    ),
    .s_axis_cc_tkeep   ( s_axis_cc_tkeep    ),
    .s_axis_cc_tvalid  ( s_axis_cc_tvalid   ),
    .s_axis_cc_tready  ( s_axis_cc_tready   ),

    .pcie_tfc_nph_av                    ( pcie_tfc_nph_av                   ),
    .pcie_tfc_npd_av                    ( pcie_tfc_npd_av                   ),
    .pcie_rq_seq_num                    ( pcie_rq_seq_num                   ),
    .pcie_rq_seq_num_vld                ( pcie_rq_seq_num_vld               ),
    .pcie_rq_tag                        ( pcie_rq_tag                       ),
    .pcie_rq_tag_vld                    ( pcie_rq_tag_vld                   ),
    .pcie_cq_np_req                     ( pcie_cq_np_req                    ),
    .pcie_cq_np_req_count               ( pcie_cq_np_req_count              ),
    .cfg_phy_link_down                  ( cfg_phy_link_down                 ),
    .cfg_phy_link_status                ( cfg_phy_link_status               ),
    .cfg_negotiated_width               ( cfg_negotiated_width              ),
    .cfg_current_speed                  ( cfg_current_speed                 ),
    .cfg_max_payload                    ( cfg_max_payload                   ),
    .cfg_max_read_req                   ( cfg_max_read_req                  ),
    .cfg_function_status                ( cfg_function_status               ),
    .cfg_function_power_state           ( cfg_function_power_state          ),
    .cfg_vf_status                      ( cfg_vf_status                     ),
    .cfg_vf_power_state                 ( cfg_vf_power_state                ),
    .cfg_link_power_state               ( cfg_link_power_state              ),
    .cfg_err_cor_out                    ( cfg_err_cor_out                   ),
    .cfg_err_nonfatal_out               ( cfg_err_nonfatal_out              ),
    .cfg_err_fatal_out                  ( cfg_err_fatal_out                 ),
    .cfg_ltr_enable                     ( cfg_ltr_enable                    ),
    .cfg_ltssm_state                    ( cfg_ltssm_state                   ),
    .cfg_rcb_status                     ( cfg_rcb_status                    ),
    .cfg_dpa_substate_change            ( cfg_dpa_substate_change           ),
    .cfg_obff_enable                    ( cfg_obff_enable                   ),
    .cfg_pl_status_change               ( cfg_pl_status_change              ),
    .cfg_tph_requester_enable           ( cfg_tph_requester_enable          ),
    .cfg_tph_st_mode                    ( cfg_tph_st_mode                   ),
    .cfg_vf_tph_requester_enable        ( cfg_vf_tph_requester_enable       ),
    .cfg_vf_tph_st_mode                 ( cfg_vf_tph_st_mode                ),
    .cfg_mgmt_addr                      ( cfg_mgmt_addr                     ),
    .cfg_mgmt_write                     ( cfg_mgmt_write                    ),
    .cfg_mgmt_write_data                ( cfg_mgmt_write_data               ),
    .cfg_mgmt_byte_enable               ( cfg_mgmt_byte_enable              ),
    .cfg_mgmt_read                      ( cfg_mgmt_read                     ),
    .cfg_mgmt_read_data                 ( cfg_mgmt_read_data                ),
    .cfg_mgmt_read_write_done           ( cfg_mgmt_read_write_done          ),
    .cfg_mgmt_type1_cfg_reg_access      ( cfg_mgmt_type1_cfg_reg_access     ),
    .cfg_msg_received                   ( cfg_msg_received                  ),
    .cfg_msg_received_data              ( cfg_msg_received_data             ),
    .cfg_msg_received_type              ( cfg_msg_received_type             ),
    .cfg_msg_transmit                   ( cfg_msg_transmit                  ),
    .cfg_msg_transmit_type              ( cfg_msg_transmit_type             ),
    .cfg_msg_transmit_data              ( cfg_msg_transmit_data             ),
    .cfg_msg_transmit_done              ( cfg_msg_transmit_done             ),
    .cfg_fc_ph                          ( cfg_fc_ph                         ),
    .cfg_fc_pd                          ( cfg_fc_pd                         ),
    .cfg_fc_nph                         ( cfg_fc_nph                        ),
    .cfg_fc_npd                         ( cfg_fc_npd                        ),
    .cfg_fc_cplh                        ( cfg_fc_cplh                       ),
    .cfg_fc_cpld                        ( cfg_fc_cpld                       ),
    .cfg_fc_sel                         ( cfg_fc_sel                        ),
    .cfg_per_func_status_control        ( cfg_per_func_status_control       ),
    .cfg_per_func_status_data           ( cfg_per_func_status_data          ),
    .cfg_subsys_vend_id                 ( cfg_subsys_vend_id                ),
    .cfg_hot_reset_out                  ( cfg_hot_reset_out                 ),
    .cfg_config_space_enable            ( cfg_config_space_enable           ),
    .cfg_req_pm_transition_l23_ready    (cfg_req_pm_transition_l23_ready    ),
    .cfg_hot_reset_in                   (cfg_hot_reset_in                   ),
    .cfg_ds_port_number                 (cfg_ds_port_number                 ),
    .cfg_ds_bus_number                  (cfg_ds_bus_number                  ),
    .cfg_ds_device_number               (cfg_ds_device_number               ),
    .cfg_ds_function_number             (cfg_ds_function_number             ),
    .cfg_per_function_number            (cfg_per_function_number            ),
    .cfg_per_function_output_request    ( cfg_per_function_output_request   ),
    .cfg_per_function_update_done       ( cfg_per_function_update_done      ),
    .cfg_dsn                            ( cfg_dsn                           ),
    .cfg_power_state_change_ack         ( cfg_power_state_change_ack        ),
    .cfg_power_state_change_interrupt   ( cfg_power_state_change_interrupt  ),
    .cfg_err_cor_in                     ( cfg_err_cor_in                    ),
    .cfg_err_uncor_in                   ( cfg_err_uncor_in                  ),
    .cfg_flr_in_process                 ( cfg_flr_in_process                ),
    .cfg_flr_done                       ( cfg_flr_done                      ),
    .cfg_vf_flr_in_process              ( cfg_vf_flr_in_process             ),
    .cfg_vf_flr_done                    ( cfg_vf_flr_done                   ),
    .cfg_link_training_enable           ( cfg_link_training_enable          ),
    .cfg_interrupt_int                  ( cfg_interrupt_int                 ),
    .cfg_interrupt_pending              ( cfg_interrupt_pending             ),
    .cfg_interrupt_sent                 ( cfg_interrupt_sent                ),
    .cfg_interrupt_msi_enable           ( cfg_interrupt_msi_enable          ),
    .cfg_interrupt_msi_vf_enable        ( cfg_interrupt_msi_vf_enable       ),
    .cfg_interrupt_msi_mmenable         ( cfg_interrupt_msi_mmenable        ),
    .cfg_interrupt_msi_mask_update      ( cfg_interrupt_msi_mask_update     ),
    .cfg_interrupt_msi_data             ( cfg_interrupt_msi_data            ),
    .cfg_interrupt_msi_select           ( cfg_interrupt_msi_select          ),
    .cfg_interrupt_msi_int              ( cfg_interrupt_msi_int             ),
    .cfg_interrupt_msi_pending_status   ( cfg_interrupt_msi_pending_status  ),
    .cfg_interrupt_msi_sent             ( cfg_interrupt_msi_sent            ),
    .cfg_interrupt_msi_fail             ( cfg_interrupt_msi_fail            ),
    .cfg_interrupt_msi_attr             ( cfg_interrupt_msi_attr            ),
    .cfg_interrupt_msi_tph_present      ( cfg_interrupt_msi_tph_present     ),
    .cfg_interrupt_msi_tph_type         ( cfg_interrupt_msi_tph_type        ),
    .cfg_interrupt_msi_tph_st_tag       ( cfg_interrupt_msi_tph_st_tag      ),
    .cfg_interrupt_msix_enable          ( cfg_interrupt_msix_enable         ),
    .cfg_interrupt_msix_mask            ( cfg_interrupt_msix_mask           ),
    .cfg_interrupt_msix_vf_enable       ( cfg_interrupt_msix_vf_enable      ),
    .cfg_interrupt_msix_vf_mask         ( cfg_interrupt_msix_vf_mask        ),
    .cfg_interrupt_msix_data            ( cfg_interrupt_msix_data           ),
    .cfg_interrupt_msix_address         ( cfg_interrupt_msix_address        ),
    .cfg_interrupt_msix_int             ( cfg_interrupt_msix_int            ),
    .cfg_interrupt_msix_sent            ( cfg_interrupt_msix_sent           ),
    .cfg_interrupt_msix_fail            ( cfg_interrupt_msix_fail           ),
    .cfg_interrupt_msi_function_number  ( cfg_interrupt_msi_function_number ),
    .sys_clk   ( sys_clk   ),
    .sys_reset ( sys_reset )
);


/* Reaction to Power State Change Interrupt */
always @ (posedge user_clk or posedge user_reset) begin
    if (user_reset) begin
        cfg_power_state_change_ack <= `TD 1'b0;
    end
    else if (cfg_power_state_change_interrupt) begin
        cfg_power_state_change_ack <= `TD 1'b1;
    end
    else begin
        cfg_power_state_change_ack <= `TD 1'b0;
    end
end

/* Function level Reset for PF & VF */
always @(posedge user_clk or posedge user_reset) begin
    if (user_reset) begin
        cfg_flr_done_reg0       <= 2'b0;
        cfg_vf_flr_done_reg0    <= 6'b0;
        cfg_flr_done_reg1       <= 2'b0;
        cfg_vf_flr_done_reg1    <= 6'b0;
    end
    else begin
        cfg_flr_done_reg0       <= cfg_flr_in_process;
        cfg_vf_flr_done_reg0    <= cfg_vf_flr_in_process;
        cfg_flr_done_reg1       <= cfg_flr_done_reg0;
        cfg_vf_flr_done_reg1    <= cfg_vf_flr_done_reg0;
    end
end

assign cfg_flr_done[0] = ~cfg_flr_done_reg1[0] && cfg_flr_done_reg0[0]; 
assign cfg_flr_done[1] = ~cfg_flr_done_reg1[1] && cfg_flr_done_reg0[1];

assign cfg_vf_flr_done[0] = ~cfg_vf_flr_done_reg1[0] && cfg_vf_flr_done_reg0[0]; 
assign cfg_vf_flr_done[1] = ~cfg_vf_flr_done_reg1[1] && cfg_vf_flr_done_reg0[1]; 
assign cfg_vf_flr_done[2] = ~cfg_vf_flr_done_reg1[2] && cfg_vf_flr_done_reg0[2]; 
assign cfg_vf_flr_done[3] = ~cfg_vf_flr_done_reg1[3] && cfg_vf_flr_done_reg0[3]; 
assign cfg_vf_flr_done[4] = ~cfg_vf_flr_done_reg1[4] && cfg_vf_flr_done_reg0[4]; 
assign cfg_vf_flr_done[5] = ~cfg_vf_flr_done_reg1[5] && cfg_vf_flr_done_reg0[5];

endmodule
