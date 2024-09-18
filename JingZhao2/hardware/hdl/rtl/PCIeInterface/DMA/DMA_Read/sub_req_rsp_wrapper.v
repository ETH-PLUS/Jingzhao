`timescale 1ns / 100ps
//*************************************************************************
// > File   : sub_req_rsp_wrapper.v
// > Author : Kangning
// > Date   : 2022-06-29
// > Note   : Wrapper for sub_req_rsp interface
//*************************************************************************

module sub_req_rsp_wrapper #(
    
) (
    input wire dma_clk, // i, 1
    input wire rst_n  , // i, 1

    /* ------- Read Response output{begin} ------- */
    /* *_head
     * | Reserved | address | Reserved | Byte length |
     * |  127:96  |  95:32  |  31:13   |    12:0     |
     */
    output wire                    ft_rd_rsp_ren , // o, 1
    output wire [`TAG_NUM_LOG-1:0] ft_rd_rsp_tag , // o, `TAG_NUM_LOG
    input  wire [`DMA_HEAD_W -1:0] ft_rd_rsp_head, // i, `DMA_HEAD_W
    input  wire [`DMA_DATA_W -1:0] ft_rd_rsp_data, // i, `DMA_DATA_W
    input  wire                    ft_rd_rsp_last, // i, 1
    input  wire                    ft_rd_rsp_vld , // i, 1
    /* ------- Read Response output{end} ------- */

    /* -------tag release{begin}------- */
    output wire                     nxt_match_ready, // o, 1
    input  wire                     nxt_match_last , // i, 1
    input  wire [`DW_LEN_WIDTH-1:0] nxt_match_sz   , // i, `DW_LEN_WIDTH
    input  wire [`TAG_MISC    -1:0] nxt_match_misc , // i, `TAG_MISC ; Including addr && dw empty info
    input  wire [8            -1:0] nxt_match_chnl , // i, `DMA_RD_CHNL_NUM_LOG
    input  wire [`TAG_NUM_LOG -1:0] nxt_match_tag  , // i, `TAG_NUM_LOG
    input  wire                     nxt_match_valid, // i, 1
    /* -------tag release{end}------- */

    /* ------- Read sub-req response{begin} ------- */
    /* dma_*_head
     * | emit | chnl_num | Reserved | address | Reserved | Byte length |
     * | 127  | 126:120  |  119:96  |  95:32  |  31:13   |    12:0     |
     */
    output  wire                   st_sub_req_rsp_valid, // o, 1
    output  wire                   st_sub_req_rsp_last , // o, 1
    output  wire [`DMA_DATA_W-1:0] st_sub_req_rsp_data , // o, `DMA_DATA_W
    output  wire [`DMA_HEAD_W-1:0] st_sub_req_rsp_head , // o, `DMA_HEAD_W
    input   wire                   st_sub_req_rsp_ready  // i, 1
    /* ------- Read sub-req response{end} ------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [31:0] dbg_sel  // i, 32
    ,output wire [31:0] dbg_bus  // o, 32
    /* -------APB reated signal{end}------- */
`endif
);


/* -------sub_req_rsp_head generation {begin}------- */
reg  [0             :0] last    ;
reg  [12            :0] size    ;
reg  [`TAG_NUM_LOG-1:0] tag     ;
reg  [7             :0] chnl_num;
reg  [6             :0] addr    ;
reg  [`DMA_LEN_WIDTH-1:0] byte_len;
/* ------- sub_req_rsp_head generation{end}------- */

/* -------State relevant to FSM{begin}------- */
localparam IDLE      = 2'b01, // Wait for the the release of tag fifo
           FORWARD   = 2'b10; // Store the the response to reorder buffer till the out_reg send its 
                              // last beat. Then jump to IDLE.

reg [1:0] cur_state;
reg [1:0] nxt_state;

wire is_idle, is_forward;
wire j_forward, j_idle;
wire nxt_forward;
/* -------State relevant to FSM{end}------- */

/* ------- Read sub-req response{begin} ------- */
/* dma_*_head
 * | emit | chnl_num | Reserved | address | Reserved | Byte length |
 * | 127  | 126:120  |  119:96  |  95:32  |  31:13   |    12:0     |
 */
wire                   sub_req_rsp_valid;
wire                   sub_req_rsp_last ;
wire [`DMA_DATA_W-1:0] sub_req_rsp_data ;
wire [`DMA_HEAD_W-1:0] sub_req_rsp_head ;
wire                   sub_req_rsp_ready;
/* ------- Read sub-req response{end} ------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire [`WRAPPER_SIGNAL_W-1:0] dbg_signal;  
/* -------APB reated signal{end}------- */
`endif

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------- //

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign dbg_bus = dbg_signal >> {dbg_sel, 5'd0};

assign dbg_signal = { // 444
    last, size, tag, chnl_num, addr, byte_len, // 48
    cur_state, nxt_state, // 4
    is_idle, is_forward, // 2
    j_forward, j_idle, // 2
    nxt_forward, // 1
    sub_req_rsp_valid, sub_req_rsp_last , sub_req_rsp_data , sub_req_rsp_head , sub_req_rsp_ready // 387
};
/* -------APB reated signal{end}------- */
`endif

/* -------{Read Response FSM}begin------- */
/******************** Stage 1: State Register **********************/
assign is_idle    = (cur_state == IDLE   );
assign is_forward = (cur_state == FORWARD);

assign j_forward  = (cur_state == IDLE) & nxt_match_valid;
assign nxt_forward = (cur_state == IDLE) & nxt_match_valid;

assign j_idle     = (cur_state == FORWARD) & (sub_req_rsp_valid & sub_req_rsp_ready & sub_req_rsp_last);

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
            if (nxt_match_valid) begin
                nxt_state = FORWARD;
            end
            else begin
                nxt_state = IDLE;
            end
        end
        FORWARD: begin
            if (sub_req_rsp_valid & sub_req_rsp_ready & sub_req_rsp_last) begin
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

// interface with Reorder buffer Fetch
assign ft_rd_rsp_ren = is_forward & sub_req_rsp_ready;
assign ft_rd_rsp_tag = tag;

// interface with Non-posted Tag Management
assign nxt_match_ready = is_forward & sub_req_rsp_valid & sub_req_rsp_ready & sub_req_rsp_last; // j_forward | nxt_forward;

// sub_req_rsp interface
/* dma_*_head
 * | emit | chnl_num | Reserved | address | Reserved | Byte length |
 * | 127  | 126:120  |  119:96  |  95:32  |  31:13   |    12:0     |
 */
assign sub_req_rsp_valid = ft_rd_rsp_vld & is_forward;
assign sub_req_rsp_last  = sub_req_rsp_valid ? ft_rd_rsp_last : 0;
assign sub_req_rsp_head  = sub_req_rsp_valid ? {((last << 7) | chnl_num), 81'd0, addr, 19'd0, byte_len} : 0;
assign sub_req_rsp_data  = sub_req_rsp_valid ? ft_rd_rsp_data : 0;
/* -------{Read Response FSM}end------- */


/* -------Sub req rsp signal generation{begin}------- */
always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        last      <= `TD 0;
        size      <= `TD 0;
        tag       <= `TD 0;
        chnl_num  <= `TD 0;
        addr      <= `TD 0;
        byte_len  <= `TD 0;
    end
    else if (j_idle) begin
        last      <= `TD 0;
        size      <= `TD 0;
        tag       <= `TD 0;
        chnl_num  <= `TD 0;
        addr      <= `TD 0;
        byte_len  <= `TD 0;
    end
    else if (j_forward) begin // j_forward | nxt_forward
        last     <= `TD nxt_match_last;
        size     <= `TD nxt_match_sz  ;
        tag      <= `TD nxt_match_tag ;
        chnl_num <= `TD nxt_match_chnl;
        addr     <= `TD nxt_match_misc[11:5];
        byte_len <= `TD (nxt_match_sz << 2) - nxt_match_misc[4:0];
    end
end
/* -------Sub req rsp signal generation{end}------- */

/* -------output reg{begin}------- */
assign st_sub_req_rsp_valid = sub_req_rsp_valid;
assign st_sub_req_rsp_last  = sub_req_rsp_last ;
assign st_sub_req_rsp_head  = sub_req_rsp_head ;
assign st_sub_req_rsp_data  = sub_req_rsp_data ;
assign sub_req_rsp_ready    = st_sub_req_rsp_ready;
// st_reg #(
//     .TUSER_WIDTH ( `DMA_HEAD_W ),
//     .TDATA_WIDTH ( `DMA_DATA_W )
// ) out_st_reg (
//     .clk   ( dma_clk ), // i, 1
//     .rst_n ( rst_n   ), // i, 1

//     /* -------input axis-like interface{begin}------- */
//     .axis_tvalid ( sub_req_rsp_valid ), // i, 1
//     .axis_tlast  ( sub_req_rsp_last  ), // i, 1
//     .axis_tuser  ( sub_req_rsp_head  ), // i, TUSER_WIDTH
//     .axis_tdata  ( sub_req_rsp_data  ), // i, TDATA_WIDTH
//     .axis_tready ( sub_req_rsp_ready ), // o, 1
//     /* -------input axis-like interface{end}------- */

//     /* -------output in_reg inteface{begin}------- */
//     .axis_reg_tvalid ( st_sub_req_rsp_valid ), // o, 1
//     .axis_reg_tlast  ( st_sub_req_rsp_last  ), // o, 1
//     .axis_reg_tuser  ( st_sub_req_rsp_head  ), // o, TUSER_WIDTH
//     .axis_reg_tdata  ( st_sub_req_rsp_data  ), // o, TDATA_WIDTH
//     .axis_reg_tready ( st_sub_req_rsp_ready )  // i, 1
//     /* -------output in_reg inteface{end}------- */
// );
/* -------output reg{end}------- */

endmodule