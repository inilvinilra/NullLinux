#!/usr/bin/env bash
set -euo pipefail
# Run on a normal Arch/CachyOS boot (not a container). Configures libvirt for virt-manager.
# Usage: ./scripts/setup-libvirt-host.sh
#   (enter sudo password when asked once)

if [[ $EUID -eq 0 ]]; then
  echo "Run as your normal user, not root."
  exit 1
fi

if ! pidof -q systemd 2>/dev/null; then
  echo "This host has no systemd (PID1). Open a real terminal on your machine and run this script there."
  exit 1
fi

echo "==> Packages..."
sudo -E env LC_ALL=C pacman -Sy --needed --noconfirm \
  libvirt \
  virt-manager \
  virt-viewer \
  dnsmasq \
  bridge-utils \
  openbsd-netcat \
  edk2-ovmf \
  qemu-base \
  vde2

echo "==> Sockets and services (modular libvirt)..."
for u in \
  virtqemud.socket \
  virtqemud-ro.socket \
  virtqemud-admin.socket \
  virtlogd.socket \
  virtlockd.socket \
  virtnetworkd.socket \
  virtstoraged.socket \
  virtnodedevd.socket \
  virtsecretd.socket \
  virtnwfilterd.socket \
  virtinterfaced.socket \
  virtproxyd.socket; do
  sudo -E systemctl enable --now "$u" 2>/dev/null || true
done

echo "==> Monolithic libvirtd (if present, helps some setups)..."
sudo -E systemctl enable libvirtd.service 2>/dev/null || true
sudo -E systemctl start libvirtd.service 2>/dev/null || true

echo "==> Groups libvirt, kvm..."
sudo -E usermod -aG libvirt,kvm "$USER" || true

echo "==> Default virtual network (NAT)..."
if [[ -f /usr/share/libvirt/networks/default.xml ]]; then
  sudo -E virsh net-info default &>/dev/null || sudo -E virsh net-define /usr/share/libvirt/networks/default.xml
  sudo -E virsh net-start default 2>/dev/null || true
  sudo -E virsh net-autostart default 2>/dev/null || true
fi

echo "==> Check..."
if test -S /var/run/libvirt/virtqemud-sock 2>/dev/null; then
  echo "OK: /var/run/libvirt/virtqemud-sock"
else
  echo "If socket is missing, run:  sudo systemctl start virtqemud.socket"
  sudo -E systemctl --no-pager status virtqemud.socket | head -12 || true
fi

cat <<'EOF'

Next:
 1) Log out and log in again (or reboot) so group "libvirt" is active.
 2) Open virt-manager  →  File → Add connection  →  QEMU/KVM  →  Connect.

Troubleshooting:  sudo systemctl status virtqemud.socket
EOF
