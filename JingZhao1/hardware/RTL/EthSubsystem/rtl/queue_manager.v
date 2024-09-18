`timescale 1ns / 100ps
//*************************************************************************
// > File Name: queue_manager.v
// > Author   : Li jianxiong
// > Date     : 2021-10-12
// > Note     : queue_manager is used for manage the queue information
//              it connect the pio module and renew the queue info
//              when lan engine request for the desc, it return the 
//              queue addr and the queue index
//              TODO:  tx queue must wait the tx cpl queue has extra descriptor
// > V1.1 - 2021-10-21 : 
//*************************************************************************

module queue_manager #(  
  parameter QUEUE_COUNT = 32,
  /* the desc table size */
  parameter DESC_TABLE_SIZE = 128,

  /* axil parameter */
  parameter AXIL_ADDR_WIDTH = 32,

  parameter DEBUG_RX = 0
)
(
  input   wire clk,
  input   wire rst_n,

  /* from desc fetch, request for the queue information */
  input   wire [`QUEUE_NUMBER_WIDTH-1:0]      desc_dequeue_req_qnum,
  input   wire                               desc_dequeue_req_valid,
  output  wire                               desc_dequeue_req_ready,

  /* to  desc fetch */
  output  wire [`QUEUE_NUMBER_WIDTH-1:0]      desc_dequeue_resp_qnum,
  output  wire [`QUEUE_INDEX_WIDTH-1:0]       desc_dequeue_resp_qindex,
  output  wire [`DMA_ADDR_WIDTH-1:0]          desc_dequeue_resp_desc_addr,
  output  wire [`DMA_ADDR_WIDTH-1:0]          desc_dequeue_resp_cpl_addr,
  output  wire [`MSI_NUM_WIDTH-1:0]           desc_dequeue_resp_msi,
  output  wire [`STATUS_WIDTH-1:0]            desc_dequeue_resp_status,
  output  wire                                desc_dequeue_resp_valid,

  output  wire [`QUEUE_NUMBER_WIDTH-1:0]      doorbell_queue,
  output  wire                               doorbell_valid,

  /* input from len engine , finish cpl */
  input   wire [`QUEUE_NUMBER_WIDTH-1:0]      cpl_finish_qnum,
  input   wire                                cpl_finish_valid,
  output  wire                                cpl_finish_ready,

  /*axil write signal*/
  input   wire [AXIL_ADDR_WIDTH-1:0]            awaddr_queue,
  input   wire                                  awvalid_queue,
  output  wire                                  awready_queue,
  input   wire [`AXIL_DATA_WIDTH-1:0]            wdata_queue,
  input   wire [`AXIL_STRB_WIDTH-1:0]            wstrb_queue,
  input   wire                                  wvalid_queue,
  output  wire                                  wready_queue,
  output  wire                                  bvalid_queue,
  input   wire                                  bready_queue,
  /*axil read signal*/
  input   wire [AXIL_ADDR_WIDTH-1:0]            araddr_queue,
  input   wire                                  arvalid_queue,
  output  wire                                  arready_queue,
  output  wire [`AXIL_DATA_WIDTH-1:0]            rdata_queue,
  output  wire                                  rvalid_queue,
  input   wire                                  rready_queue

`ifdef ETH_CHIP_DEBUG
  // ,input 	  wire		[0 : 0] 		Rw_data
	// ,output 	wire 		[0 : 0] 		Ro_data
	,output 	wire 		[(`QUEUE_MANAGER_DEG_REG_NUM)  * 32 - 1 : 0]		  Dbg_bus
`endif
);

localparam LOG_QUEUE_SIZE_WIDTH  = 4;

localparam CL_QUEUE_COUNT            = $clog2(QUEUE_COUNT);
localparam QUEUE_RAM_BE_WIDTH  = 16;
localparam QUEUE_RAM_WIDTH     = QUEUE_RAM_BE_WIDTH*8;

localparam CL_DESC_SIZE         = $clog2(`DESC_SIZE);
localparam CL_CPL_SIZE         = $clog2(`CPL_SIZE);
/* -------axi state machane {begin}------- */
wire [AXIL_ADDR_WIDTH-1:0]           waddr;
wire [`AXIL_DATA_WIDTH-1:0]          wdata;
wire [`AXIL_STRB_WIDTH-1:0]          wstrb;
wire                                 wvalid;
wire                                 wready;

wire [AXIL_ADDR_WIDTH-1:0]            raddr;
wire                                  rvalid;
wire [`AXIL_DATA_WIDTH-1:0]           rdata;
wire                                  rready;

axi_convert #(
    /* axil parameter */
  .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH)
) 
axi_convert_inst
(
  .clk(clk),
  .rst_n(rst_n),

  /*axil write signal*/
  .awaddr_s(awaddr_queue),
  .awvalid_s(awvalid_queue),
  .awready_s(awready_queue),
  .wdata_s(wdata_queue),
  .wstrb_s(wstrb_queue),
  .wvalid_s(wvalid_queue),
  .wready_s(wready_queue),
  .bvalid_s(bvalid_queue),
  .bready_s(bready_queue),

  .waddr(waddr),
  .wdata(wdata),
  .wstrb(wstrb),
  .wvalid(wvalid),
  .wready(wready),

  /*axil read signal*/
  .araddr_s(araddr_queue),
  .arvalid_s(arvalid_queue),
  .arready_s(arready_queue),
  .rdata_s(rdata_queue),
  .rvalid_s(rvalid_queue),
  .rready_s(rready_queue),

  .raddr(raddr),
  .rvalid(rvalid),
  .rdata(rdata),
  .rready(rready)
);

wire axil_write_en;
wire axil_read_en;
wire dequeue_en;
wire cpl_finish_en;

/* -------queue ram operete register {begin}------- */
reg [`DMA_ADDR_WIDTH-1:0]         queue_addr_ram      [QUEUE_COUNT-1:0];
reg [LOG_QUEUE_SIZE_WIDTH-1:0]    queue_log_size_ram  [QUEUE_COUNT-1:0];
reg [1-1:0]                       queue_active_ram    [QUEUE_COUNT-1:0];
reg [`QUEUE_INDEX_WIDTH-1:0]      queue_cpl_num_ram   [QUEUE_COUNT-1:0];
reg [`QUEUE_INDEX_WIDTH-1:0]      queue_head_ptr_ram  [QUEUE_COUNT-1:0];
reg [`QUEUE_INDEX_WIDTH-1:0]      queue_tail_ptr_ram  [QUEUE_COUNT-1:0];

wire [`QUEUE_INDEX_WIDTH-1:0]     queue_ram_read_data_head_ptr;
wire [`QUEUE_INDEX_WIDTH-1:0]     queue_ram_read_data_tail_ptr;
wire [`QUEUE_INDEX_WIDTH-1:0]     queue_ram_read_data_cpl_queue;
wire [LOG_QUEUE_SIZE_WIDTH-1:0]   queue_ram_read_data_log_queue_size;
wire                              queue_ram_read_data_active;
wire [`DMA_ADDR_WIDTH-1:0]        queue_ram_read_data_base_addr;

wire queue_empty; /* is queue empty ?  */
/* -------queue ram operete register {end}------- */


/* -------cpl queue ram operate register {begin}------- */
reg [`DMA_ADDR_WIDTH-1:0]         cpl_queue_addr_ram      [QUEUE_COUNT-1:0];
reg [LOG_QUEUE_SIZE_WIDTH-1:0]    cpl_queue_log_size_ram  [QUEUE_COUNT-1:0];
reg                               cpl_queue_armed_ram     [QUEUE_COUNT-1:0];
reg [1-1:0]                       cpl_queue_active_ram    [QUEUE_COUNT-1:0];
reg [`MSI_NUM_WIDTH-1:0]          cpl_queue_msix_ram       [QUEUE_COUNT-1:0];
reg [`QUEUE_INDEX_WIDTH-1:0]      cpl_queue_head_ptr_ram  [QUEUE_COUNT-1:0];
reg [`QUEUE_INDEX_WIDTH-1:0]      cpl_queue_active_head_ptr_ram  [QUEUE_COUNT-1:0];
reg [`QUEUE_INDEX_WIDTH-1:0]      cpl_queue_tail_ptr_ram  [QUEUE_COUNT-1:0];

wire [`QUEUE_INDEX_WIDTH-1:0]           cpl_queue_ram_read_data_head_ptr;
wire [`QUEUE_INDEX_WIDTH-1:0]           cpl_queue_ram_read_data_active_head_ptr;
wire [`QUEUE_INDEX_WIDTH-1:0]           cpl_queue_ram_read_data_tail_ptr;
wire [`MSI_NUM_WIDTH-1:0]               cpl_queue_ram_read_data_msix;
wire [LOG_QUEUE_SIZE_WIDTH-1:0]         cpl_queue_ram_read_data_log_size;
wire                                    cpl_queue_ram_read_data_armed;
wire                                    cpl_queue_ram_read_data_active;
wire [`DMA_ADDR_WIDTH-1:0]              cpl_queue_ram_read_data_base_addr;

wire                                    cpl_queue_idle_full;
wire                                    cpl_queue_active_full;
wire                                    cpl_queue_full;

wire                                    queue_status;
/* -------cpl queue ram operate register {end}------- */

/* -------operation register {begin}------- */
wire [CL_QUEUE_COUNT-1:0]    queue_ram_ptr; // store queue_ram operate ptr

wire [CL_QUEUE_COUNT-1:0]    axil_queue;     /* axil lite operate queue */
wire [3:0]                    axil_reg_addr;  /* axil lite operate register addr */
/* -------operation register {end}------- */

/* axil write */
assign axil_write_en  = wvalid && wready;
/* axil read */
assign axil_read_en   = !axil_write_en && rvalid && rready;

assign wready = 1'b1;
assign rready = !axil_write_en;

assign queue_empty    = queue_ram_read_data_head_ptr == queue_ram_read_data_tail_ptr || !queue_ram_read_data_active;

assign cpl_queue_idle_full    = (($unsigned(cpl_queue_ram_read_data_head_ptr - cpl_queue_ram_read_data_tail_ptr) 
                                    & ({`QUEUE_INDEX_WIDTH{1'b1}} << cpl_queue_ram_read_data_log_size)) != 0) 
                                    || (!cpl_queue_ram_read_data_active);
assign cpl_queue_active_full  = (($unsigned(cpl_queue_ram_read_data_active_head_ptr - cpl_queue_ram_read_data_tail_ptr) 
                                    & ({`QUEUE_INDEX_WIDTH{1'b1}} << cpl_queue_ram_read_data_log_size)) != 0) 
                                    || (!cpl_queue_ram_read_data_active);

assign cpl_queue_full = cpl_queue_idle_full && cpl_queue_active_full;

assign queue_status = !queue_empty && !cpl_queue_full && cpl_queue_ram_read_data_armed;

/* get the axil operate queue */
assign axil_queue    = axil_write_en ? waddr >> 6 : axil_read_en  ? raddr >> 6 : 'b0;
assign axil_reg_addr = axil_write_en ? waddr >> 2 : axil_read_en  ? raddr >> 2 : 'b0;

/* get the operate queue number  */
assign queue_ram_ptr  = (axil_write_en || axil_read_en) ? axil_queue :  
                          dequeue_en ? desc_dequeue_req_qnum : 
                          cpl_finish_en ? cpl_finish_qnum : 'b0;
/* get the queue information from queue_ram */


/* get the detailed queue information */
assign queue_ram_read_data_head_ptr          = queue_head_ptr_ram[queue_ram_ptr];
assign queue_ram_read_data_tail_ptr          = queue_tail_ptr_ram[queue_ram_ptr];
assign queue_ram_read_data_cpl_queue         = queue_cpl_num_ram[queue_ram_ptr];
assign queue_ram_read_data_log_queue_size    = queue_log_size_ram[queue_ram_ptr];
assign queue_ram_read_data_active            = queue_active_ram[queue_ram_ptr];
assign queue_ram_read_data_base_addr         = queue_addr_ram[queue_ram_ptr];

assign cpl_queue_ram_read_data_head_ptr             = cpl_queue_head_ptr_ram[queue_ram_ptr];
assign cpl_queue_ram_read_data_active_head_ptr      = cpl_queue_active_head_ptr_ram[queue_ram_ptr];
assign cpl_queue_ram_read_data_tail_ptr             = cpl_queue_tail_ptr_ram[queue_ram_ptr];
assign cpl_queue_ram_read_data_msix                  = cpl_queue_msix_ram[queue_ram_ptr];
assign cpl_queue_ram_read_data_log_size             = cpl_queue_log_size_ram[queue_ram_ptr];
assign cpl_queue_ram_read_data_armed                = cpl_queue_armed_ram[queue_ram_ptr];
assign cpl_queue_ram_read_data_active               = cpl_queue_active_ram[queue_ram_ptr];
assign cpl_queue_ram_read_data_base_addr            = cpl_queue_addr_ram[queue_ram_ptr];

assign rdata   = /* queue ram read data*/
                            axil_reg_addr == 4'h0 ? queue_ram_read_data_base_addr[31:0] :
                            axil_reg_addr == 4'h1 ? queue_ram_read_data_base_addr[63:32] :
                            axil_reg_addr == 4'h2 ? {queue_ram_read_data_active, 15'b0, queue_ram_read_data_log_queue_size} :
                            axil_reg_addr == 4'h3 ? queue_ram_read_data_cpl_queue :
                            axil_reg_addr == 4'h4 ? queue_ram_read_data_head_ptr :
                            axil_reg_addr == 4'h6 ? queue_ram_read_data_tail_ptr :
                            /* cpl queue ram read data */
                            axil_reg_addr == 4'h8 ? cpl_queue_ram_read_data_base_addr[31:0] :
                            axil_reg_addr == 4'h9 ? cpl_queue_ram_read_data_base_addr[63:32] :
                            axil_reg_addr == 4'ha ? {cpl_queue_ram_read_data_active, 15'b0, cpl_queue_ram_read_data_log_size} :
                            axil_reg_addr == 4'hb ? {cpl_queue_ram_read_data_armed, 15'b0, cpl_queue_ram_read_data_msix} :
                            axil_reg_addr == 4'hc ? cpl_queue_ram_read_data_head_ptr :
                            axil_reg_addr == 4'he ? cpl_queue_ram_read_data_tail_ptr : 'b0;


/* queue ram format
  | base addr | active | block size | queue_size | cpl queue |  tail_ptr | head_ptr
  |  127:64   |  55    |  53:52     |    51:48   |  47:32    |   31:16   |   15:0
*/

/* pio register addr
  addr  |  register name  |   bit
  4'h0  |  lower addr     |   31:0
  4'h1  |  upper addr     |   31:0
  4'h2  |  queue_size     |   3:0
        |  block_size     |   9:8
        |  active         |   31:31
  4'h3  | cpl_queue size  |   15:0
  4'h4  |  header ptr     |   31:0
  4'h6  | tail ptr        |   31:0
 */

integer i;

always @(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    for(i = 0; i < QUEUE_COUNT; i = i + 1) begin:QUEUE_INIT
      queue_head_ptr_ram[i]     <= `TD 'b0;
      queue_cpl_num_ram[i]      <= `TD 'b0;
      queue_log_size_ram[i]     <= `TD 'b0;
      queue_active_ram[i]       <= `TD 'b0;
      queue_addr_ram[i]         <= `TD 'b0;
    end
  end else begin
    if(axil_write_en) begin
      case(axil_reg_addr) 
        4'h0: begin // low address
          if(!queue_ram_read_data_active) begin
            queue_addr_ram[queue_ram_ptr][31:0]   <= `TD wdata;
          end
        end
        4'h1:begin // upper address
          if(!queue_ram_read_data_active) begin
            queue_addr_ram[queue_ram_ptr][63:32]  <= `TD wdata;
          end
        end
        4'h2:begin // queue_size
          if(!queue_ram_read_data_active && wstrb[0]) begin
            queue_log_size_ram[queue_ram_ptr]     <= `TD wdata[LOG_QUEUE_SIZE_WIDTH-1:0];
          end
          if(wstrb[3]) begin // active 
            queue_active_ram[queue_ram_ptr]       <= `TD wdata[31];
          end
        end
        4'h3:begin // cpl queue number
          if(!queue_ram_read_data_active) begin
            queue_cpl_num_ram[queue_ram_ptr]     <= `TD wdata;
          end
        end
        4'h4:begin // head ptr
          queue_head_ptr_ram[queue_ram_ptr]     <= `TD wdata;
        end
      endcase
    end     
  end
end

integer n;
always @(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    for(n = 0; n < QUEUE_COUNT; n = n + 1) begin:QUEUE_INIT_TAIL
      queue_tail_ptr_ram[n]     <= `TD 'b0;
    end
  end else begin    
    // tail ptr
    if(axil_write_en && axil_reg_addr ==  4'h6 && !queue_ram_read_data_active) begin
      // if axil write and queue not active, change the tail ptr
      queue_tail_ptr_ram[queue_ram_ptr]     <= `TD wdata;
    end else if(dequeue_en) begin
      // when dequeue, the tail ptr self-increment
      if(queue_status) begin
        queue_tail_ptr_ram[queue_ram_ptr]     <= `TD queue_tail_ptr_ram[queue_ram_ptr] + 1;
      end
    end
  end
end

/* when change the header ptr, generate a doorbell */
assign doorbell_queue   = queue_ram_ptr;
assign doorbell_valid   = axil_write_en && axil_reg_addr == 4'h4 
                                &&  queue_ram_read_data_active && queue_head_ptr_ram[queue_ram_ptr] != wdata;

/* cpl_queue ram format
  | base addr | active | armed | continuous | queue_size | event id  |  tail_ptr | head_ptr
  |  127:64   |  55    |  53   |     54     |    51:48   |  47:32    |   31:16   |   15:0
*/

/* pio register addr
  addr  |  register name  |   bit
  4'h8  |  lower addr     |   31:0
  4'h9  |  upper addr     |   31:0
  4'ha  |  queue_size     |   3:0
        |  active         |   31:31
  4'hb  | interrupt num   |   15:0
        |   continuous    |   30:30
        |    armed        |   31:31
  4'hc  |  header ptr     |   31:0
  4'he  | tail ptr        |   31:0
 */
integer k;

always @(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    for(k = 0; k < QUEUE_COUNT; k = k + 1) begin:CPL_INIT
      cpl_queue_addr_ram[k]             <= `TD 'b0;  
      cpl_queue_log_size_ram[k]         <= `TD 'b0;  
      cpl_queue_armed_ram[k]            <= `TD 'b0; 
      cpl_queue_active_ram[k]           <= `TD 'b0;  
      cpl_queue_msix_ram[k]             <= `TD 'b0;  
      cpl_queue_tail_ptr_ram[k]         <= `TD 'b0;  
    end
  end else begin
    if(axil_write_en) begin
      case(axil_reg_addr) 
        4'h8: begin // low address
          if(!cpl_queue_ram_read_data_active) begin
            cpl_queue_addr_ram[queue_ram_ptr][31:0]   <= `TD wdata;
          end
        end
        4'h9:begin // upper address
          if(!cpl_queue_ram_read_data_active) begin
            cpl_queue_addr_ram[queue_ram_ptr][63:32]  <= `TD wdata;
          end
        end
        4'ha:begin // queue_size
          if(!cpl_queue_ram_read_data_active && wstrb[0]) begin
            cpl_queue_log_size_ram[queue_ram_ptr]     <= `TD wdata[LOG_QUEUE_SIZE_WIDTH-1:0];
          end
          if(wstrb[3]) begin // active 
            cpl_queue_active_ram[queue_ram_ptr]       <= `TD wdata[31];
          end
        end
        4'hb:begin // msi number
          if(!cpl_queue_ram_read_data_active) begin
            cpl_queue_msix_ram[queue_ram_ptr]        <= `TD wdata[15:0];
          end
          if(wstrb[3]) begin // armed 
            cpl_queue_armed_ram[queue_ram_ptr]      <= `TD wdata[31];
          end
        end
        4'he:begin // tail ptr
          cpl_queue_tail_ptr_ram[queue_ram_ptr]     <= `TD wdata;
        end
      endcase
    end 
  end
end

integer m;
always @(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    for(m = 0; m < QUEUE_COUNT; m = m + 1) begin:CPL_INIT_HEADER    
      cpl_queue_head_ptr_ram[m]         <= `TD 'b0;  
      cpl_queue_active_head_ptr_ram[m]  <= `TD 'b0; 
    end
  end else begin  
    // if axil write and queue not active, change the head ptr
    if(axil_write_en && axil_reg_addr ==  4'hc && !cpl_queue_ram_read_data_active) begin
      cpl_queue_head_ptr_ram[queue_ram_ptr]             <= `TD wdata;
      cpl_queue_active_head_ptr_ram[queue_ram_ptr]      <= `TD wdata;
    end else if (dequeue_en) begin
      if(queue_status) 
        cpl_queue_active_head_ptr_ram[queue_ram_ptr]     <= `TD cpl_queue_active_head_ptr_ram[queue_ram_ptr] + 1;
    // when finish cpl, the head ptr self-increment
    end else if(cpl_finish_en) begin      
      cpl_queue_head_ptr_ram[queue_ram_ptr]     <= `TD cpl_queue_head_ptr_ram[queue_ram_ptr] + 1;
    end
  end
end

/* queue request enable */
assign desc_dequeue_req_ready = !axil_write_en && !axil_read_en;

assign dequeue_en  = desc_dequeue_req_ready && desc_dequeue_req_valid;

/* the same cycle return the result  after desc_fetch module request*/ 
assign desc_dequeue_resp_qnum         = queue_ram_ptr;
assign desc_dequeue_resp_qindex       = queue_ram_read_data_tail_ptr;
// assign desc_dequeue_resp_qindex       = queue_ram_read_data_tail_ptr & ({`QUEUE_INDEX_WIDTH{1'b1}} >> (`QUEUE_INDEX_WIDTH - queue_ram_read_data_log_queue_size));
assign desc_dequeue_resp_desc_addr   = queue_ram_read_data_base_addr + ((queue_ram_read_data_tail_ptr & ({`QUEUE_INDEX_WIDTH{1'b1}} >> 
                                              (`QUEUE_INDEX_WIDTH -  queue_ram_read_data_log_queue_size))) << CL_DESC_SIZE);
assign desc_dequeue_resp_cpl_addr     = cpl_queue_ram_read_data_base_addr + ((cpl_queue_ram_read_data_active_head_ptr & ({`QUEUE_INDEX_WIDTH{1'b1}} >> 
                                              (`QUEUE_INDEX_WIDTH - cpl_queue_ram_read_data_log_size))) << CL_CPL_SIZE);
assign desc_dequeue_resp_msi          = cpl_queue_ram_read_data_msix;
assign desc_dequeue_resp_status       = (!queue_empty && !cpl_queue_full && cpl_queue_ram_read_data_armed) ? 8'hFF : 8'h0;
assign desc_dequeue_resp_valid        = dequeue_en;

assign desc_dequeue_resp_head_ptr      = queue_ram_read_data_head_ptr;
assign desc_dequeue_resp_tail_ptr      = queue_ram_read_data_tail_ptr;
assign desc_dequeue_resp_cpl_head_ptr  = cpl_queue_ram_read_data_head_ptr;
assign desc_dequeue_resp_cpl_tail_ptr  = cpl_queue_ram_read_data_tail_ptr;

assign cpl_finish_ready = !axil_write_en && !axil_read_en && !dequeue_en;

assign cpl_finish_en = cpl_finish_valid && cpl_finish_ready;



`ifdef ETH_CHIP_DEBUG

assign Dbg_bus = {// wire
                  28'b0,
                  desc_dequeue_req_qnum, desc_dequeue_req_valid, desc_dequeue_req_ready, desc_dequeue_resp_qnum, 
                  desc_dequeue_resp_qindex, desc_dequeue_resp_desc_addr, desc_dequeue_resp_cpl_addr, desc_dequeue_resp_msi, 
                  desc_dequeue_resp_head_ptr, desc_dequeue_resp_tail_ptr, desc_dequeue_resp_cpl_head_ptr, desc_dequeue_resp_cpl_tail_ptr, 
                  desc_dequeue_resp_status, desc_dequeue_resp_valid, doorbell_queue, doorbell_valid, cpl_finish_qnum, 
                  cpl_finish_valid, cpl_finish_ready, 
                  waddr, wdata, wstrb, wvalid, wready, raddr, rvalid, rdata, rready, axil_write_en, axil_read_en, dequeue_en, 
                  cpl_finish_en, queue_ram_read_data_head_ptr, queue_ram_read_data_tail_ptr, queue_ram_read_data_cpl_queue, 
                  queue_ram_read_data_log_queue_size, queue_ram_read_data_active, queue_ram_read_data_base_addr, 
                  queue_empty, cpl_queue_ram_read_data_head_ptr, cpl_queue_ram_read_data_active_head_ptr, 
                  cpl_queue_ram_read_data_tail_ptr, cpl_queue_ram_read_data_msix, cpl_queue_ram_read_data_log_size, 
                  cpl_queue_ram_read_data_armed, cpl_queue_ram_read_data_active, cpl_queue_ram_read_data_base_addr, 
                  cpl_queue_idle_full, cpl_queue_active_full, cpl_queue_full, queue_status,  
                  queue_ram_ptr, axil_queue, axil_reg_addr
                  // reg
                  
                  } ;

`endif




endmodule