/*------------------------------------------- Module Description : Begin ----------------------------------------------
Name:       ScatterData
Author:     YangFan
Function:   Scatters continous stream to non-contiguous memory page.
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
module ScatterData
(
    input   wire                                                                clk,
    input   wire                                                                rst,

    input   wire                                                                scatter_req_wr_en,
    input   wire        [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]       scatter_req_din,
    output  wire                                                                scatter_req_prog_full,

    input   wire                                                                scatter_data_wr_en,
    input   wire        [`DMA_DATA_WIDTH - 1 : 0]                               scatter_data_din,
    output  wire                                                                scatter_data_prog_full,

    output  wire                                                                dma_wr_req_valid,
    output  wire                                                                dma_wr_req_last ,
    output  wire        [`DMA_HEAD_WIDTH - 1 : 0]                               dma_wr_req_head ,
    output  wire        [`DMA_DATA_WIDTH - 1 : 0]                               dma_wr_req_data ,
    input   wire                                                                dma_wr_req_ready 
);
/*------------------------------------------- Input/Output Definition : End -----------------------------------------*/

/*------------------------------------------- Local Variables Definition : Begin ------------------------------------*/
wire                                                                scatter_req_rd_en;
wire        [`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH - 1 : 0]       scatter_req_dout;
wire                                                                scatter_req_empty;

reg                                                                 q_dma_wr_req_valid;
reg                                                                 q_dma_wr_req_last;
reg         [(`DMA_DATA_WIDTH - 1) : 0]                             qv_dma_wr_req_data;
reg         [(`DMA_HEAD_WIDTH - 1) : 0]                             qv_dma_wr_req_head;

reg                                                                 q_dma_wr_req_valid_diff;
reg                                                                 q_dma_wr_req_last_diff;
reg         [(`DMA_DATA_WIDTH -1):0]                                qv_dma_wr_req_data_diff;
reg         [(`DMA_HEAD_WIDTH -1):0]                                qv_dma_wr_req_head_diff;

wire                                                                scatter_data_rd_en;
wire        [`DMA_DATA_WIDTH - 1 : 0]                               scatter_data_dout;
wire                                                                scatter_data_empty;

wire        [`DMA_LENGTH_WIDTH - 1 : 0]                             wv_cur_req_length;
wire        [`DMA_LENGTH_WIDTH - 1 : 0]                             wv_cur_page_length;
wire                                                                w_channel_empty;
wire        [`DMA_DATA_WIDTH - 1 : 0]                               wv_channel_dout;

reg                                                                 q_channel_rd_en;

reg         [`DMA_LENGTH_WIDTH - 1 : 0]                             qv_req_length_left;
reg         [`DMA_LENGTH_WIDTH - 1 : 0]                             qv_page_length_left;

reg         [`DMA_LENGTH_WIDTH - 1 : 0]                             qv_unwritten_len;
reg         [`DMA_DATA_WIDTH - 1 : 0]                               qv_unwritten_data;

wire                                                                w_last_page_of_req;
reg         [`DMA_LENGTH_WIDTH - 1 : 0]			                    qv_offset;
/*------------------------------------------- Local Variables Definition : End --------------------------------------*/

/*------------------------------------------- Submodules Instatiation : Begin ---------------------------------------*/
SyncFIFO_Template #(
    .FIFO_TYPE   (0),
    .FIFO_WIDTH  (`DMA_LENGTH_WIDTH * 2 + `DMA_ADDR_WIDTH),
    .FIFO_DEPTH  (64)
)
scatter_req_fifo
(
    .clk(clk),
    .rst(rst),

    .wr_en(scatter_req_wr_en),
    .din(scatter_req_din),
    .prog_full(scatter_req_prog_full),
    .rd_en(scatter_req_rd_en),
    .dout(scatter_req_dout),
    .empty(scatter_req_empty),
    .data_count()
);


