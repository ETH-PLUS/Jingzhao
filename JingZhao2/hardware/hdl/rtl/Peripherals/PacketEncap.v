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
module PacketEncap #(
    parameter       HEADER_BUS_WIDTH        =   512,
    parameter       PAYLOAD_BUS_WIDTH       =   512,
    parameter       KEEP_BUS_WIDTH          =   64
)
(
    input   wire                                            clk,
    input   wire                                            rst,

    input   wire                                            i_packet_in_valid,
    //Head Format
    //{31B Header + 2B Payload Length + 1B Header Length}
    input   wire        [HEADER_BUS_WIDTH - 1 : 0]          iv_packet_in_head,
    input   wire        [PAYLOAD_BUS_WIDTH - 1 : 0]         iv_packet_in_data,
    input   wire        [KEEP_BUS_WIDTH - 1 : 0]            iv_packet_in_keep,
    input   wire                                            i_packet_in_start,
    input   wire                                            i_packet_in_last,
    output  wire                                            o_packet_in_ready,

    output  wire                                            o_packet_out_valid,
    output  wire        [HEADER_BUS_WIDTH - 1 : 0]          ov_packet_out_head,
    output  wire        [PAYLOAD_BUS_WIDTH - 1 : 0]         ov_packet_out_data,
    output  wire        [KEEP_BUS_WIDTH - 1 : 0]            ov_packet_out_keep,
    output  wire                                            o_packet_out_start,
    output  wire                                            o_packet_out_last,
    input   wire                                            i_packet_out_ready
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
reg                 [31:0]              qv_unwritten_len;
reg                 [31:0]              qv_total_len;
reg                 [31:0]              qv_left_len;
reg                 [511:0]             qv_unwritten_data;

reg                 [HEADER_BUS_WIDTH - 1 : 0]          qv_packet_in_head;

reg                 [511:0]             qv_packet_out_data;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
//Null
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
reg                 [2:0]               encap_cur_state;
reg                 [2:0]               encap_next_state;

parameter           [2:0]               ENCAP_IDLE_s = 3'd1,
                                        ENCAP_TRANS_s = 3'd2;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        encap_cur_state <= ENCAP_IDLE_s;
    end
    else begin
        encap_cur_state <= encap_next_state;
    end
end    

always @(*) begin
    case(encap_cur_state)
        ENCAP_IDLE_s:           if(i_packet_in_valid) begin
                                    encap_next_state = ENCAP_TRANS_s;
                                end
                                else begin
                                    encap_next_state = ENCAP_IDLE_s;
                                end
        ENCAP_TRANS_s:          if(qv_unwritten_len + qv_left_len <= 64) begin
                                    if(qv_left_len == 0 && i_packet_out_ready) begin
                                        encap_next_state = ENCAP_IDLE_s;
                                    end
                                    else if(qv_left_len > 0 && i_packet_in_valid && i_packet_out_ready) begin
                                        encap_next_state = ENCAP_IDLE_s;
                                    end
                                    else begin
                                        encap_next_state = ENCAP_TRANS_s;
                                    end
                                end
        default:                encap_next_state = ENCAP_IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- qv_total_len --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_total_len <= 'd0;
    end
    else if(encap_cur_state == ENCAP_IDLE_s && i_packet_in_valid) begin
        qv_total_len <= i_packet_in_valid ? iv_packet_in_head[23:8] + iv_packet_in_head[7:0] : 'd0;
    end
    else begin
        qv_total_len <= qv_total_len;
    end
end

//-- qv_packet_in_head --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_packet_in_head <= 'd0;
    end
    else if(encap_cur_state == ENCAP_IDLE_s) begin
        qv_packet_in_head <= i_packet_in_valid ? iv_packet_in_head : 'd0;
    end
    else begin
        qv_packet_in_head <= qv_packet_in_head;
    end
end

//-- qv_left_len --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_left_len <= 'd0;
    end
    else if(encap_cur_state == ENCAP_IDLE_s && i_packet_in_valid) begin
        qv_left_len <= iv_packet_in_head[23:8];
    end
    else if(encap_cur_state == ENCAP_TRANS_s && i_packet_in_valid && i_packet_out_ready) begin
        if(qv_left_len > 64) begin
            qv_left_len <= qv_left_len - 'd64;
        end
        else begin
            qv_left_len <= 'd0;
        end
    end
    else begin
        qv_left_len <= qv_left_len;
    end
end

//-- qv_unwritten_len --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_unwritten_len <= 'd0;
    end
    else if(encap_cur_state == ENCAP_IDLE_s && i_packet_in_valid) begin
        qv_unwritten_len <= iv_packet_in_head[7:0];
    end
    else if(encap_cur_state == ENCAP_TRANS_s) begin
        if(qv_unwritten_len + qv_left_len <= 64) begin
            if(qv_left_len == 0 && i_packet_out_ready) begin
                qv_unwritten_len <= 'd0;
            end
            else if(qv_left_len > 0 && i_packet_in_valid && i_packet_out_ready) begin
                qv_unwritten_len <= 'd0;
            end
            else begin
                qv_unwritten_len <= qv_unwritten_len;
            end
        end
        else begin
            if(qv_left_len > 64 && i_packet_in_valid && i_packet_out_ready) begin
                qv_unwritten_len <= qv_unwritten_len;
            end
            else if(qv_left_len <= 64 && i_packet_in_valid && i_packet_out_ready) begin
                qv_unwritten_len <= (qv_unwritten_len + qv_left_len) - 64;
            end
            else begin
                qv_unwritten_len <= qv_unwritten_len;
            end
        end
    end
    else begin
        qv_unwritten_len <= qv_unwritten_len;
    end
end

//-- qv_unwritten_data --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_unwritten_data <= 'd0;
    end
    else if(encap_cur_state == ENCAP_IDLE_s && i_packet_in_valid) begin
        qv_unwritten_data <= iv_packet_in_head[511:0];
    end
    else if(encap_cur_state == ENCAP_TRANS_s) begin
        if(qv_unwritten_len + qv_left_len <= 64) begin
            if(qv_left_len == 0 && i_packet_out_ready) begin
                qv_unwritten_data <= 'd0;
            end
            else if(qv_left_len > 0 && i_packet_in_valid && i_packet_out_ready) begin
                qv_unwritten_data <= 'd0;
            end
            else begin
                qv_unwritten_data <= qv_unwritten_data;
            end
        end
        else if(i_packet_out_ready) begin
            case(qv_unwritten_len)
                0   :       qv_unwritten_data <= 'd0;
                1   :       qv_unwritten_data <= { {((64 - 1 ) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 1  * 8]};
                2   :       qv_unwritten_data <= { {((64 - 2 ) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 2  * 8]};
                3   :       qv_unwritten_data <= { {((64 - 3 ) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 3  * 8]};
                4   :       qv_unwritten_data <= { {((64 - 4 ) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 4  * 8]};
                5   :       qv_unwritten_data <= { {((64 - 5 ) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 5  * 8]};
                6   :       qv_unwritten_data <= { {((64 - 6 ) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 6  * 8]};
                7   :       qv_unwritten_data <= { {((64 - 7 ) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 7  * 8]};
                8   :       qv_unwritten_data <= { {((64 - 8 ) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 8  * 8]};
                9   :       qv_unwritten_data <= { {((64 - 9 ) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 9  * 8]};
                10  :       qv_unwritten_data <= { {((64 - 10) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 10 * 8]};
                11  :       qv_unwritten_data <= { {((64 - 11) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 11 * 8]};
                12  :       qv_unwritten_data <= { {((64 - 12) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 12 * 8]};
                13  :       qv_unwritten_data <= { {((64 - 13) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 13 * 8]};
                14  :       qv_unwritten_data <= { {((64 - 14) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 14 * 8]};
                15  :       qv_unwritten_data <= { {((64 - 15) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 15 * 8]};
                16  :       qv_unwritten_data <= { {((64 - 16) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 16 * 8]};
                17  :       qv_unwritten_data <= { {((64 - 17) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 17 * 8]};
                18  :       qv_unwritten_data <= { {((64 - 18) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 18 * 8]};
                19  :       qv_unwritten_data <= { {((64 - 19) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 19 * 8]};
                20  :       qv_unwritten_data <= { {((64 - 20) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 20 * 8]};
                21  :       qv_unwritten_data <= { {((64 - 21) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 21 * 8]};
                22  :       qv_unwritten_data <= { {((64 - 22) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 22 * 8]};
                23  :       qv_unwritten_data <= { {((64 - 23) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 23 * 8]};
                24  :       qv_unwritten_data <= { {((64 - 24) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 24 * 8]};
                25  :       qv_unwritten_data <= { {((64 - 25) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 25 * 8]};
                26  :       qv_unwritten_data <= { {((64 - 26) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 26 * 8]};
                27  :       qv_unwritten_data <= { {((64 - 27) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 27 * 8]};
                28  :       qv_unwritten_data <= { {((64 - 28) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 28 * 8]};
                29  :       qv_unwritten_data <= { {((64 - 29) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 29 * 8]};
                30  :       qv_unwritten_data <= { {((64 - 30) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 30 * 8]};
                31  :       qv_unwritten_data <= { {((64 - 31) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 31 * 8]};
                32  :       qv_unwritten_data <= { {((64 - 32) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 32 * 8]};
                33  :       qv_unwritten_data <= { {((64 - 33) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 33 * 8]};
                34  :       qv_unwritten_data <= { {((64 - 34) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 34 * 8]};
                35  :       qv_unwritten_data <= { {((64 - 35) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 35 * 8]};
                36  :       qv_unwritten_data <= { {((64 - 36) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 36 * 8]};
                37  :       qv_unwritten_data <= { {((64 - 37) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 37 * 8]};
                38  :       qv_unwritten_data <= { {((64 - 38) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 38 * 8]};
                39  :       qv_unwritten_data <= { {((64 - 39) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 39 * 8]};
                40  :       qv_unwritten_data <= { {((64 - 40) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 40 * 8]};
                41  :       qv_unwritten_data <= { {((64 - 41) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 41 * 8]};
                42  :       qv_unwritten_data <= { {((64 - 42) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 42 * 8]};
                43  :       qv_unwritten_data <= { {((64 - 43) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 43 * 8]};
                44  :       qv_unwritten_data <= { {((64 - 44) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 44 * 8]};
                45  :       qv_unwritten_data <= { {((64 - 45) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 45 * 8]};
                46  :       qv_unwritten_data <= { {((64 - 46) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 46 * 8]};
                47  :       qv_unwritten_data <= { {((64 - 47) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 47 * 8]};
                48  :       qv_unwritten_data <= { {((64 - 48) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 48 * 8]};
                49  :       qv_unwritten_data <= { {((64 - 49) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 49 * 8]};
                50  :       qv_unwritten_data <= { {((64 - 50) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 50 * 8]};
                51  :       qv_unwritten_data <= { {((64 - 51) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 51 * 8]};
                52  :       qv_unwritten_data <= { {((64 - 52) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 52 * 8]};
                53  :       qv_unwritten_data <= { {((64 - 53) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 53 * 8]};
                54  :       qv_unwritten_data <= { {((64 - 54) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 54 * 8]};
                55  :       qv_unwritten_data <= { {((64 - 55) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 55 * 8]};
                56  :       qv_unwritten_data <= { {((64 - 56) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 56 * 8]};
                57  :       qv_unwritten_data <= { {((64 - 57) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 57 * 8]};
                58  :       qv_unwritten_data <= { {((64 - 58) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 58 * 8]};
                59  :       qv_unwritten_data <= { {((64 - 59) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 59 * 8]};
                60  :       qv_unwritten_data <= { {((64 - 60) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 60 * 8]};
                61  :       qv_unwritten_data <= { {((64 - 61) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 61 * 8]};
                62  :       qv_unwritten_data <= { {((64 - 62) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 62 * 8]};
                63  :       qv_unwritten_data <= { {((64 - 63) * 8){1'b0}}, iv_packet_in_data[511 : 512 - 63 * 8]};
                default:    qv_unwritten_data <= qv_unwritten_data;
            endcase
        end
        else begin
            qv_unwritten_data <= qv_unwritten_data;
        end
    end
    else begin
        qv_unwritten_data <= qv_unwritten_data;
    end
end

//-- o_packet_in_ready --
assign o_packet_in_ready = (encap_cur_state == ENCAP_TRANS_s) && i_packet_out_ready;

//-- o_packet_out_valid --
assign o_packet_out_valid = (encap_cur_state == ENCAP_TRANS_s) && ((qv_left_len > 0 && i_packet_in_valid) || (qv_left_len == 'd0));

//-- ov_packet_out_head --
assign ov_packet_out_head = ((encap_cur_state == ENCAP_TRANS_s) && o_packet_out_start) ? iv_packet_in_head : 'd0;

//-- o_packet_out_start --
assign o_packet_out_start = (encap_cur_state == ENCAP_TRANS_s) && (qv_unwritten_len + qv_left_len == qv_total_len);

//-- o_packet_out_last --
assign o_packet_out_last = (encap_cur_state == ENCAP_TRANS_s) && (qv_unwritten_len + qv_left_len <= 64) && 
                                    ((qv_left_len == 0) || (qv_left_len > 0 && i_packet_in_valid));

//-- ov_packet_out_data --
assign ov_packet_out_data = qv_packet_out_data;

//-- qv_packet_out_data --
always @(*) begin
    if(rst) begin
        qv_packet_out_data = 'd0;
    end
    else if(encap_cur_state == ENCAP_TRANS_s) begin
        case(qv_unwritten_len)
            0   :       qv_packet_out_data = iv_packet_in_data;
            1   :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[1  * 8 - 1 : 0]};
            2   :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[2  * 8 - 1 : 0]};
            3   :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[3  * 8 - 1 : 0]};
            4   :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[4  * 8 - 1 : 0]};
            5   :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[5  * 8 - 1 : 0]};
            6   :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[6  * 8 - 1 : 0]};
            7   :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[7  * 8 - 1 : 0]};
            8   :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[8  * 8 - 1 : 0]};
            9   :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[9  * 8 - 1 : 0]};
            10  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[10 * 8 - 1 : 0]};
            11  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[11 * 8 - 1 : 0]};
            12  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[12 * 8 - 1 : 0]};
            13  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[13 * 8 - 1 : 0]};
            14  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[14 * 8 - 1 : 0]};
            15  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[15 * 8 - 1 : 0]};
            16  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[16 * 8 - 1 : 0]};
            17  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[17 * 8 - 1 : 0]};
            18  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[18 * 8 - 1 : 0]};
            19  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[19 * 8 - 1 : 0]};
            20  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[20 * 8 - 1 : 0]};
            21  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[21 * 8 - 1 : 0]};
            22  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[22 * 8 - 1 : 0]};
            23  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[23 * 8 - 1 : 0]};
            24  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[24 * 8 - 1 : 0]};
            25  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[25 * 8 - 1 : 0]};
            26  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[26 * 8 - 1 : 0]};
            27  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[27 * 8 - 1 : 0]};
            28  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[28 * 8 - 1 : 0]};
            29  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[29 * 8 - 1 : 0]};
            30  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[30 * 8 - 1 : 0]};
            31  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[31 * 8 - 1 : 0]};
            32  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[32 * 8 - 1 : 0]};
            33  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[33 * 8 - 1 : 0]};
            34  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[34 * 8 - 1 : 0]};
            35  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[35 * 8 - 1 : 0]};
            36  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[36 * 8 - 1 : 0]};
            37  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[37 * 8 - 1 : 0]};
            38  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[38 * 8 - 1 : 0]};
            39  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[39 * 8 - 1 : 0]};
            40  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[40 * 8 - 1 : 0]};
            41  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[41 * 8 - 1 : 0]};
            42  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[42 * 8 - 1 : 0]};
            43  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[43 * 8 - 1 : 0]};
            44  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[44 * 8 - 1 : 0]};
            45  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[45 * 8 - 1 : 0]};
            46  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[46 * 8 - 1 : 0]};
            47  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[47 * 8 - 1 : 0]};
            48  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[48 * 8 - 1 : 0]};
            49  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[49 * 8 - 1 : 0]};
            50  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[50 * 8 - 1 : 0]};
            51  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[51 * 8 - 1 : 0]};
            52  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[52 * 8 - 1 : 0]};
            53  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[53 * 8 - 1 : 0]};
            54  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[54 * 8 - 1 : 0]};
            55  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[55 * 8 - 1 : 0]};
            56  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[56 * 8 - 1 : 0]};
            57  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[57 * 8 - 1 : 0]};
            58  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[58 * 8 - 1 : 0]};
            59  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[59 * 8 - 1 : 0]};
            60  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[60 * 8 - 1 : 0]};
            61  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[61 * 8 - 1 : 0]};
            62  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[62 * 8 - 1 : 0]};
            63  :       qv_packet_out_data = {iv_packet_in_data, qv_unwritten_data[63 * 8 - 1 : 0]}; 
            default:    qv_packet_out_data = qv_packet_out_data;
        endcase
    end
    else begin
        qv_packet_out_data = qv_packet_out_data;
    end
end

/*------------------------------------------- Variables Decode : End ------------------------------------------------*/

endmodule