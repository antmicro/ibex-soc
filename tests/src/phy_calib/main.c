/* Copyright Antmicro 2023
 * SPDX-License-Identifier: Apache-2.0
 */

volatile unsigned int* phy_regs = 0xC0000800;
volatile char* sim_out = 0x801FFFFC;

#define PHY_ZQ_CONFIG    (0x00 / 4)
#define PHY_ZQ_CAL       (0x04 / 4)
#define PHY_PHY_FEEDBACK (0x08 / 4)

void main(void)
{
    unsigned int done = 0;
    unsigned int zq_config = 0x7f;

    phy_regs[PHY_ZQ_CAL] = 1;

    while (!done) {
        phy_regs[PHY_ZQ_CONFIG] = zq_config;

        if (phy_regs[PHY_PHY_FEEDBACK] & 0x01) {
            *sim_out = '1';
            zq_config--;
        }
        else {
            *sim_out = '0';
            done = 1;
        }
    }

    phy_regs[PHY_ZQ_CAL] = 0;

    *sim_out = '\n';
}
