# Null Linux Roadmap

Status is claimed only for work that is implemented **and** verified. See
[audit-baseline.md](audit-baseline.md) for what has actually been tested and
what has not.

## P0 — Stabilisation (in progress)

Done and enforced by `tools/lint.sh`:

- [x] Validation gate encoding the release-blocking rules
- [x] Unit tests that need no root, network or real package transaction
- [x] One canonical source for role, package and menu data, with drift detection
- [x] Package engine: no partial upgrades, database-verified installs,
      structured complete/partial/failed/canceled/unchanged results
- [x] Ownership graph so removing a role cannot remove another role's packages
- [x] Role state derived from the package database instead of marker files
- [x] One-shot first-run wizard that stays available by hand
- [x] Installer input validation and no interpolation of input into root scripts
- [x] Installer device filtering that excludes the live medium and mounted disks
- [x] Installer cleanup traps and post-install verification before claiming success
- [x] Installed systems receive Null Linux identity and the full KDE defaults
- [x] CPU-specific microcode instead of installing both
- [x] Desktop entries valid, with TryExec, safe launchers and removal on uninstall
- [x] Third-party repositories opt-in, behind full-fingerprint verification
- [x] CI pinned to commit SHAs, least-privilege tokens, no fork-PR package builds
- [x] Build no longer executes piped remote scripts or edits host configuration
- [x] ISO profile actually builds

Remaining before P0 is complete:

- [ ] Automated UEFI live-boot test in CI
- [ ] Automated install-to-disk test, reboot from the installed disk
- [ ] Installer cancellation and failure-cleanup tests
- [ ] Package availability check for all catalogued packages

## P1 — Trust and recovery

- [ ] Null Linux packages for identity, KDE defaults, branding and tooling,
      so installation stops copying files into place
- [ ] Signed Null Linux repository with offline root key and documented rotation
- [ ] LUKS2 + Btrfs guided installation with subvolumes and a recovery path
- [ ] Unified Kernel Images, regenerated and signed across kernel updates
- [ ] Secure Boot with controlled test keys; no automatic key enrolment
- [ ] Snapshot before high-risk transactions, with a tested rollback path
- [ ] Wayland as the default session, once a boot test proves it
- [ ] Threat model and privacy statement
- [ ] Hardware support matrix from real test results

## P2 — Scope and polish

- [ ] Security profiles (daily, research, defensive, opsec, lab) as composable units
- [ ] Native Qt control centre with a Polkit-backed privileged helper
- [ ] Rootless containers for volatile tooling; disposable VMs for malware work
- [ ] Reproducible ISO builds, SBOM and published provenance
- [ ] Original visual identity after a documented branding review

## Not planned

Kernel forks, replacing pacman, bundling every BlackArch package into the ISO,
telemetry of any kind, and claims of anonymity or undetectability.
