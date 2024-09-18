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
// File Version     :        $Revision: #18 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_arb.v#18 $ 
**
** ---------------------------------------------------------------------
**
** File             : DW_axi_arb.v
**
**
** Created  : Tue May 24 17:09:09 MEST 2005
** Modified : $Date: 2020/03/22 $
** Abstract : This block implements the DW_axi arbiter.
**
** ---------------------------------------------------------------------
*/




module DW_axi_arb (
  // Inputs - System.
  aclk_i,
  aresetn_i,
  bus_priorities_i,

  // Inputs - Channel Source.
  lock_seq_i,
  locktx_i,
  unlock_i,
  grant_masked_i,
  request_i,
  use_other_pri_i,
  //bus_grant_lock_i,
  
  // Inputs - Channel Destination.
  valid_i,
  ready_i,
  last_i,
  
  // Outputs - Channel Destination.
  grant_o,
  bus_grant_o,
  grant_p_local_o
);

//----------------------------------------------------------------------
// MODULE PARAMETERS.
//----------------------------------------------------------------------
  parameter ARB_TYPE = 0; // Select type of arbitration.
                          // 0 - Dynamic priority (DP).
                          // 1 - First come first serve (FCFS).
                          // 2 - Fair among equals (2T).
                          // 3 - User defined.

  parameter NC = 4; // Number of clients to the arbiter.

  parameter LOG2_NC = 2; // Log base 2 of number of clients to the 
                         // arbiter.

  parameter LOG2_NC_P1 = 2; // Log base 2 of (number of clients to the 
                            // arbiter + 1).
       
  parameter [0:0] PL_ARB = 0; // Set to 1 if arb. output should be pipelined.

  parameter [0:0] MCA_EN = 0; // Enable multi cycle arbitration.

  parameter MCA_NC = 0; // Number of arb. cycles in multi cycle arb.

  parameter MCA_NC_W = 1; // Log base 2 of MCA_NC + 1.

  parameter MCA_HLD_PRIOR = 0; // Set to 1 if we should hold priority
                               // signals for multi cycle arbitration.
          
  parameter PRIORITY_W = 2; // Width of priority value for 1 client.

  parameter BUS_MASTERS_PRIORITY_W = 8; // Width of bus containing priorities of
                                // all visible masters.

  parameter [0:0] ARB_BURST_LOCK = 0; // Lock arbitration to client until 
                                // burst completes.

  parameter HAS_LOCKING = 0; // Add AXI locking features.

  parameter ARB_PARK_MODE = 0; // Macro for park mode parameter of
                             // instantiated designware arbiter.
                             // Set to not instantiate any parking 
                             // logic

  // Width of arbiter internal grant index.                                
  localparam ARB_INDEX_W = (ARB_TYPE==1) ? LOG2_NC_P1 : LOG2_NC;
  // Priority Bus width for each Master will be AXI_QOSW wide if ARBITER is selected as QoS Arbiter, otherwise wiil be  derived from PRIORITY_W(generic param)  
  localparam MASTERS_PRIORITY_W =(ARB_TYPE==4)? `AXI_QOSW: PRIORITY_W;

//----------------------------------------------------------------------
// LOCAL MACROS.
//----------------------------------------------------------------------
  `define ARB_PARK_INDEX    0 // Macro for park index parameter of
                              // instantiated designware arbiter.
            
  `define ARB_OP_MODE_NOREG 0 // Macro for output mode parameter of
                              // instantiated designware arbiter, this
                              // sets the parameter such that arbiter
                              // outputs will be unregistered.
                              // Note only applies to designware arbiter
                              // not DW_axi_arb.

  // Macro for number of clients to the designware arbiter.
  // If the NC parameter is 1 we will be ignoring all outputs of the 
  // designware arbiter so synthesis will blow it away, but passing
  // a parameter of 1 as number of clients to this arbiter will
  // cause an internal parameter check error, so if the actual
  // number of clients is 1, we will pass 2 to the designware arbiters
  // parameter to satisfy this check but externally bypass the arbiter
  // so the value won't matter.
  `define NC_INTERNAL  ((NC==1) ? 2 : NC)            

  // Macro for priority bus to the arbiter, using NC_INTERNAL macro.
  `define BUS_PRIOR_W_INTERNAL (`NC_INTERNAL*MASTERS_PRIORITY_W)

