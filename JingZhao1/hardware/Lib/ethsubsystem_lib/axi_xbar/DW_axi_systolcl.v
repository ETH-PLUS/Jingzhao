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
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_systolcl.v#12 $ 
**
** ---------------------------------------------------------------------
**
** File     : DW_axi_systolcl.v
//
//
** Created  : Tue May 24 17:09:09 MEST 2005
** Modified : $Date: 2020/03/22 $
** Abstract : The purpose of this module is to map system port
**            numbers to local port numbers within the DW_axi
**            interconnect system.
**            Necessary because not all slave and master ports are
**            visible to each other, so each slave and master port will
**            have different numbers for the slave and master ports
**            that are visible to it.
**            Note that this module can map from slave to master port
**            numbers or vice versa depending on the parameters/inputs
**            that are applied to it.
**
** ---------------------------------------------------------------------
*/

module DW_axi_systolcl (
  // Inputs.
  sys_pnum_i,
  
  // Outputs.
  lcl_pnum_o,
  bidi_sys_pnum_oh_o
);

//----------------------------------------------------------------------
// MODULE PARAMETERS.
//----------------------------------------------------------------------

  parameter NUM_PLCL = 17; // Number of visible/local ports.

  parameter LCLPNUM_W = 5; // Width of local port number signals. 

  parameter NUM_PSYS = 17; // Number of ports in the system, master or
                           // slave depending on which one we are 
                           // dealing with.

  parameter SYSPNUM_W = 5; // Width of system port number signals. 

  parameter [0:0] P0_VIS  = 1; // Port visibility parameters. Set to 1 if
  parameter [0:0] P1_VIS  = 1; // corresponding port is visible. Need 17
  parameter [0:0] P2_VIS  = 1; // parameters, for slaves we have 16 possible
  parameter [0:0] P3_VIS  = 1; // user slaves + 1 for the default slave.
  parameter [0:0] P4_VIS  = 1; 
  parameter [0:0] P5_VIS  = 1; 
  parameter [0:0] P6_VIS  = 1; 
  parameter [0:0] P7_VIS  = 1; 
  parameter [0:0] P8_VIS  = 1; 
  parameter [0:0] P9_VIS  = 1; 
  parameter [0:0] P10_VIS = 1; 
  parameter [0:0] P11_VIS = 1; 
  parameter [0:0] P12_VIS = 1; 
  parameter [0:0] P13_VIS = 1; 
  parameter [0:0] P14_VIS = 1; 
  parameter [0:0] P15_VIS = 1; 
  parameter [0:0] P16_VIS = 1; 
  

//----------------------------------------------------------------------
// PORT DECLARATIONS.
//----------------------------------------------------------------------

//----------------------------------------------------------------------
// INPUTS
//----------------------------------------------------------------------
  input [SYSPNUM_W-1:0] sys_pnum_i; // System port number input.

