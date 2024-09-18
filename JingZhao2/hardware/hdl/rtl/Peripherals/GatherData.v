/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       GatherData
Author:     YangFan
Function:   Gather data from non-contiguous memory page and merge into continuous network stream.
--------------------------------------------- Module Decription : End -----------------------------------------------*/

/*------------------------------------------- Timescale Definition : Begin ------------------------------------------*/
`timescale 1ns / 1ps
/*------------------------------------------- Timescale Definition : End --------------------------------------------*/

/*------------------------------------------- Included Files : Begin ------------------------------------------------*/
`include "protocol_engine_def.vh"
/*------------------------------------------- Included Files : End --------------------------------------------------*/

/*------------------------------------------- Local Macros Definition : Begin ---------------------------------------*/
/*------------------------------------------- Local Macros Definition : End -----------------------------------------*/

/*------------------------------------------- Input/Output Definition : Begin ---------------------------------------*/
module GatherData
(
    input   wire                                                                clk,
    input   wire                                                                rst,
    
    input   wire                                                                gather_req_wr_en,
    input   wire        [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]       gather_req_din,
    output  wire                                                                gather_req_prog_full,
    
    output  wire                                                                dma_rd_req_valid,
    output  wire        [`DMA_HEAD_WIDTH - 1 : 0]                               dma_rd_req_head,
    output  wire        [`DMA_DATA_WIDTH - 1 : 0]                               dma_rd_req_data,
    output  wire                                                                dma_rd_req_last,
    input   wire                                                                dma_rd_req_ready,
    
    input   wire                                                                dma_rd_rsp_valid,
    input   wire        [`DMA_HEAD_WIDTH - 1 : 0]                               dma_rd_rsp_head,
    input   wire        [`DMA_DATA_WIDTH - 1 : 0]                               dma_rd_rsp_data,
    input   wire                                                                dma_rd_rsp_last,
    output  wire                                                                dma_rd_rsp_ready,
    
    input   wire                                                                gather_resp_rd_en,
    output  wire                                                                gather_resp_empty,
    output  wire        [`DMA_DATA_WIDTH - 1 : 0]                               gather_resp_dout
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                                                        gather_req_rd_en;
wire         [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]              gather_req_dout;
wire                                                                        gather_req_empty;

wire                                                                        dma_rd_req_wr_en;
wire         [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]              dma_rd_req_din;
wire                                                                        dma_rd_req_prog_full;
wire                                                                        dma_rd_req_rd_en;
wire         [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]              dma_rd_req_dout;
wire                                                                        dma_rd_req_empty;

reg          [31:0]                                                         qv_total_length_left;
reg          [31:0]                                                         qv_page_length_left;
reg          [31:0]                                                         qv_unwritten_len;
reg          [511:0]                                                        qv_unwritten_data;
wire                                                                        w_last_page_of_req;

reg                                                                         gather_resp_wr_en;
reg          [`DMA_DATA_WIDTH - 1 : 0]                                      gather_resp_din;
wire                                                                        gather_resp_prog_full;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
SyncFIFO_Template #(
    .FIFO_TYPE   (0),
    .FIFO_WIDTH  (`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH),
    .FIFO_DEPTH  (64)
)
gather_req_fifo
(
    .clk(clk),
    .rst(rst),

    .wr_en(gather_req_wr_en),
    .din(gather_req_din),
    .prog_full(gather_req_prog_full),
    .rd_en(gather_req_rd_en),
    .dout(gather_req_dout),
    .empty(gather_req_empty),
    .data_count()
);

SyncFIFO_Template #(
    .FIFO_TYPE   (0),
    .FIFO_WIDTH  (`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH),
    .FIFO_DEPTH  (64)
)
dma_rd_req_fifo
(
    .clk(clk),
    .rst(rst),

    .wr_en(dma_rd_req_wr_en),
    .din(dma_rd_req_din),
    .prog_full(dma_rd_req_prog_full),
    .rd_en(dma_rd_req_rd_en),
    .dout(dma_rd_req_dout),
    .empty(dma_rd_req_empty),
    .data_count()
);

