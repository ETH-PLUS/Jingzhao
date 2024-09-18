		/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       RespTransCore_Thread_1
Author:     YangFan
Function:   1.Generate DMA Read for RDMA Read Resp.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module RespTransCore_Thread_1
(
    input   wire                                                            clk,
    input   wire                                                            rst,

//Interface with ReqRecvCore
    output  wire                                                            net_resp_ren,
    input   wire                               								net_resp_empty,
    input   wire     [`NET_REQ_META_WIDTH - 1 : 0]                          net_resp_dout,

//Interface with Gather Data
    input   wire                                                            payload_empty,
    input   wire    [511:0]                                                 payload_data,
    output  wire                                                            payload_ren,

//Interface with Payload Buffer
    output  wire                                                            insert_req_valid,
    output  wire                                                            insert_req_start,
    output  wire                                                            insert_req_last,
    output  wire    [`PACKET_BUFFER_SLOT_NUM_LOG - 1 : 0]                   insert_req_head,
    output  wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]                     insert_req_data,
    input   wire                                                            insert_req_ready,

    input   wire                                                            insert_resp_valid,
    input   wire    [`PACKET_BUFFER_SLOT_NUM_LOG - 1 : 0]                   insert_resp_data,

//Interface with TransportSubsystem
    output  wire                                                            egress_pkt_valid,
    output  wire    [`PKT_META_BUS_WIDTH - 1 : 0]                           egress_pkt_head,
    input   wire                                                            egress_pkt_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define                     NET_LOCAL_QPN_OFFSET                            23:0
`define                     NET_REMOTE_QPN_OFFSET                           55:32
`define                     NET_OPCODE_OFFSET                               60:56
`define                     NET_SERVICE_TYPE_OFFSET                         63:61
`define                     NET_DMAC_OFFSET                                 111:64
`define                     NET_SMAC_OFFSET                                 159:112
`define                     NET_DIP_OFFSET                                  191:160
`define                     NET_SIP_OFFSET                                  223:192
`define                     NET_PKT_LENGTH_OFFSET                           255:224
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg                         [`NET_REQ_META_WIDTH - 1 : 0]                   net_resp_bus;

wire                        [4:0]                                           net_opcode;
wire                        [15:0]                                          net_pkt_length;

reg                         [31:0]                                          payload_piece_count;
reg                         [31:0]                                          payload_piece_total;

reg                         [`MAX_DB_SLOT_NUM_LOG - 1:0]                                          pkt_start_addr;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg                 [2:0]           cur_state;
reg                 [2:0]           next_state;

parameter           [2:0]           IDLE_s      = 3'd1,
                                    JUDGE_s     = 3'd2,
                                    INSERT_s    = 3'd3,
                                    INJECT_s    = 3'd4;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        cur_state <= IDLE_s;
    end
    else begin
        cur_state <= next_state;
    end
end

