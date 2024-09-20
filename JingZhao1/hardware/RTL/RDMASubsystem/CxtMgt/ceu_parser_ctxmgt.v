//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: ceu_parser_ctxmgt.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V0.5
// VERSION DESCRIPTION: 5nd Edition  
//----------------------------------------------------
// RELEASE DATE: 2022-08-29
//---------------------------------------------------- 
// PURPOSE: parse msg from CEU for CtxMgt module. 
//          initiate req key_qpc_data module
//          extract data to key_qpc_data
//          forward ctxmdata req && payload to ctxmdata to change context mdata
//          forward ctx req to ctxmdata to lookup physical addr
//          forward ctx payload to writectx to initiate dma write context req
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
//----------------------------------------------------
// VERSION UPDATE: 
// modify ctxmgt module, parse more info from the payload recieved from CEU
// add one more fifo for key_qpc_data module
// //-FHDR-----------------------------------------------

//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_ctxmgt_h.vh"

module ceu_parser_ctxmgt (
    input clk,
    input rst,

    // externel Parse msg requests header from CEU 
    input   wire                 ceu_req_valid,
    output  wire                 ceu_req_ready,
    input   wire [`DT_WIDTH-1:0] ceu_req_data,
    input   wire                 ceu_req_last,
    input   wire [`HD_WIDTH-1:0] ceu_req_header,

    // internal request cmd fifo to write key_qpc_data
    //35 width 
    input   wire                       ceu_wr_req_rd_en,
    output  wire                       ceu_wr_req_empty,//also to request controller
    output  wire [`CEUP_REQ_KEY-1:0]   ceu_wr_req_dout,

    // internal context data fifo to write key_qpc_data
    //384 width 
    //first fifo for old info
    input   wire                       ceu_wr_data_rd_en1,
    output  wire                       ceu_wr_data_empty1,
    output  wire [`KEY_QPC_DT-1:0]     ceu_wr_data_dout1,
    //second fifo for new info
    input   wire                       ceu_wr_data_rd_en2,
    output  wire                       ceu_wr_data_empty2,
    output  wire [`KEY_QPC_DT-1:0]     ceu_wr_data_dout2,

    // internal req cmd to ctxmdata Module
    //128 width 16 depth syn FIFO format1
    input   wire                      ceu_req_ctxmdata_rd_en,
    output  wire                      ceu_req_ctxmdata_empty,
    output  wire [`CEUP_REQ_MDT-1:0]  ceu_req_ctxmdata_dout,

    // internel context metaddata payload to write ctxmdata Module
    // 256 width 24 depth syn FIFO (only context meatadata)
    input   wire                   ctxmdata_data_rd_en,
    output  wire                   ctxmdata_data_empty,
    output  wire [`INTER_DT-1:0]   ctxmdata_data_dout,

    // internal context data to writectx module to write to host memory
    input   wire                  ctx_data_rd_en,
    output  wire                  ctx_data_empty,
    output  wire [`INTER_DT-1:0]  ctx_data_dout  
    
    `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , input   wire 	[`PAR_DBG_RW_NUM * 32 - 1 : 0]	rw_data        
    , output  wire 	[`PAR_DBG_REG_NUM * 32 -1:0]		wv_dbg_bus_1
    `endif 
);

//variables for key_qpc_data/ctxmdata/writectx module fifo (header and payload)

    // wire fifo_clear;
    // assign fifo_clear = 1'b0;
    // internal request cmd fifo to write key_qpc_data
    //35 width 8 depth
    reg                        ceu_wr_req_wr_en;
    wire                       ceu_wr_req_prog_full;    //also to request controller
    reg  [`CEUP_REQ_KEY-1:0]   ceu_wr_req_din;

    // internal context data fifo to write key_qpc_data
    //384 width 8 depth
    //first fifo for old info
    reg                        ceu_wr_data_wr_en1;
    wire                       ceu_wr_data_prog_full1;
    reg  [`KEY_QPC_DT-1:0]     ceu_wr_data_din1;
    //second fifo for new info
    reg                        ceu_wr_data_wr_en2;
    wire                       ceu_wr_data_prog_full2;
    reg  [`KEY_QPC_DT-1:0]     ceu_wr_data_din2;

    // internal req cmd to ctxmdata Module
    //128 width 8 depth syn FIFO format1
    reg                       ceu_req_ctxmdata_wr_en;
    wire                      ceu_req_ctxmdata_prog_full;
    reg  [`CEUP_REQ_MDT-1:0]  ceu_req_ctxmdata_din;

    // internel context metaddata payload to write ctxmdata Module
    // 256 width 16 depth syn FIFO (only context meatadata)
    reg                    ctxmdata_data_wr_en;
    wire                   ctxmdata_data_prog_full;
    reg  [`INTER_DT-1:0]   ctxmdata_data_din;

    // internal context data to writectx module to write to host memory
    // 256 width 32 depth syn FIFO
    reg                    ctx_data_wr_en;
    wire                   ctx_data_prog_full;
    reg  [`INTER_DT-1:0]   ctx_data_din;

ceu_wr_req_fifo_35w8d ceu_wr_req_fifo_35w8d_Inst(
        .clk        (clk),
        .srst        (rst),
        .wr_en      (ceu_wr_req_wr_en),
        .rd_en      (ceu_wr_req_rd_en),
        .din        (ceu_wr_req_din),
        .dout       (ceu_wr_req_dout),
        .full       (),
        .empty      (ceu_wr_req_empty),     
        .prog_full  (ceu_wr_req_prog_full)
    `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[1 * 32 - 1 : 0])        
    `endif 
);

//first fifo for old QPC key info 
ceu_wr_data_fifo_384w8d ceu_wr_data_fifo_384w8d_Inst1(
        .clk        (clk),
        .srst        (rst),
        .wr_en      (ceu_wr_data_wr_en1),
        .rd_en      (ceu_wr_data_rd_en1),
        .din        (ceu_wr_data_din1),
        .dout       (ceu_wr_data_dout1),
        .full       (),
        .empty      (ceu_wr_data_empty1),     
        .prog_full  (ceu_wr_data_prog_full1)
    `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[1 * 32 +: 1 * 32])        
    `endif 
);

//second fifo for new QPC key info
ceu_wr_data_fifo_384w8d ceu_wr_data_fifo_384w8d_Inst2(
        .clk        (clk),
        .srst        (rst),
        .wr_en      (ceu_wr_data_wr_en2),
        .rd_en      (ceu_wr_data_rd_en2),
        .din        (ceu_wr_data_din2),
        .dout       (ceu_wr_data_dout2),
        .full       (),
        .empty      (ceu_wr_data_empty2),     
        .prog_full  (ceu_wr_data_prog_full2)
    `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[2 * 32 +: 1 * 32])        
    `endif 
);

