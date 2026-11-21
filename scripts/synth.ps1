$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$OutputDir = Join-Path $ProjectRoot "simulation\synthesis"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$YosysNative = Get-Command yosys -ErrorAction SilentlyContinue
$Python = Get-Command python -ErrorAction SilentlyContinue

if ($YosysNative) {
    $YosysCommand = $YosysNative.Source
    Write-Host ("Yosys: " + (& $YosysCommand "-V"))
    & $YosysCommand "-s" (Join-Path $ProjectRoot "scripts\synth.ys")
    exit $LASTEXITCODE
}

if (-not $Python) {
    Write-Host "Yosys not found. Install yosys or yowasp-yosys."
    exit 1
}

$PythonCommand = $Python.Source
$VersionCode = "from yowasp_yosys import run_yosys; raise SystemExit(run_yosys(['-V']))"
& $PythonCommand "-c" $VersionCode
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$ScriptPath = (Join-Path $ProjectRoot "scripts\synth.ys").Replace('\', '/')
$SynthesisCode = "from yowasp_yosys import run_yosys; raise SystemExit(run_yosys(['-s', r'$ScriptPath']))"
& $PythonCommand "-c" $SynthesisCode
exit $LASTEXITCODE
