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
 *      <kangning18z@ict.ac.cn>
 *  Date : 2021.07.08
 */

#include "dev/rdma/hangu_driver.hh"



HanGuDriver::HanGuDriver(Params *p)
  : EmulatedDriver(p), device(p->device) {
    // HANGU_PRINT(HanGuDriver, "HanGu RNIC driver.\n");
}

/**
 * Create an FD entry for the KFD inside of the owning process.
 */
int
HanGuDriver::open(ThreadContext *tc, int mode, int flags) {
    
    HANGU_PRINT(HanGuDriver, "open : %s.\n", filename);

    auto process = tc->getProcessPtr();
    auto device_fd_entry = std::make_shared<DeviceFDEntry>(this, filename);
    int tgt_fd = process->fds->allocFD(device_fd_entry);
    cpu_id = tc->contextId();

    // Configure PCI config space
    configDevice();

    return tgt_fd;
}

void
HanGuDriver::configDevice() {
    
}

/**
 * Currently, mmap() will simply setup a mapping for the associated
 * rnic's send doorbells.
 */
Addr
HanGuDriver::mmap(ThreadContext *tc, Addr start, uint64_t length, int prot,
                int tgt_flags, int tgt_fd, int offset) {
    HANGU_PRINT(HanGuDriver, " rnic hangu_rnic doorbell mmap (start: %p, length: 0x%x,"
            "offset: 0x%x) cxt_id %d\n", start, length, offset, tc->contextId());

    auto process = tc->getProcessPtr();
    auto mem_state = process->memState;

    // Extend global mmap region if necessary.
    if (start == 0) {
        // Assume mmap grows down, as in x86 Linux.
        start = mem_state->getMmapEnd() - length;
        mem_state->setMmapEnd(start);
    }
    
    /**
     * Now map this virtual address to our PIO doorbell interface
     * in the page tables (non-cacheable).
     */
    AddrRangeList addrList = device->getAddrRanges();
    HANGU_PRINT(HanGuDriver, " addrList size %d\n", addrList.size());
    AddrRange baseAddrBar0 = addrList.front();
    HANGU_PRINT(HanGuDriver, " baseAddrBar0.start 0x%x, baseAddrBar0.size() 0x%x\n", baseAddrBar0.start(), baseAddrBar0.size());
    process->pTable->map(start, baseAddrBar0.start(), 64, false); // Actually, 36 is enough
    HANGU_PRINT(HanGuDriver, " rnic hangu_rnic doorbell mapped to 0x%x\n", start);
    hcrAddr = start;
    return start + 24;
}