ceu_req_ctxmdata_fifo_128w8d ceu_req_ctxmdata_fifo_128w8d_Inst(
        .clk        (clk),
        .srst        (rst),
        .wr_en      (ceu_req_ctxmdata_wr_en),
        .rd_en      (ceu_req_ctxmdata_rd_en),
        .din        (ceu_req_ctxmdata_din),
        .dout       (ceu_req_ctxmdata_dout),
        .full       (),
        .empty      (ceu_req_ctxmdata_empty),     
        .prog_full  (ceu_req_ctxmdata_prog_full)
    `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[3 * 32 +: 1 * 32])        
    `endif 
);

ctxmdata_data_fifo_256w16d ctxmdata_data_fifo_256w16d_Inst(
        .clk        (clk),
        .srst        (rst),
        .wr_en      (ctxmdata_data_wr_en),
        .rd_en      (ctxmdata_data_rd_en),
        .din        (ctxmdata_data_din),
        .dout       (ctxmdata_data_dout),
        .full       (),
        .empty      (ctxmdata_data_empty),     
        .prog_full  (ctxmdata_data_prog_full)
    `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[4 * 32 +: 1 * 32])        
    `endif 
);

ctx_data_fifo_256w32d ctx_data_fifo_256w32d_Inst(
        .clk        (clk),
        .srst        (rst),
        .wr_en      (ctx_data_wr_en),
        .rd_en      (ctx_data_rd_en),
        .din        (ctx_data_din),
        .dout       (ctx_data_dout),
        .full       (),
        .empty      (ctx_data_empty),     
        .prog_full  (ctx_data_prog_full)
    `ifdef CTX_DUG
        /*Interface with APB Slave*/
    , .rw_data(rw_data[5 * 32 +: 1 * 32])        
    `endif 
);

//registers
reg [1:0] fsm_cs;
reg [1:0] fsm_ns;

//state machine parameters
//get header and the fisrt cycle data from ceu AXIS 
parameter PARSE_REQ      = 2'b01;
//make sure whether it has payload, which fifo it will be pushed,
//if it doesn't have payload, tranfer req header to dest fifo
//if it has payload,transfer req and payload to ctxmdata_data, ceu_req_ctxmdata, writectx, or key_qpc_data
parameter TRANS_REQ_DATA = 2'b10;

//-----------------Stage 1 :State Register----------
always @(posedge clk or posedge rst) begin
    if(rst)
        fsm_cs <= `TD PARSE_REQ;
    else
        fsm_cs <= `TD fsm_ns;
end

//-----------------Stage 2 :State Transition----------

//temporarily store header to wait for extract data
reg [`HD_WIDTH-1 :0] qv_ceu_req_header;

//wv_payload_num;   for PARSE_REQ; all derived msg seemed as payload
wire [31:0] wv_payload_num;

//temporaryly store payload 
reg [`DT_WIDTH-1 :0] qv_tmp_ceu_payload;

// accumulating payload to make sure which cycle transfer next msg
reg [31:0] qv_payload_cnt;

//rebuild payload for derived msg which has payload
reg [`KEY_QPC_DT-1 :0] qv_rebuild_payload1;
reg [`KEY_QPC_DT-1 :0] qv_rebuild_payload2;

