// =============================================================================
// CNN Inference Layer — 1D Convolution using NPU Systolic Array
//
// Pipeline: im2col → systolic_array_4x4 → relu_layer → output_buffer
//
// Key insight: systolic_array_4x4 has its own internal weight memory (wmem).
// During S_LOAD_W, we drive load_w=1 and present weight rows directly.
// The testbench loads weights via the wr_sel=1 interface into a local reg bank,
// then we use that bank to feed the systolic array at inference start.
//
// FSM: IDLE → LOAD_W(N) → CLR → COMPUTE(N) → DRAIN(N+2) → CAPTURE → [repeat | DONE]
//
// Parameters:
//   N   = 4  : array size, num filters, kernel size
//   IW       : input feature map width (IW > N)
//   DW  = 8  : INT8
//   AW  = 24 : accumulator
//   N_PATCHES = IW - N + 1
// =============================================================================

`timescale 1ns / 1ps

module cnn_layer #(
    parameter N   = 4,
    parameter IW  = 8,
    parameter DW  = 8,
    parameter AW  = 24
)(
    input  wire        clk,
    input  wire        rst_n,

    // Load interface
    input  wire                      wr_en,
    input  wire                      wr_sel,      // 0=input X, 1=weights W
    input  wire [1:0]                wr_row,
    input  wire [1:0]                wr_col,
    input  wire signed [DW-1:0]      wr_data,
    input  wire [$clog2(IW)-1:0]     wr_addr,

    // Control
    input  wire        start,
    output wire        done,

    // Readback: Y[rd_filter][rd_pos] after ReLU
    input  wire        rd_en,
    input  wire [2:0]  rd_filter,
    input  wire [2:0]  rd_pos,
    output wire signed [AW-1:0] rd_data
);

    localparam K         = N;
    localparam N_PATCHES = IW - K + 1;
    localparam DRAIN_LEN = N + 2;

    // ── Local weight storage (fed directly to systolic array) ─────────────────
    reg signed [DW-1:0] wt [0:N-1][0:N-1];
    integer i, j;

    initial begin
        for (i = 0; i < N; i = i+1)
            for (j = 0; j < N; j = j+1)
                wt[i][j] = 0;
    end

    always @(posedge clk) begin
        if (wr_en && wr_sel)
            wt[wr_row][wr_col] <= wr_data;
    end

    reg [$clog2(N_PATCHES+1)-1:0] patch_idx;

    // ── im2col ────────────────────────────────────────────────────────────────
    wire [K*DW-1:0]   patch_col;

    im2col #(.IW(IW), .K(K), .DW(DW), .STRIDE(1)) u_im2col (
        .clk       (clk),
        .rst_n     (rst_n),
        .wr_en     (wr_en & ~wr_sel),
        .wr_addr   (wr_addr),
        .wr_data   (wr_data),
        .patch_idx (patch_idx),
        .col_out   (patch_col)
    );

    // ── Systolic array ────────────────────────────────────────────────────────
    reg              sys_load_w, sys_en, sys_clr;
    reg  [N*DW-1:0]  sys_w_row;
    reg  [N*DW-1:0]  a_rows_reg;
    wire [N*N*AW-1:0] y_out_bus;
    wire              y_valid;

    systolic_array_4x4 #(.N(N), .DATA_WIDTH(DW), .ACC_WIDTH(AW)) u_array (
        .clk    (clk),
        .rst_n  (rst_n),
        .load_w (sys_load_w),
        .w_row  (sys_w_row),
        .en     (sys_en),
        .clr    (sys_clr),
        .a_rows (a_rows_reg),
        .y_out  (y_out_bus),
        .valid  (y_valid)
    );

    // ── ReLU ──────────────────────────────────────────────────────────────────
    reg               cap_pulse;
    wire              relu_valid;
    wire [N*N*AW-1:0] relu_out;

    relu_layer #(.N(N), .ACC_WIDTH(AW)) u_relu (
        .clk      (clk),
        .rst_n    (rst_n),
        .in_valid (cap_pulse),
        .in_data  (y_out_bus),
        .out_valid(relu_valid),
        .out_data (relu_out)
    );

    // ── Output buffer ─────────────────────────────────────────────────────────
    reg signed [AW-1:0] out_mem [0:N-1][0:N_PATCHES-1];
    reg [2:0]            cap_pos_r;        // Current capture position (updated in CAPTURE state)
    reg [2:0]            cap_pos_delay;    // 1-cycle delayed cap_pos_r (aligned with relu_valid)
    integer f, p;

    initial begin
        for (f = 0; f < N; f = f+1)
            for (p = 0; p < N_PATCHES; p = p+1)
                out_mem[f][p] = 0;
    end

    // Delay cap_pos_r by 1 cycle to align with relu_valid (relu_layer has 1-cycle latency)
    always @(posedge clk) begin
        cap_pos_delay <= cap_pos_r;
    end

    always @(posedge clk) begin
        if (relu_valid) begin
            for (f = 0; f < N; f = f+1)
                // We use ROW 0 of the systolic array for all filters (since they are in columns)
                // relu_out[(0*N + f)*AW +: AW] corresponds to acc[0][f]
                out_mem[f][cap_pos_delay] <= $signed(relu_out[f*AW +: AW]);
        end
    end

    reg signed [AW-1:0] rd_data_r;
    always @(posedge clk) begin
        if (!rst_n)     rd_data_r <= 0;
        else if (rd_en) rd_data_r <= out_mem[rd_filter][rd_pos];
    end
    assign rd_data = rd_data_r;

    // ── Unified Control FSM ───────────────────────────────────────────────────
    localparam [3:0]
        S_IDLE    = 4'd0,
        S_LOAD_W  = 4'd1,  // Assert load_w=1, present weight rows one per cycle
        S_CLR     = 4'd2,  // Clear systolic accumulators (clr=1, en=1, a=0)
        S_COMPUTE = 4'd3,  // Stream K patch elements
        S_DRAIN   = 4'd4,  // Flush pipeline
        S_CAPTURE = 4'd5,  // Pulse cap → ReLU → out_mem
        S_DONE    = 4'd6;

    reg [3:0]  state;
    reg [3:0]  phase;
    reg        done_r;

    assign done = done_r;

    always @(posedge clk) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            phase        <= 0;
            patch_idx    <= 0;
            sys_load_w   <= 0;
            sys_en       <= 0;
            sys_clr      <= 0;
            sys_w_row    <= 0;
            a_rows_reg   <= 0;
            done_r       <= 0;
        end else begin
            sys_clr      <= 0;
            sys_load_w   <= 0;
            cap_pulse    <= 0;
            done_r       <= 0;

            case (state)
                S_IDLE: begin
                    sys_en    <= 0;
                    patch_idx <= 0;
                    if (start) begin
                        phase        <= 0;
                        state        <= S_LOAD_W;
                    end
                end

                // Load N weight rows into systolic array's wmem
                // We map filter N to column N by transposing the weights!
                // wt[filter][element]. We want w_row to feed the 4 columns for element 'phase'.
                S_LOAD_W: begin
                    sys_load_w <= 1;
                    sys_en     <= 0;
                    // Pack kernel element 'phase' for all filters into sys_w_row
                    sys_w_row <= {wt[3][phase], wt[2][phase],
                                  wt[1][phase], wt[0][phase]};
                    if (phase == N-1) begin
                        state <= S_CLR;
                        phase <= 0;
                    end else begin
                        phase <= phase + 1;
                    end
                end

                // Clear PE accumulators (en=1 required for mac_unit to respond)
                S_CLR: begin
                    sys_clr    <= 1;
                    sys_en     <= 1;
                    a_rows_reg <= 0;
                    state      <= S_COMPUTE;
                    phase      <= 0;
                end

                // Feed K patch elements (only to ROW 0)
                S_COMPUTE: begin
                    sys_clr    <= 0;
                    sys_en     <= 1;
                    a_rows_reg <= {24'd0, patch_col[phase*DW +: DW]};
                    if (phase == N-1) begin
                        state <= S_DRAIN;
                        phase <= 0;
                    end else begin
                        phase <= phase + 1;
                    end
                end

                // Flush skew pipeline (N+2 extra cycles with a=0)
                S_DRAIN: begin
                    sys_en     <= 1;
                    a_rows_reg <= 0;
                    if (phase == DRAIN_LEN-1) begin
                        state <= S_CAPTURE;
                        phase <= 0;
                    end else begin
                        phase <= phase + 1;
                    end
                end

                // Latch y_out → ReLU → out_mem
                S_CAPTURE: begin
                    sys_en    <= 0;
                    cap_pulse <= 1;
                    cap_pos_r <= patch_idx[2:0];

                    if (patch_idx == N_PATCHES-1) begin
                        state <= S_DONE;
                    end else begin
                        patch_idx <= patch_idx + 1;
                        state     <= S_CLR;  // Next patch
                    end
                end

                S_DONE: begin
                    done_r <= 1;
                    state  <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
