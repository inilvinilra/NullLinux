# Null Linux — Baseline Audit (P0)

Audit date: 2026-08-13. Scope: full working tree as delivered.

Every number and defect below was verified against the source tree. Claims that could not be
verified in this environment are listed under [Blocked verification](#blocked-verification) and
are **not** asserted as true or false.

## 1. Verified current state

| Fact | Value | How verified |
| --- | --- | --- |
| Roles | **13** | `config/roles/*.yml` |
| Role package entries | **497** | sum of `^  - ` lines |
| Unique package names | **439** | sorted unique across all roles |
| Packages shared by ≥2 roles | **54** | `uniq -d` across roles |
| Custom desktop entries | **29** | `iso/airootfs/usr/share/nulllinux/desktop-entries/` |
| KDE menu categories | **9** of 13 roles | `usr/share/desktop-directories/` |
| Role metapackages | 13 PKGBUILDs | `src/roles/` |
| Tracked files | 162 | `find . -type f` |
| Shell syntax errors | 0 | `bash -n`, all 18 scripts |
| Role YAML parse errors | 0 | PyYAML |
| Desktop entries failing `desktop-file-validate` | **29 of 29** | run in this audit |

The prompt's stated counts (13 / ~497 / ~439 / 29) are **confirmed exactly**.

Working-tree note: this checkout is an extracted snapshot, **not a git repository**. Branch,
tag, commit and CI run history could not be inspected locally.

### Architecture as it stands

Archiso profile (`iso/`) + BIOS/UEFI live boot + KDE Plasma live session + three Bash tools
(`null-install` 406 lines, `null-setup` 463, `null-toolkit` 473) + 13 role manifests + 13 role
metapackages + 3 GitHub Actions workflows + Dockerfile + QEMU helpers.

Role data exists in **three** hand-synced copies: `config/roles/*.yml`,
`iso/airootfs/etc/nulllinux/roles.d/*.yml`, and `depends=()` in `src/roles/*/PKGBUILD`.
All three are currently identical — which is luck, not a mechanism. The tool binaries are
likewise duplicated between `src/` and `iso/airootfs/usr/bin/`, and one copy **has already
drifted** (`null-setup.desktop`).

## 2. Risk-ranked findings

Severity: **S1** blocks any release · **S2** blocks stable · **S3** correctness/maintenance.

### S1 — Installer can destroy the wrong data or produce an unusable system

**S1-01 Disk selection parses the wrong column and offers unsafe targets.**
`src/installer/null-install:105-122` parses `lsblk -dpno NAME,TYPE,TRAN,SIZE` and reads size from
`$4`. `TRAN` is empty for many devices, so the field shifts. Reproduced on the audit host: a
**zram device was listed as an installable target with a blank size**. Filtering is
`grep 'disk' | grep -v 'loop\|sr\|rom'`, a substring match over the whole line. There is **no
exclusion of the live medium**, no mounted-device check, no minimum-size check, and no existing-OS
or LUKS/LVM/BitLocker detection. A user can select the USB stick they booted from.

**S1-02 Unvalidated user input is interpolated into a root-executed script.**
`null-install:150-167` accepts hostname and username from `dialog --inputbox` with **no
validation whatsoever**, then expands them unquoted into a generated heredoc
(`null-install:202-279`, e.g. `useradd … "${USERNAME_VALUE}"`, the `/etc/hosts` block) which is
executed as root via `arch-chroot`. A username containing shell metacharacters executes arbitrary
commands as root on the target. Same defect in `iso/airootfs/usr/local/bin/null-bootstrap:37-101`.

**S1-03 No cleanup or rollback on failure.** `null-install` has no `trap`. Any failure after
`partition_disk` (`:129-148`) leaves `/mnt` and `/mnt/boot` mounted, the disk repartitioned, and
password-hash files on the target. There is no install plan, no step verification, no rollback.

**S1-04 Success is reported unconditionally.** `show_complete` (`:354-369`) always claims success
and asserts facts it never verified ("Firewall: ufw (enabled)", "Boot: systemd-boot"). No
post-install validation runs.

**S1-05 Installed system has no Null Linux identity.** The installer never installs
`/etc/os-release`, `/etc/issue`, `/etc/motd`, Plymouth theme, or SDDM config to the target.
`pacstrap` provides Arch's `/etc/os-release`, so **an installed "Null Linux" identifies as Arch
Linux**.

**S1-06 Installed KDE ≠ live KDE.** `null-install:336-349` copies a hand-picked subset of
`/etc/skel`. Not copied, verified by comparison: `plasma-org.kde.plasma.desktop-appletsrc`
(**the entire panel layout**), `.bashrc`, `konsolerc`, `ksplashrc`, `powerdevilrc`, `kwalletrc`,
`kactivitymanagerdrc`. The advertised desktop does not survive installation.

**S1-07 Live-only autostart leaks into the installed system.** `.config/autostart` *is* in the
copy list, and `iso/airootfs/etc/skel/.config/autostart/null-setup.desktop` carries no autostart
condition, so the wizard launches **on every login, forever**. `null-setup` writes its marker only
at `:455-456` after the menu loop, and nothing ever reads it to suppress launch.

**S1-08 BIOS installation is claimed but refused.** `README.md` advertises "BIOS + UEFI boot
support"; `null-install:375-379` exits if `/sys/firmware/efi/efivars` is absent. Live BIOS boot
works; BIOS *installation* does not exist.

**S1-09 Encryption and Btrfs are absent.** The installer is ext4-only, unconditionally
(`:132-143`). No LUKS2, no Btrfs, no subvolumes, no zram, no swap. `cryptsetup` is not even in
`iso/packages.x86_64`.

### S1 — Package engine reports false success

**S1-10 Partial upgrades at runtime.** `pacman -Sy` followed by installs at
`null-toolkit:181,200` and `null-setup:105,124`. Also `Dockerfile:18` and
`scripts/setup-libvirt-host.sh:73`.

**S1-11 AUR results are never verified, and success is discarded.** `null-toolkit:209-233` /
`null-setup:133-157`: the AUR call's failure is swallowed by `|| echo "AUR skip"`, and then
`lang_fallback_install` runs **even when the AUR install succeeded**. It returns 1 for any package
not in its hardcoded list, so the package is appended to `unresolved_pkgs` regardless of outcome.
No `pacman -Qi` re-check follows. The result set is wrong in both directions.

**S1-12 Role markers are written even when everything fails.** `install_packages` always returns 0
(`null-toolkit:236-240`); `cmd_install` then writes the marker and prints "installed
successfully" (`:273-277`). `null-setup` does the same at `:278` and `:376`, inside a pipeline to
`dialog --programbox` where the exit status is `dialog`'s anyway. Failures cannot propagate.

**S1-13 Role removal deletes shared packages.** `cmd_remove:301` runs
`pacman -Rns --noconfirm` over the role's entire package list with `2>/dev/null`, then prints a
reassuring message. **54 packages belong to more than one role.** There is no ownership graph, no
dry-run, no distinction between role-requested, shared, and independently installed packages.

**S1-14 Three incompatible state conventions.** `null-toolkit` reads
`/etc/nulllinux/roles/<role>.installed`; the metapackages install
`/etc/nulllinux/roles.d/<role>.installed`; `null-setup` uses
`$HOME/.config/nulllinux-role-<role>`. A role installed by metapackage is invisible to the role
manager. State is marker-derived, never derived from actual package state.

**S1-15 Unpinned language-manager installs as root.** `null-toolkit:25-78` runs
`pip install --break-system-packages`, `go install …@latest` into `/usr/local/bin`, and
`cargo install` with no version pin, as root, outside pacman's knowledge.

### S1 — Supply chain

**S1-16 `curl | bash` in the build path.** `.github/workflows/build-iso.yml:24`,
`Dockerfile:10`, `README.md:46`.

**S1-17 Third-party repo key trusted by short ID.** `3056513887B78AEB` (16-hex, not a full
fingerprint) fetched from a keyserver and `--lsign`ed, then packages installed by URL with no
checksum — `build-iso.yml:26-32`, `Dockerfile:11-15`, `README.md:48-53`.

**S1-18 Build mutates the host.** `scripts/build-iso.sh:19-35` writes host
`/etc/pacman.d/mirrorlist`, `blackarch-mirrorlist`, `chaotic-mirrorlist`; the script also
auto-escalates with `exec sudo` (`:37-40`).

**S1-19 Fork PRs build untrusted PKGBUILDs.** `build-packages.yml` triggers on `pull_request`,
runs a privileged `archlinux:latest` container, grants `builder` NOPASSWD sudo, and runs
`makepkg` on the PR's own PKGBUILD. No workflow declares `permissions:`, `concurrency:`, or
`timeout-minutes:`, and every action is a floating `@v4`/`@v2` tag.

**S1-20 Third-party repos enabled without consent.** BlackArch and Chaotic-AUR are enabled in the
live `pacman.conf`, copied verbatim to the target (`null-install:283`), appended by
`null-bootstrap`, and their keyrings are `pacstrap`ed into every installation.

### S2 — Security posture and desktop correctness

**S2-01 Hardened SSH config never reaches the target.**
`iso/airootfs/etc/ssh/sshd_config.d/10-null-linux.conf` (`PasswordAuthentication no`,
`PermitRootLogin no`) is live-only. `openssh` is installed on the target with upstream defaults.
The service is not enabled, so nothing listens — but README's "SSH key-only" is false for
installed systems.
**S2-02 Live session is X11, not Wayland.** `customize_airootfs.sh` autologin sets
`Session=plasmax11`.
**S2-03 Performance tuning shipped as "hardening".** `99-nulllinux-perf.conf` sets only
`vm.*` knobs; no security sysctls, no AppArmor, no lockdown, no profiles.
**S2-04 Both microcode packages installed and both `initrd` lines emitted**
(`null-install:173-185`, `:269-276`) with no CPU detection.
**S2-05 Firefox policies ship pre-set bookmarks** pointing at the project repo.
**S2-06 `kded5rc` in a Plasma 6 skel** — Plasma 6 reads `kded6rc`.

### S3 — Metadata and documentation

**S3-01 All 29 desktop entries fail validation** — unregistered `NullLinux-*` categories without
the required `X-` prefix, and no registered main category.
**S3-02 No entry declares `TryExec`** → entries persist for uninstalled tools.
**S3-03 The alpm hook has no `Operation = Remove`** — entries are never removed. Its matcher is
also a substring match, so installing `tor` can install the Tor **Browser** entry.
**S3-04 Launchers run privileged/instantly-closing commands** — e.g.
`Exec=konsole -e sudo tcpdump --help`; no `--hold`, so errors flash and vanish.
**S3-05 README says 9 roles; there are 13.** `crypto`, `devtools`, `essentials`, `reversing` have
no KDE category and are absent from the documented role list. `docs/roadmap.md` marks Phase 3–5
"DONE" and claims "13 tool .desktop entries" (there are 29).
**S3-06 `null-setup` claims "500+ packages"** — 439 unique / 497 entries.
**S3-07 Stale `xredjhon/NullLinux` identity in 21 files.** *(fixed in this change set)*
**S3-08 Artwork provenance undocumented** — 5 PNGs, ~10 MB, no source/license/ownership record.
The logo's resemblance to the Arch logo needs a documented branding review (not a legal opinion).

## 3. Blocked verification

Not runnable here; **not** claimed either way.

| Item | Blocker | Command once available |
| --- | --- | --- |
| ISO builds | no `mkarchiso`, `xorriso` | `pacman -S archiso`, `./scripts/build-iso.sh` |
| Live/installed boot | no `qemu-system-x86_64`, no OVMF | `pacman -S qemu-desktop edk2-ovmf` |
| ShellCheck findings | not installed | `pacman -S shellcheck` |
| PKGBUILD/namcap | not installed | `pacman -S namcap` |
| Workflow lint | no `actionlint` | `pacman -S actionlint` |
| Whether the 439 packages exist | needs a synced Arch/BlackArch/Chaotic DB | `pacman -Si` per name |
| Why `update-check` fails | needs CI logs / a git remote | see below |
| CI run history | not a git repo | `gh run list` |

`update-check.yml` has two concrete failure candidates, both unconfirmed: `pip install nvchecker`
against a PEP 668 system Python on `ubuntu-latest`, and `nvchecker.toml`'s `source = "github"`
entries with no `GITHUB_TOKEN` keyfile (rate-limited/401). Its `[null-toolkit]` entry also tracked
a repository path that does not match the canonical project. `oldver.json` is `{}`, so `nvcmp`
has no baseline, and the job ends with `git push || true`, which hides failure.

## 4. Ordered P0 plan

Dependency order. Each step ends with `./tools/lint.sh` plus its own tests.

1. **Validation gate** — encode the rules so regressions are mechanical. *(done)*
2. **Canonical identity** — one owner string, gate-enforced. *(done)*
3. **Single source of truth** — `manifests/roles/*.yml` as the only role data; generate
   `roles.d/`, PKGBUILD `depends()`, KDE categories, docs counts; CI fails on drift.
4. **Package engine rewrite** — no `-Sy`; structured
   `complete|partial|failed|canceled|unchanged`; verify every install with `pacman -Qi`; required
   failures block the marker; drop the language-manager fallback.
5. **Ownership graph + safe removal** — derive state from package state; dry-run; never remove
   shared or independently installed packages; one state convention.
6. **One-shot first run** — systemd user unit with `ConditionPathExists`, manually relaunchable.
7. **Installer safety** — input validation, no interpolation of user data into generated scripts,
   structured device enumeration, live-medium exclusion, typed destructive confirmation, `trap`
   cleanup, install plan with per-step verification, honest completion report.
8. **Installed-system consistency** — package identity/KDE defaults/branding/security config
   instead of copying live files; CPU-specific microcode; hardened SSH config; no live autologin.
9. **Build & CI hardening** — no host mutation, no `curl | bash`, full fingerprints, pinned
   action SHAs, least-privilege tokens, no fork-PR package builds.
10. **Desktop metadata** — `X-NullLinux-*` categories, `TryExec`, removal hook, safe launchers,
    categories for all 13 roles.
11. **QEMU integration tests** — UEFI live boot, UEFI install + reboot from disk, cancellation,
    failure cleanup.

P1 and later (encryption/UKI/Secure Boot, signed repository, Qt control center, threat model,
hardware matrix) stay untouched until the P0 gate is green.

## 5. Decisions recorded in this change set

**Validation gate in Bash, not a typed language.** The rules are file-shaped and must run on a
bare Arch host and in CI with no toolchain. Migration to a typed implementation is warranted for
the *installer planner* (stateful, security-sensitive), not for a linter. Rollback: delete
`tools/`.

**Canonical owner = `inilvinilra/NullLinux`,** taken from the project brief. This is a branding
decision the maintainer owns; it is a single reversible `sed`, and `tools/lint.sh` honours
`NULL_CANONICAL_REPO` if it changes.

**Gate fails loudly rather than warning.** A warning-only linter on a project that already
documents unfinished work as "DONE" would not change outcomes.
