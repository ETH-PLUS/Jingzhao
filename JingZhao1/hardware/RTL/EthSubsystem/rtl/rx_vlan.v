`timescale 1ns / 100ps
//*************************************************************************
// > File Name: rx_vlan.v
// > Author   : Li jianxiong
// > Date     : 2021-10-29
// > Note     : rx_vlan is used to receive the frame from roce fifo and 
//              add the ip header to the frame
//              then transmit it to the mac
//              it implements a fifo inside.
//              
// > V1.1 - 2021-10-21 : 
//*************************************************************************

module rx_vlan
(
  input   wire                              clk,
  input   wire                              rst_n,

  /*interface to mac tx  */
  input wire                                  axis_rx_valid, 
  input wire                                  axis_rx_last,
  input wire [`DMA_DATA_WIDTH-1:0]            axis_rx_data,
  input wire [`DMA_KEEP_WIDTH-1:0]            axis_rx_data_be,
  output wire                                 axis_rx_ready,

  output  wire                                  axis_rx_vlan_valid, 
  output  wire                                  axis_rx_vlan_last,
  output  wire [`DMA_DATA_WIDTH-1:0]            axis_rx_vlan_data,
  output  wire [`DMA_KEEP_WIDTH-1:0]            axis_rx_vlan_data_be,
  input   wire                                  axis_rx_vlan_ready,

  /*interface to roce rx  */
  output  wire [`VLAN_TAG_WIDTH-1:0]            rx_vlan_tci,
  output  wire                                  rx_vlan_valid,
  output  wire [`STATUS_WIDTH-1:0]              rx_vlan_status

`ifdef ETH_CHIP_DEBUG
  // ,input 	  wire		[0 : 0] 		Rw_data
	// ,output 	wire 		[0 : 0] 		Ro_data
  ,input 	  wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_sel
,output 	wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_bus
//	,output 	wire 		[`RX_VLAN_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_bus
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

localparam  TRANS_IDLE = 0,
            TRANS_PALOAD = 1,
            TRANS_LAST = 2,
            NOT_VLAN = 3;

reg   [1:0] state_trans;
wire  [1:0] state_trans_next;

wire axis_ready_valid;
wire axis_ready_last;

assign axis_ready_valid = axis_rx_valid & axis_rx_ready;
assign axis_ready_last  = axis_rx_valid & axis_rx_ready && axis_rx_last;

wire [15:0]                   eth_type;
wire                          vlan_flag;
wire [`VLAN_TAG_WIDTH-1:0]    vlan_tci;

assign eth_type[15:8] = axis_rx_data[(12%`DMA_KEEP_WIDTH)*8 +: 8];
assign eth_type[7:0]  = axis_rx_data[(13%`DMA_KEEP_WIDTH)*8 +: 8];

assign vlan_flag      = eth_type == 16'h8100;
assign vlan_tci[15:8] = axis_rx_data[(14%`DMA_KEEP_WIDTH)*8 +: 8];
assign vlan_tci[7:0]  = axis_rx_data[(15%`DMA_KEEP_WIDTH)*8 +: 8]; 

/* data after joint with last signal */
wire                          joint_data_last;
reg  [`DMA_DATA_WIDTH-1:0]    joint_data;
reg  [`DMA_KEEP_WIDTH-1:0]    joint_data_be;

reg   [224-1:0]    store_data_reg;
reg   [28-1:0]    store_data_be_reg;

/* data read from the fifo */
wire  [`DMA_DATA_WIDTH-1:0]     frame_data_fifo;
wire  [`DMA_KEEP_WIDTH-1:0]     frame_data_be_fifo;
wire                            frame_data_last_fifo;

/* fifo signal */
wire                          frame_fifo_full; // full when first MSB different but rest same
wire                          frame_fifo_empty; // empty when pointers match exactly
wire                          frame_fifo_wr;
wire                          frame_fifo_rd;
wire [3:0]                    frame_empty_entry_num;


reg [15:0]  pkt_cycle;

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

assign axis_rx_ready = !frame_fifo_full;

assign state_trans_next =   (state_trans == TRANS_IDLE && axis_ready_valid && !vlan_flag) ? NOT_VLAN : 
                            (state_trans == TRANS_IDLE && axis_ready_valid) ? TRANS_PALOAD : 
                              (state_trans == NOT_VLAN  && axis_ready_last ) ? TRANS_IDLE : 
                              (state_trans == NOT_VLAN  && axis_ready_valid ) ? NOT_VLAN : 
                              (state_trans == TRANS_PALOAD && axis_ready_last && axis_rx_data_be[`DMA_KEEP_WIDTH-1:2]) ? TRANS_LAST : 
                              (state_trans == TRANS_PALOAD && axis_ready_last ) ? TRANS_IDLE : 
                              (state_trans == TRANS_PALOAD && axis_ready_valid ) ? TRANS_PALOAD :                               
                              (state_trans == TRANS_LAST && !axis_ready_valid ) ? TRANS_IDLE : 
                              (state_trans == TRANS_LAST && axis_ready_valid && !vlan_flag) ? NOT_VLAN :
                              (state_trans == TRANS_LAST && axis_ready_valid ) ? TRANS_PALOAD : state_trans;

