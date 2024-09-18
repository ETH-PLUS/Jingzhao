//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: msg_def_v2p_h.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V2.0 
// VERSION DESCRIPTION: First Edition  
//----------------------------------------------------
// RELEASE DATE: 2022-08-31 
//---------------------------------------------------- 
// PURPOSE: Define the msg type of VirtToPhys module.
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION    DEFAULT VALUE  
// 
//-FHDR-----------------------------------------------

`define TD #1
/*****************Add for APB-slave*******************/
//add for apb dug
`ifndef FPGA_VERSION
  `define V2P_DUG
`endif
//add for simulation
`define V2P_SIM 1

`define V2P_MEM_MAX_ADDR_WIDTH			13			//maximum depth = 8192
`define V2P_MEM_MAX_DIN_WIDTH			1024		//maximum width = 1024
`define V2P_MEM_MAX_DEPTH				8192		//maximum depth = 8192

`define CEUPAR_DBG_REG_NUM 98
`define CEUTPTM_DBG_REG_NUM 77
`define V2P_RDCTX_DBG_REG_NUM 47
`define RDDT_DBG_REG_NUM 78
`define RDWQE_DBG_REG_NUM 86
`define V2P_WRCTX_DBG_REG_NUM 97
`define WRDT_DBG_REG_NUM 68
`define MPTCTL_DBG_REG_NUM 275
`define MPT_DBG_REG_NUM 190
`define MPTRD_DT_PAR_DBG_REG_NUM 42
`define MPTRD_WQE_PAR_DBG_REG_NUM 42
`define MPTWR_PAR_DBG_REG_NUM 36
`define MPTM_DBG_REG_NUM 67
`define MTTCTL_DBG_REG_NUM 185
`define MTT_DBG_REG_NUM 178
`define MTTREQ_CTL_DBG_REG_NUM 38
`define MTTM_DBG_REG_NUM 77
`define REQSCH_DBG_REG_NUM 3
`define CHCTL_DBG_REG_NUM 1
`define TPTM_DBG_REG_NUM  222

`define VTP_DBG_REG_NUM (`CEUPAR_DBG_REG_NUM + `V2P_RDCTX_DBG_REG_NUM + `RDDT_DBG_REG_NUM + `RDWQE_DBG_REG_NUM + `V2P_WRCTX_DBG_REG_NUM + `WRDT_DBG_REG_NUM + `MPTCTL_DBG_REG_NUM + `MPT_DBG_REG_NUM + `MPTRD_DT_PAR_DBG_REG_NUM + `MPTRD_WQE_PAR_DBG_REG_NUM + `MPTWR_PAR_DBG_REG_NUM + `MTTCTL_DBG_REG_NUM + `MTT_DBG_REG_NUM + `MTTREQ_CTL_DBG_REG_NUM + `REQSCH_DBG_REG_NUM + `CHCTL_DBG_REG_NUM + `TPTM_DBG_REG_NUM)

`define CEUPAR_DBG_RW_NUM 6
`define V2P_RDCTX_DBG_RW_NUM 1
`define RDDT_DBG_RW_NUM 1
`define RDWQE_DBG_RW_NUM 1
`define V2P_WRCTX_DBG_RW_NUM 0
`define WRDT_DBG_RW_NUM 0
`define MPTCTL_DBG_RW_NUM 5
`define MPT_DBG_RW_NUM 12
`define MPTRD_DT_PAR_DBG_RW_NUM 1
`define MPTRD_WQE_PAR_DBG_RW_NUM 1
`define MPTWR_PAR_DBG_RW_NUM 1
`define MTTCTL_DBG_RW_NUM 3
`define MTT_DBG_RW_NUM 15
`define MTTREQ_CTL_DBG_RW_NUM 0
`define REQSCH_DBG_RW_NUM 0
`define CHCTL_DBG_RW_NUM 0

