`timescale  1ns / 1ps

`include "common_function_def.vh"

module SRAM_TDP_Template #(
    parameter       RAM_WIDTH = 32,
    parameter       RAM_DEPTH = 32,
    parameter       ADDR_WIDTH = log2b(RAM_DEPTH - 1)
)
(
    input   wire                                clk,
    input   wire                                rst,

    input   wire                                wea,
    input   wire    [ADDR_WIDTH - 1 : 0]        addra,
    input   wire    [RAM_WIDTH - 1 : 0]         dina,
    output  wire    [RAM_WIDTH - 1 : 0]         douta,             

    input   wire                                web,
    input   wire    [ADDR_WIDTH - 1 : 0]        addrb,
    input   wire    [RAM_WIDTH - 1 : 0]         dinb,
    output  wire    [RAM_WIDTH - 1 : 0]         doutb
);

wire    [RAM_WIDTH - 1 : 0]         douta_fake;             
wire    [RAM_WIDTH - 1 : 0]         doutb_fake;

generate 
    if(RAM_WIDTH == 1 && RAM_DEPTH == 4096) begin : GEN_BRAM_TDP_1W_4096D
        BRAM_TDP_1w_4096d BRAM_TDP_1w_4096d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 76 && RAM_DEPTH == 4096) begin : GEN_BRAM_TDP_76W_4096D
        BRAM_TDP_76w_4096d BRAM_TDP_76w_4096d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 87 && RAM_DEPTH == 2) begin : GEN_BRAM_TDP_87W_2D  //Test cache miss case, MTT CACHE_SET_NUM = 2
        BRAM_TDP_87w_2d BRAM_TDP_87w_2d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 340 && RAM_DEPTH == 2) begin : GEN_BRAM_TDP_340W_2D  //Test cache miss case, MPT CACHE_SET_NUM = 2
        BRAM_TDP_340w_2d BRAM_TDP_340w_2d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 1 && RAM_DEPTH == 512) begin : GEN_BRAM_TDP_1W_512D
        BRAM_TDP_1w_512d BRAM_TDP_1w_512d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 332 && RAM_DEPTH == 512) begin : GEN_BRAM_TDP_332W_512D
        BRAM_TDP_332w_512d BRAM_TDP_332w_512d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 82 && RAM_DEPTH == 4096) begin : GEN_BRAM_TDP_82W_4096D
        BRAM_TDP_82w_4096d BRAM_TDP_82w_4096d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 99 && RAM_DEPTH == 16) begin : GEN_BRAM_TDP_99W_16D
        BRAM_TDP_99w_16d BRAM_TDP_99w_16d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 136 && RAM_DEPTH == 256) begin : GEN_BRAM_TDP_136W_256D
        BRAM_TDP_136w_256d BRAM_TDP_136w_256d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 424 && RAM_DEPTH == 256) begin : GEN_BRAM_TDP_424W_256D
        BRAM_TDP_424w_256d BRAM_TDP_424w_256d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end 
    else if(RAM_WIDTH == 52 && RAM_DEPTH == 8192) begin : GEN_BRAM_TDP_52W_8192D
        BRAM_TDP_52w_8192d BRAM_TDP_52w_8192d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 24 && RAM_DEPTH == 256) begin : GEN_BRAM_TDP_24W_256D
        BRAM_TDP_24w_256d BRAM_TDP_24w_256d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 5 && RAM_DEPTH == 16) begin : GEN_BRAM_TDP_5W_16D
        BRAM_TDP_5w_16d BRAM_TDP_5w_16d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 6 && RAM_DEPTH == 16) begin : GEN_BRAM_TDP_6W_16D
        BRAM_TDP_6w_16d BRAM_TDP_6w_16d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 512 && RAM_DEPTH == 32) begin : GEN_BRAM_TDP_512W_32D
        BRAM_TDP_512w_32d BRAM_TDP_512w_32d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 1 && RAM_DEPTH == 16) begin : GEN_BRAM_TDP_1W_16D
        BRAM_TDP_1w_16d BRAM_TDP_1w_16d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 1 && RAM_DEPTH == 256) begin : GEN_BRAM_TDP_1W_256D
        BRAM_TDP_1w_256d BRAM_TDP_1w_256d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 5 && RAM_DEPTH == 256) begin : GEN_BRAM_TDP_5W_256D
        BRAM_TDP_5w_256d BRAM_TDP_5w_256d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 5 && RAM_DEPTH == 32) begin : GEN_BRAM_TDP_5W_32D
        BRAM_TDP_5w_32d BRAM_TDP_5w_32d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 98 && RAM_DEPTH == 32) begin : GEN_BRAM_TDP_98W_32D
        BRAM_TDP_98w_32d BRAM_TDP_98w_32d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 418 && RAM_DEPTH == 32) begin : GEN_BRAM_TDP_418W_32D
        BRAM_TDP_418w_32d BRAM_TDP_418w_32d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 130 && RAM_DEPTH == 32) begin : GEN_BRAM_TDP_130W_32D
        BRAM_TDP_130w_32d BRAM_TDP_130w_32d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 322 && RAM_DEPTH == 32) begin : GEN_BRAM_TDP_322W_32D
        BRAM_TDP_322w_32d BRAM_TDP_322w_32d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 192 && RAM_DEPTH == 32) begin : GEN_BRAM_TDP_192W_32D
        BRAM_TDP_192w_32d BRAM_TDP_192w_32d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 12 && RAM_DEPTH == 32) begin : GEN_BRAM_TDP_12W_32D
        BRAM_TDP_12w_32d BRAM_TDP_12w_32d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 44 && RAM_DEPTH == 32) begin : GEN_BRAM_TDP_44W_32D
        BRAM_TDP_44w_32d BRAM_TDP_44w_32d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 576 && RAM_DEPTH == 32) begin : GEN_BRAM_TDP_576W_32D
        BRAM_TDP_576w_32d BRAM_TDP_576w_32d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 6 && RAM_DEPTH == 256) begin : GEN_BRAM_TDP_6W_256D
        BRAM_TDP_6w_256d BRAM_TDP_6w_256d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 6 && RAM_DEPTH == 64) begin : GEN_BRAM_TDP_6W_64D
        BRAM_TDP_6w_64d BRAM_TDP_6w_64d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 256 && RAM_DEPTH == 64) begin : GEN_BRAM_TDP_256W_64D
        BRAM_TDP_256w_64d BRAM_TDP_256w_64d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 512 && RAM_DEPTH == 512) begin : GEN_BRAM_TDP_512W_512D
        BRAM_TDP_512w_512d BRAM_TDP_512w_512d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 9 && RAM_DEPTH == 512) begin : GEN_BRAM_TDP_9W_512D
        BRAM_TDP_9w_512d BRAM_TDP_9w_512d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 488 && RAM_DEPTH == 32) begin : GEN_BRAM_TDP_488W_32D
        BRAM_TDP_488w_32d BRAM_TDP_488w_32d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 352 && RAM_DEPTH == 32) begin : GEN_BRAM_TDP_352W_32D
        BRAM_TDP_352w_32d BRAM_TDP_352w_32d_Inst(
            .clka   (       clk             ),
            .rsta   (       rst             ),
            .wea    (       wea             ),
            .addra  (       addra           ),
            .dina   (       dina            ),
            .douta  (       douta_fake      ),
            .clkb   (       clk             ),
            .rstb   (       rst             ),
            .web    (       web             ),
            .addrb  (       addrb           ),
            .dinb   (       dinb            ),
            .doutb  (       doutb_fake      )
        );
    end
