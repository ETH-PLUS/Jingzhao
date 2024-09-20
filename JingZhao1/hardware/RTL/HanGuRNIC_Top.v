`timescale 1ns / 100ps
//*************************************************************************
// > File Name   : HanGuRNIC_Top.v
// > Description : HanGuRNIC_Top, Top modulle of Han Gu RNIC
// > Author      : YangFan
// > Date        : 2022-05-20
//*************************************************************************

(* DowngradeIPIdentifiedWarnings = "yes" *)
module HanGuRNIC_Top # (
    parameter          PL_SIM_FAST_LINK_TRAINING           = "FALSE",      // Simulation Speedup
    parameter          PCIE_EXT_CLK                        = "TRUE", // Use External Clocking Module
    parameter          PCIE_EXT_GT_COMMON                  = "FALSE", // Use External GT COMMON Module
    parameter          C_DATA_WIDTH                        = 256,         // RX/TX interface data width
    parameter          KEEP_WIDTH                          = C_DATA_WIDTH / 32,
    // parameter          EXT_PIPE_SIM                        = "FALSE",  // This Parameter has effect on selecting Enable External PIPE Interface in GUI.
    parameter          PL_LINK_CAP_MAX_LINK_SPEED          = 2,  // 1- GEN1, 2 - GEN2, 4 - GEN3
    parameter          PL_LINK_CAP_MAX_LINK_WIDTH          = 8,  // 1- X1, 2 - X2, 4 - X4, 8 - X8
    // USER_CLK2_FREQ = AXI Interface Frequency
    //   0: Disable User Clock
    //   1: 31.25 MHz
    //   2: 62.50 MHz  (default)
    //   3: 125.00 MHz
    //   4: 250.00 MHz
    //   5: 500.00 MHz
    parameter  integer USER_CLK2_FREQ                 = 3,
    parameter          REF_CLK_FREQ                   = 0,           // 0 - 100 MHz, 1 - 125 MHz,  2 - 250 MHz
    parameter          AXISTEN_IF_RQ_ALIGNMENT_MODE   = "FALSE",
    parameter          AXISTEN_IF_CC_ALIGNMENT_MODE   = "FALSE",
    parameter          AXISTEN_IF_CQ_ALIGNMENT_MODE   = "FALSE",
    parameter          AXISTEN_IF_RC_ALIGNMENT_MODE   = "FALSE",
    parameter          AXISTEN_IF_ENABLE_CLIENT_TAG   = 1        ,
    parameter          AXISTEN_IF_RQ_PARITY_CHECK     = 0        ,
    parameter          AXISTEN_IF_CC_PARITY_CHECK     = 0        ,
    parameter          AXISTEN_IF_MC_RX_STRADDLE      = 0        ,
    parameter          AXISTEN_IF_ENABLE_RX_MSG_INTFC = 0        ,
    parameter   [17:0] AXISTEN_IF_ENABLE_MSG_ROUTE    = 18'h2FFFF,

    // defined for pcie interface
    parameter          DMA_HEAD_WIDTH                 = 128      ,
    parameter          AXIL_DATA_WIDTH                = 32       ,
    parameter          AXIL_ADDR_WIDTH                = 24       ,
    parameter          ETHER_BASE                     = 24'h0    ,
    parameter          ETHER_LEN                      = 24'h1000 ,
    parameter          DB_BASE                        = 12'h0    ,
    parameter          HCR_BASE                       = 20'h80000,

    parameter          AXIL_STRB_WIDTH                = (AXIL_DATA_WIDTH/8),
    parameter           PORT_NUM                      = 1
) (
/*MAC and PHY related pins{Begin}*/
    //Signals of MAC
    input   wire                                                    button_rst,    //Button reset
    input   wire                                                    sfp_refclk_p,
    input   wire                                                    sfp_refclk_n,


    input   wire  [PORT_NUM - 1 : 0]                                 mac_rxn,
    input   wire  [PORT_NUM - 1 : 0]                                 mac_rxp,
    output  wire  [PORT_NUM - 1 : 0]                                 mac_txp,
    output  wire  [PORT_NUM - 1 : 0]                                 mac_txn,
    output  wire  [PORT_NUM - 1 : 0]                                 mac_phy_ready,
    input   wire   [PORT_NUM - 1 : 0]                                mac_mod_detect,
    input   wire   [PORT_NUM - 1 : 0]                                mac_los,
    input   wire  [PORT_NUM - 1 : 0]                                 mac_tx_fault,
    output wire [PORT_NUM - 1 : 0]                                   mac_tx_disable,

    output  [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]  pci_exp_txp,
    output  [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]  pci_exp_txn,
    input   [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]  pci_exp_rxp,
    input   [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]  pci_exp_rxn,

    input                                           sys_clk_p,
    input                                           sys_clk_n,
    input                                           sys_rst_n
);


// Local Parameters derived from user selection
localparam integer USER_CLK_FREQ   = ((PL_LINK_CAP_MAX_LINK_SPEED == 3'h4) ? 5 : 4);
// localparam         EXT_PIPE_SIM    = "FALSE";

// Wire Declarations
wire                                       user_lnk_up ;
wire                                       user_app_rdy;
wire                                       user_clk    ;
wire                                       user_reset  ;

/* ------- AXI Interface{begin}------- */
wire                                       s_axis_rq_tlast;
wire                 [C_DATA_WIDTH-1:0]    s_axis_rq_tdata;
wire                             [59:0]    s_axis_rq_tuser;
wire                   [KEEP_WIDTH-1:0]    s_axis_rq_tkeep;
wire                              [3:0]    s_axis_rq_tready;
wire                                       s_axis_rq_tvalid;

wire                 [C_DATA_WIDTH-1:0]    m_axis_rc_tdata;
wire                             [74:0]    m_axis_rc_tuser;
wire                                       m_axis_rc_tlast;
wire                   [KEEP_WIDTH-1:0]    m_axis_rc_tkeep;
wire                                       m_axis_rc_tvalid;
wire                                       m_axis_rc_tready;

wire                 [C_DATA_WIDTH-1:0]    m_axis_cq_tdata;
wire                             [84:0]    m_axis_cq_tuser;
wire                                       m_axis_cq_tlast;
wire                   [KEEP_WIDTH-1:0]    m_axis_cq_tkeep;
wire                                       m_axis_cq_tvalid;
wire                                       m_axis_cq_tready;

wire                 [C_DATA_WIDTH-1:0]    s_axis_cc_tdata;
wire                             [32:0]    s_axis_cc_tuser;
wire                                       s_axis_cc_tlast;
wire                   [KEEP_WIDTH-1:0]    s_axis_cc_tkeep;
wire                                       s_axis_cc_tvalid;
wire                              [3:0]    s_axis_cc_tready;
/* ------- AXI Interface{end}------- */

/* ------- Configuration (CFG) Interface{begin}------- */
wire                              [2:0]    cfg_max_payload;
wire                              [2:0]    cfg_max_read_req;

// Interrupt Interface Signals
wire                              [1:0]    cfg_interrupt_msix_enable;
wire                              [1:0]    cfg_interrupt_msix_mask;
wire                             [31:0]    cfg_interrupt_msix_data;
wire                             [63:0]    cfg_interrupt_msix_address;
wire                                       cfg_interrupt_msix_int;
wire                                       cfg_interrupt_msix_sent;
wire                                       cfg_interrupt_msix_fail;
wire                              [2:0]    cfg_interrupt_msi_function_number;
/* ------- Configuration (CFG) Interface{end}------- */

  /* -------Connect NIC_Top and MAC2Engine{begin}------- */
wire                                        rx_axis_nic_tvalid;
wire                                        rx_axis_nic_tlast;
wire [C_DATA_WIDTH - 1: 0]                  rx_axis_nic_tdata;
wire [C_DATA_WIDTH / 8 - 1: 0]              rx_axis_nic_tkeep;
wire                                        rx_axis_nic_tready;

wire                                        tx_axis_nic_tvalid;
wire                                        tx_axis_nic_tlast;
wire [C_DATA_WIDTH - 1: 0]                  tx_axis_nic_tdata;
wire [C_DATA_WIDTH / 8 - 1: 0]              tx_axis_nic_tkeep;
wire                                        tx_axis_nic_tready;

/* -------Connect NIC_Top and MAC2Engine{End}------- */

/* -------Connect MAC2Engine and MACCore{End}------- */
wire    [64 * PORT_NUM - 1 : 0]   tx_axis_mac_tdata;
wire    [8 * PORT_NUM - 1 : 0]    tx_axis_mac_tkeep;
wire    [PORT_NUM - 1 : 0]        tx_axis_mac_tvalid;
wire    [PORT_NUM - 1 : 0]        tx_axis_mac_tlast;
wire    [PORT_NUM - 1 : 0]        tx_axis_mac_tready;    

wire    [64 * PORT_NUM - 1:0]     rx_axis_mac_tdata;
wire    [8 * PORT_NUM - 1:0]      rx_axis_mac_tkeep;
wire    [PORT_NUM - 1 : 0]        rx_axis_mac_tvalid;
wire    [PORT_NUM - 1 : 0]        rx_axis_mac_tlast;
wire    [PORT_NUM - 1 : 0]        rx_axis_mac_tready;
/* -------Connect Mac2Engine and MACCore{End}------- */

// ref_clk IBUFDS from the edge connector
IBUFDS_GTE2 refclk_ibuf (.O(sys_clk), .ODIV2(), .I(sys_clk_p), .CEB(1'b0), .IB(sys_clk_n));

wire            nic_clk;
wire            dclk;

reset_gen reset_gen (

    .sys_clk                     ( user_clk      ), // i, 1

    .user_reset                  ( user_reset   ), // i, 1
    .user_lnk_up                 ( user_lnk_up  ), // i, 1
    .user_app_rdy                ( user_app_rdy ), // i, 1
    .sys_rst_n                   ( sys_rst_n    ), // i, 1
    .cmd_rst                     ( 1'b0      ), // i, 1

    .glbl_rst ( glbl_rst ), // o, 1
    .app_rst  ( app_rst  )  // o, 1
);

clk_wiz_1 nic_clk_wiz (
    .clk_out1 ( nic_clk ), 
    .clk_out2 (dclk),
    .reset    ( 1'd0 ), 
    .locked   (), 
    .clk_in1  (user_clk  )
);

/* --------- PCIe Core Controller{begin}------- */
PCIe_Ctrl #(
    .PL_LINK_CAP_MAX_LINK_WIDTH     ( PL_LINK_CAP_MAX_LINK_WIDTH ), // PCIe Lane Width
    .PL_LINK_CAP_MAX_LINK_SPEED     ( PL_LINK_CAP_MAX_LINK_SPEED ), // PCIe Link Speed; 1- GEN1, 2 - GEN2, 4 - GEN3
    .C_DATA_WIDTH                   ( C_DATA_WIDTH ),               // AXI interface data width
    .KEEP_WIDTH                     ( KEEP_WIDTH ),                 // TSTRB width
    .PCIE_REFCLK_FREQ               ( REF_CLK_FREQ ),               // PCIe Reference Clock Frequency
    .PCIE_USERCLK1_FREQ             ( USER_CLK_FREQ ),              // PCIe Core Clock Frequency - Core Clock Freq
    .PCIE_USERCLK2_FREQ             ( USER_CLK2_FREQ )              // PCIe User Clock Frequency - User Clock Freq 
) PCIe_Ctrl (

    /* ------- PCI Express (pci_exp) Interface{begin}------- */
    // Tx
    .pci_exp_txn                                   ( pci_exp_txn ),
    .pci_exp_txp                                   ( pci_exp_txp ),

    // Rx
    .pci_exp_rxn                                   ( pci_exp_rxn ),
    .pci_exp_rxp                                   ( pci_exp_rxp ),
    /* ------- PCI Express (pci_exp) Interface{end}------- */

    /* ------- Clock & GT COMMON Sharing Interface{begin}------- */
    .pipe_pclk_out_slave                        ( ),
    .pipe_rxusrclk_out                          ( ),
    .pipe_rxoutclk_out                          ( ),
    .pipe_dclk_out                              ( ),
    .pipe_userclk1_out                          ( ),
    .pipe_oobclk_out                            ( ),
    .pipe_userclk2_out                          ( ),
    .pipe_mmcm_lock_out                         ( ),
    .pipe_pclk_sel_slave                        ({PL_LINK_CAP_MAX_LINK_WIDTH{1'b0}}),
    .pipe_mmcm_rst_n                            ( 1'b1),
    /* ------- Clock & GT COMMON Sharing Interface{end}------- */

    /* ------- AXI Interface{begin}------- */
    .user_clk                    ( user_clk     ), // o, 1
    .user_reset                  ( user_reset   ), // o, 1
    .user_lnk_up                 ( user_lnk_up  ), // o, 1
    .user_app_rdy                ( user_app_rdy ), // o, 1

    .s_axis_rq_tvalid            ( s_axis_rq_tvalid ), // i, 1
    .s_axis_rq_tlast             ( s_axis_rq_tlast  ), // i, 1
    .s_axis_rq_tkeep             ( s_axis_rq_tkeep  ), // i, 8
    .s_axis_rq_tuser             ( s_axis_rq_tuser  ), // i, 60
    .s_axis_rq_tdata             ( s_axis_rq_tdata  ), // i, 256
    .s_axis_rq_tready            ( s_axis_rq_tready ), // o, 1
    .pcie_rq_seq_num             (                  ), // o, 4 (not used)
    .pcie_rq_seq_num_vld         (                  ), // o, 1 (not used)
    .pcie_rq_tag                 (                  ), // o, 6 (not used)
    .pcie_rq_tag_vld             (                  ), // o, 1 (not used)

    .m_axis_rc_tvalid            ( m_axis_rc_tvalid ), // o, 1
    .m_axis_rc_tlast             ( m_axis_rc_tlast  ), // o, 1
    .m_axis_rc_tkeep             ( m_axis_rc_tkeep  ), // o, 8
    .m_axis_rc_tuser             ( m_axis_rc_tuser  ), // o, 75
    .m_axis_rc_tdata             ( m_axis_rc_tdata  ), // o, 256
    .m_axis_rc_tready            ( m_axis_rc_tready ), // i, 1

    .m_axis_cq_tvalid            ( m_axis_cq_tvalid ), // o, 1
    .m_axis_cq_tlast             ( m_axis_cq_tlast  ), // o, 1
    .m_axis_cq_tkeep             ( m_axis_cq_tkeep  ), // o, 8
    .m_axis_cq_tuser             ( m_axis_cq_tuser  ), // o, 85
    .m_axis_cq_tdata             ( m_axis_cq_tdata  ), // o, 256
    .m_axis_cq_tready            ( m_axis_cq_tready ), // i, 1
    .pcie_cq_np_req              ( 1'd1             ), // i, 1 (keep it high for not use backpressure on non-posted req)
    .pcie_cq_np_req_count        (                  ), // o, 6

    .s_axis_cc_tvalid            ( s_axis_cc_tvalid ), // i, 1
    .s_axis_cc_tlast             ( s_axis_cc_tlast  ), // i, 1
    .s_axis_cc_tkeep             ( s_axis_cc_tkeep  ), // i, 8
    .s_axis_cc_tuser             ( s_axis_cc_tuser  ), // i, 33
    .s_axis_cc_tdata             ( s_axis_cc_tdata  ), // i, 256
    .s_axis_cc_tready            ( s_axis_cc_tready ), // o, 1
    /* ------- AXI Interface{end}------- */

    /* -------Configuration (CFG) Interface{begin}------- */
    // Transmit Flow Control Interface (We don't care about it)
    .pcie_tfc_nph_av                                (  ), // o, 2
    .pcie_tfc_npd_av                                (  ), // o, 2

    // Configuration Management Interface (We don't use it)
    .cfg_mgmt_addr                                  ( 19'd0 ), // i, 19
    .cfg_mgmt_write                                 ( 1'd0  ), // i, 1
    .cfg_mgmt_write_data                            ( 32'd0 ), // i, 32
    .cfg_mgmt_byte_enable                           ( 4'd0  ), // i, 4
    .cfg_mgmt_read                                  ( 1'd0  ), // i, 1
    .cfg_mgmt_read_data                             (       ), // o, 32
    .cfg_mgmt_read_write_done                       (       ), // o, 1
    .cfg_mgmt_type1_cfg_reg_access                  ( 1'd0  ), // i, 1

    // Configuration Status Interface, (partially used)
    .cfg_phy_link_down           (                  ), // o, 1
    .cfg_phy_link_status         (                  ), // o, 2
    .cfg_negotiated_width        (                  ), // o, 4
    .cfg_current_speed           (                  ), // o, 3
    .cfg_max_payload             ( cfg_max_payload  ), // o, 3
    .cfg_max_read_req            ( cfg_max_read_req ), // o, 3
    .cfg_function_status         (                  ), // o, 8
    .cfg_function_power_state    (                  ), // o, 6
    .cfg_vf_status               (                  ), // o, 12
    .cfg_vf_power_state          (                  ), // o, 18
    .cfg_link_power_state        (                  ), // o, 2
    .cfg_err_cor_out             (                  ), // o, 1
    .cfg_err_nonfatal_out        (                  ), // o, 1
    .cfg_err_fatal_out           (                  ), // o, 1
    .cfg_ltr_enable              (                  ), // o, 1
    .cfg_ltssm_state             (                  ), // o, 6
    .cfg_rcb_status              (                  ), // o, 2
    .cfg_dpa_substate_change     (                  ), // o, 2
    .cfg_obff_enable             (                  ), // o, 2
    .cfg_pl_status_change        (                  ), // o, 1
    .cfg_tph_requester_enable    (                  ), // o, 2
    .cfg_tph_st_mode             (                  ), // o, 6
    .cfg_vf_tph_requester_enable (                  ), // o, 6
    .cfg_vf_tph_st_mode          (                  ), // o, 18

    // Configuration Received Message Interface (We don't care about it)
    .cfg_msg_received      (  ), // o, 1
    .cfg_msg_received_data (  ), // o, 8
    .cfg_msg_received_type (  ), // o, 5

    // Configuration Transmit Message Interface (We don't use it)
    .cfg_msg_transmit      ( 1'd0  ), // i, 1
    .cfg_msg_transmit_type ( 3'd0  ), // i, 3
    .cfg_msg_transmit_data ( 32'd0 ), // i, 32
    .cfg_msg_transmit_done (       ), // o, 1

    // Configuration Flow Control Interface (We don't care about it)
    .cfg_fc_ph   (      ), // o, 8
    .cfg_fc_pd   (      ), // o, 12
    .cfg_fc_nph  (      ), // o, 8
    .cfg_fc_npd  (      ), // o, 12
    .cfg_fc_cplh (      ), // o, 8
    .cfg_fc_cpld (      ), // o, 12
    .cfg_fc_sel  ( 3'd0 ), // i, 3

    // Per Function Status Interface (We don't support VF)
    .cfg_per_func_status_control ( 3'd0 ), // i, 3
    .cfg_per_func_status_data    (      ), // o, 16

    // Configuration Control Interface
    .cfg_hot_reset_in                 ( 1'd0     ), // i, 1
    .cfg_hot_reset_out                (          ), // o, 1
    .cfg_config_space_enable          ( 1'd1     ), // i, 1, (enable the configuration space)
    .cfg_per_function_update_done     (          ), // o, 1 (not used)
    .cfg_per_function_number          ( 3'd0     ), // i, 3 (not used)
    .cfg_per_function_output_request  ( 1'd0     ), // i, 1 (not used)
    .cfg_dsn                          ( `CAP_DSN ), // i, 64
    .cfg_ds_port_number               ( 8'd0     ), // i, 8
    .cfg_ds_bus_number                ( 8'd0     ), // i, 8
    .cfg_ds_device_number             ( 5'd0     ), // i, 5
    .cfg_ds_function_number           ( 3'd0     ), // i, 3
    .cfg_err_cor_in                   ( 1'd0     ), // i, 1 (not used)
    .cfg_err_uncor_in                 ( 1'd0     ), // i, 1 (not used)
    .cfg_req_pm_transition_l23_ready  ( 1'd0     ), // i, 1 (not used)
    .cfg_link_training_enable         ( 1'd1     ), // i, 1, (1 for enable the LTSSM)

    // Configuration Interrupt Controller Interface
    .cfg_interrupt_int                 ( 4'd0   ), // i, 4 (We don't use legacy Int)
    .cfg_interrupt_pending             ( 2'd0   ), // i, 2 (We don't use legacy Int)
    .cfg_interrupt_sent                (        ), // o, 1 (We don't use legacy Int)
    .cfg_interrupt_msi_enable          (        ), // o, 2  (We don't use MSI Int)
    .cfg_interrupt_msi_vf_enable       (        ), // o, 6  (We don't use MSI Int)
    .cfg_interrupt_msi_mmenable        (        ), // o, 6  (We don't use MSI Int)
    .cfg_interrupt_msi_mask_update     (        ), // o, 1  (We don't use MSI Int)
    .cfg_interrupt_msi_data            (        ), // o, 32 (We don't use MSI Int)
    .cfg_interrupt_msi_select          ( 4'd0   ), // i, 4  (We don't use MSI Int)
    .cfg_interrupt_msi_int             ( 32'd0  ), // i, 32 (We don't use MSI Int)
    .cfg_interrupt_msi_pending_status  ( 64'd0  ), // i, 64 (We don't use MSI Int)
    .cfg_interrupt_msi_sent            (        ), // o, 1  (We don't use MSI Int)
    .cfg_interrupt_msi_fail            (        ), // o, 1  (We don't use MSI Int)
    .cfg_interrupt_msi_attr            ( 3'd0   ), // i, 3  (We don't use MSI Int)
    .cfg_interrupt_msi_tph_present     ( 1'd0   ), // i, 1  (We don't use MSI Int)
    .cfg_interrupt_msi_tph_type        ( 2'd0   ), // i, 2  (We don't use MSI Int)
    .cfg_interrupt_msi_tph_st_tag      ( 9'd0   ), // i, 9  (We don't use MSI Int)
    .cfg_interrupt_msix_enable         ( cfg_interrupt_msix_enable         ), // o, 2
    .cfg_interrupt_msix_mask           ( cfg_interrupt_msix_mask           ), // o, 2
    .cfg_interrupt_msix_vf_enable      (        ), // o, 6  (VF are not supported)
    .cfg_interrupt_msix_vf_mask        (        ), // o, 6  (VF are not supported)
    .cfg_interrupt_msix_data           ( cfg_interrupt_msix_data           ), // i, 32
    .cfg_interrupt_msix_address        ( cfg_interrupt_msix_address        ), // i, 64
    .cfg_interrupt_msix_int            ( cfg_interrupt_msix_int            ), // i, 1
    .cfg_interrupt_msix_sent           ( cfg_interrupt_msix_sent           ), // o, 1
    .cfg_interrupt_msix_fail           ( cfg_interrupt_msix_fail           ), // o, 1
    .cfg_interrupt_msi_function_number ( cfg_interrupt_msi_function_number ), // i, 3

    // Vender ID
    .cfg_subsys_vend_id  ( `VENDER_ID ), // i, 16
    /* -------Configuration (CFG) Interface{end}------- */

   .sys_clk                                        ( sys_clk  ), // i, 1
   .sys_reset                                      ( glbl_rst )  // i, 1

);
/* --------- PCIe Core Contronller{end}------- */

NIC_Top NIC_Top_Inst
(
	.rst(app_rst),
	.pcie_clk(user_clk),
	.nic_clk(nic_clk),
	
    /*Interface with PCIe Subsystem*/
    .s_axis_rq_tvalid(s_axis_rq_tvalid),
    .s_axis_rq_tlast (s_axis_rq_tlast ),
    .s_axis_rq_tkeep (s_axis_rq_tkeep ),
    .s_axis_rq_tuser (s_axis_rq_tuser ),
    .s_axis_rq_tdata (s_axis_rq_tdata ),
    .s_axis_rq_tready(s_axis_rq_tready),
    
    .m_axis_rc_tvalid(m_axis_rc_tvalid),
    .m_axis_rc_tlast (m_axis_rc_tlast ),
    .m_axis_rc_tkeep (m_axis_rc_tkeep ),
    .m_axis_rc_tuser (m_axis_rc_tuser ),
    .m_axis_rc_tdata (m_axis_rc_tdata ),
    .m_axis_rc_tready(m_axis_rc_tready),

    .m_axis_cq_tvalid(m_axis_cq_tvalid),
    .m_axis_cq_tlast (m_axis_cq_tlast ),
    .m_axis_cq_tkeep (m_axis_cq_tkeep ),
    .m_axis_cq_tuser (m_axis_cq_tuser ),
    .m_axis_cq_tdata (m_axis_cq_tdata ),
    .m_axis_cq_tready(m_axis_cq_tready),

    .s_axis_cc_tvalid(s_axis_cc_tvalid),
    .s_axis_cc_tlast (s_axis_cc_tlast ),
    .s_axis_cc_tkeep (s_axis_cc_tkeep ),
    .s_axis_cc_tuser (s_axis_cc_tuser ),
    .s_axis_cc_tdata (s_axis_cc_tdata ),
    .s_axis_cc_tready(s_axis_cc_tready),
    /* ------- AXI Interface{end}------- */

    // Configuration (CFG) Interface
    .cfg_max_payload (cfg_max_payload ),
//    .cfg_max_read_req(cfg_max_read_req),
    .cfg_max_read_req(3'b001),
    // Interrupt Interface Signals
//    .cfg_interrupt_msix_enable('d0),
//    .cfg_interrupt_msix_mask('d0),
//    .cfg_interrupt_msix_data(),
//    .cfg_interrupt_msix_address(),
//    .cfg_interrupt_msix_int(),
//    .cfg_interrupt_msix_sent('d0),
//    .cfg_interrupt_msix_fail('d0),
//    .cfg_interrupt_msi_function_number(),

    /*Interface with Link Layer*/
        /*Interface with TX HPC Link, AXIS Interface*/
    .nic_link_hpc_tx_pkt_valid(),
    .nic_link_hpc_tx_pkt_end(),
    .nic_link_hpc_tx_pkt_data(),
    .nic_link_hpc_tx_pkt_keep(),
    .nic_link_hpc_tx_pkt_ready('d0),
    .nic_link_hpc_tx_pkt_start(),         
    .nic_link_hpc_tx_pkt_user(),         

    /*Interface with RX HPC Link, AXIS Interface*/
        /*interface to LinkLayer Rx  */
    .nic_link_hpc_rx_pkt_valid('d0), 
    .nic_link_hpc_rx_pkt_end('d0),
    .nic_link_hpc_rx_pkt_data('d0),
    .nic_link_hpc_rx_pkt_keep('d0),
    .nic_link_hpc_rx_pkt_ready(), 
    .nic_link_hpc_rx_pkt_start('d0),
    .nic_link_hpc_rx_pkt_user('d0), 

        /*Interface with TX/RX ETH Link, AXIS Interface*/
    .nic_link_eth_tx_pkt_valid(tx_axis_nic_tvalid),
    .nic_link_eth_tx_pkt_end(tx_axis_nic_tlast),
    .nic_link_eth_tx_pkt_data(tx_axis_nic_tdata),
    .nic_link_eth_tx_pkt_keep(tx_axis_nic_tkeep),
    .nic_link_eth_tx_pkt_ready(tx_axis_nic_tready),
    .nic_link_eth_tx_pkt_start(tx_axis_nic_tstart),
    .nic_link_eth_tx_pkt_user(tx_axis_nic_tuser),

    .nic_link_eth_rx_pkt_valid(rx_axis_nic_tvalid),
    .nic_link_eth_rx_pkt_end(rx_axis_nic_tlast),
    .nic_link_eth_rx_pkt_data(rx_axis_nic_tdata),
    .nic_link_eth_rx_pkt_keep(rx_axis_nic_tkeep),
    .nic_link_eth_rx_pkt_ready(rx_axis_nic_tready),
    .nic_link_eth_rx_pkt_start(rx_axis_nic_tstart),
    .nic_link_eth_rx_pkt_user(rx_axis_nic_tuser)

//    /*Interface with Cfg Subsystem*/
//    .ov_init_rw_data(),
//    .iv_rw_data('d0),
//    .ov_ro_data(),

//    .iv_dbg_sel('d0),
//    .ov_dbg_bus()

);

wire coreclk_out;

MacToEngine #(
  .PORT_NUM(PORT_NUM)
)
MacToEngine_inst(
    .sysclk(nic_clk),
    .ethclk(coreclk_out),
    .rst_n( ~app_rst),

    .rx_axis_data(rx_axis_nic_tdata),
    .rx_axis_valid(rx_axis_nic_tvalid),
    .rx_axis_keep(rx_axis_nic_tkeep),
    .rx_axis_last(rx_axis_nic_tlast),
    .rx_axis_ready(rx_axis_nic_tready),

    .rx_axis_mac_data(rx_axis_mac_tdata),
    .rx_axis_mac_valid(rx_axis_mac_tvalid),
    .rx_axis_mac_keep(rx_axis_mac_tkeep),
    .rx_axis_mac_last(rx_axis_mac_tlast),
    .rx_axis_mac_ready(rx_axis_mac_tready),

    .tx_axis_data(tx_axis_nic_tdata),
    .tx_axis_valid(tx_axis_nic_tvalid),
    .tx_axis_keep(tx_axis_nic_tkeep),
    .tx_axis_last(tx_axis_nic_tlast),
    .tx_axis_ready(tx_axis_nic_tready),

    .tx_axis_mac_data(tx_axis_mac_tdata),
    .tx_axis_mac_valid(tx_axis_mac_tvalid),
    .tx_axis_mac_keep(tx_axis_mac_tkeep),
    .tx_axis_mac_last(tx_axis_mac_tlast),
    .tx_axis_mac_ready(tx_axis_mac_tready)
);

CoreTop_0 CoreTop_0_Inst(
   .reset(app_rst),
   .refclk_p(sfp_refclk_p),
   .refclk_n(sfp_refclk_n),
   .dclk(dclk),
   .txp(mac_txp[0]),
   .txn(mac_txn[0]),
   .rxp(mac_rxp[0]),
   .rxn(mac_rxn[0]),
   
  .tx_axis_tdata(tx_axis_mac_tdata[64 * (0 + 1) - 1 : 64 * 0]),
  .tx_axis_tkeep(tx_axis_mac_tkeep[8 * (0 + 1) - 1 : 8 * 0]),
  .tx_axis_tvalid(tx_axis_mac_tvalid[ (0 + 1) - 1 : 0]),
  .tx_axis_tlast(tx_axis_mac_tlast[ (0 + 1) - 1 : 0]),
  .tx_axis_tready(tx_axis_mac_tready[ (0 + 1) - 1 : 0]),
  
  .rx_axis_tdata(rx_axis_mac_tdata[64 * (0 + 1) - 1 : 64 * 0]),
  .rx_axis_tkeep(rx_axis_mac_tkeep[8 * (0 + 1) - 1 : 8 * 0]),
  .rx_axis_tvalid(rx_axis_mac_tvalid[ (0 + 1) - 1 :  0]),
  .rx_axis_tlast(rx_axis_mac_tlast[ (0 + 1) - 1 : 0]),
  .rx_axis_tready(rx_axis_mac_tready[(0 + 1)-1: 0]),
   
   .phy_ready(mac_phy_ready[0]),
   .signal_detect(1'b1),
   .tx_fault(mac_tx_fault[0]),
   .tx_disable(mac_tx_disable[0]),
   
   //Output to other cores
  .dclk_out(),
  .coreclk_out(coreclk_out),
  .qplloutclk_out(),
  .qplloutrefclk_out(),
  .qplllock_out(),
  .txusrclk_out(),
  .txusrclk2_out(),
  .gttxreset_out(),
  .gtrxreset_out(),
  .txuserrdy_out(),
  .areset_datapathclk_out(),
  .reset_counter_done_out()    
);

//ila_tx_desc_fetch ila_eth_tx_inst(
//  .clk(nic_clk),
//  .probe0(tx_axis_nic_tvalid),
//  .probe1(tx_axis_nic_tlast),
//  .probe2(tx_axis_nic_tdata),
//  .probe3(128'd0),
//  .probe4(tx_axis_nic_tready)
//);

endmodule