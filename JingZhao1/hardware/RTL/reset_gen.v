`timescale 1ns / 100ps
//*************************************************************************
// > File Name   : reset_gen.v
// > Description : reset generator module, used to generate global and app 
// >               used reset signal
// > Author      : Corning
// > Date        : 2021-09-08
// > 
//*************************************************************************


module reset_gen (
    input      sys_clk     ,

    input      user_reset  ,
    input      user_lnk_up ,
    input      user_app_rdy,
    input      sys_rst_n   ,
    input      cmd_rst     ,

    output     glbl_rst    ,
    output     app_rst 
);

wire vio_reset;
wire sys_rst_n_c;

wire glbl_rst_in;
wire app_rst_in ;

assign glbl_rst_in = ~sys_rst_n_c;
assign app_rst_in  = user_reset | ~(user_lnk_up & user_app_rdy) | vio_reset; // 

vio_rst vio_rst (
  .clk        ( sys_clk  ), // input wire clk
  .probe_out0 ( vio_reset)  // output wire [0 : 0] probe_out0
);

IBUF sys_reset_n_ibuf (
    .O( sys_rst_n_c ), 
    .I( sys_rst_n   ) 
);

BUFG BUFG_inst1 (
  .O( glbl_rst    ), // 1-bit output: Reset output
  .I( glbl_rst_in )  // 1-bit input: Reset input
);

BUFG BUFG_inst2 (
  .O( app_rst    ), // 1-bit output: Reset output
  .I( app_rst_in )  // 1-bit input: Reset input
);

endmodule