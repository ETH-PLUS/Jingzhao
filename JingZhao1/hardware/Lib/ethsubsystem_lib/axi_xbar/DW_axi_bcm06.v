
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
// Filename    : DW_axi_bcm06.v
// Revision    : $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_bcm06.v#11 $
// Author      : Rick Kelly          04/14/04
// Description : DW_axi_bcm06.v Verilog module for DW_axi
//
// DesignWare IP ID: c7a15259
//
////////////////////////////////////////////////////////////////////////////////

module DW_axi_bcm06 (
    clk,
    rst_n,
    init_n,
    push_req_n,
    pop_req_n,
    diag_n,
    ae_level,
    af_thresh,
    we_n,
    empty,
    almost_empty,
    half_full,
    almost_full,
    full,
    error,
    wr_addr,
    rd_addr,
    wrd_count,
    nxt_empty_n,
    nxt_full,
    nxt_error
    );

parameter DEPTH  = 4;           // RANGE 2 to 16777216
parameter ERR_MODE  =  0 ;      // RANGE 0 to 2
parameter ADDR_WIDTH = 2;       // RANGE 1 to 24

input                   clk;            // Input Clock (pos edge)
input                   rst_n;          // Async reset (active low)
input                   init_n;         // Sync reset (active low) (FIFO clear/flush)
input                   push_req_n;     // Push request (active low)
input                   pop_req_n;      // Pop Request (active low)
input                   diag_n;         // Diagnostic sync. reset rd_addr (active low)
input  [ADDR_WIDTH-1:0] ae_level;       // Almost empty level input bus
input  [ADDR_WIDTH-1:0] af_thresh;      // Almost full threshold input bus
output                  we_n;           // RAM Write Enable output (active low)
output                  empty;          // FIFO Empty flag output (active high)
output                  almost_empty;   // FIFO Almost Empty flag output (active high)
output                  half_full;      // FIFO Half Full flag output (active high)
output                  almost_full;    // FIFO almost Full flag output (active high)
output                  full;           // FIFO full flag output (active high)
output                  error;          // FIFO Error flag output (active high)
output [ADDR_WIDTH-1:0] wr_addr;        // RAM Write Address output bus
output [ADDR_WIDTH-1:0] rd_addr;        // RAM Read Address output bus
output [ADDR_WIDTH-1:0] wrd_count;      // Words in FIFO (not always accurate at full)
output                  nxt_empty_n;    // Look ahead empty flag (active low)
output                  nxt_full;       // Look ahead full flag
output                  nxt_error;      // Look ahead empty flag


wire                    next_empty_n;
reg                     empty_n;
wire                    next_almost_empty_n;
reg                     almost_empty_n;
wire                    next_half_full;
reg                     half_full_int;
wire                    next_almost_full;
reg                     almost_full_int;
wire                    next_full;
reg                     full_int;
wire                    next_error;
reg                     error_int;
wire [ADDR_WIDTH-1:0]   next_wr_addr;
reg  [ADDR_WIDTH-1:0]   wr_addr_int;
wire                    next_wr_addr_at_max;
reg                     wr_addr_at_max;
wire [ADDR_WIDTH-1:0]   next_rd_addr;
reg  [ADDR_WIDTH-1:0]   rd_addr_int;
wire                    next_rd_addr_at_max;
reg                     rd_addr_at_max;
wire [ADDR_WIDTH-1:0]   next_word_count;
reg  [ADDR_WIDTH-1:0]   word_count;
reg  [ADDR_WIDTH  :0]   advanced_word_count;

wire                    advance_wr_addr;
wire [ADDR_WIDTH+1:0]   advanced_wr_addr;
wire                    advance_rd_addr;
wire [ADDR_WIDTH+1:0]   advanced_rd_addr;
wire                    inc_word_count;
wire                    dec_word_count;

