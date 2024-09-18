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
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_lcltosys.v#9 $ 
**
** ---------------------------------------------------------------------
**
** File     : DW_axi_lcltosys.v
//
//
** Created  : Tue May 24 17:09:09 MEST 2005
** Modified : $Date: 2020/03/22 $
** Abstract : The purpose of this module is to map local port
**            numbers to system port numbers within the DW_axi
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


module DW_axi_lcltosys (
  // Inputs.
  lcl_pnum_i,
  
  // Outputs.
  sys_pnum_o
);

//----------------------------------------------------------------------
// MODULE PARAMETERS.
//----------------------------------------------------------------------
  parameter NUM_PLCL = 17; // Number of visible/local ports.

  parameter LCLPNUM_W = 5; // Width of local port number signals. 

  parameter NUM_PSYS = 17; // Number of ports in the system, master or
                           // slave depending on which one we are 
                           // dealing with.

  parameter LOG2_NUM_PSYS = 5; 

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
  
  // 0 => Binary encoded output slave number.
  // 1 => 1 hot encoded output slave number.
  parameter ONE_HOT = 0;

  // Switch output slave numbers width depending on seleted encoding.
  localparam SYS_PNUM_W = ONE_HOT ? NUM_PSYS : LOG2_NUM_PSYS;

//----------------------------------------------------------------------
// PORT DECLARATIONS.
//----------------------------------------------------------------------

//----------------------------------------------------------------------
// INPUTS
//----------------------------------------------------------------------
  input [LCLPNUM_W-1:0] lcl_pnum_i; // Local port number input.

//----------------------------------------------------------------------
// OUTPUTS
//----------------------------------------------------------------------
  output [SYS_PNUM_W-1:0] sys_pnum_o; // System port number output.


  //--------------------------------------------------------------------
  // REGISTER VARIABLES.
  //--------------------------------------------------------------------

  // Local port system port numbers bus.
  reg [SYS_PNUM_W*NUM_PLCL-1:0] bus_lcl_port_sysnums; 


  //--------------------------------------------------------------------
  // WIRE VARIABLES.
  //--------------------------------------------------------------------
  // Bus has been created for maximum config. Lower configs some of the bits may remain unused 
  wire [`AXI_MAX_NUM_MST_SLVS-1:0] bus_p_vis; // Bus containing all
                                              // port visibility 
  wire [SYS_PNUM_W-1:0] sys_pnum_mpd; // System port number mapped from
                                              // parameters.

  
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

  
  // Build up bus of port visibility parameters.               
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
                 

  //--------------------------------------------------------------------
  // STATIC DECODE
  // Decode local port numbers corresponding system port numbers from 
  // input parameters.
  //--------------------------------------------------------------------
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue.
  always @ (bus_p_vis) 
  begin : gen_sys_pnums_PROC
    reg [LCLPNUM_W-1:0] lcl_pnum;
    reg [SYS_PNUM_W-1:0] sys_pnum;

    integer sys_pnum_intg;

    integer i; // loop iterator below.

    bus_lcl_port_sysnums = {SYS_PNUM_W*NUM_PLCL{1'b0}};
    lcl_pnum             = {LCLPNUM_W{1'b0}};
    sys_pnum             = {SYS_PNUM_W{1'b0}}; 

    // For every visible/local port, search through system port
    // visibility parameters to decode corresponding system port
    // number.
    for(sys_pnum_intg=0; 
        sys_pnum_intg<=(NUM_PSYS-1); 
        sys_pnum_intg=sys_pnum_intg+1
       ) 
    begin
      if(bus_p_vis[sys_pnum_intg]) begin
        // Select one hot or binary system master number encoding.
        sys_pnum = ONE_HOT 
                   ? (1'b1 << sys_pnum_intg) 
                   : sys_pnum_intg;

        // Assign bit by bit as verilog does not allow variable
        // field widths.
        for(i=0 ; i<=(SYS_PNUM_W-1) ; i=i+1) begin
          bus_lcl_port_sysnums[(SYS_PNUM_W*lcl_pnum)+i] = sys_pnum[i];
        end
  
        // When we match a local port number to a system port
        // number, for the next local port number we only want
        // to search from the system port after the one currently
        // matched to find the next local <-> system port number
        // mapping.
        lcl_pnum = lcl_pnum+1;  
      end
    
    end // for(sys_pnum_intg...

  end // gen_sys_pnums_PROC
  //spyglass enable_block W415a
  

  // This module implements the local port number to system
  // port number mux.
  DW_axi_busmux
  
  #(NUM_PLCL,   // Number of input busses.
    SYS_PNUM_W,  // Bit width of each input bus.
    LCLPNUM_W   // Width of select line.
  )
  U_lcltosys_mux (
    .sel  (lcl_pnum_i),
    .din  (bus_lcl_port_sysnums), 
    .dout (sys_pnum_mpd) 
  );
  

  // If the number of local ports is equal to the number of
  // system ports, and one hot encoding is not required, 
  // no mapping needs to be done so we can assign the local
  // port number straight to the system port number.
  generate
  if ((NUM_PLCL==NUM_PSYS) & (ONE_HOT==0))
     assign sys_pnum_o = lcl_pnum_i; 
  else
     assign sys_pnum_o = sys_pnum_mpd;
  endgenerate

endmodule
