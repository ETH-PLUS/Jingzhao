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
// File Version     :        $Revision: #7 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_sp_wrorder.v#7 $ 
**
** ---------------------------------------------------------------------
**
** File     : DW_axi_sp_wrorder.v
//
//
** Created  : Wed Jul 27 16:07:30 MEST 2005
** Modified : $Date: 2020/03/22 $
** Abstract : This block is responsible for maintaining AXI write
**            ordering rules. It sits in front of the write data
**            channel arbiter in the slave port and decides which
**            masters may request to the arbiter depending on the
**            write ordering rules.
**
** ---------------------------------------------------------------------
*/

module DW_axi_sp_wrorder (
  // Inputs - System.
  aclk_i,
  aresetn_i,

  // Inputs - Master ports.
  bus_valid_i,
  bus_priority_i,

  // Inputs - Write address channel.
  issued_tx_i,
  issued_mstnum_i,

  // Inputs - Write data channel internal.
  ready_i,
  cpl_tx_i,

  // Inputs - Arbiter.
  grant_m_local_i,

  // Outputs - Shared write data channel.
  firstpnd_mst_o,
  fifo_empty_o,
  firstpnd_fifo_pop_o,

  // Outputs - Arbiter.
  req_o,
  bus_mst_req_o,
  bus_mst_priorities_o
);


//----------------------------------------------------------------------
// MODULE PARAMETERS.
//----------------------------------------------------------------------
  parameter NUM_VIS_MP = 4; // Number of visible master ports.

  parameter LOG2_NUM_VIS_MP = 4; // Log base 2 of number of visble
                                 // master ports.

  parameter PL_ARB = 0; // 1 if arbiter outputs are pipelined.

  parameter WID = 2; // Write interleaving depth.

  parameter MAX_FAC = 4; // Maximum number of active/outstanding
                         // commands that may be forwarded to the
                            // external slave.

  parameter LOG2_MAX_FAC = 2;

  parameter BUS_PRIORITY_W = 2; // Width of input priorities bus.

  parameter BUS_PRIORITY_WID_W = 2; // Width of the per write
                                    // interleaving depth priority bus.

  parameter BUS_MST_REQ_W = 2; // Width of bus containing master
                               // numbers which ware allowed to access
                                  // the arbiter.

  // Does W channel to attached slave (dedicated) have a shared to
  // dedicated link.
  parameter HAS_W_SHRD_DDCTD_LNK = 0;

  // Is multi cycle arbitration enabled for this slaves W channel.
  parameter MCA_EN = 0;

//----------------------------------------------------------------------
// LOCAL MACROS.
//----------------------------------------------------------------------

  // Width of bus containing local master numbers for the write
  // interleaving slots.
  `define BUS_SLOT_MST_W (LOG2_NUM_VIS_MP*WID)

  // Number of input busses to each mst require mux.
  `define MST_REQ_MUX_NUM_DIN 2

  // Width of master require bus mux data in bus.
  `define MST_REQ_BMUX_DIN_W (`MST_REQ_MUX_NUM_DIN*LOG2_NUM_VIS_MP)

  // Width of master require multi bus mux data in bus.
  `define MST_REQ_MBMUX_DIN_W (`MST_REQ_BMUX_DIN_W*WID)

