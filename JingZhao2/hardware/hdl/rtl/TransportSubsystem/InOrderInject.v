/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       InOrderInject
Author:     YangFan
Function:   Send Packet from ULP.
            Transport subsystem does not care about packet type(RC/UC/UD req/resp), it focuses on packet order.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "ib_constant_def_h.vh"
`include "common_function_def.vh"
`include "transport_subsystem_def.vh"
`include "global_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module InOrderInject (
    input   wire                                                            clk,
    input   wire                                                            rst,

//Packet-In
    input   wire                                                            i_packet_in_valid,
    input   wire        [`PKT_HEAD_WIDTH - 1 : 0]                           iv_packet_in_head,
    input   wire        [`PKT_DATA_WIDTH - 1 : 0]                           iv_packet_in_data,
    input   wire                                                            i_packet_in_start,
    input   wire                                                            i_packet_in_last,
    output  reg                                                             o_packet_in_ready,

//NPSN control
    output  reg                                                             o_npsn_wr_en,
    output  reg         [`QP_NUM_LOG - 1 : 0]                               ov_npsn_wr_index,
    output  reg         [`PSN_WIDTH - 1 : 0]                                ov_npsn_wr_data,
    output  wire        [`QP_NUM_LOG - 1 : 0]                               ov_npsn_rd_index,
    input   wire        [`PSN_WIDTH - 1 : 0]                                iv_npsn_rd_data,

//Interface with SendBufferMgt(Enqueue Packet)
    //No need for ready signal
    input   wire        [`SEND_BUFFER_SLOT_NUM_LOG - 1 : 0]                 iv_available_slot_num,
    output  reg                                                             o_insert_req_valid,
    output  reg         [`PKT_HEAD_WIDTH - 1 : 0]                           ov_insert_req_head,
    output  reg         [`PKT_DATA_WIDTH - 1 : 0]                           ov_insert_req_data,
    output  reg                                                             o_insert_req_start,
    output  reg                                                             o_insert_req_last,
    input   wire                                                            i_insert_req_ready,

//Interface with TimerControl
    output  reg                                                             o_tc_wr_en,
    output  reg         [`TIMER_CMD_WIDTH - 1 : 0]                          ov_tc_din,
    input   wire                                                            i_tc_prog_full,

//Packet-Out
    output  reg                                                             o_packet_out_valid,
    output  reg         [`PKT_HEAD_WIDTH - 1 : 0]                           ov_packet_out_head,
    output  reg         [`PKT_DATA_WIDTH - 1 : 0]                           ov_packet_out_data,
    output  reg                                                             o_packet_out_start,
    output  reg                                                             o_packet_out_last,
    input   wire                                                            i_packet_out_ready

);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                    [31:0]                      wv_payload_len;
wire                    [2:0]                       wv_service_type;

reg                     [23:0]                      qv_qpn;
wire                    [31:0]                      wv_slot_required;
reg                     [31:0]                      qv_slot_required;

reg                                                 q_insert_header;

/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
//Null
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/


/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg             [2:0]               ioi_cur_state;
reg             [2:0]               ioi_next_state;

parameter       [2:0]               IOI_IDLE_s = 4'd1,
                                    IOI_UNRELIABLE_s = 4'd2,
                                    IOI_RELIABLE_s = 4'd3;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        ioi_cur_state <= IOI_IDLE_s;
    end
    else begin
        ioi_cur_state <= ioi_next_state;
    end
end

always @(*) begin
    case(ioi_cur_state) 
        IOI_IDLE_s:                  if(i_packet_in_valid) begin
                                        if(wv_service_type == `RC && (wv_slot_required <= iv_available_slot_num)) begin
                                            ioi_next_state = IOI_RELIABLE_s;
                                        end
                                        else if(wv_service_type == `UC || wv_service_type == `UD) begin
                                            ioi_next_state = IOI_UNRELIABLE_s;
                                        end
                                        else begin
                                            ioi_next_state = IOI_IDLE_s;
                                        end
                                    end
                                    else begin
                                        ioi_next_state = IOI_IDLE_s;
                                    end 
        IOI_UNRELIABLE_s:            if(i_packet_in_valid && i_packet_in_last && i_packet_out_ready) begin
                                        ioi_next_state = IOI_IDLE_s;
                                    end
                                    else begin
                                        ioi_next_state = IOI_UNRELIABLE_s;
                                    end
        IOI_RELIABLE_s:              if(i_packet_in_valid && i_packet_in_last && i_packet_out_ready && !i_tc_prog_full) begin
                                        ioi_next_state = IOI_IDLE_s;
                                    end
                                    else begin
                                        ioi_next_state = IOI_RELIABLE_s;
                                    end
        default:                    ioi_next_state = IOI_IDLE_s;
    endcase
