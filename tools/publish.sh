#!/bin/bash
# Publishes this pack with addons/arena_weapons, the code a host mounts from it as an overlay.
#   DOT_SITE=https://tmcdev.net tools/publish.sh VERSION --lock /tmp/aw-lock.json --token-file ~/.config/dot/creator-token-dev [--dry-run]
# Give --lock a file outside the repo: content.lock.json here pins the art store, not this pack.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
V=${1:?usage: tools/publish.sh VERSION [publish_pack.sh flags]}; shift
# Every addon folder but addons/arena_weapons stays out, by folder name, so a copy with links resolved (heavy's staging box) packs the same.
EX=(); for d in "$HERE"/addons/*/; do n="$(basename "$d")"; [ "$n" = arena_weapons ] || EX+=(--exclude-dir "$n"); done
"$HERE/../dot-cloud/tools/publish_pack.sh" publish --source "$HERE" --id arena-weapons --version "$V" "${EX[@]}" "$@"
