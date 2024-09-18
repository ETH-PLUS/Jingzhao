`timescale 1ns / 100ps
//*************************************************************************
// > File Name: desc_fetch.v
// > Author   : Li jianxiong
// > Date     : 2021-10-12
// > Note     : desc_fetch is used for receive the desc from memory.
//              it reveices the desc request from rx engine
//              and initiate a request to the queue management module to get 
//              the queue addr ??? index and other information. 
//              Then get the desc from memory by the queue information.
// > V1.1 - 2021-10-21 : 
//*************************************************************************


module desc_fetch #(
  /* number of descripor tabel */
  parameter DESC_TABLE_SIZE = 128,

  parameter DEBUG_RX = 0
)
(
  input   wire                              clk,
  input   wire                              rst_n,

  /* input from rx_engine, request for a desc */
  input   wire [`QUEUE_NUMBER_WIDTH-1:0]        desc_req_qnum,
  input   wire                                  desc_req_valid,
  output  wire                                  desc_req_ready,

  /* to rx_engine,  return the desc data */
  output  wire [`STATUS_WIDTH-1:0]            desc_rsp_status,
  output  wire [`QUEUE_NUMBER_WIDTH-1:0]      desc_rsp_qnum,
  output  wire [`QUEUE_INDEX_WIDTH-1:0]       desc_rsp_qindex,
  output  wire [`ETH_LEN_WIDTH-1:0]           desc_rsp_length,
  output  wire [`DMA_ADDR_WIDTH-1:0]          desc_rsp_dma_addr,
  output  wire [`DMA_ADDR_WIDTH-1:0]          desc_rsp_desc_addr,
  output  wire [`CSUM_START_WIDTH-1:0]        desc_rsp_csum_start,
  output  wire [`CSUM_START_WIDTH-1:0]        desc_rsp_csum_offset,
  output  wire [`DMA_ADDR_WIDTH-1:0]          desc_rsp_cpl_addr,
  output  wire [`IRQ_MSG-1:0]                 desc_rsp_msix_msg,
  output  wire [`DMA_ADDR_WIDTH-1:0]          desc_rsp_msix_addr,
  output  wire                                desc_rsp_valid,
  input   wire                                desc_rsp_ready,
  // output  wire [`QUEUE_INDEX_WIDTH-1:0]       desc_rsp_head_ptr,
  // output  wire [`QUEUE_INDEX_WIDTH-1:0]       desc_rsp_tail_ptr,
  // output  wire [`QUEUE_INDEX_WIDTH-1:0]       desc_rsp_cpl_head_ptr,
  // output  wire [`QUEUE_INDEX_WIDTH-1:0]       desc_rsp_cpl_tail_ptr,

  /* to queue manager, request for the queue information */
  output wire [`QUEUE_NUMBER_WIDTH-1:0]       desc_dequeue_req_qnum,
  output wire                                 desc_dequeue_req_valid,
  input  wire                                 desc_dequeue_req_ready,

  /* from queue manager */
  input  wire [`QUEUE_NUMBER_WIDTH-1:0]       desc_dequeue_resp_qnum,
  input  wire [`QUEUE_INDEX_WIDTH-1:0]        desc_dequeue_resp_qindex,
  input  wire [`DMA_ADDR_WIDTH-1:0]           desc_dequeue_resp_desc_addr,
  input  wire [`DMA_ADDR_WIDTH-1:0]           desc_dequeue_resp_cpl_addr,
  input  wire [`MSI_NUM_WIDTH-1:0]            desc_dequeue_resp_msi,
  input  wire [`STATUS_WIDTH-1:0]             desc_dequeue_resp_status,
  input  wire                                 desc_dequeue_resp_valid,
  // input  wire [`QUEUE_INDEX_WIDTH-1:0]        desc_dequeue_resp_head_ptr,
  // input  wire [`QUEUE_INDEX_WIDTH-1:0]        desc_dequeue_resp_tail_ptr,
  // input  wire [`QUEUE_INDEX_WIDTH-1:0]        desc_dequeue_resp_cpl_head_ptr,
  // input  wire [`QUEUE_INDEX_WIDTH-1:0]        desc_dequeue_resp_cpl_tail_ptr,

  /* to dma module, to get the desc */
  output wire                                 desc_dma_req_valid,
  output wire                                 desc_dma_req_last,
  output wire [`DMA_DATA_WIDTH-1:0]           desc_dma_req_data,
  output wire [`DMA_HEAD_WIDTH-1:0]           desc_dma_req_head,
  input  wire                                  desc_dma_req_ready,

  /* to dma module, to get the desc */
  input   wire                                desc_dma_rsp_valid,
  input   wire                                desc_dma_rsp_last,
  input   wire [`DMA_DATA_WIDTH-1:0]          desc_dma_rsp_data,
  input   wire [`DMA_HEAD_WIDTH-1:0]          desc_dma_rsp_head,
  output  wire                                desc_dma_rsp_ready,

  output wire [`MSI_NUM_WIDTH-1:0]               irq_req_msix,
  output wire                                   irq_req_valid,
  input  wire                                   irq_req_ready,

  input   wire   [`IRQ_MSG-1:0]                 irq_rsp_msg,
  input   wire   [`DMA_ADDR_WIDTH-1:0]          irq_rsp_addr,
  input   wire                                  irq_rsp_valid,
  output  wire                                  irq_rsp_ready

  ,output reg [31:0]                           desc_fetch_req_cnt
  ,output reg [31:0]                           desc_fetch_rsp_cnt
  ,output reg [31:0]                           desc_fetch_error_cnt

`ifdef ETH_CHIP_DEBUG
  // ,input 	  wire		[0 : 0] 		Rw_data
	// ,output 	wire 		[0 : 0] 		Ro_data
	,output 	wire 		[(`DESC_FETCH_DEG_REG_NUM)  * 32 - 1 : 0]		  Dbg_bus
`endif

  `ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved | reserved | idx | end | out |
     * |  255:10  |   9:5    | 4:2 |  1  |  0  |
     */
    ,output wire [255:0] debug
    /* ------- Debug interface {end}------- */
  `endif

);

localparam CL_DESC_TABLE_SIZE = $clog2(DESC_TABLE_SIZE);
localparam DESC_PTR_MASK      ={1'b0, {CL_DESC_TABLE_SIZE{1'b1}}};

