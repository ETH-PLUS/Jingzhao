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
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_mp_drespch.v#11 $ 
**
** ---------------------------------------------------------------------
**
** File     : DW_axi_mp_drespch.v
//
//
** Created  : Tue May 24 17:09:09 MEST 2005
** Modified : $Date: 2020/03/22 $
** Abstract : Seperate instantiations of this block will implement 
**            the master port read data and burst response channels.
**
** ---------------------------------------------------------------------
*/


module DW_axi_mp_drespch (
  // Inputs - System.  
  aclk_i,
  aresetn_i,

  bus_slv_priorities_i,

  // Inputs - External Master.  
  ready_i,
  bus_ready_shrd_i,

  // Outputs - External Master.  
  valid_o,
  bus_valid_shrd_o,
  payload_o,
  payload_icm_o,
    
  // Inputs - Slave Ports.  
  bus_valid_i,
  bus_valid_shrd_i,
  bus_payload_i,
    
  // Outputs - Slave Ports.  
  bus_ready_o,

  // Inputs - Address channel.
  //act_snums_i,
    
  // Outputs - Read address channel.  
  cpl_tx_o,
  cpl_tx_shrd_bus_o,
  cpl_id_o
);

   
//----------------------------------------------------------------------
// MODULE PARAMETERS.
//----------------------------------------------------------------------
  parameter ICM_PORT = 0;         // Interconnecting master port config
  parameter NUM_VIS_SP = 16; // Number of visible slave ports.

  parameter LOG2_NUM_VIS_SP = 4; // Log 2 of NUM_VIS_SP.

  parameter LOG2_NUM_VIS_SP_P1 = 4; // Log 2 of (NUM_VIS_SP + 1).

  parameter PL_ARB = 0; // 1 to pipeline arbiter outputs.

  parameter MCA_EN = 0; // Enable multi cycle arbitration.

  parameter MCA_NC = 0; // Number of arb. cycles in multi cycle arb.

  parameter MCA_NC_W = 0; // Log base 2 of MCA_NC + 1.

  parameter ARB_TYPE = 0; // Arbitration type.

  parameter BUS_PYLD_S_W = (4*`AXI_R_PYLD_M_W);  // Width of bus with 
                                                 // payloads from all 
                                                 // visible slaves.

  parameter PYLD_M_W = `AXI_R_PYLD_M_W;  // Width of payload bus to 
                                         // master.

  parameter PYLD_S_W = `AXI_R_PYLD_M_W;  // Width of individual
                                         // payload bus from slave.
                                         // Not equal to PYLC_M_W
                                         // for configs w/ 
                                         // AXI_HAS_BICMD.

  parameter BUS_PRIORITY_W = 8;  // Width of bus with all visible slave 
                                 // prioritys.

  parameter MAX_UIDA = 4; // Maximum number of unique ID's that master
                          // may have outstanding transactions with.
        
  parameter LOG2_MAX_UIDA = 2; // Log base 2 of MAX_UIDA.

  parameter ACT_SNUMS_W = 8; // Width of active slave numbers bus.        

  parameter R_CH = 1; // This parameter is set to 1 if the block is 
                      // being used as part of a read data 
                      // channel.

  parameter RI_LIMIT = 0; // Set to 1 if read interleaving depth is
                          // limited to 0.

  /* -------------------------------------------------------------------                     
   * Shared Channel Parameters
   */
  // spyglass disable_block ReserveName
  // SMD: A reserve name has been used.
  // SJ: This parameter is local to this module. This is not passed to heirarchy below this module. hence, it will not cause any issue.
  parameter SHARED = 0; // Shared address channel block ?                     
  // spyglass enable_block ReserveName
  parameter NSM = 1; // Number of masters on this shared channel.

  parameter SHARED_PL = 0; // Pipeline in shared channel ?
  
  // 1 if the shared master has a dedicated channel also.
  parameter HAS_DDCTD_M0 = 1;
  parameter HAS_DDCTD_M1 = 1;
  parameter HAS_DDCTD_M2 = 1;
  parameter HAS_DDCTD_M3 = 1;
  parameter HAS_DDCTD_M4 = 1;
  parameter HAS_DDCTD_M5 = 1;
  parameter HAS_DDCTD_M6 = 1;
  parameter HAS_DDCTD_M7 = 1;
  parameter HAS_DDCTD_M8 = 1;
  parameter HAS_DDCTD_M9 = 1;
  parameter HAS_DDCTD_M10 = 1;
  parameter HAS_DDCTD_M11 = 1;
  parameter HAS_DDCTD_M12 = 1;
  parameter HAS_DDCTD_M13 = 1;
  parameter HAS_DDCTD_M14 = 1;
  parameter HAS_DDCTD_M15 = 1;

  localparam V_BUS_SHRD_W = NUM_VIS_SP*NSM;

  // Decode if there is any connection with a dedicated address channel.
  localparam HAS_DDCTD_LNK 
    =   (HAS_DDCTD_M0 == 1)
      | ((HAS_DDCTD_M1 == 1) & (NSM >= 1))
      | ((HAS_DDCTD_M2 == 1) & (NSM >= 2))
      | ((HAS_DDCTD_M3 == 1) & (NSM >= 3))
      | ((HAS_DDCTD_M4 == 1) & (NSM >= 4))
      | ((HAS_DDCTD_M5 == 1) & (NSM >= 5))
      | ((HAS_DDCTD_M6 == 1) & (NSM >= 6))
      | ((HAS_DDCTD_M7 == 1) & (NSM >= 7))
      | ((HAS_DDCTD_M8 == 1) & (NSM >= 8))
      | ((HAS_DDCTD_M9 == 1) & (NSM >= 9))
      | ((HAS_DDCTD_M10 == 1) & (NSM >= 10))
      | ((HAS_DDCTD_M11 == 1) & (NSM >= 11))
      | ((HAS_DDCTD_M12 == 1) & (NSM >= 12))
      | ((HAS_DDCTD_M13 == 1) & (NSM >= 13))
      | ((HAS_DDCTD_M14 == 1) & (NSM >= 14))
      | ((HAS_DDCTD_M15 == 1) & (NSM >= 15));

  // Is the DW_axi_irs_arbpl required to perform PL_ARB register slicing
  // here ?
  localparam SHARED_ARB_PL_IRS = SHARED & HAS_DDCTD_LNK & PL_ARB;
  
  // Width of arbiter internal grant index.                                
  localparam ARB_INDEX_W = (ARB_TYPE==1) 
                           ? LOG2_NUM_VIS_SP_P1 
                           : LOG2_NUM_VIS_SP;
  // Park mode paramter: to be used when there is only 1 slave in the configuration
  // and the other slave is a default slave.
  // In this mode park the arbitration to default slave, so that all the master port
  // does not recieve the payload from slave. 
  localparam ARB_PARK_MODE  = (NUM_VIS_SP == 2) ? 1: 0; 


//----------------------------------------------------------------------
// LOCAL MACROS.
//----------------------------------------------------------------------

  // If the number of unique ID values allowed is greater than the 
  // number of visible slave ports arbitrate per slave, otherwise
  // we can limit the arbiter to only arbitrate for the number
  // of unique ID values allowed. 
  // Note : we can do this because we only allow masters to use a
  // particular ID value to have outstanding transactions with 1 slave.

  //`define PER_SLAVE_ARBITRATION (MAX_UIDA>=NUM_VIS_SP)
  // Always do per slave arbitration, better for timing performance
  // than per unique ID arbitration with muxing around the arbiter.
  `define PER_SLAVE_ARBITRATION 1

  // Macros for arbiter parameters depending on whether we are 
  // arbitrating for all visible slaves or for the number of unique 
  // ID values.
  `define ARB_NC (`PER_SLAVE_ARBITRATION ? NUM_VIS_SP : MAX_UIDA)
  `define ARB_PRIOR_W     (`PER_SLAVE_ARBITRATION ? BUS_PRIORITY_W : (MAX_UIDA*`AXI_LOG2_NSP1))

  `define ARB_LOG2_NC (`PER_SLAVE_ARBITRATION ? LOG2_NUM_VIS_SP : LOG2_MAX_UIDA)

  // Note this value only works for per slave arbitration.
  // Since we never use per UIDA arbitration at the moment.
  `define ARB_LOG2_NC_P1 LOG2_NUM_VIS_SP_P1

  `define BUS_PORT_REQ_W (`PER_SLAVE_ARBITRATION ? (NUM_VIS_SP*LOG2_NUM_VIS_SP) : ACT_SNUMS_W)

  // Switch ID field macros depending on which channel is being
  // implemented.
  `define DRESPCH_ID_RHS ((R_CH==1) ? `AXI_RPYLD_ID_RHS_M : `AXI_BPYLD_ID_RHS_M)
  `define DRESPCH_ID_LHS ((R_CH==1) ? `AXI_RPYLD_ID_LHS_M : `AXI_BPYLD_ID_LHS_M)

  `define ID_W (`AXI_MIDW + ICM_PORT*(`AXI_LOG2_NM))

  // Width of payload for ICM ports, only used if SHARED==1.
  `define PYLD_ICM_W (PYLD_M_W + ICM_PORT*(`AXI_LOG2_NM))

