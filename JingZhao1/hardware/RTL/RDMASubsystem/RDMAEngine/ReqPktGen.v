`timescale 1ns / 1ps

`include "ib_constant_def_h.vh"

module ReqPktGen(
    input   wire                clk,
    input   wire                rst,

//Interface with RequesterTransControl
    input   wire                i_tc_header_empty,
    input   wire    [319:0]     iv_tc_header_data,
    output  wire                o_tc_header_rd_en,

    input   wire                i_tc_nd_empty,
    input   wire    [255:0]     iv_tc_nd_data,
    output  wire                o_tc_nd_rd_en,

//RequesterRecvControl
    input   wire                i_rc_header_empty,
    input   wire    [319:0]     iv_rc_header_data,
    output  wire                o_rc_header_rd_en,

    input   wire                i_rc_nd_empty,
    input   wire    [255:0]     iv_rc_nd_data,
    output  wire                o_rc_nd_rd_en,

//BitWidthTrans
    input   wire                i_trans_prog_full,
    output  wire                o_trans_wr_en,
    output  wire    [255:0]     ov_trans_data,

    input   wire    [31:0]      dbg_sel,
    output  wire    [32 - 1 :0]      dbg_bus
    //output  wire    [`DBG_NUM_REQ_PKT_GEN * 32 - 1 :0]      dbg_bus
);
/*----------------------------------------  Part 1: Signals Definition and Submodules Connection ----------------------------------------*/
reg                     q_tc_header_rd_en;
reg                     q_tc_nd_rd_en;

reg                     q_rc_header_rd_en;
reg                     q_rc_nd_rd_en;

reg                     q_trans_wr_en;
reg     [255:0]         qv_trans_data;


assign o_tc_header_rd_en = q_tc_header_rd_en;
assign o_tc_nd_rd_en = q_tc_nd_rd_en;

assign o_rc_header_rd_en = q_rc_header_rd_en;

assign o_rc_nd_rd_en = q_rc_nd_rd_en;

assign o_trans_wr_en = q_trans_wr_en;
assign ov_trans_data = qv_trans_data;

reg     [31:0]        qv_unwritten_len;
reg     [255:0]       qv_unwritten_data;
reg     [31:0]        qv_pkt_left_len;


wire    [7:0]       wv_opcode;

reg                 q_sch_flag;
reg                 q_cur_is_rtc;
reg     [7:0]       qv_header_len;
wire    [12:0]      wv_payload_len;

reg                 q_atomics_counter;

reg     [7:0]       qv_header_len_reg;



/*----------------------------------------  Part 2: State Machine Transition ------------------------------------------------------------*/
reg     [4:0]       RPG_cur_state;
reg     [4:0]       RPG_next_state;

parameter   [4:0]   RPG_IDLE_s          = 5'b00001,
                    RPG_RTC_HEADER_s    = 5'b00010,
                    RPG_RTC_PAYLOAD_s   = 5'b00100,
                    RPG_RRC_HEADER_s    = 5'b01000,
                    RPG_RRC_PAYLOAD_s   = 5'b10000;   

always @(posedge clk or posedge rst) begin
    if (rst) begin
        RPG_cur_state <= RPG_IDLE_s;
    end
    else begin
        RPG_cur_state <= RPG_next_state;
    end
end  

