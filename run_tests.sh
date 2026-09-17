#!/usr/bin/env bash
set -e

# ==============================================================================
# Spiritbound Automated Test & Verification Suite
# ==============================================================================
# Usage:
#   ./run_tests.sh                 # Run unit tests + UI smoke + E2E playthrough
#   ./run_tests.sh --snapshots     # Run all tests + generate mobile visual screenshots
#   ./run_tests.sh --only-e2e      # Run only the E2E campaign playthrough bot
#   ./run_tests.sh --only-snapshots # Run only the visual snapshot tool
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
GEN_SNAPSHOTS=false

for arg in "$@"; do
    case "$arg" in
        --snapshots)
            GEN_SNAPSHOTS=true
            ;;
        --only-e2e)
            RUN_UNIT=false
            RUN_SMOKE=false
            RUN_E2E=true
            GEN_SNAPSHOTS=false
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
    echo -e "\n${YELLOW}[1/3] Running Unit & Integration Tests (tests/test_runner.gd)...${NC}"
    godot --headless --path "${GODOT_DIR}" -s tests/test_runner.gd
    echo -e "${GREEN}✓ Unit & Integration tests passed!${NC}"
fi

# 2. UI Smoke & Interaction Suite
if [ "$RUN_SMOKE" = true ]; then
    echo -e "\n${YELLOW}[2/3] Running UI Smoke & Interaction Tests (tests/ui_smoke.gd)...${NC}"
    godot --headless --path "${GODOT_DIR}" -s tests/ui_smoke.gd
    echo -e "${GREEN}✓ UI Smoke & Interaction tests passed!${NC}"
fi

# 3. E2E Campaign Playthrough Bot
if [ "$RUN_E2E" = true ]; then
    echo -e "\n${YELLOW}[3/3] Running E2E Campaign Playthrough Bot (tests/e2e_playthrough.gd)...${NC}"
    godot --headless --path "${GODOT_DIR}" -s tests/e2e_playthrough.gd
    echo -e "${GREEN}✓ E2E Campaign Playthrough passed without softlocks!${NC}"
fi

# 4. Mobile Visual Snapshots (Optional or Flagged)
if [ "$GEN_SNAPSHOTS" = true ]; then
    echo -e "\n${YELLOW}[+] Capturing Mobile Visual Snapshots (390x844)...${NC}"
    godot --path "${GODOT_DIR}" --rendering-driver opengl3 -s tests/visual_snapshots.gd
    echo -e "${GREEN}✓ All 7 mobile visual snapshots generated in Godot/tests/snapshots/${NC}"
    ls -lh "${GODOT_DIR}/tests/snapshots/"
fi

echo -e "\n${GREEN}========================================================${NC}"
echo -e "${GREEN}   🎉 ALL SELECTED SPIRITBOUND TESTS PASSED CLEANLY!    ${NC}"
echo -e "${GREEN}========================================================${NC}\n"
