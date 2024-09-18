
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

///////////////////////////// HanGuRnic::DMA Engine {begin}//////////////////////////////
void 
HanGuRnic::DmaEngine::dmaWriteCplProcessing() {

    HANGU_PRINT(DmaEngine, " DMAEngine.dmaWriteCplProcessing! size %d\n", 
            dmaWrReq2RspFifo.front()->size);
    
    /* Pop related write request */
    DmaReqPtr dmaReq = dmaWrReq2RspFifo.front();
    dmaWrReq2RspFifo.pop();

    /* Schedule myself if there's item in fifo */
    if (dmaWrReq2RspFifo.size()) {
        rnic->schedule(dmaWriteCplEvent, dmaWrReq2RspFifo.front()->schd);
    }
}


void 
HanGuRnic::DmaEngine::dmaWriteProcessing () {

    uint8_t CHNL_NUM = 3;
    bool isEmpty[CHNL_NUM];
    isEmpty[0] = rnic->cacheDmaAccessFifo.empty();
    isEmpty[1] = rnic->dataDmaWriteFifo.empty() ;
    isEmpty[2] = rnic->cqDmaWriteFifo.empty()   ;

    if (rnic->cacheDmaAccessFifo.size() && rnic->cacheDmaAccessFifo.front()->reqType == 0) { /* read request */
        /* shchedule dma read processing if this is a read request */
        if (!dmaReadEvent.scheduled()) {
            rnic->schedule(dmaReadEvent, curTick() + rnic->clockPeriod());
        }

        isEmpty[0] = true; /* Write Request. This also means empty */
    }

    if (isEmpty[0] & isEmpty[1] & isEmpty[2]) {
        return;
    }

    HANGU_PRINT(DmaEngine, " DMAEngine.dmaWrite! size0 %d, size1 %d, size2 %d\n", 
            rnic->cacheDmaAccessFifo.size(), rnic->dataDmaWriteFifo.size(), rnic->cqDmaWriteFifo.size());

    uint8_t cnt = 0;
    while (cnt < CHNL_NUM) {
        if (isEmpty[writeIdx] == false) {
            DmaReqPtr dmaReq;
            switch (writeIdx) {
              case 0 :
                dmaReq = rnic->cacheDmaAccessFifo.front();
                rnic->cacheDmaAccessFifo.pop();
                HANGU_PRINT(DmaEngine, " DMAEngine.dmaWrite: Is cacheDmaAccessFifo! addr 0x%lx\n", (uint64_t)(dmaReq->data));
                break;
              case 1 :
                dmaReq = rnic->dataDmaWriteFifo.front();
                rnic->dataDmaWriteFifo.pop();
                HANGU_PRINT(DmaEngine, " DMAEngine.dmaWrite: Is dataDmaWriteFifo!\n");
                break;
              case 2 :
                dmaReq = rnic->cqDmaWriteFifo.front();
                rnic->cqDmaWriteFifo.pop();
                
                HANGU_PRINT(DmaEngine, " DMAEngine.dmaWrite: Is cqDmaWriteFifo!\n");
                
                break;
            }
            
            // unit: ps
            Tick bwDelay = (dmaReq->size + 32) * rnic->pciBandwidth;
            Tick delay = rnic->dmaWriteDelay + bwDelay;
            
            HANGU_PRINT(DmaEngine, " DMAEngine.dmaWrite: dmaReq->addr 0x%x, dmaReq->size %d, delay %d, bwDelay %d!\n", 
            dmaReq->addr, dmaReq->size, delay, bwDelay);
            assert(dmaReq->size != 0);

            /* Send dma req to dma channel
             * this event is used to call rnic->dmaWrite() */
            dmaWReqFifo.push(dmaReq);
            if (!dmaChnlProcEvent.scheduled()) {
                rnic->schedule(dmaChnlProcEvent, curTick() + rnic->clockPeriod());
            }
            
            /* Schedule DMA Write completion event */
            dmaReq->schd = curTick() + delay;
            dmaWrReq2RspFifo.push(dmaReq);
            if (!dmaWriteCplEvent.scheduled()) {
                rnic->schedule(dmaWriteCplEvent, dmaReq->schd);
            }
            
            /* Point to next chnl */
            ++writeIdx;
            writeIdx = writeIdx % CHNL_NUM;
            
            // bwDelay = (bwDelay > rnic->clockPeriod()) ? bwDelay : rnic->clockPeriod();
            if (dmaWriteEvent.scheduled()) {
                rnic->reschedule(dmaWriteEvent, curTick() + bwDelay);
            } else { // still schedule incase in time interval
                     // [curTick(), curTick() + rnic->dmaWriteDelay + bwDelay] , 
                     // one or more channel(s) schedule dmaWriteEvent
                rnic->schedule(dmaWriteEvent, curTick() + bwDelay);
            }
            HANGU_PRINT(DmaEngine, " DMAEngine.dmaWrite: out!\n");
            return;
        } else {
            ++cnt;
            ++writeIdx;
            writeIdx = writeIdx % CHNL_NUM;
        }
    }
}


