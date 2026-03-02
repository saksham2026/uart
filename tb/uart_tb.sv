`timescale 1ns/1ps

module uart_tb;

    import uart_pkg::*;

    // -------------------------------------------------
    // Independent Clocks
    // -------------------------------------------------

    // TX clock (50 MHz)
    localparam TX_CLK_PERIOD = 20.9;

    // RX clock (can change slightly to test tolerance)
    localparam RX_CLK_PERIOD = 20;   // keep equal first

    logic tx_clk = 0;
    logic rx_clk = 0;
    logic rstn;

    always #(TX_CLK_PERIOD/2) tx_clk = ~tx_clk;
    always #(RX_CLK_PERIOD/2) rx_clk = ~rx_clk;

    // -------------------------------------------------
    // Tick Signals
    // -------------------------------------------------
    logic tx_s_tick;
    logic rx_s_tick;

    // -------------------------------------------------
    // TX Signals
    // -------------------------------------------------
    logic [DATA_WIDTH-1:0] tx_data;
    logic tx_start;
    logic tx_o;
    logic tx_done;

    // -------------------------------------------------
    // RX Signals
    // -------------------------------------------------
    logic rx_i;
    logic [DATA_WIDTH-1:0] rx_data;
    logic rx_done;

    // -------------------------------------------------
    // TX Baud Generator
    // -------------------------------------------------
    baud_gen tx_baud (
        .clk_i(tx_clk),
        .rstn_i(rstn),
        .s_tick_o(tx_s_tick)
    );

    // -------------------------------------------------
    // RX Baud Generator
    // -------------------------------------------------
    baud_gen rx_baud (
        .clk_i(rx_clk),
        .rstn_i(rstn),
        .s_tick_o(rx_s_tick)
    );

    // -------------------------------------------------
    // UART TX
    // -------------------------------------------------
    uart_tx tx_inst (
        .clk_i(tx_clk),
        .rstn_i(rstn),
        .data_i(tx_data),
        .tx_start_i(tx_start),
        .s_tick_i(tx_s_tick),
        .tx_o(tx_o),
        .tx_done_o(tx_done)
    );

    // -------------------------------------------------
    // UART RX
    // -------------------------------------------------
    uart_rx rx_inst (
        .clk_i(rx_clk),
        .rstn_i(rstn),
        .rx_i(rx_i),
        .s_tick_i(rx_s_tick),
        .data_o(rx_data),
        .rx_done_o(rx_done)
    );

    // -------------------------------------------------
    // Optional 2-Flop Synchronizer (CDC Safe)
    // -------------------------------------------------
    logic rx_sync1, rx_sync2;

    always_ff @(posedge rx_clk or negedge rstn) begin
        if (!rstn) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= tx_o;
            rx_sync2 <= rx_sync1;
        end
    end

    assign rx_i = rx_sync2;

    // -------------------------------------------------
    // Reset
    // -------------------------------------------------
    initial begin
        rstn = 0;
        tx_start = 0;
        tx_data  = 0;
        #200;
        rstn = 1;
    end

    // -------------------------------------------------
    // Send Byte Task (TX Clock Domain)
    // -------------------------------------------------
    task send_byte(input [DATA_WIDTH-1:0] data);
        begin
            // Wait until TX FSM is truly IDLE
            wait (tx_inst.state == tx_inst.IDLE);

            @(posedge tx_clk);
            tx_data  <= data;
            tx_start <= 1;

            @(posedge tx_clk);
            tx_start <= 0;
        end
    endtask

    // -------------------------------------------------
    // Test Sequence
    // -------------------------------------------------
    initial begin
        wait(rstn);

        $display("Starting Independent Clock UART Test...");

        repeat (300) begin
            automatic logic [DATA_WIDTH-1:0] val;
            val = $urandom_range(0, 255);

            send_byte(val);

            // Wait for RX completion
            @(posedge rx_done);

            if (rx_data !== val) begin
                $display("ERROR (async): Sent %0h Got %0h",
                         val, rx_data);
                $fatal;
            end
            else begin
                $display("PASS (async): %0h transmitted and received",
                         val);
            end
        end

        $display("Async UART test passed!");
        $finish;
    end

    // -------------------------------------------------
    // Timeout Protection
    // -------------------------------------------------
    initial begin
        #300_000_000;
        $display("TIMEOUT - Async stuck");
        $finish;
    end

endmodule
