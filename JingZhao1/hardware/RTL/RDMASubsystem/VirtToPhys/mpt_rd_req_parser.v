//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: mpt_rd_req_parser.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V0.0 
// VERSION DESCRIPTION: 1st Edition  
//----------------------------------------------------
// RELEASE DATE: 2021-12-1
//---------------------------------------------------- 
// PURPOSE: parse the mpt_ram_ctl requests to mtt_ram_ctl with DMA read operations, and transfer them to mtt_ram_ctl
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
// 
//-FHDR-----------------------------------------------

//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_v2p_h.vh"

module mpt_rd_req_parser(
    input clk,
    input rst,  
    //----------------interface to mpt_ram_ctl module-------------------------
        // //read request(include Src,Op,mtt_index,v-addr,length) from mpt_ram module        
        // //| ---------------------165 bit------------------------- |
        // //|   Src    |     Op  | mtt_index | address |Byte length |
        // //|  164:162 | 161:160 |  159:96   |  95:32  |   31:0     |
        // output wire                     mpt_rd_req_mtt_rd_en,
        // input  wire  [164:0]            mpt_rd_req_mtt_dout,
        // input  wire                     mpt_rd_req_mtt_empty,

        //write read request(include Src,mtt_index,v-addr,length) to mtt_ram_ctl module        
        //|--------------163 bit------------------------- |
        //|    Src  | mtt_index | address |Byte length |
        //| 162:160 |  159:96   |  95:32  |   31:0     |
        output wire                     mpt_rd_req_mtt_rd_en,
        input  wire  [162:0]            mpt_rd_req_mtt_dout,
        input  wire                     mpt_rd_req_mtt_empty,

    //---------------------------mtt_ram_ctl--------------------------
        //mtt_ram look up request at cacheline level for dma read data requests
        //|--------------198 bit------------------------- |
        //|    Src  |  total length |    Op  | mtt_index | address | tmp length |
        //| 197:195 |    194:163    |162:160 |  159:96   |  95:32  |   31:0     |
        input   wire             mpt_rd_req_mtt_cl_rd_en,
        output  wire             mpt_rd_req_mtt_cl_empty,
        output  wire  [197:0]    mpt_rd_req_mtt_cl_dout

    `ifdef V2P_DUG
    //apb_slave
        ,  input wire [`MPTRD_DT_PAR_DBG_RW_NUM * 32 - 1 : 0]   rw_data
        ,  output wire [`MPTRD_DT_PAR_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mpt_rd_data_par
    `endif


);

//--------------{fifo declaration}begin---------------//

    //wmtt_ram look up request at cacheline level for dma read data requests
    wire                mpt_rd_req_mtt_cl_prog_full;
    reg                 mpt_rd_req_mtt_cl_wr_en;
    wire    [197:0]      mpt_rd_req_mtt_cl_din;
    mpt_wr_req_mtt_cl_fifo_198w64d mpt_rd_req_mtt_cl_fifo_198w64d_Inst(
        .clk        (clk),
        .srst       (rst),
        .wr_en      (mpt_rd_req_mtt_cl_wr_en),
        .rd_en      (mpt_rd_req_mtt_cl_rd_en),
        .din        (mpt_rd_req_mtt_cl_din),
        .dout       (mpt_rd_req_mtt_cl_dout),
        .full       (),
        .empty      (mpt_rd_req_mtt_cl_empty),     
        .prog_full  (mpt_rd_req_mtt_cl_prog_full)
    `ifdef V2P_DUG
    //apb_slave
        , .rw_data(rw_data[0 * 32 +: 1 * 32])        
    `endif
    ); 
//--------------{variable declaration}  end---------------//