void 
HanGuRnic::DmaEngine::dmaReadCplProcessing() {

    // HANGU_PRINT(DmaEngine, " DMAEngine.dmaReadCplProcessing! cplSize %d\n", 
    //         dmaRdReq2RspFifo.front()->size);

    /* post related cpl pkt to related fifo */
    DmaReqPtr dmaReq = dmaRdReq2RspFifo.front();
    dmaRdReq2RspFifo.pop();
    dmaReq->rdVld = 1;
    Event *e = &rnic->qpcModule.qpcRspProcEvent;
    if (dmaReq->event == e) { /* qpc dma read cpl pkt */
        assert(dmaReq->size == 256);
        rnic->qpcDmaRdCplFifo.push(dmaReq);
    }

    /* Schedule related completion event */
    if (!(dmaReq->event)->scheduled()) {
        rnic->schedule(*(dmaReq->event), curTick() + rnic->clockPeriod());
    }

    /* Schedule myself if there's item in fifo */
    if (dmaRdReq2RspFifo.size()) {
        rnic->schedule(dmaReadCplEvent, dmaRdReq2RspFifo.front()->schd);
    }

    // HANGU_PRINT(DmaEngine, " DMAEngine.dmaReadCplProcessing: out!\n");
}

void 
HanGuRnic::DmaEngine::dmaReadProcessing () {

    HANGU_PRINT(DmaEngine, " DMAEngine.dmaRead! \n");
    
    uint8_t CHNL_NUM = 4;
    bool isEmpty[CHNL_NUM];
    isEmpty[0] = rnic->cacheDmaAccessFifo.empty();
    isEmpty[1] = rnic->descDmaReadFifo.empty() ;
    isEmpty[2] = rnic->dataDmaReadFifo.empty() ;
    isEmpty[3] = rnic->ccuDmaReadFifo.empty()  ;

    /* If there has write request, schedule dma Write Proc */
    if (rnic->cacheDmaAccessFifo.size() && rnic->cacheDmaAccessFifo.front()->reqType == 1) { /* write request */
        /* shchedule dma write processing if this is a write request */
        if (!dmaWriteEvent.scheduled()) {
            rnic->schedule(dmaWriteEvent, curTick() + rnic->clockPeriod());
        }

        isEmpty[0] = true; /* Write Request. This also means empty */
    }
    
    if (isEmpty[0] & isEmpty[1] & isEmpty[2] & isEmpty[3]) {
        return;
    }

    HANGU_PRINT(DmaEngine, " DMAEngine.dmaRead: in! \n");

    uint8_t cnt = 0;
    while (cnt < CHNL_NUM) {
        if (isEmpty[readIdx] == false) {
            DmaReqPtr dmaReq;
            switch (readIdx) {
              case 0 :
                dmaReq = rnic->cacheDmaAccessFifo.front();
                rnic->cacheDmaAccessFifo.pop();
                HANGU_PRINT(DmaEngine, " DMAEngine.dmaRead: Is cacheDmaAccessFifo!\n");
                break;
              case 1 :
                dmaReq = rnic->descDmaReadFifo.front();
                rnic->descDmaReadFifo.pop();
                HANGU_PRINT(DmaEngine, " DMAEngine.dmaRead: Is descDmaReadFifo! FIFO depth: %d\n", rnic->descDmaReadFifo.size());
                break;
              case 2 :
                dmaReq = rnic->dataDmaReadFifo.front();
                rnic->dataDmaReadFifo.pop();
                HANGU_PRINT(DmaEngine, " DMAEngine.dmaRead: Is dataDmaReadFifo! FIFO depth: %d\n", rnic->dataDmaReadFifo.size());
                break;
              case 3 :
                dmaReq = rnic->ccuDmaReadFifo.front();
                rnic->ccuDmaReadFifo.pop();
                HANGU_PRINT(DmaEngine, " DMAEngine.dmaRead: Is ccuDmaReadFifo!\n");
                break;
            }
            
            // unit: ps
            Tick bwDelay = (dmaReq->size + 32) * rnic->pciBandwidth;
            Tick delay = rnic->dmaReadDelay + bwDelay;
            
            HANGU_PRINT(DmaEngine, " DMAEngine.dmaRead: dmaReq->addr 0x%x, dmaReq->size %d, delay %d, bwDelay %d!\n", 
            dmaReq->addr, dmaReq->size, delay, bwDelay);
            assert(dmaReq->size != 0);

            /* Send dma req to dma channel, 
             * this event is used to call rnic->dmaRead() */
            dmaRReqFifo.push(dmaReq);
            if (!dmaChnlProcEvent.scheduled()) {
                rnic->schedule(dmaChnlProcEvent, curTick() + rnic->clockPeriod());
            }
            
            /* Schedule DMA read completion event */
            dmaReq->schd = curTick() + delay;
            dmaRdReq2RspFifo.push(dmaReq);
            if (!dmaReadCplEvent.scheduled()) {
                rnic->schedule(dmaReadCplEvent, dmaReq->schd);
            }

            /* Point to next chnl */
            ++readIdx;
            readIdx = readIdx % CHNL_NUM;

            /* Reschedule the dma read event. delay is (byte count * bandwidth) */
            if (dmaReadEvent.scheduled()) {
                rnic->reschedule(dmaReadEvent, curTick() + bwDelay);
            } else { // still schedule incase in time interval
                     // [curTick(), curTick() + rnic->dmaReadDelay * dmaReq->size] , 
                     // one or more channel(s) schedule dmaReadEvent
                rnic->schedule(dmaReadEvent, curTick() + bwDelay);
            }
            
            HANGU_PRINT(DmaEngine, " DMAEngine.dmaRead: out! \n");
            return;
        } else {
            ++cnt;
            ++readIdx;
            readIdx = readIdx % CHNL_NUM;
        }
    }
}

