`timescale 1ns / 1ps 

module AsyncRxFIFO #(
  parameter MAC_DATA_WIDTH = 64,
  parameter MAC_KEEP_WIDTH = MAC_DATA_WIDTH / 8,
  parameter PORT_NUM = 1
  )
  (
    input   wire            sysclk,
    input   wire            ethclk,        
    input   wire            rst_n,

    output  wire [`DMA_DATA_WIDTH-1:0]    rx_axis_data,
    output  wire                          rx_axis_valid,
    output  wire [`DMA_KEEP_WIDTH-1:0]    rx_axis_keep,
    output                                rx_axis_last,
    input   wire                          rx_axis_ready,

    input  wire [MAC_DATA_WIDTH-1:0]   rx_axis_mac_data,
    input  wire                        rx_axis_mac_valid,
    input  wire [MAC_KEEP_WIDTH-1:0]   rx_axis_mac_keep,
    input                              rx_axis_mac_last,
    output wire                        rx_axis_mac_ready

    ,output reg [31:0]                           packet_cnt
    ,output reg [31:0]                           udp_cnt
    ,output reg [31:0]                           tcp_cnt

  );

localparam CYCLE_COUNT      = `DMA_DATA_WIDTH / MAC_DATA_WIDTH; /* number of cycle to joint the data, 4 * 128 -> 512 */
localparam FIFO_WIDTH       = `DMA_DATA_WIDTH + `DMA_KEEP_WIDTH + 1;
localparam LAST_POS         = FIFO_WIDTH - 1;

wire fifo_empty;
wire fifo_full;
wire fifo_rd;
wire fifo_wr;

wire  [FIFO_WIDTH-1:0]  joint_data; /* joint data,  because the data width of the mac is 128 and the fifo is 512*/
reg   [FIFO_WIDTH-1:0]  joint_data_reg; /* store the joint data */

reg   [7:0] cycle_cnt; // 4 cycle data joint into one 512 data, so the 4 cycle to joint one fifo data

wire [`DMA_DATA_WIDTH-1:0]    rx_axis_data_fifo;
wire [`DMA_KEEP_WIDTH-1:0]    rx_axis_keep_fifo;
wire                          rx_axis_last_fifo;

generate
  genvar j;
  for(j = 0; j < `DMA_KEEP_WIDTH; j = j + 1) begin:generate_data_mask
    assign rx_axis_data[j*8 +:8] = rx_axis_keep_fifo[j]  ? rx_axis_data_fifo[j*8 +: 8] : 8'b0;
  end
endgenerate

assign rx_axis_keep = rx_axis_keep_fifo;
assign rx_axis_last = rx_axis_last_fifo && rx_axis_valid;


assign fifo_wr = rx_axis_mac_valid && rx_axis_mac_ready && (rx_axis_mac_last || cycle_cnt[1:0] == 'b11);
assign fifo_rd = rx_axis_valid && rx_axis_ready;

assign rx_axis_valid = ~fifo_empty;

assign rx_axis_mac_ready = ~fifo_full;


generate
  genvar k;
  for(k = 0; k < CYCLE_COUNT; k = k + 1) begin
    assign joint_data[MAC_DATA_WIDTH*k +: MAC_DATA_WIDTH]                     = (cycle_cnt[1:0] == k ? rx_axis_mac_data : joint_data_reg[MAC_DATA_WIDTH*k +: MAC_DATA_WIDTH]);
    assign joint_data[`DMA_DATA_WIDTH + MAC_KEEP_WIDTH*k +: MAC_KEEP_WIDTH]   = (cycle_cnt[1:0] == k ? rx_axis_mac_keep : joint_data_reg[`DMA_DATA_WIDTH + MAC_KEEP_WIDTH*k +: MAC_KEEP_WIDTH]);
  end
endgenerate

assign joint_data[LAST_POS] = rx_axis_mac_last;

/* cycle_cnt increment one per cycle when data_valid */
always@(posedge ethclk) begin
  if(!rst_n) begin
    cycle_cnt = 'b0;
  end else begin
    if(rx_axis_mac_valid && rx_axis_mac_ready && rx_axis_mac_last) begin
      cycle_cnt <= `TD 'b0;
    end else if(rx_axis_mac_valid && rx_axis_mac_ready) begin
      cycle_cnt <= `TD cycle_cnt + 1'b1;
    end
  end
end

/* store the joint_data and frame_len, when last cycle or the fourth cycle, store in the fifo */
always@(posedge ethclk) begin
  if(!rst_n) begin
    joint_data_reg        <= `TD 'b0;
  end else begin
    if(rx_axis_mac_valid && rx_axis_mac_ready && rx_axis_mac_last) begin
      joint_data_reg      <= `TD 'b0;
    end else if(rx_axis_mac_valid && rx_axis_mac_ready && cycle_cnt[1:0] == 'b11) begin
      joint_data_reg      <= `TD 'b0;
    end else if(rx_axis_mac_valid && rx_axis_mac_ready) begin
      joint_data_reg      <= `TD joint_data;
    end
  end
end

wire [9:0] wr_data_count;


AsyncFIFO_289w_512d_FWFT async_rx_fifo(
  .rd_clk(sysclk),
  .wr_clk(ethclk),        
  .rst(~rst_n),                 
  .din(joint_data),                    
  .wr_en(fifo_wr),               
  .rd_en(fifo_rd),               //qEthFrameDS_RdEn
  .dout({rx_axis_last_fifo, rx_axis_keep_fifo, rx_axis_data_fifo}),
  .full(fifo_full),             
  .empty(fifo_empty),
  .wr_data_count(wr_data_count)
);


reg is_tcp;
reg is_udp;

always@(posedge sysclk ) begin
  if(!rst_n) begin
    packet_cnt                <= `TD 'b0;
    tcp_cnt                   <= `TD 'b0;
    // udp_cnt                   <= `TD 'b0;
  end else begin
    if(rx_axis_valid && rx_axis_ready && rx_axis_last) begin
      packet_cnt <= `TD packet_cnt + 1'b1;
      if(is_tcp) 
        tcp_cnt <= `TD tcp_cnt + 1'b1;
      // if(is_udp)
      //   udp_cnt <= `TD udp_cnt + 1'b1;
    end
  end
end

always@(posedge ethclk ) begin
  if(!rst_n) begin
    udp_cnt                   <= `TD 'b0;
  end else begin
    if(rx_axis_mac_valid && rx_axis_mac_ready && rx_axis_mac_last) begin
      udp_cnt <= `TD udp_cnt + 1'b1;
    end
  end
end

reg [7:0] test_cycle;

always@(posedge sysclk ) begin
  if(!rst_n) begin
    test_cycle <= `TD 'b0;
  end else begin
    if(rx_axis_valid && rx_axis_ready && rx_axis_last) begin
      test_cycle <= `TD 'b0;
    end else if(rx_axis_valid && rx_axis_ready) begin
      test_cycle <= `TD test_cycle + 1'b1;
    end
  end
end

always@(posedge sysclk ) begin
  if(!rst_n) begin
    is_udp                <= `TD 'b0;
    is_tcp                <= `TD 'b0;
  end else begin
    if(rx_axis_valid && rx_axis_ready && rx_axis_last) begin
      is_udp <= `TD 'b0;
      is_tcp <= `TD 'b0;
    end else if(rx_axis_valid && rx_axis_ready && test_cycle == 'b0) begin
      is_udp <= (rx_axis_data[23*8 +: 8] == 8'h11) && ({rx_axis_data[12*8 +: 8], rx_axis_data[13*8 +: 8]} == 16'h0800);
      is_tcp <= (rx_axis_data[23*8 +: 8] == 8'h06) && ({rx_axis_data[12*8 +: 8], rx_axis_data[13*8 +: 8]} == 16'h0800);
    end else begin
      is_udp <= `TD is_udp;
      is_tcp <= `TD is_tcp;
    end
  end
end

// wire is_zero;
// assign is_zero = rx_axis_data[255:240] == 'b0 && rx_axis_valid;

// wire is_zero_mac;
// assign is_zero_mac = rx_axis_mac_data[63:48] == 'b0 && rx_axis_mac_valid;

// ila_mac_64 ila_mac_rx_64(
//   .clk(ethclk),
//   .probe0(rx_axis_mac_data),
//   .probe1(rx_axis_mac_valid),
//   .probe2(rx_axis_mac_keep),
//   .probe3(rx_axis_mac_last ),
//   .probe4(rx_axis_mac_ready)
// );

// ila_asyncRxFIFO_test ila_mac_rx_test(
//   .clk(ethclk),
//   .probe0(rx_axis_mac_data),
//   .probe1(rx_axis_mac_valid),
//   .probe2(rx_axis_mac_keep),
//   .probe3(rx_axis_mac_last ),
//   .probe4(rx_axis_mac_ready),
//   .probe5(cycle_cnt[1:0]),
//   .probe6(fifo_wr),
//   .probe7(joint_data)
// );


// ila_dma_req ila_mac_rx(
//   .clk(sysclk),
//   .probe0(rx_axis_valid ),
//   .probe1(rx_axis_last),
//   .probe2(rx_axis_data),
//   .probe3({95'b0, is_zero, rx_axis_keep} ),
//   .probe4(rx_axis_ready)
// );

// wire rx_axis_mac_valid_ready;
// assign rx_axis_mac_valid_ready = rx_axis_mac_valid && rx_axis_mac_ready;

// ila_mac_64 ila_mac_rx_64(
//   .clk(ethclk),
//   .probe0(rx_axis_mac_data),
//   .probe1(rx_axis_mac_valid_ready),
//   .probe2(rx_axis_mac_keep),
//   .probe3(rx_axis_mac_last )
// );

// wire rx_axis_valid_ready;

// assign rx_axis_valid_ready = rx_axis_valid && rx_axis_ready;

// ila_dma_keep ila_mac_rx(
//   .clk(sysclk),
//   .probe0(rx_axis_valid_ready ),
//   .probe1(rx_axis_last),
//   .probe2(rx_axis_data),
//   .probe3(rx_axis_keep )
// );

// ila_fifo_full ila_async_rxfifo_full(
//   .clk(ethclk),
//   .probe0(fifo_wr ),
//   .probe1(fifo_full),
//   .probe2(fifo_rd)
// );

endmodule