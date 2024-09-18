import os
import time
import datetime

CLIENT_NUM = 1
QP_CACHE_CAP = 300
REORDER_CAP  = 64
# QP_NUM_LIST = [512, 256, 128, 64, 32, 16, 8, 4, 2, 1] # 1, 2, 4, 8, 16, 32, 64, 128, 256, 512
QP_NUM_LIST = [1]

WR_TYPE = 0 # 0 -  rdma write; 1 - rdma read
PCIE_TYPE = "X16"
VERSION = "V1.5-final"
RECORD_FILENAME = "res_out/record-" + VERSION + "_QP_CACHE_CAP" + str(QP_CACHE_CAP) + "RECAP" + str(REORDER_CAP) + ".txt"

def change_param(qps_per_clt):
    file_data = ""
    with open("../tests/test-progs/hangu-rnic/src/librdma.h", "r", encoding="utf-8") as f:
        for line in f:
            if "#define TEST_QP_NUM" in line:
                line = "#define TEST_QP_NUM   " + str(qps_per_clt) + "\n"
            file_data += line

    with open("../tests/test-progs/hangu-rnic/src/librdma.h", "w", encoding="utf-8") as f:
        f.write(file_data)
    
    file_data = ""
    with open("../src/dev/rdma/hangu_rnic_defs.hh", "r", encoding="utf-8") as f:
        for line in f:
            if "#define QPN_NUM" in line:
                line = "#define QPN_NUM   (" + str(qps_per_clt) + " * " + str(CLIENT_NUM) + ")\n"
            file_data += line

    with open("../src/dev/rdma/hangu_rnic_defs.hh", "w", encoding="utf-8") as f:
        f.write(file_data)


def execute_program(node_num, qpc_cache_cap, reorder_cap):
    return os.system("python3 run_hangu.py " + str(node_num) + " " + str(qpc_cache_cap) + " " + str(reorder_cap) + " " + str(WR_TYPE))

def print_result(file_name, qps_per_clt):
    bandwidth = 0
    msg_rate  = 0
    latency   = 0
    cnt = 0
    with open("res_out/rnic_sys_test.txt") as f:
        for line in f.readlines():
            if "start time" in line:
                bandwidth += float(line.split(',')[2].strip().split(' ')[1]) # .split(' ')[2]
                msg_rate  += float(line.split(',')[3].strip().split(' ')[1]) # .split(' ')[2]
                latency   += float(line.split(',')[4].strip().split(' ')[1])
                cnt += 1
    
    bandwidth = round(bandwidth, 2)
    msg_rate  = round(msg_rate , 2)
    latency   = round(latency/(cnt*1000.0), 2)

    res_data = "==========================================\n"
    res_data += str(qps_per_clt) + " QPs * " + str(CLIENT_NUM) + " clients * " +  str(cnt) + " CPU_NUM = " + str(qps_per_clt * CLIENT_NUM * cnt) + "\n"
    if WR_TYPE == 1:
        res_data += "RDMA READ\n"
    else:
        res_data += "RDMA WRITE\n"
    res_data += "QPS_PER_CLT " + str(qps_per_clt) + "\n"
    
    res_data += "CPU_NUM     " + str(cnt) + "\n"
    res_data += "bandwidth   " + str(bandwidth) + " MB/s\n"
    res_data += "msg_rate    " + str(msg_rate ) + " Mops/s\n"
    res_data += "latency     " + str(latency  ) + " us\n"
    res_data += "==========================================\n\n"

    with open(file_name, "a+", encoding="utf-8") as f:
        f.write(res_data)
    
    return bandwidth, msg_rate, latency

def main():

    bandwidth = []
    msg_rate  = []
    latency   = []

    for qps_per_clt in QP_NUM_LIST:
        # Change parameter realted to the simulation
        change_param(qps_per_clt)

        # execute the program
        print("=============================================")
        print("qps_per_clt is : %d" % (qps_per_clt))
        print("=============================================\n\n\n\n")
        if execute_program(CLIENT_NUM + 1, QP_CACHE_CAP, REORDER_CAP) != 0:
            print("\033[0;31;40mProgram execution error! %d\033[0m" % (qps_per_clt))
            return 1
        
        # Get results
        bw, mr, lat = print_result(RECORD_FILENAME, qps_per_clt)
        bandwidth.append(bw)
        msg_rate.append(mr)
        latency.append(lat)

    print(QP_NUM_LIST)
    print(bandwidth)
    print(msg_rate)
    print(latency)
    with open(RECORD_FILENAME, "a+", encoding="utf-8") as f:
        f.write(" ".join(list(map(str, QP_NUM_LIST))))
        f.write("\n")
        f.write(" ".join(list(map(str, bandwidth))))
        f.write("\n")
        f.write(" ".join(list(map(str, msg_rate))))
        f.write("\n")
        f.write(" ".join(list(map(str, latency))))
        f.write("\n")

if __name__ == "__main__":
    main()
