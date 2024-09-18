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

#ifndef __RDMA_HANGU_RNIC_HH__
#define __RDMA_HANGU_RNIC_HH__

#include <deque>
#include <queue>
#include <string>
#include <list>
#include <unordered_map>

#include "dev/rdma/hangu_rnic_defs.hh"

#include "base/inet.hh"
#include "debug/EthernetDesc.hh"
#include "debug/EthernetIntr.hh"
#include "dev/rdma/rdma_nic.hh"
#include "dev/net/etherdevice.hh"
#include "dev/net/etherint.hh"
#include "dev/net/etherpkt.hh"
#include "dev/net/pktfifo.hh"
#include "dev/pci/device.hh"
#include "params/HanGuRnic.hh"

// #include "dev/rdma/resc_cache.hh"
// #include "dev/rdma/hangu_cache.hh"

using namespace HanGuRnicDef;

class HanGuRnicInt;

class HanGuRnic : public RdmaNic {
    private:
        HanGuRnicInt *etherInt;

        // device registers
        Regs regs;

        // packet fifos, interact with Ethernet Link
        std::queue<EthPacketPtr> rxFifo;
        std::queue<EthPacketPtr> txFifo;

        /* --------------------PIO <-> CCU {begin}-------------------- */
        std::queue<DoorbellPtr> pio2ccuDbFifo;
        /* --------------------PIO <-> CCU {end}-------------------- */

        /* --------------------CCU <-> RDMA Engine {begin}-------------------- */
        std::vector<DoorbellPtr> doorbellVector;
        std::queue<uint8_t> df2ccuIdxFifo;
        /* --------------------CCU <-> RDMA Engine {end}-------------------- */

        /* --------------------TPT <-> RDMA Engine {begin}-------------------- */
        // Descriptor relevant
        std::queue<MrReqRspPtr>descReqFifo; // tx(DFU) & rx(RPU) descriptor req post to this fifo.
        std::queue<TxDescPtr> txdescRspFifo; /* Store descriptor, **not list** */
        std::queue<RxDescPtr> rxdescRspFifo;
        // std::queue<MrReqRspPtr> txdescRspFifo;
        // std::queue<MrReqRspPtr> rxdescRspFifo;

        // CQ write req fifo, SCU and RCU post the request
        std::queue<MrReqRspPtr> cqWreqFifo;

        // Data processing fifo
        std::queue<MrReqRspPtr> dataReqFifo;   // DPU, rgrru, rpu -> TPT
        std::queue<MrReqRspPtr> txdataRspFifo; // TPT -> rgrru
        std::queue<MrReqRspPtr> rxdataRspFifo; // TPT -> RPCPLU

        /* --------------------TPT <-> RDMA Engine {end}-------------------- */

        /* --------------------CqcModule <-> RDMA Engine {begin}-------------------- */
        /** 
         * Cqc read&update req post to this fifo. (
         * scu -(update req)-> CqcModule; 
         * rcu -(update req)-> CqcModule )
         */
        std::queue<CxtReqRspPtr> txCqcReqFifo;
        std::queue<CxtReqRspPtr> rxCqcReqFifo;

        std::queue<CxtReqRspPtr> txCqcRspFifo; /* CqcModule -(update rsp)-> scu */
        std::queue<CxtReqRspPtr> rxCqcRspFifo; /* CqcModule -(update rsp)-> rcu */
        /* --------------------CqcModule <-> RDMA Engine {end}-------------------- */

        /* --------------------DescScheduler <-> RDMA Engine {begin}---------------------------*/
        std::queue<TxDescPtr> txDescLaunchQue;
        std::queue<std::pair<uint32_t, uint32_t>> updateQue;
        /* --------------------DescScheduler <-> RDMA Engine {end}-----------------------------*/

        /* --------------------DescScheduler <-> CCU {begin}---------------------------*/
        std::queue<QPStatusPtr> createQue;
        /* --------------------DescScheduler <-> CCU {end}-----------------------------*/

        /* --------------------TPT <-> DMA Engine {begin}-------------------- */
        std::queue<DmaReqPtr> descDmaReadFifo;
        std::queue<DmaReqPtr> dataDmaReadFifo;
        std::queue<DmaReqPtr> cqDmaWriteFifo;
        std::queue<DmaReqPtr> dataDmaWriteFifo;
        /* --------------------TPT <-> DMA Engine {end}-------------------- */

        /* --------------------CCU <-> DMA Engine {begin}-------------------- */
        std::queue<DmaReqPtr> ccuDmaReadFifo;
        /* --------------------CCU <-> DMA Engine {end}-------------------- */
        
        /* -----------------------CCU Relevant {begin}----------------------- */
        void ceuProc(); // Event of CEU before fetching mailbox.
        EventFunctionWrapper ceuProcEvent;

        void doorbellProc(); // Event of doorbell processing
        EventFunctionWrapper doorbellProcEvent;

        void mboxFetchCpl(); // Event of CCU after mailbox being fetched.
        EventFunctionWrapper mboxEvent;

        uint8_t* mboxBuf;
        
        /* -----------------------CCU Relevant {end}----------------------- */

        /* -----------------------RDMA Engine Relevant{begin}----------------------- */

        class RdmaEngine {
            protected:

                /* Point to the rnic I am belong to */
                HanGuRnic *rnic;

                /* Name of this Module */
                std::string _name;


                /* dfu -> ddu */
                // std::queue<DoorbellPtr> df2ddFifo;
                uint32_t txDescLenSel(uint8_t num);/* Return number of descriptors to prefetch */

