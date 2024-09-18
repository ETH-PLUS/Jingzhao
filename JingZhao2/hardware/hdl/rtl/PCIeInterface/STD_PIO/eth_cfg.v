`timescale 1ns / 100ps
//*************************************************************************
// > File   : eth_cfg.v
// > Author : Kangning
// > Date   : 2022-06-10
// > Note   : eth_cfg, Provide interface for Ethernet bar space access.
//*************************************************************************


module eth_cfg #(
    parameter AXIL_DATA_WIDTH = 32 ,
    parameter AXIL_ADDR_WIDTH = 24 ,

    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8)
) (

    input  wire clk   , // i, 1
    input  wire rst_n , // i, 1

    /* --------Req Channel{begin}-------- */
    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    input  wire [`PIO_DATA_W-1:0] pio_eth_req_data  , // i, `PIO_DATA_W
    input  wire [`PIO_HEAD_W-1:0] pio_eth_req_head  , // i, `PIO_HEAD_W
    input  wire [1          -1:0] pio_eth_req_last  , // i, 1             
    input  wire [1          -1:0] pio_eth_req_valid , // i, 1             
    output wire [1          -1:0] pio_eth_req_ready , // o, 1             
    /* --------Req Channel{end}-------- */

    /* --------Rsp Channel{begin}-------- */         
    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    output wire [`PIO_DATA_W-1:0] st_pio_eth_rrsp_data , // o, `PIO_DATA_W
    output wire [`PIO_HEAD_W-1:0] st_pio_eth_rrsp_head , // o, `PIO_HEAD_W
    output wire [1          -1:0] st_pio_eth_rrsp_last , // o, 1             
    output wire [1          -1:0] st_pio_eth_rrsp_valid, // o, 1             
    input  wire [1          -1:0] st_pio_eth_rrsp_ready, // i, 1             
    /* -------Rsp Channel{end}-------- */

    /* --------Interact with Ethernet BAR{begin}------- */
    output wire [AXIL_ADDR_WIDTH-1:0]    m_axil_awaddr ,
    output wire                          m_axil_awvalid,
    input  wire                          m_axil_awready,

    output wire [AXIL_DATA_WIDTH-1:0]    m_axil_wdata ,
    output wire [AXIL_STRB_WIDTH-1:0]    m_axil_wstrb , // byte select
    output wire                          m_axil_wvalid,
    input  wire                          m_axil_wready,

    input  wire                          m_axil_bvalid,
    output wire                          m_axil_bready,

    output wire [AXIL_ADDR_WIDTH-1:0]    m_axil_araddr ,
    output wire                          m_axil_arvalid,
    input  wire                          m_axil_arready,
    
    input  wire [AXIL_DATA_WIDTH-1:0]    m_axil_rdata ,
    input  wire                          m_axil_rvalid,
    output wire                          m_axil_rready
    /* --------Interact with Ethernet BAR{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [31:0] dbg_sel  // debug bus select
    ,output wire [31:0] dbg_bus  // debug bus data    
    /* -------APB reated signal{end}------- */
`endif
);

/* --------Related to FIFO{begin}-------- */
/* pio_head
 * |  131  | 130:128 | 127:96 |   95:0  |
 * | is_wr | bar_id  |  addr  | cc_head |
 */
wire req_valid, req_ready;
wire [`PIO_DATA_W-1:0] req_data; // `PIO_DATA_W
wire [`PIO_HEAD_W-1:0] req_head; // `PIO_HEAD_W

wire eth_full, eth_empty;
wire is_wr;
wire [31:0] addr;
wire [2 :0] bar_id;
wire [13-1:0] byte_len;
/* --------Related to FIFO{end}-------- */

/* -------FSM relevant{begin}------- */
localparam  IDLE     = 6'b00_0001, // Wait for input
            EN_AWRSP = 6'b00_0010, // Wait for Ethernet Addr Write rsp
            EN_WRSP  = 6'b00_0100, // Wait for Ethernet Write rsp
            EN_WBRSP = 6'b00_1000, // Wait for Ethernet Write back rsp
            EN_ARRSP = 6'b01_0000, // Wait for Ethernet Addr Read rsp
            EN_RRSP  = 6'b10_0000; // Wait for Ethernet Read rsp

reg [5:0] cur_state;
reg [5:0] nxt_state;

wire is_idle, is_en_awrsp, is_en_wrsp, is_en_wbrsp, is_en_arrsp, is_en_rrsp;
/* -------FSM relevant{end}------- */

/* --------Rsp Channel{begin}-------- */         
/* pio_head
 * |  131  | 130:128 | 127:96 |   95:0  |
 * | is_wr | bar_id  |  addr  | cc_head |
 */
wire [`PIO_DATA_W-1:0] pio_eth_rrsp_data ;
wire [`PIO_HEAD_W-1:0] pio_eth_rrsp_head ;
wire [1          -1:0] pio_eth_rrsp_last ;
wire [1          -1:0] pio_eth_rrsp_valid;
wire [1          -1:0] pio_eth_rrsp_ready;
/* -------Rsp Channel{end}-------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire [`ETH_CFG_SIGNAL_W-1:0] dbg_signal_eth_cfg;
/* -------APB reated signal{end}------- */
`endif

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */

assign dbg_bus = dbg_signal_eth_cfg >> {dbg_sel, 5'd0};

assign dbg_signal_eth_cfg = { // 850
    req_valid, req_ready, req_data, req_head, // 390
    eth_full, eth_empty, is_wr, addr, bar_id, byte_len, // 51
    cur_state, nxt_state, // 12
    is_idle, is_en_awrsp, is_en_wrsp, is_en_wbrsp, is_en_arrsp, is_en_rrsp, // 6
    pio_eth_rrsp_data , pio_eth_rrsp_head , pio_eth_rrsp_last , pio_eth_rrsp_valid, pio_eth_rrsp_ready // 391
};
/* -------APB reated signal{end}------- */
`endif

/* -------ETH CFG Fifo{begin}------- */
pcieifc_sync_fifo #(
    .DSIZE ( `PIO_HEAD_W + `PIO_DATA_W ), // 132+256=388
    .ASIZE ( 2  ) // 4 depth
) eth_cfg_sync_fifo (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1
    .clr   ( 1'd0  ), // i, 1

    .wen   ( pio_eth_req_valid & pio_eth_req_ready  ), // i, 1
    .din   ( {pio_eth_req_head, pio_eth_req_data}   ), // i, DSIZE
    .full  ( eth_full  ), // o, 1

    .ren   ( req_ready ), // i, 1
    .dout  ( {req_head, req_data} ), // o, DSIZE
    .empty ( eth_empty  )  // o, 1

`ifdef PCIEI_APB_DBG
    ,.rtsel ( 2'b0 )  // i, 2
    ,.wtsel ( 2'b0 )  // i, 2
    ,.ptsel ( 2'b0 )  // i, 2
    ,.vg    ( 1'b0 )  // i, 1
    ,.vs    ( 1'b0 )  // i, 1
`endif
);
assign req_valid         = !eth_empty;
assign pio_eth_req_ready = !eth_full;

assign is_wr    = req_head[131];
assign addr     = req_head[127:96];
assign bar_id   = req_head[130:128];
assign byte_len = req_head[28:16];
/* --------ETH CFG Fifo{end}-------- */

//------------------------------{ETH BAR Space Access Engine FSM}begin------------------------------//
/******************** Stage 1: State Register **********************/

assign is_idle     = ( cur_state == IDLE     );
assign is_en_awrsp = ( cur_state == EN_AWRSP );
assign is_en_wrsp  = ( cur_state == EN_WRSP  );
assign is_en_wbrsp = ( cur_state == EN_WBRSP );
assign is_en_arrsp = ( cur_state == EN_ARRSP );
assign is_en_rrsp  = ( cur_state == EN_RRSP  );

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
            if (req_valid & is_wr) begin
                nxt_state = EN_AWRSP;
            end
            else if (req_valid & !is_wr) begin
                nxt_state = EN_ARRSP;
            end
            else begin
                nxt_state = IDLE;
            end
        end
        EN_AWRSP: begin
            if (m_axil_awvalid & m_axil_awready) begin
                nxt_state = EN_WRSP;
            end
            else begin
                nxt_state = EN_AWRSP;
            end
        end
        EN_WRSP: begin
            if (m_axil_wvalid & m_axil_wready) begin
                nxt_state = EN_WBRSP;
            end
            else begin
                nxt_state = EN_WRSP;
            end
        end
        EN_WBRSP: begin
            if (m_axil_bvalid & m_axil_bready) begin
                nxt_state = IDLE;
            end
            else begin
                nxt_state = EN_WBRSP;
            end
        end
        EN_ARRSP: begin
            if (m_axil_arvalid & m_axil_arready) begin
                nxt_state = EN_RRSP;
            end
            else begin
                nxt_state = EN_ARRSP;
            end
        end
        EN_RRSP: begin
            if (m_axil_rvalid & m_axil_rready) begin
                nxt_state = IDLE;
            end
            else begin
                nxt_state = EN_RRSP;
            end
        end
        default: begin
            nxt_state = IDLE;
        end
    endcase
end
/******************** Stage 3: Output **********************/

// Ethernet BAR Space Access Interface
assign m_axil_awvalid = is_en_awrsp;
assign m_axil_awaddr  = addr[23:0] ;

assign m_axil_wvalid  = is_en_wrsp;
assign m_axil_wdata   = req_data  ;
assign m_axil_wstrb   = (byte_len == 1) ? 4'h1 :
                        (byte_len == 2) ? 4'h3 :
                        (byte_len == 3) ? 4'h7 : 4'hF;

assign m_axil_bready  = is_en_wbrsp;

assign m_axil_arvalid = is_en_arrsp;
assign m_axil_araddr  = addr[23:0] ;

assign m_axil_rready  = pio_eth_rrsp_ready;

// Req Channel
assign req_ready = (is_en_rrsp & pio_eth_rrsp_valid & pio_eth_rrsp_ready) |
                   (is_en_wrsp & m_axil_wvalid      & m_axil_wready     );

// Rsp Channel
/* pio_head
 * |  131  | 130:128 | 127:96 |   95:0  |
 * | is_wr | bar_id  |  addr  | cc_head |
 */
assign pio_eth_rrsp_valid = is_en_rrsp & m_axil_rvalid;
assign pio_eth_rrsp_last  = pio_eth_rrsp_valid;
assign pio_eth_rrsp_head  = pio_eth_rrsp_valid ? req_head : 0;
assign pio_eth_rrsp_data  = pio_eth_rrsp_valid ? m_axil_rdata : 0;
//------------------------------{ETH BAR Space Access Engine FSM}end------------------------------//

st_reg #(
    .TUSER_WIDTH ( `PIO_HEAD_W ), 
    .TDATA_WIDTH ( `PIO_DATA_W )
) uar_db_st_reg (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( pio_eth_rrsp_valid ), // i, 1
    .axis_tlast  ( pio_eth_rrsp_last  ), // i, 1
    .axis_tuser  ( pio_eth_rrsp_head  ), // i, TUSER_WIDTH
    .axis_tdata  ( pio_eth_rrsp_data  ), // i, TDATA_WIDTH
    .axis_tready ( pio_eth_rrsp_ready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output st_reg inteface{begin}------- */
    .axis_reg_tvalid ( st_pio_eth_rrsp_valid ), // o, 1  
    .axis_reg_tlast  ( st_pio_eth_rrsp_last  ), // o, 1
    .axis_reg_tuser  ( st_pio_eth_rrsp_head  ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( st_pio_eth_rrsp_data  ), // o, TDATA_WIDTH
    .axis_reg_tready ( st_pio_eth_rrsp_ready )  // i, 1
    /* -------output st_reg inteface{end}------- */
);

`ifdef ILA_ON
//    ila_eth_cfg_ncsg_rd ila_eth_cfg_ncsg_rd_inst(
//        .clk(clk),
//        .probe0(m_axil_araddr) ,
//        .probe1(m_axil_arvalid),
//        .probe2(m_axil_arready),
    
//        .probe3(m_axil_rdata) ,
//        .probe4(m_axil_rvalid),
//        .probe5(m_axil_rready)

//    );
`endif

endmodule