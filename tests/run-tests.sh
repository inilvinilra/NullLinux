#!/usr/bin/env bash
# Null Linux unit tests. No root, no network, no real package operations:
# pacman is replaced by a stub whose behaviour each test controls.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass_count=0
fail_count=0

ok() { pass_count=$((pass_count + 1)); printf '  ok   %s\n' "$1"; }
no() { fail_count=$((fail_count + 1)); printf '  FAIL %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; }

is() {
  local desc="$1" expected="$2" actual="$3"
  [[ "$expected" == "$actual" ]] && ok "$desc" || no "$desc" "$expected" "$actual"
}

group() { printf '\n── %s\n' "$1"; }

# ── stub pacman ──────────────────────────────────────────────────────────────
# INSTALLED holds package names, one per line. INSTALLABLE lists what the fake
# repositories can provide. The stub mutates INSTALLED exactly like pacman would.
setup_stub() {
  mkdir -p "$TMP/bin"
  cat > "$TMP/bin/pacman" <<'STUB'
#!/usr/bin/env bash
db="$NULL_TEST_DB"; repo="$NULL_TEST_REPO"
case "$1" in
  -Qq) grep -qxF "$2" "$db" ;;
  -Si) grep -qxF "$2" "$repo" ;;
  -S)
    shift
    args=(); for a in "$@"; do [[ "$a" == -* ]] || args+=("$a"); done
    rc=0
    for p in "${args[@]}"; do
      if grep -qxF "$p" "$repo"; then grep -qxF "$p" "$db" || echo "$p" >> "$db"
      else rc=1; fi
    done
    exit $rc ;;
  -Rns)
    shift
    args=(); for a in "$@"; do [[ "$a" == -* ]] || args+=("$a"); done
    for p in "${args[@]}"; do grep -vxF "$p" "$db" > "$db.new" || true; mv "$db.new" "$db"; done ;;
  *) exit 0 ;;
esac
STUB
  chmod +x "$TMP/bin/pacman"
}

reset_world() {
  : > "$TMP/db"; : > "$TMP/repo"
  rm -rf "$TMP/roles" "$TMP/state"
  mkdir -p "$TMP/roles" "$TMP/state"
  export NULL_TEST_DB="$TMP/db" NULL_TEST_REPO="$TMP/repo"
  export NULL_ROLE_DIR="$TMP/roles" NULL_STATE_DIR="$TMP/state"
  export NULL_PACMAN="$TMP/bin/pacman"
}

make_role() {
  local id="$1"; shift
  { printf 'id=%s\nname=%s role\ndescription=test\nmenu_name=%s\n' "$id" "$id" "$id"
    for p in "$@"; do printf 'package=%s\n' "$p"; done
  } > "$TMP/roles/$id.role"
}

db_add()   { printf '%s\n' "$@" >> "$TMP/db"; }
repo_add() { printf '%s\n' "$@" >> "$TMP/repo"; }

setup_stub
reset_world
# shellcheck source=../src/lib/nulllinux-pkg.sh
source "$ROOT_DIR/src/lib/nulllinux-pkg.sh"

# ── role parsing ─────────────────────────────────────────────────────────────
group "role manifest parsing"
make_role redteam nmap hydra sqlmap
is "reads package list" "nmap hydra sqlmap" "$(role_packages redteam | tr '\n' ' ' | sed 's/ $//')"
is "reads display name" "redteam role" "$(role_field redteam name)"
is "detects missing role" "1" "$(role_exists nosuch; echo $?)"
make_role 'weird' 'pkg-with-dash' 'pkg.with.dot'
is "tolerates punctuation in names" "pkg-with-dash pkg.with.dot" "$(role_packages weird | tr '\n' ' ' | sed 's/ $//')"

# ── install results ──────────────────────────────────────────────────────────
group "structured install results"
reset_world; make_role r1 a b c

repo_add a b c
pkg_install a b c; is "all available -> complete" "complete" "$(result_name $?)"
is "installed set recorded" "a b c" "${PKG_INSTALLED[*]}"

pkg_install a b c; is "second run -> unchanged" "unchanged" "$(result_name $?)"
is "nothing reinstalled" "0" "${#PKG_INSTALLED[@]}"

reset_world; repo_add a
pkg_install a missing1; is "one resolves, one does not -> partial" "partial" "$(result_name $?)"
is "failure recorded" "missing1" "${PKG_FAILED[*]}"
is "success recorded" "a" "${PKG_INSTALLED[*]}"

reset_world
pkg_install nope1 nope2; is "nothing resolves -> failed" "failed" "$(result_name $?)"
is "all recorded as failed" "nope1 nope2" "${PKG_FAILED[*]}"

# A package that is not in the repo must never be reported as installed,
# even when the bulk transaction exits non-zero as a whole.
reset_world; repo_add good
pkg_install good bad
is "verified against the database, not the exit code" "good" "${PKG_INSTALLED[*]}"
is "unresolved package is not claimed" "bad" "${PKG_FAILED[*]}"

