#!/bin/bash
# Publishes this pack. Every addon except arena_weapons is host-owned (dot-server-deploy/addons.lock names arena-weapons too, so it is filtered out of the list).
#   DOT_SITE=https://tmcdev.net tools/publish.sh VERSION --lock /tmp/aw-lock.json --token-file ~/.config/dot/creator-token-dev [--dry-run]
# Give --lock a file outside the repo: content.lock.json here pins the art store, not this pack.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
V=${1:?usage: tools/publish.sh VERSION [publish_pack.sh flags]}; shift
HOSTS="$(mktemp)"; trap 'rm -f "$HOSTS"' EXIT
grep -v '^[[:space:]]*#' "$HERE/../dot-server-deploy/addons.lock" | cut -f1 | grep -vx arena-weapons > "$HOSTS"
"$HERE/../dot-cloud/tools/publish_pack.sh" publish --source "$HERE" --id arena-weapons --version "$V" --host-addons "$HOSTS" "$@"
