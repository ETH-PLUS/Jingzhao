//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: selected_channel_ctl.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V2.0 
// VERSION DESCRIPTION: 1st Edition  
//----------------------------------------------------
// RELEASE DATE: 2021-12-24 
//---------------------------------------------------- 
// PURPOSE: control the selected_channel_reg, write the ready signal changed by both req_scheduler and MPT module.
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
// 
//-FHDR-----------------------------------------------

//---------------------------------------------------- 
`timescale 1ns / 1ps

`include "msg_def_v2p_h.vh"

module selected_channel_ctl#(
    // used for Selected Channel Reg to mark the selected channel and Ready, MPT/MTT module may read the info
    parameter CHANNEL_WIDTH = 9
    )(
    input   clk,
    input   rst,

    //req_scheduler changes the value of Selected Channel Reg to mark the selected channel, MPT/MTT module may read the info
    input wire    [CHANNEL_WIDTH-1 :0]  new_selected_channel,
    
    //MPT module set this signal, after MPT module read req from req_fifo
    input wire    req_read_already,

    //req_scheduler read the value of Selected Channel Reg to make decision
    //MPT read the selected_channel and read the req_fifo of different channels
    output wire   [CHANNEL_WIDTH-1 :0]  old_selected_channel

    `ifdef V2P_DUG
    //apb_slave
    ,  output wire [`CHCTL_DBG_REG_NUM * 32 - 1 : 0]   wv_dbg_bus_chctl
    `endif

);


//-------------------- Output Decode--------------------
reg    [CHANNEL_WIDTH-1 : 0]  qv_selected_channel;
/*VCS Verification*/
// assign old_selected_channel = qv_selected_channel;
assign old_selected_channel = qv_selected_channel & {!req_read_already,8'b11111111};
/*Action = Modify, add req_read_already singnal as combinatorial logic */
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
        qv_selected_channel <= `TD 0;
    end
    // else if (qv_selected_channel[CHANNEL_WIDTH-1] == 0) begin
    // else if ((qv_selected_channel[CHANNEL_WIDTH-1] == 0) && (new_selected_channel[CHANNEL_WIDTH-1] != 0)) begin
    else if ((qv_selected_channel[CHANNEL_WIDTH-1] == 0) && (new_selected_channel[CHANNEL_WIDTH-1] != 0) && (new_selected_channel[CHANNEL_WIDTH-2:0] != 0)) begin
        qv_selected_channel <= `TD new_selected_channel;
    end 
    else if ((qv_selected_channel[CHANNEL_WIDTH-1] == 1) && req_read_already) begin
        qv_selected_channel <= `TD {1'b0,qv_selected_channel[CHANNEL_WIDTH-2:0]};
    end
    else begin
        qv_selected_channel <= `TD qv_selected_channel;
    end
end


`ifdef V2P_DUG
    // /*****************Add for APB-slave regs**********************************/ 
        // reg    [CHANNEL_WIDTH-1 : 0]  qv_selected_channel;
    /*****************Add for APB-slave wires**********************************/         
        // input wire    [CHANNEL_WIDTH-1 :0]  new_selected_channel,
        // input wire    req_read_already,
        // output wire   [CHANNEL_WIDTH-1 :0]  old_selected_channel
    //Total regs and wires : 2797 + 1895 = 4692 = 32 * 146 + 20. bit align 147

    assign wv_dbg_bus_chctl = {
        4'b0000,
        qv_selected_channel,
        
        new_selected_channel,
        req_read_already,
        old_selected_channel
    };

`endif 

endmodule