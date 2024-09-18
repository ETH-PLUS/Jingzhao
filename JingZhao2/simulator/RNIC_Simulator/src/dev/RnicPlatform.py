# 
# ====================== START OF LICENSE NOTICE =======================
#  Copyright (C) 2021 Kang Ning, NCIC, ICT, CAS.
#  All Rights Reserved.
# 
#  NO WARRANTY. THE PRODUCT IS PROVIDED BY DEVELOPER "AS IS" AND ANY
#  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
#  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL DEVELOPER BE LIABLE FOR
#  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
#  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
#  GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
#  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
#  IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THE PRODUCT, EVEN
#  IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# ======================= END OF LICENSE NOTICE ========================
#   Primary Author: Kang Ning
#       <kangning18z@ict.ac.cn>
#   Date: 2021.07.08


from m5.params import *
from m5.proxy import *

from m5.objects.Rnic import HanGuRnic
from m5.objects.Platform import Platform
from m5.objects.PciHost import GenericPciHost


class RnicPciHost(GenericPciHost):
    conf_base = 0xC000000000000000
    conf_size = "16MB"

    pci_pio_base = 0x8000000000000000

class RnicPlatform(Platform):
    type = 'RnicPlatform'
    cxx_header = "dev/rnicPlatform.hh"

    system = Param.System(Parent.any, "system")

    pci_host = RnicPciHost()

    rdma_nic = HanGuRnic(pci_bus=0, pci_dev=0, pci_func=0)
    
    def attachIO(self, bus):
        self.pci_host.pio = bus.default
        self.rdma_nic.pio = bus.mem_side_ports
        self.rdma_nic.dma = bus.cpu_side_ports
        
