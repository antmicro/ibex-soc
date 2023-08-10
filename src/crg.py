#!/usr/bin/env python3
#
# Copyright (c) 2018-2021 Florent Kermarrec <florent@enjoy-digital.fr>
# Copyright (c) 2020 Stefan Schrijvers <ximin@ximinity.net>
# Copyright (c) 2023 Antmicro <www.antmicro.com>
# SPDX-License-Identifier: Apache-2.0

from migen import *

from litex.gen import LiteXModule

from litex.soc.cores.clock import *

# CRG ----------------------------------------------------------------------------------------------

class XilinxS7CRG(LiteXModule):
    def __init__(self, platform, core_config):
        self.rst         = Signal()
        self.cd_sys      = ClockDomain()
        self.cd_sys2x    = ClockDomain()
        self.cd_sys8x    = ClockDomain()
        self.cd_idelay   = ClockDomain()

        # # #

        self.pll = pll = S7PLL(speedgrade=-1)
        self.comb += pll.reset.eq(self.rst)
        pll.register_clkin(platform.request("clk"), core_config["input_clk_freq"])
        pll.create_clkout(self.cd_sys,          core_config["sys_clk_freq"])
        pll.create_clkout(self.cd_sys2x,    2 * core_config["sys_clk_freq"])
        pll.create_clkout(self.cd_sys8x,    8 * core_config["sys_clk_freq"])
        pll.create_clkout(self.cd_idelay,   core_config["iodelay_clk_freq"])

        self.idelayctrl = S7IDELAYCTRL(self.cd_idelay)

class XilinxV7CRG(XilinxS7CRG):
    pass

class XilinxK7CRG(XilinxS7CRG):
    pass

class XilinxA7CRG(XilinxS7CRG):
    def __init__(self, platform, core_config):
        XilinxS7CRG.__init__(self, platform, core_config)

        self.cd_sys8x_90 = ClockDomain()
        self.pll.create_clkout(self.cd_sys8x_90, 8 * core_config["sys_clk_freq"], phase=90)
