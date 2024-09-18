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
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_sp_lockarb.v#8 $ 
**
** ---------------------------------------------------------------------
**
** File     : DW_axi_sp_lockarb.v
//
//
** Created  : Tue May 24 17:09:09 MEST 2005
** Modified : $Date: 2020/03/22 $
** Abstract : This module builds on the DW_axi_arb block to add
**            AXI transaction locking functionality.
**
** ---------------------------------------------------------------------
*/

module DW_axi_sp_lockarb (
  // Inputs - System.
  aclk_i,
  aresetn_i,
  bus_mst_priorities_i,

  // Inputs - Channel Source.
  rreq_i,
  wreq_i,
  tx_cnt_nz_i,

  // Inputs - Channel Destination.
  ready_i,

  // Inputs - Other address channel block.
  outstnd_txs_fed_i,
  outstnd_txs_nonlkd_i,
  unlocking_tx_rcvd_i,
  bus_grant_arb_i,
  grant_m_local_arb_i,
  lock_other_i,
  
  // Outputs - Other address channel block.
  outstnd_txs_fed_o,
  outstnd_txs_nonlkd_o,
  unlocking_tx_rcvd_o,
  lock_o,
  bus_grant_arb_o,
  grant_m_local_arb_o,

  // Inputs - Completion channel.
  cpl_tx_i,
  
  // Outputs - Channel Destination.
  grant_o,
  bus_grant_o,
  grant_m_local_o
);

   
//----------------------------------------------------------------------
// MODULE PARAMETERS.
//----------------------------------------------------------------------
  parameter ARB_TYPE = 0; // Arbitration type.

  parameter NC = 16; // Number of clients to the arbiter.

  parameter LOG2_NC = 4; // Log base 2 of number of clients to the
                         // arbiter.

  parameter LOG2_NC_P1 = 4; // Log base 2 of (number of clients to the
                            // arbiter + 1).

  parameter [0:0] PL_ARB = 0; // 1 to pipeline arbiter outputs.

  parameter MCA_EN = 0; // Enable multi cycle arbitration.

  parameter MCA_NC = 0; // Number of arb. cycles in multi cycle arb.

  parameter MCA_NC_W = 0; // Log base 2 of MCA_NC + 1.

  parameter MAX_FAC = 1; // Max. number of active commands to the 
                         // external slave.

  parameter LOG2_MAX_FAC_P1 = 2; // Log base 2 of MAX_FAC + 1.       

  parameter BUS_PRIORITY_W = 2; // Width of bus containing prioritys of 
                                // all visible masters.

  parameter LOCKING = 0; // Set to 1 to implement locking functionality.        
  parameter AWCH = 0; // Set to 1 if the arbiter is being used in a 
                      // write address channel. 

  // spyglass disable_block ReserveName
  // SMD: A reserve name has been used.
  // SJ: This parameter is local to this module. This is not passed to heirarchy below this module. hence, it will not cause any issue.
  parameter SHARED = 0; // Shared channel ?
  // spyglass enable_block ReserveName


  // Width of arbiter internal grant index.                                
  localparam ARB_INDEX_W = (ARB_TYPE==1) ? LOG2_NC_P1 : LOG2_NC;
  localparam [LOG2_MAX_FAC_P1-1: 0] MAX_FAC_LOC = MAX_FAC; 