                /* DDU owns */
                DoorbellPtr dduDbell; /* Doorbell stored for DDU use. This is NOT the PIO doorbell */
                bool allowNewDb;

                /* ddu -> dpu */
                std::vector<TxDescPtr> dd2dpVector;

                /* ddu <- dpu */
                std::queue<uint8_t> dp2ddIdxFifo;

                /* dpu owns */
                // uint32_t descCnt;     /* Number of descriptors fetched for one doorbell */

                /* dpu -> rgrru */
                std::queue<DP2RGPtr> dp2rgFifo;
                uint32_t getRdmaHeadSize (uint8_t opcode, uint8_t qpType);

                /* rg&rru owns */
                std::unordered_map<uint32_t, WinMapElem *> sndWindowList; /* <QPN, send pkt list> */
                uint32_t windowSize; /* current window size */
                uint32_t windowCap;  /* maximum window size */
                bool windowFull;
                void postTxCpl(uint8_t qpType, uint32_t qpn, 
                        uint32_t cqn, TxDescPtr desc); /* Post send completion to SCU */
                bool isWindowBlocked();
                bool isRspRecv();
                bool isReqGen();

                /* rgu owns */
                bool messageEnd;
                void rguProcessing(); /* Request Generation Unit */
                void setMacAddr (uint8_t *dst, uint64_t src);
                void setRdmaHead(TxDescPtr desc, QpcResc* qpc, uint8_t* pktPtr, uint8_t &needAck);
                void copyEthData(EthPacketPtr rawPkt, EthPacketPtr newPkt, MrReqRspPtr rspData);

                /* rru owns */
                void rruProcessing(); /* Response Receiving Unit */
                void reTransPkt(WinMapElem *winElem, uint32_t pktCnt); /* retransmission packet */
                void rdmaReadRsp(EthPacketPtr rxPkt, WindowElemPtr winElem);

                // rg&rru -> scu
                std::queue<CqDescPtr> rg2scFifo;

                // scu owns
                // bool isPostCqcReq;

                /* {rg&rru ->sau} && {rpu -> sau} */
                std::queue<EthPacketPtr> txsauFifo;

                /* rau owns */
                bool isAckPkt(EthPacketPtr rxPkt);

                /* rau -> rg&rru */
                std::queue<EthPacketPtr> ra2rgFifo;

                /* rau -> rpu */
                std::vector<EthPacketPtr> rs2rpVector;

                /* rpu -> rau */
                std::queue<uint8_t> rp2raIdxFifo;

                /* rpu owns */
                // QpcResc *rxLastQpc;
                // RxDesc *rxDesc;
                uint32_t rxDescLenSel();// Return number of rx descriptors to fetch (in the unit of rx desc number)
                void rpuWbQpc (QpcResc* qpc);
                
                /* rpu -> rcvRpu */
                // std::unordered_map<uint32_t, std::pair<uint32_t, QpcResc*> > rcvQpcList; /* <qpn, <cnt, qpc> > */
                std::queue<std::pair<EthPacketPtr, QpcResc*> > rp2rcvRpFifo;


                // wrRpu owns
                void wrRpuProcessing(EthPacketPtr rxPkt, QpcResc* qpc);

                // rdRpu owns
                void rdRpuProcessing (EthPacketPtr rxPkt, QpcResc* qpc);

                // rdRpu -> rdRpCpl
                std::queue<EthPacketPtr> rp2rpCplFifo;

                // rpu -> rcu
                std::queue<CqDescPtr> rp2rcFifo;

                int onFlyPacketNum;

            public:

                RdmaEngine (HanGuRnic *rnic, const std::string n, uint32_t elemCap)
                : rnic(rnic),
                    _name(n),
                    allowNewDb(true),
                    dd2dpVector(elemCap),
                    windowSize(0),
                    windowCap(WINDOW_CAP),
                    windowFull(false),
                    messageEnd(true),
                    rs2rpVector(elemCap),
                    onFlyPacketNum(0),
                    dfuEvent ([this]{ dfuProcessing(); }, n),
                    dduEvent ([this]{ dduProcessing(); }, n),
                    dpuEvent ([this]{ dpuProcessing(); }, n),
                    rgrrEvent([this]{ rgrrProcessing();}, n),
                    scuEvent ([this]{ scuProcessing(); }, n),
                    sauEvent ([this]{ sauProcessing(); }, n),
                    rauEvent ([this]{ rauProcessing(); }, n),
                    rpuEvent ([this]{ rpuProcessing(); }, n),
                    rcvRpuEvent  ([this]{rcvRpuProcessing();  }, n),
                    rdCplRpuEvent([this]{rdCplRpuProcessing();}, n),
                    rcuEvent([this]{ rcuProcessing();}, n)
                    { 
                        for (uint32_t x = 0; x < elemCap; ++x) {
                            dp2ddIdxFifo.push(x);
                            rp2raIdxFifo.push(x);
                        }
                        assert(rp2raIdxFifo.size() == elemCap);
                    }

                std::string name() { return _name; }

                // event for tx packet
                void dfuProcessing(); // Descriptor Fetching Unit
                EventFunctionWrapper dfuEvent;
                
                void dduProcessing(); // Descriptor decode Unit
                EventFunctionWrapper dduEvent;
                
                void dpuProcessing(); // Descriptor processing unit
                EventFunctionWrapper dpuEvent;
                
                void rgrrProcessing(); // Request Generation & Response Receiving Unit
                EventFunctionWrapper rgrrEvent;
                
