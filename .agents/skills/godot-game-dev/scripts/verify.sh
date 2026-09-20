#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$DIR"

# Delegates to the repo's own canonical suite runner rather than keeping a second, shorter list
# of suites here — an earlier version of this script only ran test_runner.gd + ui_smoke.gd
# directly, silently skipping e2e_playthrough, balance_probe, and the GUT suite entirely, which
# both AGENTS.md's own verification rule and every suite's own test coverage assume ran. See
# AGENTS.md's "Verifying a change" section for what `./run_tests.sh` actually covers.
./run_tests.sh
