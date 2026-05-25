# =============================================================================
# synth.tcl — Vivado Batch Synthesis Script
#
# Usage (from project root):
#   vivado -mode batch -source scripts/synth.tcl
#
# Synthesizes npu_top for Basys3 (XC7A35T) and reports:
#   - Timing summary
#   - Resource utilization
# =============================================================================

# ── Project settings ──────────────────────────────────────────────────────────
set PART       "xc7a35tcpg236-1"    ;# Basys3 FPGA part number
set TOP        "npu_top"
set RTL_DIR    "[file dirname [info script]]/../rtl"
set OUT_DIR    "[file dirname [info script]]/../results/utilization_reports"

# ── Create output directory ───────────────────────────────────────────────────
file mkdir $OUT_DIR

# ── Read RTL sources ──────────────────────────────────────────────────────────
puts "\n=== Reading RTL sources ==="
read_verilog [glob ${RTL_DIR}/*.v]

# ── Constraints (timing) ──────────────────────────────────────────────────────
set XDC "[file dirname [info script]]/../constraints/basys3.xdc"
if {[file exists $XDC]} {
    puts "Reading constraints: $XDC"
    read_xdc $XDC
}

# ── Synthesis ─────────────────────────────────────────────────────────────────
puts "\n=== Running synthesis for part: $PART ==="
synth_design -top $TOP -part $PART -flatten_hierarchy rebuilt

# ── Generate reports ──────────────────────────────────────────────────────────
puts "\n=== Generating reports ==="

report_timing_summary \
    -delay_type max \
    -check_timing_verbose \
    -max_paths 10 \
    -input_pins \
    -routable_nets \
    -file "${OUT_DIR}/timing_summary.rpt"

report_utilization \
    -file "${OUT_DIR}/utilization.rpt"

report_power \
    -file "${OUT_DIR}/power.rpt"

# ── Print quick summary to console ───────────────────────────────────────────
puts "\n=========================================="
puts "  Synthesis complete!"
puts "  Reports written to: $OUT_DIR"
puts "  - timing_summary.rpt"
puts "  - utilization.rpt"
puts "  - power.rpt"
puts "=========================================="

# ── Save checkpoint ───────────────────────────────────────────────────────────
write_checkpoint -force "${OUT_DIR}/post_synth.dcp"
puts "  Checkpoint: ${OUT_DIR}/post_synth.dcp"
