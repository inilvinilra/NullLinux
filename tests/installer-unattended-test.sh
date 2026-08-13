#!/usr/bin/env bash
# Drive null-install's unattended path end to end against stubbed tools.
#
# The VM test proves an installation works. It costs half an hour, so it cannot
# be the only thing standing between a control-flow mistake and a release. This
# runs the same code path in seconds and asserts the three things that are not
# about partitioning at all:
#
#   * an unattended run never opens a dialog — one that nobody can dismiss does
#     not fail an install, it hangs it
#   * a failure part-way through unwinds its mounts in reverse order
#   * verification that does not pass is reported as a failure, never as success
#
# Every external command is a stub, so nothing here touches a real disk. The
# target device is a node faked by fakeroot: it satisfies -b and refers to
# nothing.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Overridable so the suite can be pointed at a deliberately broken copy to check
# that these assertions still fail when they should.
INSTALLER="${NULL_INSTALLER:-$ROOT_DIR/src/installer/null-install}"

PASS=0; FAIL=0; SKIP=0
ok()   { printf '  \033[0;32m✓\033[0m %s\n' "$*"; PASS=$((PASS + 1)); }
bad()  { printf '  \033[0;31m✗\033[0m %s\n' "$*"; FAIL=$((FAIL + 1)); }
skip() { printf '  \033[0;33m–\033[0m %s (skipped: %s)\n' "$1" "$2"; SKIP=$((SKIP + 1)); }

command -v fakeroot >/dev/null 2>&1 || {
  skip "installer unattended path" "fakeroot is not installed"
  printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
  exit 0
}

# The installer refuses to run on a machine that did not boot via UEFI, and it
# is right to. Rather than weaken that check for the sake of a test, or skip the
# suite on every build machine that is not itself UEFI, give each case a private
# /sys with the firmware directory present. Nothing outside the namespace sees
# it, and the check under test runs unmodified.
UNSHARE=()
if unshare -rm true 2>/dev/null; then
  UNSHARE=(unshare -rm)
  export NULL_TEST_FAKE_SYS=1
elif [[ ! -d /sys/firmware/efi/efivars ]]; then
  skip "installer unattended path" \
    "no unprivileged user namespaces and this host did not boot in UEFI mode"
  printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ── the payload the installer copies from, exactly as it sits on the medium ──
"$ROOT_DIR/tools/stage-profile.sh" "$WORK/profile" >/dev/null || {
  printf 'could not stage the profile\n' >&2; exit 1; }
SRC_ROOT="$WORK/profile/airootfs"

# ── stubs ────────────────────────────────────────────────────────────────────
STUBS="$WORK/stubs"
mkdir -p "$STUBS"

stub() {
  local name="$1"; shift
  printf '#!/usr/bin/env bash\n%s\n' "$*" > "$STUBS/$name"
  chmod +x "$STUBS/$name"
}

