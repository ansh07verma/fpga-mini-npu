// =============================================================================
// Processing Element (PE)
//
// Weight-stationary systolic array PE:
//   - Loads one weight value and holds it for the entire computation
//   - Passes activations rightward to neighbouring PEs  (a_out)
//   - Accumulates partial sums and passes them downward  (y_out)
//   - Two pipeline stages match the underlying MAC unit
// =============================================================================

`timescale 1ns / 1ps

module pe #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 24
)(
    input  wire                       clk,
    input  wire                       rst_n,
    input  wire                       load_w,    // Load weight pulse (hold until computation done)
    input  wire                       clr,       // Clear accumulator (start new row)
    input  wire                       en,        // Global compute enable
    input  wire signed [DATA_WIDTH-1:0] a_in,   // Activation from left / top boundary
    input  wire signed [DATA_WIDTH-1:0] w_in,   // Weight to be stored
    input  wire signed [ACC_WIDTH-1:0]  y_in,   // Partial sum from above PE
    output reg  signed [DATA_WIDTH-1:0] a_out,  // Activation forwarded to right
    output wire signed [ACC_WIDTH-1:0]  y_out   // Partial sum forwarded downward
);

    // -------------------------------------------------------------------------
    // Weight register — stationary throughout matrix multiplication
    // -------------------------------------------------------------------------
    reg signed [DATA_WIDTH-1:0] weight;

    always @(posedge clk) begin
        if (!rst_n)       weight <= 0;
        else if (load_w)  weight <= w_in;
    end

    // -------------------------------------------------------------------------
    // Activation forwarding register (adds 1-cycle skew for systolic rhythm)
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) a_out <= 0;
        else if (en) a_out <= a_in;
    end

    // -------------------------------------------------------------------------
    // MAC unit instance
    // -------------------------------------------------------------------------
    wire signed [ACC_WIDTH-1:0] mac_out;

    mac_unit #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH (ACC_WIDTH)
    ) u_mac (
        .clk   (clk),
        .rst_n (rst_n),
        .clr   (clr),
        .en    (en),
        .a     (a_in),
        .b     (weight),
        .y     (mac_out)
    );

    // -------------------------------------------------------------------------
    // Partial sum accumulation: mac_out adds onto incoming partial sum from above
    // y_out is registered to pipeline properly through the array
    // -------------------------------------------------------------------------
    reg signed [ACC_WIDTH-1:0] psum_reg;

    always @(posedge clk) begin
        if (!rst_n || clr) psum_reg <= 0;
        else if (en)       psum_reg <= mac_out + y_in;
    end

    assign y_out = psum_reg;

endmodule
