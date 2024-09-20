//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: ceu_tptm_proc.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V0.0 
// VERSION DESCRIPTION: 1st Edition  
//----------------------------------------------------
// RELEASE DATE: 2020-09-16 
//---------------------------------------------------- 
// PURPOSE: sort the tptmetadata request and payload from ceu_parser.
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
// 
//-FHDR-----------------------------------------------

//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_v2p_h.vh"

module ceu_tptm_proc #(
    parameter  CEU_HD_WIDTH  = 104//for ceu_tptm_proc to MPTMdata/MTTMdata req header fifo
    )(
    input clk,
    input rst,
    input  wire                    ceu_start,
    output wire                    ceu_finish,
    // internal TPTMeteData write request header from CEU 
    //128 width header format
    output wire                    ceu_req_rd_en,
    input  wire  [`HD_WIDTH-1:0]   ceu_req_dout,
    input  wire                    ceu_req_empty,
    // internel TPT metaddata from CEU 
    // 256 width (only TPT metadata)
    output wire                    mdata_rd_en,
    input  wire  [`DT_WIDTH-1:0]   mdata_dout,
    input  wire                    mdata_empty,
    
    //extract mptmdata request to mptmdata submodule
    input  wire                        mptm_req_rd_en,
    output wire  [CEU_HD_WIDTH-1:0]    mptm_req_dout, 
    output wire                        mptm_req_empty,
    
    //extract mptmdata payload to mptmdata submodule
    input  wire                        mptm_rd_en,
    output wire  [`DT_WIDTH-1:0]       mptm_dout, 
    output wire                        mptm_empty,
    
    //extract mttmdata request to mttmdata submodule
    input  wire                        mttm_req_rd_en,
    output wire  [CEU_HD_WIDTH-1:0]    mttm_req_dout, 
    output wire                        mttm_req_empty,
    
    //extract mttmdata payload to mttmdata submodule
    input  wire                        mttm_rd_en,
    output wire  [`DT_WIDTH-1:0]       mttm_dout, 
    output wire                        mttm_empty
    
    `ifdef V2P_DUG
    //apb_slave
    ,  input wire [`CEUTPTM_DBG_RW_NUM * 32 - 1 : 0]   rw_data
    ,  output wire [`CEUTPTM_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_ceutptm
    `endif
);
/*Spyglass*/
    wire fifo_clear;
    assign fifo_clear = 1'b0;
/*Action = Modify*/
//extract mptmdata request to mptmdata submodule
reg                         mptm_req_wr_en;
reg   [CEU_HD_WIDTH-1:0]    mptm_req_din; 
wire                        mptm_req_prog_full;

//extract mptmdata payload to mptmdata submodule
reg                         mptm_wr_en;
reg   [`DT_WIDTH-1:0]       mptm_din; 
wire                        mptm_prog_full;

//extract mttmdata request to mttmdata submodule
reg                         mttm_req_wr_en;
reg   [CEU_HD_WIDTH-1:0]    mttm_req_din; 
wire                        mttm_req_prog_full;

//extract mttmdata payload to mttmdata submodule
reg                         mttm_wr_en;
reg   [`DT_WIDTH-1:0]       mttm_din;  
wire                        mttm_prog_full;

//extract mptmdata request to mptmdata submodule FIFO
mptm_req_fifo_104w32d mptm_req_fifo_104w32d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (mptm_req_wr_en),
        .rd_en      (mptm_req_rd_en),
        .din        (mptm_req_din),
        .dout       (mptm_req_dout),
        .full       (),
        .empty      (mptm_req_empty),     
        .prog_full  (mptm_req_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[1 * 32 - 1 : 0])        
    `endif
);

//extract mptmdata payload to mptmdata submodule FIFO
mptm_fifo_256w32d mptm_fifo_256w32d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (mptm_wr_en),
        .rd_en      (mptm_rd_en),
        .din        (mptm_din),
        .dout       (mptm_dout),
        .full       (),
        .empty      (mptm_empty),     
        .prog_full  (mptm_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[1 * 32 +: 1 * 32])        
    `endif
);

