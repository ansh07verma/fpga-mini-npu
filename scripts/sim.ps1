# =============================================================================
# sim.ps1 — One-command Verilog Simulation Runner
#
# Usage:
#   .\scripts\sim.ps1 -module mac_unit        # Simulate one module
#   .\scripts\sim.ps1 -module all             # Simulate all testbenches
#   .\scripts\sim.ps1 -module mac_unit -wave  # Open waveform after sim
#
# Requirements: Vivado xvlog/xelab/xsim on PATH
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$module,

    [switch]$wave   # Open waveform viewer after simulation
)

$Root     = Split-Path $PSScriptRoot -Parent
$RTL      = "$Root\rtl"
$TB       = "$Root\tb"
$Results  = "$Root\results\simulation_logs"
$WorkDir  = "$Root\results\simulation_logs\xsim_work"

# Vivado path (update if your install is elsewhere)
$VivadoBin = "C:\AMDDesignTools\2025.2\Vivado\bin"
if (-not ($env:PATH -split ";" | Where-Object { $_ -like "*Vivado*" })) {
    $env:PATH = "$VivadoBin;$env:PATH"
}

New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
New-Item -ItemType Directory -Force -Path $Results | Out-Null

# Map module names to their source files
$modules = @{
    "mac_unit"       = @{
        src = @("$RTL\mac_unit.v", "$TB\tb_mac_unit.v")
        top = "tb_mac_unit"
    }
    "pe"             = @{
        src = @("$RTL\mac_unit.v", "$RTL\pe.v", "$TB\tb_pe.v")
        top = "tb_pe"
    }
    "systolic_2x2"   = @{
        src = @("$RTL\mac_unit.v", "$RTL\pe.v", "$RTL\systolic_array_2x2.v", "$TB\tb_systolic_4x4.v")
        top = "tb_systolic_4x4"
    }
    "systolic_4x4"   = @{
        src = @("$RTL\mac_unit.v", "$RTL\pe.v", "$RTL\systolic_array_4x4.v", "$TB\tb_systolic_4x4.v")
        top = "tb_systolic_4x4"
    }
    "npu_top"        = @{
        src = @(
            "$RTL\mac_unit.v",
            "$RTL\pe.v",
            "$RTL\systolic_array_4x4.v",
            "$RTL\input_buffer.v",
            "$RTL\weight_buffer.v",
            "$RTL\output_buffer.v",
            "$RTL\controller_fsm.v",
            "$RTL\npu_top.v",
            "$TB\tb_npu_top.v"
        )
        top = "tb_npu_top"
    }
    "relu"           = @{
        src = @("$RTL\relu_layer.v", "$TB\tb_relu_layer.v")
        top = "tb_relu_layer"
    }
    "im2col"         = @{
        src = @("$RTL\im2col.v", "$TB\tb_im2col.v")
        top = "tb_im2col"
    }
    "cnn_layer"      = @{
        src = @(
            "$RTL\mac_unit.v",
            "$RTL\pe.v",
            "$RTL\systolic_array_4x4.v",
            "$RTL\relu_layer.v",
            "$RTL\im2col.v",
            "$RTL\cnn_layer.v",
            "$TB\tb_cnn_layer.v"
        )
        top = "tb_cnn_layer"
    }
    "all"            = $null
}

function Run-Sim {
    param([string]$name, [string[]]$sources, [string]$topModule)

    Write-Host "`n$('='*60)" -ForegroundColor Cyan
    Write-Host "  Simulating: $name" -ForegroundColor Yellow
    Write-Host "$('='*60)" -ForegroundColor Cyan

    Push-Location $WorkDir

    # Step 1: Compile
    Write-Host "[1/3] Compiling..." -ForegroundColor Blue
    $compile_args = @("--nolog", "--work", "work") + $sources
    & xvlog @compile_args
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Compilation failed for $name" -ForegroundColor Red
        Pop-Location; return $false
    }

    # Step 2: Elaborate
    Write-Host "[2/3] Elaborating..." -ForegroundColor Blue
    & xelab "-debug" "typical" "-snapshot" "${topModule}_snap" $topModule
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Elaboration failed for $name" -ForegroundColor Red
        Pop-Location; return $false
    }

    # Step 3: Simulate
    Write-Host "[3/3] Simulating..." -ForegroundColor Blue
    $log_file = "$Results\${name}.log"
    & xsim "--runall" "${topModule}_snap" 2>&1 | Tee-Object -FilePath $log_file

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Simulation failed for $name" -ForegroundColor Red
        Pop-Location; return $false
    }

    # Check for FAIL in output
    $log = Get-Content $log_file -ErrorAction SilentlyContinue
    $failures  = $log | Select-String "\[FAIL\]"
    $passes    = $log | Select-String "\[PASS\]"
    # Also detect: "RESULTS: N PASS / 0 FAIL" summary lines
    $results_line = $log | Select-String "RESULTS:" | Select-Object -Last 1
    $zero_fail    = $results_line -match "/ 0 FAIL"
    $any_fail     = $results_line -match "/ [^0]\d* FAIL"

    Write-Host ""
    if ($failures -or $any_fail) {
        Write-Host "  FAILURES DETECTED:" -ForegroundColor Red
        $failures | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    } else {
        Write-Host "  All checks passed!" -ForegroundColor Green
    }
    # Show summary count from RESULTS line if available, else [PASS]/[FAIL] counts
    if ($results_line) {
        Write-Host "  $results_line"
    } else {
        Write-Host "  $($passes.Count) PASS  /  $($failures.Count) FAIL"
    }
    Write-Host "  Log: $log_file"

    # Open waveform if requested
    if ($wave) {
        $vcd = "$Results\${name}.vcd"
        if (Test-Path $vcd) {
            Write-Host "`nOpening waveform in Vivado..." -ForegroundColor Cyan
            Start-Process vivado -ArgumentList "-source $PSScriptRoot\open_wave.tcl -tclargs $vcd"
        }
    }

    Pop-Location
    return ($failures.Count -eq 0)
}

# ── Main ──────────────────────────────────────────────────────────────────────
$total_pass = 0
$total_fail = 0

if ($module -eq "all") {
    foreach ($name in $modules.Keys | Where-Object { $_ -ne "all" }) {
        $m = $modules[$name]
        $ok = Run-Sim -name $name -sources $m.src -topModule $m.top
        if ($ok) { $total_pass++ } else { $total_fail++ }
    }
    Write-Host "`n$('='*60)" -ForegroundColor Cyan
    Write-Host "  TOTAL: $total_pass passed / $total_fail failed" -ForegroundColor $(if ($total_fail -eq 0) { "Green" } else { "Red" })
    Write-Host "$('='*60)`n" -ForegroundColor Cyan
} elseif ($modules.ContainsKey($module)) {
    $m = $modules[$module]
    Run-Sim -name $module -sources $m.src -topModule $m.top
} else {
    Write-Host "Unknown module: $module" -ForegroundColor Red
    Write-Host "Available: $($modules.Keys -join ', ')"
    exit 1
}
