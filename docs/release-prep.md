# Null Linux Release Prep

## Scope Completed

- Arch-only direction is enforced in docs and defaults
- KDE dark-first baseline is in place
- BlackArch repository integration is enabled
- Category-based security menu scaffolding is integrated
- Null Welcome catalog, validator, backend installer, and launcher are integrated
- Smoke test and release checklist are wired

## Key Paths Added or Updated

### Platform and Security Baseline

- `branding/identity.md`
- `iso/pacman.conf`
- `iso/packages.x86_64`
- `iso/airootfs/etc/ssh/sshd_config.d/10-null-linux.conf`
- `iso/airootfs/root/customize_airootfs.sh`
- `iso/airootfs/etc/pacman.d/blackarch-mirrorlist`

### KDE and Category Menu UX

- `iso/airootfs/etc/skel/.config/kdeglobals`
- `iso/airootfs/etc/skel/.config/plasmarc`
- `iso/airootfs/etc/skel/.config/autostart/nm-applet.desktop`
- `iso/airootfs/etc/skel/.config/autostart/polkit-gnome-authentication-agent-1.desktop`
- `iso/airootfs/usr/local/bin/null-tools-menu`
- `iso/airootfs/etc/xdg/menus/applications-merged/nulllinux-tools.menu`
- `iso/airootfs/usr/share/applications/nulllinux-*.desktop`
- `iso/airootfs/usr/share/desktop-directories/nulllinux-*.directory`

### Null Welcome Module

- `iso/airootfs/usr/share/null-welcome/catalog.yml`
- `iso/airootfs/usr/local/bin/null-welcome-install`
- `iso/airootfs/usr/local/bin/null-welcome`
- `iso/airootfs/usr/share/applications/nulllinux-welcome.desktop`
- `scripts/null-welcome-validate.py`
- `scripts/integrate-nullwelcome.sh`

### Build and Validation Tooling

- `scripts/build-iso.sh`
- `scripts/smoke-test.sh`
- `docs/release-checklist.md`

### Documentation

- `README.md`
- `docs/roadmap.md`
- `docs/tool-categories.md`
- `docs/null-welcome-module.md`
- `docs/null-welcome-catalog-notes.md`

## Suggested Commit Split

1. `feat(platform): align Arch-only KDE baseline and security defaults`
   - identity alignment, SSH/password policy, BlackArch integration

2. `feat(desktop): add KDE dark defaults and category menu skeleton`
   - KDE profile files, menu definitions, category launchers, tools menu backend

3. `feat(null-welcome): add catalog, validator, installer backend, and launcher`
   - catalog, validation script, installer flow, desktop entry, integration hook

4. `chore(release): add smoke-test pipeline and release preparation docs`
   - smoke test script, checklist updates, roadmap/readme/docs synchronization

## Validation Runbook

Run in this order:

```bash
./scripts/smoke-test.sh
./scripts/build-iso.sh --clean-work
./scripts/run-qemu.sh
./scripts/run-qemu-uefi.sh
```

## Exit Criteria for Push

- Smoke test passes
- ISO build succeeds after clean workdir
- BIOS and UEFI VM boot path confirmed
- Release checklist reviewed and signed off
