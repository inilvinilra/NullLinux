# Null Linux

Null Linux is a minimal Arch-based live distribution project.

Current scope:
- bootable live ISO
- KDE Plasma desktop
- SDDM login manager
- minimal branding and sane defaults
- manual bootstrap path for installed systems

Not included yet:
- installer
- custom package repository
- advanced hardening

## Repository Layout

- `iso/`: archiso profile and live root filesystem
- `scripts/`: build helpers
- `docs/`: project notes and roadmap
- `branding/`: branding notes and assets placeholders

## Build Requirements

Build on an Arch-based host with:
- `archiso`
- `git`
- `qemu-desktop`
- `rsync`
- `syslinux`
- `xorriso`
- `squashfs-tools`
- `edk2-ovmf` for UEFI testing

## Build

```bash
./scripts/build-iso.sh
```

Optional clean rebuild:

```bash
./scripts/build-iso.sh --clean-work
```

Optional NullWelcome GUI staging:

```bash
./scripts/integrate-nullwelcome.sh --from-local /path/to/NullWelcome
```

By default, artifacts are written to `out/` and temporary build files to `work/`.

## Quick Test

```bash
./scripts/smoke-test.sh
./scripts/check-host.sh
./scripts/run-qemu.sh
./scripts/run-qemu-uefi.sh
```

## Install Path

The current install path is a live-environment bootstrap helper:

```bash
null-bootstrap
```

See `docs/manual-install.md` for the expected mount layout.

## Operational Docs

- Tool taxonomy and menu structure: `docs/tool-categories.md`
- Release validation checklist: `docs/release-checklist.md`
- Release prep handover: `docs/release-prep.md`
- Null Welcome module plan: `docs/null-welcome-module.md`
- Null Welcome catalog notes: `docs/null-welcome-catalog-notes.md`

## Milestone

`v0.1.0-alpha` target:
- ISO builds successfully
- boots into a live environment
- shows an SDDM login screen
- basic networking works through NetworkManager

## Current Platform Defaults

- Arch + BlackArch repositories enabled in the ISO profile
- KDE dark-first defaults for live user profile
- Category-based Null Linux menu entries:
  - Red Team
  - Blue Team
  - OSINT
  - OPSEC
  - Network
- External tool path discovery for category launchers:
  - `/home/tools`
  - `/home/user/tools`
- Null Welcome entrypoint:
  - `/usr/local/bin/null-welcome`
  - `/usr/local/bin/null-welcome-install`
