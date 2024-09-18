
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

///////////////////////////// HanGuRnic::RDMA Engine relevant {begin}//////////////////////////////

uint32_t
HanGuRnic::RdmaEngine::txDescLenSel (uint8_t num) {
    return (uint32_t)num;
}

/**
 * @brief Descriptor fetching Unit
 * Post descriptor read request and recv relatived QPC information
 * Pass useful information to DDU.
 */
void
HanGuRnic::RdmaEngine::dfuProcessing () {

    HANGU_PRINT(RdmaEngine, " RdmaEngine.dfuProcessing!\n");

    /* read qpc sq addr */
    assert(rnic->qpcModule.txQpAddrRspFifo.size());
    CxtReqRspPtr qpcRsp = rnic->qpcModule.txQpAddrRspFifo.front();
    uint8_t idx = qpcRsp->idx;
    rnic->qpcModule.txQpAddrRspFifo.pop();

    HANGU_PRINT(RdmaEngine, " RdmaEngine.dfuProcessing: idx %d\n", idx);

    /* Get doorbell rrelated to the qpc
     * If the index fifo is empty, reschedule ccu.dfu event */
    assert(rnic->doorbellVector[idx] != nullptr);
    DoorbellPtr dbell = rnic->doorbellVector[idx];
    rnic->doorbellVector[idx] = nullptr;
    rnic->df2ccuIdxFifo.push(idx);
    if ((rnic->df2ccuIdxFifo.size() == 1) && rnic->pio2ccuDbFifo.size()) { 
        if (!rnic->doorbellProcEvent.scheduled()) {
            rnic->schedule(rnic->doorbellProcEvent, curTick() + rnic->clockPeriod());
        }
    }

    /* Post doorbell to DDU */
    // df2ddFifo.push(dbell);

    assert(qpcRsp->txQpcRsp->srcQpn == dbell->qpn);
    HANGU_PRINT(RdmaEngine, " RdmaEngine.dfuProcessing:"
            " Post descriptor to MR Module! sndBaselkey: %d, qpn %d, num %d, opcode %d, dbell->offset %d\n", 
            qpcRsp->txQpcRsp->sndWqeBaseLkey, dbell->qpn, dbell->num, dbell->opcode, dbell->offset);

    /* Post Descriptor read request to MR Module */
    MrReqRspPtr descReq = make_shared<MrReqRsp>(DMA_TYPE_RREQ, MR_RCHNL_TX_DESC,
            qpcRsp->txQpcRsp->sndWqeBaseLkey, 
            txDescLenSel(dbell->num) << 5, dbell->offset);
    descReq->txDescRsp = new TxDesc[dbell->num];
    rnic->descReqFifo.push(descReq);
    if (!rnic->mrRescModule.transReqEvent.scheduled()) { /* Schedule MrRescModule.transReqProcessing */
        rnic->schedule(rnic->mrRescModule.transReqEvent, curTick() + rnic->clockPeriod());
    }
    
    /* If doorbell fifo & addr fifo has event, schedule myself again. */
    if (rnic->qpcModule.txQpAddrRspFifo.size()) {
        if (!dfuEvent.scheduled()) { /* Schedule DfuProcessing */
            rnic->schedule(dfuEvent, curTick() + rnic->clockPeriod());
        }
    }

    HANGU_PRINT(RdmaEngine, " RdmaEngine.dfuProcessing: out!\n");
}

/**
 * @note Called by dduEvent, I am scheduled by MrRescModule.dmaRrspProcessing
 *       and myself.
 *       
 *       This function is used to read QPC from CxtRescModule. We request the 
 *       QPC even if last cycle we request the same QPC (though this QPC is 
 *       decayed). We did this beacuse we hope Context Module knows the QPC 
 *       requirement. Later in rgu, we just abandon the fetched QPC, and 
 *       replace it with QPC stored in rgu.
 *       
 */
void
HanGuRnic::RdmaEngine::dduProcessing () {
    
    // HANGU_PRINT(RdmaEngine, " RdmaEngine.dduProcessing!\n");

    // make sure that on fly data request number does not exceed DATA_REQ_LIMIT
    if ((std::count(dd2dpVector.begin(), dd2dpVector.end(), nullptr) > dd2dpVector.size() - DATA_REQ_LIMIT) || 1)
    {
        /* If there's no valid idx, exit the schedule */
        if (dp2ddIdxFifo.size() == 0) {
            HANGU_PRINT(HanGuRnic, " RdmaEngine.dduProcessing: If there's no valid idx, exit the schedule\n");
            return;
        }

        if (this->allowNewDb) {
            /* Fetch Doorbell from DFU fifo */
            assert(df2ddFifo.size());
            assert(this->dduDbell == nullptr);
            this->dduDbell = df2ddFifo.front();
            df2ddFifo.pop();
            this->allowNewDb = false;
            HANGU_PRINT(RdmaEngine, " RdmaEngine.dduProcessing: Get one Doorbell!\n");
        }
        else 
        {
            HANGU_PRINT(RdmaEngine, " Not allow new DB!\n");
        }

        /* Fetch one descriptor from tx descriptor fifo */
        // assert(rnic->txdescRspFifo.size()); /* TPT calls this function, so 
        //                                      * txDescFifo should have items */
        // TxDescPtr txDesc = rnic->txdescRspFifo.front();
        // rnic->txdescRspFifo.pop();
        assert(rnic->txDescLaunchQue.size());
        TxDescPtr txDesc = rnic->txDescLaunchQue.front();
        rnic->txDescLaunchQue.pop();

        /* Put one descriptor to waiting Memory */
        HANGU_PRINT(RdmaEngine, " RdmaEngine.dduProcessing: desc->len 0x%x, desc->lkey 0x%x, desc->lvaddr 0x%x, desc->opcode 0x%x, desc->flags 0x%x, dduDbell->qpn 0x%x, dduDbell->num: %d\n", 
                txDesc->len, txDesc->lkey, txDesc->lVaddr, txDesc->opcode, txDesc->flags, dduDbell->qpn, dduDbell->num);
        HANGU_PRINT(RdmaEngine, "WQE left in queue: %d\n", rnic->txDescLaunchQue.size());
        uint8_t idx = dp2ddIdxFifo.front();
        dp2ddIdxFifo.pop();
        assert(dd2dpVector[idx] == nullptr);
        dd2dpVector[idx] = txDesc;
        /* We don't schedule it here, cause it should be 
        * scheduled by Context Module */
        // if (!dpuEvent.scheduled()) { /* Schedule RdmaEngine.dpuProcessing */
        //     rnic->schedule(dpuEvent, curTick() + rnic->clockPeriod());
        // }

        /* Post qp read request to QpcModule */
        CxtReqRspPtr qpcRdReq = make_shared<CxtReqRsp>(CXT_RREQ_QP, CXT_CHNL_TX, dduDbell->qpn, 1, idx); /* dduDbell->num */
        qpcRdReq->txQpcRsp = new QpcResc;
        rnic->qpcModule.postQpcReq(qpcRdReq);

        /* update allowNewDb */
        --this->dduDbell->num;
        if (this->dduDbell->num == 0) 
        {
            this->allowNewDb = true;
            this->dduDbell = nullptr;
        }
    }
    else
    {
        HANGU_PRINT(RdmaEngine, " RdmaEngine.dduProcessing: on fly data request number exceeds DATA_REQ_LIMIT: %d\n", 
            std::count(dd2dpVector.begin(), dd2dpVector.end(), nullptr));
    }

    /* Schedule myself again if there's new descriptor
     * or there remains descriptors to post */
    if (dp2ddIdxFifo.size() && rnic->txDescLaunchQue.size() && 
            ((allowNewDb && df2ddFifo.size()) || (!allowNewDb))) 
    {
        if (!dduEvent.scheduled()) { /* Schedule myself */
            rnic->schedule(dduEvent, curTick() + rnic->clockPeriod());
        }
    }
    else {
        HANGU_PRINT(RdmaEngine, "dp2ddIdxFifo.size: %d, rnic->txDescLaunchQue.size: %d, allowNewDb: %B, df2ddFifo.size: %d\n", 
            dp2ddIdxFifo.size(), rnic->txDescLaunchQue.size(), allowNewDb, df2ddFifo.size());
    }

    // HANGU_PRINT(RdmaEngine, " RdmaEngine.dduProcessing: out!\n");
}

uint32_t
HanGuRnic::RdmaEngine::getRdmaHeadSize (uint8_t opcode, uint8_t qpType) {
    switch(opcode) {
      case OPCODE_SEND :
        switch (qpType) {
          case QP_TYPE_RC:
            return PKT_BTH_SZ;
          case QP_TYPE_UD:
            return PKT_BTH_SZ + PKT_DETH_SZ;
          default:
            panic("QP type error!");
            return 0;
        }
      case OPCODE_RDMA_WRITE:
      case OPCODE_RDMA_READ:
        assert(qpType == QP_TYPE_RC);
        return PKT_BTH_SZ + PKT_RETH_SZ;
      default:
        panic("Error! Post wrong descriptor type to send queue. (in getRdmaHeadSize) opcode %d\n", opcode);
        return 0;
    }
}

