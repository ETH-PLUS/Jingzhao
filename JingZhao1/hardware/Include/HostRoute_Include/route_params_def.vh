`define 	TD

/*Port mode*/
`define 	HPC_MODE 					1'b0
`define 	ETH_MODE 					1'b1

/*Work mode*/
`define 	TRANSPARENT					1'b0
`define 	RELAY 						1'b1

`define PASS_THROUGH_MODE	0
`define P2P_MODE			1

/*Debug*/
`define DBG_NUM_ROUTE_SUBSYS 			32'd256

/*Command and resp offset*/
`define 	REQ_OPCODE_START			32'd0
`define 	REQ_OPCODE_END				32'd7
`define 	REQ_OPCODE_WIDTH			32'd8
`define 	DLID_START 					32'd16
`define 	DLID_END 					32'd31
`define 	QPN_START 					32'd32
`define 	QPN_END 					32'd55
`define 	DMAC_START 					32'd16
`define 	DMAC_END					32'd63
`define 	SMAC_START 					32'd64
`define 	SMAC_END					32'd111
`define 	VLAN_START 					32'd112
`define 	VLAN_END 					32'd123
`define 	PORT_START 					32'd124
`define 	PORT_END 					32'd127
	
`define 	RESP_OPCODE_START			32'd0
`define 	RESP_OPCODE_END 			32'd7
`define 	RESP_OPCODE_WIDTH			32'd8
`define 	PORT_BITMAP_WIDTH 			32'd16
`define 	PORT_BITMAP_START 			32'd8
`define 	PORT_BITMAP_END 			32'd23
`define 	LEARNIG_STATE_WIDTH 		32'd8

`define 	HPC_ADDR_WIDTH				32'd16
`define 	ETH_ADDR_WIDTH				32'd48

`define 	ROUTE_REQ_WIDTH				32'd128
`define 	ROUTE_RESP_WIDTH			32'd32
`define 	RANGE_WIDTH					32'd6
`define 	SIZE_WIDTH 					32'd6
	
`define 	QPN_WIDTH 					32'd24
	
`define 	INNER_ADDR_WIDTH			32'd3

/*Command and resp opcode*/
`define 	HPC_STATIC_SP_DOR			8'd1
`define 	HPC_STATIC_MP_DOR			8'd2
`define 	HPC_DYNAMIC_MP_DOR			8'd3
`define 	HPC_TABLE_LOOKUP			8'd4
`define 	ETH_LOOKUP_WITHOUT_VLAN		8'd5
`define 	ETH_LOOKUP_WITH_VLAN 		8'd6
`define 	ADD_ROUTE 					8'd7
`define 	DELETE_ROUTE 				8'd8

`define 	UNICAST 					8'd1
`define 	MULTICAST 					8'd2
`define 	BROADCAST 					8'd3
`define 	NO_ROUTE 					8'd4

`define 	NEW_LEARNING				8'hFF
`define 	DUP_LEARNING				8'h00


/*Dimension-related postision and offset*/
`define 	W_INC_PORT_INDEX			4'd8 		//Port 8 means this output port will increase W address
`define 	W_DEC_PORT_INDEX 			4'd9 		//Port 9 means this output port will decrease W address
`define 	X_INC_PORT_INDEX 			4'd10
`define 	X_DEC_PORT_INDEX 			4'd11
`define 	Y_INC_PORT_INDEX 			4'd12
`define 	Y_DEC_PORT_INDEX 			4'd13
`define 	Z_INC_PORT_INDEX 			4'd14
`define 	Z_DEC_PORT_INDEX 			4'd15

`define 	W_AVAILABLE_POS				3'd0
`define 	W_DIRECTION_POS				3'd1
`define 	X_AVAILABLE_POS				3'd2
`define 	X_DIRECTION_POS				3'd3
`define 	Y_AVAILABLE_POS				3'd4
`define 	Y_DIRECTION_POS				3'd5
`define 	Z_AVAILABLE_POS				3'd6
`define 	Z_DIRECTION_POS				3'd7
	
`define 	DIM_AVA						1'b1 	//Dimension Available
`define 	DIM_NOT_AVA					1'b0 	//Dimension Not Available 
`define 	DIR_INC 					1'b1 	//Direction Increase
`define 	DIR_DEC 					1'b0 	//Direction Decrease 	
	
`define 	W_SELECTED					2'b00
`define 	X_SELECTED		 			2'b01
`define 	Y_SELECTED		 			2'b10
`define 	Z_SELECTED		 			2'b11 
	
