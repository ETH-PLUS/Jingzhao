//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: mpt_ram_ctl.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V17.0 
// VERSION DESCRIPTION: 1st Edition  
//----------------------------------------------------
// RELEASE DATE: 2022-8-18
//---------------------------------------------------- 
// PURPOSE: store and operate on mpt table data
// add EQ function
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
// 
//-FHDR-----------------------------------------------

//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_v2p_h.vh"

module mpt_ram_ctl#(
    parameter MPT_SIZE       = 524288, //Total Size(MPT+MTT) 1MB, MPT_RAM occupies 512KB
    parameter CACHE_WAY_NUM  = 2,//2 way
    parameter LINE_SIZE      = 64,//Cache line size = 64B(MPT entry= 64B)
    parameter INDEX           =   12,//mpt_ram index width
    parameter TAG             =   3,//mpt_ram tag width
    parameter DMA_RD_BKUP_WIDTH  = 99,//for Mdata-TPT Read req header fifo
    parameter PEND_CNT_WIDTH = 32,
    parameter CHANNEL_WIDTH = 9
    )(
    input clk,
    input rst,
    //------------------interface to selected_channel_ctl module--------
        output reg                          req_read_already,
        input  wire   [CHANNEL_WIDTH-1 :0]  selected_channel,
    
    //------------------interface to request scheduler module
        output reg   [PEND_CNT_WIDTH-1 :0] qv_pend_channel_cnt,
    
    //------------------interface to ceu channel----------------------
        // internal ceu request header
        // 128 width header format
        output  reg                    mpt_req_rd_en,
        input  wire  [`HD_WIDTH-1:0]   mpt_req_dout,
        //input  wire                    mpt_req_empty,
    
        // internal ceu payload data
        // 256 width 
        output  reg                    mpt_data_rd_en,
        input  wire  [`DT_WIDTH-1:0]   mpt_data_dout,
        input  wire                    mpt_data_empty,

    //------------------interface to rdma engine channel--------------
        //read  Doorbell Processing(WQE) req_fifo
        //input   wire                i_db_vtp_cmd_empty,
        output   reg                o_db_vtp_cmd_rd_en,
        input   wire    [255:0]     iv_db_vtp_cmd_data,
        //write Doorbell Processing(WQE) state_fifo
        input   wire                i_db_vtp_resp_prog_full,
        output  reg                 o_db_vtp_resp_wr_en,
        output  wire     [7:0]       ov_db_vtp_resp_data,

        //read  WQE Parser(WQE�? req_fifo
        //input   wire                i_wp_vtp_wqe_cmd_empty,
        output   reg                o_wp_vtp_wqe_cmd_rd_en,
        input   wire    [255:0]     iv_wp_vtp_wqe_cmd_data,
        //write WQE Parser(WQE�? state_fifo
        input   wire                i_wp_vtp_wqe_resp_prog_full,
        output  reg                 o_wp_vtp_wqe_resp_wr_en,
        output  wire     [7:0]       ov_wp_vtp_wqe_resp_data,        
        
        //read WQE Parser(DATA) req_fifo
        //input   wire                i_wp_vtp_nd_cmd_empty,
        output   reg                o_wp_vtp_nd_cmd_rd_en,
        input   wire    [255:0]     iv_wp_vtp_nd_cmd_data,
        //write WQE Parser(DATA) state_fifo
        input   wire                i_wp_vtp_nd_resp_prog_full,
        output  reg                 o_wp_vtp_nd_resp_wr_en,
        output  wire     [7:0]       ov_wp_vtp_nd_resp_data,
        
        //read  RequesterTransControl(CQ) req_fifo
        //input    wire               i_rtc_vtp_cmd_empty,
        output    reg               o_rtc_vtp_cmd_rd_en,
        input    wire    [255:0]    iv_rtc_vtp_cmd_data,
        //write RequesterTransControl(CQ) state_fifo
        input   wire                i_rtc_vtp_resp_prog_full,
        output  reg                 o_rtc_vtp_resp_wr_en,
        output  wire     [7:0]       ov_rtc_vtp_resp_data,    

        //read  RequesterRecvControl(DATA) req_fifo
        //input    wire               i_rrc_vtp_cmd_empty,
        output    reg               o_rrc_vtp_cmd_rd_en,
        input    wire    [255:0]    iv_rrc_vtp_cmd_data,
        //write RequesterRecvControl(DATA) state_fifo
        input   wire                i_rrc_vtp_resp_prog_full,
        output  reg                 o_rrc_vtp_resp_wr_en,
        output  wire     [7:0]       ov_rrc_vtp_resp_data,

        //read  Execution Engine(DATA) req_fifo
        //input    wire               i_ee_vtp_cmd_empty,
        output    reg               o_ee_vtp_cmd_rd_en,
        input    wire    [255:0]    iv_ee_vtp_cmd_data,
        //write Execution Engine(DATA) state_fifo
        input   wire                i_ee_vtp_resp_prog_full,
        output  reg                 o_ee_vtp_resp_wr_en,
        output  wire     [7:0]       ov_ee_vtp_resp_data,

        //read  Execution Engine(RQ WQE) req_fifo
        //input    wire               i_rwm_vtp_cmd_empty,
        output    reg               o_rwm_vtp_cmd_rd_en,
        input    wire    [255:0]    iv_rwm_vtp_cmd_data,
        //write Execution Engine(RQ WQE) state_fifo
        input   wire                i_rwm_vtp_resp_prog_full,
        output  reg                 o_rwm_vtp_resp_wr_en,
        output  wire     [7:0]       ov_rwm_vtp_resp_data,

    //------------------interface to Metadata module-------------
        //read mpt_base for compute index in mpt_ram
        input  wire  [63:0]                    mpt_base_addr,  

    //------------------interface to dma_read_ctx module-------------
        //read dma req header metadata from backup fifo
        //| --------99  bit------|
        //| index | opcode | len |
        //|  64   |    3   | 32  |
        output reg                             dma_rd_mpt_bkup_rd_en,
        input  wire  [DMA_RD_BKUP_WIDTH-1:0]   dma_rd_mpt_bkup_dout,
        input  wire                            dma_rd_mpt_bkup_empty,
    
    //-----------------interface to DMA Engine module------------------
        //read MPT Ctx payload response from DMA Engine module     
        output  wire                           dma_v2p_mpt_rd_rsp_tready,
        input   wire                           dma_v2p_mpt_rd_rsp_tvalid,
        input   wire [`DT_WIDTH-1:0]           dma_v2p_mpt_rd_rsp_tdata,
        input   wire                           dma_v2p_mpt_rd_rsp_tlast,
        input   wire [`HD_WIDTH-1:0]           dma_v2p_mpt_rd_rsp_theader,

    //---------------------------mpt_ram--------------------------
        //lookup info and response state
        input  wire                     lookup_allow_in,
        output reg                      lookup_rden,
        output reg                      lookup_wren,
        output reg  [LINE_SIZE*8-1:0]   lookup_wdata,
        //lookup info addr={(32-INDEX-TAG)'b0,lookup_tag,lookup_index}
        output reg  [INDEX -1     :0]   lookup_index,
        output reg  [TAG -1       :0]   lookup_tag,
        /*Spyglass*/
        //input  wire [2:0]               lookup_state,// | 3<->miss | 2<->hit | 0<->idle |
        //input  wire                     lookup_ldst, // 1 for store, and 0 for load
        //input  wire                     state_valid, // valid in normal state, invalid if stall
        /*Action = Delete*/
        output wire                     lookup_stall,
        // add EQ function
        output wire                       mpt_eq_addr,
        //lookup info state fifo
        output reg                           state_rd_en, 
        input  wire                          state_empty, 
        input  wire [4:0]                    state_dout , 
        //hit mpt entry in fifo, for mpt info match and mtt lookup
        output reg                      hit_data_rd_en,
        input  wire                     hit_data_empty,         
        input  wire [LINE_SIZE*8-1:0]   hit_data_dout,
        //miss read addr in fifo, for pending fifo addr to refill
        output reg                      miss_addr_rd_en,
        input  wire  [31:0]             miss_addr_dout,
        input  wire                     miss_addr_empty,

    //----------------interface to MTT module-------------------------
        /*******mtt read/write block problem*********/
        // //write MTT read request(include Src,Op,mtt_index,v-addr,length) to MTT module        
        // //| ---------------------165 bit------------------------- |
        // //|   Src    |     Op  | mtt_index | address |Byte length |
        // //|  164:162 | 162:160 |  159:96   |  95:32  |   31:0     |
        // input  wire                     mpt_req_mtt_rd_en,
        // output wire  [164:0]            mpt_req_mtt_dout,
        // output wire                     mpt_req_mtt_empty,
        
        //write read request(include Src,mtt_index,v-addr,length) to mpt_rd_req_parser module        
        //|--------------163 bit------------------------- |
        //|    Src  | mtt_index | address |Byte length |
        //| 162:160 |  159:96   |  95:32  |   31:0     |
        input  wire                     mpt_rd_req_mtt_rd_en,
        output wire  [162:0]            mpt_rd_req_mtt_dout,
        output wire                     mpt_rd_req_mtt_empty,

        //write read request(include Src,mtt_index,v-addr,length) to mpt_rd_wqe_req_parser module        
        //|--------------163 bit------------------------- |
        //|    Src  | mtt_index | address |Byte length |
        //| 162:160 |  159:96   |  95:32  |   31:0     |
        input  wire                     mpt_rd_wqe_req_mtt_rd_en,
        output wire  [162:0]            mpt_rd_wqe_req_mtt_dout,
        output wire                     mpt_rd_wqe_req_mtt_empty,
    
        //write read request(include Src,mtt_index,v-addr,length) to mpt_wr_req_parser module        
        //|--------------163 bit------------------------- |
        //|    Src  | mtt_index | address |Byte length |
        //| 162:160 |  159:96   |  95:32  |   31:0     |
        input  wire                     mpt_wr_req_mtt_rd_en,
        output wire  [162:0]            mpt_wr_req_mtt_dout,
        output wire                     mpt_wr_req_mtt_empty,
        //Action==Modify: maxiaoxiao, divide the mtt_ram_ctl req into read and write FIFOs

    // used for req_scheduler judge if mpt_ram is in idle state
        output   wire          mpt_rsp_stall,

        output reg [2:0] lookup_ram_cnt

    `ifdef V2P_DUG
    //apb_slave
        ,  input wire [`MPTCTL_DBG_RW_NUM * 32 - 1 : 0]   rw_data
        ,  output wire [`MPTCTL_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mptctl
    `endif

);