/**
 * @note Called by dpuEvent, it's scheduled by CxtRescModule.cxtRspProcessing 
 *       and myself. 
 *       QPC in qpcModule.txQpcRspFifo may be decayed. We just put it to rgu, and 
 *       rgu may replace it with its own newer QPC.
 */
void
HanGuRnic::RdmaEngine::dpuProcessing () {

    HANGU_PRINT(RdmaEngine, " RdmaEngine.dpuProcessing!\n");

    if (dp2rgFifo.size() < DATA_REQ_LIMIT || 1)
    {
        /* Get Context from Context Module */
        assert(rnic->qpcModule.txQpcRspFifo.size());
        CxtReqRspPtr dpuQpc = rnic->qpcModule.txQpcRspFifo.front();
        rnic->qpcModule.txQpcRspFifo.pop();
        assert((dpuQpc->txQpcRsp->qpType == QP_TYPE_RC) ||
                (dpuQpc->txQpcRsp->qpType == QP_TYPE_UD)); /* we should only use RC and UD type QP */

        /* Get one descriptor entry from RdmaEngine.dduProcessing */
        HANGU_PRINT(RdmaEngine, " RdmaEngine.dpuProcessing: num 0x%x, idx %d\n", dpuQpc->num, dpuQpc->idx);
        uint8_t idx = dpuQpc->idx;
        assert(dd2dpVector[idx] != nullptr);
        TxDescPtr desc = dd2dpVector[idx];
        dd2dpVector[idx] = nullptr;
        assert(desc->len <= 16384); // TO DO: the final step is to remove this
        HANGU_PRINT(RdmaEngine, " RdmaEngine.dpuProcessing:"
                    " Get descriptor entry from RdmaEngine.dduProcessing, len: %d, lkey: %d, opcode: %d, rkey: %d\n", 
                    desc->len, desc->lkey, desc->opcode, desc->rdmaType.rkey);

        /* schedule ddu if dp2ddIdxFifo is capable */
        dp2ddIdxFifo.push(idx);
        // bug fix: 20240301
        if ((dp2ddIdxFifo.size() == 1) && 
            //  rnic->txdescRspFifo.size() && 
             ((allowNewDb && df2ddFifo.size()) || (!allowNewDb))) {
            if (!dduEvent.scheduled()) {
                rnic->schedule(dduEvent, curTick() + rnic->clockPeriod());
            }
        }

        /* Generate request packet (RDMA read/write, send) */
        EthPacketPtr txPkt = std::make_shared<EthPacketData>(16384); // TODO: modify size here
        txPkt->length = ETH_ADDR_LEN * 2 + getRdmaHeadSize(desc->opcode, dpuQpc->txQpcRsp->qpType); /* ETH_ADDR_LEN * 2 means length of 2 MAC addr */

        /* Post Descriptor & QPC & request packet pointer to RdmaEngine.rguProcessing */
        DP2RGPtr dp2rg = make_shared<DP2RG>();
        dp2rg->desc = desc;
        dp2rg->qpc  = dpuQpc->txQpcRsp;
        dp2rg->txPkt= txPkt;
        dp2rgFifo.push(dp2rg);
        HANGU_PRINT(RdmaEngine, " RdmaEngine.dpuProcessing: Post Desc & QPC to RdmaEngine.rguProcessing qpn: 0x%x. sndPsn %d qpType %d dpuQpc->sz %d, dp2rgFifo size: %d\n", 
                dp2rg->qpc->srcQpn, dp2rg->qpc->sndPsn, dp2rg->qpc->qpType, dpuQpc->sz, dp2rgFifo.size());

        /* Post Data read request to Memory Region Module (TPT) */
        MrReqRspPtr rreq;
        switch(desc->opcode) {
        case OPCODE_SEND :
        case OPCODE_RDMA_WRITE:
            /* Post Data read request to Data Read Request FIFO.
            * Fetch data from host memory */
            // HANGU_PRINT(RdmaEngine, " RdmaEngine.dpuProcessing: Push Data read request to MrRescModule.transReqProcessing: len %d vaddr 0x%x\n", desc->len, desc->lVaddr);
            rreq = make_shared<MrReqRsp>(DMA_TYPE_RREQ, MR_RCHNL_TX_DATA,
                    desc->lkey, desc->len, (uint32_t)(desc->lVaddr&0xFFF));
            rreq->rdDataRsp = txPkt->data + txPkt->length; /* Address Rsp data (from host memory) should be located */
            rnic->dataReqFifo.push(rreq);
            if (!rnic->mrRescModule.transReqEvent.scheduled()) {
                rnic->schedule(rnic->mrRescModule.transReqEvent, curTick() + rnic->clockPeriod());
            }

            break;
        case OPCODE_RDMA_READ:
            /* Schedule rg&rru to start Processing RDMA read. 
            * Cause RDMA read don't need to read data from host memory */
            if (!rgrrEvent.scheduled()) { /* Schedule RdmaEngine.rgrrProcessing */
                rnic->schedule(rgrrEvent, curTick() + rnic->clockPeriod());
            }
            break;
        default:
            panic("Error! Post wrong descriptor type to send queue. desc->opcode %d\n", desc->opcode);
            break;
        }
    }
    else
    {
        HANGU_PRINT(RdmaEngine, " RdmaEngine.dpuProcessing: dp2rgFifo size exceeds: %d\n", dp2rgFifo.size());
    }

    /* Recall myself if there's new descriptor and QPC */
    if (rnic->qpcModule.txQpcRspFifo.size()) {
        if (!dpuEvent.scheduled()) { /* Schedule myself */
            rnic->schedule(dpuEvent, curTick() + rnic->clockPeriod());
        }
    }
    
    HANGU_PRINT(RdmaEngine, " RdmaEngine.dpuProcessing: out!\n");
}

/**
 * @note 
 *      Resend from first elem of the window.
 *      We didn't implement retransmission mechanism yet.
 *      We assume no packet lost now. 
 */
void
HanGuRnic::RdmaEngine::reTransPkt(WinMapElem *winElem, uint32_t pktCnt) {
    return;
}


void
HanGuRnic::RdmaEngine::rdmaReadRsp(EthPacketPtr rxPkt, WindowElemPtr winElem) {

    HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rdmaReadRsp\n");

    // Post Data Wrte request to fifo
    MrReqRspPtr dataWreq = make_shared<MrReqRsp>(
                DMA_TYPE_WREQ, TPT_WCHNL_TX_DATA,
                winElem->txDesc->lkey, 
                winElem->txDesc->len, 
                (uint32_t)(winElem->txDesc->lVaddr & 0xFFF));
    dataWreq->wrDataReq = new uint8_t[dataWreq->length]; /* copy data, because the packet will be deleted soon */
    memcpy(dataWreq->wrDataReq, rxPkt->data + ETH_ADDR_LEN * 2 + PKT_BTH_SZ + PKT_AETH_SZ, dataWreq->length);
    rnic->dataReqFifo.push(dataWreq);

    HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.RRU.rdmaReadRsp: RDMA read Data is: %s\n", dataWreq->wrDataReq);

    // Schedule TPT to start Post completion.
    if (!rnic->mrRescModule.transReqEvent.scheduled()) {
        rnic->schedule(rnic->mrRescModule.transReqEvent, curTick() + rnic->clockPeriod());
    }
}

void
HanGuRnic::RdmaEngine::postTxCpl(uint8_t qpType, uint32_t qpn, 
        uint32_t cqn, TxDescPtr desc) {
    
    HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.postTxCpl! qpn %d, cqn %d \n", qpn, cqn);

    /* signaled to CQ based on the info from wqe */
    if (!desc->isSignaled()) {
        HANGU_PRINT(RdmaEngine, "Do not post completion! QPN: %d, desc flag: 0x%lx\n", qpn, desc->flags);
        return;
    }
    else
    {
        HANGU_PRINT(RdmaEngine, "Post completioin! QPN: %d, desc flag: 0x%lx\n", qpn, desc->flags);
    }
    
    /* Post related info into scu Fifo */
    CqDescPtr cqDesc = make_shared<CqDesc>(qpType, 
            desc->opcode, desc->len, qpn, cqn);
    rg2scFifo.push(cqDesc);

    /* Post Cqc req to CqcModule */
    CxtReqRspPtr cqcRdReq = make_shared<CxtReqRsp>(CXT_RREQ_CQ, CXT_CHNL_TX, cqn);
    cqcRdReq->txCqcRsp = new CqcResc;
    rnic->cqcModule.postCqcReq(cqcRdReq);

    HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.postTxCpl: out!\n");
}

/**
 * @note
 *      Response Receiving Unit Processing.
 *      This function is called by rgrrProcessing.
 *      Note that retransmission mechanism is not fully implemented. 
 *      At present, we only provide NACK perception. 
 */