always @(*) begin
    case(RPG_cur_state) 
        RPG_IDLE_s:         if(q_sch_flag == 1) begin
                                if(!i_rc_header_empty) begin
                                    RPG_next_state = RPG_RRC_HEADER_s;
                                end
                                else if(!i_tc_header_empty) begin
                                    RPG_next_state = RPG_RTC_HEADER_s;
                                end
                                else begin
                                    RPG_next_state = RPG_IDLE_s;
                                end
                            end
                            else begin
                                if(!i_tc_header_empty) begin
                                    RPG_next_state = RPG_RTC_HEADER_s;
                                end
                                else if(!i_rc_header_empty) begin
                                    RPG_next_state = RPG_RRC_HEADER_s;
                                end
                                else begin
                                    RPG_next_state = RPG_IDLE_s;
                                end                             
                            end
        RPG_RTC_HEADER_s:   if(wv_opcode[4:0] == `FETCH_AND_ADD || wv_opcode[4:0] == `CMP_AND_SWAP) begin //Atomics has 40Byte header, which crosses 32B boundary
                                if(!i_trans_prog_full) begin
                                    if(q_atomics_counter) begin
                                        RPG_next_state = RPG_IDLE_s;
                                    end
                                    else begin
                                        RPG_next_state = RPG_RTC_HEADER_s;
                                    end
                                end
                                else begin
                                    RPG_next_state = RPG_RTC_HEADER_s;
                                end
                            end
                            else if(wv_payload_len == 0) begin //No payload to carry
                                if(!i_trans_prog_full) begin
                                    RPG_next_state = RPG_IDLE_s;
                                end
                                else begin
                                    RPG_next_state = RPG_RTC_HEADER_s;
                                end
                            end
                            else begin  //Need to carry payload
                                if(!i_tc_nd_empty && !i_trans_prog_full) begin
                                    if(qv_header_len + wv_payload_len <= 32) begin
                                        RPG_next_state = RPG_IDLE_s;    //Header and Payload do not cross 32B boundary
                                    end
                                    else begin  //Multiple cycles to write payload
                                        RPG_next_state = RPG_RTC_PAYLOAD_s;
                                    end
                                end
                                else begin
                                    RPG_next_state = RPG_RTC_HEADER_s;
                                end
                            end
        RPG_RTC_PAYLOAD_s:  if(qv_pkt_left_len == 0) begin 
                                if(!i_trans_prog_full) begin
                                    RPG_next_state = RPG_IDLE_s;
                                end
                                else begin
                                    RPG_next_state = RPG_RTC_PAYLOAD_s;
                                end
                            end  
                            else if(qv_unwritten_len + qv_pkt_left_len <= 32) begin
                                if(!i_tc_nd_empty && !i_trans_prog_full) begin
                                    RPG_next_state = RPG_IDLE_s;
                                end 
                                else begin
                                    RPG_next_state = RPG_RTC_PAYLOAD_s;
                                end
                            end
                            else begin
                                RPG_next_state = RPG_RTC_PAYLOAD_s;
                            end
        RPG_RRC_HEADER_s:   if(wv_opcode[4:0] == `FETCH_AND_ADD || wv_opcode[4:0] == `CMP_AND_SWAP) begin //Atomics has 40Byte header, which crosses 32B boundary
                                if(!i_trans_prog_full) begin
                                    if(q_atomics_counter) begin
                                        RPG_next_state = RPG_IDLE_s;
                                    end
                                    else begin
                                        RPG_next_state = RPG_RRC_HEADER_s;
                                    end
                                end
                                else begin
                                    RPG_next_state = RPG_RRC_HEADER_s;
                                end
                            end
                            else if(wv_payload_len == 0) begin //No payload to carry
                                if(!i_trans_prog_full) begin
                                    RPG_next_state = RPG_IDLE_s;
                                end
                                else begin
                                    RPG_next_state = RPG_RRC_HEADER_s;
                                end
                            end
                            else begin  //Need to carry payload
                                if(!i_rc_nd_empty && !i_trans_prog_full) begin
                                    if(qv_header_len + wv_payload_len <= 32) begin
                                        RPG_next_state = RPG_IDLE_s;    //Header and Payload do not cross 32B boundary
                                    end
                                    else begin  //Multiple cycles to write payload
                                        RPG_next_state = RPG_RRC_PAYLOAD_s;
                                    end
                                end
                                else begin
                                    RPG_next_state = RPG_RRC_HEADER_s;
                                end
                            end
        RPG_RRC_PAYLOAD_s:  if(qv_pkt_left_len == 0) begin 
                                if(!i_trans_prog_full) begin
                                    RPG_next_state = RPG_IDLE_s;
                                end
                                else begin
                                    RPG_next_state = RPG_RRC_PAYLOAD_s;
                                end
                            end  
                            else if(qv_unwritten_len + qv_pkt_left_len <= 32) begin
                                if(!i_rc_nd_empty && !i_trans_prog_full) begin
                                    RPG_next_state = RPG_IDLE_s;
                                end 
                                else begin
                                    RPG_next_state = RPG_RRC_PAYLOAD_s;
                                end
                            end
                            else begin
                                RPG_next_state = RPG_RRC_PAYLOAD_s;
                            end
        /*Spyglass Add Begin*/
        default:            RPG_next_state = RPG_IDLE_s;
        /*Spyglass Add End*/
    endcase
end

/*----------------------------------------  Part 3: Output Registers Decode -------------------------------------------------------------*/
assign wv_opcode = q_cur_is_rtc ? iv_tc_header_data[31:24] : iv_rc_header_data[31:24];


always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_header_len_reg <= 'd0;        
    end
    else begin
        qv_header_len_reg <= qv_header_len;
    end
end