                void scuProcessing(); // Send Completion Unit
                EventFunctionWrapper scuEvent;
                
                void sauProcessing(); // Send Arbiter Unit, directly post data to link layer
                EventFunctionWrapper sauEvent;

                
                // event for rx packet
                void rauProcessing(); // Receive Arbiter Unit
                EventFunctionWrapper rauEvent;
                
                void rpuProcessing(); // Receive Processing Unit
                EventFunctionWrapper rpuEvent;

                void rcvRpuProcessing ();
                EventFunctionWrapper rcvRpuEvent;

                void rdCplRpuProcessing(); // RDMA read Receive Processing Completion Unit
                EventFunctionWrapper rdCplRpuEvent;

                void rcuProcessing(); // Receive Completion Unit
                EventFunctionWrapper rcuEvent;

                std::queue<DoorbellPtr> df2ddFifo; // TODO: move this FIFO to Top level and change its name
        };

        RdmaEngine rdmaEngine;
        /* -----------------------RDMA Engine Relevant{end}----------------------- */

        /* -------------------WQE Scheduler Relevant{begin}---------------------- */
        class DescScheduler{
            private:
                HanGuRnic *rNic;
                std::string _name;
                void qpcRspProc();
                void qpStatusProc();
                void wqePrefetchSchedule();
                void wqePrefetch();
                void wqeProc();
                void rxUpdate();
                void launchWQE();
                void createQpStatus();
                uint16_t sqSize;
                uint16_t rqSize;
                std::queue<uint32_t> highPriorityQpnQue;
                std::queue<uint32_t> lowPriorityQpnQue;
                std::queue<uint32_t> leastPriorityQpnQue;
                std::queue<TxDescPtr> highPriorityDescQue;
                std::queue<TxDescPtr> lowPriorityDescQue;
                std::queue<DoorbellPtr> dbProcQpStatusRReqQue;
                std::queue<std::pair<DoorbellPtr, QPStatusPtr>> dbQpStatusRspQue;
                std::queue<uint32_t> wqePrefetchQpStatusRReqQue;
                std::queue<std::pair<uint32_t, QPStatusPtr>> wqeFetchInfoQue;
                std::queue<DoorbellPtr> wqeProcToLaunchWqeQueH;
                std::queue<DoorbellPtr> wqeProcToLaunchWqeQueL;
                EventFunctionWrapper qpStatusRspEvent;
                EventFunctionWrapper wqePrefetchEvent;
                EventFunctionWrapper wqePrefetchScheduleEvent;
                EventFunctionWrapper launchWqeEvent;
            public:
                DescScheduler(HanGuRnic *rNic, std::string name);
                EventFunctionWrapper updateEvent;
                EventFunctionWrapper createQpStatusEvent;
                EventFunctionWrapper qpcRspEvent;
                EventFunctionWrapper wqeRspEvent;
                std::unordered_map<uint8_t, uint16_t> groupTable;
                std::unordered_map<uint32_t, QPStatusPtr> qpStatusTable;
                std::string name()
                {
                    return _name;
                }
        };
        DescScheduler descScheduler;
        /* -------------------WQE Scheduler Relevant{end}------------------------ */

        /* -------------------WQE Buffer Relevant{begin}---------------------- */
        // class DescBuffer{
        //     private:

        //     public:
        //         DescBuffer();
        //         uint64_t byteSize;
        //         uint32_t totalWeight;
        // };
        // DescBuffer wqeBuffer;
        // /* -------------------WQE Buffer Relevant{end}------------------------ */

        // /* -------------------QP Status Relevant{begin}---------------------- */
        // class QPStatus{
        //     private:

        //     public:
        //         QPStatus();
        // };
        // QPStatus qpStatus;
        /* -------------------QP Status Relevant{end}------------------------ */

        
        /* -----------------------Cache {begin}------------------------ */
        template <class T, class S>
        class RescCache {
            private:

                struct CacheRdPkt {
                    CacheRdPkt(Event *cplEvent, uint32_t rescIdx, 
                            T *rescDma, S reqPkt, DmaReqPtr dmaReq, T *rspResc, const std::function<bool(T&)> &rescUpdate) 
                    : cplEvent(cplEvent), rescIdx(rescIdx), rescDma(rescDma), reqPkt(reqPkt), 
                        rspResc(rspResc), 
                        rescUpdate(rescUpdate) { this->dmaReq = dmaReq; }
                    Event   *cplEvent; /* event to be scheduled when resource fetched */
                    uint32_t rescIdx; /* resource index */
                    T       *rescDma; /* addr used to get resc through DMA read */
                    S        reqPkt ; /* temp store the request pkt */
                    DmaReqPtr dmaReq; /* DMA read request pkt, to fetch missed resource (cache), 
                                        we only use its isValid to fetch the rsp */
                    T       *rspResc; /* addr used to rsp the requester !TODO: delete it later */
                    const std::function<bool(T&)> rescUpdate;
                };

                /* Pointer to the device I am in. */
                HanGuRnic *rnic;

                /* Stores my name in string */
                std::string _name;

                /* Cache for resource T */
                std::unordered_map<uint32_t, T> cache;
                uint32_t capacity; /* number of cache entries this Resource cache owns */

                /* used to process cache read */
                void readProc();
                EventFunctionWrapper readProcEvent;
            
                /* Request FIFO, Only used in Cache Read.
                * Used to temp store request pkt in order */
                std::queue<CacheRdPkt> reqFifo;
                

                // Base ICM address of resources in ICM space.
                uint64_t baseAddr;
                
