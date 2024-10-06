//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: mtt_ram_ctl.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V0.0 
// VERSION DESCRIPTION: 1st Edition  
//----------------------------------------------------
// RELEASE DATE: 2020-12-25
//---------------------------------------------------- 
// PURPOSE: store and operate on mtt table data
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
// 
//-FHDR-----------------------------------------------

//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_v2p_h.vh"

module mtt_ram_ctl#(
    parameter MTT_SIZE       = 524288, //Total Size(MPT+MTT) 1MB, mtt_RAM occupies 512KB
    parameter CACHE_WAY_NUM  = 2,//2 way
    parameter LINE_SIZE      = 32,//Cache line size = 32B(mtt entry= 8B)
    parameter INDEX           =   12,//mtt_ram index width
    parameter TAG             =   3,//mtt_ram tag width
    parameter OFFSET          =   2,//mtt_ram offset width
    parameter NUM             =   3,//mtt_ram num width to indicate how many mtt entries in 1 cache line
    parameter DMA_DT_REQ_WIDTH  = 134//mtt_ram_ctl to dma_read/write_data req header fifo
    )(
    input clk,
    input rst,  
    //------------------interface to ceu channel----------------------
        // internal ceu request header
        // 128 width header format
        output  reg                    mtt_req_rd_en,
        input  wire  [`HD_WIDTH-1:0]   mtt_req_dout,
        input  wire                    mtt_req_empty,
    
        // internal ceu payload data
        // 256 width 
        output  reg                    mtt_data_rd_en,
        input  wire  [`DT_WIDTH-1:0]   mtt_data_dout,
        input  wire                    mtt_data_empty,

    //------------------interface to Metadata module-------------
        //read mtt_base for compute index in mtt_ram
        input  wire  [63:0]             mtt_base_addr,  
    
    /**************mofidy for dma read write requests block ***************/
    //------------------interface to mtt_req_scheduler---------
        input wire [3:0] new_selected_channel,
        //mtt_ram_ctl block signal for 3 req fifo processing block 
        //| bit 2 read WQE | bit 1 write data | bit 0 read data |
        output reg [2:0]   block_valid,
        output reg [197:0] rd_wqe_block_info,
        output reg [197:0] wr_data_block_info,
        output reg [197:0] rd_data_block_info,
        //mtt_ram_ctl unblock signal for reading 3 blocked req  
        //| bit 2 read WQE | bit 1 write data | bit 0 read data |
        output reg    [2:0]   unblock_valid,
        input  wire   [197:0] rd_wqe_block_reg,
        input  wire   [197:0] wr_data_block_reg,
        input  wire   [197:0] rd_data_block_reg,
        
        output wire   dma_rd_dt_req_prog_full,
        output wire   dma_rd_wqe_req_prog_full,
        output wire   dma_wr_dt_req_prog_full,

    // //----------------interface to mpt_ram module-------------------------
    //     //read request(include Src,Op,mtt_index,v-addr,length) from mpt_ram module        
    //     //| ---------------------165 bit------------------------- |
    //     //|   Src    |     Op  | mtt_index | address |Byte length |
    //     //|  164:162 | 161:160 |  159:96   |  95:32  |   31:0     |
    //     output wire                     mpt_req_mtt_rd_en,
    //     input  wire  [164:0]            mpt_req_mtt_dout,
    //     input  wire                     mpt_req_mtt_empty,

    //----------------interface to mpt_rd_req_parser module-------------------------
        //mtt_ram look up request at cacheline level for dma read data requests
        //|--------------198 bit------------------------- |
        //|    Src  |  total length |    Op  | mtt_index | address | tmp length |
        //| 197:195 |    194:163    |162:160 |  159:96   |  95:32  |   31:0     |
        output  wire             mpt_rd_req_mtt_cl_rd_en,
        input   wire             mpt_rd_req_mtt_cl_empty,
        input   wire  [197:0]    mpt_rd_req_mtt_cl_dout,

    //----------------interface to mpt_rd_wqe_req_parser module-------------------------
        //mtt_ram look up request at cacheline level for dma read data requests
        //|--------------198 bit------------------------- |
        //|    Src  |  total length |    Op  | mtt_index | address | tmp length |
        //| 197:195 |    194:163    |162:160 |  159:96   |  95:32  |   31:0     |
        output  wire             mpt_rd_wqe_req_mtt_cl_rd_en,
        input   wire             mpt_rd_wqe_req_mtt_cl_empty,
        input   wire  [197:0]    mpt_rd_wqe_req_mtt_cl_dout,

    //----------------interface to mpt_wr_req_parser module-------------------------
        //mtt_ram look up request at cacheline level for dma read data requests
        //|--------------198 bit------------------------- |
        //|    Src  |  total length |    Op  | mtt_index | address | tmp length |
        //| 197:195 |    194:163    |162:160 |  159:96   |  95:32  |   31:0     |
        output  wire             mpt_wr_req_mtt_cl_rd_en,
        input   wire             mpt_wr_req_mtt_cl_empty,
        input   wire  [197:0]    mpt_wr_req_mtt_cl_dout,
    /**************mofidy for dma read write requests block ***************/

    //---------------------------mtt_ram--------------------------
        //lookup info 
        input  wire                     lookup_allow_in,
        output reg                      lookup_rden,
        output reg                      lookup_wren,
        output reg  [LINE_SIZE*8-1:0]   lookup_wdata, //lookup info addr={(64-INDEX-TAG-OFFSET)'b0,lookup_tag,lookup_index,lookup_offset}
        output reg  [INDEX -1     :0]   lookup_index,
        output reg  [TAG -1       :0]   lookup_tag,
        output reg  [OFFSET - 1   :0]   lookup_offset,
        output reg  [NUM - 1      :0]   lookup_num,
        // add EQ function
        output reg                      mtt_eq_addr,
        //response state
        input  wire [2:0]               lookup_state,// | 2<->miss | 1<->hit | 0<->idle |
        input  wire                     lookup_ldst, // 1 for store, and 0 for load
        input  wire                     state_valid, // valid in normal state, invalid if stall
        output wire                     lookup_stall,

        //hit read mtt entry 
        input  wire [LINE_SIZE*8-1:0]   hit_rdata,
        //miss read mtt entry, it's the dma reaponse data
        input  wire [LINE_SIZE*8-1:0]   miss_rdata,

    //------------------interface to dma_read_data module-------------
        //-mtt_ram_ctl--dma_read/write_data req header format
        //high-----------------------------low
        //|-------------------134 bit--------------------|
        //| total len |opcode | dest/src |tmp len | addr |
        //| 32        |   3   |     3    | 32     |  64  |
        //|----------------------------------------------|
        input   wire                            dma_rd_dt_req_rd_en,
        output  wire                            dma_rd_dt_req_empty,
        output  wire  [DMA_DT_REQ_WIDTH-1:0]    dma_rd_dt_req_dout,

        input   wire                            dma_rd_wqe_req_rd_en,
        output  wire                            dma_rd_wqe_req_empty,
        output  wire  [DMA_DT_REQ_WIDTH-1:0]    dma_rd_wqe_req_dout,

        input   wire                            dma_wr_dt_req_rd_en,
        output  wire                            dma_wr_dt_req_empty,
        output  wire  [DMA_DT_REQ_WIDTH-1:0]    dma_wr_dt_req_dout

    `ifdef V2P_DUG
    //apb_slave
        ,  input wire [`MTTCTL_DBG_RW_NUM * 32 - 1 : 0]   rw_data
        ,  output wire [`MTTCTL_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mttctl
    `endif        
);

//--------------{fifo declaration}begin---------------//

    //write dma read network data request(include Total legnth,Op,Src,length,phy-addr) to dma_read_data module        
    // wire                               dma_rd_dt_req_prog_full;
    reg                                dma_rd_dt_req_wr_en;
    reg   [DMA_DT_REQ_WIDTH-1:0]       dma_rd_dt_req_din;
    dma_rd_dt_req_fifo_134w64d dma_rd_dt_req_fifo_134w64d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (dma_rd_dt_req_wr_en),
        .rd_en      (dma_rd_dt_req_rd_en),
        .din        (dma_rd_dt_req_din),
        .dout       (dma_rd_dt_req_dout),
        .full       (),
        .empty      (dma_rd_dt_req_empty),     
        .prog_full  (dma_rd_dt_req_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[0 * 32 +: 1 * 32])        
    `endif
    ); 

    //write dma read WQE data request(include Total legnth,Op,Src,length,phy-addr) to dma_read_data module        
    // wire                               dma_rd_wqe_req_prog_full;
    reg                                dma_rd_wqe_req_wr_en;
    reg   [DMA_DT_REQ_WIDTH-1:0]       dma_rd_wqe_req_din;
    dma_rd_dt_req_fifo_134w64d dma_rd_wqe_req_fifo_134w64d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (dma_rd_wqe_req_wr_en),
        .rd_en      (dma_rd_wqe_req_rd_en),
        .din        (dma_rd_wqe_req_din),
        .dout       (dma_rd_wqe_req_dout),
        .full       (),
        .empty      (dma_rd_wqe_req_empty),     
        .prog_full  (dma_rd_wqe_req_prog_full)
     `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[1 * 32 +: 1 * 32])        
    `endif
   ); 

    //write dma write network data request(include Total legnth,Op,Src,length,phy-addr) to dma_write_data module        
    // wire                               dma_wr_dt_req_prog_full;
    reg                                dma_wr_dt_req_wr_en;
    reg   [DMA_DT_REQ_WIDTH-1:0]       dma_wr_dt_req_din;
    dma_rd_dt_req_fifo_134w64d dma_wr_dt_req_fifo_134w64d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (dma_wr_dt_req_wr_en),
        .rd_en      (dma_wr_dt_req_rd_en),
        .din        (dma_wr_dt_req_din),
        .dout       (dma_wr_dt_req_dout),
        .full       (),
        .empty      (dma_wr_dt_req_empty),     
        .prog_full  (dma_wr_dt_req_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[2 * 32 +: 1 * 32])        
    `endif
    ); 

//--------------{variable declaration}  end---------------//

