#!/usr/bin/env bash
# Rebuilds the textures of the named models in place from their pristine sources:
#   tools/tex_pipeline.sh <src dir with the original <name>.glb> <work dir> <size> <samples> <name>...
# Needs blender 4.3 and a python with numpy, scipy and PIL. Source GLBs: `git show <main>:addons/arena_weapons/assets/models/<name>.glb`.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
srcd=$1 work=$2 size=$3 samples=$4; shift 4
py=${PYTHON:-python3}
for n in "$@"; do
	AW_MODE=${AW_MODE:-orig} blender -b -P "$here/tools/tex_bake.py" -- "$srcd/$n.glb" "$work/$n" "$size" "$samples" > "$work/$n.bake.log" 2>&1 || { echo "BAKE FAILED $n"; tail -5 "$work/$n.bake.log"; continue; }
	"$py" -I "$here/tools/tex_gen.py" "$srcd/$n.glb" "$work/$n" "$here/addons/arena_weapons/assets/models/$n.glb" ${AW_DEBUG:+--debug}
done
