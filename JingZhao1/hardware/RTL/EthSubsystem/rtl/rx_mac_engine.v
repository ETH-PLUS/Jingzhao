`timescale 1ns / 100ps
//*************************************************************************
// > File Name: rx_engine.v
// > Author   : Li jianxiong
// > Date     : 2021-11-02
// > Note     : rx_engine  is used to receive the rx frame for mac
//              it request the desc from the desc_provider, 
//              and send the frame to corresponding mem
// > V1.1 - 2021-11-02 : 
//*************************************************************************

module rx_mac_engine #(
  parameter QUEUE_COUNT = 32,
  parameter DESC_TABLE_SIZE = 128,
  /* hash and csum parameter */
  parameter RX_CHECKSUM_ENABLE = 1,
  parameter RX_VLAN_ENABLE = 1
) 
(
  input   wire                              clk,
  input   wire                              rst_n,

  /*interface to mac rx  */
  input wire                                  axis_rx_valid, 
  input wire                                  axis_rx_last,
  input wire [`DMA_DATA_WIDTH-1:0]            axis_rx_data,
  input wire [`DMA_KEEP_WIDTH-1:0]            axis_rx_data_be,
  output wire                                 axis_rx_ready,


  /* output to desc fetch , request for a desc */
  output  wire [`QUEUE_NUMBER_WIDTH-1:0]      rx_desc_req_qnum,
  output  wire                                rx_desc_req_valid,
  input   wire                                rx_desc_req_ready,

    /* from desc, get the desc data */
  input   wire [`STATUS_WIDTH-1:0]            rx_desc_rsp_status,
  input   wire [`QUEUE_NUMBER_WIDTH-1:0]      rx_desc_rsp_qnum,
  input   wire [`QUEUE_INDEX_WIDTH-1:0]       rx_desc_rsp_qindex,
  input   wire [`ETH_LEN_WIDTH-1:0]           rx_desc_rsp_length,
  input   wire [`DMA_ADDR_WIDTH-1:0]          rx_desc_rsp_dma_addr,
  input   wire [`DMA_ADDR_WIDTH-1:0]          rx_desc_rsp_cpl_addr,
  input   wire [`IRQ_MSG-1:0]                 rx_desc_rsp_msix_msg,
  input   wire [`DMA_ADDR_WIDTH-1:0]          rx_desc_rsp_msix_addr,
  input   wire                                rx_desc_rsp_valid,
  output  wire                                rx_desc_rsp_ready,
  input   wire [`QUEUE_INDEX_WIDTH-1:0]       rx_desc_rsp_head_ptr,
  input   wire [`QUEUE_INDEX_WIDTH-1:0]       rx_desc_rsp_tail_ptr,
  input   wire [`QUEUE_INDEX_WIDTH-1:0]       rx_desc_rsp_cpl_head_ptr,
  input   wire [`QUEUE_INDEX_WIDTH-1:0]       rx_desc_rsp_cpl_tail_ptr,

  /* output to queue manager , finish cpl */
  output  wire [`QUEUE_NUMBER_WIDTH-1:0]      rx_cpl_finish_qnum,
  output  wire                                rx_cpl_finish_valid,
  input   wire                                rx_cpl_finish_ready,

  /* -------to dma module , to write the frame and cpl{begin}------- */
  output wire                                 rx_axis_wr_valid,
  output wire [`DMA_DATA_WIDTH-1:0]           rx_axis_wr_data,
  output wire [`DMA_HEAD_WIDTH-1:0]           rx_axis_wr_head,
  output wire                                 rx_axis_wr_last,
  input  wire                                 rx_axis_wr_ready

  , input  wire                                   start_sche
  , input  wire                                   msix_enable



  ,output wire [31:0]                           mac_fifo_rev_cnt
  ,output wire [31:0]                           mac_fifo_send_cnt
  ,output wire [31:0]                           mac_fifo_error_cnt

  ,output wire [31:0]                           rx_mac_proc_rec_cnt
  ,output wire [31:0]                           rx_mac_proc_desc_cnt
  ,output wire [31:0]                           rx_mac_proc_cpl_cnt
  ,output wire [31:0]                           rx_mac_proc_msix_cnt
  ,output wire [31:0]                           rx_mac_proc_error_cnt

`ifdef ETH_CHIP_DEBUG
  ,input 	wire 	[`RW_DATA_NUM_RX_MACENGINE * 32 - 1 : 0]	rw_data
	// ,output 	wire 		[0 : 0] 		Ro_data
  ,input 	  wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_sel
	,output 	wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_bus
	//,output 	wire 		[`RX_MAC_ENGINE_DEG_REG_NUM * 32 - 1 : 0] Dbg_bus
`endif

`ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved | reserved | idx | end | out |
     * |  255:10  |   9:5    | 4:2 |  1  |  0  |
     */
    ,output wire [255:0] debug_rx_dma
    ,output wire [255:0] debug_rx_csum
    /* ------- Debug interface {end}------- */
`endif
);

/* from hash, indicate that a frame is coming */
wire [`HASH_WIDTH-1:0]              rx_hash_fifo;
wire [`HASH_TYPE_WIDTH-1:0]         rx_hash_type_fifo;
wire                                rx_hash_fifo_empty;
wire                                rx_hash_fifo_rd;

/* from the mac fifo, indicate the frame receive status */
wire                                rx_frame_fifo_empty;
wire [`ETH_LEN_WIDTH-1:0]           rx_frame_fifo_len_fifo;
wire [`STATUS_WIDTH-1:0]            rx_frame_fifo_status_fifo;
wire                                rx_frame_fifo_rd;

/*
* Receive checksum input
*/
wire [`CSUM_WIDTH-1:0]              rx_csum_data_fifo;
wire [`STATUS_WIDTH-1:0]            rx_csum_status_fifo;
wire                                rx_csum_empty;
wire                                rx_csum_fifo_rd;


wire [`VLAN_TAG_WIDTH-1:0]          rx_vlan_tci_fifo;
wire [`STATUS_WIDTH-1:0]            rx_vlan_status_fifo;
wire                                rx_vlan_empty;
wire                                rx_vlan_fifo_rd;

/* mac fifo indicate a frame coming */
wire                                rx_frame_fifo_valid;
wire [`ETH_LEN_WIDTH-1:0]           rx_frame_fifo_len;
wire [`STATUS_WIDTH-1:0]            rx_frame_fifo_status;


/* rx_frameproc to mac_fifo, when get the the desc, output the dma adder to frame */
wire [`DMA_ADDR_WIDTH-1:0]          rx_frame_dma_req_addr;
wire [`STATUS_WIDTH-1:0]            rx_frame_dma_req_status;
wire [`ETH_LEN_WIDTH-1:0]           rx_frame_dma_req_len;
wire                                rx_frame_dma_req_valid;
wire                                rx_frame_dma_req_ready;

