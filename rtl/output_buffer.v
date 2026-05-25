// =============================================================================
// Output Buffer
//
// Captures the complete N×N result matrix from the systolic array's flat
// y_out bus and holds it for random-access readback.
//
// The systolic array outputs ALL N*N results simultaneously on y_out when
// done. The output buffer latches the entire bus in one cycle (capture=1).
//
// Readback: single-element random access via (rd_row, rd_col).
// =============================================================================

`timescale 1ns / 1ps

module output_buffer #(
    parameter N         = 4,
    parameter ACC_WIDTH = 24
)(
    input  wire                        clk,
    input  wire                        rst_n,

    // ── Capture interface ─────────────────────────────────────────────────
    // Assert capture=1 for one cycle when y_out is stable.
    // y_out[(i*N+j)*ACC_WIDTH +: ACC_WIDTH] = C[i][j]
    input  wire                        capture,
    input  wire [N*N*ACC_WIDTH-1:0]    y_in,

    // ── Readback interface ────────────────────────────────────────────────
    input  wire                        rd_en,
    input  wire [1:0]                  rd_row,   // 2 bits for N=4
    input  wire [1:0]                  rd_col,
    output reg  signed [ACC_WIDTH-1:0] rd_data
);

    reg signed [ACC_WIDTH-1:0] mem [0:N-1][0:N-1];

    integer i, j;

    // ── Capture: latch all N*N elements in one cycle ──────────────────────
    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < N; i = i + 1)
                for (j = 0; j < N; j = j + 1)
                    mem[i][j] <= 0;
        end else if (capture) begin
            for (i = 0; i < N; i = i + 1)
                for (j = 0; j < N; j = j + 1)
                    mem[i][j] <= $signed(y_in[(i*N+j)*ACC_WIDTH +: ACC_WIDTH]);
        end
    end

    // ── Readback ──────────────────────────────────────────────────────────
    always @(posedge clk) begin
        if (!rst_n)      rd_data <= 0;
        else if (rd_en)  rd_data <= mem[rd_row][rd_col];
    end

endmodule
