import matplotlib.pyplot as plt
import numpy as np

# Config
N = 4
CYCLES = 12

fig, ax = plt.subplots(figsize=(10, 6))

# Set up grid
ax.set_xlim(0, CYCLES)
ax.set_ylim(-1, N * N)
ax.set_xticks(np.arange(0, CYCLES + 1, 1))
ax.set_yticks(np.arange(0, N * N, 1))

# Labels for Y axis
yticklabels = []
for r in range(N):
    for c in range(N):
        yticklabels.append(f"PE({r},{c})")
ax.set_yticklabels(yticklabels)
ax.set_xlabel("Clock Cycle", fontsize=12, fontweight='bold')
ax.set_ylabel("Processing Element", fontsize=12, fontweight='bold')
ax.set_title("Systolic Array Space-Time Schedule (Wavefront Execution)", fontsize=16, pad=15)
ax.grid(True, linestyle='--', alpha=0.5)

colors = ['#3498db', '#e74c3c', '#2ecc71', '#9b59b6']

# Draw the execution blocks
for r in range(N):
    for c in range(N):
        pe_idx = r * N + c
        # PE(r,c) starts at cycle r+c
        start_cycle = r + c
        
        # It processes 4 patches
        for patch in range(4):
            cycle = start_cycle + patch
            rect = plt.Rectangle((cycle, pe_idx - 0.4), 1, 0.8, 
                               facecolor=colors[patch % len(colors)], 
                               edgecolor='black', alpha=0.8)
            ax.add_patch(rect)
            ax.text(cycle + 0.5, pe_idx, f"P{patch}", ha='center', va='center', color='white', fontweight='bold', fontsize=8)

# Add legend
import matplotlib.patches as mpatches
legend_patches = [mpatches.Patch(color=colors[i], label=f'Patch {i}') for i in range(4)]
ax.legend(handles=legend_patches, loc='upper right', bbox_to_anchor=(1.15, 1))

plt.tight_layout()
print("Generating timing visualization...")
plt.savefig("docs/assets/systolic_timing.png", dpi=150, bbox_inches='tight')
print("Saved to docs/assets/systolic_timing.png")