always@(posedge clk, negedge rst_n) begin
  state_trans <= `TD !rst_n ? TRANS_IDLE : state_trans_next;
end

assign joint_data_last  =  (state_trans == NOT_VLAN  && state_trans_next == TRANS_IDLE) || 
                        (state_trans == TRANS_PALOAD && state_trans_next ==  TRANS_IDLE) || 
                      (state_trans == TRANS_LAST  && state_trans_next == TRANS_IDLE) || 
                      (state_trans == TRANS_LAST && state_trans_next == TRANS_PALOAD);

/* fifo write signal */
assign frame_fifo_wr =  (state_trans == TRANS_IDLE && state_trans_next ==  NOT_VLAN && axis_ready_valid) ||
                        (state_trans == NOT_VLAN && state_trans_next ==  NOT_VLAN && axis_ready_valid) ||
                        (state_trans == NOT_VLAN && state_trans_next ==  TRANS_IDLE && axis_ready_valid) ||
                        (state_trans == TRANS_PALOAD && state_trans_next ==  TRANS_PALOAD && axis_ready_valid ) || 
                      (state_trans == TRANS_PALOAD && state_trans_next ==  TRANS_LAST && axis_ready_valid ) || 
                      (state_trans == TRANS_PALOAD && state_trans_next ==  TRANS_IDLE && axis_ready_valid  ) || 
                      (state_trans == TRANS_LAST  && state_trans_next == TRANS_IDLE) || 
                      (state_trans == TRANS_LAST && state_trans_next == TRANS_PALOAD  && axis_ready_valid) ||
                      (state_trans == TRANS_LAST && state_trans_next == NOT_VLAN      && axis_ready_valid);

/* store data every valid cycle */
always@(*) begin
  if(!rst_n) begin
    joint_data      = 'b0;
  end else begin    
    if ((state_trans == TRANS_IDLE  && state_trans_next == NOT_VLAN)    ||
        (state_trans == NOT_VLAN    && state_trans_next == NOT_VLAN)    ||
        (state_trans == NOT_VLAN    && state_trans_next == TRANS_IDLE)  ||
        (state_trans == TRANS_LAST  && state_trans_next == NOT_VLAN)) begin
      joint_data    = axis_rx_data;
    end else if (state_trans == TRANS_IDLE && state_trans_next == TRANS_PALOAD) begin
      joint_data        = 0;
    end else if ((state_trans == TRANS_PALOAD && state_trans_next == TRANS_PALOAD)  || 
                  (state_trans == TRANS_PALOAD && state_trans_next == TRANS_IDLE)   ||
                  (state_trans == TRANS_PALOAD && state_trans_next == TRANS_LAST)) begin
      joint_data    = {axis_rx_data[31:0], store_data_reg[223:0]};
    end else if ((state_trans == TRANS_LAST && state_trans_next == TRANS_IDLE) || 
                  (state_trans == TRANS_LAST && state_trans_next == TRANS_PALOAD)) begin
      joint_data    = store_data_reg[223:0];
    end else begin
      joint_data    = 0;
    end
  end
end

/* store data every valid cycle */

always@(*) begin
  if(!rst_n) begin
    joint_data_be      = {`DMA_KEEP_WIDTH{1'b0}};
  end else begin    
    if ((state_trans == TRANS_IDLE  && state_trans_next == NOT_VLAN)    ||
        (state_trans == NOT_VLAN    && state_trans_next == NOT_VLAN)    ||
        (state_trans == NOT_VLAN    && state_trans_next == TRANS_IDLE)  ||
        (state_trans == TRANS_LAST  && state_trans_next == NOT_VLAN)) begin
      joint_data_be    = axis_rx_data_be;
    end else if (state_trans == TRANS_IDLE && state_trans_next == TRANS_PALOAD) begin
      joint_data_be        = {`DMA_KEEP_WIDTH{1'b0}};
    end else if ((state_trans == TRANS_PALOAD && state_trans_next == TRANS_PALOAD)  || 
                  (state_trans == TRANS_PALOAD && state_trans_next == TRANS_IDLE)   ||
                  (state_trans == TRANS_PALOAD && state_trans_next == TRANS_LAST)) begin
      joint_data_be    = {axis_rx_data_be[3:0], store_data_be_reg[27:0]};
    end else if ((state_trans == TRANS_LAST && state_trans_next == TRANS_IDLE) || 
                  (state_trans == TRANS_LAST && state_trans_next == TRANS_PALOAD)) begin
      joint_data_be    = store_data_be_reg[27:0];
    end else begin
      joint_data_be    = {`DMA_KEEP_WIDTH{1'b0}};
    end
  end
end
    

/* store data every valid cycle */
always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    store_data_reg      <= `TD 'b0;
    store_data_be_reg   <= `TD 'b0;
  end else begin
    if(axis_ready_valid) begin
      if(state_trans == TRANS_IDLE && state_trans_next == TRANS_PALOAD || 
          state_trans == TRANS_LAST && state_trans_next == TRANS_PALOAD ) begin
        store_data_reg    <= `TD {axis_rx_data[255:128], axis_rx_data[95:0]};
        store_data_be_reg <= `TD {axis_rx_data_be[`DMA_KEEP_WIDTH-1:16], axis_rx_data_be[11:0]};
      end else begin
        store_data_reg    <= `TD {axis_rx_data[255:32]};
        store_data_be_reg <= `TD {axis_rx_data_be[`DMA_KEEP_WIDTH-1:4]};
      end
    end else begin
      store_data_reg    <= `TD store_data_reg;
      store_data_be_reg <= `TD store_data_be_reg;
    end
  end
end

eth_sync_fifo_2psram  
#( .DATA_WIDTH(`DMA_DATA_WIDTH + `DMA_KEEP_WIDTH + 1),
  .FIFO_DEPTH(`RX_VLAN_FIFO_DEPTH)
) sync_fifo_2psram_inst (
  .clk  (clk  ),
  .rst_n(rst_n),
  .rw_data(32'd0),
  .wr_en(frame_fifo_wr),
  .din  ({joint_data_last, joint_data_be, joint_data}),
  .full (),
  .progfull (frame_fifo_full),
  .rd_en(frame_fifo_rd),
  .dout ({frame_data_last_fifo, frame_data_be_fifo, frame_data_fifo}),
  .empty(frame_fifo_empty),
  .empty_entry_num(frame_empty_entry_num),
  .count()
);

/* -------receive frame FSM {end}------- */

/* -------xmit frame {begin}------- */


assign axis_rx_vlan_valid     = !frame_fifo_empty;
assign axis_rx_vlan_last      =  frame_data_last_fifo & axis_rx_vlan_valid;
assign axis_rx_vlan_data      =  frame_data_fifo;
assign axis_rx_vlan_data_be   = frame_data_be_fifo;

assign frame_fifo_rd          = axis_rx_vlan_valid & axis_rx_vlan_ready;

assign rx_vlan_tci      = vlan_tci;
assign rx_vlan_valid    = pkt_cycle == 0 && axis_ready_valid;
assign rx_vlan_status   = vlan_flag;
/* -------xmit frame {end}------- */


`ifdef ETH_CHIP_DEBUG

wire 		[`RX_VLAN_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_data;


assign Dbg_data = {// wire
                  3'b0, state_trans_next, axis_ready_valid, axis_ready_last, eth_type, vlan_flag, vlan_tci, 
                  joint_data_last, frame_data_fifo, frame_data_be_fifo, frame_data_last_fifo, frame_fifo_full, 
                  frame_fifo_empty, frame_fifo_wr, frame_fifo_rd, frame_empty_entry_num, 
                  // reg
                  state_trans, joint_data, joint_data_be, store_data_reg, store_data_be_reg, pkt_cycle
                  } ;

assign Dbg_bus = Dbg_data >> (Dbg_sel << 5);              
//assign Dbg_bus = Dbg_data;              

`endif


`ifdef SIMULATION


reg [15:0]  sim_vlan_cnt;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    sim_vlan_cnt <= `TD 0;
  end else begin
    if(axis_ready_last) begin
      sim_vlan_cnt <= `TD sim_vlan_cnt + 1;
    end
  end
end

    /* ------- Debug interface {begin}------- */
    /* | reserved |  | data_be | last |
     * |  255:64  |  |  63:32  |  0  |
     */
// assign debug = {frame_fifo_rd && state_roce == ROCE_ERROR && frame_data_last_fifo , 
//                   frame_fifo_rd &&  frame_data_last_fifo,
//                   frame_fifo_rd};
/* ------- Debug interface {end}------- */
`endif
endmodule