void
HanGuRnic::RdmaEngine::rruProcessing () {

    HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rruProcessing!\n");

    /* Get RX ack data from fifo */
    assert(ra2rgFifo.size());
    EthPacketPtr rxPkt = ra2rgFifo.front();
    BTH *bth   = (BTH *)(rxPkt->data + ETH_ADDR_LEN * 2);
    AETH *aeth = (AETH *)(rxPkt->data + ETH_ADDR_LEN * 2 + PKT_BTH_SZ);
    uint32_t destQpn = bth->op_destQpn & 0xFFFFFF;
    uint32_t ackPsn  = bth->needAck_psn & 0xFFFFFF;
    ra2rgFifo.pop();
    onFlyPacketNum--;
    HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rruProcessing:"
            " Get RX ack data from fifo destQpn 0x%x, ackPsn %d, on-fly count: %d\n", 
            destQpn, ackPsn, onFlyPacketNum);
    assert(onFlyPacketNum >= 0);

    if (rnic->descScheduler.qpStatusTable[destQpn]->type == LAT_QP)
    {
        HANGU_PRINT(RdmaEngine, "receive ack, qpn: 0x%x, curtick: %ld\n", destQpn, curTick());
    }

    /* Get ACK bounded QP List from Window */
    WinMapElem* winElem;
    if (sndWindowList.find(destQpn) == sndWindowList.end()) {
        for (auto &item : sndWindowList) {
            uint32_t key = item.first;
            WinMapElem* val = item.second;
            HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rruProcessing: qpn: %d, key %d firstPsn %d lastPsn %d\n\n", 
                    destQpn, key, val->firstPsn, val->lastPsn);
        }
        panic("[RdmaEngine] RdmaEngine.RGRRU.rruProcessing:"
            " cannot find windows elem according to destQpn\n");
    } 
    winElem = sndWindowList[destQpn];
    if (winElem->list == nullptr) {
        panic("[RdmaEngine] RdmaEngine.RGRRU.rruProcessing:"
            " destQpn %d has no pending elem\n", destQpn);
    }
    HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rruProcessing: Get ACK bounded QP List from Window\n");

    /* If RX ACK owns illegal psn, just abandon it. */
    if (winElem->firstPsn > ackPsn || winElem->lastPsn < ackPsn) {
        panic("[RdmaEngine] RdmaEngine.RGRRU.rruProcessing:"
            " RX ACK owns illegal PSN! QPN: %d, firstPsn: %d, lastPsn: %d, ackPsn: %d\n", 
            destQpn, winElem->firstPsn, winElem->lastPsn, ackPsn);
        // HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rruProcessing:"
        //     " RX ACK owns illegal PSN! firstPsn: %d, lastPsn: %d, ackPsn: %d\n", 
        //     winElem->firstPsn, winElem->lastPsn, ackPsn);
        ackPsn = winElem->firstPsn;
    }
    HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rruProcessing: RX ACK owns legal PSN! firstPsn: %d, lastPsn: %d\n", 
            winElem->firstPsn, winElem->lastPsn);

    /* If the elem, in Window list, has PSN <= RX PKT's PSN, 
     * release the elem.
     * Note if the elem is a RDMA read packet, 
     * elem's PSN
     * retrans the RDMA read packet. */
    bool reTrans = false;
    while (winElem->firstPsn <= ackPsn) {
        
        /* If this is a NAK packet, resend this packet, 
         * and get out of the loop. */
        if (winElem->firstPsn == ackPsn &&
                (aeth->syndrome_msn >> 24) == RSP_NAK) {
            reTransPkt(winElem, 1);
            break;
        }

        /**
         * Process different type of trans packets
         */
        EthPacketPtr winPkt = winElem->list->front()->txPkt;
        switch (( ((BTH *)(winPkt->data + ETH_ADDR_LEN * 2))->op_destQpn >> 24 ) & 0x1F) {
            case PKT_TRANS_SEND_ONLY:
            case PKT_TRANS_RWRITE_ONLY:
                postTxCpl(QP_TYPE_RC, destQpn, winElem->cqn, 
                            winElem->list->front()->txDesc);
                break;
            case PKT_TRANS_RREAD_ONLY:
                if (winElem->firstPsn < ackPsn) {
                    reTransPkt(winElem, ackPsn - winElem->firstPsn);
                    reTrans = true;
                } else if (winElem->firstPsn == ackPsn) {
                    HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rruProcessing: Start RDMA read response receiving process\n");
                    rdmaReadRsp(rxPkt, winElem->list->front());
                    postTxCpl(QP_TYPE_RC, destQpn, winElem->cqn, 
                            winElem->list->front()->txDesc);
                }
                break;
            default:
                panic("winPkt type wrong!\n");
        }
        if (reTrans == true) {
            panic("reTrans!\n");
            break;
        }

        // update QP Status in descriptor scheduler
        // std::pair<uint32_t, uint32_t> qpStatusUpdate(winElem->list->front()->txDesc->qpn, 
        //                                              winElem->list->front()->txDesc->len);
        std::pair<uint32_t, uint32_t> qpStatusUpdate(destQpn, 
                                                     winElem->list->front()->txDesc->len);
        rnic->updateQue.push(qpStatusUpdate);
        if (!rnic->descScheduler.updateEvent.scheduled())
        {
            rnic->schedule(rnic->descScheduler.updateEvent, curTick() + rnic->clockPeriod());
        }
        
        /**
         * Update the send window
         * Delete first elem in the list
         */
        ++winElem->firstPsn;
        --windowSize;
        windowFull = (windowSize >= windowCap);
        winElem->list->pop_front();
    }
}

void 
HanGuRnic::RdmaEngine::setMacAddr (uint8_t *dst, uint64_t src) {
    for (int i = 0; i < ETH_ADDR_LEN; ++i) {
        dst[ETH_ADDR_LEN - 1 - i] = (src >> (i * 8)) & 0xff;
    }
}


/**
 * @note
 *      Request Generation processing.
 *      This function is called by rgrrProcessing.
 *      !TODO: We don't implement multi-packet message, i.e., maximum size 
 *      for one message is 4KB. 
 */
