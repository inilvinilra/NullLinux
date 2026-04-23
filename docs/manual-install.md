# Manual Install

## Recommended: TUI Installer

```bash
sudo null-install
```

The installer provides a dialog interface for disk selection, partitioning,
user creation, timezone, and security role selection.

## Manual Bootstrap (Advanced)

If you prefer full manual control:

### Assumptions

- UEFI system
- EFI partition mounted at `/mnt/boot`
- Root filesystem mounted at `/mnt`

### Partitioning Example

```bash
parted /dev/nvme0n1 --script mklabel gpt
parted /dev/nvme0n1 --script mkpart ESP fat32 1MiB 1025MiB
parted /dev/nvme0n1 --script set 1 esp on
parted /dev/nvme0n1 --script mkpart ROOT ext4 1025MiB 100%
mkfs.fat -F32 /dev/nvme0n1p1
mkfs.ext4 /dev/nvme0n1p2
mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot
```

### Bootstrap

```bash
null-bootstrap
```

The script will:
- Install the base system with KDE Plasma
- Configure BlackArch and Chaotic-AUR repos
- Generate fstab
- Create a user and set passwords
- Enable NetworkManager, SDDM, and ufw
- Install systemd-boot

### After Reboot

- Log in with the created user
- Run `null-welcome` for setup guidance
- Install security roles: `sudo null-toolkit install redteam`
- Update the system: `sudo pacman -Syu`
