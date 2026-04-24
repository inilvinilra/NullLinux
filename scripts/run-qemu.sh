#!/usr/bin/env bash
# Null Linux — launch ISO in QEMU with UEFI (OVMF). This is the default.
# For legacy SeaBIOS only, use: ./run-qemu-bios.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run-qemu-uefi.sh" "$@"
