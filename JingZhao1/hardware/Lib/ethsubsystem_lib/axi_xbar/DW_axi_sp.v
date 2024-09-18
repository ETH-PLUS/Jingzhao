/* ---------------------------------------------------------------------
**
// ------------------------------------------------------------------------------
// 
// Copyright 2001 - 2020 Synopsys, INC.
// 
// This Synopsys IP and all associated documentation are proprietary to
// Synopsys, Inc. and may only be used pursuant to the terms and conditions of a
// written license agreement with Synopsys, Inc. All other use, reproduction,
// modification, or distribution of the Synopsys IP or the associated
// documentation is strictly prohibited.
// 
// Component Name   : DW_axi
// Component Version: 4.04a
// Release Type     : GA
// ------------------------------------------------------------------------------

// 
// Release version :  4.04a
// File Version     :        $Revision: #12 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_sp.v#12 $ 
**
** ---------------------------------------------------------------------
**
** File     : DW_axi_sp.v
//
//
** Created  : Mon May  9 19:49:59 MEST 2005
** Modified : $Date: 2020/03/22 $
** Abstract : Slave Port block for the DW_axi interconnect.
**            External AXI slaves connect to the DW_axi through slave 
**            ports.
**
** ---------------------------------------------------------------------
*/
module DW_axi_sp (
  aclk_i,
  aresetn_i,

  ar_bus_mst_priorities_i,
  aw_bus_mst_priorities_i,
  w_bus_mst_priorities_i,

  // READ ADDRESS CHANNEL.
  
  // Inputs - External Slave.
  arready_i,

  // Outputs - External Slave.
  arvalid_o,
  arpayload_o,

  // Inputs - Master Ports.
  bus_arvalid_i,
  bus_arpayload_i,

  // Outputs - Master Ports.
  bus_arready_o,


  // READ DATA CHANNEL.
  
  // Inputs - External Slave.
  rvalid_i,
  rpayload_i,

  // Outputs - External Slave.
  rready_o,
  
  // Inputs - Master Ports.
  bus_rready_i,

  // Outputs - Master Ports.
  bus_rvalid_o,
  r_shrd_ch_req_o,
  rpayload_o,
  
  // Outputs - Shared Slave Port AR.
  rcpl_tx_shrd_o,

  // WRITE ADDRESS CHANNEL.
  
  // Inputs - External Slave.
  awready_i,

  // Outputs - External Slave.
  awvalid_o,
  awpayload_o,

  // Inputs - Master Ports.
  bus_awvalid_i,
  bus_awpayload_i,

  // Outputs - Master Ports.
  bus_awready_o,
  aw_shrd_lyr_granted_o,

  // Top level - Out
  issued_wtx_mst_oh_o,

  // Top level - In
  issued_wtx_mst_oh_i,


  // WRITE DATA CHANNEL.
  
  // Inputs - External Slave.
  wready_i,

  // Outputs - External Slave.
  wvalid_o,
  wpayload_o,

  // Inputs - Master Ports.
  bus_wvalid_i,
  bus_wpayload_i,

  // Outputs - Master Ports.
  bus_wready_o,

  // Inputs - Shared AW channel.
  issued_tx_shrd_i,
  issued_tx_shrd_mst_oh_i,

  // Outputs - Shared W channel.
  shrd_w_nxt_fb_pend_o,

  // BURST RESPONSE CHANNEL.
  
  // Inputs - External Slave.
  bvalid_i,
  bpayload_i,

  // Outputs - External Slave.
  bready_o,

  // Inputs - Master Ports.
  bus_bready_i,

  // Outputs - Master Ports.
  bus_bvalid_o,
  b_shrd_ch_req_o,
  bpayload_o,

  // Outputs - Shared Slave Port AW.
  wcpl_tx_shrd_o
);

