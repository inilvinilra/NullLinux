#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/out"
ISO_PATH="${1:-$(find "$OUT_DIR" -maxdepth 1 -type f -name '*.iso' | sort | tail -n 1)}"
OVMF_CODE="${OVMF_CODE:-/usr/share/edk2/x64/OVMF_CODE.4m.fd}"
OVMF_VARS_TEMPLATE="${OVMF_VARS_TEMPLATE:-/usr/share/edk2/x64/OVMF_VARS.4m.fd}"
OVMF_VARS="$ROOT_DIR/work/OVMF_VARS.fd"
ACCEL_ARGS=()

if [[ -z "${ISO_PATH}" || ! -f "${ISO_PATH}" ]]; then
  echo "No ISO found. Build one first or pass the ISO path explicitly." >&2
  exit 1
fi

if [[ ! -f "$OVMF_CODE" || ! -f "$OVMF_VARS_TEMPLATE" ]]; then
  echo "OVMF firmware not found." >&2
  exit 1
fi

if [[ -e /dev/kvm ]]; then
  ACCEL_ARGS=(-enable-kvm)
fi

mkdir -p "$ROOT_DIR/work"
cp -f "$OVMF_VARS_TEMPLATE" "$OVMF_VARS"

exec qemu-system-x86_64 \
  -m 4096 \
  -smp 4 \
  "${ACCEL_ARGS[@]}" \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
  -drive if=pflash,format=raw,file="$OVMF_VARS" \
  -cdrom "$ISO_PATH" \
  -boot d \
  -vga virtio \
  -display gtk,gl=on \
  -netdev user,id=n1 \
  -device virtio-net-pci,netdev=n1
