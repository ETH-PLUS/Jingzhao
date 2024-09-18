/*
 *======================= START OF LICENSE NOTICE =======================
 *  Copyright (C) 2021 Kang Ning, NCIC, ICT, CAS.
 *  All Rights Reserved.
 *
 *  NO WARRANTY. THE PRODUCT IS PROVIDED BY DEVELOPER "AS IS" AND ANY
 *  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 *  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 *  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL DEVELOPER BE LIABLE FOR
 *  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 *  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 *  GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
 *  IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 *  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THE PRODUCT, EVEN
 *  IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *======================== END OF LICENSE NOTICE ========================
 *  Primary Author: Kang Ning
 *  <kangning18z@ict.ac.cn>
 */

/**
 * @file
 * Han Gu RNIC register defination declaration.
 */


#ifndef __HANGU_RNIC_DEFS_HH__
#define __HANGU_RNIC_DEFS_HH__
#include<memory>
#include "base/bitfield.hh"
#include "dev/net/etherpkt.hh"
#include "debug/HanGu.hh"
#include "sim/eventq.hh"
#include "dev/rdma/kfd_ioctl.h"

#ifdef COLOR

#define HANGU_PRINT(name, x, ...) do {                                      \
            DPRINTF(name, "[\033[1;33m" #name "\033[0m] " x, ##__VA_ARGS__);\
        } while (0)

#else

#define HANGU_PRINT(name, x, ...) do {                     \
            DPRINTF(name, "[" #name "] " x, ##__VA_ARGS__);\
        } while (0)
#endif

#define QPN_NUM   (512 * 3)

#define MAX_PREFETCH_NUM 8
#define MAX_COMMIT_SZ 4096
#define MAX_MSG_RATE 60
#define MAX_BW 100
#define WQE_BUFFER_CAPACITY 120
// #define WQE_PREFETCH_THRESHOLD 100
#define LAT_QP 1
#define BW_QP 2
#define RATE_QP 3
#define UC_QP 4
#define UD_QP 5
// UC and UD QP above is only used in QoS!

// QoS related parameters
#define LEAST_QPN_QUE_CAP 64
#define DESC_REQ_LIMIT 5
#define DATA_REQ_LIMIT 6
// #define RGU_SAU_LIM 1
#define BIGN 20480
#define WINDOW_CAP 20
// #define MAX_SUBWQE_SIZE 1024

#define PAGE_SIZE_LOG 12
#define PAGE_SIZE (1 << PAGE_SIZE_LOG)