int
HanGuDriver::ioctl(ThreadContext *tc, unsigned req, Addr ioc_buf) {
    auto &virt_proxy = tc->getVirtProxy();

    if (HGKFD_IOC_GET_TIME == req) {
        HANGU_PRINT(HanGuDriver, " ioctl: HGKFD_IOC_GET_TIME %ld\n", curTick());

        /* Get && copy current time */
        TypedBufferArg<kfd_ioctl_get_time_args> args(ioc_buf);
        args->cur_time = curTick();
        args.copyOut(virt_proxy);

        return 0;
    } else if (checkHcr(virt_proxy)) {
        HANGU_PRINT(HanGuDriver, " `GO` bit is still high! Try again later.\n");
        return -1;
    }
    
    Addr pAddr;
    auto process = tc->getProcessPtr();
    process->pTable->translate(ioc_buf, pAddr);

    switch (req) {
      case HGKFD_IOC_INIT_DEV: // Input
        {   
            HANGU_PRINT(HanGuDriver, " ioctl : HGKFD_IOC_INIT_DEV.\n");
            
            TypedBufferArg<kfd_ioctl_init_dev_args> args(ioc_buf);
            args.copyIn(virt_proxy);

            initMailbox(process);
            HANGU_PRINT(HanGuDriver, " HGKFD_IOC_INIT_DEV mailbox initialized\n");
            
            // We don't use input parameter here
            initIcm(virt_proxy, RESC_LEN_LOG, RESC_LEN_LOG, RESC_LEN_LOG, RESC_LEN_LOG);
            initQoS(virt_proxy, process);
        }
        break;
      case HGKFD_IOC_ALLOC_MTT: // Input Output
        {   
            HANGU_PRINT(HanGuDriver, " ioctl : HGKFD_IOC_ALLOC_MTT.\n");
            
            TypedBufferArg<kfd_ioctl_init_mtt_args> args(ioc_buf);
            args.copyIn(virt_proxy);
            
            allocMtt(process, args);
            HANGU_PRINT(HanGuDriver, " HGKFD_IOC_ALLOC_MTT mtt allocated\n");
            
            uint32_t last_mtt_index = (args->mtt_index + args->batch_size - 1);
            if (!isIcmMapped(mttMeta, last_mtt_index)) { /* last mtt index in this allocation */
                HANGU_PRINT(HanGuDriver, " HGKFD_IOC_ALLOC_MTT mtt not mapped\n");
                Addr icmVPage = allocIcm (process, mttMeta, args->mtt_index);
                writeIcm(virt_proxy, HanGuRnicDef::ICMTYPE_MTT, mttMeta, icmVPage);
                HANGU_PRINT(HanGuDriver, " HGKFD_IOC_ALLOC_MTT mtt ICM mapping is written\n");
            }

            args.copyOut(virt_proxy);
        }
        break;
      case HGKFD_IOC_WRITE_MTT: // Input
        {   
            HANGU_PRINT(HanGuDriver, " ioctl : HGKFD_IOC_WRITE_MTT.\n");
            
            TypedBufferArg<kfd_ioctl_init_mtt_args> args(ioc_buf);
            args.copyIn(virt_proxy);

            writeMtt(virt_proxy, args);
        }
        break;
      case HGKFD_IOC_ALLOC_MPT: // Output
        {   
            TypedBufferArg<kfd_ioctl_alloc_mpt_args> args(ioc_buf);
            args.copyIn(virt_proxy);
            HANGU_PRINT(HanGuDriver, " ioctl : HGKFD_IOC_ALLOC_MPT. batch_size %d\n", args->batch_size);

            allocMpt(process, args);

            HANGU_PRINT(HanGuDriver, " get into ioctl HGKFD_IOC_ALLOC_MPT: mpt_start_index: %d\n", args->mpt_index);
            if (!isIcmMapped(mptMeta, args->mpt_index + args->batch_size - 1)) {
                Addr icmVPage = allocIcm(process, mptMeta, args->mpt_index);
                writeIcm(virt_proxy, HanGuRnicDef::ICMTYPE_MPT, mptMeta, icmVPage);
            }

            args.copyOut(virt_proxy);
        }
        break;
      case HGKFD_IOC_WRITE_MPT: // Input
        {   
            HANGU_PRINT(HanGuDriver, " ioctl : HGKFD_IOC_WRITE_MPT.\n");

            TypedBufferArg<kfd_ioctl_write_mpt_args> args(ioc_buf);
            args.copyIn(virt_proxy);

            writeMpt(virt_proxy, args);
        }
        break;
      case HGKFD_IOC_ALLOC_CQ: // Output
        {   
            HANGU_PRINT(HanGuDriver, " ioctl : HGKFD_IOC_ALLOC_CQ.\n");

            TypedBufferArg<kfd_ioctl_alloc_cq_args> args(ioc_buf);
            
            allocCqc(args);

            if (!isIcmMapped(cqcMeta, args->cq_num)) {
                Addr icmVPage = allocIcm (process, cqcMeta, args->cq_num);
                writeIcm(virt_proxy, HanGuRnicDef::ICMTYPE_CQC, cqcMeta, icmVPage);
            }

            args.copyOut(virt_proxy);
        }
        break;
      case HGKFD_IOC_WRITE_CQC: // Input
        {   
            HANGU_PRINT(HanGuDriver, " ioctl : HGKFD_IOC_WRITE_CQC.\n");

            TypedBufferArg<kfd_ioctl_write_cqc_args> args(ioc_buf);
            args.copyIn(virt_proxy);

            writeCqc(virt_proxy, args);
        }
        break;
      case HGKFD_IOC_ALLOC_QP: // Output
        {   
            HANGU_PRINT(HanGuDriver, " ioctl : HGKFD_IOC_ALLOC_QP.\n");

            TypedBufferArg<kfd_ioctl_alloc_qp_args> args(ioc_buf);
            args.copyIn(virt_proxy);

            allocQpc(args);

            updateN(virt_proxy, args);

            // allocate space for QP context
            if (!isIcmMapped(qpcMeta, args->qp_num + args->batch_size - 1)) {
                Addr icmVPage = allocIcm (process, qpcMeta, args->qp_num);
                writeIcm(virt_proxy, HanGuRnicDef::ICMTYPE_QPC, qpcMeta, icmVPage);
            }

            HANGU_PRINT(HanGuDriver, " ioctl : HGKFD_IOC_ALLOC_QP, qp_num: 0x%x(%d), batch_size %d\n", args->qp_num, RESC_LIM_MASK&args->qp_num, args->batch_size);

            args.copyOut(virt_proxy);
        }
        break;
      case HGKFD_IOC_WRITE_QPC: // Input
        {   
            HANGU_PRINT(HanGuDriver, " ioctl : HGKFD_IOC_WRITE_QPC\n");

            // copy from user space to kernel space
            TypedBufferArg<kfd_ioctl_write_qpc_args> args(ioc_buf);
            args.copyIn(virt_proxy);

            writeQpc(virt_proxy, args);
        }
        break;
      case HGKFD_IOC_CHECK_GO: 
        {   
            /* We don't check `go` bit here, cause it 
             * has been checked at the beginning of ioctl. */
            // HANGU_PRINT(HanGuDriver, " ioctl : HGKFD_IOC_CHECK_GO, `GO` is cleared.\n");
        }
        break;
        case HGKFD_IOC_SET_GROUP:
        {
            HANGU_PRINT(HanGuDriver, "ioctl: HGKFD_IOC_SET_GROUP\n");
            TypedBufferArg<kfd_ioctl_set_group_args> args(ioc_buf);
            args.copyIn(virt_proxy);
            setGroup(virt_proxy, args);
            args.copyOut(virt_proxy);
        }
        break;
        case HGKFD_IOC_ALLOC_GROUP:
        {
            HANGU_PRINT(HanGuDriver, "ioctl: HGKFD_IOC_ALLOC_GROUP\n");
            TypedBufferArg<kfd_ioctl_alloc_group_args> args(ioc_buf);
            args.copyIn(virt_proxy);
            allocGroup(virt_proxy, args);
            args.copyOut(virt_proxy);
        }
        break;
        case HGKFD_IOC_UPDATE_QP_WEIGHT:
        {
            HANGU_PRINT(HanGuDriver, "ioctl: HGKFD_IOC_UPDATE_QP_WEIGHT\n");
            TypedBufferArg<kfd_ioctl_write_qpc_args> args(ioc_buf);
            args.copyIn(virt_proxy);
            updateQpWeight(virt_proxy, args);
        }
        break;
        default:
        {
            fatal("%s: bad ioctl %d\n", req);
        }
        break;
    }
    return 0;
}

