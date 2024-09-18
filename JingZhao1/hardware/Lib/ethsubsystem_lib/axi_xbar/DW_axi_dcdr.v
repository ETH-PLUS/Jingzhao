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
// File Version     :        $Revision: #9 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_dcdr.v#9 $ 
**
** ---------------------------------------------------------------------
**
** File     : DW_axi_dcdr.v
//
//
** Created  : Tue May 24 17:09:09 MEST 2005
** Modified : $Date: 2020/03/22 $
** Abstract : This block implements the DW_axi slave address decoder.
**            It contains visibility parameters for each slave so
**            it will only implement logic for visible slaves, for
**            each master port it is used in.
**
** ---------------------------------------------------------------------
*/

module DW_axi_dcdr (
  // Inputs.
  addr_i,
  
  // Outputs.
  region_o,
  local_slv_o,
  sys_slv_o,
  slv_on_shrd_o
);

//----------------------------------------------------------------------
// MODULE PARAMETERS.
//----------------------------------------------------------------------
  parameter NUM_VIS_SP = 16; // Number of slave ports visible from the
                             // master port where this block is 
                             // instantiated.

  parameter LOG2_NUM_VIS_SP = 4; // Log 2 of NUM_VIS_SP.
           
  parameter S0_N_VIS = 1; // Slave 0 to 16 normal address mode   
  parameter [0:0] S1_N_VIS = 1; // visibility parameters.
  parameter [0:0] S2_N_VIS = 1; 
  parameter [0:0] S3_N_VIS = 1; 
  parameter [0:0] S4_N_VIS = 1; 
  parameter [0:0] S5_N_VIS = 1; 
  parameter [0:0] S6_N_VIS = 1; 
  parameter [0:0] S7_N_VIS = 1; 
  parameter [0:0] S8_N_VIS = 1; 
  parameter [0:0] S9_N_VIS = 1; 
  parameter [0:0] S10_N_VIS = 1; 
  parameter [0:0] S11_N_VIS = 1; 
  parameter [0:0] S12_N_VIS = 1; 
  parameter [0:0] S13_N_VIS = 1; 
  parameter [0:0] S14_N_VIS = 1; 
  parameter [0:0] S15_N_VIS = 1; 
  parameter [0:0] S16_N_VIS = 1; 

  parameter S0_B_VIS = 1; // Slave 0 to 16 boot address mode 
  parameter [0:0] S1_B_VIS = 1; // visibility parameters.
  parameter [0:0] S2_B_VIS = 1; 
  parameter [0:0] S3_B_VIS = 1; 
  parameter [0:0] S4_B_VIS = 1; 
  parameter [0:0] S5_B_VIS = 1; 
  parameter [0:0] S6_B_VIS = 1; 
  parameter [0:0] S7_B_VIS = 1; 
  parameter [0:0] S8_B_VIS = 1; 
  parameter [0:0] S9_B_VIS = 1; 
  parameter [0:0] S10_B_VIS = 1; 
  parameter [0:0] S11_B_VIS = 1; 
  parameter [0:0] S12_B_VIS = 1; 
  parameter [0:0] S13_B_VIS = 1; 
  parameter [0:0] S14_B_VIS = 1; 
  parameter [0:0] S15_B_VIS = 1; 
  parameter [0:0] S16_B_VIS = 1; 

  // Shared layer for this channel exists.
  parameter HAS_SHARED = 0;

  // Source on shared or dedicated layer parameters.
  parameter SHARED_S0 = 0;
  parameter SHARED_S1 = 0;
  parameter SHARED_S2 = 0;
  parameter SHARED_S3 = 0;
  parameter SHARED_S4 = 0;
  parameter SHARED_S5 = 0;
  parameter SHARED_S6 = 0;
  parameter SHARED_S7 = 0;
  parameter SHARED_S8 = 0;
  parameter SHARED_S9 = 0;
  parameter SHARED_S10 = 0;
  parameter SHARED_S11 = 0;
  parameter SHARED_S12 = 0;
  parameter SHARED_S13 = 0;
  parameter SHARED_S14 = 0;
  parameter SHARED_S15 = 0;
  parameter SHARED_S16 = 0;


//----------------------------------------------------------------------
// LOCAL MACROS.
//----------------------------------------------------------------------

  // Slave visibility macros. Derived from normal and boot mode 
  // slave visibility parameters. A slave is visible if it is visible
  // in either normal or boot mode.
  // a vector. Hence there is no issue functionally
  `define P0_VIS  ( S0_N_VIS ||  S0_B_VIS)
  `define P1_VIS  ( S1_N_VIS ||  S1_B_VIS)
  `define P2_VIS  ( S2_N_VIS ||  S2_B_VIS)
  `define P3_VIS  ( S3_N_VIS ||  S3_B_VIS)
  `define P4_VIS  ( S4_N_VIS ||  S4_B_VIS)
  `define P5_VIS  ( S5_N_VIS ||  S5_B_VIS)
  `define P6_VIS  ( S6_N_VIS ||  S6_B_VIS)
  `define P7_VIS  ( S7_N_VIS ||  S7_B_VIS)
  `define P8_VIS  ( S8_N_VIS ||  S8_B_VIS)
  `define P9_VIS  ( S9_N_VIS ||  S9_B_VIS)
  `define P10_VIS (S10_N_VIS || S10_B_VIS)
  `define P11_VIS (S11_N_VIS || S11_B_VIS)
  `define P12_VIS (S12_N_VIS || S12_B_VIS)
  `define P13_VIS (S13_N_VIS || S13_B_VIS)
  `define P14_VIS (S14_N_VIS || S14_B_VIS)
  `define P15_VIS (S15_N_VIS || S15_B_VIS)
  `define P16_VIS (S16_N_VIS || S16_B_VIS)


//----------------------------------------------------------------------
// PORT DECLARATIONS
//----------------------------------------------------------------------

//----------------------------------------------------------------------
// INPUTS
//----------------------------------------------------------------------
  input [`AXI_AW-1:0] addr_i;    // Address from master.


