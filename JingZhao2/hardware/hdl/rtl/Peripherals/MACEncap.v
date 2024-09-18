/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       PacketEncap
Author:     YangFan
Function:   In NIC/Switch processing pipeline, protocol processing requires frequent appending and removing header.
            This module abstracts the append process.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "common_function_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module MACEncap
(
    input   wire                                                    clk,
    input   wire                                                    rst,

    input   wire                                                    egress_pkt_valid,
    input   wire    [`PKT_META_BUS_WIDTH - 1 : 0]                   egress_pkt_head,
    output  wire                                                    egress_pkt_ready,

    output  wire                                                    delete_req_valid,
    output  wire    [`MAX_DB_SLOT_NUM_LOG * 2 - 1 : 0]              delete_req_head,
    input   wire                                                    delete_req_ready,
    
    input   wire                                                    delete_resp_valid,
    input   wire                                                    delete_resp_start,
    input   wire                                                    delete_resp_last,
    input   wire    [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]             delete_resp_data,
    output  wire                                                    delete_resp_ready,

    output  wire                                                    mac_tx_valid,
    input   wire                                                    mac_tx_ready,
    output  wire                                                    mac_tx_start,
    output  wire                                                    mac_tx_last,
    output  wire    [`MAC_KEEP_WIDTH - 1 : 0]                       mac_tx_keep,
    output  wire                                                    mac_tx_user,
    output  reg    [`MAC_DATA_WIDTH - 1 : 0]                        mac_tx_data
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     LOCAL_QPN_OFFSET            23:0
`define     OPCODE_OFFSET               28:24
`define     SERVICE_TYPE_OFFSET         31:29
`define     REMOTE_QPN_OFFSET           55:32
`define     RKEY_OFFSET                 95:64
`define     RADDR_OFFSET                159:96
`define     IMMEDIATE_OFFSET            191:160
`define     DMAC_OFFSET                 239:192
`define     SMAC_OFFSET                 287:240
`define     DIP_OFFSET                  319:288
`define     SIP_OFFSET                  351:320
`define     PAYLOAD_ADDR_OFFSET         367:352
`define     PAYLOAD_LENGTH_OFFSET       383:368
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire            [`MAC_HEADER_LENGTH * 8 - 1 : 0]                    mac_header;
wire            [`BTH_LENGTH * 8 - 1 : 0]                           bth;
wire            [`RETH_LENGTH * 8 - 1 : 0]                          reth;
wire            [`IMMETH_LENGTH * 8 - 1 : 0]                        immeth;
wire            [`AETH_LENGTH * 8 - 1 : 0]                          aeth;

wire            [23:0]                                          bth_local_qpn;
wire            [23:0]                                          bth_dst_qpn;
wire            [2:0]                                           bth_service_type;
wire            [4:0]                                           bth_opcode;
wire            [15:0]                                          bth_pkt_length;

wire            [63:0]                                          reth_raddr;
wire            [31:0]                                          reth_rkey;
wire            [31:0]                                          reth_dma_length;

wire            [23:0]                                          aeth_msn;
wire            [7:0]                                           aeth_syndrome;

reg             [`PKT_META_BUS_WIDTH - 1 : 0]                   pkt_header_bus;

reg             [15:0]                                          payload_left_length;
reg             [15:0]                                          unwritten_len;
reg             [511:0]                                         unwritten_data;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg             [2:0]                   cur_state;
reg             [2:0]                   next_state;

parameter       [2:0]                   IDLE_s              = 3'd1,
                                        DEL_s               = 3'd2,
                                        ZERO_PAYLOAD_ENCAP_s        = 3'd3,
                                        NON_ZERO_PAYLOAD_ENCAP_s    = 3'd4;


always @(posedge clk or posedge rst) begin
    if (rst) begin
        cur_state <= IDLE_s;        
    end
    else begin
        cur_state <= next_state;
    end
end

always @(*) begin
    case(cur_state)
        IDLE_s:             if(egress_pkt_valid) begin
                                if( egress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_REQUEST_FIRST ||
                                    egress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_REQUEST_MIDDLE || 
                                    egress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_REQUEST_LAST ||
                                    egress_pkt_head[`OPCODE_OFFSET] == `RDMA_READ_REQUEST_ONLY || egress_pkt_head[`OPCODE_OFFSET] == `ACKNOWLEDGE) begin
                                    next_state = ZERO_PAYLOAD_ENCAP_s;
                                end
                                else begin
                                    next_state = DEL_s;
                                end
                            end
                            else begin
                                next_state = IDLE_s;
                            end
        DEL_s:              if(delete_req_valid && delete_req_ready) begin
                                next_state = NON_ZERO_PAYLOAD_ENCAP_s;
                            end
                            else begin
                                next_state = ZERO_PAYLOAD_ENCAP_s;
                            end
        ZERO_PAYLOAD_ENCAP_s:       if(mac_tx_valid && mac_tx_ready) begin  //Only one cycle
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = ZERO_PAYLOAD_ENCAP_s;
                            end
        NON_ZERO_PAYLOAD_ENCAP_s:   if(payload_left_length + unwritten_len > 64) begin //Still need more cycles
                                next_state = NON_ZERO_PAYLOAD_ENCAP_s;
                            end
                            else if(payload_left_length > 0 && delete_resp_valid && mac_tx_ready) begin
                                next_state = IDLE_s;
                            end
                            else if(payload_left_length == 0 && mac_tx_ready) begin
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = NON_ZERO_PAYLOAD_ENCAP_s;
                            end
        default:            next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- pkt_header_bus --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        pkt_header_bus <= 'd0;        
    end
    else if (cur_state == IDLE_s && egress_pkt_valid) begin
        pkt_header_bus <= egress_pkt_head;
    end
    else begin
        pkt_header_bus <= pkt_header_bus;
    end
end

//-- bth --
assign bth = {bth_pkt_length, bth_dst_qpn, bth_opcode, bth_service_type, bth_local_qpn};

//-- reth --
assign reth = {reth_dma_length, reth_rkey, reth_raddr};

//-- immeth --
assign immeth = (cur_state == IDLE_s) ? egress_pkt_head[`IMMEDIATE_OFFSET] : pkt_header_bus[`IMMEDIATE_OFFSET];

//-- aeth --
assign aeth = 'd0;

//-- bth_local_qpn --
//-- bth_dst_qpn --
//-- bth_service_type --
//-- bth_opcode --
//-- bth_pkt_length --
assign bth_local_qpn = (cur_state == IDLE_s) ? egress_pkt_head[`LOCAL_QPN_OFFSET] : pkt_header_bus[`LOCAL_QPN_OFFSET];
assign bth_dst_qpn = (cur_state == IDLE_s) ? egress_pkt_head[`REMOTE_QPN_OFFSET] : pkt_header_bus[`REMOTE_QPN_OFFSET];
assign bth_service_type = (cur_state == IDLE_s) ? egress_pkt_head[`SERVICE_TYPE_OFFSET] : pkt_header_bus[`SERVICE_TYPE_OFFSET];
assign bth_opcode = (cur_state == IDLE_s) ? egress_pkt_head[`OPCODE_OFFSET] : pkt_header_bus[`OPCODE_OFFSET];
assign bth_pkt_length = (cur_state == IDLE_s) ? egress_pkt_head[`PAYLOAD_LENGTH_OFFSET] : pkt_header_bus[`PAYLOAD_LENGTH_OFFSET];

//-- reth_raddr --
//-- reth_rkey --
//-- reth_dma_length --
assign reth_raddr = (cur_state == IDLE_s) ? egress_pkt_head[`RADDR_OFFSET] : pkt_header_bus[`RADDR_OFFSET];
assign reth_rkey = (cur_state == IDLE_s) ? egress_pkt_head[`RKEY_OFFSET] : pkt_header_bus[`RKEY_OFFSET];
assign reth_dma_length = (cur_state == IDLE_s) ? egress_pkt_head[`PAYLOAD_LENGTH_OFFSET] : pkt_header_bus[`PAYLOAD_LENGTH_OFFSET];

//-- mac_header --
// assign mac_header = (cur_state == IDLE_s) ? {16'h0008, egress_pkt_head[`SMAC_OFFSET], egress_pkt_head[`DMAC_OFFSET]} : 
//                     {16'h0800, pkt_header_bus[`SMAC_OFFSET], pkt_header_bus[`DMAC_OFFSET]};

assign mac_header = (cur_state == IDLE_s) ? {16'h0008, 48'haabbccddeeff, 48'h112233445566} : 
                    {16'h0008, 48'haabbccddeeff, 48'h112233445566};

//-- payload_left_length --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        payload_left_length <= 'd0;        
    end
    else if (cur_state == IDLE_s && egress_pkt_valid) begin
        payload_left_length <= egress_pkt_head[`PAYLOAD_LENGTH_OFFSET];
    end
    else if(cur_state == ZERO_PAYLOAD_ENCAP_s) begin
        payload_left_length <= 'd0;
    end
    else if(cur_state == NON_ZERO_PAYLOAD_ENCAP_s) begin
        if(payload_left_length == 0) begin //Only unwritten_len left
            payload_left_length <= 'd0;
        end
        else if(payload_left_length > 0 && delete_resp_valid && mac_tx_ready) begin
            payload_left_length <= payload_left_length > 64 ? payload_left_length - 'd64 : 'd0;
        end
        else begin
            payload_left_length <= payload_left_length;
        end
    end
    else begin
        payload_left_length <= payload_left_length;
    end
end

//-- unwritten_len --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        unwritten_len <= 'd0;        
    end
    else if (cur_state == IDLE_s && egress_pkt_valid) begin
        case(egress_pkt_head[`OPCODE_OFFSET])
            `SEND_FIRST:                    unwritten_len <= `BTH_LENGTH + `MAC_HEADER_LENGTH;
            `SEND_MIDDLE:                   unwritten_len <= `BTH_LENGTH + `MAC_HEADER_LENGTH;
            `SEND_ONLY:                     unwritten_len <= `BTH_LENGTH + `MAC_HEADER_LENGTH;
            `SEND_LAST:                     unwritten_len <= `BTH_LENGTH + `MAC_HEADER_LENGTH;
            `SEND_ONLY_WITH_IMM:            unwritten_len <= `BTH_LENGTH + `IMMETH_LENGTH + `MAC_HEADER_LENGTH;
            `SEND_LAST_WITH_IMM:            unwritten_len <= `BTH_LENGTH + `MAC_HEADER_LENGTH;
            `RDMA_WRITE_FIRST:              unwritten_len <= `BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH;
            `RDMA_WRITE_MIDDLE:             unwritten_len <= `BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH;
            `RDMA_WRITE_LAST:               unwritten_len <= `BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH;
            `RDMA_WRITE_ONLY:               unwritten_len <= `BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH;
            `RDMA_WRITE_LAST_WITH_IMM:      unwritten_len <= `BTH_LENGTH + `RETH_LENGTH +`IMMETH_LENGTH + `MAC_HEADER_LENGTH;
            `RDMA_WRITE_ONLY_WITH_IMM:      unwritten_len <= `BTH_LENGTH + `RETH_LENGTH +`IMMETH_LENGTH + `MAC_HEADER_LENGTH;
            `RDMA_READ_REQUEST_FIRST:       unwritten_len <= `BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH;
            `RDMA_READ_REQUEST_MIDDLE:      unwritten_len <= `BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH;
            `RDMA_READ_REQUEST_LAST:        unwritten_len <= `BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH;
            `RDMA_READ_REQUEST_ONLY:        unwritten_len <= `BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH;
            `RDMA_READ_RESPONSE_FIRST:      unwritten_len <= `BTH_LENGTH + `MAC_HEADER_LENGTH;
            `RDMA_READ_RESPONSE_MIDDLE:     unwritten_len <= `BTH_LENGTH + `MAC_HEADER_LENGTH;
            `RDMA_READ_RESPONSE_LAST:       unwritten_len <= `BTH_LENGTH + `MAC_HEADER_LENGTH;
            `RDMA_READ_RESPONSE_ONLY:       unwritten_len <= `BTH_LENGTH + `MAC_HEADER_LENGTH;
            `ACKNOWLEDGE:                   unwritten_len <= `BTH_LENGTH + `AETH_LENGTH + `MAC_HEADER_LENGTH;
            default:                        unwritten_len <= 'd0;
        endcase
    end
    else if(cur_state == ZERO_PAYLOAD_ENCAP_s && mac_tx_ready) begin
        unwritten_len <= 'd0;
    end
    else if(cur_state == NON_ZERO_PAYLOAD_ENCAP_s) begin
        if(payload_left_length == 0) begin  //Last cycle transmit
            unwritten_len <= mac_tx_ready ? 'd0 : unwritten_len;
        end
        else if(payload_left_length > 0 && delete_resp_valid && mac_tx_ready) begin
            if(payload_left_length + unwritten_len <= 64) begin  //Last cycle transmit
                unwritten_len <= 'd0;
            end
            else if(payload_left_length + unwritten_len > 64) begin
                if(payload_left_length > 64) begin
                    unwritten_len <= unwritten_len;
                end
                else begin
                   unwritten_len <= payload_left_length + unwritten_len - 'd64; 
                end
            end
            else begin
                unwritten_len <= unwritten_len;
            end
        end
        else begin
            unwritten_len <= unwritten_len;
        end
    end
    else begin
        unwritten_len <= unwritten_len;
    end
end

//-- unwritten_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        unwritten_data <= 'd0;        
    end
    else if (cur_state == IDLE_s && egress_pkt_valid) begin
        case(egress_pkt_head[`OPCODE_OFFSET])
            `SEND_FIRST:                    unwritten_data <= {bth, mac_header};
            `SEND_MIDDLE:                   unwritten_data <= {bth, mac_header};
            `SEND_ONLY:                     unwritten_data <= {bth, mac_header};
            `SEND_LAST:                     unwritten_data <= {bth, mac_header};
            `SEND_ONLY_WITH_IMM:            unwritten_data <= {immeth, bth, mac_header};
            `SEND_LAST_WITH_IMM:            unwritten_data <= {immeth, bth, mac_header};
            `RDMA_WRITE_FIRST:              unwritten_data <= {reth, bth, mac_header};
            `RDMA_WRITE_MIDDLE:             unwritten_data <= {reth, bth, mac_header};
            `RDMA_WRITE_LAST:               unwritten_data <= {reth, bth, mac_header};
            `RDMA_WRITE_ONLY:               unwritten_data <= {reth, bth, mac_header};
            `RDMA_WRITE_LAST_WITH_IMM:      unwritten_data <= {immeth, reth, bth, mac_header};
            `RDMA_WRITE_ONLY_WITH_IMM:      unwritten_data <= {immeth, reth, bth, mac_header};
            `RDMA_READ_REQUEST_FIRST:       unwritten_data <= {reth, bth, mac_header};
            `RDMA_READ_REQUEST_MIDDLE:      unwritten_data <= {reth, bth, mac_header};
            `RDMA_READ_REQUEST_LAST:        unwritten_data <= {reth, bth, mac_header};
            `RDMA_READ_REQUEST_ONLY:        unwritten_data <= {reth, bth, mac_header};
            `RDMA_READ_RESPONSE_FIRST:      unwritten_data <= {bth, mac_header};
            `RDMA_READ_RESPONSE_MIDDLE:     unwritten_data <= {bth, mac_header};
            `RDMA_READ_RESPONSE_LAST:       unwritten_data <= {bth, mac_header};
            `RDMA_READ_RESPONSE_ONLY:       unwritten_data <= {bth, mac_header};
            `ACKNOWLEDGE:                   unwritten_data <= {aeth, bth, mac_header};
            default:                        unwritten_data <= 'd0;
        endcase        
    end
    else if(cur_state == ZERO_PAYLOAD_ENCAP_s && mac_tx_ready) begin
        unwritten_data <= 'd0;
    end
    else if(cur_state == NON_ZERO_PAYLOAD_ENCAP_s) begin
        if(payload_left_length == 0) begin
            unwritten_data <= mac_tx_ready ? 'd0 : unwritten_data;
        end
        else if(payload_left_length > 0 && delete_resp_valid && mac_tx_ready) begin
            if(payload_left_length + unwritten_len <= 64) begin
                unwritten_data <= 'd0;
            end
            else if(payload_left_length > 64 || payload_left_length + unwritten_len > 64) begin
                case(unwritten_len)
                    0   :           unwritten_data <= 'd0;
                    1   :           unwritten_data <= {{((64 - 1 ) * 8){1'b0}}, delete_resp_data[511 : (64 - 1 ) * 8]};
                    2   :           unwritten_data <= {{((64 - 2 ) * 8){1'b0}}, delete_resp_data[511 : (64 - 2 ) * 8]};
                    3   :           unwritten_data <= {{((64 - 3 ) * 8){1'b0}}, delete_resp_data[511 : (64 - 3 ) * 8]};
                    4   :           unwritten_data <= {{((64 - 4 ) * 8){1'b0}}, delete_resp_data[511 : (64 - 4 ) * 8]};
                    5   :           unwritten_data <= {{((64 - 5 ) * 8){1'b0}}, delete_resp_data[511 : (64 - 5 ) * 8]};
                    6   :           unwritten_data <= {{((64 - 6 ) * 8){1'b0}}, delete_resp_data[511 : (64 - 6 ) * 8]};
                    7   :           unwritten_data <= {{((64 - 7 ) * 8){1'b0}}, delete_resp_data[511 : (64 - 7 ) * 8]};
                    8   :           unwritten_data <= {{((64 - 8 ) * 8){1'b0}}, delete_resp_data[511 : (64 - 8 ) * 8]};
                    9   :           unwritten_data <= {{((64 - 9 ) * 8){1'b0}}, delete_resp_data[511 : (64 - 9 ) * 8]};
                    10  :           unwritten_data <= {{((64 - 10) * 8){1'b0}}, delete_resp_data[511 : (64 - 10) * 8]};
                    11  :           unwritten_data <= {{((64 - 11) * 8){1'b0}}, delete_resp_data[511 : (64 - 11) * 8]};
                    12  :           unwritten_data <= {{((64 - 12) * 8){1'b0}}, delete_resp_data[511 : (64 - 12) * 8]};
                    13  :           unwritten_data <= {{((64 - 13) * 8){1'b0}}, delete_resp_data[511 : (64 - 13) * 8]};
                    14  :           unwritten_data <= {{((64 - 14) * 8){1'b0}}, delete_resp_data[511 : (64 - 14) * 8]};
                    15  :           unwritten_data <= {{((64 - 15) * 8){1'b0}}, delete_resp_data[511 : (64 - 15) * 8]};
                    16  :           unwritten_data <= {{((64 - 16) * 8){1'b0}}, delete_resp_data[511 : (64 - 16) * 8]};
                    17  :           unwritten_data <= {{((64 - 17) * 8){1'b0}}, delete_resp_data[511 : (64 - 17) * 8]};
                    18  :           unwritten_data <= {{((64 - 18) * 8){1'b0}}, delete_resp_data[511 : (64 - 18) * 8]};
                    19  :           unwritten_data <= {{((64 - 19) * 8){1'b0}}, delete_resp_data[511 : (64 - 19) * 8]};
                    20  :           unwritten_data <= {{((64 - 20) * 8){1'b0}}, delete_resp_data[511 : (64 - 20) * 8]};
                    21  :           unwritten_data <= {{((64 - 21) * 8){1'b0}}, delete_resp_data[511 : (64 - 21) * 8]};
                    22  :           unwritten_data <= {{((64 - 22) * 8){1'b0}}, delete_resp_data[511 : (64 - 22) * 8]};
                    23  :           unwritten_data <= {{((64 - 23) * 8){1'b0}}, delete_resp_data[511 : (64 - 23) * 8]};
                    24  :           unwritten_data <= {{((64 - 24) * 8){1'b0}}, delete_resp_data[511 : (64 - 24) * 8]};
                    25  :           unwritten_data <= {{((64 - 25) * 8){1'b0}}, delete_resp_data[511 : (64 - 25) * 8]};
                    26  :           unwritten_data <= {{((64 - 26) * 8){1'b0}}, delete_resp_data[511 : (64 - 26) * 8]};
                    27  :           unwritten_data <= {{((64 - 27) * 8){1'b0}}, delete_resp_data[511 : (64 - 27) * 8]};
                    28  :           unwritten_data <= {{((64 - 28) * 8){1'b0}}, delete_resp_data[511 : (64 - 28) * 8]};
                    29  :           unwritten_data <= {{((64 - 29) * 8){1'b0}}, delete_resp_data[511 : (64 - 29) * 8]};
                    30  :           unwritten_data <= {{((64 - 30) * 8){1'b0}}, delete_resp_data[511 : (64 - 30) * 8]};
                    31  :           unwritten_data <= {{((64 - 31) * 8){1'b0}}, delete_resp_data[511 : (64 - 31) * 8]};
                    32  :           unwritten_data <= {{((64 - 32) * 8){1'b0}}, delete_resp_data[511 : (64 - 32) * 8]};
                    33  :           unwritten_data <= {{((64 - 33) * 8){1'b0}}, delete_resp_data[511 : (64 - 33) * 8]};
                    34  :           unwritten_data <= {{((64 - 34) * 8){1'b0}}, delete_resp_data[511 : (64 - 34) * 8]};
                    35  :           unwritten_data <= {{((64 - 35) * 8){1'b0}}, delete_resp_data[511 : (64 - 35) * 8]};
                    36  :           unwritten_data <= {{((64 - 36) * 8){1'b0}}, delete_resp_data[511 : (64 - 36) * 8]};
                    37  :           unwritten_data <= {{((64 - 37) * 8){1'b0}}, delete_resp_data[511 : (64 - 37) * 8]};
                    38  :           unwritten_data <= {{((64 - 38) * 8){1'b0}}, delete_resp_data[511 : (64 - 38) * 8]};
                    39  :           unwritten_data <= {{((64 - 39) * 8){1'b0}}, delete_resp_data[511 : (64 - 39) * 8]};
                    40  :           unwritten_data <= {{((64 - 40) * 8){1'b0}}, delete_resp_data[511 : (64 - 40) * 8]};
                    41  :           unwritten_data <= {{((64 - 41) * 8){1'b0}}, delete_resp_data[511 : (64 - 41) * 8]};
                    42  :           unwritten_data <= {{((64 - 42) * 8){1'b0}}, delete_resp_data[511 : (64 - 42) * 8]};
                    43  :           unwritten_data <= {{((64 - 43) * 8){1'b0}}, delete_resp_data[511 : (64 - 43) * 8]};
                    44  :           unwritten_data <= {{((64 - 44) * 8){1'b0}}, delete_resp_data[511 : (64 - 44) * 8]};
                    45  :           unwritten_data <= {{((64 - 45) * 8){1'b0}}, delete_resp_data[511 : (64 - 45) * 8]};
                    46  :           unwritten_data <= {{((64 - 46) * 8){1'b0}}, delete_resp_data[511 : (64 - 46) * 8]};
                    47  :           unwritten_data <= {{((64 - 47) * 8){1'b0}}, delete_resp_data[511 : (64 - 47) * 8]};
                    48  :           unwritten_data <= {{((64 - 48) * 8){1'b0}}, delete_resp_data[511 : (64 - 48) * 8]};
                    49  :           unwritten_data <= {{((64 - 49) * 8){1'b0}}, delete_resp_data[511 : (64 - 49) * 8]};
                    50  :           unwritten_data <= {{((64 - 50) * 8){1'b0}}, delete_resp_data[511 : (64 - 50) * 8]};
                    51  :           unwritten_data <= {{((64 - 51) * 8){1'b0}}, delete_resp_data[511 : (64 - 51) * 8]};
                    52  :           unwritten_data <= {{((64 - 52) * 8){1'b0}}, delete_resp_data[511 : (64 - 52) * 8]};
                    53  :           unwritten_data <= {{((64 - 53) * 8){1'b0}}, delete_resp_data[511 : (64 - 53) * 8]};
                    54  :           unwritten_data <= {{((64 - 54) * 8){1'b0}}, delete_resp_data[511 : (64 - 54) * 8]};
                    55  :           unwritten_data <= {{((64 - 55) * 8){1'b0}}, delete_resp_data[511 : (64 - 55) * 8]};
                    56  :           unwritten_data <= {{((64 - 56) * 8){1'b0}}, delete_resp_data[511 : (64 - 56) * 8]};
                    57  :           unwritten_data <= {{((64 - 57) * 8){1'b0}}, delete_resp_data[511 : (64 - 57) * 8]};
                    58  :           unwritten_data <= {{((64 - 58) * 8){1'b0}}, delete_resp_data[511 : (64 - 58) * 8]};
                    59  :           unwritten_data <= {{((64 - 59) * 8){1'b0}}, delete_resp_data[511 : (64 - 59) * 8]};
                    60  :           unwritten_data <= {{((64 - 60) * 8){1'b0}}, delete_resp_data[511 : (64 - 60) * 8]};
                    61  :           unwritten_data <= {{((64 - 61) * 8){1'b0}}, delete_resp_data[511 : (64 - 61) * 8]};
                    62  :           unwritten_data <= {{((64 - 62) * 8){1'b0}}, delete_resp_data[511 : (64 - 62) * 8]};
                    63  :           unwritten_data <= {{((64 - 63) * 8){1'b0}}, delete_resp_data[511 : (64 - 63) * 8]};
                    default:        unwritten_data <= unwritten_data;
                endcase
            end
            else if(payload_left_length + unwritten_len <= 64) begin
                unwritten_data <= 'd0;
            end
            else begin
                unwritten_data <= unwritten_data;
            end
        end
        else begin
            unwritten_data <= unwritten_data;
        end
    end
    else begin
        unwritten_data <= unwritten_data;
    end
end

//-- mac_tx_data --
always @(*) begin
    if (rst) begin
        mac_tx_data = 'd0;      
    end
    else if (cur_state == ZERO_PAYLOAD_ENCAP_s) begin
        mac_tx_data = unwritten_data;
    end
    else if(cur_state == NON_ZERO_PAYLOAD_ENCAP_s) begin
        if(payload_left_length == 0) begin
            mac_tx_data = unwritten_data;
        end
        else if(payload_left_length > 64 || payload_left_length + unwritten_len > 64) begin
            case(unwritten_len)
                0   :           mac_tx_data = delete_resp_data;
                1   :           mac_tx_data = {delete_resp_data[(64 - 1 ) * 8 - 1 : 0], unwritten_data[1  * 8 - 1 : 0]};
                2   :           mac_tx_data = {delete_resp_data[(64 - 2 ) * 8 - 1 : 0], unwritten_data[2  * 8 - 1 : 0]};
                3   :           mac_tx_data = {delete_resp_data[(64 - 3 ) * 8 - 1 : 0], unwritten_data[3  * 8 - 1 : 0]};
                4   :           mac_tx_data = {delete_resp_data[(64 - 4 ) * 8 - 1 : 0], unwritten_data[4  * 8 - 1 : 0]};
                5   :           mac_tx_data = {delete_resp_data[(64 - 5 ) * 8 - 1 : 0], unwritten_data[5  * 8 - 1 : 0]};
                6   :           mac_tx_data = {delete_resp_data[(64 - 6 ) * 8 - 1 : 0], unwritten_data[6  * 8 - 1 : 0]};
                7   :           mac_tx_data = {delete_resp_data[(64 - 7 ) * 8 - 1 : 0], unwritten_data[7  * 8 - 1 : 0]};
                8   :           mac_tx_data = {delete_resp_data[(64 - 8 ) * 8 - 1 : 0], unwritten_data[8  * 8 - 1 : 0]};
                9   :           mac_tx_data = {delete_resp_data[(64 - 9 ) * 8 - 1 : 0], unwritten_data[9  * 8 - 1 : 0]};
                10  :           mac_tx_data = {delete_resp_data[(64 - 10) * 8 - 1 : 0], unwritten_data[10 * 8 - 1 : 0]};
                11  :           mac_tx_data = {delete_resp_data[(64 - 11) * 8 - 1 : 0], unwritten_data[11 * 8 - 1 : 0]};
                12  :           mac_tx_data = {delete_resp_data[(64 - 12) * 8 - 1 : 0], unwritten_data[12 * 8 - 1 : 0]};
                13  :           mac_tx_data = {delete_resp_data[(64 - 13) * 8 - 1 : 0], unwritten_data[13 * 8 - 1 : 0]};
                14  :           mac_tx_data = {delete_resp_data[(64 - 14) * 8 - 1 : 0], unwritten_data[14 * 8 - 1 : 0]};
                15  :           mac_tx_data = {delete_resp_data[(64 - 15) * 8 - 1 : 0], unwritten_data[15 * 8 - 1 : 0]};
                16  :           mac_tx_data = {delete_resp_data[(64 - 16) * 8 - 1 : 0], unwritten_data[16 * 8 - 1 : 0]};
                17  :           mac_tx_data = {delete_resp_data[(64 - 17) * 8 - 1 : 0], unwritten_data[17 * 8 - 1 : 0]};
                18  :           mac_tx_data = {delete_resp_data[(64 - 18) * 8 - 1 : 0], unwritten_data[18 * 8 - 1 : 0]};
                19  :           mac_tx_data = {delete_resp_data[(64 - 19) * 8 - 1 : 0], unwritten_data[19 * 8 - 1 : 0]};
                20  :           mac_tx_data = {delete_resp_data[(64 - 20) * 8 - 1 : 0], unwritten_data[20 * 8 - 1 : 0]};
                21  :           mac_tx_data = {delete_resp_data[(64 - 21) * 8 - 1 : 0], unwritten_data[21 * 8 - 1 : 0]};
                22  :           mac_tx_data = {delete_resp_data[(64 - 22) * 8 - 1 : 0], unwritten_data[22 * 8 - 1 : 0]};
                23  :           mac_tx_data = {delete_resp_data[(64 - 23) * 8 - 1 : 0], unwritten_data[23 * 8 - 1 : 0]};
                24  :           mac_tx_data = {delete_resp_data[(64 - 24) * 8 - 1 : 0], unwritten_data[24 * 8 - 1 : 0]};
                25  :           mac_tx_data = {delete_resp_data[(64 - 25) * 8 - 1 : 0], unwritten_data[25 * 8 - 1 : 0]};
                26  :           mac_tx_data = {delete_resp_data[(64 - 26) * 8 - 1 : 0], unwritten_data[26 * 8 - 1 : 0]};
                27  :           mac_tx_data = {delete_resp_data[(64 - 27) * 8 - 1 : 0], unwritten_data[27 * 8 - 1 : 0]};
                28  :           mac_tx_data = {delete_resp_data[(64 - 28) * 8 - 1 : 0], unwritten_data[28 * 8 - 1 : 0]};
                29  :           mac_tx_data = {delete_resp_data[(64 - 29) * 8 - 1 : 0], unwritten_data[29 * 8 - 1 : 0]};
                30  :           mac_tx_data = {delete_resp_data[(64 - 30) * 8 - 1 : 0], unwritten_data[30 * 8 - 1 : 0]};
                31  :           mac_tx_data = {delete_resp_data[(64 - 31) * 8 - 1 : 0], unwritten_data[31 * 8 - 1 : 0]};
                32  :           mac_tx_data = {delete_resp_data[(64 - 32) * 8 - 1 : 0], unwritten_data[32 * 8 - 1 : 0]};
                33  :           mac_tx_data = {delete_resp_data[(64 - 33) * 8 - 1 : 0], unwritten_data[33 * 8 - 1 : 0]};
                34  :           mac_tx_data = {delete_resp_data[(64 - 34) * 8 - 1 : 0], unwritten_data[34 * 8 - 1 : 0]};
                35  :           mac_tx_data = {delete_resp_data[(64 - 35) * 8 - 1 : 0], unwritten_data[35 * 8 - 1 : 0]};
                36  :           mac_tx_data = {delete_resp_data[(64 - 36) * 8 - 1 : 0], unwritten_data[36 * 8 - 1 : 0]};
                37  :           mac_tx_data = {delete_resp_data[(64 - 37) * 8 - 1 : 0], unwritten_data[37 * 8 - 1 : 0]};
                38  :           mac_tx_data = {delete_resp_data[(64 - 38) * 8 - 1 : 0], unwritten_data[38 * 8 - 1 : 0]};
                39  :           mac_tx_data = {delete_resp_data[(64 - 39) * 8 - 1 : 0], unwritten_data[39 * 8 - 1 : 0]};
                40  :           mac_tx_data = {delete_resp_data[(64 - 40) * 8 - 1 : 0], unwritten_data[40 * 8 - 1 : 0]};
                41  :           mac_tx_data = {delete_resp_data[(64 - 41) * 8 - 1 : 0], unwritten_data[41 * 8 - 1 : 0]};
                42  :           mac_tx_data = {delete_resp_data[(64 - 42) * 8 - 1 : 0], unwritten_data[42 * 8 - 1 : 0]};
                43  :           mac_tx_data = {delete_resp_data[(64 - 43) * 8 - 1 : 0], unwritten_data[43 * 8 - 1 : 0]};
                44  :           mac_tx_data = {delete_resp_data[(64 - 44) * 8 - 1 : 0], unwritten_data[44 * 8 - 1 : 0]};
                45  :           mac_tx_data = {delete_resp_data[(64 - 45) * 8 - 1 : 0], unwritten_data[45 * 8 - 1 : 0]};
                46  :           mac_tx_data = {delete_resp_data[(64 - 46) * 8 - 1 : 0], unwritten_data[46 * 8 - 1 : 0]};
                47  :           mac_tx_data = {delete_resp_data[(64 - 47) * 8 - 1 : 0], unwritten_data[47 * 8 - 1 : 0]};
                48  :           mac_tx_data = {delete_resp_data[(64 - 48) * 8 - 1 : 0], unwritten_data[48 * 8 - 1 : 0]};
                49  :           mac_tx_data = {delete_resp_data[(64 - 49) * 8 - 1 : 0], unwritten_data[49 * 8 - 1 : 0]};
                50  :           mac_tx_data = {delete_resp_data[(64 - 50) * 8 - 1 : 0], unwritten_data[50 * 8 - 1 : 0]};
                51  :           mac_tx_data = {delete_resp_data[(64 - 51) * 8 - 1 : 0], unwritten_data[51 * 8 - 1 : 0]};
                52  :           mac_tx_data = {delete_resp_data[(64 - 52) * 8 - 1 : 0], unwritten_data[52 * 8 - 1 : 0]};
                53  :           mac_tx_data = {delete_resp_data[(64 - 53) * 8 - 1 : 0], unwritten_data[53 * 8 - 1 : 0]};
                54  :           mac_tx_data = {delete_resp_data[(64 - 54) * 8 - 1 : 0], unwritten_data[54 * 8 - 1 : 0]};
                55  :           mac_tx_data = {delete_resp_data[(64 - 55) * 8 - 1 : 0], unwritten_data[55 * 8 - 1 : 0]};
                56  :           mac_tx_data = {delete_resp_data[(64 - 56) * 8 - 1 : 0], unwritten_data[56 * 8 - 1 : 0]};
                57  :           mac_tx_data = {delete_resp_data[(64 - 57) * 8 - 1 : 0], unwritten_data[57 * 8 - 1 : 0]};
                58  :           mac_tx_data = {delete_resp_data[(64 - 58) * 8 - 1 : 0], unwritten_data[58 * 8 - 1 : 0]};
                59  :           mac_tx_data = {delete_resp_data[(64 - 59) * 8 - 1 : 0], unwritten_data[59 * 8 - 1 : 0]};
                60  :           mac_tx_data = {delete_resp_data[(64 - 60) * 8 - 1 : 0], unwritten_data[60 * 8 - 1 : 0]};
                61  :           mac_tx_data = {delete_resp_data[(64 - 61) * 8 - 1 : 0], unwritten_data[61 * 8 - 1 : 0]};
                62  :           mac_tx_data = {delete_resp_data[(64 - 62) * 8 - 1 : 0], unwritten_data[62 * 8 - 1 : 0]};
                63  :           mac_tx_data = {delete_resp_data[(64 - 63) * 8 - 1 : 0], unwritten_data[63 * 8 - 1 : 0]};
                default:        mac_tx_data = 'd0;
            endcase
        end
        else if(payload_left_length + unwritten_len <= 64) begin
            case(unwritten_len)
                0   :           mac_tx_data = delete_resp_data;
                1   :           mac_tx_data = {delete_resp_data[(64 - 1 ) * 8 - 1 : 0], unwritten_data[1  * 8 - 1 : 0]};
                2   :           mac_tx_data = {delete_resp_data[(64 - 2 ) * 8 - 1 : 0], unwritten_data[2  * 8 - 1 : 0]};
                3   :           mac_tx_data = {delete_resp_data[(64 - 3 ) * 8 - 1 : 0], unwritten_data[3  * 8 - 1 : 0]};
                4   :           mac_tx_data = {delete_resp_data[(64 - 4 ) * 8 - 1 : 0], unwritten_data[4  * 8 - 1 : 0]};
                5   :           mac_tx_data = {delete_resp_data[(64 - 5 ) * 8 - 1 : 0], unwritten_data[5  * 8 - 1 : 0]};
                6   :           mac_tx_data = {delete_resp_data[(64 - 6 ) * 8 - 1 : 0], unwritten_data[6  * 8 - 1 : 0]};
                7   :           mac_tx_data = {delete_resp_data[(64 - 7 ) * 8 - 1 : 0], unwritten_data[7  * 8 - 1 : 0]};
                8   :           mac_tx_data = {delete_resp_data[(64 - 8 ) * 8 - 1 : 0], unwritten_data[8  * 8 - 1 : 0]};
                9   :           mac_tx_data = {delete_resp_data[(64 - 9 ) * 8 - 1 : 0], unwritten_data[9  * 8 - 1 : 0]};
                10  :           mac_tx_data = {delete_resp_data[(64 - 10) * 8 - 1 : 0], unwritten_data[10 * 8 - 1 : 0]};
                11  :           mac_tx_data = {delete_resp_data[(64 - 11) * 8 - 1 : 0], unwritten_data[11 * 8 - 1 : 0]};
                12  :           mac_tx_data = {delete_resp_data[(64 - 12) * 8 - 1 : 0], unwritten_data[12 * 8 - 1 : 0]};
                13  :           mac_tx_data = {delete_resp_data[(64 - 13) * 8 - 1 : 0], unwritten_data[13 * 8 - 1 : 0]};
                14  :           mac_tx_data = {delete_resp_data[(64 - 14) * 8 - 1 : 0], unwritten_data[14 * 8 - 1 : 0]};
                15  :           mac_tx_data = {delete_resp_data[(64 - 15) * 8 - 1 : 0], unwritten_data[15 * 8 - 1 : 0]};
                16  :           mac_tx_data = {delete_resp_data[(64 - 16) * 8 - 1 : 0], unwritten_data[16 * 8 - 1 : 0]};
                17  :           mac_tx_data = {delete_resp_data[(64 - 17) * 8 - 1 : 0], unwritten_data[17 * 8 - 1 : 0]};
                18  :           mac_tx_data = {delete_resp_data[(64 - 18) * 8 - 1 : 0], unwritten_data[18 * 8 - 1 : 0]};
                19  :           mac_tx_data = {delete_resp_data[(64 - 19) * 8 - 1 : 0], unwritten_data[19 * 8 - 1 : 0]};
                20  :           mac_tx_data = {delete_resp_data[(64 - 20) * 8 - 1 : 0], unwritten_data[20 * 8 - 1 : 0]};
                21  :           mac_tx_data = {delete_resp_data[(64 - 21) * 8 - 1 : 0], unwritten_data[21 * 8 - 1 : 0]};
                22  :           mac_tx_data = {delete_resp_data[(64 - 22) * 8 - 1 : 0], unwritten_data[22 * 8 - 1 : 0]};
                23  :           mac_tx_data = {delete_resp_data[(64 - 23) * 8 - 1 : 0], unwritten_data[23 * 8 - 1 : 0]};
                24  :           mac_tx_data = {delete_resp_data[(64 - 24) * 8 - 1 : 0], unwritten_data[24 * 8 - 1 : 0]};
                25  :           mac_tx_data = {delete_resp_data[(64 - 25) * 8 - 1 : 0], unwritten_data[25 * 8 - 1 : 0]};
                26  :           mac_tx_data = {delete_resp_data[(64 - 26) * 8 - 1 : 0], unwritten_data[26 * 8 - 1 : 0]};
                27  :           mac_tx_data = {delete_resp_data[(64 - 27) * 8 - 1 : 0], unwritten_data[27 * 8 - 1 : 0]};
                28  :           mac_tx_data = {delete_resp_data[(64 - 28) * 8 - 1 : 0], unwritten_data[28 * 8 - 1 : 0]};
                29  :           mac_tx_data = {delete_resp_data[(64 - 29) * 8 - 1 : 0], unwritten_data[29 * 8 - 1 : 0]};
                30  :           mac_tx_data = {delete_resp_data[(64 - 30) * 8 - 1 : 0], unwritten_data[30 * 8 - 1 : 0]};
                31  :           mac_tx_data = {delete_resp_data[(64 - 31) * 8 - 1 : 0], unwritten_data[31 * 8 - 1 : 0]};
                32  :           mac_tx_data = {delete_resp_data[(64 - 32) * 8 - 1 : 0], unwritten_data[32 * 8 - 1 : 0]};
                33  :           mac_tx_data = {delete_resp_data[(64 - 33) * 8 - 1 : 0], unwritten_data[33 * 8 - 1 : 0]};
                34  :           mac_tx_data = {delete_resp_data[(64 - 34) * 8 - 1 : 0], unwritten_data[34 * 8 - 1 : 0]};
                35  :           mac_tx_data = {delete_resp_data[(64 - 35) * 8 - 1 : 0], unwritten_data[35 * 8 - 1 : 0]};
                36  :           mac_tx_data = {delete_resp_data[(64 - 36) * 8 - 1 : 0], unwritten_data[36 * 8 - 1 : 0]};
                37  :           mac_tx_data = {delete_resp_data[(64 - 37) * 8 - 1 : 0], unwritten_data[37 * 8 - 1 : 0]};
                38  :           mac_tx_data = {delete_resp_data[(64 - 38) * 8 - 1 : 0], unwritten_data[38 * 8 - 1 : 0]};
                39  :           mac_tx_data = {delete_resp_data[(64 - 39) * 8 - 1 : 0], unwritten_data[39 * 8 - 1 : 0]};
                40  :           mac_tx_data = {delete_resp_data[(64 - 40) * 8 - 1 : 0], unwritten_data[40 * 8 - 1 : 0]};
                41  :           mac_tx_data = {delete_resp_data[(64 - 41) * 8 - 1 : 0], unwritten_data[41 * 8 - 1 : 0]};
                42  :           mac_tx_data = {delete_resp_data[(64 - 42) * 8 - 1 : 0], unwritten_data[42 * 8 - 1 : 0]};
                43  :           mac_tx_data = {delete_resp_data[(64 - 43) * 8 - 1 : 0], unwritten_data[43 * 8 - 1 : 0]};
                44  :           mac_tx_data = {delete_resp_data[(64 - 44) * 8 - 1 : 0], unwritten_data[44 * 8 - 1 : 0]};
                45  :           mac_tx_data = {delete_resp_data[(64 - 45) * 8 - 1 : 0], unwritten_data[45 * 8 - 1 : 0]};
                46  :           mac_tx_data = {delete_resp_data[(64 - 46) * 8 - 1 : 0], unwritten_data[46 * 8 - 1 : 0]};
                47  :           mac_tx_data = {delete_resp_data[(64 - 47) * 8 - 1 : 0], unwritten_data[47 * 8 - 1 : 0]};
                48  :           mac_tx_data = {delete_resp_data[(64 - 48) * 8 - 1 : 0], unwritten_data[48 * 8 - 1 : 0]};
                49  :           mac_tx_data = {delete_resp_data[(64 - 49) * 8 - 1 : 0], unwritten_data[49 * 8 - 1 : 0]};
                50  :           mac_tx_data = {delete_resp_data[(64 - 50) * 8 - 1 : 0], unwritten_data[50 * 8 - 1 : 0]};
                51  :           mac_tx_data = {delete_resp_data[(64 - 51) * 8 - 1 : 0], unwritten_data[51 * 8 - 1 : 0]};
                52  :           mac_tx_data = {delete_resp_data[(64 - 52) * 8 - 1 : 0], unwritten_data[52 * 8 - 1 : 0]};
                53  :           mac_tx_data = {delete_resp_data[(64 - 53) * 8 - 1 : 0], unwritten_data[53 * 8 - 1 : 0]};
                54  :           mac_tx_data = {delete_resp_data[(64 - 54) * 8 - 1 : 0], unwritten_data[54 * 8 - 1 : 0]};
                55  :           mac_tx_data = {delete_resp_data[(64 - 55) * 8 - 1 : 0], unwritten_data[55 * 8 - 1 : 0]};
                56  :           mac_tx_data = {delete_resp_data[(64 - 56) * 8 - 1 : 0], unwritten_data[56 * 8 - 1 : 0]};
                57  :           mac_tx_data = {delete_resp_data[(64 - 57) * 8 - 1 : 0], unwritten_data[57 * 8 - 1 : 0]};
                58  :           mac_tx_data = {delete_resp_data[(64 - 58) * 8 - 1 : 0], unwritten_data[58 * 8 - 1 : 0]};
                59  :           mac_tx_data = {delete_resp_data[(64 - 59) * 8 - 1 : 0], unwritten_data[59 * 8 - 1 : 0]};
                60  :           mac_tx_data = {delete_resp_data[(64 - 60) * 8 - 1 : 0], unwritten_data[60 * 8 - 1 : 0]};
                61  :           mac_tx_data = {delete_resp_data[(64 - 61) * 8 - 1 : 0], unwritten_data[61 * 8 - 1 : 0]};
                62  :           mac_tx_data = {delete_resp_data[(64 - 62) * 8 - 1 : 0], unwritten_data[62 * 8 - 1 : 0]};
                63  :           mac_tx_data = {delete_resp_data[(64 - 63) * 8 - 1 : 0], unwritten_data[63 * 8 - 1 : 0]};
                default:        mac_tx_data = 'd0;
            endcase                        
        end
        else begin
            mac_tx_data = 'd0;
        end
    end
    else begin
        mac_tx_data = 'd0;
    end
end

//-- mac_tx_valid --
//-- mac_tx_start --
//-- mac_tx_last --
//-- mac_tx_keep --
//-- mac_tx_user --
assign mac_tx_valid = (cur_state == ZERO_PAYLOAD_ENCAP_s) ? 'd1 : 
                        (cur_state == NON_ZERO_PAYLOAD_ENCAP_s && payload_left_length > 0 && delete_resp_valid) ? 'd1 : 
                        (cur_state == NON_ZERO_PAYLOAD_ENCAP_s && payload_left_length == 0) ? 'd1 : 'd0;
assign mac_tx_start = (cur_state == ZERO_PAYLOAD_ENCAP_s) ? 'd1 : 
                        (cur_state == NON_ZERO_PAYLOAD_ENCAP_s && payload_left_length == bth_pkt_length) ? 'd1 : 'd0;
assign mac_tx_last = (cur_state == ZERO_PAYLOAD_ENCAP_s) ? 'd1 : 
                        (cur_state == NON_ZERO_PAYLOAD_ENCAP_s && mac_tx_valid && payload_left_length + unwritten_len <= 64) ? 'd1 : 'd0;
assign mac_tx_keep = 64'hFFFFFFFFFFFFFFFF;   //We don't use keep, juse keep all valid
assign mac_tx_user = 'd0;   //Always good packet

//-- egress_pkt_ready --
assign egress_pkt_ready = (cur_state == IDLE_s) ? 'd1 : 'd0;

//-- delete_req_valid --
//-- delete_req_head --
assign delete_req_valid = (cur_state == DEL_s) ? 'd1 : 'd0;
assign delete_req_head = (cur_state == DEL_s) ? {bth_pkt_length[5:0] ? (bth_pkt_length >> 6) + 1 : bth_pkt_length >> 6, pkt_header_bus[`PAYLOAD_ADDR_OFFSET]} : 'd0;

//-- delete_resp_ready --
assign delete_resp_ready = (cur_state == NON_ZERO_PAYLOAD_ENCAP_s) ? mac_tx_ready : 'd0;
/*------------------------------------------- Variables Decode : End ------------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef     LOCAL_QPN_OFFSET     
`undef     OPCODE_OFFSET        
`undef     SERVICE_TYPE_OFFSET  
`undef     REMOTE_QPN_OFFSET    
`undef     RKEY_OFFSET          
`undef     RADDR_OFFSET         
`undef     IMMEDIATE_OFFSET     
`undef     DMAC_OFFSET          
`undef     SMAC_OFFSET          
`undef     DIP_OFFSET           
`undef     SIP_OFFSET           
`undef     PAYLOAD_ADDR_OFFSET  
`undef     PAYLOAD_LENGTH_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/
endmodule