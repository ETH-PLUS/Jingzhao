/*-------------------------------------------------- QP Property Parameters : Begin ---------------------------------------------*/
`define 	MAX_QP_NUM							16384
`define 	MAX_QP_NUM_LOG						16

`define 	MAX_CQ_NUM							16384
`define 	MAX_CQ_NUM_LOG						16

`define 	QP_NUM 								256
`define 	QP_NUM_LOG							8

`define 	CQ_NUM 								256
`define 	CQ_NUM_LOG							8

`define 	MAX_QUEUE_DEPTH 					8
`define 	MAX_QUEUE_DEPTH_LOG 				8

`define 	MAX_MSG_SIZE 						(1 << 31)
`define 	MAX_MSG_SIZE_LOG 					32

`define 	MAX_DMQ_SLOT_NUM 					8192
`define 	MAX_DMQ_SLOT_NUM_LOG				15

`define 	MAX_OOO_SLOT_NUM 					`MAX_DMQ_SLOT_NUM 	
`define 	MAX_OOO_SLOT_NUM_LOG				`MAX_DMQ_SLOT_NUM_LOG

`define 	MAX_DB_SLOT_NUM 					16384
`define 	MAX_DB_SLOT_NUM_LOG 				16
/*-------------------------------------------------- QP Property Parameters : End -----------------------------------------------*/		

/*----------------------------------------------------- ICMCache Parameters : Begin --------------------------------------------------*/
`define 	PAGE_SIZE 								4096

`define 	CACHE_SET_NUM_QPC						256
`define 	CACHE_SET_NUM_CQC 						256
`define 	CACHE_SET_NUM_EQC						16
`define 	CACHE_SET_NUM_MPT						512
//`define 	CACHE_SET_NUM_MPT 						2
`define 	CACHE_SET_NUM_MTT						4096
//`define 	CACHE_SET_NUM_MTT 						2 		//Test cache miss case

`define 	CACHE_TYPE_QPC							1
`define 	CACHE_TYPE_CQC 							2
`define 	CACHE_TYPE_EQC 							3			
`define 	CACHE_TYPE_MPT 							4
`define 	CACHE_TYPE_MTT 							5

//Actual cache entry width stored in NIC-SRAM
`define 	CACHE_ENTRY_WIDTH_QPC 				416
`define 	CACHE_ENTRY_WIDTH_CQC 				128
`define 	CACHE_ENTRY_WIDTH_EQC 				96
`define 	CACHE_ENTRY_WIDTH_MPT 				320
`define 	CACHE_ENTRY_WIDTH_MTT 				64

//Software allocated icm entry size
`define 	ICM_ENTRY_SIZE_QPC 					192
`define 	ICM_ENTRY_SIZE_CQC					64
`define 	ICM_ENTRY_SIZE_EQC					64
`define 	ICM_ENTRY_SIZE_MPT					64
`define 	ICM_ENTRY_SIZE_MTT					8

//Software allocated icm slot size
`define 	ICM_SLOT_SIZE_QPC 					256
`define 	ICM_SLOT_SIZE_CQC					128
`define 	ICM_SLOT_SIZE_EQC					128
`define 	ICM_SLOT_SIZE_MPT					64
`define 	ICM_SLOT_SIZE_MTT					8

//ICM entry num for each resource
`define 	ICM_ENTRY_NUM_MTT					(4 * 1024 * 1024)	//Cover 16GB host memory
`define 	ICM_ENTRY_NUM_MPT					(512 * 1024) 		//Cover 512K Memory Region
`define 	ICM_ENTRY_NUM_QPC					(16 * 1024)			//Cover 16K QPs
`define 	ICM_ENTRY_NUM_CQC					(16 * 1024)			//Cover 16K CQs
`define 	ICM_ENTRY_NUM_EQC					32					//Cover 32 EQs

//ICM size for each resource
`define 	ICM_SIZE_MTT						`ICM_SLOT_SIZE_MTT * `ICM_ENTRY_NUM_MTT
`define 	ICM_SIZE_MPT						`ICM_SLOT_SIZE_MPT * `ICM_ENTRY_NUM_MPT
`define 	ICM_SIZE_QPC						`ICM_SLOT_SIZE_QPC * `ICM_ENTRY_NUM_QPC
`define 	ICM_SIZE_CQC						`ICM_SLOT_SIZE_CQC * `ICM_ENTRY_NUM_CQC
`define 	ICM_SIZE_EQC						`ICM_SLOT_SIZE_EQC * `ICM_ENTRY_NUM_EQC

