#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$DIR"

echo "=== Running Rules Suite (test_runner.gd) ==="
godot --headless --path Godot/ --script res://tests/test_runner.gd

echo "=== Running UI & Turn Smoke Suite (ui_smoke.gd) ==="
godot --headless --path Godot/ --script res://tests/ui_smoke.gd

echo "=== All Spiritbound Headless Tests Passed! ==="
