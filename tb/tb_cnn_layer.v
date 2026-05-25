// =============================================================================
// Testbench: CNN Layer (End-to-End)
//
// Tests the full cnn_layer pipeline:
//   im2col → systolic_array → relu → output_buffer
//
// Test scenario (simple all-ones weights):
//   Input X = [1, 2, 3, 4, 5, 6, 7, 8]  (IW=8)
//   Weights W: ALL ROWS = [1,1,1,1] (all-ones)
//   Kernel K=N=4, stride=1 → N_PATCHES = 8-4+1 = 5
//
// Golden: Y[f][p] = sum(X[p:p+4]) for all filters f
//   p=0: 1+2+3+4 = 10
//   p=1: 2+3+4+5 = 14
//   p=2: 3+4+5+6 = 18
//   p=3: 4+5+6+7 = 22
//   p=4: 5+6+7+8 = 26
//
// After ReLU (all positive): same values.
// All 4 filters produce the same output.
// Total checks: N * N_PATCHES = 4 * 5 = 20
// =============================================================================
`timescale 1ns / 1ps

module tb_cnn_layer;

    localparam N   = 4;
    localparam K   = N;
    localparam IW  = 8;
    localparam DW  = 8;
    localparam AW  = 24;
    localparam N_PATCHES = IW - K + 1;  // 5

    reg  clk=0, rst_n=0;
    reg  wr_en=0, wr_sel=0;
    reg  [1:0] wr_row=0, wr_col=0;
    reg  signed [DW-1:0] wr_data=0;
    reg  [$clog2(IW)-1:0] wr_addr=0;
    reg  start=0;
    wire done;
    reg  rd_en=0;
    reg  [2:0] rd_filter=0, rd_pos=0;
    wire signed [AW-1:0] rd_data;

    cnn_layer #(.N(N),.IW(IW),.DW(DW),.AW(AW)) dut(
        .clk(clk),.rst_n(rst_n),
        .wr_en(wr_en),.wr_sel(wr_sel),
        .wr_row(wr_row),.wr_col(wr_col),.wr_data(wr_data),.wr_addr(wr_addr),
        .start(start),.done(done),
        .rd_en(rd_en),.rd_filter(rd_filter),.rd_pos(rd_pos),.rd_data(rd_data));

    always #5 clk = ~clk;

    integer pass_cnt=0, fail_cnt=0;
    integer f, p, i;

    // Golden: Y[f][p] = sum(X[p:p+N])
    // X = [1..8], sum of any 4 consecutive:
    reg signed [AW-1:0] golden [0:N-1][0:N_PATCHES-1];

    task load_weight;
        input [1:0] row, col;
        input signed [DW-1:0] val;
        begin
            @(negedge clk);
            wr_en=1; wr_sel=1; wr_row=row; wr_col=col; wr_data=val;
            @(posedge clk); #1;
        end
    endtask

    task load_input;
        input [2:0] addr;
        input signed [DW-1:0] val;
        begin
            @(negedge clk);
            wr_en=1; wr_sel=0; wr_addr=addr; wr_data=val;
            @(posedge clk); #1;
        end
    endtask

    initial begin
        $dumpfile("C:/Users/user/.gemini/antigravity-ide/scratch/fpga-mini-npu/results/simulation_logs/cnn_layer.vcd");
        $dumpvars(0, tb_cnn_layer);
    end

    initial begin
        // Build golden model: W = all-ones → Y[f][p] = sum(X[p..p+N-1])
        for (f=0; f<N; f=f+1)
            for (p=0; p<N_PATCHES; p=p+1) begin
                // sum(X[p], X[p+1], X[p+2], X[p+3])
                // X[i] = i+1
                golden[f][p] = (p+1) + (p+2) + (p+3) + (p+4);
                // = 4p + 10
            end

        // Reset
        repeat(3) @(posedge clk); #1; rst_n=1;
        repeat(2) @(posedge clk); #1;

        // ── Load weight matrix W (all ones) ──────────────────────────────────
        $display("[Step 1] Loading W = all-ones...");
        for (f=0; f<N; f=f+1)
            for (i=0; i<K; i=i+1)
                load_weight(f[1:0], i[1:0], 8'sd1);

        @(negedge clk); wr_en=0;
        repeat(2) @(posedge clk); #1;

        // ── Load input X = [1..8] ─────────────────────────────────────────────
        $display("[Step 2] Loading X = [1..8]...");
        for (i=0; i<IW; i=i+1)
            load_input(i[2:0], i+1);

        @(negedge clk); wr_en=0;
        repeat(2) @(posedge clk); #1;

        // ── Start inference ───────────────────────────────────────────────────
        $display("[Step 3] Starting inference (N=%0d, IW=%0d, patches=%0d, golden[0][0]=%0d)...",
                 N, IW, N_PATCHES, $signed(golden[0][0]));
        @(negedge clk); start=1;
        @(posedge clk); #1;
        @(negedge clk); start=0;

        // Wait for done
        begin : wait_done
            integer timeout;
            timeout = 0;
            while (!done && timeout < 5000) begin
                @(posedge clk); #1;
                timeout = timeout + 1;
            end
            if (timeout >= 5000) begin
                $display("TIMEOUT waiting for done!");
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("[Step 4] Done after %0d cycles", timeout);
            end
        end

        repeat(5) @(posedge clk); #1;

        // ── Readback and verify ───────────────────────────────────────────────
        $display("[Step 5] Verifying %0d outputs...", N*N_PATCHES);
        for (f=0; f<N; f=f+1) begin
            for (p=0; p<N_PATCHES; p=p+1) begin
                @(negedge clk);
                rd_en=1; rd_filter=f[2:0]; rd_pos=p[2:0];
                @(posedge clk); #1;
                @(negedge clk); rd_en=0;
                @(posedge clk); #1;

                if ($signed(rd_data) === $signed(golden[f][p])) begin
                    pass_cnt = pass_cnt + 1;
                    $display("  [PASS] Y[%0d][%0d] = %0d", f, p, $signed(rd_data));
                end else begin
                    fail_cnt = fail_cnt + 1;
                    $display("  [FAIL] Y[%0d][%0d] = %0d (exp %0d)",
                             f, p, $signed(rd_data), $signed(golden[f][p]));
                end
            end
        end

        $display("\n=== RESULTS: %0d PASS / %0d FAIL ===\n", pass_cnt, fail_cnt);
        $finish;
    end

endmodule