# ── role status ──────────────────────────────────────────────────────────────
group "role status derives from package state"
reset_world; make_role r1 a b
is "nothing installed -> available" "available" "$(role_status r1)"
db_add a
is "some installed -> partial" "partial" "$(role_status r1)"
db_add b
is "all installed, no state file -> satisfied" "satisfied" "$(role_status r1)"
state_write r1 a b
is "with state file -> installed" "installed" "$(role_status r1)"
reset_world; make_role r1 a b; db_add a; state_write r1 a b
is "state file but package missing -> degraded" "degraded" "$(role_status r1)"
reset_world; make_role r1 a b; db_add nulllinux-r1
is "metapackage wins" "metapackage" "$(role_status r1)"

# ── removal ownership ────────────────────────────────────────────────────────
group "removal never touches packages owned by others"
reset_world
make_role redteam nmap shared-tool
make_role blueteam suricata shared-tool
repo_add nmap shared-tool suricata
db_add nmap shared-tool suricata
state_write redteam nmap shared-tool
state_write blueteam suricata shared-tool

is "shared package is kept while the other role is active" "nmap" "$(role_removable redteam | tr '\n' ' ' | sed 's/ $//')"
is "shared package reported as kept" "shared-tool" "$(role_kept_shared redteam | tr '\n' ' ' | sed 's/ $//')"

state_clear blueteam
db_add x  # blueteam now inactive: its packages are still installed but unowned
reset_world
make_role redteam nmap shared-tool
make_role blueteam suricata shared-tool
repo_add nmap shared-tool suricata
db_add nmap shared-tool
state_write redteam nmap shared-tool
is "with the other role gone, shared package is removable" "nmap shared-tool" "$(role_removable redteam | tr '\n' ' ' | sed 's/ $//')"

reset_world
make_role redteam nmap user-installed
repo_add nmap user-installed
db_add nmap user-installed
state_write redteam nmap   # user-installed was already there; we do not own it
is "package we did not install is never removed" "nmap" "$(role_removable redteam | tr '\n' ' ' | sed 's/ $//')"

reset_world
make_role redteam nmap
repo_add nmap; db_add nmap
is "no state file -> nothing is removable" "" "$(role_removable redteam | tr '\n' ' ' | sed 's/ $//')"

# ── input validation ─────────────────────────────────────────────────────────
group "hostname and username validation"
source "$ROOT_DIR/src/lib/nulllinux-validate.sh"

for good in null nulllinux host-1 a bc123; do
  is "hostname '$good' accepted" "0" "$(valid_hostname "$good"; echo $?)"
done
for bad in "" "-lead" "trail-" "has space" "UPPER" "a;rm -rf /" "sü" "$(printf 'a\nb')" \
           "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"; do
  is "hostname $(printf '%q' "$bad") rejected" "1" "$(valid_hostname "$bad"; echo $?)"
done

for good in null user1 dev-ops _svc; do
  is "username '$good' accepted" "0" "$(valid_username "$good"; echo $?)"
done
for bad in "" "1st" "Root" "has space" "a\$b" "x;id" "root" "../etc" "$(printf 'a\nb')" \
           "toolongusernametoolongusernametoolong"; do
  is "username $(printf '%q' "$bad") rejected" "1" "$(valid_username "$bad"; echo $?)"
done

# ── device naming ────────────────────────────────────────────────────────────
group "partition naming"
is "sata"    "/dev/sda1"      "$(partition_path /dev/sda 1)"
is "nvme"    "/dev/nvme0n1p1" "$(partition_path /dev/nvme0n1 1)"
is "nvme p2" "/dev/nvme0n1p2" "$(partition_path /dev/nvme0n1 2)"
is "mmc"     "/dev/mmcblk0p1" "$(partition_path /dev/mmcblk0 1)"
is "loop"    "/dev/loop0p1"   "$(partition_path /dev/loop0 1)"
is "virtio"  "/dev/vda2"      "$(partition_path /dev/vda 2)"
is "dm"      "/dev/dm-0p1"    "$(partition_path /dev/dm-0 1)"

# ── end-to-end: the real CLI against the stub ────────────────────────────────
group "null-toolkit end to end"
reset_world
mkdir -p "$TMP/lib"; cp "$ROOT_DIR/src/lib/nulllinux-pkg.sh" "$TMP/lib/"
TK=("$ROOT_DIR/src/tools/null-toolkit/null-toolkit")
export NULL_LIB_DIR="$TMP/lib"
run_tk() { NULL_LIB_DIR="$TMP/lib" "${TK[@]}" "$@" >"$TMP/out" 2>"$TMP/err"; }

make_role redteam nmap hydra
make_role blueteam suricata hydra
repo_add nmap hydra suricata

run_tk list; is "list shows roles as available" "0" "$?"
is "list marks redteam available" "1" "$(grep -c 'redteam.*available' "$TMP/out")"

