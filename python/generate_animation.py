"""
generate_animation.py  (v3 — black bg, light colors, legend inside frame)
"""
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch
from matplotlib.animation import FuncAnimation
import os

N        = 4
TOTAL    = 14
INTERVAL = 700
PE_W, PE_H = 1.38, 1.15
GAP_X, GAP_Y = 0.30, 0.28
GRID_X0, GRID_Y0 = 2.60, 1.80
PACK_R = 0.17

def pe_center(r, c):
    x = GRID_X0 + c*(PE_W+GAP_X) + PE_W/2
    y = GRID_Y0 + (N-1-r)*(PE_H+GAP_Y) + PE_H/2
    return x, y

fig, ax = plt.subplots(figsize=(12, 9))
fig.patch.set_facecolor('#000000')
ax.set_facecolor('#000000')
ax.set_xlim(0.2, 11.8)
ax.set_ylim(0.3, 9.4)
ax.set_aspect('equal')
ax.axis('off')

# ── Title ─────────────────────────────────────────────────────────────────────
ax.text(6.0, 9.15,
        'Weight-Stationary Systolic Array — Wavefront Dataflow',
        ha='center', fontsize=13, fontweight='bold', color='#ffffff')
ax.text(6.0, 8.77,
        '4×4 INT8 PE grid  |  Activations → right  |  Partial sums ↓ down  |  Weights stationary',
        ha='center', fontsize=9, color='#999999')

# ── Legend (right-middle — clear of the PE grid) ───────────────────────
LX, LY, LW, LH = 9.55, 3.70, 2.05, 2.38
leg_bg = FancyBboxPatch((LX, LY), LW, LH, boxstyle='round,pad=0.08',
                        facecolor='#111111', edgecolor='#555555', linewidth=1.3, zorder=6)
ax.add_patch(leg_bg)
ax.text(LX+LW/2, LY+LH-0.22, 'Legend',
        ha='center', fontsize=9.5, fontweight='bold', color='#eeeeee', zorder=7)

leg_items = [
    ('#ff55ff', 'Activation (→ right)'),
    ('#44ff88', 'Partial sum (↓ down)'),
    ('#1155bb', '#3399ff', 'PE idle'),
    ('#003366', '#00eeff', 'PE computing'),
]
# Draw colored patches for PEs and lines for packets
ax.add_patch(FancyBboxPatch((LX+0.18, LY+LH-0.70), 0.45, 0.28,
             boxstyle='round,pad=0.04', facecolor='#0a1e3a', edgecolor='#3399ff',
             linewidth=1.5, zorder=7))
ax.text(LX+0.75, LY+LH-0.56, 'PE (idle)',
        ha='left', fontsize=8.5, color='#eeeeee', va='center', zorder=7)

ax.add_patch(FancyBboxPatch((LX+0.18, LY+LH-1.10), 0.45, 0.28,
             boxstyle='round,pad=0.04', facecolor='#001430', edgecolor='#00eeff',
             linewidth=2.5, zorder=7))
ax.text(LX+0.75, LY+LH-0.96, 'PE (computing)',
        ha='left', fontsize=8.5, color='#eeeeee', va='center', zorder=7)

for i, (color, label) in enumerate([('#ff55ff', 'Activation packet'), ('#44ff88', 'Partial sum')]):
    y = LY+LH - 1.50 - i*0.42
    c = plt.Circle((LX+0.40, y), 0.14, color=color, zorder=7)
    ax.add_patch(c)
    ax.text(LX+0.75, y, label, ha='left', fontsize=8.5, color='#eeeeee', va='center', zorder=7)

# ── Static PE boxes ───────────────────────────────────────────────────────────
pe_boxes  = {}
pe_wt_lbl = {}
pe_mac_lbl = {}
pe_lbl    = {}

for r in range(N):
    for c in range(N):
        cx, cy = pe_center(r, c)
        px, py = cx - PE_W/2, cy - PE_H/2
        b = FancyBboxPatch((px, py), PE_W, PE_H,
                           boxstyle='round,pad=0.07',
                           facecolor='#0a1e3a', edgecolor='#3399ff',
                           linewidth=1.8, zorder=2)
        ax.add_patch(b)
        pe_boxes[(r,c)] = b
        pe_lbl[(r,c)] = ax.text(cx, cy+0.25, f'PE({r},{c})',
                                 ha='center', fontsize=8.5, fontweight='bold',
                                 color='#aaddff', zorder=5)
        pe_wt_lbl[(r,c)] = ax.text(cx, cy-0.10, f'W[{r}][{c}]',
                                    ha='center', fontsize=8, color='#ffcc44', zorder=5)
        pe_mac_lbl[(r,c)] = ax.text(cx, cy-0.34, 'y += a×w',
                                     ha='center', fontsize=7, color='#55eeff',
                                     zorder=5, alpha=0)

