`timescale 1ns / 100ps
//*************************************************************************
// > File Name: rsp_data_fifo.v
// > Author   : Kangning
// > Date     : 2020-11-15
// > Note     : rsp_data_fifo, store and concat multi-pkts into one message. 
//              Note that the fifo could store more than one message.
// > ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
// > ^                                                              ^
// > ^        ##########       ###########                          ^
// > ^        #        #------># tmp_reg #      ###########         ^
// > ^ ------># in_reg #       ###########----->#         #         ^
// > ^        #        #                        #data_fifo#---->    ^
// > ^        ##########----------------------->#         #         ^
// > ^                                          ###########         ^
// > ^                                                              ^
// > ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
//*************************************************************************

module rsp_data_fifo #(
    
) (
    input  wire dma_clk, // i, 1
    input  wire rst_n  , // i, 1

    /* ------- sub_req rsp input{begin} ------- */
    input  wire                      sub_req_rsp_valid, // i, 1
    input  wire                      sub_req_rsp_last , // i, 1; indicate the last cycle of the whole req rsp
    input  wire [`DMA_LEN_WIDTH-1:0] sub_req_rsp_blen , // i, `DMA_LEN_WIDTH; blen for every cycle
    input  wire [`DMA_DATA_W   -1:0] sub_req_rsp_data , // i, `DMA_DATA_W
    output wire                      sub_req_rsp_ready, // o, 1
    /* ------- sub_req rsp input{end} ------- */

    /* ------- rsp output{begin} ------- */
    output wire                   req_rsp_valid, // o, 1
    output wire [`DMA_DATA_W-1:0] req_rsp_data , // o, `DMA_DATA_W
    input  wire                   req_rsp_ready  // i, 1
    /* ------- rsp output{end} ------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [`SRAM_RW_DATA_W-1:0] rw_data// i, `SRAM_RW_DATA_W
    ,output wire [`DATA_FIFO_SIGNAL_W-1:0] dbg_signal  // o, `DATA_FIFO_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

/* -------in_reg{begin}------- */
wire                      in_reg_valid;
wire                      in_reg_last ;
wire [`DMA_LEN_WIDTH-1:0] in_reg_blen ;
wire [`DMA_DATA_W   -1:0] in_reg_data ;
wire                      in_reg_ready;
/* -------in_reg{end}------- */

/* -------tmp_reg{begin}------- */
wire                      in_tmp_valid;
wire                      in_tmp_last ;
wire [`DMA_LEN_WIDTH-1:0] in_tmp_blen ;
wire [`DMA_DATA_W   -1:0] in_tmp_data ;
wire                      in_tmp_ready;

wire [`DMA_LEN_WIDTH  :0] avail_bytes;
wire [`DMA_DATA_W   -1:0] concat_tmp_data;

wire                      tmp_reg_valid;
wire                      tmp_reg_last ;
wire [`DMA_LEN_WIDTH-1:0] tmp_reg_blen ;
wire [`DMA_DATA_W   -1:0] tmp_reg_data ;
wire                      tmp_reg_ready;
/* -------tmp_reg{end}------- */

/* -------data fifo{begin}------- */
wire is_msg_eop;

wire                   in_fifo_wen ;
wire [`DMA_DATA_W-1:0] in_fifo_data;
wire                   in_fifo_full;

wire                   out_fifo_ren  ;
wire [`DMA_DATA_W-1:0] out_fifo_data ;
wire                   out_fifo_empty;
/* -------data fifo{end}------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire  [1:0]  rtsel;
wire  [1:0]  wtsel;
wire  [1:0]  ptsel;
wire         vg   ;
wire         vs   ;
/* -------APB reated signal{end}------- */
`endif

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign {rtsel, wtsel, ptsel, vg, vs} = rw_data;
assign dbg_signal = { // 1602
    in_reg_valid, in_reg_last , in_reg_blen , in_reg_data , in_reg_ready, // 272
    in_tmp_valid, in_tmp_last , in_tmp_blen , in_tmp_data , in_tmp_ready, // 272
    avail_bytes, concat_tmp_data, // 269
    tmp_reg_valid, tmp_reg_last, tmp_reg_blen, tmp_reg_data, tmp_reg_ready, // 272
    is_msg_eop, // 1
    in_fifo_wen, in_fifo_data, in_fifo_full, // 258
    out_fifo_ren, out_fifo_data, out_fifo_empty  // 258
};
/* -------APB reated signal{end}------- */
`endif

/* -------in_reg{begin}------- */
st_reg #(
    .TUSER_WIDTH ( 1 ),
    .TDATA_WIDTH ( `DMA_DATA_W + `DMA_LEN_WIDTH )
) in_st_reg (
    .clk   ( dma_clk ), // i, 1
    .rst_n ( rst_n   ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( sub_req_rsp_valid ), // i, 1
    .axis_tlast  ( sub_req_rsp_last  ), // i, 1
    .axis_tuser  ( 1'd0 ), // i, TUSER_WIDTH
    .axis_tdata  ( {sub_req_rsp_blen, sub_req_rsp_data} ), // i, TDATA_WIDTH
    .axis_tready ( sub_req_rsp_ready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .axis_reg_tvalid ( in_reg_valid ), // o, 1
    .axis_reg_tlast  ( in_reg_last  ), // o, 1
    .axis_reg_tuser  (  ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( {in_reg_blen, in_reg_data} ), // o, TDATA_WIDTH
    .axis_reg_tready ( in_reg_ready )  // i, 1
    /* -------output in_reg inteface{end}------- */
);

assign in_reg_ready = !in_fifo_full & !is_msg_eop; // & tmp_reg_valid 
/* -------in_reg{end}------- */

/* -------tmp_reg{begin}------- */
assign in_tmp_valid = in_reg_valid & in_reg_ready & (avail_bytes != `DMA_W_BCNT);
assign in_tmp_last  = in_reg_last  & (avail_bytes != `DMA_W_BCNT);
assign in_tmp_blen  = (avail_bytes <  `DMA_W_BCNT) ? avail_bytes                 :
                      (avail_bytes == `DMA_W_BCNT) ? {`DMA_LEN_WIDTH{1'b0}}      :
                      (avail_bytes >  `DMA_W_BCNT) ? (avail_bytes - `DMA_W_BCNT) : {`DMA_LEN_WIDTH{1'b0}};
assign in_tmp_data  = (avail_bytes <  `DMA_W_BCNT) ? concat_tmp_data                                      : 
                      (avail_bytes == `DMA_W_BCNT) ? {`DMA_DATA_W{1'b0}}                                  :
                      (avail_bytes >  `DMA_W_BCNT) ? (in_reg_data >> ((`DMA_W_BCNT - tmp_reg_blen) << 3)) : {`DMA_DATA_W{1'b0}};

assign avail_bytes     = (is_msg_eop ? {`DMA_LEN_WIDTH{1'b0}} : tmp_reg_blen) + in_reg_blen;
assign concat_tmp_data = (in_reg_data << (tmp_reg_blen << 3)) | (tmp_reg_data); //  & ((1 << (tmp_reg_blen << 3))-1)

st_reg #(
    .TUSER_WIDTH ( 1 ),
    .TDATA_WIDTH ( `DMA_LEN_WIDTH + `DMA_DATA_W )
) tmp_st_reg (
    .clk   ( dma_clk ), // i, 1
    .rst_n ( rst_n   ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( in_tmp_valid ), // i, 1
    .axis_tlast  ( in_tmp_last  ), // i, 1
    .axis_tuser  ( 1'd0 ), // i, TUSER_WIDTH
    .axis_tdata  ( {in_tmp_blen, in_tmp_data} ), // i, TDATA_WIDTH
    .axis_tready ( in_tmp_ready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output st_reg inteface{begin}------- */
    .axis_reg_tvalid ( tmp_reg_valid ), // o, 1
    .axis_reg_tlast  ( tmp_reg_last  ), // o, 1
    .axis_reg_tuser  (  ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( {tmp_reg_blen, tmp_reg_data} ), // o, TDATA_WIDTH
    .axis_reg_tready ( tmp_reg_ready )  // i, 1
    /* -------output st_reg inteface{end}------- */
);
/* 
 * Assert when fifo is not full && there's bytes in tem_reg (tem_reg_blen != 0) && (
 *  1. in_reg data is valid ||
 *  2. The last cycle of the message, draining the last cycle
 * ) 
 */
assign tmp_reg_ready = !in_fifo_full & (in_reg_valid | is_msg_eop);
/* -------tmp_reg{end}------- */

/* -------data fifo{begin}------- */
assign is_msg_eop   = (tmp_reg_valid & tmp_reg_last & tmp_reg_blen != 0);

assign in_fifo_wen  = (in_reg_valid & (avail_bytes >= `DMA_W_BCNT))| is_msg_eop;
assign in_fifo_data = is_msg_eop ? tmp_reg_data : concat_tmp_data; 
pcieifc_sync_fifo #(
    .DSIZE ( `DMA_DATA_W ), // 256
    .ASIZE ( `RSP_FIFO_DEPTH_LOG )  // 4KB payload capacity
) data_fifo (
    .clk   ( dma_clk ), // i, 1
    .rst_n ( rst_n   ), // i, 1
    .clr   ( 1'd0    ), // i, 1

    .wen   ( in_fifo_wen   ), // i, 1
    .din   ( in_fifo_data  ), // i, DSIZE
    .full  ( in_fifo_full  ), // o, 1

    .ren   ( out_fifo_ren   ), // i, 1
    .dout  ( out_fifo_data  ), // o, DSIZE
    .empty ( out_fifo_empty )  // o, 1

`ifdef PCIEI_APB_DBG
    ,.rtsel ( rtsel )  // i, 2
    ,.wtsel ( wtsel )  // i, 2
    ,.ptsel ( ptsel )  // i, 2
    ,.vg    ( vg    )  // i, 1
    ,.vs    ( vs    )  // i, 1
`endif
);
assign out_fifo_ren = req_rsp_valid & req_rsp_ready;
/* -------data fifo{end}------- */

/* ------- rsp output{begin} ------- */
assign req_rsp_valid = !out_fifo_empty;
assign req_rsp_data  = out_fifo_data;
/* ------- rsp output{end} ------- */

endmodule