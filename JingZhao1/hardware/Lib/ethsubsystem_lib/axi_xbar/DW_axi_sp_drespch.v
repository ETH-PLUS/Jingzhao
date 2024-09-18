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
// File Version     :        $Revision: #8 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_sp_drespch.v#8 $ 
**
** ---------------------------------------------------------------------
**
** File     : DW_axi_sp_drespch.v
//
//
** Created  : Tue May 24 17:09:09 MEST 2005
** Modified : $Date: 2020/03/22 $
** Abstract : Seperate instantiations of this block implement the 
**            slave port read data and burst response channels.
**
** ---------------------------------------------------------------------
*/

module DW_axi_sp_drespch (
  // Inputs - System.
  //aclk_i,
  //aresetn_i,
    
  // Inputs - External Slave.
  valid_i,
  payload_i,
    
  // Outputs - External Slave.
  ready_o,
    
  // Inputs - Master Ports.
  ready_i,
    
  // Outputs - Master Ports.
  bus_valid_o,
  valid_o,
  shrd_ch_req_o,
  payload_o,

  // Outputs - Read Address Channel.
  cpl_tx_o,
  shrd_cpl_tx_o
);

   
//----------------------------------------------------------------------
// MODULE PARAMETERS.
//----------------------------------------------------------------------
  parameter NUM_VIS_MP = 16; // Number of visible master ports.

  parameter LOG2_NUM_VIS_MP = 4; // Log 2 of number of visible master 
                                 // ports.

  parameter PYLD_M_W = `AXI_R_PYLD_M_W; // Payload width to master.
  parameter PYLD_S_W = `AXI_R_PYLD_S_W; // Payload width from slave.

  parameter M0_VIS = 1; // Master visibility parameters.
  parameter M1_VIS = 1;
  parameter M2_VIS = 1;
  parameter M3_VIS = 1;
  parameter M4_VIS = 1;
  parameter M5_VIS = 1;
  parameter M6_VIS = 1;
  parameter M7_VIS = 1;
  parameter M8_VIS = 1;
  parameter M9_VIS = 1;
  parameter M10_VIS = 1;
  parameter M11_VIS = 1;
  parameter M12_VIS = 1;
  parameter M13_VIS = 1;
  parameter M14_VIS = 1;
  parameter M15_VIS = 1;

  parameter [0:0] R_CH = 1; // This parameter is set to 1 if the block is 
                      // being used as part of a read data 
                      // channel.

  // Shared layer for this channel exists.
  parameter HAS_SHARED = 0;

  // Source on shared or dedicated layer parameters.
  parameter SHARED_M0 = 0;
  parameter SHARED_M1 = 0;
  parameter SHARED_M2 = 0;
  parameter SHARED_M3 = 0;
  parameter SHARED_M4 = 0;
  parameter SHARED_M5 = 0;
  parameter SHARED_M6 = 0;
  parameter SHARED_M7 = 0;
  parameter SHARED_M8 = 0;
  parameter SHARED_M9 = 0;
  parameter SHARED_M10 = 0;
  parameter SHARED_M11 = 0;
  parameter SHARED_M12 = 0;
  parameter SHARED_M13 = 0;
  parameter SHARED_M14 = 0;
  parameter SHARED_M15 = 0;

  // Address source on shared or dedicated layer parameters.
  parameter A_SHARED_M0 = 0;
  parameter A_SHARED_M1 = 0;
  parameter A_SHARED_M2 = 0;
  parameter A_SHARED_M3 = 0;
  parameter A_SHARED_M4 = 0;
  parameter A_SHARED_M5 = 0;
  parameter A_SHARED_M6 = 0;
  parameter A_SHARED_M7 = 0;
  parameter A_SHARED_M8 = 0;
  parameter A_SHARED_M9 = 0;
  parameter A_SHARED_M10 = 0;
  parameter A_SHARED_M11 = 0;
  parameter A_SHARED_M12 = 0;
  parameter A_SHARED_M13 = 0;
  parameter A_SHARED_M14 = 0;
  parameter A_SHARED_M15 = 0;

//----------------------------------------------------------------------
// LOCAL MACROS.
//----------------------------------------------------------------------
  `define DRESPCH_ID_RHS ((R_CH==1) ? `AXI_RPYLD_ID_RHS_S : `AXI_BPYLD_ID_RHS_S)
  `define DRESPCH_ID_LHS ((R_CH==1) ? `AXI_RPYLD_ID_LHS_S : `AXI_BPYLD_ID_LHS_S)

