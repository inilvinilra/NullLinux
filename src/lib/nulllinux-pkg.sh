#!/usr/bin/env bash
# Null Linux package engine.
#
# Every installation reports a structured result and is verified against the
# package database. Nothing here ever refreshes the database without upgrading
# (partial upgrades corrupt a rolling-release system), and nothing installs
# software through a language package manager.
#
# Result codes returned by pkg_install / role_install:
#   0  complete   every requested package is installed
#   10 partial    some optional packages could not be installed
#   11 failed     at least one required package could not be installed
#   12 canceled   the user aborted
#   13 unchanged  nothing needed doing

NULL_RESULT_COMPLETE=0
NULL_RESULT_PARTIAL=10
NULL_RESULT_FAILED=11
NULL_RESULT_CANCELED=12
NULL_RESULT_UNCHANGED=13

NULL_ROLE_DIR="${NULL_ROLE_DIR:-/usr/share/nulllinux/roles}"
NULL_STATE_DIR="${NULL_STATE_DIR:-/var/lib/nulllinux/roles}"
NULL_PACMAN="${NULL_PACMAN:-pacman}"
# Privilege escalation is a prefix, never part of the command name: joining them
# into one string makes the shell look for a command called "sudo pacman".
NULL_PACMAN_PREFIX="${NULL_PACMAN_PREFIX:-}"

# Populated by pkg_install.
PKG_INSTALLED=()
PKG_ALREADY=()
PKG_FAILED=()

# Queries never need privilege; only transactions do.
pacman_read() { "$NULL_PACMAN" "$@"; }
pacman_write() {
  if [[ -n "$NULL_PACMAN_PREFIX" ]]; then
    "$NULL_PACMAN_PREFIX" "$NULL_PACMAN" "$@"
  else
    "$NULL_PACMAN" "$@"
  fi
}

pacman_q() { pacman_read -Qq "$1" >/dev/null 2>&1; }
pacman_si() { pacman_read -Si "$1" >/dev/null 2>&1; }

# ── role data ────────────────────────────────────────────────────────────────

role_file() { printf '%s/%s.role' "$NULL_ROLE_DIR" "$1"; }

role_exists() { [[ -f "$(role_file "$1")" ]]; }

