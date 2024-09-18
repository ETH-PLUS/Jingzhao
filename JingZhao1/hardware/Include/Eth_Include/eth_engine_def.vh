// `define XILINX_FPGA

`define FW_ID_REG                     32'h0000
`define FW_ID_VENDOR                  32'h0004
`define IF_FEATURE_REG                32'h0008
`define TX_QUEUE_COUNT_REG            32'h000C
`define TX_QM_BASE_ADDR_REG           32'h0010
`define TX_CPL_QUEUE_COUNT_REG        32'h0014
`define TX_CQM_BASE_ADDR_REG          32'h0018
`define RX_QUEUE_COUNT_REG            32'h001C
`define RX_QM_BASE_ADDR_REG           32'h0020
`define RX_CPLQUEUE_COUNT_REG         32'h0028
`define RX_CQM_BASE_ADDR_REG          32'h002C
`define NIC_TX_MTU                    32'h003C
`define NIC_RX_MTU                    32'h0040
`define TX_START_SCHEDULER            32'h0050
`define TX_SHUTDOWN_MSIX              32'h0054

`define QUEUE_BASE_ADDR_REG             32'h000
`define QUEUE_ACTIVE_LOG_SIZE_REG       32'h008
`define QUEUE_CPL_QUEUE_INDEX_REG       32'h00C
`define QUEUE_HEAD_PTR_REG              32'h010
`define QUEUE_TAIL_PTR_REG              32'h018
`define CPL_QUEUE_BASE_ADDR_REG         32'h020
`define CPL_QUEUE_ACTIVE_LOG_SIZE_REG   32'h028
`define CPL_QUEUE_INTERRUPT_INDEX_REG   32'h02C
`define CPL_QUEUE_HEAD_PTR_REG          32'h030
`define CPL_QUEUE_TAIL_PTR_REG          32'h038
`define QUEUE_STRIDE                    32'h00000040


// fifo depth
`define RX_PKT_FIFO_DEPTH         512
`define RX_PKT_ELEMENT_DEPTH      256

`define RX_ROCE_PKT_FIFO_DEPTH    512
`define RX_ROCE_CSUM_FIFO_DEPTH   32

`define TX_PKT_FIFO_DEPTH         512
`define TX_PKT_ELEMENT_DEPTH      256

`define TX_ROCE_PKT_FIFO_DEPTH    512
`define TX_ROCE_CSUM_FIFO_DEPTH   32

`define RX_VLAN_FIFO_DEPTH        8
`define TX_SCHED_FIFO_DEPTH       32
`define RX_DISTR_FIFO_DEPTH       8



`define CSUM_WIDTH          16
`define HASH_WIDTH          32
`define HASH_TYPE_WIDTH     4

`define ROCE_DESC_WIDTH     192
`define ROCE_DTYP_WIDTH     4
`define ROCE_LEN_WIDTH      16


`define IP_WIDTH            32
`define MAC_WIDTH           48
`define PORT_WIDTH          48

`define CSUM_START_WIDTH    8

// `define DMA_ADDR_WIDTH      256

