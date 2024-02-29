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
import logging

from migen import *

from litex.gen import colorer
from litex.gen import LiteXModule
from litex.gen.fhdl.hierarchy import LiteXHierarchyExplorer

from litex.soc.integration.soc import LiteXSoC
from litex.soc.integration.soc import SoCConstant, SoCCSRHandler, SoCRegion, SoCCSRRegion

from litex.soc.interconnect.csr import CSR, CSRStorage, CSRStatus, AutoCSR
from litex.soc.interconnect import csr_bus

from litex.soc.cores.cpu import CPUNone

from litex.compat.soc_core import SoCCoreCompat

from litex.build.generic_toolchain import GenericToolchain
from litex.build.generic_platform import GenericPlatform, Pins, Subsignal
from litex.soc.integration.builder import Builder

from litedram import modules as litedram_modules
from litedram.core.controller import ControllerSettings, LiteDRAMControllerRegisterBank, REGISTER_NAMES
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

class DRAMControllerRegisterBank(LiteDRAMControllerRegisterBank):
    def __init__(self, phy_settings, initial_timings, max_expected_values, memtype):
        for reg in REGISTER_NAMES:
            if reg == "tZQCS" and memtype in ["LPDDR4", "LPDDR5", "DDR5"]:
                continue # ZQCS refresher does not work with LPDDR4, LPDDR5 and DDR5
            try:
                width = getattr(max_expected_values, reg)
            except AttributeError:
                width = None
            width = (width.bit_length() + 1) if width is not None else 1
            reset_val = None
            if initial_timings is not None:
                try:
                    reset_val = getattr(initial_timings, reg)
                except AttributeError:
                    reset_val = None
            csr = CSRStorage(width, name=reg, reset=reset_val if reset_val is not None else 0)
            assert reset_val is None or reset_val < 2**width, (reg, reset_val, 2**width)
            setattr(self, reg, csr)

# DummyDRAMControler -----------------------------------------------------------------------------

class DummyDRAMController(Module):
    def __init__(self, phy_settings, geom_settings, timing_settings, max_expected_values):
        # Settings -------------------------------------------------------------
        self.settings        = ControllerSettings()
        self.settings.phy    = phy_settings
        self.settings.geom   = geom_settings
        self.settings.timing = timing_settings

        # Registers ------------------------------------------------------------
        self.registers = registers = DRAMControllerRegisterBank(
            phy_settings, timing_settings, max_expected_values,
            phy_settings.memtype)

    def get_csrs(self):
        return self.registers.get_csrs()

# DummyDRAMCore ----------------------------------------------------------------------------------

class DummyDRAMCore(Module, AutoCSR):
    def __init__(self, phy, module):
        self.submodules.dfii = DFIInjector(
            addressbits = max(module.geom_settings.addressbits, getattr(phy, "addressbits", 0)),
            bankbits    = max(module.geom_settings.bankbits, getattr(phy, "bankbits", 0)),
            nranks      = phy.settings.nranks,
            databits    = phy.settings.dfi_databits,
            nphases     = phy.settings.nphases,
            memtype     = phy.settings.memtype,
            strobes     = phy.settings.strobes,
            with_sub_channels= phy.settings.with_sub_channels)
        self.comb += self.dfii.master.connect(phy.dfi)

        self.submodules.controller = DummyDRAMController(
            phy_settings        = phy.settings,
            geom_settings       = module.geom_settings,
            timing_settings     = module.timing_settings,
            max_expected_values = module.maximal_timing_values)

# DRAMPHYSoC -------------------------------------------------------------------------------------

class SysBusHandler:
    """
    A dummy sysbus handler to provide memory regions
    """
    def __init__(self, regions):
        self.regions = regions


