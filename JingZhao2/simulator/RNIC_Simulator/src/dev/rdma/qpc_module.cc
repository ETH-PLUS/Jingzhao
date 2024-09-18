#include "dev/rdma/hangu_rnic.hh"
#include <algorithm>
#include <memory>
#include <queue>
#include "base/inet.hh"
#include "base/trace.hh"
#include "base/random.hh"
#include "debug/Drain.hh"
#include "dev/net/etherpkt.hh"
#include "debug/HanGu.hh"
#include "mem/packet.hh"
#include "mem/packet_access.hh"
#include "params/HanGuRnic.hh"
#include "sim/stats.hh"
#include "sim/system.hh"

using namespace HanGuRnicDef;
using namespace Net;
using namespace std;

///////////////////////////// HanGuRnic::QpcModule {begin}//////////////////////////////
bool 
HanGuRnic::QpcModule::postQpcReq(CxtReqRspPtr qpcReq) {
    assert( (qpcReq->type == CXT_WREQ_QP) || 
            (qpcReq->type == CXT_RREQ_QP) || 
            (qpcReq->type == CXT_RREQ_SQ) ||
            (qpcReq->type == CXT_CREQ_QP));
    assert( (qpcReq->chnl == CXT_CHNL_TX) || 
            (qpcReq->chnl == CXT_CHNL_RX));
    if (qpcReq->type == CXT_CREQ_QP) {
        ccuQpcWreqFifo.push(qpcReq);
    } else if (qpcReq->chnl == CXT_CHNL_TX && qpcReq->type == CXT_RREQ_SQ) {
        txQpAddrRreqFifo.push(qpcReq);
    } else if (qpcReq->chnl == CXT_CHNL_TX && qpcReq->type == CXT_RREQ_QP) {
        txQpcRreqFifo.push(qpcReq);
    } else if (qpcReq->chnl == CXT_CHNL_RX && qpcReq->type == CXT_RREQ_QP) {
        rxQpcRreqFifo.push(qpcReq);
    } else {
        panic("[QpcModule.postQpcReq] invalid chnl %d or type %d", qpcReq->chnl, qpcReq->type);
    }
    if (!qpcReqProcEvent.scheduled()) { /* Schedule qpcReqProc() */
        rnic->schedule(qpcReqProcEvent, curTick() + rnic->clockPeriod());
    }
    return true;
}

bool qpcTxUpdate (QpcResc &resc, uint32_t sz) {
    if (resc.qpType == QP_TYPE_RC) {
        resc.ackPsn += sz;
        resc.sndPsn += sz;
    }
    resc.sndWqeOffset += sz * sizeof(TxDesc);
    if (resc.sndWqeOffset + sizeof(TxDesc) > (1 << resc.sqSizeLog)) {
        resc.sndWqeOffset = 0; /* Same as in userspace drivers */
    }
    
    return true;
}

bool qpcRxUpdate (QpcResc &resc) {
    if (resc.qpType == QP_TYPE_RC) {
        resc.expPsn += 1;
        HANGU_PRINT(CxtResc, "RC QP qpcRxUpdate, QPN: %d, dst QPN: %d, epsn: %d\n", resc.srcQpn, resc.destQpn, resc.expPsn);
    }
    resc.rcvWqeOffset += sizeof(RxDesc);
    if (resc.rcvWqeOffset + sizeof(RxDesc) > (1 << resc.rqSizeLog)) {
        resc.rcvWqeOffset = 0; /* Same as in userspace drivers */
    }
    
    assert(resc.rqSizeLog == 12);
    return true;
}

void 
HanGuRnic::QpcModule::hitProc(uint8_t chnlNum, CxtReqRspPtr qpcReq) {
    qpcCache.readEntry(qpcReq->num, qpcReq->txQpcRsp);
    assert(qpcReq->num == qpcReq->txQpcRsp->srcQpn);

    HANGU_PRINT(CxtResc, " QpcModule.qpcReqProc.readProc.hitProc: qpn %d hit, chnlNum %d idx %d\n", 
            qpcReq->txQpcRsp->srcQpn, chnlNum, qpcReq->idx);

    /* Post rsp to related fifo, schedule related rsp receiving module */
    Event *e;
    if (chnlNum == 0) { // txQpAddrRspFifo
        txQpAddrRspFifo.push(qpcReq);
        // e = &rnic->rdmaEngine.dfuEvent;
        e = &rnic->descScheduler.qpcRspEvent;
    } else if (chnlNum == 1) { // txQpcRspFifo
        /* update after read */
        uint32_t sz = qpcReq->sz;
        qpcCache.updateEntry(qpcReq->num, [sz](QpcResc &qpc) { return qpcTxUpdate(qpc, sz); });

        txQpcRspFifo.push(qpcReq);
        e = &rnic->rdmaEngine.dpuEvent;
    } else if (chnlNum == 2) { // rxQpcRspFifo
        /* update after read */
        qpcCache.updateEntry(qpcReq->num, [](QpcResc &qpc) { return qpcRxUpdate(qpc); });

        rxQpcRspFifo.push(qpcReq);
        e = &rnic->rdmaEngine.rpuEvent;
    } else {
        panic("[QpcModule.readProc.hitProc] Unrecognized chnl %d or type %d", qpcReq->chnl, qpcReq->type);
    }

    if (!e->scheduled()) {
        rnic->schedule(*e, curTick() + rnic->clockPeriod());
    }
}

