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
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_dfltslv.v#9 $ 
**
** ---------------------------------------------------------------------
**
** File     : DW_axi_dfltslv.v
//
//
** Created  : Mon Jun 27 17:34:35 MEST 2005
** Modified : $Date: 2020/03/22 $
** Abstract : This block implements the DW_axi default slave.
**            The default slave is shared between all address layers.
**
** ---------------------------------------------------------------------
*/


module DW_axi_dfltslv(
    // Inputs - System
    aclk_i,                  
    aresetn_i,               
    
    // Inputs - Read address channel signals
    arvalid_i,               
    arid_i,
    arlen_i,
    araddr_i,
    arsize_i,
    arlock_i,
    arburst_i,
    arcache_i,
    arprot_i,

    // Outputs - Read address channel signals
    arready_o,

    // Inputs - Read data channel signals
    rready_i,
      
    // Outputs - Read data channel signals
    rvalid_o,
    rid_o,
    rresp_o,
    rlast_o,
    rdata_o,

    // Inputs - Write address channel signals
    awvalid_i,
    awid_i,
    awlen_i,
    awaddr_i,
    awsize_i,
    awlock_i,
    awburst_i,
    awcache_i,
    awprot_i,


    // Outputs - Write address channel signals
    awready_o,
      
    // Inputs - Write data channel signals
    wvalid_i,
    wlast_i,
    wid_i,
    wdata_i,
    wstrb_i,
    
    // outputs - Write data channel signals
    wready_o,

    // Inputs - write response channel signals
    bready_i,

    // Outputs - write response channel signals
    bvalid_o,
    bid_o,
    bresp_o
   
  );

  //-------------------------------------------------------------------
  // Parameters
  //-------------------------------------------------------------------
  parameter  IDW  = 6;          // ID Width = AXI_IDW + 
                                   // (log base 2 AXI_NUM_MASTERS)
  
  //-------------------------------------------------------------------
  // PORT DECLARATIONS
  //-------------------------------------------------------------------


  // Inputs - System
  input aclk_i;      // System clock
  input aresetn_i;    // Active low asynchronus reset

  // Inputs - Read address channel signals
  input arvalid_i;                       // Read address valid

  input [IDW-1:0]  arid_i;          // Read address ID
  input [`AXI_BLW-1:0]  arlen_i;         // Burst Length
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: These ports are not used 
  input [`AXI_AW-1:0]  araddr_i;
  input [`AXI_BSW-1:0]  arsize_i;
  input [`AXI_LTW-1:0]  arlock_i;
  input [`AXI_BTW-1:0]  arburst_i;
  input [`AXI_CTW-1:0]  arcache_i;
  input [`AXI_PTW-1:0]  arprot_i;
  //spyglass enable_block W240

  // Outputs - Read address channel signals
  output arready_o;              // Read address ready

  // Inputs - Read data channel signals
  input rready_i;                // Read ready
      
  // Outputs - Read data channel signals
  output rvalid_o;               // Read valid
  output rlast_o;                // Read last
  
  output [IDW-1:0]        rid_o;       // Read ID tag
  output [`AXI_RRW-1:0]   rresp_o;     // Read response
  output [`AXI_DW-1:0]    rdata_o;     // Read data

  // Inputs - Write address channel signals
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: These ports are not used 
  input awvalid_i;                        // Write address valid
  
  input [IDW-1:0]      awid_i;            // Write address ID
  input [`AXI_BLW-1:0] awlen_i;           // Burst length
  input [`AXI_AW-1:0]  awaddr_i;
  input [`AXI_BSW-1:0] awsize_i;
  input [`AXI_LTW-1:0] awlock_i;
  input [`AXI_BTW-1:0] awburst_i;
  input [`AXI_CTW-1:0] awcache_i;
  input [`AXI_PTW-1:0] awprot_i;
  //spyglass enable_block W240

  // Outputs - Write address channel signals
  output awready_o;               // Write address ready    
     
  // Inputs - Write data channel signals
  input wvalid_i;                 // Write valid
  input wlast_i;                  // Write last
  
  input [IDW-1:0]        wid_i;           // Write ID tag  
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: These ports are not used 
  input [`AXI_DW-1:0]    wdata_i;         // Write data 
  input [`AXI_SW-1:0]    wstrb_i;         // Write strobes
  //spyglass enable_block W240
    
  // outputs - Write data channel signals
  output wready_o;                // Write ready

  // Inputs - write response channel signals
  input bready_i;                 // Response ready

  // Outputs - write response channel signals
  output bvalid_o;                // Write response valid
  
  output [IDW-1:0]        bid_o;       // response ID
  output [`AXI_BRW-1:0]   bresp_o;     // Write response

  //-------------------------------------------------------------------
  // REGISTER VARIABLES.
  //-------------------------------------------------------------------
  reg rvalid_r;                // "set clear" register - read channel
  
  reg wlast_r;                 // Write last register

  
  reg [IDW-1:0]      rid_r;    // Read ID tag
  reg [`AXI_BLW-1:0] arlen_r;  // Burst Length
  reg [IDW-1:0]      wid_r;    // write ID tag

  //-------------------------------------------------------------------
  // WIRE VARIABLES.
  //-------------------------------------------------------------------
  
  wire clr_rvalid;             // Clear input to register rvalid_r
  wire clr_wlast;              // Clear input to register wlast_r
  
  //*******************************************************************
  // RTL 
  //*******************************************************************


  // "set clear" register: rvalid_r
  // The register is cleared by the signal clr_rvalid, which is 
  // asserted by the read data channel when it has completed the 
  // transaction.
  always @ (posedge aclk_i or negedge aresetn_i)
  begin : rvalid_r_PROC
    if (!aresetn_i) 
       rvalid_r <= 1'b0;
    else 
      if(!rvalid_r) begin
        rvalid_r <= arvalid_i;
      end else begin
        rvalid_r <= clr_rvalid ? 1'b0 : rvalid_r;  
      end
  end

  // clr_rvalid signal is asserted when arlen_r has decremented to zero
  // (rlast) and when ready_i is asserted with rlast_o == 1'b1
  assign clr_rvalid = rready_i & rlast_o;
 
  // Read ID tag register: rid_r
  // This is the ID tag of the read data group of signals
  // Must match the ARID value of the read transaction
  always @ (posedge aclk_i or negedge aresetn_i)
  begin : rid_r_PROC
    if (!aresetn_i)
      rid_r <= {IDW{1'b0}};
    else
      rid_r <= (!rvalid_r)? arid_i : rid_r;
  end
    
  // Read valid output signal
  assign rvalid_o = rvalid_r;
  
  // Hold off any masters attempting to access the slave until the 
  // current transaction has completed
  assign arready_o = ~rvalid_r;

  // Read Id tag output signal
  assign rid_o    = rid_r;
  
  // Read address channel 
  // This register will only take new values when the currently 
  // registered transaction has completed. arlen_r holds the number of
  // read transactions generated. This value is decremented every time
  // one of the read transactions is accepted.
  always @ (posedge aclk_i or negedge aresetn_i)
  begin : arlen_r_PROC 
    if (!aresetn_i)
      arlen_r <= {`AXI_BLW{1'b0}};
    else
      arlen_r  <= (rvalid_r & (!rready_i)) ? arlen_r :
                  ((rvalid_r & rready_i) ? (arlen_r -1) : arlen_i);
  end

  // Asserted when arlen_r has decremented to zero
  assign rlast_o   = rvalid_r & (arlen_r == 0);

  // Don't care whats on the read data signal since we are driving out
  // decode errors.
  assign rdata_o     = {`AXI_DW{1'b0}};
  assign rresp_o     = `AXI_RESP_DECERR;    


  //-------------------------------------------------------------------
  // WRITE SIDE
  // Because it is possible for the default slave to receive 
  // interleaved write data it is designed to effectively have an
  // infinite write interleaving depth.
  // The write address channel is ignored and we sample wid_i 
  // whenever wlast_i is asserted, and use this condition to drive
  // a burst response for that ID. While we are waiting for the burst
  // response to complete we will hold wready_o low to hold any
  // new write data until we have finished with the previously 
  // sampled write data ID.
  //-------------------------------------------------------------------

  // Can always accept new write data transaction.
  assign awready_o = 1'b1;

  // Write ID tag register: wid_r
  // This signal is the ID tag of the write data transfer. 
  // The ID of a write data beat is captured in this register when
  // wlast_r is asserted and used to drive out a burst response 
  // for that write transaction.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : wid_r_PROC 
    if (!aresetn_i) 
      wid_r  <= {IDW{1'b0}};
    else 
      wid_r  <= (!wlast_r) ? wid_i : wid_r;
  end

  // Write last register: wlast_r
  // This signal indicates the last transfer in a write burst has
  // occured. Used to generate a burst response for the write 
  // transaction. Cleared when burst response has completed.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : wlast_r_PROC
    if (!aresetn_i) 
      wlast_r <= 1'b0;
    else
      wlast_r <= (clr_wlast) ? 1'b0 : 
                 ((wvalid_i & wlast_i) ? 1'b1 : wlast_r);
  end

  // Clear wlast_r when burst response has completed.
  assign clr_wlast = bvalid_o && bready_i;
  
  // Hold new write data if we are waiting for a burst response
  // to complete, only then can we free the wid_r register.
  assign wready_o  = !wlast_r;

  // Burst response ID.
  assign bid_o = wid_r;
  
  // This signal indicates that a write response is available
  assign bvalid_o  = wlast_r;
  
  // Indicates the status of the write transaction, always
  // a decode error.
  assign bresp_o = `AXI_RESP_DECERR;  
        

endmodule 

