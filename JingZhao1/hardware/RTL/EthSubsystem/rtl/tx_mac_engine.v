`timescale 1ns / 100ps
//*************************************************************************
// > File Name: tx_engine.v
// > Author   : Li jianxiong
// > Date     : 2021-11-02
// > Note     : tx_engine  is used to send the tx frame to mac
//              it request the desc from the desc_provider, 
//              and send the frame to mac
// > V1.1 - 2021-11-02 : 
//*************************************************************************

module tx_mac_engine #(
  parameter AXIL_ADDR_WIDTH = 12,
  parameter DESC_TABLE_SIZE = 128
)(
  input wire clk,
  input wire rst_n,
    /*interface to mac tx  */
  output  wire                                  axis_tx_valid,
  output  wire                                  axis_tx_last,
  output  wire [`DMA_DATA_WIDTH-1:0]            axis_tx_data,
  output  wire [`DMA_KEEP_WIDTH-1:0]            axis_tx_data_be,
  input   wire                                  axis_tx_ready,
  output wire  [`XBAR_USER_WIDTH-1:0]           axis_tx_user,
  output wire                                   axis_tx_start,

  input wire  [`QUEUE_NUMBER_WIDTH-1:0]         tx_doorbell_queue,
  input wire                                    tx_doorbell_valid,

  /* input from tx_engine, request for a desc */
  output  wire [`QUEUE_NUMBER_WIDTH-1:0]        tx_desc_req_qnum,
  output  wire                                  tx_desc_req_valid,
  input   wire                                  tx_desc_req_ready,

  /* to tx_engine,  return the desc data */
  input   wire [`STATUS_WIDTH-1:0]            tx_desc_status,
  input   wire [`QUEUE_NUMBER_WIDTH-1:0]      tx_desc_qnum,
  input   wire [`QUEUE_INDEX_WIDTH-1:0]       tx_desc_qindex,
  input   wire [`ETH_LEN_WIDTH-1:0]           tx_desc_length,
  input   wire [`DMA_ADDR_WIDTH-1:0]          tx_desc_dma_addr,
  input   wire [`DMA_ADDR_WIDTH-1:0]          tx_desc_desc_addr,
  input   wire [`CSUM_START_WIDTH-1:0]        tx_desc_csum_start,
  input   wire [`CSUM_START_WIDTH-1:0]        tx_desc_csum_offset,
  input   wire [`DMA_ADDR_WIDTH-1:0]          tx_desc_cpl_addr,
  input   wire [`IRQ_MSG-1:0]                 tx_desc_msix_msg,
  input   wire [`DMA_ADDR_WIDTH-1:0]          tx_desc_msix_addr,
  input   wire                                tx_desc_valid,
  output  wire                                tx_desc_ready,

  /* to dma module, to get the frame */
  output wire                                 tx_frame_req_valid,
  output wire                                 tx_frame_req_last,
  output wire [`DMA_DATA_WIDTH-1:0]           tx_frame_req_data,
  output wire [`DMA_HEAD_WIDTH-1:0]           tx_frame_req_head,
  input  wire                                 tx_frame_req_ready,

  /* interface to dma */
  input   wire                                tx_frame_rsp_valid,
  input   wire                                tx_frame_rsp_last,
  input   wire [`DMA_DATA_WIDTH-1:0]          tx_frame_rsp_data,
  input   wire [`DMA_HEAD_WIDTH-1:0]          tx_frame_rsp_head,
  output  wire                                tx_frame_rsp_ready,

  /* completion data dma interface */
  output wire                                 tx_axis_wr_valid,
  output wire [`DMA_DATA_WIDTH-1:0]           tx_axis_wr_data,
  output wire [`DMA_HEAD_WIDTH-1:0]           tx_axis_wr_head,
  output wire                                 tx_axis_wr_last,
  input  wire                                 tx_axis_wr_ready,

  /* output to queue manager , finish cpl */
  output  wire [`QUEUE_NUMBER_WIDTH-1:0]      tx_cpl_finish_qnum,
  output  wire                                tx_cpl_finish_valid,
  input   wire                                tx_cpl_finish_ready

  , input  wire                                   start_sche
  , input  wire                                   msix_enable

  , input  wire [AXIL_ADDR_WIDTH-1:0]             awaddr_queue
  , input  wire                                   awvalid_queue
  , input  wire                                   awready_queue
  , input  wire [`AXIL_DATA_WIDTH-1:0]            wdata_queue
  , input  wire                                   wvalid_queue
  , input  wire                                   wready_queue

  ,output wire [31:0]                           tx_mac_proc_rec_cnt
  ,output wire [31:0]                           tx_mac_proc_xmit_cnt
  ,output wire [31:0]                           tx_mac_proc_cpl_cnt
  ,output wire [31:0]                           tx_mac_proc_msix_cnt

`ifdef ETH_CHIP_DEBUG
  ,input 	  wire		[`RW_DATA_NUM_TX_MACENGINE * 32 - 1 : 0] 		rw_data
	// ,output 	  wire 		[0 : 0] 		Ro_data
  ,input 	  wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_sel
	,output 	wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_bus
	//,output 	wire 		[`TX_MAC_ENGINE_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_bus
`endif

  `ifdef SIMULATION
  /* ------- Debug interface {begin}------- */
  /* | reserved | reserved | idx | end | out |
    * |  255:10  |   9:5    | 4:2 |  1  |  0  |
    */
  ,output wire [255:0] debug_tx_dma
  ,output wire [255:0] debug_tx_macproc
  /* ------- Debug interface {end}------- */
  `endif
);

wire                                  tx_axis_irq_valid;
wire [`DMA_DATA_WIDTH-1:0]            tx_axis_irq_data;
wire [`DMA_HEAD_WIDTH-1:0]            tx_axis_irq_head;
wire                                  tx_axis_irq_last;
wire                                  tx_axis_irq_ready;

  /* completion data dma interface */
wire                                tx_axis_cpl_wr_valid;
wire [`DMA_DATA_WIDTH-1:0]          tx_axis_cpl_wr_data;
wire [`DMA_HEAD_WIDTH-1:0]          tx_axis_cpl_wr_head;
wire                                tx_axis_cpl_wr_last;
wire                                tx_axis_cpl_wr_ready;


`ifdef ETH_CHIP_DEBUG
wire 		[`TX_MAC_ENGINE_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_data;


wire 		[`TX_SCHD_RR_DEG_REG_NUM  * 32 - 1 : 0]		          Dbg_bus_tx_scheduler_rr;
wire 		[`TX_MACPROC_DEG_REG_NUM  * 32 - 1 : 0]		          Dbg_bus_tx_macproc;

assign Dbg_data = {Dbg_bus_tx_scheduler_rr, Dbg_bus_tx_macproc} ;


assign Dbg_bus = Dbg_data >> (Dbg_sel << 5);
//assign Dbg_bus = Dbg_data;

`endif


tx_macproc #(
  .DESC_TABLE_SIZE(DESC_TABLE_SIZE)
) 
tx_macproc_inst
(
  .clk(clk),
  .rst_n(rst_n),

  /* from fx_frameproc,  get the the dma addr, dma the frame 
      after finish the dma, ready set 1*/
  .tx_desc_qnum(tx_desc_qnum),
  .tx_desc_qindex(tx_desc_qindex),
  .tx_desc_frame_len(tx_desc_length),
  .tx_desc_dma_addr(tx_desc_dma_addr),
  .tx_desc_desc_addr(tx_desc_desc_addr),
  .tx_desc_csum_start(tx_desc_csum_start),
  .tx_desc_csum_offset(tx_desc_csum_offset),
  .tx_desc_cpl_addr(tx_desc_cpl_addr),
  .tx_desc_msix_msg(tx_desc_msix_msg),
  .tx_desc_msix_addr(tx_desc_msix_addr),    
  .tx_desc_valid(tx_desc_valid),
  .tx_desc_ready(tx_desc_ready),

  /* to dma module, to get the desc */
  .tx_frame_req_valid(tx_frame_req_valid),
  .tx_frame_req_last(tx_frame_req_last),
  .tx_frame_req_data(tx_frame_req_data),
  .tx_frame_req_head(tx_frame_req_head),
  .tx_frame_req_ready(tx_frame_req_ready),

  /* interface to dma */
  .tx_frame_rsp_valid(tx_frame_rsp_valid),
  .tx_frame_rsp_data(tx_frame_rsp_data),
  .tx_frame_rsp_head(tx_frame_rsp_head),
  .tx_frame_rsp_last(tx_frame_rsp_last),
  .tx_frame_rsp_ready(tx_frame_rsp_ready),

  /* interface to mac */
  .axis_tx_valid(axis_tx_valid),
  .axis_tx_last(axis_tx_last),
  .axis_tx_data(axis_tx_data),
  .axis_tx_data_be(axis_tx_data_be),
  .axis_tx_ready(axis_tx_ready),
  .axis_tx_user(axis_tx_user),
  .axis_tx_start(axis_tx_start),

  // .payload_len(payload_len),
  
  /* completion data dma interface */
  .tx_axis_cpl_wr_valid(tx_axis_cpl_wr_valid),
  .tx_axis_cpl_wr_data(tx_axis_cpl_wr_data),
  .tx_axis_cpl_wr_head(tx_axis_cpl_wr_head),
  .tx_axis_cpl_wr_last(tx_axis_cpl_wr_last),
  .tx_axis_cpl_wr_ready(tx_axis_cpl_wr_ready),

  .tx_axis_irq_valid(tx_axis_irq_valid),
  .tx_axis_irq_data(tx_axis_irq_data),
  .tx_axis_irq_head(tx_axis_irq_head),
  .tx_axis_irq_last(tx_axis_irq_last),
  .tx_axis_irq_ready(tx_axis_irq_ready),

  .tx_cpl_finish_qnum(tx_cpl_finish_qnum),
  .tx_cpl_finish_valid(tx_cpl_finish_valid),
  .tx_cpl_finish_ready(tx_cpl_finish_ready)

  ,.tx_mac_proc_rec_cnt(tx_mac_proc_rec_cnt)
  ,.tx_mac_proc_xmit_cnt(tx_mac_proc_xmit_cnt)
  ,.tx_mac_proc_cpl_cnt(tx_mac_proc_cpl_cnt)
  ,.tx_mac_proc_msix_cnt(tx_mac_proc_msix_cnt)

  ,.msix_enable(msix_enable)

`ifdef ETH_CHIP_DEBUG
	// ,output 	  wire 		[0 : 0] 		Ro_data
  ,.rw_data(rw_data[2 * 32 - 1 : 0])
	,.Dbg_bus(Dbg_bus_tx_macproc)
`endif
 
  `ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved | reserved | idx | end | out |
     * |  255:10  |   9:5    | 4:2 |  1  |  0  |
     */
    ,.debug(debug_tx_macproc)
    /* ------- Debug interface {end}------- */
  `endif
);

eth_req_arbiter #(
    .C_DATA_WIDTH(`DMA_DATA_WIDTH),
    .AXIS_TUSER_WIDTH(`DMA_HEAD_WIDTH),
    .CHANNEL_NUM(2),    // number of slave signals to arbit
    .CHNL_NUM_LOG(1),
    .KEEP_WIDTH(`DMA_KEEP_WIDTH)
) 
tx_axis_arbiter( 
    .rdma_clk(clk),
    .rst_n(rst_n),

    /* -------Slave AXIS Interface{begin}------- */
    .s_axis_req_tvalid ( { tx_axis_cpl_wr_valid,  tx_axis_irq_valid } ),
    .s_axis_req_tdata  ( { tx_axis_cpl_wr_data,   tx_axis_irq_data } ),
    .s_axis_req_tuser  ( { tx_axis_cpl_wr_head,   tx_axis_irq_head } ),
    .s_axis_req_tlast  ( { tx_axis_cpl_wr_last,   tx_axis_irq_last } ),
    .s_axis_req_tkeep  ( {(2 * `DMA_KEEP_WIDTH){1'b0}}                     ),
    .s_axis_req_tready ( { tx_axis_cpl_wr_ready,  tx_axis_irq_ready } ),
    /* -------Slave AXIS Interface{end}------- */

    /* ------- Master AXIS Interface{begin} ------- */
    .m_axis_req_tvalid (   tx_axis_wr_valid  ),
    .m_axis_req_tdata  (   tx_axis_wr_data ), 
    .m_axis_req_tuser  (   tx_axis_wr_head ), 
    .m_axis_req_tlast  (   tx_axis_wr_last ),    
    .m_axis_req_tkeep  (             	   ),	
    .m_axis_req_tready (   tx_axis_wr_ready ) 
    /* ------- Master AXIS Interface{end} ------- */

`ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved | reserved | idx | end | out |
     * |  255:10  |   9:5    | 4:2 |  1  |  0  |
     */
    ,.debug(debug_tx_dma)
    /* ------- Debug interface {end}------- */
`endif
);



tx_scheduler_rr tx_scheduler_inst(
  .clk(clk),
  .rst_n(rst_n),

  .start_sche(start_sche),

  .awaddr_queue(awaddr_queue),
  .awvalid_queue(awvalid_queue),
  .awready_queue(awready_queue),
  .wdata_queue(wdata_queue),
  .wvalid_queue(wvalid_queue),
  .wready_queue(wready_queue),

  .desc_req_qnum(tx_desc_req_qnum),
  .desc_req_valid(tx_desc_req_valid),
  .desc_req_ready(tx_desc_req_ready)

`ifdef ETH_CHIP_DEBUG
  // ,input 	  wire		[0 : 0] 		Rw_data
	// ,output 	  wire 		[0 : 0] 		Ro_data
  ,.rw_data(rw_data[2*32 +: 32])
	,.Dbg_bus(Dbg_bus_tx_scheduler_rr)
`endif
);
    
endmodule
