//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: dma_write_ctx_ctxmgt.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V0.0 
// VERSION DESCRIPTION: 1st Edition  
//----------------------------------------------------
// RELEASE DATE: 2022-08-30
//---------------------------------------------------- 
// PURPOSE: write context to host memory.
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
// 
//-FHDR-----------------------------------------------

//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_ctxmgt_h.vh"

module dma_write_ctx_ctxmgt(
    input clk,
    input rst,
    
    //-------------ctxmdata module interface------------------
        //| ------------------128bit------------------------------------|
        //|   type   |  opcode |   Src   | R      |   data   |   addr   | 
        //|    4 bit |  4 bit  |  3 bit  |21 bit  |  32 bit  |  64 bit  |   
    //DMA write Ctx Request from ctxmdata
    output wire                     mdt_req_wr_ctx_rd_en,
    input  wire  [`HD_WIDTH-1:0]    mdt_req_wr_ctx_dout,
    input  wire                     mdt_req_wr_ctx_empty,

    //-------------ceu_parser interface------------------
    // internal context data to writectx module to write to host memory
    output wire                  ctx_data_rd_en,
    input  wire                  ctx_data_empty,
    input  wire [`INTER_DT-1:0]  ctx_data_dout,

    //-------------DMA Engine module interface------------------
    /* dma_*_head(interact with DMA modules), valid only in first beat of a packet
    //|    src   | reserved_h  | address | reserved_l | Byte length |
    //|  127:125 |   124:96    |  95:32  |  31:12     |    11:0     |
     */
    //DMA Write Ctx Request Out interface
    output  wire                           dma_cm_wr_req_valid,
    output  wire                           dma_cm_wr_req_last ,
    output  wire [(`DT_WIDTH-1):0]         dma_cm_wr_req_data ,
    output  wire [(`HD_WIDTH-1):0]         dma_cm_wr_req_head ,
    input   wire                           dma_cm_wr_req_ready
        
    `ifdef CTX_DUG
        /*Interface with APB Slave*/
	    ,output wire 		[`WRCTX_DBG_REG_NUM * 32 - 1 : 0]		wv_dbg_bus_4
    `endif 
);

//variables decleration
reg  [`DT_WIDTH-1 :0]     qv_tmp_data; 
reg  [`HD_WIDTH-1 :0]     qv_tmp_header;

wire [3:0]   wv_req_type;//extract from the tmp_header
wire [3:0]   wv_req_opcode;//extract from the tmp_header
/*Spyglass*/
//wire [2:0]   wv_req_source;//extract from the tmp_header
/*Action = Delete*/

reg  [11:0]  wv_dma_req_length;//judge from the req_type and req_opcode

wire  [3:0]  wv_out_payload_cnt;//counter for paylaod data of dma write req out 
reg  [3:0]   qv_out_payload_cnt;//counter for paylaod data of dma write req out 

reg  [3:0]   wv_out_payload_num;//total payload num of dma write req out,judge from the req_type and req_opcode

wire         has_input_payload;//indicate that we will read paylaod from ceu_parser ctx_data fifo
wire         no_input_payload;//indicate that there is no paylaod from ceu_parser ctx_data fifo

reg  [3:0]   qv_recv_payload_cnt;//counter for paylaod data from ceu_parser ctx_data fifo
reg  [3:0]   wv_recv_payload_num;//total payload num from ceu_parser ctx_data fifo,judge from the req_type and req_opcode

//state machine parameters
//registers
reg [1:0] fsm_cs;
reg [1:0] fsm_ns;

//get header and the fisrt cycle data from ctxmdata
parameter PARSE_REQ  = 2'b01;
//make sure whether it has payload
//if it doesn't have payload(key_qpc_data req), extract data from header and initiate dma write req
//if it has payload(ceu_parser req), read payload, initiate dma write req
parameter REQ_OUT    = 2'b10;

//-----------------Stage 1 :State Register----------
always @(posedge clk or posedge rst) begin
    if(rst)
        fsm_cs <= `TD PARSE_REQ;
    else
        fsm_cs <= `TD fsm_ns;
end

//-----------------Stage 2 :State Transition----------
always @(*) begin
    case (fsm_cs)
        //ctxmdata dma write req coming, get req fifo dout
        PARSE_REQ: begin
            if (!mdt_req_wr_ctx_empty) begin
                fsm_ns = REQ_OUT;
            end else begin
                fsm_ns = PARSE_REQ;
            end
        end    
        REQ_OUT:begin
            //next state is PARSE_REQ conditons:
            //1) ceu_parser req have payload, and this is the last payload to be transfered, and dma engine is ready            
            //2) key_qpc_data req has 0 payload, and dma engine is ready            
            // if ((dma_cm_wr_req_ready && (((qv_out_payload_cnt + 1== wv_out_payload_num) && qv_tmp_header[96]) || !qv_tmp_header[96]) && has_input_payload && (qv_recv_payload_cnt + 1 == wv_recv_payload_num) && ctx_data_rd_en) || (dma_cm_wr_req_ready && (qv_out_payload_cnt + 1== wv_out_payload_num) && no_input_payload)) begin
            if ((dma_cm_wr_req_ready && (((wv_out_payload_cnt == wv_out_payload_num) && qv_tmp_header[96]) || !qv_tmp_header[96]) && has_input_payload && (qv_recv_payload_cnt == wv_recv_payload_num)) || (dma_cm_wr_req_ready && (wv_out_payload_cnt == wv_out_payload_num) && no_input_payload)) begin
                fsm_ns = PARSE_REQ;                
            end
            else begin
                fsm_ns = REQ_OUT;
            end
        end
        default: 
            fsm_ns = PARSE_REQ;
    endcase
end

//-----------------Stage 3 : Output--------------------
//mdt_req_wr_ctx_rd_en
assign mdt_req_wr_ctx_rd_en = (fsm_cs == PARSE_REQ) && !mdt_req_wr_ctx_empty;

//ctx_data_rd_en
assign ctx_data_rd_en = (fsm_cs == REQ_OUT) && has_input_payload && (qv_recv_payload_cnt < wv_recv_payload_num) && dma_cm_wr_req_ready && !ctx_data_empty;

//reg  [`DT_WIDTH-1 :0]     qv_tmp_data; 
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_tmp_data <= `TD 0;
    end
    else if (ctx_data_rd_en) begin
        qv_tmp_data <= `TD ctx_data_dout;
    end
    else if (fsm_cs == REQ_OUT) begin
        qv_tmp_data <= `TD qv_tmp_data;
    end
    else begin
        qv_tmp_data <= `TD 0;
    end