`define CEUTPTM_DBG_RW_NUM 4
`define MPTM_DBG_RW_NUM 3
`define MTTM_DBG_RW_NUM 3

`define TPTM_DBG_RW_NUM  `CEUTPTM_DBG_RW_NUM + `MPTM_DBG_RW_NUM + `MTTM_DBG_RW_NUM

`define VTP_DBG_RW_NUM `CEUPAR_DBG_RW_NUM + `V2P_RDCTX_DBG_RW_NUM + `RDDT_DBG_RW_NUM + `RDWQE_DBG_RW_NUM + `V2P_WRCTX_DBG_RW_NUM + `WRDT_DBG_RW_NUM + `MPTCTL_DBG_RW_NUM + `MPT_DBG_RW_NUM + `MPTRD_DT_PAR_DBG_RW_NUM + `MPTRD_WQE_PAR_DBG_RW_NUM + `MPTWR_PAR_DBG_RW_NUM + `MTTCTL_DBG_RW_NUM + `MTT_DBG_RW_NUM + `MTTREQ_CTL_DBG_RW_NUM + `REQSCH_DBG_RW_NUM + `CHCTL_DBG_RW_NUM + `TPTM_DBG_RW_NUM
/*****************Add for APB-slave*******************/
//---------------------------------------------------- 
//AXIS Slave1 msg format for CEU begin
//       type + opcode + Reservr + addr + data
//width  4      4        24     32 Option 64 Option
`define CEU_CM_HEAD_WIDTH   128     // CEU <-> CM  Interface head width
`define CEU_V2P_HEAD_WIDTH  128     // CEU <-> V2P Interface head width
`define HD_WIDTH      128
`define DT_WIDTH      256
`define TYPE_WIDTH     4
`define OPCODE_WIDTH   4
`define ADDR_WIDTH    32

// Type, Interact with CEU
`define WR_MPT_TPT    4'b0001
`define WR_MTT_TPT    4'b0010
`define WR_ICMMAP_TPT 4'b0011
`define MAP_ICM_TPT   4'b0100

// Opcode, for WR_ICMMAP_CXT && WR_ICMMAP_TPT
`define WR_ICMMAP_EN_V2P  4'b0001
`define WR_ICMMAP_DIS_V2P 4'b0010

// Opcode, for MAP_ICM_CXT && MAP_ICM_TPT
`define MAP_ICM_EN_V2P  4'b0001
`define MAP_ICM_DIS_V2P 4'b0010

// Opcode, for WR_MPT_TPT
`define WR_MPT_WRITE   4'b0001
`define WR_MPT_INVALID 4'b0010

// Opcode, for WR_MTT_TPT
`define WR_MTT_WRITE   4'b0001
`define WR_MTT_INVALID 4'b0010
//AXIS Slave1 msg format for CEU end
//----------------------------------------------------


//---------------------------------------------------- 
//AXIS Slave2 and Master2 msg format for RDMA Engine begin
//       type + opcode + match-info
//width  4      4         32*6    
// request format info 
//| 255:224 | 223:192 | 191:160 | 159:128 | 127:96  |  95:64  |  63:32  |  31:8 | 7:4 | 3:0 |
//| Reserve | length  | VA-high | VA-low  |   Key   |   PD    |  Flags  |  Resv |  Op | Tpye|
//MPT flags
    //MPT attribute flags
    //MTHCA_MPT_FLAG_SW_OWNS     [31:28]
    //ABSOLUTE_ADDR              [27]
    //RELATIVE_ADDR              [26]
    //MTHCA_MPT_FLAG_MIO         [17]
    //MTHCA_MPT_FLAG_BIND_ENABLE [15]
    //MTHCA_MPT_FLAG_PHYSICAL    [9]
    //MTHCA_MPT_FLAG_REGION      [8]
    //MPT Access flags
    //IBV_ACCESS_ON_DEMAND       [6]
    //IBV_ACCESS_ZERO_BASED      [5]
    //IBV_ACCESS_MW_BIND         [4]
    //IBV_ACCESS_REMOTE_ATOMIC   [3]
    //IBV_ACCESS_REMOTE_READ	 [2]
    //IBV_ACCESS_REMOTE_WRITE    [1]
    //IBV_ACCESS_LOCAL_WRITE     [0]


`define MATCHINFO_WIDTH   192

// Type, Interact with RDMA Engine
`define RD_REQ_WQE    4'b0001
`define RD_REQ_DATA   4'b0010
`define WR_REQ_DATA   4'b0011