role_ids() {
  local f
  for f in "$NULL_ROLE_DIR"/*.role; do
    [[ -f "$f" ]] || continue
    basename "$f" .role
  done
}

role_field() {
  local role="$1" key="$2" line
  while IFS= read -r line; do
    [[ "$line" == "${key}="* ]] && { printf '%s' "${line#*=}"; return 0; }
  done < "$(role_file "$role")"
}

role_packages() {
  local line
  while IFS= read -r line; do
    [[ "$line" == package=* ]] && printf '%s\n' "${line#package=}"
  done < "$(role_file "$1")"
}

# ── role state ───────────────────────────────────────────────────────────────
#
# State is derived from the package database first. The state file only records
# what this tool installed, so removal can tell our packages from the user's.

state_file() { printf '%s/%s.state' "$NULL_STATE_DIR" "$1"; }

role_status() {
  local role="$1"
  if pacman_q "nulllinux-${role}"; then
    printf 'metapackage'
    return 0
  fi

  local total=0 present=0 pkg
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] || continue
    total=$((total + 1))
    pacman_q "$pkg" && present=$((present + 1))
  done < <(role_packages "$role")

  if [[ -f "$(state_file "$role")" ]]; then
    [[ $present -eq $total ]] && printf 'installed' || printf 'degraded'
    return 0
  fi
  if [[ $total -gt 0 && $present -eq $total ]]; then
    printf 'satisfied'
  elif [[ $present -gt 0 ]]; then
    printf 'partial'
  else
    printf 'available'
  fi
}

role_is_active() {
  case "$(role_status "$1")" in
    metapackage | installed | degraded | satisfied) return 0 ;;
    *) return 1 ;;
  esac
}

# Packages this tool installed for a role (never the user's own packages).
state_owned() {
  local f line
  f="$(state_file "$1")"
  [[ -f "$f" ]] || return 0
  while IFS= read -r line; do
    [[ "$line" == owned=* ]] && printf '%s\n' "${line#owned=}"
  done < "$f"
}

state_write() {
  local role="$1"; shift
  local stamp
  stamp="$(date -Iseconds)"
  mkdir -p "$NULL_STATE_DIR"
  {
    printf 'role=%s\n' "$role"
    printf 'installed_at=%s\n' "$stamp"
    local p
    for p in "$@"; do printf 'owned=%s\n' "$p"; done
  } > "$(state_file "$role")"
}

state_clear() { rm -f "$(state_file "$1")"; }

# ── installation ─────────────────────────────────────────────────────────────

# Deliberate, complete synchronisation. Never call plain -Sy.
pkg_sync_upgrade() {
  pacman_write -Syu --noconfirm
}

# pkg_install <pkg...>
# Installs from configured repositories only, then verifies each package
# against the package database. Repository failure is never treated as success.
pkg_install() {
  PKG_INSTALLED=(); PKG_ALREADY=(); PKG_FAILED=()
  local -a wanted=("$@") missing=()
  local pkg

  for pkg in "${wanted[@]}"; do
    if pacman_q "$pkg"; then PKG_ALREADY+=("$pkg"); else missing+=("$pkg"); fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    return "$NULL_RESULT_UNCHANGED"
  fi

  # One transaction for everything that resolves; then retry the remainder
  # individually so a single bad name cannot mask the rest.
  pacman_write -S --needed --noconfirm "${missing[@]}" >&2 || true

  local -a still=()
  for pkg in "${missing[@]}"; do
    if pacman_q "$pkg"; then PKG_INSTALLED+=("$pkg"); else still+=("$pkg"); fi
  done

  for pkg in "${still[@]}"; do
    pacman_write -S --needed --noconfirm "$pkg" >&2 || true
    if pacman_q "$pkg"; then
      PKG_INSTALLED+=("$pkg")
    else
      PKG_FAILED+=("$pkg")
    fi
  done

  [[ ${#PKG_FAILED[@]} -eq 0 ]] && return "$NULL_RESULT_COMPLETE"
  [[ ${#PKG_INSTALLED[@]} -gt 0 ]] && return "$NULL_RESULT_PARTIAL"
  return "$NULL_RESULT_FAILED"
}

result_name() {
  case "$1" in
    "$NULL_RESULT_COMPLETE") printf 'complete' ;;
    "$NULL_RESULT_PARTIAL") printf 'partial' ;;
    "$NULL_RESULT_FAILED") printf 'failed' ;;
    "$NULL_RESULT_CANCELED") printf 'canceled' ;;
    "$NULL_RESULT_UNCHANGED") printf 'unchanged' ;;
    *) printf 'unknown' ;;
  esac
}

# ── removal ownership ────────────────────────────────────────────────────────

# Packages required by any *other* active role.
packages_claimed_elsewhere() {
  local keep="$1" role
  while IFS= read -r role; do
    [[ "$role" == "$keep" ]] && continue
    role_is_active "$role" || continue
    role_packages "$role"
  done < <(role_ids) | sort -u
}

# role_removable <role>
# Prints packages that may be removed: installed, belonging to this role, not
# claimed by another active role, and installed by us rather than by the user.
role_removable() {
  local role="$1"
  local claimed owned pkg
  claimed="$(packages_claimed_elsewhere "$role")"
  owned="$(state_owned "$role")"

  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] || continue
    pacman_q "$pkg" || continue
    grep -qxF "$pkg" <<<"$claimed" && continue
    # With no state file we cannot prove we installed it, so we keep it.
    [[ -n "$owned" ]] && ! grep -qxF "$pkg" <<<"$owned" && continue
    [[ -z "$owned" ]] && continue
    printf '%s\n' "$pkg"
  done < <(role_packages "$role")
}

role_kept_shared() {
  local role="$1" claimed pkg
  claimed="$(packages_claimed_elsewhere "$role")"
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] || continue
    pacman_q "$pkg" || continue
    grep -qxF "$pkg" <<<"$claimed" && printf '%s\n' "$pkg"
  done < <(role_packages "$role")
}
