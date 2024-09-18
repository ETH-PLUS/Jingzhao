`timescale 1ns / 100ps
//*************************************************************************
// > File Name: ncsr_manager.v
// > Author   : Li jianxiong
// > Date     : 2021-10-12
// > Note     : ncsr_manager is used to manage nic csr, including queue number, addr offset .etc
// > V1.1 - 2021-10-12 : 
//*************************************************************************

module ncsr_manager #(
  /* axil parameter */
  parameter AXIL_ADDR_WIDTH = 20,

  /* some feature of the eth nic */
  parameter RX_RSS_ENABLE = 1, 
  parameter RX_HASH_ENABLE = 1,
  parameter TX_CHECKSUM_ENABLE = 1,
  parameter RX_CHECKSUM_ENABLE = 1,
  parameter RX_VLAN_ENABLE = 1,

  /* queue base addr */
  parameter TX_QUEUE_COUNT = 32,
  parameter AXIL_TX_QM_BASE_ADDR = 0,
  parameter TX_CPL_QUEUE_COUNT = 32,
  parameter AXIL_TX_CQM_BASE_ADDR = 0,   
  parameter RX_QUEUE_COUNT = 32 ,
  parameter AXIL_RX_QM_BASE_ADDR = 0,    
  parameter RX_CPL_QUEUE_COUNT = 32,
  parameter AXIL_RX_CQM_BASE_ADDR = 0,
  parameter TX_MTU = 1500,
  parameter RX_MTU = 1500
) 
(
  input wire clk,
  input wire rst_n,

  output reg                                  start_sche,
  output reg                                  msix_enable,

  /*axil write signal*/
  input wire [AXIL_ADDR_WIDTH-1:0]            awaddr_csr,
  input wire                                  awvalid_csr,
  output  wire                                awready_csr,
  input wire [`AXIL_DATA_WIDTH-1:0]            wdata_csr,
  input wire [`AXIL_STRB_WIDTH-1:0]            wstrb_csr,
  input wire                                  wvalid_csr,
  output  wire                                wready_csr,
  output  wire                                bvalid_csr,
  input wire                                  bready_csr,
  /*axil read signal*/
  input wire [AXIL_ADDR_WIDTH-1:0]            araddr_csr,
  input wire                                  arvalid_csr,
  output  wire                                arready_csr,
  output  wire [`AXIL_DATA_WIDTH-1:0]           rdata_csr,
  output  wire                                rvalid_csr,
  input wire                                  rready_csr

  ,input wire [31:0]                           tx_mac_proc_rec_cnt
  ,input wire [31:0]                           tx_mac_proc_xmit_cnt
  ,input wire [31:0]                           tx_mac_proc_cpl_cnt
  ,input wire [31:0]                           tx_mac_proc_msix_cnt

  ,input wire [31:0]                           rx_mac_proc_rec_cnt
  ,input wire [31:0]                           rx_mac_proc_desc_cnt
  ,input wire [31:0]                           rx_mac_proc_cpl_cnt
  ,input wire [31:0]                           rx_mac_proc_msix_cnt
  ,input wire [31:0]                           rx_mac_proc_error_cnt

  ,input wire [31:0]                           mac_fifo_rev_cnt
  ,input wire [31:0]                           mac_fifo_send_cnt
  ,input wire [31:0]                           mac_fifo_error_cnt

  ,input wire [31:0]                           tx_desc_fetch_req_cnt
  ,input wire [31:0]                           tx_desc_fetch_rsp_cnt
  ,input wire [31:0]                           tx_desc_fetch_error_cnt

  ,input wire [31:0]                           rx_desc_fetch_req_cnt
  ,input wire [31:0]                           rx_desc_fetch_rsp_cnt
  ,input wire [31:0]                           rx_desc_fetch_error_cnt

  `ifdef ETH_CHIP_DEBUG
  // ,input 	  wire		[0 : 0] 		Rw_data
	// ,output 	wire 		[0 : 0] 		Ro_data
  ,input 	  wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_sel
	,output 	wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_bus
	//,output 	wire 		[`NCSR_MANAGER_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_bus