//----------------------------------------------------------------------
// MODULE PARAMETERS.
//----------------------------------------------------------------------
  parameter NUM_VIS_MP = 16; // Number of master ports visible to
                             // this slave port.

  parameter LOG2_NUM_VIS_MP = 4; // Log 2 of NUM_VIS_MP.

  // Number of visibile masters for AR/AW/W channels & derived params.
  parameter AR_NVM = 16;
  parameter AR_NVM_LOG2 = 4;
  parameter AR_NVM_P1_LOG2 = 4;

  parameter AW_NVM = 16;
  parameter AW_NVM_LOG2 = 4;
  parameter AW_NVM_P1_LOG2 = 4;

  parameter W_NVM = 16;
  parameter W_NVM_LOG2 = 4;
  parameter W_NVM_P1_LOG2 = 4;

  parameter ARB_TYPE_AR = 0; // Arbiter type for AR channel.
  parameter ARB_TYPE_AW = 0; // Arbiter type for AW channel.
  parameter ARB_TYPE_W = 0; // Arbiter type for W channel.

  parameter AR_MCA_EN = 0; // 1 if multi-cycle arbitration is enabled
  parameter AW_MCA_EN = 0; // for each of these 3 channels.
  parameter W_MCA_EN = 0; 

  parameter AR_MCA_NC = 0; // Number of arbitration cycles if
  parameter AW_MCA_NC = 0; // multi cycle arbitration is enabled
  parameter W_MCA_NC = 0;  // for each of these 3 channels.

  parameter AR_MCA_NC_W = 0; // Log base 2 of *_MCA_NC + 1 params.
  parameter AW_MCA_NC_W = 0; 
  parameter W_MCA_NC_W = 0;  

  // Master visibility parameters.
  parameter M0_VIS  = 1;
  parameter M1_VIS  = 1; 
  parameter M2_VIS  = 1; 
  parameter M3_VIS  = 1; 
  parameter M4_VIS  = 1; 
  parameter M5_VIS  = 1; 
  parameter M6_VIS  = 1; 
  parameter M7_VIS  = 1; 
  parameter M8_VIS  = 1; 
  parameter M9_VIS  = 1; 
  parameter M10_VIS = 1; 
  parameter M11_VIS = 1; 
  parameter M12_VIS = 1; 
  parameter M13_VIS = 1; 
  parameter M14_VIS = 1; 
  parameter M15_VIS = 1; 

  parameter WID = 2; // Write interleaving depth of the slave port.

  parameter LOG2_WID = 1; // Log base 2 of WID.

  parameter LOG2_WID_P1 = 2; // Log base 2 of (WID + 1).

  parameter MAX_FARC = 2; // Number of active read commands that
                          // the slave port will forward to the 
                          // external slave.

  parameter LOG2_MAX_FARC_P1 = 2; // Log base 2 of MAX_FARC + 1.

  parameter MAX_FAWC = 2; // Number of active write commands that
                          // the slave port will forward to the 
                          // external slave.

  parameter LOG2_MAX_FAWC = 2; // Log base 2 of MAX_FAWC.

  parameter LOG2_MAX_FAWC_P1 = 2; // Log base 2 of MAX_FAWC + 1.

  parameter LOCKING = 0; // Set to 1 if the slave port will
                         // implement AXI locking functionality.
                      
  // AW channel masters, connected here through shared layer ?
  parameter AW_SHARED_M0 = 0;
  parameter AW_SHARED_M1 = 0;
  parameter AW_SHARED_M2 = 0;
  parameter AW_SHARED_M3 = 0;
  parameter AW_SHARED_M4 = 0;
  parameter AW_SHARED_M5 = 0;
  parameter AW_SHARED_M6 = 0;
  parameter AW_SHARED_M7 = 0;
  parameter AW_SHARED_M8 = 0;
  parameter AW_SHARED_M9 = 0;
  parameter AW_SHARED_M10 = 0;
  parameter AW_SHARED_M11 = 0;
  parameter AW_SHARED_M12 = 0;
  parameter AW_SHARED_M13 = 0;
  parameter AW_SHARED_M14 = 0;
  parameter AW_SHARED_M15 = 0;
  
  // AR channel masters, connected here through shared layer ?
  parameter AR_SHARED_M0 = 0;
  parameter AR_SHARED_M1 = 0;
  parameter AR_SHARED_M2 = 0;
  parameter AR_SHARED_M3 = 0;
  parameter AR_SHARED_M4 = 0;
  parameter AR_SHARED_M5 = 0;
  parameter AR_SHARED_M6 = 0;
  parameter AR_SHARED_M7 = 0;
  parameter AR_SHARED_M8 = 0;
  parameter AR_SHARED_M9 = 0;
  parameter AR_SHARED_M10 = 0;
  parameter AR_SHARED_M11 = 0;
  parameter AR_SHARED_M12 = 0;
  parameter AR_SHARED_M13 = 0;
  parameter AR_SHARED_M14 = 0;
  parameter AR_SHARED_M15 = 0;

  // W channel masters, connected here through shared layer ?
  parameter W_SHARED_M0 = 0;
  parameter W_SHARED_M1 = 0;
  parameter W_SHARED_M2 = 0;
  parameter W_SHARED_M3 = 0;
  parameter W_SHARED_M4 = 0;
  parameter W_SHARED_M5 = 0;
  parameter W_SHARED_M6 = 0;
  parameter W_SHARED_M7 = 0;
  parameter W_SHARED_M8 = 0;
  parameter W_SHARED_M9 = 0;
  parameter W_SHARED_M10 = 0;
  parameter W_SHARED_M11 = 0;
  parameter W_SHARED_M12 = 0;
  parameter W_SHARED_M13 = 0;
  parameter W_SHARED_M14 = 0;
  parameter W_SHARED_M15 = 0;


  // R channel masters, accessed through shared layer ?
  parameter R_SHARED_M0 = 0;
  parameter R_SHARED_M1 = 0;
  parameter R_SHARED_M2 = 0;
  parameter R_SHARED_M3 = 0;
  parameter R_SHARED_M4 = 0;
  parameter R_SHARED_M5 = 0;
  parameter R_SHARED_M6 = 0;
  parameter R_SHARED_M7 = 0;
  parameter R_SHARED_M8 = 0;
  parameter R_SHARED_M9 = 0;
  parameter R_SHARED_M10 = 0;
  parameter R_SHARED_M11 = 0;
  parameter R_SHARED_M12 = 0;
  parameter R_SHARED_M13 = 0;
  parameter R_SHARED_M14 = 0;
  parameter R_SHARED_M15 = 0;

  // B channel slaves, accessed through shared layer ?
  parameter B_SHARED_M0 = 0;
  parameter B_SHARED_M1 = 0;
  parameter B_SHARED_M2 = 0;
  parameter B_SHARED_M3 = 0;
  parameter B_SHARED_M4 = 0;
  parameter B_SHARED_M5 = 0;
  parameter B_SHARED_M6 = 0;
  parameter B_SHARED_M7 = 0;
  parameter B_SHARED_M8 = 0;
  parameter B_SHARED_M9 = 0;
  parameter B_SHARED_M10 = 0;
  parameter B_SHARED_M11 = 0;
  parameter B_SHARED_M12 = 0;
  parameter B_SHARED_M13 = 0;
  parameter B_SHARED_M14 = 0;
  parameter B_SHARED_M15 = 0;

  // Does the shared to dedicated link exist for the AW & W channels.
  parameter AW_HAS_SHRD_DDCTD_LNK = 0;
  parameter W_HAS_SHRD_DDCTD_LNK = 0;

  // Parameters to remove sink blocks here if the function is performed
  // by the shared layer.
  parameter REMOVE_AR = 0;
  parameter REMOVE_AW = 0;
  parameter REMOVE_W  = 0;

  // Width of concatenated read address channel payload vector for all
  // visible master ports.
  localparam BUS_AR_PYLD_S_W = AR_NVM*`AXI_AR_PYLD_S_W; 

  // Width of concatenated write address channel payload vector for all
  // visible master ports.
  localparam BUS_AW_PYLD_S_W = AW_NVM*`AXI_AW_PYLD_S_W; 

  // Width of concatenated write data channel payload vector for all
  // visible master ports.
  localparam BUS_W_PYLD_S_W = W_NVM*`AXI_W_PYLD_S_W;   

  // Width of concatenated master priorities for all visible master 
  // ports.
  localparam AR_BUS_PRIORITY_W = `AXI_MST_PRIORITY_W*AR_NVM;
  localparam AW_BUS_PRIORITY_W = `AXI_MST_PRIORITY_W*AW_NVM;
  localparam W_BUS_PRIORITY_W  = `AXI_MST_PRIORITY_W*W_NVM;
  
  localparam RPAYLOAD_W = `AXI_R_PYLD_M_W 
                          + (`AXI_LOG2_NM*`AXI_IS_ICM_M1);

  localparam BPAYLOAD_W = `AXI_B_PYLD_M_W 
                          + (`AXI_LOG2_NM*`AXI_IS_ICM_M1);

  // Parameters to tell us which of the shared sink channels are visible 
  // to this master port.
  localparam R_SHARED_LAYER_VIS 
    = (  R_SHARED_M15
       | R_SHARED_M14
       | R_SHARED_M13
       | R_SHARED_M12
       | R_SHARED_M11
       | R_SHARED_M10
       | R_SHARED_M9
       | R_SHARED_M8
       | R_SHARED_M7
       | R_SHARED_M6
       | R_SHARED_M5
       | R_SHARED_M4
       | R_SHARED_M3
       | R_SHARED_M2
       | R_SHARED_M1
       | R_SHARED_M0
      );

  localparam B_SHARED_LAYER_VIS 
    = (  B_SHARED_M15
       | B_SHARED_M14
       | B_SHARED_M13
       | B_SHARED_M12
       | B_SHARED_M11
       | B_SHARED_M10
       | B_SHARED_M9
       | B_SHARED_M8
       | B_SHARED_M7
       | B_SHARED_M6
       | B_SHARED_M5
       | B_SHARED_M4
       | B_SHARED_M3
       | B_SHARED_M2
       | B_SHARED_M1
       | B_SHARED_M0
      );

  // Width of arbiter internal grant index.                                
  // Only used in locking configs where both channel arbiters must be
  // of the same type.
  localparam ARB_INDEX_W = (ARB_TYPE_AR==1) 
                           ? AR_NVM_P1_LOG2 : AR_NVM_LOG2;


