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
 * Device model for Han Gu RNIC.
 */

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

HanGuRnic::HanGuRnic(const Params *p)
  : RdmaNic(p), etherInt(NULL),
    doorbellVector(p->reorder_cap),
    ceuProcEvent      ([this]{ ceuProc();      }, name()),
    doorbellProcEvent ([this]{ doorbellProc(); }, name()),
    mboxEvent([this]{ mboxFetchCpl();    }, name()),
    rdmaEngine  (this, name() + ".RdmaEngine", p->reorder_cap),
    descScheduler(this, name() + ".DescScheduler"),
    mrRescModule(this, name() + ".MrRescModule", p->mpt_cache_num, p->mtt_cache_num),
    cqcModule   (this, name() + ".CqcModule", p->cqc_cache_num),
    qpcModule   (this, name() + ".QpcModule", p->qpc_cache_cap, p->reorder_cap),
    dmaReadDelay(p->dma_read_delay), dmaWriteDelay(p->dma_write_delay),
    pciBandwidth(p->pci_speed),
    etherBandwidth(p->ether_speed),
    dmaEngine   (this, name() + ".DmaEngine"),
    LinkDelay     (p->link_delay),
    ethRxPktProcEvent([this]{ ethRxPktProc(); }, name()) {

    HANGU_PRINT(HanGuRnic, " qpc_cache_cap %d  reorder_cap %d cpuNum 0x%x\n", p->qpc_cache_cap, p->reorder_cap, p->cpu_num);

    cpuNum = p->cpu_num;
    syncCnt = 0;
    syncSucc = 0;

    for (int i = 0; i < p->reorder_cap; ++i) {
        df2ccuIdxFifo.push(i);
    }

    etherInt = new HanGuRnicInt(name() + ".int", this);

    mboxBuf = new uint8_t[4096];

    // Set the MAC address
    memset(macAddr, 0, ETH_ADDR_LEN);
    for (int i = 0; i < ETH_ADDR_LEN; ++i) {
        macAddr[ETH_ADDR_LEN - 1 - i] = (p->mac_addr >> (i * 8)) & 0xff;
        // HANGU_PRINT(PioEngine, " mac[%d] 0x%x\n", ETH_ADDR_LEN - 1 - i, macAddr[ETH_ADDR_LEN - 1 - i]);
    }

    BARSize[0]  = (1 << 12);
    BARAddrs[0] = 0xc000000000000000;
}

HanGuRnic::~HanGuRnic() {
    delete etherInt;
}

void
HanGuRnic::init() {
    PciDevice::init();
}

Port &
HanGuRnic::getPort(const std::string &if_name, PortID idx) {
    if (if_name == "interface")
        return *etherInt;
    return RdmaNic::getPort(if_name, idx);
}

///////////////////////////// HanGuRnic::PIO relevant {begin}//////////////////////////////

Tick
HanGuRnic::writeConfig(PacketPtr pkt) {
    int offset = pkt->getAddr() & PCI_CONFIG_SIZE;
    if (offset < PCI_DEVICE_SPECIFIC) {
        PciDevice::writeConfig(pkt);
    }
    else {
        panic("Device specific PCI config space not implemented.\n");
    }

    /* !TODO: We will implement PCI configuration here.
     * Some work may need to be done here based for the pci 
     * COMMAND bits, we don't realize now. */

    return configDelay;
}


Tick
HanGuRnic::read(PacketPtr pkt) {
    int bar;
    Addr daddr;

    if (!getBAR(pkt->getAddr(), bar, daddr)) {
        panic("Invalid PCI memory access to unmapped memory.\n");
    }

    /* Only HCR Space (BAR0-1) is allowed */
    assert(bar == 0);

    /* Only 32bit accesses allowed */
    // assert(pkt->getSize() == 4);

    // HANGU_PRINT(PioEngine, " Read device addr 0x%x, pioDelay: %d\n", daddr, pioDelay);


    /* Handle read of register here.
     * Here we only implement read go bit */
    if (daddr == (Addr)&(((HanGuRnicDef::Hcr*)0)->goOpcode)) {/* Access `GO` bit */
        pkt->setLE<uint32_t>(regs.cmdCtrl.go()<<31 | regs.cmdCtrl.op());
    } else if (daddr == 0x20) {/* Access `sync` reg */
        pkt->setLE<uint32_t>(syncSucc);
    } 
    else if (daddr == 0x30)
    {
        pkt->setLE<uint64_t>(regs.qosShareAddr);
    }
    else if (daddr == 0x40)
    {
        // reserved for QP amount
    }
    else {
        pkt->setLE<uint32_t>(0);
    }

    pkt->makeAtomicResponse();
    return pioDelay;
}

