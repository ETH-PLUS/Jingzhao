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
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_irs_arbpl.v#12 $ 
**
** ---------------------------------------------------------------------
**
** File     : DW_axi_irs_arbpl.v
//
//
** Created  : Tue May 24 17:09:09 MEST 2005
** Modified : $Date: 2020/03/22 $
** Abstract : This block implements an internal register slice 
**            particular to the pipelined arbiter option.
**            the DW_axi interconnect. 
**
**            It differs from DW_axi_irs in that the valid signals
**            are forwarded combinatorially here. Payload is registered
**            as in DW_axi_irs. This block has only pass through and
**            forward registered modes.
**
** ---------------------------------------------------------------------
*/


module DW_axi_irs_arbpl (
  // Inputs - System.
  aclk_i,
  aresetn_i,

  // Inputs - Payload source.
  bus_valid_i,
  shrd_ch_req_i,
  payload_i,
  mask_valid_i,
  issued_wtx_shrd_mst_oh_i,
  
  // Outputs - Payload source.
  ready_o,

  // Inputs - Payload destination.
  bus_ready_i,
  
  // Outputs - Channel source.
  id_o,       
  local_slv_o,

  // Outputs - Payload destination.
  bus_valid_o,
  bus_valid_r_o,
  shrd_ch_req_o,
  payload_o,
  payload_prereg_o,
  issued_wtx_shrd_mst_oh_o
);

