# Privacy and Telemetry Statement

Null Linux collects nothing. There is no analytics, no hardware inventory, no
crash reporting, no usage counting, and no identifier of any kind is generated
or transmitted. There is no account, and no component phones home.

This document describes what the system does, so you can verify it rather than
trust it.

## Network activity you should expect

| When | What connects | Why |
| --- | --- | --- |
| `pacman -Syu`, `null-setup`, `null-toolkit install` | your configured Arch mirrors | downloading packages |
| `null-repo enable <repo>` | the keyserver you name, then that repository's mirrors | fetching and verifying a key |
| Browsing | whatever you visit | you asked for it |

Nothing else initiates a connection on its own. Null Linux performs no public-IP
lookup, no geolocation, no regulatory-domain lookup, and no update check of its
own.

## Defaults chosen for privacy

- **No service listens.** sshd is installed but disabled. The firewall denies
  incoming traffic. Nothing else opens a port.
- **No DNS-over-HTTPS provider is imposed.** Earlier builds forced every lookup
  through one third-party resolver. That is now off: choosing a resolver is your
  decision, and the setting is unlocked.
- **The browser start page is blank**, so opening it does not announce that you
  did to any server.
- **Firefox telemetry, Studies, Pocket and Firefox Accounts are disabled**, and
  tracking protection and HTTPS-only mode are on.
- **File indexing (Baloo) is off**, so nothing scans your disk in the background.
- **uBlock Origin is installed automatically** from addons.mozilla.org on first
  browser start. This is the one component fetched without asking. It is there
  because blocking trackers by default protects more than it costs; it is a
  network request you did not initiate, and you can remove the policy in
  `/usr/lib/firefox/distribution/policies.json`.

## What Null Linux does not claim

Null Linux does not make you anonymous, untraceable or undetectable, and it is
not "secure by default" in any sense that would survive a real adversary. It is
a conventional Arch system with conservative defaults. Your network, your
hardware, your firmware and the tools you run all remain observable.

Security tooling in the role catalog can be loud: scanners, packet capture,
monitor mode and credential tools change how your machine appears on a network
and may be logged, blocked or reported by whoever runs it. That is a property of
the tools, not something a distribution can hide.

## Diagnostics

There is no automatic diagnostic upload. If a future release adds a diagnostic
bundle, it will redact identifiers by default and show you the contents before
anything leaves the machine.

## Verifying this

```bash
ss -ltnp                      # nothing should be listening
systemctl list-units --type=service --state=running
grep -r . /usr/lib/firefox/distribution/policies.json
```
