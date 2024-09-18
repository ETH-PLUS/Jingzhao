`timescale 1ns / 100ps
//*************************************************************************
// > File   : tgt_pyld_send_proc.v
// > Author : Kangning
// > Date   : 2022-08-28
// > Note   : DMA P2P target payload send processing
//*************************************************************************


`define stat_trans  if (qstruct_valid) begin                                \
                        nxt_state = DESC_PARSE;                          \
                    end                                                     \
                    else begin                                              \
                        nxt_state = IDLE;                                   \
                    end

module tgt_pyld_send_proc #(
    
) (

    input  wire clk  , // i, 1
    input  wire rst_n, // i, 1

    /* --------Info from queue struct{begin}-------- */
    /* qstruct_head_ctx : qcontext of prepared queue
     * qstruct_head_desc: payload descriptor
     * qstruct_buf_addr : allocated buffer base address in P2P pyld_buf, 
     *                    this is an array. A valid addr outputs when valid
     *                    and ready assert at the same time.
     * qstruct_last     : assert when the last qstruct_buf_addr is asserted
     */
    input  wire                             qstruct_valid    , // i, 1
    input  wire                             qstruct_last     , // i, 1
    input  wire [`QUEUE_CONTEXT_WIDTH-1:0]  qstruct_head_ctx , // i, `QUEUE_CONTEXT_WIDTH
    input  wire [`QUEUE_DESC_WIDTH   -1:0]  qstruct_head_desc, // i, `QUEUE_DESC_WIDTH
    input  wire [`BUF_ADDR_WIDTH     -1:0]  qstruct_buf_addr , // i, `BUF_ADDR_WIDTH
    output wire                             qstruct_ready    , // o, 1
    /* --------Info from queue struct{end}-------- */

    /* --------Ctrl Info to pyld_buf{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved |dst_dev| src_dev | Reserved | Byte length |
     * |  63:-    | 47:40 |  39:32  |  31:16   |    15:0     |
     */
    output wire                       pbuf_free_valid     , // o, 1
    output wire                       pbuf_free_last      , // o, 1
    output wire [`P2P_DHEAD_W   -1:0] pbuf_free_head      , // o, `P2P_DHEAD_W
    output wire [1:0]                 pbuf_free_buf_offset, // o, 2
    output wire [`BUF_ADDR_WIDTH-1:0] pbuf_free_buf_addr  , // o, `BUF_ADDR_WIDTH
    input  wire                       pbuf_free_ready     , // i, 1
    /* --------Ctrl Info to pyld_buf{begin}-------- */

    /* --------p2p mem payload out{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved |dst_dev| src_dev | Reserved | Byte length |
     * |  63:-    | 47:40 |  39:32  |  31:16   |    15:0     |
     */
    input  wire                    ft_pyld_req_valid, // i, 1
    input  wire                    ft_pyld_req_last , // i, 1
    input  wire [`P2P_DHEAD_W-1:0] ft_pyld_req_head , // i, `P2P_DHEAD_W
    input  wire [`P2P_DATA_W -1:0] ft_pyld_req_data , // i, `P2P_DATA_W
    output wire                    ft_pyld_req_ready, // o, 1
    /* --------p2p mem payload out{end}-------- */

    /* --------p2p forward down channel{begin}-------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved |dst_dev| src_dev | Reserved | Byte length |
     * |  63:-    | 47:40 |  39:32  |  31:16   |    15:0     |
     */
    output wire                    st_p2p_down_valid, // o, 1             
    output wire                    st_p2p_down_last , // o, 1             
    output wire [`P2P_DHEAD_W-1:0] st_p2p_down_head , // o, `P2P_DHEAD_W
    output wire [`P2P_DATA_W -1:0] st_p2p_down_data , // o, `P2P_DATA_W  
    input  wire                    st_p2p_down_ready  // i, 1        
    /* --------p2p forward down channel{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
	,output wire [`TGT_SEND_SIGNAL_W-1:0] dbg_signal // o, `TGT_SEND_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

localparam BEAT_BYTE_NUM = `P2P_DATA_W / 8;

/* --------Payload Sending FSM{begin}-------- */
localparam  IDLE       = 2'b01,
            DESC_PARSE = 2'b10;

reg [1:0] cur_state;
reg [1:0] nxt_state;

wire [47               :0] qctx_slid ;
wire [47               :0] qdesc_dlid;
wire [`MSG_BLEN_WIDTH-1:0] qdesc_blen;
wire [`DEV_NUM_WIDTH -1:0] qdesc_sdev;
wire [`DEV_NUM_WIDTH -1:0] qdesc_ddev;

wire [1:0] last_offset;
reg  [1:0] ft_offset  ;

wire is_idle, is_desc_parse;
wire is_nxt_desc_parse;
/* --------Payload Sending FSM{end}-------- */

/* --------p2p forward down channel{begin}-------- */
/* *_head, valid only in first beat of a packet
 * | Reserved |dst_dev| src_dev | Reserved | Byte length |
 * |  63:-    | 47:40 |  39:32  |  31:16   |    15:0     |
 */
wire                    p2p_down_valid;
wire                    p2p_down_last ;
wire [`P2P_DATA_W -1:0] p2p_down_data ;
wire [`P2P_DHEAD_W-1:0] p2p_down_head ;
wire                    p2p_down_ready;
/* --------p2p forward down channel{end}-------- */

//-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign dbg_signal = { // 462

    cur_state, nxt_state, // 4
    qctx_slid , qdesc_dlid, qdesc_blen, qdesc_sdev, qdesc_ddev, // 128
    last_offset, ft_offset  , // 4
    is_idle, is_desc_parse, is_nxt_desc_parse, // 3
    p2p_down_valid, p2p_down_last , p2p_down_data , p2p_down_head , p2p_down_ready  // 323
};
/* -------APB reated signal{end}------- */
`endif

/* -------Payload Sending FSM{begin}------- */
/******************** Stage 1: State Register **********************/
assign is_idle       = (cur_state == IDLE      );
assign is_desc_parse = (cur_state == DESC_PARSE);

assign is_nxt_desc_parse = ((nxt_state == DESC_PARSE) & (cur_state == IDLE      )) |
                           ((nxt_state == DESC_PARSE) & (cur_state == DESC_PARSE) & p2p_down_valid & p2p_down_ready & p2p_down_last);

// assign last_offset = qdesc_blen[`PBUF_SZ_LOG-1:`PBUF_SZ_LOG-2] + |qdesc_blen[`PBUF_SZ_LOG-3:0] - 2'b1;
assign qctx_slid  = qstruct_head_ctx[47:0];
assign qdesc_dlid = {qstruct_head_desc[79:64], qstruct_head_desc[31:0]};
assign qdesc_blen = qstruct_head_desc[47:32];
assign qdesc_sdev = qstruct_head_desc[55:48];
assign qdesc_ddev = qstruct_head_desc[63:56];
assign last_offset = qdesc_blen[`PBUF_SZ_LOG-1:`PBUF_SZ_LOG-2] + |qdesc_blen[`PBUF_SZ_LOG-3:0] - 2'b1;

always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        ft_offset <= `TD 2'd0;
    end
    else if (is_desc_parse & pbuf_free_valid & pbuf_free_ready & pbuf_free_last) begin
        ft_offset <= `TD 2'd0;
    end
    else if (is_desc_parse & pbuf_free_valid & pbuf_free_ready) begin
        ft_offset <= `TD ft_offset + 2'd1;
    end
end

always @(posedge clk, negedge rst_n) begin
    if(~rst_n)
        cur_state <= `TD IDLE;
    else
        cur_state <= `TD nxt_state;
end
/******************** Stage 2: State Transition **********************/

always @(*) begin
    case(cur_state)
        IDLE: begin
            `stat_trans
            // if (qstruct_valid) begin
            //     nxt_state = DESC_PARSE;
            // end
            // else begin
            //     nxt_state = IDLE;
            // end
        end
        DESC_PARSE: begin
            if (p2p_down_valid & p2p_down_ready & p2p_down_last) begin
                `stat_trans
            end
            else begin
                nxt_state = DESC_PARSE;
            end
        end
        default: begin
            nxt_state = IDLE;
        end
    endcase
end
/******************** Stage 3: Output **********************/

assign qstruct_ready       = ((ft_offset == 3) || pbuf_free_last) & pbuf_free_ready & is_desc_parse;

assign pbuf_free_valid      = qstruct_valid & is_desc_parse;
assign pbuf_free_last       = qstruct_last & (ft_offset == last_offset);
assign pbuf_free_head       = {{32-2*`DEV_NUM_WIDTH{1'd0}}, qdesc_ddev, qdesc_sdev, 16'd0, qdesc_blen};
assign pbuf_free_buf_offset = ft_offset       ;
assign pbuf_free_buf_addr   = qstruct_buf_addr;


/* *_head, valid only in first beat of a packet
 * | Reserved |dst_dev| src_dev | Reserved | Byte length |
 * |  63:-    | 47:40 |  39:32  |  31:16   |    15:0     |
 */
assign p2p_down_valid = ft_pyld_req_valid;
assign p2p_down_last  = ft_pyld_req_last;
assign p2p_down_head  = ft_pyld_req_head;
assign p2p_down_data  = ft_pyld_req_data;
assign ft_pyld_req_ready = p2p_down_ready;

st_reg #(
    .TUSER_WIDTH ( `P2P_DHEAD_W ),
    .TDATA_WIDTH ( `P2P_DATA_W  ) 
) st_reg2down (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* -------input axis-like interface{begin}------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved |dst_dev| src_dev | Reserved | Byte length |
     * |  63:-    | 47:40 |  39:32  |  31:16   |    15:0     |
     */
    .axis_tvalid ( p2p_down_valid ), // i, 1
    .axis_tlast  ( p2p_down_last  ), // i, 1
    .axis_tuser  ( p2p_down_head  ), // i, TUSER_WIDTH
    .axis_tdata  ( p2p_down_data  ), // i, TDATA_WIDTH
    .axis_tready ( p2p_down_ready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    /* *_head, valid only in first beat of a packet
     * | Reserved |dst_dev| src_dev | Reserved | Byte length |
     * |  63:-    | 47:40 |  39:32  |  31:16   |    15:0     |
     */
    .axis_reg_tvalid ( st_p2p_down_valid ), // o, 1  // read valid from input register
    .axis_reg_tlast  ( st_p2p_down_last  ), // o, 1 
    .axis_reg_tuser  ( st_p2p_down_head  ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( st_p2p_down_data  ), // o, TDATA_WIDTH
    .axis_reg_tready ( st_p2p_down_ready )  // i, 1
    /* -------output in_reg inteface{end}------- */
);
/* -------Payload Sending FSM{end}------- */

endmodule 
