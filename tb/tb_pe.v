// =============================================================================
// Testbench: PE (Processing Element)
//
// Tests the weight-stationary PE in isolation (y_in = 0).
//
// Key pipeline behaviour (from mac_unit.v and pe.v):
//
//  mac_unit:  On posedge with en=1, clr=1: y_mac <= a*b       (load, not add)
//             On posedge with en=1, clr=0: y_mac <= y_mac + a*b (accumulate)
//             On posedge with en=0:        y_mac holds
//
//  pe psum:   On posedge with en=1, clr=1: psum_reg <= 0        (clear)
//             On posedge with en=1, clr=0: psum_reg <= y_mac + y_in
//             On posedge with en=0:        psum_reg holds
//             (note: psum uses mac_out = y_mac from SAME cycle = previous clk edge)
//
//  y_out = psum_reg
//
// Timing for single MAC:
//   CLK edge 1: en=1,clr=1,a=V,w=W  → y_mac=V*W  ; psum=0  (clear wins)
//   CLK edge 2: en=1,clr=0           → y_mac=y_mac; psum=V*W+0 = V*W
//   CLK edge 3: en=0                 → psum holds; y_out = V*W  ✓
//
// So: clr=1 on cycle 1 clears psum; y_mac gets V*W.
//     en=1,clr=0 on cycle 2 lets psum = y_mac = V*W.
//     After that, y_out = V*W.
// =============================================================================
`timescale 1ns / 1ps

module tb_pe;

    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH  = 24;

    reg  clk=0, rst_n=0;
    reg  load_w=0, en=0, clr=0;
    reg  signed [DATA_WIDTH-1:0] a_in=0, w_in=0;
    wire signed [DATA_WIDTH-1:0] a_out;
    wire signed [ACC_WIDTH-1:0]  y_out;

    // y_in = 0: isolated top-row PE, no partial sums from above
    pe #(.DATA_WIDTH(DATA_WIDTH),.ACC_WIDTH(ACC_WIDTH)) dut(
        .clk(clk),.rst_n(rst_n),
        .load_w(load_w),.w_in(w_in),
        .en(en),.clr(clr),
        .a_in(a_in),.a_out(a_out),
        .y_in({ACC_WIDTH{1'b0}}),
        .y_out(y_out));

    always #5 clk = ~clk;

    integer pass_cnt=0, fail_cnt=0;

    task check_y;
        input signed [ACC_WIDTH-1:0] got, exp;
        input [127:0] label;
        begin
            if ($signed(got) === $signed(exp)) pass_cnt = pass_cnt + 1;
            else begin
                $display("  [FAIL] %0s: got=%0d expected=%0d",label,$signed(got),$signed(exp));
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    initial begin
        // Reset
        repeat(3) @(posedge clk); #1; rst_n = 1;
        repeat(2) @(posedge clk); #1;

        // ── TC1: Single accumulate — w=3, a=5 → y=15 ────────────────────────
        // Edge 1: load_w=1
        // Edge 2: en=1,clr=1,a=5 → y_mac=15; psum=0 (clr wins)
        // Edge 3: en=1,clr=0     → psum=y_mac+0=15; y_mac still 15
        // Edge 4: en=0           → hold
        // y_out = 15 ✓
        $display("[TC1] w=3, a=5, expect y=15");
        @(negedge clk); load_w=1; w_in=3;
        @(posedge clk); #1;
        @(negedge clk); load_w=0; clr=1; en=1; a_in=5;  // Edge 2: clear, start mac
        @(posedge clk); #1;
        @(negedge clk); clr=0; en=1; a_in=0;             // Edge 3: psum = y_mac
        @(posedge clk); #1;
        @(negedge clk); en=0;                             // Edge 4: done
        @(posedge clk); #1;
        #1;
        check_y(y_out, 24'sd15, "TC1 y=5*3");

        // ── TC2: a_out passthrough (1 cycle) ─────────────────────────────────
        $display("[TC2] a_out passthrough: a_in=7, expect a_out=7 on next clk");
        @(negedge clk); en=1; clr=1; a_in=7;
        @(posedge clk); #1;
        // a_out is registered: available on this posedge
        if ($signed(a_out) === 8'sd7) pass_cnt = pass_cnt + 1;
        else begin
            $display("  [FAIL] TC2 a_out: got=%0d expected=7", $signed(a_out));
            fail_cnt = fail_cnt + 1;
        end
        @(negedge clk); en=0; clr=0; a_in=0;
        @(posedge clk); #1;

        // ── TC3: 2 accumulate cycles — w=2, a=3 → y=12 ──────────────────────
        // Edge 1: load_w=1
        // Edge 2: clr=1,en=1,a=3 → y_mac=6; psum=0
        // Edge 3: clr=0,en=1,a=3 → psum=6; y_mac=6+6=12
        // Edge 4: clr=0,en=1,a=0 → psum=12; y_mac=12+0=12
        // Edge 5: en=0           → hold; y_out=12
        $display("[TC3] 2x accumulate: w=2, a=3, expect y=12");
        @(negedge clk); load_w=1; w_in=2;
        @(posedge clk); #1;
        @(negedge clk); load_w=0; clr=1; en=1; a_in=3;  // Edge 2
        @(posedge clk); #1;
        @(negedge clk); clr=0; en=1; a_in=3;             // Edge 3
        @(posedge clk); #1;
        @(negedge clk); en=1; a_in=0;                    // Edge 4: capture into psum
        @(posedge clk); #1;
        @(negedge clk); en=0;
        @(posedge clk); #1;
        #1;
        check_y(y_out, 24'sd12, "TC3 y=2x3*2");

        // ── TC4: Negative weight w=-4, a=5 → y=-20 ────────────────────────────
        $display("[TC4] w=-4, a=5, expect y=-20");
        @(negedge clk); load_w=1; w_in=-4;
        @(posedge clk); #1;
        @(negedge clk); load_w=0; clr=1; en=1; a_in=5;
        @(posedge clk); #1;
        @(negedge clk); clr=0; en=1; a_in=0;
        @(posedge clk); #1;
        @(negedge clk); en=0;
        @(posedge clk); #1;
        #1;
        check_y(y_out, -24'sd20, "TC4 y=5*-4");

        // ── TC5: Hold — y must not change when en=0 ──────────────────────────
        $display("[TC5] Hold: en=0, y should stay -20");
        @(negedge clk); en=0; a_in=127;
        repeat(4) @(posedge clk); #1;
        check_y(y_out, -24'sd20, "TC5 hold");

        // ── TC6: CLR then fresh compute — w=7, a=7 → y=49 ────────────────────
        $display("[TC6] CLR+fresh: w=7, a=7, expect y=49");
        @(negedge clk); load_w=1; w_in=7;
        @(posedge clk); #1;
        @(negedge clk); load_w=0; clr=1; en=1; a_in=7;
        @(posedge clk); #1;
        @(negedge clk); clr=0; en=1; a_in=0;
        @(posedge clk); #1;
        @(negedge clk); en=0;
        @(posedge clk); #1;
        #1;
        check_y(y_out, 24'sd49, "TC6 y=7*7");

        $display("\n===== Results: %0d PASS / %0d FAIL =====\n", pass_cnt, fail_cnt);
        $finish;
    end

endmodule