always @(*) begin
    if(RPG_cur_state == RPG_RTC_HEADER_s || RPG_cur_state == RPG_RRC_HEADER_s) begin
        case(wv_opcode[4:0])
            `SEND_FIRST                 :   qv_header_len = 12;  
            `SEND_MIDDLE                :   qv_header_len = 12;  
            `SEND_LAST                  :   qv_header_len = 12;  
            `SEND_LAST_WITH_IMM         :   qv_header_len = 16;  
            `SEND_ONLY                  :   qv_header_len = 12 + (wv_opcode[7:5] == `UD ? 16 : 0);  
            `SEND_ONLY_WITH_IMM         :   qv_header_len = 16 + (wv_opcode[7:5] == `UD ? 16 : 0);  
            `RDMA_WRITE_FIRST           :   qv_header_len = 28;  
            `RDMA_WRITE_MIDDLE          :   qv_header_len = 12;  
            `RDMA_WRITE_LAST            :   qv_header_len = 12;  
            `RDMA_WRITE_LAST_WITH_IMM   :   qv_header_len = 16;  
            `RDMA_WRITE_ONLY            :   qv_header_len = 28;  
            `RDMA_WRITE_ONLY_WITH_IMM   :   qv_header_len = 32;  
            `RDMA_READ_REQUEST          :   qv_header_len = 28;  
            `CMP_AND_SWAP               :   qv_header_len = 40;  
            `FETCH_AND_ADD              :   qv_header_len = 40; 
            default                     :   qv_header_len = 0;  
        endcase
    end 
    else begin
        qv_header_len = qv_header_len_reg;
    end
end

assign wv_payload_len = q_cur_is_rtc ? {iv_tc_header_data[94:88], iv_tc_header_data[61:56]} : {iv_rc_header_data[94:88], iv_rc_header_data[61:56]};

//-- w_trans_finish -- Useless
// assign w_trans_finish = (((q_sch_flag == 1'b1) && !i_tc_header_empty && !i_tc_nd_empty) ||  ((q_sch_flag == 1'b0) && !i_rc_header_empty && !i_rc_nd_empty))
//                         && !i_trans_prog_full && qv_pkt_left_len == 0;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_sch_flag <= 1'b0;        
    end
    else if (RPG_cur_state != RPG_IDLE_s && RPG_next_state == RPG_IDLE_s) begin
        if(RPG_cur_state == RPG_RTC_HEADER_s || RPG_cur_state == RPG_RTC_PAYLOAD_s) begin
            q_sch_flag <= 1'b1;
        end
        else if(RPG_cur_state == RPG_RRC_HEADER_s || RPG_cur_state == RPG_RRC_PAYLOAD_s) begin
            q_sch_flag <= 1'b0;
        end
        else begin
            q_sch_flag <= q_sch_flag;
        end
    end
    else begin
        q_sch_flag <= q_sch_flag;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_cur_is_rtc <= 1'b0;        
    end
    else if (RPG_cur_state == RPG_IDLE_s && RPG_next_state != RPG_IDLE_s) begin 
        if (q_sch_flag == 1) begin
            q_cur_is_rtc <= i_rc_header_empty ? 1 : 0;
        end
        else begin
            q_cur_is_rtc <= i_tc_header_empty ? 0 : 1;
        end
    end 
    else begin
        q_cur_is_rtc <= q_cur_is_rtc;
    end
end

//-- qv_unwritten_len --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_unwritten_len <= 'd0;        
    end
    else if(RPG_cur_state == RPG_RRC_HEADER_s || RPG_cur_state == RPG_RTC_HEADER_s) begin
        if(qv_header_len + wv_payload_len <= 32) begin
            qv_unwritten_len <= 'd0;        //One cycle written, qv_unwritten_len does not has any effect
        end
        else begin
            qv_unwritten_len <= qv_header_len;
        end
    end
    else if(RPG_cur_state == RPG_RTC_PAYLOAD_s) begin
        qv_unwritten_len <= qv_unwritten_len;
    end
    else begin
        qv_unwritten_len <= qv_unwritten_len;
    end
end

//-- qv_unwritten_data -- //Incomplete control logic
// always @(posedge clk or posedge rst) begin
//     if (rst) begin
//         qv_unwritten_data <= 'd0;        
//     end
//     else if(RPG_cur_state == RPG_RTC_HEADER_s || RPG_cur_state == RPG_RRC_HEADER_s || RPG_cur_state == RPG_RTC_PAYLOAD_s || RPG_cur_state == RPG_RRC_PAYLOAD_s) begin
//         case(qv_header_len)     
//             12:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 12) * 8] : iv_rc_nd_data[255 : 12 * 8];
//             16:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 16) * 8] : iv_rc_nd_data[255 : 16 * 8];
//             20:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 20) * 8] : iv_rc_nd_data[255 : 20 * 8];
//             24:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 24) * 8] : iv_rc_nd_data[255 : 24 * 8];
//             28:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 28) * 8] : iv_rc_nd_data[255 : 28 * 8];
//             30:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 30) * 8] : iv_rc_nd_data[255 : 30 * 8];
//             32:         qv_unwritten_data <= qv_unwritten_data;   //Special case
//             default:    qv_unwritten_data <= qv_unwritten_data;
//         endcase
//     end
//     else begin
//         qv_unwritten_data <= qv_unwritten_data;
//     end
// end

//-- qv_unwritten_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_unwritten_data <= 'd0;        
    end
    else if(RPG_cur_state == RPG_RTC_HEADER_s) begin
        if(wv_opcode[4:0] == `CMP_AND_SWAP || wv_opcode[4:0] == `FETCH_AND_ADD) begin
            qv_unwritten_data <= qv_unwritten_data;         //Aotmics does not need store unwritten data
        end
        else begin
            if(wv_payload_len + qv_header_len <= 32) begin
                qv_unwritten_data <= qv_unwritten_data;
            end
            else if(!i_trans_prog_full && !i_tc_nd_empty) begin
                case(qv_header_len)     
                    12:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 12) * 8] : iv_rc_nd_data[255 : 12 * 8];
                    16:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 16) * 8] : iv_rc_nd_data[255 : 16 * 8];
                    20:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 20) * 8] : iv_rc_nd_data[255 : 20 * 8];
                    24:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 24) * 8] : iv_rc_nd_data[255 : 24 * 8];
                    28:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 28) * 8] : iv_rc_nd_data[255 : 28 * 8];
                    30:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 30) * 8] : iv_rc_nd_data[255 : 30 * 8];
                    32:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data : iv_rc_nd_data;   //Special case
                    default:    qv_unwritten_data <= qv_unwritten_data;
                endcase
            end
            else begin
                qv_unwritten_data <= qv_unwritten_data;
            end
        end
    end
    else if(RPG_cur_state == RPG_RRC_HEADER_s) begin
        if(wv_opcode[4:0] == `CMP_AND_SWAP || wv_opcode[4:0] == `FETCH_AND_ADD) begin
            qv_unwritten_data <= qv_unwritten_data;         //Aotmics does not need store unwritten data
        end
        else begin
            if(wv_payload_len + qv_header_len <= 32) begin
                qv_unwritten_data <= qv_unwritten_data;
            end
            else if(!i_trans_prog_full && !i_rc_nd_empty) begin
                case(qv_header_len)     
                    12:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 12) * 8] : iv_rc_nd_data[255 : 12 * 8];
                    16:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 16) * 8] : iv_rc_nd_data[255 : 16 * 8];
                    20:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 20) * 8] : iv_rc_nd_data[255 : 20 * 8];
                    24:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 24) * 8] : iv_rc_nd_data[255 : 24 * 8];
                    28:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 28) * 8] : iv_rc_nd_data[255 : 28 * 8];
                    30:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 30) * 8] : iv_rc_nd_data[255 : 30 * 8];
                    32:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data : iv_rc_nd_data;   //Special case
                    default:    qv_unwritten_data <= qv_unwritten_data;
                endcase
            end
            else begin
                qv_unwritten_data <= qv_unwritten_data;
            end
        end
    end
    else if (RPG_cur_state == RPG_RTC_PAYLOAD_s) begin
        if(qv_pkt_left_len == 0) begin
            qv_unwritten_data <= qv_unwritten_data;
        end
        else begin
            if(!i_trans_prog_full && !i_tc_nd_empty) begin
                case(qv_header_len)     
                    12:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 12) * 8] : iv_rc_nd_data[255 : 12 * 8];
                    16:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 16) * 8] : iv_rc_nd_data[255 : 16 * 8];
                    20:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 20) * 8] : iv_rc_nd_data[255 : 20 * 8];
                    24:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 24) * 8] : iv_rc_nd_data[255 : 24 * 8];
                    28:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 28) * 8] : iv_rc_nd_data[255 : 28 * 8];
                    30:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 30) * 8] : iv_rc_nd_data[255 : 30 * 8];
                    32:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data : iv_rc_nd_data;   //Special case
                    default:    qv_unwritten_data <= qv_unwritten_data;
                endcase
            end
            else begin
                qv_unwritten_data <= qv_unwritten_data;
            end
        end
    end
    else if (RPG_cur_state == RPG_RRC_PAYLOAD_s) begin
        if(qv_pkt_left_len == 0) begin
            qv_unwritten_data <= qv_unwritten_data;
        end
        else begin
            if(!i_trans_prog_full && !i_rc_nd_empty) begin
                case(qv_header_len)     
                    12:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 12) * 8] : iv_rc_nd_data[255 : 12 * 8];
                    16:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 16) * 8] : iv_rc_nd_data[255 : 16 * 8];
                    20:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 20) * 8] : iv_rc_nd_data[255 : 20 * 8];
                    24:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 24) * 8] : iv_rc_nd_data[255 : 24 * 8];
                    28:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 28) * 8] : iv_rc_nd_data[255 : 28 * 8];
                    30:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data[255 : (32 - 30) * 8] : iv_rc_nd_data[255 : 30 * 8];
                    32:         qv_unwritten_data <= q_cur_is_rtc ? iv_tc_nd_data : iv_rc_nd_data;   //Special case
                    default:    qv_unwritten_data <= qv_unwritten_data;
                endcase
            end
            else begin
                qv_unwritten_data <= qv_unwritten_data;
            end
        end
    end
    else begin
        qv_unwritten_data <= qv_unwritten_data;
    end
end

//-- q_trans_wr_en --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_trans_wr_en <= 1'b0;        
    end
    else if (RPG_cur_state == RPG_RTC_HEADER_s) begin
        if(wv_opcode[4:0] == `CMP_AND_SWAP || wv_opcode[4:0] == `FETCH_AND_ADD) begin
            if(q_atomics_counter == 0) begin
                q_trans_wr_en <= !i_trans_prog_full && !i_tc_nd_empty;                
            end
            else begin
                q_trans_wr_en <= !i_trans_prog_full;
            end
        end
        else if(wv_payload_len == 0) begin
            q_trans_wr_en <= !i_trans_prog_full;
        end
        else if(wv_payload_len > 0) begin
            q_trans_wr_en <= !i_trans_prog_full && !i_tc_nd_empty;
        end
        else begin
            q_trans_wr_en <= 1'b0;
        end
    end
    else if (RPG_cur_state == RPG_RRC_HEADER_s) begin
        if(wv_opcode[4:0] == `CMP_AND_SWAP || wv_opcode[4:0] == `FETCH_AND_ADD) begin
            if(q_atomics_counter == 0) begin
                q_trans_wr_en <= !i_trans_prog_full && !i_rc_nd_empty;                
            end
            else begin
                q_trans_wr_en <= !i_trans_prog_full;
            end
        end
        else if(wv_payload_len == 0) begin
            q_trans_wr_en <= !i_trans_prog_full;
        end
        else if(wv_payload_len > 0) begin
            q_trans_wr_en <= !i_trans_prog_full;
        end
        else begin
            q_trans_wr_en <= 1'b0;
        end
    end
    else if (RPG_cur_state == RPG_RTC_PAYLOAD_s) begin
        if(qv_pkt_left_len == 0) begin          //When qv_pkt_left_len is 0, we only need to handle the last qv_unwritten_data and do not need to read new data
            q_trans_wr_en <= !i_trans_prog_full;
        end
        else begin //When qv_pkt_left_len is > 0, we must read new data
            q_trans_wr_en <= !i_trans_prog_full && !i_tc_nd_empty;
        end
    end
    else if(RPG_cur_state == RPG_RRC_PAYLOAD_s) begin
        if(qv_pkt_left_len == 0) begin
            q_trans_wr_en <= !i_trans_prog_full;
        end
        else begin
            q_trans_wr_en <= !i_trans_prog_full && !i_rc_nd_empty;
        end
    end
    else begin
        q_trans_wr_en <= 1'b0;
    end
end

//-- qv_trans_data --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_trans_data <= 'd0;        
    end
    else if (RPG_cur_state == RPG_RRC_HEADER_s || RPG_cur_state == RPG_RTC_HEADER_s) begin
        if(wv_opcode[4:0] == `CMP_AND_SWAP || wv_opcode[4:0] == `FETCH_AND_ADD) begin
            if(q_atomics_counter == 0) begin
                if(!i_trans_prog_full) begin
                    qv_trans_data <= q_cur_is_rtc ? iv_tc_header_data[255:0] : iv_rc_header_data[255:0];
                end
                else begin
                    qv_trans_data <= qv_trans_data;
                end
            end
            else begin
                if(!i_trans_prog_full) begin
                    qv_trans_data <= q_cur_is_rtc ? iv_tc_header_data[319:256] : iv_rc_header_data[319:256];
                end
                else begin
                    qv_trans_data <= qv_trans_data;
                end
            end
        end
        else begin
            if(wv_payload_len == 0) begin   //Only consider header
                if(!i_trans_prog_full) begin
                    qv_trans_data <= q_cur_is_rtc ? iv_tc_header_data : iv_rc_header_data;
                end
                else begin
                    qv_trans_data <= qv_trans_data;
                end
            end 
            else begin
                if(!i_trans_prog_full && ((q_cur_is_rtc && !i_tc_nd_empty) || (!q_cur_is_rtc && !i_rc_nd_empty))) begin
                    case(qv_header_len) 
                        12:     qv_trans_data <= q_cur_is_rtc ? {iv_tc_nd_data[(32 - 12) * 8 - 1 : 0], iv_tc_header_data[12 * 8 - 1 : 0]} : {iv_rc_nd_data[(32 - 12) * 8 - 1 : 0], iv_rc_header_data[12 * 8 - 1 : 0]};
                        16:     qv_trans_data <= q_cur_is_rtc ? {iv_tc_nd_data[(32 - 16) * 8 - 1 : 0], iv_tc_header_data[16 * 8 - 1 : 0]} : {iv_rc_nd_data[(32 - 16) * 8 - 1 : 0], iv_rc_header_data[16 * 8 - 1 : 0]};
                        20:     qv_trans_data <= q_cur_is_rtc ? {iv_tc_nd_data[(32 - 20) * 8 - 1 : 0], iv_tc_header_data[20 * 8 - 1 : 0]} : {iv_rc_nd_data[(32 - 20) * 8 - 1 : 0], iv_rc_header_data[20 * 8 - 1 : 0]};
                        24:     qv_trans_data <= q_cur_is_rtc ? {iv_tc_nd_data[(32 - 24) * 8 - 1 : 0], iv_tc_header_data[24 * 8 - 1 : 0]} : {iv_rc_nd_data[(32 - 24) * 8 - 1 : 0], iv_rc_header_data[24 * 8 - 1 : 0]};
                        28:     qv_trans_data <= q_cur_is_rtc ? {iv_tc_nd_data[(32 - 28) * 8 - 1 : 0], iv_tc_header_data[28 * 8 - 1 : 0]} : {iv_rc_nd_data[(32 - 28) * 8 - 1 : 0], iv_rc_header_data[28 * 8 - 1 : 0]};
                        32:     qv_trans_data <= q_cur_is_rtc ? iv_tc_header_data : iv_rc_header_data;
                        default:qv_trans_data <= qv_trans_data;
                    endcase
                end
                else begin
                    qv_trans_data <= qv_trans_data;
                end
            end
        end
    end
    else if (RPG_cur_state == RPG_RTC_PAYLOAD_s || RPG_cur_state == RPG_RRC_PAYLOAD_s) begin
        if(qv_pkt_left_len > 0) begin 
            if(!i_trans_prog_full && ((q_cur_is_rtc && !i_tc_nd_empty) || (!q_cur_is_rtc && !i_rc_nd_empty))) begin 
                case(qv_unwritten_len) 
                    12:     qv_trans_data <= q_cur_is_rtc ? {iv_tc_nd_data[(32 - 12) * 8 - 1 : 0], qv_unwritten_data[12 * 8 - 1 : 0]} : {iv_rc_nd_data[(32 - 12) * 8 - 1 : 0], qv_unwritten_data[12 * 8 - 1 : 0]};
                    16:     qv_trans_data <= q_cur_is_rtc ? {iv_tc_nd_data[(32 - 16) * 8 - 1 : 0], qv_unwritten_data[16 * 8 - 1 : 0]} : {iv_rc_nd_data[(32 - 16) * 8 - 1 : 0], qv_unwritten_data[16 * 8 - 1 : 0]};
                    20:     qv_trans_data <= q_cur_is_rtc ? {iv_tc_nd_data[(32 - 20) * 8 - 1 : 0], qv_unwritten_data[20 * 8 - 1 : 0]} : {iv_rc_nd_data[(32 - 20) * 8 - 1 : 0], qv_unwritten_data[20 * 8 - 1 : 0]};
                    24:     qv_trans_data <= q_cur_is_rtc ? {iv_tc_nd_data[(32 - 24) * 8 - 1 : 0], qv_unwritten_data[24 * 8 - 1 : 0]} : {iv_rc_nd_data[(32 - 24) * 8 - 1 : 0], qv_unwritten_data[24 * 8 - 1 : 0]};
                    28:     qv_trans_data <= q_cur_is_rtc ? {iv_tc_nd_data[(32 - 28) * 8 - 1 : 0], qv_unwritten_data[28 * 8 - 1 : 0]} : {iv_rc_nd_data[(32 - 28) * 8 - 1 : 0], qv_unwritten_data[28 * 8 - 1 : 0]};
                    32:     qv_trans_data <= qv_unwritten_data;
                    default:qv_trans_data <= qv_trans_data;
                endcase
            end
            else begin
                qv_trans_data <= qv_trans_data;
            end
        end 
        else begin
            if(!i_trans_prog_full) begin
                qv_trans_data <= qv_unwritten_data;                
            end
            else begin
                qv_trans_data <= qv_trans_data;
            end
        end
    end
    else begin
        qv_trans_data <= qv_trans_data;
    end
end

//-- qv_pkt_left_len -- This is a tricky counter, which indicates how many data are still left in the network FIFO, it does not include the qv_unwritten_data/len,
//                      which are already in the temporary registers.    
always @(posedge clk or posedge rst) begin
    if (rst) begin
        qv_pkt_left_len <= 'd0;        
    end
    else if(RPG_cur_state == RPG_RTC_HEADER_s && RPG_next_state == RPG_RTC_PAYLOAD_s) begin
        if(wv_payload_len <= 32) begin
            qv_pkt_left_len <= 'd0;
        end
        else begin
            qv_pkt_left_len <= wv_payload_len - 32;
        end
    end
    else if (RPG_cur_state == RPG_RRC_HEADER_s && RPG_next_state == RPG_RRC_PAYLOAD_s) begin
        if(wv_payload_len <= 32) begin
            qv_pkt_left_len <= 'd0;
        end
        else begin
            qv_pkt_left_len <= wv_payload_len - 32;
        end
    end
    else if (RPG_cur_state == RPG_RTC_PAYLOAD_s && o_tc_nd_rd_en && !i_trans_prog_full) begin
        if(qv_pkt_left_len <= 32) begin
            qv_pkt_left_len <= 0;
        end
        else begin
            qv_pkt_left_len <= qv_pkt_left_len - 32;
        end
    end
    else if (RPG_cur_state == RPG_RRC_PAYLOAD_s && o_rc_nd_rd_en && !i_trans_prog_full) begin
        if(qv_pkt_left_len <= 32) begin
            qv_pkt_left_len <= 0;
        end
        else begin
            qv_pkt_left_len <= qv_pkt_left_len - 32;
        end
    end    
    else begin
        qv_pkt_left_len <= qv_pkt_left_len;
    end
end

//-- q_tc_header_rd_en --
always @(*) begin
    case(RPG_cur_state)
        RPG_RTC_HEADER_s:       if(wv_opcode[4:0] == `CMP_AND_SWAP || wv_opcode[4:0] == `FETCH_AND_ADD) begin
                                    if(q_atomics_counter == 0 && !i_trans_prog_full && !i_tc_header_empty) begin
                                        q_tc_header_rd_en = 1'b1;
                                    end
                                    else begin
                                        q_tc_header_rd_en = !i_trans_prog_full;
                                    end
                                end
                                else begin
									if(wv_payload_len == 0 && !i_trans_prog_full) begin
										q_tc_header_rd_en = 1'b1;
									end 
									else if(wv_payload_len != 0 && !i_tc_nd_empty && !i_trans_prog_full) begin
										q_tc_header_rd_en = 1'b1;
									end 
									else begin
										q_tc_header_rd_en = 1'b0;
									end 
                                end
//        RPG_RTC_PAYLOAD_s:      if(qv_pkt_left_len == 0) begin
//                                    q_tc_header_rd_en = !i_trans_prog_full;
//                                end
//                                else if(qv_unwritten_len + qv_pkt_left_len <= 32) begin
//                                    q_tc_header_rd_en = !i_trans_prog_full && !i_tc_nd_empty;
//                                end
//                                else begin
//                                    q_tc_header_rd_en = 1'b0;
//                                end
        default:                q_tc_header_rd_en = 1'b0;
    endcase
end

//-- q_tc_nd_rd_en --
always @(*) begin
    case(RPG_cur_state)
        RPG_RTC_HEADER_s:       if(wv_payload_len != 0) begin
                                    q_tc_nd_rd_en = !i_trans_prog_full && !i_tc_nd_empty;
                                end
                                else begin
                                    q_tc_nd_rd_en = 1'b0;
                                end
        RPG_RTC_PAYLOAD_s:      if(qv_pkt_left_len > 0) begin
                                    q_tc_nd_rd_en = !i_trans_prog_full && !i_tc_nd_empty;
                                end
                                else begin
                                    q_tc_nd_rd_en = 1'b0;
                                end
        default:                q_tc_nd_rd_en = 1'b0;
    endcase
end

//-- q_atomics_counter --
always @(posedge clk or posedge rst) begin
    if (rst) begin
        q_atomics_counter <= 1'b0;        
    end
    else if (RPG_cur_state == RPG_RTC_HEADER_s || RPG_cur_state == RPG_RRC_HEADER_s) begin
        if(wv_opcode[4:0] == `CMP_AND_SWAP || wv_opcode[4:0] == `FETCH_AND_ADD) begin
            if(q_atomics_counter == 0 && !i_trans_prog_full && !i_rc_header_empty) begin
                q_atomics_counter <= 1'b1;
            end
            else begin
                q_atomics_counter <= 1'b0;
            end
        end
        else begin
            q_atomics_counter <= 1'b0;
        end
    end
    else begin
        q_atomics_counter <= 1'b0;
    end
end

//-- q_rc_header_rd_en --
always @(*) begin
    case(RPG_cur_state)
        RPG_RRC_HEADER_s:       if(wv_opcode[4:0] == `CMP_AND_SWAP || wv_opcode[4:0] == `FETCH_AND_ADD) begin
                                    if(q_atomics_counter == 0 && !i_trans_prog_full && !i_rc_header_empty) begin
                                        q_rc_header_rd_en = 1'b1;
                                    end
                                    else begin
                                        q_rc_header_rd_en = !i_trans_prog_full;
                                    end
                                end
                                else begin
                                    if(wv_payload_len == 0 && !i_trans_prog_full) begin
                                        q_rc_header_rd_en = 1'b1;
                                    end
                                    else if(wv_payload_len != 0 && !i_rc_nd_empty && !i_trans_prog_full) begin
                                        q_rc_header_rd_en = 1'b1;
                                    end
									else begin
										q_rc_header_rd_en = 1'b0;
									end 
                                end
//        RPG_RRC_PAYLOAD_s:      if(qv_pkt_left_len == 0) begin
//                                    q_rc_header_rd_en = !i_trans_prog_full;
//                                end
//                                else if(qv_unwritten_len + qv_pkt_left_len <= 32) begin
//                                    q_rc_header_rd_en = !i_trans_prog_full && !i_rc_nd_empty;
//                                end
//                                else begin
//                                    q_rc_header_rd_en = 1'b0;
//                                end
        default:                q_rc_header_rd_en = 1'b0;
    endcase
end

//-- q_rc_nd_rd_en --
always @(*) begin
    case(RPG_cur_state)
        RPG_RRC_HEADER_s:       if(wv_payload_len != 0) begin
                                    q_rc_nd_rd_en = !i_trans_prog_full && !i_rc_nd_empty;
                                end
                                else begin
                                    q_rc_nd_rd_en = 1'b0;
                                end
        RPG_RRC_PAYLOAD_s:      if(qv_pkt_left_len > 0) begin
                                    q_rc_nd_rd_en = !i_trans_prog_full && !i_rc_nd_empty;
                                end
                                else begin
                                    q_rc_nd_rd_en = 1'b0;
                                end
        default:                q_rc_nd_rd_en = 1'b0;
    endcase
end

/*----------------------------- Connect dbg bus -------------------------------------*/
wire    [`DBG_NUM_REQ_PKT_GEN * 32 - 1 : 0]   coalesced_bus;

