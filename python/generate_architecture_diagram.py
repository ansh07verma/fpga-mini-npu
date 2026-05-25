"""
generate_architecture_diagram.py
Renders a professional block diagram of the NPU as a matplotlib figure.
Shows: Controller FSM, Input Buffer, Weight Buffer, 4x4 PE Grid with
directional dataflow arrows (activations → right, partial sums ↓ down),
and Output Buffer.
Output: docs/assets/architecture_block.png
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import matplotlib.patheffects as pe
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import numpy as np

fig, ax = plt.subplots(figsize=(14, 10))
ax.set_xlim(0, 14)
ax.set_ylim(0, 10)
ax.axis('off')
fig.patch.set_facecolor('#0f1923')
ax.set_facecolor('#0f1923')

# ─── Helpers ──────────────────────────────────────────────────────────────────
def rounded_box(ax, x, y, w, h, color, alpha=1.0, lw=2, ec='white'):
    box = FancyBboxPatch((x, y), w, h,
                         boxstyle="round,pad=0.08",
                         facecolor=color, edgecolor=ec,
                         linewidth=lw, alpha=alpha, zorder=3)
    ax.add_patch(box)
    return box

def label(ax, x, y, text, fs=10, color='white', bold=False, ha='center', va='center'):
    weight = 'bold' if bold else 'normal'
    t = ax.text(x, y, text, fontsize=fs, color=color, ha=ha, va=va,
                fontweight=weight, zorder=5)
    return t

def arrow(ax, x0, y0, x1, y1, color='#aaaaaa', lw=1.8, label_text=None, label_off=(0,0)):
    ax.annotate('', xy=(x1, y1), xytext=(x0, y0),
                arrowprops=dict(arrowstyle='->', color=color,
                                lw=lw, mutation_scale=18),
                zorder=4)
    if label_text:
        mx, my = (x0+x1)/2 + label_off[0], (y0+y1)/2 + label_off[1]
        ax.text(mx, my, label_text, fontsize=8, color=color, ha='center',
                va='center', style='italic', zorder=5)

# ─── Title ────────────────────────────────────────────────────────────────────
label(ax, 7, 9.6, 'FPGA Mini NPU — Architecture Overview',
      fs=16, bold=True, color='#e0e0e0')
label(ax, 7, 9.25, 'Weight-Stationary 4×4 Systolic Array  |  INT8  |  Basys3 XC7A35T @ 100 MHz',
      fs=9.5, color='#888888')

# ─── External Interface box ───────────────────────────────────────────────────
rounded_box(ax, 0.2, 7.5, 2.4, 1.4, '#1a2a3a', ec='#446688', lw=1.5)
label(ax, 1.4, 8.5, 'External Interface', fs=9, bold=True, color='#6699cc')
label(ax, 1.4, 8.1, 'wr_en / wr_data', fs=8.5, color='#dddddd')
label(ax, 1.4, 7.75, 'start  |  rd_en', fs=8.5, color='#dddddd')

# ─── Controller FSM ───────────────────────────────────────────────────────────
rounded_box(ax, 0.2, 5.6, 2.4, 1.5, '#1e2d1e', ec='#44aa55', lw=2)
label(ax, 1.4, 6.85, 'Controller FSM', fs=9, bold=True, color='#55cc66')
label(ax, 1.4, 6.5,  'IDLE', fs=7.5, color='#aaaaaa')
label(ax, 1.4, 6.2,  '→ LOAD_W → CLR', fs=7.5, color='#aaaaaa')
label(ax, 1.4, 5.9,  '→ COMPUTE → DRAIN', fs=7.5, color='#aaaaaa')
label(ax, 1.4, 5.6,  '→ CAPTURE → DONE', fs=7.5, color='#aaaaaa')

# FSM control outputs
arrow(ax, 2.6, 6.35, 4.1, 6.35, color='#55cc66', label_text='load_w / en / clr', label_off=(0, 0.2))

# ─── Input Buffer (Matrix A) ──────────────────────────────────────────────────
rounded_box(ax, 0.2, 3.7, 2.4, 1.4, '#2a1a2a', ec='#aa44aa', lw=2)
label(ax, 1.4, 4.85, 'Input Buffer', fs=9, bold=True, color='#cc55cc')
label(ax, 1.4, 4.5,  'Matrix A', fs=8.5, color='#dddddd')
label(ax, 1.4, 4.2,  '[4 × INT8 regs]', fs=8, color='#aaaaaa')
label(ax, 1.4, 3.9,  'a_rows[31:0]', fs=8, color='#cc99cc')

# ─── Weight Buffer ────────────────────────────────────────────────────────────
rounded_box(ax, 4.1, 8.0, 5.8, 1.0, '#2a1a1a', ec='#aa6633', lw=2)
label(ax, 7.0, 8.7,  'Weight Buffer  —  Matrix B', fs=9, bold=True, color='#dd8844')
label(ax, 7.0, 8.25, 'wmem[4][4]  INT8 register file  (weight-stationary: loaded once, reused N times)',
      fs=8, color='#bbbbbb')

# ─── 4x4 PE Grid ─────────────────────────────────────────────────────────────
N = 4
pe_size = 1.08
pe_gap  = 0.12
grid_x0 = 4.2
grid_y0 = 3.55

pe_colors_base = '#163050'
pe_colors_active = '#1a4070'

# Grid background
rounded_box(ax, grid_x0 - 0.18, grid_y0 - 0.18,
            N*(pe_size + pe_gap) + 0.06, N*(pe_size + pe_gap) + 0.06,
            '#101820', ec='#336699', lw=2.5)
label(ax, grid_x0 + N*(pe_size+pe_gap)/2 - 0.1, grid_y0 + N*(pe_size+pe_gap) + 0.05,
      '4 × 4 Systolic Array', fs=10, bold=True, color='#5599cc')

for r in range(N):
    for c in range(N):
        px = grid_x0 + c * (pe_size + pe_gap)
        py = grid_y0 + (N-1-r) * (pe_size + pe_gap)

        rounded_box(ax, px, py, pe_size, pe_size, pe_colors_active, ec='#4488bb', lw=1.5)
        label(ax, px + pe_size*0.5, py + pe_size*0.65, f'PE({r},{c})', fs=7.5,
              bold=True, color='#aaccff')
        label(ax, px + pe_size*0.5, py + pe_size*0.38, f'W[{r}][{c}]', fs=7.5,
              color='#dd9944')
        label(ax, px + pe_size*0.5, py + pe_size*0.15, 'y += a×w', fs=6.5,
              color='#88bbff')

# Activation flow arrows (→) along each row — left side input
for r in range(N):
    py = grid_y0 + (N-1-r) * (pe_size + pe_gap) + pe_size*0.5
    ax.annotate('', xy=(grid_x0, py), xytext=(grid_x0 - 0.85, py),
                arrowprops=dict(arrowstyle='->', color='#cc44cc', lw=2,
                                mutation_scale=14), zorder=5)
    # inter-PE activation arrows
    for c in range(N-1):
        px0 = grid_x0 + c*(pe_size+pe_gap) + pe_size
        px1 = grid_x0 + (c+1)*(pe_size+pe_gap)
        ax.annotate('', xy=(px1, py), xytext=(px0, py),
                    arrowprops=dict(arrowstyle='->', color='#cc44cc',
                                   lw=1.5, mutation_scale=12), zorder=5)

# Partial sum flow arrows (↓) along each column — top inputs
for c in range(N):
    px = grid_x0 + c*(pe_size+pe_gap) + pe_size*0.5
    top_y = grid_y0 + N*(pe_size+pe_gap) - 0.02
    ax.annotate('', xy=(px, top_y - 0.0), xytext=(px, top_y + 0.5),
                arrowprops=dict(arrowstyle='->', color='#33aa55',
                               lw=1.8, mutation_scale=13), zorder=5)
    for r in range(N-1):
        py0 = grid_y0 + (N-1-r) * (pe_size+pe_gap)
        py1 = py0 - pe_gap
        ax.annotate('', xy=(px, py1), xytext=(px, py0),
                    arrowprops=dict(arrowstyle='->', color='#33aa55',
                                   lw=1.5, mutation_scale=11), zorder=5)

# Output arrows (↓) from bottom row
for c in range(N):
    px = grid_x0 + c*(pe_size+pe_gap) + pe_size*0.5
    py_bot = grid_y0
    ax.annotate('', xy=(px, py_bot - 0.5), xytext=(px, py_bot),
                arrowprops=dict(arrowstyle='->', color='#33cc66',
                               lw=2.0, mutation_scale=14), zorder=5)

# ─── Output Buffer ────────────────────────────────────────────────────────────
rounded_box(ax, 4.1, 2.5, 5.8, 0.9, '#1a2a1a', ec='#33aa55', lw=2)
label(ax, 7.0, 3.15, 'Output Buffer  —  Matrix C', fs=9, bold=True, color='#44cc66')
label(ax, 7.0, 2.75, 'out_buf[4][4]  24-bit signed accumulators  |  rd_data[23:0]', fs=8, color='#bbbbbb')

# ─── done / rd_data output ───────────────────────────────────────────────────
rounded_box(ax, 11.0, 2.5, 2.7, 0.9, '#1a2a3a', ec='#446688', lw=1.5)
label(ax, 12.35, 3.15, 'rd_data[23:0]', fs=8.5, bold=True, color='#6699cc')
label(ax, 12.35, 2.75, 'done', fs=8.5, color='#aaaaaa')
arrow(ax, 9.9, 2.95, 11.0, 2.95, color='#44cc66')

# ─── Weight buffer → PE grid ──────────────────────────────────────────────────
for c in range(N):
    px = grid_x0 + c*(pe_size+pe_gap) + pe_size*0.5
    arrow(ax, px, 9.0, px, grid_y0 + N*(pe_size+pe_gap) + 0.5,
          color='#dd8844', lw=1.5)

# ─── Input buffer → row inputs ────────────────────────────────────────────────
arrow(ax, 2.6, 4.35, grid_x0 - 0.85, 4.35, color='#cc44cc', lw=2,
      label_text='a_rows[31:0]', label_off=(0, 0.22))

# ─── Ext Interface → Buffers ─────────────────────────────────────────────────
arrow(ax, 1.4, 7.5, 1.4, 7.1, color='#6688aa')
arrow(ax, 2.6, 8.2, 4.1, 8.5, color='#888888', label_text='wr_data', label_off=(0, 0.18))

# ─── Legend ──────────────────────────────────────────────────────────────────
legend_x, legend_y = 11.2, 7.8
rounded_box(ax, legend_x - 0.1, legend_y - 1.5, 2.7, 2.0, '#111820', ec='#334455', lw=1.2, alpha=0.95)
label(ax, legend_x + 1.25, legend_y + 0.35, 'Data Flow Legend', fs=9, bold=True, color='#aaaaaa')
items = [
    ('#dd8844', 'Weights (stationary)'),
    ('#cc44cc', 'Activations (→ right)'),
    ('#33aa55', 'Partial sums (↓ down)'),
    ('#44cc66', 'Results out'),
]
for i, (color, text) in enumerate(items):
    y = legend_y + 0.0 - i * 0.38
    ax.plot([legend_x + 0.1, legend_x + 0.45], [y, y], color=color, lw=2.5, zorder=6)
    ax.annotate('', xy=(legend_x + 0.45, y), xytext=(legend_x + 0.35, y),
                arrowprops=dict(arrowstyle='->', color=color, lw=1.5, mutation_scale=10))
    label(ax, legend_x + 0.55, y, text, fs=8, color='#cccccc', ha='left')

plt.tight_layout(pad=0.2)
out = 'docs/assets/architecture_block.png'
plt.savefig(out, dpi=160, bbox_inches='tight', facecolor=fig.get_facecolor())
print(f'Saved: {out}')
