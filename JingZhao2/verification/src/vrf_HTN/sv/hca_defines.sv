`define QUERY_QP_TEST
////////////////////////////////////////////////////////////
// width, length and size
////////////////////////////////////////////////////////////
`define TCQ                             1
`define DATA_WIDTH                      256
`define DMA_HEAD_WIDTH                  128
`define KEEP_WIDTH                      `DATA_WIDTH / 32
`define QP_ID_WIDTH                     14
`define TLP_FMT_WIDTH                   3
`define TLP_TYPE_WIDTH                  5
`define TLP_TC_WIDTH                    3
`define QPC_SIZE                        128
`define CQC_SIZE                        60
`define EQC_SIZE                        48
`define PAGE_SIZE                       4096
`define HOST_NUM                        2
`define MEM_LINE_SIZE                   256
`define HCR_BIT_SIZE                    224
`define ADDR_WIDTH                      64
`define CQE_SIZE                        32
`define HCR_BYTE_SIZE                   28
`define DB_BYTE_SIZE                    8
`define DW_BYTE_SIZE                    4
`define DW_BIT_SIZE                     32
`define BYTE_BIT_WIDTH                  8
`define DW_ALIGNED_WIDTH                2
`define DW_DATA_WIDTH                   32
`define TWO_DW_WIDTH                    (2 * `DW_DATA_WIDTH)
`define THR_DW_WIDTH                    (3 * `DW_DATA_WIDTH)
`define FOU_DW_WIDTH                    (4 * `DW_DATA_WIDTH)

`define RQ_WQE_BYTE_LEN                 128
`define SQ_WQE_BYTE_LEN                 128

`define QPC_MTU_256                     3'h1
`define QPC_MTU_512                     3'h2
`define QPC_MTU_1024                    3'h3
`define QPC_MTU_2048                    3'h4
`define QPC_MTU_4096                    3'h5

/* This signal indicates the (max payload size & max read request size) 
*  agreed in the communication
* 3'b000 -- 128 B
* 3'b001 -- 256 B
* 3'b010 -- 512 B
* 3'b011 -- 1024B
* 3'b100 -- 2048B
* 3'b101 -- 4096B
*/
// This field sets the maximum TLP payload size. 
// As a Receiver, the logic must handle TLPs as large as the set value. 
// As a Transmitter, the logic must not generate TLPs exceeding the set value.
`define MAX_PAYLOAD                     3'b001
// This field sets the maximum Read Request size for the logic as a Requester. 
// The logic must not generate Read Requests with size exceeding the set value.
`define MAX_READ_REQ                    3'b001
`define MODIFY_QP_DW_CNT                41
`define RC_DESC_DW_SIZE                 3
`define LOG_NUM_WIDTH                   8
`define DEPTH_BIT_WIDTH                 40

`define LOG_NUM_QPS                     8'h10
`define LOG_NUM_CQS                     8'h10
`define LOG_NUM_EQS                     8'h05
`define LOG_MPT_SZ                      8'h11

`define WQE_NEXT_SEG_DW                 4
`define WQE_DATA_SEG_DW                 4
`define WQE_RADDR_SEG_DW                4

`define VRF_SQ_BYTE_SIZE                4096
`define VRF_RQ_BYTE_SIZE                4096

