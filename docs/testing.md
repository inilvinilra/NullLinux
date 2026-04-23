# Testing

## Prerequisites

Ensure BlackArch and Chaotic-AUR keyrings are installed on the build host.
See README.md for setup instructions.

## Build

```bash
./scripts/check-host.sh
./scripts/build-iso.sh
```

## Boot Test

```bash
./scripts/run-qemu.sh            # BIOS
./scripts/run-qemu-uefi.sh       # UEFI
```

## Smoke Test Checklist

### Boot
- [ ] Plymouth splash appears briefly
- [ ] Boot menu appears (Syslinux/BIOS, systemd-boot/UEFI)
- [ ] Kernel and initramfs load

### Desktop
- [ ] SDDM autologins user `null`
- [ ] KDE Plasma desktop with dark theme
- [ ] Papirus-Dark icons visible
- [ ] NullLinux wallpaper set
- [ ] Panel layout: app launcher, task bar, system tray, clock
- [ ] null-welcome launches on first login

### Networking & Security
- [ ] NetworkManager connects (`nmcli`)
- [ ] `pacman -Sy` refreshes all repos (core, extra, multilib, blackarch, chaotic-aur)
- [ ] `ufw status` shows active with deny incoming
- [ ] `ssh` rejects password login

### Tools
- [ ] `null-toolkit list` shows 9 roles as available
- [ ] `sudo null-toolkit install network` installs packages
- [ ] `null-toolkit info network` shows package status
- [ ] Installed tools appear in KDE menu under Null Linux Security

### Installer
- [ ] `null-install` launches dialog TUI (do not run full install in QEMU)
- [ ] `null-bootstrap` still works as fallback

### Docker
- [ ] `docker build -t nulllinux .` succeeds
- [ ] `docker run -it nulllinux null-toolkit list` shows roles
