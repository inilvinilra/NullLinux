#!/usr/bin/env bash
# Syncs NullLinux desktop entries for installed tools into the applications dir.

DESKTOP_SRC="/usr/share/nulllinux/desktop-entries"
DESKTOP_DST="/usr/share/applications"

[[ -d "$DESKTOP_SRC" ]] || exit 0

while read -r pkg; do
  for f in "$DESKTOP_SRC"/*.desktop; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f" .desktop)"
    if [[ "$base" == "$pkg" ]] || [[ "$base" == *"$pkg"* ]]; then
      cp -f "$f" "$DESKTOP_DST/nulllinux-$(basename "$f")"
    fi
  done
done

update-desktop-database "$DESKTOP_DST" 2>/dev/null || true
