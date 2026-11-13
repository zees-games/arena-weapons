#!/usr/bin/env bash
# Contact sheet of each gun's fire: tools/render_kick.sh <out.png under the project> before|after|fx|tp [proc]  (see render_kick.gd)
set -euo pipefail
cd "$(dirname "$0")/.."
xvfb-run -a -s "-screen 0 960x540x24" timeout 600 godot --path . --resolution 960x540 --fixed-fps 60 --script tools/render_kick.gd -- "$1" "${2:-after}" "${3:-}" 2>&1 | grep -E "RESULT|ERROR|SCRIPT" | head -40