`define 	LOCAL_0_SELECTED			3'b000
`define 	LOCAL_1_SELECTED			3'b001
`define 	LOCAL_2_SELECTED			3'b010
`define 	LOCAL_3_SELECTED			3'b011
`define 	LOCAL_4_SELECTED			3'b100
`define 	LOCAL_5_SELECTED			3'b101
`define 	LOCAL_6_SELECTED			3'b110
`define 	LOCAL_7_SELECTED			3'b111	

/*VLAN-Related*/
`define 	TPID						16'h8100

/*Table Lookup Related Params*/
`define 	TABLE_DEPTH_LOG_2			16'd2		//4 Entries
//`define 	TABLE_DEPTH_LOG_2			16'd12		//4K Entries
`define 	HIGHER_HPC_ADDR_WIDTH		16'd4 		//16 - 12
`define 	HIGHER_ETH_ADDR_WIDTH 		16'd36 		//48 - 12
`define 	VLAN_ID_WIDTH 				16'd12		//IEEE 802.1Q Format
`define 	PORT_INDEX_WIDTH 			16'd4
`define 	ENTRY_VALID_WIDTH 			16'd1
`define 	ENTRY_VALID_POS 			16'd0
`define 	PORT_INDEX_POS_START		16'd1
`define 	PORT_INDEX_POS_END 			16'd4
`define 	VLAN_ID_POS_START 			16'd5
`define  	VLAN_ID_POS_END 			16'd16
`define 	HIGHER_HPC_ADDR_POS_START	16'd17
`define 	HIGHER_HPC_ADDR_POS_END 	16'd20
`define 	HIGHER_ETH_ADDR_POS_START	16'd17
`define 	HIGHER_ETH_ADDR_POS_END 	16'd52
`define 	TABLE_INDEX_POS_START		16'd16
`define 	TABLE_INDEX_POS_END 		16'd27

`define 	ENTRY_VALID 				1'b1
`define 	ENTRY_INVALID 				1'b0

/*Spanning Tree Protocol*/
`define 	ROOT_BRIDGE 							//root bridge is the bridge which has the lowest bridge id, 
													//which is the root of the spanning tree, each LAN has only one root bridge
`define 	NON_ROOT_BRIDGE
`define 	DESIGNATED_BRIDGE						//Each physical connection between two bridges is called a network segment, 
													//each segment elected a designated bridge, which is nearer to the root bridge
`define 	ROOT_PORT 					4'd0		//each non-root bridge has only one root port, this port has the lowest cost when accessing the root bridge
`define 	DESIGNATED_PORT				4'd1		//each designated port is the port on the designated bridge in a specific network segment
													//for root bridge, all ports are designated ports
`define 	ALTERNATE_PORT 				4'd2		//All other ports except root ports and designated ports are called alternate ports, 
													//these ports are blocked, thry do not relay any packet


`define 	PORT_STATE_DISABLE			4'd0			//Port not available 
`define 	PORT_STATE_BLOCKING			4'd1			//Port can receive BPDU but can not relay BPDU
`define 	PORT_STATE_LISTENING		4'd2			//Generate and relay BPDU to construct a STP
`define 	PORT_STATE_LEARNING			4'd3			//STP already constructed, try to construct forwarding database
`define 	PORT_STATE_FORWARDING 		4'd4			//Normal forwarding 

`define 	BPDU_LENGTH 				32'd280		//35Byte	
`define 	PROTOCOL_ID_START			32'd0
`define 	PROTOCOL_ID_END				32'd15
`define 	VERSION_START				32'd16
`define 	VERSION_END					32'd23				
`define 	MESSAGE_TYPE_START			32'd24 
`define 	MESSAGE_TYPE_END			32'd31
`define 	FLAG_START					32'd32
`define 	FLAG_END					32'd39
`define 	ROOT_ID_START				32'd40
`define 	ROOT_ID_END					32'd103
`define 	ROOT_PATH_COST_START		32'd104
`define 	ROOT_PATH_COST_END			32'd135
`define 	BRIDGE_ID_START				32'd136
`define 	BRIDGE_ID_END				32'd199
`define 	PORT_ID_START 				32'd200
`define 	PORT_ID_END 				32'd215
`define 	MESSAGE_AGE_START 			32'd216
`define 	MESSAGE_AGE_END 			32'd231
`define 	MAX_AGE_START 				32'd232
`define 	MAX_AGE_END 				32'd247
`define 	HELLO_TIME_START 			32'd248
`define 	HELLO_TIME_END 				32'd263
`define 	FORWARD_DELAY_START 		32'd264
`define 	FORWARD_DELAY_END 			32'd279