`define MPT_ITEM_SIZE                   64

////////////////////////////////////////////////////////////
// address
////////////////////////////////////////////////////////////
`define HCR_BAR_ADDR                    `ADDR_WIDTH'h0000_0000_0000_0000
`define DB_BAR_ADDR                     `ADDR_WIDTH'h0000_0000_0000_0000
`define ETH_BAR_ADDR                    `ADDR_WIDTH'h0000_0000_1000_0000

`define INBOX_ADDR                      `ADDR_WIDTH'h0000_0000_1234_1000
`define OUTBOX_ADDR                     `ADDR_WIDTH'h0000_0000_1234_2000
`define DATA_RECV_BUFF_GAP              `ADDR_WIDTH'h0000_0001_0000_0000
`define SQ_RQ_GAP                       `ADDR_WIDTH'h0000_0000_0080_0000

`define CQ_BASE_VADDR                   `ADDR_WIDTH'h0000_0000_0010_0000
`define DATA_BASE_VADDR                 `ADDR_WIDTH'h

`define ICM_BASE                        `ADDR_WIDTH'h0000_1000_0000_0000 // base address of ICM space in memory

`define MTT_OFFSET                      `ADDR_WIDTH'h0000_0000_0000_0000
`define QPC_OFFSET                      `ADDR_WIDTH'h0000_1000_0000_0000
`define CQC_OFFSET                      `ADDR_WIDTH'h0000_2000_0000_0000
`define MPT_OFFSET                      `ADDR_WIDTH'h0000_3000_0000_0000
`define EQC_OFFSET                      `ADDR_WIDTH'h0000_4000_0000_0000

`define DATA_BASE                       `ADDR_WIDTH'h8000_0000_0000_0000

`define MSIX_ITR_VEC_BASE               `ADDR_WIDTH'h0000_0000_0000_5400

////////////////////////////////////////////////////////////
// type
////////////////////////////////////////////////////////////
`define ICM_QPC_TYP                     1
`define ICM_CQC_TYP                     2
`define ICM_EQC_TYP                     5
`define ICM_MPT_TYP                     3
`define ICM_MTT_TYP                     4

////////////////////////////////////////////////////////////
// numbers
////////////////////////////////////////////////////////////
`define MAX_PROC_NUM                    2048

`define INIT_HCA_INBOX_DW_CNT           16
`define DEV_LIM_DW_CNT                  16
`define ADAPTER_DW_CNT                  8
`define QPC_DW_CNT                      48

`define     MAX_HOST_NUM                2
`define     MAX_PROC_NUM                2048
`define     MAX_QP_NUM                  16384
`define     MAX_DB_NUM                  30
`define     MAX_WQE_NUM                 4096
`define     MAX_PAGE_NUM                1024

`define     MTT_ICM_PAGE_LIMIT          512
`define     MPT_ICM_PAGE_LIMIT          512
`define     QPC_ICM_PAGE_LIMIT          1024
`define     CQC_ICM_PAGE_LIMIT          256

////////////////////////////////////////////////////////////
// time
////////////////////////////////////////////////////////////
`define RST_DELAY                       1000
`define AFTER_RST_DELAY                 100000
`define DL                              #1
`define READ_GO_GAP                     30
// `define CFG_COMM_GAP                    1000
`define CFG_GAP                         5  // time gap between master driver sends two item to DUT
`define CQE2SCB_GAP                     2000 // time gap between slave monitor receives a CQE
                                             // and sends it to scoreboard
`define VALID_GAP                       64
`define READY_GAP                       64
`define PCIE_CLK_PERIOD                 10  // nanosecond
`define RDMA_CLK_PERIOD                 10  // nanosecond
`define BREAKTIME                       5000

////////////////////////////////////////////////////////////
// code
////////////////////////////////////////////////////////////
`define PCIE_MEM_RD                     4'b0000
`define PCIE_MEM_WR                     4'b0001
`define CQE_OWNER_SW                    8'b0000_0000
`define CQE_OWNER_HW                    8'b1000_0000

////////////////////////////////////////////////////////////
// others
////////////////////////////////////////////////////////////
`define CMD_POLL_TOKEN                  16'hffff_ffff

`define HCR_BAR_ID                      0
`define DB_BAR_ID                       2

