# Copyright Antmicro 2023
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer, Event, Lock
from cocotb.queue import Queue

import random
import logging

import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import tlul

# ==============================================================================


class MemoryModel:
    """
    A ROM/RAM memory model
    """

    SIGNALS = {
        "clk",
        "rst_n",

        "req",
        "we",
        "addr",
        "wdata",
        "wmask",

        "gnt",
        "valid",
        "rdata",
        "error",
    }

    def __init__(self, signals, size_bits=10, read_only=False):

        # Check if we have all signals
        missing = False
        for name in self.SIGNALS:
            if name not in signals:
                logging.critical("missing '{}'".format(name))
                missing = True

        assert missing is False

        self.signals   = signals
        self.size_bits = size_bits
        self.read_only = read_only

        self.storage   = dict()

    async def process(self):

        while True:
            await RisingEdge(self.signals["clk"])

            self.signals["gnt"].value   = 1
            self.signals["valid"].value = 0
            self.signals["error"].value = 0

            # Request
            if self.signals["req"].value == 1:
                addr = self.signals["addr"].value % (1 << self.size_bits)

                # Write
                if self.signals["we"].value:

                    # RAM, do the write
                    if not self.read_only:
                        data = self.signals["wdata"].value
                        mask = self.signals["wmask"].value

                        # TODO: use mask
                        self.storage[addr] = data

                    # ROM, signal error
                    else:
                        self.signals["error"].value = 2 # Recoverable

                # Read
                else:
                    data = self.storage.get(addr, 0)
                    self.signals["rdata"].value = data
                    self.signals["valid"].value = 1

                # Wait at random
                for i in range(random.randint(0, 10)):
                    self.signals["gnt"].value = 0
                    await RisingEdge(self.signals["clk"])
                self.signals["gnt"].value = 1

# ==============================================================================