//----------------------------------------------------------------------
// PORT DECLARATIONS.
//----------------------------------------------------------------------
  input aclk_i;    // AXI system clock.
  input aresetn_i; // AXI system reset.

  // Busses containing priorities of all connected masters, for AR, AW
  // and W channels.

  // Not used if the shared layer is performing all channel
  // sink functions for this slave on the AR, W and AW channel.
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input [AR_BUS_PRIORITY_W-1:0] ar_bus_mst_priorities_i; 
  input [AW_BUS_PRIORITY_W-1:0] aw_bus_mst_priorities_i; 
  input [W_BUS_PRIORITY_W-1:0]  w_bus_mst_priorities_i; 
  //spyglass enable_block W240

  //--------------------------------------------------------------------
  // READ ADDRESS CHANNEL.
  //--------------------------------------------------------------------
  
  // Inputs - External Slave.
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input                         arready_i; // Ready from external slave.
  //spyglass enable_block W240

  // Outputs - External Slave.
  output                        arvalid_o;   // Valid to external 
                                             // slave.
  output [`AXI_AR_PYLD_S_W-1:0] arpayload_o; // Payload to external 
                                             // slave.

  // Inputs - Master Ports.
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input [AR_NVM-1:0] bus_arvalid_i; // Valid signals from all visible 
                                    // master ports.
                                    
  input [BUS_AR_PYLD_S_W-1:0]   bus_arpayload_i; // Payload vectors from 
                                                 // all visible master 
                                                  // ports.
  //spyglass enable_block W240


  // Outputs - Master Ports.
  output [AR_NVM-1:0] bus_arready_o; // Ready to master ports.


  //--------------------------------------------------------------------
  // READ DATA CHANNEL.
  //--------------------------------------------------------------------
  
  // Inputs - External Slave.
  input                        rvalid_i;   // Valid from external slave.
  input [`AXI_R_PYLD_S_W-1:0]  rpayload_i; // Payload from external 
                                           // slave.

  // Outputs - External Slave.
  output                       rready_o; // Ready to external slave.
  
  // Inputs - Master Ports.
  input [NUM_VIS_MP-1:0]       bus_rready_i; // All ready signals from 
                                             // visible master ports.

  // Outputs - Master Ports.
  output [NUM_VIS_MP-1:0]      bus_rvalid_o; // Valid signals to master
                                             // ports.
  output                       r_shrd_ch_req_o; // Request for R 
                                                // shared layer.
  output [RPAYLOAD_W-1:0]      rpayload_o;   // Payload vector to master

  // Outputs - Shared Slave Port AR.
  output                       rcpl_tx_shrd_o; // Signal t/x completion 
                                               // to the shared AR 
                                               // channel.

  //--------------------------------------------------------------------
  // WRITE ADDRESS CHANNEL.
  //--------------------------------------------------------------------
  
  // Inputs - External Slave.
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input                         awready_i; // Ready from external slave.
  //spyglass enable_block W240

  // Outputs - External Slave.
  output                        awvalid_o;   // Valid to external slave.
  output [`AXI_AW_PYLD_S_W-1:0] awpayload_o; // Payload to external 
                                             // slave.
 
  // Inputs - Master Ports.
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input [AW_NVM-1:0] bus_awvalid_i; // Valid signals from all visible 
                                    // master ports.
  input [BUS_AW_PYLD_S_W-1:0] bus_awpayload_i; // Payload vectors from 
                                               // all visible slave
                                                // ports.
  //spyglass enable_block W240

  // Outputs - Master Ports.
  output [AW_NVM-1:0] bus_awready_o; // Ready to master ports.

  output aw_shrd_lyr_granted_o; // Asserted when shared layer granted
                                // at dedicated aw channel.


  // Send out AW one hot granted signals to be decoded into a num
  // visible masters value by ifdefs at the top level. Required
  // when the dedicated AW channel has a link with the shared AW
  // channel.
  output [AW_NVM-1:0]     issued_wtx_mst_oh_o;
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input  [NUM_VIS_MP-1:0] issued_wtx_mst_oh_i;


  //--------------------------------------------------------------------
  // WRITE DATA CHANNEL.
  //--------------------------------------------------------------------
  
  // Inputs - External Slave.
  input                         wready_i; // Ready from external slave.
  //spyglass enable_block W240

  // Outputs - External Slave.
  output                        wvalid_o;   // Valid to external slave.
  output [`AXI_W_PYLD_S_W-1:0]  wpayload_o; // Payload vector to 
                                            // external slave.

  // Inputs - Master Ports.
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input [W_NVM-1:0] bus_wvalid_i; // Valid signals from all visible 
                                 // master ports.
  input [BUS_W_PYLD_S_W-1:0] bus_wpayload_i; // Payload vectors from 
  //spyglass enable_block W240
                                             // all visible master
                                             // ports.

  // Outputs - Master Ports.
  output [W_NVM-1:0] bus_wready_o; // Ready to master ports.
  
  // Inputs - Shared AW channel.
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input                  issued_tx_shrd_i;
  input [NUM_VIS_MP-1:0] issued_tx_shrd_mst_oh_i;
  //spyglass enable_block W240
  
  
  // Outputs - Shared W channel.
  // Tells the shared W channel when it is next to send a first W beat
  // to this slave. Used to avoid a deadlock condition with the shared
  // to dedicated layer link.
  output shrd_w_nxt_fb_pend_o;

  //--------------------------------------------------------------------
  // BURST RESPONSE CHANNEL.
  //--------------------------------------------------------------------
  // Inputs - External Slave.
  input                        bvalid_i;   // Valid from external slave.
  input [`AXI_B_PYLD_S_W-1:0]  bpayload_i; // Payload from external 
                                           // slave.

  // Outputs - External Slave.
  output                       bready_o; // Ready to external slave.
  
  // Inputs - Master Ports.
  input [NUM_VIS_MP-1:0]       bus_bready_i; // All ready signals from 
                                             // visible master ports.

  // Outputs - Master Ports.
  output [NUM_VIS_MP-1:0]      bus_bvalid_o; // Valid signals to master
                                             // ports.
  output                       b_shrd_ch_req_o; // Request for B 
                                                // shared layer.
  output [BPAYLOAD_W-1:0]      bpayload_o;   // Payload vector to master
                                             // ports.

  // Outputs - Shared Slave Port AW.
  output                       wcpl_tx_shrd_o; // Signal t/x completion 
                                               // to the shared AW 
                                               // channel.
                                          
  //--------------------------------------------------------------------
  // WIRE VARIABLES.
  //--------------------------------------------------------------------
  // These signals are used only for write channel instantiations and unused for read channel instantiation
  wire outstnd_wtxs_fed; // Signal from write address channel block, 
                         // when its transaction count register has 
                         // gone to 0.
       
  wire outstnd_nonlkd_wtxs; // Signal from write address channel block,
                            // asserted when there are outstanding 
                              // non locked write transactions to the 
                            // slave.
       
  wire outstnd_rtxs_fed; // Signal from read address channel block, 
                         // when its transaction count register has 
                         // gone to 0.

  wire outstnd_nonlkd_rtxs; // Signal from read address channel block,
                            // asserted when there are outstanding 
                            // non locked read transactions to the 
                            // slave.

  wire unlocking_wtx_rcvd; // Signal from write address channel block
                           // asserted when it has received an 
                           // unlocking transaction.
  wire unlocking_rtx_rcvd; // Signal from read address channel block
                           // asserted when it has received an 
                           // unlocking transaction.
         
  wire arlock; // Asserted by read address channel when its arbiter
               // is locked to a particular master.
  wire awlock; // Asserted by write address channel when its arbiter
               // is locked to a particular master.
               
  wire rcpl_tx; // Read transaction completed signal, from read data
                // channel to read address channel.
  wire wcpl_tx; // Write transaction completed signal, from burst
                // response channel to read address channel.

  // 1-hot grant and local grant indexes from the arbiter in the read 
  // address channel block.
  wire [AR_NVM-1:0]      bus_grant_arb_ar;     
  wire [AR_NVM_LOG2-1:0] grant_m_local_arb_ar;


  // 1-hot grant and local grant indexes from the arbiter in the write 
  // address channel block.
  wire [AW_NVM-1:0]      bus_grant_arb_aw;   
  wire [AW_NVM_LOG2-1:0] grant_m_local_arb_aw;
  
  wire issued_wtx; // Asserted by write address channel when write
                   // command has been issued. Goes to write data 
                   // channel.
                                       
  // Signifies the master number whos transaction has been issued 
  // with issued_wtx.
  wire [LOG2_NUM_VIS_MP-1:0] issued_wmstnum;

  //--------------------------------------------------------------------
  // Signals to connect between internal register slices and each 
  // each master port channel block.
  // Source channels only.
  //--------------------------------------------------------------------
  wire [NUM_VIS_MP-1:0]       bus_rvalid_sp;
  wire                        rvalid_sp;
  wire                        rready_sp;
  wire [RPAYLOAD_W-1:0]       rpayload_sp;

  wire [NUM_VIS_MP-1:0]       bus_rvalid_irs;
  wire                        rready_irs;
  wire [RPAYLOAD_W-1:0]       rpayload_irs;

  wire [NUM_VIS_MP-1:0]       bus_bvalid_sp;
  wire                        bvalid_sp;
  wire                        bready_sp;
  wire [BPAYLOAD_W-1:0]       bpayload_sp;

  wire [NUM_VIS_MP-1:0]       bus_bvalid_irs;
  wire                        bready_irs;
  wire [BPAYLOAD_W-1:0]       bpayload_irs;

  // Wires for unconnected module outputs.
  wire r_id_irs_unconn;
  wire r_local_slv_irs_unconn;
  wire r_id_irs_arbpl_unconn;
  wire r_local_slv_irs_arbpl_unconn;

  wire b_id_irs_unconn;
  wire b_local_slv_irs_unconn;
  wire b_id_irs_arbpl_unconn;
  wire b_local_slv_irs_arbpl_unconn;

  wire r_shrd_ch_req_sp;
  wire b_shrd_ch_req_sp;
  wire r_shrd_ch_req_irs;
  wire b_shrd_ch_req_irs;

  wire issued_tx_ar_unconn;
  wire [AR_NVM_LOG2-1:0] issued_mstnum_ar_unconn;

  wire [RPAYLOAD_W-1:0] rpayload_prereg_unconn;
  wire [BPAYLOAD_W-1:0] bpayload_prereg_unconn;

  wire ar_bus_valid_shrd_o_unconn;
  wire ar_issued_tx_o_unconn;
  wire [LOG2_NUM_VIS_MP-1:0] ar_issued_mstnum_o_unconn;
  wire ar_issued_tx_shrd_slv_oh_o_unconn;
  wire [AR_NVM-1:0] ar_issued_tx_mst_oh_o;

  wire aw_bus_valid_shrd_o_unconn;
  wire aw_issued_tx_shrd_slv_oh_o_unconn;

  wire w_bus_valid_shrd_o_unconn;

  wire [NUM_VIS_MP-1:0] r_bus_valid_r_o_unconn;
  wire r_issued_wtx_shrd_mst_oh_o;

  wire [NUM_VIS_MP-1:0] b_bus_valid_r_o_unconn;
  wire b_issued_wtx_shrd_mst_oh_o;

  wire ar_shrd_lyr_granted_unconn;

  // Remove this block if the shared layer is performing all channel
  // sink functions for this slave on the AR channel.
  generate
    if(REMOVE_AR == 0) begin : gen_ar_addrch
      //----------------------------------------------------------------
      // Read Address Channel Block.
      //----------------------------------------------------------------
      DW_axi_sp_addrch
      
      #(AR_NVM,             // Number of connected master ports.
        AR_NVM_LOG2,        // 
        AR_NVM_P1_LOG2,     //
        NUM_VIS_MP,         // Number of visible master ports.
        LOG2_NUM_VIS_MP,    // 
        `AXI_AR_PL_ARB,     // Pipeline AR channel arbiter ?
        AR_MCA_EN,          // Has multi-cycle arbitration ?
        AR_MCA_NC,          // Num. cycles in multi-cycle arbitration.
        AR_MCA_NC_W,        // Log base 2 of AR_MCA_NC.
        ARB_TYPE_AR,        // Arbitration type.
        BUS_AR_PYLD_S_W,    // Width of bus containing payloads 
                            // from all visible master ports.
        `AXI_AR_PYLD_S_W,   // Width of payload vector to slave.
        MAX_FARC,           // Max. number of active read commands.
        LOG2_MAX_FARC_P1,   // Log base 2 of MAX_FARC + 1.
        AR_BUS_PRIORITY_W,  // Width of bus containing priorities of 
                            // all visible masters.
        LOCKING,            // Implement locking or not.      
        `AXI_NOT_AW_CH      // Not a write address channel.
       )
      U_AR_DW_axi_sp_addrch (
        // Inputs - System.
        .aclk_i                  (aclk_i),
        .aresetn_i               (aresetn_i),
        .bus_mst_priorities_i    (ar_bus_mst_priorities_i),
        
        // Inputs - External Slave.
        .ready_i                 (arready_i),
        
        // Outputs - External Slave.
        .valid_o                 (arvalid_o),
        .payload_o               (arpayload_o),
        
        // Inputs - Master Ports.
        .bus_arvalid_i           (bus_arvalid_i),
        .bus_awvalid_i           ({AR_NVM{1'b0}}),
    
        .bus_payload_i           (bus_arpayload_i),
        
        // Outputs - Master Ports.
        .bus_ready_o             (bus_arready_o),
        .shrd_lyr_granted_o      (ar_shrd_lyr_granted_unconn),
        
        // Inputs - Write Address Channel.
        .outstnd_txs_fed_i       (1'b0),
        .outstnd_txs_nonlkd_i    (1'b0),
        .unlocking_tx_rcvd_i     (1'b0),
        .bus_grant_arb_i         ({AR_NVM{1'b0}}),
        .grant_m_local_arb_i     ({AR_NVM_LOG2{1'b0}}),
        .lock_i                  (1'b0),
        
        // Outputs - Write Address Channel.
        .outstnd_txs_fed_o       (outstnd_rtxs_fed),
        .outstnd_txs_nonlkd_o    (outstnd_nonlkd_rtxs),
        .unlocking_tx_rcvd_o     (unlocking_rtx_rcvd),
        .lock_o                  (arlock),
        .bus_grant_arb_o         (bus_grant_arb_ar),
        .grant_m_local_arb_o     (grant_m_local_arb_ar),
        
        // Inputs - Read Data Channel.
        .cpl_tx_i                (rcpl_tx),
       
        // Inputs - Unconnected.
        .bus_arvalid_shrd_i      ({AR_NVM{1'b0}}), 
        .bus_awvalid_shrd_i      ({AR_NVM{1'b0}}), 
        .bus_ready_shrd_i        (1'b0), 
        .cpl_tx_shrd_bus_i       (1'b0), 

        // Outputs - Unconnected.
        .bus_valid_shrd_o        (ar_bus_valid_shrd_o_unconn), 
        .issued_tx_o             (ar_issued_tx_o_unconn), 
        .issued_mstnum_o         (ar_issued_mstnum_o_unconn),
        .issued_tx_shrd_slv_oh_o (ar_issued_tx_shrd_slv_oh_o_unconn), 
        .issued_tx_mst_oh_o      (ar_issued_tx_mst_oh_o)  
      );
    end
   else begin: assign_default_1 //VP:: Done to remove lint error
     assign arvalid_o = 1'b0;
     assign arpayload_o= {`AXI_AR_PYLD_S_W{1'b0}};
     assign bus_arready_o = {AR_NVM{1'b0}};
     end
  endgenerate


  //--------------------------------------------------------------------
  // Read Data Channel Block.
  //--------------------------------------------------------------------
  DW_axi_sp_drespch
  
  #(NUM_VIS_MP,         // Number of visible master ports.
    LOG2_NUM_VIS_MP,    // Log 2 of number of visible master ports.
    `AXI_R_PYLD_M_W,    // Payload width to master.
    `AXI_R_PYLD_S_W,    // Payload width from slave.
    
    // Master visibility parameters.
     M0_VIS,  M1_VIS,  M2_VIS,  M3_VIS,   M4_VIS,  M5_VIS,
     M6_VIS,  M7_VIS,  M8_VIS,  M9_VIS,  M10_VIS, M11_VIS,
    M12_VIS, M13_VIS, M14_VIS, M15_VIS,

    `AXI_R_CH,          // R or B channel ?

    R_SHARED_LAYER_VIS, // Is there an R shared layer.
    
    // Source on shared or dedicated layer parameters.
     R_SHARED_M0,  R_SHARED_M1,  R_SHARED_M2,  R_SHARED_M3, 
     R_SHARED_M4,  R_SHARED_M5,  R_SHARED_M6,  R_SHARED_M7, 
     R_SHARED_M8,  R_SHARED_M9, R_SHARED_M10, R_SHARED_M11, 
    R_SHARED_M12, R_SHARED_M13, R_SHARED_M14, R_SHARED_M15,
    
    // Address channel source on shared or dedicated layer 
    // parameters.
     AR_SHARED_M0,  AR_SHARED_M1,  AR_SHARED_M2,  AR_SHARED_M3, 
     AR_SHARED_M4,  AR_SHARED_M5,  AR_SHARED_M6,  AR_SHARED_M7, 
     AR_SHARED_M8,  AR_SHARED_M9, AR_SHARED_M10, AR_SHARED_M11, 
    AR_SHARED_M12, AR_SHARED_M13, AR_SHARED_M14, AR_SHARED_M15 
   )
  U_R_DW_axi_sp_drespch (
    // Inputs - System.
    //.aclk_i         (aclk_i),
    //.aresetn_i      (aresetn_i),
    
    // Inputs - External Slave.
    .valid_i        (rvalid_i),
    .payload_i      (rpayload_i),
    
    // Outputs - External Slave.
    .ready_o        (rready_o),
    
    // Inputs - Master Ports, via internal reg slice.
    .ready_i        (rready_sp),
    
    // Outputs - Master Ports, via internal reg slice.
    .bus_valid_o    (bus_rvalid_sp),
    .valid_o        (rvalid_sp),
    .shrd_ch_req_o  (r_shrd_ch_req_sp),
    .payload_o      (rpayload_sp),
    
    // Outputs - Read Address Channel.
    .cpl_tx_o       (rcpl_tx),
    .shrd_cpl_tx_o  (rcpl_tx_shrd_o)
  );

  //--------------------------------------------------------------------
  // Internal register slice for R channel.
  //--------------------------------------------------------------------
  DW_axi_irs
  
  #(`AXI_R_TMO,        // Channel timing option.
    NUM_VIS_MP,        // Number of visible master ports.
    `AXI_R_PL_ARB,     // Is channel arbiter pipelined.
    RPAYLOAD_W,        // Channel payload width.
    1,                 // Log base 2 of num. visible ports. Not required
                       // in this instance, pass 1 to compile clean.
    1,                 // Master ID width, not required, pass 1 to 
                       // compile clean.
    0,                 // Masking logic not required here.
    0,                 // ID right hand bit, not required here.
    0,                 // ID left hand bit, not required here.
    0,                 // Pass a 1 for W channel, not required.
    R_SHARED_LAYER_VIS // Shared layer signal(s) required ?
  )
  U_R_DW_axi_irs (
    // Inputs - System.
    .aclk_i        (aclk_i),
    .aresetn_i     (aresetn_i),

    // Inputs - Payload source.
    .payload_i    (rpayload_sp),
    .bus_valid_i  (bus_rvalid_sp),
    .valid_i      (rvalid_sp),
    .mask_valid_i (1'b0), // Masking not required here.
    .shrd_ch_req_i (r_shrd_ch_req_sp),
  
    // Outputs - Payload source.
    .ready_o       (rready_sp),

    // Inputs - Payload destination.
    .ready_i      (rready_irs),
    
    // Outputs - Unconnected.
    .id_o         (r_id_irs_unconn),
    .local_slv_o  (r_local_slv_irs_unconn),

    // Outputs - Payload destination.
    .bus_valid_o   (bus_rvalid_irs),
    .shrd_ch_req_o (r_shrd_ch_req_irs),
    .payload_o     (rpayload_irs)
  );

  //--------------------------------------------------------------------
  // Internal register slice for R channel.
  //--------------------------------------------------------------------
  DW_axi_irs_arbpl
  
  #(`AXI_R_PL_ARB,     // Is channel arbiter pipelined.
    NUM_VIS_MP,        // Number of visible master ports.
    RPAYLOAD_W,        // Channel payload width.
    1,                 // Log base 2 of num. visible ports. Not required
                       // in this instance, pass 1 to compile clean.
    1,                 // Master ID width, not required, pass 1 to 
                       // compile clean.
    0,                 // Masking logic not required here.
    0,                 // ID right hand bit, not required here.
    0,                 // ID left hand bit, not required here.
    0,                 // Pass a 1 for W channel, not required.
    R_SHARED_LAYER_VIS // Shared layer signal(s) required ?
  )
  U_R_DW_axi_irs_arbpl (
    // Inputs - System.
    .aclk_i                   (aclk_i),
    .aresetn_i                (aresetn_i),

    // Inputs - Payload source.
    .payload_i                (rpayload_irs),
    .bus_valid_i              (bus_rvalid_irs),
    .mask_valid_i             (1'b0), // Masking not required here.
    .shrd_ch_req_i            (r_shrd_ch_req_irs),
    .issued_wtx_shrd_mst_oh_i (1'b0),
  
    // Outputs - Payload source.
    .ready_o                  (rready_irs),

    // Inputs - Payload destination.
    .bus_ready_i              (bus_rready_i),
    
    // Outputs - Unconnected.
    .id_o                     (r_id_irs_arbpl_unconn),
    .local_slv_o              (r_local_slv_irs_arbpl_unconn),

    // Outputs - Payload destination.
    .bus_valid_o              (bus_rvalid_o),
    .payload_o                (rpayload_o),
    .shrd_ch_req_o            (r_shrd_ch_req_o),
    
    // Unconnected outputs.
    .bus_valid_r_o            (r_bus_valid_r_o_unconn), 
    .payload_prereg_o         (rpayload_prereg_unconn),
    .issued_wtx_shrd_mst_oh_o (r_issued_wtx_shrd_mst_oh_o)
  );


  // Remove this block if the shared layer is performing all channel
  // sink functions for this slave on the AW channel.
  generate
    if(REMOVE_AW == 0) begin : gen_aw_addrch
      //----------------------------------------------------------------
      // Write Address Channel Block.
      //----------------------------------------------------------------
      DW_axi_sp_addrch
      
      #(AW_NVM,                // Number of connected master ports.
        AW_NVM_LOG2,           // 
        AW_NVM_P1_LOG2,        // 
        NUM_VIS_MP,            // Number of visible master ports.
        LOG2_NUM_VIS_MP,       // 
        `AXI_AW_PL_ARB,        // Pipeline AW channel arbiter.
        AW_MCA_EN,             // Has multi-cycle arbitration ?
        AW_MCA_NC,             // Num. cycles in multi-cycle 
                               // arbitration.
        AW_MCA_NC_W,           // Log base 2 of AW_MCA_NC.
        ARB_TYPE_AW,           // Arbitration type.
        BUS_AW_PYLD_S_W,       // Width of bus containing payloads 
                               // from all visible master ports.
        `AXI_AW_PYLD_S_W,      // Width of payload vector to slave.
        MAX_FAWC,              // Max. number of active write commands.
        LOG2_MAX_FAWC_P1,      // Log base 2 of MAX_FAWC + 1.
        AW_BUS_PRIORITY_W,     // Width of bus containing priorities of 
                               // all visible masters.
        LOCKING,               // Implement locking or not.      
        `AXI_AW_CH,            // Write address channel.

        AW_HAS_SHRD_DDCTD_LNK  // Does AW have shared->dedicated 
                               // channel link.
       )
      U_AW_DW_axi_sp_addrch (
        // Inputs - System.
        .aclk_i                          (aclk_i),
        .aresetn_i                       (aresetn_i),
        .bus_mst_priorities_i            (aw_bus_mst_priorities_i),
        
        // Inputs - External Slave.
        .ready_i                         (awready_i),
        
        // Outputs - External Slave.
        .valid_o                         (awvalid_o),
        .payload_o                       (awpayload_o),
        
        // Inputs - Master Ports.
        .bus_awvalid_i                   (bus_awvalid_i),
        .bus_arvalid_i                  ({AW_NVM{1'b0}}),
    
        .bus_payload_i                   (bus_awpayload_i),

        
        // Outputs - Master Ports.
        .bus_ready_o                     (bus_awready_o),
        .shrd_lyr_granted_o              (aw_shrd_lyr_granted_o),
        
        // Inputs - Write Address Channel.
        .outstnd_txs_fed_i               (1'b0),
        .outstnd_txs_nonlkd_i            (1'b0),
        .unlocking_tx_rcvd_i             (1'b0),
        .bus_grant_arb_i                 ({AW_NVM{1'b0}}),
        .grant_m_local_arb_i             ({AW_NVM_LOG2{1'b0}}),
        .lock_i                          (1'b0),
        
        // Outputs - Read Address Channel.
        .outstnd_txs_fed_o               (outstnd_wtxs_fed),
        .outstnd_txs_nonlkd_o            (outstnd_nonlkd_wtxs),
        .unlocking_tx_rcvd_o             (unlocking_wtx_rcvd),
        .lock_o                          (awlock),
        .bus_grant_arb_o                 (bus_grant_arb_aw),
        .grant_m_local_arb_o             (grant_m_local_arb_aw),
        
        // Inputs - Burst Response Channel.
        .cpl_tx_i                        (wcpl_tx),
    
        // Outputs - Write Data Channel/Read address channel.
        .issued_tx_o                     (issued_wtx),
        .issued_mstnum_o                 (issued_wmstnum),
        .issued_tx_mst_oh_o              (issued_wtx_mst_oh_o),
        
        // Inputs - Unconnected.
        .bus_arvalid_shrd_i      ({AW_NVM{1'b0}}), 
        .bus_awvalid_shrd_i      ({AW_NVM{1'b0}}), 
        .bus_ready_shrd_i        (1'b0), 
        .cpl_tx_shrd_bus_i       (1'b0), 

        // Outputs - Write address channel.
        .bus_valid_shrd_o        (aw_bus_valid_shrd_o_unconn), 
        .issued_tx_shrd_slv_oh_o (aw_issued_tx_shrd_slv_oh_o_unconn) 
      );
    end else begin : gen_aw_shrd_lyr_granted_o
      assign aw_shrd_lyr_granted_o = 1'b0;
      
       //VP::default assignment
      assign awvalid_o           = 1'b0;  
      assign awpayload_o         = {`AXI_AW_PYLD_S_W{1'b0}};
      assign bus_awready_o       = {AW_NVM{1'b0}};
      assign issued_wtx_mst_oh_o =  {AW_NVM{1'b0}};
      assign issued_wtx          =1'b0;
      assign issued_wmstnum      ={LOG2_NUM_VIS_MP{1'b0}};
    end
  endgenerate
  
  

  // Remove this block if the shared layer is performing all channel
  // sink functions for this slave on the W channel.
  generate
    if(REMOVE_W == 0) begin : gen_w_datach
      //----------------------------------------------------------------
      // Write Data Channel Block.
      //----------------------------------------------------------------
      DW_axi_sp_wdatach
      
      #(W_NVM,                 // Number of connected master ports and 
        W_NVM_LOG2,            // derived values.
        W_NVM_P1_LOG2,         //
        NUM_VIS_MP,            // Number of visible master ports.
        LOG2_NUM_VIS_MP,       // 
        AW_NVM,                // Num masters visible to dedicated AW
                               // channel.
        `AXI_W_PL_ARB,         // Pipeline W channel arbiter.
        W_MCA_EN,              // Has multi-cycle arbitration ?
        W_MCA_NC,              // Num. cycles in multi-cycle 
                               // arbitration.
        W_MCA_NC_W,            // Log base 2 of W_MCA_NC.
        ARB_TYPE_W,            // Arbitration type.
        BUS_W_PYLD_S_W,        // Width of bus containing payloads 
                               // from all visible master ports.
        `AXI_W_PYLD_S_W,       // Payload width to slave. 
        MAX_FAWC,              // Max. number of active write commands.
        LOG2_MAX_FAWC,       
        WID,                   // Write interleaving depth.
        LOG2_WID,              // Log base 2 of WID.
        LOG2_WID_P1,           // Log base 2 of (WID + 1).
        W_BUS_PRIORITY_W,      // Width of bus containing priorities of 
                               // all visible masters.
                            
        // Master visibility parameters.
         M0_VIS,  M1_VIS,  M2_VIS,  M3_VIS,   M4_VIS,  M5_VIS,
         M6_VIS,  M7_VIS,  M8_VIS,  M9_VIS,  M10_VIS, M11_VIS,
        M12_VIS, M13_VIS, M14_VIS, M15_VIS,

        // Master visibility parameters, W channel.
         W_SHARED_M0,  W_SHARED_M1,   W_SHARED_M2,  W_SHARED_M3,
         W_SHARED_M4,  W_SHARED_M5,   W_SHARED_M6,  W_SHARED_M7,  
         W_SHARED_M8,  W_SHARED_M9,  W_SHARED_M10, W_SHARED_M11,
        W_SHARED_M12, W_SHARED_M13,  W_SHARED_M14, W_SHARED_M15,
        
        // Master visibility parameters, AW channel.
         AW_SHARED_M0,  AW_SHARED_M1,   AW_SHARED_M2,  AW_SHARED_M3,
         AW_SHARED_M4,  AW_SHARED_M5,   AW_SHARED_M6,  AW_SHARED_M7,  
         AW_SHARED_M8,  AW_SHARED_M9,  AW_SHARED_M10, AW_SHARED_M11,
        AW_SHARED_M12, AW_SHARED_M13,  AW_SHARED_M14, AW_SHARED_M15,

        AW_HAS_SHRD_DDCTD_LNK, // Does AW have shared->dedicated 
                               // channel link.
        W_HAS_SHRD_DDCTD_LNK,  // Does W have shared->dedicated
                               // channel link.
        0,                     // Shared layer ? No.
        1,                     // Num shared slaves, N/A.
        0,                     // Shared layer pipeline ? N/A.
        REMOVE_AW              // Is this slaves AW now shared ?
       )
      U_W_DW_axi_sp_wdatach (
        // Inputs - System.
        .aclk_i                          (aclk_i),
        .aresetn_i                       (aresetn_i),
        .bus_mst_priorities_i            (w_bus_mst_priorities_i),
        
        // Inputs - External Slave.
        .ready_i                         (wready_i),
        
        // Outputs - External Slave.
        .valid_o                         (wvalid_o),
        .payload_o                       (wpayload_o),
        
        // Inputs - Master Ports.
        .bus_valid_i                     (bus_wvalid_i),
        .bus_payload_i                   (bus_wpayload_i),
        
        // Outputs - Master Ports.
        .bus_ready_o                     (bus_wready_o),
        
        // Inputs - Write Address Channel.
        .issued_tx_i                     (issued_wtx),
        .issued_mstnum_i                 (issued_wmstnum),
        .issued_tx_mst_oh_i              (issued_wtx_mst_oh_o),
        .issued_tx_shrd_ddctd_mst_oh_i   (issued_wtx_mst_oh_i), 
        
        // Inputs - Shared Write Address Channel.
        .issued_tx_shrd_i                (issued_tx_shrd_i),
        .issued_tx_shrd_mst_oh_i         (issued_tx_shrd_mst_oh_i),

        // Outputs - Shared W channel.
        .shrd_w_nxt_fb_pend_o            (shrd_w_nxt_fb_pend_o),

        // Inputs - unconnected.
        .bus_valid_shrd_i                ({W_NVM{1'b0}}), 
        .bus_ready_shrd_i                (1'b0), 
        .shrd_w_nxt_fb_pend_bus_i        (1'b0), 
        .w_layer_s_m_bus_i               ({W_NVM{1'b0}}), 
        .issued_tx_shrd_slv_oh_i         (1'b0),

        // Outputs - Unconnected.
        .bus_valid_shrd_o                (w_bus_valid_shrd_o_unconn) 
      );
    end else begin : default_assignment ///VP:: default assignments to avoide lint error
      assign wvalid_o       = 1'b0;
      assign wpayload_o           = {`AXI_W_PYLD_S_W{1'b0}};
      assign bus_wready_o    = {W_NVM{1'b0}};
      assign shrd_w_nxt_fb_pend_o = 1'b0;  
    end

  endgenerate


  //--------------------------------------------------------------------
  // Burst Response Channel Block.
  //--------------------------------------------------------------------
  DW_axi_sp_drespch
  
  #(NUM_VIS_MP,         // Number of visible master ports.
    LOG2_NUM_VIS_MP,    // Log 2 of number of visible master ports.
    `AXI_B_PYLD_M_W,    // Payload width to master.
    `AXI_B_PYLD_S_W,    // Payload width to slave.
    
    // Master visibility parameters.
     M0_VIS,  M1_VIS,  M2_VIS,  M3_VIS,   M4_VIS,  M5_VIS,
     M6_VIS,  M7_VIS,  M8_VIS,  M9_VIS,  M10_VIS, M11_VIS,
    M12_VIS, M13_VIS, M14_VIS, M15_VIS,
    
    `AXI_NOT_R_CH,      // R or B channel ?

    B_SHARED_LAYER_VIS, // Is there an B shared layer.

    // Source on shared or dedicated layer parameters.
     B_SHARED_M0,  B_SHARED_M1,  B_SHARED_M2,  B_SHARED_M3, 
     B_SHARED_M4,  B_SHARED_M5,  B_SHARED_M6,  B_SHARED_M7, 
     B_SHARED_M8,  B_SHARED_M9, B_SHARED_M10, B_SHARED_M11, 
    B_SHARED_M12, B_SHARED_M13, B_SHARED_M14, B_SHARED_M15,
    
    // Address channel source on shared or dedicated layer 
    // parameters.
     AW_SHARED_M0,  AW_SHARED_M1,  AW_SHARED_M2,  AW_SHARED_M3, 
     AW_SHARED_M4,  AW_SHARED_M5,  AW_SHARED_M6,  AW_SHARED_M7, 
     AW_SHARED_M8,  AW_SHARED_M9, AW_SHARED_M10, AW_SHARED_M11, 
    AW_SHARED_M12, AW_SHARED_M13, AW_SHARED_M14, AW_SHARED_M15 
   )
  U_B_DW_axi_sp_drespch (
    // Inputs - System.
    //.aclk_i         (aclk_i),
    //.aresetn_i      (aresetn_i),
    
    // Inputs - External Slave.
    .valid_i        (bvalid_i),
    .payload_i      (bpayload_i),
    
    // Outputs - External Slave.
    .ready_o        (bready_o),
    
    // Inputs - Master Ports, via internal reg slice.
    .ready_i        (bready_sp),
    
    // Outputs - Master Ports, via internal reg slice.
    .bus_valid_o    (bus_bvalid_sp),
    .valid_o        (bvalid_sp),
    .shrd_ch_req_o  (b_shrd_ch_req_sp),
    .payload_o      (bpayload_sp),

    // Outputs - Write Address Channel.
    .cpl_tx_o       (wcpl_tx),
    .shrd_cpl_tx_o  (wcpl_tx_shrd_o)
  );


  //--------------------------------------------------------------------
  // Internal register slice for B channel.
  //--------------------------------------------------------------------
  DW_axi_irs
  
  #(`AXI_B_TMO,        // Channel timing option.
    NUM_VIS_MP,        // Number of visible master ports.
    `AXI_B_PL_ARB,     // Is channel arbiter pipelined.
    BPAYLOAD_W,        // Channel payload width.
    1,                 // Log base 2 of num. visible ports. Not required
                       // in this instance, pass 1 to compile clean.
    1,                 // Master ID width, not required, pass 1 to 
                       // compile clean.
    0,                 // Masking logic not required.
    0,                 // ID right hand bit, not required here.
    0,                 // ID left hand bit, not required here.
    0,                 // Pass a 1 for W channel, not required.
    B_SHARED_LAYER_VIS // Shared layer signal(s) required ?
  )
  U_B_DW_axi_irs (
    // Inputs - System.
    .aclk_i        (aclk_i),
    .aresetn_i     (aresetn_i),

    // Inputs - Payload source.
    .payload_i    (bpayload_sp),
    .bus_valid_i  (bus_bvalid_sp),
    .valid_i      (bvalid_sp),
    .mask_valid_i (1'b0), // Masking not required here.
    .shrd_ch_req_i (b_shrd_ch_req_sp),
  
    // Outputs - Payload source.
    .ready_o       (bready_sp),

    // Inputs - Payload destination.
    .ready_i       (bready_irs),

    // Outputs - Unconnected.
    .id_o         (b_id_irs_unconn),
    .local_slv_o  (b_local_slv_irs_unconn),

    // Outputs - Payload destination.
    .bus_valid_o   (bus_bvalid_irs),
    .shrd_ch_req_o (b_shrd_ch_req_irs),
    .payload_o     (bpayload_irs)
  );

  //--------------------------------------------------------------------
  // Internal register slice for B channel.
  //--------------------------------------------------------------------
  DW_axi_irs_arbpl
  
  #(`AXI_B_PL_ARB,     // Is channel arbiter pipelined.
    NUM_VIS_MP,        // Number of visible master ports.
    BPAYLOAD_W,        // Channel payload width.
    1,                 // Log base 2 of num. visible ports. Not required
                       // in this instance, pass 1 to compile clean.
    1,                 // Master ID width, not required, pass 1 to 
                       // compile clean.
    0,                 // Masking logic not required here.
    0,                 // ID right hand bit, not required here.
    0,                 // ID left hand bit, not required here.
    0,                 // Pass a 1 for W channel, not required.
    B_SHARED_LAYER_VIS // Shared layer signal(s) required ?
  )
  U_B_DW_axi_irs_arbpl (
    // Inputs - System.
    .aclk_i                   (aclk_i),
    .aresetn_i                (aresetn_i),

    // Inputs - Payload source.
    .payload_i                (bpayload_irs),
    .bus_valid_i              (bus_bvalid_irs),
    .mask_valid_i             (1'b0), // Masking not required here.
    .shrd_ch_req_i            (b_shrd_ch_req_irs),
    .issued_wtx_shrd_mst_oh_i (1'b0),
  
    // Outputs - Payload source.
    .ready_o                  (bready_irs),

    // Inputs - Payload destination.
    .bus_ready_i              (bus_bready_i),

    // Outputs - Unconnected.
    .id_o                     (b_id_irs_arbpl_unconn),
    .local_slv_o              (b_local_slv_irs_arbpl_unconn),

    // Outputs - Payload destination.
    .bus_valid_o              (bus_bvalid_o),
    .payload_o                (bpayload_o),
    .shrd_ch_req_o            (b_shrd_ch_req_o),
    
    // Unconnected outputs.
    .bus_valid_r_o            (b_bus_valid_r_o_unconn), 
    .payload_prereg_o         (bpayload_prereg_unconn),
    .issued_wtx_shrd_mst_oh_o (b_issued_wtx_shrd_mst_oh_o)
  );

endmodule