//----------------------------------------------------------------------
// OUTPUTS
//----------------------------------------------------------------------
  output [LOG2_NUM_VIS_SP-1:0] local_slv_o; // Decoded local slave 
                                           // number.

  output [3:0] region_o; // Decoded region value for the address

  output [`AXI_LOG2_NSP1-1:0] sys_slv_o;   // Decoded system slave 
  reg    [`AXI_LOG2_NSP1-1:0] sys_slv_o;   // number.

  output slv_on_shrd_o; // Asserted when decoded slave is accessed via
                        // shared layer.

  //--------------------------------------------------------------------
  // REGISTER VARIABLES.
  //--------------------------------------------------------------------

  //--------------------------------------------------------------------
  // WIRE VARIABLES.
  //--------------------------------------------------------------------
  
  wire dcd_slv_norm_1; // Decode signals for slaves 1 to 16 in normal 
  wire dcd_slv_norm_2; // address mode.
  wire dcd_slv_norm_3;
  wire dcd_slv_norm_4;
  wire dcd_slv_norm_5;
  wire dcd_slv_norm_6;
  wire dcd_slv_norm_7;
  wire dcd_slv_norm_8;
  wire dcd_slv_norm_9;
  wire dcd_slv_norm_10;
  wire dcd_slv_norm_11;
  wire dcd_slv_norm_12;
  wire dcd_slv_norm_13;
  wire dcd_slv_norm_14;
  wire dcd_slv_norm_15;
  wire dcd_slv_norm_16;

  wire dcd_slv_norm_reg0_s1;
  wire dcd_slv_norm_reg1_s1;
  wire dcd_slv_norm_reg2_s1;
  wire dcd_slv_norm_reg3_s1;
  wire dcd_slv_norm_reg4_s1;
  wire dcd_slv_norm_reg5_s1;
  wire dcd_slv_norm_reg6_s1;
  wire dcd_slv_norm_reg7_s1;

  wire dcd_slv_norm_reg0_s2;
  wire dcd_slv_norm_reg1_s2;
  wire dcd_slv_norm_reg2_s2;
  wire dcd_slv_norm_reg3_s2;
  wire dcd_slv_norm_reg4_s2;
  wire dcd_slv_norm_reg5_s2;
  wire dcd_slv_norm_reg6_s2;
  wire dcd_slv_norm_reg7_s2;

  wire dcd_slv_norm_reg0_s3;
  wire dcd_slv_norm_reg1_s3;
  wire dcd_slv_norm_reg2_s3;
  wire dcd_slv_norm_reg3_s3;
  wire dcd_slv_norm_reg4_s3;
  wire dcd_slv_norm_reg5_s3;
  wire dcd_slv_norm_reg6_s3;
  wire dcd_slv_norm_reg7_s3;

  wire dcd_slv_norm_reg0_s4;
  wire dcd_slv_norm_reg1_s4;
  wire dcd_slv_norm_reg2_s4;
  wire dcd_slv_norm_reg3_s4;
  wire dcd_slv_norm_reg4_s4;
  wire dcd_slv_norm_reg5_s4;
  wire dcd_slv_norm_reg6_s4;
  wire dcd_slv_norm_reg7_s4;

  wire dcd_slv_norm_reg0_s5;
  wire dcd_slv_norm_reg1_s5;
  wire dcd_slv_norm_reg2_s5;
  wire dcd_slv_norm_reg3_s5;
  wire dcd_slv_norm_reg4_s5;
  wire dcd_slv_norm_reg5_s5;
  wire dcd_slv_norm_reg6_s5;
  wire dcd_slv_norm_reg7_s5;

  wire dcd_slv_norm_reg0_s6;
  wire dcd_slv_norm_reg1_s6;
  wire dcd_slv_norm_reg2_s6;
  wire dcd_slv_norm_reg3_s6;
  wire dcd_slv_norm_reg4_s6;
  wire dcd_slv_norm_reg5_s6;
  wire dcd_slv_norm_reg6_s6;
  wire dcd_slv_norm_reg7_s6;

  wire dcd_slv_norm_reg0_s7;
  wire dcd_slv_norm_reg1_s7;
  wire dcd_slv_norm_reg2_s7;
  wire dcd_slv_norm_reg3_s7;
  wire dcd_slv_norm_reg4_s7;
  wire dcd_slv_norm_reg5_s7;
  wire dcd_slv_norm_reg6_s7;
  wire dcd_slv_norm_reg7_s7;

  wire dcd_slv_norm_reg0_s8;
  wire dcd_slv_norm_reg1_s8;
  wire dcd_slv_norm_reg2_s8;
  wire dcd_slv_norm_reg3_s8;
  wire dcd_slv_norm_reg4_s8;
  wire dcd_slv_norm_reg5_s8;
  wire dcd_slv_norm_reg6_s8;
  wire dcd_slv_norm_reg7_s8;

  wire dcd_slv_norm_reg0_s9;
  wire dcd_slv_norm_reg1_s9;
  wire dcd_slv_norm_reg2_s9;
  wire dcd_slv_norm_reg3_s9;
  wire dcd_slv_norm_reg4_s9;
  wire dcd_slv_norm_reg5_s9;
  wire dcd_slv_norm_reg6_s9;
  wire dcd_slv_norm_reg7_s9;

  wire dcd_slv_norm_reg0_s10;
  wire dcd_slv_norm_reg1_s10;
  wire dcd_slv_norm_reg2_s10;
  wire dcd_slv_norm_reg3_s10;
  wire dcd_slv_norm_reg4_s10;
  wire dcd_slv_norm_reg5_s10;
  wire dcd_slv_norm_reg6_s10;
  wire dcd_slv_norm_reg7_s10;

  wire dcd_slv_norm_reg0_s11;
  wire dcd_slv_norm_reg1_s11;
  wire dcd_slv_norm_reg2_s11;
  wire dcd_slv_norm_reg3_s11;
  wire dcd_slv_norm_reg4_s11;
  wire dcd_slv_norm_reg5_s11;
  wire dcd_slv_norm_reg6_s11;
  wire dcd_slv_norm_reg7_s11;

  wire dcd_slv_norm_reg0_s12;
  wire dcd_slv_norm_reg1_s12;
  wire dcd_slv_norm_reg2_s12;
  wire dcd_slv_norm_reg3_s12;
  wire dcd_slv_norm_reg4_s12;
  wire dcd_slv_norm_reg5_s12;
  wire dcd_slv_norm_reg6_s12;
  wire dcd_slv_norm_reg7_s12;

  wire dcd_slv_norm_reg0_s13;
  wire dcd_slv_norm_reg1_s13;
  wire dcd_slv_norm_reg2_s13;
  wire dcd_slv_norm_reg3_s13;
  wire dcd_slv_norm_reg4_s13;
  wire dcd_slv_norm_reg5_s13;
  wire dcd_slv_norm_reg6_s13;
  wire dcd_slv_norm_reg7_s13;

  wire dcd_slv_norm_reg0_s14;
  wire dcd_slv_norm_reg1_s14;
  wire dcd_slv_norm_reg2_s14;
  wire dcd_slv_norm_reg3_s14;
  wire dcd_slv_norm_reg4_s14;
  wire dcd_slv_norm_reg5_s14;
  wire dcd_slv_norm_reg6_s14;
  wire dcd_slv_norm_reg7_s14;

  wire dcd_slv_norm_reg0_s15;
  wire dcd_slv_norm_reg1_s15;
  wire dcd_slv_norm_reg2_s15;
  wire dcd_slv_norm_reg3_s15;
  wire dcd_slv_norm_reg4_s15;
  wire dcd_slv_norm_reg5_s15;
  wire dcd_slv_norm_reg6_s15;
  wire dcd_slv_norm_reg7_s15;

  wire dcd_slv_norm_reg0_s16;
  wire dcd_slv_norm_reg1_s16;
  wire dcd_slv_norm_reg2_s16;
  wire dcd_slv_norm_reg3_s16;
  wire dcd_slv_norm_reg4_s16;
  wire dcd_slv_norm_reg5_s16;
  wire dcd_slv_norm_reg6_s16;
  wire dcd_slv_norm_reg7_s16;



