
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
// File Version     :        $Revision: #11 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_arbiter_fae.v#11 $ 
//
// Filename    : DW_axi_arbiter_fae.v
//
//
// Author      : James Feagans     May 20, 2004
// Description : DW_axi_arbiter_fae.v Verilog module for DWbb
//
// DesignWare IP ID: 35d47de1
//
////////////////////////////////////////////////////////////////////////////////

// NOTE.
//jstokes, 31.03.2010, originally BCM53, name changed after custom DW_axi
//changes added - at comment marked with "jstokes"




  module DW_axi_arbiter_fae (
  clk,
  rst_n,
  init_n,
  enable,
  request,
  prior,
  lock,
  mask,
  use_other_pri,
  //bus_gnt_lk_i,
  bus_pri_other,
       
  parked,
  granted,
  locked,
  grant,
  grant_index,
  bus_pri
);

                          
  parameter N           = 4;  // RANGE 2 TO 32
  parameter P_WIDTH     = 2;  // RANGE 1 TO 5
  parameter PARK_MODE   = 1;  // RANGE 0 OR 1
  parameter PARK_INDEX  = 0;  // RANGE 0 TO 31
  parameter OUTPUT_MODE = 1;  // RANGE 0 OR 1
  parameter INDEX_WIDTH = 2;  // RANGE 1 to 5
  parameter HAS_LOCKING = 0; // Add AXI locking features.


  input        clk;   // Clock input
  input        rst_n;   // active low reset
  input        init_n;   // active low reset
  input        enable;   // active high register enable
  input  [N-1: 0]    request; // client request bus
  input  [P_WIDTH*N-1: 0]  prior;   // client priority bus
  input  [N-1: 0]    lock;   // client lock bus
  input  [N-1: 0]    mask;   // client mask bus
  // Signals used only when Locking is present 
  // Internal priority bus from the other channels arbiter.
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input  [(N*INDEX_WIDTH)-1: 0] bus_pri_other;

  // 1 means use the internal priority of the other
  // address channel arbiter.
  input  [N-1: 0]    use_other_pri;
  //spyglass enable_block W240
  // Bit asserted for granted locking client.
  //input [N-1:0] bus_gnt_lk_i;

  output      parked;   // arbiter parked status flag
  output      granted; // arbiter granted status flag
  output      locked;   // arbiter locked status flag
  output [N-1: 0]    grant;   // one-hot client grant bus
  output [INDEX_WIDTH-1: 0]  grant_index; //   index of current granted client

  // Send internal priority to other address channel.
  output [(N*INDEX_WIDTH)-1: 0] bus_pri;
  
  reg [N-1:0] bus_current_ext_pri_lt;
  reg [1:0] current_state, next_state;
  reg [P_WIDTH-1:0] tmp_client_pri;
  reg [P_WIDTH-1:0] tmp_current_pri;
  wire [1:0] st_vec;

  wire   [N-1: 0] next_grant;
  wire   [INDEX_WIDTH-1: 0] next_grant_index;
  wire   next_parked, next_granted, next_locked;

  reg    [N-1: 0] grant_int;
  reg    [INDEX_WIDTH-1: 0] grant_index_int;
  reg    parked_int, granted_int, locked_int;

  reg    [INDEX_WIDTH-1: 0] temp_prior, temp2_prior;

  wire   [(P_WIDTH+INDEX_WIDTH+1)-1: 0] maxp1_priority;
  wire   [INDEX_WIDTH-1: 0] max_prior;
  wire   [N-1: 0] masked_req;
  wire   active_request;

  integer i1, j1, k1, l1, i2, j2, k2, i3, l3;
  integer x1, y1;
  
  
  reg    [(N*INDEX_WIDTH)-1: 0] int_priority;

  reg    [(N*INDEX_WIDTH)-1: 0] decr_prior;

  reg    [(N*(P_WIDTH+INDEX_WIDTH+1))-1: 0] priority_vec;

  reg    [(N*(P_WIDTH+INDEX_WIDTH+1))-1: 0] muxed_pri_vec;

  reg    [(N*INDEX_WIDTH)-1: 0] next_prior;
  wire   [INDEX_WIDTH-1: 0] current_index;
  wire [P_WIDTH+INDEX_WIDTH:00] current_value;  
    

  wire   [N-1: 0] temp_gnt;

  wire   [N-1: 0] p_index, p_index_temp;

  assign maxp1_priority = {P_WIDTH+INDEX_WIDTH+1{1'b1}};
  assign max_prior = {INDEX_WIDTH{1'b1}};

  assign masked_req = request & (~mask);

  assign active_request = |masked_req;

  assign next_locked = |(grant_int & lock);

  assign next_granted = next_locked | active_request;

  assign next_parked = ~next_granted;


// spyglass disable_block SelfDeterminedExpr-ML
// SMD: Self determined expression found
// SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
  always @(prior or int_priority)
  begin:C_PRIORITY_VEC_PROC
    for (i1=0 ; i1<N ; i1=i1+1) begin
      for (j1=0 ; j1<(P_WIDTH+INDEX_WIDTH+1) ; j1=j1+1) begin
        if (j1 == (P_WIDTH+INDEX_WIDTH+1) - 1) begin
          priority_vec[i1*(P_WIDTH+INDEX_WIDTH+1)+j1] = 1'b0;
        end
        else if (j1 >= INDEX_WIDTH) begin
          priority_vec[i1*(P_WIDTH+INDEX_WIDTH+1)+j1] = prior[i1*P_WIDTH+(j1-(INDEX_WIDTH))];
        end
        else begin
          priority_vec[i1*(P_WIDTH+INDEX_WIDTH+1)+j1] = int_priority[i1*INDEX_WIDTH+j1];
        end
      end
    end
  end

  always @(priority_vec or masked_req or maxp1_priority)
  begin:C_MUXED_PRI_VEC_PROC
    for (k1=0 ; k1<N ; k1=k1+1) begin
      for (l1=0 ; l1<(P_WIDTH+INDEX_WIDTH+1) ; l1=l1+1) begin
  muxed_pri_vec[k1*(P_WIDTH+INDEX_WIDTH+1)+l1] = (masked_req[k1]) ?
          priority_vec[k1*(P_WIDTH+INDEX_WIDTH+1)+l1]: maxp1_priority[l1];
      end
    end
  end

  always @(int_priority)
  begin: C_DECR_PRIOR_PROC
    for (i2=0 ; i2<N ; i2=i2+1) begin

      for (j2=0 ; j2<INDEX_WIDTH ; j2=j2+1) begin
        temp_prior[j2] = int_priority[i2*INDEX_WIDTH+j2];
      end
      // Width of temp_prior refers to number of slaves/clients connected to arbiter. So priority will be assigned based on number of clients attached. Hence if width will become 1 then no need of priority because only one slave is attched. Hence variable length assignment in LHS and RHS won't cause any functionality issue.
      temp2_prior = temp_prior - 1'b1;
      for (k2=0 ; k2<INDEX_WIDTH ; k2=k2+1) begin
        decr_prior[i2*INDEX_WIDTH+k2] = temp2_prior[k2];
      end

    end
  end
// spyglass enable_block SelfDeterminedExpr-ML


  assign st_vec = {next_parked, next_locked};
  always @(current_state or st_vec)
  begin: S_ARB_STATE_MACHINE_PROC
    case (current_state)
    // DEFAULT 
    2'b00: begin
      case (st_vec)
      2'b00: next_state = 2'b10;
      2'b10: next_state = 2'b01;
      default: next_state = 2'b00;
      endcase
    end
    // PARKED
    2'b01: begin
      case (st_vec)
      2'b00: next_state = 2'b10;
      2'b01: next_state = 2'b11;
      default: next_state = 2'b01;
      endcase
    end
    // NOT PARKED & NOT LOCKED
    2'b10: begin
      case (st_vec)
      2'b01: next_state = 2'b11;
      2'b10: next_state = 2'b01;
      default: next_state = 2'b10;
      endcase
    end
    // LOCKED
    default: begin
      case (st_vec)
      2'b00: next_state = 2'b10;
      2'b10: next_state = 2'b01;
      default: next_state = 2'b11;
      endcase
    end
    endcase
  end


// spyglass disable_block SelfDeterminedExpr-ML
// SMD: Self determined expression found
// SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.

  /*
  *  jstokes, crm 9000401583, 15.9.2010
  *
  * Remove possibility of starvation conditions from the fair among equals
  * arbiter.
  *
  * Internal priority of clients will now not update if a higher external
  * priority client is granted.
  *
  */

  // Decode if the external priority of each client is less than
  // the external priority of the currently granted client. 
  always @(*) begin : BUS_CURRENT_EXT_PRI_LT_PROC
    integer client;
    integer pbit;

    bus_current_ext_pri_lt = {N{1'b0}};

    for(client=0;client<N;client=client+1) begin

      // Get external priority of this client.
      for(pbit=0;pbit<P_WIDTH;pbit=pbit+1) begin
        tmp_client_pri[pbit]
        = priority_vec[(client*(P_WIDTH+INDEX_WIDTH+1))+INDEX_WIDTH+pbit];
      end // for(pbit=0;...

      // Get external priority of current granted client.
      for(pbit=0;pbit<P_WIDTH;pbit=pbit+1) begin
        tmp_current_pri[pbit] = current_value[INDEX_WIDTH+pbit];
      end // for(pbit=0;...

      // Set this clients bit if its external priority is less than
      // the external priority of the currently granted client.
      // NOTE : We are testing if the priority is less than the current
      // priority but we use ">", since a lower priority value is a 
      // higher priority.
      if(tmp_client_pri>tmp_current_pri) begin
        bus_current_ext_pri_lt[client] = 1'b1;
      end

    end // for(client=0;...
  end // bus_current_ext_pri_lt_PROC

  always @(*)
  begin:C_STATE_TRANSITION_PROC
    for (i3=0 ; i3<N ; i3=i3+1) begin
      for (l3=0 ; l3<INDEX_WIDTH ; l3=l3+1) begin
        case (current_state)
        2'b00: begin
          if (masked_req[i3]) begin
            if (next_grant[i3]) begin
              next_prior[i3*INDEX_WIDTH+l3] = max_prior[l3];
            end
            else begin
              // If the external priority of this client is less than the
              // external priority of the currently granted client then
              // do not increment the priority of this client.
              // This avoids situations where the internal priority of
              // clients with an external priority lower than the currently
              // granted client, can wrap around if they have to wait
              // for > N (num client) grants before the higher priority
              // client drops his request. i.e. The internal priority
              // for each client is [(log base 2 N)-1:0] bits, so it can
              // only increment a finite number of times before it wraps.
              if(bus_current_ext_pri_lt[i3]) begin
                next_prior[i3*INDEX_WIDTH+l3] = int_priority[i3*INDEX_WIDTH+l3];
              end else begin
                next_prior[i3*INDEX_WIDTH+l3] = decr_prior[i3*INDEX_WIDTH+l3];
              end
            end
          end
          else begin
            next_prior[i3*INDEX_WIDTH+l3] = max_prior[l3];
          end
        end
        2'b01: begin
          if (next_locked) begin
            if (masked_req[i3]) begin
              if (next_grant[i3]) begin
                next_prior[i3*INDEX_WIDTH+l3] = int_priority[i3*INDEX_WIDTH+l3];
              end
              else begin
                // If the external priority of this client is less than the
                // external priority of the currently granted client then
                // do not increment the priority of this client.
                if(bus_current_ext_pri_lt[i3]) begin
                  next_prior[i3*INDEX_WIDTH+l3] = int_priority[i3*INDEX_WIDTH+l3];
                end else begin
                  next_prior[i3*INDEX_WIDTH+l3] = decr_prior[i3*INDEX_WIDTH+l3];
                end
              end
            end
            else begin
              next_prior[i3*INDEX_WIDTH+l3] = max_prior[l3];
            end
          end
          else begin
            if (masked_req[i3]) begin
              if (next_grant[i3]) begin
                next_prior[i3*INDEX_WIDTH+l3] = max_prior[l3];
              end
              else begin
                // If the external priority of this client is less than the
                // external priority of the currently granted client then
                // do not increment the priority of this client.
                if(bus_current_ext_pri_lt[i3]) begin
                  next_prior[i3*INDEX_WIDTH+l3] = int_priority[i3*INDEX_WIDTH+l3];
                end else begin
                  next_prior[i3*INDEX_WIDTH+l3] = decr_prior[i3*INDEX_WIDTH+l3];
                end
              end
            end
            else begin
              next_prior[i3*INDEX_WIDTH+l3] = max_prior[l3];
            end
          end
        end
        default: begin
          if (next_locked) begin
            if (masked_req[i3] == 1'b0) begin
              next_prior[i3*INDEX_WIDTH+l3] = max_prior[l3];
            end
            else begin
              next_prior[i3*INDEX_WIDTH+l3] = int_priority[i3*INDEX_WIDTH+l3];
            end
          end
          else begin
            if (masked_req[i3] == 1'b0) begin
              next_prior[i3*INDEX_WIDTH+l3] = max_prior[l3];
            end
            else begin
              if (next_grant[i3]) begin
                next_prior[i3*INDEX_WIDTH+l3] = max_prior[l3];
              end
              else begin
                // If the external priority of this client is less than the
                // external priority of the currently granted client then
                // do not increment the priority of this client.
                if(bus_current_ext_pri_lt[i3]) begin
                  next_prior[i3*INDEX_WIDTH+l3] = int_priority[i3*INDEX_WIDTH+l3];
                end else begin
                  next_prior[i3*INDEX_WIDTH+l3] = decr_prior[i3*INDEX_WIDTH+l3];
                end
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
   #(P_WIDTH+INDEX_WIDTH+1, N, INDEX_WIDTH) U_minmax(
  .a(muxed_pri_vec),
  .tc(1'b0),
  .min_max(1'b0),
  .value(current_value),
  .index(current_index) );

  //one hot encoding function 
  function automatic [N-1:0] func_decode;
    input [INDEX_WIDTH-1:0]    a;  // input
    reg   [N-1:0]    z;
    integer  i;
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

  // one hot encoding of priority index
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

  //MUX function
  function automatic [N-1:0] func_mux;
    input [N*4-1:0]  a;  // input bus
    input [2-1:0]    sel;  // select
    reg   [N-1:0]  z;
    integer  i, j; 
    integer k;
    begin
      z = {N {1'b0}};
      k = 0;
      for (i=0 ; i<4 ; i=i+1) begin
  if (i == sel) begin
    for (j=0 ; j<N ; j=j+1) begin
// spyglass disable_block SelfDeterminedExpr-ML
// SMD: Self determined expression found
// SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.        
    // all bits of z may not be used 
      z[j] = a[j + k];
// spyglass enable_block SelfDeterminedExpr-ML      

    end // for (j
  end // if
  k = k + N;
      end // for (i
      func_mux = z;
    end
  endfunction

  assign next_grant = func_mux( ({grant_int,p_index,grant_int,temp_gnt}), ({next_parked,next_locked}) );



 
  //Binary Encoding function 
  function automatic [INDEX_WIDTH-1:0] func_binenc;
    input [N-1:0]    a;  // input
    reg   [INDEX_WIDTH-1:0]    z;
    integer i;
    reg   [31:0]    j;
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
  always @(posedge clk or negedge rst_n) begin : arb_reg_PROC
    if (~rst_n) begin
      current_state       <= 2'b00;
      grant_index_int     <= {INDEX_WIDTH{1'b1}};
      parked_int          <= 1'b0;
      granted_int         <= 1'b0;
      locked_int          <= 1'b0;
      grant_int           <= {N{1'b0}};
    end else if (init_n == 1'b0) begin
      current_state       <= 2'b00;
      grant_index_int     <= {INDEX_WIDTH{1'b1}};
      parked_int          <= 1'b0;
      granted_int         <= 1'b0;
      locked_int          <= 1'b0;
      grant_int           <= {N{1'b0}};
    end else if (enable) begin
      current_state       <= next_state;
      grant_index_int     <= next_grant_index;
      parked_int          <= next_parked;
      granted_int         <= next_granted;
      locked_int          <= next_locked;
      grant_int           <= next_grant;
    end 
  end

  // jstokes, 30/3/2010, mix of priorities from this channel
  // and other address channel, used for implementing
  // locked sequences.
  // Take internal priority from the other address channel for locking
  // clients when instructed.
  generate
  if(HAS_LOCKING)
  begin
    always @(posedge clk or negedge rst_n) begin : INT_PRIORITY_PROC
      if (~rst_n)
        int_priority        <= {N*INDEX_WIDTH{1'b1}};
      else if (init_n == 1'b0) 
        int_priority        <= {N*INDEX_WIDTH{1'b1}};
      else if (enable) begin
        for (x1=0 ; x1<N ; x1=x1+1) begin
          // spyglass disable_block SelfDeterminedExpr-ML
          // SMD: Self determined expression found
          // SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
          if(use_other_pri[x1]) begin
            for (y1=0 ; y1<INDEX_WIDTH ; y1=y1+1) begin
              int_priority[x1*INDEX_WIDTH+y1]
                <= bus_pri_other[x1*INDEX_WIDTH+y1];
            end
          end else begin
            for (y1=0 ; y1<INDEX_WIDTH ; y1=y1+1) begin
              int_priority[x1*INDEX_WIDTH+y1]
                <= next_prior[x1*INDEX_WIDTH+y1];
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
        int_priority        <= {N*INDEX_WIDTH{1'b1}};
      else if (init_n == 1'b0) 
        int_priority        <= {N*INDEX_WIDTH{1'b1}};
      else if (enable) 
        int_priority <= next_prior;
    end    
  end 
  endgenerate


  
  // jstokes, 30/3/2010
  // Send internal priority to the other address channel.
  assign bus_pri = next_prior;

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
