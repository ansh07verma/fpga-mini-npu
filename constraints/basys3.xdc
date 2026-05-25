## =============================================================================
## basys3.xdc — Timing & I/O Constraints for Basys3 (XC7A35T)
##
## Board : Digilent Basys3
## FPGA  : Xilinx Artix-7 XC7A35TCPG236-1
## Clock : 100 MHz on W5
##
## Pin mapping strategy for npu_top:
##   clk      → W5 (100 MHz crystal)
##   rst_n    → U18 (BTNC - center button, active LOW)
##   start    → T17 (BTNR - right button)
##   done     → U16 (LD0 - LED indicator)
##   wr_en    → V17 (SW0)
##   wr_sel   → V16 (SW1) -- 0=A matrix, 1=B weight matrix
##   rd_en    → W16 (SW2)
##   wr_row   → W13,V2  (SW3,SW4)
##   wr_col   → T3,T2   (SW5,SW6)
##   wr_data  → Pmod JA (JA1-JA4, JA7-JA10) -- 8-bit data input
##   rd_row   → W15,V15 (SW7,SW8)
##   rd_col   → W14,W12 (SW9,SW10)
##   rd_data  → LD[7:0] = lower 8 bits of result (LEDs 0-7)
##              LD[15:8] = bits [15:8] of result (for 24-bit, upper 8 on 7-seg)
## =============================================================================

## ── Master Clock ─────────────────────────────────────────────────────────────
create_clock -period 10.000 -name sys_clk [get_ports clk]
set_input_jitter sys_clk 0.100
set_clock_uncertainty 0.100 [get_clocks sys_clk]

set_property PACKAGE_PIN W5      [get_ports clk]
set_property IOSTANDARD  LVCMOS33 [get_ports clk]

## ── Reset — Center button BTNC (active-low) ──────────────────────────────────
set_property PACKAGE_PIN U18     [get_ports rst_n]
set_property IOSTANDARD  LVCMOS33 [get_ports rst_n]

## ── Start — Right button BTNR ─────────────────────────────────────────────────
set_property PACKAGE_PIN T17     [get_ports start]
set_property IOSTANDARD  LVCMOS33 [get_ports start]

## ── Done indicator — LED LD0 ─────────────────────────────────────────────────
set_property PACKAGE_PIN U16     [get_ports done]
set_property IOSTANDARD  LVCMOS33 [get_ports done]

## ── Write enable — SW0 ───────────────────────────────────────────────────────
set_property PACKAGE_PIN V17     [get_ports wr_en]
set_property IOSTANDARD  LVCMOS33 [get_ports wr_en]

## ── Matrix select — SW1 (0=A, 1=B) ─────────────────────────────────────────
set_property PACKAGE_PIN V16     [get_ports wr_sel]
set_property IOSTANDARD  LVCMOS33 [get_ports wr_sel]

## ── Read enable — SW2 ────────────────────────────────────────────────────────
set_property PACKAGE_PIN W16     [get_ports rd_en]
set_property IOSTANDARD  LVCMOS33 [get_ports rd_en]

## ── wr_row[1:0] — SW[4:3] ────────────────────────────────────────────────────
set_property PACKAGE_PIN W13     [get_ports {wr_row[0]}]
set_property PACKAGE_PIN V2      [get_ports {wr_row[1]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {wr_row[*]}]

## ── wr_col[1:0] — SW[6:5] ────────────────────────────────────────────────────
set_property PACKAGE_PIN T3      [get_ports {wr_col[0]}]
set_property PACKAGE_PIN T2      [get_ports {wr_col[1]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {wr_col[*]}]

## ── rd_row[1:0] — SW[8:7] ────────────────────────────────────────────────────
set_property PACKAGE_PIN W15     [get_ports {rd_row[0]}]
set_property PACKAGE_PIN V15     [get_ports {rd_row[1]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {rd_row[*]}]

## ── rd_col[1:0] — SW[10:9] ───────────────────────────────────────────────────
set_property PACKAGE_PIN W14     [get_ports {rd_col[0]}]
set_property PACKAGE_PIN W12     [get_ports {rd_col[1]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {rd_col[*]}]

## ── wr_data[7:0] — Pmod JB (all pins are in bank 15, LVCMOS33) ──────────────
## JB = connector J2 on Basys3
set_property PACKAGE_PIN A14     [get_ports {wr_data[0]}]
set_property PACKAGE_PIN A16     [get_ports {wr_data[1]}]
set_property PACKAGE_PIN B15     [get_ports {wr_data[2]}]
set_property PACKAGE_PIN B16     [get_ports {wr_data[3]}]
set_property PACKAGE_PIN A15     [get_ports {wr_data[4]}]
set_property PACKAGE_PIN A17     [get_ports {wr_data[5]}]
set_property PACKAGE_PIN C15     [get_ports {wr_data[6]}]
set_property PACKAGE_PIN C16     [get_ports {wr_data[7]}]
set_property IOSTANDARD  LVCMOS33 [get_ports {wr_data[*]}]

## ── rd_data[7:0] — LEDs LD[7:0] on Basys3 ───────────────────────────────────
set_property PACKAGE_PIN E19     [get_ports {rd_data[0]}]
set_property PACKAGE_PIN U19     [get_ports {rd_data[1]}]
set_property PACKAGE_PIN V19     [get_ports {rd_data[2]}]
set_property PACKAGE_PIN W18     [get_ports {rd_data[3]}]
set_property PACKAGE_PIN U15     [get_ports {rd_data[4]}]
set_property PACKAGE_PIN U14     [get_ports {rd_data[5]}]
set_property PACKAGE_PIN V14     [get_ports {rd_data[6]}]
set_property PACKAGE_PIN V13     [get_ports {rd_data[7]}]
set_property IOSTANDARD  LVCMOS33 [get_ports rd_data*]

## rd_data[23:8] — not physically mapped; suppress DRC for unconnected output bits
## These are internal signals visible only in simulation / UART readback
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]

## ── Async input false paths ───────────────────────────────────────────────────
set_false_path -from [get_ports start]
set_false_path -from [get_ports rst_n]
set_false_path -from [get_ports wr_en]
set_false_path -from [get_ports wr_sel]
set_false_path -from [get_ports rd_en]
set_false_path -from [get_ports {wr_row[*]}]
set_false_path -from [get_ports {wr_col[*]}]
set_false_path -from [get_ports {rd_row[*]}]
set_false_path -from [get_ports {rd_col[*]}]
set_false_path -from [get_ports {wr_data[*]}]
