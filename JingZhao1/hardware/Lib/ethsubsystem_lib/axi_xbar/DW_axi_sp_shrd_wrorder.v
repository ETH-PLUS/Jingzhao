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
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_sp_shrd_wrorder.v#9 $ 
**
** ---------------------------------------------------------------------
**
** File     : DW_axi_sp_shrd_wrorder.v
//
//
** Abstract : This block implements write ordering for the shared write
**            data channel.
**
** ---------------------------------------------------------------------
*/

module DW_axi_sp_shrd_wrorder (
  // Inputs - System
  aclk_i,
  aresetn_i,

  // Inputs - Master Ports
  bus_valid_i,
  bus_valid_shrd_i,
  
  // Inputs - Slave Ports (Write address channels)
  issued_slvnum_oh_i,
  issued_mstnum_i,
  bus_ready_shrd_m_i,
  tx_acc_s_i,

  // Inputs - Dedicated W Channels.
  shrd_w_nxt_fb_pend_bus_i,
  
  // Outputs - Slave Port Arbiter
  bus_mst_req_o,

  // Inputs - Slave Port
  bus_valid_shrd_out_i,
  cpl_tx_bus_i
);

//----------------------------------------------------------------------
// MODULE PARAMETERS.
//----------------------------------------------------------------------

  parameter NM = 0; // Number of visible master ports.
  parameter NS = 0; // Number of attached slaves.

  parameter L2_NM = 0; // Log base 2 of NM.

  parameter PL_ARB = 0; // 1 if arbiter outputs are pipelined.

  parameter SHARED_PL = 0; // Add shared layer pipelining.

  // Do the attached shared slaves have dedicated channel also.
  parameter HAS_DDCTD_W_S0 = 1;
  parameter HAS_DDCTD_W_S1 = 1;
  parameter HAS_DDCTD_W_S2 = 1;
  parameter HAS_DDCTD_W_S3 = 1;
  parameter HAS_DDCTD_W_S4 = 1;
  parameter HAS_DDCTD_W_S5 = 1;
  parameter HAS_DDCTD_W_S6 = 1;
  parameter HAS_DDCTD_W_S7 = 1;
  parameter HAS_DDCTD_W_S8 = 1;
  parameter HAS_DDCTD_W_S9 = 1;
  parameter HAS_DDCTD_W_S10 = 1;
  parameter HAS_DDCTD_W_S11 = 1;
  parameter HAS_DDCTD_W_S12 = 1;
  parameter HAS_DDCTD_W_S13 = 1;
  parameter HAS_DDCTD_W_S14 = 1;
  parameter HAS_DDCTD_W_S15 = 1;
  parameter HAS_DDCTD_W_S16 = 1;

