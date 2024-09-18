`timescale 1ns / 100ps
//*************************************************************************
// > File Name: tx_macproc.v
// > Author   : Li jianxiong
// > Date     : 2021-10-29
// > Note     : tx_macproc is used to request a frame from dma 
//              and send it to the mac
//              it implements a fifo inside.
//              TODO: lenght 

//              
// > V1.1 - 2021-10-21 : 
//*************************************************************************

module tx_macproc #(
  parameter DESC_TABLE_SIZE = 128,
  parameter REVERSE = 1
) 
(
  input   wire                              clk,
  input   wire                              rst_n,

  /* from fx_frameproc,  get the the dma addr, dma the frame 
      after finish the dma, ready set 1*/

  input   wire [`QUEUE_NUMBER_WIDTH-1:0]        tx_desc_qnum,
  input   wire [`QUEUE_INDEX_WIDTH-1:0]         tx_desc_qindex,
  input   wire [`ETH_LEN_WIDTH-1:0]             tx_desc_frame_len,
  input   wire [`DMA_ADDR_WIDTH-1:0]            tx_desc_dma_addr,
  input   wire [`DMA_ADDR_WIDTH-1:0]            tx_desc_desc_addr,
  input   wire [`CSUM_START_WIDTH-1:0]          tx_desc_csum_start,
  input   wire [`CSUM_START_WIDTH-1:0]          tx_desc_csum_offset,
  input   wire [`DMA_ADDR_WIDTH-1:0]            tx_desc_cpl_addr,
  input   wire [`IRQ_MSG-1:0]                   tx_desc_msix_msg,
  input   wire [`DMA_ADDR_WIDTH-1:0]            tx_desc_msix_addr,
  input   wire                                  tx_desc_valid,
  output  wire                                  tx_desc_ready,  


  /* to dma module, to get the frame */
  output wire                                 tx_frame_req_valid,
  output wire                                 tx_frame_req_last,
  output wire [`DMA_DATA_WIDTH-1:0]           tx_frame_req_data,
  output wire [`DMA_HEAD_WIDTH-1:0]           tx_frame_req_head,
  input  wire                                 tx_frame_req_ready,

  /* interface to dma */
  input   wire                               tx_frame_rsp_valid,
  input   wire                               tx_frame_rsp_last,
  input   wire [`DMA_DATA_WIDTH-1:0]          tx_frame_rsp_data,
  input   wire [`DMA_HEAD_WIDTH-1:0]          tx_frame_rsp_head,
  output  wire                               tx_frame_rsp_ready,

  /* interface to mac */
  output wire                                 axis_tx_valid, 
  output wire                                 axis_tx_last,
  output wire [`DMA_DATA_WIDTH-1:0]           axis_tx_data,
  output wire [`DMA_KEEP_WIDTH-1:0]           axis_tx_data_be,
  input wire                                  axis_tx_ready,
  output wire  [`XBAR_USER_WIDTH-1:0]         axis_tx_user,
  output wire                                 axis_tx_start,

  // output wire [`ETH_LEN_WIDTH-1:0]             payload_len,

  /* completion data dma interface */
  output wire                                 tx_axis_cpl_wr_valid,
  output wire [`DMA_DATA_WIDTH-1:0]           tx_axis_cpl_wr_data,
  output wire [`DMA_HEAD_WIDTH-1:0]           tx_axis_cpl_wr_head,
  output wire                                 tx_axis_cpl_wr_last,
  input  wire                                 tx_axis_cpl_wr_ready,

  output wire                                 tx_axis_irq_valid,
  output wire [`DMA_DATA_WIDTH-1:0]           tx_axis_irq_data,
  output wire [`DMA_HEAD_WIDTH-1:0]           tx_axis_irq_head,
  output wire                                 tx_axis_irq_last,
  input  wire                                 tx_axis_irq_ready,

  /* output to queue manager , finish cpl */
  output  wire [`QUEUE_NUMBER_WIDTH-1:0]      tx_cpl_finish_qnum,
  output  wire                                tx_cpl_finish_valid,
  input   wire                                tx_cpl_finish_ready

  , input  wire                                   msix_enable


  ,output reg [31:0]                           tx_mac_proc_rec_cnt
  ,output reg [31:0]                           tx_mac_proc_xmit_cnt
  ,output reg [31:0]                           tx_mac_proc_cpl_cnt
  ,output reg [31:0]                           tx_mac_proc_msix_cnt

`ifdef ETH_CHIP_DEBUG
  ,input 	wire 	[`RW_DATA_NUM_TX_MACPROC * 32 - 1 : 0]	rw_data
	// ,output 	wire 		[0 : 0] 		Ro_data
	,output 	wire 		[`TX_MACPROC_DEG_REG_NUM  * 32 - 1 : 0]		  Dbg_bus
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
localparam DESC_PTR_MASK      = {CL_DESC_TABLE_SIZE{1'b1}};
localparam CL_DMA_KEEP_WIDTH  = $clog2(`DMA_KEEP_WIDTH);

`ifdef ETH_CHIP_DEBUG

wire 		[(`TX_MACPROC_SELF_DEG_REG_NUM)  * 32 - 1 : 0]		  Dbg_bus_tx_macproc;
wire 		[(`CHECKSUM_UTIL_DEG_REG_NUM)  * 32 - 1 : 0]		    Dbg_bus_checksum_util;
`endif

wire [10-1:0]  empty_entry_num;

wire fifo_full;
wire fifo_empty;
wire fifo_wr;
wire fifo_rd;
wire fifo_enough;

wire [`DMA_DATA_WIDTH-1:0]    axis_tx_data_fifo;
wire                          axis_tx_last_fifo;

reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_start_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_frame_req_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_frame_rsp_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_frame_trans_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_cpl_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_irq_finish_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_queue_cpl_ptr;
reg [CL_DESC_TABLE_SIZE+1-1:0] desc_table_csum_ptr;

wire  desc_table_start_en;
wire  desc_frame_req_en;
wire  desc_frame_rsp_en;
wire  desc_frame_trans_en;
wire  desc_wirte_cpl_en;
wire  desc_interrupt_finish_en;
wire  desc_queue_cpl_en;
wire  desc_queue_csum_en;

reg [`QUEUE_NUMBER_WIDTH-1:0]           desc_table_qnum[DESC_TABLE_SIZE-1:0]; 
reg [`QUEUE_INDEX_WIDTH-1:0]            desc_table_qindex[DESC_TABLE_SIZE-1:0];
reg [`ETH_LEN_WIDTH-1:0]                desc_table_frame_len[DESC_TABLE_SIZE-1:0];
reg [`DMA_ADDR_WIDTH-1:0]               desc_table_dma_addr[DESC_TABLE_SIZE-1:0];
reg [`DMA_ADDR_WIDTH-1:0]               desc_table_desc_addr[DESC_TABLE_SIZE-1:0];
reg [`CSUM_START_WIDTH-1:0]             desc_table_csum_start[DESC_TABLE_SIZE-1:0];
reg [`CSUM_START_WIDTH-1:0]             desc_table_csum_offset[DESC_TABLE_SIZE-1:0];
reg [`DMA_ADDR_WIDTH-1:0]               desc_table_cpl_addr[DESC_TABLE_SIZE-1:0];
reg [`IRQ_MSG-1:0]                      desc_table_msix_msg[DESC_TABLE_SIZE-1:0];
reg [`DMA_ADDR_WIDTH-1:0]               desc_table_msix_addr[DESC_TABLE_SIZE-1:0];


/* -------deal with new frame {begin}------- */
assign tx_desc_ready   = ($unsigned(desc_table_start_ptr - desc_table_irq_finish_ptr) < DESC_TABLE_SIZE);
assign desc_table_start_en      = tx_desc_ready && tx_desc_valid;

integer i;
always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_start_ptr            <= `TD  'b0;
    for(i = 0; i < DESC_TABLE_SIZE; i = i + 1) begin:init_start
      desc_table_qnum[i]            <= `TD 0;
      desc_table_qindex[i]          <= `TD 0;
      desc_table_frame_len[i]       <= `TD 0;
      desc_table_dma_addr[i]        <= `TD 0;
      desc_table_csum_start[i]      <= `TD 0;
      desc_table_csum_offset[i]     <= `TD 0;
      desc_table_desc_addr[i]       <= `TD 0;
      desc_table_cpl_addr[i]        <= `TD 0;
      desc_table_msix_msg[i]        <= `TD 0;
      desc_table_msix_addr[i]       <= `TD 0;
    end
  end else begin
    /* if a new frame coming */
    if (desc_table_start_en) begin
      /* store the frame status */
      desc_table_qnum[desc_table_start_ptr[CL_DESC_TABLE_SIZE-1:0]]         <= `TD  tx_desc_qnum;
      desc_table_qindex[desc_table_start_ptr[CL_DESC_TABLE_SIZE-1:0]]       <= `TD  tx_desc_qindex;
      desc_table_frame_len[desc_table_start_ptr[CL_DESC_TABLE_SIZE-1:0]]    <= `TD  tx_desc_frame_len;
      desc_table_dma_addr[desc_table_start_ptr[CL_DESC_TABLE_SIZE-1:0]]     <= `TD  tx_desc_dma_addr;
      desc_table_csum_start[desc_table_start_ptr[CL_DESC_TABLE_SIZE-1:0]]   <= `TD  tx_desc_csum_start;
      desc_table_csum_offset[desc_table_start_ptr[CL_DESC_TABLE_SIZE-1:0]]  <= `TD  tx_desc_csum_offset;
      desc_table_desc_addr[desc_table_start_ptr[CL_DESC_TABLE_SIZE-1:0]]    <= `TD  tx_desc_desc_addr;
      desc_table_cpl_addr[desc_table_start_ptr[CL_DESC_TABLE_SIZE-1:0]]     <= `TD  tx_desc_cpl_addr;
      desc_table_msix_msg[desc_table_start_ptr[CL_DESC_TABLE_SIZE-1:0]]     <= `TD  tx_desc_msix_msg;
      desc_table_msix_addr[desc_table_start_ptr[CL_DESC_TABLE_SIZE-1:0]]    <= `TD  tx_desc_msix_addr;
      desc_table_start_ptr <= `TD  desc_table_start_ptr + 1;
    end
  end
end
/* -------deal with new frame {end}------- */


 /* -------begin to fetch the desc {begin}------- */
assign fifo_enough         = (desc_table_frame_len[desc_table_frame_req_ptr[CL_DESC_TABLE_SIZE-1:0]] >> 8) < empty_entry_num;


assign tx_frame_req_valid   = (desc_table_frame_req_ptr != desc_table_start_ptr) && fifo_enough;
assign tx_frame_req_last    = tx_frame_req_valid;

assign tx_frame_req_data    = 'b0;

assign tx_frame_req_head    = {32'b0, 
                            desc_table_dma_addr[desc_table_frame_req_ptr[CL_DESC_TABLE_SIZE-1:0]],
                            16'b0,                                                                
                            desc_table_frame_len[desc_table_frame_req_ptr[CL_DESC_TABLE_SIZE-1:0]]};



/* dma_*_head(interact with RDMA modules), valid only in first beat of a packet
    * | Reserved | address | Reserved | Byte length |
    * |  127:96  |  95:32  |  31:13   |    12:0     |
    */

assign desc_frame_req_en  = tx_frame_req_valid && tx_frame_req_ready;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_frame_req_ptr <= `TD  'b0;
  end else begin
    if(desc_frame_req_en) begin
      desc_table_frame_req_ptr <= `TD  desc_table_frame_req_ptr + 1'b1;
    end
  end
end
 /* -------begin to fetch the desc {end}------- */


 /* -------get the frame, finish the fetch operation {begin}------- */
assign tx_frame_rsp_ready   = !fifo_full;
assign desc_frame_rsp_en    = tx_frame_rsp_valid && tx_frame_rsp_ready && tx_frame_rsp_last;

assign fifo_wr = tx_frame_rsp_valid && tx_frame_rsp_ready;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_frame_rsp_ptr <= `TD  'b0;
  end else begin
    if(desc_frame_rsp_en) begin
      desc_table_frame_rsp_ptr <= `TD  desc_table_frame_rsp_ptr + 1'b1;      
    end
  end
end
/* -------get the frame, finish the fetch operation {end}------- */


/* -------csum {begin}------- */

wire [15:0]                         tx_csum_out;
wire                                tx_csum_out_valid;

wire [15:0]                         tx_csum_out_fifo;
wire                                tx_csum_fifo_rd;
wire                                tx_csum_fifo_empty;

assign desc_queue_csum_en    =  desc_table_csum_ptr != desc_table_frame_rsp_ptr && tx_csum_out_valid;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_csum_ptr    <= `TD  'b0;
  end else begin
    if(desc_queue_csum_en) begin
      desc_table_csum_ptr  <= `TD  desc_table_csum_ptr + 1'b1;
    end
  end
end
/* -------csum {end}------- */

/* send the frame to mac {begin}*/
/* calculate the last cycle data_be */
function [`DMA_KEEP_WIDTH:0] data_be_calculate(
  input [`ETH_LEN_WIDTH-1:0]  len
);
  begin
    /* the last  */
    data_be_calculate = len[CL_DMA_KEEP_WIDTH-1:0] == 'b0 ? {`DMA_KEEP_WIDTH{1'b1}} : ({`DMA_KEEP_WIDTH{1'b1}} << len[CL_DMA_KEEP_WIDTH-1:0]) ^ {`DMA_KEEP_WIDTH{1'b1}};
  end  
endfunction

wire [`CSUM_START_WIDTH-1:0] csum_offset_out; 

wire [`ETH_LEN_WIDTH-1:0] frame_len_out;

reg [`DMA_DATA_WIDTH-1:0] axis_tx_data_tmp;

reg [15:0]  csum_out_cnt;

assign frame_len_out = desc_table_frame_len[desc_table_frame_trans_ptr[CL_DESC_TABLE_SIZE-1:0]];

assign fifo_rd = axis_tx_valid && axis_tx_ready;

assign tx_csum_fifo_rd = axis_tx_valid && axis_tx_ready && axis_tx_last;

assign csum_offset_out =  desc_table_csum_offset[desc_table_frame_trans_ptr[CL_DESC_TABLE_SIZE-1:0]];

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    csum_out_cnt <= `TD 0;
  end else begin
    if(axis_tx_valid && axis_tx_ready && axis_tx_last) begin
      csum_out_cnt <= `TD 0;
    end else if (axis_tx_valid && axis_tx_ready) begin
      csum_out_cnt <= `TD csum_out_cnt + 1;
    end else begin
      csum_out_cnt <= `TD csum_out_cnt;
    end
  end
end

always@(*)begin
  if(csum_offset_out != 0) begin
    case(csum_out_cnt)
      0:begin
        axis_tx_data_tmp = axis_tx_data_fifo;
      end
      1:begin
        if(csum_offset_out < 2 * `DMA_KEEP_WIDTH) begin          
          axis_tx_data_tmp = (axis_tx_data_fifo & ~({240'b0, 16'hffff} << ((csum_offset_out - `DMA_KEEP_WIDTH) << 3)))
                                | ({240'h0, tx_csum_out_fifo} << ((csum_offset_out - `DMA_KEEP_WIDTH) << 3));     
        end else begin
          axis_tx_data_tmp = axis_tx_data_fifo;
        end
      end
      2:begin
        if(csum_offset_out < 2 * `DMA_KEEP_WIDTH) begin
          axis_tx_data_tmp = axis_tx_data_fifo;
        end else begin
          axis_tx_data_tmp = (axis_tx_data_fifo & ~({240'b0, 16'hffff} << ((csum_offset_out - 2 * `DMA_KEEP_WIDTH) << 3)))  
                                | ({240'h0, tx_csum_out_fifo} << ((csum_offset_out - 2 * `DMA_KEEP_WIDTH) << 3));
        end
      end
      default:
        axis_tx_data_tmp = axis_tx_data_fifo;
    endcase
  end else begin
    axis_tx_data_tmp = axis_tx_data_fifo;
  end
end

assign axis_tx_valid          =  !fifo_empty && !tx_csum_fifo_empty && desc_table_frame_trans_ptr != desc_table_csum_ptr;
assign axis_tx_data           =  axis_tx_data_tmp;
assign axis_tx_last           =  axis_tx_last_fifo && axis_tx_valid;
assign axis_tx_data_be        =  axis_tx_valid & axis_tx_last_fifo ? data_be_calculate(frame_len_out) : {`DMA_KEEP_WIDTH{1'b1}};
assign axis_tx_user           =  frame_len_out[`ETH_LEN_WIDTH-1:10] + (|frame_len_out[9:0]);
// assign axis_tx_user           =  frame_len_out[`ETH_LEN_WIDTH-1:2] + (|frame_len_out[1:0]) + 2;
assign axis_tx_start          =   0;

/* the payload len, use total len  subtracted the mac header*/
// assign payload_len            = desc_table_frame_len[desc_table_frame_trans_ptr[CL_DESC_TABLE_SIZE-1:0]];

/* finish the last cycle */
assign desc_frame_trans_en    =  axis_tx_valid && axis_tx_ready && axis_tx_last;
 

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_frame_trans_ptr <= `TD  'b0;
  end else begin
    if(desc_frame_trans_en) begin
      desc_table_frame_trans_ptr <= `TD  desc_table_frame_trans_ptr + 1'b1;
    end
  end
end
/* send the frame to mac {end}*/


/* ------------send cpl {begin}-------------*/
/* data format
  | Reserved  | hash_type    | hash      | csum     | Reserved | frame_len | queue index | queue number
  |  511:128  |  95:167:160  | 159:127   | 127:122  | 111:48   | 47:32     |  31:16      |   15:0
*/

assign tx_axis_cpl_wr_data         = {  160'b0,    
                                        desc_table_frame_len[desc_table_cpl_ptr[CL_DESC_TABLE_SIZE-1:0]],
                                        desc_table_qindex[desc_table_cpl_ptr[CL_DESC_TABLE_SIZE-1:0]],
                                        desc_table_qnum[desc_table_cpl_ptr[CL_DESC_TABLE_SIZE-1:0]],
                                        32'b0   
                                        };
/* header format
  | Reserved | address | Reserved | Byte length |
  |  127:96  |  95:32  |  31:13   |    12:0     |
*/
assign tx_axis_cpl_wr_head         = {  32'b01, /* write */
                                        desc_table_cpl_addr[desc_table_cpl_ptr[CL_DESC_TABLE_SIZE-1:0]], /* 127:96 */
                                        32'd32 /* 256 */
                                      };
/* there is only one cycle for the cpl data */                                      
assign tx_axis_cpl_wr_last         = tx_axis_cpl_wr_valid;

assign tx_axis_cpl_wr_valid         = desc_table_cpl_ptr != desc_table_frame_trans_ptr 
                                        && desc_table_cpl_ptr != desc_table_frame_rsp_ptr;

assign desc_wirte_cpl_en            = tx_axis_cpl_wr_valid && tx_axis_cpl_wr_ready;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_cpl_ptr <= `TD  'b0;
  end else begin
    if(desc_wirte_cpl_en) begin
      desc_table_cpl_ptr <= `TD  desc_table_cpl_ptr + 1'b1;
    end
  end
end

/* ------------send cpl {end}-------------*/

/* -------cpl queue head ptr increment {begin}------- */
assign tx_cpl_finish_qnum       = desc_table_qnum[desc_table_queue_cpl_ptr[CL_DESC_TABLE_SIZE-1:0]];
/* cpl queue head ptr increment */
assign tx_cpl_finish_valid      = (desc_table_queue_cpl_ptr != desc_table_cpl_ptr) ;

assign desc_queue_cpl_en        = (tx_cpl_finish_valid && tx_cpl_finish_ready) ;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_queue_cpl_ptr    <= `TD  'b0;
  end else begin
    if(desc_queue_cpl_en) begin
      desc_table_queue_cpl_ptr  <= `TD  desc_table_queue_cpl_ptr + 1'b1;
    end
  end
end
/* -------cpl queue head ptr increment {end}------- */


/* -------irq request {begin}------- */

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
assign tx_axis_irq_valid         = desc_table_irq_finish_ptr != desc_table_queue_cpl_ptr && msix_enable;

assign tx_axis_irq_data          = desc_table_msix_msg[desc_table_irq_finish_ptr[CL_DESC_TABLE_SIZE-1:0]];
assign tx_axis_irq_head          = {
                                      32'b01, /* write */
                                      // 32'b01
                                      desc_table_msix_addr[desc_table_irq_finish_ptr[CL_DESC_TABLE_SIZE-1:0]],
                                      32'd4
                                    };
                                  
assign tx_axis_irq_last           = tx_axis_irq_valid;

assign desc_interrupt_finish_en   = (tx_axis_irq_valid && tx_axis_irq_ready) || (desc_table_irq_finish_ptr != desc_table_queue_cpl_ptr && !msix_enable);

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    desc_table_irq_finish_ptr <= `TD  'b0;
  end else begin
    if(desc_interrupt_finish_en) begin
      desc_table_irq_finish_ptr <= `TD  desc_table_irq_finish_ptr + 1'b1;
    end
  end
end
/* -------irq request {end}------- */


eth_sync_fifo_2psram  
#( .DATA_WIDTH(`DMA_DATA_WIDTH + 1),
  .FIFO_DEPTH(`TX_PKT_FIFO_DEPTH)
) sync_fifo_2psram_inst (
  .clk  (clk  ),
  .rst_n(rst_n),
  .wr_en(fifo_wr),
  .din  ({tx_frame_rsp_last, tx_frame_rsp_data}),
  .full (),
  .progfull (fifo_full),
  .rd_en(fifo_rd),
  .dout ({axis_tx_last_fifo, axis_tx_data_fifo}),
  .empty(fifo_empty),
  .empty_entry_num(empty_entry_num),
  .count()
  `ifdef ETH_CHIP_DEBUG
    ,.rw_data(rw_data[1 * 32 - 1 : 0])
  `endif
);

wire                                tx_csum_valid;
wire                                tx_csum_last;
wire [`DMA_DATA_WIDTH-1:0]          tx_csum_data;
reg  [`DMA_KEEP_WIDTH-1:0]          tx_csum_data_be;

wire  [`DMA_KEEP_WIDTH-1:0]          tx_frame_rsp_data_be;
wire  [`ETH_LEN_WIDTH-1:0]           tx_frame_rsp_frame_len;

wire [`CSUM_START_WIDTH-1:0] csum_start;

assign csum_start  =  desc_table_csum_start[desc_table_frame_rsp_ptr[CL_DESC_TABLE_SIZE-1:0]] ; 
      
reg [15:0]  csum_cal_cnt;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    csum_cal_cnt <= `TD 0;
  end else begin
    if(tx_frame_rsp_valid & tx_frame_rsp_ready & tx_frame_rsp_last) begin
      csum_cal_cnt <= `TD 0;
    end else if (tx_frame_rsp_valid & tx_frame_rsp_ready) begin
      csum_cal_cnt <= `TD csum_cal_cnt + 1;
    end else begin
      csum_cal_cnt <= `TD csum_cal_cnt;
    end
  end
end


assign tx_csum_valid = tx_frame_rsp_valid & tx_frame_rsp_ready;
assign tx_csum_last  = tx_frame_rsp_last;
assign tx_csum_data  = tx_frame_rsp_data;

assign tx_frame_rsp_frame_len = desc_table_frame_len[desc_table_frame_rsp_ptr[CL_DESC_TABLE_SIZE-1:0]];

assign tx_frame_rsp_data_be = tx_frame_rsp_last ?  data_be_calculate(tx_frame_rsp_frame_len) : {`DMA_KEEP_WIDTH{1'b1}};


always@(*) begin
  case (csum_cal_cnt)
    0:begin
      tx_csum_data_be = `DMA_KEEP_WIDTH'h0;
    end
    1:begin
      if(csum_start < 2 * `DMA_KEEP_WIDTH) begin
        tx_csum_data_be = (`DMA_KEEP_WIDTH'hffff_ffff & tx_frame_rsp_data_be) << (csum_start - `DMA_KEEP_WIDTH);
      end else begin
        tx_csum_data_be = `DMA_KEEP_WIDTH'h0;
      end
    end
    2:begin
      if(csum_start < 2 * `DMA_KEEP_WIDTH) begin
        tx_csum_data_be = (`DMA_KEEP_WIDTH'hffff_ffff & tx_frame_rsp_data_be);
      end else begin
        tx_csum_data_be = (`DMA_KEEP_WIDTH'hffff_ffff & tx_frame_rsp_data_be) << (csum_start - 2 * `DMA_KEEP_WIDTH);
      end
    end
    default:
      tx_csum_data_be = (`DMA_KEEP_WIDTH'hffff_ffff & tx_frame_rsp_data_be);    
  endcase
end


checksum_util #(
  .DATA_WIDTH(`DMA_DATA_WIDTH),
  .KEEP_WIDTH(`DMA_KEEP_WIDTH),
  .REVERSE(REVERSE),
  .START_OFFSET(0)
)
l4_checksum_util
(
  .clk(clk),
  .rst_n(rst_n),

  /*interface to mac rx  */
  .csum_data_valid(tx_csum_valid), 
  .csum_data_last(tx_csum_last),
  .csum_data(tx_csum_data),
  .csum_data_be(tx_csum_data_be),

  /*otuput to rx_engine, csum is used for offload*/
  .csum_out(tx_csum_out),
  .csum_out_valid(tx_csum_out_valid)

`ifdef ETH_CHIP_DEBUG
	// ,output 	  wire 		[0 : 0] 		Ro_data
	,.Dbg_bus(Dbg_bus_checksum_util)
`endif
);

eth_sync_fifo_2psram  
#( .DATA_WIDTH(`CSUM_WIDTH),
  .FIFO_DEPTH(`TX_PKT_ELEMENT_DEPTH)
) sync_fifo_2psram_csum_inst (
  .clk  (clk  ),
  .rst_n(rst_n),
  .wr_en(tx_csum_out_valid),
  .din  ({tx_csum_out[7:0], tx_csum_out[15:8]}),
  .full (),
  .progfull (),
  .rd_en(tx_csum_fifo_rd),
  .dout (tx_csum_out_fifo ),
  .empty(tx_csum_fifo_empty),
  .empty_entry_num(),
  .count()
  `ifdef ETH_CHIP_DEBUG
    ,.rw_data(rw_data[1*32 +: 32])
  `endif
);


always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    tx_mac_proc_rec_cnt                <= `TD 'b0;
  end else begin
    if(tx_frame_req_valid && tx_frame_req_ready) begin
      tx_mac_proc_rec_cnt <= `TD tx_mac_proc_rec_cnt + 1'b1;
    end
  end
end

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    tx_mac_proc_xmit_cnt                <= `TD 'b0;
  end else begin
    if(axis_tx_valid && axis_tx_ready && axis_tx_last) begin
      tx_mac_proc_xmit_cnt <= `TD tx_mac_proc_xmit_cnt + 1'b1;
    end
  end
end

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    tx_mac_proc_cpl_cnt                <= `TD 'b0;
  end else begin
    if(tx_axis_cpl_wr_valid && tx_axis_cpl_wr_ready) begin
      tx_mac_proc_cpl_cnt <= `TD tx_mac_proc_cpl_cnt + 1'b1;
    end
  end
end

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    tx_mac_proc_msix_cnt                <= `TD 'b0;
  end else begin
    if(desc_interrupt_finish_en) begin
      tx_mac_proc_msix_cnt <= `TD tx_mac_proc_msix_cnt + 1'b1;
    end
  end
end


`ifdef ETH_CHIP_DEBUG

assign Dbg_bus_tx_macproc = {// wire
                  3'b0, empty_entry_num, fifo_full, fifo_empty, fifo_wr, fifo_rd, fifo_enough, axis_tx_data_fifo, axis_tx_last_fifo, 
                  desc_table_start_en, desc_frame_req_en, desc_frame_rsp_en, desc_frame_trans_en, desc_wirte_cpl_en, desc_interrupt_finish_en, 
                  desc_queue_cpl_en, desc_queue_csum_en, tx_csum_out, tx_csum_out_valid, tx_csum_out_fifo, tx_csum_fifo_rd, tx_csum_fifo_empty, 
                  csum_offset_out, frame_len_out, tx_csum_valid, tx_csum_last, tx_csum_data, tx_frame_rsp_data_be, tx_frame_rsp_frame_len, csum_start,

                  // reg
                  desc_table_start_ptr, desc_table_frame_req_ptr, desc_table_frame_rsp_ptr, desc_table_frame_trans_ptr, 
                  desc_table_cpl_ptr, desc_table_irq_finish_ptr, desc_table_queue_cpl_ptr, desc_table_csum_ptr, axis_tx_data_tmp, csum_out_cnt, tx_csum_data_be, csum_cal_cnt
                  } ;

assign Dbg_bus = {Dbg_bus_tx_macproc, Dbg_bus_checksum_util};
`endif




`ifdef SIMULATION
    /* ------- Debug interface {begin}------- */
    /* | reserved | reserved | idx | end | out |
     * |  255:10  |   9:5    | 4:2 |  1  |  0  |
     */
    assign debug  = {
                            desc_table_qindex[desc_table_irq_finish_ptr[CL_DESC_TABLE_SIZE-1:0]],
                            desc_table_qnum[desc_table_irq_finish_ptr[CL_DESC_TABLE_SIZE-1:0]],
                            desc_table_qindex[desc_table_cpl_ptr[CL_DESC_TABLE_SIZE-1:0]],
                            desc_table_qnum[desc_table_cpl_ptr[CL_DESC_TABLE_SIZE-1:0]],
                            desc_table_qindex[desc_table_frame_trans_ptr[CL_DESC_TABLE_SIZE-1:0]],
                            desc_table_qnum[desc_table_frame_trans_ptr[CL_DESC_TABLE_SIZE-1:0]],
                            desc_table_qindex[desc_table_frame_req_ptr[CL_DESC_TABLE_SIZE-1:0]],
                            desc_table_qnum[desc_table_frame_req_ptr[CL_DESC_TABLE_SIZE-1:0]]
                           };
    /* ------- Debug interface {end}------- */
`endif

//ila_mac_fifo ila_mac_fifo_inst(
//    .clk(clk),
//    .probe0(fifo_wr),
//    .probe1({tx_frame_rsp_last, tx_frame_rsp_data}),
//    .probe2 (fifo_full),
//    .probe3(fifo_rd),
//    .probe4({axis_tx_last_fifo, axis_tx_data_fifo}),
//    .probe5(fifo_empty),
//    .probe6(empty_entry_num),
//    .probe7(tx_csum_fifo_empty),
//    .probe8(desc_table_frame_trans_ptr),
//    .probe9(desc_table_csum_ptr),
//    .probe10(desc_table_irq_finish_ptr),
//    .probe11(desc_table_queue_cpl_ptr),
//    .probe12(desc_table_frame_rsp_ptr),
//    .probe13(desc_table_start_ptr),
//    .probe14(desc_table_frame_req_ptr),
//    .probe15(desc_table_cpl_ptr),
//    .probe16(axis_tx_valid), 
//    .probe17(axis_tx_last),
//    .probe18(axis_tx_ready),
//    .probe19(axis_tx_start)    
//);

//ila_tx_desc_fetch ila_tx_cpl_inst(
//  .clk(clk),
//  .probe0(tx_axis_cpl_wr_valid),
//  .probe1(tx_axis_cpl_wr_last),
//  .probe2(tx_axis_cpl_wr_data),
//  .probe3(tx_axis_cpl_wr_head),
//  .probe4(tx_axis_cpl_wr_ready)
//);

//ila_tx_desc_rsp ila_tx_irq_inst(
//    .clk(clk),
//    .probe0(tx_axis_irq_valid),
//    .probe1(tx_axis_irq_last),
//    .probe2(tx_axis_irq_data),
//    .probe3(tx_axis_irq_head),
//    .probe4(tx_axis_irq_ready)
//);


endmodule

