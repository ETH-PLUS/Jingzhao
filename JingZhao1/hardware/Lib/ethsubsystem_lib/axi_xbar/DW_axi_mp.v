/*
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
// File Version     :        $Revision: #23 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_mp.v#23 $ 
**
** ---------------------------------------------------------------------
**
** File     : DW_axi_mp.v
//
//
** Created  : Mon May  9 19:49:55 MEST 2005
** Modified : $Date: 2020/03/22 $
** Abstract : Master Port block for the DW_axi interconnect.
**            External AXI masters connect to the DW_axi through the
**            master port block.
**
** ---------------------------------------------------------------------
*/
module DW_axi_mp (
  aclk_i,
  aresetn_i,



  r_bus_slv_priorities_i,
  b_bus_slv_priorities_i,



  // READ ADDRESS CHANNEL.


  // Inputs - External Master.
  arvalid_i,
  arpayload_i,

  // Outputs - External Master.
  arready_o,

  // Inputs - Slave Ports.
  bus_arready_i,

  // Outputs - Slave Ports.
  bus_arvalid_o,
  ar_shrd_ch_req_o,
  arpayload_o,


  // READ DATA CHANNEL.

  // Inputs - External Master.
  rready_i,

  // Outputs - External Master.
  rvalid_o,
  rpayload_o,

  // Inputs - Slave Ports.
  bus_rvalid_i,
  bus_rpayload_i,

  // Outputs - Slave Ports.
  bus_rready_o,


  // Inputs - Shared Master Port.
  rcpl_tx_shrd_i,
  rcpl_id_shrd_i,

  // WRITE ADDRESS CHANNEL.


  // Inputs - External Master.
  awvalid_i,
  awpayload_i,

  // Outputs - External Master.
  awready_o,

  // Inputs - Slave Ports.
  bus_awready_i,
  aw_shrd_lyr_granted_s_bus_i,
  issued_wtx_shrd_sys_s_bus_i,

  // Outputs - Slave Ports.
  bus_awvalid_o,
  aw_shrd_ch_req_o,
  awpayload_o,


  // WRITE DATA CHANNEL.

  // Inputs - External Master.
  wvalid_i,
  wpayload_i,

  // Outputs - External Master.
  wready_o,

  // Inputs - Slave Ports.
  bus_wready_i,

  // Outputs - Slave Ports.
  bus_wvalid_o,
  w_shrd_ch_req_o,
  wpayload_o,


  // BURST RESPONSE CHANNEL.

  // Inputs - External Master.
  bready_i,

  // Outputs - External Master.
  bvalid_o,
  bpayload_o,

  // Inputs - Slave Ports.
  bus_bvalid_i,
  bus_bpayload_i,

  // Outputs - Slave Ports.
  bus_bready_o,

  // Inputs - Shared Master Port.
  wcpl_tx_shrd_i,
  wcpl_id_shrd_i

);

