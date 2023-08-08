# Ibex-based RISC-V SoC for testing DRAM PHY

## Prerequisities

- Verilator (version >5.000)

## Building

As for now everything is written in SystemVerilog and does not require any generation step. Building actually means assembling a list of files of the design and verilating it. The build system is based on make. To run verilation invoke the `verilator-build` target:

```bash
make verilator-build
```

## Testing

There two types of tests:

- RTL unit tests
- Simulation tests

### RTL unit tests

These tests focus on testing each RTL component (that requires it). They use [cocotb](https://docs.cocotb.org/) Python-based framework. By default Verilator is used as RTL simulator but thanks to cocotb portability others could be used as well.

To run RTL tests invoke:
```bash
make rtl-tests
```

To run a specific test use:
```bash
make rtl-test-<test_name>
```

and replace `test_name` with one. RTL tests are located under `tests/rtl`

### Simulation tests

Simulation tests perform RTL simulation of the whole SoC in its target configuration. Different tests use different programs for the RISC-V core. Again Verilaor is used for simulation.

To run all simulation tests do:
```bash
make sim-tests
```

Individual tests can be run with:
```bash
make sim-test-<test_name>
```

Tests can be found in `tests/src`

