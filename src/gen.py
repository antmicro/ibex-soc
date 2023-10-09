#!/usr/bin/env python3
#
# Copyright (c) 2018-2021 Florent Kermarrec <florent@enjoy-digital.fr>
# Copyright (c) 2020 Stefan Schrijvers <ximin@ximinity.net>
# Copyright (c) 2023 Antmicro <www.antmicro.com>
# SPDX-License-Identifier: Apache-2.0

import os
import yaml
import argparse
import inspect

from migen import *

from litex.soc.interconnect import wishbone
from litex.soc.integration.soc import LiteXSoC

from litex.build.generic_toolchain import GenericToolchain
from litex.build.generic_platform import GenericPlatform, Pins, Subsignal
from litex.soc.integration.builder import Builder

from litedram.frontend.wishbone import *

from litedram import modules as litedram_modules
from litedram.core import ControllerSettings
from litedram.phy import lpddr4 as lpddr4_phys

from litedram.dfii import DFIInjector

import crg
from litex.build.xilinx import platform as xilinx_plat

# ------------------------------------------------------------------------------

class NoToolchain(GenericToolchain):
    """
    Generic toolchain stub
    """

    def __init__(self, *args, **kwargs):
        GenericToolchain.__init__(self, *args, **kwargs)

    def build_io_constraints(self):
        pass

    def build_script(self):
        pass


class NoPlatform(GenericPlatform):
    """
    Generic platform stub
    """

    def __init__(self, *args, **kwargs):
        GenericPlatform.__init__(self, *args, **kwargs)
        self.toolchain = NoToolchain()

    def build(self, *args, **kwargs):
        return self.toolchain.build(self, *args, **kwargs)


# IOs/Interfaces -----------------------------------------------------------------------------------

def get_common_ios():
    return [
        # Clk/Rst.
        ("clk", 0, Pins(1)),
        ("rst", 0, Pins(1)),

        # Low-level memory control
        ("mem_rst", 0, Pins(1)),
    ]

def get_dram_ios(core_config):
    assert core_config["memtype"] in ["LPDDR4"]

    # LPDDR4
    if core_config["memtype"] == "LPDDR4":
        ca_width = 6
        return [
            ("ddram", 0,
                Subsignal("ca",      Pins(ca_width)),
                Subsignal("cs",      Pins(core_config["sdram_rank_nb"])),
                Subsignal("dq",      Pins(8*core_config["sdram_module_nb"])),
                Subsignal("dqs_p",   Pins(core_config["sdram_module_nb"])),
                Subsignal("dqs_n",   Pins(core_config["sdram_module_nb"])),
                Subsignal("dmi",     Pins(core_config["sdram_module_nb"])),
                Subsignal("clk_p",   Pins(core_config["sdram_rank_nb"])),
                Subsignal("clk_n",   Pins(core_config["sdram_rank_nb"])),
                Subsignal("cke",     Pins(core_config["sdram_rank_nb"])),
                Subsignal("odt",     Pins(core_config["sdram_rank_nb"])),
                Subsignal("reset_n", Pins(1))
            ),
        ]

# DRAMCoreSoC -------------------------------------------------------------------------------------