/* -------------------------- HCR {begin} ------------------------ */

uint8_t 
HanGuDriver::checkHcr(PortProxy& portProxy) {

    uint32_t goOp;
    // HANGU_PRINT(HanGuDriver, " Start read `GO`.\n");
    portProxy.readBlob(hcrAddr + (Addr)&(((HanGuRnicDef::Hcr*)0)->goOpcode), &goOp, sizeof(goOp));

    
    if ((goOp >> 31) == 1) {
        // HANGU_PRINT(HanGuDriver, " `GO` is still high\n");
        return 1;
    }
    // HANGU_PRINT(HanGuDriver, " `GO` is cleared.\n");
    return 0;
}

void 
HanGuDriver::postHcr(PortProxy& portProxy, uint64_t inParam, 
        uint32_t inMod, uint64_t outParam, uint8_t opcode) {
    
    HanGuRnicDef::Hcr hcr;

    HANGU_PRINT(HanGuDriver, " Start Write hcr\n");

    hcr.inParam_l  = inParam & 0xffffffff;
    hcr.inParam_h  = inParam >> 32;
    hcr.inMod      = inMod;
    hcr.outParam_l = outParam & 0xffffffff;
    hcr.outParam_h = outParam >> 32;
    hcr.goOpcode   = (1 << 31) | opcode;
    // HANGU_PRINT(HanGuDriver, " inParam_l: 0x%x\n", hcr.inParam_l);
    // HANGU_PRINT(HanGuDriver, " inParam_h: 0x%x\n", hcr.inParam_h);
    // HANGU_PRINT(HanGuDriver, " inMod: 0x%x\n", hcr.inMod);
    // HANGU_PRINT(HanGuDriver, " outParam_l: 0x%x\n", hcr.outParam_l);
    // HANGU_PRINT(HanGuDriver, " outParam_h: 0x%x\n", hcr.outParam_h);
    // HANGU_PRINT(HanGuDriver, " goOpcode: 0x%x\n", hcr.goOpcode);

    portProxy.writeBlob(hcrAddr, &hcr, sizeof(hcr));
}

/* -------------------------- HCR {end} ------------------------ */


/* -------------------------- ICM {begin} ------------------------ */

void 
HanGuDriver::initIcm(PortProxy& portProxy, uint8_t qpcNumLog, uint8_t cqcNumLog, 
        uint8_t mptNumLog, uint8_t mttNumLog) {

    Addr startPtr = 0;
    
    mttMeta.start     = startPtr;
    mttMeta.size      = ((1 << mttNumLog) * sizeof(HanGuRnicDef::MttResc));
    mttMeta.entrySize = sizeof(HanGuRnicDef::MttResc);
    mttMeta.entryNumLog = mttNumLog;
    mttMeta.entryNumPage= (1 << (mttNumLog-(12-3)));
    mttMeta.bitmap    = new uint8_t[mttMeta.entryNumPage];
    memset(mttMeta.bitmap, 0, mttMeta.entryNumPage);
    startPtr += mttMeta.size;
    HANGU_PRINT(HanGuDriver, " mttMeta.entryNumPage 0x%x\n", mttMeta.entryNumPage);

    mptMeta.start = startPtr;
    mptMeta.size  = ((1 << mptNumLog) * sizeof(HanGuRnicDef::MptResc));
    mptMeta.entrySize = sizeof(HanGuRnicDef::MptResc);
    mptMeta.entryNumLog = mptNumLog;
    mptMeta.entryNumPage = (1 << (mptNumLog-(12-5)));
    mptMeta.bitmap = new uint8_t[mptMeta.entryNumPage];
    memset(mptMeta.bitmap, 0, mptMeta.entryNumPage);
    startPtr += mptMeta.size;
    HANGU_PRINT(HanGuDriver, " mptMeta.entryNumPage 0x%x\n", mptMeta.entryNumPage);

    cqcMeta.start = startPtr;
    cqcMeta.size  = ((1 << cqcNumLog) * sizeof(HanGuRnicDef::CqcResc));
    cqcMeta.entrySize = sizeof(HanGuRnicDef::CqcResc);
    cqcMeta.entryNumLog = cqcNumLog;
    cqcMeta.entryNumPage = (1 << (cqcNumLog-(12-4)));
    cqcMeta.bitmap = new uint8_t[cqcMeta.entryNumPage];
    memset(cqcMeta.bitmap, 0, cqcMeta.entryNumPage);
    startPtr += cqcMeta.size;
    HANGU_PRINT(HanGuDriver, " cqcMeta.entryNumPage 0x%x\n", cqcMeta.entryNumPage);

    qpcMeta.start = startPtr;
    qpcMeta.size  = ((1 << qpcNumLog) * sizeof(HanGuRnicDef::QpcResc));
    qpcMeta.entrySize   = sizeof(HanGuRnicDef::QpcResc);
    qpcMeta.entryNumLog = qpcNumLog;
    qpcMeta.entryNumPage = (1 << (qpcNumLog-(12-8)));
    qpcMeta.bitmap = new uint8_t[qpcMeta.entryNumPage];
    memset(qpcMeta.bitmap, 0, qpcMeta.entryNumPage);
    HANGU_PRINT(HanGuDriver, " qpcMeta.entryNumPage 0x%x\n", qpcMeta.entryNumPage);
    
    startPtr += qpcMeta.size;

    /* put initResc into mailbox */
    HanGuRnicDef::InitResc initResc;
    initResc.qpcBase   = qpcMeta.start;
    initResc.qpsNumLog = qpcNumLog;
    initResc.cqcBase   = cqcMeta.start;
    initResc.cqsNumLog = cqcNumLog;
    initResc.mptBase   = mptMeta.start;
    initResc.mptNumLog = mptNumLog;
    initResc.mttBase   = mttMeta.start;
    // HANGU_PRINT(HanGuDriver, " qpcMeta.start: 0x%lx, cqcMeta.start : 0x%lx, mptMeta.start : 0x%lx, mttMeta.start : 0x%lx\n", 
    //         qpcMeta.start, cqcMeta.start, mptMeta.start, mttMeta.start);
    portProxy.writeBlob(mailbox.vaddr, &initResc, sizeof(HanGuRnicDef::InitResc));

    postHcr(portProxy, (uint64_t)mailbox.paddr, 0, 0, HanGuRnicDef::INIT_ICM);
}


