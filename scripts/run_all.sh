#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/simulation"
mkdir -p "$OUTPUT_DIR"

if [[ "${1:-}" == "--negative-control" ]]; then
    LOG="$OUTPUT_DIR/negative_control_results.txt"
    iverilog -g2012 -Wall -s negative_control_tb -o "$OUTPUT_DIR/negative_control_test.vvp" \
        "$ROOT_DIR/testbench/negative_control_tb.v" | tee "$LOG"
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit 1
    fi

    vvp "$OUTPUT_DIR/negative_control_test.vvp" 2>&1 | tee -a "$LOG"
    SIM_STATUS=${PIPESTATUS[0]}
    if grep -q "FAIL:" "$LOG"; then
        echo "NEGATIVE CONTROL VERIFIED: runner detects FAIL output"
        exit 1
    fi
    if [[ $SIM_STATUS -ne 0 ]]; then
        echo "NEGATIVE CONTROL VERIFIED: runner detects non-zero simulation exit"
        exit 1
    fi
    echo "NEGATIVE CONTROL FAILED: expected failure was not detected"
    exit 1
fi

declare -a TEST_NAMES=("GPIO" "RAM" "Timer" "UART" "SPI" "Full Mini SoC")
declare -a TEST_TOPS=("gpio_tb" "ram_tb" "timer_tb" "uart_tb" "spi_tb" "mini_soc_tb")
declare -a TEST_MARKERS=("GPIO TEST: ALL PASSED" "RAM TEST: ALL PASSED" "TIMER TEST: ALL PASSED" "UART TEST: ALL PASSED" "SPI TEST: ALL PASSED" "MINI SOC: ALL TESTS PASSED")

CONSOLIDATED_REPORT="$OUTPUT_DIR/results.txt"
{
    echo "MINI SOC AUTOMATED VERIFICATION"
    echo "Run timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
} > "$CONSOLIDATED_REPORT"

FAILURES=0
TOTAL_CHECKS=0
TOTAL_ERRORS=0

run_test() {
    local name="$1"
    local top="$2"
    local marker="$3"
    local rtl_files="$4"
    local tb="$5"
    local safe_name="${name,,}"
    safe_name="${safe_name// /_}"
    local vvp="$OUTPUT_DIR/${safe_name}_test.vvp"
    local log="$OUTPUT_DIR/${safe_name}_linux_results.txt"

    echo "======== $name ========" | tee "$log"
    echo "======== $name ========" >> "$CONSOLIDATED_REPORT"
    read -r -a rtl_array <<< "$rtl_files"
    iverilog -g2012 -Wall -s "$top" -o "$vvp" "${rtl_array[@]}" "$ROOT_DIR/$tb" 2>&1 | tee -a "$log"
    local compile_status=${PIPESTATUS[0]}
    if [[ $compile_status -ne 0 ]]; then
        echo "COMPILATION FAILED: $name" | tee -a "$log"
        echo "COMPILATION FAILED" >> "$CONSOLIDATED_REPORT"
        cat "$log" >> "$CONSOLIDATED_REPORT"
        echo "" >> "$CONSOLIDATED_REPORT"
        ((FAILURES+=1))
        return
    fi

    vvp "$vvp" 2>&1 | tee -a "$log"
    local sim_status=${PIPESTATUS[0]}
    if [[ $sim_status -ne 0 ]]; then
        echo "SIMULATION FAILED: $name" | tee -a "$log"
        echo "SIMULATION FAILED" >> "$CONSOLIDATED_REPORT"
        cat "$log" >> "$CONSOLIDATED_REPORT"
        echo "" >> "$CONSOLIDATED_REPORT"
        ((FAILURES+=1))
        return
    fi
    if grep -q "FAIL:" "$log"; then
        echo "SIMULATION FAILED: $name contains FAIL output" | tee -a "$log"
        echo "SIMULATION FAILED" >> "$CONSOLIDATED_REPORT"
        cat "$log" >> "$CONSOLIDATED_REPORT"
        echo "" >> "$CONSOLIDATED_REPORT"
        ((FAILURES+=1))
        return
    fi
    if ! grep -q "$marker" "$log"; then
        echo "SIMULATION FAILED: $name missing success marker $marker" | tee -a "$log"
        echo "SIMULATION FAILED: missing success marker" >> "$CONSOLIDATED_REPORT"
        cat "$log" >> "$CONSOLIDATED_REPORT"
        echo "" >> "$CONSOLIDATED_REPORT"
        ((FAILURES+=1))
        return
    fi
    echo "SIMULATION PASSED: $name" | tee -a "$log"
    echo "SIMULATION PASSED" >> "$CONSOLIDATED_REPORT"

    SUITE_CHECKS=$(grep -Eio '(CHECKS|Checks):[[:space:]]*[0-9]+|Checks:[[:space:]]*[0-9]+|CHECKS:[[:space:]]*[0-9]+' "$log" | tail -n 1 | grep -Eo '[0-9]+$' || true)
    SUITE_ERRORS=$(grep -Eio '(ERRORS|Errors):[[:space:]]*[0-9]+|Errors:[[:space:]]*[0-9]+|ERRORS:[[:space:]]*[0-9]+' "$log" | tail -n 1 | grep -Eo '[0-9]+$' || true)
    if [[ -n "$SUITE_CHECKS" ]]; then
        TOTAL_CHECKS=$((TOTAL_CHECKS + SUITE_CHECKS))
    fi
    if [[ -n "$SUITE_ERRORS" ]]; then
        TOTAL_ERRORS=$((TOTAL_ERRORS + SUITE_ERRORS))
    fi

    cat "$log" >> "$CONSOLIDATED_REPORT"
    echo "" >> "$CONSOLIDATED_REPORT"
}

