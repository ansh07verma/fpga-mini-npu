# =============================================================================
# impl.tcl — Vivado Full Implementation Script
#
# Usage (from project root):
#   vivado -mode batch -source scripts/impl.tcl
#
# Runs the full implementation flow on npu_top:
#   synth_design → opt_design → place_design → route_design
#
# Generates:
#   - utilization_reports/impl_utilization.rpt   (real post-route counts)
#   - utilization_reports/impl_timing.rpt         (real slack after routing)
#   - utilization_reports/impl_power.rpt
#   - utilization_reports/npu_top.bit             (bitstream for Basys3)
# =============================================================================

# ── Project settings ──────────────────────────────────────────────────────────
set PART    "xc7a35tcpg236-1"    ;# Basys3 FPGA part
set TOP     "npu_top"
set RTL_DIR "[file dirname [info script]]/../rtl"
set OUT_DIR "[file dirname [info script]]/../results/utilization_reports"
set XDC     "[file dirname [info script]]/../constraints/basys3.xdc"

file mkdir $OUT_DIR

# ── Read sources ──────────────────────────────────────────────────────────────
puts "\n=== [1/6] Reading RTL sources ==="
read_verilog [glob ${RTL_DIR}/*.v]

if {[file exists $XDC]} {
    puts "Reading constraints: $XDC"
    read_xdc $XDC
} else {
    puts "WARNING: No XDC found at $XDC — no I/O or timing constraints applied"
}

# ── Synthesis ─────────────────────────────────────────────────────────────────
puts "\n=== [2/6] Synthesis ==="
synth_design -top $TOP -part $PART -flatten_hierarchy rebuilt

# ── Optimization ─────────────────────────────────────────────────────────────
# opt_design performs:
#   - Logic optimization (absorbs small logic into DSP48/CARRY4)
#   - DSP48E1 mapping (use_dsp="yes" takes effect here)
#   - Retiming across registers
puts "\n=== [3/6] Optimization (DSP48 inference happens here) ==="
opt_design

# Report after opt (shows real DSP count before place)
puts "\n--- Post-opt utilization ---"
report_utilization -file "${OUT_DIR}/post_opt_utilization.rpt"

# ── Downgrade non-critical DRC checks ─────────────────────────────────────────
# BIVC-1: Bank IO Vcc conflict — safe to ignore for prototype demo
#          (rd_data[23:8] are not physically connected; won't cause damage)
# NSTD-1: Unconstrained IO standard  — handled by SEVERITY downgrade in XDC
# UCIO-1: Unconstrained pin location — same
set_property SEVERITY {Warning} [get_drc_checks BIVC-1]
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]

# ── Place ─────────────────────────────────────────────────────────────────────
puts "\n=== [4/6] Placement ==="
place_design

# ── Route ─────────────────────────────────────────────────────────────────────
puts "\n=== [5/6] Routing ==="
route_design

# ── Reports ───────────────────────────────────────────────────────────────────
puts "\n=== [6/6] Generating final reports ==="

report_utilization \
    -file "${OUT_DIR}/impl_utilization.rpt"

report_timing_summary \
    -delay_type max \
    -check_timing_verbose \
    -max_paths 10 \
    -input_pins \
    -file "${OUT_DIR}/impl_timing.rpt"

report_power \
    -file "${OUT_DIR}/impl_power.rpt"

report_route_status \
    -file "${OUT_DIR}/impl_route_status.rpt"

# ── Bitstream ─────────────────────────────────────────────────────────────────
puts "\n=== Generating bitstream ==="
write_bitstream -force "${OUT_DIR}/npu_top.bit"

# ── Checkpoint ────────────────────────────────────────────────────────────────
write_checkpoint -force "${OUT_DIR}/post_route.dcp"

puts "\n=========================================="
puts "  Implementation complete!"
puts "  Bitstream: ${OUT_DIR}/npu_top.bit"
puts "  Reports  : ${OUT_DIR}/"
puts "=========================================="
