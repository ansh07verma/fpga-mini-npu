# FPGA Mini NPU — CNN Accelerator using Systolic Array Architecture

[![Simulation](https://img.shields.io/badge/sim-passing-brightgreen)]()
[![FPGA](https://img.shields.io/badge/FPGA-Basys3%20Artix--7-blue)]()
[![Vivado](https://img.shields.io/badge/Vivado-2025.2-orange)]()
[![Language](https://img.shields.io/badge/language-Verilog-purple)]()

> A small-scale Neural Processing Unit (NPU) implemented in Verilog RTL,  
> accelerating INT8 matrix multiplication via a weight-stationary systolic array  
> on an FPGA (Basys3 / Nexys A7).

---

## Architecture Overview

```
 External Interface
 ┌─────────────────────────────────────────────────────────────┐
 │  wr_en / wr_data  ──►  Input Buffer (Matrix A)             │
 │                   ──►  Weight Buffer (Matrix B)             │
 │                                                             │
 │  start ──► Controller FSM ──────────────────────────────►  │
 │             IDLE→LOAD_W→LOAD_A→COMPUTE→DRAIN→DONE          │
 │                    │                                        │
 │                    ▼                                        │
 │         ┌─────────────────────┐                            │
 │         │  4×4 Systolic Array  │                            │
 │         │  [PE][PE][PE][PE]   │  ← weights stationary      │
 │         │  [PE][PE][PE][PE]   │  ← activations flow right  │
 │         │  [PE][PE][PE][PE]   │  ← partial sums flow down  │
 │         │  [PE][PE][PE][PE]   │                            │
 │         └─────────┬───────────┘                            │
 │                   │ y_out                                   │
 │                   ▼                                        │
 │         Output Buffer (Matrix C)  ──►  rd_data             │
 │                                        done LED            │
 └─────────────────────────────────────────────────────────────┘
```

Each **Processing Element (PE)** implements:
```
y = y + (activation × weight)    // 2-stage pipelined MAC
```

---

## Repository Structure

```
fpga-mini-npu/
├── rtl/
│   ├── mac_unit.v            # 2-stage pipelined INT8 MAC
│   ├── pe.v                  # Weight-stationary Processing Element
│   ├── systolic_array_2x2.v  # 2×2 systolic array
│   ├── systolic_array_4x4.v  # 4×4 systolic array (parameterizable)
│   ├── input_buffer.v        # Matrix A register file
│   ├── weight_buffer.v       # Matrix B register file
│   ├── output_buffer.v       # Result capture buffer
│   ├── controller_fsm.v      # One-hot FSM controller
│   └── npu_top.v             # Top-level integration
├── tb/
│   ├── tb_mac_unit.v         # 9-case MAC unit testbench
│   ├── tb_systolic_4x4.v     # 5-case systolic array testbench (80/80 pass)
│   └── tb_npu_top.v          # End-to-end system testbench (64/64 pass)
├── python/
│   ├── golden_model.py       # NumPy reference model
│   ├── gen_test_vectors.py   # Random INT8 test matrix generator
│   └── fixed_point_utils.py  # INT8 / Q8.8 quantization helpers
├── scripts/
│   ├── sim.ps1               # One-command simulation runner
│   └── synth.tcl             # Vivado batch synthesis script
├── constraints/
│   └── basys3.xdc            # Timing + I/O constraints (Basys3)
├── results/
│   ├── simulation_logs/      # VCD waveforms + logs
│   └── utilization_reports/  # Vivado synthesis reports
└── docs/
    ├── architecture.md       # Detailed architecture documentation
    └── interview_prep.md     # Q&A for all 4 PRD interview questions
```

---

## Quick Start

### 1. Simulate the MAC Unit
```powershell
cd fpga-mini-npu
.\scripts\sim.ps1 -module mac_unit
```

### 2. Simulate the Full 4×4 Systolic Array
```powershell
.\scripts\sim.ps1 -module systolic_4x4
```

### 3. Simulate End-to-End (Full Chip)
```powershell
.\scripts\sim.ps1 -module npu_top
# Loads A and B, pulses start, waits for done, reads back C
```

### 4. Run All Testbenches
```powershell
.\scripts\sim.ps1 -module all
```

### 5. Run Python Golden Model
```powershell
python python/golden_model.py
python python/gen_test_vectors.py --seed 42
```

### 6. Synthesize for Basys3
```powershell
vivado -mode batch -source scripts/synth.tcl
```

---

## Simulation Waveforms

Below are cycle-accurate waveform captures demonstrating the core operation of the CNN Layer inference pipeline.

### Full Inference Run (5 Patches)
*(A bird's-eye view showing the patch index counting up and the `done` signal asserting at cycle 65)*

![Full Waveform](docs/assets/waveform_full.png)

### Pipeline Zoom-in (First 150 ns)
*(Detailed view of the FSM moving from `IDLE (0)` → `LOAD_W (1)` → `CLR (2)` → `COMPUTE (3)` and raw data streaming into `a_rows_reg`)*

![Zoomed Waveform](docs/assets/waveform_zoom.png)

---

## Performance Results

### Simulation — 100% Pass Rate

| Testbench | Tests | Result |
|---|---|---|
| `tb_mac_unit` | 9 | ✅ 9/9 PASS |
| `tb_systolic_4x4` | 5 × 16 elements | ✅ 80/80 PASS |
| `tb_npu_top` (end-to-end) | 4 × 16 elements | ✅ 64/64 PASS |

### Synthesis — Basys3 (XC7A35T @ 100 MHz)

| Metric | Value | Notes |
|--------|-------|-------|
| **WNS (timing slack)** | **+0.153 ns ✅** | Synthesis: +0.819 ns → Post-place: +0.505 ns → Post-route: +0.153 ns |
| Slice LUTs | 1,811 / 20,800 (8.71%) | Post-route |
| Slice Registers | 1,258 / 41,600 (3.02%) | |
| DSP48E1 | 16* (synthesis: 0) / 90 (18%) | `(* use_dsp = "yes" *)` — maps at implementation |
| Block RAM | 0 / 50 (0%) | Pure register-file implementation |
| **Latency (4×4 matmul)** | **17 cycles** | LOAD_W(4)+CLR(1)+COMPUTE(4)+DRAIN(6)+DONE(1) |
| **Throughput** | **1 matmul / 170 ns** | At 100 MHz |
| **Bitstream** | **npu_top.bit (2,140 KB)** | ✅ Ready to flash to Basys3 |
| Accumulator | 24-bit signed | No overflow: max = 4×127×127 = 64,516 |

---

## Key Design Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Arithmetic | INT8 signed | Maps to DSP48 slices; industry NPU standard |
| Array topology | Weight-stationary | Max weight reuse; simple control logic |
| FSM encoding | One-hot | Easy Vivado debugging, clean timing |
| Memory | Register files | No BRAM dependency; educational clarity |
| Accumulator | 24-bit | Prevents overflow: max chain = 4×127×127 = 64,516 |

---

## How Systolic Arrays Work

In a weight-stationary systolic array:

1. **Pre-load phase**: Each PE row absorbs its weight column from matrix B
2. **Compute phase**: Matrix A columns flow rightward through the grid, one element per PE per cycle
3. **Accumulate**: Partial dot products accumulate downward through PE rows
4. **Drain phase**: After N+pipeline cycles, results are read from the bottom row

This achieves **O(N²) parallelism** with **O(1) memory bandwidth** per cycle — the key advantage over CPU sequential execution.

---

## License

MIT License — free to use for academic and educational purposes.
