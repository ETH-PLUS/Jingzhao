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
// File Version     :        $Revision: #12 $ 
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_irs.v#12 $ 
**
** ---------------------------------------------------------------------
**
** File     : DW_axi_irs.v
//
//
** Created  : Tue May 24 17:09:09 MEST 2005
** Modified : $Date: 2020/03/22 $
** Abstract : This block implements the internal register slice pipeline
**            for DW_axi. The key difference between this block and a
**            standard register slice is that this block operates on a
**            bus of valid signals. This bus of valid signals comes from
**            a decoding element in the master element that sends the 
**            t/x.
**            Each valid in the bus is for a particular slave element
**            (master port or slave port in DW_axi).
**
** ---------------------------------------------------------------------
*/

module DW_axi_irs (
  // Inputs - System.
  aclk_i,
  aresetn_i,

  // Inputs - Payload source.
  bus_valid_i,
  valid_i,
  shrd_ch_req_i,
  payload_i,
  mask_valid_i,
  
  // Outputs - Payload source.
  ready_o,

  // Inputs - Payload destination.
  ready_i,

  // Outputs - Channel source.
  id_o,       
  local_slv_o,

  // Outputs - Payload destination.
  bus_valid_o,
  shrd_ch_req_o,
  payload_o
);

//----------------------------------------------------------------------
// MODULE PARAMETERS.
//----------------------------------------------------------------------
  parameter TMO = 0; // Timing option that this block will implement.
                     // TMO = 0 => Pass through mode.
                     // TMO = 1 => Forward register mode.
                     // TMO = 2 => Full register mode.
  
  parameter N = 2; // Number of valid signals that this block 
                   // accomadates.

  parameter PL_ARB = 0; // 1 if channel arbiter is pipelined.       

  parameter PYLD_W = `AXI_AR_PYLD_M_W; // Width of payload signals in 
                                       // this block.    

  parameter LOG2_NUM_VIS = 1; // Log base 2 of number of visible 
                              // slave ports.
                                 
  parameter ID_W = 1; // Master ID width.                                 

  parameter DO_MASKING = 0; // 1 if this block should perform valid
                            // masking and send back id and local
                            // slave number.

  parameter ID_RHS = 0; // Left hand bit index of ID in payload.
  parameter ID_LHS = 0; // Right hand bit index of ID in payload.

  parameter W_CH = 0; // Pass a 1 if this module is being used in a 
                      // W channel.

  parameter SHARED_VIS = 0; // 1 if shared layer signals should be
                            // generated.
                            
//----------------------------------------------------------------------
// PORT DECLARATIONS
//----------------------------------------------------------------------
  // Inputs - System.
  input aclk_i;    // AXI system clock.
  input aresetn_i; // AXI system reset.

  // Inputs - Payload source.
  input [N-1:0]      bus_valid_i; 
  input              valid_i; // Used to avoid requiring OR reduction
                              // on bus_valid_i.
  input              mask_valid_i;
  input              shrd_ch_req_i;
  input [PYLD_W-1:0] payload_i;

  // Outputs - Payload source.
  output ready_o;


  // Inputs - Payload destination.
  input ready_i;

  // Outputs - MP address channel.
  output [ID_W-1:0] id_o;       
  output [LOG2_NUM_VIS-1:0] local_slv_o;

  // Outputs - Payload destination.
  output [N-1:0]      bus_valid_o; 
  output              shrd_ch_req_o;
  output [PYLD_W-1:0] payload_o;


  //--------------------------------------------------------------------
  // FORWARD REGISTER MODE LOGIC
  //--------------------------------------------------------------------
  // Registers the forward (valid master to valid slave) only.
  // Uses a single buffer stage to avoid dead cycles due to the register
  // in the handskaking paths.
  //--------------------------------------------------------------------

  //--------------------------------------------------------------------
  // Forward register mode reg variables.
  //--------------------------------------------------------------------
  reg [N-1:0]      frwd_bus_valid_r;
  wire [N-1:0]     frwd_bus_valid_mskd;
  reg              frwd_mask_valid_r;
  reg              frwd_shrd_ch_req_r;
  wire             frwd_shrd_ch_req_mskd;
  reg [PYLD_W-1:0] frwd_payload_r;

  // Mask generation feedback signals in forward register mode.
  wire [ID_W-1:0]         frwd_id;       
  reg  [LOG2_NUM_VIS-1:0] frwd_local_slv;
  wire [LOG2_NUM_VIS-1:0] frwd_local_slv_w;

  //--------------------------------------------------------------------
  // Forward register mode wire variables.
  //--------------------------------------------------------------------
  wire [N-1:0] frwd_bus_valid_mux;  // Mux between registered bus valids
                                    // and input bus valids.

  wire frwd_shrd_ch_req_mux;  // Mux between registered shared request 
                              // and input shared req.
  
  wire frwd_ready_o; // ready to source for forward register mode.
  wire [LOG2_NUM_VIS-1:0] dummy_wire; 


   
  assign dummy_wire =  {LOG2_NUM_VIS{1'b0}};

  //--------------------------------------------------------------------
  // Valid mux and hold register.
  // Select valid_i if we are sending ready_o == 1'b1 to the 
  // payload source.
  //--------------------------------------------------------------------
  assign frwd_bus_valid_mux 
    =   frwd_ready_o 
        // For write data channels, when the pipeline stage is 
        // required to do masking, we must let through new valid 
        // signals from the sp_wdatach when the mask has been cleared.
        // This is because the correct target slave, and hence valid
        // bus output, cannot be decoded until we have a matching
        // AW id and slave number with which to route the W beat.
      | (   (~mask_valid_i & frwd_mask_valid_r) 
          & ((W_CH==1) & (DO_MASKING==1)) 
        )
      ? bus_valid_i 
      : frwd_bus_valid_r;

  always @(posedge aclk_i or negedge aresetn_i)
  begin : frwd_bus_valid_r_PROC
    if(!aresetn_i) begin
      frwd_bus_valid_r <= {N{1'b0}};
    end else begin
      frwd_bus_valid_r <= frwd_bus_valid_mux;
    end
  end // frwd_bus_valid_r_PROC

  assign frwd_shrd_ch_req_mux 
    =    frwd_ready_o 
         // For explanation see comment for same code in 
         // frwd_bus_valid_mux generation.
       | (   (~mask_valid_i & frwd_mask_valid_r) 
           & ((W_CH==1) & (DO_MASKING==1)) 
         )
       ? shrd_ch_req_i
       : frwd_shrd_ch_req_r;


  // Only send valid when it has been unmasked. Until then the t/x is 
  // being stored in the pipeline stage.
  assign frwd_bus_valid_mskd 
    = DO_MASKING
      ? frwd_bus_valid_r & {N{~frwd_mask_valid_r}}
      : frwd_bus_valid_r;


  always @(posedge aclk_i or negedge aresetn_i)
  begin : frwd_mask_valid_r_PROC
    if(!aresetn_i) begin
      frwd_mask_valid_r <= 1'b0;
    end else begin
      if(~frwd_mask_valid_r) begin
        // We have to hold the mask bit here similar to how we hold the 
        // valid signal(s) if the mask is 0, otherwise we could get a 
        // mask bit for the next t/x that does not apply to this t/x.
        frwd_mask_valid_r
          <= frwd_ready_o 
               // If the arbiter pipeline stage is present, we must only
               // set the mask register here when a valid has been sent
               // from the source. Because in this case, 
               // frwd_mask_valid_r is being used to mask ready back to 
               // the source, so we must be careful not to mask ready
               // because mask_valid_i was 1 by default.
             ? mask_valid_i & (valid_i | (PL_ARB==0))
             : frwd_mask_valid_r;
      end else begin
        // If the mask is set, then we take the mask bit input, waiting for
        // it to deassert. While we are masking, no ready will be sent to
        // the master so no new t/x can arrive.
        frwd_mask_valid_r <= mask_valid_i;
      end
    end
  end // frwd_mask_valid_r_PROC


  always @(posedge aclk_i or negedge aresetn_i)
  begin : frwd_shrd_ch_req_r_PROC
    if(!aresetn_i) begin
      frwd_shrd_ch_req_r <= 1'b0;
    end else begin
      frwd_shrd_ch_req_r <= frwd_shrd_ch_req_mux;
    end
  end // frwd_shrd_ch_req_r_PROC

  // Perform masking on shared channel request signal.
  assign frwd_shrd_ch_req_mskd 
    = DO_MASKING
      ? (frwd_shrd_ch_req_r & (~frwd_mask_valid_r))
      : frwd_shrd_ch_req_r;


  //--------------------------------------------------------------------
  // Payload Register.
  // If ready_o to the source is 1'b1 load with new payload, otherwise
  // hold current contents.
  //--------------------------------------------------------------------
  always @(posedge aclk_i or negedge aresetn_i)
  begin : payload_r_PROC
    if(!aresetn_i) begin
      frwd_payload_r <= {PYLD_W{1'b0}};
    end else begin
      if(frwd_ready_o & valid_i) frwd_payload_r <= payload_i;
    end
  end // payload_r_PROC


  // We will deassert ready_o to the source if valid_i was asserted on 
  // the previous cycle (valid_r is set to 1'b1) and ready_i from the 
  // destination is deasserted.
  assign frwd_ready_o =   (~(|frwd_bus_valid_r) | ready_i)
                          // If the arbiter pipeline stage is also 
                          // present, then deassert ready back to the
                          // source if we have a masked t/x here.
                          // Required because we must only accept 1
                          // masked t/x into the pipeline stages, and
                          // the arbiter pipleline stage will assert 
                          // ready by default.
                        & ((~frwd_mask_valid_r) | (PL_ARB==0));

  generate
  if(DO_MASKING & (W_CH==0)) begin : gen_lcl_slv1_mask_wch0
    // Create id and local slave signals to send back to the mp addrch
    // block to maintain the mask until it is cleared.
    assign frwd_id = frwd_payload_r[ID_LHS:ID_RHS];

    // Local slave variable is decoded from the bus of valids per slave,
    // since we don't otherwise have a binary slave number here.
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue.
    integer frwd_intg_i;                  
    always @(*)
    begin : frwd_local_slv_PROC
      frwd_local_slv = {LOG2_NUM_VIS{1'b0}};
      for(  frwd_intg_i=0
          ; frwd_intg_i<N
          ; frwd_intg_i=frwd_intg_i+1
         ) begin
        if(frwd_bus_valid_r[frwd_intg_i]) frwd_local_slv = frwd_intg_i;
      end
    end // frwd_local_slv_PROC
  //spyglass enable_block W415a
    assign frwd_local_slv_w = frwd_local_slv;
  
  end else if(W_CH) begin : gen_lcl_slv1_wch1
    // Create id and local slave signals to send back to the mp addrch
    // block to maintain the mask until it is cleared.
    // Only ID required for write data channels.
    assign frwd_id = frwd_payload_r[ID_LHS:ID_RHS];
    assign frwd_local_slv_w = {LOG2_NUM_VIS{1'b0}};
    always @(*) 
    begin : gen_lcl_slv1_wch1_PROC // Done to remove LINT issue
      frwd_local_slv = dummy_wire;
    end
  end else begin : gen_lcl_slv1_nomask_wch0 
    assign frwd_id = {(ID_W){1'b0}};
    assign frwd_local_slv_w = {LOG2_NUM_VIS{1'b0}};
    always @(*) 
    begin : gen_lcl_slv1_nomask_wch0_PROC //Done to remove LINT issue
      frwd_local_slv = dummy_wire;
    end
  end

  endgenerate

  //--------------------------------------------------------------------
  // FULL REGISTER MODE LOGIC
  //--------------------------------------------------------------------
  // Registers both the forward (valid master to valid slave) and 
  // backward path (ready slave to ready master). Uses 2 buffer stages
  // to avoid dead cycles due to the double registering in the 
  // handskaking paths.
  //--------------------------------------------------------------------
  
  //--------------------------------------------------------------------
  // Full register mode variables.
  //--------------------------------------------------------------------
  reg [N-1:0]      full_bus_valid1_r; // Bus valid and payload registers 
  reg [N-1:0]      full_bus_valid2_r; // to hold 2 pending transactions 
  reg [PYLD_W-1:0] full_plb1_r;       // from the channel source.
  reg [PYLD_W-1:0] full_plb2_r;
  reg              full_shrd_ch_req1_r; // Shared request registers.
  reg              full_shrd_ch_req2_r; // 
  wire             full_shrd_ch_req1_mskd; // Masked versions of shared
  wire             full_shrd_ch_req2_mskd; // request registers.

  reg              full_mask_valid1_r; // Mask bit registers for each
  reg              full_mask_valid2_r; // of the 2 full reg mode 
                                       // payload banks.

  wire [N-1:0]     full_bus_valid1_mskd; // Masked valid bits for
  wire [N-1:0]     full_bus_valid2_mskd; // each payload bank.

  reg              set_plb_r; // Points to the next payload bank to be
                              // set.
  reg              clr_plb_r; // Points to the next payload bank to be
                              // cleared.

  wire set_v1; // Set and clear signals for full_valid1_r and 
  wire clr_v1; // full_valid2_r registers.
  wire set_v2;
  wire clr_v2;


  // Outputs of muxes used to select which payload banks contents will
  // be used to generate the mask generation feedback signals to the 
  // t/x source block
  wire [N-1:0] full_valid_mux; // Output of full register mode valid
                               // mux.
               
  wire [PYLD_W-1:0] full_payload_mux; // Output of full register mode
                                      // payload mux.
  reg [PYLD_W-1:0] full_mask_fdbk_pyld_mux;
  reg [N-1:0]      full_mask_fdbk_bus_valid_mux;

  wire full_shrd_ch_req_mux; // Full register mode shared channel 
                             // request mux.

  wire tx_acc_src; // Asserted when transaction is accepted at source
                   // side.
  wire tx_acc_dst; // Asserted when transaction is accepted at 
                   // destination side.

  wire payload_sel; // Select which payload bank goes to output.

  wire full_ready; // Ready to source for full register mode.

  wire any_valid1; // Asserted when any bit of full_bus_valid1_r is
                   // asserted.
  wire any_valid2; // Asserted when any bit of full_bus_valid2_r is 
                   // asserted.

  // Mask generation feedback signals in full register mode.
  wire [ID_W-1:0]         full_id;       
  reg  [LOG2_NUM_VIS-1:0] full_local_slv;
  wire [LOG2_NUM_VIS-1:0] full_local_slv_w;

  //spyglass disable_block FlopEConst
  //SMD: Enable pin EN on Flop always disabled
  //SJ: Warning can be ignored
  //--------------------------------------------------------------------
  // Set payload bank register.
  // This register tells us which payload bank will get loaded with
  // the next transaction from the source. When a transaction is
  // accepted at the source side it gets loaded into a payload
  // bank register. Once a transaction is loaded into a payload
  // bank the next transaction will go to the other payload bank.
  // set_plb_r == 1'b0 => Payload bank 1 next to be set.
  // set_plb_r == 1'b1 => Payload bank 2 next to be set.
  //--------------------------------------------------------------------

  // Transaction accepted at source side.       
  assign tx_acc_src = (valid_i & ready_o);       

  always @(posedge aclk_i or negedge aresetn_i)
  begin : set_plb_r_PROC
    if(!aresetn_i) begin
      set_plb_r <= 1'b0;
    end else begin
      if(tx_acc_src) set_plb_r <= !set_plb_r;
    end
  end // set_plb_r_PROC
  //spyglass enable_block FlopEConst

  // Decode set_v* variables.
  // These signals control the setting of the registers
  // full_valid*_r. These registers in turn control the setting
  // and clearing of the payload banks.
  // NOTE :
  // For write data channels, when the pipeline stage is 
  // required to do masking, we must let through new valid 
  // signals from the sp_wdatach when the mask has been cleared.
  // This is because the correct target slave, and hence valid
  // bus output, cannot be decoded until we have a matching
  // AW id and slave number with which to route the W beat.
  assign set_v1 
    =   (tx_acc_src & (!set_plb_r))
      | (   (   ~mask_valid_i 
                // Check which payloads mask bits are set to
                // know which one to load with new correctly
                // generated valid signals.
              & ({full_mask_valid2_r,full_mask_valid1_r} == 2'b01) 
            )
          & ((W_CH==1) & (DO_MASKING==1)) 
        ); 

  assign set_v2
    =   (tx_acc_src & set_plb_r)
      | (   (   ~mask_valid_i 
                // Check which payloads mask bits are set to
                // know which one to load with new correctly
                // generated valid signals.
              & ({full_mask_valid2_r,full_mask_valid1_r} == 2'b10) 
            )
          & ((W_CH==1) & (DO_MASKING==1)) 
        ); 

  

  //--------------------------------------------------------------------
  // Clear payload bank register.
  // This register tells us which payload bank will get cleared next.
  // When a transaction is accepted at the destination side the 
  // payload bank pointed to by this register will get cleared.
  // Once a payload bank is cleared this register will
  // point to the other payload bank.
  // clr_plb_r == 1'b0 => Payload bank 1 next to be cleared.
  // clr_plb_r == 1'b1 => Payload bank 2 next to be cleared.
  //--------------------------------------------------------------------
  
  // Transaction accepted at destination side.       
  // The final sink port (i.e. an MP or SP) will only assert ready to 
  // visible origninal sink ports (MP or SP) if a transaction was driven 
  // to that port, so we can use ready_i directly here. 
  // If PL_ARB is 1 there will be another register slice stage between
  // here and the final sink port, so ready may be asserted without 
  // driving a valid. If this is the case qualify ready_i with the 
  // valid outputs.
  assign tx_acc_dst = PL_ARB 
                      ? ((|bus_valid_o) & ready_i)
                      : ready_i;       

  always @(posedge aclk_i or negedge aresetn_i)
  begin : clr_plb_r_PROC
    if(!aresetn_i) begin
      clr_plb_r <= 1'b0;
    end else begin
      if(tx_acc_dst) clr_plb_r <= !clr_plb_r;
    end
  end // clr_plb_r_PROC

  // Decode clr_v* variables.
  // These signals control the clearing of the registers
  // full_valid*_r. These registers in turn control the setting
  // and clearing of the payload banks.
  assign clr_v1 = (tx_acc_dst & (!clr_plb_r));
  assign clr_v2 = (tx_acc_dst & clr_plb_r);
  

  //--------------------------------------------------------------------
  // full_bus_valid1_r register.
  // This is a set clear register where clear has higher priority
  // than setting.
  //--------------------------------------------------------------------
  always @(posedge aclk_i or negedge aresetn_i)
  begin : full_bus_valid1_r_PROC
    if(!aresetn_i) begin
      full_bus_valid1_r <= {N{1'b0}};
    end else begin
      if      (clr_v1) full_bus_valid1_r <= {N{1'b0}};
      else if (set_v1) full_bus_valid1_r <= bus_valid_i;
    end
  end // full_bus_valid1_r_PROC

  // Assert if there is any valid signal asserted in full_bus_valid1_r.
  assign any_valid1 = |full_bus_valid1_r;


  //--------------------------------------------------------------------
  // full_bus_valid2_r register.
  // This is a set clear register where clear has higher priority
  // than setting.
  //--------------------------------------------------------------------
  always @(posedge aclk_i or negedge aresetn_i)
  begin : full_bus_valid2_r_PROC
    if(!aresetn_i) begin
      full_bus_valid2_r <= {N{1'b0}};
    end else begin
      if      (clr_v2) full_bus_valid2_r <= {N{1'b0}};
      else if (set_v2) full_bus_valid2_r <= bus_valid_i;
    end
  end // full_bus_valid2_r_PROC

  // Assert if there is any valid signal asserted in full_bus_valid1_r.
  assign any_valid2 = |full_bus_valid2_r;
  

  /* -------------------------------------------------------------------
   * Mask register bits for each payload bank.
   */

  // Payload bank 1.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : full_mask_valid1_r_PROC
    if(!aresetn_i) begin
      full_mask_valid1_r <= 1'b0;
    end else begin
      // Use set_v1 to load when the payload bank is being loaded (i.e.
      // with a new t/x.
      // Then if the mask is set to 1, keep loading the new mask bit 
      // until it deasserts.
      if(set_v1 | full_mask_valid1_r) begin
        full_mask_valid1_r <= mask_valid_i;
      end
    end
  end // full_mask_valid1_r_PROC

  // Apply the mask.
  // Only send valid when it has been unmasked. Until then the t/x is 
  // being stored in the pipeline stage.
  assign full_bus_valid1_mskd
    = DO_MASKING
      ? full_bus_valid1_r & {N{~full_mask_valid1_r}}
      : full_bus_valid1_r;

  // Payload bank 2.
  always @(posedge aclk_i or negedge aresetn_i)
  begin : full_mask_valid2_r_PROC
    if(!aresetn_i) begin
      full_mask_valid2_r <= 1'b0;
    end else begin
      // Use set_v2 to load when the payload bank is being loaded (i.e.
      // with a new t/x.
      // Then if the mask is set to 1, keep loading the new mask bit 
      // until it deasserts.
      if(set_v2 | full_mask_valid2_r) begin
        full_mask_valid2_r <= mask_valid_i;
      end
    end
  end // full_mask_valid2_r_PROC

  // Apply the mask.
  // Only send valid when it has been unmasked. Until then the t/x is 
  // being stored in the pipeline stage.
  assign full_bus_valid2_mskd
    = DO_MASKING
      ? full_bus_valid2_r & {N{~full_mask_valid2_r}}
      : full_bus_valid2_r;


  

  //--------------------------------------------------------------------
  // full_shrd_ch_req1_r register.
  // This is a set clear register where clear has higher priority
  // than setting.
  //--------------------------------------------------------------------
  always @(posedge aclk_i or negedge aresetn_i)
  begin : full_shrd_ch_req1_r_PROC
    if(!aresetn_i) begin
      full_shrd_ch_req1_r <= 1'b0;
    end else begin
      if      (clr_v1) full_shrd_ch_req1_r <= 1'b0;
      else if (set_v1) full_shrd_ch_req1_r <= shrd_ch_req_i;
    end
  end // full_shrd_ch_req1_r_PROC

  // Do masking on shared channel request signal.
  assign full_shrd_ch_req1_mskd
    = DO_MASKING
      ? (full_shrd_ch_req1_r & (~full_mask_valid1_r))
      : full_shrd_ch_req1_r;
 

  //--------------------------------------------------------------------
  // full_shrd_ch_req2_r register.
  // This is a set clear register where clear has higher priority
  // than setting.
  //--------------------------------------------------------------------
  always @(posedge aclk_i or negedge aresetn_i)
  begin : full_shrd_ch_req2_r_PROC
    if(!aresetn_i) begin
      full_shrd_ch_req2_r <= 1'b0;
    end else begin
      if      (clr_v2) full_shrd_ch_req2_r <= 1'b0;
      else if (set_v2) full_shrd_ch_req2_r <= shrd_ch_req_i;
    end
  end // full_shrd_ch_req2_r_PROC

  // Do masking on shared channel request signal.
  assign full_shrd_ch_req2_mskd
    = DO_MASKING
      ? (full_shrd_ch_req2_r & (~full_mask_valid2_r))
      : full_shrd_ch_req2_r;
 

  //--------------------------------------------------------------------
  // Payload bank 1 register.
  // Gets loaded with new payload from payload_i unless full_bus_valid_1_r
  // is asserted (holds current value in that case). 
  //--------------------------------------------------------------------
  always @(posedge aclk_i or negedge aresetn_i)
  begin : full_plb1_r_PROC
    if(!aresetn_i) begin
      full_plb1_r <= {(PYLD_W){1'b0}};
    end else begin
      if((!any_valid1) & valid_i) full_plb1_r <= payload_i;
    end
  end // full_plb1_r_PROC
  

  //--------------------------------------------------------------------
  // Payload bank 2 register.
  // Gets loaded with new payload from payload_i unless full_bus_valid_2_r
  // is asserted (holds current value in that case). 
  //--------------------------------------------------------------------
  always @(posedge aclk_i or negedge aresetn_i)
  begin : full_plb2_r_PROC
    if(!aresetn_i) begin
      full_plb2_r <= {(PYLD_W){1'b0}};
    end else begin
      if((!any_valid2) & valid_i) full_plb2_r <= payload_i;
    end
  end // full_plb2_r_PROC


  // clr_plb_r points to the payload bank that the destination will
  // accept next, so this corresponds to the payload bank we will
  // select for the the payload output.
  assign payload_sel = clr_plb_r;        


  //--------------------------------------------------------------------
  // Payload and valid output mux.
  //--------------------------------------------------------------------
  assign full_valid_mux = payload_sel 
                          ? full_bus_valid2_mskd 
                          : full_bus_valid1_mskd;

  assign full_payload_mux = payload_sel ? full_plb2_r : full_plb1_r;

  assign full_shrd_ch_req_mux = payload_sel 
                                ? full_shrd_ch_req2_mskd 
                                : full_shrd_ch_req1_mskd;

  // Mux used to select which payload banks contents will
  // be used to generate the mask generation feedback signals to the 
  // t/x source block.
  always @(*) begin : full_mask_fdbk_mux_PROC
    // Here we only care about selecting the right payload bank,
    // we are not concerned about the condition where neither mask
    // bit is asserted.
    if({full_mask_valid2_r,full_mask_valid1_r} == 2'b01) begin
      full_mask_fdbk_pyld_mux      = full_plb1_r;
      full_mask_fdbk_bus_valid_mux = full_bus_valid1_r;
    end else begin
      full_mask_fdbk_pyld_mux      = full_plb2_r;
      full_mask_fdbk_bus_valid_mux = full_bus_valid2_r;
    end
  end // full_mask_fdbk_mux_PROC

  generate
  if(DO_MASKING & (W_CH==0)) begin : gen_lcl_slv2_mask_wch0
    // Create id and local slave signals to send back to the mp addrch
    // block to maintain the mask until it is cleared.
    // Only ID required for write data channels.
    assign full_id = full_mask_fdbk_pyld_mux[ID_LHS:ID_RHS];

    // Local slave variable is decoded from the bus of valids per slave,
    // since we don't otherwise have a binary slave number here.
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue.
    integer full_intg_i;                  
    always @(*)
    begin : full_local_slv_PROC
      full_local_slv = {LOG2_NUM_VIS{1'b0}};
      for(  full_intg_i=0
          ; full_intg_i<N
          ; full_intg_i=full_intg_i+1
         ) 
      begin
        if(full_mask_fdbk_bus_valid_mux[full_intg_i]) begin
           full_local_slv = full_intg_i;
         end
      end
    end // full_local_slv_PROC
  //spyglass enable_block W415a
    assign full_local_slv_w = full_local_slv;
  
  end else if(W_CH) begin : gen_lcl_slv2_wch1
    // Create id and local slave signals to send back to the mp addrch
    // block to maintain the mask until it is cleared.
    // Only ID required for write data channels.
    assign full_id = full_mask_fdbk_pyld_mux[ID_LHS:ID_RHS];
    assign full_local_slv_w = {LOG2_NUM_VIS{1'b0}};
    always @(*) begin : full_local_slv_PROC
    full_local_slv = dummy_wire ; //VP:: Lint errror
    end
  end else begin : gen_lcl_slv2_nomask_wch0
    assign full_id = {(ID_W){1'b0}};
    assign full_local_slv_w = {LOG2_NUM_VIS{1'b0}};
    always @(*) begin: full_local_slv_PROC
    full_local_slv = dummy_wire ; // VP:: Lint Error
    end
  end

  endgenerate

  //--------------------------------------------------------------------
  // Decode ready out to the source for full register mode.
  // We send ready out high unless both payload banks are set (i.e.
  // any_valid*_r == 1'b1). All these signals are coming from
  // registers so this breaks the path from destination ready to source 
  // ready.
  // If this module is performing valid masking, then we deassert ready
  // back to the source, if a masked t/x is accepted into either payload
  // bank. Since this module must feedback the id and slave number from
  // the masked t/x to the source block so it can detect when the mask 
  // is cleared, we can't accept a new t/x into the pipeline during this
  // time. The reason for this is that the idmask block is busy at that
  // time so we have no way of knowing if the new t/x should be masked
  // or not.
  //--------------------------------------------------------------------
  assign full_ready = DO_MASKING
                      ? (  ((!any_valid1) & (~full_mask_valid2_r)) 
                         | ((!any_valid2) & (~full_mask_valid1_r))
                        )
                      : ((!any_valid1) | (!any_valid2));
  
  
  //--------------------------------------------------------------------
  // OUTPUT STAGE
  // Select outputs dependant on selected timing mode.
  //--------------------------------------------------------------------
  assign bus_valid_o = (TMO==`AXI_TMO_COMB)
                       ? bus_valid_i : 
                         ((TMO==`AXI_TMO_FRWD) 
                          ? frwd_bus_valid_mskd
                          : full_valid_mux
                         ); 

  assign payload_o = (TMO==`AXI_TMO_COMB)
                       ? payload_i : 
                         ((TMO==`AXI_TMO_FRWD) 
                           ? frwd_payload_r 
                           : full_payload_mux
                         ); 

  assign shrd_ch_req_o = SHARED_VIS
                         ?  ((TMO==`AXI_TMO_COMB)
                             ? shrd_ch_req_i : 
                               ((TMO==`AXI_TMO_FRWD) 
                                 ? frwd_shrd_ch_req_mskd
                                 : full_shrd_ch_req_mux
                               ) 
                            )
                         : 1'b0;

  assign ready_o = (TMO==`AXI_TMO_COMB)
                     ? ready_i : 
                       ((TMO==`AXI_TMO_FRWD) 
                         ? frwd_ready_o 
                         : full_ready
                       ); 

  // Select mask generation feedback signals.       
  assign id_o = (DO_MASKING & (TMO!=`AXI_TMO_COMB))
                ? ((TMO==`AXI_TMO_FRWD)
                    ? frwd_id
                    : full_id
                  )
                : {ID_W{1'b0}};

  assign local_slv_o = (DO_MASKING & (TMO!=`AXI_TMO_COMB))
                       ? ((TMO==`AXI_TMO_FRWD)
                           ? frwd_local_slv
                           : full_local_slv
                         )
                       : {LOG2_NUM_VIS{1'b0}};

         
endmodule
