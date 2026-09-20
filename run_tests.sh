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
#   ./run_tests.sh --diff          # Regenerate the 9 snapshots and diff them against baseline
#                                   #   (needs a real or Xvfb display — see the suite's own note)
#   ./run_tests.sh --balance       # Run only the 250-stage balance trajectory bot (full)
#   ./run_tests.sh --balance-quick # Run the same bot retry-capped (fast, for CI)
#   ./run_tests.sh --balance-gold  # Run the same bot gold-constrained (diagnostic, not gated)
#   ./run_tests.sh --gut           # Run only the GUT suite (tests/gut/test_*.gd)
#   ./run_tests.sh --snapshots     # Generate/refresh 390x844 mobile screenshots (no diff/gate)
#   ./run_tests.sh --refresh-baselines  # Recapture + promote to Pixel-Diff's committed baselines
#                                   #   (needs a real or Xvfb display) — do this deliberately after
#                                   #   a real, reviewed UI change, then review and commit the
#                                   #   changed Godot/tests/snapshots/baselines/*.png yourself
#   ./run_tests.sh --only-e2e      # Run only the E2E campaign playthrough bot
# ==============================================================================

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT_DIR="${REPO_DIR}/Godot"

# run_suite <label> <success-sentinel> <command...>
#
# Runs a Godot test script, shows its output, and -- this is the point -- decides pass/fail from
# what it printed rather than from the process exit code. Each of these suites is a Godot script
# invoked with `-s`; if one fails to *parse* (or dies before its first print), Godot still exits 0
# and a caller that only checked the status would report a pass. In practice this suite did
# exactly that: a parse error in test_runner.gd printed "🎉 ALL SELECTED SPIRITBOUND TESTS PASSED
# CLEANLY!" while the unit tests never ran at all. Anything that let a release gate go green
# without running is worth an explicit check.
#
# Fails on Godot script/parse errors, and fails when the sentinel is absent -- so a suite that
# silently skips (or was never wired up) counts as a failure, not a pass.
run_suite() {
    local label="$1"; shift
    local sentinel="$1"; shift
    local log; log="$(mktemp)"

    set +e
    "$@" 2>&1 | tee "${log}"
    local status="${PIPESTATUS[0]}"
    set -e

    if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script" "${log}"; then
        echo -e "${RED}✗ ${label} FAILED — the script did not run cleanly (see the errors above).${NC}"
        rm -f "${log}"
        exit 1
    fi
    if ! grep -qF "${sentinel}" "${log}"; then
        echo -e "${RED}✗ ${label} FAILED — never printed its success line (\"${sentinel}\").${NC}"
        echo -e "${RED}  Absence means the suite did not actually run to completion; treating that as a${NC}"
        echo -e "${RED}  pass is how a green build ships untested code.${NC}"
        rm -f "${log}"
        exit 1
    fi
    if [ "${status}" -ne 0 ]; then
        echo -e "${RED}✗ ${label} FAILED — exit status ${status} despite the success line.${NC}"
        rm -f "${log}"
        exit 1
    fi
    rm -f "${log}"
}

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
BALANCE_GOLD=false
GEN_SNAPSHOTS=false
REFRESH_BASELINES=false

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
        --balance-gold)
            RUN_UNIT=false
            RUN_SMOKE=false
            RUN_E2E=false
            RUN_GUT=false
            RUN_BALANCE=true
            BALANCE_GOLD=true
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
        --refresh-baselines)
            RUN_UNIT=false
            RUN_SMOKE=false
            RUN_E2E=false
            RUN_BALANCE=false
            RUN_GUT=false
            REFRESH_BASELINES=true
            ;;
        *)
            ;;
    esac
done

# Release-script version numbers (no Godot, no build, ~1s). Fails the run rather than warning --
# and it is wired in *before* the Godot suites because release_ios.sh itself refuses to build
# until this suite passes: a build number that only reaches an echo statement produces a valid
# archive with the wrong CFBundleVersion, which nothing else here would notice.
if [ "$RUN_UNIT" = true ]; then
    echo -e "\n${YELLOW}[build] Release-script version numbers (Tests/release_version_test.sh)...${NC}"
    bash "${REPO_DIR}/Tests/release_version_test.sh"
fi

