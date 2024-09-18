`timescale 1ns / 100ps
//*************************************************************************
// > File Name: rx_distributor.v
// > Author   : Li jianxiong
// > Date     : 2021-10-12
// > Note     : rx_distributor is used for 
// > V1.1 - 2021-10-21 : 
//*************************************************************************
module rx_distributor #(
  /* parameters */
)
(
  input   wire                              clk,
  input   wire                              rst_n,

  input     wire                                  axis_rx_valid, 
  input     wire                                  axis_rx_last,
  input     wire [`DMA_DATA_WIDTH-1:0]            axis_rx_data,
  input     wire [`DMA_KEEP_WIDTH-1:0]            axis_rx_data_be,
  output    wire                                  axis_rx_ready,
  input     wire [`XBAR_USER_WIDTH-1:0]           axis_rx_user,
  input     wire                                  axis_rx_start,

  output wire [2 * 1 - 1:0]                         axis_rx_out_valid,
  output wire [2 * 1 - 1:0]                         axis_rx_out_last,
  output wire [2 * `DMA_DATA_WIDTH-1:0]             axis_rx_out_data,
  output wire [2 * `DMA_KEEP_WIDTH-1:0]             axis_rx_out_data_be,
  input  wire [2 * 1 - 1:0]                         axis_rx_out_ready,
  output wire [2 * `XBAR_USER_WIDTH - 1:0]          axis_rx_out_user,
  output wire [2 * 1 - 1:0]                         axis_rx_out_start

  `ifdef ETH_CHIP_DEBUG
  // ,input 	  wire		[0 : 0] 		Rw_data
	// ,output 	wire 		[0 : 0] 		Ro_data

  ,input 	  wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_sel
	,output 	wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_bus
	//,output 	wire 		[`RX_DISTRIBUTER_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_bus
`endif
);

localparam IDLE = 0,
            TRANS = 1;

reg [15:0] cycle;

wire axis_valid_ready;
wire axis_valid_last;

wire axis_out_valid_ready;
wire axis_out_valid_last;

wire frame_fifo_full;
wire frame_fifo_rd;
wire frame_fifo_empty;

wire is_roce_fifo_full;
wire is_roce_fifo_rd;
wire is_roce_fifo_empty;
wire is_roce_fifo_wr;
wire is_roce_fifo_out;

wire                  is_roce_fifo_in;
reg [7:0]             protocol;
wire [`PORT_WIDTH-1:0] sport;
wire [`PORT_WIDTH-1:0] dport;

reg                   is_roce_reg;

wire                                  fifo_axis_rx_last;
wire [`DMA_DATA_WIDTH-1:0]            fifo_axis_rx_data;
wire [`DMA_KEEP_WIDTH-1:0]            fifo_axis_rx_data_be;
wire [`XBAR_USER_WIDTH-1:0]           fifo_axis_rx_user;
wire                                  fifo_axis_rx_start;

/* -------is roce {end}------- */
assign axis_valid_ready = axis_rx_ready && axis_rx_valid;
assign axis_valid_last  = axis_rx_ready && axis_rx_valid && axis_rx_last;

assign axis_rx_ready  = !frame_fifo_full;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    protocol  <= `TD 0;
  end else if(axis_valid_last) begin
    protocol  <= `TD 0;
  end else if(axis_valid_ready && cycle == 0) begin
    protocol  <= `TD axis_rx_data[191:184];
  end else begin
    protocol  <= `TD protocol;
  end
end

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    cycle  <= `TD 0;
  end else if(axis_valid_last) begin
    cycle  <= `TD 0;
  end else if(axis_valid_ready) begin
    cycle  <= `TD cycle + 1;
  end else begin
    cycle  <= `TD cycle;
  end

end

assign sport = {axis_rx_data[23:16], axis_rx_data[31:24]};
assign dport = {axis_rx_data[39:32], axis_rx_data[47:40]};

