# Testing

## What runs anywhere

```bash
./tools/lint.sh          # release-blocking rules; exits non-zero on violation
./tests/run-tests.sh     # unit tests: no root, no network, no real packages
```

The unit tests replace pacman with a stub, so install results, role state,
removal ownership, input validation and partition naming are all exercised
without touching the system.

## What needs an Arch host

```bash
./scripts/check-host.sh
sudo ./scripts/build-iso.sh
```

The build runs the validation gate first and refuses to continue if it fails.
It never modifies the host's pacman or mirror configuration.

## Boot testing

Interactive:

```bash
./scripts/run-qemu-uefi.sh    # UEFI
./scripts/run-qemu-bios.sh    # legacy BIOS live boot
```

Automated, with evidence:

```bash
./tests/qemu-boot-test.sh                 # live boot, writes a screenshot
sudo ./tests/install-test.sh              # install to a loop device, then boot it
```

`qemu-boot-test.sh` boots the ISO headless under OVMF and captures the
framebuffer. QEMU exits cleanly whether or not the guest booted, so inspect the
screenshot; a successful live boot shows the Plasma desktop.

`install-test.sh` creates its own file-backed loop device, installs to it
unattended, verifies the result offline, then boots the disk with no
installation medium attached.

**Never test installation against a real disk.** Both scripts create and destroy
their own images, and the installer independently refuses any device backing a
mounted filesystem.

## Smoke checklist

### Live boot
- [ ] Boot menu appears (systemd-boot on UEFI, syslinux on BIOS)
- [ ] SDDM autologs in as `null`
- [ ] Plasma desktop with the Null Linux wallpaper and panel

### Identity and defaults
- [ ] `cat /etc/os-release` reports `ID=nulllinux`
- [ ] `ss -ltnp` shows no unexpected listener
- [ ] `systemctl is-enabled sshd` reports disabled
- [ ] Tools appear under the Null Linux menu categories

### Role manager
- [ ] `null-toolkit list` shows 13 roles with real status
- [ ] `null-toolkit info network` marks installed packages correctly
- [ ] `sudo null-toolkit install <role>` reports complete/partial/failed honestly
- [ ] A role with an unavailable package is **not** marked installed
- [ ] `null-toolkit remove <role> --dry-run` keeps packages another role needs

### First run
- [ ] The setup wizard appears once after first login
- [ ] It does **not** appear on the second login
- [ ] `null-setup` still launches it by hand

### Installer (QEMU only)
- [ ] The live medium is never offered as a target
- [ ] A mistyped confirmation aborts without touching the disk
- [ ] Cancelling before partitioning leaves the disk untouched
- [ ] A completed install boots from disk with no installation medium attached
- [ ] The installed desktop matches the live one, without live autologin
