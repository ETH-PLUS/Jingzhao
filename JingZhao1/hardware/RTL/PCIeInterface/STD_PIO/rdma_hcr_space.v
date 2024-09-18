`timescale 1ns / 100ps
//*************************************************************************
// > File   : rdma_hcr_space.v
// > Author : Kangning
// > Date   : 2020-08-17
// > Note   : Store the content of RDMA BAR space
// >           V0.5 -- Only support BAR0-1 space (HCR)
// >           V1.0 -- Support BAR0-1 and BAR 2-3
// >           V1.1 -- Divide clock domain between PCIe and RDMA
// >           V1.2 -- Put async fifo behind the module. HCR register can interact
// >           with CEU directly.
// >           V1.3 -- Remove BAR 2-3 related logic
//*************************************************************************

module rdma_hcr_space #(
      
) (
    input  wire                      clk,
    input  wire                      rst_n,


    /* -------pio <--> RDMA interface (in clk domain){begin}------- */
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
    /* -------pio <-->RDMA interface (in clk domain){end}------- */

    /* -------Reset signal{begin}------- */
    output reg                          is_rst,
    input  wire                         init_done,
    /* -------Reset signal{end}------- */

    /* -------Access BAR space Interface{begin}------- */
    input  wire        req_vld  , // i, 1
    input  wire [7 :0] req_wen  , // i, 8
    input  wire [63:0] req_addr , // i, 64
    input  wire [63:0] req_wdata, // i, 64

    output reg         rsp_valid, // o, 1
    output reg  [31:0] rsp_rdata, // o, 64
    input  wire        rsp_ready  // i, 1
    /* -------Access BAR space Interface{end}------- */

`ifdef PCIEI_APB_DBG
    /* -------APB reated signal{begin}------- */
    ,output wire [`RDMA_HCR_SPACE_SIGNAL_W-1:0] dbg_signal // o, `RDMA_HCR_SPACE_SIGNAL_W
    /* -------APB reated signal{end}------- */
`endif
);
/* ------- BAR irrelevant{begin}------- */
// bar rd || wr
wire req_ren;

// BAR address selection, write of less than 32 bits to BAR space don't work.
wire bar0_0_hit   ;
wire bar0_1_hit   ;
wire bar0_2_hit   ;
wire bar0_3_hit   ;
wire bar0_4_hit   ;
wire bar0_5_hit   ;
wire bar0_6_hit   ;
wire bar0_init_done_hit;
wire bar0_rst_hit ;
/* ------- BAR irrelevant{end}------- */

/* -------BAR0 variable{begin}------- */

wire         set_rst;

reg [63:0] reg_in_param   ;
reg [31:0] reg_in_modifier;
reg [63:0] reg_out_param  ;
reg [15:0] reg_token      ;
reg [ 7:0] reg_status     ;
reg        reg_go         ;
reg        reg_event      ;
reg [ 7:0] reg_op_modifier;
reg [11:0] reg_op         ;

wire bar0_en;
/* -------BAR0 variable{end}------- */

//----------------------------------------------------------------------------------------------------------------------

`ifdef PCIEI_APB_DBG
/* -------APB reated signal{begin}------- */

assign dbg_signal = { // 218
    req_ren, // 1
    bar0_0_hit, bar0_1_hit, bar0_2_hit, bar0_3_hit, bar0_4_hit, bar0_5_hit, bar0_6_hit, bar0_init_done_hit, bar0_rst_hit, // 9
    set_rst, // 1
    reg_in_param, reg_in_modifier, reg_out_param, reg_token, reg_status, reg_go, reg_event, reg_op_modifier, reg_op, // 206
    bar0_en // 1
};

/* -------APB reated signal{end}------- */
`endif

/* -------BAR irrelevant{bagin}------- */
// BAR rd || wr
assign req_ren = req_vld & !(|req_wen);

// BAR address selection
assign bar0_0_hit = req_addr[19:0] == 20'h00 + `HCR_BASE;
assign bar0_1_hit = req_addr[19:0] == 20'h04 + `HCR_BASE;
assign bar0_2_hit = req_addr[19:0] == 20'h08 + `HCR_BASE;
assign bar0_3_hit = req_addr[19:0] == 20'h0C + `HCR_BASE;
assign bar0_4_hit = req_addr[19:0] == 20'h10 + `HCR_BASE;
assign bar0_5_hit = req_addr[19:0] == 20'h14 + `HCR_BASE;
assign bar0_6_hit = req_addr[19:0] == 20'h18 + `HCR_BASE;

assign bar0_init_done_hit = req_addr[19:0] == `INIT_DONE_OFFSET;
assign bar0_rst_hit       = req_addr[19:0] == `CMD_RST_OFFSET; // BAR0-1 has 1MB space, which is 20 bits
/* -------BAR irrelevant{end}------- */


/* -------BAR0 logic{begin}------- */
assign bar0_en = req_vld;

always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        reg_in_param <= `TD 0;
    end
    else if ((req_wen == 8'hf) && bar0_en && bar0_0_hit) begin
        reg_in_param <= `TD {req_wdata[31:0], reg_in_param[31:0]};
    end
    else if ((req_wen == 8'hf) && bar0_en && bar0_1_hit) begin
        reg_in_param <= `TD {reg_in_param[63:32], req_wdata[31:0]};
    end
end

always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        reg_in_modifier <= `TD 0;
    end
    else if ((req_wen == 8'hf) && bar0_en && bar0_2_hit) begin
        reg_in_modifier <= `TD req_wdata[31:0];
    end
end

always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        reg_out_param <= `TD 64'h0;
    end
    else if (pio_hcr_clear) begin
        reg_out_param <= `TD pio_hcr_out_param;
    end 
    else if ((req_wen == 8'hf) && bar0_en && bar0_3_hit) begin
        reg_out_param <= `TD {req_wdata[31:0], reg_out_param[31:0]};
    end
    else if ((req_wen == 8'hf) && bar0_en && bar0_4_hit) begin
        reg_out_param <= `TD {reg_out_param[63:32], req_wdata[31:0]};
    end
end

always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        reg_token <= `TD 16'd0;
    end
    else if ((req_wen == 8'hf) && bar0_en && bar0_5_hit) begin
        reg_token <= `TD req_wdata[31:16];
    end
end

always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        reg_status      <= `TD 8'd0;
        reg_go          <= `TD 1'd0;
        reg_event       <= `TD 1'd0;
        reg_op_modifier <= `TD 8'd0;
        reg_op          <= `TD 12'd0;
    end
    else if (pio_hcr_clear) begin
        reg_status <= `TD pio_hcr_status;
        reg_go     <= `TD 1'd0;
    end
    else if ((req_wen == 8'hf) && bar0_en && bar0_6_hit) begin
        reg_status      <= `TD req_wdata[31:24];
        reg_go          <= `TD req_wdata[23];
        reg_event       <= `TD req_wdata[22];
        reg_op_modifier <= `TD req_wdata[19:12];
        reg_op          <= `TD req_wdata[11:0];
    end
end

assign set_rst = bar0_rst_hit & (req_wen[3:0] == 8'hf) & req_wdata[0];
always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        is_rst  <= `TD 0;
    end
    else if (bar0_en & set_rst) begin
        is_rst  <= `TD 1;
    end
    else begin
        is_rst  <= `TD 1'b0;
    end
end

always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        rsp_rdata <= `TD 32'd0;
        rsp_valid <= `TD 1'd0  ;
    end
    else if (req_ren && bar0_en) begin
        if (bar0_0_hit) begin
            rsp_rdata <= `TD reg_in_param[63:32];
        end
        else if (bar0_1_hit) begin
            rsp_rdata <= `TD reg_in_param[31:0];
        end
        else if (bar0_2_hit) begin
            rsp_rdata <= `TD reg_in_modifier;
        end
        else if (bar0_3_hit) begin
            rsp_rdata <= `TD reg_out_param[63:32];
        end
        else if (bar0_4_hit) begin
            rsp_rdata <= `TD reg_out_param[31:0];
        end
        else if (bar0_5_hit) begin
            rsp_rdata <= `TD {reg_token, 16'd0};
        end
        else if (bar0_6_hit) begin
            rsp_rdata <= `TD {reg_status, reg_go, reg_event, 2'd0, reg_op_modifier, reg_op};
        end
        else if (bar0_init_done_hit) begin
            rsp_rdata <= `TD init_done;
        end
        else begin
            rsp_rdata <= `TD 32'd0;
        end
        rsp_valid    <= `TD 1'd1  ;
    end
    else if (rsp_valid & rsp_ready) begin
        rsp_rdata <= `TD 32'd0;
        rsp_valid <= `TD 1'd0 ;
    end
end

// in clk domain
assign pio_hcr_in_param    = reg_in_param   ;
assign pio_hcr_in_modifier = reg_in_modifier;
assign pio_hcr_out_dma_addr= reg_out_param  ;
assign pio_hcr_token       = reg_token      ;
assign pio_hcr_go          = reg_go         ;
assign pio_hcr_event       = reg_event      ;
assign pio_hcr_op_modifier = reg_op_modifier;
assign pio_hcr_op          = reg_op         ;
/* -------BAR0 logic in clk domain{end}------- */

endmodule