`timescale 1ns / 100ps
//*************************************************************************
// > File Name: nmsix_manager.v
// > Author   : Li jianxiong
// > Date     : 2021-10-12
// > Note     : nmsix_manager is used to manage nic msix, including queue number, addr offset .etc
// > V1.1 - 2021-10-12 : 
//*************************************************************************

module msix_manager #(
  /* axil parameter */
  parameter AXIL_ADDR_WIDTH = 12,

  /* msix  */
  parameter INTERRUPTE_NUM = 64
) 
(
  input   wire                                  clk,
  input   wire                                  rst_n,

  /*axil write signal*/
  input   wire [AXIL_ADDR_WIDTH-1:0]            awaddr_msix,
  input   wire                                  awvalid_msix,
  output  wire                                  awready_msix,
  input   wire [`AXIL_DATA_WIDTH-1:0]           wdata_msix,
  input   wire [`AXIL_STRB_WIDTH-1:0]           wstrb_msix,
  input   wire                                  wvalid_msix,
  output  wire                                  wready_msix,
  output  wire                                  bvalid_msix,
  input   wire                                  bready_msix,
  /*axil read signal*/
  input   wire [AXIL_ADDR_WIDTH-1:0]            araddr_msix,
  input   wire                                  arvalid_msix,
  output  wire                                  arready_msix,
  output  wire [`AXIL_DATA_WIDTH-1:0]           rdata_msix,
  output  wire                                  rvalid_msix,
  input   wire                                  rready_msix,

  input    wire   [`MSI_NUM_WIDTH-1:0]          tx_irq_req_msix,
  input    wire                                 tx_irq_req_valid,
  output   wire                                 tx_irq_req_ready,

  output   wire   [`IRQ_MSG-1:0]                tx_irq_rsp_msg,
  output   wire   [`DMA_ADDR_WIDTH-1:0]         tx_irq_rsp_addr,
  output   wire                                 tx_irq_rsp_valid,
  input    wire                                 tx_irq_rsp_ready,

  input    wire   [`MSI_NUM_WIDTH-1:0]          rx_irq_req_msix,
  input    wire                                 rx_irq_req_valid,
  output   wire                                 rx_irq_req_ready,

  output   wire   [`IRQ_MSG-1:0]                rx_irq_rsp_msg,
  output   wire   [`DMA_ADDR_WIDTH-1:0]         rx_irq_rsp_addr,
  output   wire                                 rx_irq_rsp_valid,
  input    wire                                 rx_irq_rsp_ready

`ifdef ETH_CHIP_DEBUG
  // ,input 	  wire		[0 : 0] 		Rw_data
	// ,output 	wire 		[0 : 0] 		Ro_data
  ,input 	  wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_sel
	,output 	wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_bus
	//,output 	wire 		[`MSIX_MANAGER_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_bus
`endif
);


localparam IRQ_ADDR_WIDTH     = $clog2(INTERRUPTE_NUM) ;
// localparam INTERRUPTE_NUM_LOG = $clog2(INTERRUPTE_NUM) + 1;

wire [AXIL_ADDR_WIDTH-1:0]            waddr;
wire [`AXIL_DATA_WIDTH-1:0]           wdata;
wire [`AXIL_STRB_WIDTH-1:0]           wstrb;
wire                                  wvalid;
wire                                  wready;

wire [AXIL_ADDR_WIDTH-1:0]            raddr;
wire                                  rvalid;
reg [`AXIL_DATA_WIDTH-1:0]            rdata;
wire                                  rready;

axi_convert #(
    /* axil parameter */
  .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH)
) 
axi_convert_inst
(
  .clk(clk),
  .rst_n(rst_n),

  /*axil write signal*/
  .awaddr_s(awaddr_msix),
  .awvalid_s(awvalid_msix),
  .awready_s(awready_msix),
  .wdata_s(wdata_msix),
  .wstrb_s(wstrb_msix),
  .wvalid_s(wvalid_msix),
  .wready_s(wready_msix),
  .bvalid_s(bvalid_msix),
  .bready_s(bready_msix),

  .waddr(waddr),
  .wdata(wdata),
  .wstrb(wstrb),
  .wvalid(wvalid),
  .wready(wready),

  /*axil read signal*/
  .araddr_s(araddr_msix),
  .arvalid_s(arvalid_msix),
  .arready_s(arready_msix),
  .rdata_s(rdata_msix),
  .rvalid_s(rvalid_msix),
  .rready_s(rready_msix),

  .raddr(raddr),
  .rvalid(rvalid),
  .rdata(rdata),
  .rready(rready)
);


