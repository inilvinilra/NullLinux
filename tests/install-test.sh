#!/usr/bin/env bash
# Install Null Linux to a disposable disk image, then boot the result.
#
# The target is a file-backed loop device created and destroyed by this script.
# It never touches a physical disk: the installer independently refuses any
# device backing a mounted filesystem, and this script refuses to run against
# anything that is not the loop device it created.
#
# Requires root (partitioning, pacstrap) and roughly 6 GB of downloads.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${NULL_TEST_OUT:-/var/tmp/nulllinux-installtest}"
IMAGE="$OUT_DIR/target.raw"
SIZE_GB="${NULL_TEST_SIZE_GB:-24}"
TARGET_MNT="$OUT_DIR/mnt"
BOOT_SECONDS="${NULL_BOOT_SECONDS:-180}"

OVMF_CODE="${OVMF_CODE:-/usr/share/edk2/x64/OVMF_CODE.4m.fd}"
OVMF_VARS_SRC="${OVMF_VARS:-/usr/share/edk2/x64/OVMF_VARS.4m.fd}"

LOOP=""
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

cleanup() {
  umount -R "$TARGET_MNT" 2>/dev/null || true
  [[ -n "$LOOP" ]] && losetup -d "$LOOP" 2>/dev/null
}
trap cleanup EXIT

[[ ${EUID} -eq 0 ]] || die "must run as root (it partitions a loop device and runs pacstrap)"
[[ -d /sys/firmware/efi/efivars ]] || die "the installer requires UEFI; this host booted in BIOS mode"
for cmd in losetup pacstrap arch-chroot qemu-system-x86_64 qemu-img; do
  command -v "$cmd" >/dev/null || die "missing dependency: $cmd"
done

# A kernel upgrade replaces the running kernel's module tree, so loop cannot be
# loaded until the machine reboots. Say that instead of failing on a bare ENOENT.
if [[ ! -e /dev/loop0 ]] && ! modprobe loop 2>/dev/null; then
  if [[ ! -d "/lib/modules/$(uname -r)" ]]; then
    die "the running kernel $(uname -r) has no module tree left on disk
  (an upgrade replaced it). Reboot before running this test."
  fi
  die "the loop driver is unavailable; this test needs it to create a target disk"
fi

mkdir -p "$OUT_DIR" "$TARGET_MNT"
rm -f "$IMAGE"
truncate -s "${SIZE_GB}G" "$IMAGE"

LOOP="$(losetup --find --show --partscan "$IMAGE")" || die "could not attach a loop device"
[[ "$LOOP" == /dev/loop* ]] || die "unexpected loop device: $LOOP"
printf 'Target: %s (%s, %sG)\n' "$LOOP" "$IMAGE" "$SIZE_GB"

ANSWERS="$OUT_DIR/answers"
umask 077
cat > "$ANSWERS" <<EOF
disk=$LOOP
confirm_destroy_device=$LOOP
hostname=nulltest
username=tester
timezone=UTC
user_password=$(head -c 18 /dev/urandom | base64 | tr -d '/+=')
third_party_repos=false
EOF

printf '\n=== running the installer unattended ===\n'
NULL_TARGET="$TARGET_MNT" \
NULL_LIB_DIR="$ROOT_DIR/src/lib" \
NULL_SHARE_DIR="$ROOT_DIR/iso/airootfs/usr/share/nulllinux/installer" \
  "$ROOT_DIR/src/installer/null-install" --unattended "$ANSWERS"
install_status=$?
rm -f "$ANSWERS"

[[ $install_status -eq 0 ]] || die "installer exited with status $install_status"

printf '\n=== verifying the installed image ===\n'
mount "${LOOP}p2" "$TARGET_MNT" || die "cannot mount the installed root"
mount "${LOOP}p1" "$TARGET_MNT/boot" || die "cannot mount the installed ESP"