uint8_t 
HanGuDriver::isIcmMapped(RescMeta &rescMeta, Addr index) {
    
    Addr icmVPage = (rescMeta.start + index * rescMeta.entrySize) >> 12;
    
    return (icmAddrmap.find(icmVPage) != icmAddrmap.end());
}

Addr 
HanGuDriver::allocIcm(Process *process, RescMeta &rescMeta, Addr index) {
    Addr icmVPage = (rescMeta.start + index * rescMeta.entrySize) >> 12;
    while (icmAddrmap.find(icmVPage) != icmAddrmap.end()) { /* cause we allocate multiply resources one time, 
                                                             * the resources may be cross-page. */
        ++icmVPage;
    }
    HANGU_PRINT(HanGuDriver, " rescMeta.start: 0x%lx, index 0x%x, entrySize %d icmVPage 0x%lx\n", rescMeta.start, index, rescMeta.entrySize, icmVPage);
    for (uint32_t i =  0; i < ICM_ALLOC_PAGE_NUM; ++i) {
        if (i == 0) {
            icmAddrmap[icmVPage] = process->system->allocPhysPages(ICM_ALLOC_PAGE_NUM);
        } else {
            icmAddrmap[icmVPage + i] = icmAddrmap[icmVPage] + (i << 12);
        }
        HANGU_PRINT(HanGuDriver, " icmAddrmap[0x%x(%d)]: 0x%lx\n", icmVPage+i, i, icmAddrmap[icmVPage+i]);
    }
    return icmVPage;
}

/**
 * @note write ICM address translation into RNIC
*/
void
HanGuDriver::writeIcm(PortProxy& portProxy, uint8_t rescType, RescMeta &rescMeta, Addr icmVPage) {

    // put IcmResc into mailbox
    HanGuRnicDef::IcmResc icmResc;
    icmResc.pageNum = ICM_ALLOC_PAGE_NUM; // now we support ICM_ALLOC_PAGE_NUM pages
    icmResc.vAddr   = icmVPage << 12;
    icmResc.pAddr   = icmAddrmap[icmVPage];
    portProxy.writeBlob(mailbox.vaddr, &icmResc, sizeof(HanGuRnicDef::InitResc));
    HANGU_PRINT(HanGuDriver, " pageNum %d, vAddr 0x%lx, pAddr 0x%lx\n", icmResc.pageNum, icmResc.vAddr, icmResc.pAddr);

    postHcr(portProxy, (uint64_t)mailbox.paddr, 1, rescType, HanGuRnicDef::WRITE_ICM);
}

/* -------------------------- ICM {end} ------------------------ */

/* -------------------------- Group {begin}----------------------- */
/**
 * @note set group weight, update all group granularities, make sure all weight related parameters are correct
*/
void HanGuDriver::initQoS(PortProxy& portProxy, Process* process)
{
    // allocate shared memory for QoS
    Addr sharePhysAddr;
    portProxy.readBlob(hcrAddr + barShareAddrOffset, &sharePhysAddr, sizeof(Addr));
    if (sharePhysAddr == 0)
    {
        sharePhysAddr = process->system->allocPhysPages(qosSharePageNum);
        portProxy.writeBlob(hcrAddr + barShareAddrOffset, &sharePhysAddr, sizeof(Addr));
        HANGU_PRINT(HanGuDriver, "physical qosShareAddr set into BAR0: 0x%x\n", sharePhysAddr);

        // Assume mmap grows down, as in x86 Linux.
        auto mem_state = process->memState;
        qosShareParamAddr = mem_state->getMmapEnd() - (qosSharePageNum << 12);
        mem_state->setMmapEnd(qosShareParamAddr);
        process->pTable->map(qosShareParamAddr, sharePhysAddr, (qosSharePageNum << 12), false);
        // uint32_t N = BIGN;
        // portProxy.writeBlob(qosShareParamAddr + NOffset, &N, sizeof(uint32_t));
        uint16_t groupNum = 0;
        portProxy.writeBlob(qosShareParamAddr + groupNumOffset, &groupNum, sizeof(uint16_t));
        uint64_t qpNum = 0;
        portProxy.writeBlob(qosShareParamAddr + qpAmountOffset, &qpNum, sizeof(uint64_t));
    }
    else
    {
        HANGU_PRINT(HanGuDriver, "physical qosShareAddr already set: 0x%x\n", sharePhysAddr);
        // Assume mmap grows down, as in x86 Linux.
        auto mem_state = process->memState;
        qosShareParamAddr = mem_state->getMmapEnd() - (qosSharePageNum << 12);
        mem_state->setMmapEnd(qosShareParamAddr);
        process->pTable->map(qosShareParamAddr, sharePhysAddr, (qosSharePageNum << 12), false);
    }
}

