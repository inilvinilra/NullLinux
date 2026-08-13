#!/usr/bin/env bash
# Input validation for anything that reaches a privileged operation.
#
# User-supplied values are never interpolated into generated scripts, so these
# checks are the boundary: reject here, and nothing downstream has to escape.

# RFC 1123 label: letters, digits and inner hyphens, 1-63 characters.
valid_hostname() {
  local value="$1"
  # Character ranges follow locale collation, which lets accented letters match
  # [a-z]. C collation is what the kernel and useradd actually accept.
  local LC_ALL=C
  [[ ${#value} -ge 1 && ${#value} -le 63 ]] || return 1
  [[ "$value" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || return 1
  return 0
}

# Portable POSIX user name, plus the reserved names we must not collide with.
valid_username() {
  local value="$1"
  local LC_ALL=C
  [[ ${#value} -ge 1 && ${#value} -le 32 ]] || return 1
  [[ "$value" =~ ^[a-z_][a-z0-9_-]*$ ]] || return 1
  case "$value" in
    root | bin | daemon | mail | ftp | http | nobody | systemd-* | dbus | polkitd) return 1 ;;
  esac
  return 0
}

valid_timezone() {
  local value="$1"
  local LC_ALL=C
  [[ "$value" =~ ^[A-Za-z0-9][A-Za-z0-9_+-]*(/[A-Za-z0-9][A-Za-z0-9_+-]*)*$ ]] || return 1
  [[ -e "/usr/share/zoneinfo/$value" ]] || return 1
  return 0
}

# Kernel naming rule: a trailing digit in the disk name means the partition
# suffix is separated by "p" (nvme0n1 -> nvme0n1p1, sda -> sda1).
partition_path() {
  local disk="$1" number="$2"
  if [[ "$disk" =~ [0-9]$ ]]; then
    printf '%sp%s' "$disk" "$number"
  else
    printf '%s%s' "$disk" "$number"
  fi
}
