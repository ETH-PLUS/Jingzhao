`timescale 1ns / 100ps
//*************************************************************************
// > File Name: rdma_uar.v
// > Author   : Kangning
// > Date     : 2022-08-11
// > Note     : rdma_uar, Generate configurations for RDMA uar space. 
// >            1. This space is accessed in 64-bit.
// >            2. This space is write only for driver.
//*************************************************************************

module rdma_uar #(
    
) (
    input  wire clk  , // i, 1
    input  wire rst_n, // i, 1

    /* --------Req Channel{begin}-------- */
    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    input  wire [`PIO_DATA_W-1:0]  pio_uar_req_data  , // i, `PIO_DATA_W
    input  wire [`PIO_HEAD_W-1:0]  pio_uar_req_head  , // i, `PIO_HEAD_W
    input  wire                    pio_uar_req_last  , // i, 1
    input  wire                    pio_uar_req_valid , // i, 1
    output wire                    pio_uar_req_ready , // o, 1
    /* --------Req Channel{end}-------- */

    /* --------SQ Doorbell{begin}-------- */
    output wire           pio_uar_db_valid, // o, 1
    output wire [63:0]    pio_uar_db_data , // o, 64
    input  wire           pio_uar_db_ready, // i, 1
    /* --------SQ Doorbell{end}-------- */

    /* --------ARM CQ interface{begin}-------- */
    input  wire          cq_ren , // i, 1
    input  wire [31:0]   cq_num , // i, 32
    output reg           cq_dout_reg, // o, 1
    /* --------ARM CQ interface{end}-------- */
    
    /* --------ARM EQ interface{begin}-------- */
    input  wire          eq_ren , // i, 1
    input  wire [31:0]   eq_num , // i, 31
    output reg           eq_dout_reg  // o, 1
    /* --------ARM EQ interface{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [2*`SRAM_RW_DATA_W-1:0] rw_data  // i, 2*`SRAM_RW_DATA_W
    ,input  wire [31:0] dbg_sel  // debug bus select
    ,output wire [31:0] dbg_bus  // debug bus data    
    /* -------APB reated signal{end}------- */
`endif
);

localparam CQ_NUM_LOG = 13;
localparam EQ_NUM_LOG = 5 ;

/* --------requet parse{begin}-------- */
wire [31:0] req_addr;
wire is_set_sq_db, is_arm_cq, is_arm_eq;
/* --------requet parse{end}-------- */


/* -------SQ Doorbell{begin}------- */
reg        db_wen ;
reg [63:0] db_din ;
wire       db_full;

wire        db_ren  ;
wire [63:0] db_dout ;
wire        db_empty;
/* -------SQ Doorbell{end}------- */

/* -------ARM CQ{begin}------- */
reg cq_update_reg;
reg [CQ_NUM_LOG-1:0] cq_addr_reg;

wire                  arm_cq_we  ;
wire [CQ_NUM_LOG-1:0] arm_cq_addr;
wire                  arm_cq_din ;

wire cq_dout;
/* -------ARM CQ{end}------- */

/* -------ARM EQ{begin}------- */
reg eq_update_reg;
reg [EQ_NUM_LOG-1:0] eq_addr_reg;

wire                  arm_eq_we  ;
wire [EQ_NUM_LOG-1:0] arm_eq_addr;
wire                  arm_eq_din ;

wire eq_dout;
/* -------ARM EQ{end}------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire [`RDMA_UAR_SIGNAL_W-1:0] dbg_signal_rdma_uar;
wire  [1:0]  db_rtsel, cq_rtsel;
wire  [1:0]  db_wtsel, cq_wtsel;
wire  [1:0]  db_ptsel, cq_ptsel;
wire         db_vg   , cq_vg   ;
wire         db_vs   , cq_vs   ;
/* -------APB reated signal{end}------- */
`endif

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign {db_rtsel, db_wtsel, db_ptsel, db_vg, db_vs, 
        cq_rtsel, cq_wtsel, cq_ptsel, cq_vg, cq_vs} = rw_data;
assign dbg_bus = dbg_signal_rdma_uar >> {dbg_sel, 5'd0};

assign dbg_signal_rdma_uar = { // 211
    req_addr, is_set_sq_db, is_arm_cq, is_arm_eq, // 35
    db_wen, db_din, db_full, // 66
    db_ren, db_dout, db_empty, // 66
    cq_update_reg, cq_addr_reg, // 14
    arm_cq_we, arm_cq_addr, arm_cq_din, // 15
    cq_dout, // 1
    eq_update_reg, eq_addr_reg, // 6
    arm_eq_we, arm_eq_addr, arm_eq_din, // 7
    eq_dout // 1
};
/* -------APB reated signal{end}------- */
`endif