bool 
HanGuRnic::QpcModule::readProc(uint8_t chnlNum, CxtReqRspPtr qpcReq) {
    HANGU_PRINT(CxtResc, " QpcModule.qpcReqProc.readProc!\n");
    /* Lookup qpnHashMap to learn that if there's 
     * pending elem for this qpn in this channel. */
    if (qpnHashMap.find(qpcReq->num) != qpnHashMap.end()) { /* related qpn is found in qpnHashMap, check if pending */
        qpnHashMap[qpcReq->num]->reqCnt += 1;
        HANGU_PRINT(CxtResc, " QpcModule.qpcReqProc.readProc: related qpn is found in qpnHashMap qpn %d idx %d\n", 
                qpcReq->num, qpcReq->idx);
        HANGU_PRINT(CxtResc, " QpcModule.qpcReqProc.readProc: qpnMap.size() %d get_size() %d\n", 
                qpnHashMap.size(), pendStruct.get_size());
        /* save req to pending fifo */
        PendingElemPtr pElem =  make_shared<PendingElem>(qpcReq->idx, chnlNum, qpcReq, false); // new PendingElem(qpcReq->idx, chnlNum, qpcReq, false);
        pendStruct.push_elem(pElem);
        HANGU_PRINT(CxtResc, " QpcModule.qpcReqProc.readProc: qpnMap.size() %d get_size() %d\n", 
                qpnHashMap.size(), pendStruct.get_size());
        return true;
    }
    /* Lookup QPC in QPC Cache */
    if (qpcCache.lookupHit(qpcReq->num)) { /* cache hit, and return related rsp to related fifo */
        HANGU_PRINT(CxtResc, " QpcModule.qpcReqProc.readProc: cache hit, qpn %d\n", qpcReq->num);
        hitProc(chnlNum, qpcReq);
    } else { /* cache miss */
        HANGU_PRINT(CxtResc, " QpcModule.qpcReqProc.readProc: cache miss, qpn %d, rtnCnt %d\n", qpcReq->num, rtnCnt);
        /* save req to pending fifo */
        HANGU_PRINT(CxtResc, " QpcModule.qpcReqProc.readProc: qpnMap.size() %d get_size() %d\n", 
                qpnHashMap.size(), pendStruct.get_size());
        PendingElemPtr pElem = make_shared<PendingElem>(qpcReq->idx, chnlNum, qpcReq, true);
        pendStruct.push_elem(pElem);
        HANGU_PRINT(CxtResc, " QpcModule.qpcReqProc.readProc: qpnMap.size() %d get_size() %d\n", 
                qpnHashMap.size(), pendStruct.get_size());
        /* write an entry to qpnHashMap */
        QpnInfoPtr qpnInfo = make_shared<QpnInfo>(qpcReq->num); // new QpnInfo(qpcReq->num);
        qpnHashMap.emplace(qpcReq->num, qpnInfo);
        HANGU_PRINT(CxtResc, " QpcModule.qpcReqProc.readProc: qpnHashMap.size %d rtnCnt %d\n", qpnHashMap.size(), rtnCnt);
    }
    HANGU_PRINT(CxtResc, " QpcModule.qpcReqProc.readProc: out!\n");
    return true;
}

void 
HanGuRnic::QpcModule::qpcCreate() {
    CxtReqRspPtr qpcReq = ccuQpcWreqFifo.front();
    ccuQpcWreqFifo.pop();
    assert(qpcReq->type == CXT_CREQ_QP);
    assert(qpcReq->num == qpcReq->txQpcReq->srcQpn);

    HANGU_PRINT(CxtResc, " QpcModule.qpcCreate: srcQpn %d sndBaseLkey %d\n", qpcReq->txQpcReq->srcQpn, qpcReq->txQpcReq->sndWqeBaseLkey);
    writeOne(qpcReq);

    /* delete useless qpc, cause writeEntry use memcpy 
     * to build cache entry. */
    delete qpcReq->txQpcReq;
}

