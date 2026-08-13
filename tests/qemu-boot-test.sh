#!/usr/bin/env bash
# Automated live-boot test.
#
# Boots the ISO headless under OVMF, waits, and captures the framebuffer through
# the QEMU monitor. A screenshot is evidence; a zero exit status from QEMU is
# not, because QEMU exits cleanly whether or not the guest ever booted.
#
# Never point this at a real disk. It creates and destroys its own image.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISO_PATH="${1:-}"
OUT_DIR="${NULL_TEST_OUT:-/var/tmp/nulllinux-boottest}"
BOOT_SECONDS="${NULL_BOOT_SECONDS:-90}"
RAM_MB="${NULL_TEST_RAM:-3072}"

OVMF_CODE="${OVMF_CODE:-/usr/share/edk2/x64/OVMF_CODE.4m.fd}"
OVMF_VARS_SRC="${OVMF_VARS:-/usr/share/edk2/x64/OVMF_VARS.4m.fd}"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ -n "$ISO_PATH" ]] || ISO_PATH="$(find /var/tmp/nulllinux-out "$ROOT_DIR/out" -maxdepth 1 -name '*.iso' 2>/dev/null | head -1)"
[[ -f "$ISO_PATH" ]] || die "ISO not found. Pass its path as the first argument."
command -v qemu-system-x86_64 >/dev/null || die "qemu-system-x86_64 not installed (pacman -S qemu-system-x86)"
command -v qemu-img >/dev/null || die "qemu-img not installed (pacman -S qemu-img)"
[[ -f "$OVMF_CODE" ]] || die "OVMF firmware not found at $OVMF_CODE (pacman -S edk2-ovmf)"

mkdir -p "$OUT_DIR"
VARS="$OUT_DIR/OVMF_VARS.fd"
DISK="$OUT_DIR/target.qcow2"
SERIAL="$OUT_DIR/serial.log"
MONITOR="$OUT_DIR/monitor.sock"
SHOT="$OUT_DIR/screen.ppm"
PNG="$OUT_DIR/screen.png"

cp -f "$OVMF_VARS_SRC" "$VARS"
rm -f "$SERIAL" "$SHOT" "$PNG" "$MONITOR"
qemu-img create -f qcow2 "$DISK" 20G >/dev/null

ACCEL=(-machine "type=q35")
[[ -w /dev/kvm ]] && ACCEL=(-machine "type=q35,accel=kvm" -cpu host)

printf 'Booting %s headless for %ss...\n' "$(basename "$ISO_PATH")" "$BOOT_SECONDS"

qemu-system-x86_64 \
  "${ACCEL[@]}" \
  -m "$RAM_MB" -smp 2 \
  -drive "if=pflash,format=raw,unit=0,readonly=on,file=$OVMF_CODE" \
  -drive "if=pflash,format=raw,unit=1,file=$VARS" \
  -drive "file=$DISK,format=qcow2,if=virtio" \
  -cdrom "$ISO_PATH" \
  -boot "order=d" \
  -display none \
  -vga std \
  -serial "file:$SERIAL" \
  -monitor "unix:$MONITOR,server,nowait" \
  -daemonize \
  -pidfile "$OUT_DIR/qemu.pid" || die "QEMU failed to start"

pid="$(cat "$OUT_DIR/qemu.pid")"
cleanup() { kill "$pid" 2>/dev/null; }
trap cleanup EXIT

elapsed=0
while [[ $elapsed -lt $BOOT_SECONDS ]]; do
  kill -0 "$pid" 2>/dev/null || die "QEMU exited early after ${elapsed}s; guest never finished booting"
  sleep 5
  elapsed=$((elapsed + 5))
  printf '  %ss\n' "$elapsed"
done

printf 'Capturing framebuffer...\n'
printf 'screendump %s\n' "$SHOT" | socat - "unix-connect:$MONITOR" >/dev/null 2>&1 \
  || printf 'screendump %s\n' "$SHOT" | timeout 10 nc -U "$MONITOR" >/dev/null 2>&1 \
  || die "could not reach the QEMU monitor (install socat or openbsd-netcat)"

sleep 3
[[ -s "$SHOT" ]] || die "no framebuffer captured"

if command -v magick >/dev/null 2>&1; then
  magick "$SHOT" "$PNG" && rm -f "$SHOT"
elif command -v convert >/dev/null 2>&1; then
  convert "$SHOT" "$PNG" && rm -f "$SHOT"
else
  PNG="$SHOT"
fi

printf '\nBoot test finished.\n'
printf '  screenshot: %s\n' "$PNG"
printf '  serial log: %s (%s bytes)\n' "$SERIAL" "$(stat -c%s "$SERIAL" 2>/dev/null || echo 0)"
printf '\nInspect the screenshot: a successful live boot shows the Plasma desktop.\n'