assign is_roce_fifo_in = (cycle == 1 &&  protocol == 8'd17 && sport == 16'd4791 && dport == 16'd4791) ? 1 : 0;

assign is_roce_fifo_wr = (cycle == 0 && axis_valid_last) || (cycle == 1 && axis_valid_ready);
/* -------is roce {end}------- */


/* -------distribute the frame {begin}------- */

reg   state_cur;
wire  state_next;

assign state_next = (state_cur == IDLE && !is_roce_fifo_empty) ? TRANS : 
                          (state_cur == TRANS && axis_out_valid_last) ? IDLE : state_cur;

assign is_roce_fifo_rd = state_cur == IDLE && state_next == TRANS;

always@(posedge clk, negedge rst_n) begin
  is_roce_reg <= `TD (!rst_n) ? 0 : is_roce_fifo_rd ? is_roce_fifo_out : is_roce_reg;
end

always@(posedge clk, negedge rst_n) begin
  state_cur <= `TD (!rst_n) ? IDLE : state_next;
end

assign frame_fifo_rd = axis_out_valid_ready;

assign axis_out_valid_ready = (axis_rx_out_ready[0] && axis_rx_out_valid[0]) || 
                                (axis_rx_out_ready[1] && axis_rx_out_valid[1]);
assign axis_out_valid_last = (axis_rx_out_ready[0] && axis_rx_out_valid[0] && axis_rx_out_last[0]) || 
                                (axis_rx_out_ready[1] && axis_rx_out_valid[1] && axis_rx_out_last[1]);

assign axis_rx_out_valid      = (state_cur == TRANS && !frame_fifo_empty) ? (is_roce_reg ? 2'b10 : 2'b01 ) : 2'b00;
assign axis_rx_out_last       = {2{fifo_axis_rx_last}} & {2{axis_rx_out_valid}};
assign axis_rx_out_data       = {2{fifo_axis_rx_data}};
assign axis_rx_out_data_be    = {2{fifo_axis_rx_data_be}};
assign axis_rx_out_user       = {2{fifo_axis_rx_user}};
assign axis_rx_out_start      = {2{fifo_axis_rx_start}};

/* -------distribute the frame {begin}------- */


eth_sync_fifo_2psram
#( .DATA_WIDTH(1+`DMA_DATA_WIDTH+`DMA_KEEP_WIDTH+`XBAR_USER_WIDTH+1),
  .FIFO_DEPTH(`RX_DISTR_FIFO_DEPTH)
) sync_fifo_2psram_udp_csum_inst (
  .clk  (clk  ),
  .rst_n(rst_n),
  .wr_en(axis_rx_valid && axis_rx_ready),
  .din  ({axis_rx_last,
          axis_rx_data,
          axis_rx_data_be,
          axis_rx_user,
          axis_rx_start}),
  .full (),
  .progfull (frame_fifo_full),
  .rd_en(frame_fifo_rd),
  .dout ({fifo_axis_rx_last,
        fifo_axis_rx_data,
        fifo_axis_rx_data_be,
        fifo_axis_rx_user,
        fifo_axis_rx_start}),
  .empty(frame_fifo_empty),
  .empty_entry_num(),
  .count(),
	.rw_data(32'd0)
);

eth_sync_fifo_2psram
#( .DATA_WIDTH(1),
  .FIFO_DEPTH(`RX_DISTR_FIFO_DEPTH)
) sync_fifo_2psram_is_roce_inst (
  .clk  (clk  ),
  .rst_n(rst_n),
  .wr_en(is_roce_fifo_wr),
  .din  (is_roce_fifo_in),
  .full (),
  .progfull (is_roce_fifo_full),
  .rd_en(is_roce_fifo_rd),
  .dout (is_roce_fifo_out),
  .empty(is_roce_fifo_empty),
  .empty_entry_num(),
  .count(),
	.rw_data(32'd0)
);



`ifdef ETH_CHIP_DEBUG

wire 		[`RX_DISTRIBUTER_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_data;


assign Dbg_data = {// wire
                  14'b0,
                  axis_rx_valid, axis_rx_last, axis_rx_data, axis_rx_data_be, axis_rx_ready, axis_rx_user, 
                  axis_rx_start, axis_rx_out_valid, axis_rx_out_last, axis_rx_out_data, axis_rx_out_data_be, 
                  axis_rx_out_ready, axis_rx_out_user, axis_rx_out_start, axis_valid_ready, axis_valid_last, 
                  axis_out_valid_ready, axis_out_valid_last, frame_fifo_full, frame_fifo_rd, frame_fifo_empty, 
                  is_roce_fifo_full, is_roce_fifo_rd, is_roce_fifo_empty, is_roce_fifo_wr, is_roce_fifo_out, 
                  is_roce_fifo_in, sport, dport, fifo_axis_rx_last, fifo_axis_rx_data, fifo_axis_rx_data_be, 
                  fifo_axis_rx_user, fifo_axis_rx_start, state_next, 

                  // reg
                  cycle, protocol, is_roce_reg, state_cur
                  } ;
                  
assign Dbg_bus = Dbg_data >> (Dbg_sel << 5);
//assign Dbg_bus = Dbg_data;

`endif




endmodule
