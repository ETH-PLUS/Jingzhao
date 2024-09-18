`timescale 1ns / 100ps
//*************************************************************************
// > File Name: desc_provider.v
// > Author   : Li jianxiong
// > Date     : 2021-11-02
// > Note     : desc_provider is used to provide desc to len engine,
//              it contains rx and tx queue_manager, desc_fetch
//              
// > V1.1 - 2021-11-02 : 
//*************************************************************************

module desc_provider #(
  parameter AXIL_ADDR_WIDTH = 32,

  parameter QUEUE_COUNT = 32,
  parameter DESC_TABLE_SIZE = 128 /* number of descripor tabel */
  , parameter DEBUG_RX = 0
)
(
  input wire                                clk,
  input wire                                rst_n,

  /* to dma module, to get the desc */
  output wire                               desc_dma_req_valid,
  output wire                               desc_dma_req_last,
  output wire [`DMA_DATA_WIDTH-1:0]          desc_dma_req_data,
  output wire [`DMA_HEAD_WIDTH-1:0]          desc_dma_req_head,
  input  wire                               desc_dma_req_ready,

  /* to dma module, to get the desc */
  input   wire                               desc_dma_rsp_valid,
  input   wire [`DMA_DATA_WIDTH-1:0]          desc_dma_rsp_data,
  input   wire [`DMA_HEAD_WIDTH-1:0]          desc_dma_rsp_head,
  input   wire                               desc_dma_rsp_last,
  output  wire                               desc_dma_rsp_ready,

  /* input from engine, request for a desc */
  input   wire [`QUEUE_NUMBER_WIDTH-1:0]     desc_req_qnum,
  input   wire                              desc_req_valid,
  output  wire                              desc_req_ready,

  output wire  [`QUEUE_NUMBER_WIDTH-1:0]     doorbell_queue,
  output wire                               doorbell_valid,

  /* to engine,  return the desc data */
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


  output wire [`MSI_NUM_WIDTH-1:0]               irq_req_msix,
  output wire                                   irq_req_valid,
  input  wire                                   irq_req_ready,

  input   wire   [`IRQ_MSG-1:0]                 irq_rsp_msg,
  input   wire   [`DMA_ADDR_WIDTH-1:0]          irq_rsp_addr,
  input   wire                                  irq_rsp_valid,
  output  wire                                  irq_rsp_ready,

  /* input from len engine , finish cpl */
  input   wire [`QUEUE_NUMBER_WIDTH-1:0]      cpl_finish_qnum,
  input   wire                                cpl_finish_valid,
  output  wire                                cpl_finish_ready,

  /*axil write signal*/
  input wire [AXIL_ADDR_WIDTH-1:0]            awaddr_queue,
  input wire                                  awvalid_queue,
  output  wire                                awready_queue,
  input wire [`AXIL_DATA_WIDTH-1:0]            wdata_queue,
  input wire [`AXIL_STRB_WIDTH-1:0]            wstrb_queue,
  input wire                                  wvalid_queue,
  output  wire                                wready_queue,
  output  wire                                bvalid_queue,
  input wire                                  bready_queue,
  /*axil read signal*/
  input wire [AXIL_ADDR_WIDTH-1:0]            araddr_queue,
  input wire                                  arvalid_queue,
  output  wire                                arready_queue,
  output  wire [`AXIL_DATA_WIDTH-1:0]          rdata_queue,
  output  wire                                rvalid_queue,
  input wire                                  rready_queue

  ,output wire [31:0]                           desc_fetch_req_cnt
  ,output wire [31:0]                           desc_fetch_rsp_cnt
  ,output wire [31:0]                           desc_fetch_error_cnt

`ifdef ETH_CHIP_DEBUG
  // ,input 	  wire		[0 : 0] 		Rw_data
	// ,output 	  wire 		[0 : 0] 		Ro_data
  ,input 	  wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_sel
	,output 	wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_bus
//	,output 	wire 		[`DESC_PROVIDER_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_bus

`endif

  `ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved | reserved | idx | end | out |
     * |  255:10  |   9:5    | 4:2 |  1  |  0  |
     */
    ,output wire [255:0] debug_desc_fetch
    /* ------- Debug interface {end}------- */
  `endif
);


wire [`QUEUE_NUMBER_WIDTH-1:0]        desc_dequeue_req_qnum;
wire                                  desc_dequeue_req_valid;
wire                                  desc_dequeue_req_ready;