reg  [2:0]   norm_region;

// Depending on visibility, these registers may not be used 
 

  // Concatenation of all normal mode slave decode signals.
  wire [`AXI_MAX_NUM_MST_SLVS-1:0] bus_dcd_slv_norm;

  // Result of muxing between normal and boot mode slave decode
  // signals.
  wire [`AXI_MAX_NUM_MST_SLVS-1:0] bus_dcd_slv_mux;

  // Bit for each slave, asserted if this master port accesses that 
  // slave on the shared layer.
  wire [`AXI_MAX_NUM_MST_SLVS-1:0] shared_s_bus;

  wire [`AXI_MAX_NUM_USR_MSTS-1:0] bidi_sys_pnum_oh_o_unconn;


  // Bit for each slave, asserted if this master port accesses that 
  // slave on the shared layer.
  assign shared_s_bus
    = {(SHARED_S16 ? 1'b1 : 1'b0),
       (SHARED_S15 ? 1'b1 : 1'b0),
       (SHARED_S14 ? 1'b1 : 1'b0),
       (SHARED_S13 ? 1'b1 : 1'b0),
       (SHARED_S12 ? 1'b1 : 1'b0),
       (SHARED_S11 ? 1'b1 : 1'b0),
       (SHARED_S10 ? 1'b1 : 1'b0),
       (SHARED_S9 ? 1'b1 : 1'b0),
       (SHARED_S8 ? 1'b1 : 1'b0),
       (SHARED_S7 ? 1'b1 : 1'b0),
       (SHARED_S6 ? 1'b1 : 1'b0),
       (SHARED_S5 ? 1'b1 : 1'b0),
       (SHARED_S4 ? 1'b1 : 1'b0),
       (SHARED_S3 ? 1'b1 : 1'b0),
       (SHARED_S2 ? 1'b1 : 1'b0),
       (SHARED_S1 ? 1'b1 : 1'b0),
       (SHARED_S0 ? 1'b1 : 1'b0)
      };

// Region Select for S1
  assign dcd_slv_norm_reg0_s1 = ((addr_i>=`AXI_R1_NSA_S1) && (addr_i<=`AXI_R1_NEA_S1));
  assign dcd_slv_norm_reg1_s1 = ((addr_i>=`AXI_R2_NSA_S1) && (addr_i<=`AXI_R2_NEA_S1) && (`AXI_NUM_RN_S1>=2));
  assign dcd_slv_norm_reg2_s1 = ((addr_i>=`AXI_R3_NSA_S1) && (addr_i<=`AXI_R3_NEA_S1) && (`AXI_NUM_RN_S1>=3));
  assign dcd_slv_norm_reg3_s1 = ((addr_i>=`AXI_R4_NSA_S1) && (addr_i<=`AXI_R4_NEA_S1) && (`AXI_NUM_RN_S1>=4));
  assign dcd_slv_norm_reg4_s1 = ((addr_i>=`AXI_R5_NSA_S1) && (addr_i<=`AXI_R5_NEA_S1) && (`AXI_NUM_RN_S1>=5));
  assign dcd_slv_norm_reg5_s1 = ((addr_i>=`AXI_R6_NSA_S1) && (addr_i<=`AXI_R6_NEA_S1) && (`AXI_NUM_RN_S1>=6));
  assign dcd_slv_norm_reg6_s1 = ((addr_i>=`AXI_R7_NSA_S1) && (addr_i<=`AXI_R7_NEA_S1) && (`AXI_NUM_RN_S1>=7));
  assign dcd_slv_norm_reg7_s1 = ((addr_i>=`AXI_R8_NSA_S1) && (addr_i<=`AXI_R8_NEA_S1) && (`AXI_NUM_RN_S1>=8));

  // Generate the normal address mode slave decode signals.
  assign dcd_slv_norm_1 =  (dcd_slv_norm_reg0_s1 ||
                            dcd_slv_norm_reg1_s1 || 
                            dcd_slv_norm_reg2_s1 || 
                            dcd_slv_norm_reg3_s1 ||
                            dcd_slv_norm_reg4_s1 || 
                            dcd_slv_norm_reg5_s1 || 
                            dcd_slv_norm_reg6_s1 || 
                            dcd_slv_norm_reg7_s1) && 
                            S1_N_VIS;

// Region Select for S2
  assign dcd_slv_norm_reg0_s2 = ((addr_i>=`AXI_R1_NSA_S2) && (addr_i<=`AXI_R1_NEA_S2));
  assign dcd_slv_norm_reg1_s2 = ((addr_i>=`AXI_R2_NSA_S2) && (addr_i<=`AXI_R2_NEA_S2) && (`AXI_NUM_RN_S2>=2));
  assign dcd_slv_norm_reg2_s2 = ((addr_i>=`AXI_R3_NSA_S2) && (addr_i<=`AXI_R3_NEA_S2) && (`AXI_NUM_RN_S2>=3));
  assign dcd_slv_norm_reg3_s2 = ((addr_i>=`AXI_R4_NSA_S2) && (addr_i<=`AXI_R4_NEA_S2) && (`AXI_NUM_RN_S2>=4));
  assign dcd_slv_norm_reg4_s2 = ((addr_i>=`AXI_R5_NSA_S2) && (addr_i<=`AXI_R5_NEA_S2) && (`AXI_NUM_RN_S2>=5));
  assign dcd_slv_norm_reg5_s2 = ((addr_i>=`AXI_R6_NSA_S2) && (addr_i<=`AXI_R6_NEA_S2) && (`AXI_NUM_RN_S2>=6));
  assign dcd_slv_norm_reg6_s2 = ((addr_i>=`AXI_R7_NSA_S2) && (addr_i<=`AXI_R7_NEA_S2) && (`AXI_NUM_RN_S2>=7));
  assign dcd_slv_norm_reg7_s2 = ((addr_i>=`AXI_R8_NSA_S2) && (addr_i<=`AXI_R8_NEA_S2) && (`AXI_NUM_RN_S2>=8));

  // Generate the normal address mode slave decode signals.
  assign dcd_slv_norm_2 =  (dcd_slv_norm_reg0_s2 || 
                            dcd_slv_norm_reg1_s2 || 
                            dcd_slv_norm_reg2_s2 || 
                            dcd_slv_norm_reg3_s2 ||
                            dcd_slv_norm_reg4_s2 || 
                            dcd_slv_norm_reg5_s2 || 
                            dcd_slv_norm_reg6_s2 || 
                            dcd_slv_norm_reg7_s2) && 
                            S2_N_VIS;

