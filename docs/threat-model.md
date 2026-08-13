# Threat Model

What Null Linux defends against, what it does not, and what is left unresolved.
Written against the system as it actually is: alpha, unsigned, without disk
encryption. Where a mitigation does not exist yet, it says so.

## Assets

- **The user's data** on the installed system.
- **The user's credentials**: passwords, keys, API tokens for security tooling.
- **The machine's integrity**: kernel, initramfs, bootloader, packages.
- **The user's identity and location**, insofar as the machine reveals them.
- **The project's release integrity**: the ISO and, later, signed packages.
- **Third parties' systems.** A workstation full of offensive tooling can be
  turned against someone else, including by accident.

## Trust boundaries

1. Arch Linux's package signing and its packagers.
2. Third-party repositories (BlackArch, Chaotic-AUR) once the user enables them.
3. The AUR, which is build scripts that execute as the user, not a repository.
4. The GitHub Actions runners that build the ISO.
5. The live medium, which is unsigned today.
6. The boundary between the live environment and an installed system.
7. The user's own network.

## Threats

### T1 — Compromised or malicious package upstream

**Mitigation.** Only official Arch repositories are configured by default;
pacman verifies signatures against the Arch keyring. Third-party repositories
are opt-in and require a verified full fingerprint. No package is ever installed
through pip, go or cargo behind pacman's back, and no build or runtime path
pipes a remote script into a shell.

**Residual risk.** A compromised Arch packager still reaches the machine. Null
Linux adds no independent review of upstream package contents.

**Detection.** `pacman -Qkk` for file integrity; `paccheck` for signatures.

### T2 — Compromised third-party repository

**Mitigation.** Disabled by default. `null-repo` refuses a short key id, checks
that the retrieved key carries the fingerprint given, requires explicit
confirmation, and can be reversed. The user is told before installing that most
role packages come from BlackArch.

**Residual risk.** Once enabled, a compromised BlackArch or Chaotic-AUR key
signs packages the system will install without further question. These
repositories are large and fast-moving.

**Recovery.** `null-repo disable <repo>`, then audit foreign packages with
`pacman -Qm`.

### T3 — Malicious AUR PKGBUILD

**Mitigation.** Nothing in Null Linux builds AUR packages. The AUR helpers were
removed from the image; the language-manager fallbacks that fetched unpinned
code as root are gone.

**Residual risk.** If the user installs an AUR helper themselves, this returns
in full. Read the PKGBUILD.

### T4 — Compromised CI or workflow dependency

**Mitigation.** Actions are pinned to commit SHAs, workflow tokens are
read-only, jobs have timeouts and concurrency groups, and pull requests from
forks no longer build PKGBUILDs — `makepkg` executes the PKGBUILD, so that was
arbitrary code execution on a runner.

**Residual risk.** The runner image, Arch's mirrors and GitHub itself remain
trusted. Builds are not reproducible yet, so a tampered artifact cannot be
detected by rebuilding.

### T5 — Tampered release image

**Mitigation.** The build prints a SHA-256 of every ISO.

**Not mitigated.** The ISO is **unsigned**. A checksum published beside the
download proves nothing against an attacker who can replace both. Signing, an
SBOM and published provenance are required before a stable release and do not
exist yet.

### T6 — Lost or stolen machine

**Not mitigated.** There is no disk encryption. The installer states this before
it touches the disk. Anyone with the machine has the data.

Until LUKS2 lands, use full-disk encryption from another installer, or do not
put sensitive data on it.

### T7 — Evil-maid boot tampering

**Not mitigated.** No Secure Boot, no Unified Kernel Images, no measured boot.
An attacker with physical access can modify the bootloader, kernel or initramfs
undetectably.

### T8 — Credential leakage through logs and shell history

**Mitigation.** The installer never puts a password on a command line: hashes go
to a file with restrictive permissions and are consumed by `chpasswd -e`, then
deleted on every exit path, including failure and signals. Passwords are never
printed to the terminal or the install log.

**Residual risk.** Security tools you run may write credentials to their own
logs, and your shell history records what you type. Null Linux does not manage
API keys for you.

### T9 — The machine exposing services

**Mitigation.** Nothing listens by default. sshd is installed but disabled, and
the hardened drop-in (no root login, no password authentication) is installed
with it. The firewall denies incoming traffic. No Tor, VPN, proxy, database, web
server or C2 framework is enabled by installing its role.

**Residual risk.** Many role packages start listeners when *you* run them. That
is their function.

### T10 — Host compromise through a security tool

**Partially mitigated.** Tools are not installed by default; roles are chosen
explicitly. Launchers no longer invoke `sudo` for you.

**Not mitigated.** Tools run with your privileges on your daily machine. There
is no sandboxing, no container placement, and no VM isolation for high-risk
work. Parsing hostile input — a captured packet, a malware sample, a firmware
image — in a tool running as you is a real compromise path. Do that work in a
disposable VM.

### T11 — Malware analysis escape

**Not mitigated.** There is no isolation layer. Do not detonate samples on this
system.

### T12 — Installer destroying the wrong disk

**Mitigation.** Device selection excludes the live medium, every disk backing a
mounted filesystem, read-only devices, pseudo devices such as zram and loop, and
anything under 20 GB. It shows the disk's current contents, then requires the
full device path to be typed to match. Unattended mode applies the same
exclusions and additionally requires the target to be named twice.

**Residual risk.** A user who types the path of the correct-looking wrong disk
will lose it. There is no undo.

**Verified.** On a real machine the filter refused both the system disk and a
zram device, offering nothing rather than offering to destroy the host.

### T13 — Interrupted or failed installation

**Mitigation.** Mounts are tracked and unwound on every exit path; secrets are
removed; the installer reports success only after verifying identity, fstab,
kernel, initramfs, boot entry, user and sudo policy on the target.

**Residual risk.** A partially written disk is still a destroyed disk. There is
no resume.

### T14 — Update regression on a rolling release

**Partially mitigated.** No partial upgrades are possible from Null Linux tools;
`null-toolkit update` performs a full synchronised upgrade.

**Not mitigated.** No snapshots, no rollback, no staged channel. A bad upgrade
is recovered by hand from another medium.

### T15 — Malicious USB device

**Not mitigated.** USBGuard is not configured. Any plugged device is trusted by
the kernel as usual.

### T16 — Network observation and fingerprinting

**Partially mitigated.** No telemetry, no public-IP lookup, no automatic update
check, no DNS-over-HTTPS forced through a third party, and a blank browser start
page, so a fresh boot announces nothing on its own.

**Not mitigated.** MAC randomisation policy is not yet configured, and the tools
you run are loud by design. Null Linux makes no anonymity claim.

## Non-goals

Null Linux does not attempt to defeat a physically present attacker, a
compromised firmware, a malicious Arch packager, or a network adversary
observing your traffic. It is not an anonymity system.

## Review

This document must be revisited whenever a defence listed as "not mitigated" is
implemented, in particular disk encryption, Secure Boot, ISO signing, snapshots
and container or VM placement for high-risk tooling.
