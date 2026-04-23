#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=qemu-common.sh
source "$SCRIPT_DIR/qemu-common.sh" "$@"

OVMF_CODE="${OVMF_CODE:-/usr/share/edk2/x64/OVMF_CODE.4m.fd}"
OVMF_VARS_TEMPLATE="${OVMF_VARS_TEMPLATE:-/usr/share/edk2/x64/OVMF_VARS.4m.fd}"
OVMF_VARS="$ROOT_DIR/work/OVMF_VARS.fd"

if [[ ! -f "$OVMF_CODE" || ! -f "$OVMF_VARS_TEMPLATE" ]]; then
  echo "OVMF firmware not found." >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/work"
cp -f "$OVMF_VARS_TEMPLATE" "$OVMF_VARS"

exec qemu-system-x86_64 \
  "${COMMON_QEMU_ARGS[@]}" \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
  -drive if=pflash,format=raw,file="$OVMF_VARS"