class DRAMPHYSoC(LiteXModule, SoCCoreCompat):
    """
    The PHY core SoC
    """

    def __init__(self, platform, core_config, **kwargs):
        platform.add_extension(get_common_ios())

        csr_base            = 0xC0002000
        csr_data_width      = 32
        csr_address_width   = 10    # 1024
        csr_paging          = 0x100 # 256
        csr_ordering        = "big"
        csr_reserved_csrs   = {}

        # SoC attributes ------------------------------------------------------
        self.platform       = platform
        self.sys_clk_freq   = int(core_config["sys_clk_freq"])

        self.config         = {}
        self.cpu_type       = None

        self.constants      = {}
        self.csr_regions    = {}

        self.mem_regions    = {
            "csr":  SoCRegion(
                origin  = csr_base,
                size    = 0x400,
                mode    = "rw",
            )
        }

        self.mem_map        = {
            "csr":  csr_base,
        }

        self.constants["CONFIG_CLOCK_FREQUENCY"] = SoCConstant(self.sys_clk_freq)

        if not len(logging.root.handlers):
            logging.basicConfig(level=logging.INFO)

        self.logger = logging.getLogger("SoC")
        self.logger.info("FPGA device : {}.".format(platform.device))
        self.logger.info("System clock: {:3.3f}MHz.".format(self.sys_clk_freq/1e6))

        # CPU -----------------------------------------------------------------
        self.cpu = CPUNone()

        # System Bus Handler --------------------------------------------------
        self.bus = SysBusHandler(
            regions = self.mem_regions,
        )

        # CSR Bus Handler -----------------------------------------------------

        # FIXME: Override some constants in the class to allow non-standard
        # CSR address width and paging
        SoCCSRHandler.supported_address_width = [csr_address_width]
        SoCCSRHandler.supported_paging        = [csr_paging]

        self.csr = SoCCSRHandler(
            data_width      = csr_data_width,
            address_width   = csr_address_width,
            alignment       = csr_data_width,
            paging          = csr_paging,
            ordering        = csr_ordering,
            reserved_csrs   = csr_reserved_csrs,
        )

        # Clock domain --------------------------------------------------------

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

        # DRAM Interface ------------------------------------------------------
        rate = "1:{}".format(core_config.get("sdram_ratio", 8))

        sdram_module_def = core_config["sdram_module"]
        timing_settings = True
        if sdram_module_def.__name__.endswith("Module"):
            timing_settings = False
            setattr(sdram_module_def, "nbanks", 2**core_config.get("dfi_bankbits", 2))
            setattr(sdram_module_def, "nrows", core_config.get("sdram_rows", 8192))
            setattr(sdram_module_def, "ncols", core_config.get("sdram_cols", 1024))
            setattr(sdram_module_def, "timing_settings", None)
        sdram_module = sdram_module_def(self.sys_clk_freq, rate=rate, timing_settings=timing_settings)

        # Collect Electrical Settings.
        electrical_settings_kwargs = {}
        for name in ["rtt_nom", "rtt_wr", "ron"]:
            if core_config.get(name, None) is not None:
                electrical_settings_kwargs[name] = core_config[name]

        # PHY -----------------------------------------------------------------

        # LPDDR4PHY.
        platform.add_extension(get_dram_ios(core_config))
        if core_config["sdram_phy"] in [lpddr4_phys.A7LPDDR4PHY, lpddr4_phys.K7LPDDR4PHY, lpddr4_phys.V7LPDDR4PHY]:
            assert core_config["memtype"] in ["LPDDR4"]
            self.submodules.ddrphy = phy = core_config["sdram_phy"](
                pads             = platform.request("ddram"),
                sys_clk_freq     = self.sys_clk_freq,
                iodelay_clk_freq = core_config["iodelay_clk_freq"])
        else:
            raise NotImplementedError

        # DFI Injector --------------------------------------------------------

        self.submodules.sdram = sdram = DummyDRAMCore(phy, sdram_module)
        self.expose_dfi(platform, sdram.dfii.slave)

        # Collect Controller Settings.
        controller_settings_kwargs = {}
        for name in inspect.getfullargspec(ControllerSettings. __init__).args:
            if core_config.get(name, None) is not None:
                controller_settings_kwargs[name] = core_config[name]
        controller_settings = controller_settings = ControllerSettings(**controller_settings_kwargs)

        # DRAM Control/Status -------------------------------------------------

        def get_csr_bus_ios(bus, bus_name="csr"):
            """
            Creates a platform extension with CSR bus IOs
            """
            subsignals = []
            for name, width, direction in bus.layout:
                subsignals.append(Subsignal(name, Pins(width)))
            ios = [(bus_name , 0) + tuple(subsignals)]
            return ios

        def connect_csr_bus_to_pads(bus, pads):
            """
            Connects CSR bus to IO pags
            """
            r = []
            for name, width, direction in bus.layout:
                sig  = getattr(bus,  name)
                pad  = getattr(pads, name)
                if direction == DIR_S_TO_M:
                    r.append(pad.eq(sig))
                else:
                    r.append(sig.eq(pad))
            return r

        ctl_bus = csr_bus.Interface(
            address_width = self.csr.address_width,
            data_width    = self.csr.data_width
        )
        self.csr.add_master(master=ctl_bus)
        platform.add_extension(get_csr_bus_ios(ctl_bus))
        ctl_pads = platform.request("csr")
        self.comb += connect_csr_bus_to_pads(ctl_bus, ctl_pads)

    # SoC finalization --------------------------------------------------------
    def finalize(self):
        """
        Finalizes the SoC
        """

        if self.finalized:
            return

        # SoC Main CSRs collection --------------------------------------------

        # Collect CSRs created on the Main Module.
        main_csrs = dict()
        for name, obj in self.__dict__.items():
            if isinstance(obj, (CSR, CSRStorage, CSRStatus)):
                main_csrs[name] = obj

        # Add Main CSRs to a "main" Sub-Module and delete it from Main Module.
        if main_csrs:
            self.main = LiteXModule()
            for name, csr in main_csrs.items():
                setattr(self.main, name, csr)
                delattr(self, name)

        # SoC CSR Interconnect ------------------------------------------------
        self.csr_bankarray = csr_bus.CSRBankArray(self,
            address_map        = self.csr.address_map,
            data_width         = self.csr.data_width,
            address_width      = self.csr.address_width,
            alignment          = self.csr.alignment,
            paging             = self.csr.paging,
            ordering           = self.csr.ordering)

        if len(self.csr.masters):
            self.csr_interconnect = csr_bus.InterconnectShared(
                masters = list(self.csr.masters.values()),
                slaves  = self.csr_bankarray.get_buses())

        # Add CSRs regions.
        for name, csrs, mapaddr, rmap in self.csr_bankarray.banks:
            self.csr.add_region(name, SoCCSRRegion(
                origin   = (self.bus.regions["csr"].origin + self.csr.paging*mapaddr),
                busword  = self.csr.data_width,
                obj      = csrs))

        # Add Memory regions.
        for name, memory, mapaddr, mmap in self.csr_bankarray.srams:
            self.csr.add_region(name + "_" + memory.name_override, SoCCSRRegion(
                origin  = (self.bus.regions["csr"].origin + self.csr.paging*mapaddr),
                busword = self.csr.data_width,
                obj     = memory))

        # Sort CSR regions by origin.
        self.csr.regions = {k: v for k, v in sorted(self.csr.regions.items(), key=lambda item: item[1].origin)}

        # Add CSRs / Config items to constants.
        self.constants["CONFIG_CSR_DATA_WIDTH"] = SoCConstant(self.csr.data_width)
        self.constants["CONFIG_CPU_NOP"] = SoCConstant("nop")
        self.constants["SDRAM_TEST_DISABLE"] = SoCConstant(None)
        self.constants["MAIN_RAM_BASE"] = SoCConstant(0xffffffff)
        self.constants["MAIN_RAM_SIZE"] = SoCConstant(0)
        for name, constant in self.csr_bankarray.constants:
            self.add_constant(name + "_" + constant.name, constant.value.value)

        # Finalize submodules -------------------------------------------------
        Module.finalize(self)

        # Compat --------------------------------------------------------------
        self.finalize_csr_regions()

        # SoC Hierarchy -------------------------------------------------------
        self.logger.info(colorer("-"*80, color="bright"))
        self.logger.info(colorer("SoC Hierarchy:"))
        self.logger.info(colorer("-"*80, color="bright"))
        self.logger.info(LiteXHierarchyExplorer(top=self, depth=None))
        self.logger.info(colorer("-"*80, color="bright"))

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
            if sig == "rst" and getattr(cd, sig, None) is None:
                continue
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

    # SoC build ------------------------------------------------------------------------------------
    def get_build_name(self):
        return getattr(self, "build_name", self.platform.name)

    def build(self, *args, **kwargs):
        self.build_name = kwargs.pop("build_name", self.platform.name)
        if self.build_name[0].isdigit():
            self.build_name = f"_{self.build_name}"
        kwargs.update({"build_name": self.build_name})
        return self.platform.build(self, *args, **kwargs)


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
    toolchain = core_config["toolchain"] if "toolchain" in core_config else None
    platform = platform_obj("", io=[], toolchain=toolchain)
    soc     = DRAMPHYSoC(platform, core_config)
    builder = Builder(soc, **builder_arguments)
    builder.build(build_name=args.name, regular_comb=False)

if __name__ == "__main__":
    main()
