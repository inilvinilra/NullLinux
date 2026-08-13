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

# LIVE MEDIUM ONLY. The installer never copies this file to a target system;
# installed systems get a password-prompting wheel policy instead.
cat > /etc/sudoers.d/10-null <<'EOF'
null ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 /etc/sudoers.d/10-null

pacman-key --init
pacman-key --populate archlinux

systemctl enable NetworkManager.service
systemctl disable NetworkManager-wait-online.service || true
systemctl enable sddm.service
systemctl enable ufw.service

ufw default deny incoming
ufw default allow outgoing
ufw --force enable

mkdir -p /etc/sddm.conf.d
# LIVE MEDIUM ONLY. Session stays on X11 until the Wayland session has been
# verified by an automated QEMU boot test; see docs/audit-baseline.md.
cat > /etc/sddm.conf.d/autologin.conf <<'SDDM'
[Autologin]
User=null
Session=plasmax11
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

systemctl mask plymouth-start.service
systemctl mask plymouth-read-write.service
systemctl mask plymouth-quit.service
systemctl mask plymouth-quit-wait.service
systemctl mask ModemManager.service
systemctl mask lvm2-monitor.service
systemctl mask lvm2-lvmpolld.socket
systemctl disable bluetooth.service 2>/dev/null || true

ldconfig
touch /etc/.updated /var/.updated

mkdir -p /etc/sysctl.d
# Performance tuning only. These are not security controls.
cat > /etc/sysctl.d/99-nulllinux-perf.conf <<'SYSCTL'
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
SYSCTL

mkdir -p /etc/tmpfiles.d
cat > /etc/tmpfiles.d/tmp.conf <<'TMPFILES'
q /tmp 1777 root root 7d
TMPFILES

# Same sync the alpm hook runs after every transaction: entries appear only for
# tools that are actually installed.
if [[ -x /usr/share/nulllinux/hooks/update-desktop-entries.sh ]]; then
  /usr/share/nulllinux/hooks/update-desktop-entries.sh || true
fi

xdg-user-dirs-update