//-----------------{ceu req processing state mechine} begin--------------------//
    //--------------{variable declaration}---------------
    localparam  CEU_REQ_IDLE   = 2'b01;
    // read: ceu request header, ceu payload data
    // write: mtt_ram lookup signals
    localparam  CEU_REQ_PROC   = 2'b10; 
    
    reg [1:0] ceu_req_fsm_cs;
    reg [1:0] ceu_req_fsm_ns;

    //store the processing req info and data
    reg  [`HD_WIDTH-1 : 0] qv_get_ceu_req_hd;    //reg for ceu request header
    reg  [`DT_WIDTH-1 : 0] qv_get_ceu_payload;     //reg for ceu payload data
    //total mtt_ram look up req num derived from 1 ceu req
    wire [31:0]  ceu_req_mtt_num;
    //reg for counting times of ceu look up mtt_ram 
    reg  [31:0]  qv_ceu_req_mtt_cnt;
    //reg for ceu req mtt_ram addr
    reg  [63:0]  qv_ceu_req_mtt_addr;    
    //left data offset in payload: 256bit/64 bit = 4, total 2 bit offset
    reg  [1:0]  qv_left_payload_offset;
    //left mtt entry num for ceu req
    reg  [31:0] qv_left_ceu_req_mtt_num;
    // indicate that ceu req is been processing, used to stall mpt req processing
    wire is_ceu_req_processing;


    //-----------------Stage 1 :State Register----------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ceu_req_fsm_cs <= `TD CEU_REQ_IDLE;
        end
        else begin
            ceu_req_fsm_cs <= `TD ceu_req_fsm_ns;
        end
    end
    //-----------------Stage 2 :State Transition----------
    always @(*) begin
        case (ceu_req_fsm_cs)
            CEU_REQ_IDLE: begin
                if(!mtt_req_empty && !mtt_data_empty && lookup_allow_in) begin
                    ceu_req_fsm_ns = CEU_REQ_PROC;
                end
                else begin
                    ceu_req_fsm_ns = CEU_REQ_IDLE;
                end
            end 
            CEU_REQ_PROC: begin
                /*VCS Verification*/
                // if ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4) && (mtt_req_empty | mtt_data_empty)) begin
                if ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4) && (mtt_req_empty | mtt_data_empty) && lookup_allow_in && (state_valid | (!state_valid & (lookup_state == 3'b1))) && !(lookup_rden | lookup_wren)) begin
                /*Action = Modify, add lookup_allow_in, state_valid, rden and wren signals judge*/
                    ceu_req_fsm_ns = CEU_REQ_IDLE;
                end
                else begin
                    ceu_req_fsm_ns = CEU_REQ_PROC;
                end
            end
            default: ceu_req_fsm_ns = CEU_REQ_IDLE;
        endcase
    end
    //-----------------Stage 3 :Output Decode------------------
    //------------------interface to ceu channel----------------------
    //read ceu request header fifo read_en
    always @(*) begin
        if (rst) begin
            mtt_req_rd_en = 0;
        end
        else begin
            case (ceu_req_fsm_cs)
                CEU_REQ_IDLE:begin
                    //next state is CEU_REQ_PROC, rd_en
                    if (!mtt_req_empty && !mtt_data_empty && lookup_allow_in) begin
                        mtt_req_rd_en = 1;
                    end else begin
                        mtt_req_rd_en = 0;
                    end
                end
                CEU_REQ_PROC:begin
                    //next state is CEU_REQ_PROC, rd_en
                    /*VCS Verification*/
                    // if ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4) && !mtt_req_empty && !mtt_data_empty && lookup_allow_in) begin
                    if ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4) && !mtt_req_empty && !mtt_data_empty && lookup_allow_in && (state_valid | (!state_valid & (lookup_state == 3'b1))) && !(lookup_rden | lookup_wren)) begin
                        /*Action = Modify, add state_valid, rden and wren signals judge*/
                        mtt_req_rd_en = 1;
                    end else begin
                        mtt_req_rd_en = 0;
                    end
                end
                default: mtt_req_rd_en = 0;
            endcase
        end
    end
    //reg  [`HD_WIDTH-1 : 0] qv_get_ceu_req_hd;    //reg for ceu request header
    //| --------------------64bit---------------------- |
    //|      type     |     opcode     |   R  | mtt_num |
    //| (WR_MTT_TPT)  | (WR_MTT_WRITE) | void | (32bit) |
    //|-------------------------------------------------|
    //|                 mtt_start_index                 |
    //|                     (64bit)                     |
    //|-------------------------------------------------|
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_get_ceu_req_hd <= `TD 0;
        end 
        else begin
            case (ceu_req_fsm_cs)
                CEU_REQ_IDLE:begin
                    //get the new ceu req header
                    if (!mtt_req_empty && !mtt_data_empty && lookup_allow_in) begin
                        qv_get_ceu_req_hd <= `TD mtt_req_dout;
                    end else begin
                        qv_get_ceu_req_hd <= `TD 0;
                    end
                end
                CEU_REQ_PROC:begin
                    //get the new ceu req header
                    /*VCS Verification*/
                    // if ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4) && !mtt_req_empty && !mtt_data_empty && lookup_allow_in) begin
                    if ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4) && !mtt_req_empty && !mtt_data_empty && lookup_allow_in && (state_valid | (!state_valid & (lookup_state == 3'b1))) && !(lookup_rden | lookup_wren)) begin
                        /*Action = Modify, add state_valid, rden and wren signals judge*/
                        qv_get_ceu_req_hd <= `TD mtt_req_dout;
                    //keep the request header in the same req's CEU_REQ_PROC state
                    end else if ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] > 4) | ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num > 4)))begin
                        qv_get_ceu_req_hd <= `TD qv_get_ceu_req_hd;
                    end 
                    else begin
                        qv_get_ceu_req_hd <= `TD 0;
                    end
                end
                default: qv_get_ceu_req_hd <= `TD 0;
            endcase
        end
    end
    //read ceu payload data fifo read_en
    //        output  reg                    mtt_data_rd_en,
        always @(*) begin
        if (rst) begin
            mtt_data_rd_en = 0;
        end else begin
            case (ceu_req_fsm_cs)
                CEU_REQ_IDLE:begin
                    //next state is CEU_REQ_PROC, rd_en
                    if (!mtt_req_empty && !mtt_data_empty && lookup_allow_in) begin
                        mtt_data_rd_en = 1;
                    end else begin
                        mtt_data_rd_en = 0;
                    end
                end
                CEU_REQ_PROC:begin
                    //next state is new CEU_REQ_PROC, rd_en
                    /*VCS Verification*/
                    // if ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4) && !mtt_req_empty && !mtt_data_empty && lookup_allow_in) begin
                    if ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4) && !mtt_req_empty && !mtt_data_empty && lookup_allow_in && (state_valid | (!state_valid & (lookup_state == 3'b1))) && !(lookup_rden | lookup_wren)) begin
                        mtt_data_rd_en = 1;
                    end
                    //keep read payload data, if there are left mtt_reqs derived from 1 ceu req and tmp payload can not refill a mtt_req
                    //qv_left_payload_offset > qv_ceu_req_mtt_addr[1:0] mains that qv_left_payload_offset+(4-qv_ceu_req_mtt_addr[1:0])>=4, 
                    else if ((((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] > 4) && (qv_left_payload_offset >= qv_ceu_req_mtt_addr[1:0])) | ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num > 4))) && !mtt_data_empty && lookup_allow_in && (state_valid | (!state_valid & (lookup_state == 3'b1))) && !(lookup_rden | lookup_wren)) begin
                        /*Action = Modify, add state_valid, rden and wren signals judge*/
                        mtt_data_rd_en = 1;
                    end
                    else begin
                        mtt_data_rd_en = 0;
                    end
                end
                default: mtt_data_rd_en = 0;
            endcase
        end    
    end

    //store the processing req info and data
    //    reg  [`DT_WIDTH-1 : 0] qv_get_ceu_payload;     //reg for ceu payload data
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_get_ceu_payload <= `TD 0;
        end else begin
            case (ceu_req_fsm_cs)
                CEU_REQ_IDLE:begin
                    //next state is CEU_REQ_PROC, get data
                    if (!mtt_req_empty && !mtt_data_empty && lookup_allow_in) begin
                        qv_get_ceu_payload <= `TD mtt_data_dout;
                    end else begin
                        qv_get_ceu_payload <= `TD 0;
                    end
                end
                CEU_REQ_PROC:begin
                    //next state is new CEU_REQ_PROC, get data
                    /*VCS Verification*/
                    if ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4) && !mtt_req_empty && !mtt_data_empty && lookup_allow_in && (state_valid | (!state_valid & (lookup_state == 3'b1))) && !(lookup_rden | lookup_wren)) begin
                        /*Action = Modify, add state_valid, rden and wren signals judge*/
                        qv_get_ceu_payload <= `TD mtt_data_dout;
                    end
                    //keep read payload data, if there are left mtt_reqs derived from 1 ceu req and tmp payload can not refill a mtt_req
                    //qv_left_payload_offset > qv_ceu_req_mtt_addr[1:0] mains that qv_left_payload_offset+(4-qv_ceu_req_mtt_addr[1:0])>=4, 
                    else if ((((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] > 4) && (qv_left_payload_offset >= qv_ceu_req_mtt_addr[1:0])) | ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num > 4))) && !mtt_data_empty && lookup_allow_in && (state_valid | (!state_valid & (lookup_state == 3'b1))) && !(lookup_rden | lookup_wren)) begin
                        /*Action = Modify, add state_valid, rden and wren signals judge*/
                        qv_get_ceu_payload <= `TD mtt_data_dout;
                    end
                    else begin
                        qv_get_ceu_payload <= `TD qv_get_ceu_payload;
                    end
                end 
                default: qv_get_ceu_payload <= `TD 0;
            endcase
        end
    end

    //wire [31:0]  ceu_req_mtt_num;  total mtt_ram req num derived from 1 ceu req
    wire [31:0] req_num_add_offset;
    assign req_num_add_offset = qv_get_ceu_req_hd[95:64] + qv_get_ceu_req_hd[1:0];
    // req_num = (num+offset)/4 + ((num+offset)%4 ? 1 : 0)
    assign ceu_req_mtt_num = (qv_get_ceu_req_hd[`HD_WIDTH-1:`HD_WIDTH-8]=={`WR_MTT_TPT,`WR_MTT_WRITE}) ?
                             req_num_add_offset[31:2] + ((req_num_add_offset[1:0]>0) ? 1 : 0) : 0;

    //reg  [31:0]  qv_ceu_req_mtt_cnt; reg for ceu req mtt_ram cnt
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_ceu_req_mtt_cnt <= `TD 0;
        end else begin
            case (ceu_req_fsm_cs)
                CEU_REQ_IDLE:begin
                    qv_ceu_req_mtt_cnt <= `TD 0;
                end
                CEU_REQ_PROC:begin
                    //if lookup_allow_in and payload data (register and fifo_dout) is ready, cnt+1
                    /*VCS Verification*/
                    if ((((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] > 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num > 4) && !mtt_data_empty) | ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] > 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4)) | ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num > 4) && !mtt_data_empty) | ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4))) && lookup_allow_in && (state_valid | (!state_valid & (lookup_state == 3'b1))) && !(lookup_rden | lookup_wren)) begin
                    /*Action = Modify, add state_valid, rden and wren signals judge*/
                        qv_ceu_req_mtt_cnt <= `TD qv_ceu_req_mtt_cnt + 1;
                    end
                    else begin
                        qv_ceu_req_mtt_cnt <= `TD qv_ceu_req_mtt_cnt;
                    end
                end 
                default: qv_ceu_req_mtt_cnt <= `TD 0;
            endcase
        end
    end

    //reg  [63:0]  qv_ceu_req_mtt_addr;    reg for ceu req mtt_ram addr
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_ceu_req_mtt_addr <= `TD 0;
        end else begin
            case (ceu_req_fsm_cs)
                CEU_REQ_IDLE:begin
                    //next state is CEU_REQ_PROC, req index is the req_addr
                    if (!mtt_req_empty && !mtt_data_empty && lookup_allow_in) begin
                        qv_ceu_req_mtt_addr <= `TD mtt_req_dout[63:0];
                    end else begin
                        qv_ceu_req_mtt_addr <= `TD 0;
                    end
                end
                CEU_REQ_PROC:begin
                    /*VCS Verification*/
                    //next state is CEU_REQ_PROC, req index is the req_addr
                    if ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4) && !mtt_req_empty && !mtt_data_empty && lookup_allow_in && (state_valid | (!state_valid & (lookup_state == 3'b1))) && !(lookup_rden | lookup_wren)) begin
                        qv_ceu_req_mtt_addr <= `TD mtt_req_dout[63:0];
                    end
                    //if lookup_allow_in and payload data (register and fifo_dout) is ready, change the req_mtt_addr
                    else if (((((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] > 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num > 4) && !mtt_data_empty) | ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] > 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4)) | ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num > 4) && !mtt_data_empty) | ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4)))) && lookup_allow_in && (state_valid | (!state_valid & (lookup_state == 3'b1))) && !(lookup_rden | lookup_wren)) begin
                    /*Action = Modify, add state_valid, rden and wren signals judge*/
                        //req_mtt_addr <= req_mtt_addr + current mtt num in this cycle
                        qv_ceu_req_mtt_addr <= `TD (qv_ceu_req_mtt_addr[1:0]+qv_left_ceu_req_mtt_num >= 4) ? {qv_ceu_req_mtt_addr[63:2]+1,2'b00} : (qv_ceu_req_mtt_addr + qv_left_ceu_req_mtt_num);
                    end
                    else begin
                        qv_ceu_req_mtt_addr <= `TD qv_ceu_req_mtt_addr;
                    end
                end 
                default: qv_ceu_req_mtt_addr <= `TD 0;
            endcase
        end
    end

    //reg  [1:0]  qv_left_payload_offset; left data offset in payload: 256bit/64 bit = 4, total 2 bit offset
    wire [2:0] left_num_add_offset;
    //offset= (addr[1:0]+num >=4) ? offset+4-addr[1:0] : offset+num; 
    assign left_num_add_offset = (qv_ceu_req_mtt_addr[1:0]+qv_left_ceu_req_mtt_num >= 4) ? 
                                ({1'b1,qv_left_payload_offset} - {1'b0,qv_ceu_req_mtt_addr[1:0]}) :
                                (qv_left_payload_offset + qv_left_ceu_req_mtt_num[1:0]); 
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_left_payload_offset <= `TD 0;
        end else begin
            case (ceu_req_fsm_cs)
                CEU_REQ_IDLE:begin
                    //next state is CEU_REQ_PROC, offset = 0
                    if (!mtt_req_empty && !mtt_data_empty && lookup_allow_in) begin
                        qv_left_payload_offset <= `TD 0;
                    end else begin
                        qv_left_payload_offset <= `TD 0;
                    end
                end
                CEU_REQ_PROC:begin
                    /*VCS Verification*/
                    //next state is CEU_REQ_PROC, offset = 0
                    if ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4) && !mtt_req_empty && !mtt_data_empty && lookup_allow_in && (state_valid | (!state_valid & (lookup_state == 3'b1))) && !(lookup_rden | lookup_wren)) begin
                        qv_left_payload_offset <= `TD 0;
                    end
                    //if lookup_allow_in and payload data (register and fifo_dout) is ready, change the payload_offset
                    else if (((((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] > 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num > 4) && !mtt_data_empty) | ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] > 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4)) | ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num > 4) && !mtt_data_empty) | ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4)))) && lookup_allow_in && (state_valid | (!state_valid & (lookup_state == 3'b1))) && !(lookup_rden | lookup_wren)) begin
                    /*Action = Modify, add state_valid, rden and wren signals judge*/
                        //payload_offset <= (payload_offset + current mtt num in this cycle)/4
                        qv_left_payload_offset <= `TD left_num_add_offset[1:0];
                    end
                    else begin
                        qv_left_payload_offset <= `TD qv_left_payload_offset;
                    end 
                end
                default: qv_left_payload_offset <= `TD 0;
            endcase
        end
    end    

    //reg  [31:0] qv_left_ceu_req_mtt_num; left mtt num for req
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_left_ceu_req_mtt_num <= `TD 0;
        end else begin
            case (ceu_req_fsm_cs)
                CEU_REQ_IDLE:begin
                    //next state is CEU_REQ_PROC,left_mtt_num is the req num
                    if (!mtt_req_empty && !mtt_data_empty && lookup_allow_in) begin
                        qv_left_ceu_req_mtt_num <= `TD mtt_req_dout[95:64];
                    end else begin
                        qv_left_ceu_req_mtt_num <= `TD 0;
                    end
                end
                CEU_REQ_PROC:begin
                    /*VCS Verification*/
                    //next state is CEU_REQ_PROC,left_mtt_num is the req num
                    if ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4) && !mtt_req_empty && !mtt_data_empty && lookup_allow_in && (state_valid | (!state_valid & (lookup_state == 3'b1))) && !(lookup_rden | lookup_wren)) begin
                        qv_left_ceu_req_mtt_num <= `TD mtt_req_dout[95:64];
                    end
                    //if lookup_allow_in and payload data (register and fifo_dout) is ready, change the left_mtt_num
                    else if (((((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] > 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num > 4) && !mtt_data_empty) | ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] > 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4)) | ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num > 4) && !mtt_data_empty) | ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4)))) && lookup_allow_in && (state_valid | (!state_valid & (lookup_state == 3'b1))) && !(lookup_rden | lookup_wren)) begin
                    /*Action = Modify, add state_valid, rden and wren signals judge*/
                        //qv_left_ceu_req_mtt_num <= qv_left_ceu_req_mtt_num - current mtt num in this cycle
                        qv_left_ceu_req_mtt_num <= `TD (qv_ceu_req_mtt_addr[1:0]+qv_left_ceu_req_mtt_num >= 4) ? (qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] - 4) : 0;
                    end
                    else begin
                        qv_left_ceu_req_mtt_num <= `TD qv_left_ceu_req_mtt_num;
                    end
                end 
                default: qv_left_ceu_req_mtt_num <= `TD 0;
            endcase
        end
    end

    //wire is_ceu_req_processing;
    assign is_ceu_req_processing = (ceu_req_fsm_cs == CEU_REQ_PROC) | (ceu_req_fsm_ns == CEU_REQ_PROC);

    //---------------------------mtt_ram operation in this fsm is at the end of this module-------------------------

//-----------------{ceu req processing state mechine} end--------------------//

//-----------------{mpt req processing state mechine} begin--------------------//

    //--------------{variable declaration}---------------
    
    // read: ceu mpt request header 
    localparam  RD_MPT_REQ   = 3'b001;
    //initiate mtt_ram lookup signal    
    localparam  INIT_LOOKUP  = 3'b010; 
    //lookup results processing, initiate dma_read/write_data req
    localparam  LOOKUP_RESULT_PROC = 3'b100 ;

    reg [2:0] mpt_req_fsm_cs;
    reg [2:0] mpt_req_fsm_ns;

    //store the processing req info 
    reg  [197 : 0] qv_get_mpt_req;    //reg for mpt request 
    // //total mtt_ram look up num derived from 1 mpt req
    // wire  [31:0]  total_mpt_req_mtt_num;
    // //reg for mpt look up mtt_ram times cnt
    // reg  [31:0]  qv_mpt_req_mtt_cnt;
    //reg for mpt look up mtt_ram addr, mtt index in mtt_ram
    reg  [63:0]  qv_mpt_req_mtt_addr;    
    //left mtt entry num for 1 mpt req
    reg  [31:0] qv_left_mtt_entry_num;
    //reg for the data virtual addr of the 1st mtt in cache line
    reg  [63:0] qv_fisrt_mtt_vaddr;  
    //left mtt Byte length
    reg  [31:0] qv_left_mtt_Blen;
    // store the req mtt num in one cacheline of 1 mtt_ram lookup
    reg [2:0] qv_mtt_num_in_cacheline;
    //store the mtt_ram lookup results
    reg  [LINE_SIZE*8-1:0]   qv_rdata;
    reg  [2:0]               qv_state;
    reg                      q_ldst;
    reg                      q_result_valid;
    //left dma_read/write_data req num derived from 1 mtt_ram read req result
    reg  [2:0]  qv_left_dma_req_from_cache;
    //left dma_read/write_data req num derived from 1 mpt req
    reg  [31:0] qv_left_dma_req_from_mpt;

    //******Action=Add, used for dma wr/rd requests block
   
    //MXX modify for wr_data rd_data rd_wqe block, use mpt_req_mtt_valid instead of mpt_req_mtt_empty
    // wire mpt_req_mtt_empty;
    // assign mpt_req_mtt_empty = (new_selected_channel == 4'b1001) ? ((rd_data_block_reg == 198'b0) && mpt_rd_req_mtt_cl_empty) : 
    // (new_selected_channel == 4'b1010) ? ((wr_data_block_reg == 198'b0) && mpt_wr_req_mtt_cl_empty) : 
    // (new_selected_channel == 4'b1100) ? ((rd_wqe_block_reg == 198'b0) && mpt_rd_wqe_req_mtt_cl_empty) : 1'b1;

    wire mpt_req_mtt_valid;
    assign mpt_req_mtt_valid = ((new_selected_channel == 4'b1001) && ((rd_data_block_reg != 198'b0) || !mpt_rd_req_mtt_cl_empty) && !dma_rd_dt_req_prog_full) ||
    ((new_selected_channel == 4'b1010) && ((wr_data_block_reg != 198'b0) || !mpt_wr_req_mtt_cl_empty) && !dma_wr_dt_req_prog_full) ||
    ((new_selected_channel == 4'b1100) && ((rd_wqe_block_reg  != 198'b0) || !mpt_rd_wqe_req_mtt_cl_empty) && !dma_rd_wqe_req_prog_full);

    wire [197:0] mpt_req_mtt_dout;
    // assign mpt_req_mtt_dout = (new_selected_channel == 3'b101) ? mpt_rd_req_mtt_cl_dout : (new_selected_channel == 3'b110) ? mpt_wr_req_mtt_cl_dout : 0;
    assign mpt_req_mtt_dout = (new_selected_channel == 4'b1001) ? ( (rd_data_block_reg != 198'b0) ? rd_data_block_reg : mpt_rd_req_mtt_cl_dout) : 
    (new_selected_channel == 4'b1010) ? ( (wr_data_block_reg != 198'b0) ? wr_data_block_reg : mpt_wr_req_mtt_cl_dout) : 
    (new_selected_channel == 4'b1100) ? ( (rd_wqe_block_reg != 198'b0) ? rd_wqe_block_reg : mpt_rd_wqe_req_mtt_cl_dout) : 198'b0;
    //******Action=Add, used for dma wr/rd requests block

    //******Action=Add, used for distinguish dma rd wqe/ rd data / wr data requests
    wire is_rd_wqe;
    wire is_rd_data;
    wire is_wr_data;
    assign is_rd_wqe  = (qv_get_mpt_req[161:160] == `DOWN) && ((qv_get_mpt_req[197:195] == `SRC_DBP) || (qv_get_mpt_req[197:195] == `SRC_WPWQE) || (qv_get_mpt_req[197:195] == `SRC_EEWQE));
    assign is_rd_data = (qv_get_mpt_req[161:160] == `DOWN) && ((qv_get_mpt_req[197:195] == `SRC_WPDT) || (qv_get_mpt_req[197:195] == `SRC_EEDT));
    // assign is_wr_data = (qv_get_mpt_req[161:160] == `UP) && ((qv_get_mpt_req[197:195] == `SRC_RTC) ||(qv_get_mpt_req[197:195] == `SRC_RRC) || (qv_get_mpt_req[197:195] == `SRC_EEDT));
    //TODO: add eq funciton
    wire is_phy_wr;
    assign is_phy_wr = (qv_get_mpt_req[162:160] == `DATA_WR_PHY) && ((qv_get_mpt_req[197:195] == `SRC_RTC) ||(qv_get_mpt_req[197:195] == `SRC_RRC) || (qv_get_mpt_req[197:195] == `SRC_EEDT));
    wire is_vir_wr;
    assign is_vir_wr = (qv_get_mpt_req[161:160] == `UP) && ((qv_get_mpt_req[197:195] == `SRC_RTC) ||(qv_get_mpt_req[197:195] == `SRC_RRC) || (qv_get_mpt_req[197:195] == `SRC_EEDT));
    assign is_wr_data = is_vir_wr || is_phy_wr;
    //******Action=Add, used for distinguish dma rd wqe/ rd data / wr data requests

    //-----------------Stage 1 :State Register----------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mpt_req_fsm_cs <= `TD RD_MPT_REQ;
        end
        else begin
            mpt_req_fsm_cs <= `TD mpt_req_fsm_ns;
        end
    end
    //-----------------Stage 2 :State Transition----------
    always @(*) begin
        case (mpt_req_fsm_cs)
            RD_MPT_REQ: begin
                //MXX modify for wr_data rd_data rd_wqe block, use mpt_req_mtt_valid instead of mpt_req_mtt_empty
                // if (!is_ceu_req_processing && !mpt_req_mtt_empty && lookup_allow_in) begin
                if (!is_ceu_req_processing && mpt_req_mtt_valid && lookup_allow_in) begin
                    mpt_req_fsm_ns = INIT_LOOKUP;
                end else begin
                    mpt_req_fsm_ns = RD_MPT_REQ;
                end
            end
            INIT_LOOKUP: begin
                /*VCS Verification*/
                // if (!dma_rd_dt_req_prog_full && !dma_wr_dt_req_prog_full) begin
                // if ((((qv_get_mpt_req[161:160] == `DOWN) && !dma_rd_dt_req_prog_full) || ((qv_get_mpt_req[161:160] == `UP) && !dma_wr_dt_req_prog_full)) && lookup_allow_in && (state_valid | (!state_valid & (lookup_state == 3'b1))) && !(lookup_rden | lookup_wren)) begin
                if (((is_rd_data && !dma_rd_dt_req_prog_full) || (is_wr_data && !dma_wr_dt_req_prog_full) || (is_rd_wqe && !dma_rd_wqe_req_prog_full) ) && lookup_allow_in && (state_valid | (!state_valid & (lookup_state == 3'b1))) && !(lookup_rden | lookup_wren)) begin
                /*Action = Modify, add mtt_ram lookup enbale conditions*/
                    mpt_req_fsm_ns = LOOKUP_RESULT_PROC;
                /*Action = Add, add conditions for store block info*/
                end 
                else if ((is_rd_data && dma_rd_dt_req_prog_full) || (is_wr_data && dma_wr_dt_req_prog_full) || (is_rd_wqe && dma_rd_wqe_req_prog_full)) begin
                    mpt_req_fsm_ns = RD_MPT_REQ;
                /*Action = Add, add conditions for store block info*/               
                end else begin
                    mpt_req_fsm_ns = INIT_LOOKUP;
                end
            end
            LOOKUP_RESULT_PROC: begin
                //make sure the conditions 
                //the last dma req derived from 1 mpt req, read the new mpt req
                /*VCS  Verification*/
                // if ((qv_left_dma_req_from_mpt == qv_mtt_num_in_cacheline) && (qv_left_dma_req_from_cache == 1) && (qv_mpt_req_mtt_cnt == total_mpt_req_mtt_num) && (((qv_get_mpt_req[161:160] == `DOWN) && !dma_rd_dt_req_prog_full) || ((qv_get_mpt_req[161:160] == `UP) && !dma_wr_dt_req_prog_full)) && (state_valid | q_result_valid))  begin
                if ((qv_left_dma_req_from_mpt == qv_mtt_num_in_cacheline) && (qv_left_dma_req_from_cache == 1)  && ((is_rd_data && !dma_rd_dt_req_prog_full) || (is_wr_data && !dma_wr_dt_req_prog_full) || (is_rd_wqe && !dma_rd_wqe_req_prog_full)) && (state_valid | q_result_valid))  begin
                    mpt_req_fsm_ns = RD_MPT_REQ;
                end
                //the last dma req derived from 1 mtt_ram req result but not the last dma req derived from 1 mpt req, initiate mtt_ram lookup
                // else if ((qv_left_dma_req_from_mpt >= 1) && (qv_left_dma_req_from_cache == 1) && (qv_mpt_req_mtt_cnt < total_mpt_req_mtt_num) && (((qv_get_mpt_req[161:160] == `DOWN) && !dma_rd_dt_req_prog_full) || ((qv_get_mpt_req[161:160] == `UP) && !dma_wr_dt_req_prog_full)) && (state_valid | q_result_valid)) begin
                /*Action = Add, add  (&& (state_valid | q_result_valid)) condition*/
                //     mpt_req_fsm_ns = INIT_LOOKUP;
                // end
                else if (((is_rd_data && dma_rd_dt_req_prog_full) || (is_wr_data && dma_wr_dt_req_prog_full) || (is_rd_wqe && dma_rd_wqe_req_prog_full)) && (state_valid | q_result_valid)) begin
                    mpt_req_fsm_ns = RD_MPT_REQ;
                end
                else begin
                    mpt_req_fsm_ns = LOOKUP_RESULT_PROC;
                end
            end
            default: mpt_req_fsm_ns = RD_MPT_REQ;
        endcase
    end
    //---------------------------------Stage 3 :Output Decode--------------------------------

    ////----------------interface to mpt_ram module-------------------------
    ////read request(include Src,Op,mtt_index,v-addr,length) from mpt_ram_ctl module  
    //    //| ---------------------165 bit------------------------- |
    //    //|   Src    |     Op  | mtt_index | address |Byte length |
    //    //|  164:162 | 161:160 |  159:96   |  95:32  |   31:0     |

    //----------------interface to mpt_rd_/wr_req_mtt_parser module-------------------------
    // mpt_rd/wr_req_parser to mtt_ram_ctl look up request at cacheline level for dma read data requests
        //|--------------198 bit------------------------- |
        //|    Src  |  total length |    Op  | mtt_index | address | tmp length |
        //| 197:195 |    194:163    |162:160 |  159:96   |  95:32  |   31:0     |    
    assign mpt_rd_req_mtt_cl_rd_en = (mpt_req_fsm_cs == RD_MPT_REQ) && !mpt_rd_req_mtt_cl_empty && (new_selected_channel == 4'b1001) && (rd_data_block_reg == 198'b0) && !is_ceu_req_processing && lookup_allow_in && !dma_rd_dt_req_prog_full;

    assign mpt_wr_req_mtt_cl_rd_en = (mpt_req_fsm_cs == RD_MPT_REQ) && !mpt_wr_req_mtt_cl_empty && (new_selected_channel == 4'b1010) && (wr_data_block_reg == 198'b0) &&!is_ceu_req_processing && lookup_allow_in && !dma_wr_dt_req_prog_full;

    assign mpt_rd_wqe_req_mtt_cl_rd_en = (mpt_req_fsm_cs == RD_MPT_REQ) && !mpt_rd_wqe_req_mtt_cl_empty && (new_selected_channel == 4'b1100) && (rd_wqe_block_reg == 198'b0) &&!is_ceu_req_processing && lookup_allow_in && !dma_rd_wqe_req_prog_full;

    always @(*) begin
        if (rst) begin
            unblock_valid = 3'b000;
        end
        else if ((mpt_req_fsm_cs == RD_MPT_REQ) && !is_ceu_req_processing && lookup_allow_in) begin
            case (new_selected_channel)
            4'b1001: begin 
                // unblock_valid = (rd_data_block_reg != 198'b0) ? 3'b001 : 3'b000;
                unblock_valid = ((rd_data_block_reg != 198'b0) && !dma_rd_dt_req_prog_full) ? 3'b001 : 3'b000;
            end
            4'b1010: begin
                // unblock_valid = (wr_data_block_reg != 198'b0) ? 3'b010 : 3'b000;
                unblock_valid = ((wr_data_block_reg != 198'b0) && !dma_wr_dt_req_prog_full) ? 3'b010 : 3'b000;
            end
            4'b1100: begin
                // unblock_valid = (rd_wqe_block_reg != 198'b0) ? 3'b100 : 3'b000;
                unblock_valid = ((rd_wqe_block_reg != 198'b0) && !dma_rd_wqe_req_prog_full) ? 3'b100 : 3'b000;
            end                
            default: unblock_valid = 3'b000;
            endcase
        end 
        else begin
            unblock_valid = 3'b000;
        end       
    end

    wire mpt_req_mtt_rd_en;
    assign mpt_req_mtt_rd_en = mpt_rd_req_mtt_cl_rd_en || mpt_wr_req_mtt_cl_rd_en || mpt_rd_wqe_req_mtt_cl_rd_en || (|unblock_valid);

    //store the processing req info 
        //reg  [197 : 0] qv_get_mpt_req;    //reg for mpt request 
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_get_mpt_req <= `TD 0;
        end else begin
            case (mpt_req_fsm_cs)
                RD_MPT_REQ: begin
                    // if (mpt_rd_req_mtt_cl_rd_en) begin
                    //     qv_get_mpt_req <= `TD mpt_rd_req_mtt_cl_dout;
                    // end
                    // else if (mpt_wr_req_mtt_cl_rd_en) begin
                    //     qv_get_mpt_req <= `TD mpt_wr_req_mtt_cl_dout;
                    // end
                    // else begin
                    //     qv_get_mpt_req <= `TD 0;
                    // end
                    case ({mpt_rd_wqe_req_mtt_cl_rd_en,mpt_wr_req_mtt_cl_rd_en,mpt_rd_req_mtt_cl_rd_en,unblock_valid})
                        6'b000001: begin
                            qv_get_mpt_req <= `TD rd_data_block_reg;
                        end
                        6'b000010: begin
                            qv_get_mpt_req <= `TD wr_data_block_reg;
                        end
                        6'b000100: begin
                            qv_get_mpt_req <= `TD rd_wqe_block_reg ;
                        end
                        6'b001000: begin
                            qv_get_mpt_req <= `TD mpt_rd_req_mtt_cl_dout;
                        end            
                        6'b010000: begin
                            qv_get_mpt_req <= `TD mpt_wr_req_mtt_cl_dout;
                        end            
                        6'b100000: begin
                            qv_get_mpt_req <= `TD mpt_rd_wqe_req_mtt_cl_dout;
                        end                                    
                        default: qv_get_mpt_req <= `TD 198'b0;
                    endcase
                end
                INIT_LOOKUP: begin
                    // keep the mpt req
                    qv_get_mpt_req <= `TD qv_get_mpt_req;
                end
                LOOKUP_RESULT_PROC: begin
                    // keep the mpt req
                    qv_get_mpt_req <= `TD qv_get_mpt_req;
                end
                default: qv_get_mpt_req <= `TD 198'b0;
            endcase
        end
    end
    //TODO: add for eq function
    wire phy_addr;
    assign phy_addr =  ((mpt_req_fsm_cs == RD_MPT_REQ) && (mpt_req_mtt_dout[162:160] == `DATA_WR_PHY)) ||
        ((mpt_req_fsm_cs == INIT_LOOKUP) && (qv_get_mpt_req[162:160] == `DATA_WR_PHY));

    //request virtual addr page inside offset(low 12) add byte length
    wire [31:0]  req_vaddr_offset_add_Blen; 
    // assign req_vaddr_offset_add_Blen = (mpt_req_fsm_cs==RD_MPT_REQ) ? (mpt_req_mtt_dout[43:32] + mpt_req_mtt_dout[31:0]) : (qv_get_mpt_req[43:32] + qv_get_mpt_req[31:0]);
    assign req_vaddr_offset_add_Blen = ((mpt_req_fsm_cs==RD_MPT_REQ)) ? (mpt_req_mtt_dout[43:32] + mpt_req_mtt_dout[31:0]) : (qv_get_mpt_req[43:32] + qv_get_mpt_req[31:0]);
    //mtt entry num = total physical page num =  (offset+Blen)/4K+((offset+Blen)%4K ? 1 :0)
    wire [31:0]  total_mtt_entry_num; 
    //TODO: add for eq function
    // assign total_mtt_entry_num = req_vaddr_offset_add_Blen[31:12] + (|req_vaddr_offset_add_Blen[11:0] ? 1 : 0);
    assign total_mtt_entry_num = phy_addr ? 1 : (req_vaddr_offset_add_Blen[31:12] + (|req_vaddr_offset_add_Blen[11:0] ? 1 : 0));
    //request index offset in cache line add total mtt entry num
    wire [31:0]  index_off_add_total_mtt_num;
    // assign index_off_add_total_mtt_num = (mpt_req_fsm_cs==RD_MPT_REQ) ? (mpt_req_mtt_dout[97:96] + total_mtt_entry_num) : (qv_get_mpt_req[97:96] + total_mtt_entry_num);
    wire [63:0] wv_mpt_req_mtt_addr;
    // assign wv_mpt_req_mtt_addr = (mpt_req_fsm_cs==RD_MPT_REQ) ? mpt_req_mtt_dout[159:96] : qv_get_mpt_req[159:96];
    assign wv_mpt_req_mtt_addr = ((mpt_req_fsm_cs==RD_MPT_REQ)) ? mpt_req_mtt_dout[159:96] : qv_get_mpt_req[159:96];
    // assign index_off_add_total_mtt_num = wv_mpt_req_mtt_addr[1:0] + total_mtt_entry_num;
    //TODO: add for eq function
    assign index_off_add_total_mtt_num = phy_addr ? 1 : (wv_mpt_req_mtt_addr[1:0] + total_mtt_entry_num);
    
    
    // //total mtt_ram look up num derived from 1 mpt req
    //     //    wire  [31:0]  total_mpt_req_mtt_num;
    // assign total_mpt_req_mtt_num = index_off_add_total_mtt_num[31:2] + (|index_off_add_total_mtt_num[1:0] ? 1 :0);

    // //reg for mpt look up mtt_ram times cnt
    //     //    reg  [31:0]  qv_mpt_req_mtt_cnt;
    // always @(posedge clk or posedge rst) begin
    //     if (rst) begin
    //         qv_mpt_req_mtt_cnt <= `TD 0;
    //     end
    //     else begin
    //        case (mpt_req_fsm_cs)
    //            RD_MPT_REQ: begin
    //                qv_mpt_req_mtt_cnt <= `TD 0;
    //            end
    //            INIT_LOOKUP: begin
    //             /*VCS Verification*/
    //             /*Action = Modify, add state_valid, rden and wren signals judge*/
    //             if ((((qv_get_mpt_req[161:160] == `DOWN) && !dma_rd_dt_req_prog_full) || ((qv_get_mpt_req[161:160] == `UP) && !dma_wr_dt_req_prog_full)) && (state_valid | (!state_valid & (lookup_state == 3'b1))) && !(lookup_rden | lookup_wren) && lookup_allow_in) begin
    //                     qv_mpt_req_mtt_cnt <= `TD qv_mpt_req_mtt_cnt + 1;
    //                 end else begin
    //                     qv_mpt_req_mtt_cnt <= `TD qv_mpt_req_mtt_cnt;
    //                 end                  
    //            end
    //            LOOKUP_RESULT_PROC: begin
    //                qv_mpt_req_mtt_cnt <= `TD qv_mpt_req_mtt_cnt;
    //            end
    //            default: qv_mpt_req_mtt_cnt <= `TD 0;
    //        endcase 
    //     end
    // end

    //reg for mpt look up mtt_ram addr, mtt index in mtt_ram
        //    reg  [63:0]  qv_mpt_req_mtt_addr;    
    //left mtt entry num for 1 mpt req
        //    reg  [31:0] qv_left_mtt_entry_num;
    //reg for the data virtual addr of the 1st mtt in cache line
        // reg  [63:0] qv_fisrt_mtt_vaddr; 
    //left mtt Byte length if all the mtt entry in l cacheline of mtt_ram lookup have initiated dma req
        //    reg  [31:0] qv_left_mtt_Blen;
    // store the req mtt num in one cacheline of 1 mtt_ram lookup
        //reg [2:0] qv_mtt_num_in_cacheline;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_mpt_req_mtt_addr <= `TD 0;
            qv_left_mtt_entry_num <= `TD 0;
            qv_fisrt_mtt_vaddr <= `TD 0;
            qv_left_mtt_Blen <= `TD 0;
            qv_mtt_num_in_cacheline <= `TD 0;
        end
        else begin
            case (mpt_req_fsm_cs)
                RD_MPT_REQ: begin
                    if (mpt_req_mtt_rd_en) begin
                        // qv_mpt_req_mtt_addr <= `TD mpt_req_mtt_dout[159:96];
                        qv_mpt_req_mtt_addr <= `TD wv_mpt_req_mtt_addr;
                        qv_left_mtt_entry_num <= `TD total_mtt_entry_num;
                        /*VCS  Verification*/
                        // qv_fisrt_mtt_vaddr <= `TD mpt_req_mtt_dout[63:0];
                        qv_fisrt_mtt_vaddr <= `TD mpt_req_mtt_dout[95:32];
                        /*Action = Modify, correct the selected bits from mpt_ram_ctl request*/
                       
                        qv_left_mtt_Blen <= `TD mpt_req_mtt_dout[31:0];
                        //total req mtt num + cache line offset > 4; this req mtt num = 4- cacheline offset
                        qv_mtt_num_in_cacheline <= `TD (index_off_add_total_mtt_num >= 4) ? (3'b100 - wv_mpt_req_mtt_addr[1:0]) : total_mtt_entry_num; 
                        // qv_mtt_num_in_cacheline <= `TD (index_off_add_total_mtt_num >= 4) ? (3'b100 - mpt_req_mtt_dout[97:96]) : total_mtt_entry_num; 
                    end else begin
                        qv_mpt_req_mtt_addr <= `TD 0;
                        qv_left_mtt_entry_num <= `TD 0;
                        qv_fisrt_mtt_vaddr <= `TD 0;
                        qv_left_mtt_Blen <= `TD 0;
                        qv_mtt_num_in_cacheline <= `TD 0;
                    end
                end
                INIT_LOOKUP: begin
                    qv_mpt_req_mtt_addr <= `TD qv_mpt_req_mtt_addr;
                    qv_left_mtt_entry_num <= `TD qv_left_mtt_entry_num;
                    qv_fisrt_mtt_vaddr <= `TD qv_fisrt_mtt_vaddr;
                    qv_left_mtt_Blen <= `TD qv_left_mtt_Blen;
                    qv_mtt_num_in_cacheline <= `TD qv_mtt_num_in_cacheline;
                end
                LOOKUP_RESULT_PROC: begin
                    /*VCS Verification*/
                    // if ((qv_left_dma_req_from_mpt == 1) && (qv_left_dma_req_from_cache == 1) && (qv_left_mtt_entry_num == 1) &&  (qv_mpt_req_mtt_cnt == total_mpt_req_mtt_num) && (((qv_get_mpt_req[161:160] == `DOWN) && !dma_rd_dt_req_prog_full) || ((qv_get_mpt_req[161:160] == `UP) && !dma_wr_dt_req_prog_full)) && (state_valid | q_result_valid)) begin
                    if ((qv_left_dma_req_from_mpt == qv_mtt_num_in_cacheline) && (qv_left_dma_req_from_cache == 1) && ((is_rd_data && !dma_rd_dt_req_prog_full) || (is_wr_data && !dma_wr_dt_req_prog_full) || (is_rd_wqe && !dma_rd_wqe_req_prog_full) ) && (state_valid | q_result_valid)) begin
                        qv_mpt_req_mtt_addr <= `TD 0;
                        qv_left_mtt_entry_num <= `TD 0;
                        qv_fisrt_mtt_vaddr <= `TD 0;
                        qv_left_mtt_Blen <= `TD 0;
                        qv_mtt_num_in_cacheline <= `TD 0;
                    end                    
                    /*Action = Add, add regs chnage if next state is RD_MPT_REQ*/
                    // //next state is INIT_LOOKUP, change the data for lookup info and dma request in the next LOOKUP_RESULT_PROC state
                    // else if ((qv_left_dma_req_from_mpt >= 1) && (qv_left_dma_req_from_cache == 1) && (qv_left_mtt_entry_num > 0) &&  (qv_mpt_req_mtt_cnt < total_mpt_req_mtt_num) && (((qv_get_mpt_req[161:160] == `DOWN) && !dma_rd_dt_req_prog_full) || ((qv_get_mpt_req[161:160] == `UP) && !dma_wr_dt_req_prog_full)) && (qv_mpt_req_mtt_addr[1:0] + qv_left_mtt_entry_num > 4) && (state_valid | q_result_valid) ) begin
                    // /*Action = Add, add  (&& (state_valid | q_result_valid)) condition*/
                    //     //req mtt num exceed 1 cacheline: index = index + 1; offset = 0 
                    //     qv_mpt_req_mtt_addr <= `TD {qv_mpt_req_mtt_addr[63:2],2'b00}+{61'b0,3'b100};
                    //     //req mtt num exceed 1 cacheline: left num = left num - req mtt num in the cacheline
                    //     qv_left_mtt_entry_num <= `TD qv_left_mtt_entry_num - (4 - qv_mpt_req_mtt_addr[1:0]);
                    //     //req mtt num exceed 1 cacheline: fisrt_mtt_vaddr = fisrt_mtt_vaddr + req mtt num in cachline * 4K; low 12 bit=0
                    //     qv_fisrt_mtt_vaddr <= `TD {qv_fisrt_mtt_vaddr[63:12],12'b0} + {50'b1,14'b0} - {50'b0,qv_mpt_req_mtt_addr[1:0],12'b0};
                    //     //req mtt num exceed 1 cacheline: left length = left length -(4K-vaddr{11:0})- (3-mtt num in cacheline)*4K;
                    //     qv_left_mtt_Blen <= `TD qv_left_mtt_Blen - ({20'b1,12'b0} - {20'b0,qv_fisrt_mtt_vaddr[11:0]}) - ({20'b11,12'b0} - {18'b0, qv_mpt_req_mtt_addr[1:0],12'b0});
                    //     /*VCS Verification*/
                    //     //req mtt num exceed 1 cacheline: this mtt_ram mtt req num = 4;
                    //     // qv_mtt_num_in_cacheline <= `TD 4;
                    //     qv_mtt_num_in_cacheline <= `TD ((qv_left_mtt_entry_num - (4 - qv_mpt_req_mtt_addr[1:0])) > 4) ? 4 : (qv_left_mtt_entry_num - (4 - qv_mpt_req_mtt_addr[1:0]));
                    //     /*Action = Modify, correct mtt_ram mtt req num*/
                    // end
                    // //next state is INIT_LOOKUP, change the data for lookup info and dma request in the next LOOKUP_RESULT_PROC state
                    // else if ((qv_left_dma_req_from_mpt >= 1) && (qv_left_dma_req_from_cache == 1) && (qv_left_mtt_entry_num > 0) && (qv_mpt_req_mtt_cnt < total_mpt_req_mtt_num) && (((qv_get_mpt_req[161:160] == `DOWN) && !dma_rd_dt_req_prog_full) |(    (qv_get_mpt_req[161:160] == `UP) && !dma_wr_dt_req_prog_full)) && (qv_mpt_req_mtt_addr[1:0] +qv_left_mtt_entry_num <= 4) && (state_valid | q_result_valid) ) begin
                    // /*Action = Add, add  (&& (state_valid | q_result_valid)) condition*/
                    //     //req mtt num don't exceed 1 cacheline: index = index; offset = offset + num                       
                    //     qv_mpt_req_mtt_addr <= `TD qv_mpt_req_mtt_addr + qv_left_mtt_entry_num;
                    //     //req mtt num not exceed 1 cacheline: left num = 0
                    //     qv_left_mtt_entry_num <= `TD 0;
                    //     //req mtt num not exceed 1 cacheline: fisrt_mtt_vaddr = fisrt_mtt_vaddr + qv_left_mtt_Blen;
                    //     qv_fisrt_mtt_vaddr <= `TD qv_fisrt_mtt_vaddr + qv_left_mtt_Blen;
                    //     //req mtt num not exceed 1 cacheline: left length = 0;
                    //     qv_left_mtt_Blen <= `TD 0;
                    //     //req mtt num not exceed 1 cacheline: this mtt_ram mtt req num = left mtt num
                    //     qv_mtt_num_in_cacheline <= `TD qv_left_mtt_entry_num;
                    // end
                    else begin
                        qv_mpt_req_mtt_addr <= `TD qv_mpt_req_mtt_addr;
                        qv_left_mtt_entry_num <= `TD qv_left_mtt_entry_num;
                        qv_fisrt_mtt_vaddr <= `TD qv_fisrt_mtt_vaddr;
                        qv_left_mtt_Blen <= `TD qv_left_mtt_Blen;
                        qv_mtt_num_in_cacheline <= `TD qv_mtt_num_in_cacheline;
                    end
                end
                default: begin
                    qv_mpt_req_mtt_addr <= `TD 0;
                    qv_left_mtt_entry_num <= `TD 0;
                    qv_fisrt_mtt_vaddr <= `TD 0;
                    qv_left_mtt_Blen <= `TD 0;
                    qv_mtt_num_in_cacheline <= `TD 0;
                end 
            endcase 
        end
    end

    //store the virtual address offset in physical page, the num of virtual addr = qv_mtt_num_in_cacheline
    // reg [11:0] virt_addr_offset3;
    // reg [11:0] virt_addr_offset2;
    // reg [11:0] virt_addr_offset1;
    wire [11:0] virt_addr_offset3;
    assign virt_addr_offset3 = 12'b0;
    wire [11:0] virt_addr_offset2;
    assign virt_addr_offset2 = 12'b0;
    wire [11:0] virt_addr_offset1;
    assign virt_addr_offset1 = 12'b0;
    reg [11:0] virt_addr_offset0;
    //store the Byte length in physical page, the num of Byte length variables = qv_mtt_num_in_cacheline
    reg [31:0] byte_length3;
    reg [31:0] byte_length2;
    reg [31:0] byte_length1;
    reg [31:0] byte_length0;  
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // virt_addr_offset3 <= `TD 0;
            // virt_addr_offset2 <= `TD 0;
            // virt_addr_offset1 <= `TD 0;
            virt_addr_offset0 <= `TD 0;
            byte_length3      <= `TD 0;
            byte_length2      <= `TD 0;
            byte_length1      <= `TD 0;
            byte_length0      <= `TD 0;
        end else begin
            case (mpt_req_fsm_cs)
                RD_MPT_REQ: begin
                    if (mpt_req_mtt_rd_en && (index_off_add_total_mtt_num <= 4)) begin
                        // virt_addr_offset3 <= `TD 0;
                        // virt_addr_offset2 <= `TD 0;
                        // virt_addr_offset1 <= `TD 0;
                        virt_addr_offset0 <= `TD mpt_req_mtt_dout[43:32];
                        //if vaddr offset in page + byte length > 16K: byte length = 4K; else: byte length = vaddr offset+byte length-12K
                        byte_length3  <= `TD ((mpt_req_mtt_dout[31:0] + {20'b0,mpt_req_mtt_dout[43:32]})> {20'b100,12'b0}) ? {20'b1,12'b0} : ({20'b0,mpt_req_mtt_dout[43:32]} + mpt_req_mtt_dout[31:0] - {20'b11,12'b0});
                        //if vaddr offset in page + byte length > 12K: byte length = 4K; else: byte length = vaddr offset+byte length-8K
                        byte_length2  <= `TD ((mpt_req_mtt_dout[31:0] + {20'b0,mpt_req_mtt_dout[43:32]})> {20'b11,12'b0}) ? {20'b1,12'b0} : ({20'b0,mpt_req_mtt_dout[43:32]} + mpt_req_mtt_dout[31:0] - {20'b10,12'b0});
                        //if vaddr offset in page + byte length > 8K: byte length = 4K; else: byte length = vaddr offset+byte length-4K
                        byte_length1  <= `TD ((mpt_req_mtt_dout[31:0] + {20'b0,mpt_req_mtt_dout[43:32]})> {20'b10,12'b0}) ? {20'b1,12'b0} : ({20'b0,mpt_req_mtt_dout[43:32]} + mpt_req_mtt_dout[31:0] - {20'b1,12'b0});
                        //if vaddr offset in page + byte length > 4K: byte length = 4K - vaddr offset; else: byte length = byte length
                        byte_length0  <= `TD ((mpt_req_mtt_dout[31:0] + {20'b0,mpt_req_mtt_dout[43:32]}) > {20'b1,12'b0}) ? ({20'b1,12'b0} - {20'b0,mpt_req_mtt_dout[43:32]}) : mpt_req_mtt_dout[31:0];
                    end                   
                    else begin
                        // virt_addr_offset3 <= `TD 0;
                        // virt_addr_offset2 <= `TD 0;
                        // virt_addr_offset1 <= `TD 0;
                        virt_addr_offset0 <= `TD 0;
                        byte_length3      <= `TD 0;
                        byte_length2      <= `TD 0;
                        byte_length1      <= `TD 0;
                        byte_length0      <= `TD 0;
                    end
                end
                INIT_LOOKUP: begin
                    //keep the data for dma request in the LOOKUP_RESULT_PROC state
                    // virt_addr_offset3 <= `TD virt_addr_offset3;
                    // virt_addr_offset2 <= `TD virt_addr_offset2;
                    // virt_addr_offset1 <= `TD virt_addr_offset1;
                    virt_addr_offset0 <= `TD virt_addr_offset0;
                    byte_length3      <= `TD byte_length3     ;
                    byte_length2      <= `TD byte_length2     ;
                    byte_length1      <= `TD byte_length1     ;
                    byte_length0      <= `TD byte_length0     ;
                end
                LOOKUP_RESULT_PROC: begin
                    // //next state is INIT_LOOKUP, change the data for dma request in the next LOOKUP_RESULT_PROC state
                    // if ((qv_left_dma_req_from_mpt >= 1) && (qv_left_dma_req_from_cache == 1) && (qv_left_mtt_entry_num > 0) && (qv_mpt_req_mtt_cnt <= total_mpt_req_mtt_num) && (((qv_get_mpt_req[161:160] == `DOWN) && !dma_rd_dt_req_prog_full) || ((qv_get_mpt_req[161:160] == `UP) && !dma_wr_dt_req_prog_full)) && (qv_mpt_req_mtt_addr[1:0] + qv_left_mtt_entry_num > 4)) begin
                    //     virt_addr_offset3 <= `TD 0;
                    //     virt_addr_offset2 <= `TD 0;
                    //     virt_addr_offset1 <= `TD 0;
                    //     virt_addr_offset0 <= `TD qv_fisrt_mtt_vaddr[11:0];
                    //     /*VCS Verification*/
                    //     // byte_length3      <= `TD {20'b1,12'b0};
                    //     // byte_length2      <= `TD {20'b1,12'b0};
                    //     // byte_length1      <= `TD {20'b1,12'b0};
                    //     // byte_length0      <= `TD {20'b1,12'b0} - {20'b0,qv_fisrt_mtt_vaddr[11:0]};
                    //     //if vaddr offset in page + byte length > 16K: byte length = 4K; else: byte length = vaddr offset+byte length-12K
                    //     byte_length3  <= `TD (qv_left_mtt_Blen + {20'b0,qv_fisrt_mtt_vaddr[11:0]} > {20'b100,12'b0}) ? {20'b1,12'b0} : ({20'b0,qv_fisrt_mtt_vaddr[11:0]} + qv_left_mtt_Blen - {20'b11,12'b0});
                    //     //if vaddr offset in page + byte length > 12K: byte length = 4K; else: byte length = vaddr offset+byte length-8K
                    //     byte_length2  <= `TD (qv_left_mtt_Blen + {20'b0,qv_fisrt_mtt_vaddr[11:0]} > {20'b11,12'b0}) ? {20'b1,12'b0} : ({20'b0,qv_fisrt_mtt_vaddr[11:0]} + qv_left_mtt_Blen - {20'b10,12'b0});
                    //     //if vaddr offset in page + byte length > 8K: byte length = 4K; else: byte length = vaddr offset+byte length-4K
                    //     byte_length1  <= `TD (qv_left_mtt_Blen + {20'b0,qv_fisrt_mtt_vaddr[11:0]} > {20'b10,12'b0}) ? {20'b1,12'b0} : ({20'b0,qv_fisrt_mtt_vaddr[11:0]} + qv_left_mtt_Blen - {20'b1,12'b0});
                    //     //if vaddr offset in page + byte length > 4K: byte length = 4K - vaddr offset; else: byte length = byte length
                    //     byte_length0  <= `TD (qv_left_mtt_Blen + {20'b0,qv_fisrt_mtt_vaddr[11:0]} > {20'b1,12'b0}) ? ({20'b1,12'b0} - {20'b0,qv_fisrt_mtt_vaddr[11:0]}) : qv_left_mtt_Blen;
                    //     /*Action = Modify, correct the byte_length*/
                    // end
                    // //next state is INIT_LOOKUP, change the data for dma request in the next LOOKUP_RESULT_PROC state
                    // else if ((qv_left_dma_req_from_mpt >= 1) && (qv_left_dma_req_from_cache == 1) && (qv_left_mtt_entry_num > 0) && (qv_mpt_req_mtt_cnt <= total_mpt_req_mtt_num) && (((qv_get_mpt_req[161:160] == `DOWN) && !dma_rd_dt_req_prog_full) || ((qv_get_mpt_req[161:160] == `UP) && !dma_wr_dt_req_prog_full)) && (qv_mpt_req_mtt_addr[1:0] + qv_left_mtt_entry_num <= 4)) begin
                    //     virt_addr_offset3 <= `TD 0;
                    //     virt_addr_offset2 <= `TD 0;
                    //     virt_addr_offset1 <= `TD 0;
                    //     virt_addr_offset0 <= `TD qv_fisrt_mtt_vaddr[11:0];
                    //     //if vaddr offset in page + byte length > 16K: byte length = 4K; else: byte length = vaddr offset+byte length-12K
                    //     byte_length3  <= `TD (qv_left_mtt_Blen + {20'b0,qv_fisrt_mtt_vaddr[11:0]} > {20'b100,12'b0}) ? {20'b1,12'b0} : ({20'b0,qv_fisrt_mtt_vaddr[11:0]} + qv_left_mtt_Blen - {20'b11,12'b0});
                    //     //if vaddr offset in page + byte length > 12K: byte length = 4K; else: byte length = vaddr offset+byte length-8K
                    //     byte_length2  <= `TD (qv_left_mtt_Blen + {20'b0,qv_fisrt_mtt_vaddr[11:0]} > {20'b11,12'b0}) ? {20'b1,12'b0} : ({20'b0,qv_fisrt_mtt_vaddr[11:0]} + qv_left_mtt_Blen - {20'b10,12'b0});
                    //     //if vaddr offset in page + byte length > 8K: byte length = 4K; else: byte length = vaddr offset+byte length-4K
                    //     byte_length1  <= `TD (qv_left_mtt_Blen + {20'b0,qv_fisrt_mtt_vaddr[11:0]} > {20'b10,12'b0}) ? {20'b1,12'b0} : ({20'b0,qv_fisrt_mtt_vaddr[11:0]} + qv_left_mtt_Blen - {20'b1,12'b0});
                    //     //if vaddr offset in page + byte length > 4K: byte length = 4K - vaddr offset; else: byte length = byte length
                    //     byte_length0  <= `TD (qv_left_mtt_Blen + {20'b0,qv_fisrt_mtt_vaddr[11:0]} > {20'b1,12'b0}) ? ({20'b1,12'b0} - {20'b0,qv_fisrt_mtt_vaddr[11:0]}) : qv_left_mtt_Blen;
                    // end
                    // else begin
                    //     virt_addr_offset3 <= `TD virt_addr_offset3;
                    //     virt_addr_offset2 <= `TD virt_addr_offset2;
                    //     virt_addr_offset1 <= `TD virt_addr_offset1;
                    //     virt_addr_offset0 <= `TD virt_addr_offset0;
                    //     byte_length3      <= `TD byte_length3     ;
                    //     byte_length2      <= `TD byte_length2     ;
                    //     byte_length1      <= `TD byte_length1     ;
                    //     byte_length0      <= `TD byte_length0     ;
                    // end
                    // virt_addr_offset3 <= `TD virt_addr_offset3;
                    // virt_addr_offset2 <= `TD virt_addr_offset2;
                    // virt_addr_offset1 <= `TD virt_addr_offset1;
                    virt_addr_offset0 <= `TD virt_addr_offset0;
                    byte_length3      <= `TD byte_length3     ;
                    byte_length2      <= `TD byte_length2     ;
                    byte_length1      <= `TD byte_length1     ;
                    byte_length0      <= `TD byte_length0     ;
                end
                default: begin
                    // virt_addr_offset3 <= `TD 0;
                    // virt_addr_offset2 <= `TD 0;
                    // virt_addr_offset1 <= `TD 0;
                    virt_addr_offset0 <= `TD 0;
                    byte_length3      <= `TD 0;
                    byte_length2      <= `TD 0;
                    byte_length1      <= `TD 0;
                    byte_length0      <= `TD 0;
                end
            endcase
        end
    end

    //mtt_ram response state add data----------------------
        //        input  wire [2:0]               lookup_state,// | 2<->miss | 1<->hit | 0<->idle |
        //        input  wire                     lookup_ldst, // 1 for store, and 0 for load
        //        input  wire                     state_valid, // valid in normal state, invalid if stall
        //        input  wire [LINE_SIZE*8-1:0]   hit_rdata,//hit read mtt entry 
        //        input  wire [LINE_SIZE*8-1:0]   miss_rdata,//miss read mtt entry, it's the dma reaponse data
    //    store the mtt_ram lookup results
        //    reg  [LINE_SIZE*8-1:0]   qv_rdata;
        //    reg  [2:0]               qv_state;
        //    reg                      q_ldst;
        //    reg                      q_result_valid;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_rdata <= `TD 0;
            qv_state <= `TD 0;  
            q_ldst   <= `TD 0;
            q_result_valid <= `TD 0;
        end else if ((mpt_req_fsm_cs == LOOKUP_RESULT_PROC) && state_valid) begin
            qv_rdata <= `TD hit_rdata | miss_rdata;
            qv_state <= `TD lookup_state;
            q_ldst   <= `TD lookup_ldst;
            q_result_valid <= `TD state_valid;
        end else if (mpt_req_fsm_cs == LOOKUP_RESULT_PROC) begin
            qv_rdata <= `TD qv_rdata;
            qv_state <= `TD qv_state;
            q_ldst   <= `TD q_ldst  ;
            q_result_valid <= `TD q_result_valid;
        end
        else begin
            qv_rdata <= `TD 0;
            qv_state <= `TD 0;
            q_ldst   <= `TD 0;
            q_result_valid <= `TD 0;
        end
    end

    //left dma_read/write_data req num derived from 1 mtt_ram read req result
        //    reg  [2:0]  qv_left_dma_req_from_cache;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_left_dma_req_from_cache <= `TD 0;
        end 
        else begin
            case (mpt_req_fsm_cs)
                RD_MPT_REQ: begin
                    qv_left_dma_req_from_cache <= `TD 0;              
                end
                INIT_LOOKUP: begin
                /*VCS Verification*/
                /*Action = Modify, add state_valid, rden and wren signals judge*/
                    if (((is_rd_data && !dma_rd_dt_req_prog_full) || (is_wr_data && !dma_wr_dt_req_prog_full) ||(is_rd_wqe && !dma_rd_wqe_req_prog_full)) && (state_valid | (!state_valid & (lookup_state == 3'b1))) && !(lookup_rden | lookup_wren)) begin
                        qv_left_dma_req_from_cache <= `TD qv_mtt_num_in_cacheline;
                    end else begin
                        qv_left_dma_req_from_cache <= `TD qv_left_dma_req_from_cache;
                    end
                end
                LOOKUP_RESULT_PROC: begin
                    if ((qv_left_dma_req_from_cache > 0) && (state_valid | q_result_valid) && ((is_rd_data && !dma_rd_dt_req_prog_full) || (is_wr_data && !dma_wr_dt_req_prog_full) ||(is_rd_wqe && !dma_rd_wqe_req_prog_full))) begin
                        qv_left_dma_req_from_cache <= `TD qv_left_dma_req_from_cache - 1;
                    end
                    else begin
                        qv_left_dma_req_from_cache <= `TD qv_left_dma_req_from_cache;
                    end
                end
                default: qv_left_dma_req_from_cache <= `TD 0;
            endcase
        end
    end
    //left dma_read/write_data req num derived from 1 mpt req
        //    reg  [31:0] qv_left_dma_req_from_mpt;//
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_left_dma_req_from_mpt <= `TD 0;
        end
        else begin
            case (mpt_req_fsm_cs)
                RD_MPT_REQ: begin
                    if (mpt_req_mtt_rd_en) begin
                        qv_left_dma_req_from_mpt <= `TD total_mtt_entry_num;              
                    end else begin
                        qv_left_dma_req_from_mpt <= `TD 0;
                    end
                end
                INIT_LOOKUP: begin
                    qv_left_dma_req_from_mpt <= `TD qv_left_dma_req_from_mpt;
                end
                LOOKUP_RESULT_PROC: begin
                    if ((qv_left_dma_req_from_mpt > 0) && (qv_left_dma_req_from_cache == 1) && (state_valid | q_result_valid) && ((is_rd_data && !dma_rd_dt_req_prog_full) || (is_wr_data && !dma_wr_dt_req_prog_full) ||(is_rd_wqe && !dma_rd_wqe_req_prog_full))) begin
                        qv_left_dma_req_from_mpt <= `TD qv_left_dma_req_from_mpt - qv_mtt_num_in_cacheline;
                    end
                    else begin
                        qv_left_dma_req_from_mpt <= `TD qv_left_dma_req_from_mpt;
                    end
                end
                default: qv_left_dma_req_from_mpt <= `TD 0;
            endcase
        end
    end

    //------------------interface to dma_read/write_data module-------------
        //reg                                dma_rd_dt_req_wr_en;
        //reg                                dma_wr_dt_req_wr_en;
        //reg                                dma_rd_wqe_req_wr_en;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dma_rd_dt_req_wr_en <= `TD 1'b0;
            dma_wr_dt_req_wr_en <= `TD 1'b0;
            dma_rd_wqe_req_wr_en <= `TD 1'b0;
        end else if ((mpt_req_fsm_cs == LOOKUP_RESULT_PROC) && (qv_left_dma_req_from_cache > 0) && (state_valid | q_result_valid)) begin
            case ({is_rd_wqe,is_wr_data,is_rd_data})
                3'b001: begin
                    if (!dma_rd_dt_req_prog_full) begin
                        dma_rd_dt_req_wr_en <= `TD 1'b1;
                        dma_wr_dt_req_wr_en <= `TD 1'b0;
                        dma_rd_wqe_req_wr_en <= `TD 1'b0;
                    end else begin
                        dma_rd_dt_req_wr_en <= `TD 1'b0;
                        dma_wr_dt_req_wr_en <= `TD 1'b0;
                        dma_rd_wqe_req_wr_en <= `TD 1'b0;
                    end
                end
                3'b010: begin
                    if (!dma_wr_dt_req_prog_full) begin
                        dma_rd_dt_req_wr_en <= `TD 1'b0;
                        dma_wr_dt_req_wr_en <= `TD 1'b1;
                        dma_rd_wqe_req_wr_en <= `TD 1'b0;
                    end else begin
                        dma_rd_dt_req_wr_en <= `TD 1'b0;
                        dma_wr_dt_req_wr_en <= `TD 1'b0;
                        dma_rd_wqe_req_wr_en <= `TD 1'b0;
                    end
                end
                3'b100: begin
                    if (!dma_rd_wqe_req_prog_full) begin
                        dma_rd_dt_req_wr_en <= `TD 1'b0;
                        dma_wr_dt_req_wr_en <= `TD 1'b0;
                        dma_rd_wqe_req_wr_en <= `TD 1'b1;
                    end else begin
                        dma_rd_dt_req_wr_en <= `TD 1'b0;
                        dma_wr_dt_req_wr_en <= `TD 1'b0;
                        dma_rd_wqe_req_wr_en <= `TD 1'b0;
                    end
                end
                default: begin
                    dma_rd_dt_req_wr_en <= `TD 1'b0;
                    dma_wr_dt_req_wr_en <= `TD 1'b0;
                    dma_rd_wqe_req_wr_en <= `TD 1'b0;
                end
            endcase
        end
        else begin
            dma_rd_dt_req_wr_en <= `TD 1'b0;
            dma_wr_dt_req_wr_en <= `TD 1'b0;
            dma_rd_wqe_req_wr_en <= `TD 1'b0;
        end
    end

    //devide the lookup results
    wire [51:0] dma_req_page_addr0;
    wire [51:0] dma_req_page_addr1;
    wire [51:0] dma_req_page_addr2;
    wire [51:0] dma_req_page_addr3;
    assign dma_req_page_addr0 = ((mpt_req_fsm_cs == LOOKUP_RESULT_PROC) && state_valid && !lookup_ldst) ? 
                                    {miss_rdata[64*1-1:64*0+12] | hit_rdata[64*1-1:64*0+12]} : 
                                ((mpt_req_fsm_cs == LOOKUP_RESULT_PROC) && q_result_valid && !q_ldst) ?  
                                    qv_rdata[64*1-1:64*0+12] : 0;
    assign dma_req_page_addr1 = ((mpt_req_fsm_cs == LOOKUP_RESULT_PROC) && state_valid && !lookup_ldst) ? 
                                   {miss_rdata[64*2-1:64*1+12] | hit_rdata[64*2-1:64*1+12]} : 
                               ((mpt_req_fsm_cs == LOOKUP_RESULT_PROC) && q_result_valid && !q_ldst) ?  
                                   qv_rdata[64*2-1:64*1+12] : 0;                                
    assign dma_req_page_addr2 = ((mpt_req_fsm_cs == LOOKUP_RESULT_PROC) && state_valid && !lookup_ldst) ? 
                                   {miss_rdata[64*3-1:64*2+12] | hit_rdata[64*3-1:64*2+12]} : 
                               ((mpt_req_fsm_cs == LOOKUP_RESULT_PROC) && q_result_valid && !q_ldst) ?  
                                   qv_rdata[64*3-1:64*2+12] : 0;   
    assign dma_req_page_addr3 = ((mpt_req_fsm_cs == LOOKUP_RESULT_PROC) && state_valid && !lookup_ldst) ? 
                                    {miss_rdata[64*4-1:64*3+12] | hit_rdata[64*4-1:64*3+12]} : 
                                ((mpt_req_fsm_cs == LOOKUP_RESULT_PROC) && q_result_valid && !q_ldst) ?  
                                    qv_rdata[64*4-1:64*3+12] : 0;  

    // -mtt_ram_ctl--dma_read_data/dma_read_wqe/dma_write_data req header format
        // //high-----------------------------low
        //|-------------------134 bit--------------------|
        //| total len |opcode | dest/src |tmp len | addr |
        //| 32        |   3   |     3    | 32     |  64  |
        //|----------------------------------------------|
        //reg   [DMA_DT_REQ_WIDTH-1:0]       dma_rd_dt_req_din;
        //reg   [DMA_DT_REQ_WIDTH-1:0]       dma_wr_dt_req_din;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dma_rd_dt_req_din <= `TD 134'b0;
            dma_wr_dt_req_din <= `TD 134'b0;
            dma_rd_wqe_req_din <= `TD 134'b0;
        end else if ((mpt_req_fsm_cs == LOOKUP_RESULT_PROC) && (qv_left_dma_req_from_cache > 0) && (state_valid | q_result_valid)) begin
            /*VCS Verification*/
            case ({is_rd_wqe,is_wr_data,is_rd_data})
                3'b001: begin
                    case (qv_mtt_num_in_cacheline)
                        3'b001: begin
                            case (qv_left_dma_req_from_cache)
                                3'b001: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_rd_dt_req_prog_full) begin
                                                // dma_rd_dt_req_din <= `TD {qv_get_mpt_req[31:0],((((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ? `DATA_RD_FIRST : `DATA_RD),qv_get_mpt_req[164:162],byte_length0,dma_req_page_addr0, virt_addr_offset0};
                                                dma_rd_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr0, virt_addr_offset0};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b01: begin
                                            if (!dma_rd_dt_req_prog_full) begin
                                                dma_rd_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr1, virt_addr_offset0};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b10: begin
                                            if (!dma_rd_dt_req_prog_full) begin
                                                dma_rd_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr2, virt_addr_offset0};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b11: begin
                                            if (!dma_rd_dt_req_prog_full) begin
                                                dma_rd_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr3, virt_addr_offset0};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Modify*/
                                end
                                default: begin
                                    dma_rd_dt_req_din <= `TD 134'b0;
                                    dma_wr_dt_req_din <= `TD 134'b0;
                                    dma_rd_wqe_req_din <= `TD 134'b0;
                                end
                            endcase
                        end
                        3'b010: begin
                            case (qv_left_dma_req_from_cache)
                                3'b001: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_rd_dt_req_prog_full) begin
                                                dma_rd_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length1,dma_req_page_addr1, virt_addr_offset1};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b01: begin
                                            if (!dma_rd_dt_req_prog_full) begin
                                                dma_rd_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length1,dma_req_page_addr2, virt_addr_offset1};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b10: begin
                                            if (!dma_rd_dt_req_prog_full) begin
                                                dma_rd_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length1,dma_req_page_addr3, virt_addr_offset1};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/
                                    // if (!dma_rd_dt_req_prog_full) begin
                                    //     dma_rd_dt_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_RD_FIRST : `DATA_RD),qv_get_mpt_req[164:162],byte_length0,dma_req_page_addr0,virt_addr_offset0};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_dt_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                3'b010: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_rd_dt_req_prog_full) begin
                                                dma_rd_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr0, virt_addr_offset0};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b01: begin
                                            if (!dma_rd_dt_req_prog_full) begin
                                                dma_rd_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr1, virt_addr_offset0};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b10: begin
                                            if (!dma_rd_dt_req_prog_full) begin
                                                dma_rd_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr2, virt_addr_offset0};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/                                    
                                    // if (!dma_rd_dt_req_prog_full) begin
                                    //     dma_rd_dt_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_RD_FIRST : `DATA_RD),qv_get_mpt_req[164:162],byte_length1,dma_req_page_addr1,virt_addr_offset1};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_dt_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                default: begin
                                    dma_rd_dt_req_din <= `TD 134'b0;
                                    dma_wr_dt_req_din <= `TD 134'b0;
                                    dma_rd_wqe_req_din <= `TD 134'b0;
                                end
                            endcase
                        end
                        3'b011: begin
                            case (qv_left_dma_req_from_cache)
                                3'b001: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_rd_dt_req_prog_full) begin
                                                dma_rd_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length2,dma_req_page_addr2, virt_addr_offset2};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b01: begin
                                            if (!dma_rd_dt_req_prog_full) begin
                                                dma_rd_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length2,dma_req_page_addr3, virt_addr_offset2};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/                                    
                                    // if (!dma_rd_dt_req_prog_full) begin
                                    //     dma_rd_dt_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_RD_FIRST : `DATA_RD),qv_get_mpt_req[164:162],byte_length0,dma_req_page_addr0,virt_addr_offset0};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_dt_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                3'b010: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_rd_dt_req_prog_full) begin
                                                dma_rd_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length1,dma_req_page_addr1, virt_addr_offset1};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b01: begin
                                            if (!dma_rd_dt_req_prog_full) begin
                                                dma_rd_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length1,dma_req_page_addr2, virt_addr_offset1};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                            dma_rd_dt_req_din <= `TD 134'b0;
                                            dma_wr_dt_req_din <= `TD 134'b0;
                                            dma_rd_wqe_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/ 
                                    // if (!dma_rd_dt_req_prog_full) begin
                                    //     dma_rd_dt_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_RD_FIRST : `DATA_RD),qv_get_mpt_req[164:162],byte_length1,dma_req_page_addr1,virt_addr_offset1};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_dt_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                3'b011: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_rd_dt_req_prog_full) begin
                                                dma_rd_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr0, virt_addr_offset0};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b01: begin
                                            if (!dma_rd_dt_req_prog_full) begin
                                                dma_rd_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr1, virt_addr_offset0};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                            dma_rd_dt_req_din <= `TD 134'b0;
                                            dma_wr_dt_req_din <= `TD 134'b0;
                                            dma_rd_wqe_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/
                                    // if (!dma_rd_dt_req_prog_full) begin
                                    //     dma_rd_dt_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_RD_FIRST : `DATA_RD),qv_get_mpt_req[164:162],byte_length2,dma_req_page_addr2,virt_addr_offset2};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_dt_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                default: begin
                                    dma_rd_dt_req_din <= `TD 134'b0;
                                    dma_wr_dt_req_din <= `TD 134'b0;
                                    dma_rd_wqe_req_din <= `TD 134'b0;
                                end
                            endcase
                        end
                        3'b100: begin
                            case (qv_left_dma_req_from_cache)
                                3'b001: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_rd_dt_req_prog_full) begin
                                                dma_rd_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length3,dma_req_page_addr3, virt_addr_offset3};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/                                        
                                    // if (!dma_rd_dt_req_prog_full) begin
                                    //     dma_rd_dt_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_RD_FIRST : `DATA_RD),qv_get_mpt_req[164:162],byte_length0,dma_req_page_addr0,virt_addr_offset0};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_dt_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                3'b010: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_rd_dt_req_prog_full) begin
                                                dma_rd_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length2,dma_req_page_addr2, virt_addr_offset2};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/                                     
                                    // if (!dma_rd_dt_req_prog_full) begin
                                    //     dma_rd_dt_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_RD_FIRST : `DATA_RD),qv_get_mpt_req[164:162],byte_length1,dma_req_page_addr1,virt_addr_offset1};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_dt_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                3'b011: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_rd_dt_req_prog_full) begin
                                                dma_rd_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length1,dma_req_page_addr1, virt_addr_offset1};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/    
                                    // if (!dma_rd_dt_req_prog_full) begin
                                    //     dma_rd_dt_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_RD_FIRST : `DATA_RD),qv_get_mpt_req[164:162],byte_length2,dma_req_page_addr2,virt_addr_offset2};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_dt_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                3'b100: begin                                    
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_rd_dt_req_prog_full) begin
                                                dma_rd_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr0, virt_addr_offset0};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/    
                                    // if (!dma_rd_dt_req_prog_full) begin
                                    //     dma_rd_dt_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_RD_FIRST : `DATA_RD),qv_get_mpt_req[164:162],byte_length3,dma_req_page_addr3,virt_addr_offset3};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_dt_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                default: begin
                                    dma_rd_dt_req_din <= `TD 134'b0;
                                    dma_wr_dt_req_din <= `TD 134'b0;
                                    dma_rd_wqe_req_din <= `TD 134'b0;
                                end
                            endcase
                        end
                        default: begin
                            dma_rd_dt_req_din <= `TD 134'b0;
                            dma_wr_dt_req_din <= `TD 134'b0;
                            dma_rd_wqe_req_din <= `TD 134'b0;
                        end
                    endcase
                end
                3'b010: begin
                    //TODO: add eq fucntion
                    if (is_phy_wr) begin
                        if (!dma_wr_dt_req_prog_full) begin
                            dma_wr_dt_req_din <= `TD {qv_get_mpt_req[194:163],`DATA_WR_FIRST,qv_get_mpt_req[197:195],qv_get_mpt_req[31:0],qv_get_mpt_req[95:32]};
                            dma_rd_dt_req_din <= `TD 134'b0;
                            dma_rd_wqe_req_din <= `TD 134'b0;
                        end else begin
                            dma_rd_dt_req_din <= `TD 134'b0;
                            dma_wr_dt_req_din <= `TD 134'b0;
                            dma_rd_wqe_req_din <= `TD 134'b0;
                        end
                    end
                    //end TODO: add eq fucntion
                    else begin
                    case (qv_mtt_num_in_cacheline)
                        3'b001: begin
                            case (qv_left_dma_req_from_cache)
                                3'b001: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_wr_dt_req_prog_full) begin
                                                dma_wr_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_WR},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr0, virt_addr_offset0};
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b01: begin
                                            if (!dma_wr_dt_req_prog_full) begin
                                                dma_wr_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_WR},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr1, virt_addr_offset0};
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b10: begin
                                            if (!dma_wr_dt_req_prog_full) begin
                                                dma_wr_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_WR},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr2, virt_addr_offset0};
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b11: begin
                                            if (!dma_wr_dt_req_prog_full) begin
                                                dma_wr_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_WR},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr3, virt_addr_offset0};
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Modify*/
                                end
                                default: begin
                                    dma_rd_dt_req_din <= `TD 134'b0;
                                    dma_wr_dt_req_din <= `TD 134'b0;
                                    dma_rd_wqe_req_din <= `TD 134'b0;
                                end
                            endcase
                        end
                        3'b010: begin
                            case (qv_left_dma_req_from_cache)
                                3'b001: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_wr_dt_req_prog_full) begin
                                                dma_wr_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_WR},qv_get_mpt_req[197:195],byte_length1,dma_req_page_addr1, virt_addr_offset1};
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b01: begin
                                            if (!dma_wr_dt_req_prog_full) begin
                                                dma_wr_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_WR},qv_get_mpt_req[197:195],byte_length1,dma_req_page_addr2, virt_addr_offset1};
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b10: begin
                                            if (!dma_wr_dt_req_prog_full) begin
                                                dma_wr_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_WR},qv_get_mpt_req[197:195],byte_length1,dma_req_page_addr3, virt_addr_offset1};
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/
                                    // if (!dma_wr_dt_req_prog_full) begin
                                    //     dma_wr_dt_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_WR_FIRST : `DATA_WR),qv_get_mpt_req[164:162],byte_length0,dma_req_page_addr0,virt_addr_offset0};
                                    //     dma_rd_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_dt_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                3'b010: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_wr_dt_req_prog_full) begin
                                                dma_wr_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_WR},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr0, virt_addr_offset0};
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b01: begin
                                            if (!dma_wr_dt_req_prog_full) begin
                                                dma_wr_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_WR},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr1, virt_addr_offset0};
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b10: begin
                                            if (!dma_wr_dt_req_prog_full) begin
                                                dma_wr_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_WR},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr2, virt_addr_offset0};
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/                                    
                                    // if (!dma_wr_dt_req_prog_full) begin
                                    //     dma_rd_dt_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_WR_FIRST : `DATA_WR),qv_get_mpt_req[164:162],byte_length1,dma_req_page_addr1,virt_addr_offset1};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_dt_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                default: begin
                                    dma_rd_dt_req_din <= `TD 134'b0;
                                    dma_wr_dt_req_din <= `TD 134'b0;
                                    dma_rd_wqe_req_din <= `TD 134'b0;
                                end
                            endcase
                        end
                        3'b011: begin
                            case (qv_left_dma_req_from_cache)
                                3'b001: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_wr_dt_req_prog_full) begin
                                                dma_wr_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_WR},qv_get_mpt_req[197:195],byte_length2,dma_req_page_addr2, virt_addr_offset2};
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b01: begin
                                            if (!dma_wr_dt_req_prog_full) begin
                                                dma_wr_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_WR},qv_get_mpt_req[197:195],byte_length2,dma_req_page_addr3, virt_addr_offset2};
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/                                    
                                    // if (!dma_wr_dt_req_prog_full) begin
                                    //     dma_rd_dt_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_WR_FIRST : `DATA_WR),qv_get_mpt_req[164:162],byte_length0,dma_req_page_addr0,virt_addr_offset0};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_dt_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                3'b010: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_wr_dt_req_prog_full) begin
                                                dma_wr_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_WR},qv_get_mpt_req[197:195],byte_length1,dma_req_page_addr1, virt_addr_offset1};
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b01: begin
                                            if (!dma_wr_dt_req_prog_full) begin
                                                dma_wr_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_WR},qv_get_mpt_req[197:195],byte_length1,dma_req_page_addr2, virt_addr_offset1};
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                            dma_rd_dt_req_din <= `TD 134'b0;
                                            dma_wr_dt_req_din <= `TD 134'b0;
                                            dma_rd_wqe_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/ 
                                    // if (!dma_wr_dt_req_prog_full) begin
                                    //     dma_rd_dt_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_WR_FIRST : `DATA_WR),qv_get_mpt_req[164:162],byte_length1,dma_req_page_addr1,virt_addr_offset1};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_dt_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                3'b011: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_wr_dt_req_prog_full) begin
                                                dma_wr_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_WR},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr0, virt_addr_offset0};
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b01: begin
                                            if (!dma_wr_dt_req_prog_full) begin
                                                dma_wr_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_WR},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr1, virt_addr_offset0};
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                            dma_rd_dt_req_din <= `TD 134'b0;
                                            dma_wr_dt_req_din <= `TD 134'b0;
                                            dma_rd_wqe_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/
                                    // if (!dma_wr_dt_req_prog_full) begin
                                    //     dma_rd_dt_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_WR_FIRST : `DATA_WR),qv_get_mpt_req[164:162],byte_length2,dma_req_page_addr2,virt_addr_offset2};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_dt_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                default: begin
                                    dma_rd_dt_req_din <= `TD 134'b0;
                                    dma_wr_dt_req_din <= `TD 134'b0;
                                    dma_rd_wqe_req_din <= `TD 134'b0;
                                end
                            endcase
                        end
                        3'b100: begin
                            case (qv_left_dma_req_from_cache)
                                3'b001: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_wr_dt_req_prog_full) begin
                                                dma_wr_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_WR},qv_get_mpt_req[197:195],byte_length3,dma_req_page_addr3, virt_addr_offset3};
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/                                        
                                    // if (!dma_wr_dt_req_prog_full) begin
                                    //     dma_rd_dt_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_WR_FIRST : `DATA_WR),qv_get_mpt_req[164:162],byte_length0,dma_req_page_addr0,virt_addr_offset0};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_dt_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                3'b010: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_wr_dt_req_prog_full) begin
                                                dma_wr_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_WR},qv_get_mpt_req[197:195],byte_length2,dma_req_page_addr2, virt_addr_offset2};
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/                                     
                                    // if (!dma_wr_dt_req_prog_full) begin
                                    //     dma_rd_dt_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_WR_FIRST : `DATA_WR),qv_get_mpt_req[164:162],byte_length1,dma_req_page_addr1,virt_addr_offset1};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_dt_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                3'b011: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_wr_dt_req_prog_full) begin
                                                dma_wr_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_WR},qv_get_mpt_req[197:195],byte_length1,dma_req_page_addr1, virt_addr_offset1};
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/    
                                    // if (!dma_wr_dt_req_prog_full) begin
                                    //     dma_rd_dt_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_WR_FIRST : `DATA_WR),qv_get_mpt_req[164:162],byte_length2,dma_req_page_addr2,virt_addr_offset2};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_dt_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                3'b100: begin                                    
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_wr_dt_req_prog_full) begin
                                                dma_wr_dt_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_WR},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr0, virt_addr_offset0};
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/    
                                    // if (!dma_wr_dt_req_prog_full) begin
                                    //     dma_rd_dt_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_WR_FIRST : `DATA_WR),qv_get_mpt_req[164:162],byte_length3,dma_req_page_addr3,virt_addr_offset3};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_dt_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                default: begin
                                    dma_rd_dt_req_din <= `TD 134'b0;
                                    dma_wr_dt_req_din <= `TD 134'b0;
                                    dma_rd_wqe_req_din <= `TD 134'b0;
                                end
                            endcase
                        end
                        default: begin
                            dma_rd_dt_req_din <= `TD 134'b0;
                            dma_wr_dt_req_din <= `TD 134'b0;
                            dma_rd_wqe_req_din <= `TD 134'b0;
                        end
                    endcase                           
                    end                
                end
                3'b100: begin
                    case (qv_mtt_num_in_cacheline)
                        3'b001: begin
                            case (qv_left_dma_req_from_cache)
                                3'b001: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_rd_wqe_req_prog_full) begin
                                                // dma_rd_dt_req_din <= `TD {qv_get_mpt_req[31:0],((((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ? `DATA_RD_FIRST : `DATA_RD),qv_get_mpt_req[164:162],byte_length0,dma_req_page_addr0, virt_addr_offset0};
                                                dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr0, virt_addr_offset0};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b01: begin
                                            if (!dma_rd_wqe_req_prog_full) begin
                                                dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr1, virt_addr_offset0};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b10: begin
                                            if (!dma_rd_wqe_req_prog_full) begin
                                                dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr2, virt_addr_offset0};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b11: begin
                                            if (!dma_rd_wqe_req_prog_full) begin
                                                dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr3, virt_addr_offset0};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Modify*/
                                end
                                default: begin
                                    dma_rd_wqe_req_din <= `TD 134'b0;
                                    dma_wr_dt_req_din <= `TD 134'b0;
                                    dma_rd_dt_req_din <= `TD 134'b0;
                                end
                            endcase
                        end
                        3'b010: begin
                            case (qv_left_dma_req_from_cache)
                                3'b001: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_rd_wqe_req_prog_full) begin
                                                dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length1,dma_req_page_addr1, virt_addr_offset1};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b01: begin
                                            if (!dma_rd_wqe_req_prog_full) begin
                                                dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length1,dma_req_page_addr2, virt_addr_offset1};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b10: begin
                                            if (!dma_rd_wqe_req_prog_full) begin
                                                dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length1,dma_req_page_addr3, virt_addr_offset1};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/
                                    // if (!dma_rd_wqe_req_prog_full) begin
                                    //     dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_RD_FIRST : `DATA_RD),qv_get_mpt_req[164:162],byte_length0,dma_req_page_addr0,virt_addr_offset0};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_wqe_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                3'b010: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_rd_wqe_req_prog_full) begin
                                                dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr0, virt_addr_offset0};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b01: begin
                                            if (!dma_rd_wqe_req_prog_full) begin
                                                dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr1, virt_addr_offset0};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b10: begin
                                            if (!dma_rd_wqe_req_prog_full) begin
                                                dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr2, virt_addr_offset0};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/                                    
                                    // if (!dma_rd_wqe_req_prog_full) begin
                                    //     dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_RD_FIRST : `DATA_RD),qv_get_mpt_req[164:162],byte_length1,dma_req_page_addr1,virt_addr_offset1};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_wqe_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                default: begin
                                    dma_rd_wqe_req_din <= `TD 134'b0;
                                    dma_wr_dt_req_din <= `TD 134'b0;
                                    dma_rd_dt_req_din <= `TD 134'b0;
                                end
                            endcase
                        end
                        3'b011: begin
                            case (qv_left_dma_req_from_cache)
                                3'b001: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_rd_wqe_req_prog_full) begin
                                                dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length2,dma_req_page_addr2, virt_addr_offset2};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b01: begin
                                            if (!dma_rd_wqe_req_prog_full) begin
                                                dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length2,dma_req_page_addr3, virt_addr_offset2};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/                                    
                                    // if (!dma_rd_wqe_req_prog_full) begin
                                    //     dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_RD_FIRST : `DATA_RD),qv_get_mpt_req[164:162],byte_length0,dma_req_page_addr0,virt_addr_offset0};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_wqe_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                3'b010: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_rd_wqe_req_prog_full) begin
                                                dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length1,dma_req_page_addr1, virt_addr_offset1};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b01: begin
                                            if (!dma_rd_wqe_req_prog_full) begin
                                                dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length1,dma_req_page_addr2, virt_addr_offset1};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                            dma_rd_wqe_req_din <= `TD 134'b0;
                                            dma_wr_dt_req_din <= `TD 134'b0;
                                            dma_rd_dt_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/ 
                                    // if (!dma_rd_wqe_req_prog_full) begin
                                    //     dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_RD_FIRST : `DATA_RD),qv_get_mpt_req[164:162],byte_length1,dma_req_page_addr1,virt_addr_offset1};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_wqe_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                3'b011: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_rd_wqe_req_prog_full) begin
                                                dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr0, virt_addr_offset0};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end
                                        end
                                        2'b01: begin
                                            if (!dma_rd_wqe_req_prog_full) begin
                                                dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr1, virt_addr_offset0};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                            dma_rd_wqe_req_din <= `TD 134'b0;
                                            dma_wr_dt_req_din <= `TD 134'b0;
                                            dma_rd_dt_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/
                                    // if (!dma_rd_wqe_req_prog_full) begin
                                    //     dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_RD_FIRST : `DATA_RD),qv_get_mpt_req[164:162],byte_length2,dma_req_page_addr2,virt_addr_offset2};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_wqe_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                default: begin
                                    dma_rd_wqe_req_din <= `TD 134'b0;
                                    dma_wr_dt_req_din <= `TD 134'b0;
                                    dma_rd_dt_req_din <= `TD 134'b0;
                                end
                            endcase
                        end
                        3'b100: begin
                            case (qv_left_dma_req_from_cache)
                                3'b001: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_rd_wqe_req_prog_full) begin
                                                dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length3,dma_req_page_addr3, virt_addr_offset3};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/                                        
                                    // if (!dma_rd_wqe_req_prog_full) begin
                                    //     dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_RD_FIRST : `DATA_RD),qv_get_mpt_req[164:162],byte_length0,dma_req_page_addr0,virt_addr_offset0};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_wqe_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                3'b010: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_rd_wqe_req_prog_full) begin
                                                dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length2,dma_req_page_addr2, virt_addr_offset2};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/                                     
                                    // if (!dma_rd_wqe_req_prog_full) begin
                                    //     dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_RD_FIRST : `DATA_RD),qv_get_mpt_req[164:162],byte_length1,dma_req_page_addr1,virt_addr_offset1};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_wqe_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                3'b011: begin
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_rd_wqe_req_prog_full) begin
                                                dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length1,dma_req_page_addr1, virt_addr_offset1};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/    
                                    // if (!dma_rd_wqe_req_prog_full) begin
                                    //     dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_RD_FIRST : `DATA_RD),qv_get_mpt_req[164:162],byte_length2,dma_req_page_addr2,virt_addr_offset2};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_wqe_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                3'b100: begin                                    
                                    /*VCS Verification*/
                                    case (qv_mpt_req_mtt_addr[OFFSET-1:0])
                                        2'b00: begin
                                            if (!dma_rd_wqe_req_prog_full) begin
                                                dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[194:163],{(qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline) ? qv_get_mpt_req[162:160] : `DATA_RD},qv_get_mpt_req[197:195],byte_length0,dma_req_page_addr0, virt_addr_offset0};
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end else begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                            end
                                        end
                                        default: begin
                                                dma_rd_wqe_req_din <= `TD 134'b0;
                                                dma_wr_dt_req_din <= `TD 134'b0;
                                                dma_rd_dt_req_din <= `TD 134'b0;
                                        end
                                    endcase
                                    /*Action = Add*/    
                                    // if (!dma_rd_wqe_req_prog_full) begin
                                    //     dma_rd_wqe_req_din <= `TD {qv_get_mpt_req[31:0],(((qv_left_mtt_entry_num == total_mtt_entry_num) && (qv_left_dma_req_from_cache == qv_mtt_num_in_cacheline)) ?`DATA_RD_FIRST : `DATA_RD),qv_get_mpt_req[164:162],byte_length3,dma_req_page_addr3,virt_addr_offset3};
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end else begin
                                    //     dma_rd_wqe_req_din <= `TD 134'b0;
                                    //     dma_wr_dt_req_din <= `TD 134'b0;
                                    // end
                                end
                                default: begin
                                    dma_rd_wqe_req_din <= `TD 134'b0;
                                    dma_wr_dt_req_din <= `TD 134'b0;
                                    dma_rd_dt_req_din <= `TD 134'b0;
                                end
                            endcase
                        end
                        default: begin
                            dma_rd_wqe_req_din <= `TD 134'b0;
                            dma_wr_dt_req_din <= `TD 134'b0;
                            dma_rd_dt_req_din <= `TD 134'b0;
                        end
                    endcase
                end
                default: begin
                    dma_rd_wqe_req_din <= `TD 134'b0;
                    dma_wr_dt_req_din <= `TD 134'b0;
                    dma_rd_dt_req_din <= `TD 134'b0;
                end
            endcase
            /*Action = Modify, byte_length0-3 and virt_addr_offset0-3 are correspond to the suquence num of payload, but physical addr0-3 correspond to the mtt entry num in cacheline*/
        end
        else begin
            dma_rd_wqe_req_din <= `TD 134'b0;
            dma_wr_dt_req_din <= `TD 134'b0;
            dma_rd_wqe_req_din <= `TD 134'b0;
        end
    end

    //TODO:
    //mtt_ram_ctl block signal for 3 req fifo processing block 
        //| bit 2 read WQE | bit 1 write data | bit 0 read data |
        // output reg [2:0]   block_valid,
        // output reg [197:0] rd_wqe_block_info,
        // output reg [197:0] wr_data_block_info,
        // output reg [197:0] rd_data_block_info,
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            block_valid <= `TD 3'b0;
            rd_wqe_block_info <= `TD 198'b0;
            wr_data_block_info <= `TD 198'b0;
            rd_data_block_info <= `TD 198'b0;
        end else begin
            case (mpt_req_fsm_cs)
                INIT_LOOKUP: begin
                    case ({is_rd_wqe,is_wr_data,is_rd_data})
                        3'b001: begin
                            if (dma_rd_dt_req_prog_full) begin
                                block_valid <= `TD 3'b001;
                                rd_wqe_block_info <= `TD 198'b0;
                                wr_data_block_info <= `TD 198'b0;
                                rd_data_block_info <= `TD qv_get_mpt_req;
                            end else begin
                                block_valid <= `TD 3'b0;
                                rd_wqe_block_info <= `TD 198'b0;
                                wr_data_block_info <= `TD 198'b0;
                                rd_data_block_info <= `TD 198'b0;    
                            end
                        end
                        3'b010: begin
                            if (dma_wr_dt_req_prog_full) begin
                                block_valid <= `TD 3'b010;
                                rd_wqe_block_info <= `TD 198'b0;
                                wr_data_block_info <= `TD qv_get_mpt_req;
                                rd_data_block_info <= `TD 198'b0;
                            end else begin
                                block_valid <= `TD 3'b0;
                                rd_wqe_block_info <= `TD 198'b0;
                                wr_data_block_info <= `TD 198'b0;
                                rd_data_block_info <= `TD 198'b0;    
                            end
                        end
                        3'b100: begin
                            if (dma_rd_wqe_req_prog_full) begin
                                block_valid <= `TD 3'b100;
                                rd_wqe_block_info <= `TD qv_get_mpt_req;
                                wr_data_block_info <= `TD 198'b0;
                                rd_data_block_info <= `TD 198'b0;
                            end else begin
                                block_valid <= `TD 3'b0;
                                rd_wqe_block_info <= `TD 198'b0;
                                wr_data_block_info <= `TD 198'b0;
                                rd_data_block_info <= `TD 198'b0;    
                            end
                        end
                        default:  begin
                            block_valid <= `TD 3'b0;
                            rd_wqe_block_info <= `TD 198'b0;
                            wr_data_block_info <= `TD 198'b0;
                            rd_data_block_info <= `TD 198'b0;    
                        end
                    endcase
                end
                LOOKUP_RESULT_PROC: begin
                    //TODO:
                    case ({is_rd_wqe,is_wr_data,is_rd_data})
                        3'b001: begin
                            if (dma_rd_dt_req_prog_full && (state_valid | q_result_valid)) begin
                                case (qv_mtt_num_in_cacheline)
                                    3'b001: begin
                                        case (qv_left_dma_req_from_cache)
                                            3'b001: begin
                                                block_valid <= `TD 3'b001;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD qv_get_mpt_req;
                                            end
                                            default: begin
                                                block_valid <= `TD 3'b000;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                        endcase
                                    end
                                    3'b010:  begin
                                        case (qv_left_dma_req_from_cache)
                                            3'b001: begin
                                                block_valid <= `TD 3'b001;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD {qv_get_mpt_req[197:163],`DATA_RD,(qv_mpt_req_mtt_addr+64'b1),{qv_fisrt_mtt_vaddr[63:12],12'b0},(qv_left_mtt_Blen-byte_length0)};
                                            end
                                            3'b010: begin
                                                block_valid <= `TD 3'b001;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD qv_get_mpt_req;
                                            end
                                            default: begin
                                                block_valid <= `TD 3'b000;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                        endcase
                                    end
                                    3'b011: begin
                                        case (qv_left_dma_req_from_cache)
                                            3'b001: begin
                                                block_valid <= `TD 3'b001;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD {qv_get_mpt_req[197:163],`DATA_RD,(qv_mpt_req_mtt_addr+64'b10),{qv_fisrt_mtt_vaddr[63:12],12'b0},(qv_left_mtt_Blen-byte_length0-byte_length1)};
                                            end
                                            3'b010: begin
                                                block_valid <= `TD 3'b001;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD {qv_get_mpt_req[197:163],`DATA_RD,(qv_mpt_req_mtt_addr+64'b1),{qv_fisrt_mtt_vaddr[63:12],12'b0},(qv_left_mtt_Blen-byte_length0)};
                                            end
                                            3'b011: begin
                                                block_valid <= `TD 3'b001;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD qv_get_mpt_req;
                                            end
                                            default: begin
                                                block_valid <= `TD 3'b000;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                        endcase
                                    end
                                    3'b100: begin
                                        case (qv_left_dma_req_from_cache)
                                            3'b001: begin
                                                block_valid <= `TD 3'b001;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD {qv_get_mpt_req[197:163],`DATA_RD,(qv_mpt_req_mtt_addr+64'b11),{qv_fisrt_mtt_vaddr[63:12],12'b0},(qv_left_mtt_Blen-byte_length0-byte_length1-byte_length2)};
                                            end
                                            3'b010: begin
                                                block_valid <= `TD 3'b001;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD {qv_get_mpt_req[197:163],`DATA_RD,(qv_mpt_req_mtt_addr+64'b10),{qv_fisrt_mtt_vaddr[63:12],12'b0},(qv_left_mtt_Blen-byte_length0-byte_length1)};
                                            end
                                            3'b011: begin
                                                block_valid <= `TD 3'b001;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD {qv_get_mpt_req[197:163],`DATA_RD,(qv_mpt_req_mtt_addr+64'b1),{qv_fisrt_mtt_vaddr[63:12],12'b0},(qv_left_mtt_Blen-byte_length0)};
                                            end
                                            3'b100: begin                                    
                                                block_valid <= `TD 3'b001;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD qv_get_mpt_req;
                                            end
                                            default: begin
                                                block_valid <= `TD 3'b000;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                        endcase
                                    end
                                    default: begin
                                        block_valid <= `TD 3'b000;
                                        rd_wqe_block_info <= `TD 198'b0;
                                        wr_data_block_info <= `TD 198'b0;
                                        rd_data_block_info <= `TD 198'b0;
                                    end
                                endcase
                            end else begin
                                block_valid <= `TD 3'b000;
                                rd_wqe_block_info <= `TD 198'b0;
                                wr_data_block_info <= `TD 198'b0;
                                rd_data_block_info <= `TD 198'b0;    
                            end
                        end
                        3'b010: begin
                            if (dma_wr_dt_req_prog_full && (state_valid | q_result_valid)) begin
                                case (qv_mtt_num_in_cacheline)
                                    3'b001: begin
                                        case (qv_left_dma_req_from_cache)
                                            3'b001: begin
                                                block_valid <= `TD 3'b010;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD qv_get_mpt_req;
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                            default: begin
                                                block_valid <= `TD 3'b000;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                        endcase
                                    end
                                    3'b010:  begin
                                        case (qv_left_dma_req_from_cache)
                                            3'b001: begin
                                                block_valid <= `TD 3'b010;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD {qv_get_mpt_req[197:163],`DATA_WR,(qv_mpt_req_mtt_addr+64'b1),{qv_fisrt_mtt_vaddr[63:12],12'b0},(qv_left_mtt_Blen-byte_length0)};
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                            3'b010: begin
                                                block_valid <= `TD 3'b010;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD qv_get_mpt_req;
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                            default: begin
                                                block_valid <= `TD 3'b000;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                        endcase
                                    end
                                    3'b011: begin
                                        case (qv_left_dma_req_from_cache)
                                            3'b001: begin
                                                block_valid <= `TD 3'b010;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD {qv_get_mpt_req[197:163],`DATA_WR,(qv_mpt_req_mtt_addr+64'b10),{qv_fisrt_mtt_vaddr[63:12],12'b0},(qv_left_mtt_Blen-byte_length0-byte_length1)};
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                            3'b010: begin
                                                block_valid <= `TD 3'b010;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD {qv_get_mpt_req[197:163],`DATA_WR,(qv_mpt_req_mtt_addr+64'b1),{qv_fisrt_mtt_vaddr[63:12],12'b0},(qv_left_mtt_Blen-byte_length0)};
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                            3'b011: begin
                                                block_valid <= `TD 3'b010;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD qv_get_mpt_req;
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                            default: begin
                                                block_valid <= `TD 3'b000;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                        endcase
                                    end
                                    3'b100: begin
                                        case (qv_left_dma_req_from_cache)
                                            3'b001: begin
                                                block_valid <= `TD 3'b010;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD {qv_get_mpt_req[197:163],`DATA_WR,(qv_mpt_req_mtt_addr+64'b11),{qv_fisrt_mtt_vaddr[63:12],12'b0},(qv_left_mtt_Blen-byte_length0-byte_length1-byte_length2)};
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                            3'b010: begin
                                                block_valid <= `TD 3'b010;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD {qv_get_mpt_req[197:163],`DATA_WR,(qv_mpt_req_mtt_addr+64'b10),{qv_fisrt_mtt_vaddr[63:12],12'b0},(qv_left_mtt_Blen-byte_length0-byte_length1)};
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                            3'b011: begin
                                                block_valid <= `TD 3'b010;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD {qv_get_mpt_req[197:163],`DATA_WR,(qv_mpt_req_mtt_addr+64'b1),{qv_fisrt_mtt_vaddr[63:12],12'b0},(qv_left_mtt_Blen-byte_length0)};
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                            3'b100: begin                                    
                                                block_valid <= `TD 3'b010;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD qv_get_mpt_req;
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                            default: begin
                                                block_valid <= `TD 3'b000;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                        endcase
                                    end
                                    default: begin
                                        block_valid <= `TD 3'b000;
                                        rd_wqe_block_info <= `TD 198'b0;
                                        wr_data_block_info <= `TD 198'b0;
                                        rd_data_block_info <= `TD 198'b0;
                                    end
                                endcase
                            end else begin
                                block_valid <= `TD 3'b0;
                                rd_wqe_block_info <= `TD 198'b0;
                                wr_data_block_info <= `TD 198'b0;
                                rd_data_block_info <= `TD 198'b0;    
                            end
                        end
                        3'b100: begin
                            if (dma_rd_wqe_req_prog_full && (state_valid | q_result_valid)) begin
                                case (qv_mtt_num_in_cacheline)
                                    3'b001: begin
                                        case (qv_left_dma_req_from_cache)
                                            3'b001: begin
                                                block_valid <= `TD 3'b100;
                                                rd_wqe_block_info <= `TD qv_get_mpt_req;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                            default: begin
                                                block_valid <= `TD 3'b000;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                        endcase
                                    end
                                    3'b010:  begin
                                        case (qv_left_dma_req_from_cache)
                                            3'b001: begin
                                                block_valid <= `TD 3'b100;
                                                rd_data_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_wqe_block_info <= `TD {qv_get_mpt_req[197:163],`DATA_RD,(qv_mpt_req_mtt_addr+64'b1),{qv_fisrt_mtt_vaddr[63:12],12'b0},(qv_left_mtt_Blen-byte_length0)};
                                            end
                                            3'b010: begin
                                                block_valid <= `TD 3'b100;
                                                rd_wqe_block_info <= `TD qv_get_mpt_req;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                            default: begin
                                                block_valid <= `TD 3'b000;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                        endcase
                                    end
                                    3'b011: begin
                                        case (qv_left_dma_req_from_cache)
                                            3'b001: begin
                                                block_valid <= `TD 3'b100;
                                                rd_data_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_wqe_block_info <= `TD {qv_get_mpt_req[197:163],`DATA_RD,(qv_mpt_req_mtt_addr+64'b10),{qv_fisrt_mtt_vaddr[63:12],12'b0},(qv_left_mtt_Blen-byte_length0-byte_length1)};
                                            end
                                            3'b010: begin
                                                block_valid <= `TD 3'b100;
                                                rd_data_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_wqe_block_info <= `TD {qv_get_mpt_req[197:163],`DATA_RD,(qv_mpt_req_mtt_addr+64'b1),{qv_fisrt_mtt_vaddr[63:12],12'b0},(qv_left_mtt_Blen-byte_length0)};
                                            end
                                            3'b011: begin
                                                block_valid <= `TD 3'b100;
                                                rd_wqe_block_info <= `TD qv_get_mpt_req;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                            default: begin
                                                block_valid <= `TD 3'b000;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                        endcase
                                    end
                                    3'b100: begin
                                        case (qv_left_dma_req_from_cache)
                                            3'b001: begin
                                                block_valid <= `TD 3'b100;
                                                rd_data_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_wqe_block_info <= `TD {qv_get_mpt_req[197:163],`DATA_RD,(qv_mpt_req_mtt_addr+64'b11),{qv_fisrt_mtt_vaddr[63:12],12'b0},(qv_left_mtt_Blen-byte_length0-byte_length1-byte_length2)};
                                            end
                                            3'b010: begin
                                                block_valid <= `TD 3'b100;
                                                rd_data_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_wqe_block_info <= `TD {qv_get_mpt_req[197:163],`DATA_RD,(qv_mpt_req_mtt_addr+64'b10),{qv_fisrt_mtt_vaddr[63:12],12'b0},(qv_left_mtt_Blen-byte_length0-byte_length1)};
                                            end
                                            3'b011: begin
                                                block_valid <= `TD 3'b100;
                                                rd_data_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_wqe_block_info <= `TD {qv_get_mpt_req[197:163],`DATA_RD,(qv_mpt_req_mtt_addr+64'b1),{qv_fisrt_mtt_vaddr[63:12],12'b0},(qv_left_mtt_Blen-byte_length0)};
                                            end
                                            3'b100: begin                                    
                                                block_valid <= `TD 3'b100;
                                                rd_wqe_block_info <= `TD qv_get_mpt_req;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                            default: begin
                                                block_valid <= `TD 3'b000;
                                                rd_wqe_block_info <= `TD 198'b0;
                                                wr_data_block_info <= `TD 198'b0;
                                                rd_data_block_info <= `TD 198'b0;
                                            end
                                        endcase
                                    end
                                    default: begin
                                        block_valid <= `TD 3'b000;
                                        rd_wqe_block_info <= `TD 198'b0;
                                        wr_data_block_info <= `TD 198'b0;
                                        rd_data_block_info <= `TD 198'b0;
                                    end
                                endcase
                            end else begin
                                block_valid <= `TD 3'b0;
                                rd_wqe_block_info <= `TD 198'b0;
                                wr_data_block_info <= `TD 198'b0;
                                rd_data_block_info <= `TD 198'b0;    
                            end
                        end
                        default:  begin
                            block_valid <= `TD 3'b0;
                            rd_wqe_block_info <= `TD 198'b0;
                            wr_data_block_info <= `TD 198'b0;
                            rd_data_block_info <= `TD 198'b0;    
                        end
                    endcase
                end
                default: begin
                    block_valid <= `TD 3'b0;
                    rd_wqe_block_info <= `TD 198'b0;
                    wr_data_block_info <= `TD 198'b0;
                    rd_data_block_info <= `TD 198'b0;
                end
            endcase
        end
    end
//-----------------{mpt req processing state mechine} end--------------------//


//-----------------{two state mechines both write signal} begin--------------------//

//---------------------------mtt_ram--------------------------
    // consider the mpt and ceu req processing state mechine initiate the mtt_ram lookup req
    //   //lookup info 
    //   input  wire                     lookup_allow_in,
    //   output reg                      lookup_rden,
    //   output reg                      lookup_wren,
    //   output reg  [LINE_SIZE*8-1:0]   lookup_wdata,
    //       //lookup info addr={(64-INDEX-TAG-OFFSET)'b0,lookup_tag,lookup_index,lookup_offset}
    //   output reg  [INDEX -1     :0]   lookup_index,
    //   output reg  [TAG -1       :0]   lookup_tag,
    //   output reg  [OFFSET - 1   :0]   lookup_offset,
    //   output reg  [NUM - 1      :0]   lookup_num,
    //   output wire                     lookup_stall,
    /*Spyglass*/
    assign lookup_stall = 1'b0;
    /*Action = Add*/
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            lookup_rden <= `TD 0;
            lookup_wren <= `TD 0;
            lookup_wdata <= `TD 0;
            lookup_index <= `TD 0;
            lookup_tag <= `TD 0;
            lookup_offset <= `TD 0;
            lookup_num <= `TD 0;
            //TODO: add eq fucntion
            mtt_eq_addr <= `TD 0;
        end 
        //the ceu req processing state mechine initiate the mtt_ram lookup req
        /*VCS  Verification*/
        // else if ((ceu_req_fsm_cs == CEU_REQ_PROC) && ((((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] > 4) | ((qv_left_ceu_req_mtt_num +  qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num > 4))) && !mtt_data_empty) | ((qv_left_ceu_req_mtt_num +  qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4))) && lookup_allow_in) begin
        else if ((ceu_req_fsm_cs == CEU_REQ_PROC) && ((((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] > 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num > 4) && !mtt_data_empty) | ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] > 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4)) | ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num > 4) && !mtt_data_empty) | ((qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] <= 4) && (qv_left_payload_offset + qv_left_ceu_req_mtt_num <= 4)))) && lookup_allow_in && (state_valid | (!state_valid & (lookup_state == 3'b1))) && !(lookup_rden | lookup_wren)) begin
            /*Action = Modify, add state_valid as req enable condition, add !rd_en & !wren to insert at least 1 clk between 2 req */            
            case (qv_left_payload_offset)
                2'b00:begin
                    if (qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] > 4) begin
                        case (qv_ceu_req_mtt_addr[1:0])
                            2'b00: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {qv_get_ceu_payload};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                           
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD 4;
                            end 
                            2'b01: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {qv_get_ceu_payload[3*64-1:0*64],64'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD 3;
                            end 
                            2'b10: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {qv_get_ceu_payload[2*64-1:0*64],128'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD 2;
                            end 
                            2'b11: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {qv_get_ceu_payload[1*64-1:0*64],192'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD 1;
                            end 
                            default: begin
                                lookup_rden <= `TD 0;
                                lookup_wren <= `TD 0;
                                lookup_wdata <= `TD 0;
                                lookup_index <= `TD 0;
                                lookup_tag <= `TD 0;
                                lookup_offset <= `TD 0;
                                lookup_num <= `TD 0;                            
                            end
                        endcase
                    end else begin
                        case (qv_ceu_req_mtt_addr[1:0])
                            2'b00: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {qv_get_ceu_payload};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                           
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD qv_left_ceu_req_mtt_num[NUM-1:0];
                            end 
                            2'b01: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {qv_get_ceu_payload[3*64:0*64],64'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD qv_left_ceu_req_mtt_num[NUM-1:0];
                            end 
                            2'b10: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {qv_get_ceu_payload[2*64:0*64],128'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD qv_left_ceu_req_mtt_num[NUM-1:0];
                            end 
                            2'b11: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {qv_get_ceu_payload[1*64:0*64],192'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD qv_left_ceu_req_mtt_num[NUM-1:0];
                            end 
                            default: begin
                                lookup_rden <= `TD 0;
                                lookup_wren <= `TD 0;
                                lookup_wdata <= `TD 0;
                                lookup_index <= `TD 0;
                                lookup_tag <= `TD 0;
                                lookup_offset <= `TD 0;
                                lookup_num <= `TD 0;                            
                            end
                        endcase                
                    end
                end 
                2'b01:begin
                    if (qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] > 4) begin
                        case (qv_ceu_req_mtt_addr[1:0])
                            2'b00: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {mtt_data_dout[1*64-1:0*64],qv_get_ceu_payload[4*64-1:1*64]};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                           
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD 4;
                            end 
                            2'b01: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {qv_get_ceu_payload[4*64-1:1*64],64'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD 3;
                            end 
                            2'b10: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {qv_get_ceu_payload[3*64-1:1*64],128'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD 2;
                            end 
                            2'b11: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {qv_get_ceu_payload[2*64-1:1*64],192'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD 1;
                            end 
                            default: begin
                                lookup_rden <= `TD 0;
                                lookup_wren <= `TD 0;
                                lookup_wdata <= `TD 0;
                                lookup_index <= `TD 0;
                                lookup_tag <= `TD 0;
                                lookup_offset <= `TD 0;
                                lookup_num <= `TD 0;                            
                            end
                        endcase
                    end else begin
                        case (qv_ceu_req_mtt_addr[1:0])
                            2'b00: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {mtt_data_dout[1*64-1:0*64],qv_get_ceu_payload[4*64-1:1*64]};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                           
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD qv_left_ceu_req_mtt_num;
                            end 
                            2'b01: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {qv_get_ceu_payload[4*64-1:1*64],64'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD qv_left_ceu_req_mtt_num;
                            end 
                            2'b10: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {qv_get_ceu_payload[3*64-1:1*64],128'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD qv_left_ceu_req_mtt_num;
                            end 
                            2'b11: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {qv_get_ceu_payload[2*64-1:1*64],192'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD qv_left_ceu_req_mtt_num;
                            end 
                            default: begin
                                lookup_rden <= `TD 0;
                                lookup_wren <= `TD 0;
                                lookup_wdata <= `TD 0;
                                lookup_index <= `TD 0;
                                lookup_tag <= `TD 0;
                                lookup_offset <= `TD 0;
                                lookup_num <= `TD 0;                            
                            end
                        endcase                            
                    end
                end
                2'b10:begin
                    if (qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] > 4) begin
                        case (qv_ceu_req_mtt_addr[1:0])
                            2'b00: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {mtt_data_dout[2*64-1:0*64],qv_get_ceu_payload[4*64-1:2*64]};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                           
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD 4;
                            end 
                            2'b01: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {mtt_data_dout[1*64-1:0*64],qv_get_ceu_payload[4*64-1:2*64],64'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD 3;
                            end 
                            2'b10: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {qv_get_ceu_payload[4*64-1:2*64],128'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD 2;
                            end 
                            2'b11: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {qv_get_ceu_payload[3*64-1:2*64],192'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD 1;
                            end 
                            default: begin
                                lookup_rden <= `TD 0;
                                lookup_wren <= `TD 0;
                                lookup_wdata <= `TD 0;
                                lookup_index <= `TD 0;
                                lookup_tag <= `TD 0;
                                lookup_offset <= `TD 0;
                                lookup_num <= `TD 0;                            
                            end
                        endcase
                    end else begin
                        case (qv_ceu_req_mtt_addr[1:0])
                            2'b00: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {mtt_data_dout[2*64-1:0*64],qv_get_ceu_payload[4*64-1:2*64]};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                           
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD qv_left_ceu_req_mtt_num;
                            end 
                            2'b01: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {mtt_data_dout[1*64-1:0*64],qv_get_ceu_payload[4*64-1:2*64],64'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD qv_left_ceu_req_mtt_num;
                            end 
                            2'b10: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {qv_get_ceu_payload[4*64-1:2*64],128'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD qv_left_ceu_req_mtt_num;
                            end 
                            2'b11: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {qv_get_ceu_payload[3*64-1:2*64],192'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD qv_left_ceu_req_mtt_num;
                            end 
                            default: begin
                                lookup_rden <= `TD 0;
                                lookup_wren <= `TD 0;
                                lookup_wdata <= `TD 0;
                                lookup_index <= `TD 0;
                                lookup_tag <= `TD 0;
                                lookup_offset <= `TD 0;
                                lookup_num <= `TD 0;                            
                            end
                        endcase                            
                    end
                end
                2'b11:begin
                    if (qv_left_ceu_req_mtt_num + qv_ceu_req_mtt_addr[1:0] > 4) begin
                        case (qv_ceu_req_mtt_addr[1:0])
                            2'b00: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {mtt_data_dout[3*64-1:0*64],qv_get_ceu_payload[4*64-1:3*64]};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                           
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD 4;
                            end 
                            2'b01: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {mtt_data_dout[2*64-1:0*64],qv_get_ceu_payload[4*64-1:3*64],64'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD 3;
                            end 
                            2'b10: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {mtt_data_dout[1*64-1:0*64],qv_get_ceu_payload[4*64-1:3*64],128'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD 2;
                            end 
                            2'b11: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {qv_get_ceu_payload[4*64-1:3*64],192'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD 1;
                            end 
                            default: begin
                                lookup_rden <= `TD 0;
                                lookup_wren <= `TD 0;
                                lookup_wdata <= `TD 0;
                                lookup_index <= `TD 0;
                                lookup_tag <= `TD 0;
                                lookup_offset <= `TD 0;
                                lookup_num <= `TD 0;                            
                            end
                        endcase
                    end
                    else begin
                        case (qv_ceu_req_mtt_addr[1:0])
                            2'b00: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {mtt_data_dout[3*64-1:0*64],qv_get_ceu_payload[4*64-1:3*64]};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                           
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD qv_left_ceu_req_mtt_num;
                            end 
                            2'b01: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {mtt_data_dout[2*64-1:0*64],qv_get_ceu_payload[4*64-1:3*64],64'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD qv_left_ceu_req_mtt_num;
                            end 
                            2'b10: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {mtt_data_dout[1*64-1:0*64],qv_get_ceu_payload[4*64-1:3*64],128'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD qv_left_ceu_req_mtt_num;
                            end 
                            2'b11: begin
                                lookup_rden  <= `TD 0;
                                lookup_wren  <= `TD 1;
                                lookup_wdata <= `TD {qv_get_ceu_payload[4*64-1:3*64],192'b0};
                                lookup_index <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET-1:OFFSET];                                        
                                lookup_tag   <= `TD qv_ceu_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
                                lookup_offset<= `TD qv_ceu_req_mtt_addr[OFFSET-1:0];
                                lookup_num   <= `TD qv_left_ceu_req_mtt_num;
                            end 
                            default: begin
                                lookup_rden <= `TD 0;
                                lookup_wren <= `TD 0;
                                lookup_wdata <= `TD 0;
                                lookup_index <= `TD 0;
                                lookup_tag <= `TD 0;
                                lookup_offset <= `TD 0;
                                lookup_num <= `TD 0;                            
                            end
                        endcase
                    end
                end  
                default: begin
                    lookup_rden <= `TD 0;
                    lookup_wren <= `TD 0;
                    lookup_wdata <= `TD 0;
                    lookup_index <= `TD 0;
                    lookup_tag <= `TD 0;
                    lookup_offset <= `TD 0;
                    lookup_num <= `TD 0;
                end
            endcase
            //TODO: add eq fucntion
            mtt_eq_addr <= `TD 0;
        end
        //consider the mpt req processing state mechine initiate the mtt_ram lookup req
        /*VCS Verification*/
        /*Action = Modify, add state_valid, rden and wren signals judge*/
        else if ((mpt_req_fsm_cs == INIT_LOOKUP) && lookup_allow_in && ((is_rd_data && !dma_rd_dt_req_prog_full) || (is_wr_data && !dma_wr_dt_req_prog_full) ||(is_rd_wqe && !dma_rd_wqe_req_prog_full)) && (state_valid | (!state_valid & (lookup_state == 3'b1))) && !(lookup_rden | lookup_wren)) begin
            lookup_rden <= `TD 1;
            lookup_wren <= `TD 0;
            lookup_wdata <= `TD 0;
            lookup_index  <= `TD qv_mpt_req_mtt_addr[INDEX+OFFSET-1:OFFSET];          
            lookup_tag    <= `TD qv_mpt_req_mtt_addr[INDEX+OFFSET+TAG-1:INDEX+OFFSET];
            lookup_offset <= `TD qv_mpt_req_mtt_addr[OFFSET-1:0];
            lookup_num <= `TD qv_mtt_num_in_cacheline;
            //TODO: add eq fucntion
            mtt_eq_addr <= `TD is_phy_wr ? 1'b1 : 1'b0;
        end
        else begin
            lookup_rden <= `TD 0;
            lookup_wren <= `TD 0;
            lookup_wdata <= `TD 0;
            lookup_index <= `TD 0;
            lookup_tag <= `TD 0;
            lookup_offset <= `TD 0;
            lookup_num <= `TD 0;
            //TODO: add eq fucntion
            mtt_eq_addr <= `TD 0;
        end
    end
//-----------------{two state mechines both write signal} end--------------------//


`ifdef V2P_DUG
    // /*****************Add for APB-slave regs**********************************/ 
        // reg                    mtt_req_rd_en,
        // reg                    mtt_data_rd_en,
        // reg [2:0]   block_valid,
        // reg [197:0] rd_wqe_block_info,
        // reg [197:0] wr_data_block_info,
        // reg [197:0] rd_data_block_info,
        // reg    [2:0]   unblock_valid,
        // reg                      lookup_rden,
        // reg                      lookup_wren,
        // reg  [LINE_SIZE*8-1:0]   lookup_wdata,
        // reg  [INDEX -1     :0]   lookup_index,
        // reg  [TAG -1       :0]   lookup_tag,
        // reg  [OFFSET - 1   :0]   lookup_offset,
        // reg  [NUM - 1      :0]   lookup_num,
        // reg                      mtt_eq_addr,
        // reg                                dma_rd_dt_req_wr_en;
        // reg   [DMA_DT_REQ_WIDTH-1:0]       dma_rd_dt_req_din;
        // reg                                dma_rd_wqe_req_wr_en;
        // reg   [DMA_DT_REQ_WIDTH-1:0]       dma_rd_wqe_req_din;
        // reg                                dma_wr_dt_req_wr_en;
        // reg   [DMA_DT_REQ_WIDTH-1:0]       dma_wr_dt_req_din;
        // reg [1:0] ceu_req_fsm_cs;
        // reg [1:0] ceu_req_fsm_ns;
        // reg  [`HD_WIDTH-1 : 0] qv_get_ceu_req_hd;
        // reg  [`DT_WIDTH-1 : 0] qv_get_ceu_payload;
        // reg  [31:0]  qv_ceu_req_mtt_cnt;
        // reg  [63:0]  qv_ceu_req_mtt_addr;    
        // reg  [1:0]  qv_left_payload_offset;
        // reg  [31:0] qv_left_ceu_req_mtt_num;
        // reg [2:0] mpt_req_fsm_cs;
        // reg [2:0] mpt_req_fsm_ns;
        // reg  [197 : 0] qv_get_mpt_req;
        // reg  [63:0]  qv_mpt_req_mtt_addr;    
        // reg  [31:0] qv_left_mtt_entry_num;
        // reg  [63:0] qv_fisrt_mtt_vaddr;  
        // reg  [31:0] qv_left_mtt_Blen;
        // reg [2:0] qv_mtt_num_in_cacheline;
        // reg  [LINE_SIZE*8-1:0]   qv_rdata;
        // reg  [2:0]               qv_state;
        // reg                      q_ldst;
        // reg                      q_result_valid;
        // reg  [2:0]  qv_left_dma_req_from_cache;
        // reg  [31:0] qv_left_dma_req_from_mpt;
        // reg [11:0] virt_addr_offset3;
        // reg [11:0] virt_addr_offset2;
        // reg [11:0] virt_addr_offset1;
        // reg [11:0] virt_addr_offset0;
        // reg [31:0] byte_length3;
        // reg [31:0] byte_length2;
        // reg [31:0] byte_length1;
        // reg [31:0] byte_length0;  
        
    /*****************Add for APB-slave wires**********************************/         
        // input  wire  [`HD_WIDTH-1:0]   mtt_req_dout,
        // input  wire                    mtt_req_empty,
        // input  wire  [`DT_WIDTH-1:0]   mtt_data_dout,
        // input  wire                    mtt_data_empty,
        // input  wire  [63:0]             mtt_base_addr,  
        // input wire [3:0] new_selected_channel,
        // input  wire   [197:0] rd_wqe_block_reg,
        // input  wire   [197:0] wr_data_block_reg,
        // input  wire   [197:0] rd_data_block_reg,
        // output  wire             mpt_rd_req_mtt_cl_rd_en,
        // input   wire             mpt_rd_req_mtt_cl_empty,
        // input   wire  [197:0]    mpt_rd_req_mtt_cl_dout,
        // output  wire             mpt_rd_wqe_req_mtt_cl_rd_en,
        // input   wire             mpt_rd_wqe_req_mtt_cl_empty,
        // input   wire  [197:0]    mpt_rd_wqe_req_mtt_cl_dout,
        // output  wire             mpt_wr_req_mtt_cl_rd_en,
        // input   wire             mpt_wr_req_mtt_cl_empty,
        // input   wire  [197:0]    mpt_wr_req_mtt_cl_dout,
        // input  wire                     lookup_allow_in,
        // input  wire [2:0]               lookup_state,
        // input  wire                     lookup_ldst,
        // input  wire                     state_valid,
        // output wire                     lookup_stall,
        // input  wire [LINE_SIZE*8-1:0]   hit_rdata,
        // input  wire [LINE_SIZE*8-1:0]   miss_rdata,
        // input   wire                            dma_rd_dt_req_rd_en,
        // output  wire                            dma_rd_dt_req_empty,
        // output  wire  [DMA_DT_REQ_WIDTH-1:0]    dma_rd_dt_req_dout,
        // input   wire                            dma_rd_wqe_req_rd_en,
        // output  wire                            dma_rd_wqe_req_empty,
        // output  wire  [DMA_DT_REQ_WIDTH-1:0]    dma_rd_wqe_req_dout,
        // input   wire                            dma_wr_dt_req_rd_en,
        // output  wire                            dma_wr_dt_req_empty,
        // output  wire  [DMA_DT_REQ_WIDTH-1:0]    dma_wr_dt_req_dout
        // wire                               dma_rd_dt_req_prog_full;
        // wire                               dma_rd_wqe_req_prog_full;
        // wire                               dma_wr_dt_req_prog_full;
        // wire [31:0]  ceu_req_mtt_num;
        // wire is_ceu_req_processing;
        // wire [31:0] req_num_add_offset;
        // wire [2:0] left_num_add_offset;
        // wire mpt_req_mtt_valid;
        // wire [197:0] mpt_req_mtt_dout;
        // wire is_rd_wqe;
        // wire is_rd_data;
        // wire is_wr_data;
        // wire is_phy_wr;
        // wire is_vir_wr;
        // wire mpt_req_mtt_rd_en;
        // wire phy_addr;
        // wire [31:0]  req_vaddr_offset_add_Blen; 
        // wire [31:0]  total_mtt_entry_num; 
        // wire [31:0]  index_off_add_total_mtt_num;
        // wire [63:0] wv_mpt_req_mtt_addr;
        // wire [51:0] dma_req_page_addr0;
        // wire [51:0] dma_req_page_addr1;
        // wire [51:0] dma_req_page_addr2;
        // wire [51:0] dma_req_page_addr3;
        
    //Total regs and wires : 5896 = 184*32+8

    assign wv_dbg_bus_mttctl = {
        24'b0,
        mtt_req_rd_en,
        mtt_data_rd_en,
        block_valid,
        rd_wqe_block_info,
        wr_data_block_info,
        rd_data_block_info,
        unblock_valid,
        lookup_rden,
        lookup_wren,
        lookup_wdata,
        lookup_index,
        lookup_tag,
        lookup_offset,
        lookup_num,
        mtt_eq_addr,
        dma_rd_dt_req_wr_en,
        dma_rd_dt_req_din,
        dma_rd_wqe_req_wr_en,
        dma_rd_wqe_req_din,
        dma_wr_dt_req_wr_en,
        dma_wr_dt_req_din,
        ceu_req_fsm_cs,
        ceu_req_fsm_ns,
        qv_get_ceu_req_hd,
        qv_get_ceu_payload,
        qv_ceu_req_mtt_cnt,
        qv_ceu_req_mtt_addr,
        qv_left_payload_offset,
        qv_left_ceu_req_mtt_num,
        mpt_req_fsm_cs,
        mpt_req_fsm_ns,
        qv_get_mpt_req,
        qv_mpt_req_mtt_addr,
        qv_left_mtt_entry_num,
        qv_fisrt_mtt_vaddr,
        qv_left_mtt_Blen,
        qv_mtt_num_in_cacheline,
        qv_rdata,
        qv_state,
        q_ldst,
        q_result_valid,
        qv_left_dma_req_from_cache,
        qv_left_dma_req_from_mpt,
        virt_addr_offset3,
        virt_addr_offset2,
        virt_addr_offset1,
        virt_addr_offset0,
        byte_length3,
        byte_length2,
        byte_length1,
        byte_length0,

        mtt_req_dout,
        mtt_req_empty,
        mtt_data_dout,
        mtt_data_empty,
        mtt_base_addr,
        new_selected_channel,
        rd_wqe_block_reg,
        wr_data_block_reg,
        rd_data_block_reg,
        mpt_rd_req_mtt_cl_rd_en,
        mpt_rd_req_mtt_cl_empty,
        mpt_rd_req_mtt_cl_dout,
        mpt_rd_wqe_req_mtt_cl_rd_en,
        mpt_rd_wqe_req_mtt_cl_empty,
        mpt_rd_wqe_req_mtt_cl_dout,
        mpt_wr_req_mtt_cl_rd_en,
        mpt_wr_req_mtt_cl_empty,
        mpt_wr_req_mtt_cl_dout,
        lookup_allow_in,
        lookup_state,
        lookup_ldst,
        state_valid,
        lookup_stall,
        hit_rdata,
        miss_rdata,
        dma_rd_dt_req_rd_en,
        dma_rd_dt_req_empty,
        dma_rd_dt_req_dout,
        dma_rd_wqe_req_rd_en,
        dma_rd_wqe_req_empty,
        dma_rd_wqe_req_dout,
        dma_wr_dt_req_rd_en,
        dma_wr_dt_req_empty,
        dma_wr_dt_req_dout,
        dma_rd_dt_req_prog_full,
        dma_rd_wqe_req_prog_full,
        dma_wr_dt_req_prog_full,
        ceu_req_mtt_num,
        is_ceu_req_processing,
        req_num_add_offset,
        left_num_add_offset,
        // mpt_req_mtt_empty,
        mpt_req_mtt_valid,
        mpt_req_mtt_dout,
        is_rd_wqe,
        is_rd_data,
        is_wr_data,
        is_phy_wr,
        is_vir_wr,
        mpt_req_mtt_rd_en,
        phy_addr,
        req_vaddr_offset_add_Blen,
        total_mtt_entry_num,
        index_off_add_total_mtt_num,
        wv_mpt_req_mtt_addr,
        dma_req_page_addr0,
        dma_req_page_addr1,
        dma_req_page_addr2,
        dma_req_page_addr3    
    };

`endif 

endmodule