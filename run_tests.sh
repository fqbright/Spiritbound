#!/usr/bin/env bash
set -e

# ==============================================================================
# Spiritbound Automated Test & Verification Suite
# ==============================================================================
# Usage:
#   ./run_tests.sh                 # Run core suites (unit + ui_smoke + e2e_playthrough)
#   ./run_tests.sh --all           # Run EVERYTHING (unit + ui_smoke + e2e + balance + monkey + leaks + diff)
#   ./run_tests.sh --monkey        # Run Chaos Monkey stress tests
#   ./run_tests.sh --leaks         # Run Memory & Object leak profiler
#   ./run_tests.sh --diff          # Run Visual Pixel-Diff baseline comparison
#   ./run_tests.sh --snapshots     # Generate/refresh 390x844 mobile screenshots
#   ./run_tests.sh --only-e2e      # Run only the E2E campaign playthrough bot
#   ./run_tests.sh --balance       # Run only the 250-stage balance trajectory bot (full)
#   ./run_tests.sh --balance-quick # Run the same bot retry-capped (fast, for CI)
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
RUN_MONKEY=false
RUN_LEAKS=false
RUN_DIFF=false
RUN_BALANCE=false
BALANCE_QUICK=false
GEN_SNAPSHOTS=false

for arg in "$@"; do
    case "$arg" in
        --all)
            RUN_UNIT=true
            RUN_SMOKE=true
            RUN_E2E=true
            RUN_MONKEY=true
            RUN_LEAKS=true
            RUN_DIFF=true
            RUN_BALANCE=true
            ;;
        --monkey)
            RUN_UNIT=false
            RUN_SMOKE=false
            RUN_E2E=false
            RUN_MONKEY=true
            ;;
        --leaks)
            RUN_UNIT=false
            RUN_SMOKE=false
            RUN_E2E=false
            RUN_LEAKS=true
            ;;
        --diff)
            RUN_UNIT=false
            RUN_SMOKE=false
            RUN_E2E=false
            RUN_DIFF=true
            ;;
        --snapshots)
            GEN_SNAPSHOTS=true
            ;;
        --only-e2e)
            RUN_UNIT=false
            RUN_SMOKE=false
            RUN_E2E=true
            ;;
        --balance)
            RUN_UNIT=false
            RUN_SMOKE=false
            RUN_E2E=false
            RUN_BALANCE=true
            ;;
        --balance-quick)
            RUN_UNIT=false
            RUN_SMOKE=false
            RUN_E2E=false
            RUN_BALANCE=true
            BALANCE_QUICK=true
            ;;
        --only-snapshots)
            RUN_UNIT=false
            RUN_SMOKE=false
            RUN_E2E=false
            GEN_SNAPSHOTS=true
            ;;
        *)
            ;;
    esac
done

# 1. Unit & Integration Test Suite
if [ "$RUN_UNIT" = true ]; then
    echo -e "\n${YELLOW}[1/7] Running Unit & Integration Tests (tests/test_runner.gd)...${NC}"
    godot --headless --path "${GODOT_DIR}" -s tests/test_runner.gd
    echo -e "${GREEN}✓ Unit & Integration tests passed!${NC}"
fi

# 2. UI Smoke & Interaction Suite
if [ "$RUN_SMOKE" = true ]; then
    echo -e "\n${YELLOW}[2/7] Running UI Smoke & Interaction Tests (tests/ui_smoke.gd)...${NC}"
    godot --headless --path "${GODOT_DIR}" -s tests/ui_smoke.gd
    echo -e "${GREEN}✓ UI Smoke & Interaction tests passed!${NC}"
fi

# 3. E2E Campaign Playthrough Bot
if [ "$RUN_E2E" = true ]; then
    echo -e "\n${YELLOW}[3/7] Running E2E Campaign Playthrough Bot (tests/e2e_playthrough.gd)...${NC}"
    godot --headless --path "${GODOT_DIR}" -s tests/e2e_playthrough.gd
    echo -e "${GREEN}✓ E2E Campaign Playthrough passed without softlocks!${NC}"
fi

# 4. 250-Stage Balance Trajectory Bot
if [ "$RUN_BALANCE" = true ]; then
    if [ "$BALANCE_QUICK" = true ]; then
        echo -e "\n${YELLOW}[4/7] Running 250-Stage Balance Trajectory Bot, quick (tests/balance_probe.gd --quick)...${NC}"
        godot --headless --path "${GODOT_DIR}" -s tests/balance_probe.gd -- --quick
    else
        echo -e "\n${YELLOW}[4/7] Running 250-Stage Balance Trajectory Bot, full (tests/balance_probe.gd)...${NC}"
        godot --headless --path "${GODOT_DIR}" -s tests/balance_probe.gd
    fi
    echo -e "${GREEN}✓ Balance trajectory holds its four-band curve!${NC}"
fi

# 5. Chaos Monkey Stress Testing
if [ "$RUN_MONKEY" = true ]; then
    echo -e "\n${YELLOW}[5/7] Running Chaos Monkey Stress Tests (tests/chaos_monkey.gd)...${NC}"
    godot --headless --path "${GODOT_DIR}" -s tests/chaos_monkey.gd
    echo -e "${GREEN}✓ Chaos Monkey survived without crashes!${NC}"
fi

# 6. Memory & ObjectDB Leak Profiler
if [ "$RUN_LEAKS" = true ]; then
    echo -e "\n${YELLOW}[6/7] Running Memory & Object Leak Profiler (tests/leak_checker.gd)...${NC}"
    godot --headless --path "${GODOT_DIR}" -s tests/leak_checker.gd
    echo -e "${GREEN}✓ Leak Profiler confirmed zero unbounded leaks!${NC}"
fi

# 7. Visual Pixel-Diff Comparison
if [ "$RUN_DIFF" = true ]; then
    echo -e "\n${YELLOW}[7/7] Running Visual Pixel-Diff Comparison (tests/pixel_diff_test.gd)...${NC}"
    godot --headless --path "${GODOT_DIR}" -s tests/pixel_diff_test.gd
    echo -e "${GREEN}✓ Pixel-Diff verified all screens match baselines!${NC}"
fi

# 8. Mobile Visual Snapshots (optional; not part of --all)
if [ "$GEN_SNAPSHOTS" = true ]; then
    echo -e "\n${YELLOW}[+] Capturing Mobile Visual Snapshots (390x844)...${NC}"
    godot --path "${GODOT_DIR}" --rendering-driver opengl3 -s tests/visual_snapshots.gd
    echo -e "${GREEN}✓ All 7 mobile visual snapshots generated in Godot/tests/snapshots/${NC}"
    ls -lh "${GODOT_DIR}/tests/snapshots/"
fi

echo -e "\n${GREEN}========================================================${NC}"
echo -e "${GREEN}   🎉 ALL SELECTED SPIRITBOUND TESTS PASSED CLEANLY!    ${NC}"
echo -e "${GREEN}========================================================${NC}\n"