//----------------------------------------------------------------------
// MODULE PARAMETERS.
//----------------------------------------------------------------------
  parameter TMO = 0; // Timing option that this block will implement.
                     // TMO = 0 => Pass through mode.
                     // TMO = 1 => Forward register mode.
  
  parameter N = 2; // Number of valid signals that this block 
                   // accomadates.
       
  parameter PYLD_W = `AXI_AR_PYLD_M_W; // Width of payload signals in 
                                       // this block.    

  parameter LOG2_NUM_VIS = 1; // Log base 2 of number of visible 
                              // slave ports.
                                 
  parameter ID_W = 1; // Master ID width.                                 

  parameter DO_MASKING = 0; // 1 if this block should perform valid
                            // masking and send back id and local
                            // slave number.

  parameter ID_RHS = 0; // Left hand bit index of ID in payload.
  parameter ID_LHS = 1; // Right hand bit index of ID in payload.

  parameter W_CH = 0; // Pass a 1 if this module is being used in a 
                      // W channel.

  parameter SHARED_VIS = 0; // 1 if shared layer signals should be
                            // generated.
                            
  // 1 if this instance is being used in an AW channel shared to
  // dedicated link i.e. are issued_wtx_shrd_mst_oh_i & 
  // issued_wtx_shrd_mst_oh_o signals being used.
  parameter AW_SHRD_DDCTD_LNK = 0; 

  // Number of masters on the shared AW layer.
  parameter AW_NSM = 1;
                            
//----------------------------------------------------------------------
// LOCAL MACROS.
//----------------------------------------------------------------------


//----------------------------------------------------------------------
// PORT DECLARATIONS
//----------------------------------------------------------------------
  // Inputs - System.
  input aclk_i;    // AXI system clock.
  input aresetn_i; // AXI system reset.

  // Inputs - Payload source.
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input [N-1:0]      bus_valid_i;

  // Not Used if DO_MASKING parameter is 0 
  input              mask_valid_i;
  input [AW_NSM-1:0] issued_wtx_shrd_mst_oh_i;
  input              shrd_ch_req_i;
  input [PYLD_W-1:0] payload_i;
  //spyglass enable_block W240

  // Outputs - Payload source.
  output ready_o;


  // Inputs - Payload destination.
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input [N-1:0] bus_ready_i;
  //spyglass enable_block W240
  
  // Outputs - Channel source.
  output [ID_W-1:0] id_o;       
  output [LOG2_NUM_VIS-1:0] local_slv_o;

  // Outputs - Payload destination.
  output [N-1:0]      bus_valid_o; 
  output [N-1:0]      bus_valid_r_o; 
  output              shrd_ch_req_o;
  output [PYLD_W-1:0] payload_o;
  output [PYLD_W-1:0] payload_prereg_o; // Pre register version of
                                        // payload_o.
                                        
  // Master number of t/x issued from here - when used in
  // AW channel shared to dedicated link only.
  output [AW_NSM-1:0] issued_wtx_shrd_mst_oh_o;


  //--------------------------------------------------------------------
  // FORWARD REGISTER MODE LOGIC
  //--------------------------------------------------------------------
  // Registers the forward (valid master to valid slave) only.
  // Uses a single buffer stage to avoid dead cycles due to the register
  // in the handskaking paths.
  //--------------------------------------------------------------------

  //--------------------------------------------------------------------
  // Forward register mode variables.
  //--------------------------------------------------------------------
  reg [N-1:0]      frwd_bus_valid_r;
  wire [N-1:0]     frwd_bus_valid_mskd;
  reg              frwd_shrd_ch_req_r;
  wire             frwd_shrd_ch_req_mskd;
  reg [PYLD_W-1:0] frwd_payload_r;

  // Register and pre register signals for the mask bit relating to the 
  // t/x currently being issued from this pipeline stage.
  reg frwd_mask_valid_r;
  reg frwd_mask_valid_mux;

  wire [N-1:0] frwd_bus_valid_mux;  // Mux between registered bus valids
                                    // and input bus valids.

  wire frwd_shrd_ch_req_mux;  // Mux between registered shared request 
                              // and input shared req.
                              
  wire [PYLD_W-1:0] frwd_payload_mux; // Mux between registered payload
                                      // and payload in.
  
  wire frwd_ready_o; // ready to source for forward register mode.

  wire any_ready; // Asserted when any ready signals from the 
                  // destination are asserted.
                  
 
  reg [LOG2_NUM_VIS-1:0] local_slv;
  reg [AW_NSM-1:0] issued_wtx_shrd_mst_oh_r;
  reg [AW_NSM-1:0] issued_wtx_shrd_mst_oh;

  wire mask_valid; // Mask_valid_i qualified by DO_MASKING parameter.


  // Qualify mask_valid_i with DO_MASKING parameter.
  assign mask_valid = DO_MASKING ? mask_valid_i : 1'b0;

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
      | (   (~mask_valid & frwd_mask_valid_r) 
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

  // Only send valid when it has been unmasked. Until then the t/x is 
  // being stored in the pipeline stage.
  assign frwd_bus_valid_mskd 
    = DO_MASKING
      ? frwd_bus_valid_mux & {N{~frwd_mask_valid_mux}}
      : frwd_bus_valid_mux;
  assign frwd_shrd_ch_req_mux 
    = (frwd_ready_o) 
        // For explanation see comment for same code in 
        // frwd_bus_valid_mux generation.
      | (   (~mask_valid & frwd_mask_valid_r) 
          & ((W_CH==1) & (DO_MASKING==1)) 
        )
      ? shrd_ch_req_i
      : frwd_shrd_ch_req_r;

  // Only send shared channel request when t/x has been unmasked. Until
  // then the t/x is being stored in the pipeline stage.
  assign frwd_shrd_ch_req_mskd
    = DO_MASKING
      ? (frwd_shrd_ch_req_mux & (~frwd_mask_valid_mux))
      : frwd_shrd_ch_req_mux;


  // Register to store input t/x mask bit.
  // Pre register signal.
  always @(*)
  begin : frwd_mask_valid_mux_PROC
    if(~frwd_mask_valid_r) begin
      // We have to hold the mask bit here similar to how we hold the 
      // valid signal(s) if the mask is 0, otherwise we could get a 
      // mask bit for the next t/x that does not apply to this t/x.
      frwd_mask_valid_mux
        = frwd_ready_o ? mask_valid : frwd_mask_valid_r;
    end else begin
      // If the mask is set, then we take the mask bit input, waiting for
      // it to deassert. While we are masking, no ready will be sent to
      // the master so no new t/x can arrive.
      frwd_mask_valid_mux = mask_valid;
    end
  end // frwd_mask_valid_mux_PROC

  always @(posedge aclk_i or negedge aresetn_i)
  begin : frwd_mask_valid_r_PROC
    if(!aresetn_i) begin
      frwd_mask_valid_r <= 1'b0;
    end else begin
      frwd_mask_valid_r <= frwd_mask_valid_mux;
    end
  end // frwd_mask_valid_r_PROC


  generate
  if(DO_MASKING & (W_CH==0)) begin : gen_lcl_slv_mask_wch0_arb
    // Create id and local slave signals to send back to the mp addrch
    // block to maintain the mask until it is cleared.
    assign id_o = frwd_payload_r[ID_LHS:ID_RHS];

    // Local slave variable is decoded from the bus of valids per slave,
    // since we don't otherwise have a binary slave number here.
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ: This is not an issue.
    integer frwd_intg_i;                  
    always @(*)
    begin : local_slv_PROC
      local_slv = {LOG2_NUM_VIS{1'b0}};
      for(  frwd_intg_i=0
          ; frwd_intg_i<N
          ; frwd_intg_i=frwd_intg_i+1
         ) begin
        if(frwd_bus_valid_r[frwd_intg_i]) local_slv = frwd_intg_i;
      end
    end // local_slv_PROC
  //spyglass enable_block W415a
    assign local_slv_o = local_slv;
  
  end else if(W_CH) begin : gen_lcl_slv_wch1_arb
    // Create id and local slave signals to send back to the mp addrch
    // block to maintain the mask until it is cleared.
    // Only ID required for write data channels.
    assign id_o = frwd_payload_r[ID_LHS:ID_RHS];
    assign local_slv_o = {LOG2_NUM_VIS{1'b0}};
  end else begin : gen_lcl_slv_nomask_wch0_arb
    assign id_o = {ID_W{1'b0}};
    assign local_slv_o = {LOG2_NUM_VIS{1'b0}};
  end

  endgenerate


  always @(posedge aclk_i or negedge aresetn_i)
  begin : frwd_shrd_ch_req_r_PROC
    if(!aresetn_i) begin
      frwd_shrd_ch_req_r <= 1'b0;
    end else begin
      frwd_shrd_ch_req_r <= frwd_shrd_ch_req_mux;
    end
  end // frwd_shrd_ch_req_r_PROC


  //--------------------------------------------------------------------
  // Payload Register.
  // If ready_o to the source is 1'b1 load with new payload, otherwise
  // hold current contents.
  //--------------------------------------------------------------------
  assign frwd_payload_mux = (frwd_ready_o & (|bus_valid_i)) 
                            ? payload_i
                            : frwd_payload_r;

  always @(posedge aclk_i or negedge aresetn_i)
  begin : payload_r_PROC
    if(!aresetn_i) begin
      frwd_payload_r <= {PYLD_W{1'b0}};
    end else begin
      frwd_payload_r <= frwd_payload_mux;
    end
  end // payload_r_PROC


  // Asserted when any ready signals from the destination are asserted.
  // Only 1 should be asserted at any time. The handshaking between this
  // channel source and other channel destinations is implemented such 
  // that each destination asserts a different ready bit to each source
  // only when that source as asserted a valid to that destination.
  // So we can do an OR reduction on bus_ready_i and use the result as
  // a ready signal from the destination.
  assign any_ready = |bus_ready_i;

  // We will deassert ready_o to the source if valid_i was asserted on 
  // the previous cycle (valid_r is set to 1'b1) and any_ready from the 
  // destination is deasserted.
  assign frwd_ready_o = ~(|frwd_bus_valid_r) | any_ready;

  //--------------------------------------------------------------------
  // Perform register slicing of issued_wtx_shrd_mst_oh_i.
  //
  // In order to avoid a deadlock condition involving shared to 
  // dedicated links when the shared layer is pipelined, and also the 
  // arbiter pipeline stage for the channel is enabled - the master 
  // number of the transaction issued to a dedicated W layer is 
  // register sliced here. The register slicing is necessary so the
  // master number signal is present when the t/x is pushed into the
  // dedicated W channel. The push is initiated by the dedicated AW
  // layer, since only this layer knows the level of the first data
  // beat ordering fifo in the dedicated W channel. When the tx here
  // is accepted by the dedicated AW layer, the master number is pushed
  // and we can move onto the next master number.

  generate 
   if(AW_SHRD_DDCTD_LNK)
   begin
    always @(*) begin : issued_wtx_shrd_mst_oh_PROC
      issued_wtx_shrd_mst_oh = {AW_NSM{1'b0}};
      if(frwd_ready_o) begin
        issued_wtx_shrd_mst_oh = issued_wtx_shrd_mst_oh_i;
      end else begin
        issued_wtx_shrd_mst_oh = issued_wtx_shrd_mst_oh_r;
      end
    end // issued_wtx_shrd_mst_oh_PROC
   end
   else
   begin
    always @(*) begin : issued_wtx_shrd_mst_oh_PROC
      issued_wtx_shrd_mst_oh = {AW_NSM{1'b0}};
    end // issued_wtx_shrd_mst_oh_PROC
   end
  endgenerate

  always @(posedge aclk_i or negedge aresetn_i) 
  begin : issued_wtx_shrd_mst_oh_r_PROC
    if(~aresetn_i) begin
      issued_wtx_shrd_mst_oh_r <= {AW_NSM{1'b0}};
    end else begin
      issued_wtx_shrd_mst_oh_r <= issued_wtx_shrd_mst_oh;
    end
  end // issued_wtx_shrd_mst_oh_r_PROC
  
  // Pass through if not a shared dedicated link with arbpl pipelining
  // required on the link.
  assign issued_wtx_shrd_mst_oh_o = (AW_SHRD_DDCTD_LNK & (TMO==1)) 
                                    ? issued_wtx_shrd_mst_oh_r
                                    : issued_wtx_shrd_mst_oh_i;


  //--------------------------------------------------------------------
  // OUTPUT STAGE
  // Select outputs dependant on selected timing mode.
  // Note how valid outputs are combinatorial.
  //--------------------------------------------------------------------
  assign bus_valid_o = (TMO==`AXI_TMO_COMB)
                       ? bus_valid_i 
                       : frwd_bus_valid_mskd;

  // Provide registered valids as an output also.
  assign bus_valid_r_o = frwd_bus_valid_r;

  assign shrd_ch_req_o = SHARED_VIS
                         ?  ((TMO==`AXI_TMO_COMB)
                             ? shrd_ch_req_i 
                             : frwd_shrd_ch_req_mskd
                            ) 
                         : 1'b0;

  assign payload_o = (TMO==`AXI_TMO_COMB)
                       ? payload_i
                       : frwd_payload_r;

  assign ready_o = (TMO==`AXI_TMO_COMB)
                     ? any_ready 
                     : frwd_ready_o;

  assign payload_prereg_o = (TMO==`AXI_TMO_COMB)
                            ? payload_i
                            : ((frwd_ready_o) ? payload_i : frwd_payload_r);
         
endmodule
