/* -------Read request Tag{begin}------- */

// Attribute for the DMA Engine
`define MAX_TAG_LOG_SUPPORT     6 /* Supported max number of tag number in one read channel */
`define MAX_RD_CHNL_LOG_SUPPORT 4 /* Supported max number of read channels in log */

`define TAG_NUM_LOG     6
`define TAG_NUM         (1 << `TAG_NUM_LOG)     

// Stores misc information (addr[6:0] and empty[4:0])
// | ADDR[6:0] | EMPTY[4:0] |
`define TAG_MISC        (7+5)

// The first allocated tag
`define TAG_BASE        0

`define DMA_RD_CHNL_NUM_LOG 4 // number of channel in log size, 4 (maximum 16 channels) is default
`define DMA_RD_CHNL_NUM     10 		//CEU(1), SQ(1), RQ(1), QPC(1), CQC(1), EQC(1), MPT(1), MTT(1), TX_REQ(1), RX_REQ(1)

`define DMA_WR_CHNL_NUM_LOG 4 // number of channel in log size, 3 (maximum 8 channels) is default
`define DMA_WR_CHNL_NUM     10		//CEU(1), QPC(1), CQC(1), EQC(1), MPT(1), MTT(1), TX_REQ(1), RX_REQ(1), RX_RESP(1), P2P
/* -------Read request Tag{end}------- */

/* --------DMA data width{begin}-------- */
`define DMA_DATA_W          256
`define DMA_KEEP_W          (`DMA_DATA_W / 32)
`define DMA_W_BCNT          (`DMA_DATA_W/8)
/* --------DMA data width{end}-------- */

/* --------DMA read rsp related{begin}-------- */
`define PROG_FULL_NUM       8
`define RSP_FIFO_DEPTH_LOG  7
/* --------DMA read rsp related{end}-------- */

/* -------axis request interface{begin}------- */
// tuser
/* AXI-Stream request tuser, every request contains only one beat of tuser signal.
 * | Reserved | REQ_TYPE |   Tag  | address | Reserved | DW length | first BE | last BE |
 * | 127:108  | 107:104  | 103:96 |  95:32  |  31:19   |   18:8    |   7:4    |   3:0   |
 */
`define AXIS_TUSER_W    128

`define DMA_READ_REQ    4'h0
`define DMA_WRITE_REQ   4'h1
`define DMA_INT_REQ     4'h2

`define TAG_EMPTY         (8-`TAG_WIDTH)
`define TAG_WIDTH         8  // Actual width of tag in PCIe packet.
// `define TAG_CHNL_WIDTH    (`TAG_WIDTH-`DMA_RD_CHNL_NUM_LOG) // discarded

`define DW_LEN_WIDTH      11
`define FIRST_BE_WIDTH    4
`define LAST_BE_WIDTH     4
/* -------axis request interface{end}------- */


/* ------- DMA head related macro{begin} ------- */
/* *_head (interact with RDMA modules, through an async fifo), valid only in first beat of a packet
 * | Reserved | address | Reserved | Byte length |
 * |  127:96  |  95:32  |  31:13   |    12:0     |
 */
`define DMA_LEN_WIDTH    13
`define DMA_ADDR_WIDTH   64

/* DMA head width */
`define DMA_HEAD_W   128
/* ------- DMA head related macro{end} ------- */

/* ------- PAGE Size {begin}------- */
`define PAGE_SIZE_LOG 12
/* ------- PAGE Size {end}------- */

/* ------- DBG{begin}-------- */
`define ARB_BASE_SIGNAL_W       11

// read response related debug signal
`define RD_RSP_TOP_SIGNAL_W         1600 /* 827 -> 1600 */
`define RSP_DEALIGN_SIGNAL_W        1600 /* 988 -> 1600 */
`define REBUF_TOP_SIGNAL_W          960  /* 711 -> 960 */
`define SUB_RSP_CONCAT_SIGNAL_W     4800 /* 3311 -> 4800 */
`define TAG_BUF_SIGNAL_W            640  /* 537 -> 640 */
`define TAG_MATCHING_SIGNAL_W       1600 /* 693 -> 1600 */
`define WRAPPER_SIGNAL_W            1600 /* 444 -> 1600 */

// rd_req_rsp related debug signal
`define RD_TOP_SIGNAL_W         11200  /* 9716 -> 11200 */
`define RD_REQ_SIGNAL_W         640    /* 440 -> 640 */
`define RREQ_ARB_SIGNAL_W       68     /* 68 -> 320 */
`define TAG_REQ_SIGNAL_W        640    /* 556 -> 640 */
`define TAG_MGMT_SIGNAL_W       640    /* 605 -> 640 */
`define DMA_DEMUX_SIGNAL_W      320    /* 14 -> 320 */
`define RSP_CONCAT_SIGNAL_W     3200 /* 2770 -> 3200; DATA_FIFO_SIGNAL_W */
`define DATA_FIFO_SIGNAL_W      1602 /* 1602 -> 1920 */

// Wr req related debug signal
`define WREQ_TOP_SIGNAL_W           960  /* 776 -> 960 */
`define WREQ_ALIGN_SIGNAL_W         1600 /* 1150 -> 1600 */
`define WREQ_SPLIT_SIGNAL_W         960  /* 906 -> 960 */