void 
HanGuRnic::RdmaEngine::rguProcessing () {

    HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.%s!\n", __func__);

    // if (txsauFifo.size() > RGU_SAU_LIM)
    // {
    //     return;
    // }

    /* Get Descriptor & QPC & packet pointer 
     * from RdmaEngine.dpuProcessing */
    assert(dp2rgFifo.size());
    DP2RGPtr tmp = dp2rgFifo.front();
    TxDescPtr desc = tmp->desc;
    QpcResc *qpc = tmp->qpc;
    EthPacketPtr txPkt = tmp->txPkt;
    dp2rgFifo.pop();

    if (rnic->descScheduler.qpStatusTable[qpc->srcQpn]->type == LAT_QP)
    {
        HANGU_PRINT(RdmaEngine, "data received! qpn: 0x%x, curtick: %ld\n", qpc->srcQpn, curTick());
    }
    
    HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rguProcessing: qpType %d, WQE type: %d, qpn: 0x%x, dst qpn: 0x%x, sndPsn %d sndWqeOffset %d\n", 
            qpc->qpType, desc->opcode, qpc->srcQpn, qpc->destQpn, qpc->sndPsn, qpc->sndWqeOffset);

    /* Get Request Data (send & RDMA write) 
     * from MrRescModule.dmaRrspProcessing. */
    MrReqRspPtr rspData; /* I have already gotten the address in txPkt, 
                           * so it is useless for me. */
    /* Generate request packet (RDMA read/write, send) */
    // EthPacketPtr txPktToSend = std::make_shared<EthPacketData>(16384); //TODO: modify size here
    // txPktToSend->length = ETH_ADDR_LEN * 2 + getRdmaHeadSize(desc->opcode, qpc->qpType); /* ETH_ADDR_LEN * 2 means length of 2 MAC addr */
    
    if (desc->opcode == OPCODE_SEND || desc->opcode == OPCODE_RDMA_WRITE) {
        assert(rnic->txdataRspFifo.size());
        rspData = rnic->txdataRspFifo.front();
        rnic->txdataRspFifo.pop();
        assert(rspData->sentPktNum < rspData->mttNum);

        HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rguProcessing: "
                "Get Request Data: 0x%x, 0x%x, 0x%x, 0x%x, 0x%x, 0x%x, 0x%x, 0x%x\n", 
                (rspData->data)[0], (rspData->data)[1], (rspData->data)[2], (rspData->data)[3], 
                (rspData->data)[4], (rspData->data)[5], (rspData->data)[6], (rspData->data)[7]);
        HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rguProcessing: "
                "Get Request Data: 0x%x, 0x%x, 0x%x, 0x%x, 0x%x, 0x%x, 0x%x, 0x%x\n", 
                *(rspData->data+8), *(rspData->data + 9), *(rspData->data + 10), *(rspData->data + 11), 
                *(rspData->data + 12), *(rspData->data + 13), *(rspData->data + 14), *(rspData->data + 15));
    }

    /* Generate Request packet Header
     * We don't implement multi-packet message now. */
    // uint8_t *pktPtr = txPktToSend->data + ETH_ADDR_LEN * 2;
    uint8_t *pktPtr = txPkt->data + ETH_ADDR_LEN * 2;
    uint8_t needAck;
    setRdmaHead(desc, qpc, pktPtr, needAck);

    // if (desc->opcode == OPCODE_SEND || desc->opcode == OPCODE_RDMA_WRITE)
    // {
    //     copyEthData(txPkt, txPktToSend, rspData);
    // }

    // Set MAC address
    uint64_t dmac, lmac;
    if (qpc->qpType == QP_TYPE_RC) {
        dmac = qpc->dLid;
        lmac = qpc->lLid;
    } else if (qpc->qpType == QP_TYPE_UD) {
        dmac = desc->sendType.dlid;
        lmac = qpc->lLid;
    } else {
        panic("Unsupported QP type, opcode: %d, type: %d\n", desc->opcode, qpc->qpType);
    }
    HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rguProcessing: dmac 0x%lx, smac 0x%lx\n", dmac, lmac);
    setMacAddr(txPkt->data, dmac);
    setMacAddr(txPkt->data + ETH_ADDR_LEN, lmac);

    txPkt->length    += desc->len;
    txPkt->simLength += desc->len;

    // for (int i = 0; i < txPkt->length; ++i) {
    //     HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rguProcessing: data[%d] 0x%x\n", i, (txPkt->data)[i]);
    // }

    /* if the packet need ack, post pkt 
     * info into send window */
    if (needAck) {

        HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rguProcessing: Need ACK (RC type)!\n");

        /* Post Packet to send window */
        WindowElemPtr winElem = make_shared<WindowElem>(txPkt, qpc->srcQpn, 
                qpc->sndPsn, desc);
        if (sndWindowList.find(qpc->srcQpn) == sndWindowList.end()) { // sndWindowList[qpc->srcQpn] == nullptr
            sndWindowList[qpc->srcQpn] = new WinMapElem;
            sndWindowList[qpc->srcQpn]->list = new WinList;
            sndWindowList[qpc->srcQpn]->cqn = qpc->cqn;
        }
        if (sndWindowList[qpc->srcQpn]->list->size() == 0) {
            sndWindowList[qpc->srcQpn]->firstPsn = qpc->sndPsn;
        }
        sndWindowList[qpc->srcQpn]->lastPsn = qpc->sndPsn;
        sndWindowList[qpc->srcQpn]->list->push_back(winElem);

        // for (auto &item : sndWindowList) {
        //     uint32_t key = item.first;
        //     WinMapElem* val = item.second;
        //     if (val->list->size()) {
        //         HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rguProcessing: qpn: %d, key %d firstPsn %d lastPsn %d, size %d\n\n", 
        //                 qpc->srcQpn, key, val->firstPsn, val->lastPsn, val->list->size());
        //     }
        // }
        assert(sndWindowList[qpc->srcQpn]->firstPsn <= sndWindowList[qpc->srcQpn]->lastPsn);

        /* Update the state of send window.  
         * If window is full, block RC transmission */
        ++windowSize;
        windowFull = (windowSize >= windowCap);

        HANGU_PRINT(RdmaEngine, "need ACK! RdmaEngine.RGRRU.rguProcessing: qpn: %d, first psn: %d, last psn: %d, windowSize %d\n", 
            qpc->srcQpn, sndWindowList[qpc->srcQpn]->firstPsn, sndWindowList[qpc->srcQpn]->lastPsn, windowSize);
    }
    
    /* Post Send Packet. Schedule RdmaEngine.sauProcessing 
     * to Send Packet through Ethernet Interface. */
    txsauFifo.push(txPkt);
    if (!sauEvent.scheduled()) {
        rnic->schedule(sauEvent, curTick() + rnic->clockPeriod());
    }
    messageEnd = true; /* Just ignore it now. */

    // update on fly packet number, ONLY FOR RC CONNECTIONS
    if (needAck)
    {
        onFlyPacketNum++;
    }

    /* Update QPC */
    if (qpc->qpType == QP_TYPE_RC) {
        ++qpc->sndPsn;
    }

    /* Same as in userspace drivers */
    qpc->sndWqeOffset += sizeof(TxDesc);
    if (qpc->sndWqeOffset + sizeof(TxDesc) > (1 << qpc->sqSizeLog)) {
        qpc->sndWqeOffset = 0;  /* qpc->sqSizeLog */ 
    }
    
    /* Post CQ if no need to acks. */
    if (!needAck && messageEnd) {
        postTxCpl(qpc->qpType, qpc->srcQpn, qpc->cqn, desc);
    }

    /* !TODO: we may need to implement timer here. */

    /* If next pkt doesn't not belong to this qp or 
     * there's no pkt, Post QPC back to QpcModule.
     * Note that we uses short circuit logic in "||", and 
     * the sequence of two condition cannot change. 
     * !FIXME: We don't use it now, cause we update qpc when read it. */
    // if (dp2rgFifo.empty() || /* No packet to send */
    //         dp2rgFifo.front()->qpc->srcQpn != qpc->srcQpn) { /* next qpc != current qpc */
        
    //     /* post qpc wreq to qpcModule */
    //     CxtReqRspPtr qpcWrReq = make_shared<CxtReqRsp>(CXT_WREQ_QP, CXT_CHNL_TX, qpc->srcQpn);
    //     qpcWrReq->txQpcReq = qpc;
    //     rnic->qpcModule.postQpcReq(qpcWrReq);
    // }
    delete qpc; /* qpc is useless */
    
    HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rguProcessing: out!\n");
}

bool
HanGuRnic::RdmaEngine::isReqGen() {
    return dp2rgFifo.size() && (rnic->txdataRspFifo.size() ||
            (dp2rgFifo.front()->desc->opcode == OPCODE_RDMA_READ));
}

bool
HanGuRnic::RdmaEngine::isRspRecv() {
    return ra2rgFifo.size();
}

bool
HanGuRnic::RdmaEngine::isWindowBlocked() {
    return windowFull && 
            (dp2rgFifo.front()->qpc->qpType == QP_TYPE_RC);
}

/**
 * @note set BTH and ETH header for PktPtr
*/
void HanGuRnic::RdmaEngine::setRdmaHead(TxDescPtr desc, QpcResc* qpc, uint8_t* pktPtr, uint8_t &needAck)
{
    uint32_t bthOp;
    if (desc->opcode == OPCODE_SEND && qpc->qpType == QP_TYPE_RC) 
    { /* RC Send */
        
        HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rguProcessing: RC send!\n");

        /* Add BTH header */
        bthOp = ((qpc->qpType << 5) | PKT_TRANS_SEND_ONLY) << 24;
        needAck = 0x01;
        ((BTH *) pktPtr)->op_destQpn = bthOp | qpc->destQpn;
        ((BTH *) pktPtr)->needAck_psn = (needAck << 24) | qpc->sndPsn; // TODO: change sndPsn

        HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rguProcessing: "
                "BTH head: 0x%x 0x%x\n", 
                ((BTH *) pktPtr)->op_destQpn, ((BTH *) pktPtr)->needAck_psn);
        
    } 
    else if (desc->opcode == OPCODE_SEND && qpc->qpType == QP_TYPE_UD) 
    { /* UD Send */
        
        HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rguProcessing: UD send!\n");
        
        /* Add BTH header */
        bthOp = ((qpc->qpType << 5) | PKT_TRANS_SEND_ONLY) << 24;
        needAck = 0x00;
        ((BTH *) pktPtr)->op_destQpn = bthOp | desc->sendType.destQpn;
        ((BTH *) pktPtr)->needAck_psn = (needAck << 24) | qpc->sndPsn;
        HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rguProcessing: "
                "BTH head: 0x%x 0x%x\n", 
                ((BTH *) pktPtr)->op_destQpn, ((BTH *) pktPtr)->needAck_psn);
        pktPtr += PKT_BTH_SZ;

        /* Add DETH header */
        ((DETH *) pktPtr)->srcQpn = qpc->srcQpn;
        ((DETH *) pktPtr)->qKey = desc->sendType.qkey;

        HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rguProcessing: "
                "DETH head: 0x%x 0x%x\n", 
                ((DETH *) pktPtr)->srcQpn, ((DETH *) pktPtr)->qKey);
    } 
    else if (qpc->qpType == QP_TYPE_RC && desc->opcode == OPCODE_RDMA_WRITE) 
    { /* RC RDMA Write */

        HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rguProcessing: RC RDMA Write!\n");
        
        // Add BTH header
        bthOp = ((qpc->qpType << 5) | PKT_TRANS_RWRITE_ONLY) << 24;
        needAck = 0x01;
        ((BTH *) pktPtr)->op_destQpn = bthOp | qpc->destQpn;
        ((BTH *) pktPtr)->needAck_psn = (needAck << 24) | qpc->sndPsn;
        HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rguProcessing: BTH head: 0x%x 0x%x, src qpn: %d, dst qpn: %d\n", 
                ((BTH *) pktPtr)->op_destQpn, ((BTH *) pktPtr)->needAck_psn, qpc->srcQpn, qpc->destQpn);
        pktPtr += PKT_BTH_SZ;
        
        // Add RETH header
        ((RETH *) pktPtr)->rVaddr_l = desc->rdmaType.rVaddr_l;
        ((RETH *) pktPtr)->rVaddr_h = desc->rdmaType.rVaddr_h;
        ((RETH *) pktPtr)->rKey = desc->rdmaType.rkey;
        ((RETH *) pktPtr)->len = desc->len;

        HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rguProcessing: "
                "RETH head: 0x%x 0x%x 0x%x 0x%x\n", 
                ((RETH *) pktPtr)->rVaddr_l, ((RETH *) pktPtr)->rVaddr_h, 
                ((RETH *) pktPtr)->rKey, ((RETH *) pktPtr)->len);
    } 
    else if (qpc->qpType == QP_TYPE_RC && desc->opcode == OPCODE_RDMA_READ) 
    { /* RC RDMA Read */
        
        HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rguProcessing: RC RDMA Write!\n");
        
        // Add BTH header
        bthOp = ((qpc->qpType << 5) | PKT_TRANS_RREAD_ONLY) << 24;
        needAck = 0x01;
        ((BTH *) pktPtr)->op_destQpn = bthOp | qpc->destQpn;
        ((BTH *) pktPtr)->needAck_psn = (needAck << 24) | qpc->sndPsn;
        HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rguProcessing: "
                "BTH head: 0x%x 0x%x\n", 
                ((BTH *) pktPtr)->op_destQpn, ((BTH *) pktPtr)->needAck_psn);
        pktPtr += PKT_BTH_SZ;

        // Add RETH header
        ((RETH *) pktPtr)->rVaddr_l = desc->rdmaType.rVaddr_l;
        ((RETH *) pktPtr)->rVaddr_h = desc->rdmaType.rVaddr_h;
        ((RETH *) pktPtr)->rKey = desc->rdmaType.rkey;
        ((RETH *) pktPtr)->len = desc->len;

        HANGU_PRINT(RdmaEngine, " RdmaEngine.RGRRU.rguProcessing: "
                "RETH head: 0x%x 0x%x 0x%x 0x%x\n", 
                ((RETH *) pktPtr)->rVaddr_l, ((RETH *) pktPtr)->rVaddr_h, 
                ((RETH *) pktPtr)->rKey, ((RETH *) pktPtr)->len);
    } 
    else 
    {
        panic("Unsupported opcode and QP type combination, "
                "opcode: %d, type: %d\n", desc->opcode, qpc->qpType);
    }
}

