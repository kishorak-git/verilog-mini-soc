# Verification and Test Coverage

## Verification scope

The project uses Icarus Verilog and VVP to compile and execute standalone peripheral testbenches and a full Mini SoC integration testbench. The regression is simulation-based RTL verification; it is not formal verification or physical FPGA validation.

## Latest recorded regression summary

The repository's consolidated report, `simulation/results.txt`, records six suites, 48 checks, and zero reported errors.

| Suite | Checks | Errors | Main areas exercised |
|---|---:|---:|---|
| GPIO | 3 | 0 | Output register, input register, deselected output |
| RAM | 4 | 0 | Multiple word addresses and deselected output |
| Timer | 3 | 0 | Period register, counting, disabled behavior |
| UART | 16 | 0 | Baud divider, loopback, receive-ready status, external RX bytes, framing error, short glitch, busy-start handling |
| SPI | 7 | 0 | Divider, transfer completion, status clear, master receive, slave receive |
| Full Mini SoC | 15 | 0 | Integrated RAM, GPIO, timer, UART, SPI, invalid-address response |
| **Total** | **48** | **0** | **Six test suites** |

## Selected coverage details

### GPIO
- Write and read the output register.
- Sample and read the input register.
- Verify deselected output behavior.

### RAM
- Read/write multiple locations, including first and last words in the mapped region.
- Verify deselected output behavior.

### Timer
- Program the period.
- Verify counter operation while enabled.
- Verify disabled behavior.

### UART
- Program the baud divider.
- Exercise loopback receive and ASCII data.
- Verify receive-ready set and clear behavior, including consecutive status reads.
- Exercise external receive values `00`, `FF`, `55`, `AA`, and `41`, plus a deterministic random byte.
- Verify framing-error detection and clearing.
- Verify a short input glitch does not create a receive event.
- Verify a start request while busy preserves the current byte.

### SPI
- Program the divider and complete transfers.
- Verify transfer-done status and clearing behavior.
- Verify master-received and slave-received data values.

### Full Mini SoC
- Exercise RAM, GPIO, timer, UART, and SPI through the integrated top-level.
- Verify an invalid address returns zero.

## Reproducing the regression

### Windows

Install Icarus Verilog with both `iverilog.exe` and `vvp.exe` available on PATH, then run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_all_tests.ps1
```

The consolidated report is written to `simulation\results.txt`.

### Linux

With Icarus Verilog installed:

```bash
bash scripts/run_all.sh
```

## Continuous integration

The repository contains two GitHub Actions workflows:

- [Windows Icarus Verilog regression](../.github/workflows/verilog-regression.yml)
- [Linux simulation and synthesis](../.github/workflows/ci.yml)

The recorded successful runs supplied for this verification milestone:

- [Windows workflow run](https://github.com/kishorak-git/verilog-mini-soc/actions/runs/44997589419)
- [Linux workflow run](https://github.com/kishorak-git/verilog-mini-soc/actions/runs/44997589437)

A passing CI run demonstrates that the workflow completed successfully for that commit. The badges in the README display the latest status on the default branch.

## Evidence and limitations

- The detailed local regression output is committed as [`simulation/results.txt`](../simulation/results.txt).
- The 48-check total is taken from that recorded report.
- CI workflow status links above are the run records associated with the reported verification milestone.
- These tests do not establish formal correctness, complete protocol compliance, FPGA timing closure, or successful operation on physical hardware.
