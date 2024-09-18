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
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_busmux.v#8 $ 
**
** ---------------------------------------------------------------------
**
** File     : DW_axi_busmux.v
//
//
** Created  : Thu May 26 13:27:47 MEST 2005
** Modified : $Date: 2020/03/22 $
** Abstract : Parameterized one-hot mux that will
**            multiplex several buses (quantity specified
**            at compile time, and controlled by a parameter)
**            of a particular width (which is also specified at
**            compile time by a parameter). For example, the same
**            module would be able to mux three 12-bit buses, or
**            seven 5-bit buses, or any other combination,
**            depending on the parameter values used when the
**            module is instantiated.
**
** ---------------------------------------------------------------------
*/


module DW_axi_busmux ( sel, din, dout );

  parameter BUS_COUNT = 2;   // Number of input buses.
  parameter MUX_WIDTH = 3;   // Bit width of data buses.
  parameter SEL_WIDTH = 1;   // Width of select line.

  input [SEL_WIDTH-1:0]           sel;  // Select signal.

  input [MUX_WIDTH*BUS_COUNT-1:0] din;  // Concatenated input buses.
  wire  [MUX_WIDTH*BUS_COUNT-1:0] din;  
  output [MUX_WIDTH-1:0] dout; // Output data bus.
  reg    [MUX_WIDTH-1:0] dout;             


  reg [BUS_COUNT-1:0] sel_oh; // One-hot select signals.


  // Create one hot version of sel input.
  // Used as select line for the mux.
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue.
  always @(sel) 
  begin : sel_oh_PROC
    integer busnum;

    sel_oh = {BUS_COUNT{1'b0}};

    for(busnum=0 ; busnum<=(BUS_COUNT-1) ; busnum=busnum+1) begin
      if(sel == busnum) sel_oh[busnum] = 1'b1;
    end

  end
  //spyglass enable_block W415a


  // One of the subtleties that might not be obvious that makes 
  // this work so well is the use of the blocking assignment (=) 
  // that allows dout to be built up incrementally. 
  // The one-hot select builds up into the wide "or" function 
  // you'd code by hand.
  // spyglass disable_block W415a
  // SMD: Signal may be multiply assigned (beside initialization) in the same scope
  // SJ : This is not an issue.
  // spyglass disable_block SelfDeterminedExpr-ML
  // SMD: Self determined expression found
  // SJ : The expression indexing the vector/array will never exceed the bound of the vector/array.        
  always @ (*) begin : mux_logic_PROC
     integer i, j;
     dout = {MUX_WIDTH{1'b0}};
     for (i = 0; i <= (BUS_COUNT-1); i = i + 1) begin
       for (j = 0; j <= (MUX_WIDTH-1); j = j + 1) begin
         dout[j] = dout[j] | din[MUX_WIDTH*i +j]&sel_oh[i];
       end
     end
  end // always
  // spyglass enable_block SelfDeterminedExpr-ML      
  //spyglass enable_block W415a


endmodule // DW_axi_busmux

