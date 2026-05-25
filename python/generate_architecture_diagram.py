"""
generate_architecture_diagram.py  (v4 — black bg, light colors, fixed legend)
"""
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
import numpy as np

fig, ax = plt.subplots(figsize=(17, 11))
ax.set_xlim(0, 17)
ax.set_ylim(0, 11)
ax.axis('off')
fig.patch.set_facecolor('#000000')
ax.set_facecolor('#000000')

def box(x, y, w, h, fc, ec, lw=2.0, zorder=2):
    p = FancyBboxPatch((x, y), w, h, boxstyle='round,pad=0.1',
                       facecolor=fc, edgecolor=ec, linewidth=lw, zorder=zorder)
    ax.add_patch(p)

def txt(x, y, s, fs=9, color='white', bold=False, ha='center', va='center', zorder=5):
    ax.text(x, y, s, fontsize=fs, color=color,
            fontweight='bold' if bold else 'normal',
            ha=ha, va=va, zorder=zorder)

def arr(x0, y0, x1, y1, color, lw=2.0, ms=16, zorder=4):
    ax.annotate('', xy=(x1, y1), xytext=(x0, y0),
                arrowprops=dict(arrowstyle='->', color=color, lw=lw, mutation_scale=ms),
                zorder=zorder)

# ── Title ─────────────────────────────────────────────────────────────────────
txt(8.5, 10.65, 'FPGA Mini NPU — Architecture Overview', fs=17, bold=True, color='#ffffff')
txt(8.5, 10.28, 'Weight-Stationary 4×4 Systolic Array  |  INT8  |  Basys3 XC7A35T @ 100 MHz',
    fs=9.5, color='#aaaaaa')

# ── Grid geometry ─────────────────────────────────────────────────────────────
N = 4
PE_W, PE_H = 1.35, 1.12
GAP_X, GAP_Y = 0.28, 0.26
GX0, GY0 = 4.90, 2.70

def pe_rect(r, c):
    return GX0 + c*(PE_W+GAP_X), GY0 + (N-1-r)*(PE_H+GAP_Y)

def pe_cx(r, c): return pe_rect(r,c)[0] + PE_W/2
def pe_cy(r, c): return pe_rect(r,c)[1] + PE_H/2

grid_right  = GX0 + N*PE_W + (N-1)*GAP_X
grid_top    = GY0 + N*PE_H + (N-1)*GAP_Y
grid_width  = grid_right - GX0
grid_height = grid_top   - GY0
grid_cx     = GX0 + grid_width/2

# ── Weight Buffer ─────────────────────────────────────────────────────────────
WB_H, WB_GAP = 0.78, 0.38
WB_Y = grid_top + WB_GAP

box(GX0, WB_Y, grid_width, WB_H, '#1a0d00', '#ff9922', lw=2.2)
txt(grid_cx, WB_Y+WB_H*0.68, 'Weight Buffer  —  Matrix B', fs=10, bold=True, color='#ffaa44')
txt(grid_cx, WB_Y+WB_H*0.25,
    'wmem[4][4]   INT8 register file   (weight-stationary: loaded once, reused N times)',
    fs=8, color='#dddddd')

for c in range(N):
    cx = pe_cx(0, c)
    arr(cx, WB_Y, cx, grid_top+0.04, color='#ff9922', lw=2.0, ms=14)

# ── Grid background ───────────────────────────────────────────────────────────
PAD = 0.22
box(GX0-PAD, GY0-PAD, grid_width+2*PAD, grid_height+2*PAD, '#080808', '#4488cc', lw=2.5)
txt(grid_cx, GY0-PAD-0.26, '4 × 4 Systolic Array', fs=10, bold=True, color='#66aaff')

