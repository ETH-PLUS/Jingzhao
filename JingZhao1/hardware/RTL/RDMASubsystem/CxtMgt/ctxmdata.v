//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: ctxmdata.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V0.4 
// VERSION DESCRIPTION: 4st Edition  
//----------------------------------------------------
// RELEASE DATE: 2022-08-30
//---------------------------------------------------- 
// PURPOSE: store and operate on context metadata.
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
//----------------------------------------------------
// VERSION UPDATE: 
// 
//-FHDR-----------------------------------------------

//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_ctxmgt_h.vh"

module ctxmdata#(
    parameter  QPCM_RAM_DWIDTH = 52,  //qpcmdata RAM data width
    parameter  QPCM_RAM_AWIDTH = 10,  //qpcmdata RAM addr width
    parameter  QPCM_RAM_DEPTH  = 1024,//qpcmdata RAM depth
    parameter  CQCM_RAM_DWIDTH = 52, //cqcmdata RAM data width
    parameter  CQCM_RAM_AWIDTH = 8,  //cqcmdata RAM addr width
    parameter  CQCM_RAM_DEPTH  = 256 //cqcmdata RAM depth
    )(
    input clk,
    input rst,

    // internal ceu_parser req cmd to ctxmdata Module
    //128 width 16 depth syn FIFO format1
    output  wire                      ceu_req_ctxmdata_rd_en,
    input   wire                      ceu_req_ctxmdata_empty,
    input   wire [`CEUP_REQ_MDT-1:0]  ceu_req_ctxmdata_dout,

    // internel ceu_parser context metaddata payload to write ctxmdata Module
    // 256 width 24 depth syn FIFO (only context meatadata)
    output  wire                     ctxmdata_data_rd_en,
    input   wire                     ctxmdata_data_empty,
    input   wire [`INTER_DT-1:0]     ctxmdata_data_dout,
    
    //internal key_qpc_data Request In interface
    output wire                      key_ctx_req_mdt_rd_en,
    input  wire  [`HD_WIDTH-1:0]     key_ctx_req_mdt_dout,
    input  wire                      key_ctx_req_mdt_empty,
   
    //DMA Read Ctx Request Out interface
    input  wire                            mdt_req_rd_ctx_rd_en,
    output wire [`MDT_REQ_RD_CTX-1:0]      mdt_req_rd_ctx_dout,
    output wire                            mdt_req_rd_ctx_empty,

    //DMA Write Ctx Request Out interface
    input  wire                     mdt_req_wr_ctx_rd_en,
    output wire  [`HD_WIDTH-1:0]    mdt_req_wr_ctx_dout,
    output wire                     mdt_req_wr_ctx_empty
    
    `ifdef CTX_DUG    
    //apb_slave
    // .wv_ro_data_2(wv_ro_data_2),
    , input   wire 	[`CTXM_DBG_RW_NUM * 32 - 1 : 0]	rw_data        
    , output wire 	[`CTXM_DBG_REG_NUM * 32 -1:0]		wv_dbg_bus_2
    `endif 
);

//Req Out FIFO variables decleration 
    // wire fifo_clear;
    // assign fifo_clear = 1'b0;
    //DMA Read Ctx Request Out interface
    reg                             mdt_req_rd_ctx_wr_en;
    wire  [`MDT_REQ_RD_CTX-1:0]     wv_mdt_req_rd_ctx_din;
    wire                            mdt_req_rd_ctx_prog_full;

    //DMA Write Ctx Request Out interface
    reg                      mdt_req_wr_ctx_wr_en;
    wire  [`HD_WIDTH-1:0]    wv_mdt_req_wr_ctx_din;
    wire                     mdt_req_wr_ctx_prog_full;

mdt_req_rd_ctx_fifo_108w8d mdt_req_rd_ctx_fifo_108w8d_Inst(
        .clk        (clk),
        .srst        (rst),
        .wr_en      (mdt_req_rd_ctx_wr_en),
        .rd_en      (mdt_req_rd_ctx_rd_en),
        .din        (wv_mdt_req_rd_ctx_din),
        .dout       (mdt_req_rd_ctx_dout),
        .full       (),
        .empty      (mdt_req_rd_ctx_empty),     
        .prog_full  (mdt_req_rd_ctx_prog_full)

    `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[0 * 32 +: 1 * 32])        
    `endif 
);

mdt_req_wr_ctx_fifo_128w8d mdt_req_wr_ctx_fifo_128w8d_Inst(
        .clk        (clk),
        .srst        (rst),
        .wr_en      (mdt_req_wr_ctx_wr_en),
        .rd_en      (mdt_req_wr_ctx_rd_en),
        .din        (wv_mdt_req_wr_ctx_din),
        .dout       (mdt_req_wr_ctx_dout),
        .full       (),
        .empty      (mdt_req_wr_ctx_empty),     
        .prog_full  (mdt_req_wr_ctx_prog_full)
    `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[1 * 32 +: 1 * 32])        
    `endif 
);

//qpctxmdata RAM variables decleration 
reg                              qpcm_wr_en; 
reg    [QPCM_RAM_AWIDTH-1 : 0]   qpcm_wr_addr;
reg    [QPCM_RAM_DWIDTH-1 : 0]   qpcm_wr_data;
reg                              qpcm_rd_en;
reg    [QPCM_RAM_AWIDTH-1 : 0]   qpcm_rd_addr;
wire   [QPCM_RAM_DWIDTH-1 : 0]   qpcm_rd_data;
/*Spyglass*/
//wire                             qpcm_ram_rst;
/*Action = Delete*/

reg  [0:0] qpcm_valid_array[0:QPCM_RAM_DEPTH-1];//valid flag

bram_qpc_52w1024d_simdaulp qpcm_ram(
    .clka     (clk),
    .ena      (qpcm_wr_en),
    .wea      (qpcm_wr_en),
    .addra    (qpcm_wr_addr),
    .dina     (qpcm_wr_data),
    .clkb     (clk),
    .enb      (qpcm_rd_en),
    .addrb    (qpcm_rd_addr),
    .doutb    (qpcm_rd_data)
    `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[2 * 32 +: 1 * 32])        
    `endif 
);
//cqctxmdata RAM variables decleration 
reg                              cqcm_wr_en; 
reg    [CQCM_RAM_AWIDTH-1 : 0]   cqcm_wr_addr;
reg    [CQCM_RAM_DWIDTH-1 : 0]   cqcm_wr_data;
reg                              cqcm_rd_en;
reg    [CQCM_RAM_AWIDTH-1 : 0]   cqcm_rd_addr;
wire   [CQCM_RAM_DWIDTH-1 : 0]   cqcm_rd_data;
/*Spyglass*/
//wire                             cqcm_ram_rst;
/*Action = Delete*/

reg  [0:0] cqcm_valid_array[0:CQCM_RAM_DEPTH-1];//valid flag

bram_cqc_52w256d_simdaulp  cqcm_ram(
    .clka     (clk),
    .ena      (cqcm_wr_en),
    .wea      (cqcm_wr_en),
    .addra    (cqcm_wr_addr),
    .dina     (cqcm_wr_data),
    .clkb     (clk),
    .enb      (cqcm_rd_en),
    .addrb    (cqcm_rd_addr),
    .doutb    (cqcm_rd_data)
    `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[3 * 32 +: 1 * 32])        
    `endif 
);
//eqctxmdata reg variables decleration 
    reg [51:0] eqc_page_addr;

//--------------------register varibles decleration-----------------------------
reg [`HD_WIDTH-1:0] qv_temp_ceu_req_hd;
reg [`HD_WIDTH-1:0] qv_temp_keyctx_req_hd;
reg [`DT_WIDTH-1:0] qv_temp_ceu_paylaod;
reg [31:0] qv_chunk_cnt;  //count for context metadata chunk number
reg [31:0] qv_payload_cnt;//count for context metadata number
/*VCS*/
reg [11:0] qv_page_cnt;//count for physical page num of 1 chunk
/*Action = Add*/
reg [1:0] qv_dma_req_cnt; //count for dma req number in DMA_PROC state

//use the virtual addr and qpc_base/cqc_base/eqc_base to jude the mdata belongs to which area
reg qpc_map;//MAP_ICM_EN
reg cqc_map;//MAP_ICM_EN
reg eqc_map;//MAP_ICM_EN
reg qpc_unmap;//MAP_ICM_DIS
reg cqc_unmap;//MAP_ICM_DIS
reg eqc_unmap;//MAP_ICM_DIS
//store the qpc_base/cqc_base/eqc_base
reg [55:0] qv_qpc_base;
reg [55:0] qv_cqc_base;
reg [55:0] qv_eqc_base;

wire [63:0] wv_qpc_base;
wire [63:0] wv_cqc_base;
wire [63:0] wv_eqc_base;
//--------------------wire varibles decleration-----------------------------
wire [3:0]  wv_ceu_req_type;
wire [3:0]  wv_ceu_req_opcode;
wire [3:0]  wv_keyctx_req_type;
wire [3:0]  wv_keyctx_req_opcode;

//ceu req to ctxmdata has no payload; but has context payload to writectx module
wire ctx_have_payload;
//ceu req to ctxmdata has no context payload, need to write 0 to host memory
wire ctx_no_payload;
//ceu req to ctxmdata has metadata payload
wire mdata_have_payload;
//ceu req to ctxmdata has no metadata payload
wire mdata_no_payload;

//key_qpc_data req to ctxmdata has no payload;
wire keyqpc_no_payload;

wire [3:0]  wv_reg_ceu_req_type;
wire [3:0]  wv_reg_ceu_req_opcode;
wire [3:0]  wv_reg_keyctx_req_type;
wire [3:0]  wv_reg_keyctx_req_opcode;

//ceu req cause dma read ctx req to dma_read_ctx module
wire ceu_has_dma_rd;
//ceu req cause dma write ctx req to dma_write_ctx module
wire ceu_has_dma_wr;
//key_qpc_data req cause dma write ctx req to dma_write_ctx module
wire keyctx_has_dma_wr;

//ceu req cause ctxmdata read op
wire ceu_has_mdata_rd;

/*Spyglass*/
//ceu req cause ctxmdata write op
//wire ceu_has_mdata_wr;
/*Action = Delete*/

//key_qpc_data req cause ctxmdata read op
wire keyctx_has_mdata_rd;

wire [31:0] wv_chunk_num;  //total chunk num in 1 ceu req
wire [31:0] wv_payload_num;//total context metadata payload number
wire [1:0] wv_dma_req_num;//total dma req number derived from 1 ceu or key_qpc_data req
wire mdt_op_finish;//signal for context metadata read write operation finish, used for judge step into DMA_PROC

/*VCS*/
wire [11:0] wv_page_num;//total page num of 1 chunk
/*Action = Add*/


//ctxmdata_ila ctxmdata_ila (
//    .clk(clk),
//    .probe0(wv_qpc_base),//64 bit
//    .probe1(wv_cqc_base),//64 bit
//    .probe2(wv_eqc_base),//64 bit
//    .probe3(wv_payload_num),//32 bit
//    .probe4(qv_payload_cnt),//32 bit
//    .probe5(qv_temp_ceu_req_hd),//128 bit
//    .probe6(qv_temp_ceu_paylaod)//256 bit
//);

//qpcmdata_ila qpcmdata_ila (
//    .clk(clk),
//    .probe0(qpcm_wr_en),//1 
//    .probe1(qpcm_wr_addr),//10 
//    .probe2(qpcm_wr_data),//52
//    .probe3(qpcm_rd_en),//1 
//    .probe4(qpcm_rd_addr),//10
//    .probe5(qpcm_rd_data)//52
//);
//cqcmdata_ila cqcmdata_ila (
//    .clk(clk),
//    .probe0(cqcm_wr_en),//1 
//    .probe1(cqcm_wr_addr),//8
//    .probe2(cqcm_wr_data),//52
//    .probe3(cqcm_rd_en),//1 
//    .probe4(cqcm_rd_addr),//8
//    .probe5(cqcm_rd_data)//52
//);

// eqcmdata_ila eqcmdata_ila (
//     .clk(clk),
//     .probe0(eqc_page_addr)//52 
// );

