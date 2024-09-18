`timescale 1ns / 100ps
//*************************************************************************
// > File Name: tx_roceproc.v
// > Author   : Li jianxiong
// > Date     : 2021-10-29
// > Note     : tx_roceproc is used to receive the frame from roce fifo and 
//              add the ip header to the frame
//              then transmit it to the mac
//              it implements a fifo inside.
//              TODO: lenght 
//              
// > V1.1 - 2021-10-21 : 
//*************************************************************************

module tx_roceproc
(
  input   wire                              clk,
  input   wire                              rst_n,

  /* from tx_rocedesc,  get the the desc*/
  input   wire [`ROCE_DTYP_WIDTH-1:0]         tx_desc_dtyp,
  input   wire [`ROCE_LEN_WIDTH-1:0]           tx_desc_len,
  input   wire [`MAC_WIDTH-1:0]               tx_desc_smac,
  input   wire [`MAC_WIDTH-1:0]               tx_desc_dmac,
  input   wire [`IP_WIDTH-1:0]                tx_desc_sip,
  input   wire [`IP_WIDTH-1:0]                tx_desc_dip,
  input   wire                                tx_desc_valid,
  output  wire                                tx_desc_ready,

  input   wire                                  i_roce_empty,
  input   wire  [`DMA_DATA_WIDTH-1:0]           iv_roce_data,
  output  wire                                  o_roce_rd_en,

  /* interface to mac */
  output wire                                   axis_tx_valid, 
  output wire                                   axis_tx_last,
  output wire [`DMA_DATA_WIDTH-1:0]             axis_tx_data,
  output wire [`DMA_KEEP_WIDTH-1:0]             axis_tx_data_be,
  input wire                                    axis_tx_ready,
  output wire  [`XBAR_USER_WIDTH-1:0]           axis_tx_user,
  output wire                                   axis_tx_start

`ifdef ETH_CHIP_DEBUG
  ,input 	wire 	[`RW_DATA_NUM_TX_ROCEPORC * 32 - 1 : 0]	rw_data
	// ,output 	wire 		[0 : 0] 		Ro_data

  ,input 	  wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_sel
	,output 	wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_bus
	//,output 	wire 		[`TX_ROCEPROC_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_bus
`endif
);

/*
TCP/UDP Frame (IPv4)

 Field                                Length
 Destination MAC address              6 octets
 Source MAC address                   6 octets
 Ethertype (0x0800)                   2 octets
 Version (4)                          4 bits
 IHL (5-15)                           4 bits
 typeofservice (0)                    8 bits
 length                               2 octets
 identification (0?)                  2 octets
 fragment offset (0) & flags (010)    2 octets
 time to live (64?)                   1 octet
 protocol (6 or 17)                   1 octet
 header checksum                      2 octets
 source IP                            4 octets
 destination IP                       4 octets
 options                              (IHL-5)*4 octets

 source port                          2 octets
 desination port                      2 octets
 checksum                             2 octets
 payload length                       2 octets
 other fields + payload
*/

localparam IP_UDP_HEADER_LEN_BE   = 28;
localparam TOTAL_HEADER_LEN_BE    = 42;
localparam TOTAL_HEADER_LEN       = TOTAL_HEADER_LEN_BE << 3;
localparam JOINT_OFFSET_80        = 80;
localparam JOINT_OFFSET_176       = 176;
localparam CYCLE_WIDTH            = 8;
localparam OFFSET_32       = 32;
localparam OFFSET_22       = 22;
localparam OFFSET_10       = 10;

localparam  TRANS_IDLE = 0,
            TRANS_WORK = 1;

localparam REVERSE = 1;

/* change small end to big end */
function [TOTAL_HEADER_LEN-1:0] swapn (input [TOTAL_HEADER_LEN-1:0] data);
	integer i;
	for (i=0; i<(TOTAL_HEADER_LEN-1); i=i+8) 
    swapn[i+:8] = data[(TOTAL_HEADER_LEN-1-i)-:8];
endfunction 

/**
 * store the descriptor data
 */
// reg [`ROCE_DTYP_WIDTH-1:0]          store_dtyp;
reg [`ROCE_LEN_WIDTH-1:0]           store_len;
reg [`MAC_WIDTH-1:0]                store_smac;
reg [`MAC_WIDTH-1:0]                store_dmac;
reg [`IP_WIDTH-1:0]                 store_sip;
reg [`IP_WIDTH-1:0]                 store_dip;

/* fifo signal */
wire                          frame_fifo_full;  // 
wire                          frame_fifo_empty; // 
wire                          frame_fifo_wr;
wire                          frame_fifo_rd;

/* data read from the fifo */
wire  [`DMA_DATA_WIDTH-1:0]         frame_fifo_data_out;
wire                                frame_fifo_last_out;
wire  [`DMA_KEEP_WIDTH-1:0]         frame_fifo_data_be_out;

wire [15:0]                         ip_csum_fifo_data;
wire                                ip_fifo_empty;
wire                                ip_fifo_void;
wire [5:0]                          ip_fifo_empty_entry;
wire                                ip_fifo_rd;

wire [15:0]                         udp_csum_fifo_data;
wire                                udp_fifo_empty;
wire                                udp_fifo_void;
wire [5:0]                          udp_fifo_empty_entry;
wire                                udp_fifo_rd;

wire                                packet_len_wr ;
wire  [15:0]                        packet_len_store;
wire                                packet_len_rd;
wire  [15:0]                        packet_len_fifo_data;


/* -------State transmit packet{begin}------- */

reg   state_trans;
wire  state_trans_next;

reg [15:0] udp_csum_reg;
reg [15:0] ip_csum_reg;
reg [15:0] packet_len_reg;

reg [7:0] trans_cnt;

/* mask data by byte enable */
function [`DMA_DATA_WIDTH-1:0] data_mask(
  input [`DMA_DATA_WIDTH-1:0]  data,
  input [`DMA_KEEP_WIDTH-1:0]  data_be
);
  integer i;
  begin
    for(i = 0; i < `DMA_KEEP_WIDTH; i = i + 1) begin
      data_mask[i * 8 +: 8] = data[i * 8 +: 8] & {8{data_be[i]}};
    end
  end
endfunction

/* state change */
assign state_trans_next = (state_trans == TRANS_IDLE && !udp_fifo_empty && !ip_fifo_empty) ? TRANS_WORK : 
                          (state_trans == TRANS_WORK && axis_tx_valid && axis_tx_ready && axis_tx_last)? TRANS_IDLE : state_trans;

always @(posedge clk, negedge rst_n) begin
  state_trans <= `TD !rst_n ? TRANS_IDLE : state_trans_next;
end

assign ip_fifo_rd     = state_trans == TRANS_IDLE && state_trans_next == TRANS_WORK;
assign udp_fifo_rd    = state_trans == TRANS_IDLE && state_trans_next == TRANS_WORK;
assign packet_len_rd  = state_trans == TRANS_IDLE && state_trans_next == TRANS_WORK;


// store fifo data 
always @(posedge clk, negedge rst_n) begin
  ip_csum_reg <= `TD !rst_n ? 0 : ip_fifo_rd ?  ip_csum_fifo_data : ip_csum_reg;
end

always @(posedge clk, negedge rst_n) begin
  udp_csum_reg <= `TD !rst_n ? 0 : udp_fifo_rd ?  udp_csum_fifo_data : udp_csum_reg;
end

always @(posedge clk, negedge rst_n) begin
  packet_len_reg <= `TD !rst_n ? 0 : packet_len_rd ?  packet_len_fifo_data : packet_len_reg;
end

// cnt
always@(posedge clk, negedge rst_n) begin
  if (!rst_n) begin
    trans_cnt <= `TD 1'b0;
  end else if (axis_tx_valid && axis_tx_ready && axis_tx_last) begin
    trans_cnt <= `TD 0;
  end else if(axis_tx_valid && axis_tx_ready) begin
    trans_cnt <= `TD trans_cnt + 1;
  end
end

assign frame_fifo_rd = axis_tx_valid && axis_tx_ready;

assign axis_tx_valid  = state_trans == TRANS_WORK;

assign axis_tx_last  = frame_fifo_last_out && axis_tx_valid;

assign axis_tx_data  = (trans_cnt == 0) ? { frame_fifo_data_out[255:208], ip_csum_reg[7:0],ip_csum_reg[15:8], frame_fifo_data_out[191:0]} :
                        (trans_cnt == 1) ? { frame_fifo_data_out[255:80], udp_csum_reg[7:0],udp_csum_reg[15:8], frame_fifo_data_out[63:0]} : frame_fifo_data_out;

assign axis_tx_data_be  = frame_fifo_data_be_out;

assign axis_tx_user  = packet_len_reg[15:10] + (|packet_len_reg[9:0]);

assign axis_tx_start  = 0;
/* -------State transmit packet{end}------- */


/* -------State read packet{begin}------- */
localparam  RD_IDLE = 0,
            RD_DESC = 1,
            RD_DEAL_HEADER   = 2,
            RD_DEAL_PAYLOAD  = 3,
            RD_LAST     = 4;

wire  [TOTAL_HEADER_LEN-1:0]      data_header;        /* big end  */
// wire  [TOTAL_HEADER_LEN-1:0]      data_header_swapn;  /* big end */

// assign data_header_swapn = swapn(data_header);

reg   [2:0] state_rd;
wire  [2:0] state_rd_next;
wire        state_rd_stall;
wire        inner_fifo_full;

// remaining length
reg   [`ROCE_LEN_WIDTH-1:0]     state_len_reg;

/* joint data */
wire                          joint_data_valid;
wire                          joint_data_last;
// current cycle data
wire  [`DMA_DATA_WIDTH-1:0]     joint_data;
reg   [`DMA_KEEP_WIDTH-1:0]     joint_data_be;
// store the last cycle data that not tansmit
reg   [80-1:0]     joint_data_store;
reg   [OFFSET_32 - OFFSET_22 -1: 0 ]     joint_data_be_store;
// reg   [`DMA_KEEP_WIDTH-1:0]     joint_data_be_store;


/* ------ store descriptor data ------- */
always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    // store_dtyp       <=  `TD 'b0;
    store_len        <=  `TD 'b0;
    store_smac       <=  `TD 'b0;
    store_dmac       <=  `TD 'b0;
    store_sip        <=  `TD 'b0;
    store_dip        <=  `TD 'b0;
  end else begin
    /* store the desc data */
    // store_dtyp       <=  `TD (tx_desc_valid && tx_desc_ready) ? tx_desc_dtyp  : store_dtyp;
    store_len        <=  `TD (tx_desc_valid && tx_desc_ready) ? tx_desc_len   : store_len;
    store_smac       <=  `TD (tx_desc_valid && tx_desc_ready) ? tx_desc_smac  : store_smac;
    store_dmac       <=  `TD (tx_desc_valid && tx_desc_ready) ? tx_desc_dmac  : store_dmac;
    store_sip        <=  `TD (tx_desc_valid && tx_desc_ready) ? tx_desc_sip   : store_sip;
    store_dip        <=  `TD (tx_desc_valid && tx_desc_ready) ? tx_desc_dip   : store_dip;
  end  
end

assign tx_desc_ready = state_rd == RD_IDLE;

assign ip_fifo_void   = ip_fifo_empty_entry < 3;
assign udp_fifo_void  = udp_fifo_empty_entry < 3;

// if fifo is full or packet not ready, stall the state
assign inner_fifo_full = frame_fifo_full || ip_fifo_void || udp_fifo_void;
assign state_rd_stall  = i_roce_empty || inner_fifo_full;

/* -------receive roce frame FSM {begin}------- */
assign state_rd_next = 
                    (state_rd == RD_IDLE && tx_desc_valid && tx_desc_ready) ? RD_DESC :  
                    (inner_fifo_full)     ? state_rd :
                    (state_rd == RD_LAST) ? RD_IDLE :
                    (state_rd_stall)      ? state_rd :
                    (state_rd == RD_DESC)  ? RD_DEAL_HEADER : 
                    (state_rd == RD_DEAL_HEADER   && state_len_reg > OFFSET_32) ? RD_DEAL_PAYLOAD :
                    (state_rd == RD_DEAL_HEADER   && state_len_reg > OFFSET_22 && state_len_reg <= OFFSET_32) ? RD_LAST :
                    (state_rd == RD_DEAL_HEADER   && state_len_reg <= OFFSET_22) ? RD_IDLE :
                    (state_rd == RD_DEAL_PAYLOAD  && state_len_reg > OFFSET_32) ? RD_DEAL_PAYLOAD :
                    (state_rd == RD_DEAL_PAYLOAD  && state_len_reg > OFFSET_22 && state_len_reg <= OFFSET_32) ? RD_LAST :
                    (state_rd == RD_DEAL_PAYLOAD  && state_len_reg <= OFFSET_22) ? RD_IDLE : state_rd;
                    

/* joint the data  */
assign joint_data = (state_rd == RD_DESC && state_rd_next == RD_DEAL_HEADER) ? data_header[`DMA_DATA_WIDTH-1 : 0] :
                                          data_mask({iv_roce_data[JOINT_OFFSET_176-1:0] ,joint_data_store[JOINT_OFFSET_80-1:0]}, joint_data_be) ;

/* the highest bit is  the last signal */
assign joint_data_valid = frame_fifo_wr;
/*  */
assign joint_data_last  = (state_rd != RD_IDLE && state_rd_next == RD_IDLE) ? 1'b1 : 1'b0;

/* calculate the data mask */
/* because we have to joint the data ,and the data may not fill the entry, we need a mask */
always@* begin
  if(state_rd == RD_DESC && state_rd_next == RD_DEAL_HEADER) begin
      joint_data_be   = {`DMA_KEEP_WIDTH{1'b1}};
  end else if(state_rd == RD_DEAL_HEADER && state_rd_next == RD_DEAL_PAYLOAD) begin
      joint_data_be   = {`DMA_KEEP_WIDTH{1'b1}};
  /* because next read cycle is over */
  end else if(state_rd == RD_DEAL_HEADER && state_rd_next == RD_IDLE) begin
      joint_data_be   = {`DMA_KEEP_WIDTH{1'b1}} >> (OFFSET_32 - (state_len_reg + OFFSET_10));
  end else if(state_rd == RD_DEAL_HEADER && state_rd_next == RD_LAST) begin
      joint_data_be   = {`DMA_KEEP_WIDTH{1'b1}};
  end else if(state_rd == RD_DEAL_PAYLOAD && state_rd_next == RD_DEAL_PAYLOAD) begin
      joint_data_be   = {`DMA_KEEP_WIDTH{1'b1}};
  end else if(state_rd == RD_DEAL_PAYLOAD && state_rd_next == RD_LAST) begin
      joint_data_be   = {`DMA_KEEP_WIDTH{1'b1}};
  end else if(state_rd == RD_DEAL_PAYLOAD && state_rd_next == RD_IDLE) begin
      joint_data_be   = {`DMA_KEEP_WIDTH{1'b1}} >> (OFFSET_32 - (state_len_reg + OFFSET_10));
  end else if(state_rd == RD_LAST && state_rd_next == RD_IDLE) begin
      joint_data_be   = joint_data_be_store;
  end else begin
      joint_data_be   = {`DMA_KEEP_WIDTH{1'b0}};
  end
end

/* read the roce frame frome the outside fifo */
assign o_roce_rd_en =  !state_rd_stall &&
                            ((state_rd == RD_DEAL_HEADER && state_rd_next == RD_DEAL_PAYLOAD) || 
                            (state_rd == RD_DEAL_HEADER && state_rd_next == RD_IDLE) || 
                            (state_rd == RD_DEAL_HEADER && state_rd_next == RD_LAST) || 
                            (state_rd == RD_DEAL_PAYLOAD && state_rd_next == RD_DEAL_PAYLOAD) || 
                            (state_rd == RD_DEAL_PAYLOAD && state_rd_next == RD_LAST) || 
                            (state_rd == RD_DEAL_PAYLOAD && state_rd_next == RD_IDLE));

assign frame_fifo_wr = (!inner_fifo_full && (state_rd == RD_LAST && state_rd_next == RD_IDLE)) ||
                        (!state_rd_stall &&  ((state_rd == RD_DESC && state_rd_next == RD_DEAL_HEADER) || 
                            (state_rd == RD_DEAL_HEADER && state_rd_next == RD_DEAL_PAYLOAD) || 
                            (state_rd == RD_DEAL_HEADER && state_rd_next == RD_IDLE) || 
                            (state_rd == RD_DEAL_HEADER && state_rd_next == RD_LAST) || 
                            (state_rd == RD_DEAL_PAYLOAD && state_rd_next == RD_DEAL_PAYLOAD) || 
                            (state_rd == RD_DEAL_PAYLOAD && state_rd_next == RD_LAST) || 
                            (state_rd == RD_DEAL_PAYLOAD && state_rd_next == RD_IDLE)));

// store the last cycle data
wire store_data_en;
assign store_data_en = o_roce_rd_en || (state_rd == RD_DESC && state_rd_next == RD_DEAL_HEADER);

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    joint_data_store      <= `TD 'b0;
  end else begin
    if(store_data_en) begin
      /* store the upper header */
      if(state_rd == RD_DESC && state_rd_next == RD_DEAL_HEADER) begin
        joint_data_store        <= `TD data_header[TOTAL_HEADER_LEN -1 : `DMA_DATA_WIDTH];
      /* store the upper 80 */
      end else begin        
        joint_data_store        <= `TD iv_roce_data[`DMA_DATA_WIDTH-1:JOINT_OFFSET_176];
      end
    end
  end
end

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    joint_data_be_store <= `TD 'b0;
  end else begin
    /* because the data may not fill the register */
    if(state_rd != RD_IDLE && state_rd_next == RD_IDLE) begin
      joint_data_be_store      <= `TD 0;
    end else if(state_rd == RD_DEAL_HEADER && state_rd_next == RD_LAST) begin
      joint_data_be_store      <= `TD {`DMA_KEEP_WIDTH{1'b1}} >> (OFFSET_32 - (state_len_reg - OFFSET_22));
    end else if(state_rd == RD_DEAL_PAYLOAD && state_rd_next == RD_LAST) begin
      joint_data_be_store      <= `TD {`DMA_KEEP_WIDTH{1'b1}} >> (OFFSET_32 - (state_len_reg - OFFSET_22));
    end else begin
      joint_data_be_store      <= `TD joint_data_be_store;
    end
  end
end

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    state_len_reg   <= `TD 'b0;
  end else begin
    if(state_rd == RD_DESC && state_rd_next == RD_DEAL_HEADER) begin
      state_len_reg   <= `TD store_len;
    end else begin
      if(o_roce_rd_en) begin
        state_len_reg   <= `TD (state_len_reg > `DMA_KEEP_WIDTH) ?  (state_len_reg - `DMA_KEEP_WIDTH) : 'b0;
      end else begin
        state_len_reg <= `TD state_len_reg;
      end      
    end
  end
end

always@(posedge clk, negedge rst_n) begin
    state_rd <= `TD !rst_n ? RD_IDLE : state_rd_next;
end

eth_sync_fifo_2psram  
#( .DATA_WIDTH(`DMA_DATA_WIDTH +  `DMA_KEEP_WIDTH + 1),
  .FIFO_DEPTH(`TX_ROCE_PKT_FIFO_DEPTH)
) sync_fifo_2psram_inst (
  .clk  (clk  ),
  .rst_n(rst_n),
  .wr_en(frame_fifo_wr),
  .din  ({joint_data_be, joint_data_last, joint_data}),
  .full (),
  .progfull (frame_fifo_full),
  .rd_en(frame_fifo_rd),
  .dout ({frame_fifo_data_be_out,frame_fifo_last_out, frame_fifo_data_out}),
  .empty(frame_fifo_empty),
  .empty_entry_num(),
  .count()
  `ifdef ETH_CHIP_DEBUG
    ,.rw_data(rw_data[1*32-1:0])
  `endif
);

assign packet_len_wr    = tx_desc_valid && tx_desc_ready;
assign packet_len_store = tx_desc_len + 42;

eth_sync_fifo_2psram  
#( .DATA_WIDTH(`ROCE_LEN_WIDTH),
  .FIFO_DEPTH(`TX_ROCE_CSUM_FIFO_DEPTH)
) sync_fifo_2psram_length_inst (
  .clk  (clk  ),
  .rst_n(rst_n),
  .wr_en(packet_len_wr),
  .din  (packet_len_store),
  .full (),
  .progfull (),
  .rd_en(packet_len_rd),
  .dout (packet_len_fifo_data),
  .empty(),
  .empty_entry_num(),
  .count()
  `ifdef ETH_CHIP_DEBUG
    ,.rw_data(rw_data[1*32 +: 32])
  `endif
);
/* -------receive roce frame FSM {end}------- */


/* -------checksum the ip {begin}------- */
reg [7:0] ip_csum_cnt;
wire                                ip_csum_valid;
wire                                ip_csum_last;
wire [`DMA_DATA_WIDTH-1:0]          ip_csum_data;
wire [`DMA_KEEP_WIDTH-1:0]          ip_csum_data_be;

wire [15:0]                         ip_csum_out;
wire                                ip_csum_out_valid;

assign ip_csum_valid     = joint_data_valid;
assign ip_csum_last      = joint_data_last;

assign ip_csum_data     = joint_data;
assign ip_csum_data_be  = (ip_csum_cnt == 0) ? `DMA_KEEP_WIDTH'hffff_c000 :
                            (ip_csum_cnt == 1) ? `DMA_KEEP_WIDTH'h0000_0003 : `DMA_KEEP_WIDTH'h0;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    ip_csum_cnt <= `TD 0;
  end else if(ip_csum_valid && ip_csum_last) begin
    ip_csum_cnt <= `TD 0;
  end else if (ip_csum_valid) begin
    ip_csum_cnt <= `TD ip_csum_cnt + 1;
  end
end

checksum_util #(
  .DATA_WIDTH(`DMA_DATA_WIDTH),
  .KEEP_WIDTH(`DMA_KEEP_WIDTH),
  .REVERSE(REVERSE),
  .START_OFFSET(0)
) 
ip_checksum_util
(

  .clk(clk),
  .rst_n(rst_n),

  /*interface to mac rx  */
  .csum_data_valid(ip_csum_valid), 
  .csum_data_last(ip_csum_last),
  .csum_data(ip_csum_data),
  .csum_data_be(ip_csum_data_be),

  /*otuput to rx_engine, csum is used for offload*/
  .csum_out(ip_csum_out),
  .csum_out_valid(ip_csum_out_valid)

`ifdef ETH_CHIP_DEBUG
	,
	.Dbg_bus()
`endif
);

eth_sync_fifo_2psram  
#( .DATA_WIDTH(`CSUM_WIDTH),
  .FIFO_DEPTH(`TX_ROCE_CSUM_FIFO_DEPTH)
) sync_fifo_2psram_ip_csum_inst (
  .clk  (clk  ),
  .rst_n(rst_n),
  .wr_en(ip_csum_out_valid),
  .din  (ip_csum_out),
  .full (),
	.progfull(),
  .rd_en(ip_fifo_rd),
  .dout (ip_csum_fifo_data),
  .empty(ip_fifo_empty),
  .empty_entry_num(ip_fifo_empty_entry),
  .count()
  `ifdef ETH_CHIP_DEBUG
    ,.rw_data(rw_data[2*32 +: 32])
  `endif
);
/* -------checksum the ip {end}------- */

/* -------checksum the udp {begin}------- */
reg [7:0] upd_csum_cnt;

wire                                udp_csum_valid;
wire                                udp_csum_last;
wire [`DMA_DATA_WIDTH-1:0]          udp_csum_data;
wire [`DMA_KEEP_WIDTH-1:0]          udp_csum_data_be;

wire [15:0]                         udp_csum_out;
wire                                udp_csum_out_valid;



wire [15:0] tcpl;
wire [7:0] ptcl;

assign tcpl = 8 + store_len;
// assign mbz = 0;
assign ptcl = 8'h11;

assign udp_csum_valid     = joint_data_valid;
assign udp_csum_last      = joint_data_last;
/* 
    | dest ip  | source ip | ptcl    | tclp     |
    |  271:240 |  239: 208 | 207:192 | 191: 176 |
 */
assign udp_csum_data      = upd_csum_cnt == 0 ? {joint_data[255:208], 
                                                tcpl[7:0], tcpl[15:8], ptcl, 184'b0} : joint_data;
assign udp_csum_data_be   = joint_data_be;

always@(posedge clk, negedge rst_n) begin
  if (!rst_n) begin
    upd_csum_cnt <= `TD 1'b0;
  end else if (udp_csum_valid && udp_csum_last) begin
    upd_csum_cnt <= `TD 0;
  end else if(udp_csum_valid) begin
    upd_csum_cnt <= `TD upd_csum_cnt + 1;
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
  .FIFO_DEPTH(`TX_ROCE_CSUM_FIFO_DEPTH)
) sync_fifo_2psram_udp_csum_inst (
  .clk  (clk  ),
  .rst_n(rst_n),
  .wr_en(udp_csum_out_valid),
  .din  (udp_csum_out),
  .full (),
  .progfull (),
  .rd_en(udp_fifo_rd),
  .dout (udp_csum_fifo_data),
  .empty(udp_fifo_empty),
  .empty_entry_num(udp_fifo_empty_entry),
  .count()
  `ifdef ETH_CHIP_DEBUG
    ,.rw_data(rw_data[3*32 +: 32])
  `endif
);
/* -------checksum the udp {end}------- */


reg [15:0]                   identification;

/* increase the identification when finish one frame */
always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    identification <= `TD 'b0;
  end else begin
    if(state_rd != RD_IDLE && state_rd_next == RD_IDLE) begin
      identification    <= `TD identification + 1;
    end
  end
end


wire [`MAC_WIDTH-1:0]         header_dmac;
wire [`MAC_WIDTH-1:0]         header_smac;
wire [15:0]                   header_ethtype;
wire [7:0]                    header_len_version;
wire [7:0]                    header_typeService;
wire [15:0]                   header_totollen;
wire [15:0]                   header_identification;
wire [15:0]                   header_frameoffset;
wire [7:0]                    header_timelive;
wire [7:0]                    header_protocol;
wire [15:0]                   header_ipchecksum;
wire [`IP_WIDTH-1:0]          header_sip;
wire [`IP_WIDTH-1:0]          header_dip;
wire [15:0]                   header_srcport;
wire [15:0]                   header_dstport;
wire [15:0]                   header_udpchecksum;
wire [`ROCE_LEN_WIDTH-1:0]    header_udplen;

assign header_smac                                      = store_smac;
assign header_dmac                                      = store_dmac;
assign header_len_version                               = {4'h4, 4'h5};
assign header_typeService                               = 8'h0;
assign header_totollen                                  = store_len + 16'd28;
assign header_identification                            = identification;
assign header_frameoffset                               = {8'b0, 8'b0};
assign header_timelive                                  = 8'd64;
assign header_protocol                                  = 8'd17;
assign header_ipchecksum                                = 16'd0;
assign header_sip                                       = store_sip;
assign header_dip                                       = store_dip;
assign header_srcport                                   = {8'hb7, 8'h12};
assign header_dstport                                   = {8'hb7, 8'h12};
assign header_udpchecksum                               = 16'h0;
assign header_udplen                                    = store_len + 16'd8;
assign header_ethtype                                   = 16'h0800;


assign data_header  = { 
                      header_udpchecksum,
                      {header_udplen[7:0], header_udplen[15:8]},
                      header_dstport,
                      header_srcport,
                      header_dip[7:0],header_dip[15:8],header_dip[23:16],header_dip[31:24],
                      header_sip[7:0],header_sip[15:8],header_sip[23:16],header_sip[31:24],
                      header_ipchecksum,
                      header_protocol,
                      header_timelive,
                      {header_frameoffset[7:0], header_frameoffset[15:8]},
                      {header_identification[7:0], identification[15:8]},
                      {header_totollen[7:0], header_totollen[15:8]},
                      header_typeService,
                      header_len_version,
                      {header_ethtype[7:0], header_ethtype[15:8]},
                      header_smac[7:0],header_smac[15:8],header_smac[23:16],header_smac[31:24],header_smac[39:32],header_smac[47:40],
                      header_dmac[7:0],header_dmac[15:8],header_dmac[23:16],header_dmac[31:24],header_dmac[39:32],header_dmac[47:40]
                      };



`ifdef ETH_CHIP_DEBUG

wire 		[`TX_ROCEPROC_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_data;



assign Dbg_data = {// wire
                  19'b0,
                  frame_fifo_wr, frame_fifo_rd, frame_fifo_data_out, frame_fifo_last_out, frame_fifo_data_be_out, ip_csum_fifo_data, 
                  ip_fifo_empty, ip_fifo_void, ip_fifo_empty_entry, ip_fifo_rd, udp_csum_fifo_data, udp_fifo_empty, udp_fifo_void, 
                  udp_fifo_empty_entry, udp_fifo_rd, packet_len_store, packet_len_rd, packet_len_fifo_data, state_trans_next, state_rd_next, 
                  state_rd_stall, inner_fifo_full, joint_data_valid, joint_data_last, joint_data, store_data_en, ip_csum_valid, ip_csum_last, 
                  ip_csum_data, ip_csum_data_be, ip_csum_out, ip_csum_out_valid, udp_csum_valid, udp_csum_last, udp_csum_data, udp_csum_data_be, 
                  udp_csum_out, udp_csum_out_valid, tcpl, ptcl, header_dmac, header_smac, header_ethtype, header_len_version, header_typeService, 
                  header_totollen, header_identification, header_frameoffset, header_timelive, header_protocol, header_ipchecksum, header_sip, header_dip, 
                  header_srcport, header_dstport, header_udpchecksum, header_udplen,

                  // reg
                  store_len, store_smac, store_dmac, store_sip, store_dip, state_trans, udp_csum_reg, 
                  ip_csum_reg, packet_len_reg, trans_cnt, state_rd, state_len_reg, joint_data_be, joint_data_store, joint_data_be_store, 
                  joint_data_be_store, ip_csum_cnt, upd_csum_cnt, identification 
                  } ;


assign Dbg_bus = Dbg_data >> (Dbg_sel << 5);
//assign Dbg_bus = Dbg_data;

`endif


endmodule

