# =============================================================================
# synth_2x2.tcl — Batch synthesis for isolated 2×2 systolic array
# Usage: vivado -mode batch -source scripts/synth_2x2.tcl
# =============================================================================

set root [file dirname [file dirname [info script]]]
set rtl  "$root/rtl"
set out  "$root/results/utilization_reports"

create_project -force synth_2x2_proj [file join $root results synth_2x2_proj] -part xc7a35tcpg236-1

# Add only the files needed for the 2x2 array
add_files [list \
    "$rtl/mac_unit.v" \
    "$rtl/pe.v" \
    "$rtl/systolic_array_2x2.v" \
]

set_property top systolic_array_2x2 [current_fileset]

# Synthesize
synth_design -top systolic_array_2x2 -part xc7a35tcpg236-1

# Report
report_utilization -file "$out/utilization_2x2.rpt"

puts "\n=== 2x2 Synthesis complete. Report: $out/utilization_2x2.rpt ===\n"

close_project
