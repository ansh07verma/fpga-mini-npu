// =============================================================================
// im2col Pre-Processor (Combinatorial Extraction)
//
// Stores the input feature map (1D) and provides a combinatorial read
// of the K-element patch starting at patch_idx * STRIDE.
// =============================================================================

`timescale 1ns / 1ps

module im2col #(
    parameter IW     = 8,     // Input vector length
    parameter K      = 4,     // Kernel size
    parameter DW     = 8,     // Data width (INT8)
    parameter STRIDE = 1      // Convolution stride
)(
    input  wire             clk,
    input  wire             rst_n,

    // ── Input load port ──────────────────────────────────────────────────────
    input  wire             wr_en,
    input  wire [$clog2(IW)-1:0] wr_addr,
    input  wire signed [DW-1:0]  wr_data,

    // ── Extraction ───────────────────────────────────────────────────────────
    input  wire [$clog2(IW)-1:0] patch_idx,
    output wire [K*DW-1:0]       col_out
);

    reg signed [DW-1:0] ibuf [0:IW-1];
    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < IW; i = i + 1) ibuf[i] <= 0;
        end else if (wr_en) begin
            ibuf[wr_addr] <= wr_data;
        end
    end

    genvar k;
    generate
        for (k = 0; k < K; k = k + 1) begin : extract
            assign col_out[k*DW +: DW] = ibuf[patch_idx * STRIDE + k];
        end
    endgenerate

endmodule