void 
HanGuRnic::QpcModule::qpcAccess() {
    uint8_t CHNL_NUM = 3;
    bool isEmpty[CHNL_NUM];
    isEmpty[0] = txQpAddrRreqFifo.empty();
    isEmpty[1] = txQpcRreqFifo.empty();
    isEmpty[2] = rxQpcRreqFifo.empty();
    HANGU_PRINT(CxtResc, " QpcModule.qpcReqProc.qpcAccess: empty[0] %d empty[1] %d empty[2] %d\n", isEmpty[0], isEmpty[1], isEmpty[2]);
    CxtReqRspPtr qpcReq;
    for (uint8_t cnt = 0; cnt < CHNL_NUM; ++cnt) {
        if (isEmpty[this->chnlIdx] == false) {
            switch (this->chnlIdx) {
              case 0:
                qpcReq = txQpAddrRreqFifo.front();
                txQpAddrRreqFifo.pop();
                assert(qpcReq->chnl == CXT_CHNL_TX && qpcReq->type == CXT_RREQ_SQ);
                break;
              case 1:
                qpcReq = txQpcRreqFifo.front();
                txQpcRreqFifo.pop();
                assert(qpcReq->chnl == CXT_CHNL_TX && qpcReq->type == CXT_RREQ_QP);
                break;
              case 2:
                qpcReq = rxQpcRreqFifo.front();
                rxQpcRreqFifo.pop();
                assert(qpcReq->chnl == CXT_CHNL_RX && qpcReq->type == CXT_RREQ_QP);
                break;
              default:
                panic("[QpcModule.qpcReqProc.qpcAccess] chnlIdx error! %d", this->chnlIdx);
                break;
            }
            HANGU_PRINT(CxtResc, " QpcModule.qpcReqProc.qpcAccess: qpn: %d, chnlIdx %d, idx %d rtnCnt %d\n", 
                    qpcReq->num, this->chnlIdx, qpcReq->idx, rtnCnt);
            assert((qpcReq->num & QPN_MASK) <= QPN_NUM);
            readProc(this->chnlIdx, qpcReq);
            /* Point to next chnl */
            ++this->chnlIdx;
            this->chnlIdx = this->chnlIdx % CHNL_NUM;
            HANGU_PRINT(CxtResc, " QpcModule.qpcReqProc.qpcAccess: out!\n");
            return;
        } else {
            /* Point to next chnl */
            ++this->chnlIdx;
            this->chnlIdx = this->chnlIdx % CHNL_NUM;
        }
    }
}

void 
HanGuRnic::QpcModule::writeOne(CxtReqRspPtr qpcReq) {
    HANGU_PRINT(CxtResc, " QpcModule.writeOne!\n");

    HANGU_PRINT(CxtResc, " QpcModule.writeOne: srcQpn 0x%x, num %d, idx %d, chnl %d, sndBaseLkey %d\n", qpcReq->txQpcReq->srcQpn, qpcReq->num, qpcReq->idx, qpcReq->chnl, qpcReq->txQpcReq->sndWqeBaseLkey);
    assert(qpcReq->num == qpcReq->txQpcReq->srcQpn);

    if (qpcCache.lookupFull(qpcReq->num)) {

        /* get replaced qpc */
        uint32_t wbQpn = qpcCache.replaceEntry();
        QpcResc* qpc = qpcCache.deleteEntry(wbQpn);
        HANGU_PRINT(CxtResc, " QpcModule.writeOne: get replaced qpc 0x%x(%d)\n", wbQpn, (wbQpn & RESC_LIM_MASK));
        
        /* get related icm addr */
        uint64_t paddr = qpcIcm.num2phyAddr(wbQpn);

        /* store replaced qpc back to memory */
        storeMem(paddr, qpc);
    }

    /* write qpc entry back to cache */
    qpcCache.writeEntry(qpcReq->num, qpcReq->txQpcRsp);
    HANGU_PRINT(CxtResc, " QpcModule.writeOne: out!\n");
}

void 
HanGuRnic::QpcModule::storeMem(uint64_t paddr, QpcResc *qpc) {
    DmaReqPtr dmaReq = make_shared<DmaReq>(paddr, sizeof(QpcResc), 
            nullptr, (uint8_t *)qpc, 0); /* last param is useless here */
    dmaReq->reqType = 1; /* this is a write request */
    rnic->cacheDmaAccessFifo.push(dmaReq);
    if (!rnic->dmaEngine.dmaWriteEvent.scheduled()) {
        rnic->schedule(rnic->dmaEngine.dmaWriteEvent, curTick() + rnic->clockPeriod());
    }
}