wire [`HASH_WIDTH-1:0]            crx_hash;
wire [`HASH_TYPE_WIDTH-1:0]       crx_hash_type;
wire                              crx_hash_valid;

wire [`CSUM_WIDTH-1:0]              csum_data;
wire [`STATUS_WIDTH-1:0]            csum_status;
wire                                csum_valid;

wire                                rx_frame_dma_finish_valid;
wire [`STATUS_WIDTH-1:0]            rx_frame_dma_finish_status;

wire                                rx_axis_frame_wr_valid;
wire [`DMA_DATA_WIDTH-1:0]          rx_axis_frame_wr_data;
wire [`DMA_HEAD_WIDTH-1:0]          rx_axis_frame_wr_head;
wire                                rx_axis_frame_wr_last;
wire                                rx_axis_frame_wr_ready;

wire                               rx_axis_cpl_wr_valid;
wire [`DMA_DATA_WIDTH-1:0]          rx_axis_cpl_wr_data;
wire [`DMA_HEAD_WIDTH-1:0]          rx_axis_cpl_wr_head;
wire                               rx_axis_cpl_wr_last;
wire                               rx_axis_cpl_wr_ready;

wire                               rx_axis_irq_valid;
wire [`DMA_DATA_WIDTH-1:0]          rx_axis_irq_data;
wire [`DMA_HEAD_WIDTH-1:0]          rx_axis_irq_head;
wire                               rx_axis_irq_last;
wire                               rx_axis_irq_ready;


wire                                  axis_rx_vlan_valid;
wire                                  axis_rx_vlan_last;
wire [`DMA_DATA_WIDTH-1:0]            axis_rx_vlan_data;
wire [`DMA_KEEP_WIDTH-1:0]            axis_rx_vlan_data_be;
wire                                  axis_rx_vlan_ready;

wire [`VLAN_TAG_WIDTH-1:0]            rx_vlan_tci;
wire                                  rx_vlan_valid;
wire [`STATUS_WIDTH-1:0]              rx_vlan_status;

`ifdef ETH_CHIP_DEBUG

assign Dbg_data_rx_mac_engine = {
  12'b0, rx_hash_fifo, rx_hash_type_fifo, rx_hash_fifo_empty, rx_hash_fifo_rd, rx_frame_fifo_empty, 
  rx_frame_fifo_len_fifo, rx_frame_fifo_status_fifo, rx_frame_fifo_rd, rx_csum_data_fifo, rx_csum_status_fifo, rx_csum_empty, 
  rx_csum_fifo_rd, rx_vlan_tci_fifo, rx_vlan_status_fifo, rx_vlan_empty, rx_vlan_fifo_rd
};

wire 		[`DBG_DATA_WIDTH-1 : 0]     Dbg_bus_mac_fifo;
wire 		[`DBG_DATA_WIDTH-1 : 0]     Dbg_bus_rx_macproc;
wire 		[`DBG_DATA_WIDTH-1 : 0]     Dbg_bus_rx_hash;
wire 		[`DBG_DATA_WIDTH-1 : 0]     Dbg_bus_rx_checksum;
wire 		[`DBG_DATA_WIDTH-1 : 0]		  Dbg_bus_rx_mac_engine;
wire 		[`DBG_DATA_WIDTH-1 : 0]     Dbg_bus_rx_vlan;

//wire 		[`MAC_FIFO_DEG_REG_NUM  * 32 - 1 : 0]     Dbg_bus_mac_fifo;
//wire 		[`RX_MACPROC_DEG_REG_NUM  * 32 - 1 : 0]     Dbg_bus_rx_macproc;
//wire 		[`RX_HASH_DEG_REG_NUM  * 32 - 1 : 0]     Dbg_bus_rx_hash;
//wire 		[`RX_CHECKSUM_DEG_REG_NUM  * 32 - 1 : 0]     Dbg_bus_rx_checksum;
//wire 		[`DBG_DATA_WIDTH-1 : 0]		  Dbg_bus_rx_mac_engine;
//wire 		[`RX_VLAN_DEG_REG_NUM  * 32 - 1 : 0]     Dbg_bus_rx_vlan;

wire 		[`DBG_DATA_WIDTH-1 : 0]     Dbg_sel_rx_macproc;
wire 		[`DBG_DATA_WIDTH-1 : 0]     Dbg_sel_mac_fifo;
wire 		[`DBG_DATA_WIDTH-1 : 0]     Dbg_sel_rx_hash;
wire 		[`DBG_DATA_WIDTH-1 : 0]     Dbg_sel_rx_checksum;
wire 		[`DBG_DATA_WIDTH-1 : 0]		  Dbg_sel_rx_mac_engine;
wire 		[`DBG_DATA_WIDTH-1 : 0]     Dbg_sel_rx_vlan;

assign Dbg_sel_mac_fifo           = Dbg_sel > `MAC_FIFO_DEG_REG_OFFSET              ? Dbg_sel - `MAC_FIFO_DEG_REG_OFFSET : 'b0;
assign Dbg_sel_rx_macproc         = Dbg_sel > `RX_MACPROC_DEG_REG_OFFSET            ? Dbg_sel - `RX_MACPROC_DEG_REG_OFFSET : 'b0;
assign Dbg_sel_rx_hash            = Dbg_sel > `RX_HASH_DEG_REG_OFFSET               ? Dbg_sel - `RX_HASH_DEG_REG_OFFSET : 'b0;
assign Dbg_sel_rx_checksum        = Dbg_sel > `RX_CHECKSUM_DEG_REG_OFFSET           ? Dbg_sel - `RX_CHECKSUM_DEG_REG_OFFSET : 'b0;
assign Dbg_sel_rx_mac_engine      = Dbg_sel > `RX_MAC_ENGINE_SELF_DEG_REG_OFFSET    ? Dbg_sel - `RX_MAC_ENGINE_SELF_DEG_REG_OFFSET : 'b0;
assign Dbg_sel_rx_vlan            = Dbg_sel > `RX_VLAN_DEG_REG_OFFSET               ? Dbg_sel - `RX_VLAN_DEG_REG_OFFSET : 'b0;

assign Dbg_bus_rx_mac_engine = Dbg_data_rx_mac_engine >> (Dbg_sel_rx_mac_engine << 5);
//assign Dbg_bus_rx_mac_engine = Dbg_data_rx_mac_engine;


assign Dbg_bus     = (Dbg_sel >= `MAC_FIFO_DEG_REG_OFFSET                && Dbg_sel < `RX_MACPROC_DEG_REG_OFFSET)          ? Dbg_bus_mac_fifo :
                    (Dbg_sel >= `RX_MACPROC_DEG_REG_OFFSET              && Dbg_sel < `RX_HASH_DEG_REG_OFFSET)             ? Dbg_bus_rx_macproc :
                    (Dbg_sel >= `RX_HASH_DEG_REG_OFFSET                 && Dbg_sel < `RX_CHECKSUM_DEG_REG_OFFSET)         ? Dbg_bus_rx_hash :
                    (Dbg_sel >= `RX_CHECKSUM_DEG_REG_OFFSET             && Dbg_sel < `RX_MAC_ENGINE_SELF_DEG_REG_OFFSET)  ? Dbg_bus_rx_checksum :
                    (Dbg_sel >= `RX_MAC_ENGINE_SELF_DEG_REG_OFFSET      && Dbg_sel < `RX_VLAN_DEG_REG_OFFSET)             ? Dbg_bus_rx_mac_engine :
                    (Dbg_sel >= `RX_VLAN_DEG_REG_OFFSET)  ?    Dbg_bus_rx_vlan : 'b0;      
//assign Dbg_bus     = {
//						Dbg_bus_mac_fifo,
//						Dbg_bus_rx_macproc,
//						Dbg_bus_rx_hash,
//						Dbg_bus_rx_checksum,
//						Dbg_bus_rx_mac_engine,
//						Dbg_bus_rx_vlan
//};
`endif

rx_macproc #(
  .QUEUE_COUNT(QUEUE_COUNT),

  .DESC_TABLE_SIZE(DESC_TABLE_SIZE)
) 
rx_macproc_inst 
(
  .clk(clk),
  .rst_n(rst_n),

  /* from hash, indicate that a frame is coming */
  .rx_hash_fifo(rx_hash_fifo), 
  // .rx_hash_type_fifo(rx_hash_type_fifo),
  .rx_hash_fifo_empty(rx_hash_fifo_empty),
  .rx_hash_fifo_rd(rx_hash_fifo_rd),

  /* from the mac fifo, indicate the frame receive status */
  .rx_frame_fifo_empty(rx_frame_fifo_empty),
  .rx_frame_fifo_len_fifo(rx_frame_fifo_len_fifo),
  .rx_frame_fifo_status_fifo(rx_frame_fifo_status_fifo),
  .rx_frame_fifo_rd(rx_frame_fifo_rd),

  .msix_enable(msix_enable),

  /*
  * Receive checksum input
  */
  .rx_csum_data(rx_csum_data_fifo),
  .rx_csum_status(rx_csum_status_fifo),
  .rx_csum_empty(rx_csum_empty),
  .rx_csum_fifo_rd(rx_csum_fifo_rd),

  .rx_vlan_tci(rx_vlan_tci_fifo),
  .rx_vlan_status(rx_vlan_status_fifo),
  .rx_vlan_empty(rx_vlan_empty),
  .rx_vlan_fifo_rd(rx_vlan_fifo_rd),

  /* output to desc fetch , request for a desc */
  .rx_desc_req_qnum(rx_desc_req_qnum),
  .rx_desc_req_valid(rx_desc_req_valid),
  .rx_desc_req_ready(rx_desc_req_ready),

  /* from desc, get the desc data */
  .rx_desc_rsp_status(rx_desc_rsp_status),
  .rx_desc_rsp_qnum(rx_desc_rsp_qnum),
  .rx_desc_rsp_qindex(rx_desc_rsp_qindex),
  .rx_desc_rsp_length(rx_desc_rsp_length),
  .rx_desc_rsp_dma_addr(rx_desc_rsp_dma_addr),
  .rx_desc_rsp_cpl_addr(rx_desc_rsp_cpl_addr),
  .rx_desc_rsp_msix_msg(rx_desc_rsp_msix_msg),
  .rx_desc_rsp_msix_addr(rx_desc_rsp_msix_addr), 
  .rx_desc_rsp_valid(rx_desc_rsp_valid),
  .rx_desc_rsp_ready(rx_desc_rsp_ready),
  .rx_desc_rsp_head_ptr(rx_desc_rsp_head_ptr),
  .rx_desc_rsp_tail_ptr(rx_desc_rsp_tail_ptr),
  .rx_desc_rsp_cpl_head_ptr(rx_desc_rsp_cpl_head_ptr),
  .rx_desc_rsp_cpl_tail_ptr(rx_desc_rsp_cpl_tail_ptr),

  /* to frame dma, when get the the desc, output the dma adder to frame */
  .rx_frame_dma_req_addr(rx_frame_dma_req_addr),
  .rx_frame_dma_req_status(rx_frame_dma_req_status),
  .rx_frame_dma_req_len(rx_frame_dma_req_len),
  .rx_frame_dma_req_valid(rx_frame_dma_req_valid),
  .rx_frame_dma_req_ready(rx_frame_dma_req_ready),

  .rx_frame_dma_finish_valid(rx_frame_dma_finish_valid),
  .rx_frame_dma_finish_status(rx_frame_dma_finish_status),

  .rx_axis_cpl_wr_valid(rx_axis_cpl_wr_valid),
  .rx_axis_cpl_wr_data(rx_axis_cpl_wr_data),
  .rx_axis_cpl_wr_head(rx_axis_cpl_wr_head),
  .rx_axis_cpl_wr_last(rx_axis_cpl_wr_last),
  .rx_axis_cpl_wr_ready(rx_axis_cpl_wr_ready),

  .rx_axis_irq_valid(rx_axis_irq_valid),
  .rx_axis_irq_data(rx_axis_irq_data),
  .rx_axis_irq_head(rx_axis_irq_head),
  .rx_axis_irq_last(rx_axis_irq_last),
  .rx_axis_irq_ready(rx_axis_irq_ready),

  .rx_cpl_finish_qnum(rx_cpl_finish_qnum),
  .rx_cpl_finish_valid(rx_cpl_finish_valid),
  .rx_cpl_finish_ready(rx_cpl_finish_ready)

  ,.rx_mac_proc_rec_cnt(rx_mac_proc_rec_cnt)
  ,.rx_mac_proc_desc_cnt(rx_mac_proc_desc_cnt)
  ,.rx_mac_proc_cpl_cnt(rx_mac_proc_cpl_cnt)
  ,.rx_mac_proc_msix_cnt(rx_mac_proc_msix_cnt)
  ,.rx_mac_proc_error_cnt(rx_mac_proc_error_cnt)

`ifdef ETH_CHIP_DEBUG
	,.Dbg_bus(Dbg_bus_rx_macproc)
	,.Dbg_sel(Dbg_sel_rx_macproc)
`endif

);


mac_fifo 
mac_fifo_inst 
(
  .clk(clk),
  .rst_n(rst_n),

  /*interface to mac rx  */
  .axis_rx_valid(axis_rx_vlan_valid),
  .axis_rx_last(axis_rx_vlan_last),
  .axis_rx_data(axis_rx_vlan_data),
  .axis_rx_data_be(axis_rx_vlan_data_be),
  .axis_rx_ready(axis_rx_vlan_ready),

  /* interface to dma */
  .rx_axis_frame_wr_valid(rx_axis_frame_wr_valid),
  .rx_axis_frame_wr_data(rx_axis_frame_wr_data),
  .rx_axis_frame_wr_head(rx_axis_frame_wr_head),
  .rx_axis_frame_wr_last(rx_axis_frame_wr_last),
  .rx_axis_frame_wr_ready(rx_axis_frame_wr_ready),

  /* interface to rx_frameproc, when receive a new frame, transmit status to the  */
  .rx_frame_fifo_valid(rx_frame_fifo_valid),
  .rx_frame_fifo_len(rx_frame_fifo_len),
  .rx_frame_fifo_status(rx_frame_fifo_status),

  /* from fx_frameproc,  get the the dma addr, dma the frame */
  .rx_frame_dma_req_addr(rx_frame_dma_req_addr),
  .rx_frame_dma_req_status(rx_frame_dma_req_status),
  .rx_frame_dma_req_len(rx_frame_dma_req_len),
  .rx_frame_dma_req_valid(rx_frame_dma_req_valid),
  .rx_frame_dma_req_ready(rx_frame_dma_req_ready),

  .rx_frame_dma_finish_valid(rx_frame_dma_finish_valid),
  .rx_frame_dma_finish_status(rx_frame_dma_finish_status)

  ,.mac_fifo_rev_cnt(mac_fifo_rev_cnt)
  ,.mac_fifo_send_cnt(mac_fifo_send_cnt)
  ,.mac_fifo_error_cnt(mac_fifo_error_cnt)

`ifdef ETH_CHIP_DEBUG
  ,.rw_data(rw_data[32 - 1 : 0])
	,.Dbg_sel(Dbg_sel_mac_fifo)
	,.Dbg_bus(Dbg_bus_mac_fifo)
`endif
);

wire mac_status_fifo_full;

eth_sync_fifo_2psram  
#( .DATA_WIDTH(`STATUS_WIDTH + `ETH_LEN_WIDTH), //
   .FIFO_DEPTH(`RX_PKT_ELEMENT_DEPTH)
) sync_fifo_2psram_mac_fifo_inst (
	.clk  (clk  ),
	.rst_n(rst_n),
	.wr_en(rx_frame_fifo_valid),
	.din  ({rx_frame_fifo_len, rx_frame_fifo_status}),
	.full ( ),
	.progfull (mac_status_fifo_full ),
	.rd_en(rx_frame_fifo_rd),
	.dout ({rx_frame_fifo_len_fifo, rx_frame_fifo_status_fifo} ),
	.empty(rx_frame_fifo_empty),
  .empty_entry_num(),
  .count()
`ifdef ETH_CHIP_DEBUG
  ,.rw_data(rw_data[1*32 +: 32])
`endif
);
  


rx_hash
rx_hash_inst
(
  .clk(clk),
  .rst_n(rst_n),

  /*interface to mac rx  */
  .axis_rx_valid(axis_rx_vlan_valid && axis_rx_vlan_ready), 
  .axis_rx_last(axis_rx_vlan_last),
  .axis_rx_data(axis_rx_vlan_data),
  .axis_rx_data_be(axis_rx_vlan_data_be),

  

  .hash_key(320'h6d5a56da255b0ec24167253d43a38fb0d0ca2bcbae7b30b477cb2da38030f20c6a42b73bbeac01fa),

  /*otuput to rx_engine, hash is used for choose the queue*/
  .crx_hash(crx_hash),
  // .crx_hash_type(crx_hash_type),
  .crx_hash_valid(crx_hash_valid)

`ifdef ETH_CHIP_DEBUG
	,.Dbg_sel(Dbg_sel_rx_hash)
	,.Dbg_bus(Dbg_bus_rx_hash)
`endif
);

wire hash_fifo_full;

eth_sync_fifo_2psram  
#( .DATA_WIDTH(`HASH_WIDTH), //hash_value and hash_type
   .FIFO_DEPTH(`RX_PKT_ELEMENT_DEPTH)
) sync_fifo_2psram_rx_hash_inst (
	.clk  (clk  ),
	.rst_n(rst_n),
	.wr_en(crx_hash_valid),
	.din  (crx_hash ),
	.full ( ),
	.progfull (hash_fifo_full ),
	.rd_en(rx_hash_fifo_rd),
	.dout (rx_hash_fifo),
	.empty(rx_hash_fifo_empty),
  .empty_entry_num(),
  .count()
`ifdef ETH_CHIP_DEBUG
  ,.rw_data(rw_data[2*32 +: 32])
`endif
);



eth_req_arbiter #(
    .C_DATA_WIDTH(`DMA_DATA_WIDTH),
    .AXIS_TUSER_WIDTH(`DMA_HEAD_WIDTH),
    .CHANNEL_NUM(3),    // number of slave signals to arbit
    .CHNL_NUM_LOG(2),
    .KEEP_WIDTH(`DMA_KEEP_WIDTH)
) 
rx_axis_arbiter( 
    .rdma_clk(clk),
    .rst_n(rst_n),

    /* -------Slave AXIS Interface{begin}------- */
    .s_axis_req_tvalid ( { rx_axis_frame_wr_valid,   rx_axis_cpl_wr_valid, rx_axis_irq_valid } ),
    .s_axis_req_tdata  ( { rx_axis_frame_wr_data,    rx_axis_cpl_wr_data,  rx_axis_irq_data } ),
    .s_axis_req_tuser  ( { rx_axis_frame_wr_head,    rx_axis_cpl_wr_head,  rx_axis_irq_head } ),
    .s_axis_req_tlast  ( { rx_axis_frame_wr_last,    rx_axis_cpl_wr_last,  rx_axis_irq_last } ),
    .s_axis_req_tkeep  ( {(3 * `DMA_KEEP_WIDTH){1'b0}}                                              ),
    .s_axis_req_tready ( { rx_axis_frame_wr_ready,   rx_axis_cpl_wr_ready, rx_axis_irq_ready } ),
    /* -------Slave AXIS Interface{end}------- */

    /* ------- Master AXIS Interface{begin} ------- */
    .m_axis_req_tvalid (   rx_axis_wr_valid  ),
    .m_axis_req_tdata  (   rx_axis_wr_data ), 
    .m_axis_req_tuser  (   rx_axis_wr_head ), 
    .m_axis_req_tlast  (   rx_axis_wr_last ),    
    .m_axis_req_tkeep  (              	),
    .m_axis_req_tready (   rx_axis_wr_ready ) 
    /* ------- Master AXIS Interface{end} ------- */

    `ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved | reserved | idx | end | out |
     * |  255:10  |   9:5    | 4:2 |  1  |  0  |
     */
    ,.debug(debug_rx_dma)
    /* ------- Debug interface {end}------- */
`endif
);

// generate
//   if(RX_CHECKSUM_ENABLE) begin: RX_CSUM
    rx_checksum #(
      .REVERSE(1)
    ) rx_checksum_inst (
      .clk(clk),
      .rst_n(rst_n),

      .axis_rx_valid(axis_rx_vlan_valid),
      .axis_rx_last(axis_rx_vlan_last),
      .axis_rx_data(axis_rx_vlan_data),
      .axis_rx_data_be(axis_rx_vlan_data_be),
      .axis_rx_ready(axis_rx_vlan_ready),

      .csum_valid(csum_valid),
      .csum_data(csum_data),
      .csum_status(csum_status)

      `ifdef ETH_CHIP_DEBUG
        // ,input 	  wire		[0 : 0] 		Rw_data
        // ,output 	  wire 		[0 : 0] 		Ro_data
        ,.Dbg_sel(Dbg_sel_rx_checksum)
        ,.Dbg_bus(Dbg_bus_rx_checksum)
      `endif

      `ifdef SIMULATION
          /* ------- Debug interface {begin}------- */
          /* | reserved | reserved | idx | end | out |
          * |  255:10  |   9:5    | 4:2 |  1  |  0  |
          */
          ,.debug(debug_rx_csum)
          /* ------- Debug interface {end}------- */
      `endif
    );

    eth_sync_fifo_2psram  
    #( .DATA_WIDTH(`STATUS_WIDTH + `CSUM_WIDTH), //128data+4valid+sop+eop+12dstport
      .FIFO_DEPTH(`RX_PKT_ELEMENT_DEPTH)
    ) sync_fifo_2psram_rx_checksum_inst (
      .clk  (clk  ),
      .rst_n(rst_n),
      .wr_en(csum_valid),
      .din  ({csum_status, csum_data}),
      .full ( ),
		.progfull(),
      .rd_en(rx_csum_fifo_rd),
      .dout ({rx_csum_status_fifo, rx_csum_data_fifo}),
      .empty(rx_csum_empty),
      .empty_entry_num(),
      .count()
    `ifdef ETH_CHIP_DEBUG
      ,.rw_data(rw_data[3*32 +: 32])
    `endif
    );
//   end else begin
//     // assign rx_csum_fifo_rd    = 'b0;
//     assign rx_csum_data_fifo       = 'b0;
//     assign rx_csum_empty      = 'b0;
//   end
// endgenerate


// generate
//   if(RX_VLAN_ENABLE) begin:RX_VLAN   

    rx_vlan rx_vlan_inst
    (
      .clk  (clk  ),
      .rst_n(rst_n),

      /*interface to mac tx  */
      .axis_rx_valid(axis_rx_valid), 
      .axis_rx_last(axis_rx_last),
      .axis_rx_data(axis_rx_data),
      .axis_rx_data_be(axis_rx_data_be),
      .axis_rx_ready(axis_rx_ready),

      .axis_rx_vlan_valid(axis_rx_vlan_valid), 
      .axis_rx_vlan_last(axis_rx_vlan_last),
      .axis_rx_vlan_data(axis_rx_vlan_data),
      .axis_rx_vlan_data_be(axis_rx_vlan_data_be),
      .axis_rx_vlan_ready(axis_rx_vlan_ready),

      /*interface to roce rx  */
      .rx_vlan_tci(rx_vlan_tci),
      .rx_vlan_valid(rx_vlan_valid),
      .rx_vlan_status(rx_vlan_status)

      `ifdef ETH_CHIP_DEBUG
        ,.Dbg_sel(Dbg_sel_rx_vlan)
        ,.Dbg_bus(Dbg_bus_rx_vlan)
      `endif
    );

    eth_sync_fifo_2psram  
    #( .DATA_WIDTH(`STATUS_WIDTH + `VLAN_TAG_WIDTH), //128data+4valid+sop+eop+12dstport
      .FIFO_DEPTH(`RX_PKT_ELEMENT_DEPTH)
    ) sync_fifo_2psram_rx_vlan_inst (
      .clk  (clk  ),
      .rst_n(rst_n),
      .wr_en(rx_vlan_valid),
      .din  ({rx_vlan_status, rx_vlan_tci}),
      .full ( ),
		.progfull(),
      .rd_en(rx_vlan_fifo_rd),
      .dout ({rx_vlan_status_fifo, rx_vlan_tci_fifo}),
      .empty(rx_vlan_empty),
      .empty_entry_num(),
      .count()
      `ifdef ETH_CHIP_DEBUG
        ,.rw_data(rw_data[4*32 +: 32])
      `endif
    );

`ifdef SIMULATION
    reg [15:0]  t_sim_vlan_cnt;

    always@(posedge clk, negedge rst_n) begin
      if(!rst_n) begin
        t_sim_vlan_cnt <= `TD 0;
      end else begin
        if(rx_vlan_fifo_rd) begin
          t_sim_vlan_cnt <= `TD t_sim_vlan_cnt + 1;
        end
      end
    end
`endif
//   end else begin
//     assign axis_rx_vlan_valid    = axis_rx_valid;
//     assign axis_rx_vlan_last    = axis_rx_last;
//     assign axis_rx_vlan_data    = axis_rx_data;
//     assign axis_rx_vlan_data_be  = axis_rx_data_be;
//     assign axis_rx_vlan_ready    = axis_rx_ready;

//     assign rx_vlan_status_fifo = 'b0;
//     assign rx_vlan_tci_fifo    = 'b0;
//     assign rx_vlan_empty       = 'b0; 

//   end
// endgenerate

//ila_mac2engine ila_rx_mac_engine_inst(
//    .clk(clk),
//    .probe0(axis_rx_data),
//    .probe1(axis_rx_valid),
//    .probe2(axis_rx_data_be),
//    .probe3(axis_rx_last),
//    .probe4(axis_rx_ready),

//    .probe5(axis_rx_vlan_data),
//    .probe6(axis_rx_vlan_valid),
//    .probe7(axis_rx_vlan_data_be),
//    .probe8(axis_rx_vlan_last),
//    .probe9(axis_rx_vlan_ready)
//);

endmodule
