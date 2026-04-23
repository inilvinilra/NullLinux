# Contributing to Null Linux

## Getting Started

1. Fork the repository
2. Clone your fork
3. Install build dependencies (see README.md)
4. Install BlackArch and Chaotic-AUR keyrings on your build host
5. Run `./scripts/check-host.sh` to verify your environment

## Building

```bash
./scripts/build-iso.sh
./scripts/run-qemu.sh       # test BIOS boot
./scripts/run-qemu-uefi.sh  # test UEFI boot
```

## Project Structure

- `iso/` — archiso profile (packages, boot config, airootfs overlay)
- `src/roles/` — metapackage PKGBUILDs for each security role
- `src/tools/` — null-toolkit CLI source
- `src/installer/` — null-install TUI installer source
- `config/roles/` — YAML role definitions (package lists)
- `scripts/` — build and test helpers

## Adding a New Tool

1. Determine which role(s) the tool belongs to
2. Add the package name to `config/roles/<role>.yml`
3. Add it to the corresponding `src/roles/nulllinux-<role>/PKGBUILD` depends array
4. Create a `.desktop` entry in `iso/airootfs/usr/share/nulllinux/desktop-entries/`
   with the appropriate `Categories=NullLinux-<Category>;` tag
5. Test: `sudo null-toolkit install <role>` and verify the tool appears in KDE menu

## Adding a New Role

1. Create `config/roles/<newrole>.yml` with name, description, and package list
2. Create `src/roles/nulllinux-<newrole>/PKGBUILD`
3. Add a `.directory` file in `iso/airootfs/usr/share/desktop-directories/`
4. Add a `<Menu>` block in `iso/airootfs/etc/xdg/menus/applications-merged/nulllinux-security.menu`
5. Add the role to `null-toolkit` AVAILABLE_ROLES array and case statements

## Code Style

- Shell scripts: `bash` with `set -euo pipefail`, pass `shellcheck`
- Use existing patterns as reference
- Minimal comments — code should be self-documenting
- English for all code, comments, and commit messages

## Pull Requests

- One feature or fix per PR
- Test the ISO build before submitting
- Reference any related issues