// `define QPC_BASE_PATH                   "hca_tb_top.hca_dut.RDMA_Top.ctxmgt.ctxmdata.qv_qpc_base"
// `define CQC_BASE_PATH                   "hca_tb_top.hca_dut.RDMA_Top.ctxmgt.ctxmdata.qv_cqc_base"
// `define EQC_BASE_PATH                   "hca_tb_top.hca_dut.RDMA_Top.ctxmgt.ctxmdata.qv_eqc_base"
// `define MPT_BASE_PATH                   "hca_tb_top.hca_dut.RDMA_Top.VirtToPhys.tptmdata.ceu_tptm_proc.mpt_base"
// `define MTT_BASE_PATH                   "hca_tb_top.hca_dut.RDMA_Top.VirtToPhys.tptmdata.ceu_tptm_proc.mtt_base"

//---------------------------{type define}begin--------------------------//
typedef bit [`ADDR_WIDTH-1 : 0] mem_addr_typ;
typedef bit [`BYTE_BIT_WIDTH-1 : 0] byte_typ;
typedef int unsigned uint;
typedef longint unsigned ulint;
typedef enum {FALSE, TRUE} bool;
typedef bit [`ADDR_WIDTH - 1 : 0] addr64_typ;
typedef bit [`ADDR_WIDTH - 1 : 0] addr;

typedef bit [`DW_DATA_WIDTH-1:0] dw_typ;
typedef bit [`TWO_DW_WIDTH-1:0] two_dw_typ;
typedef bit [`THR_DW_WIDTH-1:0] thr_dw_typ;
typedef bit [`FOU_DW_WIDTH-1:0] fou_dw_typ;

typedef enum {SERV_INIT, RC, UC, RD, UD} e_service_type;
typedef enum {OP_INIT, WRITE, READ, SEND, RECV} e_op_type;

typedef bit [10:0] pid_t;

typedef struct {
    bit [7      : 0] nreq;
    bit [15     : 0] sq_head;
    bit              f0;
    bit [4      : 0] opcode;
    bit [23     : 0] qp_num;
    bit [7      : 0] size0;
    bit [10     : 0] proc_id;
    // int host_id;
} doorbell;

typedef struct {
    bit [31     : 0] opt_param_mask;
    bit [31     : 0] flags;
    bit [7      : 0] mtu_msgmax;
    bit [7      : 0] rq_entry_sz_log;            
    bit [7      : 0] sq_entry_sz_log;            
    bit [7      : 0] rlkey_arbel_sched_queue;   // no use
    bit [31     : 0] usr_page;                  // no use
    bit [31     : 0] local_qpn;
    bit [31     : 0] remote_qpn;
    bit [31     : 0] port_pkey;
    bit [7      : 0] rnr_retry;
    bit [7      : 0] g_mylmc;                   // no use
    // bit [15     : 0] rlid;                      // no use
    bit [7      : 0] ackto;                     // no use
    bit [7      : 0] mgid_index;                // no use
    bit [7      : 0] static_rate;               // no use
    bit [7      : 0] hop_limit;                 // no use
    bit [31     : 0] sl_tclass_flowlabel;       // no use
    bit [127    : 0] rgid;                      // no use
    // bit [15     : 0] dlid;
    // bit [15     : 0] slid;
    bit [47     : 0] smac;
    bit [47     : 0] dmac;
    bit [31     : 0] sip;
    bit [31     : 0] dip;
    bit [31     : 0] pd;
    bit [31     : 0] wqe_base;                  // no use
    bit [31     : 0] wqe_lkey;                  // no use
    bit [31     : 0] next_send_psn;
    bit [31     : 0] cqn_snd;
    bit [31     : 0] snd_wqe_base_l;
    bit [31     : 0] snd_wqe_len;               // total length of SQ in byte
    // bit [31     : 0] snd_db_index;              // no use
    bit [31     : 0] last_acked_psn;
    bit [31     : 0] ssn;                       // no use
    bit [31     : 0] rnr_nextrecvpsn;
    bit [31     : 0] ra_buff_indx;              // no use
    bit [31     : 0] cqn_rcv;                   // no use
    bit [31     : 0] rcv_wqe_base_l;
    bit [31     : 0] rcv_wqe_len;               // total length of RQ in byte
    // bit [31     : 0] rcv_db_index;              // no use
    bit [31     : 0] qkey;
    bit [31     : 0] rmsn;                      // no use
    bit [15     : 0] rq_wqe_counter;            // no use
    bit [15     : 0] sq_wqe_counter;            // no use 
    // addr             head;
    // addr             tail;
} qp_context;