/**
 * @note
 * copy data from raw packet to new packet to be sent
 * @param rawPkt: packet containing the whole MR response
 * @param newPkt: packet to be sent, no larger than 4K
 * @param rspData: MR response
 * 
*/
// void HanGuRnic::RdmaEngine::copyEthData(EthPacketPtr rawPkt, EthPacketPtr newPkt, 
//                                         MrReqRspPtr rspData) // TO DO: not finished!
// {
//     assert(rspData->sentPktNum < rspData->mttNum);
//     if (rspData->mttNum == 1)
//     {
//         memcpy(newPkt->data + ETH_ADDR_LEN * 2 + getRdmaHeadSize(desc->opcode, qpc->qpType),
//             rawPkt->data + ETH_ADDR_LEN * 2 + getRdmaHeadSize(desc->opcode, qpc->qpType),
//             4096);
//     }
//     else 
//     // /* set packet length */
//     newPkt->length    += desc->len;
//     newPkt->simLength += desc->len;

//     rspData->sentPktNum++;
// }

/**
 * @note Called by rgrrEvent, scheduled by rdmaEngine.dpuProcessing, 
 *       rdmaEngine.rauProcessing, MrRescModule.dmaRrspProcessing and 
 *       my self.
 */
void
HanGuRnic::RdmaEngine::rgrrProcessing () {

    // HANGU_PRINT(RdmaEngine, " RdmaEngine.rgrrProcessing: dp2rgFifo.size %d rnic->txdataRspFifo %d\n", 
    //         dp2rgFifo.size(), rnic->txdataRspFifo.size());
    // HANGU_PRINT(RdmaEngine, " RdmaEngine.rgrrProcessing: isRspRecv %d isReqGen %d windowSize %d\n", 
    //         isRspRecv(), isReqGen(), windowSize);
    
    /* Rsp has higher priority than req generation, 
     * in case of dead lock. */
    if (isRspRecv()) {
        rruProcessing();
    } else if (isReqGen()) {
        if (isWindowBlocked()) {
            return;
        }
        rguProcessing();
    }

    /* Schedule myself when there's req need to generate or 
     * Ack need to recv. */
    if (isRspRecv() || isReqGen()) {
        if (!rgrrEvent.scheduled()) {
            rnic->schedule(rgrrEvent, curTick() + rnic->clockPeriod());
        }
    }
}

void
HanGuRnic::RdmaEngine::scuProcessing () {

    HANGU_PRINT(RdmaEngine, " RdmaEngine.scuProcessing!\n");

    assert(rnic->txCqcRspFifo.size());
    
    HANGU_PRINT(RdmaEngine, " RdmaEngine.scuProcessing: cq offset: %d, cq lkey %d, qpn %d, cqn %d, transtype: %d\n", 
            rnic->txCqcRspFifo.front()->txCqcRsp->offset, 
            rnic->txCqcRspFifo.front()->txCqcRsp->lkey, 
            rg2scFifo.front()->qpn, rg2scFifo.front()->cqn, rg2scFifo.front()->transType);
    
    /* Get Cq addr lkey, and post CQ WC to TPT */
    MrReqRspPtr cqWreq = make_shared<MrReqRsp>(DMA_TYPE_WREQ, TPT_WCHNL_TX_CQUE,
            rnic->txCqcRspFifo.front()->txCqcRsp->lkey, sizeof(CqDesc), 
            rnic->txCqcRspFifo.front()->txCqcRsp->offset);
    rnic->txCqcRspFifo.pop();
    cqWreq->cqDescReq = new CqDesc(rg2scFifo.front()->srvType, 
                                    rg2scFifo.front()->transType, 
                                    rg2scFifo.front()->byteCnt, 
                                    rg2scFifo.front()->qpn, 
                                    rg2scFifo.front()->cqn);
    rg2scFifo.pop();
    rnic->cqWreqFifo.push(cqWreq);

    // Schedule tarnsReq event(TPT) to post CQ WC to TPT
    if (!rnic->mrRescModule.transReqEvent.scheduled()) { // If not scheduled yet, schedule the event.
        rnic->schedule(rnic->mrRescModule.transReqEvent, curTick() + rnic->clockPeriod());
    }

    /* Schedule myself if still has elem in fifo */
    if (!rnic->txCqcRspFifo.empty() && !rg2scFifo.empty()) {
        if (!scuEvent.scheduled()) {
            rnic->schedule(scuEvent, curTick() + rnic->clockPeriod());
        }
    }

    HANGU_PRINT(RdmaEngine, " RdmaEngine.scuProcessing: out\n");

    return;

}


void
HanGuRnic::RdmaEngine::sauProcessing () {

    HANGU_PRINT(RdmaEngine, " RdmaEngine.sauProcessing!\n");

    if (txsauFifo.empty()) {
        return;
    }

    /**
     * unit: ps
     * We don't use it, cause ettherswicth has done this work
     */
    Tick bwDelay = txsauFifo.front()->length * rnic->etherBandwidth;

    /* Used only for Debug Print */
    // uint8_t *dmac = txsauFifo.front()->data;
    // uint8_t *smac = txsauFifo.front()->data + ETH_ADDR_LEN;
    BTH *bth = (BTH *)(txsauFifo.front()->data + ETH_ADDR_LEN * 2);
    uint8_t type = (bth->op_destQpn >> 24) & 0x1f;
    uint8_t srv  = bth->op_destQpn >> 29;
    // for (int i = 0; i < ETH_ADDR_LEN; ++i) {
    //     HANGU_PRINT(RdmaEngine, " RdmaEngine.sauProcessing, dmac[%d]: 0x%x smac[%d] 0x%x\n", i, dmac[i], i, smac[i]);
    // }
    HANGU_PRINT(RdmaEngine, " RdmaEngine.sauProcessing, type: %d, srv: %d, op_destQpn: 0x%x, BW %dps/byte, len %d, bwDelay %d, txsauFifo size: %d\n", 
            type, srv, bth->op_destQpn, rnic->etherBandwidth, txsauFifo.front()->length, bwDelay, txsauFifo.size());

    if (rnic->etherInt->sendPacket(txsauFifo.front())) {
        
        HANGU_PRINT(RdmaEngine, " RdmaEngine.sauProcessing: TxFIFO: Successful transmit!\n");

        rnic->txBytes += txsauFifo.front()->length;
        rnic->txPackets++;

        txsauFifo.pop();
    }

    /* Reschedule RdmaEngine.sauProcessing, 
     * no matter if it has been scheduled */
    // if (sauEvent.scheduled()) {
    //     rnic->reschedule(sauEvent, curTick() + bwDelay);
    // } else {
    //     rnic->schedule(sauEvent, curTick() + bwDelay);
    // }
    // if (txsauFifo.size()) {
    //     if (!sauEvent.scheduled()) {
    //         rnic->schedule(sauEvent, curTick() + rnic->clockPeriod());
    //     }
    // }
    if (txsauFifo.size())
    {
        if (sauEvent.scheduled())
        {
            rnic->reschedule(sauEvent, curTick() + bwDelay);
        }
        else
        {
            rnic->schedule(sauEvent, curTick() + bwDelay);
        }
    }

    HANGU_PRINT(RdmaEngine, " RdmaEngine.sauProcessing: out\n");
}

