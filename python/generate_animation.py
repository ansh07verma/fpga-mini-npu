import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
import numpy as np
import matplotlib.patches as patches

# Config
N = 4
CYCLES = 12
FIG_SIZE = (8, 6)

fig, ax = plt.subplots(figsize=FIG_SIZE)
ax.set_xlim(-2, N + 1)
ax.set_ylim(-N - 1, 2)
ax.axis('off')
ax.set_title("Weight-Stationary Systolic Array Dataflow", fontsize=16, pad=20)

# Colors
PE_COLOR = '#3498db'
A_COLOR = '#e74c3c'  # Activations flowing right
B_COLOR = '#f1c40f'  # Weights (stationary)
C_COLOR = '#2ecc71'  # Partial sums flowing down

# Draw PE grid
pes = {}
for r in range(N):
    for c in range(N):
        rect = patches.Rectangle((c, -r-1), 0.8, 0.8, linewidth=2, edgecolor='#2c3e50', facecolor=PE_COLOR, alpha=0.3)
        ax.add_patch(rect)
        # Weight label (stationary)
        ax.text(c + 0.4, -r - 0.2, f"W{r}{c}", ha='center', va='center', color=B_COLOR, fontweight='bold', fontsize=9)
        
        # dynamic text handles
        pes[(r, c)] = {
            'act': ax.text(c + 0.15, -r - 0.7, "", ha='center', va='center', color=A_COLOR, fontsize=10, fontweight='bold'),
            'psum': ax.text(c + 0.65, -r - 0.7, "", ha='center', va='center', color=C_COLOR, fontsize=10, fontweight='bold')
        }

# Data streams
acts = {}  # incoming A
psums = {} # outgoing C

for r in range(N):
    # Activation inputs (left side)
    acts[r] = ax.text(-0.5, -r - 0.5, "", ha='center', va='center', color=A_COLOR, fontsize=11, fontweight='bold')
for c in range(N):
    # Psum outputs (bottom side)
    psums[c] = ax.text(c + 0.4, -N - 0.5, "", ha='center', va='center', color=C_COLOR, fontsize=11, fontweight='bold')

cycle_text = ax.text(-1.5, 1, "Cycle: 0", fontsize=14, fontweight='bold', color='#34495e')

# Legend
ax.plot([], [], 'o', color=A_COLOR, label="Activation (Flows Right)")
ax.plot([], [], 'o', color=B_COLOR, label="Weight (Stationary)")
ax.plot([], [], 'o', color=C_COLOR, label="Partial Sum (Flows Down)")
ax.legend(loc='upper right', frameon=False, fontsize=10)

def init():
    return []

def update(frame):
    cycle = frame
    cycle_text.set_text(f"Cycle: {cycle}")
    
    # Input Activations (staggered by row)
    for r in range(N):
        # Activation index for row r at this cycle
        a_idx = cycle - r
        if 0 <= a_idx < 4:
            acts[r].set_text(f"X{a_idx}")
        else:
            acts[r].set_text("")
            
    # PE Grid values
    for r in range(N):
        for c in range(N):
            # PE gets active at cycle = r + c
            # It processes for 4 cycles
            active_idx = cycle - (r + c)
            if 0 <= active_idx < 4:
                pes[(r, c)]['act'].set_text(f"X{active_idx}")
                pes[(r, c)]['psum'].set_text(f"Y{active_idx}")
                # Highlight active PE
                pes[(r, c)]['act'].set_alpha(1.0)
            else:
                pes[(r, c)]['act'].set_text("")
                pes[(r, c)]['psum'].set_text("")

    # Output Psums (staggered by col, appears after N rows)
    for c in range(N):
        out_idx = cycle - (N - 1 + c) - 1
        if 0 <= out_idx < 4:
            psums[c].set_text(f"Y{out_idx}")
        else:
            psums[c].set_text("")
            
    return []

print("Generating dataflow animation...")
ani = FuncAnimation(fig, update, frames=CYCLES, init_func=init, blit=False, interval=600)
ani.save("docs/assets/dataflow.gif", writer='pillow', dpi=100)
print("Saved to docs/assets/dataflow.gif")
