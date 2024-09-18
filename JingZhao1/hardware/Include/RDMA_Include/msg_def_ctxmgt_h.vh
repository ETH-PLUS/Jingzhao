//+FHDR----------------------------------------------- 
// (C) Copyright Institute of Computing Technology (ICT) 
// All Right Reserved 
//---------------------------------------------------- 
// FILE NAME: msg_def_ctxmgt_h.v 
// AUTHOR: maxiaoxiao 
// CONTACT INFORMATION: maxiaoxiao@ncic.ac.cn 
//----------------------------------------------------
// RELEASE VERSION: V0.0 
// VERSION DESCRIPTION: First Edition  
//----------------------------------------------------
// RELEASE DATE: 2020-07-26 
//---------------------------------------------------- 
// PURPOSE: Define the msg type of CtxMgt module.
//----------------------------------------------------
// PARAMETERS: 
// PARAMETER NAME    RANGE    DESCRIPTION       DEFAULT VALUE  
// 
//-FHDR-----------------------------------------------

`define TD #1
`define CEU_TD #2400

`define 	CXT_MEM_MAX_ADDR_WIDTH					13
`define 	CXT_MEM_MAX_DIN_WIDTH 					128
`define 	CXT_MEM_MAX_DEPTH						8192					

/*****************Add for APB-slave*******************/
//add for apb dug
`ifndef FPGA_VERSION
    `define CTX_DUG
`endif
//add for simulation
`define CTX_SIM 1

// `define CXTMGT_RW_REG_NUM 1
// `define CXTMGT_RO_REG_NUM 14'h600

// `define PAR_RO_REG_NUM 14'h100
`define PAR_DBG_REG_NUM 147
`define PAR_DBG_RW_NUM 6

// `define CTXM_RO_REG_NUM 14'h100
`define CTXM_DBG_REG_NUM 98
`define CTXM_DBG_RW_NUM 4

// `define RDCTX_RO_REG_NUM 14'h100
`define RDCTX_DBG_REG_NUM 49
`define RDCTX_DBG_RW_NUM 1

// `define WRCTX_RO_REG_NUM 14'h100
`define WRCTX_DBG_REG_NUM 38
`define WRCTX_DBG_RW_NUM 0

// `define KEY_RO_REG_NUM 14'h100
//TODO:
`define KEY_DBG_REG_NUM 10
`define KEY_DBG_RW_NUM 29

// `define REQCTL_RO_REG_NUM 14'h100
`define REQCTL_DBG_REG_NUM 1
`define REQCTL_DBG_RW_NUM 0

`define CXTMGT_DBG_REG_NUM  `PAR_DBG_REG_NUM + `CTXM_DBG_REG_NUM + `RDCTX_DBG_REG_NUM +`WRCTX_DBG_REG_NUM +`KEY_DBG_REG_NUM + `REQCTL_DBG_REG_NUM
`define CXTMGT_DBG_RW_NUM  `PAR_DBG_RW_NUM + `CTXM_DBG_RW_NUM + `RDCTX_DBG_RW_NUM +`WRCTX_DBG_RW_NUM +`KEY_DBG_RW_NUM + `REQCTL_DBG_RW_NUM

/*****************Add for APB-slave*******************/

//---------------------------------------------------- 
//AXIS msg header format for CEU and RDMA Engine begin
// wire width 128 bits
// HIGH  type + opcode + reserved + addr + data LOW
//width  4      4           24       32   64 Optional
`define HD_WIDTH          128
`define DT_WIDTH          256
`define AXIS_TYPE_WIDTH     4
`define AXIS_OPCODE_WIDTH   4
`define AXIS_ADDR_WIDTH   32

// Type, Interact with CEU and RDMA Engine
`define RD_QP_CTX     4'b0001
`define WR_QP_CTX     4'b0010
`define WR_CQ_CTX     4'b0011
`define WR_EQ_CTX     4'b0100
`define WR_ICMMAP_CTX 4'b0101
`define MAP_ICM_CTX   4'b0110

`define RD_CQ_CTX     4'b0111
`define RD_EQ_CTX     4'b1000


// Opcode, for RD_QP_CTX
`define RD_QP_ALL     4'b0001 //for ceu read all qpc
`define RD_QP_NPST    4'b0010 //for RTC, read NextPSN & QP state
`define RD_QP_SST     4'b0011 //for Doorbell processing, read PD, Lkey, Pkey, PMTU, Service Type, DestQPN
`define RD_QP_RST     4'b0100 //for Execution Engine, read Pkey、PMTU、PD、Lkey、Expected PSN、RNR Timer、QP State;
`define RD_QP_STATE   4'b0101 //for WQE Parser, read QP state
`define RD_ENCAP      4'b0110 //for FrameEncap, read IP and MAC


// Opcode, for WR_QP_CTX
`define WR_QP_ALL     4'b0001 //for ceu
`define WR_QP_UAPST   4'b0010 //for RRC, write UnAckedPSN、QP State
`define WR_QP_NPST    4'b0011 //for RTC, write NextPSN & QP state
`define WR_QP_EPST    4'b0100 //for Execution Engine, write Expected PSN、QP State;
`define WR_QP_STATE   4'b0101 //Reserved write QP State;