reg [127:0] msix_table[INTERRUPTE_NUM-1:0];

reg [127:0] msix_wdata;

wire [IRQ_ADDR_WIDTH-1:0] msix_num_rd;
wire [IRQ_ADDR_WIDTH-1:0] msix_num_wr;

/*---------axil write signal {begin}--------------*/
assign msix_num_wr = waddr[4 +: IRQ_ADDR_WIDTH];

assign wready = 1'b1;

always @(*) begin
  if(!rst_n) begin
    msix_wdata = 0;
  end else if(wvalid && wready && waddr[AXIL_ADDR_WIDTH-1 -: 4] < 4'h4) begin
    case(waddr[3:2])
      2'b00:    msix_wdata = { msix_table[msix_num_wr][127:32], wdata};
      2'b01:    msix_wdata = { msix_table[msix_num_wr][127:64], wdata, msix_table[msix_num_wr][31:0]};
      2'b10:    msix_wdata = { msix_table[msix_num_wr][127:96], wdata, msix_table[msix_num_wr][63:0]};
      2'b11:    msix_wdata = { wdata, msix_table[msix_num_wr][95:0]};
    endcase
  end else begin
    msix_wdata = 0; 
  end
end

integer i;
always @(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    for(i = 0; i < INTERRUPTE_NUM; i = i + 1) begin:init_table
      msix_table[i]              <= `TD 0;
    end
  end else if(wready_msix && wvalid_msix) begin
    msix_table[msix_num_wr] <= `TD msix_wdata;
  end
end
/*---------axil write signal {end}--------------*/


/*---------axil read signal {begin}--------------*/
assign msix_num_rd = raddr[4 +: IRQ_ADDR_WIDTH];

assign rready = 1'b1;

wire [127:0] rdata_table;

assign rdata_table = msix_table[msix_num_rd];

always @(*) begin
  if(!rst_n) begin
    rdata = 0;
  end else if(rvalid && rready && raddr[AXIL_ADDR_WIDTH-1 -: 4] == 4'h2) begin
    case(raddr[3:2])
      2'b00:    rdata = rdata_table[31:0];
      2'b01:    rdata = rdata_table[63:32];
      2'b10:    rdata = rdata_table[95:64];
      2'b11:    rdata = rdata_table[127:96];
    endcase
  end else begin
    rdata = 0; 
  end
end
/*---------axil read signal {end}--------------*/


/*---------irq read {begin}--------------*/

localparam  IRQ_IDEL = 0,
            IRQ_REQ  = 1;
 
/* tx read irq message */
reg                       tx_irq_state;
reg [`MSI_NUM_WIDTH-1:0]  tx_irq_msix;

assign tx_irq_req_ready = tx_irq_state == IRQ_IDEL;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    tx_irq_msix   <= 'b0;
    tx_irq_state  <= IRQ_IDEL;
  end else if(tx_irq_req_valid && tx_irq_req_ready ) begin
    tx_irq_msix   <= tx_irq_req_msix;
    tx_irq_state  <= IRQ_REQ;
  end else if (tx_irq_rsp_valid && tx_irq_rsp_ready) begin
    tx_irq_msix   <= 'b0;
    tx_irq_state  <= IRQ_IDEL;
  end
end

assign tx_irq_rsp_valid = tx_irq_state == IRQ_REQ;

assign tx_irq_rsp_msg   = tx_irq_state == IRQ_REQ ? msix_table[tx_irq_msix[IRQ_ADDR_WIDTH-1:0]][95:64] : 'b0;
assign tx_irq_rsp_addr  = tx_irq_state == IRQ_REQ ? msix_table[tx_irq_msix[IRQ_ADDR_WIDTH-1:0]][63:0] : 'b0;

/* rx read irq message */
reg                                 rx_irq_state;
reg [`MSI_NUM_WIDTH-1:0]            rx_irq_msix;

assign rx_irq_req_ready = rx_irq_state == IRQ_IDEL;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    rx_irq_msix   <= 'b0;
    rx_irq_state  <= IRQ_IDEL;
  end else if(rx_irq_req_valid && rx_irq_req_ready ) begin
    rx_irq_msix   <= rx_irq_req_msix;
    rx_irq_state  <= IRQ_REQ;
  end else if (rx_irq_rsp_valid && rx_irq_rsp_ready) begin
    rx_irq_msix   <= 'b0;
    rx_irq_state  <= IRQ_IDEL;
  end
end

assign rx_irq_rsp_valid = rx_irq_state == IRQ_REQ;

assign rx_irq_rsp_msg   = rx_irq_state == IRQ_REQ ? msix_table[rx_irq_msix[IRQ_ADDR_WIDTH-1:0]][95:64] : 'b0;
assign rx_irq_rsp_addr  = rx_irq_state == IRQ_REQ ? msix_table[rx_irq_msix[IRQ_ADDR_WIDTH-1:0]][63:0] : 'b0;


`ifdef ETH_CHIP_DEBUG

wire 		[`MSIX_MANAGER_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_data;

assign Dbg_data = {// wire
                  10'b0,
                  tx_irq_req_msix, tx_irq_req_valid, tx_irq_req_ready, tx_irq_rsp_msg, tx_irq_rsp_addr, 
                  tx_irq_rsp_valid, tx_irq_rsp_ready, rx_irq_req_msix, rx_irq_req_valid, rx_irq_req_ready, 
                  rx_irq_rsp_msg, rx_irq_rsp_addr, rx_irq_rsp_valid, rx_irq_rsp_ready, 
                  waddr, wdata, wstrb, wvalid, wready, raddr, rvalid, rready, 
                  msix_num_rd, msix_num_wr, rdata_table, 


                  // reg
                  rdata, msix_wdata, tx_irq_state, tx_irq_msix, rx_irq_state, rx_irq_msix
                  } ;

assign Dbg_bus = Dbg_data >> (Dbg_sel << 5);
//assign Dbg_bus = Dbg_data;
`endif



/* irq test */
// wire irq_btn_in;
// wire [3:0] irq_num_in;

// reg irq_btn_reg;
// reg [3:0] irq_num_reg;

// reg irq_sig;

// vio_irq vio_irq_inst (
//   .clk        ( clk  ), // input wire clk
//   .probe_out0 ( irq_btn_in),  // output wire [0 : 0] probe_out0
//   .probe_out1 ( irq_num_in)  // output wire [0 : 0] probe_out0
// );


// always@(posedge clk, negedge rst_n) begin
//   irq_btn_reg <= irq_btn_in;
//   irq_num_reg <= irq_num_in;
// end

// assign msix_axis_irq_valid  = irq_sig;
// assign msix_axis_irq_last   = irq_sig;
// assign msix_axis_irq_data   = msix_table[irq_num_reg][95:64];
// assign msix_axis_irq_head   = {
//                               32'b10, /* interrupt */
//                               msix_table[irq_num_reg][63:0],
//                               32'b0
//                             };

// always@(posedge clk, negedge rst_n) begin
//   if(rst_n && irq_btn_reg == 1 && irq_btn_in == 0) begin
//     irq_sig <= 1;
//   end else if(msix_axis_irq_valid && msix_axis_irq_ready) begin
//     irq_sig <= 0;
//   end
// end

// ila_msix_test ila_msix_test_inst(
//   .clk(clk),
//   .probe0(irq_btn_reg ),
//   .probe1(irq_num_reg),
//   .probe2(irq_sig),
//   .probe3(msix_axis_irq_valid),
//   .probe4(msix_axis_irq_data ),
//   .probe5(msix_axis_irq_head ),
//   .probe6(msix_axis_irq_last ),
//   .probe7(msix_axis_irq_ready)
// );


// ila_msix_axi_rd ila_msix_axi_rd_inst(
//   .clk(clk),
//   .probe0(araddr_msix ),
//   .probe1(arvalid_msix),
//   .probe2(arready_msix),
//   .probe3(rdata_msix ),
//   .probe4(rvalid_msix ),
//   .probe5(rready_msix),
//   .probe6(rdata_table)
// );

endmodule