void 
HanGuRnic::DmaEngine::dmaChnlProc () {
    if (dmaWReqFifo.empty() && dmaRReqFifo.empty()) {
        return ;
    }

    /* dma write has the higher priority, cause it is the duty of 
     * app logic to handle the write-after-read error. DMA channel 
     * only needs to avoid read-after-write error (when accessing 
     * the same address) */
    DmaReqPtr dmaReq;
    if (dmaWReqFifo.size()) { 
        
        dmaReq = dmaWReqFifo.front();
        dmaWReqFifo.pop();
        rnic->dmaWrite(dmaReq->addr, dmaReq->size, nullptr, dmaReq->data);
    } else if (dmaRReqFifo.size()) {

        dmaReq = dmaRReqFifo.front();
        dmaRReqFifo.pop();
        rnic->dmaRead(dmaReq->addr, dmaReq->size, nullptr, dmaReq->data);
    }
    
    /* schedule myself to post the dma req to the channel */
    if (dmaWReqFifo.size() || dmaRReqFifo.size()) {
        if (!dmaChnlProcEvent.scheduled()) {
            rnic->schedule(dmaChnlProcEvent, curTick() + rnic->clockPeriod());
        }
    }
}
///////////////////////////// HanGuRnic::DMA Engine {end}//////////////////////////////