// DMA related debug signal
`define DMA_TOP_SIGNAL_W            19200 /* 17275 -> 19200 ;RQ_ASYNC_SIGNAL_W, RC_ASYNC_SIGNAL_W, RRSP_ASYNC_SIGNAL_W */
`define WR_REQ_SIGNAL_W             (`WREQ_TOP_SIGNAL_W+`WREQ_ALIGN_SIGNAL_W+`WREQ_SPLIT_SIGNAL_W)
`define WREQ_ARB_SIGNAL_W           52
`define REQ_ARB_SIGNAL_W            18
`define INT_PROC_SIGNAL_W           107
`define REQ_CONVERT_TOP_SIGNAL_W    818
`define RSP_CONVERT_TOP_SIGNAL_W    936
`define RQ_ASYNC_SIGNAL_W           885
`define RC_ASYNC_SIGNAL_W           34
`define RRSP_ASYNC_SIGNAL_W         84

// read response related debug base !TODO:
`define RD_RSP_TOP_DBG_B    32'd0      /* 827 -> 1600 ;RD_RSP_TOP_SIGNAL_W */
`define RSP_DEALIGN_DBG_B   32'd50     /* 988 -> 1600 ;RSP_DEALIGN_SIGNAL_W */
`define REORDER_BUF_DBG_B   32'd100    /* 960+4800+640=6400 ;REBUF_TOP_SIGNAL_W(960)+SUB_RSP_CONCAT_SIGNAL_W(4800)+TAG_BUF_SIGNAL_W(640) */
`define TAG_MATCHING_DBG_B  32'd300    /* 693 -> 1600 ;TAG_MATCHING_SIGNAL_W */
`define WRAPPER_DBG_B       32'd350    /* 444 -> 1600 ;WRAPPER_SIGNAL_W */
`define RD_RSP_DBG_SIZE     32'd2000   /* In 32bit unit */

// read req rsp related debug base
`define RD_TOP_DBG_B        32'd0       /* 9716 -> 11200 ;RD_TOP_SIGNAL_W */
`define RD_REQ_DBG_B        32'd350     /* 640*9 -> 6400 ;RD_REQ_SIGNAL_W */
`define RREQ_ARB_DBG_B      32'd550     /* 68 -> 320 ;RREQ_ARB_SIGNAL_W */
`define TAG_REQ_DBG_B       32'd560     /* 556 -> 640 ;TAG_REQ_SIGNAL_W */
`define TAG_MGMT_DBG_B      32'd580     /* 605 -> 640 ;TAG_MGMT_SIGNAL_W */
`define RD_RSP_DBG_B        32'd600     /* 2000*32 ;RD_RSP_DBG_SIZE*32 */
`define DMA_DEMUX_DBG_B     32'd2600    /* 14 -> 320 ;DMA_DEMUX_SIGNAL_W */
`define RSP_CONCAT_DBG_B    32'd2610    /* 2770*9 -> 3200*10=32000 ;RSP_CONCAT_SIGNAL_W(3200)*DMA_RD_CHNL_NUM(9) */
`define RD_REQ_RSP_DBG_SIZE 32'd3800    /* In 32bit unit */

// DMA related debug base
`define DMA_TOP_DBG_B       32'd0       /* 17275 -> 19200 ;DMA_TOP_SIGNAL_W */
`define RD_REQ_RSP_DBG_B    32'd600     /* 3800*32 ;RD_REQ_RSP_DBG_SIZE*32 */
`define WR_REQ_DBG_B        32'd4400    /* 3520*8 -> 3520*10=35200 ;WR_REQ_SIGNAL_W(3520)*DMA_WR_CHNL_NUM(8) */
`define WREQ_ARB_DBG_B      32'd5500    /* 52 -> 64 ;WREQ_ARB_SIGNAL_W */
`define REQ_ARB_DBG_B       32'd5402    /* 18 -> 32 ;REQ_ARB_SIGNAL_W */
`define REQ_CONVERT_DBG_B   32'd5403    /* 107+819=926 -> 960 ;INT_PROC_SIGNAL_W(107)+REQ_CONVERT_TOP_SIGNAL_W(818) */
`define RSP_CONVERT_DBG_B   32'd5433    /* 936 -> 960 ;RSP_CONVERT_TOP_SIGNAL_W */
`define DMA_DBG_SIZE        32'd6000    /* In 32bit unit */
/* ------- DBG{end}-------- */
