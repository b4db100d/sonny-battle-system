#!/usr/bin/env bash
# Single verification entry point: import the project headlessly and run the test suite.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/tools/setup_godot.sh"
GODOT="$ROOT/.godot-bin/godot"

echo "==> Importing project (headless)"
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true

echo "==> Running tests"
"$GODOT" --headless --path "$ROOT" -s res://tests/run_tests.gd
