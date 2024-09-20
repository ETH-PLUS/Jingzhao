//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: tptmdata.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V0.0 
// VERSION DESCRIPTION: 1st Edition  
//----------------------------------------------------
// RELEASE DATE: 2020-10-15
//---------------------------------------------------- 
// PURPOSE: store and operate on tptmetadata.
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
// 
//-FHDR-----------------------------------------------

//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_v2p_h.vh"

module mttm_proc#(
    parameter  TPT_HD_WIDTH  = 99,//for MTT-mttmdata req header fifo
    parameter  DMA_RD_HD_WIDTH  = 163,//for Mdata-DMA Read req header fifo
    parameter  DMA_WR_HD_WIDTH  = 99,//for Mdata-DMA Write req header fifo
    parameter  CEU_HD_WIDTH  = 104,//for ceu_tptm_proc to mttmdata req header fifo
    parameter  MTTM_RAM_DWIDTH = 52,//mttmdata RAM data width
    parameter  MTTM_RAM_AWIDTH = 9,//mttmdata RAM addr width
    parameter  MTTM_RAM_DEPTH  = 512 //mttmdata RAM depth
    )(
    input clk,
    input rst,
    /*Spyglass*/
    //input  wire                    mttm_start,
    /*Action = Delete*/
    
    output wire                    mttm_finish,

	input 	wire 											global_mem_init_finish,
	input	wire 											init_wea,
	input	wire 	[`V2P_MEM_MAX_ADDR_WIDTH - 1 : 0]		init_addra,
	input	wire 	[`V2P_MEM_MAX_DIN_WIDTH - 1 : 0]		init_dina,

    //mttmdata request from ceu_tptm_proc
    output wire                      mttm_req_rd_en,
    input  wire  [CEU_HD_WIDTH-1:0]  mttm_req_dout, 
    input  wire                      mttm_req_empty,
    //mttmdata payload from ceu_tptm_proc
    output wire                      mttm_rd_en,
    input  wire  [`DT_WIDTH-1:0]     mttm_dout, 
    input  wire                      mttm_empty,
    //MTT Request interface
    output wire                        mtt_req_rd_en,
    input  wire  [TPT_HD_WIDTH-1:0]    mtt_req_dout,
    input  wire                        mtt_req_empty,  
    //MTT get mtt_base for compute index in mtt_ram
    output wire  [63:0]                mtt_base_addr,    
    //DMA Read Ctx Request interface
    input  wire                           dma_rd_mtt_req_rd_en,
    output wire  [DMA_RD_HD_WIDTH-1:0]    dma_rd_mtt_req_dout,
    output wire                           dma_rd_mtt_req_empty,
    //DMA Write Ctx Request interface
    input  wire                           dma_wr_mtt_req_rd_en,
    output wire  [DMA_WR_HD_WIDTH-1:0]    dma_wr_mtt_req_dout,
    output wire                           dma_wr_mtt_req_empty 
    `ifdef V2P_DUG
    //apb_slave
        ,  input wire [`MTTM_DBG_RW_NUM * 32 - 1 : 0]   rw_data
        ,  output wire [`MTTM_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mttm
    `endif

);
/*************** RAM init control begin ****************/
reg		ram_init_finish;
always @(posedge clk or posedge rst) begin
	if(rst) begin
		ram_init_finish <= 'd0;
	end
	else if(global_mem_init_finish) begin
		ram_init_finish <= 1'b1;
	end 
	else begin
		ram_init_finish <= ram_init_finish;
	end 
end 
/*************** RAM init control finish ***************/

//DMA Read Ctx Request interface
wire                        dma_rd_mtt_req_prog_full;
reg                         dma_rd_mtt_req_wr_en;
wire  [DMA_RD_HD_WIDTH-1 :0]   dma_rd_mtt_req_din;

//DMA Write Ctx Request interface
wire                        dma_wr_mtt_req_prog_full;
reg                         dma_wr_mtt_req_wr_en;
wire  [DMA_WR_HD_WIDTH-1 :0]   dma_wr_mtt_req_din;

//DMA Read Ctx Request interface FIFO
dma_rd_mpt_req_fifo_163w32d dma_rd_mtt_req_fifo_163w32d_Inst(
    .clk        (clk),
    .srst       (rst),
    .wr_en      (dma_rd_mtt_req_wr_en),
    .rd_en      (dma_rd_mtt_req_rd_en),
    .din        (dma_rd_mtt_req_din),
    .dout       (dma_rd_mtt_req_dout),
    .full       (),
    .empty      (dma_rd_mtt_req_empty),     
    .prog_full  (dma_rd_mtt_req_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[0 * 32 +: 1 * 32])        
    `endif
); 

//DMA Write Ctx Request interface FIFO
dma_wr_mpt_req_fifo_99w32d dma_wr_mtt_req_fifo_99w32d_Inst(
    .clk        (clk),
    .srst       (rst),
    .wr_en      (dma_wr_mtt_req_wr_en),
    .rd_en      (dma_wr_mtt_req_rd_en),
    .din        (dma_wr_mtt_req_din),
    .dout       (dma_wr_mtt_req_dout),
    .full       (),
    .empty      (dma_wr_mtt_req_empty),     
    .prog_full  (dma_wr_mtt_req_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[1 * 32 +: 1 * 32])        
    `endif
); 

//use singledualportram to instantiate MTTMdata RAM 
reg                              wr_en; 
reg    [MTTM_RAM_AWIDTH-1 : 0]   wr_addr;
reg    [MTTM_RAM_DWIDTH-1 : 0]   wr_data;
/*VCS Verification*/
reg                           q_rd_en;
/*Action = Add, Use wire(reg varibales wire logic) to enable bram read signal, keep the reg data to judge dma wr_en*/
reg                              rd_en;
reg    [MTTM_RAM_AWIDTH-1 : 0]   rd_addr;
wire   [MTTM_RAM_DWIDTH-1 : 0]   rd_data;
wire                             ram_rst;
reg    valid_array[MTTM_RAM_DEPTH-1 : 0] ;//valid flag

bram_mttm_52w512d_simdaulp mttm_ram(
    .clka     (clk),
    .ena      (ram_init_finish ? wr_en : init_wea),
    .wea      (ram_init_finish ? wr_en : init_wea),
    .addra    (ram_init_finish ? wr_addr : init_addra[MTTM_RAM_AWIDTH - 1: 0]),
    .dina     (ram_init_finish ? wr_data : init_dina[MTTM_RAM_DWIDTH - 1 : 0]),
    .clkb     (clk),
    /*VCS Verification*/
    // .enb      (rd_en),
    .enb      (q_rd_en),
    .addrb    (rd_addr),
    /*Action = Modify, Use wire to enable bram read signal, keep the reg data to judge dma wr_en*/
    .doutb    (rd_data)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[2 * 32 +: 1 * 32])        
    `endif
);

//mttm_proc sub_module finish
reg  q_mttm_finish;
assign mttm_finish = q_mttm_finish;

/*************************state mechine 1 for ceu_tptm_proc req****************************/
//registers
reg [2:0] ceu_fsm_cs;
reg [2:0] ceu_fsm_ns;

//state machine localparams
//IDLE
localparam CEU_IDLE    = 3'b001;
//ACCESS: access mttmdata RAM, including INIT HCA, CLOSE HCA, ICM MAP, ICM UNMAP. 
localparam CEU_ACCESS  = 3'b010;
//PAYLOAD: read ceu_tptm_proc payload and put them into mttm ram
localparam CEU_PAYLOAD = 3'b100;

reg  [CEU_HD_WIDTH-1:0]   qv_tmp_ceu_req_header;
reg  [`DT_WIDTH-1:0]      qv_tmp_ceu_payload;
wire ceu_has_payload;
wire ceu_no_payload;

// chunk num means the chunk num in 1 request, 1 payload may have 2 chunk
wire  [31:0] chunk_num;
reg   [31:0] chunk_cnt;
// we can compute payload num refering to chunk num
// chunk_num % 2 + chunk_num / 2 = payload_num 
reg  [31:0]  payload_cnt;
reg  [31:0]  payload_num;
// page_num means that the page number in 1 chunk
wire [11:0] page_num;
reg  [11:0] page_cnt;


//-----------------Stage 1 :State Register----------
always @(posedge clk or posedge rst) begin
    if(rst)
        ceu_fsm_cs <= `TD CEU_IDLE;
    else
        ceu_fsm_cs <= `TD ceu_fsm_ns;
end
//-----------------Stage 2 :State Transition----------
always @(*) begin
    case (ceu_fsm_cs)
        CEU_IDLE: begin
            if(!mttm_req_empty) begin
                ceu_fsm_ns = CEU_ACCESS;
            end
            else
                ceu_fsm_ns = CEU_IDLE;
        end 
        CEU_ACCESS: begin
            if (ceu_no_payload && mttm_req_empty) begin
                ceu_fsm_ns = CEU_IDLE;
            end
            else if (ceu_has_payload && !mttm_empty) begin
                ceu_fsm_ns = CEU_PAYLOAD;
            end else begin
                ceu_fsm_ns = CEU_ACCESS;
            end
        end
        CEU_PAYLOAD: begin
            if ((payload_cnt == payload_num) && (chunk_cnt == chunk_num) && (page_cnt == page_num) && mttm_req_empty) begin
                ceu_fsm_ns = CEU_IDLE;
            end else if ((payload_cnt == payload_num) && (chunk_cnt == chunk_num) && (page_cnt == page_num) && !mttm_req_empty) begin
                ceu_fsm_ns = CEU_ACCESS;
            end else begin
                ceu_fsm_ns = CEU_PAYLOAD;
            end
        end
        default: ceu_fsm_ns = CEU_IDLE;
    endcase
end

//-----------------Stage 3 :Output Decode----------
assign ceu_has_payload = (mttm_req_dout[103:100] == `MAP_ICM_TPT) &&
                         (mttm_req_dout[99:96] == `MAP_ICM_EN_V2P);

assign ceu_no_payload = ((mttm_req_dout[103:100] == `WR_ICMMAP_TPT) &&
                          (mttm_req_dout[99:96] == `WR_ICMMAP_EN_V2P)) ||
                         ((mttm_req_dout[103:100] == `WR_ICMMAP_TPT) &&
                          (mttm_req_dout[99:96] == `WR_ICMMAP_DIS_V2P)) ||
                         ((mttm_req_dout[103:100] == `MAP_ICM_TPT) &&
                          (mttm_req_dout[99:96] == `MAP_ICM_DIS_V2P));

// output wire   mttm_req_rd_en; 
// form ceu_tptm_proc req 
reg  q_mttm_req_rd_en;
/*VCS Verification*/
assign mttm_req_rd_en = q_mttm_req_rd_en & !mttm_req_empty;
/*Action = Modify, add & !mttm_req_empty*/
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_mttm_req_rd_en <= `TD 0;
    end else begin
        case (ceu_fsm_cs)
            CEU_IDLE: begin
                if (!mttm_req_empty) begin
                    q_mttm_req_rd_en <= `TD 1;
                end else begin
                    q_mttm_req_rd_en <= `TD 0;
                end
            end 
            CEU_ACCESS: begin
                if (ceu_no_payload && !mttm_req_empty) begin
                    q_mttm_req_rd_en <= `TD 1;
                end else begin
                    q_mttm_req_rd_en <= `TD 0;
                end
            end
            CEU_PAYLOAD: begin
                if ((payload_cnt == payload_num) && (chunk_cnt == chunk_num) && (page_cnt == page_num) && !mttm_req_empty) begin
                    q_mttm_req_rd_en <= `TD 1;
                end else begin
                    q_mttm_req_rd_en <= `TD 0;
                end
            end
            default: q_mttm_req_rd_en <= `TD 0;
        endcase
    end
end

// reg  [31:0]  payload_cnt;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        payload_cnt <= `TD 0;
    end
    // when the chunk_cnt < chunk_num, payload_cnt < payload_num, chunk_cnt is even, and page_cnt < page_num, 
    // that means the second chunk in the payload is processed completely and there are new payloads need processed.
    /*VCS Verification*/
    // else if (((payload_cnt < payload_num) || (payload_cnt == 0)) && (ceu_fsm_cs == CEU_PAYLOAD) && ((chunk_cnt < chunk_num) || (chunk_cnt == 0) ) && (!(chunk_cnt[0])) && (page_cnt == page_num) && !mptm_empty) begin
    else if (mttm_rd_en) begin
    /*Action = Modify, use read enable signal to update payload_cnt*/
        payload_cnt <= `TD payload_cnt + 1;
    end else if (ceu_fsm_cs == CEU_PAYLOAD) begin
        payload_cnt <= `TD payload_cnt;
    end else begin
        payload_cnt <= `TD 0;
    end 
end

// reg  [31:0]  payload_num; 
always @(*) begin
    // if chunk_num is odd, payload_num = chunk_num/2 +1;
    if ((ceu_fsm_cs == CEU_PAYLOAD) && qv_tmp_ceu_req_header[64]) begin
        payload_num = (qv_tmp_ceu_req_header[95:64] >> 1) + 1;
    end 
    // if chunk_num is even, payload_num = chunk_num/2 +1;
    else if ((ceu_fsm_cs == CEU_PAYLOAD) && !qv_tmp_ceu_req_header[64]) begin
        payload_num = qv_tmp_ceu_req_header[95:64] >> 1;
    end
    else
        payload_num = 0;
end

//reg  [CEU_HD_WIDTH-1:0] qv_tmp_ceu_req_header;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_tmp_ceu_req_header <= `TD 0;
    end else begin
        case (ceu_fsm_cs)
            CEU_IDLE: begin
                qv_tmp_ceu_req_header <= `TD 0;
            end 
            CEU_ACCESS: begin
                qv_tmp_ceu_req_header <= `TD mttm_req_dout;
            end
            CEU_PAYLOAD: begin
                qv_tmp_ceu_req_header <= `TD qv_tmp_ceu_req_header;
            end
            default: qv_tmp_ceu_req_header <= `TD 0;
        endcase
    end
end

// page_num; 
// if chunk_cnt is odd, page_num is the low 12 bit in low 128 payload;
// if chunk_cnt is even, page_num is the low 12 bit in high 128 payload;
assign page_num = ((ceu_fsm_cs == CEU_PAYLOAD) && (chunk_cnt[0] == 1)) ? qv_tmp_ceu_payload[11:0] : 
                   (((ceu_fsm_cs == CEU_PAYLOAD) && (chunk_cnt[0] == 0)) ? qv_tmp_ceu_payload[139:128]: 0);

// page_cnt ;//every chunk has page_num entries, we need page_num cycle to store them .
always @(posedge clk or posedge rst) begin
    if (rst) begin
        page_cnt <= `TD 0;
    end 
    else begin
        case (ceu_fsm_cs)
            CEU_IDLE: begin
                page_cnt <= `TD 0;
            end
            CEU_ACCESS: begin
                page_cnt <= `TD 0;
            end 
            CEU_PAYLOAD: begin
                /*VCS Verification*/
                // if (((page_cnt == 12'b0) && (page_num == 12'b0) && ((chunk_cnt < chunk_num) || (chunk_cnt == 0))) || ((page_cnt < page_num) && (chunk_cnt < chunk_num))) begin
                if (((page_cnt == 12'b0) && (page_num == 12'b0) && ((chunk_cnt < chunk_num) || (chunk_cnt == 0))) || ((page_cnt < page_num) && (chunk_cnt <= chunk_num))) begin
                    /*Action = Modify, chunk_cnt <= chunk_num*/
                    page_cnt <= `TD page_cnt + 1;
                end 
                else if ((page_cnt == page_num) && (chunk_cnt < chunk_num)) begin
                    page_cnt <= `TD 1;
                end else begin
                    page_cnt <= `TD page_cnt;
                end
            end
            default: page_cnt <= `TD 0;
        endcase
    end
end

// output wire    mttm_rd_en 
// form ceu_tptm_proc payload, ICM_MAP
reg q_mttm_rd_en;
assign mttm_rd_en = q_mttm_rd_en  && !mttm_empty;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_mttm_rd_en <= `TD 0;
    end else begin
        case (ceu_fsm_cs)
            CEU_IDLE: begin
               q_mttm_rd_en <= `TD 0;
            end 
            CEU_ACCESS: begin
                // in ACCESS state enable q_mttm_rd_en 1 time
                if (ceu_has_payload && !mttm_empty) begin
                    q_mttm_rd_en <= `TD 1;
                end else begin
                    q_mttm_rd_en <= `TD 0;
                end
            end
            CEU_PAYLOAD: begin
                // when 1 payload has been processed completely and there are still some payload in fifo, enable the q_mttm_rd_en
                /*VCS Verification*/
                // if (((payload_cnt < payload_num) || (payload_cnt == 0)) && !mttm_empty && ((chunk_cnt == 0) || (chunk_cnt < chunk_num)) && ((page_cnt == 0) || (page_cnt == page_num-1))) begin
                if ((chunk_cnt < chunk_num) && (payload_cnt < payload_num) && (page_cnt == page_num-1) && !chunk_cnt[0] && !mttm_empty) begin
                    /*Action = Modify, all page of 1 chunk process completely and chunk_cnt is even */                    
                    q_mttm_rd_en <= `TD 1;
                end else begin
                    q_mttm_rd_en <= `TD 0;
                end
            end
            default: q_mttm_rd_en <= `TD 0;
        endcase
    end
end

// reg  [`DT_WIDTH-1:0]      qv_tmp_ceu_payload;
// store ceu_paylaod for chunk1->page_num + chunk2->page_num cycle, because 1 payload may have 2 chunk
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_tmp_ceu_payload <= `TD 256'b0;
    end else begin
        case (ceu_fsm_cs)
            CEU_IDLE: begin
                qv_tmp_ceu_payload <= `TD 256'b0;
            end
            CEU_ACCESS: begin
                qv_tmp_ceu_payload <= `TD 256'b0;
            end 
            CEU_PAYLOAD: begin
                // 1 cycle behind mptm_rd_en signal, payload_cnt has increased
                /*VCS Verification*/
                // if ( ((payload_cnt == 0) && (chunk_cnt == 0) && (page_cnt == 0)) || ((payload_cnt < payload_num) && (chunk_cnt < chunk_num) && (page_cnt == page_num)) ) begin
                    if (mttm_rd_en) begin
                    /*Action = Modify, use read enable signal to update payload_cnt*/
                    qv_tmp_ceu_payload <= `TD mttm_dout;
                end else begin
                    qv_tmp_ceu_payload <= `TD qv_tmp_ceu_payload;
                end
            end
            default: qv_tmp_ceu_payload <= `TD 256'b0;
        endcase
    end
end

// chunk_num, extract chunk num from header
assign chunk_num = qv_tmp_ceu_req_header[95:64];
// chunk_cnt, count for chunk (1 payload may have 2 chunk)
always @(posedge clk or posedge rst) begin
    if (rst) begin
        chunk_cnt <= `TD 32'b0;
    end 
    else begin
        case (ceu_fsm_cs)
            CEU_IDLE: begin
                chunk_cnt <= `TD 32'b0;
            end
            CEU_ACCESS: begin
                chunk_cnt <= `TD 32'b0;
            end
            CEU_PAYLOAD: begin
                // the first cycle in PAYLOAD state or all pages in 1 chunk have been processed completely, chunk_cnt increases
                if (((chunk_cnt == 0) && (payload_cnt == 0) && (page_cnt == 0)) || ((chunk_cnt < chunk_num) && (payload_cnt <= payload_num) && (page_cnt == page_num))) begin
                    chunk_cnt <= `TD chunk_cnt + 1;
                end else begin
                    chunk_cnt <= `TD chunk_cnt;
                end
            end
            default: chunk_cnt <= `TD 32'b0;
        endcase
    end
end

// ram_rst
reg    q_ram_rst;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_ram_rst <= `TD 1;
    end 
    else begin
        case (ceu_fsm_cs)
            CEU_IDLE: begin
                q_ram_rst <= `TD 0;
            end
            CEU_ACCESS: begin
                case (mttm_req_dout[103:96])
                    // INIT HCA, reset
                    {`WR_ICMMAP_TPT,`WR_ICMMAP_EN_V2P}:begin
                        q_ram_rst <= `TD 1;
                    end
                    // ClOSE HCA, reset
                    {`WR_ICMMAP_TPT,`WR_ICMMAP_DIS_V2P}: begin
                        q_ram_rst <= `TD 1;
                    end 
                    // ICM UNMAP, don't reset, just change the value of valid array
                    {`MAP_ICM_TPT,`MAP_ICM_DIS_V2P}:begin
                        q_ram_rst <= `TD 0;
                    end
                    default: q_ram_rst <= `TD 0;
                endcase
            end
            CEU_PAYLOAD: begin
                q_ram_rst <= `TD 0;
            end 
            default: q_ram_rst <= `TD 0;
        endcase
    end   
end
assign ram_rst = rst || q_ram_rst;


//low 64: mtt_base;
reg [63:0] mtt_base;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mtt_base <= `TD 0;
    end 
    else begin
        case (ceu_fsm_cs)
            CEU_IDLE: begin
                mtt_base <= `TD mtt_base;
            end
            CEU_ACCESS: begin
                case (mttm_req_dout[103:96])
                    {`WR_ICMMAP_TPT,`WR_ICMMAP_EN_V2P}:begin
                        mtt_base <= `TD mttm_req_dout[63:0];
                    end
                    {`WR_ICMMAP_TPT,`WR_ICMMAP_DIS_V2P}: begin
                        mtt_base <= `TD 0;
                    end 
                    {`MAP_ICM_TPT,`MAP_ICM_DIS_V2P}:begin
                        mtt_base <= `TD mtt_base;
                    end
                    default: begin
                        mtt_base <= `TD mtt_base;
                    end
                endcase
            end
            CEU_PAYLOAD: begin
                mtt_base <= `TD mtt_base;
            end 
            default:  begin
                mtt_base <= `TD mtt_base;
            end
        endcase
    end   
end
// output wire  [63:0]                mtt_base_addr,    
assign   mtt_base_addr = mtt_base;


//reg   [MTTM_RAM_DEPTH-1 : 0]  valid_array;
wire [63:0]  unmap_addr;  //valid_array addr = (virt addr - mtt_base)[20:12];
wire [63:0]  map_low_addr;//ram_array addr = (virt addr in 127:64 payload - mtt_base)[20:12];
wire [63:0]  map_high_addr;//ram_array addr = (virt addr in 255:192 payload - mtt_base)[20:12];
assign unmap_addr    = mttm_req_dout[63:0] - mtt_base;
//first cycle read from fifo_dout, else read from tmp_ceu_payload
/*VCS Verification*/
// assign map_low_addr  =  (page_cnt == 0) ? (mttm_dout[127:64] - mtt_base) : (qv_tmp_ceu_payload[127:64] - mtt_base);
assign map_low_addr  =  (mttm_rd_en) ? (mttm_dout[127:64] - mtt_base) : (qv_tmp_ceu_payload[127:64] - mtt_base);
/*Action = Modify, use read enable signal to choose dout or reg to update addr*/
assign map_high_addr = qv_tmp_ceu_payload[255:192] - mtt_base;//read from tmp_paylaod reg
integer i;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        for(i = 0; i < MTTM_RAM_DEPTH; i = i + 1) begin
            valid_array[i] <= `TD 0;
        end
    end else begin
        case (ceu_fsm_cs)
            CEU_IDLE: begin
                for(i = 0; i < MTTM_RAM_DEPTH; i = i + 1) begin
                    valid_array[i] <= `TD valid_array[i];           
                end
            end
            CEU_ACCESS: begin
                case (mttm_req_dout[103:96])
                    {`WR_ICMMAP_TPT,`WR_ICMMAP_EN_V2P}:begin
                        // invalid all entry
                        for(i = 0; i < MTTM_RAM_DEPTH; i = i + 1) begin
                            valid_array[i] <= `TD 0;
                        end                      
                    end
                    {`WR_ICMMAP_TPT,`WR_ICMMAP_DIS_V2P}: begin
                        // invalid all entry
                        for(i = 0; i < MTTM_RAM_DEPTH; i = i + 1) begin
                            valid_array[i] <= `TD 0;
                        end   
                    end 
                    {`MAP_ICM_TPT,`MAP_ICM_DIS_V2P}:begin
                        // unmap cmd, invalid the correspond entry bit
                        /*Spyglass*/
                        //for(i = 0; i < mttm_req_dout[72:64]; i = i + 1) begin
                        //    valid_array[unmap_addr[20:12] + i] <= `TD 0;
                        //end
                        for(i = 0; i < MTTM_RAM_DEPTH; i = i + 1) begin
                            if ((i < unmap_addr[20:12] + mttm_req_dout[72:64]) && (i >= unmap_addr[20:12])) begin
                                valid_array[i] <= `TD 0;
                            end else begin
                                valid_array[i] <= `TD valid_array[i];
                            end
                        end
                        /*Action = Modify*/
                    end
                    default: begin
                        for(i = 0; i < MTTM_RAM_DEPTH; i = i + 1) begin
                            valid_array[i] <= `TD valid_array[i];           
                        end
                    end 
                endcase
            end
            CEU_PAYLOAD: begin
                // the first chunk of 1 payload processing stage, use the low 128 bits
                if (((chunk_cnt == 0) && (payload_cnt == 0) && (page_cnt == 0)) || (((chunk_cnt < chunk_num) || (chunk_cnt == chunk_num)) && (page_cnt < page_num) && (chunk_cnt[0] == 1)) ) begin
                    valid_array[map_low_addr[20:12] + page_cnt[MTTM_RAM_AWIDTH-1:0]] <= `TD 1;
                end 
                else if ((chunk_cnt < chunk_num) && (page_cnt == page_num) && (chunk_cnt[0] == 0)) begin
                    valid_array[map_low_addr[20:12]] <= `TD 1;
                end 
                else if ((chunk_cnt < chunk_num) && (page_cnt == page_num) && (chunk_cnt[0] == 1)) begin
                    valid_array[map_high_addr[20:12]] <= `TD 1;
                end
                else if (((chunk_cnt < chunk_num) || (chunk_cnt == chunk_num)) && (page_cnt < page_num) && (chunk_cnt[0] == 0)) begin
                    valid_array[map_high_addr[20:12] + page_cnt[MTTM_RAM_AWIDTH-1:0]] <= `TD 1;
                end
                else begin
                    for(i = 0; i < MTTM_RAM_DEPTH; i = i + 1) begin
                    valid_array[i] <= `TD valid_array[i];           
                end
                end
            end 
            default: begin
                for(i = 0; i < MTTM_RAM_DEPTH; i = i + 1) begin
                    valid_array[i] <= `TD valid_array[i];           
                end
            end
        endcase
    end
end

// reg       wr_en; 
// write enable to mttmdata RAM
always @(posedge clk or posedge rst) begin
    if (rst) begin
        wr_en <= `TD 0;
    end
    else begin
        case (ceu_fsm_cs)
            CEU_IDLE: begin
                wr_en <= `TD 0;
            end
            CEU_ACCESS: begin
                wr_en <= `TD 0;
            end
            CEU_PAYLOAD: begin
                if ( ((chunk_cnt == 0) && (payload_cnt == 0) && (page_cnt == 0)) || (chunk_cnt < chunk_num) || ((chunk_cnt == chunk_num) && (page_cnt < page_num)) ) begin
                    wr_en <= `TD 1;
                end else begin
                    wr_en <= `TD 0;
                end
            end 
            default: wr_en <= `TD 0;
        endcase
    end   
end
 
// reg    [MTTM_RAM_AWIDTH-1 : 0]   wr_addr; 
// write addr to mttmdata RAM
always @(posedge clk or posedge rst) begin
    if (rst) begin
        wr_addr <= `TD 0;
    end else begin
        case (ceu_fsm_cs)
            CEU_IDLE: begin
                wr_addr <= `TD 0;
            end
            CEU_ACCESS: begin
                wr_addr <= `TD 0;
            end
            CEU_PAYLOAD: begin
                // when the first chunk in the payload is being processed, write to the address based on the low_addr info
                if (((chunk_cnt == 0) && (payload_cnt == 0) && (page_cnt == 0)) || ((chunk_cnt <= chunk_num) && (page_cnt < page_num) && (chunk_cnt[0] == 1)) ) begin
                    //use the page_cnt + base_addr to calculate the entry addr
                    wr_addr <= `TD map_low_addr[20:12] + page_cnt[MTTM_RAM_AWIDTH-1:0];
                end
                // when the second chunk in the payload is processed completely, next cycle write to the address based on the low_addr info
                else if ((chunk_cnt < chunk_num) && (page_cnt == page_num) && (chunk_cnt[0] == 0)) begin
                    wr_addr <= `TD map_low_addr[20:12];
                end
                // when the first chunk in the payload is processed completely, next cycle write to the address based on the high_addr info 
                else if ((chunk_cnt < chunk_num) && (page_cnt == page_num) && (chunk_cnt[0] == 1)) begin
                    wr_addr <= `TD map_high_addr[20:12];
                end
                // when the second chunk in the payload is being processed, write to the address based on the high_addr info
                else if ((chunk_cnt <= chunk_num) && (page_cnt < page_num) && (chunk_cnt[0] == 0)) begin
                    wr_addr <= `TD map_high_addr[20:12] + page_cnt[MTTM_RAM_AWIDTH-1:0];
                end
                else begin
                    wr_addr <= `TD 0;
                end
            end
            default: wr_addr <= `TD 0;
        endcase
    end
end
 
// reg    [MTTM_RAM_AWIDTH-1 : 0]   wr_data;
// write data to mttmdata RAM, if 1 chunk has more than 1 page_num, each page has 1 entry
// we compute the physical addr by adding 1 (because page size=4KB and we don't store the low 12 bit)
always @(posedge clk or posedge rst) begin
    if (rst) begin
        wr_data <= `TD 0;
    end else begin
        case (ceu_fsm_cs)
            CEU_IDLE: begin
                wr_data <= `TD 0;
            end 
            CEU_ACCESS: begin
                wr_data <= `TD 0;
            end
            CEU_PAYLOAD: begin
                // when the first chunk in the new payload is first being processed, write the physical address based on the low_phy_addr info from mttm_dout
                if (((chunk_cnt == 0) && (payload_cnt == 0) && (page_cnt == 0)) || ((chunk_cnt < chunk_num) && (page_cnt == page_num) && (chunk_cnt[0] == 0)) ) begin
                    wr_data <= `TD mttm_dout[63:12];
                end
                // when the first chunk in the payload is being processed, write the physical address based on the low_phy_addr info from tmp reg
                else if ((chunk_cnt <= chunk_num) && (page_cnt < page_num) && (chunk_cnt[0] == 1)) begin
                    //use the page_cnt + phy addr in payload to calculate the entry physical addr
                    wr_data <= `TD qv_tmp_ceu_payload[63:12] + {40'b0,page_cnt};
                end
                // when the first chunk in the payload is processed completely, next cycle write the physical address based on the high_phy_addr info from mttm_dout
                else if ((chunk_cnt < chunk_num) && (page_cnt == page_num) && (chunk_cnt[0] == 1)) begin
                    /*VCS Verification*/
                    // wr_data <= `TD mttm_dout[191:140];
                    wr_data <= `TD qv_tmp_ceu_payload[191:140];
                    /*Action = Modify, use reg to extract data;*/
                end
                // when the second chunk in the payload is being processed, write the physical address based on the high_phy_addr info from tmp reg
                else if ((chunk_cnt <= chunk_num) && (page_cnt < page_num) && (chunk_cnt[0] == 0)) begin
                    //use the page_cnt + phy addr in payload to calculate the entry physical addr
                    wr_data <= `TD qv_tmp_ceu_payload[191:140] + {40'b0,page_cnt};
                end
                else begin
                    wr_data <= `TD 0;
                end
            end
            default:  wr_data <= `TD 0;
        endcase
    end
end


/*************************state mechine 2 for MTT req****************************/
//registers
reg [2:0] mtt_fsm_cs;
reg [2:0] mtt_fsm_ns;
//state machine localparams
//IDLE
localparam MTT_IDLE    = 3'b001;
//ACCESS: access mttmdata RAM, Read mttm entry for next DMA_REQ state. 
localparam MTT_ACCESS  = 3'b010;
//DMA_REQ: initiate dma read/write request according to the mttmdata
localparam MTT_DMA_REQ = 3'b100;

wire dest_dma_req_prog_full;
reg  [TPT_HD_WIDTH-1:0]   qv_tmp_mtt_req_header;
wire [19:0]  wv_req_num;
reg  [19:0]  qv_req_cnt;


//-----------------Stage 1 :State Register----------
always @(posedge clk or posedge rst) begin
    if(rst)
        mtt_fsm_cs <= `TD MTT_IDLE;
    else
        mtt_fsm_cs <= `TD mtt_fsm_ns;
end
//-----------------Stage 2 :State Transition----------
always @(*) begin
    case (mtt_fsm_cs)
        MTT_IDLE: begin
            if(!mtt_req_empty) begin
                mtt_fsm_ns = MTT_ACCESS;
            end
            else
                mtt_fsm_ns = MTT_IDLE;
        end 
        MTT_ACCESS: begin
            if (!dest_dma_req_prog_full) begin
                mtt_fsm_ns = MTT_DMA_REQ;    
            end
            else
                mtt_fsm_ns = MTT_ACCESS;
        end
        MTT_DMA_REQ: begin
            // todo: add condition for finishing req transfer? No, only 1 cycle to transfer dma req header
            if ((qv_req_cnt == wv_req_num) && !mtt_req_empty) begin
                mtt_fsm_ns = MTT_ACCESS;
            end 
            else if ((qv_req_cnt == wv_req_num) && mtt_req_empty) begin
                mtt_fsm_ns = MTT_IDLE;
            end
            else
                mtt_fsm_ns = MTT_DMA_REQ;
        end
        default: mtt_fsm_ns = MTT_IDLE;
    endcase
end

//-----------------Stage 3 :Output Decode----------

// output wire    mtt_req_rd_en 
// from MTT req to read/write from/to host MTT data
reg q_mtt_req_rd_en;
assign mtt_req_rd_en = q_mtt_req_rd_en && !mtt_req_empty;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_mtt_req_rd_en <= `TD 0;
    end else begin
        case (mtt_fsm_cs)
            MTT_IDLE: begin
                if (!mtt_req_empty) begin
                    q_mtt_req_rd_en <= `TD 1;
                end else begin
                    q_mtt_req_rd_en <= `TD 0;
                end
            end
            MTT_ACCESS: begin
                q_mtt_req_rd_en <= `TD 0;
            end
            MTT_DMA_REQ: begin
                if ((qv_req_cnt == wv_req_num) && !mtt_req_empty) begin
                    q_mtt_req_rd_en <= `TD 1;
                end
                else begin
                    q_mtt_req_rd_en <= `TD 0;
                end
            end
            default: q_mtt_req_rd_en <= `TD 0;
        endcase
    end
end
 
//reg  [TPT_HD_WIDTH-1:0] qv_tmp_mtt_req_header;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_tmp_mtt_req_header <= `TD 0;
    end else begin
        case (mtt_fsm_cs)
            MTT_IDLE: begin
                qv_tmp_mtt_req_header <= `TD 0;
            end 
            MTT_ACCESS: begin
                if (q_mtt_req_rd_en) begin
                    qv_tmp_mtt_req_header <= `TD mtt_req_dout;
                end else begin
                    qv_tmp_mtt_req_header <= `TD qv_tmp_mtt_req_header;
                end
            end
            MTT_DMA_REQ: begin
                qv_tmp_mtt_req_header <= `TD qv_tmp_mtt_req_header;
            end
            default: qv_tmp_mtt_req_header <= `TD 0;
        endcase
    end
end

// wire  dest_dma_req_prog_full;
// MTT_ACCESS state, use mtt_req_dout "opcode" seg to select dest_fifo
// MTT_DMA_REQ state, use qv_tmp_mtt_req_header "opcode" seg to select dest_fifo
// `MTT_RD             --------- dma_rd_mtt_req_fifo
// `MTT_WR and `MTT_IN --------- dma_wr_mtt_req_fifo
assign dest_dma_req_prog_full = (((mtt_fsm_cs == MTT_ACCESS) && (mtt_req_dout[98:96] == `MTT_RD)) || 
                                 ((mtt_fsm_cs == MTT_DMA_REQ) && (qv_tmp_mtt_req_header[98:96] == `MTT_RD))) ? dma_rd_mtt_req_prog_full : 
                                 ((((mtt_fsm_cs == MTT_ACCESS) && ((mtt_req_dout[98:96] == `MTT_WR) || 
                                                                   (mtt_req_dout[98:96] == `MTT_IN))) || 
                                   ((mtt_fsm_cs == MTT_DMA_REQ) && ((qv_tmp_mtt_req_header[98:96] == `MTT_WR) ||
                                                                    (qv_tmp_mtt_req_header[98:96] == `MTT_IN)))) ? 
                                   dma_wr_mtt_req_prog_full : 1); 

// reg      rd_en; 
// read enable to mttmdata RAM
always @(posedge clk or posedge rst) begin
    if (rst) begin
        rd_en <= `TD 0;
    end else begin
        case (mtt_fsm_cs)
            MTT_IDLE: begin
                rd_en <= `TD 0;
            end
            MTT_ACCESS: begin
                if (!dest_dma_req_prog_full) begin
                    rd_en <= `TD 1;
                end else begin
                    rd_en <= `TD 0;
                end
            end
            MTT_DMA_REQ: begin
                if (!dest_dma_req_prog_full && (qv_req_cnt < wv_req_num)) begin
                    rd_en <= `TD 1;
                end else begin
                    rd_en <= `TD 0;
                end
            end
            default: rd_en <= `TD 0;
        endcase
    end
end
/*VCS Verification*/
// reg      q_rd_en; 
// read enable to mttmdata RAM
always @(*) begin
    if (rst) begin
        q_rd_en =  0;
    end else begin
        case (mtt_fsm_cs)
            MTT_IDLE: begin
                q_rd_en = 0;
            end
            MTT_ACCESS: begin
                if (!dest_dma_req_prog_full) begin
                    q_rd_en = 1;
                end else begin
                    q_rd_en = 0;
                end
            end
            MTT_DMA_REQ: begin
                if (!dest_dma_req_prog_full && (qv_req_cnt < wv_req_num)) begin
                    q_rd_en = 1;
                end else begin
                    q_rd_en = 0;
                end
            end
            default: q_rd_en = 0;
        endcase
    end
end
/*Action = Modify, add wire combinatorial logic*/

//wv_total means the total space for mtt req
//wv_total = the 1st mtt offset + mtt_num * mtt_size
//{mtt_index low 9 bits , 3'b0} represents the 1st mtt offset
wire  [31:0]  wv_total;
assign wv_total =  {20'b0,qv_tmp_mtt_req_header[8:0],3'b0} + {qv_tmp_mtt_req_header[92:64],3'b0};

//wire [19:0]  wv_req_num;
//wv_req_num means the total dma reqs number derived from 1 mtt req, 
//it's equal to the page number occupied by mtt entry
assign wv_req_num = (wv_total[11:0] == 12'b0) ? wv_total[31:12] : (wv_total[31:12] + 1);

//reg  [19:0]  qv_req_cnt; 
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_req_cnt <= `TD 0;
    end 
    else begin
        case (mtt_fsm_cs)
            MTT_ACCESS: begin
                if (!dest_dma_req_prog_full) begin
                    qv_req_cnt <= `TD qv_req_cnt + 1;
                end else begin
                    qv_req_cnt <= `TD 0;
                end
            end
            MTT_DMA_REQ:begin
                if (!dest_dma_req_prog_full && (qv_req_cnt < wv_req_num)) begin
                    qv_req_cnt <= `TD qv_req_cnt + 1;
                end 
                else if (qv_req_cnt == wv_req_num) begin
                    qv_req_cnt <= `TD 0;
                end 
                else begin
                    qv_req_cnt <= `TD qv_req_cnt;
                end
            end
            default: qv_req_cnt <= `TD 0;
        endcase
    end
end

// wv_rd_ori_addr ({64 bits index,3'b0}), mttm addr in RAM (low 12 bit = 0, only[20:12] bit are valid)
wire [63:0] wv_rd_ori_addr;
assign  wv_rd_ori_addr = {qv_tmp_mtt_req_header[60:0],3'b0};
/*VCS Verification*/
// reg    [MTTM_RAM_AWIDTH-1 : 0]   rd_addr; 
// read addr to mttmdata RAM
// always @(posedge clk or posedge rst) begin
//     if (rst) begin
//         rd_addr <= `TD 0;
//     end else begin
//         case (mtt_fsm_cs)
//             MTT_IDLE: begin
//                 rd_addr <= `TD 0;
//             end
//             MTT_ACCESS: begin
//                 // the 1st access RAM in 1 mtt req using the ori_addr[20:12]
//                 if (!dest_dma_req_prog_full) begin
//                     rd_addr <= `TD wv_rd_ori_addr[20:12];
//                 end else begin
//                     rd_addr <= `TD 0;    
//                 end
//             end
//             MTT_DMA_REQ: begin
//                 // the other accsses derived by the same mtt req to the RAM using the ori_addr[20:12] added by the qv_req_cnt
//                 if (!dest_dma_req_prog_full && (qv_req_cnt < wv_req_num)) begin
//                     rd_addr <= `TD wv_rd_ori_addr[20:12] + qv_req_cnt[8:0];
//                 end 
//                 else begin
//                     rd_addr <= `TD 0;
//                 end
//             end
//             default: rd_addr <= `TD 0;
//         endcase
//     end
// end
always @(*) begin
    if (rst) begin
        rd_addr = 0;
    end else begin
        case (mtt_fsm_cs)
            MTT_IDLE: begin
                rd_addr = 0;
            end
            MTT_ACCESS: begin
                // the 1st access RAM in 1 mtt req using the ori_addr[20:12]
                if (!dest_dma_req_prog_full) begin
                    rd_addr = mtt_req_dout[17:9];
                end else begin
                    rd_addr = 0;    
                end
            end
            MTT_DMA_REQ: begin
                // the other accsses derived by the same mtt req to the RAM using the ori_addr[20:12] added by the qv_req_cnt
                if (!dest_dma_req_prog_full && (qv_req_cnt < wv_req_num)) begin
                    rd_addr = wv_rd_ori_addr[20:12] + qv_req_cnt[8:0];
                end 
                else begin
                    rd_addr = 0;
                end
            end
            default: rd_addr = 0;
        endcase
    end
end
/*Action = Modify, change sequential logic into combinatorial logic*/
 
// reg  [MTTM_RAM_AWIDTH-1 : 0]   rd_data; 
// read data from mttmdata RAM, value is changed by RAM module

// reg      dma_rd_mtt_req_wr_en; 
// initial read host MTT data req
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dma_rd_mtt_req_wr_en <= `TD 0;
    end else begin
        case (qv_tmp_mtt_req_header[98:96] & {3{(mtt_fsm_cs == MTT_DMA_REQ)}})
            3'b000:  dma_rd_mtt_req_wr_en <= `TD 0;
            `MTT_RD: begin
                if ((qv_req_cnt <= wv_req_num) && rd_en) begin
                    dma_rd_mtt_req_wr_en <= `TD 1;
                end else begin
                    dma_rd_mtt_req_wr_en <= `TD 0;
                end
            end
            default: dma_rd_mtt_req_wr_en <= `TD 0;
        endcase
    end
end

//tmp_length used to store the tmp request data byte length  
wire [31:0] tmp_length;
reg [31-3:0] qv_tmp_length;
assign tmp_length = {qv_tmp_length,3'b0};
reg [2:0]  tmp_op;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_tmp_length <= `TD 0;
        tmp_op     <= `TD 0;
    end
    //if it has only 1 req, the length = the mtt num * mtt_size
    else if ((mtt_fsm_cs == MTT_DMA_REQ) && (wv_req_num == 1) && (qv_req_cnt == 1) && rd_en) begin
        qv_tmp_length <= `TD qv_tmp_mtt_req_header[95:64];
        tmp_op <= `TD `LAST;
    end
    //if it has more than 1 req and this is the first req, the length = 4KB - the origianl offset in the fisrt page
    else if ((mtt_fsm_cs == MTT_DMA_REQ) && (qv_req_cnt == 1) && (wv_req_num > 1) && rd_en) begin
        qv_tmp_length <= `TD {20'b1,9'b0} - {20'b0,qv_tmp_mtt_req_header[8:0]};
        tmp_op <= `TD qv_tmp_mtt_req_header[98:96];
    end
    //if it has more than 1 req and this is neither the first req nor the last req, the length = 4KB
    else if ((mtt_fsm_cs == MTT_DMA_REQ) && (qv_req_cnt < wv_req_num) && (wv_req_num > 1) && (qv_req_cnt > 1) && rd_en) begin
        qv_tmp_length <= `TD {20'b1,9'b0};
        tmp_op <= `TD qv_tmp_mtt_req_header[98:96];
    end
    //if it has more than 1 req and this is the last req
    //the length = mtt num * mtt_size - 4KB * (req_num -2) - (4KB-1st offset) = mtt num * mtt_size - 4KB *(req_num-1) + 1st offset
    else if ((mtt_fsm_cs == MTT_DMA_REQ) && (qv_req_cnt == wv_req_num) && (wv_req_num > 1) && rd_en) begin
        qv_tmp_length <= `TD {qv_tmp_mtt_req_header[92:64]} - {(wv_req_num - 1),9'b0} + {20'b0,qv_tmp_mtt_req_header[8:0]};
        tmp_op <= `TD `LAST;
    end
    else begin
        qv_tmp_length <= `TD 0;
        tmp_op     <= `TD 0;
    end
end

//tmp_phy_addr used to store the tmp physical addr for the the tmp request
wire [63:0] tmp_phy_addr;
reg [63-3:0] qv_tmp_phy_addr;
assign tmp_phy_addr = {qv_tmp_phy_addr,3'b0};
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_tmp_phy_addr <= `TD 0;
    end
    //if this is the first req, the phy addr = {rd_data, the offset}
    else if ((mtt_fsm_cs == MTT_DMA_REQ) && (qv_req_cnt == 1) && rd_en) begin
        qv_tmp_phy_addr <= `TD {rd_data,qv_tmp_mtt_req_header[8:0]};
    end
    //if it has more than 1 req and this is neither the first req nor the last req, offset =0, the phy addr = {rd_data, 12'b0;}
    else if ((mtt_fsm_cs == MTT_DMA_REQ) && (qv_req_cnt < wv_req_num) && (wv_req_num > 1) && (qv_req_cnt > 1) && rd_en) begin
        qv_tmp_phy_addr <= `TD {rd_data,9'b0};
    end
    //if it has more than 1 req and this is the last req
    else if ((mtt_fsm_cs == MTT_DMA_REQ) && (qv_req_cnt == wv_req_num) && (wv_req_num > 1) && rd_en) begin
        //tmp_phy_addr <= `TD {rd_data, wv_total[11:0]};
        qv_tmp_phy_addr <= `TD {rd_data,9'b0};
    end
    else begin
        qv_tmp_phy_addr <= `TD 0;
    end
end

//tmp_index used to store the mtt index in mtt table of first mtt in the tmp dma read request
reg [63:0] tmp_index;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        tmp_index <= `TD 0;
    end
    //if this is the first req, the index = qv_tmp_mtt_req_header[63:0]
    else if ((mtt_fsm_cs == MTT_DMA_REQ) && (qv_req_cnt == 1) && rd_en) begin
        tmp_index <= `TD qv_tmp_mtt_req_header[63:0];
    end
    //if it has more than 1 req and this is not the first req, index = original index + (4KB-offset)/8B + (req_cnt-2)*4KB/8B
    else if ((mtt_fsm_cs == MTT_DMA_REQ) && (qv_req_cnt <= wv_req_num) && (wv_req_num > 1) && (qv_req_cnt > 1) && rd_en) begin
        tmp_index <= `TD qv_tmp_mtt_req_header[63:0] + {55'b1,9'b0} - {55'b0,qv_tmp_mtt_req_header[8:0]} + {35'b0,(qv_req_cnt-2),9'b0};
    end
    else begin
        tmp_index <= `TD 0;
    end
end

// wire  [DMA_RD_HD_WIDTH-1 :0]   dma_rd_mtt_req_din; 
//| -----------163 bit----------|
//| index | opcode | len | addr |
//|  64   |    3   | 32  |  64  |
//|--------------------------==-|
assign dma_rd_mtt_req_din =  (dma_rd_mtt_req_wr_en) ? {tmp_index,tmp_op,tmp_length,tmp_phy_addr} : 0;

// reg   [DMA_WR_HD_WIDTH-1 :0]   dma_wr_mtt_req_wr_en; 
// initial write host MTT data req
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dma_wr_mtt_req_wr_en <= `TD 0;
    end else begin
        case (qv_tmp_mtt_req_header[98:96] & {3{(mtt_fsm_cs == MTT_DMA_REQ)}})
            3'b000:  dma_wr_mtt_req_wr_en <= `TD 0;
            `MTT_IN: dma_wr_mtt_req_wr_en <= `TD 0;
            `MTT_WR: begin
                if ((qv_req_cnt <= wv_req_num) && rd_en) begin
                    dma_wr_mtt_req_wr_en <= `TD 1;
                end else begin
                    dma_wr_mtt_req_wr_en <= `TD 0;
                end
            end
            default: dma_wr_mtt_req_wr_en <= `TD 0;
        endcase
    end
end
 
// wire   [DMA_WR_HD_WIDTH-1 :0]   dma_wr_mtt_req_din; 
//|-----99 bit----------|
//| opcode | len | addr |
//|    3   | 32  |  64  |
//|---------------------|
assign dma_wr_mtt_req_din = (dma_wr_mtt_req_wr_en) ? {tmp_op,tmp_length,tmp_phy_addr} : 0;
//assign dma_rd_mtt_req_din =  (dma_wr_mtt_req_wr_en && (qv_req_cnt == 20'b0)) ? {wv_req_num,wv_req_num,`MTT_RD,tmp_length,tmp_phy_addr} : (dma_wr_mtt_req_wr_en && (qv_req_cnt < wv_req_num) && (qv_req_cnt != 20'b0)) ? {wv_req_num,(qv_req_cnt-1),`MTT_RD,tmp_length,tmp_phy_addr} : 0;

// reg  q_mttm_finish; 
// singal to mark finish the mttmdata proc
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_mttm_finish <= `TD 0;
    end 
    else if ((ceu_fsm_ns == CEU_IDLE) && (mtt_fsm_ns == MTT_IDLE)) begin
        q_mttm_finish <= `TD 1;
    end else begin
        q_mttm_finish <= `TD 0;
    end
end


`ifdef V2P_DUG
    // /*****************Add for APB-slave regs**********************************/ 
        // reg                         dma_rd_mtt_req_wr_en;
        // reg                         dma_wr_mtt_req_wr_en;
        // reg                              wr_en; 
        // reg    [MTTM_RAM_AWIDTH-1 : 0]   wr_addr;
        // reg    [MTTM_RAM_DWIDTH-1 : 0]   wr_data;
        // reg                           q_rd_en;
        // reg                              rd_en;
        // reg    [MTTM_RAM_AWIDTH-1 : 0]   rd_addr;
        // reg    valid_array[MTTM_RAM_DEPTH-1 : 0] ;
        // reg  q_mttm_finish;
        // reg [2:0] ceu_fsm_cs;
        // reg [2:0] ceu_fsm_ns;
        // reg  [CEU_HD_WIDTH-1:0]   qv_tmp_ceu_req_header;
        // reg  [`DT_WIDTH-1:0]      qv_tmp_ceu_payload;
        // reg   [31:0] chunk_cnt;
        // reg  [31:0]  payload_cnt;
        // reg  [31:0]  payload_num;
        // reg  [11:0] page_cnt;
        // reg  q_mttm_req_rd_en;
        // reg q_mttm_rd_en;
        // reg    q_ram_rst;
        // reg [63:0] mtt_base;
        // reg [2:0] mtt_fsm_cs;
        // reg [2:0] mtt_fsm_ns;
        // reg  [TPT_HD_WIDTH-1:0]   qv_tmp_mtt_req_header;
        // reg  [19:0]  qv_req_cnt;
        // reg q_mtt_req_rd_en;
        // reg [31:0] tmp_length;
        // reg [2:0]  tmp_op;
        // reg [63:0] tmp_phy_addr;
        // reg [63:0] tmp_index;
        
    /*****************Add for APB-slave wires**********************************/         
        // output wire                    mttm_finish,
        // output wire                      mttm_req_rd_en,
        // input  wire  [CEU_HD_WIDTH-1:0]  mttm_req_dout, 
        // input  wire                      mttm_req_empty,
        // output wire                      mttm_rd_en,
        // input  wire  [`DT_WIDTH-1:0]     mttm_dout, 
        // input  wire                      mttm_empty,
        // output wire                        mtt_req_rd_en,
        // input  wire  [TPT_HD_WIDTH-1:0]    mtt_req_dout,
        // input  wire                        mtt_req_empty,  
        // output wire  [63:0]                mtt_base_addr,    
        // input  wire                           dma_rd_mtt_req_rd_en,
        // output wire  [DMA_RD_HD_WIDTH-1:0]    dma_rd_mtt_req_dout,
        // output wire                           dma_rd_mtt_req_empty,
        // input  wire                           dma_wr_mtt_req_rd_en,
        // output wire  [DMA_WR_HD_WIDTH-1:0]    dma_wr_mtt_req_dout,
        // output wire                           dma_wr_mtt_req_empty 
        // wire                        dma_rd_mtt_req_prog_full;
        // wire  [DMA_RD_HD_WIDTH-1 :0]   dma_rd_mtt_req_din;
        // wire                        dma_wr_mtt_req_prog_full;
        // wire  [DMA_WR_HD_WIDTH-1 :0]   dma_wr_mtt_req_din;
        // wire   [MTTM_RAM_DWIDTH-1 : 0]   rd_data;
        // wire                             ram_rst;
        // wire ceu_has_payload;
        // wire ceu_no_payload;
        // wire  [31:0] chunk_num;
        // wire [11:0] page_num;
        // wire [63:0]  unmap_addr;
        // wire [63:0]  map_low_addr;
        // wire [63:0]  map_high_addr;
        // wire dest_dma_req_prog_full;
        // wire [19:0]  wv_req_num;
        // wire  [31:0]  wv_total;
        // wire [63:0] wv_rd_ori_addr;
        
    //Total regs and wires : 2464 = 77*32

    assign wv_dbg_bus_mttm = {
        // 16'hffff,
        dma_rd_mtt_req_wr_en,
        dma_wr_mtt_req_wr_en,
        wr_en,
        wr_addr,
        wr_data,
        q_rd_en,
        rd_en,
        rd_addr,
        q_mttm_finish,
        ceu_fsm_cs,
        ceu_fsm_ns,
        qv_tmp_ceu_req_header,
        qv_tmp_ceu_payload,
        chunk_cnt,
        payload_cnt,
        payload_num,
        page_cnt,
        q_mttm_req_rd_en,
        q_mttm_rd_en,
        q_ram_rst,
        mtt_base,
        mtt_fsm_cs,
        mtt_fsm_ns,
        qv_tmp_mtt_req_header,
        qv_req_cnt,
        q_mtt_req_rd_en,
        qv_tmp_length,
        tmp_op,
        qv_tmp_phy_addr,
        tmp_index,

        tmp_length,
        tmp_phy_addr,
        mttm_finish,
        mttm_req_rd_en,
        mttm_req_dout,
        mttm_req_empty,
        mttm_rd_en,
        mttm_dout,
        mttm_empty,
        mtt_req_rd_en,
        mtt_req_dout,
        mtt_req_empty,
        mtt_base_addr,
        dma_rd_mtt_req_rd_en,
        dma_rd_mtt_req_dout,
        dma_rd_mtt_req_empty,
        dma_wr_mtt_req_rd_en,
        dma_wr_mtt_req_dout,
        dma_wr_mtt_req_empty,
        dma_rd_mtt_req_prog_full,
        dma_rd_mtt_req_din,
        dma_wr_mtt_req_prog_full,
        dma_wr_mtt_req_din,
        rd_data,
        ram_rst,
        ceu_has_payload,
        ceu_no_payload,
        chunk_num,
        page_num,
        unmap_addr,
        map_low_addr,
        map_high_addr,
        dest_dma_req_prog_full,
        wv_req_num,
        wv_total,
        wv_rd_ori_addr
    };

`endif 


endmodule