end

/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- wv_payload_len --
assign wv_payload_len = iv_packet_in_head[`PAYLOAD_LENGTH_OFFSET];

//-- wv_slot_required --
assign wv_slot_required = (wv_payload_len[5:0] ? (wv_payload_len >> 6) + 1 : (wv_payload_len >> 6)) + 'd1;  //+1 for packet header

//-- wv_service_type --
assign wv_service_type = iv_packet_in_head[`SERVICE_TYPE_OFFSET];

//-- qv_qpn --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_qpn <= 'd0;
    end
    else if(ioi_cur_state == IOI_IDLE_s) begin
        qv_qpn <= i_packet_in_valid ? iv_packet_in_head[`QPN_OFFSET] : 'd0;
    end
    else begin
        qv_qpn <= qv_qpn;
    end
end

//-- qv_slot_required --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_slot_required <= 'd0;
    end
    else if(ioi_cur_state == IOI_IDLE_s && i_packet_in_valid) begin
        qv_slot_required <= (wv_service_type == `RC) ? wv_slot_required : 'd0;     //+1 to store packet header
    end
    else if(ioi_cur_state == IOI_RELIABLE_s && (qv_slot_required <= iv_available_slot_num) && i_packet_in_valid && o_packet_in_ready) begin
        qv_slot_required <= (qv_slot_required > 0) ? qv_slot_required - 'd1 : 'd0;
    end
    else begin
        qv_slot_required <= qv_slot_required;
    end
end

