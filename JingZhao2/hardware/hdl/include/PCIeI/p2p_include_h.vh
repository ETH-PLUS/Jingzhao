
`define CFG_BAR_INI_ADDR_BASE   (`P2P_CFG_BASE + 16'h0)
`define CFG_BAR_INI_ADDR_LEN    16'h8000
`define CFG_BAR_TGT_ADDR_BASE   (`P2P_CFG_BASE + 16'h8000)
`define CFG_BAR_TGT_ADDR_LEN    16'h8000
// `define MEM_BAR_TGT_ADDR_BASE

/* --------Head && Data related{begin}-------- */
`define P2P_DATA_W          256
`define P2P_HEAD_W          128

`define P2P_DHEAD_W         64
`define P2P_UHEAD_W         64
/* --------Head && Data related{end}-------- */


/* --------dev->addr table{begin}-------- */
`define D2A_TAB_DEPTH           4

// P2P device type width
`define DEV_TYPE_WIDTH          4

// dev NO. width
`define DEV_NUM_WIDTH           8

/* We allocate 4 pages for one device, so the lower 14 bit is invalid */
`define BAR_ADDR_BASE_WIDTH     50

`define DEV_NIC                 4'd1
`define DEV_DSA                 4'd2
/* --------dev->addr table{end}-------- */

/* --------target related macro{begin}-------- */

`define BAR_DESC_OFFSET         64'h3000

// Maximum number of queues in log (default is 16)
`define QUEUE_NUM_LOG       4
`define QUEUE_NUM           (1 << `QUEUE_NUM_LOG)

// Message byte length width
`define MSG_BLEN_WIDTH      16

// descriptor width in a queue
// | dlid[47:32] | dst_dev[7:0] | src_dev[7:0] | byte_len[15:0] | dlid[31:0] |
// |   16 bit    |     8 bit    |     8 bit    |     16 bit     |   32 bit   |
`define QUEUE_DESC_WIDTH        80

// The depth of descriptor queue in log format(default is 32)
`define QUEUE_DESC_DEPTH_LOG    5

// Queue context width
`define QUEUE_CONTEXT_WIDTH     64

// Number of payload buffers in our design (default is 1K)
`define PBUF_NUM_LOG        10

// the width of payload buffer address
`define BUF_ADDR_WIDTH      `PBUF_NUM_LOG

// payload buffer size in log format (default is 128 bytes)
`define PBUF_SZ_LOG         7
`define PBUF_BLOCK_SZ       (1 << `PBUF_SZ_LOG) /* payload buffer block size in byte length */
/* --------target related macro{end}-------- */

/* --------Debug param{begin}-------- */

// PIO top module signal width
`define P2P_TOP_SIGNAL_W    4800 /* 3268 -> 4800 */

// P2P ini module
`define INI_TOP_SIGNAL_W        1600 /* 1143 -> 1600 */
`define INI_DEV2ADDR_SIGNAL_W   320  /* 240 -> 320 */

// P2P tgt queue struct signal
`define QSTRUCT_TOP_SIGNAL_W    320  /* 268 -> 320 */
`define DESC_QUEUE_SIGNAL_W     7200 /* 6312 -> 7200 */

// P2P tgt module
`define TGT_TOP_SIGNAL_W        3200 /* 2703 -> 3200 */
`define TGT_RECV_SIGNAL_W       64   /* 38 -> 64 */
`define TGT_QSTRUCT_SIGNAL_W    9600 /* 320 + 7200 -> 9600; QSTRUCT_TOP_SIGNAL_W, DESC_QUEUE_SIGNAL_W */
`define TGT_PBUF_SIGNAL_W       640  /* 576 -> 640 */
`define TGT_SEND_SIGNAL_W       640  /* 462 -> 640 */

// PIO top module base addr
`define P2P_TOP_DBG_B           32'd0   /* 4800 ;P2P_TOP_SIGNAL_W */
`define INI_DBG_B               32'd150 /* 3200>1600+320 ;INI_TOP_SIGNAL_W, INI_DEV2ADDR_SIGNAL_W */
`define TGT_DBG_B               32'd250 /* 16000>3200+64+9600+640+640 ;TGT_TOP_SIGNAL_W, TGT_RECV_SIGNAL_W, TGT_QSTRUCT_SIGNAL_W, TGT_PBUF_SIGNAL_W, TGT_SEND_SIGNAL_W */
`define P2P_DBG_SIZE            32'd1000 /* 1000 * 32 = 32000 */
/* --------Debug param{end}-------- */