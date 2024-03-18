#ifndef __ACCESSORS_H
#define __ACCESSORS_H

#ifdef __cplusplus
extern "C" {
#endif

#include <generated/csr.h>
#if defined(CSR_SDRAM_BASE) && defined(CSR_DDRPHY_BASE)
#include <generated/sdram_phy.h>

typedef void (*action_callback)(int module);

#if defined(SDRAM_PHY_READ_LEVELING_CAPABLE)

extern int read_dq_delay[SDRAM_PHY_MODULES];
void read_inc_dq_delay(int module);
void read_rst_dq_delay(int module);

#endif // defined(SDRAM_PHY_READ_LEVELING_CAPABLE)

#if defined(SDRAM_PHY_WRITE_LEVELING_CAPABLE)

extern int sdram_clock_delay;
void sdram_inc_clock_delay(void);
void sdram_rst_clock_delay(void);

extern int write_dq_delay[SDRAM_PHY_MODULES];
void write_inc_dq_delay(int module);
void write_rst_dq_delay(int module);

void write_inc_dqs_delay(int module);
void write_rst_dqs_delay(int module);

void write_inc_delay(int module);
void write_rst_delay(int module);

#endif // defined(SDRAM_PHY_WRITE_LEVELING_CAPABLE)

#if defined(SDRAM_PHY_BITSLIPS)

extern int read_dq_bitslip[SDRAM_PHY_MODULES];
void read_inc_dq_bitslip(int module);
void read_rst_dq_bitslip(int module);

extern int write_dq_bitslip[SDRAM_PHY_MODULES];
void write_inc_dq_bitslip(int module);
void write_rst_dq_bitslip(int module);

#endif // defined(SDRAM_PHY_BITSLIPS)

#if defined(CSR_DDRPHY_DLY_SEL_ADDR)
void sdram_select(int module, int dq_line);
void sdram_deselect(int module, int dq_line);
void sdram_leveling_action(int module, int dq_line, action_callback action);
#endif // defined(CSR_DDRPHY_DLY_SEL_ADDR)

#ifdef SDRAM_PHY_WRITE_LEVELING_CAPABLE
extern int _sdram_write_leveling_dat_delays[16];
void sdram_write_leveling_rst_dat_delay(int module, int show);
void sdram_write_leveling_force_dat_delay(int module, int taps, int show);

#if defined(SDRAM_PHY_BITSLIPS)
extern int _sdram_write_leveling_bitslips[16];
void sdram_write_leveling_rst_bitslip(int module, int show);
void sdram_write_leveling_force_bitslip(int module, int bitslip, int show);
#endif // defined(SDRAM_PHY_BITSLIPS)
#endif // SDRAM_PHY_WRITE_LEVELING_CAPABLE

#endif // defined(CSR_SDRAM_BASE) && defined(CSR_DDRPHY_BASE)

#ifdef __cplusplus
}
#endif

#endif // __ACCESSORS_H