//----------------------------------------------------------------------
// LOCAL MACROS.
//----------------------------------------------------------------------
  
  // This macro tells us when to implement AXI locking logic.
  // Only required if LOCKING parameter is set to 1 and number of
  // clients is greater than 1.
  `define IMPLEMENT_LOCKING ((LOCKING==1) && (NC>1))

//----------------------------------------------------------------------
// PORT DECLARATIONS
//----------------------------------------------------------------------

  // Inputs - System.
  input aclk_i;    // AXI system clock.
  input aresetn_i; // AXI system reset.

  // Priorities from all visible masters.
  input [BUS_PRIORITY_W-1:0] bus_mst_priorities_i; 
   
  // Inputs - Channel Source.
  // rreq not used in write channel instantiations and wreq not used in read channel instantiations 
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input [NC-1:0] rreq_i;    // Read request inputs.
  input [NC-1:0] wreq_i;    // Write request inputs.
  //spyglass enable_block W240


  // Transactions outstanding for the slave accessed by the granted 
  // master.
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input tx_cnt_nz_i; 
  //spyglass enable_block W240

  // Inputs - Channel Destination.
  input ready_i; 

  // Inputs - Other address channel block.
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input outstnd_txs_fed_i; // Falling edge detect on outstanding t/x's
                           // signal from other address channel.

  input outstnd_txs_nonlkd_i; // Asserted by other address channel block 
                              // when it has outstanding non locked
                              // transactions.

  input unlocking_tx_rcvd_i; // Asserted from other address channel when 
                             // it has received the unlocking 
                             // transaction.
  //spyglass enable_block W240

                
  input [NC-1:0]      bus_grant_arb_i;     // 1-hot bus grant and local
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input [LOG2_NC-1:0] grant_m_local_arb_i; // granted master interface
                                           // numbers from the other
                                           // address channels arbiter. 
                                           // These can become the grant 
                                           // indexes for this block 
                                           // during locked sequences.
  
  // Lock input from the other address channel block.
  input lock_other_i; 
  //spyglass enable_block W240

  // Internal priorities from the other address channels timing arbiter.

  // Output - Other address channel block.
  output outstnd_txs_fed_o; // Falling edge detect of outstanding t/x's
                            // in this channel to other address channel.

  output outstnd_txs_nonlkd_o; // Signal to other address channel 
                               // block, asserted when there are 
                               // outstanding transactions to the 
                               // slave in this channel.
  
  output unlocking_tx_rcvd_o; // Asserted when this channel has 
                              // received the unlocking transaction.

  output lock_o; // Lock input to the other
                 // address channel block.

  output [NC-1:0]      bus_grant_arb_o;     // Local granted master
  output [LOG2_NC-1:0] grant_m_local_arb_o; // and 1-hot grant signals
                                            // from this address
                                            // channels arbiter. 


  // Inputs - Completion channel.
  input cpl_tx_i; // For read address channel this signal will be driven
                  // by the read data channel block.
                  // For write address channel this signal will be 
                  // driven by the burst response block.
                  // In either case asserted when read/write transaction
                  // has completed.

  // Outputs - Channel Destination.
  output                    grant_o; // Asserted when a client 
                                     // is granted. Becomes 
                                     // valid to the channel 
                                     // destination.
          
  output [NC-1:0] bus_grant_o; // Bit for each client asserted when
                               // client is granted.
             
  output [LOG2_NC-1:0] grant_m_local_o; // Granted master local 
                                        // number.

  //--------------------------------------------------------------------
  // WIRE & REG VARIABLES.
  //--------------------------------------------------------------------
  // If locking is not present register not used
  reg [NC-1:0] req_arb; // Request inputs to the DW_axi_arb block.
  reg [NC-1:0] req_arb_r; // Registered version.

  reg [NC-1:0] req_r; // Registered version of [r/w]req_i to align
                      // with configured timing option.
           
  reg [LOG2_MAX_FAC_P1-1:0] txcount;   // Number of outstanding 
                                       // this channel.
  reg [LOG2_MAX_FAC_P1-1:0] txcount_r; // transactions to the slave on 
  reg [NC-1:0] locktx_arb_r;
  reg unlocking_tx_rcvd_r; // Register that is set when the unlocking
                           // transaction of a locked sequence has 
                           // been received.
  
  reg cpl_tx_r; // Registered version of the input signal.         

  reg this_ch_locked_r; // Asserted when this channel is locked.
  reg both_ch_locked_r; // Asserted when both channels are locked.
  wire this_ch_locked; // Same as above but qualified with
  wire both_ch_locked; // IMPLEMENT_LOCKING macro.
  //reg this_ch_locked_2r; // Registered this_ch_locked.

  wire this_ch_locked_arb; // Version of this_ch_locked that asserts
                           // combinatorially.

  wire this_ch_locked_plarb; // Version of this_ch_locked that asserts
                             // combinatorially if PL_ARB == 1.

  reg [NC-1:0] locktx_r; // Register to generate locktx_pla.

  reg unlocking_tx_rcvd_d1; // 1 cycle delayed version of 
                            // unlocking_tx_rcvd.

  reg unlock_d1; // 1 cycle delayed version of unlock signal.

  // Local and 1-hot master number and grant outputs
  // from the DW_axi_arb block.
  wire [LOG2_NC-1:0]      grant_m_local_arb;    
  wire                    grant_arb; 
  wire [NC-1:0]           bus_grant_arb; 

  //--------------------------------------------------------------------
  // Hold registers and muxes for arbiter outputs while a locked 
  // sequence is in progress or waiting to start.
  wire [NC-1:0]           bus_grant_lock_nxt; 
  reg  [NC-1:0]           bus_grant_lock_r; 

  wire [NC-1:0] locktx; // Bitwise OR of read and write locking 
                        // signals.

  wire [NC-1:0] locktx_pla; // Version of locktx aligned with channel
                            // timing option.

  wire locktx_granted; // Locktx signal of granted client, qualified 
                       // with grant output of the arbiter.      

  wire locktx_selected; // Locktx signal of granted client.      
  
  wire [NC-1:0] req_pla; // Version of [r/w]req_i aligned with grant index 
                         // output from the arbiter (w.r.t. configured
                         // timing option.)
    
  wire req_granted; // Request line of granted client.

  wire locked_first; // Asserted when this channels arbiter has
                     // locked but the other channels arbiter has
                     // yet to lock.

  wire tx_accepted; // Asserted when a transaction has been
                    // accepted.
        
  wire outstnd_txs_nonlkd; // Asserted when there are outstanding
                           // non locked transactions in either the 
                           // read or write address channels.
         
  wire max_act_txs; // Asserted when we have reached the maximum
                    // number of active transactions for this channel.

  wire unlock; // Asserted for a cycle at the end of a locked sequence.        
               // Unlocks the arbiter.

  wire mask_grant; // Asserted when grant from the arbiter is to be 
                   // masked out.

  wire unlocking_tx_rcvd_r_jstfd; // Version of unlocking_tx_rcvd_r that
                                  // will be 1'b0 if locking is not
                                  // enabled.

  wire unlocking_tx_rcvd; // Unlocking t/x received on either address 
                          // channel.

  wire outstnd_txs; // Asserted for locking enabled configurations when
                    // there are outstanding transactions with the 
                    // external slave.

  reg outstnd_txs_r; // Registered version of above signal.

  wire [NC-1:0] rlocktx; // Intermediary signals for *locktx_i inputs
  wire [NC-1:0] wlocktx; // to avoid synth warnings when locking is not
                         // configured.

  wire grant_pre_mask; // Output grant signal prior to masking.                         

  wire grant_masked; // Asserted when a grant (valid) is being masked.

  // lock_other_i, gated off when locking not implemented.
  wire lock_other_msk; 
  // registered version.
  reg lock_other_msk_r;
  // chose between registered and unregistered depending on PL_ARB.
  wire lock_other_msk_plarb;

  // Version of locktx granted that does not assert 1 cycle after a 
  // locked sequence if PL_ARB == 1.
  wire locktx_granted_plarb;

  // Asserted for duration of locked sequence when this channel locked
  // after the other address channel.
  reg locked_second_nxt;
  reg locked_second_r;


  // Asserted when timing arbiter of this channel should take internal
  // priority of timing arbiter on other channel at end of 
  // locked sequence.
  reg [NC-1:0] use_other_pri;

  wire [NC-1:0] bus_grant_arb_plarb;  
  reg [NC-1:0] bus_grant_arb_i_r;

  // lock_other_i, gated off when locking not implemented.
  assign lock_other_msk = `IMPLEMENT_LOCKING ? lock_other_i : 1'b0;

  // Create registered version.
  always @(posedge aclk_i or negedge aresetn_i) 
  begin : lock_other_msk_r_PROC
    if(~aresetn_i) begin
      lock_other_msk_r <= 1'b0;
    end else begin
      lock_other_msk_r <= lock_other_msk;
    end
  end // lock_other_msk_r_PROC

  // chose between registered and unregistered depending on PL_ARB.
  // Since in this mode, the grant was registered already in the other
  // channel, need to immediately use it here to block new locking
  // requests from this channel.
  assign lock_other_msk_plarb = PL_ARB 
                                ? lock_other_msk 
                                : lock_other_msk_r;

  // Need to register grants from other address channel if not already
  // pipelined.
    
  always @(posedge aclk_i or negedge aresetn_i) 
  begin : bus_grant_arb_i_r_PROC
    if(~aresetn_i) begin
      bus_grant_arb_i_r <= {NC{1'b0}};
    end else begin
      bus_grant_arb_i_r <= bus_grant_arb_i;
    end
  end // bus_grant_arb_i_r_PROC
  assign bus_grant_arb_plarb
    = PL_ARB ? bus_grant_arb_i : bus_grant_arb_i_r;


  // Instantiate arbiter module.
  DW_axi_arb
  
  #(ARB_TYPE,               // Arbitration type.
    NC,                     // Number of clients to arbiter.
    LOG2_NC,                // Log base 2 of number of clients to the 
                            // arbiter.
    LOG2_NC_P1,             // Log base 2 of (number of clients to the 
                            // arbiter + 1).
    PL_ARB,                 // Pipeline arbiter outputs ?
    MCA_EN,                 // Has multi-cycle arbitration ?
    MCA_NC,                 // Num. cycles in multi-cycle arbitration.
    MCA_NC_W,               // Log base 2 of MCA_NC.
    `AXI_MCA_HLD_PRIOR,     // Hold priorities for multi cycle arb.
    `AXI_MST_PRIORITY_W,    // Priority width of a single master.
    BUS_PRIORITY_W,         // Width of bus containing priorities of all
                            // visible masters.
    0,                      // Don't lock to client until burst completes.
    LOCKING                 // Add AXI locking features.
  )
  U_DW_axi_arb (
    // Inputs - System.
    .aclk_i               (aclk_i),
    .aresetn_i            (aresetn_i),
    .bus_priorities_i     (bus_mst_priorities_i),

    // Inputs - Channel Source.
    .lock_seq_i           (this_ch_locked_arb),
    .locktx_i             (locktx),
    .unlock_i             (unlock),
    .grant_masked_i       (grant_masked),
    .request_i            (req_arb),
    .use_other_pri_i      (use_other_pri),
    //.bus_grant_lock_i     (bus_grant_lock_r),
  
    // Inputs - Channel Destination.
    .valid_i              (grant_o),
    .ready_i              (ready_i),
    .last_i               (1'b0), // Not required here.
  
    // Outputs - Channel Destination.
    .grant_o              (grant_arb),
    .bus_grant_o          (bus_grant_arb),
    .grant_p_local_o      (grant_m_local_arb)
  );


  // Tie locking signals off to 1'b0 if locking is not configured.
  assign rlocktx = {(NC){1'b0}};
  assign wlocktx = {(NC){1'b0}};

  //--------------------------------------------------------------------

  //--------------------------------------------------------------------
  // Holding mux and register for arbiter output signals while a 
  // locked sequence is in progress (or waiting to start).

  // Create registered grant bus during locked sequence.
  assign bus_grant_lock_nxt = this_ch_locked
                              ? bus_grant_lock_r
                              : bus_grant_arb;
                        
  always @(posedge aclk_i or negedge aresetn_i)
  begin : bus_grant_lock_r_PROC
    if(~aresetn_i) begin
      bus_grant_lock_r <= {NC{1'b0}};
    end else begin
      bus_grant_lock_r <= bus_grant_lock_nxt;
    end 
  end // bus_grant_lock_r_PROC

  //spyglass disable_block FlopEConst
  //SMD: Enable pin EN on Flop always disabled
  //SJ: Warning can be ignored
  // Register locktx bits when lock sequence starts
  // Used in generating requests to arbiter.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : locktx_arb_r_PROC
    if(!aresetn_i) begin
      locktx_arb_r <= {NC{1'b0}};  
    end else begin
      if(!this_ch_locked) locktx_arb_r <= locktx;  
    end
  end // locktx_r_PROC
  //spyglass enable_block FlopEConst
  

  //--------------------------------------------------------------------
  // Generate the request inputs to the DW_axi_arb block.
  //--------------------------------------------------------------------
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue.
  generate
   if (`IMPLEMENT_LOCKING)
   begin
    if (AWCH)
    begin
     always @(*) 
     begin : gen_req_arb_PROC
       integer cnum;
       req_arb = {NC{1'b0}};
       for(cnum=0; cnum<=(NC-1); cnum=cnum+1) begin
         // Once this channel locks, we block all new requests,
         // locked or unlocked.
         if(this_ch_locked_plarb) begin
           req_arb[cnum] = req_arb_r[cnum];

         // Once one channel locks, we block all new locking 
         // requests until the lock sequence has ended.
         // It will take lock_other_msk_plarb 1 cyle to deassert at 
         // end of lock sequence, use unlock_d1 to allow new requests 
         // to propagate immediately after unlock.
         end else if(  locktx[cnum] 
                     & (lock_other_msk_plarb & (~unlock_d1))
                    )
         begin

           // For timing based arbiters, except for locking client granted
           // on the other channel, block all locking requests.
           if(~bus_grant_arb_plarb[cnum] & (ARB_TYPE!=0)) begin
             req_arb[cnum] = 1'b0;
           end else begin
             req_arb[cnum] = req_arb_r[cnum];
           end

         end else begin
           req_arb[cnum] =    wreq_i[cnum] 
                           | (rreq_i[cnum] & rlocktx[cnum]);
         end

       end // for(client_num=0...
     end // gen_req_arb_PROC  
    end // if (AWCH)
    else
    begin
     always @(*) 
     begin : gen_req_arb_PROC
       integer cnum;
       req_arb = {NC{1'b0}};
       for(cnum=0; cnum<=(NC-1); cnum=cnum+1) begin
         // Once this channel locks, we block all new requests,
         // locked or unlocked.
         if(this_ch_locked_plarb) begin
           req_arb[cnum] = req_arb_r[cnum];

         // Once one channel locks, we block all new locking 
         // requests until the lock sequence has ended.
         end else if(  locktx[cnum] 
                     & (lock_other_msk_plarb & (~unlock_d1))
                    )
         begin

           // For timing based arbiters, except for locking client granted
           // on the other channel, block all locking requests.
           if(~bus_grant_arb_plarb[cnum] & (ARB_TYPE!=0)) begin
             req_arb[cnum] = 1'b0;
           end else begin
             req_arb[cnum] = req_arb_r[cnum];
           end

         end else begin
           req_arb[cnum] =    rreq_i[cnum] 
                           | (wreq_i[cnum] & wlocktx[cnum]);
         end
       end // for(client_num=0...
     end // gen_req_arb_PROC  
    end // if (!AWCH)
   end // if (IMPLEMENT_LOCKING)
   else
   begin
    if (AWCH)
    begin
     always @(*) 
     begin : gen_req_arb_PROC 
      req_arb = wreq_i;
     end 
    end // if (AWCH)
    else
    begin
     always @(*) 
     begin : gen_req_arb_PROC 
      req_arb = rreq_i;
     end
    end // if (!AWCH)
   end //if (!IMPLEMENT_LOCKING)
  endgenerate

  // Create registered version of req_arb.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : req_arb_r_PROC
    if(~aresetn_i) begin
      req_arb_r <= {NC{1'b0}};
    end else begin
      req_arb_r <= req_arb;
    end 
  end // req_arb_r_PROC
  //spyglass enable_block W415a


  //--------------------------------------------------------------------
  // Generate bitwise or of read and write locking signals. A locked
  // transaction on either channel locks both channel.
  // Note have to qualify the lock signals with request signal - request
  // signals come from valids.
  assign locktx = `IMPLEMENT_LOCKING 
                  ? ((rlocktx & rreq_i) 
                     | (wlocktx & wreq_i)
                    )
                  : {NC{1'b0}};

  // Register lock_tx to align with configured timing option.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : locktx_r_PROC
    if(!aresetn_i) begin
      locktx_r <= {NC{1'b0}};  
    end else begin
      locktx_r <= locktx;  
    end
  end // locktx_r_PROC
  
  // locktx_pla reflects locktx aligned with the grant output from
  // the designware arbiter, i.e. it should be a registered 
  // version of locktx if the arbiter outputs are pipelined.
  // Necessary to detect when the unlocking transaction has been issued.
  assign locktx_pla = (PL_ARB==0) ? locktx : locktx_r;


  //--------------------------------------------------------------------
  // If a lock sequence is in progress we will select 
  // grant_o output from the request line of the granted client. There 
  // are 2 reasons for this, firstly we could have forced a request on 
  // the channel to lock the arbiter and the granted client may not be
  // requesting on this channel, and secondly, the client the arbiter is
  // locked to may not be the client that is granted the lock of both
  // channels. Note since we are passing the grant straight
  // through from the request line we have to add in the correct
  // registering for our timing options, just like what the DW_axi_arb
  // would have done internally.
  //--------------------------------------------------------------------
  
  // Register [r/w]req_i to align with configured timing option.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : req_r_PROC
    if(!aresetn_i) begin
      req_r <= {NC{1'b0}};  
    end else begin
      req_r <= AWCH ? wreq_i : rreq_i;  
    end
  end // req_r_PROC

  // req_pla reflects [r/w]req_i aligned with the grant output from
  // the designware arbiter, i.e. it should be a registered 
  // version of [r/w]req_i if the outputs of the arbiter are pipelined.
  assign req_pla = ((PL_ARB==0) 
                    ? (AWCH ? wreq_i : rreq_i) 
                    : req_r
                   );

  // This module selects the granted clients request line.
  // Takes either a registered or unregistered version of [r/w]req_i
  // as it's input, depending on the configured timing option.
  DW_axi_busmux
  
  #(NC,            // Number of inputs to mux.
    1,             // Width of each input to mux.
    LOG2_NC        // Width of select line to mux.
  ) 
  U_DW_axi_busmux_req_granted (
    .sel  (grant_m_local_o),
    .din  (req_pla), 
    .dout (req_granted) 
  );
  

  // Detect when this channels arbiter is locked but the other channels
  // arbiter has not locked.
  // Need to use this_ch_locked here as locktx_granted will go low
  // if the other channel has not yet locked (grant index that selects 
  // it swithces to other channels grant index in anticipation of  a
  // higher priority client winning arbitration there).
  assign locked_first 
    = !lock_other_msk & (locktx_granted_plarb | this_ch_locked);

  // Select between this channels and the other address channels
  // local granted master number. 
  assign grant_m_local_o = grant_m_local_arb;
  
  // Same as above for one hot grant bus.         
  assign bus_grant_o = bus_grant_arb;
  

  // Generate a registered version of cpl_tx_i . We want to
  // break all inter channel timing paths for timing performance.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : cpl_tx_r_PROC
    if(!aresetn_i) begin
      cpl_tx_r <= 1'b0;
    end else begin
      cpl_tx_r <= cpl_tx_i;
    end
  end // cpl_tx_r_PROC


  //--------------------------------------------------------------------
  // Generate a signal which will be asserted when there are 
  // outstanding transactions to the slave (reads or writes).
  //--------------------------------------------------------------------
  
  // Decode when a transaction has been accepted on this channel.
  // Note : grant_o becomes valid output to the channel destination.
  assign tx_accepted = grant_o & ready_i;

  //--------------------------------------------------------------------
  // Maintain count of active transactions to the slave from
  // this channel.
  //--------------------------------------------------------------------
  always @(*) 
  begin : txcount_PROC
    // Not necessary for shared channels (max outstanding t/x masking
    // done in sp_addrch) , so disconnect here to force register removal
    // during synthesis.
    case({cpl_tx_r, tx_accepted})
      // tx accepted and another completed in the same cycle.
      // Both imply no change to transaction count.
      2'b00,
      2'b11 : txcount = SHARED ? {LOG2_MAX_FAC_P1{1'b0}} : txcount_r; 

      // Transaction accepted, increment transaction count.
      2'b01 : txcount = txcount_r + 1'b1;
  
      // Transaction completed, decrement transaction count.
      2'b10 : txcount = txcount_r - 1'b1;
    endcase
  end // txcount_PROC

  always @(posedge aclk_i or negedge aresetn_i)
  begin : txcount_r_PROC
    if(!aresetn_i) begin
      txcount_r <= {LOG2_MAX_FAC_P1{1'b0}};
    end else begin
      txcount_r <= txcount;
    end
  end // txcount_r_PROC


  //--------------------------------------------------------------------
  // Decode when we have the maximum supported number of active 
  // transactions to the slave on this channel.
  // Not necessary if slave is visible to just 1 master, i.e. 1 client
  // => (NC == 1).
  // The txcount value is used if locking is configured or if number
  // of visible masters is > 1 (no locking if number of visible 
  // masters is == 1). 
  // These are the 2 cases where txcount_r is used so to ensure this
  // value is an accurate representation of the number of t/x's issued,
  // we will mask out the valid for any t/x that attempts to exceed
  // the max value.
  // Note that for shared address layers, max outstanding t/x masking
  // is done pre arbiter, not here.
  //--------------------------------------------------------------------
  assign max_act_txs = ((NC>1) & (SHARED==0))
                       ? (txcount_r == MAX_FAC_LOC)
                       : 1'b0;

  // Decode when there are outstanding transactions to the slave on
  // this channel. 
  assign outstnd_txs = 
    (`IMPLEMENT_LOCKING==1)
    // For a shared channel, the txcount is 
    // maintained in sp_addrch, not this block.
    ? (SHARED ? tx_cnt_nz_i
              : (txcount_r != {LOG2_MAX_FAC_P1{1'b0}})
      )
    : 1'b0;

  // Generate falling edge detect of outstnd_txs, used in detecting 
  // the end of a locked sequence.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : outstnd_txs_r_PROC
    if(!aresetn_i) begin
      outstnd_txs_r <= 1'b0;
    end else begin
      outstnd_txs_r <= outstnd_txs;
    end
  end // outstnd_txs_r_PROC

  // This needs to be an output to the other address channel so it can
  // unlock from an unlocking t/x on this channel, and vice versa.
  assign outstnd_txs_fed_o = (`IMPLEMENT_LOCKING==1)
                             ? (outstnd_txs_r && (!outstnd_txs))
                             : 1'b0;


  // To mask out initiation of locked sequences we need a version of
  // the outstanding tx's signal that will be 0 during a locking 
  // sequence.
  assign outstnd_txs_nonlkd_o = both_ch_locked
                                ? 1'b0
                                : outstnd_txs;

  // Decode when there are outstanding unlocked transactions to the 
  // slave on either read or write channels.
  // Used for masking lock sequence initiation.
  // Hold this signal at 1'b0 if we are not implementing AXI locking.
  assign outstnd_txs_nonlkd = (`IMPLEMENT_LOCKING==1) 
                              ? (outstnd_txs_nonlkd_o
                                  || outstnd_txs_nonlkd_i
                                )
                              : 1'b0;


  //--------------------------------------------------------------------
  // Generate the unlock signal.
  // The unlock signal is asserted on completion of a locking sequence. 
  // If while the arbiter is locked we decode the acceptance of an 
  // unlocking transaction (grant_o & ready !locktx[grant_m_local_o]) 
  // we set the register unlocking_tx_rcvd_r. Since the unlocking 
  // transaction can occur on either channel we have the input 
  // unlocking_transaction_i (we provide unlocking_transaction_o also) 
  // which is unlocking_tx_rcvd_r from the other channel.  
  // Once either of these are set, a falling edge detect of the 
  // outstnd_txs signal (completion of the unlocking transaction) 
  // asserts the unlock signal.
  //--------------------------------------------------------------------

  // This module selects the granted clients locktx signal.
  DW_axi_busmux
  
  #(NC,            // Number of inputs to mux.
    1,             // Width of each input to mux.
    LOG2_NC        // Width of select line to mux.
  ) 
  U_DW_axi_busmux_locktx_granted (
    .sel  (grant_m_local_o),
    .din  (locktx_pla), 
    .dout (locktx_selected) 
  );

  assign locktx_granted = locktx_selected & grant_arb;

  // Version of locktx granted that does not assert 1 cycle after a 
  // locked sequence if PL_ARB == 1.
  assign locktx_granted_plarb = locktx_granted & ((~unlock_d1) | (!PL_ARB));
  
  //spyglass disable_block STARC05-2.2.3.3
  //SMD: signal is assigned over the same signal in an always construct for sequential circuits
  //SJ: This is design intention, warning can be ignored
  // Set clear register.
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : unlocking_tx_rcvd_r_PROC
    if(!aresetn_i) begin
      unlocking_tx_rcvd_r <= 1'b0;
    end else begin
      // Unlocking transaction is decoded as transaction accepted
      // while the arbiter is locked with the granted clients
      // locktx signal deasserted. Note use of this_ch_locked as
      // opposed to both_ch_locked, it is possible that 
      // both_ch_locked will not assert for a channel if no t/x's
      // are sent on the channel during the locked sequence, but we 
      // can rely on this_ch_locked being asserted.
      if(this_ch_locked & tx_accepted & (!locktx_selected)) 
      begin
        unlocking_tx_rcvd_r <= 1'b1;
      end 
      
      if(unlock) begin
        // Clear this register when unlock is asserted.
        unlocking_tx_rcvd_r <= 1'b0;
      end
    end
  end // unlocking_tx_rcvd_r_PROC
  //spyglass enable_block W415a
  //spyglass enable_block STARC05-2.2.3.3

  
  // Generate version of unlocking_tx_rcvd_r that will be held at
  // 1'b0 if AXI locking is not enabled.
  assign unlocking_tx_rcvd_r_jstfd = (`IMPLEMENT_LOCKING==1)
                                     ? unlocking_tx_rcvd_r
                                     : 1'b0;


  // Unlocking transaction received on either address channel.
  assign unlocking_tx_rcvd = `IMPLEMENT_LOCKING
                             ? (unlocking_tx_rcvd_r_jstfd 
                                || unlocking_tx_rcvd_i
                               )
                             : 1'b0;

  // 1 cycle delayed version of unlocking_tx_rcvd.            
  always @(posedge aclk_i or negedge aresetn_i)
  begin : unlocking_tx_rcvd_d1_PROC
    if(!aresetn_i) begin
      unlocking_tx_rcvd_d1 <= 1'b0;
    end else begin
      unlocking_tx_rcvd_d1 <= unlocking_tx_rcvd;
    end
  end 
  

  // Decode when to unlock arbiter at the end of a locked sequence.
  // Unlocking transaction received on either channel followed
  // by a falling edge on outstnd_txs i.e. unlocking transaction
  // has completed. Need to use unlocking_tx_rcvd_d1 to avoid
  // trigerring unlock off the falling edge detect of outstnd_txs
  // before the master drove the unlocking t/x, which would not
  // represent the completion of the unlocking t/x.
  // Hold at 1'b0 if AXI locking is not enabled.
  assign unlock = 
    (`IMPLEMENT_LOCKING==1)
    ? (unlocking_tx_rcvd_d1 && (outstnd_txs_fed_o || outstnd_txs_fed_i))
    : 1'b0;


  // Generate 1 cycle delayed version of unlock signal.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : unlock_d1_PROC
    if(!aresetn_i) begin
      unlock_d1 <= 1'b0;
    end else begin 
      unlock_d1 <= unlock;
    end
  end // unlock_d1_PROC


  //--------------------------------------------------------------------
  // Conditions in which grant is masked.
  // 1. Arbiter is locked and there are outstanding transactions.
  //    Satisfies an AXI protocol rule.
  // 2. Arbiter in this channel has locked but arbiter in other 
  //    channel has yet to lock. We can only grant a locked 
  //    transaction on 1 channel when both can lock.
  // 3. We have already issued the maximum allowed number of 
  //    active (i.e. uncompleted) transactions to the slave.
  // 4. Mask from the time the unlocked t/x is issued to when we unlock 
  //    the channel internaly. Theoriticaly a master could complete the 
  //    lock sequence and issue another t/x the cycle after the
  //    unlocking t/x was issued, but because of internal pipelining 
  //    this new valid will reach here before this channel is unlocked. 
  //    Because we change from the locked clients index back to the
  //    arbiters output index after we unlocked we run the risk of
  //    removing a valid before ready returns. The signal
  //    unlocking_tx_rcvd_r is used for this purpose.
  // 5. If the arbiter is pipelined, mask the grant for 1 cycle after
  //    a lock sequence ends. The request of the locking client will
  //    have been held high until the end of the locked sequence until
  //    the arbiter is enabled - so that the arbiter can register the
  //    grant and reduce the priority of the client for the next grant.
  //    This request will be removed at that point. Since a pipelined
  //    arbiter will assert its grant on the next cycle when
  //    this_ch_locked has already deasserted, we must mask for this cycle
  //    to prevent a spurious valid propagating.
  assign mask_grant = (outstnd_txs_nonlkd
                         // Need to use locktx_granted here to mask
                         // a valid output on the first cycle before
                         // this_ch_locked gets set.
                       & (this_ch_locked | locktx_granted)
                      ) 
                      | locked_first 
                      | max_act_txs
                      | unlocking_tx_rcvd
                      | (PL_ARB & unlock_d1);

  //--------------------------------------------------------------------
  // Decode grant output.          
  // If mask_grant is asserted, grant output will be 0.
  // Otherwise depends on this_ch_locked (locktx_granted is used to
  // cover the cycle before this_ch_locked is set), recall that for
  // a locked transaction the grant will come from the request line of 
  // the granted client (look at generation of req_granted), otherwise 
  // grant output will come from the designware arbiter.
  // If multi cycle arbitration is enabled then we always select 
  // req_granted, as the arbiter grant output cannnot be used as a valid
  // output in this case also. 
  assign grant_o = mask_grant ? 1'b0 : grant_pre_mask;
  assign grant_pre_mask = 
    ( (    (this_ch_locked | locktx_granted)
        || (MCA_EN == 1)
      )
      // For multi cycle arbitration and locking
      // configs, want to avoid valid being asserted when
      // the arbiter has not yet granted.
      // This doesn't apply during a lock sequence,
      // the arbiter is being held inactive during
      // this time.
      ? req_granted & (   grant_arb
                        | this_ch_locked 
                        | locktx_granted
                        | (`AXI_HAS_LOCKING == 0)
                      )
      : grant_arb
    );

  // Assert when a grant (valid) is being masked. Used to disable timing
  // based arbiters (fcfs/fair among equals) while a valid is being 
  // masked.
  assign grant_masked = grant_pre_mask & mask_grant;


  //spyglass disable_block STARC05-2.2.3.3
  //SMD: signal is assigned over the same signal in an always construct for sequential circuits
  //SJ: This is design intention, warning can be ignored
  //spyglass disable_block FlopEConst
  //SMD: Enable pin EN on Flop always disabled
  //SJ: Warning can be ignored
  //--------------------------------------------------------------------
  // Generate this_ch_locked_r.
  // Asserted once a client requesting a locked t/x has been granted 
  // in this channel. Cleared when unlock is asserted.
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : this_ch_locked_r_PROC
    if(!aresetn_i) begin
      this_ch_locked_r <= 1'b0;
    end else begin
      // Unlock has higher priority.
      if(locktx_granted_plarb) 
        this_ch_locked_r <= 1'b1;
      if(unlock) this_ch_locked_r <= 1'b0;
    end
  end // this_ch_locked_r_PROC
  //spyglass enable_block W415a
  //spyglass enable_block FlopEConst
  //spyglass enable_block STARC05-2.2.3.3
  assign this_ch_locked = `IMPLEMENT_LOCKING ? this_ch_locked_r : 1'b0;

  // Version of this_ch_locked_r that asserts combinatorially. 
  assign this_ch_locked_arb = locktx_granted_plarb | this_ch_locked_r;
  
  // Version of this_ch_locked_r that asserts combinatorially
  // if PL_ARB == 1.
  assign this_ch_locked_plarb =   (locktx_granted_plarb & PL_ARB) 
                                | this_ch_locked_r;




  /* -------------------------------------------------------------------
   * For timing based arbiters, guarantee that the internal priorities
   * of all lock requesting clients are equal at the end of a locked
   * sequence, if one channels locks before the other.
   * Because each channel can lock at different times, and the arbiter 
   * of the channel yet to lock can be enabled while possibly multiple
   * non locked t/x's are accepted - pending locking t/x's can have
   * their priority incremented on that channel as they miss those
   * grants. After the lock sequence ends, this means that a locking
   * client can have a higher priority - relatively - on one channel
   * than the other, which breaks the requirement of the scheme used 
   * here that if each channel locks at the same time, they will grant
   * the same client.
   * To solve this, during the unlock cycle, when the arbiter is
   * enaled, the arbiter of the channel which was last to lock, will
   * take the internal priority of the locking clients from the 
   * other channels arbiter.
   */
  

  // Asserted for duration of locked sequence when this channel locked
  // after the other address channel.
  always @(*)
  begin : locked_second_nxt_PROC
    locked_second_nxt = locked_second_r;
    if(locked_second_r) begin
      locked_second_nxt = ~unlock;
    end else begin
      locked_second_nxt = lock_other_msk & (~lock_o);
    end
  end // locked_second_nxt_PROC

  always @(posedge aclk_i or negedge aresetn_i)
  begin : locked_second_r_PROC
    if(~aresetn_i) begin
      locked_second_r <= 1'b0;
    end else begin
      locked_second_r <= locked_second_nxt;
    end 
  end // locked_second_r_PROC

  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue.
  always @(*) begin : use_other_pri_PROC
    integer n;
    use_other_pri = {NC{1'b0}};
    // Required for timing based arbiters when locking is enabled only.
    // Don't take other channels priority for the currently granted
    // locking client.
    for(n=0;n<NC;n=n+1) begin
      use_other_pri[n]
        =   locked_second_r 
          & locktx_arb_r[n] 
          & unlock & (((ARB_TYPE==1) | (ARB_TYPE==2)) & LOCKING);
    end
  end // use_other_pri_PROC
  //spyglass enable_block W415a


  //--------------------------------------------------------------------
  // Generate both_ch_locked_r.
  // Asserted once a client requesting a locked t/x has been granted 
  // in both channels. Decoded as the first valid (grant_o here) being
  // asserted while locktx_selected is asserted. This can only happen
  // when both chanels are locked, but it will also only assert when
  // there are no more conditions masking the start of the locked 
  // sequence.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : both_ch_locked_r_PROC
    if(!aresetn_i) begin
      both_ch_locked_r <= 1'b0;
    end else begin
      if     (locktx_selected & grant_o) both_ch_locked_r <= 1'b1;
      else if(unlock)                    both_ch_locked_r <= 1'b0;
    end
  end // both_ch_locked_r_PROC
  assign both_ch_locked = `IMPLEMENT_LOCKING ? both_ch_locked_r : 1'b0;



  // Assert lock_o to inform the other address channel that this 
  // channels arbiter is locked.
  // Need to use this_ch_locked here as locktx_granted will go low
  // if the other channel has not yet locked (grant index that selects 
  // it swithces to other channels grant index in anticipation of  a
  // higher priority client winning arbitration there).
  assign lock_o = locktx_granted_plarb | this_ch_locked;

  // For AXI transaction locking between the 2 addressd channels in the
  // slave port block the other address channels needs to know what
  // client this channel is locked to, so we drive the 2 outputs below.
  assign bus_grant_arb_o = bus_grant_arb;
  assign grant_m_local_arb_o = grant_m_local_arb;

  // Drive this signal to the other address channel as the unlocking
  // tx could come from either channel and has to unlock both.
  assign unlocking_tx_rcvd_o = unlocking_tx_rcvd_r_jstfd;


endmodule
