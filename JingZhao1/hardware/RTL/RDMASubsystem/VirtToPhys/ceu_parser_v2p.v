//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: ceu_parser.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V0.2 
// VERSION DESCRIPTION: 2nd Edition  
//----------------------------------------------------
// RELEASE DATE: 2020-08-31 
//---------------------------------------------------- 
// PURPOSE: parse msg from CEU for VirToPhys module.
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
// 
//-FHDR-----------------------------------------------

//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_v2p_h.vh"

module ceu_parser_v2p (
    input clk,
    input rst,
    // externel Parse msg requests header from CEU 
    input   wire                  ceu_req_tvalid,
    output  wire                  ceu_req_tready,
    input   wire [`DT_WIDTH-1:0]  ceu_req_tdata,
    input   wire                  ceu_req_tlast,
    input   wire [`HD_WIDTH-1:0]  ceu_req_theader,

    // internal MPT request header
    //128 width header format
    input  wire                    mpt_req_rd_en,
    output wire  [`HD_WIDTH-1:0]   mpt_req_dout,
    output wire                    mpt_req_empty,
    
    // internal MPT payload data
    //256 width 
    input  wire                    mpt_data_rd_en,
    output wire  [`DT_WIDTH-1:0]   mpt_data_dout,
    output wire                    mpt_data_empty,
    
    // internal MTT request header
    //128 width header format
    input  wire                    mtt_req_rd_en,
    output wire  [`HD_WIDTH-1:0]   mtt_req_dout,
    output wire                    mtt_req_empty,
    
    // internal MTT payload data
    //256 width 
    input  wire                    mtt_data_rd_en,
    output wire  [`DT_WIDTH-1:0]   mtt_data_dout,
    output wire                    mtt_data_empty,

    // internal TPTMeteData write request header
    //128 width header format
    input  wire                    mdata_req_rd_en,
    output wire  [`HD_WIDTH-1:0]   mdata_req_dout,
    output wire                    mdata_req_empty,

    // internel TPT metaddata for TPTmetaData Module
    // 256 width (only TPT meatadata)
    input  wire                    mdata_rd_en,
    output wire  [`DT_WIDTH-1:0]   mdata_dout,
    output wire                    mdata_empty
    `ifdef V2P_DUG
    //apb_slave
    ,  input wire [`CEUPAR_DBG_RW_NUM * 32 - 1 : 0]   rw_data
    ,  output wire [`CEUPAR_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_ceupar
    `endif 

);

//variables for MPT/MTT/Mdata dest fifo (header and payload)

wire                          mpt_req_wr_en;
wire                          mpt_req_prog_full;
wire [`HD_WIDTH-1:0]          mpt_req_din;


// wire                          mpt_data_wr_en;
wire                          mpt_data_prog_full;
// wire [`DT_WIDTH-1:0]          mpt_data_din;
    
wire                          mtt_req_wr_en;
wire                          mtt_req_prog_full;
wire [`HD_WIDTH-1:0]          mtt_req_din;

// wire                          mtt_data_wr_en;
wire                          mtt_data_prog_full;
// wire [`DT_WIDTH-1:0]          mtt_data_din;

wire                         mdata_req_wr_en;
wire                         mdata_req_prog_full;
wire [`HD_WIDTH-1:0]         mdata_req_din;


// wire                         mdata_wr_en;
wire                         mdata_prog_full;
// wire [`DT_WIDTH-1:0]         mdata_din;   

reg                         mpt_data_wr_en;
reg [`DT_WIDTH-1:0]         mpt_data_din;  
reg                         mtt_data_wr_en;
reg [`DT_WIDTH-1:0]         mtt_data_din;
reg                         mdata_wr_en;
reg [`DT_WIDTH-1:0]         mdata_din; 

/*Spyglass*/
// wire fifo_clear;
// assign fifo_clear = 1'b0;
/*Action = Modify*/

mpt_req_fifo_128w16d mpt_req_fifo_128w16d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (mpt_req_wr_en),
        .rd_en      (mpt_req_rd_en),
        .din        (mpt_req_din),
        .dout       (mpt_req_dout),
        .full       (),
        .empty      (mpt_req_empty),     
        .prog_full  (mpt_req_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[1 * 32 - 1 : 0])        
    `endif
);

