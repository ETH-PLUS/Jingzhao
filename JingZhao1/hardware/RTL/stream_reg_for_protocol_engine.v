`timescale 1ns / 100ps

module stream_reg_for_protocol_engine #(
    TUSER_WIDTH = 128,
    TDATA_WIDTH = 256,
    TKEEP_WIDTH = TDATA_WIDTH / 8
) (
    input wire clk   , // i, 1
    input wire rst_n , // i, 1

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
    input wire                    in_reg_tready,

    input wire                    tuser_clear
    /* -------output in_reg inteface{end}------- */
);

//assign in_reg_tvalid = axis_tvalid;
//assign in_reg_tlast = axis_tlast;
//assign in_reg_tuser = axis_tuser;
//assign in_reg_tdata = axis_tdata;
//assign in_reg_tkeep = axis_tkeep;
//assign in_reg_tstart = axis_tstart;
//assign axis_tready = in_reg_tready;

wire 	[(TUSER_WIDTH + TDATA_WIDTH + TKEEP_WIDTH + 1 + 1) - 1 : 0]	payload_slave;

gp_slice_ml #(
	.NUM_LEVELS		(1				),
	.PAYLD_WIDTH	(TUSER_WIDTH + TDATA_WIDTH + TKEEP_WIDTH + 1 + 1),
	.MODE			(0				),
	.SYNC_RESET		(0				)
)	u_gp_slice_ml_PE (
	.clk(clk),
	.rst_n(rst_n),

	.vld_m(axis_tvalid),
	.rdy_m(axis_tready),
	.payld_m({axis_tstart, axis_tlast, axis_tkeep, axis_tuser, axis_tdata}),
	.vld_s(in_reg_tvalid),
	.rdy_s(in_reg_tready),
	.payld_s(payload_slave)
);

assign 	in_reg_tstart = in_reg_tvalid ? payload_slave[(TUSER_WIDTH + TDATA_WIDTH + TKEEP_WIDTH + 1 + 1) - 1] : 'd0;
assign 	in_reg_tlast = in_reg_tvalid ? payload_slave[(TUSER_WIDTH + TDATA_WIDTH + TKEEP_WIDTH + 1 + 1) - 2] : 'd0;
assign 	in_reg_tkeep = in_reg_tvalid ? payload_slave[(TUSER_WIDTH + TDATA_WIDTH + TKEEP_WIDTH) - 1 : (TUSER_WIDTH + TDATA_WIDTH)] : 'd0;
assign 	in_reg_tuser = in_reg_tvalid ? payload_slave[(TUSER_WIDTH + TDATA_WIDTH) - 1 : (TDATA_WIDTH)] : 'd0;
assign 	in_reg_tdata = in_reg_tvalid ? payload_slave[(TDATA_WIDTH) - 1 : 0] : 'd0;

endmodule
