`timescale 1ns / 100ps
//*************************************************************************
// > File Name: axi_convert.v
// > Author   : Li jianxiong
// > Date     : 2021-10-12
// > Note     : axi_convert is used to manage nic s, including queue number, addr offset .etc
// > V1.1 - 2021-10-12 : 
//*************************************************************************

module axi_int #(
    /* axil parameter */
  parameter AXIL_ADDR_WIDTH = 32
) 
(
  input wire clk,
  input wire rst_n,

  /*axil write signal*/
  input   wire [AXIL_ADDR_WIDTH-1:0]              awaddr_m,
  input   wire                                    awvalid_m,
  output  wire                                    awready_m,
  
  

  input   wire [`AXIL_DATA_WIDTH-1:0]             wdata_m,
  input   wire [`AXIL_STRB_WIDTH-1:0]             wstrb_m,
  input   wire                                    wvalid_m,  
  output  wire                                    wready_m,

  output  wire                                    bvalid_m,
  input   wire                                    bready_m,

  /*axil read signal*/
  input   wire [AXIL_ADDR_WIDTH-1:0]              araddr_m,
  input   wire                                    arvalid_m,
  output  wire                                    arready_m,

  output  wire [`AXIL_DATA_WIDTH-1:0]             rdata_m,
  output  wire                                    rvalid_m,
  input   wire                                    rready_m,

  /*axil write signal*/
  output   wire [AXIL_ADDR_WIDTH-1:0]               awaddr_s,
  output   wire                                     awvalid_s,
  input   wire                                      awready_s,

  output   wire [`AXIL_DATA_WIDTH-1:0]             wdata_s,
  output   wire [`AXIL_STRB_WIDTH-1:0]             wstrb_s,
  output   wire                                    wvalid_s,
  input   wire                                    wready_s,

  input     wire                                    bvalid_s,
  output   wire                                    bready_s,

  /*axil read signal*/
  output   wire [AXIL_ADDR_WIDTH-1:0]              araddr_s,
  output   wire                                    arvalid_s,
  input     wire                                    arready_s,

  input   wire [`AXIL_DATA_WIDTH-1:0]             rdata_s,
  input   wire                                    rvalid_s,
  output   wire                                    rready_s
);


ready_handshake #(
    /* axil parameter */
  .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
  .DATA_EN(0),
  .ADDR_EN(1),
  .STRB_EN(0)
) 
ready_handshake_waddr(
  .clk(clk),
  .rst_n(rst_n),
  
  .push_valid(awvalid_m),
  .push_data({`AXIL_DATA_WIDTH{1'b0}}),
  .push_addr(awaddr_m),
  .push_strb({`AXIL_STRB_WIDTH{1'b0}}),
  .push_ready(awready_m),
  
  .pop_valid(awvalid_s),
  .pop_data(),
  .pop_addr(awaddr_s),
  .pop_strb(),
  .pop_ready(awready_s)
);

ready_handshake #(
    /* axil parameter */
  .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
  .DATA_EN(1),
  .ADDR_EN(0),
  .STRB_EN(1)
) 
ready_handshake_wdata(
  .clk(clk),
  .rst_n(rst_n),
  
  .push_valid(wvalid_m),
  .push_data(wdata_m),
  .push_addr({`AXIL_DATA_WIDTH{1'b0}}),
  .push_strb(wstrb_m),
  .push_ready(wready_m),
  
  .pop_valid(wvalid_s),
  .pop_data(wdata_s),
  .pop_addr(),
  .pop_strb(wstrb_s),
  .pop_ready(wready_s)
);

ready_handshake #(
    /* axil parameter */
  .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
  .DATA_EN(0),
  .ADDR_EN(0),
  .STRB_EN(0)
) 
ready_handshake_brsp(
  .clk(clk),
  .rst_n(rst_n),
  
  .push_valid(bvalid_s),
  .push_data({`AXIL_DATA_WIDTH{1'b0}}),
  .push_addr({`AXIL_DATA_WIDTH{1'b0}}),
  .push_strb({`AXIL_STRB_WIDTH{1'b0}}),
  .push_ready(bready_s),
  
  .pop_valid(bvalid_m),
  .pop_data(),
  .pop_addr(),
  .pop_strb(),
  .pop_ready(bready_m)
);

ready_handshake #(
    /* axil parameter */
  .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
  .DATA_EN(0),
  .ADDR_EN(1),
  .STRB_EN(0)
) 
ready_handshake_rd(
  .clk(clk),
  .rst_n(rst_n),
  
  .push_valid(arvalid_m),
  .push_data({`AXIL_DATA_WIDTH{1'b0}}),
  .push_addr(araddr_m),
  .push_strb({`AXIL_STRB_WIDTH{1'b0}}),
  .push_ready(arready_m),
  
  .pop_valid(arvalid_s),
  .pop_data(),
  .pop_addr(araddr_s),
  .pop_strb(),
  .pop_ready(arready_s)
);

ready_handshake #(
    /* axil parameter */
  .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
  .DATA_EN(1),
  .ADDR_EN(0),
  .STRB_EN(0)
) 
ready_handshake_ra(
  .clk(clk),
  .rst_n(rst_n),
  
  .push_valid(rvalid_s),
  .push_data(rdata_s),
  .push_addr({`AXIL_DATA_WIDTH{1'b0}}),
  .push_strb({`AXIL_STRB_WIDTH{1'b0}}),
  .push_ready(rready_s),
  
  .pop_valid(rvalid_m),
  .pop_data(rdata_m),
  .pop_addr(),
  .pop_strb(),
  .pop_ready(rready_m)
);



endmodule


module ready_handshake #(
    /* axil parameter */
  parameter AXIL_ADDR_WIDTH = 32,
  parameter DATA_EN = 1,
  parameter ADDR_EN = 1,
  parameter STRB_EN = 1
) (
  input  wire  				                  clk,
  input  wire 				                  rst_n,
  
  input  wire 				                  push_valid,
  input  wire [`AXIL_DATA_WIDTH -1:0] 	push_data,
  input  wire [`AXIL_DATA_WIDTH -1:0] 	push_addr,
  input  wire [`AXIL_STRB_WIDTH -1:0]   push_strb,
  output wire 				                  push_ready,
  
  output wire				                    pop_valid,
  output wire  [`AXIL_DATA_WIDTH -1:0] 	pop_data,
  output wire  [AXIL_ADDR_WIDTH-1:0] 	  pop_addr,
  output wire  [`AXIL_STRB_WIDTH -1:0] 	pop_strb,
  input  wire 				                  pop_ready
);


wire 					write_en;	//write enable
wire 					read_en;	//read enable

reg           push_full;

assign push_ready 	= ~push_full; 
assign write_en 	= push_valid & push_ready;
 
assign pop_valid    = push_full;
assign read_en      = pop_valid & pop_ready;

always @(posedge clk or negedge rst_n) begin
  if(~rst_n) 
	  push_full <= `TD 1'b0;
  else if(write_en)
	  push_full <= `TD 1'b1; 
  else if(read_en)
    push_full <= `TD 1'b0;
end 


generate
  if(DATA_EN) begin : DATA_EN_G
    reg  [`AXIL_DATA_WIDTH -1:0] 	pop_data_reg;

    always @(posedge clk or negedge rst_n) begin
      if(~rst_n) begin
        pop_data_reg <= `TD 'd0;
      end else if(write_en) begin
        pop_data_reg <= `TD push_data;
      end
    end
    
    assign pop_data = pop_data_reg; 
  end else begin
    assign pop_data = 'b0; 
  end
endgenerate

generate
  if(ADDR_EN) begin : ADDR_EN_G
    reg  [AXIL_ADDR_WIDTH-1:0] 	  pop_addr_reg;

    always @(posedge clk or negedge rst_n) begin
      if(~rst_n) begin
        pop_addr_reg <= `TD 'd0;
      end else if(write_en) begin
        pop_addr_reg <= `TD push_addr;
      end
    end

    assign pop_addr = pop_addr_reg; 
  end else begin
    assign pop_addr = 'b0; 
  end
endgenerate

generate 
  if(STRB_EN) begin : STRB_EN_G
    reg  [`AXIL_STRB_WIDTH -1:0] 	pop_strb_reg;

    always @(posedge clk or negedge rst_n) begin
      if(~rst_n) begin
        pop_strb_reg <= `TD 'd0;
      end else if(write_en) begin
        pop_strb_reg <= `TD push_strb;
      end
    end

    assign pop_strb = pop_strb_reg; 
  end  else begin
    assign pop_strb = 'b0; 
  end
endgenerate

endmodule


