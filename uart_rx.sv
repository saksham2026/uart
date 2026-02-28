// -----------------------------------------------------------------------------
// UART Receiver Module
// Author: Saksham Aggarwal
// Copyright (c) 2026 Saksham Aggarwal
// License: MIT
// -----------------------------------------------------------------------------


`timescale 1ns/1ps
module uart_rx
	import uart_pkg::*;
(
	input clk_i,
	input rstn_i,
	input rx_i,
	input s_tick_i,
	output logic [DATA_WIDTH-1:0] data_o,
	output rx_done_o
	);
	
	// STATE OF THE RECEIVER
	typedef enum logic [1:0] {
		IDLE,
		START,
		DATA,
		STOP
	} state_t;

	localparam MID_SAMPLE = OVERSAMPLE/2 - 1;
	localparam END_SAMPLE = OVERSAMPLE - 1; 

	// COUNTER FOR COUNTING SAMPLING TICKS
	logic [$clog2(END_SAMPLE)-1:0] tick_count;
	
	// COUNTING NUMBER OF DATA BITS RECEIVED
	logic [$clog2(DATA_WIDTH)-1:0] bit_count;

	// CONTROL SIGNAL FOR SAMPLING COUNTER
	logic rstn_count;

	state_t state, next_state;
	

	// rst_count will reset the tick counter in the IDLE state, in the
	// middle of the start bit, hence we count till 7, after that we have
	// to count till 15 in order to reach mid of next da ta bit
	
	assign rstn_count = !((state==START && tick_count==MID_SAMPLE) || (state==DATA && tick_count==END_SAMPLE) || (state==IDLE) || (state==STOP && tick_count==END_SAMPLE));

	always_ff @(posedge clk_i or negedge rstn_i) begin
		if(!rstn_i) tick_count <= '0;
		else if(!rstn_count) tick_count <= '0;
		else if(s_tick_i) tick_count <= tick_count + 1;
	end

	always_ff @(posedge clk_i or negedge rstn_i) begin
		if(!rstn_i) bit_count <= '0;
		else if(state != DATA) bit_count <= '0;
		else if(state==DATA && tick_count==END_SAMPLE) bit_count <= bit_count + 1;
	end

	// STATE TRANSITION
	always_ff @(posedge clk_i or negedge rstn_i) begin
		if(!rstn_i) state <= IDLE;
		else state <= next_state;
	end

	// NEXT STATE LOGIC
	always_comb begin
		next_state = state;
		case(state)
			IDLE  : next_state = (!rx_i) ? START : IDLE;
			START : next_state = (tick_count==MID_SAMPLE && !rx_i) ? DATA : START; // START bit is 0
			DATA  : next_state = (bit_count==DATA_WIDTH-1 && tick_count==END_SAMPLE) ? STOP : DATA;
			STOP   : next_state = (tick_count==END_SAMPLE && rx_i) ? IDLE : STOP;
			default : next_state = IDLE;
		endcase
	end

	always_ff @(posedge clk_i or negedge rstn_i) begin
		if(!rstn_i) data_o <= '0;
		else if(state == DATA && tick_count==END_SAMPLE && bit_count<DATA_WIDTH) data_o[bit_count] <= rx_i;
	end

	// OUTPUT LOGIC
	assign rx_done_o = (state==STOP && tick_count==END_SAMPLE);
endmodule
