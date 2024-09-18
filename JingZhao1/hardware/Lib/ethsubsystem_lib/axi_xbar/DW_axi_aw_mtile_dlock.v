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
// Revision: $Id: //dwh/DW_ocb/DW_axi/amba_dev/src/DW_axi_aw_mtile_dlock.v#8 $ 
**
** ---------------------------------------------------------------------
**
** File     : DW_axi_aw_mtile_dlock.v
//
//
** Modified : $Date: 2020/03/22 $
** Abstract : The purpose of this block is to prevent deadlock 
**            conditions with write transactions in multi tile DW_axi
**            systems.
**
** ---------------------------------------------------------------------
*/


module DW_axi_aw_mtile_dlock (
  // Inputs 
  aclk_i,
  aresetn_i,
  bus_valid_i,
  shrd_ch_req_i,
  bus_ready_i,
  bus_wready_i,
  bus_wvalid_i,
  bus_wvalid_r_i,
  wlast_i,
  // Outputs
  bus_valid_o,
  shrd_ch_req_o
);

/*----------------------------------------------------------------------
 * MODULE PARAMETERS.
 */
  parameter NUM_VIS_SP  = 2; // Num. visible slave ports.
  parameter AW_PL_ARB = 0; // 1 if AW arbiter outputs are pipelined.
  parameter W_PL_ARB = 0; // 1 if W arbiter outputs are pipelined.

  parameter MAX_UIDA = 1; // Num unique ID's.
  parameter MAX_WCA  = 1; // Num act. t/x's per unique ID.

  parameter PYLD_W = 1; // Payload width.
  
  // Visibility of each slave port to this master port.                                
  parameter VIS_S0 = 0;
  parameter VIS_S1 = 0;
  parameter VIS_S2 = 0;
  parameter VIS_S3 = 0;
  parameter VIS_S4 = 0;
  parameter VIS_S5 = 0;
  parameter VIS_S6 = 0;
  parameter VIS_S7 = 0;
  parameter VIS_S8 = 0;
  parameter VIS_S9 = 0;
  parameter VIS_S10 = 0;
  parameter VIS_S11 = 0;
  parameter VIS_S12 = 0;
  parameter VIS_S13 = 0;
  parameter VIS_S14 = 0;
  parameter VIS_S15 = 0;
  parameter VIS_S16 = 0;
  

/*----------------------------------------------------------------------
 * LOCAL PARAMETERS
 */
 localparam MAX_PEND = MAX_UIDA * MAX_WCA;
 localparam PEND_TX_CNT_W =    (MAX_PEND==512) ? 10
                            : ((MAX_PEND>=256) ? 9
                            : ((MAX_PEND>=128) ? 8
                            : ((MAX_PEND>=64) ? 7
                            : ((MAX_PEND>=32) ? 6
                            : ((MAX_PEND>=16) ? 5
                            : ((MAX_PEND>=8) ? 4
                            : ((MAX_PEND>=4) ? 3
                            : ((MAX_PEND>1) ? 2 : 1))))))));


 // Is it possible to get WLAST before AW at this master port.                            
 // If a slave port is visible to more than 1 master, it will not
 // send WVALID to slave until it has issued AWVALID - due to the need
 // to implement write ordering rules. If a slave is visible to just
 // 1 master however, WVALID does not need to wait for AWVALID to be
 // issued.
 localparam WLAST_B4_AW = 
     (`AXI_NUM_MASTERS == 1)
   | (VIS_S0 & (`AXI_NMV_S0 == 1))
   | (VIS_S1 & (`AXI_NMV_S1 == 1))
   | (VIS_S2 & (`AXI_NMV_S2 == 1))
   | (VIS_S3 & (`AXI_NMV_S3 == 1))
   | (VIS_S4 & (`AXI_NMV_S4 == 1))
   | (VIS_S5 & (`AXI_NMV_S5 == 1))
   | (VIS_S6 & (`AXI_NMV_S6 == 1))
   | (VIS_S7 & (`AXI_NMV_S7 == 1))
   | (VIS_S8 & (`AXI_NMV_S8 == 1))
   | (VIS_S9 & (`AXI_NMV_S9 == 1))
   | (VIS_S10 & (`AXI_NMV_S10 == 1))
   | (VIS_S11 & (`AXI_NMV_S11 == 1))
   | (VIS_S12 & (`AXI_NMV_S12 == 1))
   | (VIS_S13 & (`AXI_NMV_S13 == 1))
   | (VIS_S14 & (`AXI_NMV_S14 == 1))
   | (VIS_S15 & (`AXI_NMV_S15 == 1))
   | (VIS_S16 & (`AXI_NMV_S16 == 1));



