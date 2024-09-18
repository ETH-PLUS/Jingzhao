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
// File Version     :        $Revision: #8 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_fifo_s1_sf.v#8 $ 
//
// Filename    : DW_axi_fifo_s1_sf.v
// Author      : ALS         04/28/04
// Description : DW_axi_fifo_s1_sf.v Verilog module for DW_axi
//
//
//
// DesignWare IP ID: 5bf0f11f
//
////////////////////////////////////////////////////////////////////////////////


//VCS coverage exclude_file

module DW_axi_fifo_s1_sf 
    (clk, rst_n, init_n, push_req_n, pop_req_n, diag_n, data_in, empty, 
     nxt_empty, almost_empty, half_full, almost_full, full, error, data_out
    );
  parameter WIDTH      = 8;           // RANGE 1 TO 256
  parameter DEPTH      = 4;           // RANGE 2 TO 256
  parameter AE_LEVEL   = 1;           // RANGE 0 TO 255
  parameter AF_LEVEL   = 1;           // RANGE 0 TO 255
  parameter ERR_MODE   = 0;           // RANGE 0 TO 2
  parameter RST_MODE   = 0;           // RANGE 0 TO 1
  parameter ADDR_WIDTH = 2;           // RANGE 1 TO 8
 
  input                clk;           // clock input
  input                rst_n;         // active low async. reset
  input                init_n;        // active low sync. reset (FIFO flush)
  input                push_req_n;    // active low push request
  input                pop_req_n;     // active low pop request
  input                diag_n;        // active low diagnostic input
  input  [WIDTH-1 : 0] data_in;       // FIFO input data bus
  output               empty;         // empty status flag
  output               nxt_empty;     // Next empty status flag
  output               almost_empty;  // almost empty status flag
  output               half_full;     // half full status flag
  output               almost_full;   // almost full status flag
  output               full;          // full status flag
  output               error;         // error status flag
  output [WIDTH-1 : 0] data_out;      // FIFO outptu data bus
 
  wire                    ram_async_rst_n;
  wire [ADDR_WIDTH-1 : 0] ram_rd_addr, ram_wr_addr;
  wire           [31 : 0] ae_level_i;
  wire           [31 : 0] af_thresh_i; 
  wire                    ram_we_n;
  wire                    nxt_empty_n;
 
  // Wires for unconnected sub module outputs.
  wire [ADDR_WIDTH-1:0] wrd_count_unconn;
  wire nxt_full_unconn;
  wire nxt_error_unconn;

    

  assign ae_level_i  = AE_LEVEL;
  assign af_thresh_i = DEPTH - AF_LEVEL; 

  assign ram_async_rst_n = (RST_MODE == 0) ? rst_n : 1'b1;

  DW_axi_bcm06
   #(DEPTH, ERR_MODE, ADDR_WIDTH) U_FIFO_CTL(
      .clk(clk),
      .rst_n(rst_n),
      .init_n(init_n),
      .push_req_n(push_req_n),
      .pop_req_n(pop_req_n),
      .ae_level(ae_level_i[ADDR_WIDTH-1:0]),
      .af_thresh(af_thresh_i[ADDR_WIDTH-1:0]),
      .diag_n(diag_n),
      .empty(empty),
      .almost_empty(almost_empty),
      .half_full(half_full),
      .almost_full(almost_full),
      .full(full),
      .error(error),
      .we_n(ram_we_n),
      .wr_addr(ram_wr_addr),
      .rd_addr(ram_rd_addr),
      .wrd_count(wrd_count_unconn),
      .nxt_empty_n(nxt_empty_n),
      .nxt_full(nxt_full_unconn),
      .nxt_error(nxt_error_unconn)
      );
    
  DW_axi_bcm57
   #(WIDTH, DEPTH, 0, ADDR_WIDTH) U_FIFO_MEM( 
      .clk(clk),
      .rst_n(ram_async_rst_n),
      .wr_n(ram_we_n),
      .rd_addr(ram_rd_addr),
      .wr_addr(ram_wr_addr),
      .data_in(data_in),
      .data_out(data_out)
      );


  assign nxt_empty = !nxt_empty_n;      

  
endmodule