//rebuild header for derived key_qpc_dat req header
// reg [`CEUP_REQ_KEY-1 :0] qv_rebuild_key_header;//for key_qpc_data
reg [`CEUP_REQ_KEY-1-3 :0] qv_rebuild_key_header;//for key_qpc_data SOUR = `CEU

//rebuild header for derived ctxmdata req header
reg [`CEUP_REQ_MDT-1 :0] qv_rebuild_mdt_header;//for ctxmdata

// wire
wire [3:0]  wv_req_type;
wire [3:0]  wv_req_opcode;

//ceu_parser_ila ceu_parser_ila (
//    .clk(clk),
//    .probe0(fsm_cs),//2 bit
//    .probe1(fsm_ns),//2 bit
//    .probe2(ceu_req_ready),//1 bit
//    .probe3(ceu_req_data),//256 bit
//    .probe4(ceu_req_valid),//1 bit
//    .probe5(ceu_req_header),//128 bit
//    .probe6(ceu_req_last),//1 bit
//    .probe7(qv_ceu_req_header),//128 bit
//    .probe8(qv_tmp_ceu_payload),//256 bit
//    .probe9(wv_payload_num),//32 bit
//    .probe10(qv_payload_cnt),//32 bit  
    
//    .probe11(ceu_wr_data_wr_en1),//1 bit
//    .probe12(ceu_wr_data_din1),//384 bit
    
//    .probe13(ceu_req_ctxmdata_wr_en),//1 bit
//    .probe14(ceu_req_ctxmdata_din)//128 bit

//); 

/*Spyglass*/
//wire [31:0] wv_req_addr;
/*Action = Delete*/
assign wv_req_type =  qv_ceu_req_header[127:128-`AXIS_TYPE_WIDTH];
assign wv_req_opcode= qv_ceu_req_header[127-`AXIS_TYPE_WIDTH:128-`AXIS_OPCODE_WIDTH-`AXIS_TYPE_WIDTH];
/*Spyglass*/
//assign wv_req_addr = qv_ceu_req_header[`AXIS_ADDR_WIDTH+64-1:64];
/*Action = Delete*/

//req to ctxmdata has no payload; but has context payload to writectx module
wire ctx_have_payload;
assign ctx_have_payload = ((wv_req_type == `WR_QP_CTX) && (wv_req_opcode == `WR_QP_ALL)) || ((wv_req_type == `WR_CQ_CTX) && (wv_req_opcode == `WR_CQ_ALL)) || ((wv_req_type == `WR_CQ_CTX) && (wv_req_opcode == `WR_CQ_MODIFY)) || ((wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_ALL));

//req to ctxmdata has no context payload, need to write 0 to host memory or change some segs in context enter or read qpc
wire ctx_no_payload;
assign ctx_no_payload =  ((wv_req_type == `RD_QP_CTX) && (wv_req_opcode == `RD_QP_ALL)) || ((wv_req_type == `WR_CQ_CTX) && (wv_req_opcode == `WR_CQ_INVALID)) || ((wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_INVALID)) || ((wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_FUNC));

//no req to key_qpc_data
wire no_kqpc_req;
// Modify by MXX 2022.07.25
// assign no_kqpc_req = ((wv_req_type == `RD_QP_CTX) && (wv_req_opcode == `RD_QP_ALL)) || ((wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_ALL)) || ((wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_INVALID)) || ((wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_FUNC));
assign no_kqpc_req = ((wv_req_type == `RD_QP_CTX) && (wv_req_opcode == `RD_QP_ALL));

//req to key_qpc_data has key context payload;
wire keyqpc_have_payload;
// assign keyqpc_have_payload = ((wv_req_type == `WR_QP_CTX) && (wv_req_opcode == `WR_QP_ALL)) || ((wv_req_type == `WR_CQ_CTX) && (wv_req_opcode == `WR_CQ_ALL)) || ((wv_req_type == `WR_CQ_CTX) && (wv_req_opcode == `WR_CQ_MODIFY));
assign keyqpc_have_payload = ((wv_req_type == `WR_QP_CTX) && (wv_req_opcode == `WR_QP_ALL)) || ((wv_req_type == `WR_CQ_CTX) && (wv_req_opcode == `WR_CQ_ALL)) || ((wv_req_type == `WR_CQ_CTX) && (wv_req_opcode == `WR_CQ_MODIFY)) ||
((wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_ALL));

//req to key_qpc_data has no payload;(CQ_INVALID || CLOSE HCA)
wire keyqpc_no_payload;
// assign keyqpc_no_payload = ((wv_req_type == `WR_CQ_CTX) && (wv_req_opcode == `WR_CQ_INVALID)) || ((wv_req_type == `WR_ICMMAP_CTX) && (wv_req_opcode == `WR_ICMMAP_DIS));
assign keyqpc_no_payload = ((wv_req_type == `WR_CQ_CTX) && (wv_req_opcode == `WR_CQ_INVALID)) || ((wv_req_type == `WR_ICMMAP_CTX) && (wv_req_opcode == `WR_ICMMAP_DIS)) ||
 ((wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_INVALID)) || ((wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_FUNC));

// wire ceu_modify_eq;
// assign ceu_modify_eq = ((wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_INVALID)) || ((wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_FUNC));
//req to ctxmdata has metadata payload
wire mdata_have_payload;
assign mdata_have_payload =  ((wv_req_type == `MAP_ICM_CTX) && (wv_req_opcode == `MAP_ICM_EN)) || ((wv_req_type == `WR_ICMMAP_CTX) && (wv_req_opcode == `WR_ICMMAP_EN));

//req to ctxmdata has no metadata payload
wire mdata_no_payload;
assign mdata_no_payload =  ((wv_req_type == `MAP_ICM_CTX) && (wv_req_opcode == `MAP_ICM_DIS)) || ((wv_req_type == `WR_ICMMAP_CTX) && (wv_req_opcode == `WR_ICMMAP_DIS));

always @(*) begin
    case (fsm_cs)
        // AXIS data coming, PARSE_REQ from AXIS
        PARSE_REQ: begin
            if (ceu_req_ready && ceu_req_valid) begin
                fsm_ns = TRANS_REQ_DATA;
            end else begin
                fsm_ns = PARSE_REQ;
            end
        end    
        TRANS_REQ_DATA:begin
            //next state is PARSE_REQ conditons:
            //1) ctx req & key_qpc_data both have payload, check both req&data fifo aren't full, and it's the last ctx payload, 
            //2) ctx req has paylaod & key_qpc_data has no payload, check ctx req&data, key_qpc_data req fifo aren't full, and it's the last ctx payload
            //3) ctx req & key_qpc_data both have no payload, check both reqfifo aren't full
            //4) mdata req has payload, check mdata req&data fifo aren't full, and it's the last mdata payload(mdata payload num > 1 or not)
            //5) mdata req has no payload, check mdata req fifo aren't full
            /*VCS Verification*/
            //6) CEU has payload, no key_qpc_data req (wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_ALL)
            //7) ctx has no payload, no key_qpc_data req, check  mdata req fifo aren't full
            /*Action = Add*/
            if ((ctx_have_payload && keyqpc_no_payload && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt == wv_payload_num) && !ctx_data_prog_full && !ceu_wr_req_prog_full)  || 
            (ctx_have_payload && keyqpc_have_payload && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt == wv_payload_num) && !ctx_data_prog_full && !ceu_wr_data_prog_full1 && !ceu_wr_req_prog_full) ||
            (ctx_no_payload && keyqpc_no_payload && !ceu_req_ctxmdata_prog_full && !ceu_wr_req_prog_full) || 
            (mdata_have_payload && !ctxmdata_data_prog_full && !ceu_req_ctxmdata_prog_full && (((qv_payload_cnt == wv_payload_num) && (wv_payload_num > 1)) || (wv_payload_num == 1))) ||
            (mdata_no_payload && !ceu_req_ctxmdata_prog_full) ||
            (no_kqpc_req && ctx_have_payload && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt == wv_payload_num) && !ctx_data_prog_full) ||
            (ctx_no_payload && no_kqpc_req && !ceu_req_ctxmdata_prog_full)) begin
                fsm_ns = PARSE_REQ;                
            end
            else begin
                fsm_ns = TRANS_REQ_DATA;
            end
        end
        default: 
            fsm_ns = PARSE_REQ;
    endcase
end

//-----------------Stage 3 : Output--------------------

//externel Parse msg requests header from CEU   
    // output  wire         ceu_req_ready,
    // ready in (1) PARSE_REQ state; (2) TRANS_REQ_DATA state if it has paylaod to receive
/*VCS Verification*/
//Add condition in last: CEU has payload, no key_qpc_data req (wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_ALL)
/*Action = Add*/
assign ceu_req_ready = (fsm_cs == PARSE_REQ) || ((fsm_cs == TRANS_REQ_DATA) && (
            (ctx_have_payload && keyqpc_no_payload && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt < wv_payload_num) && !ctx_data_prog_full && !ceu_wr_req_prog_full)  || 
            (ctx_have_payload && keyqpc_have_payload && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt < wv_payload_num) && !ctx_data_prog_full && !ceu_wr_data_prog_full1 && !ceu_wr_req_prog_full) ||
            (mdata_have_payload && !ctxmdata_data_prog_full && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt < wv_payload_num) && (wv_payload_num > 1)) || 
            ((no_kqpc_req && ctx_have_payload && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt < wv_payload_num) && !ctx_data_prog_full))));

