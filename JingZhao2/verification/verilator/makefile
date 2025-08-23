# Makefile
VERILATOR = verilator
VERILATOR_FLAGS = --cc --exe -O2 --trace --bbox-unsup

# 顶层模块名称（对应 testbench 中的 VCounter）
TOP = hca_tb_top

# Verilog 源文件
VERILOG = $(shell find ../../hardware/hdl -name "*.v" -o -name "*.h" -o -name "*.vh")

# C++ testbench
TB = testbench.cpp

all: sim

# 生成 C++ 仿真源并编译
sim: obj_dir/V$(TOP)
	$(MAKE) -C obj_dir -f V$(TOP).mk
	./obj_dir/V$(TOP)

# 由 Verilator 生成 obj_dir/VCounter.mk
obj_dir/V$(TOP):
	$(VERILATOR) $(VERILATOR_FLAGS) -top-module $(TOP) $(VERILOG) $(TB)

clean:
	rm -rf obj_dir waveform.vcd

.PHONY: all sim clean
