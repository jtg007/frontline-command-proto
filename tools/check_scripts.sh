#!/usr/bin/env bash
# Strict static check of every GDScript file (warnings configured as errors in project.godot).
# Usage: tools/check_scripts.sh [godot-binary]
set -euo pipefail
GODOT="${1:-${GODOT:-godot}}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
fail=0
while IFS= read -r f; do
  out="$("$GODOT" --headless --path . --check-only -s "res://$f" 2>&1 | grep -E 'SCRIPT ERROR|Parse Error|WARNING|at: ' | grep -v 'ObjectDB' || true)"
  if [ -n "$out" ]; then
    echo "== $f"; echo "$out"; fail=1
  fi
done < <(find src tests tools -name '*.gd' | sort)
if [ "$fail" -ne 0 ]; then echo "Script check FAILED"; exit 1; fi
echo "Script check passed ($(find src tests tools -name '*.gd' | wc -l) files)"