// Region Select for S3
  assign dcd_slv_norm_reg0_s3 = ((addr_i>=`AXI_R1_NSA_S3) && (addr_i<=`AXI_R1_NEA_S3));
  assign dcd_slv_norm_reg1_s3 = ((addr_i>=`AXI_R2_NSA_S3) && (addr_i<=`AXI_R2_NEA_S3) && (`AXI_NUM_RN_S3>=2));
  assign dcd_slv_norm_reg2_s3 = ((addr_i>=`AXI_R3_NSA_S3) && (addr_i<=`AXI_R3_NEA_S3) && (`AXI_NUM_RN_S3>=3));
  assign dcd_slv_norm_reg3_s3 = ((addr_i>=`AXI_R4_NSA_S3) && (addr_i<=`AXI_R4_NEA_S3) && (`AXI_NUM_RN_S3>=4));
  assign dcd_slv_norm_reg4_s3 = ((addr_i>=`AXI_R5_NSA_S3) && (addr_i<=`AXI_R5_NEA_S3) && (`AXI_NUM_RN_S3>=5));
  assign dcd_slv_norm_reg5_s3 = ((addr_i>=`AXI_R6_NSA_S3) && (addr_i<=`AXI_R6_NEA_S3) && (`AXI_NUM_RN_S3>=6));
  assign dcd_slv_norm_reg6_s3 = ((addr_i>=`AXI_R7_NSA_S3) && (addr_i<=`AXI_R7_NEA_S3) && (`AXI_NUM_RN_S3>=7));
  assign dcd_slv_norm_reg7_s3 = ((addr_i>=`AXI_R8_NSA_S3) && (addr_i<=`AXI_R8_NEA_S3) && (`AXI_NUM_RN_S3>=8));

  // Generate the normal address mode slave decode signals.
  assign dcd_slv_norm_3 =  (dcd_slv_norm_reg0_s3 || 
                            dcd_slv_norm_reg1_s3 || 
                            dcd_slv_norm_reg2_s3 || 
                            dcd_slv_norm_reg3_s3 ||
                            dcd_slv_norm_reg4_s3 || 
                            dcd_slv_norm_reg5_s3 || 
                            dcd_slv_norm_reg6_s3 || 
                            dcd_slv_norm_reg7_s3) && 
                            S3_N_VIS;

// Region Select for S4
  assign dcd_slv_norm_reg0_s4 = ((addr_i>=`AXI_R1_NSA_S4) && (addr_i<=`AXI_R1_NEA_S4));
  assign dcd_slv_norm_reg1_s4 = ((addr_i>=`AXI_R2_NSA_S4) && (addr_i<=`AXI_R2_NEA_S4) && (`AXI_NUM_RN_S4>=2));
  assign dcd_slv_norm_reg2_s4 = ((addr_i>=`AXI_R3_NSA_S4) && (addr_i<=`AXI_R3_NEA_S4) && (`AXI_NUM_RN_S4>=3));
  assign dcd_slv_norm_reg3_s4 = ((addr_i>=`AXI_R4_NSA_S4) && (addr_i<=`AXI_R4_NEA_S4) && (`AXI_NUM_RN_S4>=4));
  assign dcd_slv_norm_reg4_s4 = ((addr_i>=`AXI_R5_NSA_S4) && (addr_i<=`AXI_R5_NEA_S4) && (`AXI_NUM_RN_S4>=5));
  assign dcd_slv_norm_reg5_s4 = ((addr_i>=`AXI_R6_NSA_S4) && (addr_i<=`AXI_R6_NEA_S4) && (`AXI_NUM_RN_S4>=6));
  assign dcd_slv_norm_reg6_s4 = ((addr_i>=`AXI_R7_NSA_S4) && (addr_i<=`AXI_R7_NEA_S4) && (`AXI_NUM_RN_S4>=7));
  assign dcd_slv_norm_reg7_s4 = ((addr_i>=`AXI_R8_NSA_S4) && (addr_i<=`AXI_R8_NEA_S4) && (`AXI_NUM_RN_S4>=8));

  // Generate the normal address mode slave decode signals.
  assign dcd_slv_norm_4 =  (dcd_slv_norm_reg0_s4 || 
                            dcd_slv_norm_reg1_s4 || 
                            dcd_slv_norm_reg2_s4 || 
                            dcd_slv_norm_reg3_s4 ||
                            dcd_slv_norm_reg4_s4 || 
                            dcd_slv_norm_reg5_s4 || 
                            dcd_slv_norm_reg6_s4 || 
                            dcd_slv_norm_reg7_s4) && 
                            S4_N_VIS;

// Region Select for S5
  assign dcd_slv_norm_reg0_s5 = ((addr_i>=`AXI_R1_NSA_S5) && (addr_i<=`AXI_R1_NEA_S5));
  assign dcd_slv_norm_reg1_s5 = ((addr_i>=`AXI_R2_NSA_S5) && (addr_i<=`AXI_R2_NEA_S5) && (`AXI_NUM_RN_S5>=2));
  assign dcd_slv_norm_reg2_s5 = ((addr_i>=`AXI_R3_NSA_S5) && (addr_i<=`AXI_R3_NEA_S5) && (`AXI_NUM_RN_S5>=3));
  assign dcd_slv_norm_reg3_s5 = ((addr_i>=`AXI_R4_NSA_S5) && (addr_i<=`AXI_R4_NEA_S5) && (`AXI_NUM_RN_S5>=4));
  assign dcd_slv_norm_reg4_s5 = ((addr_i>=`AXI_R5_NSA_S5) && (addr_i<=`AXI_R5_NEA_S5) && (`AXI_NUM_RN_S5>=5));
  assign dcd_slv_norm_reg5_s5 = ((addr_i>=`AXI_R6_NSA_S5) && (addr_i<=`AXI_R6_NEA_S5) && (`AXI_NUM_RN_S5>=6));
  assign dcd_slv_norm_reg6_s5 = ((addr_i>=`AXI_R7_NSA_S5) && (addr_i<=`AXI_R7_NEA_S5) && (`AXI_NUM_RN_S5>=7));
  assign dcd_slv_norm_reg7_s5 = ((addr_i>=`AXI_R8_NSA_S5) && (addr_i<=`AXI_R8_NEA_S5) && (`AXI_NUM_RN_S5>=8));

  // Generate the normal address mode slave decode signals.
  assign dcd_slv_norm_5 =  (dcd_slv_norm_reg0_s5 || 
                            dcd_slv_norm_reg1_s5 || 
                            dcd_slv_norm_reg2_s5 || 
                            dcd_slv_norm_reg3_s5 ||
                            dcd_slv_norm_reg4_s5 || 
                            dcd_slv_norm_reg5_s5 || 
                            dcd_slv_norm_reg6_s5 || 
                            dcd_slv_norm_reg7_s5) && 
                            S5_N_VIS;

// Region Select for S6
  assign dcd_slv_norm_reg0_s6 = ((addr_i>=`AXI_R1_NSA_S6) && (addr_i<=`AXI_R1_NEA_S6));
  assign dcd_slv_norm_reg1_s6 = ((addr_i>=`AXI_R2_NSA_S6) && (addr_i<=`AXI_R2_NEA_S6) && (`AXI_NUM_RN_S6>=2));
  assign dcd_slv_norm_reg2_s6 = ((addr_i>=`AXI_R3_NSA_S6) && (addr_i<=`AXI_R3_NEA_S6) && (`AXI_NUM_RN_S6>=3));
  assign dcd_slv_norm_reg3_s6 = ((addr_i>=`AXI_R4_NSA_S6) && (addr_i<=`AXI_R4_NEA_S6) && (`AXI_NUM_RN_S6>=4));
  assign dcd_slv_norm_reg4_s6 = ((addr_i>=`AXI_R5_NSA_S6) && (addr_i<=`AXI_R5_NEA_S6) && (`AXI_NUM_RN_S6>=5));
  assign dcd_slv_norm_reg5_s6 = ((addr_i>=`AXI_R6_NSA_S6) && (addr_i<=`AXI_R6_NEA_S6) && (`AXI_NUM_RN_S6>=6));
  assign dcd_slv_norm_reg6_s6 = ((addr_i>=`AXI_R7_NSA_S6) && (addr_i<=`AXI_R7_NEA_S6) && (`AXI_NUM_RN_S6>=7));
  assign dcd_slv_norm_reg7_s6 = ((addr_i>=`AXI_R8_NSA_S6) && (addr_i<=`AXI_R8_NEA_S6) && (`AXI_NUM_RN_S6>=8));

  // Generate the normal address mode slave decode signals.
  assign dcd_slv_norm_6 =  (dcd_slv_norm_reg0_s6 || 
                            dcd_slv_norm_reg1_s6 || 
                            dcd_slv_norm_reg2_s6 || 
                            dcd_slv_norm_reg3_s6 ||
                            dcd_slv_norm_reg4_s6 || 
                            dcd_slv_norm_reg5_s6 || 
                            dcd_slv_norm_reg6_s6 || 
                            dcd_slv_norm_reg7_s6) && 
                            S6_N_VIS;

