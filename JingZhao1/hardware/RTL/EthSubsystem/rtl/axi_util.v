`timescale 1ns / 100ps
//*************************************************************************
// > File Name: axi_util.v
// > Author   : Li jianxiong
// > Date     : 2021-10-29
// > Note     : axi_util is used to receive the frame from roce fifo and 
//              add the ip header to the frame
//              then transmit it to the mac
//              it implements a fifo inside.
//              
// > V1.1 - 2021-10-21 : 
//*************************************************************************

module axi_util #(
  parameter AXIL_ADDR_WIDTH       = 32
)
(
  input   wire                                  clk,
  input   wire                                  rst_n,

  // Write Address Channel from Master 1
  input wire                       awvalid_m,
  input wire  [`AXI_AW-1:0]        awaddr_m,
  output  wire                     awready_m,  
  input wire                       wvalid_m,
  input wire  [`AXI_DW-1:0]        wdata_m,
  input wire  [`AXI_SW-1:0]        wstrb_m,
  output  wire                      wready_m,
  output  wire                      bvalid_m,
  input wire                       bready_m,

  input wire                       arvalid_m,
  input wire  [`AXI_AW-1:0]        araddr_m,
  output  wire                      arready_m,
  output  wire                      rvalid_m,
  output  wire [`AXI_DW-1:0]        rdata_m,
  input wire                       rready_m,

  /*axil write signal*/
  output wire [AXIL_ADDR_WIDTH-1:0]             awaddr_csr,
  output wire                                   awvalid_csr,
  input  wire                                   awready_csr,
  output wire [`AXIL_DATA_WIDTH-1:0]            wdata_csr,
  output wire [`AXIL_STRB_WIDTH-1:0]            wstrb_csr,
  output wire                                   wvalid_csr,
  input  wire                                   wready_csr,
  input  wire                                   bvalid_csr,
  output wire                                   bready_csr,
  /*axil read signal*/
  output wire [AXIL_ADDR_WIDTH-1:0]             araddr_csr,
  output wire                                   arvalid_csr,
  input  wire                                   arready_csr,
  input  wire [`AXIL_DATA_WIDTH-1:0]            rdata_csr,
  input  wire                                   rvalid_csr,
  output wire                                   rready_csr,


    /*axil write signal*/
  output wire [AXIL_ADDR_WIDTH-1:0]             awaddr_rx,
  output wire                                   awvalid_rx,
  input  wire                                   awready_rx,
  output wire [`AXIL_DATA_WIDTH-1:0]            wdata_rx,
  output wire [`AXIL_STRB_WIDTH-1:0]            wstrb_rx,
  output wire                                   wvalid_rx,
  input  wire                                   wready_rx,
  input  wire                                   bvalid_rx,
  output wire                                   bready_rx,
  /*axil read signal*/
  output wire [AXIL_ADDR_WIDTH-1:0]             araddr_rx,
  output wire                                   arvalid_rx,
  input  wire                                   arready_rx,
  input  wire [`AXIL_DATA_WIDTH-1:0]            rdata_rx,
  input  wire                                   rvalid_rx,
  output wire                                   rready_rx,

    /*axil write signal*/
  output wire [AXIL_ADDR_WIDTH-1:0]             awaddr_tx,
  output wire                                   awvalid_tx,
  input  wire                                   awready_tx,
  output wire [`AXIL_DATA_WIDTH-1:0]            wdata_tx,
  output wire [`AXIL_STRB_WIDTH-1:0]            wstrb_tx,
  output wire                                   wvalid_tx,
  input  wire                                   wready_tx,
  input  wire                                   bvalid_tx,
  output wire                                   bready_tx,
  /*axil read signal*/
  output wire [AXIL_ADDR_WIDTH-1:0]             araddr_tx,
  output wire                                   arvalid_tx,
  input  wire                                   arready_tx,
  input  wire [`AXIL_DATA_WIDTH-1:0]            rdata_tx,
  input  wire                                   rvalid_tx,
  output wire                                   rready_tx,

    /*axil write signal*/
  output   wire [AXIL_ADDR_WIDTH-1:0]             awaddr_msix,
  output   wire                                   awvalid_msix,
  input  wire                                     awready_msix,
  output   wire [`AXIL_DATA_WIDTH-1:0]            wdata_msix,
  output   wire [`AXIL_STRB_WIDTH-1:0]            wstrb_msix,
  output   wire                                   wvalid_msix,
  input  wire                                     wready_msix,
  input  wire                                     bvalid_msix,
  output   wire                                   bready_msix,
  /*axil read signal*/
  output   wire [AXIL_ADDR_WIDTH-1:0]             araddr_msix,
  output   wire                                   arvalid_msix,
  input  wire                                     arready_msix,
  input  wire [`AXIL_DATA_WIDTH-1:0]              rdata_msix,
  input  wire                                     rvalid_msix,
  output   wire                                   rready_msix
);

