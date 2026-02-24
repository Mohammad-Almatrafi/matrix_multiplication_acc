import numpy as np
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

def float_equal(a, b):
    if np.isnan(a) and np.isnan(b):
        return True
    return a == b



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
    f.write(f"{src1} * {src2} = {np.uint32(output).view(np.float32)}\n")
    f.write("expected output:\n")
    f.write(f"{src1} * {src2} = {np.uint32(expected).view(np.float32)}\n")

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
    # floating_max = np.finfo(np.float32).max
    # floating_min = -np.finfo(np.float32).max
    # floating_min = np.float32(-1)
    # floating_max = np.float32(1)
    
    floating_min = -np.finfo(np.float32).tiny * 2
    floating_max = np.finfo(np.float32).tiny * 2
    count = 0
    file_name = "fp_mult_test.log"
    iterations = int(10**7 * 0.5)
    # iterations = 1
    is_fail = False
    diff_count = 0
    normal_count = 0
    dut.A.value = 0
    dut.B.value = 0
    rng = np.random.default_rng(42)
    with open(file_name, "w") as f:
        for i in range(iterations):
            await Timer(1, unit="ns")
            # x1 = rng.uniform(np.float64(floating_min), np.float64(floating_max))
            # x2 = rng.uniform(np.float64(floating_min), np.float64(floating_max))
            x1 = rng.integers(0, 2**32, dtype=np.uint32)
            x2 = rng.integers(0, 2**32, dtype=np.uint32)
            # x1_man = np.uint32(0x7FFFFF)
            # x1_exp = np.uint32(0x0)
            # x1_sign = np.uint32(0x0)
            # x2_man = np.uint32(0x0)
            # x2_exp = np.uint32(0xF0)
            # x2_sign = np.uint32(0x0)

            # x1 = x1_man | x1_exp << 23 | x1_sign << 31
            # x2 = x2_man | x2_exp << 23 | x2_sign << 31

            x1 = x1.view(np.float32)
            x2 = x2.view(np.float32)
            # x1 = x1.view(np.float32)
            # x2 = x2.view(np.float32)
            src1 = np.float32(x1)
            src2 = np.float32(x2)
            dut.A.value = int(src1.view(np.uint32))
            dut.B.value = int(src2.view(np.uint32))
            expected = src2 * src1
            await Timer(1, unit="ns")
            output = dut.Y.value.to_unsigned()
            output_comp = np.uint32(int(output)).view(np.float32)
            
            sim_time = cocotb.simtime.get_sim_time(unit = 'ns')
            sim_time = int(sim_time)
            compare = float_equal(output_comp, expected)
            compare = not compare


            expected = int(expected.view(np.uint32))

            if compare:
                is_fail = True
                count += 1
                sign_diff = (src1.view(np.uint32) >> 31 & 1) ^ (src2.view(np.uint32) >> 31 & 1)
                sign_bool = sign_diff == 1
                f.write(f"FAIL:\n")
                write_log_file(f,src1, src2, expected, output,sim_time,sign_bool)
                diff_count += sign_diff


            # else:
            #     f.write(f"PASS:\n")
            #     sign_bool = False
            #     write_log_file(f,src1, src2, expected, output,sim_time, sign_bool)

        f.write(f"tests passed: {iterations-count}\n" +
                f"tests failed: {count}\n")
        f.write(f"different signs fails: {diff_count}\n")
        f.write(f"different normalization fails: {normal_count}\n")

    if(is_fail):
        assert False
    # Simulation ends
    dut._log.info("Simulation complete")