endgenerate

//Resolve read-write collisions
reg                                wea_diff;
reg    [ADDR_WIDTH - 1 : 0]        addra_diff;
reg    [RAM_WIDTH - 1 : 0]         dina_diff;

reg                                web_diff;
reg    [ADDR_WIDTH - 1 : 0]        addrb_diff;
reg    [RAM_WIDTH - 1 : 0]         dinb_diff;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        wea_diff <= 'd0;
        addra_diff <= 'd0;
        dina_diff <= 'd0;
    end
    else begin
        wea_diff <= wea;
        addra_diff <= addra;
        dina_diff <= dina;
    end
end

assign douta = (addra_diff == addrb_diff) && wea_diff && !web_diff ? dina_diff : 
                (addra_diff == addrb_diff) && !wea_diff && web_diff ? dinb_diff : 
                (addra_diff != addrb_diff) && wea_diff ? dina_diff : douta_fake;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        web_diff <= 'd0;
        addrb_diff <= 'd0;
        dinb_diff <= 'd0;
    end
    else begin
        web_diff <= web;
        addrb_diff <= addrb;
        dinb_diff <= dinb;
    end
end

assign doutb = (addra_diff == addrb_diff) && wea_diff && !web_diff ? dina_diff : 
                (addra_diff == addrb_diff) && !wea_diff && web_diff ? dinb_diff : 
                (addra_diff != addrb_diff) && web_diff ? dinb_diff : doutb_fake;

/*Debug subsystem : Begin*/
`ifdef DEBUG_ON

`endif
/*Debug subsystem : End*/


endmodule
