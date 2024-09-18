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
 *  Date: 2021.07.08
 */

/**
 * @file
 * The HanGuDriver implements an RnicDriver for an RDMA NIC
 * agent. 
 */

#ifndef __RDMA_HANGU_DRIVER_HH__
#define __RDMA_HANGU_DRIVER_HH__

#include "hangu_rnic_defs.hh"
#include "dev/rdma/kfd_ioctl.h"
#include "base/time.hh"

#include "dev/rdma/rdma_nic.hh"
#include "debug/HanGu.hh"
#include "params/HanGuDriver.hh"

#include "sim/proxy_ptr.hh"
#include "sim/process.hh"
#include "sim/system.hh"
#include "cpu/thread_context.hh"
#include "sim/syscall_emul_buf.hh"

#include "base/types.hh"
#include "sim/emul_driver.hh"


class RdmaNic;
class PortProxy;
class ThreadContext;

struct HanGuDriverParams;

class HanGuDriver final : public EmulatedDriver {
  public:
    typedef HanGuDriverParams Params;
    HanGuDriver(Params *p);

    int open(ThreadContext *tc, int mode, int flags);
    int ioctl(ThreadContext *tc, unsigned req, Addr ioc_buf) override;
    Addr mmap(ThreadContext *tc, Addr start, uint64_t length,
              int prot, int tgtFlags, int tgtFd, int offset);

  protected:
    /**
     * RDMA agent (device) that is controled by this driver.
     */
    RdmaNic *device;
    
    Addr hcrAddr;

    void configDevice();

  private:

    /* -------CPU_ID{begin}------- */
    uint8_t cpu_id;
    /* -------CPU_ID{end}------- */

    /* -------HCR {begin}------- */
    uint8_t checkHcr(PortProxy& portProxy);

    void postHcr(PortProxy& portProxy, 
            uint64_t inParam, uint32_t inMod, uint64_t outParam, uint8_t opcode);
    /* -------HCR {end}------- */

    /* ------- Resc {begin} ------- */
    struct RescMeta {
        Addr     start ;  // start index (icm vaddr) of the resource
        uint64_t size  ;  // size of the resource(in byte)
        uint32_t entrySize; // size of one entry (in byte)
        uint8_t  entryNumLog;
        uint32_t entryNumPage;
        
        // ICM space bitmap, one bit indicates one page.
        uint8_t *bitmap;  // resource bitmap, 
    };

    uint32_t allocResc(uint8_t rescType, RescMeta &rescMeta);
    /* ------- Resc {end} ------- */

    /* -------ICM resources {begin}------- */
    /* we use one entry to store one page */
    std::unordered_map<Addr, Addr> icmAddrmap; // Global ICM space address mapping <icm vaddr page, icm paddr>
    
    void initIcm(PortProxy& portProxy, uint8_t qpcNumLog, 
            uint8_t cqcNumLog, uint8_t mptNumLog, uint8_t mttNumLog);
    
    // If the icm page mapped
    uint8_t isIcmMapped(RescMeta &rescMeta, Addr index);

    /**
     * @brief Allocate ICM space paddr. Allocate ICM_ALLOC_PAGE_NUM pages one time
     * 
     * @param process 
     * @param rescMeta 
     * @param index Start index of allocated resource this time
     * @return Addr: start Virtual Page of the ICM space
     */
    Addr allocIcm(Process *process, RescMeta &rescMeta, Addr index);

    // write <icm vaddr, paddr> into hardware
    void writeIcm(PortProxy& portProxy, uint8_t rescType, RescMeta &rescMeta, Addr icmVPage);
    /* -------ICM resources {end}------- */


    /* -------MTT resources {begin}------- */
    RescMeta mttMeta;

    // allocate mtt resources
    void allocMtt(Process *process, TypedBufferArg<kfd_ioctl_init_mtt_args> &args);
    
    void writeMtt(PortProxy& portProxy, TypedBufferArg<kfd_ioctl_init_mtt_args> &args);
    /* -------MTT resources {end}------- */

    /* -------MPT resources {begin}------- */
    RescMeta mptMeta;

    // allocate mpt resources
    void allocMpt(Process *process, TypedBufferArg<kfd_ioctl_alloc_mpt_args> &args);
    
    void writeMpt(PortProxy& portProxy, TypedBufferArg<kfd_ioctl_write_mpt_args> &args);
    /* -------MTT resources {end}------- */

    /* -------CQC resources {begin}------- */
    
    RescMeta cqcMeta;

    // allocate cq resources
    void allocCqc(TypedBufferArg<kfd_ioctl_alloc_cq_args> &args);
    
    void writeCqc(PortProxy& portProxy, TypedBufferArg<kfd_ioctl_write_cqc_args> &args);
    /* -------CQC resources {end}------- */

    /* -------QPC resources {begin}------- */
    RescMeta qpcMeta;

    // allocate qp resources
    void allocQpc(TypedBufferArg<kfd_ioctl_alloc_qp_args> &args);
    
    void writeQpc(PortProxy& portProxy, TypedBufferArg<kfd_ioctl_write_qpc_args> &args);
    /* -------QPC resources {end}------- */

    /* -------QoS Group resources {begin}------- */
    struct groupUnit
    {
        std::unordered_map<uint32_t, uint8_t> qpWeight;
    };

    void setGroup(PortProxy& portProxy, TypedBufferArg<kfd_ioctl_set_group_args> &args);
    void allocGroup(PortProxy& portProxy, TypedBufferArg<kfd_ioctl_alloc_group_args> &args);
    void updateQpWeight(PortProxy& portProxy, TypedBufferArg<kfd_ioctl_write_qpc_args> &args);
    void printQoS(PortProxy& portProxy);
    void initQoS(PortProxy& portProxy, Process* process);
    void updateN(PortProxy& portProxy, TypedBufferArg<kfd_ioctl_alloc_qp_args> &args);
    
    std::unordered_map<uint32_t, uint8_t> qpGroup;
    std::unordered_map<uint8_t, struct groupUnit> groupTable;
    Addr qosShareParamAddr;
    const int NOffset                   = 0;
    const int groupNumOffset            = 16;
    const int groupWeightSumOffset      = 32;
    const int groupWeightOffset         = 256;
    const int groupQPWeightSumOffset    = 512;
    const int groupGranularityOffset    = 1536;
    const int barShareAddrOffset        = 0x30;
    const int barShareAddrFlagOffset    = 0x40;
    const int qpAmountOffset            = 0x50;
    const int qosSharePageNum           = 1;
    // int qpAmount = 0;
    const int chunkSizePerQP = 4096;
    /* -------QoS Group resources {end}------- */

    /* ------------TQ resources {begin}---------- */
    RescMeta tqMeta;
    void allocTq();
    /* ------------TQ resources {end}------------ */

    /* -------mailbox {begin} ------- */

    // Addr mailbox;
    struct Mailbox {
        Addr paddr;
        Addr vaddr;
    };
    Mailbox mailbox;

    void initMailbox(Process *process);
    /* -------mailbox {end} ------- */

};

#endif // __RDMA_HANGU_DRIVER_HH__