//temporarily store header to wait for extract data
    //reg [`HD_WIDTH-1 :0] qv_ceu_req_header;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_ceu_req_header <= `TD 128'b0;
    end 
    else if (ceu_req_ready && ceu_req_valid && (fsm_cs == PARSE_REQ)) begin
        qv_ceu_req_header <= `TD ceu_req_header;
    end
    else if (fsm_cs == TRANS_REQ_DATA) begin
        qv_ceu_req_header <= `TD qv_ceu_req_header;
    end
    else
        qv_ceu_req_header <= `TD 128'b0;
end

//wv_payload_num;   for PARSE_REQ; all derived msg seemed as payload
    //wire [31:0] wv_payload_num; 
    //condition that: MAP_ICM_EN, payload num = chunk_num/2 + chunk_num%2
assign wv_payload_num = ((wv_req_type == `WR_QP_CTX) && (wv_req_opcode == `WR_QP_ALL)) ? 32'b110 : ((wv_req_type == `WR_CQ_CTX) && ((wv_req_opcode == `WR_CQ_ALL)||(wv_req_opcode == `WR_CQ_MODIFY))) ? 32'b10 : ((wv_req_type == `WR_EQ_CTX)&&(wv_req_opcode == `WR_EQ_ALL)) ? 32'b10 : ((wv_req_type == `MAP_ICM_CTX) && (wv_req_opcode == `MAP_ICM_EN)) ? ({1'b0,qv_ceu_req_header[95:65]} + {31'b0,qv_ceu_req_header[64]}) : ((wv_req_type == `WR_ICMMAP_CTX) && (wv_req_opcode == `WR_ICMMAP_EN)) ? 32'b1 : 32'b0;

//temporarily store payload
    //reg [`DT_WIDTH-1 :0] qv_tmp_ceu_payload;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_tmp_ceu_payload <= `TD 256'b0;
    end
    //receive the ceu data at the same clk when receive ceu req header, no matter if it has payload
    else if ((fsm_cs == PARSE_REQ) && ceu_req_ready && ceu_req_valid) begin
        qv_tmp_ceu_payload <= `TD ceu_req_data;
    end
    else if ((fsm_cs == TRANS_REQ_DATA) && ceu_req_ready && ceu_req_valid) begin
        qv_tmp_ceu_payload <= `TD ceu_req_data;
    end
    else if (fsm_cs == TRANS_REQ_DATA) begin
        qv_tmp_ceu_payload <= `TD qv_tmp_ceu_payload;
    end
    else
        qv_tmp_ceu_payload <= `TD 256'b0;
end

// accumulating payload to make sure which cycle transfer next msg
    //reg [31:0] qv_payload_cnt;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_payload_cnt <= `TD 32'b0;
    end
    //receive the ceu data at the same clk when receive ceu req header, no matter if it has payload
    else if ((fsm_cs == PARSE_REQ) && ceu_req_ready && ceu_req_valid) begin
        qv_payload_cnt <= `TD 32'b1;
    end
    //payload count + 1 when the requset has payload, the count num < total num, new payload is coming
    else if ((fsm_cs == TRANS_REQ_DATA) && (ctx_have_payload || mdata_have_payload) && (qv_payload_cnt < wv_payload_num) && ceu_req_ready && ceu_req_valid ) begin
        qv_payload_cnt <= `TD qv_payload_cnt + 1;
    end
    else if (fsm_cs == TRANS_REQ_DATA) begin
        qv_payload_cnt <= `TD qv_payload_cnt;
    end
    else
        qv_payload_cnt <= `TD 32'b0;
end

//rebuild payload for derived msg which has payload
    //reg [`KEY_QPC_DT-1 :0] qv_rebuild_payload1;
    //reg [`KEY_QPC_DT-1 :0] qv_rebuild_payload2;
