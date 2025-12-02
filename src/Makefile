PWD = $(shell pwd)

logs_and_waves:
	mkdir -p logs_and_waves

output:
	mkdir -p output

tb_run:
	cd tb && make

clean:
	rm -rf tb/sim_build tb/__pycache__ tb/results.xml tb/dump.vcd

