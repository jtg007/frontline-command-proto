#!/usr/bin/env bash
# Writes build_stamp.json (Build-ID shown in the watermark, handshake and F8 reports).
# Build-ID = b<commit count>-<short sha>[-dirty]
set -euo pipefail
cd "$(dirname "$0")/.."
count="$(git rev-list --count HEAD 2>/dev/null || echo 0)"
sha="$(git rev-parse --short HEAD 2>/dev/null || echo nogit)"
dirty=""
if [ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ]; then dirty="-dirty"; fi
id="b${count}-${sha}${dirty}"
printf '{"build_id": "%s", "commit": "%s", "built_at": "%s"}\n' "$id" "$sha" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > build_stamp.json
echo "$id"
