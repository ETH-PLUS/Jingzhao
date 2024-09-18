`timescale 1ns / 100ps
//*************************************************************************
// > File Name: axi_convert.v
// > Author   : Li jianxiong
// > Date     : 2021-10-12
// > Note     : axi_convert is used to manage nic s, including queue number, addr offset .etc
// > V1.1 - 2021-10-12 : 
//*************************************************************************

`include "eth_engine_def.vh"

module axi_convert #(
    /* axil parameter */
  parameter AXIL_ADDR_WIDTH = 32,
  parameter ILA_DEBUG = 0  
) 
(
  input wire clk,
  input wire rst_n,

  /*axil write signal*/
  input wire [AXIL_ADDR_WIDTH-1:0]              awaddr_s,
  input wire                                    awvalid_s,
  output  wire                                  awready_s,
  input wire [`AXIL_DATA_WIDTH-1:0]             wdata_s,
  input wire [`AXIL_STRB_WIDTH-1:0]             wstrb_s,
  input wire                                    wvalid_s,
  output  wire                                  wready_s,
  output  wire                                  bvalid_s,
  input wire                                    bready_s,

  /*axil read signal*/
  input wire [AXIL_ADDR_WIDTH-1:0]              araddr_s,
  input wire                                    arvalid_s,
  output  wire                                  arready_s,
  output  wire [`AXIL_DATA_WIDTH-1:0]           rdata_s,
  output  wire                                  rvalid_s,
  input wire                                    rready_s,

  output wire [AXIL_ADDR_WIDTH-1:0]             waddr,
  output wire [`AXIL_DATA_WIDTH-1:0]            wdata,
  output wire [`AXIL_STRB_WIDTH-1:0]            wstrb,
  output wire                                   wvalid,
  input  wire                                   wready,

  output wire [AXIL_ADDR_WIDTH-1:0]             raddr,
  output wire                                   rvalid,
  input  wire [`AXIL_DATA_WIDTH-1:0]            rdata,
  input  wire                                   rready
);

localparam WRITE_IDLE = 0,
            WRITE_DATA = 1,
            WRITE_RESP = 2;
  
localparam READ_IDLE = 0,
            READ_INTER = 1,
            READ_DATA = 2;

reg [1:0]   write_state_cur;
wire [1:0]  write_state_next;

reg [1:0]   read_state_cur;
wire [1:0]  read_state_next;

reg [AXIL_ADDR_WIDTH-1:0] awaddr_s_reg;
reg [AXIL_ADDR_WIDTH-1:0] araddr_s_reg;

assign write_state_next = write_state_cur == WRITE_IDLE && awvalid_s && awready_s ? WRITE_DATA :
                          write_state_cur == WRITE_DATA && wvalid_s && wready_s ? WRITE_RESP :
                          write_state_cur == WRITE_RESP && bvalid_s && bready_s ? WRITE_IDLE : write_state_cur;

assign awready_s = write_state_cur == WRITE_IDLE;

assign wready_s = write_state_cur == WRITE_DATA && wready;
assign bvalid_s = write_state_cur == WRITE_RESP;

assign wvalid = write_state_cur == WRITE_DATA && wvalid_s;
assign waddr  = awaddr_s_reg;
assign wdata  = wdata_s;
assign wstrb  = wstrb_s;

always @(posedge clk, negedge rst_n) begin
  if(!rst_n)  awaddr_s_reg <= `TD 'b0;
  else        awaddr_s_reg <= `TD awvalid_s && awready_s ? awaddr_s : awaddr_s;  
end

/*axil read signal*/
reg [`AXIL_DATA_WIDTH-1:0]           rdata_reg;

assign read_state_next = read_state_cur == READ_IDLE && arvalid_s && arready_s ? READ_INTER :
                          read_state_cur == READ_INTER && rvalid && rready ? READ_DATA : 
                          read_state_cur == READ_DATA && rvalid_s && rready_s ? READ_IDLE : read_state_cur;

assign arready_s  = read_state_cur == READ_IDLE;

assign raddr      = araddr_s_reg;
assign rvalid     = read_state_cur == READ_INTER;

assign rvalid_s   = read_state_cur == READ_DATA;
assign rdata_s    = rdata_reg;

always @(posedge clk, negedge rst_n) begin
  if(!rst_n)  araddr_s_reg <= `TD 'b0;
  else        araddr_s_reg <= `TD arvalid_s && arready_s ? araddr_s : araddr_s_reg;  
end

always @(posedge clk, negedge rst_n) begin
  if(!rst_n)  rdata_reg <= `TD 'b0;
  else        rdata_reg <= `TD rvalid && rready ? rdata : rdata_reg;  
end

always @(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    read_state_cur <= `TD READ_IDLE;
    write_state_cur <= `TD WRITE_IDLE;
  end else begin
    read_state_cur <= `TD read_state_next;
    write_state_cur <= `TD write_state_next;
  end
end

// generate
//   if(ILA_DEBUG) begin: ILA_TEST
//     ila_axi_test ila_space_arbiter_inst(
//       .clk(clk),
//       .probe0(araddr_s),
//       .probe1(arvalid_s),
//       .probe2(arready_s),
//       .probe3(rdata_s),
//       .probe4(rvalid_s),
//       .probe5(rready_s)
//     );
//   end
// endgenerate


endmodule