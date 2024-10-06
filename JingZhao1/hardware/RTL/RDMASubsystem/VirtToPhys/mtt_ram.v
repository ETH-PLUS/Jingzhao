//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: mtt_ram.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V0.0 
// VERSION DESCRIPTION: 1st Edition  
//----------------------------------------------------
// RELEASE DATE: 2020-12-29
//---------------------------------------------------- 
// PURPOSE: mtt ram space
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
// 
//-FHDR-----------------------------------------------
//                        --------------                              
//                        |   Cache   |                               
//                        --------------                              
//                    / 1.      | 2.      \ 3.                        
//                   /  look_up | update   \  replace                         
//                  /           | match     \   write mtt                       
//                 /            | refill     \     refill                   
// |--stage1:lookup-|----stage2:update-------|-----stage3:replace-----|
// | rd tagv(rd,wr) |      match tagv,       |  wr data(wr or miss),  |
// |   rd data(rd), |     rd lru(miss),      |    wr dirty (write)    |
// |                |    rd dirty(miss),     |       wr lru(all),     |
// |                |   ldst_stall(hit),     |      wr tagv(miss ),   |
// |                |  allow_in(0 in miss)   |                        |
// |                |    out rd data(rd),    |                        |
// |----------------|------------------------|------------------------|--------------------
// |                |                        |out cache line(replace),| dma_wr_mpt FIFO    : dma_write_ctx module
// |                | wait&rd dma resp(miss) |                        | dma_v2p_mpt_rd_rsp : dma engine module
// |                |  out miss addr(miss),  |   out addr(replace),   | mttmdata req FIFO  : mttmdata module
// |----------------|------------------------|------------------------|--------------------
//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_v2p_h.vh"

