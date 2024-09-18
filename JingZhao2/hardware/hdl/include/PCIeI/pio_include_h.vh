/* --------PCIe Interface related{begin}-------- */
`define PCIEI_DATA_W        256
`define PCIEI_KEEP_W        (`PCIEI_DATA_W / 32)
`define PCIEI_KEEP_MASK     ({`PCIEI_KEEP_W{1'd1}})
/* --------PCIe Interface related{end}-------- */

/* --------PIO data & head width {begin}-------- */
`define ALIGN_HEAD_W        128

`define PIO_USER_W          140
`define PIO_HEAD_W          132
`define PIO_DATA_W          `PCIEI_DATA_W
`define PIO_KEEP_W          (`PIO_DATA_W / 32)
/* --------PIO data & head width {end}-------- */

/* --------RDMA BAR Space {begin}-------- */
`define RDMA_MSIX_NUM_LOG   6
`define RDMA_MSIX_DATA_W    128
/* --------RDMA BAR Space {end}-------- */

/* --------BAR space BASE & LEN{begin}-------- */
`define BAR0_WIDTH              20

`define DOORBELL_BASE           12'h00
`define ARM_CQ_BASE             12'h10
`define ARM_EQ_BASE             12'h20

/* Bar0-1, who owns ether and hcr register, 
   has 1MB memory ([19:0] is valid).
 */
`define HCR_BASE         20'h0     
`define ETH_BASE         20'h1000  
`define ETH_LEN          20'h4000  
`define ETH_INT_BASE     20'h5000  
`define ETH_INT_LEN      20'h400   
`define HCA_INT_BASE     20'h5400  
`define HCA_INT_LEN      20'h400   
`define P2P_CFG_BASE     20'h1_0000
`define P2P_CFG_LEN      20'h1_0000
`define P2P_MEM_BASE     20'h2_0000
`define P2P_MEM_LEN      20'h8_0000

`define CMD_RST_OFFSET      20'h0_0F10
`define INIT_DONE_OFFSET    20'h0_0F20
/* --------BAR space BASE & LEN{end}-------- */

/* --------Debug param{begin}-------- */
// Debug related
`define PCIEI_APB_DBG

// RW_DATA for one SRAM
`define SRAM_RW_DATA_W          8

// PIO top module signal width
`define STD_PIO_TOP_SIGNAL_W    9600 /* 8643 -> 9600 ;7683+CC_ASYNC_SIGNAL_W */
`define CQ_PARSER_SIGNAL_W      960  /* 745 -> 960 */
`define CC_ASYNC_SIGNAL_W       960  /* 809 -> 960 */
`define CC_COMPOSER_SIGNAL_W    640  /* 481 -> 640 */
`define PIO_REQ_SIGNAL_W        320  /* 276 -> 320 ;PIO_DEMUX_SIGNAL_W */
`define PIO_RRSP_SIGNAL_W       9600 /* 6442 -> 9600 ;PIO_MUX_SIGNAL_W+PIO_DW_ALIGN_SIGNAL_W+PIO_RSP_SPLIT_SIGNAL_W */
`define RDMA_UAR_SIGNAL_W       320  /* 211 -> 320 */
`define RDMA_INT_SIGNAL_W       1600 /* 1013 -> 1600 */
`define RDMA_HCR_SIGNAL_W       640  /* 538 -> 640 ;RDMA_HCR_SPACE_SIGNAL_W */
`define ETH_CFG_SIGNAL_W        960  /* 850 -> 960 */
`define P2P_ACCESS_SIGNAL_W     1600 /* 1147 -> 1600 */

// pio_req module
`define PIO_DEMUX_SIGNAL_W      9

// pio_rrsp module
`define PIO_MUX_SIGNAL_W        1621
`define PIO_DW_ALIGN_SIGNAL_W   1286
`define PIO_RSP_SPLIT_SIGNAL_W  1302

// pio_rdma_hcr module
`define RDMA_HCR_SPACE_SIGNAL_W 218

// PIO top module base addr
`define PIO_TOP_DBG_B           32'd0   /* 9600 ;STD_PIO_TOP_SIGNAL_W */
`define CQ_PARSER_DBG_B         32'd300 /* 960 ;CQ_PARSER_SIGNAL_W */
`define CC_COMPOSER_DBG_B       32'd330 /* 640 ;CC_COMPOSER_SIGNAL_W */
`define PIO_REQ_DBG_B           32'd350 /* 320 ;PIO_REQ_SIGNAL_W */
`define PIO_RRSP_DBG_B          32'd360 /* 9600 ;PIO_RRSP_SIGNAL_W */
`define RDMA_UAR_DBG_B          32'd660 /* 320 ;RDMA_UAR_SIGNAL_W */
`define RDMA_INT_DBG_B          32'd670 /* 1600 ;RDMA_INT_SIGNAL_W */
`define RDMA_HCR_DBG_B          32'd750 /* 640 ;RDMA_HCR_SIGNAL_W */
`define ETH_CFG_DBG_B           32'd770 /* 960 ;ETH_CFG_SIGNAL_W */
`define P2P_ACCESS_DBG_B        32'd800 /* 1600 ;P2P_ACCESS_SIGNAL_W */
`define STD_PIO_DBG_SIZE        32'd1000 /* In 32bit unit */

// PCIe interface debug base
`define DMA_DBG_BASE        32'h1000_0000 /* 32'd6000 ;DMA_DBG_SIZE */
`define PIO_DBG_BASE        32'h1000_1770 /* 32'd1000 ;STD_PIO_DBG_SIZE */
`define P2P_DBG_BASE        32'h1000_1B58 /* 32'd1000 ;P2P_DBG_SIZE */
`define PCIEI_DBG_SIZE      32'h1000_1F40 /* 32'd8000 */
/* --------Debug param{end}-------- */