//----------------------------------------------------------------------
// MODULE PARAMETERS.
//----------------------------------------------------------------------
  parameter MS_NUM = 0; // System number of this master port
                        // instantiation.

  parameter ICM_PORT = 0; // Master port configured as interconnecting port

  parameter NUM_VIS_SP = 16; // Number of slave ports visible to
                             // this master port.

  parameter LOG2_NUM_VIS_SP = 4; // Log base 2 NUM_VIS_SP.

  // Number of visibile masters for R/B channels & derived params.
  parameter R_NVS = 16;
  parameter R_NVS_LOG2 = 4;
  parameter R_NVS_P1_LOG2 = 4;

  parameter B_NVS = 16;
  parameter B_NVS_LOG2 = 4;
  parameter B_NVS_P1_LOG2 = 4;


  parameter ARB_TYPE_R = 0; // Arbiter type for R channel.
  parameter ARB_TYPE_B = 0; // Arbiter type for B channel.

  parameter R_MCA_EN = 0; // 1 if multi-cycle arbitration is enabled
  parameter B_MCA_EN = 0; // for each of these 2 channels.

  parameter R_MCA_NC = 0; // Number of arbitration cycles if
  parameter B_MCA_NC = 0; // multi cycle arbitration is enabled
                          // for each of these 2 channels.

  parameter R_MCA_NC_W = 0; // Log base 2 of *_MCA_NC + 1.
  parameter B_MCA_NC_W = 0;

  // 17 slave visibility parameters for boot and normal mode, all
  // possible user slaves + 1 for the default slave - always slave 0.
  parameter S0_N_VIS  = 1; // Normal mode slave visibility parameters.
  parameter S1_N_VIS  = 1;
  parameter S2_N_VIS  = 1;
  parameter S3_N_VIS  = 1;
  parameter S4_N_VIS  = 1;
  parameter S5_N_VIS  = 1;
  parameter S6_N_VIS  = 1;
  parameter S7_N_VIS  = 1;
  parameter S8_N_VIS  = 1;
  parameter S9_N_VIS  = 1;
  parameter S10_N_VIS = 1;
  parameter S11_N_VIS = 1;
  parameter S12_N_VIS = 1;
  parameter S13_N_VIS = 1;
  parameter S14_N_VIS = 1;
  parameter S15_N_VIS = 1;
  parameter S16_N_VIS = 1;

  parameter S0_B_VIS  = 1; // Boot mode slave visibility parameters.
  parameter S1_B_VIS  = 1;
  parameter S2_B_VIS  = 1;
  parameter S3_B_VIS  = 1;
  parameter S4_B_VIS  = 1;
  parameter S5_B_VIS  = 1;
  parameter S6_B_VIS  = 1;
  parameter S7_B_VIS  = 1;
  parameter S8_B_VIS  = 1;
  parameter S9_B_VIS  = 1;
  parameter S10_B_VIS = 1;
  parameter S11_B_VIS = 1;
  parameter S12_B_VIS = 1;
  parameter S13_B_VIS = 1;
  parameter S14_B_VIS = 1;
  parameter S15_B_VIS = 1;
  parameter S16_B_VIS = 1;


  parameter MAX_RCA_ID_M = 4; // Number of active transactions
  parameter MAX_WCA_ID_M = 4; // allowed per ID value. Read and
                              // write address channels.

  parameter MAX_URIDA_M  = 4; // Number of unique ID values that
  parameter MAX_UWIDA_M  = 4; // the master port can have active
                              // transactions for. Read and write
                                 // address channels.


  parameter LOG2_MAX_RCA_ID_P1_M = 2; // Log base 2 of the above
  parameter LOG2_MAX_WCA_ID_P1_M = 2; // MAX_[R/W]CA_ID_M parameters.
                                      // plus 1. Width of transaction
                                          // count register for each
                                          // unique ID. Needs to be plus
                                          // 1 because count must reach
                                          // the max allowed value.

  parameter LOG2_MAX_URIDA_M = 2; // Log base 2 of the above
  parameter LOG2_MAX_UWIDA_M = 2; // MAX_U[R/W]IDA_M parameters.

  parameter RI_LIMIT = 0; // Limit read interleaving to 1, true/false.

  // AR channel slaves, accessed through shared layer ?
  parameter AR_SHARED_S0 = 0;
  parameter AR_SHARED_S1 = 0;
  parameter AR_SHARED_S2 = 0;
  parameter AR_SHARED_S3 = 0;
  parameter AR_SHARED_S4 = 0;
  parameter AR_SHARED_S5 = 0;
  parameter AR_SHARED_S6 = 0;
  parameter AR_SHARED_S7 = 0;
  parameter AR_SHARED_S8 = 0;
  parameter AR_SHARED_S9 = 0;
  parameter AR_SHARED_S10 = 0;
  parameter AR_SHARED_S11 = 0;
  parameter AR_SHARED_S12 = 0;
  parameter AR_SHARED_S13 = 0;
  parameter AR_SHARED_S14 = 0;
  parameter AR_SHARED_S15 = 0;
  parameter AR_SHARED_S16 = 0;

  // AW channel slaves, accessed through shared layer ?
  parameter AW_SHARED_S0 = 0;
  parameter AW_SHARED_S1 = 0;
  parameter AW_SHARED_S2 = 0;
  parameter AW_SHARED_S3 = 0;
  parameter AW_SHARED_S4 = 0;
  parameter AW_SHARED_S5 = 0;
  parameter AW_SHARED_S6 = 0;
  parameter AW_SHARED_S7 = 0;
  parameter AW_SHARED_S8 = 0;
  parameter AW_SHARED_S9 = 0;
  parameter AW_SHARED_S10 = 0;
  parameter AW_SHARED_S11 = 0;
  parameter AW_SHARED_S12 = 0;
  parameter AW_SHARED_S13 = 0;
  parameter AW_SHARED_S14 = 0;
  parameter AW_SHARED_S15 = 0;
  parameter AW_SHARED_S16 = 0;

  // W channel slaves, accessed through shared layer ?
  parameter W_SHARED_S0 = 0;
  parameter W_SHARED_S1 = 0;
  parameter W_SHARED_S2 = 0;
  parameter W_SHARED_S3 = 0;
  parameter W_SHARED_S4 = 0;
  parameter W_SHARED_S5 = 0;
  parameter W_SHARED_S6 = 0;
  parameter W_SHARED_S7 = 0;
  parameter W_SHARED_S8 = 0;
  parameter W_SHARED_S9 = 0;
  parameter W_SHARED_S10 = 0;
  parameter W_SHARED_S11 = 0;
  parameter W_SHARED_S12 = 0;
  parameter W_SHARED_S13 = 0;
  parameter W_SHARED_S14 = 0;
  parameter W_SHARED_S15 = 0;
  parameter W_SHARED_S16 = 0;

  // AW channel slaves, which ones have a shared to dedicated link.
  parameter AW_SHRD_DDCTD_S0 = 0;
  parameter AW_SHRD_DDCTD_S1 = 0;
  parameter AW_SHRD_DDCTD_S2 = 0;
  parameter AW_SHRD_DDCTD_S3 = 0;
  parameter AW_SHRD_DDCTD_S4 = 0;
  parameter AW_SHRD_DDCTD_S5 = 0;
  parameter AW_SHRD_DDCTD_S6 = 0;
  parameter AW_SHRD_DDCTD_S7 = 0;
  parameter AW_SHRD_DDCTD_S8 = 0;
  parameter AW_SHRD_DDCTD_S9 = 0;
  parameter AW_SHRD_DDCTD_S10 = 0;
  parameter AW_SHRD_DDCTD_S11 = 0;
  parameter AW_SHRD_DDCTD_S12 = 0;
  parameter AW_SHRD_DDCTD_S13 = 0;
  parameter AW_SHRD_DDCTD_S14 = 0;
  parameter AW_SHRD_DDCTD_S15 = 0;
  parameter AW_SHRD_DDCTD_S16 = 0;


  // Parameters to remove sink blocks here if the function is performed
  // by the shared layer.
  parameter REMOVE_R = 0;
  parameter REMOVE_B = 0;


  // Active ID buffer width and read pointer width
  parameter ACT_ID_BUF_POINTER_WIDTH_AW = 8;
  parameter LOG2_ACT_ID_BUF_POINTER_WIDTH_AW = 3;
  parameter ACT_ID_BUF_POINTER_WIDTH_AR = 8;
  parameter LOG2_ACT_ID_BUF_POINTER_WIDTH_AR = 3;


  // Additional bits required for payload bus when ICM ports are used
  localparam ICM_PYLD = `AXI_HAS_BICMD*`AXI_LOG2_NM;

  // Width of concatenated read data channel payload vector from all
  // visible slave ports.
  // Note : master number has been stripped from ID signal in
  //        the slave port.
  localparam BUS_R_PYLD_S_W
             = R_NVS*(`AXI_R_PYLD_M_W + ICM_PYLD);

  // Width of concatenated burst response channel payload vector for all
  // visible slave ports.
  // Note : master number has been stripped from ID signal in
  //        the slave port.
  localparam BUS_B_PYLD_S_W
             = B_NVS*(`AXI_B_PYLD_M_W + ICM_PYLD);

  // Width of concatenated slave priorities for all visible slave ports.
  localparam R_BUS_PRIORITY_W = `AXI_SLV_PRIORITY_W*R_NVS;
  localparam B_BUS_PRIORITY_W = `AXI_SLV_PRIORITY_W*B_NVS;

  // Width of active read IDs bus.
  localparam ACT_RIDS_W
             = MAX_URIDA_M*(`AXI_MIDW + ICM_PORT*(`AXI_LOG2_NM));

  // Width of active read slave numbers bus.
  localparam ACT_RSNUMS_W = MAX_URIDA_M*LOG2_NUM_VIS_SP;
  // Width of active read count per ID bus.
  localparam ACT_RCOUNT_W = MAX_URIDA_M*LOG2_MAX_RCA_ID_P1_M;


  // Width of active write IDs bus.
  localparam ACT_WIDS_W
             = MAX_UWIDA_M*(`AXI_MIDW + ICM_PORT*(`AXI_LOG2_NM));

  // Width of active write slave numbers bus.
  localparam ACT_WSNUMS_W = MAX_UWIDA_M*LOG2_NUM_VIS_SP;
  // Width of active write count per ID bus.
  localparam ACT_WCOUNT_W = MAX_UWIDA_M*LOG2_MAX_WCA_ID_P1_M;

  // Parameters to tell us which of the shared sink channels are visible
  // to this master port.
  localparam AR_SHARED_LAYER_VIS
    = (  AR_SHARED_S16
       | AR_SHARED_S15
       | AR_SHARED_S14
       | AR_SHARED_S13
       | AR_SHARED_S12
       | AR_SHARED_S11
       | AR_SHARED_S10
       | AR_SHARED_S9
       | AR_SHARED_S8
       | AR_SHARED_S7
       | AR_SHARED_S6
       | AR_SHARED_S5
       | AR_SHARED_S4
       | AR_SHARED_S3
       | AR_SHARED_S2
       | AR_SHARED_S1
       | AR_SHARED_S0
      );

  // Parameters to control which pipeline stage will do transaction
  // masking. The first enabled pipeline stage will perform the masking.
  // If there are no pipelines in a channel the channel source block
  // will do the task.
  localparam AW_IRS_DO_MASKING
    = (`AXI_AW_TMO!=0);
  localparam AW_IRS_ARB_PL_DO_MASKING
    = (`AXI_AW_TMO==0) & (`AXI_AW_PL_ARB==1);

  localparam AR_IRS_DO_MASKING
    = (`AXI_AR_TMO!=0);
  localparam AR_IRS_ARB_PL_DO_MASKING
    = (`AXI_AR_TMO==0) & (`AXI_AR_PL_ARB==1);

  localparam W_IRS_DO_MASKING
    = (`AXI_W_TMO!=0);
  localparam W_IRS_ARB_PL_DO_MASKING
    = (`AXI_W_TMO==0) & (`AXI_W_PL_ARB==1);

  // Must use the slave ID width if this is an ICM port.
  localparam AW_PYLD_ID_RHS = ICM_PORT
                              ? `AXI_AWPYLD_ID_RHS_S
                              : `AXI_AWPYLD_ID_RHS_M;

  localparam AW_PYLD_ID_LHS = ICM_PORT
                              ? `AXI_AWPYLD_ID_LHS_S
                              : `AXI_AWPYLD_ID_LHS_M;

  localparam AR_PYLD_ID_RHS = ICM_PORT
                              ? `AXI_ARPYLD_ID_RHS_S
                              : `AXI_ARPYLD_ID_RHS_M;

  localparam AR_PYLD_ID_LHS = ICM_PORT
                              ? `AXI_ARPYLD_ID_LHS_S
                              : `AXI_ARPYLD_ID_LHS_M;

  localparam W_PYLD_ID_RHS = ICM_PORT
                             ? `AXI_WPYLD_ID_RHS_S
                             : `AXI_WPYLD_ID_RHS_M;

  localparam W_PYLD_ID_LHS = ICM_PORT
                             ? `AXI_WPYLD_ID_LHS_S
                             : `AXI_WPYLD_ID_LHS_M;



  localparam AW_SHARED_LAYER_VIS
    = (  AW_SHARED_S16
       | AW_SHARED_S15
       | AW_SHARED_S14
       | AW_SHARED_S13
       | AW_SHARED_S12
       | AW_SHARED_S11
       | AW_SHARED_S10
       | AW_SHARED_S9
       | AW_SHARED_S8
       | AW_SHARED_S7
       | AW_SHARED_S6
       | AW_SHARED_S5
       | AW_SHARED_S4
       | AW_SHARED_S3
       | AW_SHARED_S2
       | AW_SHARED_S1
       | AW_SHARED_S0
      );

  localparam W_SHARED_LAYER_VIS
    = (  W_SHARED_S16
       | W_SHARED_S15
       | W_SHARED_S14
       | W_SHARED_S13
       | W_SHARED_S12
       | W_SHARED_S11
       | W_SHARED_S10
       | W_SHARED_S9
       | W_SHARED_S8
       | W_SHARED_S7
       | W_SHARED_S6
       | W_SHARED_S5
       | W_SHARED_S4
       | W_SHARED_S3
       | W_SHARED_S2
       | W_SHARED_S1
       | W_SHARED_S0
      );

  // Combine boot and normal slave visibility parameters.
  localparam S0_VIS = S0_B_VIS | S0_N_VIS;
  localparam S1_VIS = S1_B_VIS | S1_N_VIS;
  localparam S2_VIS = S2_B_VIS | S2_N_VIS;
  localparam S3_VIS = S3_B_VIS | S3_N_VIS;
  localparam S4_VIS = S4_B_VIS | S4_N_VIS;
  localparam S5_VIS = S5_B_VIS | S5_N_VIS;
  localparam S6_VIS = S6_B_VIS | S6_N_VIS;
  localparam S7_VIS = S7_B_VIS | S7_N_VIS;
  localparam S8_VIS = S8_B_VIS | S8_N_VIS;
  localparam S9_VIS = S9_B_VIS | S9_N_VIS;
  localparam S10_VIS = S10_B_VIS | S10_N_VIS;
  localparam S11_VIS = S11_B_VIS | S11_N_VIS;
  localparam S12_VIS = S12_B_VIS | S12_N_VIS;
  localparam S13_VIS = S13_B_VIS | S13_N_VIS;
  localparam S14_VIS = S14_B_VIS | S14_N_VIS;
  localparam S15_VIS = S15_B_VIS | S15_N_VIS;
  localparam S16_VIS = S16_B_VIS | S16_N_VIS;


//----------------------------------------------------------------------
// LOCAL MAROS.
//----------------------------------------------------------------------

  `define LCL_AR_PYLD_W `AXI_AR_PYLD_M_W
  `define LCL_AW_PYLD_W `AXI_AW_PYLD_M_W
  `define LCL_W_PYLD_W  `AXI_W_PYLD_M_W

  `define LCL_R_M_PYLD_W  `AXI_R_PYLD_M_W
  `define LCL_R_S_PYLD_W  `AXI_R_PYLD_M_W

  `define LCL_B_M_PYLD_W  `AXI_B_PYLD_M_W
  `define LCL_B_S_PYLD_W  `AXI_B_PYLD_M_W

  `define ID_W `AXI_MIDW

  `define R_PYLD_ICM_W `LCL_R_M_PYLD_W
  `define B_PYLD_ICM_W `LCL_B_M_PYLD_W
  
//----------------------------------------------------------------------
// PORT DECLARATIONS.
//----------------------------------------------------------------------
  input aclk_i;    // AXI system clock.
  input aresetn_i; // AXI system reset.



  
  // Signal will not be used if the shared layer is performing all channel
  // sink functions for this master on the B channel

  // Bus containing priorities of all connected slaves for R and B
  // channels.
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input [R_BUS_PRIORITY_W-1:0] r_bus_slv_priorities_i;

  // sink functions for this master on the B channel 
  input [B_BUS_PRIORITY_W-1:0] b_bus_slv_priorities_i;
  //spyglass enable_block W240



  //--------------------------------------------------------------------
  // READ ADDRESS CHANNEL.
  //--------------------------------------------------------------------


  // Inputs - External Master.
  input                         arvalid_i;    // Valid from external
                                              // master.

  input [`LCL_AR_PYLD_W-1:0]  arpayload_i;  // Channel payload vector.

  // Outputs - External Master.
  output                        arready_o;    // Ready to external
                                              // master.

  // Inputs - Slave Ports.
  input [NUM_VIS_SP-1:0]        bus_arready_i; // All ready signals from
                                               // connected slave ports.

  // Outputs - Slave Ports.
  output [NUM_VIS_SP-1:0]       bus_arvalid_o; // Valid to slave ports.
  output                        ar_shrd_ch_req_o; // Request for AR
                                                  // shared layer.
  output [`AXI_AR_PYLD_S_W-1:0] arpayload_o;   // Payload to slave
                                               // ports.


  //--------------------------------------------------------------------
  // READ DATA CHANNEL.
  //--------------------------------------------------------------------

  // Inputs - External Master.
  // This signal is not used if shared layer is performing all channel sink functions for this master on the R channel.
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input                         rready_i; // Ready from external master.
  //spyglass enable_block W240

  // Outputs - External Master.
  output                        rvalid_o;   // Valid to external master.
  output [`LCL_R_M_PYLD_W-1:0]  rpayload_o; // Payload vector to
                                            // external master.
  // Signal will not be used if the shared layer is performing all channel
  // sink functions for this master on the B channel

  // Inputs - Slave Ports.
  // All valid signals from visible slave ports.
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input [R_NVS-1:0] bus_rvalid_i;

  // All payload vectors from visible slave ports.
  input [BUS_R_PYLD_S_W-1:0] bus_rpayload_i;
  //spyglass enable_block W240

  // Outputs - Slave Ports.
  // Ready signal to visible  slave ports.
  output [R_NVS-1:0] bus_rready_o;

  // Inputs - Shared Master Port.
  // T/x completion data from the shared master port.
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input             rcpl_tx_shrd_i;
  input [`ID_W-1:0] rcpl_id_shrd_i;
  //spyglass enable_block W240

  //--------------------------------------------------------------------
  // WRITE ADDRESS CHANNEL.
  //--------------------------------------------------------------------


  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  // Inputs - External Master.
  input                         awvalid_i;    // Valid from external
                                              // master.
  input [`LCL_AW_PYLD_W-1:0]  awpayload_i;  // Channel payload vector.
  //spyglass enable_block W240

  // Outputs - External Master.
  output                        awready_o;    // Ready to external
                                              // master.

  // Inputs - Slave Ports.
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input [NUM_VIS_SP-1:0]        bus_awready_i; // All ready signals from
                                               // connected slave ports.

  // Bit for each attached slave, asserted if the slaves dedicated layer
  // has granted the shared layer.
  input [NUM_VIS_SP-1:0]  aw_shrd_lyr_granted_s_bus_i;

  // Bit for each attached slave, asserted if this master port was
  // requesting to the slave on the shared to dedicated link.
  input [NUM_VIS_SP-1:0] issued_wtx_shrd_sys_s_bus_i;
  //spyglass enable_block W240

  // Outputs - Slave Ports.
  output [NUM_VIS_SP-1:0]       bus_awvalid_o; // Valid to master
                                               // interfaces.
  output                        aw_shrd_ch_req_o; // Request for AW
                                                  // shared layer.
  output [`AXI_AW_PYLD_S_W-1:0] awpayload_o;   // Payload to master
                                               // interfaces.


  //--------------------------------------------------------------------
  // WRITE DATA CHANNEL.
  //--------------------------------------------------------------------

  // Inputs - External Master.
  input                        wvalid_i;   // Valid from external
                                           // master.

  input [`LCL_W_PYLD_W-1:0]  wpayload_i; // Payload from external
                                         // master.

  // Outputs - External Master.
  output                       wready_o; // Ready to external master.

  // Inputs - Slave Ports.
  input [NUM_VIS_SP-1:0]       bus_wready_i; // Ready signals from all
                                             // slave ports.

  // Outputs - Slave Ports.
  output [NUM_VIS_SP-1:0]      bus_wvalid_o; // Valid to slave ports.
  output                       w_shrd_ch_req_o; // Request for W
                                                // shared layer.
  output [`AXI_W_PYLD_S_W-1:0] wpayload_o;   // Payload to slave ports.


  //--------------------------------------------------------------------
  // BURST RESPONSE CHANNEL.
  //--------------------------------------------------------------------

  // Inputs - External Master.
  // Signal will not be used if the shared layer is performing all channel
  // sink functions for this master on the B channel
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input                        bready_i; // Ready from external master.
  //spyglass enable_block W240

  // Outputs - External Master.
  output                       bvalid_o;   // Valid to external master.
  output [`LCL_B_M_PYLD_W-1:0] bpayload_o; // Payload vector to external
                                           // master.

  // Inputs - Slave Ports.
  // All valid signals from visible slave ports.
  // Signal will not be used if the shared layer is performing all channel
  // sink functions for this master on the B channel
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input [B_NVS-1:0] bus_bvalid_i;

  // All payload vectors from visible slave ports.
  input [BUS_B_PYLD_S_W-1:0] bus_bpayload_i;
  //spyglass enable_block W240

  // Outputs - Slave Ports.
  // Ready signal to visible  slave ports.
  output [B_NVS-1:0] bus_bready_o;

  // Inputs - Shared Master Port.
  // T/x completion data from the shared master port.
  // Signal will not be used if the shared layer is performing all channel
  // sink functions for this master on the B channel
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input             wcpl_tx_shrd_i;
  input [`ID_W-1:0] wcpl_id_shrd_i;
  //spyglass enable_block W240

  //--------------------------------------------------------------------
  // WIRE VARIABLES.
  //--------------------------------------------------------------------

  // Read and write transaction completion signals. From burst
  // response channel to write address channel for write transactions,
  // from read data channel to read address channel for
   // read transactions.
  wire                  rcpl_tx_lcl; // From local read data and
  wire [`ID_W-1:0]      rcpl_id_lcl; // burst response channels.
  wire                  wcpl_tx_lcl;
  wire [`ID_W-1:0]      wcpl_id_lcl;
  wire                  rcpl_tx; // Selected between shared and local
  wire [`ID_W-1:0]      rcpl_id; // completion signals.
  wire                  wcpl_tx;
  wire [`ID_W-1:0]      wcpl_id;

  wire [ACT_WIDS_W-1:0]   act_wids;    // Active write IDs bus.
  wire [ACT_WSNUMS_W-1:0] act_wsnums;  // Active write slave numbers
                                       // bus.

  wire [MAX_UWIDA_M-1:0] issuedtx_slot_oh; // Which write ID slot has
                                           // had a transaction
                                                // accepted.

  //wire [ACT_RSNUMS_W-1:0] act_rsnums;  // Active read slave numbers bus.

  // Registered W valids from write data channel arbiter pipeline stage
  // register slice.
  wire [NUM_VIS_SP-1:0] w_bus_valid_r;
  

  //--------------------------------------------------------------------
  // Signals to connect between both internal register slices and each
  // master port channel block.
  // Source channels only.
  //--------------------------------------------------------------------
  wire [NUM_VIS_SP-1:0]       bus_arvalid_mp;
  wire                        arvalid_mp;
  wire                        armask_valid_mp;
  wire                        arready_mp;
  wire [`AXI_AR_PYLD_S_W-1:0] arpayload_mp;
  wire [`AXI_AR_PYLD_S_W-1:0] arpayload_prereg;

  wire [`ID_W-1:0]            ar_id_irs;
  wire [LOG2_NUM_VIS_SP-1:0]  ar_local_slv_irs;

  wire [`ID_W-1:0]            ar_id_irs_arbpl;
  wire [LOG2_NUM_VIS_SP-1:0]  ar_local_slv_irs_arbpl;

  wire [`ID_W-1:0]            ar_id_irs_mux;
  wire [LOG2_NUM_VIS_SP-1:0]  ar_local_slv_irs_mux;


  wire [NUM_VIS_SP-1:0]       bus_arvalid_irs;
  wire                        arready_irs;
  wire [`AXI_AR_PYLD_S_W-1:0] arpayload_irs;

  wire [NUM_VIS_SP-1:0]       bus_awvalid_mp;
  wire                        awvalid_mp;
  wire                        awmask_valid_mp;
  wire                        awready_mp;
  wire [`AXI_AW_PYLD_S_W-1:0] awpayload_mp;
  wire [`AXI_AW_PYLD_S_W-1:0] awpayload_prereg;

  wire [`ID_W-1:0]            aw_id_irs;
  wire [LOG2_NUM_VIS_SP-1:0]  aw_local_slv_irs;

  wire [`ID_W-1:0]            aw_id_irs_arbpl;
  wire [LOG2_NUM_VIS_SP-1:0]  aw_local_slv_irs_arbpl;

  wire [`ID_W-1:0]            aw_id_irs_mux;
  wire [LOG2_NUM_VIS_SP-1:0]  aw_local_slv_irs_mux;


  wire [NUM_VIS_SP-1:0]       bus_awvalid_irs;
  wire [NUM_VIS_SP-1:0]       bus_awvalid_irs_arbpl;
  wire                        aw_shrd_ch_req_irs_arbpl;
  wire                        awready_irs;
  wire [`AXI_AW_PYLD_S_W-1:0] awpayload_irs;

  wire [NUM_VIS_SP-1:0]       bus_wvalid_mp;
  wire                        wvalid_mp;
  wire                        wmask_valid_mp;
  wire                        wready_mp;
  wire [`AXI_W_PYLD_S_W-1:0]  wpayload_mp;

  wire [`ID_W-1:0]            w_id_irs;

  wire [`ID_W-1:0]            w_id_irs_arbpl;

  wire [`ID_W-1:0]            w_id_irs_mux;

  wire [NUM_VIS_SP-1:0]       bus_wvalid_irs;
  wire                        wready_irs;
  wire [`AXI_W_PYLD_S_W-1:0]  wpayload_irs;

  wire ar_shrd_ch_req_mp;
  wire aw_shrd_ch_req_mp;
  wire w_shrd_ch_req_mp;
  wire ar_shrd_ch_req_irs;
  wire aw_shrd_ch_req_irs;
  wire w_shrd_ch_req_irs;

  // Wires for unconnected sub module outputs.
  wire [LOG2_NUM_VIS_SP-1:0]  w_local_slv_irs_uncon;
  wire [LOG2_NUM_VIS_SP-1:0]  w_local_slv_irs_arbpl_uncon;
  wire [ACT_RIDS_W-1:0] act_ids_ar_unconn;
  wire [MAX_URIDA_M-1:0] issuedtx_slot_oh_ar_unconn;
  wire [`AXI_W_PYLD_S_W-1:0] wpayload_prereg_unconn;

  wire r_bus_valid_shrd_o_unconn;
  wire [`R_PYLD_ICM_W-1:0] r_payload_icm_o_unconn;
  wire r_cpl_tx_shrd_bus_o_unconn;

  wire b_bus_valid_shrd_o_unconn;
  wire [`B_PYLD_ICM_W-1:0] b_payload_icm_o_unconn;
  wire b_cpl_tx_shrd_bus_o_unconn;

  wire [NUM_VIS_SP-1:0] ar_bus_valid_r;
  wire ar_issued_wtx_shrd_mst_oh_o;

  wire [NUM_VIS_SP-1:0] aw_bus_valid_r;
  wire aw_issued_wtx_shrd_mst_oh_o;

  wire w_issued_wtx_shrd_mst_oh_o;
  
  //wire [LOG2_MAX_UWIDA_M*MAX_UWIDA_M*MAX_WCA_ID_M-1:0] act_ids_buffer_ar_unconn ;
  wire [ACT_ID_BUF_POINTER_WIDTH_AR-1:0] act_ids_buffer_ar_unconn ;
  wire [LOG2_ACT_ID_BUF_POINTER_WIDTH_AR-1:0] act_ids_rd_buffer_pointer_ar_unconn = {LOG2_ACT_ID_BUF_POINTER_WIDTH_AR{1'b0}};
  wire [LOG2_ACT_ID_BUF_POINTER_WIDTH_AW-1:0] act_ids_rd_buffer_pointer;
  wire [ACT_ID_BUF_POINTER_WIDTH_AW-1:0] act_ids_buffer ;
  wire                                   no_act_id;
  //wire [LOG2_MAX_UWIDA_M*MAX_UWIDA_M*MAX_WCA_ID_M-1:0] act_ids_buffer ;
  // region signals
  //wire [`AXI_REGIONW-1:0] arregion_o;
  //wire [`AXI_REGIONW-1:0] awregion_o;
  // Select between local and shared channel read t/x completion
  // signals.
  assign rcpl_tx = REMOVE_R ? rcpl_tx_shrd_i : rcpl_tx_lcl;
  assign rcpl_id = REMOVE_R ? rcpl_id_shrd_i : rcpl_id_lcl;

  //--------------------------------------------------------------------
  // Read Address Channel Block.
  //--------------------------------------------------------------------

  //One of the port intentionally not used
  DW_axi_mp_addrch
  
  #(MS_NUM,                   // Master port system number.
    ICM_PORT,                 // Interconnecting master port.
    NUM_VIS_SP,               // Number of visible slave ports.
    LOG2_NUM_VIS_SP,          // Log 2 of number of visible slave ports.
    `AXI_AR_TMO,              // AR channel timing option.
    `AXI_AR_PL_ARB,           // Is channel arbiter pipelined.
    `AXI_AR_PYLD_M_W,         // AR channel payload width from master.
    `AXI_AR_PYLD_S_W,         // AR channel payload width to slave.

    // Normal mode slave visibility parameters.
     S0_N_VIS,  S1_N_VIS,  S2_N_VIS, S3_N_VIS,   S4_N_VIS, S5_N_VIS,
     S6_N_VIS,  S7_N_VIS,  S8_N_VIS, S9_N_VIS,  S10_N_VIS, S11_N_VIS,
    S12_N_VIS, S13_N_VIS, S14_N_VIS, S15_N_VIS, S16_N_VIS,

    // Boot mode slave visibility parameters.
     S0_B_VIS,  S1_B_VIS,  S2_B_VIS,  S3_B_VIS,  S4_B_VIS,  S5_B_VIS,
     S6_B_VIS,  S7_B_VIS,  S8_B_VIS,  S9_B_VIS, S10_B_VIS, S11_B_VIS,
    S12_B_VIS, S13_B_VIS, S14_B_VIS, S15_B_VIS, S16_B_VIS,

    MAX_RCA_ID_M,             // Max active read transactions per ID.
    MAX_URIDA_M,              // Num of unique ID's that may be active.
    LOG2_MAX_RCA_ID_P1_M,     // Log base 2 of MAX_RCA_ID_M + 1.
    LOG2_MAX_URIDA_M,          // Log base 2 of MAX_URIDA_M   
    ACT_RIDS_W,               // Width of active read IDs bus.
    ACT_RSNUMS_W,             // Width of active slave numbers bus.
    ACT_RCOUNT_W,             // Width of active read count per ID bus.

    AR_SHARED_LAYER_VIS,      // Is there an AR shared layer.

    // Source on shared or dedicated layer parameters.
     AR_SHARED_S0,  AR_SHARED_S1,  AR_SHARED_S2,  AR_SHARED_S3,
     AR_SHARED_S4,  AR_SHARED_S5,  AR_SHARED_S6,  AR_SHARED_S7,
     AR_SHARED_S8,  AR_SHARED_S9, AR_SHARED_S10, AR_SHARED_S11,
    AR_SHARED_S12, AR_SHARED_S13, AR_SHARED_S14, AR_SHARED_S15,
    AR_SHARED_S16,

    // Which sinks have shared to dedicted links, not required
    // for AR channel.
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,

    0,                        // Not a write address channel.
    ACT_ID_BUF_POINTER_WIDTH_AR,LOG2_ACT_ID_BUF_POINTER_WIDTH_AR
   )
  U_AR_DW_axi_mp_addrch (
    // Inputs - System.
    .aclk_i                      (aclk_i),
    .aresetn_i                   (aresetn_i),




    // Inputs - External Master.
    .valid_i                     (arvalid_i),
    .payload_i                   (arpayload_i),

    // Outputs - External Master.
    .ready_o                     (arready_o),

    // Inputs - Slave Ports, via internal reg slice.
    .ready_i                     (arready_mp),



    .aw_shrd_lyr_granted_s_bus_i ({NUM_VIS_SP{1'b0}}),
    .issued_wtx_shrd_sys_s_bus_i ({NUM_VIS_SP{1'b0}}),


    // Outputs - Slave Ports, via internal reg slice.
    .bus_valid_o                 (bus_arvalid_mp),
    .valid_o                     (arvalid_mp),
    .mask_valid_o                (armask_valid_mp),
    .shrd_ch_req_o               (ar_shrd_ch_req_mp),
    .payload_o                   (arpayload_mp),

    // Inputs - Pipeline stage.
    .id_rs_i                     (ar_id_irs_mux),
    .local_slv_rs_i              (ar_local_slv_irs_mux),

    // Inputs - Read Data Channel.
    .cpl_tx_i                    (rcpl_tx),
    .cpl_id_i                    (rcpl_id),
    // Outputs - Read Data Channel.
    // spyglass disable_block W287b
    // SMD: Output port to an instance is not connected
    // SJ: Intentionally left unconnected. Not an issue
    .act_snums_o                 (),
    // spyglass enable_block W287b
    
    // Output - region number.
    //.region_o                    (arregion_o),

    // Unused outputs.
    .act_ids_o                   (act_ids_ar_unconn),
   .act_ids_buffer               (act_ids_buffer_ar_unconn), // Read Adress Channel do not active id storage
// spyglass disable_block W287b
// SMD: Output port to an instance is not connected
// SJ: This is not an issue
   .no_act_id                    (),
// spyglass enable_block W287b
   .act_ids_rd_buffer_pointer    (act_ids_rd_buffer_pointer_ar_unconn),

    .issuedtx_slot_oh_o          (issuedtx_slot_oh_ar_unconn)
  );

  
  // Select masking feedback signals from the first pipeline stage in
  // the channel.
  assign ar_id_irs_mux = (`AXI_AR_TMO!=0)
                         ? ar_id_irs
                         : (`AXI_AR_PL_ARB==1)
                           ? ar_id_irs_arbpl
                           : {`ID_W{1'b0}};

  assign ar_local_slv_irs_mux = (`AXI_AR_TMO!=0)
                                ? ar_local_slv_irs
                                : (`AXI_AR_PL_ARB==1)
                                  ? ar_local_slv_irs_arbpl
                                  : {LOG2_NUM_VIS_SP{1'b0}};


  //--------------------------------------------------------------------
  // Internal register slice for AR channel.
  //--------------------------------------------------------------------
  DW_axi_irs
  
  #(`AXI_AR_TMO,          // Channel timing option.
    NUM_VIS_SP,           // Number of visible slave ports.
    `AXI_AR_PL_ARB,       // Is channel arbiter pipelined.
    `AXI_AR_PYLD_S_W,     // Channel payload width.
    LOG2_NUM_VIS_SP,      // Log base of num. visible slave ports.
    `ID_W,                // Master ID width.
    AR_IRS_DO_MASKING,    // Masking logic required.
    AR_PYLD_ID_RHS,       // Left hand bit index of ID in payload.
    AR_PYLD_ID_LHS,       // Right hand bit index of ID in payload.
    0,                    // Pass 1 for W channel.
    AR_SHARED_LAYER_VIS   // Shared layer signal(s) required ?
  )
  U_AR_DW_axi_irs (
    // Inputs - System.
    .aclk_i        (aclk_i),
    .aresetn_i     (aresetn_i),

    // Inputs - Payload source.
    .payload_i     (arpayload_mp),
    .bus_valid_i   (bus_arvalid_mp),
    .valid_i       (arvalid_mp),
    .mask_valid_i  (armask_valid_mp),
    .shrd_ch_req_i (ar_shrd_ch_req_mp),

    // Outputs - Payload source.
    .ready_o       (arready_mp),

    // Inputs - Payload destination.
    .ready_i       (arready_irs),

    // Outputs - MP address channel.
    .id_o          (ar_id_irs),
    .local_slv_o   (ar_local_slv_irs),

    // Outputs - Payload destination.
    .bus_valid_o   (bus_arvalid_irs),
    .shrd_ch_req_o (ar_shrd_ch_req_irs),
    .payload_o     (arpayload_irs)
  );



  //--------------------------------------------------------------------
  // Pipelined arbiter register slice for AR channel.
  //--------------------------------------------------------------------
  DW_axi_irs_arbpl
  
  #(`AXI_AR_PL_ARB,           // Is channel arbiter pipelined.
    NUM_VIS_SP,               // Number of visible slave ports.
    `AXI_AR_PYLD_S_W,         // Channel payload width.
    LOG2_NUM_VIS_SP,          // Log base of num. visible slave ports.
    `ID_W,                    // Master ID width.
    AR_IRS_ARB_PL_DO_MASKING, // Masking logic required.
    AR_PYLD_ID_RHS,           // Left hand bit index of ID in payload.
    AR_PYLD_ID_LHS,           // Right hand bit index of ID in payload.
    0,                        // Pass 1 for W channel.
    AR_SHARED_LAYER_VIS       // Shared layer signal(s) required ?
  )
  U_AR_DW_axi_irs_arbpl (
    // Inputs - System.
    .aclk_i                   (aclk_i),
    .aresetn_i                (aresetn_i),

    // Inputs - Payload source.
    .bus_valid_i              (bus_arvalid_irs),
    .shrd_ch_req_i            (ar_shrd_ch_req_irs),
    .payload_i                (arpayload_irs),
    .mask_valid_i             (armask_valid_mp),
    .issued_wtx_shrd_mst_oh_i (1'b0),

    // Outputs - Payload source.
    .ready_o                  (arready_irs),

    // Inputs - Payload destination.
    .bus_ready_i              (bus_arready_i),

    // Outputs - MP address channel.
    .id_o                     (ar_id_irs_arbpl),
    .local_slv_o              (ar_local_slv_irs_arbpl),

    // Outputs - Payload destination.
    .bus_valid_o              (bus_arvalid_o),
    .shrd_ch_req_o            (ar_shrd_ch_req_o),
    .payload_o                (arpayload_o),
    .payload_prereg_o         (arpayload_prereg),

    // Unconnected outputs.
    .bus_valid_r_o            (ar_bus_valid_r),
    .issued_wtx_shrd_mst_oh_o (ar_issued_wtx_shrd_mst_oh_o)
  );


  // Remove this block if the shared layer is performing all channel
  // sink functions for this master on the R channel.
  generate
    if(REMOVE_R == 0) begin : gen_r_drespch
      //----------------------------------------------------------------
      // Read Data Channel Block.
      //----------------------------------------------------------------
      DW_axi_mp_drespch
      
      #(ICM_PORT,
        R_NVS,               // Number of visible slave ports.
        R_NVS_LOG2,          //
        R_NVS_P1_LOG2,       //
        `AXI_R_PL_ARB,       // Pipeline channel arbiter outputs.
        R_MCA_EN,            // Has multi-cycle arbitration ?
        R_MCA_NC,            // Num. cycles in multi-cycle arbitration.
        R_MCA_NC_W,          // Log base 2 of R_MCA_NC.
        ARB_TYPE_R,          // Arbitration type.
        BUS_R_PYLD_S_W,      // Width of bus with payloads from all
                             // visible slaves.
        `LCL_R_M_PYLD_W,     // Payload width to master.
        `LCL_R_S_PYLD_W,     // Single payload width from slave port.
        R_BUS_PRIORITY_W,    // Width of bus with all visible slave
                             // priorities.
        MAX_URIDA_M,         // Max unique values of ID with outstanding
                             // transactions.
        LOG2_MAX_URIDA_M,    // Log base 2 of MAX_URIDA_M.
        ACT_RSNUMS_W,        // Width of active slave numbers bus.
        `AXI_R_CH,           // Block is being used in a read data
                             // channel here.
        RI_LIMIT             // Limit read interleaving depth ?
       )
      U_R_DW_axi_mp_drespch (
        // Inputs - System.
        .aclk_i                  (aclk_i),
        .aresetn_i               (aresetn_i),

        .bus_slv_priorities_i    (r_bus_slv_priorities_i),

        // Inputs - External Master.
        .ready_i                 (rready_i),

        // Outputs - External Master.
        .valid_o                 (rvalid_o),
        .payload_o               (rpayload_o),

        // Inputs - Slave Ports.
        .bus_valid_i             (bus_rvalid_i),
        .bus_payload_i           (bus_rpayload_i),

        // Outputs - Slave Ports.
        .bus_ready_o             (bus_rready_o),

        // Inputs - Address channel.
        //.act_snums_i             (act_rsnums),

        // Outputs - Read address channel.
        .cpl_tx_o                (rcpl_tx_lcl),
        .cpl_id_o                (rcpl_id_lcl),

        // Inputs - unconnected.
        .bus_ready_shrd_i        (1'b0),
        .bus_valid_shrd_i        ({R_NVS{1'b0}}),

        // Outputs - unconnected.
        .bus_valid_shrd_o        (r_bus_valid_shrd_o_unconn),
        .payload_icm_o           (r_payload_icm_o_unconn),
        .cpl_tx_shrd_bus_o       (r_cpl_tx_shrd_bus_o_unconn)
      );
    end
    else begin : assign_default_1 // VP:: Lint error
    assign rvalid_o     = 1'b0;
    assign rpayload_o   = {`LCL_R_M_PYLD_W{1'b0}};
    assign bus_rready_o = {R_NVS{1'b0}};
    end   
  endgenerate


  // Select between local and shared channel write t/x completion
  // signals.
  assign wcpl_tx = REMOVE_B ? wcpl_tx_shrd_i : wcpl_tx_lcl;
  assign wcpl_id = REMOVE_B ? wcpl_id_shrd_i : wcpl_id_lcl;

  //--------------------------------------------------------------------
  // Write Address Channel Block.
  //--------------------------------------------------------------------
  DW_axi_mp_addrch
  
  #(MS_NUM,                   // Master port system number.
    ICM_PORT,                 // Interconnecting master port.
    NUM_VIS_SP,               // Number of visible slave ports.
    LOG2_NUM_VIS_SP,          // Log 2 of number of visible slave ports.
    `AXI_AW_TMO,              // AW channel timing option.
    `AXI_AW_PL_ARB,           // Is channel arbiter pipelined.
    `AXI_AW_PYLD_M_W,         // AW channel payload width from master.
    `AXI_AW_PYLD_S_W,         // AW channel payload width to slave.

    // Normal mode slave visibility parameters.
     S0_N_VIS,  S1_N_VIS,  S2_N_VIS, S3_N_VIS,   S4_N_VIS, S5_N_VIS,
     S6_N_VIS,  S7_N_VIS,  S8_N_VIS, S9_N_VIS,  S10_N_VIS, S11_N_VIS,
    S12_N_VIS, S13_N_VIS, S14_N_VIS, S15_N_VIS, S16_N_VIS,

    // Boot mode slave visibility parameters.
     S0_B_VIS,  S1_B_VIS,  S2_B_VIS,  S3_B_VIS,  S4_B_VIS,  S5_B_VIS,
     S6_B_VIS,  S7_B_VIS,  S8_B_VIS,  S9_B_VIS, S10_B_VIS, S11_B_VIS,
    S12_B_VIS, S13_B_VIS, S14_B_VIS, S15_B_VIS, S16_B_VIS,

    MAX_WCA_ID_M,             // Max active write transactions per ID.
    MAX_UWIDA_M,              // Number of unique ID's that may be active.
    LOG2_MAX_WCA_ID_P1_M,     // Log base 2 of MAX_WCA_ID_M.
    LOG2_MAX_UWIDA_M,          // Log base 2 of MAX_UWIDA_M   
    ACT_WIDS_W,               // Width of active write IDs bus.
    ACT_WSNUMS_W,             // Width of active slave numbers bus.
    ACT_WCOUNT_W,             // Width of active write count per ID bus.

    AW_SHARED_LAYER_VIS,      // Is there an AW shared layer.

    // Source on shared or dedicated layer parameters.
     AW_SHARED_S0,  AW_SHARED_S1,  AW_SHARED_S2,  AW_SHARED_S3,
     AW_SHARED_S4,  AW_SHARED_S5,  AW_SHARED_S6,  AW_SHARED_S7,
     AW_SHARED_S8,  AW_SHARED_S9, AW_SHARED_S10, AW_SHARED_S11,
    AW_SHARED_S12, AW_SHARED_S13, AW_SHARED_S14, AW_SHARED_S15,
    AW_SHARED_S16,

    // Which sinks have shared to dedicted links.
     AW_SHRD_DDCTD_S0,  AW_SHRD_DDCTD_S1,  AW_SHRD_DDCTD_S2,
     AW_SHRD_DDCTD_S3,  AW_SHRD_DDCTD_S4,  AW_SHRD_DDCTD_S5,
     AW_SHRD_DDCTD_S6,  AW_SHRD_DDCTD_S7,  AW_SHRD_DDCTD_S8,
     AW_SHRD_DDCTD_S9, AW_SHRD_DDCTD_S10, AW_SHRD_DDCTD_S11,
    AW_SHRD_DDCTD_S12, AW_SHRD_DDCTD_S13, AW_SHRD_DDCTD_S14,
    AW_SHRD_DDCTD_S15, AW_SHRD_DDCTD_S16,

    1,                         // This is a write address channel.
    ACT_ID_BUF_POINTER_WIDTH_AW,LOG2_ACT_ID_BUF_POINTER_WIDTH_AW
   )
  U_AW_DW_axi_mp_addrch (
    // Inputs - System.
    .aclk_i                      (aclk_i),
    .aresetn_i                   (aresetn_i),




    // Inputs - External Master.
    .valid_i                     (awvalid_i),
    .payload_i                   (awpayload_i),

    // Outputs - External Master.
    .ready_o                     (awready_o),

    // Inputs - Slave Ports, via internal reg slice.
    .ready_i                     (awready_mp),


    .aw_shrd_lyr_granted_s_bus_i (aw_shrd_lyr_granted_s_bus_i),
    .issued_wtx_shrd_sys_s_bus_i (issued_wtx_shrd_sys_s_bus_i),

    // Outputs - Slave Ports, via internal reg slice.
    .bus_valid_o                 (bus_awvalid_mp),
    .valid_o                     (awvalid_mp),
    .mask_valid_o                (awmask_valid_mp),
    .shrd_ch_req_o               (aw_shrd_ch_req_mp),
    .payload_o                   (awpayload_mp),

    // Inputs - Pipeline stage.
    .id_rs_i                     (aw_id_irs_mux),
    .local_slv_rs_i              (aw_local_slv_irs_mux),


    // Inputs - Burst Response Channel.
    .cpl_tx_i                    (wcpl_tx),
    .cpl_id_i                    (wcpl_id),

    // Outputs - Write Data Channel.
    .act_ids_o                   (act_wids),
    .act_snums_o                 (act_wsnums),
     // Output - region output.
    //.region_o                    (awregion_o),
      .act_ids_buffer            (act_ids_buffer),
      .no_act_id                 (no_act_id),
      .act_ids_rd_buffer_pointer (act_ids_rd_buffer_pointer),
    .issuedtx_slot_oh_o          (issuedtx_slot_oh)

  );

  // Select masking feedback signals from the first pipeline stage in
  // the channel.
  assign aw_id_irs_mux = (`AXI_AW_TMO!=0)
                         ? aw_id_irs
                         : (`AXI_AW_PL_ARB==1)
                           ? aw_id_irs_arbpl
                           : {`ID_W{1'b0}};

  assign aw_local_slv_irs_mux = (`AXI_AW_TMO!=0)
                                ? aw_local_slv_irs
                                : (`AXI_AW_PL_ARB==1)
                                  ? aw_local_slv_irs_arbpl
                                  : {LOG2_NUM_VIS_SP{1'b0}};

  //--------------------------------------------------------------------
  // Internal register slice for AW channel.
  //--------------------------------------------------------------------
  DW_axi_irs
  
  #(`AXI_AW_TMO,          // Channel timing option.
    NUM_VIS_SP,           // Number of visible slave ports.
    `AXI_AW_PL_ARB,       // Is channel arbiter pipelined.
    `AXI_AW_PYLD_S_W,     // Channel payload width.
    LOG2_NUM_VIS_SP,      // Log base of num. visible slave ports.
    `ID_W,                // Master ID width.
    AW_IRS_DO_MASKING,    // Masking logic required.
    AW_PYLD_ID_RHS,       // Left hand bit index of ID in payload.
    AW_PYLD_ID_LHS,       // Right hand bit index of ID in payload.
    0,                    // Pass 1 for W channel.
    AW_SHARED_LAYER_VIS   // Shared layer signal(s) required ?
  )
  U_AW_DW_axi_irs (
    // Inputs - System.
    .aclk_i        (aclk_i),
    .aresetn_i     (aresetn_i),

    // Inputs - Payload source.
    .payload_i     (awpayload_mp),
    .bus_valid_i   (bus_awvalid_mp),
    .valid_i       (awvalid_mp),
    .mask_valid_i  (awmask_valid_mp),
    .shrd_ch_req_i (aw_shrd_ch_req_mp),

    // Outputs - Payload source.
    .ready_o       (awready_mp),

    // Inputs - Payload destination.
    .ready_i       (awready_irs),

    // Outputs - MP address channel.
    .id_o          (aw_id_irs),
    .local_slv_o   (aw_local_slv_irs),

    // Outputs - Payload destination.
    .bus_valid_o   (bus_awvalid_irs),
    .shrd_ch_req_o (aw_shrd_ch_req_irs),
    .payload_o     (awpayload_irs)
  );


  //--------------------------------------------------------------------
  // Pipelined arbiter register slice for AW channel.
  //--------------------------------------------------------------------
  DW_axi_irs_arbpl
  
  #(`AXI_AW_PL_ARB,           // Is channel arbiter pipelined.
    NUM_VIS_SP,               // Number of visible slave ports.
    `AXI_AW_PYLD_S_W,         // Channel payload width.
    LOG2_NUM_VIS_SP,          // Log base of num. visible slave ports.
    `ID_W,                    // Master ID width.
    AW_IRS_ARB_PL_DO_MASKING, // Masking logic required.
    AW_PYLD_ID_RHS,           // Left hand bit index of ID in payload.
    AW_PYLD_ID_LHS,           // Right hand bit index of ID in payload.
    0,                        // Pass 1 for W channel.
    AW_SHARED_LAYER_VIS       // Shared layer signal(s) required ?
  )
  U_AW_DW_axi_irs_arbpl (
    // Inputs - System.
    .aclk_i              (aclk_i),
    .aresetn_i           (aresetn_i),

    // Inputs - Payload source.
    .bus_valid_i              (bus_awvalid_irs),
    .shrd_ch_req_i            (aw_shrd_ch_req_irs),
    .payload_i                (awpayload_irs),
    .mask_valid_i             (awmask_valid_mp),
    .issued_wtx_shrd_mst_oh_i (1'b0),

    // Outputs - Payload source.
    .ready_o                  (awready_irs),

    // Inputs - Payload destination.
    .bus_ready_i              (bus_awready_i),

    // Outputs - MP address channel.
    .id_o                     (aw_id_irs_arbpl),
    .local_slv_o              (aw_local_slv_irs_arbpl),

    // Outputs - Payload destination.
    .bus_valid_o              (bus_awvalid_irs_arbpl),
    .shrd_ch_req_o            (aw_shrd_ch_req_irs_arbpl),
    .payload_o                (awpayload_o),
    .payload_prereg_o         (awpayload_prereg),

    // Unconnected outputs.
    .bus_valid_r_o            (aw_bus_valid_r),
    .issued_wtx_shrd_mst_oh_o (aw_issued_wtx_shrd_mst_oh_o)
  );


  /*--------------------------------------------------------------------
   * Multi tile write deadlock prevention.
   */
  DW_axi_aw_mtile_dlock
  
  #( .NUM_VIS_SP(NUM_VIS_SP)
    ,.PYLD_W(`AXI_W_PYLD_S_W)
    ,.AW_PL_ARB(`AXI_AW_PL_ARB)
    ,.W_PL_ARB(`AXI_W_PL_ARB)
    ,.MAX_UIDA(MAX_UWIDA_M)
    ,.MAX_WCA(MAX_WCA_ID_M)
    ,.VIS_S0(S0_VIS)
    ,.VIS_S1(S1_VIS)
    ,.VIS_S2(S2_VIS)
    ,.VIS_S3(S3_VIS)
    ,.VIS_S4(S4_VIS)
    ,.VIS_S5(S5_VIS)
    ,.VIS_S6(S6_VIS)
    ,.VIS_S7(S7_VIS)
    ,.VIS_S8(S8_VIS)
    ,.VIS_S9(S9_VIS)
    ,.VIS_S10(S10_VIS)
    ,.VIS_S11(S11_VIS)
    ,.VIS_S12(S12_VIS)
    ,.VIS_S13(S13_VIS)
    ,.VIS_S14(S14_VIS)
    ,.VIS_S15(S15_VIS)
    ,.VIS_S16(S16_VIS)
  )
  U_DW_axi_aw_mtile_dlock (
    // Inputs
    .aclk_i         (aclk_i),
    .aresetn_i      (aresetn_i),
    .bus_valid_i    (bus_awvalid_irs_arbpl),
    .shrd_ch_req_i  (aw_shrd_ch_req_irs_arbpl),
    .bus_ready_i    (bus_awready_i),
    .bus_wready_i   (bus_wready_i),
    .bus_wvalid_i   (bus_wvalid_o),
    .bus_wvalid_r_i (w_bus_valid_r),
    .wlast_i        (wpayload_o[`AXI_WPYLD_LAST]),
    // Outputs
    .bus_valid_o    (bus_awvalid_o),
    .shrd_ch_req_o  (aw_shrd_ch_req_o)
  );


  //--------------------------------------------------------------------
  // Write Data Channel Block.
  //--------------------------------------------------------------------
  DW_axi_mp_wdatach
  
  #(MS_NUM,                  // Master port system number.
    ICM_PORT,                // Interconnecting master port.
    NUM_VIS_SP,              // Number of visible slave ports.
    LOG2_NUM_VIS_SP,         // Log 2 of number of visible slave ports.
    `AXI_W_TMO,              // W channel timing option.
    `AXI_W_PL_ARB,           // Is channel arbiter pipelined.
    `AXI_W_PYLD_M_W,         // W channel payload width from master.
    `AXI_W_PYLD_S_W,         // W channel payload width to slave.
    ACT_WIDS_W,              // Width of active write IDs bus.
    ACT_WSNUMS_W,            // Width of active slave numbers bus.
    ACT_WCOUNT_W,            // Width of active write count per ID bus.
    MAX_UWIDA_M,             // Num of unique ID's active at any time.
    LOG2_MAX_UWIDA_M,        // Log base 2 of MAX_UWIDA_M   

    MAX_WCA_ID_M,            // max number of active
                             // transactions per unique ID.
    LOG2_MAX_WCA_ID_P1_M,    // Log base 2 of max number of active
                             // transactions per unique ID.
      
    // Normal mode slave visibility parameters.
     S0_N_VIS,  S1_N_VIS,  S2_N_VIS, S3_N_VIS,   S4_N_VIS, S5_N_VIS,
     S6_N_VIS,  S7_N_VIS,  S8_N_VIS, S9_N_VIS,  S10_N_VIS, S11_N_VIS,
    S12_N_VIS, S13_N_VIS, S14_N_VIS, S15_N_VIS, S16_N_VIS,

    // Boot mode slave visibility parameters.
     S0_B_VIS,  S1_B_VIS,  S2_B_VIS,  S3_B_VIS,  S4_B_VIS,  S5_B_VIS,
     S6_B_VIS,  S7_B_VIS,  S8_B_VIS,  S9_B_VIS, S10_B_VIS, S11_B_VIS,
    S12_B_VIS, S13_B_VIS, S14_B_VIS, S15_B_VIS, S16_B_VIS,

    W_SHARED_LAYER_VIS,      // Is there a W shared layer.

    // Source on shared or dedicated layer parameters.
     W_SHARED_S0,  W_SHARED_S1,  W_SHARED_S2,  W_SHARED_S3,
     W_SHARED_S4,  W_SHARED_S5,  W_SHARED_S6,  W_SHARED_S7,
     W_SHARED_S8,  W_SHARED_S9, W_SHARED_S10, W_SHARED_S11,
    W_SHARED_S12, W_SHARED_S13, W_SHARED_S14, W_SHARED_S15,
    W_SHARED_S16,
    ACT_ID_BUF_POINTER_WIDTH_AW,LOG2_ACT_ID_BUF_POINTER_WIDTH_AW
   )
  U_W_DW_axi_mp_wdatach (
    // Inputs - System.
    .aclk_i              (aclk_i),
    .aresetn_i           (aresetn_i),

    // Inputs - External Master.
    .valid_i             (wvalid_i),
    .payload_i           (wpayload_i),

    // Outputs - External Master.
    .ready_o             (wready_o),
    .act_ids_buffer_pointer    (act_ids_rd_buffer_pointer),

    // Inputs - Slave Ports, via internal reg slice.
    .ready_i             (wready_mp),

    // Outputs - Slave Ports, via internal reg slice.
    .bus_valid_o         (bus_wvalid_mp),
    .valid_o             (wvalid_mp),
    .mask_valid_o        (wmask_valid_mp),
    .shrd_ch_req_o       (w_shrd_ch_req_mp),
    .payload_o           (wpayload_mp),

    // Inputs - Pipeline stage.
    .id_rs_i             (w_id_irs_mux),
     .act_ids_buffer            (act_ids_buffer),
     .no_act_id                 (no_act_id),

    // Inputs  - Write Address Channel.
    .act_ids_i           (act_wids),
    .act_snums_i         (act_wsnums),
    .issuedtx_slot_oh_i  (issuedtx_slot_oh)
  );

  // Select masking feedback signals from the first pipeline stage in
  // the channel.
  assign w_id_irs_mux = (`AXI_W_TMO!=0)
                        ? w_id_irs
                        : (`AXI_W_PL_ARB==1)
                          ? w_id_irs_arbpl
                          : {`ID_W{1'b0}};

  //--------------------------------------------------------------------
  // Internal register slice for W channel.
  //--------------------------------------------------------------------
  DW_axi_irs
  
  #(`AXI_W_TMO,          // Channel timing option.
    NUM_VIS_SP,          // Number of visible slave ports.
    `AXI_W_PL_ARB,       // Is channel arbiter pipelined.
    `AXI_W_PYLD_S_W,     // Channel payload width.
    LOG2_NUM_VIS_SP,     // Log base of num. visible slave ports.
    `ID_W,               // Master ID width.
    W_IRS_DO_MASKING,    // Masking logic required.
    W_PYLD_ID_RHS,       // Left hand bit index of ID in payload.
    W_PYLD_ID_LHS,       // Right hand bit index of ID in payload.
    1,                   // Pass 1 for W channel.
    W_SHARED_LAYER_VIS   // Shared layer signal(s) required ?
  )
  U_W_DW_axi_irs (
    // Inputs - System.
    .aclk_i        (aclk_i),
    .aresetn_i     (aresetn_i),

    // Inputs - Payload source.
    .payload_i     (wpayload_mp),
    .bus_valid_i   (bus_wvalid_mp),
    .valid_i       (wvalid_mp),
    .mask_valid_i  (wmask_valid_mp),
    .shrd_ch_req_i (w_shrd_ch_req_mp),

    // Outputs - Payload source.
    .ready_o       (wready_mp),

    // Inputs - Payload destination.
    .ready_i       (wready_irs),

    // Outputs - MP address channel.
    .id_o          (w_id_irs),
    .local_slv_o   (w_local_slv_irs_uncon),

    // Outputs - Payload destination.
    .bus_valid_o   (bus_wvalid_irs),
    .shrd_ch_req_o (w_shrd_ch_req_irs),
    .payload_o     (wpayload_irs)
  );

  //--------------------------------------------------------------------
  // Pipelined arbiter register slice for W channel.
  //--------------------------------------------------------------------
  DW_axi_irs_arbpl
  
  #(`AXI_W_PL_ARB,           // Is channel arbiter pipelined ?
    NUM_VIS_SP,              // Number of visible slave ports.
    `AXI_W_PYLD_S_W,         // Channel payload width.
    LOG2_NUM_VIS_SP,         // Log base of num. visible slave ports.
    `ID_W,                   // Master ID width.
    W_IRS_ARB_PL_DO_MASKING, // Masking logic required.
    W_PYLD_ID_RHS,           // Left hand bit index of ID in payload.
    W_PYLD_ID_LHS,           // Right hand bit index of ID in payload.
    1,                       // Pass 1 for W channel.
    W_SHARED_LAYER_VIS       // Shared layer signal(s) required ?
  )
  U_W_DW_axi_irs_arbpl (
    // Inputs - System.
    .aclk_i                   (aclk_i),
    .aresetn_i                (aresetn_i),

    // Inputs - Payload source.
    .payload_i                (wpayload_irs),
    .bus_valid_i              (bus_wvalid_irs),
    .mask_valid_i             (wmask_valid_mp),
    .shrd_ch_req_i            (w_shrd_ch_req_irs),
    .issued_wtx_shrd_mst_oh_i (1'b0),

    // Outputs - Payload source.
    .ready_o                  (wready_irs),

    // Inputs - Payload destination.
    .bus_ready_i              (bus_wready_i),

    // Outputs - MP address channel.
    .id_o                     (w_id_irs_arbpl),
    .local_slv_o              (w_local_slv_irs_arbpl_uncon),

    // Outputs - Payload destination.
    .bus_valid_o              (bus_wvalid_o),
    .bus_valid_r_o            (w_bus_valid_r),
    .payload_o                (wpayload_o),
    .shrd_ch_req_o            (w_shrd_ch_req_o),

    // Unconnected outputs.
    .payload_prereg_o         (wpayload_prereg_unconn),
    .issued_wtx_shrd_mst_oh_o (w_issued_wtx_shrd_mst_oh_o)
  );


  // Remove this block if the shared layer is performing all channel
  // sink functions for this master on the B channel.
  generate
    if(REMOVE_B == 0) begin : gen_b_drespch
      //----------------------------------------------------------------
      // Burst Response Channel Block.
      //----------------------------------------------------------------
      DW_axi_mp_drespch
      
      #(ICM_PORT,            // Interconnecting master port.
        B_NVS,               // Number of visible slave ports.
        B_NVS_LOG2,          //
        B_NVS_P1_LOG2,       //
        `AXI_B_PL_ARB,       // Pipeline channel arbiter outputs.
        B_MCA_EN,            // Has multi-cycle arbitration ?
        B_MCA_NC,            // Num. cycles in multi-cycle arbitration.
        B_MCA_NC_W,          // Log base 2 of B_MCA_NC.
        ARB_TYPE_B,          // Arbitration type.
        BUS_B_PYLD_S_W,      // Width of bus with payloads from all
                             // visible slaves.
        `LCL_B_M_PYLD_W,     // Payload width to master.
        `LCL_B_S_PYLD_W,     // Single payload width from slave port.
        B_BUS_PRIORITY_W,    // Width of bus with all visible slave
                             // priorities.
        MAX_UWIDA_M,         // Max unique values of ID with outstanding
                             // transactions.
        LOG2_MAX_UWIDA_M,    // Log base 2 of MAX_UWIDA_M.
        ACT_WSNUMS_W,        // Width of active slave numbers bus.
        `AXI_NOT_R_CH        // Block is not being used in a read data
                             // channel here.
       )
      U_B_DW_axi_mp_drespch (
        // Inputs - System.
        .aclk_i                  (aclk_i),
        .aresetn_i               (aresetn_i),

        .bus_slv_priorities_i    (b_bus_slv_priorities_i),

        // Inputs - External Master.
        .ready_i                 (bready_i),

        // Outputs - External Master.
        .valid_o                 (bvalid_o),
        .payload_o               (bpayload_o),

        // Inputs - Slave Ports.
        .bus_valid_i             (bus_bvalid_i),
        .bus_payload_i           (bus_bpayload_i),

        // Outputs - Slave Ports.
        .bus_ready_o             (bus_bready_o),

        // Inputs - Address channel.
        //.act_snums_i             (act_wsnums),

        // Outputs - Write Address Channel.
        .cpl_tx_o                (wcpl_tx_lcl),
        .cpl_id_o                (wcpl_id_lcl),

        // Inputs - unconnected.
        .bus_ready_shrd_i        (1'b0),
        .bus_valid_shrd_i        ({B_NVS{1'b0}}),

        // Outputs - unconnected.
        .bus_valid_shrd_o        (b_bus_valid_shrd_o_unconn),
        .payload_icm_o           (b_payload_icm_o_unconn),
        .cpl_tx_shrd_bus_o       (b_cpl_tx_shrd_bus_o_unconn)
      );
    end
  else begin : assign_default_2 // VP:: Lint Error
  assign bvalid_o =1'b0;
  assign bpayload_o = {`LCL_B_M_PYLD_W{1'b0}};
  assign bus_bready_o ={B_NVS{1'b0}};
  end
  endgenerate




endmodule

`undef LCL_R_M_PYLD_W
`undef LCL_R_S_PYLD_W
`undef LCL_B_M_PYLD_W
`undef LCL_B_S_PYLD_W

