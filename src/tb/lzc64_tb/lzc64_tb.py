import numpy as np
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

@cocotb.test()
async def lzc64_test(dut):
    print("--------------------------------------------------")
    fails = 0
    datain_init = np.uint64(0xFFFFFFFFFFFFFFFF)
    for i in range(65):
        datain = datain_init >> i
        zero_count_expected, all_zeros_expected = check(datain = datain)
        await Timer(1, unit="ns")
        dut.datain.value = int(datain)
        await Timer(1, unit="ns")
        zero_count_module = dut.zero_count.value.to_unsigned()
        all_zeros_module = int(dut.all_zeros.value)
        if (zero_count_expected != zero_count_module or all_zeros_expected != all_zeros_module):

            fails += 1
            print(f"test number {i}")
            print(f"datain              : {np.binary_repr(datain, 64)}")
            print(f"zero_count_expected : {zero_count_expected}")
            print(f"zero_count_module   : {zero_count_module}")
            print(f"all_zeros_expected  : {all_zeros_expected}")
            print(f"all_zeros_module    : {all_zeros_module}")
            print("--------------------------------------------------")

    if(fails > 0):
        print(f"module failed {fails} times")
        assert False
    # Simulation ends
    dut._log.info("Simulation complete")


def check(datain):
    all_zeros = 1 if datain == 0 else 0
    zero_count = 0
    k = datain
    for i in range(63):
        if(((k << i)  & 0x8000000000000000) == 0):
            zero_count += 1
        else:
            break

    return zero_count,all_zeros