// Region Select for S7
  assign dcd_slv_norm_reg0_s7 = ((addr_i>=`AXI_R1_NSA_S7) && (addr_i<=`AXI_R1_NEA_S7));
  assign dcd_slv_norm_reg1_s7 = ((addr_i>=`AXI_R2_NSA_S7) && (addr_i<=`AXI_R2_NEA_S7) && (`AXI_NUM_RN_S7>=2));
  assign dcd_slv_norm_reg2_s7 = ((addr_i>=`AXI_R3_NSA_S7) && (addr_i<=`AXI_R3_NEA_S7) && (`AXI_NUM_RN_S7>=3));
  assign dcd_slv_norm_reg3_s7 = ((addr_i>=`AXI_R4_NSA_S7) && (addr_i<=`AXI_R4_NEA_S7) && (`AXI_NUM_RN_S7>=4));
  assign dcd_slv_norm_reg4_s7 = ((addr_i>=`AXI_R5_NSA_S7) && (addr_i<=`AXI_R5_NEA_S7) && (`AXI_NUM_RN_S7>=5));
  assign dcd_slv_norm_reg5_s7 = ((addr_i>=`AXI_R6_NSA_S7) && (addr_i<=`AXI_R6_NEA_S7) && (`AXI_NUM_RN_S7>=6));
  assign dcd_slv_norm_reg6_s7 = ((addr_i>=`AXI_R7_NSA_S7) && (addr_i<=`AXI_R7_NEA_S7) && (`AXI_NUM_RN_S7>=7));
  assign dcd_slv_norm_reg7_s7 = ((addr_i>=`AXI_R8_NSA_S7) && (addr_i<=`AXI_R8_NEA_S7) && (`AXI_NUM_RN_S7>=8));

  // Generate the normal address mode slave decode signals.
  assign dcd_slv_norm_7 =  (dcd_slv_norm_reg0_s7 || 
                            dcd_slv_norm_reg1_s7 || 
                            dcd_slv_norm_reg2_s7 || 
                            dcd_slv_norm_reg3_s7 ||
                            dcd_slv_norm_reg4_s7 || 
                            dcd_slv_norm_reg5_s7 || 
                            dcd_slv_norm_reg6_s7 || 
                            dcd_slv_norm_reg7_s7) && 
                            S7_N_VIS;

// Region Select for S8
  assign dcd_slv_norm_reg0_s8 = ((addr_i>=`AXI_R1_NSA_S8) && (addr_i<=`AXI_R1_NEA_S8));
  assign dcd_slv_norm_reg1_s8 = ((addr_i>=`AXI_R2_NSA_S8) && (addr_i<=`AXI_R2_NEA_S8) && (`AXI_NUM_RN_S8>=2));
  assign dcd_slv_norm_reg2_s8 = ((addr_i>=`AXI_R3_NSA_S8) && (addr_i<=`AXI_R3_NEA_S8) && (`AXI_NUM_RN_S8>=3));
  assign dcd_slv_norm_reg3_s8 = ((addr_i>=`AXI_R4_NSA_S8) && (addr_i<=`AXI_R4_NEA_S8) && (`AXI_NUM_RN_S8>=4));
  assign dcd_slv_norm_reg4_s8 = ((addr_i>=`AXI_R5_NSA_S8) && (addr_i<=`AXI_R5_NEA_S8) && (`AXI_NUM_RN_S8>=5));
  assign dcd_slv_norm_reg5_s8 = ((addr_i>=`AXI_R6_NSA_S8) && (addr_i<=`AXI_R6_NEA_S8) && (`AXI_NUM_RN_S8>=6));
  assign dcd_slv_norm_reg6_s8 = ((addr_i>=`AXI_R7_NSA_S8) && (addr_i<=`AXI_R7_NEA_S8) && (`AXI_NUM_RN_S8>=7));
  assign dcd_slv_norm_reg7_s8 = ((addr_i>=`AXI_R8_NSA_S8) && (addr_i<=`AXI_R8_NEA_S8) && (`AXI_NUM_RN_S8>=8));

  // Generate the normal address mode slave decode signals.
  assign dcd_slv_norm_8 =  (dcd_slv_norm_reg0_s8 || 
                            dcd_slv_norm_reg1_s8 || 
                            dcd_slv_norm_reg2_s8 || 
                            dcd_slv_norm_reg3_s8 ||
                            dcd_slv_norm_reg4_s8 || 
                            dcd_slv_norm_reg5_s8 || 
                            dcd_slv_norm_reg6_s8 || 
                            dcd_slv_norm_reg7_s8) && 
                            S8_N_VIS;