# ── PE cells ──────────────────────────────────────────────────────────────────
for r in range(N):
    for c in range(N):
        px, py = pe_rect(r, c)
        box(px, py, PE_W, PE_H, '#0a1a2e', '#55aaee', lw=1.8)
        cx = px+PE_W/2
        txt(cx, py+PE_H*0.75, f'PE({r},{c})', fs=8.5, bold=True, color='#aaddff')
        txt(cx, py+PE_H*0.46, f'W[{r}][{c}]',  fs=8.0, color='#ffcc55')
        txt(cx, py+PE_H*0.18, 'y += a×w',      fs=7.0, color='#77ddee')

# Inter-PE arrows
for r in range(N):
    for c in range(N-1):
        x0 = pe_rect(r,c)[0]+PE_W; x1 = pe_rect(r,c+1)[0]
        arr(x0, pe_cy(r,c), x1, pe_cy(r,c), color='#ff55ff', lw=1.5, ms=11)
for r in range(N-1):
    for c in range(N):
        y0 = pe_rect(r,c)[1]; y1 = pe_rect(r+1,c)[1]+PE_H
        arr(pe_cx(r,c), y0, pe_cx(r,c), y1, color='#33ee66', lw=1.5, ms=11)

# ── Left-side row entry arrows ────────────────────────────────────────────────
ENTRY_X = GX0 - 1.05
for r in range(N):
    cy = pe_cy(r,0)
    arr(ENTRY_X, cy, pe_rect(r,0)[0]-0.04, cy, color='#ff55ff', lw=2.2, ms=15)

# ── Output arrows ─────────────────────────────────────────────────────────────
OB_ENTRY_Y = GY0 - PAD - 0.04
for c in range(N):
    arr(pe_cx(N-1,c), GY0, pe_cx(N-1,c), OB_ENTRY_Y-0.38, color='#44ff77', lw=2.2, ms=15)

# ── Output Buffer ─────────────────────────────────────────────────────────────
OB_H = 0.78
OB_Y = OB_ENTRY_Y - 0.38 - OB_H
box(GX0, OB_Y, grid_width, OB_H, '#001a08', '#33dd55', lw=2.2)
txt(grid_cx, OB_Y+OB_H*0.68, 'Output Buffer  —  Matrix C', fs=10, bold=True, color='#55ff88')
txt(grid_cx, OB_Y+OB_H*0.25,
    'out_buf[4][4]   24-bit signed accumulators   |   rd_data[23:0]', fs=8, color='#dddddd')

# rd_data box
RD_X = GX0+grid_width+0.55; RD_Y = OB_Y; RD_W = 2.10; RD_H = OB_H
box(RD_X, RD_Y, RD_W, RD_H, '#050f1a', '#5577cc', lw=1.8)
txt(RD_X+RD_W/2, RD_Y+RD_H*0.68, 'rd_data[23:0]', fs=9, bold=True, color='#88aaff')
txt(RD_X+RD_W/2, RD_Y+RD_H*0.25, 'done ✓',        fs=9, color='#cccccc')
arr(GX0+grid_width, OB_Y+OB_H/2, RD_X, RD_Y+RD_H/2, color='#44ff77', lw=2.0, ms=14)

# ── Left Panel ────────────────────────────────────────────────────────────────
PX, PW = 0.30, 2.80

# External Interface
EXT_Y, EXT_H = 8.50, 1.30
box(PX, EXT_Y, PW, EXT_H, '#000d1a', '#5588bb', lw=1.8)
txt(PX+PW/2, EXT_Y+EXT_H*0.72, 'External Interface', fs=9.5, bold=True, color='#88bbdd')
txt(PX+PW/2, EXT_Y+EXT_H*0.40, 'wr_en / wr_data',   fs=8.5, color='#eeeeee')
txt(PX+PW/2, EXT_Y+EXT_H*0.15, 'start  |  rd_en',   fs=8.5, color='#eeeeee')

