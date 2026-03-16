# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotb.triggers import ReadWrite

def split_byte(x, p):
    x &= 0xFF
    p = (p & 1) << 3
    return ((x >> 7) << 4) | p | ((x >> 4) & 7), ((x >> 3 & 1) << 4) | p | (x & 7)


def signed_overflow_add(a, b):
    r = (a + b) & 0xFF
    return ((a ^ r) & (b ^ r) & 0x80) != 0

def signed_overflow_sub(a, b):
    r = (a - b) & 0xFF
    return ((a ^ b) & (a ^ r) & 0x80) != 0

# Opcode , alu operation, flag 1, flag 0
alu_ops = [
    [0b0010_0001, lambda x,y : (x+y) % 256, lambda x,y : (x + y) % 256 < x, signed_overflow_add, "ADD"],
    [0b0011_0001, lambda x,y : (x-y) % 256, lambda x,y : not x >= y, signed_overflow_sub, "SUB"]
]

@cocotb.test()
async def ALU_test(dut):
    for x in alu_ops:
        await bruteforce_alu_op(dut,x)

async def bruteforce_alu_op(dut, op):
    dut._log.info(f"Running Brutforce of instruction: {op[4]}")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset CPU")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1

    dut._log.info("Start of test")
    # We will load the acc value from virtmem

    async def step(num = 1,d = dut):
        await ClockCycles(d.clk, num)
        await ReadWrite()
        assert dut.uio_oe.value == 0b1111_1111

    await ReadWrite()
    
    assert dut.uio_oe.value == 0b1111_1111
    assert dut.uo_out.value == 0b0000_0010
    assert dut.uio_out.value == 0b0000_0000

    # set address
    dut.ui_in.value = 0b1010_0000

    await ReadWrite()
    assert dut.uio_oe.value == 0b1111_1111
    assert dut.uo_out.value == 0b0000_0010
    assert dut.uio_out.value == 0b0000_0000

    await step()

    assert dut.uo_out.value == 0b0010_0000
    assert dut.uio_out.value == 0b0000_0000

    dut.ui_in.value = 0b1010_0101

    await step()

    assert dut.uo_out.value == 0b0000_0010
    assert dut.uio_out.value == 0b0000_0001

    dut.ui_in.value = 0b1001_0010

    await step()

    assert dut.uo_out.value == 0b0000_0010
    assert dut.uio_out.value == 0b0000_010
    

    for i in range(256):

        print("Working on iteration: ", i, end="\r")
        
        for j in range(256):

            dut.ui_in.value = 0b1010_0010
            await step()
            dut.ui_in.value = i
            await step()

            dut.ui_in.value = 0b1010_1010
            await step()
            dut.ui_in.value = j
            await step()

            dut.ui_in.value = op[0]
            await step()

            dut.ui_in.value = 0b1011_0010
            await step()
            dut.ui_in.value = 0b0000_0000

            assert dut.uio_out.value == 0b1010_0101
            assert int(dut.uo_out.value) & 0b1110_0011 == 0b0100_0001

            await step()

            assert dut.uio_out.value == op[1](i,j)
            assert int(dut.uo_out.value) & 0b1110_0011 == 0b0110_0001
            assert bool(int(dut.uo_out.value) & 0b0000_0100) == op[3](i,j)
            assert bool(int(dut.uo_out.value) & 0b0000_1000) == op[2](i,j)

            await step(2)
            #break
        #break


    await step()

    dut._log.info(f"End of Brutforce of instruction: {op[4]}")


#@cocotb.test()
async def add_test(dut):
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

    dut._log.info("Test Add")
    # We will load the acc value from virtmem

    async def step(num = 1,d = dut):
        await ClockCycles(d.clk, num)
        await ReadWrite()
        assert dut.uio_oe.value == 0b1111_1111

    await ReadWrite()
    
    assert dut.uio_oe.value == 0b1111_1111
    assert dut.uo_out.value == 0b0000_0010
    assert dut.uio_out.value == 0b0000_0000

    # set address
    dut.ui_in.value = 0b1010_0000

    await ReadWrite()
    assert dut.uio_oe.value == 0b1111_1111
    assert dut.uo_out.value == 0b0000_0010
    assert dut.uio_out.value == 0b0000_0000

    await step()

    assert dut.uo_out.value == 0b0010_0000
    assert dut.uio_out.value == 0b0000_0000

    dut.ui_in.value = 0b1010_0101

    await step()

    assert dut.uo_out.value == 0b0000_0010
    assert dut.uio_out.value == 0b0000_0001

    dut.ui_in.value = 0b1001_0010

    await step()

    assert dut.uo_out.value == 0b0000_0010
    assert dut.uio_out.value == 0b0000_010
    
    """
    dut.ui_in.value = 0b0111_0000 # zero acc0

    await step()

    assert dut.uo_out.value == 0b0000_1110
    assert dut.uio_out.value == 0b0000_011
    

    await step()
    """

    for i in range(256):

        print("Working on iteration: ",i)
        
        for j in range(256):

            dut.ui_in.value = 0b1010_0010
            await step()
            dut.ui_in.value = i
            await step()

            dut.ui_in.value = 0b1010_1010
            await step()
            dut.ui_in.value = j
            await step()

            dut.ui_in.value = 0b0010_0001
            await step()

            dut.ui_in.value = 0b1011_0010
            await step()
            dut.ui_in.value = 0b0000_0000

            assert dut.uio_out.value == 0b1010_0101
            assert int(dut.uo_out.value) & 0b1110_0011 == 0b0100_0001

            await step()

            assert dut.uio_out.value == (i + j) % 256
            assert int(dut.uo_out.value) & 0b1110_0011 == 0b0110_0001

            await step(2)
            #break
        #break


    await step()