always @(*) begin
    case(cur_state)
        IDLE_s:             if(!net_resp_empty) begin
                                next_state = JUDGE_s;
                            end
                            else begin
                                next_state = IDLE_s;
                            end
        JUDGE_s:            if(net_opcode == `ACKNOWLEDGE) begin
                                next_state = INJECT_s;
                            end
                            else if(net_opcode == `RDMA_READ_RESPONSE_FIRST || net_opcode == `RDMA_READ_RESPONSE_MIDDLE || net_opcode == `RDMA_READ_RESPONSE_LAST ||
                                    net_opcode == `RDMA_READ_RESPONSE_ONLY) begin
                                next_state = INSERT_s;            
                            end
                            else begin
                                next_state = IDLE_s;
                            end
        INSERT_s:           if(!payload_empty && payload_piece_count == 'd1 && insert_req_valid && insert_req_ready && insert_resp_valid) begin
                                next_state = INJECT_s;
                            end
                            else begin
                                next_state = INSERT_s;
                            end
        INJECT_s:           if(egress_pkt_valid && egress_pkt_ready) begin
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = INJECT_s;
                            end
        default:            next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- net_resp_bus --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        net_resp_bus <= 'd0;        
    end
    else if (cur_state == IDLE_s && !net_resp_empty) begin
        net_resp_bus <= net_resp_dout;
    end
    else begin
        net_resp_bus <= net_resp_bus;
    end
end

//-- net_opcode --
//-- net_pkt_length --
assign net_opcode = net_resp_bus[`NET_OPCODE_OFFSET];
assign net_pkt_length = net_resp_bus[`NET_PKT_LENGTH_OFFSET];

//-- payload_piece_count --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        payload_piece_count <= 'd0;                
    end
    else if (cur_state == IDLE_s) begin
        payload_piece_count <= 'd0;
    end
    else if(cur_state == JUDGE_s) begin
        payload_piece_count <= net_pkt_length[5:0] ? (net_pkt_length >> 6) + 1 : net_pkt_length >> 6;
    end
    else if(cur_state == INSERT_s && !payload_empty && insert_req_valid && insert_req_ready) begin
        payload_piece_count <= payload_piece_count - 'd1;
    end
    else begin
        payload_piece_count <= payload_piece_count;
    end
end

//-- payload_piece_total --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        payload_piece_total <= 'd0;                
    end
    else if (cur_state == IDLE_s) begin
        payload_piece_total <= 'd0;
    end
    else if(cur_state == JUDGE_s) begin
        payload_piece_total <= net_pkt_length[5:0] ? (net_pkt_length >> 6) + 1 : net_pkt_length >> 6;
    end
    else begin
        payload_piece_total <= payload_piece_total;
    end
end

//-- pkt_start_addr --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        pkt_start_addr <= 'd0;
    end
    else if(cur_state == IDLE_s) begin
        pkt_start_addr <= 'd0;
    end
    else if(cur_state == INSERT_s && insert_req_start && insert_resp_valid) begin
        pkt_start_addr <= insert_resp_data;
    end
    else begin
        pkt_start_addr <= pkt_start_addr;
    end
end

//-- net_resp_ren --
assign net_resp_ren = (cur_state == IDLE_s) ? !net_resp_empty : 'd0;

//-- payload_ren --
assign payload_ren = (cur_state == INSERT_s) ? !payload_empty && insert_req_valid && insert_req_ready : 'd0;

//-- insert_req_valid --
//-- insert_req_start --
//-- insert_req_last --
//-- insert_req_head --
//-- insert_req_data --
assign insert_req_valid = (cur_state == INSERT_s && !payload_empty) ? 'd1 : 'd0;
assign insert_req_start = (cur_state == INSERT_s && !payload_empty) ? (payload_piece_total == payload_piece_count) : 'd0;
assign insert_req_last = (cur_state == INSERT_s && !payload_empty) ? (payload_piece_count == 'd1) : 'd0;
assign insert_req_head = (cur_state == INSERT_s && !payload_empty) ? (payload_piece_total) : 'd0;
assign insert_req_data = (cur_state == INSERT_s && !payload_empty) ? payload_data : 'd0;

//-- egress_pkt_valid --
//-- egress_pkt_head --
assign egress_pkt_valid = (cur_state == INJECT_s) ? 'd1 : 'd0;
assign egress_pkt_head = (cur_state == INJECT_s) ? {net_pkt_length, pkt_start_addr, net_resp_bus[`NET_SIP_OFFSET], net_resp_bus[`NET_DIP_OFFSET], net_resp_bus[`NET_SMAC_OFFSET],
                                                    net_resp_bus[`NET_DMAC_OFFSET], 136'd0, net_resp_bus[`NET_REMOTE_QPN_OFFSET], net_resp_bus[`NET_SERVICE_TYPE_OFFSET],
                                                    net_resp_bus[`NET_OPCODE_OFFSET], net_resp_bus[`NET_LOCAL_QPN_OFFSET]} : 'd0;
/*------------------------------------------- Variables Decode : End ----------------------------------------------***/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/

/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/

endmodule