`define DMA_ADDR_WIDTH      64
`define DMA_DATA_WIDTH      256
`define DMA_HEAD_WIDTH      128
`define XBAR_USER_WIDTH      7
`define ETH_LEN_WIDTH       16
// `define DMA_KEEP_WIDTH     (`DMA_DATA_WIDTH / 8)
`define DMA_KEEP_WIDTH      32
`define IRQ_MSG             32
`define QUEUE_INDEX_WIDTH   16

`define AXIL_DATA_WIDTH     32
`define AXIL_STRB_WIDTH     4

`define DESC_SIZE           16
`define CPL_SIZE            32

`define MAC_DATA_WIDTH      64
`define MAC_KEEP_WIDTH      (`MAC_DATA_WIDTH / 8)

`define MSI_NUM_WIDTH       16    
`define STATUS_WIDTH        8    
`define QUEUE_NUMBER_WIDTH  16
  
`define VLAN_TAG_WIDTH      16

`define CPL_STATUS_WIDTH      32

`define DBG_DATA_WIDTH       32

`define CHECKSUM_UTIL_DEG_REG_NUM    25 
`define RX_CHECKSUM_SELF_DEG_REG_NUM    26
`define RX_CHECKSUM_DEG_REG_NUM    (`RX_CHECKSUM_SELF_DEG_REG_NUM + `CHECKSUM_UTIL_DEG_REG_NUM)  // 51

`define QUEUE_MANAGER_DEG_REG_NUM    20
`define DESC_FETCH_DEG_REG_NUM    51 
`define DESC_PROVIDER_DEG_REG_NUM   (`QUEUE_MANAGER_DEG_REG_NUM + `DESC_FETCH_DEG_REG_NUM)  //71

`define MAC_FIFO_DEG_REG_NUM    41
`define RX_MACPROC_DEG_REG_NUM    4
`define RX_HASH_DEG_REG_NUM    34
`define RX_VLAN_DEG_REG_NUM    28
`define RX_MAC_ENGINE_SELF_DEG_REG_NUM    4
`define RX_MAC_ENGINE_DEG_REG_NUM   (`MAC_FIFO_DEG_REG_NUM + `RX_MACPROC_DEG_REG_NUM + `RX_HASH_DEG_REG_NUM + \
                                `RX_CHECKSUM_DEG_REG_NUM + `RX_MAC_ENGINE_SELF_DEG_REG_NUM + `RX_VLAN_DEG_REG_NUM) // 162

`define MAC_FIFO_DEG_REG_OFFSET                  0
`define RX_MACPROC_DEG_REG_OFFSET                (`RX_MACPROC_DEG_REG_NUM + `MAC_FIFO_DEG_REG_OFFSET) 
`define RX_HASH_DEG_REG_OFFSET                   (`RX_HASH_DEG_REG_NUM + `RX_MACPROC_DEG_REG_OFFSET  )
`define RX_CHECKSUM_DEG_REG_OFFSET               (`RX_CHECKSUM_DEG_REG_NUM + `RX_HASH_DEG_REG_OFFSET )
`define RX_MAC_ENGINE_SELF_DEG_REG_OFFSET        (`RX_MAC_ENGINE_SELF_DEG_REG_NUM + `RX_CHECKSUM_DEG_REG_OFFSET ) 
`define RX_VLAN_DEG_REG_OFFSET                   (`RX_VLAN_DEG_REG_NUM + `RX_MAC_ENGINE_SELF_DEG_REG_OFFSET)

`define TX_SCHD_RR_DEG_REG_NUM    4
`define TX_MACPROC_SELF_DEG_REG_NUM    32
`define TX_MACPROC_DEG_REG_NUM    (`TX_MACPROC_SELF_DEG_REG_NUM + `CHECKSUM_UTIL_DEG_REG_NUM)  //57
`define TX_MAC_ENGINE_DEG_REG_NUM    (`TX_MACPROC_DEG_REG_NUM + `TX_SCHD_RR_DEG_REG_NUM)  // 61


`define NCSR_MANAGER_DEG_REG_NUM    22
`define MSIX_MANAGER_DEG_REG_NUM    20
`define RX_DISTRIBUTER_DEG_REG_NUM  42
`define RX_ROCEPROC_DEG_REG_NUM     37
`define TX_ROCEDESC_DEG_REG_NUM     6
`define TX_ROCEPROC_DEG_REG_NUM     32

// `define ETH_ENGINE_TOP_DEG_REG_NUM   (`NCSR_MANAGER_DEG_REG_NUM +     \  // 22
//                                     `MSIX_MANAGER_DEG_REG_NUM +       \  // 20
//                                     `DESC_PROVIDER_DEG_REG_NUM +      \  // 71
//                                     `RX_MAC_ENGINE_DEG_REG_NUM +      \  // 162
//                                     `RX_ROCEPROC_DEG_REG_NUM +        \  // 37
//                                     `RX_DISTRIBUTER_DEG_REG_NUM +     \  // 42
//                                     `DESC_PROVIDER_DEG_REG_NUM +      \  // 71
//                                     `TX_MAC_ENGINE_DEG_REG_NUM +      \  // 61
//                                     `TX_ROCEDESC_DEG_REG_NUM +        \  //  6
//                                     `TX_ROCEPROC_DEG_REG_NUM)             // 32
//                                                                          // total : 524

`define  NCSR_MANAGER_DEG_REG_OFFSET      0   
`define  MSIX_MANAGER_DEG_REG_OFFSET          (`NCSR_MANAGER_DEG_REG_NUM    +   `NCSR_MANAGER_DEG_REG_OFFSET)     
`define  RX_DESC_PROVIDER_DEG_REG_OFFSET      (`MSIX_MANAGER_DEG_REG_NUM    +   `MSIX_MANAGER_DEG_REG_OFFSET)    
`define  RX_MAC_ENGINE_DEG_REG_OFFSET         (`DESC_PROVIDER_DEG_REG_NUM   +   `RX_DESC_PROVIDER_DEG_REG_OFFSET)    
`define  RX_ROCEPROC_DEG_REG_OFFSET           (`RX_MAC_ENGINE_DEG_REG_NUM   +   `RX_MAC_ENGINE_DEG_REG_OFFSET)      
`define  RX_DISTRIBUTER_DEG_REG_OFFSET        (`RX_ROCEPROC_DEG_REG_NUM     +   `RX_ROCEPROC_DEG_REG_OFFSET)   
`define  TX_DESC_PROVIDER_DEG_REG_OFFSET      (`RX_DISTRIBUTER_DEG_REG_NUM  +   `RX_DISTRIBUTER_DEG_REG_OFFSET)    
`define  TX_MAC_ENGINE_DEG_REG_OFFSET         (`DESC_PROVIDER_DEG_REG_NUM   +   `TX_DESC_PROVIDER_DEG_REG_OFFSET)    
`define  TX_ROCEDESC_DEG_REG_OFFSET           (`TX_MAC_ENGINE_DEG_REG_NUM   +   `TX_MAC_ENGINE_DEG_REG_OFFSET)      
`define  TX_ROCEPROC_DEG_REG_OFFSET           (`TX_ROCEDESC_DEG_REG_NUM     +   `TX_ROCEDESC_DEG_REG_OFFSET)        


`define ETH_CHIP_DEBUG 


`define RW_DATA_NUM_MAC_FIFO          1  // 512 x 257
`define RW_DATA_NUM_RX_MACENGINE_SELF 4  // 256 x 24 x 3  256 x 32
`define RW_DATA_NUM_RX_MACENGINE      (`RW_DATA_NUM_MAC_FIFO + `RW_DATA_NUM_RX_MACENGINE_SELF)  


`define RW_DATA_NUM_TX_SCHEDULER      1  // 32 x 16
`define RW_DATA_NUM_TX_MACPROC        2  // 256 x 16     512 x 257
`define RW_DATA_NUM_TX_MACENGINE      (`RW_DATA_NUM_TX_SCHEDULER + `RW_DATA_NUM_TX_MACPROC)

`define RW_DATA_NUM_TX_ROCEPORC       4  // 32 x 16 x 3  512 x 289

`define RW_DATA_NUM_RX_ROCEPORC       2  // 32 x 16      512 x 257
