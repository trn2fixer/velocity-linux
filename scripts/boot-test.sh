#!/usr/bin/env bash
# Boot a Velocity ISO headless in QEMU with `velocity.selftest` on the kernel
# command line, capture the serial console, and fail if the in-ISO self-test
# does not print VELOCITY_SELFTEST_OK.
#
#   scripts/boot-test.sh out/velocity-*.iso [--timeout 1500]
#
# Needs: qemu-system-x86_64, qemu-img, bsdtar. Uses KVM when /dev/kvm is writable.
set -euo pipefail

ISO="${1:?path to iso}"; shift || true
TIMEOUT=1500
while [[ $# -gt 0 ]]; do case "$1" in --timeout) TIMEOUT="$2"; shift 2 ;; *) shift ;; esac; done

OUT="$(dirname "${ISO}")/boot-test"
mkdir -p "${OUT}"
SERIAL="${OUT}/serial.log"
: >"${SERIAL}"

# Pull kernel + initramfs straight out of the ISO so we bypass the boot menu.
bsdtar -xf "${ISO}" -C "${OUT}" velocity/boot/x86_64/vmlinuz-linux velocity/boot/x86_64/initramfs-linux.img
KERNEL="${OUT}/velocity/boot/x86_64/vmlinuz-linux"
INITRD="${OUT}/velocity/boot/x86_64/initramfs-linux.img"

# Empty target disk so the installer dry-run has something to plan against.
qemu-img create -q -f qcow2 "${OUT}/disk.qcow2" 20G

ACCEL=(-accel tcg -cpu max)
if [[ -w /dev/kvm ]]; then ACCEL=(-accel kvm -cpu host); fi

echo "booting ${ISO} (accel: ${ACCEL[1]}, timeout ${TIMEOUT}s)"
qemu-system-x86_64 \
  "${ACCEL[@]}" -m 3072 -smp 2 \
  -machine q35 \
  -kernel "${KERNEL}" -initrd "${INITRD}" \
  -append "archisobasedir=velocity archisodevice=/dev/sr0 console=tty0 console=ttyS0,115200 velocity.selftest systemd.show_status=false" \
  -drive file="${ISO}",media=cdrom,if=ide,readonly=on \
  -drive file="${OUT}/disk.qcow2",if=virtio,format=qcow2 \
  -nic user,model=virtio-net-pci \
  -display none -serial "file:${SERIAL}" -monitor none \
  -no-reboot &
QPID=$!

deadline=$((SECONDS + TIMEOUT))
result=""
while kill -0 "${QPID}" 2>/dev/null; do
  if grep -q 'VELOCITY_SELFTEST_OK' "${SERIAL}"; then result=ok; break; fi
  if grep -q 'VELOCITY_SELFTEST_FAIL' "${SERIAL}"; then result=fail; break; fi
  if (( SECONDS >= deadline )); then result=timeout; break; fi
  sleep 5
done
# give poweroff a moment, then make sure QEMU is gone
sleep 10
kill "${QPID}" 2>/dev/null || true
wait "${QPID}" 2>/dev/null || true

echo
echo "================ self-test output ================"
sed -n '/===== VELOCITY SELFTEST =====/,$p' "${SERIAL}" | tr -d '\r' || true
echo "=================================================="

case "${result}" in
  ok)   echo "BOOT TEST PASSED"; exit 0 ;;
  fail) echo "BOOT TEST FAILED (self-test reported failures)"; exit 1 ;;
  *)
    echo "BOOT TEST TIMED OUT or QEMU exited early. Last 60 serial lines:"
    tail -n 60 "${SERIAL}" | tr -d '\r'
    exit 1 ;;
esac
