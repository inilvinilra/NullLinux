#!/usr/bin/env bash
# Report how much of the role catalog the configured repositories can actually
# install. This is a fact about the running system, not a pass/fail rule: with
# only official Arch repositories most security tooling is unavailable, which is
# expected and is exactly what the user is told before they opt in.
#
# Exits non-zero only if the package database cannot be read.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

ROLE_DIR="${NULL_ROLE_DIR:-iso/airootfs/usr/share/nulllinux/roles}"

command -v pacman >/dev/null 2>&1 || { echo "pacman not available"; exit 1; }

available="$(mktemp)"
wanted="$(mktemp)"
trap 'rm -f "$available" "$wanted"' EXIT

pacman -Slq 2>/dev/null | sort -u > "$available" || { echo "cannot read the package database"; exit 1; }
[[ -s "$available" ]] || { echo "package database is empty; run a full sync first"; exit 1; }

printf 'Repositories configured: %s\n\n' \
  "$(grep -oE '^\[[a-z0-9-]+\]' /etc/pacman.conf | tr -d '[]' | grep -v options | tr '\n' ' ')"

printf '%-16s %6s %6s %6s\n' "ROLE" "TOTAL" "AVAIL" "MISS"
total_all=0
miss_all=0
for f in "$ROLE_DIR"/*.role; do
  [[ -f "$f" ]] || continue
  role="$(basename "$f" .role)"
  grep '^package=' "$f" | sed 's/^package=//' | sort -u > "$wanted"
  total="$(wc -l < "$wanted")"
  miss="$(comm -23 "$wanted" "$available" | wc -l)"
  total_all=$((total_all + total))
  miss_all=$((miss_all + miss))
  printf '%-16s %6d %6d %6d\n' "$role" "$total" "$((total - miss))" "$miss"
done

printf '\n%-16s %6d %6d %6d\n' "TOTAL (entries)" "$total_all" "$((total_all - miss_all))" "$miss_all"

grep -h '^package=' "$ROLE_DIR"/*.role | sed 's/^package=//' | sort -u > "$wanted"
uniq_total="$(wc -l < "$wanted")"
uniq_miss="$(comm -23 "$wanted" "$available" | wc -l)"
printf '%-16s %6d %6d %6d\n' "TOTAL (unique)" "$uniq_total" "$((uniq_total - uniq_miss))" "$uniq_miss"

if [[ "${1:-}" == "--list-missing" ]]; then
  printf '\nNot installable from the configured repositories:\n'
  comm -23 "$wanted" "$available" | sed 's/^/  /'
fi

printf '\nPackages missing here are typically in BlackArch or the AUR.\n'
printf 'See docs/package-sources.md; enable repositories with null-repo.\n'
