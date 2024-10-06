//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: request_controller.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V1.0 
// VERSION DESCRIPTION: 2st Edition  
//----------------------------------------------------
// RELEASE DATE: 2022-08-31 
//---------------------------------------------------- 
// PURPOSE: schedule the key_qpc_data request from ceu_parser and 6 RDMA engine submodule
//          priority: ceu_parser has the top priority; 6 RDMA engine submodule req RoundRobin
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
// 
//-FHDR-----------------------------------------------

//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_ctxmgt_h.vh"

module request_controller(
    input  wire  clk,
    input  wire  rst,

    //these signals from the rd_req_empty singal of CEU, and other 5 reqs from RDMA Engine submodule
    input  wire  rd_ceu_req_empty,
    input  wire  rd_dbp_req_empty,
    input  wire  rd_wp_wqe_req_empty,
    input  wire  rd_rtc_req_empty,
    input  wire  rd_rrc_req_empty,
    input  wire  rd_ee_req_empty,
    input  wire  rd_fe_req_empty,

    //req_scheduler changes the value of Selected Channel Reg to mark the selected channel,key_qpc_data moduel read the info
    output reg  [7 :0]  selected_channel,
    //receive signal from key_qpc_data module indicate that key_qpc_data module has received the req from selected_channel fifo
    input  wire receive_req
    `ifdef CTX_DUG
        /*Interface with APB Slave*/
	    // ,input 	wire		[`CXTMGT_RW_REG_NUM * 32 - 1 : 0] 		Rw_data
	    // ,output wire 		[`CXTMGT_RO_REG_NUM * 32 - 1 : 0] 		Ro_data
	    , output wire 	[`REQCTL_DBG_REG_NUM * 32 -1:0]		wv_dbg_bus_6
    `endif
    
);

//-------------------- Output Decode--------------------
reg [6:0] qv_next_channel; 
//compute the next channel, 000001-000010-000100-001000-010000-100000
//ceu has the top priority, use RoundRobin to update selected channel reg, depending on 
// the last selected channel, the request FIFO empty signal, and the pend channel count reg
always @(*) begin
    if (rst) begin
        qv_next_channel = 0;
    end else begin
            case (selected_channel[6:0])
            7'b0000000: begin
                qv_next_channel = (!rd_ceu_req_empty   ) ? 7'b0000001 : 
                                  (!rd_dbp_req_empty   ) ? 7'b0000010 : 
                                  (!rd_wp_wqe_req_empty) ? 7'b0000100 : 
                                  (!rd_rtc_req_empty   ) ? 7'b0001000 : 
                                  (!rd_rrc_req_empty   ) ? 7'b0010000 : 
                                  (!rd_ee_req_empty    ) ? 7'b0100000 : 
                                  (!rd_fe_req_empty    ) ? 7'b1000000 : 7'b0000000;    
            end
            7'b0000001: begin
                qv_next_channel = (!rd_ceu_req_empty   ) ? 7'b0000001 : 
                                  (!rd_dbp_req_empty   ) ? 7'b0000010 : 
                                  (!rd_wp_wqe_req_empty) ? 7'b0000100 : 
                                  (!rd_rtc_req_empty   ) ? 7'b0001000 : 
                                  (!rd_rrc_req_empty   ) ? 7'b0010000 : 
                                  (!rd_ee_req_empty    ) ? 7'b0100000 :   
                                  (!rd_fe_req_empty    ) ? 7'b1000000 : 7'b0000000;    
            end
            7'b0000010: begin
                qv_next_channel = (!rd_ceu_req_empty   ) ? 7'b0000001 : 
                                  (!rd_wp_wqe_req_empty) ? 7'b0000100 :      
                                  (!rd_rtc_req_empty   ) ? 7'b0001000 :      
                                  (!rd_rrc_req_empty   ) ? 7'b0010000 :      
                                  (!rd_ee_req_empty    ) ? 7'b0100000 :   
                                  (!rd_fe_req_empty    ) ? 7'b1000000 :     
                                  (!rd_dbp_req_empty   ) ? 7'b0000010 :  7'b0000000;    
            end
            7'b0000100: begin
                qv_next_channel = (!rd_ceu_req_empty   ) ? 7'b0000001 : 
                                  (!rd_rtc_req_empty   ) ? 7'b0001000 :      
                                  (!rd_rrc_req_empty   ) ? 7'b0010000 :      
                                  (!rd_ee_req_empty    ) ? 7'b0100000 :   
                                  (!rd_fe_req_empty    ) ? 7'b1000000 :     
                                  (!rd_dbp_req_empty   ) ? 7'b0000010 : 
                                  (!rd_wp_wqe_req_empty) ? 7'b0000100 :  7'b0000000;    
            end  
            7'b0001000: begin
                qv_next_channel = (!rd_ceu_req_empty   ) ? 7'b0000001 : 
                                  (!rd_rrc_req_empty   ) ? 7'b0010000 :      
                                  (!rd_ee_req_empty    ) ? 7'b0100000 :   
                                  (!rd_fe_req_empty    ) ? 7'b1000000 :     
                                  (!rd_dbp_req_empty   ) ? 7'b0000010 :  
                                  (!rd_wp_wqe_req_empty) ? 7'b0000100 :      
                                  (!rd_rtc_req_empty   ) ? 7'b0001000 :  7'b0000000;    
            end
            7'b0010000: begin
                qv_next_channel = (!rd_ceu_req_empty    ) ? 7'b0000001 : 
                                  (!rd_ee_req_empty     ) ? 7'b0100000 :  
                                  (!rd_fe_req_empty     ) ? 7'b1000000 :      
                                  (!rd_dbp_req_empty    ) ? 7'b0000010 : 
                                  (!rd_wp_wqe_req_empty ) ? 7'b0000100 :  
                                  (!rd_rtc_req_empty    ) ? 7'b0001000 :      
                                  (!rd_rrc_req_empty    ) ? 7'b0010000 : 7'b0000000;    
            end
            7'b0100000: begin
                qv_next_channel = (!rd_ceu_req_empty   ) ? 7'b0000001 :  
                                  (!rd_fe_req_empty    ) ? 7'b1000000 : 
                                  (!rd_dbp_req_empty   ) ? 7'b0000010 :  
                                  (!rd_wp_wqe_req_empty) ? 7'b0000100 :      
                                  (!rd_rtc_req_empty   ) ? 7'b0001000 :      
                                  (!rd_rrc_req_empty   ) ? 7'b0010000 :      
                                  (!rd_ee_req_empty    ) ? 7'b0100000 : 7'b0000000;    
            end
            7'b1000000: begin
                qv_next_channel = (!rd_ceu_req_empty   ) ? 7'b0000001 : 
                                  (!rd_dbp_req_empty   ) ? 7'b0000010 :  
                                  (!rd_wp_wqe_req_empty) ? 7'b0000100 :      
                                  (!rd_rtc_req_empty   ) ? 7'b0001000 :      
                                  (!rd_rrc_req_empty   ) ? 7'b0010000 :      
                                  (!rd_ee_req_empty    ) ? 7'b0100000 : 
                                  (!rd_fe_req_empty    ) ? 7'b1000000 :  7'b0000000;
            end
            default: qv_next_channel = 7'b0;
        endcase
    end
    