// Region Select for S9
  assign dcd_slv_norm_reg0_s9 = ((addr_i>=`AXI_R1_NSA_S9) && (addr_i<=`AXI_R1_NEA_S9));
  assign dcd_slv_norm_reg1_s9 = ((addr_i>=`AXI_R2_NSA_S9) && (addr_i<=`AXI_R2_NEA_S9) && (`AXI_NUM_RN_S9>=2));
  assign dcd_slv_norm_reg2_s9 = ((addr_i>=`AXI_R3_NSA_S9) && (addr_i<=`AXI_R3_NEA_S9) && (`AXI_NUM_RN_S9>=3));
  assign dcd_slv_norm_reg3_s9 = ((addr_i>=`AXI_R4_NSA_S9) && (addr_i<=`AXI_R4_NEA_S9) && (`AXI_NUM_RN_S9>=4));
  assign dcd_slv_norm_reg4_s9 = ((addr_i>=`AXI_R5_NSA_S9) && (addr_i<=`AXI_R5_NEA_S9) && (`AXI_NUM_RN_S9>=5));
  assign dcd_slv_norm_reg5_s9 = ((addr_i>=`AXI_R6_NSA_S9) && (addr_i<=`AXI_R6_NEA_S9) && (`AXI_NUM_RN_S9>=6));
  assign dcd_slv_norm_reg6_s9 = ((addr_i>=`AXI_R7_NSA_S9) && (addr_i<=`AXI_R7_NEA_S9) && (`AXI_NUM_RN_S9>=7));
  assign dcd_slv_norm_reg7_s9 = ((addr_i>=`AXI_R8_NSA_S9) && (addr_i<=`AXI_R8_NEA_S9) && (`AXI_NUM_RN_S9>=8));

  // Generate the normal address mode slave decode signals.
  assign dcd_slv_norm_9 =  (dcd_slv_norm_reg0_s9 || 
                            dcd_slv_norm_reg1_s9 || 
                            dcd_slv_norm_reg2_s9 || 
                            dcd_slv_norm_reg3_s9 ||
                            dcd_slv_norm_reg4_s9 || 
                            dcd_slv_norm_reg5_s9 || 
                            dcd_slv_norm_reg6_s9 || 
                            dcd_slv_norm_reg7_s9) && 
                            S9_N_VIS;

// Region Select for S10
  assign dcd_slv_norm_reg0_s10 = ((addr_i>=`AXI_R1_NSA_S10) && (addr_i<=`AXI_R1_NEA_S10));
  assign dcd_slv_norm_reg1_s10 = ((addr_i>=`AXI_R2_NSA_S10) && (addr_i<=`AXI_R2_NEA_S10) && (`AXI_NUM_RN_S10>=2));
  assign dcd_slv_norm_reg2_s10 = ((addr_i>=`AXI_R3_NSA_S10) && (addr_i<=`AXI_R3_NEA_S10) && (`AXI_NUM_RN_S10>=3));
  assign dcd_slv_norm_reg3_s10 = ((addr_i>=`AXI_R4_NSA_S10) && (addr_i<=`AXI_R4_NEA_S10) && (`AXI_NUM_RN_S10>=4));
  assign dcd_slv_norm_reg4_s10 = ((addr_i>=`AXI_R5_NSA_S10) && (addr_i<=`AXI_R5_NEA_S10) && (`AXI_NUM_RN_S10>=5));
  assign dcd_slv_norm_reg5_s10 = ((addr_i>=`AXI_R6_NSA_S10) && (addr_i<=`AXI_R6_NEA_S10) && (`AXI_NUM_RN_S10>=6));
  assign dcd_slv_norm_reg6_s10 = ((addr_i>=`AXI_R7_NSA_S10) && (addr_i<=`AXI_R7_NEA_S10) && (`AXI_NUM_RN_S10>=7));
  assign dcd_slv_norm_reg7_s10 = ((addr_i>=`AXI_R8_NSA_S10) && (addr_i<=`AXI_R8_NEA_S10) && (`AXI_NUM_RN_S10>=8));

  // Generate the normal address mode slave decode signals.
  assign dcd_slv_norm_10 =  (dcd_slv_norm_reg0_s10 || 
                             dcd_slv_norm_reg1_s10 || 
                             dcd_slv_norm_reg2_s10 || 
                             dcd_slv_norm_reg3_s10 ||
                             dcd_slv_norm_reg4_s10 || 
                             dcd_slv_norm_reg5_s10 || 
                             dcd_slv_norm_reg6_s10 || 
                             dcd_slv_norm_reg7_s10) && 
                             S10_N_VIS;

// Region Select for S11
  assign dcd_slv_norm_reg0_s11 = ((addr_i>=`AXI_R1_NSA_S11) && (addr_i<=`AXI_R1_NEA_S11));
  assign dcd_slv_norm_reg1_s11 = ((addr_i>=`AXI_R2_NSA_S11) && (addr_i<=`AXI_R2_NEA_S11) && (`AXI_NUM_RN_S11>=2));
  assign dcd_slv_norm_reg2_s11 = ((addr_i>=`AXI_R3_NSA_S11) && (addr_i<=`AXI_R3_NEA_S11) && (`AXI_NUM_RN_S11>=3));
  assign dcd_slv_norm_reg3_s11 = ((addr_i>=`AXI_R4_NSA_S11) && (addr_i<=`AXI_R4_NEA_S11) && (`AXI_NUM_RN_S11>=4));
  assign dcd_slv_norm_reg4_s11 = ((addr_i>=`AXI_R5_NSA_S11) && (addr_i<=`AXI_R5_NEA_S11) && (`AXI_NUM_RN_S11>=5));
  assign dcd_slv_norm_reg5_s11 = ((addr_i>=`AXI_R6_NSA_S11) && (addr_i<=`AXI_R6_NEA_S11) && (`AXI_NUM_RN_S11>=6));
  assign dcd_slv_norm_reg6_s11 = ((addr_i>=`AXI_R7_NSA_S11) && (addr_i<=`AXI_R7_NEA_S11) && (`AXI_NUM_RN_S11>=7));
  assign dcd_slv_norm_reg7_s11 = ((addr_i>=`AXI_R8_NSA_S11) && (addr_i<=`AXI_R8_NEA_S11) && (`AXI_NUM_RN_S11>=8));

  // Generate the normal address mode slave decode signals.
  assign dcd_slv_norm_11 =  (dcd_slv_norm_reg0_s11 || 
                             dcd_slv_norm_reg1_s11 || 
                             dcd_slv_norm_reg2_s11 || 
                             dcd_slv_norm_reg3_s11 ||
                             dcd_slv_norm_reg4_s11 || 
                             dcd_slv_norm_reg5_s11 || 
                             dcd_slv_norm_reg6_s11 || 
                             dcd_slv_norm_reg7_s11) && 
                             S11_N_VIS;

// Region Select for S12
  assign dcd_slv_norm_reg0_s12 = ((addr_i>=`AXI_R1_NSA_S12) && (addr_i<=`AXI_R1_NEA_S12));
  assign dcd_slv_norm_reg1_s12 = ((addr_i>=`AXI_R2_NSA_S12) && (addr_i<=`AXI_R2_NEA_S12) && (`AXI_NUM_RN_S12>=2));
  assign dcd_slv_norm_reg2_s12 = ((addr_i>=`AXI_R3_NSA_S12) && (addr_i<=`AXI_R3_NEA_S12) && (`AXI_NUM_RN_S12>=3));
  assign dcd_slv_norm_reg3_s12 = ((addr_i>=`AXI_R4_NSA_S12) && (addr_i<=`AXI_R4_NEA_S12) && (`AXI_NUM_RN_S12>=4));
  assign dcd_slv_norm_reg4_s12 = ((addr_i>=`AXI_R5_NSA_S12) && (addr_i<=`AXI_R5_NEA_S12) && (`AXI_NUM_RN_S12>=5));
  assign dcd_slv_norm_reg5_s12 = ((addr_i>=`AXI_R6_NSA_S12) && (addr_i<=`AXI_R6_NEA_S12) && (`AXI_NUM_RN_S12>=6));
  assign dcd_slv_norm_reg6_s12 = ((addr_i>=`AXI_R7_NSA_S12) && (addr_i<=`AXI_R7_NEA_S12) && (`AXI_NUM_RN_S12>=7));
  assign dcd_slv_norm_reg7_s12 = ((addr_i>=`AXI_R8_NSA_S12) && (addr_i<=`AXI_R8_NEA_S12) && (`AXI_NUM_RN_S12>=8));

  // Generate the normal address mode slave decode signals.
  assign dcd_slv_norm_12 =  (dcd_slv_norm_reg0_s12 || 
                             dcd_slv_norm_reg1_s12 || 
                             dcd_slv_norm_reg2_s12 || 
                             dcd_slv_norm_reg3_s12 ||
                             dcd_slv_norm_reg4_s12 || 
                             dcd_slv_norm_reg5_s12 || 
                             dcd_slv_norm_reg6_s12 || 
                             dcd_slv_norm_reg7_s12) && 
                             S12_N_VIS;