/* corresponding ptr of the desc table */
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_start_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_dequeue_start_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_dequeue_finish_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_desc_fetch_start_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_desc_fetch_finish_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_msix_fetch_start_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_msix_fetch_finish_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_finish_ptr;

/* store the corresponding massage */
reg [`QUEUE_NUMBER_WIDTH-1:0]       desc_table_qnum[DESC_TABLE_SIZE-1:0]; 
reg [`QUEUE_INDEX_WIDTH-1:0]        desc_table_qindex[DESC_TABLE_SIZE-1:0]; 
reg [`DMA_ADDR_WIDTH-1:0]           desc_table_queue_addr[DESC_TABLE_SIZE-1:0];
reg [`DMA_ADDR_WIDTH-1:0]           desc_table_cpl_addr[DESC_TABLE_SIZE-1:0];
reg [`MSI_NUM_WIDTH-1:0]            desc_table_msix[DESC_TABLE_SIZE-1:0];
reg [`STATUS_WIDTH-1:0]             desc_table_desc_status[DESC_TABLE_SIZE-1:0]; 
reg [`DMA_ADDR_WIDTH-1:0]           desc_table_desc_dma_addr[DESC_TABLE_SIZE-1:0];
reg [`ETH_LEN_WIDTH-1:0]            desc_table_desc_dma_len[DESC_TABLE_SIZE-1:0];
reg [`CSUM_START_WIDTH-1:0]         desc_table_tx_csum_start[DESC_TABLE_SIZE-1:0];
reg [`CSUM_START_WIDTH-1:0]         desc_table_tx_csum_offset[DESC_TABLE_SIZE-1:0];
reg [`IRQ_MSG-1:0]                  desc_table_msix_msg[DESC_TABLE_SIZE-1:0];
reg [`DMA_ADDR_WIDTH-1:0]           desc_table_msix_addr[DESC_TABLE_SIZE-1:0];
// reg [`DMA_DATA_WIDTH-1:0]           desc_table_head_ptr[DESC_TABLE_SIZE-1:0];
// reg [`DMA_DATA_WIDTH-1:0]           desc_table_tail_ptr[DESC_TABLE_SIZE-1:0];
// reg [`DMA_DATA_WIDTH-1:0]           desc_table_cpl_head_ptr[DESC_TABLE_SIZE-1:0];
// reg [`DMA_DATA_WIDTH-1:0]           desc_table_cpl_tail_ptr[DESC_TABLE_SIZE-1:0];

