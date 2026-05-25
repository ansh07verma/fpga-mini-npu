// =============================================================================
// Testbench: 4x4 Systolic Array — C = A * B (5 test cases)
//
// Protocol:
//   1. rst_n=0 x3 cycles, rst_n=1
//   2. load_w=1 for N cycles: w_row[c*8+:8] = B[i][c] at cycle i
//   3. clr=1, en=0 for 1 cycle (reset accumulators)
//   4. en=1, clr=0: a_rows[r*8+:8] = A[r][k] for k=0..N-1
//   5. drain N+2 more en cycles with a_rows=0
//   6. sample after 3 more idle cycles
// =============================================================================

`timescale 1ns / 1ps

module tb_systolic_4x4;

    localparam N  = 4;
    localparam DW = 8;
    localparam AW = 24;

    reg clk=0, rst_n=0, load_w=0, en=0, clr=0;
    reg [N*DW-1:0] w_row=0, a_rows=0;
    wire [N*N*AW-1:0] y_out;
    wire valid;

    systolic_array_4x4 #(.N(N),.DATA_WIDTH(DW),.ACC_WIDTH(AW)) dut (
        .clk(clk),.rst_n(rst_n),
        .load_w(load_w),.w_row(w_row),
        .en(en),.clr(clr),.a_rows(a_rows),
        .y_out(y_out),.valid(valid));

    always #5 clk = ~clk;

    // ── Module-level variables (shared by tasks) ───────────────────────────
    reg signed [DW-1:0] A [0:N-1][0:N-1];
    reg signed [DW-1:0] B [0:N-1][0:N-1];
    reg signed [AW-1:0] C_gold [0:N-1][0:N-1];
    reg signed [AW-1:0] hw_v;
    integer pass_cnt, fail_cnt, i, j, k;

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

    // ── Matrix multiply task ───────────────────────────────────────────────
    task run_matmul;
        input [63:0] test_num;
        integer rr, cc, prev_fail;
        begin
            prev_fail = fail_cnt;

            // Reset
            @(negedge clk); rst_n=0; en=0; load_w=0; clr=0; a_rows=0;
            repeat(3) @(posedge clk); #1;
            @(negedge clk); rst_n=1;
            repeat(2) @(posedge clk); #1;

            // Load weights: row i of B per cycle
            load_w=1;
            for (i=0;i<N;i=i+1) begin
                @(negedge clk);
                for (cc=0;cc<N;cc=cc+1)
                    w_row[cc*DW +: DW] = B[i][cc];
                @(posedge clk); #1;
            end
            @(negedge clk); load_w=0;
            repeat(2) @(posedge clk); #1;

            // Clear accumulators (clr=1, en=0)
            @(negedge clk); clr=1; en=0; a_rows=0;
            @(posedge clk); #1;
            @(negedge clk); clr=0;

            // Stream activations: present k=0 data AT SAME negedge as en=1
            // so the very first posedge captures en=1 AND A[:,0] simultaneously.
            @(negedge clk);
            en=1;
            for (rr=0;rr<N;rr=rr+1)
                a_rows[rr*DW +: DW] = A[rr][0];
            @(posedge clk); #1;
            for (k=1;k<N;k=k+1) begin
                @(negedge clk);
                for (rr=0;rr<N;rr=rr+1)
                    a_rows[rr*DW +: DW] = A[rr][k];
                @(posedge clk); #1;
            end

            // Drain
            @(negedge clk); a_rows=0;
            repeat(N+2) @(posedge clk); #1;
            en=0;
            repeat(3) @(posedge clk); #1;

            // Check
            for (i=0;i<N;i=i+1)
                for (j=0;j<N;j=j+1) begin
                    hw_v = $signed(y_out[(i*N+j)*AW +: AW]);
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
                $display("  HW:"); for (i=0;i<N;i=i+1) begin $write("   ["); for (j=0;j<N;j=j+1) $write(" %4d",$signed(y_out[(i*N+j)*AW +: AW])); $display(" ]"); end
                $display("  GD:"); for (i=0;i<N;i=i+1) begin $write("   ["); for (j=0;j<N;j=j+1) $write(" %4d",C_gold[i][j]); $display(" ]"); end
            end
        end
    endtask

    // ── VCD dump ──────────────────────────────────────────────────────────
    initial begin
        $dumpfile("C:/Users/user/.gemini/antigravity-ide/scratch/fpga-mini-npu/results/simulation_logs/tb_systolic_4x4.vcd");
        $dumpvars(0, tb_systolic_4x4);
    end

    // ── Test sequence ─────────────────────────────────────────────────────
    initial begin
        pass_cnt=0; fail_cnt=0;
        $display("\n========================================");
        $display("  4x4 Systolic Array Testbench");
        $display("========================================");

        // Test 1: A * I = A
        $display("\n[Test 1] A * I = A");
        begin : t1 integer v; v=1;
            for (i=0;i<N;i=i+1) for (j=0;j<N;j=j+1) begin
                A[i][j]=v; v=v+1; B[i][j]=(i==j)?1:0; end
        end
        compute_golden; run_matmul(1);

        // Test 2: General positive
        $display("\n[Test 2] General multiply (exp C[0]=[17,16,17,16])");
        A[0][0]=1;A[0][1]=2;A[0][2]=3;A[0][3]=4;
        A[1][0]=2;A[1][1]=3;A[1][2]=4;A[1][3]=5;
        A[2][0]=3;A[2][1]=4;A[2][2]=5;A[2][3]=6;
        A[3][0]=4;A[3][1]=5;A[3][2]=6;A[3][3]=7;
        B[0][0]=1;B[0][1]=1;B[0][2]=1;B[0][3]=1;
        B[1][0]=1;B[1][1]=2;B[1][2]=1;B[1][3]=2;
        B[2][0]=2;B[2][1]=1;B[2][2]=2;B[2][3]=1;
        B[3][0]=2;B[3][1]=2;B[3][2]=2;B[3][3]=2;
        compute_golden; run_matmul(2);

        // Test 3: Negative values
        $display("\n[Test 3] Negative values");
        A[0][0]=-1;A[0][1]=-2;A[0][2]= 3;A[0][3]= 4;
        A[1][0]= 5;A[1][1]=-3;A[1][2]=-4;A[1][3]= 2;
        A[2][0]=-6;A[2][1]= 7;A[2][2]= 1;A[2][3]=-5;
        A[3][0]= 8;A[3][1]= 0;A[3][2]=-2;A[3][3]= 3;
        B[0][0]= 2;B[0][1]=-1;B[0][2]= 0;B[0][3]= 3;
        B[1][0]=-3;B[1][1]= 4;B[1][2]= 1;B[1][3]=-2;
        B[2][0]= 5;B[2][1]= 0;B[2][2]=-2;B[2][3]= 1;
        B[3][0]=-1;B[3][1]= 2;B[3][2]= 3;B[3][3]= 0;
        compute_golden; run_matmul(3);

        // Test 4: Zero matrix
        $display("\n[Test 4] Zero * B = 0");
        begin : t4 for (i=0;i<N;i=i+1) for (j=0;j<N;j=j+1) begin A[i][j]=0; B[i][j]=127; end end
        compute_golden; run_matmul(4);

        // Test 5: Max INT8
        $display("\n[Test 5] Max INT8 * Max INT8 (exp each = 64516)");
        begin : t5 for (i=0;i<N;i=i+1) for (j=0;j<N;j=j+1) begin A[i][j]=127; B[i][j]=127; end end
        compute_golden; run_matmul(5);

        repeat(10) @(posedge clk);
        $display("\n========================================");
        $display("  RESULTS: %0d PASS / %0d FAIL", pass_cnt, fail_cnt);
        $display("========================================\n");
        $finish;
    end

endmodule
