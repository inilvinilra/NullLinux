#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=qemu-common.sh
source "$SCRIPT_DIR/qemu-common.sh" "$@"

exec qemu-system-x86_64 "${COMMON_QEMU_ARGS[@]}"
