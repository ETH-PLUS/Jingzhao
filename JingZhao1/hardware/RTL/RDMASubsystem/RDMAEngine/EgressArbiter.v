`timescale 1ns / 1ps

`include "ib_constant_def_h.vh"
`include "chip_include_rdma.vh"
`define SCH_REQUEST      1'b1
`define SCH_RESPONSE    1'b0

module EgressArbiter(   //Schedule Request and Response packet
    input   wire                clk,
    input   wire                rst,

//Interface with ReqPktGen
    input   wire                i_req_trans_empty,
    output  wire                o_req_trans_rd_en,
    input   wire    [255:0]     iv_req_trans_data,

//RespPketGen
    input   wire                i_resp_trans_empty,
    output  wire                o_resp_trans_rd_en,
    input   wire    [255:0]     iv_resp_trans_data,

//To FrameEncap
    input   wire                i_outbound_pkt_prog_full,
    output  wire                o_outbound_pkt_wr_en,
    output  wire    [255:0]      ov_outbound_pkt_data,

    input   wire    [31:0]      dbg_sel,
    output  wire    [32 - 1:0]      dbg_bus
//    output  wire    [`DBG_NUM_EGRESS_ARBITER * 32 - 1:0]      dbg_bus

);

//ila_egress_arbiter ila_egress_arbiter(
//    .clk(clk),
//    .probe0(i_req_trans_empty),
//    .probe1(o_req_trans_rd_en),
//    .probe2(iv_req_trans_data),
//    .probe3(i_resp_trans_empty),
//    .probe4(o_resp_trans_rd_en),
//    .probe5(iv_resp_trans_data),
//    .probe6(i_outbound_pkt_prog_full),
//    .probe7(o_outbound_pkt_wr_en),
//    .probe8(ov_outbound_pkt_data)   
//);

//ila_packet_catch ila_req_catch(
//    .clk(clk),
//    .probe0(i_req_trans_empty),
//    .probe1(o_req_trans_rd_en),
//    .probe2(iv_req_trans_data)
//);

//ila_packet_catch ila_resp_catch(
//    .clk(clk),
//    .probe0(i_resp_trans_empty),
//    .probe1(o_resp_trans_rd_en),
//    .probe2(iv_resp_trans_data)
//);

/*----------------------------------------  Part 1: Signals Definition and Submodules Connection ----------------------------------------*/
reg                     q_outbound_pkt_wr_en;
reg     [255:0]         qv_outbound_pkt_data;

assign o_outbound_pkt_wr_en = q_outbound_pkt_wr_en;
assign ov_outbound_pkt_data = qv_outbound_pkt_data;

reg                     q_last_sch_type;
reg     [13:0]          qv_pkt_left_len;
reg     [13:0]          qv_transport_pkt_len;

reg     [7:0]           qv_opcode;
reg     [13:0]          qv_payload_len;



/*----------------------------------------  Part 2: State Machine Transition ------------------------------------------------------------*/
reg     [2:0]           TRANS_cur_state;
reg     [2:0]           TRANS_next_state;

parameter   [2:0]       TRANS_IDLE_s = 3'b001,
                        TRANS_REQ_s = 3'b010,
                        TRANS_RESP_s = 3'b100;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        TRANS_cur_state <= TRANS_IDLE_s;
    end
    else begin
        TRANS_cur_state <= TRANS_next_state;
    end
end

always @(*) begin
    case(TRANS_cur_state) 
        TRANS_IDLE_s:       if(q_last_sch_type == `SCH_RESPONSE) begin
                                if(!i_req_trans_empty) begin
                                    TRANS_next_state = TRANS_REQ_s;
                                end
                                else if(!i_resp_trans_empty) begin
                                    TRANS_next_state = TRANS_RESP_s;
                                end
                                else begin
                                    TRANS_next_state = TRANS_IDLE_s;
                                end
                            end
                            else begin
                                if(!i_resp_trans_empty) begin
                                    TRANS_next_state = TRANS_RESP_s;
                                end
                                else if(!i_req_trans_empty) begin
                                    TRANS_next_state = TRANS_REQ_s;
                                end
                                else begin
                                    TRANS_next_state = TRANS_IDLE_s;
                                end                               
                            end
        TRANS_REQ_s:    if(qv_pkt_left_len <= 32 && !i_req_trans_empty && !i_outbound_pkt_prog_full) begin     //Last cycle of transfer
                                TRANS_next_state = TRANS_IDLE_s;
                            end
                            else begin
                                TRANS_next_state = TRANS_REQ_s;
                            end
        TRANS_RESP_s:   if(qv_pkt_left_len <= 32 && !i_resp_trans_empty && !i_outbound_pkt_prog_full) begin     //Last cycle of transfer
                                TRANS_next_state = TRANS_IDLE_s;
                            end
                            else begin
                                TRANS_next_state = TRANS_RESP_s;
                            end
        default:            TRANS_next_state = TRANS_IDLE_s;
    endcase
end

/*----------------------------------------  Part 3: Output Registers Decode -------------------------------------------------------------*/

//-- q_last_sch_type -- Used to indicate last schedued packet is req or resp
always @(posedge clk or posedge rst) begin
    if(rst) begin
        q_last_sch_type <= 'd0;
    end
    else if(TRANS_cur_state == TRANS_IDLE_s) begin
        if(q_last_sch_type == `SCH_RESPONSE) begin
            if(!i_req_trans_empty) begin
                q_last_sch_type <= `SCH_REQUEST;
            end
            else if(!i_resp_trans_empty) begin
                q_last_sch_type <= `SCH_RESPONSE;
            end
            else begin
                q_last_sch_type <= q_last_sch_type;
            end
        end
        else begin
            if(!i_resp_trans_empty) begin
                q_last_sch_type <= `SCH_RESPONSE;
            end
            else if(!i_req_trans_empty) begin
                q_last_sch_type <= `SCH_REQUEST;
            end
            else begin
                q_last_sch_type <= q_last_sch_type;
            end            
        end
    end