`define 	PORT_8						16'd8	
`define 	PORT_9						16'd9	
`define 	PORT_10						16'd10
`define 	PORT_11						16'd11
`define 	PORT_12						16'd12
`define 	PORT_13						16'd13
`define 	PORT_14						16'd14
`define 	PORT_15						16'd15

`define 	ZERO_LINK_COST 				32'd0
`define 	DEFAULT_PROTOCOL_ID			16'd0
`define 	DEFAULT_PROTOCOL_VERSION	8'd0
`define 	DEFAULT_BPDU_TYPE			8'd0
`define 	DEFAULT_FLAGS 				8'd0
`define 	DEFAULT_ROOT_ID 			64'd0
`define 	DEFAULT_ROOT_PATH_COST		32'd0
`define 	DEFAULT_BRIDGE_ID 			64'd0
`define 	DEFAULT_PORT_ID 			16'd0
`define 	DEFAULT_MESSAGE_AGE			16'd0
`define 	DEFAULT_MAX_AGE 			16'd0 
`define 	DEFAULT_HELLO_TIME 			16'd0
`define 	DEFAULT_FORWARD_DELAY 		16'd0

`define 	DEFAULT_LINK_COST 			32'd2

`define 	BPDU_PKT 					8'hAA
`define 	MAC_ENTRY_PKT 				8'hFF

`define 	DEFAULT_ROOT_PORT 			4'd15

`define 	HEARTBEAT_THRESHOLD 		32'd65536
`define 	STATE_TRANS_THRESHOLD 		32'd65536

`define 	RING_BUS_DATA_WIDTH			128

`define 	ETH_ARP 					16'h0806
`define 	ETH_IP 						16'h0800
`define 	ETH_VLAN 					16'h8100
`define  	ADDR_BPDU 					48'h0180C2000000

`define 	TYPE_ARP 					16'h0806
`define 	TYPE_IPV4					16'h0800
`define 	TYPE_IPV6 					16'h86DD
`define 	TPID_VLAN 					16'h8100

/*Route Mode*/
`define 	STATIC_SP_DOR				4'd1
`define 	STATIC_MP_DOR				4'd2
`define 	DYNAMIC_MP_DOR				4'd3
`define 	TABLE_LOOKUP				4'd4

`define 	XBAR_UNICAST				1'b0
`define 	XBAR_MULTICAST				1'b1

`define 	HPC_LINK_HEADER_LENGTH 		16'd8
`define 	HPC_LINK_ICRC_LENGTH 		16'd4

`define 	PORT_STATE_WIDTH 			32'd4
`define 	PORT_MODE_WIDTH 			32'd1
`define 	WORK_MODE_WIDTH 			32'd1
`define 	PORT_ROUTE_MODE_WIDTH 		32'd4

`define 	XBAR_DATA_WIDTH 			32'd148
`define 	XBAR_BITMAP_WIDTH 			32'd16
`define 	XBAR_READY_WIDTH 			32'd36
`define     XBAR_COUNT_WIDTH 			32'd11

`define 	VL_BUFFER_DATA_WIDTH 			32'd176
`define 	VL_BUFFER_BITMAP_WIDTH 			32'd16
`define 	VL_BUFFER_READY_WIDTH 			32'd36
`define     VL_BUFFER_COUNT_WIDTH 			32'd11

`define 	WRITE_ENABLE 				1'b1
`define 	WRITE_DISABLE 				1'b0
`define 	READ_ENABLE 				1'b1
`define 	READ_DISABLE 				1'b0

`define 	LINK_LAYER_DATA_WIDTH 		32'd128
`define 	LINK_LAYER_KEEP_WIDTH 		32'd16
`define 	LINK_LAYER_USER_WIDTH		32'd8

`define 	HOST_ROUTE_DATA_WIDTH 		32'd256
`define 	HOST_ROUTE_KEEP_WIDTH 		32'd32
`define 	HOST_ROUTE_USER_WIDTH		32'd7
`define 	INNER_USER_WIDTH 			32'd16

`define  	ROUTE_INNER_KEEP_WIDTH 		32'd4

`define 	LINK_PACKET_LENGTH_WIDTH 	32'd7
`define 	LINK_PACKET_WIDTH 			32'd128

`define 	DATA_VALID 					1'b1
`define 	DATA_INVALID 				1'b0

`define 	RAM_ENABLE 					1'b1
`define 	RAM_DISABLE 				1'b0

`define 	ROCE_DESCRIPTOR_WIDTH 			32'd192

`define 	NIC_DATA_WIDTH 				32'd256
`define 	NIC_KEEP_WIDTH 				32'd5