#@cocotb.test()
async def sub_test(dut):
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

    dut._log.info("Test Add")
    # We will load the acc value from virtmem

    async def step(num = 1,d = dut):
        await ClockCycles(d.clk, num)
        await ReadWrite()
        assert dut.uio_oe.value == 0b1111_1111

    await ReadWrite()
    
    assert dut.uio_oe.value == 0b1111_1111
    assert dut.uo_out.value == 0b0000_0010
    assert dut.uio_out.value == 0b0000_0000

    # set address
    dut.ui_in.value = 0b1010_0000

    await ReadWrite()
    assert dut.uio_oe.value == 0b1111_1111
    assert dut.uo_out.value == 0b0000_0010
    assert dut.uio_out.value == 0b0000_0000

    await step()

    assert dut.uo_out.value == 0b0010_0000
    assert dut.uio_out.value == 0b0000_0000

    dut.ui_in.value = 0b1010_0101

    await step()

    assert dut.uo_out.value == 0b0000_0010
    assert dut.uio_out.value == 0b0000_0001

    dut.ui_in.value = 0b1001_0010

    await step()

    assert dut.uo_out.value == 0b0000_0010
    assert dut.uio_out.value == 0b0000_010
    
    """
    dut.ui_in.value = 0b0111_0000 # zero acc0

    await step()

    assert dut.uo_out.value == 0b0000_1110
    assert dut.uio_out.value == 0b0000_011
    

    await step()
    """

    for i in range(256):

        print("Working on iteration: ",i)
        
        for j in range(256):

            dut.ui_in.value = 0b1010_0010
            await step()
            dut.ui_in.value = i
            await step()

            dut.ui_in.value = 0b1010_1010
            await step()
            dut.ui_in.value = j
            await step()

            dut.ui_in.value = 0b0011_0001
            await step()

            dut.ui_in.value = 0b1011_0010
            await step()
            dut.ui_in.value = 0b0000_0000

            assert dut.uio_out.value == 0b1010_0101
            assert int(dut.uo_out.value) & 0b1110_0011 == 0b0100_0001

            await step()

            assert dut.uio_out.value == (i - j) % 256
            assert int(dut.uo_out.value) & 0b1110_0011 == 0b0110_0001

            await step(2)
            #break
        #break


    await step()





    """
    assert dut.uio_oe.value == 0b1111_1111
    assert dut.uo_out.value == 0b0000_0010
    assert dut.uio_out.value == 0b0000_0000
    """


    # Wait for one clock cycle to see the output values
    #await ClockCycles(dut.clk, 1)

    # The following assersion is just an example of how to check the output values.
    # Change it to match the actual expected output of your module:
    #assert dut.uo_out.value == 50

    # Keep testing the module by changing the input values, waiting for
    # one or more clock cycles, and asserting the expected output values.


#@cocotb.test()
async def and_test(dut):
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

    dut._log.info("Test Add")
    # We will load the acc value from virtmem

    async def step(num = 1,d = dut):
        await ClockCycles(d.clk, num)
        await ReadWrite()
        assert dut.uio_oe.value == 0b1111_1111

    await ReadWrite()
    
    assert dut.uio_oe.value == 0b1111_1111
    assert dut.uo_out.value == 0b0000_0010
    assert dut.uio_out.value == 0b0000_0000

    # set address
    dut.ui_in.value = 0b1010_0000

    await ReadWrite()
    assert dut.uio_oe.value == 0b1111_1111
    assert dut.uo_out.value == 0b0000_0010
    assert dut.uio_out.value == 0b0000_0000

    await step()

    assert dut.uo_out.value == 0b0010_0000
    assert dut.uio_out.value == 0b0000_0000

    dut.ui_in.value = 0b1010_0101

    await step()

    assert dut.uo_out.value == 0b0000_0010
    assert dut.uio_out.value == 0b0000_0001

    dut.ui_in.value = 0b1001_0010

    await step()

    assert dut.uo_out.value == 0b0000_0010
    assert dut.uio_out.value == 0b0000_010
    
    """
    dut.ui_in.value = 0b0111_0000 # zero acc0

    await step()

    assert dut.uo_out.value == 0b0000_1110
    assert dut.uio_out.value == 0b0000_011
    

    await step()
    """

    for i in range(256):

        print("Working on iteration: ",i)
        
        for j in range(256):

            dut.ui_in.value = 0b1010_0010
            await step()
            dut.ui_in.value = i
            await step()

            dut.ui_in.value = 0b1010_1010
            await step()
            dut.ui_in.value = j
            await step()

            dut.ui_in.value = 0b1100_0001
            await step()

            dut.ui_in.value = 0b1011_0010
            await step()
            dut.ui_in.value = 0b0000_0000

            assert dut.uio_out.value == 0b1010_0101
            assert int(dut.uo_out.value) & 0b1110_0011 == 0b0100_0001

            await step()

            assert dut.uio_out.value == i & j
            assert int(dut.uo_out.value) & 0b1110_0011 == 0b0110_0001

            await step(2)
            #break
        #break


    await step()
