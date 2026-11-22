$ErrorActionPreference = "Continue"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$IverilogCommand = Get-Command "iverilog.exe" -ErrorAction SilentlyContinue
if (-not $IverilogCommand) {
    throw "Icarus Verilog executable 'iverilog.exe' was not found on PATH"
}
$Iverilog = $IverilogCommand.Source

$OutputDir = Join-Path $ProjectRoot "simulation"
$OutputFile = Join-Path $OutputDir "mini_soc_compile.vvp"

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$Arguments = @(
    "-g2012",
    "-Wall",
    "-s", "mini_soc",
    "-o", $OutputFile,
    (Join-Path $ProjectRoot "rtl\mini_soc.v"),
    (Join-Path $ProjectRoot "rtl\ram.v"),
    (Join-Path $ProjectRoot "rtl\gpio.v"),
    (Join-Path $ProjectRoot "rtl\timer.v"),
    (Join-Path $ProjectRoot "rtl\uart.v"),
    (Join-Path $ProjectRoot "rtl\spi.v")
)

Write-Host "Compiling Mini SoC top-level..."
& $Iverilog $Arguments
$CompileExitCode = $LASTEXITCODE

if ($CompileExitCode -ne 0) {
    Write-Host "COMPILATION FAILED: Mini SoC top-level (iverilog exit code $CompileExitCode)"
    exit 1
}

Write-Host "COMPILATION PASSED: Mini SoC top-level"
exit 0