//extract mttmdata request to mttmdata submodule FIFO
mptm_req_fifo_104w32d mttm_req_fifo_104w32d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (mttm_req_wr_en),
        .rd_en      (mttm_req_rd_en),
        .din        (mttm_req_din),
        .dout       (mttm_req_dout),
        .full       (),
        .empty      (mttm_req_empty),     
        .prog_full  (mttm_req_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[2 * 32 +: 1 * 32])        
    `endif
);

//extract mttmdata payload to mttmdata submodule FIFO
mptm_fifo_256w32d mttm_fifo_256w32d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (mttm_wr_en),
        .rd_en      (mttm_rd_en),
        .din        (mttm_din),
        .dout       (mttm_dout),
        .full       (),
        .empty      (mttm_empty),     
        .prog_full  (mttm_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[3 * 32 +: 1 * 32])        
    `endif
);


// finish
reg q_ceu_finish;
assign ceu_finish = q_ceu_finish;

//registers
reg [2:0] fsm_cs;
reg [2:0] fsm_ns;

//state machine localparams
//IDLE
localparam IDLE     = 3'b001;
//HEADER: parse ceu request, send reconstructured requests(which has no payload) to dest fifo
localparam HEADER   = 3'b010;
//PAYLOAD: send reconstructured requests and their payloads to dest fifo, according to stored header info 
localparam PAYLOAD  = 3'b100;

wire has_payload_1; //init hca cmd has 1 payload
wire has_payload_n; //map vit-phy addr variables payload
reg [`HD_WIDTH-1 :0] tmp_req_header;
reg [`DT_WIDTH-1 :0] tmp_payload;
wire [31:0] payload_num;
reg [31:0] payload_cnt;
wire dest_fifo_full;
reg [63:0] mpt_base;
reg [63:0] mtt_base;
reg q_ceu_req_rd_en;
reg q_mdata_rd_en;

//-----------------Stage 1 :State Register----------
always @(posedge clk or posedge rst) begin
    if(rst)
        fsm_cs <= `TD IDLE;
    else
        fsm_cs <= `TD fsm_ns;
end

//-----------------Stage 2 :State Transition----------
always @(*) begin
    case (fsm_cs)
        IDLE: begin
            if(ceu_start) begin
                fsm_ns = HEADER;
            end
            else
                fsm_ns = IDLE;
        end 
        HEADER: begin
            if (has_payload_n && !mdata_empty && !dest_fifo_full) begin
                fsm_ns = PAYLOAD;
            end 
            /*VCS Verification*/
            // else if (ceu_req_empty && !dest_fifo_full)
            // begin
            //     fsm_ns = IDLE;
            // end
            // else 
            //     fsm_ns = HEADER;           
            else if (dest_fifo_full)
            begin
                fsm_ns = HEADER;
            end
            else 
                fsm_ns = IDLE;
            /*Action = Modify, jump into IDLE after Header process except Payload processing*/
        end
        PAYLOAD: begin
            if ((payload_cnt + 1 == payload_num) && !dest_fifo_full && !ceu_req_empty) begin
                fsm_ns = HEADER;
            end
            else if ((payload_cnt + 1 == payload_num) && !dest_fifo_full && ceu_req_empty) begin
                fsm_ns = IDLE;
            end else begin
                fsm_ns =PAYLOAD;
            end
        end
        default: fsm_ns = IDLE;
    endcase
end

//-----------------Stage 3 :Output Decode----------