void HanGuDriver::setGroup(PortProxy& portProxy, TypedBufferArg<kfd_ioctl_set_group_args> &args)
{
    HanGuRnicDef::GroupInfo group[MAX_GROUP_NUM];

    uint32_t bigN;
    portProxy.readBlob(qosShareParamAddr + NOffset, &bigN, sizeof(uint32_t));

    uint8_t groupNum;
    portProxy.readBlob(qosShareParamAddr + groupNumOffset, &groupNum, sizeof(uint8_t));

    HANGU_PRINT(HanGuDriver, "into setGroup command in driver! group num: %d, table size: %d\n", groupNum, groupTable.size());

    // update group weight
    for (int i = 0; i < args->group_num; i++)
    {
        portProxy.writeBlob(qosShareParamAddr + groupWeightOffset + args->group_id[i] * 1, &(args->weight[i]), sizeof(uint8_t));
        HANGU_PRINT(HanGuDriver, "write group weight to shared space, group id: %d, weight: %d\n", i, args->weight[i]);
    }

    // calculate group weight sum
    uint32_t groupWeightSum = 0;
    uint8_t tempWeight;
    for (int i = 0; i < groupNum; i++)
    {
        portProxy.readBlob(qosShareParamAddr + groupWeightOffset + i * 1, &tempWeight, sizeof(uint8_t));
        groupWeightSum += tempWeight;
    }
    portProxy.writeBlob(qosShareParamAddr + groupWeightSumOffset, &groupWeightSum, sizeof(uint32_t));
    HANGU_PRINT(HanGuDriver, "write group weight sum to shared space: %d\n", groupWeightSum);

    for (int i = 0; i < groupNum; i++)
    {
        uint8_t groupWeight;
        uint32_t qpWeightSum;
        uint32_t granularity;
        portProxy.readBlob(qosShareParamAddr + groupWeightOffset + i * 1, &groupWeight, sizeof(uint8_t));
        portProxy.readBlob(qosShareParamAddr + groupQPWeightSumOffset + i * 4, &qpWeightSum, sizeof(uint32_t));
        granularity = (double)groupWeight / groupWeightSum * bigN / qpWeightSum;
        portProxy.writeBlob(qosShareParamAddr + groupGranularityOffset + i * 4, &granularity, sizeof(uint32_t));
        group[i].groupID = i;
        group[i].granularity = granularity;
        HANGU_PRINT(HanGuDriver, "set group granularity! N: %d, group id: %d, group weight: %d, QP weight sum: %d, granularity: %d\n", 
            bigN, i, groupWeight, qpWeightSum, granularity);
    }
    // print all QoS weights and granularities
    printQoS(portProxy);
    portProxy.writeBlob(mailbox.vaddr, group, sizeof(HanGuRnicDef::GroupInfo) * groupNum);
    postHcr(portProxy, (uint64_t)mailbox.paddr, 1, groupNum, HanGuRnicDef::SET_GROUP);
}

void HanGuDriver::printQoS(PortProxy& portProxy)
{
    uint8_t groupNum;
    portProxy.readBlob(qosShareParamAddr + groupNumOffset, &groupNum, sizeof(uint8_t));
    HANGU_PRINT(HanGuDriver, "---------------------------\n");
    HANGU_PRINT(HanGuDriver, "print QoS info! group num: %d\n", groupNum);
    for (int i = 0; i < groupNum; i++)
    {
        uint8_t groupWeight;
        portProxy.readBlob(qosShareParamAddr + groupWeightOffset + i * 1, &groupWeight, sizeof(uint8_t));
        uint32_t granularity;
        portProxy.readBlob(qosShareParamAddr + groupGranularityOffset + i * 4, &granularity, sizeof(uint32_t));
        uint32_t qpWeightSum;
        portProxy.readBlob(qosShareParamAddr + groupQPWeightSumOffset + i * 4, &qpWeightSum, sizeof(uint32_t));
        HANGU_PRINT(HanGuDriver, "group[%d] info! group weight: %d, QP weight sum: %d, granularity: %d\n", 
            i, groupWeight, qpWeightSum, granularity);
    }
    HANGU_PRINT(HanGuDriver, "---------------------------\n");
}

/**
 * @note hardware related function, create entries in group granularity table
*/
void HanGuDriver::allocGroup(PortProxy& portProxy, TypedBufferArg<kfd_ioctl_alloc_group_args> &args)
{
    uint8_t groupNum;
    portProxy.readBlob(qosShareParamAddr + groupNumOffset, &groupNum, sizeof(uint8_t));
    // HANGU_PRINT(HanGuDriver, "into allocGroup! groupNum: %d, args->group_num: %d\n", groupNum, args->group_num);
    postHcr(portProxy, (uint64_t)mailbox.paddr, 1, args->group_num, HanGuRnicDef::ALLOC_GROUP);
    assert(args->group_num == 1);
    args->group_id[0] = groupNum;
    groupNum += args->group_num;
    portProxy.writeBlob(qosShareParamAddr + groupNumOffset, &groupNum, sizeof(uint8_t));
    HANGU_PRINT(HanGuDriver, "group allocated! group ID: %d, groupNum: %d\n", args->group_id[0], groupNum);
}