SyncFIFO_Template #(
    .FIFO_TYPE   (0),
    .FIFO_WIDTH  (`DMA_DATA_WIDTH),
    .FIFO_DEPTH  (64)
)
scatter_data_fifo
(
    .clk(clk),
    .rst(rst),

    .wr_en(scatter_data_wr_en),
    .din(scatter_data_din),
    .prog_full(scatter_data_prog_full),
    .rd_en(scatter_data_rd_en),
    .dout(scatter_data_dout),
    .empty(scatter_data_empty),
    .data_count()
);

/*------------------------------------------- Submodules Instatiation : End -----------------------------------------*/

/*------------------------------------------- State Machine Definition : Begin --------------------------------------*/
parameter           REQ_IDLE_s = 2'b01,
                    REQ_UPLOAD_s = 2'b10;

reg                 [1:0]               req_cur_state;
reg                 [1:0]               req_next_state;
reg 				[1:0]				req_pre_state;

always @(posedge clk or posedge rst) begin
	if(rst) begin
		req_pre_state <= REQ_IDLE_s;
	end 
	else begin
		req_pre_state <= req_cur_state;
	end 
end 

always @(posedge clk or posedge rst) begin
    if(rst) begin
        req_cur_state <= REQ_IDLE_s;
    end
    else begin
        req_cur_state <= req_next_state;
    end
end

always @(*) begin
    case(req_cur_state) 
        REQ_IDLE_s:         if(!scatter_req_empty && !w_channel_empty) begin
                                req_next_state = REQ_UPLOAD_s;
                            end    
                            else begin
                                req_next_state = REQ_IDLE_s;
                            end
        REQ_UPLOAD_s:       if(qv_page_length_left + qv_unwritten_len > 64) begin 
                                req_next_state = REQ_UPLOAD_s;
                            end     
                            else begin // <=64, judge whether need valid signal 
                                if(qv_page_length_left > 0 && !w_channel_empty && dma_wr_req_ready) begin    //Need valid indicator
                                    req_next_state = REQ_IDLE_s;
                                end
                                else if(qv_page_length_left == 0 && dma_wr_req_ready) begin
                                    req_next_state = REQ_IDLE_s;
                                end
                                else begin
                                    req_next_state = REQ_UPLOAD_s;
                                end
                            end         
        default:            req_next_state = REQ_IDLE_s;
    endcase
end
/*------------------------------------------- State Machine Definition : End ----------------------------------------*/

/*------------------------------------------- Variables Decode : Begin ----------------------------------------------*/
//-- scatter_req_rd_en --
assign scatter_req_rd_en = (req_cur_state == REQ_UPLOAD_s) && (req_next_state == REQ_IDLE_s);


//-- dma_wr_req_valid --
assign dma_wr_req_valid = q_dma_wr_req_valid;
//-- dma_wr_req_last  --
assign dma_wr_req_last  = q_dma_wr_req_last ;
//-- dma_wr_req_data  --
assign dma_wr_req_data  = qv_dma_wr_req_data;
//-- dma_wr_req_head  --
assign dma_wr_req_head  = qv_dma_wr_req_head;

//-- wv_cur_req_length --
assign wv_cur_req_length = scatter_req_dout[127:96];
//-- wv_cur_page_length --
assign wv_cur_page_length = scatter_req_dout[95:64];

//-- w_channel_empty --
assign w_channel_empty = scatter_data_empty;

//-- wv_channel_dout --
assign wv_channel_dout = scatter_data_dout;

//-- scatter_data_rd_en --
assign scatter_data_rd_en = q_channel_rd_en;

//-- w_last_page_of_req --
assign w_last_page_of_req = (qv_req_length_left == qv_page_length_left);

//-- q_dma_wr_req_valid_diff --
//-- q_dma_wr_req_last_diff --
//-- qv_dma_wr_req_data_diff --
//-- qv_dma_wr_req_head_diff --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		q_dma_wr_req_valid_diff <= 'd0;
		q_dma_wr_req_last_diff <= 'd0;
		qv_dma_wr_req_data_diff <= 'd0;
		qv_dma_wr_req_head_diff <= 'd0;
	end 
	else begin
		q_dma_wr_req_valid_diff <= q_dma_wr_req_valid;
		q_dma_wr_req_last_diff <= q_dma_wr_req_last;
		qv_dma_wr_req_data_diff <= qv_dma_wr_req_data;
		qv_dma_wr_req_head_diff <= qv_dma_wr_req_head;
	end
end 

//-- qv_page_length_left --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_page_length_left <= 'd0;
    end
    else if(req_cur_state == REQ_IDLE_s && !scatter_req_empty && !w_channel_empty) begin
        qv_page_length_left <= wv_cur_page_length - qv_unwritten_len;
    end
    else if(req_cur_state == REQ_UPLOAD_s) begin
        if(qv_page_length_left > 0 && !w_channel_empty && dma_wr_req_ready) begin
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

//-- qv_req_length_left --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_req_length_left <= 'd0;
    end
    else if(req_cur_state == REQ_IDLE_s && !scatter_req_empty && !w_channel_empty) begin
        if(qv_req_length_left == 0) begin
            qv_req_length_left <= wv_cur_req_length - qv_unwritten_len;
        end    
        else begin
            qv_req_length_left <= qv_req_length_left - qv_unwritten_len;
        end
    end
    else if(req_cur_state == REQ_UPLOAD_s) begin
        if(qv_page_length_left > 0 && !w_channel_empty && dma_wr_req_ready) begin
            if(qv_page_length_left > 64) begin
                qv_req_length_left <= qv_req_length_left - 64;
            end
            else begin
                qv_req_length_left <= qv_req_length_left - qv_page_length_left;
            end
        end
        else begin
            qv_req_length_left <= qv_req_length_left;
        end
    end
    else begin
        qv_req_length_left <= qv_req_length_left;
    end
end

//-- qv_offset --
always @(posedge clk or posedge rst) begin
	if(rst) begin
		qv_offset <= 'd0;
	end 
	else if((qv_page_length_left + qv_unwritten_len >= 64) && !w_channel_empty && dma_wr_req_ready) begin
		qv_offset <= 64 - qv_unwritten_len;
	end 
	else begin
		qv_offset <= qv_offset;
	end 
end 

//-- qv_unwritten_len --
always @(posedge clk or posedge rst) begin
    if(rst) begin
        qv_unwritten_len <= 'd0;
    end
    else if(req_cur_state == REQ_IDLE_s) begin
        qv_unwritten_len <= qv_unwritten_len;
    end
    else if(req_cur_state == REQ_UPLOAD_s) begin //qv_unwritten_len need to consider wthether is the last mtt
        if(qv_page_length_left > 0 && !w_channel_empty && dma_wr_req_ready) begin
            if(qv_page_length_left >= 64) begin
                qv_unwritten_len <= qv_unwritten_len;
            end
            else if(qv_page_length_left + qv_unwritten_len >= 64)begin
                qv_unwritten_len <= qv_page_length_left + qv_unwritten_len - 64;
            end
            else begin  
                qv_unwritten_len <= w_last_page_of_req ? 'd0 : (64 -  qv_page_length_left);
            end
        end  
        else if(qv_page_length_left == 0 && dma_wr_req_ready) begin
            qv_unwritten_len <= w_last_page_of_req ? 'd0 : (64 - qv_unwritten_len - qv_offset);
        end 
		else begin
			qv_unwritten_len <= qv_unwritten_len;
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
    else if(req_cur_state == REQ_UPLOAD_s) begin
        if(qv_page_length_left > 0 && !w_channel_empty && dma_wr_req_ready) begin
            if((qv_page_length_left >= 64) || (qv_page_length_left + qv_unwritten_len >= 64)) begin
                case(qv_unwritten_len)
                    0   :           qv_unwritten_data <= 'd0;
                    1   :           qv_unwritten_data <= {{((64 - 1 ) * 8){1'b0}}, wv_channel_dout[511 : (64 - 1 ) * 8]};
                    2   :           qv_unwritten_data <= {{((64 - 2 ) * 8){1'b0}}, wv_channel_dout[511 : (64 - 2 ) * 8]};
                    3   :           qv_unwritten_data <= {{((64 - 3 ) * 8){1'b0}}, wv_channel_dout[511 : (64 - 3 ) * 8]};
                    4   :           qv_unwritten_data <= {{((64 - 4 ) * 8){1'b0}}, wv_channel_dout[511 : (64 - 4 ) * 8]};
                    5   :           qv_unwritten_data <= {{((64 - 5 ) * 8){1'b0}}, wv_channel_dout[511 : (64 - 5 ) * 8]};
                    6   :           qv_unwritten_data <= {{((64 - 6 ) * 8){1'b0}}, wv_channel_dout[511 : (64 - 6 ) * 8]};
                    7   :           qv_unwritten_data <= {{((64 - 7 ) * 8){1'b0}}, wv_channel_dout[511 : (64 - 7 ) * 8]};
                    8   :           qv_unwritten_data <= {{((64 - 8 ) * 8){1'b0}}, wv_channel_dout[511 : (64 - 8 ) * 8]};
                    9   :           qv_unwritten_data <= {{((64 - 9 ) * 8){1'b0}}, wv_channel_dout[511 : (64 - 9 ) * 8]};
                    10  :           qv_unwritten_data <= {{((64 - 10) * 8){1'b0}}, wv_channel_dout[511 : (64 - 10) * 8]};
                    11  :           qv_unwritten_data <= {{((64 - 11) * 8){1'b0}}, wv_channel_dout[511 : (64 - 11) * 8]};
                    12  :           qv_unwritten_data <= {{((64 - 12) * 8){1'b0}}, wv_channel_dout[511 : (64 - 12) * 8]};
                    13  :           qv_unwritten_data <= {{((64 - 13) * 8){1'b0}}, wv_channel_dout[511 : (64 - 13) * 8]};
                    14  :           qv_unwritten_data <= {{((64 - 14) * 8){1'b0}}, wv_channel_dout[511 : (64 - 14) * 8]};
                    15  :           qv_unwritten_data <= {{((64 - 15) * 8){1'b0}}, wv_channel_dout[511 : (64 - 15) * 8]};
                    16  :           qv_unwritten_data <= {{((64 - 16) * 8){1'b0}}, wv_channel_dout[511 : (64 - 16) * 8]};
                    17  :           qv_unwritten_data <= {{((64 - 17) * 8){1'b0}}, wv_channel_dout[511 : (64 - 17) * 8]};
                    18  :           qv_unwritten_data <= {{((64 - 18) * 8){1'b0}}, wv_channel_dout[511 : (64 - 18) * 8]};
                    19  :           qv_unwritten_data <= {{((64 - 19) * 8){1'b0}}, wv_channel_dout[511 : (64 - 19) * 8]};
                    20  :           qv_unwritten_data <= {{((64 - 20) * 8){1'b0}}, wv_channel_dout[511 : (64 - 20) * 8]};
                    21  :           qv_unwritten_data <= {{((64 - 21) * 8){1'b0}}, wv_channel_dout[511 : (64 - 21) * 8]};
                    22  :           qv_unwritten_data <= {{((64 - 22) * 8){1'b0}}, wv_channel_dout[511 : (64 - 22) * 8]};
                    23  :           qv_unwritten_data <= {{((64 - 23) * 8){1'b0}}, wv_channel_dout[511 : (64 - 23) * 8]};
                    24  :           qv_unwritten_data <= {{((64 - 24) * 8){1'b0}}, wv_channel_dout[511 : (64 - 24) * 8]};
                    25  :           qv_unwritten_data <= {{((64 - 25) * 8){1'b0}}, wv_channel_dout[511 : (64 - 25) * 8]};
                    26  :           qv_unwritten_data <= {{((64 - 26) * 8){1'b0}}, wv_channel_dout[511 : (64 - 26) * 8]};
                    27  :           qv_unwritten_data <= {{((64 - 27) * 8){1'b0}}, wv_channel_dout[511 : (64 - 27) * 8]};
                    28  :           qv_unwritten_data <= {{((64 - 28) * 8){1'b0}}, wv_channel_dout[511 : (64 - 28) * 8]};
                    29  :           qv_unwritten_data <= {{((64 - 29) * 8){1'b0}}, wv_channel_dout[511 : (64 - 29) * 8]};
                    30  :           qv_unwritten_data <= {{((64 - 30) * 8){1'b0}}, wv_channel_dout[511 : (64 - 30) * 8]};
                    31  :           qv_unwritten_data <= {{((64 - 31) * 8){1'b0}}, wv_channel_dout[511 : (64 - 31) * 8]};
                    32  :           qv_unwritten_data <= {{((64 - 32) * 8){1'b0}}, wv_channel_dout[511 : (64 - 32) * 8]};
                    33  :           qv_unwritten_data <= {{((64 - 33) * 8){1'b0}}, wv_channel_dout[511 : (64 - 33) * 8]};
                    34  :           qv_unwritten_data <= {{((64 - 34) * 8){1'b0}}, wv_channel_dout[511 : (64 - 34) * 8]};
                    35  :           qv_unwritten_data <= {{((64 - 35) * 8){1'b0}}, wv_channel_dout[511 : (64 - 35) * 8]};
                    36  :           qv_unwritten_data <= {{((64 - 36) * 8){1'b0}}, wv_channel_dout[511 : (64 - 36) * 8]};
                    37  :           qv_unwritten_data <= {{((64 - 37) * 8){1'b0}}, wv_channel_dout[511 : (64 - 37) * 8]};
                    38  :           qv_unwritten_data <= {{((64 - 38) * 8){1'b0}}, wv_channel_dout[511 : (64 - 38) * 8]};
                    39  :           qv_unwritten_data <= {{((64 - 39) * 8){1'b0}}, wv_channel_dout[511 : (64 - 39) * 8]};
                    40  :           qv_unwritten_data <= {{((64 - 40) * 8){1'b0}}, wv_channel_dout[511 : (64 - 40) * 8]};
                    41  :           qv_unwritten_data <= {{((64 - 41) * 8){1'b0}}, wv_channel_dout[511 : (64 - 41) * 8]};
                    42  :           qv_unwritten_data <= {{((64 - 42) * 8){1'b0}}, wv_channel_dout[511 : (64 - 42) * 8]};
                    43  :           qv_unwritten_data <= {{((64 - 43) * 8){1'b0}}, wv_channel_dout[511 : (64 - 43) * 8]};
                    44  :           qv_unwritten_data <= {{((64 - 44) * 8){1'b0}}, wv_channel_dout[511 : (64 - 44) * 8]};
                    45  :           qv_unwritten_data <= {{((64 - 45) * 8){1'b0}}, wv_channel_dout[511 : (64 - 45) * 8]};
                    46  :           qv_unwritten_data <= {{((64 - 46) * 8){1'b0}}, wv_channel_dout[511 : (64 - 46) * 8]};
                    47  :           qv_unwritten_data <= {{((64 - 47) * 8){1'b0}}, wv_channel_dout[511 : (64 - 47) * 8]};
                    48  :           qv_unwritten_data <= {{((64 - 48) * 8){1'b0}}, wv_channel_dout[511 : (64 - 48) * 8]};
                    49  :           qv_unwritten_data <= {{((64 - 49) * 8){1'b0}}, wv_channel_dout[511 : (64 - 49) * 8]};
                    50  :           qv_unwritten_data <= {{((64 - 50) * 8){1'b0}}, wv_channel_dout[511 : (64 - 50) * 8]};
                    51  :           qv_unwritten_data <= {{((64 - 51) * 8){1'b0}}, wv_channel_dout[511 : (64 - 51) * 8]};
                    52  :           qv_unwritten_data <= {{((64 - 52) * 8){1'b0}}, wv_channel_dout[511 : (64 - 52) * 8]};
                    53  :           qv_unwritten_data <= {{((64 - 53) * 8){1'b0}}, wv_channel_dout[511 : (64 - 53) * 8]};
                    54  :           qv_unwritten_data <= {{((64 - 54) * 8){1'b0}}, wv_channel_dout[511 : (64 - 54) * 8]};
                    55  :           qv_unwritten_data <= {{((64 - 55) * 8){1'b0}}, wv_channel_dout[511 : (64 - 55) * 8]};
                    56  :           qv_unwritten_data <= {{((64 - 56) * 8){1'b0}}, wv_channel_dout[511 : (64 - 56) * 8]};
                    57  :           qv_unwritten_data <= {{((64 - 57) * 8){1'b0}}, wv_channel_dout[511 : (64 - 57) * 8]};
                    58  :           qv_unwritten_data <= {{((64 - 58) * 8){1'b0}}, wv_channel_dout[511 : (64 - 58) * 8]};
                    59  :           qv_unwritten_data <= {{((64 - 59) * 8){1'b0}}, wv_channel_dout[511 : (64 - 59) * 8]};
                    60  :           qv_unwritten_data <= {{((64 - 60) * 8){1'b0}}, wv_channel_dout[511 : (64 - 60) * 8]};
                    61  :           qv_unwritten_data <= {{((64 - 61) * 8){1'b0}}, wv_channel_dout[511 : (64 - 61) * 8]};
                    62  :           qv_unwritten_data <= {{((64 - 62) * 8){1'b0}}, wv_channel_dout[511 : (64 - 62) * 8]};
                    63  :           qv_unwritten_data <= {{((64 - 63) * 8){1'b0}}, wv_channel_dout[511 : (64 - 63) * 8]};
                    default:        qv_unwritten_data <= qv_unwritten_data;
                endcase
            end 
            else if(qv_page_length_left + qv_unwritten_len < 64) begin
                if(w_last_page_of_req) begin
                    qv_unwritten_data <= 'd0; 
                end
                else begin //piece together and wait for next ntt data
                    case(qv_page_length_left)
                        0   :           qv_unwritten_data <= wv_channel_dout;
                        1   :           qv_unwritten_data <= {{(64 - 1 )* 8{1'b0}},  wv_channel_dout[511 : 1  * 8]};
                        2   :           qv_unwritten_data <= {{(64 - 2 )* 8{1'b0}},  wv_channel_dout[511 : 2  * 8]};
                        3   :           qv_unwritten_data <= {{(64 - 3 )* 8{1'b0}},  wv_channel_dout[511 : 3  * 8]};
                        4   :           qv_unwritten_data <= {{(64 - 4 )* 8{1'b0}},  wv_channel_dout[511 : 4  * 8]};
                        5   :           qv_unwritten_data <= {{(64 - 5 )* 8{1'b0}},  wv_channel_dout[511 : 5  * 8]};
                        6   :           qv_unwritten_data <= {{(64 - 6 )* 8{1'b0}},  wv_channel_dout[511 : 6  * 8]};
                        7   :           qv_unwritten_data <= {{(64 - 7 )* 8{1'b0}},  wv_channel_dout[511 : 7  * 8]};
                        8   :           qv_unwritten_data <= {{(64 - 8 )* 8{1'b0}},  wv_channel_dout[511 : 8  * 8]};
                        9   :           qv_unwritten_data <= {{(64 - 9 )* 8{1'b0}},  wv_channel_dout[511 : 9  * 8]};
                        10  :           qv_unwritten_data <= {{(64 - 10)* 8{1'b0}},  wv_channel_dout[511 : 10 * 8]};
                        11  :           qv_unwritten_data <= {{(64 - 11)* 8{1'b0}},  wv_channel_dout[511 : 11 * 8]};
                        12  :           qv_unwritten_data <= {{(64 - 12)* 8{1'b0}},  wv_channel_dout[511 : 12 * 8]};
                        13  :           qv_unwritten_data <= {{(64 - 13)* 8{1'b0}},  wv_channel_dout[511 : 13 * 8]};
                        14  :           qv_unwritten_data <= {{(64 - 14)* 8{1'b0}},  wv_channel_dout[511 : 14 * 8]};
                        15  :           qv_unwritten_data <= {{(64 - 15)* 8{1'b0}},  wv_channel_dout[511 : 15 * 8]};
                        16  :           qv_unwritten_data <= {{(64 - 16)* 8{1'b0}},  wv_channel_dout[511 : 16 * 8]};
                        17  :           qv_unwritten_data <= {{(64 - 17)* 8{1'b0}},  wv_channel_dout[511 : 17 * 8]};
                        18  :           qv_unwritten_data <= {{(64 - 18)* 8{1'b0}},  wv_channel_dout[511 : 18 * 8]};
                        19  :           qv_unwritten_data <= {{(64 - 19)* 8{1'b0}},  wv_channel_dout[511 : 19 * 8]};
                        20  :           qv_unwritten_data <= {{(64 - 20)* 8{1'b0}},  wv_channel_dout[511 : 20 * 8]};
                        21  :           qv_unwritten_data <= {{(64 - 21)* 8{1'b0}},  wv_channel_dout[511 : 21 * 8]};
                        22  :           qv_unwritten_data <= {{(64 - 22)* 8{1'b0}},  wv_channel_dout[511 : 22 * 8]};
                        23  :           qv_unwritten_data <= {{(64 - 23)* 8{1'b0}},  wv_channel_dout[511 : 23 * 8]};
                        24  :           qv_unwritten_data <= {{(64 - 24)* 8{1'b0}},  wv_channel_dout[511 : 24 * 8]};
                        25  :           qv_unwritten_data <= {{(64 - 25)* 8{1'b0}},  wv_channel_dout[511 : 25 * 8]};
                        26  :           qv_unwritten_data <= {{(64 - 26)* 8{1'b0}},  wv_channel_dout[511 : 26 * 8]};
                        27  :           qv_unwritten_data <= {{(64 - 27)* 8{1'b0}},  wv_channel_dout[511 : 27 * 8]};
                        28  :           qv_unwritten_data <= {{(64 - 28)* 8{1'b0}},  wv_channel_dout[511 : 28 * 8]};
                        29  :           qv_unwritten_data <= {{(64 - 29)* 8{1'b0}},  wv_channel_dout[511 : 29 * 8]};
                        30  :           qv_unwritten_data <= {{(64 - 30) * 8{1'b0}}, wv_channel_dout[511 : 30 * 8]};
                        31  :           qv_unwritten_data <= {{(64 - 31) * 8{1'b0}}, wv_channel_dout[511 : 31 * 8]};
                        32  :           qv_unwritten_data <= {{((64 - 32) * 8){1'b0}}, wv_channel_dout[511 : 32 * 8]};
                        33  :           qv_unwritten_data <= {{((64 - 33) * 8){1'b0}}, wv_channel_dout[511 : 33 * 8]};
                        34  :           qv_unwritten_data <= {{((64 - 34) * 8){1'b0}}, wv_channel_dout[511 : 34 * 8]};
                        35  :           qv_unwritten_data <= {{((64 - 35) * 8){1'b0}}, wv_channel_dout[511 : 35 * 8]};
                        36  :           qv_unwritten_data <= {{((64 - 36) * 8){1'b0}}, wv_channel_dout[511 : 36 * 8]};
                        37  :           qv_unwritten_data <= {{((64 - 37) * 8){1'b0}}, wv_channel_dout[511 : 37 * 8]};
                        38  :           qv_unwritten_data <= {{((64 - 38) * 8){1'b0}}, wv_channel_dout[511 : 38 * 8]};
                        39  :           qv_unwritten_data <= {{((64 - 39) * 8){1'b0}}, wv_channel_dout[511 : 39 * 8]};
                        40  :           qv_unwritten_data <= {{((64 - 40) * 8){1'b0}}, wv_channel_dout[511 : 40 * 8]};
                        41  :           qv_unwritten_data <= {{((64 - 41) * 8){1'b0}}, wv_channel_dout[511 : 41 * 8]};
                        42  :           qv_unwritten_data <= {{((64 - 42) * 8){1'b0}}, wv_channel_dout[511 : 42 * 8]};
                        43  :           qv_unwritten_data <= {{((64 - 43) * 8){1'b0}}, wv_channel_dout[511 : 43 * 8]};
                        44  :           qv_unwritten_data <= {{((64 - 44) * 8){1'b0}}, wv_channel_dout[511 : 44 * 8]};
                        45  :           qv_unwritten_data <= {{((64 - 45) * 8){1'b0}}, wv_channel_dout[511 : 45 * 8]};
                        46  :           qv_unwritten_data <= {{((64 - 46) * 8){1'b0}}, wv_channel_dout[511 : 46 * 8]};
                        47  :           qv_unwritten_data <= {{((64 - 47) * 8){1'b0}}, wv_channel_dout[511 : 47 * 8]};
                        48  :           qv_unwritten_data <= {{((64 - 48) * 8){1'b0}}, wv_channel_dout[511 : 48 * 8]};
                        49  :           qv_unwritten_data <= {{((64 - 49) * 8){1'b0}}, wv_channel_dout[511 : 49 * 8]};
                        50  :           qv_unwritten_data <= {{((64 - 50) * 8){1'b0}}, wv_channel_dout[511 : 50 * 8]};
                        51  :           qv_unwritten_data <= {{((64 - 51) * 8){1'b0}}, wv_channel_dout[511 : 51 * 8]};
                        52  :           qv_unwritten_data <= {{((64 - 52) * 8){1'b0}}, wv_channel_dout[511 : 52 * 8]};
                        53  :           qv_unwritten_data <= {{((64 - 53) * 8){1'b0}}, wv_channel_dout[511 : 53 * 8]};
                        54  :           qv_unwritten_data <= {{((64 - 54) * 8){1'b0}}, wv_channel_dout[511 : 54 * 8]};
                        55  :           qv_unwritten_data <= {{((64 - 55) * 8){1'b0}}, wv_channel_dout[511 : 55 * 8]};
                        56  :           qv_unwritten_data <= {{((64 - 56) * 8){1'b0}}, wv_channel_dout[511 : 56 * 8]};
                        57  :           qv_unwritten_data <= {{((64 - 57) * 8){1'b0}}, wv_channel_dout[511 : 57 * 8]};
                        58  :           qv_unwritten_data <= {{((64 - 58) * 8){1'b0}}, wv_channel_dout[511 : 58 * 8]};
                        59  :           qv_unwritten_data <= {{((64 - 59) * 8){1'b0}}, wv_channel_dout[511 : 59 * 8]};
                        60  :           qv_unwritten_data <= {{((64 - 60) * 8){1'b0}}, wv_channel_dout[511 : 60 * 8]};
                        61  :           qv_unwritten_data <= {{((64 - 61) * 8){1'b0}}, wv_channel_dout[511 : 61 * 8]};
                        62  :           qv_unwritten_data <= {{((64 - 62) * 8){1'b0}}, wv_channel_dout[511 : 62 * 8]};
                        63  :           qv_unwritten_data <= {{((64 - 63) * 8){1'b0}}, wv_channel_dout[511 : 63 * 8]};                        
                        default:        qv_unwritten_data <= qv_unwritten_data;
                    endcase                    
                end
            end
            else begin
                qv_unwritten_data <= qv_unwritten_data;
            end
        end
        else if(qv_page_length_left == 0 && dma_wr_req_ready) begin
			if(w_last_page_of_req) begin
				qv_unwritten_data <= 'd0;
			end 
			else begin
                case(qv_unwritten_len + qv_offset)
                    0   :           qv_unwritten_data <= wv_channel_dout;
                    1   :           qv_unwritten_data <= {{(64 - 1 )* 8{1'b0}},  wv_channel_dout[511 : 1  * 8]};
                    2   :           qv_unwritten_data <= {{(64 - 2 )* 8{1'b0}},  wv_channel_dout[511 : 2  * 8]};
                    3   :           qv_unwritten_data <= {{(64 - 3 )* 8{1'b0}},  wv_channel_dout[511 : 3  * 8]};
                    4   :           qv_unwritten_data <= {{(64 - 4 )* 8{1'b0}},  wv_channel_dout[511 : 4  * 8]};
                    5   :           qv_unwritten_data <= {{(64 - 5 )* 8{1'b0}},  wv_channel_dout[511 : 5  * 8]};
                    6   :           qv_unwritten_data <= {{(64 - 6 )* 8{1'b0}},  wv_channel_dout[511 : 6  * 8]};
                    7   :           qv_unwritten_data <= {{(64 - 7 )* 8{1'b0}},  wv_channel_dout[511 : 7  * 8]};
                    8   :           qv_unwritten_data <= {{(64 - 8 )* 8{1'b0}},  wv_channel_dout[511 : 8  * 8]};
                    9   :           qv_unwritten_data <= {{(64 - 9 )* 8{1'b0}},  wv_channel_dout[511 : 9  * 8]};
                    10  :           qv_unwritten_data <= {{(64 - 10)* 8{1'b0}},  wv_channel_dout[511 : 10 * 8]};
                    11  :           qv_unwritten_data <= {{(64 - 11)* 8{1'b0}},  wv_channel_dout[511 : 11 * 8]};
                    12  :           qv_unwritten_data <= {{(64 - 12)* 8{1'b0}},  wv_channel_dout[511 : 12 * 8]};
                    13  :           qv_unwritten_data <= {{(64 - 13)* 8{1'b0}},  wv_channel_dout[511 : 13 * 8]};
                    14  :           qv_unwritten_data <= {{(64 - 14)* 8{1'b0}},  wv_channel_dout[511 : 14 * 8]};
                    15  :           qv_unwritten_data <= {{(64 - 15)* 8{1'b0}},  wv_channel_dout[511 : 15 * 8]};
                    16  :           qv_unwritten_data <= {{(64 - 16)* 8{1'b0}},  wv_channel_dout[511 : 16 * 8]};
                    17  :           qv_unwritten_data <= {{(64 - 17)* 8{1'b0}},  wv_channel_dout[511 : 17 * 8]};
                    18  :           qv_unwritten_data <= {{(64 - 18)* 8{1'b0}},  wv_channel_dout[511 : 18 * 8]};
                    19  :           qv_unwritten_data <= {{(64 - 19)* 8{1'b0}},  wv_channel_dout[511 : 19 * 8]};
                    20  :           qv_unwritten_data <= {{(64 - 20)* 8{1'b0}},  wv_channel_dout[511 : 20 * 8]};
                    21  :           qv_unwritten_data <= {{(64 - 21)* 8{1'b0}},  wv_channel_dout[511 : 21 * 8]};
                    22  :           qv_unwritten_data <= {{(64 - 22)* 8{1'b0}},  wv_channel_dout[511 : 22 * 8]};
                    23  :           qv_unwritten_data <= {{(64 - 23)* 8{1'b0}},  wv_channel_dout[511 : 23 * 8]};
                    24  :           qv_unwritten_data <= {{(64 - 24)* 8{1'b0}},  wv_channel_dout[511 : 24 * 8]};
                    25  :           qv_unwritten_data <= {{(64 - 25)* 8{1'b0}},  wv_channel_dout[511 : 25 * 8]};
                    26  :           qv_unwritten_data <= {{(64 - 26)* 8{1'b0}},  wv_channel_dout[511 : 26 * 8]};
                    27  :           qv_unwritten_data <= {{(64 - 27)* 8{1'b0}},  wv_channel_dout[511 : 27 * 8]};
                    28  :           qv_unwritten_data <= {{(64 - 28)* 8{1'b0}},  wv_channel_dout[511 : 28 * 8]};
                    29  :           qv_unwritten_data <= {{(64 - 29)* 8{1'b0}},  wv_channel_dout[511 : 29 * 8]};
                    30  :           qv_unwritten_data <= {{(64 - 30) * 8{1'b0}}, wv_channel_dout[511 : 30 * 8]};
                    31  :           qv_unwritten_data <= {{(64 - 31) * 8{1'b0}}, wv_channel_dout[511 : 31 * 8]};
                    32  :           qv_unwritten_data <= {{(64 - 32)* 8{1'b0}},  wv_channel_dout[511 : 32 * 8]};
                    33  :           qv_unwritten_data <= {{(64 - 33)* 8{1'b0}},  wv_channel_dout[511 : 33 * 8]};
                    34  :           qv_unwritten_data <= {{(64 - 34)* 8{1'b0}},  wv_channel_dout[511 : 34 * 8]};
                    35  :           qv_unwritten_data <= {{(64 - 35)* 8{1'b0}},  wv_channel_dout[511 : 35 * 8]};
                    36  :           qv_unwritten_data <= {{(64 - 36)* 8{1'b0}},  wv_channel_dout[511 : 36 * 8]};
                    37  :           qv_unwritten_data <= {{(64 - 37)* 8{1'b0}},  wv_channel_dout[511 : 37 * 8]};
                    38  :           qv_unwritten_data <= {{(64 - 38)* 8{1'b0}},  wv_channel_dout[511 : 38 * 8]};
                    39  :           qv_unwritten_data <= {{(64 - 39)* 8{1'b0}},  wv_channel_dout[511 : 39 * 8]};
                    40  :           qv_unwritten_data <= {{(64 - 40)* 8{1'b0}},  wv_channel_dout[511 : 40 * 8]};
                    41  :           qv_unwritten_data <= {{(64 - 41)* 8{1'b0}},  wv_channel_dout[511 : 41 * 8]};
                    42  :           qv_unwritten_data <= {{(64 - 42)* 8{1'b0}},  wv_channel_dout[511 : 42 * 8]};
                    43  :           qv_unwritten_data <= {{(64 - 43)* 8{1'b0}},  wv_channel_dout[511 : 43 * 8]};
                    44  :           qv_unwritten_data <= {{(64 - 44)* 8{1'b0}},  wv_channel_dout[511 : 44 * 8]};
                    45  :           qv_unwritten_data <= {{(64 - 45)* 8{1'b0}},  wv_channel_dout[511 : 45 * 8]};
                    46  :           qv_unwritten_data <= {{(64 - 46)* 8{1'b0}},  wv_channel_dout[511 : 46 * 8]};
                    47  :           qv_unwritten_data <= {{(64 - 47)* 8{1'b0}},  wv_channel_dout[511 : 47 * 8]};
                    48  :           qv_unwritten_data <= {{(64 - 48)* 8{1'b0}},  wv_channel_dout[511 : 48 * 8]};
                    49  :           qv_unwritten_data <= {{(64 - 49)* 8{1'b0}},  wv_channel_dout[511 : 49 * 8]};
                    50  :           qv_unwritten_data <= {{(64 - 50)* 8{1'b0}},  wv_channel_dout[511 : 50 * 8]};
                    51  :           qv_unwritten_data <= {{(64 - 51)* 8{1'b0}},  wv_channel_dout[511 : 51 * 8]};
                    52  :           qv_unwritten_data <= {{(64 - 52)* 8{1'b0}},  wv_channel_dout[511 : 52 * 8]};
                    53  :           qv_unwritten_data <= {{(64 - 53)* 8{1'b0}},  wv_channel_dout[511 : 53 * 8]};
                    54  :           qv_unwritten_data <= {{(64 - 54)* 8{1'b0}},  wv_channel_dout[511 : 54 * 8]};
                    55  :           qv_unwritten_data <= {{(64 - 55)* 8{1'b0}},  wv_channel_dout[511 : 55 * 8]};
                    56  :           qv_unwritten_data <= {{(64 - 56)* 8{1'b0}},  wv_channel_dout[511 : 56 * 8]};
                    57  :           qv_unwritten_data <= {{(64 - 57)* 8{1'b0}},  wv_channel_dout[511 : 57 * 8]};
                    58  :           qv_unwritten_data <= {{(64 - 58)* 8{1'b0}},  wv_channel_dout[511 : 58 * 8]};
                    59  :           qv_unwritten_data <= {{(64 - 59)* 8{1'b0}},  wv_channel_dout[511 : 59 * 8]};
                    60  :           qv_unwritten_data <= {{(64 - 60)* 8{1'b0}},  wv_channel_dout[511 : 60 * 8]};
                    61  :           qv_unwritten_data <= {{(64 - 61)* 8{1'b0}},  wv_channel_dout[511 : 61 * 8]};
                    62  :           qv_unwritten_data <= {{(64 - 62) * 8{1'b0}}, wv_channel_dout[511 : 62 * 8]};
                    63  :           qv_unwritten_data <= {{(64 - 63) * 8{1'b0}}, wv_channel_dout[511 : 63 * 8]};
                    default:        qv_unwritten_data <= qv_unwritten_data;
				endcase
			end
        end
        else begin
            qv_unwritten_data <= qv_unwritten_data;
        end
    end
    else begin
        qv_unwritten_data <= qv_unwritten_data;
    end
end

//-- q_dma_wr_req_valid --
always @(*) begin
    if(rst) begin
        q_dma_wr_req_valid = 'd0;
    end  
    else if(req_cur_state == REQ_UPLOAD_s) begin
		if(qv_page_length_left > 0 && !w_channel_empty) begin
			q_dma_wr_req_valid = 'd1;
		end
		else if(qv_page_length_left == 0) begin
			q_dma_wr_req_valid = 'd1;
		end 
		else begin
			q_dma_wr_req_valid = 'd0;
		end 
    end
    else begin
        q_dma_wr_req_valid = 'd0;
    end
end

//-- dma_wr_req_data --
always @(*) begin
    if(rst) begin
        qv_dma_wr_req_data = 'd0;
    end  
    else if(req_cur_state == REQ_UPLOAD_s) begin
        if(qv_page_length_left > 0 && !w_channel_empty) begin
            if((qv_page_length_left >= 64) || (qv_page_length_left + qv_unwritten_len >= 64)) begin
                case(qv_unwritten_len)
                    0   :           qv_dma_wr_req_data = wv_channel_dout;
                    1   :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 1 ) * 8 - 1 : 0], qv_unwritten_data[1  * 8 - 1 : 0]};
                    2   :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 2 ) * 8 - 1 : 0], qv_unwritten_data[2  * 8 - 1 : 0]};
                    3   :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 3 ) * 8 - 1 : 0], qv_unwritten_data[3  * 8 - 1 : 0]};
                    4   :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 4 ) * 8 - 1 : 0], qv_unwritten_data[4  * 8 - 1 : 0]};
                    5   :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 5 ) * 8 - 1 : 0], qv_unwritten_data[5  * 8 - 1 : 0]};
                    6   :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 6 ) * 8 - 1 : 0], qv_unwritten_data[6  * 8 - 1 : 0]};
                    7   :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 7 ) * 8 - 1 : 0], qv_unwritten_data[7  * 8 - 1 : 0]};
                    8   :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 8 ) * 8 - 1 : 0], qv_unwritten_data[8  * 8 - 1 : 0]};
                    9   :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 9 ) * 8 - 1 : 0], qv_unwritten_data[9  * 8 - 1 : 0]};
                    10  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 10) * 8 - 1 : 0], qv_unwritten_data[10 * 8 - 1 : 0]};
                    11  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 11) * 8 - 1 : 0], qv_unwritten_data[11 * 8 - 1 : 0]};
                    12  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 12) * 8 - 1 : 0], qv_unwritten_data[12 * 8 - 1 : 0]};
                    13  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 13) * 8 - 1 : 0], qv_unwritten_data[13 * 8 - 1 : 0]};
                    14  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 14) * 8 - 1 : 0], qv_unwritten_data[14 * 8 - 1 : 0]};
                    15  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 15) * 8 - 1 : 0], qv_unwritten_data[15 * 8 - 1 : 0]};
                    16  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 16) * 8 - 1 : 0], qv_unwritten_data[16 * 8 - 1 : 0]};
                    17  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 17) * 8 - 1 : 0], qv_unwritten_data[17 * 8 - 1 : 0]};
                    18  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 18) * 8 - 1 : 0], qv_unwritten_data[18 * 8 - 1 : 0]};
                    19  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 19) * 8 - 1 : 0], qv_unwritten_data[19 * 8 - 1 : 0]};
                    20  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 20) * 8 - 1 : 0], qv_unwritten_data[20 * 8 - 1 : 0]};
                    21  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 21) * 8 - 1 : 0], qv_unwritten_data[21 * 8 - 1 : 0]};
                    22  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 22) * 8 - 1 : 0], qv_unwritten_data[22 * 8 - 1 : 0]};
                    23  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 23) * 8 - 1 : 0], qv_unwritten_data[23 * 8 - 1 : 0]};
                    24  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 24) * 8 - 1 : 0], qv_unwritten_data[24 * 8 - 1 : 0]};
                    25  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 25) * 8 - 1 : 0], qv_unwritten_data[25 * 8 - 1 : 0]};
                    26  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 26) * 8 - 1 : 0], qv_unwritten_data[26 * 8 - 1 : 0]};
                    27  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 27) * 8 - 1 : 0], qv_unwritten_data[27 * 8 - 1 : 0]};
                    28  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 28) * 8 - 1 : 0], qv_unwritten_data[28 * 8 - 1 : 0]};
                    29  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 29) * 8 - 1 : 0], qv_unwritten_data[29 * 8 - 1 : 0]};
                    30  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 30) * 8 - 1 : 0], qv_unwritten_data[30 * 8 - 1 : 0]};
                    31  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 31) * 8 - 1 : 0], qv_unwritten_data[31 * 8 - 1 : 0]};
                    32  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 32) * 8 - 1 : 0], qv_unwritten_data[32 * 8 - 1 : 0]};
                    33  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 33) * 8 - 1 : 0], qv_unwritten_data[33 * 8 - 1 : 0]};
                    34  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 34) * 8 - 1 : 0], qv_unwritten_data[34 * 8 - 1 : 0]};
                    35  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 35) * 8 - 1 : 0], qv_unwritten_data[35 * 8 - 1 : 0]};
                    36  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 36) * 8 - 1 : 0], qv_unwritten_data[36 * 8 - 1 : 0]};
                    37  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 37) * 8 - 1 : 0], qv_unwritten_data[37 * 8 - 1 : 0]};
                    38  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 38) * 8 - 1 : 0], qv_unwritten_data[38 * 8 - 1 : 0]};
                    39  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 39) * 8 - 1 : 0], qv_unwritten_data[39 * 8 - 1 : 0]};
                    40  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 40) * 8 - 1 : 0], qv_unwritten_data[40 * 8 - 1 : 0]};
                    41  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 41) * 8 - 1 : 0], qv_unwritten_data[41 * 8 - 1 : 0]};
                    42  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 42) * 8 - 1 : 0], qv_unwritten_data[42 * 8 - 1 : 0]};
                    43  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 43) * 8 - 1 : 0], qv_unwritten_data[43 * 8 - 1 : 0]};
                    44  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 44) * 8 - 1 : 0], qv_unwritten_data[44 * 8 - 1 : 0]};
                    45  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 45) * 8 - 1 : 0], qv_unwritten_data[45 * 8 - 1 : 0]};
                    46  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 46) * 8 - 1 : 0], qv_unwritten_data[46 * 8 - 1 : 0]};
                    47  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 47) * 8 - 1 : 0], qv_unwritten_data[47 * 8 - 1 : 0]};
                    48  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 48) * 8 - 1 : 0], qv_unwritten_data[48 * 8 - 1 : 0]};
                    49  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 49) * 8 - 1 : 0], qv_unwritten_data[49 * 8 - 1 : 0]};
                    50  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 50) * 8 - 1 : 0], qv_unwritten_data[50 * 8 - 1 : 0]};
                    51  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 51) * 8 - 1 : 0], qv_unwritten_data[51 * 8 - 1 : 0]};
                    52  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 52) * 8 - 1 : 0], qv_unwritten_data[52 * 8 - 1 : 0]};
                    53  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 53) * 8 - 1 : 0], qv_unwritten_data[53 * 8 - 1 : 0]};
                    54  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 54) * 8 - 1 : 0], qv_unwritten_data[54 * 8 - 1 : 0]};
                    55  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 55) * 8 - 1 : 0], qv_unwritten_data[55 * 8 - 1 : 0]};
                    56  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 56) * 8 - 1 : 0], qv_unwritten_data[56 * 8 - 1 : 0]};
                    57  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 57) * 8 - 1 : 0], qv_unwritten_data[57 * 8 - 1 : 0]};
                    58  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 58) * 8 - 1 : 0], qv_unwritten_data[58 * 8 - 1 : 0]};
                    59  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 59) * 8 - 1 : 0], qv_unwritten_data[59 * 8 - 1 : 0]};
                    60  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 60) * 8 - 1 : 0], qv_unwritten_data[60 * 8 - 1 : 0]};
                    61  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 61) * 8 - 1 : 0], qv_unwritten_data[61 * 8 - 1 : 0]};
                    62  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 62) * 8 - 1 : 0], qv_unwritten_data[62 * 8 - 1 : 0]};
                    63  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 63) * 8 - 1 : 0], qv_unwritten_data[63 * 8 - 1 : 0]};
                    default:        qv_dma_wr_req_data = qv_dma_wr_req_data_diff;
                endcase
            end
            else if(qv_page_length_left + qv_unwritten_len < 64) begin
                case(qv_unwritten_len)
                    0   :           qv_dma_wr_req_data = wv_channel_dout;
                    1   :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 1 ) * 8 - 1 : 0], qv_unwritten_data[1  * 8 - 1 : 0]};
                    2   :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 2 ) * 8 - 1 : 0], qv_unwritten_data[2  * 8 - 1 : 0]};
                    3   :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 3 ) * 8 - 1 : 0], qv_unwritten_data[3  * 8 - 1 : 0]};
                    4   :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 4 ) * 8 - 1 : 0], qv_unwritten_data[4  * 8 - 1 : 0]};
                    5   :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 5 ) * 8 - 1 : 0], qv_unwritten_data[5  * 8 - 1 : 0]};
                    6   :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 6 ) * 8 - 1 : 0], qv_unwritten_data[6  * 8 - 1 : 0]};
                    7   :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 7 ) * 8 - 1 : 0], qv_unwritten_data[7  * 8 - 1 : 0]};
                    8   :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 8 ) * 8 - 1 : 0], qv_unwritten_data[8  * 8 - 1 : 0]};
                    9   :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 9 ) * 8 - 1 : 0], qv_unwritten_data[9  * 8 - 1 : 0]};
                    10  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 10) * 8 - 1 : 0], qv_unwritten_data[10 * 8 - 1 : 0]};
                    11  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 11) * 8 - 1 : 0], qv_unwritten_data[11 * 8 - 1 : 0]};
                    12  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 12) * 8 - 1 : 0], qv_unwritten_data[12 * 8 - 1 : 0]};
                    13  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 13) * 8 - 1 : 0], qv_unwritten_data[13 * 8 - 1 : 0]};
                    14  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 14) * 8 - 1 : 0], qv_unwritten_data[14 * 8 - 1 : 0]};
                    15  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 15) * 8 - 1 : 0], qv_unwritten_data[15 * 8 - 1 : 0]};
                    16  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 16) * 8 - 1 : 0], qv_unwritten_data[16 * 8 - 1 : 0]};
                    17  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 17) * 8 - 1 : 0], qv_unwritten_data[17 * 8 - 1 : 0]};
                    18  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 18) * 8 - 1 : 0], qv_unwritten_data[18 * 8 - 1 : 0]};
                    19  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 19) * 8 - 1 : 0], qv_unwritten_data[19 * 8 - 1 : 0]};
                    20  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 20) * 8 - 1 : 0], qv_unwritten_data[20 * 8 - 1 : 0]};
                    21  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 21) * 8 - 1 : 0], qv_unwritten_data[21 * 8 - 1 : 0]};
                    22  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 22) * 8 - 1 : 0], qv_unwritten_data[22 * 8 - 1 : 0]};
                    23  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 23) * 8 - 1 : 0], qv_unwritten_data[23 * 8 - 1 : 0]};
                    24  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 24) * 8 - 1 : 0], qv_unwritten_data[24 * 8 - 1 : 0]};
                    25  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 25) * 8 - 1 : 0], qv_unwritten_data[25 * 8 - 1 : 0]};
                    26  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 26) * 8 - 1 : 0], qv_unwritten_data[26 * 8 - 1 : 0]};
                    27  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 27) * 8 - 1 : 0], qv_unwritten_data[27 * 8 - 1 : 0]};
                    28  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 28) * 8 - 1 : 0], qv_unwritten_data[28 * 8 - 1 : 0]};
                    29  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 29) * 8 - 1 : 0], qv_unwritten_data[29 * 8 - 1 : 0]};
                    30  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 30) * 8 - 1 : 0], qv_unwritten_data[30 * 8 - 1 : 0]};
                    31  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 31) * 8 - 1 : 0], qv_unwritten_data[31 * 8 - 1 : 0]};
                    32  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 32) * 8 - 1 : 0], qv_unwritten_data[32 * 8 - 1 : 0]};
                    33  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 33) * 8 - 1 : 0], qv_unwritten_data[33 * 8 - 1 : 0]};
                    34  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 34) * 8 - 1 : 0], qv_unwritten_data[34 * 8 - 1 : 0]};
                    35  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 35) * 8 - 1 : 0], qv_unwritten_data[35 * 8 - 1 : 0]};
                    36  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 36) * 8 - 1 : 0], qv_unwritten_data[36 * 8 - 1 : 0]};
                    37  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 37) * 8 - 1 : 0], qv_unwritten_data[37 * 8 - 1 : 0]};
                    38  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 38) * 8 - 1 : 0], qv_unwritten_data[38 * 8 - 1 : 0]};
                    39  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 39) * 8 - 1 : 0], qv_unwritten_data[39 * 8 - 1 : 0]};
                    40  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 40) * 8 - 1 : 0], qv_unwritten_data[40 * 8 - 1 : 0]};
                    41  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 41) * 8 - 1 : 0], qv_unwritten_data[41 * 8 - 1 : 0]};
                    42  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 42) * 8 - 1 : 0], qv_unwritten_data[42 * 8 - 1 : 0]};
                    43  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 43) * 8 - 1 : 0], qv_unwritten_data[43 * 8 - 1 : 0]};
                    44  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 44) * 8 - 1 : 0], qv_unwritten_data[44 * 8 - 1 : 0]};
                    45  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 45) * 8 - 1 : 0], qv_unwritten_data[45 * 8 - 1 : 0]};
                    46  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 46) * 8 - 1 : 0], qv_unwritten_data[46 * 8 - 1 : 0]};
                    47  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 47) * 8 - 1 : 0], qv_unwritten_data[47 * 8 - 1 : 0]};
                    48  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 48) * 8 - 1 : 0], qv_unwritten_data[48 * 8 - 1 : 0]};
                    49  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 49) * 8 - 1 : 0], qv_unwritten_data[49 * 8 - 1 : 0]};
                    50  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 50) * 8 - 1 : 0], qv_unwritten_data[50 * 8 - 1 : 0]};
                    51  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 51) * 8 - 1 : 0], qv_unwritten_data[51 * 8 - 1 : 0]};
                    52  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 52) * 8 - 1 : 0], qv_unwritten_data[52 * 8 - 1 : 0]};
                    53  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 53) * 8 - 1 : 0], qv_unwritten_data[53 * 8 - 1 : 0]};
                    54  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 54) * 8 - 1 : 0], qv_unwritten_data[54 * 8 - 1 : 0]};
                    55  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 55) * 8 - 1 : 0], qv_unwritten_data[55 * 8 - 1 : 0]};
                    56  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 56) * 8 - 1 : 0], qv_unwritten_data[56 * 8 - 1 : 0]};
                    57  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 57) * 8 - 1 : 0], qv_unwritten_data[57 * 8 - 1 : 0]};
                    58  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 58) * 8 - 1 : 0], qv_unwritten_data[58 * 8 - 1 : 0]};
                    59  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 59) * 8 - 1 : 0], qv_unwritten_data[59 * 8 - 1 : 0]};
                    60  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 60) * 8 - 1 : 0], qv_unwritten_data[60 * 8 - 1 : 0]};
                    61  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 61) * 8 - 1 : 0], qv_unwritten_data[61 * 8 - 1 : 0]};
                    62  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 62) * 8 - 1 : 0], qv_unwritten_data[62 * 8 - 1 : 0]};
                    63  :           qv_dma_wr_req_data = {wv_channel_dout[(64 - 63) * 8 - 1 : 0], qv_unwritten_data[63 * 8 - 1 : 0]};
                    default:        qv_dma_wr_req_data = qv_dma_wr_req_data_diff;
                endcase                           
            end
            else begin
                qv_dma_wr_req_data = qv_dma_wr_req_data_diff;
            end
        end
        else if(qv_page_length_left == 0) begin
            qv_dma_wr_req_data = qv_unwritten_data;
        end
		else begin
			qv_dma_wr_req_data = qv_dma_wr_req_data_diff;
		end 
    end
    else begin
        qv_dma_wr_req_data = qv_dma_wr_req_data_diff;
    end
end

//-- dma_wr_req_head --
always @(*) begin
    if(rst) begin
        qv_dma_wr_req_head = 'd0;
    end
    else if(req_pre_state == REQ_IDLE_s && req_cur_state == REQ_UPLOAD_s) begin
        qv_dma_wr_req_head = {scatter_req_dout[63:0], scatter_req_dout[95:64]};
    end
    else begin
        qv_dma_wr_req_head = qv_dma_wr_req_head_diff;
    end
end

//-- q_dma_wr_req_last --
always @(*) begin
    if(rst) begin
        q_dma_wr_req_last = 'd0;
    end
    else if(req_cur_state == REQ_UPLOAD_s) begin
        if(qv_page_length_left + qv_unwritten_len <= 64) begin
            if(qv_page_length_left > 0 && !w_channel_empty) begin
                q_dma_wr_req_last = 'd1;
            end 
            else if(qv_page_length_left == 0) begin
                q_dma_wr_req_last = 'd1;
            end
            else begin
                q_dma_wr_req_last = 'd0;
            end
        end 
        else begin
            q_dma_wr_req_last = 'd0;
        end
    end
    else begin
        q_dma_wr_req_last = 'd0;
    end
end

//-- q_channel_rd_en --
always @(*) begin
    if(rst) begin
        q_channel_rd_en = 'd0;
    end
    else if(req_cur_state == REQ_UPLOAD_s) begin
        if(qv_page_length_left > 0 && !w_channel_empty && dma_wr_req_ready) begin
            q_channel_rd_en = 'd1;
        end
        else begin
            q_channel_rd_en = 'd0;
        end
    end
    else begin
        q_channel_rd_en = 'd0;
    end
end

/*------------------------------------------- Variables Decode : End ------------------------------------------------*/

endmodule
