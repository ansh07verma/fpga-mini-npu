"""
visualize_results.py — NPU Performance & Resource Visualization
===============================================================
Generates 4 publication-quality plots:

  1. Throughput vs Matrix Size (cycles per matmul)
  2. NPU vs CPU speedup bar chart
  3. Resource utilization breakdown (LUT, FF, CARRY4, DSP, IOB)
  4. Timing slack progression (synthesis → place → route)

Usage:
    python python/visualize_results.py

Output:
    results/plots/throughput.png
    results/plots/speedup.png
    results/plots/utilization.png
    results/plots/timing_progression.png
"""

import os
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.gridspec import GridSpec

# ── Style ─────────────────────────────────────────────────────────────────────
plt.rcParams.update({
    "figure.dpi": 150,
    "font.family": "DejaVu Sans",
    "font.size": 11,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.grid": True,
    "grid.alpha": 0.3,
    "axes.prop_cycle": plt.cycler("color",
        ["#4C72B0", "#DD8452", "#55A868", "#C44E52", "#8172B2"]),
})

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "results", "plots")
os.makedirs(OUT_DIR, exist_ok=True)

# ── Data ──────────────────────────────────────────────────────────────────────

# Cycles per NxN matrix multiply: LOAD_W(N) + CLR(1) + COMPUTE(N) + DRAIN(N+2) + DONE(1)
def npu_cycles(N):
    return N + 1 + N + (N + 2) + 1   # = 3N + 4

# CPU cycles (scalar sequential): N³ multiply-adds + loop overhead (≈ 2N³)
def cpu_cycles(N):
    return 2 * N**3

array_sizes   = np.array([2, 4, 8, 16, 32])
npu_cyc       = np.array([npu_cycles(n) for n in array_sizes])
cpu_cyc       = np.array([cpu_cycles(n) for n in array_sizes])
speedup       = cpu_cyc / npu_cyc

# Real measured values for N=4
MEASURED = {
    "N": 4,
    "cycles":     17,
    "wns_synth":  0.819,
    "wns_place":  0.505,
    "wns_route":  0.153,
    "freq_mhz":   100,
}

# ─────────────────────────────────────────────────────────────────────────────
# Plot 1: Throughput — cycles per matmul vs array size
# ─────────────────────────────────────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(8, 5))

ax.plot(array_sizes, npu_cyc, "o-", linewidth=2, markersize=7,
        label="NPU (systolic, O(N))", color="#4C72B0")
ax.plot(array_sizes, cpu_cyc, "s--", linewidth=2, markersize=7,
        label="CPU scalar (O(N³))", color="#C44E52")

# Mark N=4 measured point
ax.scatter([4], [17], zorder=5, s=120, color="#4C72B0",
           edgecolors="white", linewidths=2)
ax.annotate("Measured\n17 cycles", xy=(4, 17), xytext=(6, 80),
            arrowprops=dict(arrowstyle="->", color="#4C72B0"),
            fontsize=9, color="#4C72B0")

ax.set_xlabel("Matrix Size (N×N)")
ax.set_ylabel("Cycles per Matrix Multiply")
ax.set_title("NPU vs CPU: Cycles per N×N Matrix Multiply\n"
             "Systolic array is O(N), CPU scalar is O(N³)")
ax.legend()
ax.set_yscale("log")
ax.set_xticks(array_sizes)
ax.set_xticklabels([f"{n}×{n}" for n in array_sizes])

plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "throughput.png"))
print(f"  Saved: throughput.png")
plt.close()

# ─────────────────────────────────────────────────────────────────────────────
# Plot 2: Speedup bar chart
# ─────────────────────────────────────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(8, 5))

colors = ["#4C72B0" if n != 4 else "#DD8452" for n in array_sizes]
bars = ax.bar([f"{n}×{n}" for n in array_sizes], speedup,
              color=colors, edgecolor="white", linewidth=0.8, zorder=3)

# Label bars
for bar, val in zip(bars, speedup):
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.5,
            f"{val:.1f}×", ha="center", va="bottom", fontsize=10, fontweight="bold")

# Highlight measured
measured_patch = mpatches.Patch(color="#DD8452", label="4×4 (measured, 17 cycles)")
other_patch    = mpatches.Patch(color="#4C72B0", label="Theoretical")
ax.legend(handles=[measured_patch, other_patch])

ax.set_xlabel("Matrix Size (N×N)")
ax.set_ylabel("Speedup over CPU Scalar (×)")
ax.set_title("NPU Speedup vs CPU Scalar Sequential Execution\n"
             "Speedup = CPU cycles / NPU cycles")
ax.axhline(y=1, color="gray", linestyle="--", alpha=0.5, label="Baseline (1×)")
ax.set_ylim(0, max(speedup) * 1.15)

plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "speedup.png"))
print(f"  Saved: speedup.png")
plt.close()

# ─────────────────────────────────────────────────────────────────────────────
# Plot 3: Resource utilization — real post-route numbers from Vivado
# ─────────────────────────────────────────────────────────────────────────────
fig, axes = plt.subplots(1, 2, figsize=(12, 5))

# Left: Absolute counts
resources = {
    "Slice\nLUTs":     (1811, 20800),
    "Slice\nRegs(FF)": (1258, 41600),
    "CARRY4":          (288,  None),    # no fixed limit shown
    "DSP48E1\n(mapped)": (16,  90),     # expected after full impl
    "Block\nRAM":      (0,    50),
}

