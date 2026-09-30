#!/usr/bin/env bash
# shellcheck disable=SC2034
# Velocity Linux archiso profile definition.
# Consumed by mkarchiso; see scripts/build-iso.sh for how this profile is prepared.

iso_name="velocity"
iso_label="VELOCITY_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Velocity Linux <https://github.com/velocity-linux/velocity>"
iso_application="Velocity Linux Live / Installer"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="velocity"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.bash_profile"]="0:0:644"
  ["/usr/local/bin/velocity-live-init"]="0:0:755"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/velocity-selftest"]="0:0:755"
  ["/usr/local/bin/velocity-autoinstall"]="0:0:755"
  ["/etc/velocity/ci/post-install.sh"]="0:0:755"
  ["/etc/velocity/ci/velocity-installtest"]="0:0:755"
)