/*----------------------------------------------------------------------
 * PORT DECLARATIONS
 */
  
  // Inputs - System.
  input aclk_i;    // AXI system clock.
  input aresetn_i; // AXI system reset.

  // Inputs - Channel Source
  input [NUM_VIS_SP-1:0] bus_valid_i;
  input                  shrd_ch_req_i;

  // Outputs - Channel Destination
  output [NUM_VIS_SP-1:0] bus_valid_o;
  output                  shrd_ch_req_o;
  
  // Inputs - Channel Destination
  //spyglass disable_block W240
  //SMD: An input has been declared but is not read
  //SJ: This port is used in specific configuration only 
  input [NUM_VIS_SP-1:0] bus_ready_i;

  // Inputs - Write Data Channel
  input [NUM_VIS_SP-1:0] bus_wready_i;
  // Depending on paramter W_PL_ARB this signal may not be used
  input [NUM_VIS_SP-1:0] bus_wvalid_i;
  input [NUM_VIS_SP-1:0] bus_wvalid_r_i;
  input wlast_i;
  //spyglass enable_block W240


/*----------------------------------------------------------------------
 * REG/WIRE DECLARATIONS
 */

  // Non local t/x pending counter variables.                            
  reg [PEND_TX_CNT_W-1:0] nlcl_pend_cnt_nxt;
  reg [PEND_TX_CNT_W-1:0] nlcl_pend_cnt_r;
  reg [NUM_VIS_SP-1:0] bus_nlcl_slv_act_r;

  reg waiting_tx_acc_norm_r;
  wire waiting_tx_acc_pl_arb;

  // Set when non local pending counter wraps around.
  //Depending on internal parameter WLAST_B4_AW this signal may not be used
  reg nlcl_pend_cnt_wrap_r;
  wire nlcl_pend_cnt_wrap;

  // Extract last signals from write payload bus.
  wire wlast;
  assign wlast = wlast_i;


  // VIS_S* parameters collected into a bus.
  wire [`AXI_MAX_NUM_MST_SLVS-1:0] vis_bus;
  integer slv;
  assign vis_bus = 
    {(VIS_S16 ? 1'b1 : 1'b0),
     (VIS_S15 ? 1'b1 : 1'b0),
     (VIS_S14 ? 1'b1 : 1'b0),
     (VIS_S13 ? 1'b1 : 1'b0),
     (VIS_S12 ? 1'b1 : 1'b0),
     (VIS_S11 ? 1'b1 : 1'b0),
     (VIS_S10 ? 1'b1 : 1'b0),
     (VIS_S9 ? 1'b1 : 1'b0),
     (VIS_S8 ? 1'b1 : 1'b0),
     (VIS_S7 ? 1'b1 : 1'b0),
     (VIS_S6 ? 1'b1 : 1'b0),
     (VIS_S5 ? 1'b1 : 1'b0),
     (VIS_S4 ? 1'b1 : 1'b0),
     (VIS_S3 ? 1'b1 : 1'b0),
     (VIS_S2 ? 1'b1 : 1'b0),
     (VIS_S1 ? 1'b1 : 1'b0),
     (VIS_S0 ? 1'b1 : 1'b0)
    };


  /*--------------------------------------------------------------------
   * Register for every unique ID which is 1 if that ID has an 
   * outstanding t/x with an interconnecting slave port i.e. a slave
   * that connects to another AXI bus - used to prevent deadlock in
   * bi-directional configurations (multi-tile systems).
   */
  wire [`AXI_MAX_NUM_MST_SLVS-1:0] non_lcl_slv_bus;
  assign non_lcl_slv_bus = 
    {(`AXI_ACC_NON_LCL_SLV_S16 ? 1'b1 : 1'b0),
     (`AXI_ACC_NON_LCL_SLV_S15 ? 1'b1 : 1'b0),
     (`AXI_ACC_NON_LCL_SLV_S14 ? 1'b1 : 1'b0),
     (`AXI_ACC_NON_LCL_SLV_S13 ? 1'b1 : 1'b0),
     (`AXI_ACC_NON_LCL_SLV_S12 ? 1'b1 : 1'b0),
     (`AXI_ACC_NON_LCL_SLV_S11 ? 1'b1 : 1'b0),
     (`AXI_ACC_NON_LCL_SLV_S10 ? 1'b1 : 1'b0),
     (`AXI_ACC_NON_LCL_SLV_S9 ? 1'b1 : 1'b0),
     (`AXI_ACC_NON_LCL_SLV_S8 ? 1'b1 : 1'b0),
     (`AXI_ACC_NON_LCL_SLV_S7 ? 1'b1 : 1'b0),
     (`AXI_ACC_NON_LCL_SLV_S6 ? 1'b1 : 1'b0),
     (`AXI_ACC_NON_LCL_SLV_S5 ? 1'b1 : 1'b0),
     (`AXI_ACC_NON_LCL_SLV_S4 ? 1'b1 : 1'b0),
     (`AXI_ACC_NON_LCL_SLV_S3 ? 1'b1 : 1'b0),
     (`AXI_ACC_NON_LCL_SLV_S2 ? 1'b1 : 1'b0),
     (`AXI_ACC_NON_LCL_SLV_S1 ? 1'b1 : 1'b0),
     1'b0 // Default slave is always local.
    };

  // non_lcl_slv_bus reduced to visible slaves only.
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ:  non_lcl_slv_bus reduced to visible slaves only. This is not an issue
  reg [NUM_VIS_SP-1:0] vis_non_lcl_slv_bus;
  always @(*) begin : vis_non_lcl_slv_bus_PROC
    integer ss;
    integer ls;
    ls = 0;
    vis_non_lcl_slv_bus = {NUM_VIS_SP{1'b0}};
    for(ss=0;ss<`AXI_MAX_NUM_MST_SLVS;ss=ss+1) begin
      if(vis_bus[ss]) begin
        vis_non_lcl_slv_bus[ls] = non_lcl_slv_bus[ss];
        ls=ls+1;
      end
    end
  end // vis_non_lcl_slv_bus_PROC
  //spyglass enable_block W415a


  /*----------------------------------------------------------------------
   * Decode when a valid has been issued for each slave.
   */

  always @(posedge aclk_i or negedge aresetn_i) 
  begin: waiting_tx_acc_norm_r_PROC
    if(~aresetn_i) begin
      waiting_tx_acc_norm_r <= 1'b0;
    end else begin
      waiting_tx_acc_norm_r
      <= (|bus_valid_o) & (~(|bus_ready_i));
    end 
  end // waiting_tx_acc_norm_r_PROC

  // Because of the change in handshaking in AW_PL_ARB mode, waiting for
  // acceptance of a valid must be decoded differently.
  reg valid_o_r;
  always @(posedge aclk_i or negedge aresetn_i) 
  begin: valid_o_r_PROC
    if(~aresetn_i) begin
      valid_o_r <= 1'b0;
    end else begin
      valid_o_r <= (|bus_valid_o);
    end 
  end // waiting_tx_acc_norm_r_PROC
  assign waiting_tx_acc_pl_arb = valid_o_r & (~(|bus_ready_i));

  wire waiting_tx_acc;
  assign waiting_tx_acc = AW_PL_ARB 
                              ? waiting_tx_acc_pl_arb 
                              : waiting_tx_acc_norm_r;


  wire [NUM_VIS_SP-1:0] bus_nlcl_tx_issued;
  assign bus_nlcl_tx_issued 
  =   bus_valid_o 
    & (~{NUM_VIS_SP{waiting_tx_acc}})
    & vis_non_lcl_slv_bus; 

  wire nlcl_tx_issued;
  assign nlcl_tx_issued = |bus_nlcl_tx_issued;

  /*----------------------------------------------------------------------
   * Maintain a register for each non local slave which will be asserted
   * if there are outstanding transactions at that slave.
   */
  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ:  non_lcl_slv_bus reduced to visible slaves only. This is not an issue
  always @(posedge aclk_i or negedge aresetn_i) 
  begin: bus_nlcl_slv_act_r_PROC
    if(~aresetn_i) begin
      bus_nlcl_slv_act_r <= {NUM_VIS_SP{1'b0}};
    end else begin
      for(slv=0;slv<NUM_VIS_SP;slv=slv+1) begin
        if(bus_nlcl_tx_issued[slv] & (~nlcl_pend_cnt_wrap)) 
          bus_nlcl_slv_act_r[slv] <= 1'b1;

        // If CPL for this t/x gets here in same cycle
        // as the address, don't register the t/x.
        if(nlcl_pend_cnt_nxt == {PEND_TX_CNT_W{1'b0}}) 
          bus_nlcl_slv_act_r[slv] <= 1'b0;
      end // for(slv=0;...
    end // if(~aresetn_i) .. else 
  end // bus_nlcl_slv_act_r_PROC
  //spyglass enable_block W415a

  wire nlcl_slv_act;
  assign nlcl_slv_act = |bus_nlcl_slv_act_r;


  /*----------------------------------------------------------------------
   * Maintain a count of pending transactions at non local slaves.
   * Note that the deadlock avoidance scheme only allows transactions to
   * be pending at 1 non local slave at a time.
   */

   // Decode non local slave write data completion signal.
   wire [NUM_VIS_SP-1:0] bus_wvalid;
   // If W_PL_ARB mode enabled use registered valid signals, as non
   // registered ones will be removed combinatorially when ready is
   // asserted.
   assign bus_wvalid = W_PL_ARB ? bus_wvalid_r_i : bus_wvalid_i;
   wire nlcl_slv_w_cpl;
   assign nlcl_slv_w_cpl = wlast & (|(  bus_wvalid
                                     & bus_wready_i
                                     & vis_non_lcl_slv_bus
                                    )); 


  //spyglass disable_block W415a
  //SMD: Signal may be multiply assigned (beside initialization) in the same scope
  //SJ:  This is not an issue
   always @(*) begin : nlcl_pend_cnt_nxt_PROC
     nlcl_pend_cnt_nxt = nlcl_pend_cnt_r;
     case({{nlcl_tx_issued},{nlcl_slv_w_cpl}}) 
       2'b00,
       2'b11 : nlcl_pend_cnt_nxt = nlcl_pend_cnt_r;
       2'b10 : nlcl_pend_cnt_nxt = nlcl_pend_cnt_r + 1'b1;
       2'b01 : nlcl_pend_cnt_nxt = nlcl_pend_cnt_r - 1'b1;
     endcase
   end // nlcl_pend_cnt_nxt_PRC
  //spyglass enable_block W415a

  always @(posedge aclk_i or negedge aresetn_i) begin: nlcl_pend_cnt_r_PROC
    if(~aresetn_i) begin
      nlcl_pend_cnt_r <= {PEND_TX_CNT_W{1'b0}};
    end else begin
      nlcl_pend_cnt_r <= nlcl_pend_cnt_nxt;
    end 
  end // nlcl_pend_cnt_r_PROC


  /*----------------------------------------------------------------------
   * If a slave port is visible to more than 1 master, it will not
   * send WVALID to slave until it has issued AWVALID - due to the need
   * to implement write ordering rules. If a slave is visible to just
   * 1 master however, WVALID does not need to wait for AWVALID to be
   * issued.
   *
   * To work around this, if a WLAST for a non local slave is received
   * when nlcl_pend_cnt_r == 0, we let the counter wrap around
   * and set nlcl_pend_cnt_wrap_r to 1. When the counter returns to 0 
   * we set nlcl_pend_cnt_wrap_r back to 0.
   *
   * While nlcl_pend_cnt_wrap_r is 1, we don't set bus_nlcl_slv_act_r. 
   * If nlcl_pend_cnt_wrap_r == 1, the WLAST for the non local t/x 
   * has already been sent, so this t/x cannot cause a deadlock 
   * condition.
   */
   always @(posedge aclk_i or negedge aresetn_i) 
   begin: nlcl_pend_cnt_wrap_r_PROC
    if(~aresetn_i) begin
      nlcl_pend_cnt_wrap_r <= 1'b0;
    end else begin
      if(~nlcl_pend_cnt_wrap_r) begin
        // Counter about to wrap.
        nlcl_pend_cnt_wrap_r 
        <=   (nlcl_pend_cnt_nxt == {PEND_TX_CNT_W{1'b1}}) 
           & (nlcl_pend_cnt_r=={PEND_TX_CNT_W{1'b0}});
      end else begin
        // Counter returning to 0 after wrap.
        nlcl_pend_cnt_wrap_r 
        <= ~(nlcl_pend_cnt_nxt == {PEND_TX_CNT_W{1'b0}});
      end
    end 
   end // nlcl_pend_cnt_wrap_r_PROC
   assign nlcl_pend_cnt_wrap = WLAST_B4_AW ? nlcl_pend_cnt_wrap_r
                                           : 1'b0;


  /*----------------------------------------------------------------------
   * Decode and apply masking conditions.
   */
  // not used if MAX_PEND == 1
  wire mask_valid;
  // T/x at non local slave is active, and the current valid is not to 
  // the same non local slave.
  assign mask_valid =   nlcl_slv_act 
                      & (~(|(bus_valid_i & bus_nlcl_slv_act_r)))
                      // Note, if the master port is configured for a 
                      // maximum of 1 pending write t/x, multi tile
                      // deadlock is not possible, need at least 2.
                      & (MAX_PEND>1);

  assign bus_valid_o = mask_valid ? {NUM_VIS_SP{1'b0}} : bus_valid_i;

  assign shrd_ch_req_o = mask_valid ? 1'b0 : shrd_ch_req_i;

endmodule
