
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

///////////////////////////// HanGuRnic::PendingStruct {begin}//////////////////////////////
void 
HanGuRnic::PendingStruct::swapIdx() {
    uint8_t tmp = onlineIdx;
    onlineIdx   = offlineIdx;
    offlineIdx  = tmp;
    assert(onlineIdx != offlineIdx);
}

void 
HanGuRnic::PendingStruct::pushElemProc() {
    
    assert(pushFifo.size());
    PendingElemPtr pElem = pushFifo.front();
    CxtReqRspPtr qpcReq = pElem->reqPkt;
    pushFifo.pop();

    HANGU_PRINT(CxtResc, " PendingStruct.pushElemProc: qpn %d idx %d chnl %d\n", pElem->qpn, pElem->idx, pElem->chnl);
    assert((pElem->qpn & QPN_MASK) <= QPN_NUM);
    assert((pElem->reqPkt->num & QPN_MASK) <= QPN_NUM);
    assert(qpcReq != nullptr);

    /* post pElem to pendingFifo */
    ++elemNum;
    if (pendingFifo[offlineIdx].size()) {
        pendingFifo[offlineIdx].push(pElem);
    } else {
        pendingFifo[onlineIdx].push(pElem);
    }

    /* schedule loadMem to post qpcReq dma pkt to dma engine */
    HANGU_PRINT(CxtResc, " PendingStruct.pushElemProc: has_dma %d\n", pElem->has_dma);
    if (pElem->has_dma) {
        rnic->qpcModule.loadMem(qpcReq);
    }

    /* If there are elem in fifo, schedule myself again */
    if (pushFifo.size()) {
        if (!pushElemProcEvent.scheduled()) {
            rnic->schedule(pushElemProcEvent, curTick() + rnic->clockPeriod());
        }
    }
    HANGU_PRINT(CxtResc, " PendingStruct.pushElemProc: out!\n");
}

bool 
HanGuRnic::PendingStruct::push_elem(PendingElemPtr pElem) {
    pushFifo.push(pElem);
    if (!pushElemProcEvent.scheduled()) {
        rnic->schedule(pushElemProcEvent, curTick() + rnic->clockPeriod());
    }
    return true;
}

// return first elem in the fifo, the elem is not removed
PendingElemPtr 
HanGuRnic::PendingStruct::front_elem() {
    assert(pendingFifo[onlineIdx].size());
    /* read first pElem from pendingFifo */
    return pendingFifo[onlineIdx].front();
}

/* return first elem in the fifo, the elem is removed.
 * Note that if onlinePending is empty && offlinePending 
 * has elem, swap onlineIdx && offlineIdx */
PendingElemPtr 
HanGuRnic::PendingStruct::pop_elem() {
    
    assert(pendingFifo[onlineIdx].size() > 0);
    PendingElemPtr pElem = pendingFifo[onlineIdx].front();
    pendingFifo[onlineIdx].pop();
    --elemNum;

    /* if onlinePend empty, and offlinePend has elem, swap onlineIdx and offlineIdx */
    if (pendingFifo[onlineIdx].empty() && pendingFifo[offlineIdx].size()) {
        /* swap onlineIdx and offlineIdx */
        swapIdx();
    }

    HANGU_PRINT(CxtResc, " PendingStruct.pop_elem: exit, get_size() %d elemNum %d\n", get_size(), elemNum);
    
    return pElem;
}

/* read && pop one elem from offlinePending (to check the element) */
PendingElemPtr 
HanGuRnic::PendingStruct::get_elem_check() {

    assert(pendingFifo[offlineIdx].size() || pendingFifo[onlineIdx].size());
    
    if (pendingFifo[offlineIdx].empty()) {
        /* swap onlineIdx and offlineIdx */
        swapIdx();
    }
    PendingElemPtr pElem = pendingFifo[offlineIdx].front();
    pendingFifo[offlineIdx].pop();
    --elemNum;

    HANGU_PRINT(CxtResc, " QpcModule.PendingStruct.get_elem_check: exit\n");
    return pElem;
}

/* and push to the online pendingFifo */
void 
HanGuRnic::PendingStruct::ignore_elem_check(PendingElemPtr pElem) {
    pendingFifo[onlineIdx].push(pElem);
    ++elemNum;

    HANGU_PRINT(CxtResc, " QpcModule.PendingStruct.ignore_elem_check: exit\n");
}

/* if it is the first, swap online and offline pendingFifo */
void 
HanGuRnic::PendingStruct::succ_elem_check() {
    if (pendingFifo[onlineIdx].size() == 0) {
        /* swap onlineIdx and offlineIdx */
        swapIdx();
    }
    HANGU_PRINT(CxtResc, " QpcModule.PendingStruct.succ_elem_check: get_size %d, elemNum %d\n", 
            get_size(), elemNum);
}

/* call push_elem */
void 
HanGuRnic::PendingStruct::push_elem_check(PendingElemPtr pElem) {
    if (pendingFifo[onlineIdx].size() == 0) {
        /* swap onlineIdx and offlineIdx */
        swapIdx();
    }
    push_elem(pElem);
    HANGU_PRINT(CxtResc, " QpcModule.PendingStruct.push_elem_check: exit\n");
}
///////////////////////////// HanGuRnic::PendingStruct {end}//////////////////////////////