/*-----------------------------------------------------------------------------------
//internal whole key_qpc_data entry payload data:
//offset |        +0         |      +1         |         +2	     |        +3       |
//       | 7 6 5 4 | 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 |
-------------------------------Old version info ----------------------------------------
//  00h  |  state  |	0    |    servtype     |   mtu_msgmax    |    rnr_retry    |
//  04h  |                    local_qpn                                            |
//  08h  |                    remote_qpn                                           |
//  0Ch  |                    port_pkey                                            |
//  10h  |                    pd                                                   |
//  14h  |                    wqe_lkey -- sl_tclass_flowlabel                      |
//  18h  |                    next_send_psn(Next PSN)                              |
//  1Ch  |                    cqn -- cqn_send                                      |
//  20h  |                    snd_wqe_base_lky                                     |
//  24h  |                    last_acked_psn(UnAckedPSN)                           |
//  28h  |                    rnr_nextrecvpsn(Expected PSN)                        |
//  2Ch  |                    rcv_wqe_base_lkey                                    |
-------------------------------Old version info ------------------------------------
-------------------------------New version added info-------------------------------
//  00h  |      	0        |     	0          | rq_entry_sz_log | sq_entry_sz_log |
//  04h  |        dlid(dmac[15:0])   	       |        	slid(smac[15:0])       |
//  08h  |                    smac[47:16]                                          |
//  0Ch  |                    dmac[47:16]                                          |
//  10h  |                    sip                                                  |
//  14h  |                    dip                                                  |
//  18h  |                    snd_wqe_length(SQ Length)                            |
//  1Ch  |                    cqn_rcv                                              |
//  20h  |                    rcv_wqe_length(RQ Length)                            |
//  24h  |                    reserved                                             |
//  28h  |                    reserved                                             |
//  2Ch  |                    reserved                                             |
-------------------------------New version added info-------------------------------*/
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_rebuild_payload1 <= `TD 384'b0;
        qv_rebuild_payload2 <= `TD 384'b0;
    end
    else if ((fsm_cs == TRANS_REQ_DATA) && (wv_req_type == `WR_QP_CTX) && (wv_req_opcode == `WR_QP_ALL)) begin
        case (qv_payload_cnt)
            32'd1: begin
                //state info
                qv_rebuild_payload1[32*12-1:32*12-4] <= `TD  qv_tmp_ceu_payload[32*6-1:32*6-4];
                //service type info
                qv_rebuild_payload1[32*12-1-8:32*12-16] <= `TD  qv_tmp_ceu_payload[32*6-1-8:32*6-16];
                //MPTU info
                qv_rebuild_payload1[32*12-1-16:32*12-24] <= `TD  qv_tmp_ceu_payload[32*5-1:32*5-8];
                //local QPN, remote QPN, PKey info
                qv_rebuild_payload1[32*11-1:32*8] <= `TD  qv_tmp_ceu_payload[32*3-1:0];
                /**********Add in new version**********/
                //rq_entry_sz_log 
                //sq_entry_sz_log
                qv_rebuild_payload2[32*12-1-16:32*11] <= `TD  qv_tmp_ceu_payload[32*5-1-8:32*5-24];
                /**********Add in new version**********/
            end
            32'd2: begin
                //RNR_retry info
                qv_rebuild_payload1[32*11+7:32*11] <= `TD  qv_tmp_ceu_payload[32*8-1:32*8-8];
                /**********Add in new version**********/
                //sl_tclass_flowlabel 
                qv_rebuild_payload1[32*7-1:32*6] <= `TD  qv_tmp_ceu_payload[32*6-1:32*5];
                //dlid(dmac[15:0])	slid(smac[15:0])
                qv_rebuild_payload2[32*11-1:32*10] <= `TD  qv_tmp_ceu_payload[32-1:0];
                /**********Add in new version**********/
            end
            32'd3: begin
                //Portect Domain info
                qv_rebuild_payload1[32*8-1:32*7] <= `TD  qv_tmp_ceu_payload[31:0];
                /**********Add in new version**********/
                //smac[47:16],dmac[47:16],sip,dip
                qv_rebuild_payload2[32*10-1:32*6] <= `TD  qv_tmp_ceu_payload[32*8-1:32*4];
                /**********Add in new version**********/
            end
            32'd4: begin
                //WQE_LKey info
                // qv_rebuild_payload1[32*7-1:32*6] <= `TD  qv_tmp_ceu_payload[32*7-1:32*6];
                //Next send PSN, cqn_snd, send_wqe_base_lkey info
                qv_rebuild_payload1[32*6-1:32*3] <= `TD  qv_tmp_ceu_payload[32*5-1:32*2];
                //last_ascked_PSN(UnAckedPSN) info
                qv_rebuild_payload1[32*3-1:32*2] <= `TD  qv_tmp_ceu_payload[31:0];   
                /**********Add in new version**********/
                //snd_wqe_length(SQ Length)
                qv_rebuild_payload2[32*6-1:32*5] <= `TD  qv_tmp_ceu_payload[32*2-1:32];
                /**********Add in new version**********/             
            end
            32'd5: begin
                //rnr_nextrecvpsn(Expected PSN) info
                qv_rebuild_payload1[32*2-1:32*1] <= `TD  qv_tmp_ceu_payload[32*7-1:32*6];
                //rcv_wqe_base_lkey info
                qv_rebuild_payload1[32-1:0] <= `TD  qv_tmp_ceu_payload[32*4-1:32*3];             
                /**********Add in new version**********/
                //cqn_rcv
                qv_rebuild_payload2[32*5-1:32*4] <= `TD  qv_tmp_ceu_payload[32*5-1:32*4];
                //rcv_wqe_length
                qv_rebuild_payload2[32*4-1:32*3] <= `TD  qv_tmp_ceu_payload[32*3-1:32*2];
                /**********Add in new version**********/ 
            end
            default: begin
               qv_rebuild_payload1 <= `TD qv_rebuild_payload1;
               qv_rebuild_payload2 <= `TD qv_rebuild_payload2; 
            end
        endcase
    end 
    else if ((fsm_cs == TRANS_REQ_DATA) && (wv_req_type == `WR_CQ_CTX) && ((wv_req_opcode == `WR_CQ_ALL) || (wv_req_opcode == `WR_CQ_MODIFY))) begin
        if ((qv_payload_cnt == 1)) begin
            //CQ_Lkey info
            // qv_rebuild_payload1 <= `TD {352'b0,qv_tmp_ceu_payload[63:32]}; 
            qv_rebuild_payload1[31:0] <= `TD qv_tmp_ceu_payload[63:32]; 
            /**********Add in new version**********/
            //CQ logsize
            qv_rebuild_payload1[32*3-1:32*3-8] <= `TD  qv_tmp_ceu_payload[32*5-1:32*5-8];
            //CQ pd
            qv_rebuild_payload1[32*2-1:32*1] <= `TD  qv_tmp_ceu_payload[32*3-1:32*2];
            /**********Add in new version**********/ 
            //CQ eqn
            qv_rebuild_payload1[32*4-1:32*3] <= `TD  qv_tmp_ceu_payload[32*4-1:32*3];
            /**********Add in new version Add by MXX 2022.07.25**********/ 
        end else begin
            qv_rebuild_payload1 <= `TD qv_rebuild_payload1;
            qv_rebuild_payload2 <= `TD qv_rebuild_payload2;
        end
    end
    else if ((fsm_cs == TRANS_REQ_DATA) && (wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_ALL)) begin
        if ((qv_payload_cnt == 1)) begin
            //EQ_Lkey info
            // qv_rebuild_payload1 <= `TD {352'b0,qv_tmp_ceu_payload[63:32]}; 
            qv_rebuild_payload1[31:0] <= `TD qv_tmp_ceu_payload[31:0]; 
            /**********Add in new version**********/
            //EQ logsize
            qv_rebuild_payload1[32*3-1:32*3-16] <= `TD  qv_tmp_ceu_payload[32*5-1:32*5-16];
            //EQ pd
            qv_rebuild_payload1[32*2-1:32*1] <= `TD  qv_tmp_ceu_payload[32*2-1:32];
            /**********Add in new version Add by MXX 2022.07.25**********/ 
            //EQ msix-vector
            qv_rebuild_payload1[32*2+15:32*2] <= `TD  qv_tmp_ceu_payload[32*2+15:32*2];
            /**********Add in new version Add by MXX 2022.07.25**********/ 
        end else begin
            qv_rebuild_payload1 <= `TD qv_rebuild_payload1;
            qv_rebuild_payload2 <= `TD qv_rebuild_payload2;
        end
    end
    else begin
        qv_rebuild_payload1 <= `TD 384'b0;
        qv_rebuild_payload2 <= `TD 384'b0;
    end
end

//rebuild header for derived key_qpc_dat req header
    //reg [`CEUP_REQ_KEY-1 :0] qv_rebuild_key_header;//for key_qpc_data
    //|----------------------35bit-------------------|
    //|   type 4   |  opcode 4 | SOUR 3 |  QP_num 24 |
//rebuild header for derived ctxmdata req header
    //reg [`CEUP_REQ_MDT-1 :0] qv_rebuild_mdt_header;//for ctxmdata
    //|----------------------128bit----------------------|
    //|   type 4 | opcode 4 |  R 24  | Addr 32 | Data 64 | 
