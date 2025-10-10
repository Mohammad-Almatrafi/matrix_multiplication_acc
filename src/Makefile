PWD = $(shell pwd)

# sources to lint
LINT_SRCS:= 

logs_and_waves:
	mkdir -p logs_and_waves

output:
	mkdir -p output

tb_run: gen_mem_files
	cd src/tb && make

clean:
	rm -rf logs_and_waves src/tb/sim_build src/tb/__pycache__

lint:
	verilator --top rv32i_top -Wall --lint-only $(LINT_SRCS) --Wno-DECLFILENAME

