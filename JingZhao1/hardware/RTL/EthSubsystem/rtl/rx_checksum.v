`timescale 1ns / 100ps
//*************************************************************************
// > File Name: rx_checksum.v
// > Author   : Li jianxiong
// > Date     : 2021-10-29
// > Note     : rx_checksum is used to receive the frame from roce fifo and 
//              add the ip header to the frame
//              then transmit it to the mac
//              it implements a fifo inside.
//              
// > V1.1 - 2021-10-21 : 
//*************************************************************************

module rx_checksum #(
  parameter REVERSE = 1
)
(
  input   wire                              clk,
  input   wire                              rst_n,

  /*interface to mac tx  */
  input wire                                  axis_rx_valid, 
  input wire                                  axis_rx_last,
  input wire [`DMA_DATA_WIDTH-1:0]            axis_rx_data,
  input wire [`DMA_KEEP_WIDTH-1:0]            axis_rx_data_be,
  input wire                                  axis_rx_ready,

  /*interface to roce rx  */
  output wire                                 csum_valid,
  output wire [`CSUM_WIDTH-1:0]               csum_data,
  output wire [`STATUS_WIDTH-1:0]             csum_status

`ifdef ETH_CHIP_DEBUG
  // ,input 	  wire		[0 : 0] 		Rw_data
	// ,output 	wire 		[0 : 0] 		Ro_data

  ,input 	  wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_sel
	,output 	wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_bus
//	,output 	wire 		[`RX_CHECKSUM_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_bus
`endif

  `ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved |  | data_be | last |
     * |  255:64  |  |  63:32  |  0  |
     */
    ,output wire [255:0] debug
    /* ------- Debug interface {end}------- */
`endif
);

reg [15:0]  pkt_cycle;

wire [15:0] eth_type;
wire        ip_flag;
wire        tcp_flag;
wire        udp_flag;
wire [3:0]  ihl_flag;
wire [15:0] ip_len_flag;

reg         tcp_flag_reg;
reg         udp_flag_reg;
reg         ip_flag_reg;

wire axis_ready_valid;
wire axis_ready_last;

assign axis_ready_valid = axis_rx_valid && axis_rx_ready;
assign axis_ready_last  = axis_rx_valid && axis_rx_ready && axis_rx_last;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    pkt_cycle <= `TD 0;
  end else begin
    if(axis_ready_last) begin
      pkt_cycle <= `TD 0;
    end else if (axis_ready_valid) begin
      pkt_cycle <= `TD pkt_cycle + 1;
    end else begin
      pkt_cycle <= `TD pkt_cycle;
    end
  end
end

assign eth_type[15:8] = axis_rx_data[(12%`DMA_KEEP_WIDTH)*8 +: 8];
assign eth_type[7:0]  = axis_rx_data[(13%`DMA_KEEP_WIDTH)*8 +: 8];

assign ip_flag         = eth_type == 16'h0800;

assign ihl_flag          = axis_rx_data[(14%`DMA_KEEP_WIDTH)*8 +: 4];
assign tcp_flag          = (axis_rx_data[(23%`DMA_KEEP_WIDTH)*8 +: 8] == 8'h06) && ip_flag;

assign udp_flag          = (axis_rx_data[(23%`DMA_KEEP_WIDTH)*8 +: 8] == 8'h11) && ip_flag;

assign ip_len_flag[15:8] = axis_rx_data[(16%`DMA_KEEP_WIDTH)*8 +: 8];
assign ip_len_flag[7:0]  = axis_rx_data[(17%`DMA_KEEP_WIDTH)*8 +: 8];


// store the ihl, ipv4 flag
always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin 
    tcp_flag_reg      <= `TD 0;
    udp_flag_reg      <= `TD 0;
    ip_flag_reg       <= `TD 0;
  end else if(axis_ready_last) begin 
    tcp_flag_reg      <= `TD 0;
    udp_flag_reg      <= `TD 0;
    ip_flag_reg       <= `TD 0;
  end else if(pkt_cycle == 0) begin
    tcp_flag_reg      <= `TD tcp_flag;
    udp_flag_reg      <= `TD udp_flag;
    ip_flag_reg       <= `TD ip_flag;
  end else begin
    tcp_flag_reg      <= `TD tcp_flag_reg;
    udp_flag_reg      <= `TD udp_flag_reg;
    ip_flag_reg       <= `TD ip_flag_reg;
  end
end


/* -------checksum the ip {begin}------- */
wire                                tcp_csum_valid;
wire                                tcp_csum_last;
wire [`DMA_DATA_WIDTH-1:0]          tcp_csum_data;
wire [`DMA_KEEP_WIDTH-1:0]          tcp_csum_data_be;

wire [15:0]                         tcp_csum_out;
wire                                tcp_csum_out_valid;

wire [15:0] tcpl;
wire [7:0] ptcl;

wire [16:0] tmp_csum;
wire [15:0] tmp_csum_rev;

assign tcpl = ip_len_flag - (ihl_flag << 2);
assign ptcl = axis_rx_data[(23%`DMA_KEEP_WIDTH)*8 +: 8];

assign tmp_csum = {axis_rx_data[7:0], axis_rx_data[15:8]} + {axis_rx_data[7:0], axis_rx_data[15:8]};
assign tmp_csum_rev = tmp_csum[15:0] + tmp_csum[16];

assign tcp_csum_valid     = axis_ready_valid;

assign tcp_csum_last      = axis_rx_last;

/* add the vheader */
assign tcp_csum_data      = pkt_cycle == 0 ? {axis_rx_data[255:112],
                                                tcpl[7:0], tcpl[15:8], ptcl, 8'b0, axis_rx_data[255:208], 32'b0} : 
                            pkt_cycle == 1 ? {axis_rx_data[255:16],
                                               tmp_csum_rev[7:0], tmp_csum_rev[15:8] } : axis_rx_data;
                                                
assign tcp_csum_data_be   = axis_rx_data_be;


`ifdef ETH_CHIP_DEBUG
  // ,input 	  wire		[0 : 0] 		Rw_data
	// ,output 	  wire 		[0 : 0] 		Ro_data
	wire 		[(`CHECKSUM_UTIL_DEG_REG_NUM)  * 32 - 1 : 0]		  Dbg_data_checksum_util;
`endif



checksum_util #(
  .DATA_WIDTH(`DMA_DATA_WIDTH),
  .KEEP_WIDTH(`DMA_KEEP_WIDTH),
  .REVERSE(REVERSE),
  .START_OFFSET(0)
  ,.ILA_DEBUG(1)
)
ip_checksum_util
(
  .clk(clk),
  .rst_n(rst_n),

  /*interface to mac rx  */
  .csum_data_valid(tcp_csum_valid), 
  .csum_data_last(tcp_csum_last),
  .csum_data(tcp_csum_data),
  .csum_data_be(tcp_csum_data_be),

  /*otuput to rx_engine, csum is used for offload*/
  .csum_out(tcp_csum_out),
  .csum_out_valid(tcp_csum_out_valid)

`ifdef ETH_CHIP_DEBUG
  // ,input 	  wire		[0 : 0] 		Rw_data
	// ,output 	  wire 		[0 : 0] 		Ro_data
	,.Dbg_bus(Dbg_data_checksum_util)
`endif
);

reg [4:0] tcp_flag_store;
reg [4:0] udp_flag_store;
reg [4:0] ip_flag_store;



always@ (posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    tcp_flag_store  <= `TD 0;
    udp_flag_store  <= `TD 0;
    ip_flag_store   <= `TD 0;
  end else if(axis_ready_last) begin
    tcp_flag_store  <= `TD (tcp_flag_store << 1)  | {3'b0, tcp_flag_reg};
    udp_flag_store  <= `TD (udp_flag_store << 1)  | {3'b0, udp_flag_reg};
    ip_flag_store   <= `TD (ip_flag_store << 1)   | {3'b0, ip_flag_reg};
  end else begin
    tcp_flag_store  <= `TD tcp_flag_store << 1;
    udp_flag_store  <= `TD udp_flag_store << 1;
    ip_flag_store   <= `TD ip_flag_store << 1;
  end
end

wire tcp_csum_fail ;
wire udp_csum_fail ;

assign csum_valid   = tcp_csum_out_valid;

assign tcp_csum_fail    = tcp_csum_out != 0 && tcp_flag_store[4];
assign udp_csum_fail    = tcp_csum_out != 0 && udp_flag_store[4];
/*  status
  * 0000_0001 : tcp | udp
  * 0000_0000 : not
  */
assign csum_status  = {tcp_csum_fail, udp_csum_fail, tcp_flag_store[4], udp_flag_store[4], ip_flag_store[4]} ;
                      
assign csum_data  = tcp_csum_out;
/* -------checksum the ip {end}------- */


wire axis_valid_ready;

assign axis_valid_ready = axis_rx_valid & axis_rx_ready;

`ifdef ETH_CHIP_DEBUG

wire 		[`RX_CHECKSUM_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_data;


wire 		[(`RX_CHECKSUM_SELF_DEG_REG_NUM)  * 32 - 1 : 0]		  Dbg_data_rx_checksum;

assign Dbg_data_rx_checksum = {// wire
                  42'b0,
                  axis_rx_valid, axis_rx_last, axis_rx_data, axis_rx_data_be, 
                  axis_rx_ready, csum_valid, csum_data, csum_status, eth_type, ip_flag, tcp_flag, 
                  udp_flag, ihl_flag, ip_len_flag, axis_ready_valid, axis_ready_last,  
                  tcp_csum_valid, tcp_csum_last, tcp_csum_data, tcp_csum_data_be, tcp_csum_out, 
                  tcp_csum_out_valid, tcpl, ptcl, tmp_csum, tmp_csum_rev, tcp_csum_fail, udp_csum_fail, axis_valid_ready,

                  // reg
                  pkt_cycle, tcp_flag_reg, udp_flag_reg, ip_flag_reg, tcp_flag_store, udp_flag_store, ip_flag_store
                  } ;

assign Dbg_data = {Dbg_data_checksum_util, Dbg_data_rx_checksum};


assign Dbg_bus = Dbg_data >> (Dbg_sel << 5);
//assign Dbg_bus = Dbg_data;
`endif

// 8dw
// _f75c_276d_7116_a8a3_bf91_3f57_cb33_08f2_ca3d_ec4d_4b2e_b6ca_2557_d100_0000_01eb



`ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved |  | data_be | last |
     * |  255:64  |  |  63:32  |  0  |
     */
//  assign debug = {};
/* ------- Debug interface {end}------- */
`endif
endmodule