end

//-- qv_opcode -- Indicates current packet type
//-- qv_payload_len - Indicates payload length of current packet
always @(*) begin
    if (rst) begin
        qv_opcode = 'd0;
        qv_payload_len = 'd0;
    end
    else if(TRANS_cur_state == TRANS_IDLE_s) begin
        if(q_last_sch_type == `SCH_RESPONSE) begin
            if(!i_req_trans_empty) begin
                qv_opcode = iv_req_trans_data[31:24];
                qv_payload_len = {iv_req_trans_data[94:88], iv_req_trans_data[61:56]};
            end
            else if(!i_resp_trans_empty) begin
                qv_opcode = iv_resp_trans_data[31:24];
                qv_payload_len = {iv_resp_trans_data[94:88], iv_resp_trans_data[61:56]};
            end
            else begin
                qv_opcode = 'd0;
                qv_payload_len = 'd0;
            end
        end
        else begin
            if(!i_resp_trans_empty) begin
                qv_opcode = iv_resp_trans_data[31:24];
                qv_payload_len = {iv_resp_trans_data[94:88], iv_resp_trans_data[61:56]};
            end
            else if(!i_req_trans_empty) begin
                qv_opcode = iv_req_trans_data[31:24];
                qv_payload_len = {iv_req_trans_data[94:88], iv_req_trans_data[61:56]};
            end
            else begin
                qv_opcode = 'd0;
                qv_payload_len = 'd0;
            end                               
        end
    end
    else begin
        qv_opcode = 'd0;
        qv_payload_len = 'd0;
    end
end

//-- qv_transport_pkt_len --
always @(*) begin
    case(qv_opcode[4:0])
        `SEND_FIRST:                qv_transport_pkt_len = qv_payload_len + 14'd12;
        `SEND_MIDDLE:               qv_transport_pkt_len = qv_payload_len + 14'd12;
        `SEND_LAST:                 qv_transport_pkt_len = qv_payload_len + 14'd12;
        `SEND_LAST_WITH_IMM:        qv_transport_pkt_len = qv_payload_len + 14'd16;
        `SEND_ONLY:                 qv_transport_pkt_len = qv_payload_len + 14'd12 + (qv_opcode[7:5] == `UD ? 14'd16 : 14'd0);
        `SEND_ONLY_WITH_IMM:        qv_transport_pkt_len = qv_payload_len + 14'd16 + (qv_opcode[7:5] == `UD ? 14'd16 : 14'd0);
        `RDMA_WRITE_FIRST:          qv_transport_pkt_len = qv_payload_len + 14'd28;
        `RDMA_WRITE_MIDDLE:         qv_transport_pkt_len = qv_payload_len + 14'd12;
        `RDMA_WRITE_LAST:           qv_transport_pkt_len = qv_payload_len + 14'd12;
        `RDMA_WRITE_ONLY:           qv_transport_pkt_len = qv_payload_len + 14'd28;
        `RDMA_WRITE_LAST_WITH_IMM:  qv_transport_pkt_len = qv_payload_len + 14'd16;
        `RDMA_WRITE_ONLY_WITH_IMM:  qv_transport_pkt_len = qv_payload_len + 14'd32;
        `RDMA_READ_REQUEST:         qv_transport_pkt_len = 14'd28;
        `FETCH_AND_ADD:             qv_transport_pkt_len = 14'd40;
        `CMP_AND_SWAP:              qv_transport_pkt_len = 14'd40;
        `RDMA_READ_RESPONSE_FIRST:  qv_transport_pkt_len = qv_payload_len + 14'd16;
        `RDMA_READ_RESPONSE_MIDDLE: qv_transport_pkt_len = qv_payload_len + 14'd12;
        `RDMA_READ_RESPONSE_LAST:   qv_transport_pkt_len = qv_payload_len + 14'd16;
        `RDMA_READ_RESPONSE_ONLY:   qv_transport_pkt_len = qv_payload_len + 14'd16;
        `ACKNOWLEDGE:               qv_transport_pkt_len = 14'd16;
        default:                    qv_transport_pkt_len = 14'd0;
    endcase