//ICM page num for each resources
//`define 	ICM_PAGE_NUM_MTT					((`ICM_SLOT_SIZE_MTT * `ICM_ENTRY_NUM_MTT / `PAGE_SIZE) + (`ICM_SLOT_SIZE_MTT * `ICM_ENTRY_NUM_MTT) % //`PAGE_SIZE ? 1 : 0)
//`define 	ICM_PAGE_NUM_MPT					((`ICM_SLOT_SIZE_MPT * `ICM_ENTRY_NUM_MPT / `PAGE_SIZE) + (`ICM_SLOT_SIZE_MPT * `ICM_ENTRY_NUM_MPT) % //`PAGE_SIZE ? 1 : 0)
//`define 	ICM_PAGE_NUM_QPC					((`ICM_SLOT_SIZE_QPC * `ICM_ENTRY_NUM_QPC / `PAGE_SIZE) + (`ICM_SLOT_SIZE_QPC * `ICM_ENTRY_NUM_QPC) % //`PAGE_SIZE ? 1 : 0)
//`define 	ICM_PAGE_NUM_CQC					((`ICM_SLOT_SIZE_CQC * `ICM_ENTRY_NUM_CQC / `PAGE_SIZE) + (`ICM_SLOT_SIZE_CQC * `ICM_ENTRY_NUM_CQC) % //`PAGE_SIZE ? 1 : 0)
//`define 	ICM_PAGE_NUM_EQC					((`ICM_SLOT_SIZE_EQC * `ICM_ENTRY_NUM_EQC / `PAGE_SIZE) + (`ICM_SLOT_SIZE_EQC * `ICM_ENTRY_NUM_EQC) % `PAGE_SIZE ? 1 : 0)
`define 	ICM_PAGE_NUM_MTT					(`ICM_SLOT_SIZE_MTT * `ICM_ENTRY_NUM_MTT / `PAGE_SIZE)
`define 	ICM_PAGE_NUM_MPT					(`ICM_SLOT_SIZE_MPT * `ICM_ENTRY_NUM_MPT / `PAGE_SIZE)
`define 	ICM_PAGE_NUM_QPC					(`ICM_SLOT_SIZE_QPC * `ICM_ENTRY_NUM_QPC / `PAGE_SIZE)
`define 	ICM_PAGE_NUM_CQC					(`ICM_SLOT_SIZE_CQC * `ICM_ENTRY_NUM_CQC / `PAGE_SIZE)
`define 	ICM_PAGE_NUM_EQC					(`ICM_SLOT_SIZE_EQC * `ICM_ENTRY_NUM_EQC / `PAGE_SIZE)

//ICM space addr width
`define 	ICM_SPACE_ADDR_WIDTH 				64

//Physical space addr width
`define 	PHY_SPACE_ADDR_WIDTH 				64

`define 	PAGE_FRAME_WIDTH 					52


`define 	COUNT_MAX 							2
`define 	COUNT_MAX_LOG 						2

`define 	REQ_TAG_NUM 						4
`define 	REQ_TAG_NUM_LOG 					2
/*----------------------------------------------------- ICMCache Parameters : End ----------------------------------------------------*/

/*----------------------------------------------------- WQE Unit Filed Offset : End --------------------------------------------------*/
//NextUnit field offset
`define 	NEXT_UNIT_NEXT_WQE_OPCODE_OFFSET 		4:0
`define 	NEXT_UNIT_NEXT_WQE_VALID_OFFSET 		5
`define 	NEXT_UNIT_NEXT_WQE_ADDR_OFFSET 			31:6
`define 	NEXT_UNIT_NEXT_WQE_SIZE_OFFSET 			37:32
`define 	NEXT_UNIT_CUR_WQE_FENCE_OFFSET			38
`define 	NEXT_UNIT_NEXT_WQE_DBD_OFFSET			39
`define 	NEXT_UNIT_NEXT_WQE_EE_OFFSET  			63:40
`define 	NEXT_UNIT_CUR_WQE_SIZE_OFFSET 			77:70
`define 	NEXT_UNIT_CUR_WQE_OPCODE_OFFSET			85:78
`define 	NEXT_UNIT_CUR_WQE_IMM_OFFSET			127:96

//DataUnit field offset
`define 	DATA_UNIT_INLINE_OFFSET					31
`define 	DATA_UNIT_BYTE_CNT_OFFSET				30:0
`define 	DATA_UNIT_LKEY_OFFSET 					63:32
`define 	DATA_UNIT_LADDR_OFFSET 					127:64

//RaddrUnit field offset
`define 	RADDR_UNIT_RADDR_OFFSET 				63:0
`define 	RADDR_UNIT_RKEY_OFFSET 					95:64

//UDUnit field offset 
`define 	UD_UNIT_PORT_OFFSET 					7:0
`define 	UD_UNIT_SMAC_LOW_OFFSET 				47:32
`define 	UD_UNIT_SMAC_HIGH_OFFSET 				95:64
`define 	UD_UNIT_DMAC_LOW_OFFSET					63:48
`define 	UD_UNIT_DMAC_HIGH_OFFSET				127:96
`define 	UD_UNIT_SIP_OFFSET 						31:0
`define 	UD_UNIT_DIP_OFFSET 						63:32
`define 	UD_UNIT_REMOTE_QPN_OFFSET				31:0
`define 	UD_UNIT_QKEY_OFFSET						63:32
/*----------------------------------------------------- WQE Unit Filed Offset : End --------------------------------------------------*/

