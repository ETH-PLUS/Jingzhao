`timescale 1ns / 100ps

module stream_fifo #(
    TUSER_WIDTH = 128,
    TDATA_WIDTH = 256,
    TKEEP_WIDTH = TDATA_WIDTH / 8
) (
    input wire clk   , // i, 1
    input wire rst , // i, 1

    /* -------input axis-like interface{begin}------- */
    input  wire                   axis_tvalid , // i, 1
    input  wire                   axis_tlast  , // i, 1
    input  wire [TUSER_WIDTH-1:0] axis_tuser  , // i, TUSER_WIDTH
    input  wire [TDATA_WIDTH-1:0] axis_tdata  , // i, TDATA_WIDTH
    output wire                   axis_tready , // o, 1
    input   wire                    axis_tstart,
    input   wire [TKEEP_WIDTH-1:0] axis_tkeep,

    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    output wire                    in_reg_tvalid,  // read valid from input register
    output wire                    in_reg_tlast , 
    output wire  [TUSER_WIDTH-1:0] in_reg_tuser ,
    output wire  [TDATA_WIDTH-1:0] in_reg_tdata ,
    output wire  [TKEEP_WIDTH-1:0] in_reg_tkeep ,
    output wire                      in_reg_tstart,
    input wire                    in_reg_tready
    /* -------output in_reg inteface{end}------- */
);

wire                                                                                    payload_wr_en;
wire                [(TDATA_WIDTH + 1 + 1) - 1 : 0]                                     payload_din;
wire                                                                                    payload_prog_full;
wire                                                                                    payload_rd_en;
wire                [(TDATA_WIDTH + 1 + 1) - 1 : 0]                                     payload_dout;
wire                                                                                    payload_empty;

wire                                                                                    header_wr_en;
wire                [TUSER_WIDTH - 1 : 0]                                               header_din;
wire                                                                                    header_prog_full;
wire                                                                                    header_rd_en;
wire                [TUSER_WIDTH - 1 : 0]                                               header_dout;
wire                                                                                    header_empty;

assign payload_wr_en = axis_tvalid && axis_tready;
assign payload_din = {axis_tlast, axis_tstart, axis_tdata};

assign header_wr_en = axis_tvalid && axis_tready;
assign header_din = axis_tuser;

assign axis_tready = !header_prog_full && !payload_prog_full;

assign header_rd_en = in_reg_tready && !header_empty;
assign payload_rd_en = in_reg_tready && !payload_empty;

SyncFIFO_Template #(
    .FIFO_WIDTH                 (   TUSER_WIDTH         ),
    .FIFO_DEPTH                 (   16                  )
)
HeaderFIFO
(
    .clk                        (   clk                 ),
    .rst                        (   rst                 ),

    .wr_en                      (   header_wr_en        ),
    .din                        (   header_din          ),
    .prog_full                  (   header_prog_full    ),
    .rd_en                      (   header_rd_en        ),
    .dout                       (   header_dout         ),
    .empty                      (   header_empty        ),
    .data_count                 (                       )
);

SyncFIFO_Template #(
    .FIFO_WIDTH                 (   TDATA_WIDTH + 1 + 1 ),
    .FIFO_DEPTH                 (   16                  )
)
PayloadFIFO
(
    .clk                        (   clk                 ),
    .rst                        (   rst                 ),

    .wr_en                      (   payload_wr_en       ),
    .din                        (   payload_din         ),
    .prog_full                  (   payload_prog_full   ),
    .rd_en                      (   payload_rd_en       ),
    .dout                       (   payload_dout        ),
    .empty                      (   payload_empty       ),
    .data_count                 (                       )
);

assign  in_reg_tvalid = !header_empty && !payload_empty;
assign 	in_reg_tstart = in_reg_tvalid ? payload_dout[TDATA_WIDTH] : 'd0;
assign 	in_reg_tlast = in_reg_tvalid ? payload_dout[TDATA_WIDTH + 1] : 'd0;
assign 	in_reg_tkeep = 'd0;
assign 	in_reg_tuser = in_reg_tvalid ? header_dout : 'd0;
assign 	in_reg_tdata = in_reg_tvalid ? payload_dout : 'd0;

endmodule