// master stall one cycle
wire                        awvalid_m_d0;
wire  [`AXI_AW-1:0]         awaddr_m_d0;
wire                        awready_m_d0;  
wire                        wvalid_m_d0;
wire  [`AXI_DW-1:0]         wdata_m_d0;
wire  [`AXI_SW-1:0]         wstrb_m_d0;
wire                        wready_m_d0;
wire                        bvalid_m_d0;
wire                        bready_m_d0;
wire                        arvalid_m_d0;
wire  [`AXI_AW-1:0]         araddr_m_d0;
wire                        arready_m_d0;
wire                        rvalid_m_d0;
wire [`AXI_DW-1:0]          rdata_m_d0;
wire                        rready_m_d0;

// stall one cycle
wire                        awvalid_s_in_d0   [3:0],  awvalid_s_out_d0  [3:0];
wire  [`AXI_AW-1:0]         awaddr_s_in_d0    [3:0],  awaddr_s_out_d0   [3:0];
wire                        awready_s_in_d0   [3:0],  awready_s_out_d0  [3:0];  
wire                        wvalid_s_in_d0    [3:0],  wvalid_s_out_d0   [3:0];
wire  [`AXI_DW-1:0]         wdata_s_in_d0     [3:0],  wdata_s_out_d0    [3:0];
wire  [`AXI_SW-1:0]         wstrb_s_in_d0     [3:0],  wstrb_s_out_d0    [3:0];
wire                        wready_s_in_d0    [3:0],  wready_s_out_d0   [3:0];
wire                        bvalid_s_in_d0    [3:0],  bvalid_s_out_d0   [3:0];
wire                        bready_s_in_d0    [3:0],  bready_s_out_d0   [3:0];
wire                        arvalid_s_in_d0   [3:0],  arvalid_s_out_d0  [3:0];
wire  [`AXI_AW-1:0]         araddr_s_in_d0    [3:0],  araddr_s_out_d0   [3:0];
wire                        arready_s_in_d0   [3:0],  arready_s_out_d0  [3:0];
wire                        rvalid_s_in_d0    [3:0],  rvalid_s_out_d0   [3:0];
wire [`AXI_DW-1:0]          rdata_s_in_d0     [3:0],  rdata_s_out_d0    [3:0];
wire                        rready_s_in_d0    [3:0],  rready_s_out_d0   [3:0];


assign {awvalid_msix,   awvalid_tx,   awvalid_rx, awvalid_csr }    = {awvalid_s_out_d0[3],   awvalid_s_out_d0[2],  awvalid_s_out_d0[1],  awvalid_s_out_d0[0]}; 
assign {awaddr_msix,    awaddr_tx,    awaddr_rx,  awaddr_csr  }    = {awaddr_s_out_d0[3],    awaddr_s_out_d0[2],   awaddr_s_out_d0[1],   awaddr_s_out_d0[0]}; 
assign {awready_s_out_d0[3],   awready_s_out_d0[2],  awready_s_out_d0[1],  awready_s_out_d0[0]}  = {awready_msix,   awready_tx,   awready_rx, awready_csr } ; 