`endif
);

wire [AXIL_ADDR_WIDTH-1:0]           waddr;
wire [`AXIL_DATA_WIDTH-1:0]           wdata;
wire [`AXIL_STRB_WIDTH-1:0]          wstrb;
wire                                 wvalid;
wire                                 wready;

wire [AXIL_ADDR_WIDTH-1:0]            raddr;
wire                                  rvalid;
reg [`AXIL_DATA_WIDTH-1:0]             rdata;
wire                                  rready;

axi_convert #(
    /* axil parameter */
  .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
  .ILA_DEBUG(0)
) 
axi_convert_inst
(
  .clk(clk),
  .rst_n(rst_n),

  /*axil write signal*/
  .awaddr_s(awaddr_csr),
  .awvalid_s(awvalid_csr),
  .awready_s(awready_csr),
  .wdata_s(wdata_csr),
  .wstrb_s(wstrb_csr),
  .wvalid_s(wvalid_csr),
  .wready_s(wready_csr),
  .bvalid_s(bvalid_csr),
  .bready_s(bready_csr),

  .waddr(waddr),
  .wdata(wdata),
  .wstrb(wstrb),
  .wvalid(wvalid),
  .wready(wready),

  /*axil read signal*/
  .araddr_s(araddr_csr),
  .arvalid_s(arvalid_csr),
  .arready_s(arready_csr),
  .rdata_s(rdata_csr),
  .rvalid_s(rvalid_csr),
  .rready_s(rready_csr),

  .raddr(raddr),
  .rvalid(rvalid),
  .rdata(rdata),
  .rready(rready)
);

assign wready = 1'b1;

