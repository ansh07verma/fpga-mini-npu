"""
fixed_point_utils.py — Fixed-Point Arithmetic Helpers

Utilities for INT8 and Q8.8 fixed-point conversion.
Useful for understanding the quantization used in the NPU hardware.
"""

import numpy as np

# ── INT8 utilities ────────────────────────────────────────────────────────────

def float_to_int8(val: float, scale: float = 1.0) -> int:
    """Quantize a float to INT8 with optional scale factor."""
    quantized = round(val / scale)
    return int(np.clip(quantized, -128, 127))

def int8_to_float(val: int, scale: float = 1.0) -> float:
    """Dequantize an INT8 value back to float."""
    val = int(np.int8(val))   # ensure signed interpretation
    return val * scale

def quantize_array_int8(arr, scale=None):
    """Quantize a NumPy array to INT8. Auto-computes scale if not provided."""
    arr = np.asarray(arr, dtype=np.float32)
    if scale is None:
        scale = np.max(np.abs(arr)) / 127.0 if np.any(arr != 0) else 1.0
    quantized = np.round(arr / scale).astype(np.int8)
    return quantized, scale

# ── Q8.8 fixed-point utilities ────────────────────────────────────────────────

FRAC_BITS = 8   # Q8.8 format: 8 integer bits, 8 fractional bits

def float_to_q88(val: float) -> int:
    """Convert float to Q8.8 fixed-point (16-bit signed)."""
    raw = round(val * (1 << FRAC_BITS))
    return int(np.clip(raw, -32768, 32767))

def q88_to_float(val: int) -> float:
    """Convert Q8.8 fixed-point back to float."""
    val = int(np.int16(val))   # ensure 16-bit signed
    return val / (1 << FRAC_BITS)

def q88_multiply(a: int, b: int) -> int:
    """
    Fixed-point multiply: (a * b) >> FRAC_BITS
    Intermediate result is 32-bit to avoid overflow.
    """
    result = (int(np.int16(a)) * int(np.int16(b))) >> FRAC_BITS
    return int(np.clip(result, -32768, 32767))

# ── Demo / self-test ──────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("=== INT8 Quantization Demo ===")
    test_vals = [0.0, 1.0, -1.0, 3.14, -2.71, 100.0, 127.0, -128.0, 200.0]
    for v in test_vals:
        q = float_to_int8(v)
        d = int8_to_float(q)
        print(f"  float={v:8.2f}  →  INT8={q:5d}  →  float={d:8.2f}  "
              f"  error={abs(v - d):.2f}")

    print("\n=== Q8.8 Fixed-Point Demo ===")
    pairs = [(1.5, 2.0), (3.14, 1.0), (-0.5, 4.0), (0.1, 0.1)]
    for a, b in pairs:
        qa = float_to_q88(a)
        qb = float_to_q88(b)
        qc = q88_multiply(qa, qb)
        fc = q88_to_float(qc)
        print(f"  {a:.2f} × {b:.2f} = {a*b:.4f}  |  "
              f"Q8.8: 0x{qa & 0xFFFF:04X} × 0x{qb & 0xFFFF:04X} = {fc:.4f}  "
              f"  error={abs(a*b - fc):.4f}")

    print("\n=== Array Quantization Demo ===")
    weights = np.array([[0.1, -0.5, 0.3], [1.2, -0.8, 0.0]], dtype=np.float32)
    q_weights, scale = quantize_array_int8(weights)
    print(f"  Original:\n{weights}")
    print(f"  Scale: {scale:.4f}")
    print(f"  Quantized (INT8):\n{q_weights}")
    print(f"  Dequantized:\n{q_weights.astype(np.float32) * scale}")