# install as non-root must refuse
run_tk install redteam; is "install without root refuses" "1" "$?"
is "refusal explains how" "1" "$(grep -c 'Root required' "$TMP/err")"

# Dry-run removal needs no root and must never change anything.
db_add nmap hydra suricata
state_write redteam nmap hydra
state_write blueteam suricata hydra
run_tk remove redteam --dry-run; is "dry-run exits cleanly" "0" "$?"
is "dry-run keeps the shared package" "1" "$(grep -c 'hydra' "$TMP/out")"
is "dry-run removes only the exclusive package" "1" "$(grep -cE '^    - nmap$' "$TMP/out")"
is "dry-run says nothing changed" "1" "$(grep -c 'nothing was changed' "$TMP/out")"
is "dry-run left the database intact" "3" "$(wc -l < "$TMP/db")"
state_kept=1; [[ -f "$TMP/state/redteam.state" ]] && state_kept=0
is "dry-run left role state intact" "0" "$state_kept"

run_tk info redteam; is "info runs without root" "0" "$?"
is "info counts installed packages" "1" "$(grep -c '2 of 2 installed' "$TMP/out")"

# ── privilege escalation ─────────────────────────────────────────────────────
group "privileged pacman invocation"
reset_world; make_role r1 a; repo_add a

# A prefix must stay a separate argv element. Folding it into the command name
# makes the shell search for a program literally called "sudo pacman".
mkdir -p "$TMP/bin"
cat > "$TMP/bin/fakesudo" <<'SUDO'
#!/usr/bin/env bash
echo "fakesudo:$1" >> "$NULL_TEST_DB.sudolog"
exec "$@"
SUDO
chmod +x "$TMP/bin/fakesudo"

rm -f "$TMP/db.sudolog"
NULL_PACMAN_PREFIX="$TMP/bin/fakesudo" pkg_install a
is "install through a prefix succeeds" "complete" "$(result_name $?)"
is "the prefix actually ran" "1" "$(grep -c 'fakesudo:' "$TMP/db.sudolog" 2>/dev/null || echo 0)"
is "the package really landed" "0" "$(pacman_q a; echo $?)"

reset_world; make_role r1 a; repo_add a
NULL_PACMAN_PREFIX="" pkg_install a
is "install without a prefix still works" "complete" "$(result_name $?)"

# Reads must not be escalated: querying the database needs no privilege.
reset_world; make_role r1 a; repo_add a; db_add a
rm -f "$TMP/db.sudolog"
NULL_PACMAN_PREFIX="$TMP/bin/fakesudo" pacman_q a
is "queries bypass the prefix" "0" "$(test -f "$TMP/db.sudolog" && echo 1 || echo 0)"

# ── repository trust ─────────────────────────────────────────────────────────
group "null-repo fingerprint handling"
cp "$ROOT_DIR/iso/pacman.conf" "$TMP/pacman.conf"
NULL_PACMAN_CONF="$TMP/pacman.conf" source "$ROOT_DIR/src/tools/null-repo/null-repo" >/dev/null 2>&1

is "full fingerprint accepted" "4AA4767BBC9C4B1D18AE28B77F2D434B9741E8AC" \
   "$(normalise_fpr '4AA4767BBC9C4B1D18AE28B77F2D434B9741E8AC')"
is "spaced fingerprint normalised" "4AA4767BBC9C4B1D18AE28B77F2D434B9741E8AC" \
   "$(normalise_fpr '4AA4 767B BC9C 4B1D 18AE  28B7 7F2D 434B 9741 E8AC')"
is "lowercase normalised" "4AA4767BBC9C4B1D18AE28B77F2D434B9741E8AC" \
   "$(normalise_fpr '4aa4767bbc9c4b1d18ae28b77f2d434b9741e8ac')"
is "long key id refused" "1" "$(normalise_fpr '3056513887B78AEB' >/dev/null; echo $?)"
is "short key id refused" "1" "$(normalise_fpr '87B78AEB' >/dev/null; echo $?)"
is "non-hex refused" "1" "$(normalise_fpr 'ZZZ4767BBC9C4B1D18AE28B77F2D434B9741E8AC' >/dev/null; echo $?)"
is "empty refused" "1" "$(normalise_fpr '' >/dev/null; echo $?)"
is "known repo recognised" "0" "$(known_repo blackarch; echo $?)"
is "unknown repo rejected" "1" "$(known_repo notarepo; echo $?)"
is "repo starts disabled" "1" "$(is_enabled blackarch; echo $?)"

# The installer cannot be unit-tested the way a library can: it is a sequence of
# steps against a disk. Its control flow can be, and that suite runs itself.
if "$ROOT_DIR/tests/installer-unattended-test.sh"; then
  pass_count=$((pass_count + 1))
else
  fail_count=$((fail_count + 1))
  printf '  \033[0;31m✗\033[0m installer unattended suite failed\n'
fi

printf '\n%d passed, %d failed\n' "$pass_count" "$fail_count"
[[ $fail_count -eq 0 ]]
