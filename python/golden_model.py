"""
golden_model.py — NumPy INT8 Matrix Multiply Reference

Computes the expected output C = A * B using INT8 quantization
so testbench results can be verified against a known-good reference.

Usage:
    python python/golden_model.py

Outputs:
    - Console: matrix values and expected results
    - results/simulation_logs/golden_C.hex  (for $readmemh in testbenches)
"""

import numpy as np
import os

# ── Matrix definitions (match tb_systolic_4x4.v Test 2) ─────────────────────
A = np.array([
    [1, 2, 3, 4],
    [2, 3, 4, 5],
    [3, 4, 5, 6],
    [4, 5, 6, 7],
], dtype=np.int8)

B = np.array([
    [1, 1, 1, 1],
    [1, 2, 1, 2],
    [2, 1, 2, 1],
    [2, 2, 2, 2],
], dtype=np.int8)

# ── Compute C = A * B in int32 to avoid overflow ─────────────────────────────
C = np.matmul(A.astype(np.int32), B.astype(np.int32))

print("=" * 50)
print("Matrix A (INT8):")
print(A)
print("\nMatrix B (INT8):")
print(B)
print("\nC = A × B (INT32 accumulation):")
print(C)
print("=" * 50)

# ── Verify against expected values ───────────────────────────────────────────
# C[0][0] = 1*1 + 2*1 + 3*2 + 4*2 = 1+2+6+8 = 17
expected_C00 = 17
assert C[0][0] == expected_C00, f"Mismatch! C[0][0]={C[0][0]}, expected {expected_C00}"
print(f"\n[OK] C[0][0] = {C[0][0]} (expected {expected_C00})")
print(f"[OK] C[0]    = {list(C[0])}")
print(f"[OK] C[3]    = {list(C[3])}")

# ── Identity matrix sanity check ─────────────────────────────────────────────
A2 = np.arange(1, 17, dtype=np.int8).reshape(4, 4)
I  = np.eye(4, dtype=np.int8)
C2 = np.matmul(A2.astype(np.int32), I.astype(np.int32))
assert np.array_equal(C2, A2.astype(np.int32)), "Identity multiply failed!"
print(f"\n[OK] A * I = A  (identity test passed)")

# ── Export C as hex file for Verilog $readmemh ───────────────────────────────
os.makedirs("results/simulation_logs", exist_ok=True)
with open("results/simulation_logs/golden_C.hex", "w") as f:
    for r in range(4):
        for c in range(4):
            val = int(C[r][c]) & 0xFFFFFF   # 24-bit mask
            f.write(f"{val:06x}\n")

print("\n[OK] Exported results/simulation_logs/golden_C.hex")
print("\nAll golden model checks PASSED ✓")
