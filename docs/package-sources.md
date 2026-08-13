# Package Sources and Repository Policy

Null Linux installs software through pacman only. Nothing is fetched by a piped
install script, and nothing is installed through a language package manager
behind pacman's back.

## Preference order

1. **Official Arch repositories** (`core`, `extra`, `multilib`). Everything the
   base system and desktop needs comes from here.
2. **A signed Null Linux repository** for the distribution's own packages. It
   does not exist yet; until it does, Null Linux components are installed by the
   installer from the ISO rather than as signed packages.
3. **Explicitly approved third-party repositories** — BlackArch and Chaotic-AUR.
   Opt-in, never enabled without asking.
4. **Reviewed PKGBUILDs** built from pinned sources with verified checksums.
5. **Containers or VMs** for tooling that should not touch the host.

## Third-party repositories

Most security tooling in the role catalog comes from BlackArch. It is available
on the live medium, where its presence is disclosed on screen. The installer
asks before enabling it on an installed system and **defaults to no**.

If you decline, roles that depend on BlackArch packages will report unresolved
packages. That is reported honestly rather than hidden: `null-toolkit` lists
every package it could not install and does not mark the role installed.

### Enabling them safely

Do not pipe an install script into a shell, and do not trust a short key id. A
16-hex key id is not a fingerprint: verify the full fingerprint against the
value published by the project through a channel you already trust, then sign it
locally.

```bash
# Inspect the key fully before trusting it.
pacman-key --recv-key <FULL-FINGERPRINT> --keyserver <keyserver>
pacman-key --finger <FULL-FINGERPRINT>     # compare every group against the published value
pacman-key --lsign-key <FULL-FINGERPRINT>
```

Only then add the repository section to `/etc/pacman.conf`.

## The AUR

The AUR is not a repository; it is a collection of build scripts that execute as
your user. Null Linux does not install AUR packages automatically, and the role
manager will not build them for you. If you use an AUR helper, review the
PKGBUILD yourself.

Earlier versions installed packages through `pip --break-system-packages`,
`go install ...@latest` and unpinned `cargo install` when a package was missing.
That is removed: those files are invisible to pacman, unpinned, and were run as
root. Software that is not packaged is not installed.

## Partial upgrades

Arch does not support installing packages against a refreshed database without
upgrading. Null Linux never runs `pacman -Sy` followed by an install; the
validation gate fails the build if such a call reappears.
