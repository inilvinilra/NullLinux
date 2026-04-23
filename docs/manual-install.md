# Manual Install

This is the current install path for Null Linux.

## Assumptions

- UEFI system
- EFI partition mounted at `/mnt/boot`
- root filesystem mounted at `/mnt`

## Partitioning Example

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

## Bootstrap

```bash
null-bootstrap
```

The script will:
- install the base system
- generate `fstab`
- create a user
- enable `NetworkManager` and `sddm`
- install `systemd-boot`
- ask for root and user passwords

## After Reboot

- log in with the created user
- verify networking
- update the system with `sudo pacman -Syu`
