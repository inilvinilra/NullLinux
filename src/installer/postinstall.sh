#!/usr/bin/env bash
# Runs inside the target system via arch-chroot.
#
# Every value arrives as an environment variable. Nothing the user typed is ever
# interpolated into this file, so no input can become code here.
set -euo pipefail

: "${NULL_HOSTNAME:?}" "${NULL_USERNAME:?}" "${NULL_TIMEZONE:?}"
: "${NULL_LOCALE:=en_US.UTF-8}" "${NULL_KEYMAP:=us}" "${NULL_ROOT_UUID:?}"
: "${NULL_MICROCODE:=}" "${NULL_SHELL:=/bin/bash}"

ln -sf "/usr/share/zoneinfo/${NULL_TIMEZONE}" /etc/localtime
hwclock --systohc || true

sed -i "s/^#\(${NULL_LOCALE} \)/\1/" /etc/locale.gen
locale-gen
printf 'LANG=%s\n' "$NULL_LOCALE" > /etc/locale.conf
printf 'KEYMAP=%s\n' "$NULL_KEYMAP" > /etc/vconsole.conf
printf '%s\n' "$NULL_HOSTNAME" > /etc/hostname

{
  printf '127.0.0.1 localhost\n'
  printf '::1 localhost\n'
  printf '127.0.1.1 %s.localdomain %s\n' "$NULL_HOSTNAME" "$NULL_HOSTNAME"
} > /etc/hosts

useradd -m -G wheel,audio,video,storage -s "$NULL_SHELL" "$NULL_USERNAME"

# Hashes arrive on file descriptors, never on a command line where ps would
# show them. chpasswd -e consumes an already-hashed password.
if [[ -s /run/nulllinux/user.hash ]]; then
  printf '%s:%s\n' "$NULL_USERNAME" "$(cat /run/nulllinux/user.hash)" | chpasswd -e
fi
if [[ -s /run/nulllinux/root.hash ]]; then
  printf 'root:%s\n' "$(cat /run/nulllinux/root.hash)" | chpasswd -e
else
  passwd -l root
fi

install -d -m 0750 /etc/sudoers.d
printf '%%wheel ALL=(ALL:ALL) ALL\n' > /etc/sudoers.d/01-wheel
chmod 0440 /etc/sudoers.d/01-wheel

systemctl enable NetworkManager.service
systemctl enable sddm.service
systemctl disable NetworkManager-wait-online.service 2>/dev/null || true

# Nothing listens by default. sshd stays installed but disabled; the hardened
# drop-in applies if the user ever enables it.
systemctl disable sshd.service 2>/dev/null || true

if command -v ufw >/dev/null 2>&1; then
  ufw --force default deny incoming
  ufw --force default allow outgoing
  systemctl enable ufw.service
fi

pacman-key --init
pacman-key --populate archlinux

bootctl --path=/boot install

cat > /boot/loader/loader.conf <<'LOADER'
default null-linux.conf
timeout 3
console-mode keep
editor no
LOADER

write_entry() {
  local file="$1" title="$2" extra="$3"
  {
    printf 'title   %s\n' "$title"
    printf 'linux   /vmlinuz-linux\n'
    [[ -n "$NULL_MICROCODE" ]] && printf 'initrd  /%s.img\n' "$NULL_MICROCODE"
    printf 'initrd  /initramfs-linux%s.img\n' "$extra"
    printf 'options root=UUID=%s rw quiet loglevel=3\n' "$NULL_ROOT_UUID"
  } > "/boot/loader/entries/$file"
}

write_entry null-linux.conf "Null Linux" ""
write_entry null-linux-fallback.conf "Null Linux (fallback initramfs)" "-fallback"

mkinitcpio -P

xdg-user-dirs-update || true

# Verification: refuse to report success unless the boot path really exists.
fail=0
for required in /boot/vmlinuz-linux /boot/initramfs-linux.img \
                /boot/loader/entries/null-linux.conf; do
  [[ -e "$required" ]] || { printf 'missing: %s\n' "$required" >&2; fail=1; }
done
if [[ -n "$NULL_MICROCODE" ]]; then
  [[ -e "/boot/${NULL_MICROCODE}.img" ]] || { printf 'missing microcode\n' >&2; fail=1; }
fi
id "$NULL_USERNAME" >/dev/null || fail=1

exit "$fail"
