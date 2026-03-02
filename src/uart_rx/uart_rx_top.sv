// ============================================================================
// UART RX Top (Receiver + FIFO + Status)
// ----------------------------------------------------------------------------
// Author      : Saksham Aggarwal
// Created     : 2026
// License     : MIT
// SPDX-License-Identifier: MIT
// ----------------------------------------------------------------------------
// Description :
//   Combines uart_rx and rx_fifo.
//   - Stores received bytes into FIFO
//   - Blocks writes when FIFO is full
//   - Sticky overflow flag with software clear
// ============================================================================

`timescale 1ns/1ps

module uart_rx_top
  import uart_pkg::*;
#(
    parameter FIFO_DEPTH = 16
)
(
    input  logic                     clk_i,
    input  logic                     rstn_i,

    // Serial interface
    input  logic                     rx_i,
    input  logic                     s_tick_i,

    // CPU / System Interface
    input  logic                     rd_en_i,            // pop FIFO
    output logic [DATA_WIDTH-1:0]    data_o,
    output logic                     empty_o,
    output logic                     full_o,

    // Status
    input  logic                     overflow_clear_i,
    output logic                     overflow_o
);

    // -------------------------------------------------
    // Internal Signals
    // -------------------------------------------------
    logic [DATA_WIDTH-1:0] rx_data;
    logic                  rx_done;
    logic                  fifo_full;
    logic                  fifo_empty;
    logic                  fifo_write;

    // -------------------------------------------------
    // UART Receiver Instance
    // -------------------------------------------------
    uart_rx rx_inst (
        .clk_i      (clk_i),
        .rstn_i     (rstn_i),
        .rx_i       (rx_i),
        .s_tick_i   (s_tick_i),
        .data_o     (rx_data),
        .rx_done_o  (rx_done)
    );

    // -------------------------------------------------
    // FIFO Write Enable
    // -------------------------------------------------
    assign fifo_write = rx_done && !fifo_full;

    // -------------------------------------------------
    // Sticky Overflow Flag
    // -------------------------------------------------
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i)
            overflow_o <= 1'b0;
        else if (overflow_clear_i)
            overflow_o <= 1'b0;
        else if (rx_done && fifo_full)
            overflow_o <= 1'b1;
    end

    // -------------------------------------------------
    // RX FIFO Instance
    // -------------------------------------------------
    rx_fifo #(
        .DEPTH(FIFO_DEPTH)
    ) fifo_inst (
        .clk_i        (clk_i),
        .rstn_i       (rstn_i),
        .w_enable_i   (fifo_write),
        .r_enable_i   (rd_en_i),
        .data_i       (rx_data),
        .data_o       (data_o),
        .full         (fifo_full),
        .empty        (fifo_empty)
    );

    // -------------------------------------------------
    // Output Assignments
    // -------------------------------------------------
    assign full_o  = fifo_full;
    assign empty_o = fifo_empty;

endmodule
