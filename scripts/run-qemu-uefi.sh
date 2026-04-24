#!/usr/bin/env bash
# UEFI (OVMF) — recommended for Null Linux. `run-qemu.sh` is a wrapper to this.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=qemu-common.sh
source "$SCRIPT_DIR/qemu-common.sh" "$@"

find_ovmf() {
  local c v
  for c in \
    "${OVMF_CODE:-}" \
    /usr/share/edk2/x64/OVMF_CODE.4m.fd \
    /usr/share/ovmf/x64/OVMF_CODE.fd \
    /usr/share/qemu/edk2-x86_64-code.fd
  do
    [[ -n "$c" && -f "$c" ]] && { echo "$c"; return 0; }
  done
  return 1
}

find_ovmf_vars() {
  local v
  for v in \
    "${OVMF_VARS_TEMPLATE:-}" \
    /usr/share/edk2/x64/OVMF_VARS.4m.fd \
    /usr/share/ovmf/x64/OVMF_VARS.fd \
    /usr/share/qemu/edk2-x86_64-vars.fd
  do
    [[ -n "$v" && -f "$v" ]] && { echo "$v"; return 0; }
  done
  return 1
}

OVMF_CODE="$(find_ovmf)" || {
  echo "OVMF UEFI firmware not found. Install: edk2-ovmf or ovmf" >&2
  exit 1
}
OVMF_VARS_TEMPLATE="$(find_ovmf_vars)" || {
  echo "OVMF vars template not found." >&2
  exit 1
}

OVMF_VARS="$ROOT_DIR/work/OVMF_VARS.fd"
mkdir -p "$ROOT_DIR/work"
cp -f "$OVMF_VARS_TEMPLATE" "$OVMF_VARS"

echo "OVMF CODE: $OVMF_CODE" >&2

exec qemu-system-x86_64 \
  "${COMMON_QEMU_ARGS[@]}" \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
  -drive if=pflash,format=raw,file="$OVMF_VARS"