Tick
HanGuRnic::write(PacketPtr pkt) {
    int bar;
    Addr daddr;

    HANGU_PRINT(PioEngine, " PioEngine.write: pkt addr 0x%x, size 0x%x\n",
            pkt->getAddr(), pkt->getSize());

    if (!getBAR(pkt->getAddr(), bar, daddr)) {
        panic("Invalid PCI memory access to unmapped memory.\n");
    }

    /* Only BAR 0 is allowed */
    assert(bar == 0);
    
    if (daddr == 0 && pkt->getSize() == sizeof(Hcr)) {
        HANGU_PRINT(PioEngine, " PioEngine.write: HCR, inparam: 0x%x\n", pkt->getLE<Hcr>().inParam_l);

        regs.inParam.iparaml(pkt->getLE<Hcr>().inParam_l);
        regs.inParam.iparamh(pkt->getLE<Hcr>().inParam_h);
        regs.modifier = pkt->getLE<Hcr>().inMod;
        regs.outParam.oparaml(pkt->getLE<Hcr>().outParam_l);
        regs.outParam.oparamh(pkt->getLE<Hcr>().outParam_h);
        regs.cmdCtrl = pkt->getLE<Hcr>().goOpcode;

        /* Schedule CEU */
        if (!ceuProcEvent.scheduled()) { 
            schedule(ceuProcEvent, curTick() + clockPeriod());
        }

    } else if (daddr == 0x18 && pkt->getSize() == sizeof(uint64_t)) {

        /*  Used to Record start of time */
        HANGU_PRINT(HanGuRnic, " PioEngine.write: Doorbell, value %#X pio interval %ld\n", pkt->getLE<uint64_t>(), curTick() - this->tick); 
        
        regs.db._data = pkt->getLE<uint64_t>();
        
        DoorbellPtr dbell = make_shared<DoorbellFifo>(regs.db.opcode(), 
            regs.db.num(), regs.db.qpn(), regs.db.offset());
        pio2ccuDbFifo.push(dbell);

        /* Record last tick */
        this->tick = curTick();

        /* Schedule doorbellProc */
        if (!doorbellProcEvent.scheduled()) { 
            schedule(doorbellProcEvent, curTick() + clockPeriod());
        }

        HANGU_PRINT(HanGuRnic, " PioEngine.write: qpn %d, opcode %x, num %d\n", 
                regs.db.qpn(), regs.db.opcode(), regs.db.num());
    } else if (daddr == 0x20 && pkt->getSize() == sizeof(uint32_t)) { /* latency sync */
        
        HANGU_PRINT(HanGuRnic, " PioEngine.write: sync bit, value %#X, syncCnt %d\n", pkt->getLE<uint32_t>(), syncCnt); 
        
        if (pkt->getLE<uint32_t>() == 1) {
            syncCnt += 1;
            assert(syncCnt <= cpuNum);
            if (syncCnt == cpuNum) {
                syncSucc = 1;
            }
        } else {
            assert(syncCnt > 0);
            syncCnt -= 1;
            if (syncCnt == 0) {
                syncSucc = 0;
            }
        }

        HANGU_PRINT(HanGuRnic, " PioEngine.write: sync bit end, value %#X, syncCnt %d\n", pkt->getLE<uint32_t>(), syncCnt); 
    } 
    else if (daddr == 0x30 && pkt->getSize() == sizeof(uint64_t))
    {
        // write shared parameter address
        regs.qosShareAddr = pkt->getLE<uint64_t>();
        HANGU_PRINT(HanGuRnic, "QoS shared address set: 0x%s\n", regs.qosShareAddr);
    }
    else {
        panic("Write request to unknown address : %#x && size 0x%x\n", daddr, pkt->getSize());
    }

    pkt->makeAtomicResponse();
    return pioDelay;
}
///////////////////////////// HanGuRnic::PIO relevant {end}//////////////////////////////

