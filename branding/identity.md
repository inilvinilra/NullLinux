# Null Linux Identity

- Distribution name: Null Linux
- ISO name: `null-linux`
- Publisher: `Null Linux Project`
- Live hostname: `null`
- Live user: `null` (passwordless, sudo via NOPASSWD)
- Desktop: KDE Plasma
- Display manager: SDDM
- Design direction: dark, minimal, low-noise cybersecurity workstation
- Boot: systemd-boot (UEFI) + Syslinux (BIOS)

The first release intentionally avoids heavy theming. The goal is a quiet base image
that is easy to extend later with role-based security tooling.