typedef struct {
    bit [31     : 0] flags;
    bit [63     : 0] start;
    bit [7      : 0] logsize; // log of CQE number
    bit [23     : 0] usrpage;
    bit [31     : 0] comp_eqn;
    bit [31     : 0] pd;
    bit [31     : 0] lkey;
    bit [31     : 0] cqn;
} cq_context;

typedef struct {
    // flags:     // 0xf << 28: HGHCA_MPT_FLAG_SW_OWNS
    // 1   << 17: HGHCA_MPT_FLAG_MIO
    bit [31     : 0] flags; 
    bit [31     : 0] page_size; // log(actual size) - 12
    bit [31     : 0] key; // 8 bit random + 24 bit offset
    bit [31     : 0] pd;
    bit [63     : 0] start; // start virtual address of the memory region
    bit [63     : 0] length;
    bit [31     : 0] lkey; // no use
    bit [31     : 0] window_count; // no use
    bit [31     : 0] window_count_limit; // no use
    bit [63     : 0] mtt_seg; // start mtt item index
    bit [31     : 0] mtt_sz; // no use
} mpt;

typedef struct {
    bit [63     : 0] start_index;
    bit [63     : 0] phys_addr[$];
} mtt_unit;

typedef struct {
    addr index;
    addr phys_addr;
} mtt;

typedef struct {
    bit [63     : 0] qpc_base;
    bit [7      : 0] log_num_qps;
    bit [63     : 0] cqc_base;
    bit [7      : 0] log_num_cqs;
    bit [63     : 0] eqc_base;
    bit [7      : 0] log_num_eqs;
    bit [63     : 0] mpt_base;
    bit [7      : 0] log_mpt_sz;
    bit [63     : 0] mtt_base;
} icm_base;

typedef struct {
    bit [63     : 0] virt[$];
    bit [63     : 0] page[$];
    bit [11     : 0] page_num;
} icm_map;

//------------------------WQE Begin-----------------------//
typedef struct {
    bit [25     : 0] next_wqe;
    bit [4      : 0] next_opcode;
    bit [23     : 0] next_ee;
    bit              next_dbd;
    bit              next_fence;
    bit [5      : 0] next_wqe_size; // 16B
    bit              cq;
    bit              evt;
    bit              solicit;
    bit [31     : 0] imm_data;
    bit              res_0;
    bit              res_1;
    bit [27     : 0] res_2;
} wqe_next_seg;

typedef struct {
    bit [31     : 0] byte_num;
    bit [7      : 0] data[$];
} wqe_inline_seg;

typedef struct {
    bit [31     : 0] byte_count;
    bit [31     : 0] lkey;
    bit [63     : 0] addr;
} wqe_data_seg_unit;

typedef struct {
    bit [63     : 0] raddr;
    bit [31     : 0] rkey;
} wqe_raddr_seg;

typedef struct {
    bit [127    : 0] zero;
} wqe_zero_seg; // used in RECV WQE

typedef struct {
    bit [7      : 0] port;
    bit [47     : 0] smac;
    bit [47     : 0] dmac;
    bit [31     : 0] sip;
    bit [31     : 0] dip;
    bit [31     : 0] dqpn;
    bit [31     : 0] qkey;
} wqe_ud_seg;