///////////////////////////// HanGuRnic::CCU relevant {begin}//////////////////////////////

void
HanGuRnic::mboxFetchCpl () {

    HANGU_PRINT(CcuEngine, " CcuEngine.CEU.mboxFetchCpl!\n");
    switch (regs.cmdCtrl.op()) {
      case INIT_ICM :
        HANGU_PRINT(CcuEngine, " CcuEngine.CEU.mboxFetchCpl: INIT_ICM command!\n");
        regs.mptBase   = ((InitResc *)mboxBuf)->mptBase;
        regs.mttBase   = ((InitResc *)mboxBuf)->mttBase;
        regs.qpcBase   = ((InitResc *)mboxBuf)->qpcBase;
        regs.cqcBase   = ((InitResc *)mboxBuf)->cqcBase;
        regs.mptNumLog = ((InitResc *)mboxBuf)->mptNumLog;
        regs.qpcNumLog = ((InitResc *)mboxBuf)->qpsNumLog;
        regs.cqcNumLog = ((InitResc *)mboxBuf)->cqsNumLog;
        mrRescModule.mptCache.setBase(regs.mptBase);
        mrRescModule.mttCache.setBase(regs.mttBase);
        qpcModule.setBase(regs.qpcBase);
        cqcModule.cqcCache.setBase(regs.cqcBase);
        break;
      case WRITE_ICM:
        // HANGU_PRINT(CcuEngine, " CcuEngine.CEU.mboxFetchCpl: WRITE_ICM command! outparam %d, mod %d\n", 
        //         regs.outParam.oparaml(), regs.modifier);
        
        switch (regs.outParam.oparaml()) {
          case ICMTYPE_MPT:
            HANGU_PRINT(CcuEngine, " CcuEngine.CEU.mboxFetchCpl: ICMTYPE_MPT command!\n");
            mrRescModule.mptCache.icmStore((IcmResc *)mboxBuf, regs.modifier);
            break;
          case ICMTYPE_MTT:
            HANGU_PRINT(CcuEngine, " CcuEngine.CEU.mboxFetchCpl: ICMTYPE_MTT command!\n");
            mrRescModule.mttCache.icmStore((IcmResc *)mboxBuf, regs.modifier);
            break;
          case ICMTYPE_QPC:
            HANGU_PRINT(CcuEngine, " CcuEngine.CEU.mboxFetchCpl: ICMTYPE_QPC command!\n");
            qpcModule.icmStore((IcmResc *)mboxBuf, regs.modifier);
            break;
          case ICMTYPE_CQC:
            HANGU_PRINT(CcuEngine, " CcuEngine.CEU.mboxFetchCpl: ICMTYPE_CQC command!\n");
            cqcModule.cqcCache.icmStore((IcmResc *)mboxBuf, regs.modifier);
            break;
          default: /* ICM mapping do not belong any Resources. */
            panic("ICM mapping do not belong any Resources.\n");
        }
        break;
      case WRITE_MPT:
        HANGU_PRINT(CcuEngine, " CcuEngine.CEU.mboxFetchCpl: WRITE_MPT command! mod %d ouParam %d\n", regs.modifier, regs.outParam._data);
        for (int i = 0; i < regs.outParam._data; ++i) {
            MptResc *tmp = (((MptResc *)mboxBuf) + i);
            HANGU_PRINT(CcuEngine, " CcuEngine.CEU.mboxFetchCpl: WRITE_MPT command! mpt_index %d tmp_addr 0x%lx\n", tmp->key, (uintptr_t)tmp);
            mrRescModule.mptCache.rescWrite(tmp->key, tmp);
        }
        break;
      case WRITE_MTT:
        HANGU_PRINT(CcuEngine, " CcuEngine.CEU.mboxFetchCpl: WRITE_MTT command!\n");
        for (int i = 0; i < regs.outParam._data; ++i) {
            mrRescModule.mttCache.rescWrite(regs.modifier + i, ((MttResc *)mboxBuf) + i);
        }
        break;
      case WRITE_QPC:
        HANGU_PRINT(CcuEngine, " CcuEngine.CEU.mboxFetchCpl: WRITE_QPC command! 0x%lx\n", (uintptr_t)mboxBuf);
        for (int i = 0; i < regs.outParam._data; ++i) {
            CxtReqRspPtr qpcReq = make_shared<CxtReqRsp>(CXT_CREQ_QP, CXT_CHNL_TX, 0); /* last param is useless here */
            qpcReq->txQpcReq = new QpcResc;
            memcpy(qpcReq->txQpcReq, (((QpcResc *)mboxBuf) + i), sizeof(QpcResc));
            HANGU_PRINT(CcuEngine, " CcuEngine.CEU.mboxFetchCpl: WRITE_QPC command! i %d qpn 0x%x(%d), addr 0x%lx\n", 
                    i, qpcReq->txQpcReq->srcQpn, qpcReq->txQpcReq->srcQpn&QPN_MASK, (uintptr_t)qpcReq->txQpcReq);
            qpcReq->num = qpcReq->txQpcReq->srcQpn;
            qpcModule.postQpcReq(qpcReq); /* post create request to qpcModule */
            
            // write QP status
            QPStatusPtr qpStatus = make_shared<QPStatusItem>(
                qpcReq->txQpcReq->sndWqeBaseLkey, 
                qpcReq->txQpcReq->perfWeight,
                qpcReq->txQpcReq->indicator,
                qpcReq->txQpcReq->srcQpn,
                qpcReq->txQpcReq->groupID,
                qpcReq->txQpcReq->qpType);
            // delete this line later
            // HANGU_PRINT(CcuEngine, "write QPC, qpn: %d, indicator: %d, weight: %d\n", 
            //     qpcReq->txQpcReq->srcQpn, qpcReq->txQpcReq->indicator, qpcReq->txQpcReq->perfWeight);
            // assert(qpcReq->txQpcReq->indicator == BW_QP);
            // descScheduler.qpStatusTable.emplace(qpStatus->qpn, qpStatus);
            createQue.push(qpStatus);
            if (!descScheduler.createQpStatusEvent.scheduled())
            {
                schedule(descScheduler.createQpStatusEvent, curTick() + clockPeriod());
            }
        }
        delete[] mboxBuf;
        break;
      case WRITE_CQC:
        HANGU_PRINT(CcuEngine, " CcuEngine.CEU.mboxFetchCpl: WRITE_CQC command! regs_mod %d mb 0x%lx\n", regs.modifier,  (uintptr_t)mboxBuf);
        cqcModule.cqcCache.rescWrite(regs.modifier, (CqcResc *)mboxBuf);
        break;
      case SET_GROUP:
        HANGU_PRINT(CcuEngine, " CcuEngine.CEU.mboxFetchCpl: SET_GROUP command!\n");
        GroupInfo* groupInfo;
        for (int i = 0; i < regs.outParam._data; ++i) {
            groupInfo = (GroupInfo *)mboxBuf + i;
            descScheduler.groupTable[groupInfo->groupID] = groupInfo->granularity;
        }
        delete mboxBuf;
        break;
      case ALLOC_GROUP: // do nothing for ALLOC_GROUP in hardware
        break;
      default:
        panic("Bad inputed command: %d\n", regs.cmdCtrl.op());
    }
    regs.cmdCtrl.go(0); // Set command indicator as finished.

    HANGU_PRINT(CcuEngine, " CcuEngine.CEU.mboxFetchCpl: `GO` bit is down!\n");

    // delete[] mboxBuf;
}

