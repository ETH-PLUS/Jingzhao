.PHONY: com debug run clean

# variables
OUTPUT = hca_test
TEST_NAME = test_direct_param
CASE_NAME = test_direct
VPD_NAME = wave2.vpd

# commands
com:
	vcs -sverilog -ntb_opts uvm \
	-debug_access+all -lca \
	-picarchive -full64 -timescale=1ns/100ps \
	+acc +vpi \
	+memcbk \
	+warn=none \
	+nospecify \
	+define+UVM_OBJECT_MUST_HAVE_CONSTRUCTOR+UVM_USE_CALLBACKS_OBJECTION_FOR_TEST_DONE \
	+define+UVM_REG_DATA_WIDTH=256 \
	+define+FPGA_SIM \
    +define+CFG_SIM \
	+define+TD \
	-l compile.log \
	-f filelist-htn.f -o ${OUTPUT}

# debug command generates .vpd waveform file supported by DVE
debug:
	./${OUTPUT} -gui -uvmDebug +vpdfile+./run_case.vpd +UVM_VERDI_TRACE=HIER +UVM_VERBOSITY=UVM_LOW +UVM_TESTNAME=${TEST_NAME} \
				+HOST_NUM=2 \
				+PROC_NUM=2 \
				+DB_NUM=1 \
				+SG_NUM=2 \
				+DATA_CNT=32769 \
				+DATA_UNIT=B \
				+RC_QP_NUM=18 \
				+UC_QP_NUM=0 \
				+UD_QP_NUM=0 \
				+WRITE_WQE_NUM=1 \
				+READ_WQE_NUM=1 \
				+SEND_WQE_NUM=1 \
				+RECV_WQE_NUM=1 \
                +CASEID=932 \
				-l run_case.log 

# run command generates .log file without the waveform
run:
	./${OUTPUT} -uvmDebug +vpdfile+4KB.vpd +UVM_VERDI_TRACE=HIER +UVM_VERBOSITY=UVM_LOW +UVM_TESTNAME=${TEST_NAME} \
				+HOST_NUM=2 \
				+PROC_NUM=2 \
				+DB_NUM=1 \
				+SG_NUM=1 \
				+DATA_CNT=4 \
				+DATA_UNIT=KB \
				+RC_QP_NUM=2 \
				+UC_QP_NUM=0 \
				+UD_QP_NUM=0 \
				+WRITE_WQE_NUM=1 \
				+READ_WQE_NUM=1 \
				+SEND_WQE_NUM=1 \
				+RECV_WQE_NUM=1 \
                +CASEID=949 \
				-l run.log 

clean:
	rm -rf ${OUTPUT} *.vpd stack.info* session.inter.vpd.tcl csrc DVEfiles *.fsdb novas* *.daidir ucli.key vc_hdrs.h verdiLog flex* inter*