assign {wvalid_msix,    wvalid_tx,    wvalid_rx,  wvalid_csr  }   = {wvalid_s_out_d0[3],    wvalid_s_out_d0[2],   wvalid_s_out_d0[1],   wvalid_s_out_d0[0]}; 
assign {wdata_msix,     wdata_tx,     wdata_rx,   wdata_csr   }   = {wdata_s_out_d0[3],     wdata_s_out_d0[2],    wdata_s_out_d0[1],    wdata_s_out_d0[0]}; 
assign {wstrb_msix,     wstrb_tx,     wstrb_rx,   wstrb_csr   }   = {wstrb_s_out_d0[3],     wstrb_s_out_d0[2],    wstrb_s_out_d0[1],    wstrb_s_out_d0[0]}; 
assign {wready_s_out_d0[3],    wready_s_out_d0[2],   wready_s_out_d0[1],   wready_s_out_d0[0]}   = {wready_msix,    wready_tx,    wready_rx,  wready_csr } ; 

assign {bvalid_s_out_d0[3],    bvalid_s_out_d0[2],   bvalid_s_out_d0[1],   bvalid_s_out_d0[0]}   = {bvalid_msix,    bvalid_tx,    bvalid_rx,  bvalid_csr  }; 
assign {bready_msix,    bready_tx,    bready_rx,  bready_csr  }   = {bready_s_out_d0[3],    bready_s_out_d0[2],   bready_s_out_d0[1],   bready_s_out_d0[0]}; 

assign {arvalid_msix,   arvalid_tx,   arvalid_rx, arvalid_csr }   = {arvalid_s_out_d0[3],   arvalid_s_out_d0[2],  arvalid_s_out_d0[1],  arvalid_s_out_d0[0]}; 
assign {araddr_msix,    araddr_tx,    araddr_rx,  araddr_csr  }   = {araddr_s_out_d0[3],    araddr_s_out_d0[2],   araddr_s_out_d0[1],   araddr_s_out_d0[0]}; 
assign {arready_s_out_d0[3],   arready_s_out_d0[2],  arready_s_out_d0[1],  arready_s_out_d0[0]}   = {arready_msix,   arready_tx,   arready_rx, arready_csr } ;

assign {rvalid_s_out_d0[3],    rvalid_s_out_d0[2],   rvalid_s_out_d0[1],   rvalid_s_out_d0[0]}    = {rvalid_msix,    rvalid_tx,    rvalid_rx,  rvalid_csr  } ;
assign {rdata_s_out_d0[3],     rdata_s_out_d0[2],    rdata_s_out_d0[1],    rdata_s_out_d0[0]}     = {rdata_msix,     rdata_tx,     rdata_rx,   rdata_csr   } ;
assign {rready_msix,    rready_tx,    rready_rx,  rready_csr  }   = {rready_s_out_d0[3],    rready_s_out_d0[2],   rready_s_out_d0[1],   rready_s_out_d0[0]}; 


axi_int #(
  /* axil parameter */
  .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH)
) 
axi_int_inst_m
(
  .clk(clk),
  .rst_n(rst_n),

  // master signal
  .awaddr_m(awaddr_m),
  .awvalid_m(awvalid_m),
  .awready_m(awready_m),
  .wdata_m(wdata_m),
  .wstrb_m(wstrb_m),
  .wvalid_m(wvalid_m),  
  .wready_m(wready_m),
  .bvalid_m(bvalid_m),
  .bready_m(bready_m),
  .araddr_m(araddr_m),
  .arvalid_m(arvalid_m),
  .arready_m(arready_m),
  .rdata_m(rdata_m),
  .rvalid_m(rvalid_m),
  .rready_m(rready_m),

  // slave signal
  .awaddr_s(awaddr_m_d0),
  .awvalid_s(awvalid_m_d0),
  .awready_s(awready_m_d0),
  .wdata_s(wdata_m_d0),
  .wstrb_s(wstrb_m_d0),
  .wvalid_s(wvalid_m_d0),
  .wready_s(wready_m_d0),
  .bvalid_s(bvalid_m_d0),
  .bready_s(bready_m_d0),
  .araddr_s(araddr_m_d0),
  .arvalid_s(arvalid_m_d0),
  .arready_s(arready_m_d0),
  .rdata_s(rdata_m_d0),
  .rvalid_s(rvalid_m_d0),
  .rready_s(rready_m_d0)
);


