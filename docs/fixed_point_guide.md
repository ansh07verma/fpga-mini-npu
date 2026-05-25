# Fixed-Point Arithmetic Guide
## Reference for the FPGA Mini NPU Project

---

## 1. What Is Fixed-Point Arithmetic?

Floating-point numbers (like IEEE 754 `float`) represent real numbers with a dynamic exponent — they can represent 1.5 × 10⁻³⁸ and 3.14159265 and 1.7 × 10³⁸ all with similar relative precision.

**Fixed-point** removes the dynamic exponent. Instead, the binary point is fixed at a predetermined position. This means:

- Simpler, faster hardware (no exponent logic)
- Deterministic latency (no special cases for NaN, Inf, denormals)
- Maps directly to integer arithmetic units (adders, multipliers, DSP slices)
- Predictable overflow behavior

---

## 2. Notation: Qm.n Format

Fixed-point numbers are described using **Q notation**:

| Notation | Meaning |
|---|---|
| `Q8.0` | 8 integer bits, 0 fractional bits = plain INT8 |
| `Q4.4` | 4 integer bits, 4 fractional bits |
| `Q0.8` | 0 integer bits, 8 fractional bits (all fractional) |
| `Q1.7` | 1 integer bit (sign only), 7 fractional bits |

For **this NPU**, we use `INT8` = `Q8.0` (8-bit signed integer, no fractional bits):

```
Bit pattern: [s|i₆|i₅|i₄|i₃|i₂|i₁|i₀]
              ↑
          sign bit (two's complement)

Range: -128 to +127
```

---

## 3. INT8 Multiply → 16-bit Product

When two INT8 values are multiplied, the result requires **16 bits** to avoid overflow:

```
max_positive = 127 × 127 = 16,129     fits in 15 bits (2^14 = 16,384)
max_negative = -128 × 127 = -16,256   fits in 16-bit signed (min = -32,768)
worst_case   = -128 × -128 = 16,384   fits in 15 bits (2^14 = 16,384) ✓
```

In Verilog:
```verilog
wire signed [7:0]  a, b;
wire signed [15:0] product = a * b;  // 16-bit signed result, no overflow
```

---

## 4. Accumulation → 24-bit Accumulator

The NPU accumulates **4 products** (for a 4×4 matrix multiply):

```
max_accumulation = 4 × (127 × 127) = 4 × 16,129 = 64,516
```

A 24-bit signed accumulator has range **−8,388,608 to +8,388,607**, so:

```
64,516 << 8,388,607   ✓ — no overflow possible for 4×4 INT8 matmul
```

In Verilog (the `mac_unit`):
```verilog
wire signed [15:0] product = a * b;
wire signed [23:0] product_ext = {{8{product[15]}}, product};  // sign-extend to 24b
reg  signed [23:0] y;                                           // accumulator

// Accumulate:
y <= y + product_ext;
```

---

## 5. Sign Extension

When widening a signed number from N bits to M bits (M > N), you must copy the **sign bit** into all new upper bits:

```
INT8 value: -3 = 1111_1101b  (8 bits)

Sign-extend to 16 bits:
  = 1111_1111_1111_1101b  ✓ = -3 in INT16

Zero-extend (WRONG for signed!):
  = 0000_0000_1111_1101b  ✗ = +253 in INT16
```

Verilog sign extension:
```verilog
// Manual (explicit):
wire signed [23:0] ext = {{8{product[15]}}, product};

// Automatic (Verilog does this when you assign narrow signed to wide signed):
wire signed [23:0] ext = product;  // also works if both are declared signed
```

---

## 6. Quantization: Float → INT8

Neural network weights are trained in float32, then **quantized** to INT8 for inference:

### Symmetric Quantization (used by this NPU)

```
scale = max(|W|) / 127

INT8_val = round(float_val / scale)
         = clamp(INT8_val, -128, 127)

# Dequantize (after matmul):
float_result = INT8_result * scale_A * scale_B
```

### Example

```python
import numpy as np

W_float = np.array([0.5, -1.0, 0.25, -0.75])  # weights
scale   = np.max(np.abs(W_float)) / 127        # = 1.0 / 127 ≈ 0.00787

W_int8  = np.clip(np.round(W_float / scale), -128, 127).astype(np.int8)
# W_int8 = [63, -127, 32, -95]

# After INT8 matmul, dequantize:
output_float = matmul_int8_result * scale * scale_input
```

---

## 7. Overflow Analysis for Scaling

| Array Size | Max Accumulation | Bits Required | Accumulator Width |
|---|---|---|---|
| 2×2 | 2 × 127² = 32,258 | 15 bits | 16-bit safe |
| 4×4 | 4 × 127² = 64,516 | 17 bits | 24-bit safe |
| 8×8 | 8 × 127² = 129,032 | 18 bits | 24-bit safe |
| 16×16 | 16 × 127² = 258,064 | 18 bits | 24-bit safe |
| 256×256 | 256 × 127² = 4,128,768 | 22 bits | 24-bit safe |
| 512×512 | 512 × 127² = 8,257,536 | 23 bits | 24-bit **marginal** |

> For **any array ≤ 256×256**, a 24-bit accumulator is safe for INT8 inputs.

---

## 8. Two's Complement — Quick Reference

| Value | 8-bit Binary | Hex |
|---|---|---|
| +127 | `0111 1111` | `0x7F` |
| +1   | `0000 0001` | `0x01` |
| 0    | `0000 0000` | `0x00` |
| −1   | `1111 1111` | `0xFF` |
| −128 | `1000 0000` | `0x80` |

**Rules:**
- MSB = 1 → negative
- Negate: flip all bits + 1
- Addition/subtraction: same as unsigned (hardware is identical!)

---

## 9. Why INT8 for AI Hardware?

| Format | Bits | Area (relative) | Power | Typical Accuracy Drop |
|---|---|---|---|---|
| FP32 | 32 | 16× | 16× | Baseline |
| FP16 | 16 | 4× | 4× | < 0.1% |
| **INT8** | **8** | **1×** | **1×** | **< 1%** |
| INT4 | 4 | 0.25× | 0.25× | 1–3% |

A single Xilinx DSP48E1 slice computes `P = A×B + C` (18×27→48 bit) in **1 clock cycle** at up to **741 MHz**. The NPU uses this primitive for each of the 16 PE multipliers.

---

## 10. Fixed-Point in This Codebase

| File | Role | Format |
|---|---|---|
| `rtl/mac_unit.v` | Multiply-accumulate | INT8 in, 24-bit acc |
| `python/fixed_point_utils.py` | Quantization helpers | float→INT8, INT8→float |
| `python/golden_model.py` | Reference model | INT8 matmul via NumPy |
| `python/gen_test_vectors.py` | Test vector generation | Random INT8 matrices |

```python
# From fixed_point_utils.py
def quantize(x, bits=8):
    max_val = 2**(bits-1) - 1        # 127
    scale   = np.max(np.abs(x)) / max_val
    return np.clip(np.round(x / scale), -max_val-1, max_val).astype(np.int8), scale

def dequantize(x_int, scale_a, scale_b):
    return x_int.astype(np.float32) * scale_a * scale_b
```