# Any dialog at all is a defect in unattended mode: record the attempt and fail
# loudly rather than blocking, so the test reports a bug instead of hanging.
stub dialog 'printf "%s\n" "$*" >> "$NULL_TEST_DIALOG_LOG"; exit 1'
# Creates the partition nodes a real parted would, so the installer's check that
# they appeared is genuinely exercised rather than skipped.
stub parted '
dev=""
for a in "$@"; do [[ "$a" == /* && -e "$a" ]] && { dev="$a"; break; }; done
if [[ "$*" == *mkpart* && -n "$dev" ]]; then
  n=1; while [[ -e "${dev}${n}" ]]; do n=$((n + 1)); done
  mknod "${dev}${n}" b 253 "$n"
fi
exit 0'
stub wipefs  'exit 0'
stub udevadm 'exit 0'
stub mkfs.fat  'exit 0'
stub mkfs.ext4 'exit 0'
stub bootctl   'exit 0'
stub lsblk 'exit 0'          # -nro PKNAME on a node with no parent prints nothing
stub findmnt '
# The installer asks twice: for the source behind a mount point, and for every
# mounted source. A busy run answers with the target device to prove the
# installer refuses it.
if [[ -n "${NULL_TEST_BUSY:-}" ]]; then printf "%s\n" "$NULL_TEST_DISK"; fi
exit 0'
stub blkid 'printf "11111111-2222-3333-4444-555555555555\n"'
stub genfstab 'printf "# fake fstab\nUUID=11111111-2222-3333-4444-555555555555 / ext4 defaults 0 1\n"'
stub mount '
target="${@: -1}"
mkdir -p "$target"
printf "mount %s\n" "$target" >> "$NULL_TEST_MOUNT_LOG"
exit 0'
stub umount '
printf "umount %s\n" "$*" >> "$NULL_TEST_MOUNT_LOG"
exit 0'

# Stands in for pacstrap: lays down the parts of a base system the installer
# checks for, and nothing else.
stub pacstrap '
[[ -n "${NULL_TEST_FAIL_PACSTRAP:-}" ]] && { echo "pacstrap: simulated failure" >&2; exit 1; }
target=""
for a in "$@"; do [[ "$a" == /* && -d "$a" ]] && { target="$a"; break; }; done
mkdir -p "$target"/{etc,boot,usr/bin,usr/share,home,run,var/lib}
: > "$target/boot/vmlinuz-linux"
: > "$target/boot/initramfs-linux.img"
: > "$target/etc/passwd"
exit 0'

# Stands in for the configuration run inside the chroot. It creates what
# postinstall.sh creates, so verify_install is exercised against a realistic
# result rather than against an empty tree.
stub arch-chroot '
target="$1"
[[ -n "${NULL_TEST_FAIL_CHROOT:-}" ]] && { echo "chroot: simulated failure" >&2; exit 1; }
mkdir -p "$target/etc/sudoers.d" "$target/home/tester"
printf "tester:x:1000:1000::/home/tester:/bin/bash\n" >> "$target/etc/passwd"
printf "%%wheel ALL=(ALL:ALL) ALL\n" > "$target/etc/sudoers.d/01-wheel"
if [[ -z "${NULL_TEST_SKIP_BOOT_ENTRY:-}" ]]; then
  mkdir -p "$target/boot/loader/entries"
  printf "title Null Linux\n" > "$target/boot/loader/entries/null-linux.conf"
fi
exit 0'

# ── one run of the installer, fully isolated ─────────────────────────────────
# Prints its combined output; the caller inspects that and the recorded logs.
run_install() {
  local name="$1"; shift
  local case_dir="$WORK/case-$name"
  rm -rf "$case_dir"; mkdir -p "$case_dir"

  cat > "$case_dir/script" <<'INNER'
set -uo pipefail
cd "$CASE_DIR"
mkdir -p dev target
mknod dev/vdz b 253 0
: > "$NULL_TEST_DIALOG_LOG"
: > "$NULL_TEST_MOUNT_LOG"
cat > answers <<EOF
disk=$CASE_DIR/dev/vdz
confirm_destroy_device=$CASE_DIR/dev/vdz
hostname=nulltest
username=tester
timezone=UTC
user_password=not-a-real-password
third_party_repos=false
EOF
NULL_TEST_DISK="$CASE_DIR/dev/vdz" \
"$INSTALLER" --unattended "$CASE_DIR/answers"
echo "EXIT=$?"
INNER

  PATH="$STUBS:$PATH" \
  CASE_DIR="$case_dir" \
  INSTALLER="$INSTALLER" \
  NULL_SRC_ROOT="$SRC_ROOT" \
  NULL_TARGET="$case_dir/target" \
  NULL_LOG="$case_dir/install.log" \
  NULL_TEST_DIALOG_LOG="$case_dir/dialog.log" \
  NULL_TEST_MOUNT_LOG="$case_dir/mount.log" \
  env -u NULL_ROLE_DIR -u NULL_STATE_DIR -u NULL_PACMAN -u NULL_PACMAN_PREFIX \
      -u NULL_LIB_DIR -u NULL_SHARE_DIR -u NULL_DATA_DIR -u NULL_SKEL_DIR \
      -u NULL_BIN_DIR \
      "$@" "${UNSHARE[@]}" bash -c '
        if [[ -n "${NULL_TEST_FAKE_SYS:-}" ]]; then
          mount -t tmpfs none /sys && mkdir -p /sys/firmware/efi/efivars
        fi
        exec fakeroot bash "$1"' _ "$case_dir/script" 2>&1
}

exit_code_of() { sed -n 's/^EXIT=//p' <<<"$1" | tail -1; }
dialog_calls() { wc -l < "$WORK/case-$1/dialog.log"; }

printf '\n\033[1mInstaller — unattended path\033[0m\n'

# ── 1. a run that succeeds ───────────────────────────────────────────────────
out="$(run_install success)"
[[ "$(exit_code_of "$out")" == 0 ]] \
  && ok "a complete unattended install exits 0" \
  || { bad "a complete unattended install exits 0"; printf '%s\n' "$out" | tail -25; }
grep -q 'installed and verified' <<<"$out" \
  && ok "success is reported as text, not as a dialog" \
  || bad "success is reported as text, not as a dialog"
[[ "$(dialog_calls success)" -eq 0 ]] \
  && ok "no dialog is opened during an unattended run" \
  || { bad "no dialog is opened during an unattended run"; cat "$WORK/case-success/dialog.log"; }
grep -q 'umount -R' "$WORK/case-success/mount.log" \
  && ok "the target is unmounted after a successful install" \
  || bad "the target is unmounted after a successful install"

# ── 2. a run that fails part-way ─────────────────────────────────────────────
out="$(run_install pacstrap-fails NULL_TEST_FAIL_PACSTRAP=1)"
[[ "$(exit_code_of "$out")" != 0 ]] \
  && ok "a failed base installation exits nonzero" \
  || bad "a failed base installation exits nonzero"
grep -q 'Installation aborted' <<<"$out" \
  && ok "the failure names the step that failed" \
  || bad "the failure names the step that failed"
grep -q 'installed and verified' <<<"$out" \
  && bad "a failed run never claims success" \
  || ok "a failed run never claims success"
# Mounts must come apart in the reverse of the order they went on.
mlog="$WORK/case-pacstrap-fails/mount.log"
mounts="$(grep -c '^mount ' "$mlog")"
[[ "$mounts" -eq 2 ]] \
  && ok "both filesystems were mounted before the failure" \
  || bad "both filesystems were mounted before the failure (saw $mounts)"
first_umount="$(grep -m1 '^umount' "$mlog" | grep -o '[^ ]*$')"
[[ "$first_umount" == */target/boot ]] \
  && ok "cleanup unmounts in reverse order (boot first)" \
  || bad "cleanup unmounts in reverse order (boot first; saw '$first_umount')"
