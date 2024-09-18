`timescale 1ns / 100ps
//*************************************************************************
// > File Name: rx_roceproc.v
// > Author   : Li jianxiong
// > Date     : 2021-10-29
// > Note     : rx_roceproc is used to receive the frame from roce fifo and 
//              add the ip header to the frame
//              then transmit it to the mac
//              it implements a fifo inside.
//              
// > V1.1 - 2021-10-21 : 
//*************************************************************************

module rx_roceproc #(
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
  output wire                                 axis_rx_ready,

  /*interface to roce rx  */
  input   wire                                i_roce_prog_full,
  output  wire [`DMA_DATA_WIDTH-1:0]          ov_roce_data,
  output  wire                                o_roce_wr_en

`ifdef ETH_CHIP_DEBUG
  ,input 	wire 	[`RW_DATA_NUM_RX_ROCEPORC * 32 - 1 : 0]	rw_data
	// ,output 	wire 		[0 : 0] 		Ro_data

  ,input 	  wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_sel
	,output 	wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_bus
	//,output 	wire 		[`RX_ROCEPROC_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_bus
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

localparam TRANS_IDLE = 0,
            TRANS_HEADER = 1,
            TRANS_PALOAD = 2,
            TRANS_LAST = 3;

localparam OFFSET_THRESH_32       = 32;
localparam OFFSET_THRESH_22       = 22;
localparam OFFSET_THRESH_10       = 10;

/* mask data */
function [`DMA_DATA_WIDTH-1:0] mask_data (
  input [`DMA_DATA_WIDTH-1:0] data,
  input [`DMA_KEEP_WIDTH-1:0] data_be);

	integer i;
	for (i=0; i<(`DMA_KEEP_WIDTH-1); i=i+8) 
    mask_data[i*8 +:8] = data_be[i] ? data[i*8 +: 8] : 8'b0;
endfunction 

reg   [1:0] state_trans;
wire  [1:0] state_trans_next;

reg [15:0] payload_len;


wire axis_ready_valid;
wire axis_ready_last;

assign axis_ready_valid = axis_rx_valid & axis_rx_ready;
assign axis_ready_last  = axis_rx_valid & axis_rx_ready && axis_rx_last;


/* data after joint with last signal */
wire                          joint_data_valid;
wire                          joint_data_last;

reg  [`DMA_DATA_WIDTH-1:0]    joint_data;

reg   [176-1:0]    store_data_reg;

/* data read from the fifo */
wire  [`DMA_DATA_WIDTH-1:0]     frame_data_fifo;
wire                            frame_data_last_fifo;

/* fifo signal */
wire                          frame_fifo_full; // full when first MSB different but rest same
wire                          frame_fifo_empty; // empty when pointers match exactly
wire                          frame_fifo_wr;
wire                          frame_fifo_rd;
wire [9:0]                    frame_empty_entry_num;

wire                                udp_fifo_full;
wire [5:0]                          udp_empty_entry_num;

assign axis_rx_ready = frame_empty_entry_num > 1 && udp_empty_entry_num > 2;

assign state_trans_next = (state_trans == TRANS_IDLE && axis_ready_valid) ? TRANS_HEADER : 
                              (state_trans == TRANS_HEADER && axis_ready_last ) ? TRANS_IDLE : 
                              (state_trans == TRANS_HEADER && axis_ready_valid ) ? TRANS_PALOAD : 
                              (state_trans == TRANS_PALOAD && axis_ready_last && payload_len > OFFSET_THRESH_10) ? TRANS_LAST : 
                              (state_trans == TRANS_PALOAD && axis_ready_last ) ? TRANS_IDLE : 
                              (state_trans == TRANS_PALOAD && axis_ready_valid ) ? TRANS_PALOAD :                               
                              (state_trans == TRANS_LAST && !axis_ready_valid ) ? TRANS_IDLE : 
                              (state_trans == TRANS_LAST && axis_ready_valid ) ? TRANS_HEADER : state_trans;

