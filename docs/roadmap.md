# Null Linux Roadmap (Arch-Only)

## Product Direction

- Distribution model: Arch-based only
- Desktop target: KDE Plasma with a dark-first UI
- Security tooling UX: category-driven launcher and menu layout
- Package sources: Arch official repos plus BlackArch
- Language policy: all user-facing text and docs in English

## Core Objectives

- Deliver a stable, reproducible ArchISO build pipeline
- Provide a secure-by-default live and installed baseline
- Offer curated security tooling grouped by practical workflows
- Maintain a clean contributor workflow with strong CI gates

## Workstreams

### 1) Architecture and Repository Standards

- [ ] Finalize architecture document for build, runtime, release, and support boundaries
- [ ] Lock repository conventions for `iso/`, `scripts/`, `docs/`, `branding/`, and future `packages/`
- [ ] Define ownership and acceptance criteria for each workstream

### 2) Build System and Reproducibility

- [ ] Refactor build scripts to avoid mutating host binaries
- [ ] Remove runtime remote file fetches from build path
- [ ] Add strict preflight checks (dependencies, versions, permissions, disk space)
- [ ] Add build profiles: `minimal`, `core-security`, `full-security`
- [ ] Add reproducibility checks and artifact manifest generation

### 3) Package Sources and Mirrors

- [ ] Integrate Arch and BlackArch repositories in `pacman.conf`
- [ ] Add keyring and mirrorlist setup for all enabled repositories
- [ ] Add mirror fallback strategy and mirror health verification script
- [ ] Define update cadence and rollback runbook for broken updates

### 4) KDE Desktop and Theming

- [ ] Ship a KDE default profile with dark theme enabled by default
- [ ] Standardize panel, launcher, terminal profile, icon theme, and login appearance
- [ ] Add sane defaults for HiDPI, font rendering, and accessibility options
- [ ] Add first-run onboarding entry point for network, updates, and docs

### 5) Security Tool Taxonomy and Menu UX

- [ ] Define category taxonomy and metadata schema for tools
- [ ] Implement category groups in KDE application menu
- [ ] Initial categories:
  - Red Team
  - Blue Team
  - OSINT
  - OPSEC
  - Network
  - Web
  - Forensics
  - Reverse Engineering
  - Wireless
  - Crypto
- [ ] Add role bundles for quick install profiles (red, blue, osint, network)

### 6) Installer Path

- [ ] Keep bootstrap installer path for MVP
- [ ] Add guided install presets (standard, encrypted single disk, dual-boot safe mode)
- [ ] Add post-install finalization for KDE session readiness
- [ ] Add install validation tests in VM pipelines

### 7) Security Baseline

- [ ] Remove weak default credentials from live environment
- [ ] Set secure SSH defaults for live and installed systems
- [ ] Define sudo, firewall, and network service defaults
- [ ] Add baseline security audit checklist for release candidates

### 8) CI/CD and Release Engineering

- [ ] Add CI gates for script linting and config validation
- [ ] Add smoke boot tests for BIOS/UEFI in QEMU
- [ ] Add signed release artifacts and checksum publication
- [ ] Standardize release channels: `alpha`, `beta`, `stable`
- [ ] Publish release checklist and changelog template

### 9) Documentation and Contributor Experience

- [ ] Write a 15-minute local build quickstart
- [ ] Document tool categories and role bundle behavior
- [ ] Publish troubleshooting guides for build and boot failures
- [ ] Add issue templates for regressions, package requests, and feature proposals

## 90-Day Execution Plan

### Phase 1 (Days 1-30): Platform Stabilization

- Finalize architecture and repository standards
- Complete deterministic build refactor
- Integrate Arch + BlackArch mirrors and trust configuration
- Deliver KDE dark baseline profile
- Release target: `v0.2.0-alpha`

### Phase 2 (Days 31-60): Security UX and Tooling Identity

- Implement tool taxonomy and KDE category menus
- Add role bundle profiles
- Add onboarding entry point and baseline usability improvements
- Expand CI with build and boot smoke checks
- Release target: `v0.3.0-alpha`

### Phase 3 (Days 61-90): Installer and Release Maturity

- Harden installer MVP and guided install presets
- Add release signing and artifact publication standards
- Complete security baseline enforcement
- Finalize contributor and operations documentation
- Release target: `v0.4.0-beta`

## Priority Backlog (Top 20)

1. Lock Arch-only scope in all docs and configs
2. Refactor build scripts for deterministic behavior
3. Add strict preflight validation command
4. Integrate BlackArch repo, keys, and mirrors
5. Add mirror fallback validation script
6. Ship KDE dark default profile
7. Standardize KDE menu and launcher defaults
8. Define tool taxonomy metadata schema
9. Implement category-based KDE menu entries
10. Add role bundle package profiles
11. Harden live defaults and SSH policy
12. Add installer guided standard profile
13. Add installer encrypted profile
14. Add QEMU BIOS/UEFI smoke boot checks
15. Add CI validation for package/tool metadata
16. Add signed artifact publishing flow
17. Add release checklist and changelog template
18. Add build troubleshooting documentation
19. Add issue templates and triage labels
20. Run first full release candidate rehearsal

## Definition of Done

- English-only content in docs and user-facing outputs
- Minimal comments in scripts and configuration files
- CI passes for all mandatory checks
- Boot smoke test passes on at least one BIOS and one UEFI VM path
- Release artifacts include checksums and signatures
- Documentation updated for every user-visible behavior change
