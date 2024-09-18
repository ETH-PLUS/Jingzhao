`timescale 1ns / 100ps
//*************************************************************************
// > File Name: req_converter.v
// > Author   : Kangning
// > Date     : 2020-08-25
// > Note     : req_converter used to convert AXI-Stream into  
// >            Xilinx PCIe compatible interface.
//*************************************************************************

//`include "../lib/global_include_h.v"

module req_converter #(
  
) (
    input  wire                        pcie_clk  ,
    input  wire                        pcie_rst_n,
    input  wire                        dma_clk   ,
    input  wire                        rst_n     ,


    /* ------- Interface with Request Arbiter{begin} ------- */
    /* AXI-Stream request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
     * or
     * AXI-Stream interrupt request tuser, only valid in first beat of a packet
     * | Reserved | REQ_TYPE |  Resv  | address | Reserved |
     * | 127:108  | 107:104  | 103:96 |  95:32  |  31:0    |
     */
    input  wire                     axis_req_tvalid, // i, 1
    input  wire                     axis_req_tlast , // i, 1
    input  wire [`DMA_DATA_W  -1:0] axis_req_tdata , // i, `DMA_DATA_W
    input  wire [`AXIS_TUSER_W-1:0] axis_req_tuser , // i, `AXIS_TUSER_W
    input  wire [`DMA_KEEP_W  -1:0] axis_req_tkeep , // i, `DMA_KEEP_W
    output wire                     axis_req_tready, // o, 1
    /* ------- Interface with Request Arbiter{end} ------- */
    

    /* -------dma --> pcie interface{begin}------- */
    // Requester request
    /*  RQ tuser
     * |  59:28 |  27:24  |    23:16   |          15         |   14:13  |      12     |     11      |     10:8    |   7:4   |    3:0   |
     * | parity | seq_num | tph_st_tag | tph_indirect_tag_en | tph_type | tph_present | discontinue | addr_offset | last_be | first_be |
     * |   0    |   0     |     0      |          0          |     0    |      0      |      0      |      0      |         |          |
     */
    output wire                   s_axis_rq_tvalid, // o, 1
    output wire                   s_axis_rq_tlast , // o, 1
    output wire [`DMA_DATA_W-1:0] s_axis_rq_tdata , // o, `DMA_DATA_W
    output wire [59           :0] s_axis_rq_tuser , // o, 60
    output wire [`DMA_KEEP_W-1:0] s_axis_rq_tkeep , // o, `DMA_KEEP_W
    input  wire                   s_axis_rq_tready, // i, 1
    /* -------dma --> pcie interface{end}------- */

    input  wire [15:0]            req_id_in, // i, 16

    /* -------Interrupt Interface Signals{begin}------- */
    input                  [1:0]     cfg_interrupt_msix_enable        ,
    input                  [1:0]     cfg_interrupt_msix_mask          ,
    output                [31:0]     cfg_interrupt_msix_data          ,
    output                [63:0]     cfg_interrupt_msix_address       ,
    output                           cfg_interrupt_msix_int           ,
    input                            cfg_interrupt_msix_sent          ,
    input                            cfg_interrupt_msix_fail          ,
    output wire            [2:0]     cfg_interrupt_msi_function_number 
    /* -------Interrupt Interface Signals{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,input  wire [`SRAM_RW_DATA_W-1:0] rw_data  // i, `SRAM_RW_DATA_W
    ,input  wire [31:0] dbg_sel  // debug bus select
    ,output wire [31:0] dbg_bus  // debug bus data    
    /* -------APB reated signal{end}------- */
`endif
);

/*-------Interrupt related logic{begin}------- */
wire        int_req_valid;
wire [31:0] int_req_data ;
wire [63:0] int_req_addr ;
wire        int_req_ready;
/*-------Interrupt related logic{end}------- */

/* -------related to input regs{begin}------- */
wire input_tready;

wire                     in_reg_tvalid;
wire                     in_reg_tlast ;
wire [`DMA_DATA_W  -1:0] in_reg_tdata ;
wire [`AXIS_TUSER_W-1:0] in_reg_tuser ;
wire [`DMA_KEEP_W  -1:0] in_reg_tkeep ;
wire                     in_reg_tready;
/* -------related to input regs{end}------- */

/* -------RQ head{begin}------- */
wire [2 :0]  attr;
wire [2 :0]  tc;
wire [15:0]  cpl_id;
wire [7 :0]  tag;
reg  [15:0]  req_id;
wire [10:0]  dw_cnt;
wire [3 :0]  req_type;
wire [127:0] rq_head;
/* -------RQ head{end}------- */

/* -------data realignment{begin}------- */
reg [127:0] tmp_reg_data;
reg [3  :0] tmp_reg_keep;

reg head_beat; // first beat of an s_axis_rq_* packet
reg tmp_beat; // data in tmp_reg as the last beat of s_axis_rq_* interface for output

wire st_tmp; // store tmp_reg in the last beat of axis_req_* interface
/* -------data realignment{end}------- */

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
wire [`REQ_CONVERT_TOP_SIGNAL_W-1:0] req_convert_top_dbg_signal;
wire [`INT_PROC_SIGNAL_W-1:0] int_proc_dbg_signal;
/* -------APB reated signal{end}------- */
`endif

//---------------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */
assign dbg_bus = {req_convert_top_dbg_signal, int_proc_dbg_signal} >> {dbg_sel, 5'd0}; // 924

assign req_convert_top_dbg_signal = { // 818
    int_req_valid, int_req_data, int_req_addr, int_req_ready, // 98
    input_tready, // 1
    in_reg_tvalid, in_reg_tlast, in_reg_tdata, in_reg_tuser, in_reg_tkeep, in_reg_tready, // 395
    attr, tc, cpl_id, tag, req_id, dw_cnt, req_type, rq_head, // 189
    tmp_reg_data, tmp_reg_keep, // 132
    head_beat, tmp_beat, // 2
    st_tmp // 1
};
/* -------APB reated signal{end}------- */
`endif

/*-------Interrupt related logic{begin}------- */
assign int_req_valid = axis_req_tuser[107:104] == `DMA_INT_REQ;
assign int_req_data  = axis_req_tdata[31:0];
assign int_req_addr  = axis_req_tuser[95:32];

int_proc int_proc (
    .pcie_clk   ( pcie_clk   ), // i, 1
    .pcie_rst_n ( pcie_rst_n ), // i, 1
    .dma_clk    ( dma_clk    ), // i, 1
    .rst_n      ( rst_n      ), // i, 1

    .int_req_valid ( int_req_valid ), // i,, 1
    .int_req_data  ( int_req_data  ), // i,, 32
    .int_req_addr  ( int_req_addr  ), // i,, 64
    .int_req_ready ( int_req_ready ), // o,, 1

    /* -------Interrupt Interface Signals{begin}------- */
    .cfg_interrupt_msix_enable         ( cfg_interrupt_msix_enable         ), // i, 2
    .cfg_interrupt_msix_mask           ( cfg_interrupt_msix_mask           ), // i, 2
    .cfg_interrupt_msix_data           ( cfg_interrupt_msix_data           ), // o, 32
    .cfg_interrupt_msix_address        ( cfg_interrupt_msix_address        ), // o, 64
    .cfg_interrupt_msix_int            ( cfg_interrupt_msix_int            ), // o, 1
    .cfg_interrupt_msix_sent           ( cfg_interrupt_msix_sent           ), // i, 1
    .cfg_interrupt_msix_fail           ( cfg_interrupt_msix_fail           ), // i, 1
    .cfg_interrupt_msi_function_number ( cfg_interrupt_msi_function_number )  // o, 3
    /* -------Interrupt Interface Signals{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,.rw_data    ( rw_data             ) // i, `SRAM_RW_DATA_W
    ,.dbg_signal ( int_proc_dbg_signal ) // o, `INT_PROC_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);
/*-------Interrupt related logic{end}------- */

/* -------related to in_reg{begin}------- */
assign axis_req_tready = int_req_valid ? int_req_ready : input_tready;
st_reg #(
    .TUSER_WIDTH ( `AXIS_TUSER_W ),
    .TDATA_WIDTH ( `DMA_KEEP_W + `DMA_DATA_W )
) in_reg (
    .clk   ( dma_clk ), // i, 1
    .rst_n ( rst_n    ), // i, 1

    /* -------input axis-like interface{begin}------- */
    .axis_tvalid ( axis_req_tvalid & (~int_req_valid)), // i, 1
    .axis_tlast  ( axis_req_tlast  ), // i, 1
    .axis_tuser  ( axis_req_tuser  ), // i, TUSER_WIDTH
    .axis_tdata  ( {axis_req_tkeep, axis_req_tdata} ), // i, TDATA_WIDTH
    .axis_tready ( input_tready    ), // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    .axis_reg_tvalid ( in_reg_tvalid ), // o, 1 
    .axis_reg_tlast  ( in_reg_tlast  ), // o, 1 
    .axis_reg_tuser  ( in_reg_tuser  ), // o, TUSER_WIDTH
    .axis_reg_tdata  ( {in_reg_tkeep, in_reg_tdata} ), // o, TDATA_WIDTH
    .axis_reg_tready ( in_reg_tready )  // i, 1
    /* -------output in_reg inteface{end}------- */
);
/* -------related to in_reg{end}------- */

/* -------RQ head{begin}------- */
always @(posedge dma_clk, negedge rst_n) begin
    if (~rst_n) begin
        req_id <= `TD 0;
    end
    else begin
        req_id <= req_id_in;
    end
end

assign attr     = 3'd0;
assign tc       = 3'd0;
assign cpl_id   = 16'd0;
assign tag      = in_reg_tuser[103:96];
// assign req_id   = 16'd0;
assign dw_cnt   = in_reg_tuser[18:8];
assign req_type = in_reg_tuser[107:104];
assign rq_head  = {1'd0, attr, tc, 1'd0, cpl_id, tag, req_id, 1'd0, req_type, dw_cnt, 
                   in_reg_tuser[95:34], 2'd0};
/* -------RQ head{end}------- */


/* -------data realignment{begin}------- */
always @(posedge dma_clk, negedge rst_n) begin
  if (~rst_n) begin
    tmp_reg_data <= `TD 128'd0;
    tmp_reg_keep <= `TD 4'd0;
  end
  else if (in_reg_tvalid & in_reg_tready) begin
    tmp_reg_data <= `TD in_reg_tdata[255:128];
    tmp_reg_keep <= `TD in_reg_tkeep[7:4];
  end
end

always @(posedge dma_clk, negedge rst_n) begin
  if (~rst_n) begin
    head_beat <= `TD 1;
  end
  else if (s_axis_rq_tvalid & s_axis_rq_tready & s_axis_rq_tlast) begin
    head_beat <= `TD 1;
  end
  else if (s_axis_rq_tvalid & s_axis_rq_tready) begin
    head_beat <= `TD 0;
  end
end

always @(posedge dma_clk, negedge rst_n) begin
  if (~rst_n) begin
    tmp_beat <= `TD 0;
  end
  else if (in_reg_tvalid & in_reg_tready & in_reg_tlast & st_tmp) begin
    tmp_beat <= `TD 1;
  end
  else if (tmp_beat & s_axis_rq_tready) begin
    tmp_beat <= `TD 0;
  end
end

assign st_tmp = |in_reg_tkeep[7:4];
/* -------data realignment{end}------- */


/* -------output {begin}------- */
assign in_reg_tready = s_axis_rq_tready & !tmp_beat;


assign s_axis_rq_tvalid = in_reg_tvalid | tmp_beat;
assign s_axis_rq_tlast  = (in_reg_tlast & !st_tmp) |
                          tmp_beat;


assign s_axis_rq_tdata  = head_beat&in_reg_tvalid ? {in_reg_tdata[127:0], rq_head}      : 
                          tmp_beat                  ? {128'd0, tmp_reg_data}                :
                          in_reg_tvalid           ? {in_reg_tdata[127:0], tmp_reg_data} : 
                          256'd0;
assign s_axis_rq_tkeep  = head_beat&in_reg_tvalid ? {in_reg_tkeep[3:0], 4'hf}         : 
                          tmp_beat                  ? {4'd0, tmp_reg_keep}                :
                          in_reg_tvalid           ? {in_reg_tkeep[3:0], tmp_reg_keep} : 
                          8'd0;


assign s_axis_rq_tuser  = head_beat ? {32'd0, 4'd0, 8'd0, 1'd0, 2'd0, 1'd0, 1'd0, 3'd0, 
                                       in_reg_tuser[3:0], in_reg_tuser[7:4]} : 0;
/* -------output {end}------- */

/* -------{Read Request Arbiter FSM}end------- */

endmodule