// Opcode, for RD_REQ_WQE
`define RD_SQ_FWQE    4'b0001
`define RD_SQ_TWQE    4'b0010
`define RD_RQ_WQE     4'b0011

// Opcode, for RD_REQ_DATA; L-Local; R-Remote.
`define RD_L_NET_DATA  4'b0001
`define RD_R_NET_DATA  4'b0010

// Opcode, for WR_REQ_DATA; L-Local; R-Remote.
`define WR_L_NET_DATA   4'b0001
`define WR_R_NET_DATA   4'b0010
`define WR_CQE_DATA     4'b0011 
`define WR_EQE_DATA     4'b0100     

// pendingfifo--------------store the read miss request info 
    //| 207:200 | 199:168 | 167:136 | 135:104 | 103:72  |  71:40  |  39:8  | 7:4 | 3:0  |
    //| channel | length  | VA-high | VA-low  |   Key   |   PD    |  Flags |  Op | Tpye |

//AXIS Slave2 and Master2 msg format for RDMA Engine end
//----------------------------------------------------


//---------------------------------------------------- 
//AXIS Master msg format for RDMA Engine begin
//        State 
//width     4         

`define STATE_WIDTH   8

// STATE_INFO {  PD_ERR    
//             | FLAGS_ERR 
//             | KEY_ERR   
//             | LENGTH_ERR
//             | SUCCESS   }
`define PD_ERR       8'b00000001
`define FLAGS_ERR    8'b00000010
`define KEY_ERR      8'b00000100
`define LENGTH_ERR   8'b00001000
`define SUCCESS      8'b00010000
//AXIS Master msg format for RDMA Engine end
//----------------------------------------------------


/*************************************************************
/----------------------CEU TPT Metadata request----------------

CMD_INIT_HCA packet header(for Virtual-to-physical)
| --------------------64bit---------------------- |
|      type       |      opcode    |     R        |
| (WR_ICMMAP_TPT) | (WR_ICMMAP_EN_V2P) |  (void)      |
|-------------------------------------------------|
|                        R                        |
|                     (void)                      |
|-------------------------------------------------|
CMD_INIT_HCA packet payload 127:0
|            mpt_base             |  log_mpt_sz   |
|            (63:8)               |    (7:0)      |
|-------------------------------------------------|
|                    mtt_base                     |
|                    (63:0)                       |
|-------------------------------------------------|


CMD_CLOSE_HCA packet
| --------------------64bit---------------------- |
|      type     |      opcode     |       R       |
|(WR_ICMMAP_TPT)| (WR_ICMMAP_DIS_V2P) |    (void)     |
|-------------------------------------------------|
|                        R                        |
|                     (void)                      |
|-------------------------------------------------|


CMD_MAP_ICM head
| --------------------64bit----------------------- |
|      type     |     opcode    |   R  | chunk_num |
| (MAP_ICM_TPT) | (MAP_ICM_EN_V2P)  | void |  (32bit)  |
|--------------------------------------------------|
|                        R                         |
|                      void                        |
|--------------------------------------------------|
    payload
        |--------| --------------------64bit---------------------- |------|
        |  255:  |                    virtual addr                 | 1Ch- |
        |  192   |                    (chunk 1 info)               | 18h  |
        |--------|-------------------------------------------------|------|
        |  191:  |            page addr            |   page_num    | 14h- |
        |  128   |            (63:8)               |    (11:0)     | 10h  |
        |--------|-------------------------------------------------|------|
        |  127:  |                    virtual addr                 | 0Ch- |
        |   64   |                    (chunk 0 info)               | 08h  |
        |--------|-------------------------------------------------|------|
        |   63:  |            page addr            |   page_num    | 04h- |
        |    0   |            (63:8)               |    (11:0)     | 00h  |

        payload num = (chunk_num/2)+(chunk_num%2)

CMD_MAP_ICM payload 127:0 chunk0;255-128 chunk1·· 

CMD_UNMAP_ICM head
| -------------------64bit----------------------- |
|      type     |     opcode    |   R  | page_cnt |
| (MAP_ICM_TPT) | (MAP_ICM_DIS_V2P) | void | (32bit)  |
|-------------------------------------------------|
|                      virt                       |
|                    (64bit)                      |
|-------------------------------------------------|
 *****************************************************************/


/*************************************************************
/----------------------CEU TPT Table request----------------
CMD_SW2HW_MPT head
|----------------------64bit-----------------------|
|     type     |     opcode     |   R  | mpt_index |
| (WR_MPT_TPT) | (WR_MPT_WRITE) | void |  (32bit)  |
|--------------------------------------------------|
|                         R                        |
|                        void                      |
|--------------------------------------------------|

CMD_HW2SW_MPT head
|----------------------64bit-------------------------|
|     type     |       opcode     |   R  | mpt_index |
| (WR_MPT_TPT) | (WR_MPT_INVALID) | void |  (32bit)  |
|----------------------------------------------------|
|                         R                          |
|                        void                        |
|----------------------------------------------------|

CMD_WRITE_MTT head
| --------------------64bit---------------------- |
|      type     |     opcode     |   R  | mtt_num |
| (WR_MTT_TPT)  | (WR_MTT_WRITE) | void | (32bit) |
|-------------------------------------------------|
|                 mtt_start_index                 |
|                     (64bit)                     |
|-------------------------------------------------|
 *****************************************************************/


/***************tptmdata internal  data format ***************/
//-----------ceu_tptm_proc--mptm/mttm req header format---------
//high------------------------low
//| ---------104 bit------------|
//|  type | opcode | num | addr |
//|    4  |   4    | 32  |  64  |
//|-----------------------------|

//-----------ceu_tptm_proc--mptm/mttm payload format---------
//high------------------------low
//| ---------256 bit------------|
//|``````| virt addr | phy addr |
//|``````|    64     |    64    |
//|-----------------------------|

//-----------MPT/MTT-mptm/mttm req header format---------
//high------------------------low
//| ---------99 bit-----|
//| opcode | num | addr |
//|    3   | 32  |  64  |
//|-----------------------------|
`define MPT_RD   3'b001 //read
`define MPT_WR   3'b010 //write 
`define MPT_IN   3'b011 //invalid
`define MTT_RD   3'b101 //read
`define MTT_WR   3'b110 //write 
`define MTT_IN   3'b111 //invalid
`define LAST     3'b100 //mptm/mttm-dma_read/write_ctx indicate that this is the last dma req derived from 1 mtt/mpt req
//-----------mptm/mttm--dma_write_ctx req header format---------
//high------------------------low
//| ---------99 bit-----|
//| opcode | len | phy addr |
//|    3   | 32  |     64   |
//|-----------------------------|
//-----------mptm/mttm--dma_reade_ctx req header format---------
//high------------------------low
//| ---------163 bit-----|
//| index | opcode | len |phy addr |
//|   64  |    3   | 32  |     64  |
//|-----------------------------|
//opcode format as before
/**********************************************************
//**************************mtt_req_scheduler--mtt_ram_ctl interface***************/
    //mtt_ram_ctl block signal for 3 req fifo processing block 
    //| bit 2 read WQE | bit 1 write data | bit 0 read data |

    //mtt_ram_ctl unblock signal for reading 3 blocked req  
    //| bit 2 read WQE | bit 1 write data | bit 0 read data |

    //------------------new_selected_channel-------------------
    //| bit |        Description    |
    //|-----|-----------------------|
    //|  3  |         valid         |
    //|  2  | mpt_rd_wqe_req_mtt_cl |
    //|  1  |   mpt_wr_req_mtt_cl   |
    //|  0  |   mpt_rd_req_mtt_cl   |

    //block_req_reg
    //|--------------198 bit------------------------- |
    //|    Src  |  total length |    Op  | mtt_index | address | tmp length |
    //| 197:195 |    194:163    |162:160 |  159:96   |  95:32  |   31:0     |

