#!/usr/bin/env bash
# Builds the Playtest packages into dist/:
#   frontline-command-<build>-linux.zip     client (Linux x86_64)
#   frontline-command-<build>-windows.zip   client (Windows x86_64)
#   frontline-command-<build>-server-linux.zip  dedicated server + start_server.sh
#   SHA256SUMS.txt
# Usage: tools/package.sh [--server-address=host:port] [--godot=/path/to/godot]
# Needs Godot 4.7.x export templates installed (Editor → Manage Export Templates).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
ADDRESS=""
for a in "$@"; do
  case "$a" in
    --server-address=*) ADDRESS="${a#*=}" ;;
    --godot=*) GODOT="${a#*=}" ;;
    *) echo "unknown option $a"; exit 2 ;;
  esac
done

BUILD_ID="$(tools/stamp_build.sh)"
CFG_BACKUP="$(mktemp)"
cp config/default_server.cfg "$CFG_BACKUP"
restore() { cp "$CFG_BACKUP" config/default_server.cfg; rm -f "$CFG_BACKUP" build_stamp.json; }
trap restore EXIT
if [ -n "$ADDRESS" ]; then
  sed -i "s|^address=.*|address=\"$ADDRESS\"|" config/default_server.cfg
fi

rm -rf build dist
mkdir -p build/linux build/windows dist
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Linux" build/linux/FrontlineCommand.x86_64 2>&1 | grep -E "ERROR|WARNING" || true
"$GODOT" --headless --path . --export-release "Windows" build/windows/FrontlineCommand.exe 2>&1 | grep -E "ERROR|WARNING" || true
test -f build/linux/FrontlineCommand.x86_64 && test -f build/windows/FrontlineCommand.exe || { echo "export failed"; exit 1; }

name="frontline-command-${BUILD_ID}"
for platform in linux windows; do
  stage="build/stage/${name}-${platform}"
  mkdir -p "$stage"
  cp -r build/"$platform"/* "$stage"/
  cp docs/PLAYTEST_1.md "$stage/HOW_TO_PLAY.md"
  cp LICENSE "$stage/"
  (cd build/stage && python3 -m zipfile -c "../../dist/${name}-${platform}.zip" "${name}-${platform}")
done
stage="build/stage/${name}-server-linux"
mkdir -p "$stage"
cp build/linux/FrontlineCommand.x86_64 server/start_server.sh LICENSE "$stage"/
cp docs/HOSTING.md "$stage/HOSTING.md"
chmod +x "$stage/start_server.sh" "$stage/FrontlineCommand.x86_64"
(cd build/stage && python3 -m zipfile -c "../../dist/${name}-server-linux.zip" "${name}-server-linux")

(cd dist && sha256sum ./*.zip > SHA256SUMS.txt)
echo "Packaged build ${BUILD_ID}${ADDRESS:+ (join address $ADDRESS)}:"
ls -lh dist