                // Storage for ICM
                uint64_t *icmPage;
                uint32_t rescSz; // size of one entry of resource

                // Convert resource number into physical address.
                uint64_t rescNum2phyAddr(uint32_t num);

                /* Cache replace scheme, return key in cache */
                uint32_t replaceScheme();

                // Write evited elem back to memory
                void storeReq(uint64_t addr, T *resc);

                // Read wanted elem from memory
                void fetchReq(uint64_t addr, Event *cplEvent, uint32_t rescNum, S reqPkt, T *resc, const std::function<bool(T&)> &rescUpdate=nullptr);

                /* get fetched data from memory */
                void fetchRsp();
                EventFunctionWrapper fetchCplEvent;
                
                /* read req -> read rsp Fifo
                * Used only in Read Cache miss. */
                std::queue<CacheRdPkt> rreq2rrspFifo;

            public:

                RescCache (HanGuRnic *i, uint32_t cacheSize, const std::string n) 
                : rnic(i),
                    _name(n),
                    capacity(cacheSize),
                    readProcEvent([this]{ readProc(); }, n),
                    fetchCplEvent([this]{ fetchRsp(); }, n) { icmPage = new uint64_t [ICM_MAX_PAGE_NUM]; rescSz = sizeof(T); }

                /* Set base address of ICM space */
                void setBase(uint64_t base);

                /* ICM Write Request */
                void icmStore(IcmResc *icmResc, uint32_t chunkNum);

                /* Write resource back to Cache */
                void rescWrite(uint32_t rescIdx, T *resc, const std::function<bool(T&, T&)> &rescUpdate=nullptr);

                /* Read resource from Cache */
                void rescRead(uint32_t rescIdx, Event *cplEvent, S reqPkt, T *rspResc=nullptr, const std::function<bool(T&)> &rescUpdate=nullptr);

                /* Outer module uses to get cache entry (so don't delete the element) */
                std::queue<std::pair<T *, S> > rrspFifo;

                std::string name() { return _name; }
        };
        /* -----------------------Cache {end}------------------------ */



        // /* -----------------------Cache {begin}------------------------ */
        // template <class T, class S>
        // class RescCache {
        //     private:

        //         struct CacheRdPkt {
        //             CacheRdPkt(Event *cplEvent, uint32_t rescIdx, 
        //                     T *rescDma, S reqPkt, DmaReqPtr dmaReq, T *rspResc, const std::function<bool(T&)> &rescUpdate) 
        //             : cplEvent(cplEvent), rescIdx(rescIdx), rescDma(rescDma), reqPkt(reqPkt), 
        //                 rspResc(rspResc), 
        //                 rescUpdate(rescUpdate) { this->dmaReq = dmaReq; }
        //             Event   *cplEvent; /* event to be scheduled when resource fetched */
        //             uint32_t rescIdx; /* resource index */
        //             T       *rescDma; /* addr used to get resc through DMA read */
        //             S        reqPkt ; /* temp store the request pkt */
        //             DmaReqPtr dmaReq; /* DMA read request pkt, to fetch missed resource (cache), 
        //                                 we only use its isValid to fetch the rsp */
        //             T       *rspResc; /* addr used to rsp the requester !TODO: delete it later */
        //             const std::function<bool(T&)> rescUpdate;
        //         };

        //         /* Pointer to the device I am in. */
        //         HanGuRnic *rnic;

        //         /* Stores my name in string */
        //         std::string _name;

        //         /* Cache for resource T */
        //         std::unordered_map<uint32_t, T> cache;
        //         uint32_t capacity; /* number of cache entries this Resource cache owns */

        //         /* used to process cache read */
        //         void readProc();
        //         EventFunctionWrapper readProcEvent;
            
        //         /* Request FIFO, Only used in Cache Read.
        //         * Used to temp store request pkt in order */
        //         std::queue<CacheRdPkt> reqFifo;
                

        //         // Base ICM address of resources in ICM space.
        //         uint64_t baseAddr;
                
        //         // Storage for ICM
        //         uint64_t *icmPage;
        //         uint32_t rescSz; // size of one entry of resource

        //         // Convert resource number into physical address.
        //         uint64_t rescNum2phyAddr(uint32_t num);

        //         /* Cache replace scheme, return key in cache */
        //         uint32_t replaceScheme();

        //         // Write evited elem back to memory
        //         void storeReq(uint64_t addr, T *resc);

        //         // Read wanted elem from memory
        //         void fetchReq(uint64_t addr, Event *cplEvent, uint32_t rescNum, S reqPkt, T *resc, const std::function<bool(T&)> &rescUpdate=nullptr);

        //         /* get fetched data from memory */
        //         void fetchRsp();
        //         EventFunctionWrapper fetchCplEvent;
                
        //         /* read req -> read rsp Fifo
        //         * Used only in Read Cache miss. */
        //         std::queue<CacheRdPkt> rreq2rrspFifo;

        //     public:

        //         RescCache (HanGuRnic *i, uint32_t cacheSize, const std::string n) 
        //         : rnic(i),
        //             _name(n),
        //             capacity(cacheSize),
        //             readProcEvent([this]{ readProc(); }, n),
        //             fetchCplEvent([this]{ fetchRsp(); }, n) { icmPage = new uint64_t [ICM_MAX_PAGE_NUM]; rescSz = sizeof(T); }

        //         /* Set base address of ICM space */
        //         void setBase(uint64_t base);

        //         /* ICM Write Request */
        //         void icmStore(IcmResc *icmResc, uint32_t chunkNum);