namespace HanGuRnicDef {

struct QpcResc;
struct CqcResc;


struct Hcr {
    uint32_t inParam_l;
    uint32_t inParam_h;
    uint32_t inMod;
    uint32_t outParam_l;
    uint32_t outParam_h;
    uint32_t goOpcode;
};
// Command Opcode for CEU command
const uint8_t INIT_ICM  = 0x01;
const uint8_t WRITE_ICM = 0x02;
const uint8_t WRITE_MPT = 0x03;
const uint8_t WRITE_MTT = 0x04;
const uint8_t WRITE_QPC = 0x05;
const uint8_t WRITE_CQC = 0x06;
const uint8_t SET_GROUP = 0x07;
// const uint8_t SET_ALL_GROUP = 0x08;
const uint8_t ALLOC_GROUP = 0x08;

struct Doorbell {
    uint8_t  opcode;
    uint8_t  num;
    uint32_t qpn;
    uint32_t offset;
};
// Command Opcode for Doorbell command
const uint8_t OPCODE_NULL       = 0x00;
const uint8_t OPCODE_SEND       = 0x01;
const uint8_t OPCODE_RECV       = 0x02;
const uint8_t OPCODE_RDMA_WRITE = 0x03;
const uint8_t OPCODE_RDMA_READ  = 0x04;

struct DoorbellFifo {
    DoorbellFifo (uint8_t  opcode, uint8_t  num, 
            uint32_t qpn, uint32_t offset) {
        this->opcode = opcode;
        this->num = num;
        this->qpn = qpn;
        this->offset = offset;
    }
    DoorbellFifo (uint8_t num, uint32_t qpn, uint8_t type) 
    {
        this->num = num;
        this->qpn = qpn;
        this->opcode = type;
    }
    uint8_t  opcode; // for pseudo doorbell, this field indicates the type of QP
    uint8_t  num;
    uint32_t qpn;
    uint32_t offset;
    // Addr     qpAddr;
};
typedef std::shared_ptr<DoorbellFifo> DoorbellPtr;


/* Mailbox offset in CEU command */
// INIT_ICM
struct InitResc {
    uint8_t qpsNumLog;
    uint8_t cqsNumLog;
    uint8_t mptNumLog;
    uint64_t qpcBase;
    uint64_t cqcBase;
    uint64_t mptBase;
    uint64_t mttBase;
    uint64_t tqBase;
};
// const uint32_t MBOX_INIT_SZ = 0x20;

// WRITE_ICM
struct IcmResc {
    uint16_t pageNum;
    uint64_t vAddr;
    uint64_t pAddr;
};
const uint8_t ICMTYPE_MPT = 0x01;
const uint8_t ICMTYPE_MTT = 0x02;
const uint8_t ICMTYPE_QPC = 0x03;
const uint8_t ICMTYPE_CQC = 0x04;
const uint8_t ICMTYPE_TQ  = 0x05;

/* WRITE_MTT */
struct MttResc {
    uint64_t pAddr;
};


/* WRITE_MPT */
struct MptResc {
    uint32_t flag;
    uint32_t key;
    uint64_t startVAddr;
    uint64_t length;
    uint64_t mttSeg;
};
// Same as ibv_mr_flag
const uint8_t MPT_FLAG_RD     = (1 << 0);
const uint8_t MPT_FLAG_WR     = (1 << 1);
const uint8_t MPT_FLAG_LOCAL  = (1 << 2);
const uint8_t MPT_FLAG_REMOTE = (1 << 3);

// WRITE_QP
// WARNING: The size of QPC must be 256B!
struct QpcResc {
    uint8_t flag; // QP state, not useed now
    uint8_t qpType;
    uint8_t sqSizeLog; /* The size of SQ in log (It is now fixed at 4KB, which is 12) */
    uint8_t rqSizeLog; /* The size of RQ in log (It is now fixed at 4KB, which is 12) */
    uint16_t sndWqeOffset;
    uint16_t rcvWqeOffset;
    uint16_t lLid; // Local LID
    uint16_t dLid; // Dest  LID
    uint32_t srcQpn; // Local qpn
    uint32_t destQpn; // Dest qpn
    uint32_t sndPsn; // next send psn
    uint32_t ackPsn; // last acked psn
    uint32_t expPsn; // next receive (expect) psn
    uint32_t cqn;
    uint32_t sndWqeBaseLkey; // send wqe base lkey
    uint32_t rcvWqeBaseLkey; // receive wqe base lkey
    uint32_t qkey;
    uint32_t reserved[51];

    uint8_t  indicator; // 1: latency-sensitive; 2: bandwidth-sensitive; 3: message rate sensitive
    uint8_t  perfWeight;
    uint8_t  groupID;
    uint8_t  qosReserve;
};

const uint8_t QP_TYPE_RC = 0x00;
const uint8_t QP_TYPE_UC = 0x01;
const uint8_t QP_TYPE_RD = 0x02;
const uint8_t QP_TYPE_UD = 0x03;

// WRITE_CQ
struct CqcResc {
    uint32_t cqn;
    uint32_t offset; // The offset of the CQ
    uint32_t lkey;   // lkey of the CQ

    // !TODO We don't implement it now.
    uint32_t sizeLog; // The size of CQ. (It is now fixed at 4KB)
};


const uint32_t WR_FLAG_SIGNALED = (1 << 31);

/**
 * @note Send descriptor struct. This struct must BE IDENTICAL to the difinition in libhgrnic!!!!
 * 
*/
struct TxDesc {

