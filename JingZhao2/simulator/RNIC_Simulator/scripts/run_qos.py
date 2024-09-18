import os
import time
import sys

SERVER_LID  = 10

NUM_CPUS  = 2
CPU_CLK   = "4GHz"
EN_SPEED  = "100Gbps"
PCI_SPEED = "128Gbps"

WRITE = 0
READ = 1

class Param():
    def __init__(self, num_nodes, qpc_cache_cap, reorder_cap, op_mode, test_case):
        self.num_nodes     = num_nodes
        self.qpc_cache_cap = qpc_cache_cap
        self.reorder_cap   = reorder_cap
        self.op_mode       = op_mode
        self.test_case     = test_case


def cmd_run_sim(debug, test_prog, option, params):
    '''
    Generate simulation running command
    '''

    cmd = "cd ../ && build/X86/gem5.opt"

    # Add debug options
    if debug != "":
        debug = " --debug-flags=" + debug
    cmd += debug

    # execution script
    cmd += " configs/example/rdma/hangu_rnic_se.py"
    cmd += " --cpu-clock " + CPU_CLK
    cmd += " --num-cpus " + str(NUM_CPUS)
    cmd += " -c " + test_prog
    cmd += " -o " + option
    cmd += " --node-num " + str(params.num_nodes)
    cmd += " --ethernet-linkspeed " + EN_SPEED
    cmd += " --pci-linkspeed "  + PCI_SPEED
    cmd += " --qpc-cache-cap "  + str(params.qpc_cache_cap)
    cmd += " --reorder-cap "    + str(params.reorder_cap)
    cmd += " --mem-size 2048MB"
    cmd += " > scripts/" + params.test_case + ".txt"

    return cmd

def execute_program(debug, test_prog, option, params):

    # compile Gem-5
    cmd_list = [
        # "cd ../tests/test-progs/hangu-rnic/src && make",
        # "cd ../ && scons build/X86/gem5.opt"
    ]
    # record start time
    cmd_list.append("echo $(date +%Y-%m-%d/%H:%M:%S)")
    # run simulation
    cmd_list.append(cmd_run_sim(debug, test_prog, option, params))
    #record end time
    cmd_list.append("echo $(date +%Y-%m-%d/%H:%M:%S)")

    # execute cmd_list sequentially
    for cmd in cmd_list:
        print(cmd)
        rtn = os.system(cmd)
        if rtn != 0:
            raise Exception("\033[0;31;40mError for cmd " + cmd + "\033[0m")
        time.sleep(0.1)

def main():

    if (len(sys.argv) != 2):
        print("Illegal parameter!")
        return
    else:
        testcase = sys.argv[1]

    params = Param(2, 100, 64, WRITE, testcase)

    num_nodes = params.num_nodes
    svr_lid = SERVER_LID

    debug = ""
    debug = "HanGuDriver"
    debug += ",CxtResc"
    debug = "PioEngine,CcuEngine,MrResc,HanGuDriver,RescCache,Ethernet,RdmaEngine,"
    debug +="HanGuRnic,CxtResc,DmaEngine,"
    debug +="DescScheduler"

    # add server program
    test_prog = "'tests/test-progs/hangu-rnic/src/" + testcase + "/server"
    opt = "'-s " + str(svr_lid) + " -t " + str(num_nodes - 1) + " -m " + str(params.op_mode)

    # add client program to test_prog
    for i in range(num_nodes - 1):
        test_prog += ";tests/test-progs/hangu-rnic/src/" + testcase + "/client"
        opt += ";-s " + str(svr_lid) + " -l " + str(svr_lid + i + 1) + " -t " + str(num_nodes - 1) + " -m " + str(params.op_mode)
    test_prog += "'"
    opt += "'"

    return execute_program(debug=debug, test_prog=test_prog, option=opt, params=params)

if __name__ == "__main__":
    main()
