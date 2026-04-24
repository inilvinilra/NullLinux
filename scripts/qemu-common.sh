#!/usr/bin/env bash
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
  ACCEL_ARGS=(-enable-kvm -cpu host,+topoext)
fi

TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
TOTAL_CORES=$(nproc)
VM_RAM=$(( TOTAL_RAM / 2 ))
VM_CORES=$(( TOTAL_CORES / 2 ))
[[ $VM_RAM -lt 2048 ]] && VM_RAM=2048
[[ $VM_RAM -gt 8192 ]] && VM_RAM=8192
[[ $VM_CORES -lt 2 ]] && VM_CORES=2
[[ $VM_CORES -gt 8 ]] && VM_CORES=8

DISK_IMG="/tmp/nulllinux-test.qcow2"
if [[ ! -f "$DISK_IMG" ]]; then
  qemu-img create -f qcow2 "$DISK_IMG" 40G
fi

echo "VM: ${VM_RAM}MB RAM, ${VM_CORES} cores, KVM=$([ ${#ACCEL_ARGS[@]} -gt 0 ] && echo yes || echo no)"

COMMON_QEMU_ARGS=(
  -m "$VM_RAM"
  -smp "$VM_CORES",sockets=1,cores="$VM_CORES",threads=1
  "${ACCEL_ARGS[@]}"
  -cdrom "$ISO_PATH"
  -drive file="$DISK_IMG",format=qcow2,if=virtio,cache=writeback,discard=unmap
  -boot d
  -device virtio-vga-gl
  -display gtk,gl=on
  -device virtio-net-pci,netdev=n1
  -netdev user,id=n1
  -device intel-hda -device hda-duplex
  -usb -device usb-tablet
  -global ICH9-LPC.disable_s3=1
)