//----------------------------------------------------------------------
// PORT DECLARATIONS
//----------------------------------------------------------------------

// Inputs - System.
   input aclk_i;    // AXI system clock.
   input aresetn_i; // AXI system reset.

   input [BUS_MASTERS_PRIORITY_W-1:0] bus_priorities_i; // Bus containing 
                                                // priorities of all 
                                                 // connected ports.


// Inputs - Channel Source.
   input lock_seq_i; // Asserted when a lock sequence is active.
   input unlock_i; // Force arbiter enable cycle at end of lock
                   // sequence.

   input grant_masked_i; // Asserted when a grant is masked externally,
                         // used to disable timing based arbiters 
                         // during the masking period.

   input [NC-1:0] request_i; // Client request inputs.
   input [NC-1:0] locktx_i; // Lock inputs per client.

   // 1 means timing arbiter should use the priority of the other
   // address channel for that client.
   //spyglass disable_block W240
   //SMD: An input has been declared but is not read
   //SJ: If number of clients are 1 then this signal is not used
   input [NC-1:0] use_other_pri_i; 
   // Bit asserted for granted locking client.
   //input [NC-1:0] bus_grant_lock_i;

   //spyglass enable_block W240

// Inputs - Channel Destination.
   input valid_i; // The final valid signal that is issued from the 
                  // channel destination.
   input ready_i; // Used to hold the grant index until transfer is 
                  // accepted.
   input last_i; // Last beat of data, only used for read data 
                 // currently.      