assign wv_ceu_req_type =  ceu_req_ctxmdata_dout[127:128-`AXIS_TYPE_WIDTH];
assign wv_ceu_req_opcode= ceu_req_ctxmdata_dout[127-`AXIS_TYPE_WIDTH:128-`AXIS_OPCODE_WIDTH-`AXIS_TYPE_WIDTH];
assign wv_keyctx_req_type =  key_ctx_req_mdt_dout[127:128-`AXIS_TYPE_WIDTH];
assign wv_keyctx_req_opcode= key_ctx_req_mdt_dout[127-`AXIS_TYPE_WIDTH:128-`AXIS_OPCODE_WIDTH-`AXIS_TYPE_WIDTH];

assign ctx_have_payload = ((wv_ceu_req_type == `WR_QP_CTX) && (wv_ceu_req_opcode == `WR_QP_ALL)) || ((wv_ceu_req_type == `WR_CQ_CTX) && (wv_ceu_req_opcode == `WR_CQ_ALL)) || ((wv_ceu_req_type == `WR_CQ_CTX) && (wv_ceu_req_opcode == `WR_CQ_MODIFY)) || ((wv_ceu_req_type == `WR_EQ_CTX) && (wv_ceu_req_opcode == `WR_EQ_ALL));
assign ctx_no_payload =  ((wv_ceu_req_type == `WR_CQ_CTX) && (wv_ceu_req_opcode == `WR_CQ_INVALID)) || ((wv_ceu_req_type == `WR_EQ_CTX) && (wv_ceu_req_opcode == `WR_EQ_INVALID)) || ((wv_ceu_req_type == `WR_EQ_CTX) && (wv_ceu_req_opcode == `WR_EQ_FUNC)) || ((wv_ceu_req_type == `RD_QP_CTX) && (wv_ceu_req_opcode == `RD_QP_ALL));
assign mdata_have_payload =  ((wv_ceu_req_type == `MAP_ICM_CTX) && (wv_ceu_req_opcode == `MAP_ICM_EN)) || ((wv_ceu_req_type == `WR_ICMMAP_CTX) && (wv_ceu_req_opcode == `WR_ICMMAP_EN));
assign mdata_no_payload =  ((wv_ceu_req_type == `MAP_ICM_CTX) && (wv_ceu_req_opcode == `MAP_ICM_DIS)) || ((wv_ceu_req_type == `WR_ICMMAP_CTX) && (wv_ceu_req_opcode == `WR_ICMMAP_DIS));

assign keyqpc_no_payload = ((wv_keyctx_req_type == `WR_QP_CTX) && ((wv_keyctx_req_opcode == `WR_QP_STATE) || (wv_keyctx_req_opcode == `WR_QP_UAPST) || (wv_keyctx_req_opcode == `WR_QP_NPST) || (wv_keyctx_req_opcode == `WR_QP_EPST)));

assign  wv_reg_ceu_req_type      = qv_temp_ceu_req_hd[127:128-`AXIS_TYPE_WIDTH];
assign  wv_reg_ceu_req_opcode    = qv_temp_ceu_req_hd[127-`AXIS_TYPE_WIDTH:128-`AXIS_OPCODE_WIDTH-`AXIS_TYPE_WIDTH];
assign  wv_reg_keyctx_req_type   = qv_temp_keyctx_req_hd[127:128-`AXIS_TYPE_WIDTH];
assign  wv_reg_keyctx_req_opcode = qv_temp_keyctx_req_hd[127-`AXIS_TYPE_WIDTH:128-`AXIS_OPCODE_WIDTH-`AXIS_TYPE_WIDTH];

assign ceu_has_dma_rd  = ((wv_reg_ceu_req_type == `RD_QP_CTX) && (wv_reg_ceu_req_opcode == `RD_QP_ALL));
assign ceu_has_dma_wr  = ((wv_reg_ceu_req_type == `WR_CQ_CTX) || (wv_reg_ceu_req_type == `WR_EQ_CTX) || (wv_reg_ceu_req_type == `WR_QP_CTX));
assign keyctx_has_dma_wr = ((wv_reg_keyctx_req_type == `WR_QP_CTX) && ((wv_reg_keyctx_req_opcode == `WR_QP_STATE) || (wv_reg_keyctx_req_opcode == `WR_QP_UAPST) || (wv_reg_keyctx_req_opcode == `WR_QP_NPST) || (wv_reg_keyctx_req_opcode == `WR_QP_EPST)));

assign ceu_has_mdata_rd     = ceu_has_dma_rd || ceu_has_dma_wr;
/*Spyglass*/
//assign ceu_has_mdata_wr     = ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN)) || ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_DIS)) || ((wv_reg_ceu_req_type == `WR_ICMMAP_CTX) && (wv_reg_ceu_req_opcode == `WR_ICMMAP_EN)) || ((wv_reg_ceu_req_type == `WR_ICMMAP_CTX) && (wv_reg_ceu_req_opcode == `WR_ICMMAP_DIS));
/*Action = Delete*/

assign keyctx_has_mdata_rd  = keyctx_has_dma_wr;

//-----------------------------state mechine-------------------------------
//registers
reg [2:0] fsm_cs;
reg [2:0] fsm_ns;

//state machine parameters
//RCV_REQ
parameter RCV_REQ  = 3'b001;
//ctxmdata read/write operation processing
parameter MDT_PROC = 3'b010;
//initiate dma request
parameter DMA_PROC = 3'b100;

//-----------------Stage 1 :State Register----------
always @(posedge clk or posedge rst) begin
    if(rst)
        fsm_cs <= `TD RCV_REQ;
    else
        fsm_cs <= `TD fsm_ns;
end

//-----------------Stage 2 :State Transition----------
always @(*) begin
    case (fsm_cs)
        RCV_REQ: begin
            //ceu_parser req not empty(no payload) || ceu_parser req & data not empty(has payload) || key_qpc_data req not empty
            if((!ceu_req_ctxmdata_empty && !ctxmdata_data_empty && mdata_have_payload) || ((mdata_no_payload || ctx_have_payload || ctx_no_payload) && !ceu_req_ctxmdata_empty) || (keyqpc_no_payload && !key_ctx_req_mdt_empty && ceu_req_ctxmdata_empty)) begin
                fsm_ns = MDT_PROC;
            end
            else
                fsm_ns = RCV_REQ;
        end 
        MDT_PROC: begin
            if (mdt_op_finish && ((ceu_has_dma_rd && !mdt_req_rd_ctx_prog_full) || ((ceu_has_dma_wr || keyctx_has_dma_wr) && !mdt_req_wr_ctx_prog_full))) begin
                fsm_ns = DMA_PROC;
            end
            else if (!mdt_op_finish || (mdt_op_finish && ((ceu_has_dma_rd && mdt_req_rd_ctx_prog_full) || ((ceu_has_dma_wr || keyctx_has_dma_wr) && mdt_req_wr_ctx_prog_full)))) begin
                fsm_ns = MDT_PROC;
            end
            else begin
                fsm_ns = RCV_REQ;
            end
        end
        DMA_PROC: begin
            if ((qv_dma_req_cnt + 1 == wv_dma_req_num) && ((ceu_has_dma_rd && !mdt_req_rd_ctx_prog_full) || ((ceu_has_dma_wr || keyctx_has_dma_wr) && !mdt_req_wr_ctx_prog_full))) begin
                fsm_ns = RCV_REQ;
            end else begin
                fsm_ns = DMA_PROC;
            end
        end
        default: fsm_ns = RCV_REQ;
    endcase
end

//-----------------Stage 3 :Output Decode--------------------
// internal ceu_parser req cmd to ctxmdata Module
    //53 width 16 depth syn FIFO
    //    output  wire                      ceu_req_ctxmdata_rd_en,
    // read ceu req if ceu_parser req not empty(no payload) || ceu_parser req & data not empty(has payload)
assign ceu_req_ctxmdata_rd_en = (fsm_cs == RCV_REQ) && ((!ceu_req_ctxmdata_empty && !ctxmdata_data_empty && mdata_have_payload) || ((mdata_no_payload || ctx_have_payload || ctx_no_payload))) && !ceu_req_ctxmdata_empty;

// internel context metaddata payload to write ctxmdata Module
    // 256 width 24 depth syn FIFO (only context meatadata)
    //    output  wire                     ctxmdata_data_rd_en,
    // read ceu context metadata payload at RCV_REQ state with req together, at MDT_PROC state, read them when 2 chunk entries has written and there're still payload need written
assign ctxmdata_data_rd_en = ((fsm_cs == RCV_REQ) && !ceu_req_ctxmdata_empty && !ctxmdata_data_empty && mdata_have_payload && !ceu_req_ctxmdata_empty) || ((fsm_cs == MDT_PROC) && (qv_payload_cnt < wv_payload_num) && (qv_chunk_cnt[0]==1'b0) && (qv_chunk_cnt < wv_chunk_num) && (wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && (qv_page_cnt + 1 >= wv_page_num) && !ctxmdata_data_empty);
//internal key_qpc_data Request In interface
    //    output wire                      key_ctx_req_mdt_rd_en,
    // read key_qpc_data req if key_qpc_data req not empty and ceu req is empty
assign key_ctx_req_mdt_rd_en = (fsm_cs == RCV_REQ) && keyqpc_no_payload && !key_ctx_req_mdt_empty && ceu_req_ctxmdata_empty;

//reg [`HD_WIDTH-1:0] qv_temp_ceu_req_hd;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_temp_ceu_req_hd <= `TD 128'b0;
    end
    else if (ceu_req_ctxmdata_rd_en && (fsm_cs == RCV_REQ)) begin
        qv_temp_ceu_req_hd <= `TD ceu_req_ctxmdata_dout;
    end
    else if (!ceu_req_ctxmdata_rd_en && (fsm_cs == RCV_REQ)) begin
        qv_temp_ceu_req_hd <= `TD 128'b0;
    end
    else begin
        qv_temp_ceu_req_hd <= `TD qv_temp_ceu_req_hd;
    end
end
//reg [`HD_WIDTH-1:0] qv_temp_keyctx_req_hd;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_temp_keyctx_req_hd <= `TD 128'b0;
    end
    else if (key_ctx_req_mdt_rd_en && (fsm_cs == RCV_REQ)) begin
        qv_temp_keyctx_req_hd <= `TD key_ctx_req_mdt_dout;
    end
    else if (!key_ctx_req_mdt_rd_en && (fsm_cs == RCV_REQ)) begin
        qv_temp_keyctx_req_hd <= `TD 128'b0;
    end
    else begin
        qv_temp_keyctx_req_hd <= `TD qv_temp_keyctx_req_hd;
    end
end
//reg [`DT_WIDTH-1:0] qv_temp_ceu_paylaod;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_temp_ceu_paylaod <= `TD 256'b0;
    end
    else if (ctxmdata_data_rd_en) begin
        qv_temp_ceu_paylaod <= `TD ctxmdata_data_dout;
    end
    else if (!ctxmdata_data_rd_en && (fsm_cs == MDT_PROC)) begin
        qv_temp_ceu_paylaod <= `TD qv_temp_ceu_paylaod;
    end
    else begin
        qv_temp_ceu_paylaod <= `TD 256'b0;
    end
end
//reg [31:0] qv_chunk_cnt;  //count for context metadata chunk number, changed at the same clk as wr_en signal for RAM
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_chunk_cnt <= `TD 32'b0;
    end
    /*VCS*/
    //if MDT_PROC state and mdata req has payload, chunk counte number < total chunk number, increase the chunk counter
    // else if ((fsm_cs == MDT_PROC) && (qv_chunk_cnt < wv_chunk_num)) begin
    //     qv_chunk_cnt <= `TD qv_chunk_cnt + 1;
    // end
    else if ((fsm_cs == RCV_REQ) && (wv_ceu_req_type == `MAP_ICM_CTX) && (wv_ceu_req_opcode == `MAP_ICM_EN) && !ceu_req_ctxmdata_empty && !ctxmdata_data_empty) begin
        qv_chunk_cnt <= `TD 1;
    end
    else if ((fsm_cs == MDT_PROC) && (qv_chunk_cnt < wv_chunk_num) && (wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && (qv_page_cnt + 1 >= wv_page_num) && (((qv_chunk_cnt[0] == 1'b0) && !ctxmdata_data_empty) || (qv_chunk_cnt[0] == 1'b1))) begin
        qv_chunk_cnt <= `TD qv_chunk_cnt + 1;
    end
    /**Action = Modify*/
    //hold the chunk cnt value
    else if (fsm_cs == MDT_PROC) begin
        qv_chunk_cnt <= `TD qv_chunk_cnt;
    end
    else begin
        qv_chunk_cnt <= `TD 32'b0;
    end