        //         /* Write resource back to Cache */
        //         void rescWrite(uint32_t rescIdx, T *resc, const std::function<bool(T&, T&)> &rescUpdate=nullptr);

        //         /* Read resource from Cache */
        //         void rescRead(uint32_t rescIdx, Event *cplEvent, S reqPkt, T *rspResc=nullptr, const std::function<bool(T&)> &rescUpdate=nullptr);

        //         /* Outer module uses to get cache entry (so don't delete the element) */
        //         std::queue<std::pair<T *, S> > rrspFifo;

        //         std::string name() { return _name; }
        // };
        // /* -----------------------Cache {end}------------------------ */

        /* -----------------------TPT Relevant{begin}----------------------- */
        class MrRescModule {
            protected:

                /* Point to the device I am in */
                HanGuRnic *rnic;

                /* Name of my self */
                std::string _name;

                uint8_t chnlIdx;
                
                /* Temp store dma read request pkt until read rsp is back */
                std::queue<std::pair<MrReqRspPtr, DmaReqPtr> > dmaReq2RspFifo;
                void dmaReqProcess(uint64_t pAddr, MrReqRspPtr tptReq, uint32_t offset, uint32_t length);
                /**
                 * tx descriptor (read rsp) -(schedule to)-> rdmaEngine.ddu
                 * rx descriptor (read rsp) -(schedule to)-> rdmaEngine.rcvrpu
                 * tx read data (read rsp) -(schedule to)->  rdmaEngine.rg&rru(rgu)
                 * rx read data (read rsp) -(schedule to)->  rdmaEngine.rpu(RdRPU)
                 */
                void dmaRrspProcessing();
                EventFunctionWrapper dmaRrspEvent;

                /* MPT relevant */
                void mptReqProcess(MrReqRspPtr tptReq);
                bool isMRMatching (MptResc * mptResc, MrReqRspPtr tptReq);// Judge if this tpt req 
                                                                        // is valid to access the memory region
                void mptRspProcessing();
                EventFunctionWrapper mptRspEvent;

                /* MTT Relevant */
                void mttReqProcess(uint64_t mttIdx, MrReqRspPtr tptReq);
                void mttRspProcessing();
                EventFunctionWrapper mttRspEvent;

                // added by mazhenlong @ 23230805
                int onFlyDataMrRdReqNum;
                int onFlyDescMrRdReqNum;
                int onFlyDataDmaRdReqNum;
                int onFlyDescDmaRdReqNum;

            public:

                MrRescModule (HanGuRnic *i, const std::string n, 
                        uint32_t mptCacheNum, uint32_t mttCacheNum);


                /* dfu tx descriptor (read req)
                * rpu rx descriptor (read req)
                * scu cq (write req)
                * rcu cq (write req)
                * dpu read data (read req)
                * rg&rru(RRU) write data (write req)
                * rpu(RdRPU) read data (read req)
                * rpu(WrRPU, RcvRPU) write data (write req) */
                void transReqProcessing();
                EventFunctionWrapper transReqEvent;

                RescCache<MptResc, MrReqRspPtr> mptCache;
                RescCache<MttResc, MrReqRspPtr> mttCache;

                std::string name() { return _name; }
            
        };

        MrRescModule mrRescModule;
        /* -----------------------TPT Relevant{end}----------------------- */
        
        /* -----------------------CQC Management Module {begin}----------------------- */
        class CqcModule {
            protected:

                /* Pointer to the device I am in */
                HanGuRnic *rnic;

                /* Name of myself */
                std::string _name;
                
                /* req owns */
                uint8_t chnlIdx;

                /* txCqcRspFifo; CqcModule -(update rsp)-> scu 
                * rxCqcRspFifo; CqcModule -(update rsp)-> rcu */
                void cqcRspProc();
                EventFunctionWrapper cqcRspProcEvent;

                /* txCqcReqFifo;
                * rxCqcReqFifo; */
                void cqcReqProc(); 
                EventFunctionWrapper cqcReqProcEvent;

            public:

                CqcModule (HanGuRnic *i, const std::string n, uint32_t cqcCacheNum)
                : rnic(i),
                    _name(n),
                    chnlIdx(0),
                    cqcRspProcEvent([this]{ cqcRspProc();}, n),
                    cqcReqProcEvent([this]{ cqcReqProc();}, n),
                    cqcCache(i, cqcCacheNum, n) { }

                bool postCqcReq(CxtReqRspPtr cqcReq);

                RescCache<CqcResc, CxtReqRspPtr> cqcCache;

                std::string name() { return _name; }
        };

        CqcModule cqcModule;
        /* -----------------------CQC Management Module {end}----------------------- */

        /* -----------------------ICM Management Module {begin}------------------- */
        class IcmManage {
            /* Name of myself */
            std::string _name;

            // Base ICM address of resources in ICM space.
            uint64_t baseAddr;
            
            // Storage for ICM
            uint64_t *icmPage;
            uint32_t rescSz; // size of one entry of resource
        
            public:
                IcmManage (const std::string n, uint32_t entrySz)
                : _name(n) { baseAddr = 0; icmPage = new uint64_t [ICM_MAX_PAGE_NUM]; rescSz = entrySz; }

                // Convert resource number into physical address.
                uint64_t num2phyAddr(uint32_t num) {
                    uint32_t vAddr = num * rescSz;
                    uint32_t icmIdx = vAddr >> 12;
                    uint32_t offset = vAddr & 0xfff;
                    uint64_t pAddr = icmPage[icmIdx] + offset;

                    return pAddr;
                }

