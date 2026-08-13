#!/usr/bin/env bash
# Build the Null Linux ISO.
#
# The build never modifies the host's pacman configuration: mkarchiso is given
# the profile's own pacman.conf, and mirror selection belongs to the operator.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_SRC="$ROOT_DIR/iso"
# mkarchiso builds a chroot inside the work directory, and arch-chroot cannot
# handle a path containing whitespace. Fall back to a safe location instead of
# failing halfway through a long build.
DEFAULT_WORK="$ROOT_DIR/work"
DEFAULT_OUT="$ROOT_DIR/out"
if [[ "$ROOT_DIR" =~ [[:space:]] ]]; then
  DEFAULT_WORK="/var/tmp/nulllinux-work"
  DEFAULT_OUT="/var/tmp/nulllinux-out"
fi
WORK_DIR="${NULL_WORK_DIR:-$DEFAULT_WORK}"
OUT_DIR="${NULL_OUT_DIR:-$DEFAULT_OUT}"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v mkarchiso >/dev/null 2>&1 || die "mkarchiso not found (pacman -S archiso)"

if [[ ${EUID} -ne 0 ]]; then
  die "mkarchiso must run as root. Re-run deliberately: sudo $0"
fi

"$ROOT_DIR/tools/lint.sh" || die "validation gate failed; refusing to build"

if [[ "$WORK_DIR" =~ [[:space:]] || "$OUT_DIR" =~ [[:space:]] ]]; then
  die "work and output paths must not contain whitespace (arch-chroot limitation): $WORK_DIR"
fi

mkdir -p "$WORK_DIR" "$OUT_DIR"
printf 'Work directory:   %s\n' "$WORK_DIR"
printf 'Output directory: %s\n' "$OUT_DIR"

# iso/ holds live-only configuration; executables come from src/ at build time.
PROFILE_DIR="${WORK_DIR%/}-profile"
"$ROOT_DIR/tools/stage-profile.sh" "$PROFILE_DIR"

printf 'Building from %s (staged from %s + src/)\n' "$PROFILE_DIR" "$PROFILE_SRC"
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

ISO_FILE="$(find "$OUT_DIR" -maxdepth 1 -name '*.iso' -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)"
[[ -n "$ISO_FILE" ]] || die "no ISO produced"

sha256sum "$ISO_FILE" > "$ISO_FILE.sha256"
printf '\nBuild complete: %s\n' "$ISO_FILE"
printf 'SHA-256:        %s\n' "$(cut -d' ' -f1 < "$ISO_FILE.sha256")"
printf '\nThis ISO is unsigned. Signing is required before any stable release.\n'
