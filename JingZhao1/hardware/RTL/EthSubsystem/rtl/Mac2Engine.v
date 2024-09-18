module MacToEngine #(
  parameter MAC_DATA_WIDTH = 64,
  parameter MAC_KEEP_WIDTH = MAC_DATA_WIDTH / 8,
  parameter PORT_NUM = 1
)(
    input   wire            sysclk,
    input   wire            ethclk,
    input   wire            rst_n,

    output  wire [`DMA_DATA_WIDTH-1:0]   rx_axis_data,
    output  wire                        rx_axis_valid,
    output  wire [`DMA_KEEP_WIDTH-1:0]   rx_axis_keep,
    output                              rx_axis_last,
    input   wire                        rx_axis_ready,

    input  wire [MAC_DATA_WIDTH-1:0]   rx_axis_mac_data,
    input  wire                        rx_axis_mac_valid,
    input  wire [MAC_KEEP_WIDTH-1:0]   rx_axis_mac_keep,
    input                              rx_axis_mac_last,
    output wire                        rx_axis_mac_ready,

    input   wire [`DMA_DATA_WIDTH-1:0]   tx_axis_data,
    input   wire                        tx_axis_valid,
    input   wire [`DMA_KEEP_WIDTH-1:0]   tx_axis_keep,
    input                               tx_axis_last,
    output  wire                        tx_axis_ready,

    output wire [MAC_DATA_WIDTH-1:0]   tx_axis_mac_data,
    output wire                        tx_axis_mac_valid,
    output wire [MAC_KEEP_WIDTH-1:0]   tx_axis_mac_keep,
    output                             tx_axis_mac_last,
    input  wire                        tx_axis_mac_ready

    ,output wire [31:0] tx_packet_cnt
    ,output wire [31:0] tx_tcp_cnt
    ,output wire [31:0] tx_udp_cnt
    ,output wire [31:0] rx_packet_cnt
    ,output wire [31:0] rx_tcp_cnt
    ,output wire [31:0] rx_udp_cnt
);

AsyncTxFIFO #(
.MAC_DATA_WIDTH(MAC_DATA_WIDTH),
.MAC_KEEP_WIDTH(MAC_KEEP_WIDTH),
.PORT_NUM(PORT_NUM)
)
AsyncTxFIFO_inst
(
.sysclk(sysclk),
.ethclk(ethclk),        
.rst_n(rst_n),

.tx_axis_data(tx_axis_data),
.tx_axis_valid(tx_axis_valid),
.tx_axis_keep(tx_axis_keep),
.tx_axis_last(tx_axis_last),
.tx_axis_ready(tx_axis_ready),

.tx_axis_mac_data(tx_axis_mac_data),
.tx_axis_mac_valid(tx_axis_mac_valid),
.tx_axis_mac_keep(tx_axis_mac_keep),
.tx_axis_mac_last(tx_axis_mac_last),
.tx_axis_mac_ready(tx_axis_mac_ready)

,.packet_cnt(tx_packet_cnt)
,.tcp_cnt(tx_tcp_cnt)
,.udp_cnt(tx_udp_cnt)
);


AsyncRxFIFO #(
.MAC_DATA_WIDTH(MAC_DATA_WIDTH),
.MAC_KEEP_WIDTH(MAC_KEEP_WIDTH),
.PORT_NUM(PORT_NUM)
)
AsyncRxFIFO_inst
(
.sysclk(sysclk),
.ethclk(ethclk),        
.rst_n(rst_n),

.rx_axis_data(rx_axis_data),
.rx_axis_valid(rx_axis_valid),
.rx_axis_keep(rx_axis_keep),
.rx_axis_last(rx_axis_last),
.rx_axis_ready(rx_axis_ready),

.rx_axis_mac_data(rx_axis_mac_data),
.rx_axis_mac_valid(rx_axis_mac_valid),
.rx_axis_mac_keep(rx_axis_mac_keep),
.rx_axis_mac_last(rx_axis_mac_last),
.rx_axis_mac_ready(rx_axis_mac_ready)

,.packet_cnt(rx_packet_cnt)
,.tcp_cnt(rx_tcp_cnt)
,.udp_cnt(rx_udp_cnt)
);

//ila_mac2engine ila_mac2engine_inst(
//    .clk(ethclk),
//    .probe0(tx_axis_data),
//    .probe1(tx_axis_valid),
//    .probe2(tx_axis_keep),
//    .probe3(tx_axis_last),
//    .probe4(tx_axis_ready),

//    .probe5(rx_axis_data),
//    .probe6(rx_axis_valid),
//    .probe7(rx_axis_keep),
//    .probe8(rx_axis_last),
//    .probe9(rx_axis_ready)
//);

endmodule