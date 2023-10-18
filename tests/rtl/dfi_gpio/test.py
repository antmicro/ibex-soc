# Copyright Antmicro 2023
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer

import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import tlul


# ==============================================================================


async def initialize(dut):
    """
    Initializes the DUT by starting the clock and issuing a reset pulse
    """

    # Start a clock
    cocotb.start_soon(Clock(dut.clk_i, 10, "ns").start())

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
    dut.tl_gpio_i_a_user.value = MUBI4FALSE << INSTR_TYPE_SHIFT

@cocotb.test()
async def test_basic_gpio(dut):
    pfx = "tl_gpio"
    gpio_tlul = tlul.MasterInterface({
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
    })

    gpio_tlul.start()
    await initialize(dut)
    await ClockCycles(dut.clk_i, 10)

    # Write 1 to init_start CSR
    dut.dfi_init_start_i.value = 1
    await ClockCycles(dut.clk_i, 5)

    # Read init_start CSR
    await gpio_tlul.get(0x00000000)
    await RisingEdge(dut.clk_i)
    assert dut.tl_gpio_o_d_data.value == 1
    await ClockCycles(dut.clk_i, 5)

    # Reset init_start CSR
    dut.dfi_init_start_i.value = 0
    await gpio_tlul.get(0x00000000)
    await RisingEdge(dut.clk_i)
    assert dut.tl_gpio_o_d_data.value == 0
    await ClockCycles(dut.clk_i, 5)

    # Write 1 to init_done CSR
    await gpio_tlul.put_full_data(0x00000004, 1)
    await RisingEdge(dut.clk_i)
    assert dut.dfi_init_done_o.value == 1
