`timescale 1ns / 100ps
//*************************************************************************
// > File Name: pcieifc_sd_sram.v
// > Author   : Kangning
// > Date     : 2022-07-19
// > Note     : simple dual port sram used in PCIe interface.
//*************************************************************************

module pcieifc_sd_sram #(
    parameter DATAWIDTH  = 8, // Memory data word width
    parameter ADDRWIDTH  = 4, // Number of mem address bits
    parameter DEPTH      = 1 << ADDRWIDTH
) (
    input  wire clk  , // i, 1
    input  wire rst_n, // i, 1

    input  wire                 wea  , // i, 1
    input  wire [ADDRWIDTH-1:0] addra, // i, ADDRWIDTH
    input  wire [DATAWIDTH-1:0] dina , // i, DATAWIDTH

    input  wire                 reb  , // i, 1
    input  wire [ADDRWIDTH-1:0] addrb, // i, ADDRWIDTH
    output  wire [DATAWIDTH-1:0] doutb  // o, DATAWIDTH

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

generate
if ((DATAWIDTH == 1  && ADDRWIDTH == 5 )) begin:W1_D32  // PIO, 1, armed_eq_table

    pcieifc_sd_sram_1W_32D pcieifc_sd_sram_1W_32D_inst(
        .clka(clk),    // input wire clka
        .wea(wea),      // input wire [0 : 0] wea
        .addra(addra),  // input wire [5 : 0] addra
        .dina(dina),    // input wire [268 : 0] dina
        .clkb(clk),    // input wire clkb
        .addrb(addrb),  // input wire [5 : 0] addrb
        .doutb(doutb)  // output wire [268 : 0] doutb
    );

end // DATAWIDTH == 1  && ADDRWIDTH == 5
else if (DATAWIDTH == 269 && ADDRWIDTH == 6) begin:W269_D64  // DMA, 2prf, 1, temp_data_sram
    pcieifc_sd_sram_269W_64D pcieifc_sd_sram_269W_64D_inst(
        .clka(clk),    // input wire clka
        .wea(wea),      // input wire [0 : 0] wea
        .addra(addra),  // input wire [5 : 0] addra
        .dina(dina),    // input wire [268 : 0] dina
        .clkb(clk),    // input wire clkb
        .addrb(addrb),  // input wire [5 : 0] addrb
        .doutb(doutb)  // output wire [268 : 0] doutb
    );
end // DATAWIDTH == 269 && ADDRWIDTH == 6
else if (DATAWIDTH == 257 && ADDRWIDTH == 9) begin:W257_D512  // DMA, uhddpsram, 1, reorder_buf

    pcieifc_sd_sram_257W_512D pcieifc_sd_sram_257W_512D_inst(
        .clka(clk),    // input wire clka
        .wea(wea),      // input wire [0 : 0] wea
        .addra(addra),  // input wire [5 : 0] addra
        .dina(dina),    // input wire [268 : 0] dina
        .clkb(clk),    // input wire clkb
        .addrb(addrb),  // input wire [5 : 0] addrb
        .doutb(doutb)  // output wire [268 : 0] doutb
    );

end // DATAWIDTH == 257 && ADDRWIDTH == 9
else if (DATAWIDTH == 1 && ADDRWIDTH == 13) begin:W1_D8192 // PIO, uhddpsram, 1, armed_cq_table

       pcieifc_sd_sram_1W_256D pcieifc_sd_sram_1W_256D_inst(
        .clka(clk),    // input wire clka
        .wea(wea),      // input wire [0 : 0] wea
        .addra(addra),  // input wire [5 : 0] addra
        .dina(dina),    // input wire [268 : 0] dina
        .clkb(clk),    // input wire clkb
        .addrb(addrb),  // input wire [5 : 0] addrb
        .doutb(doutb)  // output wire [268 : 0] doutb
    );

end
else if (DATAWIDTH == 63 && ADDRWIDTH == 4) begin:W63_D16 // P2P, 2prf, 1, ini_dev2addr_table

    pcieifc_sd_sram_63W_16D pcieifc_sd_sram_63W_16D_inst(
        .clka(clk),    // input wire clka
        .wea(wea),      // input wire [0 : 0] wea
        .addra(addra),  // input wire [5 : 0] addra
        .dina(dina),    // input wire [268 : 0] dina
        .clkb(clk),    // input wire clkb
        .addrb(addrb),  // input wire [5 : 0] addrb
        .doutb(doutb)  // output wire [268 : 0] doutb
    );

end
else if (DATAWIDTH == 64 && ADDRWIDTH == 4) begin:W64_D16 // P2P, 2prf, 1, tgt_queue_struct

    pcieifc_sd_sram_64W_16D pcieifc_sd_sram_64W_16D_inst(
        .clka(clk),    // input wire clka
        .wea(wea),      // input wire [0 : 0] wea
        .addra(addra),  // input wire [5 : 0] addra
        .dina(dina),    // input wire [268 : 0] dina
        .clkb(clk),    // input wire clkb
        .addrb(addrb),  // input wire [5 : 0] addrb
        .doutb(doutb)  // output wire [268 : 0] doutb
    );
end
else if (DATAWIDTH == 256 && ADDRWIDTH == 12) begin:W256_D4096 // P2P, uhddpsram, 1, tgt_pyld_buf
    pcieifc_sd_sram_256W_4096D pcieifc_sd_sram_256W_4096D_inst(
        .clka(clk),    // input wire clka
        .wea(wea),      // input wire [0 : 0] wea
        .addra(addra),  // input wire [5 : 0] addra
        .dina(dina),    // input wire [268 : 0] dina
        .clkb(clk),    // input wire clkb
        .addrb(addrb),  // input wire [5 : 0] addrb
        .doutb(doutb)  // output wire [268 : 0] doutb
    );
end
endgenerate


endmodule
