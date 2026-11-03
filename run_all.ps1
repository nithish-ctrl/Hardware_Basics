# run_all.ps1: runs every example in hardware_basics and reports PASS/FAIL per example.
# First, in this PowerShell window:  . D:\Downloads\Hardware\tools\oss-cad-suite\environment.ps1
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$code = Join-Path $root "code"

if (-not (Get-Command iverilog -ErrorAction SilentlyContinue)) {
    Write-Host "iverilog not found. Run this first:" -ForegroundColor Yellow
    Write-Host "  . D:\Downloads\Hardware\tools\oss-cad-suite\environment.ps1"
    exit 1
}

$results = @()

function Run-Example($name, $dir, [scriptblock]$commands, $mustContain) {
    Push-Location (Join-Path $code $dir)
    try {
        $out = (& $commands 2>&1 | Out-String)
    } finally {
        Pop-Location
    }
    $ok = $true
    foreach ($m in $mustContain) { if ($out -notmatch [regex]::Escape($m)) { $ok = $false } }
    if ($out -match "FAIL") { $ok = $false }
    $script:results += [pscustomobject]@{ Example = $name; Result = $(if ($ok) { "PASS" } else { "FAIL" }) }
    if (-not $ok) { Write-Host "---- output of $name ----"; Write-Host $out }
}

Run-Example "02 numbers lab"         "02_numbers"       { python numbers_lab.py }                                    @("IEEE-754")
Run-Example "03 full adder + XOR"    "03_logic_gates"   { iverilog -o logic.vvp full_adder.v tb_logic.v; vvp -n logic.vvp } @("PASS")
Run-Example "04 combinational"       "04_combinational" { iverilog -o comb.vvp ..\03_logic_gates\full_adder.v comb_blocks.v tb_comb.v; vvp -n comb.vvp } @("PASS")
Run-Example "05 sequential"          "05_sequential"    { iverilog -o seq.vvp seq_basics.v tb_seq.v; vvp -n seq.vvp }  @("count wraps")
Run-Example "06 blocking demo"       "06_cycles_fsm"    { iverilog -o blocking.vvp blocking_demo.v; vvp -n blocking.vvp } @("walks down")
Run-Example "06 traffic light FSM"   "06_cycles_fsm"    { iverilog -o traffic.vvp traffic_light.v tb_traffic.v; vvp -n traffic.vvp } @("button pressed", "YELLOW")
Run-Example "06 valid/ready"         "06_cycles_fsm"    { iverilog -o handshake.vvp tb_handshake.v; vvp -n handshake.vvp } @("PASS")
Run-Example "07 RAM + FIFO"          "07_memory"        { iverilog -o mem.vvp memories.v tb_memories.v; vvp -n mem.vvp } @("PASS")
Run-Example "08 fixed point + lerp"  "08_arithmetic"    { iverilog -o fixed.vvp fixed_point.v tb_fixed.v; vvp -n fixed.vvp } @("PASS")
Run-Example "09 tiny assembler"      "09_tiny_cpu"      { python tiny_asm.py sum.s sum.hex }                         @("F000")
Run-Example "09 tiny CPU"            "09_tiny_cpu"      { iverilog -o cpu.vvp tiny_cpu.v tb_cpu.v; vvp -n cpu.vvp }   @("PASS")
Run-Example "10 SIMT trace"          "10_cpu_to_gpu"    { python simt_trace.py }                                     @("EXIT")
Run-Example "10 latency hiding"      "10_cpu_to_gpu"    { python latency_hiding.py }                                 @("ALU busy")
Run-Example "11 transform demo"      "11_graphics_math" { python transform_demo.py }                                 @("PERSPECTIVE DIVIDE")
Run-Example "11 mini rasterizer"     "11_graphics_math" { python mini_raster.py }                                    @("triangle.png")

$results | Format-Table -AutoSize
$failed = @($results | Where-Object { $_.Result -eq "FAIL" }).Count
if ($failed -eq 0) { Write-Host "All $($results.Count) examples passed." -ForegroundColor Green }
else { Write-Host "$failed example(s) failed (output shown above)." -ForegroundColor Red; exit 1 }