typedef struct {
    wqe_next_seg next_seg;
    wqe_inline_seg inline_seg;
    wqe_data_seg_unit data_seg[$];
    wqe_raddr_seg raddr_seg;
    wqe_zero_seg zero_seg;
    wqe_ud_seg ud_seg;
} wqe;
//------------------------WQE End-----------------------//

// CQE segments
typedef struct {
    bit [31     : 0] my_qpn;
    bit [31     : 0] my_ee;
    bit [31     : 0] rqpn;
    bit [15     : 0] rlid;
    bit [7      : 0] g_mlpath;
    bit [7      : 0] sl_ipok;
    bit [31     : 0] imm_etype_pkey_eec;
    bit [31     : 0] byte_cnt;
    bit [31     : 0] wqe;
    bit [7      : 0] owner;
    bit [7      : 0] is_send;
    bit [7      : 0] opcode;
    bit [7      : 0] vender_err;
    bit [7      : 0] syndrome;
    bit [15     : 0] db_cnt;
} cqe;

typedef struct {
    int src_host;
    int dst_host;
    addr src_addr;
    addr dst_addr;
    int length;
} check_mem_unit;

//---------------------------{type define}end----------------------------//

//---------------------------{macro function}begin-----------------------//
`define PA_DATA(PROC_ID, QPN) {5'b0, PROC_ID[10:0], 1'b1, QPN[13:0], 33'b0}
`define PA_CQ(PROC_ID, CQN) {5'b0, PROC_ID[10:0], 15'b1, CQN[12:0], 20'b0}
`define PA_QP(PROC_ID, QPN) {5'b0, PROC_ID[10:0], 10'b1, QPN[13:0], 24'b0}

`define VA_DATA(QPN) {16'b0, 1'b1, QPN[13:0], 33'b0}
`define VA_CQ(CQN) {16'b0, 15'b1, CQN[12:0], 20'b0}
`define VA_QP(QPN) {16'b0, 10'b1, QPN[13:0], 24'b0}

`define VA(ADDR) {16'b0, ADDR[47:0]}
`define PA(PROC_ID, ADDR) {5'b0, PROC_ID[10:0], ADDR[47:0]}
//---------------------------{macro function}end-------------------------//


// From Kang Ning
//------------------QP STATE BEGIN---------------------//
`define HGHCA_QP_STATE_RST              0
`define HGHCA_QP_STATE_INIT             1
`define HGHCA_QP_STATE_RTR              2
`define HGHCA_QP_STATE_RTS              3
`define HGHCA_QP_STATE_SQE              4
`define HGHCA_QP_STATE_SQD              5
`define HGHCA_QP_STATE_ERR              6

`define HGHCA_QP_ST_RC                  0
`define HGHCA_QP_ST_UC                  1
`define HGHCA_QP_ST_RD                  2
`define HGHCA_QP_ST_UD                  3

`define IB_QP_STATE                     32'h0000_0001
`define IB_QP_CUR_STATE                 32'h0000_0002
`define IB_QP_EN_SQD_ASYNC_NOTIFY       32'h0000_0004
`define IB_QP_ACCESS_FLAGS              32'h0000_0008
`define IB_QP_PKEY_INDEX                32'h0000_0010
`define IB_QP_PORT                      32'h0000_0020
`define IB_QP_QKEY                      32'h0000_0040
`define IB_QP_AV                        32'h0000_0080
`define IB_QP_PATH_MTU                  32'h0000_0100
`define IB_QP_TIMEOUT                   32'h0000_0200
`define IB_QP_RETRY_CNT                 32'h0000_0400
`define IB_QP_RNR_RETRY                 32'h0000_0800
`define IB_QP_RQ_PSN                    32'h0000_1000
`define IB_QP_MAX_QP_RD_ATOMIC          32'h0000_2000
`define IB_QP_ALT_PATH                  32'h0000_4000
`define IB_QP_MIN_RNR_TIMER             32'h0000_8000
`define IB_QP_SQ_PSN                    32'h0001_0000
`define IB_QP_MAX_DEST_RD_ATOMIC        32'h0002_0000
`define IB_QP_PATH_MIG_STATE            32'h0004_0000
`define IB_QP_CAP                       32'h0008_0000
`define IB_QP_DEST_QPN                  32'h0010_0000
//------------------QP STATE END---------------------//

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

/* -------Write CxtMgt && Virt2Phys CMD{begin}------- */
// with req data
`define CMD_INIT_HCA      12'h007 // in_param -- inbox, no out_param

// without req data, without resp
`define CMD_CLOSE_HCA     12'h008 // no in_param, no out_param
/* -------Write CxtMgt && Virt2Phys CMD{end}------- */

/* -------Write CxtMgt || Virt2Phys{begin}------- */
// with req data
`define CMD_MAP_ICM       12'hffa // in_param -- inbox, no out_param, in_modifier -- nent, op_modifier -- module selection
`define CMD_UNMAP_ICM     12'hff9 // in_param -- virt addr, no out_param, in_modifier -- page count, op_modifier -- module selection
/* -------Write CxtMgt || Virt2Phys{end}------- */

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
//----------------------------{CMD decode}end----------------------------//

//--------------{Query device limit}begin--------------//
`define RESVED_QPS   8'h1 // 
`define RESVED_CQS   8'h2
`define RESVED_EQS   8'h3
`define RESVED_MTTS  8'h4
`define RESVED_PDS   8'h2
`define RESVED_LKEYS 8'h0
`define MAX_QP_SZ    16'd11 // pow(2, 11) wqe num in one queue
`define MAX_CQ_SZ    16'd11

`define MAX_QPS      8'd14
`define MAX_CQS      8'd13
`define MAX_EQS      8'd0
`define MAX_MPTS     8'd14
`define MAX_PDS      8'd12 
`define MAX_GIDS     8'd0
`define MAX_PKEYS    8'd1
`define MAX_MTT_SEG  8'd3 //
`define QPC_ENTRY_SZ 16'd256
// `define CQC_ENTRY_SZ 16'd128
`define CQC_ENTRY_SZ 16'd64
`define EQC_ENTRY_SZ 16'd64
`define MPT_ENTRY_SZ 16'd64

// beat two
`define ACK_DELAY          4'h8
`define MAX_MTU            4'h0
`define MAX_PORT_WIDTH     4'd1
`define MAX_VL             4'd15
`define NUM_PORTS          4'd1
`define MIN_PAGE_SZ        8'h00
`define MAX_SG             8'h10 // data seg number
`define MAX_DESC_SZ        16'h0080 // wqe size
`define MAX_SG_RQ          8'h10
`define MAX_DESC_SZ_RQ     16'h0010
`define MAX_ICM_SZ         64'h12345678_87650000
//--------------{Query device limit}end--------------//

//--------------{Doorbell Opcode}begin---------------//
`define     VERBS_SEND                 5'b01010
`define     VERBS_SEND_WITH_IMM        5'b01011
`define     VERBS_RDMA_WRITE           5'b01000
`define     VERBS_RDMA_WRITE_WITH_IMM  5'b01001
`define     VERBS_RDMA_READ            5'b10000
`define     VERBS_CMP_AND_SWAP         5'b10001
`define     VERBS_FETCH_AND_ADD        5'b10010
//--------------{Doorbell Opcode}end-----------------//

//-----------------{MPT flags}begin------------------//
`define     MPT_FLAG_SW_OWNS

//--------------{Query adapter}begin--------------//
`define BOARD_ID 64'h01234567_89abcdef
//--------------{Query adapter}end--------------//

// `define wait_signal(chnl)   \
//     while(1) begin  \
//         wait (chnl);  \
//         repeat(2) `TD; \
//         if(chnl)  \
//             break;  \
//         else \
//             @ (posedge nic_if.clk);   \
//     end
