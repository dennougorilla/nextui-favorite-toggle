#!/bin/sh
# Tests the pak and packages it into dist/. The pak is plain shell, nothing to compile.

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Probe instead of `command -v`: on Windows python3 can be a Microsoft Store stub that just fails
for PYTHON in python3 python; do "$PYTHON" -c "" 2>/dev/null && break; done

sh "$ROOT/tests/test.sh"
"$PYTHON" "$ROOT/scripts/package.py"
