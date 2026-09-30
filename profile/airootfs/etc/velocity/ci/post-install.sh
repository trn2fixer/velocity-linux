#!/usr/bin/env bash
# CI post-install hook. Runs on the live medium after velocity-install finished,
# with the new system still mounted at $TARGET. Makes the installed system
# report over the serial console and run velocity-installtest on first boot.
set -euo pipefail
T="${TARGET:?TARGET not set}"

# GRUB + kernel on serial so the harness can read the first boot.
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4 console=tty0 console=ttyS0,115200"/' "${T}/etc/default/grub"
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' "${T}/etc/default/grub"
cat >>"${T}/etc/default/grub" <<'EOF'

# --- CI serial console (added by /etc/velocity/ci/post-install.sh) ---
GRUB_TERMINAL_INPUT="console serial"
GRUB_TERMINAL_OUTPUT="console serial"
GRUB_SERIAL_COMMAND="serial --unit=0 --speed=115200"
EOF
arch-chroot "${T}" grub-mkconfig -o /boot/grub/grub.cfg

# First-boot test inside the installed system.
install -Dm755 /etc/velocity/ci/velocity-installtest "${T}/usr/local/bin/velocity-installtest"
install -Dm644 /etc/velocity/ci/velocity-installtest.service "${T}/etc/systemd/system/velocity-installtest.service"
systemctl --root="${T}" enable velocity-installtest.service
echo "post-install: serial console + installtest enabled"