# 1. Unit & Integration Test Suite
if [ "$RUN_UNIT" = true ]; then
    echo -e "\n${YELLOW}[1/8] Running Unit & Integration Tests (tests/test_runner.gd)...${NC}"
    run_suite "Unit & Integration tests" "SPIRITBOUND TESTS:" \
        godot --headless --path "${GODOT_DIR}" -s tests/test_runner.gd
    echo -e "${GREEN}✓ Unit & Integration tests passed!${NC}"
fi

# 2. UI Smoke & Interaction Suite
if [ "$RUN_SMOKE" = true ]; then
    echo -e "\n${YELLOW}[2/8] Running UI Smoke & Interaction Tests (tests/ui_smoke.gd)...${NC}"
    run_suite "UI Smoke & Interaction tests" "UI SMOKE: all checks passed" \
        godot --headless --path "${GODOT_DIR}" -s tests/ui_smoke.gd
    echo -e "${GREEN}✓ UI Smoke & Interaction tests passed!${NC}"
fi

# 3. E2E Campaign Playthrough Bot
if [ "$RUN_E2E" = true ]; then
    echo -e "\n${YELLOW}[3/8] Running E2E Campaign Playthrough Bot (tests/e2e_playthrough.gd)...${NC}"
    run_suite "E2E Campaign Playthrough" "E2E CAMPAIGN RUN: ALL CHECKS PASSED (0 FAILURES)" \
        godot --headless --path "${GODOT_DIR}" -s tests/e2e_playthrough.gd
    echo -e "${GREEN}✓ E2E Campaign Playthrough passed without softlocks!${NC}"
fi

# 4. 250-Stage Balance Trajectory Bot
if [ "$RUN_BALANCE" = true ]; then
    if [ "$BALANCE_GOLD" = true ]; then
        echo -e "\n${YELLOW}[4/8] Running 250-Stage Balance Trajectory Bot, gold-constrained (tests/balance_probe.gd --gold)...${NC}"
        echo -e "${YELLOW}  (diagnostic only — see Docs/BALANCE_REVALIDATION.md suggestion #1; not gated on depth yet)${NC}"
        run_suite "Balance trajectory (gold)" "BALANCE PROBE: CURVE HOLDS (0 FAILURES)" \
            godot --headless --path "${GODOT_DIR}" -s tests/balance_probe.gd -- --gold
    elif [ "$BALANCE_QUICK" = true ]; then
        echo -e "\n${YELLOW}[4/8] Running 250-Stage Balance Trajectory Bot, quick (tests/balance_probe.gd --quick)...${NC}"
        run_suite "Balance trajectory (quick)" "BALANCE PROBE: CURVE HOLDS (0 FAILURES)" \
            godot --headless --path "${GODOT_DIR}" -s tests/balance_probe.gd -- --quick
    else
        echo -e "\n${YELLOW}[4/8] Running 250-Stage Balance Trajectory Bot, full (tests/balance_probe.gd)...${NC}"
        run_suite "Balance trajectory" "BALANCE PROBE: CURVE HOLDS (0 FAILURES)" \
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
    run_suite "Chaos Monkey stress tests" "CHAOS & MONKEY TEST SUITE: ALL CHECKS PASSED (0 FAILURES)" \
        godot --headless --path "${GODOT_DIR}" -s tests/chaos_monkey.gd
    echo -e "${GREEN}✓ Chaos Monkey survived without crashes!${NC}"
fi

# 7. Memory & ObjectDB Leak Profiler
if [ "$RUN_LEAKS" = true ]; then
    echo -e "\n${YELLOW}[7/8] Running Memory & Object Leak Profiler (tests/leak_checker.gd)...${NC}"
    run_suite "Memory & object leak profiler" "LEAK PROFILER: ALL CHECKS PASSED (0 UNBOUNDED LEAKS)" \
        godot --headless --path "${GODOT_DIR}" -s tests/leak_checker.gd
    echo -e "${GREEN}✓ Leak Profiler confirmed zero unbounded leaks!${NC}"
fi

