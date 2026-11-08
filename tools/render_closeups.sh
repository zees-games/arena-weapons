#!/usr/bin/env bash
# Close-up frames of models: tools/render_closeups.sh <out dir under screenshots/> <model>...   (RENDER_DIR=res:// or abs folder for another glb set)
set -euo pipefail
cd "$(dirname "$0")/.."
out=$1; shift
xvfb-run -a -s "-screen 0 1600x900x24" timeout 900 godot --path . --resolution 1600x900 --script tools/render_closeups.gd -- "$out" "$@" 2>&1 | grep -E "RESULT|MISSING|ERROR|SCRIPT" | head -80
