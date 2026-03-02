// ============================================================================
// UART Receiver (uart_rx)
// ----------------------------------------------------------------------------
// Author      : Saksham Aggarwal
// Created     : 2026
// License     : MIT
// SPDX-License-Identifier: MIT
// ----------------------------------------------------------------------------
// Description :
//   Parameterized UART receiver with oversampling tick input.
//   Frame format: 1 Start | DATA_WIDTH Data | 1 Stop
//   - Start bit validated at mid-sample
//   - Data bits sampled at end of bit period
//   - Stop bit verified high
//   - Generates 1-cycle rx_done_o pulse when frame completes
// ============================================================================

`timescale 1ns/1ps

module uart_rx
  import uart_pkg::*;
(
    input  logic                     clk_i,
    input  logic                     rstn_i,
    input  logic                     rx_i,
    input  logic                     s_tick_i,      // oversample tick
    output logic [DATA_WIDTH-1:0]    data_o,
    output logic                     rx_done_o
);

    // -------------------------------------------------
    // Parameters
    // -------------------------------------------------
    localparam MID_SAMPLE = (OVERSAMPLE/2) - 1;
    localparam END_SAMPLE = OVERSAMPLE - 1;

    // -------------------------------------------------
    // State Machine
    // -------------------------------------------------
    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t;

    state_t state, next_state;

    // -------------------------------------------------
    // Counters
    // -------------------------------------------------
    logic [$clog2(OVERSAMPLE)-1:0]     tick_count;
    logic [$clog2(DATA_WIDTH)-1:0]     bit_count;

    // -------------------------------------------------
    // Tick Counter
    // -------------------------------------------------
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i)
            tick_count <= '0;
        else if (state == IDLE)
            tick_count <= '0;
        else if (s_tick_i) begin
            if ((state == START && tick_count == MID_SAMPLE) ||
                (state == DATA  && tick_count == END_SAMPLE) ||
                (state == STOP  && tick_count == END_SAMPLE))
                tick_count <= '0;
            else
                tick_count <= tick_count + 1;
        end
    end

    // -------------------------------------------------
    // Bit Counter (counts received DATA bits)
    // -------------------------------------------------
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i)
            bit_count <= '0;
        else if (state != DATA)
            bit_count <= '0;
        else if (s_tick_i && tick_count == END_SAMPLE) begin
            if (bit_count == DATA_WIDTH-1)
                bit_count <= '0;
            else
                bit_count <= bit_count + 1;
        end
    end

    // -------------------------------------------------
    // State Register
    // -------------------------------------------------
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i)
            state <= IDLE;
        else
            state <= next_state;
    end

    // -------------------------------------------------
    // Next-State Logic
    // -------------------------------------------------
    always_comb begin
        next_state = state;

        case (state)

            // Wait for falling edge (start bit)
            IDLE : begin
                if (!rx_i)
                    next_state = START;
            end

            // Validate start bit at mid-sample
            START : begin
                if (s_tick_i && tick_count == MID_SAMPLE) begin
                    if (!rx_i)
                        next_state = DATA;   // valid start
                    else
                        next_state = IDLE;   // false start
                end
            end

            // Receive data bits
            DATA : begin
                if (s_tick_i &&
                    tick_count == END_SAMPLE &&
                    bit_count == DATA_WIDTH-1)
                    next_state = STOP;
            end

            // Validate stop bit
            STOP : begin
                if (s_tick_i && tick_count == END_SAMPLE) begin
                    if (rx_i)
                        next_state = IDLE;   // valid stop
                    else
                        next_state = IDLE;   // framing error (still recover)
                end
            end

        endcase
    end

    // -------------------------------------------------
    // Data Sampling (LSB first)
    // -------------------------------------------------
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i)
            data_o <= '0;
        else if (state == DATA &&
                 s_tick_i &&
                 tick_count == END_SAMPLE)
            data_o[bit_count] <= rx_i;
    end

    // -------------------------------------------------
    // Done Pulse
    // -------------------------------------------------
    assign rx_done_o = (state == STOP &&
                        s_tick_i &&
                        tick_count == END_SAMPLE &&
                        rx_i);   // stop bit valid

endmodule