// reg q_ceu_finish
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_ceu_finish <= `TD 1'b0;
    end
    // ceu_finish valid only if the ceu_tptm_proc module is IDLE
    else if (fsm_ns == IDLE) begin
        q_ceu_finish <= `TD 1'b1;
    end else begin
        q_ceu_finish <= `TD 1'b0;
    end
end

// wire has_payload_1;
assign has_payload_1 = ((fsm_cs == HEADER) && (
                       (ceu_req_dout[`HD_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH] == `WR_ICMMAP_TPT) &&
                        (ceu_req_dout[`HD_WIDTH-`TYPE_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH-`OPCODE_WIDTH] == `WR_ICMMAP_EN_V2P)
                       )) ? 1'b1 : 1'b0;
// wire has_payload_n;                    
assign has_payload_n = ((fsm_cs == HEADER) && 
                         ((ceu_req_dout[`HD_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH] == `MAP_ICM_TPT) && 
                         (ceu_req_dout[`HD_WIDTH-`TYPE_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH-`OPCODE_WIDTH] == `MAP_ICM_EN_V2P)) 
                        ) ? 1'b1 : 1'b0;

// reg [`HD_WIDTH-1 :0] tmp_req_header;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        tmp_req_header <= `TD 0;
    end
    else begin
        case (fsm_cs)
            IDLE: tmp_req_header <= `TD 0;
            HEADER: begin
                if (!dest_fifo_full) begin
                    tmp_req_header <= `TD ceu_req_dout;
                end else begin
                    tmp_req_header <= `TD tmp_req_header;
                end
            end
            PAYLOAD: begin
                if ((payload_cnt + 1 == payload_num) && !dest_fifo_full) begin
                    tmp_req_header <= `TD 0;
                end
                else
                    tmp_req_header <= `TD tmp_req_header;
            end
            default: tmp_req_header <= `TD 0;
        endcase
    end
end

// reg [`DT_WIDTH-1 :0] tmp_payload;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        tmp_payload <= `TD 0;
    end
    else if (has_payload_n || has_payload_1) begin
        tmp_payload <= `TD mdata_dout;
    end
    else if (fsm_cs == HEADER) begin
        tmp_payload <= `TD tmp_payload;
    end
    else if ((fsm_cs == PAYLOAD) && !dest_fifo_full && (payload_cnt < payload_num)) begin
        tmp_payload <= `TD mdata_dout;
    end
    else begin
        tmp_payload <= `TD 0;
    end
end
        

// wire [31:0] payload_num;
//payload_num = (chunk_num % 2) ? chunk_num/2+1 : chunk_num/2 
assign payload_num = ((fsm_cs == PAYLOAD) && 
                      (tmp_req_header[`HD_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH] == `MAP_ICM_TPT) && 
                      (tmp_req_header[`HD_WIDTH-`TYPE_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH-`OPCODE_WIDTH] == `MAP_ICM_EN_V2P)) ? ((tmp_req_header[64]) ? (tmp_req_header[95:64]/2+1) : (tmp_req_header[95:64]/2)) : 0;

// reg [31:0] payload_cnt;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        payload_cnt <= `TD 0;
    end
    else if ((fsm_cs == PAYLOAD) && !dest_fifo_full && (payload_cnt < payload_num)) begin
        payload_cnt <= `TD payload_cnt + 1;
    end else if ((fsm_cs == PAYLOAD) && dest_fifo_full && (payload_cnt < payload_num)) begin
        payload_cnt <= `TD payload_cnt;
    end
    else
        payload_cnt <= `TD 0;
end

// reg [63:0] mpt_base;
// reg [63:0] mtt_base;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mpt_base <= `TD 0;
        mtt_base <= `TD 0;
    end 
    else if (has_payload_1 && !mdata_empty) begin
        mpt_base <= `TD {mdata_dout[127:72],8'b0};
        mtt_base <= `TD mdata_dout[63:0];
    end 
    else begin
        mpt_base <= `TD mpt_base;
        mtt_base <= `TD mtt_base;
    end
end


// wire dest_fifo_full;
// HEADER state's INIT HCA and HEADER state' ClOSE HCA indicates dest fifos are both mptm and mttm fifo
// for HEADER & PAYLOAD states' MAP_ICM_EN_V2P cmds, we need to compare the paylaod's virt addr with mpt/mtt_base to decide dest fifo;
// for HEADER state' MAP_ICM_DIS_V2P cmds, we need to compare the request's virt addr with mpt/mtt_base to decide dest fifo;
// PAYLOAD state' INIT HCA 
//((fsm_cs == PAYLOAD) && 
//                            (tmp_req_header[`HD_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH] == `WR_ICMMAP_TPT) &&
//                            (tmp_req_header[`HD_WIDTH-`TYPE_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH-`OPCODE_WIDTH] == `WR_ICMMAP_EN_V2P))
assign dest_fifo_full = (  has_payload_1 || 
                            ((fsm_cs == HEADER) && 
                             (ceu_req_dout[`HD_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH] == `WR_ICMMAP_TPT) &&
                             (ceu_req_dout[`HD_WIDTH-`TYPE_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH-`OPCODE_WIDTH] == `WR_ICMMAP_DIS_V2P))) ? (mptm_prog_full || mttm_prog_full) : 
                          (  (  (has_payload_n && 
                                  (((mtt_base > mpt_base) && (mdata_dout[127:64] >= mtt_base)) || 
                                   ((mtt_base < mpt_base) && (mdata_dout[127:64] < mpt_base) && (mdata_dout[127:64] >= mtt_base)))) || 
                                ( (fsm_cs == HEADER) && 
                                  (ceu_req_dout[`HD_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH] == `MAP_ICM_TPT) && 
                                  (ceu_req_dout[`HD_WIDTH-`TYPE_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH-`OPCODE_WIDTH] == `MAP_ICM_DIS_V2P) && 
                                  ( ((mtt_base > mpt_base) && (ceu_req_dout[63:0] >= mtt_base)) || 
                                    ((mtt_base < mpt_base) && (ceu_req_dout[63:0] < mpt_base) && (ceu_req_dout[63:0] >= mtt_base)))) ||
                                ( (fsm_cs == PAYLOAD) && 
                                    (tmp_req_header[`HD_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH] == `MAP_ICM_TPT) && 
                                    (tmp_req_header[`HD_WIDTH-`TYPE_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH-`OPCODE_WIDTH] == `MAP_ICM_EN_V2P) &&
                                    (((mtt_base > mpt_base) && (tmp_payload[127:64] >= mtt_base)) || 
                                     ((mtt_base < mpt_base) && (tmp_payload[127:64] < mpt_base) && (tmp_payload[127:64] >= mtt_base))))) ? mttm_prog_full :
                            ( ( (has_payload_n && 
                                  (((mtt_base < mpt_base) && (mdata_dout[127:64] >= mpt_base)) || 
                                   ((mtt_base > mpt_base) && (mdata_dout[127:64] >= mpt_base) && (mdata_dout[127:64] < mtt_base)))) || 
                                ( (fsm_cs == HEADER) && 
                                  (ceu_req_dout[`HD_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH] == `MAP_ICM_TPT) && 
                                  (ceu_req_dout[`HD_WIDTH-`TYPE_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH-`OPCODE_WIDTH] == `MAP_ICM_DIS_V2P) && 
                                  ( ((mtt_base < mpt_base) && (ceu_req_dout[63:0] >= mpt_base)) || 
                                    ((mtt_base > mpt_base) && (ceu_req_dout[63:0] >= mpt_base) && (ceu_req_dout[63:0] < mtt_base)))) ||
                                ( (fsm_cs == PAYLOAD) && 
                                    (tmp_req_header[`HD_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH] == `MAP_ICM_TPT) && 
                                    (tmp_req_header[`HD_WIDTH-`TYPE_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH-`OPCODE_WIDTH] == `MAP_ICM_EN_V2P) &&
                                    (((mtt_base < mpt_base) && (tmp_payload[127:64] >= mpt_base)) || 
                                     ((mtt_base > mpt_base) && (tmp_payload[127:64] >= mpt_base) && (tmp_payload[127:64] < mtt_base))))) ? mptm_prog_full : 0));  

// reg q_ceu_req_rd_en;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_ceu_req_rd_en <= `TD 0;
    end 
    else begin
        case (fsm_cs)
            IDLE: begin
                if (!ceu_req_empty) begin
                    q_ceu_req_rd_en <= `TD 1;
                end else begin
                    q_ceu_req_rd_en <= `TD 0;
                end
            end
            HEADER: begin
                // next cycle is HEADER state to read new header to process
                if (!ceu_req_empty && !dest_fifo_full && !has_payload_n) begin
                    q_ceu_req_rd_en <= `TD 1;
                end else begin
                    q_ceu_req_rd_en <= `TD 0;
                end
            end
            PAYLOAD: begin
                // next cycle is HEADER state to read new header to process
                if ((payload_cnt + 1 == payload_num) && !dest_fifo_full && !ceu_req_empty) begin
                    q_ceu_req_rd_en <= `TD 1;
                end else begin
                    q_ceu_req_rd_en <= `TD 0;
                end
            end
            default: q_ceu_req_rd_en <= `TD 0;
        endcase
    end
end

// wire ceu_req_rd_en
assign ceu_req_rd_en = (!ceu_req_empty) & q_ceu_req_rd_en;

// reg q_mdata_rd_en;
always @(*) begin
    case (fsm_cs)
        IDLE: begin
            q_mdata_rd_en = 0;
        end 
        HEADER: begin
            if (has_payload_1 || has_payload_n) begin
                q_mdata_rd_en = 1;
            end else begin
                q_mdata_rd_en = 0;
            end
        end
        PAYLOAD: begin
            //if (!dest_fifo_full && (payload_cnt < payload_num)) begin
            if (!dest_fifo_full && (payload_cnt +1 < payload_num)) begin
                q_mdata_rd_en = 1;
            end else begin
                q_mdata_rd_en = 0;
            end
        end
        default: q_mdata_rd_en = 0;
    endcase
end

// wire mdata_rd_en
assign mdata_rd_en = (!mdata_empty) & q_mdata_rd_en;

 
// reg                         mptm_req_wr_en;
wire    is_mptm_req;
assign  is_mptm_req = has_payload_1 || 
                    ( (fsm_cs == HEADER) && 
                       (ceu_req_dout[`HD_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH] == `WR_ICMMAP_TPT) &&
                       (ceu_req_dout[`HD_WIDTH-`TYPE_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH-`OPCODE_WIDTH] == `WR_ICMMAP_DIS_V2P)) || 
                    ( has_payload_n && 
                     (((mtt_base < mpt_base) && (mdata_dout[127:64] >= mpt_base)) || 
                      ((mtt_base > mpt_base) && (mdata_dout[127:64] >= mpt_base) && (mdata_dout[127:64] < mtt_base)))) || 
                    ( (fsm_cs == HEADER) && 
                      (ceu_req_dout[`HD_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH] == `MAP_ICM_TPT) && 
                      (ceu_req_dout[`HD_WIDTH-`TYPE_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH-`OPCODE_WIDTH] == `MAP_ICM_DIS_V2P) && 
                      ( ((mtt_base < mpt_base) && (ceu_req_dout[63:0] >= mpt_base)) || 
                        ((mtt_base > mpt_base) && (ceu_req_dout[63:0] >= mpt_base) && (ceu_req_dout[63:0] < mtt_base))));
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mptm_req_wr_en <= `TD 0;
    end else begin
        case (fsm_cs)
            IDLE: begin
                mptm_req_wr_en <= `TD 0;
            end
            HEADER: begin
                if (is_mptm_req && !mptm_req_prog_full) begin
                    mptm_req_wr_en <= `TD 1;
                end else begin
                    mptm_req_wr_en <= `TD 0;
                end
            end
            PAYLOAD: begin
                mptm_req_wr_en <= `TD 0;
            end 
            default: mptm_req_wr_en <= `TD 0;
        endcase
    end
end

// reg   [CEU_HD_WIDTH-1:0]    mptm_req_din;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mptm_req_din <= `TD 0;
    end else begin
        case (fsm_cs)
            IDLE: begin
                mptm_req_din <= `TD 0;
            end
            HEADER: begin
                case ({ceu_req_dout[`HD_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH] ,ceu_req_dout[`HD_WIDTH-`TYPE_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH-`OPCODE_WIDTH]} & {8{!mptm_req_prog_full}})
                    8'b0: begin
                        mptm_req_din <= `TD 0;
                    end 
                    {`WR_ICMMAP_TPT,`WR_ICMMAP_EN_V2P}:begin
                        mptm_req_din <= `TD {ceu_req_dout[127:120],32'b0,mdata_dout[127:64]};
                    end
                    {`WR_ICMMAP_TPT,`WR_ICMMAP_DIS_V2P}: begin
                        mptm_req_din <= `TD {ceu_req_dout[127:120],ceu_req_dout[95:0]};
                    end
                    {`MAP_ICM_TPT,`MAP_ICM_EN_V2P}: begin
                        if (((mtt_base < mpt_base) && (mdata_dout[127:64] >= mpt_base)) ||
                            ((mtt_base > mpt_base) && (mdata_dout[127:64] >= mpt_base) && (mdata_dout[127:64] < mtt_base))) begin
                            mptm_req_din <= `TD {ceu_req_dout[127:120],ceu_req_dout[95:0]};
                        end else begin
                            mptm_req_din <= `TD 0;
                        end
                    end
                    {`MAP_ICM_TPT,`MAP_ICM_DIS_V2P}: begin
                        if (((mtt_base < mpt_base) && (ceu_req_dout[63:0] >= mpt_base)) || 
                            ((mtt_base > mpt_base) && (ceu_req_dout[63:0] >= mpt_base) && (ceu_req_dout[63:0] < mtt_base))) begin
                            mptm_req_din <= `TD {ceu_req_dout[127:120],ceu_req_dout[95:0]};
                        end else begin
                            mptm_req_din <= `TD 0;
                        end
                    end
                    default: mptm_req_din <= `TD 0;
                endcase
            end
            PAYLOAD: begin
                mptm_req_din <= `TD 0;
            end 
            default: mptm_req_din <= `TD 0;
        endcase
    end
end

// reg                         mptm_wr_en;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mptm_wr_en <= `TD 0;
    end else begin
        case (fsm_cs)
            IDLE: begin
                mptm_wr_en <= `TD 0;
            end
            HEADER: begin
                mptm_wr_en <= `TD 0;
            end
            PAYLOAD: begin
                if ((tmp_req_header[`HD_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH] == `MAP_ICM_TPT) && 
                    (tmp_req_header[`HD_WIDTH-`TYPE_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH-`OPCODE_WIDTH] == `MAP_ICM_EN_V2P) &&
                    (((mtt_base < mpt_base) && (tmp_payload[127:64] >= mpt_base)) || 
                     ((mtt_base > mpt_base) && (tmp_payload[127:64] >= mpt_base) && (tmp_payload[127:64] < mtt_base))) &&
                    (payload_cnt < payload_num) && !mptm_prog_full) begin
                    mptm_wr_en <= `TD 1;
                end else begin
                   mptm_wr_en <= `TD 0; 
                end
            end 
            default: mptm_wr_en <= `TD 0;
        endcase
    end
end

// reg   [`DT_WIDTH-1:0]       mptm_din; 
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mptm_din <= `TD 0;
    end 
    else begin
        case (fsm_cs)
            IDLE: begin
                mptm_din <= `TD 0;
            end 
            HEADER: begin
                mptm_din <= `TD 0;
            end
            PAYLOAD: begin
                if ((tmp_req_header[`HD_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH] == `MAP_ICM_TPT) && 
                    (tmp_req_header[`HD_WIDTH-`TYPE_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH-`OPCODE_WIDTH] == `MAP_ICM_EN_V2P) &&
                    (((mtt_base < mpt_base) && (tmp_payload[127:64] >= mpt_base)) || 
                     ((mtt_base > mpt_base) && (tmp_payload[127:64] >= mpt_base) && (tmp_payload[127:64] < mtt_base))) &&
                    (payload_cnt < payload_num) && !mptm_prog_full) begin
                    mptm_din <= `TD tmp_payload;
                end else begin
                    mptm_din <= `TD 0;
                end
            end
            default: mptm_din <= `TD 0;
        endcase
    end