# Controller FSM
FSM_Y, FSM_H = 6.70, 1.50
arr(PX+PW/2, EXT_Y, PX+PW/2, FSM_Y+FSM_H, color='#888888', lw=1.5, ms=11)
box(PX, FSM_Y, PW, FSM_H, '#001200', '#44cc55', lw=2.0)
txt(PX+PW/2, FSM_Y+FSM_H*0.84, 'Controller FSM',      fs=9.5, bold=True, color='#66ee77')
txt(PX+PW/2, FSM_Y+FSM_H*0.57, 'IDLE → LOAD_W → CLR', fs=7.5, color='#cccccc')
txt(PX+PW/2, FSM_Y+FSM_H*0.35, 'COMPUTE → DRAIN',      fs=7.5, color='#cccccc')
txt(PX+PW/2, FSM_Y+FSM_H*0.14, 'CAPTURE → DONE',       fs=7.5, color='#cccccc')

CTRL_Y = FSM_Y + FSM_H*0.5
arr(PX+PW, CTRL_Y, GX0-PAD-0.06, CTRL_Y, color='#44cc55', lw=1.8, ms=13)
txt((PX+PW+GX0-PAD)/2, CTRL_Y+0.22, 'load_w / en / clr', fs=8, color='#77ee88')

# ext → weight buffer arrow
arr(PX+PW, EXT_Y+EXT_H*0.70, GX0, WB_Y+WB_H*0.50, color='#ff9922', lw=1.6, ms=12)
txt((PX+PW+GX0)/2, WB_Y+WB_H*0.5+0.25, 'wr_data (weights)', fs=7.5, color='#ffbb44')

# Input Buffer
IB_Y, IB_H = 4.40, 1.80
arr(PX+PW, EXT_Y+EXT_H*0.28, PX+PW*0.85, IB_Y+IB_H, color='#888888', lw=1.4, ms=10)
box(PX, IB_Y, PW, IB_H, '#120022', '#bb44dd', lw=2.0)
txt(PX+PW/2, IB_Y+IB_H*0.82, 'Input Buffer',     fs=9.5, bold=True, color='#dd66ff')
txt(PX+PW/2, IB_Y+IB_H*0.58, 'Matrix A',         fs=9.0, color='#eeeeee')
txt(PX+PW/2, IB_Y+IB_H*0.35, '[4 × INT8 regs]', fs=8.0, color='#bbbbbb')
txt(PX+PW/2, IB_Y+IB_H*0.14, 'a_rows[31:0]',    fs=8.0, color='#ee99ff')

for r in range(N):
    cy = pe_cy(r,0)
    arr(PX+PW, IB_Y+IB_H*0.5, ENTRY_X+0.05, cy, color='#cc44cc', lw=1.5, ms=11)

txt(PX+PW+0.55, pe_cy(1,0)+0.30, 'a_rows[31:0]', fs=8, color='#ff66ff')

# ── Legend (right-middle, vertically centred with the PE grid) ────────────────
LW, LH = 3.30, 3.00
LX = 13.45
LY = (GY0 + grid_height/2) - LH/2   # vertically centred on the PE grid
box(LX, LY, LW, LH, '#050505', '#444444', lw=1.5)
txt(LX+LW/2, LY+LH-0.30, 'Data Flow Legend', fs=10, bold=True, color='#dddddd')

items = [
    ('#ff9922', 'Weights (stationary, ↓ into PEs)'),
    ('#ff55ff', 'Activations (→ right across rows)'),
    ('#33ee66', 'Partial sums (↓ down columns)'),
    ('#44ff77', 'Results (→ output buffer)'),
]
for i, (color, label) in enumerate(items):
    y = LY + LH - 0.75 - i*0.55
    arr(LX+0.20, y, LX+0.80, y, color=color, lw=2.5, ms=12)
    txt(LX+0.95, y, label, fs=8.5, color='#eeeeee', ha='left')

plt.tight_layout(pad=0.1)
out = 'docs/assets/architecture_block.png'
plt.savefig(out, dpi=160, bbox_inches='tight', facecolor='#000000')
print(f'Saved: {out}')
