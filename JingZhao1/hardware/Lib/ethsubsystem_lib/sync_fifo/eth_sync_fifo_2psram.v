
module eth_sync_fifo_2psram 
#(
    parameter DATA_WIDTH  = 88,
    parameter FIFO_DEPTH  = 1024,
    parameter ADDR_WIDTH  = log2b(FIFO_DEPTH-1), 
    parameter DEPTH_WIDTH = log2b(FIFO_DEPTH) 
    // ,parameter RAM_NUM = DATA_WIDTH == 257 && FIFO_DEPTH == 512 ? 2  :
    //                     DATA_WIDTH == 289 && FIFO_DEPTH == 512 ? 3  : 1

)
(
    input                       clk,
    input                       rst_n,

    input                       wr_en,
    input  [DATA_WIDTH-1:0]     din,
    output                      full,
    output                      progfull,

    input                       rd_en,
    output [DATA_WIDTH-1:0]     dout,
    output                      empty,
    // input  [6:0]                sram_pin_ctrl,
    output [DEPTH_WIDTH-1:0]    empty_entry_num,
    output [DEPTH_WIDTH-1:0]    count

    ,input 	wire 	[32 - 1 : 0]	rw_data
);

reg                     wr_en_diff;
reg [DATA_WIDTH-1:0]     din_diff;

always@(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    wr_en_diff  <= `TD 0;
    din_diff  <= `TD 0;
  end else begin
    wr_en_diff  <= `TD wr_en;
    din_diff  <= `TD din;
  end
   
end

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


`ifdef FPGA_VERSION

wire        [ADDR_WIDTH : 0]        data_count;
assign empty_entry_num = FIFO_DEPTH - data_count;
assign count = data_count;

        if(DATA_WIDTH == 257 && FIFO_DEPTH == 512) begin:FIFO_512x257
            eth_sync_fifo_257W_512D eth_sync_fifo_257W_512D_inst (
              .clk(clk),               
              .srst(~rst_n),             
              .din(din_diff),                
              .wr_en(wr_en_diff),           
              .rd_en(rd_en),            
              .dout(dout),             
              .full(full),             
              .empty(empty),          
              .data_count(data_count), 
              .prog_full(progfull)   
            );
        end else if(DATA_WIDTH == 289 && FIFO_DEPTH == 512) begin:FIFO_512x289   
            eth_sync_fifo_289W_512D eth_sync_fifo_289W_512D_inst (
              .clk(clk),               
              .srst(~rst_n),             
              .din(din_diff),                
              .wr_en(wr_en_diff),           
              .rd_en(rd_en),            
              .dout(dout),             
              .full(full),             
              .empty(empty),          
              .data_count(data_count), 
              .prog_full(progfull)   
            );
        end else if(DATA_WIDTH == 16 && FIFO_DEPTH == 256) begin:FIFO_256x16
            eth_sync_fifo_16W_256D eth_sync_fifo_16W_256D_inst (
              .clk(clk),               
              .srst(~rst_n),             
              .din(din_diff),                
              .wr_en(wr_en_diff),           
              .rd_en(rd_en),            
              .dout(dout),             
              .full(full),             
              .empty(empty),          
              .data_count(data_count), 
              .prog_full(progfull)   
            );
        end else if(DATA_WIDTH == 32 && FIFO_DEPTH == 256) begin:FIFO_256x32
            eth_sync_fifo_32W_256D eth_sync_fifo_32W_256D_inst (
              .clk(clk),               
              .srst(~rst_n),             
              .din(din_diff),                
              .wr_en(wr_en_diff),           
              .rd_en(rd_en),            
              .dout(dout),             
              .full(full),             
              .empty(empty),          
              .data_count(data_count), 
              .prog_full(progfull)   
            );
        end else if(DATA_WIDTH == 24 && FIFO_DEPTH == 256) begin:FIFO_256x24
            eth_sync_fifo_24W_256D eth_sync_fifo_24W_256D_inst (
              .clk(clk),               
              .srst(~rst_n),             
              .din(din_diff),                
              .wr_en(wr_en_diff),           
              .rd_en(rd_en),            
              .dout(dout),             
              .full(full),             
              .empty(empty),          
              .data_count(data_count), 
              .prog_full(progfull)   
            );
        end else if(DATA_WIDTH == 16 && FIFO_DEPTH == 32) begin:FIFO_32x16
            eth_sync_fifo_16W_32D eth_sync_fifo_16W_32D_inst (
              .clk(clk),               
              .srst(~rst_n),             
              .din(din_diff),                
              .wr_en(wr_en_diff),           
              .rd_en(rd_en),            
              .dout(dout),             
              .full(full),             
              .empty(empty),          
              .data_count(data_count), 
              .prog_full(progfull)   
            );  
        end else if(DATA_WIDTH == 297 && FIFO_DEPTH == 8) begin:FIFO_8x297
            eth_sync_fifo_297W_8D eth_sync_fifo_297W_8D_inst (
              .clk(clk),               
              .srst(~rst_n),             
              .din(din_diff),                
              .wr_en(wr_en_diff),           
              .rd_en(rd_en),            
              .dout(dout),             
              .full(full),             
              .empty(empty),          
              .data_count(data_count), 
              .prog_full(progfull)   
            );  
        end else if(DATA_WIDTH == 1 && FIFO_DEPTH == 8) begin:FIFO_8x1
            eth_sync_fifo_1W_8D eth_sync_fifo_1W_8D_inst (
              .clk(clk),               
              .srst(~rst_n),             
              .din(din_diff),                
              .wr_en(wr_en_diff),           
              .rd_en(rd_en),            
              .dout(dout),             
              .full(full),             
              .empty(empty),          
              .data_count(data_count), 
              .prog_full(progfull)   
            );  
        end else if(DATA_WIDTH == 289 && FIFO_DEPTH == 8) begin:FIFO_8x289
            eth_sync_fifo_289W_8D eth_sync_fifo_289W_8D_inst (
              .clk(clk),               
              .srst(~rst_n),             
              .din(din_diff),                
              .wr_en(wr_en_diff),           
              .rd_en(rd_en),            
              .dout(dout),             
              .full(full),             
              .empty(empty),          
              .data_count(data_count), 
              .prog_full(progfull)   
            );  
        end
`else

`endif
endmodule 


