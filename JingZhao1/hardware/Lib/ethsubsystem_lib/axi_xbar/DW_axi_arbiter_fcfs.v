
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
// File Version     :        $Revision: #10 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_arbiter_fcfs.v#10 $ 
//
// Filename    : DW_axi_arbiter_fcfs.v
//
//
// Author      : James Feagans     May 20, 2004
// Description : DW_axi_arbiter_fcfs.v Verilog module for DWbb
//
// DesignWare IP ID: 22c35740
//
////////////////////////////////////////////////////////////////////////////////

// NOTE.
//jstokes, 31.03.2010, originally BCM54, name changed after custom DW_axi
//changes added - at comment marked with "jstokes"

// ABSTRACT:  Arbiter with first-come-first-served priority scheme
//   
// MODIFIED:


  module DW_axi_arbiter_fcfs (
  clk,
  rst_n,
  init_n,
  enable,
  request,
  lock,
  mask,
  use_other_pri,
  bus_pri_other,
 // bus_gnt_lk_i,
  parked,
  granted,
  locked,
  grant,
  grant_index,
  bus_pri
);

  parameter N                = 4; // RANGE 2 to 32
  parameter PARK_MODE        = 1; // RANGE 0 or 1
  parameter PARK_INDEX       = 0; // RANGE 0 to (N - 1)
  parameter OUTPUT_MODE      = 1; // RANGE 0 or 1
  `define m N+1
  parameter INDEX_WIDTH = 2; // RANGE 1 to 5
  parameter REAL_INDEX_WIDTH = 3; // RANGE 2 to 6
  parameter HAS_LOCKING = 0; // Locking features required.



  input        clk;   // clock input
  input        rst_n;   // active low reset
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input        init_n;   // active low reset
  input        enable;   // active high register enable
  input  [N-1: 0]    request; // client request bus
  input  [N-1: 0]    lock;   // client lock bus
  input  [N-1: 0]    mask;   // client mask bus
  // Signals used only when Locking is present
  // Internal priority bus from the other channels arbiter.
  input  [(N*REAL_INDEX_WIDTH)-1: 0] bus_pri_other;

  // 1 means use the internal priority of the other
  // address channel arbiter.
  input [N-1:0]    use_other_pri;
  //spyglass enable_block W240
  // Bit asserted for granted locking client.
  //input [N-1:0] bus_gnt_lk_i;

  output      parked;   // arbiter parked status flag
  output      granted; // arbiter granted status flag
  output      locked;   // arbeter locked status bus
  output [N-1: 0]    grant;   // one-hot granted client bus
  output [INDEX_WIDTH-1: 0]  grant_index; //ndex of current granted client 

  // Send internal priority to other address channel.
  output [(N*REAL_INDEX_WIDTH)-1: 0] bus_pri;

wire   [1:0] current_state, next_state_ff, st_vec;
reg    [1:0] next_state, state_ff;

reg    [N-1: 0] next_grant;
wire   [INDEX_WIDTH-1: 0] next_grant_index;
wire   next_parked, next_granted, next_locked;

reg    [N-1: 0] grant_int;
// Signals not used when OUTPUT_MODE is 1
wire   [INDEX_WIDTH-1: 0] grant_index_int;
reg    parked_int, granted_int, locked_int;


wire   [REAL_INDEX_WIDTH-1: 0] max_prior, maxp1_priority;
wire   [N-1: 0] masked_req;

wire   [(N*REAL_INDEX_WIDTH)-1: 0] prior, next_priority_ff;
reg    [(N*REAL_INDEX_WIDTH)-1: 0] priority_ff;

reg    [(N*REAL_INDEX_WIDTH)-1: 0] decr_prior;
reg    [(N*REAL_INDEX_WIDTH)-1: 0] next_prior;
reg    [INDEX_WIDTH-1: 0] grant_index_n_int;


reg    [(N*REAL_INDEX_WIDTH)-1: 0] priority_vec;

reg    [(N*REAL_INDEX_WIDTH)-1: 0] muxed_pri_vec;


wire   [INDEX_WIDTH-1: 0] current_index;

wire   [REAL_INDEX_WIDTH-1: 0] priority_value;

wire   [N-1: 0] temp_gnt;

wire   [N-1: 0] p_index, p_index_temp;

wire   [INDEX_WIDTH-1: 0] next_grant_index_n;
integer x1, y1;
integer i1, j1;
integer i2, j2, k2;
integer i3, j3;

  //spyglass disable_block W163
  //SMD: Truncation of bits in constant integer conversion
  //SJ: Rest of the bits can be ignored
  assign maxp1_priority = (N > ((1 << INDEX_WIDTH) - 1'b1) ) ?
    N: ((1 << INDEX_WIDTH) - 1'b1);
  //spyglass enable_block W163
  //Width of maxp1_priority refers to number of slaves/clients connected to arbiter plus 1. So priority will be assigned based on number of clients attached. Hence if width will become 2 then no need of priority because only one slave is attched. Hence variable length assignment in LHS and RHS won't cause any functionality issue. 
  assign max_prior = maxp1_priority - 1'b1;

  assign masked_req = request & (~mask);

  assign next_locked = |(grant_int & lock);

  assign next_granted = next_locked | (|masked_req);

  assign next_parked = ~next_granted;


  // spyglass disable_block SelfDeterminedExpr-ML
  // SMD: Self determined expression found
  // SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
  //always @(prior or masked_req or maxp1_priority) begin : PROC_reorder_input
  //VP:: Fix for LINT ERROR STAR 9000442091
  // replaced sensitivity list by *
  always @(*) begin : reorder_input_PROC
    for (i1=0 ; i1<N ; i1=i1+1) begin
      for (j1=0 ; j1<REAL_INDEX_WIDTH ; j1=j1+1) begin
  priority_vec[i1*REAL_INDEX_WIDTH+j1] = (j1 == INDEX_WIDTH) ?
          1'b0: prior[i1*REAL_INDEX_WIDTH+j1];
  muxed_pri_vec[i1*REAL_INDEX_WIDTH+j1] = (masked_req[i1]) ?
          priority_vec[i1*REAL_INDEX_WIDTH+j1]: maxp1_priority[j1];
      end
    end
  end

  always @(prior) begin : predec_PROC
    reg  [(REAL_INDEX_WIDTH)-1: 0] temp_prior, temp2_prior;
    for (i2=0 ; i2<N ; i2=i2+1) begin
      for (j2=0 ; j2<REAL_INDEX_WIDTH ; j2=j2+1) begin
        temp_prior[j2] = prior[i2*REAL_INDEX_WIDTH+j2];
      end
      // Width of temp_prior refers to number of slaves/clients connected to arbiter. So priority will be assigned based on number of clients attached. Hence if width will become 1 then no need of priority because only one slave is attched. Hence variable length assignment in LHS and RHS won't cause any functionality issue.
      temp2_prior = temp_prior - 1'b1;

      for (k2=0 ; k2<REAL_INDEX_WIDTH ; k2=k2+1) begin
        decr_prior[i2*REAL_INDEX_WIDTH+k2] = temp2_prior[k2];
      end

    end
  end
  // spyglass enable_block SelfDeterminedExpr-ML


  assign st_vec = {next_parked, next_locked};

  always @(current_state or st_vec) begin : mk_nxt_st_PROC
    case (current_state)
    2'b00: begin
      case (st_vec)
      2'b00: next_state = 2'b10;
      2'b10: next_state = 2'b01;
      default: next_state = 2'b00;
      endcase
    end
    2'b01: begin
      case (st_vec)
      2'b00: next_state = 2'b10;
      2'b01: next_state = 2'b11;
      default: next_state = 2'b01;
      endcase
    end
    2'b10: begin
      case (st_vec)
      2'b01: next_state = 2'b11;
      2'b10: next_state = 2'b01;
      default: next_state = 2'b10;
      endcase
    end
    default: begin
      case (st_vec)
      2'b00: next_state = 2'b10;
      2'b10: next_state = 2'b01;
      default: next_state = 2'b11;
      endcase
    end
    endcase
  end

  assign current_state = state_ff ^ 2'b00;
  assign next_state_ff = next_state ^ 2'b00;

  // spyglass disable_block SelfDeterminedExpr-ML
  // SMD: Self determined expression found
  // SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
  always @(*) begin : mk_nxt_prior_PROC
    for (i3=0 ; i3<N ; i3=i3+1) begin
      for (j3=0 ; j3<REAL_INDEX_WIDTH ; j3=j3+1) begin
        case (current_state)
        2'b00: begin
          if (masked_req[i3]) begin
            if (next_grant[i3]) begin
              next_prior[i3*REAL_INDEX_WIDTH+j3] = max_prior[j3];
            end else begin
              next_prior[i3*REAL_INDEX_WIDTH+j3] = decr_prior[i3*REAL_INDEX_WIDTH+j3];
            end
          end else begin
            next_prior[i3*REAL_INDEX_WIDTH+j3] = max_prior[j3];
          end
        end
        2'b01: begin
          if (next_locked) begin
            if (masked_req[i3]) begin
              if (next_grant[i3]) begin
                next_prior[i3*REAL_INDEX_WIDTH+j3] = prior[i3*REAL_INDEX_WIDTH+j3];
              end else begin
                next_prior[i3*REAL_INDEX_WIDTH+j3] = decr_prior[i3*REAL_INDEX_WIDTH+j3];
              end
            end else begin
              next_prior[i3*REAL_INDEX_WIDTH+j3] = max_prior[j3];
            end
          end else begin
            if (masked_req[i3]) begin
              if (next_grant[i3]) begin
                next_prior[i3*REAL_INDEX_WIDTH+j3] = max_prior[j3];
              end else begin
                next_prior[i3*REAL_INDEX_WIDTH+j3] = decr_prior[i3*REAL_INDEX_WIDTH+j3];
              end
            end else begin
              next_prior[i3*REAL_INDEX_WIDTH+j3] = max_prior[j3];
            end
          end
        end
        default: begin
          if (next_locked) begin
            if (masked_req[i3] == 1'b0) begin
              next_prior[i3*REAL_INDEX_WIDTH+j3] = max_prior[j3];
            end else begin
              next_prior[i3*REAL_INDEX_WIDTH+j3] = prior[i3*REAL_INDEX_WIDTH+j3];
            end
          end else begin
            if (masked_req[i3] == 1'b0) begin
              next_prior[i3*REAL_INDEX_WIDTH+j3] = max_prior[j3];
            end else begin
              if (next_grant[i3]) begin
                next_prior[i3*REAL_INDEX_WIDTH+j3] = max_prior[j3];
              end else begin
                next_prior[i3*REAL_INDEX_WIDTH+j3] = decr_prior[i3*REAL_INDEX_WIDTH+j3];
              end
            end
          end
        end

        endcase
      end
    end
  end
  // spyglass enable_block SelfDeterminedExpr-ML


  
    DW_axi_bcm01
     #(REAL_INDEX_WIDTH, N, INDEX_WIDTH) U_minmax (
    .a(muxed_pri_vec),
    .tc(1'b0),
    .min_max(1'b0),
    .value(priority_value),
    .index(current_index) );


  // one hot decode function
  function automatic [N-1:0] func_decode;
    input [INDEX_WIDTH-1:0]    a;  // input
    reg   [N-1:0]    z;
    integer    i;
    begin
      z = {N{1'b0}};
      for (i=0 ; i<N ; i=i+1) begin
  if (i == a) begin
    z [i] = 1'b1;
  end // if
      end // for (i
      func_decode = z;
    end
  endfunction

  assign temp_gnt = func_decode( current_index );

  //decoding function for priority index
  function automatic [N-1:0] func_decode_p_index;
    input [INDEX_WIDTH-1:0]    a;  // input
    reg   [N-1:0]    z;
    integer    i;
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
  always @(next_parked or next_locked or grant_int or p_index or temp_gnt) begin : mk_nxt_gr_PROC
    case ({next_parked, next_locked}) 
    2'b00: next_grant = temp_gnt;
    2'b01: next_grant = grant_int;
    2'b10: next_grant = p_index;
    default: next_grant = grant_int;
    endcase
  end


  //Binary Encoding Function 
  function automatic [INDEX_WIDTH-1:0] func_binenc;
    input [N-1:0]    a;  // input
    reg   [INDEX_WIDTH-1:0]    z;
    integer    i;
    reg [31:0] j;
    begin
      z = {INDEX_WIDTH{1'b1}};
      for (i=N ; i > 0 ; i=i-1) begin
        j = i-1;
  if (a[j] == 1'b1)
    z = j [INDEX_WIDTH-1:0];
      end // for (i
      func_binenc = z;
    end
  endfunction

  assign next_grant_index = func_binenc( next_grant );
  // Signals not used if OUTPUT_MODE=0

  always @(posedge clk or negedge rst_n) begin : regs_PROC
    if (~rst_n) begin
      state_ff            <= 2'b00;
      grant_index_n_int   <= {INDEX_WIDTH{1'b0}};
      parked_int          <= 1'b0;
      granted_int         <= 1'b0;
      locked_int          <= 1'b0;
      grant_int           <= {N{1'b0}};
    end else if (init_n == 1'b0) begin
      state_ff            <= 2'b00;
      grant_index_n_int   <= {INDEX_WIDTH{1'b0}};
      parked_int          <= 1'b0;
      granted_int         <= 1'b0;
      locked_int          <= 1'b0;
      grant_int           <= {N{1'b0}};
    end else if (enable) begin
      state_ff            <= next_state_ff;
      grant_index_n_int   <= next_grant_index_n;
      parked_int          <= next_parked;
      granted_int         <= next_granted;
      locked_int          <= next_locked;
      grant_int           <= next_grant;
    end
  end
 // jstokes, 31.03.2010
 // Take internal priority from the other address channel for locking
 // clients when instructed.
  generate
  if(HAS_LOCKING)
  begin
    always @(posedge clk or negedge rst_n) begin : PRIORITY_FF_PROC
      if (~rst_n)
        priority_ff      <= {N*REAL_INDEX_WIDTH{1'b0}};
      else if (init_n == 1'b0) 
        priority_ff      <= {N*REAL_INDEX_WIDTH{1'b0}};
      else if (enable) begin
        for (x1=0 ; x1<N ; x1=x1+1) begin
          // spyglass disable_block SelfDeterminedExpr-ML
          // SMD: Self determined expression found
          // SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
          if(use_other_pri[x1]) begin
            for (y1=0 ; y1<REAL_INDEX_WIDTH ; y1=y1+1) begin
              priority_ff[x1*REAL_INDEX_WIDTH+y1]
                <= bus_pri_other[x1*REAL_INDEX_WIDTH+y1];
            end
          end else begin
            for (y1=0 ; y1<REAL_INDEX_WIDTH ; y1=y1+1) begin
              priority_ff[x1*REAL_INDEX_WIDTH+y1]
                <= next_priority_ff[x1*REAL_INDEX_WIDTH+y1];
            end
          end
          // spyglass enable_block SelfDeterminedExpr-ML
        end
      end
    end  
  end
  else
  begin
    always @(posedge clk or negedge rst_n) begin : INT_PRIORITY_PROC
      if (~rst_n)
        priority_ff      <= {N*REAL_INDEX_WIDTH{1'b0}};
      else if (init_n == 1'b0) 
        priority_ff      <= {N*REAL_INDEX_WIDTH{1'b0}};
      else if (enable) 
        priority_ff <= next_priority_ff;
    end    
  end 
  endgenerate

  // jstokes, 31.03.2010
  // Send internal priority to the other address channel.
  assign bus_pri = next_priority_ff;

  assign next_priority_ff = {N{max_prior}} ^ next_prior;
  assign prior = {N{max_prior}} ^ priority_ff;

  assign next_grant_index_n  = ~next_grant_index;
  assign grant_index_int     = ~grant_index_n_int;

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
