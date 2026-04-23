# Null Welcome Module Plan

## Decision

Null Welcome should start as an in-repo module in NullLinux.

## Why

- Faster iteration with ISO profile, package lists, and desktop integration
- Single release flow while taxonomy and install logic are still changing
- Easier testing in live ISO and post-install bootstrap path

## Split Trigger

Move Null Welcome to a dedicated repository when all conditions are met:

- Stable plugin or catalog schema for at least two release cycles
- Independent release cadence becomes necessary
- UI and backend surface are used by external projects

## Architecture

- Catalog source: `iso/airootfs/usr/share/null-welcome/catalog.yml`
- Runtime entrypoint: future `null-welcome` desktop app
- Install backend: package profile executor with grouped transactions
- GUI binary integration path: `iso/airootfs/opt/nullwelcome/nullwelcome`
- Modes:
  - Development & Build Environments
  - Essential Tools
  - Security Categories
  - Privacy & Anti-Forensics
  - Security Hardening
  - Performance Optimization

## Delivery Phases

### Phase A (MVP)

- Read YAML catalog and render grouped selections
- Install selected package sets with transaction preview
- Save operation log and rollback hints
- Prefer external `NullWelcome` GUI binary when present, fallback to backend CLI flow

### Phase B

- Add profile presets (red team, blue team, osint, network)
- Add dependency/conflict checks before execution
- Add import/export for custom catalog overrides

### Phase C

- Add post-install validation checks
- Add package source policy checks (official, BlackArch, optional AUR helper path)
- Add telemetry-free local usage stats for troubleshooting
