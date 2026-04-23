# Null Welcome Catalog Notes

## Source

The current catalog baseline is derived from your curated tool list and grouped into:

- Development & Build Environments
- Essential Tools
- Information Gathering & OSINT
- Web Application Security
- Exploitation & Post-Exploitation
- Password Cracking & Cryptography
- Forensics, DFIR & Steganography
- Reverse Engineering & Malware Analysis
- Network Traffic Analysis & Sniffing
- Privacy & Anti-Forensics
- Security Hardening
- Performance Optimization

## Current Status

- Catalog path: `iso/airootfs/usr/share/null-welcome/catalog.yml`
- MVP backend entrypoint: `iso/airootfs/usr/local/bin/null-welcome-install`
- Desktop launcher entrypoint: `iso/airootfs/usr/local/bin/null-welcome`
- Optional GUI binary staging script: `scripts/integrate-nullwelcome.sh`
- Package availability can vary between Arch official, BlackArch, and AUR

## Next Steps

- Add a richer KDE/Qt UI over the existing backend
- Add repo-source policy to each item (`official`, `blackarch`, `aur`)
- Add a transaction history file and rollback helper
