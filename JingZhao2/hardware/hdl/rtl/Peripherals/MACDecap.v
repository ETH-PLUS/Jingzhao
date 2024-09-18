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
module MACDecap
(
    input   wire                                            clk,
    input   wire                                            rst,

    output   wire                                           insert_req_valid,
    output   wire                                           insert_req_start,
    output   wire                                           insert_req_last,
    output   wire    [`MAX_DB_SLOT_NUM_LOG - 1 : 0]         insert_req_head,
    output   reg     [`PACKET_BUFFER_SLOT_WIDTH - 1 : 0]    insert_req_data,
    input    wire                                           insert_req_ready,

    output  wire                                            insert_resp_valid,
    output  wire    [`MAX_DB_SLOT_NUM_LOG - 1 : 0]          insert_resp_data,

    input   wire                                            mac_rx_valid,
    output  wire                                            mac_rx_ready,
    input   wire                                            mac_rx_start,
    input   wire                                            mac_rx_last,
    input   wire    [`MAC_KEEP_WIDTH - 1 : 0]               mac_rx_keep,
    input   wire                                            mac_rx_user,
    input   wire    [`MAC_DATA_WIDTH - 1 : 0]               mac_rx_data,

    output   wire                                 			ingress_pkt_valid,
    output   wire    [`PKT_META_BUS_WIDTH - 1 : 0]			ingress_pkt_head,
    input    wire                              				ingress_pkt_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
`define     DMAC_OFFSET             63 : 16
`define     SMAC_OFFSET             111 : 64

`define     SRC_QPN_OFFSET          23 + `MAC_HEADER_LENGTH * 8 : 0 + `MAC_HEADER_LENGTH * 8
`define     SERVICE_TYPE_OFFSET     26 + `MAC_HEADER_LENGTH * 8 : 24 + `MAC_HEADER_LENGTH * 8
`define     OPCODE_OFFSET           31 + `MAC_HEADER_LENGTH * 8 : 27 + `MAC_HEADER_LENGTH * 8
`define     DST_QPN_OFFSET          55 + `MAC_HEADER_LENGTH * 8 : 32 + `MAC_HEADER_LENGTH * 8
`define     PAYLOAD_LENGTH_OFFSET   71 + `MAC_HEADER_LENGTH * 8 : 56 + `MAC_HEADER_LENGTH * 8

`define     RADDR_OFFSET            63 + `MAC_HEADER_LENGTH * 8 + `BTH_LENGTH * 8 : 0 + `MAC_HEADER_LENGTH * 8 + `BTH_LENGTH * 8
`define     RKEY_OFFSET             95 + `MAC_HEADER_LENGTH * 8 + `BTH_LENGTH * 8 : 64 + `MAC_HEADER_LENGTH * 8 + `BTH_LENGTH * 8
`define     DMA_LENGTH_OFFSET       127 + `MAC_HEADER_LENGTH * 8 + `BTH_LENGTH * 8 : 96 + `MAC_HEADER_LENGTH * 8 + `BTH_LENGTH * 8
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
reg         [23:0]                  local_qpn;
reg         [23:0]                  remote_qpn;
reg         [4:0]                   opcode;
reg         [2:0]                   service_type;
reg         [7:0]                   syndrome;
reg         [31:0]                  rkey;
reg         [63:0]                  raddr;
reg         [31:0]                  immediate;
reg         [47:0]                  dmac;
reg         [47:0]                  smac;
reg         [31:0]                  dip;
reg         [31:0]                  sip;
reg         [15:0]                  payload_start_addr;
reg         [15:0]                  payload_length;
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg         [31:0]                  payload_left_length;
reg         [31:0]                  unwritten_len;
reg         [511:0]                 unwritten_data;

reg         [31:0]                  insert_count;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
//Null
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg             [2:0]                   cur_state;
reg             [2:0]                   next_state;

parameter       [2:0]                   IDLE_s              = 3'd1,
                                        BUFFER_PAYLOAD_s    = 3'd2,
                                        GEN_META_s          = 3'd3;

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
        IDLE_s:             if(mac_rx_valid) begin
                                if(mac_rx_data[`OPCODE_OFFSET] == `ACKNOWLEDGE ||
                                    mac_rx_data[`OPCODE_OFFSET] == `RDMA_READ_REQUEST_FIRST ||
                                    mac_rx_data[`OPCODE_OFFSET] == `RDMA_READ_REQUEST_MIDDLE ||
                                    mac_rx_data[`OPCODE_OFFSET] == `RDMA_READ_REQUEST_LAST ||
                                    mac_rx_data[`OPCODE_OFFSET] == `RDMA_READ_REQUEST_ONLY) begin
                                    next_state = GEN_META_s;
                                end
                                else begin
                                    next_state = BUFFER_PAYLOAD_s;
                                end
                            end
                            else begin
                                next_state = IDLE_s;
                            end
        BUFFER_PAYLOAD_s:   if(payload_left_length + unwritten_len <= 64) begin
                                if(payload_left_length == 0 && insert_req_ready) begin
                                    next_state = GEN_META_s;
                                end
                                else if(payload_left_length > 0 && mac_rx_valid && insert_req_ready) begin
                                    next_state = GEN_META_s;
                                end
                                else begin
                                    next_state = BUFFER_PAYLOAD_s;
                                end
                            end
                            else begin
                                next_state = BUFFER_PAYLOAD_s;
                            end
        GEN_META_s:         if(ingress_pkt_valid && ingress_pkt_ready) begin
                                next_state = IDLE_s;
                            end
                            else begin
                                next_state = GEN_META_s;
                            end
        default:            next_state = IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- local_qpn --
//-- remote_qpn --
//-- opcode --
//-- service_type --
//-- syndrome --
//-- rkey --
//-- raddr --
//-- immediate --
//-- dmac --
//-- smac --
//-- dip --
//-- sip --
//-- payload_start_addr --
//-- payload_length --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        local_qpn <= 'd0;
        remote_qpn <= 'd0;
        opcode <= 'd0;
        service_type <= 'd0;
        syndrome <= 'd0;
        rkey <= 'd0;
        raddr <= 'd0;
        immediate <= 'd0;
        dmac <= 'd0;
        smac <= 'd0;
        dip <= 'd0;
        sip <= 'd0;
        payload_length <= 'd0;
    end
    else if (cur_state == IDLE_s && mac_rx_valid) begin
        local_qpn <= mac_rx_data[`SRC_QPN_OFFSET];
        remote_qpn <= mac_rx_data[`DST_QPN_OFFSET];
        opcode <= mac_rx_data[`OPCODE_OFFSET];
        service_type <= mac_rx_data[`SERVICE_TYPE_OFFSET];
        syndrome <= 'd0;
        rkey <= mac_rx_data[`RKEY_OFFSET];
        raddr <= mac_rx_data[`RADDR_OFFSET];
        immediate <= 'd0;
        dmac <= mac_rx_data[`DMAC_OFFSET];
        smac <= mac_rx_data[`SMAC_OFFSET];
        dip <= 'd0;
        sip <= 'd0;
        payload_length <= mac_rx_data[`PAYLOAD_LENGTH_OFFSET];
    end
end

//-- payload_start_addr --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        payload_start_addr <= 'd0;        
    end
    else if(cur_state == IDLE_s) begin
        payload_start_addr <= 'd0;
    end
    else if (cur_state == BUFFER_PAYLOAD_s && insert_req_valid && insert_req_start && insert_req_ready && insert_resp_valid) begin
        payload_start_addr <= insert_resp_data;
    end
    else begin
        payload_start_addr <= payload_start_addr;
    end
end

//-- payload_left_length --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        payload_left_length <= 'd0;
    end
    else if (cur_state == IDLE_s && mac_rx_valid) begin
        if(mac_rx_data[`PAYLOAD_LENGTH_OFFSET] == 0) begin
            payload_left_length <= 'd0;
        end
        else begin
            case(mac_rx_data[`OPCODE_OFFSET])
                `SEND_FIRST:                    payload_left_length <= mac_rx_data[`PAYLOAD_LENGTH_OFFSET] > (64 - `BTH_LENGTH - `MAC_HEADER_LENGTH) ? 
                                                                    mac_rx_data[`PAYLOAD_LENGTH_OFFSET] - (64 - `BTH_LENGTH - `MAC_HEADER_LENGTH) : 'd0;
                `SEND_MIDDLE:                   payload_left_length <= mac_rx_data[`PAYLOAD_LENGTH_OFFSET] > (64 - `BTH_LENGTH - `MAC_HEADER_LENGTH) ? 
                                                                    mac_rx_data[`PAYLOAD_LENGTH_OFFSET] - (64 - `BTH_LENGTH - `MAC_HEADER_LENGTH) : 'd0;
                `SEND_ONLY:                     payload_left_length <= mac_rx_data[`PAYLOAD_LENGTH_OFFSET] > (64 - `BTH_LENGTH - `MAC_HEADER_LENGTH) ? 
                                                                    mac_rx_data[`PAYLOAD_LENGTH_OFFSET] - (64 - `BTH_LENGTH - `MAC_HEADER_LENGTH) : 'd0;
                `SEND_LAST:                     payload_left_length <= mac_rx_data[`PAYLOAD_LENGTH_OFFSET] > (64 - `BTH_LENGTH - `MAC_HEADER_LENGTH) ? 
                                                                    mac_rx_data[`PAYLOAD_LENGTH_OFFSET] - (64 - `BTH_LENGTH - `MAC_HEADER_LENGTH) : 'd0;
                `SEND_ONLY_WITH_IMM:            payload_left_length <= mac_rx_data[`PAYLOAD_LENGTH_OFFSET] > (64 - `IMMETH_LENGTH - `BTH_LENGTH - `MAC_HEADER_LENGTH) ? 
                                                                    mac_rx_data[`PAYLOAD_LENGTH_OFFSET] - (64 - `IMMETH_LENGTH - `BTH_LENGTH - `MAC_HEADER_LENGTH) : 'd0;
                `SEND_LAST_WITH_IMM:            payload_left_length <= mac_rx_data[`PAYLOAD_LENGTH_OFFSET] > (64 - `IMMETH_LENGTH - `BTH_LENGTH - `MAC_HEADER_LENGTH) ? 
                                                                    mac_rx_data[`PAYLOAD_LENGTH_OFFSET] - (64 - `IMMETH_LENGTH - `BTH_LENGTH - `MAC_HEADER_LENGTH) : 'd0;
                `RDMA_WRITE_FIRST:              payload_left_length <= mac_rx_data[`PAYLOAD_LENGTH_OFFSET] > (64 - `RETH_LENGTH - `BTH_LENGTH - `MAC_HEADER_LENGTH) ? 
                                                                    mac_rx_data[`PAYLOAD_LENGTH_OFFSET] - (64 - `RETH_LENGTH - `BTH_LENGTH - `MAC_HEADER_LENGTH) : 'd0;
                `RDMA_WRITE_MIDDLE:             payload_left_length <= mac_rx_data[`PAYLOAD_LENGTH_OFFSET] > (64 - `RETH_LENGTH - `BTH_LENGTH - `MAC_HEADER_LENGTH) ? 
                                                                    mac_rx_data[`PAYLOAD_LENGTH_OFFSET] - (64 - `RETH_LENGTH - `BTH_LENGTH - `MAC_HEADER_LENGTH) : 'd0;
                `RDMA_WRITE_LAST:               payload_left_length <= mac_rx_data[`PAYLOAD_LENGTH_OFFSET] > (64 - `RETH_LENGTH - `BTH_LENGTH - `MAC_HEADER_LENGTH) ? 
                                                                    mac_rx_data[`PAYLOAD_LENGTH_OFFSET] - (64 - `RETH_LENGTH - `BTH_LENGTH - `MAC_HEADER_LENGTH) : 'd0;
                `RDMA_WRITE_ONLY:               payload_left_length <= mac_rx_data[`PAYLOAD_LENGTH_OFFSET] > (64 - `RETH_LENGTH - `BTH_LENGTH - `MAC_HEADER_LENGTH) ? 
                                                                    mac_rx_data[`PAYLOAD_LENGTH_OFFSET] - (64 - `RETH_LENGTH - `BTH_LENGTH - `MAC_HEADER_LENGTH) : 'd0;
                `RDMA_WRITE_LAST_WITH_IMM:      payload_left_length <= mac_rx_data[`PAYLOAD_LENGTH_OFFSET] > (64 - `IMMETH_LENGTH -  `RETH_LENGTH - `BTH_LENGTH - `MAC_HEADER_LENGTH) ? 
                                                                    mac_rx_data[`PAYLOAD_LENGTH_OFFSET] - (64 - `IMMETH_LENGTH -  `RETH_LENGTH - `BTH_LENGTH - `MAC_HEADER_LENGTH) : 'd0;
                `RDMA_WRITE_ONLY_WITH_IMM:      payload_left_length <= mac_rx_data[`PAYLOAD_LENGTH_OFFSET] > (64 - `IMMETH_LENGTH -  `RETH_LENGTH - `BTH_LENGTH - `MAC_HEADER_LENGTH) ? 
                                                                    mac_rx_data[`PAYLOAD_LENGTH_OFFSET] - (64 - `IMMETH_LENGTH -  `RETH_LENGTH - `BTH_LENGTH - `MAC_HEADER_LENGTH) : 'd0;
                `RDMA_READ_REQUEST_FIRST:       payload_left_length <= 'd0;
                `RDMA_READ_REQUEST_MIDDLE:      payload_left_length <= 'd0;
                `RDMA_READ_REQUEST_LAST:        payload_left_length <= 'd0;
                `RDMA_READ_REQUEST_ONLY:        payload_left_length <= 'd0;
                `RDMA_READ_RESPONSE_FIRST:      payload_left_length <= mac_rx_data[`PAYLOAD_LENGTH_OFFSET] > (64 - `BTH_LENGTH - `MAC_HEADER_LENGTH) ? 
                                                                    mac_rx_data[`PAYLOAD_LENGTH_OFFSET] - (64 - `BTH_LENGTH - `MAC_HEADER_LENGTH) : 'd0;
                `RDMA_READ_RESPONSE_MIDDLE:     payload_left_length <= mac_rx_data[`PAYLOAD_LENGTH_OFFSET] > (64 - `BTH_LENGTH - `MAC_HEADER_LENGTH) ? 
                                                                    mac_rx_data[`PAYLOAD_LENGTH_OFFSET] - (64 - `BTH_LENGTH - `MAC_HEADER_LENGTH) : 'd0;
                `RDMA_READ_RESPONSE_LAST:       payload_left_length <= mac_rx_data[`PAYLOAD_LENGTH_OFFSET] > (64 - `BTH_LENGTH - `MAC_HEADER_LENGTH) ? 
                                                                    mac_rx_data[`PAYLOAD_LENGTH_OFFSET] - (64 - `BTH_LENGTH - `MAC_HEADER_LENGTH) : 'd0;
                `RDMA_READ_RESPONSE_ONLY:       payload_left_length <= mac_rx_data[`PAYLOAD_LENGTH_OFFSET] > (64 - `BTH_LENGTH - `MAC_HEADER_LENGTH) ? 
                                                                    mac_rx_data[`PAYLOAD_LENGTH_OFFSET] - (64 - `BTH_LENGTH - `MAC_HEADER_LENGTH) : 'd0;
                `ACKNOWLEDGE:                   payload_left_length <= 'd0;
                default:                        payload_left_length <= 'd0;
            endcase
        end
    end
    else if(cur_state == BUFFER_PAYLOAD_s) begin
        if(payload_left_length == 0) begin //Only unwritten_len left
            payload_left_length <= 'd0;
        end
        else if(payload_left_length > 0 && mac_rx_valid && insert_req_ready) begin
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
    else if (cur_state == IDLE_s && mac_rx_valid) begin
        case(mac_rx_data[`OPCODE_OFFSET])
            `SEND_FIRST:                    unwritten_len <= 64 - (`BTH_LENGTH + `MAC_HEADER_LENGTH);
            `SEND_MIDDLE:                   unwritten_len <= 64 - (`BTH_LENGTH + `MAC_HEADER_LENGTH);
            `SEND_ONLY:                     unwritten_len <= 64 - (`BTH_LENGTH + `MAC_HEADER_LENGTH);
            `SEND_LAST:                     unwritten_len <= 64 - (`BTH_LENGTH + `MAC_HEADER_LENGTH);
            `SEND_ONLY_WITH_IMM:            unwritten_len <= 64 - (`BTH_LENGTH + `IMMETH_LENGTH + `MAC_HEADER_LENGTH);
            `SEND_LAST_WITH_IMM:            unwritten_len <= 64 - (`BTH_LENGTH + `MAC_HEADER_LENGTH);
            `RDMA_WRITE_FIRST:              unwritten_len <= 64 - (`BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH);
            `RDMA_WRITE_MIDDLE:             unwritten_len <= 64 - (`BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH);
            `RDMA_WRITE_LAST:               unwritten_len <= 64 - (`BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH);
            `RDMA_WRITE_ONLY:               unwritten_len <= 64 - (`BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH);
            `RDMA_WRITE_LAST_WITH_IMM:      unwritten_len <= 64 - (`BTH_LENGTH + `RETH_LENGTH +`IMMETH_LENGTH + `MAC_HEADER_LENGTH);
            `RDMA_WRITE_ONLY_WITH_IMM:      unwritten_len <= 64 - (`BTH_LENGTH + `RETH_LENGTH +`IMMETH_LENGTH + `MAC_HEADER_LENGTH);
            `RDMA_READ_REQUEST_FIRST:       unwritten_len <= 64 - (`BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH);
            `RDMA_READ_REQUEST_MIDDLE:      unwritten_len <= 64 - (`BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH);
            `RDMA_READ_REQUEST_LAST:        unwritten_len <= 64 - (`BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH);
            `RDMA_READ_REQUEST_ONLY:        unwritten_len <= 64 - (`BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH);
            `RDMA_READ_RESPONSE_FIRST:      unwritten_len <= 64 - (`BTH_LENGTH + `MAC_HEADER_LENGTH);
            `RDMA_READ_RESPONSE_MIDDLE:     unwritten_len <= 64 - (`BTH_LENGTH + `MAC_HEADER_LENGTH);
            `RDMA_READ_RESPONSE_LAST:       unwritten_len <= 64 - (`BTH_LENGTH + `MAC_HEADER_LENGTH);
            `RDMA_READ_RESPONSE_ONLY:       unwritten_len <= 64 - (`BTH_LENGTH + `MAC_HEADER_LENGTH);
            `ACKNOWLEDGE:                   unwritten_len <= 64 - (`BTH_LENGTH + `AETH_LENGTH + `MAC_HEADER_LENGTH);
            default:                        unwritten_len <= 'd0;
        endcase    
    end
    else if(cur_state == BUFFER_PAYLOAD_s) begin
        if(payload_left_length == 0) begin  //Last cycle insert
            unwritten_len <= insert_req_ready ? 'd0 : unwritten_len;
        end
        else if(payload_left_length > 0 && mac_rx_valid && insert_req_ready) begin
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
end

//-- unwritten_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        unwritten_data <= 'd0;        
    end
    else if (cur_state == IDLE_s && mac_rx_valid) begin
        case(mac_rx_data[`OPCODE_OFFSET])
            `SEND_FIRST:                    unwritten_data <= mac_rx_data[511 : (`BTH_LENGTH + `MAC_HEADER_LENGTH) * 8];
            `SEND_MIDDLE:                   unwritten_data <= mac_rx_data[511 : (`BTH_LENGTH + `MAC_HEADER_LENGTH) * 8];
            `SEND_ONLY:                     unwritten_data <= mac_rx_data[511 : (`BTH_LENGTH + `MAC_HEADER_LENGTH) * 8];
            `SEND_LAST:                     unwritten_data <= mac_rx_data[511 : (`BTH_LENGTH + `MAC_HEADER_LENGTH) * 8];
            `SEND_ONLY_WITH_IMM:            unwritten_data <= mac_rx_data[511 : (`BTH_LENGTH + `IMMETH_LENGTH + `MAC_HEADER_LENGTH) * 8];
            `SEND_LAST_WITH_IMM:            unwritten_data <= mac_rx_data[511 : (`BTH_LENGTH + `MAC_HEADER_LENGTH) * 8];
            `RDMA_WRITE_FIRST:              unwritten_data <= mac_rx_data[511 : (`BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH) * 8];
            `RDMA_WRITE_MIDDLE:             unwritten_data <= mac_rx_data[511 : (`BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH) * 8];
            `RDMA_WRITE_LAST:               unwritten_data <= mac_rx_data[511 : (`BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH) * 8];
            `RDMA_WRITE_ONLY:               unwritten_data <= mac_rx_data[511 : (`BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH) * 8];
            `RDMA_WRITE_LAST_WITH_IMM:      unwritten_data <= mac_rx_data[511 : (`BTH_LENGTH + `RETH_LENGTH +`IMMETH_LENGTH + `MAC_HEADER_LENGTH) * 8];
            `RDMA_WRITE_ONLY_WITH_IMM:      unwritten_data <= mac_rx_data[511 : (`BTH_LENGTH + `RETH_LENGTH +`IMMETH_LENGTH + `MAC_HEADER_LENGTH) * 8];
            `RDMA_READ_REQUEST_FIRST:       unwritten_data <= mac_rx_data[511 : (`BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH) * 8];
            `RDMA_READ_REQUEST_MIDDLE:      unwritten_data <= mac_rx_data[511 : (`BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH) * 8];
            `RDMA_READ_REQUEST_LAST:        unwritten_data <= mac_rx_data[511 : (`BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH) * 8];
            `RDMA_READ_REQUEST_ONLY:        unwritten_data <= mac_rx_data[511 : (`BTH_LENGTH + `RETH_LENGTH + `MAC_HEADER_LENGTH) * 8];
            `RDMA_READ_RESPONSE_FIRST:      unwritten_data <= mac_rx_data[511 : (`BTH_LENGTH + `MAC_HEADER_LENGTH) * 8];
            `RDMA_READ_RESPONSE_MIDDLE:     unwritten_data <= mac_rx_data[511 : (`BTH_LENGTH + `MAC_HEADER_LENGTH) * 8];
            `RDMA_READ_RESPONSE_LAST:       unwritten_data <= mac_rx_data[511 : (`BTH_LENGTH + `MAC_HEADER_LENGTH) * 8];
            `RDMA_READ_RESPONSE_ONLY:       unwritten_data <= mac_rx_data[511 : (`BTH_LENGTH + `MAC_HEADER_LENGTH) * 8];
            `ACKNOWLEDGE:                   unwritten_data <= mac_rx_data[511 : (`BTH_LENGTH + `AETH_LENGTH + `MAC_HEADER_LENGTH) * 8];
            default:                        unwritten_data <= 'd0;
        endcase        
    end
    else if(cur_state == BUFFER_PAYLOAD_s) begin
        if(payload_left_length == 0) begin
            unwritten_data <= insert_req_ready ? 'd0 : unwritten_data;
        end
        else if(payload_left_length > 0 && mac_rx_valid && insert_req_ready) begin
            if(payload_left_length + unwritten_len <= 64) begin
                unwritten_data <= 'd0;
            end
            else if(payload_left_length > 64 || payload_left_length + unwritten_len > 64) begin
                case(unwritten_len)
                    0   :           unwritten_data <= 'd0;
                    1   :           unwritten_data <= {{((64 - 1 ) * 8){1'b0}}, mac_rx_data[511 : (64 - 1 ) * 8]};
                    2   :           unwritten_data <= {{((64 - 2 ) * 8){1'b0}}, mac_rx_data[511 : (64 - 2 ) * 8]};
                    3   :           unwritten_data <= {{((64 - 3 ) * 8){1'b0}}, mac_rx_data[511 : (64 - 3 ) * 8]};
                    4   :           unwritten_data <= {{((64 - 4 ) * 8){1'b0}}, mac_rx_data[511 : (64 - 4 ) * 8]};
                    5   :           unwritten_data <= {{((64 - 5 ) * 8){1'b0}}, mac_rx_data[511 : (64 - 5 ) * 8]};
                    6   :           unwritten_data <= {{((64 - 6 ) * 8){1'b0}}, mac_rx_data[511 : (64 - 6 ) * 8]};
                    7   :           unwritten_data <= {{((64 - 7 ) * 8){1'b0}}, mac_rx_data[511 : (64 - 7 ) * 8]};
                    8   :           unwritten_data <= {{((64 - 8 ) * 8){1'b0}}, mac_rx_data[511 : (64 - 8 ) * 8]};
                    9   :           unwritten_data <= {{((64 - 9 ) * 8){1'b0}}, mac_rx_data[511 : (64 - 9 ) * 8]};
                    10  :           unwritten_data <= {{((64 - 10) * 8){1'b0}}, mac_rx_data[511 : (64 - 10) * 8]};
                    11  :           unwritten_data <= {{((64 - 11) * 8){1'b0}}, mac_rx_data[511 : (64 - 11) * 8]};
                    12  :           unwritten_data <= {{((64 - 12) * 8){1'b0}}, mac_rx_data[511 : (64 - 12) * 8]};
                    13  :           unwritten_data <= {{((64 - 13) * 8){1'b0}}, mac_rx_data[511 : (64 - 13) * 8]};
                    14  :           unwritten_data <= {{((64 - 14) * 8){1'b0}}, mac_rx_data[511 : (64 - 14) * 8]};
                    15  :           unwritten_data <= {{((64 - 15) * 8){1'b0}}, mac_rx_data[511 : (64 - 15) * 8]};
                    16  :           unwritten_data <= {{((64 - 16) * 8){1'b0}}, mac_rx_data[511 : (64 - 16) * 8]};
                    17  :           unwritten_data <= {{((64 - 17) * 8){1'b0}}, mac_rx_data[511 : (64 - 17) * 8]};
                    18  :           unwritten_data <= {{((64 - 18) * 8){1'b0}}, mac_rx_data[511 : (64 - 18) * 8]};
                    19  :           unwritten_data <= {{((64 - 19) * 8){1'b0}}, mac_rx_data[511 : (64 - 19) * 8]};
                    20  :           unwritten_data <= {{((64 - 20) * 8){1'b0}}, mac_rx_data[511 : (64 - 20) * 8]};
                    21  :           unwritten_data <= {{((64 - 21) * 8){1'b0}}, mac_rx_data[511 : (64 - 21) * 8]};
                    22  :           unwritten_data <= {{((64 - 22) * 8){1'b0}}, mac_rx_data[511 : (64 - 22) * 8]};
                    23  :           unwritten_data <= {{((64 - 23) * 8){1'b0}}, mac_rx_data[511 : (64 - 23) * 8]};
                    24  :           unwritten_data <= {{((64 - 24) * 8){1'b0}}, mac_rx_data[511 : (64 - 24) * 8]};
                    25  :           unwritten_data <= {{((64 - 25) * 8){1'b0}}, mac_rx_data[511 : (64 - 25) * 8]};
                    26  :           unwritten_data <= {{((64 - 26) * 8){1'b0}}, mac_rx_data[511 : (64 - 26) * 8]};
                    27  :           unwritten_data <= {{((64 - 27) * 8){1'b0}}, mac_rx_data[511 : (64 - 27) * 8]};
                    28  :           unwritten_data <= {{((64 - 28) * 8){1'b0}}, mac_rx_data[511 : (64 - 28) * 8]};
                    29  :           unwritten_data <= {{((64 - 29) * 8){1'b0}}, mac_rx_data[511 : (64 - 29) * 8]};
                    30  :           unwritten_data <= {{((64 - 30) * 8){1'b0}}, mac_rx_data[511 : (64 - 30) * 8]};
                    31  :           unwritten_data <= {{((64 - 31) * 8){1'b0}}, mac_rx_data[511 : (64 - 31) * 8]};
                    32  :           unwritten_data <= {{((64 - 32) * 8){1'b0}}, mac_rx_data[511 : (64 - 32) * 8]};
                    33  :           unwritten_data <= {{((64 - 33) * 8){1'b0}}, mac_rx_data[511 : (64 - 33) * 8]};
                    34  :           unwritten_data <= {{((64 - 34) * 8){1'b0}}, mac_rx_data[511 : (64 - 34) * 8]};
                    35  :           unwritten_data <= {{((64 - 35) * 8){1'b0}}, mac_rx_data[511 : (64 - 35) * 8]};
                    36  :           unwritten_data <= {{((64 - 36) * 8){1'b0}}, mac_rx_data[511 : (64 - 36) * 8]};
                    37  :           unwritten_data <= {{((64 - 37) * 8){1'b0}}, mac_rx_data[511 : (64 - 37) * 8]};
                    38  :           unwritten_data <= {{((64 - 38) * 8){1'b0}}, mac_rx_data[511 : (64 - 38) * 8]};
                    39  :           unwritten_data <= {{((64 - 39) * 8){1'b0}}, mac_rx_data[511 : (64 - 39) * 8]};
                    40  :           unwritten_data <= {{((64 - 40) * 8){1'b0}}, mac_rx_data[511 : (64 - 40) * 8]};
                    41  :           unwritten_data <= {{((64 - 41) * 8){1'b0}}, mac_rx_data[511 : (64 - 41) * 8]};
                    42  :           unwritten_data <= {{((64 - 42) * 8){1'b0}}, mac_rx_data[511 : (64 - 42) * 8]};
                    43  :           unwritten_data <= {{((64 - 43) * 8){1'b0}}, mac_rx_data[511 : (64 - 43) * 8]};
                    44  :           unwritten_data <= {{((64 - 44) * 8){1'b0}}, mac_rx_data[511 : (64 - 44) * 8]};
                    45  :           unwritten_data <= {{((64 - 45) * 8){1'b0}}, mac_rx_data[511 : (64 - 45) * 8]};
                    46  :           unwritten_data <= {{((64 - 46) * 8){1'b0}}, mac_rx_data[511 : (64 - 46) * 8]};
                    47  :           unwritten_data <= {{((64 - 47) * 8){1'b0}}, mac_rx_data[511 : (64 - 47) * 8]};
                    48  :           unwritten_data <= {{((64 - 48) * 8){1'b0}}, mac_rx_data[511 : (64 - 48) * 8]};
                    49  :           unwritten_data <= {{((64 - 49) * 8){1'b0}}, mac_rx_data[511 : (64 - 49) * 8]};
                    50  :           unwritten_data <= {{((64 - 50) * 8){1'b0}}, mac_rx_data[511 : (64 - 50) * 8]};
                    51  :           unwritten_data <= {{((64 - 51) * 8){1'b0}}, mac_rx_data[511 : (64 - 51) * 8]};
                    52  :           unwritten_data <= {{((64 - 52) * 8){1'b0}}, mac_rx_data[511 : (64 - 52) * 8]};
                    53  :           unwritten_data <= {{((64 - 53) * 8){1'b0}}, mac_rx_data[511 : (64 - 53) * 8]};
                    54  :           unwritten_data <= {{((64 - 54) * 8){1'b0}}, mac_rx_data[511 : (64 - 54) * 8]};
                    55  :           unwritten_data <= {{((64 - 55) * 8){1'b0}}, mac_rx_data[511 : (64 - 55) * 8]};
                    56  :           unwritten_data <= {{((64 - 56) * 8){1'b0}}, mac_rx_data[511 : (64 - 56) * 8]};
                    57  :           unwritten_data <= {{((64 - 57) * 8){1'b0}}, mac_rx_data[511 : (64 - 57) * 8]};
                    58  :           unwritten_data <= {{((64 - 58) * 8){1'b0}}, mac_rx_data[511 : (64 - 58) * 8]};
                    59  :           unwritten_data <= {{((64 - 59) * 8){1'b0}}, mac_rx_data[511 : (64 - 59) * 8]};
                    60  :           unwritten_data <= {{((64 - 60) * 8){1'b0}}, mac_rx_data[511 : (64 - 60) * 8]};
                    61  :           unwritten_data <= {{((64 - 61) * 8){1'b0}}, mac_rx_data[511 : (64 - 61) * 8]};
                    62  :           unwritten_data <= {{((64 - 62) * 8){1'b0}}, mac_rx_data[511 : (64 - 62) * 8]};
                    63  :           unwritten_data <= {{((64 - 63) * 8){1'b0}}, mac_rx_data[511 : (64 - 63) * 8]};
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

//-- insert_req_valid --
//-- insert_req_start --
//-- insert_req_last --
//-- insert_req_head --
assign insert_req_valid = (cur_state == BUFFER_PAYLOAD_s && payload_left_length == 0) ? 'd1 :
                            (cur_state == BUFFER_PAYLOAD_s && payload_left_length > 0) ? 'd1 : 'd0;
assign insert_req_start = (cur_state == BUFFER_PAYLOAD_s && (insert_count == 'd1)) ? 'd1 : 'd0;
assign insert_req_last = (cur_state == BUFFER_PAYLOAD_s && payload_left_length == 0) ? 'd1 :
                        (cur_state == BUFFER_PAYLOAD_s && payload_left_length > 0 && payload_left_length + unwritten_len <= 64) ? 'd1 : 'd0; 
assign insert_req_head = (cur_state == BUFFER_PAYLOAD_s && insert_req_start) ? (mac_rx_data[`PAYLOAD_LENGTH_OFFSET] % 64 ? (mac_rx_data[`PAYLOAD_LENGTH_OFFSET] >> 6) + 1 : mac_rx_data[`PAYLOAD_LENGTH_OFFSET] >> 6) : 'd0;

//-- insert_count --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        insert_count <= 'd0;        
    end
    else if (cur_state == IDLE_s && next_state == BUFFER_PAYLOAD_s) begin
        insert_count <= 'd1;
    end
    else if(cur_state == BUFFER_PAYLOAD_s && insert_req_valid && insert_req_ready) begin
        insert_count <= insert_count + 'd1;
    end
    else begin
        insert_count <= insert_count;
    end
end

//-- insert_req_data --
always @(*) begin
    if (rst) begin
        insert_req_data = 'd0;      
    end
    else if(cur_state == BUFFER_PAYLOAD_s) begin
        if(payload_left_length == 0) begin
            insert_req_data = unwritten_data;
        end
        else if(payload_left_length > 64 || payload_left_length + unwritten_len > 64) begin
            case(unwritten_len)
                0   :           insert_req_data = mac_rx_data;
                1   :           insert_req_data = {mac_rx_data[(64 - 1 ) * 8 - 1 : 0], unwritten_data[1  * 8 - 1 : 0]};
                2   :           insert_req_data = {mac_rx_data[(64 - 2 ) * 8 - 1 : 0], unwritten_data[2  * 8 - 1 : 0]};
                3   :           insert_req_data = {mac_rx_data[(64 - 3 ) * 8 - 1 : 0], unwritten_data[3  * 8 - 1 : 0]};
                4   :           insert_req_data = {mac_rx_data[(64 - 4 ) * 8 - 1 : 0], unwritten_data[4  * 8 - 1 : 0]};
                5   :           insert_req_data = {mac_rx_data[(64 - 5 ) * 8 - 1 : 0], unwritten_data[5  * 8 - 1 : 0]};
                6   :           insert_req_data = {mac_rx_data[(64 - 6 ) * 8 - 1 : 0], unwritten_data[6  * 8 - 1 : 0]};
                7   :           insert_req_data = {mac_rx_data[(64 - 7 ) * 8 - 1 : 0], unwritten_data[7  * 8 - 1 : 0]};
                8   :           insert_req_data = {mac_rx_data[(64 - 8 ) * 8 - 1 : 0], unwritten_data[8  * 8 - 1 : 0]};
                9   :           insert_req_data = {mac_rx_data[(64 - 9 ) * 8 - 1 : 0], unwritten_data[9  * 8 - 1 : 0]};
                10  :           insert_req_data = {mac_rx_data[(64 - 10) * 8 - 1 : 0], unwritten_data[10 * 8 - 1 : 0]};
                11  :           insert_req_data = {mac_rx_data[(64 - 11) * 8 - 1 : 0], unwritten_data[11 * 8 - 1 : 0]};
                12  :           insert_req_data = {mac_rx_data[(64 - 12) * 8 - 1 : 0], unwritten_data[12 * 8 - 1 : 0]};
                13  :           insert_req_data = {mac_rx_data[(64 - 13) * 8 - 1 : 0], unwritten_data[13 * 8 - 1 : 0]};
                14  :           insert_req_data = {mac_rx_data[(64 - 14) * 8 - 1 : 0], unwritten_data[14 * 8 - 1 : 0]};
                15  :           insert_req_data = {mac_rx_data[(64 - 15) * 8 - 1 : 0], unwritten_data[15 * 8 - 1 : 0]};
                16  :           insert_req_data = {mac_rx_data[(64 - 16) * 8 - 1 : 0], unwritten_data[16 * 8 - 1 : 0]};
                17  :           insert_req_data = {mac_rx_data[(64 - 17) * 8 - 1 : 0], unwritten_data[17 * 8 - 1 : 0]};
                18  :           insert_req_data = {mac_rx_data[(64 - 18) * 8 - 1 : 0], unwritten_data[18 * 8 - 1 : 0]};
                19  :           insert_req_data = {mac_rx_data[(64 - 19) * 8 - 1 : 0], unwritten_data[19 * 8 - 1 : 0]};
                20  :           insert_req_data = {mac_rx_data[(64 - 20) * 8 - 1 : 0], unwritten_data[20 * 8 - 1 : 0]};
                21  :           insert_req_data = {mac_rx_data[(64 - 21) * 8 - 1 : 0], unwritten_data[21 * 8 - 1 : 0]};
                22  :           insert_req_data = {mac_rx_data[(64 - 22) * 8 - 1 : 0], unwritten_data[22 * 8 - 1 : 0]};
                23  :           insert_req_data = {mac_rx_data[(64 - 23) * 8 - 1 : 0], unwritten_data[23 * 8 - 1 : 0]};
                24  :           insert_req_data = {mac_rx_data[(64 - 24) * 8 - 1 : 0], unwritten_data[24 * 8 - 1 : 0]};
                25  :           insert_req_data = {mac_rx_data[(64 - 25) * 8 - 1 : 0], unwritten_data[25 * 8 - 1 : 0]};
                26  :           insert_req_data = {mac_rx_data[(64 - 26) * 8 - 1 : 0], unwritten_data[26 * 8 - 1 : 0]};
                27  :           insert_req_data = {mac_rx_data[(64 - 27) * 8 - 1 : 0], unwritten_data[27 * 8 - 1 : 0]};
                28  :           insert_req_data = {mac_rx_data[(64 - 28) * 8 - 1 : 0], unwritten_data[28 * 8 - 1 : 0]};
                29  :           insert_req_data = {mac_rx_data[(64 - 29) * 8 - 1 : 0], unwritten_data[29 * 8 - 1 : 0]};
                30  :           insert_req_data = {mac_rx_data[(64 - 30) * 8 - 1 : 0], unwritten_data[30 * 8 - 1 : 0]};
                31  :           insert_req_data = {mac_rx_data[(64 - 31) * 8 - 1 : 0], unwritten_data[31 * 8 - 1 : 0]};
                32  :           insert_req_data = {mac_rx_data[(64 - 32) * 8 - 1 : 0], unwritten_data[32 * 8 - 1 : 0]};
                33  :           insert_req_data = {mac_rx_data[(64 - 33) * 8 - 1 : 0], unwritten_data[33 * 8 - 1 : 0]};
                34  :           insert_req_data = {mac_rx_data[(64 - 34) * 8 - 1 : 0], unwritten_data[34 * 8 - 1 : 0]};
                35  :           insert_req_data = {mac_rx_data[(64 - 35) * 8 - 1 : 0], unwritten_data[35 * 8 - 1 : 0]};
                36  :           insert_req_data = {mac_rx_data[(64 - 36) * 8 - 1 : 0], unwritten_data[36 * 8 - 1 : 0]};
                37  :           insert_req_data = {mac_rx_data[(64 - 37) * 8 - 1 : 0], unwritten_data[37 * 8 - 1 : 0]};
                38  :           insert_req_data = {mac_rx_data[(64 - 38) * 8 - 1 : 0], unwritten_data[38 * 8 - 1 : 0]};
                39  :           insert_req_data = {mac_rx_data[(64 - 39) * 8 - 1 : 0], unwritten_data[39 * 8 - 1 : 0]};
                40  :           insert_req_data = {mac_rx_data[(64 - 40) * 8 - 1 : 0], unwritten_data[40 * 8 - 1 : 0]};
                41  :           insert_req_data = {mac_rx_data[(64 - 41) * 8 - 1 : 0], unwritten_data[41 * 8 - 1 : 0]};
                42  :           insert_req_data = {mac_rx_data[(64 - 42) * 8 - 1 : 0], unwritten_data[42 * 8 - 1 : 0]};
                43  :           insert_req_data = {mac_rx_data[(64 - 43) * 8 - 1 : 0], unwritten_data[43 * 8 - 1 : 0]};
                44  :           insert_req_data = {mac_rx_data[(64 - 44) * 8 - 1 : 0], unwritten_data[44 * 8 - 1 : 0]};
                45  :           insert_req_data = {mac_rx_data[(64 - 45) * 8 - 1 : 0], unwritten_data[45 * 8 - 1 : 0]};
                46  :           insert_req_data = {mac_rx_data[(64 - 46) * 8 - 1 : 0], unwritten_data[46 * 8 - 1 : 0]};
                47  :           insert_req_data = {mac_rx_data[(64 - 47) * 8 - 1 : 0], unwritten_data[47 * 8 - 1 : 0]};
                48  :           insert_req_data = {mac_rx_data[(64 - 48) * 8 - 1 : 0], unwritten_data[48 * 8 - 1 : 0]};
                49  :           insert_req_data = {mac_rx_data[(64 - 49) * 8 - 1 : 0], unwritten_data[49 * 8 - 1 : 0]};
                50  :           insert_req_data = {mac_rx_data[(64 - 50) * 8 - 1 : 0], unwritten_data[50 * 8 - 1 : 0]};
                51  :           insert_req_data = {mac_rx_data[(64 - 51) * 8 - 1 : 0], unwritten_data[51 * 8 - 1 : 0]};
                52  :           insert_req_data = {mac_rx_data[(64 - 52) * 8 - 1 : 0], unwritten_data[52 * 8 - 1 : 0]};
                53  :           insert_req_data = {mac_rx_data[(64 - 53) * 8 - 1 : 0], unwritten_data[53 * 8 - 1 : 0]};
                54  :           insert_req_data = {mac_rx_data[(64 - 54) * 8 - 1 : 0], unwritten_data[54 * 8 - 1 : 0]};
                55  :           insert_req_data = {mac_rx_data[(64 - 55) * 8 - 1 : 0], unwritten_data[55 * 8 - 1 : 0]};
                56  :           insert_req_data = {mac_rx_data[(64 - 56) * 8 - 1 : 0], unwritten_data[56 * 8 - 1 : 0]};
                57  :           insert_req_data = {mac_rx_data[(64 - 57) * 8 - 1 : 0], unwritten_data[57 * 8 - 1 : 0]};
                58  :           insert_req_data = {mac_rx_data[(64 - 58) * 8 - 1 : 0], unwritten_data[58 * 8 - 1 : 0]};
                59  :           insert_req_data = {mac_rx_data[(64 - 59) * 8 - 1 : 0], unwritten_data[59 * 8 - 1 : 0]};
                60  :           insert_req_data = {mac_rx_data[(64 - 60) * 8 - 1 : 0], unwritten_data[60 * 8 - 1 : 0]};
                61  :           insert_req_data = {mac_rx_data[(64 - 61) * 8 - 1 : 0], unwritten_data[61 * 8 - 1 : 0]};
                62  :           insert_req_data = {mac_rx_data[(64 - 62) * 8 - 1 : 0], unwritten_data[62 * 8 - 1 : 0]};
                63  :           insert_req_data = {mac_rx_data[(64 - 63) * 8 - 1 : 0], unwritten_data[63 * 8 - 1 : 0]};
                default:        insert_req_data = 'd0;
            endcase
        end
        else if(payload_left_length + unwritten_len <= 64) begin
            case(unwritten_len)
                0   :           insert_req_data = mac_rx_data;
                1   :           insert_req_data = {mac_rx_data[(64 - 1 ) * 8 - 1 : 0], unwritten_data[1  * 8 - 1 : 0]};
                2   :           insert_req_data = {mac_rx_data[(64 - 2 ) * 8 - 1 : 0], unwritten_data[2  * 8 - 1 : 0]};
                3   :           insert_req_data = {mac_rx_data[(64 - 3 ) * 8 - 1 : 0], unwritten_data[3  * 8 - 1 : 0]};
                4   :           insert_req_data = {mac_rx_data[(64 - 4 ) * 8 - 1 : 0], unwritten_data[4  * 8 - 1 : 0]};
                5   :           insert_req_data = {mac_rx_data[(64 - 5 ) * 8 - 1 : 0], unwritten_data[5  * 8 - 1 : 0]};
                6   :           insert_req_data = {mac_rx_data[(64 - 6 ) * 8 - 1 : 0], unwritten_data[6  * 8 - 1 : 0]};
                7   :           insert_req_data = {mac_rx_data[(64 - 7 ) * 8 - 1 : 0], unwritten_data[7  * 8 - 1 : 0]};
                8   :           insert_req_data = {mac_rx_data[(64 - 8 ) * 8 - 1 : 0], unwritten_data[8  * 8 - 1 : 0]};
                9   :           insert_req_data = {mac_rx_data[(64 - 9 ) * 8 - 1 : 0], unwritten_data[9  * 8 - 1 : 0]};
                10  :           insert_req_data = {mac_rx_data[(64 - 10) * 8 - 1 : 0], unwritten_data[10 * 8 - 1 : 0]};
                11  :           insert_req_data = {mac_rx_data[(64 - 11) * 8 - 1 : 0], unwritten_data[11 * 8 - 1 : 0]};
                12  :           insert_req_data = {mac_rx_data[(64 - 12) * 8 - 1 : 0], unwritten_data[12 * 8 - 1 : 0]};
                13  :           insert_req_data = {mac_rx_data[(64 - 13) * 8 - 1 : 0], unwritten_data[13 * 8 - 1 : 0]};
                14  :           insert_req_data = {mac_rx_data[(64 - 14) * 8 - 1 : 0], unwritten_data[14 * 8 - 1 : 0]};
                15  :           insert_req_data = {mac_rx_data[(64 - 15) * 8 - 1 : 0], unwritten_data[15 * 8 - 1 : 0]};
                16  :           insert_req_data = {mac_rx_data[(64 - 16) * 8 - 1 : 0], unwritten_data[16 * 8 - 1 : 0]};
                17  :           insert_req_data = {mac_rx_data[(64 - 17) * 8 - 1 : 0], unwritten_data[17 * 8 - 1 : 0]};
                18  :           insert_req_data = {mac_rx_data[(64 - 18) * 8 - 1 : 0], unwritten_data[18 * 8 - 1 : 0]};
                19  :           insert_req_data = {mac_rx_data[(64 - 19) * 8 - 1 : 0], unwritten_data[19 * 8 - 1 : 0]};
                20  :           insert_req_data = {mac_rx_data[(64 - 20) * 8 - 1 : 0], unwritten_data[20 * 8 - 1 : 0]};
                21  :           insert_req_data = {mac_rx_data[(64 - 21) * 8 - 1 : 0], unwritten_data[21 * 8 - 1 : 0]};
                22  :           insert_req_data = {mac_rx_data[(64 - 22) * 8 - 1 : 0], unwritten_data[22 * 8 - 1 : 0]};
                23  :           insert_req_data = {mac_rx_data[(64 - 23) * 8 - 1 : 0], unwritten_data[23 * 8 - 1 : 0]};
                24  :           insert_req_data = {mac_rx_data[(64 - 24) * 8 - 1 : 0], unwritten_data[24 * 8 - 1 : 0]};
                25  :           insert_req_data = {mac_rx_data[(64 - 25) * 8 - 1 : 0], unwritten_data[25 * 8 - 1 : 0]};
                26  :           insert_req_data = {mac_rx_data[(64 - 26) * 8 - 1 : 0], unwritten_data[26 * 8 - 1 : 0]};
                27  :           insert_req_data = {mac_rx_data[(64 - 27) * 8 - 1 : 0], unwritten_data[27 * 8 - 1 : 0]};
                28  :           insert_req_data = {mac_rx_data[(64 - 28) * 8 - 1 : 0], unwritten_data[28 * 8 - 1 : 0]};
                29  :           insert_req_data = {mac_rx_data[(64 - 29) * 8 - 1 : 0], unwritten_data[29 * 8 - 1 : 0]};
                30  :           insert_req_data = {mac_rx_data[(64 - 30) * 8 - 1 : 0], unwritten_data[30 * 8 - 1 : 0]};
                31  :           insert_req_data = {mac_rx_data[(64 - 31) * 8 - 1 : 0], unwritten_data[31 * 8 - 1 : 0]};
                32  :           insert_req_data = {mac_rx_data[(64 - 32) * 8 - 1 : 0], unwritten_data[32 * 8 - 1 : 0]};
                33  :           insert_req_data = {mac_rx_data[(64 - 33) * 8 - 1 : 0], unwritten_data[33 * 8 - 1 : 0]};
                34  :           insert_req_data = {mac_rx_data[(64 - 34) * 8 - 1 : 0], unwritten_data[34 * 8 - 1 : 0]};
                35  :           insert_req_data = {mac_rx_data[(64 - 35) * 8 - 1 : 0], unwritten_data[35 * 8 - 1 : 0]};
                36  :           insert_req_data = {mac_rx_data[(64 - 36) * 8 - 1 : 0], unwritten_data[36 * 8 - 1 : 0]};
                37  :           insert_req_data = {mac_rx_data[(64 - 37) * 8 - 1 : 0], unwritten_data[37 * 8 - 1 : 0]};
                38  :           insert_req_data = {mac_rx_data[(64 - 38) * 8 - 1 : 0], unwritten_data[38 * 8 - 1 : 0]};
                39  :           insert_req_data = {mac_rx_data[(64 - 39) * 8 - 1 : 0], unwritten_data[39 * 8 - 1 : 0]};
                40  :           insert_req_data = {mac_rx_data[(64 - 40) * 8 - 1 : 0], unwritten_data[40 * 8 - 1 : 0]};
                41  :           insert_req_data = {mac_rx_data[(64 - 41) * 8 - 1 : 0], unwritten_data[41 * 8 - 1 : 0]};
                42  :           insert_req_data = {mac_rx_data[(64 - 42) * 8 - 1 : 0], unwritten_data[42 * 8 - 1 : 0]};
                43  :           insert_req_data = {mac_rx_data[(64 - 43) * 8 - 1 : 0], unwritten_data[43 * 8 - 1 : 0]};
                44  :           insert_req_data = {mac_rx_data[(64 - 44) * 8 - 1 : 0], unwritten_data[44 * 8 - 1 : 0]};
                45  :           insert_req_data = {mac_rx_data[(64 - 45) * 8 - 1 : 0], unwritten_data[45 * 8 - 1 : 0]};
                46  :           insert_req_data = {mac_rx_data[(64 - 46) * 8 - 1 : 0], unwritten_data[46 * 8 - 1 : 0]};
                47  :           insert_req_data = {mac_rx_data[(64 - 47) * 8 - 1 : 0], unwritten_data[47 * 8 - 1 : 0]};
                48  :           insert_req_data = {mac_rx_data[(64 - 48) * 8 - 1 : 0], unwritten_data[48 * 8 - 1 : 0]};
                49  :           insert_req_data = {mac_rx_data[(64 - 49) * 8 - 1 : 0], unwritten_data[49 * 8 - 1 : 0]};
                50  :           insert_req_data = {mac_rx_data[(64 - 50) * 8 - 1 : 0], unwritten_data[50 * 8 - 1 : 0]};
                51  :           insert_req_data = {mac_rx_data[(64 - 51) * 8 - 1 : 0], unwritten_data[51 * 8 - 1 : 0]};
                52  :           insert_req_data = {mac_rx_data[(64 - 52) * 8 - 1 : 0], unwritten_data[52 * 8 - 1 : 0]};
                53  :           insert_req_data = {mac_rx_data[(64 - 53) * 8 - 1 : 0], unwritten_data[53 * 8 - 1 : 0]};
                54  :           insert_req_data = {mac_rx_data[(64 - 54) * 8 - 1 : 0], unwritten_data[54 * 8 - 1 : 0]};
                55  :           insert_req_data = {mac_rx_data[(64 - 55) * 8 - 1 : 0], unwritten_data[55 * 8 - 1 : 0]};
                56  :           insert_req_data = {mac_rx_data[(64 - 56) * 8 - 1 : 0], unwritten_data[56 * 8 - 1 : 0]};
                57  :           insert_req_data = {mac_rx_data[(64 - 57) * 8 - 1 : 0], unwritten_data[57 * 8 - 1 : 0]};
                58  :           insert_req_data = {mac_rx_data[(64 - 58) * 8 - 1 : 0], unwritten_data[58 * 8 - 1 : 0]};
                59  :           insert_req_data = {mac_rx_data[(64 - 59) * 8 - 1 : 0], unwritten_data[59 * 8 - 1 : 0]};
                60  :           insert_req_data = {mac_rx_data[(64 - 60) * 8 - 1 : 0], unwritten_data[60 * 8 - 1 : 0]};
                61  :           insert_req_data = {mac_rx_data[(64 - 61) * 8 - 1 : 0], unwritten_data[61 * 8 - 1 : 0]};
                62  :           insert_req_data = {mac_rx_data[(64 - 62) * 8 - 1 : 0], unwritten_data[62 * 8 - 1 : 0]};
                63  :           insert_req_data = {mac_rx_data[(64 - 63) * 8 - 1 : 0], unwritten_data[63 * 8 - 1 : 0]};
                default:        insert_req_data = 'd0;
            endcase                        
        end
        else begin
            insert_req_data = 'd0;
        end
    end
    else begin
        insert_req_data = 'd0;
    end
end

//-- mac_rx_ready --
assign mac_rx_ready =   (cur_state == IDLE_s) ? 'd1 :
                        (cur_state == BUFFER_PAYLOAD_s && payload_left_length > 0) ? insert_req_ready : 'd0;

//-- ingress_pkt_valid --
//-- ingress_pkt_head --
assign ingress_pkt_valid = (cur_state == GEN_META_s) ? 'd1 : 'd0;
assign ingress_pkt_head = (cur_state == GEN_META_s) ? { 
                                                        payload_length, payload_start_addr, sip, dip, smac, dmac, 
                                                        immediate, raddr, rkey, 8'd0, remote_qpn, service_type, opcode, local_qpn
                                                    } : 'd0;
/*------------------------------------------- Variables Decode : End ------------------------------------------------*/

/*------------------------------------------- Local Macros Undef : Begin --------------------------------------------*/
`undef     DMAC_OFFSET
`undef     SMAC_OFFSET

`undef     SRC_QPN_OFFSET
`undef     SERVICE_TYPE_OFFSET
`undef     OPCODE_OFFSET
`undef     DST_QPN_OFFSET
`undef     PAYLOAD_LENGTH_OFFSET

`undef     RADDR_OFFSET
`undef     RKEY_OFFSET
`undef     DMA_LENGTH_OFFSET
/*------------------------------------------- Local Macros Undef : End ----------------------------------------------*/


endmodule