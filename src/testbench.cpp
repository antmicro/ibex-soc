#include "Vsim_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

vluint64_t g_time = 0;

double sc_time_stamp () {
    return (double)g_time * 1e-2;   // 1 tick equals 0.01 time unit
}

int main (int argc, char* argv[]) {

    Verilated::commandArgs(argc, argv);

    // Instantiate the top module
    Vsim_top* top = new Vsim_top;

    // Init trace dump
#if VM_TRACE
    VerilatedVcdC* trace = NULL;
    Verilated::traceEverOn(true);
    trace = new VerilatedVcdC;
    top->trace(trace, 24);
    trace->open("dump.vcd");
#endif

    // Simulate
    while (!Verilated::gotFinish()){
#if VM_TRACE
        trace->dump(g_time);
#endif
        top->eval();
        g_time += 1;
    }

    // Close trace dump
#if VM_TRACE
    trace->close();
#endif

    return 0;
}