// Region Select for S13
  assign dcd_slv_norm_reg0_s13 = ((addr_i>=`AXI_R1_NSA_S13) && (addr_i<=`AXI_R1_NEA_S13));
  assign dcd_slv_norm_reg1_s13 = ((addr_i>=`AXI_R2_NSA_S13) && (addr_i<=`AXI_R2_NEA_S13) && (`AXI_NUM_RN_S13>=2));
  assign dcd_slv_norm_reg2_s13 = ((addr_i>=`AXI_R3_NSA_S13) && (addr_i<=`AXI_R3_NEA_S13) && (`AXI_NUM_RN_S13>=3));
  assign dcd_slv_norm_reg3_s13 = ((addr_i>=`AXI_R4_NSA_S13) && (addr_i<=`AXI_R4_NEA_S13) && (`AXI_NUM_RN_S13>=4));
  assign dcd_slv_norm_reg4_s13 = ((addr_i>=`AXI_R5_NSA_S13) && (addr_i<=`AXI_R5_NEA_S13) && (`AXI_NUM_RN_S13>=5));
  assign dcd_slv_norm_reg5_s13 = ((addr_i>=`AXI_R6_NSA_S13) && (addr_i<=`AXI_R6_NEA_S13) && (`AXI_NUM_RN_S13>=6));
  assign dcd_slv_norm_reg6_s13 = ((addr_i>=`AXI_R7_NSA_S13) && (addr_i<=`AXI_R7_NEA_S13) && (`AXI_NUM_RN_S13>=7));
  assign dcd_slv_norm_reg7_s13 = ((addr_i>=`AXI_R8_NSA_S13) && (addr_i<=`AXI_R8_NEA_S13) && (`AXI_NUM_RN_S13>=8));

  // Generate the normal address mode slave decode signals.
  assign dcd_slv_norm_13 =  (dcd_slv_norm_reg0_s13 || 
                             dcd_slv_norm_reg1_s13 || 
                             dcd_slv_norm_reg2_s13 || 
                             dcd_slv_norm_reg3_s13 ||
                             dcd_slv_norm_reg4_s13 || 
                             dcd_slv_norm_reg5_s13 || 
                             dcd_slv_norm_reg6_s13 || 
                             dcd_slv_norm_reg7_s13) && 
                             S13_N_VIS;

// Region Select for S14
  assign dcd_slv_norm_reg0_s14 = ((addr_i>=`AXI_R1_NSA_S14) && (addr_i<=`AXI_R1_NEA_S14));
  assign dcd_slv_norm_reg1_s14 = ((addr_i>=`AXI_R2_NSA_S14) && (addr_i<=`AXI_R2_NEA_S14) && (`AXI_NUM_RN_S14>=2));
  assign dcd_slv_norm_reg2_s14 = ((addr_i>=`AXI_R3_NSA_S14) && (addr_i<=`AXI_R3_NEA_S14) && (`AXI_NUM_RN_S14>=3));
  assign dcd_slv_norm_reg3_s14 = ((addr_i>=`AXI_R4_NSA_S14) && (addr_i<=`AXI_R4_NEA_S14) && (`AXI_NUM_RN_S14>=4));
  assign dcd_slv_norm_reg4_s14 = ((addr_i>=`AXI_R5_NSA_S14) && (addr_i<=`AXI_R5_NEA_S14) && (`AXI_NUM_RN_S14>=5));
  assign dcd_slv_norm_reg5_s14 = ((addr_i>=`AXI_R6_NSA_S14) && (addr_i<=`AXI_R6_NEA_S14) && (`AXI_NUM_RN_S14>=6));
  assign dcd_slv_norm_reg6_s14 = ((addr_i>=`AXI_R7_NSA_S14) && (addr_i<=`AXI_R7_NEA_S14) && (`AXI_NUM_RN_S14>=7));
  assign dcd_slv_norm_reg7_s14 = ((addr_i>=`AXI_R8_NSA_S14) && (addr_i<=`AXI_R8_NEA_S14) && (`AXI_NUM_RN_S14>=8));

  // Generate the normal address mode slave decode signals.
  assign dcd_slv_norm_14 =  (dcd_slv_norm_reg0_s14 || 
                             dcd_slv_norm_reg1_s14 || 
                             dcd_slv_norm_reg2_s14 || 
                             dcd_slv_norm_reg3_s14 ||
                             dcd_slv_norm_reg4_s14 || 
                             dcd_slv_norm_reg5_s14 || 
                             dcd_slv_norm_reg6_s14 || 
                             dcd_slv_norm_reg7_s14) && 
                             S14_N_VIS;

