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
#  Primary Author: Kang Ning
#  <kangning18z@ict.ac.cn>
# 


from __future__ import print_function
from __future__ import absolute_import

import optparse
import sys
import os

import m5
from m5.defines import buildEnv
from m5.objects import *
from m5.params import NULL
from m5.util import addToPath, fatal, warn

from m5.objects.PciHost import *
from m5.objects.Rnic import HanGuRnic, HanGuDriver


addToPath('../../')

from common import Options
from common import Simulation
from common import CacheConfig
from common import CpuConfig
from common import ObjectList
from common import MemConfig
from common.FileSystemConfig import config_filesystem
from common.Caches import *
from common.cpu2000 import *

def get_processes(options, system, rdma_driver, idx, node_num=0):
    """
    Interprets provided options and returns a list of processes
    """

    inputs = []
    outputs = []
    errouts = []

    # Get cmd from input
    cmd = options.cmd.split(';')
    if len(cmd) < options.node_num:
        fatal("Too few cmds!")
        sys.exit(1)
    workloads = [cmd[node_num]]

    # Get options from input
    opt = options.options.split(';')
    if len(opt) < options.node_num:
        fatal("Too few opts!")
        sys.exit(1)
    pargs = opt[node_num]

    # if options.input != "":
    #     inputs = options.input.split(';')
    #     process.input = inputs[0]

    # if options.output != "":
    #     outputs = options.output.split(';')
    #     process.output = outputs[0]

    # if options.errout != "":
    #     errouts = options.errout.split(';')
    #     process.errout = errouts[0]

    # print(pargs.split())

    process = Process(pid = 100 + idx)
    process.executable = workloads[0] # the location of the program
    process.cwd = os.getcwd()
    process.cmd = [workloads[0]] + pargs.split() + ['-c', str(idx)]
    process.drivers = [rdma_driver]

    print(process.executable)
    print(process.cmd)

    if options.env:
        with open(options.env, 'r') as f:
            process.env = [line.rstrip() for line in f]

    return process

def config_rnic(system, options, node_num):
    """
    Add rdma nic to the system.
    """
    # North Bridge
    system.iobus  = IOXBar()
    system.iobridge = Bridge(delay='250ns')
    system.iobridge.master = system.iobus.slave
    system.iobridge.slave  = system.membus.master

    # Allow the bridge to pass through:
    #  1) kernel configured PCI device memory map address: address range
    #     [0xC0000000, 0xFFFF0000). (The upper 64kB are reserved for m5ops.)
    #  2) the bridge to pass through the IO APIC (two pages, already contained in 1),
    #  3) everything in the IO address range up to the local APIC, and
    #  4) then the entire PCI address space and beyond.
    IO_address_space_base = 0x8000000000000000
    pci_config_address_space_base = 0xc000000000000000
    interrupts_address_space_base = 0xa000000000000000
    system.iobridge.ranges = \
        [
        AddrRange(0xC0000000, 0xFFFF0000),
        AddrRange(IO_address_space_base,
                  interrupts_address_space_base - 1),
        AddrRange(pci_config_address_space_base,
                  Addr.max)
        ]
    system.dmabridge = Bridge(delay='250ns',
                       ranges = system.mem_ranges)
    system.dmabridge.slave = system.iobus.master
    system.dmabridge.master = system.membus.slave

    # Get input param
    opt = options.options.split(';')
    if len(opt) < options.node_num:
        fatal("Too few opts!")
        sys.exit(1)
    in_pargs = opt[node_num].split()

    # Parse input pargs
    svr_mac = 0
    clt_mac = 0
    for i in range(len(in_pargs)):
        if in_pargs[i] == "-s":
            svr_mac = int(in_pargs[i+1])
        elif in_pargs[i] == "-l":
            clt_mac = int(in_pargs[i+1])

    # Get mac_addr
    if node_num == 0:
        mac_addr = svr_mac
    else:
        mac_addr = clt_mac

    system.platform = RnicPlatform()
    system.platform.rdma_nic.mac_addr = mac_addr
    system.platform.rdma_nic.pci_speed     = options.pci_linkspeed
    system.platform.rdma_nic.ether_speed   = options.ethernet_linkspeed
    system.platform.rdma_nic.qpc_cache_cap = options.qpc_cache_cap
    system.platform.rdma_nic.reorder_cap   = options.reorder_cap
    system.platform.rdma_nic.cpu_num       = options.num_cpus
    
    system.platform.attachIO(system.iobus)
    system.intrctrl = IntrControl()