/* --------requet parse{begin}-------- */
assign req_addr = pio_uar_req_head[127:96];

assign is_set_sq_db = (req_addr[11:0] == `DOORBELL_BASE) & pio_uar_req_valid;
assign is_arm_cq    = (req_addr[11:0] == `ARM_CQ_BASE  ) & pio_uar_req_valid;
assign is_arm_eq    = (req_addr[11:0] == `ARM_EQ_BASE  ) & pio_uar_req_valid;

assign pio_uar_req_ready = 1;
/* --------requet parse{end}-------- */


/* -------BAR2 logic{begin}------- */
// Write Doorbell to FIFO
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        db_wen <= `TD 0;
        db_din <= `TD 0;
    end
    else if (db_wen & !db_full) begin
        db_wen <= `TD 0;
        db_din <= `TD 0;
    end
    else if (is_set_sq_db) begin
        db_wen <= `TD 1;
        db_din <= `TD pio_uar_req_data[63:0];
    end
end

pcieifc_sync_fifo #(
    .DSIZE ( 64 ),
    .ASIZE ( 6  ) // 64 depth
) doobell_sync_fifo (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1
    .clr   ( 1'd0  ), // i, 1

    .wen   ( db_wen   ), // i, 1
    .din   ( db_din   ), // i, 64
    .full  ( db_full  ), // o, 1

    .ren   ( db_ren   ), // i, 1; pio_uar_db_ready
    .dout  ( db_dout  ), // o, 64
    .empty ( db_empty )  // o, 1

`ifdef PCIEI_APB_DBG
    ,.rtsel ( db_rtsel )  // i, 2
    ,.wtsel ( db_wtsel )  // i, 2
    ,.ptsel ( db_ptsel )  // i, 2
    ,.vg    ( db_vg    )  // i, 1
    ,.vs    ( db_vs    )  // i, 1
`endif
);

st_reg #(
    .TUSER_WIDTH ( 1  ), // unused
    .TDATA_WIDTH ( 64 )
) uar_db_st_reg (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( !db_empty ), // i, 1
    .axis_tlast  ( 1'b1      ), // i, 1
    .axis_tuser  ( 1'b0      ), // i, TUSER_WIDTH
    .axis_tdata  ( db_dout   ), // i, TDATA_WIDTH
    .axis_tready ( db_ren    ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output st_reg inteface{begin}------- */
    .axis_reg_tvalid ( pio_uar_db_valid ), // o, 1  
    .axis_reg_tlast  (   ), // o, 1
    .axis_reg_tuser  (   ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( pio_uar_db_data  ), // o, TDATA_WIDTH
    .axis_reg_tready ( pio_uar_db_ready )  // i, 1
    /* -------output st_reg inteface{end}------- */
);
/* -------SQ Doorbell Logic{end}------- */


/* -------ARM CQ Logic{begin}------- */
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        cq_update_reg <= `TD 0;
        cq_addr_reg   <= `TD 0;
    end
    else if (cq_update_reg & (!is_arm_cq | !cq_dout)) begin // 1. clear when armed cq is not written
                                                            // 2. clear when cq is not armed
        cq_update_reg <= `TD 0;
        cq_addr_reg   <= `TD 0;
    end
    else if (cq_ren) begin
        cq_update_reg <= `TD 1;
        cq_addr_reg   <= `TD cq_num;
    end
end

assign arm_cq_we   = is_arm_cq | cq_update_reg;
assign arm_cq_addr = is_arm_cq     ? pio_uar_req_data[CQ_NUM_LOG-1:0] : 
                     cq_update_reg ? cq_addr_reg                      : 0;
assign arm_cq_din  = is_arm_cq;

pcieifc_sd_sram #(
    .DATAWIDTH  ( 1 ), // Memory data word width
    .ADDRWIDTH  ( CQ_NUM_LOG  )  // 8192 entries
) armed_cq_table (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    .wea   ( arm_cq_we   ), // i, 1
    .addra ( arm_cq_addr ), // i, ADDRWIDTH
    .dina  ( arm_cq_din  ), // i, DATAWIDTH

    .reb   ( 1'd1        ), // i, 1
    .addrb ( cq_ren ? cq_num[CQ_NUM_LOG-1:0] : {CQ_NUM_LOG{1'd0}} ), // i, ADDRWIDTH
    .doutb ( cq_dout     )  // o, DATAWIDTH

`ifdef PCIEI_APB_DBG
    ,.rtsel ( cq_rtsel )  // i, 2
    ,.wtsel ( cq_wtsel )  // i, 2
    ,.ptsel ( cq_ptsel )  // i, 2
    ,.vg    ( cq_vg    )  // i, 1
    ,.vs    ( cq_vs    )  // i, 1
`endif
);

always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        cq_dout_reg <= `TD 0;
    end
    else begin
        cq_dout_reg <= `TD cq_dout;
    end
end
/* -------ARM CQ Logic{begin}------- */


/* -------ARM EQ Logic{begin}------- */
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        eq_update_reg <= `TD 0;
        eq_addr_reg   <= `TD 0;
    end
    else if (eq_update_reg & (!is_arm_eq | !eq_dout)) begin // 1. clear when armed eq is not written
                                                            // 2. clear when eq is not armed
        eq_update_reg <= `TD 0;
        eq_addr_reg   <= `TD 0;
    end
    else if (eq_ren) begin
        eq_update_reg <= `TD 1;
        eq_addr_reg   <= `TD eq_num;
    end
end

assign arm_eq_we   = is_arm_eq | eq_update_reg;
assign arm_eq_addr = is_arm_eq     ? pio_uar_req_data[EQ_NUM_LOG-1:0] : 
                     eq_update_reg ? eq_addr_reg                      : 0;
assign arm_eq_din  = is_arm_eq;

pcieifc_sd_sram #(
    .DATAWIDTH  ( 1 ), // Memory data word width
    .ADDRWIDTH  ( EQ_NUM_LOG  )  // 32 entries
) armed_eq_table (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    .wea   ( arm_eq_we   ), // i, 1
    .addra ( arm_eq_addr ), // i, ADDRWIDTH
    .dina  ( arm_eq_din  ), // i, DATAWIDTH

    .reb   ( 1'd1        ), // i, 1
    .addrb ( eq_ren ? eq_num[EQ_NUM_LOG-1:0] : {EQ_NUM_LOG{1'd0}} ), // i, ADDRWIDTH
    .doutb ( eq_dout     )  // o, DATAWIDTH

`ifdef PCIEI_APB_DBG
    ,.rtsel ( 2'b0 )  // i, 2
    ,.wtsel ( 2'b0 )  // i, 2
    ,.ptsel ( 2'b0 )  // i, 2
    ,.vg    ( 1'b0 )  // i, 1
    ,.vs    ( 1'b0 )  // i, 1
`endif
);

always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        eq_dout_reg <= `TD 0;
    end
    else begin
        eq_dout_reg <= `TD eq_dout;
    end
end
/* -------ARM EQ Logic{begin}------- */
endmodule
