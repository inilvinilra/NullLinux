# Manual Installation

The supported path is the installer:

```bash
sudo null-install
```

It handles UEFI GPT partitioning, an ext4 root, user creation, boot entries and
verification, and refuses to continue if the result would not boot.

Current scope and limitations are listed in
[audit-baseline.md](audit-baseline.md). In short: UEFI only, no disk encryption
yet, no BIOS installation.

## Installing by hand

`null-bootstrap` has been removed. It duplicated the installer, interpolated
unvalidated input into a script that ran as root inside the target, and enabled
third-party repositories without asking. Rather than maintain a second
privileged code path, here is the plain Arch procedure.

Assumes UEFI, a GPT disk, and that you have checked the device name twice.

```bash
# 1. Partition (replace /dev/sdX; on NVMe the partitions are /dev/nvme0n1p1 etc.)
parted -s /dev/sdX mklabel gpt
parted -s /dev/sdX mkpart ESP fat32 1MiB 1025MiB
parted -s /dev/sdX set 1 esp on
parted -s /dev/sdX mkpart ROOT ext4 1025MiB 100%

mkfs.fat -F32 /dev/sdX1
mkfs.ext4 -F /dev/sdX2

mount /dev/sdX2 /mnt
mount --mkdir /dev/sdX1 /mnt/boot

# 2. Base system. Install only your CPU's microcode.
ucode=$(grep -m1 '^vendor_id' /proc/cpuinfo | grep -q GenuineIntel && echo intel-ucode || echo amd-ucode)
pacstrap -K /mnt base linux linux-firmware mkinitcpio sudo networkmanager \
    plasma-desktop plasma-workspace sddm konsole dolphin "$ucode"

genfstab -U /mnt > /mnt/etc/fstab

# 3. Configure inside the target
arch-chroot /mnt
```

Inside the chroot, set the timezone, locale, hostname and a user, then:

```bash
systemctl enable NetworkManager sddm
bootctl --path=/boot install
```

Write `/boot/loader/entries/null-linux.conf` with your root UUID
(`blkid -s UUID -o value /dev/sdX2`):

```
title   Null Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=UUID=<uuid> rw quiet loglevel=3
```

Then `mkinitcpio -P`, exit, `umount -R /mnt`, and reboot.