// Opcode, for WR_CQ_CTX
`define WR_CQ_ALL     4'b0001  //for ceu
`define WR_CQ_MODIFY  4'b0010  //for ceu
`define WR_CQ_INVALID 4'b0011  //for ceu

// Opcode, for WR_EQ_CTX
`define WR_EQ_ALL     4'b0001  //for ceu
`define WR_EQ_FUNC    4'b0010  //for ceu
`define WR_EQ_INVALID 4'b0011  //for ceu

// Opcode, for WR_ICMMAP_CTX 
`define WR_ICMMAP_EN  4'b0001 //for ceu
`define WR_ICMMAP_DIS 4'b0010 //for ceu

// Opcode, for MAP_ICM_CTX 
`define MAP_ICM_EN  4'b0001  //for ceu
`define MAP_ICM_DIS 4'b0010  //for ceu

// Opcode, for RD_CQ_CTX
`define RD_CQ_K    4'b0001 //Reserved
`define RD_CQ_CST  4'b0010 //for RRC, read CQ_Lkey、NextPSN、UnAckedPSN、QP State
// Opcode, for RD_EQ_CTX
`define RD_EQ_K     4'b0001  //Reserved
`define RD_EQ_ALL   4'b0010  //Reserved
//AXIS msg header format for CEU and RDMA Engine end
//---------------------------------------------------- 

