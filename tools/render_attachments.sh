#!/usr/bin/env bash
# Contact sheet of fitted attachments in first and third person: tools/render_attachments.sh <out.png under the project> <gun>...  (see render_attachments.gd)
set -euo pipefail
cd "$(dirname "$0")/.."
out=$1; shift
xvfb-run -a -s "-screen 0 960x540x24" timeout 900 godot --path . --resolution 960x540 --script tools/render_attachments.gd -- "$out" "$@" 2>&1 | grep -E "RESULT|ERROR|SCRIPT" | head -60
