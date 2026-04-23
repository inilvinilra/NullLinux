# Null Linux Release Checklist

## Pre-Build

- Confirm package list updates are reviewed
- Confirm `iso/pacman.conf` repository configuration is valid
- Confirm roadmap and release notes are updated
- Confirm no temporary debug changes remain in scripts
- Run `./scripts/smoke-test.sh`

## Build

- Run `./scripts/check-host.sh`
- Run `./scripts/build-iso.sh`
- Verify build artifacts are generated in `out/`

## Boot Validation

- Run BIOS test: `./scripts/run-qemu.sh`
- Run UEFI test: `./scripts/run-qemu-uefi.sh`
- Verify SDDM appears and KDE session is available
- Verify network works using NetworkManager

## Security Validation

- Verify SSH password authentication is disabled
- Verify live user does not use a static default password
- Verify `sudo` policy is applied as expected
- Verify firewall package and OPSEC tools are present

## Tooling UX Validation

- Verify `Null Linux Tools` category is visible in KDE menu
- Verify Red Team, Blue Team, OSINT, OPSEC, and Network categories appear
- Verify each category launcher opens and reports tool availability

## Release Artifacts

- Generate SHA256 checksum for ISO
- Verify checksum file and ISO filename match release version
- Publish release notes with known issues and test results
