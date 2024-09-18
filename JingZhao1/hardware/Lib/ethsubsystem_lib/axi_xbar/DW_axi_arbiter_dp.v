////////////////////////////////////////////////////////////////////////////////
//
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
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_arbiter_dp.v#9 $ 
//
// Filename    : DW_axi_arbiter_dp.v
// Author      : James Feagans     May 10, 2004
// Description : DW_axi_arbiter_dp.v Verilog module for DW_axi
//
//
//
// DesignWare IP ID: 8a05a938
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// ABSTRACT:  Arbiter with dynamic priority scheme
//   
// MODIFIED:
////////////////////////////////////////////////////////////////////////////////



//VCS coverage exclude_file

module DW_axi_arbiter_dp (
  clk,
  enable,
  rst_n,
  request,
  prior,
  lock,
  mask,
  parked,
  granted,
  locked,
  grant,
  grant_index
);


  parameter N              = 4; // RANGE 2 to 32
  parameter PRIOR_WIDTH    = 2; // RANGE 1 to 5.
  parameter PARK_MODE      = 1; // 0 or 1
  parameter PARK_INDEX     = 0; // RANGE 0 to (N - 1)
  parameter OUTPUT_MODE    = 1; // 0 or 1
  parameter INDEX_WIDTH    = 2; // RANGE 1 to 5
  parameter PRIOR_WIDTH_P1 = PRIOR_WIDTH+1; // RANGE 2 to 6


  input        clk;   // Clock input
  input        enable;   // active high register enable
  input        rst_n;   // active low reset
  input  [N-1: 0]    request; // client request bus
  input  [PRIOR_WIDTH*N-1: 0]  prior;   // client priority bus
  input  [N-1: 0]    lock;   // client lock bus
  input  [N-1: 0]    mask;   // client mask bus
  
  output      parked;   // arbiter parked status flag
  output      granted; // arbiter granted status flag
  output      locked;   // arbiter locked status flag
  output [N-1: 0]    grant;   // one-hot client grant bus
  output [INDEX_WIDTH-1: 0]  grant_index; //   index of current granted client

//Signals not used when OUTPUT_MODE is 1
reg    [N-1: 0] next_grant;
wire   [INDEX_WIDTH-1: 0] next_grant_index;
wire   next_parked, next_granted, next_locked;


reg    [N-1: 0] grant_int;
reg    [INDEX_WIDTH-1: 0] grant_index_int;
reg    parked_int, granted_int, locked_int;

wire   [PRIOR_WIDTH_P1-1: 0] maxp1_priority;
wire   [N-1: 0] masked_req;

wire   [N-1: 0] temp_gnt;

wire   [N-1: 0] p_index, p_index_temp;


reg    [(N*PRIOR_WIDTH_P1)-1: 0] priority_vec;

reg    [N*PRIOR_WIDTH_P1-1: 0] muxed_pri_vec;

wire   [INDEX_WIDTH-1: 0] current_index;

wire   [PRIOR_WIDTH_P1-1: 0] priority_value;

