#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_DIR="$ROOT_DIR/iso"
WORK_DIR="$ROOT_DIR/work"
OUT_DIR="$ROOT_DIR/out"
CLEAN_WORK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      echo "Usage: $0 [--clean-work]"
      exit 0
      ;;
    --clean-work)
      CLEAN_WORK=1
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--clean-work]" >&2
      exit 1
      ;;
  esac
done

if ! command -v mkarchiso >/dev/null 2>&1; then
  echo "mkarchiso not found. Install archiso first." >&2
  exit 1
fi

if [[ ! -d "$PROFILE_DIR" ]]; then
  echo "ISO profile directory not found: $PROFILE_DIR" >&2
  exit 1
fi

mkdir -p "$WORK_DIR" "$OUT_DIR"

if [[ "$CLEAN_WORK" -eq 1 ]]; then
  rm -rf "$WORK_DIR"
  mkdir -p "$WORK_DIR"
fi

if [[ "${EUID}" -ne 0 ]]; then
  exec sudo mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"
fi

mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"
