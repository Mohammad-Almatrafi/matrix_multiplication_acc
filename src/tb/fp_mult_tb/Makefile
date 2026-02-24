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
VERILOG_SOURCES += $(PWD)/../../modules/lzc.sv
VERILOG_SOURCES += $(PWD)/../../modules/fp_mult.sv
VERILOG_SOURCES += $(PWD)/fp_mult_wrapper.sv

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = fp_mult_wrapper

# MODULE is the basename of the Python test file
MODULE = fp_mult_tb

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

