# Null Linux Roadmap

## Phase 1 — Foundation (DONE)

- [x] Bootable live ISO with KDE Plasma
- [x] Passwordless live user with NOPASSWD sudo
- [x] SSH hardened (key-only, MaxAuthTries 3)
- [x] Branding aligned to KDE target
- [x] XFCE autostart entries removed
- [x] QEMU scripts deduplicated via shared helper
- [x] Package list cleaned (grub removed, openssh/iwd added)
- [x] ufw firewall enabled by default
- [x] Restrictive file permissions in profiledef.sh

## Phase 2 — Mirrors & Repository Infrastructure (DONE)

- [x] BlackArch repository and mirrors
- [x] Chaotic-AUR repository and mirrors
- [x] rate-mirrors in build script
- [x] GitHub Actions ISO build workflow
- [x] SHA256 checksums for ISO

## Phase 3 — Tool Categories & Menus (DONE)

- [x] 9 cyber role definitions (YAML configs)
- [x] 9 metapackage PKGBUILDs
- [x] KDE XDG menu system (10 .directory + .menu file)
- [x] 13 tool .desktop entries with category tags
- [x] null-toolkit CLI (install/remove/list/info/update)

## Phase 4 — Desktop Experience & Branding (DONE)

- [x] KDE Plasma dark theme (Breeze Dark + Papirus-Dark)
- [x] KDE panel layout preset with NullLinux wallpaper
- [x] SDDM autologin + Breeze theme
- [x] Konsole dark profile (NullLinux.profile)
- [x] Styled .bashrc with security aliases
- [x] Plymouth boot splash with logo
- [x] systemd-boot/Syslinux quiet splash entries
- [x] Wallpapers and logo bundled in ISO

## Phase 5 — Installer, Hardening & CI (DONE)

- [x] null-install TUI installer (dialog-based, role selection)
- [x] Package build CI workflow (detect changed PKGBUILDs, matrix build)
- [x] nvchecker upstream version tracking (daily cron)
- [x] Dockerfile for base image
- [x] All documentation updated

## Future

- [ ] Custom NullLinux package hosting (R2 or GitHub Pages)
- [ ] GPG package signing infrastructure
- [ ] Secure Boot / UKI support
- [ ] WSL distribution image
- [ ] VM prebuilt images (VirtualBox OVA)
- [ ] Nix-based variant
- [ ] Community contribution guide
