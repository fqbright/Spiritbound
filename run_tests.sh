#!/usr/bin/env bash
set -e

# ==============================================================================
# Spiritbound Automated Test & Verification Suite
# ==============================================================================
# Usage:
#   ./run_tests.sh                 # Run core suites (unit + ui_smoke + e2e_playthrough + balance + gut)
#   ./run_tests.sh --all           # Run EVERYTHING (core + monkey + leaks + diff)
#   ./run_tests.sh --monkey        # Run Chaos Monkey stress tests
#   ./run_tests.sh --leaks         # Run Memory & Object leak profiler
#   ./run_tests.sh --diff          # Run Visual Pixel-Diff baseline comparison
#   ./run_tests.sh --balance       # Run only the 250-stage balance trajectory bot (full)
#   ./run_tests.sh --balance-quick # Run the same bot retry-capped (fast, for CI)
#   ./run_tests.sh --gut           # Run only the GUT suite (tests/gut/test_*.gd)
#   ./run_tests.sh --snapshots     # Generate/refresh 390x844 mobile screenshots
#   ./run_tests.sh --only-e2e      # Run only the E2E campaign playthrough bot
# ==============================================================================

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT_DIR="${REPO_DIR}/Godot"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================================${NC}"
echo -e "${BLUE}   SPIRITBOUND AUTOMATED TEST SUITE                     ${NC}"
echo -e "${BLUE}========================================================${NC}"

RUN_UNIT=true
RUN_SMOKE=true
RUN_E2E=true
RUN_BALANCE=true
RUN_GUT=true
RUN_MONKEY=false
RUN_LEAKS=false
RUN_DIFF=false
BALANCE_QUICK=false
GEN_SNAPSHOTS=false

for arg in "$@"; do
    case "$arg" in
        --all)
            RUN_UNIT=true
            RUN_SMOKE=true
            RUN_E2E=true
            RUN_BALANCE=true
            RUN_GUT=true
            RUN_MONKEY=true
            RUN_LEAKS=true
            RUN_DIFF=true
            ;;
        --monkey)
            RUN_UNIT=false
            RUN_SMOKE=false
            RUN_E2E=false
            RUN_BALANCE=false
            RUN_GUT=false
            RUN_MONKEY=true
            ;;
        --leaks)
            RUN_UNIT=false
            RUN_SMOKE=false
            RUN_E2E=false
            RUN_BALANCE=false
            RUN_GUT=false
            RUN_LEAKS=true
            ;;
        --diff)
            RUN_UNIT=false
            RUN_SMOKE=false
            RUN_E2E=false
            RUN_BALANCE=false
            RUN_GUT=false
            RUN_DIFF=true
            ;;
        --balance)
            RUN_UNIT=false
            RUN_SMOKE=false
            RUN_E2E=false
            RUN_GUT=false
            RUN_BALANCE=true
            ;;
        --balance-quick)
            RUN_UNIT=false
            RUN_SMOKE=false
            RUN_E2E=false
            RUN_GUT=false
            RUN_BALANCE=true
            BALANCE_QUICK=true
            ;;
        --gut)
            RUN_UNIT=false
            RUN_SMOKE=false
            RUN_E2E=false
            RUN_BALANCE=false
            RUN_GUT=true
            ;;
        --snapshots)
            GEN_SNAPSHOTS=true
            ;;
        --only-e2e)
            RUN_UNIT=false
            RUN_SMOKE=false
            RUN_E2E=true
            RUN_BALANCE=false
            RUN_GUT=false
            ;;
        --only-snapshots)
            RUN_UNIT=false
            RUN_SMOKE=false
            RUN_E2E=false
            RUN_BALANCE=false
            RUN_GUT=false
            GEN_SNAPSHOTS=true
            ;;
        *)
            ;;
    esac
done

# 1. Unit & Integration Test Suite
if [ "$RUN_UNIT" = true ]; then
    echo -e "\n${YELLOW}[1/8] Running Unit & Integration Tests (tests/test_runner.gd)...${NC}"
    godot --headless --path "${GODOT_DIR}" -s tests/test_runner.gd
    echo -e "${GREEN}✓ Unit & Integration tests passed!${NC}"
fi

# 2. UI Smoke & Interaction Suite
if [ "$RUN_SMOKE" = true ]; then
    echo -e "\n${YELLOW}[2/8] Running UI Smoke & Interaction Tests (tests/ui_smoke.gd)...${NC}"
    godot --headless --path "${GODOT_DIR}" -s tests/ui_smoke.gd
    echo -e "${GREEN}✓ UI Smoke & Interaction tests passed!${NC}"
fi

