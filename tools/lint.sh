#!/usr/bin/env bash
# Null Linux P0 validation gate.
# Encodes the release-blocking rules from docs/audit-baseline.md.
# Exit 0 = gate passes. Exit 1 = at least one P0 rule is violated.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

CANONICAL_REPO="${NULL_CANONICAL_REPO:-inilvinilra/NullLinux}"

RED=''; GREEN=''; YELLOW=''; BOLD=''; NC=''
if [[ -t 1 ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; BOLD=$'\033[1m'; NC=$'\033[0m'
fi

failures=0
skipped=0
current_check=""

# Scan the tree but never the gate's own rule patterns or build output.
scan() {
  grep -rn -e "$1" --include='*' . \
    --exclude-dir=work --exclude-dir=out --exclude-dir=.git 2>/dev/null \
    | grep -v '^\./tools/lint\.sh:' || true
}

# Code rules apply to code. Documentation has to be able to name the practices
# it tells people to avoid.
scan_code() { scan "$1" | grep -v '\.md:' || true; }

check() {
  current_check="$1"
  printf '%s── %s%s\n' "$BOLD" "$current_check" "$NC"
}

fail() {
  failures=$((failures + 1))
  printf '  %sFAIL%s %s\n' "$RED" "$NC" "$1"
}

pass() {
  printf '  %sok%s   %s\n' "$GREEN" "$NC" "$1"
}

skip() {
  skipped=$((skipped + 1))
  printf '  %sskip%s %s\n' "$YELLOW" "$NC" "$1"
}

shell_files() {
  find . -path ./work -prune -o -path ./out -prune -o -type f \
    \( -name '*.sh' -o -path './src/installer/*' -o -path './src/tools/*/null-*' \
       -o -path './iso/airootfs/usr/bin/*' -o -path './iso/airootfs/usr/local/bin/*' \) \
    -print 2>/dev/null | grep -v '\.desktop$' | sort
}

desktop_files() {
  find . -name '*.desktop' -not -path './work/*' | sort
}

# ── 1. Shell syntax ───────────────────────────────────────────────────────────
check "shell syntax (bash -n)"
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  if ! err="$(bash -n "$f" 2>&1)"; then
    fail "$f: $err"
  fi
done < <(shell_files)
[[ $failures -eq 0 ]] && pass "all shell files parse"

# ── 2. ShellCheck ─────────────────────────────────────────────────────────────
check "shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    if ! out="$(shellcheck -S warning -f gcc "$f" 2>&1)"; then
      fail "$f"
      printf '       %s\n' "$out"
    fi
  done < <(shell_files)
else
  skip "shellcheck not installed (pacman -S shellcheck)"
fi

# ── 3. Desktop entry validity ─────────────────────────────────────────────────
check "desktop entries validate"
if command -v desktop-file-validate >/dev/null 2>&1; then
  bad=0
  while IFS= read -r f; do
    if out="$(desktop-file-validate "$f" 2>&1)" && [[ -z "$out" ]]; then
      continue
    fi
    if grep -q '^.*: error:' <<<"$out"; then
      bad=$((bad + 1))
      fail "$f"
      printf '       %s\n' "$(head -1 <<<"$out")"
    fi
  done < <(desktop_files)
  [[ $bad -eq 0 ]] && pass "no desktop-file-validate errors"
else
  skip "desktop-file-validate not installed (pacman -S desktop-file-utils)"
fi

# ── 4. Tool launchers must be safe and self-verifying ──────────────────────────
check "tool launcher safety"
entry_dir="iso/airootfs/usr/share/nulllinux/desktop-entries"
if [[ -d "$entry_dir" ]]; then
  missing_tryexec=(); privileged=()
  for f in "$entry_dir"/*.desktop; do
    [[ -f "$f" ]] || continue
    grep -q '^TryExec=' "$f" || missing_tryexec+=("$(basename "$f")")
    grep -q '^Exec=.*\bsudo\b' "$f" && privileged+=("$(basename "$f")")
  done
  if [[ ${#missing_tryexec[@]} -gt 0 ]]; then
    fail "${#missing_tryexec[@]} entries lack TryExec= (stale entries survive package removal)"
  else
    pass "all entries declare TryExec"
  fi
  if [[ ${#privileged[@]} -gt 0 ]]; then
    fail "entries invoke sudo directly: ${privileged[*]}"
  else
    pass "no launcher invokes sudo directly"
  fi
fi

# ── 5. Desktop entries are removed with their package ─────────────────────────
check "desktop entry removal hook"
hook="iso/airootfs/usr/share/libalpm/hooks/nulllinux-desktop-entries.hook"
if [[ -f "$hook" ]]; then
  if grep -q '^Operation *= *Remove' "$hook"; then
    pass "hook handles package removal"
  else
    fail "$hook has no 'Operation = Remove' trigger; entries persist after uninstall"
  fi
fi

# ── 6. Role manifests parse and carry required fields ─────────────────────────
check "role manifest schema"
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' 2>/dev/null; then
  if out="$(python3 tools/validate-roles.py 2>&1)"; then
    pass "$out"
  else
    fail "$out"
  fi
else
  skip "python3 + PyYAML unavailable (pacman -S python-yaml)"
fi

# ── 7. Single source of truth ─────────────────────────────────────────────────
check "no duplicated source of truth"
drift=0
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' 2>/dev/null; then
  if out="$(python3 tools/generate.py --check 2>&1)"; then
    pass "$out"
  else
    drift=$((drift + 1)); fail "generated tree is stale:"
    printf '       %s\n' "$out"
  fi
else
  skip "generator check needs python3 + PyYAML"
fi
# Executables must exist once, in src/. The profile receives them at build time
# via tools/stage-profile.sh, so there is nothing to keep in sync by hand.
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  base="$(basename "$f")"
  if find src -name "$base" -type f | grep -q .; then
    drift=$((drift + 1))
    fail "duplicate of a src/ file committed under iso/: $f"
  fi
done < <(find iso/airootfs/usr/bin iso/airootfs/usr/share/nulllinux/lib \
              iso/airootfs/usr/share/nulllinux/installer -type f 2>/dev/null)

[[ $drift -eq 0 ]] && pass "generated files current; no executable is committed twice"

check "staged profile is complete"
staged="$(mktemp -d)"
if ./tools/stage-profile.sh "$staged" >/dev/null 2>&1; then
  missing=()
  for f in usr/bin/null-install usr/bin/null-toolkit usr/bin/null-setup \
           usr/bin/null-setup-firstrun usr/bin/null-apply-branding usr/bin/null-repo \
           usr/share/nulllinux/lib/nulllinux-pkg.sh \
           usr/share/nulllinux/lib/nulllinux-validate.sh \
           usr/share/nulllinux/installer/postinstall.sh \
           usr/share/applications/null-setup.desktop \
           etc/skel/.config/autostart/null-setup.desktop; do
    [[ -e "$staged/airootfs/$f" ]] || missing+=("$f")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    fail "staging leaves out: ${missing[*]}"
  else
    pass "staging produces a complete profile"
  fi
else
  fail "tools/stage-profile.sh failed"
fi
rm -rf "$staged"

# ── 8. Canonical project identity ─────────────────────────────────────────────
check "canonical repository identity"
stale="$(scan_code 'xredjhon' | cut -d: -f1 | sort -u)"
if [[ -n "$stale" ]]; then
  fail "stale repository owner in $(wc -l <<<"$stale") files (expected ${CANONICAL_REPO})"
  printf '       %s\n' $stale
else
  pass "no stale repository references"
fi

# ── 9. No partial upgrades at runtime ─────────────────────────────────────────
check "no pacman -Sy partial upgrades"
hits="$(scan_code 'pacman -Sy\([^u]\|$\)')"
if [[ -n "$hits" ]]; then
  fail "partial-upgrade calls found:"
  printf '       %s\n' "$hits"
else
  pass "no partial-upgrade calls"
fi

# ── 10. No unverified remote code execution ───────────────────────────────────
check "no curl | bash"
hits="$(scan_code 'curl[^|]*|[[:space:]]*\(sudo[[:space:]]*\)\?bash\|wget[^|]*|[[:space:]]*\(sudo[[:space:]]*\)\?bash')"
if [[ -n "$hits" ]]; then
  fail "unverified remote script execution:"
  printf '       %s\n' "$hits"
else
  pass "no piped remote script execution"
fi

# ── 11. No untracked language-manager system installs ─────────────────────────
check "no unpinned language-manager fallback"
hits="$(scan_code '--break-system-packages\|go install [^ ]*@latest\|cargo install [^-]')"
if [[ -n "$hits" ]]; then
  fail "unpinned/untracked language-manager installs:"
  printf '       %s\n' "$hits"
else
  pass "no language-manager fallback installs"
fi

# ── 12. First-run wizard must be one-shot ─────────────────────────────────────
check "first-run wizard is one-shot"
autostart="iso/airootfs/etc/skel/.config/autostart/null-setup.desktop"
if [[ -f "$autostart" ]]; then
  if grep -q '^X-KDE-AutostartCondition=\|^TryExec=.*null-setup-firstrun' "$autostart"; then
    pass "autostart entry is conditional"
  else
    fail "$autostart runs on every login (no autostart condition / one-shot guard)"
  fi
fi

# ── 13. GitHub Actions supply chain ───────────────────────────────────────────
check "workflow hardening"
wf_fail=0
for wf in .github/workflows/*.yml; do
  [[ -f "$wf" ]] || continue
  if unpinned="$(grep -n 'uses:.*@v[0-9]' "$wf")"; then
    wf_fail=1; fail "$wf: actions not pinned to a commit SHA"
    printf '       %s\n' "$unpinned"
  fi
  grep -q '^permissions:\|^ *permissions:' "$wf" || { wf_fail=1; fail "$wf: no explicit permissions block"; }
  grep -q 'timeout-minutes:' "$wf" || { wf_fail=1; fail "$wf: no job timeout"; }
  grep -q '^concurrency:' "$wf" || { wf_fail=1; fail "$wf: no concurrency control"; }
done
[[ $wf_fail -eq 0 ]] && pass "workflows pinned, scoped, bounded"

# ── 14. Build must not mutate the host ────────────────────────────────────────
check "build does not modify host configuration"
if hits="$(grep -rn 'save /etc/pacman.d/\|> */etc/pacman.d/mirrorlist' scripts/ 2>/dev/null)"; then
  if [[ -n "$hits" ]]; then
    fail "build script writes host mirror configuration:"
    printf '       %s\n' "$hits"
  fi
else
  pass "no host mirror mutation"
fi

# ── 15. Documented facts match the tree ───────────────────────────────────────
check "documentation facts match source"
role_count="$(find config/roles -name '*.yml' | wc -l)"
entry_count="$(find iso/airootfs/usr/share/nulllinux/desktop-entries -name '*.desktop' 2>/dev/null | wc -l)"
claimed="$(grep -oE '\*\*[0-9]+ (security |tool )?roles\*\*' README.md | grep -oE '[0-9]+' | head -1)"
if [[ -n "$claimed" && "$claimed" != "$role_count" ]]; then
  fail "README claims ${claimed} roles; tree has ${role_count}"
else
  pass "README role count is consistent (${role_count})"
fi
doc_count="$(grep -oE '^[0-9]+ roles' docs/roles.md 2>/dev/null | grep -oE '[0-9]+' | head -1)"
if [[ "$doc_count" != "$role_count" ]]; then
  fail "docs/roles.md reports ${doc_count:-nothing}; tree has ${role_count} roles"
else
  pass "generated role catalog matches (${role_count})"
fi
missing_dirs=()
for f in config/roles/*.yml; do
  role="$(basename "$f" .yml)"
  [[ -f "iso/airootfs/usr/share/desktop-directories/nulllinux-${role}.directory" ]] || missing_dirs+=("$role")
done
if [[ ${#missing_dirs[@]} -gt 0 ]]; then
  fail "roles with no KDE menu category: ${missing_dirs[*]}"
else
  pass "every role has a KDE menu category"
fi
printf '  %sinfo%s %d roles, %d desktop entries, %d unique packages\n' "$BOLD" "$NC" \
  "$role_count" "$entry_count" \
  "$(grep -h '^package=' iso/airootfs/usr/share/nulllinux/roles/*.role | sort -u | wc -l)"

# ── Summary ───────────────────────────────────────────────────────────────────
echo
if [[ $failures -eq 0 ]]; then
  printf '%sP0 gate: PASS%s (%d checks skipped)\n' "$GREEN" "$NC" "$skipped"
  exit 0
fi
printf '%sP0 gate: FAIL — %d violation(s)%s (%d checks skipped)\n' "$RED" "$failures" "$NC" "$skipped"
exit 1
