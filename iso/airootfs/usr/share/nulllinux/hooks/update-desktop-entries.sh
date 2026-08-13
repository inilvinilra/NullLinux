#!/usr/bin/env bash
# Keep Null Linux tool launchers in step with what is actually installed.
# Idempotent: adds entries for installed tools, removes entries for tools that
# are gone. Runs after every pacman transaction, so it needs no target list.
set -uo pipefail

SRC="/usr/share/nulllinux/desktop-entries"
DST="/usr/share/applications"

[[ -d "$SRC" ]] || exit 0

changed=0
for entry in "$SRC"/*.desktop; do
  [[ -f "$entry" ]] || continue
  target="$DST/nulllinux-$(basename "$entry")"
  pkg="$(sed -n 's/^X-NullLinux-Package=//p' "$entry" | head -1)"
  [[ -n "$pkg" ]] || continue

  if pacman -Qq "$pkg" >/dev/null 2>&1; then
    if ! cmp -s "$entry" "$target"; then
      install -Dm644 "$entry" "$target"
      changed=1
    fi
  elif [[ -e "$target" ]]; then
    rm -f "$target"
    changed=1
  fi
done

[[ $changed -eq 1 ]] && update-desktop-database "$DST" >/dev/null 2>&1
exit 0