//RaddrUnit filed offset

/*----------------------------------------------------- CEU Parameters : Begin --------------------------------------------------*/
`define     CEU_CXT_HEAD_WIDTH                  128             
`define     CEU_CXT_DATA_WIDTH                  256                 

`define     CEU_MR_HEAD_WIDTH                   128
`define     CEU_MR_DATA_WIDTH                   256

`define 	RD_QP_CXT							4'b0001
`define 	WR_QP_CXT							4'b0010
`define 	WR_CQ_CXT							4'b0011
`define 	WR_EQ_CXT							4'b0100
`define 	WR_ICMMAP_CXT						4'b0101
`define 	MAP_ICM_CXT							4'b0110

`define 	RD_QP_ALL							4'b0001
`define 	WR_QP_ALL							4'b0001
`define 	WR_CQ_ALL							4'b0001
`define 	WR_CQ_MODIFY						4'b0010
`define 	WR_CQ_INVALID						4'b0011
`define 	WR_EQ_ALL							4'b0001
`define 	WR_EQ_FUNC							4'b0010
`define 	WR_EQ_INVALID						4'b0100
`define 	WR_ICMMAP_EN						4'b0001
`define 	WR_ICMMAP_DIS						4'b0010
`define 	MAP_ICM_EN							4'b0001
`define 	MAP_ICM_DIS							4'b0010

`define 	WR_MPT_TPT    						4'b0001
`define 	WR_MTT_TPT    						4'b0010
`define 	WR_ICMMAP_TPT 						4'b0011
`define 	MAP_ICM_TPT   						4'b0100

`define 	WR_MPT_WRITE   						4'b0001
`define 	WR_MPT_INVALID 						4'b0010

`define 	WR_MTT_WRITE   						4'b0001
`define 	WR_MTT_INVALID 						4'b0010
/*----------------------------------------------------- CEU Parameters : End ----------------------------------------------------*/


/*-----------------------------------------------------	DMA Parameters : Begin --------------------------------------------------*/
`define 	DMA_HEAD_WIDTH 						128				
`define 	DMA_DATA_WIDTH						512 				

`define 	DMA_LENGTH_WIDTH					32
`define 	DMA_ADDR_WIDTH						64
/*-----------------------------------------------------	DMA Parameters : End ----------------------------------------------------*/


/*------------------------------------------------------- CxtMgt Parameters : Begin ---------------------------------------------*/
`define 	CXT_READ 							4'b0001

`define 	CXT_CMD_HEAD_WIDTH					128	
`define 	CXT_CMD_DATA_WIDTH					512

`define 	CXT_RESP_HEAD_WIDTH 				128
`define 	CXT_RESP_DATA_WIDTH 				`CACHE_ENTRY_WIDTH_QPC + `CACHE_ENTRY_WIDTH_CQC + `CACHE_ENTRY_WIDTH_EQC
/*------------------------------------------------------- CxtMgt Parameters : End -----------------------------------------------*/		



/*-------------------------------------------------------- MRMgt Parameters : Begin ---------------------------------------------*/
`define 	MR_CMD_HEAD_WIDTH						192	
`define 	MR_CMD_DATA_WIDTH						512
	
`define 	MR_RESP_HEAD_WIDTH 						192
`define 	MR_RESP_DATA_WIDTH 						224
	
`define 	MR_RESP_STATE_OFFSET					3:0
`define 	MR_RESP_PAGE_CNT_OFFSET					23:4

`define 	MR_RESP_VALID_0_OFFSET					3:0
`define 	MR_RESP_VALID_1_OFFSET					7:4
`define 	MR_RESP_SIZE_0_OFFSET					63:32
`define 	MR_RESP_SIZE_1_OFFSET					95:64
`define 	MR_RESP_ADDR_0_OFFSET					159:96
`define 	MR_RESP_ADDR_1_OFFSET					223:160

`define 	LOCAL_READ 								4'b0001
`define 	LOCAL_WRITE 							4'b0010
`define 	REMOTE_READ 							4'b0100
`define 	REMOTE_WRITE 							4'b1000

`define 	PAGE_VALID 								4'b1111
/*-------------------------------------------------------- MRMgt Parameters : End -----------------------------------------------*/	
			

/*-------------------------------------------------------- QueueSubsystem Parameters : Begin ------------------------------------*/
`define 	SQ_META_WIDTH 										544

`define 	SQ_CACHE_CELL_NUM 									16
`define 	SQ_CACHE_CELL_NUM_LOG 								4
`define 	SQ_CACHE_SLOT_NUM 									64
`define 	SQ_CACHE_SLOT_NUM_LOG								6