assign coalesced_bus = {
                            q_tc_header_rd_en,
                            q_tc_nd_rd_en,
                            q_rc_header_rd_en,
                            q_rc_nd_rd_en,
                            q_trans_wr_en,
                            qv_trans_data,
                            qv_unwritten_len,
                            qv_unwritten_data,
                            qv_pkt_left_len,
                            q_sch_flag,
                            q_cur_is_rtc,
                            qv_header_len,
                            q_atomics_counter,
                            qv_header_len_reg,
                            RPG_cur_state,
                            RPG_next_state,
                            wv_opcode,
                            wv_payload_len
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
                    (dbg_sel == 9)  ?   coalesced_bus[32 * 10 - 1 : 32 * 9] :
                    (dbg_sel == 10) ?   coalesced_bus[32 * 11 - 1 : 32 * 10] :
                    (dbg_sel == 11) ?   coalesced_bus[32 * 12 - 1 : 32 * 11] :
                    (dbg_sel == 12) ?   coalesced_bus[32 * 13 - 1 : 32 * 12] :
                    (dbg_sel == 13) ?   coalesced_bus[32 * 14 - 1 : 32 * 13] :
                    (dbg_sel == 14) ?   coalesced_bus[32 * 15 - 1 : 32 * 14] :
                    (dbg_sel == 15) ?   coalesced_bus[32 * 16 - 1 : 32 * 15] :
                    (dbg_sel == 16) ?   coalesced_bus[32 * 17 - 1 : 32 * 16] :
                    (dbg_sel == 17) ?   coalesced_bus[32 * 18 - 1 : 32 * 17] :
                    (dbg_sel == 18) ?   coalesced_bus[32 * 19 - 1 : 32 * 18] :
                    (dbg_sel == 19) ?   coalesced_bus[32 * 20 - 1 : 32 * 19] : 32'd0;
//assign dbg_bus = coalesced_bus;

endmodule