void HanGuDriver::updateN(PortProxy& portProxy, TypedBufferArg<kfd_ioctl_alloc_qp_args> &args)
{
    // qpAmount += args->batch_size;
    // update QP amount
    uint64_t qpAmount;
    portProxy.readBlob(qosShareParamAddr + qpAmountOffset, &qpAmount, sizeof(uint64_t));
    HANGU_PRINT(HanGuDriver, "QP amount get! qp amount: %d\n", qpAmount);
    qpAmount += args->batch_size;
    portProxy.writeBlob(qosShareParamAddr + qpAmountOffset, &qpAmount, sizeof(uint64_t));
    HANGU_PRINT(HanGuDriver, "QP amount set! qp amount: %d\n", qpAmount);
    uint32_t bigN = qpAmount * chunkSizePerQP;
    portProxy.writeBlob(qosShareParamAddr + NOffset, &bigN, sizeof(uint32_t));
    HANGU_PRINT(HanGuDriver, "N updated! N: %d\n", bigN);
}

/**
 * @note update several groups in case that some QPs change their weight
*/
void HanGuDriver::updateQpWeight(PortProxy& portProxy, TypedBufferArg<kfd_ioctl_write_qpc_args> &args)
{
    /* put QpcResc into mailbox */
    HanGuRnicDef::GroupInfo group[MAX_QPC_BATCH];
    memset(group, 0, sizeof(HanGuRnicDef::GroupInfo) * args->batch_size);
    int setGroupNum = 0;
    std::unordered_map<uint8_t, uint8_t> setGroup;
    uint32_t groupWeightSum;
    portProxy.readBlob(qosShareParamAddr + groupWeightSumOffset, &groupWeightSum, sizeof(uint32_t));
    uint32_t bigN;
    portProxy.readBlob(qosShareParamAddr + NOffset, &bigN, sizeof(uint32_t));
    // modify QP weight in group table and record the groups to be updated
    for (uint32_t i = 0; i < args->batch_size; ++i)
    {
        if (groupTable[args->groupID[i]].qpWeight[args->src_qpn[i]] != args->weight[i])
        {
            groupTable[args->groupID[i]].qpWeight[args->src_qpn[i]] = args->weight[i];
            if (setGroup.find(args->groupID[i]) == setGroup.end())
            {
                setGroup[args->groupID[i]] = 1;
                setGroupNum++;
            }
            HANGU_PRINT(HanGuDriver, "update QP weight! qpn: 0x%x, old QP weight: %d, new QP weight: %d, group ID: %d\n", 
                args->src_qpn[i], groupTable[args->groupID[i]].qpWeight[args->src_qpn[i]], args->weight[i], args->groupID[i]);
        }
    }
    assert(args->batch_size > 0);
    if (setGroupNum == 0)
    {
        HANGU_PRINT(HanGuDriver, "setGroupNum is ZERO!\n");
        return;
    }
    assert(setGroup.size() != 0);
    assert(setGroupNum == setGroup.size());
    HANGU_PRINT(HanGuDriver, "into update QP weight! setGroupNum: %d\n", setGroupNum);
    // update group granularity
    int i = 0;
    for (std::unordered_map<uint8_t, uint8_t>::iterator iter = setGroup.begin(); iter != setGroup.end(); iter++) {
        assert(iter->second == 1);
        uint8_t groupID = iter->first;
        // recalculate group granularity
        uint32_t qpWeightSum = 0;
        for (std::unordered_map<uint32_t, uint8_t>::iterator it = groupTable[groupID].qpWeight.begin(); it != groupTable[groupID].qpWeight.end(); it++)
        {
            qpWeightSum += it->second;
        }
        uint8_t groupWeight;
        uint32_t granularity;
        portProxy.readBlob(qosShareParamAddr + groupWeightOffset +  groupID * 1, &groupWeight, sizeof(uint8_t));
        granularity = (double)groupWeight / groupWeightSum * bigN / qpWeightSum;
        group[i].groupID = groupID;
        group[i].granularity = granularity;
        // set new QP weight sum
        portProxy.writeBlob(qosShareParamAddr + groupQPWeightSumOffset + groupID * 4, &qpWeightSum, sizeof(uint32_t));
        // set new granularity
        portProxy.writeBlob(qosShareParamAddr + groupGranularityOffset + groupID * 4, &granularity, sizeof(uint16_t));
        HANGU_PRINT(HanGuDriver, "update granularity when update QP weight! Group ID: %d, group weight: %d, group granularity: %d, big N: %d, group weight sum: %d, qp weight sum: %d\n", 
            groupID, groupWeight, granularity, bigN, groupWeightSum, qpWeightSum);
        i++;
    }
    printQoS(portProxy);
    portProxy.writeBlob(mailbox.vaddr, group, sizeof(HanGuRnicDef::GroupInfo) * setGroupNum);
    postHcr(portProxy, (uint64_t)mailbox.paddr, 1, setGroupNum, HanGuRnicDef::SET_GROUP);
}
/* --------------------------- Group {end}---------------------------- */

/* -------------------------- Resc {begin} ------------------------ */
uint32_t 
HanGuDriver::allocResc(uint8_t rescType, RescMeta &rescMeta) {
    uint32_t i = 0, j = 0;
    uint32_t rescNum = 0;
    while (rescMeta.bitmap[i] == 0xff) {
        ++i;
    }
    rescNum = i * 8;

    while ((rescMeta.bitmap[i] >> j) & 0x01) {
        ++rescNum;
        ++j;
    }
    rescMeta.bitmap[i] |= (1 << j);

    rescNum += (cpu_id << RESC_LIM_LOG);
    return rescNum;
}
/* -------------------------- Resc {end} ------------------------ */

/* -------------------------- MTT {begin} ------------------------ */

