#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="$ROOT_DIR/iso/airootfs/opt/nullwelcome"
BIN_NAME="nullwelcome"

usage() {
  cat <<'EOF'
Usage:
  scripts/integrate-nullwelcome.sh --from-local <path-to-nullwelcome-repo>
  scripts/integrate-nullwelcome.sh --from-binary <path-to-nullwelcome-binary>

This script stages NullWelcome into the ISO profile at:
  iso/airootfs/opt/nullwelcome/nullwelcome
EOF
}

copy_binary() {
  local src="$1"
  mkdir -p "$TARGET_DIR"
  cp "$src" "$TARGET_DIR/$BIN_NAME"
  chmod 0755 "$TARGET_DIR/$BIN_NAME"
  echo "Staged: $TARGET_DIR/$BIN_NAME"
}

MODE=""
VALUE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-local|--from-binary)
      MODE="$1"
      VALUE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$MODE" || -z "$VALUE" ]]; then
  usage
  exit 1
fi

case "$MODE" in
  --from-local)
    if [[ ! -d "$VALUE" ]]; then
      echo "Local repo path not found: $VALUE" >&2
      exit 1
    fi
    cargo build --release --manifest-path "$VALUE/Cargo.toml"
    copy_binary "$VALUE/target/release/$BIN_NAME"
    ;;
  --from-binary)
    if [[ ! -x "$VALUE" ]]; then
      echo "Binary not found or not executable: $VALUE" >&2
      exit 1
    fi
    copy_binary "$VALUE"
    ;;
esac
