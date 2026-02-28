// ============================================================================
// UART Transmitter (uart_tx)
// ----------------------------------------------------------------------------
// Author      : Saksham Aggarwal
// Created     : 2026
// License     : MIT
// SPDX-License-Identifier: MIT
// ----------------------------------------------------------------------------
// Description :
//   Parameterized UART transmitter with oversampling tick input.
//   Sends 1 start bit, DATA_WIDTH data bits (LSB first), and 1 stop bit.
//   Frame format: 1 Start | DATA_WIDTH Data | 1 Stop
// ============================================================================

module uart_tx
  import uart_pkg::*;
(
    input  logic                     clk_i,
    input  logic                     rstn_i,
    input  logic [DATA_WIDTH-1:0]    data_i,
    input  logic                     tx_start_i,
    input  logic                     s_tick_i,      // oversample tick
    output logic                     tx_o,
    output logic                     tx_done_o
);

    // -------------------------------------------------
    // Internal Signals
    // -------------------------------------------------
    logic [$clog2(DATA_WIDTH)-1:0]    bit_count;
    logic [$clog2(OVERSAMPLE)-1:0]    tick_count;
    logic [DATA_WIDTH-1:0]            data;

    // -------------------------------------------------
    // State Machine Definition
    // -------------------------------------------------
    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t;

    state_t state, next_state;

    // -------------------------------------------------
    // Oversample Tick Counter
    // -------------------------------------------------
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i)
            tick_count <= '0;
        else if (state != IDLE) begin
            if (s_tick_i) begin
                if (tick_count == OVERSAMPLE-1)
                    tick_count <= '0;
                else
                    tick_count <= tick_count + 1;
            end
        end
        else
            tick_count <= '0;
    end

    // -------------------------------------------------
    // Bit Counter (Counts DATA bits only)
    // -------------------------------------------------
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i)
            bit_count <= '0;
        else if (state == DATA && s_tick_i && tick_count == OVERSAMPLE-1) begin
            if (bit_count == DATA_WIDTH-1)
                bit_count <= '0;
            else
                bit_count <= bit_count + 1;
        end
    end

    // -------------------------------------------------
    // Data Latching (Capture input when transmission starts)
    // -------------------------------------------------
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i)
            data <= '0;
        else if (state == IDLE && tx_start_i)
            data <= data_i;
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

            IDLE : begin
                if (tx_start_i)
                    next_state = START;
            end

            START : begin
                if (s_tick_i && tick_count == OVERSAMPLE-1)
                    next_state = DATA;
            end

            DATA : begin
                if (s_tick_i && tick_count == OVERSAMPLE-1 &&
                    bit_count == DATA_WIDTH-1)
                    next_state = STOP;
            end

            STOP : begin
                if (s_tick_i && tick_count == OVERSAMPLE-1)
                    next_state = IDLE;
            end

        endcase
    end

    // -------------------------------------------------
    // Output Logic
    // -------------------------------------------------
    always_comb begin
        tx_o = 1'b1;  // default idle high

        case (state)
            IDLE  : tx_o = 1'b1;
            START : tx_o = 1'b0;
            DATA  : tx_o = data[bit_count]; // LSB first
            STOP  : tx_o = 1'b1;
        endcase
    end

    // -------------------------------------------------
    // Transmission Done Pulse
    // -------------------------------------------------
    assign tx_done_o = (state == STOP &&
                        s_tick_i &&
                        tick_count == OVERSAMPLE-1);

endmodule