end

// reg                         mttm_req_wr_en;
wire    is_mttm_req;
assign  is_mttm_req = has_payload_1 || 
                    ( (fsm_cs == HEADER) && 
                       (ceu_req_dout[`HD_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH] == `WR_ICMMAP_TPT) &&
                       (ceu_req_dout[`HD_WIDTH-`TYPE_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH-`OPCODE_WIDTH] == `WR_ICMMAP_DIS_V2P)) || 
                    ( has_payload_n && 
                     (((mtt_base > mpt_base) && (mdata_dout[127:64] >= mtt_base)) || 
                      ((mtt_base < mpt_base) && (mdata_dout[127:64] < mpt_base) && (mdata_dout[127:64] >= mtt_base)))) || 
                    ( (fsm_cs == HEADER) && 
                      (ceu_req_dout[`HD_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH] == `MAP_ICM_TPT) && 
                      (ceu_req_dout[`HD_WIDTH-`TYPE_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH-`OPCODE_WIDTH] == `MAP_ICM_DIS_V2P) && 
                      ( ((mtt_base > mpt_base) && (ceu_req_dout[63:0] >= mtt_base)) || 
                        ((mtt_base < mpt_base) && (ceu_req_dout[63:0] < mpt_base) && (ceu_req_dout[63:0] >= mtt_base))));

always @(posedge clk or posedge rst) begin
    if (rst) begin
        mttm_req_wr_en <= `TD 0;
    end else begin
        case (fsm_cs)
            IDLE: begin
                mttm_req_wr_en <= `TD 0;
            end
            HEADER: begin
                if (is_mttm_req && !mttm_req_prog_full) begin
                    mttm_req_wr_en <= `TD 1;
                end else begin
                    mttm_req_wr_en <= `TD 0;
                end
            end
            PAYLOAD: begin
                mttm_req_wr_en <= `TD 0;
            end 
            default: mttm_req_wr_en <= `TD 0;
        endcase
    end
end

// reg   [CEU_HD_WIDTH-1:0]    mttm_req_din;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mttm_req_din <= `TD 0;
    end else begin
        case (fsm_cs)
            IDLE: begin
                mttm_req_din <= `TD 0;
            end
            HEADER: begin
                case ({ceu_req_dout[`HD_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH] ,ceu_req_dout[`HD_WIDTH-`TYPE_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH-`OPCODE_WIDTH]} & {8{!mttm_req_prog_full}})
                    8'b0: begin
                        mttm_req_din <= `TD 0;
                    end 
                    {`WR_ICMMAP_TPT,`WR_ICMMAP_EN_V2P}:begin
                        mttm_req_din <= `TD {ceu_req_dout[127:120],32'b0,mdata_dout[63:0]};
                    end
                    {`WR_ICMMAP_TPT,`WR_ICMMAP_DIS_V2P}: begin
                        mttm_req_din <= `TD {ceu_req_dout[127:120],ceu_req_dout[95:0]};
                    end
                    {`MAP_ICM_TPT,`MAP_ICM_EN_V2P}: begin
                        if (((mtt_base > mpt_base) && (mdata_dout[127:64] >= mtt_base)) || 
                            ((mtt_base < mpt_base) && (mdata_dout[127:64] < mpt_base) && (mdata_dout[127:64] >= mtt_base))) begin
                            mttm_req_din <= `TD {ceu_req_dout[127:120],ceu_req_dout[95:0]};
                        end else begin
                            mttm_req_din <= `TD 0;
                        end
                    end
                    {`MAP_ICM_TPT,`MAP_ICM_DIS_V2P}: begin
                        if (((mtt_base > mpt_base) && (ceu_req_dout[63:0] >= mtt_base)) || 
                            ((mtt_base < mpt_base) && (ceu_req_dout[63:0] < mpt_base) && (ceu_req_dout[63:0] >= mtt_base))) begin
                            mttm_req_din <= `TD {ceu_req_dout[127:120],ceu_req_dout[95:0]};
                        end else begin
                            mttm_req_din <= `TD 0;
                        end
                    end
                    default: mttm_req_din <= `TD 0;
                endcase
            end
            PAYLOAD: begin
                mttm_req_din <= `TD 0;
            end 
            default: mttm_req_din <= `TD 0;
        endcase
    end
end

// reg                         mttm_wr_en;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mttm_wr_en <= `TD 0;
    end else begin
        case (fsm_cs)
            IDLE: begin
                mttm_wr_en <= `TD 0;
            end
            HEADER: begin
                mttm_wr_en <= `TD 0;
            end
            PAYLOAD: begin
                if ((tmp_req_header[`HD_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH] == `MAP_ICM_TPT) && 
                    (tmp_req_header[`HD_WIDTH-`TYPE_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH-`OPCODE_WIDTH] == `MAP_ICM_EN_V2P) &&
                    (((mtt_base > mpt_base) && (tmp_payload[127:64] >= mtt_base)) || 
                     ((mtt_base < mpt_base) && (tmp_payload[127:64] < mpt_base) && (tmp_payload[127:64] >= mtt_base))) &&
                    (payload_cnt < payload_num) && !mttm_prog_full) begin
                    mttm_wr_en <= `TD 1;
                end else begin
                    mttm_wr_en <= `TD 0; 
                end
            end 
            default: mttm_wr_en <= `TD 0;
        endcase
    end
end

// reg   [`DT_WIDTH-1:0]       mttm_din;  
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mttm_din <= `TD 0;
    end 
    else begin
        case (fsm_cs)
            IDLE: begin
                mttm_din <= `TD 0;
            end 
            HEADER: begin
                mttm_din <= `TD 0;
            end
            PAYLOAD: begin
                if ((tmp_req_header[`HD_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH] == `MAP_ICM_TPT) && 
                    (tmp_req_header[`HD_WIDTH-`TYPE_WIDTH-1: `HD_WIDTH-`TYPE_WIDTH-`OPCODE_WIDTH] == `MAP_ICM_EN_V2P) &&
                    (((mtt_base > mpt_base) && (tmp_payload[127:64] >= mtt_base)) || 
                     ((mtt_base < mpt_base) && (tmp_payload[127:64] < mpt_base) && (tmp_payload[127:64] >= mtt_base))) &&
                    (payload_cnt < payload_num) && !mttm_prog_full) begin
                    mttm_din <= `TD tmp_payload;
                end else begin
                    mttm_din <= `TD 0;
                end
            end
            default: mttm_din <= `TD 0;
        endcase
    end
end


`ifdef V2P_DUG
    // /*****************Add for APB-slave regs**********************************/ 

        // reg                         mptm_req_wr_en;
        // reg   [CEU_HD_WIDTH-1:0]    mptm_req_din; 
        // reg                         mptm_wr_en;
        // reg   [`DT_WIDTH-1:0]       mptm_din; 
        // reg                         mttm_req_wr_en;
        // reg   [CEU_HD_WIDTH-1:0]    mttm_req_din; 
        // reg                         mttm_wr_en;
        // reg   [`DT_WIDTH-1:0]       mttm_din;  
        // reg q_ceu_finish;
        // reg [2:0] fsm_cs;
        // reg [2:0] fsm_ns;
        // reg [`HD_WIDTH-1 :0] tmp_req_header;
        // reg [`DT_WIDTH-1 :0] tmp_payload;
        // reg [31:0] payload_cnt;
        // reg [63:0] mpt_base;
        // reg [63:0] mtt_base;
        // reg q_ceu_req_rd_en;
        // reg q_mdata_rd_en;

    // /*****************Add for APB-slave wires**********************************/ 
        // wire                    ceu_start,
        // wire                    ceu_finish,
        // wire                    ceu_req_rd_en,
        // wire  [`HD_WIDTH-1:0]   ceu_req_dout,
        // wire                    ceu_req_empty,
        // wire                    mdata_rd_en,
        // wire  [`DT_WIDTH-1:0]   mdata_dout,
        // wire                    mdata_empty,
        // wire                        mptm_req_rd_en,
        // wire  [CEU_HD_WIDTH-1:0]    mptm_req_dout, 
        // wire                        mptm_req_empty,
        // wire                        mptm_rd_en,
        // wire  [`DT_WIDTH-1:0]       mptm_dout, 
        // wire                        mptm_empty,
        // wire                        mttm_req_rd_en,
        // wire  [CEU_HD_WIDTH-1:0]    mttm_req_dout, 
        // wire                        mttm_req_empty,
        // wire                        mttm_rd_en,
        // wire  [`DT_WIDTH-1:0]       mttm_dout, 
        // wire                        mttm_empty
        // wire fifo_clear;
        // wire                        mptm_req_prog_full;
        // wire                        mptm_prog_full;
        // wire                        mttm_req_prog_full;
        // wire                        mttm_prog_full;
        // wire has_payload_1;
        // wire has_payload_n;
        // wire [31:0] payload_num;
        // wire dest_fifo_full;
        // wire    is_mptm_req;
        // wire    is_mttm_req;    
    //Total regs and wires : 2437 = 76*32+5

    assign wv_dbg_bus_ceutptm = {
        27'b0,
        // 27'hffffff,
        mptm_req_wr_en,
        mptm_req_din,
        mptm_wr_en,
        mptm_din,
        mttm_req_wr_en,
        mttm_req_din,
        mttm_wr_en,
        mttm_din,
        q_ceu_finish,
        fsm_cs,
        fsm_ns,
        tmp_req_header,
        tmp_payload,
        payload_cnt,
        mpt_base,
        mtt_base,
        q_ceu_req_rd_en,
        q_mdata_rd_en,

        ceu_start,
        ceu_finish,
        ceu_req_rd_en,
        ceu_req_dout,
        ceu_req_empty,
        mdata_rd_en,
        mdata_dout,
        mdata_empty,
        mptm_req_rd_en,
        mptm_req_dout,
        mptm_req_empty,
        mptm_rd_en,
        mptm_dout,
        mptm_empty,
        mttm_req_rd_en,
        mttm_req_dout,
        mttm_req_empty,
        mttm_rd_en,
        mttm_dout,
        mttm_empty,
        fifo_clear,
        mptm_req_prog_full,
        mptm_prog_full,
        mttm_req_prog_full,
        mttm_prog_full,
        has_payload_1,
        has_payload_n,
        payload_num,
        dest_fifo_full,
        is_mptm_req,
        is_mttm_req
    };

`endif 
endmodule