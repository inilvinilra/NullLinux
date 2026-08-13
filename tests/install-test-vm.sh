#!/usr/bin/env bash
# Install Null Linux inside a VM, then boot the installed disk on its own.
#
# Everything destructive happens inside QEMU against a virtual disk, so this
# needs no loop device and no privileged access to the host's block layer.
#
#   1. build a small answers disk
#   2. boot the TEST image with the target disk attached; it installs and powers off
#   3. boot the target disk with no installation medium and capture the screen
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${NULL_TEST_OUT:-/var/tmp/nulllinux-vmtest}"
TEST_ISO="${1:-$(find /var/tmp/nulllinux-testout -maxdepth 1 -name '*.iso' 2>/dev/null | head -1)}"
DISK_GB="${NULL_TEST_SIZE_GB:-24}"
RAM_MB="${NULL_TEST_RAM:-4096}"
INSTALL_TIMEOUT="${NULL_INSTALL_TIMEOUT:-2400}"
BOOT_SECONDS="${NULL_BOOT_SECONDS:-150}"

OVMF_CODE="${OVMF_CODE:-/usr/share/edk2/x64/OVMF_CODE.4m.fd}"
OVMF_VARS_SRC="${OVMF_VARS:-/usr/share/edk2/x64/OVMF_VARS.4m.fd}"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ -f "$TEST_ISO" ]] || die "test ISO not found; run: sudo ./tests/build-test-iso.sh"
for cmd in qemu-system-x86_64 qemu-img mkfs.vfat socat; do
  command -v "$cmd" >/dev/null || die "missing dependency: $cmd"
done
[[ -f "$OVMF_CODE" ]] || die "OVMF firmware not found at $OVMF_CODE"

mkdir -p "$OUT_DIR"
TARGET="$OUT_DIR/target.qcow2"
ANSWERS_IMG="$OUT_DIR/answers.img"
SERIAL="$OUT_DIR/install-serial.log"
VARS="$OUT_DIR/OVMF_VARS.fd"
rm -f "$TARGET" "$ANSWERS_IMG" "$SERIAL"

printf '=== preparing a %sG virtual target and an answers disk ===\n' "$DISK_GB"
qemu-img create -f qcow2 "$TARGET" "${DISK_GB}G" >/dev/null