problems=()
grep -q '^ID=nulllinux' "$TARGET_MNT/etc/os-release" || problems+=("os-release is not Null Linux")
grep -q '^tester:' "$TARGET_MNT/etc/passwd" || problems+=("user missing")
[[ -e "$TARGET_MNT/boot/vmlinuz-linux" ]] || problems+=("kernel missing")
[[ -e "$TARGET_MNT/boot/initramfs-linux.img" ]] || problems+=("initramfs missing")
[[ -e "$TARGET_MNT/boot/loader/entries/null-linux.conf" ]] || problems+=("boot entry missing")
[[ -e "$TARGET_MNT/boot/EFI/BOOT/BOOTX64.EFI" || -e "$TARGET_MNT/boot/EFI/systemd/systemd-bootx64.efi" ]] \
  || problems+=("no EFI boot loader installed")
[[ -f "$TARGET_MNT/etc/sudoers.d/01-wheel" ]] || problems+=("sudo policy missing")
[[ -f "$TARGET_MNT/usr/bin/null-toolkit" ]] || problems+=("role manager missing")
[[ -d "$TARGET_MNT/usr/share/nulllinux/roles" ]] || problems+=("role data missing")
[[ -f "$TARGET_MNT/etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc" ]] \
  || problems+=("KDE panel layout missing")

# Live-only behaviour must never reach an installed system.
[[ -e "$TARGET_MNT/etc/sudoers.d/10-null" ]] && problems+=("live passwordless sudo leaked")
grep -rq '^\[Autologin\]' "$TARGET_MNT/etc/sddm.conf.d/" 2>/dev/null && problems+=("live autologin leaked")

# Only the detected CPU's microcode should be referenced.
if grep -q 'intel-ucode' "$TARGET_MNT/boot/loader/entries/null-linux.conf" \
   && grep -q 'amd-ucode' "$TARGET_MNT/boot/loader/entries/null-linux.conf"; then
  problems+=("both microcode images referenced")
fi

umount -R "$TARGET_MNT"

if [[ ${#problems[@]} -gt 0 ]]; then
  printf 'INSTALLED IMAGE FAILED VERIFICATION:\n'
  printf '  - %s\n' "${problems[@]}"
  exit 1
fi
printf 'installed image passed %d checks\n' 12

losetup -d "$LOOP"; LOOP=""

printf '\n=== booting the installed disk (no installation medium attached) ===\n'
VARS="$OUT_DIR/OVMF_VARS.fd"
cp -f "$OVMF_VARS_SRC" "$VARS"
MONITOR="$OUT_DIR/monitor.sock"
SHOT="$OUT_DIR/screen.ppm"
PNG="$OUT_DIR/installed-boot.png"
rm -f "$MONITOR" "$SHOT" "$PNG"

ACCEL=(-machine "type=q35")
[[ -w /dev/kvm ]] && ACCEL=(-machine "type=q35,accel=kvm" -cpu host)

qemu-system-x86_64 \
  "${ACCEL[@]}" -m "${NULL_TEST_RAM:-3072}" -smp 2 \
  -drive "if=pflash,format=raw,unit=0,readonly=on,file=$OVMF_CODE" \
  -drive "if=pflash,format=raw,unit=1,file=$VARS" \
  -drive "file=$IMAGE,format=raw,if=virtio" \
  -display none -vga std \
  -serial "file:$OUT_DIR/serial.log" \
  -monitor "unix:$MONITOR,server,nowait" \
  -daemonize -pidfile "$OUT_DIR/qemu.pid" || die "QEMU failed to start"

pid="$(cat "$OUT_DIR/qemu.pid")"
elapsed=0
while [[ $elapsed -lt $BOOT_SECONDS ]]; do
  kill -0 "$pid" 2>/dev/null || die "the installed system did not stay running (${elapsed}s)"
  sleep 5
  elapsed=$((elapsed + 5))
done

printf 'screendump %s\n' "$SHOT" | socat - "unix-connect:$MONITOR" >/dev/null 2>&1 || true
sleep 3
kill "$pid" 2>/dev/null

[[ -s "$SHOT" ]] || die "no framebuffer captured from the installed system"
if command -v magick >/dev/null 2>&1; then magick "$SHOT" "$PNG" && rm -f "$SHOT"; else PNG="$SHOT"; fi

printf '\nInstall test finished.\n'
printf '  screenshot: %s\n' "$PNG"
printf '  A successful result shows SDDM asking for the tester password.\n'
