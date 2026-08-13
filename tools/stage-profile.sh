#!/usr/bin/env bash
# Stage a complete archiso profile: the live-only configuration in iso/ plus the
# executables and libraries from src/.
#
# Nothing under iso/airootfs is a copy of something in src/. Executables live in
# one place and are installed into the profile at build time, so the two can
# never drift.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${1:?usage: stage-profile.sh <destination>}"

rm -rf "$DEST"
mkdir -p "$DEST"
cp -a "$ROOT_DIR/iso/." "$DEST/"

bin="$DEST/airootfs/usr/bin"
lib="$DEST/airootfs/usr/share/nulllinux/lib"
installer="$DEST/airootfs/usr/share/nulllinux/installer"

install -Dm755 "$ROOT_DIR/src/installer/null-install"                "$bin/null-install"
install -Dm755 "$ROOT_DIR/src/tools/null-toolkit/null-toolkit"       "$bin/null-toolkit"
install -Dm755 "$ROOT_DIR/src/tools/null-setup/null-setup"           "$bin/null-setup"
install -Dm755 "$ROOT_DIR/src/tools/null-setup/null-setup-firstrun"  "$bin/null-setup-firstrun"
install -Dm755 "$ROOT_DIR/src/tools/null-setup/null-apply-branding"  "$bin/null-apply-branding"
install -Dm755 "$ROOT_DIR/src/tools/null-repo/null-repo"             "$bin/null-repo"

install -dm755 "$lib"
install -Dm644 "$ROOT_DIR"/src/lib/*.sh -t "$lib/"

install -Dm755 "$ROOT_DIR/src/installer/postinstall.sh" "$installer/postinstall.sh"

# The desktop entry that launches the wizard lives with the wizard.
install -Dm644 "$ROOT_DIR/src/tools/null-setup/null-setup.desktop" \
  "$DEST/airootfs/usr/share/applications/null-setup.desktop"
install -Dm644 "$ROOT_DIR/src/tools/null-setup/null-setup-autostart.desktop" \
  "$DEST/airootfs/etc/skel/.config/autostart/null-setup.desktop"

printf 'staged profile: %s\n' "$DEST"
