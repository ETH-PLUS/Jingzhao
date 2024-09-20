//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: mpt_ram.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V0.0 
// VERSION DESCRIPTION: 1st Edition  
//----------------------------------------------------
// RELEASE DATE: 2020-11-30
//---------------------------------------------------- 
// PURPOSE: mpt ram space
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
//                  /           | match     \   write mpt                       
//                 /            | refill     \     refill                   
// |--stage1:lookup-|----stage2:update------|-----stage3:replace-----|
// | rd tagv(rd,wr) |      match tagv,      |  out miss lru(miss),   |
// |   rd data(rd), |     rd lru(miss),     |   wr data,dirty(wr),   |
// |   valid_out,   |    rd dirty(miss),    |  wr lru(wr or rd hit), |
// |                |   ldst_stall(hit),    |    wr tagv(miss,wr),   |
// |                |  allow_in(0 in miss)  |                        |
// |                | out rd data(hit,rd),  |                        |
// |----------------|-----------------------|------------------------|--------------------
// |                |                       |out cache line(replace),| dma_wr_mpt FIFO    : dma_write_ctx module
// |                |  out miss addr(miss), |   out addr(replace),   | mptmdata req FIFO  : mptmdata module
// |----------------|-----------------------|------------------------|--------------------
//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_v2p_h.vh"
//
module mpt_ram#(
    parameter MPT_SIZE        =   524288, //Total Size(MPT+MTT) 1MB, MPT_RAM occupies 512KB
    parameter CACHE_WAY_NUM   =   2,//2 way
    parameter LINE_SIZE       =   64,//Cache line size = 64B(MPT entry= 64B)
    parameter INDEX           =   12,//mpt_ram index width
    parameter TAG             =   3,//mpt_ram tag width
    parameter TPT_HD_WIDTH    =   99,//for MPT-MPTdata req header fifo
    parameter CACHE_BANK_NUM  =   1
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
        input  wire [LINE_SIZE*8-1:0]        lookup_wdata, //1 MPT entry size
        input  wire [INDEX -1     :0]        lookup_index, //
        input  wire [TAG -1       :0]        lookup_tag  , //
        // add EQ function
        input  wire                         mpt_eq_addr,    
    //pipeline 2
        //lookup state info out wire(all these state infos are stored in state out fifo)
        /*Spyglass*/
        //output wire [2:0]                    lookup_state, // | 3<->miss | 2<->hit | 0<->idle |
        //output wire                          lookup_ldst , // 1 for store, and 0 for load
        //output wire                          state_valid , // valid in normal state, invalid if stall
        /*Action = Delete*/
        //lookup state out fifo
        input  wire                          state_rd_en , 
        output wire                          state_empty ,
        output wire [4:0]                    state_dout  ,//{lookup_state[2:0],lookup_ldst,state_valid}

        //hit mpt entry out fifo, for mpt info match and mtt lookup
        input  wire                          hit_data_rd_en,
        output wire                          hit_data_empty,         
        output wire [LINE_SIZE*8-1:0]        hit_data_dout,
        //miss read addr out fifo, for pending fifo addr to refill
        input  wire                          miss_addr_rd_en,
        output wire  [31:0]                  miss_addr_dout,
        output wire                          miss_addr_empty,

    // stall in pipeline 2 and 3: // stall the output of lookup stage
        input  wire                         lookup_stall, 
             
    //pipeline 3 replace: write back         
        //write MPT Ctx payload to dma_write_ctx module
        input  wire                         dma_wr_mpt_rd_en,
        output wire  [`DT_WIDTH-1:0]        dma_wr_mpt_dout, // write back replace data
        output wire                         dma_wr_mpt_empty,

    //pipeline 2 and pipeline 3: mptmdata module req  
        //miss read req out fifo, for mptmdata initiate dma read req in pipeline 2
        //replace write req out fifo, for mptmdata initiate dma write req in pipeline 3
        input  wire                          mptm_req_rd_en,
        output wire  [TPT_HD_WIDTH-1:0]      mptm_req_dout,//miss_addr or replace addr
        output wire                          mptm_req_empty

    `ifdef V2P_DUG
    //apb_slave
        ,  input wire [`MPT_DBG_RW_NUM * 32 - 1 : 0]   rw_data
        ,  output wire [`MPT_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mpt
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
    wire         rd_en_tagv  [0:(CACHE_WAY_NUM-1)];
    wire         rd_en_dirty [0:(CACHE_WAY_NUM-1)];
    wire         rd_en_data  [0:(CACHE_WAY_NUM*CACHE_BANK_NUM-1)];
    wire         rd_en_lru;

    wire         wr_en_tagv  [0:(CACHE_WAY_NUM-1)];
    wire         wr_en_dirty [0:(CACHE_WAY_NUM-1)];
    wire         wr_en_data  [0:(CACHE_WAY_NUM*CACHE_BANK_NUM-1)];
    wire         wr_en_lru;

    wire [INDEX -1 :0]  rd_addr_tagv;
    wire [INDEX -1 :0]  rd_addr_dirty;
    wire [INDEX -1 :0]  rd_addr_data;
    wire [INDEX -1 :0]  rd_addr_lru;

    wire [INDEX -1 :0]  wr_addr_tagv;
    wire [INDEX -1 :0]  wr_addr_dirty;
    wire [INDEX -1 :0]  wr_addr_data;
    wire [INDEX -1 :0]  wr_addr_lru;

    wire [TAG          :0]  din_tagv ;
    wire                    din_dirty;
    wire [LINE_SIZE*8-1:0]  din_data ;
    wire                    din_lru  ;

    wire [TAG          :0]  dout_tagv  [0:(CACHE_WAY_NUM-1)];
    wire                    dout_dirty [0:(CACHE_WAY_NUM-1)];
    wire [LINE_SIZE*8-1:0]  dout_data  [0:(CACHE_WAY_NUM*CACHE_BANK_NUM-1)];
    wire                    dout_lru;

// lookup to update stage
    reg                     lookup_rden_pipe2  ;
    reg                     lookup_wren_pipe2  ;
    reg [LINE_SIZE*8-1:0]   lookup_wdata_pipe2 ;
    reg [INDEX -1 :0]       lookup_index_pipe2 ;
    reg [TAG-1        :0]   lookup_tag_pipe2   ;
    //TODO: add eq function, for phy addr flags
    reg eq_addr_pipe2;

// data in pipe2: update
    //this signal used to stall the pipeline when the req out fifo or hit out fifo in stage 2 or stage 3 is prog full
    wire                   update_stall; 
    //match state
    wire ismatch_way; //1(exist dout hit the tag and valid)
    wire match_way;   //1(way 1);0(way 0)
    wire miss_pipe2;  //stage1 valid income but miss
    wire hit_pipe2;   //stage1 valid income and hit
    wire idle_pipe2;  //stage1 invalid income
    // lookup state info 
    wire [2:0]   lookup_state;// | 2<->miss | 1<->hit | 0<->idle |
    wire         lookup_ldst ;// 1 for store, and 0 for load  
    wire         state_valid ;// valid in process state, invalid if stall or idle
    //read data
    wire                   load_op;         //hit read
    wire [LINE_SIZE*8-1:0] dout_data_way0;
    wire [LINE_SIZE*8-1:0] dout_data_way1;
    wire [LINE_SIZE*8-1:0] match_rdata;
    //out data
    wire [LINE_SIZE*8-1:0] hit_data;
    wire [31:0]            miss_addr;
    //write data
    wire                   store_op ;       //hit write or miss write
    wire [LINE_SIZE*8-1:0] store_din;
    wire [INDEX -1 :0]     update_index;
    //replace 
    wire [INDEX -1 :0]     replace_index; //used to read dirty and lru
    wire                   replace_op;    //miss cause replace
    // wire                   forward_pass;
    //state out fifo 
    wire                          state_wr_en;
    wire                          state_prog_full;
    wire      [4:0]               state_din; 
    //hit data out fifo
    wire                          hit_data_wr_en;
    wire                          hit_data_prog_full;
    wire [LINE_SIZE*8-1:0]        hit_data_din; //hit_data
    //miss read addr out fifo, for pending fifo addr to refill
    wire                          miss_addr_wr_en;
    wire                          miss_addr_prog_full;
    wire  [31:0]                  miss_addr_din;//read mpt req(miss_addr);

// update to replace stage
    reg               miss_pipe3         ;
    reg               write_miss_pipe3   ;
    reg               read_hit_pipe3     ;//used to update lru
    reg               store_op_pipe3     ;//write hit or write miss or refill op
    reg [TAG      :0] tagv_way0_pipe3    ;//tagv from stage2     
    reg [TAG      :0] tagv_way1_pipe3    ;//tagv from 
    reg [TAG-1    :0] lookup_tag_pipe3   ;//write tag info from stage2
    reg [INDEX -1 :0] replace_index_pipe3;//used to write req to mptmdata
    // reg               ldst_stall_pipe3   ;
    //regs added for update to replace pipe data transfer
    reg [INDEX -1 :0]     update_index_pipe3;
    reg                   ismatch_way_pipe3;
    reg                   match_way_pipe3;
    reg [LINE_SIZE*8-1:0] store_din_pipe3   ;//write hit or write miss or refill data
    reg [LINE_SIZE*8-1:0] dout_data_way0_pipe3;//transfer 2 way data for replace
    reg [LINE_SIZE*8-1:0] dout_data_way1_pipe3;

// data in pipe3: replace & refill
    reg                    replace_lru; //hold the replace_lru info, if write miss or stall
    reg                    replace_en;  //hold the signal for indicating that we need write back
    wire  [63:0]           replace_addr;
    wire                   idle_pipe3;
    //write MPT Ctx payload to dma_write_ctx module
    wire                         dma_wr_mpt_wr_en;
    wire                         dma_wr_mpt_prog_full;
    wire  [`DT_WIDTH-1:0]        dma_wr_mpt_din;// write back replace data
    reg   [1:0]                  dma_wr_mpt_cnt;//count 2 cycle for finishing mpt entry trans

//in pipeline 2 and pipeline 3: mptmdata module req  
    //miss read req out fifo, for mptmdata initiate dma read req in pipeline 2
    //replace write req out fifo, for mptmdata initiate dma write req in pipeline 3
    wire                          mptm_req_wr_en;
    wire                          mptm_req_prog_full;
    wire  [TPT_HD_WIDTH-1:0]      mptm_req_din;//read mpt req(miss_addr); or replace write mpt req(replace_addr)
//--------------{variable declaration}end---------------//
//----------{Cache} ----begin-------------------//
genvar w, b;
generate
    for (w = 0; w < 2; w = w+1) begin: way
        bram_mpt_tagv_4w4096d_simdaulp mpt_tagv(
            .clka     (clk),
            .ena      (ram_init_finish ? wr_en_tagv[w] : init_wea), // i 1
            .wea      (ram_init_finish ? wr_en_tagv[w] : init_wea), // i 1
            .addra    (ram_init_finish ? wr_addr_tagv : init_addra[11:0]),  // i 12
            .dina     (ram_init_finish ? din_tagv : init_dina[3:0]),      // i 4
            .clkb     (clk),
            .enb      (rd_en_tagv[w]), // i 1
            .addrb    (rd_addr_tagv),  // i 12
            .doutb    (dout_tagv[w])   // o 4
            `ifdef V2P_DUG
            //apb_slave
                , .rw_data(rw_data[w * 32 +: 1 * 32])        
            `endif
        );
        bram_mpt_dirty_1w4096d_simdaulp mpt_dirty(
            .clka     (clk),
            .ena      (ram_init_finish ? wr_en_dirty[w] : init_wea),    // i 1
            .wea      (ram_init_finish ? wr_en_dirty[w] : init_wea),    // i 1
            .addra    (ram_init_finish ? wr_addr_dirty : init_addra[11:0]),     // i 12
            .dina     (ram_init_finish ? din_dirty : init_dina[0]),         // i 1
            .clkb     (clk),
            .enb      (rd_en_dirty[w]),    // i 1
            .addrb    (rd_addr_dirty),     // i 12
            .doutb    (dout_dirty[w])      // o 1
            `ifdef V2P_DUG
            //apb_slave
                , .rw_data(rw_data[(2+w) * 32 +: 1 * 32])        
            `endif
        );
        for (b = 0; b < 1; b = b+1) begin: bank
            bram_mpt_data_512w4096d_simdaulp mpt_data(
                .clka     (clk),
                .ena      (ram_init_finish ? wr_en_data[w*CACHE_BANK_NUM+b] : init_wea), // i 1 
                .wea      (ram_init_finish ? wr_en_data[w*CACHE_BANK_NUM+b] : init_wea), // i 1 
                .addra    (ram_init_finish ? wr_addr_data : init_addra[11:0]),                   // i 12
                .dina     (ram_init_finish ? din_data : init_dina[511:0]),                       // i 64*8
                .clkb     (clk),
                .enb      (rd_en_data[w*CACHE_BANK_NUM+b]), // i 1
                .addrb    (rd_addr_data),                   // i 12
                .doutb    (dout_data[w*CACHE_BANK_NUM+b])   // o 64*8
                `ifdef V2P_DUG
                //apb_slave
                    , .rw_data(rw_data[(4+w+b) * 32 +: 1 * 32])        
                `endif
            );
        end
    end
endgenerate
bram_mpt_lru_1w4096d_simdaulp  mpt_lru(  // store the way which is not used recently.
    .clka     (clk),
    .ena      (ram_init_finish ? wr_en_lru : init_wea),    // i 1
    .wea      (ram_init_finish ? wr_en_lru : init_wea),    // i 1
    .addra    (ram_init_finish ? wr_addr_lru : init_addra[11:0]),  // i 12
    .dina     (ram_init_finish ? din_lru : init_dina[0]),       // i 1
    .clkb     (clk),
    .enb      (rd_en_lru),   // i 1
    .addrb    (rd_addr_lru),  // i 12
    .doutb    (dout_lru)      // o 1
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[6 * 32 +: 1 * 32])        
    `endif
);
//----------{Cache}end--------------------------------//

//------------------{FIFO output interface}begin----------------//

    //pipeline 2 update: state out fifo, for mpt_ram_ctl get lookup state info
    state_fifo_5w16d state_fifo_5w16d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (state_wr_en),
        .rd_en      (state_rd_en),
        .din        (state_din),
        .dout       (state_dout),
        .full       (),
        .empty      (state_empty),     
        .prog_full  (state_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[7 * 32 +: 1 * 32])        
    `endif
    );   
    //pipeline 2 update: hit mpt entry out fifo, for mpt info match and mtt lookup
    hit_data_fifo_512w16d hit_data_fifo_512w16d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (hit_data_wr_en),
        .rd_en      (hit_data_rd_en),
        .din        (hit_data_din),
        .dout       (hit_data_dout),
        .full       (),
        .empty      (hit_data_empty),     
        .prog_full  (hit_data_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[8 * 32 +: 1 * 32])        
    `endif
    ); 

    //pipeline 2 update: miss read addr out fifo, for pending fifo addr to refill
    miss_addr_fifo_32w16d miss_addr_fifo_32w16d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (miss_addr_wr_en),
        .rd_en      (miss_addr_rd_en),
        .din        (miss_addr_din),
        .dout       (miss_addr_dout),
        .full       (),
        .empty      (miss_addr_empty),     
        .prog_full  (miss_addr_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[9 * 32 +: 1 * 32])        
    `endif
    );     

    //pipeline 3 replace: write MPT Ctx payload to dma_write_ctx module
    dma_wr_mpt_fifo_256w16d dma_wr_mpt_fifo_256w16d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (dma_wr_mpt_wr_en),
        .rd_en      (dma_wr_mpt_rd_en),
        .din        (dma_wr_mpt_din),
        .dout       (dma_wr_mpt_dout),
        .full       (),
        .empty      (dma_wr_mpt_empty),     
        .prog_full  (dma_wr_mpt_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[10 * 32 +: 1 * 32])        
    `endif
    );     

    //pipeline 2 and pipeline 3: dma req header fifo to mptmdata module 
        //miss read req out fifo, for mptmdata initiate dma read req in pipeline 2
        //replace write req out fifo, for mptmdata initiate dma write req in pipeline 3
        mptm_req_fifo_99w16d mptm_req_fifo_99w16d_Inst(
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
                , .rw_data(rw_data[11 * 32 +: 1 * 32])        
            `endif
        );     
     
//------------------{FIFO output interface}  end----------------//
// mpt_ran_ila mpt_ran_ila(
//         .clk(clk),
//     .probe0(state_wr_en),
//        .probe1(state_din),
//        .probe2(miss_addr_wr_en),
//        .probe3(miss_addr_din),
//        .probe4(dma_wr_mpt_wr_en),
//        .probe5(dma_wr_mpt_din),
//        .probe6(mptm_req_wr_en),
//            .probe7(mptm_req_din),
//            .probe8(hit_data_wr_en),
//        .probe9(hit_data_din)
// );
//------------ -{Three stages pipeline}begin--------------//

//----------{stage1: lookup}begin------------//
assign lookup_allow_in  = update_allow_in;
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
//modify in 2023.03.10 for the first mpt config error
// assign rd_en_dirty[0] = replace_op & update_2_replace ?  1'd1 : 1'd0;    // stage 2: miss write and stage3 is ready, read dirty
// assign rd_en_dirty[1] = replace_op & update_2_replace ?  1'd1 : 1'd0;    // stage 2: miss write and stage3 is ready, read dirty
assign rd_en_dirty[0] = lookup_2_update ?  1'd1 : 1'd0;    // stage 2: miss write and stage3 is ready, read dirty
assign rd_en_dirty[1] = lookup_2_update ?  1'd1 : 1'd0;    // stage 2: miss write and stage3 is ready, read dirty
// assign rd_en_lru     =  replace_op & update_2_replace ?  1'd1 : 1'd0;    // stage 2: miss write and stage3 is ready, read lru
assign rd_en_lru     =  lookup_2_update?  1'd1 : 1'd0;    // stage 2: miss write and stage3 is ready, read lru

assign wr_en_tagv[0]  = ((((match_way_pipe3==0) & ismatch_way_pipe3) | 
                          (!ismatch_way_pipe3 & (replace_lru==0))) & 
                          store_op_pipe3) ? 1'b1 : 1'd0;                // hit/miss write or refill; stage 3 change tagv
assign wr_en_tagv[1]  = ((((match_way_pipe3==1) & ismatch_way_pipe3) | 
                          (!ismatch_way_pipe3 & (replace_lru==1))) & 
                          store_op_pipe3) ? 1'b1 : 1'd0;                // hit/miss write or refill; stage 3 change tagv
assign wr_en_data[ 0] =  ((((match_way_pipe3==0) & ismatch_way_pipe3) | 
                           (!ismatch_way_pipe3 & (replace_lru==0))) & 
                           store_op_pipe3) ? 1'b1  : 'd0;               // hit/miss write or refill; stage 3 store data
assign wr_en_data[ 1] =  ((((match_way_pipe3==1) & ismatch_way_pipe3) | 
                           (!ismatch_way_pipe3 & (replace_lru==1))) & 
                           store_op_pipe3) ? 1'b1  : 'd0;               // hit/miss write or refill; stage 3 store data
assign wr_en_dirty[0] =  ((((match_way_pipe3==0) & ismatch_way_pipe3) | 
                           (!ismatch_way_pipe3 & (replace_lru==0))) & 
                           store_op_pipe3) ? 1'b1  : 'd0;               // hit/miss write or refill; stage 3 change dirty
assign wr_en_dirty[1] =  ((((match_way_pipe3==1) & ismatch_way_pipe3) | 
                          (!ismatch_way_pipe3 & (replace_lru==1))) & 
                          store_op_pipe3) ? 1'b1 : 1'd0;                // hit/miss write or refill; stage 3 change dirty
assign wr_en_lru    = store_op_pipe3 | read_hit_pipe3;                  // read hit or write; stage 3 change lru

assign rd_addr_tagv  = lookup_2_update ? lookup_index : 'd0; // stage 1: lookup, read tagv
assign rd_addr_data  = lookup_2_update ? lookup_index : 'd0; // stage 1: lookup, read data
//modify in 2023.03.10 for the first mpt config error
// assign rd_addr_dirty = replace_op ? replace_index : 'd0;     // stage 2(miss wr): need replace, read dirty
assign rd_addr_dirty = lookup_2_update ? lookup_index : replace_op ? replace_index : 'd0;     // stage 2(miss wr): need replace, read dirty
// assign rd_addr_lru   = replace_op ? replace_index : 'd0;     // stage 2(miss wr): need replace, read lru
assign rd_addr_lru   = lookup_2_update ? lookup_index : replace_op ? replace_index : 'd0;     // stage 1: need replace, read lru

assign wr_addr_tagv  = (store_op_pipe3) ? update_index_pipe3 : 'd0;                 // stage 2 write;             stage 3 store tagv
assign wr_addr_data  = (store_op_pipe3) ? update_index_pipe3 : 'd0;                 // stage 2 write;             stage 3 store data
assign wr_addr_dirty = (store_op_pipe3) ? update_index_pipe3 : 'd0;                 // stage 2 write;             stage 3 change dirty
assign wr_addr_lru   = (store_op_pipe3 | read_hit_pipe3) ? update_index_pipe3 : 'd0;// stage 2 read hit or write; stage 3 change lru

assign din_tagv  = (store_op_pipe3) ? {lookup_tag_pipe3,1'b1} : 'd0;             // stage 2 write;             stage 3 store tagv
assign din_data  = (store_op_pipe3) ? store_din_pipe3 : 'd0;                   // stage 2 write;             stage 3 store data
assign din_dirty = (store_op_pipe3) ? 1'd1 : 1'd0;                               // stage 2 write;             stage 3 dirty = 1
assign din_lru   = (store_op_pipe3 | read_hit_pipe3) ? (~match_way_pipe3) : 1'd0;// stage 2 read hit or write; stage 3 lru = !hit_way;
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
    else begin
        update_valid_in <= `TD 1'd0;
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
        // lookup_offset_pipe2 <= `TD 'd0;
        //TODO: add eq funciton
        eq_addr_pipe2 <= `TD 1'b0;
    end
    else if (lookup_2_update) begin
        lookup_rden_pipe2   <= `TD lookup_rden  ;
        lookup_wren_pipe2   <= `TD lookup_wren  ;
        lookup_wdata_pipe2  <= `TD lookup_wdata ;
        lookup_index_pipe2  <= `TD lookup_index ;
        lookup_tag_pipe2    <= `TD lookup_tag   ;
        // lookup_offset_pipe2 <= `TD lookup_offset;
        //TODO: add eq funciton
        eq_addr_pipe2 <= `TD mpt_eq_addr;
    end
    else begin
        lookup_rden_pipe2   <= `TD 'd0;
        lookup_wren_pipe2   <= `TD 'd0;
        lookup_wdata_pipe2  <= `TD 'd0;
        lookup_index_pipe2  <= `TD 'd0;
        lookup_tag_pipe2    <= `TD 'd0;
        // lookup_offset_pipe2 <= `TD 'd0;
        //TODO: add eq funciton
        eq_addr_pipe2 <= `TD 1'b0;
    end
end
//-----------{Lookup to Update}end----------------//

//----------{stage2: update (match, out miss req, rd lru,dirty)}begin------------//

// handshaking
// assign update_allow_in = (((!(idle_pipe2 & lookup_stall) & !(miss_pipe2 & lookup_stall)) | hit_pipe2) | store_op);
// consider:(1) !lookup_stall & pipe2 ilde & !update_stall
//               (2) !lookup_stall & !pipe2 ilde & miss read req out fifo isn't full & hit read mpt out fifo isn't full & miss read addr backup fifo isn't full & state fifo isn't full & !update_stall
//               (3) !lookup_stall & !pipe2 ilde & hit write & !update_stall
assign update_allow_in = !lookup_stall & (idle_pipe2 | (!idle_pipe2 & ( 
                             (!mptm_req_prog_full & !hit_data_prog_full & !miss_addr_prog_full & !state_prog_full) |
                              (hit_pipe2 & lookup_wren_pipe2) 
                              ))) & !update_stall ;
// indicates that data for stage3 ready
assign update_valid_out = !idle_pipe2;
// consider:(1) !pipe2 ilde & miss read req out fifo isn't full & hit read mpt out fifo isn't full & miss read addr backup fifo isn't full
//          (2) !pipe2 ilde & write
//assign update_valid_out = !idle_pipe2 & ( 
//                             (!mptm_req_prog_full & !hit_data_prog_full & 
//                             !miss_addr_prog_full) |
//                              store_op); 

// wire                   update_stall; 
// this signal used to stall the pipeline when 
    // (1) stage 1 is a read req 
    // (2) stage 2 write miss
    // (3) stage 3 write miss and replace out not finish(2 cycle to out mot entry)
    // assign update_stall = lookup_rden & ((miss_pipe2 & store_op) | write_miss_pipe3);
    assign update_stall = (miss_pipe2 & store_op) | write_miss_pipe3;
    assign update_2_replace = update_valid_out & replace_allow_in;

// match state
    //ismatch_way, match_way;
    //miss_pipe2, hit_pipe2, idle_pipe2;
    // assign ismatch_way = (dout_tagv[0] == {lookup_tag_pipe2, 1'd1}) | (dout_tagv[1] == {lookup_tag_pipe2, 1'd1});
    //TODO: add eq function, always match
    assign ismatch_way = eq_addr_pipe2 ? 1 : ((dout_tagv[0] == {lookup_tag_pipe2, 1'd1}) | (dout_tagv[1] == {lookup_tag_pipe2, 1'd1}));
    
    assign match_way   = ((dout_tagv[0] == {lookup_tag_pipe2, 1'd1}) & 1'd0) |
                         ((dout_tagv[1] == {lookup_tag_pipe2, 1'd1}) & 1'd1);
    assign miss_pipe2 =  (update_valid_in & !ismatch_way);// (update_valid_in & !ismatch_way) & !wen_tagv_inst;
    assign hit_pipe2  =  (update_valid_in &  ismatch_way);
    assign idle_pipe2 = !update_valid_in;

// read data
    //wire                   load_op; 
    //wire [LINE_SIZE*8-1:0] dout_data_way0;
    //wire [LINE_SIZE*8-1:0] dout_data_way1;
    //wire [LINE_SIZE*8-1:0] match_rdata;
    assign load_op        = hit_pipe2 & lookup_rden_pipe2;
    assign dout_data_way0 = dout_data[0];
    assign dout_data_way1 = dout_data[1];
    assign match_rdata = match_way ? dout_data_way1 : dout_data_way0;

// write data
    //wire                   store_op ;
    //wire [LINE_SIZE*8-1:0] store_din;
    //wire [INDEX -1 :0]     update_index;
    assign store_op     = (hit_pipe2 | miss_pipe2) & lookup_wren_pipe2;
    assign store_din    = lookup_wdata_pipe2;
    assign update_index = lookup_index_pipe2;

// output state and cached data
    //wire [LINE_SIZE*8-1:0] hit_data,
    //wire [31:0]            miss_addr,
    assign hit_data     = hit_pipe2 ? match_rdata : 'd0;
    assign miss_addr    = {17'b0, lookup_tag_pipe2, lookup_index_pipe2};

// miss match
    //wire [INDEX -1 :0]     replace_index; //used to read dirty and lru
    //wire                   replace_op;    //only write miss cause replace
    assign replace_op = miss_pipe2 & lookup_wren_pipe2;
    assign replace_index = lookup_index_pipe2;

//  hit data out fifo
    //wire                          hit_data_wr_en,
    //wire [LINE_SIZE*8-1:0]        hit_data_din, //hit_data
    assign hit_data_wr_en = load_op;
    assign hit_data_din   = load_op ? hit_data : 0;
    
//  miss read addr out fifo, for pending fifo addr to refill
    //wire                          miss_addr_wr_en,
    //wire  [31:0]                  miss_addr_din,//read mpt req(miss_addr);
    assign miss_addr_wr_en = miss_pipe2 & lookup_rden_pipe2;
    assign miss_addr_din   = miss_addr_wr_en ? miss_addr : 0;

// lookup state info out
    //output wire [2:0]   lookup_state, // | 2<->miss | 1<->hit | 0<->idle |
    //output wire         lookup_ldst , // 1 for store, and 0 for load  
    //output wire         state_valid   , // valid in process state, invalid if stall or idle
    assign lookup_state = {miss_pipe2, hit_pipe2, idle_pipe2};
    assign lookup_ldst  = ((|lookup_wren_pipe2) & 1'd1) | (lookup_rden_pipe2 & 1'd0);
    assign state_valid  = update_valid_out ? 1'd1 : update_stall ? 1'd0 : 1'd0;
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
always @(posedge clk or posedge rst) begin
    if (rst) begin
        miss_pipe3            <= `TD 'b0;
        write_miss_pipe3      <= `TD 'b0;
        store_op_pipe3        <= `TD 'b0;
        read_hit_pipe3        <= `TD 'b0;
        tagv_way0_pipe3       <= `TD 'b0;
        tagv_way1_pipe3       <= `TD 'b0;
        lookup_tag_pipe3      <= `TD 'b0;
        replace_index_pipe3   <= `TD 'b0;
        // ldst_stall_pipe3      <= `TD 'b0;
        update_index_pipe3    <= `TD 'b0; 
        ismatch_way_pipe3     <= `TD 'b0; 
        match_way_pipe3       <= `TD 'b0; 
        store_din_pipe3       <= `TD 'b0; 
        dout_data_way0_pipe3  <= `TD 'b0; 
        dout_data_way1_pipe3  <= `TD 'b0; 
    end
    else if (update_2_replace) begin      
        miss_pipe3            <= `TD  miss_pipe2;
        write_miss_pipe3      <= `TD  miss_pipe2 & lookup_wren_pipe2;
        store_op_pipe3        <= `TD  store_op;
        read_hit_pipe3        <= `TD  load_op;
        tagv_way0_pipe3       <= `TD  dout_tagv[0];
        tagv_way1_pipe3       <= `TD  dout_tagv[1];
        lookup_tag_pipe3      <= `TD  lookup_tag_pipe2;
        replace_index_pipe3   <= `TD  replace_index;
        // ldst_stall_pipe3      <= `TD  update_stall; 
        update_index_pipe3    <= `TD  update_index;
        ismatch_way_pipe3     <= `TD  ismatch_way;
        match_way_pipe3       <= `TD  match_way;
        store_din_pipe3       <= `TD  store_din;
        dout_data_way0_pipe3  <= `TD  dout_data_way0;
        dout_data_way1_pipe3  <= `TD  dout_data_way1;
    end
    /*VCS Verification*/
    // else if (write_miss_pipe3 & ((dma_wr_mpt_cnt == 0) | ((dma_wr_mpt_cnt == 1) & dma_wr_mpt_wr_en))) begin
    else if (write_miss_pipe3 & ((dma_wr_mpt_cnt == 0) | ((dma_wr_mpt_cnt == 1) & dma_wr_mpt_wr_en)) & replace_en) begin
    /*Action = Modify, add replace_en condition*/
        //value changed based on dma_wr_mpt_cnt, miss_pipe3, and store_op_pipe3
        //consider that wr_en ram signal is changed by these signals: 
        //  match_way_pipe3, ismatch_way_pipe3, replace_lru==1, store_op_pipe3, read_hit_pipe3;  
        //so, if write miss causes stall, these signals are changed into 0, and use new variables store them
        miss_pipe3            <= `TD  miss_pipe3          ;
        write_miss_pipe3      <= `TD  write_miss_pipe3    ;
        store_op_pipe3        <= `TD  0                   ;
        read_hit_pipe3        <= `TD  0                   ;
        tagv_way0_pipe3       <= `TD  tagv_way0_pipe3     ;
        tagv_way1_pipe3       <= `TD  tagv_way1_pipe3     ;
        lookup_tag_pipe3      <= `TD  lookup_tag_pipe3    ;
        replace_index_pipe3   <= `TD  replace_index_pipe3 ;
        // ldst_stall_pipe3      <= `TD  ldst_stall_pipe3    ;
        update_index_pipe3    <= `TD  update_index_pipe3  ;
        ismatch_way_pipe3     <= `TD  0                   ;
        match_way_pipe3       <= `TD  0                   ;
        store_din_pipe3       <= `TD  0                   ;
        dout_data_way0_pipe3  <= `TD  dout_data_way0_pipe3;
        dout_data_way1_pipe3  <= `TD  dout_data_way1_pipe3;
    end
    else begin
        miss_pipe3            <= `TD 'b0;
        write_miss_pipe3      <= `TD 'b0;
        store_op_pipe3        <= `TD 'b0;
        read_hit_pipe3        <= `TD 'b0;
        tagv_way0_pipe3       <= `TD 'b0;
        tagv_way1_pipe3       <= `TD 'b0;
        lookup_tag_pipe3      <= `TD 'b0;
        replace_index_pipe3   <= `TD 'b0;
        // ldst_stall_pipe3      <= `TD 'b0;
        update_index_pipe3    <= `TD 'b0; 
        ismatch_way_pipe3     <= `TD 'b0; 
        match_way_pipe3       <= `TD 'b0; 
        store_din_pipe3       <= `TD 'b0; 
        dout_data_way0_pipe3  <= `TD 'b0; 
        dout_data_way1_pipe3  <= `TD 'b0; 
    end
end
//-----------{Update to Replace}end----------------//

//----------{Stage3: Replace (write mpt, replace, write back)}begin-----------------//
//handshaking
    //wire    idle_pipe3;
    //we can't jude the stage3 is idle only based on replace_valid_in=0, because if write miss, replace_valid_in=0,too
    //we add a another signal to jude if stage3 is idle, which hold the value when write miss or stall accuring.
    assign idle_pipe3 = !replace_valid_in & !(|update_index_pipe3);
    //wire    replace_allow_in; 
    //consider: (1)replace stage is idle; (2)write/read hit; (3) write miss and write back fifo out finish; 
    //          (4) dma req fifo isn't full; (5) dma payload fifo isn't full
    assign replace_allow_in = (idle_pipe3 | (replace_valid_in & ismatch_way_pipe3) | (miss_pipe3 & !write_miss_pipe3)) 
                                & !mptm_req_prog_full & !dma_wr_mpt_prog_full;
// data in pipe3: replace
    //reg                    replace_lru;
    //reg                    replace_en;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            replace_lru <= `TD 0;
            replace_en  <= `TD 0;
        end
        //modify in 2023.03.10 for the first mpt config error
        // else if (rd_en_lru) begin
        //     replace_lru <= `TD dout_lru;
        //     replace_en  <= `TD update_valid_out & (dout_lru ? dout_dirty[1] : dout_dirty[0]) &  miss_pipe2 & lookup_wren_pipe2;
        // end        
        else if (update_2_replace) begin
            replace_lru <= `TD dout_lru;
            replace_en  <= `TD update_valid_out & (dout_lru ? dout_dirty[1] : dout_dirty[0]) &  miss_pipe2 & lookup_wren_pipe2;
        end 
else if (write_miss_pipe3 & ((dma_wr_mpt_cnt == 0) | ((dma_wr_mpt_cnt == 1) & dma_wr_mpt_wr_en))) begin
            replace_lru <= `TD replace_lru;
            replace_en  <= `TD replace_en ;
        end else begin
            replace_lru <= `TD 0;
            replace_en  <= `TD 0;           
        end
    end
    //wire [63:0]  replace_addr;
    /*Spyglass*/
    //assign replace_addr = {49'b0, (replace_lru ? tagv_way1_pipe3[20:1] : tagv_way0_pipe3[20:1]), replace_index_pipe3};
    assign replace_addr = {49'b0, (replace_lru ? tagv_way1_pipe3[3:1] : tagv_way0_pipe3[3:1]), replace_index_pipe3};
    /*Action = Modify*/

//write MPT Ctx payload to dma_write_ctx module
    //wire                    dma_wr_mpt_wr_en;
    //consider: (1)first cycle in stage3: write miss, valid in, replace_en, mpt fifo isn't full
    //          (2)not 1st cycle in stage3: write miss, dma mpt transfer not finish, repalce_en, mpt fifo isn't full
    assign dma_wr_mpt_wr_en = ((replace_valid_in & write_miss_pipe3 ) | 
                               (write_miss_pipe3 & (dma_wr_mpt_cnt < 2))) 
                               & replace_en & !dma_wr_mpt_prog_full;
    //wire  [`DT_WIDTH-1:0]   dma_wr_mpt_din;// write back replace data
    //consider: (1)wr_en; (2)mpt_cnt indicates the seg in dout_data; (3)replace_lru indidates the way write back
    /*VCS Verification*/

    // assign dma_wr_mpt_din = (dma_wr_mpt_wr_en & (dma_wr_mpt_cnt == 0) & replace_lru) ? dout_data_way1_pipe3[LINE_SIZE*4-1:0]
    //                     : (dma_wr_mpt_wr_en & (dma_wr_mpt_cnt == 1) & replace_lru) ? dout_data_way1_pipe3[LINE_SIZE*8-1:LINE_SIZE*4]
    //                     : (dma_wr_mpt_wr_en & (dma_wr_mpt_cnt == 0) & !replace_lru) ? dout_data_way0_pipe3[LINE_SIZE*4-1:0]
    //                     : (dma_wr_mpt_wr_en & (dma_wr_mpt_cnt == 1) & !replace_lru) ? dout_data_way0_pipe3[LINE_SIZE*8-1:LINE_SIZE*4] : 0;
    assign dma_wr_mpt_din = (dma_wr_mpt_wr_en & (dma_wr_mpt_cnt == 0) & replace_lru) ? dout_data_way1_pipe3[LINE_SIZE*8-1:LINE_SIZE*4]
                    : (dma_wr_mpt_wr_en & (dma_wr_mpt_cnt == 1) & replace_lru) ? dout_data_way1_pipe3[LINE_SIZE*4-1:0]
                    : (dma_wr_mpt_wr_en & (dma_wr_mpt_cnt == 0) & !replace_lru) ? dout_data_way0_pipe3[LINE_SIZE*8-1:LINE_SIZE*4]
                    : (dma_wr_mpt_wr_en & (dma_wr_mpt_cnt == 1) & !replace_lru) ? dout_data_way0_pipe3[LINE_SIZE*4-1:0] : 0; 
    /*Action = Modify, reverse the suquence of mpt data write back to host memory*/
    //reg   [1:0]             dma_wr_mpt_cnt;//count 2 cycle after the wr_en signal for finishing mpt entry trans
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dma_wr_mpt_cnt <= `TD 0;
        end
        else if (replace_valid_in & write_miss_pipe3 & dma_wr_mpt_wr_en) begin //first cycle in stage3 wr_en, increace to 1
            dma_wr_mpt_cnt <= `TD 1;
        end
        else if (write_miss_pipe3 & (dma_wr_mpt_cnt < 2) && dma_wr_mpt_wr_en) begin //once wr_en, once increace
            dma_wr_mpt_cnt <= `TD dma_wr_mpt_cnt + 1;
        end
        else if ((dma_wr_mpt_cnt < 2) && !dma_wr_mpt_wr_en) begin//!wr_en, hold the cnt value
            dma_wr_mpt_cnt <= `TD dma_wr_mpt_cnt;
        end
        else begin
            dma_wr_mpt_cnt <= `TD 0;
        end
    end
//----------{Stage3: Replacee (write mpt, replace, write back)}end-----------------//

//------------------{in pipeline 2 and pipeline 3: req header to mptmdata module }begin---------------//
    //miss read req out fifo, for mptmdata initiate dma read req in pipeline 2
    //replace write req out fifo, for mptmdata initiate dma write req in pipeline 3
    //-----------MPT/MTT-mptm/mttm req header format---------
        //high------------------------low
        //| ---------99 bit-----|
        //| opcode | num | addr |
        //|    3   | 32  |  64  |
        //|-----------------------------|
    //wire                          mptm_req_wr_en,
    //consider: (1) stage2 read miss and req fifo isn't full; (2)stage3' 1st cycle write miss and req fifo isn't full
    assign mptm_req_wr_en = ((miss_pipe2 & lookup_rden_pipe2) 
                            | (replace_valid_in & write_miss_pipe3 & dma_wr_mpt_wr_en))
                             & !mptm_req_prog_full;
    //wire  [TPT_HD_WIDTH-1:0]      mptm_req_din,//read mpt req(miss_addr); or replace write mpt req(replace_addr)
    assign mptm_req_din = (miss_pipe2 & lookup_rden_pipe2 & mptm_req_wr_en) ? {`MPT_RD,32'b1,32'b0,miss_addr} 
                        : (replace_valid_in & write_miss_pipe3 & dma_wr_mpt_wr_en & mptm_req_wr_en) ?
                        {`MPT_WR,32'b1,replace_addr} : 0;
//------------------{in pipeline 2 and pipeline 3: mptmdata module req}begin---------------//

`ifdef V2P_DUG
    // /*****************Add for APB-slave regs**********************************/ 
        // reg     update_valid_in;
        // reg     replace_valid_in;
        // reg                     lookup_rden_pipe2  ;
        // reg                     lookup_wren_pipe2  ;
        // reg [LINE_SIZE*8-1:0]   lookup_wdata_pipe2 ;
        // reg [INDEX -1 :0]       lookup_index_pipe2 ;
        // reg [TAG-1        :0]   lookup_tag_pipe2   ;
        // reg eq_addr_pipe2;
        // reg               miss_pipe3         ;
        // reg               write_miss_pipe3   ;
        // reg               read_hit_pipe3     ;
        // reg               store_op_pipe3     ;
        // reg [TAG      :0] tagv_way0_pipe3    ;
        // reg [TAG      :0] tagv_way1_pipe3    ;
        // reg [TAG-1    :0] lookup_tag_pipe3   ;
        // reg [INDEX -1 :0] replace_index_pipe3;
        // reg [INDEX -1 :0]     update_index_pipe3;
        // reg                   ismatch_way_pipe3;
        // reg                   match_way_pipe3;
        // reg [LINE_SIZE*8-1:0] store_din_pipe3   ;
        // reg [LINE_SIZE*8-1:0] dout_data_way0_pipe3;
        // reg [LINE_SIZE*8-1:0] dout_data_way1_pipe3;
        // reg                    replace_lru;
        // reg                    replace_en;
        // reg   [1:0]                  dma_wr_mpt_cnt;

        
    /*****************Add for APB-slave wires**********************************/         
        // wire                          lookup_allow_in,
        // wire                          lookup_rden ,
        // wire                          lookup_wren ,
        // wire [LINE_SIZE*8-1:0]        lookup_wdata,
        // wire [INDEX -1     :0]        lookup_index,
        // wire [TAG -1       :0]        lookup_tag  ,
        // wire                         mpt_eq_addr,    
        // wire                          state_rd_en , 
        // wire                          state_empty ,
        // wire [4:0]                    state_dout  ,
        // wire                          hit_data_rd_en,
        // wire                          hit_data_empty,         
        // wire [LINE_SIZE*8-1:0]        hit_data_dout,
        // wire                          miss_addr_rd_en,
        // wire  [31:0]                  miss_addr_dout,
        // wire                          miss_addr_empty,
        // wire                         lookup_stall, 
        // wire                         dma_wr_mpt_rd_en,
        // wire  [`DT_WIDTH-1:0]        dma_wr_mpt_dout,
        // wire                         dma_wr_mpt_empty,
        // wire                          mptm_req_rd_en,
        // wire  [TPT_HD_WIDTH-1:0]      mptm_req_dout,
        // wire                          mptm_req_empty
        // wire    lookup_valid_out;
        // wire    lookup_2_update;
        // wire    update_allow_in;
        // wire    update_valid_out;
        // wire    update_2_replace;
        // wire    replace_allow_in;
        // wire         rd_en_tagv  [0:(CACHE_WAY_NUM-1)];
        // wire         rd_en_dirty [0:(CACHE_WAY_NUM-1)];
        // wire         rd_en_data  [0:(CACHE_WAY_NUM*CACHE_BANK_NUM-1)];
        // wire         rd_en_lru;
        // wire         wr_en_tagv  [0:(CACHE_WAY_NUM-1)];
        // wire         wr_en_dirty [0:(CACHE_WAY_NUM-1)];
        // wire         wr_en_data  [0:(CACHE_WAY_NUM*CACHE_BANK_NUM-1)];
        // wire         wr_en_lru;
        // wire [INDEX -1 :0]  rd_addr_tagv;
        // wire [INDEX -1 :0]  rd_addr_dirty;
        // wire [INDEX -1 :0]  rd_addr_data;
        // wire [INDEX -1 :0]  rd_addr_lru;
        // wire [INDEX -1 :0]  wr_addr_tagv;
        // wire [INDEX -1 :0]  wr_addr_dirty;
        // wire [INDEX -1 :0]  wr_addr_data;
        // wire [INDEX -1 :0]  wr_addr_lru;
        // wire [TAG          :0]  din_tagv ;
        // wire                    din_dirty;
        // wire [LINE_SIZE*8-1:0]  din_data ;
        // wire                    din_lru  ;
        // wire [TAG          :0]  dout_tagv  [0:(CACHE_WAY_NUM-1)];
        // wire                    dout_dirty [0:(CACHE_WAY_NUM-1)];
        // wire [LINE_SIZE*8-1:0]  dout_data  [0:(CACHE_WAY_NUM*CACHE_BANK_NUM-1)];
        // wire                    dout_lru;
        // wire                   update_stall; 
        // wire ismatch_way;
        // wire match_way;
        // wire miss_pipe2;
        // wire hit_pipe2;
        // wire idle_pipe2;
        // wire [2:0]   lookup_state;
        // wire         lookup_ldst ;
        // wire         state_valid ;
        // wire              load_op;
        // wire [LINE_SIZE*8-1:0] dout_data_way0;
        // wire [LINE_SIZE*8-1:0] dout_data_way1;
        // wire [LINE_SIZE*8-1:0] match_rdata;
        // wire [LINE_SIZE*8-1:0] hit_data;
        // wire [31:0]            miss_addr;
        // wire                   store_op ;
        // wire [LINE_SIZE*8-1:0] store_din;
        // wire [INDEX -1 :0]     update_index;
        // wire [INDEX -1 :0]     replace_index;
        // wire                   replace_op;
        // wire                          state_wr_en;
        // wire                          state_prog_full;
        // wire      [4:0]               state_din; 
        // wire                          hit_data_wr_en;
        // wire                          hit_data_prog_full;
        // wire [LINE_SIZE*8-1:0]        hit_data_din;
        // wire                          miss_addr_wr_en;
        // wire                          miss_addr_prog_full;
        // wire  [31:0]                  miss_addr_din;
        // wire  [63:0]           replace_addr;
        // wire                   idle_pipe3;
        // wire                         dma_wr_mpt_wr_en;
        // wire                         dma_wr_mpt_prog_full;
        // wire  [`DT_WIDTH-1:0]        dma_wr_mpt_din;
        // wire                          mptm_req_wr_en;
        // wire                          mptm_req_prog_full;
        // wire  [TPT_HD_WIDTH-1:0]      mptm_req_din;
        
    //Total regs and wires : 6056 = 189*32+8

    assign wv_dbg_bus_mpt = {
        24'b0,
        update_valid_in,
        replace_valid_in,
        lookup_rden_pipe2,
        lookup_wren_pipe2,
        lookup_wdata_pipe2,
        lookup_index_pipe2,
        lookup_tag_pipe2,
        eq_addr_pipe2,
        miss_pipe3,
        write_miss_pipe3,
        read_hit_pipe3,
        store_op_pipe3,
        tagv_way0_pipe3,
        tagv_way1_pipe3,
        lookup_tag_pipe3,
        replace_index_pipe3,
        update_index_pipe3,
        ismatch_way_pipe3,
        match_way_pipe3,
        store_din_pipe3,
        dout_data_way0_pipe3,
        dout_data_way1_pipe3,
        replace_lru,
        replace_en,
        dma_wr_mpt_cnt,

        lookup_allow_in,
        lookup_rden,
        lookup_wren,
        lookup_wdata,
        lookup_index,
        lookup_tag,
        mpt_eq_addr,
        state_rd_en,
        state_empty,
        state_dout,
        hit_data_rd_en,
        hit_data_empty,
        hit_data_dout,
        miss_addr_rd_en,
        miss_addr_dout,
        miss_addr_empty,
        lookup_stall,
        dma_wr_mpt_rd_en,
        dma_wr_mpt_dout,
        dma_wr_mpt_empty,
        mptm_req_rd_en,
        mptm_req_dout,
        mptm_req_empty,
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
        rd_en_lru,
        wr_en_tagv[0],
        wr_en_tagv[1],
        wr_en_dirty[0],
        wr_en_dirty[1],
        wr_en_data[0],
        wr_en_data[1],
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
        din_data,
        din_lru,
        dout_tagv[0],
        dout_tagv[1],
        dout_dirty[0],
        dout_dirty[1],
        dout_data[0],
        dout_data[1],
        dout_lru,
        update_stall,
        ismatch_way,
        match_way,
        miss_pipe2,
        hit_pipe2,
        idle_pipe2,
        lookup_state,
        lookup_ldst,
        state_valid,
        load_op,
        dout_data_way0,
        dout_data_way1,
        match_rdata,
        hit_data,
        miss_addr,
        store_op,
        store_din,
        update_index,
        replace_index,
        replace_op,
        state_wr_en,
        state_prog_full,
        state_din,
        hit_data_wr_en,
        hit_data_prog_full,
        hit_data_din,
        miss_addr_wr_en,
        miss_addr_prog_full,
        miss_addr_din,
        replace_addr,
        idle_pipe3,
        dma_wr_mpt_wr_en,
        dma_wr_mpt_prog_full,
        dma_wr_mpt_din,
        mptm_req_wr_en,
        mptm_req_prog_full,
        mptm_req_din      
    };

`endif 

endmodule