void
HanGuRnic::ceuProc () {
    
    HANGU_PRINT(CcuEngine, " CcuEngine.ceuProc!\n");

    int size;
    switch (regs.cmdCtrl.op()) {
      case INIT_ICM :
        size = sizeof(InitResc); // MBOX_INIT_SZ;
        mboxBuf = (uint8_t *)new InitResc;
        HANGU_PRINT(CcuEngine, " CcuEngine.ceuProc: INIT_ICM command!\n");
        break;
      case WRITE_ICM:
        HANGU_PRINT(CcuEngine, " CcuEngine.ceuProc: WRITE_ICM command!\n");
        size = regs.modifier * sizeof(IcmResc); // regs.modifier * MBOX_ICM_ENTRY_SZ;
        mboxBuf = (uint8_t *)new IcmResc[regs.modifier];
        break;
      case WRITE_MPT:
        HANGU_PRINT(CcuEngine, " CcuEngine.ceuProc: WRITE_MPT command!\n");
        size = regs.outParam._data * sizeof(MptResc);
        mboxBuf = (uint8_t *)new MptResc[regs.outParam._data];
        break;
      case WRITE_MTT:
        HANGU_PRINT(CcuEngine, " CcuEngine.ceuProc: WRITE_MTT command!\n");
        size = regs.outParam._data * sizeof(MttResc);
        mboxBuf = (uint8_t *)new MttResc[regs.outParam._data];
        break;
      case WRITE_QPC:
        HANGU_PRINT(CcuEngine, " CcuEngine.ceuProc: WRITE_QPC command! batch_size %ld\n", regs.outParam._data);
        size = regs.outParam._data * sizeof(QpcResc);
        mboxBuf = (uint8_t *)new QpcResc[regs.outParam._data];
        break;
      case WRITE_CQC:
        HANGU_PRINT(CcuEngine, " CcuEngine.ceuProc: WRITE_CQC command!\n");
        size = sizeof(CqcResc); // MBOX_CQC_ENTRY_SZ;
        mboxBuf = (uint8_t *)new CqcResc;
        break;
      case SET_GROUP:
        HANGU_PRINT(CcuEngine, " CcuEngine.ceuProc: SET_GROUP command!\n");
        size = regs.outParam._data * sizeof(GroupInfo);
        mboxBuf = (uint8_t *)new GroupInfo[regs.outParam._data];
        break;
      case ALLOC_GROUP:
        HANGU_PRINT(CcuEngine, " CcuEngine.ceuProc: SET_GROUP command!\n");
        size = regs.outParam._data * sizeof(uint8_t);
        mboxBuf = (uint8_t *)new GroupInfo;
        break;
      default:
        size = 0;
        panic("Bad input command.\n");
    }

    assert(size > 0 && size <= (MAILBOX_PAGE_NUM << 12)); /* size should not be zero */

    /* read mailbox through dma engine */
    DmaReqPtr dmaReq = make_shared<DmaReq>(pciToDma(regs.inParam._data), size, 
            &mboxEvent, mboxBuf, 0); /* last param is useless here */
    ccuDmaReadFifo.push(dmaReq);
    if (!dmaEngine.dmaReadEvent.scheduled()) {
        schedule(dmaEngine.dmaReadEvent, curTick() + clockPeriod());
    }

    /* We don't schedule it here, cause it should be 
     * scheduled by DMA Engine. */
    // if (!mboxEvent.scheduled()) { /* Schedule mboxFetchCpl */
    //     schedule(mboxEvent, curTick() + clockPeriod());
    // }
}

