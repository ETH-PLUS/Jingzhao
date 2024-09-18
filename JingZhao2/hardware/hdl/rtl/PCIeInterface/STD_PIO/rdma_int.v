`timescale 1ns / 100ps
//*************************************************************************
// > File Name: rdma_int.v
// > Author   : Kangning
// > Date     : 2022-08-11
// > Note     : rdma_int, Generate configurations for RDMA MSI-X interrupt vector.
//*************************************************************************

module rdma_int #(
    parameter HCA_INT_LEN                 = 20'h400 
) (
    input  wire clk  , // i, 1
    input  wire rst_n, // i, 1

    /* --------Req Channel{begin}-------- */
    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    input  wire [`PIO_DATA_W-1:0]  pio_int_req_data  , // i, `PIO_DATA_W
    input  wire [`PIO_HEAD_W-1:0]  pio_int_req_head  , // i, `PIO_HEAD_W
    input  wire                    pio_int_req_last  , // i, 1
    input  wire                    pio_int_req_valid , // i, 1
    output wire                    pio_int_req_ready , // o, 1
    /* --------Req Channel{end}-------- */

    /* --------Rsp Channel{begin}-------- */
    /* pio_head
     * |  131  | 130:128 | 127:96 |   95:0  |
     * | is_wr | bar_id  |  addr  | cc_head |
     */
    output wire [`PIO_DATA_W-1:0] pio_int_rrsp_data , // o, `PIO_DATA_W
    output wire [`PIO_HEAD_W-1:0] pio_int_rrsp_head , // o, `PIO_HEAD_W
    output wire                   pio_int_rrsp_last , // o, 1
    output wire                   pio_int_rrsp_valid, // o, 1
    input  wire                   pio_int_rrsp_ready, // i, 1
    /* -------Rsp Channel{end}-------- */

    /* --------Rsp Channel{begin}-------- */
    input  wire                          in_pio_eq_int_req_valid, // i, 1
    input  wire [`RDMA_MSIX_NUM_LOG-1:0] in_pio_eq_int_req_num  , // i, `RDMA_MSIX_NUM_LOG
    output wire                          in_pio_eq_int_req_ready, // o, 1

    output wire                          out_pio_eq_int_rsp_valid, // o, 1
    output wire [`RDMA_MSIX_DATA_W -1:0] out_pio_eq_int_rsp_data , // o, `RDMA_MSIX_DATA_W
    input  wire                          out_pio_eq_int_rsp_ready  // i, 1
    /* -------Rsp Channel{end}-------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [4*`SRAM_RW_DATA_W-1:0] rw_data  // i, 4*`SRAM_RW_DATA_W
    ,input  wire [31:0] dbg_sel  // i, 32
    ,output wire [31:0] dbg_bus  // o, 32
    /* -------APB reated signal{end}------- */
`endif
);

localparam ENTRY_DW_WIDTH = 32;
localparam ENTRY_DW_NUM   = 4;
localparam MSIX_TABLE_SZ  = (ENTRY_DW_WIDTH * ENTRY_DW_NUM / 8) << `RDMA_MSIX_NUM_LOG;

/* --------Stream reg in&out{begin}-------- */
wire                          pio_eq_int_req_valid;
wire [`RDMA_MSIX_NUM_LOG-1:0] pio_eq_int_req_num  ;
wire                          pio_eq_int_req_ready;

wire                          pio_eq_int_rsp_valid;
wire [`RDMA_MSIX_DATA_W -1:0] pio_eq_int_rsp_data ;
wire                          pio_eq_int_rsp_ready;
/* --------Stream reg in&out{end}-------- */

/* --------Upper State Machine{begin}-------- */
localparam  UPPER_REQ  = 3'b001,
            UPPER_READ = 3'b010,
            UPPER_RSP  = 3'b100;

reg [2:0] upper_cur_state, upper_nxt_state;
wire is_upper_req, is_upper_read, is_upper_rsp;

wire         is_wr   ;
wire [31:0]  req_addr;
wire [95:0]  cc_head ;
wire [1 :0]  offset  ;

reg [95:0] cc_head_reg ;
reg [31:0] addr_reg    ;
reg [1 :0] offset_reg  ;
reg [31:0] upper_dout_reg;
/* --------Upper State Machine{end}-------- */

/* --------Down State Machine{begin}-------- */
localparam  DOWN_REQ  = 3'b001,
            DOWN_READ = 3'b010,
            DOWN_RSP  = 3'b100;

reg [2:0] down_cur_state, down_nxt_state;
wire is_down_req, is_down_read, is_down_rsp;

reg [127:0] down_dout_reg;
/* --------Down State Machine{end}-------- */

/* --------Signals related to SRAM{begin}-------- */
wire                      upper_we  [ENTRY_DW_NUM-1:0];
wire [`RDMA_MSIX_NUM_LOG -1:0] upper_addr[ENTRY_DW_NUM-1:0];
wire [ENTRY_DW_WIDTH-1:0] upper_din [ENTRY_DW_NUM-1:0];
wire [ENTRY_DW_WIDTH-1:0] upper_dout[ENTRY_DW_NUM-1:0];

// wire                      down_we  [ENTRY_DW_NUM-1:0];
wire [`RDMA_MSIX_NUM_LOG -1:0] down_addr[ENTRY_DW_NUM-1:0];
// wire [ENTRY_DW_WIDTH-1:0] down_din [ENTRY_DW_NUM-1:0];
wire [ENTRY_DW_WIDTH-1:0] down_dout[ENTRY_DW_NUM-1:0];
/* --------Signals related to SRAM{end}-------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire [`RDMA_INT_SIGNAL_W-1:0] dbg_signal_rdma_int;
wire  [ENTRY_DW_NUM*2-1:0] rtsel;
wire  [ENTRY_DW_NUM*2-1:0] wtsel;
wire  [ENTRY_DW_NUM*2-1:0] ptsel;
wire  [ENTRY_DW_NUM*1-1:0] vg   ;
wire  [ENTRY_DW_NUM*1-1:0] vs   ;
/* -------APB reated signal{end}------- */
`endif

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign {rtsel, wtsel, ptsel, vg, vs} = rw_data;   
assign dbg_bus = dbg_signal_rdma_int >> {dbg_sel, 5'd0};

generate
if (ENTRY_DW_NUM == 4) begin:DBG_CHNL4

    assign dbg_signal_rdma_int = { // 1013
        pio_eq_int_req_valid, pio_eq_int_req_num, pio_eq_int_req_ready, // 8
        pio_eq_int_rsp_valid, pio_eq_int_rsp_data , pio_eq_int_rsp_ready, // 130
        upper_cur_state, upper_nxt_state, // 6
        is_upper_req, is_upper_read, is_upper_rsp, // 3
        is_wr, req_addr, cc_head, offset, // 131
        cc_head_reg, addr_reg, offset_reg, upper_dout_reg, // 162
        down_cur_state, down_nxt_state, // 6
        is_down_req, is_down_read, is_down_rsp, // 3
        down_dout_reg, // 128

        upper_we[3], upper_addr[3], upper_din[3], upper_dout[3], down_addr[3], down_dout[3], 
        upper_we[2], upper_addr[2], upper_din[2], upper_dout[2], down_addr[2], down_dout[2], 
        upper_we[1], upper_addr[1], upper_din[1], upper_dout[1], down_addr[1], down_dout[1], 
        upper_we[0], upper_addr[0], upper_din[0], upper_dout[0], down_addr[0], down_dout[0]  // 109*4 = 436
    };

end
endgenerate

/* -------APB reated signal{end}------- */
`endif

/* --------Stream reg in&out{begin}-------- */
st_reg #(
    .TUSER_WIDTH ( 1  ), // unused
    .TDATA_WIDTH ( `RDMA_MSIX_NUM_LOG ) // 6
) int_req_st_reg (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( in_pio_eq_int_req_valid ), // i, 1
    .axis_tlast  ( 1'b1      ), // i, 1
    .axis_tuser  ( 1'b0      ), // i, TUSER_WIDTH
    .axis_tdata  ( in_pio_eq_int_req_num   ), // i, TDATA_WIDTH
    .axis_tready ( in_pio_eq_int_req_ready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output st_reg inteface{begin}------- */
    .axis_reg_tvalid ( pio_eq_int_req_valid  ), // o, 1  
    .axis_reg_tlast  (   ), // o, 1
    .axis_reg_tuser  (   ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( pio_eq_int_req_num   ), // o, TDATA_WIDTH
    .axis_reg_tready ( pio_eq_int_req_ready )  // i, 1
    /* -------output st_reg inteface{end}------- */
);

st_reg #(
    .TUSER_WIDTH ( 1  ), // unused
    .TDATA_WIDTH ( 128 )
) int_rsp_st_reg (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( pio_eq_int_rsp_valid ), // i, 1
    .axis_tlast  ( 1'b1      ), // i, 1
    .axis_tuser  ( 1'b0      ), // i, TUSER_WIDTH
    .axis_tdata  ( pio_eq_int_rsp_data  ), // i, TDATA_WIDTH
    .axis_tready ( pio_eq_int_rsp_ready ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output st_reg inteface{begin}------- */
    .axis_reg_tvalid ( out_pio_eq_int_rsp_valid ), // o, 1  
    .axis_reg_tlast  (   ), // o, 1
    .axis_reg_tuser  (   ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( out_pio_eq_int_rsp_data  ), // o, TDATA_WIDTH
    .axis_reg_tready ( out_pio_eq_int_rsp_ready )  // i, 1
    /* -------output st_reg inteface{end}------- */
);
/* --------Stream reg in&out{end}-------- */

/* -------{Upper Interrupt table access FSM}begin------- */
assign is_wr    = pio_int_req_head[131];
assign req_addr = pio_int_req_head[127:96];
assign cc_head  = pio_int_req_head[95:0];
assign offset   = req_addr[3:2];

assign is_upper_req  = upper_cur_state == UPPER_REQ;
assign is_upper_read = upper_cur_state == UPPER_READ;
assign is_upper_rsp  = upper_cur_state == UPPER_RSP;
/******************** Stage 1: State Register **********************/

always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        cc_head_reg <= `TD 0;
        addr_reg    <= `TD 0;
        offset_reg  <= `TD 0;
    end
    else if (is_upper_req & pio_int_req_valid & !is_wr) begin
        cc_head_reg <= `TD cc_head ;
        addr_reg    <= `TD req_addr;
        offset_reg  <= `TD offset  ;
    end
end

always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        upper_dout_reg <= `TD 0;
    end
    else if (is_upper_read) begin
        upper_dout_reg <= `TD upper_dout[offset_reg];
    end
end

always @(posedge clk, negedge rst_n) begin
    if(~rst_n)
        upper_cur_state <= `TD UPPER_REQ;
    else
        upper_cur_state <= `TD upper_nxt_state;
end

/******************** Stage 2: State Transition **********************/
always @(*) begin
    case(upper_cur_state)
    UPPER_REQ: begin
        if (pio_int_req_valid & !is_wr) begin
            upper_nxt_state = UPPER_READ;
        end
        else begin
            upper_nxt_state = UPPER_REQ;
        end
    end
    UPPER_READ: begin
        upper_nxt_state = UPPER_RSP;
    end
    UPPER_RSP: begin
        if (pio_int_rrsp_ready) begin
            upper_nxt_state = UPPER_REQ;
        end
        else begin
            upper_nxt_state = UPPER_RSP;
        end
    end
    default: begin
        upper_nxt_state = UPPER_REQ;
    end
    endcase
end
/******************** Stage 3: Output **********************/
assign pio_int_req_ready = is_upper_req;

assign pio_int_rrsp_data  = upper_dout_reg;
assign pio_int_rrsp_head  = {4'd0, addr_reg, cc_head_reg};
assign pio_int_rrsp_last  = is_upper_rsp;
assign pio_int_rrsp_valid = is_upper_rsp;
/* -------{Upper Interrupt table access FSM}end------- */


/* --------MSI-X Interruptt Table{begin}-------- */
genvar i;
generate
for (i = 0; i < ENTRY_DW_NUM; i = i + 1) begin:ENTRY_DW

assign upper_we  [i] = (offset == i) & is_wr;
assign upper_addr[i] = req_addr[`RDMA_MSIX_NUM_LOG-1+4:4];
assign upper_din [i] = pio_int_req_data[ENTRY_DW_WIDTH-1:0];

assign down_addr[i] = pio_eq_int_req_num;
    
pcieifc_td_sram #(
    .DATAWIDTH  ( ENTRY_DW_WIDTH     ), // Memory data word width, 32
    .ADDRWIDTH  ( `RDMA_MSIX_NUM_LOG )  // 64 entries
) entry_dw (
    .clk   ( clk   ), // i, 1
    .rst_n ( rst_n ), // i, 1

    .wea   ( upper_we  [i] ), // i, 1
    .addra ( upper_addr[i] ), // i, ADDRWIDTH
    .dina  ( upper_din [i] ), // i, DATAWIDTH
    .douta ( upper_dout[i] ), // o, DATAWIDTH

    .web   ( 1'd0         ), // i, 1
    .addrb ( down_addr[i] ), // i, ADDRWIDTH
    .dinb  ({ENTRY_DW_WIDTH{1'b0}}), // i, DATAWIDTH
    .doutb ( down_dout[i] )  // o, DATAWIDTH

`ifdef PCIEI_APB_DBG
    ,.rtsel ( rtsel[(i+1)*2-1:i*2] )  // i, 2
    ,.wtsel ( wtsel[(i+1)*2-1:i*2] )  // i, 2
    ,.ptsel ( ptsel[(i+1)*2-1:i*2] )  // i, 2
    ,.vg    ( vg   [i] )  // i, 1
    ,.vs    ( vs   [i] )  // i, 1
`endif
);

end
endgenerate
/* --------MSI-X Interruptt Table{end}-------- */

/* -------{Down Interrupt table access FSM}begin------- */
assign is_down_req  = down_cur_state == DOWN_REQ;
assign is_down_read = down_cur_state == DOWN_READ;
assign is_down_rsp  = down_cur_state == DOWN_RSP;

/******************** Stage 1: State Register **********************/
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        down_dout_reg <= `TD 0;
    end
    else if (is_down_read) begin
        down_dout_reg <= `TD {down_dout[3], down_dout[2], down_dout[1], down_dout[0]};
    end
end

always @(posedge clk, negedge rst_n) begin
    if(~rst_n)
        down_cur_state <= `TD DOWN_REQ;
    else
        down_cur_state <= `TD down_nxt_state;
end

/******************** Stage 2: State Transition **********************/
always @(*) begin
    case(down_cur_state)
    DOWN_REQ: begin
        if (pio_eq_int_req_valid) begin
            down_nxt_state = DOWN_READ;
        end
        else begin
            down_nxt_state = DOWN_REQ;
        end
    end
    DOWN_READ: begin
        if (pio_eq_int_rsp_ready) begin
            down_nxt_state = DOWN_REQ;
        end
        else begin
            down_nxt_state = DOWN_RSP;
        end
    end
    DOWN_RSP: begin
        if (pio_eq_int_rsp_ready) begin
            down_nxt_state = DOWN_REQ;
        end
        else begin
            down_nxt_state = DOWN_RSP;
        end
    end
    default: begin
        down_nxt_state = DOWN_REQ;
    end
    endcase
end
/******************** Stage 3: Output **********************/
assign pio_eq_int_req_ready = is_down_req; // o, 1

assign pio_eq_int_rsp_valid = is_down_read | is_down_rsp; // o, 1
assign pio_eq_int_rsp_data  = is_down_read ? {down_dout[3], down_dout[2], down_dout[1], down_dout[0]} : down_dout_reg; // o, 128

/* -------{Down Interrupt table access FSM}end------- */

endmodule