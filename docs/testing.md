# Testing

Three layers, in the order you should reach for them. Each one costs roughly
twenty times the previous, and each one answers a question the cheaper layer
cannot.

| Layer | Cost | Answers |
|---|---|---|
| Gate and unit tests | seconds | Do the rules hold? Does the logic behave? |
| Installer control flow | seconds | Does the installer do the right thing when a step fails? |
| VM install and boot | ~40 minutes | Does an installed system actually boot? |

Nothing above the first layer is a substitute for the one below it, and the top
layer is too slow to iterate on. A bug that a cheaper layer could have caught
should be given a test at that layer.

## What runs anywhere

```bash
./tools/lint.sh          # release-blocking rules; exits non-zero on violation
./tests/run-tests.sh     # unit tests: no root, no network, no real packages
```

The unit tests replace pacman with a stub, so install results, role state,
removal ownership, input validation and partition naming are all exercised
without touching the system.

`run-tests.sh` also runs `tests/installer-unattended-test.sh`, which drives the
installer's whole unattended path with every external command stubbed. It asserts
what the VM test is too slow to iterate on:

- an unattended run never opens a dialog — one nobody can dismiss does not fail
  an install, it hangs it
- a failure part-way through unwinds its mounts in reverse order
- an install that does not verify is reported as a failure, never as a success
- a device the running system is using is refused before anything is mounted

The target device is a node faked by `fakeroot`: it satisfies `-b` and refers to
nothing. Each case runs in its own mount namespace with a private `/sys`, so the
UEFI check runs unmodified on a build machine that did not boot via UEFI. Where
neither `fakeroot` nor unprivileged user namespaces are available, the suite
reports itself skipped rather than passing silently.

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
sudo ./tests/build-test-iso.sh            # a throwaway image that installs itself
./tests/install-test-vm.sh                # install inside a VM, then boot the result
```

`qemu-boot-test.sh` boots the ISO headless under OVMF and captures the
framebuffer. QEMU exits cleanly whether or not the guest booted, so inspect the
screenshot; a successful live boot shows the Plasma desktop.

`install-test-vm.sh` does everything destructive inside QEMU, against a virtual
disk, so it needs no loop device and no privileged access to the host's block
layer. It boots the test image with a target disk and an answers disk attached,
waits for the guest to install itself and power off, then boots the target disk
alone and captures the screen.

The answers disk also carries the working tree's whole payload — tools, role
data, desktop entries, the KDE skel — laid out exactly as it sits on the live
medium. The installer is pointed at it with `NULL_SRC_ROOT`, so a change to any
of them is tested without rebuilding the image. The test image only has to be a
working harness. It prints `USING_INJECTED_BUILD` on the console when it takes
this path, so a run can never quietly test the wrong code.

`install-test.sh` is the older loop-device version, kept for a host where
hardware virtualisation is unavailable. Prefer the VM.

**Never test installation against a real disk.** These scripts create and destroy
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
