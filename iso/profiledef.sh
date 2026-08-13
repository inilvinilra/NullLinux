#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="null-linux"
iso_label="NULL_LINUX"
iso_publisher="Null Linux Project <https://github.com/inilvinilra/NullLinux>"
iso_application="Null Linux Live ISO"
iso_version="0.2.0-alpha"
install_dir="null"
buildmodes=('iso')
bootmodes=(
  'bios.syslinux.mbr'
  'bios.syslinux.eltorito'
  'uefi-ia32.systemd-boot.esp'
  'uefi-x64.systemd-boot.esp'
  'uefi-ia32.systemd-boot.eltorito'
  'uefi-x64.systemd-boot.eltorito'
)
arch=('x86_64')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/polkit-1/rules.d"]="0:0:750"
  ["/root"]="0:0:750"
  ["/root/customize_airootfs.sh"]="0:0:755"
  ["/usr/bin/null-toolkit"]="0:0:755"
  ["/usr/bin/null-install"]="0:0:755"
  ["/usr/bin/null-setup"]="0:0:755"
  ["/usr/bin/null-repo"]="0:0:755"
  ["/usr/bin/null-setup-firstrun"]="0:0:755"
  ["/usr/share/nulllinux/hooks/update-desktop-entries.sh"]="0:0:755"
  ["/usr/share/nulllinux/installer/postinstall.sh"]="0:0:755"
)
