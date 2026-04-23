#!/usr/bin/env bash
set -euo pipefail

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc || true

echo "null" > /etc/hostname
echo "Null Linux" > /etc/issue

sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

cat > /etc/locale.conf <<'EOF'
LANG=en_US.UTF-8
EOF

cat > /etc/vconsole.conf <<'EOF'
KEYMAP=us
EOF

useradd -m -G wheel,audio,video,storage,optical -s /bin/bash null
passwd -d null
passwd -e null
install -d -m 700 -o null -g null /home/null
cp -a /etc/skel/. /home/null/
rm -f /home/null/.dmrc /home/null/.xsession
chown -R null:null /home/null

cat > /etc/sudoers.d/10-null <<'EOF'
null ALL=(ALL) ALL
EOF
chmod 0440 /etc/sudoers.d/10-null
chmod 0755 /usr/local/bin/null-tools-menu
chmod 0755 /usr/local/bin/null-welcome
chmod 0755 /usr/local/bin/null-welcome-install

systemctl enable NetworkManager.service
systemctl disable NetworkManager-wait-online.service || true
systemctl enable sddm.service

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

xdg-user-dirs-update