    TxDesc(TxDesc * tx) {
        this->len               = tx->len;
        this->lkey              = tx->lkey;
        this->lVaddr            = tx->lVaddr;
        this->flags             = tx->flags;
        this->sendType.destQpn  = tx->sendType.destQpn;
        this->sendType.dlid     = tx->sendType.dlid;
        this->sendType.qkey     = tx->sendType.qkey;
        // this->qpn               = tx->qpn;
    }

    TxDesc(std::shared_ptr<TxDesc> tx) {
        this->len               = tx->len;
        this->lkey              = tx->lkey;
        this->lVaddr            = tx->lVaddr;
        this->flags             = tx->flags;
        this->sendType.destQpn  = tx->sendType.destQpn;
        this->sendType.dlid     = tx->sendType.dlid;
        this->sendType.qkey     = tx->sendType.qkey;
        // this->qpn               = tx->qpn;
    }

    TxDesc() {
        this->len               = 0;
        this->lkey              = 0;
        this->lVaddr            = 0;
        this->flags             = 0;
        this->sendType.destQpn  = 0;
        this->sendType.dlid     = 0;
        this->sendType.qkey     = 0;
        // this->qpn               = 0;
    }

    bool isSignaled () {
        return (this->flags & WR_FLAG_SIGNALED) != 0;
    }

    // set that this WQE needs completion (32nd bit)
    void setCompleteSignal()
    {
        this->flags = this->flags | (1 << 31);
    }

    // cancel the completion signal of this WQE
    void cancelCompleteSignal()
    {
        this->flags = this->flags & ~(1 << 31);
    }

    // bool isQueUpdate()
    // {
    //     return (this->flags & (1 << 30));
    // }

    // void setQueUpdate()
    // {
    //     this->flags = this->flags | (1 << 30);
    // }

    uint32_t len;
    uint32_t lkey;
    uint64_t lVaddr;
    
    // uint32_t qpn;

    union {
        struct {        
            uint32_t dlid;
            uint32_t qkey;
            uint32_t destQpn;
        } sendType;
        struct {
            uint32_t rkey;
            uint32_t rVaddr_l;
            uint32_t rVaddr_h;
        } rdmaType;
    };
    // uint8_t opcode;

    union {
        uint32_t flags; // 32nd bit indicates CQE generation, 31st bit indicates QPN queue update
        uint8_t  opcode;
    };
};
typedef std::shared_ptr<TxDesc> TxDescPtr;


// Receive Descriptor struct
struct RxDesc {

    RxDesc(RxDesc * rx) {
        this->len = rx->len;
        this->lkey = rx->lkey;
        this->lVaddr = rx->lVaddr;
    }

    RxDesc() {
        this->len    = 0;
        this->lkey   = 0;
        this->lVaddr = 0;
    }

    uint32_t len;
    uint32_t lkey;
    uint64_t lVaddr;
};
typedef std::shared_ptr<RxDesc> RxDescPtr;

struct CqDesc {
    CqDesc(uint8_t srvType, uint8_t transType, 
            uint16_t byteCnt, uint32_t qpn, uint32_t cqn) {
        this->srvType   = srvType;
        this->transType = transType;
        this->byteCnt   = byteCnt;
        this->qpn       = qpn;
        this->cqn       = cqn;
    }
    uint8_t  srvType;
    uint8_t  transType;
    uint16_t byteCnt;
    uint32_t qpn;
    uint32_t cqn;
};
// const uint8_t CQ_ENTRY_SZ = 12;
typedef std::shared_ptr<CqDesc> CqDescPtr;


/* Descriptor read & Data read&write request */
struct MrReqRsp {
    
