`timescale 1ns / 100ps
//*************************************************************************
// > File Name: rx_hash.v
// > Author   : Li jianxiong
// > Date     : 2021-10-12
// > Note     : rx_hash is used for generate hash number for a frame by
//              using the quad of ( src ip address, dest ip address, 
//              src port, dest port)
//              TODO:now the module is not configurable
// > V1.1 - 2021-10-12 : 
//*************************************************************************

module rx_hash #
(
  parameter START_OFFSET = 14 /* ip header start offset is 14 bytes*/
)
(
  input wire clk,
  input wire rst_n,

  /*interface to mac rx  */
  input wire                              axis_rx_valid, 
  input wire                              axis_rx_last,
  input wire [`DMA_DATA_WIDTH-1:0]        axis_rx_data,
  input wire [`DMA_KEEP_WIDTH-1:0]        axis_rx_data_be,

  input wire [40*8-1:0]                   hash_key,

  /*otuput to rx_engine, hash is used for choose the queue*/
  output reg [`HASH_WIDTH-1:0]           crx_hash,
  output reg                             crx_hash_valid

  `ifdef ETH_CHIP_DEBUG
  // ,input 	  wire		[0 : 0] 		Rw_data
	// ,output 	wire 		[0 : 0] 		Ro_data
  ,input 	  wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_sel
	,output 	wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_bus
	//,output 	wire 		[`RX_HASH_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_bus
`endif
);

localparam CYCLE_COUNT = (38+`DMA_KEEP_WIDTH-1) / `DMA_KEEP_WIDTH; /*the cycle count of the quad, the last is the dest posr*/
localparam PTR_WIDTH   = 8;

function [`HASH_WIDTH-1:0] hash_toep(
  input [95:0]  data,
  input [5:0]       len,
  input [40*8-1:0]  key 
);
  integer i, j;
  begin
    hash_toep = 0;
    for(i = 0; i < len; i = i + 1) begin
      for(j = 0; j < 8; j = j + 1) begin
        if(data[i*8 + (7-j)]) begin
          hash_toep = hash_toep ^ key[40*8 - 32 - i * 8 - j +: 32];
        end
      end
    end
  end  
endfunction

localparam  CYCLE_0 = 0,
            CYCLE_1 = 1,
            CYCLE_R = 2; 

reg  [1:0]  state_cur;
wire [1:0]  state_next;

reg  [47:0] hash_data_reg;
wire [95:0] hash_data_next;

// compute toeplitz hashes
wire [31:0] hash_part_ipv4_ip;
wire [31:0] hash_part_ipv4_port;

wire [15:0] eth_type;

wire ipv4_flag;
wire tcp_udp_flag;
reg  tcp_udp_flag_reg;

wire [3:0] ihl_flag;
reg  [3:0] ihl_reg;

reg   [PTR_WIDTH-1:0] ptr_reg;

assign hash_part_ipv4_ip = hash_toep(hash_data_next, 8, hash_key);
assign hash_part_ipv4_port = hash_toep(hash_data_next >> 8*8, 4, hash_key << 8*8);

/*eth type is in the 96-111*/
assign eth_type[15:8] = axis_rx_valid && (ptr_reg == 0) ? axis_rx_data[12*8 +: 8] : 'b0;
assign eth_type[7:0]  = axis_rx_valid && (ptr_reg == 0) ? axis_rx_data[13*8 +: 8] : 'b0;
/* ihl ip header length */
assign ihl_flag       = axis_rx_valid && (ptr_reg == 0) ? axis_rx_data[14*8 +: 4] : 'b0;

assign ipv4_flag = axis_rx_valid && (eth_type == 16'h0800) ? 1'b1 : 'b0;

// generate
//   genvar l, k;
//   /*get the src and dest ip address*/
//   for(l = 0; l < 6; l = l + 1) begin:hash_data1
//     assign hash_data_next[l*8 +: 8] = state_cur == CYCLE_0 ? axis_rx_data[(26+l)*8 +: 8] : hash_data_reg[l*8 +: 8];
//   end
//   for(k = 0; k < 6; k = k + 1) begin:hash_data2
//     assign hash_data_next[(k+6)*8 +: 8] = state_cur == CYCLE_1 ? axis_rx_data[k*8 +: 8] : 'b0;
//   end
// endgenerate

assign hash_data_next[6*8-1:0]      = state_cur == CYCLE_0 ? axis_rx_data[26*8 +: 48] : hash_data_reg;
assign hash_data_next[12*8-1 : 48]  = state_cur == CYCLE_1 ? axis_rx_data[47:0] : 'b0;

assign tcp_udp_flag = axis_rx_valid && (ptr_reg == 23/`DMA_KEEP_WIDTH) && (ihl_flag == 5) ? 
                            (axis_rx_data[(23%`DMA_KEEP_WIDTH)*8 +: 8] == 8'h06) || (axis_rx_data[(23%`DMA_KEEP_WIDTH)*8 +: 8] == 8'h11) : 'b0;


