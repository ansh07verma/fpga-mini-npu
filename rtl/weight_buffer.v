// =============================================================================
// Weight Buffer
//
// Stores N rows of N weights (matrix B).
// During LOAD_WEIGHTS phase, one row of N weights is presented per cycle
// to be absorbed by the matching PE row in the systolic array.
// =============================================================================

`timescale 1ns / 1ps

module weight_buffer #(
    parameter N          = 4,
    parameter DATA_WIDTH = 8
)(
    input  wire                         clk,
    input  wire                         rst_n,
    // Write port
    input  wire                         wr_en,
    input  wire [$clog2(N)-1:0]         wr_row,
    input  wire [$clog2(N)-1:0]         wr_col,
    input  wire signed [DATA_WIDTH-1:0] wr_data,
    // Read port — combinatorial, zero latency
    input  wire                         rd_en,
    input  wire [$clog2(N)-1:0]         rd_row,
    output wire [N*DATA_WIDTH-1:0]      rd_data
);

    reg signed [DATA_WIDTH-1:0] mem [0:N-1][0:N-1];

    integer i, j;

    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < N; i = i + 1)
                for (j = 0; j < N; j = j + 1)
                    mem[i][j] <= 0;
        end else if (wr_en) begin
            mem[wr_row][wr_col] <= wr_data;
        end
    end

    // Combinatorial read — present row rd_row immediately
    genvar c;
    generate
        for (c = 0; c < N; c = c + 1) begin : row_read
            assign rd_data[c*DATA_WIDTH +: DATA_WIDTH] = rd_en ? mem[rd_row][c] : 0;
        end
    endgenerate

endmodule