//-- q_insert_header --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_insert_header <= 'd0;
    end
    else if(ioi_cur_state == IOI_IDLE_s && i_packet_in_valid && (wv_service_type == `RC) && (wv_slot_required <= iv_available_slot_num)) begin
        q_insert_header <= 'd1;
    end
    else if(ioi_cur_state == IOI_RELIABLE_s && q_insert_header && i_insert_req_ready) begin
        q_insert_header <= 'd0;
    end
    else begin
        q_insert_header <= q_insert_header;
    end
end

//-- o_packet_in_ready --
always @(*) begin
    if(rst) begin 
        o_packet_in_ready = 'd0;
    end
    else if(ioi_cur_state == IOI_UNRELIABLE_s) begin
        o_packet_in_ready = i_packet_out_ready;
    end
    else if(ioi_cur_state == IOI_RELIABLE_s) begin
        if(q_insert_header) begin
            o_packet_in_ready = 'd0;
        end
        else if(i_packet_in_last) begin
            o_packet_in_ready = !i_tc_prog_full && i_packet_out_ready && i_insert_req_ready;
        end
        else begin
            o_packet_in_ready = i_packet_out_ready && i_insert_req_ready;
        end
    end
    else begin
        o_packet_in_ready = 'd0;
    end
end


//-- o_npsn_wr_en --
//-- ov_npsn_wr_index --
//-- ov_npsn_wr_data --
always @(*) begin
    if(rst) begin
        o_npsn_wr_en = 'd0;
        ov_npsn_wr_index = 'd0;
        ov_npsn_wr_data = 'd0;
    end
    else if((ioi_cur_state == IOI_UNRELIABLE_s || ioi_cur_state == IOI_RELIABLE_s) && i_packet_in_valid && i_packet_in_last && i_packet_out_ready && !i_tc_prog_full) begin
        o_npsn_wr_en = 'd1;
        ov_npsn_wr_index = qv_qpn;
        ov_npsn_wr_data = iv_npsn_rd_data + 'd1;
    end
    else begin
        o_npsn_wr_en = 'd0;
        ov_npsn_wr_index = 'd0;
        ov_npsn_wr_data = 'd0;
    end
end

//-- ov_npsn_rd_index --
assign ov_npsn_rd_index = (ioi_cur_state == IOI_IDLE_s) ? iv_packet_in_head[`SRC_QPN_OFFSET] : qv_qpn;

//-- o_insert_req_valid --
//-- ov_insert_req_head --
//-- ov_insert_req_data --
//-- o_insert_req_start --
//-- o_insert_req_last --
always @(*) begin
    if(rst) begin
        o_insert_req_valid = 'd0;
        ov_insert_req_head = 'd0;
        ov_insert_req_data = 'd0;
        o_insert_req_start = 'd0;
        o_insert_req_last = 'd0;
    end
    else if(ioi_cur_state == IOI_RELIABLE_s) begin
        o_insert_req_valid = q_insert_header ? i_packet_in_valid : (i_packet_in_valid && i_packet_out_ready && i_insert_req_ready);
        ov_insert_req_head = q_insert_header ? {qv_slot_required, iv_npsn_rd_data, qv_qpn} : 'd0;
        ov_insert_req_data = q_insert_header ? {240'd0, (iv_npsn_rd_data), iv_packet_in_head[247:8], iv_packet_in_head[7:0] + 8'd3} : iv_packet_in_data;
        o_insert_req_start = q_insert_header ? i_packet_in_start : 'd0;
        o_insert_req_last = q_insert_header ? 'd0 : i_packet_in_last;
    end
    else begin
        o_insert_req_valid = 'd0;
        ov_insert_req_head = 'd0;
        ov_insert_req_data = 'd0;
        o_insert_req_start = 'd0;
        o_insert_req_last = 'd0;
    end
end

//-- o_tc_wr_en --
//-- ov_tc_din --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        o_tc_wr_en <= 'd0;
        ov_tc_din <= 'd0;
    end
    else if((ioi_cur_state == IOI_RELIABLE_s) && i_packet_in_valid && i_packet_in_last) begin
        o_tc_wr_en <= 'd1;
        ov_tc_din <= {`START_TIMER, qv_qpn};       
    end
    else begin
        o_tc_wr_en <= 'd0;
        ov_tc_din <= 'd0;
    end
end

//-- o_packet_out_valid --
//-- ov_packet_out_head --
//-- ov_packet_out_data --
//-- o_packet_out_start --
//-- o_packet_out_last --
always @(*) begin
    if(rst) begin
        o_packet_out_valid = 'd0;
        ov_packet_out_head = 'd0;
        ov_packet_out_data = 'd0;
        o_packet_out_start = 'd0;
        o_packet_out_last = 'd0;
    end
    else if(ioi_cur_state == IOI_RELIABLE_s || ioi_cur_state == IOI_UNRELIABLE_s) begin
        //Here we must synchronize packet out and insert, it may incur combination loop, hence we add several stream_reg.
        o_packet_out_valid = q_insert_header ? 'd0 : (i_packet_in_valid && i_packet_out_ready && i_insert_req_ready);
        ov_packet_out_head = o_packet_out_start ? {240'd0, (iv_npsn_rd_data), iv_packet_in_head[247:8], iv_packet_in_head[7:0] + 8'd3} : 'd0;    //Append PSN
        ov_packet_out_data = o_packet_out_valid ? iv_packet_in_data : 'd0;
        o_packet_out_start = q_insert_header ? 'd0 : i_packet_in_start;
        o_packet_out_last = q_insert_header ? 'd0 : i_packet_in_last;
    end
    else begin
        o_packet_out_valid = 'd0;
        ov_packet_out_head = 'd0;
        ov_packet_out_data = 'd0;
        o_packet_out_start = 'd0;
        o_packet_out_last = 'd0;
    end
end

/*------------------------------------------- Variables Decode : End ------------------------------------------------*/
endmodule