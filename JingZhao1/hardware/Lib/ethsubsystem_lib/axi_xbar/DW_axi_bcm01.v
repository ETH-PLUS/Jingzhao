
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
// Filename    : DW_axi_bcm01.v
// Revision    : $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_bcm01.v#11 $
// Author      : Rick Kelly     May 18, 2004
// Description : DW_axi_bcm01.v Verilog module for DW_axi
//
// DesignWare IP ID: f543d40e
//
////////////////////////////////////////////////////////////////////////////////


  module DW_axi_bcm01 (
      // Inputs
        a,
        tc,
        min_max,
      // Outputs
        value,
        index
);

parameter WIDTH =               4;      // element WIDTH
parameter NUM_INPUTS =          8;      // number of elements in input array
parameter INDEX_WIDTH =         3;      // size of index pointer = ceil(log2(NUM_INPUTS))

localparam [INDEX_WIDTH : 0] NUM_INPUTS_LOG2 = 1 << (INDEX_WIDTH);

input  [NUM_INPUTS*WIDTH-1 : 0]         a;      // Concatenated input vector
input                                   tc;     // 0 = unsigned, 1 = signed
input                                   min_max;// 0 = find min, 1 = find max
output [WIDTH-1:0]                      value;  // mon or max value found
output [INDEX_WIDTH-1:0]                index;  // index to value found

  DW_minmax #(WIDTH,NUM_INPUTS, INDEX_WIDTH) U1(
        .a(a),
        .tc(tc),
        .min_max(min_max),
        .value(value),
        .index(index) );


endmodule