    MrReqRsp(uint8_t type, uint8_t chnl, uint32_t lkey, 
            uint32_t len, uint32_t vaddr) {
        this->type = type;
        this->chnl = chnl;
        this->lkey = lkey;
        this->length = len;
        this->offset = vaddr;
        
        this->wrDataReq = nullptr;
    }

    uint8_t  type  ; /* 1 - wreq; 2 - rreq, 3 - rrsp; */
    uint8_t  chnl  ; /* 1 - wreq TX cq; 2 - wreq RX cq; 3 - wreq TX data; 4 - wreq RX data;
                      * 5 - rreq TX Desc; 6 - rreq RX Desc; 7 - rreq TX Data; 8 - rreq RX Data */
    uint32_t lkey  ;
    uint32_t length; /* in Bytes */
    uint32_t offset; /* Accessed VAddr, used to compare with vaddr in MPT, 
                      * and calculate MTT Index, Besides, this field also provides
                      * access offset to the actual paddr. 
                      * !TODO: Now we only support lower 16 bit comparasion with Vaddr, 
                      * which means support maximum 16KB for one MR. */
    uint32_t mttNum;        /* MTT item number corresponding to this MR request, equals to DMA request number */
    uint32_t mttRspNum;     /* number of responded MTT items */ 
    uint32_t dmaRspNum;     /* number of responded DMA requests */ 
    uint32_t sentPktNum;    /* number of Ethernet packet that has finished */
    struct MptResc *mpt;
    union {
        TxDesc  *txDescRsp;
        RxDesc  *rxDescRsp;
        CqDesc  *cqDescReq;
        uint8_t *wrDataReq;
        uint8_t *rdDataRsp;
        uint8_t *data;
    };
};
typedef std::shared_ptr<MrReqRsp> MrReqRspPtr;
const uint8_t DMA_TYPE_WREQ = 0x01;
const uint8_t DMA_TYPE_RREQ = 0x02;
const uint8_t DMA_TYPE_RRSP = 0x03;

const uint8_t TPT_WCHNL_TX_CQUE = 0x01;
const uint8_t TPT_WCHNL_RX_CQUE = 0x02;
const uint8_t TPT_WCHNL_TX_DATA = 0x03;
const uint8_t TPT_WCHNL_RX_DATA = 0x04;
const uint8_t MR_RCHNL_TX_DESC = 0x05;
const uint8_t MR_RCHNL_RX_DESC = 0x06;
const uint8_t MR_RCHNL_TX_DATA = 0x07;
const uint8_t MR_RCHNL_RX_DATA = 0x08;


struct CxtReqRsp {
    CxtReqRsp (uint8_t type, uint8_t chnl, uint32_t num, uint32_t sz = 1, uint8_t idx = 0) {
        this->type = type;
        this->chnl = chnl;
        this->num  = num;
        this->sz   = sz;
        this->idx  = idx;
        this->txCqcRsp = nullptr;
    }
    uint8_t type; // 1: qp wreq; 2: qp rreq; 3: qp rrsp; 4: cq rreq; 5: cq rrsp; 6: sq addr req
    uint8_t chnl; // 1: tx Channel; 2: rx Channel
    uint32_t num; // Resource num (QPN or CQN).
    uint32_t sz; // request number of the resources, used in qpc read (TX)
    uint8_t  idx; // used to uniquely identify the req pkt */
    union {
        QpcResc  *txQpcRsp;
        QpcResc  *rxQpcRsp;
        QpcResc  *txQpcReq;
        QpcResc  *rxQpcReq;
        CqcResc  *txCqcRsp;
        CqcResc  *rxCqcRsp;
    };
};
typedef std::shared_ptr<CxtReqRsp> CxtReqRspPtr;
const uint8_t CXT_WREQ_QP = 0x01;
const uint8_t CXT_RREQ_QP = 0x02;
const uint8_t CXT_RRSP_QP = 0x03;
const uint8_t CXT_RREQ_CQ = 0x04;
const uint8_t CXT_RRSP_CQ = 0x05;
const uint8_t CXT_RREQ_SQ = 0x06; /* read sq addr */
const uint8_t CXT_CREQ_QP = 0x07; /* create request */
const uint8_t CXT_CHNL_TX = 0x01;
const uint8_t CXT_CHNL_RX = 0x02;

struct DF2DD {
    uint8_t  opcode;
    uint8_t  num;
    uint32_t qpn;
};

struct DD2DP {
    QpcResc *qpc; 
    TxDesc  *desc; // tx descriptor
};

struct DP2RG {
    QpcResc*     qpc; 
    TxDescPtr    desc; // tx descriptor
    EthPacketPtr txPkt;
};
typedef std::shared_ptr<DP2RG> DP2RGPtr;

struct RA2RG {
    QpcResc *qpc;
    EthPacketPtr txPkt;
};

struct DmaReq {
    DmaReq (Addr addr, int size, Event *event, uint8_t *data, uint32_t chnl=0) {
        this->addr  = addr;
        this->size  = size;
        this->event = event;
        this->data  = data;
        this->chnl  = chnl;
        this->rdVld = 0;
        this->schd  = 0;
        this->reqType = 0;
    }
    Addr         addr  ; 
    int          size  ; 
    Event       *event ;
    uint8_t      rdVld ; /* the dma req's return data is valid */
    uint8_t     *data  ; 
    uint32_t     chnl  ; /* channel number the request belongs to, see below DMA_REQ_* for details */
    Tick         schd  ; /* when to schedule the event */
    uint8_t      reqType; /* type of request: 0 for read request, 1 for write request */
};
typedef std::shared_ptr<DmaReq> DmaReqPtr;

struct PendingElem {
    uint8_t idx;
    uint8_t chnl;
    uint32_t qpn;
    CxtReqRspPtr reqPkt;
    bool has_dma;
    
