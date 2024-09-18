`timescale 1ns / 100ps
//*************************************************************************
// > File Name: rsp_converter.v
// > Author   : Kangning
// > Date     : 2020-08-25
// > Note     : rsp_converter, used to convert Xilinx PCIe compatible 
// >               interface into AXI-Stream
//*************************************************************************

//`include "../lib/global_include_h.v"
//`include "../lib/dma_def_h.v"

module rsp_converter #(
    
) (
    input  wire                        dma_clk  ,
    input  wire                        rst_n    ,

    /* ------- pcie --> dma interface{begin}------- */
    // Requester Completion
    /*  RC tuser
     * |  74:43 |      42     |    41:38   |  37:34   |    33    |    32    |  31:0   |  
     * | parity | discontinue |  is_eof_1  | is_eof_0 | is_sof_1 | is_sof_0 | byte_en |
     * | ignore |   ignore    |  ignore    | ignore   |  ignore  |  ignore  |         |
     */
    input  wire                   m_axis_rc_tvalid, // i, 1
    input  wire                   m_axis_rc_tlast , // i, 1
    input  wire [`DMA_DATA_W-1:0] m_axis_rc_tdata , // i, `DMA_DATA_W
    input  wire [74           :0] m_axis_rc_tuser , // i, 75
    input  wire [`DMA_KEEP_W-1:0] m_axis_rc_tkeep , // i, `DMA_KEEP_W
    output wire                   m_axis_rc_tready, // o, 1
    /* ------- pcie --> dma interface{end}------- */


    /* ------- Interface with dma read module{begin}------- */
    /* AXI-Stream read response tuser, interact with read response distributor.
     * Only valid in first beat of a packet
     * | Reserved | REQ CPL |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 119:105  |   104   | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     */
    output wire                     axis_rd_rsp_tvalid, // o, 1
    output wire                     axis_rd_rsp_tlast , // o, 1
    output wire [`DMA_DATA_W  -1:0] axis_rd_rsp_tdata , // o, `DMA_DATA_W
    output wire [`AXIS_TUSER_W-1:0] axis_rd_rsp_tuser , // o, `AXIS_TUSER_W
    output wire [`DMA_KEEP_W  -1:0] axis_rd_rsp_tkeep , // o, `DMA_KEEP_W
    input  wire                     axis_rd_rsp_tready  // i, 1
    /* ------- Interface with dma read module{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [31:0] dbg_sel  // i, 32
    ,output wire [31:0] dbg_bus  // o, 32    
    /* -------APB reated signal{end}------- */
`endif
);

// Generate last signal of m_axis_rc_tlast, cause it doesn't work in FPGA V7 series
/* -------last generate {begin}------- */
// reg [`DW_LEN_WIDTH-1:0] dw_left;
/* -------last generate {end}------- */

/* -------axis_dw_left{begin}------- */
wire                     axis_next_last; // indicate that next cycle is axis_rd_rsp_last
wire [`DMA_KEEP_W  -1:0] axis_keep     ;
reg  [`DW_LEN_WIDTH-1:0] axis_dw_left  ;
/* -------axis_dw_last{end}------- */

/* -------tuser generation{begin}------- */
wire [1 :0] last_dw;

wire                             is_req_cpl;
wire [`TAG_WIDTH+`TAG_EMPTY-1:0] tag     ;
wire [`DMA_ADDR_WIDTH      -1:0] addr    ;
wire [`DW_LEN_WIDTH        -1:0] dw_len  ;
wire [`FIRST_BE_WIDTH      -1:0] first_be;
wire [`LAST_BE_WIDTH       -1:0] last_be ;

wire [`DW_LEN_WIDTH          :0] total_dw;

reg                     is_aligned_last;
reg [`AXIS_TUSER_W-1:0] axis_tuser; // tuser signal output in RX_IDLE state
/* -------tuser generation{end}------- */

/* -------data generation{begin}------- */

reg [159:0] tmp_reg_data;

wire [`DMA_DATA_W-1:0] axis_tdata_rsp ;
wire [`DMA_DATA_W-1:0] axis_tdata_last;
/* -------data generation{end}------- */

/* -------State relevant in FSM{begin}------- */
localparam RX_IDLE = 3'b001, // This State is used to generate tuser for other stage use, 
                             // this state do not output, but input one beat. When input vld & rdy
                             // asserted at the same time (one beat data in), jump to RX_RSP;
                             // and if this beat is last beat, jump to RX_LAST state.
           RX_RSP  = 3'b010, // This state is used to output & input data, when it is last beat and 
                             // there's data in temp register, jump to RX_LAST state.
           RX_LAST = 3'b100; // Output data in temp, and jump to RX_IDLE state. Note that this state
                             // don't assert ready.

reg [2:0] cur_state;
reg [2:0] nxt_state;

wire is_rx_idle, is_rx_rsp, is_rx_last;
/* -------State relevant in FSM{end}------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire [`RSP_CONVERT_TOP_SIGNAL_W-1:0] dbg_signal;
/* -------APB reated signal{end}------- */
`endif

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign dbg_bus = dbg_signal >> {dbg_sel, 5'd0};

assign dbg_signal = { // 936
    axis_next_last, axis_keep, axis_dw_left, // 20
    last_dw, // 2
    is_req_cpl, tag, addr, dw_len, first_be, last_be, // 92
    total_dw, // 12
    is_aligned_last, // 1
    axis_tuser, // 128
    tmp_reg_data, // 160
    axis_tdata_rsp, axis_tdata_last, // 512
    cur_state, nxt_state, // 6
    is_rx_idle, is_rx_rsp, is_rx_last // 3
};
/* -------APB reated signal{end}------- */
`endif

/* -------axis_dw_left{begin}------- */
assign axis_next_last = ( is_rx_rsp  &                                        ((8 < axis_dw_left) & (axis_dw_left <= 16))) |
                        ( is_rx_idle &                                        (dw_len <= 8))                               |
                        ((is_rx_last & m_axis_rc_tvalid & m_axis_rc_tready) & (dw_len <= 8));
always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        axis_dw_left <= `TD 0;
    end
    else if ((is_rx_idle & m_axis_rc_tvalid & m_axis_rc_tready) | 
             (is_rx_last & m_axis_rc_tvalid & m_axis_rc_tready & !is_aligned_last)) begin
        axis_dw_left <= `TD dw_len;
    end
    else if (axis_rd_rsp_tvalid & axis_rd_rsp_tready) begin
        axis_dw_left <= `TD axis_dw_left - 8;
    end
end
assign axis_keep = ({`DMA_KEEP_W{axis_dw_left >= 8}} & 8'hFF) |
                   ({`DMA_KEEP_W{axis_dw_left == 7}} & 8'h7F) |
                   ({`DMA_KEEP_W{axis_dw_left == 6}} & 8'h3F) |
                   ({`DMA_KEEP_W{axis_dw_left == 5}} & 8'h1F) |
                   ({`DMA_KEEP_W{axis_dw_left == 4}} & 8'h0F) |
                   ({`DMA_KEEP_W{axis_dw_left == 3}} & 8'h07) |
                   ({`DMA_KEEP_W{axis_dw_left == 2}} & 8'h03) |
                   ({`DMA_KEEP_W{axis_dw_left == 1}} & 8'h01);
/* -------axis_dw_left{end}------- */

/* -------tuser generation{begin}------- */
assign last_dw = m_axis_rc_tdata[17:16] + m_axis_rc_tdata[1:0];

assign is_req_cpl = m_axis_rc_tdata[30];
assign tag      = m_axis_rc_tdata[71:64];
assign addr     = {52'd0, m_axis_rc_tdata[11:2], 2'd0};
assign dw_len   = m_axis_rc_tdata[42:32];
assign first_be = ({4{m_axis_rc_tdata[1:0] == 2'b00}} & 4'b1111) |
                  ({4{m_axis_rc_tdata[1:0] == 2'b01}} & 4'b1110) |
                  ({4{m_axis_rc_tdata[1:0] == 2'b10}} & 4'b1100) |
                  ({4{m_axis_rc_tdata[1:0] == 2'b11}} & 4'b1000);
assign last_be  = m_axis_rc_tdata[30] ? 
                 (({4{last_dw == 2'b00}} & 4'b1111) |
                  ({4{last_dw == 2'b01}} & 4'b0001) |
                  ({4{last_dw == 2'b10}} & 4'b0011) |
                  ({4{last_dw == 2'b11}} & 4'b0111)) : 4'b1111;

assign total_dw = dw_len + 3;
always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        axis_tuser  <= `TD {`AXIS_TUSER_W{1'd0}};
        is_aligned_last <= `TD 0;
    end
    else if ((is_rx_idle & m_axis_rc_tvalid & m_axis_rc_tready) ||      // jump from idle to RX_RSP || RX_LAST
             (is_rx_last & m_axis_rc_tvalid & m_axis_rc_tready & !is_aligned_last)) begin  // jump from RX_LAST to RX_RSP || RX_LAST
        axis_tuser <= `TD {23'd0, is_req_cpl, tag, addr, 13'd0, dw_len, 
                           (dw_len == 1) ? (first_be & last_be) : first_be, 
                           (dw_len == 1) ? 4'b0000 : last_be};
        is_aligned_last <= `TD ((0 == dw_len[2:0]) || (dw_len[2:0] >= 6));
    end
    else if (is_rx_last & m_axis_rc_tvalid & m_axis_rc_tready & is_aligned_last) begin
        axis_tuser  <= `TD {`AXIS_TUSER_W{1'd0}};
        is_aligned_last <= `TD 0;
    end
end
/* -------tuser generation{end}------- */

/* -------data & keep generation{begin}------- */
always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        tmp_reg_data <= `TD 160'd0;
    end
    else if ((is_rx_last & axis_rd_rsp_tready & is_aligned_last) & (m_axis_rc_tvalid & m_axis_rc_tready)) begin
        tmp_reg_data <= `TD 160'd0;
    end
    else if ((is_rx_last & axis_rd_rsp_tready & !is_aligned_last) & (m_axis_rc_tvalid & m_axis_rc_tready)) begin
        tmp_reg_data <= `TD m_axis_rc_tdata[255:96];
    end
    else if (is_rx_last & axis_rd_rsp_tready & !is_aligned_last) begin
        tmp_reg_data <= `TD 160'd0;
    end
    else if (m_axis_rc_tvalid & m_axis_rc_tready) begin
        tmp_reg_data <= `TD m_axis_rc_tdata[255:96];
    end
end


assign axis_tdata_rsp  = {m_axis_rc_tdata[95:0], tmp_reg_data};
assign axis_tdata_last = {96'd0, tmp_reg_data};
/* -------data & keep generation{end}------- */


/* -------{RSP converter FSM}begin------- */
/******************** Stage 1: State Register **********************/

assign is_rx_idle = (cur_state == RX_IDLE);
assign is_rx_rsp  = (cur_state == RX_RSP );
assign is_rx_last = (cur_state == RX_LAST);

always @(posedge dma_clk, negedge rst_n) begin
    if(~rst_n)
        cur_state <= `TD RX_IDLE;
    else
        cur_state <= `TD nxt_state;
end

/******************** Stage 2: State Transition **********************/

always @(*) begin
    case(cur_state)
    RX_IDLE: begin
        if (m_axis_rc_tvalid & m_axis_rc_tready & axis_next_last) begin
            nxt_state = RX_LAST;
        end
        else if (m_axis_rc_tvalid & m_axis_rc_tready & !axis_next_last) begin
            nxt_state = RX_RSP;
        end
        else begin
            nxt_state = RX_IDLE;
        end
    end
    RX_RSP: begin
        if (m_axis_rc_tvalid & m_axis_rc_tready & axis_next_last) begin
            nxt_state = RX_LAST;
        end
        else begin
            nxt_state = RX_RSP;
        end
    end
    RX_LAST: begin
        if (axis_rd_rsp_tvalid & axis_rd_rsp_tready) begin
            if (m_axis_rc_tvalid & m_axis_rc_tready & is_aligned_last) begin // prevsious pkt hasn't finished yet.
                nxt_state = RX_IDLE;
            end
            else if (m_axis_rc_tvalid & m_axis_rc_tready & axis_next_last) begin
                nxt_state = RX_LAST;
            end
            else if (m_axis_rc_tvalid & m_axis_rc_tready & !axis_next_last) begin
                nxt_state = RX_RSP;
            end
            else begin
                nxt_state = RX_IDLE;
            end
        end
        else begin
            nxt_state = RX_LAST;
        end
    end
    default: begin
        nxt_state = RX_IDLE;
    end
    endcase
end


/******************** Stage 3: Output **********************/

assign m_axis_rc_tready = is_rx_idle | ((is_rx_rsp | is_rx_last) & axis_rd_rsp_tready);

assign axis_rd_rsp_tvalid = (is_rx_rsp & m_axis_rc_tvalid) | (is_rx_last & is_aligned_last & m_axis_rc_tvalid) | (is_rx_last & !is_aligned_last);
assign axis_rd_rsp_tlast  = axis_rd_rsp_tvalid & is_rx_last;
assign axis_rd_rsp_tuser  = axis_rd_rsp_tvalid ? axis_tuser : 0;
assign axis_rd_rsp_tdata  = ({`DMA_DATA_W{is_rx_rsp                    }} & axis_tdata_rsp ) |
                            ({`DMA_DATA_W{is_rx_last &  is_aligned_last}} & axis_tdata_rsp ) |
                            ({`DMA_DATA_W{is_rx_last & !is_aligned_last}} & axis_tdata_last);
assign axis_rd_rsp_tkeep  = axis_keep;

/* -------{RSP converter FSM}end------- */

endmodule
