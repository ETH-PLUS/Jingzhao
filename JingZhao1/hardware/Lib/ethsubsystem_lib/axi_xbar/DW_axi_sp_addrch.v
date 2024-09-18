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
// File Version     :        $Revision: #16 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_sp_addrch.v#16 $ 
**
** ---------------------------------------------------------------------
**
** File     : DW_axi_sp_addrch.v
//
//
** Created  : Tue May 24 17:09:09 MEST 2005
** Modified : $Date: 2020/03/22 $
** Abstract : Seperate instantiations of this block implement the 
**            slave port read and write address channels.
**
** ---------------------------------------------------------------------
*/

module DW_axi_sp_addrch (
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
  bus_arvalid_i,
  bus_awvalid_i,

  bus_arvalid_shrd_i,
  bus_awvalid_shrd_i,

  bus_payload_i,
    
  // Outputs - Master Ports.
  bus_ready_o,
  shrd_lyr_granted_o,
    
  // Inputs - Read/Write Address Channel.
  outstnd_txs_fed_i,
  outstnd_txs_nonlkd_i,
  unlocking_tx_rcvd_i,
  bus_grant_arb_i,
  grant_m_local_arb_i,
  lock_i,
    
  // Outputs - Read/Write Address Channel.
  outstnd_txs_fed_o,
  outstnd_txs_nonlkd_o,
  unlocking_tx_rcvd_o,
  lock_o,
  bus_grant_arb_o,
  grant_m_local_arb_o,
    
  // Inputs - Read Data/Burst Response Channel.
  cpl_tx_i,
  cpl_tx_shrd_bus_i,

  // Outputs - Write Data Channel.
  issued_tx_o,
  issued_mstnum_o,
  issued_tx_shrd_slv_oh_o,
  issued_tx_mst_oh_o
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
  parameter LOG2_NUM_VIS_MP = 4; // Log 2 of Number of visible master 
                                  // ports.

  parameter PL_ARB = 0; // 1 to pipeline arbiter outputs.

  parameter MCA_EN = 0; // Enable multi cycle arbitration.

  parameter MCA_NC = 0; // Number of arb. cycles in multi cycle arb.

  parameter MCA_NC_W = 0; // Log base 2 of MCA_NC + 1.

  parameter ARB_TYPE = 0; // Arbitration type.


  // Width of bus containing payloads from all visible master ports.
  parameter BUS_PYLD_S_W = (2*`AXI_AR_PYLD_S_W);
  
  // Width of payload vector to slave.
  parameter PYLD_S_W = `AXI_AR_PYLD_S_W; 

  parameter MAX_FAC = 4; // Max. number of active commands to the 
                         // external slave.

  parameter LOG2_MAX_FAC_P1 = 2; // Log base 2 of MAX_FAC + 1.

  parameter BUS_PRIORITY_W = 2; // Width of bus containing priorities of 
                                // all visible masters.

  parameter LOCKING = 0; // Set to 1 to implement locking functionality.        
  parameter [0:0] WCH = 0; // Set to 1 if the block is implementing a write
                     // channel i.e. write address channel.

  // Does this dedicated channel, have a dedicated link.
  parameter [0:0] HAS_SHRD_DDCTD_LNK = 0;

  /* -------------------------------------------------------------------                     
   * Shared Channel Parameters
   */
  // spyglass disable_block ReserveName
  // SMD: A reserve name has been used.
  // SJ: This parameter is local to this module. This is not passed to heirarchy below this module. hence, it will not cause any issue.
  parameter SHARED = 0; // Shared address channel block ?                     
  // spyglass enable_block ReserveName
  parameter NSS = 1; // Number of slaves on this shared channel.

  parameter SHARED_PL = 0; // Pipeline in shared channel ?

  // Forward active command limits for each slave on the shared layer.
  parameter FAC_S0 = 1;
  parameter FAC_S1 = 1;
  parameter FAC_S2 = 1;
  parameter FAC_S3 = 1;
  parameter FAC_S4 = 1;
  parameter FAC_S5 = 1;
  parameter FAC_S6 = 1;
  parameter FAC_S7 = 1;
  parameter FAC_S8 = 1;
  parameter FAC_S9 = 1;
  parameter FAC_S10 = 1;
  parameter FAC_S11 = 1;
  parameter FAC_S12 = 1;
  parameter FAC_S13 = 1;
  parameter FAC_S14 = 1;
  parameter FAC_S15 = 1;
  parameter FAC_S16 = 1;
  
  // Log base 2 of FAC + 1 for each slave on the shared layer.
  parameter LOG2_FAC_P1_S0 = 1;
  parameter LOG2_FAC_P1_S1 = 1;
  parameter LOG2_FAC_P1_S2 = 1;
  parameter LOG2_FAC_P1_S3 = 1;
  parameter LOG2_FAC_P1_S4 = 1;
  parameter LOG2_FAC_P1_S5 = 1;
  parameter LOG2_FAC_P1_S6 = 1;
  parameter LOG2_FAC_P1_S7 = 1;
  parameter LOG2_FAC_P1_S8 = 1;
  parameter LOG2_FAC_P1_S9 = 1;
  parameter LOG2_FAC_P1_S10 = 1;
  parameter LOG2_FAC_P1_S11 = 1;
  parameter LOG2_FAC_P1_S12 = 1;
  parameter LOG2_FAC_P1_S13 = 1;
  parameter LOG2_FAC_P1_S14 = 1;
  parameter LOG2_FAC_P1_S15 = 1;
  parameter LOG2_FAC_P1_S16 = 1;

  // 1 if the shared slave has a dedicated channel also.
  parameter HAS_DDCTD_S0 = 1;
  parameter HAS_DDCTD_S1 = 1;
  parameter HAS_DDCTD_S2 = 1;
  parameter HAS_DDCTD_S3 = 1;
  parameter HAS_DDCTD_S4 = 1;
  parameter HAS_DDCTD_S5 = 1;
  parameter HAS_DDCTD_S6 = 1;
  parameter HAS_DDCTD_S7 = 1;
  parameter HAS_DDCTD_S8 = 1;
  parameter HAS_DDCTD_S9 = 1;
  parameter HAS_DDCTD_S10 = 1;
  parameter HAS_DDCTD_S11 = 1;
  parameter HAS_DDCTD_S12 = 1;
  parameter HAS_DDCTD_S13 = 1;
  parameter HAS_DDCTD_S14 = 1;
  parameter HAS_DDCTD_S15 = 1;
  parameter HAS_DDCTD_S16 = 1;

  // Every master will send a bus of valid signals, with 1 signal for
  // every attached slave (signals for slaves not visible to that master
  // are tied to 0 at the top level.
  localparam V_BUS_SHRD_W = NUM_CON_MP*NSS;

  // Decode if there is any connection with a dedicated address channel.
  localparam HAS_DDCTD_LNK 
    =   (HAS_DDCTD_S0 == 1)
      | ((HAS_DDCTD_S1 == 1) & (NSS >= 1))
      | ((HAS_DDCTD_S2 == 1) & (NSS >= 2))
      | ((HAS_DDCTD_S3 == 1) & (NSS >= 3))
      | ((HAS_DDCTD_S4 == 1) & (NSS >= 4))
      | ((HAS_DDCTD_S5 == 1) & (NSS >= 5))
      | ((HAS_DDCTD_S6 == 1) & (NSS >= 6))
      | ((HAS_DDCTD_S7 == 1) & (NSS >= 7))
      | ((HAS_DDCTD_S8 == 1) & (NSS >= 8))
      | ((HAS_DDCTD_S9 == 1) & (NSS >= 9))
      | ((HAS_DDCTD_S10 == 1) & (NSS >= 10))
      | ((HAS_DDCTD_S11 == 1) & (NSS >= 11))
      | ((HAS_DDCTD_S12 == 1) & (NSS >= 12))
      | ((HAS_DDCTD_S13 == 1) & (NSS >= 13))
      | ((HAS_DDCTD_S14 == 1) & (NSS >= 14))
      | ((HAS_DDCTD_S15 == 1) & (NSS >= 15))
      | ((HAS_DDCTD_S16 == 1) & (NSS >= 16));

  // Is the DW_axi_irs_arbpl required to perform PL_ARB register slicing
  // here ?
  // NOTE, not done here for the AW channel. For the AW channel, to avoid
  // a deadlock condition, a seperate irs_arbpl module is used for every
  // shared to dedicated link.
  localparam SHARED_ARB_PL_IRS = SHARED & HAS_DDCTD_LNK & PL_ARB 
                                 & (WCH == 0);

  // Width of arbiter internal grant index.                                
  localparam ARB_INDEX_W = (ARB_TYPE==1) 
                           ? LOG2_NUM_CON_MP_P1
                           : LOG2_NUM_CON_MP;

// Width of Bus Priority Signals In case QOS if selected                           
 localparam  MASTER_BUS_PRIORITY_W = (ARB_TYPE==4) ? (`AXI_QOSW * NUM_CON_MP) : BUS_PRIORITY_W;


//----------------------------------------------------------------------
// LOCAL MACROS.
//----------------------------------------------------------------------

 `define REG_INTER_BLOCK_PATHS 0

//----------------------------------------------------------------------
// PORT DECLARATIONS
//----------------------------------------------------------------------
  // Inputs - System.
  input aclk_i;    // AXI system clock.
  input aresetn_i; // AXI system reset.

  // Priorities from all visible masters.
  // Not used if ARB_TYPE == 4
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input [BUS_PRIORITY_W-1:0] bus_mst_priorities_i; 
           

  // Inputs - External Slave.
  // Ready from external slave(s).
  // Priorities from all visible masters.
  // Not used if Address block is shared
  input           ready_i; // Dedicated.
  input [NSS-1:0] bus_ready_shrd_i; // Shared.
  //spyglass enable_block W240

  // Outputs - External Slave.
  // Valid to external slave(s).
  output                valid_o; // Dedicated.
  output [NSS-1:0]      bus_valid_shrd_o; // Shared. 
  reg    [NSS-1:0]      bus_valid_shrd_o; 
  output [PYLD_S_W-1:0] payload_o; // Payload to external slave.

  // Inputs - Master Ports.
  // Read and write valid signals.
  // If SHARED==1, this signal will take a bus of shared channel 
  // requests from each master, this will be 1 bit for each master 
  // with that bit being asserted if the master decodes it is requesting
  // this shared layer.
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input [NUM_CON_MP-1:0] bus_arvalid_i;  
  input [NUM_CON_MP-1:0] bus_awvalid_i; 

                 
  // Shared channel valid inputs.
  // Bus of bus of valids from all masters that connect to this shared
  // layer. Valid for each slave, from each master.
  input [V_BUS_SHRD_W-1:0]   bus_arvalid_shrd_i;
  input [V_BUS_SHRD_W-1:0]   bus_awvalid_shrd_i;
                 
  input [BUS_PYLD_S_W-1:0]    bus_payload_i;   // Payload vectors from 
                                               // all visible master
                                               // ports.
  //spyglass enable_block W240

  // Outputs - Master Ports.
  // This signal is not used if the shared layer is performing all channel sink functions for this slave on the AR channel
  output [NUM_CON_MP-1:0]     bus_ready_o; // Ready to master ports.

  // Assert when the shared layer is granted here.
  // Only required for AW channel (deadlock condition).
  output shrd_lyr_granted_o; 

  // These signals are unused if 'Locking' feature is disabled in DW_axi_sp_lockarb.v file
  // Input - Read or Write Address Channel.
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input outstnd_txs_fed_i; // Falling edge detect on outstnd_txs 
                           // signal in other address channel.

  input outstnd_txs_nonlkd_i; // Signal from other address channel 
                              // block, asserted when there are 
                              // outstanding non locked transactions to
                              // the slave in this channel.

  input unlocking_tx_rcvd_i; // Asserted from other address channel when 
                             // it has received the unlocking 
                             // transaction.

  // 1-hot grant and local granted master numbers from the other 
  // address channel blocks arbiter. 
  input [NUM_CON_MP-1:0]      bus_grant_arb_i;     
  input [LOG2_NUM_CON_MP-1:0] grant_m_local_arb_i; 
  
  input                    lock_i; // Lock input from the other
                                   // address channel block.
  
  
  //spyglass enable_block W240
  // Output - Read or Write Address Channel.
  output outstnd_txs_fed_o; // Falling edge detect on outstnd_txs 
                            // signal to other address channel.
  
  output outstnd_txs_nonlkd_o; // Signal to other address channel block,
                               // asserted when there are outstanding 
                               // non locked transactions to the slave 
                               // in this channel.
  
  output unlocking_tx_rcvd_o; // Asserted when this channel has 
                              // received the unlocking transaction.

  output lock_o; // Lock input to the other
                 // address channel block.

  // 1-hot grant and local granted master numbers from this address
  // channels arbiter.
  output [NUM_CON_MP-1:0]      bus_grant_arb_o;     
  output [LOG2_NUM_CON_MP-1:0] grant_m_local_arb_o; 
  

  // Inputs - Read Data or Burst Response Channel.
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input cpl_tx_i; // Transaction completed signal.

  // Per slave transaction completed signals for a shared channel.
  input [NSS-1:0] cpl_tx_shrd_bus_i; 
  //spyglass enable_block W240

  // Outputs - Write Data Channel.
  output issued_tx_o; // Asserted by address channel when command has 
                      // been issued.

  // Signifys the master number whose transaction has been issued with
  // issued_tx_o.
  output [LOG2_NUM_VIS_MP-1:0] issued_mstnum_o; 

  // Bit for each slave on shared AW bus (applies to writes only),
  // asserted when a t/x for that slave has been issued.
  // This signal is used only for write address channels and unused for Read address channels.

  output [NSS-1:0] issued_tx_shrd_slv_oh_o;

  // Bit for each master asserted for the master that wins arbitration.
  output [NUM_CON_MP-1:0] issued_tx_mst_oh_o;


  //--------------------------------------------------------------------
  // REGISTER VARIABLES.
  //--------------------------------------------------------------------
  //reg cpl_tx_r; // Registered version of cpl_tx_i.

  // If address channel is not shared this register is not used
  reg waiting_for_tx_acc_r; // Reg to tell us when we are waiting for 
                            // a t/x to be accepted.
  // Register sliced version of bus_grant, used to generate 
  // issued_tx_mst_oh_o.
  reg [NUM_CON_MP-1:0] bus_grant_rs_r; 
  
  // Register version of bus_valid_shrd;                            
  reg [V_BUS_SHRD_W-1:0] bus_valid_shrd_r; 

  // Max sized bus of all AXI_S*_ON_W_SHARED_ONLY parameters.
  wire [`AXI_MAX_NUM_MST_SLVS-1:0] s_on_w_shrd_only_bus_max;
  // Max sized bus of all AXI_S*_ON_AW_SHARED_VAL parameters.
  wire [`AXI_MAX_NUM_MST_SLVS-1:0] s_on_aw_shrd_bus_max;
  // Above sized for NSS (number of slaves connected to shared AW).
  reg [NSS-1:0] s_on_w_shrd_only_s_bus;
  //--------------------------------------------------------------------
  // WIRE VARIABLES.
  //--------------------------------------------------------------------
  
  wire [NSS-1:0] cpl_tx_shrd_bus_mux; 
  // Local granted master number and grant outputs from the 
  // DW_axi_sp_lockarb block.
  wire [LOG2_NUM_CON_MP-1:0] grant_m_local;    
  wire [NUM_CON_MP-1:0]      bus_grant;    
  wire                       grant; 

  // bus_arvalid_shrd_i or bus_awvalid_shrd_i chosen by WCH parameter.
  wire [V_BUS_SHRD_W-1:0] bus_valid_shrd; 

  // Selected from bus_valid_shrd and bus_valid_shrd_mux dependant
  // on PL_ARB parameter.
  wire [V_BUS_SHRD_W-1:0] bus_valid_shrd_mux; 
  
  // Valid per slave from granted master.
  wire [NSS-1:0] bus_valid_shrd_grnt_mux; 
  wire tx_acc_s; // Asserted when when a transfer has been accepted by 
                 // the slave.

  wire ready_shrd_mux; // Selected from bus of ready signals of all 
                       // slaves on the shared channel.
  
  wire ready_shrd_ddctd_mux; // Selected between ready_i and
                             // ready_shrd_mux depending on SHARED 
                             // parameter.
                             
  //--------------------------------------------------------------------
  // Multi cycle arbitration signals.
  //--------------------------------------------------------------------

  // Signal for each slave attached to the shared layer, asserted when
  // the max configured amount of attached t/x's are outstanding in the
  // slave.
  wire max_fac_s0;
  wire max_fac_s1;
  wire max_fac_s2;
  wire max_fac_s3;
  wire max_fac_s4;
  wire max_fac_s5;
  wire max_fac_s6;
  wire max_fac_s7;
  wire max_fac_s8;
  wire max_fac_s9;
  wire max_fac_s10;
  wire max_fac_s11;
  wire max_fac_s12;
  wire max_fac_s13;
  wire max_fac_s14;
  wire max_fac_s15;
  wire max_fac_s16;
               
  // Tx count non zero bit for each attached slave.
  wire tx_cnt_nz_s0;
  wire tx_cnt_nz_s1;
  wire tx_cnt_nz_s2;
  wire tx_cnt_nz_s3;
  wire tx_cnt_nz_s4;
  wire tx_cnt_nz_s5;
  wire tx_cnt_nz_s6;
  wire tx_cnt_nz_s7;
  wire tx_cnt_nz_s8;
  wire tx_cnt_nz_s9;
  wire tx_cnt_nz_s10;
  wire tx_cnt_nz_s11;
  wire tx_cnt_nz_s12;
  wire tx_cnt_nz_s13;
  wire tx_cnt_nz_s14;
  wire tx_cnt_nz_s15;
  wire tx_cnt_nz_s16;

  // Max sized bus of all max_fac_s* signals.
  wire [`AXI_MAX_NUM_MST_SLVS-1:0] max_fac_s_bus_max;
  // As above, but sized for attached slaves only.
  wire [NSS-1:0] max_fac_s_bus;

  // max_fac_s_bus masked to avoid masking when a slave is on the 
  // shared W, but there is only 1 master on the shared W layer.
  wire [NSS-1:0] max_fac_s_bus_masked;

  // Bit for each slave asserted when a t/x for that slave is accepted.
  wire [NSS-1:0] tx_acc_s_bus;
  wire [`AXI_MAX_NUM_MST_SLVS-1:0] tx_acc_s_bus_max;

  // Registered copy of cpl_tx_shrd_bus_i.
  reg [NSS-1:0] cpl_tx_shrd_bus_r; 
  
  // Max sized version of cpl_tx_shrd_bus_r.
  wire [`AXI_MAX_NUM_MST_SLVS-1:0] cpl_tx_r_bus_max;

  // Max sized bus of tx_cnt_nz_s* signals.
  wire [`AXI_MAX_NUM_MST_SLVS-1:0] tx_cnt_nz_s_bus_max;
  // Version of above sized for attached slaves only.
  wire [NSS-1:0] tx_cnt_nz_s_bus;

  // Mask bit for each master asserted if that master is attempting to
  // access a slave that has reached its outstanding t/x limit.
  // Seperate versions for ar & aw (due to locking). 
  wire [V_BUS_SHRD_W-1:0] bus_arvalid_shrd_mask;
  wire [V_BUS_SHRD_W-1:0] bus_awvalid_shrd_mask;

  // OR reduced, per master version of bus_*valid_shrd_mask.
  reg [NUM_CON_MP-1:0] arvalid_shrd_mask;
  reg [NUM_CON_MP-1:0] awvalid_shrd_mask;
  
  // bus_*valid_i with shared channel only pre arbiter max outstanding
  // t/x's per slave masking applied.
  wire [NUM_CON_MP-1:0] bus_arvalid_shrd_masked;  
  wire [NUM_CON_MP-1:0] bus_awvalid_shrd_masked; 

  // Non zero transaction count bit for the targeted slave only.
  wire tx_cnt_nz_target_slv;


  // Wires to/from shared layer internal register slice.
  wire [PYLD_S_W-1:0] payload_pre_irs; // Payload to external slave,
                                       // prior to internal reg slice.

  wire [NSS-1:0] bus_valid_shrd_masked; // Shared valid signals.

  wire ready_irs; // Ready from the internal register slice.

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


  // Registered valis from the irs_arbpl block.
  wire [NSS-1:0] bus_valid_irs_arbpl_r; 

  // Wires for unconnected module outputs.
  wire id_irs_unconn;
  wire local_slv_irs_unconn;
  wire shrd_ch_req_irs_unconn;

  wire irs_apl_id_unconn;
  wire irs_apl_local_slv_unconn;
  wire irs_apl_shrd_ch_req_unconn;
  wire [PYLD_S_W-1:0] irs_apl_payload_prereg_unconn;
  wire irs_apl_issued_wtx_shrd_mst_oh_unconn;




  // Use registered version of cpl_tx_i for timing performance reasons.
  //always @(posedge aclk_i or negedge aresetn_i)
  //begin : cpl_tx_r_PROC
  //  if(!aresetn_i) begin
  //    cpl_tx_r <= 1'b0;
  //  end else begin
  //    cpl_tx_r <= cpl_tx_i;
  //  end
  //end // cpl_tx_r_PROC

  wire cpl_tx_mux; 
  //assign cpl_tx_mux = `REG_INTER_BLOCK_PATHS ? cpl_tx_r : cpl_tx_i;
  assign cpl_tx_mux = cpl_tx_i;



  // Select incoming valid signals depending on which channel we are
  // implementing.
  assign bus_valid_shrd = WCH ? bus_awvalid_shrd_i : bus_arvalid_shrd_i;


  // Perform max active t/x masking prior to the arbiter. Requests for
  // slaves that have reached their max. outstanding t/x limit are 
  // masked. Masking pre arbiter means the entire shared channel does
  // not have to stop when one masked slave is accessed.
  // Note : Since if a write data link is shared, the corresponding 
  // AW channel link must also be shared (feature), if there is one 
  // master present here, there can only be 1 master present on the 
  // shared W layer. In this case write ordering processing is not
  // required, so the masking here which ensures the shared write 
  // ordering fifos do not overflow is not required.
  assign bus_arvalid_shrd_masked 
    = SHARED ? bus_arvalid_i & (~arvalid_shrd_mask | (NUM_CON_MP == 1))
             : bus_arvalid_i;

  assign bus_awvalid_shrd_masked 
    = SHARED ? bus_awvalid_i & (~awvalid_shrd_mask | (NUM_CON_MP == 1))
             : bus_awvalid_i;
 //priority signal for each master is assigned by payload topmost bits
 
 parameter  PAYLOAD_W_M =  BUS_PYLD_S_W/NUM_CON_MP;   

 reg        [MASTER_BUS_PRIORITY_W-1:0]     busmst_priorities_i ;
//Unconnected Net - false report by lint tool version 2011.12
//STAR 9000547353 is repotted for this , need remove this rule when lint
//tool issue is fixed
   always @(*) begin: BUSMST_PRIORITIES_PROC
    busmst_priorities_i = bus_mst_priorities_i;
   end
                  
             
  DW_axi_sp_lockarb
   
  #(ARB_TYPE,           // Arbitration type.
    NUM_CON_MP,         // Number of clients to arbiter.
    LOG2_NUM_CON_MP,    // Log base 2 of number of clients to the arbiter.
    LOG2_NUM_CON_MP_P1, // Log base 2 of (number of clients to the 
                        // arbiter + 1).
    PL_ARB,             // Pipeline arbiter ?
    MCA_EN,             // Has multi-cycle arbitration ?
    MCA_NC,             // Num. cycles in multi-cycle arbitration.
    MCA_NC_W,           // Log base 2 MCA_NC.
    MAX_FAC,            // Max. number of active commands to external
                        // slave.
    LOG2_MAX_FAC_P1,    // Log base 2 of MAX_FAC + 1.
    MASTER_BUS_PRIORITY_W,     // Width of bus containing priorities of all
                        // visible masters.
    LOCKING,            // Implement locking or not.         
    WCH,                // Is block part of a write channel or not. 
    SHARED              // Shared channel ?
  )
  U_DW_axi_sp_lockarb (
    // Inputs - System.
    .aclk_i                (aclk_i),
    .aresetn_i             (aresetn_i),
    .bus_mst_priorities_i  (busmst_priorities_i),

    // Inputs - Channel Source.
    .rreq_i                (bus_arvalid_shrd_masked),
    .wreq_i                (bus_awvalid_shrd_masked),
    .tx_cnt_nz_i           (tx_cnt_nz_target_slv),

    // Inputs - Channel Destination.
    .ready_i               (ready_shrd_ddctd_mux),

    // Inputs - Other address channel block.
    .outstnd_txs_fed_i     (outstnd_txs_fed_i),
    .outstnd_txs_nonlkd_i  (outstnd_txs_nonlkd_i),
    .unlocking_tx_rcvd_i   (unlocking_tx_rcvd_i),
    .bus_grant_arb_i       (bus_grant_arb_i),
    .grant_m_local_arb_i   (grant_m_local_arb_i),
    .lock_other_i          (lock_i),

    // Outputs - Other address channel block.
    .outstnd_txs_fed_o     (outstnd_txs_fed_o),
    .outstnd_txs_nonlkd_o  (outstnd_txs_nonlkd_o),
    .unlocking_tx_rcvd_o   (unlocking_tx_rcvd_o),
    .lock_o                (lock_o),
    .bus_grant_arb_o       (bus_grant_arb_o),
    .grant_m_local_arb_o   (grant_m_local_arb_o),

    // Inputs - Completion channel.
    .cpl_tx_i              (cpl_tx_mux),
  
    // Outputs - Channel Destination.
    .grant_o               (grant),
    .bus_grant_o           (bus_grant),
    .grant_m_local_o       (grant_m_local)
  );


  /*--------------------------------------------------------------------
   * Dedicated Valid Generation
   */

  // This block implements the slave port payload mux.
  // It selects the payload from the granted master port.
  DW_axi_busmux
  
  #(NUM_CON_MP,      // Number of inputs to the mux.
    PYLD_S_W,        // Width of each input to the mux.
    LOG2_NUM_CON_MP  // Width of select input for the mux.
  )
  U_busmux_payload (
    .sel  (grant_m_local),
    .din  (bus_payload_i), 
    .dout (payload_pre_irs) 
  );

  // Dedicated valid output is grant from the arbiter block.
  assign valid_o = SHARED ? 1'b0 : grant;
  

  /*--------------------------------------------------------------------
   * Shared Channel MAX_FAC Request Masking
   *
   * For a dedicated channel this is done post arbiter, but for a 
   * shared channel it should be done pre arbiter. The reason being 
   * that when a valid is masked because the slave being addressed is
   * already at its max outstanding command limit, if we mask after
   * the arbiter the entire shared channel is stalled, but if we mask
   * the request pre arbiter, only the master attempting to access the
   * slave which is at its limit will be masked, and the channel is 
   * free for other masters to access other slaves.
   */
   
  // Decode when a t/x is accepted for each slave.
  assign tx_acc_s_bus = bus_valid_shrd_masked & {NSS{ready_irs}};
  
  // Assign to max sized version.
  generate
   if (`AXI_MAX_NUM_MST_SLVS == NSS)
    assign tx_acc_s_bus_max = tx_acc_s_bus;
   else 
    assign tx_acc_s_bus_max = {{(`AXI_MAX_NUM_MST_SLVS - NSS){1'b0}},tx_acc_s_bus};
  endgenerate  
  
  // Use registered version of cpl_tx_shrd_bus_i for timing 
  // performance reasons.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : cpl_tx_shrd_bus_r_PROC
    if(!aresetn_i) begin
      cpl_tx_shrd_bus_r <= {NSS{1'b0}};
    end else begin
      cpl_tx_shrd_bus_r <= cpl_tx_shrd_bus_i;
    end
  end // cpl_tx_shrd_bus_r_PROC

  // Are inter channel paths configured to be registered.
  assign cpl_tx_shrd_bus_mux = 
    `REG_INTER_BLOCK_PATHS
    ? cpl_tx_shrd_bus_r 
    : cpl_tx_shrd_bus_i;

  // Assign to max sized version.
  generate
   if (`AXI_MAX_NUM_MST_SLVS == NSS)
    assign cpl_tx_r_bus_max = cpl_tx_shrd_bus_r;
   else 
    assign cpl_tx_r_bus_max = {{(`AXI_MAX_NUM_MST_SLVS - NSS){1'b0}},cpl_tx_shrd_bus_r};
  endgenerate 

  // Instantiate tx count modules for each slave, only the outputs of
  // modules relating to connected slaves will be used.
  // If PL_ARB == 0, pass 1 to get registered count outputs, if
  // PL_ARB == 1, then pass 0 to get unregistered outputs. This is
  // required due to the register after the arbiter in this case, which
  // means we have to generate new requests (with masking) 
  // during the current valid out cycle.
  generate
    if(SHARED & (NSS >= 1)) begin : gen_tx_cnt_nss1
      DW_axi_sp_addrch_tx_cnt
       
      #(LOG2_FAC_P1_S0, FAC_S0, (PL_ARB == 0)) U_tx_cnt0
      ( /* In  */ .clk_i(aclk_i), .resetn_i(aresetn_i), .tx_acc_i(tx_acc_s_bus_max[0]),
                  .tx_cpl_i(cpl_tx_r_bus_max[0]),
        /* Out */ .cnt_max_o(max_fac_s0), .cnt_nz_o(tx_cnt_nz_s0)
      );
    end
    else begin
    assign  max_fac_s0= 1'b0;
    assign  tx_cnt_nz_s0=1'b0;
    end      
    if(SHARED & (NSS >= 2)) begin : gen_tx_cnt_nss2
      DW_axi_sp_addrch_tx_cnt
       
      #(LOG2_FAC_P1_S1, FAC_S1, (PL_ARB == 0)) U_tx_cnt1
      ( /* In  */ .clk_i(aclk_i), .resetn_i(aresetn_i), .tx_acc_i(tx_acc_s_bus_max[1]),
                  .tx_cpl_i(cpl_tx_r_bus_max[1]),
        /* Out */ .cnt_max_o(max_fac_s1), .cnt_nz_o(tx_cnt_nz_s1)
      );
    end
    else begin
     assign max_fac_s1= 1'b0;
     assign tx_cnt_nz_s1=1'b0;
    end      
    if(SHARED & (NSS >= 3)) begin : gen_tx_cnt_nss3
      DW_axi_sp_addrch_tx_cnt
       
      #(LOG2_FAC_P1_S2, FAC_S2, (PL_ARB == 0)) U_tx_cnt2
      ( /* In  */ .clk_i(aclk_i), .resetn_i(aresetn_i), .tx_acc_i(tx_acc_s_bus_max[2]),
                  .tx_cpl_i(cpl_tx_r_bus_max[2]),
        /* Out */ .cnt_max_o(max_fac_s2), .cnt_nz_o(tx_cnt_nz_s2)
      );
    end
    else begin
     assign max_fac_s2= 1'b0;
     assign tx_cnt_nz_s2=1'b0;
    end      
    if(SHARED & (NSS >= 4)) begin : gen_tx_cnt_nss4
      DW_axi_sp_addrch_tx_cnt
       
      #(LOG2_FAC_P1_S3, FAC_S3, (PL_ARB == 0)) U_tx_cnt3
      ( /* In  */ .clk_i(aclk_i), .resetn_i(aresetn_i), .tx_acc_i(tx_acc_s_bus_max[3]),
                  .tx_cpl_i(cpl_tx_r_bus_max[3]),
        /* Out */ .cnt_max_o(max_fac_s3), .cnt_nz_o(tx_cnt_nz_s3)
      );
    end
    else begin
    assign  max_fac_s3= 1'b0;
    assign  tx_cnt_nz_s3=1'b0;
    end      
    if(SHARED & (NSS >= 5)) begin : gen_tx_cnt_nss5
      DW_axi_sp_addrch_tx_cnt
       
      #(LOG2_FAC_P1_S4, FAC_S4, (PL_ARB == 0)) U_tx_cnt4
      ( /* In  */ .clk_i(aclk_i), .resetn_i(aresetn_i), .tx_acc_i(tx_acc_s_bus_max[4]),
                  .tx_cpl_i(cpl_tx_r_bus_max[4]),
        /* Out */ .cnt_max_o(max_fac_s4), .cnt_nz_o(tx_cnt_nz_s4)
      );
    end
    else begin
     assign max_fac_s4= 1'b0;
     assign tx_cnt_nz_s4=1'b0;
    end      
    if(SHARED & (NSS >= 6)) begin : gen_tx_cnt_nss6
      DW_axi_sp_addrch_tx_cnt
       
      #(LOG2_FAC_P1_S5, FAC_S5, (PL_ARB == 0)) U_tx_cnt5
      ( /* In  */ .clk_i(aclk_i), .resetn_i(aresetn_i), .tx_acc_i(tx_acc_s_bus_max[5]),
                  .tx_cpl_i(cpl_tx_r_bus_max[5]),
        /* Out */ .cnt_max_o(max_fac_s5), .cnt_nz_o(tx_cnt_nz_s5)
      );
    end
    else begin
     assign max_fac_s5= 1'b0;
     assign tx_cnt_nz_s5=1'b0;
    end      
    if(SHARED & (NSS >= 7)) begin : gen_tx_cnt_nss7
      DW_axi_sp_addrch_tx_cnt
       
      #(LOG2_FAC_P1_S6, FAC_S6, (PL_ARB == 0)) U_tx_cnt6
      ( /* In  */ .clk_i(aclk_i), .resetn_i(aresetn_i), .tx_acc_i(tx_acc_s_bus_max[6]),
                  .tx_cpl_i(cpl_tx_r_bus_max[6]),
        /* Out */ .cnt_max_o(max_fac_s6), .cnt_nz_o(tx_cnt_nz_s6)
      );
    end
    else begin
     assign max_fac_s6= 1'b0;
     assign tx_cnt_nz_s6=1'b0;
    end      
    if(SHARED & (NSS >= 8)) begin : gen_tx_cnt_nss8
      DW_axi_sp_addrch_tx_cnt
       
      #(LOG2_FAC_P1_S7, FAC_S7, (PL_ARB == 0)) U_tx_cnt7
      ( /* In  */ .clk_i(aclk_i), .resetn_i(aresetn_i), .tx_acc_i(tx_acc_s_bus_max[7]),
                  .tx_cpl_i(cpl_tx_r_bus_max[7]),
        /* Out */ .cnt_max_o(max_fac_s7), .cnt_nz_o(tx_cnt_nz_s7)
      );
    end
    else begin
     assign  max_fac_s7= 1'b0;
     assign  tx_cnt_nz_s7=1'b0;
    end      
    if(SHARED & (NSS >= 9)) begin : gen_tx_cnt_nss9
      DW_axi_sp_addrch_tx_cnt
       
      #(LOG2_FAC_P1_S8, FAC_S8, (PL_ARB == 0)) U_tx_cnt8
      ( /* In  */ .clk_i(aclk_i), .resetn_i(aresetn_i), .tx_acc_i(tx_acc_s_bus_max[8]),
                  .tx_cpl_i(cpl_tx_r_bus_max[8]),
        /* Out */ .cnt_max_o(max_fac_s8), .cnt_nz_o(tx_cnt_nz_s8)
      );
    end
    else begin
     assign max_fac_s8= 1'b0;
     assign tx_cnt_nz_s8=1'b0;
    end      
    if(SHARED & (NSS >= 10)) begin : gen_tx_cnt_nss10
      DW_axi_sp_addrch_tx_cnt
       
      #(LOG2_FAC_P1_S9, FAC_S9, (PL_ARB == 0)) U_tx_cnt9
      ( /* In  */ .clk_i(aclk_i), .resetn_i(aresetn_i), .tx_acc_i(tx_acc_s_bus_max[9]),
                  .tx_cpl_i(cpl_tx_r_bus_max[9]),
        /* Out */ .cnt_max_o(max_fac_s9), .cnt_nz_o(tx_cnt_nz_s9)
      );
    end
    else begin
     assign max_fac_s9= 1'b0;
     assign tx_cnt_nz_s9=1'b0;
    end      
    if(SHARED & (NSS >= 11)) begin : gen_tx_cnt_nss11
      DW_axi_sp_addrch_tx_cnt
       
      #(LOG2_FAC_P1_S10, FAC_S10, (PL_ARB == 0)) U_tx_cnt10
      ( /* In  */ .clk_i(aclk_i), .resetn_i(aresetn_i), .tx_acc_i(tx_acc_s_bus_max[10]),
                  .tx_cpl_i(cpl_tx_r_bus_max[10]),
        /* Out */ .cnt_max_o(max_fac_s10), .cnt_nz_o(tx_cnt_nz_s10)
      );
    end
    else begin
     assign  max_fac_s10= 1'b0;
     assign  tx_cnt_nz_s10=1'b0;
    end      
    if(SHARED & (NSS >= 12)) begin : gen_tx_cnt_nss12
      DW_axi_sp_addrch_tx_cnt
       
      #(LOG2_FAC_P1_S11, FAC_S11, (PL_ARB == 0)) U_tx_cnt11
      ( /* In  */ .clk_i(aclk_i), .resetn_i(aresetn_i), .tx_acc_i(tx_acc_s_bus_max[11]),
                  .tx_cpl_i(cpl_tx_r_bus_max[11]),
        /* Out */ .cnt_max_o(max_fac_s11), .cnt_nz_o(tx_cnt_nz_s11)
      );
    end
    else begin
     assign max_fac_s11= 1'b0;
     assign tx_cnt_nz_s11=1'b0;
    end      
    if(SHARED & (NSS >= 13)) begin : gen_tx_cnt_nss13
      DW_axi_sp_addrch_tx_cnt
       
      #(LOG2_FAC_P1_S12, FAC_S12, (PL_ARB == 0)) U_tx_cnt12
      ( /* In  */ .clk_i(aclk_i), .resetn_i(aresetn_i), .tx_acc_i(tx_acc_s_bus_max[12]),
                  .tx_cpl_i(cpl_tx_r_bus_max[12]),
        /* Out */ .cnt_max_o(max_fac_s12), .cnt_nz_o(tx_cnt_nz_s12)
      );
    end
    else begin
     assign  max_fac_s12= 1'b0;
     assign  tx_cnt_nz_s12=1'b0;
    end      
    if(SHARED & (NSS >= 14)) begin : gen_tx_cnt_nss14
      DW_axi_sp_addrch_tx_cnt
       
      #(LOG2_FAC_P1_S13, FAC_S13, (PL_ARB == 0)) U_tx_cnt13
      ( /* In  */ .clk_i(aclk_i), .resetn_i(aresetn_i), .tx_acc_i(tx_acc_s_bus_max[13]),
                  .tx_cpl_i(cpl_tx_r_bus_max[13]),
        /* Out */ .cnt_max_o(max_fac_s13), .cnt_nz_o(tx_cnt_nz_s13)
      );
    end
    else begin
    assign  max_fac_s13= 1'b0;
    assign  tx_cnt_nz_s13=1'b0;
    end      
    if(SHARED & (NSS >= 15)) begin : gen_tx_cnt_nss15
      DW_axi_sp_addrch_tx_cnt
       
      #(LOG2_FAC_P1_S14, FAC_S14, (PL_ARB == 0)) U_tx_cnt14
      ( /* In  */ .clk_i(aclk_i), .resetn_i(aresetn_i), .tx_acc_i(tx_acc_s_bus_max[14]),
                  .tx_cpl_i(cpl_tx_r_bus_max[14]),
        /* Out */ .cnt_max_o(max_fac_s14), .cnt_nz_o(tx_cnt_nz_s14)
      );
    end
    else begin
    assign  max_fac_s14= 1'b0;
    assign  tx_cnt_nz_s14=1'b0;
    end      
    if(SHARED & (NSS >= 16)) begin : gen_tx_cnt_nss16
      DW_axi_sp_addrch_tx_cnt
       
      #(LOG2_FAC_P1_S15, FAC_S15, (PL_ARB == 0)) U_tx_cnt15
      ( /* In  */ .clk_i(aclk_i), .resetn_i(aresetn_i), .tx_acc_i(tx_acc_s_bus_max[15]),
                  .tx_cpl_i(cpl_tx_r_bus_max[15]),
        /* Out */ .cnt_max_o(max_fac_s15), .cnt_nz_o(tx_cnt_nz_s15)
      );
    end
    else begin
    assign  max_fac_s15= 1'b0;
    assign  tx_cnt_nz_s15=1'b0;
    end      
    if(SHARED & (NSS >= 17)) begin : gen_tx_cnt_nss17
      DW_axi_sp_addrch_tx_cnt
       
      #(LOG2_FAC_P1_S16, FAC_S16, (PL_ARB == 0)) U_tx_cnt16
      ( /* In  */ .clk_i(aclk_i), .resetn_i(aresetn_i), .tx_acc_i(tx_acc_s_bus_max[16]),
                  .tx_cpl_i(cpl_tx_r_bus_max[16]), 
        /* Out */ .cnt_max_o(max_fac_s16), .cnt_nz_o(tx_cnt_nz_s16)
      );
    end
    else begin
     assign max_fac_s16= 1'b0;
     assign tx_cnt_nz_s16=1'b0;
    end      
  endgenerate

  // Collect tx_cnt block outputs into busses.
  assign max_fac_s_bus_max = 
    {max_fac_s16,
     max_fac_s15,
     max_fac_s14,
     max_fac_s13,
     max_fac_s12,
     max_fac_s11,
     max_fac_s10,
     max_fac_s9,
     max_fac_s8,
     max_fac_s7,
     max_fac_s6,
     max_fac_s5,
     max_fac_s4,
     max_fac_s3,
     max_fac_s2,
     max_fac_s1,
     max_fac_s0
    };
  // Strip out the bits we need only.
  assign max_fac_s_bus = max_fac_s_bus_max[NSS-1:0];
  
  assign s_on_w_shrd_only_bus_max = 
    {(`AXI_S16_ON_W_SHARED_ONLY_VAL == 1),
     (`AXI_S15_ON_W_SHARED_ONLY_VAL == 1),
     (`AXI_S14_ON_W_SHARED_ONLY_VAL == 1),
     (`AXI_S13_ON_W_SHARED_ONLY_VAL == 1),
     (`AXI_S12_ON_W_SHARED_ONLY_VAL == 1),
     (`AXI_S11_ON_W_SHARED_ONLY_VAL == 1),
     (`AXI_S10_ON_W_SHARED_ONLY_VAL == 1),
     (`AXI_S9_ON_W_SHARED_ONLY_VAL == 1),
     (`AXI_S8_ON_W_SHARED_ONLY_VAL == 1),
     (`AXI_S7_ON_W_SHARED_ONLY_VAL == 1),
     (`AXI_S6_ON_W_SHARED_ONLY_VAL == 1),
     (`AXI_S5_ON_W_SHARED_ONLY_VAL == 1),
     (`AXI_S4_ON_W_SHARED_ONLY_VAL == 1),
     (`AXI_S3_ON_W_SHARED_ONLY_VAL == 1),
     (`AXI_S2_ON_W_SHARED_ONLY_VAL == 1),
     (`AXI_S1_ON_W_SHARED_ONLY_VAL == 1),
     (`AXI_S0_ON_W_SHARED_ONLY_VAL == 1)
    };

  assign s_on_aw_shrd_bus_max = 
    {(`AXI_S16_ON_AW_SHARED_VAL == 1),
     (`AXI_S15_ON_AW_SHARED_VAL == 1),
     (`AXI_S14_ON_AW_SHARED_VAL == 1),
     (`AXI_S13_ON_AW_SHARED_VAL == 1),
     (`AXI_S12_ON_AW_SHARED_VAL == 1),
     (`AXI_S11_ON_AW_SHARED_VAL == 1),
     (`AXI_S10_ON_AW_SHARED_VAL == 1),
     (`AXI_S9_ON_AW_SHARED_VAL == 1),
     (`AXI_S8_ON_AW_SHARED_VAL == 1),
     (`AXI_S7_ON_AW_SHARED_VAL == 1),
     (`AXI_S6_ON_AW_SHARED_VAL == 1),
     (`AXI_S5_ON_AW_SHARED_VAL == 1),
     (`AXI_S4_ON_AW_SHARED_VAL == 1),
     (`AXI_S3_ON_AW_SHARED_VAL == 1),
     (`AXI_S2_ON_AW_SHARED_VAL == 1),
     (`AXI_S1_ON_AW_SHARED_VAL == 1),
     (`AXI_S0_ON_AW_SHARED_VAL == 1)
    };

  // Construct a signal which will use the relevant bit of 
  // s_on_w_shrd_only_bus_max for each slave on the AW shared layer.
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue.
  always @(*) begin : s_on_w_shrd_only_s_bus_PROC
    integer slv;
    integer shrd_slv;
    // jstokes, 10/2/2010, star 9000372365
    // shrd_slv integer variable initialised. Previosly was not
    // initialised which caused latches & a combinatorial loop.
    // NOTE : This code performs a static rewiring only - i.e.
    // no logic is inferred.
    shrd_slv = 0;
    s_on_w_shrd_only_s_bus = {NSS{1'b0}};
    // jstokes, 9.6.2010, 9000386264
    // Need to use this code only for configs where it is
    // required, otherwise array index out of bounds error
    // can occur.
    for(slv=0;slv<`AXI_MAX_NUM_MST_SLVS;slv=slv+1) begin
      if(s_on_aw_shrd_bus_max[slv]) begin
        s_on_w_shrd_only_s_bus[shrd_slv]
          = s_on_w_shrd_only_bus_max[slv];
        shrd_slv = shrd_slv + 1;
      end
    end
  end // s_on_w_shrd_only_s_bus_PROC
  //spyglass enable_block W415a

  // max_fac_s_bus masked to avoid masking when a slave is on the 
  // shared W only, but there is only 1 master on the shared W layer.
  // In this case only 1 master is visible to the slave, so write ordering
  // logic (and hence max active t/x masking) is not required.

  generate 
   if (SHARED & WCH)
   begin
    assign max_fac_s_bus_masked = 
      max_fac_s_bus
      & (~(  s_on_w_shrd_only_s_bus
          & {NSS{WCH & (`AXI_W_SHARED_LAYER_NM == 1) & `AXI_W_HAS_SHARED_LAYER}}
         ));
   end
   else
   begin
    assign max_fac_s_bus_masked = 
      max_fac_s_bus
      & (~(  {NSS{1'b0}}
          & {NSS{WCH & (`AXI_W_SHARED_LAYER_NM == 1) & `AXI_W_HAS_SHARED_LAYER}}
         ));
   end
  endgenerate

  assign tx_cnt_nz_s_bus_max = 
    {tx_cnt_nz_s16,
     tx_cnt_nz_s15,
     tx_cnt_nz_s14,
     tx_cnt_nz_s13,
     tx_cnt_nz_s12,
     tx_cnt_nz_s11,
     tx_cnt_nz_s10,
     tx_cnt_nz_s9,
     tx_cnt_nz_s8,
     tx_cnt_nz_s7,
     tx_cnt_nz_s6,
     tx_cnt_nz_s5,
     tx_cnt_nz_s4,
     tx_cnt_nz_s3,
     tx_cnt_nz_s2,
     tx_cnt_nz_s1,
     tx_cnt_nz_s0
    };
  // Strip out the bits we need only.
  assign tx_cnt_nz_s_bus = tx_cnt_nz_s_bus_max[NSS-1:0];

  // Decode a non zero transaction count bit for the targeted slave only.
  // bus_valid_shrd_maskd represents the per slave valid signals from the
  // winning master, so by AND'ing with the per slave non zero token 
  // count bits, we will have a 1 remaining only if the addressed slave
  // has a non zero transaction count.
  generate
   if (NSS > 1)
     assign tx_cnt_nz_target_slv = ~(|(tx_cnt_nz_s_bus & bus_valid_shrd_masked));
   else
     assign tx_cnt_nz_target_slv = ~(tx_cnt_nz_s_bus & bus_valid_shrd_masked);
  endgenerate

  // Decode a mask bit for each master, asserted if that master is
  // attempting to access a slave that has reached its outstanding t/x
  // limit.
  assign bus_arvalid_shrd_mask
    = {NUM_CON_MP{max_fac_s_bus_masked}} & bus_arvalid_shrd_i;
  assign bus_awvalid_shrd_mask
    = {NUM_CON_MP{max_fac_s_bus_masked}} & bus_awvalid_shrd_i;

  // OR reduce the above signals to have 1 bit per master.
  integer i;
  integer j;
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue.
  //spyglass disable_block SelfDeterminedExpr-ML
  //SMD: Self determined expression found
  //SJ : The expression indexing the vector/array will never exceed the bound of the vector/array.        
  always @(*) begin : arwvalid_shrd_mask_PROC
    arvalid_shrd_mask = {NUM_CON_MP{1'b0}};
    awvalid_shrd_mask = {NUM_CON_MP{1'b0}};
    for(i=0 ; i<NUM_CON_MP ; i=i+1) begin
      for(j=0 ; j<NSS ; j=j+1) begin
        arvalid_shrd_mask[i]
          =   arvalid_shrd_mask[i] 
            | bus_arvalid_shrd_mask[j+(i*NSS)];
        awvalid_shrd_mask[i] 
          =   awvalid_shrd_mask[i] 
            | bus_awvalid_shrd_mask[j+(i*NSS)];
      end
    end
  end // arwvalid_shrd_mask_PROC
  //spyglass enable_block SelfDeterminedExpr-ML      
  //spyglass enable_block W415a


  /*--------------------------------------------------------------------
   * Shared Valid Generation
   */

  // Register bus_valid_shrd to align with the rest of the channel signals.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : bus_valid_shrd_r_PROC
    if(~aresetn_i) begin
      bus_valid_shrd_r <= {V_BUS_SHRD_W{1'b0}};
    end else begin
      bus_valid_shrd_r <= bus_valid_shrd;
    end
  end // bus_valid_shrd_r_PROC

  // If multi cycle arbitration is being used and the arbiter
  // pipeline stage is enabled then we must use registered valid
  // signals here to align valid with the buffered payload.
  assign bus_valid_shrd_mux = PL_ARB 
                             ? bus_valid_shrd_r 
                             : bus_valid_shrd;


  /*--------------------------------------------------------------------
   * Shared channel valid out select.
   * Selects slave valid signals from the granted master, note that 
   * for each master we have a bus of valid signals with valid for the
   * addressed slave asserted.
   */
  DW_axi_busmux
  
  #(NUM_CON_MP,      // Number of inputs to the mux.
    NSS,             // Width of each input to the mux.
    LOG2_NUM_CON_MP  // Width of select input for the mux.
  )
  U_busmux_shrd_vld (
    .sel  (grant_m_local),
    .din  (bus_valid_shrd_mux), 
    .dout (bus_valid_shrd_grnt_mux) 
  );
  
  // Mask the multiplexed valid bus with grant from the arbiter, so 
  // valids are only asserted when a request has been made to the 
  // arbiter.
  assign bus_valid_shrd_masked 
    = SHARED 
      ? (  bus_valid_shrd_grnt_mux 
         & {NSS{grant}}
        )
      : {NSS{1'b0}};
  

  /*--------------------------------------------------------------------
   * Generate transaction issued signals.
   *
   * Sent to write data channels where they are used to implement
   * write data ordering rules.
   *
   * There are 2 reasons why the t/x issued signal are generated
   * post pipeline stage for a shared layer.
   *
   * 1.
   * Transaction issued signals to the shared write data 
   * channels must be generated from after the register slice here if
   * if the pipeline stage is selected, and if any of the 
   * attached slaves also have a dedicated write address channel 
   * (shared to dedicated link). This is necessary as in this 
   * case the dedicated write data channel must combine the
   * shared aw channel granted master number and dedicated aw 
   * channel number to create a single local master number to
   * use to implement ordering rules. For this to work, the
   * t/x issued signals from here must be valid when the t/x
   * from here is issued at the dedicated aw channel. 
   * Generating the signals post register slice performs this 
   * task.
   *
   * 2. 
   * If any pipeline stages exist on the shared layer, then the 
   * t/x issued signals must be generated post pipeline stages.
   * If generated pre pipeline, if a t/x that asserts the tx_issued
   * signals is held up in the pipeline, the t/x issued signals 
   * may allow the write to complete before the address has been
   * issued, or accepted into the pipeline stages. Then when the 
   * completion signal for the t/x arrives here, it will decrement
   * the t/x counter for the addresses slave. But since the address
   * transfer was not issued the counter will not have been
   * incremented for this t/x, and the completion (which decrements
   * the counter) may cause it to wrap around, after which it will
   * be out of sync with the system. Bus deadlock will eventually
   * occur from this point.
   */

  // Asserted if issued_tx_shrd* signals should be generated post
  // register slice.
  wire rs_issued_tx_shrd; 
  assign rs_issued_tx_shrd = (SHARED_PL | SHARED_ARB_PL_IRS);



  // Register signal to tell us when we are waiting for a t/x to
  // be accepted.
  // Generated from post register slice signals if tx_issued signals
  // are generated post register slice.
  // waiting_for_tx_acc_r signal not used in read channel instantiations
  generate
   if (NSS == 1)
   begin
    always @(negedge aresetn_i or posedge aclk_i) 
    begin : waiting_for_tx_acc_r_PROC 
      if(!aresetn_i) begin
        waiting_for_tx_acc_r <= 1'b0;
      end else begin
        if(waiting_for_tx_acc_r) begin
          // T/x accepted.
       // `ifdef SNPS_RCE_INTERNAL_ON
         /**ccx_cond: ; ; 0 ; rs_issued_tx_shrd is derrived from the parameters, if the chanel is shared then this signal is true.*/
        //`endif
          waiting_for_tx_acc_r 
            <= rs_issued_tx_shrd 
               ? (~(  (bus_ready_shrd_i & bus_valid_shrd_o)
                  ))
               : (~ready_shrd_ddctd_mux);
        end else begin  
          // Set this register if valid is asserted and not accepted.
          // Use grant signal instead of valid_o, as valid_o will assert
          // in dedicated (SHARED=0) mode only, whereas grant from the
          // arbiter will always assert if any valid input is asserted.
        //`ifdef SNPS_RCE_INTERNAL_ON
         /**ccx_cond: ; ; 0 ; rs_issued_tx_shrd is derrived from the parameters, if the chanel is shared then this signal is true. --condition_no_to_update.*/
        //`endif 
          waiting_for_tx_acc_r 
            <= SHARED
               ? ( rs_issued_tx_shrd 
                   ? (   (bus_valid_shrd_o) 
                       & (~(bus_ready_shrd_i & bus_valid_shrd_o))
                     )
                   : bus_valid_shrd_masked & (~ready_shrd_ddctd_mux)
                 )
               : valid_o & (!ready_shrd_ddctd_mux);
        end
      end
    end // waiting_for_tx_acc_r_PROC  
   end
   else
   begin
    always @(negedge aresetn_i or posedge aclk_i) 
    begin : waiting_for_tx_acc_r_PROC 
      if(!aresetn_i) begin
        waiting_for_tx_acc_r <= 1'b0;
      end else begin
        if(waiting_for_tx_acc_r) begin
          // T/x accepted.
       //`ifdef SNPS_RCE_INTERNAL_ON
        /**ccx_cond: ; ; 0 ; rs_issued_tx_shrd is derrived from the parameters, if the chanel is shared then this signal is true.  --condition_no_to_update. */
       //`endif
          waiting_for_tx_acc_r 
            <= rs_issued_tx_shrd 
               ? (~(  (|(bus_ready_shrd_i & bus_valid_shrd_o))
                  ))
               : (~ready_shrd_ddctd_mux);
        end else begin  
          // Set this register if valid is asserted and not accepted.
          // Use grant signal instead of valid_o, as valid_o will assert
          // in dedicated (SHARED=0) mode only, whereas grant from the
          // arbiter will always assert if any valid input is asserted.
          waiting_for_tx_acc_r 
            <= SHARED
               ? ( rs_issued_tx_shrd 
                   ? (   (|bus_valid_shrd_o) 
                       & (~(|(bus_ready_shrd_i & bus_valid_shrd_o)))
                     )
                   : (|bus_valid_shrd_masked) & (~ready_shrd_ddctd_mux)
                 )
               : valid_o & (!ready_shrd_ddctd_mux);
        end
      end
    end // waiting_for_tx_acc_r_PROC 
   end
  endgenerate
  
  // Assert this output when a transaction has been issued from the 
  // slave port. Valid asserted for new t/x, i.e. not waiting for
  // previous to be accepted.
  assign issued_tx_o = grant & (!waiting_for_tx_acc_r);
  
  // Bit for each slave on shared AW bus (applies to writes only),
  // asserted when a t/x for that slave has been issued.
  assign issued_tx_shrd_slv_oh_o 
    = SHARED
      ? ( rs_issued_tx_shrd 
          ? bus_valid_shrd_o & {NSS{~waiting_for_tx_acc_r}}
          : bus_valid_shrd_masked & {NSS{~waiting_for_tx_acc_r}}
        )
      : {NSS{1'b0}};


  /* -------------------------------------------------------------------
  * Bit for each master asserted for the master that wins arbitration
  * here. 
  *
  * For shared channel instances, used to tell dedicated write data 
  * channels which master issued a t/x to which slave.
  *
  * For dedicated address channel instances with a shared to dedicated
  * layer link, used to decode local master number at connected write
  * data channels.
  *
  * When a shared to dedicated link exists, we must translate the grant
  * outputs from this arbiter to a value that represents all masters
  * visible here. For example, 10 masters may be visible here, 2 through
  * the dedicated channel and 8 from the shared channel. The arbiter
  * outputs will be 0, 1 or 2 (shared layer request), and we must
  * translate this to the correct local master number values from 1 to 
  * 10. This translation is done at the top level with ifdefs.
  */
  assign issued_tx_mst_oh_o 
    = SHARED
        // For shared channel, need to align this signal with the
        // shared channel pipeline(s) if there is a link with any
        // dedicated channels. 
      ? ( rs_issued_tx_shrd 
          ? bus_grant_rs_r
          : bus_grant
        )
      : ( HAS_SHRD_DDCTD_LNK
          ? bus_grant
          : {NUM_CON_MP{1'b0}}
        ); 

  // Local master number who's transaction was accepted with assertion 
  // of issued_tx_o. With of this signal is always LOG2_NUM_VIS_MP
  // width, so it is always the same width as the corresponding W
  // channel input, the signal is only used if this dedicated channel
  // is visible to the same number of masters that is connected to.
  generate
   if (NUM_CON_MP != NUM_VIS_MP)
    assign issued_mstnum_o = {LOG2_NUM_VIS_MP{1'b0}}; 
   else
    assign issued_mstnum_o = grant_m_local;
  endgenerate


  /*--------------------------------------------------------------------
   * Create a register slice for bus_grant.
   * Used in generation of issued_tx_mst_oh_o.
   */
  always @(posedge aclk_i or negedge aresetn_i) 
  begin : bus_grant_rs_r_PROC
    if(~aresetn_i) begin
      bus_grant_rs_r <= {NUM_CON_MP{1'b0}};
    end else begin
      if(ready_irs_in | (~(|bus_grant_rs_r))) begin
        bus_grant_rs_r <= bus_grant;
      end
    end
  end // bus_grant_rs_r_PROC
 

  /*--------------------------------------------------------------------
   * Decode bus_ready_o.
   * Each bit of bus_ready_o applies to 1 master port only.
   * bus_grant comes from the arbiter and has 1 bit per master port
   * also. By doing a bitwise and of valid_o with bus_grant
   * we get a bus of ready signals for each master port, where ready
   * will only be asserted if the master port is sending a 
   * transfer to this channel, has won arbitration, and the slave
   * has accepted with ready high.
   * Note that for a shared channel we first need to select the ready
   * input of the addressed slave, this is done before the 
   * shared layer internal register slice and the output comes here
   * as ready_irs.
   */

  // Select the correct final ready bit from the attached slave(s)
  // depending on whether this is a shared channel or dedicated.
  assign ready_shrd_ddctd_mux = SHARED ? ready_irs : ready_i;

  assign tx_acc_s = SHARED 
                    ? (grant & ready_irs)
                    : (valid_o & ready_i);

  assign bus_ready_o = {NUM_CON_MP{tx_acc_s}} & bus_grant;


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
  U_DW_axi_irs_sp_a_shrd (
    // Inputs - System.
    .aclk_i        (aclk_i),
    .aresetn_i     (aresetn_i),

    // Inputs - Payload source.
    .payload_i     (payload_pre_irs),
    .bus_valid_i   (bus_valid_shrd_masked),
    .valid_i       (grant),
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
    {(HAS_DDCTD_S16 == 1),
     (HAS_DDCTD_S15 == 1),
     (HAS_DDCTD_S14 == 1),
     (HAS_DDCTD_S13 == 1),
     (HAS_DDCTD_S12 == 1),
     (HAS_DDCTD_S11 == 1),
     (HAS_DDCTD_S10 == 1),
     (HAS_DDCTD_S9 == 1),
     (HAS_DDCTD_S8 == 1),
     (HAS_DDCTD_S7 == 1),
     (HAS_DDCTD_S6 == 1),
     (HAS_DDCTD_S5 == 1),
     (HAS_DDCTD_S4 == 1),
     (HAS_DDCTD_S3 == 1),
     (HAS_DDCTD_S2 == 1),
     (HAS_DDCTD_S1 == 1),
     (HAS_DDCTD_S0 == 1)
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
  U_DW_axi_irs_arbpl_sp_a_shrd (
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
    .bus_valid_r_o            (bus_valid_irs_arbpl_r),
    .payload_o                (payload_irs_arbpl),
    
    // Outputs - Unconnected.
    .id_o                     (irs_apl_id_unconn),
    .local_slv_o              (irs_apl_local_slv_unconn),
    .shrd_ch_req_o            (irs_apl_shrd_ch_req_unconn),
    .issued_wtx_shrd_mst_oh_o (irs_apl_issued_wtx_shrd_mst_oh_unconn),
    .payload_prereg_o         (irs_apl_payload_prereg_unconn) 
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
   if (NSS==1)
    assign any_valid_irs_arbpl = (bus_valid_irs_arbpl);
   else
    assign any_valid_irs_arbpl = (|(bus_valid_irs_arbpl));
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
      ? ( (|(has_ddctd_s_bus & bus_valid_irs))
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
      if(has_ddctd_s_bus[slv] & SHARED_ARB_PL_IRS) begin
        bus_ready_irs_arbpl_in[slv] = bus_ready_shrd_i[slv];
      end else begin
        bus_ready_irs_arbpl_in[slv] = 1'b0;
      end
    end
  end // bus_ready_irs_arbpl_in_PROC
  //spyglass enable_block W224
  //spyglass enable_block STARC05-2.1.5.3
  

  // Assert for 1 cycle when a t/x from the shared layer
  // is issued here. Only required for AW channel 
  // (deadlock condition avoidance logic).
  assign shrd_lyr_granted_o 
    = WCH & HAS_SHRD_DDCTD_LNK & bus_grant[NUM_CON_MP-1] 
      & (valid_o & (~waiting_for_tx_acc_r));

endmodule

