`timescale 1ns / 100ps
//*************************************************************************
// > File Name: pcieifc_td_sram.v
// > Author   : Kangning
// > Date     : 2022-08-11
// > Note     : true dual port sram used in PCIe interface.
//*************************************************************************

module pcieifc_td_sram #(
    parameter DATAWIDTH  = 8, // Memory data word width
    parameter ADDRWIDTH  = 4, // Number of mem address bits
    parameter DEPTH      = 1 << ADDRWIDTH
) (
    input  wire clk  , // i, 1
    input  wire rst_n, // i, 1

    input  wire                 wea  , // i, 1
    input  wire [ADDRWIDTH-1:0] addra, // i, ADDRWIDTH
    input  wire [DATAWIDTH-1:0] dina , // i, DATAWIDTH
    output wire [DATAWIDTH-1:0] douta, // o, DATAWIDTH

    input  wire                 web  , // i, 1
    input  wire [ADDRWIDTH-1:0] addrb, // i, ADDRWIDTH
    input  wire [DATAWIDTH-1:0] dinb , // i, DATAWIDTH
    output wire [DATAWIDTH-1:0] doutb  // o, DATAWIDTH

`ifdef PCIEI_APB_DBG
    ,input wire  [1:0]  rtsel
    ,input wire  [1:0]  wtsel
    ,input wire  [1:0]  ptsel
    ,input wire         vg   
    ,input wire         vs   
`endif
);

`ifndef PCIEI_APB_DBG

wire  [1:0]  rtsel;
wire  [1:0]  wtsel;
wire  [1:0]  ptsel;
wire         vg   ;
wire         vs   ;

assign rtsel = 2'b0;
assign wtsel = 2'b0;
assign ptsel = 2'b0;
assign vg    = 1'b0;
assign vs    = 1'b0;

`endif

`ifdef FPGA_VERSION
    pciei_tdp_sram_32W_64D pciei_tdp_sram_32W_64D_inst (
      .clka(clk),    // input wire clka
      .ena(1'b1),      // input wire ena
      .wea(wea),      // input wire [0 : 0] wea
      .addra(addra),  // input wire [5 : 0] addra
      .dina(dina),    // input wire [31 : 0] dina
      .douta(douta),  // output wire [31 : 0] douta
      .clkb(clk),    // input wire clkb
      .enb(1'b1),      // input wire enb
      .web(web),      // input wire [0 : 0] web
      .addrb(addrb),  // input wire [5 : 0] addrb
      .dinb(dinb),    // input wire [31 : 0] dinb
      .doutb(doutb)  // output wire [31 : 0] doutb
    );
`else

generate
if (DATAWIDTH == 32 && DEPTH == 64) begin: W32_D64 // PIO, uhddpsram, 1, rdma_int

    TSDN28HPCUHDB64X32M4MR TSDN28HPCUHDB64X32M4MR (
        .RTSEL ( rtsel      ), // input [1:0] RTSEL;
        .WTSEL ( wtsel      ), // input [1:0] WTSEL;
        .PTSEL ( ptsel      ), // input [1:0] PTSEL;
        .FAD0  ( 10'b0      ), // input [9:0] FAD0  
        .FAD1  ( 10'b0      ), // input [9:0] FAD1  
        .REDEN0( 1'b0       ), // input REDEN0
        .REDEN1( 1'b0       ), // input REDEN1
        .AA    ( addra      ), // input [M-1:0] AA;
        .DA    ( dina       ), // input [N-1:0] DA;
        .WEBA  ( ~wea       ), // input WEBA; write channel & read channel
        .CEBA  ( 1'b0       ), // input CEBA; chip enable, low-active
        .CLK   ( clk        ), // input CLK;
        .AB    ( addrb      ), // input [M-1:0] AB;
        .DB    ( dinb       ), // input [N-1:0] DB;
        .WEBB  ( ~web       ), // input WEBB; write channel & read channel
        .CEBB  ( 1'b0       ), // input CEBB; chip enable, low-active
        .QA    ( douta      ), // output [N-1:0] QA;
        .QB    ( doutb      )  // output [N-1:0] QB;
    );
    
end // DATA_WIDTH == 32 && FIFO_DEPTH == 64
endgenerate

`endif
endmodule