integer i1, j1;

  assign maxp1_priority = {PRIOR_WIDTH_P1{1'b1}};

  assign masked_req = request & (~mask);

  assign next_locked = |(grant_int & lock);

  assign next_granted = next_locked | (|masked_req);

  assign next_parked = ~next_granted;

// reg  [PRIOR_WIDTH*N-1: 0]  prior_c;   // client priority bus
// always @(*) begin
//    for (i1=0 ; i1<N ; i1=i1+1) begin
//     for (j1=0 ; j1<PRIOR_WIDTH ; j1=j1+1) begin
//         if (request[i1])
//         prior_c[i1*PRIOR_WIDTH+j1] = prior[i1*PRIOR_WIDTH+j1];
//         else prior_c[i1*PRIOR_WIDTH+j1] = 1'b1;
// end   
// end
// end
  // spyglass disable_block SelfDeterminedExpr-ML
  // SMD: Self determined expression found
  // SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
  always @(*) begin: MUXED_PRI_VEC_PROC
    for (i1=0 ; i1<N ; i1=i1+1) begin
      for (j1=0 ; j1<PRIOR_WIDTH_P1 ; j1=j1+1) begin
  priority_vec[i1*PRIOR_WIDTH_P1+j1] = (j1 == PRIOR_WIDTH) ?
          1'b0: prior[i1*PRIOR_WIDTH+j1];
  muxed_pri_vec[i1*PRIOR_WIDTH_P1+j1] = (masked_req[i1]) ?
          ((j1 == PRIOR_WIDTH)?  1'b0: prior[i1*PRIOR_WIDTH+j1]) : maxp1_priority[j1];
      end
    end
  end
  // spyglass enable_block SelfDeterminedExpr-ML
 
 
 
    DW_axi_bcm01
     #(PRIOR_WIDTH_P1, N, INDEX_WIDTH) U_minmax (
    .a(muxed_pri_vec),
    .tc(1'b0),
    .min_max(1'b0),
    .value(priority_value),
    .index(current_index) );


  //Grant index to one hot encoding  
  function automatic [N-1:0] func_decode;
    input [INDEX_WIDTH-1:0]    a;  // input
    reg   [N-1:0]    z;
    integer i;
    begin
      z = {N{1'b0}};
      for (i=0 ; i<N ; i=i+1) begin
  // Signed and unsigned operands should not be used in same operation 
  // Comparison works fine there is no functional issue   
  if (i == a) begin
    z [i] = 1'b1;
  end // if
      end // for (i
      func_decode = z;
    end
  endfunction

  assign temp_gnt = func_decode( current_index );

  // Park index one hot decoding 
  function automatic [N-1:0] func_decode_p_index;
    input [INDEX_WIDTH-1:0]    a;  // input
    reg   [N-1:0]    z;
    integer i;
    begin
      z = {N{1'b0}};
      for (i=0 ; i<N ; i=i+1) begin
  if (i == a) begin
    z [i] = 1'b1;
  end // if
      end // for (i
      func_decode_p_index = z;
    end
  endfunction

  assign p_index_temp = func_decode_p_index( PARK_INDEX );
  assign p_index = (PARK_MODE == 0) ? {N{1'b0}}: p_index_temp;

// Signals not used when OUTPUT_MODE is 1
  always @(*) begin : NEXT_GRANT_PROC
    case ({next_parked, next_locked}) 
      2'b00: next_grant = temp_gnt;
      2'b01: next_grant = grant_int;
      2'b10: next_grant = p_index;
      default: next_grant = grant_int;
    endcase
  end


  // Binary encoding function 
  function automatic [INDEX_WIDTH-1:0] func_binenc;
    input [N-1:0]    a;  // input
    reg   [INDEX_WIDTH-1:0]    z;
    integer i,j;
    begin
      z = {INDEX_WIDTH{1'b1}};
      for (i=N ; i > 0 ; i=i-1) begin
        j = i-1;
  if (a[j] == 1'b1)
    z = j ;
      end // for (i
      func_binenc = z;
    end
  endfunction

  assign next_grant_index = func_binenc( next_grant );

  //spyglass disable_block FlopEConst
  //SMD: Enable pin EN on Flop is always enabled
  //SJ: Warning can be ignored
  //Signals not used when OUTPUT_MODE is 1

  always @(posedge clk or negedge rst_n) begin: INT_SIG_REG_PROC
    if (~rst_n) begin
      grant_index_int     <= {INDEX_WIDTH{1'b1}};
      parked_int          <= 1'b0;
      granted_int         <= 1'b0;
      locked_int          <= 1'b0;
      grant_int           <= {N{1'b0}};
    end
    else if (enable) begin
      grant_index_int     <= next_grant_index;
      parked_int          <= next_parked;
      granted_int         <= next_granted;
      locked_int          <= next_locked;
      grant_int           <= next_grant;
    end
  end
  //spyglass enable_block FlopEConst

  assign grant       = (OUTPUT_MODE == 0) ? next_grant :
                        grant_int;
  assign grant_index = (OUTPUT_MODE == 0) ? next_grant_index :
                        grant_index_int;
  assign granted     = (OUTPUT_MODE == 0) ? next_granted : 
                  granted_int;
  assign parked      = (PARK_MODE == 0) ? 1'b0:
                         (OUTPUT_MODE == 0) ? next_parked : 
                    parked_int;
  assign locked      = (OUTPUT_MODE == 0) ? next_locked : 
                  locked_int;

endmodule

