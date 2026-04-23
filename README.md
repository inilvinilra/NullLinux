# Null Linux

Null Linux is an Arch-based cybersecurity distribution with a KDE Plasma dark desktop,
role-based security tooling, and access to Arch, BlackArch, and Chaotic-AUR repositories.

## Features

- **Arch-based** rolling release with Arch + BlackArch + Chaotic-AUR repos
- **KDE Plasma** dark desktop (Breeze Dark theme, Papirus-Dark icons)
- **9 security roles** — Red Team, Blue Team, OSINT, OPSEC, Network, Forensics, Web, Wireless, Exploitation
- **null-toolkit CLI** — install/remove security tool categories on demand
- **null-install TUI** — dialog-based installer with role selection
- **Hardened defaults** — ufw firewall, SSH key-only, restrictive file permissions
- **Plymouth** branded boot splash
- **BIOS + UEFI** boot support
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

BlackArch and Chaotic-AUR keyrings must be installed on the build host:

```bash
# BlackArch
curl -sL https://blackarch.org/strap.sh | sudo bash

# Chaotic-AUR
sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key 3056513887B78AEB
sudo pacman -U \
  'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
  'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
```

## Build

```bash
./scripts/build-iso.sh
```

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

Available: `redteam` `blueteam` `osint` `opsec` `network` `forensics` `web` `wireless` `exploitation`

## Docker

```bash
docker build -t nulllinux .
docker run -it nulllinux
```

## Live Environment

- User: `null` (passwordless, NOPASSWD sudo)
- Desktop: KDE Plasma (Breeze Dark)
- Firewall: ufw (deny incoming, allow outgoing)
- SSH: key-based only
- Welcome app launches on first login

## Roadmap

See `docs/roadmap.md`.

## License

This project is provided as-is for educational and security research purposes.
