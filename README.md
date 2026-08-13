# Null Linux

Null Linux is an Arch-based cybersecurity distribution with a KDE Plasma dark desktop,
role-based security tooling, and access to Arch, BlackArch, and Chaotic-AUR repositories.

## Features

- **Arch-based** rolling release with Arch + BlackArch + Chaotic-AUR repos
- **KDE Plasma** dark desktop (Breeze Dark theme, Papirus-Dark icons)
- **13 tool roles** — see [docs/roles.md](docs/roles.md), generated from `config/roles/`
- **null-toolkit CLI** — install/remove security tool categories on demand
- **null-install TUI** — dialog-based installer with role selection
- **Conservative defaults** — firewall denies incoming, no service listens by default, no telemetry
- **Plymouth** branded boot splash
- **UEFI installation**; the live ISO also boots on legacy BIOS
- **CI/CD** — GitHub Actions for ISO builds and package management
- **Docker** image available

## Repository Layout

```
iso/                archiso profile, packages, boot config, live rootfs
src/
  roles/            metapackage PKGBUILDs per security role
  tools/            null-toolkit CLI
  installer/        null-install TUI installer
config/roles/       YAML role definitions
scripts/            build, test, and QEMU helpers
docs/               documentation and roadmap
branding/           identity notes
.github/workflows/  CI/CD (ISO build, package build, update checks)
.nvchecker/         upstream version tracking
```

## Build Requirements

Build on an Arch-based host with:
- `archiso`, `git`, `qemu-desktop`, `rsync`, `syslinux`, `xorriso`, `squashfs-tools`
- `edk2-ovmf` (UEFI testing)
- `rate-mirrors` (optional, build-time mirror optimization)

Third-party repositories (BlackArch, Chaotic-AUR) are **opt-in**. Enabling them
requires verifying a full key fingerprint against the project's published value —
never a short key ID, and never a piped install script. See
[docs/package-sources.md](docs/package-sources.md).

## Validate and build

```bash
./tools/lint.sh          # release-blocking rules
./tests/run-tests.sh     # unit tests, no root required
sudo ./scripts/build-iso.sh
```

The build refuses to run if the validation gate fails, and never modifies the
host's pacman or mirror configuration.

## Test

```bash
./scripts/check-host.sh
./scripts/run-qemu.sh            # BIOS
./scripts/run-qemu-uefi.sh       # UEFI
```

## Install

### TUI Installer (recommended)

```bash
sudo null-install
```

### Manual Bootstrap (advanced)

```bash
null-bootstrap
```

See `docs/manual-install.md` for partition layout.

## Security Roles

Install roles with null-toolkit:

```bash
sudo null-toolkit install redteam
sudo null-toolkit install blueteam
sudo null-toolkit install osint
null-toolkit list
null-toolkit info network
```

Available: `essentials` `devtools` `network` `web` `osint` `opsec` `redteam` `exploitation`
`blueteam` `forensics` `reversing` `wireless` `crypto`

Role removal never removes a package another installed role still needs:

```bash
sudo null-toolkit remove redteam --dry-run   # show the exact transaction first
```

## Docker

```bash
docker build -t nulllinux .
docker run -it nulllinux
```

## Live Environment

- User: `null` (passwordless, NOPASSWD sudo) — **live medium only**, never installed
- Desktop: KDE Plasma (Breeze Dark)
- Firewall: deny incoming, allow outgoing
- SSH: daemon installed but not enabled; nothing listens by default
- Setup wizard runs once on first login and stays available as `null-setup`

## Privacy

Null Linux collects nothing: no telemetry, no analytics, no crash reports, no
identifiers. See [docs/privacy.md](docs/privacy.md) for exactly what connects to
the network and when.

## Status

Alpha. See [docs/audit-baseline.md](docs/audit-baseline.md) for verified state,
known defects and the release gates that are not yet met. The ISO is unsigned;
encryption, Secure Boot and rollback are not implemented yet.

Null Linux is an independent Arch-based distribution. It is not endorsed by or
affiliated with Arch Linux, BlackArch, KDE, or any packaged upstream.

## Roadmap

See `docs/roadmap.md`.

## License

MIT (see LICENSE). Provided as-is for lawful security research and authorized
testing. You are responsible for having permission to test any system.
