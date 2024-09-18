
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

///////////////////////////// HanGuRnic::CqcModule {begin}//////////////////////////////
bool 
HanGuRnic::CqcModule::postCqcReq(CxtReqRspPtr cqcReq) {

    assert(cqcReq->type == CXT_RREQ_CQ);

    if (cqcReq->chnl == CXT_CHNL_TX) {
        rnic->txCqcReqFifo.push(cqcReq);
    } else if (cqcReq->chnl == CXT_CHNL_RX) {
        rnic->rxCqcReqFifo.push(cqcReq);
    } else {
        panic("[CqcModule]: cqcReq->chnl error! %d", cqcReq->chnl);
    }

    if (!cqcReqProcEvent.scheduled()) { /* Schedule cqcReqProc() */
        rnic->schedule(cqcReqProcEvent, curTick() + rnic->clockPeriod());
    }

    return true;
}

void 
HanGuRnic::CqcModule::cqcRspProc() {

    HANGU_PRINT(CxtResc, " CqcModule.cqcRspProc!\n");

    assert(cqcCache.rrspFifo.size());
    CxtReqRspPtr cqcRsp = cqcCache.rrspFifo.front().second;
    cqcCache.rrspFifo.pop();
    uint8_t type = cqcRsp->type, chnl = cqcRsp->chnl;
    Event *e;

    /* Get event and push cqcRsp to relevant Fifo */
    if (type == CXT_RREQ_CQ && chnl == CXT_CHNL_TX) {
        cqcRsp->type = CXT_RRSP_CQ;
        e = &rnic->rdmaEngine.scuEvent;

        rnic->txCqcRspFifo.push(cqcRsp);
    } else if (type == CXT_RREQ_CQ && chnl == CXT_CHNL_RX) {
        cqcRsp->type = CXT_RRSP_CQ;
        e = &rnic->rdmaEngine.rcuEvent;

        rnic->rxCqcRspFifo.push(cqcRsp);
    } else {
        panic("[CqcModule]: cxtReq type error! type: %d, chnl %d", type, chnl);
    }
    
    /* schedule related module to retruen read rsp cqc */
    if (!e->scheduled()) {
        rnic->schedule(*e, curTick() + rnic->clockPeriod());
    }

    /* If there's still has elem to be 
     * processed, reschedule myself */
    if (cqcCache.rrspFifo.size()) {
        if (!cqcRspProcEvent.scheduled()) {/* Schedule myself */
            rnic->schedule(cqcRspProcEvent, curTick() + rnic->clockPeriod());
        }
    }

    HANGU_PRINT(CxtResc, " CqcModule.cqcRspProc: out!\n");
}

/* cqc update function used in lambda expression */
bool cqcReadUpdate(CqcResc &resc) {

    resc.offset += sizeof(CqDesc);

    if (resc.offset + sizeof(CqDesc) > (1 << resc.sizeLog)) {
        resc.offset = 0;
    }
    return true;
}

void
HanGuRnic::CqcModule::cqcReqProc() {

    HANGU_PRINT(CxtResc, " CqcModule.cqcReqProc!\n");

    uint8_t CHNL_NUM = 2;
    bool isEmpty[CHNL_NUM];
    isEmpty[0] = rnic->txCqcReqFifo.empty();
    isEmpty[1] = rnic->rxCqcReqFifo.empty();

    CxtReqRspPtr cqcReq;
    for (uint8_t cnt = 0; cnt < CHNL_NUM; ++cnt) {
        if (isEmpty[chnlIdx] == false) {
            switch (chnlIdx) {
              case 0:
                cqcReq = rnic->txCqcReqFifo.front();
                rnic->txCqcReqFifo.pop();
                assert(cqcReq->chnl == CXT_CHNL_TX);

                HANGU_PRINT(CxtResc, " CqcModule.cqcReqProc: tx CQC read req posted!\n");
                break;
              case 1:
                cqcReq = rnic->rxCqcReqFifo.front();
                rnic->rxCqcReqFifo.pop();
                assert(cqcReq->chnl == CXT_CHNL_RX);

                HANGU_PRINT(CxtResc, " CqcModule.cqcReqProc: rx CQC read req posted!\n");
                break;
            }

            assert(cqcReq->type == CXT_RREQ_CQ);

            /* Read CQC from CQC Cache */
            cqcCache.rescRead(cqcReq->num, &cqcRspProcEvent, cqcReq, cqcReq->txCqcRsp, [](CqcResc &resc) -> bool { return cqcReadUpdate(resc); });

            /* Point to next chnl */
            ++chnlIdx;
            chnlIdx = chnlIdx % CHNL_NUM;

            /* Schedule myself again if there still has elem in fifo */
            if (rnic->txCqcReqFifo.size() || rnic->rxCqcReqFifo.size()) {
                if (!cqcReqProcEvent.scheduled()) { /* schedule myself */
                    rnic->schedule(cqcReqProcEvent, curTick() + rnic->clockPeriod());
                }
            }
            
            HANGU_PRINT(CxtResc, " CqcModule.cqcReqProc: out!\n");

            return;
        } else {
            /* Point to next chnl */
            ++chnlIdx;
            chnlIdx = chnlIdx % CHNL_NUM;
        }
    }
}
///////////////////////////// HanGuRnic::CqcModule {end}//////////////////////////////