/*VCS Verification*/
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_rebuild_key_header <= 32'b0;
        qv_rebuild_mdt_header <= 128'b0;
    end
    else if ((fsm_cs == TRANS_REQ_DATA) && (keyqpc_have_payload || keyqpc_no_payload))begin
        // qv_rebuild_key_header <= ((wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_FUNC)) ? {qv_ceu_req_header[127:120],`CEU,qv_ceu_req_header[95],qv_ceu_req_header[86:64]} : {qv_ceu_req_header[127:120],`CEU,qv_ceu_req_header[87:64]};
        qv_rebuild_key_header <= ((wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_FUNC)) ? {qv_ceu_req_header[127:120],qv_ceu_req_header[95],qv_ceu_req_header[86:64]} : {qv_ceu_req_header[127:120],qv_ceu_req_header[87:64]};
        qv_rebuild_mdt_header <= qv_ceu_req_header;
        //modify for and EQ_FUNC/ EQ_INVALID cmd
        // qv_rebuild_mdt_header <= (!ceu_modify_eq) ? qv_ceu_req_header : 128'b0;
    end
    else if (fsm_cs == TRANS_REQ_DATA) begin
        qv_rebuild_key_header <= 32'b0;
        qv_rebuild_mdt_header <= qv_ceu_req_header;
    end
    else begin
        qv_rebuild_key_header <= 32'b0;
        qv_rebuild_mdt_header <= 128'b0;
    end
end
/*Action = Modify, Change combinatorial logic to temporal logic*/

// internal request cmd fifo to write key_qpc_data
    //    reg                        ceu_wr_req_wr_en;
// internal context data fifo to write key_qpc_data
    //    reg                        ceu_wr_data_wr_en1;
// internal req cmd to ctxmdata Module
    //    reg                    ceu_req_ctxmdata_wr_en;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        ceu_wr_req_wr_en       <= `TD 1'b0;
        ceu_wr_data_wr_en1      <= `TD 1'b0;
        ceu_wr_data_wr_en2      <= `TD 1'b0;
        ceu_req_ctxmdata_wr_en <= `TD 1'b0;
    end

    //key_qpc_data&ctx req has payload & payload is ready & fifo aren't full, write req and data at the same clk
    else if ((fsm_cs == TRANS_REQ_DATA) && keyqpc_have_payload && ctx_have_payload && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt == wv_payload_num) && !ctx_data_prog_full && !ceu_wr_data_prog_full1 && !ceu_wr_req_prog_full) begin
        ceu_wr_req_wr_en       <= `TD 1'b1;
        ceu_wr_data_wr_en1      <= `TD 1'b1;
        ceu_wr_data_wr_en2      <= `TD (wv_req_type == `WR_QP_CTX) ? 1'b1 : 1'b0;
        ceu_req_ctxmdata_wr_en <= `TD 1'b1;
    end
    //key_qpc_data req has no payload & ctx req has payload & payload is ready & fifo aren't full, write req and data at the same clk
    else if ((fsm_cs == TRANS_REQ_DATA) && ((keyqpc_no_payload && ctx_have_payload && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt == wv_payload_num) && !ctx_data_prog_full && !ceu_wr_req_prog_full) || (ctx_no_payload && keyqpc_no_payload && !ceu_req_ctxmdata_prog_full && !ceu_wr_req_prog_full)))begin
        ceu_wr_req_wr_en       <= `TD 1'b1;
        ceu_wr_data_wr_en1      <= `TD 1'b0;
        ceu_wr_data_wr_en2      <= `TD 1'b0;
        ceu_req_ctxmdata_wr_en <= `TD 1'b1;
    end
    /*VCS Verification*/
    //ctxmdata req or ctx req has no payload & ctxmdata paylaod is ready & fifo aren't full, write req and data at the same clk
    else if ((fsm_cs == TRANS_REQ_DATA) && ((mdata_have_payload && !ctxmdata_data_prog_full && !ceu_req_ctxmdata_prog_full && (((qv_payload_cnt == wv_payload_num) && (wv_payload_num > 1)) || (wv_payload_num == 1))) || ((mdata_no_payload || ctx_no_payload) && !ceu_req_ctxmdata_prog_full) || ((no_kqpc_req && ctx_have_payload && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt == wv_payload_num) && !ctx_data_prog_full)))) begin
    /*Action = Modify, add WR_EQ condition*/
        ceu_wr_req_wr_en       <= `TD 1'b0;
        ceu_wr_data_wr_en1      <= `TD 1'b0;
        ceu_wr_data_wr_en2      <= `TD 1'b0;
        ceu_req_ctxmdata_wr_en <= `TD 1'b1;
    end
    else begin
        ceu_wr_req_wr_en       <= `TD 1'b0;
        ceu_wr_data_wr_en1      <= `TD 1'b0;
        ceu_wr_data_wr_en2      <= `TD 1'b0;
        ceu_req_ctxmdata_wr_en <= `TD 1'b0;
    end
end

// internel context metaddata payload to write ctxmdata Module
    //    reg                    ctxmdata_data_wr_en;
// internal context data to writectx module to write to host memory
    //    reg                    ctx_data_wr_en;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        ctxmdata_data_wr_en    <= `TD 1'b0;
        ctx_data_wr_en         <= `TD 1'b0;
    end
    /*VCS Verification*/
    //ctx req has payload & payload is ready & fifo aren't full, write data to the dma_write_ctx dest fifo
   else if ((fsm_cs == TRANS_REQ_DATA) && ((keyqpc_have_payload && ctx_have_payload && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt == wv_payload_num) && !ctx_data_prog_full && !ceu_wr_data_prog_full1 && !ceu_wr_req_prog_full) || ((ctx_have_payload && keyqpc_have_payload && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt < wv_payload_num) && !ctx_data_prog_full && !ceu_wr_data_prog_full1 && !ceu_wr_req_prog_full) && ceu_req_ready && ceu_req_valid) || (no_kqpc_req && ctx_have_payload && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt == wv_payload_num) && !ctx_data_prog_full) || (no_kqpc_req && ctx_have_payload && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt < wv_payload_num) && !ctx_data_prog_full && ceu_req_ready && ceu_req_valid))) begin
        /*Action = Modify*/
        ctxmdata_data_wr_en    <= `TD 1'b0;
        ctx_data_wr_en         <= `TD 1'b1;
    end
    //ctxmdata req has payload & payload is ready & fifo aren't full, write data to the ctxmdata dest fifo
    /*VCS Verification*/
    //else if ((fsm_cs == TRANS_REQ_DATA) && (mdata_have_payload && !ctxmdata_data_prog_full && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt <= wv_payload_num) && (wv_payload_num >= 1))) begin
    else if ((fsm_cs == TRANS_REQ_DATA) && ((mdata_have_payload && !ctxmdata_data_prog_full && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt == wv_payload_num) && (wv_payload_num >= 1)) || (mdata_have_payload && !ctxmdata_data_prog_full && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt < wv_payload_num) && (wv_payload_num >= 1) && ceu_req_ready && ceu_req_valid))) begin
        /*Action = Modify*/
        /*Spyglass*/
        ctxmdata_data_wr_en    <= `TD 1'b1;
        ctx_data_wr_en         <= `TD 1'b0;
        /*Action = add*/
    end else begin
        ctxmdata_data_wr_en    <= `TD 1'b0;
        ctx_data_wr_en         <= `TD 1'b0;
    end
end

// internal request cmd fifo to write key_qpc_data
    //    reg  [`CEUP_REQ_KEY-1:0]   ceu_wr_req_din;  //53 width 8 depth