generate
  genvar i;

  for(i = 0; i < 4; i = i + 1) begin: axi_int_loop
    axi_int #(
        /* axil parameter */
      .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH)
    ) 
    axi_int_inst_s
    (
      .clk(clk),
      .rst_n(rst_n),

      /*axil write signal*/
      .awaddr_m(awaddr_s_in_d0[i]),
      .awvalid_m(awvalid_s_in_d0[i]),
      .awready_m(awready_s_in_d0[i]),
      .wdata_m(wdata_s_in_d0[i]),
      .wstrb_m(wstrb_s_in_d0[i]),
      .wvalid_m(wvalid_s_in_d0[i]),  
      .wready_m(wready_s_in_d0[i]),
      .bvalid_m(bvalid_s_in_d0[i]),
      .bready_m(bready_s_in_d0[i]),
      .araddr_m(araddr_s_in_d0[i]),
      .arvalid_m(arvalid_s_in_d0[i]),
      .arready_m(arready_s_in_d0[i]),
      .rdata_m(rdata_s_in_d0[i]),
      .rvalid_m(rvalid_s_in_d0[i]),
      .rready_m(rready_s_in_d0[i]),

      .awaddr_s(awaddr_s_out_d0[i]),
      .awvalid_s(awvalid_s_out_d0[i]),
      .awready_s(awready_s_out_d0[i]),
      .wdata_s(wdata_s_out_d0[i]),
      .wstrb_s(wstrb_s_out_d0[i]),
      .wvalid_s(wvalid_s_out_d0[i]),
      .wready_s(wready_s_out_d0[i]),
      .bvalid_s(bvalid_s_out_d0[i]),
      .bready_s(bready_s_out_d0[i]),
      .araddr_s(araddr_s_out_d0[i]),
      .arvalid_s(arvalid_s_out_d0[i]),
      .arready_s(arready_s_out_d0[i]),
      .rdata_s(rdata_s_out_d0[i]),
      .rvalid_s(rvalid_s_out_d0[i]),
      .rready_s(rready_s_out_d0[i])
    );
  end
endgenerate


