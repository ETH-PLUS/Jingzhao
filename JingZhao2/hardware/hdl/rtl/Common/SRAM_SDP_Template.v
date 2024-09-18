`timescale  1ns / 1ps

`include "common_function_def.vh"

module SRAM_SDP_Template #(
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

    input   wire    [ADDR_WIDTH - 1 : 0]        addrb,
    output  wire    [RAM_WIDTH - 1 : 0]         doutb                          
);

//Resolve read-write collisions
reg                                wea_diff;
reg    [ADDR_WIDTH - 1 : 0]        addra_diff;
reg    [RAM_WIDTH - 1 : 0]         dina_diff;

reg    [ADDR_WIDTH - 1 : 0]        addrb_diff;
wire   [RAM_WIDTH - 1 : 0]         doutb_fake;

generate 
    if(RAM_WIDTH == 32 && RAM_DEPTH == 32) begin : GEN_BRAM_SDP_32W_32D
        //Instantiate Xilinx IP
    end  
    else if(RAM_WIDTH == 129 && RAM_DEPTH == 64) begin : GEN_BRAM_SDP_129W_64D
    //      BRAM_SDP_129w_64d BRAM_SDP_129w_64d_inst(
    //        .clka     (clk),
    //        .wea      (wea),
    //        .addra    (addra),
    //        .dina     (dina),
    //        .clkb     (clk),
    //        .addrb    (addrb),
    //        .doutb    (doutb_fake)
    //    );

    end 
    else if(RAM_WIDTH == 24 && RAM_DEPTH == 16384) begin : GEN_BRAM_SDP_24W_16384D
    //      BRAM_SDP_24w_16384d BRAM_SDP_24w_16384d_inst(
    //        .clka     (clk),
    //        .wea      (wea),
    //        .addra    (addra),
    //        .dina     (dina),
    //        .clkb     (clk),
    //        .addrb    (addrb),
    //        .doutb    (doutb_fake)
    //    );

    end
    else if(RAM_WIDTH == 52 && RAM_DEPTH == 1) begin : GEN_BRAM_SDP_52W_1D
        BRAM_SDP_52w_1d BRAM_SDP_52w_1d_inst(
            .clka       (       clk             ),
            .wea        (       wea             ),
            .addra      (       addra           ),
            .dina       (       dina            ),
            .clkb       (       clk             ),
            .addrb      (       addrb           ),
            .doutb      (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 52 && RAM_DEPTH == 512) begin : GEN_BRAM_SDP_52W_512D
        BRAM_SDP_52w_512d BRAM_SDP_52w_512d_inst(
            .clka       (       clk             ),
            .wea        (       wea             ),
            .addra      (       addra           ),
            .dina       (       dina            ),
            .clkb       (       clk             ),
            .addrb      (       addrb           ),
            .doutb      (       doutb_fake      )
        );
    end 
    else if(RAM_WIDTH == 52 && RAM_DEPTH == 1024) begin : GEN_BRAM_SDP_52W_1024D
        BRAM_SDP_52w_1024d BRAM_SDP_52w_1024d_inst(
            .clka       (       clk             ),
            .wea        (       wea             ),
            .addra      (       addra           ),
            .dina       (       dina            ),
            .clkb       (       clk             ),
            .addrb      (       addrb           ),
            .doutb      (       doutb_fake      )
        );
    end 
    else if(RAM_WIDTH == 52 && RAM_DEPTH == 8192) begin : GEN_BRAM_SDP_52W_8192D
        BRAM_SDP_52w_8192d BRAM_SDP_52w_8192d_inst(
            .clka       (       clk             ),
            .wea        (       wea             ),
            .addra      (       addra           ),
            .dina       (       dina            ),
            .clkb       (       clk             ),
            .addrb      (       addrb           ),
            .doutb      (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 128 && RAM_DEPTH == 1024) begin : GEN_BRAM_SDP_128W_1024D
        BRAM_SDP_128w_1024d BRAM_SDP_128w_1024d_inst(
            .clka       (       clk             ),
            .wea        (       wea             ),
            .addra      (       addra           ),
            .dina       (       dina            ),
            .clkb       (       clk             ),
            .addrb      (       addrb           ),
            .doutb      (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 1 && RAM_DEPTH == 256) begin : GEN_BRAM_SDP_1W_256D
        BRAM_SDP_1w_256d BRAM_SDP_1w_256d_inst(
            .clka       (       clk             ),
            .wea        (       wea             ),
            .addra      (       addra           ),
            .dina       (       dina            ),
            .clkb       (       clk             ),
            .addrb      (       addrb           ),
            .doutb      (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 8 && RAM_DEPTH == 32) begin : GEN_BRAM_SDP_8W_32D
        BRAM_SDP_8w_32d BRAM_SDP_8w_32d_inst(
            .clka       (       clk             ),
            .wea        (       wea             ),
            .addra      (       addra           ),
            .dina       (       dina            ),
            .clkb       (       clk             ),
            .addrb      (       addrb           ),
            .doutb      (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 8 && RAM_DEPTH == 128) begin : GEN_BRAM_SDP_8W_128D
        BRAM_SDP_8w_128d BRAM_SDP_8w_128d_inst(
            .clka       (       clk             ),
            .wea        (       wea             ),
            .addra      (       addra           ),
            .dina       (       dina            ),
            .clkb       (       clk             ),
            .addrb      (       addrb           ),
            .doutb      (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 32 && RAM_DEPTH == 256) begin : GEN_BRAM_SDP_32W_256D
        BRAM_SDP_32w_256d BRAM_SDP_32w_256d_inst(
            .clka       (       clk             ),
            .wea        (       wea             ),
            .addra      (       addra           ),
            .dina       (       dina            ),
            .clkb       (       clk             ),
            .addrb      (       addrb           ),
            .doutb      (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 416 && RAM_DEPTH == 32) begin : GEN_BRAM_SDP_416W_32D
        BRAM_SDP_416w_32d BRAM_SDP_416w_32d_inst(
            .clka       (       clk             ),
            .wea        (       wea             ),
            .addra      (       addra           ),
            .dina       (       dina            ),
            .clkb       (       clk             ),
            .addrb      (       addrb           ),
            .doutb      (       doutb_fake      )
        );
    end 
    else if(RAM_WIDTH == 128 && RAM_DEPTH == 32) begin : GEN_BRAM_SDP_128W_32D
        BRAM_SDP_128w_32d BRAM_SDP_128w_32d_inst(
            .clka       (       clk             ),
            .wea        (       wea             ),
            .addra      (       addra           ),
            .dina       (       dina            ),
            .clkb       (       clk             ),
            .addrb      (       addrb           ),
            .doutb      (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 641 && RAM_DEPTH == 32) begin : GEN_BRAM_SDP_641W_32D
        BRAM_SDP_641w_32d BRAM_SDP_641w_32d_inst(
            .clka       (       clk             ),
            .wea        (       wea             ),
            .addra      (       addra           ),
            .dina       (       dina            ),
            .clkb       (       clk             ),
            .addrb      (       addrb           ),
            .doutb      (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 161 && RAM_DEPTH == 32) begin : GEN_BRAM_SDP_161W_32D
        BRAM_SDP_161w_32d BRAM_SDP_161w_32d_inst(
            .clka       (       clk             ),
            .wea        (       wea             ),
            .addra      (       addra           ),
            .dina       (       dina            ),
            .clkb       (       clk             ),
            .addrb      (       addrb           ),
            .doutb      (       doutb_fake      )
        );
    end 
    else if(RAM_WIDTH == 225 && RAM_DEPTH == 32) begin : GEN_BRAM_SDP_225W_32D
        BRAM_SDP_225w_32d BRAM_SDP_225w_32d_inst(
            .clka       (       clk             ),
            .wea        (       wea             ),
            .addra      (       addra           ),
            .dina       (       dina            ),
            .clkb       (       clk             ),
            .addrb      (       addrb           ),
            .doutb      (       doutb_fake      )
        );
    end
    else if(RAM_WIDTH == 24 && RAM_DEPTH == 256) begin : GEN_BRAM_SDP_24W_256D
        BRAM_SDP_24w_256d BRAM_SDP_24w_256d_inst(
            .clka       (       clk             ),
            .wea        (       wea             ),
            .addra      (       addra           ),
            .dina       (       dina            ),
            .clkb       (       clk             ),
            .addrb      (       addrb           ),
            .doutb      (       doutb_fake      )
        );
    end 
endgenerate

always @(posedge clk or posedge rst) begin
    if(rst) begin
        wea_diff <= 'd0;
        addra_diff <= 'd0;
        dina_diff <= 'd0;

        addrb_diff <= 'd0;
    end
    else begin
        wea_diff <= wea;
        addra_diff <= addra;
        dina_diff <= dina;

        addrb_diff <= addrb;
    end
end

assign doutb = (wea_diff && (addra_diff == addrb_diff)) ? dina_diff : doutb_fake;

/*Debug subsystem : Begin*/
`ifdef DEBUG_ON

`endif
/*Debug subsystem : End*/


endmodule
