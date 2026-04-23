# Null Linux Tool Categories

This document defines the initial menu taxonomy for security tooling in the KDE desktop.

## Categories

- Red Team
- Blue Team
- OSINT
- OPSEC
- Network

## Current Implementation

- Launcher script: `iso/airootfs/usr/local/bin/null-tools-menu`
- Desktop entries: `iso/airootfs/usr/share/applications/nulllinux-*.desktop`
- Menu definition: `iso/airootfs/etc/xdg/menus/applications-merged/nulllinux-tools.menu`
- Category directory metadata: `iso/airootfs/usr/share/desktop-directories/nulllinux-*.directory`

## Notes

- Current menu entries are category launchers that display tool availability.
- External toolbox discovery supports `/home/tools` and `/home/user/tools`.
- Tool bundles and package layering will be expanded in the next milestone.