//**************************mtt_ram_ctl--dma_read_wqe/dma_read_data/dma_write_data interface***************/
//-----------mtt_ram_ctl--dma_read_data req header format---------
//high-------------------------low
//|-------------------134 bit--------------------|
//| total len |opcode | dest/src |tmp len | addr |
//| 32        |   3   |     3    | 32     |  64  |
//|----------------------------------------------|
//----------mtt_ram_ctl--dma_write_ctx req header format---------
//high--------------------------low
//|-------------------134 bit--------------------|
//| total len |opcode | dest/src |tmp len | addr |
//| 32        |   3   |     3    | 32     |  64  |
//|----------------------------------------------|
//dest 
`define  DEST_CEU        3'b000
`define  DEST_DBP        3'b001
`define  DEST_WPWQE      3'b010
`define  DEST_WPDT       3'b011
`define  DEST_RTC        3'b100
`define  DEST_RRC        3'b101
`define  DEST_EEWQE      3'b110  //rwm
`define  DEST_EEDT       3'b111  //ee
//source
`define  SRC_CEU        3'b000
`define  SRC_DBP        3'b001
`define  SRC_WPWQE      3'b010
`define  SRC_WPDT       3'b011
`define  SRC_RTC        3'b100
`define  SRC_RRC        3'b101
`define  SRC_EEWQE      3'b110  //rwm
`define  SRC_EEDT       3'b111  //ee
//opcode
`define DATA_RD         3'b001
`define DATA_WR         3'b010
`define DATA_RD_FIRST   3'b101//mtt-dma_read/write_data indicate that this is the first dma req derived from 1 mpt req
`define DATA_WR_FIRST   3'b110//mtt-dma_read/write_data indicate that this is the first dma req derived from 1 mpt req
`define DATA_WR_PHY     3'b111//mtt-dma_write_data indicate that this is the physical addr req
///**********************************************************/



/***************DMA engine request header data format ***************/
// dma_*_head(interact with DMA modules), valid only in first beat of a packet
//| Reserved | address | Reserved | Byte length |
//|  127:96  |  95:32  |  31:26   |    25:0     |
///**********************************************************/

/***************mpt_ram_ctl to mpt_rd/wr_req_parser request header data format ***************/
//|--------------163 bit------------------------- |
//|    Src  | mtt_index | address |Byte length |
//| 162:160 |  159:96   |  95:32  |   31:0     |

// mpt_rd/wr_req_parser to mtt_ram_ctl look up request at cacheline level for dma read data requests
//|--------------198 bit------------------------- |
//|    Src  |  total length |    Op  | mtt_index | address | tmp length |
//| 197:195 |    194:163    |162:160 |  159:96   |  95:32  |   31:0     |

//note:all the v_addr transfer to mtt modele is a relative addr, if it's the absolute addr, sub the start addr
//Src define                           abbre    up/down
//|  0  |   CEU                       | CEU    | U/D |
//|  1  |   Doorbell Processing(WQE)  | DB     |  D  |
//|  2  |   WQE Parser(SQ WQE)        | WP_WQE |  D  |
//|  3  |   WQE Parser(DATA)          | WP_ND  |  D  |
//|  4  |   RequesterTransControl(CQ) | RTC    |  U  |
//|  5  |   RequesterRecvControl(DATA)| RRC    |  U  |
//|  6  |   Execution Engine(RQ WQE)  | RWM    |  D  | 
//|  7  |   Execution Engine(DATA)    | EE     | U/D | 
//Op  define
`define  UP          2'b10 //upload data to host(DMA write)
`define  DOWN        2'b01 //download data from host(DMA read)
///**********************************************************/

/***************MPT pending fifo data format ***************/
    // pendingfifo--------------store the read miss request info 
        //| 207:200 | 199:168 | 167:136 | 135:104 | 103:72  |  71:40  |  39:8  | 7:4 | 3:0  |
        //| channel | length  | VA-high | VA-low  |   Key   |   PD    |  Flags |  Op | Tpye |
//**********************************************************/

/***************mpt_ram read req fifo data format ***************/
    // rd_mpt_req_fifo--------------store the read request info 
        //| 207:200 | 199:168 | 167:136 | 135:104 | 103:72  |  71:40  |  39:8  | 7:4 | 3:0  |
        //| channel | length  | VA-high | VA-low  |   Key   |   PD    |  Flags |  Op | Tpye |
//**********************************************************/

/***************MPT-req_scheduler pend_channel_cnt data format ***************/
//|  seg 0 |  CEU                        |   pend_channel_cnt[1*4-1:0*4] 
//|  seg 1 |  Doorbell Processing(WQE)   |   pend_channel_cnt[2*4-1:1*4] 
//|  seg 2 |  WQE Parser(WQE）           |   pend_channel_cnt[3*4-1:2*4] 
//|  seg 3 |  WQE Parser(DATA)           |   pend_channel_cnt[4*4-1:3*4] 
//|  seg 4 |  RequesterTransControl(CQ)  |   pend_channel_cnt[5*4-1:4*4] 
//|  seg 5 |  RequesterRecvControl(DATA) |   pend_channel_cnt[6*4-1:5*4] 
//|  seg 6 |  Execution Engine(RQ WQE)   |   pend_channel_cnt[7*4-1:6*4] 
//|  seg 7 |  Execution Engine(DATA)     |   pend_channel_cnt[8*4-1:7*4] 
//**********************************************************/

//***********************mpt data whole format*************************/
    //32*1 -1: 32*0 |   Flags                        |
    //32*2 -1: 32*1 |   page_size                    |
    //32*3 -1: 32*2 |   Key                          |
    //32*4 -1: 32*3 |   PD                           |
    //32*5 -1: 32*4 |   start-high                   |
    //32*6 -1: 32*5 |   start-low                    |
    //32*7 -1: 32*6 |   length-high                  |
    //32*8 -1: 32*7 |   length-low                   |
    //32*9 -1: 32*8 |   lkey             (Reserved)  |
    //32*10-1: 32*9 |   window_cnt       (Reserved)  |
    //32*11-1: 32*10|   window_cnt_limit (Reserved)  |
    //32*12-1: 32*11|   mtt_seg_high                 |
    //32*13-1: 32*12|   mtt_seg_low                  |
    //32*14-1: 32*13|   mtt_size         (Reserved)  |
//***********************mpt data tranfer format*************************/
    //32*8 -1: 32*7 |   Flags                        |
    //32*7 -1: 32*6 |   page_size                    |
    //32*6 -1: 32*5 |   Key                          |
    //32*5 -1: 32*4 |   PD                           | clk 1
    //32*4 -1: 32*3 |   start-high                   |
    //32*3 -1: 32*2 |   start-low                    |
    //32*2 -1: 32*1 |   length-high                  |
    //32*1 -1: 32*0 |   length-low                   |

    //32*8 -1: 32*7 |   lkey             (Reserved)  |
    //32*7 -1: 32*6 |   window_cnt       (Reserved)  |
    //32*6 -1: 32*5 |   window_cnt_limit (Reserved)  |
    //32*5 -1: 32*4 |   mtt_seg_high                 | clk 2
    //32*4 -1: 32*3 |   mtt_seg_low                  |
    //32*3 -1: 32*2 |   mtt_size         (Reserved)  |
    //32*2 -1: 32*0 |   0                (Reserved)  |
//***********************mpt data format*************************/

/**********************MPT Flags****************************/
// MPT表项属性标志位
// MTHCA_MPT_FLAG_SW_OWNS 【31:28】
// ABSOLUTE_ADDR【27】
// RELATIVE_ADDR【26】
// MTHCA_MPT_FLAG_MIO 【17】
// MTHCA_MPT_FLAG_BIND_ENABLE【15】
// MTHCA_MPT_FLAG_PHYSICAL【9】
// MTHCA_MPT_FLAG_REGION【8】
// MPT表项访问权限标志位
// IBV_ACCESS_LOCAL_WRITE【0】
// IBV_ACCESS_REMOTE_WRITE【1】
// IBV_ACCESS_REMOTE_READ	【2】
// IBV_ACCESS_REMOTE_ATOMIC【3】
// IBV_ACCESS_MW_BIND【4】
// IBV_ACCESS_ZERO_BASED【5】
// IBV_ACCESS_ON_DEMAND【6】
/*****************************************************/