    PendingElem(uint8_t idx, uint8_t chnl, CxtReqRspPtr reqPkt, bool has_dma) {
        this->idx     = idx;
        this->chnl    = chnl;
        this->qpn     = reqPkt->num;
        this->reqPkt  = reqPkt;
        this->has_dma = has_dma;
    }

    PendingElem() {
        this->idx     = 0;
        this->chnl    = 0;
        this->qpn     = 0;
        this->reqPkt  = nullptr;
        this->has_dma = false;
    }

    ~PendingElem() {
        // HANGU_PRINT(Debug::CxtResc, "[CxtResc] ~PendingElem()\n");
    }
};
typedef std::shared_ptr<PendingElem> PendingElemPtr;

struct WindowElem {
    WindowElem(EthPacketPtr txPkt, uint32_t qpn, 
            uint32_t psn, TxDescPtr txDesc) {
        this->txPkt = txPkt;
        this->qpn   = qpn;
        this->psn   = psn;
        this->txDesc = txDesc;
    };
    EthPacketPtr txPkt;
    uint32_t qpn;
    uint32_t psn;

    TxDescPtr txDesc;
};
typedef std::shared_ptr<WindowElem> WindowElemPtr;
typedef std::list<WindowElemPtr> WinList;

/* Window List for one QP */
struct WinMapElem {
    WinList *list;      /* List of send packet and it attached information */
    uint32_t firstPsn;  /* First PSN in the list */
    uint32_t lastPsn;   /* Last PSN in the list */
    uint32_t cqn;       /* CQN for this QP (SQ) */
};

struct BTH {
    /* srv_type : trans_type : dest qpn
     * [31:29]     [28:24]     [23:0]   
     */
    uint32_t op_destQpn;