end
//reg [31:0] qv_payload_cnt;//count for context metadata number
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_payload_cnt <= `TD 32'b0;
    end
    //once read ctxmdata, increase the payload counter
    else if (ctxmdata_data_rd_en) begin
        qv_payload_cnt <= `TD qv_payload_cnt + 1;
    end
    else if (fsm_cs == MDT_PROC) begin
        qv_payload_cnt <= `TD qv_payload_cnt;
    end
    else begin
        qv_payload_cnt <= `TD 32'b0;
    end
end

/*VCS*/
//reg [11:0] qv_page_cnt;//count for physical page num of 1 chunk
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_page_cnt <= `TD 12'b0;
    end 
    else if ((fsm_cs == MDT_PROC) && (qv_chunk_cnt <= wv_chunk_num) && (wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && (qv_page_cnt + 1 < wv_page_num)) begin
        qv_page_cnt <= `TD qv_page_cnt + 1;
    end
    else if ((fsm_cs == MDT_PROC) && (qv_chunk_cnt < wv_chunk_num) && (wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && (qv_page_cnt + 1 == wv_page_num) && (((qv_chunk_cnt[0] == 1'b0) && !ctxmdata_data_empty) || (qv_chunk_cnt[0] == 1'b1))) begin
        qv_page_cnt <= `TD 12'b0;
    end
    else if ((fsm_cs == MDT_PROC) && (qv_chunk_cnt < wv_chunk_num) && (wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN)) begin
        qv_page_cnt <= `TD qv_page_cnt;
    end
    else begin
        qv_page_cnt <= `TD 12'b0;
    end
end
/*Action = Add*/

//reg [1:0] qv_dma_req_cnt;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_dma_req_cnt <= `TD 2'b0;
    end
    //in DMA_PROC state, if dma req counter < total dma req num, and the dest dma req out fifo isn't full, increase the dma req counter
    else if ((fsm_cs == DMA_PROC) && (qv_dma_req_cnt < wv_dma_req_num) && ((ceu_has_dma_rd && !mdt_req_rd_ctx_prog_full) || ((ceu_has_dma_wr || keyctx_has_dma_wr) && !mdt_req_wr_ctx_prog_full))) begin
        qv_dma_req_cnt <= `TD qv_dma_req_cnt +1;
    end
    else if ((fsm_cs == DMA_PROC)) begin
        qv_dma_req_cnt <= `TD qv_dma_req_cnt;
    end
    else begin
        qv_dma_req_cnt <= `TD 2'b0;
    end
end

//wire [31:0] wv_chunk_num;  //total chunk num in 1 ceu req
assign wv_chunk_num = ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN)) ? qv_temp_ceu_req_hd[95:64] : 32'b0;

//wire [31:0] wv_payload_num;//total context metadata payload number
// chunk_num % 2 + chunk_num / 2 = payload_num assign wv_payload_num =
assign wv_payload_num = {1'b0,wv_chunk_num[31:1]} + {31'b0,wv_chunk_num[0]};

//wire [1:0] wv_dma_req_num;
//total dma req number, WR_QP_UAPST & WR_QP_NPST & WR_QP_EPST req will derived 2 dma write req, because the 2 seg in paylaod in non-contiguous addr
assign wv_dma_req_num = (ceu_has_dma_rd || ceu_has_dma_wr || ((wv_reg_keyctx_req_type == `WR_QP_CTX) && (wv_reg_keyctx_req_opcode == `WR_QP_STATE))) ? 1: ((wv_reg_keyctx_req_type == `WR_QP_CTX) && ((wv_reg_keyctx_req_opcode == `WR_QP_UAPST) || (wv_reg_keyctx_req_opcode == `WR_QP_NPST) || (wv_reg_keyctx_req_opcode == `WR_QP_EPST))) ? 2'b10 : 2'b0;

/*VCS*/
//wire [11:0] wv_page_num;//total page num of 1 chunk
assign wv_page_num = ((fsm_cs == MDT_PROC) && (wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && (qv_chunk_cnt[0] == 1'b1)) ? qv_temp_ceu_paylaod[11:0] : ((fsm_cs == MDT_PROC) && (wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && (qv_chunk_cnt[0] == 1'b0)) ? qv_temp_ceu_paylaod[139:128] : 12'b0;
/*Action = Add*/

/*VCS*/
//wire mdt_op_finish;
//MAP_ICM_EN operation has chunk_num*page_num cycles derived operation on Metadata RAM, other operation can be peocessed completely in 1 cycle.
// assign mdt_op_finish = ceu_has_mdata_rd || keyctx_has_mdata_rd || (((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN)) && (qv_chunk_cnt+1 == wv_chunk_num)) || ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_DIS)) || ((wv_reg_ceu_req_type == `WR_ICMMAP_CTX) && (wv_reg_ceu_req_opcode == `WR_ICMMAP_EN)) || ((wv_reg_ceu_req_type == `WR_ICMMAP_CTX) && (wv_reg_ceu_req_opcode == `WR_ICMMAP_DIS));
assign mdt_op_finish = ceu_has_mdata_rd || keyctx_has_mdata_rd || (((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN)) && (qv_chunk_cnt == wv_chunk_num) && (qv_page_cnt + 1 >= wv_page_num)) || ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_DIS)) || ((wv_reg_ceu_req_type == `WR_ICMMAP_CTX) && (wv_reg_ceu_req_opcode == `WR_ICMMAP_EN)) || ((wv_reg_ceu_req_type == `WR_ICMMAP_CTX) && (wv_reg_ceu_req_opcode == `WR_ICMMAP_DIS));
/*Action = Modify*/

//use the virtual addr and qpc_base/cqc_base/eqc_base to jude the mdata belongs to which area
    //reg qpc_map;
    //reg cqc_map;
    //reg eqc_map;
    //reg qpc_unmap;
    //reg cqc_unmap;
    //reg eqc_unmap;
always @(*) begin
    if (rst) begin
        qpc_map = 0;
        cqc_map = 0;
        eqc_map = 0;
        qpc_unmap = 0;
        cqc_unmap = 0;
        eqc_unmap = 0;
    end 
    else begin
        case ({(wv_qpc_base > wv_cqc_base),(wv_qpc_base > wv_eqc_base),(wv_cqc_base > wv_eqc_base)})
        /*VCS Verification*/
            //eqc > cqc > qpc
            3'b000: begin
                //MAP_ICM_EN
                /*VCS Verification*/
                //if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN)) begin
                if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && qv_chunk_cnt[0] && (fsm_cs == MDT_PROC)) begin
                /*Action = Modify, Add qv_chunk_num condition to decide extract low address in payload*/
                    case ({(qv_temp_ceu_paylaod[127:64] >= wv_eqc_base),(qv_temp_ceu_paylaod[127:64] >= wv_cqc_base),(qv_temp_ceu_paylaod[127:64] >= wv_qpc_base)})
                        3'b111:begin
                            qpc_map = 0;
                            cqc_map = 0;
                            eqc_map = 1;
                        end
                        3'b011:begin
                            qpc_map = 0;
                            cqc_map = 1;
                            eqc_map = 0;
                        end
                        3'b001:begin
                            qpc_map = 1;
                            cqc_map = 0;
                            eqc_map = 0;
                        end                         
                        default: begin
                            qpc_map = 0;
                            cqc_map = 0;
                            eqc_map = 0;
                        end
                    endcase
                    qpc_unmap = 0;
                    cqc_unmap = 0;
                    eqc_unmap = 0;
                end
                /*VCS Verification*/
                else if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && !qv_chunk_cnt[0] && (fsm_cs == MDT_PROC)) begin
                    case ({(qv_temp_ceu_paylaod[(127+128):(64+128)] >= wv_eqc_base),(qv_temp_ceu_paylaod[(127+128):(64+128)] >= wv_cqc_base),(qv_temp_ceu_paylaod[(127+128):(64+128)] >= wv_qpc_base)})
                        3'b111:begin
                             qpc_map = 0;
                             cqc_map = 0;
                             eqc_map = 1;
                         end
                        3'b011:begin
                            qpc_map = 0;
                            cqc_map = 1;
                            eqc_map = 0;
                        end
                        3'b001:begin
                            qpc_map = 1;
                            cqc_map = 0;
                            eqc_map = 0;
                        end                         
                        default: begin
                            qpc_map = 0;
                            cqc_map = 0;
                            eqc_map = 0;
                        end
                    endcase
                    qpc_unmap = 0;
                    cqc_unmap = 0;
                    eqc_unmap = 0;
                end
                /*Action = Add, Add qv_chunk_num condition to extract high address in payload*/

                //MAP_ICM_DIS
                else if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_DIS)) begin
                    case ({(qv_temp_ceu_req_hd[63:0] >= wv_eqc_base),(qv_temp_ceu_req_hd[63:0]>= wv_cqc_base),(qv_temp_ceu_req_hd[63:0] >= wv_qpc_base)})
                        3'b111:begin
                            qpc_unmap = 0;
                            cqc_unmap = 0;
                            eqc_unmap = 1;
                        end
                        3'b011:begin
                            qpc_unmap = 0;
                            cqc_unmap = 1;
                            eqc_unmap = 0;
                        end
                        3'b001:begin
                            qpc_unmap = 1;
                            cqc_unmap = 0;
                            eqc_unmap = 0;
                        end                         
                        default: begin
                            qpc_unmap = 0;
                            cqc_unmap = 0;
                            eqc_unmap = 0;
                        end
                    endcase
                    qpc_map = 0;
                    cqc_map = 0;
                    eqc_map = 0;
                end
                else begin
                    qpc_map = 0;
                    cqc_map = 0;
                    eqc_map = 0;
                    qpc_unmap = 0;
                    cqc_unmap = 0;
                    eqc_unmap = 0;
                end
            end
            //cqc > eqc > qpc
            3'b001:begin
                //MAP_ICM_EN
                /*VCS Verification*/
                //if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN)) begin
                if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && qv_chunk_cnt[0] && (fsm_cs == MDT_PROC)) begin
                /*Action = Modify, Add qv_chunk_num condition to decide extract low address in payload*/
                    case ({(qv_temp_ceu_paylaod[127:64] >= wv_cqc_base),(qv_temp_ceu_paylaod[127:64] >= wv_eqc_base),(qv_temp_ceu_paylaod[127:64] >= wv_qpc_base)})
                        3'b111:begin
                            qpc_map = 0;
                            eqc_map = 0;
                            cqc_map = 1;
                        end
                        3'b011:begin
                            qpc_map = 0;
                            eqc_map = 1;
                            cqc_map = 0;
                        end
                        3'b001:begin
                            qpc_map = 1;
                            eqc_map = 0;
                            cqc_map = 0;
                        end                         
                        default: begin
                            qpc_map = 0;
                            eqc_map = 0;
                            cqc_map = 0;
                        end
                    endcase
                    qpc_unmap = 0;
                    eqc_unmap = 0;
                    cqc_unmap = 0;
                end
                /*VCS Verification*/
                else if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && !qv_chunk_cnt[0] && (fsm_cs == MDT_PROC)) begin
                    case ({(qv_temp_ceu_paylaod[(127+128):(64+128)] >= wv_cqc_base),(qv_temp_ceu_paylaod[(127+128):(64+128)] >= wv_eqc_base),(qv_temp_ceu_paylaod[(127+128):(64+128)] >= wv_qpc_base)})
                        3'b111:begin
                            qpc_map = 0;
                            eqc_map = 0;
                            cqc_map = 1;
                        end
                        3'b011:begin
                             qpc_map = 0;
                             eqc_map = 1;
                             cqc_map = 0;
                        end
                        3'b001:begin
                            qpc_map = 1;
                            eqc_map = 0;
                            cqc_map = 0;
                        end                         
                        default: begin
                            qpc_map = 0;
                            eqc_map = 0;
                            cqc_map = 0;
                        end
                    endcase
                    qpc_unmap = 0;
                    eqc_unmap = 0;
                    cqc_unmap = 0;
                end
                /*Action = Add, Add qv_chunk_num condition to extract high address in payload*/
                //MAP_ICM_DIS
                else if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_DIS)) begin
                    case ({(qv_temp_ceu_req_hd[63:0] >= wv_cqc_base),(qv_temp_ceu_req_hd[63:0]>= wv_eqc_base),(qv_temp_ceu_req_hd[63:0] >= wv_qpc_base)})
                        3'b111:begin
                            qpc_unmap = 0;
                            eqc_unmap = 0;
                            cqc_unmap = 1;
                        end
                        3'b011:begin
                            qpc_unmap = 0;
                            eqc_unmap = 1;
                            cqc_unmap = 0;
                        end
                        3'b001:begin
                            qpc_unmap = 1;
                            eqc_unmap = 0;
                            cqc_unmap = 0;
                        end                         
                        default: begin
                            qpc_unmap = 0;
                            eqc_unmap = 0;
                            cqc_unmap = 0;
                        end                        
                    endcase
                    qpc_map = 0;
                    eqc_map = 0;
                    cqc_map = 0;
                end
                else begin
                    qpc_map = 0;
                    cqc_map = 0;
                    eqc_map = 0;
                    qpc_unmap = 0;
                    cqc_unmap = 0;
                    eqc_unmap = 0;
                end
            end
            //cqc > qpc > eqc
            3'b011:begin
                //MAP_ICM_EN
                /*VCS Verification*/
                //if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN)) begin
                if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && qv_chunk_cnt[0] && (fsm_cs == MDT_PROC)) begin
                /*Action = Modify, Add qv_chunk_num condition to decide extract low address in payload*/
                    case ({(qv_temp_ceu_paylaod[127:64] >= wv_cqc_base),(qv_temp_ceu_paylaod[127:64] >= wv_qpc_base),(qv_temp_ceu_paylaod[127:64] >= wv_eqc_base)})
                        3'b111:begin
                            eqc_map = 0;
                            qpc_map = 0;
                            cqc_map = 1;
                        end
                        3'b011:begin
                            eqc_map = 0;
                            qpc_map = 1;
                            cqc_map = 0;
                        end
                        3'b001:begin
                            eqc_map = 1;
                            qpc_map = 0;
                            cqc_map = 0;
                        end                         
                        default: begin
                            eqc_map = 0;
                            qpc_map = 0;
                            cqc_map = 0;
                        end                        
                    endcase
                    eqc_unmap = 0;
                    qpc_unmap = 0;
                    cqc_unmap = 0;
                end
                else if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && !qv_chunk_cnt[0] && (fsm_cs == MDT_PROC)) begin
                    case ({(qv_temp_ceu_paylaod[(127+128):(64+128)] >= wv_cqc_base),(qv_temp_ceu_paylaod[(127+128):(64+128)] >= wv_qpc_base),(qv_temp_ceu_paylaod[(127+128):(64+128)] >= wv_eqc_base)})
                        3'b111:begin
                            eqc_map = 0;
                            qpc_map = 0;
                            cqc_map = 1;
                        end
                        3'b011:begin
                            eqc_map = 0;
                            qpc_map = 1;
                            cqc_map = 0;
                        end
                        3'b001:begin
                             eqc_map = 1;
                             qpc_map = 0;
                             cqc_map = 0;
                        end                         
                        default: begin
                            eqc_map = 0;
                            qpc_map = 0;
                            cqc_map = 0;
                        end                        
                    endcase
                    eqc_unmap = 0;
                    qpc_unmap = 0;
                    cqc_unmap = 0;
                end
                /*Action = Add, Add qv_chunk_num condition to extract high address in payload*/
                //MAP_ICM_DIS
                else if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_DIS)) begin
                    case ({(qv_temp_ceu_req_hd[63:0] >= wv_cqc_base),(qv_temp_ceu_req_hd[63:0]>= wv_qpc_base),(qv_temp_ceu_req_hd[63:0] >= wv_eqc_base)})
                        3'b111:begin
                            eqc_unmap = 0;
                            qpc_unmap = 0;
                            cqc_unmap = 1;
                        end
                        3'b011:begin
                            eqc_unmap = 0;
                            qpc_unmap = 1;
                            cqc_unmap = 0;
                        end
                        3'b001:begin
                            eqc_unmap = 1;
                            qpc_unmap = 0;
                            cqc_unmap = 0;
                        end                         
                        default: begin
                            eqc_unmap = 0;
                            qpc_unmap = 0;
                            cqc_unmap = 0;
                        end
                    endcase
                    eqc_map = 0;
                    qpc_map = 0;
                    cqc_map = 0;
                end
                else begin
                    qpc_map = 0;
                    cqc_map = 0;
                    eqc_map = 0;
                    qpc_unmap = 0;
                    cqc_unmap = 0;
                    eqc_unmap = 0;
                end
            end
            //eqc > qpc > cqc
            3'b100:begin
                //MAP_ICM_EN
                /*VCS Verification*/
                //if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN)) begin
                if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && qv_chunk_cnt[0] && (fsm_cs == MDT_PROC)) begin
                /*Action = Modify, Add qv_chunk_num condition to decide extract low address in payload*/
                    case ({(qv_temp_ceu_paylaod[127:64] >= wv_eqc_base),(qv_temp_ceu_paylaod[127:64] >= wv_qpc_base),(qv_temp_ceu_paylaod[127:64] >= wv_cqc_base)})
                        3'b111:begin
                            cqc_map = 0;
                            qpc_map = 0;
                            eqc_map = 1;
                        end
                        3'b011:begin
                            cqc_map = 0;
                            qpc_map = 1;
                            eqc_map = 0;
                        end
                        3'b001:begin
                            cqc_map = 1;
                            qpc_map = 0;
                            eqc_map = 0;
                        end                         
                        default: begin
                            cqc_map = 0;
                            qpc_map = 0;
                            eqc_map = 0;
                        end
                    endcase
                    cqc_unmap = 0;
                    qpc_unmap = 0;
                    eqc_unmap = 0;
                end
                /*VCS Verification*/
                else if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && !qv_chunk_cnt[0] && (fsm_cs == MDT_PROC)) begin
                    case ({(qv_temp_ceu_paylaod[(127+128):(64+128)] >= wv_eqc_base),(qv_temp_ceu_paylaod[(127+128):(64+128)] >= wv_qpc_base),(qv_temp_ceu_paylaod[(127+128):(64+128)] >= wv_cqc_base)})
                        3'b111:begin
                             cqc_map = 0;
                             qpc_map = 0;
                             eqc_map = 1;
                        end
                        3'b011:begin
                            cqc_map = 0;
                            qpc_map = 1;
                            eqc_map = 0;
                        end
                        3'b001:begin
                            cqc_map = 1;
                            qpc_map = 0;
                            eqc_map = 0;
                        end                         
                        default: begin
                            cqc_map = 0;
                            qpc_map = 0;
                            eqc_map = 0;
                        end
                    endcase
                    cqc_unmap = 0;
                    qpc_unmap = 0;
                    eqc_unmap = 0;
                end
                /*Action = Add, Add qv_chunk_num condition to extract high address in payload*/
                //MAP_ICM_DIS
                else if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_DIS)) begin
                    case ({(qv_temp_ceu_req_hd[63:0] >= wv_eqc_base),(qv_temp_ceu_req_hd[63:0]>= wv_qpc_base),(qv_temp_ceu_req_hd[63:0] >= wv_cqc_base)})
                        3'b111:begin
                            cqc_unmap = 0;
                            qpc_unmap = 0;
                            eqc_unmap = 1;
                        end
                        3'b011:begin
                            cqc_unmap = 0;
                            qpc_unmap = 1;
                            eqc_unmap = 0;
                        end
                        3'b001:begin
                            cqc_unmap = 1;
                            qpc_unmap = 0;
                            eqc_unmap = 0;
                        end                         
                        default: begin
                            cqc_unmap = 0;
                            qpc_unmap = 0;
                            eqc_unmap = 0;
                        end
                    endcase
                    cqc_map = 0;
                    qpc_map = 0;
                    eqc_map = 0;
                end
                else begin
                    qpc_map = 0;
                    cqc_map = 0;
                    eqc_map = 0;
                    qpc_unmap = 0;
                    cqc_unmap = 0;
                    eqc_unmap = 0;
                end
            end
            //qpc > eqc > cqc
            3'b110:begin
                //MAP_ICM_EN
                /*VCS Verification*/
                //if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN)) begin
                if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && qv_chunk_cnt[0] && (fsm_cs == MDT_PROC)) begin
                /*Action = Modify, Add qv_chunk_num condition to decide extract low address in payload*/
                    case ({(qv_temp_ceu_paylaod[127:64] >= wv_qpc_base),(qv_temp_ceu_paylaod[127:64] >= wv_eqc_base),(qv_temp_ceu_paylaod[127:64] >= wv_cqc_base)})
                        3'b111:begin
                            cqc_map = 0;
                            eqc_map = 0;
                            qpc_map = 1;
                        end
                        3'b011:begin
                            cqc_map = 0;
                            eqc_map = 1;
                            qpc_map = 0;
                        end
                        3'b001:begin
                            cqc_map = 1;
                            eqc_map = 0;
                            qpc_map = 0;
                        end                         
                        default: begin
                            cqc_map = 0;
                            eqc_map = 0;
                            qpc_map = 0;
                        end                                                         
                    endcase
                    cqc_unmap = 0;
                    eqc_unmap = 0;
                    qpc_unmap = 0;
                end
                /*VCS Verification*/
                else if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && !qv_chunk_cnt[0] && (fsm_cs == MDT_PROC)) begin
                    case ({(qv_temp_ceu_paylaod[(127+128):(64+128)] >= wv_qpc_base),(qv_temp_ceu_paylaod[(127+128):(64+128)] >= wv_eqc_base),(qv_temp_ceu_paylaod[(127+128):(64+128)] >= wv_cqc_base)})
                        3'b111:begin
                            cqc_map = 0;
                            eqc_map = 0;
                            qpc_map = 1;
                        end
                        3'b011:begin
                             cqc_map = 0;
                             eqc_map = 1;
                             qpc_map = 0;
                        end
                        3'b001:begin
                            cqc_map = 1;
                            eqc_map = 0;
                            qpc_map = 0;
                        end                         
                        default: begin
                            cqc_map = 0;
                            eqc_map = 0;
                            qpc_map = 0;
                        end                                                         
                    endcase
                    cqc_unmap = 0;
                    eqc_unmap = 0;
                    qpc_unmap = 0;
                end
                /*Action = Add, Add qv_chunk_num condition to extract high address in payload*/
                //MAP_ICM_DIS
                else if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_DIS)) begin
                    case ({(qv_temp_ceu_req_hd[63:0] >= wv_qpc_base),(qv_temp_ceu_req_hd[63:0]>= wv_eqc_base),(qv_temp_ceu_req_hd[63:0] >= wv_cqc_base)})
                        3'b111:begin
                            cqc_unmap = 0;
                            eqc_unmap = 0;
                            qpc_unmap = 1;
                        end
                        3'b011:begin
                            cqc_unmap = 0;
                            eqc_unmap = 1;
                            qpc_unmap = 0;
                        end
                        3'b001:begin
                            cqc_unmap = 1;
                            eqc_unmap = 0;
                            qpc_unmap = 0;
                        end                         
                        default: begin
                            cqc_unmap = 0;
                            eqc_unmap = 0;
                            qpc_unmap = 0;
                        end
                    endcase
                    cqc_map = 0;
                    eqc_map = 0;
                    qpc_map = 0;
                end
                else begin
                    qpc_map = 0;
                    cqc_map = 0;
                    eqc_map = 0;
                    qpc_unmap = 0;
                    cqc_unmap = 0;
                    eqc_unmap = 0;
                end
            end
            //qpc > cqc > eqc
            3'b111: begin
                //MAP_ICM_EN
                /*VCS Verification*/
                //if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN)) begin
                if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && qv_chunk_cnt[0] && (fsm_cs == MDT_PROC)) begin
                /*Action = Modify, Add qv_chunk_num condition to decide extract low address in payload*/
                    case ({(qv_temp_ceu_paylaod[127:64] >= wv_qpc_base),(qv_temp_ceu_paylaod[127:64] >= wv_cqc_base),(qv_temp_ceu_paylaod[127:64] >= wv_eqc_base)})
                        3'b111:begin
                            eqc_map = 0;
                            cqc_map = 0;
                            qpc_map = 1;
                        end
                        3'b011:begin
                            eqc_map = 0;
                            cqc_map = 1;
                            qpc_map = 0;
                        end
                        3'b001:begin
                            eqc_map = 1;
                            cqc_map = 0;
                            qpc_map = 0;
                        end                         
                        default: begin
                            eqc_map = 0;
                            cqc_map = 0;
                            qpc_map = 0;
                        end
                    endcase
                    eqc_unmap = 0;
                    cqc_unmap = 0;
                    qpc_unmap = 0;
                end
                /*VCS Verification*/
                //if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN)) begin
                else if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && !qv_chunk_cnt[0] && (fsm_cs == MDT_PROC)) begin
                    case ({(qv_temp_ceu_paylaod[(127+128):(64+128)] >= wv_qpc_base),(qv_temp_ceu_paylaod[(127+128):(64+128)] >= wv_cqc_base),(qv_temp_ceu_paylaod[(127+128):(64+128)] >= wv_eqc_base)})
                        3'b111:begin
                            eqc_map = 0;
                            cqc_map = 0;
                            qpc_map = 1;
                        end
                        3'b011:begin
                            eqc_map = 0;
                            cqc_map = 1;
                            qpc_map = 0;
                        end
                        3'b001:begin
                            eqc_map = 1;
                             cqc_map = 0;
                             qpc_map = 0;
                        end                         
                        default: begin
                            eqc_map = 0;
                            cqc_map = 0;
                            qpc_map = 0;
                        end
                    endcase
                    eqc_unmap = 0;
                    cqc_unmap = 0;
                    qpc_unmap = 0;
                end
                /*Action = Add, Add qv_chunk_num condition to extract high address in payload*/
                //MAP_ICM_DIS
                else if ((wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_DIS)) begin
                    case ({(qv_temp_ceu_req_hd[63:0] >= wv_qpc_base),(qv_temp_ceu_req_hd[63:0]>= wv_cqc_base),(qv_temp_ceu_req_hd[63:0] >= wv_eqc_base)})
                        3'b111:begin
                            eqc_unmap = 0;
                            cqc_unmap = 0;
                            qpc_unmap = 1;
                        end
                        3'b011:begin
                            eqc_unmap = 0;
                            cqc_unmap = 1;
                            qpc_unmap = 0;
                        end
                        3'b001:begin
                            eqc_unmap = 1;
                            cqc_unmap = 0;
                            qpc_unmap = 0;
                        end                         
                        default: begin
                            eqc_unmap = 0;
                            cqc_unmap = 0;
                            qpc_unmap = 0;
                        end
                    endcase
                    eqc_map = 0;
                    cqc_map = 0;
                    qpc_map = 0;
                end
                else begin
                    qpc_map = 0;
                    cqc_map = 0;
                    eqc_map = 0;
                    qpc_unmap = 0;
                    cqc_unmap = 0;
                    eqc_unmap = 0;
                end
            end
            default: begin
                qpc_map = 0;
                cqc_map = 0;
                eqc_map = 0;
                qpc_unmap = 0;
                cqc_unmap = 0;
                eqc_unmap = 0;
            end
        endcase
        /*Action = Modify, repalce the compare operation ">" with ">=" */
    end
end
//store the qpc_base/cqc_base/eqc_base
    //reg [63:0] wv_qpc_base;
    //reg [63:0] wv_cqc_base;
    //reg [63:0] wv_eqc_base;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_qpc_base <= `TD 0;
        qv_cqc_base <= `TD 0;
        qv_eqc_base <= `TD 0;
    end
    else if ((wv_reg_ceu_req_type == `WR_ICMMAP_CTX) && (wv_reg_ceu_req_opcode == `WR_ICMMAP_EN) && (fsm_cs == MDT_PROC)) begin
        qv_qpc_base <= `TD qv_temp_ceu_paylaod[(64*3-1) : (64*2+8)];
        qv_cqc_base <= `TD qv_temp_ceu_paylaod[(64*2-1) : (64*1+8)];
        qv_eqc_base <= `TD qv_temp_ceu_paylaod[(64*1-1) : (64*0+8)];
    end
    /*VCS Verification*/
    else if ((wv_reg_ceu_req_type == `WR_ICMMAP_CTX) && (wv_reg_ceu_req_opcode == `WR_ICMMAP_DIS) && (fsm_cs == MDT_PROC)) begin
        qv_qpc_base <= `TD 0;
        qv_cqc_base <= `TD 0;
        qv_eqc_base <= `TD 0;
    end
    /*Action = Add*/
    else begin
        qv_qpc_base <= `TD qv_qpc_base;
        qv_cqc_base <= `TD qv_cqc_base;
        qv_eqc_base <= `TD qv_eqc_base;
    end
end

assign wv_qpc_base = {qv_qpc_base,8'b0};
assign wv_cqc_base = {qv_cqc_base,8'b0};
assign wv_eqc_base = {qv_eqc_base,8'b0};

//qpctxmdata RAM write operation //when ceu initiate MAP_ICM_EN req
    //reg                              qpcm_wr_en; 
    //reg    [QPCM_RAM_AWIDTH-1 : 0]   qpcm_wr_addr;
    //reg    [QPCM_RAM_DWIDTH-1 : 0]   qpcm_wr_data;
wire [63:0] qpc_map_low_addr;//qp index = (Virt addr - qpc_base)
wire [63:0] qpc_map_high_addr;//qp index = (Virt addr - qpc_base)
assign qpc_map_low_addr = {qv_temp_ceu_paylaod[127:64]} - wv_qpc_base;
assign qpc_map_high_addr = {qv_temp_ceu_paylaod[255:192]} - wv_qpc_base;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qpcm_wr_en   <= `TD 0; 
        qpcm_wr_addr <= `TD 0;
        qpcm_wr_data <= `TD 0;
    end
    /*VCS*/
    // //get the addr and data from the low 128 of temp paylaod reg
    // //RAM addr = (Virt addr - qpc_base)[21:12]
    // else if ((fsm_cs == MDT_PROC) && (wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && (qv_chunk_cnt < wv_chunk_num) && (qv_chunk_cnt[0] == 0) && qpc_map) begin
    //     qpcm_wr_en   <= `TD 1; 
    //     qpcm_wr_addr <= `TD qpc_map_low_addr[21:12];
    //     qpcm_wr_data <= `TD qv_temp_ceu_paylaod[63:12];
    // end
    // //get the addr and data from the high 128 of temp paylaod reg
    // else if ((fsm_cs == MDT_PROC) && (wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && (qv_chunk_cnt < wv_chunk_num) && (qv_chunk_cnt[0] == 1) && qpc_map) begin
    //     qpcm_wr_en   <= `TD 1; 
    //     qpcm_wr_addr <= `TD qpc_map_high_addr[21:12];
    //     qpcm_wr_data <= `TD qv_temp_ceu_paylaod[63+128:12+128];
    // end
        //get the addr and data from the low 128 of temp paylaod reg
    //RAM addr = (Virt addr - qpc_base)[21:12]
    else if ((fsm_cs == MDT_PROC) && (wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && (qv_chunk_cnt <= wv_chunk_num) && (qv_chunk_cnt[0] == 1'b1) && (qv_page_cnt < wv_page_num) && qpc_map) begin
        qpcm_wr_en   <= `TD 1; 
        qpcm_wr_addr <= `TD qpc_map_low_addr[21:12] + qv_page_cnt[9:0];
        qpcm_wr_data <= `TD qv_temp_ceu_paylaod[63:12] + {40'b0,qv_page_cnt};
    end
    //get the addr and data from the high 128 of temp paylaod reg
    else if ((fsm_cs == MDT_PROC) && (wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && (qv_chunk_cnt <= wv_chunk_num) && (qv_chunk_cnt[0] == 1'b0) && (qv_page_cnt < wv_page_num) && qpc_map) begin
        qpcm_wr_en   <= `TD 1; 
        qpcm_wr_addr <= `TD qpc_map_high_addr[21:12] + qv_page_cnt[9:0];;
        qpcm_wr_data <= `TD qv_temp_ceu_paylaod[63+128:12+128] + {40'b0,qv_page_cnt};;
    end
    /*Action = Modify*/
    else begin
        qpcm_wr_en   <= `TD 0;
        qpcm_wr_addr <= `TD 0;
        qpcm_wr_data <= `TD 0;
    end
end
//qpctxmdata RAM read operation
    //reg                              qpcm_rd_en;
    //reg    [QPCM_RAM_AWIDTH-1 : 0]   qpcm_rd_addr;
wire [63:0] qpcm_compute_addr;
assign qpcm_compute_addr = (((wv_reg_ceu_req_type == `RD_QP_CTX) && (wv_reg_ceu_req_opcode == `RD_QP_ALL)) || (wv_reg_ceu_req_type == `WR_QP_CTX)) ? {24'b0,qv_temp_ceu_req_hd[95:64],8'b0} : keyctx_has_mdata_rd ? {24'b0,qv_temp_keyctx_req_hd[95:64],8'b0} : 0;
/*VCS Verification*/
// always @(posedge clk or posedge rst) begin
//     if (rst) begin
//         qpcm_rd_en    <= `TD 0;
//         qpcm_rd_addr  <= `TD 0;
//     end
//     else if ((fsm_cs == MDT_PROC) &&(((wv_reg_ceu_req_type == `RD_QP_CTX) && (wv_reg_ceu_req_opcode == `RD_QP_ALL)) || (wv_reg_ceu_req_type == `WR_QP_CTX) || keyctx_has_mdata_rd)) begin
//         qpcm_rd_en    <= `TD 1;
//         qpcm_rd_addr  <= `TD qpcm_compute_addr[21:12];
//     end
//     else begin
//         qpcm_rd_en    <= `TD 0;
//         qpcm_rd_addr  <= `TD 0;
//     end
// end
always @(*) begin
    if (rst) begin
        qpcm_rd_en   = 0;
        qpcm_rd_addr = 0;
    end
    else if ((fsm_cs == MDT_PROC) &&(((wv_reg_ceu_req_type == `RD_QP_CTX) && (wv_reg_ceu_req_opcode == `RD_QP_ALL)) || (wv_reg_ceu_req_type == `WR_QP_CTX) || keyctx_has_mdata_rd)) begin
        qpcm_rd_en   = 1;
        qpcm_rd_addr = qpcm_compute_addr[21:12];
    end
    else begin
        qpcm_rd_en   = 0;
        qpcm_rd_addr = 0;
    end
end
/*Action = Modify, Change temporal logic to combinatorial logic*/

//qpctxmdata RAM valid/invalid operation
    //wire                             qpcm_ram_rst;
    //reg [0:0] qpcm_valid_array[0:QPCM_RAM_DEPTH-1];//valid flag
    /*Spyglass*/
    //assign qpcm_ram_rst = rst || ((wv_reg_ceu_req_type == `WR_ICMMAP_CTX) && (wv_reg_ceu_req_opcode == `WR_ICMMAP_DIS));
    /*Action = Delete*/

wire [63:0] qpc_unmap_addr;
assign qpc_unmap_addr = qv_temp_ceu_req_hd[63:0] - wv_qpc_base;
integer i;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        for(i = 0; i < QPCM_RAM_DEPTH; i = i + 1) begin
            qpcm_valid_array[i] <= `TD 0;
        end
    end
    else begin
        case ({(fsm_cs == MDT_PROC),wv_reg_ceu_req_type,wv_reg_ceu_req_opcode})
            //MAP_ICM_EN, set relative valid flag
            {1'b1,`MAP_ICM_CTX,`MAP_ICM_EN}: begin
                //get the addr and data from the low 128 of temp paylaod reg
                //RAM addr = (Virt addr - qpc_base)[21:12]
                /*VCS Verification*/
                //if ((qv_chunk_cnt <= wv_chunk_num) && (qv_chunk_cnt[0]== 1'b1) && qpc_map && (qv_page_cnt < wv_page_num)) begin
                if ((qv_chunk_cnt <= wv_chunk_num) && (qv_chunk_cnt[0]== 1'b1) && qpc_map && (qv_page_cnt < wv_page_num)) begin
                /*Acton = Modify*/
                    qpcm_valid_array[qpc_map_low_addr[21:12] + qv_page_cnt[9:0]] <= `TD 1'b1;        
                end
                //get the addr and data from the high 128 of temp paylaod reg
                else if ((qv_chunk_cnt <= wv_chunk_num) && (qv_chunk_cnt[0] == 1'b0) && qpc_map && (qv_page_cnt < wv_page_num)) begin
                    qpcm_valid_array[qpc_map_high_addr[21:12] + qv_page_cnt[9:0]] <= `TD 1'b1;
                end
                else begin
                    for(i = 0; i < QPCM_RAM_DEPTH; i = i + 1) begin
                        qpcm_valid_array[i] <= `TD qpcm_valid_array[i];
                    end
                end
            end
            //MAP_ICM_DIS, clear relative valid flag
            {1'b1,`MAP_ICM_CTX,`MAP_ICM_DIS}: begin
                /*Spyglass*/
                //if (qpc_unmap) begin
                    //for(i = 0; i < qv_temp_ceu_req_hd[73:64]; i = i + 1) begin
                    //  qpcm_valid_array[qpc_unmap_addr[21:12]+i] <= `TD 0;
                    //end
                for(i = 0; i < QPCM_RAM_DEPTH; i = i + 1) begin
                    if (qpc_unmap && (i < (qpc_unmap_addr[21:12] + qv_temp_ceu_req_hd[73:64])) && (i >= qpc_unmap_addr[21:12])) begin
                        qpcm_valid_array[i] <= `TD 1'b0;
                    end else begin
                        qpcm_valid_array[i] <= `TD qpcm_valid_array[i];
                    end
                end
                //end
                /*Action = Modify*/
            end
            //WR_ICMMAP_DIS, clear all valid flag
            {1'b1,`WR_ICMMAP_CTX,`WR_ICMMAP_DIS}:begin
                for(i = 0; i < QPCM_RAM_DEPTH; i = i + 1) begin
                    qpcm_valid_array[i] <= `TD 0;
                end
            end
            default: begin
                for(i = 0; i < QPCM_RAM_DEPTH; i = i + 1) begin
                    qpcm_valid_array[i] <= `TD qpcm_valid_array[i];
                end
            end
        endcase        
    end
end

//cqctxmdata RAM write operation
    //reg                              cqcm_wr_en; 
    //reg    [CQCM_RAM_AWIDTH-1 : 0]   cqcm_wr_addr;
    //reg    [CQCM_RAM_DWIDTH-1 : 0]   cqcm_wr_data;
wire [63:0] cqc_map_low_addr; // cq  index = (Virt addr - qpc_base)
wire [63:0] cqc_map_high_addr;// cq  index = (Virt addr - qpc_base)
assign cqc_map_low_addr  = {qv_temp_ceu_paylaod[127:64]}  - wv_cqc_base;
assign cqc_map_high_addr = {qv_temp_ceu_paylaod[255:192]} - wv_cqc_base;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cqcm_wr_en    <= `TD 0; 
        cqcm_wr_addr  <= `TD 0;
        cqcm_wr_data  <= `TD 0;
    end 
    //get the addr and data from the low 128 of temp paylaod reg
    //RAM addr = (Virt addr - qpc_base)[19:12]
    else if ((fsm_cs == MDT_PROC) && (wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && (qv_chunk_cnt <= wv_chunk_num) && (qv_chunk_cnt[0] == 1'b1) && (qv_page_cnt < wv_page_num) && cqc_map) begin
        cqcm_wr_en   <= `TD 1; 
        cqcm_wr_addr <= `TD cqc_map_low_addr[19:12] + qv_page_cnt[9:0];
        cqcm_wr_data <= `TD qv_temp_ceu_paylaod[63:12] + {40'b0,qv_page_cnt};
    end
    //get the addr and data from the high 128 of temp paylaod reg
    else if ((fsm_cs == MDT_PROC) && (wv_reg_ceu_req_type == `MAP_ICM_CTX) && (wv_reg_ceu_req_opcode == `MAP_ICM_EN) && (qv_chunk_cnt <= wv_chunk_num) && (qv_chunk_cnt[0] == 1'b0) && (qv_page_cnt < wv_page_num) && cqc_map) begin
        cqcm_wr_en   <= `TD 1; 
        cqcm_wr_addr <= `TD cqc_map_high_addr[19:12] + qv_page_cnt[9:0];
        cqcm_wr_data <= `TD qv_temp_ceu_paylaod[63+128:12+128] + {40'b0,qv_page_cnt};
    end
    else begin
        cqcm_wr_en    <= `TD 0; 
        cqcm_wr_addr  <= `TD 0;
        cqcm_wr_data  <= `TD 0;
    end
end
//cqctxmdata RAM read operation
    //reg                              cqcm_rd_en;
    //reg    [CQCM_RAM_AWIDTH-1 : 0]   cqcm_rd_addr;
wire [63:0] cqcm_compute_addr;
assign cqcm_compute_addr = (wv_reg_ceu_req_type == `WR_CQ_CTX) ? {26'b0,qv_temp_ceu_req_hd[95:64],6'b0} : 0;
/*VCS Verification*/
// always @(posedge clk or posedge rst) begin
//     if (rst) begin
//         cqcm_rd_en    <= `TD 0;
//         cqcm_rd_addr  <= `TD 0;
//     end
//     else if ((fsm_cs == MDT_PROC) && (wv_reg_ceu_req_type == `WR_CQ_CTX)) begin
//         cqcm_rd_en    <= `TD 1;
//         cqcm_rd_addr  <= `TD cqcm_compute_addr[19:12];
//     end
//     else begin
//         cqcm_rd_en    <= `TD 0;
//         cqcm_rd_addr  <= `TD 0;
//     end
// end
always @(*) begin
    if (rst) begin
        cqcm_rd_en    = 0;
        cqcm_rd_addr  = 0;
    end
    else if ((fsm_cs == MDT_PROC) && (wv_reg_ceu_req_type == `WR_CQ_CTX)) begin
        cqcm_rd_en    = 1;
        cqcm_rd_addr  = cqcm_compute_addr[19:12];
    end
    else begin
        cqcm_rd_en    = 0;
        cqcm_rd_addr  = 0;
    end
end
/*Action = Modify, Change temporal logic to combinatorial logic*/
//cqctxmdata RAM  valid/invalid operation
    //wire                             cqcm_ram_rst;
    //reg  [0:0] cqcm_valid_array[0:CQCM_RAM_DEPTH-1];//valid flag
    /*Spyglass*/
    //assign cqcm_ram_rst = rst || ((wv_reg_ceu_req_type == `WR_ICMMAP_CTX) && (wv_reg_ceu_req_opcode == `WR_ICMMAP_DIS));
    /*Action = Delete*/
wire [63:0] cqc_unmap_addr;
assign cqc_unmap_addr = qv_temp_ceu_req_hd[63:0] - wv_cqc_base;
integer j;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        for(j = 0; j < CQCM_RAM_DEPTH; j = j + 1) begin
            cqcm_valid_array[j] <= `TD 0;
        end
    end
    else begin
        case ({(fsm_cs == MDT_PROC),wv_reg_ceu_req_type,wv_reg_ceu_req_opcode})
            //MAP_ICM_EN, set relative valid flag
            {1'b1,`MAP_ICM_CTX,`MAP_ICM_EN}: begin
                //get the addr and data from the low 128 of temp paylaod reg
                //RAM addr = (Virt addr - cqc_base)[21:12]
                if ((qv_chunk_cnt <= wv_chunk_num) && (qv_chunk_cnt[0] == 1'b1) && cqc_map && (qv_page_cnt < wv_page_num)) begin
                    cqcm_valid_array[cqc_map_low_addr[19:12] + qv_page_cnt[9:0]] <= `TD 1'b1;        
                end
                //get the addr and data from the high 128 of temp paylaod reg
                else if ((qv_chunk_cnt <= wv_chunk_num) && (qv_chunk_cnt[0] == 1'b0) && cqc_map && (qv_page_cnt < wv_page_num)) begin
                    cqcm_valid_array[cqc_map_high_addr[19:12] + qv_page_cnt[9:0]] <= `TD 1'b1;
                end
                else begin
                    for(j = 0; j < CQCM_RAM_DEPTH; j = j + 1) begin
                        cqcm_valid_array[j] <= `TD cqcm_valid_array[j];
                    end
                end
            end
            //MAP_ICM_DIS, clear relative valid flag
            {1'b1,`MAP_ICM_CTX,`MAP_ICM_DIS}: begin
                /*Spyglass*/
                //if (cqc_unmap) begin
                //    for(j = 0; j < qv_temp_ceu_req_hd[71:64]; j = j + 1) begin
                //        cqcm_valid_array[cqc_unmap_addr[19:12]+j] <= `TD 0;
                //    end
                //end
                for(j = 0; j < CQCM_RAM_DEPTH; j = j + 1) begin
                    if (cqc_unmap && (j < (cqc_unmap_addr[19:12] + qv_temp_ceu_req_hd[71:64])) && (j >= cqc_unmap_addr[19:12])) begin
                        cqcm_valid_array[j] <= `TD 1'b0;
                    end else begin
                        cqcm_valid_array[j] <= `TD cqcm_valid_array[j];
                    end
                end
                /*Action = Modify*/
            end
            //WR_ICMMAP_DIS, clear all valid flag
            {1'b1,`WR_ICMMAP_CTX,`WR_ICMMAP_DIS}:begin
                for(j = 0; j < CQCM_RAM_DEPTH; j = j + 1) begin
                    cqcm_valid_array[j] <= `TD 0;
                end
            end
            default: begin
                for(j = 0; j < CQCM_RAM_DEPTH; j = j + 1) begin
                    cqcm_valid_array[j] <= `TD cqcm_valid_array[j];
                end
            end
        endcase        
    end
end

//eqctxmdata reg
    //    reg [51:0] eqc_page_addr;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        eqc_page_addr <= `TD 0;
    end
    else begin
        case ({(fsm_cs == MDT_PROC),wv_reg_ceu_req_type,wv_reg_ceu_req_opcode})
            //MAP_ICM_EN, get the eqc_page_addr
            {1'b1,`MAP_ICM_CTX,`MAP_ICM_EN}: begin
                /*Spyglass*/
                if (eqc_map) begin
                    eqc_page_addr <= `TD qv_temp_ceu_paylaod[63:12];
                end else begin
                    eqc_page_addr <= `TD eqc_page_addr;
                end
                /*Action = Add*/
            end
            //MAP_ICM_DIS, clear the eqc_page_addr
            {1'b1,`MAP_ICM_CTX,`MAP_ICM_DIS}: begin
                /*Spyglass*/
                if (eqc_unmap) begin
                    eqc_page_addr <= `TD 0;
                end else begin
                    eqc_page_addr <= `TD eqc_page_addr;
                end
                /*Action = Add*/
            end
            //WR_ICMMAP_DIS, clear all valid flag
            {1'b1,`WR_ICMMAP_CTX,`WR_ICMMAP_DIS}:begin
                eqc_page_addr <= `TD 0;
            end
            default: begin
                eqc_page_addr <= `TD eqc_page_addr;
            end
        endcase        
    end
end

//DMA Read Ctx Request Out interface
    //reg                             mdt_req_rd_ctx_wr_en;
    //reg  [`MDT_REQ_RD_CTX-1:0]      mdt_req_rd_ctx_din;
    //----------------Out dma read req to dma_read_ctx module
    //|---------108bit---------------|
    //|  addr     | len      | QPN   | 
    //|  64 bit   | 12 bit   | 32 bit|
    reg  [`MDT_REQ_RD_CTX-1-20:0]      mdt_req_rd_ctx_din;
    assign wv_mdt_req_rd_ctx_din = {mdt_req_rd_ctx_din[`MDT_REQ_RD_CTX-1-20:32],8'b0,12'b11000000,mdt_req_rd_ctx_din[31:0]};
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mdt_req_rd_ctx_wr_en <= `TD 0;
        mdt_req_rd_ctx_din   <= `TD 0;
    end
    else if (ceu_has_dma_rd && (fsm_cs == DMA_PROC) && !mdt_req_rd_ctx_prog_full) begin
        /*VCS Verification*/
        // mdt_req_rd_ctx_wr_en <=  `TD 1;
        // mdt_req_rd_ctx_din   <=  `TD {qpcm_rd_data,qpcm_compute_addr[11:0],12'b100000000,qv_temp_ceu_req_hd[95:64]};
        mdt_req_rd_ctx_wr_en <= `TD (qpcm_valid_array[qpcm_compute_addr[21:12]]) ? 1 : 0;
        mdt_req_rd_ctx_din   <= `TD (qpcm_valid_array[qpcm_compute_addr[21:12]]) ? {qpcm_rd_data,qpcm_compute_addr[11:8],qv_temp_ceu_req_hd[95:64]} : 0;
        /*Action = Modify*/
    end
    else begin
        mdt_req_rd_ctx_wr_en <= `TD 0;
        mdt_req_rd_ctx_din   <= `TD 0;
    end
end

//DMA Write Ctx Request Out interface
    //reg                      mdt_req_wr_ctx_wr_en;
    //reg   [`HD_WIDTH-1:0]    mdt_req_wr_ctx_din  ;
    //wire                     mdt_req_wr_ctx_prog_full;
    //----------------Out dma read req to dma_write_ctx module
        //| ------------------128bit------------------------------------|
        //|   type   |  opcode |   Src   | R      | valid  |   data   |   addr   | 
        //|    4 bit |  4 bit  |  3 bit  |20 bit  |  1 bit |  32 bit  |  64 bit  | 
    reg   [`HD_WIDTH-1-20:0]    mdt_req_wr_ctx_din;
    assign wv_mdt_req_wr_ctx_din = {mdt_req_wr_ctx_din[`HD_WIDTH-1-20:97],20'b0,mdt_req_wr_ctx_din[96:0]};
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mdt_req_wr_ctx_wr_en <= `TD 0;
        mdt_req_wr_ctx_din   <= `TD 0;
    end
    else if (ceu_has_dma_wr && (fsm_cs == DMA_PROC) && !mdt_req_wr_ctx_prog_full) begin
        case ({wv_reg_ceu_req_type,wv_reg_ceu_req_opcode})
            // {`WR_QP_CTX,`WR_QP_ALL}: begin
            //     mdt_req_wr_ctx_wr_en <= `TD (qpcm_valid_array[qpcm_compute_addr[21:12]]) ? 1 : 0;
            //     mdt_req_wr_ctx_din   <= `TD (qpcm_valid_array[qpcm_compute_addr[21:12]]) ? {`WR_QP_CTX,`WR_QP_ALL,`CEU,21'b0,32'b0,qpcm_rd_data,qpcm_compute_addr[11:0]} : 0;
            // end
            // {`WR_CQ_CTX,`WR_CQ_ALL}:begin
            //     mdt_req_wr_ctx_wr_en <= `TD (cqcm_valid_array[cqcm_compute_addr[19:12]]) ? 1 : 0;
            //     mdt_req_wr_ctx_din   <= `TD (cqcm_valid_array[cqcm_compute_addr[19:12]]) ? {`WR_CQ_CTX,`WR_CQ_ALL,`CEU,21'b0,32'b0,cqcm_rd_data,cqcm_compute_addr[11:0]} : 0;
            // end
            // {`WR_CQ_CTX,`WR_CQ_MODIFY}:begin
            //     mdt_req_wr_ctx_wr_en <= `TD (cqcm_valid_array[cqcm_compute_addr[19:12]]) ? 1 : 0;
            //     mdt_req_wr_ctx_din   <= `TD (cqcm_valid_array[cqcm_compute_addr[19:12]]) ? {`WR_CQ_CTX,`WR_CQ_MODIFY,`CEU,21'b0,32'b0,cqcm_rd_data,cqcm_compute_addr[11:0]} : 0;
            // end
            // {`WR_EQ_CTX,`WR_EQ_ALL}:begin
            //     mdt_req_wr_ctx_wr_en <= `TD (eqc_page_addr != 0) ? 1 : 0;
            //     mdt_req_wr_ctx_din   <= `TD (eqc_page_addr != 0) ? {`WR_EQ_CTX,`WR_EQ_ALL,`CEU,21'b0,32'b0,eqc_page_addr,qv_temp_ceu_req_hd[69:64],6'b0} : 0;
            // end
            // {`WR_CQ_CTX,`WR_CQ_INVALID}:begin
            //     mdt_req_wr_ctx_wr_en <= `TD (cqcm_valid_array[cqcm_compute_addr[19:12]]) ? 1 : 0;
            //     mdt_req_wr_ctx_din   <= `TD (cqcm_valid_array[cqcm_compute_addr[19:12]]) ? {`WR_CQ_CTX,`WR_CQ_INVALID,`CEU,21'b0,32'b0,cqcm_rd_data,cqcm_compute_addr[11:0]} : 0;
            // end
            // {`WR_EQ_CTX,`WR_EQ_INVALID}:begin
            //     mdt_req_wr_ctx_wr_en <= `TD (eqc_page_addr != 0) ? 1 :0;
            //     mdt_req_wr_ctx_din   <= `TD (eqc_page_addr != 0) ? {`WR_EQ_CTX,`WR_EQ_INVALID,`CEU,21'b0,32'b0,eqc_page_addr,qv_temp_ceu_req_hd[69:64],6'b0} : 0;
            // end
            // {`WR_EQ_CTX,`WR_EQ_FUNC}:begin
            //     mdt_req_wr_ctx_wr_en <= `TD (eqc_page_addr != 0) ? 1 : 0;
            //     //make sure event mask addr offset in host memory: mask offset = 0;
            //     mdt_req_wr_ctx_din   <= `TD (eqc_page_addr != 0) ? {`WR_EQ_CTX,`WR_EQ_FUNC,`CEU,21'b0,qv_temp_ceu_req_hd[31:0],eqc_page_addr,qv_temp_ceu_req_hd[69:64],6'b0} :0;
            // end
            {`WR_QP_CTX,`WR_QP_ALL}: begin
                mdt_req_wr_ctx_wr_en <= `TD 1;
                mdt_req_wr_ctx_din   <= `TD {`WR_QP_CTX,`WR_QP_ALL,`CEU,qpcm_valid_array[qpcm_compute_addr[21:12]],32'b0,qpcm_rd_data,qpcm_compute_addr[11:0]};
            end
            {`WR_CQ_CTX,`WR_CQ_ALL}:begin
                mdt_req_wr_ctx_wr_en <= `TD 1;
                mdt_req_wr_ctx_din   <= `TD {`WR_CQ_CTX,`WR_CQ_ALL,`CEU,cqcm_valid_array[cqcm_compute_addr[19:12]],32'b0,cqcm_rd_data,cqcm_compute_addr[11:0]};
            end
            {`WR_CQ_CTX,`WR_CQ_MODIFY}:begin
                mdt_req_wr_ctx_wr_en <= `TD 1;
                mdt_req_wr_ctx_din   <= `TD {`WR_CQ_CTX,`WR_CQ_MODIFY,`CEU,cqcm_valid_array[cqcm_compute_addr[19:12]],32'b0,cqcm_rd_data,cqcm_compute_addr[11:0]};
            end
            {`WR_EQ_CTX,`WR_EQ_ALL}:begin
                mdt_req_wr_ctx_wr_en <= `TD 1;
                mdt_req_wr_ctx_din   <= `TD {`WR_EQ_CTX,`WR_EQ_ALL,`CEU,(eqc_page_addr != 0),32'b0,eqc_page_addr,qv_temp_ceu_req_hd[69:64],6'b0};
            end
            {`WR_CQ_CTX,`WR_CQ_INVALID}:begin
                mdt_req_wr_ctx_wr_en <= `TD 1;
                mdt_req_wr_ctx_din   <= `TD {`WR_CQ_CTX,`WR_CQ_INVALID,`CEU,cqcm_valid_array[cqcm_compute_addr[19:12]],32'b0,cqcm_rd_data,cqcm_compute_addr[11:0]};
            end
            {`WR_EQ_CTX,`WR_EQ_INVALID}:begin
                mdt_req_wr_ctx_wr_en <= `TD 1;
                mdt_req_wr_ctx_din   <= `TD {`WR_EQ_CTX,`WR_EQ_INVALID,`CEU,(eqc_page_addr != 0),32'b0,eqc_page_addr,qv_temp_ceu_req_hd[69:64],6'b0};
            end
            {`WR_EQ_CTX,`WR_EQ_FUNC}:begin
                mdt_req_wr_ctx_wr_en <= `TD 1;
                //make sure event mask addr offset in host memory: mask offset = 0;
                mdt_req_wr_ctx_din   <= `TD {`WR_EQ_CTX,`WR_EQ_FUNC,`CEU,(eqc_page_addr != 0),qv_temp_ceu_req_hd[31:0],eqc_page_addr,qv_temp_ceu_req_hd[69:64],6'b0};
            end
            default: begin
                mdt_req_wr_ctx_wr_en <= `TD 0;
                mdt_req_wr_ctx_din   <= `TD 0;
            end
        endcase
    end
    else if ((fsm_cs == DMA_PROC) && !mdt_req_wr_ctx_prog_full && keyctx_has_dma_wr && (qv_dma_req_cnt < wv_dma_req_num) && qpcm_valid_array[qpcm_compute_addr[21:12]]) begin
        case ({wv_reg_keyctx_req_type,wv_reg_keyctx_req_opcode})
            {`WR_QP_CTX,`WR_QP_UAPST}:begin
                if (qv_dma_req_cnt == 0) begin
                    mdt_req_wr_ctx_wr_en <= `TD 1;
                    //make sure state addr offset in host memory:state offset = 08h
                    mdt_req_wr_ctx_din   <= `TD {`WR_QP_CTX,`WR_QP_STATE,`RRC,30'b0,qv_temp_keyctx_req_hd[2:0],qpcm_rd_data,(qpcm_compute_addr[11:0]+12'h8)};
                end
                else if (qv_dma_req_cnt == 1) begin
                    mdt_req_wr_ctx_wr_en <= `TD 1;
                    //make sure UnackPSN addr offset in host memory: UnackPSN offset = 7ch
                    mdt_req_wr_ctx_din   <= `TD {`WR_QP_CTX,`WR_QP_UAPST,`RRC,9'b0,qv_temp_keyctx_req_hd[31:8],qpcm_rd_data,(qpcm_compute_addr[11:0]+12'h7c)};
                end
                else begin
                    mdt_req_wr_ctx_wr_en <= `TD 0;
                    mdt_req_wr_ctx_din   <= `TD 0;
                end
            end
            {`WR_QP_CTX,`WR_QP_NPST}:begin
                if (qv_dma_req_cnt == 0) begin
                    mdt_req_wr_ctx_wr_en <= `TD 1;
                    //make sure state addr offset in host memory: state offset = 08h
                    mdt_req_wr_ctx_din   <= `TD {`WR_QP_CTX,`WR_QP_STATE,`RTC,30'b0,qv_temp_keyctx_req_hd[2:0],qpcm_rd_data,(qpcm_compute_addr[11:0]+12'h8)};
                end
                else if (qv_dma_req_cnt == 1) begin
                    mdt_req_wr_ctx_wr_en <= `TD 1;
                    //make sure NextPSN addr offset in host memory: NextPSN offset = 6ch
                    mdt_req_wr_ctx_din   <= `TD {`WR_QP_CTX,`WR_QP_NPST,`RTC,9'b0,qv_temp_keyctx_req_hd[31:8],qpcm_rd_data,(qpcm_compute_addr[11:0]+12'h6c)};
                end
                else begin
                    mdt_req_wr_ctx_wr_en <= `TD 0;
                    mdt_req_wr_ctx_din   <= `TD 0;
                end
            end
            {`WR_QP_CTX,`WR_QP_EPST}:begin
                if (qv_dma_req_cnt == 0) begin
                    mdt_req_wr_ctx_wr_en <= `TD 1;
                    //make sure state addr offset in host memory: state offset = 08h
                    mdt_req_wr_ctx_din   <= `TD {`WR_QP_CTX,`WR_QP_STATE,`EE,30'b0,qv_temp_keyctx_req_hd[2:0],qpcm_rd_data,(qpcm_compute_addr[11:0]+12'h8)};
                end
                else if (qv_dma_req_cnt == 1) begin
                    mdt_req_wr_ctx_wr_en <= `TD 1;
                    //make sure ExpectPSN addr offset in host memory: ExpectPSN offset = 84h
                    mdt_req_wr_ctx_din   <= `TD {`WR_QP_CTX,`WR_QP_EPST,`EE,9'b0,qv_temp_keyctx_req_hd[31:8],qpcm_rd_data,(qpcm_compute_addr[11:0]+12'h84)};
                end
                else begin
                    mdt_req_wr_ctx_wr_en <= `TD 0;
                    mdt_req_wr_ctx_din   <= `TD 0;
                end
            end 
            default: begin
                mdt_req_wr_ctx_wr_en <= `TD 0;
                mdt_req_wr_ctx_din   <= `TD 0;
            end
        endcase
    end
    /*Action = Modify, add valid flag check before initiate dma request*/
    else begin
        mdt_req_wr_ctx_wr_en <= `TD 0;
        mdt_req_wr_ctx_din   <= `TD 0;
    end
end



`ifdef CTX_DUG
    // /*****************Add for APB-slave regs**********************************/ 
    // reg                             mdt_req_rd_ctx_wr_en;                  //1 
    // reg                      mdt_req_wr_ctx_wr_en;                         //1 
    // reg                              qpcm_wr_en;                           //1 
    // reg    [QPCM_RAM_AWIDTH-1 : 0]   qpcm_wr_addr;                         //10 
    // reg    [QPCM_RAM_DWIDTH-1 : 0]   qpcm_wr_data;                         //52 
    // reg                              qpcm_rd_en;                           //1 
    // reg    [QPCM_RAM_AWIDTH-1 : 0]   qpcm_rd_addr;                         //10 
    // reg                              cqcm_wr_en;                           //1 
    // reg    [CQCM_RAM_AWIDTH-1 : 0]   cqcm_wr_addr;                         //8 
    // reg    [CQCM_RAM_DWIDTH-1 : 0]   cqcm_wr_data;                         //52 
    // reg                              cqcm_rd_en;                           //1 
    // reg    [CQCM_RAM_AWIDTH-1 : 0]   cqcm_rd_addr;                         //8 
    // reg [51:0] eqc_page_addr;                                              //52 
    // reg [`HD_WIDTH-1:0] qv_temp_ceu_req_hd;                                //128 
    // reg [`HD_WIDTH-1:0] qv_temp_keyctx_req_hd;                             //128 
    // reg [`DT_WIDTH-1:0] qv_temp_ceu_paylaod;                               //256 
    // reg [31:0] qv_chunk_cnt;                                               //32 
    // reg [31:0] qv_payload_cnt;                                             //32 
    // reg [11:0] qv_page_cnt;                                                //12 
    // reg [1:0] qv_dma_req_cnt;                                              //2 
    // reg qpc_map;//MAP_ICM_EN                                               //1 
    // reg cqc_map;//MAP_ICM_EN                                               //1 
    // reg eqc_map;//MAP_ICM_EN                                               //1 
    // reg qpc_unmap;//MAP_ICM_DIS                                            //1 
    // reg cqc_unmap;//MAP_ICM_DIS                                            //1 
    // reg eqc_unmap;//MAP_ICM_DIS                                            //1 
    // reg [55:0] qv_qpc_base;                                                //56 
    // reg [55:0] qv_cqc_base;                                                //56 
    // reg [55:0] qv_eqc_base;                                                //56 
    // reg [2:0] fsm_cs;                                                      //3 
    // reg [2:0] fsm_ns;                                                      //3 
    // reg  [`MDT_REQ_RD_CTX-1-20:0]      mdt_req_rd_ctx_din;                 //88 
    // reg   [`HD_WIDTH-1-20:0]    mdt_req_wr_ctx_din;                        //108 
    
    //total regs count = 1bit_signal(12) + fsm(3*2) + reg (10*2 + 52*3 + 8*2 + 256 + 128*2 + 32*2 + 12 + 2 + 56*3 + 88 + 108) = 1164
     
    //*****************Add for APB-slave wires**********************************/  
    // wire                      ceu_req_ctxmdata_rd_en,                     //1 
    // wire                      ceu_req_ctxmdata_empty,                     //1 
    // wire [`CEUP_REQ_MDT-1:0]  ceu_req_ctxmdata_dout,                      //128 
    // wire                     ctxmdata_data_rd_en,                         //1 
    // wire                     ctxmdata_data_empty,                         //1 
    // wire [`INTER_DT-1:0]     ctxmdata_data_dout,                          //256 
    // wire                      key_ctx_req_mdt_rd_en,                      //1 
    // wire  [`HD_WIDTH-1:0]     key_ctx_req_mdt_dout,                       //128 
    // wire                      key_ctx_req_mdt_empty,                      //1 
    // wire                            mdt_req_rd_ctx_rd_en,                 //1 
    // wire [`MDT_REQ_RD_CTX-1:0]      mdt_req_rd_ctx_dout,                  //108 
    // wire                            mdt_req_rd_ctx_empty,                 //1 
    // wire                     mdt_req_wr_ctx_rd_en,                        //1 
    // wire  [`HD_WIDTH-1:0]    mdt_req_wr_ctx_dout,                         //128 
    // wire                     mdt_req_wr_ctx_empty                         //1 
    // wire  [`MDT_REQ_RD_CTX-1:0]     wv_mdt_req_rd_ctx_din;                //128 
    // wire                            mdt_req_rd_ctx_prog_full;             //1 
    // wire  [`HD_WIDTH-1:0]    wv_mdt_req_wr_ctx_din;                       //128 
    // wire                     mdt_req_wr_ctx_prog_full;                    //1 
    // wire   [QPCM_RAM_DWIDTH-1 : 0]   qpcm_rd_data;                        //52 
    // wire   [CQCM_RAM_DWIDTH-1 : 0]   cqcm_rd_data;                        //52 
    // wire [63:0] wv_qpc_base;                                              //64 
    // wire [63:0] wv_cqc_base;                                              //64 
    // wire [63:0] wv_eqc_base;                                              //64 
    // wire [3:0]  wv_ceu_req_type;                                          //4 
    // wire [3:0]  wv_ceu_req_opcode;                                        //4 
    // wire [3:0]  wv_keyctx_req_type;                                       //4 
    // wire [3:0]  wv_keyctx_req_opcode;                                     //4 
    // wire ctx_have_payload;                                                //1 
    // wire ctx_no_payload;                                                  //1 
    // wire mdata_have_payload;                                              //1 
    // wire mdata_no_payload;                                                //1 
    // wire keyqpc_no_payload;                                               //1 
    // wire [3:0]  wv_reg_ceu_req_type;                                      //4 
    // wire [3:0]  wv_reg_ceu_req_opcode;                                    //4 
    // wire [3:0]  wv_reg_keyctx_req_type;                                   //4 
    // wire [3:0]  wv_reg_keyctx_req_opcode;                                 //4 
    // wire ceu_has_dma_rd;                                                  //1 
    // wire ceu_has_dma_wr;                                                  //1 
    // wire keyctx_has_dma_wr;                                               //1 
    // wire ceu_has_mdata_rd;                                                //1 
    // wire keyctx_has_mdata_rd;                                             //1 
    // wire [31:0] wv_chunk_num;                                             //32 
    // wire [31:0] wv_payload_num;                                           //32 
    // wire [1:0] wv_dma_req_num;                                            ///2 
    // wire mdt_op_finish;                                                   //1 
    // wire [11:0] wv_page_num;                                              //12 
    // wire [63:0] qpc_map_low_addr;                                         //64 
    // wire [63:0] qpc_map_high_addr;                                        //64 
    // wire [63:0] qpcm_compute_addr;                                        //64 
    // wire [63:0] qpc_unmap_addr;                                           //64 
    // wire [63:0] cqc_map_low_addr;                                         //64 
    // wire [63:0] cqc_map_high_addr;                                        //64 
    // wire [63:0] cqcm_compute_addr;                                        //64 
    // wire [63:0] cqc_unmap_addr;                                           //64 
    
    //total wires count = 1bit_signal(23) + 52*2 + 256 + 128*5 + 32*2 + 12 + 2 + 108 + 64*11 + 4*8 = 1945

    //Total regs and wires : 1164 + 1945 = 3109 = 32 * 97 + 5. bit align 98


    assign wv_dbg_bus_2 = {
        5'b0,
        mdt_req_rd_ctx_wr_en,
        mdt_req_wr_ctx_wr_en,
        qpcm_wr_en,
        qpcm_wr_addr,
        qpcm_wr_data,
        qpcm_rd_en,
        qpcm_rd_addr,
        cqcm_wr_en,
        cqcm_wr_addr,
        cqcm_wr_data,
        cqcm_rd_en,
        cqcm_rd_addr,
        eqc_page_addr,
        qv_temp_ceu_req_hd,
        qv_temp_keyctx_req_hd,
        qv_temp_ceu_paylaod,
        qv_chunk_cnt,
        qv_payload_cnt,
        qv_page_cnt,
        qv_dma_req_cnt,
        qpc_map,
        cqc_map,
        eqc_map,
        qpc_unmap,
        cqc_unmap,
        eqc_unmap,
        qv_qpc_base,
        qv_cqc_base,
        qv_eqc_base,
        fsm_cs,
        fsm_ns,
        mdt_req_rd_ctx_din,
        mdt_req_wr_ctx_din,

        ceu_req_ctxmdata_rd_en,
        ceu_req_ctxmdata_empty,
        ceu_req_ctxmdata_dout,
        ctxmdata_data_rd_en,
        ctxmdata_data_empty,
        ctxmdata_data_dout,
        key_ctx_req_mdt_rd_en,
        key_ctx_req_mdt_dout,
        key_ctx_req_mdt_empty,
        mdt_req_rd_ctx_rd_en,
        mdt_req_rd_ctx_dout,
        mdt_req_rd_ctx_empty,
        mdt_req_wr_ctx_rd_en,
        mdt_req_wr_ctx_dout,
        mdt_req_wr_ctx_empty,
        wv_mdt_req_rd_ctx_din,
        mdt_req_rd_ctx_prog_full,
        wv_mdt_req_wr_ctx_din,
        mdt_req_wr_ctx_prog_full,
        qpcm_rd_data,
        cqcm_rd_data,
        wv_qpc_base,
        wv_cqc_base,
        wv_eqc_base,
        wv_ceu_req_type,
        wv_ceu_req_opcode,
        wv_keyctx_req_type,
        wv_keyctx_req_opcode,
        ctx_have_payload,
        ctx_no_payload,
        mdata_have_payload,
        mdata_no_payload,
        keyqpc_no_payload,
        wv_reg_ceu_req_type,
        wv_reg_ceu_req_opcode,
        wv_reg_keyctx_req_type,
        wv_reg_keyctx_req_opcode,
        ceu_has_dma_rd,
        ceu_has_dma_wr,
        keyctx_has_dma_wr,
        ceu_has_mdata_rd,
        keyctx_has_mdata_rd,
        wv_chunk_num,
        wv_payload_num,
        wv_dma_req_num,
        mdt_op_finish,
        wv_page_num,
        qpc_map_low_addr,
        qpc_map_high_addr,
        qpcm_compute_addr,
        qpc_unmap_addr,
        cqc_map_low_addr,
        cqc_map_high_addr,
        cqcm_compute_addr,
        cqc_unmap_addr
    };
`endif 

endmodule