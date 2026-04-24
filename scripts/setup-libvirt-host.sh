#!/usr/bin/env bash
set -euo pipefail
# Configures libvirt for virt-manager (qemu:///system).
# Works from Konsole, from Cursor, or non-interactive (see below).
#
#   SUDO_ASKPASS: path to askpass (auto-detects ksshaskpass on KDE)
#   SUDO_PASSWORD: optional, piped to sudo -S (avoid in shared history)
#   Run from TTY: normal sudo password prompt

if [[ $EUID -eq 0 ]]; then
  echo "Run as your normal user, not root."
  exit 1
fi

if ! pidof -q systemd 2>/dev/null; then
  echo "This host has no systemd. Run on your real install."
  exit 1
fi

# Pick a graphical askpass if we have a display and no TTY (e.g. Cursor)
pick_askpass() {
  for p in \
    /usr/lib/ssh-askpass-fullscreen \
    /usr/lib/kf6/ksshaskpass \
    /usr/lib/kf5/ksshaskpass \
    /usr/lib/ssh-askpass; do
    [[ -x "$p" ]] && { echo "$p"; return 0; }
  done
  command -v ssh-askpass-fullscreen 2>/dev/null
}

run_sudo() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
    return
  fi
  if sudo -n true 2>/dev/null; then
    sudo -E "$@"
    return
  fi
  if [[ -n "${SUDO_PASSWORD:-}" ]]; then
    printf '%s\n' "$SUDO_PASSWORD" | sudo -S -E "$@"
    return
  fi
  if [[ -n "${SUDO_ASKPASS:-}" ]] && [[ -x "$SUDO_ASKPASS" ]]; then
    sudo -A -E "$@"
    return
  fi
  if [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && askpath="$(pick_askpass)" && [[ -n "$askpath" ]]; then
    export SUDO_ASKPASS="$askpath"
    sudo -A -E "$@"
    return
  fi
  if [[ -t 0 ]] && [[ -t 1 ]]; then
    sudo -E "$@"
    return
  fi
  cat <<'EOM' >&2
sudo needs a password but this environment has no TTY (e.g. Cursor). Use one of:

  A) Konsole / a normal terminal:     ./scripts/setup-libvirt-host.sh

  B) Graphical password (KDE):         export SUDO_ASKPASS=/usr/lib/kf6/ksshaskpass
                                        ./scripts/setup-libvirt-host.sh

  C) One-liner (not ideal for copy-paste):  SUDO_PASSWORD='yourpass' ./scripts/setup-libvirt-host.sh

EOM
  exit 1
}

echo "==> Packages..."
run_sudo env LC_ALL=C pacman -Sy --needed --noconfirm \
  libvirt \
  virt-manager \
  virt-viewer \
  dnsmasq \
  bridge-utils \
  openbsd-netcat \
  edk2-ovmf \
  qemu-base \
  vde2 \
  ksshaskpass

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
  run_sudo systemctl enable --now "$u" 2>/dev/null || true
done

echo "==> Monolithic libvirtd (if present)..."
run_sudo systemctl enable libvirtd.service 2>/dev/null || true
run_sudo systemctl start libvirtd.service 2>/dev/null || true

echo "==> Groups libvirt, kvm..."
run_sudo usermod -aG libvirt,kvm "$USER" || true

echo "==> Default virtual network (NAT)..."
if [[ -f /usr/share/libvirt/networks/default.xml ]]; then
  run_sudo virsh net-info default &>/dev/null || run_sudo virsh net-define /usr/share/libvirt/networks/default.xml
  run_sudo virsh net-start default 2>/dev/null || true
  run_sudo virsh net-autostart default 2>/dev/null || true
fi

echo "==> Check..."
if test -S /var/run/libvirt/virtqemud-sock 2>/dev/null; then
  echo "OK: /var/run/libvirt/virtqemud-sock"
else
  echo "If socket is missing, run:  sudo systemctl start virtqemud.socket" || true
  run_sudo systemctl --no-pager status virtqemud.socket 2>/dev/null | head -12 || true
fi

cat <<'EOF'

Next:
 1) Log out and log in again (or reboot) so group "libvirt" is active.
 2) Open virt-manager  →  File → Add connection  →  QEMU/KVM  →  Connect.

Troubleshooting:  sudo systemctl status virtqemud.socket
EOF
