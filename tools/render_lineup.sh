#!/usr/bin/env bash
# Consistent test scene of every weapon, first-person + third-person at the same angle/FOV/lighting:
#   tools/render_lineup.sh <out dir under screenshots/> [model...]   (no models = all; RENDER_DIR=abs folder of .glb for another set)
set -euo pipefail
cd "$(dirname "$0")/.."
out=$1; shift
if [ $# -eq 0 ]; then set -- $(ls addons/arena_weapons/assets/models/*.glb | xargs -n1 basename | sed 's/\.glb$//'); fi
xvfb-run -a -s "-screen 0 1280x720x24" timeout 900 godot --path . --resolution 960x540 --script tools/weapon_lineup.gd -- "$out" "$@" 2>&1 | grep -E "RESULT|MISSING|ERROR|SCRIPT" | head -80
