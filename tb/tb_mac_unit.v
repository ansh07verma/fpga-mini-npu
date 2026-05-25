// =============================================================================
// Testbench: MAC Unit
// =============================================================================

`timescale 1ns / 1ps

module tb_mac_unit;

    // ── DUT ports ─────────────────────────────────────────────────────────
    reg        clk, rst_n, clr, en;
    reg  signed [7:0]  a, b;
    wire signed [23:0] y;

    // ── DUT instantiation ─────────────────────────────────────────────────
    mac_unit #(.DATA_WIDTH(8), .ACC_WIDTH(24)) dut (
        .clk(clk), .rst_n(rst_n), .clr(clr), .en(en),
        .a(a), .b(b), .y(y)
    );

    // ── Clock: 10ns period (100 MHz) ─────────────────────────────────────
    initial clk = 0;
    always #5 clk = ~clk;

    // ── Task: apply one MAC operation ─────────────────────────────────────
    task apply_mac;
        input signed [7:0] ta, tb;
        input              do_clr;
        begin
            @(negedge clk);
            a = ta; b = tb; clr = do_clr; en = 1;
            @(posedge clk); #1;
            en = 0;
        end
    endtask

    // ── Task: check output ────────────────────────────────────────────────
    // MAC is single-stage: y updates at the posedge where en=1.
    // apply_mac already waited through that posedge, so y is ready now.
    integer pass_count, fail_count;
    task check;
        input signed [23:0] expected;
        input [127:0]        test_name;
        begin
            // y was registered at the posedge inside apply_mac.
            // Just sample it now (apply_mac left us just after that posedge+1).
            if (y === expected) begin
                $display("[PASS] %s  y=%0d (expected %0d)", test_name, y, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %s  y=%0d (expected %0d)", test_name, y, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ── Dump waveforms ────────────────────────────────────────────────────
    initial begin
        $dumpfile("C:/Users/user/.gemini/antigravity-ide/scratch/fpga-mini-npu/results/simulation_logs/tb_mac_unit.vcd");
        $dumpvars(0, tb_mac_unit);
    end

    // ── Test sequence ─────────────────────────────────────────────────────
    initial begin
        pass_count = 0; fail_count = 0;
        rst_n = 0; clr = 0; en = 0; a = 0; b = 0;
        repeat(3) @(posedge clk);
        rst_n = 1;

        $display("\n===== MAC Unit Testbench =====");

        // TC1: Basic multiply-accumulate  y = 3*4 = 12
        apply_mac(8'sd3, 8'sd4, 1);
        check(24'sd12, "TC1 3*4=12");

        // TC2: Accumulate again  y = 12 + 2*5 = 22
        apply_mac(8'sd2, 8'sd5, 0);
        check(24'sd22, "TC2 acc 2*5");

        // TC3: Negative operand  y = 22 + (-3)*4 = 10
        apply_mac(-8'sd3, 8'sd4, 0);
        check(24'sd10, "TC3 neg*pos");

        // TC4: Both negative  y = 10 + (-2)*(-6) = 22
        apply_mac(-8'sd2, -8'sd6, 0);
        check(24'sd22, "TC4 neg*neg");

        // TC5: Clear then new product  y = 7*7 = 49
        apply_mac(8'sd7, 8'sd7, 1);
        check(24'sd49, "TC5 clr then 7*7");

        // TC6: Zero input
        apply_mac(8'sd0, 8'sd127, 1);
        check(24'sd0, "TC6 zero*max");

        // TC7: Max INT8 * Max INT8 = 127*127 = 16129
        apply_mac(8'sd127, 8'sd127, 1);
        check(24'sd16129, "TC7 max*max");

        // TC8: Min INT8 * Min INT8 = (-128)*(-128) = 16384
        apply_mac(-8'sd128, -8'sd128, 1);
        check(24'sd16384, "TC8 min*min");

        // TC9: Chain: 1+2+3+4+5 dot 1+1+1+1+1 = 15
        apply_mac(8'sd1, 8'sd1, 1);
        apply_mac(8'sd2, 8'sd1, 0);
        apply_mac(8'sd3, 8'sd1, 0);
        apply_mac(8'sd4, 8'sd1, 0);
        apply_mac(8'sd5, 8'sd1, 0);
        repeat(3) @(posedge clk);
        if (y === 24'sd15) begin
            $display("[PASS] TC9 chain dot=15  y=%0d", y);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] TC9 chain dot=15  y=%0d", y);
            fail_count = fail_count + 1;
        end

        repeat(5) @(posedge clk);
        $display("\n===== Results: %0d PASS / %0d FAIL =====\n", pass_count, fail_count);
        $finish;
    end

endmodule