bool 
HanGuRnic::RdmaEngine::isAckPkt(EthPacketPtr rxPkt) {
    BTH *bth = (BTH *)(rxPkt->data + ETH_ADDR_LEN * 2);
    return ((bth->op_destQpn >> 24) & 0x1F) == PKT_TRANS_ACK;
}


/**
* @note receive ack 
*/
void
HanGuRnic::RdmaEngine::rauProcessing () {
    
    assert(rnic->rxFifo.size());
    EthPacketPtr rxPkt = rnic->rxFifo.front();
    BTH *bth = (BTH *)(rxPkt->data + ETH_ADDR_LEN * 2);
    // for (int i = 0; i < rxPkt->length; ++i) {
    //     HANGU_PRINT(RdmaEngine, " RdmaEngine.rauProcessing: data[%d]: 0x%x\n", i, (rxPkt->data)[i]);
    // }

    HANGU_PRINT(RdmaEngine, " RdmaEngine.rauProcessing: op_destQpn: 0x%x, rxFifo size: %d\n", bth->op_destQpn, rnic->rxFifo.size());
    
    
    if (((bth->op_destQpn >> 24) & 0x1F) == PKT_TRANS_ACK) { /* ACK packet, transform to RG&RRU */
        /* pop ethernet pkt from RX channel */
        rnic->rxFifo.pop();
        
        ra2rgFifo.push(rxPkt);
        
        /* Schedule rg&rru to start Processing Response Receiving. */
        if (!rgrrEvent.scheduled()) {
            rnic->schedule(rgrrEvent, curTick() + rnic->clockPeriod());
        }

        HANGU_PRINT(RdmaEngine, " RdmaEngine.rauProcessing: Receive ACK packet, pass to RdmaEngine.RGRRU.rruProcessing! rxFifo size: %d\n", rnic->rxFifo.size());

    } else if (rp2raIdxFifo.size()) { /* Incomming request packet, pass to RPU */
        
        /* pop ethernet pkt from RX channel */
        rnic->rxFifo.pop();

        /* read available idx */
        uint8_t idx = rp2raIdxFifo.front();
        rp2raIdxFifo.pop();

        HANGU_PRINT(RdmaEngine, " RdmaEngine.rauProcessing: "
                "Receive request packet, pass to RdmaEngine.rpuProcessing. idx %d\n", idx);
        
        /* Post qpc rd req to qpcModule */
        CxtReqRspPtr rxQpcRdReq = make_shared<CxtReqRsp>(
                                CXT_RREQ_QP, 
                                CXT_CHNL_RX, 
                                (bth->op_destQpn & 0xFFFFFF), 
                                1, 
                                idx);
        rxQpcRdReq->rxQpcRsp = new QpcResc;
        rnic->qpcModule.postQpcReq(rxQpcRdReq);

        /* Post RX pkt to RPU */
        rs2rpVector[idx] = rxPkt;
        /* We don't schedule it here, cause it should be 
        * scheduled by Context Module */
        // if (!rpuEvent.scheduled()) { /* Schedule RdmaEngine.rpuProcessing */
        //     rnic->schedule(rpuEvent, curTick() + rnic->clockPeriod());
        // }
    }

    /* If there still has elem in fifo, schedule myself again */
    if (rnic->rxFifo.size() && (rp2raIdxFifo.size() || isAckPkt(rnic->rxFifo.front()))) {
        if (!rauEvent.scheduled()) {
            rnic->schedule(rauEvent, curTick() + rnic->clockPeriod());
        }
    }

    HANGU_PRINT(RdmaEngine, " RdmaEngine.rauProcessing: out\n");
}


void 
HanGuRnic::RdmaEngine::rpuWbQpc (QpcResc* qpc) {
    
    HANGU_PRINT(RdmaEngine, " RdmaEngine.rpuProcessing: Write back QPC to Context Module. QPN: %d, RQ_offset %d, ePSN %d\n", 
            qpc->srcQpn, qpc->rcvWqeOffset, qpc->expPsn);

    /* post qpc wr req to qpcModule */
    /* !FIXME: We don't use it now, cause we update qpc when read it. */
    // CxtReqRspPtr rxQpcWrReq = make_shared<CxtReqRsp>(CXT_WREQ_QP, CXT_CHNL_RX, qpc->srcQpn);
    // rxQpcWrReq->txQpcReq = qpc;
    // rnic->qpcModule.postQpcReq(rxQpcWrReq);
}

void
HanGuRnic::RdmaEngine::rcvRpuProcessing () {

    HANGU_PRINT(RdmaEngine, " RdmaEngine.RPU.rcvRpuProcessing!\n");

    /* Get rx descriptor from MrRescModule.dmaRrspProcessing */
    assert(rnic->rxdescRspFifo.size());
    RxDescPtr rxDesc = rnic->rxdescRspFifo.front();
    rnic->rxdescRspFifo.pop();
    HANGU_PRINT(RdmaEngine, " RdmaEngine.RPU.rcvRpuProcessing: len %d, lkey %d, lVaddr 0x%lx\n", rxDesc->len, rxDesc->lkey, rxDesc->lVaddr);
    HANGU_PRINT(RdmaEngine, " RdmaEngine.RPU.rcvRpuProcessing: Get rx descriptor!\n");

    /* get Received packet (from wire) and qpc */
    std::pair<EthPacketPtr, QpcResc*> tmp = rp2rcvRpFifo.front();
    EthPacketPtr rxPkt = tmp.first; 
    QpcResc* qpcCopy = tmp.second; /* just a copy of qpc, original has been written back */
    rp2rcvRpFifo.pop();
    HANGU_PRINT(RdmaEngine, " RdmaEngine.RPU.rcvRpuProcessing: get Received packet and qpc!\n");

    /* Write received data back to memory through MR Module */
    MrReqRspPtr dataWreq = make_shared<MrReqRsp>(
                DMA_TYPE_WREQ, TPT_WCHNL_RX_DATA,
                rxDesc->lkey,
                rxDesc->len,
                (uint32_t)(rxDesc->lVaddr&0xFFF));
    dataWreq->wrDataReq = new uint8_t[dataWreq->length];
    if (qpcCopy->qpType == QP_TYPE_RC) { /* copy data, because the packet will be deleted soon */
        memcpy(dataWreq->wrDataReq, rxPkt->data + ETH_ADDR_LEN * 2 + PKT_BTH_SZ, dataWreq->length);
    } else {
        memcpy(dataWreq->wrDataReq, rxPkt->data + ETH_ADDR_LEN * 2 + PKT_BTH_SZ + PKT_DETH_SZ, dataWreq->length);
    }
    rnic->dataReqFifo.push(dataWreq);
    if (!rnic->mrRescModule.transReqEvent.scheduled()) {
        rnic->schedule(rnic->mrRescModule.transReqEvent, curTick() + rnic->clockPeriod());
    }

    HANGU_PRINT(RdmaEngine, " RdmaEngine.RPU.rcvRpuProcessing: data to be written back at 0x%x, offset 0x%x, data addr 0x%lx\n", 
            rxDesc->lVaddr, dataWreq->offset, (uintptr_t)(dataWreq->data));
    // for (int i = 0; i < dataWreq->length; ++i) {
    //     HANGU_PRINT(RdmaEngine, " RdmaEngine.RPU.rcvRpuProcessing: data[%d] 0x%x\n", i, (dataWreq->wrDataReq)[i]);
    // }

    /* RC QP generate ack */
    if (qpcCopy->qpType == QP_TYPE_RC) {
        
        EthPacketPtr txPkt = std::make_shared<EthPacketData>(16384);
        txPkt->length = ETH_ADDR_LEN * 2 + PKT_BTH_SZ + PKT_AETH_SZ;
        txPkt->simLength = 0;

        /* Set Mac addr head */
        memcpy(txPkt->data, rxPkt->data + ETH_ADDR_LEN, ETH_ADDR_LEN); /* set dst mac addr */
        memcpy(txPkt->data + ETH_ADDR_LEN, rxPkt->data, ETH_ADDR_LEN); /* set src mac addr */

        /* Add BTH header */
        uint32_t bthOp;
        uint8_t *pktPtr = txPkt->data + ETH_ADDR_LEN * 2;
        bthOp = ((qpcCopy->qpType << 5) | PKT_TRANS_ACK) << 24;
        ((BTH *) pktPtr)->op_destQpn = bthOp | qpcCopy->destQpn;
        ((BTH *) pktPtr)->needAck_psn =  qpcCopy->expPsn;
        pktPtr += PKT_BTH_SZ;

        /* Add AETH header */
        ((AETH *) pktPtr)->syndrome_msn = RSP_ACK << 24;

        /* Post Send Packet
         * Schedule SAU to Send out ACK Packet through Ethernet Interface. */
        txsauFifo.push(txPkt);
        if (!sauEvent.scheduled()) {
            rnic->schedule(sauEvent, curTick() + rnic->clockPeriod());
        }
    }

    /* Post related info into rcuProcessing for further processing */
    CqDescPtr cqDesc = make_shared<CqDesc>(qpcCopy->qpType, 
            OPCODE_RECV, rxDesc->len, qpcCopy->srcQpn, qpcCopy->cqn);
    rp2rcFifo.push(cqDesc);
    /* We don't schedule it here, cause it should be 
     * scheduled by Context Module */
    // if (!rcuEvent.scheduled()) {
    //     rnic->schedule(rcuEvent, curTick() + rnic->clockPeriod());
    // }
    
    /* Post Cqc read request to CqcModule */
    CxtReqRspPtr rxCqcRdReq = make_shared<CxtReqRsp>(CXT_RREQ_CQ, CXT_CHNL_RX, qpcCopy->cqn);
    rxCqcRdReq->txCqcRsp = new CqcResc;
    rnic->cqcModule.postCqcReq(rxCqcRdReq);

    delete qpcCopy;

    /* schedule myself if there's still has elem in input fifo */
    if (rp2rcvRpFifo.size() && rnic->rxdescRspFifo.size()) {
        if (!rcvRpuEvent.scheduled()) {
            rnic->schedule(rcvRpuEvent, curTick() + rnic->clockPeriod());
        }
    }
    
    HANGU_PRINT(RdmaEngine, " RdmaEngine.RPU.rcvRpuProcessing: out!\n");
}

