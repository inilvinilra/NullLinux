# Security Policy

## Reporting a vulnerability

Report privately through GitHub Security Advisories:
<https://github.com/inilvinilra/NullLinux/security/advisories/new>

Please do not open a public issue for a vulnerability first.

Include what you did, what happened, what you expected, the ISO build id from
`/etc/os-release`, and whether the issue affects the live image, the installer,
or an installed system.

This is a small project with no paid staff and no service-level commitment. You
will get an acknowledgement and an honest answer about whether and when it can
be fixed.

## What is in scope

- The installer (`null-install`), especially anything that destroys data,
  bypasses validation, or installs a system that differs from what was verified.
- The package engine and role manager: false success, unverified installs,
  removing packages another role owns.
- Repository trust: anything that would accept an unverified key or repository.
- Defaults that expose the machine: a listening service, a weakened firewall, a
  credential written somewhere readable.
- Anything in the live image that leaks into an installed system, such as
  passwordless sudo or autologin.

## What is not a vulnerability

- Security tools in the role catalog behaving as designed. They are offensive
  tools; that they scan, capture or crack is their purpose.
- Packages from third-party repositories or the AUR. Those are other projects'
  supply chains; report to them.
- The absence of a feature that is documented as not implemented, such as disk
  encryption or Secure Boot. See `docs/audit-baseline.md`.

## Current security status

Null Linux is alpha. The ISO is **unsigned**, there is no signed package
repository, and disk encryption, Unified Kernel Images and Secure Boot are not
implemented. Do not use it where those matter. `docs/audit-baseline.md` lists
what has been verified by execution and what has not.

## Supported versions

Only the latest commit on `main`. There is no backport branch.