wire [`QUEUE_NUMBER_WIDTH-1:0]      desc_dequeue_resp_qnum;
wire [`QUEUE_INDEX_WIDTH-1:0]       desc_dequeue_resp_qindex;
wire [`DMA_ADDR_WIDTH-1:0]          desc_dequeue_resp_desc_addr;
wire [`DMA_ADDR_WIDTH-1:0]          desc_dequeue_resp_cpl_addr;
wire [`MSI_NUM_WIDTH-1:0]            desc_dequeue_resp_msi;
wire [`STATUS_WIDTH-1:0]            desc_dequeue_resp_status;
wire                               desc_dequeue_resp_valid;

`ifdef ETH_CHIP_DEBUG

wire 		[`DESC_PROVIDER_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_data;


wire 		[(`DESC_FETCH_DEG_REG_NUM)  * 32 - 1 : 0]		    Dbg_bus_desc_fetch;
wire 		[(`QUEUE_MANAGER_DEG_REG_NUM)  * 32 - 1 : 0]		Dbg_bus_queue_manger;

assign Dbg_data = {Dbg_bus_desc_fetch, Dbg_bus_queue_manger} ;

assign Dbg_bus = Dbg_data >> (Dbg_sel << 5);
//assign Dbg_bus = Dbg_data;

`endif

desc_fetch #(
  .DESC_TABLE_SIZE(DESC_TABLE_SIZE) /* number of descripor tabel */  
  ,.DEBUG_RX(DEBUG_RX)
)
desc_fetch_inst
(
  .clk(clk),
  .rst_n(rst_n),

  /* input from engine, request for a desc */
  .desc_req_qnum(desc_req_qnum),
  .desc_req_valid(desc_req_valid),
  .desc_req_ready(desc_req_ready),

  /* to engine,  return the desc data */
  .desc_rsp_status(desc_rsp_status),
  .desc_rsp_qnum(desc_rsp_qnum),
  .desc_rsp_qindex(desc_rsp_qindex),
  .desc_rsp_length(desc_rsp_length),
  .desc_rsp_dma_addr(desc_rsp_dma_addr),
  .desc_rsp_desc_addr(desc_rsp_desc_addr),
  .desc_rsp_csum_start(desc_rsp_csum_start),
  .desc_rsp_csum_offset(desc_rsp_csum_offset),
  .desc_rsp_cpl_addr(desc_rsp_cpl_addr),
  .desc_rsp_msix_msg(desc_rsp_msix_msg),
  .desc_rsp_msix_addr(desc_rsp_msix_addr),
  .desc_rsp_valid(desc_rsp_valid),
  .desc_rsp_ready(desc_rsp_ready),

  /* to queue manager, request for the queue information */
  .desc_dequeue_req_qnum(desc_dequeue_req_qnum),
  .desc_dequeue_req_valid(desc_dequeue_req_valid),
  .desc_dequeue_req_ready(desc_dequeue_req_ready),

  /* from queue manager */
  .desc_dequeue_resp_qnum(desc_dequeue_resp_qnum),
  .desc_dequeue_resp_qindex(desc_dequeue_resp_qindex),
  .desc_dequeue_resp_desc_addr(desc_dequeue_resp_desc_addr),
  .desc_dequeue_resp_cpl_addr(desc_dequeue_resp_cpl_addr),
  .desc_dequeue_resp_msi(desc_dequeue_resp_msi),
  .desc_dequeue_resp_status(desc_dequeue_resp_status),
  .desc_dequeue_resp_valid(desc_dequeue_resp_valid),

  /* to dma module, to get the desc */
  .desc_dma_req_valid(desc_dma_req_valid),
  .desc_dma_req_last(desc_dma_req_last),
  .desc_dma_req_data(desc_dma_req_data),
  .desc_dma_req_head(desc_dma_req_head),
  .desc_dma_req_ready(desc_dma_req_ready),

  /* to dma module, to get the desc */
  .desc_dma_rsp_valid(desc_dma_rsp_valid),
  .desc_dma_rsp_last(desc_dma_rsp_last),
  .desc_dma_rsp_data(desc_dma_rsp_data),
  .desc_dma_rsp_head(desc_dma_rsp_head),
  .desc_dma_rsp_ready(desc_dma_rsp_ready),

  .irq_req_msix(irq_req_msix),
  .irq_req_valid(irq_req_valid),
  .irq_req_ready(irq_req_ready),

  .irq_rsp_msg(irq_rsp_msg),
  .irq_rsp_addr(irq_rsp_addr),
  .irq_rsp_valid(irq_rsp_valid),
  .irq_rsp_ready(irq_rsp_ready)
  
  
  ,.desc_fetch_req_cnt(desc_fetch_req_cnt)
  ,.desc_fetch_rsp_cnt(desc_fetch_rsp_cnt)
  ,.desc_fetch_error_cnt(desc_fetch_error_cnt)

`ifdef ETH_CHIP_DEBUG
  // ,input 	  wire		[0 : 0] 		Rw_data
	// ,output 	  wire 		[0 : 0] 		Ro_data
	,.Dbg_bus(Dbg_bus_desc_fetch)
