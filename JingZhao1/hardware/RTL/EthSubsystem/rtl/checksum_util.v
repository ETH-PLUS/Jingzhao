`timescale 1ns / 100ps
//*************************************************************************
// > File Name: checksum_util.v
// > Author   : Li jianxiong
// > Date     : 2021-10-12
// > Note     : checksum_util is used to calculate the checksum of ip datagram
//              for the purpose of offload
//              tree structer 
// > V1.1 - 2021-10-12 : 
//*************************************************************************

module checksum_util #(
  parameter DATA_WIDTH = 256,
  parameter KEEP_WIDTH = DATA_WIDTH / 8,
  parameter REVERSE = 0,
  parameter START_OFFSET = 0 /* ip header start offset is 14 bytes*/
  ,parameter ILA_DEBUG = 0
) (

  input wire clk,
  input wire rst_n,

  /*interface to mac rx  */
  input wire                        csum_data_valid, 
  input wire                        csum_data_last,
  input wire [DATA_WIDTH-1:0]       csum_data,
  input wire [KEEP_WIDTH-1:0]       csum_data_be,

  /*otuput to rx_engine, csum is used for offload*/
  output wire [15:0]                csum_out,
  output wire                       csum_out_valid

`ifdef ETH_CHIP_DEBUG
  // ,input 	  wire		[0 : 0] 		Rw_data
	// ,output 	wire 		[0 : 0] 		Ro_data
	,output 	wire 		[(`CHECKSUM_UTIL_DEG_REG_NUM)  * 32 - 1 : 0]		  Dbg_bus
`endif

);

localparam LEVELS                   = $clog2(DATA_WIDTH/8);
localparam FIRST_CIRCLE_CNT         = DATA_WIDTH/8/4;


wire [DATA_WIDTH-1:0] crx_data_masked; /* choose correct data in stream, remove mac header and data invalid bytes*/
wire [KEEP_WIDTH-1:0] mask_mac_header; /*store mask, indicate the ip header start position*/

reg  [DATA_WIDTH-1:0]        sum_reg[LEVELS-2:0]; 
wire [FIRST_CIRCLE_CNT*17-1:0]       sum_reg_first_cycle; /* store the first level sum result */
reg  [LEVELS-2:0]            sum_valid_reg; /* store the sum valid */
reg  [LEVELS-2:0]            sum_last_reg; /* store the last signal of a frame */

reg [15:0] sum_acc_reg; 
reg [15:0] crx_csum_reg; /* store the final result of checksum */
reg crx_csum_valid_reg; /* checksum output valid */

assign csum_out       = crx_csum_reg;
assign csum_out_valid = crx_csum_valid_reg;

// get the masked data by csum_data_be and mask_reg
// choose correct data in stream, remove mac header and data invalid bytes

generate
  genvar j;
  for(j = 0; j < KEEP_WIDTH; j = j + 1) begin:generate_data_mask

    assign crx_data_masked[j*8 +:8] = (csum_data_be[j] && mask_mac_header[j]) ? csum_data[j*8 +: 8] : 8'b0;
  end
endgenerate

// calculate the first level sum of a cycle
// Sum of two adjacent 16 bits, result is 17 bits
generate
  genvar k;
  for(k = 0; k < FIRST_CIRCLE_CNT; k = k + 1) begin:sum_reg_0
    // because this is the big ending encode, so we have to exchange the positon
    if (REVERSE) begin
        assign sum_reg_first_cycle[k*17 +: 17] =  {crx_data_masked[(4*k+0)*8 +: 8], crx_data_masked[(4*k+1)*8 +: 8]}
                                                        + {crx_data_masked[(4*k+2)*8 +: 8], crx_data_masked[(4*k+3)*8 +: 8]};
    end else begin
        assign sum_reg_first_cycle[k*17 +: 17] =  {crx_data_masked[(4*k+1)*8 +: 8], crx_data_masked[(4*k+0)*8 +: 8]}
                                                        + {crx_data_masked[(4*k+3)*8 +: 8], crx_data_masked[(4*k+2)*8 +: 8]};
    end
  end
endgenerate

// mask the first cycle of a frame because it contains mac header
// the ip checksum doesn't calculate the mac header
assign mask_mac_header      = csum_data_valid ? {KEEP_WIDTH{1'b1}} << START_OFFSET : {KEEP_WIDTH{1'b1}}; 

always @(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    sum_reg[0]          <= `TD 'b0;
    sum_valid_reg[0]    <= `TD 'b0;
    sum_last_reg[0]     <= `TD 'b0;
  end else begin 
    // set reg in posedge clk, negedge rst_n
    if(csum_data_valid) begin
      sum_reg[0]          <= `TD {{(DATA_WIDTH-DATA_WIDTH/16/2*17){1'b0}}, sum_reg_first_cycle[DATA_WIDTH/16/2*17 - 1:0]};
      sum_valid_reg[0]    <= `TD 1'b1;
      sum_last_reg[0]     <= `TD csum_data_last;
    end else begin
      sum_valid_reg[0]    <= `TD 1'b0;
      sum_last_reg[0]     <= `TD 'b0;
    end
  end
end

integer i;
// other level sum calculation
generate
  genvar l;

  for(l = 1; l < LEVELS-1; l = l + 1) begin:sum_reg_other
    always @(posedge clk, negedge rst_n) begin
      if(!rst_n) begin
        sum_valid_reg[l]  <= `TD 1'b0;
        sum_last_reg[l]   <= `TD 1'b0;
        for(i = 0; i < DATA_WIDTH/8/4/(2**l); i = i + 1) begin
          sum_reg[l] <= `TD 'b0;
        end
      end else if(sum_valid_reg[l-1]) begin
        // adjecent  bits add 
        for(i = 0; i < DATA_WIDTH/8/4/(2**l); i = i + 1) begin
          sum_reg[l][i*(17+l) +: (17+l)] <= `TD sum_reg[l-1][(i*2+0)*(17+l-1) +: (17+l-1)] + sum_reg[l-1][(i*2+1)*(17+l-1) +: (17+l-1)];
          sum_reg[l][DATA_WIDTH-1:(DATA_WIDTH/8/4/(2**l))*(17+l)] <= `TD 'b0;
        end
        // set corresponding level valid
        sum_valid_reg[l]  <= `TD 1'b1;
        sum_last_reg[l]   <= `TD sum_last_reg[l-1];
      end else begin
        sum_valid_reg[l]  <= `TD 1'b0;
        sum_last_reg[l]   <= `TD 1'b0;
      end
    end
  end
endgenerate

wire [16+LEVELS-1:0] sum_acc_temp[2:0]; /* store checksum temporary result */

assign sum_acc_temp[0] = sum_reg[LEVELS-2][16+LEVELS-1-1:0] + sum_acc_reg;
assign sum_acc_temp[1] = sum_acc_temp[0][15:0] + (sum_acc_temp[0] >> 16);
assign sum_acc_temp[2] = sum_acc_temp[1][15:0] + sum_acc_temp[1][16];

/* calculate the whole frame */
always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    crx_csum_valid_reg  <= `TD 1'b0;
    sum_acc_reg         <= `TD 'b0;
    crx_csum_reg        <= `TD 'b0;
  end else if(sum_valid_reg[LEVELS-2]) begin
    // if last cycle , output the checksum value
    if(sum_last_reg[LEVELS-2]) begin
      crx_csum_reg          <= `TD ~sum_acc_temp[2];
      crx_csum_valid_reg    <= `TD 1'b1;
      sum_acc_reg           <= `TD 0;
    end else begin
      // cumulative every cycle checksum 
      sum_acc_reg         <= `TD sum_acc_temp[2];
      crx_csum_valid_reg  <= `TD 1'b0;
    end
  end else begin
    crx_csum_valid_reg    <= `TD 1'b0;
  end
end  

`ifdef ETH_CHIP_DEBUG

 assign Dbg_bus = {// wire
                  28'b0,
                  csum_data_valid,  csum_data_last, csum_data, csum_data_be, csum_out, csum_out_valid, crx_data_masked, 
                  mask_mac_header,sum_reg_first_cycle,  

                  // reg
                  sum_valid_reg, sum_last_reg, sum_acc_reg, crx_csum_reg, crx_csum_valid_reg
                  } ;
`endif




endmodule

