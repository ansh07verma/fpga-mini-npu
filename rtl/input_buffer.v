// =============================================================================
// Input Buffer
//
// Stores N rows of N activations each (N×N matrix A).
// During LOAD_INPUT phase, one row is presented to the systolic array per cycle
// with appropriate skew applied externally by the top-level or driver logic.
// =============================================================================

`timescale 1ns / 1ps

module input_buffer #(
    parameter N          = 4,
    parameter DATA_WIDTH = 8
)(
    input  wire                         clk,
    input  wire                         rst_n,
    // Write port (serial load from external interface)
    input  wire                         wr_en,
    input  wire [$clog2(N)-1:0]         wr_row,
    input  wire [$clog2(N)-1:0]         wr_col,
    input  wire signed [DATA_WIDTH-1:0] wr_data,
    // Read port — combinatorial, zero latency
    // rd_data[r*DATA_WIDTH +: DATA_WIDTH] = mem[r][rd_col]
    input  wire                         rd_en,
    input  wire [$clog2(N)-1:0]         rd_col,
    output wire [N*DATA_WIDTH-1:0]      rd_data
);

    // Internal storage: mem[row][col]
    reg signed [DATA_WIDTH-1:0] mem [0:N-1][0:N-1];

    integer i, j;

    // Write path (registered)
    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < N; i = i + 1)
                for (j = 0; j < N; j = j + 1)
                    mem[i][j] <= 0;
        end else if (wr_en) begin
            mem[wr_row][wr_col] <= wr_data;
        end
    end

    // Combinatorial read — present column rd_col immediately
    genvar r;
    generate
        for (r = 0; r < N; r = r + 1) begin : col_read
            assign rd_data[r*DATA_WIDTH +: DATA_WIDTH] = rd_en ? mem[r][rd_col] : 0;
        end
    endgenerate

endmodule