void 
HanGuDriver::allocMtt(Process *process, 
        TypedBufferArg<kfd_ioctl_init_mtt_args> &args) {
    for (uint32_t i = 0; i < args->batch_size; ++i) {
        args->mtt_index = allocResc(HanGuRnicDef::ICMTYPE_MTT, mttMeta);
        // HANGU_PRINT(HanGuDriver, " HGKFD_IOC_ALLOC_MTT: mtt_bitmap: %d\n", mttMeta.bitmap[0]);
        // HANGU_PRINT(HanGuDriver, " HGKFD_IOC_ALLOC_MTT: mtt_index: %d\n", args->mtt_index);
        process->pTable->translate((Addr)args->vaddr[i], (Addr &)args->paddr[i]);
        HANGU_PRINT(HanGuDriver, " HGKFD_IOC_ALLOC_MTT: vaddr: 0x%lx, paddr: 0x%lx mtt_index %d\n", 
                (uint64_t)args->vaddr[i], (uint64_t)args->paddr[i], args->mtt_index);
    }
    args->mtt_index -= (args->batch_size - 1);
}

void 
HanGuDriver::writeMtt(PortProxy& portProxy, TypedBufferArg<kfd_ioctl_init_mtt_args> &args) {
    
    // put mttResc into mailbox
    HanGuRnicDef::MttResc mttResc[MAX_MR_BATCH];
    for (uint32_t i = 0; i < args->batch_size; ++i) {
        mttResc[i].pAddr = args->paddr[i];
    }
    portProxy.writeBlob(mailbox.vaddr, mttResc, sizeof(HanGuRnicDef::MttResc) * args->batch_size);

    postHcr(portProxy, (uint64_t)mailbox.paddr, args->mtt_index, args->batch_size, HanGuRnicDef::WRITE_MTT);
}
/* -------------------------- MTT {end} ------------------------ */

/* -------------------------- MPT {begin} ------------------------ */
void 
HanGuDriver::allocMpt(Process *process, 
        TypedBufferArg<kfd_ioctl_alloc_mpt_args> &args) {
    for (uint32_t i = 0; i < args->batch_size; ++i) {
        args->mpt_index = allocResc(HanGuRnicDef::ICMTYPE_MPT, mptMeta);
        HANGU_PRINT(HanGuDriver, " HGKFD_IOC_ALLOC_MPT: mpt_index %d batch_size %d\n", args->mpt_index, args->batch_size);
    }
    args->mpt_index -= (args->batch_size - 1);
}
    
void 
HanGuDriver::writeMpt(PortProxy& portProxy, TypedBufferArg<kfd_ioctl_write_mpt_args> &args) {
    // put MptResc into mailbox
    HanGuRnicDef::MptResc mptResc[MAX_MR_BATCH];
    for (uint32_t i = 0; i < args->batch_size; ++i) {
        mptResc[i].flag       = args->flag     [i];
        mptResc[i].key        = args->mpt_index[i];
        mptResc[i].length     = args->length   [i];
        mptResc[i].startVAddr = args->addr     [i];
        mptResc[i].mttSeg     = args->mtt_index[i];
        HANGU_PRINT(HanGuDriver, " HGKFD_IOC_WRITE_MPT: mpt_index %d(%d) mtt_index %d(%d) batch_size %d\n", 
                args->mpt_index[i], mptResc[i].key, args->mtt_index[i], mptResc[i].mttSeg, args->batch_size);
    }
    portProxy.writeBlob(mailbox.vaddr, mptResc, sizeof(HanGuRnicDef::MptResc) * args->batch_size);

    postHcr(portProxy, (uint64_t)mailbox.paddr, args->mpt_index[0], args->batch_size, HanGuRnicDef::WRITE_MPT);
}
/* -------------------------- MPT {end} ------------------------ */


/* -------------------------- CQC {begin} ------------------------ */
void 
HanGuDriver::allocCqc (TypedBufferArg<kfd_ioctl_alloc_cq_args> &args) {
    args->cq_num = allocResc(HanGuRnicDef::ICMTYPE_CQC, cqcMeta);
}
    
void 
HanGuDriver::writeCqc(PortProxy& portProxy, TypedBufferArg<kfd_ioctl_write_cqc_args> &args) {
    /* put CqcResc into mailbox */
    HanGuRnicDef::CqcResc cqcResc;
    cqcResc.cqn    = args->cq_num  ;
    cqcResc.lkey   = args->lkey    ;
    cqcResc.offset = args->offset  ;
    cqcResc.sizeLog= args->size_log;
    portProxy.writeBlob(mailbox.vaddr, &cqcResc, sizeof(HanGuRnicDef::CqcResc));

    postHcr(portProxy, (uint64_t)mailbox.paddr, args->cq_num, 0, HanGuRnicDef::WRITE_CQC);
}
/* -------------------------- CQC {end} ------------------------ */