mpt_req_fifo_128w16d mtt_req_fifo_128w16d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (mtt_req_wr_en),
        .rd_en      (mtt_req_rd_en),
        .din        (mtt_req_din),
        .dout       (mtt_req_dout),
        .full       (),
        .empty      (mtt_req_empty),     
        .prog_full  (mtt_req_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[1 * 32 +: 1 * 32])        
    `endif
);

mpt_req_fifo_128w16d mdata_req_fifo_128w16d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (mdata_req_wr_en),
        .rd_en      (mdata_req_rd_en),
        .din        (mdata_req_din),
        .dout       (mdata_req_dout),
        .full       (),
        .empty      (mdata_req_empty),     
        .prog_full  (mdata_req_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[2 * 32 +: 1 * 32])        
    `endif
);

mpt_data_fifo_256w64d mpt_data_fifo_256w64d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (mpt_data_wr_en),
        .rd_en      (mpt_data_rd_en),
        .din        (mpt_data_din),
        .dout       (mpt_data_dout),
        .full       (),
        .empty      (mpt_data_empty),     
        .prog_full  (mpt_data_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[3 * 32 +: 1 * 32])        
    `endif
);

mtt_data_fifo_256w256d mtt_data_fifo_256w256d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (mtt_data_wr_en),
        .rd_en      (mtt_data_rd_en),
        .din        (mtt_data_din),
        .dout       (mtt_data_dout),
        .full       (),
        .empty      (mtt_data_empty),     
        .prog_full  (mtt_data_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[4 * 32 +: 1 * 32])        
    `endif
);