`define 	RQ_CACHE_CELL_NUM 									`SQ_CACHE_CELL_NUM 		
`define 	RQ_CACHE_CELL_NUM_LOG 								`SQ_CACHE_CELL_NUM_LOG 	
`define 	RQ_CACHE_SLOT_NUM 									`SQ_CACHE_SLOT_NUM 		
`define 	RQ_CACHE_SLOT_NUM_LOG								`SQ_CACHE_SLOT_NUM_LOG

`define 	WQE_META_WIDTH 										576
`define 	WQE_SEG_WIDTH 										128

`define 	WQE_PARSER_META_WIDTH								288
/*-------------------------------------------------------- QueueSubsystem Parameters : End --------------------------------------*/


/*----------------------------------------------------------- RDMACore Parameters : Begin ---------------------------------------*/

/*----------------------------------------------------------- RDMACore Parameters : End -----------------------------------------*/

/*---------------------------------------------------- TransportSubsystem Parameters : Begin ------------------------------------*/
`define 	PKT_HEAD_BUS_WIDTH 				32
`define 	PKT_DATA_BUS_WIDTH 				512
`define     PKT_KEEP_BUS_WIDTH              64
/*---------------------------------------------------- TransportSubsystem Parameters : End --------------------------------------*/


/*---------------------------------------------------------- OoOStation Parameters : Begin --------------------------------------*/
`define 	MAX_REQ_TAG_NUM					256
`define 	MAX_REQ_TAG_NUM_LOG 			8

`define 	DEFAULT_REQ_TAG_NUM				32
`define 	DEFAULT_REQ_TAG_NUM_LOG			5

//SQ OoOStation
`define 	SQ_OOO_SLOT_NUM        			32
`define 	SQ_OOO_SLOT_NUM_LOG				5

`define 	SQ_OOO_CXT_INGRESS_HEAD_WIDTH		(`CXT_CMD_HEAD_WIDTH + `INGRESS_COMMON_HEAD_WIDTH)
`define 	SQ_OOO_CXT_INGRESS_DATA_WIDTH 		512
`define 	SQ_OOO_CXT_EGRESS_HEAD_WIDTH 		(`CXT_RESP_DATA_WIDTH + `EGRESS_COMMON_HEAD_WIDTH)
`define 	SQ_OOO_CXT_EGRESS_DATA_WIDTH 		`SQ_OOO_CXT_INGRESS_DATA_WIDTH

`define 	SQ_OOO_MR_INGRESS_HEAD_WIDTH		(`MR_CMD_HEAD_WIDTH + `INGRESS_COMMON_HEAD_WIDTH)
`define 	SQ_OOO_MR_INGRESS_DATA_WIDTH 		512
`define 	SQ_OOO_MR_EGRESS_HEAD_WIDTH 		(`MR_RESP_DATA_WIDTH + `EGRESS_COMMON_HEAD_WIDTH)
`define 	SQ_OOO_MR_EGRESS_DATA_WIDTH 		`SQ_OOO_MR_INGRESS_DATA_WIDTH

//RQ OoOStation
`define 	RQ_OOO_SLOT_NUM        			32
`define 	RQ_OOO_SLOT_NUM_LOG				5

//Not Used
`define 	RQ_OOO_CXT_INGRESS_HEAD_WIDTH		(`CXT_CMD_HEAD_WIDTH + `INGRESS_COMMON_HEAD_WIDTH)
`define 	RQ_OOO_CXT_INGRESS_DATA_WIDTH 		`PKT_META_BUS_WIDTH
`define 	RQ_OOO_CXT_EGRESS_HEAD_WIDTH 		(`CXT_RESP_DATA_WIDTH + `EGRESS_COMMON_HEAD_WIDTH)
`define 	RQ_OOO_CXT_EGRESS_DATA_WIDTH 		`RQ_OOO_CXT_INGRESS_DATA_WIDTH

`define 	RQ_OOO_MR_INGRESS_HEAD_WIDTH		(`MR_CMD_HEAD_WIDTH + `INGRESS_COMMON_HEAD_WIDTH)
`define 	RQ_OOO_MR_INGRESS_DATA_WIDTH 		352
`define 	RQ_OOO_MR_EGRESS_HEAD_WIDTH 		(`MR_RESP_DATA_WIDTH + `EGRESS_COMMON_HEAD_WIDTH)
`define 	RQ_OOO_MR_EGRESS_DATA_WIDTH 		`RQ_OOO_MR_INGRESS_DATA_WIDTH

//TX_REQ OoOStation
`define 	TX_REQ_OOO_SLOT_NUM        			32
`define 	TX_REQ_OOO_SLOT_NUM_LOG				5

`define 	TX_REQ_OOO_CXT_INGRESS_HEAD_WIDTH		(`CXT_CMD_HEAD_WIDTH + `INGRESS_COMMON_HEAD_WIDTH)
`define 	TX_REQ_OOO_CXT_INGRESS_DATA_WIDTH 		576
`define 	TX_REQ_OOO_CXT_EGRESS_HEAD_WIDTH 		(`CXT_RESP_DATA_WIDTH + `EGRESS_COMMON_HEAD_WIDTH)
`define 	TX_REQ_OOO_CXT_EGRESS_DATA_WIDTH 		`TX_REQ_OOO_CXT_INGRESS_DATA_WIDTH

