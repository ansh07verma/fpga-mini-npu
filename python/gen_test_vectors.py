"""
gen_test_vectors.py — Generate INT8 Random Test Matrices

Generates random 4x4 INT8 matrices A and B, computes expected C = A*B,
and exports everything to hex files for $readmemh in Verilog testbenches.

Usage:
    python python/gen_test_vectors.py [--seed 42] [--n 4]
"""

import numpy as np
import argparse
import os

def quantize_int8(arr):
    """Clip and convert to int8."""
    return np.clip(arr, -128, 127).astype(np.int8)

def export_hex(matrix, filename, width_bits=8):
    """Export matrix elements as hex, one per line (row-major order)."""
    mask = (1 << width_bits) - 1
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with open(filename, "w") as f:
        for row in matrix:
            for val in row:
                f.write(f"{int(val) & mask:0{width_bits//4}x}\n")
    print(f"  Exported: {filename}")

def main():
    parser = argparse.ArgumentParser(description="Generate NPU test vectors")
    parser.add_argument("--seed", type=int, default=42,   help="Random seed")
    parser.add_argument("--n",    type=int, default=4,    help="Matrix dimension")
    parser.add_argument("--scale", type=int, default=10,  help="Max element value")
    args = parser.parse_args()

    rng = np.random.default_rng(args.seed)
    N   = args.n

    # Generate random INT8 matrices (small values to avoid accumulator saturation)
    A_raw = rng.integers(-args.scale, args.scale, size=(N, N))
    B_raw = rng.integers(-args.scale, args.scale, size=(N, N))
    A = quantize_int8(A_raw)
    B = quantize_int8(B_raw)

    # Compute golden reference (INT32 accumulation)
    C = np.matmul(A.astype(np.int32), B.astype(np.int32))

    print(f"\n=== Test Vector Generator (seed={args.seed}, N={N}) ===")
    print(f"\nMatrix A (INT8):\n{A}")
    print(f"\nMatrix B (INT8):\n{B}")
    print(f"\nExpected C = A×B (INT32):\n{C}")

    # Export
    export_hex(A, "results/simulation_logs/test_A.hex", width_bits=8)
    export_hex(B, "results/simulation_logs/test_B.hex", width_bits=8)
    export_hex(C, "results/simulation_logs/expected_C.hex", width_bits=24)

    # Also print Verilog-ready initialization
    print("\n--- Verilog initial block (copy to testbench) ---")
    for r in range(N):
        for c in range(N):
            print(f"A[{r}][{c}]={int(A[r][c])}; ", end="")
        print()
    print()
    for r in range(N):
        for c in range(N):
            print(f"B[{r}][{c}]={int(B[r][c])}; ", end="")
        print()

    print("\nAll test vectors generated ✓")

if __name__ == "__main__":
    main()
