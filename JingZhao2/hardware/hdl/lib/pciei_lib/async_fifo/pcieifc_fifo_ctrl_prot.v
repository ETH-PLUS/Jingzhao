`timescale 1ns / 100ps
module pcieifc_fifo_ctrl_prot #(
    parameter ADDR_WIDTH    = 5     ,
    parameter FIFO_DEPTH    = 32'd32
) (
    input  wire                  fifo_clk  , // fifo clock supply
    input  wire                  fifo_rstn , // fifo async reset, active low
    input  wire                  fifo_clear, // pointer sync reset, active high
    input  wire                  fifo_inc  , // FIFO pointer increase indictor
    input  wire                  fifo_dir  , // 0: read, 1: write
    
    output wire                  fifo_cen  , // FIFO chip enable
    output wire [ADDR_WIDTH-1:0] fifo_addr , // FIFO address
    output wire                  fifo_full , // register out
    output wire                  fifo_empty, // register out

    input  wire [ADDR_WIDTH:0]   ptr_gray_other, // propagated gray pointer from other clock domain
    output  reg [ADDR_WIDTH:0]   ptr_bin       , // local binary pointer output
    output  reg [ADDR_WIDTH:0]   ptr_gray      , // local gray-coded pointer output
    output wire [ADDR_WIDTH:0]   ptr_bin_other   // binary conversed format of the propagated pointer
);

wire    fifo_full_c;
wire    fifo_empty_c;
reg     empty;

wire [ADDR_WIDTH:0]     max_depth;
wire [ADDR_WIDTH-1:0]   offset;

wire [ADDR_WIDTH:0]     ptr_gray_next; 
wire [ADDR_WIDTH:0]     ptr_bin_next;
    
// ------------------------------------------------------------------------------- 

assign max_depth = {1'b1, {ADDR_WIDTH{1'b0}}};  // max depth in theory
assign offset    = max_depth - FIFO_DEPTH;      // max depth - actual depth, 1 is default

// the non-2-power gray code sequence is generated based on a mirror line, as 
// long as the equal number of entries are removed on both side of the mirror 
// line, the desired offset gray code sequence can be gotten.
// ---------------------------------------------------------------------- //
// 16-count       14-count       12-count
// ---------------------------------------------------------------------- //
// 0000           0000           0000
// 0001           0001           0001
// 0011           0011           0011
// 0010           0010           0010
// 0110           0110           0110
// 0111           0111           0111
// 0101           0101           ----
// 0100           ----           ----
// ---------------------------------------- mirror line  //
// 1100           ----           ----
// 1101           1101           ----
// 1111           1111           1111
// 1110           1110           1110
// 1010           1010           1010
// 1011           1011           1011
// 1001           1001           1001
// 1000           1000           1000

function [ADDR_WIDTH:0]  bin2gray;
    input [ADDR_WIDTH:0]    bin;
    input [ADDR_WIDTH-1:0]  offset;
    reg   [ADDR_WIDTH:0] bin_adj;
    reg   [ADDR_WIDTH:0] gray;
    begin
        if (bin > FIFO_DEPTH)
            bin_adj = bin + {1'b0, offset};
        else
            bin_adj = bin;
        gray = bin_adj ^ (bin_adj >> 1);
        bin2gray = gray;
    end
endfunction // bin2gray

function [ADDR_WIDTH:0]  gray2bin;
    input [ADDR_WIDTH:0]    gray;
    input [ADDR_WIDTH-1:0]  offset;
    reg   [ADDR_WIDTH:0] bin_adj;
    reg   [ADDR_WIDTH:0] bin;
    integer              i;
    begin
        for (i=0; i<=ADDR_WIDTH; i=i+1)
            bin[i] = ^(gray >> i);
        if (bin > FIFO_DEPTH)
            bin_adj = bin - {1'b0, offset};
        else
            bin_adj = bin;
        gray2bin = bin_adj;
    end
endfunction // gray2bin

// ---------------------------------------------------------------------- 

assign ptr_bin_other = gray2bin(ptr_gray_other, offset);

// ----- gray and binary pointer increment ----- //
always @(posedge fifo_clk or negedge fifo_rstn) begin
    if (!fifo_rstn) begin
        ptr_bin  <= `TD {ADDR_WIDTH+1{1'b0}};
        ptr_gray <= `TD {ADDR_WIDTH+1{1'b0}};
    end
    else if (fifo_clear) begin
        ptr_bin  <= `TD {ADDR_WIDTH+1{1'b0}};
        ptr_gray <= `TD {ADDR_WIDTH+1{1'b0}};
    end
    else if (~fifo_cen) begin
        ptr_bin  <= `TD ptr_bin_next;
        ptr_gray <= `TD ptr_gray_next;
    end
end

assign ptr_bin_next  =  (ptr_bin[ADDR_WIDTH-1:0] == FIFO_DEPTH-1) ? 
                        {~ptr_bin[ADDR_WIDTH], {ADDR_WIDTH{1'b0}}} : (ptr_bin + 1'b1);

assign ptr_gray_next = bin2gray(ptr_bin_next, offset);

// ----- fifo full logic ----- //
assign fifo_full_c   = (ptr_bin == {~ptr_bin_other[ADDR_WIDTH], ptr_bin_other[ADDR_WIDTH-1:0]});

// ----- fifo empty logic ----- //
assign fifo_empty_c  = (ptr_bin == ptr_bin_other);
always @(posedge fifo_clk or negedge fifo_rstn) begin
    if (!fifo_rstn) begin
        empty <= `TD 1'b1;
    end
    else if (fifo_clear) begin
        empty <= `TD 1'b1;
    end
    else if (fifo_inc | fifo_empty) begin
        empty <= `TD fifo_empty_c;
    end
end

assign fifo_full  = fifo_full_c;
assign fifo_empty = empty;

// ----- memory interface ----- //
// when FIFO is full in write domain, the new write request won't be served until 
// FIFO isn't full; when FIFO is empty in read domain, the new read request won't 
// served until FIFO isn't empty.
assign fifo_cen  = fifo_dir ? 
                    (~fifo_inc | fifo_full_c) : 
                    ~(
                        (fifo_inc & !fifo_empty_c) | 
                        (fifo_empty & !fifo_empty_c)
                    );

assign fifo_addr = ptr_bin[ADDR_WIDTH-1:0];

endmodule