always@(posedge clk, negedge rst_n) begin
  state_trans <= `TD !rst_n ? TRANS_IDLE : state_trans_next;
end

assign joint_data_valid = (state_trans == TRANS_HEADER && state_trans_next == TRANS_IDLE  && axis_ready_valid ) || 
                      (state_trans == TRANS_PALOAD && state_trans_next ==  TRANS_PALOAD && axis_ready_valid ) || 
                      (state_trans == TRANS_PALOAD && state_trans_next ==  TRANS_LAST && axis_ready_valid ) || 
                      (state_trans == TRANS_PALOAD && state_trans_next ==  TRANS_IDLE && axis_ready_valid  ) || 
                      (state_trans == TRANS_LAST  && state_trans_next == TRANS_IDLE) || 
                      (state_trans == TRANS_LAST && state_trans_next == TRANS_HEADER  && axis_ready_valid);

assign joint_data_last  = (state_trans == TRANS_HEADER && state_trans_next == TRANS_IDLE  && axis_ready_valid ) || 
                      (state_trans == TRANS_PALOAD && state_trans_next ==  TRANS_IDLE && axis_ready_valid  ) || 
                      (state_trans == TRANS_LAST  && state_trans_next == TRANS_IDLE) || 
                      (state_trans == TRANS_LAST && state_trans_next == TRANS_HEADER  && axis_ready_valid);

/* store data every valid cycle */
always@(*) begin
  if(!rst_n) begin
    joint_data      = 'b0;
  end else begin
    if (state_trans == TRANS_IDLE && state_trans_next == TRANS_HEADER) begin
      joint_data    = 0;
    end else if (state_trans == TRANS_HEADER && state_trans_next == TRANS_PALOAD) begin
      joint_data    = 0;
    end else if (state_trans == TRANS_HEADER && state_trans_next == TRANS_IDLE) begin
      joint_data    = {80'b0, axis_rx_data[255:80]};
    end else if (state_trans == TRANS_PALOAD && state_trans_next == TRANS_PALOAD) begin
      joint_data    = {axis_rx_data[79:0], store_data_reg};
    end else if (state_trans == TRANS_PALOAD && state_trans_next == TRANS_IDLE) begin
      joint_data    = {axis_rx_data[79:0], store_data_reg};
    end else if (state_trans == TRANS_PALOAD && state_trans_next == TRANS_LAST) begin
      joint_data    = {axis_rx_data[79:0], store_data_reg};
    end else if (state_trans == TRANS_LAST && state_trans_next == TRANS_IDLE) begin
      joint_data    = {80'b0, store_data_reg};
    end else if (state_trans == TRANS_LAST && state_trans_next == TRANS_HEADER) begin
      joint_data    = {80'b0, store_data_reg};
    end else begin
      joint_data    = 0;
    end
  end
end

wire [15:0] axis_len;
assign axis_len = {axis_rx_data[135:128], axis_rx_data[143:136]};

always @(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    payload_len <= `TD 0;
  end else begin
    if(axis_ready_valid) begin
      if(state_trans == TRANS_IDLE && state_trans_next == TRANS_HEADER) begin
        payload_len <= `TD (axis_len > 28) ? axis_len - 28 : 0;
      end else if (state_trans == TRANS_LAST && state_trans_next == TRANS_HEADER) begin
        payload_len <= `TD (axis_len > 28) ? axis_len - 28 : 0;
      end else if (state_trans == TRANS_HEADER && state_trans_next == TRANS_PALOAD) begin
        payload_len <= `TD (payload_len >= 22) ?  payload_len - 22 : 0;
      end else if (state_trans == TRANS_HEADER && state_trans_next == TRANS_IDLE) begin
        payload_len <= `TD 0;
      end else if (state_trans == TRANS_PALOAD && state_trans_next == TRANS_PALOAD) begin
        payload_len <= `TD (payload_len >= 22) ?  payload_len - 32 : 0;
      end else if (state_trans == TRANS_PALOAD && state_trans_next == TRANS_IDLE) begin
        payload_len <= `TD 0;
      end else if (state_trans == TRANS_PALOAD && state_trans_next == TRANS_LAST) begin
        payload_len <= `TD 0;
      end else if (state_trans == TRANS_LAST && state_trans_next == TRANS_IDLE) begin
        payload_len <= `TD 0;
      end else begin
        payload_len <= `TD payload_len;
      end
    end else begin
      payload_len <= `TD payload_len;
    end
  end
end
    
/* fifo write signal */
assign frame_fifo_wr =   (state_trans == TRANS_HEADER && state_trans_next == TRANS_IDLE  && axis_ready_valid ) || 
                      (state_trans == TRANS_PALOAD && state_trans_next ==  TRANS_PALOAD && axis_ready_valid ) || 
                      (state_trans == TRANS_PALOAD && state_trans_next ==  TRANS_LAST && axis_ready_valid ) || 
                      (state_trans == TRANS_PALOAD && state_trans_next ==  TRANS_IDLE && axis_ready_valid  ) || 
                      (state_trans == TRANS_LAST  && state_trans_next == TRANS_IDLE) || 
                      (state_trans == TRANS_LAST && state_trans_next == TRANS_HEADER  && axis_ready_valid);

