# 
# ======================= START OF LICENSE NOTICE =======================
#   Copyright (C) 2021 Kang Ning, NCIC, ICT, CAS.
#   All Rights Reserved.
# 
#   NO WARRANTY. THE PRODUCT IS PROVIDED BY DEVELOPER "AS IS" AND ANY
#   EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#   IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
#   PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL DEVELOPER BE LIABLE FOR
#   ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
#   DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
#   GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
#   INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
#   IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#   OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THE PRODUCT, EVEN
#   IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# ======================== END OF LICENSE NOTICE ========================
#   Primary Author: Kang Ning
#   <kangning18z@ict.ac.cn>
#

from m5.defines import buildEnv
from m5.SimObject import SimObject
from m5.params import *
from m5.proxy import *
from m5.objects.PciDevice import PciDevice
from m5.objects.Ethernet import *
from m5.objects.Process import EmulatedDriver

# ETHERNET_ROLE = 'ETHERNET'
# Port.compat(ETHERNET_ROLE, ETHERNET_ROLE)

class HanGuDriver(EmulatedDriver):
    type = 'HanGuDriver'
    # abstract = True
    cxx_header = 'dev/rdma/hangu_driver.hh'

    device = Param.RdmaNic('HanGu Rnic controlled by this driver')

class RdmaNic(PciDevice):
    type = 'RdmaNic'
    abstract = True
    cxx_header = "dev/rdma/rdma_nic.hh"
    

class HanGuRnic(RdmaNic):
    # class for Han Gu RNIC
    type = 'HanGuRnic'
    cxx_header = "dev/rdma/hangu_rnic.hh"
    mac_addr   = Param.UInt64(0x0, "Ethernet Hardware Address")
    
    interface = EtherInt("Ethernet Interface")
    
    mpt_cache_num = Param.Int(40000,
        "Number of mpt cache enteries")
    mtt_cache_num = Param.Int(50000,
        "Number of mtt cache enteries")
    qpc_cache_cap = Param.Int(100,
        "Number of qpc cache enteries")
    cqc_cache_num = Param.Int(2000,
        "Number of cqc cache enteries")
    
    VendorID = 0x8086
    DeviceID = 0x1075
    SubsystemID = 0x1008
    SubsystemVendorID = 0x8086
    Status = 0x0000
    SubClassCode = 0x00
    ClassCode = 0x02
    ProgIF = 0x00
    BAR0 = 0x00000000
    BAR1 = 0x00000000
    BAR2 = 0x00000000
    BAR3 = 0x00000000
    BAR4 = 0x00000000
    BAR5 = 0x00000000
    MaximumLatency = 0x00
    MinimumGrant = 0xff
    InterruptLine = 0x1e
    InterruptPin = 0x01
    BAR0Size = '1kB'
    
    dma_read_delay = Param.Latency('1000ns', "delay after desc fetch occurs")
    dma_write_delay = Param.Latency('500ns', "delay after desc wb occurs")

    pci_speed = Param.NetworkBandwidth('1Gbps', "pci speed in bits per second")
    ether_speed = Param.NetworkBandwidth('1Gbps', "NIC speed in bits per second")
    
    reorder_cap = Param.Int(100, "Number of concurrent request for one qpc req channel")

    link_delay = Param.Latency('100ns', "ethernet link delay")
    cpu_num    = Param.Int(10, "Number of CPUs in this node")