void
HanGuRnic::RdmaEngine::wrRpuProcessing (EthPacketPtr rxPkt, QpcResc* qpc) {

    HANGU_PRINT(RdmaEngine, " RdmaEngine.RPU.wrRPU!\n");
    
    /* Parse received RDMA write packet */
    RETH *reth = (RETH *)(rxPkt->data + ETH_ADDR_LEN * 2 + PKT_BTH_SZ);
    uint8_t *data = (rxPkt->data + ETH_ADDR_LEN * 2 + PKT_BTH_SZ + PKT_RETH_SZ);
    HANGU_PRINT(RdmaEngine, " RdmaEngine.RPU.wrRPU: Parse received RDMA write packet!\n");
    
    /* Write data back to memory through TPT */
    MrReqRspPtr dataWreq = make_shared<MrReqRsp>(
                DMA_TYPE_WREQ, TPT_WCHNL_RX_DATA,
                reth->rKey,
                reth->len,
                (uint32_t)(reth->rVaddr_l & 0xFFF));
    dataWreq->wrDataReq = new uint8_t[dataWreq->length];
    memcpy(dataWreq->wrDataReq, data, dataWreq->length); /* copy data, because the packet will be deleted soon */
    rnic->dataReqFifo.push(dataWreq);
    if (!rnic->mrRescModule.transReqEvent.scheduled()) {
        rnic->schedule(rnic->mrRescModule.transReqEvent, curTick() + rnic->clockPeriod());
    }
    // HANGU_PRINT(RdmaEngine, " RdmaEngine.RPU.wrRPU: Write data back to memory through TPT\n");
    HANGU_PRINT(RdmaEngine, " RdmaEngine.RPU.wrRPU: Recved RDMA write data: %s, rkey: 0x%x, len %d, rvaddr 0x%x\n", 
            dataWreq->wrDataReq, reth->rKey, reth->len, reth->rVaddr_l);

    /* RC QP generate ack */
    if (qpc->qpType == QP_TYPE_RC) {
        
        EthPacketPtr txPkt = std::make_shared<EthPacketData>(16384);
        txPkt->length = ETH_ADDR_LEN * 2 + PKT_BTH_SZ + PKT_AETH_SZ;
        txPkt->simLength = 0;

        /* Set Mac addr head */
        memcpy(txPkt->data, rxPkt->data + ETH_ADDR_LEN, ETH_ADDR_LEN); /* set dst mac addr */
        memcpy(txPkt->data + ETH_ADDR_LEN, rxPkt->data, ETH_ADDR_LEN); /* set src mac addr */

        /* Add BTH header */
        uint32_t bthOp;
        uint8_t *pktPtr = txPkt->data + ETH_ADDR_LEN * 2;
        bthOp = ((qpc->qpType << 5) | PKT_TRANS_ACK) << 24;
        ((BTH *) pktPtr)->op_destQpn = bthOp | qpc->destQpn;
        ((BTH *) pktPtr)->needAck_psn =  qpc->expPsn;
        HANGU_PRINT(RdmaEngine, "wrRpuProcessing: src QPN: 0x%x, dst QPN: 0x%x, expPsn: 0x%x\n", qpc->srcQpn, qpc->destQpn, qpc->expPsn);
        pktPtr += PKT_BTH_SZ;

        /* Add AETH header */
        ((AETH *) pktPtr)->syndrome_msn = RSP_ACK << 24;

        /** Post Send Packet
         * Schedule sau to start Send Packet through Ethernet Interface.
         */
        txsauFifo.push(txPkt);
        if (!sauEvent.scheduled()) {
            rnic->schedule(sauEvent, curTick() + rnic->clockPeriod());
        }
    }

    // /* Update QPC in receive side, 
    //  * and Write QPC back to CM module */
    // ++qpc->expPsn;
    // rpuWbQpc(qpc);

    HANGU_PRINT(RdmaEngine, " RdmaEngine.RPU.wrRPU: out!\n");
}


/**
 * @note Process RDMA read incomming pkt, Requester part. (rdCplRpuProcessing is counterpart)
 * This part post data read request to DMAEngine */
void
HanGuRnic::RdmaEngine::rdRpuProcessing (EthPacketPtr rxPkt, QpcResc* qpc) {

    HANGU_PRINT(RdmaEngine, " RdmaEngine.RPU.rdRpuProcessing!\n");
    
    /* Parse received RDMA write packet */
    RETH *reth = (RETH *)(rxPkt->data + ETH_ADDR_LEN * 2 + PKT_BTH_SZ);
    HANGU_PRINT(RdmaEngine, " RdmaEngine.RPU.rdRpuProcessing:"
            " Parse received RDMA read packet! len: %d, rKey: 0x%x, vaddr: 0x%x\n", reth->len, reth->rKey, reth->rVaddr_l);

    /* Generate RDMA read response packet */
    EthPacketPtr txPkt = std::make_shared<EthPacketData>(16384);
    txPkt->length = ETH_ADDR_LEN * 2 + PKT_BTH_SZ + PKT_AETH_SZ;
    txPkt->simLength = 0;

    /* Set Mac addr head */
    memcpy(txPkt->data, rxPkt->data + ETH_ADDR_LEN, ETH_ADDR_LEN); /* set dst mac addr */
    memcpy(txPkt->data + ETH_ADDR_LEN, rxPkt->data, ETH_ADDR_LEN); /* set src mac addr */

    /* Add BTH header */
    uint32_t bthOp;
    uint8_t *pktPtr = txPkt->data + ETH_ADDR_LEN * 2;
    bthOp = ((qpc->qpType << 5) | PKT_TRANS_ACK) << 24;
    ((BTH *) pktPtr)->op_destQpn = bthOp | qpc->destQpn;
    ((BTH *) pktPtr)->needAck_psn =  qpc->expPsn;
    pktPtr += PKT_BTH_SZ;

    /* Add AETH header */
    ((AETH *) pktPtr)->syndrome_msn = RSP_ACK << 24;
    pktPtr += PKT_AETH_SZ;
    HANGU_PRINT(RdmaEngine, " RdmaEngine.RPU.rdRpuProcessing: Generate RDMA read response packet!\n");
    
    /* Read data from memory through MrRescModule.transReqProcessing */
    MrReqRspPtr dataRreq = make_shared<MrReqRsp>(
                DMA_TYPE_RREQ, MR_RCHNL_RX_DATA,
                reth->rKey,
                reth->len,
                (uint32_t)(reth->rVaddr_l & 0xFFF)); /* offset, within 4KB */
    dataRreq->rdDataRsp = pktPtr;
    rnic->dataReqFifo.push(dataRreq);
    if (!rnic->mrRescModule.transReqEvent.scheduled()) {
        rnic->schedule(rnic->mrRescModule.transReqEvent, curTick() + rnic->clockPeriod());
    }
    HANGU_PRINT(RdmaEngine, " RdmaEngine.RPU.rdRpuProcessing:"
            " Read data from memory through MrRescModule.transReqProcessing!\n");


    /* Post response packet to RdmaEngine.RPU.rdCplRpuProcessing */
    rp2rpCplFifo.push(txPkt);
    /* We don't schedule it here, cause it should be 
    * scheduled by MR Module */
    // if (!rdCplRpuEvent.scheduled()) { /* Schedule RdmaEngine.RPU.rdCplRpuProcessing */
    //     rnic->schedule(rdCplRpuEvent, curTick() + rnic->clockPeriod());
    // }

    // /* Update QPC in receive side, 
    //  * and Write QPC back to CM module */
    // ++qpc->expPsn;
    // rpuWbQpc(qpc);

    HANGU_PRINT(RdmaEngine, " RdmaEngine.RPU.rdRpuProcessing: out!\n");
}