always @(*) begin
    if (rst) begin
        ceu_wr_req_din  = 35'b0;
    end 
    else if ((keyqpc_no_payload || keyqpc_have_payload) && ceu_wr_req_wr_en) begin
        // ceu_wr_req_din  = qv_rebuild_key_header;
        ceu_wr_req_din  = {qv_rebuild_key_header[31:24],`CEU,qv_rebuild_key_header[23:0]};
        // qv_rebuild_key_header <= ((wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_FUNC)) ? {qv_ceu_req_header[127:120],`CEU,qv_ceu_req_header[95],qv_ceu_req_header[86:64]} : {qv_ceu_req_header[127:120],`CEU,qv_ceu_req_header[87:64]};
    end
    else begin
        ceu_wr_req_din  = 35'b0;
    end    
end
// internal context data fifo to write key_qpc_data
    //    reg  [`KEY_QPC_DT-1:0]     ceu_wr_data_din1; //384 width 8 depth
always @(*) begin
    if (rst) begin
        ceu_wr_data_din1  = 384'b0;
    end 
    else if (keyqpc_have_payload && ceu_wr_data_wr_en1) begin
        ceu_wr_data_din1  = qv_rebuild_payload1;
    end
    else begin
        ceu_wr_data_din1  = 384'b0;
    end    
end
    //    reg  [`KEY_QPC_DT-1:0]     ceu_wr_data_din2; //384 width 8 depth
always @(*) begin
    if (rst) begin
        ceu_wr_data_din2  = 384'b0;
    end 
    else if (keyqpc_have_payload && ceu_wr_data_wr_en2) begin
        ceu_wr_data_din2  = qv_rebuild_payload2;
    end
    else begin
        ceu_wr_data_din2  = 384'b0;
    end    
end

// internal req cmd to ctxmdata Module
    //    reg  [`CEUP_REQ_MDT-1:0]  ceu_req_ctxmdata_din;//128 width 8 depth
always @(*) begin
    if (rst) begin
        ceu_req_ctxmdata_din  = 128'b0;
    end 
    else if ((mdata_have_payload || mdata_no_payload || ctx_no_payload || ctx_have_payload) && ceu_req_ctxmdata_wr_en) begin
        ceu_req_ctxmdata_din  = qv_rebuild_mdt_header;
    end
    else begin
        ceu_req_ctxmdata_din  = 128'b0;
    end    
end

// internel context metaddata payload to write ctxmdata Module
always @(posedge clk or posedge rst) begin
    if (rst) begin
        ctxmdata_data_din <= 256'b0;
    end
    /*VCS Verification*/
    //else if ((fsm_cs == TRANS_REQ_DATA) && mdata_have_payload && !ctxmdata_data_prog_full && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt <= wv_payload_num) && (wv_payload_num >= 1)) begin
    else if ((fsm_cs == TRANS_REQ_DATA) && ((mdata_have_payload && !ctxmdata_data_prog_full && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt == wv_payload_num) && (wv_payload_num >= 1)) || (mdata_have_payload && !ctxmdata_data_prog_full && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt < wv_payload_num) && (wv_payload_num >= 1) && ceu_req_ready && ceu_req_valid))) begin
    /*Action = Modify*/
        ctxmdata_data_din <= qv_tmp_ceu_payload;
    end
    else begin
        ctxmdata_data_din <= 256'b0;
    end
end
/*Action = Modify, Change combinatorial logic to temporal logic*/

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ctx_data_din <= 256'b0;
    end
        /*VCS Verification*/
    else if ((fsm_cs == TRANS_REQ_DATA) && ((keyqpc_have_payload && ctx_have_payload && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt == wv_payload_num) && !ctx_data_prog_full && !ceu_wr_data_prog_full1 && !ceu_wr_req_prog_full) || ((ctx_have_payload && keyqpc_have_payload && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt < wv_payload_num) && !ctx_data_prog_full && !ceu_wr_data_prog_full1 && !ceu_wr_req_prog_full) && ceu_req_ready && ceu_req_valid) || (no_kqpc_req && ctx_have_payload && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt == wv_payload_num) && !ctx_data_prog_full) || (no_kqpc_req && ctx_have_payload && !ceu_req_ctxmdata_prog_full && (qv_payload_cnt < wv_payload_num) && !ctx_data_prog_full && ceu_req_ready && ceu_req_valid))) begin
    /*Action = Modify*/
        ctx_data_din <= qv_tmp_ceu_payload;
    end
    else begin
        ctx_data_din <= 256'b0;
    end
end
/*Action = Modify, Change combinatorial logic to temporal logic*/