//----------------------------------------------------------------------
// OUTPUTS
//----------------------------------------------------------------------
  output [LCLPNUM_W-1:0] lcl_pnum_o; // Local port number output.

  // One hot system master number output for bidi enabled 
  // configurations.
  output [`AXI_MAX_NUM_USR_MSTS-1:0] bidi_sys_pnum_oh_o;


  //--------------------------------------------------------------------
  // REGISTER VARIABLES.
  //--------------------------------------------------------------------

  // Local port system port numbers bus.
  reg [LCLPNUM_W*NUM_PSYS-1:0] bus_sys_port_lclnums; 
  
  // Map System Number to system port number (BICMD Support)
  reg [SYSPNUM_W-1:0] sys_pnum_map; // System port number input.


  //--------------------------------------------------------------------
  // WIRE VARIABLES.
  //--------------------------------------------------------------------
  // Signals not used in single master configurations
  wire [`AXI_MAX_NUM_MST_SLVS-1:0] bus_p_vis; // Bus containing all
                                              // port visibility 
                                              // parameters.

  wire [LCLPNUM_W-1:0] lcl_pnum_mpd; // Local port number mapped from
                                     // system port number.
  
  wire p0_vis;                
  wire p1_vis;                
  wire p2_vis;                
  wire p3_vis;                
  wire p4_vis;                
  wire p5_vis;                
  wire p6_vis;                
  wire p7_vis;                
  wire p8_vis;                
  wire p9_vis;                
  wire p10_vis;                
  wire p11_vis;                
  wire p12_vis;                
  wire p13_vis;                
  wire p14_vis;                
  wire p15_vis;                
  wire p16_vis;                
  
 
  // Individual decode signals for each master in a bi-directional
  // command flow enabled configuration.
  reg bidi_mp1_dec;  
  reg bidi_mp2_dec;        
  reg bidi_mp3_dec;        
  reg bidi_mp4_dec;        
  wire bidi_mp5_dec;        
  wire bidi_mp6_dec;        
  wire bidi_mp7_dec;        
  wire bidi_mp8_dec;        
  wire bidi_mp9_dec;        
  wire bidi_mp10_dec;        
  wire bidi_mp11_dec;        
  wire bidi_mp12_dec;        
  wire bidi_mp13_dec;        
  wire bidi_mp14_dec;        
  wire bidi_mp15_dec;        
  wire bidi_mp16_dec;        

  // Bus of one hot master port decodes.
  wire [`AXI_MAX_NUM_USR_MSTS-1:0] bidi_mp_dec_bus;

  // create bus wires for system master allowed through each
  // ICM port
   wire [SYSPNUM_W-1:0]            msts1_thru_icm1;
   wire [SYSPNUM_W-1:0]            msts2_thru_icm1;
   wire [SYSPNUM_W-1:0]            msts3_thru_icm1;
   wire [SYSPNUM_W-1:0]            msts4_thru_icm1;
   wire [SYSPNUM_W-1:0]            msts5_thru_icm1;
   wire [SYSPNUM_W-1:0]            msts6_thru_icm1;
   wire [SYSPNUM_W-1:0]            msts7_thru_icm1;
   wire [SYSPNUM_W-1:0]            msts8_thru_icm1;
                                                                                     
   wire [SYSPNUM_W-1:0]            msts1_thru_icm2;
   wire [SYSPNUM_W-1:0]            msts2_thru_icm2;
   wire [SYSPNUM_W-1:0]            msts3_thru_icm2;
   wire [SYSPNUM_W-1:0]            msts4_thru_icm2;
   wire [SYSPNUM_W-1:0]            msts5_thru_icm2;
   wire [SYSPNUM_W-1:0]            msts6_thru_icm2;
   wire [SYSPNUM_W-1:0]            msts7_thru_icm2;
   wire [SYSPNUM_W-1:0]            msts8_thru_icm2;
                                                                                     
   wire [SYSPNUM_W-1:0]            msts1_thru_icm3;
   wire [SYSPNUM_W-1:0]            msts2_thru_icm3;
   wire [SYSPNUM_W-1:0]            msts3_thru_icm3;
   wire [SYSPNUM_W-1:0]            msts4_thru_icm3;
   wire [SYSPNUM_W-1:0]            msts5_thru_icm3;
   wire [SYSPNUM_W-1:0]            msts6_thru_icm3;
   wire [SYSPNUM_W-1:0]            msts7_thru_icm3;
   wire [SYSPNUM_W-1:0]            msts8_thru_icm3;
                                                                                     
   wire [SYSPNUM_W-1:0]            msts1_thru_icm4;
   wire [SYSPNUM_W-1:0]            msts2_thru_icm4;
   wire [SYSPNUM_W-1:0]            msts3_thru_icm4;
   wire [SYSPNUM_W-1:0]            msts4_thru_icm4;
   wire [SYSPNUM_W-1:0]            msts5_thru_icm4;
   wire [SYSPNUM_W-1:0]            msts6_thru_icm4;
   wire [SYSPNUM_W-1:0]            msts7_thru_icm4;
   wire [SYSPNUM_W-1:0]            msts8_thru_icm4;

  // Array of system masters configured to send traffic
  // through each of the 4 ICM's in a single configuration.
  wire [SYSPNUM_W*`AXI_NUM_MST_THRU_ICM1-1:0] sys_msts_icm1;
  wire [SYSPNUM_W*`AXI_NUM_MST_THRU_ICM2-1:0] sys_msts_icm2;
  wire [SYSPNUM_W*`AXI_NUM_MST_THRU_ICM3-1:0] sys_msts_icm3;
  wire [SYSPNUM_W*`AXI_NUM_MST_THRU_ICM4-1:0] sys_msts_icm4;
  wire    dummy_wire  ;

  // Build up bus of port visibility parameters.
  assign p0_vis = P0_VIS;
  assign p1_vis = P1_VIS;
  assign p2_vis = P2_VIS;
  assign p3_vis = P3_VIS;
  assign p4_vis = P4_VIS;
  assign p5_vis = P5_VIS;
  assign p6_vis = P6_VIS;
  assign p7_vis = P7_VIS;
  assign p8_vis = P8_VIS;
  assign p9_vis = P9_VIS;
  assign p10_vis = P10_VIS;
  assign p11_vis = P11_VIS;
  assign p12_vis = P12_VIS;
  assign p13_vis = P13_VIS;
  assign p14_vis = P14_VIS;
  assign p15_vis = P15_VIS;
  assign p16_vis = P16_VIS;
   
  assign bus_p_vis = { p16_vis,
                       p15_vis,
                       p14_vis,
                       p13_vis,
                       p12_vis,
                       p11_vis,
                       p10_vis,
                       p9_vis,
                       p8_vis,
                       p7_vis,
                       p6_vis,
                       p5_vis,
                       p4_vis,
                       p3_vis,
                       p2_vis,
                       p1_vis,
                       p0_vis
                     };

  // Array of system masters configured to send traffic
  // through each of the 4 ICM's in a single configuration.

  // Assign these paramters to signals so they have fixed widths,
  // allows access in an array later.
  // spyglass disable_block W164a
  // SMD: Identifies assignments in which the LHS width is less than the RHS width
  // SJ : This is not a functional issue, this is as per the requirement.
  //      Hence this can be waived.
  // spyglass disable_block W163
  // SMD: Truncation of bits in constant integer conversion
  // SJ : This is not a functional issue, this is as per the requirement.
  //      Hence this can be waived.
  assign msts1_thru_icm1 = (`AXI_ALLOW_MST1_ICM1-1);
  assign msts2_thru_icm1 = (`AXI_ALLOW_MST2_ICM1-1);
  assign msts3_thru_icm1 = (`AXI_ALLOW_MST3_ICM1-1);
  assign msts4_thru_icm1 = (`AXI_ALLOW_MST4_ICM1-1);
  assign msts5_thru_icm1 = (`AXI_ALLOW_MST5_ICM1-1);
  assign msts6_thru_icm1 = (`AXI_ALLOW_MST6_ICM1-1);
  assign msts7_thru_icm1 = (`AXI_ALLOW_MST7_ICM1-1);
  assign msts8_thru_icm1 = (`AXI_ALLOW_MST8_ICM1-1);
  
  assign msts1_thru_icm2 = (`AXI_ALLOW_MST1_ICM2-1);
  assign msts2_thru_icm2 = (`AXI_ALLOW_MST2_ICM2-1);
  assign msts3_thru_icm2 = (`AXI_ALLOW_MST3_ICM2-1);
  assign msts4_thru_icm2 = (`AXI_ALLOW_MST4_ICM2-1);
  assign msts5_thru_icm2 = (`AXI_ALLOW_MST5_ICM2-1);
  assign msts6_thru_icm2 = (`AXI_ALLOW_MST6_ICM2-1);
  assign msts7_thru_icm2 = (`AXI_ALLOW_MST7_ICM2-1);
  assign msts8_thru_icm2 = (`AXI_ALLOW_MST8_ICM2-1);

  assign msts1_thru_icm3 = (`AXI_ALLOW_MST1_ICM3-1);
  assign msts2_thru_icm3 = (`AXI_ALLOW_MST2_ICM3-1);
  assign msts3_thru_icm3 = (`AXI_ALLOW_MST3_ICM3-1);
  assign msts4_thru_icm3 = (`AXI_ALLOW_MST4_ICM3-1);
  assign msts5_thru_icm3 = (`AXI_ALLOW_MST5_ICM3-1);
  assign msts6_thru_icm3 = (`AXI_ALLOW_MST6_ICM3-1);
  assign msts7_thru_icm3 = (`AXI_ALLOW_MST7_ICM3-1);
  assign msts8_thru_icm3 = (`AXI_ALLOW_MST8_ICM3-1);

  assign msts1_thru_icm4 = (`AXI_ALLOW_MST1_ICM4-1);
  assign msts2_thru_icm4 = (`AXI_ALLOW_MST2_ICM4-1);
  assign msts3_thru_icm4 = (`AXI_ALLOW_MST3_ICM4-1);
  assign msts4_thru_icm4 = (`AXI_ALLOW_MST4_ICM4-1);
  assign msts5_thru_icm4 = (`AXI_ALLOW_MST5_ICM4-1);
  assign msts6_thru_icm4 = (`AXI_ALLOW_MST6_ICM4-1);
  assign msts7_thru_icm4 = (`AXI_ALLOW_MST7_ICM4-1);
  assign msts8_thru_icm4 = (`AXI_ALLOW_MST8_ICM4-1);
  // spyglass enable_block W163


  assign sys_msts_icm1 = {msts8_thru_icm1,
                          msts7_thru_icm1,
                          msts6_thru_icm1,
                          msts5_thru_icm1,
                          msts4_thru_icm1,
                          msts3_thru_icm1,
                          msts2_thru_icm1,
                          msts1_thru_icm1};

  assign sys_msts_icm2 = {msts8_thru_icm2,
                          msts7_thru_icm2,
                          msts6_thru_icm2,
                          msts5_thru_icm2,
                          msts4_thru_icm2,
                          msts3_thru_icm2,
                          msts2_thru_icm2,
                          msts1_thru_icm2};
      
  assign sys_msts_icm3 = {msts8_thru_icm3,
                          msts7_thru_icm3,
                          msts6_thru_icm3,
                          msts5_thru_icm3,
                          msts4_thru_icm3,
                          msts3_thru_icm3,
                          msts2_thru_icm3,
                          msts1_thru_icm3};

  assign sys_msts_icm4 = {msts8_thru_icm4,
                          msts7_thru_icm4,
                          msts6_thru_icm4,
                          msts5_thru_icm4,
                          msts4_thru_icm4,
                          msts3_thru_icm4,
                          msts2_thru_icm4,
                          msts1_thru_icm4};     
  // spyglass enable_block W164a
                 


  // If there is more than 1 ICM, mp1 is only selected if one of the 
  // system masters configured to be addressed through ICM1 is detected
  // , otherwise mp1 is decoded if the system master is not on this 
  // instance.
//  The logic for bidi_mp1_dec is changed becoz of Lint Error
 

  assign    dummy_wire  = 1'b0;

  always @(*)
  begin: bidi_mp1_dec_PROC     
   bidi_mp1_dec     = dummy_wire;
  end
 

  // Decode if the system master in the upper ID field is 
  // accessed through ICM 2, or if MP2 is not an ICM if the ID 
  // should be routed to the system master at MP2 of this instance.
  // spyglass disable_block SelfDeterminedExpr-ML
  // SMD: Self determined expression found
  // SJ : The expression indexing the vector/array will never exceed the bound of the vector/array.        
  always @ (*) 
  begin : bidi_mp2_dec_PROC
    integer i;
    integer j;
    reg [SYSPNUM_W-1:0] sys_pnum;

    bidi_mp2_dec = 1'b0;
    if(((`AXI_SYS_NUM_FOR_M2-1) == sys_pnum_i) & p1_vis) begin
      bidi_mp2_dec = 1'b1;
    end
  end // bidi_mp1_dec_PROC


  // Decode if the system master in the upper ID field is 
  // accessed through ICM 3, or if MP3 is not an ICM if the ID 
  // should be routed to the system master at MP3 of this instance.
  always @ (*) 
  begin : bidi_mp3_dec_PROC
    integer i;
    integer j;
    reg [SYSPNUM_W-1:0] sys_pnum;

    bidi_mp3_dec = 1'b0;
    if(((`AXI_SYS_NUM_FOR_M3-1)== sys_pnum_i) & p2_vis) begin
      bidi_mp3_dec = 1'b1;
    end
  end // bidi_mp1_dec_PROC


  // Decode if the system master in the upper ID field is 
  // accessed through ICM 4, or if MP4 is not an ICM if the ID 
  // should be routed to the system master at MP4 of this instance.
  always @ (*) 
  begin : bidi_mp4_dec_PROC
    integer i;
    integer j;
    reg [SYSPNUM_W-1:0] sys_pnum;

    bidi_mp4_dec = 1'b0;
    if(((`AXI_SYS_NUM_FOR_M4-1) == sys_pnum_i) & p3_vis) begin
      bidi_mp4_dec = 1'b1;
    end
  end // bidi_mp1_dec_PROC
  // spyglass enable_block SelfDeterminedExpr-ML      

  // Decode if the system masters at the rest of the local master ports
  // are being targeted.
  assign bidi_mp5_dec = p4_vis & ((`AXI_SYS_NUM_FOR_M5-1) == sys_pnum_i);
  assign bidi_mp6_dec = p5_vis & ((`AXI_SYS_NUM_FOR_M6-1) == sys_pnum_i);
  assign bidi_mp7_dec = p6_vis & ((`AXI_SYS_NUM_FOR_M7-1) == sys_pnum_i);
  assign bidi_mp8_dec = p7_vis & ((`AXI_SYS_NUM_FOR_M8-1) == sys_pnum_i);
  assign bidi_mp9_dec = p8_vis & ((`AXI_SYS_NUM_FOR_M9-1) == sys_pnum_i);
  assign bidi_mp10_dec = p9_vis & ((`AXI_SYS_NUM_FOR_M10-1) == sys_pnum_i);
  assign bidi_mp11_dec = p10_vis & ((`AXI_SYS_NUM_FOR_M11-1) == sys_pnum_i);
  assign bidi_mp12_dec = p11_vis & ((`AXI_SYS_NUM_FOR_M12-1) == sys_pnum_i);
  assign bidi_mp13_dec = p12_vis & ((`AXI_SYS_NUM_FOR_M13-1) == sys_pnum_i);
  assign bidi_mp14_dec = p13_vis & ((`AXI_SYS_NUM_FOR_M14-1) == sys_pnum_i);
  assign bidi_mp15_dec = p14_vis & ((`AXI_SYS_NUM_FOR_M15-1) == sys_pnum_i);
  assign bidi_mp16_dec = p15_vis & ((`AXI_SYS_NUM_FOR_M16-1) == sys_pnum_i);


  // One hot bus of master port decodes.
  assign bidi_mp_dec_bus 
    = {bidi_mp16_dec,
       bidi_mp15_dec,
       bidi_mp14_dec,
       bidi_mp13_dec,
       bidi_mp12_dec,
       bidi_mp11_dec,
       bidi_mp10_dec,
       bidi_mp9_dec,
       bidi_mp8_dec,
       bidi_mp7_dec,
       bidi_mp6_dec,
       bidi_mp5_dec,
       bidi_mp4_dec,
       bidi_mp3_dec,
       bidi_mp2_dec,
       bidi_mp1_dec
      };

  // Shared R and B channels need a one hot system master number to
  // decode if the t/x is going to the shared R/B channel.
  assign bidi_sys_pnum_oh_o = bidi_mp_dec_bus;


  // If bi-directional command flow is enabled decode 1-hot
  // bidi_mp_dec_bus to a binary master port number.
  // Otherwise pass the upper ID bits unchanged.
  // mp is scaled to allow it to reach a value of
  // AXI_NUM_MASTERS. If it is scaled using AXI_LOG2_NM-1
  // then mp<AXI_NUM_MASTERS will never be true as mp will
  // wrap to 0 and we will have an infinite loop
 
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue
    always @ (*) begin : sys_pnum_map_PROC
      integer mp;
      sys_pnum_map = sys_pnum_i;
    end // sys_pnum_map_PROC 


  //--------------------------------------------------------------------
  // STATIC DECODE
  // Decode system port numbers corresponding local port numbers from 
  // input parameters.
  //--------------------------------------------------------------------
  // non_lcl_slv_bus reduced to visible slaves only. This is not an issue
  always @ (bus_p_vis) 
  begin : gen_lcl_pnums_PROC
    reg [LCLPNUM_W-1:0] lcl_pnum;

    integer sys_pnum;
    integer i; // Loop iterator below.

    bus_sys_port_lclnums = {(LCLPNUM_W*NUM_PSYS){1'b0}};
    lcl_pnum             = {LCLPNUM_W{1'b0}};

    // Search through all system ports to find a match for 
    // the current local port number. 
    for(sys_pnum=0; sys_pnum<=(NUM_PSYS-1); sys_pnum=sys_pnum+1) begin

      if(bus_p_vis[sys_pnum]) begin
        // Assign bit by bit as verilog does not allow variable
        // field widths.
        for(i=0 ; i<=(LCLPNUM_W-1) ; i=i+1) begin
          bus_sys_port_lclnums[(LCLPNUM_W*sys_pnum)+i] = lcl_pnum[i];
        end

        // When we match a system port number to a local port
        // number, the next visible system port will be
        // local port number lcl_pnum+1.
        lcl_pnum = lcl_pnum+1;         
      end

    end // for(sys_pnum...

  end // gen_lcl_pnums_PROC
  //spyglass enable_block W415a
  

  // This module implements the system port number to local
  // port number mux.
  DW_axi_busmux
  
  #(NUM_PSYS,     // Number of input busses.
    LCLPNUM_W,    // Width of each input bus.
    SYSPNUM_W     // Width of select line.
  )
  U_lcltosys_mux (
    .sel  (sys_pnum_map),
    .din  (bus_sys_port_lclnums), 
    .dout (lcl_pnum_mpd) 
  );
  

  // If the number of local ports is equal to the number of
  // system ports no mapping needs to be done so we can
  // assign the system port number straight to the local port
  // number.

  // spyglass disable_block W164a
  // SMD: Identifies assignments in which the LHS width is less than the RHS width
  // SJ : This is not a functional issue, this is as per the requirement.
  //      Hence this can be waived.
  generate
   if (NUM_PLCL==NUM_PSYS) 
    assign lcl_pnum_o = sys_pnum_map; 
   else
    assign lcl_pnum_o = lcl_pnum_mpd; 
  endgenerate
  // spyglass enable_block W164a


endmodule
