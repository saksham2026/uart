// -----------------------------------------------------------------------------
// UART Package File
// Author: Saksham Aggarwal
// Copyright (c) 2026 Saksham Aggarwal
// License: MIT
// -----------------------------------------------------------------------------


`timescale 1ns/1ps
package uart_pkg;

	// TIMING PARAMETERS
	parameter BAUD_RATE = 16200;
	parameter OVERSAMPLE = 16;
	parameter FREQ_CLK = 50000000;

	// DATA PARAMETERS
	parameter DATA_WIDTH = 8;
endpackage