mtt_data_fifo_256w256d mdata_fifo_256w256d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (mdata_wr_en),
        .rd_en      (mdata_rd_en),
        .din        (mdata_din),
        .dout       (mdata_dout),
        .full       (),
        .empty      (mdata_empty),     
        .prog_full  (mdata_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[5 * 32 +: 1 * 32])        
    `endif
);



//registers
reg [1:0] fsm_cs;
reg [1:0] fsm_ns;

//state machine localparams
//make sure whether it has payload, which fifo it will be pushed,
localparam PARSE_REQ    = 2'b01;
//transfer req and payload to dest fifo
localparam FORWARD      = 2'b10;


//-----------------Stage 1 :State Register----------
always @(posedge clk or posedge rst) begin
    if(rst)
        fsm_cs <= `TD PARSE_REQ;
    else
        fsm_cs <= `TD fsm_ns;
end


//-----------------Stage 2 :State Transition----------

// wire for judging dest fifo (header and payload)
// reg  start;
reg  last;
reg  [`HD_WIDTH-1 :0] qv_ceu_req_theader;
reg  [`DT_WIDTH-1 :0] qv_ceu_req_tdata;
wire [3:0]            wv_req_type;
wire [3:0]            wv_req_opcode;
assign wv_req_type =  (fsm_cs == PARSE_REQ) ? ceu_req_theader[`HD_WIDTH-1:`HD_WIDTH-`TYPE_WIDTH] : qv_ceu_req_theader[`HD_WIDTH-1:`HD_WIDTH-`TYPE_WIDTH];
assign wv_req_opcode= (fsm_cs == PARSE_REQ) ? ceu_req_theader[`HD_WIDTH-`TYPE_WIDTH-1:`HD_WIDTH-`OPCODE_WIDTH-`TYPE_WIDTH] : qv_ceu_req_theader[`HD_WIDTH-`TYPE_WIDTH-1:`HD_WIDTH-`OPCODE_WIDTH-`TYPE_WIDTH];


wire w_mpt_has_payload;
wire w_mtt_has_payload;
wire w_mdata_has_payload;
wire w_mpt_no_payload;
wire w_mdata_no_payload;
assign w_mpt_has_payload = (wv_req_type == `WR_MPT_TPT) && (wv_req_opcode == `WR_MPT_WRITE);
assign w_mtt_has_payload = (wv_req_type == `WR_MTT_TPT) && (wv_req_opcode == `WR_MTT_WRITE);
assign w_mdata_has_payload = ((wv_req_type == `WR_ICMMAP_TPT) && (wv_req_opcode == `WR_ICMMAP_EN_V2P)) || ((wv_req_type == `MAP_ICM_TPT) && (wv_req_opcode == `MAP_ICM_EN_V2P));
assign w_mpt_no_payload = (wv_req_type == `WR_MPT_TPT) && (wv_req_opcode == `WR_MPT_INVALID);
assign w_mdata_no_payload = ((wv_req_type == `WR_ICMMAP_TPT) && (wv_req_opcode == `WR_ICMMAP_DIS_V2P)) || ((wv_req_type == `MAP_ICM_TPT) && (wv_req_opcode == `MAP_ICM_DIS_V2P));


always @(*) begin
    case (fsm_cs)
        PARSE_REQ: begin
            //if req comes,put the req header and payload to regs, next state is FORWARD
            if (ceu_req_tready && ceu_req_tvalid && ((w_mdata_has_payload && !mdata_prog_full) || (w_mdata_no_payload && !mdata_req_prog_full) || (w_mpt_has_payload && !mpt_data_prog_full) ||(w_mpt_no_payload && !mpt_req_prog_full) || (w_mtt_has_payload && !mtt_data_prog_full))) begin
                fsm_ns = FORWARD;
            end
            else
                fsm_ns = PARSE_REQ;
        end    
        FORWARD:begin
            //forward req and payload to the dest fifo, when 1 req is 
            //processed completely, next cycle processes new req
            //MXX modify for configure block, use mtt_req_prog_full replace mtt_data_prog_full
            // if ( last && ((w_mdata_has_payload && !mdata_prog_full) || (w_mdata_no_payload && !mdata_req_prog_full) || (w_mpt_has_payload && !mpt_data_prog_full) ||(w_mpt_no_payload && !mpt_req_prog_full) || (w_mtt_has_payload && !mtt_data_prog_full)))begin
            if ( last && ((w_mdata_has_payload && !mdata_prog_full) || (w_mdata_no_payload && !mdata_req_prog_full) || (w_mpt_has_payload && !mpt_data_prog_full) ||(w_mpt_no_payload && !mpt_req_prog_full) || (w_mtt_has_payload && !mtt_req_prog_full)))begin
                fsm_ns = PARSE_REQ;
            end                
            else
                fsm_ns = FORWARD;
        end
        default: 
            fsm_ns = PARSE_REQ;
    endcase
end

//-----------------Stage 3 : Output Decode--------------------

// // start
// // the reg used to mark a new request, used to make sure that we only push the qv_ceu_req_theader once
// always @(posedge clk or posedge rst) begin
//     if (rst) begin
//         start <= `TD 0;
//     end 
//     else if (ceu_req_tready && ceu_req_tvalid && (fsm_cs == PARSE_REQ)) begin
//         start <= `TD 1;
//     end
//     // keep the start reg if the dest fifo is full(request header hasn't been pushed in)
//     else if ((fsm_cs == FORWARD) && ((w_mdata_has_payload && !mdata_prog_full) || (w_mdata_no_payload && !mdata_req_prog_full) || (w_mpt_has_payload && !mpt_data_prog_full) ||(w_mpt_no_payload && !mpt_req_prog_full) || (w_mtt_has_payload && !mtt_data_prog_full))) begin
//         start <= `TD start;
//     end
//     else
//         start <= `TD 0;
// end

// last
// reg used to mark the last cycle of requst data stored in qv_ceu_req_tdata or qv_ceu_req_theader
always @(posedge clk or posedge rst) begin
    if (rst) begin
        last <= `TD 0;
    end 
    else if (ceu_req_tready && ceu_req_tvalid && ceu_req_tlast) begin
        last <= `TD 1;
    end 
    // keep the last reg if the dest fifo is full (request header  or payload hasn't been pushed in)
    // else if ((fsm_cs == FORWARD) && ((w_mdata_has_payload && !mdata_prog_full) || (w_mdata_no_payload && !mdata_req_prog_full) || (w_mpt_has_payload && !mpt_data_prog_full) ||(w_mpt_no_payload && !mpt_req_prog_full) || (w_mtt_has_payload && !mtt_data_prog_full))) begin
    else if ((fsm_cs == FORWARD) && 
    ((w_mdata_has_payload && mdata_prog_full) || 
    (w_mdata_no_payload && mdata_req_prog_full) || 
    (w_mpt_has_payload && mpt_data_prog_full) ||
    (w_mpt_no_payload && mpt_req_prog_full) || 
    (w_mtt_has_payload && mtt_data_prog_full)) ) begin
        last <= `TD last;
    end
    else
        last <= `TD 0;
end


// qv_ceu_req_theader;
// store the request header untill the whole packet has been forward to dest fifo
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_ceu_req_theader <= `TD 0;
    end 
    else if (ceu_req_tready && ceu_req_tvalid && (fsm_cs == PARSE_REQ) && ((w_mdata_has_payload && !mdata_prog_full) || (w_mdata_no_payload && !mdata_req_prog_full) || (w_mpt_has_payload && !mpt_data_prog_full) ||(w_mpt_no_payload && !mpt_req_prog_full) || (w_mtt_has_payload && !mtt_data_prog_full))) begin
        qv_ceu_req_theader <= `TD ceu_req_theader;
    end
    else if (fsm_cs == FORWARD) begin
        qv_ceu_req_theader <= `TD qv_ceu_req_theader;
    end
    else
        qv_ceu_req_theader <= `TD 0;
end

// qv_ceu_req_tdata;
// store the request payload for 1 cycle to meet the time constrains
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_ceu_req_tdata <= `TD 0;
    end
    else if (ceu_req_tready && ceu_req_tvalid && ((w_mdata_has_payload && !mdata_prog_full) || (w_mpt_has_payload && !mpt_data_prog_full) || (w_mtt_has_payload && !mtt_data_prog_full)))  begin
        qv_ceu_req_tdata <= `TD ceu_req_tdata;
    end
    // else if ((fsm_cs == FORWARD) && ((w_mdata_has_payload && !mdata_prog_full) || (w_mpt_has_payload && !mpt_data_prog_full) || (w_mtt_has_payload && !mtt_data_prog_full))) begin
    else if ((w_mdata_has_payload && mdata_prog_full) || (w_mpt_has_payload && mpt_data_prog_full) || (w_mtt_has_payload && mtt_data_prog_full)) begin
        qv_ceu_req_tdata <= `TD qv_ceu_req_tdata;
    end
    else
        qv_ceu_req_tdata <= `TD 0;
end

// ceu_req_tready
// tready is always 1 in PARSE_REQ state; tready changes into 1 
// when the parsed dest fifo is not full and the data is the not last data in FORWARD state.
assign ceu_req_tready = (((fsm_cs == PARSE_REQ) && !mdata_prog_full && !mdata_req_prog_full && !mpt_data_prog_full && !mpt_req_prog_full && !mtt_data_prog_full && !mtt_req_prog_full) || 
    ((fsm_cs == FORWARD) && !last && ((w_mdata_has_payload && !mdata_prog_full && !mdata_req_prog_full) || 
                                    (w_mdata_no_payload && !mdata_req_prog_full) || 
                                    (w_mpt_has_payload && !mpt_data_prog_full && !mpt_req_prog_full) ||
                                    (w_mpt_no_payload && !mpt_req_prog_full) || 
                                    (w_mtt_has_payload && !mtt_data_prog_full && !mtt_req_prog_full)))) ? 1 : 0;


//variables for MPT/MTT/Mdata dest fifo (header and payload)
// mpt_req_wr_en
assign mpt_req_wr_en = ((fsm_cs == FORWARD) && !mpt_req_prog_full && last && (w_mpt_has_payload || w_mpt_no_payload)) ? 1 : 0;
// mpt_req_din
assign mpt_req_din = ((fsm_cs == FORWARD) && !mpt_req_prog_full && last && (w_mpt_has_payload || w_mpt_no_payload)) ? qv_ceu_req_theader : 128'b0;

/*VCS Verification*/
// // mpt_data_wr_en
// //assign mpt_data_wr_en = ((fsm_cs == FORWARD) && !mpt_data_prog_full && (|qv_ceu_req_tdata) && w_mpt_has_payload) ? 1 : 0;
// assign mpt_data_wr_en = ((fsm_cs == FORWARD) && !mpt_data_prog_full && w_mpt_has_payload) ? 1 : 0;
// // mpt_data_din
// //assign mpt_data_din = ((fsm_cs == FORWARD) && !mpt_data_prog_full && (|qv_ceu_req_tdata) && w_mpt_has_payload) ? qv_ceu_req_tdata : 256'b0;
// assign mpt_data_din = ((fsm_cs == FORWARD) && !mpt_data_prog_full && w_mpt_has_payload) ? qv_ceu_req_tdata : 256'b0;
// /*Action = Modify, Do not check if the mpt entry is zero*/

// mtt_req_wr_en
assign mtt_req_wr_en = ((fsm_cs == FORWARD) && !mtt_req_prog_full && last && w_mtt_has_payload) ? 1 : 0;
// mtt_req_din
assign mtt_req_din = ((fsm_cs == FORWARD) && !mtt_req_prog_full && last && w_mtt_has_payload) ? qv_ceu_req_theader : 128'b0;
 
// // mtt_data_wr_en
// // assign mtt_data_wr_en = ((fsm_cs == FORWARD) && !mtt_data_prog_full && (|qv_ceu_req_tdata) && w_mtt_has_payload) ? 1 : 0;
// assign mtt_data_wr_en = ((fsm_cs == FORWARD) && !mtt_data_prog_full && w_mtt_has_payload) ? 1 : 0;
// // mtt_data_din
// // assign mtt_data_din = ((fsm_cs == FORWARD) && !mtt_data_prog_full && (|qv_ceu_req_tdata) && w_mtt_has_payload) ? qv_ceu_req_tdata : 256'b0;
// assign mtt_data_din = ((fsm_cs == FORWARD) && !mtt_data_prog_full && w_mtt_has_payload) ? qv_ceu_req_tdata : 256'b0;

// mdata_req_wr_en
assign mdata_req_wr_en = ((fsm_cs == FORWARD) && !mdata_req_prog_full && last && (w_mdata_has_payload || w_mdata_no_payload)) ? 1 : 0;
// mdata_req_din
assign mdata_req_din = ((fsm_cs == FORWARD) && !mdata_req_prog_full && last && (w_mdata_has_payload || w_mdata_no_payload)) ? qv_ceu_req_theader : 128'b0;

// // mdata_wr_en
// // assign mdata_wr_en = ((fsm_cs == FORWARD) && !mdata_prog_full && (|qv_ceu_req_tdata) && w_mdata_has_payload) ? 1 : 0;
// assign mdata_wr_en = ((fsm_cs == FORWARD) && !mdata_prog_full && w_mdata_has_payload) ? 1 : 0;
// // mdata_din
// // assign mdata_din = ((fsm_cs == FORWARD) && !mdata_prog_full && (|qv_ceu_req_tdata) && w_mdata_has_payload) ? qv_ceu_req_tdata : 256'b0;
// assign mdata_din = ((fsm_cs == FORWARD) && !mdata_prog_full && w_mdata_has_payload) ? qv_ceu_req_tdata : 256'b0;


//reg                         mpt_data_wr_en;
//reg [`DT_WIDTH-1:0]         mpt_data_din;  
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mpt_data_wr_en <= `TD 0;
        mpt_data_din <= `TD 0;  
    end
    else begin
        case (fsm_cs)
            PARSE_REQ: begin
                if (ceu_req_tready && ceu_req_tvalid && !mpt_data_prog_full && w_mpt_has_payload) begin
                    mpt_data_wr_en <= `TD 1;
                    mpt_data_din <= `TD ceu_req_tdata;
                end
                else begin
                    mpt_data_wr_en <= `TD 0;
                    mpt_data_din <= `TD 0;  
                end
            end    
            FORWARD:begin
                if (ceu_req_tready && ceu_req_tvalid && !mpt_data_prog_full && w_mpt_has_payload)begin
                    mpt_data_wr_en <= `TD 1;
                    mpt_data_din <= `TD ceu_req_tdata;  
                end                
                else begin
                    mpt_data_wr_en <= `TD 0;
                    mpt_data_din <= `TD 0;  
                end
            end
            default: begin
                mpt_data_wr_en <= `TD 0;
                mpt_data_din <= `TD 0;  
            end
        endcase
    end
end
//reg                         mtt_data_wr_en;
//reg [`DT_WIDTH-1:0]         mtt_data_din;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mtt_data_wr_en <= `TD 0;
        mtt_data_din <= `TD 0;
    end
    else begin
        case (fsm_cs)
            PARSE_REQ: begin
                if (ceu_req_tready && ceu_req_tvalid && !mtt_data_prog_full && w_mtt_has_payload) begin
                    mtt_data_wr_en <= `TD 1;
                    mtt_data_din <= `TD ceu_req_tdata;
                end
                else begin
                    mtt_data_wr_en <= `TD 0;
                    mtt_data_din <= `TD 0;
                end
            end    
            FORWARD:begin
                if (ceu_req_tready && ceu_req_tvalid && !mtt_data_prog_full && w_mtt_has_payload) begin
                    mtt_data_wr_en <= `TD 1;
                    mtt_data_din <= `TD ceu_req_tdata;
                end
                else begin
                    mtt_data_wr_en <= `TD 0;
                    mtt_data_din <= `TD 0;
                end
            end
            default: begin
                mtt_data_wr_en <= `TD 0;
                mtt_data_din <= `TD 0;
            end
        endcase
    end
end

//reg                         mdata_wr_en;
//reg [`DT_WIDTH-1:0]         mdata_din; 
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mdata_wr_en <= `TD 0;
        mdata_din <= `TD 0; 
    end
    else begin
        case (fsm_cs)
            PARSE_REQ: begin
                if (ceu_req_tready && ceu_req_tvalid && !mdata_prog_full && w_mdata_has_payload) begin
                    mdata_wr_en <= `TD 1;
                    mdata_din <= `TD ceu_req_tdata; 
                end
                else begin
                    mdata_wr_en <= `TD 0;
                    mdata_din <= `TD 0; 
                end
            end    
            FORWARD:begin
                if (ceu_req_tready && ceu_req_tvalid && !mdata_prog_full && w_mdata_has_payload) begin
                    mdata_wr_en <= `TD 1;
                    mdata_din <= `TD ceu_req_tdata; 
                end
                else begin
                    mdata_wr_en <= `TD 0;
                    mdata_din <= `TD 0; 
                end
            end
            default: begin
                mdata_wr_en <= `TD 0;
                mdata_din <= `TD 0; 
            end
        endcase
    end
