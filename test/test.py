# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotb.triggers import ReadWrite


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

    # Set the input values you want to test
    #dut.ui_in.value = 20
    #dut.uio_in.value = 30


    await ReadWrite()
    #await ClockCycles(dut.clk, 10)

    instr_mem = [0b0001_0001,0b1011_0000]

    assert dut.uio_oe.value == 0b1111_1111
    assert dut.uo_out.value == 0b0000_0010
    assert dut.uio_out.value == 0b0000_0000

    dut.ui_in.value = instr_mem[0]

    await ClockCycles(dut.clk, 1)

    assert dut.uio_oe.value == 0b1111_1111
    assert dut.uo_out.value == 0b0000_0010
    assert dut.uio_out.value == 0b0000_0001

    dut.ui_in.value = instr_mem[1]

    assert dut.uio_oe.value == 0b1111_1111
    assert dut.uo_out.value == 0b0000_0010
    assert dut.uio_out.value == 0b0000_0001

    await ReadWrite()

    assert dut.uio_oe.value == 0b1111_1111
    assert dut.uo_out.value == 0b0000_0010
    assert dut.uio_out.value == 0b0000_0010

    await ClockCycles(dut.clk, 2)


    # Wait for one clock cycle to see the output values
    #await ClockCycles(dut.clk, 1)

    # The following assersion is just an example of how to check the output values.
    # Change it to match the actual expected output of your module:
    #assert dut.uo_out.value == 50

    # Keep testing the module by changing the input values, waiting for
    # one or more clock cycles, and asserting the expected output values.
