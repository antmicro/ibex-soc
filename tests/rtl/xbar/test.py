# Copyright Antmicro 2023
# SPDX-License-Identifier: Apache-2.0

import pytest
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer

import random
import logging
import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import tlul

# ==============================================================================


def setup_interfaces(dut):
    """
    Sets up TileLink interfaces
    """

    def tlul_master(pfx):
        return tlul.MasterInterface({
            "clk":          dut.clk_i,
            "rst_n":        dut.rst_ni,

            "a_ready":      getattr(dut, pfx + "_o_a_ready"),
            "a_valid":      getattr(dut, pfx + "_i_a_valid"),
            "a_opcode":     getattr(dut, pfx + "_i_a_opcode"),
            "a_source":     getattr(dut, pfx + "_i_a_source"),
            "a_address":    getattr(dut, pfx + "_i_a_address"),
            "a_size":       getattr(dut, pfx + "_i_a_size"),
            "a_data":       getattr(dut, pfx + "_i_a_data"),
            "a_mask":       getattr(dut, pfx + "_i_a_mask"),

            "d_ready":      getattr(dut, pfx + "_i_d_ready"),
            "d_valid":      getattr(dut, pfx + "_o_d_valid"),
            "d_opcode":     getattr(dut, pfx + "_o_d_opcode"),
            "d_source":     getattr(dut, pfx + "_o_d_source"),
            "d_sink":       getattr(dut, pfx + "_o_d_sink"),
            "d_size":       getattr(dut, pfx + "_o_d_size"),
            "d_data":       getattr(dut, pfx + "_o_d_data"),
            "d_error":      getattr(dut, pfx + "_o_d_error"),
        }, max_pending=4)

    def tlul_slave(pfx):
        return tlul.SlaveInterface(pfx, {
            "clk":          dut.clk_i,
            "rst_n":        dut.rst_ni,

            "a_ready":      getattr(dut, pfx + "_i_a_ready"),
            "a_valid":      getattr(dut, pfx + "_o_a_valid"),
            "a_opcode":     getattr(dut, pfx + "_o_a_opcode"),
            "a_source":     getattr(dut, pfx + "_o_a_source"),
            "a_address":    getattr(dut, pfx + "_o_a_address"),
            "a_size":       getattr(dut, pfx + "_o_a_size"),
            "a_data":       getattr(dut, pfx + "_o_a_data"),
            "a_mask":       getattr(dut, pfx + "_o_a_mask"),

            "d_ready":      getattr(dut, pfx + "_o_d_ready"),
            "d_valid":      getattr(dut, pfx + "_i_d_valid"),
            "d_opcode":     getattr(dut, pfx + "_i_d_opcode"),
            "d_source":     getattr(dut, pfx + "_i_d_source"),
            "d_sink":       getattr(dut, pfx + "_i_d_sink"),
            "d_size":       getattr(dut, pfx + "_i_d_size"),
            "d_data":       getattr(dut, pfx + "_i_d_data"),
            "d_error":      getattr(dut, pfx + "_i_d_error"),
        }, logger=dut._log)

    ifaces = {
        "mem":  tlul_slave("tl_m"),
    }

    for m in range(2):
        name = "h" + str(m)
        ifaces[name] = tlul_master("tl_" + name)

    for n in range(7):
        name = "d" + str(n)
        ifaces[name] = tlul_slave("tl_" + name)

    # Start interfaces
    for iface in ifaces.values():
        iface.start()

    return ifaces


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

# ==============================================================================


async def do_write(iface, address, data):
    """
    Issues a write through a TLUL interface. Returns a write record
    """
    await iface.put_full_data(address, data)
    return (address, data)


async def region_write(dut, master, region):
    """
    A test that issues writes to a memory region from the given master port.
    At first writes to the beginning and ending addresses are written, then
    it issues random writes to the region and finally random writes outside
    the region. The latter should all fail.
    """
    logger = dut._log

    # Initialize
    ifaces = setup_interfaces(dut)
    await initialize(dut)
    await ClockCycles(dut.clk_i, 10)

    # Get interfaces
    slave, arange = region

    m_iface = ifaces[master]
    s_iface = ifaces[slave]

    # Set transfer handler. The handler records transfers that reached
    # the slave interface
    def on_transfer(opcode, address, wdata, wmask):
        assert opcode == tlul.ReqOpcode.PutFullData
        s_writes.append((address, wdata))
        return 0

    s_iface.transfer_handler = on_transfer

    # Writes
    m_writes = []
    s_writes = []

    # Beginning of the region
    m_writes.append(
        await do_write(m_iface, arange[0],     random.randint(0, 1<<31)))
    # End of the region
    m_writes.append(
        await do_write(m_iface, arange[1] - 4, random.randint(0, 1<<31)))

    await ClockCycles(dut.clk_i, 10)

    # Random inside region
    for i in range(500):
        address = random.randint(*arange) & ~3 # Align to 32-bit
        m_writes.append(
            await do_write(m_iface, address, random.randint(0, 1<<31)))

    await ClockCycles(dut.clk_i, 10)

    # Random outside region
    for i in range(500):

        while True:
            address = random.randint(0, 1<<31) & ~3 # Align to 32-bit
            if address < arange[0] or address >= arange[1]:
                break

        # Do no record the writes that are about to fail. They should not show
        # on the slave write list
        await do_write(m_iface, address, random.randint(0, 1<<31))

    await ClockCycles(dut.clk_i, 10)

    # Compare
    lnt = max(len(m_writes), len(s_writes))
    err = False

    for i in range(lnt):

        if i < len(m_writes):
            lhs = "0x{:08X} <= 0x{:08X}".format(*m_writes[i])
        else:
            lhs = "None                    "

        if i < len(s_writes):
            rhs = "0x{:08X} <= 0x{:08X}".format(*s_writes[i])
        else:
            rhs = "None                    "

        msg = lhs + " vs. " + rhs

        if lhs != rhs:
            logger.error(msg)
            err = True
        else:
            logger.debug(msg)

    assert not err

# ==============================================================================

regions = [
    ("mem", (0x80000000, 0xC0000000)),
]

for i in range(7):
    regions.append(
        ("d{}".format(i), (0xC0000000 + i * 1024, 0xC0000000 + (i+1) * 1024 - 4))
    )

tf = cocotb.regression.TestFactory(region_write)
tf.add_option("master", ["h0", "h1"])
tf.add_option("region", regions)
tf.generate_tests()
