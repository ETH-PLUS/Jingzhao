`timescale 1ns / 100ps
//*************************************************************************
// > File Name: mac_fifo.v
// > Author   : Li jianxiong
// > Date     : 2021-10-29
// > Note     : mac_fifo is used to receive the frame from mac and send the 
//              frame to the dma module
//              it implements a fifo inside.
//              mac is response for the integrity of the frame ,so in this module
//              we don't need to guarantee the frame integrity
//              
// > V1.1 - 2021-10-21 : 
//*************************************************************************

module mac_fifo 
(
  input   wire                              clk,
  input   wire                              rst_n,

  /*interface to mac rx ??? receive frame from  mac*/
  input wire                                  axis_rx_valid, 
  input wire                                  axis_rx_last,
  input wire [`DMA_DATA_WIDTH-1:0]            axis_rx_data,
  input wire [`DMA_KEEP_WIDTH-1:0]            axis_rx_data_be,
  output wire                                 axis_rx_ready,

  /* interface to rx_macproc, when receive a new frame, transmit status and frame length */
  output wire                                 rx_frame_fifo_valid,
  output wire [`ETH_LEN_WIDTH-1:0]            rx_frame_fifo_len,
  output wire [`STATUS_WIDTH-1:0]             rx_frame_fifo_status,

  /* interface to dma */
  output wire                               rx_axis_frame_wr_valid,
  output wire [`DMA_DATA_WIDTH-1:0]          rx_axis_frame_wr_data,
  output wire [`DMA_HEAD_WIDTH-1:0]          rx_axis_frame_wr_head,
  output wire                               rx_axis_frame_wr_last,
  input  wire                               rx_axis_frame_wr_ready,

  /* from rx_macproc,  get the the dma addr, dma the frame */
  input  wire [`DMA_ADDR_WIDTH-1:0]           rx_frame_dma_req_addr,
  input  wire [`STATUS_WIDTH-1:0]             rx_frame_dma_req_status,
  input  wire [`ETH_LEN_WIDTH-1:0]            rx_frame_dma_req_len,
  input  wire                                 rx_frame_dma_req_valid,
  output wire                                 rx_frame_dma_req_ready,

  /* to rx_macproc,  after finishing dma the frame, return the status */
  output wire                               rx_frame_dma_finish_valid,
  output wire [`STATUS_WIDTH-1:0]           rx_frame_dma_finish_status

  ,output reg [31:0]                           mac_fifo_rev_cnt
  ,output reg [31:0]                           mac_fifo_send_cnt
  ,output reg [31:0]                           mac_fifo_error_cnt

`ifdef ETH_CHIP_DEBUG
	// ,output wire 	[`RW_DATA_NUM_MAC_FIFO * 32 - 1 : 0]	init_rw_data
	,input 	wire 	[`RW_DATA_NUM_MAC_FIFO * 32 - 1 : 0]	rw_data
  // ,input 	  wire		[0 : 0] 		Rw_data
	// ,output 	wire 		[0 : 0] 		Ro_data
  ,input 	  wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_sel
	,output 	wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_bus
	//,output 	wire 		[`MAC_FIFO_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_bus
`endif
);


/* fifo signal */
wire  fifo_full;
wire  fifo_wr;
wire  fifo_empty;

/* calculate the frame length */
wire [`ETH_LEN_WIDTH-1:0]     frame_len; // the total length of the frame
reg  [`ETH_LEN_WIDTH-1:0]     frame_len_reg;

wire [9:0] empty_entry_num;

/* -------receive a frame and calculate the length {begin}------- */
assign axis_rx_ready = !fifo_full;

/* function to calculate the frame_len using byte enable signal*/
function [`ETH_LEN_WIDTH-1:0] f_frame_len(
  input [`DMA_KEEP_WIDTH-1:0]  data_be
);
  integer i;
  begin
    f_frame_len = 0;
    for(i = 0; i < `DMA_KEEP_WIDTH; i = i + 1) begin
      f_frame_len = f_frame_len + data_be[i];
    end
  end
endfunction

assign frame_len = axis_rx_last ? frame_len_reg + f_frame_len(axis_rx_data_be) : frame_len_reg + `DMA_KEEP_WIDTH;

/* store the joint_data and frame_len, when last cycle or the fourth cycle, store in the fifo */
always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    frame_len_reg         <= `TD 'b0;
  end else begin
    if(axis_rx_last && axis_rx_valid && axis_rx_ready) begin
      frame_len_reg         <= `TD 'b0;
    end else if(axis_rx_valid && axis_rx_ready) begin
      frame_len_reg   <= `TD frame_len;
    end
  end
end

/* when finish receive a frame , send status to the rx_frameproc */
assign rx_frame_fifo_valid    = axis_rx_last && axis_rx_valid && axis_rx_ready;
assign rx_frame_fifo_len      = frame_len;
assign rx_frame_fifo_status   = 8'hFF;
/* -------receive a frame and calculate the length {end}------- */

/* -------transmit the frame to dma {begin}------- */
localparam  TRANS_IDLE = 0,
            TRANS_WORK = 1,
            TRANS_ERROR = 2;

reg   [1:0] state_trans;
wire  [1:0] state_trans_next;

wire  fifo_rd;

wire                                  axis_rx_last_fifo;
wire [`DMA_DATA_WIDTH-1:0]            axis_rx_data_fifo;

reg [`DMA_ADDR_WIDTH-1:0]           rx_frame_dma_req_addr_reg;
reg [`ETH_LEN_WIDTH-1:0]            rx_frame_dma_req_len_reg;

assign rx_frame_dma_req_ready = state_trans == TRANS_IDLE;

assign state_trans_next = (state_trans == TRANS_IDLE  && rx_frame_dma_req_valid && rx_frame_dma_req_status == 8'hFF) ? TRANS_WORK : 
                          (state_trans == TRANS_IDLE  && rx_frame_dma_req_valid && rx_frame_dma_req_status == 8'h00) ? TRANS_ERROR : 
                          (state_trans == TRANS_WORK  && rx_axis_frame_wr_valid && rx_axis_frame_wr_last && rx_axis_frame_wr_ready) ? TRANS_IDLE :
                          (state_trans == TRANS_ERROR && rx_axis_frame_wr_last) ? TRANS_IDLE : state_trans;

/* if the desc is error , */
assign fifo_rd = (state_trans == TRANS_WORK && rx_axis_frame_wr_valid && rx_axis_frame_wr_ready) 
                  || (state_trans == TRANS_ERROR);

assign rx_axis_frame_wr_valid =  state_trans == TRANS_WORK;
assign rx_axis_frame_wr_data  =  axis_rx_data_fifo;
assign rx_axis_frame_wr_head  =  {32'b01, /* write */
                                  rx_frame_dma_req_addr_reg, 
                                  16'b0, 
                                  rx_frame_dma_req_len_reg};
assign rx_axis_frame_wr_last  =  axis_rx_last_fifo && !fifo_empty;

/* transmit finish */
assign rx_frame_dma_finish_valid  = (state_trans == TRANS_WORK || state_trans == TRANS_ERROR) && state_trans_next == TRANS_IDLE;
assign rx_frame_dma_finish_status = 8'hFF;

always @(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    rx_frame_dma_req_addr_reg       <= `TD 'b0;
    rx_frame_dma_req_len_reg        <= `TD 'b0;
  end else begin
    if(state_trans == TRANS_IDLE && state_trans_next == TRANS_WORK) begin
      rx_frame_dma_req_addr_reg       <= `TD  rx_frame_dma_req_addr;
      rx_frame_dma_req_len_reg        <= `TD  rx_frame_dma_req_len;
    end else begin
      rx_frame_dma_req_addr_reg       <= `TD  rx_frame_dma_req_addr_reg;
      rx_frame_dma_req_len_reg        <= `TD  rx_frame_dma_req_len_reg;
    end
  end
end

always@(posedge clk, negedge rst_n) begin  
  if(!rst_n) begin
    state_trans   <= `TD TRANS_IDLE;
  end else begin
    state_trans   <= `TD state_trans_next;
  end
end
/* -------transmit the frame to dma {end}------- */

assign fifo_wr = axis_rx_valid && axis_rx_ready;

eth_sync_fifo_2psram  
#( .DATA_WIDTH(`DMA_DATA_WIDTH + 1),
  .FIFO_DEPTH(`RX_PKT_FIFO_DEPTH)
) sync_fifo_2psram_udp_csum_inst (
  .clk  (clk  ),
  .rst_n(rst_n),
  .wr_en(fifo_wr),
  .din  ({axis_rx_last, axis_rx_data}),
  .full (),
  .progfull (fifo_full),
  .rd_en(fifo_rd),
  .dout ({axis_rx_last_fifo, axis_rx_data_fifo}),
  .empty(fifo_empty),
  .empty_entry_num(empty_entry_num),
  .count()
`ifdef ETH_CHIP_DEBUG
  ,.rw_data(rw_data)
`endif
);


always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    mac_fifo_rev_cnt                <= `TD 'b0;
  end else begin
    if(axis_rx_valid & axis_rx_last & axis_rx_ready) begin
      mac_fifo_rev_cnt <= `TD mac_fifo_rev_cnt + 1'b1;
    end
  end
end
always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    mac_fifo_send_cnt                <= `TD 'b0;
  end else begin
    if(rx_axis_frame_wr_valid && rx_axis_frame_wr_last && rx_axis_frame_wr_ready) begin
      mac_fifo_send_cnt <= `TD mac_fifo_send_cnt + 1'b1;
    end
  end
end

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    mac_fifo_error_cnt                <= `TD 'b0;
  end else begin
    if(state_trans == TRANS_ERROR && state_trans_next == TRANS_IDLE) begin
      mac_fifo_error_cnt <= `TD mac_fifo_error_cnt + 1'b1;
    end
  end
end


`ifdef ETH_CHIP_DEBUG

wire 		[`MAC_FIFO_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_data;

assign Dbg_data = {// wire
                  27'h0,
                  axis_rx_valid, axis_rx_last, axis_rx_data, axis_rx_data_be, axis_rx_ready, 
                  rx_frame_fifo_valid, rx_frame_fifo_len, rx_frame_fifo_status, rx_axis_frame_wr_valid, 
                  rx_axis_frame_wr_data, rx_axis_frame_wr_head, rx_axis_frame_wr_last, rx_axis_frame_wr_ready, 
                  rx_frame_dma_req_addr, rx_frame_dma_req_status, rx_frame_dma_req_len, rx_frame_dma_req_valid, 
                  rx_frame_dma_req_ready, rx_frame_dma_finish_valid, rx_frame_dma_finish_status, 
                  fifo_full, fifo_wr, fifo_empty, frame_len, empty_entry_num, state_trans_next, 
                  fifo_rd, axis_rx_last_fifo, axis_rx_data_fifo, 

                  // reg
                  mac_fifo_rev_cnt, mac_fifo_send_cnt, mac_fifo_error_cnt, frame_len_reg, state_trans, 
                  rx_frame_dma_req_addr_reg,  rx_frame_dma_req_len_reg

                  } ;

assign Dbg_bus = Dbg_data >> (Dbg_sel << 5);
//assign Dbg_bus = Dbg_data;

`endif


endmodule



