#!/usr/bin/env bash
# One-command dedicated server start (Linux x86_64). Needs one open UDP port.
#   ./start_server.sh                 # UDP 27515
#   PORT=28000 ./start_server.sh
# Bug-report copies and logs land in ~/.local/share/godot/app_userdata/Frontline Command Proto/
set -euo pipefail
cd "$(dirname "$0")"
PORT="${PORT:-27515}"
MAX_PLAYERS="${MAX_PLAYERS:-32}"
exec ./FrontlineCommand.x86_64 --headless -- --server --port="$PORT" --max-players="$MAX_PLAYERS" "$@"
