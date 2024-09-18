`define CEU_DATA_WIDTH      256


//----------------------------{CMD decode}begin--------------------------//
/* -------Write Read local(CEU) relevant CMD{begin}------- */
// Read
`define CMD_QUERY_DEV_LIM 12'h003 // no in_param, out_param -- outbox
`define CMD_QUERY_ADAPTER 12'h006 // no in_param, out_param -- outbox

// unrealized, belongs to MAD
`define CMD_INIT_IB          12'h009 // in_param -- inbox, no out_param, in_modifier -- port
`define CMD_CLOSE_IB         12'h00a // no in_param, no out_param, in_modifier -- port
`define CMD_SET_IB           12'h00c // in_param -- inbox, no out_param, in_modifier -- port
`define CMD_CONF_SPECIAL_QP  12'h023
`define CMD_MAD_IFC          12'h024
/* -------Write Read local(CEU) relevant CMD{end}------- */

/* -------Read Write Context Management CMD{begin}------- */
// with req data
`define CMD_SW2HW_CQ      12'h016 // in_param -- inbox, no out_param, in_modifier -- cqn
`define CMD_RESIZE_CQ     12'h02c // in_param -- inbox, no out_param, in_modifier -- cqn
`define CMD_SW2HW_EQ      12'h013 // in_param -- inbox, no out_param, in_modifier -- eqn
`define CMD_MAP_EQ        12'h012 // in_param -- event_mask, no out_param, in_modifier -- eqn

// with || without req data
`define CMD_MODIFY_QP

// without req data, with resp
`define CMD_HW2SW_CQ      12'h017 // no in_param, no out_param, in_modifier -- cqn
`define CMD_HW2SW_EQ      12'h014 // no in_param, no out_param, in_modifier -- eqn
`define CMD_QUERY_QP      12'h022 // no in_param, out_param -- outbox, in_modifier -- qpn
/* -------Read Write Context Management CMD{end}------- */

/* -------Write Virtual to Physical CMD{begin}------- */
// with req data
`define CMD_SW2HW_MPT     12'h00d // in_param -- inbox, no out_param, in_modifier -- mpt_index
`define CMD_WRITE_MTT     12'h011 // in_param -- inbox, no out_param, in_modifier -- mtt_num

// without req data, without resp
`define CMD_HW2SW_MPT     12'h00f // no in_param, no out_param, in_modifier -- mpt_index
/* -------Write Virtual to Physical CMD{end}------- */

/* -------Write CtxMgt && Virt2Phys CMD{begin}------- */
// with req data
`define CMD_INIT_HCA      12'h007 // in_param -- inbox, no out_param

// without req data, without resp
`define CMD_CLOSE_HCA     12'h008 // no in_param, no out_param
/* -------Write CtxMgt && Virt2Phys CMD{end}------- */

/* -------Write CtxMgt || Virt2Phys{begin}------- */
// with req data
`define CMD_MAP_ICM       12'hffa // in_param -- inbox, no out_param, in_modifier -- nent, op_modifier -- module selection
`define CMD_UNMAP_ICM     12'hff9 // in_param -- virt addr, no out_param, in_modifier -- page count, op_modifier -- module selection
/* -------Write CtxMgt || Virt2Phys{end}------- */

/* -------Access EQ engine{begin}------- */
// not realized
`define CMD_NOP
/* -------Access EQ engine{end}------- */

