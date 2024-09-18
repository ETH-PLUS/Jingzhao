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
 * RDMA NIC Device statistic declaration.
 */

#include "dev/rdma/rdma_nic.hh"

#include "sim/stats.hh"

void
RdmaNic::regStats() {
    PciDevice::regStats();

    txBytes
        .name(name() + ".txBytes")
        .desc("Bytes Transmitted")
        .prereq(txBytes)
        ;

    rxBytes
        .name(name() + ".rxBytes")
        .desc("Bytes Received")
        .prereq(rxBytes)
        ;

    txPackets
        .name(name() + ".txPackets")
        .desc("Number of Packets Transmitted")
        .prereq(txBytes)
        ;

    rxPackets
        .name(name() + ".rxPackets")
        .desc("Number of Packets Received")
        .prereq(rxBytes)
        ;

    descDmaReads
        .name(name() + ".descDMAReads")
        .desc("Number of descriptors the device read w/ DMA")
        .precision(0)
        ;

    descDmaWrites
        .name(name() + ".descDMAWrites")
        .desc("Number of descriptors the device wrote w/ DMA")
        .precision(0)
        ;

    descDmaRdBytes
        .name(name() + ".descDmaReadBytes")
        .desc("number of descriptor bytes read w/ DMA")
        .precision(0)
        ;

    descDmaWrBytes
        .name(name() + ".descDmaWriteBytes")
        .desc("number of descriptor bytes write w/ DMA")
        .precision(0)
        ;

    txBandwidth
        .name(name() + ".txBandwidth")
        .desc("Transmit Bandwidth (bits/s)")
        .precision(0)
        .prereq(txBytes)
        ;

    rxBandwidth
        .name(name() + ".rxBandwidth")
        .desc("Receive Bandwidth (bits/s)")
        .precision(0)
        .prereq(rxBytes)
        ;

    totBandwidth
        .name(name() + ".totBandwidth")
        .desc("Total Bandwidth (bits/s)")
        .precision(0)
        .prereq(totBytes)
        ;

    totPackets
        .name(name() + ".totPackets")
        .desc("Total Packets")
        .precision(0)
        .prereq(totBytes)
        ;

    totBytes
        .name(name() + ".totBytes")
        .desc("Total Bytes")
        .precision(0)
        .prereq(totBytes)
        ;

    totPacketRate
        .name(name() + ".totPPS")
        .desc("Total Tranmission Rate (packets/s)")
        .precision(0)
        .prereq(totBytes)
        ;

    txPacketRate
        .name(name() + ".txPPS")
        .desc("Packet Tranmission Rate (packets/s)")
        .precision(0)
        .prereq(txBytes)
        ;

    rxPacketRate
        .name(name() + ".rxPPS")
        .desc("Packet Reception Rate (packets/s)")
        .precision(0)
        .prereq(rxBytes)
        ;

    txBandwidth = txBytes * Stats::constant(8) / simSeconds;
    rxBandwidth = rxBytes * Stats::constant(8) / simSeconds;
    totBandwidth = txBandwidth + rxBandwidth;
    totBytes = txBytes + rxBytes;
    totPackets = txPackets + rxPackets;

    txPacketRate = txPackets / simSeconds;
    rxPacketRate = rxPackets / simSeconds;
    totPacketRate = totPackets / simSeconds;
}