end

`ifdef V2P_DUG
    // /*****************Add for APB-slave regs**********************************/ 
        // reg                         mpt_data_wr_en;
        // reg [`DT_WIDTH-1:0]         mpt_data_din;  
        // reg                         mtt_data_wr_en;
        // reg [`DT_WIDTH-1:0]         mtt_data_din;
        // reg                         mdata_wr_en;
        // reg [`DT_WIDTH-1:0]         mdata_din; 
        // reg [1:0] fsm_cs;
        // reg [1:0] fsm_ns;
        // reg  last;
        // reg  [`HD_WIDTH-1 :0] qv_ceu_req_theader;
        // reg  [`DT_WIDTH-1 :0] qv_ceu_req_tdata;

    // /*****************Add for APB-slave wires**********************************/ 
        // wire                  ceu_req_tvalid,
        // wire                  ceu_req_tready,
        // wire [`DT_WIDTH-1:0]  ceu_req_tdata,
        // wire                  ceu_req_tlast,
        // wire [`HD_WIDTH-1:0]  ceu_req_theader,
        // wire                    mpt_req_rd_en,
        // wire  [`HD_WIDTH-1:0]   mpt_req_dout,
        // wire                    mpt_req_empty,
        // wire                    mpt_data_rd_en,
        // wire  [`DT_WIDTH-1:0]   mpt_data_dout,
        // wire                    mpt_data_empty,
        // wire                    mtt_req_rd_en,
        // wire  [`HD_WIDTH-1:0]   mtt_req_dout,
        // wire                    mtt_req_empty,
        // wire                    mtt_data_rd_en,
        // wire  [`DT_WIDTH-1:0]   mtt_data_dout,
        // wire                    mtt_data_empty,
        // wire                    mdata_req_rd_en,
        // wire  [`HD_WIDTH-1:0]   mdata_req_dout,
        // wire                    mdata_req_empty,
        // wire                    mdata_rd_en,
        // wire  [`DT_WIDTH-1:0]   mdata_dout,
        // wire                    mdata_empty
        // wire                          mpt_req_wr_en;
        // wire                          mpt_req_prog_full;
        // wire [`HD_WIDTH-1:0]          mpt_req_din;
        // wire                          mpt_data_prog_full;
        // wire                          mtt_req_wr_en;
        // wire                          mtt_req_prog_full;
        // wire [`HD_WIDTH-1:0]          mtt_req_din;
        // wire                          mtt_data_prog_full;
        // wire                         mdata_req_wr_en;
        // wire                         mdata_req_prog_full;
        // wire [`HD_WIDTH-1:0]         mdata_req_din;
        // wire                         mdata_prog_full;
        // wire [3:0]            wv_req_type;
        // wire [3:0]            wv_req_opcode;
        // wire w_mpt_has_payload;
        // wire w_mtt_has_payload;
        // wire w_mdata_has_payload;
        // wire w_mpt_no_payload;
        // wire w_mdata_no_payload;
    //Total regs and wires : 3117 = 97*32 +13

    assign wv_dbg_bus_ceupar = {
        19'b0,
        mpt_data_wr_en,
        mpt_data_din,
        mtt_data_wr_en,
        mtt_data_din,
        mdata_wr_en,
        mdata_din,
        fsm_cs,
        fsm_ns,
        last,
        qv_ceu_req_theader,
        qv_ceu_req_tdata,

        ceu_req_tvalid,
        ceu_req_tready,
        ceu_req_tdata,
        ceu_req_tlast,
        ceu_req_theader,
        mpt_req_rd_en,
        mpt_req_dout,
        mpt_req_empty,
        mpt_data_rd_en,
        mpt_data_dout,
        mpt_data_empty,
        mtt_req_rd_en,
        mtt_req_dout,
        mtt_req_empty,
        mtt_data_rd_en,
        mtt_data_dout,
        mtt_data_empty,
        mdata_req_rd_en,
        mdata_req_dout,
        mdata_req_empty,
        mdata_rd_en,
        mdata_dout,
        mdata_empty,
        mpt_req_wr_en,
        mpt_req_prog_full,
        mpt_req_din,
        mpt_data_prog_full,
        mtt_req_wr_en,
        mtt_req_prog_full,
        mtt_req_din,
        mtt_data_prog_full,
        mdata_req_wr_en,
        mdata_req_prog_full,
        mdata_req_din,
        mdata_prog_full,
        wv_req_type,
        wv_req_opcode,
        w_mpt_has_payload,
        w_mtt_has_payload,
        w_mdata_has_payload,
        w_mpt_no_payload,
        w_mdata_no_payload       
    };
`endif 

endmodule




