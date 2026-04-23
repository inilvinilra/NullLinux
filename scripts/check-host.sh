#!/usr/bin/env bash
set -euo pipefail

missing=0

for cmd in mkarchiso qemu-system-x86_64 xorriso mksquashfs; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing: $cmd"
    missing=1
  fi
done

if [[ ! -e /usr/share/syslinux/bios/ldlinux.c32 ]] && [[ ! -e /usr/lib/syslinux/bios/ldlinux.c32 ]]; then
  echo "Missing: syslinux BIOS modules"
  missing=1
fi

if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

echo "Host looks ready."
