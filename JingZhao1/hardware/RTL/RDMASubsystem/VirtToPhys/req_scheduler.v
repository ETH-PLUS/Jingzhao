//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: req_scheduler.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V0.0 
// VERSION DESCRIPTION: 2st Edition  
//----------------------------------------------------
// RELEASE DATE: 2022-03-28 
//---------------------------------------------------- 
// PURPOSE: schedule the mpt request from ceu and rdma engine.
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
// 
//-FHDR-----------------------------------------------

//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_v2p_h.vh"

module req_scheduler#(
    // used for Selected Channel Reg to mark the selected channel and Ready, MPT/MTT module may read the info
    parameter CHANNEL_WIDTH = 9, 
    // used for Pend Channel Reg, req_scheduler may read it to make decision choose which req channel 
    parameter PEND_CNT_WIDTH = 32 
    )(
    input  wire  clk,
    input  wire  rst,

    //these signals from the rd_req_empty singal of CEU, and other 7 reqs from RDMA Engine submodule
    input  wire  rd_ceu_req_empty,
    input  wire  rd_dbp_req_empty,
    input  wire  rd_wp_wqe_req_empty,
    input  wire  rd_wp_dt_req_empty,
    input  wire  rd_rtc_req_empty,
    input  wire  rd_rrc_req_empty,
    input  wire  rd_rqwqe_req_empty,
    input  wire  rd_ee_req_empty,
    
    /*VCS Verification*/
    //check mpt_ram_ctl read lookup state from mpt_ram read enable signal, and delay 2 clk to get the new pend_channel_cnt value to selecte next channel
    input wire state_rd_en,
    // input wire state_empty,
    /*Action = add*/

    // //MPT module set this signal, after MPT module read req from req_fifo
    // input wire    req_read_already,

    //req_scheduler read Pending Channel Count Reg to make decision choose which req channel 
    input  wire  [PEND_CNT_WIDTH-1 :0] pend_channel_cnt,

    //req_scheduler changes the value of Selected Channel Reg to mark the selected channel, MPT/MTT module may read the info
    output wire  [CHANNEL_WIDTH-1 :0]  new_selected_channel,

    //req_scheduler read the value of Selected Channel Reg to make decision
    input wire   [CHANNEL_WIDTH-1 :0]   old_selected_channel,
    input wire          mpt_rsp_stall,
    input wire [2:0] lookup_ram_cnt

    `ifdef V2P_DUG
    //apb_slave
    ,  output wire [`REQSCH_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_reqsch
    `endif

);


//-------------------- Output Decode--------------------

reg [CHANNEL_WIDTH-2:0] qv_next_channel; 
//compute the next channel, 00000001-00000010-00000100-00001000-00010000-00100000-01000000-10000000-00000001
// use RoundRobin to update selected channel reg, depending on 
// the last selected channel, the request FIFO empty signal, and the pend channel count reg
// ceu has the 1st priority

reg    [CHANNEL_WIDTH-1 : 0] qv_selected_channel;

/*VCS Verification*/
//check mpt_ram_ctl read lookup state from mpt_ram read enable signal, and delay 2 clk to get the new pend_channel_cnt value to selecte next channel
//input wire state_rd_en
reg q_state_rd_delay1;
reg q_state_rd_delay2;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_state_rd_delay1 <= `TD 0;
        q_state_rd_delay2 <= `TD 0;
    /*VCS Verification*/
    // end else begin
    //     q_state_rd_delay1 <= `TD state_rd_en;
    //     q_state_rd_delay2 <= `TD q_state_rd_delay1;
    // end
    // end else if ((state_rd_en | q_state_rd_delay1) & !q_state_rd_delay2 & !req_read_already) begin
    end else if ((state_rd_en | q_state_rd_delay1) & !q_state_rd_delay2) begin
        q_state_rd_delay1 <= `TD state_rd_en;
        q_state_rd_delay2 <= `TD q_state_rd_delay1;
    //Modified by maxiaoxiao at 2022.03.28, keep the q_state_rd_delay2 valid if qv_selected_channel[CHANNEL_WIDTH-2:0] != qv_next_channel
    // end else if ((old_selected_channel[CHANNEL_WIDTH-1] == 0) && (qv_next_channel != 0) && q_state_rd_delay2 && !mpt_rsp_stall) begin
    end else if ((old_selected_channel[CHANNEL_WIDTH-1] == 0) && (qv_next_channel != 0) && q_state_rd_delay2 && !mpt_rsp_stall && (qv_selected_channel[CHANNEL_WIDTH-2:0] == qv_next_channel)) begin
        q_state_rd_delay1 <= `TD 0;
        q_state_rd_delay2 <= `TD 0;
    end else begin
        q_state_rd_delay1 <= `TD q_state_rd_delay1;
        q_state_rd_delay2 <= `TD q_state_rd_delay2;
    end
    /*Action = Modify, keep the q_state_rd_delay1, q_state_rd_delay2 signals if there is no new request comes*/
end
/*Action = add*/

always @(*) begin
    case (old_selected_channel[CHANNEL_WIDTH-2:0])
        8'b00000000: begin
            qv_next_channel = (!rd_ceu_req_empty    &&  (pend_channel_cnt[1*4-1:0*4] == 4'b0)) ? 8'b00000001 :      
                              (!rd_dbp_req_empty    &&  (pend_channel_cnt[2*4-1:1*4] == 4'b0)) ? 8'b00000010 :      
                              (!rd_wp_wqe_req_empty &&  (pend_channel_cnt[3*4-1:2*4] == 4'b0)) ? 8'b00000100 :      
                              (!rd_wp_dt_req_empty  &&  (pend_channel_cnt[4*4-1:3*4] == 4'b0)) ? 8'b00001000 :      
                              (!rd_rtc_req_empty    &&  (pend_channel_cnt[5*4-1:4*4] == 4'b0)) ? 8'b00010000 :      
                              (!rd_rrc_req_empty    &&  (pend_channel_cnt[6*4-1:5*4] == 4'b0)) ? 8'b00100000 :      
                              (!rd_rqwqe_req_empty  &&  (pend_channel_cnt[7*4-1:6*4] == 4'b0)) ? 8'b01000000 :      
                              (!rd_ee_req_empty     &&  (pend_channel_cnt[8*4-1:7*4] == 4'b0)) ? 8'b10000000 : 8'b00000000;    
        end
        8'b00000001: begin
            qv_next_channel = (!rd_ceu_req_empty    &&  (pend_channel_cnt[1*4-1:0*4] == 4'b0)) ? 8'b00000001 :
                              (!rd_dbp_req_empty    &&  (pend_channel_cnt[2*4-1:1*4] == 4'b0)) ? 8'b00000010 :      
                              (!rd_wp_wqe_req_empty &&  (pend_channel_cnt[3*4-1:2*4] == 4'b0)) ? 8'b00000100 :      
                              (!rd_wp_dt_req_empty  &&  (pend_channel_cnt[4*4-1:3*4] == 4'b0)) ? 8'b00001000 :      
                              (!rd_rtc_req_empty    &&  (pend_channel_cnt[5*4-1:4*4] == 4'b0)) ? 8'b00010000 :      
                              (!rd_rrc_req_empty    &&  (pend_channel_cnt[6*4-1:5*4] == 4'b0)) ? 8'b00100000 :      
                              (!rd_rqwqe_req_empty  &&  (pend_channel_cnt[7*4-1:6*4] == 4'b0)) ? 8'b01000000 :      
                              (!rd_ee_req_empty     &&  (pend_channel_cnt[8*4-1:7*4] == 4'b0)) ? 8'b10000000 : 
                               8'b00000000;    
        end
        8'b00000010: begin
            qv_next_channel = (!rd_ceu_req_empty    &&  (pend_channel_cnt[1*4-1:0*4] == 4'b0)) ? 8'b00000001 : 
                              (!rd_wp_wqe_req_empty &&  (pend_channel_cnt[3*4-1:2*4] == 4'b0)) ? 8'b00000100 :      
                              (!rd_wp_dt_req_empty  &&  (pend_channel_cnt[4*4-1:3*4] == 4'b0)) ? 8'b00001000 :      
                              (!rd_rtc_req_empty    &&  (pend_channel_cnt[5*4-1:4*4] == 4'b0)) ? 8'b00010000 :      
                              (!rd_rrc_req_empty    &&  (pend_channel_cnt[6*4-1:5*4] == 4'b0)) ? 8'b00100000 :      
                              (!rd_rqwqe_req_empty  &&  (pend_channel_cnt[7*4-1:6*4] == 4'b0)) ? 8'b01000000 :      
                              (!rd_ee_req_empty     &&  (pend_channel_cnt[8*4-1:7*4] == 4'b0)) ? 8'b10000000 : 
                              (!rd_dbp_req_empty    &&  (pend_channel_cnt[2*4-1:1*4] == 4'b0)) ? 8'b00000010 :  8'b00000000;    
        end
        8'b00000100: begin
            qv_next_channel = (!rd_ceu_req_empty    &&  (pend_channel_cnt[1*4-1:0*4] == 4'b0)) ? 8'b00000001 : 
                              (!rd_wp_dt_req_empty  &&  (pend_channel_cnt[4*4-1:3*4] == 4'b0)) ? 8'b00001000 :      
                              (!rd_rtc_req_empty    &&  (pend_channel_cnt[5*4-1:4*4] == 4'b0)) ? 8'b00010000 :      
                              (!rd_rrc_req_empty    &&  (pend_channel_cnt[6*4-1:5*4] == 4'b0)) ? 8'b00100000 :      
                              (!rd_rqwqe_req_empty  &&  (pend_channel_cnt[7*4-1:6*4] == 4'b0)) ? 8'b01000000 :      
                              (!rd_ee_req_empty     &&  (pend_channel_cnt[8*4-1:7*4] == 4'b0)) ? 8'b10000000 : 
                              (!rd_dbp_req_empty    &&  (pend_channel_cnt[2*4-1:1*4] == 4'b0)) ? 8'b00000010 :  
                              (!rd_wp_wqe_req_empty &&  (pend_channel_cnt[3*4-1:2*4] == 4'b0)) ? 8'b00000100 :      
                              8'b00000000;    
        end  
        8'b00001000: begin
            qv_next_channel = (!rd_ceu_req_empty    &&  (pend_channel_cnt[1*4-1:0*4] == 4'b0)) ? 8'b00000001 : 
                              (!rd_rtc_req_empty    &&  (pend_channel_cnt[5*4-1:4*4] == 4'b0)) ? 8'b00010000 :      
                              (!rd_rrc_req_empty    &&  (pend_channel_cnt[6*4-1:5*4] == 4'b0)) ? 8'b00100000 :      
                              (!rd_rqwqe_req_empty  &&  (pend_channel_cnt[7*4-1:6*4] == 4'b0)) ? 8'b01000000 :      
                              (!rd_ee_req_empty     &&  (pend_channel_cnt[8*4-1:7*4] == 4'b0)) ? 8'b10000000 : 
                              (!rd_dbp_req_empty    &&  (pend_channel_cnt[2*4-1:1*4] == 4'b0)) ? 8'b00000010 :  
                              (!rd_wp_wqe_req_empty &&  (pend_channel_cnt[3*4-1:2*4] == 4'b0)) ? 8'b00000100 :      
                              (!rd_wp_dt_req_empty  &&  (pend_channel_cnt[4*4-1:3*4] == 4'b0)) ? 8'b00001000 :      
                              8'b00000000;    
        end
        8'b00010000: begin
            qv_next_channel = (!rd_ceu_req_empty    &&  (pend_channel_cnt[1*4-1:0*4] == 4'b0)) ? 8'b00000001 : 
                              (!rd_rrc_req_empty    &&  (pend_channel_cnt[6*4-1:5*4] == 4'b0)) ? 8'b00100000 :      
                              (!rd_rqwqe_req_empty  &&  (pend_channel_cnt[7*4-1:6*4] == 4'b0)) ? 8'b01000000 :      
                              (!rd_ee_req_empty     &&  (pend_channel_cnt[8*4-1:7*4] == 4'b0)) ? 8'b10000000 : 
                              (!rd_dbp_req_empty    &&  (pend_channel_cnt[2*4-1:1*4] == 4'b0)) ? 8'b00000010 :  
                              (!rd_wp_wqe_req_empty &&  (pend_channel_cnt[3*4-1:2*4] == 4'b0)) ? 8'b00000100 :      
                              (!rd_wp_dt_req_empty  &&  (pend_channel_cnt[4*4-1:3*4] == 4'b0)) ? 8'b00001000 :      
                              (!rd_rtc_req_empty    &&  (pend_channel_cnt[5*4-1:4*4] == 4'b0)) ? 8'b00010000 :      
                              8'b00000000;    
        end
        8'b00100000: begin
            qv_next_channel = (!rd_ceu_req_empty    &&  (pend_channel_cnt[1*4-1:0*4] == 4'b0)) ? 8'b00000001 : 
                              (!rd_rqwqe_req_empty  &&  (pend_channel_cnt[7*4-1:6*4] == 4'b0)) ? 8'b01000000 :      
                              (!rd_ee_req_empty     &&  (pend_channel_cnt[8*4-1:7*4] == 4'b0)) ? 8'b10000000 : 
                              (!rd_dbp_req_empty    &&  (pend_channel_cnt[2*4-1:1*4] == 4'b0)) ? 8'b00000010 :  
                              (!rd_wp_wqe_req_empty &&  (pend_channel_cnt[3*4-1:2*4] == 4'b0)) ? 8'b00000100 :      
                              (!rd_wp_dt_req_empty  &&  (pend_channel_cnt[4*4-1:3*4] == 4'b0)) ? 8'b00001000 :      
                              (!rd_rtc_req_empty    &&  (pend_channel_cnt[5*4-1:4*4] == 4'b0)) ? 8'b00010000 :      
                              (!rd_rrc_req_empty    &&  (pend_channel_cnt[6*4-1:5*4] == 4'b0)) ? 8'b00100000 :      
                              8'b00000000;    
        end
        8'b01000000: begin
            qv_next_channel = (!rd_ceu_req_empty    &&  (pend_channel_cnt[1*4-1:0*4] == 4'b0)) ? 8'b00000001 : 
                              (!rd_ee_req_empty     &&  (pend_channel_cnt[8*4-1:7*4] == 4'b0)) ? 8'b10000000 : 
                              (!rd_dbp_req_empty    &&  (pend_channel_cnt[2*4-1:1*4] == 4'b0)) ? 8'b00000010 :  
                              (!rd_wp_wqe_req_empty &&  (pend_channel_cnt[3*4-1:2*4] == 4'b0)) ? 8'b00000100 :      
                              (!rd_wp_dt_req_empty  &&  (pend_channel_cnt[4*4-1:3*4] == 4'b0)) ? 8'b00001000 :      
                              (!rd_rtc_req_empty    &&  (pend_channel_cnt[5*4-1:4*4] == 4'b0)) ? 8'b00010000 :      
                              (!rd_rrc_req_empty    &&  (pend_channel_cnt[6*4-1:5*4] == 4'b0)) ? 8'b00100000 :
                              (!rd_rqwqe_req_empty  &&  (pend_channel_cnt[7*4-1:6*4] == 4'b0)) ? 8'b01000000 :      
                              8'b00000000;    
        end
        8'b10000000: begin
            qv_next_channel = (!rd_ceu_req_empty    &&  (pend_channel_cnt[1*4-1:0*4] == 4'b0)) ? 8'b00000001 : 
                              (!rd_dbp_req_empty    &&  (pend_channel_cnt[2*4-1:1*4] == 4'b0)) ? 8'b00000010 :  
                              (!rd_wp_wqe_req_empty &&  (pend_channel_cnt[3*4-1:2*4] == 4'b0)) ? 8'b00000100 :      
                              (!rd_wp_dt_req_empty  &&  (pend_channel_cnt[4*4-1:3*4] == 4'b0)) ? 8'b00001000 :      
                              (!rd_rtc_req_empty    &&  (pend_channel_cnt[5*4-1:4*4] == 4'b0)) ? 8'b00010000 :      
                              (!rd_rrc_req_empty    &&  (pend_channel_cnt[6*4-1:5*4] == 4'b0)) ? 8'b00100000 :
                              (!rd_rqwqe_req_empty  &&  (pend_channel_cnt[7*4-1:6*4] == 4'b0)) ? 8'b01000000 :      
                              (!rd_ee_req_empty     &&  (pend_channel_cnt[8*4-1:7*4] == 4'b0)) ? 8'b10000000 : 
                              8'b00000000;    
        end
        default: qv_next_channel = 8'b0;
    endcase    
end


// assign new_selected_channel = qv_selected_channel;
//valid: compare the selected_channel with the
// assign new_selected_channel = (qv_selected_channel[CHANNEL_WIDTH-1] && (qv_selected_channel[CHANNEL_WIDTH-2:0] == qv_next_channel) && (lookup_ram_cnt == 0)) ? qv_selected_channel :  (qv_selected_channel[CHANNEL_WIDTH-1] && ((qv_selected_channel[CHANNEL_WIDTH-2:0] != qv_next_channel) || (lookup_ram_cnt != 0))) ?  {1'b0,qv_selected_channel[CHANNEL_WIDTH-2:0]} : qv_selected_channel;

assign new_selected_channel = (qv_selected_channel[CHANNEL_WIDTH-1] && (qv_selected_channel[CHANNEL_WIDTH-2:0] == qv_next_channel) && (lookup_ram_cnt == 0)) ? qv_selected_channel : 
    (qv_selected_channel[CHANNEL_WIDTH-1] && ((qv_selected_channel[CHANNEL_WIDTH-2:0] == qv_next_channel) && (lookup_ram_cnt != 0))) ? {1'b0,qv_selected_channel[CHANNEL_WIDTH-2:0]} :
    (qv_selected_channel[CHANNEL_WIDTH-1] && ((qv_selected_channel[CHANNEL_WIDTH-2:0] != qv_next_channel) || (lookup_ram_cnt == 0))) ? {1'b1,qv_next_channel} : qv_selected_channel;
//------------------qv_selected_channel-------------------
//| bit |        Description           |
//|-----|------------------------------|
//|  0  |   CEU                        |
//|  1  |   Doorbell Processing(WQE)   |
//|  2  |   WQE Parser(WQE）           |
//|  3  |   WQE Parser(DATA)           |
//|  4  |   RequesterTransControl(CQ)  |
//|  5  |   RequesterRecvControl(DATA) |
//|  6  |   Execution Engine(RQ WQE)   |
//|  7  |   Execution Engine(DATA)     |
//|  8  |   Ready                      |

always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_selected_channel[CHANNEL_WIDTH-2:0] <= `TD 8'b0;
        qv_selected_channel[CHANNEL_WIDTH-1]   <= `TD 1'b0; //not ready
    end
    /*VCS Verification*/  
    // else if ((old_selected_channel[CHANNEL_WIDTH-1] == 0) && (qv_next_channel != 0)) begin
    //     qv_selected_channel <= `TD {1'b1,qv_next_channel};
    // end
    // else if ((old_selected_channel[CHANNEL_WIDTH-1] == 0) && (qv_next_channel == 0)) begin
    //     qv_selected_channel <= `TD {1'b0,old_selected_channel[CHANNEL_WIDTH-2:0]};
    // end
    else if ((old_selected_channel[CHANNEL_WIDTH-1] == 0) && (qv_next_channel != 0) && (q_state_rd_delay2 | !rd_ceu_req_empty) && !mpt_rsp_stall) begin
        qv_selected_channel <= `TD {1'b1,qv_next_channel};
    end
    /*Action = Modify*/ 
    //check mpt_ram_ctl read lookup state from mpt_ram 
    //  1) if read enable, delay 2 clk to get the new pend_channel_cnt value to selecte next channel
    //  2) if !rd_ceu_req_empty,  selecte next channel directly
    else if ((old_selected_channel[CHANNEL_WIDTH-1] == 0) && (qv_next_channel == 0)) begin
        qv_selected_channel <= `TD {1'b0,old_selected_channel[CHANNEL_WIDTH-2:0]};
    end
    else begin
        qv_selected_channel <= `TD old_selected_channel;
    end
end


`ifdef V2P_DUG
    // /*****************Add for APB-slave regs**********************************/ 
        // reg [CHANNEL_WIDTH-2:0] qv_next_channel; 
        // reg    [CHANNEL_WIDTH-1 : 0] qv_selected_channel;
        // reg q_state_rd_delay1;
        // reg q_state_rd_delay2;        
    /*****************Add for APB-slave wires**********************************/         
        // wire  rd_ceu_req_empty,
        // wire  rd_dbp_req_empty,
        // wire  rd_wp_wqe_req_empty,
        // wire  rd_wp_dt_req_empty,
        // wire  rd_rtc_req_empty,
        // wire  rd_rrc_req_empty,
        // wire  rd_rqwqe_req_empty,
        // wire  rd_ee_req_empty,
        // wire state_rd_en,
        // wire  [PEND_CNT_WIDTH-1 :0] pend_channel_cnt,
        // wire  [CHANNEL_WIDTH-1 :0]  new_selected_channel,
        // wire   [CHANNEL_WIDTH-1 :0]   old_selected_channel,
        // wire          mpt_rsp_stall,
        // wire [2:0] lookup_ram_cnt
        
    //Total regs and wires : 2797 + 1895 = 4692 = 32 * 146 + 20. bit align 147

    assign wv_dbg_bus_reqsch = {
        14'b0,
        qv_next_channel,
        qv_selected_channel,
        q_state_rd_delay1,
        q_state_rd_delay2,

        rd_ceu_req_empty,
        rd_dbp_req_empty,
        rd_wp_wqe_req_empty,
        rd_wp_dt_req_empty,
        rd_rtc_req_empty,
        rd_rrc_req_empty,
        rd_rqwqe_req_empty,
        rd_ee_req_empty,
        state_rd_en,
        pend_channel_cnt,
        new_selected_channel,
        old_selected_channel,
        mpt_rsp_stall,
        lookup_ram_cnt  
    };

`endif 

endmodule