#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_DIR="$ROOT_DIR/iso"
WORK_DIR="$ROOT_DIR/work"
OUT_DIR="$ROOT_DIR/out"

if ! command -v mkarchiso >/dev/null 2>&1; then
  echo "mkarchiso not found. Install archiso first." >&2
  exit 1
fi

mkdir -p "$WORK_DIR" "$OUT_DIR"

optimize_mirrors() {
  if ! command -v rate-mirrors >/dev/null 2>&1; then
    echo "rate-mirrors not found, skipping mirror optimization."
    return 0
  fi

  echo "Optimizing Arch mirrors..."
  rate-mirrors --allow-root --save /etc/pacman.d/mirrorlist arch || true

  if [[ -f /etc/pacman.d/blackarch-mirrorlist ]]; then
    echo "Optimizing BlackArch mirrors..."
    rate-mirrors --allow-root --save /etc/pacman.d/blackarch-mirrorlist blackarch || true
  fi

  if [[ -f /etc/pacman.d/chaotic-mirrorlist ]]; then
    echo "Optimizing Chaotic-AUR mirrors..."
    rate-mirrors --allow-root --save /etc/pacman.d/chaotic-mirrorlist chaotic-aur || true
  fi
}

if [[ "${EUID}" -ne 0 ]]; then
  echo "Re-running as root..."
  exec sudo bash "$0" "$@"
fi

optimize_mirrors

echo "Building ISO..."
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

ISO_FILE="$(find "$OUT_DIR" -maxdepth 1 -name '*.iso' -type f | sort | tail -n 1)"
if [[ -n "$ISO_FILE" ]]; then
  echo "Generating checksums..."
  sha256sum "$ISO_FILE" > "$ISO_FILE.sha256"
  echo "Build complete: $ISO_FILE"
fi
