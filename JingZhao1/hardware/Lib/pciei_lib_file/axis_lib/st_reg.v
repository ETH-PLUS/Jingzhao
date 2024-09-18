`timescale 1ns / 100ps
//*************************************************************************
// > File Name: st_reg.v
// > Author   : Kangning
// > Date     : 2022-07-18
// > Note     : A general module used to temporarily store the input 
// >            axis-like signal for one cycle.
//*************************************************************************


module st_reg #(
    parameter TUSER_WIDTH = 128,
    parameter TDATA_WIDTH = 256,
    parameter MODE        = 0  // The default mode is 0
) (
    input wire clk   , // i, 1
    input wire rst_n , // i, 1

    /* -------input axis-like interface{begin}------- */
    input  wire                   axis_tvalid , // i, 1
    input  wire                   axis_tlast  , // i, 1
    input  wire [TUSER_WIDTH-1:0] axis_tuser  , // i, TUSER_WIDTH
    input  wire [TDATA_WIDTH-1:0] axis_tdata  , // i, TDATA_WIDTH
    output wire                   axis_tready , // o, 1
    /* -------input axis-like interface{end}------- */

    /* -------output in_reg inteface{begin}------- */
    output wire                    axis_reg_tvalid,  // read valid from input register
    output wire                    axis_reg_tlast , 
    output wire  [TUSER_WIDTH-1:0] axis_reg_tuser ,
    output wire  [TDATA_WIDTH-1:0] axis_reg_tdata ,
    input  wire                    axis_reg_tready

    // input wire                    is_tuser_clear, // Optional, clear the present tuser.
    //                                               // Usually, it is asserted when 
    //                                               // *_valid & *_ready & *_last 
    // output reg                    axis_reg_sop   // Indicate the start of a pkt
    /* -------output in_reg inteface{end}------- */
);

wire                    axis_out_tlast; 
wire  [TUSER_WIDTH-1:0] axis_out_tuser;
wire  [TDATA_WIDTH-1:0] axis_out_tdata;

`define 	GP_SLICE_BYPASS 		999

gp_slice_ml #(
	.NUM_LEVELS		(1				),
	.PAYLD_WIDTH	(1 + TUSER_WIDTH + TDATA_WIDTH ),
	.MODE			(MODE		   		),
	.SYNC_RESET		(0				)
)	u_gp_slice_ml_PE (
	.clk   ( clk   ),
	.rst_n ( rst_n ),

	.vld_m   ( axis_tvalid     ),
	.rdy_m   ( axis_tready     ),
	.payld_m ( {axis_tlast, axis_tuser, axis_tdata} ),
	.vld_s   ( axis_reg_tvalid ),
	.rdy_s   ( axis_reg_tready ),
	.payld_s ( {axis_out_tlast, axis_out_tuser, axis_out_tdata} )
);
assign {axis_reg_tlast, axis_reg_tuser, axis_reg_tdata} = axis_reg_tvalid ? {axis_out_tlast, axis_out_tuser, axis_out_tdata} : {1 + TUSER_WIDTH + TDATA_WIDTH{1'd0}};

// /* -------in_reg logic{begin}------- */
// always @(posedge clk, negedge rst_n) begin
//     if (~rst_n) begin
//         axis_reg_sop  <= `TD 1;
//     end
//     else if (axis_tvalid & axis_tready & axis_tlast) begin
//         axis_reg_sop  <= `TD 1;
//     end
//     else if (axis_tvalid & axis_tready & axis_reg_sop) begin
//         axis_reg_sop  <= `TD 0;
//     end
// end

// always @(posedge clk, negedge rst_n) begin
//     if (~rst_n) begin
//         axis_reg_tuser <= `TD 0;
//     end
//     else if (axis_tvalid & axis_tready & axis_reg_sop) begin
//         axis_reg_tuser <= `TD axis_tuser;
//     end
//     else if (is_tuser_clear) begin // after trans finished, axis_reg_tuser is set to 0
//         axis_reg_tuser <= `TD 0;
//     end
// end

// always @(posedge clk, negedge rst_n) begin
//     if (~rst_n) begin
//         axis_reg_tvalid <= `TD 0;
//         axis_reg_tlast  <= `TD 0;
//         axis_reg_tdata  <= `TD 0;
//     end
//     else if (axis_tvalid & axis_tready) begin // write en & not full
//         axis_reg_tvalid <= `TD 1;
//         axis_reg_tlast  <= `TD axis_tlast;
//         axis_reg_tdata  <= `TD axis_tdata;
//     end
//     else if (axis_reg_tready & axis_reg_tvalid) begin // read en & not empty
//         axis_reg_tvalid <= `TD 0;
//         axis_reg_tlast  <= `TD 0;
//         axis_reg_tdata  <= `TD 0;
//     end
// end

// assign axis_tready  = !axis_reg_tvalid | axis_reg_tready; // empty | going to empty
// /* -------in_reg logic{end}------- */

endmodule