# 8. Visual Pixel-Diff Comparison
if [ "$RUN_DIFF" = true ]; then
    # pixel_diff_test.gd compares the committed baselines against a *current* capture of the
    # same 7 screens, so that capture has to happen first, every time this suite runs — a stale
    # or missing current snapshot means Test 3 silently skips every screen instead of actually
    # gating anything (this is exactly how it shipped for a long time: the diffing logic and
    # committed baselines were both real, but nothing ever generated a current snapshot in CI,
    # so the comparison never ran). Capturing needs a real rendering driver — get_image() on the
    # dummy driver --headless uses returns null — so unlike every other suite here this one runs
    # without --headless, against whatever DISPLAY is already set (a real one locally, or
    # Xvfb's virtual one in CI — see .github/workflows/ci.yml).
    echo -e "\n${YELLOW}[8/8] Running Visual Pixel-Diff Comparison (tests/visual_snapshots.gd + tests/pixel_diff_test.gd)...${NC}"
    if [ -z "$DISPLAY" ]; then
        echo -e "${RED}✗ No DISPLAY set — visual snapshot capture needs a real (or Xvfb virtual) display.${NC}"
        echo -e "${RED}  Locally: run under a real desktop session, or install xvfb and run e.g.${NC}"
        echo -e "${RED}  xvfb-run -a --server-args=\"-screen 0 400x900x24\" ./run_tests.sh --diff${NC}"
        echo -e "${RED}  The Xvfb screen must be at least as tall as the game's 390x844 viewport —${NC}"
        echo -e "${RED}  a shorter one silently misplaces bottom-anchored UI (see AGENTS.md).${NC}"
        exit 1
    fi
    godot --path "${GODOT_DIR}" --rendering-driver opengl3 -s tests/visual_snapshots.gd
    run_suite "Visual pixel-diff comparison" "DE-FLAKED PIXEL-DIFF SUITE: ALL CHECKS PASSED (0 FAILURES)" \
        godot --headless --path "${GODOT_DIR}" -s tests/pixel_diff_test.gd
    echo -e "${GREEN}✓ Pixel-Diff verified all screens match baselines!${NC}"
fi

# Mobile Visual Snapshots (optional; not part of --all)
if [ "$GEN_SNAPSHOTS" = true ]; then
    echo -e "\n${YELLOW}[+] Capturing Mobile Visual Snapshots (390x844)...${NC}"
    godot --path "${GODOT_DIR}" --rendering-driver opengl3 -s tests/visual_snapshots.gd
    echo -e "${GREEN}✓ All 9 mobile visual snapshots generated in Godot/tests/snapshots/${NC}"
    ls -lh "${GODOT_DIR}/tests/snapshots/"
fi

# Refresh Pixel-Diff Baselines (optional; not part of --all — a deliberate, reviewed action
# after an intentional UI change, never something to run reflexively just because the
# Pixel-Diff suite failed. If it failed, look at the saved diff images under
# Godot/tests/snapshots/diffs/ first and confirm the change is the one you meant to make.)
if [ "$REFRESH_BASELINES" = true ]; then
    echo -e "\n${YELLOW}Recapturing current snapshots and promoting them to baselines...${NC}"
    if [ -z "$DISPLAY" ]; then
        echo -e "${RED}✗ No DISPLAY set — see the Pixel-Diff suite's own note above.${NC}"
        exit 1
    fi
    godot --path "${GODOT_DIR}" --rendering-driver opengl3 -s tests/visual_snapshots.gd
    cp "${GODOT_DIR}/tests/snapshots/"*.png "${GODOT_DIR}/tests/snapshots/baselines/"
    echo -e "${GREEN}✓ Baselines updated from the current capture. Before committing:${NC}"
    echo -e "${GREEN}  1. godot --headless --path Godot/ --import   (refresh .import metadata)${NC}"
    echo -e "${GREEN}  2. ./run_tests.sh --diff                     (confirm it now passes)${NC}"
    echo -e "${GREEN}  3. Review the changed Godot/tests/snapshots/baselines/*.png yourself —${NC}"
    echo -e "${GREEN}     this step trusts that today's screens are correct, it doesn't check.${NC}"
fi

echo -e "\n${GREEN}========================================================${NC}"
echo -e "${GREEN}   🎉 ALL SELECTED SPIRITBOUND TESTS PASSED CLEANLY!    ${NC}"
echo -e "${GREEN}========================================================${NC}\n"
