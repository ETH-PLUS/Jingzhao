`timescale 1ns / 100ps
//*************************************************************************
// > File Name: rdma_hcr.v
// > Author   : Kangning
// > Date     : 2022-06-08
// > Note     : rdma_hcr, Generate configurations for RDMA bar space.
//*************************************************************************

module rdma_hcr #(
    
) (

    input wire clk  , // i, 1
    input wire rst_n, // i, 1

    /* --------Req Channel{begin}-------- */
    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    input  wire                   pio_hcr_req_valid, // i, 1
    input  wire                   pio_hcr_req_last , // i, 1
    input  wire [`PIO_DATA_W-1:0] pio_hcr_req_data , // i, `PIO_DATA_W
    input  wire [`PIO_HEAD_W-1:0] pio_hcr_req_head , // i, `PIO_HEAD_W
    output wire                   pio_hcr_req_ready, // o, 1
    /* --------Req Channel{end}-------- */

    /* --------Rsp Channel{begin}-------- */
    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    output wire                   pio_hcr_rrsp_valid, // o, 1
    output wire                   pio_hcr_rrsp_last , // o, 1
    output wire [`PIO_DATA_W-1:0] pio_hcr_rrsp_data , // o, `PIO_DATA_W
    output wire [`PIO_HEAD_W-1:0] pio_hcr_rrsp_head , // o, `PIO_HEAD_W
    input  wire                   pio_hcr_rrsp_ready, // i, 1
    /* -------Rsp Channel{end}-------- */

    /* -------pio <--> RDMA interface{begin}------- */
    output  wire [63:0]                 pio_hcr_in_param      ,
    output  wire [31:0]                 pio_hcr_in_modifier   ,
    output  wire [63:0]                 pio_hcr_out_dma_addr  ,
    input   wire [63:0]                 pio_hcr_out_param     ,
    output  wire [15:0]                 pio_hcr_token         ,
    input   wire [ 7:0]                 pio_hcr_status        ,
    output  wire                        pio_hcr_go            ,
    input   wire                        pio_hcr_clear         ,
    output  wire                        pio_hcr_event         ,
    output  wire [ 7:0]                 pio_hcr_op_modifier   ,
    output  wire [11:0]                 pio_hcr_op            ,
    /* -------pio <-->RDMA interface{end}------- */

    /* -------Reset signal{begin}------- */
    output wire                         cmd_rst  ,
    input  wire                         init_done 
    /* -------Reset signal{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [31:0] dbg_sel  // debug bus select
    ,output wire [31:0] dbg_bus  // debug bus data    
    /* -------APB reated signal{end}------- */
`endif
);

/* --------RDMA Bar access FSM{begin}-------- */
reg [1:0] cur_state, nxt_state;
localparam  TRANS = 2'b01,
            STALL = 2'b10;
wire is_trans, is_stall;
/* --------RDMA Bar access FSM{end}-------- */

/* --------interal logic{begin}-------- */
wire [10:0] dw_len;
wire is_wr, is_rd;
reg [`PIO_HEAD_W-1:0] head_reg;
/* --------interal logic{end}-------- */

/* --------BAR access interface{begin}-------- */
wire        req_vld  ;
wire [7 :0] req_wen  ;
wire [63:0] req_addr ;
wire [63:0] req_wdata;

wire [31:0] rrsp_data;
/* --------BAR access interface{end}-------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire [`RDMA_HCR_SIGNAL_W-1:0] dbg_signal_rdma_hcr;
wire [`RDMA_HCR_SPACE_SIGNAL_W-1:0] dbg_signal_space;
/* -------APB reated signal{end}------- */
`endif

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */

assign dbg_bus = dbg_signal_rdma_hcr >> {dbg_sel, 5'd0};

assign dbg_signal_rdma_hcr = { // 538
    cur_state, nxt_state, // 4
    is_trans, is_stall, // 2
    dw_len, // 11
    is_wr, is_rd, // 2
    head_reg, // 132
    req_vld, req_wen, req_addr, req_wdata, // 137
    rrsp_data, // 32
    dbg_signal_space // 218
};
/* -------APB reated signal{end}------- */
`endif

/* -------{RDMA Bar access FSM}begin------- */
/******************** Stage 1: State Register **********************/
assign is_trans = (cur_state == TRANS);
assign is_stall = (cur_state == STALL);

always @(posedge clk, negedge rst_n) begin
    if(~rst_n)
        cur_state <= `TD TRANS;
    else
        cur_state <= `TD nxt_state;
end

/******************** Stage 2: State Transition **********************/
always @(*) begin
    case(cur_state)
    TRANS: begin
        if (pio_hcr_req_valid & pio_hcr_req_ready & pio_hcr_req_last & is_rd) begin
            nxt_state = STALL;
        end
        else begin
            nxt_state = TRANS;
        end
    end
    STALL: begin
        if (pio_hcr_rrsp_valid & pio_hcr_rrsp_ready & pio_hcr_rrsp_last) begin
            nxt_state = TRANS;
        end
        else begin
            nxt_state = STALL;
        end
    end
    default: begin
        nxt_state = TRANS;
    end
    endcase
end

/******************** Stage 3: Output **********************/

// Interal logic
assign dw_len    = pio_hcr_req_head[42:32];
assign is_wr = pio_hcr_req_head[131];
assign is_rd = !is_wr;
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        head_reg <= `TD 0;
    end
    else if (pio_hcr_req_valid & pio_hcr_req_ready & pio_hcr_req_last & is_rd) begin
        head_reg <= `TD pio_hcr_req_head;
    end
end

// Rsp channel
assign pio_hcr_rrsp_head = head_reg;
assign pio_hcr_rrsp_data = {192'd0, 32'd0, rrsp_data};
assign pio_hcr_rrsp_last = pio_hcr_rrsp_valid;

// Req channel
assign pio_hcr_req_ready = is_trans;

// BAR access interface
assign req_vld   = is_trans & pio_hcr_req_valid;
assign req_wen   = ((dw_len == 1) & is_trans & is_wr) ? 8'h0f : 
                   ((dw_len == 2) & is_trans & is_wr) ? 8'hff : 0;
assign req_addr  = pio_hcr_req_valid ? pio_hcr_req_head[127:96]  : 0;
assign req_wdata = is_wr ? pio_hcr_req_data[63:0] : 0;
/* -------{RDMA bar access FSM}end------- */

rdma_hcr_space #(
    
) rdma_hcr_space (

    .clk              ( clk   ),
    .rst_n            ( rst_n ),

    /* -------pio <--> RDMA interface{begin}------- */
    .pio_hcr_in_param     ( pio_hcr_in_param     ), // o, 64
    .pio_hcr_in_modifier  ( pio_hcr_in_modifier  ), // o, 32
    .pio_hcr_out_dma_addr ( pio_hcr_out_dma_addr ), // o, 64
    .pio_hcr_out_param    ( pio_hcr_out_param    ), // i, 64
    .pio_hcr_token        ( pio_hcr_token        ), // o, 16
    .pio_hcr_status       ( pio_hcr_status       ), // i, 8
    .pio_hcr_go           ( pio_hcr_go           ), // o, 1
    .pio_hcr_clear        ( pio_hcr_clear        ), // i, 1
    .pio_hcr_event        ( pio_hcr_event        ), // o, 1
    .pio_hcr_op_modifier  ( pio_hcr_op_modifier  ), // o, 8
    .pio_hcr_op           ( pio_hcr_op           ), // o, 12
    /* -------pio <--> RDMA interface{end}------- */

    /* -------Reset signal{begin}------- */
    .is_rst               ( cmd_rst   ), // o, 1
    .init_done            ( init_done ), // i, 1
    /* -------Reset signal{end}------- */

    /* -------Access BAR space Interface{begin}------- */
    .req_vld       ( req_vld ), // i, 1
    .req_wen       ( req_wen   ), // i, 8
    .req_addr      ( req_addr  ), // i, 64
    .req_wdata     ( req_wdata ), // i, 64

    .rsp_valid     ( pio_hcr_rrsp_valid ), // o, 1
    .rsp_rdata     ( rrsp_data          ), // o, 32
    .rsp_ready     ( pio_hcr_rrsp_ready )  // i, 1
    /* -------Access BAR space Interface{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.dbg_signal ( dbg_signal_space ) // o, `RDMA_HCR_SPACE_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);

endmodule