def text2mem(text):
    """
    Encodes a string as 32-bit words
    """

    # Encode
    text = text.encode()

    # Pad to 4 bytes
    lnt  = ((len(text) + 3) // 4) * 4
    pad  = lnt - len(text)
    text = text + bytes(pad)

    # Encode words
    words = []
    for i in range(lnt // 4):
        w  = text[4*i + 0] << 24
        w |= text[4*i + 1] << 16
        w |= text[4*i + 2] << 8
        w |= text[4*i + 3]
        words.append(w)

    return words

def mem2text(words):
    """
    Decodes a string from 32-bit words
    """

    # Decode bytes
    b = bytearray()
    for w in words:
        b.append((w >> 24) & 0xFF)
        b.append((w >> 16) & 0xFF)
        b.append((w >>  8) & 0xFF)
        b.append((w      ) & 0xFF)

    # Decode text
    text = b.decode()
    return text

# ==============================================================================


async def setup_interfaces(dut):
    """
    Sets up TileLink and ROM+RAM interfaces for the DUT
    """

    tl = tlul.MasterInterface({
        "clk":          dut.clk_i,
        "rst_n":        dut.rst_ni,

        "a_ready":      dut.tl_o_a_ready,
        "a_valid":      dut.tl_i_a_valid,
        "a_opcode":     dut.tl_i_a_opcode,
        "a_source":     dut.tl_i_a_source,
        "a_address":    dut.tl_i_a_address,
        "a_size":       dut.tl_i_a_size,
        "a_data":       dut.tl_i_a_data,
        "a_mask":       dut.tl_i_a_mask,

        "d_ready":      dut.tl_i_d_ready,
        "d_valid":      dut.tl_o_d_valid,
        "d_opcode":     dut.tl_o_d_opcode,
        "d_source":     dut.tl_o_d_source,
        "d_sink":       dut.tl_o_d_sink,
        "d_size":       dut.tl_o_d_size,
        "d_data":       dut.tl_o_d_data,
        "d_error":      dut.tl_o_d_error,
    }, max_pending=4)

    rom = MemoryModel({
        "clk":          dut.clk_i,
        "rst_n":        dut.rst_ni,

        "req":          dut.rom_o_req,
        "we":           dut.rom_o_we,
        "addr":         dut.rom_o_addr,
        "wdata":        dut.rom_o_data,
        "wmask":        dut.rom_o_mask,

        "gnt":          dut.rom_i_gnt,
        "valid":        dut.rom_i_valid,
        "rdata":        dut.rom_i_data,
        "error":        dut.rom_i_error,
    }, size_bits=10, read_only=True)

    ram = MemoryModel({
        "clk":          dut.clk_i,
        "rst_n":        dut.rst_ni,

        "req":          dut.ram_o_req,
        "we":           dut.ram_o_we,
        "addr":         dut.ram_o_addr,
        "wdata":        dut.ram_o_data,
        "wmask":        dut.ram_o_mask,

        "gnt":          dut.ram_i_gnt,
        "valid":        dut.ram_i_valid,
        "rdata":        dut.ram_i_data,
        "error":        dut.ram_i_error,
    }, size_bits=10)

    return tl, rom, ram


async def initialize(dut):
    """
    Initializes the DUT by starting the clock and issuing a reset pulse
    """

    # Start a clock
    cocotb.fork(Clock(dut.clk_i, 10, "ns").start())

    # Release reset after a few ticks
    dut.rst_ni.value = 0
    await ClockCycles(dut.clk_i, 10)
    await RisingEdge(dut.clk_i)
    await Timer(1, units='ns')
    dut.rst_ni.value = 1
    await ClockCycles(dut.clk_i, 1)

    # This is usually set by CPU, it's required to avoid transfer errors
    # Instruction type field is at [18:14] of `a_user`
    INSTR_TYPE_SHIFT = 14
    MUBI4FALSE = 0x9
    dut.tl_i_a_user.value = MUBI4FALSE << INSTR_TYPE_SHIFT

# ==============================================================================

ROM_BASE    = 0x00000
RAM_BASE    = 0x20000

@cocotb.test()
async def test_ram_access(dut):

    logger = dut._log

    tl, rom, ram = await setup_interfaces(dut)
    await initialize(dut)

    tl.start()
    cocotb.fork(rom.process())
    cocotb.fork(ram.process())

    await ClockCycles(dut.clk_i, 10)

    # Write data to RAM
    text = "A quick brown fox jumps over the lazy dog..."

    logger.info("Writing  '{}'".format(text))
    data = text2mem(text)
    for i, w in enumerate(data):
        await tl.put_full_data(RAM_BASE + 4 * i, w)

    # Drain the response queue
    for i in range(len(data)):
        await tl.r_queue.get()

    await ClockCycles(dut.clk_i, 10)

    # Read data from RAM, issue read requests
    for i in range(len(data)):
        await tl.get(RAM_BASE + 4 * i)

    # Collect data
    read = dict()
    for i in range(len(data)):
        a, d = await tl.r_queue.get()
        assert d is not None, "TileLink error received"
        read[a] = d

    # Wait some cycles
    await ClockCycles(dut.clk_i, 10)

    # Verify
    read = [read[k] for k in sorted(list(read.keys()))]
    read = mem2text(read)
    logger.info("Readback '{}'".format(read))
    assert text == read, ("'{}' vs. '{}'".format(read, text))


@cocotb.test()
async def test_rom_access(dut):

    logger = dut._log

    tl, rom, ram = await setup_interfaces(dut)
    await initialize(dut)

    tl.start()
    cocotb.fork(rom.process())
    cocotb.fork(ram.process())

    await ClockCycles(dut.clk_i, 10)

    # Set data directly in the ROM model
    text = "A quick brown fox jumps over the lazy dog..."

    logger.info("Storing  '{}'".format(text))
    data = text2mem(text)
    for i, w in enumerate(data):
        a = ROM_BASE // 4 + i
        rom.storage[a] = w

    # Read data from ROM, issue read requests
    for i in range(len(data)):
        await tl.get(ROM_BASE + 4 * i)

    # Collect data
    read = dict()
    for i in range(len(data)):
        a, d = await tl.r_queue.get()
        read[a] = d

    # Wait some cycles
    await ClockCycles(dut.clk_i, 10)

    # Verify
    read = [read[k] for k in sorted(list(read.keys()))]
    read = mem2text(read)
    logger.info("Readback '{}'".format(read))
    assert text == read, ("'{}' vs. '{}'".format(read, text))


@cocotb.test()
async def test_rom_write(dut):

    logger = dut._log

    tl, rom, ram = await setup_interfaces(dut)
    await initialize(dut)

    tl.start()
    cocotb.fork(rom.process())
    cocotb.fork(ram.process())

    await ClockCycles(dut.clk_i, 10)

    # Issue a few ROM writes that should trigger a TileLink error response
    await tl.put_full_data(ROM_BASE + 0x00, 0xDEADBEEF)
    await tl.put_full_data(ROM_BASE + 0x10, 0xCAFEBABA)

    # Get responses
    read = []
    for i in range(2):
        a, d = await tl.r_queue.get()
        read.append(d)

    # All responses should be none
    assert len(read) == 2, read
    assert read == [None, None], read

    # Wait some cycles
    await ClockCycles(dut.clk_i, 10)
