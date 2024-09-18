`timescale 1ns / 1ps 

module AsyncTxFIFO #(
  parameter MAC_DATA_WIDTH = 64,
  parameter MAC_KEEP_WIDTH = MAC_DATA_WIDTH / 8,
  parameter PORT_NUM = 1
  )
  (
    input   wire            sysclk,
    input   wire            ethclk,        
    input   wire            rst_n,

    input   wire [`DMA_DATA_WIDTH-1:0]    tx_axis_data,
    input   wire                          tx_axis_valid,
    input   wire [`DMA_KEEP_WIDTH-1:0]    tx_axis_keep,
    input                                 tx_axis_last,
    output  wire                          tx_axis_ready,

    output reg [MAC_DATA_WIDTH-1:0]     tx_axis_mac_data,
    output wire                         tx_axis_mac_valid,
    output reg [MAC_KEEP_WIDTH-1:0]     tx_axis_mac_keep,
    output wire                         tx_axis_mac_last,
    input  wire                         tx_axis_mac_ready

    ,output reg [31:0]                           packet_cnt
    ,output reg [31:0]                           udp_cnt
    ,output reg [31:0]                           tcp_cnt

  );

//ila_eth_roce ila_eth_roce_inst(
//    .clk(sysclk),
//    .probe0(tx_axis_valid),
//    .probe1(tx_axis_last),
//    .probe2(tx_axis_ready),
//    .probe3(tx_axis_mac_ready)
//);

localparam CYCLE_COUNT      = `DMA_DATA_WIDTH / MAC_DATA_WIDTH; /* number of cycle to joint the data, 4 * 128 -> 512 */
localparam FIFO_WIDTH       = `DMA_DATA_WIDTH + `DMA_KEEP_WIDTH + 1;
localparam LAST_POS         = FIFO_WIDTH - 1;

wire fifo_empty;
wire fifo_full;
wire fifo_rd;
wire fifo_wr;

wire [`DMA_DATA_WIDTH-1:0]    tx_axis_data_fifo;
wire [`DMA_KEEP_WIDTH-1:0]    tx_axis_keep_fifo;
wire                          tx_axis_last_fifo;

reg [MAC_KEEP_WIDTH-1:0]      tx_axis_mac_keep_next;

reg   [7:0] cycle_cnt; // 4 cycle data joint into one 512 data, so the 4 cycle to joint one fifo data


assign fifo_wr = tx_axis_valid && tx_axis_ready;
assign fifo_rd = tx_axis_mac_valid && tx_axis_mac_ready && (tx_axis_mac_last || cycle_cnt[1:0] == 'b11);

assign tx_axis_mac_valid = ~fifo_empty;

assign tx_axis_ready = ~fifo_full;


/* cycle_cnt increment one per cycle when data_valid */
always@(posedge ethclk ) begin
  if(!rst_n) begin
    cycle_cnt <= `TD 'b0;
  end else begin
    if(tx_axis_mac_valid && tx_axis_mac_ready && tx_axis_mac_last) begin
      cycle_cnt <= `TD 'b0;
    end else if(tx_axis_mac_valid && tx_axis_mac_ready) begin
      cycle_cnt <= `TD cycle_cnt + 1'b1;
    end
  end
end

assign tx_axis_mac_last = tx_axis_last_fifo && 
                          (tx_axis_mac_keep != 'hff ||
                          cycle_cnt[1:0] == 'b11 ||
                          (tx_axis_mac_keep == 'hff && tx_axis_mac_keep_next == 'b0));

always@(*) begin
  case (cycle_cnt[1:0])
    0:begin
      tx_axis_mac_data  =  tx_axis_data_fifo[MAC_DATA_WIDTH*0 +: MAC_DATA_WIDTH];
      tx_axis_mac_keep  =  tx_axis_keep_fifo[MAC_KEEP_WIDTH*0 +: MAC_KEEP_WIDTH];
    end
    1:begin
      tx_axis_mac_data  =  tx_axis_data_fifo[MAC_DATA_WIDTH*1 +: MAC_DATA_WIDTH];
      tx_axis_mac_keep  =  tx_axis_keep_fifo[MAC_KEEP_WIDTH*1 +: MAC_KEEP_WIDTH];
    end
    2:begin
      tx_axis_mac_data  =  tx_axis_data_fifo[MAC_DATA_WIDTH*2 +: MAC_DATA_WIDTH];
      tx_axis_mac_keep  =  tx_axis_keep_fifo[MAC_KEEP_WIDTH*2 +: MAC_KEEP_WIDTH];
    end
    3:begin
      tx_axis_mac_data  =  tx_axis_data_fifo[MAC_DATA_WIDTH*3 +: MAC_DATA_WIDTH];
      tx_axis_mac_keep  =  tx_axis_keep_fifo[MAC_KEEP_WIDTH*3 +: MAC_KEEP_WIDTH];
    end
    default:begin
      tx_axis_mac_data  =  'b0;
      tx_axis_mac_keep  =  'b0;
    end    
  endcase
end

always@(*) begin
  case (cycle_cnt[1:0])
    0:begin
      tx_axis_mac_keep_next  =  tx_axis_keep_fifo[MAC_KEEP_WIDTH*1 +: MAC_KEEP_WIDTH];
    end
    1:begin
      tx_axis_mac_keep_next  =  tx_axis_keep_fifo[MAC_KEEP_WIDTH*2 +: MAC_KEEP_WIDTH];
    end
    2:begin
      tx_axis_mac_keep_next  =  tx_axis_keep_fifo[MAC_KEEP_WIDTH*3 +: MAC_KEEP_WIDTH];
    end
    default:begin
      tx_axis_mac_keep_next  =  'b0;
    end    
  endcase
end

AsyncFIFO_289w_512d_FWFT async_tx_fifo(
  .rd_clk(ethclk),
  .wr_clk(sysclk),
  .rst(~rst_n),                 
  .din({tx_axis_last, tx_axis_keep, tx_axis_data}),                    
  .wr_en(fifo_wr),               
  .rd_en(fifo_rd),              
  .dout({tx_axis_last_fifo, tx_axis_keep_fifo, tx_axis_data_fifo}),
  .full(fifo_full),             
  .empty(fifo_empty)
);


reg is_tcp;
reg is_udp;

always@(posedge sysclk ) begin
  if(!rst_n) begin
    packet_cnt                <= `TD 'b0;
    tcp_cnt                   <= `TD 'b0;
    udp_cnt                   <= `TD 'b0;
  end else begin
    if(tx_axis_valid && tx_axis_ready && tx_axis_last) begin
      packet_cnt <= `TD packet_cnt + 1'b1;
      if(is_tcp) 
        tcp_cnt <= `TD tcp_cnt + 1'b1;
      if(is_udp)
        udp_cnt <= `TD udp_cnt + 1'b1;
    end
  end
end

reg [7:0] test_cycle;

always@(posedge sysclk ) begin
  if(!rst_n) begin
    test_cycle <= `TD 'b0;
  end else begin
    if(tx_axis_valid && tx_axis_ready && tx_axis_last) begin
      test_cycle <= `TD 'b0;
    end else if(tx_axis_valid && tx_axis_ready) begin
      test_cycle <= `TD test_cycle + 1'b1;
    end
  end
end

always@(posedge sysclk ) begin
  if(!rst_n) begin
    is_udp                <= `TD 'b0;
    is_tcp                <= `TD 'b0;
  end else begin
    if(tx_axis_valid && tx_axis_ready && tx_axis_last) begin
      is_udp <= `TD 'b0;
      is_tcp <= `TD 'b0;
    end else if(tx_axis_valid && tx_axis_ready && test_cycle == 'b0) begin
      is_udp <= (tx_axis_data[23*8 +: 8] == 8'h11) && ({tx_axis_data[12*8 +: 8], tx_axis_data[13*8 +: 8]} == 16'h0800);
      is_tcp <= (tx_axis_data[23*8 +: 8] == 8'h06) && ({tx_axis_data[12*8 +: 8], tx_axis_data[13*8 +: 8]} == 16'h0800);
    end else begin
      is_udp <= `TD is_udp;
      is_tcp <= `TD is_tcp;
    end
  end
end

// wire tx_axis_mac_valid_ready;
// assign tx_axis_mac_valid_ready = tx_axis_mac_valid && tx_axis_mac_ready;

// ila_mac_64 ila_mac_tx_64(
//   .clk(ethclk),
//   .probe0({fifo_full, tx_axis_mac_ready,tx_axis_mac_valid, tx_axis_mac_data[60:0]}),
//   .probe1(tx_axis_mac_valid_ready),
//   .probe2(tx_axis_mac_keep),
//   .probe3(tx_axis_mac_last )
// );

// wire tx_axis_valid_ready;

// assign tx_axis_valid_ready = tx_axis_valid && tx_axis_ready;

// ila_dma_keep ila_mac_tx(
//   .clk(sysclk),
//   .probe0(tx_axis_valid_ready ),
//   .probe1(tx_axis_last),
//   .probe2(tx_axis_data),
//   .probe3(tx_axis_keep )
// );


// ila_fifo_full ila_async_txfifo_full(
//   .clk(sysclk),
//   .probe0(fifo_wr ),
//   .probe1(fifo_full),
//   .probe2(wr_data_count)
// );


endmodule