class DRAMPHYSoC(LiteXSoC):
    def __init__(self, platform, core_config, **kwargs):
        platform.add_extension(get_common_ios())

        # Parameters -------------------------------------------------------------------------------
        sys_clk_freq   = core_config["sys_clk_freq"]
        csr_data_width = core_config.get("csr_data_width", 32)
        csr_base       = core_config.get("csr_base", 0xF0000000)
        rate           = "1:{}".format(core_config.get("sdram_ratio", 8))

        # SoCCore ----------------------------------------------------------------------------------

        LiteXSoC.__init__(self, platform, sys_clk_freq,
            bus_standard         = "wishbone",
            bus_data_width       = 32,
            bus_address_width    = 32,
            bus_timeout          = 1e6,
            bus_bursting         = False,
            bus_interconnect     = "shared",
            bus_reserved_regions = {},

            csr_data_width       = 32,
            csr_address_width    = 14,
            csr_paging           = 0x800,
            csr_ordering         = "big",
            csr_reserved_csrs    = {},

            irq_n_irqs           = 0,
            irq_reserved_irqs    = {},
        )

        # Attributes
        self.config         = {}
        self.cpu_type       = None

        self.clk_freq       = self.sys_clk_freq

        self.csr_regions    = {}
        self.mem_regions    = self.bus.regions
        self.mem_map        = {
            "csr":  csr_base,
        }

        self.wb_slaves      = {}

        # Dummy CPU
        self.add_cpu("None")

        # Clock domain -----------------------------------------------------------------------------

        if "crg" in core_config:
            self.submodules.crg = crg_instance = core_config["crg"](platform, core_config)
            self.comb += crg_instance.rst.eq(platform.request("rst"))
            self.add_clock_domains_outputs(platform, crg_instance)
        else:
            if core_config["sdram_phy"] in [lpddr4_phys.K7LPDDR4PHY, lpddr4_phys.V7LPDDR4PHY]:
                domains = ("sys", "sys2x", "sys8x", "idelay")
            if core_config["sdram_phy"] in [lpddr4_phys.A7LPDDR4PHY]:
                domains = ("sys", "sys2x", "sys8x", "sys8x_90", "idelay")
            self.add_clock_domains(platform, domains)

        # DRAM Interface ---------------------------------------------------------------------------

        sdram_module_def = core_config["sdram_module"]
        timing_settings = True
        if sdram_module_def.__name__.endswith("Module"):
            timing_settings = False
            setattr(sdram_module_def, "nbanks", 2**core_config.get("dfi_bankbits", 2))
            setattr(sdram_module_def, "nrows", core_config.get("sdram_rows", 8192))
            setattr(sdram_module_def, "ncols", core_config.get("sdram_cols", 1024))
            setattr(sdram_module_def, "timing_settings", None)
        sdram_module = sdram_module_def(sys_clk_freq, rate=rate, timing_settings=timing_settings)

        # Collect Electrical Settings.
        electrical_settings_kwargs = {}
        for name in ["rtt_nom", "rtt_wr", "ron"]:
            if core_config.get(name, None) is not None:
                electrical_settings_kwargs[name] = core_config[name]

        # PHY --------------------------------------------------------------------------------------

        # LPDDR4PHY.
        platform.add_extension(get_dram_ios(core_config))
        if core_config["sdram_phy"] in [lpddr4_phys.A7LPDDR4PHY, lpddr4_phys.K7LPDDR4PHY, lpddr4_phys.V7LPDDR4PHY]:
            assert core_config["memtype"] in ["LPDDR4"]
            self.submodules.ddrphy = phy = core_config["sdram_phy"](
                pads             = platform.request("ddram"),
                sys_clk_freq     = sys_clk_freq,
                iodelay_clk_freq = core_config["iodelay_clk_freq"])
        else:
            raise NotImplementedError

        # DFI Injector -----------------------------------------------------------------------------

        self.submodules.dfii = dfii = DFIInjector(
            addressbits = max(sdram_module.geom_settings.addressbits, getattr(phy, "addressbits", 0)),
            bankbits    = max(sdram_module.geom_settings.bankbits, getattr(phy, "bankbits", 0)),
            nranks      = phy.settings.nranks,
            databits    = phy.settings.dfi_databits,
            nphases     = phy.settings.nphases,
            memtype     = phy.settings.memtype,
            strobes     = phy.settings.strobes,
            with_sub_channels = phy.settings.with_sub_channels)

        self.comb += dfii.master.connect(phy.dfi)

        self.expose_dfi(platform, dfii.slave)

        # Collect Controller Settings.
        controller_settings_kwargs = {}
        for name in inspect.getfullargspec(ControllerSettings. __init__).args:
            if core_config.get(name, None) is not None:
                controller_settings_kwargs[name] = core_config[name]
        controller_settings = controller_settings = ControllerSettings(**controller_settings_kwargs)

        # DRAM Control/Status ----------------------------------------------------------------------

        # Expose a bus control interface to user.
        # TODO: export CSR bus instead
        wb_bus = wishbone.Interface()
        self.bus.add_master(master=wb_bus)
        platform.add_extension(wb_bus.get_ios("wb_ctrl"))
        wb_pads = platform.request("wb_ctrl")
        self.comb += wb_bus.connect_to_pads(wb_pads, mode="slave")

    def expose_dfi(self, platform, dfi):
        """
        Exposes the provided DFI interface by creating a platform extension with
        pads that match the DFI. Connects DFI to the pads
        """

        # Add DFI pads
        extension = ["dfi", 0]
        for name, signal in dfi.get_standard_names():
            name = name.replace("dfi_", "")
            extension.append(Subsignal(name, Pins(len(signal))))
        platform.add_extension([tuple(extension)])

        # Connect DFI pads
        pads = platform.request("dfi")
        for name, signal in dfi.get_standard_names(m2s=False):
            name = name.replace("dfi_", "")
            pad = getattr(pads, name)
            self.comb += pad.eq(signal)

        for name, signal in dfi.get_standard_names(s2m=False):
            name = name.replace("dfi_", "")
            pad = getattr(pads, name)
            self.comb += signal.eq(pad)

    def expose_cd(self, platform, cd, ext_crg = False):
        """
        Exposes clock and reset signals for declared clock domains
        by creating a platform extensions with pads that match clock and reset signals.
        Connects clock and reset signals to the pads.
        """

        # Add clock/reset pads
        extension = []
        for sig in ("clk", "rst"):
            pad_name = "{}_{}".format(sig, cd.name)
            extension.append((pad_name, 0, Pins(1)))
        platform.add_extension(extension)

        # Connect clock/reset pads
        for sig in ("clk", "rst"):
            pad_name = "{}_{}".format(sig, cd.name)
            pad = platform.request(pad_name)
            if ext_crg:
                self.comb += pad.eq(getattr(cd, sig))
            else:
                self.comb += getattr(cd, sig).eq(pad)

    def add_clock_domains(self, platform, domains):
        """
        Exposes clock and reset signals for declared clock domains without CRG
        """

        for domain in domains:
            cd = ClockDomain(domain)
            self.expose_cd(platform, cd, ext_crg = False)
            setattr(self, cd.name, cd)

    def add_clock_domains_outputs(self, platform, crg):
        """
        Exposes clock and reset signals for clock domains in existing CRG
        """
        for attr_name in dir(crg):
            attr = getattr(crg, attr_name)
            if type(attr) is ClockDomain:
                self.expose_cd(platform, attr, ext_crg = True)