`endif

  `ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved | reserved | idx | end | out |
     * |  255:10  |   9:5    | 4:2 |  1  |  0  |
     */
    ,.debug(debug_desc_fetch)
    /* ------- Debug interface {end}------- */
  `endif
);


queue_manager #(
  .QUEUE_COUNT(QUEUE_COUNT),
  .DESC_TABLE_SIZE(DESC_TABLE_SIZE),

  .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH)
  ,.DEBUG_RX(DEBUG_RX)
)
queue_manager_inst
(
  .clk(clk),
  .rst_n(rst_n),

  /* from desc fetch, request for the queue information */
  .desc_dequeue_req_qnum(desc_dequeue_req_qnum),
  .desc_dequeue_req_valid(desc_dequeue_req_valid),
  .desc_dequeue_req_ready(desc_dequeue_req_ready),

  /* to  desc fetch */
  .desc_dequeue_resp_qnum(desc_dequeue_resp_qnum),
  .desc_dequeue_resp_qindex(desc_dequeue_resp_qindex),
  .desc_dequeue_resp_desc_addr(desc_dequeue_resp_desc_addr),
  .desc_dequeue_resp_cpl_addr(desc_dequeue_resp_cpl_addr),
  .desc_dequeue_resp_msi(desc_dequeue_resp_msi),
  .desc_dequeue_resp_status(desc_dequeue_resp_status),
  .desc_dequeue_resp_valid(desc_dequeue_resp_valid),
  // .desc_dequeue_resp_head_ptr(desc_dequeue_resp_head_ptr),
  // .desc_dequeue_resp_tail_ptr(desc_dequeue_resp_tail_ptr),
  // .desc_dequeue_resp_cpl_head_ptr(desc_dequeue_resp_cpl_head_ptr),
  // .desc_dequeue_resp_cpl_tail_ptr(desc_dequeue_resp_cpl_tail_ptr),

  .doorbell_queue( doorbell_queue ),
  .doorbell_valid( doorbell_valid ),

  .cpl_finish_qnum(cpl_finish_qnum),
  .cpl_finish_valid(cpl_finish_valid),
  .cpl_finish_ready(cpl_finish_ready),

  /*axil write signal*/
  .awaddr_queue(awaddr_queue),
  .awvalid_queue(awvalid_queue),
  .awready_queue(awready_queue),
  .wdata_queue(wdata_queue),
  .wstrb_queue(wstrb_queue),
  .wvalid_queue(wvalid_queue),
  .wready_queue(wready_queue),
  .bvalid_queue(bvalid_queue),
  .bready_queue(bready_queue),
  /*axil read signal*/
  .araddr_queue(araddr_queue),
  .arvalid_queue(arvalid_queue),
  .arready_queue(arready_queue),
  .rdata_queue(rdata_queue),
  .rvalid_queue(rvalid_queue),
  .rready_queue(rready_queue)

`ifdef ETH_CHIP_DEBUG
  // ,input 	  wire		[0 : 0] 		Rw_data
	// ,output 	  wire 		[0 : 0] 		Ro_data
	,.Dbg_bus(Dbg_bus_queue_manger)
`endif
);



endmodule
