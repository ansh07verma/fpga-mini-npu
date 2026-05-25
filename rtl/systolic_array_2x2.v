// =============================================================================
// 2x2 Systolic Array  (subset of 4x4, explicitly instantiated for clarity)
//
// Useful for simpler demonstrations and as a stepping stone.
// Architecture and timing are identical to systolic_array_4x4 but with N=2.
// =============================================================================

`timescale 1ns / 1ps

module systolic_array_2x2 #(
    parameter N          = 2,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 24
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         load_w,
    input  wire [N*DATA_WIDTH-1:0]      w_row,
    input  wire                         en,
    input  wire                         clr,
    input  wire [N*DATA_WIDTH-1:0]      a_col,
    output wire [N*ACC_WIDTH-1:0]       y_out,
    output reg                          valid
);

    // Internal connection wires
    wire signed [DATA_WIDTH-1:0] a_wire [0:N-1][0:N];
    wire signed [ACC_WIDTH-1:0]  y_wire [0:N][0:N-1];

    genvar r, c;

    generate
        for (r = 0; r < N; r = r + 1) begin : row_boundary
            assign a_wire[r][0] = a_col[r*DATA_WIDTH +: DATA_WIDTH];
            assign y_wire[0][r] = {ACC_WIDTH{1'b0}};
        end
    endgenerate

    generate
        for (r = 0; r < N; r = r + 1) begin : pe_row
            for (c = 0; c < N; c = c + 1) begin : pe_col
                pe #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH (ACC_WIDTH)
                ) u_pe (
                    .clk   (clk),
                    .rst_n (rst_n),
                    .load_w(load_w),
                    .clr   (clr),
                    .en    (en),
                    .a_in  (a_wire[r][c]),
                    .w_in  (w_row[r*DATA_WIDTH +: DATA_WIDTH]),
                    .y_in  (y_wire[r][c]),
                    .a_out (a_wire[r][c+1]),
                    .y_out (y_wire[r+1][c])
                );
            end
        end
    endgenerate

    generate
        for (c = 0; c < N; c = c + 1) begin : output_collect
            assign y_out[c*ACC_WIDTH +: ACC_WIDTH] = y_wire[N][c];
        end
    endgenerate

    reg [3:0] cycle_cnt;

    always @(posedge clk) begin
        if (!rst_n || clr) begin
            cycle_cnt <= 0;
            valid     <= 0;
        end else if (en) begin
            cycle_cnt <= cycle_cnt + 1;
            valid <= (cycle_cnt == N + 1) ? 1'b1 : 1'b0;
        end else begin
            valid <= 0;
        end
    end

endmodule
