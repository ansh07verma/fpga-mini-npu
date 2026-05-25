// =============================================================================
// 4x4 Systolic Array — Correct Dataflow (Final)
//
// C[i][j] = sum_{k=0}^{3} A[i][k] * B[k][j]
//
// Protocol:
//   1. Pulse clr=1 (en=0) for one cycle to zero accumulators and counters
//   2. Assert en=1 and stream A[:,k] for k=0..N-1 (each cycle one column)
//   3. Results valid 2N-1 cycles after first en
//
// Key fix: acc_en signals are COMBINATORIAL (not registered) so that the
// very first en cycle triggers accumulation with kr=0 and a_s=A[r][0].
// =============================================================================

`timescale 1ns / 1ps

module systolic_array_4x4 #(
    parameter N          = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 24
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         load_w,
    input  wire [N*DATA_WIDTH-1:0]      w_row,
    input  wire                         en,
    input  wire                         clr,
    input  wire [N*DATA_WIDTH-1:0]      a_rows,
    output wire [N*N*ACC_WIDTH-1:0]     y_out,
    output reg                          valid
);

    // ── Weight memory ─────────────────────────────────────────────────────────
    reg signed [7:0] wmem [0:3][0:3];
    reg [1:0] ld_cnt;

    always @(posedge clk) begin
        if (!rst_n || clr) begin
            ld_cnt <= 0;
        end else if (load_w) begin
            wmem[ld_cnt][0] <= $signed(w_row[ 0 +: 8]);
            wmem[ld_cnt][1] <= $signed(w_row[ 8 +: 8]);
            wmem[ld_cnt][2] <= $signed(w_row[16 +: 8]);
            wmem[ld_cnt][3] <= $signed(w_row[24 +: 8]);
            ld_cnt <= ld_cnt + 1;
        end
    end

    // ── Activation skew pipeline ──────────────────────────────────────────────
    wire signed [7:0] a0 = $signed(a_rows[0 +: 8]);

    reg signed [7:0] a1_r;
    always @(posedge clk) begin
        if (!rst_n) a1_r <= 0;
        else a1_r <= $signed(a_rows[8 +: 8]);
    end

    reg signed [7:0] a2_r0, a2_r1;
    always @(posedge clk) begin
        if (!rst_n) begin a2_r0<=0; a2_r1<=0; end
        else begin a2_r0 <= $signed(a_rows[16 +: 8]); a2_r1 <= a2_r0; end
    end

    reg signed [7:0] a3_r0, a3_r1, a3_r2;
    always @(posedge clk) begin
        if (!rst_n) begin a3_r0<=0; a3_r1<=0; a3_r2<=0; end
        else begin a3_r0 <= $signed(a_rows[24 +: 8]); a3_r1 <= a3_r0; a3_r2 <= a3_r1; end
    end

    wire signed [7:0] a1 = a1_r;
    wire signed [7:0] a2 = a2_r1;
    wire signed [7:0] a3 = a3_r2;

    // ── Weight-row pointer (counts which row of wmem to use this cycle) ───────
    // kr advances once per en cycle. For row r, we need the value r cycles ago.
    // Use: kr0 for row 0, kr0_d1 for row 1, etc.
    reg [1:0] kr0;
    always @(posedge clk) begin
        if (!rst_n || clr) kr0 <= 0;
        else if (en) kr0 <= kr0 + 1;
    end

    reg [1:0] kr1, kr2a, kr2b, kr3a, kr3b, kr3c;
    always @(posedge clk) begin
        if (!rst_n || clr) begin
            kr1<=0; kr2a<=0; kr2b<=0; kr3a<=0; kr3b<=0; kr3c<=0;
        end else begin
            kr1 <= kr0;
            kr2a <= kr0;  kr2b <= kr2a;
            kr3a <= kr0;  kr3b <= kr3a;  kr3c <= kr3b;
        end
    end

    // ── Per-row accumulate counters (count how many times each row has fired) ─
    // Each row fires exactly N times. Counter resets on clr.
    // acc_en_r is COMBINATORIAL: row r accumulates when its counter < N
    // AND its delayed en is active.

    // Delayed enables: row r starts when en has been high for r+1 cycles
    reg en_d1, en_d2, en_d3;
    always @(posedge clk) begin
        if (!rst_n || clr) begin en_d1<=0; en_d2<=0; en_d3<=0; end
        else begin en_d1<=en; en_d2<=en_d1; en_d3<=en_d2; end
    end

    reg [2:0] cnt0, cnt1, cnt2, cnt3;
    always @(posedge clk) begin
        if (!rst_n || clr) begin cnt0<=0; cnt1<=0; cnt2<=0; cnt3<=0; end
        else begin
            if (en    && cnt0 < N) cnt0 <= cnt0 + 1;
            if (en_d1 && cnt1 < N) cnt1 <= cnt1 + 1;
            if (en_d2 && cnt2 < N) cnt2 <= cnt2 + 1;
            if (en_d3 && cnt3 < N) cnt3 <= cnt3 + 1;
        end
    end

    // Combinatorial enables (allow accumulation in the SAME cycle as en fires)
    wire acc_en0 = en    && (cnt0 < N);
    wire acc_en1 = en_d1 && (cnt1 < N);
    wire acc_en2 = en_d2 && (cnt2 < N);
    wire acc_en3 = en_d3 && (cnt3 < N);

    // ── Products ──────────────────────────────────────────────────────────────
    wire signed [15:0] p00=a0*wmem[kr0][0]; wire signed [15:0] p01=a0*wmem[kr0][1];
    wire signed [15:0] p02=a0*wmem[kr0][2]; wire signed [15:0] p03=a0*wmem[kr0][3];

    wire signed [15:0] p10=a1*wmem[kr1][0]; wire signed [15:0] p11=a1*wmem[kr1][1];
    wire signed [15:0] p12=a1*wmem[kr1][2]; wire signed [15:0] p13=a1*wmem[kr1][3];

    wire signed [15:0] p20=a2*wmem[kr2b][0]; wire signed [15:0] p21=a2*wmem[kr2b][1];
    wire signed [15:0] p22=a2*wmem[kr2b][2]; wire signed [15:0] p23=a2*wmem[kr2b][3];

    wire signed [15:0] p30=a3*wmem[kr3c][0]; wire signed [15:0] p31=a3*wmem[kr3c][1];
    wire signed [15:0] p32=a3*wmem[kr3c][2]; wire signed [15:0] p33=a3*wmem[kr3c][3];

    wire signed [23:0] e00={{8{p00[15]}},p00}; wire signed [23:0] e01={{8{p01[15]}},p01};
    wire signed [23:0] e02={{8{p02[15]}},p02}; wire signed [23:0] e03={{8{p03[15]}},p03};
    wire signed [23:0] e10={{8{p10[15]}},p10}; wire signed [23:0] e11={{8{p11[15]}},p11};
    wire signed [23:0] e12={{8{p12[15]}},p12}; wire signed [23:0] e13={{8{p13[15]}},p13};
    wire signed [23:0] e20={{8{p20[15]}},p20}; wire signed [23:0] e21={{8{p21[15]}},p21};
    wire signed [23:0] e22={{8{p22[15]}},p22}; wire signed [23:0] e23={{8{p23[15]}},p23};
    wire signed [23:0] e30={{8{p30[15]}},p30}; wire signed [23:0] e31={{8{p31[15]}},p31};
    wire signed [23:0] e32={{8{p32[15]}},p32}; wire signed [23:0] e33={{8{p33[15]}},p33};

    // ── Accumulators ─────────────────────────────────────────────────────────
    reg signed [23:0] acc [0:3][0:3];

    always @(posedge clk) begin
        if (!rst_n || clr) begin acc[0][0]<=0; acc[0][1]<=0; acc[0][2]<=0; acc[0][3]<=0; end
        else if (acc_en0) begin
            acc[0][0]<=acc[0][0]+e00; acc[0][1]<=acc[0][1]+e01;
            acc[0][2]<=acc[0][2]+e02; acc[0][3]<=acc[0][3]+e03;
        end
    end
    always @(posedge clk) begin
        if (!rst_n || clr) begin acc[1][0]<=0; acc[1][1]<=0; acc[1][2]<=0; acc[1][3]<=0; end
        else if (acc_en1) begin
            acc[1][0]<=acc[1][0]+e10; acc[1][1]<=acc[1][1]+e11;
            acc[1][2]<=acc[1][2]+e12; acc[1][3]<=acc[1][3]+e13;
        end
    end
    always @(posedge clk) begin
        if (!rst_n || clr) begin acc[2][0]<=0; acc[2][1]<=0; acc[2][2]<=0; acc[2][3]<=0; end
        else if (acc_en2) begin
            acc[2][0]<=acc[2][0]+e20; acc[2][1]<=acc[2][1]+e21;
            acc[2][2]<=acc[2][2]+e22; acc[2][3]<=acc[2][3]+e23;
        end
    end
    always @(posedge clk) begin
        if (!rst_n || clr) begin acc[3][0]<=0; acc[3][1]<=0; acc[3][2]<=0; acc[3][3]<=0; end
        else if (acc_en3) begin
            acc[3][0]<=acc[3][0]+e30; acc[3][1]<=acc[3][1]+e31;
            acc[3][2]<=acc[3][2]+e32; acc[3][3]<=acc[3][3]+e33;
        end
    end

    // ── Output ────────────────────────────────────────────────────────────────
    genvar ii, jj;
    generate
        for (ii = 0; ii < N; ii = ii + 1) begin : out_r
            for (jj = 0; jj < N; jj = jj + 1) begin : out_c
                assign y_out[(ii*N+jj)*ACC_WIDTH +: ACC_WIDTH] = acc[ii][jj];
            end
        end
    endgenerate

    // ── Valid: row 3 completes on cnt3 == N ──────────────────────────────────
    always @(posedge clk) begin
        if (!rst_n || clr) valid <= 0;
        else valid <= (cnt3 == N-1 && acc_en3) ? 1'b1 : 1'b0;
    end

endmodule