//----------------------------------------------------------------------
// PORT DECLARATIONS
//----------------------------------------------------------------------

  // Inputs - System.
  input aclk_i;    // AXI system clock.
  input aresetn_i; // AXI system reset.


  // Inputs - Master ports.
  input [NUM_VIS_MP-1:0]     bus_valid_i; // Valid signals from all
                                          // visible master ports.

  input [BUS_PRIORITY_W-1:0] bus_priority_i; // Priority values for all
                                             // visible masters.


  // Inputs - Write address channel.
  input issued_tx_i; // Asserted whenever a write transaction/command
                     // has been issued by the external slave.

  // Number of the master who's transaction was issued by the external
  // slave. Note : local master number.
  input [LOG2_NUM_VIS_MP-1:0] issued_mstnum_i;

  // Inputs - Write data channel internal.
  input ready_i; // Used to decode when a write transfer has been
                 // accepted by the external slave.

  input cpl_tx_i; // Asserted whenever a write transaction has completed
                  // on the write data channel.

  // Inputs - Arbiter.
  input [LOG2_NUM_VIS_MP-1:0] grant_m_local_i; // Granted local master
                                               // number.


  // Outputs - Shared write data channel.
  // Local master number whos' first transaction beat is next.
  output [LOG2_NUM_VIS_MP-1:0] firstpnd_mst_o;
  output fifo_empty_o;
  output firstpnd_fifo_pop_o; // Pop for first pending master fifo.

  // Outputs - Arbiter.
  // This signal is unused if there is only single master port connected to this slave port
  output [WID-1:0] req_o; // Arbiter request outputs.

  // Bus containing the master numbers of masters which are
  // being allowed to access the arbiter.
  output [BUS_MST_REQ_W-1:0] bus_mst_req_o;

  // Bus containing the priority values of masters which this
  // block is allowing to access the arbiter.
  output [BUS_PRIORITY_WID_W-1:0] bus_mst_priorities_o;


  //--------------------------------------------------------------------
  // REGISTER VARIABLES.
  //--------------------------------------------------------------------
  // This signal is unused if there is only single master port connected to this slave port 
  reg [`BUS_SLOT_MST_W-1:0] bus_slot_mst_r; // Local master numbers for
                                            // the write interleaving
                                                 // slots.

  reg [WID-1:0] bus_slot_act_r; // Slot active bits for the write
                                // interleaving slots.

  // Freeslot holding signals.
  reg  [WID-1:0] freeslot_oh_hld_r; // Hold register.
  wire [WID-1:0] freeslot_oh_hld;   // Mux between hold reg. signal and
                                    // original signal.


  reg [WID-1:0] bus_slot_act_nxt; // Next state signal for
                                  // bus_slot_act_r.

  reg [WID-1:0] slot_newtx_oh; // One hot signal (or 0) signal with
                               // a bit for each write interleaving
                                  // slot. If a slots bit is asserted
                                 // there is a new transaction being
                                  // loaded into that slot.

  reg [WID-1:0] slot_cpltx_oh; // One hot signal (or 0) signal with
                               // a bit for each write interleaving
                                  // slot. If a slots bit is asserted
                                  // the transaction stored in that slot
                                  // has completed.

  reg mstnum_active; // Asserted if the firstpnd_mst has yet
                     // to complete a previous transaction.

  reg [WID-1:0] freeslot_oh; // Bit for each write interleaving slot
                             // asserted if that slot is the lowest
                                // numbered free slot i.e. active bit
                                // deasserted.

  reg [`MST_REQ_MBMUX_DIN_W-1:0] mst_req_mux_din; // Data in busses for
                                                  // the master require
                                                        // mux.



  //--------------------------------------------------------------------
  // WIRE VARIABLES.
  //--------------------------------------------------------------------
  // These signals are used for write data channel instantations and not for read channels. hence they are unused.
  wire pop; // Active high pop signal.

  wire pop_n; // Pop signal to the fifo.

  wire push_n; // Push signal to the fifo.

  wire [LOG2_NUM_VIS_MP-1:0] firstpnd_mst; // Local master number who's
                                           // first transaction beat
                                                // is next.

  // Selected between issued_mstnum_i and firstpnd_mst from the pending
  // master FIFO.
  wire [LOG2_NUM_VIS_MP-1:0] firstpnd_mst_mux;

  wire [WID-1:0] bus_slot_valid; // Valid signals selected by the master
                                 // number stored in each write
                                     // interleaving slot or the
                                     // firstpnd_mst.

  wire fifo_empty; // Asserted when the first t/x pending fifo is
                   // empty.

  wire nxt_fifo_empty; // Register next state version of fifo_empty.

  wire fifo_empty_tmo; // fifo_empty or nxt_fifo_empty depending on
                       // which timing option is configured.

  wire [WID-1:0] bus_slot_act_tmo; // bus_slot_act_r or bus_slot_act_nxt
                                   // depending on configured timing
                                       // option.

  reg firstpnd_wait_acc_r; // Asserted when a master is waiting to have
                           // its first data beat accepted.


  // Asserted when a master number issued from AW does not need to be
  // stored in the first master pending fifo here.
  wire can_send_vld_frm_aw;

  // Asserted if a master which is currently active in a write data
  // interleaving slot is requesting.
  reg slot_act_mst_req;

  // Wires for unconnected sub module outputs ports.
  wire almost_empty_unconn;
  wire half_full_unconn;
  wire almost_full_unconn;
  wire full_unconn;
  wire error_unconn;
  //--------------------------------------------------------------------


  // Generate push signal to the fifo by inverting issued_tx_i.
  assign push_n = ~issued_tx_i
                  | can_send_vld_frm_aw;

  // When the write interleaving depth is 1 and there is no link from
  // the shared write data channel, we do not need to wait until the
  // master number of the t/x issued from AW is stored in the fifo here
  // before we can forward a valid for that master.
  // If the master is already requesting when issued_tx_i asserts,
  // and the master is not previously active, and there is a free
  // interleaving slot, and the fifo is empty, we can send the valid
  // to the slave immediately - thereby removing 1 dead cycle from the
  // W channel.
  // The reason this is not supported for configs with WID>1 or with a
  // link to the shared W channel (without pipelining in each case) is that
  // that 2 arbiters would be in series, which would result in very long
  // logic paths.
  // Not supported for slaves with multi cycle arbitration enabled on W
  // channel - as this removes the guarantee that if we bypass the
  // first pending master fifo to issue the t/x immediately the request
  // will be granted.
  assign can_send_vld_frm_aw =
    (   issued_tx_i
      & (|(bus_valid_i & (1'b1 << issued_mstnum_i)))
      & (!mstnum_active)
      & (|freeslot_oh_hld)
      & fifo_empty
        // If the write interleaving depth is > 1, then do not assert
        // this signal if other currently active writes are also
        // requesting - as it is possible that the master requesting
        // for the t/x just issued from the AW channel may not
        // get granted in this case.
      & (~(slot_act_mst_req & (WID>1)))
      & ((WID==1) | (`AXI_AW_PL_ARB==1))
      & ((HAS_W_SHRD_DDCTD_LNK==0) | (`AXI_AW_SHARED_PL==1))
      & (`AXI_REG_AW_W_PATHS==0)
      & (MCA_EN==0)
    );

  
  // Decode if any active slot masters are requesting.
  always @(*) begin : slot_act_mst_req_PROC
    integer slotnum;
    integer mstbit;
    reg [LOG2_NUM_VIS_MP-1:0] slot_mst;

    slot_act_mst_req = 1'b0;

    for(slotnum=0 ; slotnum<=(WID-1) ; slotnum=slotnum+1) begin
      // Master number for this write interleaving slot.
      // spyglass disable_block SelfDeterminedExpr-ML
      // SMD: Self determined expression found
      // SJ : The expression indexing the vector/array will never exceed the bound of the vector/array.        
      for(mstbit=0 ; mstbit<=(LOG2_NUM_VIS_MP-1) ; mstbit=mstbit+1)
      begin
        slot_mst[mstbit]
         = bus_slot_mst_r[(LOG2_NUM_VIS_MP*slotnum)+mstbit];
      end
      // spyglass enable_block SelfDeterminedExpr-ML      

      slot_act_mst_req
        =   slot_act_mst_req        
          | ((|(bus_valid_i & (1'b1 << slot_mst))) & bus_slot_act_r[slotnum]);
    end
  end // slot_act_mst_req_PROC


  // Generate active high pop signal.
  // Pop if
  // - First transaction pending master is granted by the arbiter.
  //   and this transfer is accepted by the external slave and
  //   this master does not already have an active (uncompleted)
  //   transaction (i.e. if this is the case then the current transfer
  //   is the first beat of a burst).
  assign pop = (grant_m_local_i==firstpnd_mst)
               & ready_i
                & (!mstnum_active)
               // Since a valid can now be forwarded without going
               // through the fifo, block a pop when the fifo is empty
               // in the configurations were this can occur.
               & (  (!fifo_empty)
                  | (~(   ((WID==1) | (`AXI_AW_PL_ARB==1))
                       & (  (HAS_W_SHRD_DDCTD_LNK==0)
                          | (`AXI_AW_SHARED_PL==1)
                         )
                       & (MCA_EN==0)
                       & (`AXI_REG_AW_W_PATHS==0)
                     ))
                 );

  // Generate active low pop signal.
  assign pop_n = ~pop;

  // Required in DW_axi_sp_wdatach.
  assign firstpnd_fifo_pop_o = pop; 

  //--------------------------------------------------------------------
  // Instantiate first beat pending fifo.
  //--------------------------------------------------------------------
//spyglass disbale_block W528
//SMD: A signal or variable is set but never read
//SJ: Unconnected/Not required ports of FIFO 
  DW_axi_fifo_s1_sf
  
  #(LOG2_NUM_VIS_MP, // Word width.
    MAX_FAC,         // Word depth.
    1,               // ae_level, don't care.
    1,               // af_level, don't care.
    0,               // err_mode, don't care.
    0,               // Reset mode, asynch. reset including memory.
    LOG2_MAX_FAC     // Fifo address width.
  )
  U_DW_axi_fifo_s1_sf (
    .clk            (aclk_i),
    .rst_n          (aresetn_i),
    .init_n         (1'b1), // Synchronous reset, not used.

    .push_req_n     (push_n),
    .data_in        (issued_mstnum_i),

    .pop_req_n      (pop_n),
    .data_out       (firstpnd_mst),

    .diag_n         (1'b1), // Never using diagnostic mode.

    .empty          (fifo_empty),
    .nxt_empty      (nxt_fifo_empty),

    // Unconnected outputs, not required here.
    .almost_empty   (almost_empty_unconn),
    .half_full      (half_full_unconn),
    .almost_full    (almost_full_unconn),
    .full           (full_unconn),
    .error          (error_unconn)
  );
//spyglass enabale_block W528

  // If the fifo is empty take the first pending master number
  // direct from the AW channel.
  // The reason this is not supported for configs with WID>1 or with a
  // link to the shared W channel is that that 2 arbiters would be in
  // series in this case (if pipelining was not present), which would
  // result in very long logic paths.  `AXI_REG_AW_W_PATHS macro is
  // used to disable this feature.
  assign firstpnd_mst_mux
    = (  fifo_empty
       & ((WID==1) | (`AXI_AW_PL_ARB==1))
       & ((HAS_W_SHRD_DDCTD_LNK==0) | (`AXI_AW_SHARED_PL==1))
       & (MCA_EN==0)
       & (`AXI_REG_AW_W_PATHS==0)
      )
      ? issued_mstnum_i
      : firstpnd_mst;


  //--------------------------------------------------------------------
  // Decode when there is a new transaction for each write interleaving
  // slot.
  //--------------------------------------------------------------------
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue.
  always @(*)
  begin : slot_newtx_oh_PROC
    integer slotnum;

    slot_newtx_oh = {WID{1'b0}};

    for(slotnum=0 ; slotnum<=(WID-1) ; slotnum=slotnum+1) begin

      // If this slot is the lowest numbered free slot, and we
      // are popping a transaction from the first tx pending queue
      // or taking the master number direct from the AW channel,
      // and the transaction is not completing in the same cycle
      // (i.e. single beat burst) then there is a new transaction
      // for this slot.
      if(  freeslot_oh_hld[slotnum]
         & (  (pop & (!cpl_tx_i))
              // If we load a write interleaving slot on assertion of
              // can_send_vld_frm_aw, then if the arbiter pipeline
              // stage is enabled, we don't block the load if cpl_tx_i
              // is asserted. If PL_ARB==1, and cpl_tx_i and
              // can_send_vld_frm_aw are asserted at the same time,
              // the t/x for which can_send_vld_frm_aw is asserted is
              // not the one for whom cpl_tx_i is asserting.
            | (can_send_vld_frm_aw & ((!cpl_tx_i) | (PL_ARB == 1)))
           )
        )
      begin
        slot_newtx_oh[slotnum] = 1'b1;
      end

    end

  end // slot_newtx_oh_PROC
  //spyglass enable_block W415a


  //--------------------------------------------------------------------
  // Decode when the transaction in each slot has completed.
  //--------------------------------------------------------------------
  always @(*)
  begin : slot_cpltx_oh_PROC
    integer slotnum;
    integer mstbit;

    reg [LOG2_NUM_VIS_MP-1:0] slot_mst;

    slot_cpltx_oh = {WID{1'b0}};

    for(slotnum=0 ; slotnum<=(WID-1) ; slotnum=slotnum+1) begin

      // spyglass disable_block SelfDeterminedExpr-ML
      // SMD: Self determined expression found
      // SJ : The expression indexing the vector/array will never exceed the bound of the vector/array.        
      // Master number for this slot.
      for(mstbit=0 ;
          mstbit<=(LOG2_NUM_VIS_MP-1) ;
           mstbit=mstbit+1
          )
      begin
        slot_mst[mstbit]
         = bus_slot_mst_r[(LOG2_NUM_VIS_MP*slotnum)+mstbit];
      end
      // spyglass enable_block SelfDeterminedExpr-ML      

      // If the master number in this slot matches grant_m_local_i and
      // cpl_tx_i is asserted, then the transaction in this slot has
      // completed.
      // Only assert for active slots. Related with change for
      // STAR 9000301295. Previously we would assert this signal for
      // every slot with a master number that matches grant_m_local_i.
      // Since that update, one slot can load in the same cycle that
      // another slot is cleared, which required this change.
      if(  (slot_mst==grant_m_local_i)
         & bus_slot_act_r[slotnum]
         & cpl_tx_i
        )
      begin
        slot_cpltx_oh[slotnum] = 1'b1;
      end

    end

  end // slot_cpltx_oh_PROC

  integer slotnum;
  integer mstbit;
  //--------------------------------------------------------------------
  // Master number registers for the write interleaving slots.
  //--------------------------------------------------------------------
  always @(posedge aclk_i or negedge aresetn_i)
  begin : bus_slot_mst_r_PROC
    if(!aresetn_i) begin
      bus_slot_mst_r <= {`BUS_SLOT_MST_W{1'b0}};
    end else begin
      for(slotnum=0 ; slotnum<=(WID-1) ; slotnum=slotnum+1) begin

         // If there is a new transaction for this slot load the
         // slots master number register width the first pending
         // master number.
        if(slot_newtx_oh[slotnum]) begin

          for(mstbit=0 ;
               mstbit<=(LOG2_NUM_VIS_MP-1) ;
               mstbit=mstbit+1
              )
           begin
            bus_slot_mst_r[(LOG2_NUM_VIS_MP*slotnum)+mstbit]
             <= firstpnd_mst_mux[mstbit];
          end

         end // slot_newtx_oh

      end // slotnum

    end // !aresetn_i

  end // bus_slot_mst_r_PROC


  //--------------------------------------------------------------------
  // Slot active registers for the write interleaving slots.
  // Broken into next state and register processes because in some
  // cases we will use the next state version or registered version
  // depending on which timing option has been configured.
  //--------------------------------------------------------------------
  always @(posedge aclk_i or negedge aresetn_i)
  begin : bus_slot_act_r_PROC
    if(!aresetn_i) begin
      bus_slot_act_r <= {WID{1'b0}};
    end else begin
      bus_slot_act_r <= bus_slot_act_nxt;
    end
  end // bus_slot_act_r_PROC


  //--------------------------------------------------------------------
  // Calculate nxt state of bus_slot_act_r.
  //--------------------------------------------------------------------
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue.
  always @(*)
  begin : bus_slot_act_nxt_PROC
    integer slotnum;

    bus_slot_act_nxt = {WID{1'b1}};

    for(slotnum=0 ; slotnum<=(WID-1) ; slotnum=slotnum+1) begin

      case({slot_newtx_oh[slotnum], slot_cpltx_oh[slotnum]})

        // No transaction accepted and none completed OR
         // transaction accepted and completed in the same cycle
         // implies no change to active bit for this slot.
         2'b00,
         2'b11  : begin
          bus_slot_act_nxt[slotnum] = bus_slot_act_r[slotnum];
         end

         // Transaction completed, set active bit for this slot
         // to 0.
         2'b01 : begin
          bus_slot_act_nxt[slotnum] = 1'b0;
         end

         // New transaction accepted for this slot, set active bit
         // for this slot to 1.
         2'b10 : begin
          bus_slot_act_nxt[slotnum] = 1'b1;
         end

      endcase

    end // if(!aresetn_i

  end // bus_slot_act_nxt_PROC


  //--------------------------------------------------------------------
  // Need to detect if the current firstpnd_mst has yet to complete
  // a previous transaction, this affects wether or not we will
  // interpret a transfer from this master as the first beat in a burst
  // or not.
  //--------------------------------------------------------------------
  always @(*)
  begin : mstnum_active_PROC

    integer slotnum;
    integer mstbit;

    reg [LOG2_NUM_VIS_MP-1:0] slot_mst;
    reg [WID-1:0]             slot_firstpnd_act_oh;

    mstnum_active = 1'b0;


    for(slotnum=0 ; slotnum<=(WID-1) ; slotnum=slotnum+1) begin

      // spyglass disable_block SelfDeterminedExpr-ML
      // SMD: Self determined expression found
      // SJ : The expression indexing the vector/array will never exceed the bound of the vector/array.        
      // Master number for this write interleaving slot.
      for(mstbit=0 ; mstbit<=(LOG2_NUM_VIS_MP-1) ; mstbit=mstbit+1)
      begin
        slot_mst[mstbit]
         = bus_slot_mst_r[(LOG2_NUM_VIS_MP*slotnum)+mstbit];
      end
      // spyglass enable_block SelfDeterminedExpr-ML      

      // The firstpnd_mst_mux has an active transaction in this slot if
      // firstpnd_mst_mux matches the master number stored in the slot
      // and the active bit of the slot is asserted.
      slot_firstpnd_act_oh[slotnum] = (slot_mst==firstpnd_mst_mux)
                                      && bus_slot_act_r[slotnum];
    end // for(slotnum=

    // mstnum_active asserted if firstpnd_mst_mux is active in any slot.
    mstnum_active = |slot_firstpnd_act_oh;

  end // mstnum_active_PROC


  //--------------------------------------------------------------------
  // Decode which write interleaving slot is the lowest numbered free
  // slot i.e. slots active bit is deasserted.
  // Note that we do not assert any bit of this signal if the next
  // first beat pending master is already active. This is to avoid
  // forwarding the valid signal from the same master on 2 different
  // request signals to the arbiter.
  //--------------------------------------------------------------------
  always @(*)
  begin : freeslot_oh_PROC

    integer slotnum;

    reg found; // Bit used to signal when we have found the first free
               // write interleaving slot.

    freeslot_oh = {WID{1'b0}};
    found       = 1'b0;

    for(slotnum=0 ; slotnum<=(WID-1) ; slotnum=slotnum+1) begin
      // If this slot is free and we have not already found a free slot
      // and the next first beat pending master is not already active
      // assert this bit of freeslot_oh.
      if(!bus_slot_act_r[slotnum] && (!found) && (!mstnum_active)) begin
        freeslot_oh[slotnum] = 1'b1;
         found = 1'b1;
      end
    end

  end // freeslot_oh_PROC
  //spyglass enable_block W415a

  //--------------------------------------------------------------------
  // The signal freeslot_oh will change dynamicaly as write interleaving
  // slots become free. It will always reflect the lowest numbered
  // free slot.
  //
  // This means we cannot use freeslot_oh to decode what arbiter client
  // port to request on.
  //
  // The danger is that the first pending master could request on say
  // arbiter request[2], and when another masters t/x is finished it
  // could be pushed into write interleaving slot 0 (now the lowest
  // numbered slot) and request on request[0]. But the arbiter may have
  // granted to this master on request[2], but now all the signals for
  // this master are routed to client 0 signals, and since the arbiter
  // outputs are static for X cycles, it will be choosing the wrong
  // client, resulting in erroneous behaviour.
  //
  // To avoid this, we decode another version of freeslot_oh called
  // freeslot_oh_hld, which will keep a master requesting on the same
  // client port for the duration of the t/x.
  //
  // Note the logic here only has to hold the client port
  // (equivalent to interleaving slot) until the firstpnd_mst is popped
  // from the first beat pending fifo, after that point it will
  // be kept in the same interleaving slot until it has completed.
  //--------------------------------------------------------------------
  // Decode when a master is waiting to have its first data beat
  // accepted.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : firstpnd_wait_acc_r_PROC
    if(~aresetn_i) begin
      firstpnd_wait_acc_r <= 1'b0;
    end else begin
      firstpnd_wait_acc_r <=   // When the below condition is true
                                // there is a master waiting at the head
                                  // of the fifo whos next data beat will
                                  // be the first beat of a t/x.
                                  ((|freeslot_oh) & (~fifo_empty_tmo))
                                  // No longer waiting once the
                                  // firstpnd_mst has been popped from the
                                  // firstpnd_mst fifo.
                               & (~pop);
    end
  end // firstpnd_wait_acc_r_PROC


  // Use registered freeslot signal while we are waiting for a beat
  // from a first pending master to be accepted.
  assign freeslot_oh_hld = firstpnd_wait_acc_r
            ? freeslot_oh_hld_r
            : freeslot_oh;


  // Hold register used in generating freeslot_oh_hld.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : freeslot_oh_hld_r_PROC
    if(~aresetn_i) begin
      freeslot_oh_hld_r <= {WID{1'b0}};
    end else begin
      freeslot_oh_hld_r <= freeslot_oh_hld;
    end
  end // freeslot_oh_hld_r


  //--------------------------------------------------------------------
  // Construct data in bus for master require mux.
  // The multibusmux block will have a mux for each write interleaving
  // depth, each mux will have 2 inputs {firstpnd_mst_mux, slotX_mux}.
  // If a slot is free the mux will select firstpnd_mst_mux otherwise it
  // will select the master number stored in the slot.
  //--------------------------------------------------------------------
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue.
  always @(*)
  begin : mst_req_mux_din_PROC

    integer slotnum;
    integer mstbit;

    integer muxbit;
    integer busnum;

    reg [LOG2_NUM_VIS_MP-1:0] slot_mst;

    mst_req_mux_din = {`MST_REQ_MBMUX_DIN_W{1'b0}};

    for(slotnum=0 ; slotnum<=(WID-1) ; slotnum=slotnum+1) begin

      // Master number for this write interleaving slot.
      // spyglass disable_block SelfDeterminedExpr-ML
      // SMD: Self determined expression found
      // SJ : The expression indexing the vector/array will never exceed the bound of the vector/array.        
      // Master number for this write interleaving slot.
      for(mstbit=0 ; mstbit<=(LOG2_NUM_VIS_MP-1) ; mstbit=mstbit+1) begin
        slot_mst[mstbit]
        = bus_slot_mst_r[(LOG2_NUM_VIS_MP*slotnum)+mstbit];
      end
      // spyglass enable_block SelfDeterminedExpr-ML      

      for(busnum=0 ;
          busnum<=(`MST_REQ_MUX_NUM_DIN-1) ;
           busnum=busnum+1
          )
      begin

        if(busnum==0) begin

           // First mux input, master number for this slot.
          for(mstbit=0 ;
               mstbit<=(LOG2_NUM_VIS_MP-1) ;
               mstbit=mstbit+1
              )
           begin
            mst_req_mux_din[(  LOG2_NUM_VIS_MP
                               *(slotnum*`MST_REQ_MUX_NUM_DIN)
                            )
                               +(LOG2_NUM_VIS_MP*busnum)
                               +mstbit]
            = slot_mst[mstbit];
          end

         end else begin

           // Second mux input, firstpnd_mst.
          for(mstbit=0 ;
               mstbit<=(LOG2_NUM_VIS_MP-1) ;
               mstbit=mstbit+1
              )
           begin
            mst_req_mux_din[(LOG2_NUM_VIS_MP
                              *(slotnum*`MST_REQ_MUX_NUM_DIN)
                            )
                               +(LOG2_NUM_VIS_MP*busnum)
                               +mstbit]
            = firstpnd_mst_mux[mstbit];
          end

         end

      end // for(busnum=0 ;

    end // for(slotnum=0

  end // mst_req_mux_din_PROC
  //spyglass enable_block W415a

  

  // Select which masters are allowed forward valid signals to
  // the channel arbiter.
  DW_axi_multibusmux
  
  #(`MST_REQ_MUX_NUM_DIN, // Number of inputs to the mux.
    LOG2_NUM_VIS_MP,      // Width of each input to the mux.
    1,                    // Width of select line for the mux.
    WID                   // Number of busmuxes to implement.
  )
  U_DW_axi_multibusmux_mstreq (
    .sel  (freeslot_oh_hld),
    .din  (mst_req_mux_din),
    .dout (bus_mst_req_o)
  );


  // Use the master numbers in bus_mst_req_o, to select valid
  // signals from bus_valid_i. 0 to WID-1 muxes.
  DW_axi_multibusmux
  
  #(NUM_VIS_MP,        // Number of inputs to the mux.
    1,                 // Width of each input to the mux.
    LOG2_NUM_VIS_MP,   // Width of select line for the mux.
    WID                // Number of busmuxes to implement.
  )
  U_DW_axi_multibusmux_valid (
    .sel  (bus_mst_req_o),
    .din  ({WID{bus_valid_i}}),
    .dout (bus_slot_valid)
  );


  //--------------------------------------------------------------------
  // Because of the signal timing if PL_ARB=1, there is a condition we
  // need to address where back2back transactions from the
  // same master occur where the first t/x causes the second to be
  // masked. For example if the first completed the write data part of
  // a transaction, it will deassert the active bit of the related
  // write interleaving slot. The deasserted active bit should cause
  // the second valid to be masked out, but because of the register
  // after the arbiter this will happen a cycle too late, so we need
  // to use the the next state version of the bus_slot_act_r register
  // to avoid masking too late for registered timing options.
  assign bus_slot_act_tmo = (PL_ARB==0)
                            ? bus_slot_act_r
                               : bus_slot_act_nxt;

  // A similar situation exists for the fifo_empty signal.
  // We have to use the pre register version of fifo_empty for the
  // back2back t/x case where the first t/x empties the fifo so the
  // second should be masked. BUT -> nxt_fifo_empty will deassert too
  // quickly for us - i.e. a new t/x is pushed in , nxt_fifo_empty
  // could deassert combinatorially but the master number will not
  // be available on the fifo's read data out signal until after the
  // clock edge. So for registered timing options we use an OR of
  // the pre and post register versions of fifo_empty.
  assign fifo_empty_tmo = (PL_ARB==0)
                          ? fifo_empty
                             : (nxt_fifo_empty | fifo_empty);
  //--------------------------------------------------------------------


  //--------------------------------------------------------------------
  // Qualify bus_slot_valid with the status of the write interleaving
  // slots and the first tx pending queue.
  //--------------------------------------------------------------------
  // We will only forward a valid signal for a write interleaving slot
  // if that slot has an active transaction OR if that slot is
  // the free slot and the fifo is not empty OR we can send a valid
  // straight from the AW tx_issued_* signals.
  // Because the idmask block in the master port registers a
  // transaction on issue rather than on acceptance a write valid
  // can reach here for a transaction that hasn't been accepted yet,
  // so we need to qualify freeslot_oh_hld with fifo_empty_tmo so we
  // don't forward valid signals from local master 0 just because
  // firstpnd_mst will be 0 when the first t/x pending fifo is empty.
  // In registered timing modes, if we are poping from the first
  // t/x pending fifo we will not forward the valid signal from
  // the master pointed to by firstpnd_mstnum. Because of the
  // register after the arbiter (PL_ARB=1), a new valid could arrive
  // for that master while we are waiting for firstpnd_mstnum to
  // update, so for the cycle where we are poping from the fifo
  // we should avoid forwarding valids for firstpnd_mstnum,
  // as this valid has already been accepted at this point.
  assign req_o =   (   bus_slot_act_tmo
                     | (   freeslot_oh_hld
                         & {WID{!fifo_empty_tmo | can_send_vld_frm_aw}}
                            & {WID{(pop_n || (PL_ARB == 0))}}
                         )
                     )
                 & bus_slot_valid;
  //--------------------------------------------------------------------


  // Select master priorities to forward to the channel arbiter
  // depending on which masters we are allowing to access the
  // arbiter. 0 to WID-1 muxes.
  DW_axi_multibusmux
  
  #(NUM_VIS_MP,           // Number of inputs to the mux.
    `AXI_MST_PRIORITY_W,  // Width of each input to the mux.
    LOG2_NUM_VIS_MP,      // Width of select line for the mux.
    WID                   // Number of busmuxes to implement.
  )
  U_DW_axi_multibusmux_prior (
    .sel  (bus_mst_req_o),
    .din  ({WID{bus_priority_i}}),
    .dout (bus_mst_priorities_o)
  );


  // Need to tell the shared write data channel when it is next to send
  // a first beat here. Avoids a deadlock condition with the shared
  // to dedicated link. Use empty bit to avoid signalling that the
  // shared layer is next, when the fifo is empty and the data out
  // happens to point to the shared layer.
  assign firstpnd_mst_o = firstpnd_mst_mux;
  assign fifo_empty_o = fifo_empty;

endmodule