DmaReqPtr 
HanGuRnic::QpcModule::loadMem(CxtReqRspPtr qpcReq) {

    HANGU_PRINT(CxtResc, " QpcModule.loadMem: Post qpn %d to dmaEngine, idx %d, pending size %d\n", 
            qpcReq->num, qpcReq->idx, pendStruct.get_size());
    
    PendingElemPtr pElem = pendStruct.front_elem();
    HANGU_PRINT(CxtResc, " QpcModule.loadMem: qpn %d chnl %d has_dma %d, idx %d\n", 
            pElem->qpn, pElem->chnl, pElem->has_dma, pElem->idx);
    assert((pElem->qpn & QPN_MASK) <= QPN_NUM);

    /* get qpc request icm addr, and post read request to ICM memory */
    uint64_t paddr = qpcIcm.num2phyAddr(qpcReq->num);
    DmaReqPtr dmaReq = make_shared<DmaReq>(paddr, sizeof(QpcResc), 
            &qpcRspProcEvent, (uint8_t *)qpcReq->txQpcReq, 0); /* last param is useless here */
    rnic->cacheDmaAccessFifo.push(dmaReq);
    if (!rnic->dmaEngine.dmaReadEvent.scheduled()) {
        rnic->schedule(rnic->dmaEngine.dmaReadEvent, curTick() + rnic->clockPeriod());
    }

    return dmaReq;
}

uint8_t 
HanGuRnic::QpcModule::checkNoDmaElem(PendingElemPtr pElem, uint8_t chnlNum, uint32_t qpn) {
    HANGU_PRINT(CxtResc, " QpcModule.qpcRspProc.checkNoDmaElem!\n");
    QpnInfoPtr qInfo = qpnHashMap[qpn];
    assert(qInfo->reqCnt);
    /* check if qpn attached to this elem is in cache */
    if (qpcCache.lookupHit(qpn)) { /* cache hit */
        HANGU_PRINT(CxtResc, " QpcModule.qpcRspProc.checkNoDmaElem: qpcCache.lookupHit. qInfo->reqCnt %d\n", qInfo->reqCnt);
        /* update qpnHashMap, and delete invalid elem in qpnMap */
        qInfo->reqCnt -= 1;
        if (qInfo->reqCnt == 0) {
            --rtnCnt;
            qpnHashMap.erase(qpn);
        }
        /* return rsp to qpcRspFifo */
        hitProc(chnlNum, pElem->reqPkt);
        /* update pendingFifo */
        pendStruct.succ_elem_check();
        return 0;
    } else if (qInfo->isReturned) { /* cache miss && accordingly qpc is returned */
        HANGU_PRINT(CxtResc, " QpcModule.qpcRspProc.checkNoDmaElem: cache miss && accordingly qpc is returned\n");
        /* delete isReturned && --rtnCnt */
        qInfo->reqRePosted();
        --rtnCnt;
        /* repost this request to pendingFifo */
        pElem->has_dma = 1; /* This request needs to post dma read request this time */
        pendStruct.push_elem_check(pElem);
        return 0;
    }
    return 1;
}

bool 
HanGuRnic::QpcModule::isRspValidRun() {
    return (((rtnCnt != 0) && pendStruct.get_size()) || rnic->qpcDmaRdCplFifo.size());
}