`define 	TX_REQ_OOO_MR_INGRESS_HEAD_WIDTH		(`MR_CMD_HEAD_WIDTH + `INGRESS_COMMON_HEAD_WIDTH)
`define 	TX_REQ_OOO_MR_INGRESS_DATA_WIDTH 		576
`define 	TX_REQ_OOO_MR_EGRESS_HEAD_WIDTH 		(`MR_RESP_DATA_WIDTH + `EGRESS_COMMON_HEAD_WIDTH)
`define 	TX_REQ_OOO_MR_EGRESS_DATA_WIDTH 		`TX_REQ_OOO_MR_INGRESS_DATA_WIDTH

//RX_REQ OoOStation
`define 	RX_REQ_OOO_SLOT_NUM        			32
`define 	RX_REQ_OOO_SLOT_NUM_LOG				5

`define 	RX_REQ_OOO_CXT_INGRESS_HEAD_WIDTH		(`CXT_CMD_HEAD_WIDTH + `INGRESS_COMMON_HEAD_WIDTH)
`define 	RX_REQ_OOO_CXT_INGRESS_DATA_WIDTH 		`PKT_META_BUS_WIDTH
`define 	RX_REQ_OOO_CXT_EGRESS_HEAD_WIDTH 		(`CXT_RESP_DATA_WIDTH + `EGRESS_COMMON_HEAD_WIDTH)
`define 	RX_REQ_OOO_CXT_EGRESS_DATA_WIDTH 		`RX_REQ_OOO_CXT_INGRESS_DATA_WIDTH

`define 	RX_REQ_OOO_MR_INGRESS_HEAD_WIDTH		(`MR_CMD_HEAD_WIDTH + `INGRESS_COMMON_HEAD_WIDTH)
`define 	RX_REQ_OOO_MR_INGRESS_DATA_WIDTH 		352
`define 	RX_REQ_OOO_MR_EGRESS_HEAD_WIDTH 		(`MR_RESP_DATA_WIDTH + `EGRESS_COMMON_HEAD_WIDTH)
`define 	RX_REQ_OOO_MR_EGRESS_DATA_WIDTH 		`RX_REQ_OOO_MR_INGRESS_DATA_WIDTH

//RX_RESP OoOStation
`define 	RX_RESP_OOO_SLOT_NUM        			32
`define 	RX_RESP_OOO_SLOT_NUM_LOG				5

`define 	RX_RESP_OOO_CXT_INGRESS_HEAD_WIDTH		(`CXT_CMD_HEAD_WIDTH + `INGRESS_COMMON_HEAD_WIDTH)
`define 	RX_RESP_OOO_CXT_INGRESS_DATA_WIDTH 		`PKT_META_BUS_WIDTH
`define 	RX_RESP_OOO_CXT_EGRESS_HEAD_WIDTH 		(`CXT_RESP_DATA_WIDTH + `EGRESS_COMMON_HEAD_WIDTH)
`define 	RX_RESP_OOO_CXT_EGRESS_DATA_WIDTH 		`RX_RESP_OOO_CXT_INGRESS_DATA_WIDTH

`define 	RX_RESP_OOO_MR_INGRESS_HEAD_WIDTH		(`MR_CMD_HEAD_WIDTH + `INGRESS_COMMON_HEAD_WIDTH)
`define 	RX_RESP_OOO_MR_INGRESS_DATA_WIDTH 		352
`define 	RX_RESP_OOO_MR_EGRESS_HEAD_WIDTH 		(`MR_RESP_DATA_WIDTH + `EGRESS_COMMON_HEAD_WIDTH)
`define 	RX_RESP_OOO_MR_EGRESS_DATA_WIDTH 		`RX_REQ_OOO_MR_INGRESS_DATA_WIDTH



//Shared by QueueSubsystem and RDMACore(Could be customized for each submodule)
`define 	OOO_RESOURCE_TAG_OFFSET							7:0
`define 	OOO_RESOURCE_OPCODE_OFFSET 						11:8
`define 	OOO_RESOURCE_QUEUE_INDEX_OFFSET 				35:12

`define 	INGRESS_COMMON_HEAD_WIDTH						32
`define 	INGRESS_COMMON_HEAD_OFFSET						31:0
`define 	INGRESS_QUEUE_INDEX_OFFSET						23:0
`define 	INGRESS_SLOT_NUM_OFFSET 						30:24
`define 	INGRESS_NEED_RESOURCE_OFFSET 					31

`define 	EGRESS_COMMON_HEAD_WIDTH						32
`define 	EGRESS_COMMON_HEAD_OFFSET						31:0
`define 	EGRESS_QUEUE_INDEX_OFFSET						23:0
`define 	EGRESS_SLOT_NUM_OFFSET 							30:24
`define 	EGRESS_NEED_RESOURCE_OFFSET 					31

