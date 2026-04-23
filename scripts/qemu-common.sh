#!/usr/bin/env bash
# Shared helpers for QEMU launcher scripts.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/out"
ISO_PATH="${1:-$(find "$OUT_DIR" -maxdepth 1 -type f -name '*.iso' | sort | tail -n 1)}"
ACCEL_ARGS=()

if [[ -z "${ISO_PATH}" || ! -f "${ISO_PATH}" ]]; then
  echo "No ISO found. Build one first or pass the ISO path explicitly." >&2
  exit 1
fi

if [[ -e /dev/kvm ]]; then
  ACCEL_ARGS=(-enable-kvm)
fi

COMMON_QEMU_ARGS=(
  -m 4096
  -smp 4
  "${ACCEL_ARGS[@]}"
  -cdrom "$ISO_PATH"
  -boot d
  -vga virtio
  -display gtk,gl=on
  -netdev user,id=n1
  -device virtio-net-pci,netdev=n1
)