# Build --------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="DRAM PHY standalone core generator")

    parser.add_argument(
        "config",
        type=str,
        help="YAML config file"
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default="build",
        help="Base Output directory."
    )
    parser.add_argument(
        "--name",
        type=str,
        default="dram_phy",
        help="Standalone PHY name"
    )

    args = parser.parse_args()

    # Load the config
    core_config = yaml.load(open(args.config).read(), Loader=yaml.Loader)

    # Convert YAML elements to Python/LiteX --------------------------------------------------------
    for k, v in core_config.items():
        replaces = {"False": False, "True": True, "None": None}
        for r in replaces.keys():
            if v == r:
                core_config[k] = replaces[r]
        if k.endswith("clk_freq"):
            core_config[k] = float(core_config[k])
        if k == "sdram_module":
            core_config[k] = getattr(litedram_modules, core_config[k])
        if k == "sdram_phy":
            core_config[k] = getattr(lpddr4_phys, core_config[k])
        if k == "crg":
            core_config[k] = getattr(crg, core_config[k])
        if k == "platform":
            core_config[k] = getattr(xilinx_plat, core_config[k])

    # Generate core --------------------------------------------------------------------------------

    builder_arguments = {
        "output_dir":       args.output_dir,
        "gateware_dir":     None,
        "software_dir":     None,
        "include_dir":      None,
        "generated_dir":    None,
        "compile_software": False,
        "compile_gateware": False,
        "csr_csv":          os.path.join(args.output_dir, "csr.csv")
    }

    platform_obj = core_config["platform"] if "platform" in core_config else NoPlatform
    platform = platform_obj("", io=[])
    soc     = DRAMPHYSoC(platform, core_config)
    builder = Builder(soc, **builder_arguments)
    builder.build(build_name=args.name, regular_comb=False)

if __name__ == "__main__":
    main()
