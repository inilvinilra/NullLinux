#!/usr/bin/env bash
# Shared helpers for QEMU launcher scripts.
#
# Default: QXL + SDL — most stable in mixed host GPU stacks.
# Enable SPICE + vdagent channel for better dynamic resize behavior.
#
#   NULLLINUX_QEMU_VGA=qxl|virtio|virtio-gl
#   NULLLINUX_QEMU_DISPLAY=sdl|gtk
#   NULLLINUX_QEMU_NO_USB=1
#   NULLLINUX_QEMU_RAM=...   MB
#   NULLLINUX_QEMU_SMP=...   vCPUs

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd)"
# build-iso.sh relocates its output when the repository path contains
# whitespace, so look in both places before giving up.
OUT_DIR="${NULL_OUT_DIR:-$ROOT_DIR/out}"
ISO_PATH="${1:-$(find "$OUT_DIR" /var/tmp/nulllinux-out -maxdepth 1 -type f -name '*.iso' 2>/dev/null | sort | tail -n 1)}"
ACCEL_ARGS=()

if [[ -z "${ISO_PATH}" || ! -f "${ISO_PATH}" ]]; then
  echo "No ISO found. Build one first or pass the ISO path explicitly." >&2
  exit 1
fi

if [[ -e /dev/kvm && -r /dev/kvm ]]; then
  ACCEL_ARGS=(-enable-kvm -cpu host)
fi

TOTAL_RAM=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}' || echo 4096)
TOTAL_CORES=$(nproc 2>/dev/null || echo 4)
VM_RAM="${NULLLINUX_QEMU_RAM:-$(( TOTAL_RAM / 2 ))}"
VM_CORES="${NULLLINUX_QEMU_SMP:-$(( TOTAL_CORES / 2 ))}"
[[ $VM_RAM -lt 2048 ]] && VM_RAM=2048
[[ $VM_RAM -gt 8192 ]] && VM_RAM=8192
[[ $VM_CORES -lt 2 ]] && VM_CORES=2
[[ $VM_CORES -gt 8 ]] && VM_CORES=8

DISK_IMG="/tmp/nulllinux-test.qcow2"
if [[ ! -f "$DISK_IMG" ]]; then
  qemu-img create -f qcow2 "$DISK_IMG" 40G
fi

VGA_MODE="${NULLLINUX_QEMU_VGA:-qxl}"
QEMU_DISPLAY="${NULLLINUX_QEMU_DISPLAY:-sdl}"
declare -a DISPLAY_VGA=()

case "$VGA_MODE" in
  virtio-gl)
    DISPLAY_VGA=(-device virtio-vga-gl -display "${QEMU_DISPLAY},gl=on")
    echo "VGA: virtio-vga-gl (needs virGL; if no window, use: NULLLINUX_QEMU_VGA=qxl)" >&2
    ;;
  virtio)
    DISPLAY_VGA=(-device virtio-vga -display "$QEMU_DISPLAY")
    echo "VGA: virtio-vga" >&2
    ;;
  qxl|*)
    DISPLAY_VGA=(-vga qxl -display "$QEMU_DISPLAY")
    echo "VGA: qxl (default, reliable for NullLinux / KDE in VMs)" >&2
    ;;
esac

USB_ARGS=()
if [[ -z "${NULLLINUX_QEMU_NO_USB:-}" ]]; then
  USB_ARGS=(-usb -device usb-tablet)
fi

echo "VM: ${VM_RAM}MB RAM, ${VM_CORES} vCPUs, KVM=$([ ${#ACCEL_ARGS[@]} -gt 0 ] && echo yes || echo no)" >&2
echo "Display: $QEMU_DISPLAY  ISO: $ISO_PATH" >&2

# shellcheck disable=SC2034  # consumed by run-qemu-*.sh, which source this file
COMMON_QEMU_ARGS=(
  -m "$VM_RAM"
  -smp "${VM_CORES},sockets=1,cores=${VM_CORES},threads=1"
  "${ACCEL_ARGS[@]}"
  -drive "file=${DISK_IMG},format=qcow2,if=virtio,cache=writeback,discard=unmap"
  -cdrom "$ISO_PATH"
  -boot "order=cd,menu=on"
  "${DISPLAY_VGA[@]}"
  -spice "disable-ticketing=on"
  -device virtio-serial-pci
  -chardev "spicevmc,id=vdagent,name=vdagent"
  -device "virtserialport,chardev=vdagent,name=com.redhat.spice.0"
  -device "virtio-net-pci,netdev=n1"
  -netdev "user,id=n1"
  -device intel-hda -device hda-duplex
  "${USB_ARGS[@]}"
)