end

//-- qv_pkt_left_len -- Indicate how many bytes left untransferred
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_pkt_left_len <= 'd0;        
    end
    else if (TRANS_cur_state == TRANS_IDLE_s) begin
        if(!i_req_trans_empty || !i_resp_trans_empty) begin
            qv_pkt_left_len <= qv_transport_pkt_len;
        end
        else begin
            qv_pkt_left_len <= 'd0;
        end    
    end
    else if(TRANS_cur_state == TRANS_REQ_s && !i_req_trans_empty && !i_outbound_pkt_prog_full) begin
        qv_pkt_left_len <= qv_pkt_left_len - 'd32;
    end
    else if(TRANS_cur_state == TRANS_RESP_s && !i_resp_trans_empty && !i_outbound_pkt_prog_full) begin
        qv_pkt_left_len <= qv_pkt_left_len - 'd32;
    end
    else begin
        qv_pkt_left_len <= qv_pkt_left_len;
    end
end

//-- q_outbound_pkt_wr_en -- Egress packet write
//-- qv_outbound_pkt_data -- Egress packet data
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_outbound_pkt_wr_en <= 'd0;
        qv_outbound_pkt_data <= 'd0;        
    end
    else if (TRANS_cur_state == TRANS_REQ_s && !i_req_trans_empty && !i_outbound_pkt_prog_full) begin
        q_outbound_pkt_wr_en <= 'd1;
        qv_outbound_pkt_data <= iv_req_trans_data;   
    end
    else if (TRANS_cur_state == TRANS_RESP_s && !i_resp_trans_empty && !i_outbound_pkt_prog_full) begin
        q_outbound_pkt_wr_en <= 'd1;
        qv_outbound_pkt_data <= iv_resp_trans_data;   
    end
    else begin
        q_outbound_pkt_wr_en <= 'd0;
        qv_outbound_pkt_data <= qv_outbound_pkt_data;           
    end
end

//-- o_req_trans_rd_en --
assign o_req_trans_rd_en = (TRANS_cur_state == TRANS_REQ_s) && !i_req_trans_empty && !i_outbound_pkt_prog_full;

//-- o_resp_trans_rd_en --
assign o_resp_trans_rd_en = (TRANS_cur_state == TRANS_RESP_s) && !i_resp_trans_empty && !i_outbound_pkt_prog_full;


/*------------------------------------------- Connect dbg signals --------------------------------------------*/
wire   [`DBG_NUM_EGRESS_ARBITER * 32 - 1 : 0]   coalesced_bus;

assign coalesced_bus = {
                            q_outbound_pkt_wr_en,
                            qv_outbound_pkt_data,
                            q_last_sch_type,
                            qv_pkt_left_len,
                            qv_transport_pkt_len,
                            qv_opcode,
                            qv_payload_len,
                            TRANS_cur_state,
                            TRANS_next_state
                        };

assign dbg_bus =    (dbg_sel == 0)  ?   coalesced_bus[32 * 1 - 1 : 32 * 0] :
                    (dbg_sel == 1)  ?   coalesced_bus[32 * 2 - 1 : 32 * 1] :
                    (dbg_sel == 2)  ?   coalesced_bus[32 * 3 - 1 : 32 * 2] :
                    (dbg_sel == 3)  ?   coalesced_bus[32 * 4 - 1 : 32 * 3] :
                    (dbg_sel == 4)  ?   coalesced_bus[32 * 5 - 1 : 32 * 4] :
                    (dbg_sel == 5)  ?   coalesced_bus[32 * 6 - 1 : 32 * 5] :
                    (dbg_sel == 6)  ?   coalesced_bus[32 * 7 - 1 : 32 * 6] :
                    (dbg_sel == 7)  ?   coalesced_bus[32 * 8 - 1 : 32 * 7] :
                    (dbg_sel == 8)  ?   coalesced_bus[32 * 9 - 1 : 32 * 8] :
                    (dbg_sel == 9)  ?   coalesced_bus[32 * 10 - 1 : 32 * 9] : 32'd0;

//assign dbg_bus = coalesced_bus;

endmodule
