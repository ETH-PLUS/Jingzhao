`timescale 1ns / 100ps
//*************************************************************************
// > File Name: sub_rsp_concat.v
// > Author   : Kangning
// > Date     : 2020-11-15
// > Note     : sub_rsp_concat, store and concat multi-pkts into one message. 
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

module sub_rsp_concat #(
    
) (
    input  wire dma_clk, // i, 1
    input  wire rst_n  , // i, 1
    output  reg init_done, // o, 1

    /* ------- sub-rsp input{begin} ------- */
    input  wire                      st_rd_rsp_valid, // i, 1
    input  wire                      st_rd_rsp_last , // i, 1; indicate the last cycle of the whole req rsp
    input  wire                      st_rd_rsp_eop  , // i, 1; indicate the last cycle of the whole req rsp
    input  wire [`TAG_NUM_LOG  -1:0] st_rd_rsp_tag  , // i, `TAG_NUM_LOG
    input  wire [`DMA_LEN_WIDTH-1:0] st_rd_rsp_blen , // i, `DMA_LEN_WIDTH; blen for every cycle
    input  wire [`DMA_DATA_W   -1:0] st_rd_rsp_data , // i, `DMA_DATA_W
    output wire                      st_rd_rsp_ready, // o, 1
    /* ------- sub-rsp input{end} ------- */

    /* ------- rsp output{begin} ------- */
    output wire                    store_fifo_wen , // o, 1
    output wire [`TAG_NUM_LOG-1:0] store_fifo_tag , // o, `TAG_NUM_LOG
    output wire                    store_fifo_last, // o, 1
    output wire [`DMA_DATA_W -1:0] store_fifo_data, // o, `DMA_DATA_W
    input  wire                    store_fifo_rdy   // i, 1
    /* ------- rsp output{end} ------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [`SRAM_RW_DATA_W-1:0] rw_data// i, `SRAM_RW_DATA_W
    ,output wire [`SUB_RSP_CONCAT_SIGNAL_W-1:0] dbg_signal  // o, `SUB_RSP_CONCAT_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

/* --------Init related signal{begin}-------- */
reg  [`TAG_NUM_LOG              -1:0] init_waddr ;
/* --------Init related signal{end}-------- */

/* -------in_reg{begin}------- */
wire                                    st_valid;
wire                                    st_last ;
wire [`TAG_NUM_LOG                -1:0] st_tag  ;
wire [1+`DMA_LEN_WIDTH+`DMA_DATA_W-1:0] st_pyld ;
wire                                    st_ready;

wire                      in_reg_valid;
wire                      in_reg_last ;
wire                      in_reg_eop  ;
wire [`TAG_NUM_LOG  -1:0] in_reg_tag  ;
wire [`DMA_LEN_WIDTH-1:0] in_reg_blen ;
wire [`DMA_DATA_W   -1:0] in_reg_data ;
wire                      in_reg_ready;

reg in_reg_first; // First packet of in_reg
/* -------in_reg{end}------- */

/* -------Temp data get FSM{begin}------- */
localparam IDLE      = 3'b001, // Wait for the comming of the data; At this state, we read
                               // the temp data in sram and get it in the next cycle.
           FORWARD   = 3'b010, // Forward to store the data.
           TMP_CYCLE = 3'b100; // This is the last cycle (eop) with only tmp data outputs

reg [2:0] cur_state;
reg [2:0] nxt_state;

wire is_idle, is_forward, is_tmp_cycle;
wire j_forward, j_tmp_cycle;

wire is_forward_last  ; // last cycle in forward state
wire is_tmp_cycle_last; // last cycle in tmp_cycle state

wire is_trans_last; // last cycle to trans this pkt (not eop)
wire is_trans_eop ; // last cycle to trans this pkt (eop)


wire [`DMA_LEN_WIDTH-1:0] tmp_blen;
wire [`DMA_DATA_W   -1:0] tmp_data;

wire [`DMA_LEN_WIDTH-1:0] tmp_sram_blen;
wire [`DMA_DATA_W   -1:0] tmp_sram_data;
/* -------Temp data get FSM{end}------- */

/* --------Temp data SRAM{begin}-------- */
wire                                  temp_wen   ;
wire [`TAG_NUM_LOG              -1:0] temp_waddr ;
wire [`DMA_LEN_WIDTH+`DMA_DATA_W-1:0] temp_din   ;
wire                                  temp_ren   ;
wire [`TAG_NUM_LOG              -1:0] temp_raddr ;
wire [`DMA_LEN_WIDTH+`DMA_DATA_W-1:0] temp_dout  ;

// Fast forward related
wire is_fast_forward;

wire                      tmp_ff_valid;
wire [`DMA_LEN_WIDTH-1:0] tmp_ff_blen ;
wire [`DMA_DATA_W   -1:0] tmp_ff_data ;
wire                      tmp_ff_ready;
/* --------Temp data SRAM{end}-------- */

/* --------Tep reg related{begin}-------- */
wire                      con_tmp_valid;
wire                      con_tmp_last ;
wire [`TAG_NUM_LOG  -1:0] con_tmp_tag  ;
wire [`DMA_LEN_WIDTH-1:0] con_tmp_blen ;
wire [`DMA_DATA_W   -1:0] con_tmp_data ;
wire                      con_tmp_eop  ;
wire                      con_tmp_ready;

wire                      tmp_reg_valid; // We assume tmp_reg is always valid when we use it
wire                      tmp_reg_last ;
wire [`TAG_NUM_LOG  -1:0] tmp_reg_tag  ;
wire [`DMA_LEN_WIDTH-1:0] tmp_reg_blen ;
wire [`DMA_DATA_W   -1:0] tmp_reg_data ;
wire                      tmp_reg_eop  ;
wire                      tmp_reg_ready;
/* --------Tep reg related{end}-------- */

/* ---------Concat temp & in_reg{begin}-------- */
wire                      concat_valid;
wire                      concat_eop  ;
wire [`TAG_NUM_LOG  -1:0] concat_tag  ;
wire [`DMA_LEN_WIDTH  :0] concat_blen ;
wire [2*`DMA_DATA_W -1:0] concat_data ;
/* ---------Concat temp & in_reg{end}-------- */

/* -------out_reg{begin}------- */

wire                      con_out_valid;
wire                      con_out_last ;
wire [`TAG_NUM_LOG  -1:0] con_out_tag  ;
wire [`DMA_LEN_WIDTH-1:0] con_out_blen ;
wire [`DMA_DATA_W   -1:0] con_out_data ;
wire                      con_out_ready;
/* -------out_reg{end}------- */


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
assign dbg_signal = { // 3311
    init_waddr, // 6
    st_valid, st_last , st_tag  , st_pyld , st_ready, // 279
    in_reg_valid, in_reg_last , in_reg_eop  , in_reg_tag  , in_reg_blen , in_reg_data , in_reg_ready, // 279
    in_reg_first, // 1
    cur_state, nxt_state, // 6
    is_idle, is_forward, is_tmp_cycle, j_forward, j_tmp_cycle, // 5
    is_forward_last  , is_tmp_cycle_last, is_trans_last, is_trans_eop , // 4
    tmp_blen, tmp_data, tmp_sram_blen, tmp_sram_data, // 538
    temp_wen   , temp_waddr , temp_din   , temp_ren   , temp_raddr , temp_dout  , // 552
    is_fast_forward, // 1
    tmp_ff_valid, tmp_ff_blen , tmp_ff_data , tmp_ff_ready, // 271
    con_tmp_valid, con_tmp_last , con_tmp_tag  , con_tmp_blen , con_tmp_data , con_tmp_eop  , con_tmp_ready, // 279
    tmp_reg_valid, tmp_reg_last , tmp_reg_tag  , tmp_reg_blen , tmp_reg_data , tmp_reg_eop  , tmp_reg_ready, // 279
    concat_valid, concat_eop  , concat_tag  , concat_blen , concat_data , // 533
    con_out_valid, con_out_last , con_out_tag  , con_out_blen , con_out_data , con_out_ready // 278
};
/* -------APB reated signal{end}------- */
`endif

/* --------Init related signal{begin}-------- */
always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        init_done <= `TD 1'd0;
    end
    else if (init_waddr == `TAG_NUM - 1) begin
        init_done <= `TD 1'd1;
    end
end

always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        init_waddr <= `TD {`TAG_NUM_LOG{1'd0}};
    end
    else if (init_waddr != `TAG_NUM - 1) begin
        init_waddr <= init_waddr + 1;
    end
end
/* --------Init related signal{end}-------- */

/* -------in_reg{begin}------- */
assign st_rd_rsp_ready = st_ready & (!j_tmp_cycle);

assign st_valid = st_rd_rsp_valid & (!j_tmp_cycle);
assign st_last  = st_rd_rsp_last;
assign st_tag   = st_rd_rsp_tag ;
assign st_pyld  = {st_rd_rsp_eop, st_rd_rsp_blen, st_rd_rsp_data};

st_reg #(
    .TUSER_WIDTH ( `TAG_NUM_LOG ),
    .TDATA_WIDTH ( 1 + `DMA_LEN_WIDTH + `DMA_DATA_W ),
    .MODE        ( 1 ) // Allow only one cycle storage
) in_st_reg (
    .clk   ( dma_clk ), // i, 1
    .rst_n ( rst_n   ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( st_valid ), // i, 1
    .axis_tlast  ( st_last  ), // i, 1
    .axis_tuser  ( st_tag   ), // i, TUSER_WIDTH
    .axis_tdata  ( st_pyld  ), // i, TDATA_WIDTH
    .axis_tready ( st_ready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .axis_reg_tvalid ( in_reg_valid ), // o, 1
    .axis_reg_tlast  ( in_reg_last  ), // o, 1
    .axis_reg_tuser  ( in_reg_tag   ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( {in_reg_eop, in_reg_blen, in_reg_data} ), // o, TDATA_WIDTH
    .axis_reg_tready ( in_reg_ready )  // i, 1
    /* -------output in_reg inteface{end}------- */
);

assign in_reg_ready = con_out_ready; // in tmp_cycle state, it is still controlled by con_out_ready, 
                                     // cause we need to drain the input stream reg

always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        in_reg_first <= `TD 1'd0;
    end
    else if (j_forward) begin
        in_reg_first <= `TD 1'd1;
    end
    else begin
        in_reg_first <= `TD 1'd0;
    end
end
/* -------in_reg{end}------- */

/* -------{Temp data get FSM}begin------- */
/******************** Stage 1: State Register **********************/
assign is_idle      = (cur_state == IDLE     );
assign is_forward   = (cur_state == FORWARD  );
assign is_tmp_cycle = (cur_state == TMP_CYCLE);

// Last cycle (not eop) to forward
assign is_forward_last   = is_forward   & in_reg_valid & in_reg_ready & in_reg_last;
assign is_tmp_cycle_last = is_tmp_cycle & con_out_valid & con_out_ready & con_out_last;

assign is_trans_last = !j_tmp_cycle & is_forward_last & !in_reg_eop;
assign is_trans_eop  = (!j_tmp_cycle & is_forward_last & in_reg_eop) | is_tmp_cycle_last;

assign j_forward  = (is_idle           & st_valid & st_ready) ||
                    (is_forward_last   & st_valid & st_ready) ||
                    (is_tmp_cycle_last & st_valid & st_ready);
                
assign j_tmp_cycle = in_reg_eop & (concat_blen > `DMA_W_BCNT);

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
            if (st_valid & st_ready) begin
                nxt_state = FORWARD;
            end
            else begin
                nxt_state = IDLE;
            end
        end
        FORWARD: begin
            if (in_reg_valid & in_reg_ready & in_reg_last) begin
                if (in_reg_eop & (concat_blen > `DMA_W_BCNT)) begin
                    nxt_state = TMP_CYCLE;
                end
                else if (st_valid & st_ready) begin
                    nxt_state = FORWARD;
                end
                else begin
                    nxt_state = IDLE;
                end
            end
            else begin
                nxt_state = FORWARD;
            end
        end
        TMP_CYCLE: begin
            if (con_out_valid & con_out_ready & con_out_last) begin
                if (st_valid & st_ready) begin
                    nxt_state = FORWARD;
                end
                else begin
                    nxt_state = IDLE;
                end
            end
            else begin
                nxt_state = TMP_CYCLE;
            end
        end
        default: begin
            nxt_state = IDLE;
        end
    endcase
end
/******************** Stage 3: Output **********************/

assign tmp_data = in_reg_first ? tmp_sram_data : tmp_reg_data;
assign tmp_blen = in_reg_first ? tmp_sram_blen : tmp_reg_blen;
/* -------{Temp data get FSM}end------- */

/* --------temp data storge{begin}-------- */
assign temp_wen   = !is_fast_forward & (
                        is_trans_last | // When it is not the eop pkt, write back the remained tmp data
                        is_trans_eop    // When it is the eop pkt, clear the tmp sram entry
                    );
assign temp_waddr = concat_tag;
assign temp_din   = is_trans_last ? 
                    ((concat_blen >= `DMA_W_BCNT) ? {con_tmp_blen, con_tmp_data} : {con_out_blen, con_out_data}) : 
                    {`DMA_LEN_WIDTH + `DMA_DATA_W{1'd0}}; // trans_eop is included in this branch

assign temp_ren   = !is_fast_forward & j_forward;
assign temp_raddr = st_rd_rsp_tag;

pcieifc_sd_sram #(
    .DATAWIDTH  ( `DMA_LEN_WIDTH + `DMA_DATA_W ), // 269
    .ADDRWIDTH  ( `TAG_NUM_LOG )  // 64 depth
) temp_data_sram (
    .clk   ( dma_clk ), // i, 1
    .rst_n ( rst_n   ), // i, 1

    .wea   ( init_done ? temp_wen   : 1'd1                               ), // i, 1
    .addra ( init_done ? temp_waddr : init_waddr                         ), // i, ADDRWIDTH
    .dina  ( init_done ? temp_din   : {`DMA_LEN_WIDTH+`DMA_DATA_W{1'd0}} ), // i, DATAWIDTH

    .reb   ( temp_ren   ), // i, 1
    .addrb ( temp_raddr ), // i, ADDRWIDTH
    .doutb ( temp_dout  )  // o, DATAWIDTH

`ifdef PCIEI_APB_DBG
    ,.rtsel ( rtsel )
    ,.wtsel ( wtsel )
    ,.ptsel ( ptsel )
    ,.vg    ( vg    )
    ,.vs    ( vs    )
`endif
);


assign is_fast_forward = (is_trans_last | is_trans_eop) & // Need write temp data
                         j_forward &                      // Need read temp data
                         (temp_waddr == temp_raddr);      // wr & rd the same addr 
st_reg #(
    .TUSER_WIDTH ( 1 ),
    .TDATA_WIDTH ( `DMA_LEN_WIDTH + `DMA_DATA_W ),
    .MODE        ( 1 )
) tmp_ff_st_reg (
    .clk   ( dma_clk ), // i, 1
    .rst_n ( rst_n   ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( is_fast_forward ), // i, 1
    .axis_tlast  ( 1'd0  ), // i, 1
    .axis_tuser  ( 1'd0  ), // i, TUSER_WIDTH
    .axis_tdata  ( temp_din ), // i, TDATA_WIDTH
    .axis_tready (  ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .axis_reg_tvalid ( tmp_ff_valid ), // o, 1
    .axis_reg_tlast  (    ), // o, 1
    .axis_reg_tuser  (    ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( {tmp_ff_blen, tmp_ff_data} ), // o, TDATA_WIDTH
    .axis_reg_tready ( tmp_ff_ready )  // i, 1
    /* -------output in_reg inteface{end}------- */
);
assign tmp_ff_ready = con_out_ready & in_reg_valid;

assign tmp_sram_blen = tmp_ff_valid ? tmp_ff_blen : temp_dout[`DMA_LEN_WIDTH+`DMA_DATA_W-1:`DMA_DATA_W];
assign tmp_sram_data = tmp_ff_valid ? tmp_ff_data : temp_dout[`DMA_DATA_W-1:0];
/* --------temp data storge{end}-------- */

/* ---------Concat temp & in_reg{begin}-------- */
assign concat_valid = is_tmp_cycle | in_reg_valid;
assign concat_eop   = is_tmp_cycle ? tmp_reg_eop : 
                      is_forward   ? (in_reg_valid & in_reg_eop & !j_tmp_cycle) : 0;
assign concat_tag   = is_tmp_cycle ? tmp_reg_tag : 
                      is_forward   ? ({`TAG_NUM_LOG{in_reg_valid}} & in_reg_tag)  : 0;
assign concat_blen  = in_reg_blen + tmp_blen;
assign concat_data  = (in_reg_data << (tmp_blen << 3)) | tmp_data;
/* ---------Concat temp & in_reg{end}-------- */

/* -------tmp_reg{begin}------- */
assign con_tmp_valid = in_reg_valid & in_reg_ready;
assign con_tmp_last  = in_reg_last;
assign con_tmp_tag   = in_reg_tag ;
assign con_tmp_data  = concat_data[2*`DMA_DATA_W-1:`DMA_DATA_W];
assign con_tmp_blen  = (concat_blen >= `DMA_W_BCNT) ? (concat_blen - `DMA_W_BCNT) : 0;
assign con_tmp_eop   = in_reg_eop;

st_reg #(
    .TUSER_WIDTH ( `TAG_NUM_LOG ),
    .TDATA_WIDTH ( 1 + `DMA_LEN_WIDTH + `DMA_DATA_W ),
    .MODE        ( 1 )
) tmp_st_reg (
    .clk   ( dma_clk ), // i, 1
    .rst_n ( rst_n   ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( con_tmp_valid ), // i, 1
    .axis_tlast  ( con_tmp_last  ), // i, 1
    .axis_tuser  ( con_tmp_tag   ), // i, TUSER_WIDTH
    .axis_tdata  ( {con_tmp_eop, con_tmp_blen, con_tmp_data} ), // i, TDATA_WIDTH
    .axis_tready ( con_tmp_ready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .axis_reg_tvalid ( tmp_reg_valid ), // o, 1
    .axis_reg_tlast  ( tmp_reg_last  ), // o, 1
    .axis_reg_tuser  ( tmp_reg_tag   ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( {tmp_reg_eop, tmp_reg_blen, tmp_reg_data} ), // o, TDATA_WIDTH
    .axis_reg_tready ( tmp_reg_ready )  // i, 1
    /* -------output in_reg inteface{end}------- */
);
assign tmp_reg_ready = con_out_ready & concat_valid;
/* -------tmp_reg{end}------- */

/* -------out_reg{begin}------- */
assign con_out_valid = concat_valid & 
                       ((concat_blen >= `DMA_W_BCNT) | concat_eop); // don't write out if beat size is less than 32 & not eop cycle
assign con_out_last  = concat_eop;
assign con_out_tag   = concat_tag;
assign con_out_data  = concat_data[`DMA_DATA_W-1:0];
assign con_out_blen  = concat_blen;

st_reg #(
    .TUSER_WIDTH ( `TAG_NUM_LOG ),
    .TDATA_WIDTH ( `DMA_DATA_W  )
) out_st_reg (
    .clk   ( dma_clk ), // i, 1
    .rst_n ( rst_n   ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( con_out_valid ), // i, 1
    .axis_tlast  ( con_out_last  ), // i, 1
    .axis_tuser  ( con_out_tag   ), // i, TUSER_WIDTH
    .axis_tdata  ( con_out_data  ), // i, TDATA_WIDTH
    .axis_tready ( con_out_ready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .axis_reg_tvalid ( store_fifo_wen  ), // o, 1
    .axis_reg_tlast  ( store_fifo_last ), // o, 1
    .axis_reg_tuser  ( store_fifo_tag  ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( store_fifo_data ), // o, TDATA_WIDTH
    .axis_reg_tready ( store_fifo_rdy  )  // i, 1
    /* -------output in_reg inteface{end}------- */
);
/* -------out_reg{end}------- */

endmodule