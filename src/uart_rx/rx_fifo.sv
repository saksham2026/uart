`timescale 1ns/1ps

module rx_fifo
  import uart_pkg::*;
#(
    parameter DEPTH = 16
)
(
    input  logic                     clk_i,
    input  logic                     rstn_i,

    input  logic                     w_enable_i,
    input  logic                     r_enable_i,

    input  logic [DATA_WIDTH-1:0]    data_i,
    output logic [DATA_WIDTH-1:0]    data_o,

    output logic                     full,
    output logic                     empty
);

    // -----------------------------------------
    // Local parameters
    // -----------------------------------------
    localparam ADDR_WIDTH = $clog2(DEPTH);

    // -----------------------------------------
    // Memory
    // -----------------------------------------
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    logic [ADDR_WIDTH-1:0] wr_ptr;
    logic [ADDR_WIDTH-1:0] rd_ptr;
    logic [ADDR_WIDTH:0]   count;

    // -----------------------------------------
    // Status Flags
    // -----------------------------------------
    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    // -----------------------------------------
    // Sequential Logic
    // -----------------------------------------
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
            data_o <= '0;
        end
        else begin

            // Write only
            if (w_enable_i && !full && !(r_enable_i && !empty)) begin
                mem[wr_ptr] <= data_i;
                wr_ptr      <= wr_ptr + 1;
                count       <= count + 1;
            end

            // Read only
            if (r_enable_i && !empty && !(w_enable_i && !full)) begin
                data_o <= mem[rd_ptr];
                rd_ptr <= rd_ptr + 1;
                count  <= count - 1;
            end

            // Simultaneous read & write
            if (w_enable_i && !full && r_enable_i && !empty) begin
                mem[wr_ptr] <= data_i;
                wr_ptr      <= wr_ptr + 1;

                data_o      <= mem[rd_ptr];
                rd_ptr      <= rd_ptr + 1;

                // count unchanged
            end

        end
    end

endmodule