# 3. E2E Campaign Playthrough Bot
if [ "$RUN_E2E" = true ]; then
    echo -e "\n${YELLOW}[3/8] Running E2E Campaign Playthrough Bot (tests/e2e_playthrough.gd)...${NC}"
    godot --headless --path "${GODOT_DIR}" -s tests/e2e_playthrough.gd
    echo -e "${GREEN}✓ E2E Campaign Playthrough passed without softlocks!${NC}"
fi

# 4. 250-Stage Balance Trajectory Bot
if [ "$RUN_BALANCE" = true ]; then
    if [ "$BALANCE_QUICK" = true ]; then
        echo -e "\n${YELLOW}[4/8] Running 250-Stage Balance Trajectory Bot, quick (tests/balance_probe.gd --quick)...${NC}"
        godot --headless --path "${GODOT_DIR}" -s tests/balance_probe.gd -- --quick
    else
        echo -e "\n${YELLOW}[4/8] Running 250-Stage Balance Trajectory Bot, full (tests/balance_probe.gd)...${NC}"
        godot --headless --path "${GODOT_DIR}" -s tests/balance_probe.gd
    fi
    echo -e "${GREEN}✓ Balance trajectory holds its four-band curve!${NC}"
fi

# 5. GUT (Godot Unit Test) Suite
if [ "$RUN_GUT" = true ]; then
    echo -e "\n${YELLOW}[5/8] Running GUT Test Suite (tests/gut/test_*.gd)...${NC}"
    # GUT's own -gexit always exits 0 regardless of pass/fail (confirmed empirically against
    # this exact GUT version — it's meant for closing an interactive runner window, not
    # reporting CI status), so this checks stdout for GUT's own "All tests passed!" success
    # banner instead of trusting the process exit code, and fails the build explicitly when
    # it's absent. Also emits a JUnit XML report so CI can show which test failed, not just a
    # stdout dump.
    GUT_LOG="$(mktemp)"
    godot --headless --path "${GODOT_DIR}" -s addons/gut/gut_cmdln.gd -- \
        -gdir=res://tests/gut -gexit -gdisable_colors \
        -gjunit_xml_file=res://tests/gut/results.xml 2>&1 | tee "${GUT_LOG}"
    if grep -q "All tests passed!" "${GUT_LOG}"; then
        echo -e "${GREEN}✓ GUT test suite passed!${NC}"
        rm -f "${GUT_LOG}"
    else
        echo -e "${RED}✗ GUT test suite FAILED${NC}"
        rm -f "${GUT_LOG}"
        exit 1
    fi
fi

# 6. Chaos Monkey Stress Testing
if [ "$RUN_MONKEY" = true ]; then
    echo -e "\n${YELLOW}[6/8] Running Chaos Monkey Stress Tests (tests/chaos_monkey.gd)...${NC}"
    godot --headless --path "${GODOT_DIR}" -s tests/chaos_monkey.gd
    echo -e "${GREEN}✓ Chaos Monkey survived without crashes!${NC}"
fi

# 7. Memory & ObjectDB Leak Profiler
if [ "$RUN_LEAKS" = true ]; then
    echo -e "\n${YELLOW}[7/8] Running Memory & Object Leak Profiler (tests/leak_checker.gd)...${NC}"
    godot --headless --path "${GODOT_DIR}" -s tests/leak_checker.gd
    echo -e "${GREEN}✓ Leak Profiler confirmed zero unbounded leaks!${NC}"
fi

# 8. Visual Pixel-Diff Comparison
if [ "$RUN_DIFF" = true ]; then
    echo -e "\n${YELLOW}[8/8] Running Visual Pixel-Diff Comparison (tests/pixel_diff_test.gd)...${NC}"
    godot --headless --path "${GODOT_DIR}" -s tests/pixel_diff_test.gd
    echo -e "${GREEN}✓ Pixel-Diff verified all screens match baselines!${NC}"
fi

# Mobile Visual Snapshots (optional; not part of --all)
if [ "$GEN_SNAPSHOTS" = true ]; then
    echo -e "\n${YELLOW}[+] Capturing Mobile Visual Snapshots (390x844)...${NC}"
    godot --path "${GODOT_DIR}" --rendering-driver opengl3 -s tests/visual_snapshots.gd
    echo -e "${GREEN}✓ All 7 mobile visual snapshots generated in Godot/tests/snapshots/${NC}"
    ls -lh "${GODOT_DIR}/tests/snapshots/"
fi

echo -e "\n${GREEN}========================================================${NC}"
echo -e "${GREEN}   🎉 ALL SELECTED SPIRITBOUND TESTS PASSED CLEANLY!    ${NC}"
echo -e "${GREEN}========================================================${NC}\n"
