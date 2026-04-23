#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_MENU="$ROOT_DIR/iso/airootfs/usr/local/bin/null-tools-menu"

echo "[1/3] Host requirements check"
bash "$ROOT_DIR/scripts/check-host.sh"

echo "[2/3] Build script option check"
bash "$ROOT_DIR/scripts/build-iso.sh" --help >/dev/null

echo "[3/3] Category menu output check"
bash "$TOOLS_MENU" all >/dev/null

echo "Smoke test passed."