//----------------------------------------------------------------------
// PORT DECLARATIONS
//----------------------------------------------------------------------
  
  // Inputs - System
  input aclk_i; 
  input aresetn_i; 

  // Inputs - Master Ports
  input [NM-1:0] bus_valid_i;
  input [NM*NS-1:0] bus_valid_shrd_i;
  
  // Inputs - Slave Ports (Write address channels)
  // Bit for each slave asserted when a t/x has been issued to that 
  // slave.
  input [NS-1:0] issued_slvnum_oh_i;

  // Master who issued the address t/x to a slave on the shared layer.
  input [L2_NM-1:0] issued_mstnum_i;
  
  // Ready signals from all attached slaves.
  input [NM-1:0] bus_ready_shrd_m_i;

  // Single bit, asserted when the slave has accepted the currently
  // asserted valid output.
  input tx_acc_s_i;
  
  // Inputs - Dedicated W Channels.
  // Used by the shared write order block (when this is implementing a
  // shared W channel), to decode when the shared W channel can send
  // a first W beat to a dedicated W channel. To avoid deadlock, this 
  // is only done when the shared channel is next to send a first W 
  // beat to the slave (as dictated by that slaves dedicated W channel).
  input [NS-1:0] shrd_w_nxt_fb_pend_bus_i;
  
  // Inputs - Dedicated W Channels.
  
  // Outputs - Slave Port Arbiter
  // Requests for the shared write data channel arbiter.
  output [NM-1:0] bus_mst_req_o; 

  // Inputs - Slave Port
  // Per slave valid out bits from the arbitration winning master.
  input [NS-1:0] bus_valid_shrd_out_i;

  // Bit for each slave, asserted when the wlast is accepted by the slv.
  input [NS-1:0] cpl_tx_bus_i;

  // Wires are defined for maximum config, in lower configs some of the bits may remain unused
  //--------------------------------------------------------------------
  // REGISTER VARIABLES.
  //--------------------------------------------------------------------
  // Bit for each master, asserted when the master is allowed to forward
  // a request to the arbiter.
  // In lower configs some of the bits may remain unused
  reg [NM-1:0] mst_req_allow_bus;

  reg [NS-1:0] cpl_tx_bus_r; // Pipelined cpl_tx_bus_i;

  // Max sized slave completion signal bus, ifdefs are used to
  // translate the per local slave cpl_tx_bus_i to the per system
  // slave cpl_tx_bus_max.
  reg [`AXI_MAX_NUM_MST_SLVS-1:0] cpl_tx_bus_max;
  wire [`AXI_MAX_NUM_MST_SLVS-1:0] cpl_tx_bus_max_n;

  //--------------------------------------------------------------------
  // WIRE VARIABLES.
  //--------------------------------------------------------------------
   
 
  // Bus of first pending masters for each slave.
  // Note lack of -1 to accomodate dummy bit in assignment.
  wire [L2_NM*NS:0] firstpnd_mst_bus;

  // spyglass disable_block W497
  // SMD: Not all bits of the bus are set
  // SJ : The bits which are not set are never used in the design.
  // Bus of pending masters fifo empty and nxt empty (pre ff) signals.
  wire [`AXI_MAX_NUM_MST_SLVS-1:0] fifo_empty_bus_max;
  wire [`AXI_MAX_NUM_MST_SLVS-1:0] fifo_nxt_empty_bus_max;
  // spyglass enable_block W497
  // Note lack of -1 to accomodate dummy bit in assignment.
  wire [NS:0] fifo_empty_bus;
  wire [NS:0] fifo_nxt_empty_bus;

  // Individual signals for the next pending master output of each
  // next pending master fifo.
  wire [L2_NM-1:0] firstpnd_mst_s0; 
  wire [L2_NM-1:0] firstpnd_mst_s1; 
  wire [L2_NM-1:0] firstpnd_mst_s2; 
  wire [L2_NM-1:0] firstpnd_mst_s3; 
  wire [L2_NM-1:0] firstpnd_mst_s4;
  wire [L2_NM-1:0] firstpnd_mst_s5;
  wire [L2_NM-1:0] firstpnd_mst_s6;
  wire [L2_NM-1:0] firstpnd_mst_s7;
  wire [L2_NM-1:0] firstpnd_mst_s8;
  wire [L2_NM-1:0] firstpnd_mst_s9;
  wire [L2_NM-1:0] firstpnd_mst_s10;
  wire [L2_NM-1:0] firstpnd_mst_s11;
  wire [L2_NM-1:0] firstpnd_mst_s12;
  wire [L2_NM-1:0] firstpnd_mst_s13;
  wire [L2_NM-1:0] firstpnd_mst_s14;
  wire [L2_NM-1:0] firstpnd_mst_s15;
  wire [L2_NM-1:0] firstpnd_mst_s16;

  // Bus of issued tx signals, 1 for each slave decoded from
  // issued_slvnum_oh_i. Always sized for maximum number
  // of slaves. We use ifdefs to create a bus where each bit
  // position corresponds to the system number of the attached slave.
  // This is because the first t/x pending FIFOs are instantiated
  // 1 per system slave.
  reg [`AXI_MAX_NUM_MST_SLVS-1:0] issued_slvnum_max; 
  wire [`AXI_MAX_NUM_MST_SLVS-1:0] issued_slvnum_max_n;
  // These signals are unused if shared write data channel is not present
  // Due to pipelining options this may remain unused
  // If the channel arbiter is pipelined (PL_ARB == 1), completion must be
  // detected early, which results in request being removed from the
  // arbiter before accepted by the slave. To work around this, we hold
  // asserted requests until they are accepted with ready.
  wire [NM-1:0] bus_mst_req; 
  reg  [NM-1:0] bus_mst_req_hold_r;
   
  reg  [NM-1:0] bus_mst_req_plarb_mux; 

  // Used to store HAS_DDCTD_W_S* parameters.
  wire [`AXI_MAX_NUM_MST_SLVS-1:0] has_ddctd_w_s_max;
  wire [NS-1:0]                    has_ddctd_w_s;

  // Bit for each slave asserted when the first valid for the current 
  // write t/x to the slave has been issued.
  reg [NS-1:0] tx_started_s_r;


  // Mask for shrd_w_nxt_fb_pend_bus_i, to prevent it from forwarding
  // a valid to a dedicated channel, when the previously started t/x has
  // not yet been accepted at the dedicated W channel.
  reg [NS-1:0] shrd_w_nxt_fb_pend_bus_mask_r;


  // Dummy variables, used to make assignments easier.
  // Not synthesisied.
  reg  dummy_reg1;
  reg  dummy_reg2;
  integer slv, mst;

  // Create wire bus to store HAS_DDCTD_W_S* parameters.
  assign has_ddctd_w_s_max = {
      (HAS_DDCTD_W_S16 == 1) 
    , (HAS_DDCTD_W_S15 == 1) 
    , (HAS_DDCTD_W_S14 == 1) 
    , (HAS_DDCTD_W_S13 == 1) 
    , (HAS_DDCTD_W_S12 == 1) 
    , (HAS_DDCTD_W_S11 == 1) 
    , (HAS_DDCTD_W_S10 == 1) 
    , (HAS_DDCTD_W_S9 == 1) 
    , (HAS_DDCTD_W_S8 == 1) 
    , (HAS_DDCTD_W_S7 == 1) 
    , (HAS_DDCTD_W_S6 == 1) 
    , (HAS_DDCTD_W_S5 == 1) 
    , (HAS_DDCTD_W_S4 == 1) 
    , (HAS_DDCTD_W_S3 == 1) 
    , (HAS_DDCTD_W_S2 == 1) 
    , (HAS_DDCTD_W_S1 == 1) 
    , (HAS_DDCTD_W_S0 == 1) 
    };

  assign has_ddctd_w_s = has_ddctd_w_s_max[NS-1:0];

  /*--------------------------------------------------------------------
   * FUNCTIONAL OPERATION
   *
   * The shared write data channel block enforces a write interleaving 
   * depth of 1 to each slave on the shared write data channel.
   * A fifo for each slave is used to maintain a queue of which master 
   * is next to access each slave. 
   * A masters request signal to the arbiter is then only forwarded if
   * it is the next pending master for at least 1 slave.
   */

  
  /*--------------------------------------------------------------------
   * Generate First T/X Pending FIFO Push Signals
   * Push whenever a t/x is issued to a slave.
   *
   * The issued_slvnum_oh_i bus has a bit for each visible slave only,
   * here we expand it out into a bus for each system slave. We do this
   * because there is a FIFO for each system slave, because it is 
   * easier to use the per system slave architecture parameters to 
   * control whether or not to instantiate each FIFO.
   */
  always @(*) begin : issued_slvnum_max_PROC
    issued_slvnum_max = {`AXI_MAX_NUM_MST_SLVS{1'b0}};

    {
      dummy_reg2} = {issued_slvnum_oh_i, 1'b0};
  end // issued_slvnum_max_PROC
  // Invert for use as active low fifo push inputs.
  assign issued_slvnum_max_n = ~issued_slvnum_max;

  /*--------------------------------------------------------------------
   * Decode FIFO pop signals
   * - Write beats completion signal for each connected slave.
   */
  always @(*) begin : cpl_tx_bus_max_PROC
    cpl_tx_bus_max = {`AXI_MAX_NUM_MST_SLVS{1'b0}};

    {
      dummy_reg1} = {(SHARED_PL ? cpl_tx_bus_r : cpl_tx_bus_i), 1'b0};
  end // cpl_tx_bus_max_PROC
  // Invert to use for active low fifo pop inputs.
  assign cpl_tx_bus_max_n = ~cpl_tx_bus_max;

  // If SHARED_PL is set to 1, the path from the completion
  // signals to the ordering fifos is pipelined.
  always @(posedge aclk_i or negedge aresetn_i) 
  begin : cpl_tx_bus_r_PROC
    if(~aresetn_i) begin
      cpl_tx_bus_r <= {NS{1'b0}};
    end else begin
      cpl_tx_bus_r <= cpl_tx_bus_i;
    end
  end // cpl_tx_bus_r_PROC


  /*--------------------------------------------------------------------
   * Instantiate first pending master fifos for all attached slaves.
   */


  


    
    
















  /*--------------------------------------------------------------------
   * Filter FIFO Outputs
   *
   * Use ifdefs to construct busses of signals for slaves which are 
   * attached only.
   */

  // Assign firstpnd_mst_s* outputs of all fifos to a single vector.
  // Use ifdefs to filter down to a bus of signals for connected
  // slaves only.
  assign firstpnd_mst_bus = {1'b0 // Dummy bit.
                           };

  assign fifo_empty_bus = {1'b0 // Dummy bit.
                            };

  assign fifo_nxt_empty_bus = {1'b0 // Dummy bit.
                              };


  /*--------------------------------------------------------------------
   * When a shared to dedicated link exists on the W channel there is 
   * deadlock condition that we need to avoid.
   *
   * This occurs when a master is next to send a first beat to a slave
   * s(x), but it must first complete at the shared write data channel.
   * But the shared W channel is stalled attempting to access the s(x) 
   * dedicatd channel (for a different master).
   * We avoid this by only sending a first write beat to a dedicated W
   * channel, when the shared layer is the next master to send a first
   * write beat there. This is the case when shrd_w_nxt_fb_pend_bus_i
   * is asserted for the appropriate slave. This signal qualifies the 
   * assertion of the request for the first beat t/x which will go
   * from the shared channel to the dedicated channel, and we generate
   * tx_started_s_r to qualify the request for the t/x after the
   * valid for the first beat has been generated, so we don't need an 
   * assertion on shrd_w_nxt_fb_pend_bus_i after this point.
   */
  always @ (posedge aclk_i or negedge aresetn_i) 
  begin : tx_started_s_r_PROC
    if(~aresetn_i) begin
      tx_started_s_r <= {NS{1'b0}};
    end else begin
      for(slv=0;slv<NS;slv=slv+1) begin
        if(~tx_started_s_r[slv]) begin
          // Don't assert for W t/x's that begin & end in 
          // 1 cycle.
          tx_started_s_r[slv] 
          <= bus_valid_shrd_out_i[slv] & ~cpl_tx_bus_i[slv];
        end else begin
          tx_started_s_r[slv] <= ~cpl_tx_bus_i[slv];
        end
      end
    end
  end // tx_started_s_r_PROC

  //spyglass disable_block FlopEConst
  //SMD: Enable pin of  flop tied to 1
  // SJ: Warning can be ignored
  // Mask for shrd_w_nxt_fb_pend_bus_i, to prevent it from forwarding
  // a valid to a dedicated channel, when the previously started t/x has
  // not yet been accepted at the dedicated W channel.
  // Mask asserts when a valid for a slave accessed through a dedicated
  // layer is accepted, and deasserts when shrd_w_nxt_fb_pend_bus_i 
  // deasserts. The dedicated layers deassert this bit when a
  // valid for the shared layer is accepted there.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : shrd_w_nxt_fb_pend_bus_mask_r_PROC
    if(~aresetn_i) begin
      shrd_w_nxt_fb_pend_bus_mask_r <= {NS{1'b0}};
    end else begin
      for(slv=0;slv<NS;slv=slv+1) begin
        if(has_ddctd_w_s[slv]) begin
          if(~shrd_w_nxt_fb_pend_bus_mask_r[slv]) begin
            shrd_w_nxt_fb_pend_bus_mask_r[slv]
              <= bus_valid_shrd_out_i[slv] & tx_acc_s_i;
          end else begin
            shrd_w_nxt_fb_pend_bus_mask_r[slv]
              <= shrd_w_nxt_fb_pend_bus_i[slv];
          end
        end // if(has_ddctd_w_s[slv]
      end // for(slv=0;...
    end  // if(~aresetn_i) ... else
  end // shrd_w_nxt_fb_pend_bus_mask_r_PROC
  //spyglass enable_block FlopEConst



  /*--------------------------------------------------------------------
   * Decode when each master is allowed to send a request to the
   * arbiter.
   *
   * For each master, we allow it to send a request it is the next 
   * pending master (i.e. the master number at the head of the next 
   * pending fifo) of any slave (if it is accessing that slave).
   */
  // spyglass disable_block W216
  // SMD: Reports inappropriate range select for integer or time variable
  // SJ: range of integer can be used and it will not cause any functional issue here
  // spyglass disable_block SelfDeterminedExpr-ML
  // SMD: Self determined expression found
  // SJ : The expression indexing the vector/array will never exceed the bound of the vector/array.        
  always @(*) begin : mst_req_allow_bus_PROC
    integer mbit;
    reg [L2_NM-1:0] firstpnd_mst_tmp;

    mst_req_allow_bus = {NM{1'b0}};
    // Cycle through each master, and decode if the first pending master
    // of any slave refers to that master.
    for(mst=0 ; mst<=(NM-1) ; mst=mst+1) begin
      for(slv=0 ; slv<=(NS-1) ; slv=slv+1) begin
    
        // Extract the firstpnd_mst value for this slave.
        for(mbit=0 ; mbit<=(L2_NM-1) ; mbit=mbit+1) begin
          firstpnd_mst_tmp[mbit] = firstpnd_mst_bus[(slv*L2_NM)+mbit];
        end

        // Blocking assignment build up the wide OR function.
        // To forward the valid for this master, the firstpnd_mst 
        // value of this slv must refer to this master, and the 
        // slaves first pending fifo must not be empty. 
        // NOTE, that a pre register empty signal is used if the arbiter
        // is pipelined. If the arbiter is pipelined the completion 
        // signal to pop the fifo will come 1 cycle later, so we use the 
        // pre reg empty to make up that signal, so we won't forward a 
        // request that a completion on the previous cycle should have 
        // masked.
        // If number of masters on the shared W layer is 1, then we can
        // ignore all fifo signals, or signals relating to the fifos.
        // A write data stream from a single master will always obey
        // write ordering rules, so no extra ordering processing is 
        // required.
        mst_req_allow_bus[mst] 
          =   mst_req_allow_bus[mst] 
            | (    ((firstpnd_mst_tmp == mst[L2_NM-1:0]) || (NM == 1))
                   // Because the address order from the master is lost 
                   // when we split the t/x's up into per slave fifos, 
                   // we must only forward a masters valid if it is
                   // accessing the slave whose next t/x pending fifo it
                   // is at the head of.
                 & ((bus_valid_shrd_i[(mst*NS)+slv]) || (NM == 1))
                   // Slave first pending master fifo is not empty.
                 & ((~fifo_empty_bus[slv]) || (NM == 1))
                   // To avoid deadlock between a shared and dedicated
                   // W channel, if a slave has a dedicated layer also
                   // (has_ddctd_w_s) , and the t/x related with this 
                   // request has not already started 
                   // (tx_started_s_r) , and the shared layer is not
                   // next to be allowed to send a first write beat
                   // at the dedicated slave channel, then do not
                   // forward the request for this slave to the arbiter.
                 & (   ~has_ddctd_w_s[slv] 
                     | (  shrd_w_nxt_fb_pend_bus_i[slv] 
                        & ~shrd_w_nxt_fb_pend_bus_mask_r[slv]
                       )
                       // If pipeline arbiter is removed, disregard
                       // tx_started_s_r[slv] when the t/x is completing
                       // , due to reg after the arbiter have to change
                       // grants combinatorially on completion.
                     | (   tx_started_s_r[slv]
                         & ((PL_ARB==0) | ~cpl_tx_bus_i[slv]) 
                       )
                   )
                   // If arbiter is pipelined, we need to remove the
                   // valid combinatorially if the fifo is about to
                   // empty.
                 & (  ~fifo_nxt_empty_bus[slv] 
                    | (PL_ARB == 0)
                    | (NM == 1)
                   )
                   // If arbiter is pipelined, we need to mask valid 
                   // while popping the fifo. Because we won't see the 
                   // new fifo data out until 1 cycle after wlast, which
                   // will be too late to generate correct valid 
                   // (requests) to the arbiter.
                 & ((PL_ARB == 0) | ~cpl_tx_bus_i[slv] | (NM == 1))
                   // If SHARED_PL == 1, there is a pipeline in the path
                   // from the completion signals to the fifos, so after 
                   // a completion, we won't have up to date data from 
                   // the fifos until 1 cycle later, so we mask any 
                   // requests to the completing slave until we have up 
                   // to date data from the fifos.
                 & (   (SHARED_PL == 0) 
                     | (NM == 1)
                     | ~(   cpl_tx_bus_r[slv] 
                          & bus_valid_shrd_i
                            [(mst*NS)+slv]
                        )
                   )
              );
      end // for(slv=0 ; ...
    end // for(mst=0 ; ...
  end // mst_req_allow_bus_PROC
  // spyglass enable_block SelfDeterminedExpr-ML      
  // spyglass enable_block W216


  // Mask input valids in generating requests, to apply ordering rules.
  assign bus_mst_req = bus_valid_i & mst_req_allow_bus;

  /*--------------------------------------------------------------------
   * Holding requests for pipelined arbiter configurations.
   *
   * If the channel arbiter is pipelined (PL_ARB == 1), new requests must
   * be generated for the arbiter in the same cycle that ready for the
   * current t/x is asserted, so that we get the correct new grant index
   * onthe next cycle from the pipelined arbiter. To achieve this , for
   * pipelined arbiter configurations, we detect completion (and pop the
   * slave next master pending fifo) when the completing write beat is
   * issued. After this pop we have the information we need to generate the
   * correct request in time for the next grant. But we must also hold the
   * current request until ready is asserted, otherwise the arbiters grant
   * will deassert. This logic performs that function, holding requests
   * until ready is asserted, at which point the requests will
   * combinatorially change.
   * */
  always @(*) begin : bus_mst_req_plarb_mux_PROC
    integer m;
    for(m=0;m<NM;m=m+1) begin
      bus_mst_req_plarb_mux[m]
        = (bus_mst_req_hold_r[m] & ~bus_ready_shrd_m_i[m])
          ? bus_mst_req_hold_r[m]
          : bus_mst_req[m];
    end
  end // bus_mst_req_plarb_mux_PROC

  always @(posedge aclk_i or negedge aresetn_i)
  begin : bus_mst_req_hold_r_PROC
    if(~aresetn_i) begin
      bus_mst_req_hold_r <= {NM{1'b0}};
    end else begin
      bus_mst_req_hold_r <= bus_mst_req_plarb_mux;
    end
  end // bus_mst_req_hold_r_PROC

  // Request holding logic is only required when the channel arbiter is
  // pipelined.
  assign bus_mst_req_o = PL_ARB ? bus_mst_req_plarb_mux : bus_mst_req;


endmodule