/**
 * @brief Doorbell Forwarding Unit
 * Forwarding doorbell to RDMAEngine.DFU.
 * Post QPC read request to read relatived QPC information.
 */
void
HanGuRnic::doorbellProc () {

    HANGU_PRINT(HanGuRnic, " CCU.doorbellProc! db_size %d\n", pio2ccuDbFifo.size());

    /* If there's no valid idx, exit the schedule */
    if (df2ccuIdxFifo.size() == 0) {
        HANGU_PRINT(CcuEngine, " CCU.doorbellProc, If there's no valid idx, exit the schedule\n");
        return;
    }

    /* read doorbell info */
    assert(pio2ccuDbFifo.size());
    DoorbellPtr dbell = pio2ccuDbFifo.front();
    pio2ccuDbFifo.pop();

    /* Push doorbell to doorbell fifo */
    uint8_t idx = df2ccuIdxFifo.front();
    df2ccuIdxFifo.pop();
    doorbellVector[idx] = dbell;
    /* We don't schedule it here, cause it should be 
     * scheduled by Context Module. */
    // if (!rdmaEngine.dfuEvent.scheduled()) { /* Schedule RdmaEngine.dfuProcessing */
    //     schedule(rdmaEngine.dfuEvent, curTick() + clockPeriod());
    // }

    /* Post QP addr request to QpcModule */
    CxtReqRspPtr qpAddrReq = make_shared<CxtReqRsp>(CXT_RREQ_SQ, 
            CXT_CHNL_TX, dbell->qpn, 1, idx); // regs.db.qpn()
    qpAddrReq->txQpcRsp = new QpcResc;
    qpcModule.postQpcReq(qpAddrReq);

    HANGU_PRINT(CcuEngine, " CCU.doorbellProc: db.qpn: 0x%x, df2ccuIdxFifo.size %d idx %d\n", 
            dbell->qpn, df2ccuIdxFifo.size(), idx);

    /* If there still has elem in fifo, schedule myself again */
    if (df2ccuIdxFifo.size() && pio2ccuDbFifo.size()) {
        if (!doorbellProcEvent.scheduled()) {
            schedule(doorbellProcEvent, curTick() + clockPeriod());
        }
    }

    HANGU_PRINT(CcuEngine, " CCU.doorbellProc: out!\n");
}
///////////////////////////// HanGuRnic::CCU relevant {end}//////////////////////////////


