import numpy as np
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

def write_log_file(f ,src1, src2, expected, output,sim_time, sign_bool):
    A_sign       = np.binary_repr(src1.view(np.uint32) >> 31 & 1,1)
    A_mantissa   = np.binary_repr(src1.view(np.uint32) >> 0 & 0x7FFFFF,23)
    A_exponent   = np.binary_repr(src1.view(np.uint32) >> 23 & 0xFF,8)
    B_sign       = np.binary_repr(src2.view(np.uint32) >> 31 & 1,1)
    B_exponent   = np.binary_repr(src2.view(np.uint32) >> 23 & 0xFF,8)
    B_mantissa   = np.binary_repr(src2.view(np.uint32) >> 0 & 0x7FFFFF,23)

    expected_sign     = np.binary_repr(np.uint32(expected) >> 31 & 1,1)
    expected_exponent = np.binary_repr(np.uint32(expected) >> 23 & 0xFF,8)
    expected_mantissa = np.binary_repr(np.uint32(expected) >> 0 & 0x7FFFFF,23)
    output_sign       = np.binary_repr(np.uint32(output) >> 31 & 1,1)
    output_exponent   = np.binary_repr(np.uint32(output) >> 23 & 0xFF,8)
    output_mantissa   = np.binary_repr(np.uint32(output) >> 0 & 0x7FFFFF,23)


    f.write(f"simulation_time: {sim_time}\n")
    if sign_bool:
        f.write(f"sign difference\n")
    f.write("module output:\n")
    f.write(f"{src1} + {src2} = {np.uint32(output).view(np.float32)}\n")
    f.write("expected output:\n")
    f.write(f"{src1} + {src2} = {np.uint32(expected).view(np.float32)}\n")

    f.write(f"src1                 : sign: {A_sign}," +
            f" exponent: {A_exponent}, mantissa: {A_mantissa}\n")
    f.write(f"src2                 : sign: {B_sign}," +
            f" exponent: {B_exponent}, mantissa: {B_mantissa}\n")
    f.write(f"bin module output    : sign: {output_sign}," +
            f" exponent: {output_exponent}, mantissa: {output_mantissa}\n")
    f.write(f"bin expected output  : sign: {expected_sign}," +
            f" exponent: {expected_exponent}, mantissa: {expected_mantissa}\n")
    f.write("---------------------------------------------------\n")

@cocotb.test()
async def fp_add_test(dut):
    # floating_max = np.finfo(np.float32).max * 0.5
    # floating_min = -np.finfo(np.float32).max * 0.5
    # floating_min = np.float32(-1)
    # floating_max = np.float32(1)
    
    floating_min = -np.finfo(np.float32).tiny * 2
    floating_max = np.finfo(np.float32).tiny * 2
    count = 0
    iterations = 5**4
    is_fail = False
    diff_count = 0
    dut.A.value = 0
    dut.B.value = 0
    rng = np.random.default_rng(42)
    with open("fp_add_test.log", "w") as f:
        for _ in range(iterations):
            await Timer(1, unit="ns")
            x1 = rng.uniform(np.float64(floating_min), np.float64(floating_max))
            x2 = rng.uniform(np.float64(floating_min), np.float64(floating_max))
            src1 = np.float32(x1)
            src2 = np.float32(x2)
            dut.A.value = int(src1.view(np.uint32))
            dut.B.value = int(src2.view(np.uint32))
            expected = src1+src2
            expected = int(expected.view(np.uint32))
            await Timer(1, unit="ns")
            output = dut.Y.value.to_unsigned()
            sim_time = cocotb.simtime.get_sim_time(unit = 'ns')
            sim_time = int(sim_time)

            if int(dut.Y.value) != expected:
                is_fail = True
                count += 1
                sign_diff = (src1.view(np.uint32) >> 31 & 1) ^ (src2.view(np.uint32) >> 31 & 1)
                sign_bool = sign_diff == 1
                f.write(f"FAIL:\n")
                write_log_file(f,src1, src2, expected, output,sim_time,sign_bool)
                diff_count += sign_diff

            else:
                f.write(f"PASS:\n")
                sign_bool = False
                write_log_file(f,src1, src2, expected, output,sim_time, sign_bool)

        f.write(f"tests passed: {iterations-count}\n" +
                f"tests failed: {count}\n")
        f.write(f"different signs fails: {diff_count}\n")

    if(is_fail):
        assert False
    # Simulation ends
    dut._log.info("Simulation complete")

