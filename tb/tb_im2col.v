// =============================================================================
// Testbench: im2col Pre-Processor
// =============================================================================
`timescale 1ns / 1ps

module tb_im2col;

    localparam IW = 6;
    localparam K  = 2;
    localparam DW = 8;

    reg  clk=0, rst_n=0;
    reg  wr_en=0;
    reg  [$clog2(IW)-1:0] wr_addr=0;
    reg  signed [DW-1:0]  wr_data=0;
    reg  start=0;
    wire valid, done;
    wire [K*DW-1:0] col_out;

    im2col #(.IW(IW),.K(K),.DW(DW),.STRIDE(1)) dut(
        .clk(clk),.rst_n(rst_n),
        .wr_en(wr_en),.wr_addr(wr_addr),.wr_data(wr_data),
        .start(start),.valid(valid),.done(done),.col_out(col_out));

    always #5 clk=~clk;

    // Input: [10, 20, 30, 40, 50, 60]
    // K=2, stride=1 → 5 patches:
    //   col[0]=[10,20], col[1]=[20,30], col[2]=[30,40], col[3]=[40,50], col[4]=[50,60]
    localparam N_PATCHES = IW - K + 1;  // 5
    integer pass_cnt=0, fail_cnt=0;

    reg [DW-1:0] expected [0:N_PATCHES-1][0:K-1];
    integer p, k, pos;

    initial begin
        // Build expected output
        for (p=0;p<N_PATCHES;p=p+1)
            for (k=0;k<K;k=k+1)
                expected[p][k] = (p + k + 1) * 10;  // 10, 20, 30 etc.

        repeat(3) @(posedge clk); #1; rst_n=1;
        repeat(2) @(posedge clk); #1;

        // Load input buffer: [10, 20, 30, 40, 50, 60]
        $display("Loading input: [10, 20, 30, 40, 50, 60]");
        for (p=0; p<IW; p=p+1) begin
            @(negedge clk);
            wr_en=1; wr_addr=p[2:0]; wr_data=(p+1)*10;
            @(posedge clk); #1;
        end
        @(negedge clk); wr_en=0;
        repeat(2) @(posedge clk); #1;

        // Start extraction
        $display("Starting im2col extraction...");
        @(negedge clk); start=1;
        @(posedge clk); #1;
        @(negedge clk); start=0;

        // Collect output patches
        pos = 0;
        while (!done) begin
            @(posedge clk); #1;
            if (valid) begin
                $display("  patch[%0d]: [%0d, %0d]  exp=[%0d, %0d]",
                    pos,
                    $signed(col_out[0*DW +: DW]),
                    $signed(col_out[1*DW +: DW]),
                    expected[pos][0],
                    expected[pos][1]);
                if (col_out[0*DW +: DW] === expected[pos][0] &&
                    col_out[1*DW +: DW] === expected[pos][1])
                    pass_cnt = pass_cnt + 1;
                else begin
                    $display("  FAIL at patch %0d", pos);
                    fail_cnt = fail_cnt + 1;
                end
                pos = pos + 1;
            end
        end

        // Verify we got all patches
        if (pos !== N_PATCHES) begin
            $display("FAIL: got %0d patches, expected %0d", pos, N_PATCHES);
            fail_cnt = fail_cnt + 1;
        end

        repeat(5) @(posedge clk);
        $display("\n=== RESULTS: %0d PASS / %0d FAIL ===\n", pass_cnt, fail_cnt);
        $finish;
    end

endmodule
