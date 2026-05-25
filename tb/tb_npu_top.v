// =============================================================================
// Testbench: NPU Top-Level — End-to-End System Test
//
// Tests the full pipeline:
//   1. Load A and B matrices via the write port
//   2. Pulse start
//   3. Wait for done
//   4. Read back all 16 elements via rd_row/rd_col
//   5. Compare against in-testbench golden model
//
// Tests:
//   1. A * I = A  (identity sanity)
//   2. General 4×4 multiply
//   3. Negative values
//   4. Zero matrix
// =============================================================================

`timescale 1ns / 1ps

module tb_npu_top;

    localparam N  = 4;
    localparam DW = 8;
    localparam AW = 24;
    localparam MAX_WAIT = 200;  // Max cycles to wait for done before timeout

    // ── DUT ports ─────────────────────────────────────────────────────────
    reg        clk=0, rst_n=0;
    reg        wr_en=0, wr_sel=0;
    reg  [1:0] wr_row=0, wr_col=0;
    reg  signed [DW-1:0] wr_data=0;
    reg        start=0;
    wire       done;
    reg        rd_en=0;
    reg  [1:0] rd_row=0, rd_col=0;
    wire signed [AW-1:0] rd_data;

    npu_top #(.N(N),.DATA_WIDTH(DW),.ACC_WIDTH(AW)) dut (
        .clk(clk),.rst_n(rst_n),
        .wr_en(wr_en),.wr_sel(wr_sel),.wr_row(wr_row),.wr_col(wr_col),.wr_data(wr_data),
        .start(start),.done(done),
        .rd_en(rd_en),.rd_row(rd_row),.rd_col(rd_col),.rd_data(rd_data)
    );

    always #5 clk = ~clk;

    // ── Test state ────────────────────────────────────────────────────────
    reg signed [DW-1:0] A [0:N-1][0:N-1];
    reg signed [DW-1:0] B [0:N-1][0:N-1];
    reg signed [AW-1:0] C_gold [0:N-1][0:N-1];
    reg signed [AW-1:0] hw_v;
    integer pass_cnt=0, fail_cnt=0;
    integer i, j, k, wait_cyc;

    // ── Golden model ───────────────────────────────────────────────────────
    task compute_golden;
        begin
            for (i=0;i<N;i=i+1)
                for (j=0;j<N;j=j+1) begin
                    C_gold[i][j]=0;
                    for (k=0;k<N;k=k+1)
                        C_gold[i][j]=C_gold[i][j]+A[i][k]*B[k][j];
                end
        end
    endtask

    // ── Write one element to the NPU ──────────────────────────────────────
    task write_elem;
        input sel;            // 0=A, 1=B
        input [1:0] rr, cc;
        input signed [DW-1:0] dat;
        begin
            @(negedge clk);
            wr_en=1; wr_sel=sel; wr_row=rr; wr_col=cc; wr_data=dat;
            @(posedge clk); #1;
            wr_en=0;
        end
    endtask

    // ── Load both matrices ─────────────────────────────────────────────────
    task load_matrices;
        begin
            for (i=0;i<N;i=i+1)
                for (j=0;j<N;j=j+1) begin
                    write_elem(0, i[1:0], j[1:0], A[i][j]);  // A
                    write_elem(1, i[1:0], j[1:0], B[i][j]);  // B
                end
        end
    endtask

    // ── Run compute and wait for done ─────────────────────────────────────
    task run_and_wait;
        begin
            // Start
            @(negedge clk); start=1;
            @(posedge clk); #1;
            @(negedge clk); start=0;

            // Wait for done with timeout
            wait_cyc=0;
            while (!done && wait_cyc < MAX_WAIT) begin
                @(posedge clk); #1;
                wait_cyc = wait_cyc + 1;
            end

            if (wait_cyc >= MAX_WAIT) begin
                $display("  [TIMEOUT] done never asserted!");
                fail_cnt = fail_cnt + N*N;
            end
        end
    endtask

    // ── Read back and check ───────────────────────────────────────────────
    task check_results;
        input [63:0] test_num;
        integer prev_fail;
        begin
            prev_fail = fail_cnt;

            for (i=0;i<N;i=i+1)
                for (j=0;j<N;j=j+1) begin
                    @(negedge clk);
                    rd_en=1; rd_row=i[1:0]; rd_col=j[1:0];
                    @(posedge clk); #1;     // Latch address
                    @(posedge clk); #1;     // rd_data registered output ready
                    rd_en=0;
                    hw_v = rd_data;
                    if (hw_v === C_gold[i][j])
                        pass_cnt=pass_cnt+1;
                    else begin
                        $display("  [FAIL] C[%0d][%0d]=%0d (exp %0d)",
                                 i,j,hw_v,C_gold[i][j]);
                        fail_cnt=fail_cnt+1;
                    end
                end

            if (fail_cnt==prev_fail)
                $display("  [PASS] Test %0d — all %0d elements correct!", test_num, N*N);
            else begin
                $display("  HW output:");
                for (i=0;i<N;i=i+1) begin
                    // Quick print — read each element again
                    $write("    [");
                    for (j=0;j<N;j=j+1) $write(" %5d", C_gold[i][j]);
                    $display(" ] (golden)");
                end
            end
        end
    endtask

    // ── Full test ──────────────────────────────────────────────────────────
    task run_test;
        input [63:0] test_num;
        begin
            load_matrices;
            run_and_wait;
            check_results(test_num);
        end
    endtask

    // ── VCD dump ──────────────────────────────────────────────────────────
    initial begin
        $dumpfile("C:/Users/user/.gemini/antigravity-ide/scratch/fpga-mini-npu/results/simulation_logs/tb_npu_top.vcd");
        $dumpvars(0, tb_npu_top);
    end

    // ── Test sequence ─────────────────────────────────────────────────────
    initial begin
        $display("\n============================================");
        $display("  NPU Top-Level End-to-End Testbench");
        $display("============================================");

        // Reset
        repeat(4) @(posedge clk); #1;
        rst_n=1;
        repeat(2) @(posedge clk); #1;

        // ── Test 1: A * I = A ─────────────────────────────────────────────
        $display("\n[Test 1] A * I = A");
        begin : t1 integer v; v=1;
            for (i=0;i<N;i=i+1) for (j=0;j<N;j=j+1) begin
                A[i][j]=v; v=v+1; B[i][j]=(i==j)?1:0; end
        end
        compute_golden; run_test(1);

        // ── Test 2: General multiply ──────────────────────────────────────
        $display("\n[Test 2] General multiply (exp C[0]=[17,16,17,16])");
        A[0][0]=1;A[0][1]=2;A[0][2]=3;A[0][3]=4;
        A[1][0]=2;A[1][1]=3;A[1][2]=4;A[1][3]=5;
        A[2][0]=3;A[2][1]=4;A[2][2]=5;A[2][3]=6;
        A[3][0]=4;A[3][1]=5;A[3][2]=6;A[3][3]=7;
        B[0][0]=1;B[0][1]=1;B[0][2]=1;B[0][3]=1;
        B[1][0]=1;B[1][1]=2;B[1][2]=1;B[1][3]=2;
        B[2][0]=2;B[2][1]=1;B[2][2]=2;B[2][3]=1;
        B[3][0]=2;B[3][1]=2;B[3][2]=2;B[3][3]=2;
        compute_golden; run_test(2);

        // ── Test 3: Negative values ───────────────────────────────────────
        $display("\n[Test 3] Negative values");
        A[0][0]=-1;A[0][1]=-2;A[0][2]= 3;A[0][3]= 4;
        A[1][0]= 5;A[1][1]=-3;A[1][2]=-4;A[1][3]= 2;
        A[2][0]=-6;A[2][1]= 7;A[2][2]= 1;A[2][3]=-5;
        A[3][0]= 8;A[3][1]= 0;A[3][2]=-2;A[3][3]= 3;
        B[0][0]= 2;B[0][1]=-1;B[0][2]= 0;B[0][3]= 3;
        B[1][0]=-3;B[1][1]= 4;B[1][2]= 1;B[1][3]=-2;
        B[2][0]= 5;B[2][1]= 0;B[2][2]=-2;B[2][3]= 1;
        B[3][0]=-1;B[3][1]= 2;B[3][2]= 3;B[3][3]= 0;
        compute_golden; run_test(3);

        // ── Test 4: Zero matrix ───────────────────────────────────────────
        $display("\n[Test 4] Zero * B = 0");
        begin : t4
            for (i=0;i<N;i=i+1) for (j=0;j<N;j=j+1) begin A[i][j]=0; B[i][j]=127; end
        end
        compute_golden; run_test(4);

        repeat(10) @(posedge clk);
        $display("\n============================================");
        $display("  RESULTS: %0d PASS / %0d FAIL", pass_cnt, fail_cnt);
        $display("============================================\n");
        $finish;
    end

endmodule
