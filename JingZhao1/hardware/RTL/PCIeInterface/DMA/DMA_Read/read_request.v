`timescale 1ns / 100ps
//*************************************************************************
// > File Name: read_request.v
// > Author   : Kangning
// > Date     : 2022-06-29
// > Note     : read_request, used to generate read request. 
// >               Note the request must aligned by 4KB.
// > V1.1 -- 2020-09-24: Add support for various Max_Read_Request_Size
// > V1.2 -- 2022-06-29: Add chnl_num field to store
//*************************************************************************

//`include "../lib/global_include_h.v"
//`include "../lib/dma_def_h.v"

module read_request #(
    
) (
    input wire dma_clk, // i, 1
    input wire rst_n  , // i, 1

    /* ------- Read Request From RDMA{begin} ------- */
    /* dma_*_head, valid only in first beat of a packet
     * | chnl_num | Reserved | address | Reserved | Byte length |
     * | 127:120  |  119:96  |  95:32  |  31:13   |    12:0     |
     */
    output wire                   rd_req_ready, // o, 1
    input  wire [`DMA_HEAD_W-1:0] rd_req_head , // i, `DMA_HEAD_W
    input  wire                   rd_req_valid, // i, 1
    /* ------- Read Request From RDMA{end} ------- */

    /* -------axis read request interface{begin}------- */
    /* AXI-Stream read request tuser, every read request contains only one beat.
     * | chnl_num |last_sub_req | Reserved | REQ_TYPE |Tag(inv)| address | Reserved | DW length | first BE | last BE |
     * | 127:120  |     119     | 118:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     */
    output  wire                      axis_rd_request_tvalid , // o, 1
    output  wire                      axis_rd_request_tlast  , // o, 1
    output  wire [`DMA_DATA_W  -1:0]  axis_rd_request_tdata  , // o, `DMA_DATA_W
    output  wire [`AXIS_TUSER_W-1:0]  axis_rd_request_tuser  , // o, `AXIS_TUSER_W
    output  wire [`DMA_KEEP_W  -1:0]  axis_rd_request_tkeep  , // o, `DMA_KEEP_W
    input   wire                      axis_rd_request_tready , // i, 1
    /* -------axis read request interface{end}------- */

    /* --------read request blocking detection{begin}-------- */
    input  wire                         chnl_avail, // i, 1
    input  wire                         chnl_valid, // i, 1
    /* --------read request blocking detection{end}-------- */

    /* -------PCIe fragment property{begin}------- */
    /* This signal indicates the (max payload size & max read request size) agreed in the communication
     * 3'b000 -- 128 B
     * 3'b001 -- 256 B
     * 3'b010 -- 512 B
     * 3'b011 -- 1024B
     * 3'b100 -- 2048B
     * 3'b101 -- 4096B
     */
    input wire [2:0] max_pyld_sz  ,
    input wire [2:0] max_rd_req_sz  // max read request size
    /* -------PCIe fragment property{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,output wire [`RD_REQ_SIGNAL_W-1:0] dbg_signal  // o, `RD_REQ_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

/* -------State relevant in FSM{begin}------- */
localparam      IDLE    = 3'b001, // When there's incomming read req, store the req, and jump to GET_TAG.
                GET_TAG = 3'b010, // Jump to FORWARD directly, we do not get tag at this time.
                FORWARD = 3'b100; // Forward the read request(only one beat). If there is other requests 
                                  // for the dma rd req, jump to GET_TAG. Or jump to IDLE to end tx of the 
                                  // dma rd req.

reg [2:0] cur_state;
reg [2:0] nxt_state;


wire is_idle, is_get_tag, is_forward;
wire j_idle;

reg [`DMA_HEAD_W-1:0] reg_head;
/* -------State relevant in FSM{end}------- */

/* -------Head decode{begin}------- */
// relate to output
wire [`DMA_LEN_WIDTH -1:0] byte_len_align;
wire [`DMA_ADDR_WIDTH-1:0] addr_unalign;
wire [8              -1:0] chnl_num;


wire [`DMA_ADDR_WIDTH-1:0] addr_align;
wire [`DW_LEN_WIDTH  -1:0] dw_len    ;
wire [`FIRST_BE_WIDTH-1:0] first_be  ;
wire [`LAST_BE_WIDTH -1:0] last_be   ;

/* -------Head decode{end}------- */

/* -------Read request fragment{begin}------- */
// fragment info
wire [`DW_LEN_WIDTH-1:0] max_rd_req_dw; // The maximum read request in dw unit
reg  [`DW_LEN_WIDTH-1:0] dw_sent      ; // The number of dw read request has been sent in a dma read request
wire [`DW_LEN_WIDTH-1:0] dw_req       ; // read request size of a sub request
wire is_only_req  ;
wire is_first_req ;
wire is_middle_req;
wire is_last_req  ;
wire has_rd_req   ; // There's still has read request to be sent in the dma rd request


// axis tuser field
wire [`TAG_WIDTH+`TAG_EMPTY-1:0] tag            ;
wire [`DMA_ADDR_WIDTH      -1:0] axis_addr_align;
wire [`DW_LEN_WIDTH        -1:0] axis_dw_len    ;
wire [`FIRST_BE_WIDTH      -1:0] axis_first_be  ;
wire [`LAST_BE_WIDTH       -1:0] axis_last_be   ;
/* -------Read Request Fragment{end}------- */

/* --------read request blocking detection{begin}-------- */
reg chnl_avail_reg;
reg chnl_valid_reg;
wire is_chnl_blocked;
wire is_chnl_avail;
reg  is_nxt_req_blocked;
/* --------read request blocking detection{end}-------- */

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign dbg_signal = { // 440
    cur_state, nxt_state, // 6
    is_idle, is_get_tag, is_forward, // 3
    j_idle,   // 1
    reg_head, // 128
    byte_len_align, addr_unalign, chnl_num, // 85
    addr_align, dw_len, first_be, last_be, // 83
    max_rd_req_dw, dw_sent, dw_req, is_only_req, is_first_req, is_middle_req, is_last_req, has_rd_req, // 38
    tag, axis_addr_align, axis_dw_len, axis_first_be, axis_last_be, // 91
    chnl_avail_reg, chnl_valid_reg, is_chnl_blocked, is_chnl_avail, is_nxt_req_blocked // 5
};
/* -------APB reated signal{end}------- */
`endif

/* --------read request blocking detection{begin}-------- */
assign is_chnl_avail   = (~is_chnl_blocked) | (~is_nxt_req_blocked);
assign is_chnl_blocked = chnl_valid_reg & (!chnl_avail_reg);
always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        chnl_avail_reg <= `TD 0;
        chnl_valid_reg <= `TD 0;
    end
    else begin
        chnl_avail_reg <= `TD chnl_avail;
        chnl_valid_reg <= `TD chnl_valid;
    end
end

always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        is_nxt_req_blocked <= `TD 1'b0;
    end
    else if (!is_chnl_blocked) begin
        is_nxt_req_blocked <= `TD 1'b0;
    end
    else if (is_chnl_blocked & axis_rd_request_tvalid & axis_rd_request_tready) begin
        is_nxt_req_blocked <= `TD 1'b1;
    end
end
/* --------read request blocking detection{end}-------- */

/* -------Head decode{begin}------- */
// Head storage
always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        reg_head    <= `TD 0;
    end
    else if (is_idle && rd_req_valid && rd_req_ready) begin
        reg_head    <= `TD rd_req_head;
    end
    else if (j_idle) begin
        reg_head    <= `TD 0;
    end
end

// Head decode
assign chnl_num       = reg_head[127:120];
assign byte_len_align = reg_head[12:0] + addr_unalign[1:0];
assign addr_unalign   = reg_head[95:32];
assign addr_align     = {addr_unalign[63:2], 2'd0};
assign dw_len         = (byte_len_align>>2) + |byte_len_align[1:0];
assign first_be       = ({4{addr_unalign[1:0] == 2'b00}} & 4'b1111) |
                        ({4{addr_unalign[1:0] == 2'b01}} & 4'b1110) |
                        ({4{addr_unalign[1:0] == 2'b10}} & 4'b1100) |
                        ({4{addr_unalign[1:0] == 2'b11}} & 4'b1000);
assign last_be        = ({4{byte_len_align[1:0] == 2'b00}} & 4'b1111) |
                        ({4{byte_len_align[1:0] == 2'b01}} & 4'b0001) |
                        ({4{byte_len_align[1:0] == 2'b10}} & 4'b0011) |
                        ({4{byte_len_align[1:0] == 2'b11}} & 4'b0111);
/* -------Head decode{end}------- */

/* -------Read request fragment{begin}------- */
// fragment info
assign max_rd_req_dw = (11'd1 << (5 + max_rd_req_sz));
assign dw_req        = dw_len - dw_sent;
assign is_only_req   = (is_get_tag | is_forward) & (max_rd_req_dw >= dw_len);
assign is_first_req  = (is_get_tag | is_forward) & (max_rd_req_dw < dw_len) & (dw_sent == 0);
assign is_middle_req = (is_get_tag | is_forward) & (max_rd_req_dw < dw_req) & (!is_first_req);
assign is_last_req   = (is_get_tag | is_forward) & (max_rd_req_dw >= dw_req) & (!is_only_req);
assign has_rd_req    = is_first_req | is_middle_req;
always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        dw_sent <= `TD 0;
    end
    else if (is_forward & axis_rd_request_tvalid & axis_rd_request_tready & has_rd_req) begin
        dw_sent <= `TD dw_sent + max_rd_req_dw;
    end
    else if (j_idle) begin
        dw_sent <= `TD 0;
    end
end


// axis tuser field
assign tag             = {`TAG_EMPTY+`TAG_WIDTH{1'd0}};
assign axis_addr_align = addr_align + (dw_sent << 2);
assign axis_dw_len     = ({`DW_LEN_WIDTH{is_only_req  }} & dw_len       ) |
                         ({`DW_LEN_WIDTH{is_first_req }} & max_rd_req_dw) |
                         ({`DW_LEN_WIDTH{is_middle_req}} & max_rd_req_dw) |
                         ({`DW_LEN_WIDTH{is_last_req  }} & dw_req       );
assign axis_first_be   = (is_only_req & (dw_req == 1)) ? (first_be & last_be) :
                         (is_last_req & (dw_req == 1)) ? last_be              : 
                         (is_only_req | is_first_req ) ? first_be             : 4'b1111;
                         
assign axis_last_be    = (is_only_req & (dw_req == 1)) ? 4'b0000 :
                         (is_last_req & (dw_req == 1)) ? 4'b0000 : 
                         (is_only_req | is_last_req  ) ? last_be : 4'b1111;
/* -------Read Request Fragment{end}------- */

/* -------{Read Request FSM}begin------- */
/******************** Stage 1: State Register **********************/
assign is_idle      = (cur_state == IDLE   );
assign is_get_tag   = (cur_state == GET_TAG);
assign is_forward   = (cur_state == FORWARD);
assign j_idle       = (cur_state == FORWARD) & axis_rd_request_tvalid & axis_rd_request_tready & !has_rd_req;

always @(posedge dma_clk, negedge rst_n) begin
    if(~rst_n)
        cur_state <= `TD IDLE;
    else
        cur_state <= `TD nxt_state;
end

/******************** Stage 2: State Transition **********************/

always @(*) begin
    case(cur_state)
        IDLE: begin
            if (rd_req_valid & rd_req_ready) begin
                nxt_state = GET_TAG;
            end
            else begin
                nxt_state = IDLE;
            end
        end
        GET_TAG: begin
            nxt_state = FORWARD;
        end
        FORWARD: begin
            if (axis_rd_request_tvalid & axis_rd_request_tready & has_rd_req) begin
                nxt_state = GET_TAG;
            end
            else if (axis_rd_request_tvalid & axis_rd_request_tready & !has_rd_req) begin
                nxt_state = IDLE;
            end
            else begin
                nxt_state = FORWARD;
            end
        end
        default: begin
            nxt_state = IDLE;
        end
    endcase
end
/******************** Stage 3: Output **********************/
// The module will not receive read req from the channel 
// if the channel is blocked.
assign rd_req_ready = is_idle & is_chnl_avail;

/* AXI-Stream read request tuser, every read request contains only one beat.
 * | chnl_num |last_sub_req | Reserved | REQ_TYPE |Tag(inv)| address | Reserved | DW length | first BE | last BE |
 * | 127:120  |     119     | 118:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
 */
// The module will not output sub_req if the channel id blocked
assign axis_rd_request_tvalid = is_forward & is_chnl_avail;
assign axis_rd_request_tlast  = is_forward;
assign axis_rd_request_tdata  = {`DMA_DATA_W{1'd0}};
assign axis_rd_request_tuser  = is_forward ? {chnl_num, !has_rd_req, 11'd0, `DMA_READ_REQ, tag, axis_addr_align, {24-`DW_LEN_WIDTH{1'd0}}, 
                                              axis_dw_len, axis_first_be, axis_last_be} : 0;
assign axis_rd_request_tkeep  = {`DMA_KEEP_W{1'd0}};

/* -------{Read Request FSM}end------- */


endmodule
