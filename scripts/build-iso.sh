#!/usr/bin/env bash
# Build the Null Linux ISO.
#
# The build never modifies the host's pacman configuration: mkarchiso is given
# the profile's own pacman.conf, and mirror selection belongs to the operator.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_DIR="$ROOT_DIR/iso"
WORK_DIR="${NULL_WORK_DIR:-$ROOT_DIR/work}"
OUT_DIR="${NULL_OUT_DIR:-$ROOT_DIR/out}"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v mkarchiso >/dev/null 2>&1 || die "mkarchiso not found (pacman -S archiso)"

if [[ ${EUID} -ne 0 ]]; then
  die "mkarchiso must run as root. Re-run deliberately: sudo $0"
fi

"$ROOT_DIR/tools/lint.sh" || die "validation gate failed; refusing to build"

mkdir -p "$WORK_DIR" "$OUT_DIR"

printf 'Building from %s\n' "$PROFILE_DIR"
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

ISO_FILE="$(find "$OUT_DIR" -maxdepth 1 -name '*.iso' -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)"
[[ -n "$ISO_FILE" ]] || die "no ISO produced"

sha256sum "$ISO_FILE" > "$ISO_FILE.sha256"
printf '\nBuild complete: %s\n' "$ISO_FILE"
printf 'SHA-256:        %s\n' "$(cut -d' ' -f1 < "$ISO_FILE.sha256")"
printf '\nThis ISO is unsigned. Signing is required before any stable release.\n'
