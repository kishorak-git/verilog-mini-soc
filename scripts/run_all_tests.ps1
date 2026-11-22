param(
    [switch]$NegativeControl
)

$ErrorActionPreference = "Continue"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$IverilogCommand = Get-Command "iverilog.exe" -ErrorAction SilentlyContinue
if (-not $IverilogCommand) {
    throw "Icarus Verilog executable 'iverilog.exe' was not found on PATH"
}
$VvpCommand = Get-Command "vvp.exe" -ErrorAction SilentlyContinue
if (-not $VvpCommand) {
    throw "Icarus Verilog executable 'vvp.exe' was not found on PATH"
}
$Iverilog = $IverilogCommand.Source
$Vvp = $VvpCommand.Source

if ($NegativeControl) {
    $OutputDir = Join-Path $ProjectRoot "simulation"
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir | Out-Null
    }
    $NegativeVvp = Join-Path $OutputDir "negative_control_test.vvp"
    $NegativeLog = Join-Path $OutputDir "negative_control_results.txt"
    $NegativeArguments = @("-g2012","-Wall","-s","negative_control_tb","-o",$NegativeVvp,(Join-Path $ProjectRoot "testbench\negative_control_tb.v"))
    $CompileOutput = @(& $Iverilog $NegativeArguments 2>&1)
    $CompileExitCode = $LASTEXITCODE
    if ($CompileExitCode -ne 0) {
        $CompileOutput | Out-File -FilePath $NegativeLog -Encoding ASCII
        Write-Host "NEGATIVE CONTROL FAILED: negative-control testbench did not compile"
        exit 1
    }
    $SimulationOutput = @(& $Vvp $NegativeVvp 2>&1)
    $SimulationText = ($SimulationOutput -join "`r`n")
    $SimulationOutput | Out-File -FilePath $NegativeLog -Encoding ASCII
    if ($SimulationText -match "FAIL:") {
        Write-Host "NEGATIVE CONTROL VERIFIED: runner detected expected FAIL output"
        exit 1
    }
    Write-Host "NEGATIVE CONTROL FAILED: expected failure was not detected"
    exit 1
}

$OutputDir = Join-Path $ProjectRoot "simulation"
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$ConsolidatedReport = Join-Path $OutputDir "results.txt"
$ReportLines = New-Object System.Collections.Generic.List[string]
$ReportLines.Add("MINI SOC AUTOMATED VERIFICATION")
$ReportLines.Add(("Run timestamp: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss")))
$ReportLines.Add("")

$Suites = @(
    @{
        Name = "GPIO"
        Top = "gpio_tb"
        RTL = @("rtl\gpio.v")
        TB = "testbench\gpio_tb.v"
    },
    @{
        Name = "RAM"
        Top = "ram_tb"
        RTL = @("rtl\ram.v")
        TB = "testbench\ram_tb.v"
    },
    @{
        Name = "Timer"
        Top = "timer_tb"
        RTL = @("rtl\timer.v")
        TB = "testbench\timer_tb.v"
    },
    @{
        Name = "UART"
        Top = "uart_tb"
        RTL = @("rtl\uart.v")
        TB = "testbench\uart_tb.v"
    },
    @{
        Name = "SPI"
        Top = "spi_tb"
        RTL = @("rtl\spi.v")
        TB = "testbench\spi_tb.v"
    },
    @{
        Name = "Full Mini SoC"
        Top = "mini_soc_tb"
        RTL = @("rtl\mini_soc.v","rtl\ram.v","rtl\gpio.v","rtl\timer.v","rtl\uart.v","rtl\spi.v")
        TB = "testbench\mini_soc_tb.v"
    }
)

$FailedSuites = 0
$TotalChecks = 0
$TotalErrors = 0

foreach ($Suite in $Suites) {
    $Name = $Suite.Name
    $LogName = $Name.ToLower().Replace(" ", "_") + "_results.txt"
    $VvpName = $Suite.Top + ".vvp"
    $LogFile = Join-Path $OutputDir $LogName
    $VvpFile = Join-Path $OutputDir $VvpName

    $ReportLines.Add(("======== " + $Name + " ========"))
    Write-Host ("Compiling " + $Name + "...")

    $Arguments = @("-g2012","-Wall","-s",$Suite.Top,"-o",$VvpFile)
    foreach ($RtlFile in $Suite.RTL) {
        $Arguments += (Join-Path $ProjectRoot $RtlFile)
    }
    $Arguments += (Join-Path $ProjectRoot $Suite.TB)

    $CompileOutput = @(& $Iverilog $Arguments 2>&1)
    $CompileExitCode = $LASTEXITCODE
    if ($CompileExitCode -ne 0) {
        $CompileOutput | ForEach-Object { Write-Host $_ }
        $ReportLines.Add("COMPILATION FAILED")
        $FailedSuites++
        $ReportLines.Add("")
        continue
    }

    $ReportLines.Add("COMPILATION PASSED")
    Write-Host ("Running " + $Name + "...")

    $SimulationOutput = @(& $Vvp $VvpFile 2>&1 | Tee-Object -FilePath $LogFile)
    $SimulationExitCode = $LASTEXITCODE
    $SimulationText = ($SimulationOutput -join "`r`n")

    $AssertionFailure = (
        $SimulationText -match "(FAIL:|TEST: FAILED|TESTS FAILED|ERRORS:\s*[1-9][0-9]*|ALL TESTS FAILED)"
    )

    if ($SimulationExitCode -ne 0 -or $AssertionFailure) {
        $ReportLines.Add("SIMULATION FAILED")
        $FailedSuites++
    } else {
        $ReportLines.Add("SIMULATION PASSED")
    }

    foreach ($Line in $SimulationOutput) {
        $ReportLines.Add([string]$Line)
    }

    $CheckMatches = [regex]::Matches($SimulationText, "(?i)(?:CHECKS?:|Checks:)\s*(\d+)")
    if ($CheckMatches.Count -gt 0) {
        $SuiteChecks = [int]$CheckMatches[$CheckMatches.Count - 1].Groups[1].Value
        $TotalChecks += $SuiteChecks
    }

    $ErrorMatches = [regex]::Matches($SimulationText, "(?i)(?:ERRORS?:|Errors:)\s*(\d+)")
    if ($ErrorMatches.Count -gt 0) {
        $SuiteErrors = [int]$ErrorMatches[$ErrorMatches.Count - 1].Groups[1].Value
        $TotalErrors += $SuiteErrors
    } elseif ($AssertionFailure) {
        $TotalErrors++
    }

    $ReportLines.Add("")
}

$ReportLines.Add("VERIFICATION SUMMARY")
$ReportLines.Add(("Suites failed: " + $FailedSuites))
$ReportLines.Add(("Total checks: " + $TotalChecks))
$ReportLines.Add(("Total errors: " + $TotalErrors))

if ($FailedSuites -eq 0 -and $TotalErrors -eq 0) {
    $ReportLines.Add("MINI SOC AUTOMATED REGRESSION: ALL PASSED")
    $OverallResult = 0
} else {
    $ReportLines.Add("MINI SOC AUTOMATED REGRESSION: FAILED")
    $OverallResult = 1
}

[System.IO.File]::WriteAllLines(
    $ConsolidatedReport,
    $ReportLines,
    (New-Object System.Text.UTF8Encoding($false))
)

Write-Host ""
Write-Host ("Suites failed: " + $FailedSuites)
Write-Host ("Total checks: " + $TotalChecks)
Write-Host ("Total errors: " + $TotalErrors)
Write-Host ("Consolidated report: " + $ConsolidatedReport)

exit $OverallResult
