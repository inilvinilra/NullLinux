#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="$ROOT_DIR/iso/airootfs/usr/share/null-welcome/catalog.yml"
WELCOME_INSTALLER="$ROOT_DIR/iso/airootfs/usr/local/bin/null-welcome-install"
TOOLS_MENU="$ROOT_DIR/iso/airootfs/usr/local/bin/null-tools-menu"

echo "[1/5] Host requirements check"
bash "$ROOT_DIR/scripts/check-host.sh"

echo "[2/5] Null Welcome catalog validation"
python "$ROOT_DIR/scripts/null-welcome-validate.py" --catalog "$CATALOG"

echo "[3/5] Null Welcome group and action listing"
bash "$WELCOME_INSTALLER" --catalog "$CATALOG" --list-groups >/dev/null
bash "$WELCOME_INSTALLER" --catalog "$CATALOG" --list-actions security-hardening >/dev/null

echo "[4/5] Null Welcome dry-run install flow"
bash "$WELCOME_INSTALLER" --catalog "$CATALOG" --group development-build >/dev/null
bash "$WELCOME_INSTALLER" --catalog "$CATALOG" --item exploitation-post:Metasploit >/dev/null

echo "[5/5] Category menu output check"
bash "$TOOLS_MENU" all >/dev/null

echo "Smoke test passed."