//----------------------------------------------------------------------
// PORT DECLARATIONS
//----------------------------------------------------------------------

  // Inputs - System.
  input aclk_i;    // System AXI clock.
  input aresetn_i; // System AXI reset.

  input [BUS_PRIORITY_W-1:0] bus_slv_priorities_i; // Priority of all
                                                   // visible slaves.

  // Inputs - External Master.
  // Ready from external master(s).
  input           ready_i; // Dedicated.
  input [NSM-1:0] bus_ready_shrd_i; // Shared.

  // Outputs - External Master.
  // Valid to external master(s).
  output                 valid_o;   // Dedicated.
  output [NSM-1:0]       bus_valid_shrd_o; // Shared. 
  reg    [NSM-1:0]       bus_valid_shrd_o; //

  output [PYLD_M_W-1:0]  payload_o; // Payload vector to 
                                    // external master.

  // Payload vector to external ICM master.Note, used if SHARED==1 only
  // otherwise payload_o is used for both ICM ports and sys master ports.
  // Required because if this is a shared channel then both ICM and sys 
  // master ports can connect here.
  output [`PYLD_ICM_W-1:0]  payload_icm_o; 
  

  // Inputs - Slave Ports.
  // Valid in from slave ports.
  // If SHARED==1, this signal will take a bus of shared channel 
  // requests from each slave, this will be 1 bit for each slave 
  // with that bit being asserted if the slave decodes it is requesting
  // this shared layer.
  input [NUM_VIS_SP-1:0]   bus_valid_i;

  // Shared channel valid inputs.
  // Bus of bus of valids from all slaves that connect to this shared
  // layer. Valid for each master, from each slave.
  input [V_BUS_SHRD_W-1:0]   bus_valid_shrd_i;
  input [BUS_PYLD_S_W-1:0] bus_payload_i; // All payload vectors 
                                          // from visible slave
                                          // ports.
  // Inputs - Address channel.
  //input [ACT_SNUMS_W-1:0] act_snums_i; // Bus containing slave numbers
                                       // that the master has 
                                       // outstanding transactions 
                                       // with.

  // Outputs - Slave Ports.
  output [NUM_VIS_SP-1:0] bus_ready_o; // Ready signals, 1 for each
                                       // visible slave port.


  // Outputs - Read or Write Address Channel.            
  output                  cpl_tx_o; // Read and write transaction 

  // 1 signal per attached master, t/x completion signals.
  output [NSM-1:0]        cpl_tx_shrd_bus_o;

  output [`ID_W-1:0]      cpl_id_o; // completion signals. 


  //--------------------------------------------------------------------
  // REGISTER VARIABLES.
  //--------------------------------------------------------------------
  //reg [ACT_SNUMS_W-1:0] act_snums_r; // Registered version of 
                                     // act_snums_i.


  reg [PYLD_M_W-1:0] payload_sys_mst; // Payload signal with extra
                                      // bicm bits removed for a 
                                      // system master. (i.e. not an
                                      // interconnecting master)
  
  reg [NUM_VIS_SP-1:0] bus_valid_i_r; // Reg'd version of bus_valid_i.
  
  // Register version of bus_valid_shrd_i;                            
  reg [V_BUS_SHRD_W-1:0] bus_valid_shrd_r; 


  //--------------------------------------------------------------------
  // WIRE VARIABLES.
  //--------------------------------------------------------------------
  
  wire grant; // Grant signal from DW_axi_arb.
  wire [NUM_VIS_SP-1:0] bus_grant; // 1-hot grant bus.

  wire [LOG2_NUM_VIS_SP-1:0] grant_s_local; // Granted local slave 
                                            // number.
  wire tx_acc_s; // Asserted when when a transfer has been accepted by 
                 // the slave.
  
  // Selected from bus_valid_shrd_i and bus_valid_shrd_mux dependant
  // on PL_ARB parameter.
  wire [V_BUS_SHRD_W-1:0] bus_valid_shrd_mux; 
  
  // Valid per master from the granted slave.
  wire [NSM-1:0] bus_valid_shrd_grnt_mux; 
  
  wire ready_shrd_mux; // Selected from bus of ready signals of all 
                       // slaves on the shared channel.

  wire ready_shrd_ddctd_mux; // Selected between ready_i and
                             // ready_shrd_mux depending on SHARED 
                             // parameter.
                               
  //--------------------------------------------------------------------
  // Multi cycle arbitration signals.
  //--------------------------------------------------------------------
  wire valid_granted_mca; // Valid selected from the valid inputs by
                          // the registered grant index for multi 
                          // cycle arbitration.
  
  wire [NUM_VIS_SP-1:0] bus_valid_i_mux; // Selected from reg'd and un
                                         // reg'd valid inputs depending
                                         // on PL_ARB.

  // Wires to/from shared layer internal register slice.
  wire [PYLD_S_W-1:0] payload_pre_irs; // Payload to external master(s),
                                       // prior to internal reg slice.

  wire [NSM-1:0] bus_valid_shrd_grnt; // Shared valid signals.

  wire ready_irs; // Ready from the internal register slice.

  /*--------------------------------------------------------------------
   * Wires to/from both *_irs_* modules.
   */
  // Payload from DW_axi_irs.
  wire [PYLD_S_W-1:0] payload_irs; 
  // Payload from DW_axi_irs_arbpl.
  wire [PYLD_S_W-1:0] payload_irs_arbpl; 
  // Result of muxing between the *irs & *irs_arbpl payload signals.
  wire [PYLD_S_W-1:0] payload_irs_mux; 

  // Bus of valid inputs per slave for DW_axi_irs_arbpl.
  reg [NSM-1:0] bus_valid_irs_arbpl_in;

  // Bus of valid outputs per slave from DW_axi_irs.
  wire [NSM-1:0] bus_valid_irs;
  // Bus of valid outputs per slave from DW_axi_irs_arbpl.
  wire [NSM-1:0] bus_valid_irs_arbpl;

  // Ready output from DW_axi_irs_arbpl.
  wire ready_irs_arbpl;
  // Registered version of ready_irs_arbpl;
  reg ready_irs_arbpl_r;

  // Ready in to DW_axi_irs block.
  wire ready_irs_in;
  
  // Ready in to DW_axi_irs_arbpl block.
  reg [NSM-1:0] bus_ready_irs_arbpl_in;

  // Max sized bus of all HAS_DDCTD_M* parameters.
  wire [`AXI_MAX_NUM_MST_SLVS-2:0] has_ddctd_m_bus_max;
  // Above sized for NSM.
  wire [NSM-1:0] has_ddctd_m_bus;

  // Asserted if any valid output of irs_arbpl is asserted.
  wire any_valid_irs_arbpl;
  // Registered version of above.
  reg any_valid_irs_arbpl_r;

  // Wires for unconnected module outputs.
  wire id_irs_unconn;
  wire local_slv_irs_unconn;
  wire shrd_ch_req_irs_unconn;
  
  wire [NSM-1:0] irs_apl_bus_valid_r_unconn;
  wire irs_apl_id_unconn;
  wire irs_apl_local_slv_unconn;
  wire irs_apl_shrd_ch_req_unconn;
  wire [PYLD_S_W-1:0] irs_apl_payload_prereg_unconn;
  wire irs_apl_issued_wtx_shrd_mst_oh_unconn;
  wire [(`ARB_NC*ARB_INDEX_W)-1:0] bus_priority_unconn;

  /*
   * NOTE : This logic will only become useful if we decide to
   * limit the number of clients to this arbiter based on the
   * number of unique ID's.
   
  // Register act_snums_i for timing performance.
  always @(posedge aclk_i or negedge aresetn_i) 
  begin : act_snums_r_PROC
    if(!aresetn_i) begin
      act_snums_r <= {ACT_SNUMS_W{1'b0}};
    end else begin
      act_snums_r <= act_snums_i;
    end
  end // act_snums_r_PROC

  // Select valid input lines depending on which slave numbers
  // are active for each unique ID value.
  DW_axi_multibusmux
  #(NUM_VIS_SP,       // Number of inputs to the mux.
    1,                // Width of each input to the mux.
    LOG2_NUM_VIS_SP,  // Width of select line for the mux.
    MAX_UIDA          // Number of busmuxes to implement.
  )
  U_DW_axi_multibusmux_valid (
    .sel  (act_snums_r),
    .din  ({MAX_UIDA{bus_valid_i}}), 
    .dout (bus_valid_uida) 
  );
  
  // Select priority values for arbiter depending on which slave numbers
  // are active for each unique ID value.
  DW_axi_multibusmux
  #(NUM_VIS_SP,           // Number of inputs to the mux.
    `AXI_SLV_PRIORITY_W,  // Width of each input to the mux.
    LOG2_NUM_VIS_SP,      // Width of select line for the mux.
    MAX_UIDA              // Number of busmuxes to implement.
  )
  U_DW_axi_multibusmux_priority (
    .sel  (act_snums_r),
    .din  ({MAX_UIDA{bus_slv_priorities_i}}), 
    .dout (bus_priority_uida) 
  );
  */

  // Dummy wire for unrequired arbiter module output.

  DW_axi_arb
  
  #(ARB_TYPE,                 // Type of arbitration used.
    `ARB_NC,                  // Number of clients to arbiter.
    `ARB_LOG2_NC,             // Log base 2 of number of clients.
    `ARB_LOG2_NC_P1,          // Log base 2 of (number of clients + 1).
    PL_ARB,                   // Pipeline arbiter outputs.
    MCA_EN,                   // Has multi-cycle arbitration ?
    MCA_NC,                   // Num. cycles in multi-cycle arbitration.
    MCA_NC_W,                 // Log base 2 of MCA_NC.
    `AXI_MCA_HLD_PRIOR,       // Hold priorities for multi cycle arb.
    `AXI_SLV_PRIORITY_W,      // Priority width of a single slave.                 
    `ARB_PRIOR_W,             // Width of priorities bus.
    RI_LIMIT,                 // If read interleaving limit is true then
                              // lock arbitration to a client until a 
                              // burst completes.
    0                         // No locking features required here.
    ,ARB_PARK_MODE            // Park Mode
  )
  U_DW_axi_arb (
    // Inputs - System.
    .aclk_i               (aclk_i),
    .aresetn_i            (aresetn_i),
    .bus_priorities_i     (bus_slv_priorities_i),

    // Inputs - Channel Source.
    .lock_seq_i           (1'b0), // Not required here.
    .locktx_i             ({`ARB_NC{1'b0}}), // Not required here.
    .unlock_i             (1'b0), // Not required here.
    .grant_masked_i       (1'b0), // Not required here.

    // Not required here, next 2 inputs required on address
    // channels only.
    .use_other_pri_i      ({`ARB_NC{1'b0}}), 
    //.bus_grant_lock_i     ({`ARB_NC{1'b0}}),

    .request_i            (bus_valid_i),

    // Inputs - Channel Destination.
    .valid_i              (valid_o),
    .ready_i              (ready_shrd_ddctd_mux),
    .last_i               (payload_pre_irs[`AXI_RPYLD_LAST]),
  
    // Outputs - Channel Destination.
    .grant_o              (grant),
    .bus_grant_o          (bus_grant),
    .grant_p_local_o      (grant_s_local)
  );



  // This block implements the channel payload mux.
  // It selects the payload from the granted slave port.
  DW_axi_busmux
  
  #(NUM_VIS_SP,      // Number of inputs to the mux.
    PYLD_S_W,        // Width of each input to the mux.
    LOG2_NUM_VIS_SP  // Width of select input for the mux.
  )
  U_busmux_pyld (
    .sel  (grant_s_local),
    .din  (bus_payload_i), 
    .dout (payload_pre_irs) 
  );


  /*--------------------------------------------------------------------
   * Dedicated Valid Generation
   */

  // Register bus_valid_i to align with the rest of the channel signals.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : bus_valid_i_r_PROC
    if(~aresetn_i) begin
      bus_valid_i_r <= {NUM_VIS_SP{1'b0}};
    end else begin
      bus_valid_i_r <= bus_valid_i;
    end
  end // bus_valid_i_r_PROC

  // If multi cycle arbitration is being used and the arbiter
  // pipeline stage is enabled then we must use registered valid
  // signals here to align valid with the buffered payload.
  assign bus_valid_i_mux = PL_ARB ? bus_valid_i_r : bus_valid_i;


  // This mux selects the granted valid signal when multi cycle
  // arbitration has been selected for this channel at this port.
  DW_axi_busmux
  
  #(NUM_VIS_SP,      // Number of inputs to the mux.
    1,               // Width of each input to the mux.
    LOG2_NUM_VIS_SP  // Width of select input for the mux.
  )
  U_DW_axi_busmux_mca (
    .sel  (grant_s_local),
    .din  (bus_valid_i_mux), 
    .dout (valid_granted_mca) 
  );

  // Valid output is grant from the arbiter block.
  // or selected directly from the valid inputs for multi cycle
  // arbitration.
  // STAR 9000268934, 5/10/2008
  // If RI_LIMIT functionality is enabled we cannot use the grant from 
  // the arbiter as the valid output. With RI_LIMIT = 1, the grant indexes 
  // from the arbiter are held static but the grant output is still driven
  // directly from the arbiter, so another slaves request can hold grant
  // high even though the slave the grant indexes are held to is not
  // requesting. 
  assign valid_o = (MCA_EN | RI_LIMIT) ? valid_granted_mca : grant;


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
  
  #(NUM_VIS_SP,      // Number of inputs to the mux.
    NSM,             // Width of each input to the mux.
    LOG2_NUM_VIS_SP  // Width of select input for the mux.
  )
  U_busmux_shrd_vld (
    .sel  (grant_s_local),
    .din  (bus_valid_shrd_mux), 
    .dout (bus_valid_shrd_grnt_mux) 
  );
  assign bus_valid_shrd_grnt = SHARED 
                               ? bus_valid_shrd_grnt_mux 
                               : {NSM{1'b0}};
  



  // Generate transaction completion signals.
  // Need last signal for read data channel, not for burst response
  // channel.
  assign cpl_tx_o 
   = R_CH 
     ? payload_o[`AXI_RPYLD_LAST] & valid_o & ready_i
     : valid_o & ready_i;

  // Decode a t/x completion bus with a signal per attached master.
  // If this channel is shared it will signal compltion to multiple
  // master port addres channel blocks.
  assign cpl_tx_shrd_bus_o 
    = {NSM{ ((payload_o[`AXI_RPYLD_LAST] | (R_CH==0)) & ready_shrd_mux)  }}
      & bus_valid_shrd_o;                    

  // Since the shared channel may be used for both ICM and non ICM ports, 
  // if this is a shared channel, send the completion ID from payload_icm_o
  // for bidi enabled configs. ICM and non ICM master ports can take as
  // many bits as they need from it. If this is not a shared channel,
  // payload_pre_irs will always be correctly sized for the master port it is
  // connected to (i.e. if it is an ICM or not).
  generate
    if(SHARED) begin : gen_mp_dresp_shared
      assign cpl_id_o 
        = payload_o[`DRESPCH_ID_RHS+`ID_W-1:`DRESPCH_ID_RHS];
    end  else begin : gen_mp_dresp_not_shared
      assign cpl_id_o 
        = payload_o[`DRESPCH_ID_RHS+`ID_W-1:`DRESPCH_ID_RHS];
    end
  endgenerate

  /*--------------------------------------------------------------------
   * Decode bus_ready_o.
   * Each bit of bus_ready_o applies to 1 slave port only.
   * bus_grant comes from the arbiter and has 1 bit per slave port
   * also. By doing a bitwise AND of valid_o with bus_grant
   * we get a bus of ready signals for each slave port, where ready
   * will only be asserted if that slave port is sending a 
   * transfer to this channel, has won arbitration, and the master
   * has accepted with ready high.
   * Note that for a shared channel we first need to select the ready
   * input of the targeted master, this is done before the 
   * shared layer internal register slice and the output comes here
   * as ready_irs.
   */
  
  // Select the correct final ready bit from the attached master(s)
  // depending on whether this is a shared channel or dedicated.
  assign ready_shrd_ddctd_mux = SHARED ? ready_irs : ready_i;
  
  assign tx_acc_s = valid_o & ready_shrd_ddctd_mux;
  assign bus_ready_o = {NUM_VIS_SP{tx_acc_s}} & bus_grant;


  /*--------------------------------------------------------------------
   * Shared Channel Pipeline Stage
   */
  DW_axi_irs
  
  #(((SHARED & SHARED_PL) ? `AXI_TMO_FRWD : 0), // Channel timing option.
    NSM,        // Number of visible masters.
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
  U_DW_axi_irs_mp_dresp_shrd (
    // Inputs - System.
    .aclk_i        (aclk_i),
    .aresetn_i     (aresetn_i),

    // Inputs - Payload source.
    .payload_i     (payload_pre_irs),
    .bus_valid_i   (bus_valid_shrd_grnt),
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
   * Hold inputs for masters which are not accessed through dedicated
   * channel blocks at 0, so synthesis can remove unused logic 
   * relating to those masters.
   */
  assign has_ddctd_m_bus_max = 
    {(HAS_DDCTD_M15 == 1),
     (HAS_DDCTD_M14 == 1),
     (HAS_DDCTD_M13 == 1),
     (HAS_DDCTD_M12 == 1),
     (HAS_DDCTD_M11 == 1),
     (HAS_DDCTD_M10 == 1),
     (HAS_DDCTD_M9 == 1),
     (HAS_DDCTD_M8 == 1),
     (HAS_DDCTD_M7 == 1),
     (HAS_DDCTD_M6 == 1),
     (HAS_DDCTD_M5 == 1),
     (HAS_DDCTD_M4 == 1),
     (HAS_DDCTD_M3 == 1),
     (HAS_DDCTD_M2 == 1),
     (HAS_DDCTD_M1 == 1),
     (HAS_DDCTD_M0 == 1)
    };
    // Strip away unused bits.
    assign has_ddctd_m_bus = has_ddctd_m_bus_max[NSM-1:0];
   //spyglass disable_block STARC05-2.1.5.3 
   //SMD: Conditional expression does not evaluate to a scalar 
   //SJ: Warning can be ignored 
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue.
  //spyglass disable_block W224
  //SMD: Multi-bit expression found when one-bit expression expected
  //SJ: This is not an issue
   always @(*) begin : bus_valid_irs_arbpl_in_PROC
     integer mst;
     bus_valid_irs_arbpl_in = {NSM{1'b0}};
     for(mst=0;mst<NSM;mst=mst+1) begin
       // Use only if shared layer is accessing dedicated
       // sinks which have arbiter pipeline mode enabled.
       if(has_ddctd_m_bus[mst] & SHARED_ARB_PL_IRS) begin
         bus_valid_irs_arbpl_in[mst] = bus_valid_irs[mst];
       end else begin
         bus_valid_irs_arbpl_in[mst] = 1'b0;
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
    NSM,               // Number of visible masters.
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
   * DW_axi_irs_arbpl is used only for masters which are accessed 
   * through dedicated channels (shared to dedicated link) when the 
   * ARB_PL option is set to 1.
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
  //SJ: Warning can be ignored 
  // Valid output multiplexing between irs & irs_arbpl.      
  // Always use irs_arbpl bits for masters accessed through dedicated
  // channels.
  //spyglass disable_block W224
  //SMD: Multi-bit expression found when one-bit expression expected
  //SJ: This is not an issue
  always @(*) begin : bus_valid_shrd_o_PROC
    integer mst;
    for(mst=0;mst<NSM;mst=mst+1) begin
      // Use only if shared layer is accessing dedicated
      // sinks which have arbiter pipeline mode enabled.
      if(has_ddctd_m_bus[mst] & SHARED_ARB_PL_IRS) begin
        bus_valid_shrd_o[mst] = bus_valid_irs_arbpl[mst];
      end else begin
        // If there are still valids coming from irs_arbpl,
        // don't forward valids to masters not accessed through
        // dedicated channels.
        bus_valid_shrd_o[mst] 
          =   bus_valid_irs[mst] 
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
   * for masters accessed through dedicated channels.
   */
  generate
   if(NSM==1)
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
  assign payload_irs_mux
    = any_valid_irs_arbpl_r
      ? payload_irs_arbpl
      : payload_irs;


  /*--------------------------------------------------------------------
   * Select which ready signal goes to the DW_axi_irs block.
   *
   * As long as the irs block is targeting a slave accessed
   * through a dedicated channel, use ready from the irs_arbpl block, 
   * at all other times use ready decoded directly from the masters.
   */
  generate
   if (NSM == 1)
   begin
    assign ready_irs_in
      = SHARED_ARB_PL_IRS
        ? ( (has_ddctd_m_bus & bus_valid_irs)
            ? ready_irs_arbpl
            : ready_shrd_mux
          )
        : ready_shrd_mux; 
   end
   else
   begin
    assign ready_irs_in
      = SHARED_ARB_PL_IRS
        ? ( |(has_ddctd_m_bus & bus_valid_irs)
            ? ready_irs_arbpl
            : ready_shrd_mux
          )
        : ready_shrd_mux; 
   end
  endgenerate  
  


  /*--------------------------------------------------------------------
  * Select the ready input of the master being addressed by this t/x.
  * NOTE that this mux sits on the master (sink) side of an IRS 
  * (Internal Register Slice) block if enabled.
  * This is to pipeline the ready generation paths for shared
  * channels, which are significantly longer for shared channels
  * v/s dedicated channels.
  */
  DW_axi_busmux_ohsel
  
  #(NSM, // Number of inputs to the mux.
    1    // Width of each input to the mux.
   )
  U_DW_axi_busmux_ohsel_shrd_rdy_sel (
    .sel  (bus_valid_shrd_o),
    .din  (bus_ready_shrd_i), 
    .dout (ready_shrd_mux) 
  );

  //spyglass disable_block STARC05-2.1.5.3 
  //SMD: Conditional expression does not evaluate to a scalar 
  //SJ: Warning can be ignored 
  // For the irs_arbpl block, have to ensure that any bit
  // of ready will only assert if a valid has been driven out.
  // This will be true of all masters accessed through dedicated
  // channels.
  //spyglass disable_block W224
  //SMD: Multi-bit expression found when one-bit expression expected
  //SJ: This is not an issue
  always @(*) begin : bus_ready_irs_arbpl_in_PROC
    integer mst;
    for(mst=0;mst<NSM;mst=mst+1) begin
      // Use only if shared layer is accessing dedicated
      // sinks which have arbiter pipeline mode enabled.
      if(has_ddctd_m_bus[mst] & SHARED_ARB_PL_IRS) begin
        bus_ready_irs_arbpl_in[mst] = bus_ready_shrd_i[mst];
      end else begin
        bus_ready_irs_arbpl_in[mst] = 1'b0;
      end
    end
  end // bus_ready_irs_arbpl_in_PROC
  //spyglass enable_block W224
  //spyglass enable_block STARC05-2.1.5.3 



  assign payload_o = payload_irs_mux;
  //VP:: payload_icm_o was not assigned anything this the above piece of code is  not compiled
  //hence assigned all bits 0 - need to recheck
  assign payload_icm_o =  {`PYLD_ICM_W{1'b0}};



  // Undefine these macros, as the names are used in other modules,
  // so this will avoid simulator warnings.
  `undef DRESPCH_ID_RHS
  `undef DRESPCH_ID_LHS
  `undef ARB_NC
  `undef ARB_LOG2_NC
  `undef ARB_LOG2_NC_P1
  `undef BUS_PORT_REQ_W
  `undef ID_W

endmodule
