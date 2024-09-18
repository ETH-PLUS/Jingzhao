`timescale 1ns / 100ps
//*************************************************************************
// > File   : tag_matching.v
// > Author : Kangning
// > Date   : 2022-11-03
// > Note   : Match tags for different channels. 
//            Note that : 
//              1. The channel is under comparsion only when it is not stalled;
//              2. 
//*************************************************************************

module tag_matching #(
    
) (
    input wire dma_clk, // i, 1
    input wire rst_n  , // i, 1

    /* -------tag release{begin}------- */
    // Note that only one channel is allowed to assert at the same time
    output wire [`DMA_RD_CHNL_NUM * 1             - 1 : 0] tag_rrsp_ready, // o, 1
    input  wire [`DMA_RD_CHNL_NUM * 1             - 1 : 0] tag_rrsp_last , // i, 1
    input  wire [`DMA_RD_CHNL_NUM * `DW_LEN_WIDTH - 1 : 0] tag_rrsp_sz   , // i, `DW_LEN_WIDTH
    input  wire [`DMA_RD_CHNL_NUM * `TAG_MISC     - 1 : 0] tag_rrsp_misc , // i, `TAG_MISC ; Including addr && dw empty info
    input  wire [`DMA_RD_CHNL_NUM * `TAG_NUM_LOG  - 1 : 0] tag_rrsp_tag  , // i, `TAG_NUM_LOG
    input  wire [`DMA_RD_CHNL_NUM * 1             - 1 : 0] tag_rrsp_valid, // i, 1
    /* -------tag release{end}------- */

    /* ------- Read Response input{begin} ------- */
    input  wire                       st_rd_rsp_wen , // i, 1
    input  wire                       st_rd_rsp_last, // i, 1 ; assert in every last beat of sub-rsp pkt
    input  wire [`DW_LEN_WIDTH-1:0]   st_rd_rsp_dlen, // i, `DW_LEN_WIDTH ; part of head field in "store channel"
    input  wire [`TAG_NUM_LOG -1:0]   st_rd_rsp_tag , // i, `TAG_NUM_LOG  ; part of head field in "store channel"
    input  wire                       st_rd_rsp_rdy , // i, 1
    /* ------- Read Response input{end} ------- */

    /* --------chnl_stall{begin}-------- */
    input  wire [`DMA_RD_CHNL_NUM - 1 : 0] chnl_avail, // i, `DMA_RD_CHNL_NUM
    /* --------chnl_stall{end}-------- */

    /* -------tag release{begin}------- */
    input  wire                     nxt_match_ready, // i, 1
    output wire                     nxt_match_last , // o, 1
    output wire [`DW_LEN_WIDTH-1:0] nxt_match_sz   , // o, `DW_LEN_WIDTH
    output wire [`TAG_MISC    -1:0] nxt_match_misc , // o, `TAG_MISC ; Including addr && dw empty info
    output wire [8            -1:0] nxt_match_chnl , // o, 8
    output wire [`TAG_NUM_LOG -1:0] nxt_match_tag  , // o, `TAG_NUM_LOG
    output wire                     nxt_match_valid  // o, 1
    /* -------tag release{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [31:0] dbg_sel  // i, 32
    ,output wire [31:0] dbg_bus  // o, 32
    /* -------APB reated signal{end}------- */
`endif
);

localparam CHNL_DATA_W = (`TAG_NUM_LOG + 8 + `DW_LEN_WIDTH + 1 + `TAG_MISC);

/* -------rebuf log SRAM{begin}------- */
reg                      rebuf_log_sram_tag [`TAG_NUM-1:0]; // store all the tags in reorder buffer.
reg  [`DW_LEN_WIDTH-1:0] rebuf_log_sram_len [`TAG_NUM-1:0]; // Store all the accumulate len stored 
                                                             // in reorder buffer (in dw unit).
/* -------rebuf log SRAM{end}------- */

/* -------tag release{begin}------- */
// Note that only one channel is allowed to assert at the same time
wire [1             - 1 : 0] tag_chnl_last      [`DMA_RD_CHNL_NUM-1:0];
wire [`DW_LEN_WIDTH - 1 : 0] tag_chnl_sz        [`DMA_RD_CHNL_NUM-1:0];
wire [`TAG_MISC     - 1 : 0] tag_chnl_misc      [`DMA_RD_CHNL_NUM-1:0];
wire [8             - 1 : 0] tag_chnl_chnl      [`DMA_RD_CHNL_NUM-1:0];
wire [`TAG_NUM_LOG  - 1 : 0] tag_chnl_tag       [`DMA_RD_CHNL_NUM-1:0];
wire [1             - 1 : 0] is_chnl_match      [`DMA_RD_CHNL_NUM-1:0];
wire [`DMA_RD_CHNL_NUM * 1           - 1 : 0] tag_chnl_valid;
wire [`DMA_RD_CHNL_NUM * CHNL_DATA_W - 1 : 0] tag_chnl_data ;
wire [`DMA_RD_CHNL_NUM * 1           - 1 : 0] tag_chnl_ready;
/* -------tag release{end}------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire [`TAG_MATCHING_SIGNAL_W-1:0] dbg_signal;  
/* -------APB reated signal{end}------- */
`endif

//----------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
generate
if (`DMA_RD_CHNL_NUM == 9) begin: CHNL_NUM9

assign dbg_bus = dbg_signal >> {dbg_sel, 5'd0};

assign dbg_signal = { // 693
    tag_chnl_last[0], tag_chnl_sz[0], tag_chnl_misc[0], tag_chnl_chnl[0], tag_chnl_tag[0], is_chnl_match[0], 
    tag_chnl_last[1], tag_chnl_sz[1], tag_chnl_misc[1], tag_chnl_chnl[1], tag_chnl_tag[1], is_chnl_match[1], 
    tag_chnl_last[2], tag_chnl_sz[2], tag_chnl_misc[2], tag_chnl_chnl[2], tag_chnl_tag[2], is_chnl_match[2], 
    tag_chnl_last[3], tag_chnl_sz[3], tag_chnl_misc[3], tag_chnl_chnl[3], tag_chnl_tag[3], is_chnl_match[3], 
    tag_chnl_last[4], tag_chnl_sz[4], tag_chnl_misc[4], tag_chnl_chnl[4], tag_chnl_tag[4], is_chnl_match[4], 
    tag_chnl_last[5], tag_chnl_sz[5], tag_chnl_misc[5], tag_chnl_chnl[5], tag_chnl_tag[5], is_chnl_match[5], 
    tag_chnl_last[6], tag_chnl_sz[6], tag_chnl_misc[6], tag_chnl_chnl[6], tag_chnl_tag[6], is_chnl_match[6], 
    tag_chnl_last[7], tag_chnl_sz[7], tag_chnl_misc[7], tag_chnl_chnl[7], tag_chnl_tag[7], is_chnl_match[7], 
    tag_chnl_last[8], tag_chnl_sz[8], tag_chnl_misc[8], tag_chnl_chnl[8], tag_chnl_tag[8], is_chnl_match[8], // 9 * 39
    tag_chnl_valid, tag_chnl_data, tag_chnl_ready  // 9 * 38
};
end
endgenerate
/* -------APB reated signal{end}------- */
`endif

/* -------Generate block{begin}------- */
genvar i;
generate
for (i = 0; i < `DMA_RD_CHNL_NUM; i = i + 1) begin:TAG_CHNL

    assign tag_chnl_last [i] = tag_rrsp_last [(i+1) * 1             - 1 : i * 1            ];
    assign tag_chnl_sz   [i] = tag_rrsp_sz   [(i+1) * `DW_LEN_WIDTH - 1 : i * `DW_LEN_WIDTH];
    assign tag_chnl_misc [i] = tag_rrsp_misc [(i+1) * `TAG_MISC     - 1 : i * `TAG_MISC    ];
    assign tag_chnl_chnl [i] = i;
    assign tag_chnl_tag  [i] = tag_rrsp_tag  [(i+1) * `TAG_NUM_LOG  - 1 : i * `TAG_NUM_LOG ];
    assign is_chnl_match [i] = rebuf_log_sram_tag[tag_chnl_tag[i]] &                            // has returned rsp for this tag
                               (rebuf_log_sram_len[tag_chnl_tag[i]] == tag_chnl_sz[i]) &        // all sub_rsp has returned
                               chnl_avail[i];                                                   // the channel is not blocked

    assign tag_chnl_valid[i] = tag_rrsp_valid[i] & // The channel tag is valid
                               is_chnl_match[i];   // Choose the ready channel
    assign tag_chnl_data[(i+1)*CHNL_DATA_W-1:i*CHNL_DATA_W] = {tag_chnl_tag[i], tag_chnl_chnl[i], tag_chnl_sz[i], tag_chnl_last[i], tag_chnl_misc[i]};
    assign tag_rrsp_ready[i] = tag_chnl_ready[i];

end
endgenerate
/* -------Generate block{end}------- */

/* -------Reordered TAG info stored in RAM{begin}------- */
integer j;
always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        for (j = 0; j < `TAG_NUM; j = j+1) begin
            rebuf_log_sram_tag[j] <= `TD 1'd0;
            rebuf_log_sram_len[j] <= `TD {`DW_LEN_WIDTH{1'd0}};
        end
    end
    else begin
        if (nxt_match_valid & nxt_match_ready & (st_rd_rsp_wen & st_rd_rsp_rdy & st_rd_rsp_last)) begin
            rebuf_log_sram_tag[nxt_match_tag] <= `TD 1'd0;
            rebuf_log_sram_len[nxt_match_tag] <= `TD {`DW_LEN_WIDTH{1'd0}};
            rebuf_log_sram_tag[st_rd_rsp_tag]     <= `TD 1'd1;
            rebuf_log_sram_len[st_rd_rsp_tag]     <= `TD rebuf_log_sram_len[st_rd_rsp_tag] + st_rd_rsp_dlen;
        end
        else if (nxt_match_valid & nxt_match_ready) begin /* clear the info before entering the forward state */
            rebuf_log_sram_tag[nxt_match_tag] <= `TD 1'd0;
            rebuf_log_sram_len[nxt_match_tag] <= `TD {`DW_LEN_WIDTH{1'd0}};
        end
        else if (st_rd_rsp_wen & st_rd_rsp_rdy & st_rd_rsp_last) begin  /* store the info only when the last cycle of the storage */
            rebuf_log_sram_tag[st_rd_rsp_tag] <= `TD 1'd1;
            rebuf_log_sram_len[st_rd_rsp_tag] <= `TD rebuf_log_sram_len[st_rd_rsp_tag] + st_rd_rsp_dlen;
        end
    end
end
/* -------Reordered TAG info stored in RAM{end}------- */

/* --------Next rsp channel{begin}-------- */
st_mux #(
    .CHNL_NUM      ( `DMA_RD_CHNL_NUM     ),    // number of slave signals to arbit
    .CHNL_NUM_LOG  ( `DMA_RD_CHNL_NUM_LOG ),
    .TUSER_WIDTH   ( 1                    ),
    .TDATA_WIDTH   ( CHNL_DATA_W          )
) st_mux_tag_chnl ( 
    .clk   ( dma_clk ), // i, 1
    .rst_n ( rst_n   ), // i, 1

    /* -------Slave AXIS Interface{begin}------- */
    .s_axis_mux_tvalid ( tag_chnl_valid ),
    .s_axis_mux_tlast  ( tag_chnl_valid ),
    .s_axis_mux_tdata  ( tag_chnl_data  ),
    .s_axis_mux_tuser  ( {`DMA_RD_CHNL_NUM{1'b0}} ), // i, CHNL_NUM
    .s_axis_mux_tready ( tag_chnl_ready ),
    /* -------Slave AXIS Interface{end}------- */

    /* ------- Master AXIS Interface{begin} ------- */
    .m_axis_mux_tvalid ( nxt_match_valid ),
    .m_axis_mux_tlast  (  ),
    .m_axis_mux_tdata  ( {nxt_match_tag, nxt_match_chnl, nxt_match_sz, nxt_match_last, nxt_match_misc} ), 
    .m_axis_mux_tuser  (  ), 
    .m_axis_mux_tready ( nxt_match_ready )
    /* ------- Master AXIS Interface{end} ------- */
    
`ifdef SIMULATION    
    /* ------- Debug interface {begin}------- */
    /* |       reserved       |          idx       | end | out |
     * |  255:CHNL_NUM_LOG+2  | CHNL_NUM_LOG+2-1:2 |  1  |  0  |
     */
    ,.debug (  )
    /* ------- Debug interface {end}------- */
`endif
);
/* --------Next rsp channel{end}-------- */

endmodule