[[ "$(dialog_calls pacstrap-fails)" -eq 0 ]] \
  && ok "no dialog is opened on the failure path" \
  || bad "no dialog is opened on the failure path"

# ── 3. a run that finishes but does not verify ───────────────────────────────
out="$(run_install unverified NULL_TEST_SKIP_BOOT_ENTRY=1)"
[[ "$(exit_code_of "$out")" != 0 ]] \
  && ok "an unverifiable install exits nonzero" \
  || bad "an unverifiable install exits nonzero"
grep -q 'VERIFICATION FAILED' <<<"$out" \
  && ok "verification failure is reported" \
  || bad "verification failure is reported"
grep -q 'boot entry missing' <<<"$out" \
  && ok "the report names the missing piece" \
  || bad "the report names the missing piece"
grep -q 'installed and verified' <<<"$out" \
  && bad "an unverified install must not claim success" \
  || ok "an unverified install does not claim success"

# ── 4. a target that the running system is using ─────────────────────────────
out="$(run_install busy-disk NULL_TEST_BUSY=1)"
[[ "$(exit_code_of "$out")" != 0 ]] \
  && ok "a device in use is refused" \
  || bad "a device in use is refused"
grep -q 'in use by the running system' <<<"$out" \
  && ok "the refusal says why" \
  || bad "the refusal says why"
[[ ! -s "$WORK/case-busy-disk/mount.log" ]] \
  && ok "nothing was mounted before the refusal" \
  || bad "nothing was mounted before the refusal"

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[[ $FAIL -eq 0 ]]