assign state_next = !axis_rx_valid ? state_cur :
                    axis_rx_valid && axis_rx_last ? CYCLE_0 :
                    state_cur == CYCLE_0 && ipv4_flag ? CYCLE_1 :
                    state_cur == CYCLE_0 && !ipv4_flag ? CYCLE_R :
                    state_cur == CYCLE_1 ? CYCLE_R : state_cur;

// first cycle, store the flag
always @(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    ihl_reg           <= `TD   'b0;
    tcp_udp_flag_reg  <= `TD   'b0;
    hash_data_reg     <= `TD   'b0;
  end else begin
    if(axis_rx_valid && axis_rx_last) begin
      ihl_reg           <= `TD   'b0;
      tcp_udp_flag_reg  <= `TD   'b0;
      hash_data_reg     <= `TD   'b0;
    end else if(state_cur == CYCLE_0 && state_next == CYCLE_1) begin
      ihl_reg             <= `TD ihl_flag;
      tcp_udp_flag_reg    <= `TD tcp_udp_flag;
      hash_data_reg       <= `TD hash_data_next[47:0];
    end else begin
      ihl_reg             <= `TD ihl_reg;
      tcp_udp_flag_reg    <= `TD tcp_udp_flag_reg;
      hash_data_reg       <= `TD hash_data_reg;
    end
  end
end

always @(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    ptr_reg <= `TD   'b0;
  end else begin
    if(axis_rx_valid && axis_rx_last) begin
      ptr_reg <= `TD 'b0;
    end else if (axis_rx_valid) begin
      ptr_reg <= `TD   ptr_reg + 1;
    end
  end
end

always@(posedge clk, negedge rst_n) begin
  state_cur <= `TD !rst_n ? CYCLE_0 : state_next;
end

always@(*) begin
  if((state_cur == CYCLE_0 && state_next == CYCLE_0 && axis_rx_last && axis_rx_valid) || 
      (state_cur == CYCLE_0 && state_next == CYCLE_R) ||
      (state_cur == CYCLE_1 && state_next == CYCLE_R) ||
      (state_cur == CYCLE_1 && state_next == CYCLE_0)) begin
    crx_hash_valid = 1;
  end else begin
    crx_hash_valid = 0;
  end
end

always@(*) begin
  if((state_cur == CYCLE_0 && state_next == CYCLE_0 && axis_rx_last && axis_rx_valid) || 
      (state_cur == CYCLE_0 && state_next == CYCLE_R)) begin
    crx_hash        = 0;
  end else if((state_cur == CYCLE_1 && state_next == CYCLE_R) ||
      (state_cur == CYCLE_1 && state_next == CYCLE_0)) begin
    if(ihl_reg == 5 && tcp_udp_flag_reg) begin
      crx_hash        = hash_part_ipv4_ip ^ hash_part_ipv4_port;
    end else begin
      crx_hash        = hash_part_ipv4_ip;
    end
  end else begin
    crx_hash        = 0;
  end      
end

`ifdef ETH_CHIP_DEBUG

wire 		[`RX_HASH_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_data;


assign Dbg_data = {// wire
                  6'b0,
                  axis_rx_valid, axis_rx_last, axis_rx_data, axis_rx_data_be, hash_key, 
                  state_next, hash_data_next, hash_part_ipv4_ip, hash_part_ipv4_port, 
                  eth_type, ipv4_flag, tcp_udp_flag, ihl_flag, 
                  // reg
                  crx_hash, crx_hash_valid, state_cur, hash_data_reg, tcp_udp_flag_reg, ihl_reg, ptr_reg
                  } ;

assign Dbg_bus = Dbg_data >> (Dbg_sel << 5);
//assign Dbg_bus = Dbg_data;

`endif



endmodule