`define 	BYPASS_MODE										1'b1
`define 	NO_BYPASS 										1'b0
/*---------------------------------------------------------- OoOStation Parameters : End ----------------------------------------*/


/*---------------------------------------------------------- Software Verbs Opcode : Begin --------------------------------------*/
//Request Code Definition
`define     VERBS_SEND                 5'b01010
`define     VERBS_SEND_WITH_IMM        5'b01011
`define     VERBS_RDMA_WRITE           5'b01000
`define     VERBS_RDMA_WRITE_WITH_IMM  5'b01001 
`define     VERBS_RDMA_READ            5'b10000 
`define     VERBS_CMP_AND_SWAP         5'b10001 
`define     VERBS_FETCH_AND_ADD        5'b10010 
`define 	OPCODE_INVALID 			   8'hFF	

//Completion Code Definition
`define     LOC_LEN_ERR             8'b00000001
`define     LOC_QP_OP_ERR           8'b00000010 
`define     LOC_EEC_OP_ERR          8'b00000011
`define     LOC_PROT_ERR            8'b00000100
`define     WR_FLUSH_ERR            8'b00000101 
`define     MW_BIND_ERR             8'b00000110 
`define     BAD_RESP_ERR            8'b00010000
`define     LOC_ACCESS_ERR          8'b00010001
`define     REM_INV_REQ_ERR         8'b00010010 
`define     REM_ACCESS_ERR          8'b00010011
`define     REM_OP_ERR              8'b00010100 
`define     RETRY_EXC_ERR           8'b00010101 
`define     RNR_RETRY_EXC_ERR       8'b00010110 
`define     LOC_RDD_VIOL_ERR        8'b00100000 
`define     REM_INV_RD_REQ_ERR      8'b00100001 
`define     REM_ABORT_ERR           8'b00100010 
`define     INV_EECN_ERR            8'b00100011 
`define     INV_EEC_STATE_ERR       8'b00100100 

//QP State Definition
`define     QP_RESET           3'b000
`define     QP_INIT            3'b001
`define     QP_RTR             3'b010 
`define     QP_RTS             3'b011 
`define     QP_SQD             3'b100 
`define     QP_SQE             3'b101
`define     QP_ERR             3'b110
/*---------------------------------------------------------- Software Verbs Opcode : End ----------------------------------------*/

/*---------------------------------------------------------- Network Header Opcode : Begin --------------------------------------*/
`define 	BTH_LENGTH			9
`define 	RETH_LENGTH 		16
`define 	IMMETH_LENGTH 		4
`define 	AETH_LENGTH 		4
`define 	MAC_HEADER_LENGTH	14

//Base Transport Header Code
`define     RC      3'b000
`define     UC      3'b001
`define     RD      3'b010
`define     UD      3'b011
`define     CNP     3'b100
`define     XRC     3'b101

`define     SEND_FIRST                      5'b00000
`define     SEND_MIDDLE                     5'b00001
`define     SEND_LAST                       5'b00010
`define     SEND_LAST_WITH_IMM              5'b00011
`define     SEND_ONLY                       5'b00100 
`define     SEND_ONLY_WITH_IMM              5'b00101
`define     RDMA_WRITE_FIRST                5'b00110 
`define     RDMA_WRITE_MIDDLE               5'b00111
`define     RDMA_WRITE_LAST                 5'b01000 
`define     RDMA_WRITE_LAST_WITH_IMM        5'b01001 
`define     RDMA_WRITE_ONLY                 5'b01010
`define     RDMA_WRITE_ONLY_WITH_IMM        5'b01011
`define     RDMA_READ_REQUEST_FIRST         5'b01100
`define     RDMA_READ_REQUEST_MIDDLE        5'b01101
`define     RDMA_READ_REQUEST_LAST          5'b01110
`define     RDMA_READ_REQUEST_ONLY          5'b01111
`define     RDMA_READ_RESPONSE_FIRST        5'b10000 
`define     RDMA_READ_RESPONSE_MIDDLE       5'b10001 
`define     RDMA_READ_RESPONSE_LAST         5'b10010 
`define     RDMA_READ_RESPONSE_ONLY         5'b10011
`define     ACKNOWLEDGE                     5'b10100
`define     ATOMIC_ACKNOWLEDGE              5'b10101 
`define     CMP_AND_SWAP                    5'b10110 
`define     FETCH_AND_ADD                   5'b10111
`define     SEND_LAST_WITH_INVALIDATE       5'b11000 
`define     SEND_ONLY_WITH_INVALIDATE       5'b11001
`define 	GEN_CQE							5'b11010 	//GEN_CQE and GEN_EVENT is used to trigger CQE and Event
`define 	GEN_EVENT						5'b11011
`define 	GEN_INT 						5'b11100
`define     NONE_OPCODE                     5'b11111