/* -------MODIFY_QP -- inbox & no inbox, no outbox{begin}------- */
`define CMD_RST2INIT_QPEE   12'h019
`define CMD_INIT2RTR_QPEE   12'h01a
`define CMD_RTR2RTS_QPEE    12'h01b
`define CMD_RTS2RTS_QPEE    12'h01c
`define CMD_SQERR2RTS_QPEE  12'h01d
`define CMD_2ERR_QPEE       12'h01e
`define CMD_RTS2SQD_QPEE    12'h01f
`define CMD_SQD2SQD_QPEE    12'h038
`define CMD_SQD2RTS_QPEE    12'h020
`define CMD_ERR2RST_QPEE    12'h021
`define CMD_INIT2INIT_QPEE  12'h02d

`define IS_MODIFY_QP(x) (((x) == `CMD_RST2INIT_QPEE ) || \
                         ((x) == `CMD_INIT2RTR_QPEE ) || \
                         ((x) == `CMD_RTR2RTS_QPEE  ) || \
                         ((x) == `CMD_RTS2RTS_QPEE  ) || \
                         ((x) == `CMD_SQERR2RTS_QPEE) || \
                         ((x) == `CMD_2ERR_QPEE     ) || \
                         ((x) == `CMD_RTS2SQD_QPEE  ) || \
                         ((x) == `CMD_SQD2SQD_QPEE  ) || \
                         ((x) == `CMD_SQD2RTS_QPEE  ) || \
                         ((x) == `CMD_ERR2RST_QPEE  ) || \
                         ((x) == `CMD_INIT2INIT_QPEE))
/* -------MODIFY_QP -- inbox & no inbox, no outbox{end}------- */

/* -------may not be realized{begin}------- */
`define CMD_MAP_FA
`define CMD_UNMAP_FA
`define CMD_RUN_FW
`define CMD_QUERY_FW
`define CMD_MAP_ICM_AUX
`define CMD_UNMAP_ICM_AUX
`define CMD_SET_ICM_SIZE
/* -------may not be realized{end}------- */

//----------------------------{CMD decode}end----------------------------//

/* --------------CMD Status{begin}-------------- */

// realized
`define HGRNIC_CMD_STAT_OK               8'h00 // command completed successfully:  
`define HGRNIC_CMD_STAT_BAD_OP           8'h02 // Operation/command not supported or opcode modifier not supported:  
`define HGRNIC_CMD_STAT_BAD_PARAM        8'h03 // Parameter not supported or parameter out of range:
`define HGRNIC_CMD_STAT_BAD_SYS_STATE    8'h04 // System not enabled or bad system state:  
`define HGRNIC_CMD_STAT_BAD_NVMEM        8'h0b // FW image corrupted:


// not realized
`define HGRNIC_CMD_STAT_BAD_INDEX        8'h0a // Index out of range:
`define HGRNIC_CMD_STAT_INTERNAL_ERR     8'h01 // Internal error (such as a bus error) occurred while processing command:  
`define HGRNIC_CMD_STAT_BAD_RESOURCE     8'h05 // Attempt to access reserved or unallocaterd resource:  
`define HGRNIC_CMD_STAT_RESOURCE_BUSY    8'h06 // Requested resource is currently executing a command, or is otherwise busy:  
`define HGRNIC_CMD_STAT_DDR_MEM_ERR      8'h07 // memory error:  
`define HGRNIC_CMD_STAT_EXCEED_LIM       8'h08 // Required capability exceeds device limits:  
`define HGRNIC_CMD_STAT_BAD_RES_STATE    8'h09 // Resource is not in the appropriate state or ownership:
`define HGRNIC_CMD_STAT_BAD_QPEE_STATE   8'h10 // Attempt to modify a QP/EE which is not in the presumed state:
`define HGRNIC_CMD_STAT_BAD_SEG_PARAM    8'h20 // Bad segment parameters (Address/Size):
`define HGRNIC_CMD_STAT_REG_BOUND        8'h21 // Memory Region has Memory Windows bound to:
`define HGRNIC_CMD_STAT_LAM_NOT_PRE      8'h22 // HCA local attached memory not present:
`define HGRNIC_CMD_STAT_BAD_PKT          8'h30 // Bad management packet (silently discarded):  
`define HGRNIC_CMD_STAT_BAD_SIZE         8'h40 // More outstanding CQEs in CQ than new CQ size: 
/* --------------CMD Status{end}-------------- */


//----------------------{outbox size(in bytes)}begin---------------------//
`define OUTBOX_LEN_QUERY_DEV_LIM    12'h40
`define OUTBOX_LEN_QUERY_ADAPTER    12'h20
`define OUTBOX_LEN_ATTR_PORT_INFO   12'h20
//----------------------{outbox size(in bytes)}end-----------------------//

//----------------------{inbox length(in bytes)}begin--------------------//
`define INBOX_LEN_INIT_HCA     12'h40

`define INBOX_LEN_SW2HW_CQ     12'h40
`define INBOX_LEN_RESIZE_CQ    12'h08
`define INBOX_LEN_SW2HW_EQ     12'h40
`define INBOX_LEN_MODIFY_QP    12'd192 // 12'd164 // 12'h100

`define INBOX_LEN_SW2HW_MPT    12'h40
`define INBOX_LEN_MAP_ICM      
`define INBOX_LEN_WRITE_MTT    

`define OUTBOX_LEN_QUERY_QP    12'd192 // 12'd164 // 12'h100
//----------------------{inbox length(in bytes)}end----------------------//

//--------------{Query device limit}begin--------------//
`define RESVED_QPS   8'h1     /* 2 ^ 1 resved QPs     */
`define RESVED_CQS   8'h0     /* 2 ^ 0 resved CQs     */
`define RESVED_EQS   8'h0     /* 2 ^ 0 resved EQs     */
`define RESVED_MTTS  8'h0     /* 2 ^ 0 resved MTTs    */
`define RESVED_PDS   8'h0     /* 2 ^ 0 resved PDs     */
`define RESVED_LKEYS 8'h0     /* 2 ^ 0 resved LKEYs   */
`define MAX_QP_SZ    16'd13   /* 2 ^ 13 number of WQEs */
`define MAX_CQ_SZ    16'd13   /* 2 ^ 13 number of CQEs */

//`define MAX_QPS      8'd14    /* 2 ^ 14 number of QPs        */
//`define MAX_CQS      8'd13    /* 2 ^ 13 number of CQs        */
`define MAX_QPS      8'd8     /* 2 ^ 8 number of QPs        */
`define MAX_CQS      8'd8     /* 2 ^ 8 number of CQs        */
`define MAX_EQS      8'd5     /* 2 ^ 5 number of EQs         */
`define MAX_MPTS     8'd14    /* 2 ^ 14 number of MPTs       */
`define MAX_PDS      8'd12    /* 2 ^ 12 number of PDs        */
`define MAX_GIDS     8'd0     /* 2 ^ 0 number of GIDs        */
`define MAX_PKEYS    8'd1     /* 2 ^ 1 number of PKEYs       */
`define MAX_MTT_SEG  8'd8     /* one mtt seg is 8 bytes      */
`define QPC_ENTRY_SZ 16'd256  /* QPC entry size is 256 bytes */
`define CQC_ENTRY_SZ 16'd128  /* CQC entry size is 128 bytes */
`define EQC_ENTRY_SZ 16'd64   /* EQC entry size is 64 bytes  */
`define MPT_ENTRY_SZ 16'd64   /* MPT entry size is 64 bytes  */

// beat two
`define ACK_DELAY          4'h0                  /* Useless now */
`define MAX_MTU            4'h5                  /* MTU is 4096 */
`define MAX_PORT_WIDTH     4'd0                  /* Useless now */
`define MAX_VL             4'd15                 /* Useless now */
`define NUM_PORTS          4'd1                  /* 1 port now  */
`define MIN_PAGE_SZ        8'hC                  /* min page size is 2 ^ 12    */
`define MAX_SG             8'h10                 /* num of sg in sq is 16      */
`define MAX_DESC_SZ        16'h0200              /* desc size is 512 bytes     */
`define MAX_SG_RQ          8'h10                 /* num of sg in rq is 16      */
`define MAX_DESC_SZ_RQ     16'h0200              /* desc size is 512 bytes(RQ) */
`define MAX_ICM_SZ         64'h12345678_87650000 /* maximum supported ICM size */
//--------------{Query device limit}end--------------//

//--------------{Query adapter}begin--------------//
`define BOARD_ID 64'h01234567_89abcdef
//--------------{Query adapter}end--------------//

//--------------{AXIS type && opcode && addr && len}begin----------------//
`define AXIS_TYPE_WIDTH     4
`define AXIS_OPCODE_WIDTH   4
`define CEU_CM_HEAD_WIDTH   128     // CEU <-> CM  Interface head width
`define CEU_V2P_HEAD_WIDTH  128     // CEU <-> V2P Interface head width

/*******************************Defined in CTX and V2P Module*********************************************/

// Type, Interact with CtxMgt
`define RD_QP_CTX     4'b0001
`define WR_QP_CTX     4'b0010
`define WR_CQ_CTX     4'b0011
`define WR_EQ_CTX     4'b0100
`define WR_ICMMAP_CTX 4'b0101
`define MAP_ICM_CTX   4'b0110

// Type, Interact with VirtToPhys
`define WR_MPT_TPT    4'b0001
`define WR_MTT_TPT    4'b0010
`define WR_ICMMAP_TPT 4'b0011
`define MAP_ICM_TPT   4'b0100

// Opcode, for RD_QP_CTX
`define RD_QP_ALL     4'b0001

// Opcode, for WR_QP_CTX
`define WR_QP_ALL     4'b0001
`define WR_QP_INVALID 4'b1111

// Opcode, for WR_CQ_CTX
`define WR_CQ_ALL     4'b0001
`define WR_CQ_MODIFY  4'b0010
`define WR_CQ_INVALID 4'b0010

// Opcode, for WR_EQ_CTX
`define WR_EQ_ALL     4'b0001
`define WR_EQ_FUNC    4'b0010
`define WR_EQ_INVALID 4'b0011

// Opcode, for WR_ICMMAP_CTX && WR_ICMMAP_TPT
`define WR_ICMMAP_EN  4'b0001
`define WR_ICMMAP_DIS 4'b0010

// Opcode, for MAP_ICM_CTX && MAP_ICM_TPT
`define MAP_ICM_EN  4'b0001
`define MAP_ICM_DIS 4'b0010

// Opcode, for WR_MPT_TPT
`define WR_MPT_WRITE   4'b0001
`define WR_MPT_INVALID 4'b0010

// Opcode, for WR_MTT_TPT
`define WR_MTT_WRITE   4'b0001
`define WR_MTT_INVALID 4'b0010
/*******************************Defined in CTX and V2P Module*********************************************/


/* --------DBG signal{begin}-------- */
// `define CEU_DBG_LOGIC   1

`define ACC_LOCAL_RW_WIDTH      (1 + `CEU_DATA_WIDTH * 2 + `CEU_DATA_WIDTH + `CEU_DATA_WIDTH)

`define CEU_DBG_WIDTH           (`TOP_DBG_WIDTH + `ACC_CM_DBG_WIDTH + `ACC_LOCAL_DBG_WIDTH + `WR_BOTH_DBG_WIDTH + `WR_V2P_DBG_WIDTH)
`define TOP_DBG_WIDTH           (4 + 4 + 64 + 32 + 64 + 8 + 12)
`define ACC_CM_DBG_WIDTH        (64 + 64 + 12 + 4 + 4)
`define ACC_LOCAL_DBG_WIDTH     (`CEU_DATA_WIDTH * 2 + `CEU_DATA_WIDTH + `CEU_DATA_WIDTH + 3 + 3)
`define WR_BOTH_DBG_WIDTH       (`CEU_CM_HEAD_WIDTH + `CEU_V2P_HEAD_WIDTH + 1 + 1 + 4 + 4)
`define WR_V2P_DBG_WIDTH        (1 + 64 + 64 + 3 + 3)
/* --------DBG signal{end}-------- */

//--------------{AXIS type && opcode && addr && len}end----------------//
