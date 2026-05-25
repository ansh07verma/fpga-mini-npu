"""
generate_animation.py  (v2 — proper wavefront animation)

Animates the weight-stationary systolic array dataflow:
  - Weights stay INSIDE each PE (gold labels, stationary)
  - Activation "packets" (magenta circles) stream in from the left,
    staggered by row (row 1 delayed 1 cycle, row 2 delayed 2 cycles...)
  - Each PE lights up (cyan glow) while it is actively computing
  - Partial sums (green packets) drain downward from each column
  - The characteristic diagonal wavefront is clearly visible

Output: docs/assets/dataflow.gif
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import matplotlib.patheffects as pe_fx
from matplotlib.animation import FuncAnimation
import numpy as np
import os

N        = 4
TOTAL    = 14        # total animation cycles (0..13)
INTERVAL = 700       # ms per frame

# Grid layout
PE_W, PE_H = 1.4, 1.2
GAP_X, GAP_Y = 0.45, 0.40
GRID_X0, GRID_Y0 = 2.2, 1.8
PACK_R   = 0.18      # circle radius for data packets

# Compute PE centre positions
def pe_center(r, c):
    x = GRID_X0 + c * (PE_W + GAP_X) + PE_W / 2
    y = GRID_Y0 + (N-1-r) * (PE_H + GAP_Y) + PE_H / 2
    return x, y

fig, ax = plt.subplots(figsize=(11, 8))
fig.patch.set_facecolor('#0d1b2a')
ax.set_facecolor('#0d1b2a')
ax.set_xlim(0.2, 10.5)
ax.set_ylim(0.5, 9.2)
ax.set_aspect('equal')
ax.axis('off')

# ── static title & legend ─────────────────────────────────────────────────────
ax.text(5.4, 8.85,
        'Weight-Stationary Systolic Array — Wavefront Dataflow',
        ha='center', va='center', fontsize=13, fontweight='bold',
        color='#e0e0e0')
ax.text(5.4, 8.5,
        '4 × 4 INT8 PE grid  |  Activations → right  |  Partial sums ↓ down  |  Weights stationary',
        ha='center', va='center', fontsize=9, color='#888888')

legend_items = [
    (mpatches.Circle((0,0), 0.1, color='#cc33cc'), 'Activation packet (flows right)'),
    (mpatches.Circle((0,0), 0.1, color='#22bb55'), 'Partial sum (flows down)'),
    (mpatches.Rectangle((0,0), 0.3, 0.2, color='#1e5080', ec='#33aaff', lw=1.5), 'PE (idle)'),
    (mpatches.Rectangle((0,0), 0.3, 0.2, color='#0a3060', ec='#00eeff', lw=2.5), 'PE (computing)'),
]
ax.legend(handles=[h for h,_ in legend_items],
          labels=[t for _,t in legend_items],
          loc='upper right', fontsize=8.5,
          facecolor='#111e2e', edgecolor='#334455',
          labelcolor='#cccccc', framealpha=0.9)

# ── static PE boxes & weight labels ───────────────────────────────────────────
pe_boxes  = {}
pe_labels = {}
pe_weight_labels = {}

for r in range(N):
    for c in range(N):
        cx, cy = pe_center(r, c)
        px = cx - PE_W/2
        py = cy - PE_H/2
        box = mpatches.FancyBboxPatch((px, py), PE_W, PE_H,
            boxstyle='round,pad=0.06',
            facecolor='#1e5080', edgecolor='#33aaff',
            linewidth=1.8, zorder=2)
        ax.add_patch(box)
        pe_boxes[(r,c)] = box

        # PE label
        lbl = ax.text(cx, cy+0.22, f'PE({r},{c})',
                      ha='center', va='center', fontsize=8,
                      fontweight='bold', color='#88ccff', zorder=5)
        pe_labels[(r,c)] = lbl

        # Weight inside PE (gold, stationary)
        wt = ax.text(cx, cy-0.15, f'W[{r}][{c}] = w{r}{c}',
                     ha='center', va='center', fontsize=7.5,
                     color='#ffbb44', zorder=5)
        pe_weight_labels[(r,c)] = wt

# "y += a×w" label per PE (shown when active)
pe_mac_labels = {}
for r in range(N):
    for c in range(N):
        cx, cy = pe_center(r, c)
        mac = ax.text(cx, cy-0.38, 'y += a×w',
                      ha='center', va='center', fontsize=7,
                      color='#55eeff', zorder=5, alpha=0)
        pe_mac_labels[(r,c)] = mac

# ── static row input labels (left side) ───────────────────────────────────────
row_input_labels = {}
for r in range(N):
    _, cy = pe_center(r, 0)
    lbl = ax.text(0.8, cy, f'A[{r}][k]',
                  ha='center', va='center', fontsize=8.5,
                  color='#cc33cc', zorder=4)
    row_input_labels[r] = lbl
    ax.annotate('', xy=(GRID_X0-0.05, cy), xytext=(1.15, cy),
                arrowprops=dict(arrowstyle='->', color='#993399',
                               lw=1.5, mutation_scale=12), zorder=3)

# ── static column output labels (bottom) ─────────────────────────────────────
for c in range(N):
    cx, _ = pe_center(N-1, c)
    bot_y = GRID_Y0 - 0.55
    ax.annotate('', xy=(cx, bot_y), xytext=(cx, GRID_Y0-0.02),
                arrowprops=dict(arrowstyle='->', color='#22bb55',
                               lw=1.8, mutation_scale=13), zorder=3)
    ax.text(cx, bot_y-0.22, f'C[*][{c}]',
            ha='center', va='center', fontsize=8,
            color='#22bb55', zorder=4)

# ── inter-PE arrows (static, light) ───────────────────────────────────────────
for r in range(N):
    for c in range(N):
        cx, cy = pe_center(r, c)
        # rightward (activation) between columns
        if c < N-1:
            nx, _ = pe_center(r, c+1)
            ax.annotate('', xy=(nx - PE_W/2, cy),
                        xytext=(cx + PE_W/2, cy),
                        arrowprops=dict(arrowstyle='->', color='#663366',
                                       lw=1.2, mutation_scale=10), zorder=2)
        # downward (partial sum) between rows
        if r < N-1:
            _, ny = pe_center(r+1, c)
            ax.annotate('', xy=(cx, ny + PE_H/2),
                        xytext=(cx, cy - PE_H/2),
                        arrowprops=dict(arrowstyle='->', color='#1a6633',
                                       lw=1.2, mutation_scale=10), zorder=2)

# ── dynamic objects ───────────────────────────────────────────────────────────
# Activation packets — one per (row, column-position), moves right over time
act_circles = {}
for r in range(N):
    for c in range(-1, N):  # c=-1 means it's in the left input lane
        circ = plt.Circle((0,0), PACK_R, color='#cc33cc', zorder=6, alpha=0)
        ax.add_patch(circ)
        act_circles[(r,c)] = circ

# Partial sum packets — one per column
psum_circles = {}
for c in range(N):
    circ = plt.Circle((0,0), PACK_R, color='#22bb55', zorder=6, alpha=0)
    ax.add_patch(circ)
    psum_circles[c] = circ

# Cycle counter text
cycle_text = ax.text(5.4, 0.75, 'Cycle: 0',
                     ha='center', va='center', fontsize=13,
                     fontweight='bold', color='#ffffff', zorder=7)

# Phase label
phase_text = ax.text(5.4, 0.38, '',
                     ha='center', va='center', fontsize=10,
                     color='#aaaaaa', zorder=7)

PHASES = {
    range(0,1):   ('LOAD_W Phase', '#ffbb44'),
    range(1,5):   ('COMPUTE Phase — Wavefront Propagation', '#33ccff'),
    range(5,9):   ('DRAIN Phase', '#22bb55'),
    range(9,14):  ('DONE', '#888888'),
}

def get_phase(cycle):
    for r, (txt, col) in PHASES.items():
        if cycle in r:
            return txt, col
    return '', '#888888'

def update(frame):
    cycle = frame

    # Update cycle text
    cycle_text.set_text(f'Cycle: {cycle}')
    ptxt, pcol = get_phase(cycle)
    phase_text.set_text(ptxt)
    phase_text.set_color(pcol)

    # Determine which PEs are active this cycle
    # PE(r,c) is active at cycles r+c, r+c+1, r+c+2, r+c+3 (N cycles)
    # (wavefront: activation reaches PE(r,c) at cycle r+c)
    for r in range(N):
        for c in range(N):
            active_start = r + c
            is_active = (active_start <= cycle < active_start + N) and (cycle >= 1)

            if is_active:
                pe_boxes[(r,c)].set_facecolor('#0a3060')
                pe_boxes[(r,c)].set_edgecolor('#00eeff')
                pe_boxes[(r,c)].set_linewidth(3.0)
                pe_mac_labels[(r,c)].set_alpha(1.0)
            else:
                pe_boxes[(r,c)].set_facecolor('#1e5080')
                pe_boxes[(r,c)].set_edgecolor('#33aaff')
                pe_boxes[(r,c)].set_linewidth(1.8)
                pe_mac_labels[(r,c)].set_alpha(0)

    # Activation packets: show packet at PE(r, cycle-r) for cycle >= r
    for r in range(N):
        for c in range(-1, N):
            circ = act_circles[(r,c)]
            # Packet arrives at column c when cycle == r + c + 1
            # Show it entering (c=-1) one cycle before
            show_at_cycle = r + c + 1  # cycle when it's at column c
            if cycle == show_at_cycle and 0 <= c < N:
                cx, cy = pe_center(r, c)
                circ.set_center((cx - PE_W*0.1, cy))
                circ.set_alpha(0.92)
            elif cycle == r and c == -1:   # entering from left
                _, cy = pe_center(r, 0)
                circ.set_center((GRID_X0 - 0.25, cy))
                circ.set_alpha(0.85)
            else:
                circ.set_alpha(0)

    # Partial sum packets: show at bottom of each column when draining
    # Drain starts at cycle N + c (last row's last activation)
    for c in range(N):
        drain_cycle = N + c   # when result of column c exits
        circ = psum_circles[c]
        if drain_cycle <= cycle < drain_cycle + 2:
            cx, _ = pe_center(N-1, c)
            circ.set_center((cx, GRID_Y0 - 0.3))
            circ.set_alpha(0.92)
        else:
            circ.set_alpha(0)

    return list(act_circles.values()) + list(psum_circles.values()) + \
           [cycle_text, phase_text] + list(pe_boxes.values()) + \
           list(pe_mac_labels.values())

ani = FuncAnimation(fig, update, frames=TOTAL,
                    init_func=lambda: [],
                    blit=False, interval=INTERVAL)

os.makedirs('docs/assets', exist_ok=True)
out = 'docs/assets/dataflow.gif'
ani.save(out, writer='pillow', dpi=120)
print(f'Saved: {out}')