localparam [ADDR_WIDTH-1 : 0] LASTADDRESS   =  DEPTH - 1;
localparam [ADDR_WIDTH-1 : 0] HF_THRESH_VAL = (DEPTH + 1)/2;
localparam [ADDR_WIDTH   : 0] ADDRP1_SIZED_ONE = 1;
localparam [ADDR_WIDTH-1 : 0] ADDR_SIZED_ONE   = 1;

  assign we_n = push_req_n | (full_int & pop_req_n);


  assign advance_wr_addr = ~(push_req_n | (full_int & pop_req_n));

  assign advance_rd_addr = ~pop_req_n  & empty_n;


  assign advanced_wr_addr = {wr_addr_int,advance_wr_addr} + ADDRP1_SIZED_ONE;
  assign next_wr_addr = (wr_addr_at_max  &advance_wr_addr)?
                                {ADDR_WIDTH{1'b0}} :
                                advanced_wr_addr[ADDR_WIDTH:1];

  assign advanced_rd_addr = {rd_addr_int,advance_rd_addr} + ADDRP1_SIZED_ONE;

  assign next_rd_addr_at_max = ((next_rd_addr & LASTADDRESS) == LASTADDRESS)? 1'b1 : 1'b0;

  assign next_wr_addr_at_max = ((next_wr_addr & LASTADDRESS) == LASTADDRESS)? 1'b1 : 1'b0;

  assign inc_word_count = ~push_req_n & pop_req_n & (~full_int) |
                          (~push_req_n) & (~empty_n);

  assign dec_word_count = push_req_n & (~pop_req_n) & empty_n;

  always @ (word_count or dec_word_count) begin : infer_incdec_PROC
    if (dec_word_count)
      advanced_word_count = word_count - ADDR_SIZED_ONE;
    else
      advanced_word_count = word_count + ADDR_SIZED_ONE;
  end

  assign next_word_count = ((inc_word_count | dec_word_count) == 1'b0)?
                                word_count : advanced_word_count[ADDR_WIDTH-1:0];

  assign next_full =    ((word_count == LASTADDRESS)? ~push_req_n & pop_req_n : 1'b0) |
                        (full_int & push_req_n & pop_req_n) |
                        (full_int & (~push_req_n));

  assign next_empty_n = (next_word_count == {ADDR_WIDTH{1'b0}})? next_full : 1'b1;


  assign next_half_full = (next_word_count >= HF_THRESH_VAL)? 1'b1 : next_full;


generate
  if ((1<<ADDR_WIDTH) == DEPTH) begin : GEN_PWR2
    assign next_almost_empty_n = ~(((next_word_count <= ae_level)? 1'b1 : 1'b0) &
                                 (~next_full));
  end else begin : GEN_NOT_PWR2
    assign next_almost_empty_n = ~((next_word_count <= ae_level)? 1'b1 : 1'b0);
  end
endgenerate


  assign next_almost_full = (next_word_count >= af_thresh)? 1'b1 :
                                next_full;


generate
  if (ERR_MODE == 0) begin : GEN_EM_EQ0
    assign next_rd_addr = ((rd_addr_at_max & advance_rd_addr) || (diag_n==1'b0))?
                            {ADDR_WIDTH{1'b0}} : advanced_rd_addr[ADDR_WIDTH:1];
    assign next_error =  (~pop_req_n & (~empty_n)) | (~push_req_n & pop_req_n & full_int) |
                         (( |(wr_addr_int ^ rd_addr_int)) ^ (empty_n & (~full_int))) | error_int;
  end
  
  if (ERR_MODE == 1) begin : GEN_EM_EQ1
    assign next_rd_addr =  (rd_addr_at_max & advance_rd_addr)?
                            {ADDR_WIDTH{1'b0}} : advanced_rd_addr[ADDR_WIDTH:1];
    assign next_error = (~pop_req_n & (~empty_n)) | (~push_req_n & pop_req_n & full_int) | error_int;
  end
  
  if (ERR_MODE == 2) begin : GEN_EM_EQ2
    assign next_rd_addr =  (rd_addr_at_max & advance_rd_addr)?
                            {ADDR_WIDTH{1'b0}} : advanced_rd_addr[ADDR_WIDTH:1];
    assign next_error = (~pop_req_n & (~empty_n)) | (~push_req_n & pop_req_n & full_int);
  end
endgenerate



// spyglass disable_block CheckDelayTimescale-ML
// SMD: Delay is used without defining timescale compiler directive
// SJ: The design incorporates delays for behavioral simulation. Timescale compiler directive is assumed to be defined in the test bench.
  always @ (posedge clk or negedge rst_n) begin : registers_PROC
    if (rst_n == 1'b0) begin
      empty_n          <=  1'b0;
      almost_empty_n   <=  1'b0;
      half_full_int    <=  1'b0;
      almost_full_int  <=  1'b0;
      full_int         <=  1'b0;
      error_int        <=  1'b0;
      wr_addr_int      <=  {ADDR_WIDTH{1'b0}};
      rd_addr_at_max   <=  1'b0;
      wr_addr_at_max   <=  1'b0;
      rd_addr_int      <=  {ADDR_WIDTH{1'b0}};
      word_count       <=  {ADDR_WIDTH{1'b0}};
    end else if (init_n == 1'b0) begin
      empty_n          <=  1'b0;
      almost_empty_n   <=  1'b0;
      half_full_int    <=  1'b0;
      almost_full_int  <=  1'b0;
      full_int         <=  1'b0;
      error_int        <=  1'b0;
      rd_addr_at_max   <=  1'b0;
      wr_addr_at_max   <=  1'b0;
      wr_addr_int      <=  {ADDR_WIDTH{1'b0}};
      rd_addr_int      <=  {ADDR_WIDTH{1'b0}};
      word_count       <=  {ADDR_WIDTH{1'b0}};
    end else begin
// spyglass disable_block STARC-2.3.4.3
// SMD: A flip-flop should have an asynchronous set or an asynchronous reset
// SJ: This module can be specifically configured/implemented with only a synchronous reset or no resets at all.
      empty_n          <=  next_empty_n;
      almost_empty_n   <=  next_almost_empty_n;
      half_full_int    <=  next_half_full;
      almost_full_int  <=  next_almost_full;
      full_int         <=  next_full;
      error_int        <=  next_error;
      rd_addr_at_max   <=  next_rd_addr_at_max;
      wr_addr_at_max   <=  next_wr_addr_at_max;
      wr_addr_int      <=  next_wr_addr;
      rd_addr_int      <=  next_rd_addr;
      word_count       <=  next_word_count;
// spyglass enable_block STARC-2.3.4.3
    end
  end
// spyglass enable_block CheckDelayTimescale-ML

`ifdef DWC_BCM_SNPS_ASSERT_ON
`ifndef SYNTHESIS

  DW_axi_sva12_b P_RESET_PUSH(
    .clk(clk),
    .rst_n(rst_n),
    .init_n(init_n),
    .req_n(push_req_n)
  );

  DW_axi_sva12_b P_RESET_POP(
    .clk(clk),
    .rst_n(rst_n),
    .init_n(init_n),
    .req_n(pop_req_n)
  );
`endif // SYNTHESIS
`endif // DWC_BCM_SNPS_ASSERT_ON

  assign empty = ~empty_n;
  assign almost_empty = ~almost_empty_n;
  assign half_full = half_full_int;
  assign almost_full = almost_full_int;
  assign full = full_int;
  assign error = error_int;
  assign wr_addr = wr_addr_int;
  assign rd_addr = rd_addr_int;
  assign wrd_count = word_count;
  assign nxt_empty_n = next_empty_n | (~init_n);
  assign nxt_full    = next_full    &  init_n;
  assign nxt_error   = next_error   &  init_n;

endmodule