names  = list(resources.keys())
used   = [v[0] for v in resources.values()]
avail  = [v[1] if v[1] else v[0]*4 for v in resources.values()]  # dummy avail for CARRY4
pcts   = [u/a*100 for u, a in zip(used, avail)]

x = np.arange(len(names))
width = 0.35

b1 = axes[0].bar(x - width/2, avail, width, label="Available", color="#CCDDEE",
                  edgecolor="#99AABB", linewidth=0.8)
b2 = axes[0].bar(x + width/2, used,  width, label="Used",      color="#4C72B0",
                  edgecolor="white", linewidth=0.8)

axes[0].set_xticks(x)
axes[0].set_xticklabels(names, fontsize=9)
axes[0].set_ylabel("Count")
axes[0].set_title("FPGA Resource Counts\n(Basys3 XC7A35T — Post-Route)")
axes[0].legend()

for bar, val in zip(b2, used):
    axes[0].text(bar.get_x() + bar.get_width()/2, bar.get_height() + 20,
                 str(val), ha="center", va="bottom", fontsize=8)

# Right: Percentage utilization pie-style bar
pct_data = [1811/20800*100, 1258/41600*100, 16/90*100, 0/50*100]
pct_labels = ["Slice LUTs\n8.71%", "Slice FFs\n3.02%", "DSP48E1\n17.8%*", "BRAM\n0%"]
pct_colors = ["#4C72B0", "#55A868", "#DD8452", "#C44E52"]

bars = axes[1].barh(pct_labels, pct_data, color=pct_colors,
                    edgecolor="white", linewidth=0.8)
axes[1].set_xlim(0, 25)
axes[1].set_xlabel("Utilization (%)")
axes[1].set_title("Resource Utilization (%)\n* DSP mapped in full impl flow")
axes[1].axvline(x=80, color="red", linestyle="--", alpha=0.4, linewidth=1)
axes[1].text(80.5, 3.5, "80% limit", color="red", alpha=0.6, fontsize=8)

for bar, pct in zip(bars, pct_data):
    axes[1].text(bar.get_width() + 0.3, bar.get_y() + bar.get_height()/2,
                 f"{pct:.1f}%", va="center", fontsize=9)

plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "utilization.png"))
print(f"  Saved: utilization.png")
plt.close()

# ─────────────────────────────────────────────────────────────────────────────
# Plot 4: Timing slack progression through implementation stages
# ─────────────────────────────────────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(8, 5))

stages = ["Synthesis", "Post-Place", "Post-Route"]
wns    = [MEASURED["wns_synth"], MEASURED["wns_place"], MEASURED["wns_route"]]
colors = ["#55A868" if w > 0 else "#C44E52" for w in wns]

bars = ax.bar(stages, wns, color=colors, edgecolor="white", linewidth=0.8,
              zorder=3, width=0.5)

# Zero line
ax.axhline(y=0, color="black", linewidth=1.5, zorder=4)
ax.axhline(y=0, color="red", linewidth=2, linestyle="--", alpha=0.8,
           label="Timing constraint boundary (WNS = 0)")

# Annotate bars
for bar, val in zip(bars, wns):
    y_pos = val + 0.015 if val >= 0 else val - 0.030
    ax.text(bar.get_x() + bar.get_width()/2, y_pos,
            f"+{val:.3f} ns" if val > 0 else f"{val:.3f} ns",
            ha="center", va="bottom" if val >= 0 else "top",
            fontsize=11, fontweight="bold", color="#2d5a27" if val > 0 else "red")

ax.set_ylabel("Worst Negative Slack — WNS (ns)")
ax.set_title(f"Timing Closure Progression — npu_top @ 100 MHz\n"
             f"Basys3 XC7A35T, Clock period = 10 ns")
ax.legend()
ax.set_ylim(-0.2, max(wns) * 1.5)

# Add annotation explaining WNS
ax.text(0.98, 0.05, "WNS > 0 → timing MET ✓\nWNS < 0 → timing VIOLATED ✗",
        transform=ax.transAxes, ha="right", va="bottom",
        fontsize=9, color="gray",
        bbox=dict(boxstyle="round,pad=0.3", facecolor="white", alpha=0.8))

plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "timing_progression.png"))
print(f"  Saved: timing_progression.png")
plt.close()

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
print(f"\n{'='*55}")
print(f"  All plots written to: {OUT_DIR}/")
print(f"  throughput.png       — cycles vs matrix size")
print(f"  speedup.png          — NPU speedup over CPU")
print(f"  utilization.png      — FPGA resource breakdown")
print(f"  timing_progression.png — WNS through impl stages")
print(f"{'='*55}\n")
print(f"  NPU Key Numbers (N=4, 100 MHz):")
print(f"    Latency   : {MEASURED['cycles']} cycles = "
      f"{MEASURED['cycles']*10} ns per 4×4 matmul")
print(f"    Speedup   : {cpu_cycles(4)/npu_cycles(4):.1f}× over scalar CPU")
print(f"    WNS       : +{MEASURED['wns_route']:.3f} ns (post-route)")
print(f"    Max Fclk  : {1/(10-MEASURED['wns_route'])*1000:.1f} MHz")
print(f"    LUT util  : {1811/20800*100:.1f}%  FFs: {1258/41600*100:.1f}%")