//Acknowledgement Extended Transport Header Syndrome Code
`define     ACK_TYPE                        2'b00
`define     RNR_TYPE                        2'b01 
`define     RESERVED_TYPE                   2'b10
`define     NAK_TYPE                        2'b11 
        
`define     PSN_SEQUENCE_ERROR              5'b00000
`define     INVALID_REQUEST                 5'b00001 
`define     REMOTE_ACCESS_ERROR             5'b00010 
`define     REMOTE_OPERATIONAL_ERROR        5'b00011
`define     INVALID_RD_REQUEST              5'b00100

//MTU Constants
`define     MTU_256                         16'd256
`define     MTU_512                         16'd512
`define     MTU_1024                        16'd1024
`define     MTU_2048                        16'd2048
`define     MTU_4096                        16'd4096

//Header Length
`define 	PKT_ADDR_LENGTH					8'd2
`define 	BASE_HEADER_LENGTH				8'd9
`define 	WRITE_HEADER_LENGTH				8'd12
`define 	READ_REQ_HEADER_LENGTH			8'd24
`define 	READ_RSP_HEADER_LENGTH			8'd12
`define 	IMM_HEADER_LENGTH				8'd4
`define 	READ_RSP_HEADER_LENGTH			8'd12
`define 	ACK_HEADER_LENGTH				8'd1
`define 	ATOMICS_HEADER_LENGTH			8'd28
`define 	LINK_HEADER_LENGTH				8'd20

/*---------------------------------------------------------- Network Header Opcode : End ----------------------------------------*/

`define 	PACKET_BUFFER_SLOT_WIDTH 		512
`define 	PACKET_BUFFER_SLOT_NUM 			512
`define 	PACKET_BUFFER_SLOT_NUM_LOG 		9

`define 	INLINE_PAYLOAD_BUFFER_SLOT_WIDTH 		128
`define 	INLINE_PAYLOAD_BUFFER_SLOT_NUM 			4096
`define 	INLINE_PAYLOAD_BUFFER_SLOT_NUM_LOG 		12

`define 	RECV_BUFFER_SLOT_NUM 					4096
`define 	RECV_BUFFER_SLOT_NUM_LOG 				12
`define 	RECV_BUFFER_SLOT_WIDTH 					512

`define 	MCB_META_WIDTH 							512
`define 	MCB_SLOT_NUM 							4096
`define 	MCB_SLOT_NUM_LOG 						12
`define 	MCB_SLOT_WIDTH 							512
/*---------------------------------------------------------- Hardware Context Offset Definition : Begin ----------------------------------------*/
`define 	QP_CONTEXT_BIT_SIZE				416
`define 	CQ_CONTEXT_BIT_SIZE				128
`define 	EQ_CONTEXT_BIT_SIZE				96


//QP Context
`define 	QP_CXT_SERVICE_TYPE_OFFSET				2:0
`define 	QP_CXT_STATE_OFFSET 					5:3
`define 	QP_CXT_MTU_MSGMAX_OFFSET 				15:8
`define 	QP_CXT_PMTU_OFFSET						15:13
`define 	QP_CXT_SQ_ENTRY_SZ_LOG_OFFSET 			23:16
`define 	QP_CXT_RQ_ENTRY_SZ_LOG_OFFSET 			31:24
`define 	QP_CXT_DST_QPN_OFFSET					47:32
`define 	QP_CXT_PKEY_INDEX_OFFSET				55:48
`define 	QP_CXT_PORT_INDEX_OFFSET				63:56
`define 	QP_CXT_CQN_SND_OFFSET					79:64
`define 	QP_CXT_CQN_RCV_OFFSET					95:80
`define 	QP_CXT_PD_OFFSET 						127:96
`define 	QP_CXT_SQ_LKEY_OFFSET 					159:128
`define 	QP_CXT_SQ_LENGTH_OFFSET 				191:160
`define 	QP_CXT_RQ_LKEY_OFFSET 					223:192
`define 	QP_CXT_RQ_LENGTH_OFFSET					255:224
`define 	QP_CXT_SLID_OFFSET 						271:256
`define 	QP_CXT_SMAC_OFFSET						303:256
`define 	QP_CXT_DLID_OFFSET						319:304
`define 	QP_CXT_DMAC_OFFSET						351:304
`define 	QP_CXT_SIP_OFFSET 						383:352
`define 	QP_CXT_DIP_OFFSET						415:384