// Region Select for S15
  assign dcd_slv_norm_reg0_s15 = ((addr_i>=`AXI_R1_NSA_S15) && (addr_i<=`AXI_R1_NEA_S15));
  assign dcd_slv_norm_reg1_s15 = ((addr_i>=`AXI_R2_NSA_S15) && (addr_i<=`AXI_R2_NEA_S15) && (`AXI_NUM_RN_S15>=2));
  assign dcd_slv_norm_reg2_s15 = ((addr_i>=`AXI_R3_NSA_S15) && (addr_i<=`AXI_R3_NEA_S15) && (`AXI_NUM_RN_S15>=3));
  assign dcd_slv_norm_reg3_s15 = ((addr_i>=`AXI_R4_NSA_S15) && (addr_i<=`AXI_R4_NEA_S15) && (`AXI_NUM_RN_S15>=4));
  assign dcd_slv_norm_reg4_s15 = ((addr_i>=`AXI_R5_NSA_S15) && (addr_i<=`AXI_R5_NEA_S15) && (`AXI_NUM_RN_S15>=5));
  assign dcd_slv_norm_reg5_s15 = ((addr_i>=`AXI_R6_NSA_S15) && (addr_i<=`AXI_R6_NEA_S15) && (`AXI_NUM_RN_S15>=6));
  assign dcd_slv_norm_reg6_s15 = ((addr_i>=`AXI_R7_NSA_S15) && (addr_i<=`AXI_R7_NEA_S15) && (`AXI_NUM_RN_S15>=7));
  assign dcd_slv_norm_reg7_s15 = ((addr_i>=`AXI_R8_NSA_S15) && (addr_i<=`AXI_R8_NEA_S15) && (`AXI_NUM_RN_S15>=8));

  // Generate the normal address mode slave decode signals.
  assign dcd_slv_norm_15 =  (dcd_slv_norm_reg0_s15 || 
                             dcd_slv_norm_reg1_s15 || 
                             dcd_slv_norm_reg2_s15 || 
                             dcd_slv_norm_reg3_s15 ||
                             dcd_slv_norm_reg4_s15 || 
                             dcd_slv_norm_reg5_s15 || 
                             dcd_slv_norm_reg6_s15 || 
                             dcd_slv_norm_reg7_s15) && 
                             S15_N_VIS;

// Region Select for S16
  assign dcd_slv_norm_reg0_s16 = ((addr_i>=`AXI_R1_NSA_S16) && (addr_i<=`AXI_R1_NEA_S16));
  assign dcd_slv_norm_reg1_s16 = ((addr_i>=`AXI_R2_NSA_S16) && (addr_i<=`AXI_R2_NEA_S16) && (`AXI_NUM_RN_S16>=2));
  assign dcd_slv_norm_reg2_s16 = ((addr_i>=`AXI_R3_NSA_S16) && (addr_i<=`AXI_R3_NEA_S16) && (`AXI_NUM_RN_S16>=3));
  assign dcd_slv_norm_reg3_s16 = ((addr_i>=`AXI_R4_NSA_S16) && (addr_i<=`AXI_R4_NEA_S16) && (`AXI_NUM_RN_S16>=4));
  assign dcd_slv_norm_reg4_s16 = ((addr_i>=`AXI_R5_NSA_S16) && (addr_i<=`AXI_R5_NEA_S16) && (`AXI_NUM_RN_S16>=5));
  assign dcd_slv_norm_reg5_s16 = ((addr_i>=`AXI_R6_NSA_S16) && (addr_i<=`AXI_R6_NEA_S16) && (`AXI_NUM_RN_S16>=6));
  assign dcd_slv_norm_reg6_s16 = ((addr_i>=`AXI_R7_NSA_S16) && (addr_i<=`AXI_R7_NEA_S16) && (`AXI_NUM_RN_S16>=7));
  assign dcd_slv_norm_reg7_s16 = ((addr_i>=`AXI_R8_NSA_S16) && (addr_i<=`AXI_R8_NEA_S16) && (`AXI_NUM_RN_S16>=8));

  // Generate the normal address mode slave decode signals.
  assign dcd_slv_norm_16 =  (dcd_slv_norm_reg0_s16 || 
                             dcd_slv_norm_reg1_s16 || 
                             dcd_slv_norm_reg2_s16 || 
                             dcd_slv_norm_reg3_s16 ||
                             dcd_slv_norm_reg4_s16 || 
                             dcd_slv_norm_reg5_s16 || 
                             dcd_slv_norm_reg6_s16 || 
                             dcd_slv_norm_reg7_s16) && 
                             S16_N_VIS;

// Remove decoding for boot region if the remap option has not
// been configured.

always @ (*)
begin:norm_region_PROC
   case (sys_slv_o)
   0 : norm_region = 3'b000;
   default  : norm_region = 3'b000;
   endcase
end


assign region_o = {1'b0, norm_region};
 
// MUX out the  
  // Concatenate all normal slave decode signals into one bus.   
  assign bus_dcd_slv_norm
    = { dcd_slv_norm_16,
        dcd_slv_norm_15,
        dcd_slv_norm_14,
        dcd_slv_norm_13,
        dcd_slv_norm_12,
        dcd_slv_norm_11,
        dcd_slv_norm_10,
        dcd_slv_norm_9,
        dcd_slv_norm_8,
        dcd_slv_norm_7,
        dcd_slv_norm_6,
        dcd_slv_norm_5,
        dcd_slv_norm_4,
        dcd_slv_norm_3,
        dcd_slv_norm_2,
        dcd_slv_norm_1,
        ~|bus_dcd_slv_norm [`AXI_MAX_NUM_MST_SLVS-1:1]
      };
  

  
          
  // Remap address decode signal mux.          
  assign bus_dcd_slv_mux = bus_dcd_slv_norm;

  // Decode if the addressed slave is on the shared layer.
  assign slv_on_shrd_o = HAS_SHARED 
                         ? |(shared_s_bus & bus_dcd_slv_mux)
                         : 1'b0 ;


  integer slvnum_intg;
  //--------------------------------------------------------------------
  // Map bus_dcd_slv_mux from one hot to a binary slave number.
  // Note default slave 0 is decoded from bus_dcd_slv_mux == 'b0,
  // and slave 1 is decoded from bus_dcd_slv_mux[1] = 1'b1,
  // and so on.
  //--------------------------------------------------------------------
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue.
  always @(*)
  begin : bus_dcd_slv_to_oh_PROC
    reg [`AXI_LOG2_NSP1-1:0] slvnum;


    sys_slv_o = {`AXI_LOG2_NSP1{1'b0}};

    // For loop must iterate through all slaves including the
    // default slave.
    // 
    for(slvnum_intg = {`AXI_LOG2_NSP1{1'b0}} ;
        slvnum_intg <= (`AXI_NSP1-1)   ;
        slvnum_intg = slvnum_intg + 1  
       )
    begin
      slvnum = slvnum_intg;
      if(bus_dcd_slv_mux[slvnum_intg]) sys_slv_o = slvnum;
    end 

  end // bus_dcd_slv_to_oh_PROC
  //spyglass enable_block W415a


  // spyglass disable_block W576
  // SMD: Logical operation on a vector
  // SJ: S*_N_VIS and S*_B_VIS are parameters whose value is set to 1. 
  // Since, parameter is by default 32 bit, spyglass is considering it as
  // a vector. Hence there is no issue functionally
  // Map decoded system slave number to local slave number.
  DW_axi_systolcl
  
  #(
    NUM_VIS_SP,      // Number of slaves visible from this master port.
    LOG2_NUM_VIS_SP, // Log 2 of NUM_VIS_SP.
    `AXI_NSP1,       // Number of slaves in system, including default
                     // slave.
    `AXI_LOG2_NSP1,  // Log base 2 of number of slaves in the system.
    `P0_VIS,         // Port visibility parameters.
    `P1_VIS,
    `P2_VIS,
    `P3_VIS,
    `P4_VIS,
    `P5_VIS,
    `P6_VIS,
    `P7_VIS,
    `P8_VIS,
    `P9_VIS,
    `P10_VIS,
    `P11_VIS,
    `P12_VIS,
    `P13_VIS,
    `P14_VIS,
    `P15_VIS,
    `P16_VIS
  )
  // spyglass enable_block W576
  U_dcdr_systolcl (
    .sys_pnum_i         (sys_slv_o),
    .lcl_pnum_o         (local_slv_o),
    .bidi_sys_pnum_oh_o (bidi_sys_pnum_oh_o_unconn)
  );


endmodule