//-----------------{mpt req processing state mechine} begin--------------------//

    //--------------{variable declaration}---------------
    
    // read: mpt request header 
    localparam  RD_MPT_REQ   = 2'b01;
    //initiate mtt_ram lookup signal    
    localparam  INIT_LOOKUP  = 2'b10; 

    reg [1:0] mpt_req_fsm_cs;
    reg [1:0] mpt_req_fsm_ns;

    //store the processing req info 
    reg  [162 : 0] qv_get_mpt_req;    //reg for mpt request 
    //total mtt_ram look up num derived from 1 mpt req at cache line level
    wire  [31:0]  total_mpt_rd_req_mtt_num;
    //reg for mpt look up mtt_ram times cnt
    reg  [31:0]  qv_mpt_rd_req_mtt_cnt;
    //reg for mpt look up mtt_ram addr, mtt index in mtt_ram
    reg  [63:0]  qv_mpt_rd_req_mtt_addr;    
    //left mtt entry num for 1 mpt req
    reg  [31:0] qv_left_mtt_entry_num;
    //reg for the data virtual addr of the 1st mtt in cache line
    reg  [63:0] qv_fisrt_mtt_vaddr;  
    //left mtt Byte length
    reg  [31:0] qv_left_mtt_Blen;
    // // store the req mtt num in one cacheline of 1 mtt_ram lookup
    // reg [2:0] qv_mtt_num_in_cacheline;
    // //left dma_read/write_data req num derived from 1 mtt_ram read req result
    // reg  [2:0]  qv_left_dma_req_from_cache;
    // //left dma_read/write_data req num derived from 1 mpt req
    // reg  [31:0] qv_left_dma_req_from_mpt;


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
                if (!mpt_rd_req_mtt_empty && !mpt_rd_req_mtt_cl_prog_full) begin
                    mpt_req_fsm_ns = INIT_LOOKUP;
                end else begin
                    mpt_req_fsm_ns = RD_MPT_REQ;
                end
            end
            INIT_LOOKUP: begin
                if ((qv_mpt_rd_req_mtt_cnt == total_mpt_rd_req_mtt_num))  begin
                    mpt_req_fsm_ns = RD_MPT_REQ;
                end
                else begin
                    mpt_req_fsm_ns = INIT_LOOKUP;
                end
            end
            default: mpt_req_fsm_ns = RD_MPT_REQ;
        endcase
    end
    //---------------------------------Stage 3 :Output Decode--------------------------------

    //----------------interface to mpt_ram module-------------------------
        //write read request(include Src,mtt_index,v-addr,length) to mtt_ram_ctl module        
        //|--------------163 bit------------------------- |
        //|    Src  | mtt_index | address |Byte length |
        //| 162:160 |  159:96   |  95:32  |   31:0     |
    assign mpt_rd_req_mtt_rd_en = (mpt_req_fsm_cs == RD_MPT_REQ) && !mpt_rd_req_mtt_empty && !mpt_rd_req_mtt_cl_prog_full;

    //store the processing req info 
        //reg  [162 : 0] qv_get_mpt_req;    //reg for mpt request 
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_get_mpt_req <= `TD 0;
        end else begin
            case (mpt_req_fsm_cs)
                RD_MPT_REQ: begin
                    if (mpt_rd_req_mtt_rd_en) begin
                        qv_get_mpt_req <= `TD mpt_rd_req_mtt_dout;
                    end
                    else begin
                        qv_get_mpt_req <= `TD 0;
                    end
                end
                INIT_LOOKUP: begin
                    // keep the mpt req
                    qv_get_mpt_req <= `TD qv_get_mpt_req;
                end
                default: qv_get_mpt_req <= `TD 0;
            endcase
        end
    end

    //request virtual addr page inside offset(low 12) add byte length
    wire [31:0]  req_vaddr_offset_add_Blen; 
    assign req_vaddr_offset_add_Blen = (mpt_req_fsm_cs==RD_MPT_REQ) ? (mpt_rd_req_mtt_dout[43:32] + mpt_rd_req_mtt_dout[31:0]) : (qv_get_mpt_req[43:32] + qv_get_mpt_req[31:0]);
    //mtt entry num = total physical page num =  (offset+Blen)/4K+((offset+Blen)%4K ? 1 :0)
    wire [31:0]  total_mtt_entry_num; 
    assign total_mtt_entry_num = req_vaddr_offset_add_Blen[31:12] + (|req_vaddr_offset_add_Blen[11:0] ? 1 : 0);
    //request index offset in cache line add total mtt entry num
    wire [31:0]  index_off_add_total_mtt_num;
    // assign index_off_add_total_mtt_num = (mpt_req_fsm_cs==RD_MPT_REQ) ? (mpt_rd_req_mtt_dout[97:96] + total_mtt_entry_num) : (qv_get_mpt_req[97:96] + total_mtt_entry_num);
    wire [63:0] wv_mpt_rd_req_mtt_addr;
    assign wv_mpt_rd_req_mtt_addr = (mpt_req_fsm_cs==RD_MPT_REQ) ? (mpt_rd_req_mtt_dout[159:96] + mpt_rd_req_mtt_dout[95:44]) : (qv_get_mpt_req[159:96] + qv_get_mpt_req[95:44]);
    assign index_off_add_total_mtt_num = (mpt_req_fsm_cs==RD_MPT_REQ) ? (wv_mpt_rd_req_mtt_addr[1:0] + total_mtt_entry_num) : (wv_mpt_rd_req_mtt_addr[1:0] + total_mtt_entry_num);
    //total mtt_ram look up num derived from 1 mpt req
        //    wire  [31:0]  total_mpt_rd_req_mtt_num;
    assign total_mpt_rd_req_mtt_num = index_off_add_total_mtt_num[31:2] + (|index_off_add_total_mtt_num[1:0] ? 1 :0);

    //reg for mpt look up mtt_ram times cnt
        //    reg  [31:0]  qv_mpt_rd_req_mtt_cnt;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qv_mpt_rd_req_mtt_cnt <= `TD 0;
        end
        else begin
           case (mpt_req_fsm_cs)
               RD_MPT_REQ: begin
                   qv_mpt_rd_req_mtt_cnt <= `TD 0;
               end
               INIT_LOOKUP: begin
                if (!mpt_rd_req_mtt_cl_prog_full && (qv_left_mtt_entry_num > 0) &&  (qv_mpt_rd_req_mtt_cnt < total_mpt_rd_req_mtt_num)) begin
                        qv_mpt_rd_req_mtt_cnt <= `TD qv_mpt_rd_req_mtt_cnt + 1;
                    end else begin
                        qv_mpt_rd_req_mtt_cnt <= `TD qv_mpt_rd_req_mtt_cnt;
                    end                  
               end
               default: qv_mpt_rd_req_mtt_cnt <= `TD 0;
           endcase 
        end
    end

    //reg for mpt look up mtt_ram addr, mtt index in mtt_ram
        //    reg  [63:0]  qv_mpt_rd_req_mtt_addr;    
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
            qv_mpt_rd_req_mtt_addr <= `TD 0;
            qv_left_mtt_entry_num <= `TD 0;
            qv_fisrt_mtt_vaddr <= `TD 0;
            qv_left_mtt_Blen <= `TD 0;
            // qv_mtt_num_in_cacheline <= `TD 0;
        end
        else begin
            case (mpt_req_fsm_cs)
                RD_MPT_REQ: begin
                    if (mpt_rd_req_mtt_rd_en) begin
                        // qv_mpt_rd_req_mtt_addr <= `TD mpt_rd_req_mtt_dout[159:96];
                        qv_mpt_rd_req_mtt_addr <= `TD wv_mpt_rd_req_mtt_addr;
                        qv_left_mtt_entry_num <= `TD total_mtt_entry_num;
                        /*VCS  Verification*/
                        // qv_fisrt_mtt_vaddr <= `TD mpt_rd_req_mtt_dout[63:0];
                        qv_fisrt_mtt_vaddr <= `TD mpt_rd_req_mtt_dout[95:32];
                        /*Action = Modify, correct the selected bits from mpt_ram_ctl request*/
                       
                        qv_left_mtt_Blen <= `TD mpt_rd_req_mtt_dout[31:0];
                        //total req mtt num + cache line offset > 4; this req mtt num = 4- cacheline offset
                        // qv_mtt_num_in_cacheline <= `TD (index_off_add_total_mtt_num >= 4) ? (3'b100 - wv_mpt_rd_req_mtt_addr[1:0]) : total_mtt_entry_num; 
                        // qv_mtt_num_in_cacheline <= `TD (index_off_add_total_mtt_num >= 4) ? (3'b100 - mpt_rd_req_mtt_dout[97:96]) : total_mtt_entry_num; 
                    end else begin
                        qv_mpt_rd_req_mtt_addr <= `TD 0;
                        qv_left_mtt_entry_num <= `TD 0;
                        qv_fisrt_mtt_vaddr <= `TD 0;
                        qv_left_mtt_Blen <= `TD 0;
                        // qv_mtt_num_in_cacheline <= `TD 0;
                    end
                end
                INIT_LOOKUP: begin
                    if ((qv_mpt_rd_req_mtt_cnt == total_mpt_rd_req_mtt_num)) begin
                    /*regs chnage if next state is RD_MPT_REQ*/
                        qv_mpt_rd_req_mtt_addr <= `TD 0;
                        qv_left_mtt_entry_num <= `TD 0;
                        qv_fisrt_mtt_vaddr <= `TD 0;
                        qv_left_mtt_Blen <= `TD 0;
                        // qv_mtt_num_in_cacheline <= `TD 0;
                    end                    
                    //next state is INIT_LOOKUP, change the data for lookup info and dma request in the next LOOKUP_RESULT_PROC state
                    else if ((qv_left_mtt_entry_num > 0) &&  (qv_mpt_rd_req_mtt_cnt < total_mpt_rd_req_mtt_num) && !mpt_rd_req_mtt_cl_prog_full && (qv_mpt_rd_req_mtt_addr[1:0] + qv_left_mtt_entry_num > 4)) begin
                    /*Action = Add, add  (&& (state_valid | q_result_valid)) condition*/
                        //req mtt num exceed 1 cacheline: index = index + 1; offset = 0 
                        qv_mpt_rd_req_mtt_addr <= `TD {qv_mpt_rd_req_mtt_addr[63:2],2'b00}+{61'b0,3'b100};
                        //req mtt num exceed 1 cacheline: left num = left num - req mtt num in the cacheline
                        qv_left_mtt_entry_num <= `TD qv_left_mtt_entry_num - (4 - qv_mpt_rd_req_mtt_addr[1:0]);
                        //req mtt num exceed 1 cacheline: fisrt_mtt_vaddr = fisrt_mtt_vaddr + req mtt num in cachline * 4K; low 12 bit=0
                        qv_fisrt_mtt_vaddr <= `TD {qv_fisrt_mtt_vaddr[63:12],12'b0} + {50'b1,14'b0} - {50'b0,qv_mpt_rd_req_mtt_addr[1:0],12'b0};
                        //req mtt num exceed 1 cacheline: left length = left length -(4K-vaddr{11:0})- (3-mtt num in cacheline)*4K;
                        qv_left_mtt_Blen <= `TD qv_left_mtt_Blen - ({20'b1,12'b0} - {20'b0,qv_fisrt_mtt_vaddr[11:0]}) - ({20'b11,12'b0} - {18'b0, qv_mpt_rd_req_mtt_addr[1:0],12'b0});
                        /*VCS Verification*/
                        //req mtt num exceed 1 cacheline: this mtt_ram mtt req num = 4;
                        // qv_mtt_num_in_cacheline <= `TD 4;
                        // qv_mtt_num_in_cacheline <= `TD ((qv_left_mtt_entry_num - (4 - qv_mpt_rd_req_mtt_addr[1:0])) > 4) ? 4 : (qv_left_mtt_entry_num - (4 - qv_mpt_rd_req_mtt_addr[1:0]));
                        /*Action = Modify, correct mtt_ram mtt req num*/
                    end
                    //next state is INIT_LOOKUP, change the data for lookup info and dma request in the next LOOKUP_RESULT_PROC state
                    else if ((qv_left_mtt_entry_num > 0) && (qv_mpt_rd_req_mtt_cnt < total_mpt_rd_req_mtt_num) && !mpt_rd_req_mtt_cl_prog_full  && (qv_mpt_rd_req_mtt_addr[1:0] +qv_left_mtt_entry_num <= 4)) begin
                        //req mtt num don't exceed 1 cacheline: index = index; offset = offset + num                       
                        qv_mpt_rd_req_mtt_addr <= `TD qv_mpt_rd_req_mtt_addr + qv_left_mtt_entry_num;
                        //req mtt num not exceed 1 cacheline: left num = 0
                        qv_left_mtt_entry_num <= `TD 0;
                        //req mtt num not exceed 1 cacheline: fisrt_mtt_vaddr = fisrt_mtt_vaddr + qv_left_mtt_Blen;
                        qv_fisrt_mtt_vaddr <= `TD qv_fisrt_mtt_vaddr + qv_left_mtt_Blen;
                        //req mtt num not exceed 1 cacheline: left length = 0;
                        qv_left_mtt_Blen <= `TD 0;
                        //req mtt num not exceed 1 cacheline: this mtt_ram mtt req num = left mtt num
                        // qv_mtt_num_in_cacheline <= `TD qv_left_mtt_entry_num;
                    end
                    else begin
                        qv_mpt_rd_req_mtt_addr <= `TD qv_mpt_rd_req_mtt_addr;
                        qv_left_mtt_entry_num <= `TD qv_left_mtt_entry_num;
                        qv_fisrt_mtt_vaddr <= `TD qv_fisrt_mtt_vaddr;
                        qv_left_mtt_Blen <= `TD qv_left_mtt_Blen;
                        // qv_mtt_num_in_cacheline <= `TD qv_mtt_num_in_cacheline;
                    end
                end
                default: begin
                    qv_mpt_rd_req_mtt_addr <= `TD 0;
                    qv_left_mtt_entry_num <= `TD 0;
                    qv_fisrt_mtt_vaddr <= `TD 0;
                    qv_left_mtt_Blen <= `TD 0;
                    // qv_mtt_num_in_cacheline <= `TD 0;
                end 
            endcase 
        end
    end

    //---------------------------mtt_ram_ctl--------------------------
        //mtt_ram look up request at cacheline level for dma read data requests
        //|--------------198 bit------------------------- |
        //|    Src  |  total length |    Op  | mtt_index | address | tmp length |
        //| 197:195 |    194:163    |162:160 |  159:96   |  95:32  |   31:0     |
    //------------------interface to mpt_ram_ctl module-------------
        //reg                                mpt_rd_req_mtt_cl_wr_en;
        //wire                                mpt_rd_req_mtt_cl_din;
    reg     [197-2:0]    qv_mpt_rd_req_mtt_cl_din;
    assign mpt_rd_req_mtt_cl_din = qv_mpt_rd_req_mtt_cl_din[160] ? {qv_mpt_rd_req_mtt_cl_din[197-2:161],`DATA_RD_FIRST,qv_mpt_rd_req_mtt_cl_din[159:0]} : {qv_mpt_rd_req_mtt_cl_din[197-2:161],`DATA_RD,qv_mpt_rd_req_mtt_cl_din[159:0]};
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mpt_rd_req_mtt_cl_wr_en <= `TD 0;
            qv_mpt_rd_req_mtt_cl_din <= `TD 0;
        end else if ((mpt_req_fsm_cs == INIT_LOOKUP) && (qv_left_mtt_entry_num > 0) && (qv_mpt_rd_req_mtt_cnt < total_mpt_rd_req_mtt_num) && !mpt_rd_req_mtt_cl_prog_full && (qv_mpt_rd_req_mtt_addr[1:0] + qv_left_mtt_entry_num > 4)) begin
            mpt_rd_req_mtt_cl_wr_en <= `TD 1;
            // qv_mpt_rd_req_mtt_cl_din <= `TD {qv_get_mpt_req[162:160],qv_get_mpt_req[31:0],((qv_mpt_rd_req_mtt_cnt == 0) ? `DATA_RD_FIRST : `DATA_RD),qv_mpt_rd_req_mtt_addr,qv_fisrt_mtt_vaddr,(({20'b1,12'b0} - {20'b0,qv_fisrt_mtt_vaddr[11:0]}) + ({20'b11,12'b0} - {18'b0, qv_mpt_rd_req_mtt_addr[1:0],12'b0})) };
            qv_mpt_rd_req_mtt_cl_din <= `TD {qv_get_mpt_req[162:160],qv_get_mpt_req[31:0],((qv_mpt_rd_req_mtt_cnt == 0) ? 1'b1 : 1'b0),qv_mpt_rd_req_mtt_addr,qv_fisrt_mtt_vaddr,(({20'b1,12'b0} - {20'b0,qv_fisrt_mtt_vaddr[11:0]}) + ({20'b11,12'b0} - {18'b0, qv_mpt_rd_req_mtt_addr[1:0],12'b0})) };
        end
        else if ((mpt_req_fsm_cs == INIT_LOOKUP) && (qv_left_mtt_entry_num > 0) && (qv_mpt_rd_req_mtt_cnt < total_mpt_rd_req_mtt_num) && !mpt_rd_req_mtt_cl_prog_full  && (qv_mpt_rd_req_mtt_addr[1:0] +qv_left_mtt_entry_num <= 4)) begin
            mpt_rd_req_mtt_cl_wr_en <= `TD 1;
            // qv_mpt_rd_req_mtt_cl_din <= `TD {qv_get_mpt_req[162:160],qv_get_mpt_req[31:0],((qv_mpt_rd_req_mtt_cnt == 0) ? `DATA_RD_FIRST : `DATA_RD),qv_mpt_rd_req_mtt_addr,qv_fisrt_mtt_vaddr,qv_left_mtt_Blen};
            qv_mpt_rd_req_mtt_cl_din <= `TD {qv_get_mpt_req[162:160],qv_get_mpt_req[31:0],((qv_mpt_rd_req_mtt_cnt == 0) ? 1'b1 : 1'b0),qv_mpt_rd_req_mtt_addr,qv_fisrt_mtt_vaddr,qv_left_mtt_Blen};
        end
        else begin
            mpt_rd_req_mtt_cl_wr_en <= `TD 0;
            qv_mpt_rd_req_mtt_cl_din <= `TD 0;
        end
    end

`ifdef V2P_DUG
    // /*****************Add for APB-slave regs**********************************/ 
        // reg                 mpt_rd_req_mtt_cl_wr_en;
        // reg    [197:0]      mpt_rd_req_mtt_cl_din;
        // reg [1:0] mpt_req_fsm_cs;
        // reg [1:0] mpt_req_fsm_ns;
        // reg  [162 : 0] qv_get_mpt_req;
        // reg  [31:0]  qv_mpt_rd_req_mtt_cnt;
        // reg  [63:0]  qv_mpt_rd_req_mtt_addr;    
        // reg  [31:0] qv_left_mtt_entry_num;
        // reg  [63:0] qv_fisrt_mtt_vaddr;  
        // reg  [31:0] qv_left_mtt_Blen;

    /*****************Add for APB-slave wires**********************************/         
        // wire                     mpt_rd_req_mtt_rd_en,
        // wire  [162:0]            mpt_rd_req_mtt_dout,
        // wire                     mpt_rd_req_mtt_empty,
        // wire             mpt_rd_req_mtt_cl_rd_en,
        // wire             mpt_rd_req_mtt_cl_empty,
        // wire  [197:0]    mpt_rd_req_mtt_cl_dout
        // wire                mpt_rd_req_mtt_cl_prog_full;
        // wire  [31:0]  total_mpt_rd_req_mtt_num;
        // wire [31:0]  req_vaddr_offset_add_Blen; 
        // wire [31:0]  total_mtt_entry_num; 
        // wire [31:0]  index_off_add_total_mtt_num;
        // wire [63:0] wv_mpt_rd_req_mtt_addr;

        
    //Total regs and wires : 1344 = 32 * 42

    assign wv_dbg_bus_mpt_rd_data_par = {
        // 16'hffff,
        mpt_rd_req_mtt_cl_wr_en,
        qv_mpt_rd_req_mtt_cl_din,
        mpt_req_fsm_cs,
        mpt_req_fsm_ns,
        qv_get_mpt_req,
        qv_mpt_rd_req_mtt_cnt,
        qv_mpt_rd_req_mtt_addr,
        qv_left_mtt_entry_num,
        qv_fisrt_mtt_vaddr,
        qv_left_mtt_Blen,

        mpt_rd_req_mtt_cl_din,
        mpt_rd_req_mtt_rd_en,
        mpt_rd_req_mtt_dout,
        mpt_rd_req_mtt_empty,
        mpt_rd_req_mtt_cl_rd_en,
        mpt_rd_req_mtt_cl_empty,
        mpt_rd_req_mtt_cl_dout,
        mpt_rd_req_mtt_cl_prog_full,
        total_mpt_rd_req_mtt_num,
        req_vaddr_offset_add_Blen,
        total_mtt_entry_num,
        index_off_add_total_mtt_num,
        wv_mpt_rd_req_mtt_addr
    };

`endif 

endmodule