/*  */
wire  desc_table_start_en;
wire  desc_dequeue_start_en;
wire  desc_dequeue_finish_en;
wire  desc_fetch_start_en;
wire  desc_detch_finish_en;
wire  desc_irq_start_en;
wire  desc_irq_finish_en;
wire  desc_table_finish_en;


/* -------get a desc request {begin}------- */
assign desc_req_ready       = $unsigned(desc_table_start_ptr - desc_table_finish_ptr) < DESC_TABLE_SIZE;
assign desc_table_start_en  = desc_req_ready && desc_req_valid;

integer i;
/* store the request queue */
always @(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_start_ptr <= `TD  1'b0;
    for(i = 0; i < DESC_TABLE_SIZE; i = i + 1) begin:inist_qnum
      desc_table_qnum[i]                     <= `TD 0;
    end
  end else begin
    if(desc_table_start_en) begin
      desc_table_qnum[desc_table_start_ptr[CL_DESC_TABLE_SIZE-1:0]] <= `TD  desc_req_qnum;
      desc_table_start_ptr                  <= `TD  desc_table_start_ptr + 1'b1;
    end
  end
end
/* -------get a desc request {end}------- */

/* -------to queue manager, request for the queue information {begin}------- */
assign desc_dequeue_req_valid = desc_table_dequeue_start_ptr != desc_table_start_ptr;
assign desc_dequeue_req_qnum =  desc_table_qnum[desc_table_dequeue_start_ptr[CL_DESC_TABLE_SIZE-1:0]];
assign desc_dequeue_start_en  = desc_dequeue_req_valid && desc_dequeue_req_ready;

always @(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_dequeue_start_ptr <= `TD  1'b0;
  end else begin
    if(desc_dequeue_start_en) begin
      desc_table_dequeue_start_ptr                  <= `TD  desc_table_dequeue_start_ptr + 1'b1;
    end
  end
end
/* -------to queue manager, request for the queue information {end}------- */

 /* -------get queue information from queue manager {begin}------- */
assign desc_dequeue_finish_en = desc_dequeue_resp_valid;
/* store the queue infomation, include queue index, descriptor address etc. */
integer j;
always @(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_dequeue_finish_ptr <= `TD  1'b0;
    for(j = 0; j < DESC_TABLE_SIZE; j = j + 1) begin:init_start
      desc_table_qindex[j]              <= `TD 0;
      desc_table_cpl_addr[j]            <= `TD 0;
      desc_table_queue_addr[j]          <= `TD 0;
      desc_table_msix[j]                <= `TD 0;
      desc_table_desc_status[j]         <= `TD 0;
    end
  end else begin
    if(desc_dequeue_finish_en) begin
      desc_table_dequeue_finish_ptr                                         <= `TD  desc_table_dequeue_finish_ptr + 1'b1;
      desc_table_qindex[desc_table_dequeue_finish_ptr[CL_DESC_TABLE_SIZE-1:0]]      <= `TD  desc_dequeue_resp_qindex;
      desc_table_cpl_addr[desc_table_dequeue_finish_ptr[CL_DESC_TABLE_SIZE-1:0]]    <= `TD  desc_dequeue_resp_cpl_addr;
      desc_table_queue_addr[desc_table_dequeue_finish_ptr[CL_DESC_TABLE_SIZE-1:0]]  <= `TD  desc_dequeue_resp_desc_addr;
      desc_table_msix[desc_table_dequeue_finish_ptr[CL_DESC_TABLE_SIZE-1:0]]         <= `TD desc_dequeue_resp_msi;
      desc_table_desc_status[desc_table_dequeue_finish_ptr[CL_DESC_TABLE_SIZE-1:0]] <= `TD  desc_dequeue_resp_status;
    end
  end
end
 /* -------get queue information from queue manager {end}------- */

 /* -------begin to fetch the desc {begin}------- */
wire  desc_dma_req_error;

assign desc_dma_req_error = desc_table_desc_fetch_start_ptr != desc_table_dequeue_finish_ptr && 
                                desc_table_desc_status[desc_table_desc_fetch_start_ptr[CL_DESC_TABLE_SIZE-1:0]] == 8'b0;

assign desc_dma_req_valid = desc_table_desc_fetch_start_ptr != desc_table_dequeue_finish_ptr && !desc_dma_req_error; 

assign desc_dma_req_last =  desc_dma_req_valid;

/* dma_*_head(interact with RDMA modules), valid only in first beat of a packet
    * | Reserved | address | Reserved | Byte length |
    * |  127:96  |  95:32  |  31:13   |    12:0     |
    */
assign desc_dma_req_head  = {32'b0, 
                            desc_table_queue_addr[desc_table_desc_fetch_start_ptr[CL_DESC_TABLE_SIZE-1:0]],                                                                
                            32'd16};

assign desc_dma_req_data = 'b0;

assign desc_fetch_start_en  = desc_dma_req_valid && desc_dma_req_ready;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_desc_fetch_start_ptr <= `TD  'b0;
  end else begin
    if(desc_fetch_start_en || desc_dma_req_error) begin
      desc_table_desc_fetch_start_ptr <= `TD  desc_table_desc_fetch_start_ptr + 1'b1;
    end
  end
end
 /* -------begin to fetch the desc {end}------- */

 /* -------get the desc, finish the fetch operation {begin}------- */
wire desc_dma_rsp_error;

assign desc_dma_rsp_error   = desc_table_desc_fetch_finish_ptr !=  desc_table_desc_fetch_start_ptr  && 
                                desc_table_desc_status[desc_table_desc_fetch_finish_ptr[CL_DESC_TABLE_SIZE-1:0]] == 8'b0;


assign desc_dma_rsp_ready   = desc_table_desc_fetch_finish_ptr !=  desc_table_desc_fetch_start_ptr  && 
                                desc_table_desc_status[desc_table_desc_fetch_finish_ptr[CL_DESC_TABLE_SIZE-1:0]] == 8'hFF;

assign desc_detch_finish_en = desc_dma_rsp_valid && desc_dma_rsp_ready;

integer k;
always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_desc_fetch_finish_ptr <= `TD  'b0;
    for(k = 0; k < DESC_TABLE_SIZE; k = k + 1) begin:init_desc
      desc_table_desc_dma_addr[k]              <= `TD 0;
      desc_table_desc_dma_len[k]            <= `TD 0;
      desc_table_tx_csum_start[k]          <= `TD 0;
      desc_table_tx_csum_offset[k]                <= `TD 0;
    end
  end else begin
    if(desc_detch_finish_en || desc_dma_rsp_error) begin
      desc_table_desc_fetch_finish_ptr <= `TD  desc_table_desc_fetch_finish_ptr + 1'b1;
      desc_table_desc_dma_addr[desc_table_desc_fetch_finish_ptr[CL_DESC_TABLE_SIZE-1:0]]  <= `TD  desc_dma_rsp_data[127:64];
      desc_table_desc_dma_len[desc_table_desc_fetch_finish_ptr[CL_DESC_TABLE_SIZE-1:0]]   <= `TD  desc_dma_rsp_data[48:32];
      desc_table_tx_csum_start[desc_table_desc_fetch_finish_ptr[CL_DESC_TABLE_SIZE-1:0]]  <= `TD  desc_dma_rsp_data[16+:8];
      desc_table_tx_csum_offset[desc_table_desc_fetch_finish_ptr[CL_DESC_TABLE_SIZE-1:0]] <= `TD  desc_dma_rsp_data[24+:8];
    end
  end
end
/* -------get the desc, finish the fetch operation {end}------- */


 /* -------begin to fetch msix msg {begin}------- */
wire  irq_req_error;

assign irq_req_error = desc_table_msix_fetch_start_ptr != desc_table_dequeue_finish_ptr && 
                                desc_table_desc_status[desc_table_msix_fetch_start_ptr[CL_DESC_TABLE_SIZE-1:0]] == 8'b0;

assign irq_req_valid = desc_table_msix_fetch_start_ptr != desc_table_dequeue_finish_ptr && !irq_req_error; 

assign irq_req_msix   = desc_table_msix[desc_table_msix_fetch_start_ptr[CL_DESC_TABLE_SIZE-1:0]];

assign desc_irq_start_en  = irq_req_valid && irq_req_ready;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_msix_fetch_start_ptr <= `TD  'b0;
  end else begin
    if(desc_irq_start_en || irq_req_error) begin
      desc_table_msix_fetch_start_ptr <= `TD  desc_table_msix_fetch_start_ptr + 1'b1;
    end
  end
end
 /* -------begin to fetch msix msg {end}------- */

 /* -------get the desc, finish the fetch operation {begin}------- */
wire irq_rsp_error;

assign irq_rsp_error = desc_table_msix_fetch_finish_ptr !=  desc_table_msix_fetch_start_ptr  && 
                                desc_table_desc_status[desc_table_msix_fetch_finish_ptr[CL_DESC_TABLE_SIZE-1:0]] == 8'b0;

assign irq_rsp_ready = irq_rsp_valid;

assign desc_irq_finish_en = irq_rsp_valid && irq_rsp_ready;

integer l;
always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_msix_fetch_finish_ptr <= `TD  'b0;
    for(l = 0; l < DESC_TABLE_SIZE; l = l + 1) begin:init_msix
      desc_table_msix_msg[l]              <= `TD 0;
      desc_table_msix_addr[l]            <= `TD 0;
    end
  end else begin
    if(desc_irq_finish_en || irq_rsp_error) begin
      desc_table_msix_fetch_finish_ptr <= `TD  desc_table_msix_fetch_finish_ptr + 1'b1;
      desc_table_msix_msg[desc_table_msix_fetch_finish_ptr[CL_DESC_TABLE_SIZE-1:0]]   <= `TD  irq_rsp_msg;
      desc_table_msix_addr[desc_table_msix_fetch_finish_ptr[CL_DESC_TABLE_SIZE-1:0]]  <= `TD  irq_rsp_addr;
    end
  end
end


/* -------get the desc, finish the fetch operation {end}------- */

/* -------return the desc data, finish the operation {begin}------- */
assign desc_rsp_status            = desc_table_desc_status[desc_table_finish_ptr[CL_DESC_TABLE_SIZE-1:0]];
assign desc_rsp_qnum              = desc_table_qnum[desc_table_finish_ptr[CL_DESC_TABLE_SIZE-1:0]];
assign desc_rsp_qindex            = desc_table_qindex[desc_table_finish_ptr[CL_DESC_TABLE_SIZE-1:0]];
assign desc_rsp_length            = desc_table_desc_dma_len[desc_table_finish_ptr[CL_DESC_TABLE_SIZE-1:0]];
assign desc_rsp_dma_addr          = desc_table_desc_dma_addr[desc_table_finish_ptr[CL_DESC_TABLE_SIZE-1:0]];
assign desc_rsp_desc_addr         = desc_table_queue_addr[desc_table_finish_ptr[CL_DESC_TABLE_SIZE-1:0]];
assign desc_rsp_csum_start        = desc_table_tx_csum_start[desc_table_finish_ptr[CL_DESC_TABLE_SIZE-1:0]];
assign desc_rsp_csum_offset       = desc_table_tx_csum_offset[desc_table_finish_ptr[CL_DESC_TABLE_SIZE-1:0]];
assign desc_rsp_cpl_addr          = desc_table_cpl_addr[desc_table_finish_ptr[CL_DESC_TABLE_SIZE-1:0]];
assign desc_rsp_msix_msg          = desc_table_msix_msg[desc_table_finish_ptr[CL_DESC_TABLE_SIZE-1:0]];
assign desc_rsp_msix_addr         = desc_table_msix_addr[desc_table_finish_ptr[CL_DESC_TABLE_SIZE-1:0]];
assign desc_rsp_valid             = desc_table_finish_ptr != desc_table_desc_fetch_finish_ptr 
                                    && desc_table_finish_ptr != desc_table_msix_fetch_finish_ptr ;

assign desc_table_finish_en       = desc_rsp_valid && desc_rsp_ready;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_finish_ptr <= `TD  'b0;
  end else if(desc_table_finish_en) begin
    desc_table_finish_ptr <= `TD  desc_table_finish_ptr + 1'b1;
  end
end
/* -------return the desc data, finish the operation {end}------- */



always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_fetch_req_cnt <= `TD  'b0;
  end else if(desc_dequeue_start_en) begin
    desc_fetch_req_cnt <= `TD  desc_fetch_req_cnt + 1'b1;
  end
end


always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_fetch_rsp_cnt                <= `TD 'b0;
  end else begin
    if(desc_rsp_valid & desc_rsp_ready) begin
      desc_fetch_rsp_cnt <= `TD desc_fetch_rsp_cnt + 1'b1;
    end
  end
end
always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_fetch_error_cnt                <= `TD 'b0;
  end else begin
    if(desc_dma_req_error) begin
      desc_fetch_error_cnt <= `TD desc_fetch_error_cnt + 1'b1;
    end
  end
end

/* -------return the desc data, finish the operation {end}------- */

`ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved | reserved | idx | end | out |
     * |  255:10  |   9:5    | 4:2 |  1  |  0  |
     */
    assign debug[8:0] = {
      irq_req_error,
      (irq_req_valid && irq_req_ready),
      (irq_req_valid && irq_req_ready) || irq_req_error,
      desc_dma_rsp_error,
      (desc_dma_rsp_valid && desc_dma_rsp_ready),
       (desc_dma_rsp_valid && desc_dma_rsp_ready) || desc_dma_rsp_error,
      desc_dma_req_error,
      (desc_dma_req_valid && desc_dma_req_ready), 
      (desc_dma_req_valid && desc_dma_req_ready) || desc_dma_req_error
    };

    assign debug[47:32]  = desc_table_qnum[desc_table_desc_fetch_start_ptr[CL_DESC_TABLE_SIZE-1:0]];
    assign debug[63:48]  = desc_table_qindex[desc_table_desc_fetch_start_ptr[CL_DESC_TABLE_SIZE-1:0]];
    /* ------- Debug interface {end}------- */
`endif


`ifdef ETH_CHIP_DEBUG

 assign Dbg_bus = {// wire
                  3'b0,
                  desc_req_qnum, desc_req_valid, desc_req_ready, desc_rsp_status, desc_rsp_qnum, 
                  desc_rsp_qindex, desc_rsp_length, desc_rsp_dma_addr, desc_rsp_desc_addr, 
                  desc_rsp_csum_start, desc_rsp_csum_offset, desc_rsp_cpl_addr, desc_rsp_msix_msg, 
                  desc_rsp_msix_addr, desc_rsp_valid, desc_rsp_ready, desc_dequeue_req_qnum, 
                  desc_dequeue_req_valid, desc_dequeue_req_ready, desc_dequeue_resp_qnum, 
                  desc_dequeue_resp_qindex, desc_dequeue_resp_desc_addr, desc_dequeue_resp_cpl_addr, 
                  desc_dequeue_resp_msi, desc_dequeue_resp_status, desc_dequeue_resp_valid, 
                  desc_dma_req_valid, desc_dma_req_last, desc_dma_req_data, desc_dma_req_head, 
                  desc_dma_req_ready, desc_dma_rsp_valid, desc_dma_rsp_last, desc_dma_rsp_data, 
                  desc_dma_rsp_head, desc_dma_rsp_ready, 
                  irq_req_msix, irq_req_valid, irq_req_ready, irq_rsp_msg, irq_rsp_addr, irq_rsp_valid, irq_rsp_ready, 
                  desc_table_start_en, desc_dequeue_start_en, desc_dequeue_finish_en, desc_fetch_start_en, 
                  desc_detch_finish_en, desc_irq_start_en, desc_irq_finish_en, desc_table_finish_en, 
                  desc_dma_req_error, desc_dma_rsp_error, irq_req_error, irq_rsp_error, 


                  // reg
                  desc_fetch_req_cnt, desc_fetch_rsp_cnt, desc_fetch_error_cnt, desc_table_start_ptr, 
                  desc_table_dequeue_start_ptr, desc_table_dequeue_finish_ptr, desc_table_desc_fetch_start_ptr, 
                  desc_table_desc_fetch_finish_ptr, desc_table_msix_fetch_start_ptr, desc_table_msix_fetch_finish_ptr, desc_table_finish_ptr
                  } ;
`endif





endmodule