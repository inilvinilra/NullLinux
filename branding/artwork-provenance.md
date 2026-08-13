# Artwork and Third-Party Asset Provenance

Every asset shipped in the ISO must have a recorded origin, licence and permission status before a stable release. **This manifest is incomplete.**

Provenance for the assets below is **not established**. They were present in the repository before this audit with no accompanying source, author, licence or permission record, and none could be derived from the files or from git history. They are listed as unverified rather than assumed to be original work, because guessing here is exactly the mistake that creates a licensing problem later.

The project owner must complete the Source, Author, Licence and Permission columns, or replace the assets. Until then a stable release is blocked.

| File | Dimensions | Bytes | SHA-256 (first 16) | Source | Author | Licence | Permission |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `NulLinuxBackround.png` | 1672x941 | 2641412 | `b6d2b3c7be33089e` | **UNKNOWN** | **UNKNOWN** | **UNKNOWN** | **UNVERIFIED** |
| `NulLinuxBackround2.png` | 1536x1024 | 2035278 | `eacb934a0d704d18` | **UNKNOWN** | **UNKNOWN** | **UNKNOWN** | **UNVERIFIED** |
| `NulLinuxBackround4.png` | 1536x1024 | 2450283 | `f85bff431c81a516` | **UNKNOWN** | **UNKNOWN** | **UNKNOWN** | **UNVERIFIED** |
| `NullLinuxBackround3.png` | 1536x1024 | 2682637 | `6901cbaad7918903` | **UNKNOWN** | **UNKNOWN** | **UNKNOWN** | **UNVERIFIED** |
| `NullLinuxLogo.png` | 1024x1024 | 267333 | `589c4ba35706ba2a` | **UNKNOWN** | **UNKNOWN** | **UNKNOWN** | **UNVERIFIED** |

## If these were generated

If any asset came from an image generator, record the tool and the date. Terms
differ between services and change over time, and some outputs carry
restrictions that matter for a redistributable ISO.

## If these came from elsewhere

Record the URL, the licence at the time of download and the date. A wallpaper
that is free to use personally is not necessarily free to redistribute inside a
distribution image.

## Branding risk

`NullLinuxLogo.png` resembles the Arch Linux logo in silhouette. Arch Linux has
a trademark policy governing use of its marks and of confusingly similar marks.
This is a documented risk to review, not a legal conclusion: the project owner
should read the current policy and decide, ideally before any stable or
commercial release. An original visual identity avoids the question entirely.

Null Linux is an independent distribution and is not endorsed by or affiliated
with Arch Linux, BlackArch, KDE, or any packaged upstream.

## Assets from packages

Everything else on the desktop — Breeze, Papirus, the fonts — comes from its
Arch package with that package's licence. Null Linux redistributes no modified
copies of them.