//CQ Context, 160+256 is QP context bit size
`define 	CQ_CXT_LOG_SIZE_OFFSET					7+`QP_CONTEXT_BIT_SIZE:0+`QP_CONTEXT_BIT_SIZE
`define 	CQ_CXT_COMP_EQN_OFFSET					63+`QP_CONTEXT_BIT_SIZE:32+`QP_CONTEXT_BIT_SIZE
`define 	CQ_CXT_PD_OFFSET						95+`QP_CONTEXT_BIT_SIZE:64+`QP_CONTEXT_BIT_SIZE
`define 	CQ_CXT_LKEY_OFFSET						127+`QP_CONTEXT_BIT_SIZE:96+`QP_CONTEXT_BIT_SIZE

//EQ Contex, 160+256+128 is QP+CQ context bit size
`define 	EQ_CXT_LOG_SIZE_OFFSET					7+`QP_CONTEXT_BIT_SIZE+`CQ_CONTEXT_BIT_SIZE:0+`QP_CONTEXT_BIT_SIZE+`CQ_CONTEXT_BIT_SIZE
`define 	EQ_CXT_MSIX_INT_OFFSET					15+`QP_CONTEXT_BIT_SIZE+`CQ_CONTEXT_BIT_SIZE:0+`QP_CONTEXT_BIT_SIZE+`CQ_CONTEXT_BIT_SIZE
`define 	EQ_CXT_PD_OFFSET						63+`QP_CONTEXT_BIT_SIZE+`CQ_CONTEXT_BIT_SIZE:32+`QP_CONTEXT_BIT_SIZE+`CQ_CONTEXT_BIT_SIZE
`define 	EQ_CXT_LKEY_OFFSET						95+`QP_CONTEXT_BIT_SIZE+`CQ_CONTEXT_BIT_SIZE:64+`QP_CONTEXT_BIT_SIZE+`CQ_CONTEXT_BIT_SIZE
/*---------------------------------------------------------- Hardware Context Offset Definition : End ----------------------------------------*/

`define 	SQ_PREFETCH_LENGTH				(`SQ_CACHE_SLOT_NUM * 16)	//Aligned to Cache Cell Slot Num
`define 	RQ_PREFETCH_LENGTH				(`SQ_CACHE_SLOT_NUM * 16)	//TODO

`define 	CQ_REQ_HEAD_WIDTH 				64
`define 	EQ_REQ_HEAD_WIDTH 				64

`define 	CQ_RESP_HEAD_WIDTH 				96
`define 	EQ_RESP_HEAD_WIDTH 				96

`define 	CQE_LENGTH 						32
`define 	EVENT_LENGTH 					32

`define 	CQ_LADDR_OFFSET					95:32
`define 	EQ_LADDR_OFFSET					95:32

`define 	MR_RESP_WIDTH 					224

`define 	NET_REQ_META_WIDTH 				512		//TODO


`define 	HGHCA_CQ_ENTRY_OWNER_SW 		(0 << 7)
`define 	HGHCA_CQ_ENTRY_OWNER_HW 		(1 << 7)

`define 	WQE_BUFFER_SLOT_NUM 			512
`define 	WQE_BUFFER_SLOT_NUM_LOG 		9

`define 	WQE_BUFFER_SLOT_WIDTH 			488

`define 	RC_WQE_BUFFER_SLOT_WIDTH		256
`define 	RC_WQE_BUFFER_SLOT_NUM			64

`define 	PKT_META_BUS_WIDTH 				488

`define 	TAIL_FLAG						8'hFF
/*-------------------------------------------------- Common Function Definition : Begin ------------------------------------------*/
`ifndef COMMON_FUNCTION
`define COMMON_FUNCTION

	/* ------- LOG transform{begin} ------ */
    function automatic integer log2b;
    input integer val;
    begin: func_log2b
        integer i;
        log2b = 1;
        for(i = 0; i < 32; i = i + 1) begin
            if(|(val >> i)) begin
                log2b = i + 1;
            end
        end
    end
    endfunction
    /* ------- LOG transform{end} ------ */

	/* ------- DW transform{begin} ------ */
	function automatic [31:0] dw_trans;
	input [31:0] dw_in;
	begin
	    dw_trans = {dw_in[7:0], dw_in[15:8], dw_in[23:16], dw_in[31:24]};
	end
	endfunction
	/* ------- DW transform{end} ------ */

	/* ------- Beat transform{begin} ------ */
	function automatic [255:0] beat_trans;
	input [255:0] beat_in;
	begin
	    beat_trans = {dw_trans(beat_in[31 :0  ]), 
	                  dw_trans(beat_in[63 :32 ]), 
	                  dw_trans(beat_in[95 :64 ]), 
	                  dw_trans(beat_in[127:96 ]), 
	                  dw_trans(beat_in[159:128]), 
	                  dw_trans(beat_in[191:160]), 
	                  dw_trans(beat_in[223:192]), 
	                  dw_trans(beat_in[255:224])};
	end
	endfunction
	/* ------- Beat transform{end} ------ */
`endif
/*-------------------------------------------------- Common Function Definition : End -------------------------------------------*/

`define 	TODO 							0

`define 	MAC_DATA_WIDTH 					512
`define 	MAC_KEEP_WIDTH 					64