                /* Set base address of ICM space */
                void setBase(uint64_t base) { baseAddr = base; }

                /* ICM Write Request */
                void icmStore(IcmResc *icmResc, uint32_t chunkNum) {
                    for (int i = 0; i < chunkNum; ++i) {
                        uint32_t idx = (icmResc[i].vAddr - baseAddr) >> 12;
                        while (icmResc[i].pageNum) {
                            icmPage[idx] = icmResc[i].pAddr;

                            /* Update param */
                            --icmResc[i].pageNum;
                            icmResc[i].pAddr += (1 << 12);
                            ++idx;
                        }
                    }
                    delete[] icmResc;
                }

                std::string name() { return _name; }
        };
        /* -----------------------ICM Management Module {end}------------------- */
                
        /* -----------------------QPC Cache {begin}---------------------- */
        template <class T>
        class Cache {
            private:
                /* Name of myself */
                std::string _name;

                /* Cache for resource T */
                std::unordered_map<uint32_t, std::pair<T*, uint64_t> > cache; /* <entryNum, <entry, lru>> */
                uint32_t capacity; /* number of cache entries this cache owns */
                uint32_t cacheSz;

                uint64_t seq_end;

            public:
                Cache (const std::string n, uint32_t qpcCacheNum)
                : _name(n),
                    capacity(qpcCacheNum),
                    seq_end(0) { cacheSz = sizeof(T); }

                /* Cache replace scheme, return key in cache */
                uint32_t replaceEntry();

                /* lookup entry in cache */
                bool lookupHit(uint32_t entryNum); /* return true if really hit */
                bool lookupFull(uint32_t entryNum); /* return true if cache is full */

                /* read entry from cache */
                bool readEntry(uint32_t entryNum, T* entry); /* use memcpy to get entry */

                bool updateEntry(uint32_t entryNum, const std::function<bool(T&)> &update=nullptr);

                /* write entry to cache */
                bool writeEntry(uint32_t entryNum, T* entry); /* use memcpy to write entry */

                /* delete entry in cache */
                T* deleteEntry(uint32_t entryNum);

                std::string name() { return _name; }
        };
        /* -----------------------QPC Cache {end}---------------------- */

        // /* -----------------------QPC Cache {begin}---------------------- */
        // template <class T>
        // class Cache {
        //     private:
        //         /* Name of myself */
        //         std::string _name;

        //         /* Cache for resource T */
        //         std::unordered_map<uint32_t, std::pair<T*, uint64_t> > cache; /* <entryNum, <entry, lru>> */
        //         uint32_t capacity; /* number of cache entries this cache owns */
        //         uint32_t cacheSz;

        //         uint64_t seq_end;

        //     public:
        //         Cache (const std::string n, uint32_t qpcCacheNum)
        //         : _name(n),
        //             capacity(qpcCacheNum),
        //             seq_end(0) { cacheSz = sizeof(T); }

        //         /* Cache replace scheme, return key in cache */
        //         uint32_t replaceEntry();

        //         /* lookup entry in cache */
        //         bool lookupHit(uint32_t entryNum); /* return true if really hit */
        //         bool lookupFull(uint32_t entryNum); /* return true if cache is full */

        //         /* read entry from cache */
        //         bool readEntry(uint32_t entryNum, T* entry); /* use memcpy to get entry */

        //         bool updateEntry(uint32_t entryNum, const std::function<bool(T&)> &update=nullptr);

        //         /* write entry to cache */
        //         bool writeEntry(uint32_t entryNum, T* entry); /* use memcpy to write entry */

        //         /* delete entry in cache */
        //         T* deleteEntry(uint32_t entryNum);

        //         std::string name() { return _name; }
        // };
        // /* -----------------------QPC Cache {end}---------------------- */

        /* -----------------------PendingStruct {begin}---------------------- */
        class PendingStruct {
            private:

                /* Pointer to the device I am in */
                HanGuRnic *rnic;

                /* Name of myself */
                std::string _name;

                uint8_t chnl;
                
                /* used to push pending information to pendingFifo, pushElemProc() 
                * would read it */
                std::queue<PendingElemPtr> pushFifo;

                std::queue<PendingElemPtr> pendingFifo[2];
                uint32_t elemCap;
                uint32_t elemNum;

                /* swap onlineIdx and offlineIdx */
                void swapIdx();
                uint8_t offlineIdx, onlineIdx;

                /* post dma request to dma engine && push pElem to pendingFifo */
                void pushElemProc();
                EventFunctionWrapper pushElemProcEvent;

            public:
                PendingStruct(HanGuRnic *rnic, const std::string n, uint32_t elemCap): 
                    rnic(rnic),
                    _name(n),
                    elemCap(elemCap), 
                    elemNum(0), 
                    offlineIdx(1), 
                    onlineIdx(0), 
                    pushElemProcEvent([this]{ pushElemProc(); }, n) {  }

                /* push pElem to pushFifo */
                bool push_elem(PendingElemPtr pElem);
                PendingElemPtr front_elem(); // return first elem in the fifo, the elem is not removed
                PendingElemPtr pop_elem(); // return first elem in the fifo, the elem is removed

                /* just read elem, if offline is empty, swap onlineIdx and offlineIdx */
                PendingElemPtr get_elem_check();
                
                /* pop the elem, and push to the online pendingFifo */
                void ignore_elem_check(PendingElemPtr pElem);

                /* pElem which is no_dma, hit in the cache. 
                * if it is the first, swap online and offline pendingFifo */
                void succ_elem_check();

