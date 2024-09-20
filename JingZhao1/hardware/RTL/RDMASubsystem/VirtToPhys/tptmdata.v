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
// RELEASE DATE: 2020-09-11 
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

module tptmdata#(
    parameter  TPT_HD_WIDTH  = 99,//for MPT/MTT-Mdata req header fifo
    parameter  DMA_RD_HD_WIDTH  = 163,//for Mdata-DMA Read req header fifo
    parameter  DMA_WR_HD_WIDTH  = 99,//for Mdata-DMA Write req header fifo
    parameter  CEU_HD_WIDTH  = 104,//for ceu_tptm_proc to MPTMdata/MTTMdata req header fifo
    parameter  MPTM_RAM_DWIDTH = 52,//mptmdata RAM data width
    parameter  MPTM_RAM_AWIDTH = 9,//mptmdata RAM addr width
    parameter  MPTM_RAM_DEPTH  = 512, //mptmdata RAM depth
    parameter  MTTM_RAM_DWIDTH = 52,//mttmdata RAM data width
    parameter  MTTM_RAM_AWIDTH = 9,//mttmdata RAM addr width
    parameter  MTTM_RAM_DEPTH  = 512 //mttmdata RAM depth
    )(
    input clk,
    input rst,

	input 	wire 											global_mem_init_finish,
	input	wire 											init_wea,
	input	wire 	[`V2P_MEM_MAX_ADDR_WIDTH - 1 : 0]		init_addra,
	input	wire 	[`V2P_MEM_MAX_DIN_WIDTH - 1 : 0]		init_dina,

    // internal TPTMeteData write request header from CEU 
    //128 width header format
    input  wire  [`HD_WIDTH-1:0]   ceu_req_dout,
    input  wire                    ceu_req_empty,
    output wire                    ceu_req_rd_en,
    // internel TPT metaddata from CEU 
    // 256 width (only TPT meatadata)
    output wire                    mdata_rd_en,
    input  wire  [`DT_WIDTH-1:0]   mdata_dout,
    input  wire                    mdata_empty,
    
    //MPT Request interface
    output wire                        mpt_req_rd_en,
    input  wire  [TPT_HD_WIDTH-1:0]    mpt_req_dout,
    input  wire                        mpt_req_empty,
    
    //MTT Request interface
    output wire                        mtt_req_rd_en,
    input  wire  [TPT_HD_WIDTH-1:0]    mtt_req_dout,
    input  wire                        mtt_req_empty,

    //MTT get mtt_base for compute index in mtt_ram
    output wire  [63:0]                mtt_base_addr, 

    //MPT get mpt_base for compute index in mpt_ram
    output wire  [63:0]                mpt_base_addr, 
    
    //DMA Read Ctx Request interface
    input  wire                           dma_rd_mpt_req_rd_en,
    output wire  [DMA_RD_HD_WIDTH-1:0]    dma_rd_mpt_req_dout,
    output wire                           dma_rd_mpt_req_empty,
    
    input  wire                           dma_rd_mtt_req_rd_en,
    output wire  [DMA_RD_HD_WIDTH-1:0]    dma_rd_mtt_req_dout,
    output wire                           dma_rd_mtt_req_empty,

    //DMA Write Ctx Request interface
    input  wire                           dma_wr_mpt_req_rd_en,
    output wire  [DMA_WR_HD_WIDTH-1:0]    dma_wr_mpt_req_dout,
    output wire                           dma_wr_mpt_req_empty,
    
    input  wire                           dma_wr_mtt_req_rd_en,
    output wire  [DMA_WR_HD_WIDTH-1:0]    dma_wr_mtt_req_dout,
    output wire                           dma_wr_mtt_req_empty

    `ifdef V2P_DUG
    //apb_slave
    //ceu_tptm_proc
    // ,  input wire [`CEUTPTM_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_ceutptm
    // //mptm_proc
    // ,  input wire [`MPTM_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mptm
    // //mttm_proc
    // ,  input wire [`MTTM_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mttm
    //tptmdata    
        ,  input wire [(`TPTM_DBG_RW_NUM) * 32 - 1 : 0]   rw_data
        ,  output wire [(`TPTM_DBG_REG_NUM) * 32 - 1 : 0]   wv_dbg_bus_tptm
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

`ifdef V2P_DUG
    //apb_slave
    //ceu_tptm_proc
    wire [`CEUTPTM_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_ceutptm;
    //mptm_proc
    wire [`MPTM_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mptm;
    //mttm_proc
    wire [`MTTM_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mttm;
`endif

// sub_module start
wire ceu_start;
wire mptm_start;
wire mttm_start;


wire                  mptm_req_rd_en;
wire  [103:0]         mptm_req_dout;
wire                  mptm_req_empty;

wire                  mptm_rd_en;
wire [`DT_WIDTH-1:0]  mptm_dout;
wire                  mptm_empty;

wire                  mttm_req_rd_en;
wire   [103:0]        mttm_req_dout;
wire                  mttm_req_empty;

wire                  mttm_rd_en;
wire [`DT_WIDTH-1:0]  mttm_dout;
wire                  mttm_empty;

assign ceu_start =  !ceu_req_empty;
assign mptm_start = !mpt_req_empty || !mptm_req_empty;
assign mttm_start = !mtt_req_empty || !mttm_req_empty;

// sub_module finish
wire ceu_finish;
wire mptm_finish;
wire mttm_finish;

//registers
reg [1:0] fsm_cs;
reg [1:0] fsm_ns;

//state machine localparams
//IDLE
localparam IDLE    = 2'b01;
//PROC
localparam PROC    = 2'b10;


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
            if(ceu_start || mptm_start || mttm_start) begin
                fsm_ns = PROC;
            end
            else
                fsm_ns = IDLE;
        end 
        PROC: begin
            if (ceu_finish && mptm_finish && mttm_finish) begin
                fsm_ns = IDLE;
            end else begin
                fsm_ns = PROC;
            end
        end
        default: fsm_ns = IDLE;
    endcase
end

//-----------------Stage 3 :Output Decode----------

//-----------ceu_tptm_proc--mptm/mttm req header format---------
//high------------------------low
//| ---------104 bit------------|
//|  type | opcode | num | addr |
//|    4  |   4    | 32  |  64  |
//|-----------------------------|

//-----------ceu_tptm_proc--mptm/mttm payload format---------
//high------------------------low
//| ---------256 bit------------|
//|``````| virt addr | phy addr |
//|``````|    64     |    64    |
//|-----------------------------|

//-----------MPT/MTT-mptm/mttm req header format---------
//high------------------------low
//| ---------99 bit-----|
//| opcode | num | addr |
//|    3   | 32  |  64  |
//|-----------------------------|

//-----------mptm/mttm--DMA Read req header format---------
//high------------------------low
//| -----------163 bit----------|
//| index | opcode | len | addr |
//|  64   |    3   | 32  |  64  |
//|--------------------------==-|

//-----------mptm/mttm--DMA Write req header format---------
//high------------------------low
//|-----99 bit----------|
//| opcode | len | addr |
//|    3   | 32  |  64  |
//|---------------------|

ceu_tptm_proc #(
    .CEU_HD_WIDTH (CEU_HD_WIDTH))
    u_ceu_tptm_proc(
    .clk        (clk),
    .rst        (rst),
    .ceu_start  (ceu_start),
    .ceu_finish (ceu_finish),
    // internal TPTMeteData write request header froCEU 
    //128 width header format
    .ceu_req_dout      (ceu_req_dout),
    .ceu_req_empty     (ceu_req_empty),
    .ceu_req_rd_en     (ceu_req_rd_en),
    // internel TPT metaddata from CEU 
    // 256 width (only TPT meatadata)
    .mdata_rd_en       (mdata_rd_en),
    .mdata_dout        (mdata_dout),
    .mdata_empty       (mdata_empty),
    //extract mptmdata request to mptmdata submodule
    .mptm_req_rd_en    (mptm_req_rd_en),
    .mptm_req_dout     (mptm_req_dout),
    .mptm_req_empty    (mptm_req_empty),
    //extract mptmdata payload to mptmdata submodule
    .mptm_rd_en        (mptm_rd_en),
    .mptm_dout         (mptm_dout),
    .mptm_empty        (mptm_empty),
    //extract mttmdata request to mttmdata submodule
    .mttm_req_rd_en    (mttm_req_rd_en),
    .mttm_req_dout     (mttm_req_dout),
    .mttm_req_empty    (mttm_req_empty),
    //extract mttmdata payload to mttmdata submodule
    .mttm_rd_en        (mttm_rd_en),
    .mttm_dout         (mttm_dout),
    .mttm_empty        (mttm_empty)
    
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[ 0*32 +: `CEUTPTM_DBG_RW_NUM * 32])
        , .wv_dbg_bus_ceutptm(wv_dbg_bus_ceutptm)
    `endif
);

mptm_proc #(
    .TPT_HD_WIDTH (TPT_HD_WIDTH),
    .DMA_RD_HD_WIDTH (DMA_RD_HD_WIDTH),
    .DMA_WR_HD_WIDTH (DMA_WR_HD_WIDTH),
    .CEU_HD_WIDTH (CEU_HD_WIDTH),
    .MPTM_RAM_DWIDTH (MPTM_RAM_DWIDTH),
    .MPTM_RAM_AWIDTH (MPTM_RAM_AWIDTH),
    .MPTM_RAM_DEPTH  (MPTM_RAM_DEPTH))    
    u_mptm_proc(
    .clk         (clk),
    .rst         (rst),
    /*Spyglass*/
    //.mptm_start  (mptm_start),
    /*Action = Delete*/
    .mptm_finish (mptm_finish),

	.global_mem_init_finish(global_mem_init_finish),
	.init_wea(init_wea),
	.init_addra(init_addra),
	.init_dina(init_dina),

    //mptmdata request from ceu_tptm_proc
    .mptm_req_rd_en    (mptm_req_rd_en),
    .mptm_req_dout     (mptm_req_dout),
    .mptm_req_empty    (mptm_req_empty),
    //mptmdata payload from ceu_tptm_proc
    .mptm_rd_en        (mptm_rd_en),
    .mptm_dout         (mptm_dout),
    .mptm_empty        (mptm_empty),
    //MPT Request interface
    .mpt_req_rd_en     (mpt_req_rd_en),
    .mpt_req_dout      (mpt_req_dout),
    .mpt_req_empty     (mpt_req_empty),    
    //MPT get mpt_base for compute index in mpt_ram
    .mpt_base_addr     (mpt_base_addr), 
    //DMA Read Ctx Request interface
    .dma_rd_mpt_req_rd_en   (dma_rd_mpt_req_rd_en),
    .dma_rd_mpt_req_dout    (dma_rd_mpt_req_dout),
    .dma_rd_mpt_req_empty   (dma_rd_mpt_req_empty),
    //DMA Write Ctx Request interface
    .dma_wr_mpt_req_rd_en  (dma_wr_mpt_req_rd_en),  
    .dma_wr_mpt_req_dout   (dma_wr_mpt_req_dout),
    .dma_wr_mpt_req_empty  (dma_wr_mpt_req_empty)  

    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[`CEUTPTM_DBG_RW_NUM *32 +: `MPTM_DBG_RW_NUM * 32])
        ,  .wv_dbg_bus_mptm(wv_dbg_bus_mptm)
    `endif    
);

