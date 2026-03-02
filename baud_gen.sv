// -----------------------------------------------------------------------------
// UART BAUD GENERATOR MODULE
// Author: Saksham Aggarwal
// Copyright (c) 2026 Saksham Aggarwal
// License: MIT
// -----------------------------------------------------------------------------



`timescale 1ns/1ps
module baud_gen
	import uart_pkg::*;
(
	input clk_i,  // 50Mhz clock
	input rstn_i,
	output s_tick_o // sampling tick
	);

	// baud_rate = 19,200
	// Sampling rate = 16*19,200 = 307,200
	// we need mod-n counter for sampling rate
	// n = 50*1e6/307,200 = 162.76 ~ 163


	localparam int FREQ_SAMPLE = BAUD_RATE*OVERSAMPLE;
	localparam int M           = FREQ_CLK/FREQ_SAMPLE;
	localparam int WIDTH = $clog2(M);
	

	logic [WIDTH-1:0] baud_count;

	always@(posedge clk_i or negedge rstn_i) begin
		if(!rstn_i) baud_count <= '0;
		else if(baud_count == M-1) baud_count <= '0;  // mod-N counter
		else baud_count <= baud_count+1;
	end
	assign s_tick_o = (baud_count == M-1);
endmodule