# The guest sees a single virtio disk as /dev/vda.
password="$(head -c 18 /dev/urandom | base64 | tr -d '/+=')"
answers_dir="$(mktemp -d)"
cat > "$answers_dir/answers" <<EOF
disk=/dev/vda
confirm_destroy_device=/dev/vda
hostname=nulltest
username=tester
timezone=UTC
user_password=$password
third_party_repos=false
EOF
# Ship the working tree's tools alongside the answers so the run tests current
# code, not whatever was baked into the image.
mkdir -p "$answers_dir/bin" "$answers_dir/lib" "$answers_dir/installer"
install -m755 "$ROOT_DIR/src/installer/null-install"               "$answers_dir/bin/"
install -m755 "$ROOT_DIR/src/tools/null-toolkit/null-toolkit"      "$answers_dir/bin/"
install -m755 "$ROOT_DIR/src/tools/null-setup/null-setup"          "$answers_dir/bin/"
install -m755 "$ROOT_DIR/src/tools/null-setup/null-setup-firstrun" "$answers_dir/bin/"
install -m755 "$ROOT_DIR/src/tools/null-setup/null-apply-branding" "$answers_dir/bin/"
install -m755 "$ROOT_DIR/src/tools/null-repo/null-repo"            "$answers_dir/bin/"
install -m644 "$ROOT_DIR"/src/lib/*.sh                             "$answers_dir/lib/"
install -m755 "$ROOT_DIR/src/installer/postinstall.sh"             "$answers_dir/installer/"
install -m644 "$ROOT_DIR/iso/airootfs/usr/share/nulllinux/installer/os-release" \
              "$ROOT_DIR/iso/airootfs/usr/share/nulllinux/installer/sddm.conf" \
              "$answers_dir/installer/"

command -v mcopy >/dev/null || die "mtools is required (pacman -S mtools)"
truncate -s 32M "$ANSWERS_IMG"
mkfs.vfat -n NULLANSWERS "$ANSWERS_IMG" >/dev/null
mcopy -i "$ANSWERS_IMG" -s "$answers_dir"/* :: || die "could not write the answers disk"
rm -rf "$answers_dir"

ACCEL=(-machine "type=q35")
[[ -w /dev/kvm ]] && ACCEL=(-machine "type=q35,accel=kvm" -cpu host)
printf 'KVM: %s\n' "$([[ -w /dev/kvm ]] && echo enabled || echo unavailable)"

cp -f "$OVMF_VARS_SRC" "$VARS"

printf '\n=== installing inside the VM (this downloads a base system) ===\n'
qemu-system-x86_64 \
  "${ACCEL[@]}" -m "$RAM_MB" -smp "$(nproc)" \
  -drive "if=pflash,format=raw,unit=0,readonly=on,file=$OVMF_CODE" \
  -drive "if=pflash,format=raw,unit=1,file=$VARS" \
  -drive "file=$TARGET,format=qcow2,if=virtio" \
  -drive "file=$ANSWERS_IMG,format=raw,if=virtio" \
  -cdrom "$TEST_ISO" \
  -boot "order=d" \
  -netdev "user,id=n0" -device "virtio-net-pci,netdev=n0" \
  -display none \
  -serial "file:$SERIAL" \
  -daemonize -pidfile "$OUT_DIR/qemu.pid" || die "QEMU failed to start"

pid="$(cat "$OUT_DIR/qemu.pid")"
elapsed=0
result=""
while kill -0 "$pid" 2>/dev/null; do
  if [[ $elapsed -ge $INSTALL_TIMEOUT ]]; then
    kill "$pid" 2>/dev/null
    die "install timed out after ${INSTALL_TIMEOUT}s; see $SERIAL"
  fi
  sleep 10
  elapsed=$((elapsed + 10))
  if [[ $((elapsed % 60)) -eq 0 ]]; then
    printf '  %sm  %s\n' "$((elapsed / 60))" \
      "$(grep -o '###NULLTEST:[^#]*###' "$SERIAL" 2>/dev/null | tail -1)"
  fi
done

result="$(grep -o '###NULLTEST:[^#]*###' "$SERIAL" 2>/dev/null | tail -2 | tr '\n' ' ')"
printf '\nGuest finished after %ss. Markers: %s\n' "$elapsed" "${result:-none}"

grep -q '###NULLTEST:INSTALL_OK###' "$SERIAL" \
  || die "the installer did not report success. Serial log: $SERIAL"

printf '\n=== booting the installed disk, no installation medium attached ===\n'
cp -f "$OVMF_VARS_SRC" "$VARS"
MONITOR="$OUT_DIR/monitor.sock"
SHOT="$OUT_DIR/screen.ppm"
PNG="$OUT_DIR/installed-boot.png"
rm -f "$MONITOR" "$SHOT" "$PNG" "$OUT_DIR/boot-serial.log"

qemu-system-x86_64 \
  "${ACCEL[@]}" -m "$RAM_MB" -smp 2 \
  -drive "if=pflash,format=raw,unit=0,readonly=on,file=$OVMF_CODE" \
  -drive "if=pflash,format=raw,unit=1,file=$VARS" \
  -drive "file=$TARGET,format=qcow2,if=virtio" \
  -display none -vga std \
  -serial "file:$OUT_DIR/boot-serial.log" \
  -monitor "unix:$MONITOR,server,nowait" \
  -daemonize -pidfile "$OUT_DIR/qemu2.pid" || die "QEMU failed to start for the boot check"

pid="$(cat "$OUT_DIR/qemu2.pid")"
elapsed=0
while [[ $elapsed -lt $BOOT_SECONDS ]]; do
  kill -0 "$pid" 2>/dev/null || die "the installed system stopped after ${elapsed}s"
  sleep 5
  elapsed=$((elapsed + 5))
done

printf 'screendump %s\n' "$SHOT" | socat - "unix-connect:$MONITOR" >/dev/null 2>&1 || true
sleep 3
kill "$pid" 2>/dev/null
[[ -s "$SHOT" ]] || die "no framebuffer captured from the installed system"
command -v magick >/dev/null 2>&1 && { magick "$SHOT" "$PNG" && rm -f "$SHOT"; } || PNG="$SHOT"

printf '\nInstall test finished.\n'
printf '  install log: %s\n' "$SERIAL"
printf '  screenshot:  %s\n' "$PNG"
printf '  A successful result shows SDDM asking for the tester password.\n'