`ifdef CTX_DUG
    // /*****************Add for APB-slave regs**********************************/ 
    // reg                        ceu_wr_req_wr_en;           //1                      
    // reg  [`CEUP_REQ_KEY-1:0]   ceu_wr_req_din;             //CEUP_REQ_KEY=35
    // reg                        ceu_wr_data_wr_en1;         //1
    // reg  [`KEY_QPC_DT-1:0]     ceu_wr_data_din1;           //KEY_QPC_DT=384 
    // reg                        ceu_wr_data_wr_en2;         //1
    // reg  [`KEY_QPC_DT-1:0]     ceu_wr_data_din2;           //KEY_QPC_DT=384 
    // reg                       ceu_req_ctxmdata_wr_en;      //1                      
    // reg  [`CEUP_REQ_MDT-1:0]  ceu_req_ctxmdata_din;        //CEUP_REQ_MDT = 128
    // reg                    ctxmdata_data_wr_en;            //1
    // reg  [`INTER_DT-1:0]   ctxmdata_data_din;              //INTER_DT=256
    // reg                    ctx_data_wr_en;                 //1
    // reg  [`INTER_DT-1:0]   ctx_data_din;                   //INTER_DT=256
    // reg [1:0] fsm_cs;                                      //2
    // reg [1:0] fsm_ns;                                      //2
    // reg [`HD_WIDTH-1 :0] qv_ceu_req_header;                //HD_WIDTH=128
    // reg [`DT_WIDTH-1 :0] qv_tmp_ceu_payload;               //DT_WIDTH=256
    // reg [31:0] qv_payload_cnt;                             //32
    // reg [`KEY_QPC_DT-1 :0] qv_rebuild_payload1;            //KEY_QPC_DT = 384 
    // reg [`KEY_QPC_DT-1 :0] qv_rebuild_payload2;            //KEY_QPC_DT = 384 
    // reg [`CEUP_REQ_KEY-1-3 :0] qv_rebuild_key_header;      //CEUP_REQ_KEY = 32
    // reg [`CEUP_REQ_MDT-1 :0] qv_rebuild_mdt_header;        //CEUP_REQ_MDT = 128 

    //total regs count = wr_en(6) + fsm(2*2) + reg (35+384*4+128*3+256*3+32*2) = 2797 

    // /*****************Add for APB-slave wires**********************************/ 
    // wire                       ceu_req_valid,              //1 
    // wire                       ceu_req_ready,              //1 
    // wire [`DT_WIDTH-1:0]       ceu_req_data,               //256 
    // wire                       ceu_req_last,               //1 
    // wire [`HD_WIDTH-1:0]       ceu_req_header,             //128 
    // wire                       ceu_wr_req_rd_en,           //1 
    // wire                       ceu_wr_req_empty,           //1 
    // wire [`CEUP_REQ_KEY-1:0]   ceu_wr_req_dout,            //35 
    // wire                       ceu_wr_data_rd_en1,         //1 
    // wire                       ceu_wr_data_empty1,         //1 
    // wire [`KEY_QPC_DT-1:0]     ceu_wr_data_dout1,          //384 
    // wire                       ceu_wr_data_rd_en2,         //1 
    // wire                       ceu_wr_data_empty2,         //1 
    // wire [`KEY_QPC_DT-1:0]     ceu_wr_data_dout2,          //384 
    // wire                      ceu_req_ctxmdata_rd_en,      //1 
    // wire                      ceu_req_ctxmdata_empty,      //1 
    // wire [`CEUP_REQ_MDT-1:0]  ceu_req_ctxmdata_dout,       //128 
    // wire                   ctxmdata_data_rd_en,            //1 
    // wire                   ctxmdata_data_empty,            //1 
    // wire [`INTER_DT-1:0]   ctxmdata_data_dout,             //256 
    // wire                  ctx_data_rd_en,                  //1 
    // wire                  ctx_data_empty,                  //1 
    // wire [`INTER_DT-1:0]  ctx_data_dout                    //256 
    // wire                       ceu_wr_req_prog_full;       //1 
    // wire                       ceu_wr_data_prog_full1;     //1 
    // wire                       ceu_wr_data_prog_full2;     //1 
    // wire                      ceu_req_ctxmdata_prog_full;  //1 
    // wire                   ctxmdata_data_prog_full;        //1 
    // wire                   ctx_data_prog_full;             //1 
    // wire [31:0] wv_payload_num;                            //32 
    // wire [3:0]  wv_req_type;                               //4 
    // wire [3:0]  wv_req_opcode;                             //4 
    // wire ctx_have_payload;                                 //1 
    // wire ctx_no_payload;                                   //1 
    // wire no_kqpc_req;                                      //1 
    // wire keyqpc_have_payload;                              //1 
    // wire keyqpc_no_payload;                                //1 
    // wire mdata_have_payload;                               //1 
    // wire mdata_no_payload;                                 //1 
    
    //total wires count = 1bit_signal(28) + 256*3 + 128*2 + 35 + 384*2 + 32 + 4*2 = 1895

    //Total regs and wires : 2797 + 1895 = 4692 = 32 * 146 + 20. bit align 147

    assign wv_dbg_bus_1 = {
        20'b0,
        ceu_wr_req_wr_en,
        ceu_wr_req_din,
        ceu_wr_data_wr_en1,
        ceu_wr_data_din1,
        ceu_wr_data_wr_en2,
        ceu_wr_data_din2,
        ceu_req_ctxmdata_wr_en,
        ceu_req_ctxmdata_din,
        ctxmdata_data_wr_en,
        ctxmdata_data_din,
        ctx_data_wr_en,
        ctx_data_din,
        fsm_cs,
        fsm_ns,
        qv_ceu_req_header,
        qv_tmp_ceu_payload,
        qv_payload_cnt,
        qv_rebuild_payload1,
        qv_rebuild_payload2,
        qv_rebuild_key_header,
        qv_rebuild_mdt_header,
    
        ceu_req_valid,
        ceu_req_ready,
        ceu_req_data,
        ceu_req_last,
        ceu_req_header,
        ceu_wr_req_rd_en,
        ceu_wr_req_empty,
        ceu_wr_req_dout,
        ceu_wr_data_rd_en1,
        ceu_wr_data_empty1,
        ceu_wr_data_dout1,
        ceu_wr_data_rd_en2,
        ceu_wr_data_empty2,
        ceu_wr_data_dout2,
        ceu_req_ctxmdata_rd_en,
        ceu_req_ctxmdata_empty,
        ceu_req_ctxmdata_dout,
        ctxmdata_data_rd_en,
        ctxmdata_data_empty,
        ctxmdata_data_dout,
        ctx_data_rd_en,
        ctx_data_empty,
        ctx_data_dout,
        ceu_wr_req_prog_full,
        ceu_wr_data_prog_full1,
        ceu_wr_data_prog_full2,
        ceu_req_ctxmdata_prog_full,
        ctxmdata_data_prog_full,
        ctx_data_prog_full,
        wv_payload_num,
        wv_req_type,
        wv_req_opcode,
        ctx_have_payload,
        ctx_no_payload,
        no_kqpc_req,
        keyqpc_have_payload,
        keyqpc_no_payload,
        mdata_have_payload,
        mdata_no_payload
    };
`endif 

endmodule