// source for marking different module which issues request
`define  SOUR_WIDTH  3

`define  CEU     3'b001
`define  DB      3'b010
`define  WP      3'b011
`define  RTC     3'b100
`define  RRC     3'b101
`define  EE      3'b110

/********************Request header*************************
-------------------{CEU Req head} begin----------------------------
    CMD_MAP_ICM req head
        | --------------------64bit----------------------- |
        |      type     |     opcode    |   R  | chunk_num |
        | (MAP_ICM_CTX) | (MAP_ICM_EN)  | void |  (32bit)  |
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

    CMD_UNMAP_ICM req head
        | -------------------64bit----------------------- |
        |      type     |     opcode    |   R  | page_cnt |
        | (MAP_ICM_CTX) | (MAP_ICM_DIS) | void | (32bit)  |
        |-------------------------------------------------|
        |                      virt                       |
        |                    (64bit)                      |
        |-------------------------------------------------|


    CMD_INIT_HCA packet(for context-management)
        | --------------------64bit---------------------- |
        |      type       |      opcode    |     R        |
        | (WR_ICMMAP_CTX) | (WR_ICMMAP_EN) |  (void)      |
        |-------------------------------------------------|
        |                        R                        |
        |                     (void)                      |
        |-------------------------------------------------|
    payload
        |--------| --------------------64bit---------------------- |------|
        |  255:  |                        R                        | 1Ch- |
        |  192   |                     (void)                      | 18h  |
        |--------|-------------------------------------------------|------|
        |  191:  |            qpc_base             |  log_num_qps  | 14h- |
        |  128   |            (63:8)               |    (7:0)      | 10h  |
        |--------|-------------------------------------------------|------|
        |  127:  |            cqc_base             |  log_num_cqs  | 0Ch- |
        |   64   |            (63:8)               |    (7:0)      | 08h  |
        |--------|-------------------------------------------------|------|
        |   63:  |            eqc_base             |  log_num_eqs  | 04h- |
        |    0   |            (63:8)               |    (7:0)      | 00h  |


    CMD_CLOSE_HCA packet
        | --------------------64bit---------------------- |
        |      type      |      opcode     |       R       |
        | (WR_ICMMAP_CTX)| (WR_ICMMAP_DIS) |    (void)    |
        |-------------------------------------------------|
        |                        R                        |
        |                     (void)                      |
        |-------------------------------------------------|


    CMD_QUERY_QP resp head
        |----------------------64bit-----------------------|
        |     type     |   opcode    |   R    |   QP_num   |
        | (RD_QP_CTX)  | (RD_QP_ALL) | void   |  (32bit)   |
        |--------------------------------------------------|
        |                         R                        |
        |                        void                      |
        |--------------------------------------------------|

    CMD_MODIFY_QP req head
        |----------------------64bit-----------------------|
        |     type     |    opcode   |   R    |   QP_num   |
        | (WR_QP_CTX)  | (WR_QP_ALL) | void   |  (32bit)   |
        |--------------------------------------------------|
        |                         R                        |
        |                        void                      |
        |--------------------------------------------------|

    CMD_SW2HW_CQ req head
        |----------------------64bit-----------------------|
        |     type     |    opcode    |   R   |   CQ_num   |
        | (WR_CQ_CTX)  | (WR_CQ_ALL)  | void  |  (32bit)   |
        |--------------------------------------------------|
        |                         R                        |
        |                        void                      |
        |--------------------------------------------------|

    CMD_HW2SW_CQ req head
        |----------------------64bit-----------------------|
        |     type     |     opcode    |   R   |  CQ_num   |
        | (WR_CQ_CTX)  |(WR_CQ_INVALID)| void  | (32bit)   |
        |--------------------------------------------------|
        |                         R                        |
        |                        void                      |
        |--------------------------------------------------|

    CMD_RESIZE_CQ req head
        | --------------------64bit---------------------- |
        |      type     |     opcode     |   R  |  CQ_num |
        |  (WR_CQ_CTX)  | (WR_CQ_MODIFY) | void | (32bit) |
        |-------------------------------------------------|
        |                        R                        |
        |                       void                      |
        |-------------------------------------------------|

    CMD_SW2HW_EQ req head
        |----------------------64bit-----------------------|
        |     type     |    opcode    |   R   |   EQ_num   |
        | (WR_EQ_CTX)  | (WR_EQ_ALL)  | void  |  (32bit)   |
        |--------------------------------------------------|
        |                         R                        |
        |                        void                      |
        |--------------------------------------------------|

    CMD_HW2SW_EQ req head
        |----------------------64bit-----------------------|
        |     type     |     opcode     |   R  |   EQ_num  |
        | (WR_EQ_CTX)  |(WR_EQ_INVALID) | void |  (32bit)  |
        |--------------------------------------------------|
        |                         R                        |
        |                        void                      |
        |--------------------------------------------------|

    CMD_MAP_EQ req head
        | --------------------64bit---------------------- |
        |      type     |     opcode     |   R  |  EQ_num |
        |  (WR_EQ_CTX)  |  (WR_EQ_FUNC)  | void | (32bit) |
        |-------------------------------------------------|
        |                    event_mask(flags seg)        |
        |                     (64bit)                     |
        |-------------------------------------------------|
-------------------{CEU Req head} end----------------------------

-------------------{RDMA Engine Req head} begin--------------------------

    | --------------------64bit---------------------- |
    |      type 4   |   opcode 4     |  QP_num |R 32b |
    |  (RD_QP_CTX)  |  (RD_QP_NPST)  | (24bit) | void |
    |-------------------------------------------------|
    |                       R                         |
    |                     void                        |
    |-------------------------------------------------|
    other  opcodes   of RD_QP_CTX type have the same format
    RD_QP_NPST 
    RD_QP_SST  
    RD_QP_RST  
    RD_QP_STATE

    | --------------------64bit---------------------- |
    |      type     |     opcode     |  QP_num |R 32b |
    |  (RD_CQ_CTX)  |  ( RD_CQ_CST)  | (24bit) | void |
    |-------------------------------------------------|
    |                       R                         |
    |                     void                        |
    |-------------------------------------------------|
    RD_CQ_ALL opcode of RD_CQ_CTX type has the same format

    | --------------------64bit---------------------- |
    |      type     |     opcode     |  QP_num |R 32b |
    |  (RD_EQ_CTX)  |  ( RD_EQ_K)    | (24bit) | void |
    |-------------------------------------------------|
    |                       R                         |
    |                     void                        |
    |-------------------------------------------------|
    RD_EQ_ALL opcode of RD_EQ_CTX type has the same format

    | --------------------64bit----------------------- |
    |      type     |     opcode      |  QP_num |R 32b |
    |  (WR_QP_CTX)  |  (WR_QP_STATE)  | (24bit) | void |
    |--------------------------------------------------|
    |                             R                    |
    |                            void                  |
    |--------------------------------------------------|
    WR_QP_UAPST/ WR_QP_NPST /WR_QP_EPST has the same format of WR_QP_CTX type

    --------RDMA Engine req ctx fifo foramt------------------------

-------------------{RDMA Engine Req head} end--------------------------
 ****************************************************/

 /********************Response header*************************
    -------------------CEU response header----------------------
        CMD_QUERY_QP response head
            |----------------------64bit-----------------------|
            |     type     |   opcode    |   R    |   QP_num   |
            | (RD_QP_CTX)  | (RD_QP_ALL) | void   |  (32bit)   |
            |--------------------------------------------------|
            |                         R                        |
            |                        void                      |
            |--------------------------------------------------|


    ----------RDMA Engine response header----------------------

        ------------------RDMA Engine resp cmd fifo foramt------------

        -------------------RDMA Engine resp ctx fifo foramt-----------

 ****************************************************/

/*********************DMA req header*******************************
   dma_*_head(interact with DMA modules), valid only in first beat of a packet
       | Reserved | address | Reserved | Byte length |
       |  127:96  |  95:32  |  31:12   |    11:0     |
    
*********************DMA req header*******************************/

/***********************internel msg format************************/
//-------------{ceu_parser out format} begin--------------------------------------- 
    //internel req header fifo format for ceu_parser 2 request controller :write context req empty signal
    //                                                2 key_qpc_data: write context req
    //                                                2 ctxmdata: rd/wr metata req & rd/wr context req
    //                                                2 writectx: rd/wr metata req & rd/wr context req
    `define  CEUP_REQ_MDT 128 // the same as external CEU request header
    `define  CEUP_REQ_KEY 35  
    // HIGH  type + opcode + source + addr
    //width   4       4        3       24  

    //msg opcode + data width(bit)
    //key_qpc_data & request controller: type(WR_QP_CTX) + opcode:
    //    WR_QP_ALL  
    //    WR_QP_UAPST
    //    WR_QP_NPST 
    //    WR_QP_EPST 
    //ctxmdata
    //    type        +       opcode
    //    RD_QP_CTX         RD_QP_ALL
    //    WR_QP_CTX         WR_QP_ALL
    //    WR_CQ_CTX         WR_CQ_ALL(+64Byte) WR_CQ_MODIFY(+64Byte)  WR_CQ_INVALID 
    //    WR_EQ_CTX         WR_EQ_ALL(+48Byte) WR_EQ_FUNC(+64bit in header)  WR_EQ_INVALID 
    //    WR_ICMMAP_CTX     WR_ICMMAP_EN       WR_ICMMAP_DIS 
    //    MAP_ICM_CTX       MAP_ICM_EN         MAP_ICM_DIS

    `define  INTER_DT 256
    //internal payload data inclueding:
    //    ceu_parser    2    ctxmdata 
    //    ceu_parser    2    writectx 

    `define  KEY_QPC_DT 384
    //internal key qpc info data entry payload data:
    /*-----------------------------------------------------------------------------------
    //offset |        +0         |      +1         |         +2	     |        +3       |
    //       | 7 6 5 4 | 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 |
    -------------------------------Old version info ------payload 1--------------------
    //  00h  |  state  |	0    |    servtype     |   mtu_msgmax    |    rnr_retry    |
    //  04h  |                    local_qpn                                            |
    //  08h  |                    remote_qpn                                           |
    //  0Ch  |                    port_pkey                                            |
    //  10h  |                    pd                                                   |
    //  14h  |                    wqe_lkey -- sl_tclass_flowlabel                      |
    //  18h  |                    next_send_psn(Next PSN)                              |
    //  1Ch  |                    cqn -- cqn_send                                      |
    //  20h  |                    snd_wqe_base_lky                                     |
    //  24h  |                    last_acked_psn(UnAckedPSN)                           |
    //  28h  |                    rnr_next_recv_psn(Expected PSN)                        |
    //  2Ch  |                    rcv_wqe_base_lkey                                    |
    -------------------------------Old version info ------------------------------------
    -------------------------------New version added info----payload 2 -----------------
    //  00h  |      	0        |     	0          | rq_entry_sz_log | sq_entry_sz_log |
    //  04h  |        dlid(dmac[15:0])   	       |        	slid(smac[15:0])       |
    //  08h  |                    smac[47:16]                                          |
    //  0Ch  |                    dmac[47:16]                                          |
    //  10h  |                    sip                                                  |
    //  14h  |                    dip                                                  |
    //  18h  |                    snd_wqe_length(SQ Length)                            |
    //  1Ch  |                    cqn_recv                                              |
    //  20h  |                    rcv_wqe_length(RQ Length)                            |
    //  24h  |                    reserved                                             |
    //  28h  |                    reserved                                             |
    //  2Ch  |                    reserved                                             |
    -------------------------------New version added info-------------------------------*/

    //write cqc extract key info 
    //offset |        +0         |      +1         |         +2	     |        +3       |
    //       | 7 6 5 4 | 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 |
    //------------------------------- version info ------payload 1--------------------
    //  00h  |                    reserved                                             |
    //  04h  |                    reserved                                             |
    //  08h  |                    reserved                                             |
    //  0Ch  |                    reserved                                             |
    //  10h  |                    reserved                                             |
    //  14h  |                    reserved                                             |
    //  18h  |                    reserved                                             |
    //  1Ch  |                    reserved                                             |
    //  20h  |                    reserved                                             |
    //  24h  |     CQ logsize    |                       reserved                      |
    //  28h  |                    CQ pd                                                |
    //  2Ch  |                    CQ_lkey                                              |
    //---------------------------------------------------- 
//-------------{ceu_parser out format} end--------------------------------------- 

//--------------{request_controller In/Out format} begin-------------------------------------- 
    //----------Out selected_channel to key_qpc_data module----------------
        //| bit |        Description           |
        //|-----|------------------------------|
        //|  0  |   CEU                        |
        //|  1  |   Doorbell Processing(DBP)   |
        //|  2  |   WQE Parser(WP）            |
        //|  3  |   RequesterTransControl(RTC) |
        //|  4  |   RequesterRecvControl(RRC)  |
        //|  5  |   Execution Engine(EE)       |
        //|  6  |    valid                     |
    //-----------In receive_req(1 bit) signal from key_qpc_data module
//--------------{request_controller In/Out format} begin--------------------------------------

//--------------{ctxmdata In/Out format} begin-------------------------------------- 
    //-------------In req from ceu_parser format is the same as CEU external header---
    //-------------In paylaod data  from ceu_parser is the same as external payload---
    //-------------In req from key_qpc_data--------------------
        //| ---------------128bit---------------------------------------------------------|
        //|   type   |  opcode |   R      |   QPN   |    R   |  PSN   |  R     |   State  | 
        //|    4 bit |  4 bit  |  24 bit  |  32 bit | 32 bit | 24 bit |  5 bit |   3 bit  |   
    `define MDT_REQ_RD_CTX   108 
    //----------------Out dma read req to dma_read_ctx module
        //|---------108bit---------------|
        //|  addr     | len      | QPN   | 
        //|  64 bit   | 12 bit   | 32 bit|
    //----------------Out dma read req to dma_write_ctx module
        //| ------------------128bit------------------------------------|
        //|   type   |  opcode |   Src   | R      | valid  |   data   |   addr   | 
        //|    4 bit |  4 bit  |  3 bit  |20 bit  |  1 bit |  32 bit  |  64 bit  |   
//--------------{ctxmdata In/Out format} begin--------------------------------------

/***********************internel msg format************************/
