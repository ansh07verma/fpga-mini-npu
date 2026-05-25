// =============================================================================
// ReLU Layer
//
// Applies element-wise Rectified Linear Unit (ReLU) to the output of the
// systolic array accumulator outputs:
//
//   relu(x) = max(0, x)  =  x  if x > 0
//                         =  0  if x <= 0
//
// Parameters:
//   N        — array dimension (number of rows = columns)
//   ACC_WIDTH — accumulator bit width (e.g., 24 for INT8 4×4 matmul)
//
// Interface:
//   in_valid / in_data   : input  — flat N×N accumulator bus
//   out_valid / out_data : output — relu'd values, registered (1-cycle latency)
//
// The ReLU is performed purely in combinatorial logic (sign-bit check) with
// one pipeline register for clean timing closure.
// =============================================================================

`timescale 1ns / 1ps

module relu_layer #(
    parameter N         = 4,
    parameter ACC_WIDTH = 24
)(
    input  wire                        clk,
    input  wire                        rst_n,
    input  wire                        in_valid,
    input  wire [N*N*ACC_WIDTH-1:0]    in_data,
    output reg                         out_valid,
    output reg  [N*N*ACC_WIDTH-1:0]    out_data
);

    integer i;

    // Combinatorial ReLU: clamp negative values to zero
    // Sign bit is in_data[(i+1)*ACC_WIDTH-1]
    always @(posedge clk) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_data  <= {(N*N*ACC_WIDTH){1'b0}};
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                for (i = 0; i < N*N; i = i + 1) begin
                    // If sign bit is 1 (negative), output 0; else pass through
                    if (in_data[(i+1)*ACC_WIDTH-1])
                        out_data[i*ACC_WIDTH +: ACC_WIDTH] <= {ACC_WIDTH{1'b0}};
                    else
                        out_data[i*ACC_WIDTH +: ACC_WIDTH] <= in_data[i*ACC_WIDTH +: ACC_WIDTH];
                end
            end
        end
    end

endmodule