void
HanGuRnic::RdmaEngine::rdCplRpuProcessing () {

    HANGU_PRINT(RdmaEngine, " RdmaEngine.RPU.rdRPUCpl!\n");
    
    // Get rsp pkt
    assert(!rnic->rxdataRspFifo.empty());
    assert(!rp2rpCplFifo.empty());
    rnic->rxdataRspFifo.pop();
    EthPacketPtr txPkt = rp2rpCplFifo.front();
    rp2rpCplFifo.pop();
    HANGU_PRINT(RdmaEngine, " RdmaEngine.RPU.rdRPUCpl: data %s!\n", 
            (char *)(txPkt->data + ETH_ADDR_LEN * 2 + PKT_BTH_SZ + PKT_AETH_SZ));
    
    
    /** Post Send Packet
     * Schedule sau to start Send Packet through Ethernet Interface.
     */
    txsauFifo.push(txPkt);
    if (!sauEvent.scheduled()) {
        rnic->schedule(sauEvent, curTick() + rnic->clockPeriod());
    }

    HANGU_PRINT(RdmaEngine, " RdmaEngine.RPU.rdRPUCpl: out!\n");
}

uint32_t 
HanGuRnic::RdmaEngine::rxDescLenSel() {
    return 1;
}

void
HanGuRnic::RdmaEngine::rpuProcessing () {

    HANGU_PRINT(RdmaEngine, " RdmaEngine.rpuProcessing!\n");

    /* Get QP context from CxtRescModule.cxtRspProcessing */
    assert(rnic->qpcModule.rxQpcRspFifo.size());
    QpcResc* qpc = rnic->qpcModule.rxQpcRspFifo.front()->rxQpcRsp;
    uint8_t idx = rnic->qpcModule.rxQpcRspFifo.front()->idx;
    rnic->qpcModule.rxQpcRspFifo.pop();
    HANGU_PRINT(RdmaEngine, " RdmaEngine.rpuProcessing: Get QPC from cxtRspProcessing. srcQpn: %d, dstQpn %d, qpc->rcvWqeOffset: %d, idx %d\n", 
            qpc->srcQpn, qpc->destQpn, qpc->rcvWqeOffset, idx);
    
    // for (int i = 0; i < 100; ++i) {
    //     if (rs2rpVector[i] != nullptr) {
    //         HANGU_PRINT(RdmaEngine, " RdmaEngine.rpuProcessing: idx %d is valid\n", i);
    //     }
    // }
    
    /* Get RX pkt from RdmaEngine.rauProcessing */
    assert(rs2rpVector[idx] != nullptr);
    EthPacketPtr rxPkt = rs2rpVector[idx];
    BTH *bth = (BTH *)(rxPkt->data + ETH_ADDR_LEN * 2);
    rs2rpVector[idx] = nullptr;
    HANGU_PRINT(RdmaEngine, " RdmaEngine.rpuProcessing: Get RX pkt from rpuProcessing, bth 0x%x, 0x%x\n", bth->op_destQpn, bth->needAck_psn);

    /* reschedule rau if rp2raIdxFifo is empty && new rx pkt is comming */
    rp2raIdxFifo.push(idx);
    if ((rp2raIdxFifo.size() == 1) && rnic->rxFifo.size()) {
        if (!rauEvent.scheduled()) {
            rnic->schedule(rauEvent, curTick() + rnic->clockPeriod());
        }
    }

    MrReqRspPtr descReq;
    uint8_t pkt_opcode = (bth->op_destQpn >> 24) & 0x1F;
    QpcResc* qpcCopy;
    switch (pkt_opcode) {
      case PKT_TRANS_SEND_ONLY: /* Call rcvRpuProcessing() later. */
        HANGU_PRINT(RdmaEngine, " RdmaEngine.rpuProcessing: PKT_TRANS_SEND_ONLY\n");
        
        /* Post rx descriptor Read request to mrRescModule.transReqProcessing  */
        descReq = make_shared<MrReqRsp>(DMA_TYPE_RREQ, MR_RCHNL_RX_DESC,
                qpc->rcvWqeBaseLkey, rxDescLenSel() * sizeof(RxDesc), qpc->rcvWqeOffset);
        descReq->rxDescRsp = new RxDesc;
        rnic->descReqFifo.push(descReq);
        if (!rnic->mrRescModule.transReqEvent.scheduled()) { /* Scheduled MR module to read RX descriptor */
            rnic->schedule(rnic->mrRescModule.transReqEvent, curTick() + rnic->clockPeriod());
        }
        HANGU_PRINT(RdmaEngine, " RdmaEngine.rpuProcessing:"
                " Post rx descriptor read request to MR module. rq_lkey: 0x%x\n", 
                qpc->rcvWqeBaseLkey);

        /* Post RX packet and qpc to RcvRPU */
        qpcCopy = new QpcResc;
        memcpy(qpcCopy, qpc, sizeof(QpcResc));
        rp2rcvRpFifo.emplace(rxPkt, qpcCopy);
        /* We don't schedule it here, cause it should be 
        * scheduled by MR Module */
        // if (!rcvRpuEvent.scheduled()) { /* Schedule RdmaEngine.RPU.rcvRpuProcessing */
        //     rnic->schedule(rcvRpuEvent, curTick() + rnic->clockPeriod());
        // }

        break;
      case PKT_TRANS_RWRITE_ONLY: /* Process RDMA Write */
        wrRpuProcessing(rxPkt, qpc);
        break;
      case PKT_TRANS_RREAD_ONLY: /* Process RDMA Read */
        rdRpuProcessing(rxPkt, qpc);
        break;
      default:
        panic("RX packet type is wrong: 0x%x\n", pkt_opcode);
    }

    /* Update QPC, 
     * and Write QPC back to CM module */
    // switch (pkt_opcode) {
    //   case PKT_TRANS_SEND_FIRST:
    //   case PKT_TRANS_SEND_MID:
    //   case PKT_TRANS_SEND_LAST:
    //   case PKT_TRANS_SEND_ONLY:
    //     /* Update the recvWqe in qpc */
    //     qpc->rcvWqeOffset += (rxDescLenSel() * sizeof(RxDesc));
    //     if (qpc->rcvWqeOffset + (rxDescLenSel() * sizeof(RxDesc)) > (1 << qpc->rqSizeLog)) {
    //         qpc->rcvWqeOffset = 0; /* Same as in userspace drivers */ /* qpc->rqSizeLog */ 
    //     }
    //     HANGU_PRINT(RdmaEngine, " RdmaEngine.rpuProcessing: Update the recvWqe in qpc offset %d qpc->rqSizeLog %d\n", qpc->rcvWqeOffset, qpc->rqSizeLog);
    //     break;
    //   default:
    //     break;
    // }
    // if (qpc->qpType == QP_TYPE_RC) {
    //     ++qpc->expPsn;
    // }
    // rpuWbQpc(qpc);
    delete qpc; /* qpc is useless */

    /* if we have elem in input fifo, schedule myself again */
    if (rnic->qpcModule.rxQpcRspFifo.size()) {
        if (!rpuEvent.scheduled()) { /* Schedule RdmaEngine.rpuProcessing */
            rnic->schedule(rpuEvent, curTick() + rnic->clockPeriod());
        }
    }
    
    HANGU_PRINT(RdmaEngine, " RdmaEngine.rpuProcessing: out\n");
}

void
HanGuRnic::RdmaEngine::rcuProcessing () {

    HANGU_PRINT(RdmaEngine, " RdmaEngine.rcuProcessing\n");
    
    /* Get CQ addr lkey, and post CQ Work Completion to MR Module */
    assert(rnic->rxCqcRspFifo.size());
    MrReqRspPtr cqWreq = make_shared<MrReqRsp>(DMA_TYPE_WREQ, TPT_WCHNL_RX_CQUE,
            rnic->rxCqcRspFifo.front()->txCqcRsp->lkey, sizeof(CqDesc), 
            rnic->rxCqcRspFifo.front()->txCqcRsp->offset);
    rnic->rxCqcRspFifo.pop();

    HANGU_PRINT(RdmaEngine, " RdmaEngine.rcuProcessing: cq lkey %d, cq offset %d\n", cqWreq->lkey, cqWreq->offset);

    cqWreq->cqDescReq = new CqDesc(rp2rcFifo.front()->srvType, 
                                    rp2rcFifo.front()->transType, 
                                    rp2rcFifo.front()->byteCnt, 
                                    rp2rcFifo.front()->qpn, 
                                    rp2rcFifo.front()->cqn);
    rp2rcFifo.pop();


    rnic->cqWreqFifo.push(cqWreq);
    if (!rnic->mrRescModule.transReqEvent.scheduled()) { // If not scheduled yet, schedule the event.
        rnic->schedule(rnic->mrRescModule.transReqEvent, curTick() + rnic->clockPeriod());
    }

    /* schedule myself if there's still has elem in input fifo */
    if (rp2rcFifo.size() && rnic->rxCqcRspFifo.size()) {
        if (!rcuEvent.scheduled()) {
            rnic->schedule(rcuEvent, curTick() + rnic->clockPeriod());
        }
    }

    HANGU_PRINT(RdmaEngine, " RdmaEngine.rcuProcessing: out\n");
}

///////////////////////////// HanGuRnic::RDMA Engine relevant {end}//////////////////////////////
