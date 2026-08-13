# Architecture

How Null Linux is put together, which invariants hold it together, and where it
should change next.

## Shape

```
config/                 canonical data
   roles/*.yml            role identity, menu metadata, package list
   desktop-entries.yml    tool launchers
        │
        │  tools/generate.py
        ▼
generated artefacts (committed, checked in CI)
   iso/airootfs/usr/share/nulllinux/roles/*.role      runtime role data
   iso/airootfs/usr/share/nulllinux/desktop-entries/  launchers
   iso/airootfs/usr/share/desktop-directories/        KDE categories
   iso/airootfs/etc/xdg/menus/…/nulllinux-security.menu
   src/roles/nulllinux-*/PKGBUILD                     metapackages
   docs/roles.md                                      catalog

src/                    the programs
   lib/nulllinux-pkg.sh       package engine, role state, ownership
   lib/nulllinux-validate.sh  input validation, device naming
   installer/null-install     interactive and unattended installation
   installer/postinstall.sh   runs inside the target, values via environment
   tools/null-toolkit         role manager
   tools/null-setup           first-run wizard
   tools/null-repo            third-party repository trust

iso/                    live-only configuration, packages, boot entries
        │
        │  tools/stage-profile.sh   (iso/ + src/ → complete archiso profile)
        ▼
   mkarchiso → ISO
```

## Invariants

These are enforced by `tools/lint.sh`, which the build runs before it starts.
Each one exists because its absence caused a real defect.

1. **One source of truth.** Role and launcher data live in `config/`. Everything
   derived is generated; CI fails if the tree is stale. Role data previously
   existed in three hand-synced copies.
2. **No program is stored twice.** Executables live in `src/` and reach the
   image through staging. Nothing under `iso/` may share a name with a file in
   `src/`.
3. **No partial upgrades.** Nothing runs `pacman -Sy` followed by an install.
4. **No unverified remote execution.** No build or runtime path pipes a
   downloaded script into a shell.
5. **No untracked system packages.** No pip, go or cargo installs behind
   pacman's back.
6. **Installation results are verified, never assumed.** Every install is
   checked against the package database, not against an exit code.
7. **The first-run wizard runs once** and stays launchable by hand.
8. **Launchers are honest.** Every entry declares `TryExec`, none invokes
   `sudo`, and entries appear only for packages that are installed.
9. **The build does not touch the host.** No host mirror or pacman
   configuration is modified.
10. **Documented counts come from generated data.**

## Package engine

`src/lib/nulllinux-pkg.sh` is the only place that installs or removes anything.

**Results are structured**: `complete`, `partial`, `failed`, `canceled`,
`unchanged`, returned as exit codes and surfaced by every caller. A role is
recorded as installed only when every one of its packages is present.

**State is derived, not asserted.** `role_status` asks the package database
first: a role installed through its metapackage reports `metapackage`, a role
whose packages are all present without a state file reports `satisfied`, and a
state file whose packages have since been removed reports `degraded`. State
files record only what this tool installed, so removal can tell our packages
from the user's.

**Removal computes ownership.** `role_removable` excludes anything another
active role needs and anything we did not install. With 54 packages shared
between roles, the previous behaviour — `pacman -Rns` over a role's full list —
would remove another role's tools.

Every one of these paths is exercised in `tests/run-tests.sh` against a stub
pacman, so the logic is testable without root, network or a real transaction.

## Installer

The installer is the only component that destroys data, so it is built around
refusing rather than trusting.

- **Selection excludes** the live medium, every disk backing a mounted
  filesystem, read-only devices, pseudo devices and anything under 20 GB.
- **Input is validated** against C-collation patterns before it is used, and is
  passed to `postinstall.sh` as environment variables. Nothing the user types is
  ever interpolated into a script that runs as root.
- **Secrets move over file descriptors.** Password hashes are written with a
  restrictive umask and consumed by `chpasswd -e`, never placed on a command
  line, and removed on every exit path including signals.
- **Steps are unwound.** Mounts are tracked and released in reverse on failure.
- **Success is earned.** The target is checked for identity, fstab, kernel,
  initramfs, boot entry, user and sudo policy before anything reports success.
- **Unattended mode** exists for tests and applies the same validation, plus a
  requirement that the answer file name the target device twice.

## The live/installed boundary

The live image has autologin and passwordless sudo. Neither may reach an
installed system, and the install test asserts that they do not. The installed
system receives its identity, KDE defaults, hardened sshd drop-in and tooling as
deliberate installations, not as an opportunistic copy of live files — which is
how earlier builds ended up identifying as Arch Linux with no panel layout.

## Repository trust

Only official Arch repositories are configured. `null-repo` adds a third-party
repository after verifying a full 40-hex fingerprint against the value the
project publishes; short key ids are refused because they cannot establish
trust. Every change backs up `pacman.conf` and is reversible.

Null Linux ships no fingerprint for anyone else's key. A trust anchor this
project has not verified would be worse than asking the user to check.

## Known architectural debt

**The tools are Bash.** That is defensible for the role manager and the
repository helper, which are thin wrappers over pacman. It is thinner ice for
the installer, which is stateful, privileged and destructive. The current
mitigation is that its logic is small, its risky parts are pushed into
`src/lib/` where they are unit-tested, and its dangerous operations are
guarded by validation and traps.

The migration path, when it is worth taking: move installation *planning* —
device enumeration, the step list with preconditions and rollback, and the
result report — into a typed implementation with the shell reduced to executing
a plan it did not compute. Encryption, subvolume layouts and rollback will make
the current structure too big to hold in a shell script; that is the point to
switch, not before.

**The desktop defaults are files, not a package.** They are installed by the
installer. They should be Null Linux packages so that upgrades and removals go
through pacman like everything else. This is the first item of P1.

**Nothing is signed.** No signed repository, no signed ISO, no SBOM. Until that
exists, the distribution's integrity rests entirely on Arch's signatures and on
whoever hands you the image.
