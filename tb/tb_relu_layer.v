// =============================================================================
// Testbench: ReLU Layer
// =============================================================================
`timescale 1ns / 1ps

module tb_relu_layer;

    localparam N  = 4;
    localparam AW = 24;

    reg  clk=0, rst_n=0, in_valid=0;
    reg  [N*N*AW-1:0] in_data=0;
    wire              out_valid;
    wire [N*N*AW-1:0] out_data;

    relu_layer #(.N(N),.ACC_WIDTH(AW)) dut(
        .clk(clk),.rst_n(rst_n),
        .in_valid(in_valid),.in_data(in_data),
        .out_valid(out_valid),.out_data(out_data));

    always #5 clk=~clk;

    integer pass_cnt=0, fail_cnt=0, i;

    task check;
        input signed [AW-1:0] got, exp;
        input [127:0] label;
        begin
            if (got===exp) pass_cnt=pass_cnt+1;
            else begin $display("  FAIL %s: got=%0d exp=%0d",label,got,exp); fail_cnt=fail_cnt+1; end
        end
    endtask

    initial begin
        repeat(3) @(posedge clk); #1; rst_n=1;
        repeat(2) @(posedge clk); #1;

        // Test 1: all positive → pass through unchanged
        @(negedge clk); in_valid=1;
        for (i=0;i<N*N;i=i+1)
            in_data[i*AW +: AW] = i+1;  // 1..16
        @(posedge clk); #1;
        @(negedge clk); in_valid=0;
        @(posedge clk); #1;

        $display("[Test 1] All positive → pass through");
        check($signed(out_data[0*AW +: AW]),24'sd1,"relu(1)");
        check($signed(out_data[15*AW +: AW]),24'sd16,"relu(16)");

        // Test 2: all negative → all zero
        @(negedge clk); in_valid=1;
        for (i=0;i<N*N;i=i+1)
            in_data[i*AW +: AW] = -i-1;  // -1..-16
        @(posedge clk); #1;
        @(negedge clk); in_valid=0;
        @(posedge clk); #1;

        $display("[Test 2] All negative → all zero");
        check($signed(out_data[0*AW +: AW]),24'sd0,"relu(-1)");
        check($signed(out_data[15*AW +: AW]),24'sd0,"relu(-16)");

        // Test 3: mixed — first 8 positive, last 8 negative
        @(negedge clk); in_valid=1;
        for (i=0;i<N*N;i=i+1)
            in_data[i*AW +: AW] = (i<8) ? (i+1) : -(i+1);
        @(posedge clk); #1;
        @(negedge clk); in_valid=0;
        @(posedge clk); #1;

        $display("[Test 3] Mixed values");
        check($signed(out_data[0*AW +: AW]),24'sd1,"relu(1)");
        check($signed(out_data[7*AW +: AW]),24'sd8,"relu(8)");
        check($signed(out_data[8*AW +: AW]),24'sd0,"relu(-9)");
        check($signed(out_data[15*AW +: AW]),24'sd0,"relu(-16)");

        // Test 4: zero → zero
        @(negedge clk); in_valid=1;
        in_data=0;
        @(posedge clk); #1;
        @(negedge clk); in_valid=0;
        @(posedge clk); #1;

        $display("[Test 4] Zero input");
        check($signed(out_data[0*AW +: AW]),24'sd0,"relu(0)");

        $display("\n=== RESULTS: %0d PASS / %0d FAIL ===\n",pass_cnt,fail_cnt);
        $finish;
    end

endmodule