DW_axi Dw_axi_inst(
  .aclk(clk),
  .aresetn(rst_n),
// Write Address Channel from Master 1
  .awvalid_m1(awvalid_m_d0),
  .awaddr_m1(awaddr_m_d0),
  .awid_m1(`AXI_IDW_M1'b0),
  .awlen_m1(`AXI_BLW'b1),
  .awsize_m1(`AXI_BSW'd4),
  .awburst_m1(`AXI_BTW'b0),
  .awlock_m1(1'b0),
  .awcache_m1(`AXI_CTW'b0),
  .awprot_m1(`AXI_PTW'b0),
  .awready_m1(awready_m_d0),
  
// Write Data Channel from Master 1
  .wvalid_m1(wvalid_m_d0),
  .wdata_m1(wdata_m_d0),
  .wstrb_m1(wstrb_m_d0),
  .wlast_m1(wvalid_m_d0),
  .wready_m1(wready_m_d0),
// Write Response Channel from Master 1
  .bvalid_m1(bvalid_m_d0),
  .bid_m1(),
  .bresp_m1(),
  .bready_m1(bready_m_d0),
// Read Address Channel from Master 1
  .arvalid_m1(arvalid_m_d0),
  .arid_m1(`AXI_IDW_M1'b0),
  .araddr_m1(araddr_m_d0),
  .arlen_m1(`AXI_BLW'b1),
  .arsize_m1(`AXI_BSW'd4),
  .arburst_m1(`AXI_BTW'b0),
  .arlock_m1(1'b0),
  .arcache_m1(`AXI_CTW'b0),
  .arprot_m1(`AXI_PTW'b0),
  .arready_m1(arready_m_d0),

// Read Data Channel from Master 1
  .rvalid_m1(rvalid_m_d0),
  .rid_m1(),
  .rdata_m1(rdata_m_d0),
  .rlast_m1(),
  .rresp_m1(),
  .rready_m1(rready_m_d0),

// Write Address Channel from Slave 1
  .awvalid_s1(awvalid_s_in_d0[0]),
  .awaddr_s1(awaddr_s_in_d0[0]),

  .awid_s1(),

  .awlen_s1(),
  .awsize_s1(),
  .awburst_s1(),
  .awlock_s1(),
  .awcache_s1(),
  .awprot_s1(),
  .awready_s1(awready_s_in_d0[0]),

// Write Data Channel from Slave 1
  .wvalid_s1(wvalid_s_in_d0[0]),


  .wdata_s1(wdata_s_in_d0[0]),
  .wstrb_s1(wstrb_s_in_d0[0]),
  .wlast_s1(),
  .wready_s1(wready_s_in_d0[0]),
// Write Response Channel from Slave 1
  .bvalid_s1(bvalid_s_in_d0[0]),

  .bid_s1(`AXI_SIDW'b0),

  .bresp_s1(`AXI_BRW'b0),
  .bready_s1(bready_s_in_d0[0]),
// Read Address Channel from Slave 1
  .arvalid_s1(arvalid_s_in_d0[0]),

  .arid_s1(),

  .araddr_s1(araddr_s_in_d0[0]),
  .arlen_s1(),
  .arsize_s1(),
  .arburst_s1(),
  .arlock_s1(),
  .arcache_s1(),
  .arprot_s1(),
  .arready_s1(arready_s_in_d0[0]),

// Read Data Channel from Slave 1
  .rvalid_s1(rvalid_s_in_d0[0]),

  .rid_s1(`AXI_SIDW'b0),

  .rdata_s1(rdata_s_in_d0[0]),
  .rlast_s1(rvalid_s_in_d0[0]),
  .rresp_s1(`AXI_RRW'b0),
  .rready_s1(rready_s_in_d0[0]),

// Write Address Channel from Slave2
  .awvalid_s2(awvalid_s_in_d0[1]),
  .awaddr_s2(awaddr_s_in_d0[1]),

  .awid_s2(),

  .awlen_s2(),
  .awsize_s2(),
  .awburst_s2(),
  .awlock_s2(),
  .awcache_s2(),
  .awprot_s2(),
  .awready_s2(awready_s_in_d0[1]),  

// Write Data Channel from Slave2
  .wvalid_s2(wvalid_s_in_d0[1]),


  .wdata_s2(wdata_s_in_d0[1]),
  .wstrb_s2(wstrb_s_in_d0[1]),
  .wlast_s2(),
  .wready_s2(wready_s_in_d0[1]),
// Write Response Channel from Slave2
  .bvalid_s2(bvalid_s_in_d0[1]),

  .bid_s2(`AXI_SIDW'b0),

  .bresp_s2(`AXI_BRW'b0),
  .bready_s2(bready_s_in_d0[1]),
// Read Address Channel from Slave2
  .arvalid_s2(arvalid_s_in_d0[1]),

  .arid_s2(),

  .araddr_s2(araddr_s_in_d0[1]),
  .arlen_s2(),
  .arsize_s2(),
  .arburst_s2(),
  .arlock_s2(),
  .arcache_s2(),
  .arprot_s2(),
  .arready_s2(arready_s_in_d0[1]),

  

// Read Data Channel from Slave2
  .rvalid_s2(rvalid_s_in_d0[1]),

  .rid_s2(`AXI_SIDW'b0),

  .rdata_s2(rdata_s_in_d0[1]),
  .rlast_s2(rvalid_s_in_d0[1]),
  .rresp_s2(`AXI_RRW'b0),
  .rready_s2(rready_s_in_d0[1]),


// Write Address Channel from Slave3
  .awvalid_s3(awvalid_s_in_d0[2]),
  .awaddr_s3(awaddr_s_in_d0[2]),

  .awid_s3(),

  .awlen_s3(),
  .awsize_s3(),
  .awburst_s3(),
  .awlock_s3(),
  .awcache_s3(),
  .awprot_s3(),
  .awready_s3(awready_s_in_d0[2]),
  

// Write Data Channel from Slave3
  .wvalid_s3(wvalid_s_in_d0[2]),


  .wdata_s3(wdata_s_in_d0[2]),
  .wstrb_s3(wstrb_s_in_d0[2]),
  .wlast_s3(),
  .wready_s3(wready_s_in_d0[2]),
// Write Response Channel from Slave3
  .bvalid_s3(bvalid_s_in_d0[2]),

  .bid_s3(`AXI_SIDW'b0),

  .bresp_s3(`AXI_BRW'b0),
  .bready_s3(bready_s_in_d0[2]),
// Read Address Channel from Slave3
  .arvalid_s3(arvalid_s_in_d0[2]),

  .arid_s3(),

  .araddr_s3(araddr_s_in_d0[2]),
  .arlen_s3(),
  .arsize_s3(),
  .arburst_s3(),
  .arlock_s3(),
  .arcache_s3(),
  .arprot_s3(),
  .arready_s3(arready_s_in_d0[2]),

  

// Read Data Channel from Slave3
  .rvalid_s3(rvalid_s_in_d0[2]),

  .rid_s3(`AXI_SIDW'b0),

  .rdata_s3(rdata_s_in_d0[2]),
  .rlast_s3(rvalid_s_in_d0[2]),
  .rresp_s3(`AXI_RRW'b0),
  .rready_s3(rready_s_in_d0[2]),


  // Write Address Channel from Slave4
  .awvalid_s4(awvalid_s_in_d0[3]),
  .awaddr_s4(awaddr_s_in_d0[3]),

  .awid_s4(),

  .awlen_s4(),
  .awsize_s4(),
  .awburst_s4(),
  .awlock_s4(),
  .awcache_s4(),
  .awprot_s4(),
  .awready_s4(awready_s_in_d0[3]),
  

// Write Data Channel from Slave4
  .wvalid_s4(wvalid_s_in_d0[3]),


  .wdata_s4(wdata_s_in_d0[3]),
  .wstrb_s4(wstrb_s_in_d0[3]),
  .wlast_s4(),
  .wready_s4(wready_s_in_d0[3]),
// Write Response Channel from Slave4
  .bvalid_s4(bvalid_s_in_d0[3]),

  .bid_s4(`AXI_SIDW'b0),

  .bresp_s4(`AXI_BRW'b0),
  .bready_s4(bready_s_in_d0[3]),
// Read Address Channel from Slave4
  .arvalid_s4(arvalid_s_in_d0[3]),

  .arid_s4(),

  .araddr_s4(araddr_s_in_d0[3]),
  .arlen_s4(),
  .arsize_s4(),
  .arburst_s4(),
  .arlock_s4(),
  .arcache_s4(),
  .arprot_s4(),
  .arready_s4(arready_s_in_d0[3]),

  

// Read Data Channel from Slave4
  .rvalid_s4(rvalid_s_in_d0[3]),

  .rid_s4(`AXI_SIDW'b0),

  .rdata_s4(rdata_s_in_d0[3]),
  .rlast_s4(rvalid_s_in_d0[3]),
  .rresp_s4(`AXI_RRW'b0),
  .rready_s4(rready_s_in_d0[3]),

               .dbg_awid_s0(),
               .dbg_awaddr_s0(),
               .dbg_awlen_s0(),
               .dbg_awsize_s0(),
               .dbg_awburst_s0(),
               .dbg_awlock_s0(),
               .dbg_awcache_s0(),
               .dbg_awprot_s0(),
               .dbg_awvalid_s0(),
               .dbg_awready_s0(),

               .dbg_wid_s0(),
               .dbg_wdata_s0(),
               .dbg_wstrb_s0(),
               .dbg_wlast_s0(),
               .dbg_wvalid_s0(),
               .dbg_wready_s0(),
	
               .dbg_bid_s0(),
               .dbg_bresp_s0(),
               .dbg_bvalid_s0(),
               .dbg_bready_s0(),

               .dbg_arid_s0(),
               .dbg_araddr_s0(),
               .dbg_arlen_s0(),
               .dbg_arsize_s0(),
               .dbg_arburst_s0(),
               .dbg_arlock_s0(),
               .dbg_arcache_s0(),
               .dbg_arprot_s0(),
               .dbg_arvalid_s0(),
               .dbg_arready_s0(),

               .dbg_rid_s0(),
               .dbg_rdata_s0(),
               .dbg_rresp_s0(),
               .dbg_rvalid_s0(),
               .dbg_rlast_s0(),
               .dbg_rready_s0()
);



endmodule