//----------------------------------------------------------------------
// PORT DECLARATIONS
//----------------------------------------------------------------------
  // Inputs - System.
  //input aclk_i;    // AXI system clock.
  //input aresetn_i; // AXI system reset.

  // Inputs - External Slave.
  // This signal has a deadloop in DW_axi_sp.v at DW_axi_irs_arbpl instantance for both Bresp and Rresp channels.
  input                 valid_i;   // Valid from external slave.
  input [PYLD_S_W-1:0]  payload_i; // Payload from external slave.

  // Outputs - External Slave.
  output                ready_o; // Ready to external slave.
  
  // Inputs - Master Ports.
  input ready_i; // All ready signals from visible master ports.

  // Outputs - Master Ports.
  output [NUM_VIS_MP-1:0] bus_valid_o; // Valid signals to master ports.
  reg    [NUM_VIS_MP-1:0] bus_valid_o; 
  
  output valid_o; // Single bit valid output, used to avoid requiring
                  // an OR reduction on bus_valid_o in the internal
                  // register slice blocks.

  output                  shrd_ch_req_o; // Request for shared layer.
  output [PYLD_M_W-1:0]   payload_o;   // Payload vector to master
  reg    [PYLD_M_W-1:0]   payload_o;   // ports.

  // Outputs - Read/Write address channel.               
  output cpl_tx_o; // Transaction completed signal.

  output shrd_cpl_tx_o; // Transaction completed signal, asserted only
                        // for masters that access this slave through
                        // the shared A[R/W] layer.


  //--------------------------------------------------------------------
  // REGISTER VARIABLES.
  //--------------------------------------------------------------------
  reg [`AXI_LOG2_NM-1:0] id_mstnum; // Master number taken from 
                                    // slaves ID signal.
  //reg waiting_for_tx_acc_r; // Reg to tell us when we are waiting for 
                            // a t/x to be accepted.

  //--------------------------------------------------------------------
  // WIRE VARIABLES.
  //--------------------------------------------------------------------
  wire [LOG2_NUM_VIS_MP-1:0] local_mst; // Local master number, 
                                        // from the upper range of
                                        // the incoming ID value,
                                        // id_i.

  //This signal will be unused only if only 1 master is in configuration

  wire [`AXI_MAX_NUM_USR_MSTS-1:0] shared_m_bus;
  wire [`AXI_SIDW-1:0] id_slv; // ID signal from slave.

  // One hot system master number from systolcl block.
  wire [`AXI_MAX_NUM_USR_MSTS-1:0] bidi_sys_pnum_oh;
  reg [`AXI_MAX_NUM_USR_MSTS-1:0] id_mstnum_oh;


  //--------------------------------------------------------------------
  // GENERATE TX ISSUED SIGNAL.
  // Assert this signal when each transaction is issued.
  //--------------------------------------------------------------------
  
  //// Register signal to tell us when we are waiting for a t/x to
  //// be accepted.
  //always @(negedge aresetn_i or posedge aclk_i) 
  //begin : waiting_for_tx_acc_r_PROC 
  //  if(!aresetn_i) begin
  //    waiting_for_tx_acc_r <= 1'b0;
  //  end else begin
  //    if(waiting_for_tx_acc_r) begin
  //      // T/x accepted.
  //      waiting_for_tx_acc_r <= (!ready_i);
  //    end else begin  
  //      // Set this register if valid is asserted and not accepted.
  //      waiting_for_tx_acc_r <= valid_i & (!ready_i);
  //    end
  //  end
  //end // waiting_for_tx_acc_r_PROC
  //

  //// Assert this output when a transaction has been issued from the 
  //// slave port.
  //assign tx_issued = // Valid asserted for new t/x, i.e. not waiting
  //                   // for previous to be accepted.
  //                   valid_i & (!waiting_for_tx_acc_r);


  // Extract ID signal from payload_i.
  // Need to know which channel this block is implementing to know
  // where the ID bits are.
  assign id_slv = payload_i[`DRESPCH_ID_LHS:`DRESPCH_ID_RHS];

  
  // Due to loop varaible limitations range overflow is not possible,
  // hence the lint warning can be disabled:

  // Take master number from the slaves ID signal.
  
  wire dummy;
  assign dummy = 1'b0;

  always @(*) 
  begin : id_mstnum_PROC
    // No master number in slaves ID signal if only
    // 1 master in the system.
      id_mstnum = dummy;
  end // id_mstnum_PROC

 


  /*--------------------------------------------------------------------
   * Decode if shared layer is being accessed.
   */
  
  // Bit for each master, asserted if the master is visible to this
  // slave port.
  wire [`AXI_MAX_NUM_USR_MSTS-1:0] vis_m_bus;
  assign vis_m_bus
    = {(M15_VIS ? 1'b1 : 1'b0),
       (M14_VIS ? 1'b1 : 1'b0),
       (M13_VIS ? 1'b1 : 1'b0),
       (M12_VIS ? 1'b1 : 1'b0),
       (M11_VIS ? 1'b1 : 1'b0),
       (M10_VIS ? 1'b1 : 1'b0),
       (M9_VIS ? 1'b1 : 1'b0),
       (M8_VIS ? 1'b1 : 1'b0),
       (M7_VIS ? 1'b1 : 1'b0),
       (M6_VIS ? 1'b1 : 1'b0),
       (M5_VIS ? 1'b1 : 1'b0),
       (M4_VIS ? 1'b1 : 1'b0),
       (M3_VIS ? 1'b1 : 1'b0),
       (M2_VIS ? 1'b1 : 1'b0),
       (M1_VIS ? 1'b1 : 1'b0),
       (M0_VIS ? 1'b1 : 1'b0)
      };

  // Generate one hot system master number.
  // Note use of vis_m_bus to avoid decoding logic for masters which 
  // are not visible to this slave port.
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue.
  always @(*) begin : id_mstnum_oh_PROC
    integer mst;
    id_mstnum_oh = {`AXI_MAX_NUM_USR_MSTS{1'b0}};
    for(mst=0 ; mst<`AXI_MAX_NUM_USR_MSTS ; mst=mst+1) begin
      if((mst == id_mstnum) & vis_m_bus[mst]) id_mstnum_oh[mst] = 1'b1;
    end
  end // id_mstnum_oh_PROC
  //spyglass enable_block W415a


  // Bit for each master, asserted if this slave port accesses that 
  // master on the shared layer.
  assign shared_m_bus
    = {(SHARED_M15 ? 1'b1 : 1'b0),
       (SHARED_M14 ? 1'b1 : 1'b0),
       (SHARED_M13 ? 1'b1 : 1'b0),
       (SHARED_M12 ? 1'b1 : 1'b0),
       (SHARED_M11 ? 1'b1 : 1'b0),
       (SHARED_M10 ? 1'b1 : 1'b0),
       (SHARED_M9 ? 1'b1 : 1'b0),
       (SHARED_M8 ? 1'b1 : 1'b0),
       (SHARED_M7 ? 1'b1 : 1'b0),
       (SHARED_M6 ? 1'b1 : 1'b0),
       (SHARED_M5 ? 1'b1 : 1'b0),
       (SHARED_M4 ? 1'b1 : 1'b0),
       (SHARED_M3 ? 1'b1 : 1'b0),
       (SHARED_M2 ? 1'b1 : 1'b0),
       (SHARED_M1 ? 1'b1 : 1'b0),
       (SHARED_M0 ? 1'b1 : 1'b0)
      };

  wire mst_on_shrd; // Asserted when decoded master is accessed via
                    // shared layer.
  assign mst_on_shrd = HAS_SHARED 
                       ? |(  shared_m_bus 
                           & (`AXI_HAS_BICMD ? bidi_sys_pnum_oh 
                                             : id_mstnum_oh
                             )
                          )
                         : 1'b0 ;


  // Bit for each master, asserted if the master accesses this slave 
  // on the shared A[R/W] layer.
  wire [`AXI_MAX_NUM_USR_MSTS-1:0] shared_m_a_bus;
  assign shared_m_a_bus
    = {(A_SHARED_M15 ? 1'b1 : 1'b0),
       (A_SHARED_M14 ? 1'b1 : 1'b0),
       (A_SHARED_M13 ? 1'b1 : 1'b0),
       (A_SHARED_M12 ? 1'b1 : 1'b0),
       (A_SHARED_M11 ? 1'b1 : 1'b0),
       (A_SHARED_M10 ? 1'b1 : 1'b0),
       (A_SHARED_M9 ? 1'b1 : 1'b0),
       (A_SHARED_M8 ? 1'b1 : 1'b0),
       (A_SHARED_M7 ? 1'b1 : 1'b0),
       (A_SHARED_M6 ? 1'b1 : 1'b0),
       (A_SHARED_M5 ? 1'b1 : 1'b0),
       (A_SHARED_M4 ? 1'b1 : 1'b0),
       (A_SHARED_M3 ? 1'b1 : 1'b0),
       (A_SHARED_M2 ? 1'b1 : 1'b0),
       (A_SHARED_M1 ? 1'b1 : 1'b0),
       (A_SHARED_M0 ? 1'b1 : 1'b0)
      };

  // Asserted when decoded master accesses this slave via the shared 
  // A[R/W] layer.
  wire mst_on_a_shrd; 
  assign mst_on_a_shrd = |(shared_m_a_bus 
                           & (`AXI_HAS_BICMD ? bidi_sys_pnum_oh 
                                             : id_mstnum_oh
                             )
                          );

  // Map decoded system master number to local master number.
  DW_axi_systolcl
  
  #(
    NUM_VIS_MP,        // Number of masters visible from this slave 
                       // port.
    LOG2_NUM_VIS_MP,   // Log 2 of NUM_VIS_MP.
    `AXI_NUM_MASTERS,  // Number of slaves in system, including default
                       // slave.
    `AXI_LOG2_NM,      // Log base 2 of number of slaves in the system.
    M0_VIS,            // Port visibility parameters.
    M1_VIS,
    M2_VIS,
    M3_VIS,
    M4_VIS,
    M5_VIS,
    M6_VIS,
    M7_VIS,
    M8_VIS,
    M9_VIS,
    M10_VIS,
    M11_VIS,
    M12_VIS,
    M13_VIS,
    M14_VIS,
    M15_VIS,
    0                  // Maximum of 16 masters.
  )
  U_dcdr_systolcl (
    .sys_pnum_i         (id_mstnum),
    .lcl_pnum_o         (local_mst),
    .bidi_sys_pnum_oh_o (bidi_sys_pnum_oh)
  );


  // Demultiplex the valid line from the master to the 
  // valid line for the addressed addressed.
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue.
  always @(valid_i or local_mst)
  begin : bus_valid_o_PROC
    integer mstnum;

    bus_valid_o = {NUM_VIS_MP{1'b0}};

    for(mstnum=0 ; 
        mstnum<=(NUM_VIS_MP-1) ; 
        mstnum=mstnum+1 
       )
    begin
      if((local_mst==mstnum) && valid_i) begin
        bus_valid_o[mstnum] = 1'b1;
      end
    end

  end // bus_valid_o_PROC
  //spyglass enable_block W415a

  // Generate single bit valid output.
  assign valid_o = valid_i;

  // Generate shared channel request signal.
  assign shrd_ch_req_o = valid_i & mst_on_shrd;


  // Strip master port number from the id component of payload_i 
  // to form payload_o. 
  // Have to do this using a for loop because of complications with
  // the configurable presence of sideband signals in the payload bus.
  always @(*)  
  begin : strip_mstnum_from_id_PROC
    integer pyld_bit;
    integer id_bit;
    reg [`AXI_SIDW-1:0] midw;

    id_bit = 0;
    midw = payload_i[`DRESPCH_ID_LHS:`DRESPCH_ID_RHS];

    for(pyld_bit=0 ; pyld_bit<=(PYLD_M_W-1) ; pyld_bit=pyld_bit+1) begin
      // Assign fields up to id field.
      if(pyld_bit<`DRESPCH_ID_RHS) begin
        payload_o[pyld_bit] = payload_i[pyld_bit];

      // Assign id field.
      end else if(   (pyld_bit>=`DRESPCH_ID_RHS) 
                  && (pyld_bit<=(`DRESPCH_ID_LHS-`AXI_LOG2_NM))
                 ) 
      begin
        payload_o[pyld_bit] = midw[id_bit];
        id_bit = id_bit+1;
      
      // Assign fields after id fields.
      end else begin
        // There will only be id bits to strip off if number of
        // visible masters is > 1.
          payload_o[pyld_bit] = payload_i[pyld_bit];
      end
    end
  end // strip_mstnum_from_id_PROC   


  // Transaction completion signal i.e. last transfer in burst
  // accepted.
  // Note we are only interested in the last signal for the 
  // read data channel.
  assign cpl_tx_o = valid_i & ready_i && 
                    (payload_i[`AXI_RPYLD_LAST] || (!R_CH));

  // Transaction completed signal, asserted only
  // for masters that access this slave through
  // the shared A[R/W] layer.
  assign shrd_cpl_tx_o = cpl_tx_o & mst_on_a_shrd;

  // Connect ready out to the slave.      
  assign ready_o = ready_i;      

  // Undefine these macros, as the names are used in other modules,
  // so this will avoid simulator warnings.
  `undef DRESPCH_ID_RHS
  `undef DRESPCH_ID_LHS

endmodule