SyncFIFO_Template #(
    .FIFO_TYPE   (0),
    .FIFO_WIDTH  (`DMA_DATA_WIDTH),
    .FIFO_DEPTH  (64)
)
gather_resp_fifo
(
    .clk(clk),
    .rst(rst),

    .wr_en(gather_resp_wr_en),
    .din(gather_resp_din),
    .prog_full(gather_resp_prog_full),
    .rd_en(gather_resp_rd_en),
    .dout(gather_resp_dout),
    .empty(gather_resp_empty),
    .data_count()
);
/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/


/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/

/*DMA Read Response State Machine */
parameter               RESP_IDLE_s = 2'b01,
						RESP_DOWNLOAD_s = 2'b10;

reg                     [1:0]           resp_cur_state;
reg                     [1:0]           resp_next_state;

always @(posedge clk or posedge rst) begin
    if(rst) begin 
        resp_cur_state <= RESP_IDLE_s;
    end
    else begin
        resp_cur_state <= resp_next_state;
    end
end

always @(*) begin
    case(resp_cur_state)
        RESP_IDLE_s:            if(!dma_rd_req_empty) begin
                                        resp_next_state = RESP_DOWNLOAD_s;
                                    end
                                    else begin
                                        resp_next_state = RESP_IDLE_s;
                                    end
        RESP_DOWNLOAD_s:        if(qv_page_length_left + qv_unwritten_len > 64) begin 
                                    resp_next_state = RESP_DOWNLOAD_s;
                                end     
                                else begin // <=64, judge whether need valid signal 
                                    if(qv_page_length_left > 0 && dma_rd_rsp_valid && !gather_resp_prog_full) begin    //Need valid indicator
                                        resp_next_state = RESP_IDLE_s;
                                    end
                                    else if(qv_page_length_left == 0 && !gather_resp_prog_full) begin
                                        resp_next_state = RESP_IDLE_s;
                                    end
                                    else begin
                                        resp_next_state = RESP_DOWNLOAD_s;
                                    end
                                end   
        default:                resp_next_state = RESP_IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/

//-- dma_rd_req_wr_en --
assign dma_rd_req_wr_en = gather_req_rd_en;

//-- dma_rd_req_din --
assign dma_rd_req_din = gather_req_rd_en ? gather_req_dout : 0;

//-- dma_rd_req_valid --
assign dma_rd_req_valid = !gather_req_empty;
//-- dma_rd_req_head --
assign dma_rd_req_head = {'d0, gather_req_dout[63:0], gather_req_dout[95:64]};  //64-bit Addr, 32-bit Size
//-- dma_rd_req_last --
assign dma_rd_req_last = dma_rd_req_valid;
//-- dma_rd_req_data --
assign dma_rd_req_data = 'd0;

//-- gather_req_rd_en --
assign gather_req_rd_en = !gather_req_empty && dma_rd_req_ready && !dma_rd_req_prog_full;

//-- w_last_page_of_req --
assign w_last_page_of_req = (qv_total_length_left == qv_page_length_left);

//-- dma_rd_req_rd_en --
assign dma_rd_req_rd_en = (resp_cur_state == RESP_DOWNLOAD_s) && (qv_page_length_left + qv_unwritten_len <= 64) && !gather_resp_prog_full && 
                                    ((qv_page_length_left > 0 && dma_rd_rsp_valid) || (qv_page_length_left == 0));

//-- dma_rd_rsp_ready --
assign dma_rd_rsp_ready = (resp_cur_state == RESP_DOWNLOAD_s) && !gather_resp_prog_full && (qv_page_length_left > 0);

//-- qv_page_length_left --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_page_length_left <= 'd0;
    end
    else if(resp_cur_state == RESP_IDLE_s && !dma_rd_req_empty) begin
        qv_page_length_left <= dma_rd_req_dout[95:64];
    end
    else if(resp_cur_state == RESP_DOWNLOAD_s) begin
        if(qv_page_length_left > 0 && dma_rd_rsp_valid && !gather_resp_prog_full) begin
            if(qv_page_length_left > 64) begin
                qv_page_length_left <= qv_page_length_left - 64;
            end
            else begin
                qv_page_length_left <= 'd0;
            end
        end
        else begin
            qv_page_length_left <= qv_page_length_left;
        end
    end
    else begin
        qv_page_length_left <= qv_page_length_left;
    end
end

//-- qv_total_length_left --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_total_length_left <= 'd0;
    end
    else if(resp_cur_state == RESP_IDLE_s && !dma_rd_req_empty) begin
        if(qv_total_length_left == 0) begin
            qv_total_length_left <= dma_rd_req_dout[127:96];
        end    
        else begin
            qv_total_length_left <= qv_total_length_left;
        end
    end
    else if(resp_cur_state == RESP_DOWNLOAD_s) begin
        if(qv_page_length_left > 0 && dma_rd_rsp_valid && !gather_resp_prog_full) begin
            if(qv_page_length_left > 64) begin
                qv_total_length_left <= qv_total_length_left - 64;
            end
            else begin
                qv_total_length_left <= qv_total_length_left - qv_page_length_left;
            end
        end
        else begin
            qv_total_length_left <= qv_total_length_left;
        end
    end
    else begin
        qv_total_length_left <= qv_total_length_left;
    end
end

//-- qv_unwritten_len --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_unwritten_len <= 'd0;
    end
    else if(resp_cur_state == RESP_IDLE_s) begin
        qv_unwritten_len <= qv_unwritten_len;
    end
    else if(resp_cur_state == RESP_DOWNLOAD_s) begin //qv_unwritten_len need to consider wthether is the last mtt
        if(qv_page_length_left > 0 && dma_rd_rsp_valid && !gather_resp_prog_full) begin
            if(qv_page_length_left >= 64) begin
                qv_unwritten_len <= qv_unwritten_len;
            end
            else if(qv_page_length_left + qv_unwritten_len >= 64)begin
                qv_unwritten_len <= qv_page_length_left + qv_unwritten_len - 64;
            end
            else begin  
                qv_unwritten_len <= w_last_page_of_req ? 'd0 : (qv_page_length_left + qv_unwritten_len);
            end
        end  
        else if(qv_page_length_left == 0 && !gather_resp_prog_full) begin
            qv_unwritten_len <= w_last_page_of_req ? 'd0 : qv_unwritten_len;
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
    else if(resp_cur_state == RESP_DOWNLOAD_s) begin
        if(qv_page_length_left > 0 && dma_rd_rsp_valid && !gather_resp_prog_full) begin
            if((qv_page_length_left >= 64) || (qv_page_length_left + qv_unwritten_len >= 64)) begin
                case(qv_unwritten_len)
                    0   :           qv_unwritten_data <= 'd0;
                    1   :           qv_unwritten_data <= {{((64 - 1 ) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 1 ) * 8]};
                    2   :           qv_unwritten_data <= {{((64 - 2 ) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 2 ) * 8]};
                    3   :           qv_unwritten_data <= {{((64 - 3 ) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 3 ) * 8]};
                    4   :           qv_unwritten_data <= {{((64 - 4 ) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 4 ) * 8]};
                    5   :           qv_unwritten_data <= {{((64 - 5 ) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 5 ) * 8]};
                    6   :           qv_unwritten_data <= {{((64 - 6 ) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 6 ) * 8]};
                    7   :           qv_unwritten_data <= {{((64 - 7 ) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 7 ) * 8]};
                    8   :           qv_unwritten_data <= {{((64 - 8 ) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 8 ) * 8]};
                    9   :           qv_unwritten_data <= {{((64 - 9 ) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 9 ) * 8]};
                    10  :           qv_unwritten_data <= {{((64 - 10) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 10) * 8]};
                    11  :           qv_unwritten_data <= {{((64 - 11) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 11) * 8]};
                    12  :           qv_unwritten_data <= {{((64 - 12) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 12) * 8]};
                    13  :           qv_unwritten_data <= {{((64 - 13) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 13) * 8]};
                    14  :           qv_unwritten_data <= {{((64 - 14) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 14) * 8]};
                    15  :           qv_unwritten_data <= {{((64 - 15) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 15) * 8]};
                    16  :           qv_unwritten_data <= {{((64 - 16) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 16) * 8]};
                    17  :           qv_unwritten_data <= {{((64 - 17) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 17) * 8]};
                    18  :           qv_unwritten_data <= {{((64 - 18) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 18) * 8]};
                    19  :           qv_unwritten_data <= {{((64 - 19) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 19) * 8]};
                    20  :           qv_unwritten_data <= {{((64 - 20) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 20) * 8]};
                    21  :           qv_unwritten_data <= {{((64 - 21) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 21) * 8]};
                    22  :           qv_unwritten_data <= {{((64 - 22) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 22) * 8]};
                    23  :           qv_unwritten_data <= {{((64 - 23) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 23) * 8]};
                    24  :           qv_unwritten_data <= {{((64 - 24) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 24) * 8]};
                    25  :           qv_unwritten_data <= {{((64 - 25) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 25) * 8]};
                    26  :           qv_unwritten_data <= {{((64 - 26) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 26) * 8]};
                    27  :           qv_unwritten_data <= {{((64 - 27) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 27) * 8]};
                    28  :           qv_unwritten_data <= {{((64 - 28) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 28) * 8]};
                    29  :           qv_unwritten_data <= {{((64 - 29) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 29) * 8]};
                    30  :           qv_unwritten_data <= {{((64 - 30) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 30) * 8]};
                    31  :           qv_unwritten_data <= {{((64 - 31) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 31) * 8]};
                    32  :           qv_unwritten_data <= {{((64 - 32) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 32) * 8]};
                    33  :           qv_unwritten_data <= {{((64 - 33) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 33) * 8]};
                    34  :           qv_unwritten_data <= {{((64 - 34) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 34) * 8]};
                    35  :           qv_unwritten_data <= {{((64 - 35) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 35) * 8]};
                    36  :           qv_unwritten_data <= {{((64 - 36) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 36) * 8]};
                    37  :           qv_unwritten_data <= {{((64 - 37) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 37) * 8]};
                    38  :           qv_unwritten_data <= {{((64 - 38) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 38) * 8]};
                    39  :           qv_unwritten_data <= {{((64 - 39) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 39) * 8]};
                    40  :           qv_unwritten_data <= {{((64 - 40) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 40) * 8]};
                    41  :           qv_unwritten_data <= {{((64 - 41) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 41) * 8]};
                    42  :           qv_unwritten_data <= {{((64 - 42) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 42) * 8]};
                    43  :           qv_unwritten_data <= {{((64 - 43) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 43) * 8]};
                    44  :           qv_unwritten_data <= {{((64 - 44) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 44) * 8]};
                    45  :           qv_unwritten_data <= {{((64 - 45) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 45) * 8]};
                    46  :           qv_unwritten_data <= {{((64 - 46) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 46) * 8]};
                    47  :           qv_unwritten_data <= {{((64 - 47) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 47) * 8]};
                    48  :           qv_unwritten_data <= {{((64 - 48) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 48) * 8]};
                    49  :           qv_unwritten_data <= {{((64 - 49) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 49) * 8]};
                    50  :           qv_unwritten_data <= {{((64 - 50) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 50) * 8]};
                    51  :           qv_unwritten_data <= {{((64 - 51) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 51) * 8]};
                    52  :           qv_unwritten_data <= {{((64 - 52) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 52) * 8]};
                    53  :           qv_unwritten_data <= {{((64 - 53) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 53) * 8]};
                    54  :           qv_unwritten_data <= {{((64 - 54) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 54) * 8]};
                    55  :           qv_unwritten_data <= {{((64 - 55) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 55) * 8]};
                    56  :           qv_unwritten_data <= {{((64 - 56) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 56) * 8]};
                    57  :           qv_unwritten_data <= {{((64 - 57) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 57) * 8]};
                    58  :           qv_unwritten_data <= {{((64 - 58) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 58) * 8]};
                    59  :           qv_unwritten_data <= {{((64 - 59) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 59) * 8]};
                    60  :           qv_unwritten_data <= {{((64 - 60) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 60) * 8]};
                    61  :           qv_unwritten_data <= {{((64 - 61) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 61) * 8]};
                    62  :           qv_unwritten_data <= {{((64 - 62) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 62) * 8]};
                    63  :           qv_unwritten_data <= {{((64 - 63) * 8){1'b0}}, dma_rd_rsp_data[511 : (64 - 63) * 8]};
                    default:        qv_unwritten_data <= qv_unwritten_data;
                endcase
            end 
            else if(qv_page_length_left + qv_unwritten_len < 64) begin
                if(w_last_page_of_req) begin
                    qv_unwritten_data <= 'd0; 
                end
                else begin //piece together and wait for next ntt data
                    case(qv_unwritten_len)
                        0   :           qv_unwritten_data <= dma_rd_rsp_data;
                        1   :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 1 ) * 8 - 1 : 0], qv_unwritten_data[1  * 8 - 1 : 0]};
                        2   :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 2 ) * 8 - 1 : 0], qv_unwritten_data[2  * 8 - 1 : 0]};
                        3   :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 3 ) * 8 - 1 : 0], qv_unwritten_data[3  * 8 - 1 : 0]};
                        4   :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 4 ) * 8 - 1 : 0], qv_unwritten_data[4  * 8 - 1 : 0]};
                        5   :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 5 ) * 8 - 1 : 0], qv_unwritten_data[5  * 8 - 1 : 0]};
                        6   :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 6 ) * 8 - 1 : 0], qv_unwritten_data[6  * 8 - 1 : 0]};
                        7   :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 7 ) * 8 - 1 : 0], qv_unwritten_data[7  * 8 - 1 : 0]};
                        8   :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 8 ) * 8 - 1 : 0], qv_unwritten_data[8  * 8 - 1 : 0]};
                        9   :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 9 ) * 8 - 1 : 0], qv_unwritten_data[9  * 8 - 1 : 0]};
                        10  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 10) * 8 - 1 : 0], qv_unwritten_data[10 * 8 - 1 : 0]};
                        11  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 11) * 8 - 1 : 0], qv_unwritten_data[11 * 8 - 1 : 0]};
                        12  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 12) * 8 - 1 : 0], qv_unwritten_data[12 * 8 - 1 : 0]};
                        13  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 13) * 8 - 1 : 0], qv_unwritten_data[13 * 8 - 1 : 0]};
                        14  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 14) * 8 - 1 : 0], qv_unwritten_data[14 * 8 - 1 : 0]};
                        15  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 15) * 8 - 1 : 0], qv_unwritten_data[15 * 8 - 1 : 0]};
                        16  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 16) * 8 - 1 : 0], qv_unwritten_data[16 * 8 - 1 : 0]};
                        17  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 17) * 8 - 1 : 0], qv_unwritten_data[17 * 8 - 1 : 0]};
                        18  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 18) * 8 - 1 : 0], qv_unwritten_data[18 * 8 - 1 : 0]};
                        19  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 19) * 8 - 1 : 0], qv_unwritten_data[19 * 8 - 1 : 0]};
                        20  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 20) * 8 - 1 : 0], qv_unwritten_data[20 * 8 - 1 : 0]};
                        21  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 21) * 8 - 1 : 0], qv_unwritten_data[21 * 8 - 1 : 0]};
                        22  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 22) * 8 - 1 : 0], qv_unwritten_data[22 * 8 - 1 : 0]};
                        23  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 23) * 8 - 1 : 0], qv_unwritten_data[23 * 8 - 1 : 0]};
                        24  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 24) * 8 - 1 : 0], qv_unwritten_data[24 * 8 - 1 : 0]};
                        25  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 25) * 8 - 1 : 0], qv_unwritten_data[25 * 8 - 1 : 0]};
                        26  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 26) * 8 - 1 : 0], qv_unwritten_data[26 * 8 - 1 : 0]};
                        27  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 27) * 8 - 1 : 0], qv_unwritten_data[27 * 8 - 1 : 0]};
                        28  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 28) * 8 - 1 : 0], qv_unwritten_data[28 * 8 - 1 : 0]};
                        29  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 29) * 8 - 1 : 0], qv_unwritten_data[29 * 8 - 1 : 0]};
                        30  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 30) * 8 - 1 : 0], qv_unwritten_data[30 * 8 - 1 : 0]};
                        31  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 31) * 8 - 1 : 0], qv_unwritten_data[31 * 8 - 1 : 0]};
                        32  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 32) * 8 - 1 : 0], qv_unwritten_data[32 * 8 - 1 : 0]};
                        33  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 33) * 8 - 1 : 0], qv_unwritten_data[33 * 8 - 1 : 0]};
                        34  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 34) * 8 - 1 : 0], qv_unwritten_data[34 * 8 - 1 : 0]};
                        35  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 35) * 8 - 1 : 0], qv_unwritten_data[35 * 8 - 1 : 0]};
                        36  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 36) * 8 - 1 : 0], qv_unwritten_data[36 * 8 - 1 : 0]};
                        37  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 37) * 8 - 1 : 0], qv_unwritten_data[37 * 8 - 1 : 0]};
                        38  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 38) * 8 - 1 : 0], qv_unwritten_data[38 * 8 - 1 : 0]};
                        39  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 39) * 8 - 1 : 0], qv_unwritten_data[39 * 8 - 1 : 0]};
                        40  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 40) * 8 - 1 : 0], qv_unwritten_data[40 * 8 - 1 : 0]};
                        41  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 41) * 8 - 1 : 0], qv_unwritten_data[41 * 8 - 1 : 0]};
                        42  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 42) * 8 - 1 : 0], qv_unwritten_data[42 * 8 - 1 : 0]};
                        43  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 43) * 8 - 1 : 0], qv_unwritten_data[43 * 8 - 1 : 0]};
                        44  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 44) * 8 - 1 : 0], qv_unwritten_data[44 * 8 - 1 : 0]};
                        45  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 45) * 8 - 1 : 0], qv_unwritten_data[45 * 8 - 1 : 0]};
                        46  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 46) * 8 - 1 : 0], qv_unwritten_data[46 * 8 - 1 : 0]};
                        47  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 47) * 8 - 1 : 0], qv_unwritten_data[47 * 8 - 1 : 0]};
                        48  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 48) * 8 - 1 : 0], qv_unwritten_data[48 * 8 - 1 : 0]};
                        49  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 49) * 8 - 1 : 0], qv_unwritten_data[49 * 8 - 1 : 0]};
                        50  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 50) * 8 - 1 : 0], qv_unwritten_data[50 * 8 - 1 : 0]};
                        51  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 51) * 8 - 1 : 0], qv_unwritten_data[51 * 8 - 1 : 0]};
                        52  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 52) * 8 - 1 : 0], qv_unwritten_data[52 * 8 - 1 : 0]};
                        53  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 53) * 8 - 1 : 0], qv_unwritten_data[53 * 8 - 1 : 0]};
                        54  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 54) * 8 - 1 : 0], qv_unwritten_data[54 * 8 - 1 : 0]};
                        55  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 55) * 8 - 1 : 0], qv_unwritten_data[55 * 8 - 1 : 0]};
                        56  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 56) * 8 - 1 : 0], qv_unwritten_data[56 * 8 - 1 : 0]};
                        57  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 57) * 8 - 1 : 0], qv_unwritten_data[57 * 8 - 1 : 0]};
                        58  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 58) * 8 - 1 : 0], qv_unwritten_data[58 * 8 - 1 : 0]};
                        59  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 59) * 8 - 1 : 0], qv_unwritten_data[59 * 8 - 1 : 0]};
                        60  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 60) * 8 - 1 : 0], qv_unwritten_data[60 * 8 - 1 : 0]};
                        61  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 61) * 8 - 1 : 0], qv_unwritten_data[61 * 8 - 1 : 0]};
                        62  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 62) * 8 - 1 : 0], qv_unwritten_data[62 * 8 - 1 : 0]};
                        63  :           qv_unwritten_data <= {dma_rd_rsp_data[(64 - 63) * 8 - 1 : 0], qv_unwritten_data[63 * 8 - 1 : 0]};                        
                        default:        qv_unwritten_data <= qv_unwritten_data;
                    endcase                    
                end
            end
            else begin
                qv_unwritten_data <= qv_unwritten_data;
            end
        end
        else if(qv_page_length_left == 0 && !gather_resp_prog_full) begin
            qv_unwritten_data <= w_last_page_of_req ? 'd0 : qv_unwritten_data;
        end
        else begin
            qv_unwritten_data <= qv_unwritten_data;
        end
    end
    else begin
        qv_unwritten_data <= qv_unwritten_data;
    end
end

//-- gather_resp_wr_en --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        gather_resp_wr_en <= 'd0;
    end  
    else if(resp_cur_state == RESP_DOWNLOAD_s) begin
        if(qv_page_length_left > 0 && dma_rd_rsp_valid && !gather_resp_prog_full) begin
            if((qv_page_length_left >= 64) || (qv_page_length_left + qv_unwritten_len >= 64)) begin
                gather_resp_wr_en <= 'd1;
            end
            else if(qv_page_length_left + qv_unwritten_len < 64) begin
                gather_resp_wr_en <= w_last_page_of_req ? 'd1 : 'd0;     
            end
            else begin
                gather_resp_wr_en <= 'd0;
            end
        end
        else if(qv_page_length_left == 0 && !gather_resp_prog_full) begin
            gather_resp_wr_en <= w_last_page_of_req ? 'd1 : 'd0;
        end
		else begin
			gather_resp_wr_en <= 'd0;
		end 
    end
    else begin
        gather_resp_wr_en <= 'd0;
    end
end

//-- gather_resp_din --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        gather_resp_din <= 'd0;
    end  
    else if(resp_cur_state == RESP_DOWNLOAD_s) begin
        if(qv_page_length_left > 0 && dma_rd_rsp_valid && !gather_resp_prog_full) begin
            if((qv_page_length_left >= 64) || (qv_page_length_left + qv_unwritten_len >= 64)) begin
                case(qv_unwritten_len)
                    0   :           gather_resp_din <= dma_rd_rsp_data;
                    1   :           gather_resp_din <= {dma_rd_rsp_data[(64 - 1 ) * 8 - 1 : 0], qv_unwritten_data[1  * 8 - 1 : 0]};
                    2   :           gather_resp_din <= {dma_rd_rsp_data[(64 - 2 ) * 8 - 1 : 0], qv_unwritten_data[2  * 8 - 1 : 0]};
                    3   :           gather_resp_din <= {dma_rd_rsp_data[(64 - 3 ) * 8 - 1 : 0], qv_unwritten_data[3  * 8 - 1 : 0]};
                    4   :           gather_resp_din <= {dma_rd_rsp_data[(64 - 4 ) * 8 - 1 : 0], qv_unwritten_data[4  * 8 - 1 : 0]};
                    5   :           gather_resp_din <= {dma_rd_rsp_data[(64 - 5 ) * 8 - 1 : 0], qv_unwritten_data[5  * 8 - 1 : 0]};
                    6   :           gather_resp_din <= {dma_rd_rsp_data[(64 - 6 ) * 8 - 1 : 0], qv_unwritten_data[6  * 8 - 1 : 0]};
                    7   :           gather_resp_din <= {dma_rd_rsp_data[(64 - 7 ) * 8 - 1 : 0], qv_unwritten_data[7  * 8 - 1 : 0]};
                    8   :           gather_resp_din <= {dma_rd_rsp_data[(64 - 8 ) * 8 - 1 : 0], qv_unwritten_data[8  * 8 - 1 : 0]};
                    9   :           gather_resp_din <= {dma_rd_rsp_data[(64 - 9 ) * 8 - 1 : 0], qv_unwritten_data[9  * 8 - 1 : 0]};
                    10  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 10) * 8 - 1 : 0], qv_unwritten_data[10 * 8 - 1 : 0]};
                    11  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 11) * 8 - 1 : 0], qv_unwritten_data[11 * 8 - 1 : 0]};
                    12  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 12) * 8 - 1 : 0], qv_unwritten_data[12 * 8 - 1 : 0]};
                    13  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 13) * 8 - 1 : 0], qv_unwritten_data[13 * 8 - 1 : 0]};
                    14  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 14) * 8 - 1 : 0], qv_unwritten_data[14 * 8 - 1 : 0]};
                    15  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 15) * 8 - 1 : 0], qv_unwritten_data[15 * 8 - 1 : 0]};
                    16  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 16) * 8 - 1 : 0], qv_unwritten_data[16 * 8 - 1 : 0]};
                    17  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 17) * 8 - 1 : 0], qv_unwritten_data[17 * 8 - 1 : 0]};
                    18  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 18) * 8 - 1 : 0], qv_unwritten_data[18 * 8 - 1 : 0]};
                    19  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 19) * 8 - 1 : 0], qv_unwritten_data[19 * 8 - 1 : 0]};
                    20  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 20) * 8 - 1 : 0], qv_unwritten_data[20 * 8 - 1 : 0]};
                    21  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 21) * 8 - 1 : 0], qv_unwritten_data[21 * 8 - 1 : 0]};
                    22  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 22) * 8 - 1 : 0], qv_unwritten_data[22 * 8 - 1 : 0]};
                    23  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 23) * 8 - 1 : 0], qv_unwritten_data[23 * 8 - 1 : 0]};
                    24  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 24) * 8 - 1 : 0], qv_unwritten_data[24 * 8 - 1 : 0]};
                    25  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 25) * 8 - 1 : 0], qv_unwritten_data[25 * 8 - 1 : 0]};
                    26  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 26) * 8 - 1 : 0], qv_unwritten_data[26 * 8 - 1 : 0]};
                    27  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 27) * 8 - 1 : 0], qv_unwritten_data[27 * 8 - 1 : 0]};
                    28  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 28) * 8 - 1 : 0], qv_unwritten_data[28 * 8 - 1 : 0]};
                    29  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 29) * 8 - 1 : 0], qv_unwritten_data[29 * 8 - 1 : 0]};
                    30  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 30) * 8 - 1 : 0], qv_unwritten_data[30 * 8 - 1 : 0]};
                    31  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 31) * 8 - 1 : 0], qv_unwritten_data[31 * 8 - 1 : 0]};
                    32  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 32) * 8 - 1 : 0], qv_unwritten_data[32 * 8 - 1 : 0]};
                    33  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 33) * 8 - 1 : 0], qv_unwritten_data[33 * 8 - 1 : 0]};
                    34  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 34) * 8 - 1 : 0], qv_unwritten_data[34 * 8 - 1 : 0]};
                    35  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 35) * 8 - 1 : 0], qv_unwritten_data[35 * 8 - 1 : 0]};
                    36  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 36) * 8 - 1 : 0], qv_unwritten_data[36 * 8 - 1 : 0]};
                    37  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 37) * 8 - 1 : 0], qv_unwritten_data[37 * 8 - 1 : 0]};
                    38  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 38) * 8 - 1 : 0], qv_unwritten_data[38 * 8 - 1 : 0]};
                    39  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 39) * 8 - 1 : 0], qv_unwritten_data[39 * 8 - 1 : 0]};
                    40  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 40) * 8 - 1 : 0], qv_unwritten_data[40 * 8 - 1 : 0]};
                    41  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 41) * 8 - 1 : 0], qv_unwritten_data[41 * 8 - 1 : 0]};
                    42  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 42) * 8 - 1 : 0], qv_unwritten_data[42 * 8 - 1 : 0]};
                    43  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 43) * 8 - 1 : 0], qv_unwritten_data[43 * 8 - 1 : 0]};
                    44  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 44) * 8 - 1 : 0], qv_unwritten_data[44 * 8 - 1 : 0]};
                    45  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 45) * 8 - 1 : 0], qv_unwritten_data[45 * 8 - 1 : 0]};
                    46  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 46) * 8 - 1 : 0], qv_unwritten_data[46 * 8 - 1 : 0]};
                    47  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 47) * 8 - 1 : 0], qv_unwritten_data[47 * 8 - 1 : 0]};
                    48  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 48) * 8 - 1 : 0], qv_unwritten_data[48 * 8 - 1 : 0]};
                    49  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 49) * 8 - 1 : 0], qv_unwritten_data[49 * 8 - 1 : 0]};
                    50  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 50) * 8 - 1 : 0], qv_unwritten_data[50 * 8 - 1 : 0]};
                    51  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 51) * 8 - 1 : 0], qv_unwritten_data[51 * 8 - 1 : 0]};
                    52  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 52) * 8 - 1 : 0], qv_unwritten_data[52 * 8 - 1 : 0]};
                    53  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 53) * 8 - 1 : 0], qv_unwritten_data[53 * 8 - 1 : 0]};
                    54  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 54) * 8 - 1 : 0], qv_unwritten_data[54 * 8 - 1 : 0]};
                    55  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 55) * 8 - 1 : 0], qv_unwritten_data[55 * 8 - 1 : 0]};
                    56  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 56) * 8 - 1 : 0], qv_unwritten_data[56 * 8 - 1 : 0]};
                    57  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 57) * 8 - 1 : 0], qv_unwritten_data[57 * 8 - 1 : 0]};
                    58  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 58) * 8 - 1 : 0], qv_unwritten_data[58 * 8 - 1 : 0]};
                    59  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 59) * 8 - 1 : 0], qv_unwritten_data[59 * 8 - 1 : 0]};
                    60  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 60) * 8 - 1 : 0], qv_unwritten_data[60 * 8 - 1 : 0]};
                    61  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 61) * 8 - 1 : 0], qv_unwritten_data[61 * 8 - 1 : 0]};
                    62  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 62) * 8 - 1 : 0], qv_unwritten_data[62 * 8 - 1 : 0]};
                    63  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 63) * 8 - 1 : 0], qv_unwritten_data[63 * 8 - 1 : 0]};
                    default:        gather_resp_din <= gather_resp_din;
                endcase
            end
            else if(qv_page_length_left + qv_unwritten_len < 64) begin
                case(qv_unwritten_len)
                    0   :           gather_resp_din <= dma_rd_rsp_data;
                    1   :           gather_resp_din <= {dma_rd_rsp_data[(64 - 1 ) * 8 - 1 : 0], qv_unwritten_data[1  * 8 - 1 : 0]};
                    2   :           gather_resp_din <= {dma_rd_rsp_data[(64 - 2 ) * 8 - 1 : 0], qv_unwritten_data[2  * 8 - 1 : 0]};
                    3   :           gather_resp_din <= {dma_rd_rsp_data[(64 - 3 ) * 8 - 1 : 0], qv_unwritten_data[3  * 8 - 1 : 0]};
                    4   :           gather_resp_din <= {dma_rd_rsp_data[(64 - 4 ) * 8 - 1 : 0], qv_unwritten_data[4  * 8 - 1 : 0]};
                    5   :           gather_resp_din <= {dma_rd_rsp_data[(64 - 5 ) * 8 - 1 : 0], qv_unwritten_data[5  * 8 - 1 : 0]};
                    6   :           gather_resp_din <= {dma_rd_rsp_data[(64 - 6 ) * 8 - 1 : 0], qv_unwritten_data[6  * 8 - 1 : 0]};
                    7   :           gather_resp_din <= {dma_rd_rsp_data[(64 - 7 ) * 8 - 1 : 0], qv_unwritten_data[7  * 8 - 1 : 0]};
                    8   :           gather_resp_din <= {dma_rd_rsp_data[(64 - 8 ) * 8 - 1 : 0], qv_unwritten_data[8  * 8 - 1 : 0]};
                    9   :           gather_resp_din <= {dma_rd_rsp_data[(64 - 9 ) * 8 - 1 : 0], qv_unwritten_data[9  * 8 - 1 : 0]};
                    10  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 10) * 8 - 1 : 0], qv_unwritten_data[10 * 8 - 1 : 0]};
                    11  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 11) * 8 - 1 : 0], qv_unwritten_data[11 * 8 - 1 : 0]};
                    12  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 12) * 8 - 1 : 0], qv_unwritten_data[12 * 8 - 1 : 0]};
                    13  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 13) * 8 - 1 : 0], qv_unwritten_data[13 * 8 - 1 : 0]};
                    14  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 14) * 8 - 1 : 0], qv_unwritten_data[14 * 8 - 1 : 0]};
                    15  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 15) * 8 - 1 : 0], qv_unwritten_data[15 * 8 - 1 : 0]};
                    16  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 16) * 8 - 1 : 0], qv_unwritten_data[16 * 8 - 1 : 0]};
                    17  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 17) * 8 - 1 : 0], qv_unwritten_data[17 * 8 - 1 : 0]};
                    18  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 18) * 8 - 1 : 0], qv_unwritten_data[18 * 8 - 1 : 0]};
                    19  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 19) * 8 - 1 : 0], qv_unwritten_data[19 * 8 - 1 : 0]};
                    20  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 20) * 8 - 1 : 0], qv_unwritten_data[20 * 8 - 1 : 0]};
                    21  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 21) * 8 - 1 : 0], qv_unwritten_data[21 * 8 - 1 : 0]};
                    22  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 22) * 8 - 1 : 0], qv_unwritten_data[22 * 8 - 1 : 0]};
                    23  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 23) * 8 - 1 : 0], qv_unwritten_data[23 * 8 - 1 : 0]};
                    24  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 24) * 8 - 1 : 0], qv_unwritten_data[24 * 8 - 1 : 0]};
                    25  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 25) * 8 - 1 : 0], qv_unwritten_data[25 * 8 - 1 : 0]};
                    26  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 26) * 8 - 1 : 0], qv_unwritten_data[26 * 8 - 1 : 0]};
                    27  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 27) * 8 - 1 : 0], qv_unwritten_data[27 * 8 - 1 : 0]};
                    28  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 28) * 8 - 1 : 0], qv_unwritten_data[28 * 8 - 1 : 0]};
                    29  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 29) * 8 - 1 : 0], qv_unwritten_data[29 * 8 - 1 : 0]};
                    30  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 30) * 8 - 1 : 0], qv_unwritten_data[30 * 8 - 1 : 0]};
                    31  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 31) * 8 - 1 : 0], qv_unwritten_data[31 * 8 - 1 : 0]};
                    32  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 32) * 8 - 1 : 0], qv_unwritten_data[32 * 8 - 1 : 0]};
                    33  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 33) * 8 - 1 : 0], qv_unwritten_data[33 * 8 - 1 : 0]};
                    34  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 34) * 8 - 1 : 0], qv_unwritten_data[34 * 8 - 1 : 0]};
                    35  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 35) * 8 - 1 : 0], qv_unwritten_data[35 * 8 - 1 : 0]};
                    36  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 36) * 8 - 1 : 0], qv_unwritten_data[36 * 8 - 1 : 0]};
                    37  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 37) * 8 - 1 : 0], qv_unwritten_data[37 * 8 - 1 : 0]};
                    38  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 38) * 8 - 1 : 0], qv_unwritten_data[38 * 8 - 1 : 0]};
                    39  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 39) * 8 - 1 : 0], qv_unwritten_data[39 * 8 - 1 : 0]};
                    40  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 40) * 8 - 1 : 0], qv_unwritten_data[40 * 8 - 1 : 0]};
                    41  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 41) * 8 - 1 : 0], qv_unwritten_data[41 * 8 - 1 : 0]};
                    42  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 42) * 8 - 1 : 0], qv_unwritten_data[42 * 8 - 1 : 0]};
                    43  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 43) * 8 - 1 : 0], qv_unwritten_data[43 * 8 - 1 : 0]};
                    44  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 44) * 8 - 1 : 0], qv_unwritten_data[44 * 8 - 1 : 0]};
                    45  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 45) * 8 - 1 : 0], qv_unwritten_data[45 * 8 - 1 : 0]};
                    46  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 46) * 8 - 1 : 0], qv_unwritten_data[46 * 8 - 1 : 0]};
                    47  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 47) * 8 - 1 : 0], qv_unwritten_data[47 * 8 - 1 : 0]};
                    48  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 48) * 8 - 1 : 0], qv_unwritten_data[48 * 8 - 1 : 0]};
                    49  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 49) * 8 - 1 : 0], qv_unwritten_data[49 * 8 - 1 : 0]};
                    50  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 50) * 8 - 1 : 0], qv_unwritten_data[50 * 8 - 1 : 0]};
                    51  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 51) * 8 - 1 : 0], qv_unwritten_data[51 * 8 - 1 : 0]};
                    52  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 52) * 8 - 1 : 0], qv_unwritten_data[52 * 8 - 1 : 0]};
                    53  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 53) * 8 - 1 : 0], qv_unwritten_data[53 * 8 - 1 : 0]};
                    54  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 54) * 8 - 1 : 0], qv_unwritten_data[54 * 8 - 1 : 0]};
                    55  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 55) * 8 - 1 : 0], qv_unwritten_data[55 * 8 - 1 : 0]};
                    56  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 56) * 8 - 1 : 0], qv_unwritten_data[56 * 8 - 1 : 0]};
                    57  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 57) * 8 - 1 : 0], qv_unwritten_data[57 * 8 - 1 : 0]};
                    58  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 58) * 8 - 1 : 0], qv_unwritten_data[58 * 8 - 1 : 0]};
                    59  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 59) * 8 - 1 : 0], qv_unwritten_data[59 * 8 - 1 : 0]};
                    60  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 60) * 8 - 1 : 0], qv_unwritten_data[60 * 8 - 1 : 0]};
                    61  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 61) * 8 - 1 : 0], qv_unwritten_data[61 * 8 - 1 : 0]};
                    62  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 62) * 8 - 1 : 0], qv_unwritten_data[62 * 8 - 1 : 0]};
                    63  :           gather_resp_din <= {dma_rd_rsp_data[(64 - 63) * 8 - 1 : 0], qv_unwritten_data[63 * 8 - 1 : 0]};
                    default:        gather_resp_din <= gather_resp_din;
                endcase                           
            end
            else begin
                gather_resp_din <= gather_resp_din;
            end
        end
        else if(qv_page_length_left == 0 && !gather_resp_prog_full) begin
            gather_resp_din <= qv_unwritten_data;
        end
    end
    else begin
        gather_resp_din <= gather_resp_din;
    end
end

/*------------------------------------------- Variables Decode : End ------------------------------------------------*/

endmodule