always @(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    start_sche      <= `TD 0;
    msix_enable     <= `TD 1;
  end else begin
    if(wready && wvalid) begin
      case(waddr)
        12'h050: start_sche   <= `TD wdata[0];
        12'h054: msix_enable   <= `TD wdata[0];
      endcase
    end
  end
end

/*axil read signal*/
assign rready = 1'b1;

always @(*) begin
  if(rready && rvalid) begin
    case(raddr)
      12'h000:rdata =  32'hffff; /* FW_ID */
      12'h004:rdata =  32'heeee; /* FW_VER */
      12'h008:begin
        // interface features
        rdata[0]      = RX_RSS_ENABLE && RX_HASH_ENABLE;
        rdata[8]      = TX_CHECKSUM_ENABLE;
        rdata[9]      = RX_CHECKSUM_ENABLE;
        rdata[10]     = RX_HASH_ENABLE;
        rdata[11]     = RX_VLAN_ENABLE;
        rdata[7:1]    = 'b0;
        rdata[31:12]  = 'b0;
      end
      12'h00C:rdata = TX_QUEUE_COUNT;   /* HGRNIC_EN_REG_TX_QUEUE_COUNT */
      12'h010:rdata = AXIL_TX_QM_BASE_ADDR;         /* HGRNIC_EN_REG_TX_QUEUE_OFFSET */
      12'h014:rdata = TX_CPL_QUEUE_COUNT;     /* HGRNIC_EN_REG_TX_CPL_QUEUE_COUNT */
      12'h018:rdata = AXIL_TX_CQM_BASE_ADDR;         /* HGRNIC_EN_REG_TX_CPL_QUEUE_OFFSET */
      12'h01C:rdata = RX_QUEUE_COUNT;      /* HGRNIC_EN_REG_RX_QUEUE_COUNT */
      12'h020:rdata = AXIL_RX_QM_BASE_ADDR;       /* HGRNIC_EN_REG_RX_QUEUE_OFFSET */
      12'h028:rdata = RX_CPL_QUEUE_COUNT;  /* HGRNIC_EN_REG_RX_CPL_QUEUE_COUNT */
      12'h02C:rdata = AXIL_RX_CQM_BASE_ADDR;       /* HGRNIC_EN_REG_RX_CPL_QUEUE_OFFSET */
      // 12'h030:rdata  = 'b1;                        /* HGRNIC_EN_REG_PORT_COUNT */
      // 12'h034:rdata  = 'b0;                        /* HGRNIC_EN_REG_PORT_OFFSET */
      // 12'h038:rdata  = 'b0;                        /* HGRNIC_EN_REG_PORT_STRIDE */
      12'h03C:rdata = TX_MTU;                     /* HGRNIC_EN_REG_TX_MTU */
      12'h040:rdata = RX_MTU;                     /* HGRNIC_EN_REG_RX_MTU */
      12'h050:rdata = start_sche;                     /* HGRNIC_EN_REG_RX_MTU */
      12'h054:rdata = msix_enable;                     /* HGRNIC_EN_REG_RX_MTU */


      12'h100:rdata = tx_mac_proc_rec_cnt;
      12'h104:rdata = tx_mac_proc_xmit_cnt;
      12'h108:rdata = tx_mac_proc_cpl_cnt;
      12'h10C:rdata = tx_mac_proc_msix_cnt;
      12'h110:rdata = rx_mac_proc_rec_cnt;
      12'h114:rdata = rx_mac_proc_desc_cnt;
      12'h118:rdata = rx_mac_proc_cpl_cnt;
      12'h11C:rdata = rx_mac_proc_msix_cnt;
      12'h120:rdata = rx_mac_proc_error_cnt;
      12'h124:rdata = mac_fifo_rev_cnt;
      12'h128:rdata = mac_fifo_send_cnt;
      12'h12c:rdata = mac_fifo_error_cnt;
      12'h130:rdata = tx_desc_fetch_req_cnt;
      12'h134:rdata = tx_desc_fetch_rsp_cnt;
      12'h138:rdata = tx_desc_fetch_error_cnt;
      12'h13c:rdata = rx_desc_fetch_req_cnt;
      12'h140:rdata = rx_desc_fetch_rsp_cnt;
      12'h144:rdata = rx_desc_fetch_error_cnt;

      default: rdata  = {`AXIL_DATA_WIDTH{1'b0}};
    endcase
  end else begin
    rdata =  32'b0;
  end
end

`ifdef ETH_CHIP_DEBUG

wire 		[`NCSR_MANAGER_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_data;


assign Dbg_data = {// wire
                  31'b0,
                  tx_mac_proc_rec_cnt, tx_mac_proc_xmit_cnt, tx_mac_proc_cpl_cnt, tx_mac_proc_msix_cnt, 
                  rx_mac_proc_rec_cnt, rx_mac_proc_desc_cnt, rx_mac_proc_cpl_cnt, rx_mac_proc_msix_cnt, 
                  rx_mac_proc_error_cnt, mac_fifo_rev_cnt, mac_fifo_send_cnt, mac_fifo_error_cnt, 
                  tx_desc_fetch_req_cnt, tx_desc_fetch_rsp_cnt, tx_desc_fetch_error_cnt, rx_desc_fetch_req_cnt, 
                  rx_desc_fetch_rsp_cnt, rx_desc_fetch_error_cnt, 
                  waddr, wdata, wstrb, wvalid, wready, raddr, rvalid, rready, 

                  // reg
                  start_sche, rdata
                  } ;

assign Dbg_bus = Dbg_data >> (Dbg_sel << 5);
//assign Dbg_bus = Dbg_data;

`endif


//    ila_eth_cfg_ncsg_rd ila_eth_cfg_ncsg_rd_inst(
//        .clk(clk),
//        .probe0(araddr_csr),
//        .probe1(arvalid_csr),
//        .probe2(arready_csr),
//        .probe3(rdata_csr),
//        .probe4(rvalid_csr),
//        .probe5(rready_csr)
//    );


endmodule
