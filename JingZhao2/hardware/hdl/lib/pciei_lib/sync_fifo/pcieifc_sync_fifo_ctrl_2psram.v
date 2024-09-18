// sync FIFO controller which uses two-port SRAM as data array

module pcieifc_sync_fifo_ctrl_2psram #(
    parameter DATA_WIDTH  = 32'd10,
    parameter FIFO_DEPTH  = 4,
    parameter ADDR_WIDTH  = log2b(FIFO_DEPTH-1),    // local param, do not modify
    parameter DEPTH_WIDTH = log2b(FIFO_DEPTH)       // local param, do not modify
)
(
    input                           clk,
    input                           rst_n,
    input                           push,
    input                           pop,
    input  [DATA_WIDTH-1:0]         data_in,
    output [DATA_WIDTH-1:0]         data_out,
    output                          full,
    output                          empty,
    output     [DEPTH_WIDTH-1:0]    remain,     // This is inaccurate, and only indicates the remaining data count in sram
    output reg [DEPTH_WIDTH-1:0]    count,      // This is inaccurate, and only indicates the data count in sram
    output reg                      ovflow,
    output reg                      undflow,

    output                          sram_wr_cen,
    output [ADDR_WIDTH-1:0]         sram_wr_a,
    output [DATA_WIDTH-1:0]         sram_wr_d,

    output                          sram_rd_cen,
    output [ADDR_WIDTH-1:0]         sram_rd_a,
    input  [DATA_WIDTH-1:0]         sram_rd_q
);

assign remain = FIFO_DEPTH - count;

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

reg  [ADDR_WIDTH-1:0]   waddr;
reg  [ADDR_WIDTH-1:0]   raddr;

reg  [DATA_WIDTH-1:0]   rd_buf;
reg                     rd_buf_vld;
reg                     sram_q_vld;

assign sram_rd_cen = ~((count != {DEPTH_WIDTH{1'b0}}) & ((~sram_q_vld) & (~rd_buf_vld) |
                                                         (~sram_q_vld) & pop |
                                                         (~rd_buf_vld) & pop));
assign sram_rd_a   = raddr;

assign sram_wr_cen = ~((~full) & push);
assign sram_wr_a   = waddr;
assign sram_wr_d   = data_in;

assign data_out    = rd_buf_vld ? rd_buf : sram_rd_q;
assign empty       = ~(sram_q_vld | rd_buf_vld);
assign full        = (count == FIFO_DEPTH);

always @(posedge clk or negedge rst_n)
begin
    if (~rst_n) begin
        sram_q_vld <= `TD 1'b0;
    end
    else begin
        sram_q_vld <= `TD ~sram_rd_cen;
    end
end

always @(posedge clk or negedge rst_n)
begin
    if (~rst_n) begin
        rd_buf     <= `TD {DATA_WIDTH{1'b0}};
        rd_buf_vld <= `TD 1'b0;
    end
    else if (sram_q_vld & (~pop)) begin
        rd_buf_vld <= `TD 1'b1;
        rd_buf     <= `TD sram_rd_q;
    end
    else if (rd_buf_vld & pop) begin
        rd_buf_vld <= `TD 1'b0;
    end
end

always @(posedge clk or negedge rst_n)
begin
    if (~rst_n) begin
        waddr <= `TD {ADDR_WIDTH{1'b0}};
    end
    else if (~sram_wr_cen) begin
        if (waddr == FIFO_DEPTH - 1) begin
            waddr <= `TD {ADDR_WIDTH{1'b0}};
        end
        else begin
            waddr <= `TD waddr + {{ADDR_WIDTH-1{1'b0}}, 1'b1};
        end
    end
end

always @(posedge clk or negedge rst_n)
begin
    if (~rst_n) begin
        raddr <= `TD {ADDR_WIDTH{1'b0}};
    end
    else if (~sram_rd_cen) begin
        if (raddr == FIFO_DEPTH - 1) begin
            raddr <= `TD {ADDR_WIDTH{1'b0}};
        end
        else begin
            raddr <= `TD raddr + {{ADDR_WIDTH-1{1'b0}}, 1'b1};
        end
    end
end

always @(posedge clk or negedge rst_n)
begin
    if (~rst_n) begin
        count <= `TD {DEPTH_WIDTH{1'b0}};
    end
    else if ((~sram_wr_cen) & (~sram_rd_cen)) begin
        count <= `TD count;
    end
    else if (~sram_wr_cen) begin
        count <= `TD count + {{(DEPTH_WIDTH-1){1'b0}}, 1'h1};
    end
    else if (~sram_rd_cen) begin
        count <= `TD count - {{(DEPTH_WIDTH-1){1'b0}}, 1'h1};
    end
end

always @(posedge clk or negedge rst_n)
begin
    if (~rst_n) begin
        ovflow <= `TD 1'b0;
    end
    else if (push & full) begin
        ovflow <= `TD 1'b1;
    end
end

always @(posedge clk or negedge rst_n)
begin
    if (~rst_n) begin
        undflow <= `TD 1'b0;
    end
    else if (pop & empty) begin
        undflow <= `TD 1'b1;
    end
end

//synopsys translate_off
initial begin
    if (ADDR_WIDTH  != log2b(FIFO_DEPTH-1)) begin
        $display("\nFatal: ADDR_WIDTH must not be modified @(%m)\n");
        $finish;
    end
    if (DEPTH_WIDTH != log2b(FIFO_DEPTH)) begin
        $display("\nFatal: DEPTH_WIDTH must not be modified @(%m)\n");
        $finish;
    end
end
//synopsys translate_on

endmodule
