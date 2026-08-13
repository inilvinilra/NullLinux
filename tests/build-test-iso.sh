#!/usr/bin/env bash
# Build a throwaway ISO that can install itself unattended, for testing only.
#
# The release profile is copied, not modified. The overlay adds a service that
# installs to a disk named in an answers file and then powers off. That service
# is guarded by a kernel command line flag which only this image's boot entries
# set, and it must never be added to the release profile: an ISO that wipes a
# disk because of a boot parameter is a hazard, not a feature.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${NULL_TEST_PROFILE:-/var/tmp/nulllinux-testprofile}"
WORK="${NULL_TEST_WORK:-/var/tmp/nulllinux-testwork}"
OUT="${NULL_TEST_ISO_OUT:-/var/tmp/nulllinux-testout}"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ ${EUID} -eq 0 ]] || die "mkarchiso needs root: sudo $0"
command -v mkarchiso >/dev/null || die "mkarchiso not found (pacman -S archiso)"

rm -rf "$PROFILE" "$WORK" "$OUT"
mkdir -p "$PROFILE" "$OUT"
cp -a "$ROOT_DIR/iso/." "$PROFILE/"
cp -a "$ROOT_DIR/tests/testiso/airootfs/." "$PROFILE/airootfs/"

# Enable the service the way systemd would, without booting anything.
install -dm755 "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/nulllinux-autoinstall.service \
  "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants/nulllinux-autoinstall.service"

# Distinguish the artefact, and make the flag visible in every boot entry.
sed -i 's/^iso_name=.*/iso_name="null-linux-test"/' "$PROFILE/profiledef.sh"
sed -i 's/^iso_application=.*/iso_application="Null Linux TEST image - installs unattended"/' \
  "$PROFILE/profiledef.sh"
sed -i '/^file_permissions=(/a\  ["/usr/local/bin/nulllinux-autoinstall"]="0:0:755"' \
  "$PROFILE/profiledef.sh"

for entry in "$PROFILE/efiboot/loader/entries"/*.conf; do
  [[ -f "$entry" ]] || continue
  sed -i 's/^\(options .*\)$/\1 nulllinux.autoinstall systemd.unit=multi-user.target console=ttyS0,115200/' "$entry"
done
for cfg in "$PROFILE/syslinux"/*.cfg; do
  [[ -f "$cfg" ]] || continue
  sed -i 's/^\(\s*APPEND .*\)$/\1 nulllinux.autoinstall systemd.unit=multi-user.target console=ttyS0,115200/' "$cfg"
done

bash -n "$PROFILE/profiledef.sh" || die "patched profiledef.sh does not parse"

printf 'Building the TEST image from %s\n' "$PROFILE"
mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE"

ISO="$(find "$OUT" -maxdepth 1 -name '*.iso' -type f | head -1)"
[[ -n "$ISO" ]] || die "no test ISO produced"
printf '\nTest image: %s\n' "$ISO"
printf 'This image installs unattended when booted. Do not distribute it.\n'