end

//reg  [`HD_WIDTH-1 :0]     qv_tmp_header;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_tmp_header <= `TD 0;
    end
    else if (mdt_req_wr_ctx_rd_en) begin
        qv_tmp_header <= `TD mdt_req_wr_ctx_dout;
    end
    else if (fsm_cs == REQ_OUT) begin
        qv_tmp_header <= `TD qv_tmp_header;
    end
    else begin
        qv_tmp_header <= `TD 0;
    end
end

//wire [3:0]   wv_req_type  ;//extract from the tmp_header
//wire [3:0]   wv_req_opcode;//extract from the tmp_header
//wire [2:0]   wv_req_source;//extract from the tmp_header
assign wv_req_type   = qv_tmp_header[127:124];
assign wv_req_opcode = qv_tmp_header[123:120];
/*Spyglass*/
//assign wv_req_source = qv_tmp_header[119:117];
/*Action = Delete*/


//reg [11:0]  wv_dma_req_length;//judge from the req_type and req_opcode
always @(*) begin
    if (rst) begin
        wv_dma_req_length = 0;
    end else begin
        case ({wv_req_type,wv_req_opcode})
            {`WR_QP_CTX,`WR_QP_ALL}: begin
                wv_dma_req_length = 12'd164;
            end
            {`WR_CQ_CTX,`WR_CQ_ALL}:begin
                wv_dma_req_length = 12'd56;
            end
            {`WR_CQ_CTX,`WR_CQ_MODIFY}:begin
                wv_dma_req_length = 12'd56;
            end
            {`WR_EQ_CTX,`WR_EQ_ALL}:begin
                wv_dma_req_length = 12'd48;
            end
            {`WR_CQ_CTX,`WR_CQ_INVALID}:begin
                wv_dma_req_length = 12'd56;
            end
            {`WR_EQ_CTX,`WR_EQ_INVALID}:begin
                wv_dma_req_length = 12'd48;
            end
            {`WR_EQ_CTX,`WR_EQ_FUNC}:begin
                wv_dma_req_length = 12'd4;                
            end
            {`WR_QP_CTX,`WR_QP_STATE}:begin
                wv_dma_req_length = 12'd1; 
            end
            {`WR_QP_CTX,`WR_QP_UAPST}:begin
                wv_dma_req_length = 12'd4;
            end
            {`WR_QP_CTX,`WR_QP_NPST}:begin
                wv_dma_req_length = 12'd4;
            end
            {`WR_QP_CTX,`WR_QP_EPST}:begin
                wv_dma_req_length = 12'd4;
            end
            default: wv_dma_req_length = 0;
        endcase
    end    
end

//reg  [3:0]   qv_out_payload_cnt;//counter for paylaod data of dma write req out 
// assign wv_out_payload_cnt = ((dma_cm_wr_req_ready && (wv_out_payload_cnt < wv_out_payload_num) && (qv_recv_payload_cnt > wv_out_payload_cnt) && qv_tmp_header[96]) || (dma_cm_wr_req_ready && (wv_out_payload_cnt < wv_out_payload_num) && no_input_payload && (fsm_cs == REQ_OUT))) ? qv_out_payload_cnt : (qv_out_payload_cnt == 0) ? 0 : wv_out_payload_cnt;
assign wv_out_payload_cnt = (!dma_cm_wr_req_ready && (fsm_cs == REQ_OUT) && (qv_out_payload_cnt >= 1)) ? qv_out_payload_cnt - 1 : dma_cm_wr_req_ready ? qv_out_payload_cnt : 0;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_out_payload_cnt <= `TD 0;
    end
    else if ((dma_cm_wr_req_ready && (qv_out_payload_cnt < wv_out_payload_num) && (ctx_data_rd_en || (qv_recv_payload_cnt > qv_out_payload_cnt)) && qv_tmp_header[96]) || (dma_cm_wr_req_ready && (qv_out_payload_cnt < wv_out_payload_num) && no_input_payload && (fsm_cs == REQ_OUT))) begin
        qv_out_payload_cnt <= `TD qv_out_payload_cnt + 1;
    end
    else if (fsm_cs == REQ_OUT) begin
        qv_out_payload_cnt <= `TD qv_out_payload_cnt;
    end
    else begin
        qv_out_payload_cnt <= `TD 0;
    end
end

//reg [3:0]   wv_out_payload_num;//total payload num of dma write req out,judge from the req_type and req_opcode
always @(*) begin
    if (rst) begin
        wv_out_payload_num = 0;
    end else begin
        case ({wv_req_type,wv_req_opcode})
            {`WR_QP_CTX,`WR_QP_ALL}: begin
                wv_out_payload_num = 12'd6;
            end
            {`WR_CQ_CTX,`WR_CQ_ALL}:begin
                wv_out_payload_num = 12'd2;
            end
            {`WR_CQ_CTX,`WR_CQ_MODIFY}:begin
                wv_out_payload_num = 12'd2;
            end
            {`WR_EQ_CTX,`WR_EQ_ALL}:begin
                wv_out_payload_num = 12'd2;
            end
            {`WR_CQ_CTX,`WR_CQ_INVALID}:begin
                wv_out_payload_num = 12'd2;
            end
            {`WR_EQ_CTX,`WR_EQ_INVALID}:begin
                wv_out_payload_num = 12'd2;
            end
            {`WR_EQ_CTX,`WR_EQ_FUNC}:begin
                wv_out_payload_num = 12'd1;                
            end
            {`WR_QP_CTX,`WR_QP_STATE}:begin
                wv_out_payload_num = 12'd1; 
            end
            {`WR_QP_CTX,`WR_QP_UAPST}:begin
                wv_out_payload_num = 12'd1;
            end
            {`WR_QP_CTX,`WR_QP_NPST}:begin
                wv_out_payload_num = 12'd1;
            end
            {`WR_QP_CTX,`WR_QP_EPST}:begin
                wv_out_payload_num = 12'd1;
            end
            default: wv_out_payload_num = 0;
        endcase
    end    
end

//wire     has_input_payload;//indicate that we will read paylaod from ceu_parser ctx_data fifo
assign has_input_payload =  ((wv_req_type == `WR_QP_CTX) && (wv_req_opcode == `WR_QP_ALL)) || 
                            ((wv_req_type == `WR_CQ_CTX) && (wv_req_opcode == `WR_CQ_ALL)) || 
                            ((wv_req_type == `WR_CQ_CTX) && (wv_req_opcode == `WR_CQ_MODIFY)) || 
                            ((wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_ALL));
wire ceu_requests;    
assign ceu_requests =  ((wv_req_type == `WR_QP_CTX) && (wv_req_opcode == `WR_QP_ALL)) || 
                            ((wv_req_type == `WR_CQ_CTX) && (wv_req_opcode == `WR_CQ_ALL)) || 
                            ((wv_req_type == `WR_CQ_CTX) && (wv_req_opcode == `WR_CQ_MODIFY)) || 
                            ((wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_ALL)) || 
                            ((wv_req_type == `WR_CQ_CTX) && (wv_req_opcode == `WR_CQ_INVALID)) || 
                            ((wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_INVALID)) || 
                            ((wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_FUNC));
//wire     no_input_payload;//indicate that there is no paylaod from ceu_parser ctx_data fifo
assign no_input_payload =   ((wv_req_type == `WR_CQ_CTX) && (wv_req_opcode == `WR_CQ_INVALID)) || 
                            ((wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_INVALID)) || 
                            ((wv_req_type == `WR_EQ_CTX) && (wv_req_opcode == `WR_EQ_FUNC)) || 
                            ((wv_req_type == `WR_QP_CTX) && (wv_req_opcode == `WR_QP_STATE)) || 
                            ((wv_req_type == `WR_QP_CTX) && (wv_req_opcode == `WR_QP_UAPST)) || 
                            ((wv_req_type == `WR_QP_CTX) && (wv_req_opcode == `WR_QP_NPST)) || 
                            ((wv_req_type == `WR_QP_CTX) && (wv_req_opcode == `WR_QP_EPST));
wire rdma_requests;
assign rdma_requests =   ((wv_req_type == `WR_QP_CTX) && (wv_req_opcode == `WR_QP_STATE)) || 
                            ((wv_req_type == `WR_QP_CTX) && (wv_req_opcode == `WR_QP_UAPST)) || 
                            ((wv_req_type == `WR_QP_CTX) && (wv_req_opcode == `WR_QP_NPST)) || 
                            ((wv_req_type == `WR_QP_CTX) && (wv_req_opcode == `WR_QP_EPST));

//reg  [3:0]   qv_recv_payload_cnt;//counter for paylaod data from ceu_parser ctx_data fifo
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_recv_payload_cnt <= `TD 0;
    end
    else if (ctx_data_rd_en) begin
        qv_recv_payload_cnt <= `TD qv_recv_payload_cnt + 1;
    end
    else if (fsm_cs == REQ_OUT) begin
        qv_recv_payload_cnt <= `TD qv_recv_payload_cnt;       
    end
    else begin
        qv_recv_payload_cnt <= `TD 0;
    end
end
//reg [3:0]   wv_recv_payload_num;//total payload num from ceu_parser ctx_data fifo,judge from the req_type and req_opcode
always @(*) begin
    if (rst) begin
        wv_recv_payload_num = 0;
    end 
    else begin
        case ({wv_req_type,wv_req_opcode})
            {`WR_QP_CTX,`WR_QP_ALL}: begin
                wv_recv_payload_num = 12'd6;
            end
            {`WR_CQ_CTX,`WR_CQ_ALL}:begin
                wv_recv_payload_num = 12'd2;
            end
            {`WR_CQ_CTX,`WR_CQ_MODIFY}:begin
                wv_recv_payload_num = 12'd2;
            end
            {`WR_EQ_CTX,`WR_EQ_ALL}:begin
                wv_recv_payload_num = 12'd2;
            end
            default: wv_recv_payload_num = 0;
        endcase
    end    
end

//DMA Write Ctx Request Out interface
//   output  wire                           dma_cm_wr_req_valid,
reg                            q_dma_cm_wr_req_valid;
assign dma_cm_wr_req_valid = q_dma_cm_wr_req_valid && dma_cm_wr_req_ready;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_dma_cm_wr_req_valid <= `TD 0;
    end
    else if ((dma_cm_wr_req_ready && (wv_out_payload_cnt < wv_out_payload_num) && (ctx_data_rd_en || (qv_recv_payload_cnt > wv_out_payload_cnt)) && qv_tmp_header[96]) || (dma_cm_wr_req_ready && (wv_out_payload_cnt < wv_out_payload_num) && no_input_payload && (fsm_cs == REQ_OUT) && (rdma_requests || (ceu_requests && qv_tmp_header[96])))) begin
        q_dma_cm_wr_req_valid <= `TD 1;
    end
    else begin
        q_dma_cm_wr_req_valid <= `TD 0;
    end
end


reg                           q_dma_cm_wr_req_last;
//assign dma_cm_wr_req_last = (q_dma_cm_wr_req_valid && dma_cm_wr_req_ready && (wv_out_payload_cnt == wv_out_payload_num)) ? 1 : 0;
assign dma_cm_wr_req_last = q_dma_cm_wr_req_last && dma_cm_wr_req_ready;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_dma_cm_wr_req_last <= `TD 0;
    end
    else if (((wv_out_payload_cnt + 1== wv_out_payload_num) && has_input_payload && (qv_recv_payload_cnt <= wv_recv_payload_num)  && qv_tmp_header[96]) || ((wv_out_payload_cnt + 1== wv_out_payload_num) && no_input_payload && (fsm_cs == REQ_OUT) && (rdma_requests || (ceu_requests && qv_tmp_header[96])))) begin
        q_dma_cm_wr_req_last <= `TD 1;
    end
    else begin
        q_dma_cm_wr_req_last <= `TD 0;
    end
end

// always @(posedge clk or posedge rst) begin
//     if (rst) begin
//         q_dma_cm_wr_req_last <= `TD 0;
//     end
//     else if ((dma_cm_wr_req_ready && (wv_out_payload_cnt + 1== wv_out_payload_num) && has_input_payload && (qv_recv_payload_cnt + 1 == wv_recv_payload_num) && ctx_data_rd_en && qv_tmp_header[96]) || (dma_cm_wr_req_ready && (wv_out_payload_cnt + 1== wv_out_payload_num) && no_input_payload && (fsm_cs == REQ_OUT) && (rdma_requests || (ceu_requests && qv_tmp_header[96])))) begin
//         q_dma_cm_wr_req_last <= `TD 1;
//     end
//     else begin
//         q_dma_cm_wr_req_last <= `TD 0;
//     end
// end

reg  [(`DT_WIDTH-1):0]         qv_dma_cm_wr_req_data;
assign dma_cm_wr_req_data = q_dma_cm_wr_req_valid ? qv_dma_cm_wr_req_data : 'b0;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_dma_cm_wr_req_data <= `TD 0;
    end
    else begin
        case ({wv_req_type,wv_req_opcode})
            {`WR_QP_CTX,`WR_QP_ALL}: begin
                if ((wv_out_payload_cnt < wv_out_payload_num) && ctx_data_rd_en && (qv_recv_payload_cnt == wv_out_payload_cnt) && qv_tmp_header[96] && dma_cm_wr_req_ready) begin
                    qv_dma_cm_wr_req_data <= `TD ctx_data_dout;
                end 
                else if ((wv_out_payload_cnt < wv_out_payload_num) &&  (qv_recv_payload_cnt > wv_out_payload_cnt) && qv_tmp_header[96] && dma_cm_wr_req_ready) begin
                    qv_dma_cm_wr_req_data <= `TD qv_tmp_data;
                end else begin
                    qv_dma_cm_wr_req_data <= `TD 0;
                end
            end
            {`WR_CQ_CTX,`WR_CQ_ALL}:begin
                if ((wv_out_payload_cnt < wv_out_payload_num) && ctx_data_rd_en && (qv_recv_payload_cnt == wv_out_payload_cnt) && qv_tmp_header[96] && dma_cm_wr_req_ready) begin
                    qv_dma_cm_wr_req_data <= `TD ctx_data_dout;
                end 
                else if ((wv_out_payload_cnt < wv_out_payload_num) &&  (qv_recv_payload_cnt > wv_out_payload_cnt) && qv_tmp_header[96] && dma_cm_wr_req_ready) begin
                    qv_dma_cm_wr_req_data <= `TD qv_tmp_data;
                end else begin
                    qv_dma_cm_wr_req_data <= `TD 0;
                end
            end
            {`WR_CQ_CTX,`WR_CQ_MODIFY}:begin
               if ((wv_out_payload_cnt < wv_out_payload_num) && ctx_data_rd_en && (qv_recv_payload_cnt == wv_out_payload_cnt) && qv_tmp_header[96] && dma_cm_wr_req_ready) begin
                    qv_dma_cm_wr_req_data <= `TD ctx_data_dout;
                end 
                else if ((wv_out_payload_cnt < wv_out_payload_num) &&  (qv_recv_payload_cnt > wv_out_payload_cnt) && qv_tmp_header[96] && dma_cm_wr_req_ready) begin
                    qv_dma_cm_wr_req_data <= `TD qv_tmp_data;
                end else begin
                    qv_dma_cm_wr_req_data <= `TD 0;
                end
            end
            {`WR_EQ_CTX,`WR_EQ_ALL}:begin
                if ((wv_out_payload_cnt < wv_out_payload_num) && ctx_data_rd_en && (qv_recv_payload_cnt == wv_out_payload_cnt) && qv_tmp_header[96] && dma_cm_wr_req_ready) begin
                    qv_dma_cm_wr_req_data <= `TD ctx_data_dout;
                end 
                else if ((wv_out_payload_cnt < wv_out_payload_num) &&  (qv_recv_payload_cnt > wv_out_payload_cnt) && qv_tmp_header[96] && dma_cm_wr_req_ready) begin
                    qv_dma_cm_wr_req_data <= `TD qv_tmp_data;
                end else begin
                    qv_dma_cm_wr_req_data <= `TD 0;
                end
            end
            {`WR_CQ_CTX,`WR_CQ_INVALID}:begin
                qv_dma_cm_wr_req_data <= `TD 0;
            end
            {`WR_EQ_CTX,`WR_EQ_INVALID}:begin
                qv_dma_cm_wr_req_data <= `TD 0;
            end
            {`WR_EQ_CTX,`WR_EQ_FUNC}:begin
                if (dma_cm_wr_req_ready && (wv_out_payload_cnt < wv_out_payload_num) && (fsm_cs == REQ_OUT) && qv_tmp_header[96]) begin
                //put the EQC mask data at the low position
                    qv_dma_cm_wr_req_data <= `TD {224'b0,qv_tmp_header[95:64]};
                end else begin
                    qv_dma_cm_wr_req_data <= `TD 0;
                end
            end
            {`WR_QP_CTX,`WR_QP_STATE}:begin
                if (dma_cm_wr_req_ready && (wv_out_payload_cnt < wv_out_payload_num) && (fsm_cs == REQ_OUT)) begin
                //put the qp_state data at the low position
                    qv_dma_cm_wr_req_data <= `TD {249'b0,qv_tmp_header[66:64],4'b0};
                end else begin
                    qv_dma_cm_wr_req_data <= `TD 0;
                end
            end
            {`WR_QP_CTX,`WR_QP_UAPST}:begin
                if (dma_cm_wr_req_ready && (wv_out_payload_cnt < wv_out_payload_num) && (fsm_cs == REQ_OUT)) begin
                //put the unacked psn data at the low position
                    qv_dma_cm_wr_req_data <= `TD {224'b0,8'b0,qv_tmp_header[87:64]};
                end else begin
                    qv_dma_cm_wr_req_data <= `TD 0;
                end
            end
            {`WR_QP_CTX,`WR_QP_NPST}:begin
                if (dma_cm_wr_req_ready && (wv_out_payload_cnt < wv_out_payload_num) && (fsm_cs == REQ_OUT)) begin
                //put the next psn data at the low position
                    qv_dma_cm_wr_req_data <= `TD {224'b0,8'b0,qv_tmp_header[87:64]};
                end else begin
                    qv_dma_cm_wr_req_data <= `TD 0;
                end
            end
            {`WR_QP_CTX,`WR_QP_EPST}:begin
                if (dma_cm_wr_req_ready && (wv_out_payload_cnt < wv_out_payload_num) && (fsm_cs == REQ_OUT)) begin
                //put the expected psn data at the low position
                    qv_dma_cm_wr_req_data <= `TD {224'b0,8'b0,qv_tmp_header[87:64]};
                end else begin
                    qv_dma_cm_wr_req_data <= `TD 0;
                end
            end
            default: qv_dma_cm_wr_req_data <= `TD 0;
        endcase
    end
end

assign dma_cm_wr_req_head = {qv_tmp_header[119:117],29'b0,qv_tmp_header[63:0],20'b0,wv_dma_req_length};

// reg  [(`HD_WIDTH-1):0]         qv_dma_cm_wr_req_head;
// assign dma_cm_wr_req_head = q_dma_cm_wr_req_valid ? qv_dma_cm_wr_req_head : 'b0;
// always @(posedge clk or posedge rst) begin
//     if (rst) begin
//         qv_dma_cm_wr_req_head <= `TD 0;
//     end
//     else if ((dma_cm_wr_req_ready && (wv_out_payload_cnt == 0) && (ctx_data_rd_en || (qv_recv_payload_cnt > wv_out_payload_cnt)) && qv_tmp_header[96]) || (dma_cm_wr_req_ready && (wv_out_payload_cnt == 0) && no_input_payload && (fsm_cs == REQ_OUT) && (rdma_requests || (ceu_requests && qv_tmp_header[96])))) begin
//         /*VCS Verification*/
//         // dma_cm_wr_req_head <= `TD {32'b0,qv_tmp_header[63:0],20'b0,wv_dma_req_length};
//         qv_dma_cm_wr_req_head <= `TD {qv_tmp_header[119:117],29'b0,qv_tmp_header[63:0],20'b0,wv_dma_req_length};
//         /*Action = Modify, Add 3 bit to inidicate request source*/    
//     end
//     else begin
//         /*VCS Verification*/
//         // dma_cm_wr_req_head <= `TD 0;
//         qv_dma_cm_wr_req_head <= `TD {qv_tmp_header[119:117],125'b0};
//         /*Action = Modify, Add 3 bit to inidicate request source*/    
//     end
// end

`ifdef CTX_DUG
    // /*****************Add for APB-slave regs**********************************/ 
        // reg                            dma_cm_wr_req_valid,      //1 
        // reg                            dma_cm_wr_req_last,       //1 
        // reg  [(`DT_WIDTH-1):0]         dma_cm_wr_req_data,       //256 
        // reg  [`DT_WIDTH-1 :0]     qv_tmp_data;                   //256 
        // reg  [`HD_WIDTH-1 :0]     qv_tmp_header;                 //128 
        // reg  [11:0]  wv_dma_req_length;                          //12 
        // reg  [3:0]   qv_out_payload_cnt;                         //4 
        // reg  [3:0]   wv_out_payload_num;                         //4 
        // reg  [3:0]   qv_recv_payload_cnt;                        //4 
        // reg  [3:0]   wv_recv_payload_num;                        //4 
        // reg [1:0] fsm_cs;                                        //2 
        // reg [1:0] fsm_ns;                                        //2 

    //total regs count = 1bit_signal(2) + fsm(2*2) + reg (128+256*2+12+4*4) = 674

    // /*****************Add for APB-slave wires**********************************/ 
    // wire                     mdt_req_wr_ctx_rd_en,               //1 
    // wire  [`HD_WIDTH-1:0]    mdt_req_wr_ctx_dout,                //128 
    // wire                     mdt_req_wr_ctx_empty,               //1 
    // wire                  ctx_data_rd_en,                        //1 
    // wire                  ctx_data_empty,                        //1 
    // wire [`INTER_DT-1:0]  ctx_data_dout,                         //256 
    // wire  [(`HD_WIDTH-1):0]        dma_cm_wr_req_head,          //128 
    // wire                           dma_cm_wr_req_ready,          //1 
    // wire [3:0]   wv_req_type;                                    //4 
    // wire [3:0]   wv_req_opcode;                                  //4 
    // wire         has_input_payload;                              //1 
    // wire         no_input_payload;                               //1 
    // wire ceu_requests;                                           //1 
    // wire rdma_requests;                                          //1 

    //total wires count = 1bit_signal(9) + 256 + 128*2 + 4*2 = 529

    //Total regs and wires : 674 + 529 = 1203 = 32 * 37 + 19. bit align 38

    assign wv_dbg_bus_4 = {
        19'b0,
        dma_cm_wr_req_valid,
        dma_cm_wr_req_last,
        dma_cm_wr_req_data,
        q_dma_cm_wr_req_last,
        q_dma_cm_wr_req_valid,
        qv_dma_cm_wr_req_data,
        // qv_dma_cm_wr_req_head,
        qv_tmp_data,
        qv_tmp_header,
        wv_dma_req_length,
        qv_out_payload_cnt,
        wv_out_payload_num,
        qv_recv_payload_cnt,
        wv_recv_payload_num,
        fsm_cs,
        fsm_ns,

        wv_out_payload_cnt,
        mdt_req_wr_ctx_rd_en,
        mdt_req_wr_ctx_dout,
        mdt_req_wr_ctx_empty,
        ctx_data_rd_en,
        ctx_data_empty,
        ctx_data_dout,
        dma_cm_wr_req_head,
        dma_cm_wr_req_ready,
        wv_req_type,
        wv_req_opcode,
        has_input_payload,
        no_input_payload,
        ceu_requests,
        rdma_requests
    };
`endif

endmodule