// Outputs - Channel Destination.
   output grant_o;  // Grant signal to channel destination.
   output [NC-1:0] bus_grant_o; // One hot granted bus, bit per client.

   output [LOG2_NC-1:0] grant_p_local_o; // Granted port local.


  //--------------------------------------------------------------------
  // REGISTER VARIABLES.
  //--------------------------------------------------------------------
  //Based on parameter MCA_EN this signal may not be used
  wire take_mca_grant;
  reg tx_not_accepted_r; // Asserted when we need to hold the current
                         // grant index output because the destination
                         // has not accepted the current transfer.

       
  // Holds grant index static until burst completes.
  reg burst_tx_not_cpl_r;

  
  // Hold registers for the grant index. We select out these values
  // if the current transfer was not accepted.

  reg [LOG2_NC-1:0] grant_index_hold_r; 
  reg [NC-1:0] bus_grant_hold_r;    

  //--------------------------------------------------------------------
  // WIRE VARIABLES.
  //--------------------------------------------------------------------
  wire                    grant_arb_o;       // Outputs from bcm arb.
  wire [LOG2_NC-1:0]      grant_index_arb_o; // 
  wire [`NC_INTERNAL-1:0] bus_grant_arb_o;   //

  wire               grant_1client_mux;         // Grant and grant index
  wire [NC-1:0]      bus_grant_arb_1client_mux; // signals for outputs 
  wire [LOG2_NC-1:0] grant_index_1client_mux;   // of 1 client muxes.
  //Based on parameter ARB_BURST_LOCK this signal may not be used.
  // Result of mux between grant_index_hold_r and gi_port_req_mux , 
  // depends on wether current transfer was accepted or not.
  wire [LOG2_NC-1:0] grant_index_hold_mux; 

  // Result of mux between bus_grant_hold_r and bus_g_port_req_mux, 
  // depends on wether current transfer was accepted or not.
  //Based on parameter MCA_EN this signal may not be used.
  wire [NC-1:0] bus_grant_hold_mux; 

  // Signals for registered arbitration outputs.
  wire               grant_arbpl;   
  wire [NC-1:0]      bus_grant_arbpl; 
  wire [LOG2_NC-1:0] grant_index_arbpl;   

  // Inverted input priorities , need to invert because designware
  // arbiter grants to lowest requesting priority, whereas we want
  // to grant to the highest requesting priority.
  wire [BUS_MASTERS_PRIORITY_W-1:0] bus_priorities_inv; 

  // Look at the comments for the macro NC_INTERNAL to see the need
  // for these signals.
  wire [`NC_INTERNAL-1:0]          req_arb;
  wire [`BUS_PRIOR_W_INTERNAL-1:0] bus_priorities_inv_arb;

  wire arb_enable; // Signal to disable/stall the arbiters.


  // Multi cycle arbitration signals.
  wire [`NC_INTERNAL-1:0] req_mca; // Request signals from multi cycle
                                   // arbitration request hold block.
           
  wire [NC-1:0] bus_grant_mca; // bus_grant signal decoded for multi
                               // cycle arb.

  // Priority signals from multi cycle arb block.            
  wire [`BUS_PRIOR_W_INTERNAL-1:0] bus_priorities_mca;

  wire new_req; // Asserted when the request hold block can forward
                // new requests.

  // Grant hold signals.           
  // Used to hold grant signal if the arbiter output changes while
  // a valid is pending. Only required for multi cycle arbitration.
  //Based on parameter MCA_EN this signal may not be used.
  reg grant_hold_r; 
  wire grant_hold_mux;
  reg unlock_d1;


  // Wires for unconnected module outputs.
  //Signals used for unconnected ports of module instantiations 
  wire locked_unconn;
  wire parked_unconn;
    // Pass 2 bits if NC == 1.
  wire [`NC_INTERNAL-1:0] use_other_pri_int; 
  //wire [`NC_INTERNAL-1:0] bus_grant_lock_int;
  //Not used if NC==1 
  wire [(`NC_INTERNAL*ARB_INDEX_W)-1:0] bus_priority_other_int;
  wire [(`NC_INTERNAL*ARB_INDEX_W)-1:0] bus_priority_o_int;
  //--------------------------------------------------------------------
 

  generate 
    if (NC==1)
    begin
      assign use_other_pri_int = 2'b00 ;
    //  assign bus_grant_lock_int = 2'b00 ;
     assign bus_priority_other_int = 2'b00 ;
    end
    else
    begin
      assign use_other_pri_int = use_other_pri_i;
      //assign bus_grant_lock_int = bus_grant_lock_i ;
     assign bus_priority_other_int = {(`NC_INTERNAL*ARB_INDEX_W){1'b0}};
    end
  endgenerate   
  
  // Invert input priorities so we grant to highest priority requesting
  // client as opposed to lowest.
  assign bus_priorities_inv = ~bus_priorities_i;

  // Need to use these wires to connect to the designware arbiter to
  // get rid of warnings when there is only 1 client to the arbiter.
  // spyglass disable_block W164b
  // SMD: Identifies assignments in which the LHS width is greater than the RHS width
  // SJ : This is not a functional issue, this is as per the requirement.
  //      Hence this can be waived.  
  assign req_arb = request_i;
  // spyglass enable_block W164b
 //VP:: To avoid lint error assigned unused bits to 0
  generate
    if (`BUS_PRIOR_W_INTERNAL == BUS_MASTERS_PRIORITY_W) 
      assign bus_priorities_inv_arb = bus_priorities_inv;
    else
      assign bus_priorities_inv_arb = {{(`BUS_PRIOR_W_INTERNAL -BUS_MASTERS_PRIORITY_W){1'b0}}, bus_priorities_inv};
  endgenerate  

  /* ------------------------------------------------------------------
   * Generate tx issued signal for pipeline arbiter mode.
   * Can't wait until valid*ready in this mode because due to the 
   * 2 registers in the path (arbiter priority reg + pipeline reg
   * after arbiter) it will take too long to get to the next grant.
   * Instead we enable the arbiter when the t/x is issued, so it is
   * ready immediately when the previous t/x is accepted.
   * Part of this is that the register after the arbiter (pipeline reg
   * must only take new grants when valid & ready.
   *
   * jstokes, crm 9000403280, 4.8.2010
   * If arbiter grants on cycle after unlock, grant regardless of grant 
   * output from the pipeline stage and value of ready_i.
   * If PL_ARB==1, the cycle after a locked sequence ends is a dead
   * cycle. We need to detect an arbiter grant condition in this cycle
   * so we can enable the arbiter.
   * In locking configurations, if the arbiter is not enabled when it
   * should be, the same client can have different priorities on 
   * different channels, which can cause deadlock to occur.
   */
  wire tx_issued_plarb;
  assign tx_issued_plarb =   grant_arb_o 
                           & (~(grant_arbpl & (~ready_i)) | unlock_d1);

  // Asserted when transaction accepted at slave.
  wire tx_acc;
  assign tx_acc = valid_i & ready_i;

  /* ------------------------------------------------------------------
  * jstokes, 4/10/2010, STAR 9000423028
  * Enable arbiter correctly in non pipelined arbiter mode. 
  * Previously was enabled when t/x accepted in this mode, but since 
  * arbiter may already be granting another client, this is too late.
  * Now arbiter is enabled when the t/x is issued.
  * This also fixes STAR 9000423090.
  */
  wire tx_issued;
  assign tx_issued = valid_i & (~tx_not_accepted_r);

  /* ------------------------------------------------------------------
  * Extend tx_acc/tx_acc_plarb until the end of the current arbitration
  * window in Multi Cycle Arbitration mode.
  * Used to enable the arbiter if a transfer was accepted during the 
  * arbitration window.
  */
  //spyglass disable_block STARC05-2.2.3.3
  //SMD: Enable pin EN on Flop is always enabled
  //SJ: This violation can be ignored
  //spyglass disable_block FlopEConst
  //SMD: Enable pin EN on Flop is always enabled
  //SJ: In some configurations enable pin will always be enabled
  // Based on parameter MCA_EN and Pipelining options this signal may not be used.
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: Priority encoding. This is not an issue.
  reg tx_acc_ext_mca_r;
  always @(posedge aclk_i or negedge aresetn_i) 
  begin : tx_acc_ext_mca_r_PROC
    if(~aresetn_i) begin 
      tx_acc_ext_mca_r <= 1'b0;
    end else begin
      if(tx_issued_plarb) tx_acc_ext_mca_r <= 1'b1;
      // Reset at end of arbitration window.
      if(new_req)         tx_acc_ext_mca_r <= 1'b0;
    end 
  end // tx_acc_ext_mca_r_PROC
  //spyglass enable_block W415a
  //spyglass enable_block FlopEConst
  //spyglass enable_block STARC05-2.2.3.3


  //spyglass disable_block W116
  //SMD: For operator (&), left expression should match right expression  
  //SJ: Violation can be ignored
  // To get the proper effect of the fcfs and 2t arbitration schemes
  // we have to freeze the state of the arbiter when a valid (grant)
  // has been issued but has not been accepted. In this way when
  // ready is asserted we will get the grant index we expect and not
  // a more random grant index, which would be the case if the arbiter
  // was free running while we waited for ready.
  // The new_req signal is used to control arbiter enabling when
  // multi cycle arbitration is being performed i.e. the arbiter is
  // only enabled for the last cycle of the arbitration period, so it
  // doesn't continually update its internal state for each cycle of
  // the arbitration window.
  // grant_masked_i is used to disable the arbiters while a grant has
  // been masked (e.g. due to the max amount of outstanding t/x's 
  // having been reached).
  // If PL_ARB need extra decoding to stop arbiter enable at start
  // of locked sequence, because of registers after arbiter it will
  // take 1 more cycle for lock_seq_i to assert.
  // Also note that for PL_ARB or multi cycle arbitration (MCA_EN), 
  // we have to enable the arbiter on when a grant is issued, before 
  // the register stage. If we wait until after the register stage 
  // it will be too late to get a new grant out on the next cycle.
  //
  // jstokes, 4/10/2010, STAR 9000423028 & 9000423090.
  // - In non pipeline arbiter mode, arbiter is now enabled on tx issue
  //   instead of tx accept.
  assign arb_enable
    =  (  (   (((!PL_ARB) & (!MCA_EN)) & tx_issued)
            | (   (PL_ARB | MCA_EN) & (tx_issued_plarb | tx_acc_ext_mca_r)
               & (~(|(locktx_i & bus_grant_arb_o)))
              )
          )
        & new_req
        // jstokes, 10.6.2010, STAR 9000399067
        // If grant is masked in pipeline arbiter mode, on the cycle
        // after a locked sequence ends, we need to allow the arbiter
        // to be enabled in this cycle.
        & ((~grant_masked_i) | (unlock_d1 & PL_ARB))
          // Disable arbiter during lock sequence.
        & (~lock_seq_i)
       )
       // Force an enable during the unlock cycle (end of lock sequence)
       | unlock_i;
  //spyglass enable_block W116


  //--------------------------------------------------------------------
  // Performs arbiter input signal holding when multi cycle 
  // arbitration is enabled.
  //--------------------------------------------------------------------
  DW_axi_mca_reqhold
  
  #(MCA_EN,                // 1 if multi cycle arbitration is enabled.
    MCA_HLD_PRIOR,         // 1 if priority bits should be registered.
    `BUS_PRIOR_W_INTERNAL, // Width if priority signal bus.
    `NC_INTERNAL,          // Number of request signals.
    ARB_TYPE               // Arbitration Type
  )
  U_DW_axi_mca_reqhold (
    // Inputs - System.
    .aclk_i      (aclk_i),
    .aresetn_i   (aresetn_i),

    // Inputs - Payload source.
    .bus_req_i   (req_arb),
    .bus_prior_i (bus_priorities_inv_arb),
    
    // Inputs - Multi cycle arbitration control.
    .new_req_i   (new_req),

    // Outputs - Channel arbiter.
    .bus_req_o   (req_mca),
    .bus_prior_o (bus_priorities_mca)
  );


  //--------------------------------------------------------------------
  // Instantiate designware arbiter.
  //--------------------------------------------------------------------
  generate 
    case (ARB_TYPE)

      `AXI_ARB_TYPE_DP : begin : gen_arb_type_dp
        
      assign bus_priority_o_int = {`NC_INTERNAL*ARB_INDEX_W{1'b0}};
        DW_axi_arbiter_dp
        
        #(`NC_INTERNAL,       // Number of clients.
          MASTERS_PRIORITY_W,         // Priority signal width per client.   
          ARB_PARK_MODE,     
          `ARB_PARK_INDEX,    
          `ARB_OP_MODE_NOREG,
          LOG2_NC             // Width of grant index.
        )
        U_DW_axi_arbiter_dp (
          // Inputs 
          .clk          (aclk_i),
          .rst_n        (aresetn_i),
          .enable       (1'b1), // Always enable.
      
          .request      (req_mca),
          .lock         ({`NC_INTERNAL{1'b0}}), // Not using lock inputs.
          .mask         ({`NC_INTERNAL{1'b0}}), // Not using mask inputs.
          .prior        (bus_priorities_mca),
          
          // Outputs
          .granted      (grant_arb_o),
          .grant_index  (grant_index_arb_o),
          .grant        (bus_grant_arb_o), 
          .locked       (locked_unconn), // Unconnected output.
          .parked       (parked_unconn)  // Unconnected output.
        );
      end
    
      `AXI_ARB_TYPE_FCFS : begin : gen_arb_type_fcfs
        DW_axi_arbiter_fcfs
        
        #(`NC_INTERNAL,       // Number of clients.
          ARB_PARK_MODE,     
          `ARB_PARK_INDEX,    
          `ARB_OP_MODE_NOREG,
          LOG2_NC,           // Index width.
          LOG2_NC_P1,        // Index width (log b2 (num clients + 1).
          HAS_LOCKING        // Locking features required.
         )
        U_DW_axi_arbiter_fcfs (
          // Inputs.
          .clk           (aclk_i),
          .rst_n         (aresetn_i),
      
          .init_n        (1'b1), 
          // NOTE : arb_enable must be the signal that connects to 
          // the arbiter enable port. An assertion checker uses
          // this to check arbiter enabling.
          .enable        (arb_enable), 
          .request       (req_mca),
          .lock          ({`NC_INTERNAL{1'b0}}), // Not using lock inputs.
          .mask          ({`NC_INTERNAL{1'b0}}), // Not using mask inputs.
          .use_other_pri (use_other_pri_int),
          //.bus_gnt_lk_i  (bus_grant_lock_int),
          .bus_pri_other (bus_priority_other_int),

          // Outputs.
          .granted       (grant_arb_o),
          .grant_index   (grant_index_arb_o),
          .grant         (bus_grant_arb_o), 
          .bus_pri       (bus_priority_o_int),
          .locked        (locked_unconn), // Unconnected output.
          .parked        (parked_unconn)  // Unconnected output.
         );
      end

      `AXI_ARB_TYPE_2T : begin : gen_arb_type_2t
        DW_axi_arbiter_fae
        
        #(`NC_INTERNAL,       // Number of clients.
          MASTERS_PRIORITY_W,         // Priority width per client.
          ARB_PARK_MODE,     
          `ARB_PARK_INDEX,    
          `ARB_OP_MODE_NOREG,
          LOG2_NC,            // Index width.
          HAS_LOCKING         // Locking features required.
        )
        U_DW_axi_arbiter_fae (
          .clk           (aclk_i),
          .rst_n         (aresetn_i),

          .init_n        (1'b1), 
          // NOTE : arb_enable must be the signal that connects to 
          // the arbiter enable port. An assertion checker uses
          // this to check arbiter enabling.
          .enable        (arb_enable), 
          .request       (req_mca),
          .prior         (bus_priorities_mca),
          .lock          ({`NC_INTERNAL{1'b0}}), // Not using lock inputs.
          .mask          ({`NC_INTERNAL{1'b0}}), // Not using mask inputs.
          .use_other_pri (use_other_pri_int),
          //.bus_gnt_lk_i  (bus_grant_lock_int),
          .bus_pri_other (bus_priority_other_int),
       
          .granted       (grant_arb_o),
          .grant_index   (grant_index_arb_o),
          .grant         (bus_grant_arb_o), 
          .bus_pri       (bus_priority_o_int),
          .locked        (locked_unconn), // Unconnected output.
          .parked        (parked_unconn)  // Unconnected output.
        );
      end



 `AXI_ARB_TYPE_QOS : begin : gen_arb_type_qos
        
      assign bus_priority_o_int = {`NC_INTERNAL*ARB_INDEX_W{1'b0}};
        DW_axi_arbiter_dp
        
        #(`NC_INTERNAL,       // Number of clients.
          MASTERS_PRIORITY_W,         // Priority signal width per client.   
          ARB_PARK_MODE,     
          `ARB_PARK_INDEX,    
          `ARB_OP_MODE_NOREG,
          LOG2_NC             // Width of grant index.
        )
        U_DW_axi_arbiter_dp (
          // Inputs 
          .clk          (aclk_i),
          .rst_n        (aresetn_i),
          .enable       (1'b1), // Always enable.
      
          .request      (req_mca),
          .lock         ({`NC_INTERNAL{1'b0}}), // Not using lock inputs.
          .mask         ({`NC_INTERNAL{1'b0}}), // Not using mask inputs.
          .prior        (bus_priorities_mca),
          
          // Outputs
          .granted      (grant_arb_o),
          .grant_index  (grant_index_arb_o),
          .grant        (bus_grant_arb_o), 
          .locked       (locked_unconn), // Unconnected output.
          .parked       (parked_unconn)  // Unconnected output.
        );
      end


    endcase
  endgenerate


  // If there is only 1 client to the arbiter we can ignore
  // the grant and grant index outputs from the arbiter and
  // use instead request_i[0] and 'b0 respectively.
  assign grant_1client_mux = (NC==1) ? request_i[0] : grant_arb_o;

  //spyglass disable_block W164a
  //SMD: Identifies assignments in which the LHS width is less than the RHS width
  //SJ: This is not an issue as it is configuration dependent and only required bits are taken into consideration 
  //spyglass disable_block W164b
  //SMD: Identifies assignments in which the LHS width is greater than the RHS width
  //SJ: This is not an issue as it is configuration dependent and only required bits are taken into consideration 
  assign bus_grant_arb_1client_mux = (NC==1) 
                                     ? request_i[0] 
                                      : bus_grant_arb_o;
  //spyglass enable_block W164b
  //spyglass enable_block W164a

  assign grant_index_1client_mux = (NC==1) 
                                   ? {LOG2_NC{1'b0}} 
                                   : grant_index_arb_o;

  // Decode when to allow the pipeline arbiter register to
  // take new grants from the arbiter.
  // Normally when t/x is accepted, but not during locked sequence.
  // 1 cycle after a locked sequence the grants will have
  // updated, after enabling the arbiter.
  always @(posedge aclk_i or negedge aresetn_i) 
  begin : unlock_d1_PROC
    if(~aresetn_i) begin
      unlock_d1 <= 1'b0;
    end else begin
      unlock_d1 <= unlock_i;
    end
  end // unlock_d1_PROC
  wire take_apl_grant;                                   
  assign take_apl_grant = (tx_acc & (!lock_seq_i)) | unlock_d1;

  // jstokes, 26/7/2010, fix for STAR 9000406277
  // The cause of the bug was that in multi cycle arbtiratio (MCA)
  // mode configurations, the arbiter pipeline module would capture a new 
  // grant without fail every X number of cycles. Because in MCA mode the 
  // arbiter is enabled once a grant is issued (not accepted) - due to the 
  // register stage we want to have a new grant ready to go immediately - it can
  // happen that the arbiter issues a new grant index, and a previous
  // grant index which was not issued as a transaction due to a previous
  // valid wait for ready, can be overwritten. The net result of this
  // effect was that the grant order from the arbiter would be changed.
  //
  // Allow the pipeline stage after the arbiter to register new grants
  // only when the arbiter has been enabled
  // OR
  // When no valid is active from the granted master. In this case we 
  // need to be sure that the reason for no valid is not because the valid
  // is masked. If it is masked we need to hold the grant until the
  // transfer is unmasked and accepted.
  assign take_mca_grant = MCA_EN 
                          ? arb_enable | ((~valid_i) & (~grant_masked_i))
                          : 1'b1;

  // This block does all registering of the arbiter outputs.         
  DW_axi_arbpl
   #(
    PL_ARB,          // 1 to perform pipelining.
    NC,              // Width of bus_grant_*
    LOG2_NC,         // Width of grant_index_*
    MCA_EN,          // Enable multi cycle arbitration.
    MCA_NC,          // Number of arb. cycles in multi cycle arb.
    MCA_NC_W         // Log base 2 of MCA_NC.
  )
  U_DW_axi_arbpl (
    // Inputs - System.
    .aclk_i           (aclk_i),
    .aresetn_i        (aresetn_i),

    // Inputs 
    .grant_i          (grant_1client_mux),
    .bus_grant_i      (bus_grant_arb_1client_mux),
    .grant_index_i    (grant_index_1client_mux),
    .take_grant_i     (take_apl_grant),
    .take_mca_grant_i (take_mca_grant),
  
    // Outputs
    .grant_o          (grant_arbpl),
    .bus_grant_o      (bus_grant_arbpl),
    .grant_index_o    (grant_index_arbpl),
    .new_req          (new_req)
  ) ;

  // Decode this register value to tell us when the current transfer
  // was not accepted. Used to hold the grant index output until
  // the transfer is accepted. This is a registered value because
  // we only have to worry about the designware arbiters grant index
  // changing the cycle after a client is first granted, because it
  // has already won the arbitration in the cycle it became granted.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : tx_not_accepted_PROC
    if(!aresetn_i) begin
      tx_not_accepted_r <= 1'b0;
    end else begin
      if(valid_i & (!ready_i)) begin
        tx_not_accepted_r <= 1'b1;
      end else begin
        tx_not_accepted_r <= 1'b0;
      end
    end
  end // tx_no_accepted_PROC

  // 'burst_tx_not_cpl_r' signal is used only whenever 'Locked Arbitration' is enabled.
  // burst_tx_not_cpl_r is used to hold the grant index output 
  // static while we are waiting for a burst to complete.
  // Used to implement a data interleaving depth of 0 on the
  // read data channel.
  // Registered value to take effect after current cycle.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : burst_tx_not_cpl_r_PROC
    if(!aresetn_i) begin
      burst_tx_not_cpl_r <= 1'b0;
    end else begin
      if(~burst_tx_not_cpl_r) begin
        burst_tx_not_cpl_r <= valid_i & (!last_i);
      end else begin
        burst_tx_not_cpl_r <= ~(valid_i & ready_i & last_i);
      end
    end
  end // burst_tx_not_cpl_r_PROC


  // Hold register for grant signal. This is selected as the
  // grant output if the current transfer was not accepted.
  // Only necessary for multi cycle arbitration, as in all
  // other cases a client can only change by when another client
  // is requesting. In multi cycle arbitration however, the 
  // granted client can change to a client that is not requesting.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : grant_hold_r_PROC
    if(!aresetn_i) begin
      grant_hold_r <= 1'b0;
    end else begin
      grant_hold_r <= grant_hold_mux;
    end
  end // grant_hold_r_PROC

  // If a valid is pending use the hold register signal, otherwise
  // use the signal direct from the register after the arbiter stage.
  assign grant_hold_mux = (tx_not_accepted_r && MCA_EN)
                          ? grant_hold_r
                          : grant_arbpl;

  // Hold register for grant index. This is selected as the
  // grant index output if the current transfer was not accepted.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : grant_index_hold_r_PROC
    if(!aresetn_i) begin
      grant_index_hold_r <= {LOG2_NC{1'b0}};
    end else begin
      grant_index_hold_r <= grant_index_hold_mux;
    end
  end // grant_index_hold_r_PROC

  // If current transfer was not accepted, select the hold
  // register version of the grant index, as opposed to the 
  // one coming direct (possibly registered) from the designware
  // arbiter.
  // For some channels we want to lock arbitration to a client until
  // a burst has completed.
  assign grant_index_hold_mux = (  tx_not_accepted_r 
                                 | (burst_tx_not_cpl_r & ARB_BURST_LOCK)
                                )
                                ? grant_index_hold_r
                                : grant_index_arbpl;


  // Hold register for bus grant index. This is selected as the
  // bus grant index output if the current transfer was not accepted.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : bus_grant_hold_r_PROC
    if(!aresetn_i) begin
      bus_grant_hold_r <= {NC{1'b0}};
    end else begin
      bus_grant_hold_r <= bus_grant_hold_mux;
    end
  end // bus_grant_hold_r_PROC

  // If current transfer was not accepted, select the hold
  // register version of the bus grant index, as opposed to the 
  // one coming direct (possibly registered) from the designware
  // arbiter.
  // For some channels we want to lock arbitration to a client until
  // a burst has completed.
  assign bus_grant_hold_mux = (   tx_not_accepted_r 
                                | (burst_tx_not_cpl_r & ARB_BURST_LOCK)
                              )
                              ? bus_grant_hold_r
                              : bus_grant_arbpl;

  // Decode one hot granted bus specificaly for multi cycle arbitration.
  // For multi cycle arbitration we cannnot use the one hot
  // grant output of the arbiter itself. This is because the
  // arbiter inputs are held static during the arbitraton period
  // so the arbiter outputs do not relate directly to whether or
  // not the granted client is requesting or not. Instead we
  // decode bus_grant_o from the arbiter grant index. This way we can 
  // forward a t/x for the default granted client even if the client
  // was not requesting at the start of the arbration window.
  DW_axi_busdemux
  
  #(NC,        // Number of buses to mux between.
    1,         // Width of bus input to the mux.
    LOG2_NC    // Width of select line.
  ) 
  U_bus_grant_mca_demux (
    .sel   (grant_index_hold_mux),
    .din   (1'b1),
    .dout  (bus_grant_mca)
  );
  
  
  // Connect module outputs.
  assign grant_o         = grant_hold_mux;

  assign bus_grant_o     = MCA_EN
                           ? bus_grant_mca
                           : bus_grant_hold_mux;

  assign grant_p_local_o = grant_index_hold_mux;


endmodule
