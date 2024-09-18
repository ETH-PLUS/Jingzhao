`timescale 1ns / 100ps
//*************************************************************************
// > File Name: tx_rocedesc.v
// > Author   : Li jianxiong
// > Date     : 2021-10-12
// > Note     : tx_rocedesc is used for receive the desc from memory.
//              it reveices the desc request from rx engine
//              and initiate a request to the queue management module to get 
//              the queue addr ??? index and other information. 
//              Then get the desc from memory by the queue information.
// > V1.1 - 2021-10-21 : 
//*************************************************************************
module tx_rocedesc #(
  /* parameters */
)
(
  input   wire                              clk,
  input   wire                              rst_n,

  /* input from roce desc, request for a desc */
  input   wire                                i_tx_desc_empty,
  input   wire     [`ROCE_DESC_WIDTH-1:0]     iv_tx_desc_data,
  output  wire                                o_tx_desc_rd_en,

  /* to tx roceproc, to get the desc */
  output   wire [`ROCE_DTYP_WIDTH-1:0]          tx_desc_dtyp,
  output   wire [`ROCE_LEN_WIDTH-1:0]           tx_desc_len,
  output   wire [`MAC_WIDTH-1:0]                tx_desc_smac,
  output   wire [`MAC_WIDTH-1:0]                tx_desc_dmac,
  output   wire [`IP_WIDTH-1:0]                 tx_desc_sip,
  output   wire [`IP_WIDTH-1:0]                 tx_desc_dip,
  output   wire                                 tx_desc_valid,
  input    wire                                 tx_desc_ready

`ifdef ETH_CHIP_DEBUG
  // ,input 	  wire		[0 : 0] 		Rw_data
	// ,output 	wire 		[0 : 0] 		Ro_data

  ,input 	  wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_sel
,output 	wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_bus
	//,output 	wire 		[`TX_ROCEDESC_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_bus

`endif
);

localparam IDEL = 0,
            GET_DESC = 1;

reg [`ROCE_DESC_WIDTH-1:0] desc_data;

reg  state_cur;
wire state_next;

assign state_next = state_cur == IDEL && !i_tx_desc_empty ? GET_DESC :
                    state_cur == GET_DESC && tx_desc_valid && tx_desc_ready ? IDEL : state_cur;


assign tx_desc_dtyp     = desc_data[3:0];
assign tx_desc_len      = desc_data[31:16];
assign tx_desc_smac     = desc_data[79:32];
assign tx_desc_dmac     = desc_data[127:80];
assign tx_desc_sip      = desc_data[159:128];
assign tx_desc_dip      = desc_data[191:160];
assign tx_desc_valid    = state_cur == GET_DESC;

assign o_tx_desc_rd_en = state_cur == IDEL && state_next == GET_DESC;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_data <= `TD 0;
  end else begin
    if(state_cur == IDEL && state_next == GET_DESC) begin
      desc_data <= `TD iv_tx_desc_data;
    end    
  end
end

always @(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    state_cur <= `TD IDEL;
  end else begin
    state_cur <= `TD state_next;
  end
end

`ifdef ETH_CHIP_DEBUG

wire 		[`TX_ROCEDESC_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_data;


assign Dbg_data = {// wire
                  30'b0, state_next,
                  // reg
                  desc_data, state_cur
                  } ;

assign Dbg_bus = Dbg_data >> (Dbg_sel << 5);
//assign Dbg_bus = Dbg_data;

`endif



endmodule