                /* pElem which is no_dma, not find entry in the cache.
                * and call push_elem */
                void push_elem_check(PendingElemPtr pElem);

                uint32_t get_size() { return pendingFifo[0].size() + pendingFifo[1].size() + pushFifo.size(); }
                uint32_t get_pending_size() { return pendingFifo[0].size() + pendingFifo[1].size(); }

                std::string name() { return _name; }
        };
        /* -----------------------PendingStruct {end}---------------------- */

        /* -----------------------QPC Management Module {begin}----------------------- */
        class QpcModule {
            private:

                /* Pointer to the device I am in */
                HanGuRnic *rnic;

                /* Name of myself */
                std::string _name;

                /* --------Cache related{begin}-------- */
                IcmManage qpcIcm;
                Cache<QpcResc> qpcCache;
                /* --------Cache related{end}-------- */

                /* --------RDMA Engine or CCU -(req)-> QpcModule {begin}-------- */
                /** 
                 * Qpc read&write req post to this fifo. (
                 * ccu.ceu -(wreq)-> QpcModule; 
                 * ccu.dfu -(rreq)-> QpcModule; 
                 * RDMAEngine.ddu -(rreq)-> QpcModule; 
                 * rau -(rreq)-> QpcModule; )
                 */
                std::queue<CxtReqRspPtr> ccuQpcWreqFifo;
                // std::queue<CxtReqRspPtr> reqFifoChnl[3];
                std::queue<CxtReqRspPtr>  txQpAddrRreqFifo; // [0]
                std::queue<CxtReqRspPtr>  txQpcRreqFifo;    // [1]
                std::queue<CxtReqRspPtr>  rxQpcRreqFifo;    // [2]
                /* --------RDMA Engine or CCU -(req)-> QpcModule {end}-------- */

                /* --------Req Proc related {begin}-------- */
                uint8_t chnlIdx;

                bool isReqValidRun(); /* true if the reqProc is runnable next cycle */

                /* ccuQpcWreqFifo
                * txQpAddrRreqFifo
                * txQpcRreqFifo
                * rxQpcRreqFifo */
                void qpcReqProc(); /* Context request processing Unit */
                EventFunctionWrapper qpcReqProcEvent;
                void qpcCreate(); /* Create new qpc entry to cache */
                void qpcAccess();  /* Read or Write qpc from Cache */
                bool readProc(uint8_t chnlNum, CxtReqRspPtr qpcReq);
                void hitProc(uint8_t chnlNum, CxtReqRspPtr qpcReq);

                /* write one entry to cache, use memcpy for cache storage, 
                * so qpcReq is safe to use in other place */
                void writeOne(CxtReqRspPtr qpcReq);
                
                // store evited elem back to memory
                void storeMem(uint64_t paddr, QpcResc *qpc);

            public:
                // load wanted elem from memory
                DmaReqPtr loadMem(CxtReqRspPtr qpcReq);

                /* get loaded data from memory */
                void qpcRspProc();
                EventFunctionWrapper qpcRspProcEvent;
                bool isRspValidRun();

            private:

                /* used to check no_dma pending element */ 
                uint8_t checkNoDmaElem(PendingElemPtr pElem, uint8_t chnlNum, uint32_t qpn);
                /* --------Req Proc related {end}-------- */

                /* --------PendingStruct{begin}-------- */
                class QpnInfo {
                    public:
                        uint32_t qpn;
                        uint8_t reqCnt;
                        bool isValid;
                        bool isReturned;

                        QpnInfo(uint32_t qpn) : qpn(qpn), reqCnt(1), isValid(true), isReturned(false) {  }

                        void firstReqReturned() { isReturned = true; }
                        void reqRePosted() { isReturned = false; }

                        // ~QpnInfo () {
                        //     --rtnCnt;
                        // }
                };
                typedef std::shared_ptr<QpnInfo> QpnInfoPtr;

                std::unordered_map<uint32_t, QpnInfoPtr> qpnHashMap;
                uint32_t elemCap;
                uint32_t rtnCnt;
                
                struct PendingStruct pendStruct;
                /* --------PendingStruct{end}-------- */
            
            public:

                QpcModule (HanGuRnic *i, const std::string n, uint32_t qpcCacheNum, uint32_t elemCap)
                : rnic(i),
                    _name(n),
                    qpcIcm(n, sizeof(QpcResc)),
                    qpcCache(n, qpcCacheNum),
                    chnlIdx(0),
                    qpcReqProcEvent ([this]{ qpcReqProc();}, n),
                    qpcRspProcEvent ([this]{ qpcRspProc();}, n),
                    elemCap(elemCap),
                    rtnCnt(0),
                    pendStruct(i, n, elemCap) { }

                /* post read, write, create request for QPC */
                bool postQpcReq(CxtReqRspPtr qpcReq);

                /* --------QpcModule -(rsp)-> RDMA Engine or CCU {begin}-------- */
                std::queue<CxtReqRspPtr> qpcRspFifo[3];
                std::queue<CxtReqRspPtr> txQpAddrRspFifo; // QP Cxt -(rrsp)-> DFU(RDMA Engine)
                std::queue<CxtReqRspPtr> txQpcRspFifo;
                std::queue<CxtReqRspPtr> rxQpcRspFifo;
                /* --------QpcModule -(rsp)-> RDMA Engine or CCU {end}-------- */

                /* -------- Icm related interface{begin}-------- */
                void setBase(uint64_t base) { qpcIcm.setBase(base); }