module mtt_ram#(
    parameter MTT_SIZE        =   524288, //Total Size(MPT+MTT) 1MB, mtt_RAM occupies 512KB, valid addr width= l8
    parameter CACHE_WAY_NUM   =   2,//2 way
    parameter LINE_SIZE       =   32,//Cache line size = 32B(mtt entry= 8B)
    parameter INDEX           =   13,//mtt_ram index width
    parameter TAG             =   3,//mtt_ram tag width
    parameter OFFSET          =   2,//mtt_ram offset width
    parameter NUM             =   3,//mtt_ram num width to indicate how many mtt entries in 1 cache line
    parameter TPT_HD_WIDTH    =   99,//for mtt-mttdata req header fifo
    parameter CACHE_BANK_NUM  =   4//1 way BRAM num = 4
    )(
    input clk,
    input rst,

	input 	wire 											global_mem_init_finish,
	input	wire 											init_wea,
	input	wire 	[`V2P_MEM_MAX_ADDR_WIDTH - 1 : 0]		init_addra,
	input	wire 	[`V2P_MEM_MAX_DIN_WIDTH - 1 : 0]		init_dina,

    //pipeline 1 
        //out allow input signal 
        output wire                          lookup_allow_in,
        //in to pipeline 1: lookup info addr={32,lookup_tag,lookup_index}
        input  wire                          lookup_rden ,
        input  wire                          lookup_wren ,
        input  wire [LINE_SIZE*8-1:0]        lookup_wdata, //4 mtt entry size, {0,NUM of valid mtt data}
        input  wire [INDEX -1     :0]        lookup_index, //
        input  wire [TAG -1       :0]        lookup_tag  , //
        input  wire [OFFSET -1    :0]        lookup_offset  , //indicate the offset in 1 cacheline
        input  wire [NUM -1       :0]        lookup_num  , //indicate the mtt number in 1 cacheline
        // add EQ function
        input  wire                         mtt_eq_addr, 
    //pipeline 2
        //lookup state info out wire(all these state infos are stored in state out fifo)
        output wire [2:0]                    lookup_state, // | 2<->miss | 1<->hit | 0<->idle |
        output wire                          lookup_ldst , // 1 for store, and 0 for load
        output wire                          state_valid , // valid in normal state, invalid if stall
        // use wire to give lookup results
        //hit mtt entry out, for mtt info match and mtt lookup    
        output wire [LINE_SIZE*8-1:0]        hit_rdata,        
        //miss mtt entry out, for mtt info match and mtt lookup    
        output wire [LINE_SIZE*8-1:0]        miss_rdata,
        // receive dma resp data in this module
        //read MPT Ctx payload response from DMA Engine module     
        output  wire                           dma_v2p_mtt_rd_rsp_tready,
        input   wire                           dma_v2p_mtt_rd_rsp_tvalid,
        input   wire [`DT_WIDTH-1:0]           dma_v2p_mtt_rd_rsp_tdata,
        input   wire                           dma_v2p_mtt_rd_rsp_tlast,
        input   wire [`HD_WIDTH-1:0]           dma_v2p_mtt_rd_rsp_theader,

    // stall in pipeline 2 and 3: //if miss mtt_ram_ctl need stall the output of lookup stage
        input  wire                         lookup_stall, 
                 
    //pipeline 3 replace: write back         
        //write mtt Ctx payload to dma_write_ctx module
        input  wire                          dma_wr_mtt_rd_en,
        output wire  [`DT_WIDTH-1:0]         dma_wr_mtt_dout, // write back replace data
        output wire                          dma_wr_mtt_empty,

    //pipeline 2 and pipeline 3: mttmdata module req  
        //miss read req out fifo, for mttmdata initiate dma read req in pipeline 2
        //replace write req out fifo, for mttmdata initiate dma write req in pipeline 3
        input  wire                          mttm_req_rd_en,
        output wire  [TPT_HD_WIDTH-1:0]      mttm_req_dout,//miss_addr or replace addr
        output wire                          mttm_req_empty


    `ifdef V2P_DUG
    //apb_slave
        ,  input wire [`MTT_DBG_RW_NUM * 32 - 1 : 0]   rw_data
        ,  output wire [`MTT_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mtt
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


//--------------{variable declaration}begin---------------//
// pipeline handshaking
    wire    lookup_valid_out; //lookup_data ready
    wire    lookup_2_update; // data in lookup will go to the update
    
    reg     update_valid_in;  //used to judge update stage state: idle, miss, or hit
    wire    update_allow_in;  //update stage ready to receive lookup date
    wire    update_valid_out; //update date ready
    wire    update_2_replace; // data in lookup will go to the update

    reg     replace_valid_in; //used to judge replace_en signal
    wire    replace_allow_in; //replace stage ready

// cache data inout signals
    wire         rd_en_tagv[0:(CACHE_WAY_NUM-1)];
    wire         rd_en_dirty[0:(CACHE_WAY_NUM-1)];
    wire         rd_en_data[0:(CACHE_WAY_NUM*CACHE_BANK_NUM-1)];
    wire         rd_en_lru;

    wire         wr_en_tagv[0:(CACHE_WAY_NUM-1)];
    wire         wr_en_dirty[0:(CACHE_WAY_NUM-1)];
    wire         wr_en_data[0:(CACHE_WAY_NUM*CACHE_BANK_NUM-1)];
    wire         wr_en_lru;

    wire [INDEX -1 :0]  rd_addr_tagv;
    wire [INDEX -1 :0]  rd_addr_dirty;
    wire [INDEX -1 :0]  rd_addr_data;
    wire [INDEX -1 :0]  rd_addr_lru;

    wire [INDEX -1 :0]  wr_addr_tagv;
    wire [INDEX -1 :0]  wr_addr_dirty;
    wire [INDEX -1 :0]  wr_addr_data;
    wire [INDEX -1 :0]  wr_addr_lru;

    //change the din/dout data format to 2D matrix
    wire [TAG          :0]                 din_tagv ;
    wire                                   din_dirty;
    wire [LINE_SIZE/CACHE_BANK_NUM*8-1:0]  din_data [0:(CACHE_WAY_NUM*CACHE_BANK_NUM-1)];
    wire                                   din_lru  ;

    wire [TAG          :0]                 dout_tagv  [0:(CACHE_WAY_NUM-1)];
    wire                                   dout_dirty [0:(CACHE_WAY_NUM-1)];
    wire [LINE_SIZE/CACHE_BANK_NUM*8-1:0]  dout_data  [0:(CACHE_WAY_NUM*CACHE_BANK_NUM-1)];
    wire                                   dout_lru;

// lookup to update stage
    reg                     lookup_rden_pipe2  ;
    reg                     lookup_wren_pipe2  ;
    reg [LINE_SIZE*8-1:0]   lookup_wdata_pipe2 ;
    reg [INDEX -1 :0]       lookup_index_pipe2 ;
    reg [TAG-1        :0]   lookup_tag_pipe2   ;
    // add offset, num info 
    reg [OFFSET -1    :0]   lookup_offset_pipe2;
    reg [NUM -1       :0]   lookup_num_pipe2   ;
    //TODO: add eq function, for phy addr flags
    reg eq_addr_pipe2;
// data in pipe2: update
    //this signal used to stall the pipeline when the req out fifo or hit out fifo in stage 2 or stage 3 is prog full
    wire                   update_stall; 
    //match state
    wire ismatch_way; //1(exist dout hit the tag and valid)
    wire match_way;   //1(way 1);0(way 0)
    wire miss_pipe2;  //stage1 valid income but miss
    reg  q_miss_pipe2;//store the miss state
    wire hit_pipe2;   //stage1 valid income and hit
    wire idle_pipe2;  //stage1 invalid income
    //read data
    wire                   load_op;         //hit read
    wire [LINE_SIZE*8-1:0] dout_data_way0;
    wire [LINE_SIZE*8-1:0] dout_data_way1;
    wire [LINE_SIZE*8-1:0] match_rdata;
    //miss info
    /*Spyglass*/
    //wire [31:0]            miss_addr;
    wire [63:0]            miss_addr;
    /*Action = Modify*/

    //write data
    wire                   store_op ;       //write miss, write hit, or read miss 
    wire [LINE_SIZE*8-1:0] store_din;
    wire [INDEX -1 :0]     update_index;
    //replace 
    wire [INDEX -1 :0]     replace_index; //used to read dirty and lru
    wire                   replace_op;    //miss cause replace
    // wire                   forward_pass;

    //miss read addr reg, for dma response data to refill
    /*Spyglass*/
    //reg   [31:0]                  qv_miss_addr;//read mtt req(miss_addr);
    reg   [63:0]                  qv_miss_addr;
    /*Action = Modify*/
    

// update to replace stage
    // add read_miss,write_hit signal
    reg               miss_pipe3         ;//update tag,valid,lru,data
    //reg               read_miss_pipe3    ;//update tag,valid,lru,data
    reg               write_miss_pipe3   ;//update tag,valid,lru,data,dirty
    reg               read_hit_pipe3     ;//only update lru,data,dirty
    reg               write_hit_pipe3    ;//update lru
    reg               store_op_pipe3     ;//write miss, write hit, or read miss, use to update cache data,lru 
    reg [TAG      :0] tagv_way0_pipe3    ;//tagv from stage2     
    reg [TAG      :0] tagv_way1_pipe3    ;//tagv from stage2
    reg [TAG-1    :0] lookup_tag_pipe3   ;//tag from stage2
    reg [INDEX -1 :0] replace_index_pipe3;//used to write req to mttmdata
    // reg               ldst_stall_pipe3   ;
    //regs added for update to replace pipe data transfer
    reg [INDEX -1 :0]     update_index_pipe3;
    reg                   match_way_pipe3;
    reg [LINE_SIZE*8-1:0] store_din_pipe3   ;//miss or write hit 
    reg [LINE_SIZE*8-1:0] dout_data_way0_pipe3;//transfer 2 way data for replace
    reg [LINE_SIZE*8-1:0] dout_data_way1_pipe3;
    reg [OFFSET -1    :0]   lookup_offset_pipe3;
    reg [NUM -1       :0]   lookup_num_pipe3   ;

// data in pipe3: replace & refill
    wire                   replace_lru; //hold the replace_lru info, if write miss or stall
    wire                   replace_en;  //hold the signal for indicating that we need write back
    wire  [63:0]           replace_addr;
    wire                   idle_pipe3;
    //write mtt Ctx payload to dma_write_ctx module
    wire                         dma_wr_mtt_wr_en;
    wire                         dma_wr_mtt_prog_full;
    wire  [`DT_WIDTH-1:0]        dma_wr_mtt_din;// write back replace data

//in pipeline 2 and pipeline 3: mttmdata module req  
    //miss read req out fifo, for mttmdata initiate dma read req in pipeline 2
    //replace write req out fifo, for mttmdata initiate dma write req in pipeline 3
    wire                          mttm_req_wr_en;
    wire                          mttm_req_prog_full;
    wire  [TPT_HD_WIDTH-1:0]      mttm_req_din;//read mtt req(miss_addr); or replace write mtt req(replace_addr)
//--------------{variable declaration}end---------------//
//----------{Cache} ----begin-------------------//
genvar w, b;
generate
    for (w = 0; w < 2; w = w+1) begin: way
        bram_mtt_tagv_4w8192d_simdaulp mtt_tagv(
            .clka     (clk),
            .ena      (ram_init_finish ? wr_en_tagv[w] : init_wea),
            .wea      (ram_init_finish ? wr_en_tagv[w] : init_wea), // i 1
            .addra    (ram_init_finish ? wr_addr_tagv : init_addra[12:0]),  // i 13
            .dina     (ram_init_finish ? din_tagv : init_dina[3:0]),      // i 4
            .clkb     (clk),
            .enb      (rd_en_tagv[w]), // i 1
            .addrb    (rd_addr_tagv),  // i 13
            .doutb    (dout_tagv[w])   // o 4
            `ifdef V2P_DUG
            //apb_slave
                , .rw_data(rw_data[w * 32 +: 1 * 32])        
            `endif
        );
        bram_mtt_dirty_1w8192d_simdaulp mtt_dirty(
            .clka     (clk),
            .ena      (ram_init_finish ? wr_en_dirty[w] : init_wea),    // i 1
            .wea      (ram_init_finish ? wr_en_dirty[w] : init_wea),    // i 1
            .addra    (ram_init_finish ? wr_addr_dirty : init_addra[12:0]),     // i 13
            .dina     (ram_init_finish ? din_dirty : init_dina[0]),         // i 1
            .clkb     (clk),
            .enb      (rd_en_dirty[w]),    // i 1
            .addrb    (rd_addr_dirty),     // i 13
            .doutb    (dout_dirty[w])      // o 1
            `ifdef V2P_DUG
            //apb_slave
                , .rw_data(rw_data[(2+w) * 32 +: 1 * 32])        
            `endif
        );
        for (b = 0; b < 4; b = b+1) begin: bank
            bram_mtt_data_64w8192d_simdaulp mtt_data(
                .clka     (clk),
                .ena      (ram_init_finish ? wr_en_data[w*CACHE_BANK_NUM+b] : init_wea), // i 1 
                .wea      (ram_init_finish ? wr_en_data[w*CACHE_BANK_NUM+b] : init_wea), // i 1 
                .addra    (ram_init_finish ? wr_addr_data : init_addra[12:0]),                   // i 13
                .dina     (ram_init_finish ? din_data[w*CACHE_BANK_NUM+b] : init_dina[63:0]),   // i 64 bit
                .clkb     (clk),
                .enb      (rd_en_data[w*CACHE_BANK_NUM+b]), // i 1
                .addrb    (rd_addr_data),                   // i 13
                .doutb    (dout_data[w*CACHE_BANK_NUM+b])   // o 64 bit
                `ifdef V2P_DUG
                //apb_slave
                    , .rw_data(rw_data[(4+w*4+b) * 32 +: 1 * 32])        
                `endif
            );
        end
    end
endgenerate
bram_mtt_lru_1w8192d_simdaulp  mtt_lru(     // store the way which is not used recently.
    .clka     (clk),
    .ena      (ram_init_finish ? wr_en_lru : init_wea),    // i 1
    .wea      (ram_init_finish ? wr_en_lru : init_wea),    // i 1
    .addra    (ram_init_finish ? wr_addr_lru : init_addra[12:0]),  // i 13
    .dina     (ram_init_finish ? din_lru : init_dina[0]),      // i 1
    .clkb     (clk),
    .enb      (rd_en_lru),   // i 1
    .addrb    (rd_addr_lru),  // i 123
    .doutb    (dout_lru)      // o 1
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[12 * 32 +: 1 * 32])        
    `endif
);
//----------{Cache}end--------------------------------//

//------------------{FIFO output interface}begin----------------//

    //pipeline 3 replace: write mtt Ctx payload to dma_write_ctx module
        dma_wr_mpt_fifo_256w16d dma_wr_mtt_fifo_256w16d_Inst(
            .clk        (clk),
            .srst       (rst),
            .wr_en      (dma_wr_mtt_wr_en),
            .rd_en      (dma_wr_mtt_rd_en),
            .din        (dma_wr_mtt_din),
            .dout       (dma_wr_mtt_dout),
            .full       (),
            /*VCS Verification*/
            // .empty      (dma_wr_mtt_req_empty),     
            // .prog_full  (dma_wr_mtt_req_prog_full)
            .empty      (dma_wr_mtt_empty),     
            .prog_full  (dma_wr_mtt_prog_full)
            /*Action = Modify, signals connected error*/
            `ifdef V2P_DUG
            //apb_slave
                , .rw_data(rw_data[13 * 32 +: 1 * 32])        
            `endif
        ); 
    //pipeline 2 and pipeline 3: dma req header fifo to mttmdata module 
        //miss read req out fifo, for mttmdata initiate dma read req in pipeline 2
        //replace write req out fifo, for mttmdata initiate dma write req in pipeline 3
        mptm_req_fifo_99w16d mttm_req_fifo_99w16d_Inst(
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
                , .rw_data(rw_data[14 * 32 +: 1 * 32])        
            `endif
        ); 
  
//------------------{FIFO output interface}  end----------------//

//--------------------------{Three stages pipeline}begin-----------------------//

//----------{stage1: lookup}begin------------//
// assign lookup_allow_in  = update_allow_in;
// Modify, add dma mtt reaponse signal to avoid mtt_ram read-write conflict
assign lookup_allow_in  = update_allow_in && !dma_v2p_mtt_rd_rsp_tready && !dma_v2p_mtt_rd_rsp_tvalid;
assign lookup_valid_out = (lookup_rden | lookup_wren);
/*VCS Verification*/
// assign lookup_2_update  = lookup_valid_out & update_allow_in & update_2_replace;
assign lookup_2_update  = lookup_valid_out & update_allow_in & (update_valid_out | idle_pipe2) & replace_allow_in;
/*Action = Modify, add other conditions except update_2_replace*/
//----------{stage1: lookup}end------------//

//----------{Arbiter for ram access}begin----------------//
// ram operation
assign rd_en_tagv[0] = lookup_2_update ? 1'd1 : 1'd0; // stage 1: if stage2 is ready, read tagv
assign rd_en_tagv[1] = lookup_2_update ? 1'd1 : 1'd0; // stage 1: if stage2 is ready, read tagv

assign rd_en_data[0] = lookup_2_update ? 1'd1 : 1'd0; // stage 1: if stage2 is ready, read data
assign rd_en_data[1] = lookup_2_update ? 1'd1 : 1'd0; // stage 1: if stage2 is ready, read data
assign rd_en_data[2] = lookup_2_update ? 1'd1 : 1'd0; // stage 1: if stage2 is ready, read data
assign rd_en_data[3] = lookup_2_update ? 1'd1 : 1'd0; // stage 1: if stage2 is ready, read data
assign rd_en_data[4] = lookup_2_update ? 1'd1 : 1'd0; // stage 1: if stage2 is ready, read data
assign rd_en_data[5] = lookup_2_update ? 1'd1 : 1'd0; // stage 1: if stage2 is ready, read data
assign rd_en_data[6] = lookup_2_update ? 1'd1 : 1'd0; // stage 1: if stage2 is ready, read data
assign rd_en_data[7] = lookup_2_update ? 1'd1 : 1'd0; // stage 1: if stage2 is ready, read data

assign rd_en_dirty[0] = replace_op & update_2_replace ?  1'd1 : 1'd0;    // stage 2: write/read miss and stage3 is ready, read dirty
assign rd_en_dirty[1] = replace_op & update_2_replace ?  1'd1 : 1'd0;    // stage 2: write/read miss and stage3 is ready, read dirty

assign rd_en_lru     =  replace_op & update_2_replace ?  1'd1 : 1'd0;    // stage 2: write/read miss and stage3 is ready, read lru

assign wr_en_tagv[0]  = (miss_pipe3 & (replace_lru==0)) ? 1'b1 : 1'd0;   // write/read miss to refill: stage 3 change tagv
assign wr_en_tagv[1]  = (miss_pipe3 & (replace_lru==1)) ? 1'b1 : 1'd0;   // write/read miss to refill: stage 3 change tagv

// write/read miss or write hit; stage 3 store the part/whole hit/replace cache line data 
assign wr_en_data[0] = ((miss_pipe3 & (replace_lru==0)) | ((match_way_pipe3==0) & write_hit_pipe3 & 
                            (lookup_offset_pipe3==0) & (lookup_num_pipe3 > 0))) ? 1'b1  : 'd0; 
assign wr_en_data[1] = ((miss_pipe3 & (replace_lru==0)) | ((match_way_pipe3==0) & write_hit_pipe3 & (
                            ((lookup_offset_pipe3==0) & (lookup_num_pipe3 > 1)) | 
                            ((lookup_offset_pipe3==1) & (lookup_num_pipe3 > 0))))) ? 1'b1  : 'd0;  
assign wr_en_data[2] = ((miss_pipe3 & (replace_lru==0)) | ((match_way_pipe3==0) & write_hit_pipe3 & (
                            ((lookup_offset_pipe3==0) & (lookup_num_pipe3 > 2)) | 
                            ((lookup_offset_pipe3==1) & (lookup_num_pipe3 > 1)) | 
                            ((lookup_offset_pipe3==2) & (lookup_num_pipe3 > 0))))) ? 1'b1  : 'd0;  
assign wr_en_data[3] = ((miss_pipe3 & (replace_lru==0)) | ((match_way_pipe3==0) & write_hit_pipe3 & (
                            ((lookup_offset_pipe3==0) & (lookup_num_pipe3 > 3)) | 
                            ((lookup_offset_pipe3==1) & (lookup_num_pipe3 > 2)) | 
                            ((lookup_offset_pipe3==2) & (lookup_num_pipe3 > 1)) | 
                            ((lookup_offset_pipe3==3) & (lookup_num_pipe3 > 0))))) ? 1'b1  : 'd0;  
assign wr_en_data[4] = ((miss_pipe3 & (replace_lru==1)) | ((match_way_pipe3==1) & write_hit_pipe3 & 
                            (lookup_offset_pipe3==0) & (lookup_num_pipe3 > 0))) ? 1'b1  : 'd0; 
assign wr_en_data[5] = ((miss_pipe3 & (replace_lru==1)) | ((match_way_pipe3==1) & write_hit_pipe3 & (
                            ((lookup_offset_pipe3==0) & (lookup_num_pipe3 > 1)) | 
                            ((lookup_offset_pipe3==1) & (lookup_num_pipe3 > 0))))) ? 1'b1  : 'd0; 
assign wr_en_data[6] = ((miss_pipe3 & (replace_lru==1)) | ((match_way_pipe3==1) & write_hit_pipe3 & (
                            ((lookup_offset_pipe3==0) & (lookup_num_pipe3 > 2)) | 
                            ((lookup_offset_pipe3==1) & (lookup_num_pipe3 > 1)) | 
                            ((lookup_offset_pipe3==2) & (lookup_num_pipe3 > 0))))) ? 1'b1  : 'd0; 
assign wr_en_data[7] = ((miss_pipe3 & (replace_lru==1)) | ((match_way_pipe3==1) & write_hit_pipe3 & (
                            ((lookup_offset_pipe3==0) & (lookup_num_pipe3 > 3)) | 
                            ((lookup_offset_pipe3==1) & (lookup_num_pipe3 > 2)) | 
                            ((lookup_offset_pipe3==2) & (lookup_num_pipe3 > 1)) | 
                            ((lookup_offset_pipe3==3) & (lookup_num_pipe3 > 0))))) ? 1'b1  : 'd0; 

assign wr_en_dirty[0] = (((match_way_pipe3==0) & write_hit_pipe3) | 
                         ((replace_lru==0) & write_miss_pipe3)) ? 1'b1  : 'd0; // hit/miss write; stage 3 change dirty
assign wr_en_dirty[1] = (((match_way_pipe3==1) & write_hit_pipe3) | 
                         ((replace_lru==1) & write_miss_pipe3)) ? 1'b1 : 1'd0; // hit/miss write; stage 3 change dirty

assign wr_en_lru    =    store_op_pipe3 | read_hit_pipe3;    // write/read miss/hit stage 3 always change lru

// Modify in 2023.03.07 for Ram keep rd_en when the raddr change
// assign rd_addr_tagv  = lookup_2_update ? lookup_index : 'd0; // stage 1: lookup, read tagv
// assign rd_addr_data  = lookup_2_update ? lookup_index : 'd0; // stage 1: lookup, read data
assign rd_addr_tagv  = lookup_2_update ? lookup_index : lookup_index_pipe2; // stage 1: lookup, read tagv
assign rd_addr_data  = lookup_2_update ? lookup_index : lookup_index_pipe2; // stage 1: lookup, read data

assign rd_addr_dirty = replace_op ? replace_index : 'd0;     // stage 2(write/read miss): need replace, read dirty
assign rd_addr_lru   = replace_op ? replace_index : 'd0;     // stage 2(write/read miss): need replace, read lru

assign wr_addr_tagv  = (miss_pipe3) ? update_index_pipe3 : 'd0;                 // wr/rd miss          : stage 3 store tagv
assign wr_addr_data  = (store_op_pipe3) ? update_index_pipe3 : 'd0;                     // wr/rd miss or wr hit: stage 3 store data
assign wr_addr_dirty = (write_hit_pipe3 | write_miss_pipe3 ) ? update_index_pipe3 : 'd0;// wr                  : stage 3 change dirty
assign wr_addr_lru   = (store_op_pipe3 | read_hit_pipe3) ? update_index_pipe3 : 'd0;    // wr/rd miss/hit      : stage 3 change lru

assign din_tagv  = (miss_pipe3) ? {lookup_tag_pipe3,1'b1} : 'd0;           // wr/rd miss          : stage 3 store tagv

assign din_data[0]  = (store_op_pipe3) ? store_din_pipe3[1*64-1:0*64] : 'd0;       // wr/rd miss or wr hit: stage 3 store data
assign din_data[1]  = (store_op_pipe3) ? store_din_pipe3[2*64-1:1*64] : 'd0;       // wr/rd miss or wr hit: stage 3 store data
assign din_data[2]  = (store_op_pipe3) ? store_din_pipe3[3*64-1:2*64] : 'd0;       // wr/rd miss or wr hit: stage 3 store data
assign din_data[3]  = (store_op_pipe3) ? store_din_pipe3[4*64-1:3*64] : 'd0;       // wr/rd miss or wr hit: stage 3 store data
assign din_data[4]  = (store_op_pipe3) ? store_din_pipe3[1*64-1:0*64] : 'd0;       // wr/rd miss or wr hit: stage 3 store data
assign din_data[5]  = (store_op_pipe3) ? store_din_pipe3[2*64-1:1*64] : 'd0;       // wr/rd miss or wr hit: stage 3 store data
assign din_data[6]  = (store_op_pipe3) ? store_din_pipe3[3*64-1:2*64] : 'd0;       // wr/rd miss or wr hit: stage 3 store data
assign din_data[7]  = (store_op_pipe3) ? store_din_pipe3[4*64-1:3*64] : 'd0;       // wr/rd miss or wr hit: stage 3 store data

assign din_dirty = (write_hit_pipe3 | write_miss_pipe3) ? 1'd1 : 1'd0;             // wr                  : stage 3 dirty = 1
assign din_lru   = (store_op_pipe3 | read_hit_pipe3) ? (~match_way_pipe3) : 1'd0;  // wr/rd miss/hit      : stage 3 lru = !hit_way;
//----------{Arbiter for ram access}end-------------------------------//

//-----------{Lookup to Update}begin----------------//
//reg update_valid_in
always @(posedge clk or posedge rst) begin
    if (rst) begin
        update_valid_in <= `TD 1'd0;
    end
    else if (update_allow_in) begin
        update_valid_in <= `TD lookup_valid_out;
    end
    else if (update_valid_out) begin
        update_valid_in <= `TD 1'd0;
    end
    else begin
        update_valid_in <= `TD update_valid_in;
    end
end
//lookup to update reg
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lookup_rden_pipe2   <= `TD 'd0;
        lookup_wren_pipe2   <= `TD 'd0;
        lookup_wdata_pipe2  <= `TD 'd0;
        lookup_index_pipe2  <= `TD 'd0;
        lookup_tag_pipe2    <= `TD 'd0;
        lookup_offset_pipe2 <= `TD 'd0;
        lookup_num_pipe2    <= `TD 'd0;
        q_miss_pipe2        <= `TD 'd0;
        //TODO: add eq funciton
        eq_addr_pipe2 <= `TD 1'b0;
    end
    else if (lookup_2_update) begin
        lookup_rden_pipe2   <= `TD lookup_rden  ;
        lookup_wren_pipe2   <= `TD lookup_wren  ;
        lookup_wdata_pipe2  <= `TD lookup_wdata ;
        lookup_index_pipe2  <= `TD lookup_index ;
        lookup_tag_pipe2    <= `TD lookup_tag   ;
        lookup_offset_pipe2 <= `TD lookup_offset;
        lookup_num_pipe2    <= `TD lookup_num;        
        q_miss_pipe2        <= `TD 'd0;
        //TODO: add eq funciton
        eq_addr_pipe2 <= `TD mtt_eq_addr;        
    end 
    // hold the search data for miss
    else if (lookup_stall | miss_pipe2) begin
        lookup_rden_pipe2   <= `TD lookup_rden_pipe2 ;
        lookup_wren_pipe2   <= `TD lookup_wren_pipe2 ;
        lookup_wdata_pipe2  <= `TD lookup_wdata_pipe2;
        lookup_index_pipe2  <= `TD lookup_index_pipe2;
        lookup_tag_pipe2    <= `TD lookup_tag_pipe2   ;
        lookup_offset_pipe2 <= `TD lookup_offset_pipe2;
        lookup_num_pipe2    <= `TD lookup_num_pipe2   ;
        q_miss_pipe2        <= `TD miss_pipe2 | q_miss_pipe2;
        //TODO: add eq funciton
        eq_addr_pipe2 <= `TD 1'b0;
    end
    else begin
        lookup_rden_pipe2   <= `TD 'd0;
        lookup_wren_pipe2   <= `TD 'd0;
        lookup_wdata_pipe2  <= `TD 'd0;
        lookup_index_pipe2  <= `TD 'd0;
        lookup_tag_pipe2    <= `TD 'd0;
        lookup_offset_pipe2 <= `TD 'd0;
        lookup_num_pipe2    <= `TD 'd0;
        q_miss_pipe2        <= `TD 'd0;
        //TODO: add eq funciton
        eq_addr_pipe2 <= `TD 1'b0;
    end
end
//-----------{Lookup to Update}end----------------//

//----------{stage2: update (match, out miss req, rd lru,dirty)}begin------------//
// handshaking
// consider:(1) !lookup_stall & pipe2 idle  
//          (2) !lookup_stall & !pipe2 idle & miss data back !mttm_req_prog_full
//          (3) !lookup_stall & !pipe2 idle & hit 
assign update_allow_in = !lookup_stall & (idle_pipe2 | 
        (q_miss_pipe2 & dma_v2p_mtt_rd_rsp_tready & dma_v2p_mtt_rd_rsp_tvalid & dma_v2p_mtt_rd_rsp_tlast & !mttm_req_prog_full) | hit_pipe2);
        
// indicates that data for stage3 ready
// consider:(1) !pipe2 idle & miss data back & !update_stall
//          (2) !pipe2 idle & hit & !update_stall
assign update_valid_out = (q_miss_pipe2 & dma_v2p_mtt_rd_rsp_tready & dma_v2p_mtt_rd_rsp_tvalid & dma_v2p_mtt_rd_rsp_tlast) | hit_pipe2; 

// wire                   update_stall; 
// this signal used to stall the pipeline when stage 2 miss
    assign update_stall = miss_pipe2;
    assign update_2_replace = update_valid_out & replace_allow_in;

// match state
    //ismatch_way, match_way;
    //miss_pipe2, hit_pipe2, idle_pipe2;
    //TODO: add eq function, always match
    // assign ismatch_way = (dout_tagv[0] == {lookup_tag_pipe2, 1'd1}) | (dout_tagv[1] == {lookup_tag_pipe2, 1'd1});
    assign ismatch_way = eq_addr_pipe2 ? 1 : ((dout_tagv[0] == {lookup_tag_pipe2, 1'd1}) | (dout_tagv[1] == {lookup_tag_pipe2, 1'd1}));

    assign match_way   = ((dout_tagv[0] == {lookup_tag_pipe2, 1'd1}) & 1'd0) |
                         ((dout_tagv[1] == {lookup_tag_pipe2, 1'd1}) & 1'd1);
    assign miss_pipe2 =  (update_valid_in & !ismatch_way);// (update_valid_in & !ismatch_way) & !wen_tagv_inst;
    assign hit_pipe2  =  (update_valid_in & ismatch_way);
    assign idle_pipe2 = !update_valid_in;

//read MPT Ctx payload response from DMA Engine module     
    //output  wire                           dma_v2p_mtt_rd_rsp_tready,
    /*VCS Verification*/
    // assign dma_v2p_mtt_rd_rsp_tready = lookup_stall;
    assign dma_v2p_mtt_rd_rsp_tready = update_stall & replace_allow_in;
    /*Action = Modify, use update_stall to enable dma_v2p_mtt_rd_rsp_tready*/
    //input   wire                           dma_v2p_mtt_rd_rsp_tvalid,
    //input   wire [`DT_WIDTH-1:0]           dma_v2p_mtt_rd_rsp_tdata,
    //input   wire                           dma_v2p_mtt_rd_rsp_tlast,
    //input   wire [`HD_WIDTH-1:0]           dma_v2p_mtt_rd_rsp_theader,
    //miss mtt entry out, for mtt info match and mtt lookup    
    //output wire [LINE_SIZE*8-1:0]        miss_rdata,
    assign miss_rdata = (dma_v2p_mtt_rd_rsp_tready & dma_v2p_mtt_rd_rsp_tvalid & dma_v2p_mtt_rd_rsp_tlast & lookup_rden_pipe2 & q_miss_pipe2) ? dma_v2p_mtt_rd_rsp_tdata : 0;

// read data
    //wire                   load_op; 
    //wire [LINE_SIZE*8-1:0] dout_data_way0;
    //wire [LINE_SIZE*8-1:0] dout_data_way1;
    //wire [LINE_SIZE*8-1:0] match_rdata;
    assign load_op        = hit_pipe2 & lookup_rden_pipe2;
    assign dout_data_way0 = {dout_data[3],dout_data[2],dout_data[1],dout_data[0]};
    assign dout_data_way1 = {dout_data[7],dout_data[6],dout_data[5],dout_data[4]};
    assign match_rdata = match_way ? dout_data_way1 : dout_data_way0;

// write data
    //wire                   store_op ;//write miss, write hit, or read miss 
    //wire [LINE_SIZE*8-1:0] store_din;
    //wire [INDEX -1 :0]     update_index;
    assign store_op     = (q_miss_pipe2 & (lookup_rden_pipe2 | lookup_wren_pipe2)) | (hit_pipe2 & lookup_wren_pipe2);
    //joint the data use the old data and dma resp data
    reg [LINE_SIZE*8-1:0] qv_wr_miss_data;
    always @(*) begin
        if (rst) begin
            qv_wr_miss_data = 0;
        end else begin
            case (lookup_offset_pipe2)
                2'b00: begin
                    case (lookup_num_pipe2)
                        // 3'b000: qv_wr_miss_data = 0;
                        3'b001: qv_wr_miss_data = {dma_v2p_mtt_rd_rsp_tdata[64*4-1:64*1],lookup_wdata_pipe2[64*1-1:0]};
                        3'b010: qv_wr_miss_data = {dma_v2p_mtt_rd_rsp_tdata[64*4-1:64*2],lookup_wdata_pipe2[64*2-1:0]};
                        3'b011: qv_wr_miss_data = {dma_v2p_mtt_rd_rsp_tdata[64*4-1:64*3],lookup_wdata_pipe2[64*3-1:0]};
                        3'b100: qv_wr_miss_data = {lookup_wdata_pipe2[64*4-1:0]};
                        // default: qv_wr_miss_data = 0;
                        default: qv_wr_miss_data = dma_v2p_mtt_rd_rsp_tdata;
                    endcase
                end
                2'b01: begin
                    case (lookup_num_pipe2)
                        // 3'b000: qv_wr_miss_data = 0;
                        3'b001: qv_wr_miss_data = {dma_v2p_mtt_rd_rsp_tdata[64*4-1:64*2],lookup_wdata_pipe2[64*2-1:64*1],dma_v2p_mtt_rd_rsp_tdata[64*1-1:0]};
                        3'b010: qv_wr_miss_data = {dma_v2p_mtt_rd_rsp_tdata[64*4-1:64*3],lookup_wdata_pipe2[64*3-1:64*1],dma_v2p_mtt_rd_rsp_tdata[64*1-1:0]};
                        3'b011: qv_wr_miss_data = {lookup_wdata_pipe2[64*4-1:64*1],dma_v2p_mtt_rd_rsp_tdata[64*1-1:0]};
                        // default: qv_wr_miss_data = 0;
                        default: qv_wr_miss_data = dma_v2p_mtt_rd_rsp_tdata;
                    endcase
                end
                2'b10: begin
                    case (lookup_num_pipe2)
                        // 3'b000: qv_wr_miss_data = 0;
                        3'b001: qv_wr_miss_data = {dma_v2p_mtt_rd_rsp_tdata[64*4-1:64*3],lookup_wdata_pipe2[64*3-1:64*2],dma_v2p_mtt_rd_rsp_tdata[64*2-1:0]};
                        3'b010: qv_wr_miss_data = {lookup_wdata_pipe2[64*4-1:64*2],dma_v2p_mtt_rd_rsp_tdata[64*2-1:0]};
                        // default: qv_wr_miss_data = 0;
                        default: qv_wr_miss_data = dma_v2p_mtt_rd_rsp_tdata;
                    endcase
                end 
                2'b11: begin
                    case (lookup_num_pipe2)
                        // 3'b000: qv_wr_miss_data = 0;
                        3'b001: qv_wr_miss_data = {lookup_wdata_pipe2[64*4-1:64*3],dma_v2p_mtt_rd_rsp_tdata[64*3-1:0]};
                        // default: qv_wr_miss_data = 0;
                        default: qv_wr_miss_data = dma_v2p_mtt_rd_rsp_tdata;
                    endcase
                end
                default: qv_wr_miss_data = 0;
            endcase
        end
    end
    assign store_din = (hit_pipe2 & lookup_wren_pipe2) ? lookup_wdata_pipe2 : 
                       (q_miss_pipe2 & lookup_rden_pipe2) ? dma_v2p_mtt_rd_rsp_tdata :
                       (q_miss_pipe2 & lookup_wren_pipe2) ? qv_wr_miss_data : 0;
    assign update_index = lookup_index_pipe2;

// output state and cached data
    //wire [LINE_SIZE*8-1:0] hit_rdata,
    //wire [63:0]            miss_addr,
    assign hit_rdata  = hit_pipe2 ? match_rdata : 'd0;
    // miss_addr is the request addr. if we use the miss_addr to initiate dma req, we should clear offset 
    assign miss_addr = (miss_pipe2 | q_miss_pipe2) ? {46'b0, lookup_tag_pipe2, lookup_index_pipe2, lookup_offset_pipe2} : 0;

// miss match
    //wire [INDEX -1 :0]     replace_index; //used to read dirty and lru
    //wire                   replace_op;    // write or read miss will cause replace
    assign replace_op = (miss_pipe2 | q_miss_pipe2) & (lookup_wren_pipe2 | lookup_rden_pipe2); 
    assign replace_index = lookup_index_pipe2;
    
//miss read addr reg, for dma response data to refill
    //reg   [63:0]     qv_miss_addr;//read mtt req(miss_addr);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_miss_addr <= `TD 0;
        end
        else if (miss_pipe2) begin
            qv_miss_addr <= `TD miss_addr;
        end
        else begin
            qv_miss_addr <= `TD qv_miss_addr;
        end
    end

// lookup state info out
    //output wire [2:0]   lookup_state, // | 2<->miss | 1<->hit | 0<->idle |
    //output wire         lookup_ldst , // 1 for store, and 0 for load  
    //output wire         state_valid   , // valid in process state, invalid if stall or idle
    assign lookup_state = {q_miss_pipe2, hit_pipe2, idle_pipe2};
    assign lookup_ldst  = ((|lookup_wren_pipe2) & 1'd1) | (lookup_rden_pipe2 & 1'd0);
    /*VCS Verification */
    assign state_valid  = update_valid_out ? 1'd1 : 1'd0;
    // assign state_valid  = (update_valid_out | idle_pipe2) ? 1'd1 : 1'd0;
    /*Action = Modify, add idle_pipe2 to indicate lookup allow_in */
    assign state_wr_en  = update_valid_out;
    assign state_din    = {lookup_state,lookup_ldst,state_valid};

//----------{stage2: update (match, out miss req, rd lru,dirty)}end------------//

//-----------{Update to Replace}begin----------------//
// replace_valid_in
always @(posedge clk or posedge rst) begin
    if (rst) begin
        replace_valid_in <= `TD 1'd0;
    end
    else if (replace_allow_in) begin
        replace_valid_in <= `TD update_valid_out;
    end
    else begin
        replace_valid_in <= `TD 'd0;
    end
end
// update to replace stage  
   //reg               read_miss_pipe3    ;//update tag,valid,lru,data
   //reg               write_miss_pipe3   ;//update tag,valid,lru,data,dirty
   //reg               read_hit_pipe3     ;//only update lru,data,dirty
   //reg               write_hit_pipe3    ;//update lru
   //reg [OFFSET -1:0] lookup_offset_pipe3;
   //reg [NUM -1   :0] lookup_num_pipe3   ;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        miss_pipe3            <= `TD 'b0;
        //read_miss_pipe3       <= `TD 'b0;
        write_miss_pipe3      <= `TD 'b0;
        read_hit_pipe3        <= `TD 'b0;
        write_hit_pipe3       <= `TD 'b0;
        store_op_pipe3        <= `TD 'b0;
        tagv_way0_pipe3       <= `TD 'b0;
        tagv_way1_pipe3       <= `TD 'b0;
        lookup_tag_pipe3      <= `TD 'b0;
        replace_index_pipe3   <= `TD 'b0;
        update_index_pipe3    <= `TD 'b0; 
        match_way_pipe3       <= `TD 'b0; 
        store_din_pipe3       <= `TD 'b0; 
        dout_data_way0_pipe3  <= `TD 'b0; 
        dout_data_way1_pipe3  <= `TD 'b0; 
        lookup_offset_pipe3   <= `TD 'b0;
        lookup_num_pipe3      <= `TD 'b0;
    end
    else if (update_2_replace) begin      
        miss_pipe3            <= `TD (miss_pipe2 | q_miss_pipe2);
        write_miss_pipe3      <= `TD (miss_pipe2 | q_miss_pipe2) & lookup_wren_pipe2;
        read_hit_pipe3        <= `TD hit_pipe2 & lookup_rden_pipe2;
        /*Spyglass*/
        write_hit_pipe3       <= `TD hit_pipe2 & lookup_wren_pipe2;
        /*Action = Add*/
        store_op_pipe3        <= `TD store_op;
        tagv_way0_pipe3       <= `TD dout_tagv[0];
        tagv_way1_pipe3       <= `TD dout_tagv[1];
        lookup_tag_pipe3      <= `TD lookup_tag_pipe2;
        replace_index_pipe3   <= `TD replace_index;
        update_index_pipe3    <= `TD update_index;
        match_way_pipe3       <= `TD match_way;
        store_din_pipe3       <= `TD store_din;
        dout_data_way0_pipe3  <= `TD dout_data_way0;
        dout_data_way1_pipe3  <= `TD dout_data_way1;
        lookup_offset_pipe3   <= `TD lookup_offset_pipe2;
        lookup_num_pipe3      <= `TD lookup_num_pipe2;
    end
    else begin
        miss_pipe3            <= `TD 'b0;
        write_miss_pipe3      <= `TD 'b0;
        read_hit_pipe3        <= `TD 'b0;
        write_hit_pipe3       <= `TD 'b0;
        store_op_pipe3        <= `TD 'b0;
        tagv_way0_pipe3       <= `TD 'b0;
        tagv_way1_pipe3       <= `TD 'b0;
        lookup_tag_pipe3      <= `TD 'b0;
        replace_index_pipe3   <= `TD 'b0;
        update_index_pipe3    <= `TD 'b0; 
        match_way_pipe3       <= `TD 'b0; 
        store_din_pipe3       <= `TD 'b0; 
        dout_data_way0_pipe3  <= `TD 'b0; 
        dout_data_way1_pipe3  <= `TD 'b0; 
        lookup_offset_pipe3   <= `TD 'b0;
        lookup_num_pipe3      <= `TD 'b0;
    end
end
//-----------{Update to Replace}end----------------//

//----------{Stage3: Replace (write mtt, replace, write back)}begin-----------------//
//handshaking
    //wire idle_pipe3;
    assign idle_pipe3 = !replace_valid_in;
    //wire    replace_allow_in; 
    //consider: (1) dma req fifo isn't full; (2) dma payload fifo isn't full
    /*VCS Verification*/
    assign replace_allow_in = !mttm_req_prog_full & !dma_wr_mtt_prog_full;
    // assign replace_allow_in = !mttm_req_prog_full & !dma_wr_mtt_prog_full & !miss_pipe3;
    /*Action = Modify, add !miss_pipe3 to avoid wr_mttm_req in stage2 and stage3 at the same clk*/

// data in pipe3: replace
    //wire                   replace_lru;
    //wire                   replace_en;
    assign replace_lru  = dout_lru;
    assign replace_en   = replace_valid_in & (replace_lru ? dout_dirty[1] : dout_dirty[0]) & miss_pipe3;
    //wire [63:0]  replace_addr;
    // assign replace_addr = {46'b0, (replace_lru ? tagv_way1_pipe3 : tagv_way0_pipe3), replace_index_pipe3, 2'b0};
    assign replace_addr = {46'b0, (replace_lru ? tagv_way1_pipe3[3:1] : tagv_way0_pipe3[3:1]), replace_index_pipe3, 2'b0};

//write mtt Ctx payload to dma_write_ctx module
    //wire                    dma_wr_mtt_wr_en;
    //consider: repalce_en, mtt fifo isn't full
    assign dma_wr_mtt_wr_en = replace_en & !dma_wr_mtt_prog_full;
    //wire  [`DT_WIDTH-1:0]   dma_wr_mtt_din;// write back replace data
    //consider: (1)wr_en; (2)mtt_cnt indicates the seg in dout_data; (3)replace_lru indidates the way write back
    assign dma_wr_mtt_din = (dma_wr_mtt_wr_en & replace_lru) ? dout_data_way1_pipe3 :
                           (dma_wr_mtt_wr_en & !replace_lru) ? dout_data_way0_pipe3 : 0;
//----------{Stage3: Replacee (write mtt, replace, write back)}end-----------------//

//------------------{in pipeline 2 and pipeline 3: req header to mttmdata module }begin---------------//
    //miss read req out fifo, for mttmdata initiate dma read req in pipeline 2

    //replace write req out fifo, for mttmdata initiate dma write req in pipeline 3
    //-----------mtt-mttm req header format---------
        //high------------------------low
        //| ---------99 bit-----|
        //| opcode | num | addr |
        //|    3   | 32  |  64  |
        //|---------------------|
    //wire                          mttm_req_wr_en,
    //consider: (1) 1st clk in stage2 read miss and req fifo isn't full; (2)stage3 write miss and req fifo isn't full
    /*VCS Verification*/
    //Add (3) miss write and req fifo isn't full in stage 2
    //use reg to update wr_en signal
    reg q_mttm_req_wr_en;
    reg [TPT_HD_WIDTH-1:0] q_mttm_req_din;
    reg mttm_req_cnt;//make sure that mttm req once in stage 2
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            q_mttm_req_wr_en <= `TD 0;
            q_mttm_req_din <= `TD 0;
        end
        else if ((miss_pipe2 & (lookup_rden_pipe2 | lookup_wren_pipe2)) & !mttm_req_prog_full & !mttm_req_cnt) begin
            q_mttm_req_wr_en <= `TD 1;
            q_mttm_req_din <= `TD 0;
        end
        else if (replace_en & !mttm_req_prog_full) begin
            q_mttm_req_wr_en <= `TD 1;
            q_mttm_req_din <= `TD {`MTT_WR,32'b100,replace_addr};
        end
        else begin
            q_mttm_req_wr_en <= `TD 0;
            q_mttm_req_din <= `TD 0;
        end
    end    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mttm_req_cnt <= `TD 0;
        end
        else if ((miss_pipe2 & (lookup_rden_pipe2 | lookup_wren_pipe2)) & !mttm_req_prog_full & !mttm_req_cnt) begin
            mttm_req_cnt <= `TD 1;
        end
        else if (q_miss_pipe2 & dma_v2p_mtt_rd_rsp_tready & dma_v2p_mtt_rd_rsp_tvalid & dma_v2p_mtt_rd_rsp_tlast) begin
            mttm_req_cnt <= `TD 0;
        end
        else begin
            mttm_req_cnt <= `TD mttm_req_cnt;
        end
    end
    // assign mttm_req_wr_en = ((miss_pipe2 & lookup_rden_pipe2) | replace_en) & !mttm_req_prog_full;
    assign mttm_req_wr_en = q_mttm_req_wr_en;
    /*Action = Modify, TODO: maybe consider the write req number is 4 no need for initiating read request*/
    //wire  [TPT_HD_WIDTH-1:0]      mttm_req_din,
    //consider:(1) read 1 cache line mtt req (`MTT_RD,num=4,miss_addr); miss_addr set offset = 0, write cache_line
    //         (2) replace write back 1 cache line mtt req (`MTT_WR,num=4,replace_addr)
    // miss_addr is the request addr. if we use the miss_addr to initiate dma req, we should clear offset 
    /*VCS Verification*/
    //Add (3) miss write and req fifo isn't full in stage 2
    // assign mttm_req_din = (miss_pipe2 & lookup_rden_pipe2 & !mttm_req_prog_full) ? {`MTT_RD,32'b100,miss_addr[63:OFFSET],2'b0} 
    //                     : (replace_en & !mttm_req_prog_full) ? {`MTT_WR,32'b100,replace_addr} : 0;
    // assign mttm_req_din = (miss_pipe2 & (lookup_rden_pipe2 | lookup_wren_pipe2) & !mttm_req_prog_full & mttm_req_wr_en) ? {`MTT_RD,32'b100,miss_addr[63:OFFSET],2'b0} 
    //                     : (replace_en & !mttm_req_prog_full & mttm_req_wr_en) ? {`MTT_WR,32'b100,replace_addr} : 0;
    // assign mttm_req_din = (miss_pipe2 & (lookup_rden_pipe2 | lookup_wren_pipe2) & !mttm_req_prog_full & mttm_req_wr_en) ? {`MTT_RD,32'b100,miss_addr[63:OFFSET],2'b0} 
    //                     : (!mttm_req_prog_full & mttm_req_wr_en) ? {`MTT_WR,32'b100,replace_addr} : 0;
    assign mttm_req_din = (miss_pipe2 & (lookup_rden_pipe2 | lookup_wren_pipe2) & !mttm_req_prog_full & mttm_req_wr_en) ? {`MTT_RD,32'b100,miss_addr[63:OFFSET],2'b0} 
                        : (!mttm_req_prog_full & mttm_req_wr_en) ? q_mttm_req_din : 0;

    /*Action = Modify, TODO: maybe consider the write req number is 4 no need for initiating read request*/
//------------------{in pipeline 2 and pipeline 3: mttmdata module req}begin---------------//

`ifdef V2P_DUG
    // /*****************Add for APB-slave regs**********************************/ 
        // reg     update_valid_in;
        // reg     replace_valid_in;
        // reg                     lookup_rden_pipe2  ;
        // reg                     lookup_wren_pipe2  ;
        // reg [LINE_SIZE*8-1:0]   lookup_wdata_pipe2 ;
        // reg [INDEX -1 :0]       lookup_index_pipe2 ;
        // reg [TAG-1        :0]   lookup_tag_pipe2   ;
        // reg [OFFSET -1    :0]   lookup_offset_pipe2;
        // reg [NUM -1       :0]   lookup_num_pipe2   ;
        // reg eq_addr_pipe2;
        // reg  q_miss_pipe2;
        // reg   [63:0]                  qv_miss_addr;
        // reg               miss_pipe3         ;
        // reg               write_miss_pipe3   ;
        // reg               read_hit_pipe3     ;
        // reg               write_hit_pipe3    ;
        // reg               store_op_pipe3     ;
        // reg [TAG      :0] tagv_way0_pipe3    ;
        // reg [TAG      :0] tagv_way1_pipe3    ;
        // reg [TAG-1    :0] lookup_tag_pipe3   ;
        // reg [INDEX -1 :0] replace_index_pipe3;
        // reg [INDEX -1 :0]     update_index_pipe3;
        // reg                   match_way_pipe3;
        // reg [LINE_SIZE*8-1:0] store_din_pipe3   ;
        // reg [LINE_SIZE*8-1:0] dout_data_way0_pipe3;
        // reg [LINE_SIZE*8-1:0] dout_data_way1_pipe3;
        // reg [OFFSET -1    :0]   lookup_offset_pipe3;
        // reg [NUM -1       :0]   lookup_num_pipe3   ;
        // reg [LINE_SIZE*8-1:0] qv_wr_miss_data;
        // reg q_mttm_req_wr_en;
        // reg mttm_req_cnt;

    /*****************Add for APB-slave wires**********************************/         
        // output wire                          lookup_allow_in,
        // input  wire                          lookup_rden ,
        // input  wire                          lookup_wren ,
        // input  wire [LINE_SIZE*8-1:0]        lookup_wdata,
        // input  wire [INDEX -1     :0]        lookup_index,
        // input  wire [TAG -1       :0]        lookup_tag  ,
        // input  wire [OFFSET -1    :0]        lookup_offset  ,
        // input  wire [NUM -1       :0]        lookup_num  ,
        // input  wire                         mtt_eq_addr, 
        // output wire [2:0]                    lookup_state,
        // output wire                          lookup_ldst ,
        // output wire                          state_valid ,
        // output wire [LINE_SIZE*8-1:0]        hit_rdata,        
        // output wire [LINE_SIZE*8-1:0]        miss_rdata,
        // output  wire                           dma_v2p_mtt_rd_rsp_tready,
        // input   wire                           dma_v2p_mtt_rd_rsp_tvalid,
        // input   wire [`DT_WIDTH-1:0]           dma_v2p_mtt_rd_rsp_tdata,
        // input   wire                           dma_v2p_mtt_rd_rsp_tlast,
        // input   wire [`HD_WIDTH-1:0]           dma_v2p_mtt_rd_rsp_theader,
        // input  wire                         lookup_stall, 
        // input  wire                          dma_wr_mtt_rd_en,
        // output wire  [`DT_WIDTH-1:0]         dma_wr_mtt_dout,
        // output wire                          dma_wr_mtt_empty,
        // input  wire                          mttm_req_rd_en,
        // output wire  [TPT_HD_WIDTH-1:0]      mttm_req_dout,
        // output wire                          mttm_req_empty
        // wire    lookup_valid_out;
        // wire    lookup_2_update;
        // wire    update_allow_in;
        // wire    update_valid_out;
        // wire    update_2_replace;
        // wire    replace_allow_in;
        // wire         rd_en_tagv[0:(CACHE_WAY_NUM-1)];
        // wire         rd_en_dirty[0:(CACHE_WAY_NUM-1)];
        // wire         rd_en_data[0:(CACHE_WAY_NUM*CACHE_BANK_NUM-1)];
        // wire         rd_en_lru;
        // wire         wr_en_tagv[0:(CACHE_WAY_NUM-1)];
        // wire         wr_en_dirty[0:(CACHE_WAY_NUM-1)];
        // wire         wr_en_data[0:(CACHE_WAY_NUM*CACHE_BANK_NUM-1)];
        // wire         wr_en_lru;
        // wire [INDEX -1 :0]  rd_addr_tagv;
        // wire [INDEX -1 :0]  rd_addr_dirty;
        // wire [INDEX -1 :0]  rd_addr_data;
        // wire [INDEX -1 :0]  rd_addr_lru;
        // wire [INDEX -1 :0]  wr_addr_tagv;
        // wire [INDEX -1 :0]  wr_addr_dirty;
        // wire [INDEX -1 :0]  wr_addr_data;
        // wire [INDEX -1 :0]  wr_addr_lru;
        // wire [TAG          :0]                 din_tagv ;
        // wire                                   din_dirty;
        // wire [LINE_SIZE/CACHE_BANK_NUM*8-1:0]  din_data [0:(CACHE_WAY_NUM*CACHE_BANK_NUM-1)];
        // wire                                   din_lru  ;
        // wire [TAG          :0]                 dout_tagv  [0:(CACHE_WAY_NUM-1)];
        // wire                                   dout_dirty [0:(CACHE_WAY_NUM-1)];
        // wire [LINE_SIZE/CACHE_BANK_NUM*8-1:0]  dout_data  [0:(CACHE_WAY_NUM*CACHE_BANK_NUM-1)];
        // wire                                   dout_lru;
        // wire                   update_stall; 
        // wire ismatch_way;
        // wire match_way;
        // wire miss_pipe2;
        // wire hit_pipe2;
        // wire idle_pipe2;
        // wire                   load_op;
        // wire [LINE_SIZE*8-1:0] dout_data_way0;
        // wire [LINE_SIZE*8-1:0] dout_data_way1;
        // wire [LINE_SIZE*8-1:0] match_rdata;
        // wire [63:0]            miss_addr;
        // wire                   store_op ;
        // wire [LINE_SIZE*8-1:0] store_din;
        // wire [INDEX -1 :0]     update_index;
        // wire [INDEX -1 :0]     replace_index;
        // wire                   replace_op;
        // wire                   replace_lru;
        // wire                   replace_en;
        // wire  [63:0]           replace_addr;
        // wire                   idle_pipe3;
        // wire                         dma_wr_mtt_wr_en;
        // wire                         dma_wr_mtt_prog_full;
        // wire  [`DT_WIDTH-1:0]        dma_wr_mtt_din;
        // wire                          mttm_req_wr_en;
        // wire                          mttm_req_prog_full;
        // wire  [TPT_HD_WIDTH-1:0]      mttm_req_din;

    //Total regs and wires : 5692= 177*32+28

    assign wv_dbg_bus_mtt = {
        4'b0,
        update_valid_in,
        replace_valid_in,
        lookup_rden_pipe2,
        lookup_wren_pipe2,
        lookup_wdata_pipe2,
        lookup_index_pipe2,
        lookup_tag_pipe2,
        lookup_offset_pipe2,
        lookup_num_pipe2,
        eq_addr_pipe2,
        q_miss_pipe2,
        qv_miss_addr,
        miss_pipe3,
        write_miss_pipe3,
        read_hit_pipe3,
        write_hit_pipe3,
        store_op_pipe3,
        tagv_way0_pipe3,
        tagv_way1_pipe3,
        lookup_tag_pipe3,
        replace_index_pipe3,
        update_index_pipe3,
        match_way_pipe3,
        store_din_pipe3,
        dout_data_way0_pipe3,
        dout_data_way1_pipe3,
        lookup_offset_pipe3,
        lookup_num_pipe3,
        qv_wr_miss_data,
        q_mttm_req_wr_en,
        mttm_req_cnt,

        lookup_allow_in,
        lookup_rden,
        lookup_wren,
        lookup_wdata,
        lookup_index,
        lookup_tag,
        lookup_offset,
        lookup_num,
        mtt_eq_addr,
        lookup_state,
        lookup_ldst,
        state_valid,
        hit_rdata,
        miss_rdata,
        dma_v2p_mtt_rd_rsp_tready,
        dma_v2p_mtt_rd_rsp_tvalid,
        dma_v2p_mtt_rd_rsp_tdata,
        dma_v2p_mtt_rd_rsp_tlast,
        dma_v2p_mtt_rd_rsp_theader,
        lookup_stall,
        dma_wr_mtt_rd_en,
        dma_wr_mtt_dout,
        dma_wr_mtt_empty,
        mttm_req_rd_en,
        mttm_req_dout,
        mttm_req_empty,
        lookup_valid_out,
        lookup_2_update,
        update_allow_in,
        update_valid_out,
        update_2_replace,
        replace_allow_in,
        rd_en_tagv[0],
        rd_en_tagv[1],
        rd_en_dirty[0],
        rd_en_dirty[1],
        rd_en_data[0],
        rd_en_data[1],
        rd_en_data[2],
        rd_en_data[3],
        rd_en_data[4],
        rd_en_data[5],
        rd_en_data[6],
        rd_en_data[7],
        rd_en_lru,
        wr_en_tagv[0],
        wr_en_tagv[1],
        wr_en_dirty[0],
        wr_en_dirty[1],
        wr_en_data[0],
        wr_en_data[1],
        wr_en_data[2],
        wr_en_data[3],
        wr_en_data[4],
        wr_en_data[5],
        wr_en_data[6],
        wr_en_data[7],
        wr_en_lru,
        rd_addr_tagv,
        rd_addr_dirty,
        rd_addr_data,
        rd_addr_lru,
        wr_addr_tagv,
        wr_addr_dirty,
        wr_addr_data,
        wr_addr_lru,
        din_tagv,
        din_dirty,
        din_data[0],
        din_data[1],
        din_data[2],
        din_data[3],
        din_data[4],
        din_data[5],
        din_data[6],
        din_data[7],
        din_lru,
        dout_tagv[0],
        dout_tagv[1],
        dout_dirty[0],
        dout_dirty[1],
        dout_data[0],
        dout_data[1],
        dout_data[2],
        dout_data[3],
        dout_data[4],
        dout_data[5],
        dout_data[6],
        dout_data[7],
        dout_lru,
        update_stall,
        ismatch_way,
        match_way,
        miss_pipe2,
        hit_pipe2,
        idle_pipe2,
        load_op,
        dout_data_way0,
        dout_data_way1,
        match_rdata,
        miss_addr,
        store_op,
        store_din,
        update_index,
        replace_index,
        replace_op,
        replace_lru,
        replace_en,
        replace_addr,
        idle_pipe3,
        dma_wr_mtt_wr_en,
        dma_wr_mtt_prog_full,
        dma_wr_mtt_din,
        mttm_req_wr_en,
        mttm_req_prog_full,
        mttm_req_din
    };

`endif 

endmodule
