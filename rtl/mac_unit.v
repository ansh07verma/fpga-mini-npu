// =============================================================================
// MAC Unit — Multiply-Accumulate
// y = y + (a × b)
//
// Data width : 8-bit signed inputs (INT8)
// Accumulator: 24-bit signed (no overflow for 4×4 INT8 matrix chains:
//              max chain value = 4 × 127 × 127 = 64,516 << 8,388,607)
//
// Pipeline   : Single registered stage
//              On each posedge with en=1:
//                if clr: y <= sign_extend(a * b)   (start fresh dot-product)
//                else  : y <= y + sign_extend(a * b) (accumulate)
//
// Note: The multiply is performed combinatorially and registered in one cycle.
//       This maps to a single DSP48 slice in Xilinx (pre-adder optional).
//       If timing is tight, add a pipeline register before the accumulator.
// =============================================================================

`timescale 1ns / 1ps

module mac_unit #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 24
)(
    input  wire                          clk,
    input  wire                          rst_n,    // Active-low synchronous reset
    input  wire                          clr,      // Clear accumulator (start new dot-product)
    input  wire                          en,       // Clock enable
    input  wire signed [DATA_WIDTH-1:0]  a,        // Activation input
    input  wire signed [DATA_WIDTH-1:0]  b,        // Weight input
    output reg  signed [ACC_WIDTH-1:0]   y         // Accumulated output
);

    // Combinatorial multiply (16-bit signed intermediate)
    wire signed [2*DATA_WIDTH-1:0] product = a * b;

    // Sign-extend product to accumulator width
    wire signed [ACC_WIDTH-1:0] product_ext =
        {{(ACC_WIDTH - 2*DATA_WIDTH){product[2*DATA_WIDTH-1]}}, product};

    // Accumulator — (* use_dsp = "yes" *) forces Vivado to map this to a
    // DSP48E1 slice (8×8 multiply + 24-bit accumulate in one primitive).
    // Without this hint, small multipliers may be absorbed into LUT/CARRY4.
    (* use_dsp = "yes" *)
    always @(posedge clk) begin
        if (!rst_n) begin
            y <= {ACC_WIDTH{1'b0}};
        end else if (en) begin
            if (clr)
                y <= product_ext;          // Load first product (clear old accumulation)
            else
                y <= y + product_ext;      // Accumulate
        end
        // en=0: hold current value
    end

endmodule