# ── Static inter-PE arrows (dim, background) ──────────────────────────────────
for r in range(N):
    for c in range(N-1):
        x0 = GRID_X0 + c*(PE_W+GAP_X) + PE_W
        x1 = GRID_X0 + (c+1)*(PE_W+GAP_X)
        cy = pe_center(r,0)[1]
        ax.annotate('', xy=(x1, pe_center(r,c+1)[1]),
                    xytext=(x0, pe_center(r,c)[1]),
                    arrowprops=dict(arrowstyle='->', color='#553355', lw=1.1, mutation_scale=9), zorder=2)
for r in range(N-1):
    for c in range(N):
        cx, cy0 = pe_center(r,c)
        _,  cy1 = pe_center(r+1,c)
        ax.annotate('', xy=(cx, cy1+PE_H/2),
                    xytext=(cx, cy0-PE_H/2),
                    arrowprops=dict(arrowstyle='->', color='#1a4422', lw=1.1, mutation_scale=9), zorder=2)

# ── Static row entry arrows (left side) ───────────────────────────────────────
for r in range(N):
    cx, cy = pe_center(r,0)
    ax.annotate('', xy=(cx-PE_W/2, cy), xytext=(cx-PE_W/2-0.70, cy),
                arrowprops=dict(arrowstyle='->', color='#aa33aa', lw=1.5, mutation_scale=12), zorder=3)
    ax.text(cx-PE_W/2-0.85, cy, f'A[{r}][k]',
            ha='center', fontsize=8.5, color='#dd66dd', zorder=4)

# ── Static column output arrows (bottom) ──────────────────────────────────────
for c in range(N):
    cx, cy_bot = pe_center(N-1, c)
    ax.annotate('', xy=(cx, cy_bot-PE_H/2-0.48), xytext=(cx, cy_bot-PE_H/2),
                arrowprops=dict(arrowstyle='->', color='#22aa44', lw=1.8, mutation_scale=13), zorder=3)
    ax.text(cx, cy_bot-PE_H/2-0.68, f'C[*][{c}]',
            ha='center', fontsize=8, color='#33dd55', zorder=4)

# ── Dynamic objects ───────────────────────────────────────────────────────────
act_circles  = {}
for r in range(N):
    for c in range(N):
        circ = plt.Circle((0,0), PACK_R, color='#ff55ff', zorder=6, alpha=0)
        ax.add_patch(circ)
        act_circles[(r,c)] = circ

psum_circles = {}
for c in range(N):
    circ = plt.Circle((0,0), PACK_R, color='#44ff88', zorder=6, alpha=0)
    ax.add_patch(circ)
    psum_circles[c] = circ

cycle_text = ax.text(6.0, 0.72, 'Cycle: 0',
                     ha='center', fontsize=14, fontweight='bold', color='#ffffff', zorder=7)
phase_text = ax.text(6.0, 0.38, '',
                     ha='center', fontsize=10, color='#aaaaaa', zorder=7)

PHASES = [(range(0,1),'LOAD_W Phase','#ffcc33'),
          (range(1,5),'COMPUTE — Wavefront Propagation','#55ddff'),
          (range(5,9),'DRAIN Phase','#44ff88'),
          (range(9,14),'DONE','#888888')]

def get_phase(cyc):
    for rng, txt_, col in PHASES:
        if cyc in rng: return txt_, col
    return '', '#888888'

def update(frame):
    cyc = frame
    cycle_text.set_text(f'Cycle: {cyc}')
    pt, pc = get_phase(cyc)
    phase_text.set_text(pt); phase_text.set_color(pc)

    for r in range(N):
        for c in range(N):
            active = (r+c <= cyc < r+c+N) and cyc >= 1
            if active:
                pe_boxes[(r,c)].set_facecolor('#001430')
                pe_boxes[(r,c)].set_edgecolor('#00eeff')
                pe_boxes[(r,c)].set_linewidth(3.0)
                pe_mac_lbl[(r,c)].set_alpha(1.0)
            else:
                pe_boxes[(r,c)].set_facecolor('#0a1e3a')
                pe_boxes[(r,c)].set_edgecolor('#3399ff')
                pe_boxes[(r,c)].set_linewidth(1.8)
                pe_mac_lbl[(r,c)].set_alpha(0)

    for r in range(N):
        for c in range(N):
            circ = act_circles[(r,c)]
            show_at = r + c + 1
            if cyc == show_at:
                cx, cy = pe_center(r, c)
                circ.set_center((cx, cy)); circ.set_alpha(0.95)
            else:
                circ.set_alpha(0)

    for c in range(N):
        drain = N + c
        circ = psum_circles[c]
        if drain <= cyc < drain+2:
            cx, _ = pe_center(N-1, c)
            _, cy = pe_center(N-1, c)
            circ.set_center((cx, cy-PE_H/2-0.24)); circ.set_alpha(0.95)
        else:
            circ.set_alpha(0)

    return []

ani = FuncAnimation(fig, update, frames=TOTAL, init_func=lambda: [],
                    blit=False, interval=INTERVAL)

os.makedirs('docs/assets', exist_ok=True)
out = 'docs/assets/dataflow_v2.gif'
ani.save(out, writer='pillow', dpi=120)
print(f'Saved: {out}')
