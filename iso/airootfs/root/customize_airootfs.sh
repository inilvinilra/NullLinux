#!/usr/bin/env bash
set -euo pipefail

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc || true

echo "null" > /etc/hostname

cat > /etc/issue <<'ISSUE'

  \e[0;36m███╗   ██╗██╗   ██╗██╗     ██╗\e[0m
  \e[0;36m████╗  ██║██║   ██║██║     ██║\e[0m
  \e[0;36m██╔██╗ ██║██║   ██║██║     ██║\e[0m
  \e[0;36m██║╚██╗██║██║   ██║██║     ██║\e[0m
  \e[0;36m██║ ╚████║╚██████╔╝███████╗███████╗\e[0m
  \e[0;36m╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝\e[0m
  \e[1mL I N U X\e[0m  \e[2mArch-based Cybersecurity Distribution\e[0m

  Kernel: \r on \m
  TTY: \l

ISSUE

sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

cat > /etc/locale.conf <<'EOF'
LANG=en_US.UTF-8
EOF

cat > /etc/vconsole.conf <<'EOF'
KEYMAP=us
EOF

useradd -m -G wheel,audio,video,storage,optical -s /bin/zsh null
passwd -d null
install -d -m 700 -o null -g null /home/null
cp -a /etc/skel/. /home/null/
rm -f /home/null/.dmrc /home/null/.xsession
chown -R null:null /home/null

cat > /etc/sudoers.d/10-null <<'EOF'
null ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 /etc/sudoers.d/10-null

systemctl enable NetworkManager.service
systemctl disable NetworkManager-wait-online.service || true
systemctl enable sddm.service
systemctl enable ufw.service

ufw default deny incoming
ufw default allow outgoing
ufw --force enable

mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf <<'SDDM'
[Autologin]
User=null
Session=plasma
SDDM

systemctl mask systemd-firstboot.service
systemctl mask systemd-networkd.service
systemctl mask systemd-networkd.socket
systemctl mask systemd-networkd-wait-online.service
systemctl mask systemd-networkd-persistent-storage.service
systemctl mask systemd-network-generator.service
systemctl mask systemd-networkd-varlink.socket
systemctl mask systemd-networkd-varlink-metrics.socket
systemctl mask systemd-networkd-resolve-hook.socket
ldconfig
touch /etc/.updated /var/.updated

if [[ -d /usr/share/nulllinux/desktop-entries ]]; then
  for f in /usr/share/nulllinux/desktop-entries/*.desktop; do
    [[ -f "$f" ]] || continue
    cp -f "$f" /usr/share/applications/"nulllinux-$(basename "$f")"
  done
  update-desktop-database /usr/share/applications 2>/dev/null || true
fi

xdg-user-dirs-update