///////////////////////////// Ethernet Link Interaction {begin}//////////////////////////////

void
HanGuRnic::ethTxDone() {

    DPRINTF(HanGuRnic, "Enter ethTxDone!\n");
}

bool
HanGuRnic::isMacEqual(uint8_t *devSrcMac, uint8_t *pktDstMac) {
    for (int i = 0; i < ETH_ADDR_LEN; ++i) {
        if (devSrcMac[i] != pktDstMac[i]) {
            return false;
        }
    }
    return true;
}

bool
HanGuRnic::ethRxDelay(EthPacketPtr pkt) {

    HANGU_PRINT(HanGuRnic, " ethRxDelay!\n");
    
    /* dest addr is not local, then abandon it */
    if (isMacEqual(macAddr, pkt->data) == false) {
        return true;
    }

    /* Update statistic */
    rxBytes += pkt->length;
    rxPackets++;

    /* post rx pkt to ethRxPktProc */
    Tick sched = curTick() + LinkDelay;
    ethRxDelayFifo.emplace(pkt, sched);
    if (!ethRxPktProcEvent.scheduled()) {
        schedule(ethRxPktProcEvent, sched);
    }

    HANGU_PRINT(HanGuRnic, " ethRxDelay: out! link delay: %d, ethRxDelayFifo size: %d\n", LinkDelay, ethRxDelayFifo.size());

    return true;
}