mttm_proc #(
    .TPT_HD_WIDTH (TPT_HD_WIDTH),
    .DMA_RD_HD_WIDTH (DMA_RD_HD_WIDTH),
    .DMA_WR_HD_WIDTH (DMA_WR_HD_WIDTH),
    .CEU_HD_WIDTH (CEU_HD_WIDTH),
    .MTTM_RAM_DWIDTH (MTTM_RAM_DWIDTH),
    .MTTM_RAM_AWIDTH (MTTM_RAM_AWIDTH),
    .MTTM_RAM_DEPTH  (MTTM_RAM_DEPTH))
    u_mttm_proc(
    .clk         (clk),
    .rst         (rst),
    /*Spyglass*/
    //.mttm_start  (mttm_start), 
    /*Action = Delete*/
    
    .mttm_finish (mttm_finish),

	.global_mem_init_finish(global_mem_init_finish),
	.init_wea(init_wea),
	.init_addra(init_addra),
	.init_dina(init_dina),

    //mttmdata request from ceu_tptm_proc
    .mttm_req_rd_en    (mttm_req_rd_en),
    .mttm_req_dout     (mttm_req_dout),
    .mttm_req_empty    (mttm_req_empty),
    //mttmdata payload from ceu_tptm_proc
    .mttm_rd_en        (mttm_rd_en),
    .mttm_dout         (mttm_dout),
    .mttm_empty        (mttm_empty),
    //mtt Request interface
    .mtt_req_rd_en     (mtt_req_rd_en),
    .mtt_req_dout      (mtt_req_dout),
    .mtt_req_empty     (mtt_req_empty),
    //MTT get mtt_base for compute index in mtt_ram
    .mtt_base_addr     (mtt_base_addr), 
    //DMA Read Ctx Request interface
    .dma_rd_mtt_req_rd_en   (dma_rd_mtt_req_rd_en),
    .dma_rd_mtt_req_dout    (dma_rd_mtt_req_dout),
    .dma_rd_mtt_req_empty   (dma_rd_mtt_req_empty),
    //DMA Write Ctx Request interface
    .dma_wr_mtt_req_rd_en  (dma_wr_mtt_req_rd_en),  
    .dma_wr_mtt_req_dout   (dma_wr_mtt_req_dout),
    .dma_wr_mtt_req_empty  (dma_wr_mtt_req_empty)  

    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[(`CEUTPTM_DBG_RW_NUM + `MPTM_DBG_RW_NUM) *32 +:  `MTTM_DBG_RW_NUM* 32])
        ,  .wv_dbg_bus_mttm (wv_dbg_bus_mttm)
    `endif

);

`ifdef V2P_DUG
    // /*****************Add for APB-slave regs**********************************/ 
        // reg [1:0] fsm_cs;
        // reg [1:0] fsm_ns;     
    /*****************Add for APB-slave wires**********************************/         
        // input  wire  [`HD_WIDTH-1:0]   ceu_req_dout,
        // input  wire                    ceu_req_empty,
        // output wire                    ceu_req_rd_en,
        // output wire                    mdata_rd_en,
        // input  wire  [`DT_WIDTH-1:0]   mdata_dout,
        // input  wire                    mdata_empty,
        // output wire                        mpt_req_rd_en,
        // input  wire  [TPT_HD_WIDTH-1:0]    mpt_req_dout,
        // input  wire                        mpt_req_empty,
        // output wire                        mtt_req_rd_en,
        // input  wire  [TPT_HD_WIDTH-1:0]    mtt_req_dout,
        // input  wire                        mtt_req_empty,
        // output wire  [63:0]                mtt_base_addr, 
        // output wire  [63:0]                mpt_base_addr, 
        // input  wire                           dma_rd_mpt_req_rd_en,
        // output wire  [DMA_RD_HD_WIDTH-1:0]    dma_rd_mpt_req_dout,
        // output wire                           dma_rd_mpt_req_empty,
        // input  wire                           dma_rd_mtt_req_rd_en,
        // output wire  [DMA_RD_HD_WIDTH-1:0]    dma_rd_mtt_req_dout,
        // output wire                           dma_rd_mtt_req_empty,
        // input  wire                           dma_wr_mpt_req_rd_en,
        // output wire  [DMA_WR_HD_WIDTH-1:0]    dma_wr_mpt_req_dout,
        // output wire                           dma_wr_mpt_req_empty,
        // input  wire                           dma_wr_mtt_req_rd_en,
        // output wire  [DMA_WR_HD_WIDTH-1:0]    dma_wr_mtt_req_dout,
        // output wire                           dma_wr_mtt_req_empty
        // wire ceu_start;
        // wire mptm_start;
        // wire mttm_start;
        // wire                  mptm_req_rd_en;
        // wire  [103:0]         mptm_req_dout;
        // wire                  mptm_req_empty;
        // wire                  mptm_rd_en;
        // wire [`DT_WIDTH-1:0]  mptm_dout;
        // wire                  mptm_empty;
        // wire                  mttm_req_rd_en;
        // wire   [103:0]        mttm_req_dout;
        // wire                  mttm_req_empty;
        // wire                  mttm_rd_en;
        // wire [`DT_WIDTH-1:0]  mttm_dout;
        // wire                  mttm_empty;
        // wire ceu_finish;
        // wire mptm_finish;
        // wire mttm_finish;
        // input wire [`CEUTPTM_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_ceutptm
        // input wire [`MPTM_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mptm
        // input wire [`MTTM_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mttm
      
    //Total regs and wires : 9060 = 283*32+4

    //apb_slave
    //tptmdata = {tptmdata's debug signals, ceu_tptm_proc, mptm_proc, mttm_proc}
    
    assign wv_dbg_bus_tptm = {
        28'b0,
        fsm_cs,
        fsm_ns,   
        // ceu_req_dout,
        // ceu_req_empty,
        // ceu_req_rd_en,
        // mdata_rd_en,
        // mdata_dout,
        // mdata_empty,
        // mpt_req_rd_en,
        // mpt_req_dout,
        // mpt_req_empty,
        // mtt_req_rd_en,
        // mtt_req_dout,
        // mtt_req_empty,
        // mtt_base_addr,
        // mpt_base_addr,
        // dma_rd_mpt_req_rd_en,
        // dma_rd_mpt_req_dout,
        // dma_rd_mpt_req_empty,
        // dma_rd_mtt_req_rd_en,
        // dma_rd_mtt_req_dout,
        // dma_rd_mtt_req_empty,
        // dma_wr_mpt_req_rd_en,
        // dma_wr_mpt_req_dout,
        // dma_wr_mpt_req_empty,
        // dma_wr_mtt_req_rd_en,
        // dma_wr_mtt_req_dout,
        // dma_wr_mtt_req_empty,
        // ceu_start,
        // mptm_start,
        // mttm_start,
        // mptm_req_rd_en,
        // mptm_req_dout,
        // mptm_req_empty,
        // mptm_rd_en,
        // mptm_dout,
        // mptm_empty,
        // mttm_req_rd_en,
        // mttm_req_dout,
        // mttm_req_empty,
        // mttm_rd_en,
        // mttm_dout,
        // mttm_empty,
        // ceu_finish,
        // mptm_finish,
        // mttm_finish,        
        wv_dbg_bus_ceutptm,
        wv_dbg_bus_mptm,
        wv_dbg_bus_mttm
    };
    
`endif

endmodule