/* store data every valid cycle */
always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    store_data_reg      <= `TD 'b0;
  end else begin
    if(axis_ready_valid) begin
      if (state_trans == TRANS_IDLE && state_trans_next == TRANS_HEADER) begin
        store_data_reg <= `TD 0;
      end else if (state_trans == TRANS_HEADER && state_trans_next == TRANS_PALOAD) begin
        store_data_reg <= `TD axis_rx_data[255:80];
      end else if (state_trans == TRANS_HEADER && state_trans_next == TRANS_IDLE) begin
        store_data_reg <= `TD 0;
      end else if (state_trans == TRANS_PALOAD && state_trans_next == TRANS_PALOAD) begin
        store_data_reg <= `TD axis_rx_data[255:80];
      end else if (state_trans == TRANS_PALOAD && state_trans_next == TRANS_IDLE) begin
        store_data_reg <= `TD 0;
      end else if (state_trans == TRANS_PALOAD && state_trans_next == TRANS_LAST) begin
        store_data_reg <= `TD axis_rx_data[255:80];
      end else if (state_trans == TRANS_LAST && state_trans_next == TRANS_IDLE) begin
        store_data_reg <= `TD 0;
      end else if (state_trans == TRANS_LAST && state_trans_next == TRANS_HEADER) begin
        store_data_reg <= `TD 0;
      end else begin
        store_data_reg <= `TD store_data_reg;
      end
    end else begin
      store_data_reg <= `TD store_data_reg;
    end
  end
end

eth_sync_fifo_2psram  
#( .DATA_WIDTH(`DMA_DATA_WIDTH + 1),
  .FIFO_DEPTH(`RX_ROCE_PKT_FIFO_DEPTH)
) sync_fifo_2psram_inst (
  .clk  (clk  ),
  .rst_n(rst_n),
  .wr_en(frame_fifo_wr),
  .din  ({joint_data_last, joint_data}),
  .full (),
  .progfull (frame_fifo_full),
  .rd_en(frame_fifo_rd),
  .dout ({frame_data_last_fifo, frame_data_fifo}),
  .empty(frame_fifo_empty),
  .empty_entry_num(frame_empty_entry_num),
  .count()
  `ifdef ETH_CHIP_DEBUG
    ,.rw_data(rw_data[1*32-1 : 0])
  `endif
);
/* -------receive roce frame FSM {end}------- */

/* -------checksum the udp {begin}------- */
reg [7:0] udp_cycle_cnt;

wire                                udp_csum_valid;
wire                                udp_csum_last;
wire [`DMA_DATA_WIDTH-1:0]          udp_csum_data;
wire [`DMA_KEEP_WIDTH-1:0]          udp_csum_data_be;

wire [15:0]                         udp_csum_out;
wire                                udp_csum_out_valid;

wire                                udp_fifo_rd;
wire [15:0]                         udp_csum_fifo;
wire                                udp_fifo_empty;

wire [15:0] tcpl;
wire [7:0]  ptcl;

wire [16:0] tmp_csum;
wire [15:0] tmp_csum_rev;

assign ptcl = 8'h11;

assign tcpl = {axis_rx_data[135:128], axis_rx_data[143:136]} - 20;

assign tmp_csum     = {axis_rx_data[7:0], axis_rx_data[15:8]} + {axis_rx_data[7:0], axis_rx_data[15:8]};
assign tmp_csum_rev = tmp_csum[15:0] + tmp_csum[16];

assign udp_csum_valid     = axis_rx_valid && axis_rx_ready;
assign udp_csum_last      = axis_rx_last;
/*  */
assign udp_csum_data      = udp_cycle_cnt == 0 ? {axis_rx_data[255:112],
                                                tcpl[7:0], tcpl[15:8], ptcl, 8'b0, axis_rx_data[255:208], 32'b0} : 
                            udp_cycle_cnt == 1 ? {axis_rx_data[255:16],
                                               tmp_csum_rev[7:0], tmp_csum_rev[15:8] } : axis_rx_data;
                                   
assign udp_csum_data_be   = axis_rx_data_be;

always@(posedge clk, negedge rst_n) begin
  if (!rst_n) begin
    udp_cycle_cnt <= `TD 1'b0;
  end else if (udp_csum_last && udp_csum_valid) begin
    udp_cycle_cnt <= `TD 1'b0;
  end else if (udp_csum_valid) begin
    udp_cycle_cnt <= `TD udp_cycle_cnt + 1;
  end else begin
    udp_cycle_cnt <= `TD udp_cycle_cnt;
  end
end

checksum_util #(
  .DATA_WIDTH(`DMA_DATA_WIDTH),
  .KEEP_WIDTH(`DMA_KEEP_WIDTH),
  .REVERSE(REVERSE),
  .START_OFFSET(0)
) 
udp_checksum_util
(

  .clk(clk),
  .rst_n(rst_n),

  /*interface to mac rx  */
  .csum_data_valid(udp_csum_valid), 
  .csum_data_last(udp_csum_last),
  .csum_data(udp_csum_data),
  .csum_data_be(udp_csum_data_be),

  /*otuput to rx_engine, csum is used for offload*/
  .csum_out(udp_csum_out),
  .csum_out_valid(udp_csum_out_valid)
	
`ifdef ETH_CHIP_DEBUG
	,
	.Dbg_bus()
`endif

);

eth_sync_fifo_2psram  
#( .DATA_WIDTH(`CSUM_WIDTH),
  .FIFO_DEPTH(`RX_ROCE_CSUM_FIFO_DEPTH)
) sync_fifo_2psram_udp_csum_inst (
  .clk  (clk  ),
  .rst_n(rst_n),
  .wr_en(udp_csum_out_valid),
  .din  (udp_csum_out),
  .full (),
  .progfull (udp_fifo_full),
  .rd_en(udp_fifo_rd),
  .dout (udp_csum_fifo),
  .empty(udp_fifo_empty),
  .empty_entry_num(udp_empty_entry_num),
  .count()
  `ifdef ETH_CHIP_DEBUG
     ,.rw_data(rw_data[1*32 +: 32])
  `endif
);
/* -------checksum the udp {end}------- */



/* -------transmit the frame to fifo {begin}------- */

localparam  ROCE_IDLE  = 0,
            ROCE_WORK  = 1,
            ROCE_ERROR = 2;

reg   [1:0] state_roce;
wire  [1:0] state_roce_next;

/* udp_csum_fifo  zero indicate that a frame is correct */
assign state_roce_next = (state_roce == ROCE_IDLE && !udp_fifo_empty && !frame_fifo_empty && !udp_csum_fifo ) ? ROCE_WORK :
                          (state_roce == ROCE_IDLE && !udp_fifo_empty && !frame_fifo_empty && udp_csum_fifo) ? ROCE_ERROR :
                             ((state_roce == ROCE_WORK || state_roce == ROCE_ERROR) && frame_data_last_fifo && !frame_fifo_empty &&  !i_roce_prog_full) ? ROCE_IDLE : state_roce;

always @(posedge clk, negedge rst_n) begin
  state_roce <= `TD !rst_n ? ROCE_IDLE : state_roce_next;
end

assign udp_fifo_rd      = state_roce == ROCE_IDLE && (state_roce_next == ROCE_WORK || state_roce_next == ROCE_ERROR);

assign ov_roce_data     = frame_data_fifo;
assign o_roce_wr_en     = frame_fifo_rd && state_roce != ROCE_ERROR;

assign frame_fifo_rd    = !frame_fifo_empty &&  !i_roce_prog_full && (state_roce == ROCE_WORK || state_roce == ROCE_ERROR);
/* -------transmit the frame to fifo {end}------- */

reg [15:0] rec_cnt;
reg [15:0] xmit_cnt;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    rec_cnt <= `TD 0;
  end else if (axis_ready_last) begin
    rec_cnt <= `TD rec_cnt + 1;
  end else begin
    rec_cnt <= `TD rec_cnt;
  end
end

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    xmit_cnt <= `TD 0;
  end else if (frame_fifo_rd && frame_data_last_fifo) begin
    xmit_cnt <= `TD xmit_cnt + 1;
  end else begin
    xmit_cnt <= `TD xmit_cnt;
  end
end

`ifdef ETH_CHIP_DEBUG

wire 		[`RX_ROCEPROC_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_data;


assign Dbg_data = {// wire
                  8'b0, state_trans_next, axis_ready_valid, axis_ready_last, joint_data_valid, joint_data_last, 
                  frame_data_fifo, frame_data_last_fifo, frame_fifo_full, frame_fifo_empty, frame_fifo_wr, 
                  frame_fifo_rd, frame_empty_entry_num, udp_fifo_full, udp_empty_entry_num, axis_len, 
                  udp_csum_valid, udp_csum_last, udp_csum_data, udp_csum_data_be, udp_csum_out, 
                  udp_csum_out_valid, udp_fifo_rd, udp_csum_fifo, udp_fifo_empty, 
                  tcpl, ptcl, tmp_csum, tmp_csum_rev, state_roce_next, 

                  // reg
                  state_trans, payload_len, joint_data, store_data_reg, udp_cycle_cnt, state_roce, rec_cnt, xmit_cnt
                  } ;

assign Dbg_bus = Dbg_data >> (Dbg_sel << 5);
//assign Dbg_bus = Dbg_data;


`endif


 

`ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved |  | data_be | last |
     * |  255:64  |  |  63:32  |  0  |
     */
assign debug = {frame_fifo_rd && state_roce == ROCE_ERROR && frame_data_last_fifo , 
                  frame_fifo_rd &&  frame_data_last_fifo,
                  frame_fifo_rd};
/* ------- Debug interface {end}------- */




`endif
endmodule

