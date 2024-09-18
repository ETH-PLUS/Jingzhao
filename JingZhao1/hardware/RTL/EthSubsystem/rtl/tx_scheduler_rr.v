`timescale 1ns / 100ps
//*************************************************************************
// > File Name: tx_scheduler.v
// > Author   : Li jianxiong
// > Date     : 2021-10-29
// > Note     : tx_scheduler is used schedule the tx desc in tx queues
//              TODO: just used first in first out,
//              
// > V1.1 - 2021-10-21 : 
//*************************************************************************

module tx_scheduler_rr #(
  parameter QUEUE_COUNT = 32,
  parameter AXIL_ADDR_WIDTH = 12
) (
  input  wire                               clk,
  input  wire                               rst_n,

  input  wire                                   start_sche,

  input  wire [AXIL_ADDR_WIDTH-1:0]             awaddr_queue,
  input  wire                                   awvalid_queue,
  input  wire                                   awready_queue,
  input  wire [`AXIL_DATA_WIDTH-1:0]            wdata_queue,
  input  wire                                   wvalid_queue,
  input  wire                                   wready_queue,

  output wire  [`QUEUE_NUMBER_WIDTH-1:0]          desc_req_qnum,
  output wire                                     desc_req_valid,
  input  wire                                     desc_req_ready

`ifdef ETH_CHIP_DEBUG
  ,input 	wire 	[`RW_DATA_NUM_TX_SCHEDULER * 32 - 1 : 0]	rw_data
	// ,output 	  wire 		[0 : 0] 		Ro_data
	,output 	wire 		[`TX_SCHD_RR_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_bus
`endif
);

localparam CL_QUEUE_COUNT            = $clog2(QUEUE_COUNT);

wire [`QUEUE_NUMBER_WIDTH-1:0]      fifo_queue;
wire                                fifo_wr;
wire                                fifo_rd;
wire                                fifo_empty;
wire                                fifo_full;

reg   [`QUEUE_NUMBER_WIDTH-1:0]      arbiter_queue;

reg [`QUEUE_INDEX_WIDTH-1:0]      queue_head_ptr_ram  [QUEUE_COUNT-1:0];
reg [`QUEUE_INDEX_WIDTH-1:0]      queue_tail_ptr_ram  [QUEUE_COUNT-1:0];

wire [QUEUE_COUNT-1:0]            arbiter_in;
wire [QUEUE_COUNT-1:0]            arbiter_out;

//wire dequeue_en;
wire initqueue_en;

/* -------manage queue ram {begin}------- */
reg [AXIL_ADDR_WIDTH-1:0] awaddr_queue_reg;

wire [CL_QUEUE_COUNT-1:0]    queue_ram_ptr; // store queue_ram operate ptr
wire [3:0]                   axil_reg_addr;  /* axil lite operate register addr */


always @(posedge clk, negedge rst_n) begin
  if(!rst_n)  awaddr_queue_reg <=  `TD 'b0;
  else        awaddr_queue_reg <=  `TD awvalid_queue && awready_queue ? awaddr_queue : awaddr_queue_reg;  
end

assign queue_ram_ptr    = awaddr_queue_reg >> 6;
assign axil_reg_addr    = awaddr_queue_reg >> 2;

integer i, j;
always @(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    for(i = 0; i < QUEUE_COUNT; i = i + 1) begin:init_head
      queue_head_ptr_ram[i]              <= `TD 0;
    end
  end else if(wvalid_queue && wready_queue && axil_reg_addr == 4'h4) begin
    queue_head_ptr_ram[queue_ram_ptr]     <= `TD wdata_queue;
  end
end


always @(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    for(j = 0; j < QUEUE_COUNT; j = j + 1) begin:init_tail
      queue_tail_ptr_ram[j]              <= `TD 0;
    end
  end else if(wvalid_queue && wready_queue && axil_reg_addr ==  4'h6) begin
    queue_tail_ptr_ram[queue_ram_ptr]     <= `TD wdata_queue;
  end else if(fifo_wr) begin
    queue_tail_ptr_ram[arbiter_queue[CL_QUEUE_COUNT-1:0]]     <= `TD queue_tail_ptr_ram[arbiter_queue[CL_QUEUE_COUNT-1:0]] + 1;
  end
end


assign initqueue_en = wvalid_queue && wready_queue && axil_reg_addr ==  4'h6;

/* -------manage queue ram {end}------- */

/* -------arbiter {begin}------- */
generate
  genvar l;
  for(l = 0; l < QUEUE_COUNT; l = l + 1) begin:gen_arbiter_in
    assign arbiter_in[l] = queue_tail_ptr_ram[l] != queue_head_ptr_ram[l];
  end
endgenerate

round_robin_arbiter #(
  .N(QUEUE_COUNT)
) 
rr_arbiter(
	.rst_n(rst_n),
	.clk(clk),
	.req(arbiter_in),
	.grant(arbiter_out)
);

always@ (*) begin
  case (arbiter_out)
    32'h00000001: arbiter_queue = 'h0;
    32'h00000002: arbiter_queue = 'h1;
    32'h00000004: arbiter_queue = 'h2;
    32'h00000008: arbiter_queue = 'h3;
    32'h00000010: arbiter_queue = 'h4;
    32'h00000020: arbiter_queue = 'h5;
    32'h00000040: arbiter_queue = 'h6;
    32'h00000080: arbiter_queue = 'h7;
    32'h00000100: arbiter_queue = 'h8;
    32'h00000200: arbiter_queue = 'h9;
    32'h00000400: arbiter_queue = 'ha;
    32'h00000800: arbiter_queue = 'hb;
    32'h00001000: arbiter_queue = 'hc;
    32'h00002000: arbiter_queue = 'hd;
    32'h00004000: arbiter_queue = 'he;
    32'h00008000: arbiter_queue = 'hf;
    32'h00010000: arbiter_queue = 'h10;
    32'h00020000: arbiter_queue = 'h11;
    32'h00040000: arbiter_queue = 'h12;
    32'h00080000: arbiter_queue = 'h13;
    32'h00100000: arbiter_queue = 'h14;
    32'h00200000: arbiter_queue = 'h15;
    32'h00400000: arbiter_queue = 'h16;
    32'h00800000: arbiter_queue = 'h17;
    32'h01000000: arbiter_queue = 'h18;
    32'h02000000: arbiter_queue = 'h19;
    32'h04000000: arbiter_queue = 'h1a;
    32'h08000000: arbiter_queue = 'h1b;
    32'h10000000: arbiter_queue = 'h1c;
    32'h20000000: arbiter_queue = 'h1d;
    32'h40000000: arbiter_queue = 'h1e;
    32'h80000000: arbiter_queue = 'h1f;
    default:      arbiter_queue = 'h0;
  endcase
end

assign fifo_wr = arbiter_out && !fifo_full && !initqueue_en && start_sche;


eth_sync_fifo_2psram  
#( .DATA_WIDTH(16),
  .FIFO_DEPTH(`TX_SCHED_FIFO_DEPTH)
) rr_arbiter_fifo (
  .clk  (clk  ),
  .rst_n(rst_n),
  .wr_en(fifo_wr),
  .din  (arbiter_queue),
  .full (),
  .progfull (fifo_full),
  .rd_en(fifo_rd),
  .dout (fifo_queue),
  .empty(fifo_empty),
  .empty_entry_num(),
  .count()
  `ifdef ETH_CHIP_DEBUG
    ,.rw_data(rw_data)
  `endif
);

/* -------arbiter {end}------- */

/* -------output {end}------- */

assign desc_req_qnum    = fifo_queue;
assign desc_req_valid   = !fifo_empty;
assign fifo_rd          = desc_req_valid && desc_req_ready;

/* -------output {end}------- */

`ifdef ETH_CHIP_DEBUG

assign Dbg_bus = {6'b0, arbiter_in, //32
                        arbiter_out,  //32
//                        dequeue_en,  // 1
                        initqueue_en,  // 1
                        queue_ram_ptr, // 4
                        axil_reg_addr,  //4
                        fifo_queue,  // 16
                        fifo_wr,  // 1
                        fifo_rd,  // 1
                        fifo_empty,  //1
                        fifo_full,  // 1
                        arbiter_queue,  // 16
                        awaddr_queue_reg
                        } ;



`endif
// assign Ro_data = {  
//     {32-`QUEUE_INDEX_WIDTH{1'b0}}, queue_head_ptr_ram},
//     {32-`QUEUE_INDEX_WIDTH{1'b0}}, queue_tail_ptr_ram},
//     {32-AXIL_ADDR_WIDTH{1'b0}}, awaddr_queue_reg}
//   }

// assign Dbg_bus = {  
//     {32-`QUEUE_NUMBER_WIDTH{1'b0}}, fifo_queue},
//     {32-1{1'b0}}, fifo_wr},
//     {32-1{1'b0}}, fifo_rd},
//     {32-1{1'b0}}, fifo_empty},
//     {32-1{1'b0}}, fifo_full},
//     {32-QUEUE_COUNT{1'b0}}, arbiter_in},
//     {32-QUEUE_COUNT{1'b0}}, arbiter_out},
//     {32-1{1'b0}}, dequeue_en},
//     {32-1{1'b0}}, initqueue_en},
//     {32-CL_QUEUE_COUNT{1'b0}}, queue_ram_ptr},
//     {32-4{1'b0}}, axil_reg_addr},
//   }


// `define CAT(x, y) PRIMITIVE_CAT(x, y)
// `define CAT(x, y) PRIMITIVE_CAT(x, y)

// `define GET_SEC(x, n, ...) n
// `define CHECK(...) GET_SEC(__VA_ARGS__, 0)
// `define PROBE(x) x, 1

// `define IS_EMPTY(x) CHECK(CAT(PRIMITIVE_CAT(IS_EMPTY_, x), 0))
// `define IS_EMPTY_0 PROBE()

// `define FOR_EACH(macro, x, ...) CAT(FOR_EACH_, IS_EMPTY(__VA_ARGS__)) (macro, x, __VA_ARGS__)
// `define FOR_EACH_0(macro, x, ...) macro(x) DEFER(FOR_EACH_I)() (macro, __VA_ARGS__)
// `define FOR_EACH_1(...) macro(x)
// `define FOR_EACH_I() FOR_EACH
// // EXPAND(EXPAND(EXPAND(FOR_EACH(FOO, x, y, z))))  -> void x(); void y(); void z();

// `define FOO(x) wire x();

// `define EVAL(...)  EVAL1(EVAL1(EVAL1(__VA_ARGS__)))
// `define EVAL1(...) EVAL2(EVAL2(EVAL2(__VA_ARGS__)))
// `define EVAL2(...) EVAL3(EVAL3(EVAL3(__VA_ARGS__)))
// `define EVAL3(...) EVAL4(EVAL4(EVAL4(__VA_ARGS__)))
// `define EVAL4(...) EVAL5(EVAL5(EVAL5(__VA_ARGS__)))
// `define EVAL5(...) __VA_ARGS__

// EVAL(FOR_EACH(FOO, xx, yy, zz)) // -> void x(); void y(); void z();


endmodule

