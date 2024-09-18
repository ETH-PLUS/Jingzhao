`timescale 1ns / 100ps
module pcieifc_async_fifo_2psram #(
    parameter DATA_WIDTH  = 192,
    parameter ADDR_WIDTH  = 3,

    parameter FIFO_DEPTH  = (1 << ADDR_WIDTH)
) (
    input                   wr_clk,
    input                   rd_clk,
    input                   wrst_n,
    input                   rrst_n,

    input                   wr_en,
    input  [DATA_WIDTH-1:0] din  ,
    output                  full ,

    input                   rd_en,
    output [DATA_WIDTH-1:0] dout ,
    output                  empty

`ifdef PCIEI_APB_DBG
    ,input wire  [1:0]  rtsel
    ,input wire  [1:0]  wtsel
    ,input wire  [1:0]  ptsel
    ,input wire         vg   
    ,input wire         vs   
`endif
);

generate
    if (DATA_WIDTH == 96 && FIFO_DEPTH == 16) begin: W96_D16 // dma, int_proc, 2prf   
        async_fifo_v7_96W_16D async_fifo_v7_96W_16D_inst (
          .wr_clk(wr_clk),  // input wire wr_clk
          .wr_rst(~wrst_n),  // input wire wr_rst
          .rd_clk(rd_clk),  // input wire rd_clk
          .rd_rst(~rrst_n),  // input wire rd_rst
          .din(din),        // input wire din
          .wr_en(wr_en),    // input wire wr_en
          .rd_en(rd_en),    // input wire rd_en
          .dout(dout),      // output wire dout
          .full(full),      // output wire full
          .empty(empty)    // output wire empty
        );    
    end
    else if (DATA_WIDTH == 273 && FIFO_DEPTH == 16) begin: W273_D16  // dma, rq_async_fifos, 2prf
        async_fifo_v7_273W_16D async_fifo_v7_273W_16D_inst (
          .wr_clk(wr_clk),  // input wire wr_clk
          .wr_rst(~wrst_n),  // input wire wr_rst
          .rd_clk(rd_clk),  // input wire rd_clk
          .rd_rst(~rrst_n),  // input wire rd_rst
          .din(din),        // input wire din
          .wr_en(wr_en),    // input wire wr_en
          .rd_en(rd_en),    // input wire rd_en
          .dout(dout),      // output wire dout
          .full(full),      // output wire full
          .empty(empty)    // output wire empty
        );            
    end
    else if (DATA_WIDTH == 297 && FIFO_DEPTH == 16) begin: W297_D16 // dma, rc_async_fifos, 2prf
        async_fifo_v7_297W_16D async_fifo_v7_297W_16D_inst (
          .wr_clk(wr_clk),  // input wire wr_clk
          .wr_rst(~wrst_n),  // input wire wr_rst
          .rd_clk(rd_clk),  // input wire rd_clk
          .rd_rst(~rrst_n),  // input wire rd_rst
          .din(din),        // input wire din
          .wr_en(wr_en),    // input wire wr_en
          .rd_en(rd_en),    // input wire rd_en
          .dout(dout),      // output wire dout
          .full(full),      // output wire full
          .empty(empty)    // output wire empty
        );           
    end
    else if (DATA_WIDTH == 266 && FIFO_DEPTH == 32) begin: W266_D32 // pio, cq_async_fifo, 2prf
        async_fifo_v7_266W_32D async_fifo_v7_266W_32D_inst (
          .wr_clk(wr_clk),  // input wire wr_clk
          .wr_rst(~wrst_n),  // input wire wr_rst
          .rd_clk(rd_clk),  // input wire rd_clk
          .rd_rst(~rrst_n),  // input wire rd_rst
          .din(din),        // input wire din
          .wr_en(wr_en),    // input wire wr_en
          .rd_en(rd_en),    // input wire rd_en
          .dout(dout),      // output wire dout
          .full(full),      // output wire full
          .empty(empty)    // output wire empty
        );          
    end
    else if (DATA_WIDTH == 265 && FIFO_DEPTH == 32) begin: W265_D32 // pio, cc_async_fifos, 2prf
        async_fifo_v7_265W_32D async_fifo_v7_265W_32D_inst (
          .wr_clk(wr_clk),  // input wire wr_clk
          .wr_rst(~wrst_n),  // input wire wr_rst
          .rd_clk(rd_clk),  // input wire rd_clk
          .rd_rst(~rrst_n),  // input wire rd_rst
          .din(din),        // input wire din
          .wr_en(wr_en),    // input wire wr_en
          .rd_en(rd_en),    // input wire rd_en
          .dout(dout),      // output wire dout
          .full(full),      // output wire full
          .empty(empty)    // output wire empty
        );        
    end 
endgenerate

endmodule