//--------------{fifo declaration}begin---------------//
    /*******mtt read/write block problem*********/
    // //write MTT read request(include Src,Op,mtt_index,v-addr,length) to MTT module        
    // reg                  mpt_req_mtt_wr_en;
    // wire                 mpt_req_mtt_prog_full;
    // reg   [164:0]        mpt_req_mtt_din;
    // mpt_req_mtt_fifo_165w16d mpt_req_mtt_fifo_165w16d_Inst(
    //     .clk        (clk),
    //     .srst       (rst),
    //     .wr_en      (mpt_req_mtt_wr_en),
    //     .rd_en      (mpt_req_mtt_rd_en),
    //     .din        (mpt_req_mtt_din),
    //     .dout       (mpt_req_mtt_dout),
    //     .full       (),
    //     .empty      (mpt_req_mtt_empty),     
    //     .prog_full  (mpt_req_mtt_prog_full)
    // );
        
    //write read request(include Src,mtt_index,v-addr,length) to mpt_rd_req_parser module        
    reg                  mpt_rd_req_mtt_wr_en;
    wire                 mpt_rd_req_mtt_prog_full;
    reg   [162:0]        mpt_rd_req_mtt_din;
    mpt_wr_req_mtt_fifo_163w16d mpt_rd_req_mtt_fifo_163w16d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (mpt_rd_req_mtt_wr_en),
        .rd_en      (mpt_rd_req_mtt_rd_en),
        .din        (mpt_rd_req_mtt_din),
        .dout       (mpt_rd_req_mtt_dout),
        .full       (),
        .empty      (mpt_rd_req_mtt_empty),     
        .prog_full  (mpt_rd_req_mtt_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[0 * 32 +: 1 * 32])        
    `endif
);

    //write read request(include Src,mtt_index,v-addr,length) to mpt_rd_wqe_req_parser module        
    reg                  mpt_rd_wqe_req_mtt_wr_en;
    wire                 mpt_rd_wqe_req_mtt_prog_full;
    reg   [162:0]        mpt_rd_wqe_req_mtt_din;
    mpt_wr_req_mtt_fifo_163w16d mpt_rd_wqe_req_mtt_fifo_163w16d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (mpt_rd_wqe_req_mtt_wr_en),
        .rd_en      (mpt_rd_wqe_req_mtt_rd_en),
        .din        (mpt_rd_wqe_req_mtt_din),
        .dout       (mpt_rd_wqe_req_mtt_dout),
        .full       (),
        .empty      (mpt_rd_wqe_req_mtt_empty),     
        .prog_full  (mpt_rd_wqe_req_mtt_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[1 * 32 +: 1 * 32])        
    `endif
);

    //write write request(include Src,mtt_index,v-addr,length) to mpt_wr_req_parser module        
    reg                  mpt_wr_req_mtt_wr_en;
    wire                 mpt_wr_req_mtt_prog_full;
    reg   [162:0]        mpt_wr_req_mtt_din;
    mpt_wr_req_mtt_fifo_163w16d mpt_wr_req_mtt_fifo_163w16d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (mpt_wr_req_mtt_wr_en),
        .rd_en      (mpt_wr_req_mtt_rd_en),
        .din        (mpt_wr_req_mtt_din),
        .dout       (mpt_wr_req_mtt_dout),
        .full       (),
        .empty      (mpt_wr_req_mtt_empty),     
        .prog_full  (mpt_wr_req_mtt_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[2 * 32 +: 1 * 32])        
    `endif
    );

    wire   mpt_req_mtt_prog_full;
    assign mpt_req_mtt_prog_full = mpt_wr_req_mtt_prog_full | mpt_rd_req_mtt_prog_full | mpt_rd_wqe_req_mtt_prog_full;
    //Action==Modify: maxiaoxiao, divide the mtt_ram_ctl req into read and write FIFOs


    //choose the selected req channel req fifo
    wire [255:0]  selected_req_data;
    assign selected_req_data =  (selected_channel[0] & selected_channel[8]) ? {128'b0,mpt_req_dout} :
                                (selected_channel[1] & selected_channel[8]) ? iv_db_vtp_cmd_data :
                                (selected_channel[2] & selected_channel[8]) ? iv_wp_vtp_wqe_cmd_data :
                                (selected_channel[3] & selected_channel[8]) ? iv_wp_vtp_nd_cmd_data :
                                (selected_channel[4] & selected_channel[8]) ? iv_rtc_vtp_cmd_data :
                                (selected_channel[5] & selected_channel[8]) ? iv_rrc_vtp_cmd_data :
                                (selected_channel[6] & selected_channel[8]) ? iv_rwm_vtp_cmd_data :
                                (selected_channel[7] & selected_channel[8]) ? iv_ee_vtp_cmd_data : 0;
    // pendingfifo--------------store the read miss request info 
    //| 207:200 | 199:168 | 167:136 | 135:104 | 103:72  |  71:40  |  39:8  | 7:4 | 3:0  |
    //| channel | length  | VA-high | VA-low  |   Key   |   PD    |  Flags |  Op | Tpye |
    reg                        pend_req_wr_en;
    wire                       pend_req_prog_full;
    reg   [207:0]              pend_req_din;
    reg                        pend_req_rd_en;
    wire  [207:0]              pend_req_dout;
    wire                       pend_req_empty;
    pend_req_208w16d pend_req_208w16d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (pend_req_wr_en),
        .rd_en      (pend_req_rd_en),
        .din        (pend_req_din),
        .dout       (pend_req_dout),
        .full       (),
        .empty      (pend_req_empty),     
        .prog_full  (pend_req_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[3 * 32 +: 1 * 32])        
    `endif
    );   

    // rd_mpt_req_fifo--------------store the read request info 
    //| 207:200 | 199:168 | 167:136 | 135:104 | 103:72  |  71:40  |  39:8  | 7:4 | 3:0  |
    //| channel | length  | VA-high | VA-low  |   Key   |   PD    |  Flags |  Op | Tpye |
    reg                        rd_mpt_req_wr_en;
    wire                       rd_mpt_req_prog_full;
    reg   [207:0]              rd_mpt_req_din;
    reg                        rd_mpt_req_rd_en;
    wire  [207:0]              rd_mpt_req_dout;
    wire                       rd_mpt_req_empty;

    pend_req_208w16d rd_mpt_req_208w16d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (rd_mpt_req_wr_en),
        .rd_en      (rd_mpt_req_rd_en),
        .din        (rd_mpt_req_din),
        .dout       (rd_mpt_req_dout),
        .full       (),
        .empty      (rd_mpt_req_empty),     
        .prog_full  (rd_mpt_req_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[4 * 32 +: 1 * 32])        
    `endif
    );   

//--------------{variable declaration}  end---------------//

//-----------------{dma mpt response and mpt_ram lookup state mechine} begin--------------------//
    //--------------{variable declaration}---------------
    localparam  MPT_IDLE       = 3'b001;
    // read: dma request backup info,dma rsp refill payload data,miss addr,pend_req_fifo
    // info match & check; 
    // write: rsp state fifo; updateqv_pend_channel_cnt; mpt_req_mtt fifo
    localparam  MPT_RSP_PROC   = 3'b010; 
    // read: CEU req header, and paylaod form req channel
    localparam  MPT_LOOKUP     = 3'b100; 
    
    reg [2:0] mpt_fsm_cs;
    reg [2:0] mpt_fsm_ns;

    //reg for dma_rd_mpt_bkup fifo entry
    reg  [DMA_RD_BKUP_WIDTH-1 : 0] qv_get_dma_rd_mpt_bkup;
    //reg for miss_addr fifo entry
    reg  [31:0]  qv_get_miss_addr;
    //reg for read pendingfifo info 
    reg  [207:0]  qv_get_pend_req;
    //reg for store dma rsp mpt data
    reg  [127 : 0] qv_get_dma_rsp_mpt_header;    
    reg  [511 : 0] qv_get_dma_rsp_mpt_data;    
    //cycle cnt for receive data
    reg  [2:0] qv_mpt_req_data_cnt;//cnt 2 cycle for receive mpt data from ceu
    reg  [2:0] qv_mpt_rsp_data_cnt;//cnt 2 cycle for receive mpt data from dma engine
    //store the processing req info and data
    reg [255 : 0] qv_req_info;
    reg [511 : 0] qv_wr_mpt_data;
    //if mpt comes back from dma engine, stall state processing untill the rsp mpt processed completely. 
    // wire          mpt_rsp_stall;

    //dma rsp mpt and pending req info match for response state and mtt req
    wire       rsp_match_success;
    wire       rsp_match_pd_err;
    wire       rsp_match_flags_err;
    wire       rsp_match_key_err;
    wire       rsp_match_len_err;
    wire [4:0] rsp_match_state;
    //resposne state fifo full signal
    wire       selected_rsp_state_prog_full;
    
//    mpt_ram_ctl_ila mpt_ram_ctl_ila(
//        .clk(clk),
//    .probe0(mpt_fsm_cs),//3 bit
//    .probe1(mpt_fsm_ns),//3 bit
//    //reg for dma_rd_mpt_bkup fifo entry
//    .probe2(qv_get_dma_rd_mpt_bkup),//99
//    //reg for miss_addr fifo entry
//    .probe3(qv_get_miss_addr),//32
//    //reg for read pendingfifo info 
//    .probe4(qv_get_pend_req),//208
//    //reg for store dma rsp mpt data
//    .probe5(qv_get_dma_rsp_mpt_header),//128    
//    .probe6(qv_get_dma_rsp_mpt_data),//512;    
//    //cycle cnt for receive data
//    .probe7(qv_mpt_req_data_cnt),//3//cnt 2 cycle for receive mpt data from ceu
//    .probe8(qv_mpt_rsp_data_cnt),//3//cnt 2 cycle for receive mpt data from dma engine
//    //store the processing req info and data
//    .probe9(qv_req_info),//256
//    .probe10(qv_wr_mpt_data),//512
//        .probe11(lookup_rden),//1
//        .probe12(lookup_wren),
//        .probe13(lookup_wdata),//512
//        //lookup info addr={(32-INDEX-TAG)'b0,lookup_tag,lookup_index}
//        .probe14(lookup_index),//12
//        .probe15(lookup_tag),//3
//        .probe16(mpt_req_mtt_wr_en),//
//    .probe17(mpt_req_mtt_din)//165
//    );

    //-----------------Stage 1 :State Register----------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mpt_fsm_cs <= `TD MPT_IDLE;
        end
        else begin
            mpt_fsm_cs <= `TD mpt_fsm_ns;
        end
    end
    //-----------------Stage 2 :State Transition----------
    always @(*) begin
        case (mpt_fsm_cs)
            MPT_IDLE: begin
                // if(dma_v2p_mpt_rd_rsp_tready && dma_v2p_mpt_rd_rsp_tvalid && lookup_allow_in && !miss_addr_empty && !pend_req_empty && !dma_rd_mpt_bkup_empty) begin
                if(dma_v2p_mpt_rd_rsp_tready && dma_v2p_mpt_rd_rsp_tvalid && lookup_allow_in) begin
                    mpt_fsm_ns = MPT_RSP_PROC;
                end
                else if (selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid && lookup_allow_in ) begin
                    mpt_fsm_ns = MPT_LOOKUP;
                end else begin
                    mpt_fsm_ns = MPT_IDLE;
                end
            end 
            MPT_RSP_PROC: begin
                //proc finish consider: read rsp data completely; mpt_ram allow in; rsp state fifo, mtt req fifo are not full
                //next state consider: dma_v2p_mpt_rd_rsp axis ready & valid signal(high priority); selected_channel[8] valid signal; miss_addr & pend_req & dma_rd_mpt_bkup fifo isn't empty
                if ((qv_mpt_rsp_data_cnt==2) && lookup_allow_in && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full && dma_v2p_mpt_rd_rsp_tready && dma_v2p_mpt_rd_rsp_tvalid && !dma_v2p_mpt_rd_rsp_tlast && !miss_addr_empty && !pend_req_empty && !dma_rd_mpt_bkup_empty && lookup_wren) begin
                    mpt_fsm_ns = MPT_RSP_PROC;
                end                
                else if ((qv_mpt_rsp_data_cnt==2) && lookup_allow_in && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full && selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid && lookup_wren) begin
                    mpt_fsm_ns = MPT_LOOKUP;
                end
                else if ((qv_mpt_rsp_data_cnt==2) && lookup_allow_in  && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full && !selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid && lookup_wren) begin
                    mpt_fsm_ns = MPT_IDLE;
                end
                else begin
                    mpt_fsm_ns = MPT_RSP_PROC;
                end
            end
            MPT_LOOKUP: begin
                //proc finish consider: ceu write mpt need 2 clks read mpt data; rdma engine req 1 clk; mpt_ram allow in; req_info_fifo isn't full
                //next state consider: dma_v2p_mpt_rd_rsp axis ready & valid signal(high priority); selected_channel[8] valid signal; miss_addr & pend_req & dma_rd_mpt_bkup fifo isn't empty
                if ((((((qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_WRITE}) && (qv_mpt_req_data_cnt == 2)) 
                | (qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_INVALID})) && lookup_wren) | 
                ((qv_req_info[255:128] != 128'b0) && !rd_mpt_req_prog_full && lookup_rden)) 
                && lookup_allow_in && dma_v2p_mpt_rd_rsp_tready && dma_v2p_mpt_rd_rsp_tvalid && 
                !miss_addr_empty && !pend_req_empty && !dma_rd_mpt_bkup_empty) begin
                    mpt_fsm_ns = MPT_RSP_PROC;
                end 
                else if ((((((qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_WRITE}) && (qv_mpt_req_data_cnt == 2)) 
                | (qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_INVALID})) && lookup_wren) | 
                ((qv_req_info[255:128] != 128'b0) && !rd_mpt_req_prog_full && lookup_rden)) 
                && lookup_allow_in  && selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid) begin
                    mpt_fsm_ns = MPT_LOOKUP;
                end
                // else if ((((((qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_WRITE}) && (qv_mpt_req_data_cnt == 2)) 
                // | (qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_INVALID})) && lookup_wren) | 
                // ((qv_req_info[255:128] != 128'b0) && !rd_mpt_req_prog_full && lookup_rden))
                // && lookup_allow_in  && !selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid) begin
                else if ((((((qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_WRITE}) && (qv_mpt_req_data_cnt == 2)) 
                | (qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_INVALID})) && lookup_wren) | 
                ((qv_req_info[255:128] != 128'b0) && !rd_mpt_req_prog_full && lookup_rden))
                && lookup_allow_in  && !selected_channel[8]) begin
                    mpt_fsm_ns = MPT_IDLE;
                end
                else begin
                    mpt_fsm_ns = MPT_LOOKUP;
                end
            end
            default: mpt_fsm_ns = MPT_IDLE;
        endcase
    end
    //-----------------Stage 3 :Output Decode------------------
    //------------------{interface to selected_channel_ctl module} begin--------
    //output reg                          req_read_already,
    //input  wire   [CHANNEL_WIDTH-1 :0]  selected_channel,
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            req_read_already <= `TD 0;
        end
        //if selected_channel valid, lookup_allow_in, haven't read the req, no mpt refill
        //set req_read_already = 1 for 1 cycle
        else begin
            case (mpt_fsm_cs)
                MPT_IDLE: begin
                    if (selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid && lookup_allow_in && !req_read_already) begin
                        req_read_already <= `TD 1;
                    end 
                    else begin
                        req_read_already <= `TD 0;
                    end
                end 
                MPT_RSP_PROC: begin
                    if ((qv_mpt_rsp_data_cnt==2) && lookup_allow_in  && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full &&  selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid && !req_read_already && lookup_wren) begin
                        req_read_already <= `TD 1;
                    end 
                    else begin
                        req_read_already <= `TD 0;
                    end
                end
                MPT_LOOKUP: begin
                    if ((((((qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_WRITE}) && (qv_mpt_req_data_cnt == 2)) | (qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_INVALID})) && lookup_wren) | ((qv_req_info[255:128] != 128'b0) && !rd_mpt_req_prog_full && lookup_rden)) && lookup_allow_in  && selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid && !req_read_already) begin
                        req_read_already <= `TD 1;
                    end 
                    else begin
                        req_read_already <= `TD 0;
                    end
                end
                default: req_read_already <= `TD 0;
            endcase
        end 
    end
    //------------------{interface to selected_channel_ctl module} end--------
    
    //-----------------------{data for get CEU & RDMA engine request} begin--------------------------
    //CEU request & RDMA engine request channel fifo read enable
    always @(*) begin
        if (rst) begin
            mpt_req_rd_en            = 0;
            o_db_vtp_cmd_rd_en       = 0;
            o_wp_vtp_wqe_cmd_rd_en   = 0;
            o_wp_vtp_nd_cmd_rd_en    = 0;
            o_rtc_vtp_cmd_rd_en      = 0;
            o_rrc_vtp_cmd_rd_en      = 0;
            o_rwm_vtp_cmd_rd_en      = 0;
            o_ee_vtp_cmd_rd_en       = 0;
        end
        else begin
            case (mpt_fsm_cs)
                MPT_IDLE: begin
                    if (selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid && lookup_allow_in && !req_read_already) begin
                        case (selected_channel[7:0])
                            8'b00000001: begin
                                mpt_req_rd_en             = 1;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end 
                            8'b00000010: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 1;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end 
                            8'b00000100: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 1;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end 
                            8'b00001000: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 1;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end 
                            8'b00010000: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 1;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end 
                            8'b00100000: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 1;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end 
                            8'b01000000: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 1;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end 
                            8'b10000000: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 1;
                            end 
                            default: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end
                        endcase
                    end 
                    else begin
                        mpt_req_rd_en             = 0;
                        o_db_vtp_cmd_rd_en        = 0;
                        o_wp_vtp_wqe_cmd_rd_en    = 0;
                        o_wp_vtp_nd_cmd_rd_en     = 0;
                        o_rtc_vtp_cmd_rd_en       = 0;
                        o_rrc_vtp_cmd_rd_en       = 0;
                        o_rwm_vtp_cmd_rd_en       = 0;
                        o_ee_vtp_cmd_rd_en        = 0;
                    end
                end 
                MPT_RSP_PROC: begin
                    if ((qv_mpt_rsp_data_cnt==2) && lookup_allow_in  && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full &&  selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid && !req_read_already && lookup_wren) begin
                        case (selected_channel[7:0])
                            8'b00000001: begin
                                mpt_req_rd_en             = 1;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end 
                            8'b00000010: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 1;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end 
                            8'b00000100: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 1;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end 
                            8'b00001000: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 1;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end 
                            8'b00010000: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 1;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end 
                            8'b00100000: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 1;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end 
                            8'b01000000: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 1;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end 
                            8'b10000000: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 1;
                            end 
                            default: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end
                        endcase
                    end 
                    else begin
                        mpt_req_rd_en             = 0;
                        o_db_vtp_cmd_rd_en        = 0;
                        o_wp_vtp_wqe_cmd_rd_en    = 0;
                        o_wp_vtp_nd_cmd_rd_en     = 0;
                        o_rtc_vtp_cmd_rd_en       = 0;
                        o_rrc_vtp_cmd_rd_en       = 0;
                        o_rwm_vtp_cmd_rd_en       = 0;
                        o_ee_vtp_cmd_rd_en        = 0;
                    end
                end
                MPT_LOOKUP: begin
                    if ((((((qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_WRITE}) && (qv_mpt_req_data_cnt == 2)) | (qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_INVALID})) && lookup_wren) | ((qv_req_info[255:128] != 128'b0) && !rd_mpt_req_prog_full && lookup_rden)) && lookup_allow_in  && selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid && !req_read_already) begin
                        case (selected_channel[7:0])
                            8'b00000001: begin
                                mpt_req_rd_en             = 1;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end 
                            8'b00000010: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 1;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end 
                            8'b00000100: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 1;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end 
                            8'b00001000: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 1;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end 
                            8'b00010000: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 1;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end 
                            8'b00100000: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 1;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end 
                            8'b01000000: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 1;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end 
                            8'b10000000: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 1;
                            end 
                            default: begin
                                mpt_req_rd_en             = 0;
                                o_db_vtp_cmd_rd_en        = 0;
                                o_wp_vtp_wqe_cmd_rd_en    = 0;
                                o_wp_vtp_nd_cmd_rd_en     = 0;
                                o_rtc_vtp_cmd_rd_en       = 0;
                                o_rrc_vtp_cmd_rd_en       = 0;
                                o_rwm_vtp_cmd_rd_en       = 0;
                                o_ee_vtp_cmd_rd_en        = 0;
                            end
                        endcase
                    end 
                    else begin
                        mpt_req_rd_en             = 0;
                        o_db_vtp_cmd_rd_en        = 0;
                        o_wp_vtp_wqe_cmd_rd_en    = 0;
                        o_wp_vtp_nd_cmd_rd_en     = 0;
                        o_rtc_vtp_cmd_rd_en       = 0;
                        o_rrc_vtp_cmd_rd_en       = 0;
                        o_rwm_vtp_cmd_rd_en       = 0;
                        o_ee_vtp_cmd_rd_en        = 0;
                    end
                end
                default: begin
                        mpt_req_rd_en             = 0;
                        o_db_vtp_cmd_rd_en        = 0;
                        o_wp_vtp_wqe_cmd_rd_en    = 0;
                        o_wp_vtp_nd_cmd_rd_en     = 0;
                        o_rtc_vtp_cmd_rd_en       = 0;
                        o_rrc_vtp_cmd_rd_en       = 0;
                        o_rwm_vtp_cmd_rd_en       = 0;
                        o_ee_vtp_cmd_rd_en        = 0;
                    end
            endcase
        end
    end
    //store the processing req info and data
        //reg [255 : 0] qv_req_info;
    /*Spyglass*/
    //always @(*) begin
    reg [7:0] qv_selected_channel;
    always @(posedge clk or posedge rst) begin
    /*Action = Modify*/
        if (rst) begin
            qv_req_info  <= `TD 0;
            qv_selected_channel <= `TD 0;
        end
        else begin
            case (mpt_fsm_cs)
                MPT_IDLE: begin
                    if (selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid && lookup_allow_in && !req_read_already) begin
                        qv_req_info  <= `TD selected_req_data;
                        qv_selected_channel <= `TD selected_channel[7:0];
                    end 
                    else begin
                        qv_req_info  <= `TD 0;
                        qv_selected_channel <= `TD 0;
                    end
                end 
                MPT_RSP_PROC: begin
                    if ((qv_mpt_rsp_data_cnt==2) && lookup_allow_in && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full &&  selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid && !req_read_already && lookup_wren) begin
                        qv_req_info  <= `TD selected_req_data;
                        qv_selected_channel <= `TD selected_channel[7:0];
                    end 
                    else begin
                        qv_req_info  <= `TD 0;
                        qv_selected_channel <= `TD 0;
                    end
                end
                MPT_LOOKUP: begin
                    if ((((((qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_WRITE}) && (qv_mpt_req_data_cnt == 2)) | (qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_INVALID})) && lookup_wren) | ((qv_req_info[255:128] != 128'b0) && !rd_mpt_req_prog_full && lookup_rden)) && lookup_allow_in  && selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid && !req_read_already ) begin
                        qv_req_info  <= `TD selected_req_data;
                        qv_selected_channel <= `TD selected_channel[7:0];
                    end 
                    else begin
                        qv_req_info  <= `TD qv_req_info;
                        qv_selected_channel <= `TD qv_selected_channel;
                    end
                end
                default: begin
                    qv_req_info  <= `TD 0;
                    qv_selected_channel <= `TD 0;
                end
            endcase
        end
    end

    //CEU payload fifo read enable   
        //out reg   mpt_data_rd_en;
    always @(*) begin
        if (rst) begin
            mpt_data_rd_en  = 0;
        end
        else begin
            case (mpt_fsm_cs)
                MPT_IDLE: begin
                    if (selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid && lookup_allow_in && !req_read_already && (selected_channel[7:0] == 8'b00000001) && (mpt_req_dout[127:120] == {`WR_MPT_TPT,`WR_MPT_WRITE})) begin
                        mpt_data_rd_en  = 1;
                    end 
                    else begin
                        mpt_data_rd_en  = 0;
                    end
                end 
                MPT_RSP_PROC: begin
                    if ((qv_mpt_rsp_data_cnt==2) && lookup_wren && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full && selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid && !req_read_already && (selected_channel[7:0] == 8'b00000001) && (mpt_req_dout[127:120] == {`WR_MPT_TPT,`WR_MPT_WRITE})) begin
                        mpt_data_rd_en  = 1;
                    end 
                    else begin
                        mpt_data_rd_en  = 0;
                    end
                end
                MPT_LOOKUP: begin
                    //1st cycle read payload | 2ed cycle read payload
                    if ((((((qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_WRITE}) && (qv_mpt_req_data_cnt == 2)) | (qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_INVALID})) && lookup_wren) | ((qv_req_info[255:128] != 128'b0) && !rd_mpt_req_prog_full && lookup_rden)) && lookup_allow_in  && selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid && !req_read_already && (selected_channel[7:0] == 8'b00000001) && (mpt_req_dout[127:120] == {`WR_MPT_TPT,`WR_MPT_WRITE})) begin
                        mpt_data_rd_en  = 1;
                    end 
                    else if ((qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_WRITE}) && (qv_mpt_req_data_cnt == 1) && lookup_allow_in && !mpt_data_empty) begin
                        mpt_data_rd_en  = 1;
                    end
                    else begin
                        mpt_data_rd_en  = 0;
                    end
                end 
                default: begin
                    mpt_data_rd_en  = 0;
                end
            endcase
        end
    end
    //CEU payload fifo read cycle cnt & payload data reg 
        //reg  [2:0] qv_mpt_req_data_cnt;
        //reg [511 : 0] qv_wr_mpt_data;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_mpt_req_data_cnt <= `TD 0;
            qv_wr_mpt_data  <= `TD 0;
        end
        else begin
            case (mpt_fsm_cs)
                MPT_IDLE: begin
                    if (selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid && lookup_allow_in  && !req_read_already && (selected_channel[7:0] == 8'b00000001) && (mpt_req_dout[127:120] == {`WR_MPT_TPT,`WR_MPT_WRITE})) begin
                        qv_mpt_req_data_cnt <= `TD 1;
                        /*VCS Verification*/
                        // qv_wr_mpt_data  <= `TD {256'b0, mpt_data_dout};
                        qv_wr_mpt_data  <= `TD {mpt_data_dout,256'b0};
                        /*Action = Modify, correct the bytes sequences*/
                    end 
                    else begin
                        qv_mpt_req_data_cnt <= `TD 0;
                        qv_wr_mpt_data  <= `TD 0;                        
                    end
                end 
                MPT_RSP_PROC: begin
                    if ((qv_mpt_rsp_data_cnt==2) && lookup_allow_in && lookup_wren && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full && selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid && !req_read_already && (selected_channel[7:0] == 8'b00000001) && (mpt_req_dout[127:120] == {`WR_MPT_TPT,`WR_MPT_WRITE})) begin
                        qv_mpt_req_data_cnt <= `TD 1;
                        /*VCS Verification*/
                        // qv_wr_mpt_data  <= `TD {256'b0, mpt_data_dout};
                        qv_wr_mpt_data  <= `TD {mpt_data_dout,256'b0};
                        /*Action = Modify, correct the bytes sequences*/
                    end 
                    else begin
                        qv_mpt_req_data_cnt <= `TD 0;
                        qv_wr_mpt_data  <= `TD 0;                        
                    end
                end
                MPT_LOOKUP: begin
                    //1st cycle read payload | 2ed cycle read payload
                    if ((((((qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_WRITE}) && (qv_mpt_req_data_cnt == 2)) | (qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_INVALID})) && lookup_wren) | ((qv_req_info[255:128] != 128'b0) && !rd_mpt_req_prog_full && lookup_rden)) && lookup_allow_in  && selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid && !req_read_already  && (selected_channel[7:0] == 8'b00000001) && (mpt_req_dout[127:120] == {`WR_MPT_TPT,`WR_MPT_WRITE})) begin
                        qv_mpt_req_data_cnt <= `TD 1;
                        /*VCS Verification*/
                        // qv_wr_mpt_data  <= `TD {256'b0, mpt_data_dout};
                        qv_wr_mpt_data  <= `TD {mpt_data_dout,256'b0};
                        /*Action = Modify, correct the bytes sequences*/
                    end 
                    else if ((qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_WRITE}) && (qv_mpt_req_data_cnt == 1) && lookup_allow_in  && !mpt_data_empty) begin
                        qv_mpt_req_data_cnt <= `TD qv_mpt_req_data_cnt + 1;
                        /*VCS Verification*/
                        // qv_wr_mpt_data  <= `TD {mpt_data_dout,qv_wr_mpt_data[255:0]};
                        qv_wr_mpt_data  <= `TD {qv_wr_mpt_data[511:256],mpt_data_dout};
                        /*Action = Modify, correct the bytes sequences*/
                    end
                    else begin
                        qv_mpt_req_data_cnt <= `TD qv_mpt_req_data_cnt;
                        qv_wr_mpt_data  <= `TD qv_wr_mpt_data;                        
                    end
                end 
                default: begin
                    qv_mpt_req_data_cnt <= `TD 0;
                    qv_wr_mpt_data  <= `TD 0;                        
                end
            endcase
        end
    end
    //-----------------------{data for get CEU & RDMA engine request} end--------------------------
    
    //---------------------------{data for dam rsp processing} begin-------------------
    //---------interface to dma_read_ctx module----
        //read dma req header metadata from backup fifo (1 entry/dma req)
            //output reg                             dma_rd_mpt_bkup_rd_en,
            //| --------99  bit------|
            //| index | opcode | len |
            //|  64   |    3   | 32  |
    //---------interface to mpt_ram module----
        //miss read addr in fifo, for pending fifo addr to refill
            //output reg                      miss_addr_rd_en,

    //---------interface to internal pendingfifo module----
        // pendingfifo stores the read miss request info 
            //| 207:200 | 199:168 | 167:136 | 135:104 | 103:72  |  71:40  |  39:8  | 7:4 | 3:0  |
            //| channel | length  | VA-high | VA-low  |   Key   |   PD    |  Flags |  Op | Tpye |
            //reg                        pend_req_rd_en;
    always @(*) begin
        if (rst) begin
            dma_rd_mpt_bkup_rd_en  = 0;
            miss_addr_rd_en        = 0;
            pend_req_rd_en         = 0;
        end
        else begin
            case (mpt_fsm_cs)
                //next cycle is MPT_RSP_PROC state, read the dma_rd_mpt_bkup/miss_addr/pend_req fifo
                MPT_IDLE: begin
                    if(dma_v2p_mpt_rd_rsp_tready && dma_v2p_mpt_rd_rsp_tvalid && lookup_allow_in  && !miss_addr_empty && !pend_req_empty && !dma_rd_mpt_bkup_empty) begin
                        dma_rd_mpt_bkup_rd_en  = 1;
                        miss_addr_rd_en        = 1;
                        pend_req_rd_en         = 1;
                    end
                    else begin
                        dma_rd_mpt_bkup_rd_en  = 0;
                        miss_addr_rd_en        = 0;
                        pend_req_rd_en         = 0;
                    end
                end 
                //next cycle is MPT_RSP_PROC state, read the dma_rd_mpt_bkup/miss_addr/pend_req fifo
                MPT_RSP_PROC: begin
                    if ((qv_mpt_rsp_data_cnt==2) && lookup_allow_in && lookup_wren && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full &&   dma_v2p_mpt_rd_rsp_tready && dma_v2p_mpt_rd_rsp_tvalid && !miss_addr_empty && !pend_req_empty && !dma_rd_mpt_bkup_empty) begin
                        dma_rd_mpt_bkup_rd_en  = 1;
                        miss_addr_rd_en        = 1;
                        pend_req_rd_en         = 1;
                    end
                    else begin
                        dma_rd_mpt_bkup_rd_en  = 0;
                        miss_addr_rd_en        = 0;
                        pend_req_rd_en         = 0;
                    end
                end
                //next cycle is MPT_RSP_PROC state, read the dma_rd_mpt_bkup/miss_addr/pend_req fifo
                MPT_LOOKUP: begin
                    if ((((((qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_WRITE}) && (qv_mpt_req_data_cnt == 2)) | (qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_INVALID})) && lookup_wren) | ((qv_req_info[255:128] != 128'b0) && !rd_mpt_req_prog_full && lookup_rden)) && lookup_allow_in  && dma_v2p_mpt_rd_rsp_tready && dma_v2p_mpt_rd_rsp_tvalid  && !miss_addr_empty && !pend_req_empty && !dma_rd_mpt_bkup_empty) begin
                        dma_rd_mpt_bkup_rd_en  = 1;
                        miss_addr_rd_en        = 1;
                        pend_req_rd_en         = 1;
                    end
                    else begin
                        dma_rd_mpt_bkup_rd_en  = 0;
                        miss_addr_rd_en        = 0;
                        pend_req_rd_en         = 0;
                    end
                end
                default: begin
                    dma_rd_mpt_bkup_rd_en  = 0;
                    miss_addr_rd_en        = 0;
                    pend_req_rd_en         = 0;
                end
            endcase
        end
    end
        
    //reg for dma_rd_mpt_bkup fifo entry
        // reg  [DMA_RD_BKUP_WIDTH-1 : 0] qv_get_dma_rd_mpt_bkup;
    //reg for miss_addr fifo entry
        //reg  [31:0]  qv_get_miss_addr;
    //reg for read pendingfifo info 
        //reg  [207:0]  qv_get_pend_req; 
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_get_dma_rd_mpt_bkup <= `TD 0;
            qv_get_miss_addr       <= `TD 0;
            qv_get_pend_req        <= `TD 0;
        end
        else begin
            case (mpt_fsm_cs)
                //next cycle is MPT_RSP_PROC state, read the dma_rd_mpt_bkup/miss_addr/pend_req fifo
                MPT_IDLE: begin
                    if(dma_v2p_mpt_rd_rsp_tready && dma_v2p_mpt_rd_rsp_tvalid && lookup_allow_in  && !miss_addr_empty && !pend_req_empty && !dma_rd_mpt_bkup_empty) begin
                        qv_get_dma_rd_mpt_bkup <= `TD dma_rd_mpt_bkup_dout;
                        qv_get_miss_addr       <= `TD miss_addr_dout;
                        qv_get_pend_req        <= `TD pend_req_dout;                       
                    end
                    else begin
                        qv_get_dma_rd_mpt_bkup <= `TD 0;
                        qv_get_miss_addr       <= `TD 0;
                        qv_get_pend_req        <= `TD 0;                    
                    end
                end 
                //next cycle is MPT_RSP_PROC state, read the dma_rd_mpt_bkup/miss_addr/pend_req fifo
                MPT_RSP_PROC: begin
                    if ((qv_mpt_rsp_data_cnt==2) && lookup_allow_in && lookup_wren && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full &&   dma_v2p_mpt_rd_rsp_tready && dma_v2p_mpt_rd_rsp_tvalid && !miss_addr_empty && !pend_req_empty && !dma_rd_mpt_bkup_empty) begin
                        qv_get_dma_rd_mpt_bkup <= `TD dma_rd_mpt_bkup_dout;
                        qv_get_miss_addr       <= `TD miss_addr_dout;
                        qv_get_pend_req        <= `TD pend_req_dout;                       
                    end
                    else begin
                        qv_get_dma_rd_mpt_bkup <= `TD qv_get_dma_rd_mpt_bkup;
                        qv_get_miss_addr       <= `TD qv_get_miss_addr      ;
                        qv_get_pend_req        <= `TD qv_get_pend_req       ;                
                    end
                end
                //next cycle is MPT_RSP_PROC state, read the dma_rd_mpt_bkup/miss_addr/pend_req fifo
                MPT_LOOKUP: begin
                    if ((((((qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_WRITE}) && (qv_mpt_req_data_cnt == 2)) | (qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_INVALID})) && lookup_wren) | ((qv_req_info[255:128] != 128'b0) && !rd_mpt_req_prog_full && lookup_rden)) && lookup_allow_in  && dma_v2p_mpt_rd_rsp_tready && dma_v2p_mpt_rd_rsp_tvalid  && !miss_addr_empty && !pend_req_empty && !dma_rd_mpt_bkup_empty) begin
                        qv_get_dma_rd_mpt_bkup <= `TD dma_rd_mpt_bkup_dout;
                        qv_get_miss_addr       <= `TD miss_addr_dout;
                        qv_get_pend_req        <= `TD pend_req_dout;                       
                    end
                    else begin
                        qv_get_dma_rd_mpt_bkup <= `TD 0;
                        qv_get_miss_addr       <= `TD 0;
                        qv_get_pend_req        <= `TD 0;                    
                    end
                end
                default: begin
                    qv_get_dma_rd_mpt_bkup <= `TD 0;
                    qv_get_miss_addr       <= `TD 0;
                    qv_get_pend_req        <= `TD 0;                 
                end
            endcase
        end
    end
        
    //-----------------interface to DMA Engine module------------------
    //read MPT Ctx payload response from DMA Engine module     
        //output  wire           dma_v2p_mpt_rd_rsp_tready,
    assign dma_v2p_mpt_rd_rsp_tready = (!selected_rsp_state_prog_full && lookup_allow_in  && !mpt_req_mtt_prog_full) ? 1 : 0;

    //reg for store dma rsp mpt data
        //reg  [127 : 0] qv_get_dma_rsp_mpt_header;    
        //reg  [511 : 0] qv_get_dma_rsp_mpt_data;  
    //cnt 2 cycle for receive mpt data from dma engine
        //reg  [2:0] qv_mpt_rsp_data_cnt;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_get_dma_rsp_mpt_header <= `TD 0;
            qv_get_dma_rsp_mpt_data   <= `TD 0;
            qv_mpt_rsp_data_cnt       <= `TD 0;
        end
        else begin
            case (mpt_fsm_cs)
                //next cycle is MPT_RSP_PROC state, get the response header & 1st clk data from dma engine
                MPT_IDLE: begin
                    if(dma_v2p_mpt_rd_rsp_tready && dma_v2p_mpt_rd_rsp_tvalid && lookup_allow_in  && !miss_addr_empty && !pend_req_empty && !dma_rd_mpt_bkup_empty) begin
                        qv_get_dma_rsp_mpt_header <= `TD dma_v2p_mpt_rd_rsp_theader;
                        /*VCS Verification*/
                        /*Action = Modify, correct the bytes sequences*/
                        qv_get_dma_rsp_mpt_data   <= `TD {dma_v2p_mpt_rd_rsp_tdata,256'b0};
                        qv_mpt_rsp_data_cnt       <= `TD 1;
                    end
                    else begin
                        qv_get_dma_rsp_mpt_header <= `TD 0;
                        qv_get_dma_rsp_mpt_data   <= `TD 0;
                        qv_mpt_rsp_data_cnt       <= `TD 0;
                    end
                end 
                MPT_RSP_PROC: begin
                    //next cycle is MPT_RSP_PROC state, get the response header & 1st clk data from dma engine
                    if ((qv_mpt_rsp_data_cnt == 2) && lookup_allow_in && lookup_wren && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full &&   dma_v2p_mpt_rd_rsp_tready && dma_v2p_mpt_rd_rsp_tvalid && !miss_addr_empty && !pend_req_empty &&  !dma_rd_mpt_bkup_empty) begin
                        qv_get_dma_rsp_mpt_header <= `TD dma_v2p_mpt_rd_rsp_theader;
                        /*VCS Verification*/
                        /*Action = Modify, correct the bytes sequences*/
                        qv_get_dma_rsp_mpt_data   <= `TD {dma_v2p_mpt_rd_rsp_tdata,256'b0};
                        qv_mpt_rsp_data_cnt       <= `TD 1;                      
                    end
                    //get the 2nd clk mpt data               
                    else if ((qv_mpt_rsp_data_cnt == 1) && dma_v2p_mpt_rd_rsp_tready && dma_v2p_mpt_rd_rsp_tvalid && dma_v2p_mpt_rd_rsp_tlast) begin
                        /*VCS Verification*/
                        /*Action = Modify, correct the bytes sequences*/
                        qv_get_dma_rsp_mpt_data   <= `TD {qv_get_dma_rsp_mpt_data[511:256],dma_v2p_mpt_rd_rsp_tdata};
                        qv_get_dma_rsp_mpt_header <= `TD qv_get_dma_rsp_mpt_header;
                        qv_mpt_rsp_data_cnt       <= `TD qv_mpt_rsp_data_cnt + 1;       
                    end
                    /*VCS Verification*/
                    else if ((qv_mpt_rsp_data_cnt==2) && lookup_allow_in && lookup_wren && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full && !dma_v2p_mpt_rd_rsp_tvalid) begin
                        qv_get_dma_rsp_mpt_header <= `TD 0;
                        qv_get_dma_rsp_mpt_data   <= `TD 0;
                        qv_mpt_rsp_data_cnt       <= `TD 0;
                    end
                    /*Action = Add, if next state is MPT_IDLE or MPT_LOOKUP, regs are reset*/
                    else begin
                        qv_get_dma_rsp_mpt_header <= `TD qv_get_dma_rsp_mpt_header;
                        qv_get_dma_rsp_mpt_data   <= `TD qv_get_dma_rsp_mpt_data  ;
                        qv_mpt_rsp_data_cnt       <= `TD qv_mpt_rsp_data_cnt;       
                    end
                end
                //next cycle is MPT_RSP_PROC state, get the response header & 1st clk data from dma engine
                MPT_LOOKUP: begin
                    if ((((((qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_WRITE}) && (qv_mpt_req_data_cnt == 2)) | (qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_INVALID})) && lookup_wren) | ((qv_req_info[255:128] != 128'b0) && !rd_mpt_req_prog_full && lookup_rden)) && lookup_allow_in  && dma_v2p_mpt_rd_rsp_tready && dma_v2p_mpt_rd_rsp_tvalid && !miss_addr_empty && !pend_req_empty && !dma_rd_mpt_bkup_empty) begin
                        qv_get_dma_rsp_mpt_header <= `TD dma_v2p_mpt_rd_rsp_theader;
                        /*VCS Verification*/
                        /*Action = Modify, correct the bytes sequences*/
                        qv_get_dma_rsp_mpt_data   <= `TD {dma_v2p_mpt_rd_rsp_tdata,256'b0};
                        qv_mpt_rsp_data_cnt       <= `TD 1;                      
                    end
                    else begin
                        qv_get_dma_rsp_mpt_header <= `TD 0;
                        qv_get_dma_rsp_mpt_data   <= `TD 0;
                        qv_mpt_rsp_data_cnt       <= `TD 0;
                    end
                end
                default: begin
                    qv_get_dma_rsp_mpt_header <= `TD 0;
                    qv_get_dma_rsp_mpt_data   <= `TD 0;
                    qv_mpt_rsp_data_cnt       <= `TD 0;
                end
            endcase
        end    
    end

    //if mpt comes back from dma engine, stall state processing untill the rsp mpt processed completely. 
        //wire          mpt_rsp_stall;
    /*VCS Verification*/        
    // assign mpt_rsp_stall = (mpt_fsm_cs == MPT_RSP_PROC) ? 1 : 0;
    assign mpt_rsp_stall = ((mpt_fsm_cs == MPT_RSP_PROC) | (mpt_fsm_ns == MPT_RSP_PROC)) ? 1 : 0;
    /*Action = Modify, add (mpt_fsm_ns != MPT_RSP_PROC) condition to solve the state_rd_en/rd_mpt_req_rd_en signals jump problem*/

    //dma rsp mpt and pending req info match for response state and mtt req
        //wire       rsp_match_success;
        //wire       rsp_match_pd_err;
        //wire       rsp_match_flags_err;
        //wire       rsp_match_key_err;
        //wire       rsp_match_len_err;
        //wire [7:0] rsp_match_state;
    // pendingfifo--------------store the read miss request info 
        //| 207:200 | 199:168 | 167:136 | 135:104 | 103:72  |  71:40  |  39:8  | 7:4 | 3:0  |
        //| channel | length  | VA-high | VA-low  |   Key   |   PD    |  Flags |  Op | Tpye |
    //***********************mpt data tranfer      format*************************/
        //32*8 -1: 32*7 |   Flags                        |
        //32*7 -1: 32*6 |   page_size                    |
        //32*6 -1: 32*5 |   Key                          |
        //32*5 -1: 32*4 |   PD                           | clk 1
        //32*4 -1: 32*3 |   start-high                   |
        //32*3 -1: 32*2 |   start-low                    |
        //32*2 -1: 32*1 |   length-high                  |
        //32*1 -1: 32*0 |   length-low                   |
    
        //32*8 -1: 32*7 |   lkey             (Reserved)  |
        //32*7 -1: 32*6 |   window_cnt       (Reserved)  |
        //32*6 -1: 32*5 |   window_cnt_limit (Reserved)  |
        //32*5 -1: 32*4 |   mtt_seg_high                 | clk 2
        //32*4 -1: 32*3 |   mtt_seg_low                  |
        //32*3 -1: 32*2 |   mtt_size         (Reserved)  |
        //32*2 -1: 32*0 |   0                (Reserved)  |
    //***********************mpt data format*************************/
        /**********************MPT Flags****************************/
        // MPT表项属�?�标志位
        // MTHCA_MPT_FLAG_SW_OWNS �?31:28�?
        // ABSOLUTE_ADDR�?27�?
        // RELATIVE_ADDR�?26�?
        // MTHCA_MPT_FLAG_MIO �?17�?
        // MTHCA_MPT_FLAG_BIND_ENABLE�?15�?
        // MTHCA_MPT_FLAG_PHYSICAL�?9�?
        // MTHCA_MPT_FLAG_REGION�?8�?
        // MPT表项访问权限标志�?
        // IBV_ACCESS_LOCAL_WRITE�?0�?
        // IBV_ACCESS_REMOTE_WRITE�?1�?
        // IBV_ACCESS_REMOTE_READ	�?2�?
        // IBV_ACCESS_REMOTE_ATOMIC�?3�?
        // IBV_ACCESS_MW_BIND�?4�?
        // IBV_ACCESS_ZERO_BASED�?5�?
        // IBV_ACCESS_ON_DEMAND�?6�?
        /*****************************************************/
    assign rsp_match_success = !rsp_match_pd_err && !rsp_match_flags_err && !rsp_match_key_err && !rsp_match_len_err;
    //mpt flags includes all flags in req, except the absolute/relative addr flags in req flags
    //the 2 addr type flags can not be equal
    /*VCS Verification*/
    // assign rsp_match_flags_err = (((qv_get_pend_req[31+8:8] | {qv_get_dma_rsp_mpt_data[31:28],2'b11,qv_get_dma_rsp_mpt_data[25:0]}) == {qv_get_dma_rsp_mpt_data[31:28],2'b11,qv_get_dma_rsp_mpt_data[25:0]}) && (qv_get_pend_req[26+8] != qv_get_pend_req[27+8])) ? 0 :1;
    
    // assign rsp_match_pd_err  = (qv_get_pend_req[32*2+8-1:32*1+8] == qv_get_dma_rsp_mpt_data[32*4 -1: 32*3]) ? 0 :1;
    // //need check the key if valid at the time receive the lookup state, not get the rsp mpt data
    // assign rsp_match_key_err = (qv_get_pend_req[32*3+8-1:32*2+8] == qv_get_dma_rsp_mpt_data[32*3 -1: 32*2]) ? 0 :1;
    // //check if the req mpt addr exceed the border
    //     // relative addr: req_length + req_v_addr <= mpt_length                   --------No Err
    //     // absolute addr: req_length + req_v_addr <= mpt_length + mpt_start_addr  --------No Err
    // assign rsp_match_len_err = ((qv_get_pend_req[26+8] && (qv_get_pend_req[32*5+8-1:32*3+8] + qv_get_pend_req[32*6+8-1:32*5+8] <= qv_get_dma_rsp_mpt_data[32*8 -1: 32*6])) |
    //                             (qv_get_pend_req[27+8] && (qv_get_pend_req[32*5+8-1:32*3+8] + qv_get_pend_req[32*6+8-1:32*5+8] <= qv_get_dma_rsp_mpt_data[32*6 -1: 32*4] + qv_get_dma_rsp_mpt_data[32*8 -1: 32*6]))) ? 0 :1;
    
    assign rsp_match_flags_err = (((qv_get_pend_req[31+8:8] | {qv_get_dma_rsp_mpt_data[32*(8+8)-1:32*(8+8)-4],2'b11,qv_get_dma_rsp_mpt_data[32*(7+8)+25:32*(7+8)]}) == {qv_get_dma_rsp_mpt_data[32*(8+8)-1:32*(8+8)-4],2'b11,qv_get_dma_rsp_mpt_data[32*(7+8)+25:32*(7+8)]}) && (qv_get_pend_req[26+8] != qv_get_pend_req[27+8])) ? 0 :1;
    
    assign rsp_match_pd_err  = (qv_get_pend_req[32*2+8-1:32*1+8] == qv_get_dma_rsp_mpt_data[32*(5+8)-1: 32*(4+8)]) ? 0 :1;
    //need check the key if valid at the time receive the lookup state, not get the rsp mpt data
    assign rsp_match_key_err = (qv_get_pend_req[32*3+8-1:32*2+8] == qv_get_dma_rsp_mpt_data[32*(6+8) -1: 32*(5+8)]) ? 0 :1;
    //check if the req mpt addr exceed the border
        // relative addr: req_length + req_v_addr <= mpt_length                   --------No Err
        // absolute addr: req_length + req_v_addr <= mpt_length + mpt_start_addr  --------No Err
    assign rsp_match_len_err = ((qv_get_pend_req[26+8] && (qv_get_pend_req[32*5+8-1:32*3+8] + qv_get_pend_req[32*6+8-1:32*5+8] <= qv_get_dma_rsp_mpt_data[32*(2+8)-1: 32*8])) |
                                (qv_get_pend_req[27+8] && (qv_get_pend_req[32*5+8-1:32*3+8] + qv_get_pend_req[32*6+8-1:32*5+8] <= qv_get_dma_rsp_mpt_data[32*(4+8)-1: 32*(2+8)] + qv_get_dma_rsp_mpt_data[32*(2+8)-1: 32*8]))) ? 0 :1;
    /*Action = Modify, correct the bytes sequences*/
    // assign rsp_match_state = rsp_match_success   ? `SUCCESS :
    //                          rsp_match_pd_err    ? `PD_ERR  :
    //                          rsp_match_flags_err ? `FLAGS_ERR :
    //                          rsp_match_key_err   ? `KEY_ERR :
    //                          rsp_match_len_err   ? `LENGTH_ERR : 0;
    assign rsp_match_state = {rsp_match_success, 
                            rsp_match_len_err ,
                            rsp_match_key_err ,
                            rsp_match_flags_err,
                            rsp_match_pd_err}; 
    //---------------------------{data for dam rsp processing} end-------------------
      
    //-----------------initiate mpt_ram request---------------------
    //RDMA engine request format(256 bits) info 
        //| 255:224 | 223:192 | 191:160 | 159:128 | 127:96  |  95:64  |  63:32  |  31:8 | 7:4 | 3:0 |
        //| Reserve | length  | VA-high | VA-low  |   Key   |   PD    |  Flags  |  Resv |  Op | Tpye|
    //CEU request format(128 bit) info
        //|  127:124 |  123:120 | 119:96 |   95:64   | 63:0  |
        //|   type   |  opcode  |    R   | mpt_index |   R   |
        //CMD_SW2HW_MPT head:| (WR_MPT_TPT) | (WR_MPT_WRITE)   | void | index | void |
        //CMD_HW2SW_MPT head:| (WR_MPT_TPT) | (WR_MPT_INVALID) | void | index | void |

    //lookup info addr={(32-INDEX-TAG)'b0,lookup_tag,lookup_index}
    wire [31:0] lookup_addr;
    //make sure the relationship between lkey and index; index and lkey both are mpt number
    //(1) next state is MPT_LOOKUP & req from rdma engine; (2) next state is MPT_LOOKUP & req from ceu
    //(3) current clk has got 1st mpt data from dma engine in MPT_RSP_PROC; (4) current clk has got 1st mpt data from ceu in MPT_LOOKUP 
    // assign lookup_addr = ((mpt_fsm_ns == MPT_LOOKUP) && !selected_channel[0]) ? selected_req_data[32*4-1 : 32*3] :
    //                 ((mpt_fsm_ns == MPT_LOOKUP) && selected_channel[0]) ? (qv_req_info[32*3-1 : 32*2] | selected_req_data[32*3-1 : 32*2]) :
    //                 ((mpt_fsm_cs == MPT_RSP_PROC) && (qv_mpt_rsp_data_cnt < 2)) ? qv_get_pend_req[32*3+8-1:32*2+8] :
    //                 ((mpt_fsm_cs == MPT_LOOKUP) && (qv_mpt_req_data_cnt < 2) && selected_channel[0]) ? qv_req_info[32*3-1 : 32*2] : 
    //                 ((mpt_fsm_cs == MPT_LOOKUP) && !selected_channel[0]) ? qv_req_info[32*4-1 : 32*3] : 0;
    assign lookup_addr = ((mpt_fsm_cs == MPT_RSP_PROC) && (qv_mpt_rsp_data_cnt == 2)) ? qv_get_pend_req[32*3+8-1:32*2+8] :
                    ((mpt_fsm_cs == MPT_LOOKUP) && selected_channel[0]) ? qv_req_info[32*3-1 : 32*2] : 
                    ((mpt_fsm_cs == MPT_LOOKUP) && !selected_channel[0]) ? qv_req_info[32*4-1 : 32*3] : 0;
  
    //output reg                      lookup_rden,
    //output reg                      lookup_wren,
    //output reg  [LINE_SIZE*8-1:0]   lookup_wdata,
    //output reg  [INDEX -1     :0]   lookup_index,
    //output reg  [TAG -1       :0]   lookup_tag,
    /*Spyglass*/
    assign lookup_stall = 1'b0;
    /*Action = Add*/
    // always @(posedge clk or posedge rst) begin
    //     if (rst) begin
    //         lookup_rden   <= `TD 0; 
    //         lookup_wren   <= `TD 0; 
    //         lookup_wdata  <= `TD 0;  
    //         lookup_index  <= `TD 0;  
    //         lookup_tag    <= `TD 0;
    //     end
    //     else begin
    //     /*VCS Verification*/
    //         // MPT_RSP_PROC & MPT_LOOKUP state both will look up mpt_ram
    //         case (mpt_fsm_cs)
    //             // next cycle is MPT_LOOKUP state and selected req channel is from rdma engine or ceu invalid mpt entry
    //             MPT_IDLE: begin
    //                 if (selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid && lookup_allow_in  && (!selected_channel[0] | (selected_channel[0] && (selected_req_data[127:120] == {`WR_MPT_TPT,`WR_MPT_INVALID})))) begin
    //                     lookup_rden  <= `TD !selected_channel[0]; //it's a read req if it's not cue req
    //                     //it's a write req if it's a mpt invalid req. 
    //                     //note: write mpt req will be processed in the 2nd clk in MPT_LOOKUP state
    //                     lookup_wren  <= `TD selected_channel[0] && (selected_req_data[127:120] == {`WR_MPT_TPT,`WR_MPT_INVALID});
    //                     lookup_wdata <= `TD 0;
    //                     lookup_index <= `TD lookup_addr[INDEX-1:0];
    //                     lookup_tag   <= `TD lookup_addr[INDEX+TAG-1 : INDEX];
    //                 end
    //                 else begin
    //                     lookup_rden   <= `TD 0; 
    //                     lookup_wren   <= `TD 0; 
    //                     lookup_wdata  <= `TD 0;  
    //                     lookup_index  <= `TD 0;  
    //                     lookup_tag    <= `TD 0;                        
    //                 end
    //             end 
    //             MPT_RSP_PROC: begin
    //                 // next cycle is MPT_LOOKUP state and selected req channel is from rdma engine or ceu invalid mpt entry
    //                 if ((qv_mpt_rsp_data_cnt==2) && lookup_allow_in  && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full &&  selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid && (!selected_channel[0] | (selected_channel[0] && (selected_req_data[127:120] == {`WR_MPT_TPT,`WR_MPT_INVALID})))) begin
    //                     lookup_rden  <= `TD !selected_channel[0];
    //                     lookup_wren  <= `TD selected_channel[0] && (selected_req_data[127:120] == {`WR_MPT_TPT,`WR_MPT_INVALID});
    //                     lookup_wdata <= `TD 0;
    //                     lookup_index <= `TD lookup_addr[INDEX-1:0];
    //                     lookup_tag   <= `TD lookup_addr[INDEX+TAG-1 : INDEX];
    //                 end
    //                 // write lookup req to mpt_ram module at the same cycle when we get the last response mpt data from dma engine
    //                 else if ((qv_mpt_rsp_data_cnt == 1) && lookup_allow_in  && dma_v2p_mpt_rd_rsp_tready && dma_v2p_mpt_rd_rsp_tvalid && dma_v2p_mpt_rd_rsp_tlast) begin
    //                     lookup_rden  <= `TD 0;
    //                     lookup_wren  <= `TD 1;
    //                     /*VCS Verification*/
    //                     // lookup_wdata <= `TD {dma_v2p_mpt_rd_rsp_tdata,qv_get_dma_rsp_mpt_data[255:0]};
    //                     lookup_wdata <= `TD {qv_get_dma_rsp_mpt_data[511:256],dma_v2p_mpt_rd_rsp_tdata};
    //                     /*Action = Modify, correct the bytes sequences*/
    //                     lookup_index <= `TD lookup_addr[INDEX-1:0];
    //                     lookup_tag   <= `TD lookup_addr[INDEX+TAG-1 : INDEX];
    //                 end
    //                 else begin
    //                     lookup_rden   <= `TD 0; 
    //                     lookup_wren   <= `TD 0; 
    //                     lookup_wdata  <= `TD 0;  
    //                     lookup_index  <= `TD 0;  
    //                     lookup_tag    <= `TD 0; 
    //                 end
    //             end
    //             MPT_LOOKUP: begin
    //                 // write lookup write req to mpt_ram module at the same next cycle we get the last  mpt data from ceu
    //                 if ((qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_WRITE}) && (qv_mpt_req_data_cnt == 1) && lookup_allow_in  && !mpt_data_empty) begin
    //                     lookup_rden  <= `TD 0;
    //                     lookup_wren  <= `TD 1;
    //                     /*VCS Verification*/
    //                     // lookup_wdata <= `TD {mpt_data_dout,qv_wr_mpt_data[255:0]};//joint the last 256b and the 1st 256b
    //                     lookup_wdata <= `TD {qv_wr_mpt_data[511:256],mpt_data_dout};//joint the last 256b and the 1st 256b
    //                     /*Action = Modify, correct the bytes sequences*/
    //                     lookup_index <= `TD lookup_addr[INDEX-1:0];
    //                     lookup_tag   <= `TD lookup_addr[INDEX+TAG-1 : INDEX];
    //                 end 
    //                 // next cycle is MPT_LOOKUP state and selected req channel is from rdma engine or ceu invalid mpt entry
    //                 else if ((((qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_WRITE}) && (qv_mpt_req_data_cnt == 2)) | ((qv_req_info[255:128] != 128'b0) && !rd_mpt_req_prog_full)) && lookup_allow_in  && selected_channel[8] && !dma_v2p_mpt_rd_rsp_tvalid)   begin
    //                     lookup_rden  <= `TD !selected_channel[0];
    //                     lookup_wren  <= `TD selected_channel[0] && (selected_req_data[127:120] == {`WR_MPT_TPT,`WR_MPT_INVALID});
    //                     lookup_wdata <= `TD 0;
    //                     lookup_index <= `TD lookup_addr[INDEX-1:0];
    //                     lookup_tag   <= `TD lookup_addr[INDEX+TAG-1 : INDEX];
    //                 end
    //                 else begin
    //                     lookup_rden   <= `TD 0; 
    //                     lookup_wren   <= `TD 0; 
    //                     lookup_wdata  <= `TD 0;  
    //                     lookup_index  <= `TD 0;  
    //                     lookup_tag    <= `TD 0; 
    //                 end
    //             end
    //             default: begin
    //                     lookup_rden   <= `TD 0; 
    //                     lookup_wren   <= `TD 0; 
    //                     lookup_wdata  <= `TD 0;  
    //                     lookup_index  <= `TD 0;  
    //                     lookup_tag    <= `TD 0; 
    //                 end
    //         endcase
        
    //     end
    //     /*Action = Modify, add !(lookup_rden | lookup_wren) condition to get lookup_allow_in signal to avoid lookup when !lookup_allow_in*/
    // end
    always @(*) begin
        if (rst) begin
            lookup_rden   =  0; 
            lookup_wren   =  0; 
            lookup_wdata  =  0;  
            lookup_index  =  0;  
            lookup_tag    =  0;
        end
        else begin
        /*VCS Verification*/
            // MPT_RSP_PROC & MPT_LOOKUP state both will look up mpt_ram
            case (mpt_fsm_cs)
                // next cycle is MPT_LOOKUP state and selected req channel is from rdma engine or ceu invalid mpt entry
                MPT_IDLE: begin
                    lookup_rden  = 0; 
                    lookup_wren  = 0; 
                    lookup_wdata = 0;  
                    lookup_index = 0;  
                    lookup_tag   = 0;                        
                end 
                MPT_RSP_PROC: begin
                    // write lookup req to mpt_ram module at the same cycle when we get the last response mpt data from dma engine
                    if ((qv_mpt_rsp_data_cnt==2) && lookup_allow_in && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full) begin
                        lookup_rden  =  0;
                        lookup_wren  =  1;
                        /*VCS Verification*/
                        // lookup_wdata =  {qv_get_dma_rsp_mpt_data[511:256],dma_v2p_mpt_rd_rsp_tdata};
                        lookup_wdata =  qv_get_dma_rsp_mpt_data;
                        /*Action = Modify, correct the bytes sequences*/
                        lookup_index =  lookup_addr[INDEX-1:0];
                        lookup_tag   =  lookup_addr[INDEX+TAG-1 : INDEX];
                    end
                    else begin
                        lookup_rden   =  0; 
                        lookup_wren   =  0; 
                        lookup_wdata  =  0;  
                        lookup_index  =  0;  
                        lookup_tag    =  0; 
                    end
                end
                MPT_LOOKUP: begin
                    // write lookup write req to mpt_ram module: ceu write or invalid mpt entry
                    if ((((qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_WRITE}) && (qv_mpt_req_data_cnt == 2)) | (qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_INVALID})) && selected_channel[0] && lookup_allow_in) begin
                        lookup_rden  =  0;
                        lookup_wren  =  1;
                        /*VCS Verification*/
                        // lookup_wdata = {qv_wr_mpt_data[511:256],mpt_data_dout};
                        lookup_wdata = (qv_req_info[255:120] == {128'b0,`WR_MPT_TPT,`WR_MPT_WRITE}) ? qv_wr_mpt_data : 0;
                        /*Action = Modify, correct the bytes sequences*/
                        lookup_index = lookup_addr[INDEX-1:0];
                        lookup_tag   = lookup_addr[INDEX+TAG-1 : INDEX];
                    end 
                    // selected req channel from rdma engine read mpt entry
                    else if ((qv_req_info[255:128] != 128'b0) && !rd_mpt_req_prog_full && lookup_allow_in)  begin
                        lookup_rden  =  (!selected_channel[0]) & (|selected_channel[7:1]);
                        lookup_wren  =  0;
                        lookup_wdata =  0;
                        lookup_index =  lookup_addr[INDEX-1:0];
                        lookup_tag   =  lookup_addr[INDEX+TAG-1 : INDEX];
                    end
                    else begin
                        lookup_rden   = 0; 
                        lookup_wren   = 0; 
                        lookup_wdata  = 0;  
                        lookup_index  = 0;  
                        lookup_tag    = 0; 
                    end
                end
                default: begin
                        lookup_rden   = 0; 
                        lookup_wren   = 0; 
                        lookup_wdata  = 0;  
                        lookup_index  = 0;  
                        lookup_tag    = 0; 
                    end
            endcase
        
        end
        /*Action = Modify, add !(lookup_rden | lookup_wren) condition to get lookup_allow_in signal to avoid lookup when !lookup_allow_in*/
    end
    
    //TODO:
    // add EQ function
    assign mpt_eq_addr = (mpt_fsm_cs == MPT_LOOKUP) && !rd_mpt_req_prog_full && lookup_allow_in && (!selected_channel[0]) && (|selected_channel[7:1]) && (qv_req_info[7:0] == {`WR_EQE_DATA,`WR_REQ_DATA});
    // rd_mpt_req_fifo--------------store the read request info 
        //| 207:200 | 199:168 | 167:136 | 135:104 | 103:72  |  71:40  |  39:8  | 7:4 | 3:0  |
        //| channel | length  | VA-high | VA-low  |   Key   |   PD    |  Flags |  Op | Tpye |
        //reg                        rd_mpt_req_wr_en;
        //wire                       rd_mpt_req_prog_full;
        //reg   [207:0]              rd_mpt_req_din;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rd_mpt_req_wr_en <= `TD 0;
            rd_mpt_req_din   <= `TD 0;
        end
        else begin
        /*VCS Verification*/
           case (mpt_fsm_cs)
                MPT_IDLE: begin
                    rd_mpt_req_wr_en <= `TD 0;
                    rd_mpt_req_din   <= `TD 0;
                end
                MPT_RSP_PROC: begin
                    rd_mpt_req_wr_en <= `TD 0;
                    rd_mpt_req_din   <= `TD 0;
                end
                MPT_LOOKUP: begin
                    // next cycle is MPT_LOOKUP state and selected req channel is from rdma engine
                    if ((qv_req_info[255:128] != 128'b0) && !rd_mpt_req_prog_full && lookup_allow_in && lookup_rden && (!selected_channel[0]) && (|selected_channel[7:1]))  begin
                        rd_mpt_req_wr_en <= `TD 1;
                        // rd_mpt_req_din   <= `TD {selected_channel[7:0],qv_req_info[32*7-1:32],qv_req_info[7:0]};
                        rd_mpt_req_din   <= `TD {qv_selected_channel[7:0],qv_req_info[32*7-1:32],qv_req_info[7:0]};
                    end else begin
                        rd_mpt_req_wr_en <= `TD 0;
                        rd_mpt_req_din   <= `TD 0;
                    end
                end        
                default: begin
                    rd_mpt_req_wr_en <= `TD 0;
                    rd_mpt_req_din   <= `TD 0;
                end
           endcase 
        end
        /*Action = Modify, add !(lookup_rden | lookup_wren) condition to get lookup_allow_in signal to avoid lookup when !lookup_allow_in*/

    end
//-----------------{dma mpt response and mpt_ram lookup state mechine} end--------------------//


//-----------------{mpt_ram lookup state processing mechine} begin--------------------//
    
    //--------------{variable declaration}---------------//
    // read mpt_ram state out fifo 
    localparam  RD_STATE       = 3'b001;
    // mpt read miss: updateqv_pend_channel_cnt reg; store miss info to pendingfifo
    localparam  MPT_MISS_PROC  = 3'b010;
    // mpt read hit: read mpt data; read rd_mpt_req_fifo; info match; 
    //               rep state info to rep channel state fifo; if match SUCCESS, initiate mtt_ram_ctl req
    localparam  MPT_HIT_PROC   = 3'b100;
    
    reg [2:0] state_fsm_cs;
    reg [2:0] state_fsm_ns;
    
    reg  [207:0]  qv_get_rd_mpt_req;//reg for request has been lookup
    reg  [4:0]    qv_lookup_state;//store the lookup state from mpt_ram
    reg  [511:0]  qv_hit_data;    //store the hit mpt data
    //read mpt hit req info match for response state and mtt req
    wire       hit_match_success;
    wire       hit_match_pd_err;
    wire       hit_match_flags_err;
    wire       hit_match_key_err;
    wire       hit_match_len_err;

    wire [4:0] hit_match_state;
    reg [1:0] mpt_req_mtt_op; // prepare for Op seg

    //-----------------Stage 1 :State Register----------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state_fsm_cs <= `TD RD_STATE;
        end
        else begin
            state_fsm_cs <= `TD state_fsm_ns;
        end
    end
    //-----------------Stage 2 :State Transition----------
    always @(*) begin
        case (state_fsm_cs)
            RD_STATE: begin
                //state_dout {lookup_state[2:0],lookup_ldst,state_valid}
                    //lookup_state: | 3<->miss | 2<->hit | 0<->idle |
                    //lookup_ldst : 1 for store, and 0 for load
                    //state_valid : valid in normal state, invalid 
                // read miss goto MPT_MISS_PROC
                if (!mpt_rsp_stall && (state_dout == 5'b10001) && !state_empty && !rd_mpt_req_empty && !pend_req_prog_full) begin
                // if (!mpt_rsp_stall && (state_dout == 5'b10001) && !pend_req_prog_full) begin
                    state_fsm_ns = MPT_MISS_PROC;
                end
                //read hit goto MPT_HIT_PROC               
                else if (!mpt_rsp_stall && (state_dout == 5'b01001) && !state_empty && !rd_mpt_req_empty && !hit_data_empty && !mpt_req_mtt_prog_full) begin
                // else if (!mpt_rsp_stall && (state_dout == 5'b01001) && !mpt_req_mtt_prog_full) begin
                    state_fsm_ns = MPT_HIT_PROC;
                end else begin
                    state_fsm_ns = RD_STATE;
                end
            end 
            MPT_MISS_PROC: begin
                // no mpt rsponse back & pend and rsp state fifo not full, then goto RD_STATE
                if (!mpt_rsp_stall && !pend_req_prog_full && !selected_rsp_state_prog_full) begin
                    state_fsm_ns = RD_STATE;
                end                
                else begin
                    state_fsm_ns = MPT_MISS_PROC;
                end
            end
            MPT_HIT_PROC: begin
                // if (!mpt_rsp_stall && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full) begin
                if (!mpt_rsp_stall && !selected_rsp_state_prog_full && (
                    (!mpt_wr_req_mtt_prog_full && (mpt_req_mtt_op == `UP)) |
                    (!mpt_rd_req_mtt_prog_full && (qv_get_rd_mpt_req[3:0] == `RD_REQ_DATA)) | 
                    (!mpt_rd_wqe_req_mtt_prog_full && (qv_get_rd_mpt_req[3:0] == `RD_REQ_WQE)))) begin
                    state_fsm_ns = RD_STATE;
                end 
                else begin
                    state_fsm_ns = MPT_HIT_PROC;
                end
            end
            default: state_fsm_ns = RD_STATE;
        endcase
    end
     
    //----------------------Stage 3 :Output Decode------------------
    //resposne state fifo full signal
        //wire       selected_rsp_state_prog_full;
    assign selected_rsp_state_prog_full = (((mpt_fsm_cs == MPT_RSP_PROC) && (qv_get_pend_req[207:200] == 8'b00000001)) |
                (((state_fsm_cs == MPT_HIT_PROC)|(state_fsm_cs == MPT_MISS_PROC)) && (qv_get_rd_mpt_req[207:200] == 8'b00000001))) ? 0 :
            (((mpt_fsm_cs == MPT_RSP_PROC) && (qv_get_pend_req[207:200] == 8'b00000010)) | 
                (((state_fsm_cs == MPT_HIT_PROC)|(state_fsm_cs == MPT_MISS_PROC)) && (qv_get_rd_mpt_req[207:200] == 8'b00000010))) ? i_db_vtp_resp_prog_full :
            (((mpt_fsm_cs == MPT_RSP_PROC) && (qv_get_pend_req[207:200] == 8'b00000100)) | 
               (((state_fsm_cs == MPT_HIT_PROC)|(state_fsm_cs == MPT_MISS_PROC)) && (qv_get_rd_mpt_req[207:200] == 8'b00000100))) ? i_wp_vtp_wqe_resp_prog_full :
            (((mpt_fsm_cs == MPT_RSP_PROC) && (qv_get_pend_req[207:200] == 8'b00001000)) | 
               (((state_fsm_cs == MPT_HIT_PROC)|(state_fsm_cs == MPT_MISS_PROC)) && (qv_get_rd_mpt_req[207:200] == 8'b00001000))) ? i_wp_vtp_nd_resp_prog_full :
            (((mpt_fsm_cs == MPT_RSP_PROC) && (qv_get_pend_req[207:200] == 8'b00010000)) | 
               (((state_fsm_cs == MPT_HIT_PROC)|(state_fsm_cs == MPT_MISS_PROC)) && (qv_get_rd_mpt_req[207:200] == 8'b00010000))) ? i_rtc_vtp_resp_prog_full :
            (((mpt_fsm_cs == MPT_RSP_PROC) && (qv_get_pend_req[207:200] == 8'b00100000)) | 
               (((state_fsm_cs == MPT_HIT_PROC)|(state_fsm_cs == MPT_MISS_PROC)) && (qv_get_rd_mpt_req[207:200] == 8'b00100000))) ? i_rrc_vtp_resp_prog_full :
            (((mpt_fsm_cs == MPT_RSP_PROC) && (qv_get_pend_req[207:200] == 8'b01000000)) | 
               (((state_fsm_cs == MPT_HIT_PROC)|(state_fsm_cs == MPT_MISS_PROC)) && (qv_get_rd_mpt_req[207:200] == 8'b01000000))) ?  i_rwm_vtp_resp_prog_full :
            (((mpt_fsm_cs == MPT_RSP_PROC) && (qv_get_pend_req[207:200] == 8'b10000000)) | 
               (((state_fsm_cs == MPT_HIT_PROC)|(state_fsm_cs == MPT_MISS_PROC)) && (qv_get_rd_mpt_req[207:200] == 8'b10000000))) ? i_ee_vtp_resp_prog_full  : 0;

    //interface to mpt_ram info out
        //lookup info state fifo
            //output reg                           state_rd_en, 
        //hit mpt entry in fifo, for mpt info match and mtt lookup
            //output reg                      hit_data_rd_en,
    // internal rd_mpt_req_fifo-------------- read request info 
        //| 207:200 | 199:168 | 167:136 | 135:104 | 103:72  |  71:40  |  39:8  | 7:4 | 3:0  |
        //| channel | length  | VA-high | VA-low  |   Key   |   PD    |  Flags |  Op | Tpye |
        //reg                        rd_mpt_req_rd_en;
    always @(*) begin
        if (rst) begin
            state_rd_en = 0;
            hit_data_rd_en = 0;
            rd_mpt_req_rd_en = 0;
        end
        else begin
            case (state_fsm_cs)
                /*VCS  Verification*/
                RD_STATE: begin
                    if ((state_fsm_ns == MPT_MISS_PROC) & !state_empty) begin
                        state_rd_en = 1;
                        hit_data_rd_en = 0;
                        rd_mpt_req_rd_en = 1;
                    end
                    else if ((state_fsm_ns == MPT_HIT_PROC) & !state_empty) begin
                        state_rd_en = 1;
                        hit_data_rd_en = 1;
                        rd_mpt_req_rd_en = 1;  
                    end
                    /*VCS  Verification*/
                    else if ((state_dout[1] != 0) & (state_dout[0] == 1) & !state_empty) begin
                        state_rd_en = 1;
                        hit_data_rd_en = 0;
                        rd_mpt_req_rd_en = 0;  
                    /*Action = Modify, continue to read state out fifo if state valid & not load op*/   
                /*Action = Add, add state_empty signal as a condition*/   
                    end else begin
                        state_rd_en = 0;
                        hit_data_rd_en = 0;
                        rd_mpt_req_rd_en = 0;                        
                    end
                end
                MPT_MISS_PROC: begin
                    state_rd_en = 0;
                    hit_data_rd_en = 0;
                    rd_mpt_req_rd_en = 0;                    
                end
                MPT_HIT_PROC: begin
                    state_rd_en = 0;
                    hit_data_rd_en = 0;
                    rd_mpt_req_rd_en = 0;                
                end
                default: begin
                    state_rd_en = 0;
                    hit_data_rd_en = 0;
                    rd_mpt_req_rd_en = 0;                    
                end
            endcase
        end
    end

    //reg  [4:0]    qv_lookup_state;   //store the lookup state from mpt_ram
    //reg  [207:0]  qv_get_rd_mpt_req; //reg for request has been lookup
    //reg  [511:0]  qv_hit_data;       //store the hit mpt data
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_lookup_state <= `TD 0;
            qv_get_rd_mpt_req <= `TD 0;
            qv_hit_data <= `TD 0;
        end
        else begin
            case (state_fsm_cs)
                RD_STATE: begin
                    if (state_fsm_ns == MPT_MISS_PROC) begin
                        qv_lookup_state <= `TD state_dout;
                        qv_get_rd_mpt_req <= `TD rd_mpt_req_dout;
                        qv_hit_data <= `TD 0;
                    end
                    else if (state_fsm_ns == MPT_HIT_PROC) begin
                        qv_lookup_state <= `TD state_dout;
                        qv_get_rd_mpt_req <= `TD rd_mpt_req_dout;
                        qv_hit_data <= `TD hit_data_dout;                        
                    end else begin
                        qv_lookup_state <= `TD 0;
                        qv_get_rd_mpt_req <= `TD 0;
                        qv_hit_data <= `TD 0;                        
                    end
                end
                MPT_MISS_PROC: begin
                    qv_lookup_state <= `TD qv_lookup_state;
                    qv_get_rd_mpt_req <= `TD qv_get_rd_mpt_req;
                    qv_hit_data <= `TD qv_hit_data;
                end
                MPT_HIT_PROC: begin
                    qv_lookup_state <= `TD qv_lookup_state;
                    qv_get_rd_mpt_req <= `TD qv_get_rd_mpt_req;
                    qv_hit_data <= `TD qv_hit_data;
                end
                default: begin
                    qv_lookup_state <= `TD 0;
                    qv_get_rd_mpt_req <= `TD 0;
                    qv_hit_data <= `TD 0;
                end 
            endcase
        end
    end       

    //pendingfifo--------------write the read miss request info 
        //| 207:200 | 199:168 | 167:136 | 135:104 | 103:72  |  71:40  |  39:8  | 7:4 | 3:0  |
        //| channel | length  | VA-high | VA-low  |   Key   |   PD    |  Flags |  Op | Tpye |
        //reg                        pend_req_wr_en;
        //reg   [207:0]              pend_req_din;    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pend_req_wr_en <= `TD 0;
            pend_req_din <= `TD 0;
        end 
        else if ((state_fsm_cs == MPT_MISS_PROC) && !pend_req_prog_full && !mpt_rsp_stall && !selected_rsp_state_prog_full) begin
            pend_req_wr_en <= `TD 1;
            pend_req_din <= `TD qv_get_rd_mpt_req;
        end
        else begin
            pend_req_wr_en <= `TD 0;
            pend_req_din <= `TD 0;
        end
    end

    //read mpt req && lookup state info, match for response state and mtt req
        //wire       hit_match_success;
        //wire       hit_match_pd_err;
        //wire       hit_match_flags_err;
        //wire       hit_match_key_err;
        //wire       hit_match_len_err;
    // assign hit_match_success = !hit_match_pd_err && !hit_match_flags_err && !hit_match_key_err && !hit_match_len_err;
    //TODO:
    assign hit_match_success = (!hit_match_pd_err && !hit_match_flags_err && !hit_match_key_err && !hit_match_len_err) || (qv_get_rd_mpt_req[7:0] == {`WR_EQE_DATA,`WR_REQ_DATA});
    /*VCS Verification*/
    // assign hit_match_pd_err = (qv_get_rd_mpt_req[32*2+8-1:32*1+8] == qv_hit_data[32*4 -1: 32*3]) ? 0 :1;
    // //mpt flags includes all flags in req, except the absolute/relative addr flags in req flags
    // //the 2 addr type flags can not be equal
    // assign hit_match_flags_err = (((qv_get_rd_mpt_req[31+8:8] | {qv_hit_data[31:28],2'b11,qv_hit_data[25:0]}) == {qv_hit_data[31:28],2'b11,qv_hit_data[25:0]}) && (qv_get_rd_mpt_req[26+8] != qv_get_rd_mpt_req[27+8])) ? 0 :1;
    // assign hit_match_key_err = (qv_get_rd_mpt_req[32*3+8-1:32*2+8] == qv_hit_data[32*3 -1: 32*2]) ? 0 :1;
    // //check if the req mpt addr exceed the border
    //     // relative addr: req_length + req_v_addr <= mpt_length                   --------No Err
    //     // absolute addr: req_length + req_v_addr <= mpt_length + mpt_start_addr  --------No Err
    // assign hit_match_len_err = ((qv_get_rd_mpt_req[26+8] && (qv_get_rd_mpt_req[32*5+8-1:32*3+8] + qv_get_rd_mpt_req[32*6+8-1:32*5+8] <= qv_hit_data[32*8 -1: 32*6])) |
    //                             (qv_get_rd_mpt_req[27+8] && (qv_get_rd_mpt_req[32*5+8-1:32*3+8] + qv_get_rd_mpt_req[32*6+8-1:32*5+8] <= qv_hit_data[32*6 -1: 32*4] + qv_hit_data[32*8 -1: 32*6]))) ? 0 :1;
    
    assign hit_match_pd_err = (qv_get_rd_mpt_req[32*2+8-1:32*1+8] == qv_hit_data[32*(5+8)-1: 32*(4+8)]) ? 0 :1;
    //mpt flags includes all flags in req, except the absolute/relative addr flags in req flags
    //the 2 addr type flags can not be equal
    assign hit_match_flags_err = (((qv_get_rd_mpt_req[31+8:8] | {qv_hit_data[32*(8+8)-1:32*(8+8)-4],2'b11,qv_hit_data[32*(7+8)+25:32*(7+8)]}) == {qv_hit_data[32*(8+8)-1:32*(8+8)-4],2'b11,qv_hit_data[32*(7+8)+25:32*(7+8)]}) && (qv_get_rd_mpt_req[26+8] != qv_get_rd_mpt_req[27+8])) ? 0 :1;
    assign hit_match_key_err = (qv_get_rd_mpt_req[32*3+8-1:32*2+8] == qv_hit_data[32*(6+8) -1: 32*(5+8)]) ? 0 :1;
    //check if the req mpt addr exceed the border
        // relative addr: req_length + req_v_addr <= mpt_length                   --------No Err
        // absolute addr: req_length + req_v_addr <= mpt_length + mpt_start_addr  --------No Err
    assign hit_match_len_err = ((qv_get_rd_mpt_req[26+8] && (qv_get_rd_mpt_req[32*5+8-1:32*3+8] + qv_get_rd_mpt_req[32*6+8-1:32*5+8] <= qv_hit_data[32*(2+8)-1: 32*8])) |
                                (qv_get_rd_mpt_req[27+8] && (qv_get_rd_mpt_req[32*5+8-1:32*3+8] + qv_get_rd_mpt_req[32*6+8-1:32*5+8] <= qv_hit_data[32*(4+8)-1: 32*(2+8)] + qv_hit_data[32*(2+8)-1: 32*8]))) ? 0 :1;
    /*Action = Modify, correct the bytes sequences*/
    // assign hit_match_state = hit_match_success   ? `SUCCESS :
    //                          hit_match_pd_err    ? `PD_ERR  :
    //                          hit_match_flags_err ? `FLAGS_ERR :
    //                          hit_match_key_err   ? `KEY_ERR :
    //                          hit_match_len_err   ? `LENGTH_ERR : 0;
    // assign hit_match_state = {3'b0,hit_match_success, 
    //                                hit_match_len_err ,
    //                                hit_match_key_err ,
    //                                hit_match_flags_err,
    //                                hit_match_pd_err};   
    //TODO:  
    assign hit_match_state = hit_match_success ? 5'b10000 : {hit_match_success, 
                                   hit_match_len_err ,
                                   hit_match_key_err ,
                                   hit_match_flags_err,
                                   hit_match_pd_err}; 
//-----------------{mpt_ram lookup state processing mechine} end--------------------//


//-----------------{two state mechines both write signal} begin--------------------//
    //------------------{interface to request scheduler module} begin-----------
    //output reg   [PEND_CNT_WIDTH-1 :0] qv_pend_channel_cnt,
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_pend_channel_cnt <= `TD 0;
        end
        //MPT_RSP_PROC state:qv_pend_channel_cnt-1 at the same cycle we get the last response mpt data from dma engine
        else if ((mpt_fsm_cs == MPT_RSP_PROC) && (qv_mpt_rsp_data_cnt == 2) && lookup_allow_in && lookup_wren && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full) begin
            case (qv_get_pend_req[207:200])
                8'b00000001: begin
                    qv_pend_channel_cnt[1*4-1:0*4] <= `TD  qv_pend_channel_cnt[1*4-1:0*4] - 1;
                    qv_pend_channel_cnt[8*4-1:1*4] <= `TD  qv_pend_channel_cnt[8*4-1:1*4];
                end 
                8'b00000010: begin
                    qv_pend_channel_cnt[1*4-1:0*4] <= `TD  qv_pend_channel_cnt[1*4-1:0*4];
                    qv_pend_channel_cnt[2*4-1:1*4] <= `TD  qv_pend_channel_cnt[2*4-1:1*4] - 1;
                    qv_pend_channel_cnt[8*4-1:2*4] <= `TD  qv_pend_channel_cnt[8*4-1:2*4];
                end 
                8'b00000100: begin
                   qv_pend_channel_cnt[2*4-1:0*4] <= `TD qv_pend_channel_cnt[2*4-1:0*4];
                   qv_pend_channel_cnt[3*4-1:2*4] <= `TD qv_pend_channel_cnt[3*4-1:2*4] - 1;
                   qv_pend_channel_cnt[8*4-1:3*4] <= `TD qv_pend_channel_cnt[8*4-1:3*4];
                end
                8'b00001000: begin
                   qv_pend_channel_cnt[3*4-1:0*4] <= `TD qv_pend_channel_cnt[3*4-1:0*4];
                   qv_pend_channel_cnt[4*4-1:3*4] <= `TD qv_pend_channel_cnt[4*4-1:3*4] - 1;
                   qv_pend_channel_cnt[8*4-1:4*4] <= `TD qv_pend_channel_cnt[8*4-1:4*4];
                end 
                8'b00010000: begin
                   qv_pend_channel_cnt[4*4-1:0*4] <= `TD qv_pend_channel_cnt[4*4-1:0*4];
                   qv_pend_channel_cnt[5*4-1:4*4] <= `TD qv_pend_channel_cnt[5*4-1:4*4] - 1;
                   qv_pend_channel_cnt[8*4-1:5*4] <= `TD qv_pend_channel_cnt[8*4-1:5*4];
                end 
                8'b00100000: begin
                   qv_pend_channel_cnt[5*4-1:0*4] <= `TD qv_pend_channel_cnt[5*4-1:0*4];
                   qv_pend_channel_cnt[6*4-1:5*4] <= `TD qv_pend_channel_cnt[6*4-1:5*4] - 1;
                   qv_pend_channel_cnt[8*4-1:6*4] <= `TD qv_pend_channel_cnt[8*4-1:6*4];
                end 
                8'b01000000: begin
                   qv_pend_channel_cnt[6*4-1:0*4] <= `TD qv_pend_channel_cnt[6*4-1:0*4];
                   qv_pend_channel_cnt[7*4-1:6*4] <= `TD qv_pend_channel_cnt[7*4-1:6*4] - 1;
                   qv_pend_channel_cnt[8*4-1:7*4] <= `TD qv_pend_channel_cnt[8*4-1:7*4];
                end 
                8'b10000000: begin
                   qv_pend_channel_cnt[7*4-1:0*4] <= `TD qv_pend_channel_cnt[7*4-1:0*4];
                   qv_pend_channel_cnt[8*4-1:7*4] <= `TD qv_pend_channel_cnt[8*4-1:7*4] - 1;
                end
                default: begin      
                    qv_pend_channel_cnt <= `TD qv_pend_channel_cnt;          
                end
            endcase
        end
        // state proc state mechine: MPT_MISS_PROC 
        else if ((state_fsm_cs == MPT_MISS_PROC) && !pend_req_prog_full && !mpt_rsp_stall && !selected_rsp_state_prog_full) begin
            case (qv_get_rd_mpt_req[207:200])
                8'b00000001: begin
                   qv_pend_channel_cnt[1*4-1:0*4] <= `TD qv_pend_channel_cnt[1*4-1:0*4] + 1;
                   qv_pend_channel_cnt[8*4-1:1*4] <= `TD qv_pend_channel_cnt[8*4-1:1*4];
                end 
                8'b00000010: begin
                   qv_pend_channel_cnt[1*4-1:0*4] <= `TD qv_pend_channel_cnt[1*4-1:0*4];
                   qv_pend_channel_cnt[2*4-1:1*4] <= `TD qv_pend_channel_cnt[2*4-1:1*4] + 1;
                   qv_pend_channel_cnt[8*4-1:2*4] <= `TD qv_pend_channel_cnt[8*4-1:2*4];
                end 
                8'b00000100: begin
                   qv_pend_channel_cnt[2*4-1:0*4] <= `TD qv_pend_channel_cnt[2*4-1:0*4];
                   qv_pend_channel_cnt[3*4-1:2*4] <= `TD qv_pend_channel_cnt[3*4-1:2*4] + 1;
                   qv_pend_channel_cnt[8*4-1:3*4] <= `TD qv_pend_channel_cnt[8*4-1:3*4];
                end
                8'b00001000: begin
                   qv_pend_channel_cnt[3*4-1:0*4] <= `TD qv_pend_channel_cnt[3*4-1:0*4];
                   qv_pend_channel_cnt[4*4-1:3*4] <= `TD qv_pend_channel_cnt[4*4-1:3*4] + 1;
                   qv_pend_channel_cnt[8*4-1:4*4] <= `TD qv_pend_channel_cnt[8*4-1:4*4];
                end 
                8'b00010000: begin
                   qv_pend_channel_cnt[4*4-1:0*4] <= `TD qv_pend_channel_cnt[4*4-1:0*4];
                   qv_pend_channel_cnt[5*4-1:4*4] <= `TD qv_pend_channel_cnt[5*4-1:4*4] + 1;
                   qv_pend_channel_cnt[8*4-1:5*4] <= `TD qv_pend_channel_cnt[8*4-1:5*4];
                end 
                8'b00100000: begin
                   qv_pend_channel_cnt[5*4-1:0*4] <= `TD qv_pend_channel_cnt[5*4-1:0*4];
                   qv_pend_channel_cnt[6*4-1:5*4] <= `TD qv_pend_channel_cnt[6*4-1:5*4] + 1;
                   qv_pend_channel_cnt[8*4-1:6*4] <= `TD qv_pend_channel_cnt[8*4-1:6*4];
                end 
                8'b01000000: begin
                   qv_pend_channel_cnt[6*4-1:0*4] <= `TD qv_pend_channel_cnt[6*4-1:0*4];
                   qv_pend_channel_cnt[7*4-1:6*4] <= `TD qv_pend_channel_cnt[7*4-1:6*4] + 1;
                   qv_pend_channel_cnt[8*4-1:7*4] <= `TD qv_pend_channel_cnt[8*4-1:7*4];
                end 
                8'b10000000: begin
                   qv_pend_channel_cnt[7*4-1:0*4] <= `TD qv_pend_channel_cnt[7*4-1:0*4];
                   qv_pend_channel_cnt[8*4-1:7*4] <= `TD qv_pend_channel_cnt[8*4-1:7*4] + 1;
                end
                default: begin      
                    qv_pend_channel_cnt <= `TD qv_pend_channel_cnt;          
                end 
            endcase
        end
        else begin
            qv_pend_channel_cnt <= `TD qv_pend_channel_cnt;          
        end
    end
    //------------------{interface to request scheduler module} end-----------

    //-----------------------{data for rsp state info to rdma engine } begin-----------------
        //output  reg                 o_db_vtp_resp_wr_en
        //output  reg                 o_wp_vtp_wqe_resp_wr_en
        //output  reg                 o_wp_vtp_nd_resp_wr_en
        //output  reg                 o_rtc_vtp_resp_wr_en
        //output  reg                 o_rrc_vtp_resp_wr_en
        //output  reg                 o_ee_vtp_resp_wr_en
        //output  reg                 o_rwm_vtp_resp_wr_en
        reg     [4:0]       qv_db_vtp_resp_data;
        assign ov_db_vtp_resp_data = {3'b0,qv_db_vtp_resp_data};
        reg     [4:0]       qv_wp_vtp_wqe_resp_data;
        assign ov_wp_vtp_wqe_resp_data = {3'b0,qv_wp_vtp_wqe_resp_data};
        reg     [4:0]       qv_wp_vtp_nd_resp_data;
        assign ov_wp_vtp_nd_resp_data = {3'b0,qv_wp_vtp_nd_resp_data};
        reg     [4:0]       qv_rtc_vtp_resp_data;
        assign ov_rtc_vtp_resp_data = {3'b0,qv_rtc_vtp_resp_data};
        reg     [4:0]       qv_rrc_vtp_resp_data;
        assign ov_rrc_vtp_resp_data = {3'b0,qv_rrc_vtp_resp_data};
        reg     [4:0]       qv_ee_vtp_resp_data;
        assign ov_ee_vtp_resp_data = {3'b0,qv_ee_vtp_resp_data};
        reg     [4:0]       qv_rwm_vtp_resp_data  ;
        assign ov_rwm_vtp_resp_data = {3'b0,qv_rwm_vtp_resp_data};
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            o_db_vtp_resp_wr_en       <= `TD 0;
            o_wp_vtp_wqe_resp_wr_en   <= `TD 0;
            o_wp_vtp_nd_resp_wr_en    <= `TD 0;
            o_rtc_vtp_resp_wr_en      <= `TD 0;
            o_rrc_vtp_resp_wr_en      <= `TD 0;
            o_rwm_vtp_resp_wr_en      <= `TD 0;
            o_ee_vtp_resp_wr_en       <= `TD 0;

            qv_db_vtp_resp_data      <= `TD 0;
            qv_wp_vtp_wqe_resp_data  <= `TD 0;
            qv_wp_vtp_nd_resp_data   <= `TD 0;
            qv_rtc_vtp_resp_data     <= `TD 0;
            qv_rrc_vtp_resp_data     <= `TD 0;
            qv_rwm_vtp_resp_data     <= `TD 0;
            qv_ee_vtp_resp_data      <= `TD 0;
        end 
        //FSM1_MPT_RSP_PROC state: write rsp state info to rdma engine module at the next cycle after we get the last response mpt data from dma engine
        else if ((mpt_fsm_cs == MPT_RSP_PROC) && (qv_mpt_rsp_data_cnt == 2) && lookup_allow_in && lookup_wren && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full) begin
            case (qv_get_pend_req[207:200])
                8'b00000001: begin
                    o_db_vtp_resp_wr_en       <= `TD 0;
                    o_wp_vtp_wqe_resp_wr_en   <= `TD 0;
                    o_wp_vtp_nd_resp_wr_en    <= `TD 0;
                    o_rtc_vtp_resp_wr_en      <= `TD 0;
                    o_rrc_vtp_resp_wr_en      <= `TD 0;
                    o_rwm_vtp_resp_wr_en      <= `TD 0;
                    o_ee_vtp_resp_wr_en       <= `TD 0;

                    qv_db_vtp_resp_data      <= `TD 0;
                    qv_wp_vtp_wqe_resp_data  <= `TD 0;
                    qv_wp_vtp_nd_resp_data   <= `TD 0;
                    qv_rtc_vtp_resp_data     <= `TD 0;
                    qv_rrc_vtp_resp_data     <= `TD 0;
                    qv_rwm_vtp_resp_data     <= `TD 0;
                    qv_ee_vtp_resp_data      <= `TD 0;
                end 
                8'b00000010: begin
                    o_db_vtp_resp_wr_en      <= `TD 1;
                    o_wp_vtp_wqe_resp_wr_en   <= `TD 0;
                    o_wp_vtp_nd_resp_wr_en    <= `TD 0;
                    o_rtc_vtp_resp_wr_en      <= `TD 0;
                    o_rrc_vtp_resp_wr_en      <= `TD 0;
                    o_rwm_vtp_resp_wr_en      <= `TD 0;
                    o_ee_vtp_resp_wr_en       <= `TD 0;

                    qv_db_vtp_resp_data      <= `TD rsp_match_state;
                    qv_wp_vtp_wqe_resp_data  <= `TD 0;
                    qv_wp_vtp_nd_resp_data   <= `TD 0;
                    qv_rtc_vtp_resp_data     <= `TD 0;
                    qv_rrc_vtp_resp_data     <= `TD 0;
                    qv_rwm_vtp_resp_data     <= `TD 0;
                    qv_ee_vtp_resp_data      <= `TD 0;
                end 
                8'b00000100: begin
                    o_db_vtp_resp_wr_en       <= `TD 0;
                    o_wp_vtp_wqe_resp_wr_en  <= `TD 1;
                    o_wp_vtp_nd_resp_wr_en    <= `TD 0;
                    o_rtc_vtp_resp_wr_en      <= `TD 0;
                    o_rrc_vtp_resp_wr_en      <= `TD 0;
                    o_rwm_vtp_resp_wr_en      <= `TD 0;
                    o_ee_vtp_resp_wr_en       <= `TD 0;

                    qv_db_vtp_resp_data      <= `TD 0;
                    qv_wp_vtp_wqe_resp_data  <= `TD rsp_match_state;
                    qv_wp_vtp_nd_resp_data   <= `TD 0;
                    qv_rtc_vtp_resp_data     <= `TD 0;
                    qv_rrc_vtp_resp_data     <= `TD 0;
                    qv_rwm_vtp_resp_data     <= `TD 0;
                    qv_ee_vtp_resp_data      <= `TD 0;
                end 
                8'b00001000: begin
                    o_db_vtp_resp_wr_en       <= `TD 0;
                    o_wp_vtp_wqe_resp_wr_en   <= `TD 0;
                    o_wp_vtp_nd_resp_wr_en   <= `TD 1;
                    o_rtc_vtp_resp_wr_en      <= `TD 0;
                    o_rrc_vtp_resp_wr_en      <= `TD 0;
                    o_rwm_vtp_resp_wr_en      <= `TD 0;
                    o_ee_vtp_resp_wr_en       <= `TD 0;

                    qv_db_vtp_resp_data      <= `TD 0;
                    qv_wp_vtp_wqe_resp_data  <= `TD 0;
                    qv_wp_vtp_nd_resp_data   <= `TD rsp_match_state;
                    qv_rtc_vtp_resp_data     <= `TD 0;
                    qv_rrc_vtp_resp_data     <= `TD 0;
                    qv_rwm_vtp_resp_data     <= `TD 0;
                    qv_ee_vtp_resp_data      <= `TD 0;
                end 
                8'b00010000: begin
                    o_db_vtp_resp_wr_en       <= `TD 0;
                    o_wp_vtp_wqe_resp_wr_en   <= `TD 0;
                    o_wp_vtp_nd_resp_wr_en    <= `TD 0;
                    o_rtc_vtp_resp_wr_en     <= `TD 1;
                    o_rrc_vtp_resp_wr_en      <= `TD 0;
                    o_rwm_vtp_resp_wr_en      <= `TD 0;
                    o_ee_vtp_resp_wr_en       <= `TD 0;

                    qv_db_vtp_resp_data      <= `TD 0;
                    qv_wp_vtp_wqe_resp_data  <= `TD 0;
                    qv_wp_vtp_nd_resp_data   <= `TD 0;
                    qv_rtc_vtp_resp_data     <= `TD rsp_match_state;
                    qv_rrc_vtp_resp_data     <= `TD 0;
                    qv_rwm_vtp_resp_data     <= `TD 0;
                    qv_ee_vtp_resp_data      <= `TD 0;
                end 
                8'b00100000: begin
                    o_db_vtp_resp_wr_en       <= `TD 0;
                    o_wp_vtp_wqe_resp_wr_en   <= `TD 0;
                    o_wp_vtp_nd_resp_wr_en    <= `TD 0;
                    o_rtc_vtp_resp_wr_en      <= `TD 0;
                    o_rrc_vtp_resp_wr_en     <= `TD 1;
                    o_rwm_vtp_resp_wr_en      <= `TD 0;
                    o_ee_vtp_resp_wr_en       <= `TD 0;

                    qv_db_vtp_resp_data      <= `TD 0;
                    qv_wp_vtp_wqe_resp_data  <= `TD 0;
                    qv_wp_vtp_nd_resp_data   <= `TD 0;
                    qv_rtc_vtp_resp_data     <= `TD 0;
                    qv_rrc_vtp_resp_data     <= `TD rsp_match_state;
                    qv_rwm_vtp_resp_data     <= `TD 0;
                    qv_ee_vtp_resp_data      <= `TD 0;
                end 
                8'b01000000: begin
                    o_db_vtp_resp_wr_en       <= `TD 0;
                    o_wp_vtp_wqe_resp_wr_en   <= `TD 0;
                    o_wp_vtp_nd_resp_wr_en    <= `TD 0;
                    o_rtc_vtp_resp_wr_en      <= `TD 0;
                    o_rrc_vtp_resp_wr_en      <= `TD 0;
                    o_rwm_vtp_resp_wr_en     <= `TD 1;
                    o_ee_vtp_resp_wr_en       <= `TD 0;

                    qv_db_vtp_resp_data      <= `TD 0;
                    qv_wp_vtp_wqe_resp_data  <= `TD 0;
                    qv_wp_vtp_nd_resp_data   <= `TD 0;
                    qv_rtc_vtp_resp_data     <= `TD 0;
                    qv_rrc_vtp_resp_data     <= `TD 0;
                    qv_rwm_vtp_resp_data     <= `TD rsp_match_state;
                    qv_ee_vtp_resp_data      <= `TD 0;
                end 
                8'b10000000: begin
                    o_db_vtp_resp_wr_en       <= `TD 0;
                    o_wp_vtp_wqe_resp_wr_en   <= `TD 0;
                    o_wp_vtp_nd_resp_wr_en    <= `TD 0;
                    o_rtc_vtp_resp_wr_en      <= `TD 0;
                    o_rrc_vtp_resp_wr_en      <= `TD 0;
                    o_rwm_vtp_resp_wr_en      <= `TD 0;
                    o_ee_vtp_resp_wr_en      <= `TD 1;

                    qv_db_vtp_resp_data      <= `TD 0;
                    qv_wp_vtp_wqe_resp_data  <= `TD 0;
                    qv_wp_vtp_nd_resp_data   <= `TD 0;
                    qv_rtc_vtp_resp_data     <= `TD 0;
                    qv_rrc_vtp_resp_data     <= `TD 0;
                    qv_rwm_vtp_resp_data     <= `TD 0;
                    qv_ee_vtp_resp_data      <= `TD rsp_match_state;
                end  
                default: begin
                    o_db_vtp_resp_wr_en       <= `TD 0;
                    o_wp_vtp_wqe_resp_wr_en   <= `TD 0;
                    o_wp_vtp_nd_resp_wr_en    <= `TD 0;
                    o_rtc_vtp_resp_wr_en      <= `TD 0;
                    o_rrc_vtp_resp_wr_en      <= `TD 0;
                    o_rwm_vtp_resp_wr_en      <= `TD 0;
                    o_ee_vtp_resp_wr_en       <= `TD 0;

                    qv_db_vtp_resp_data      <= `TD 0;
                    qv_wp_vtp_wqe_resp_data  <= `TD 0;
                    qv_wp_vtp_nd_resp_data   <= `TD 0;
                    qv_rtc_vtp_resp_data     <= `TD 0;
                    qv_rrc_vtp_resp_data     <= `TD 0;
                    qv_rwm_vtp_resp_data     <= `TD 0;
                    qv_ee_vtp_resp_data      <= `TD 0;
                end
            endcase
        end
        //FSM2_MPT_HIT_PROC state: write rsp state info to rdma engine module at the last cycle of MPT_HIT_PROC 
        // else if ((state_fsm_cs == MPT_HIT_PROC) && !mpt_rsp_stall && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full) begin
        else if ((state_fsm_cs == MPT_HIT_PROC) && !mpt_rsp_stall && !selected_rsp_state_prog_full && 
                ((!mpt_wr_req_mtt_prog_full && (mpt_req_mtt_op == `UP)) |
                (!mpt_rd_req_mtt_prog_full && (qv_get_rd_mpt_req[3:0] == `RD_REQ_DATA)) | 
                (!mpt_rd_wqe_req_mtt_prog_full && (qv_get_rd_mpt_req[3:0] == `RD_REQ_WQE)))) begin
            case (qv_get_rd_mpt_req[207:200])
                8'b00000001: begin
                    o_db_vtp_resp_wr_en       <= `TD 0;
                    o_wp_vtp_wqe_resp_wr_en   <= `TD 0;
                    o_wp_vtp_nd_resp_wr_en    <= `TD 0;
                    o_rtc_vtp_resp_wr_en      <= `TD 0;
                    o_rrc_vtp_resp_wr_en      <= `TD 0;
                    o_rwm_vtp_resp_wr_en      <= `TD 0;
                    o_ee_vtp_resp_wr_en       <= `TD 0;

                    qv_db_vtp_resp_data      <= `TD 0;
                    qv_wp_vtp_wqe_resp_data  <= `TD 0;
                    qv_wp_vtp_nd_resp_data   <= `TD 0;
                    qv_rtc_vtp_resp_data     <= `TD 0;
                    qv_rrc_vtp_resp_data     <= `TD 0;
                    qv_rwm_vtp_resp_data     <= `TD 0;
                    qv_ee_vtp_resp_data      <= `TD 0;
                end 
                8'b00000010: begin
                    o_db_vtp_resp_wr_en      <= `TD 1;
                    o_wp_vtp_wqe_resp_wr_en   <= `TD 0;
                    o_wp_vtp_nd_resp_wr_en    <= `TD 0;
                    o_rtc_vtp_resp_wr_en      <= `TD 0;
                    o_rrc_vtp_resp_wr_en      <= `TD 0;
                    o_rwm_vtp_resp_wr_en      <= `TD 0;
                    o_ee_vtp_resp_wr_en       <= `TD 0;

                    qv_db_vtp_resp_data      <= `TD hit_match_state;
                    qv_wp_vtp_wqe_resp_data  <= `TD 0;
                    qv_wp_vtp_nd_resp_data   <= `TD 0;
                    qv_rtc_vtp_resp_data     <= `TD 0;
                    qv_rrc_vtp_resp_data     <= `TD 0;
                    qv_rwm_vtp_resp_data     <= `TD 0;
                    qv_ee_vtp_resp_data      <= `TD 0;
                end 
                8'b00000100: begin
                    o_db_vtp_resp_wr_en       <= `TD 0;
                    o_wp_vtp_wqe_resp_wr_en  <= `TD 1;
                    o_wp_vtp_nd_resp_wr_en    <= `TD 0;
                    o_rtc_vtp_resp_wr_en      <= `TD 0;
                    o_rrc_vtp_resp_wr_en      <= `TD 0;
                    o_rwm_vtp_resp_wr_en      <= `TD 0;
                    o_ee_vtp_resp_wr_en       <= `TD 0;

                    qv_db_vtp_resp_data      <= `TD 0;
                    qv_wp_vtp_wqe_resp_data  <= `TD hit_match_state;
                    qv_wp_vtp_nd_resp_data   <= `TD 0;
                    qv_rtc_vtp_resp_data     <= `TD 0;
                    qv_rrc_vtp_resp_data     <= `TD 0;
                    qv_rwm_vtp_resp_data     <= `TD 0;
                    qv_ee_vtp_resp_data      <= `TD 0;
                end 
                8'b00001000: begin
                    o_db_vtp_resp_wr_en       <= `TD 0;
                    o_wp_vtp_wqe_resp_wr_en   <= `TD 0;
                    o_wp_vtp_nd_resp_wr_en   <= `TD 1;
                    o_rtc_vtp_resp_wr_en      <= `TD 0;
                    o_rrc_vtp_resp_wr_en      <= `TD 0;
                    o_rwm_vtp_resp_wr_en      <= `TD 0;
                    o_ee_vtp_resp_wr_en       <= `TD 0;

                    qv_db_vtp_resp_data      <= `TD 0;
                    qv_wp_vtp_wqe_resp_data  <= `TD 0;
                    qv_wp_vtp_nd_resp_data   <= `TD hit_match_state;
                    qv_rtc_vtp_resp_data     <= `TD 0;
                    qv_rrc_vtp_resp_data     <= `TD 0;
                    qv_rwm_vtp_resp_data     <= `TD 0;
                    qv_ee_vtp_resp_data      <= `TD 0;
                end 
                8'b00010000: begin
                    o_db_vtp_resp_wr_en       <= `TD 0;
                    o_wp_vtp_wqe_resp_wr_en   <= `TD 0;
                    o_wp_vtp_nd_resp_wr_en    <= `TD 0;
                    o_rtc_vtp_resp_wr_en     <= `TD 1;
                    o_rrc_vtp_resp_wr_en      <= `TD 0;
                    o_rwm_vtp_resp_wr_en      <= `TD 0;
                    o_ee_vtp_resp_wr_en       <= `TD 0;

                    qv_db_vtp_resp_data      <= `TD 0;
                    qv_wp_vtp_wqe_resp_data  <= `TD 0;
                    qv_wp_vtp_nd_resp_data   <= `TD 0;
                    qv_rtc_vtp_resp_data     <= `TD hit_match_state;
                    qv_rrc_vtp_resp_data     <= `TD 0;
                    qv_rwm_vtp_resp_data     <= `TD 0;
                    qv_ee_vtp_resp_data      <= `TD 0;
                end 
                8'b00100000: begin
                    o_db_vtp_resp_wr_en       <= `TD 0;
                    o_wp_vtp_wqe_resp_wr_en   <= `TD 0;
                    o_wp_vtp_nd_resp_wr_en    <= `TD 0;
                    o_rtc_vtp_resp_wr_en      <= `TD 0;
                    o_rrc_vtp_resp_wr_en     <= `TD 1;
                    o_rwm_vtp_resp_wr_en      <= `TD 0;
                    o_ee_vtp_resp_wr_en       <= `TD 0;

                    qv_db_vtp_resp_data      <= `TD 0;
                    qv_wp_vtp_wqe_resp_data  <= `TD 0;
                    qv_wp_vtp_nd_resp_data   <= `TD 0;
                    qv_rtc_vtp_resp_data     <= `TD 0;
                    qv_rrc_vtp_resp_data     <= `TD hit_match_state;
                    qv_rwm_vtp_resp_data     <= `TD 0;
                    qv_ee_vtp_resp_data      <= `TD 0;
                end 
                8'b01000000: begin
                    o_db_vtp_resp_wr_en       <= `TD 0;
                    o_wp_vtp_wqe_resp_wr_en   <= `TD 0;
                    o_wp_vtp_nd_resp_wr_en    <= `TD 0;
                    o_rtc_vtp_resp_wr_en      <= `TD 0;
                    o_rrc_vtp_resp_wr_en      <= `TD 0;
                    o_rwm_vtp_resp_wr_en     <= `TD 1;
                    o_ee_vtp_resp_wr_en       <= `TD 0;

                    qv_db_vtp_resp_data      <= `TD 0;
                    qv_wp_vtp_wqe_resp_data  <= `TD 0;
                    qv_wp_vtp_nd_resp_data   <= `TD 0;
                    qv_rtc_vtp_resp_data     <= `TD 0;
                    qv_rrc_vtp_resp_data     <= `TD 0;
                    qv_rwm_vtp_resp_data     <= `TD hit_match_state;
                    qv_ee_vtp_resp_data      <= `TD 0;
                end 
                8'b10000000: begin
                    o_db_vtp_resp_wr_en       <= `TD 0;
                    o_wp_vtp_wqe_resp_wr_en   <= `TD 0;
                    o_wp_vtp_nd_resp_wr_en    <= `TD 0;
                    o_rtc_vtp_resp_wr_en      <= `TD 0;
                    o_rrc_vtp_resp_wr_en      <= `TD 0;
                    o_rwm_vtp_resp_wr_en      <= `TD 0;
                    o_ee_vtp_resp_wr_en      <= `TD 1;

                    qv_db_vtp_resp_data      <= `TD 0;
                    qv_wp_vtp_wqe_resp_data  <= `TD 0;
                    qv_wp_vtp_nd_resp_data   <= `TD 0;
                    qv_rtc_vtp_resp_data     <= `TD 0;
                    qv_rrc_vtp_resp_data     <= `TD 0;
                    qv_rwm_vtp_resp_data     <= `TD 0;
                    qv_ee_vtp_resp_data      <= `TD hit_match_state;
                end  
                default: begin
                    o_db_vtp_resp_wr_en       <= `TD 0;
                    o_wp_vtp_wqe_resp_wr_en   <= `TD 0;
                    o_wp_vtp_nd_resp_wr_en    <= `TD 0;
                    o_rtc_vtp_resp_wr_en      <= `TD 0;
                    o_rrc_vtp_resp_wr_en      <= `TD 0;
                    o_rwm_vtp_resp_wr_en      <= `TD 0;
                    o_ee_vtp_resp_wr_en       <= `TD 0;

                    qv_db_vtp_resp_data      <= `TD 0;
                    qv_wp_vtp_wqe_resp_data  <= `TD 0;
                    qv_wp_vtp_nd_resp_data   <= `TD 0;
                    qv_rtc_vtp_resp_data     <= `TD 0;
                    qv_rrc_vtp_resp_data     <= `TD 0;
                    qv_rwm_vtp_resp_data     <= `TD 0;
                    qv_ee_vtp_resp_data      <= `TD 0;
                end
            endcase            
        end
        else begin
            o_db_vtp_resp_wr_en       <= `TD 0;
            o_wp_vtp_wqe_resp_wr_en   <= `TD 0;
            o_wp_vtp_nd_resp_wr_en    <= `TD 0;
            o_rtc_vtp_resp_wr_en      <= `TD 0;
            o_rrc_vtp_resp_wr_en      <= `TD 0;
            o_rwm_vtp_resp_wr_en      <= `TD 0;
            o_ee_vtp_resp_wr_en       <= `TD 0;

            qv_db_vtp_resp_data      <= `TD 0;
            qv_wp_vtp_wqe_resp_data  <= `TD 0;
            qv_wp_vtp_nd_resp_data   <= `TD 0;
            qv_rtc_vtp_resp_data     <= `TD 0;
            qv_rrc_vtp_resp_data     <= `TD 0;
            qv_rwm_vtp_resp_data     <= `TD 0;
            qv_ee_vtp_resp_data      <= `TD 0;
        end
    end
    //-----------------------{data for rsp state info to rdma engine } end-------------------

    //----------------interface to MTT module-------------------------
        //old version read/write block write MTT read request(include Src,Op,mtt_index,v-addr,length) to MTT module        
        //old version read/write block | ---------------------165 bit------------------------- |
        //old version read/write block |   Src    |     Op  | mtt_index | address |Byte length |
        //old version read/write block |  164:162 | 161:160 |  159:96   |  95:32  |   31:0     |
               
        //new version|--------------163 bit------------------------- |
        //new version|    Src  | mtt_index | address |Byte length |
        //new version| 162:160 |  159:96   |  95:32  |   31:0     |

        //note:all the v_addr transfer to mtt modele is a relative addr, if it's the absolute addr, sub the start addr
        //reg                  mpt_req_mtt_wr_en;
        //reg   [164:0]        mpt_req_mtt_din;
    // rd_mpt_req_fifo/pend_req_fifo foramt 
        //| 207:200 | 199:168 | 167:136 | 135:104 | 103:72  |  71:40  |  39:8  | 7:4 | 3:0  |
        //| channel | length  | VA-high | VA-low  |   Key   |   PD    |  Flags |  Op | Tpye |
    reg  [2:0] mpt_req_mtt_src_channel; // prepare for Src seg
    always @(*) begin
        if (rst) begin
            mpt_req_mtt_src_channel = 0;
        end
        else if (mpt_fsm_cs == MPT_RSP_PROC) begin
            case (qv_get_pend_req[207:200])
                8'b00000001: begin
                    mpt_req_mtt_src_channel = `SRC_CEU;
                end
                8'b00000010: begin
                    mpt_req_mtt_src_channel = `SRC_DBP;
                end
                8'b00000100: begin
                    mpt_req_mtt_src_channel = `SRC_WPWQE;
                end
                8'b00001000: begin
                    mpt_req_mtt_src_channel = `SRC_WPDT;
                end
                8'b00010000: begin
                    mpt_req_mtt_src_channel = `SRC_RTC;
                end
                8'b00100000: begin
                    mpt_req_mtt_src_channel = `SRC_RRC;
                end
                8'b01000000: begin
                    mpt_req_mtt_src_channel = `SRC_EEWQE;
                end
                8'b10000000: begin
                    mpt_req_mtt_src_channel = `SRC_EEDT;
                end
                default: mpt_req_mtt_src_channel = 0;
            endcase
        end
        else if (state_fsm_cs == MPT_HIT_PROC) begin
            case (qv_get_rd_mpt_req[207:200])
                8'b00000001: begin
                    mpt_req_mtt_src_channel = `SRC_CEU;
                end
                8'b00000010: begin
                    mpt_req_mtt_src_channel = `SRC_DBP;
                end
                8'b00000100: begin
                    mpt_req_mtt_src_channel = `SRC_WPWQE;
                end
                8'b00001000: begin
                    mpt_req_mtt_src_channel = `SRC_WPDT;
                end
                8'b00010000: begin
                    mpt_req_mtt_src_channel = `SRC_RTC;
                end
                8'b00100000: begin
                    mpt_req_mtt_src_channel = `SRC_RRC;
                end
                8'b01000000: begin
                    mpt_req_mtt_src_channel = `SRC_EEWQE;
                end
                8'b10000000: begin
                    mpt_req_mtt_src_channel = `SRC_EEDT;
                end
                default: mpt_req_mtt_src_channel = 0; 
            endcase
        end
        else begin
            mpt_req_mtt_src_channel = 0;
        end
    end

    always @(*) begin
        if (rst) begin
            mpt_req_mtt_op = 0;
        end 
        else if (mpt_fsm_cs == MPT_RSP_PROC) begin
            case (qv_get_pend_req[3:0])
                {`RD_REQ_WQE}:  begin
                    mpt_req_mtt_op = `DOWN;
                end
                {`RD_REQ_DATA}: begin
                    mpt_req_mtt_op = `DOWN;
                end
                {`WR_REQ_DATA}: begin
                    mpt_req_mtt_op = `UP;
                end
                default: mpt_req_mtt_op = 0;
            endcase
        end
        else if (state_fsm_cs == MPT_HIT_PROC) begin
            case (qv_get_rd_mpt_req[3:0])
                {`RD_REQ_WQE}:  begin
                    mpt_req_mtt_op = `DOWN;
                end
                {`RD_REQ_DATA}: begin
                    mpt_req_mtt_op = `DOWN;
                end
                {`WR_REQ_DATA}: begin
                    mpt_req_mtt_op = `UP;
                end
                default: mpt_req_mtt_op = 0;
            endcase
        end
        else begin
            mpt_req_mtt_op = 0;
        end
    end
    //***********************mpt data format*************************/
        //32*1 -1: 32*0 |   Flags                        |
        //32*2 -1: 32*1 |   page_size                    |
        //32*3 -1: 32*2 |   Key                          |
        //32*4 -1: 32*3 |   PD                           |
        //32*5 -1: 32*4 |   start-high                   |
        //32*6 -1: 32*5 |   start-low                    |
        //32*7 -1: 32*6 |   length-high                  |
        //32*8 -1: 32*7 |   length-low                   |
        //32*9 -1: 32*8 |   lkey             (Reserved)  |
        //32*10-1: 32*9 |   window_cnt       (Reserved)  |
        //32*11-1: 32*10|   window_cnt_limit (Reserved)  |
        //32*12-1: 32*11|   mtt_seg_high                 |
        //32*13-1: 32*12|   mtt_seg_low                  |
        //32*14-1: 32*13|   mtt_size         (Reserved)  |
    //***********************mpt data format*************************/
    wire [63:0] mpt_req_mtt_index; // prepare for mtt_index
    /*VCS Verification*/
    // assign mpt_req_mtt_index = (mpt_fsm_cs == MPT_RSP_PROC) ? {qv_get_dma_rsp_mpt_data[32*12-1: 32*11],qv_get_dma_rsp_mpt_data[32*13-1: 32*12]}: (state_fsm_cs == MPT_HIT_PROC) ? {qv_hit_data[32*12-1: 32*11],qv_hit_data[32*13-1: 32*12]} : 0;
    assign mpt_req_mtt_index = (mpt_fsm_cs == MPT_RSP_PROC) ? qv_get_dma_rsp_mpt_data[32*5-1: 32*3]:
                               (state_fsm_cs == MPT_HIT_PROC) ? qv_hit_data[32*5-1: 32*3] : 0;
    /*Action = Mopdify, choose the correct seg of mpt entry*/
    //note:all the v_addr transfer to mtt modele is a relative addr, if it's the absolute addr, sub the start addr
    reg [63:0] mpt_req_mtt_rv_addr;// prepare for relative virtual addr
    always @(*) begin
        if (rst) begin
            mpt_req_mtt_rv_addr = 0;
        end
        else if (mpt_fsm_cs == MPT_RSP_PROC) begin
            //addr type flags in pend_req_fifo rdma req: ABSOLUTE_ADDR [27+8];  RELATIVE_ADDR  [26+8]
            case (qv_get_pend_req[27+8:26+8])
            /*VCS Verification*/
                // // absolute addr: sub the start addr
                // 2'b10: begin
                //     mpt_req_mtt_rv_addr = qv_get_pend_req[191:128] - {qv_get_dma_rsp_mpt_data[32*5 -1: 32*4],qv_get_dma_rsp_mpt_data[32*6 -1: 32*5]};
                // end
                // // relative addr: use the relative addr directly
                // 2'b01: begin
                //     mpt_req_mtt_rv_addr = qv_get_pend_req[191:128];
                // end
                // absolute addr: sub the start addr
                2'b10: begin
                    mpt_req_mtt_rv_addr = qv_get_pend_req[167:104] - qv_get_dma_rsp_mpt_data[32*(4+8)-1: 32*(2+8)];
                end
                // relative addr: use the relative addr directly
                2'b01: begin
                    mpt_req_mtt_rv_addr = qv_get_pend_req[167:104];
                end
            /*Action = Modify, selecte the correct seg to compute relative vaddr*/
                default: mpt_req_mtt_rv_addr = 0;
            endcase
        end
        else if (state_fsm_cs == MPT_HIT_PROC) begin
            //addr type flags in rd_mpt_req rdma req: ABSOLUTE_ADDR [27+8];  RELATIVE_ADDR  [26+8]
            case (qv_get_rd_mpt_req[27+8:26+8])
            /*VCS Verification*/
                // // absolute addr: sub the start addr
                // 2'b10: begin
                //     mpt_req_mtt_rv_addr = qv_get_rd_mpt_req[191:128] - {qv_hit_data[32*5 -1: 32*4],qv_hit_data[32*6 -1: 32*5]};
                // end
                // // relative addr: use the relative addr directly
                // 2'b01: begin
                //     mpt_req_mtt_rv_addr = qv_get_rd_mpt_req[191:128];
                // end
                                // absolute addr: sub the start addr
                2'b10: begin
                    mpt_req_mtt_rv_addr = qv_get_rd_mpt_req[167:104] - qv_hit_data[32*(4+8)-1: 32*(2+8)];
                end
                // relative addr: use the relative addr directly
                2'b01: begin
                    mpt_req_mtt_rv_addr = qv_get_rd_mpt_req[167:104];
                end
            /*Action = Modify, selecte the correct seg to compute relative vaddr*/
                default: mpt_req_mtt_rv_addr = 0;
            endcase
        end
        else begin
            mpt_req_mtt_rv_addr = 0;
        end
    end

    wire [31:0] mpt_req_mtt_byte_len; // prepare for data read/write length (count by byte)
    assign mpt_req_mtt_byte_len = (mpt_fsm_cs == MPT_RSP_PROC) ? qv_get_pend_req[32*6+8-1:32*5+8] :
                               (state_fsm_cs == MPT_HIT_PROC) ? qv_get_rd_mpt_req[32*6+8-1:32*5+8] : 0;
    /*******mtt read/write block problem*********/
    // always @(posedge clk or posedge rst) begin
    //     if (rst) begin
    //         mpt_req_mtt_wr_en <= `TD 0;
    //         mpt_req_mtt_din <= `TD 0;
    //     end
    //     /*VCS Verification*/
    //     // FSM1 MPT_RSP_PROC state: write mtt req at after the cycle we get the last response mpt data from dma engine
    //     //else if ((mpt_fsm_cs == MPT_RSP_PROC) && (qv_mpt_rsp_data_cnt == 2) && lookup_allow_in  && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full) begin
    //     else if ((mpt_fsm_cs == MPT_RSP_PROC) && (qv_mpt_rsp_data_cnt == 2) && lookup_allow_in && lookup_wren && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full && rsp_match_success) begin
    //         mpt_req_mtt_wr_en <= `TD 1;
    //         mpt_req_mtt_din <= `TD {mpt_req_mtt_src_channel,mpt_req_mtt_op,mpt_req_mtt_index,mpt_req_mtt_rv_addr,mpt_req_mtt_byte_len};
    //     end
    //     // FSM2 MPT_HIT_PROC state: write mtt req to mtt_ram_ctl module at the last cycle of MPT_HIT_PROC 
    //     //else if ((state_fsm_cs == MPT_HIT_PROC) && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full) begin
    //     else if ((state_fsm_cs == MPT_HIT_PROC) && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full && hit_match_success) begin
    //         mpt_req_mtt_wr_en <= `TD 1;
    //         mpt_req_mtt_din <= `TD {mpt_req_mtt_src_channel,mpt_req_mtt_op,mpt_req_mtt_index,mpt_req_mtt_rv_addr,mpt_req_mtt_byte_len};
    //     end
    //     /*Action = Modify, add check state SUCCESS as another condition*/
    //     else begin
    //         mpt_req_mtt_wr_en <= `TD 0;
    //         mpt_req_mtt_din <= `TD 0;
    //     end
    // end

    //read data request to mtt_ram_ctl
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mpt_rd_req_mtt_wr_en <= `TD 0;
            mpt_rd_req_mtt_din <= `TD 0;
        end
        /*VCS Verification*/
        // FSM1 MPT_RSP_PROC state: write mtt req at after the cycle we get the last response mpt data from dma engine
        //else if ((mpt_fsm_cs == MPT_RSP_PROC) && (qv_mpt_rsp_data_cnt == 2) && lookup_allow_in  && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full) begin
        else if ((mpt_fsm_cs == MPT_RSP_PROC) && (qv_mpt_rsp_data_cnt == 2) && lookup_allow_in && lookup_wren && !selected_rsp_state_prog_full && !mpt_rd_req_mtt_prog_full && rsp_match_success && (mpt_req_mtt_op == `DOWN) && (qv_get_pend_req[3:0] == `RD_REQ_DATA)) begin
            mpt_rd_req_mtt_wr_en <= `TD 1;
            mpt_rd_req_mtt_din <= `TD {mpt_req_mtt_src_channel,mpt_req_mtt_index,mpt_req_mtt_rv_addr,mpt_req_mtt_byte_len};
        end
        // FSM2 MPT_HIT_PROC state: write mtt req to mtt_ram_ctl module at the last cycle of MPT_HIT_PROC 
        //else if ((state_fsm_cs == MPT_HIT_PROC) && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full) begin
        else if ((state_fsm_cs == MPT_HIT_PROC) && !mpt_rsp_stall && !selected_rsp_state_prog_full && !mpt_rd_req_mtt_prog_full && hit_match_success && (mpt_req_mtt_op == `DOWN) && (qv_get_rd_mpt_req[3:0] == `RD_REQ_DATA)) begin
            mpt_rd_req_mtt_wr_en <= `TD 1;
            mpt_rd_req_mtt_din <= `TD {mpt_req_mtt_src_channel,mpt_req_mtt_index,mpt_req_mtt_rv_addr,mpt_req_mtt_byte_len};
        end
        /*Action = Modify, add check state SUCCESS as another condition*/
        else begin
            mpt_rd_req_mtt_wr_en <= `TD 0;
            mpt_rd_req_mtt_din <= `TD 0;
        end
    end

    //read WQE request to mtt_ram_ctl
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mpt_rd_wqe_req_mtt_wr_en <= `TD 0;
            mpt_rd_wqe_req_mtt_din <= `TD 0;
        end
        /*VCS Verification*/
        // FSM1 MPT_RSP_PROC state: write mtt req at after the cycle we get the last response mpt data from dma engine
        //else if ((mpt_fsm_cs == MPT_RSP_PROC) && (qv_mpt_rsp_data_cnt == 2) && lookup_allow_in  && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full) begin
        else if ((mpt_fsm_cs == MPT_RSP_PROC) && (qv_mpt_rsp_data_cnt == 2) && lookup_allow_in && lookup_wren && !selected_rsp_state_prog_full && !mpt_rd_wqe_req_mtt_prog_full && rsp_match_success && (mpt_req_mtt_op == `DOWN) && (qv_get_pend_req[3:0] == `RD_REQ_WQE)) begin
            mpt_rd_wqe_req_mtt_wr_en <= `TD 1;
            mpt_rd_wqe_req_mtt_din <= `TD {mpt_req_mtt_src_channel,mpt_req_mtt_index,mpt_req_mtt_rv_addr,mpt_req_mtt_byte_len};
        end
        // FSM2 MPT_HIT_PROC state: write mtt req to mtt_ram_ctl module at the last cycle of MPT_HIT_PROC 
        //else if ((state_fsm_cs == MPT_HIT_PROC) && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full) begin
        else if ((state_fsm_cs == MPT_HIT_PROC) && !mpt_rsp_stall && !selected_rsp_state_prog_full && !mpt_rd_wqe_req_mtt_prog_full && hit_match_success && (mpt_req_mtt_op == `DOWN) && (qv_get_rd_mpt_req[3:0] == `RD_REQ_WQE)) begin
            mpt_rd_wqe_req_mtt_wr_en <= `TD 1;
            mpt_rd_wqe_req_mtt_din <= `TD {mpt_req_mtt_src_channel,mpt_req_mtt_index,mpt_req_mtt_rv_addr,mpt_req_mtt_byte_len};
        end
        /*Action = Modify, add check state SUCCESS as another condition*/
        else begin
            mpt_rd_wqe_req_mtt_wr_en <= `TD 0;
            mpt_rd_wqe_req_mtt_din <= `TD 0;
        end
    end

    //TODO:
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mpt_wr_req_mtt_wr_en <= `TD 0;
            mpt_wr_req_mtt_din <= `TD 0;
        end
        /*VCS Verification*/
        // // FSM1 MPT_RSP_PROC state: write mtt req at after the cycle we get the last response mpt data from dma engine
        // //else if ((mpt_fsm_cs == MPT_RSP_PROC) && (qv_mpt_rsp_data_cnt == 2) && lookup_allow_in  && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full) begin
        // else if ((mpt_fsm_cs == MPT_RSP_PROC) && (qv_mpt_rsp_data_cnt == 2) && lookup_allow_in && lookup_wren && !selected_rsp_state_prog_full && !mpt_wr_req_mtt_prog_full && rsp_match_success && (mpt_req_mtt_op == `UP)) begin
        //     mpt_wr_req_mtt_wr_en <= `TD 1;
        //     mpt_wr_req_mtt_din <= `TD {mpt_req_mtt_src_channel,mpt_req_mtt_index,mpt_req_mtt_rv_addr,mpt_req_mtt_byte_len};
        // end
        // // FSM2 MPT_HIT_PROC state: write mtt req to mtt_ram_ctl module at the last cycle of MPT_HIT_PROC 
        // //else if ((state_fsm_cs == MPT_HIT_PROC) && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full) begin
        // else if ((state_fsm_cs == MPT_HIT_PROC) && !selected_rsp_state_prog_full && !mpt_wr_req_mtt_prog_full && hit_match_success && (mpt_req_mtt_op == `UP)) begin
        //     mpt_wr_req_mtt_wr_en <= `TD 1;
        //     mpt_wr_req_mtt_din <= `TD {mpt_req_mtt_src_channel,mpt_req_mtt_index,mpt_req_mtt_rv_addr,mpt_req_mtt_byte_len};
        // end
        /*Action = Modify, add check state SUCCESS as another condition*/
        /*VCS Verification, add condition for two FSM conflict, MXX at 2022.04.24*/
        else if ((mpt_fsm_cs == MPT_RSP_PROC) && (qv_mpt_rsp_data_cnt == 2) && lookup_allow_in && lookup_wren && !selected_rsp_state_prog_full && !mpt_wr_req_mtt_prog_full && rsp_match_success && (mpt_req_mtt_op == `UP)) begin
            mpt_wr_req_mtt_wr_en <= `TD 1;
            mpt_wr_req_mtt_din <= `TD {mpt_req_mtt_src_channel,mpt_req_mtt_index,mpt_req_mtt_rv_addr,mpt_req_mtt_byte_len};
        end
        // FSM2 MPT_HIT_PROC state: write mtt req to mtt_ram_ctl module at the last cycle of MPT_HIT_PROC 
        //else if ((state_fsm_cs == MPT_HIT_PROC) && !selected_rsp_state_prog_full && !mpt_req_mtt_prog_full) begin
        else if ((state_fsm_cs == MPT_HIT_PROC) && !mpt_rsp_stall && !selected_rsp_state_prog_full && !mpt_wr_req_mtt_prog_full && hit_match_success && (mpt_req_mtt_op == `UP)) begin
            mpt_wr_req_mtt_wr_en <= `TD 1;
            // mpt_wr_req_mtt_din <= `TD {mpt_req_mtt_src_channel,mpt_req_mtt_index,mpt_req_mtt_rv_addr,mpt_req_mtt_byte_len};
            //TODO: add eq function, set index = 64{1'b1} to indicate the phy addr
            mpt_wr_req_mtt_din <= `TD (qv_req_info[7:0] == {`WR_EQE_DATA,`WR_REQ_DATA}) ? {mpt_req_mtt_src_channel,{64{1'b1}},qv_get_rd_mpt_req[167:104],mpt_req_mtt_byte_len} : {mpt_req_mtt_src_channel,mpt_req_mtt_index,mpt_req_mtt_rv_addr,mpt_req_mtt_byte_len};
        end
        /*Action = Modify, add add condition for two FSM conflict, MXX at 2022.04.24*/
        else begin
            mpt_wr_req_mtt_wr_en <= `TD 0;
            mpt_wr_req_mtt_din <= `TD 0;
        end
    end
    //Modify: maxiaoxiao, divide the mtt_ram_ctl req into read and write FIFOs

    //reg [2:0] lookup_ram_cnt
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            lookup_ram_cnt <= `TD 0;
        end else begin
            if ((lookup_rden | lookup_wren) && !state_rd_en) begin
                lookup_ram_cnt <= `TD lookup_ram_cnt + 1;
            end 
            else if (!lookup_rden && !lookup_wren && state_rd_en) begin
                lookup_ram_cnt <= `TD lookup_ram_cnt - 1;
            end
            else begin
                lookup_ram_cnt <= `TD lookup_ram_cnt;
            end
        end
    end

//-----------------{two state mechines both write signal} end--------------------//

`ifdef V2P_DUG
    // /*****************Add for APB-slave regs**********************************/ 
        // reg                          req_read_already,
        // reg   [PEND_CNT_WIDTH-1 :0] qv_pend_channel_cnt,
        // reg                    mpt_req_rd_en,
        // reg                    mpt_data_rd_en,
        // reg                o_db_vtp_cmd_rd_en,
        // reg                 o_db_vtp_resp_wr_en,
        // reg     [7:0]       ov_db_vtp_resp_data,
        // reg                o_wp_vtp_wqe_cmd_rd_en,
        // reg                 o_wp_vtp_wqe_resp_wr_en,
        // reg     [7:0]       ov_wp_vtp_wqe_resp_data,        
        // reg                o_wp_vtp_nd_cmd_rd_en,
        // reg                 o_wp_vtp_nd_resp_wr_en,
        // reg     [7:0]       ov_wp_vtp_nd_resp_data,
        // reg               o_rtc_vtp_cmd_rd_en,
        // reg                 o_rtc_vtp_resp_wr_en,
        // reg     [7:0]       ov_rtc_vtp_resp_data,    
        // reg               o_rrc_vtp_cmd_rd_en,
        // reg                 o_rrc_vtp_resp_wr_en,
        // reg     [7:0]       ov_rrc_vtp_resp_data,
        // reg               o_ee_vtp_cmd_rd_en,
        // reg                 o_ee_vtp_resp_wr_en,
        // reg     [7:0]       ov_ee_vtp_resp_data,
        // reg               o_rwm_vtp_cmd_rd_en,
        // reg                 o_rwm_vtp_resp_wr_en,
        // reg     [7:0]       ov_rwm_vtp_resp_data,
        // reg                             dma_rd_mpt_bkup_rd_en,
        // reg                      lookup_rden,
        // reg                      lookup_wren,
        // reg  [LINE_SIZE*8-1:0]   lookup_wdata,
        // reg  [INDEX -1     :0]   lookup_index,
        // reg  [TAG -1       :0]   lookup_tag,
        // reg                      mpt_eq_addr,
        // reg                           state_rd_en, 
        // reg                      hit_data_rd_en,
        // reg                      miss_addr_rd_en,
        // reg [2:0] lookup_ram_cnt
        // reg                  mpt_rd_req_mtt_wr_en;
        // reg   [162:0]        mpt_rd_req_mtt_din;
        // reg                  mpt_rd_wqe_req_mtt_wr_en;
        // reg   [162:0]        mpt_rd_wqe_req_mtt_din;
        // reg                  mpt_wr_req_mtt_wr_en;
        // reg   [162:0]        mpt_wr_req_mtt_din;
        // reg                        pend_req_wr_en;
        // reg   [207:0]              pend_req_din;
        // reg                        pend_req_rd_en;
        // reg                        rd_mpt_req_wr_en;
        // reg   [207:0]              rd_mpt_req_din;
        // reg                        rd_mpt_req_rd_en;
        // reg [2:0] mpt_fsm_cs;
        // reg [2:0] mpt_fsm_ns;
        // reg  [DMA_RD_BKUP_WIDTH-1 : 0] qv_get_dma_rd_mpt_bkup;
        // reg  [31:0]  qv_get_miss_addr;
        // reg  [207:0]  qv_get_pend_req;
        // reg  [127 : 0] qv_get_dma_rsp_mpt_header;    
        // reg  [511 : 0] qv_get_dma_rsp_mpt_data;    
        // reg  [2:0] qv_mpt_req_data_cnt;
        // reg  [2:0] qv_mpt_rsp_data_cnt;
        // reg [255 : 0] qv_req_info;
        // reg [511 : 0] qv_wr_mpt_data;
        // reg [2:0] state_fsm_cs;
        // reg [2:0] state_fsm_ns;
        // reg  [207:0]  qv_get_rd_mpt_req;
        // reg  [4:0]    qv_lookup_state;
        // reg  [511:0]  qv_hit_data;
        // reg  [2:0] mpt_req_mtt_src_channel;
        // reg [1:0] mpt_req_mtt_op;
        // reg [63:0] mpt_req_mtt_rv_addr;
        // 

    /*****************Add for APB-slave wires**********************************/         
        // wire   [CHANNEL_WIDTH-1 :0]  selected_channel,
        // wire  [`HD_WIDTH-1:0]   mpt_req_dout,
        // wire  [`DT_WIDTH-1:0]   mpt_data_dout,
        // wire                    mpt_data_empty,
        // wire    [255:0]     iv_db_vtp_cmd_data,
        // wire                i_db_vtp_resp_prog_full,
        // wire    [255:0]     iv_wp_vtp_wqe_cmd_data,
        // wire                i_wp_vtp_wqe_resp_prog_full,
        // wire    [255:0]     iv_wp_vtp_nd_cmd_data,
        // wire                i_wp_vtp_nd_resp_prog_full,
        // wire    [255:0]    iv_rtc_vtp_cmd_data,
        // wire                i_rtc_vtp_resp_prog_full,
        // wire    [255:0]    iv_rrc_vtp_cmd_data,
        // wire                i_rrc_vtp_resp_prog_full,
        // wire    [255:0]    iv_ee_vtp_cmd_data,
        // wire                i_ee_vtp_resp_prog_full,
        // wire    [255:0]    iv_rwm_vtp_cmd_data,
        // wire                i_rwm_vtp_resp_prog_full,
        // wire  [63:0]                    mpt_base_addr,  
        // wire  [DMA_RD_BKUP_WIDTH-1:0]   dma_rd_mpt_bkup_dout,
        // wire                            dma_rd_mpt_bkup_empty,
        // wire                           dma_v2p_mpt_rd_rsp_tready,
        // wire                           dma_v2p_mpt_rd_rsp_tvalid,
        // wire [`DT_WIDTH-1:0]           dma_v2p_mpt_rd_rsp_tdata,
        // wire                           dma_v2p_mpt_rd_rsp_tlast,
        // wire [`HD_WIDTH-1:0]           dma_v2p_mpt_rd_rsp_theader,
        // wire                     lookup_allow_in,
        // wire                     lookup_stall,
        // wire                          state_empty, 
        // wire [4:0]                    state_dout , 
        // wire                     hit_data_empty,         
        // wire [LINE_SIZE*8-1:0]   hit_data_dout,
        // wire  [31:0]             miss_addr_dout,
        // wire                     miss_addr_empty,
        // wire                     mpt_rd_req_mtt_rd_en,
        // wire  [162:0]            mpt_rd_req_mtt_dout,
        // wire                     mpt_rd_req_mtt_empty,
        // wire                     mpt_rd_wqe_req_mtt_rd_en,
        // wire  [162:0]            mpt_rd_wqe_req_mtt_dout,
        // wire                     mpt_rd_wqe_req_mtt_empty,
        // wire                     mpt_wr_req_mtt_rd_en,
        // wire  [162:0]            mpt_wr_req_mtt_dout,
        // wire                     mpt_wr_req_mtt_empty,
        // wire          mpt_rsp_stall,
        // wire      mpt_rd_req_mtt_prog_full;
        // wire                 mpt_rd_wqe_req_mtt_prog_full;
        // wire                 mpt_wr_req_mtt_prog_full;
        // wire   mpt_req_mtt_prog_full;
        // wire [255:0]  selected_req_data;
        // wire                       pend_req_prog_full;
        // wire  [207:0]              pend_req_dout;
        // wire                       pend_req_empty;
        // wire                       rd_mpt_req_prog_full;
        // wire  [207:0]              rd_mpt_req_dout;
        // wire                       rd_mpt_req_empty;
        // wire       rsp_match_success;
        // wire       rsp_match_pd_err;
        // wire       rsp_match_flags_err;
        // wire       rsp_match_key_err;
        // wire       rsp_match_len_err;
        // wire [7:0] rsp_match_state;
        // wire       selected_rsp_state_prog_full;
        // wire [31:0] lookup_addr;
        // wire       hit_match_success;
        // wire       hit_match_pd_err;
        // wire       hit_match_flags_err;
        // wire       hit_match_key_err;
        // wire       hit_match_len_err;
        // wire [7:0] hit_match_state;
        // wire [63:0] mpt_req_mtt_index;
        // wire [31:0] mpt_req_mtt_byte_len;
                // 
    //Total regs and wires : 8792 = 274*32+24

    assign wv_dbg_bus_mptctl = {
        8'b0,
        req_read_already,
        qv_pend_channel_cnt,
        mpt_req_rd_en,
        mpt_data_rd_en,
        o_db_vtp_cmd_rd_en,
        o_db_vtp_resp_wr_en,
        ov_db_vtp_resp_data,
        o_wp_vtp_wqe_cmd_rd_en,
        o_wp_vtp_wqe_resp_wr_en,
        ov_wp_vtp_wqe_resp_data,
        o_wp_vtp_nd_cmd_rd_en,
        o_wp_vtp_nd_resp_wr_en,
        ov_wp_vtp_nd_resp_data,
        o_rtc_vtp_cmd_rd_en,
        o_rtc_vtp_resp_wr_en,
        ov_rtc_vtp_resp_data,
        o_rrc_vtp_cmd_rd_en,
        o_rrc_vtp_resp_wr_en,
        ov_rrc_vtp_resp_data,
        o_ee_vtp_cmd_rd_en,
        o_ee_vtp_resp_wr_en,
        ov_ee_vtp_resp_data,
        o_rwm_vtp_cmd_rd_en,
        o_rwm_vtp_resp_wr_en,
        ov_rwm_vtp_resp_data,
        dma_rd_mpt_bkup_rd_en,
        lookup_rden,
        lookup_wren,
        lookup_wdata,
        lookup_index,
        lookup_tag,
        mpt_eq_addr,
        state_rd_en,
        hit_data_rd_en,
        miss_addr_rd_en,
        lookup_ram_cnt,
        mpt_rd_req_mtt_wr_en,
        mpt_rd_req_mtt_din,
        mpt_rd_wqe_req_mtt_wr_en,
        mpt_rd_wqe_req_mtt_din,
        mpt_wr_req_mtt_wr_en,
        mpt_wr_req_mtt_din,
        pend_req_wr_en,
        pend_req_din,
        pend_req_rd_en,
        rd_mpt_req_wr_en,
        rd_mpt_req_din,
        rd_mpt_req_rd_en,
        mpt_fsm_cs,
        mpt_fsm_ns,
        qv_get_dma_rd_mpt_bkup,
        qv_get_miss_addr,
        qv_get_pend_req,
        qv_get_dma_rsp_mpt_header,
        qv_get_dma_rsp_mpt_data,
        qv_mpt_req_data_cnt,
        qv_mpt_rsp_data_cnt,
        qv_req_info,
        qv_wr_mpt_data,
        state_fsm_cs,
        state_fsm_ns,
        qv_get_rd_mpt_req,
        qv_lookup_state,
        qv_hit_data,
        mpt_req_mtt_src_channel,
        mpt_req_mtt_op,
        mpt_req_mtt_rv_addr,
        qv_db_vtp_resp_data,
        qv_wp_vtp_wqe_resp_data,
        qv_wp_vtp_nd_resp_data,
        qv_rtc_vtp_resp_data,
        qv_rrc_vtp_resp_data,
        qv_rwm_vtp_resp_data,
        qv_ee_vtp_resp_data,

        selected_channel,
        mpt_req_dout,
        mpt_data_dout,
        mpt_data_empty,
        iv_db_vtp_cmd_data,
        i_db_vtp_resp_prog_full,
        iv_wp_vtp_wqe_cmd_data,
        i_wp_vtp_wqe_resp_prog_full,
        iv_wp_vtp_nd_cmd_data,
        i_wp_vtp_nd_resp_prog_full,
        iv_rtc_vtp_cmd_data,
        i_rtc_vtp_resp_prog_full,
        iv_rrc_vtp_cmd_data,
        i_rrc_vtp_resp_prog_full,
        iv_ee_vtp_cmd_data,
        i_ee_vtp_resp_prog_full,
        iv_rwm_vtp_cmd_data,
        i_rwm_vtp_resp_prog_full,
        mpt_base_addr,
        dma_rd_mpt_bkup_dout,
        dma_rd_mpt_bkup_empty,
        dma_v2p_mpt_rd_rsp_tready,
        dma_v2p_mpt_rd_rsp_tvalid,
        dma_v2p_mpt_rd_rsp_tdata,
        dma_v2p_mpt_rd_rsp_tlast,
        dma_v2p_mpt_rd_rsp_theader,
        lookup_allow_in,
        lookup_stall,
        state_empty,
        state_dout,
        hit_data_empty,
        hit_data_dout,
        miss_addr_dout,
        miss_addr_empty,
        mpt_rd_req_mtt_rd_en,
        mpt_rd_req_mtt_dout,
        mpt_rd_req_mtt_empty,
        mpt_rd_wqe_req_mtt_rd_en,
        mpt_rd_wqe_req_mtt_dout,
        mpt_rd_wqe_req_mtt_empty,
        mpt_wr_req_mtt_rd_en,
        mpt_wr_req_mtt_dout,
        mpt_wr_req_mtt_empty,
        mpt_rsp_stall,
        mpt_rd_req_mtt_prog_full,
        mpt_rd_wqe_req_mtt_prog_full,
        mpt_wr_req_mtt_prog_full,
        mpt_req_mtt_prog_full,
        selected_req_data,
        pend_req_prog_full,
        pend_req_dout,
        pend_req_empty,
        rd_mpt_req_prog_full,
        rd_mpt_req_dout,
        rd_mpt_req_empty,
        rsp_match_success,
        rsp_match_pd_err,
        rsp_match_flags_err,
        rsp_match_key_err,
        rsp_match_len_err,
        rsp_match_state,
        selected_rsp_state_prog_full,
        lookup_addr,
        hit_match_success,
        hit_match_pd_err,
        hit_match_flags_err,
        hit_match_key_err,
        hit_match_len_err,
        hit_match_state,
        mpt_req_mtt_index,
        mpt_req_mtt_byte_len
    };

`endif 


endmodule
