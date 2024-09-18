`define REG_BASE_ADDR_host    24'h10_0000
`define RW_REG_NUM_host       141
`define RO_BASE_ADDR_host     24'h30_0000
`define RO_REG_NUM_host       138
`define BUS_BASE_ADDR_host    24'h70_0000
`define BUS_ADDR_WIDTH_host   0

`define REG_BASE_ADDR_cnct   24'h20_0000
`define RW_REG_NUM_cnct      5
`define RO_BASE_ADDR_cnct    24'h40_0000
`define RO_REG_NUM_cnct      4
`define BUS_BASE_ADDR_cnct   24'h50_0000
`define BUS_ADDR_WIDTH_cnct  8


///instantiate in host_top module
/*
`include "cfg_slave_def.vh"

cfg_slave #(
	.REG_BASE_ADDR (`REG_BASE_ADDR_host ),
	.RW_REG_NUM    (`RW_REG_NUM_host    ),
	.RO_BASE_ADDR  (`RO_BASE_ADDR_host  ), 
	.RO_REG_NUM    (`RO_REG_NUM_host    ),
	.BUS_BASE_ADDR (`BUS_BASE_ADDR_host ), 
	.BUS_ADDR_WIDTH(`BUS_ADDR_WIDTH_host), 
	.APB_SEL(1'b0)
) u_cfg_slave(
	...
	...
	...
)
*/

///instantiate in cnct_top module
/*
`include "cfg_slave_def.vh"

cfg_slave #(
	.REG_BASE_ADDR (`REG_BASE_ADDR_cnct ), 
	.RW_REG_NUM    (`RW_REG_NUM_cnct    ), 
	.RO_BASE_ADDR  (`RO_BASE_ADDR_cnct  ), 
	.RO_REG_NUM    (`RO_REG_NUM_cnct    ), 
	.BUS_BASE_ADDR (`BUS_BASE_ADDR_cnct ), 
	.BUS_ADDR_WIDTH(`BUS_ADDR_WIDTH_cnct),
	.APB_SEL(1'b1)
) u_cfg_slave(
	...
	...
	...
)
*/
