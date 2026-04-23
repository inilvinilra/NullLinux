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

OVMF_CODE="${OVMF_CODE:-/usr/share/edk2/x64/OVMF_CODE.4m.fd}"
if [[ ! -f "$OVMF_CODE" ]]; then
  echo "Warning: OVMF firmware not found at $OVMF_CODE (UEFI testing unavailable)"
fi

for keyring in blackarch chaotic; do
  if ! pacman-key --list-keys "${keyring}" >/dev/null 2>&1; then
    echo "Warning: ${keyring} keyring not found (install before building)"
  fi
done

if command -v rate-mirrors >/dev/null 2>&1; then
  echo "rate-mirrors: available"
else
  echo "Note: rate-mirrors not found (optional, for faster builds)"
fi

if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

echo "Host looks ready."
