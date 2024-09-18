
module SyncFIFO_2Port_SRAM 
#(
    parameter DATA_WIDTH = 16,
    parameter FIFO_DEPTH = 16,
    parameter ADDR_WIDTH  = log2b(FIFO_DEPTH - 1), 
    parameter DEPTH_WIDTH = log2b(FIFO_DEPTH) 
)
(
    input   wire                                        clk,
    input   wire                                        rst,

    input   wire                                        wr_en,
    input   wire    [DATA_WIDTH - 1 : 0]                din,
    output  wire                                        prog_full,

    input   wire                                        rd_en,
    output  wire    [DATA_WIDTH - 1 : 0]                dout,
    output  wire                                        empty,
    output  wire    [DEPTH_WIDTH - 1 : 0]               data_count

);

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

wire  [DEPTH_WIDTH - 1 : 0]     empty_entry_num;

wire 						rst_n;
assign rst_n = !rst;

assign prog_full = (empty_entry_num < 3) ? 1'b1 : 1'b0;
assign data_count = (FIFO_DEPTH - empty_entry_num);

SyncFIFO_2Port_Ctrl_SRAM #(
    .DATA_WIDTH(DATA_WIDTH),
    .FIFO_DEPTH(FIFO_DEPTH)
) U_SyncFIFO_2Port_Ctrl_SRAM
(
    .clk(clk),
    .rst_n(rst_n),
    .push(wr_en),
    .pop(rd_en),
    .data_in(din),
    .data_out(dout),
    .full(),
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

SRAM_SDP_Model 
#(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .RAM_DEPTH(FIFO_DEPTH)
) U_sram_2port_model(
    .clk(clk),
    .rst(rst),	
    .sram_wr_cen(sram_wr_cen),
    .sram_wr_a(sram_wr_a),
    .sram_wr_d(sram_wr_d),
    .sram_rd_cen(sram_rd_cen),
    .sram_rd_a(sram_rd_a),
    .sram_rd_q(sram_rd_q)
);

endmodule 


