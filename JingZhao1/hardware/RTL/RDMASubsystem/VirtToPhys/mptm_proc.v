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
// RELEASE DATE: 2020-09-23
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

module mptm_proc #(
    parameter  TPT_HD_WIDTH  = 99,//for MPT-mptmdata req header fifo
    parameter  DMA_RD_HD_WIDTH  = 163,//for Mdata-DMA Read req header fifo
    parameter  DMA_WR_HD_WIDTH  = 99,//for Mdata-DMA Write req header fifo
    parameter  CEU_HD_WIDTH  = 104,//for ceu_tptm_proc to mptmdata req header fifo
    parameter  MPTM_RAM_DWIDTH = 52,//mptmdata RAM data width
    parameter  MPTM_RAM_AWIDTH = 9,//mptmdata RAM addr width
    parameter  MPTM_RAM_DEPTH  = 512 //mptmdata RAM depth
    )(
    input clk,
    input rst,
    /*Spyglass*/
    //input  wire                    mptm_start,
    /*Action = Delete*/
    
    output wire                    mptm_finish,

	input 	wire 											global_mem_init_finish,
	input	wire 											init_wea,
	input	wire 	[`V2P_MEM_MAX_ADDR_WIDTH - 1 : 0]		init_addra,
	input	wire 	[`V2P_MEM_MAX_DIN_WIDTH - 1 : 0]		init_dina,

    //mptmdata request from ceu_tptm_proc
    output wire                        mptm_req_rd_en,
    input  wire  [CEU_HD_WIDTH-1:0]    mptm_req_dout, 
    input  wire                        mptm_req_empty,
    //mptmdata payload from ceu_tptm_proc
    output wire                        mptm_rd_en,
    input  wire  [`DT_WIDTH-1:0]       mptm_dout, 
    input  wire                        mptm_empty,
    //MPT Request interface
    output wire                        mpt_req_rd_en,
    input  wire  [TPT_HD_WIDTH-1:0]    mpt_req_dout,
    input  wire                        mpt_req_empty,     
    //MPT get mpt_base for compute index in mpt_ram
    output wire  [63:0]                mpt_base_addr,  
    //DMA Read Ctx Request interface
    input  wire                           dma_rd_mpt_req_rd_en,
    output wire  [DMA_RD_HD_WIDTH-1:0]    dma_rd_mpt_req_dout,
    output wire                           dma_rd_mpt_req_empty,
    //DMA Write Ctx Request interface   
    input  wire                           dma_wr_mpt_req_rd_en,
    output wire  [DMA_WR_HD_WIDTH-1:0]    dma_wr_mpt_req_dout,
    output wire                           dma_wr_mpt_req_empty 


    `ifdef V2P_DUG
    //apb_slave
        ,  input wire [`MPTM_DBG_RW_NUM * 32 - 1 : 0]   rw_data
        ,  output wire [`MPTM_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mptm
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
wire                            dma_rd_mpt_req_prog_full;
reg                             dma_rd_mpt_req_wr_en;
wire   [DMA_RD_HD_WIDTH-1 :0]   dma_rd_mpt_req_din;

//DMA Write Ctx Request interface
wire                           dma_wr_mpt_req_prog_full;
reg                            dma_wr_mpt_req_wr_en;
wire  [DMA_WR_HD_WIDTH-1 :0]   dma_wr_mpt_req_din;


//DMA Read Ctx Request interface FIFO
dma_rd_mpt_req_fifo_163w32d dma_rd_mpt_req_fifo_163w32d_Inst(
    .clk        (clk),
    .srst       (rst),
    .wr_en      (dma_rd_mpt_req_wr_en),
    .rd_en      (dma_rd_mpt_req_rd_en),
    .din        (dma_rd_mpt_req_din),
    .dout       (dma_rd_mpt_req_dout),
    .full       (),
    .empty      (dma_rd_mpt_req_empty),     
    .prog_full  (dma_rd_mpt_req_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[0 * 32 +: 1 * 32])        
    `endif
); 


//DMA Write Ctx Request interface FIFO
dma_wr_mpt_req_fifo_99w32d dma_wr_mpt_req_fifo_99w32d_Inst(
    .clk        (clk),
    .srst       (rst),
    .wr_en      (dma_wr_mpt_req_wr_en),
    .rd_en      (dma_wr_mpt_req_rd_en),
    .din        (dma_wr_mpt_req_din),
    .dout       (dma_wr_mpt_req_dout),
    .full       (),
    .empty      (dma_wr_mpt_req_empty),     
    .prog_full  (dma_wr_mpt_req_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[1 * 32 +: 1 * 32])        
    `endif
); 

//use singledualportram to instantiate mptmdata RAM 
reg                              wr_en; 
reg    [MPTM_RAM_AWIDTH-1 : 0]   wr_addr;
reg    [MPTM_RAM_DWIDTH-1 : 0]   wr_data;
reg                              rd_en;
wire   [MPTM_RAM_AWIDTH-1 : 0]   rd_addr;
wire   [MPTM_RAM_DWIDTH-1 : 0]   rd_data;
wire                             ram_rst;
reg  [0:0] valid_array[0:MPTM_RAM_DEPTH-1];//valid flag


bram_mptm_52w512d_simdaulp mptm_ram(
    .clka     (clk),
    .ena      (ram_init_finish ? wr_en : init_wea),
    .wea      (ram_init_finish ? wr_en : init_wea),
    .addra    (ram_init_finish ? wr_addr : init_addra[MPTM_RAM_AWIDTH - 1 : 0]),
    .dina     (ram_init_finish ? wr_data : init_dina[MPTM_RAM_DWIDTH - 1 : 0]),
    .clkb     (clk),
    .enb      (rd_en),
    .addrb    (rd_addr),
    .doutb    (rd_data)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[2 * 32 +: 1 * 32])        
    `endif
);

// mptm_proc sub_module process finish
reg  q_mptm_finish;
assign mptm_finish = q_mptm_finish;

/*************************state mechine 1 for ceu_tptm_proc req****************************/
//registers
reg [2:0] ceu_fsm_cs;
reg [2:0] ceu_fsm_ns;

//state machine localparams
//IDLE
localparam CEU_IDLE    = 3'b001;
//ACCESS: access mptmdata RAM, including INIT HCA, CLOSE HCA, ICM MAP, ICM UNMAP. 
localparam CEU_ACCESS  = 3'b010;
//PAYLOAD: read ceu_tptm_prco payload and put them into mptm ram
localparam CEU_PAYLOAD = 3'b100;

reg  [CEU_HD_WIDTH-1:0]   qv_tmp_ceu_req_header;
reg  [`DT_WIDTH-1:0]      qv_tmp_ceu_payload;
wire ceu_has_payload;
wire ceu_no_payload;

// chunk num means the chunk num in 1 request, 1 payload may have 2 chunk
wire [31:0] chunk_num;
reg  [31:0] chunk_cnt;
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
            if(!mptm_req_empty) begin
                ceu_fsm_ns = CEU_ACCESS;
            end
            else
                ceu_fsm_ns = CEU_IDLE;
        end 
        CEU_ACCESS: begin
            if (ceu_no_payload && mptm_req_empty) begin
                ceu_fsm_ns = CEU_IDLE;
            end
            else if (ceu_has_payload && !mptm_empty) begin
                ceu_fsm_ns = CEU_PAYLOAD;
            end else begin
                ceu_fsm_ns = CEU_ACCESS;
            end
        end
        CEU_PAYLOAD: begin
            if ((payload_cnt == payload_num) && (chunk_cnt == chunk_num) && (page_cnt == page_num) && mptm_req_empty) begin
                ceu_fsm_ns = CEU_IDLE;
            end else if ((payload_cnt == payload_num) && (chunk_cnt == chunk_num) && (page_cnt == page_num) && !mptm_req_empty) begin
                ceu_fsm_ns = CEU_ACCESS;
            end else begin
                ceu_fsm_ns = CEU_PAYLOAD;
            end
        end
        default: ceu_fsm_ns = CEU_IDLE;
    endcase
end

//-----------------Stage 3 :Output Decode----------
assign ceu_has_payload = (mptm_req_dout[103:100] == `MAP_ICM_TPT) &&
                         (mptm_req_dout[99:96] == `MAP_ICM_EN_V2P);

assign ceu_no_payload = ((mptm_req_dout[103:100] == `WR_ICMMAP_TPT) &&
                          (mptm_req_dout[99:96] == `WR_ICMMAP_EN_V2P)) ||
                         ((mptm_req_dout[103:100] == `WR_ICMMAP_TPT) &&
                          (mptm_req_dout[99:96] == `WR_ICMMAP_DIS_V2P)) ||
                         ((mptm_req_dout[103:100] == `MAP_ICM_TPT) &&
                          (mptm_req_dout[99:96] == `MAP_ICM_DIS_V2P));

// output wire   mptm_req_rd_en; 
// form ceu_tptm_proc req 
reg q_mptm_req_rd_en;
/*VCS Verification*/
assign mptm_req_rd_en = q_mptm_req_rd_en & !mptm_req_empty;
/*Action = Modify, add & !mttm_req_empty*/
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_mptm_req_rd_en <= `TD 0;
    end else begin
        case (ceu_fsm_cs)
            CEU_IDLE: begin
                if (!mptm_req_empty) begin
                    q_mptm_req_rd_en <= `TD 1;
                end else begin
                    q_mptm_req_rd_en <= `TD 0;
                end
            end 
            CEU_ACCESS: begin
                if (ceu_no_payload && !mptm_req_empty) begin
                    q_mptm_req_rd_en <= `TD 1;
                end else begin
                    q_mptm_req_rd_en <= `TD 0;
                end
            end
            CEU_PAYLOAD: begin
                if ((payload_cnt == payload_num) && (chunk_cnt == chunk_num) && (page_cnt == page_num) && !mptm_req_empty) begin
                    q_mptm_req_rd_en <= `TD 1;
                end else begin
                    q_mptm_req_rd_en <= `TD 0;
                end
            end
            default: q_mptm_req_rd_en <= `TD 0;
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
    else if (mptm_rd_en) begin
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
        payload_num <= `TD qv_tmp_ceu_req_header[95:64]/2 + 1;
    end 
    // if chunk_num is even, payload_num = chunk_num/2 +1;
    else if ((ceu_fsm_cs == CEU_PAYLOAD) && !qv_tmp_ceu_req_header[64]) begin
        payload_num <= `TD qv_tmp_ceu_req_header[95:64]/2;
    end
    else
        payload_num <= `TD 0;
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
                qv_tmp_ceu_req_header <= `TD mptm_req_dout;
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

// output wire    mptm_rd_en 
// form ceu_tptm_proc payload, ICM_MAP
reg q_mptm_rd_en;
assign mptm_rd_en = q_mptm_rd_en;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_mptm_rd_en <= `TD 0;
    end else begin
        case (ceu_fsm_cs)
            CEU_IDLE: begin
               q_mptm_rd_en <= `TD 0;
            end 
            CEU_ACCESS: begin
                // in ACCESS state enable q_mptm_rd_en 1 time
                if (ceu_has_payload && !mptm_empty) begin
                    q_mptm_rd_en <= `TD 1;
                end else begin
                    q_mptm_rd_en <= `TD 0;
                end
            end
            CEU_PAYLOAD: begin
                // when 1 payload has been processed completely and there are still some payload in fifo, enable the q_mptm_rd_en
                /*VCS Verification*/
                // if (((payload_cnt < payload_num) || (payload_cnt == 0)) && !mptm_empty && ((chunk_cnt == 0) || (chunk_cnt < chunk_num)) && ((page_cnt == 0) || (page_cnt == page_num-1))) begin
                if ((chunk_cnt < chunk_num) && (payload_cnt < payload_num) && (page_cnt == page_num-1) && !chunk_cnt[0] && !mptm_empty) begin
                    /*Action = Modify, all page of 1 chunk process completely and chunk_cnt is even */                    
                    q_mptm_rd_en <= `TD 1;
                end else begin
                    q_mptm_rd_en <= `TD 0;
                end
            end
            default: q_mptm_rd_en <= `TD 0;
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
                    if (mptm_rd_en) begin
                    /*Action = Modify, use read enable signal to update payload_cnt*/
                    qv_tmp_ceu_payload <= `TD mptm_dout;
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
                if (((chunk_cnt == 0) && (payload_cnt == 0) && (page_cnt == 0)) || ((chunk_cnt < chunk_num) && (payload_cnt <=  payload_num) && (page_cnt == page_num))) begin
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
                case (mptm_req_dout[103:96])
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


//high 56: mpt_base; low 8: log2 mpt number
reg [63:0] mpt_base;
reg [7:0]  log2_mpt_num;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mpt_base <= `TD 0;
        log2_mpt_num <= `TD 0;
    end 
    else begin
        case (ceu_fsm_cs)
            CEU_IDLE: begin
                mpt_base <= `TD mpt_base;
                log2_mpt_num <= `TD log2_mpt_num;
            end
            CEU_ACCESS: begin
                case ({mptm_req_dout[103:96]})
                    {`WR_ICMMAP_TPT,`WR_ICMMAP_EN_V2P}:begin
                        mpt_base <= `TD {mptm_req_dout[63:8],8'b0};
                        log2_mpt_num <= `TD mptm_req_dout[7:0];
                    end
                    {`WR_ICMMAP_TPT,`WR_ICMMAP_DIS_V2P}: begin
                        mpt_base <= `TD 0;
                        log2_mpt_num <= `TD 0;
                    end 
                    {`MAP_ICM_TPT,`MAP_ICM_DIS_V2P}:begin
                        mpt_base <= `TD mpt_base;
                        log2_mpt_num <= `TD log2_mpt_num;
                    end
                    default: begin
                        mpt_base <= `TD mpt_base;
                        log2_mpt_num <= `TD log2_mpt_num;
                    end
                endcase
            end
            CEU_PAYLOAD: begin
                mpt_base <= `TD mpt_base;
                log2_mpt_num <= `TD log2_mpt_num;
            end 
            default:  begin
                mpt_base <= `TD mpt_base;
                log2_mpt_num <= `TD log2_mpt_num;
            end
        endcase
    end   
end
//MPT get mpt_base for compute index in mpt_ram
//output wire  [63:0]                mpt_base_addr,  
assign mpt_base_addr = mpt_base;

// reg [0:0] valid_array[0 : MPTM_RAM_DEPTH-1]
wire [63:0]  unmap_addr;  //valid_array addr = (virt addr - mpt_base)[20:12];
wire [63:0]  map_low_addr;//ram_array addr = (virt addr in 127:64 payload - mpt_base)[20:12];
wire [63:0]  map_high_addr;//ram_array addr = (virt addr in 255:192 payload - mpt_base)[20:12];
assign unmap_addr    = mptm_req_dout[63:0] - mpt_base;
//first cycle read from fifo_dout, else read from tmp_ceu_payload
/*VCS Verification*/
// assign map_low_addr  =  (page_cnt == 0) ? (mptm_dout[127:64] - mpt_base) : (qv_tmp_ceu_payload[127:64] - mpt_base);
assign map_low_addr  =  (mptm_rd_en) ? (mptm_dout[127:64] - mpt_base) : (qv_tmp_ceu_payload[127:64] - mpt_base);
/*Action = Modify, use read enable signal to choose dout or reg to update addr*/
assign map_high_addr = qv_tmp_ceu_payload[255:192] - mpt_base;//read from tmp_paylaod reg
integer i;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        for(i = 0; i < MPTM_RAM_DEPTH; i = i + 1) begin
            valid_array[i] <= `TD 0;
        end
    end else begin
        case (ceu_fsm_cs)
            CEU_IDLE: begin
                for(i = 0; i < MPTM_RAM_DEPTH; i = i + 1) begin
                    valid_array[i] <= `TD valid_array[i];
                end
            end
            CEU_ACCESS: begin
                case (mptm_req_dout[103:96])
                    {`WR_ICMMAP_TPT,`WR_ICMMAP_EN_V2P}:begin
                        // invalid all entry
                        for(i = 0; i < MPTM_RAM_DEPTH; i = i + 1) begin
                            valid_array[i] <= `TD 0;
                        end
                    end
                    {`WR_ICMMAP_TPT,`WR_ICMMAP_DIS_V2P}: begin
                        // invalid all entry
                        for(i = 0; i < MPTM_RAM_DEPTH; i = i + 1) begin
                            valid_array[i] <= `TD 0;
                        end
                    end 
                    {`MAP_ICM_TPT,`MAP_ICM_DIS_V2P}:begin
                        // unmap cmd, invalid the correspond entry bit
                        /*Spyglass*/
                        //for(i = 0; i < mptm_req_dout[72:64]; i = i + 1) begin
                        //    valid_array[unmap_addr[20:12] + i] <= `TD 0;
                        //end
                        for(i = 0; i < MPTM_RAM_DEPTH; i = i + 1) begin
                            if ((i < unmap_addr[20:12] + mptm_req_dout[72:64]) && (i >= unmap_addr[20:12])) begin
                                valid_array[i] <= `TD 0;
                            end else begin
                                valid_array[i] <= `TD valid_array[i];
                            end
                        end
                        /*Action = Modify*/
                    end
                    default: begin
                        for(i = 0; i < MPTM_RAM_DEPTH; i = i + 1) begin
                            valid_array[i] <= `TD valid_array[i];
                        end
                    end 
                endcase
            end
            CEU_PAYLOAD: begin
                // the first chunk of 1 payload processing stage, use the low 128 bits
                if (((chunk_cnt == 0) && (payload_cnt == 0) && (page_cnt == 0)) || (((chunk_cnt < chunk_num) || (chunk_cnt == chunk_num)) && (page_cnt < page_num) && (chunk_cnt[0] == 1)) ) begin
                    valid_array[map_low_addr[20:12] + page_cnt[MPTM_RAM_AWIDTH-1:0]] <= `TD 1;
                end 
                else if ((chunk_cnt < chunk_num) && (page_cnt == page_num) && (chunk_cnt[0] == 0)) begin
                    valid_array[map_low_addr[20:12]] <= `TD 1;
                end 
                else if ((chunk_cnt < chunk_num) && (page_cnt == page_num) && (chunk_cnt[0] == 1)) begin
                    valid_array[map_high_addr[20:12]] <= `TD 1;
                end
                else if (((chunk_cnt < chunk_num) || (chunk_cnt == chunk_num)) && (page_cnt < page_num) && (chunk_cnt[0] == 0)) begin
                    valid_array[map_high_addr[20:12] + page_cnt[MPTM_RAM_AWIDTH-1:0]] <= `TD 1;
                end
                else begin
                    for(i = 0; i < MPTM_RAM_DEPTH; i = i + 1) begin
                    valid_array[i] <= `TD valid_array[i];
                end
                end
            end 
            default: begin
                for(i = 0; i < MPTM_RAM_DEPTH; i = i + 1) begin
                    valid_array[i] <= `TD valid_array[i];
                end
            end
        endcase
    end
end

// reg       wr_en; 
// write enable to mptmdata RAM
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
 
// reg    [MPTM_RAM_AWIDTH-1 : 0]   wr_addr; 
// write addr to mptmdata RAM
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
                    wr_addr <= `TD map_low_addr[20:12] + page_cnt[MPTM_RAM_AWIDTH-1:0];
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
                    wr_addr <= `TD map_high_addr[20:12] + page_cnt[MPTM_RAM_AWIDTH-1:0];
                end
                else begin
                    wr_addr <= `TD 0;
                end
            end
            default: wr_addr <= `TD 0;
        endcase
    end
end
 
// reg    [MPTM_RAM_AWIDTH-1 : 0]   wr_data;
// write data to mptmdata RAM, if 1 chunk has more than 1 page_num, each page has 1 entry
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
                // when the first chunk in the new payload is first being processed, write the physical address based on the low_phy_addr info from mptm_dout
                if (((chunk_cnt == 0) && (payload_cnt == 0) && (page_cnt == 0)) || ((chunk_cnt < chunk_num) && (page_cnt == page_num) && (chunk_cnt[0] == 0)) ) begin
                    wr_data <= `TD mptm_dout[63:12];
                end
                // when the first chunk in the payload is being processed, write the physical address based on the low_phy_addr info from tmp reg
                else if ((chunk_cnt <= chunk_num) && (page_cnt < page_num) && (chunk_cnt[0] == 1)) begin
                    //use the page_cnt + phy addr in payload to calculate the entry physical addr
                    wr_data <= `TD qv_tmp_ceu_payload[63:12] + {40'b0,page_cnt};
                end
                // when the first chunk in the payload is processed completely, next cycle write the physical address based on the high_phy_addr info from mptm_dout
                else if ((chunk_cnt < chunk_num) && (page_cnt == page_num) && (chunk_cnt[0] == 1)) begin
                    /*VCS Verification*/
                    // wr_data <= `TD mptm_dout[191:140];
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


/*************************state mechine 2 for MPT req****************************/
//registers
reg [2:0] mpt_fsm_cs;
reg [2:0] mpt_fsm_ns;
//state machine localparams
//IDLE
localparam MPT_IDLE    = 3'b001;
//ACCESS: access mptmdata RAM, Read mptm entry for next DMA_REQ state. 
localparam MPT_ACCESS  = 3'b010;
//DMA_REQ: initiate dma read/write request according to the mptmdata
localparam MPT_DMA_REQ = 3'b100;

wire dest_dma_req_prog_full;
reg  [TPT_HD_WIDTH-1:0]   qv_tmp_mpt_req_header;

//-----------------Stage 1 :State Register----------
always @(posedge clk or posedge rst) begin
    if(rst)
        mpt_fsm_cs <= `TD MPT_IDLE;
    else
        mpt_fsm_cs <= `TD mpt_fsm_ns;
end
//-----------------Stage 2 :State Transition----------
always @(*) begin
    case (mpt_fsm_cs)
        MPT_IDLE: begin
            if(!mpt_req_empty) begin
                mpt_fsm_ns = MPT_ACCESS;
            end
            else
                mpt_fsm_ns = MPT_IDLE;
        end 
        MPT_ACCESS: begin
            if (!dest_dma_req_prog_full) begin
                mpt_fsm_ns = MPT_DMA_REQ;    
            end
            else
                mpt_fsm_ns = MPT_ACCESS;
        end
        MPT_DMA_REQ: begin
            // todo: add condition for finishing req transfer? No, q mpt entry only cause 1 cycle to transfer dma req header
            if (!dest_dma_req_prog_full && !mpt_req_empty) begin
                mpt_fsm_ns = MPT_ACCESS;
            end else if (!dest_dma_req_prog_full && mpt_req_empty) begin
                mpt_fsm_ns = MPT_IDLE;
            end
            else
                mpt_fsm_ns = MPT_DMA_REQ;
        end
        default: mpt_fsm_ns = MPT_IDLE;
    endcase
end

//-----------------Stage 3 :Output Decode----------

// output wire    mpt_req_rd_en 
// from MPT req to read/write from/to host MPT data
reg q_mpt_req_rd_en;
assign mpt_req_rd_en = q_mpt_req_rd_en;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_mpt_req_rd_en <= `TD 0;
    end else begin
        case (mpt_fsm_cs)
            MPT_IDLE: begin
                if (!mpt_req_empty) begin
                    q_mpt_req_rd_en <= `TD 1;
                end else begin
                    q_mpt_req_rd_en <= `TD 0;
                end
            end
            MPT_ACCESS: begin
                q_mpt_req_rd_en <= `TD 0;
            end
            MPT_DMA_REQ: begin
                if (!dest_dma_req_prog_full && !mpt_req_empty) begin
                    q_mpt_req_rd_en <= `TD 1;
                end 
                else begin
                    q_mpt_req_rd_en <= `TD 0;
                end
            end 
            default: q_mpt_req_rd_en <= `TD 0;
        endcase
    end
end
 
//reg  [TPT_HD_WIDTH-1:0] qv_tmp_mpt_req_header;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_tmp_mpt_req_header <= `TD 0;
    end else begin
        case (mpt_fsm_cs)
            MPT_IDLE: begin
                qv_tmp_mpt_req_header <= `TD 0;
            end 
            MPT_ACCESS: begin
                qv_tmp_mpt_req_header <= `TD mpt_req_dout;
            end
            MPT_DMA_REQ: begin
                qv_tmp_mpt_req_header <= `TD qv_tmp_mpt_req_header;
            end
            default: qv_tmp_mpt_req_header <= `TD 0;
        endcase
    end
end

// wire  dest_dma_req_prog_full;
// MPT_ACCESS state, use mpt_req_dout "opcode" seg to select dest_fifo
// MPT_DMA_REQ state, use qv_tmp_mpt_req_header "opcode" seg to select dest_fifo
// `MPT_RD             --------- dma_rd_mpt_req_fifo
// `MPT_WR and `MPT_IN --------- dma_wr_mpt_req_fifo
assign dest_dma_req_prog_full = (((mpt_fsm_cs == MPT_ACCESS) && (mpt_req_dout[98:96] == `MPT_RD)) || 
                                 ((mpt_fsm_cs == MPT_DMA_REQ) && (qv_tmp_mpt_req_header[98:96] == `MPT_RD))) ? dma_rd_mpt_req_prog_full : 
                                 ((((mpt_fsm_cs == MPT_ACCESS) && ((mpt_req_dout[98:96] == `MPT_WR) || 
                                                                   (mpt_req_dout[98:96] == `MPT_IN))) || 
                                   ((mpt_fsm_cs == MPT_DMA_REQ) && ((qv_tmp_mpt_req_header[98:96] == `MPT_WR) ||
                                                                    (qv_tmp_mpt_req_header[98:96] == `MPT_IN)))) ? 
                                   dma_wr_mpt_req_prog_full : 1); 

// reg      rd_en; 
// read enable to mptmdata RAM
always @(posedge clk or posedge rst) begin
    if (rst) begin
        rd_en <= `TD 0;
    end else begin
        case (mpt_fsm_cs)
            MPT_IDLE: begin
                rd_en <= `TD 0;
            end 
            MPT_ACCESS: begin
                if (!dest_dma_req_prog_full) begin
                    rd_en <= `TD 1;
                end else begin
                    rd_en <= `TD 0;
                end
            end
            MPT_DMA_REQ: begin
                rd_en <= `TD 0;
            end
            default: rd_en <= `TD 0;
        endcase
    end
end
 
// wv_rd_addr (lkey << 6) = mptm addr in RAM (low 12 bit = 0, only[20:12] bit are valid)
wire [37:0] wv_rd_addr;
assign  wv_rd_addr = {qv_tmp_mpt_req_header[31:0],6'b0};
// read addr to mptmdata RAM
assign rd_addr = (rd_en) ? wv_rd_addr[20:12] : 0;
 
// reg  [MPTM_RAM_AWIDTH-1 : 0]   rd_data; 
// read data from mptmdata RAM, value is changed by RAM module


// reg     dma_rd_mpt_req_wr_en; 
// initial read host MPT data req
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dma_rd_mpt_req_wr_en <= `TD 0;
    end else begin
        case (qv_tmp_mpt_req_header[98:96] & {3{(mpt_fsm_cs == MPT_DMA_REQ)}})
            3'b000:  dma_rd_mpt_req_wr_en <= `TD 0;
            `MPT_RD: dma_rd_mpt_req_wr_en <= `TD 1;
            default: dma_rd_mpt_req_wr_en <= `TD 0;
        endcase
    end
end
  
// wire  [DMA_RD_HD_WIDTH-1 :0]  dma_rd_mpt_req_din;
//| -----------163 bit----------|
//| index | opcode | len | addr |
//|  64   |    3   | 32  |  64  |
//|--------------------------==-|
//rd_data=phy page;qv_tmp_mpt_req_header[5:0]=mpt entry offset;6'b0=1 mpt entry size
assign dma_rd_mpt_req_din =  (dma_rd_mpt_req_wr_en) ? {qv_tmp_mpt_req_header[63:0],`MPT_RD,32'b1000000,rd_data,qv_tmp_mpt_req_header[5:0],6'b0} : 0;

// reg     dma_wr_mpt_req_wr_en; 
// initial write host MPT data req
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dma_wr_mpt_req_wr_en <= `TD 0;
    end else begin
        case (qv_tmp_mpt_req_header[98:96] & {3{(mpt_fsm_cs == MPT_DMA_REQ)}})
            3'b000:  dma_wr_mpt_req_wr_en <= `TD 0;
            `MPT_IN: dma_wr_mpt_req_wr_en <= `TD 0;
            `MPT_WR: dma_wr_mpt_req_wr_en <= `TD 1;
            default: dma_wr_mpt_req_wr_en <= `TD 0;
        endcase
    end
end
 
// wire   [DMA_WR_HD_WIDTH-1 :0]   dma_wr_mpt_req_din; 
// initial write host MPT data req
//|-----99 bit----------|
//| opcode | len | addr |
//|    3   | 32  |  64  |
//|---------------------|
assign dma_wr_mpt_req_din = (dma_wr_mpt_req_wr_en) ? {`MPT_WR,32'b1000000,rd_data,qv_tmp_mpt_req_header[5:0],6'b0} : 0;

// reg  q_mptm_finish; 
// singal to mark finish the mptmdata proc
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_mptm_finish <= `TD 0;
    end 
    else if ((ceu_fsm_ns == CEU_IDLE) && (mpt_fsm_ns == MPT_IDLE)) begin
        q_mptm_finish <= `TD 1;
    end else begin
        q_mptm_finish <= `TD 0;
    end
end


`ifdef V2P_DUG
    // /*****************Add for APB-slave regs**********************************/ 
        // reg                             dma_rd_mpt_req_wr_en;
        // reg                            dma_wr_mpt_req_wr_en;
        // reg                              wr_en; 
        // reg    [MPTM_RAM_AWIDTH-1 : 0]   wr_addr;
        // reg    [MPTM_RAM_DWIDTH-1 : 0]   wr_data;
        // reg                              rd_en;
        // reg  [0:0] valid_array[0:MPTM_RAM_DEPTH-1];
        // reg  q_mptm_finish;
        // reg [2:0] ceu_fsm_cs;
        // reg [2:0] ceu_fsm_ns;
        // reg  [CEU_HD_WIDTH-1:0]   qv_tmp_ceu_req_header;
        // reg  [`DT_WIDTH-1:0]      qv_tmp_ceu_payload;
        // reg  [31:0] chunk_cnt;
        // reg  [31:0]  payload_cnt;
        // reg  [31:0]  payload_num;
        // reg  [11:0] page_cnt;
        // reg q_mptm_req_rd_en;
        // reg q_mptm_rd_en;
        // reg    q_ram_rst;
        // reg [63:0] mpt_base;
        // reg [7:0]  log2_mpt_num;
        // reg [2:0] mpt_fsm_cs;
        // reg [2:0] mpt_fsm_ns;
        // reg  [TPT_HD_WIDTH-1:0]   qv_tmp_mpt_req_header;
        // reg q_mpt_req_rd_en;
        
    /*****************Add for APB-slave wires**********************************/         
        // wire                    mptm_finish,
        // wire                        mptm_req_rd_en,
        // wire  [CEU_HD_WIDTH-1:0]    mptm_req_dout, 
        // wire                        mptm_req_empty,
        // wire                        mptm_rd_en,
        // wire  [`DT_WIDTH-1:0]       mptm_dout, 
        // wire                        mptm_empty,
        // wire                        mpt_req_rd_en,
        // wire  [TPT_HD_WIDTH-1:0]    mpt_req_dout,
        // wire                        mpt_req_empty,     
        // wire  [63:0]                mpt_base_addr,  
        // wire                           dma_rd_mpt_req_rd_en,
        // wire  [DMA_RD_HD_WIDTH-1:0]    dma_rd_mpt_req_dout,
        // wire                           dma_rd_mpt_req_empty,
        // wire                           dma_wr_mpt_req_rd_en,
        // wire  [DMA_WR_HD_WIDTH-1:0]    dma_wr_mpt_req_dout,
        // wire                           dma_wr_mpt_req_empty 
        // wire                            dma_rd_mpt_req_prog_full;
        // wire   [DMA_RD_HD_WIDTH-1 :0]   dma_rd_mpt_req_din;
        // wire                           dma_wr_mpt_req_prog_full;
        // wire  [DMA_WR_HD_WIDTH-1 :0]   dma_wr_mpt_req_din;
        // wire   [MPTM_RAM_AWIDTH-1 : 0]   rd_addr;
        // wire   [MPTM_RAM_DWIDTH-1 : 0]   rd_data;
        // wire                             ram_rst;
        // wire ceu_has_payload;
        // wire ceu_no_payload;
        // wire [31:0] chunk_num;
        // wire [11:0] page_num;
        // wire [63:0]  unmap_addr;
        // wire [63:0]  map_low_addr;
        // wire [63:0]  map_high_addr;
        // wire dest_dma_req_prog_full;
        // wire [37:0] wv_rd_addr;
        // 
    //Total regs and wires : 2120 = 66*32+8

    assign wv_dbg_bus_mptm = {
        24'b0,
        dma_rd_mpt_req_wr_en,
        dma_wr_mpt_req_wr_en,
        wr_en,
        wr_addr,
        wr_data,
        rd_en,
        q_mptm_finish,
        ceu_fsm_cs,
        ceu_fsm_ns,
        qv_tmp_ceu_req_header,
        qv_tmp_ceu_payload,
        chunk_cnt,
        payload_cnt,
        payload_num,
        page_cnt,
        q_mptm_req_rd_en,
        q_mptm_rd_en,
        q_ram_rst,
        mpt_base,
        log2_mpt_num,
        mpt_fsm_cs,
        mpt_fsm_ns,
        qv_tmp_mpt_req_header,
        q_mpt_req_rd_en,

        mptm_finish,
        mptm_req_rd_en,
        mptm_req_dout,
        mptm_req_empty,
        mptm_rd_en,
        mptm_dout,
        mptm_empty,
        mpt_req_rd_en,
        mpt_req_dout,
        mpt_req_empty,
        mpt_base_addr,
        dma_rd_mpt_req_rd_en,
        dma_rd_mpt_req_dout,
        dma_rd_mpt_req_empty,
        dma_wr_mpt_req_rd_en,
        dma_wr_mpt_req_dout,
        dma_wr_mpt_req_empty,
        dma_rd_mpt_req_prog_full,
        dma_rd_mpt_req_din,
        dma_wr_mpt_req_prog_full,
        dma_wr_mpt_req_din,
        rd_addr,
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
        wv_rd_addr
    };

`endif 

endmodule