/* -------------------------- QPC {begin} ------------------------ */
void 
HanGuDriver::allocQpc(TypedBufferArg<kfd_ioctl_alloc_qp_args> &args) {
    for (uint32_t i = 0; i < args->batch_size; ++i) {
        // HANGU_PRINT(HanGuDriver, " allocQpc: qpc_bitmap: 0x%x 0x%x 0x%x\n", qpcMeta.bitmap[0], qpcMeta.bitmap[1], qpcMeta.bitmap[2]);
        args->qp_num = allocResc(HanGuRnicDef::ICMTYPE_QPC, qpcMeta);
        HANGU_PRINT(HanGuDriver, " allocQpc: qpc_bitmap:  0x%x 0x%x 0x%x 0x%x 0x%x 0x%x 0x%x 0x%x\n"
                                                        " 0x%x 0x%x 0x%x 0x%x 0x%x 0x%x 0x%x 0x%x\n"
                                                        " 0x%x 0x%x 0x%x 0x%x 0x%x 0x%x 0x%x 0x%x\n"
                                                        " 0x%x 0x%x 0x%x 0x%x 0x%x 0x%x 0x%x 0x%x\n", 
                qpcMeta.bitmap[0], qpcMeta.bitmap[1], qpcMeta.bitmap[2], qpcMeta.bitmap[3], qpcMeta.bitmap[4], qpcMeta.bitmap[5], qpcMeta.bitmap[6], qpcMeta.bitmap[7], 
                qpcMeta.bitmap[8], qpcMeta.bitmap[9], qpcMeta.bitmap[10], qpcMeta.bitmap[11], qpcMeta.bitmap[12], qpcMeta.bitmap[13], qpcMeta.bitmap[14], qpcMeta.bitmap[15], 
                qpcMeta.bitmap[16], qpcMeta.bitmap[17], qpcMeta.bitmap[18], qpcMeta.bitmap[19], qpcMeta.bitmap[20], qpcMeta.bitmap[21], qpcMeta.bitmap[22], qpcMeta.bitmap[23], 
                qpcMeta.bitmap[24], qpcMeta.bitmap[25], qpcMeta.bitmap[26], qpcMeta.bitmap[27], qpcMeta.bitmap[28], qpcMeta.bitmap[29], qpcMeta.bitmap[30], qpcMeta.bitmap[31]);
    }
    args->qp_num -= (args->batch_size - 1);
}
    
void 
HanGuDriver::writeQpc(PortProxy& portProxy, TypedBufferArg<kfd_ioctl_write_qpc_args> &args) {
    /* put QpcResc into mailbox */
    HanGuRnicDef::QpcResc qpcResc[MAX_QPC_BATCH]; // = (HanGuRnicDef::QpcResc *)mailbox.vaddr;
    memset(qpcResc, 0, sizeof(HanGuRnicDef::QpcResc) * args->batch_size);
    for (uint32_t i = 0; i < args->batch_size; ++i) {
        qpcResc[i].flag           = args->flag             [i];
        qpcResc[i].qpType         = args->type             [i];
        qpcResc[i].srcQpn         = args->src_qpn          [i];
        qpcResc[i].lLid           = args->llid             [i];
        qpcResc[i].cqn            = args->cq_num           [i];
        qpcResc[i].sndWqeBaseLkey = args->snd_wqe_base_lkey[i];
        qpcResc[i].sndWqeOffset   = args->snd_wqe_offset   [i];
        qpcResc[i].sqSizeLog      = args->sq_size_log      [i];
        qpcResc[i].rcvWqeBaseLkey = args->rcv_wqe_base_lkey[i];
        qpcResc[i].rcvWqeOffset   = args->rcv_wqe_offset   [i];
        qpcResc[i].rqSizeLog      = args->rq_size_log      [i];

        qpcResc[i].ackPsn  = args->ack_psn [i];
        qpcResc[i].sndPsn  = args->snd_psn [i];
        qpcResc[i].expPsn  = args->exp_psn [i];
        qpcResc[i].dLid    = args->dlid    [i];
        qpcResc[i].destQpn = args->dest_qpn[i];

        qpcResc[i].qkey    = args->qkey[i];

        qpcResc[i].indicator = args->indicator  [i];
        qpcResc[i].perfWeight = args->weight    [i];
        qpcResc[i].groupID = args->groupID      [i];
        HANGU_PRINT(HanGuDriver, " writeQpc: qpn: 0x%x\n", qpcResc[i].srcQpn);
    }

    // update group table
    // for (uint32_t i = 0; i < args->batch_size; ++i) 
    // {
    //     groupTable[args->groupID[i]].qpWeight[args->src_qpn[i]] = args->weight[i];
    //     HANGU_PRINT(HanGuDriver, "update QP weight: qpn: %d, weight: %d, group: %d\n", 
    //         qpcResc[i].srcQpn, qpcResc[i].perfWeight, qpcResc[i].groupID);
    // }


    HANGU_PRINT(HanGuDriver, " writeQpc: args->batch_size: %d\n", args->batch_size);
    portProxy.writeBlob(mailbox.vaddr, qpcResc, sizeof(HanGuRnicDef::QpcResc) * args->batch_size);
    HANGU_PRINT(HanGuDriver, " writeQpc: args->batch_size1: %d\n", args->batch_size);

    postHcr(portProxy, (uint64_t)mailbox.paddr, args->src_qpn[0], args->batch_size, HanGuRnicDef::WRITE_QPC);
}


/* -------------------------- QPC {end} ------------------------ */

/* -------------------------- Mailbox {begin} ------------------------ */
void 
HanGuDriver::initMailbox(Process *process) {

    uint32_t allocPages = MAILBOX_PAGE_NUM;
    
    mailbox.paddr = process->system->allocPhysPages(allocPages);
    
    // Assume mmap grows down, as in x86 Linux.
    auto mem_state = process->memState;
    mailbox.vaddr = mem_state->getMmapEnd() - (allocPages << 12);
    mem_state->setMmapEnd(mailbox.vaddr);
    process->pTable->map(mailbox.vaddr, mailbox.paddr, (allocPages << 12), false);

    HANGU_PRINT(HanGuDriver, " mailbox.vaddr : 0x%x, mailbox.paddr : 0x%x\n", 
            mailbox.vaddr, mailbox.paddr);
}

/* -------------------------- Mailbox {end} ------------------------ */

HanGuDriver*
HanGuDriverParams::create()
{
    return new HanGuDriver(this);
}



