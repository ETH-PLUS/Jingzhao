`timescale  1ns / 1ps

`include "common_function_def.vh"

module SyncFIFO_Template #(
    parameter       FIFO_TYPE   = 0,    //0: Xilinx IP, 1: RegFiles
    parameter       FIFO_WIDTH  = 32,
    parameter       FIFO_DEPTH  = 32,
    parameter       COUNT_WIDTH = log2b(FIFO_DEPTH)
)
(
    input   wire                                clk,
    input   wire                                rst,

    input   wire                                wr_en,
    input   wire    [FIFO_WIDTH - 1 : 0]        din,
    output  wire                                prog_full,
    input   wire                                rd_en,
    output  wire    [FIFO_WIDTH - 1 : 0]        dout,
    output  wire                                empty,
    output  wire    [COUNT_WIDTH - 1 : 0]       data_count                        
);


generate
    if(FIFO_TYPE == 0) begin //Xilinx IP
        if(FIFO_WIDTH == 64 && FIFO_DEPTH == 128) begin : GEN_SYNC_FIFO_64W_128D
            SyncFIFO_64w_128d SyncFIFO_64w_128d_Inst(
                .clk(clk),
                .srst(rst),

                .wr_en(wr_en),
                .din(din),
                .prog_full(prog_full),
                .rd_en(rd_en),
                .dout(dout),
                .empty(empty),
                .data_count(data_count)
            );
        end
        else if(FIFO_WIDTH == 128 && FIFO_DEPTH == 16) begin : GEN_SYNC_FIFO_128W_16D
            SyncFIFO_128w_16d SyncFIFO_128w_16d_Inst(
                .clk(clk),
                .srst(rst),

                .wr_en(wr_en),
                .din(din),
                .prog_full(prog_full),
                .rd_en(rd_en),
                .dout(dout),
                .empty(empty),
                .data_count(data_count)
            );
        end
        else if(FIFO_WIDTH == 258 && FIFO_DEPTH == 16) begin : GEN_SYNC_FIFO_258W_16D
            SyncFIFO_258w_16d SyncFIFO_258w_16d_Inst(
                .clk(clk),
                .srst(rst),

                .wr_en(wr_en),
                .din(din),
                .prog_full(prog_full),
                .rd_en(rd_en),
                .dout(dout),
                .empty(empty),
                .data_count(data_count)
            );
        end
        else if(FIFO_WIDTH == 24 && FIFO_DEPTH == 256) begin : GEN_SYNC_FIFO_24W_256D
            SyncFIFO_24w_256d SyncFIFO_24w_256d_Inst(
                .clk(clk),
                .srst(rst),

                .wr_en(wr_en),
                .din(din),
                .prog_full(prog_full),
                .rd_en(rd_en),
                .dout(dout),
                .empty(empty),
                .data_count(data_count)
            );
        end
        else if(FIFO_WIDTH == 5 && FIFO_DEPTH == 32) begin : GEN_SYNC_FIFO_5W_32D
            SyncFIFO_5w_32d SyncFIFO_5w_32d_Inst(
                .clk(clk),
                .srst(rst),

                .wr_en(wr_en),
                .din(din),
                .prog_full(prog_full),
                .rd_en(rd_en),
                .dout(dout),
                .empty(empty),
                .data_count(data_count)
            );
        end
        else if(FIFO_WIDTH == 140 && FIFO_DEPTH == 32) begin : GEN_SYNC_FIFO_140W_32D
            SyncFIFO_140w_32d SyncFIFO_140w_32d_Inst(
                .clk(clk),
                .srst(rst),

                .wr_en(wr_en),
                .din(din),
                .prog_full(prog_full),
                .rd_en(rd_en),
                .dout(dout),
                .empty(empty),
                .data_count(data_count)
            );
        end
        else if(FIFO_WIDTH == 512 && FIFO_DEPTH == 64) begin : GEN_SYNC_FIFO_512W_64D
            SyncFIFO_512w_64d SyncFIFO_512w_64d_Inst(
                .clk(clk),
                .srst(rst),

                .wr_en(wr_en),
                .din(din),
                .prog_full(prog_full),
                .rd_en(rd_en),
                .dout(dout),
                .empty(empty),
                .data_count(data_count)
            );
        end
        else if(FIFO_WIDTH == 128 && FIFO_DEPTH == 64) begin : GEN_SYNC_FIFO_128W_64D
            SyncFIFO_128w_64d SyncFIFO_128w_64d_Inst(
                .clk(clk),
                .srst(rst),

                .wr_en(wr_en),
                .din(din),
                .prog_full(prog_full),
                .rd_en(rd_en),
                .dout(dout),
                .empty(empty),
                .data_count(data_count)
            );
        end
        else if(FIFO_WIDTH == 576 && FIFO_DEPTH == 32) begin : GEN_SYNC_FIFO_576W_32D
            SyncFIFO_576w_32d SyncFIFO_576w_32d_Inst(
                .clk(clk),
                .srst(rst),

                .wr_en(wr_en),
                .din(din),
                .prog_full(prog_full),
                .rd_en(rd_en),
                .dout(dout),
                .empty(empty),
                .data_count(data_count)
            );
        end
        else if(FIFO_WIDTH == 6 && FIFO_DEPTH == 64) begin : GEN_SYNC_FIFO_6W_64D
            SyncFIFO_6w_64d SyncFIFO_6w_64d_Inst(
                .clk(clk),
                .srst(rst),

                .wr_en(wr_en),
                .din(din),
                .prog_full(prog_full),
                .rd_en(rd_en),
                .dout(dout),
                .empty(empty),
                .data_count(data_count)
            );
        end
        else if(FIFO_WIDTH == 9 && FIFO_DEPTH == 512) begin : GEN_SYNC_FIFO_9W_512D
            SyncFIFO_9w_512d SyncFIFO_9w_512d_Inst(
                .clk(clk),
                .srst(rst),

                .wr_en(wr_en),
                .din(din),
                .prog_full(prog_full),
                .rd_en(rd_en),
                .dout(dout),
                .empty(empty),
                .data_count(data_count)
            );
        end
    end  
    else begin //Register File
        //Instantiate RegFile FIFO
        SyncFIFO_2Port_SRAM #(
            .DATA_WIDTH(FIFO_WIDTH),
            .FIFO_DEPTH(FIFO_DEPTH)
        )
        SyncFIFO_RegFile_Inst
        (
            .clk(clk),
            .rst(rst),

            .wr_en(wr_en),
            .din(din),
            .prog_full(prog_full),

            .rd_en(rd_en),
            .dout(dout),
            .empty(empty),
            .data_count(data_count)
        ); 
    end 
endgenerate

/*Debug subsystem : Begin*/
`ifdef DEBUG_ON

`endif
/*Debug subsystem : End*/

endmodule
