// =============================================================================
// Controller FSM — NPU Sequencer
//
// Drives the systolic array through the verified protocol:
//
//   IDLE ──► LOAD_W (N cycles) ──► CLR (1 cycle) ──► COMPUTE (N cycles)
//                                                           │
//                                               DRAIN (N+2 cycles)
//                                                           │
//                                                        DONE (1 cycle) ──► IDLE
//
// Key protocol constraints (verified against systolic_array_4x4):
//   - CLR must fire ALONE (en=0) for exactly 1 cycle before COMPUTE
//   - The first COMPUTE cycle presents a_rows[:,0] with en=1, clr=0
//   - DRAIN keeps en=1, a_rows=0 for N+2 extra cycles to flush the
//     activation skew pipeline (deepest skew is N-1 for row N-1)
//
// One-hot state encoding for clean Vivado debug view.
// =============================================================================

`timescale 1ns / 1ps

module controller_fsm #(
    parameter N = 4
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,        // Pulse: begin new matrix multiply

    // ── Datapath control outputs ─────────────────────────────────────────
    output reg         load_w,       // Weight buffer → systolic array load_w
    output reg         compute_en,   // Systolic array en (COMPUTE + DRAIN)
    output reg         clr,          // Systolic array clr (CLR state only)
    output reg         capture,      // Output buffer capture enable (DONE)
    output reg         done,         // Result ready (1 cycle pulse)

    // ── Phase counter output (drives buffer address) ──────────────────────
    output reg [2:0]   phase_cnt     // Counts within each state (0..N+2)
);

    // ── One-hot states ────────────────────────────────────────────────────
    localparam [6:0]
        S_IDLE    = 7'b0000001,
        S_LOAD_W  = 7'b0000010,   // N cycles: load weight rows
        S_CLR     = 7'b0000100,   // 1 cycle:  clear accumulators
        S_COMPUTE = 7'b0001000,   // N cycles: stream A[:,0..N-1]
        S_DRAIN   = 7'b0010000,   // N+2 cycles: flush skew pipeline
        S_DONE    = 7'b0100000,   // 1 cycle:  capture outputs, assert done
        S_IDLE2   = 7'b1000000;   // Return to idle after done

    reg [6:0] state;

    // ── State register + phase counter ────────────────────────────────────
    always @(posedge clk) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            phase_cnt <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    phase_cnt <= 0;
                    if (start) state <= S_LOAD_W;
                end

                S_LOAD_W: begin
                    if (phase_cnt == N-1) begin
                        state     <= S_CLR;
                        phase_cnt <= 0;
                    end else begin
                        phase_cnt <= phase_cnt + 1;
                    end
                end

                S_CLR: begin
                    state     <= S_COMPUTE;
                    phase_cnt <= 0;
                end

                S_COMPUTE: begin
                    if (phase_cnt == N-1) begin
                        state     <= S_DRAIN;
                        phase_cnt <= 0;
                    end else begin
                        phase_cnt <= phase_cnt + 1;
                    end
                end

                S_DRAIN: begin
                    if (phase_cnt == N+1) begin   // N+2 cycles (0..N+1)
                        state     <= S_DONE;
                        phase_cnt <= 0;
                    end else begin
                        phase_cnt <= phase_cnt + 1;
                    end
                end

                S_DONE: begin
                    state     <= S_IDLE;
                    phase_cnt <= 0;
                end

                default: begin
                    state     <= S_IDLE;
                    phase_cnt <= 0;
                end
            endcase
        end
    end

    // ── Output logic (Moore) ──────────────────────────────────────────────
    always @(*) begin
        load_w     = 1'b0;
        compute_en = 1'b0;
        clr        = 1'b0;
        capture    = 1'b0;
        done       = 1'b0;

        case (state)
            S_IDLE:    ; // all low
            S_LOAD_W:  load_w     = 1'b1;
            S_CLR:     clr        = 1'b1;           // en=0, clr=1
            S_COMPUTE: compute_en = 1'b1;           // en=1, clr=0
            S_DRAIN:   compute_en = 1'b1;           // en stays high, a_rows=0
            S_DONE:    begin
                capture = 1'b1;
                done    = 1'b1;
            end
            default: ;
        endcase
    end

endmodule