    /* needAck :  psn
     * [31:24]   [23:0]
     */
    uint32_t needAck_psn;
};
const uint8_t PKT_BTH_SZ = 8; // in bytes
const uint8_t PKT_TRANS_SEND_FIRST = 0x01;
const uint8_t PKT_TRANS_SEND_MID   = 0x02;
const uint8_t PKT_TRANS_SEND_LAST  = 0x03;
const uint8_t PKT_TRANS_SEND_ONLY  = 0x04;
const uint8_t PKT_TRANS_RWRITE_ONLY= 0x05;
const uint8_t PKT_TRANS_RREAD_ONLY = 0x06;
const uint8_t PKT_TRANS_ACK        = 0x07;

struct DETH {
    uint32_t qKey;
    uint32_t srcQpn;
};
const uint8_t PKT_DETH_SZ = 8; // in bytes

struct RETH {
    uint32_t rVaddr_l;
    uint32_t rVaddr_h;
    uint32_t rKey;
    uint32_t len;
};
const uint8_t PKT_RETH_SZ = 16; // in bytes

struct AETH {
    
    // syndrome :   msn
    // [31:24]    [23:0]
    uint32_t syndrome_msn;
};
const uint8_t PKT_AETH_SZ = 4; // in bytes
const uint8_t RSP_ACK = 0x01;
const uint8_t RSP_NAK = 0x02;



#define ADD_FIELD32(NAME, OFFSET, BITS) \
    inline uint32_t NAME() { return bits(_data, OFFSET+BITS-1, OFFSET); } \
    inline void NAME(uint32_t d) { replaceBits(_data, OFFSET+BITS-1, OFFSET,d); }

#define ADD_FIELD64(NAME, OFFSET, BITS) \
    inline uint64_t NAME() { return bits(_data, OFFSET+BITS-1, OFFSET); } \
    inline void NAME(uint64_t d) { replaceBits(_data, OFFSET+BITS-1, OFFSET,d); }

struct Regs : public Serializable {
    template<class T>
    struct Reg {
        T _data;
        T operator()() { return _data; }
        const Reg<T> &operator=(T d) { _data = d; return *this;}
        bool operator==(T d) { return d == _data; }
        void operator()(T d) { _data = d; }
        Reg() { _data = 0; }
        void serialize(CheckpointOut &cp) const
        {
            SERIALIZE_SCALAR(_data);
        }
        void unserialize(CheckpointIn &cp)
        {
            UNSERIALIZE_SCALAR(_data);
        }
    };
    
    struct INPARAM : public Reg<uint64_t> {
        using Reg<uint64_t>::operator=;
        ADD_FIELD64(iparaml,0,32);
        ADD_FIELD64(iparamh,32,32);
    };
    INPARAM inParam;

    uint32_t modifier;
    
    struct OUTPARAM : public Reg<uint64_t> {
        using Reg<uint64_t>::operator=;
        ADD_FIELD64(oparaml,0,32);
        ADD_FIELD64(oparamh,32,32);
    };
    OUTPARAM outParam;

    struct CMDCTRL : public Reg<uint32_t> {
        using Reg<uint32_t>::operator=;
        ADD_FIELD32(op,0,8);
        ADD_FIELD32(go,31,1);
    };
    CMDCTRL cmdCtrl;

    struct DOORBELL : public Reg<uint64_t> {
        using Reg<uint64_t>::operator=;
        ADD_FIELD64(dbl,0,32);
        ADD_FIELD64(dbh,32,32);
        ADD_FIELD64(opcode,0,4);
        ADD_FIELD64(offset,4,28);
        ADD_FIELD64(num,32,8);
        ADD_FIELD64(qpn,40,24);
    };
    DOORBELL db;

    uint64_t qosShareAddr = 0;


    uint64_t mptBase;
    uint64_t mttBase;
    uint64_t qpcBase;
    uint64_t cqcBase;

