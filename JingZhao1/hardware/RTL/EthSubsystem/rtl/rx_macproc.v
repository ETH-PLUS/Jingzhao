`timescale 1ns / 100ps
//*************************************************************************
// > File Name: rx_macproc.v
// > Author   : Li jianxiong
// > Date     : 2021-10-12
// > Note     : rx_macproc is used for process rx mac frame
//              module receive the mac frame and request for description,
//              and send the frame to memory.
//              eventually send the completion message
//              TODO: didn't consider the empty desc and empty fifo
// > V1.1 - 2021-10-19 : 
//*************************************************************************

module rx_macproc #(
  parameter QUEUE_COUNT = 32,

  parameter DESC_TABLE_SIZE = 128,
  /* hash and csum parameter */
  parameter CSUM_ENABLE   = 0
) (
  input   wire                              clk,
  input   wire                              rst_n,

  /* from hash, indicate that a frame is coming */
  input  wire [`HASH_WIDTH-1:0]               rx_hash_fifo, 
  input  wire                                 rx_hash_fifo_empty,
  output wire                                 rx_hash_fifo_rd,

  /* from the mac fifo, indicate the frame receive status */
  input   wire                                rx_frame_fifo_empty,
  input   wire [`ETH_LEN_WIDTH-1:0]           rx_frame_fifo_len_fifo,
  input   wire [`STATUS_WIDTH-1:0]            rx_frame_fifo_status_fifo,
  output  wire                                rx_frame_fifo_rd,

  
  /*
  * Receive checksum input
  */
  input   wire [`CSUM_WIDTH-1:0]                rx_csum_data,
  input   wire [`STATUS_WIDTH-1:0]              rx_csum_status,
  input   wire                                  rx_csum_empty,
  output  wire                                  rx_csum_fifo_rd,

  /*
  * Receive checksum input
  */
  input   wire [`VLAN_TAG_WIDTH-1:0]            rx_vlan_tci,
  input   wire [`STATUS_WIDTH-1:0]              rx_vlan_status,
  input   wire                                  rx_vlan_empty,
  output  wire                                  rx_vlan_fifo_rd,

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

  /* to frame dma, when get the the desc, output the dma adder to frame */
  output  wire [`DMA_ADDR_WIDTH-1:0]          rx_frame_dma_req_addr,
  output  wire [`STATUS_WIDTH-1:0]            rx_frame_dma_req_status,
  output  wire [`ETH_LEN_WIDTH-1:0]           rx_frame_dma_req_len,
  output  wire                                rx_frame_dma_req_valid,
  input   wire                                rx_frame_dma_req_ready,

  input wire                                  rx_frame_dma_finish_valid,
  input wire [`STATUS_WIDTH-1:0]              rx_frame_dma_finish_status,

  output wire                                 rx_axis_cpl_wr_valid,
  output wire [`DMA_DATA_WIDTH-1:0]           rx_axis_cpl_wr_data,
  output wire [`DMA_HEAD_WIDTH-1:0]           rx_axis_cpl_wr_head,
  output wire                                 rx_axis_cpl_wr_last,
  input  wire                                 rx_axis_cpl_wr_ready,

  /* irq dma interface */
  output wire                                 rx_axis_irq_valid,
  output wire [`DMA_DATA_WIDTH-1:0]           rx_axis_irq_data,
  output wire [`DMA_HEAD_WIDTH-1:0]           rx_axis_irq_head,
  output wire                                 rx_axis_irq_last,
  input  wire                                 rx_axis_irq_ready,
  
  /* output to queue manager , finish cpl */
  output  wire [`QUEUE_NUMBER_WIDTH-1:0]      rx_cpl_finish_qnum,
  output  wire                                rx_cpl_finish_valid,
  input   wire                                rx_cpl_finish_ready

  , input  wire                                   msix_enable
  

  ,output reg [31:0]                           rx_mac_proc_rec_cnt
  ,output reg [31:0]                           rx_mac_proc_desc_cnt
  ,output reg [31:0]                           rx_mac_proc_cpl_cnt
  ,output reg [31:0]                           rx_mac_proc_msix_cnt
  ,output reg [31:0]                           rx_mac_proc_error_cnt

`ifdef ETH_CHIP_DEBUG
  // ,input 	  wire		[0 : 0] 		Rw_data
	// ,output 	wire 		[0 : 0] 		Ro_data
  ,input 	  wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_sel
	,output 	wire 		[`DBG_DATA_WIDTH - 1 : 0]		  Dbg_bus
	//,output 	wire 		[`RX_MACPROC_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_bus
`endif
);

localparam CL_DESC_TABLE_SIZE     = $clog2(DESC_TABLE_SIZE);
localparam DESC_PTR_MASK          = {1'b0, {CL_DESC_TABLE_SIZE{1'b1}}};
localparam CL_QUEUE_COUNT         = $clog2(QUEUE_COUNT);


reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_start_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_dequeue_start_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_dequeue_finish_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_write_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_write_finish_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_cpl_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_irq_finish_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_queue_cpl_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_csum_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_vlan_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_mac_fifo_ptr;

reg [CL_QUEUE_COUNT-1:0]           desc_table_qnum[DESC_TABLE_SIZE-1:0]; 
reg [`QUEUE_INDEX_WIDTH-1:0]       desc_table_qindex[DESC_TABLE_SIZE-1:0]; 
reg [`DMA_ADDR_WIDTH-1:0]          desc_table_dma_addr[DESC_TABLE_SIZE-1:0];
reg [`ETH_LEN_WIDTH-1:0]           desc_table_desc_len[DESC_TABLE_SIZE-1:0];
reg [`DMA_ADDR_WIDTH-1:0]          desc_table_cpl_addr[DESC_TABLE_SIZE-1:0]; 
reg [`IRQ_MSG-1:0]                 desc_table_msix_msg[DESC_TABLE_SIZE-1:0];
reg [`DMA_ADDR_WIDTH-1:0]          desc_table_msix_addr[DESC_TABLE_SIZE-1:0];
reg [`STATUS_WIDTH-1:0]            desc_table_desc_status[DESC_TABLE_SIZE-1:0]; 
reg [`CSUM_WIDTH-1:0]              desc_table_csum_data[DESC_TABLE_SIZE-1:0]; 
reg [`STATUS_WIDTH-1:0]            desc_table_csum_status[DESC_TABLE_SIZE-1:0]; 
reg [`VLAN_TAG_WIDTH-1:0]          desc_table_vlan_tci[DESC_TABLE_SIZE-1:0]; 
reg [`STATUS_WIDTH-1:0]            desc_table_vlan_status[DESC_TABLE_SIZE-1:0]; 
reg [`HASH_WIDTH-1:0]              desc_table_hash[DESC_TABLE_SIZE-1:0]; 
reg [`ETH_LEN_WIDTH-1:0]           desc_table_frame_fifo_len[DESC_TABLE_SIZE-1:0];

wire  desc_table_start_en;
wire  desc_dequeue_start_en;
wire  desc_dequeue_finish_en;
wire  desc_write_start_en;
wire  desc_wirte_finish_en;
wire  desc_cpl_finish_en;
wire  desc_csum_en;
wire  desc_vlan_en;
wire  desc_mac_fifo_en;
wire  desc_interrupt_finish_en;
wire  desc_queue_cpl_en;

/* -------deal with new frame {begin}------- */
/* if table is available to start a new frame */
assign rx_hash_fifo_rd  = desc_table_start_en;

/* begin to receive a new frame */
assign desc_table_start_en    = ($unsigned(desc_table_start_ptr - desc_table_irq_finish_ptr) < DESC_TABLE_SIZE)
                                      && !rx_hash_fifo_empty;

/* get the queue  */

integer i;
always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_start_ptr            <= `TD  'b0;
    for(i = 0; i < DESC_TABLE_SIZE; i = i + 1) begin:init_get
      desc_table_qnum[i]          <= `TD 0;
      desc_table_hash[i]          <= `TD 0;
    end
  end else begin
    /* if a new frame coming */
    if (desc_table_start_en) begin
      /* get the qnum number */
      desc_table_qnum[desc_table_start_ptr[CL_DESC_TABLE_SIZE-1:0]]           <= `TD  rx_hash_fifo[CL_QUEUE_COUNT-1:0]; /* store the queue number */
      /* store the hash */
      desc_table_hash[desc_table_start_ptr[CL_DESC_TABLE_SIZE-1:0]]           <= `TD  rx_hash_fifo;
      /* store the frame status */
      desc_table_start_ptr                                            <= `TD  desc_table_start_ptr + 1;
    end
  end
end
/* -------deal with new frame {end}------- */

/* -------request for desc {begin}------- */
assign rx_desc_req_qnum       = desc_table_qnum[desc_table_dequeue_start_ptr[CL_DESC_TABLE_SIZE-1:0]];
/* request for desc */
assign rx_desc_req_valid      = (desc_table_dequeue_start_ptr != desc_table_start_ptr) ;

assign desc_dequeue_start_en  = (rx_desc_req_valid && rx_desc_req_ready) ;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_dequeue_start_ptr    <= `TD  'b0;
  end else begin
    if(desc_dequeue_start_en) begin
      desc_table_dequeue_start_ptr  <= `TD  desc_table_dequeue_start_ptr + 1'b1;
    end
  end
end
/* -------request for desc {end}------- */

/* -------get the desc {begin}------- */
assign desc_dequeue_finish_en        = rx_desc_rsp_valid;

assign rx_desc_rsp_ready = 1'b1;

integer j;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_dequeue_finish_ptr <= `TD  'b0;
    for(j = 0; j < DESC_TABLE_SIZE; j = j + 1) begin:init_desc
      desc_table_qindex[j]        <= `TD 0;
      desc_table_desc_len[j]      <= `TD 0;
      desc_table_dma_addr[j]      <= `TD 0;
      desc_table_cpl_addr[j]      <= `TD 0;
      desc_table_msix_msg[j]      <= `TD 0;
      desc_table_msix_addr[j]     <= `TD 0;
      desc_table_desc_status[j]   <= `TD 0;
    end
  end else begin
    if(desc_dequeue_finish_en) begin
      desc_table_dequeue_finish_ptr                                           <= `TD  desc_table_dequeue_finish_ptr + 1'b1;

      desc_table_qindex[desc_table_dequeue_finish_ptr[CL_DESC_TABLE_SIZE-1:0]]        <= `TD  rx_desc_rsp_qindex;
      desc_table_desc_len[desc_table_dequeue_finish_ptr[CL_DESC_TABLE_SIZE-1:0]]      <= `TD  rx_desc_rsp_length;
      desc_table_dma_addr[desc_table_dequeue_finish_ptr[CL_DESC_TABLE_SIZE-1:0]]      <= `TD  rx_desc_rsp_dma_addr;
      desc_table_cpl_addr[desc_table_dequeue_finish_ptr[CL_DESC_TABLE_SIZE-1:0]]      <= `TD  rx_desc_rsp_cpl_addr;
      desc_table_msix_msg[desc_table_dequeue_finish_ptr[CL_DESC_TABLE_SIZE-1:0]]      <= `TD  rx_desc_rsp_msix_msg;
      desc_table_msix_addr[desc_table_dequeue_finish_ptr[CL_DESC_TABLE_SIZE-1:0]]     <= `TD  rx_desc_rsp_msix_addr;
      desc_table_desc_status[desc_table_dequeue_finish_ptr[CL_DESC_TABLE_SIZE-1:0]]   <= `TD  rx_desc_rsp_status;
    end
  end
end
/* -------get the desc {end}------- */


/* -------get the csum {begin}------- */
assign rx_csum_fifo_rd  = desc_table_csum_ptr != desc_table_start_ptr && !rx_csum_empty;

assign desc_csum_en           = rx_csum_fifo_rd;

integer k;
always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_csum_ptr <= `TD  'b0;
    for(k = 0; k < DESC_TABLE_SIZE; k = k + 1) begin:inist_csum
      desc_table_csum_data[k]      <= `TD 0;
      desc_table_csum_status[k]    <= `TD 0;
    end
  end else begin
    if(desc_csum_en) begin
      desc_table_csum_ptr <= `TD  desc_table_csum_ptr + 1'b1;
      desc_table_csum_data[desc_table_csum_ptr[CL_DESC_TABLE_SIZE-1:0]]     <= `TD  rx_csum_data;
      desc_table_csum_status[desc_table_csum_ptr[CL_DESC_TABLE_SIZE-1:0]]   <= `TD  rx_csum_status;
    end
  end
end
/* -------get the csum {end}------- */


/* -------get the vlan {begin}------- */
assign rx_vlan_fifo_rd  = desc_table_vlan_ptr != desc_table_start_ptr && !rx_vlan_empty;

assign desc_vlan_en           = rx_vlan_fifo_rd;

integer l;
always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_vlan_ptr <= `TD  'b0;
    for(l = 0; l < DESC_TABLE_SIZE; l = l + 1) begin:init_vlan
      desc_table_vlan_tci[l]            <= `TD 0;
      desc_table_vlan_status[l]         <= `TD 0;
    end
  end else begin
    if(desc_vlan_en) begin
      desc_table_vlan_ptr <= `TD  desc_table_vlan_ptr + 1'b1;
      desc_table_vlan_tci[desc_table_vlan_ptr[CL_DESC_TABLE_SIZE-1:0]]     <= `TD  rx_vlan_tci;
      desc_table_vlan_status[desc_table_vlan_ptr[CL_DESC_TABLE_SIZE-1:0]]   <= `TD  rx_vlan_status;
    end
  end
end
/* -------get the csum {end}------- */


/* -------get the mac fifo status {begin}------- */
assign rx_frame_fifo_rd  = desc_table_mac_fifo_ptr != desc_table_start_ptr && !rx_frame_fifo_empty;

assign desc_mac_fifo_en           = rx_frame_fifo_rd;

integer m;
always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_mac_fifo_ptr <= `TD  'b0;
    for(m = 0; m < DESC_TABLE_SIZE; m = m + 1) begin:init_frame_len
      desc_table_frame_fifo_len[m]            <= `TD 0;
    end
  end else begin
    if(desc_mac_fifo_en) begin
      desc_table_mac_fifo_ptr <= `TD  desc_table_mac_fifo_ptr + 1'b1;
      desc_table_frame_fifo_len[desc_table_mac_fifo_ptr[CL_DESC_TABLE_SIZE-1:0]] <= `TD  rx_frame_fifo_len_fifo;
    end
  end
end
/* -------get the mac fifo status {end}------- */


/* -------dma the frame {begin}------- */
assign rx_frame_dma_req_valid   = desc_table_write_ptr != desc_table_dequeue_finish_ptr
                                    &&  desc_table_write_ptr != desc_table_mac_fifo_ptr;
/* dma addr  */
assign rx_frame_dma_req_addr    = desc_table_dma_addr[desc_table_write_ptr[CL_DESC_TABLE_SIZE-1:0]];
/* desc status, if error, remove the frame in the dma module  */
assign rx_frame_dma_req_status  = desc_table_desc_status[desc_table_write_ptr[CL_DESC_TABLE_SIZE-1:0]];

assign rx_frame_dma_req_len     = desc_table_frame_fifo_len[desc_table_write_ptr[CL_DESC_TABLE_SIZE-1:0]];

assign desc_write_start_en      = (rx_frame_dma_req_valid && rx_frame_dma_req_ready);

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_write_ptr  <= `TD  'b0;
  end else begin
    if(desc_write_start_en) begin
      desc_table_write_ptr <= `TD  desc_table_write_ptr + 1'b1;
    end
  end
end
/* -------dma the frame {end}------- */

/* -------dma the frame finish{begin}------- */
assign desc_wirte_finish_en      = rx_frame_dma_finish_valid;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_write_finish_ptr   <= `TD  'b0;
  end else begin
    if(desc_wirte_finish_en) begin
      desc_table_write_finish_ptr <= `TD  desc_table_write_finish_ptr + 1'b1;
    end
  end
end
/* -------dma the frame finish{end}------- */

/* -------cpl data write {begin}------- */

wire cpl_wr_error;

assign cpl_wr_error = (desc_table_cpl_ptr != desc_table_write_finish_ptr)
                      && (desc_table_desc_status[desc_table_cpl_ptr[CL_DESC_TABLE_SIZE-1:0]] == 8'h00);


assign rx_axis_cpl_wr_valid  =  (desc_table_cpl_ptr != desc_table_write_finish_ptr 
                                      && desc_table_cpl_ptr != desc_table_csum_ptr
                                      && desc_table_cpl_ptr != desc_table_vlan_ptr
                                      ) && !cpl_wr_error;


/* data format
  | Reserved  | hash_type    | hash      | csum     | Reserved | frame_len | queue index | queue number
  |  256:128  |  95:167:160  | 159:127   | 127:122  | 111:48   | 47:32     |  31:16      |   15:0
*/

wire [`CPL_STATUS_WIDTH-1:0] cpl_data_status;

assign cpl_data_status = ({24'b0, desc_table_csum_status[desc_table_cpl_ptr[CL_DESC_TABLE_SIZE-1:0]]} << 16) | 
                          ({24'b0, desc_table_vlan_status[desc_table_cpl_ptr[CL_DESC_TABLE_SIZE-1:0]]} << 15);

assign rx_axis_cpl_wr_data         = { 
                                    desc_table_vlan_tci[desc_table_cpl_ptr[CL_DESC_TABLE_SIZE-1:0]], 
                                    desc_table_csum_data[desc_table_cpl_ptr[CL_DESC_TABLE_SIZE-1:0]], 
                                    desc_table_hash[desc_table_cpl_ptr[CL_DESC_TABLE_SIZE-1:0]],  
                                    desc_table_frame_fifo_len[desc_table_cpl_ptr[CL_DESC_TABLE_SIZE-1:0]],  
                                    desc_table_qindex[desc_table_cpl_ptr[CL_DESC_TABLE_SIZE-1:0]], 
                                    {{(`QUEUE_NUMBER_WIDTH-CL_QUEUE_COUNT){1'b0}}, desc_table_qnum[desc_table_cpl_ptr[CL_DESC_TABLE_SIZE-1:0]]},
                                    cpl_data_status
                                    };

/* header format
  | Reserved | address | Reserved | Byte length |
  |  127:96  |  95:32  |  31:13   |    12:0     |
*/
assign rx_axis_cpl_wr_head         = {  32'b01, /* write */
                                        desc_table_cpl_addr[desc_table_cpl_ptr[CL_DESC_TABLE_SIZE-1:0]], /* 95:32 */                                
                                        32'd32
                                      };
/* there is only one cycle for the cpl data */                                      
assign rx_axis_cpl_wr_last         = rx_axis_cpl_wr_valid;

assign desc_cpl_finish_en         = rx_axis_cpl_wr_valid && rx_axis_cpl_wr_ready;

integer n;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_cpl_ptr <= `TD  'b0;
  end else begin
    if(desc_cpl_finish_en || cpl_wr_error) begin
      desc_table_cpl_ptr <= `TD  desc_table_cpl_ptr + 1'b1;
    end
  end
end
/* -------cpl data write {end}------- */


/* -------cpl queue head ptr increment {begin}------- */

wire cpl_finish_error;

assign cpl_finish_error = (desc_table_queue_cpl_ptr != desc_table_cpl_ptr) 
                          && (desc_table_desc_status[desc_table_queue_cpl_ptr[CL_DESC_TABLE_SIZE-1:0]] == 8'h00);

assign rx_cpl_finish_qnum       = desc_table_qnum[desc_table_queue_cpl_ptr[CL_DESC_TABLE_SIZE-1:0]];
/* cpl queue head ptr increment */
assign rx_cpl_finish_valid      = desc_table_queue_cpl_ptr != desc_table_cpl_ptr && !cpl_finish_error;

assign desc_queue_cpl_en        = rx_cpl_finish_valid && rx_cpl_finish_ready;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_queue_cpl_ptr    <= `TD  'b0;
  end else begin
    if(desc_queue_cpl_en || cpl_finish_error) begin
      desc_table_queue_cpl_ptr  <= `TD  desc_table_queue_cpl_ptr + 1'b1;
    end
  end
end
/* -------cpl queue head ptr increment {end}------- */


/* -------irq request ready {begin}------- */

/* *_head of DMA interface (interact with RDMA modules), 
  * valid only in first beat of a packet.
  * When Transmiting msi-x interrupt message, 'Byte length' 
  * should be 0, 'address' means the address of msi-x, and
  * msi-x data locates in *_data[31:0].
  * | Resvd |  Req Type |   address    | Reserved | Byte length |
  * |       |(rd,wr,int)| (msi-x addr) |          | (0 for int) |
  * |-------|-----------|--------------|----------|-------------|
  * |127:100|   99:96   |    95:32     |  31:13   |    12:0     |
  */
wire irq_wr_error;

assign irq_wr_error = (desc_table_irq_finish_ptr != desc_table_queue_cpl_ptr )
                        && (desc_table_desc_status[desc_table_irq_finish_ptr[CL_DESC_TABLE_SIZE-1:0]] == 8'h00);


assign rx_axis_irq_valid         = (desc_table_irq_finish_ptr != desc_table_queue_cpl_ptr) && !irq_wr_error && msix_enable;

assign rx_axis_irq_data          = desc_table_msix_msg[desc_table_irq_finish_ptr[CL_DESC_TABLE_SIZE-1:0]];
assign rx_axis_irq_head          = {
                                      32'b01, /* write */
                                      // 32'b01,
                                      desc_table_msix_addr[desc_table_irq_finish_ptr[CL_DESC_TABLE_SIZE-1:0]],
										//Modified by YF, int MemWr, length should be 4
                                      //32'b0
										32'd4
                                    };
                                  
assign rx_axis_irq_last           = rx_axis_irq_valid;

assign desc_interrupt_finish_en   = (rx_axis_irq_valid && rx_axis_irq_ready) || (desc_table_irq_finish_ptr != desc_table_queue_cpl_ptr && !msix_enable);

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_irq_finish_ptr <= `TD  'b0;
  end else begin
    if(desc_interrupt_finish_en || irq_wr_error) begin
      desc_table_irq_finish_ptr <= `TD  desc_table_irq_finish_ptr + 1'b1;
    end
  end
end
/* -------irq request ready {end}------- */

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    rx_mac_proc_rec_cnt                <= `TD 'b0;
  end else begin
    if(desc_table_start_en) begin
      rx_mac_proc_rec_cnt <= `TD rx_mac_proc_rec_cnt + 1'b1;
    end
  end
end

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    rx_mac_proc_desc_cnt                <= `TD 'b0;
  end else begin
    if(desc_dequeue_finish_en) begin
      rx_mac_proc_desc_cnt <= `TD rx_mac_proc_desc_cnt + 1'b1;
    end
  end
end

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    rx_mac_proc_cpl_cnt                <= `TD 'b0;
  end else begin
    if(desc_cpl_finish_en) begin
      rx_mac_proc_cpl_cnt <= `TD rx_mac_proc_cpl_cnt + 1'b1;
    end
  end
end

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    rx_mac_proc_msix_cnt                <= `TD 'b0;
  end else begin
    if(desc_interrupt_finish_en) begin
      rx_mac_proc_msix_cnt <= `TD rx_mac_proc_msix_cnt + 1'b1;
    end
  end
end

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    rx_mac_proc_error_cnt                <= `TD 'b0;
  end else begin
    if(cpl_wr_error) begin
      rx_mac_proc_error_cnt <= `TD rx_mac_proc_error_cnt + 1'b1;
    end
  end
end


`ifdef ETH_CHIP_DEBUG

wire 		[`RX_MACPROC_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_data;


assign Dbg_data = {// wire
                  16'b0, desc_table_start_en, desc_dequeue_start_en, desc_dequeue_finish_en, desc_write_start_en, 
                  desc_wirte_finish_en, desc_cpl_finish_en, desc_csum_en, desc_vlan_en, desc_mac_fifo_en, 
                  desc_interrupt_finish_en, desc_queue_cpl_en, cpl_wr_error, cpl_data_status, 
                  cpl_finish_error, irq_wr_error, 

                  // reg
                  desc_table_start_ptr, desc_table_dequeue_start_ptr, desc_table_dequeue_finish_ptr, desc_table_write_ptr, 
                  desc_table_write_finish_ptr, desc_table_cpl_ptr, desc_table_irq_finish_ptr, desc_table_queue_cpl_ptr, 
                  desc_table_csum_ptr, desc_table_vlan_ptr, desc_table_mac_fifo_ptr
                  } ;

assign Dbg_bus = Dbg_data >> (Dbg_sel << 5);
//assign Dbg_bus = Dbg_data;

`endif




// ila_dma_req ila_dma_rx_cpl_wr(
//   .clk(clk),
//   .probe0(rx_axis_cpl_wr_valid ),
//   .probe1(rx_axis_cpl_wr_last),
//   .probe2(rx_axis_cpl_wr_data),
//   .probe3(rx_axis_cpl_wr_head ),
//   .probe4(rx_axis_cpl_wr_ready)
// );

// ila_dma_req ila_dma_rx_irq(
//   .clk(clk),
//   .probe0(rx_axis_irq_valid ),
//   .probe1(rx_axis_irq_last),
//   .probe2(rx_axis_irq_data),
//   .probe3(rx_axis_irq_head ),
//   .probe4(rx_axis_irq_ready)
// );

// ila_rx_macproc ila_rx_macproc_ptr(
//   .clk(clk),
//   .probe0(desc_table_start_ptr ),
//   .probe1(desc_table_dequeue_start_ptr),
//   .probe2(desc_table_dequeue_finish_ptr),
//   .probe3(desc_table_write_ptr ),
//   .probe4(desc_table_write_finish_ptr),
//   .probe5(desc_table_cpl_ptr),
//   .probe6(desc_table_irq_finish_ptr),
//   .probe7(desc_table_queue_cpl_ptr),
//   .probe8(desc_table_csum_ptr),
//   .probe9(desc_table_vlan_ptr),
//   .probe10(desc_table_mac_fifo_ptr)
// );    

endmodule

