// Copyright TU Darmstadt 2023
// Copyright Antmicro 2023
// SPDX-License-Identifier: Apache-2.0

/**
	Pseudo PHY backend, used to emulate the comparator for the zq calibartion algorithm.
**///(vw)
module phy_backend #(CORRECT_VALUE=42)	//Set the correct value of zq calibration.
	(input [6:0] zq_config,		//The configuration value of zq, set by the state machine / controller.
	input zq_cal_en,		//Enable ZQ calibration
	output comparator_out);		//Output of the comparator. Is 1, if zq_config is to large.

	assign comparator_out = zq_cal_en ? (zq_config > CORRECT_VALUE) : 1'b0;
endmodule
