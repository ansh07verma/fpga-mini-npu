// =============================================================================
// NPU Top-Level — 4×4 INT8 Matrix Multiplier
//
// Computes C = A × B for 4×4 INT8 matrices.
//
// ── External Interface ────────────────────────────────────────────────────
//
// WRITE PHASE (before start):
//   Present each matrix element via the write port:
//     wr_en=1, wr_sel=0 (A matrix) or wr_sel=1 (B/weight matrix)
//     wr_row[1:0], wr_col[1:0], wr_data[7:0]
//
// COMPUTE PHASE:
//   Pulse start=1 for one cycle. The FSM takes over automatically.
//   done pulses high for one cycle when the result is ready (~2N+5 cycles).
//
// READ PHASE (after done):
//   rd_en=1, rd_row[1:0], rd_col[1:0] → rd_data (registered, 1-cycle latency)
//
// ── Internal Timing (N=4) ─────────────────────────────────────────────────
//
//  Cycle  State       FSM output      Systolic array action
//  0..3   LOAD_W      load_w=1        Load B rows 0..3 into weight_mem
//  4      CLR         clr=1,en=0      Zero all accumulators
//  5..8   COMPUTE     en=1            A[:,0..3] presented; row 0 accumulates
//  9..12  DRAIN       en=1,a=0        Flush skew pipeline (rows 1..3 finish)
//  13     DONE        capture,done=1  Latch all 16 outputs; assert done
//  14     IDLE        —               Ready for next operation
//
// ── Data Flow ─────────────────────────────────────────────────────────────
//
//   input_buffer  --[a_rows]-->  systolic_array_4x4  --[y_out(16x24)]--> output_buffer
//   weight_buffer --[w_row]-->  systolic_array_4x4
//   controller_fsm controls all enable/clear/capture signals
//
// =============================================================================

`timescale 1ns / 1ps

module npu_top #(
    parameter N          = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 24
)(
    input  wire        clk,
    input  wire        rst_n,

    // ── Matrix load interface ─────────────────────────────────────────────
    input  wire                         wr_en,
    input  wire                         wr_sel,    // 0=A (activation), 1=B (weight)
    input  wire [1:0]                   wr_row,
    input  wire [1:0]                   wr_col,
    input  wire signed [DATA_WIDTH-1:0] wr_data,

    // ── Control ───────────────────────────────────────────────────────────
    input  wire        start,
    output wire        done,

    // ── Result readback ───────────────────────────────────────────────────
    input  wire        rd_en,
    input  wire [1:0]  rd_row,
    input  wire [1:0]  rd_col,
    output wire signed [ACC_WIDTH-1:0] rd_data
);

    // ── FSM control signals ───────────────────────────────────────────────
    wire       fsm_load_w;
    wire       fsm_compute_en;
    wire       fsm_clr;
    wire       fsm_capture;
    wire       fsm_done;
    wire [2:0] phase_cnt;

    controller_fsm #(.N(N)) u_fsm (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (start),
        .load_w     (fsm_load_w),
        .compute_en (fsm_compute_en),
        .clr        (fsm_clr),
        .capture    (fsm_capture),
        .done       (fsm_done),
        .phase_cnt  (phase_cnt)
    );

    assign done = fsm_done;

    // ── Input buffer (matrix A) ───────────────────────────────────────────
    // Stores A[row][col], serves A[:,k] = a_rows during COMPUTE
    wire [N*DATA_WIDTH-1:0] a_rows_bus;

    input_buffer #(.N(N), .DATA_WIDTH(DATA_WIDTH)) u_ibuf (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (wr_en && !wr_sel),
        .wr_row  (wr_row),
        .wr_col  (wr_col),
        .wr_data (wr_data),
        .rd_en   (fsm_compute_en),        // Read during COMPUTE and DRAIN
        .rd_col  (phase_cnt[1:0]),        // Column k = phase_cnt within COMPUTE
        .rd_data (a_rows_bus)
    );

    // ── Weight buffer (matrix B) ──────────────────────────────────────────
    // Serves B[i,:] = w_row during LOAD_W (row i = phase_cnt)
    wire [N*DATA_WIDTH-1:0] w_row_bus;

    weight_buffer #(.N(N), .DATA_WIDTH(DATA_WIDTH)) u_wbuf (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (wr_en && wr_sel),
        .wr_row  (wr_row),
        .wr_col  (wr_col),
        .wr_data (wr_data),
        .rd_en   (fsm_load_w),
        .rd_row  (phase_cnt[1:0]),        // Row i = phase_cnt within LOAD_W
        .rd_data (w_row_bus)
    );

    // ── Systolic array ────────────────────────────────────────────────────
    wire [N*N*ACC_WIDTH-1:0] y_out_bus;
    wire                     y_valid;

    // During DRAIN, a_rows should be 0 (pipeline is flushing).
    // The input_buffer rd_en is held high during DRAIN but rd_col wraps
    // past N — so we gate a_rows to 0 when phase_cnt >= N.
    wire [N*DATA_WIDTH-1:0] a_rows_gated =
        (phase_cnt < N) ? a_rows_bus : {(N*DATA_WIDTH){1'b0}};

    systolic_array_4x4 #(
        .N         (N),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH (ACC_WIDTH)
    ) u_array (
        .clk    (clk),
        .rst_n  (rst_n),
        .load_w (fsm_load_w),
        .w_row  (w_row_bus),
        .en     (fsm_compute_en),
        .clr    (fsm_clr),
        .a_rows (a_rows_gated),
        .y_out  (y_out_bus),
        .valid  (y_valid)
    );

    // ── Output buffer ─────────────────────────────────────────────────────
    output_buffer #(.N(N), .ACC_WIDTH(ACC_WIDTH)) u_obuf (
        .clk     (clk),
        .rst_n   (rst_n),
        .capture (fsm_capture),
        .y_in    (y_out_bus),
        .rd_en   (rd_en),
        .rd_row  (rd_row),
        .rd_col  (rd_col),
        .rd_data (rd_data)
    );

endmodule
