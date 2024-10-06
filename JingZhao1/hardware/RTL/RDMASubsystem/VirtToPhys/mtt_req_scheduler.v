//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: mtt_req_scheduler.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V3.0 
// VERSION DESCRIPTION: 3st Edition  
//----------------------------------------------------
// RELEASE DATE: 2022-05-09 
//---------------------------------------------------- 
// PURPOSE: schedule the mtt request from mpt_rd_req_parser, mpt_rd_wqe_req_parser and mpt_wr_req_parser.
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
// 
//-FHDR-----------------------------------------------

//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_v2p_h.vh"

module mtt_req_scheduler(
    input  wire  clk,
    input  wire  rst,


    input  wire  mpt_rd_req_mtt_cl_rd_en,
    input  wire  mpt_rd_req_mtt_cl_empty,
    input  wire  mpt_wr_req_mtt_cl_rd_en,
    input  wire  mpt_wr_req_mtt_cl_empty,
    //add for block processing, MXX at 2022.05.09 begin
        input  wire  mpt_rd_wqe_req_mtt_cl_rd_en,
        input  wire  mpt_rd_wqe_req_mtt_cl_empty,
        //mtt_ram_ctl block signal for 3 req fifo processing block 
        //| bit 2 read WQE | bit 1 write data | bit 0 read data |
        input  wire  [2:0]   block_valid,
        input  wire  [197:0] rd_wqe_block_info,
        input  wire  [197:0] wr_data_block_info,
        input  wire  [197:0] rd_data_block_info,
        //mtt_ram_ctl unblock signal for reading 3 blocked req  
        //| bit 2 read WQE | bit 1 write data | bit 0 read data |
        input  wire  [2:0]   unblock_valid,
        output reg   [197:0] rd_wqe_block_reg,
        output reg   [197:0] wr_data_block_reg,
        output reg   [197:0] rd_data_block_reg,

        input wire   dma_rd_dt_req_prog_full,
        input wire   dma_rd_wqe_req_prog_full,
        input wire   dma_wr_dt_req_prog_full,
    //add for block processing, MXX at 2022.05.09 end
    
    //req_scheduler changes the value of Selected Channel Reg to mark the selected channel
    // output reg  [3:0] new_selected_channel
    output reg  [3:0]  new_selected_channel

    `ifdef V2P_DUG
    //apb_slave
    ,  output wire [`MTTREQ_CTL_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_mttreq_ctl
    `endif

);


//-------------------- Output Decode--------------------

//compute the next channel,00-01-10
// use RoundRobin to update selected channel reg, depending on 
// the last selected channel, the request FIFO empty signal, the blocked req reg, the rd_en, block_valid, and unblock_valid
//------------------qv_new_selected_channel-------------------
//| bit |        Description    |
//|-----|-----------------------|
//|  3  |         valid         |
//|  2  | mpt_rd_wqe_req_mtt_cl |
//|  1  |   mpt_wr_req_mtt_cl   |
//|  0  |   mpt_rd_req_mtt_cl   |

// always @(posedge clk or posedge rst) begin
//     if (rst) begin
//         qv_new_selected_channel <= `TD 3'b0;
//     end
//     case (qv_new_selected_channel)
//         3'b000: begin
//             qv_new_selected_channel <= `TD (!mpt_rd_req_mtt_cl_empty) ? 3'b101 : (mpt_rd_req_mtt_cl_empty && !mpt_wr_req_mtt_cl_empty) ? 3'b110 : 3'b000;    
//         end
//         3'b001: begin
//             qv_new_selected_channel <= `TD (!mpt_wr_req_mtt_cl_empty) ? 3'b110 : (!mpt_rd_req_mtt_cl_empty) ? 3'b101 : 3'b001;
//         end
//         3'b010: begin
//             qv_new_selected_channel <= `TD (!mpt_rd_req_mtt_cl_empty) ? 3'b101 : (!mpt_wr_req_mtt_cl_empty) ? 3'b110 : 3'b010;
//         end
//         3'b101: begin
//             qv_new_selected_channel <= `TD (mpt_rd_req_mtt_cl_rd_en && !mpt_wr_req_mtt_cl_empty) ? 3'b110 : (mpt_rd_req_mtt_cl_rd_en && !mpt_rd_req_mtt_cl_empty) ? 3'b101 : 3'b001;
//         end
//         3'b110: begin
//             qv_new_selected_channel <= `TD (mpt_wr_req_mtt_cl_rd_en && !mpt_rd_req_mtt_cl_empty) ? 3'b101 : (mpt_wr_req_mtt_cl_rd_en && !mpt_wr_req_mtt_cl_empty) ? 3'b110 : 3'b010;
//         end
//         default: qv_new_selected_channel <= `TD 3'b0;
//     endcase    
// end

reg q_mpt_rd_req_mtt_cl_rd_en;
reg q_mpt_wr_req_mtt_cl_rd_en;
reg q_mpt_rd_wqe_req_mtt_cl_rd_en;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_mpt_rd_req_mtt_cl_rd_en <= `TD 1'b0;            
        q_mpt_wr_req_mtt_cl_rd_en <= `TD 1'b0;                
        q_mpt_rd_wqe_req_mtt_cl_rd_en <= `TD 1'b0;            
    end else begin
        q_mpt_rd_req_mtt_cl_rd_en <= `TD mpt_rd_req_mtt_cl_rd_en;                    
        q_mpt_wr_req_mtt_cl_rd_en <= `TD mpt_wr_req_mtt_cl_rd_en;                
        q_mpt_rd_wqe_req_mtt_cl_rd_en <= `TD mpt_rd_wqe_req_mtt_cl_rd_en;                    
    end    
end

//| bit 2 read WQE | bit 1 write data | bit 0 read data |
wire [2:0] block_req; //flags for qv_new_selected_channel change with valid qv_new_selected_channel block check
wire [2:0] block_req_state; //flags for qv_new_selected_channel change with invalid qv_new_selected_channel block check
assign block_req_state = 
    (((rd_wqe_block_reg  != 198'b0) || (block_valid[2] == 1'b1)) ? 3'b100 : 3'b000) |
    (((wr_data_block_reg != 198'b0) || (block_valid[1] == 1'b1)) ? 3'b010 : 3'b000) |
    (((rd_data_block_reg != 198'b0) || (block_valid[0] == 1'b1)) ? 3'b001 : 3'b000);
assign block_req = 
    ((((rd_wqe_block_reg  != 198'b0) && unblock_valid[2]) || (block_valid[2] == 1'b1)) ? 3'b100 : 3'b000) |
    ((((wr_data_block_reg != 198'b0) && unblock_valid[1]) || (block_valid[1] == 1'b1)) ? 3'b010 : 3'b000) |
    ((((rd_data_block_reg != 198'b0) && unblock_valid[0]) || (block_valid[0] == 1'b1)) ? 3'b001 : 3'b000);

//output reg   [197:0] rd_wqe_block_reg;
//output reg   [197:0] wr_data_block_reg;
//output reg   [197:0] rd_data_block_reg;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        rd_wqe_block_reg <= `TD 198'b0;
        wr_data_block_reg <= `TD 198'b0;
        rd_data_block_reg <= `TD 198'b0;
    end else begin
        case ({block_valid,unblock_valid})
            6'b000000: begin
                rd_wqe_block_reg  <= `TD rd_wqe_block_reg ;
                wr_data_block_reg <= `TD wr_data_block_reg;
                rd_data_block_reg <= `TD rd_data_block_reg;
            end
            6'b000001: begin
                rd_wqe_block_reg  <= `TD rd_wqe_block_reg ;
                wr_data_block_reg <= `TD wr_data_block_reg;
                rd_data_block_reg <= `TD 198'b0;
            end
            6'b000010: begin
                rd_wqe_block_reg  <= `TD rd_wqe_block_reg ;
                wr_data_block_reg <= `TD 198'b0;
                rd_data_block_reg <= `TD rd_data_block_reg;
            end
            6'b000100: begin
                rd_wqe_block_reg  <= `TD 198'b0;
                wr_data_block_reg <= `TD wr_data_block_reg;
                rd_data_block_reg <= `TD rd_data_block_reg;
            end
            6'b001000: begin
                rd_wqe_block_reg  <= `TD rd_wqe_block_reg ;
                wr_data_block_reg <= `TD wr_data_block_reg;
                rd_data_block_reg <= `TD rd_data_block_info;
            end            
            6'b010000: begin
                rd_wqe_block_reg  <= `TD rd_wqe_block_reg ;
                wr_data_block_reg <= `TD wr_data_block_info;
                rd_data_block_reg <= `TD rd_data_block_reg;
            end            
            6'b100000: begin
                rd_wqe_block_reg  <= `TD rd_wqe_block_info;
                wr_data_block_reg <= `TD wr_data_block_reg;
                rd_data_block_reg <= `TD rd_data_block_reg;
            end     
            //add others condition with valid and unvalid rising together :begin
            6'b010001: begin
                rd_wqe_block_reg  <= `TD rd_wqe_block_reg ;
                wr_data_block_reg <= `TD wr_data_block_info;
                rd_data_block_reg <= `TD 198'b0;
            end
            6'b100001: begin
                rd_wqe_block_reg  <= `TD rd_wqe_block_info ;
                wr_data_block_reg <= `TD wr_data_block_reg;
                rd_data_block_reg <= `TD 198'b0;
            end
            6'b001010: begin
                rd_wqe_block_reg  <= `TD rd_wqe_block_reg ;
                wr_data_block_reg <= `TD 198'b0;
                rd_data_block_reg <= `TD rd_data_block_info;
            end
            6'b100010: begin
                rd_wqe_block_reg  <= `TD rd_wqe_block_info ;
                wr_data_block_reg <= `TD 198'b0;
                rd_data_block_reg <= `TD rd_data_block_reg;
            end
            6'b001100: begin
                rd_wqe_block_reg  <= `TD 198'b0;
                wr_data_block_reg <= `TD wr_data_block_reg;
                rd_data_block_reg <= `TD rd_data_block_info;
            end
            6'b010100: begin
                rd_wqe_block_reg  <= `TD 198'b0;
                wr_data_block_reg <= `TD wr_data_block_info;
                rd_data_block_reg <= `TD rd_data_block_reg;
            end
            //add others condition with valid and unvalid rising together :end
            default: begin
                rd_wqe_block_reg  <= `TD rd_wqe_block_reg ;
                wr_data_block_reg <= `TD wr_data_block_reg;
                rd_data_block_reg <= `TD rd_data_block_reg;
            end
        endcase
    end
end

// reg [3:0] qv_new_selected_channel;
// always @(posedge clk or posedge rst) begin
//     if (rst) begin
//         qv_new_selected_channel <= `TD 4'b0;
//     end
//     else begin
//         case (qv_new_selected_channel[3:0])
//             4'b0000: begin
//                 qv_new_selected_channel <= `TD 
//                 ((!mpt_rd_req_mtt_cl_empty || block_req[0]) && !dma_rd_dt_req_prog_full) ? 4'b1001 : 
//                 (!mpt_rd_req_mtt_cl_empty || block_req[0]) ? 4'b1001 : 
//                 (!mpt_wr_req_mtt_cl_empty || block_req[1]) ? 4'b1010 :  
//                 (!mpt_rd_wqe_req_mtt_cl_empty || block_req[2]) ? 4'b1100 : 4'b0000;  
//             end
//             4'b0001: begin
//                 qv_new_selected_channel <= `TD 
//                 (!mpt_wr_req_mtt_cl_empty || block_req[1]) ? 4'b1010 :  
//                 (!mpt_rd_wqe_req_mtt_cl_empty || block_req[2]) ? 4'b1100 : 
//                 (!mpt_rd_req_mtt_cl_empty || block_req[0]) ? 4'b1001 : 4'b0001;  
//             end
//             4'b0010: begin
//                 qv_new_selected_channel <= `TD 
//                 (!mpt_rd_wqe_req_mtt_cl_empty || block_req[2]) ? 4'b1100 : 
//                 (!mpt_rd_req_mtt_cl_empty || block_req[0]) ? 4'b1001 :  
//                 (!mpt_wr_req_mtt_cl_empty || block_req[1]) ? 4'b1010 : 4'b0010;
//             end
//             4'b0100: begin
//                 qv_new_selected_channel <= `TD 
//                 (!mpt_rd_req_mtt_cl_empty || block_req[0]) ? 4'b1001 : 
//                 (!mpt_wr_req_mtt_cl_empty || block_req[1]) ? 4'b1010 :  
//                 (!mpt_rd_wqe_req_mtt_cl_empty || block_req[2]) ? 4'b1100 : 4'b0100;  
//             end
//             4'b1001: begin //keep the selected channel untill mtt_ram_ctl read the request, although mtt_ram_ctl may push back it to regs
//                 qv_new_selected_channel <= `TD 
//                 ((q_mpt_rd_req_mtt_cl_rd_en || unblock_valid[0]) && (!mpt_wr_req_mtt_cl_empty || block_req[1])) ? 4'b1010 :
//                 ((q_mpt_rd_req_mtt_cl_rd_en || unblock_valid[0]) && (!mpt_rd_wqe_req_mtt_cl_empty || block_req[2])) ? 4'b1100 :
//                 ((q_mpt_rd_req_mtt_cl_rd_en || unblock_valid[0]) && (!mpt_rd_req_mtt_cl_empty || block_req[0])) ? 4'b1001 : 
//                 ( q_mpt_rd_req_mtt_cl_rd_en || unblock_valid[0]) ? 4'b0001 : qv_new_selected_channel;
//             end
//             4'b1010: begin
//                 qv_new_selected_channel <= `TD 
//                 ((q_mpt_wr_req_mtt_cl_rd_en || unblock_valid[1]) && (!mpt_rd_wqe_req_mtt_cl_empty || block_req[2])) ? 4'b1100 :
//                 ((q_mpt_wr_req_mtt_cl_rd_en || unblock_valid[1]) && (!mpt_rd_req_mtt_cl_empty || block_req[0])) ? 4'b1001 :
//                 ((q_mpt_wr_req_mtt_cl_rd_en || unblock_valid[1]) && (!mpt_wr_req_mtt_cl_empty || block_req[1])) ? 4'b1010 : 
//                 ( q_mpt_wr_req_mtt_cl_rd_en || unblock_valid[1]) ? 4'b0010 : qv_new_selected_channel;
//             end
//             4'b1100: begin
//                 qv_new_selected_channel <= `TD 
//                 ((q_mpt_rd_wqe_req_mtt_cl_rd_en || unblock_valid[2]) && (!mpt_rd_req_mtt_cl_empty || block_req[0])) ? 4'b1001 :
//                 ((q_mpt_rd_wqe_req_mtt_cl_rd_en || unblock_valid[2]) && (!mpt_wr_req_mtt_cl_empty || block_req[1])) ? 4'b1010 : 
//                 ((q_mpt_rd_wqe_req_mtt_cl_rd_en || unblock_valid[2]) && (!mpt_rd_wqe_req_mtt_cl_empty || block_req[2])) ? 4'b1100 : 
//                 ( q_mpt_rd_wqe_req_mtt_cl_rd_en || unblock_valid[2]) ? 4'b0100 : qv_new_selected_channel;
//             end
//             default: qv_new_selected_channel <= `TD 4'b0;
//         endcase         
//     end
// end
reg  [3:0]  qv_new_selected_channel;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_new_selected_channel <= `TD 4'b0;
    end
    else begin
        case (new_selected_channel[3:0])
            // 4'b0000: begin
            //     qv_new_selected_channel <= `TD 
            //     ((!mpt_rd_req_mtt_cl_empty || block_req[0]) && !dma_rd_dt_req_prog_full) ? 4'b1001 : 
            //     ((!mpt_wr_req_mtt_cl_empty || block_req[1]) && !dma_wr_dt_req_prog_full) ? 4'b1010 :  
            //     ((!mpt_rd_wqe_req_mtt_cl_empty || block_req[2]) && !dma_rd_wqe_req_prog_full) ? 4'b1100 : 4'b0000;  
            // end
            // 4'b0001: begin
            //     qv_new_selected_channel <= `TD 
            //     ((!mpt_wr_req_mtt_cl_empty || block_req[1]) && !dma_wr_dt_req_prog_full) ? 4'b1010 :  
            //     ((!mpt_rd_wqe_req_mtt_cl_empty || block_req[2]) && !dma_rd_wqe_req_prog_full) ? 4'b1100 : 
            //     ((!mpt_rd_req_mtt_cl_empty || block_req[0]) && !dma_rd_dt_req_prog_full) ? 4'b1001 : 4'b0001;  
            // end
            // 4'b0010: begin
            //     qv_new_selected_channel <= `TD 
            //     ((!mpt_rd_wqe_req_mtt_cl_empty || block_req[2]) && !dma_rd_wqe_req_prog_full) ? 4'b1100 : 
            //     ((!mpt_rd_req_mtt_cl_empty || block_req[0]) && !dma_rd_dt_req_prog_full) ? 4'b1001 :  
            //     ((!mpt_wr_req_mtt_cl_empty || block_req[1]) && !dma_wr_dt_req_prog_full) ? 4'b1010 : 4'b0010;
            // end
            // 4'b0100: begin
            //     qv_new_selected_channel <= `TD 
            //     ((!mpt_rd_req_mtt_cl_empty || block_req[0]) && !dma_rd_dt_req_prog_full) ? 4'b1001 : 
            //     ((!mpt_wr_req_mtt_cl_empty || block_req[1]) && !dma_wr_dt_req_prog_full) ? 4'b1010 :  
            //     ((!mpt_rd_wqe_req_mtt_cl_empty || block_req[2]) && !dma_rd_wqe_req_prog_full) ? 4'b1100 : 4'b0100;  
            // end
            4'b0000: begin
                qv_new_selected_channel <= `TD 
                ((!mpt_rd_req_mtt_cl_empty || block_req_state[0]) && !dma_rd_dt_req_prog_full) ? 4'b1001 : 
                ((!mpt_wr_req_mtt_cl_empty || block_req_state[1]) && !dma_wr_dt_req_prog_full) ? 4'b1010 :  
                ((!mpt_rd_wqe_req_mtt_cl_empty || block_req_state[2]) && !dma_rd_wqe_req_prog_full) ? 4'b1100 : 4'b0000;  
            end
            4'b0001: begin
                qv_new_selected_channel <= `TD 
                ((!mpt_wr_req_mtt_cl_empty || block_req_state[1]) && !dma_wr_dt_req_prog_full) ? 4'b1010 :  
                ((!mpt_rd_wqe_req_mtt_cl_empty || block_req_state[2]) && !dma_rd_wqe_req_prog_full) ? 4'b1100 : 
                ((!mpt_rd_req_mtt_cl_empty || block_req_state[0]) && !dma_rd_dt_req_prog_full) ? 4'b1001 : 4'b0001;  
            end
            4'b0010: begin
                qv_new_selected_channel <= `TD 
                ((!mpt_rd_wqe_req_mtt_cl_empty || block_req_state[2]) && !dma_rd_wqe_req_prog_full) ? 4'b1100 : 
                ((!mpt_rd_req_mtt_cl_empty || block_req_state[0]) && !dma_rd_dt_req_prog_full) ? 4'b1001 :  
                ((!mpt_wr_req_mtt_cl_empty || block_req_state[1]) && !dma_wr_dt_req_prog_full) ? 4'b1010 : 4'b0010;
            end
            4'b0100: begin
                qv_new_selected_channel <= `TD 
                ((!mpt_rd_req_mtt_cl_empty || block_req_state[0]) && !dma_rd_dt_req_prog_full) ? 4'b1001 : 
                ((!mpt_wr_req_mtt_cl_empty || block_req_state[1]) && !dma_wr_dt_req_prog_full) ? 4'b1010 :  
                ((!mpt_rd_wqe_req_mtt_cl_empty || block_req_state[2]) && !dma_rd_wqe_req_prog_full) ? 4'b1100 : 4'b0100;  
            end
            4'b1001: begin //keep the selected channel untill mtt_ram_ctl read the request, although mtt_ram_ctl may push back it to regs
                qv_new_selected_channel <= `TD 
                // (!dma_wr_dt_req_prog_full && (q_mpt_rd_req_mtt_cl_rd_en || unblock_valid[0]) && (!mpt_wr_req_mtt_cl_empty || block_req[1])) ? 4'b1010 :
                // (!dma_rd_wqe_req_prog_full && (q_mpt_rd_req_mtt_cl_rd_en || unblock_valid[0]) && (!mpt_rd_wqe_req_mtt_cl_empty || block_req[2])) ? 4'b1100 :
                // (!dma_rd_dt_req_prog_full && (q_mpt_rd_req_mtt_cl_rd_en || unblock_valid[0]) && (!mpt_rd_req_mtt_cl_empty || block_req[0])) ? 4'b1001 : 
                (( q_mpt_rd_req_mtt_cl_rd_en || unblock_valid[0])) ? 4'b0001 : qv_new_selected_channel;
            end
            4'b1010: begin
                qv_new_selected_channel <= `TD 
                // (!dma_rd_wqe_req_prog_full && (q_mpt_wr_req_mtt_cl_rd_en || unblock_valid[1]) && (!mpt_rd_wqe_req_mtt_cl_empty || block_req[2])) ? 4'b1100 :
                // (!dma_rd_dt_req_prog_full && (q_mpt_wr_req_mtt_cl_rd_en || unblock_valid[1]) && (!mpt_rd_req_mtt_cl_empty || block_req[0])) ? 4'b1001 :
                // (!dma_wr_dt_req_prog_full && (q_mpt_wr_req_mtt_cl_rd_en || unblock_valid[1]) && (!mpt_wr_req_mtt_cl_empty || block_req[1])) ? 4'b1010 : 
                ( q_mpt_wr_req_mtt_cl_rd_en || unblock_valid[1]) ? 4'b0010 : qv_new_selected_channel;
            end
            4'b1100: begin
                qv_new_selected_channel <= `TD 
                // (!dma_rd_dt_req_prog_full && (q_mpt_rd_wqe_req_mtt_cl_rd_en || unblock_valid[2]) && (!mpt_rd_req_mtt_cl_empty || block_req[0])) ? 4'b1001 :
                // (!dma_wr_dt_req_prog_full && (q_mpt_rd_wqe_req_mtt_cl_rd_en || unblock_valid[2]) && (!mpt_wr_req_mtt_cl_empty || block_req[1])) ? 4'b1010 : 
                // (!dma_rd_wqe_req_prog_full && (q_mpt_rd_wqe_req_mtt_cl_rd_en || unblock_valid[2]) && (!mpt_rd_wqe_req_mtt_cl_empty || block_req[2])) ? 4'b1100 : 
                ( q_mpt_rd_wqe_req_mtt_cl_rd_en || unblock_valid[2]) ? 4'b0100 : qv_new_selected_channel;
            end
            default: qv_new_selected_channel <= `TD 4'b0;
        endcase         
    end
end

always @(*) begin
    case (qv_new_selected_channel)
        // 4'b0000: begin
        //     new_selected_channel = qv_new_selected_channel;
        // end
        // 4'b0001: begin
        //     new_selected_channel = qv_new_selected_channel;
        // end
        // 4'b0010: begin
        //     new_selected_channel = qv_new_selected_channel;
        // end
        // 4'b0100: begin
        //     new_selected_channel = qv_new_selected_channel;
        // end
        4'b1001: begin
            if (!dma_rd_dt_req_prog_full) begin
                new_selected_channel = qv_new_selected_channel;
            end else begin
                new_selected_channel = 4'b0001;
            end
        end
        4'b1010: begin
            if (!dma_wr_dt_req_prog_full) begin
                new_selected_channel = qv_new_selected_channel;
            end else begin
                new_selected_channel = 4'b0010; 
            end             
        end
        4'b1100: begin
            if (!dma_rd_wqe_req_prog_full) begin
                new_selected_channel = qv_new_selected_channel;
            end else begin
                new_selected_channel = 4'b0100; 
            end       
        end 
        default: new_selected_channel = qv_new_selected_channel;
    endcase
end


`ifdef V2P_DUG
    // /*****************Add for APB-slave regs**********************************/ 
        // output reg   [197:0] rd_wqe_block_reg,
        // output reg   [197:0] wr_data_block_reg,
        // output reg   [197:0] rd_data_block_reg,
        // output reg  [3:0]  qv_new_selected_channel
        // reg q_mpt_rd_req_mtt_cl_rd_en;
        // reg q_mpt_wr_req_mtt_cl_rd_en;
        // reg q_mpt_rd_wqe_req_mtt_cl_rd_en;
        
    /*****************Add for APB-slave wires**********************************/         
        // input  wire  mpt_rd_req_mtt_cl_rd_en,
        // input  wire  mpt_rd_req_mtt_cl_empty,
        // input  wire  mpt_wr_req_mtt_cl_rd_en,
        // input  wire  mpt_wr_req_mtt_cl_empty,
        // input  wire  mpt_rd_wqe_req_mtt_cl_rd_en,
        // input  wire  mpt_rd_wqe_req_mtt_cl_empty,
        // input  wire  [2:0]   block_valid,
        // input  wire  [197:0] rd_wqe_block_info,
        // input  wire  [197:0] wr_data_block_info,
        // input  wire  [197:0] rd_data_block_info,
        // input  wire  [2:0]   unblock_valid,
        // wire [2:0] block_req;

    //Total regs and wires : 2797 + 1895 = 4692 = 32 * 146 + 20. bit align 147

    assign wv_dbg_bus_mttreq_ctl = {
        6'b0,
        rd_wqe_block_reg,
        wr_data_block_reg,
        rd_data_block_reg,
        qv_new_selected_channel,
        q_mpt_rd_req_mtt_cl_rd_en,
        q_mpt_wr_req_mtt_cl_rd_en,
        q_mpt_rd_wqe_req_mtt_cl_rd_en,

        mpt_rd_req_mtt_cl_rd_en,
        mpt_rd_req_mtt_cl_empty,
        mpt_wr_req_mtt_cl_rd_en,
        mpt_wr_req_mtt_cl_empty,
        mpt_rd_wqe_req_mtt_cl_rd_en,
        mpt_rd_wqe_req_mtt_cl_empty,
        block_valid,
        rd_wqe_block_info,
        wr_data_block_info,
        rd_data_block_info,
        unblock_valid,
        block_req
    };

`endif 

endmodule