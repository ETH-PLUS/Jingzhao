`define FPGA

`ifdef CFG_NODE_DEF_VH
`else
	`define CFG_NODE_DEF_VH

/****link_top module cfg param******/
	`define IB_ID_LINK           6'd1
//node start offset 24'h00_0000

	`define REG_BASE_ADDR_LINK   24'h01_0000
	`define RW_REG_NUM_LINK      20
	`define RO_BASE_ADDR_LINK    24'h02_0000
	`define RO_REG_NUM_LINK      27
	`define BUS_BASE_ADDR_LINK   24'h03_0000
	`define BUS_ADDR_WIDTH_LINK  8


/****ProtocolEngine_Top module cfg param******/
	`define IB_ID_PET           6'd2
//node start offset 24'h40_0000
	
	`define REG_BASE_ADDR_PET   24'h40_0000
	//`define RW_REG_NUM_PET      
	`define RO_BASE_ADDR_PET    24'h41_0000
	//`define RO_REG_NUM_PET      
	`define BUS_BASE_ADDR_PET   24'h42_0000
	`define BUS_ADDR_WIDTH_PET  1

/****pcie_subsys apb cfg param******/
	`define IB_ID_PCIE         6'd3 
//node start offset 24'h80_0000


/****eth_subsys apb cfg param******/
	`define IB_ID_ETH          6'd4
//offset 24'hC0_0000


//	`ifndef SIMULATION
//		`ifndef PCIEI_APB_DBG
//			`define PCIEI_APB_DBG
//		`endif
//	`endif


`endif