    uint8_t  mptNumLog;
    uint8_t  mttNumLog;
    uint8_t  qpcNumLog;
    uint8_t  cqcNumLog;

    
    void serialize(CheckpointOut &cp) const override {
        paramOut(cp, "inParam", inParam._data);
        paramOut(cp, "modifier", modifier);
        paramOut(cp, "outParam", outParam._data);
        paramOut(cp, "cmdCtrl", cmdCtrl._data);
        paramOut(cp, "db", db._data);
        paramOut(cp, "mptBase", mptBase);
        paramOut(cp, "mttBase", mttBase);
        paramOut(cp, "qpcBase", qpcBase);
        paramOut(cp, "cqcBase", cqcBase);
        paramOut(cp, "mptNumLog", mptNumLog);
        paramOut(cp, "mttNumLog", mttNumLog);
        paramOut(cp, "qpcNumLog", qpcNumLog);
        paramOut(cp, "cqcNumLog", cqcNumLog);
    }

    void unserialize(CheckpointIn &cp) override {

        paramIn(cp, "inParam", inParam._data);
        paramIn(cp, "modifier", modifier);
        paramIn(cp, "outParam", outParam._data);
        paramIn(cp, "cmdCtrl", cmdCtrl._data);
        paramIn(cp, "db", db._data);
        paramIn(cp, "mptBase", mptBase);
        paramIn(cp, "mttBase", mttBase);
        paramIn(cp, "qpcBase", qpcBase);
        paramIn(cp, "cqcBase", cqcBase);
        paramIn(cp, "mptNumLog", mptNumLog);
        paramIn(cp, "mttNumLog", mttNumLog);
        paramIn(cp, "qpcNumLog", qpcNumLog);
        paramIn(cp, "cqcNumLog", cqcNumLog);
    }
};

// WQE Scheduler relevant
struct QPStatusItem
{
    QPStatusItem(uint32_t key, uint8_t weight, uint8_t qos_type, uint32_t qpn, uint8_t group_id, uint8_t service_type)
    {
        this->key                   = key;
        this->weight                = weight;
        this->qpn                   = qpn;
        this->group_id              = group_id;
        this->head_ptr              = 0; // unit: descriptor!
        // this->fetch_ptr             = 0;
        this->tail_ptr              = 0; // unit: descriptor!
        this->wnd_start             = 0;
        this->fetch_offset          = 0;
        // this->wnd_fetch             = 0;
        this->wnd_end               = 0;
        // this->current_msg_offset    = 0;
        this->fetch_lock            = 0;
        this->in_que                = 0;
        this->fetch_count           = 0;
        assert(service_type != QP_TYPE_RD);
        switch (service_type)
        {
            case QP_TYPE_RC:
                this->type = qos_type;
                break;
            case QP_TYPE_UC:
                this->type = UC_QP;
                break;
            case QP_TYPE_RD:
                // this->type = ;
                break;
            case QP_TYPE_UD:
                this->type = UD_QP;
                break;
            default:
                break;
        }
    }
    // queue pointers
    uint32_t head_ptr;
    // uint32_t fetch_ptr; // next WQE to fetch
    uint32_t tail_ptr;
    // window
    uint32_t wnd_start; // start offset in the current message
    uint32_t fetch_offset; // offset pointer in the current message
    uint32_t wnd_end;
    // uint32_t wnd_fetch;
    // uint32_t current_msg_offset;
    uint32_t key;
    uint8_t weight;
    uint8_t type; // 1: latency, 2: bandwidth, 3: rate, 4: UC, 5: UD. In regard to librdma.h
    uint32_t qpn;
    uint8_t perf; // This segment indicates whether the performance exceeds or is lower than expected
    uint8_t group_id;
    uint8_t in_least_que; // This segment indicates the existance in the least priority queue
    uint8_t in_que; // This segment indicates the existance in the low priority queue
    // This indicates whether it is allowed to fetch WQEs for this QP. 
    // Lock it when send WQE read request; unlock it when WQE splitting is finished.
    uint8_t fetch_lock; 
    uint64_t fetch_count;
};
typedef std::shared_ptr<QPStatusItem> QPStatusPtr;

struct GroupInfo
{
    uint8_t groupID;
    uint16_t granularity;
};


} // namespace HanGuRnicDef

#endif // __HANGU_RNIC_DEFS_HH__