#!/usr/bin/env bash
# Usage: ./scripts/prepare.sh [output_dir]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${1:-build/upstream}"
[[ "$DEST" = /* ]] || DEST="$ROOT/$DEST"
readarray -t PIN < <(python3 - "$ROOT/version.json" <<'PY'
import json, sys
v = json.load(open(sys.argv[1]))
for key in ("upstream_repo", "upstream_ref", "upstream_commit", "gcem_commit"):
    print(v[key])
PY
)
echo "Preparing ${PIN[0]} @ ${PIN[1]} (${PIN[2]})"
mkdir -p "$(dirname "$DEST")"
rm -rf -- "$DEST"
git clone --depth 1 --branch "${PIN[1]}" "${PIN[0]}" "$DEST"
actual="$(git -C "$DEST" rev-parse HEAD)"
[[ "$actual" = "${PIN[2]}" ]] || { echo "Upstream commit mismatch: $actual" >&2; exit 1; }
git -C "$DEST" submodule update --init --depth 1 gcem
actual="$(git -C "$DEST/gcem" rev-parse HEAD)"
[[ "$actual" = "${PIN[3]}" ]] || { echo "GCEM commit mismatch: $actual" >&2; exit 1; }
echo "Verified FluidSynth and GCEM commits in $DEST"
