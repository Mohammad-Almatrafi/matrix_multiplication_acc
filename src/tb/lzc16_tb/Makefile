# Makefile

# defaults
SIM ?= verilator
TOPLEVEL_LANG ?= verilog
EXTRA_ARGS += --trace --trace-structs
SIM_ARGS="+ibex_tracer_file_base=mytrace"
PLUSARGS += +vcd

WAVES = 1
PWD = $(shell pwd)

# verilog sources
VERILOG_SOURCES += $(PWD)/../../modules/fp_utils.sv
VERILOG_SOURCES += $(PWD)/lzc16_wrapper.sv

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = lzc16_wrapper

# MODULE is the basename of the Python test file
MODULE = lzc16_tb

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