run_test "GPIO" "gpio_tb" "GPIO TEST: ALL PASSED" "$ROOT_DIR/rtl/gpio.v" "testbench/gpio_tb.v"
run_test "RAM" "ram_tb" "RAM TEST: ALL PASSED" "$ROOT_DIR/rtl/ram.v" "testbench/ram_tb.v"
run_test "Timer" "timer_tb" "TIMER TEST: ALL PASSED" "$ROOT_DIR/rtl/timer.v" "testbench/timer_tb.v"
run_test "UART" "uart_tb" "UART TEST: ALL PASSED" "$ROOT_DIR/rtl/uart.v" "testbench/uart_tb.v"
run_test "SPI" "spi_tb" "SPI TEST: ALL PASSED" "$ROOT_DIR/rtl/spi.v" "testbench/spi_tb.v"
run_test "Full Mini SoC" "mini_soc_tb" "MINI SOC: ALL TESTS PASSED" "$ROOT_DIR/rtl/mini_soc.v $ROOT_DIR/rtl/ram.v $ROOT_DIR/rtl/gpio.v $ROOT_DIR/rtl/timer.v $ROOT_DIR/rtl/uart.v $ROOT_DIR/rtl/spi.v" "testbench/mini_soc_tb.v"

if [[ $FAILURES -ne 0 ]]; then
    echo "LINUX REGRESSION FAILED: $FAILURES suite(s)"
    {
        echo "VERIFICATION SUMMARY"
        echo "Suites failed: $FAILURES"
        echo "Total checks: $TOTAL_CHECKS"
        echo "Total errors: $TOTAL_ERRORS"
        echo "LINUX REGRESSION: FAILED"
    } >> "$CONSOLIDATED_REPORT"
    exit 1
fi

echo "LINUX REGRESSION: ALL PASSED"
{
    echo "VERIFICATION SUMMARY"
    echo "Suites failed: 0"
    echo "Total checks: $TOTAL_CHECKS"
    echo "Total errors: $TOTAL_ERRORS"
    echo "LINUX REGRESSION: ALL PASSED"
} >> "$CONSOLIDATED_REPORT"