                /* ICM Write Request */
                void icmStore(IcmResc *icmResc, uint32_t chunkNum) { qpcIcm.icmStore(icmResc, chunkNum); }
                /* -------- Icm related interface{end}-------- */

                std::string name() { return _name; }
        };

        QpcModule qpcModule;
        /* -----------------------QPC Management Module {end}----------------------- */

        /* -----------------------DMA Engine {begin}----------------------- */
        class DmaEngine {
            protected:

                /* Point to the device we are in. */
                HanGuRnic *rnic;

                /* Name of me */
                std::string _name;
                
                /* Channel selector for arbiter in read side and write side */
                uint8_t readIdx, writeIdx;

            public:

                DmaEngine (HanGuRnic *i, const std::string n) 
                : rnic(i),
                    _name(n),
                    readIdx(0),
                    writeIdx(0),
                    dmaWriteCplEvent([this]{ dmaWriteCplProcessing(); }, n),
                    dmaReadCplEvent([this]{ dmaReadCplProcessing(); }, n),
                    dmaChnlProcEvent([this]{ dmaChnlProc(); }, n),
                    dmaWriteEvent([this]{ dmaWriteProcessing();}, n),
                    dmaReadEvent([this]{ dmaReadProcessing();}, n) { }


                std::queue<DmaReqPtr> dmaWrReq2RspFifo;
                void dmaWriteCplProcessing();
                EventFunctionWrapper dmaWriteCplEvent;

                std::queue<DmaReqPtr> dmaRdReq2RspFifo;
                void dmaReadCplProcessing();
                EventFunctionWrapper dmaReadCplEvent;

                /* Post dma req to dma channel */
                void dmaChnlProc();
                EventFunctionWrapper dmaChnlProcEvent;
                std::queue<DmaReqPtr> dmaRReqFifo;
                std::queue<DmaReqPtr> dmaWReqFifo;


                void dmaWriteProcessing();
                EventFunctionWrapper dmaWriteEvent;

                void dmaReadProcessing();
                EventFunctionWrapper dmaReadEvent;

                std::string name() { return _name; }

        };
        /* -----------------------DMA Engine {end}----------------------- */

        // Packet that we are currently putting into the txFifo
        EthPacketPtr txPacket;

        // Should to Rx/Tx State machine tick?
        // bool inTick;
        // bool rxTick;
        // bool txTick;
        // bool txFifoTick;

        // bool rxDmaPacket;
        Tick tick;


        // Delays in managaging descriptors (unit: ps)
        Tick dmaReadDelay, dmaWriteDelay; // dma fetch (read) delay, write back (write) delay.
        // Tick rxWriteDelay, txReadDelay;

        uint32_t pciBandwidth  ; /* time to trans 1 byte for pci, (unit: ps/Byte) */
        uint32_t etherBandwidth; /* time to trans 1 byte for ethernet, (unit: ps/Byte) */

        uint32_t cpuNum;
        uint32_t syncCnt;
        uint8_t  syncSucc;
        
        // void txWire(); // Post TX pkt from FIFO to Wire


        /** This function is used to restart the clock so it can handle things like
         * draining and resume in one place. */
        void restartClock();

        /** Check if all the draining things that need to occur have occured and
         * handle the drain event if so.
         */
        void checkDrain();


        uint8_t macAddr[ETH_ADDR_LEN];
        bool isMacEqual(uint8_t *devSrcMac, uint8_t *pktDstMac);

    public:
        /* --------------------Cache(in TPT & CxtM) <-> DMA Engine {begin}-------------------- */
        // std::queue<DmaReqPtr> cacheDmaReadFifo;
        // std::queue<DmaReqPtr> cacheDmaWriteFifo;
        std::queue<DmaReqPtr> cacheDmaAccessFifo;

        std::queue<DmaReqPtr> qpcDmaRdCplFifo; /* read response fifo for qpc cache */
        /* --------------------Cache(in TPT & CxtM) <-> DMA Engine {end}-------------------- */

        DmaEngine dmaEngine;

        typedef HanGuRnicParams Params;
        const Params *
        params() const {
            return dynamic_cast<const Params *>(_params);
        }

        HanGuRnic(const Params *params);
        ~HanGuRnic();
        void init() override;

        Port &getPort(const std::string &if_name,
                    PortID idx=InvalidPortID) override;

        Tick lastInterrupt;

        // PIO Interface
        Tick writeConfig(PacketPtr pkt) override;
        Tick read(PacketPtr pkt) override;
        Tick write(PacketPtr pkt) override;

        
        /* Ethernet callback */
        void ethTxDone(); // When TX done
        bool ethRxDelay(EthPacketPtr packet);

        /* related to link delay processing */
        Tick LinkDelay;
        std::queue<std::pair<EthPacketPtr, Tick>> ethRxDelayFifo;

        void ethRxPktProc(); // When rx packet
        EventFunctionWrapper ethRxPktProcEvent;

        void serialize(CheckpointOut &cp) const override;
        void unserialize(CheckpointIn &cp) override;

        DrainState drain() override;
        void drainResume() override;

};

class HanGuRnicInt : public EtherInt {
    private:
        HanGuRnic *dev; // device the interface belonged to

    public:
        HanGuRnicInt(const std::string &name, HanGuRnic *d)
            : EtherInt(name), dev(d) { }

        virtual bool recvPacket(EthPacketPtr pkt) { return dev->ethRxDelay(pkt); }
        virtual void sendDone() { dev->ethTxDone(); }
};

#endif //__RDMA_HANGU_RNIC_HH__
