PWD = $(shell pwd)

build:
	mkdir -p tb/build

logs_and_waves:
	mkdir -p logs_and_waves

output:
	mkdir -p output

fp_add_tb_run:
	cd tb/fp_add_tb && make

lzc4_tb_run:
	cd tb/fp_add_tb && make

lzc16_tb_run:
	cd tb/fp_add_tb && make

lzc64_tb_run:
	cd tb/fp_add_tb && make

clean:
	rm -rf tb/sim_build tb/__pycache__ tb/results.xml tb/dump.vcd
