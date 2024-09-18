`timescale 1ns / 100ps
module pcieifc_sync_fifo_2psram 
#(
    parameter DATA_WIDTH  = 88,
    parameter FIFO_DEPTH  = 1024,
    parameter SRAM_MODE = 0, //0:simulation; 1:smic rx high speed port;2:smic rx low speed port;else : smic tx
    parameter ADDR_WIDTH  = log2b(FIFO_DEPTH-1), 
    parameter DEPTH_WIDTH = log2b(FIFO_DEPTH) 
)
(
    input                   clk,
    input                   rst_n,

    input                   wr_en,
    input  [DATA_WIDTH-1:0] din,
    output                  full,

    input                   rd_en,
    output [DATA_WIDTH-1:0] dout,
    output                  empty,
    output [DEPTH_WIDTH-1:0]   empty_entry_num

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

function integer log2b;
input integer val;
begin: func_log2b
    integer i;
    log2b = 1;
    for (i=0; i<32; i=i+1) begin
        if (|(val >> i)) begin
            log2b = i+1;
        end
    end
end
endfunction

wire                            sram_wr_cen;
wire  [ADDR_WIDTH-1:0]          sram_wr_a;
wire  [DATA_WIDTH-1:0]          sram_wr_d;

wire                            sram_rd_cen;
wire  [ADDR_WIDTH-1:0]          sram_rd_a;
wire  [DATA_WIDTH-1:0]          sram_rd_q;

pcieifc_sync_fifo_ctrl_2psram #(.DATA_WIDTH(DATA_WIDTH),.FIFO_DEPTH(FIFO_DEPTH))   U_sync_fifo_ctrl_2psram
(
    .clk(clk),
    .rst_n(rst_n),
    .push(wr_en),
    .pop(rd_en),
    .data_in(din),
    .data_out(dout),
    .full(full),
    .empty(empty),
    .remain(empty_entry_num),      
    .count(),
    .ovflow(),
    .undflow(),
    .sram_wr_cen(sram_wr_cen),
    .sram_wr_a  (sram_wr_a  ),
    .sram_wr_d  (sram_wr_d  ),
    .sram_rd_cen(sram_rd_cen),
    .sram_rd_a  (sram_rd_a  ),
    .sram_rd_q  (sram_rd_q  )
);

`ifdef FPGA_VERSION
        pciei_sram_2port_model #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH),.FIFO_DEPTH(FIFO_DEPTH)) U_sram_2port_model(
            .clk(clk),
            .sram_wr_cen(sram_wr_cen),
            .sram_wr_a(sram_wr_a),
            .sram_wr_d(sram_wr_d),
            .sram_rd_cen(sram_rd_cen),
            .sram_rd_a(sram_rd_a),
            .sram_rd_q(sram_rd_q)
        );