void
HanGuRnic::ethRxPktProc() {

    HANGU_PRINT(HanGuRnic, " ethRxPktProc! ethRxDelayFifo size: %d\n", ethRxDelayFifo.size());
    
    /* get pkt from ethRxDelay */
    EthPacketPtr pkt = ethRxDelayFifo.front().first;
    Tick sched = ethRxDelayFifo.front().second;
    ethRxDelayFifo.pop();

    /* Only used for debugging */
    BTH *bth = (BTH *)(pkt->data + ETH_ADDR_LEN * 2);
    uint8_t type = (bth->op_destQpn >> 24) & 0x1f;
    uint8_t srv  = bth->op_destQpn >> 29;
    if (srv == QP_TYPE_RC) {
        if (type == PKT_TRANS_SEND_ONLY) {
            HANGU_PRINT(HanGuRnic, " ethRxPktProc: Receiving packet from wire, SEND_ONLY RC, data: %s.\n", 
                    (char *)(pkt->data + 8));
        } else if (type == PKT_TRANS_RWRITE_ONLY) {
            RETH *reth = (RETH *)(pkt->data + PKT_BTH_SZ + ETH_ADDR_LEN * 2);
            HANGU_PRINT(HanGuRnic, " ethRxPktProc:"
                    " Receiving packet from wire, RDMA Write data: %s, len %d, raddr 0x%x, rkey 0x%x op_destQpn 0x%x\n", 
                    (char *)(pkt->data + sizeof(BTH) + sizeof(RETH) + ETH_ADDR_LEN * 2), reth->len, reth->rVaddr_l, reth->rKey, ((BTH *)(pkt->data + ETH_ADDR_LEN * 2))->op_destQpn);
            // for (int i = 0; i < reth->len; ++i) {
            //     HANGU_PRINT(HanGuRnic, " ethRxPkt: data[%d] 0x%x\n", i, (pkt->data)[sizeof(BTH) + sizeof(RETH) + ETH_ADDR_LEN * 2 + i]);
            // }

        } else if (type == PKT_TRANS_RREAD_ONLY) {
            
        } else if (type == PKT_TRANS_ACK) {
            HANGU_PRINT(HanGuRnic, " ethRxPktProc: Receiving packet from wire, Trans ACK needAck_psn: 0x%x\n", ((BTH *)pkt->data)->needAck_psn);
        }
    } else if (srv == QP_TYPE_UD) {
        if (type == PKT_TRANS_SEND_ONLY) {
            
            uint8_t *u8_tmp = (pkt->data + 16 + ETH_ADDR_LEN * 2);
            HANGU_PRINT(HanGuRnic, " ethRxPktProc: Receiving packet from wire, SEND UD data\n");
            HANGU_PRINT(HanGuRnic, " ethRxPktProc: data: 0x%x 0x%x 0x%x 0x%x 0x%x 0x%x 0x%x 0x%x.\n", 
                    u8_tmp[0], u8_tmp[1], u8_tmp[2], u8_tmp[3], u8_tmp[4], u8_tmp[5], u8_tmp[6], u8_tmp[7]);
            HANGU_PRINT(HanGuRnic, " ethRxPktProc: data: 0x%x 0x%x 0x%x 0x%x 0x%x 0x%x 0x%x 0x%x.\n", 
                    u8_tmp[8], u8_tmp[9], u8_tmp[10], u8_tmp[11], u8_tmp[12], u8_tmp[13], u8_tmp[14], u8_tmp[15]);
        }
    }
    HANGU_PRINT(HanGuRnic, " ethRxPktProc: Receiving packet from wire, trans_type: 0x%x, srv: 0x%x.\n", type, srv);
    
    /* Schedule RAU for pkt receiving */
    rxFifo.push(pkt);
    if (!rdmaEngine.rauEvent.scheduled()) {
        schedule(rdmaEngine.rauEvent, curTick() + clockPeriod());
    }

    /* Schedule myself if there is element in ethRxDelayFifo */
    if (ethRxDelayFifo.size()) {
        sched = ethRxDelayFifo.front().second;
        if (!ethRxPktProcEvent.scheduled()) {
            schedule(ethRxPktProcEvent, sched);
        }
    }

    HANGU_PRINT(HanGuRnic, " ethRxPktProc: out!\n");
}

///////////////////////////// Ethernet Link Interaction {end}//////////////////////////////


DrainState
HanGuRnic::drain() {
    
    DPRINTF(HanGuRnic, "HanGuRnic not drained\n");
    return DrainState::Draining;
}

void
HanGuRnic::drainResume() {
    Drainable::drainResume();

    DPRINTF(HanGuRnic, "resuming from drain");
}

void
HanGuRnic::serialize(CheckpointOut &cp) const {
    PciDevice::serialize(cp);

    regs.serialize(cp);

    DPRINTF(HanGuRnic, "Get into HanGuRnic serialize.\n");
}

void
HanGuRnic::unserialize(CheckpointIn &cp) {
    PciDevice::unserialize(cp);

    regs.unserialize(cp);

    DPRINTF(HanGuRnic, "Get into HanGuRnic unserialize.\n");
}

HanGuRnic *
HanGuRnicParams::create() {
    return new HanGuRnic(this);
}