void 
HanGuRnic::QpcModule::qpcRspProc() {
    HANGU_PRINT(CxtResc, " QpcModule.qpcRspProc! rtnCnt %d qpnMap.size %d get_size() %d\n", 
            rtnCnt, qpnHashMap.size(), pendStruct.get_size());
    assert(rtnCnt <= qpnHashMap.size());
    assert(rtnCnt <= pendStruct.get_size());
    for (auto &item : qpnHashMap) {
        uint32_t   key = item.first;
        QpnInfoPtr val = item.second;
        HANGU_PRINT(CxtResc, " QpcModule.qpcRspProc: key %d qpn %d reqCnt %d\n\n", 
                key, val->qpn, val->reqCnt);
    }
    if (rnic->qpcDmaRdCplFifo.size()) { /* processing dmaRsp pkt */
        HANGU_PRINT(CxtResc, " QpcModule.qpcRspProc: processing dmaRsp pkt!\n");
        PendingElemPtr pElem = pendStruct.front_elem();
        uint32_t qpn = pElem->reqPkt->num;
        uint8_t  chnlNum = pElem->chnl;
        QpnInfoPtr qInfo = qpnHashMap[qpn];
        if (pElem->has_dma) {
            /* pop the dmaPkt */
            rnic->qpcDmaRdCplFifo.pop();
            /* update isReturned && rtnCnt */
            qInfo->firstReqReturned();
            ++rtnCnt;
            qInfo->reqCnt -= 1;
            /* write loaded qpc entry to qpc cache */
            writeOne(pElem->reqPkt);
            /* return rsp to qpcRspFifo */
            hitProc(chnlNum, pElem->reqPkt);
            HANGU_PRINT(CxtResc, " QpcModule.qpcRspProc: rtnCnt %d get_size() %d, qpnHashMap.size() %d, qInfo->reqCnt %d\n", 
                    rtnCnt, pendStruct.get_size(), qpnHashMap.size(), qInfo->reqCnt);
            /* delete invalid elem in qpnHashMap */
            if (qInfo->reqCnt == 0) {
                --rtnCnt;
                qpnHashMap.erase(qpn);
            }
            /* remove elem in pendingFifo */
            PendingElemPtr tmp = pendStruct.pop_elem();
        } else {
            /* remove the elem in pendingFifo. No matter if we process it, it cannot be placed 
             * to the head of the pendingFifo again. */
            PendingElemPtr tmp = pendStruct.pop_elem();
            uint8_t rtn = checkNoDmaElem(pElem, chnlNum, qpn);
            if (rtn != 0) {
                panic("[QpcModule.qpcRspProc] Error!");
            }
        }
    } else if (isRspValidRun()) {
        if (pendStruct.get_pending_size()) { /* there's elem in pending fifo */
            HANGU_PRINT(CxtResc, " QpcModule.qpcRspProc: processing check pendingElem!\n");
            PendingElemPtr cpElem = pendStruct.get_elem_check();
            uint32_t qpn = cpElem->reqPkt->num;
            uint8_t chnlNum = cpElem->chnl;
            if (cpElem->has_dma) {
                pendStruct.ignore_elem_check(cpElem);
            } else {
                uint8_t rtn = checkNoDmaElem(cpElem, chnlNum, qpn);
                if (rtn != 0) { /* no elem in cache && qpn hasn't returned, ignore it */
                    pendStruct.ignore_elem_check(cpElem);
                    HANGU_PRINT(CxtResc, " QpcModule.qpcRspProc: do not has dma, and check is ignored!\n");
                }
            }
        } else { /* pendingfifo has not been parpared for processing */
            HANGU_PRINT(CxtResc, " QpcModule.qpcRspProc: pendingfifo has not been parpared for processing, maybe next cycle!\n");
        }
    }
    /* if there's under checked elem in pending fifo, 
     * schedule myself again */
    if (isRspValidRun()) {
        if (!qpcRspProcEvent.scheduled()) { /* schedule myself */
            rnic->schedule(qpcRspProcEvent, curTick() + rnic->clockPeriod());
        }
    }
    HANGU_PRINT(CxtResc, " QpcModule.qpcRspProc: out! rtnCnt %d qpnMap.size %d get_size() %d\n", 
            rtnCnt, qpnHashMap.size(), pendStruct.get_size());
    assert(!(rtnCnt && (pendStruct.get_size() == 0)));
    assert(rtnCnt <= qpnHashMap.size());
    assert(rtnCnt <= pendStruct.get_size());
}

bool 
HanGuRnic::QpcModule::isReqValidRun() {
    return (ccuQpcWreqFifo.size()   || 
            txQpAddrRreqFifo.size() || 
            txQpcRreqFifo.size()    || 
            rxQpcRreqFifo.size()      );
}

void
HanGuRnic::QpcModule::qpcReqProc() {
    HANGU_PRINT(CxtResc, " QpcModule.qpcReqProc!\n");
    if (ccuQpcWreqFifo.size()) {
        qpcCreate(); /* execute qpc entry create */
    } else {
        qpcAccess(); /* execute qpc entry read || write */
    }
    HANGU_PRINT(CxtResc, " QpcModule.qpcReqProc: out!\n");
    /* Schedule myself again if there still has elem in fifo */
    if (isReqValidRun()) {
        if (!qpcReqProcEvent.scheduled()) { /* schedule myself */
            rnic->schedule(qpcReqProcEvent, curTick() + rnic->clockPeriod());
        }
    }
}
///////////////////////////// HanGuRnic::QpcModule {end}//////////////////////////////