`else
generate

if (DATA_WIDTH == 6 && FIFO_DEPTH == 64) begin: W6_D64 // np_tag_mgmt, 2prf, 1, free_tag_fifo

    TS6N28HPCSVTA64X6M2SBR TS6N28HPCSVTA64X6M2SBR (
        .AA   ( sram_wr_a          ), // input [M-1:0] AA;
        .D    ( sram_wr_d          ), // input [N-1:0] D;
        .WEB  ( sram_wr_cen        ), // input         WEB;
        .CLKW ( clk                ), // input         CLKW;
        .AB   ( sram_rd_a          ), // input [M-1:0] AB;
        .REB  ( sram_rd_cen        ), // input         REB;
        .CLKR ( clk                ), // input         CLKR;
        .AMA  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMA;
        .DM   ( {DATA_WIDTH{1'b0}} ), // input [N-1:0] DM;
        .WEBM ( 1'b0               ), // input         WEBM;
        .AMB  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMB; 
        .REBM ( 1'b0               ), // input         REBM;
        .BIST ( 1'b0               ), // input         BIST;
        .SCLK ( 1'b0               ), // input         SCLK; 
        .SDIN ( 1'b0               ), // input         SDIN; 
        .SDOUT(                    ), // output        SDOUT; 
        .RSTB ( 1'b1               ), // input         RSTB; 
        .Q    ( sram_rd_q          )  // output [N-1:0] Q;
    );

end
else if (DATA_WIDTH == 30 && FIFO_DEPTH == 64) begin: W30_D64 // np_tag_mgmt, 2prf, 9, alloced_tag_fifo

    TS6N28HPCSVTA64X18M2SBR TS6N28HPCSVTA64X18M2SBR_2 (
        .AA   ( sram_wr_a          ), // input [M-1:0] AA;
        .D    ( sram_wr_d[29:12]   ), // input [N-1:0] D;
        .WEB  ( sram_wr_cen        ), // input         WEB;
        .CLKW ( clk                ), // input         CLKW;
        .AB   ( sram_rd_a          ), // input [M-1:0] AB;
        .REB  ( sram_rd_cen        ), // input         REB;
        .CLKR ( clk                ), // input         CLKR;
        .AMA  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMA;
        .DM   ( {18{1'b0}}         ), // input [N-1:0] DM;
        .WEBM ( 1'b0               ), // input         WEBM;
        .AMB  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMB; 
        .REBM ( 1'b0               ), // input         REBM;
        .BIST ( 1'b0               ), // input         BIST;
        .SCLK ( 1'b0               ), // input         SCLK; 
        .SDIN ( 1'b0               ), // input         SDIN; 
        .SDOUT(                    ), // output        SDOUT; 
        .RSTB ( 1'b1               ), // input         RSTB; 
        .Q    ( sram_rd_q[29:12]   )  // output [N-1:0] Q;
    );

    TS6N28HPCSVTA64X6M2SBR TS6N28HPCSVTA64X6M2SBR_1 (
        .AA   ( sram_wr_a          ), // input [M-1:0] AA;
        .D    ( sram_wr_d[11:6]    ), // input [N-1:0] D;
        .WEB  ( sram_wr_cen        ), // input         WEB;
        .CLKW ( clk                ), // input         CLKW;
        .AB   ( sram_rd_a          ), // input [M-1:0] AB;
        .REB  ( sram_rd_cen        ), // input         REB;
        .CLKR ( clk                ), // input         CLKR;
        .AMA  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMA;
        .DM   ( {6{1'b0}} ), // input [N-1:0] DM;
        .WEBM ( 1'b0               ), // input         WEBM;
        .AMB  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMB; 
        .REBM ( 1'b0               ), // input         REBM;
        .BIST ( 1'b0               ), // input         BIST;
        .SCLK ( 1'b0               ), // input         SCLK; 
        .SDIN ( 1'b0               ), // input         SDIN; 
        .SDOUT(                    ), // output        SDOUT; 
        .RSTB ( 1'b1               ), // input         RSTB; 
        .Q    ( sram_rd_q[11:6]    )  // output [N-1:0] Q;
    );

    TS6N28HPCSVTA64X6M2SBR TS6N28HPCSVTA64X6M2SBR_0 (
        .AA   ( sram_wr_a          ), // input [M-1:0] AA;
        .D    ( sram_wr_d[5:0]     ), // input [N-1:0] D;
        .WEB  ( sram_wr_cen        ), // input         WEB;
        .CLKW ( clk                ), // input         CLKW;
        .AB   ( sram_rd_a          ), // input [M-1:0] AB;
        .REB  ( sram_rd_cen        ), // input         REB;
        .CLKR ( clk                ), // input         CLKR;
        .AMA  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMA;
        .DM   ( {6{1'b0}}          ), // input [N-1:0] DM;
        .WEBM ( 1'b0               ), // input         WEBM;
        .AMB  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMB; 
        .REBM ( 1'b0               ), // input         REBM;
        .BIST ( 1'b0               ), // input         BIST;
        .SCLK ( 1'b0               ), // input         SCLK; 
        .SDIN ( 1'b0               ), // input         SDIN; 
        .SDOUT(                    ), // output        SDOUT; 
        .RSTB ( 1'b1               ), // input         RSTB; 
        .Q    ( sram_rd_q[5:0]     )  // output [N-1:0] Q;
    );

end // DATA_WIDTH == 30 && FIFO_DEPTH == 64
else if (DATA_WIDTH == 10 && FIFO_DEPTH == 1024) begin: W10_D1024 // P2P, uhddpsram, 1, tgt_pyld_buf

    TSDN28HPCUHDB1024X10M4MR TSDN28HPCUHDB1024X10M4MR (
        .RTSEL ( rtsel              ), // input [1:0] RTSEL;
        .WTSEL ( wtsel              ), // input [1:0] WTSEL;
        .PTSEL ( ptsel              ), // input [1:0] PTSEL;
        .FAD0  (      10'b0         ), // input [9:0] FAD0  
        .FAD1  (      10'b0         ), // input [9:0] FAD1  
        .REDEN0(      1'b0          ), // input REDEN0
        .REDEN1(      1'b0          ), // input REDEN1
        .AA    ( sram_rd_a          ), // input [M-1:0] AA;
        .DA    ( {DATA_WIDTH{1'b0}} ), // input [N-1:0] DA;
        .WEBA  ( 1'b1               ), // input WEBA; read channel
        .CEBA  ( sram_rd_cen        ), // input CEBA; chip enable, low-active
        .CLK   ( clk                ), // input CLK;
        .AB    ( sram_wr_a          ), // input [M-1:0] AB;
        .DB    ( sram_wr_d          ), // input [N-1:0] DB;
        .WEBB  ( 1'b0               ), // input WEBB; write channel
        .CEBB  ( sram_wr_cen        ), // input CEBB; chip enable, low-active
        .QA    ( sram_rd_q          ), // output [N-1:0] QA;
        .QB    (                    )  // output [N-1:0] QB;
    );

end
else if (DATA_WIDTH == 80 && FIFO_DEPTH == 512) begin: W80_D512 // P2P, uhddpsram, 2 * 16, desc_queue
    
    TSDN28HPCUHDB512X80M4MR TSDN28HPCUHDB512X80M4MR (
        .RTSEL ( rtsel              ), // input [1:0] RTSEL;
        .WTSEL ( wtsel              ), // input [1:0] WTSEL;
        .PTSEL ( ptsel              ), // input [1:0] PTSEL;
        .FAD0  (      10'b0         ), // input [9:0] FAD0  
        .FAD1  (      10'b0         ), // input [9:0] FAD1  
        .REDEN0(      1'b0          ), // input REDEN0
        .REDEN1(      1'b0          ), // input REDEN1
        .AA    ( sram_rd_a          ), // input [M-1:0] AA;
        .DA    ( {DATA_WIDTH{1'b0}} ), // input [N-1:0] DA;
        .WEBA  ( 1'b1               ), // input WEBA; read channel
        .CEBA  ( sram_rd_cen        ), // input CEBA; chip enable, low-active
        .CLK   ( clk                ), // input CLK;
        .AB    ( sram_wr_a          ), // input [M-1:0] AB;
        .DB    ( sram_wr_d          ), // input [N-1:0] DB;
        .WEBB  ( 1'b0               ), // input WEBB; write channel
        .CEBB  ( sram_wr_cen        ), // input CEBB; chip enable, low-active
        .QA    ( sram_rd_q          ), // output [N-1:0] QA;
        .QB    (                    )  // output [N-1:0] QB;
    );

end
else if (DATA_WIDTH == 64 && FIFO_DEPTH == 64) begin: W64_D64 /// PIO, 2prf, 1, rdma_uar

    TS6N28HPCSVTA64X64M2SBR TS6N28HPCSVTA64X64M2SBR (
        .AA   ( sram_wr_a          ), // input [M-1:0] AA;
        .D    ( sram_wr_d          ), // input [N-1:0] D;
        .WEB  ( sram_wr_cen        ), // input         WEB;
        .CLKW ( clk                ), // input         CLKW;
        .AB   ( sram_rd_a          ), // input [M-1:0] AB;
        .REB  ( sram_rd_cen        ), // input         REB;
        .CLKR ( clk                ), // input         CLKR;
        .AMA  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMA;
        .DM   ( {DATA_WIDTH{1'b0}} ), // input [N-1:0] DM;
        .WEBM ( 1'b0               ), // input         WEBM;
        .AMB  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMB; 
        .REBM ( 1'b0               ), // input         REBM;
        .BIST ( 1'b0               ), // input         BIST;
        .SCLK ( 1'b0               ), // input         SCLK; 
        .SDIN ( 1'b0               ), // input         SDIN; 
        .SDOUT(                    ), // output        SDOUT; 
        .RSTB ( 1'b1               ), // input         RSTB; 
        .Q    ( sram_rd_q          )  // output [N-1:0] Q;
      );
    
end // DATA_WIDTH == 64 && FIFO_DEPTH == 16
else if (DATA_WIDTH == 265 && FIFO_DEPTH == 32) begin: W265_D32 // STD_PIO, 2prf, 1, cc_async_fifos

    TS6N28HPCSVTA32X133M2FBR TS6N28HPCSVTA32X133M2FBR_0 (
        .AA   ( sram_wr_a          ), // input [M-1:0] AA;
        .D    ( sram_wr_d[132:0]   ), // input [N-1:0] D;
        .WEB  ( sram_wr_cen        ), // input         WEB;
        .CLKW ( clk                ), // input         CLKW;
        .AB   ( sram_rd_a          ), // input [M-1:0] AB;
        .REB  ( sram_rd_cen        ), // input         REB;
        .CLKR ( clk                ), // input         CLKR;
        .AMA  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMA;
        .DM   ( {133{1'b0}}        ), // input [N-1:0] DM;
        .WEBM ( 1'b0               ), // input         WEBM;
        .AMB  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMB; 
        .REBM ( 1'b0               ), // input         REBM;
        .BIST ( 1'b0               ), // input         BIST;
        .SCLK ( 1'b0               ), // input         SCLK; 
        .SDIN ( 1'b0               ), // input         SDIN; 
        .SDOUT(                    ), // output        SDOUT; 
        .RSTB ( 1'b1               ), // input         RSTB; 
        .Q    ( sram_rd_q[132:0]   )  // output [N-1:0] Q;
    );

    TS6N28HPCSVTA32X132M2FBR TS6N28HPCSVTA32X132M2FBR_1 (
        .AA   ( sram_wr_a          ), // input [M-1:0] AA;
        .D    ( sram_wr_d[264:133] ), // input [N-1:0] D;
        .WEB  ( sram_wr_cen        ), // input         WEB;
        .CLKW ( clk                ), // input         CLKW;
        .AB   ( sram_rd_a          ), // input [M-1:0] AB;
        .REB  ( sram_rd_cen        ), // input         REB;
        .CLKR ( clk                ), // input         CLKR;
        .AMA  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMA;
        .DM   ( {132{1'b0}}        ), // input [N-1:0] DM;
        .WEBM ( 1'b0               ), // input         WEBM;
        .AMB  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMB; 
        .REBM ( 1'b0               ), // input         REBM;
        .BIST ( 1'b0               ), // input         BIST;
        .SCLK ( 1'b0               ), // input         SCLK; 
        .SDIN ( 1'b0               ), // input         SDIN; 
        .SDOUT(                    ), // output        SDOUT; 
        .RSTB ( 1'b1               ), // input         RSTB; 
        .Q    ( sram_rd_q[264:133] )  // output [N-1:0] Q;
    );

end // DATA_WIDTH == 265 && FIFO_DEPTH == 32
else if (DATA_WIDTH == 256 && FIFO_DEPTH == 128) begin: W256_D128 // DMA, 2prf, 1 * 9, sub_req_rsp_concat

    TS6N28HPCSVTA128X128M2SBR TS6N28HPCSVTA128X128M2SBR_0 (
        .AA   ( sram_wr_a          ), // input [M-1:0] AA;
        .D    ( sram_wr_d[127:0]   ), // input [N-1:0] D;
        .WEB  ( sram_wr_cen        ), // input         WEB;
        .CLKW ( clk                ), // input         CLKW;
        .AB   ( sram_rd_a          ), // input [M-1:0] AB;
        .REB  ( sram_rd_cen        ), // input         REB;
        .CLKR ( clk                ), // input         CLKR;
        .AMA  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMA;
        .DM   ( {128{1'b0}}        ), // input [N-1:0] DM;
        .WEBM ( 1'b0               ), // input         WEBM;
        .AMB  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMB; 
        .REBM ( 1'b0               ), // input         REBM;
        .BIST ( 1'b0               ), // input         BIST;
        .SCLK ( 1'b0               ), // input         SCLK; 
        .SDIN ( 1'b0               ), // input         SDIN; 
        .SDOUT(                    ), // output        SDOUT; 
        .RSTB ( 1'b1               ), // input         RSTB; 
        .Q    ( sram_rd_q[127:0]   )  // output [N-1:0] Q;
      );

      TS6N28HPCSVTA128X128M2SBR TS6N28HPCSVTA128X128M2SBR_1 (
        .AA   ( sram_wr_a          ), // input [M-1:0] AA;
        .D    ( sram_wr_d[255:128] ), // input [N-1:0] D;
        .WEB  ( sram_wr_cen        ), // input         WEB;
        .CLKW ( clk                ), // input         CLKW;
        .AB   ( sram_rd_a          ), // input [M-1:0] AB;
        .REB  ( sram_rd_cen        ), // input         REB;
        .CLKR ( clk                ), // input         CLKR;
        .AMA  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMA;
        .DM   ( {128{1'b0}}        ), // input [N-1:0] DM;
        .WEBM ( 1'b0               ), // input         WEBM;
        .AMB  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMB; 
        .REBM ( 1'b0               ), // input         REBM;
        .BIST ( 1'b0               ), // input         BIST;
        .SCLK ( 1'b0               ), // input         SCLK; 
        .SDIN ( 1'b0               ), // input         SDIN; 
        .SDOUT(                    ), // output        SDOUT; 
        .RSTB ( 1'b1               ), // input         RSTB; 
        .Q    ( sram_rd_q[255:128] )  // output [N-1:0] Q;
      );
    
end // DATA_WIDTH == 256 && FIFO_DEPTH == 128
else if (DATA_WIDTH == 385 && FIFO_DEPTH == 128) begin: W385_D128 // DMA, 2prf, 1 * 8, write_request

    TS6N28HPCSVTA128X128M2SBR TS6N28HPCSVTA128X128M2SBR_0 (
        .AA   ( sram_wr_a          ), // input [M-1:0] AA;
        .D    ( sram_wr_d[127:0]   ), // input [N-1:0] D;
        .WEB  ( sram_wr_cen        ), // input         WEB;
        .CLKW ( clk                ), // input         CLKW;
        .AB   ( sram_rd_a          ), // input [M-1:0] AB;
        .REB  ( sram_rd_cen        ), // input         REB;
        .CLKR ( clk                ), // input         CLKR;
        .AMA  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMA;
        .DM   ( {128{1'b0}}        ), // input [N-1:0] DM;
        .WEBM ( 1'b0               ), // input         WEBM;
        .AMB  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMB; 
        .REBM ( 1'b0               ), // input         REBM;
        .BIST ( 1'b0               ), // input         BIST;
        .SCLK ( 1'b0               ), // input         SCLK; 
        .SDIN ( 1'b0               ), // input         SDIN; 
        .SDOUT(                    ), // output        SDOUT; 
        .RSTB ( 1'b1               ), // input         RSTB; 
        .Q    ( sram_rd_q[127:0]   )  // output [N-1:0] Q;
      );

      TS6N28HPCSVTA128X128M2SBR TS6N28HPCSVTA128X128M2SBR_1 (
        .AA   ( sram_wr_a          ), // input [M-1:0] AA;
        .D    ( sram_wr_d[255:128] ), // input [N-1:0] D;
        .WEB  ( sram_wr_cen        ), // input         WEB;
        .CLKW ( clk                ), // input         CLKW;
        .AB   ( sram_rd_a          ), // input [M-1:0] AB;
        .REB  ( sram_rd_cen        ), // input         REB;
        .CLKR ( clk                ), // input         CLKR;
        .AMA  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMA;
        .DM   ( {128{1'b0}}        ), // input [N-1:0] DM;
        .WEBM ( 1'b0               ), // input         WEBM;
        .AMB  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMB; 
        .REBM ( 1'b0               ), // input         REBM;
        .BIST ( 1'b0               ), // input         BIST;
        .SCLK ( 1'b0               ), // input         SCLK; 
        .SDIN ( 1'b0               ), // input         SDIN; 
        .SDOUT(                    ), // output        SDOUT; 
        .RSTB ( 1'b1               ), // input         RSTB; 
        .Q    ( sram_rd_q[255:128] )  // output [N-1:0] Q;
      );

    TS6N28HPCSVTA128X129M2SBR TS6N28HPCSVTA128X129M2SBR_2 (
        .AA   ( sram_wr_a          ), // input [M-1:0] AA;
        .D    ( sram_wr_d[384:256] ), // input [N-1:0] D;
        .WEB  ( sram_wr_cen        ), // input         WEB;
        .CLKW ( clk                ), // input         CLKW;
        .AB   ( sram_rd_a          ), // input [M-1:0] AB;
        .REB  ( sram_rd_cen        ), // input         REB;
        .CLKR ( clk                ), // input         CLKR;
        .AMA  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMA;
        .DM   ( {129{1'b0}}        ), // input [N-1:0] DM;
        .WEBM ( 1'b0               ), // input         WEBM;
        .AMB  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMB; 
        .REBM ( 1'b0               ), // input         REBM;
        .BIST ( 1'b0               ), // input         BIST;
        .SCLK ( 1'b0               ), // input         SCLK; 
        .SDIN ( 1'b0               ), // input         SDIN; 
        .SDOUT(                    ), // output        SDOUT; 
        .RSTB ( 1'b1               ), // input         RSTB; 
        .Q    ( sram_rd_q[384:256] )  // output [N-1:0] Q;
    );

end // DATA_WIDTH == 385 && FIFO_DEPTH == 128
else if (DATA_WIDTH == 273 && FIFO_DEPTH == 16) begin: W273_D16  // dma, rq_async_fifos, 2prf
    
    TS6N28HPCSVTA16X137M2FBR TS6N28HPCSVTA16X137M2FBR_0 (
        .AA   ( sram_wr_a          ), // input [M-1:0] AA;
        .D    ( sram_wr_d[136:0]   ), // input [N-1:0] D;
        .WEB  ( sram_wr_cen        ), // input         WEB;
        .CLKW ( clk                ), // input         CLKW;
        .AB   ( sram_rd_a          ), // input [M-1:0] AB;
        .REB  ( sram_rd_cen        ), // input         REB;
        .CLKR ( clk                ), // input         CLKR;
        .AMA  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMA;
        .DM   ( {137{1'b0}}        ), // input [N-1:0] DM;
        .WEBM ( 1'b0               ), // input         WEBM;
        .AMB  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMB; 
        .REBM ( 1'b0               ), // input         REBM;
        .BIST ( 1'b0               ), // input         BIST;
        .SCLK ( 1'b0               ), // input         SCLK; 
        .SDIN ( 1'b0               ), // input         SDIN; 
        .SDOUT(                    ), // output        SDOUT; 
        .RSTB ( 1'b1               ), // input         RSTB; 
        .Q    ( sram_rd_q[136:0]   )  // output [N-1:0] Q;
    );

    TS6N28HPCSVTA16X136M2FBR TS6N28HPCSVTA16X136M2FBR_1 (
        .AA   ( sram_wr_a          ), // input [M-1:0] AA;
        .D    ( sram_wr_d[272:137] ), // input [N-1:0] D;
        .WEB  ( sram_wr_cen        ), // input         WEB;
        .CLKW ( clk                ), // input         CLKW;
        .AB   ( sram_rd_a          ), // input [M-1:0] AB;
        .REB  ( sram_rd_cen        ), // input         REB;
        .CLKR ( clk                ), // input         CLKR;
        .AMA  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMA;
        .DM   ( {136{1'b0}}        ), // input [N-1:0] DM;
        .WEBM ( 1'b0               ), // input         WEBM;
        .AMB  ( {ADDR_WIDTH{1'b0}} ), // input [M-1:0] AMB; 
        .REBM ( 1'b0               ), // input         REBM;
        .BIST ( 1'b0               ), // input         BIST;
        .SCLK ( 1'b0               ), // input         SCLK; 
        .SDIN ( 1'b0               ), // input         SDIN; 
        .SDOUT(                    ), // output        SDOUT; 
        .RSTB ( 1'b1               ), // input         RSTB; 
        .Q    ( sram_rd_q[272:137] )  // output [N-1:0] Q;
    );

end
endgenerate
`endif
endmodule 


