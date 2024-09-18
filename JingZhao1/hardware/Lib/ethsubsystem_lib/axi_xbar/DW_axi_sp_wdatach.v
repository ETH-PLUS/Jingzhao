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
// File Version     :        $Revision: #11 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_sp_wdatach.v#11 $ 
**
** ---------------------------------------------------------------------
**
** File     : DW_axi_sp_wdatach.v
//
//
** Created  : Tue May 24 17:09:09 MEST 2005
** Modified : $Date: 2020/03/22 $
** Abstract : This block implements the slave port write data channel.
**
** ---------------------------------------------------------------------
*/

module DW_axi_sp_wdatach (
  // Inputs - System.
  aclk_i,
  aresetn_i,
  bus_mst_priorities_i,
    
  // Inputs - External Slave.
  ready_i,
  bus_ready_shrd_i,
    
  // Outputs - External Slave.
  valid_o,
  bus_valid_shrd_o,
  payload_o,
    
  // Inputs - Master Ports.
  bus_valid_i,
  bus_valid_shrd_i,
  bus_payload_i,
  w_layer_s_m_bus_i,
    
  // Outputs - Master Ports.
  bus_ready_o,
    
  // Inputs - Write Address Channel.
  issued_tx_i,
  issued_mstnum_i,
  issued_tx_mst_oh_i,
  issued_tx_shrd_ddctd_mst_oh_i,
  
  // Inputs - Shared AW channel.
  issued_tx_shrd_i,
  issued_tx_shrd_slv_oh_i,
  issued_tx_shrd_mst_oh_i,

  // Inputs - From Dedicated W Channels.
  shrd_w_nxt_fb_pend_bus_i,

  // Outputs - Shared W channel.
  shrd_w_nxt_fb_pend_o
);

   
//----------------------------------------------------------------------
// MODULE PARAMETERS.
//----------------------------------------------------------------------
  parameter NUM_CON_MP = 16; // Number of connected master ports.
                             // i.e. num connected through dedicated
                             // channel if this is a dedicated channel
                             // instance, or num connected through
                             // shared channel if this is a shared
                             // instance.

  parameter LOG2_NUM_CON_MP = 4; // Log base 2 of number of connected
                                 // master ports.

  parameter LOG2_NUM_CON_MP_P1 = 4; // Log base 2 of (number of connected
                                    // master ports + 1).

  parameter NUM_VIS_MP = 16; // Number of visible master ports.

  parameter LOG2_NUM_VIS_MP = 4; // Log 2 of NUM_VIS_MP.

  parameter AW_NUM_VIS_MP = 4; // Num masters visible to AW dedicated 
                               // channel.

  parameter PL_ARB = 0; // 1 to pipeline arbiter outputs.

  parameter MCA_EN = 0; // Enable multi cycle arbitration.

  parameter MCA_NC = 0; // Number of arb. cycles in multi cycle arb.

  parameter MCA_NC_W = 1; // Log base 2 of MCA_NC + 1.

  parameter ARB_TYPE = 0; // Arbitration type.

  // Width of bus containing payloads from all visible master ports.
  parameter BUS_PYLD_M_W = (2*`AXI_W_PYLD_M_W); 

  parameter PYLD_S_W = `AXI_W_PYLD_M_W; // Payload width to slave. 

  parameter MAX_FAC = 4; // Max. number of active write commands.

  parameter LOG2_MAX_FAC = 2; // Log base 2 of MAX_FAC.

  parameter WID = 2; // Write interleaving depth.

  parameter LOG2_WID = 1; // Log base 2 of WID.

  parameter LOG2_WID_P1 = 2; // Log base 2 of (WID + 1).

  parameter BUS_PRIORITY_W = 2; // Width of bus containing prioritys of 
                                // all visible masters.

  // Visibility of each master port to this slave port.                                
  parameter VIS_M0 = 0;
  parameter VIS_M1 = 0;
  parameter VIS_M2 = 0;
  parameter VIS_M3 = 0;
  parameter VIS_M4 = 0;
  parameter VIS_M5 = 0;
  parameter VIS_M6 = 0;
  parameter VIS_M7 = 0;
  parameter VIS_M8 = 0;
  parameter VIS_M9 = 0;
  parameter VIS_M10 = 0;
  parameter VIS_M11 = 0;
  parameter VIS_M12 = 0;
  parameter VIS_M13 = 0;
  parameter VIS_M14 = 0;
  parameter VIS_M15 = 0;

  // Which masters are connected here through shared layer 
  // on W channel ?
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
  

  // Which masters are connected here through shared layer 
  // on AW channel ?
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
  
  // Does AW channel to attached slave (dedicated) have a shared to
  // dedicated link.
  parameter HAS_AW_SHRD_DDCTD_LNK = 0; 

  // Does W channel to attached slave (dedicated) have a shared to
  // dedicated link.
  parameter HAS_W_SHRD_DDCTD_LNK = 0;

  /* -------------------------------------------------------------------                     
   * Shared Channel Parameters
   */
  // spyglass disable_block ReserveName
  // SMD: A reserve name has been used.
  // SJ: This parameter is local to this module. This is not passed to heirarchy below this module. hence, it will not cause any issue.
  parameter [0:0] SHARED = 0; // Shared write data channel block ?                     
  // spyglass enable_block ReserveName
  parameter NSS = 1; // Number of slaves on this shared channel.

  parameter SHARED_PL = 0; // Pipeline in shared channel ?

  parameter DDCT_AW_REMOVED = 0; // Tells a dedicated W channel that it
                                 // will now get AW t/x info from the 
                                 // shared channel.
  

  // Parameter for each shared slave, 1 if the slave also
  // has a dedicatd write data channel.
  parameter HAS_DDCTD_W_S0 = 1;
  parameter HAS_DDCTD_W_S1 = 1;
  parameter HAS_DDCTD_W_S2 = 1;
  parameter HAS_DDCTD_W_S3 = 1;
  parameter HAS_DDCTD_W_S4 = 1;
  parameter HAS_DDCTD_W_S5 = 1;
  parameter HAS_DDCTD_W_S6 = 1;
  parameter HAS_DDCTD_W_S7 = 1;
  parameter HAS_DDCTD_W_S8 = 1;
  parameter HAS_DDCTD_W_S9 = 1;
  parameter HAS_DDCTD_W_S10 = 1;
  parameter HAS_DDCTD_W_S11 = 1;
  parameter HAS_DDCTD_W_S12 = 1;
  parameter HAS_DDCTD_W_S13 = 1;
  parameter HAS_DDCTD_W_S14 = 1;
  parameter HAS_DDCTD_W_S15 = 1;
  parameter HAS_DDCTD_W_S16 = 1;


  // Every master will send a bus of valid signals, with 1 signal for
  // every attached slave (signals for slaves not visible to that master
  // are tied to 0 at the top level.
  localparam V_BUS_SHRD_W = NUM_CON_MP*NSS;
  
  // Decode if there is any connection with a dedicated address channel.
  localparam HAS_DDCTD_LNK 
    =   (HAS_DDCTD_W_S0 == 1)
      | ((HAS_DDCTD_W_S1 == 1) & (NSS >= 1))
      | ((HAS_DDCTD_W_S2 == 1) & (NSS >= 2))
      | ((HAS_DDCTD_W_S3 == 1) & (NSS >= 3))
      | ((HAS_DDCTD_W_S4 == 1) & (NSS >= 4))
      | ((HAS_DDCTD_W_S5 == 1) & (NSS >= 5))
      | ((HAS_DDCTD_W_S6 == 1) & (NSS >= 6))
      | ((HAS_DDCTD_W_S7 == 1) & (NSS >= 7))
      | ((HAS_DDCTD_W_S8 == 1) & (NSS >= 8))
      | ((HAS_DDCTD_W_S9 == 1) & (NSS >= 9))
      | ((HAS_DDCTD_W_S10 == 1) & (NSS >= 10))
      | ((HAS_DDCTD_W_S11 == 1) & (NSS >= 11))
      | ((HAS_DDCTD_W_S12 == 1) & (NSS >= 12))
      | ((HAS_DDCTD_W_S13 == 1) & (NSS >= 13))
      | ((HAS_DDCTD_W_S14 == 1) & (NSS >= 14))
      | ((HAS_DDCTD_W_S15 == 1) & (NSS >= 15))
      | ((HAS_DDCTD_W_S16 == 1) & (NSS >= 16));

  // Is the DW_axi_irs_arbpl required to perform PL_ARB register slicing
  // here ?
  localparam SHARED_ARB_PL_IRS = SHARED & HAS_DDCTD_LNK & PL_ARB;

//----------------------------------------------------------------------
// LOCAL MACROS.
//----------------------------------------------------------------------
  // SHARED == 0 : arbitrate per write data interleave.
  // SHARED == 1 : arbitrate per master.
  `define ARB_NC ((NUM_CON_MP==1) ? 1 : (SHARED ? NUM_CON_MP : WID))

  // Log base 2 of number of clients to the arbiter.
  `define ARB_LOG2_NC ((NUM_CON_MP==1) ? 1 : (SHARED ? LOG2_NUM_CON_MP : LOG2_WID))
  
  // Log base 2 of (number of clients to the arbiter + 1).
  `define ARB_LOG2_NC_P1 ((NUM_CON_MP==1) ? 1 : (SHARED ? LOG2_NUM_CON_MP_P1 : LOG2_WID_P1))

  // Width of priorities bus from the wrorder block, priorities for
  // 0 to WID-1.
  `define BUS_PRIORITY_WID_W (WID*`AXI_MST_PRIORITY_W)

  // Width of bus containing master numbers of masters which are
  // being allowed to access the arbiter.
  `define BUS_PORT_REQ_W (WID*LOG2_NUM_CON_MP)

  // Macro to tell the arbiter block not to use its own internal
  // grant index. This is because we don't do per master arbitration
  // in this block because of write interleaving.
  `define USE_INT_GRANT_INDEX 0

  `define REG_INTER_BLOCK_PATHS 0

  // Width of arbiter internal grant index.                                
  localparam ARB_INDEX_W = (ARB_TYPE==1) 
                           ? `ARB_LOG2_NC_P1 
                           : `ARB_LOG2_NC;

//----------------------------------------------------------------------
// PORT DECLARATIONS
//----------------------------------------------------------------------

  // Inputs - System.
  input aclk_i;    // AXI system clock.
  input aresetn_i; // AXI system reset.

  // Priorities from all visible masters.
  // If SHARED==0 and only one master port connected to this slave port this signal is not used
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input [BUS_PRIORITY_W-1:0] bus_mst_priorities_i;

  // Inputs - External Slave.
  input                  ready_i; // Dedicated.
  input [NSS-1:0]        bus_ready_shrd_i; // Shared.
  //spyglass enable_block W240

  // Outputs - External Slave.
  output                 valid_o;   // Dedicated.
  output [NSS-1:0]       bus_valid_shrd_o; // Shared. 
  reg    [NSS-1:0]       bus_valid_shrd_o; // 
  output [PYLD_S_W-1:0]  payload_o; // Payload vector to 
                                    // external slave.

  // Inputs - Master Ports.
  // Bus of 1 valid signal from each master.
  // SHARED == 0 , these are the valids for the single attached slave.
  // SHARED == 1 : these are requests to win ownership of this shared
  //               channel.
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input [NUM_CON_MP-1:0]   bus_valid_i;   

  // Bus of valid signal for each slave from each master, used when
  // SHARED == 1 only.
  input [V_BUS_SHRD_W-1:0] bus_valid_shrd_i;

  // Payload vectors from all visible master ports.
  input [BUS_PYLD_M_W-1:0] bus_payload_i; 
  
  // Bus of W_LAYER_Sx_Mx parameters, from each master attached to
  // the shared W channel, for each slave attached to the shared W
  // channel.
  // If SHARED==0 this signal is not used
  input [V_BUS_SHRD_W-1:0] w_layer_s_m_bus_i;
  //spyglass enable_block W240


  // Outputs - Master Ports.
  output [NUM_CON_MP-1:0]  bus_ready_o; // Ready to all visible master 
                                        // ports.

  // Inputs - Write Address Channel.
  // Asserted by write address channel when write command has been
  // issued. 
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input issued_tx_i; 
                  
  // Signifies the master number whos transaction has been issued 
  // with issued_tx_i.
  input [LOG2_NUM_VIS_MP-1:0] issued_mstnum_i; 

  // 1-bit per master, tx issued signal from dedicated AW channel.
  input [AW_NUM_VIS_MP-1:0] issued_tx_mst_oh_i;
  
  // Bit for each master asserted for the master that has ownership of
  // the dedicated AW channel. Decoded specificaly for the case when the
  // dedicated channel has a link from the shared layer.
  input [NUM_VIS_MP-1:0] issued_tx_shrd_ddctd_mst_oh_i;


  // Inputs - Shared AW channel.
  // T/x issued to this slave on shared AW.
  input issued_tx_shrd_i;

  // T/x issued to a slave on shared W. Bit for each shared slave.
  input [NSS-1:0] issued_tx_shrd_slv_oh_i;

  // One hot master number who issued t/x to this slave on shared AW.
  input [NUM_VIS_MP-1:0] issued_tx_shrd_mst_oh_i;

  // Inputs - From Dedicated W Channels.
  // Used by the shared write order block (when this is implementing a
  // shared W channel), to decode when the shared W channel can send
  // a first W beat to a dedicated W channel. To avoid deadlock, this 
  // is only done when the shared channel is next to send a first W 
  // beat to the slave (as dictated by that slaves dedicated W channel).
  input [NSS-1:0] shrd_w_nxt_fb_pend_bus_i;
  //spyglass enable_block W240

  // Outputs - Shared W channel.
  // Tells the shared W channel when it is next to send a first W beat
  // to this slave. Used to avoid a deadlock condition with the shared
  // to dedicated layer link.
  output shrd_w_nxt_fb_pend_o;

  //--------------------------------------------------------------------
  // INTERNAL SIGNALS
  //--------------------------------------------------------------------
  // depending on number of visible masters these signals are not used. Violation can be ignored
  reg [NUM_CON_MP-1:0] issued_tx_w_shrd_ddctd_oh_mapd;
  wire issued_tx_mux;    
  wire [LOG2_NUM_CON_MP-1:0] issued_mstnum_mux;
  wire [NSS-1:0] issued_tx_shrd_slv_oh_mux;
  reg [LOG2_NUM_CON_MP-1:0] issued_tx_w_shrd_ddctd_mapd;
  reg                       issued_tx_r;     // Registered versions of
  reg [LOG2_NUM_CON_MP-1:0] issued_mstnum_r; // input signals. For 
  reg [NSS-1:0] issued_tx_shrd_slv_oh_r;     //

  // issued_tx_shrd_slv_oh_r_i masked such that a bit for a slave will
  // only assert if the master accessing the slave links to it through 
  // the shared W channel.
  wire [NSS-1:0] issued_tx_shrd_slv_oh_msk; 

  // w_layer_s_m_bus_i multiplexed with issued_tx_shrd_mst_oh_i.
  wire [NSS-1:0] w_layer_s_m_bus_mux;

  // Request lines to arbiter from the wrorder block.
  wire [WID-1:0] req_wrorder; 
  
  // Priority values to the arbiter from the wrorder block.
  wire [`BUS_PRIORITY_WID_W-1:0] bus_priorities_wrorder;            

  // Bus containing master numbers who are allowed to request to the
  // arbiter.
  wire [`BUS_PORT_REQ_W-1:0] bus_mst_req_wrorder;
  reg [`BUS_PORT_REQ_W-1:0] bus_mst_req_wrorder_r; // Reg'd version.
  wire [`BUS_PORT_REQ_W-1:0] bus_mst_req_pla_mux; // Selected from above
                                                  // 2 depending on 
                                                  // pipelining.

  // If there is only single master port connected to this slave port, then arbiter is not used and hence this signal has no effect.
  wire [`ARB_NC-1:0] req_arb; // Selected from bus_valid_i[0]
                                       // or req_wrorder depending on
                                       // number of visible master
                                       // ports.

  reg [`ARB_NC-1:0] req_arb_r; // registered version of 
                                        // req_arb.
           
  wire [`ARB_NC-1:0] req_arb_mux; // Selected from req_arb
                                           // and req_arb_r depending
                                           // on PL_ARB.

  // Selected from 0 or bus_priorities_wrorder, depending on number of
  // visible master ports.
  wire [`BUS_PRIORITY_WID_W-1:0] bus_priorities_arb;            

  // Selected from 0 or bus_mst_req_wrorder, depending on number of
  // visible master ports.
  wire [`BUS_PORT_REQ_W-1:0] bus_mst_req_arb;

  wire grant; // Grant output from DW_axi_arb.

  // Arbiter grant index.
  wire [`ARB_LOG2_NC-1:0] arb_grant_index; 
  // Arbiter 1 hot grant output.
  wire [`ARB_NC-1:0] arb_bus_grant; 

  // Grant signals chosen from shared and dedicated versions.
  wire [LOG2_NUM_CON_MP-1:0] grant_index_m; 
  wire [NUM_CON_MP-1:0] bus_grant_m; 

  wire cpl_tx; // Asserted when write data part of write transaction
               // completes.

  wire tx_acc_s; // Asserted when when a transfer has been accepted by 
                 // the slave.
  
  // Granted requesting port selected using arbiters grant index.
  wire [LOG2_NUM_CON_MP-1:0] port_req_mux;      
  reg  [NUM_CON_MP-1:0]      bus_grant_port_req;

  // Binary version of issued_tx_shrd_mst_oh_i.
  reg [LOG2_NUM_VIS_MP-1:0] issued_tx_shrd_mst;

  // Asserted when the shared AW channel is granted at the dedicated
  // AW channel (shared -> dedicated link).
  wire shrd_aw_grnt_at_ddctd_aw;

  /*--------------------------------------------------------------------
   * Shared Channel Generation Signals
   */

  // Request lines to arbiter from the shared channel wrorder block.
  wire [NUM_CON_MP-1:0] req_shrd_wrorder; 

  // Selected from bus_valid_shrd_i and bus_valid_shrd_mux dependant
  // on PL_ARB parameter.
  wire [V_BUS_SHRD_W-1:0] bus_valid_shrd_mux; 

  // Register version of bus_valid_shrd;                            
  reg [V_BUS_SHRD_W-1:0] bus_valid_shrd_r; 

  // Selected from bus_valid_shrd_mux by grant_index_m.
  wire [NSS-1:0] bus_valid_shrd_grnt_mux; 

  // Bit for each attached slave, assert when wlast beat is accepted
  // at the slave.
  wire [NSS-1:0] cpl_tx_shrd_bus;

  // Selected from bus of ready signals of all slaves on the shared
  // channel.
  wire ready_shrd_mux; 

  wire ready_shrd_ddctd_mux; // Selected between ready_i and
                             // ready_shrd_mux depending on SHARED 
                             // parameter.

  //--------------------------------------------------------------------
  // Multi cycle arbitration signals.
  wire valid_granted_mca; // Valid selected from the valid inputs by
                          // the registered grant index for multi 
                          // cycle arbitration.
  
  // Wires for unconnected module outputs.
  wire id_irs_unconn;
  wire local_slv_irs_unconn;
  wire shrd_ch_req_irs_unconn;

  wire [NSS-1:0] irs_apl_bus_valid_r_unconn;
  wire irs_apl_id_unconn;
  wire irs_apl_local_slv_unconn;
  wire irs_apl_shrd_ch_req_unconn;
  wire [PYLD_S_W-1:0] irs_apl_payload_prereg_unconn;
  wire irs_apl_issued_wtx_shrd_mst_oh_unconn;


  // Wires to/from shared layer internal register slice.
  wire [PYLD_S_W-1:0] payload_pre_irs; // Payload to external slave,
                                       // prior to internal reg slice.

  wire [NSS-1:0] bus_valid_shrd_masked; // Shared valid signals.

  wire ready_irs; // Ready from the internal register slice.


  
  reg [NUM_VIS_MP-1:0] issued_tx_mst_combined_oh;
  reg [LOG2_NUM_VIS_MP-1:0] issued_tx_mst_combined;

  // AW_SHARED_S* and W_SHARED_S* parameters collected into wire busses.
  wire [`AXI_MAX_NUM_USR_MSTS-1:0] aw_shrd_param_bus;
  wire [`AXI_MAX_NUM_USR_MSTS-1:0] w_shrd_param_bus;

  // Shared layer parameters, remapped to be numbered by visible master
  // not system master.
  reg [NUM_VIS_MP-1:0] aw_shrd_param_bus_lcl;
  reg [NUM_VIS_MP-1:0] w_shrd_param_bus_lcl;

  // VIS_M* parameters collected into a bus.
  wire [`AXI_MAX_NUM_USR_MSTS-1:0] vis_bus;

  // Master number next to send first beat to this slave.
  wire [LOG2_NUM_CON_MP-1:0] firstpnd_mst_ddctd;
  // Is dedicated W order fifo empty ?
  wire fifo_empty_ddctd;
  // Pop signal from dedicated layer first pending master number fifo.
  wire firstpnd_fifo_pop_ddctd;


  /*--------------------------------------------------------------------
   * Wires to/from both *_irs_* modules.
   */
  // Payload from DW_axi_irs.
  wire [PYLD_S_W-1:0] payload_irs; 
  // Payload from DW_axi_irs_arbpl.
  wire [PYLD_S_W-1:0] payload_irs_arbpl; 

  // Bus of valid inputs per slave for DW_axi_irs_arbpl.
  reg [NSS-1:0] bus_valid_irs_arbpl_in;

  // Bus of valid outputs per slave from DW_axi_irs.
  wire [NSS-1:0] bus_valid_irs;
  // Bus of valid outputs per slave from DW_axi_irs_arbpl.
  wire [NSS-1:0] bus_valid_irs_arbpl;

  // Ready output from DW_axi_irs_arbpl.
  wire ready_irs_arbpl;
  // Registered version of ready_irs_arbpl;
  reg ready_irs_arbpl_r;

  // Ready in to DW_axi_irs block.
  wire ready_irs_in;
  
  // Ready in to DW_axi_irs_arbpl block.
  reg [NSS-1:0] bus_ready_irs_arbpl_in;

  // Max sized bus of all HAS_DDCTD_S* parameters.
  wire [`AXI_MAX_NUM_MST_SLVS-1:0] has_ddctd_s_bus_max;
  // Above sized for NSS.
  wire [NSS-1:0] has_ddctd_s_bus;

  // Asserted if any valid output of irs_arbpl is asserted.
  wire any_valid_irs_arbpl;
  // Registered version of above.
  reg any_valid_irs_arbpl_r;
  wire [(`ARB_NC*ARB_INDEX_W)-1:0] bus_priority_unconn;


  // VIS_M* parameters collected into a bus.
  assign vis_bus = 
    {(VIS_M15 ? 1'b1 : 1'b0),
     (VIS_M14 ? 1'b1 : 1'b0),
     (VIS_M13 ? 1'b1 : 1'b0),
     (VIS_M12 ? 1'b1 : 1'b0),
     (VIS_M11 ? 1'b1 : 1'b0),
     (VIS_M10 ? 1'b1 : 1'b0),
     (VIS_M9 ? 1'b1 : 1'b0),
     (VIS_M8 ? 1'b1 : 1'b0),
     (VIS_M7 ? 1'b1 : 1'b0),
     (VIS_M6 ? 1'b1 : 1'b0),
     (VIS_M5 ? 1'b1 : 1'b0),
     (VIS_M4 ? 1'b1 : 1'b0),
     (VIS_M3 ? 1'b1 : 1'b0),
     (VIS_M2 ? 1'b1 : 1'b0),
     (VIS_M1 ? 1'b1 : 1'b0),
     (VIS_M0 ? 1'b1 : 1'b0)
    };


  /*--------------------------------------------------------------------
   * When operating here as a dedicated W channel.
   *
   * When the AW channel tx_issued_* signals are coming from a 
   * dedicated AW channel, that also has a link with the shared AW 
   * channel, there are some special considerations we must make in
   * order to decode the master who issued the t/x.
   *
   * From the shared layer we have, issued_tx_shrd_mst_oh_i.
   * From the dedicated layer we have, issued_tx_shrd_ddctd_mst_oh_i.
   *
   * For each master visible here, we will use a bit of one of these
   * signals, depending on how they connect to the AW channel.
   */

  // Create a bus of the shared layer parameters on the AW channel.
  assign aw_shrd_param_bus = 
    {(AW_SHARED_M15 ? 1'b1 : 1'b0),
     (AW_SHARED_M14 ? 1'b1 : 1'b0),
     (AW_SHARED_M13 ? 1'b1 : 1'b0),
     (AW_SHARED_M12 ? 1'b1 : 1'b0),
     (AW_SHARED_M11 ? 1'b1 : 1'b0),
     (AW_SHARED_M10 ? 1'b1 : 1'b0),
     (AW_SHARED_M9 ? 1'b1 : 1'b0),
     (AW_SHARED_M8 ? 1'b1 : 1'b0),
     (AW_SHARED_M7 ? 1'b1 : 1'b0),
     (AW_SHARED_M6 ? 1'b1 : 1'b0),
     (AW_SHARED_M5 ? 1'b1 : 1'b0),
     (AW_SHARED_M4 ? 1'b1 : 1'b0),
     (AW_SHARED_M3 ? 1'b1 : 1'b0),
     (AW_SHARED_M2 ? 1'b1 : 1'b0),
     (AW_SHARED_M1 ? 1'b1 : 1'b0),
     (AW_SHARED_M0 ? 1'b1 : 1'b0)
    };

  // Remap aw_shrd_param_bus to visible master bits only.
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue.
  always @(*) begin : aw_shrd_param_bus_lcl_PROC
    integer sm;
    integer lm;
    lm = 0;
    aw_shrd_param_bus_lcl = {NUM_VIS_MP{1'b0}};
    for(sm=0;sm<`AXI_MAX_NUM_USR_MSTS;sm=sm+1) begin
      if(vis_bus[sm]) begin
        aw_shrd_param_bus_lcl[lm] = aw_shrd_param_bus[sm];
        lm=lm+1;
      end
    end
  end // aw_shrd_param_bus_lcl_PROC

  // Shared channel is always the most significant numbered master
  // requesting to a dedicated channel.
  assign shrd_aw_grnt_at_ddctd_aw = issued_tx_mst_oh_i[AW_NUM_VIS_MP-1];


  // Select the shared channel tx_issued bit for masters that connect to
  // this slave via the shared AW channel, and select the dedicated 
  // channels signal for masters that connect to this slaves AW channel 
  // through the dedicated channel.
  always @(*) begin : issued_tx_mst_combined_oh_PROC
    integer mnum;
    issued_tx_mst_combined_oh = {NUM_VIS_MP{1'b0}};

    for(mnum=0 ; mnum<=(NUM_VIS_MP-1) ; mnum=mnum+1) begin
      // Use shrd_aw_grnt_at_ddctd_aw to qualify signals from shared
      // layer and dedicated layer i.e. mask shared layer signals when the
      // shared layer is NOT granted at the dedicated later, and mask
      // dedicated layer signals when shared layer IS granted at the
      // dedicated layer. Necessary because shared layer signals can
      // be asserted when the shared layer has yet to be granted at the
      // dedicated layer.
      issued_tx_mst_combined_oh[mnum] 
        = aw_shrd_param_bus_lcl[mnum] 
          ? (issued_tx_shrd_mst_oh_i[mnum] & shrd_aw_grnt_at_ddctd_aw)
          : (   issued_tx_shrd_ddctd_mst_oh_i[mnum] 
              & (~shrd_aw_grnt_at_ddctd_aw)
            );
    end
  end // issued_tx_mst_combined_oh_PROC

  // Convert issued_tx_mst_combined_oh to binary.                          
  always @(*) 
  begin : issued_tx_mst_combined_PROC
    integer mnum;
    issued_tx_mst_combined = {LOG2_NUM_VIS_MP{1'b0}};

    for(mnum=0 ; mnum<=(NUM_VIS_MP-1) ; mnum=mnum+1) begin
      if(issued_tx_mst_combined_oh[mnum]) issued_tx_mst_combined = mnum;
    end
  end // issued_tx_mst_combined_PROC


  // Convert issued_tx_shrd_mst_oh_i to binary.                          
  always @(*) 
  begin : issued_tx_shrd_mst_PROC
    integer mnum;
    issued_tx_shrd_mst = {LOG2_NUM_VIS_MP{1'b0}};

    for(mnum=0 ; mnum<=(NUM_VIS_MP-1) ; mnum=mnum+1) begin
      if(issued_tx_shrd_mst_oh_i[mnum]) issued_tx_shrd_mst = mnum;
    end
  end // issued_tx_shrd_mst_PROC
  //spyglass enable_block W415a


  /* -------------------------------------------------------------------
  * If this slave is accessed through both the shared and dedicated
  * channels on the W channel, the issued_tx signals must be remapped
  * to match how this dedicated channel sees the master requests.
  * For example, if 5 masters are visible, 2 through the dedicated channel
  * and 3 through the shared channel, this block will have 3 physical
  * master connections. 
  * e.g. 
  *
  *  VISIBLE MST 1 - SHARED    - @ this dedicated W channel => MST 3
  *  VISIBLE MST 2 - DEDICATED - @ this dedicated W channel => MST 1
  *  VISIBLE MST 3 - SHARED    - @ this dedicated W channel => MST 3
  *  VISIBLE MST 4 - DEDICATED - @ this dedicated W channel => MST 2
  *  VISIBLE MST 5 - SHARED    - @ this dedicated W channel => MST 3
  *
  * i.e. all the shared W maasters request here through master 3.
  *
  * So we must remap the per local (visible) master signal to reflect
  * how the masters appear here.
  */

  // Per local master issued_tx signal to be mapped with respect
  // to shared->dedicated W channel link.
  wire [NUM_VIS_MP-1:0] issued_tx_w_shrd_ddctd_oh_unmapd;


  // spyglass disable_block W164b
  // SMD: Identifies assignments in which the LHS width is greater than the RHS width
  // SJ : This is not a functional issue, this is as per the requirement.
  assign issued_tx_w_shrd_ddctd_oh_unmapd
    = DDCT_AW_REMOVED
        // Dedicated AW channel removed, all tx_issued_* 
        // signals come from the shared AW.
      ? issued_tx_shrd_mst_oh_i
      : HAS_AW_SHRD_DDCTD_LNK
          // Masters reach this slave through both the shared 
          // and dedicated channels => this issued_tx signal 
          // combines shared and dedicated issued_tx signals into
          // a single bus.
        ? issued_tx_mst_combined_oh
          // Only the dedicated AW channel exists.
        : issued_tx_mst_oh_i;
  // spyglass enable_block W164b


  // Create a bus of the shared layer parameters on the W channel.
  assign w_shrd_param_bus = 
    {(W_SHARED_M15 ? 1'b1 : 1'b0),
     (W_SHARED_M14 ? 1'b1 : 1'b0),
     (W_SHARED_M13 ? 1'b1 : 1'b0),
     (W_SHARED_M12 ? 1'b1 : 1'b0),
     (W_SHARED_M11 ? 1'b1 : 1'b0),
     (W_SHARED_M10 ? 1'b1 : 1'b0),
     (W_SHARED_M9 ? 1'b1 : 1'b0),
     (W_SHARED_M8 ? 1'b1 : 1'b0),
     (W_SHARED_M7 ? 1'b1 : 1'b0),
     (W_SHARED_M6 ? 1'b1 : 1'b0),
     (W_SHARED_M5 ? 1'b1 : 1'b0),
     (W_SHARED_M4 ? 1'b1 : 1'b0),
     (W_SHARED_M3 ? 1'b1 : 1'b0),
     (W_SHARED_M2 ? 1'b1 : 1'b0),
     (W_SHARED_M1 ? 1'b1 : 1'b0),
     (W_SHARED_M0 ? 1'b1 : 1'b0)
    };

  // Remap w_shrd_param_bus to visible master bits only.
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue.
  always @(*) begin : w_shrd_param_bus_lcl_PROC
    integer sm;
    integer lm;
    lm = 0;
    w_shrd_param_bus_lcl = {NUM_VIS_MP{1'b0}};
    for(sm=0;sm<`AXI_MAX_NUM_USR_MSTS;sm=sm+1) begin
      if(vis_bus[sm]) begin
        w_shrd_param_bus_lcl[lm] = w_shrd_param_bus[sm];
        lm=lm+1;
      end
    end
  end // w_shrd_param_bus_lcl_PROC


  // Perform the remapping described above.
  always @(*) begin : issued_tx_w_shrd_ddctd_oh_mapd_PROC
    integer lmn; // Local master number.
    integer sd_mn; // master number taking into account
                   // shared dedicated link.
                   
    issued_tx_w_shrd_ddctd_oh_mapd = {NUM_CON_MP{1'b0}};
    sd_mn = 0;

    // Extract bits relating to masters that reach here through the
    // dedicated layer.
    for(lmn=0;lmn<NUM_VIS_MP;lmn=lmn+1) begin
      if(~w_shrd_param_bus_lcl[lmn]) begin
        issued_tx_w_shrd_ddctd_oh_mapd[sd_mn] 
          = issued_tx_w_shrd_ddctd_oh_unmapd[lmn];
        sd_mn = sd_mn+1;
      end
    end

    // Last bit (most significant numbered master) is for all
    // masters that reach here through the shared to dedicated
    // link.
    issued_tx_w_shrd_ddctd_oh_mapd[NUM_CON_MP-1]
      = |(issued_tx_w_shrd_ddctd_oh_unmapd
           & w_shrd_param_bus_lcl);

  end // issued_tx_w_shrd_ddctd_mapd_PROC

  // Convert issued_tx_shrd_mst_oh_i to binary.                          
  always @(*) 
  begin : issued_tx_w_shrd_ddctd_mapd_PROC
    integer mnum;
    issued_tx_w_shrd_ddctd_mapd = {LOG2_NUM_CON_MP{1'b0}};

    for(mnum=0 ; mnum<=(NUM_CON_MP-1) ; mnum=mnum+1) begin
      if(issued_tx_w_shrd_ddctd_oh_mapd[mnum]) begin
        issued_tx_w_shrd_ddctd_mapd = mnum;
      end
    end
  end // issued_tx_w_shrd_ddctd_mapd_PROC
  //spyglass enable_block W415a


  /*--------------------------------------------------------------------
   * The shared AW channel will assert the issued_tx_shrd_slv_oh_i
   * signal for any t/x to a shared slave on the AW channel. 
   * But some of those master slave paths go through the shared W 
   * channel, and some do not. We need to mask any assertions of
   * issued_tx_shrd_slv_oh_i relating to a master slave link that does
   * not go through the shared W channel.
   * From the top level, the w_layer_s_m_bus_i signal contains the 
   * AXI_W_LAYER_Sx_My parameters for every master and slave on the
   * shared W channel. Organised by master
   * i.e. {m5 params, m4 params, .... m1 params}
   * Using issued_tx_shrd_mst_oh_i to select the values relating to the
   * master who sent the t/x, we and that with issued_tx_shrd_slv_oh_i
   * such that we get a version of issued_tx_shrd_slv_oh_i that asserts
   * only for master slave links on the shared W channel.
   * This is necessary because issued_tx_shrd_slv_oh_i causes the per
   * slave write ordering fifos to be pushed, and we must ensure that 
   * they are only pushed for t/x's that will come through the shared
   * W channel.
   */
  generate
  if(SHARED) begin : gen_sp_wdatach_shared
    DW_axi_busmux_ohsel
    
    #(NUM_CON_MP, // Number of inputs to the mux.
      NSS         // Width of each input to the mux.
     )
    U_DW_axi_busmux_w_layer_s_m_bus_mux (
      .sel  (issued_tx_shrd_mst_oh_i),
      .din  (w_layer_s_m_bus_i), 
      .dout (w_layer_s_m_bus_mux) 
    );
  
    // Mask issued_tx_shrd_slv_oh_i.
    assign issued_tx_shrd_slv_oh_msk 
     = w_layer_s_m_bus_mux & issued_tx_shrd_slv_oh_i;
  end else begin : gen_sp_wdatach_not_shared
    assign issued_tx_shrd_slv_oh_msk = {NSS{1'b0}};
  end
  endgenerate


  wire                       issued_tx_c;    
  wire [LOG2_NUM_CON_MP-1:0] issued_mstnum_c;

  assign issued_tx_c = DDCT_AW_REMOVED 
                       ? issued_tx_shrd_i 
                       : issued_tx_i;

  // spyglass disable_block W164a
  // SMD: Identifies assignments in which the LHS width is less than the RHS width
  // SJ: other bits will be appended with 0's, warning can be ignored
  assign issued_mstnum_c 
    = HAS_W_SHRD_DDCTD_LNK
       ? issued_tx_w_shrd_ddctd_mapd
       : (  DDCT_AW_REMOVED 
             // If this is a shared W channel then we must use
             // issued_tx_shrd_mst, which is decoded from a
             // 1 hot master number which has been rewired
             // externally from 1 bit per AW master to 1 bit
             // per W master.
           | SHARED
         )
         ? issued_tx_shrd_mst
         // This is a dedicated W channel, we use
         // different issued_tx signals depending on
         // whether or not the AW channel as a shared to
         // dedicated link or not.
         : HAS_AW_SHRD_DDCTD_LNK 
           ? issued_tx_mst_combined
           : issued_mstnum_i;
  // spyglass enable_block W164a

  // Use registered version of the issued t/x signals for timing
  // performance reasons.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : issued_tx_regs_PROC
    if(!aresetn_i) begin
      issued_tx_r             <= 1'b0;
      issued_mstnum_r         <= {LOG2_NUM_CON_MP{1'b0}};
      issued_tx_shrd_slv_oh_r <= {NSS{1'b0}};
    end else begin 
      issued_tx_r <= issued_tx_c;
      issued_mstnum_r <= issued_mstnum_c;
      
      // This is only used if the W channel is shared, and
      // if W is shared then AW must be also (for same slaves).
      // DW_axi_sp_shrd_wrorder is removed if W is not shared,
      // so this register will be optimised away when not required.
      issued_tx_shrd_slv_oh_r <= issued_tx_shrd_slv_oh_msk;                         
    end
  end // issued_tx_regs_PROC

  

  assign issued_tx_mux = `REG_INTER_BLOCK_PATHS
                         ? issued_tx_r : issued_tx_c;

  assign issued_mstnum_mux = `REG_INTER_BLOCK_PATHS
                             ? issued_mstnum_r : issued_mstnum_c;

  assign issued_tx_shrd_slv_oh_mux 
  = `REG_INTER_BLOCK_PATHS
    ? issued_tx_shrd_slv_oh_r 
    : issued_tx_shrd_slv_oh_msk;



  generate 
    if(SHARED == 0) begin : gen_sp_wdatach_w_not_shared
      //----------------------------------------------------------------
      // Dedicated Channel Write Order Block
      // - implements protocol write data interleaving & ordering rules 
      //   for a dedicated write data channel.
      //----------------------------------------------------------------
      DW_axi_sp_wrorder
      
      #(NUM_CON_MP,           // Number of visible master ports.
        LOG2_NUM_CON_MP,      
        PL_ARB,               // 1 if channel arbiter has pipelined 
                              // outputs.
        WID,                  // Slaves Write interleaving depth.
        MAX_FAC,              // Max number of outstanding commands to 
                              // slave.
        LOG2_MAX_FAC,        
        BUS_PRIORITY_W,       // Width of bus with priorities per 
                              // visible master.
        `BUS_PRIORITY_WID_W,  // Width of bus with priorities per write
                              // interleaving depth.
        `BUS_PORT_REQ_W,      // Width of bus containing master numbers 
                              // which
                              // are allowed to access the arbiter.
        HAS_W_SHRD_DDCTD_LNK, // Does this dedicated slave W channel 
                              // have a link with the shared W layer.
        MCA_EN                // Is multi cycle arbitration enabled.
      )
      U_DW_axi_sp_wrorder (
        // Inputs - System.  
        .aclk_i                 (aclk_i),
        .aresetn_i              (aresetn_i),
    
        // Inputs - Master ports.
        .bus_valid_i            (bus_valid_i),
        .bus_priority_i         (bus_mst_priorities_i),
    
        // Inputs - Write address channel.
        .issued_tx_i            (issued_tx_mux),
        .issued_mstnum_i        (issued_mstnum_mux),
    
        // Inputs - Write data channel internal.
        .ready_i                (tx_acc_s),
    
        .cpl_tx_i               (cpl_tx),
    
        // Inputs - Arbiter.
        .grant_m_local_i        (port_req_mux),
      
        // Outputs - Shared write data channel.
        .firstpnd_mst_o         (firstpnd_mst_ddctd),
        .fifo_empty_o           (fifo_empty_ddctd),
        .firstpnd_fifo_pop_o    (firstpnd_fifo_pop_ddctd),

        // Outputs - Arbiter.
        .req_o                  (req_wrorder),
        .bus_mst_req_o          (bus_mst_req_wrorder),
        .bus_mst_priorities_o   (bus_priorities_wrorder)
      );
    end 
    else begin : default_assignment //VP:: default assignment for Lint Error
     assign    bus_mst_req_wrorder = {`BUS_PORT_REQ_W{1'b0}};
     assign    bus_priorities_wrorder = {`BUS_PRIORITY_WID_W{1'b0}};
     assign    req_wrorder         = {WID{1'b0}}; 
     assign    firstpnd_mst_ddctd  = {LOG2_NUM_CON_MP{1'b0}};
     assign    fifo_empty_ddctd    = 1'b0;
     assign    firstpnd_fifo_pop_ddctd =1'b0; 
    end 

    if(SHARED) begin : gen_sp_wdatach_w_shared
      //----------------------------------------------------------------
      // Shared Channel Write Order Block
      // - implements protocol write data interleaving & ordering rules 
      //   fora dedicated write data channel.
      //----------------------------------------------------------------
      DW_axi_sp_shrd_wrorder
       
      #(NUM_CON_MP,      // Number of visible master ports.
        NSS,             // Number of attached slaves.
        LOG2_NUM_CON_MP, 
        PL_ARB,          // Are arbiter outputs pipelined.
        SHARED_PL,       // Add shared layer pipelining ?

        // Do the shared slaves have a dedicted W channel also ?
         HAS_DDCTD_W_S0,  HAS_DDCTD_W_S1,  HAS_DDCTD_W_S2, 
         HAS_DDCTD_W_S3,  HAS_DDCTD_W_S4,  HAS_DDCTD_W_S5,  
         HAS_DDCTD_W_S6,  HAS_DDCTD_W_S7,  HAS_DDCTD_W_S8,  
         HAS_DDCTD_W_S9, HAS_DDCTD_W_S10, HAS_DDCTD_W_S11, 
        HAS_DDCTD_W_S12, HAS_DDCTD_W_S13, HAS_DDCTD_W_S14, 
        HAS_DDCTD_W_S15, HAS_DDCTD_W_S16
      )
      U_DW_axi_sp_shrd_wrorder (
        // Inputs - System
        .aclk_i                   (aclk_i),
        .aresetn_i                (aresetn_i),
      
        // Inputs - Master Ports
        .bus_valid_i              (bus_valid_i),
        .bus_valid_shrd_i         (bus_valid_shrd_i),
        
        // Inputs - Slave Ports (Write address channels)
        .issued_slvnum_oh_i       (issued_tx_shrd_slv_oh_mux),
        .issued_mstnum_i          (issued_mstnum_mux),
        .bus_ready_shrd_m_i       (bus_ready_o),
        .tx_acc_s_i               (tx_acc_s),

        // Inputs - Dedicated W Channels.
        .shrd_w_nxt_fb_pend_bus_i (shrd_w_nxt_fb_pend_bus_i),
        
        // Outputs - Slave Port Arbiter
        .bus_mst_req_o            (req_shrd_wrorder),
      
        // Inputs - Slave Port
        .bus_valid_shrd_out_i     (bus_valid_shrd_masked),
        .cpl_tx_bus_i             (cpl_tx_shrd_bus)
      );
    end
  endgenerate 


  // If there is only 1 master port visible to this slave port
  // then we don't need the wrorder block. That master will
  // be required to adhere to write ordering rules itself so
  // the wrorder block is redundant.
  // We bypass the wrorder blocks outputs in this case.
  // Note that we use different priority and request signal to sent
  // to the arbiter if SHARED == 1.
  //spyglass disable_block W164a
  //SMD: Identifies assignments in which the LHS width is less than the RHS width
  //SJ: other bits will be appended with 0's, warning can be ignored
  // spyglass disable_block W164b
  // SMD: Identifies assignments in which the LHS width is greater than the RHS width
  // SJ : This is not a functional issue, this is as per the requirement.
  assign req_arb = (NUM_CON_MP==1)
                   ? bus_valid_i[0]
                   : (SHARED ? req_shrd_wrorder : req_wrorder);

  assign bus_mst_req_arb = (NUM_CON_MP==1) 
                           ?{`BUS_PORT_REQ_W{1'b0}}
                           : bus_mst_req_wrorder;

  assign bus_priorities_arb = (NUM_CON_MP==1)
                              ?{`BUS_PRIORITY_WID_W{1'b0}}
                              : (SHARED ? bus_mst_priorities_i 
                                        : bus_priorities_wrorder);
  // spyglass enable_block W164b
  //spyglass enable_block W164a

  // Tell the shared W channel when it is next to send a first W beat
  // to this slave. Used to avoid a deadlock condition with the shared
  // to dedicated layer link.
  // We deassert this signal whenever a valid from the shared layer is
  // here (always in the most significant bit position), the logic
  // in the shared write data channel that samples this signal can
  // get out of sync if it is asserted when a valid from the shared 
  // layer is already here. We can use this signal directly with no
  // registering because there must always be a pipeline stage between
  // the shared layer and the dedicated layer.
  // layer is accepted here. This deassertion works as a handshake with
  // the shared layer, so it knows when the t/x it started has been
  // accepted here, after which it is safe to look at 
  // shrd_w_nxt_fb_pend_o again. Otherwise shrd_w_nxt_fb_pend_o could
  // remain asserted because the beat hasn't reached here yet (or is
  // losing arbitration) and beats for t/x's which are not safe to send
  // could be forwarded causing deadlock.
  assign shrd_w_nxt_fb_pend_o =   (firstpnd_mst_ddctd == (NUM_CON_MP-1))
                                & (~fifo_empty_ddctd)
                                & (~bus_valid_i[NUM_CON_MP-1])
                                // If PL_ARB is enabled, valid from the 
                                // shared layer will deassert as soon
                                // as ready is returned high, to avoid 
                                // asserting this signal on that cycle
                                // use pop from the first pending 
                                // master number fifo (fifo will pop
                                // when valid&ready for first beat).
                                & (  (~firstpnd_fifo_pop_ddctd)
                                   | (PL_ARB==0)
                                  )
                                & (HAS_W_SHRD_DDCTD_LNK == 1);


  // Dummy wire for unrequired arbiter module output.

  //--------------------------------------------------------------------
  // Channel Arbiter
  //--------------------------------------------------------------------
  DW_axi_arb
   
  #(ARB_TYPE,                 // Arbitration type.
    `ARB_NC,                  // Number of clients to arbiter.
    `ARB_LOG2_NC,             // Log base 2 of number of clients.
    `ARB_LOG2_NC_P1,          // Log base 2 of (number of clients + 1).
    PL_ARB,                   // Pipeline arbiter outputs ?
    MCA_EN,                   // Has multi-cycle arbitration ?
    MCA_NC,                   // Num. cycles in multi-cycle arbitration.
    MCA_NC_W,                 // Log base 2 MCA_NC.
    1,                        // Hold priorities for multi cycle arb.
    `AXI_MST_PRIORITY_W,      // Priority width of a single master.            
    `BUS_PRIORITY_WID_W,      // Width of priorities bus.
    0,                        // Don't lock to client until burst completes.
    0                         // No locking features required here.
  )
  U_DW_axi_arb (
    // Inputs - System.
    .aclk_i               (aclk_i),
    .aresetn_i            (aresetn_i),
    .bus_priorities_i     (bus_priorities_arb),

    // Inputs - Channel Source.
    .lock_seq_i           (1'b0), // Not required here.
    .locktx_i             ({`ARB_NC{1'b0}}), // Not required here.
    .unlock_i             (1'b0), // Not required here.
    .grant_masked_i       (1'b0), // Not required here.

    // Not required here, next 2 inputs required on address
    // channels only.
    .use_other_pri_i      ({`ARB_NC{1'b0}}), 
    //.bus_grant_lock_i     ({`ARB_NC{1'b0}}),

    .request_i            (req_arb),

    // Inputs - Channel Destination.
    .valid_i              (valid_o),
    .ready_i              (ready_shrd_ddctd_mux),
    .last_i               (1'b0), // Not required here.
  
    // Outputs - Channel Destination.
    .grant_o              (grant),
    .grant_p_local_o      (arb_grant_index),
    .bus_grant_o          (arb_bus_grant) 
  );
  

  generate
    if(SHARED==0) begin : gen_sp_wdatach_dcd_not_shared
      /*--------------------------------------------------------------------
       * Decode Arbiter Outputs
       *
       * If this is a dedicated channel instance, then the arbiter grants
       * a write interleaving slot, we then have to decode what master
       * was requesting on that interleaving slot. This information is
       * given on the bus_mst_req_wrorder signal from the wrorder block.
       */

      // Register bus_mst_req_wrorder to align with rest
      // of the channel signals.
      always @(posedge aclk_i or negedge aresetn_i)
      begin : bus_mst_req_wrorder_r_PROC
        if(~aresetn_i) begin
          bus_mst_req_wrorder_r <= {`BUS_PORT_REQ_W{1'b0}};
        end else begin
          bus_mst_req_wrorder_r <= bus_mst_req_wrorder;
        end
      end // bus_mst_req_wrorder_r_PROC
  
      // Select registered requesting masters bus if
      // the arbiter is pipelined.
      assign bus_mst_req_pla_mux = PL_ARB 
                                   ? bus_mst_req_wrorder_r
                                   : bus_mst_req_wrorder;
                

      // Use the arbiters grant index to select the master that
      // was requesting on the granted write interleaving slot.
      DW_axi_busmux
      
      #(`ARB_NC,      // Number of input busses.
        LOG2_NUM_CON_MP,       // Width of each input bus.
        `ARB_LOG2_NC  // Width of select line.
      ) 
      U_port_req_mux (
        .sel  (arb_grant_index),
        .din  (bus_mst_req_pla_mux), 
        .dout (port_req_mux) 
      );
    
    
      // Decode a one hot grant per client from 
      // the result of the requesting ports mux.
      // To be used as bus_grant signal when the grant
      // index of the internal arbiter is not being used.
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue.
      always @(port_req_mux)
      begin : bus_grant_port_req_PROC
        integer i;
    
        bus_grant_port_req = {NUM_CON_MP{1'b0}};
    
        for(i=0 ; i<=(NUM_CON_MP-1) ; i=i+1 ) begin
          if(port_req_mux==i) bus_grant_port_req[i] = 1'b1;
        end
    
      end // bus_grant_port_req_PROC
    
      assign grant_index_m = port_req_mux;
      assign bus_grant_m = bus_grant_port_req;
    end // if(SHARED==0)
  //spyglass enable_block W415a

    if(SHARED) begin : gen_sp_wdatach_dcd_shared
      // We can use the arbiters grant outputs directly if SHARED==1,
      // since we will be arbitrating per master in that case.
      assign grant_index_m = arb_grant_index;
      assign bus_grant_m = arb_bus_grant;
    end

  endgenerate


  /*--------------------------------------------------------------------
   * Payload Mux
   */


  // Select the payload from the granted master port.
  DW_axi_busmux
  
  #(NUM_CON_MP,      // Number of inputs to the mux.
    PYLD_S_W,        // Width of each input to the mux.
    LOG2_NUM_CON_MP  // Width of select input for the mux.
  )
  U_busmux_payload (
    .sel  (grant_index_m),
    .din  (bus_payload_i), 
    .dout (payload_pre_irs) 
  );


  /*--------------------------------------------------------------------
   * Dedicated Valid Generation
   */
  
  // Register req_arb to align with the rest of the channel signals.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : req_arb_r_PROC
    if(~aresetn_i) begin
      req_arb_r <= {WID{1'b0}};
    end else begin
      req_arb_r <= req_arb;
    end
  end // req_arb_r_PROC

  // If multi cycle arbitration is being used and the arbiter
  // pipeline stage is enabled then we must use registered valid
  // signals here to align valid with the buffered payload.
  assign req_arb_mux = PL_ARB ? req_arb_r : req_arb;


  // This mux selects the granted valid signal when multi cycle
  // arbitration has been selected for this channel at this port.
  // Notice that in this channel because of the wrorder block 
  // controlling which clients can see the arbiter we do not
  // select from the valid inputs to this block but rather from the
  // valid signals presented to the arbiter, for this reason we
  // need to use the arb_grant_index output from the arbiter directly
  // apply to WID num clients, as opposed to port_req_mux which
  // will apply to all clients visible to this slave port.
  DW_axi_busmux
  
  #(`ARB_NC,     // Number of inputs to the mux.
    1,                    // Width of each input to the mux.
    `ARB_LOG2_NC // Width of select input for the mux.
  )
  U_DW_axi_busmux_mca (
    .sel  (arb_grant_index),
    .din  (req_arb_mux), 
    .dout (valid_granted_mca) 
  );

  // Valid output is grant from the arbiter block.
  // or selected directly from the valid inputs for multi cycle
  // arbitration.
  // NOTE : this is still used in a shared channel instance to detect
  //        when a beat has been accepted. To use the shared valid out
  //        bus we would have to multiplex it or do an OR reduction 
  //        which would be more area costly.
  assign valid_o = MCA_EN ? valid_granted_mca : grant;
  

  /*--------------------------------------------------------------------
   * Shared Valid Generation
   */

  // Register bus_valid_shrd_i to align with the rest of the channel 
  // signals.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : bus_valid_shrd_r_PROC
    if(~aresetn_i) begin
      bus_valid_shrd_r <= {V_BUS_SHRD_W{1'b0}};
    end else begin
      bus_valid_shrd_r <= bus_valid_shrd_i;
    end
  end // bus_valid_shrd_r_PROC

  // If multi cycle arbitration is being used and the arbiter
  // pipeline stage is enabled then we must use registered valid
  // signals here to align valid with the buffered payload.
  assign bus_valid_shrd_mux = PL_ARB 
                              ? bus_valid_shrd_r 
                              : bus_valid_shrd_i;

  /*--------------------------------------------------------------------
   * Select slave valid signals from the granted master, note that 
   * for each master we have a bus of valid signals with valid for the
   * addressed slave asserted.
   */
  DW_axi_busmux
  
  #(NUM_CON_MP,      // Number of inputs to the mux.
    NSS,             // Width of each input to the mux.
    LOG2_NUM_CON_MP  // Width of select input for the mux.
  )
  U_busmux_valid_shared (
    .sel  (grant_index_m),
    .din  (bus_valid_shrd_mux), 
    .dout (bus_valid_shrd_grnt_mux) 
  );
  
  // valid_o will only be asserted if the arbiter has granted a client,
  // requests will only be sent to the arbiter for clients that are
  // clear (safe) to send write data. So we use valid_o here to avoid
  // letting out a valid signal from the master selected by default
  // by the arbiter.
  assign bus_valid_shrd_masked = (SHARED & valid_o) 
                                 ? bus_valid_shrd_grnt_mux 
                                 : {NSS{1'b0}};


  /*--------------------------------------------------------------------
   * Completion detection
   */

  // Dedicated Channel
  // Detect completion of the write data part of a write transaction 
  // on the write data channel.
  assign cpl_tx = payload_pre_irs[`AXI_WPYLD_LAST] & valid_o & ready_i;

  // Shared Channel
  // Detect write data part completion for each slave attached to the
  // shared channel.
  assign cpl_tx_shrd_bus = 
    (  {NSS{payload_pre_irs[`AXI_WPYLD_LAST]}}
     & bus_valid_shrd_masked
     & {NSS{ready_irs}}
    );


  /*--------------------------------------------------------------------
   * Decode bus_ready_o.
   * Each bit of bus_ready_o applies to 1 master port only.
   * bus_grant comes from the arbiter and has 1 bit per master port
   * also. By doing a bitwise AND of valid_o with bus_grant
   * we get a bus of ready signals for each master port, where ready
   * will only be asserted if the master port is sending a 
   * transfer to this channel, has won arbitration, and the slave
   * has accepted with ready high.
   * Note that for a shared channel we first need to select the ready
   * input of the addressed slave, this is done before the 
   * shared layer internal register slice and the output comes here
   * as ready_irs.
   */

  // Select the correct final ready bit from the attached master(s)
  // depending on whether this is a shared channel or dedicated.
  assign ready_shrd_ddctd_mux = SHARED ? ready_irs : ready_i;

  assign tx_acc_s = valid_o & ready_shrd_ddctd_mux;

  assign bus_ready_o = {NUM_CON_MP{tx_acc_s}} & bus_grant_m;


  /*--------------------------------------------------------------------
   * Shared Channel Pipeline Stage
   */
  DW_axi_irs
  
  #(((SHARED & SHARED_PL) ? `AXI_TMO_FRWD : 0), // Channel timing option
    NSS,        // Number of visible slaves.
    0,          // Is channel arbiter pipelined, doesn't apply here.
    PYLD_S_W,   // Channel payload width.
    1,          // Log base 2 of num. visible ports. Not required
                // in this instance, pass 1 to compile clean.
    1,          // Master ID width, not required, pass 1 to 
                // compile clean.
    0,          // Masking logic not required here.
    0,          // ID right hand bit, not required here.
    0,          // ID left hand bit, not required here.
    0,          // Pass a 1 for W channel, not required.
    0           // Shared layer signal(s) required, doesn't apply
                // here, only required for source blocks sending
                // requests to the shared layer.
  )
  U_DW_axi_irs_sp_w_shrd (
    // Inputs - System.
    .aclk_i        (aclk_i),
    .aresetn_i     (aresetn_i),

    // Inputs - Payload source.
    .payload_i     (payload_pre_irs),
    .bus_valid_i   (bus_valid_shrd_masked),
    .valid_i       (valid_o),
    .mask_valid_i  (1'b0), // Masking not required here.
    .shrd_ch_req_i (1'b0), // Not required here.
  
    // Outputs - Payload source.
    .ready_o       (ready_irs),

    // Inputs - Payload destination.
    .ready_i       (ready_irs_in),
    
    // Outputs - Payload destination.
    .bus_valid_o   (bus_valid_irs),
    .payload_o     (payload_irs),

    // Outputs - Unconnected.
    .id_o          (id_irs_unconn),
    .local_slv_o   (local_slv_irs_unconn),
    .shrd_ch_req_o (shrd_ch_req_irs_unconn)
  );


  /*--------------------------------------------------------------------
   * Generate valid inputs for DW_axi_irs_arbpl block.
   *
   * Hold inputs for slaves which are not accessed through dedicated
   * channel blocks at 0, so synthesis can remove unused logic 
   * relating to those slaves.
   */
  assign has_ddctd_s_bus_max = 
    {(HAS_DDCTD_W_S16 == 1),
     (HAS_DDCTD_W_S15 == 1),
     (HAS_DDCTD_W_S14 == 1),
     (HAS_DDCTD_W_S13 == 1),
     (HAS_DDCTD_W_S12 == 1),
     (HAS_DDCTD_W_S11 == 1),
     (HAS_DDCTD_W_S10 == 1),
     (HAS_DDCTD_W_S9 == 1),
     (HAS_DDCTD_W_S8 == 1),
     (HAS_DDCTD_W_S7 == 1),
     (HAS_DDCTD_W_S6 == 1),
     (HAS_DDCTD_W_S5 == 1),
     (HAS_DDCTD_W_S4 == 1),
     (HAS_DDCTD_W_S3 == 1),
     (HAS_DDCTD_W_S2 == 1),
     (HAS_DDCTD_W_S1 == 1),
     (HAS_DDCTD_W_S0 == 1)
    };
    // Strip away unused bits.
    assign has_ddctd_s_bus = has_ddctd_s_bus_max[NSS-1:0];
 
  //spyglass disable_block STARC05-2.1.5.3
  //SMD: Conditional expression does not evaluate to a scalar
  //SJ: There is no functional issue, warning can be ignored
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue.
  //spyglass disable_block W224
  //SMD: Multi-bit expression found when one-bit expression expected
  //SJ: This is not an issue
   always @(*) begin : bus_valid_irs_arbpl_in_PROC
     integer slv;
     bus_valid_irs_arbpl_in = {NSS{1'b0}};
     for(slv=0;slv<NSS;slv=slv+1) begin
       // Use only if shared layer is accessing dedicated
       // sinks which have arbiter pipeline mode enabled.
       if(has_ddctd_s_bus[slv] & SHARED_ARB_PL_IRS) begin
         bus_valid_irs_arbpl_in[slv] = bus_valid_irs[slv];
       end else begin
         bus_valid_irs_arbpl_in[slv] = 1'b0;
       end
     end
   end // bus_valid_irs_arbpl_in_PROC
  //spyglass enable_block W224
  //spyglass enable_block W415a
  //spyglass enable_block STARC05-2.1.5.3


  /*--------------------------------------------------------------------
   * Shared Channel Arbiter Pipeline Stage.
   *
   * When the shared layer has a link with a dedicated channel, and the 
   * PL_ARB option is enabled in that channel, there will be a register
   * after the arbiter in the dedicated channel sink block. To operate
   * with this register after the arbiter, signals (valid, payload)
   * that leave here for a dedicated sink block need to be controlled
   * to take this into account. This requires the DW_axii_irs_arbpl 
   * block, similar to how it is used after source blocks in the
   * dedicated slave/master ports.
   */
  DW_axi_irs_arbpl
  
  #(SHARED_ARB_PL_IRS, // Add pipelining ?
    NSS,               // Number of visible slaves.
    PYLD_S_W,          // Channel payload width.
    1,                 // Log base 2 of num. visible ports. Not required
                       // in this instance, pass 1 to compile clean.
    1,                 // Master ID width, not required, pass 1 to 
                       // compile clean.
    0,                 // Masking logic not required here.
    0,                 // ID right hand bit, not required here.
    0,                 // ID left hand bit, not required here.
    0,                 // Pass a 1 for W channel, not required.
    0                  // Shared layer signal(s) required, N/A here.
  )
  U_DW_axi_irs_arbpl_sp_w_shrd (
    // Inputs - System.
    .aclk_i                   (aclk_i),
    .aresetn_i                (aresetn_i),

    // Inputs - Payload source.
    .payload_i                (payload_irs),
    .bus_valid_i              (bus_valid_irs_arbpl_in),
    .mask_valid_i             (1'b0), // Masking not required here.
    .shrd_ch_req_i            (1'b0), // N/A here.
    .issued_wtx_shrd_mst_oh_i (1'b0),
  
    // Outputs - Payload source.
    .ready_o                  (ready_irs_arbpl),

    // Inputs - Payload destination.
    .bus_ready_i              (bus_ready_irs_arbpl_in),

    // Outputs - Payload destination.
    .bus_valid_o              (bus_valid_irs_arbpl),
    .payload_o                (payload_irs_arbpl),
    
    // Outputs - Unconnected.
    .id_o                     (irs_apl_id_unconn),
    .local_slv_o              (irs_apl_local_slv_unconn),
    .shrd_ch_req_o            (irs_apl_shrd_ch_req_unconn),
    .payload_prereg_o         (irs_apl_payload_prereg_unconn), 
    .issued_wtx_shrd_mst_oh_o (irs_apl_issued_wtx_shrd_mst_oh_unconn),
    .bus_valid_r_o            (irs_apl_bus_valid_r_unconn)
  );


  /*--------------------------------------------------------------------
   * Select between outputs of DW_axi_irs, and DW_axi_irs_arbpl blocks.
   *
   * DW_axi_irs_arbpl is used only for slaves which are accessed through
   * dedicated channels (shared to dedicated link) when the ARB_PL 
   * option is set to 1.
   */
  always @(posedge aclk_i or negedge aresetn_i) 
  begin : ready_irs_arbpl_r_PROC
    if(~aresetn_i) begin
      ready_irs_arbpl_r <= 1'b0;
    end else begin
      ready_irs_arbpl_r <= ready_irs_arbpl;
    end
  end // ready_irs_arbpl_r_PROC

  //spyglass disable_block STARC05-2.1.5.3
  //SMD: Conditional expression does not evaluate to a scalar
  //SJ: There is no functional issue, warning can be ignored
  // Valid output multiplexing between irs & irs_arbpl.      
  // Always use irs_arbpl bits for slaves accessed through dedicated
  // channels.
  //spyglass disable_block W224
  //SMD: Multi-bit expression found when one-bit expression expected
  //SJ: This is not an issue
  always @(*) begin : bus_valid_shrd_o_PROC
    integer slv;
    for(slv=0;slv<NSS;slv=slv+1) begin
      // Use only if shared layer is accessing dedicated
      // sinks which have arbiter pipeline mode enabled.
      if(has_ddctd_s_bus[slv] & SHARED_ARB_PL_IRS) begin
        bus_valid_shrd_o[slv] = bus_valid_irs_arbpl[slv];
      end else begin
        // If there are still valids coming from irs_arbpl,
        // don't forward valids to slaves not accessed through
        // dedicated channels.
        bus_valid_shrd_o[slv] 
          =   bus_valid_irs[slv] 
            & (~any_valid_irs_arbpl_r | (SHARED_ARB_PL_IRS==0));
      end
    end
  end
  //spyglass enable_block W224
  //spyglass enable_block STARC05-2.1.5.3


  /*--------------------------------------------------------------------
   * Select which payload to send out.
   *
   * If any valid from irs_arbpl is asserted, use the irs_arbpl payload
   * after a 1 cycle delay. Valid inputs to irs_arbpl are only asserted
   * for slaves accessed through dedicated channels.
   */
  generate
    if (NSS == 1)
     assign any_valid_irs_arbpl = (bus_valid_irs_arbpl);
    else
     assign any_valid_irs_arbpl = |(bus_valid_irs_arbpl);
  endgenerate  

  always @(posedge aclk_i or negedge aresetn_i) 
  begin : any_valid_irs_arbpl_r_PROC
    if(~aresetn_i) begin
      any_valid_irs_arbpl_r <= 1'b0;
    end else begin
      any_valid_irs_arbpl_r <= any_valid_irs_arbpl;
    end
  end // any_valid_irs_arbpl_r_PROC


  // Payload output multiplexing between irs & irs_arbpl.      
  assign payload_o 
    = any_valid_irs_arbpl_r
      ? payload_irs_arbpl
      : payload_irs;


  /*--------------------------------------------------------------------
   * Select which ready signal goes to the DW_axi_irs block.
   *
   * As long as the irs block is targeting a slave accessed
   * through a dedicated channel, use ready from the irs_arbpl block, 
   * at all other times use ready decoded directly from the slaves.
   */
  generate
   if (NSS == 1)
   begin
  //`ifdef SNPS_RCE_INTERNAL_ON
   /**ccx_cond: ; ; 1+0 ; Condition is not reached when the bus valid occurs for the channel which is on shared layer. --condition_no_to_update.  */
  //`endif
    assign ready_irs_in
      = SHARED_ARB_PL_IRS
        ? ( (has_ddctd_s_bus & bus_valid_irs)
            ? ready_irs_arbpl
            : ready_shrd_mux
          )
        : ready_shrd_mux; 
   end
   else
   begin
    assign ready_irs_in
      = SHARED_ARB_PL_IRS
        ? ( |(has_ddctd_s_bus & bus_valid_irs)
            ? ready_irs_arbpl
            : ready_shrd_mux
          )
        : ready_shrd_mux;
   end
  endgenerate  
  


  /*--------------------------------------------------------------------
  * Select the ready input of the slave being addressed by this t/x.
  * NOTE that this mux sits on the slave (sink) side of an IRS 
  * (Internal Register Slice) block if enabled.
  * This is to pipeline the ready generation paths for shared
  * channels, which are significantly longer for shared channels
  * v/s dedicated channels.
  */
  DW_axi_busmux_ohsel
  
  #(NSS, // Number of inputs to the mux.
    1    // Width of each input to the mux.
   )
  U_DW_axi_busmux_ohsel_shrd_rdy_sel (
    .sel  (bus_valid_shrd_o),
    .din  (bus_ready_shrd_i), 
    .dout (ready_shrd_mux) 
  );


  //spyglass disable_block STARC05-2.1.5.3
  //SMD: Conditional expression does not evaluate to a scalar
  //SJ: There is no functional issue, warning can be ignored
  // For the irs_arbpl block, have to ensure that any bit
  // of ready will only assert if a valid has been driven out.
  // This will be true of all slaves accessed through dedicated
  // channels.
  //spyglass disable_block W224
  //SMD: Multi-bit expression found when one-bit expression expected
  //SJ: This is not an issue
  always @(*) begin : bus_ready_irs_arbpl_in_PROC
    integer slv;
    for(slv=0;slv<NSS;slv=slv+1) begin
      // Use only if shared layer is accessing dedicated
      // sinks which have arbiter pipeline mode enabled.
      if(has_ddctd_s_bus[slv] & SHARED_ARB_PL_IRS) begin
        bus_ready_irs_arbpl_in[slv] = bus_ready_shrd_i[slv];
      end else begin
        bus_ready_irs_arbpl_in[slv] = 1'b0;
      end
    end
  end // bus_ready_irs_arbpl_in_PROC
  //spyglass enable_block W224
  //spyglass enable_block STARC05-2.1.5.3


  // Undefine these macros, as the names are used in other modules,
  // so this will avoid simulator warnings.
  `undef ARB_NC
  `undef ARB_LOG2_NC
  `undef ARB_LOG2_NC_P1
  `undef REG_INTER_BLOCK_PATHS 

endmodule