def make_hangu_nic_system(options, CPUClass, test_mem_mode, node_id):

    system = System(cpu = [CPUClass(socket_id=i, cpu_id=i, numThreads=1, syscallRetryLatency=200) for i in range(options.num_cpus)],
                    mem_mode = test_mem_mode,
                    mem_ranges = [AddrRange(options.mem_size)],
                    cache_line_size = options.cacheline_size,
                    workload = NULL)

    # Create a top-level voltage domain
    system.voltage_domain = VoltageDomain(voltage = options.sys_voltage)

    # Create a source clock for the system and set the clock period
    system.clk_domain = SrcClockDomain(clock =  options.sys_clock,
                                    voltage_domain = system.voltage_domain)

    # Create a CPU voltage domain
    system.cpu_voltage_domain = VoltageDomain()

    # Create a separate clock domain for the CPUs
    system.cpu_clk_domain = SrcClockDomain(clock = options.cpu_clock,
                                        voltage_domain =
                                        system.cpu_voltage_domain)

    # If elastic tracing is enabled, then configure the cpu and attach the elastic
    # trace probe
    if options.elastic_trace_en:
        CpuConfig.config_etrace(CPUClass, system.cpu, options)

    # All cpus belong to a common cpu_clk_domain, therefore running at a common
    # frequency.
    for cpu in system.cpu:
        cpu.clk_domain = system.cpu_clk_domain

    MemClass = Simulation.setMemClass(options)
    system.membus = SystemXBar()
    system.system_port = system.membus.cpu_side_ports
    CacheConfig.config_cache(options, system)
    MemConfig.config_mem(options, system)
    config_filesystem(system, options)

    # Configure RDMA NIC
    config_rnic(system, options, node_id)

    if options.cmd:
        
        for i in range(options.num_cpus):
            rdma_driver = HanGuDriver(filename="hangu_rnic"+str(i))
            rdma_driver.device = system.platform.rdma_nic
            process = get_processes(options, system, rdma_driver, i, node_id)
            system.cpu[i].workload = process
            system.cpu[i].createThreads()
    else:
        print("No workload specified. Exiting!\n", file=sys.stderr)
        sys.exit(1)

    if options.wait_gdb:
        for cpu in system.cpu:
            cpu.wait_for_remote_gdb = True

    return system


def make_root_system(rnicsys, en_bw):
    self = Root(full_system = False)
    self.svrsys = rnicsys[0]
    self.cltsys = rnicsys[1:]

    self.etherswitch = EtherSwitch()
    self.etherswitch.fabric_speed = en_bw
    self.etherswitch.delay = "0us" # We don't use the delay mechanism in etherswitch
    self.etherswitch.time_to_live = "100s" # don't consider MAC addr mapping TTL
    for i in range(len(rnicsys)):
        self.etherswitch.interface = rnicsys[i].platform.rdma_nic.interface

    return self

def get_hangu_rnic_options():
    parser = optparse.OptionParser()
    Options.addCommonOptions(parser)
    Options.addSEOptions(parser)
    parser.add_option("--node-num", type="int", action="store", default=2,
                      help="""The options to pass to the binary, use " "
                              around the entire string""")
    parser.add_option("--pci-linkspeed", default="10Gbps",
                        action="store", type="string",
                        help="Link speed in bps\nDEFAULT: 10Gbps")
    parser.add_option("--qpc-cache-cap", default=50,
                        action="store", type="int",
                        help="capacity of qpc cache\nDEFAULT: 50 entries")
    parser.add_option("--reorder-cap", default=100,
                        action="store", type="int",
                        help="capacity of qpc cache\nDEFAULT: 50 entries")

    (options, args) = parser.parse_args()

    if args:
        print("Error: script doesn't take any positional arguments")
        sys.exit(1)

    print(options)
    return options


def main():
    # Add options
    options = get_hangu_rnic_options()

    (CPUClass, test_mem_mode, FutureClass) = Simulation.setCPUClass(options)

    # Check -- do not allow SMT with multiple CPUs
    if options.smt and options.num_cpus > 1:
        fatal("You cannot use SMT with multiple CPUs!")

    if options.node_num < 2:
        fatal("Too few nodes!")
        sys.exit(1)

    # # input ethernet and pci link speed
    # en_bw  = options.ethernet_linkspeed
    # pci_bw = options.pci_linkspeed
    # qpc_cache_cap = options.qpc_cache_cap
    # reorder_cap   = options.reorder_cap

    rnic_sys = []
    for i in range(options.node_num):
        rnic_sys.append(make_hangu_nic_system(options, CPUClass, test_mem_mode, i))

    root = make_root_system(rnic_sys, options.ethernet_linkspeed)
    # root: the whole system including all nodes
    Simulation.run(options, root, root.svrsys, FutureClass)

if __name__ == "__m5_main__":
    main()