end

//------------------selected_channel-------------------
//| bit |        Description           |
//|-----|------------------------------|
//|  0  |   CEU                        |
//|  1  |   Doorbell Processing(DBP)   |
//|  2  |   WQE Parser(WP）            |
//|  3  |   RequesterTransControl(RTC) |
//|  4  |   RequesterRecvControl(RRC)  |
//|  5  |   Execution Engine(EE)       |
//|  6  |   Frame Encap(FE)            |
//|  7  |    valid                     |
always @(posedge clk or posedge rst) begin
    if (rst) begin
        selected_channel[6:0] <= `TD  7'b0;
        selected_channel[7]   <= `TD  1'b0; //not valid
    end
    //key_qpc_data has received the selected channel fifo req, and new selected channel is ready, update selected_channel reg and valid seg
    else if (receive_req && selected_channel[7] && (qv_next_channel != 0)) begin
        selected_channel <= `TD  {1'b1,qv_next_channel};
    end
    //key_qpc_data has received the selected channel fifo req, and new selected channel is not ready, keep selected_channel reg and reset the valid seg
    else if (receive_req && (qv_next_channel == 0)) begin
        selected_channel <= `TD  {1'b0,selected_channel[6:0]};
    end
    //selected channel reg is not valid, and new selected channel is ready, update selected_channel reg and valid seg
    else if ((selected_channel[7] == 0) && (qv_next_channel != 0)) begin
        selected_channel <= `TD  {1'b1,qv_next_channel};
    end
    else begin
        selected_channel <= `TD  selected_channel;
    end
end

`ifdef CTX_DUG
    // /*****************Add for APB-slave regs**********************************/ 
    // reg [7 :0]  selected_channel,
    // reg [6:0] qv_next_channel;

    //total regs count = 15

    // /*****************Add for APB-slave wires**********************************/ 
    // wire  clk,
    // wire  rst,
    // wire  rd_ceu_req_empty,
    // wire  rd_dbp_req_empty,
    // wire  rd_wp_wqe_req_empty,
    // wire  rd_rtc_req_empty,
    // wire  rd_rrc_req_empty,
    // wire  rd_ee_req_empty,
    // wire  rd_fe_req_empty,
    // wire receive_req

    //total wires count = 10
    //Total regs and wires :25. bit align 1

    assign wv_dbg_bus_6 = {
        8'b0,
        selected_channel,
        qv_next_channel,
        //clk,
        rst,
        rd_ceu_req_empty,
        rd_dbp_req_empty,
        rd_wp_wqe_req_empty,
        rd_rtc_req_empty,
        rd_rrc_req_empty,
        rd_ee_req_empty,
        rd_fe_req_empty,
        receive_req
    };
`endif 

endmodule
