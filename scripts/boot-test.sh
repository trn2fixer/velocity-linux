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
TIMEOUT=720
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
ACCEL_NAME=tcg
if [[ -w /dev/kvm ]]; then ACCEL=(-accel kvm -cpu host); ACCEL_NAME=kvm; fi

# The archiso hook locates the medium by volume label; read it from the ISO.
LABEL="$(blkid -o value -s LABEL "${ISO}" 2>/dev/null || true)"
[[ -n "${LABEL}" ]] || LABEL="$(isoinfo -d -i "${ISO}" 2>/dev/null | awk -F': ' '/^Volume id/{print $2}')"
[[ -n "${LABEL}" ]] || { echo "could not read ISO volume label" >&2; exit 1; }
echo "ISO label: ${LABEL}"

echo "booting ${ISO} (accel: ${ACCEL_NAME}, timeout ${TIMEOUT}s)"
qemu-system-x86_64 \
  "${ACCEL[@]}" -m 3072 -smp 2 \
  -machine q35 \
  -kernel "${KERNEL}" -initrd "${INITRD}" \
  -append "archisobasedir=velocity archisolabel=${LABEL} rootdelay=20 console=tty0 console=ttyS0,115200 velocity.selftest" \
  -device ahci,id=ahci \
  -drive file="${ISO}",media=cdrom,if=none,id=cd0,readonly=on \
  -device ide-cd,drive=cd0,bus=ahci.0 \
  -drive file="${OUT}/disk.qcow2",if=virtio,format=qcow2 \
  -nic user,model=virtio-net-pci \
  -display none -serial "file:${SERIAL}" -monitor none \
  -no-reboot &
QPID=$!

# print new serial lines as they arrive so CI logs show progress
printed=0
stream() {
  local total
  total="$(wc -l <"${SERIAL}")"
  if (( total > printed )); then
    sed -n "$((printed + 1)),${total}p" "${SERIAL}" | tr -d '\r' | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g; s/^/  [vm] /'
    printed=${total}
  fi
}

deadline=$((SECONDS + TIMEOUT))
result=""
while kill -0 "${QPID}" 2>/dev/null; do
  stream
  if grep -q 'VELOCITY_SELFTEST_OK' "${SERIAL}"; then result=ok; break; fi
  if grep -q 'VELOCITY_SELFTEST_FAIL' "${SERIAL}"; then result=fail; break; fi
  if (( SECONDS >= deadline )); then result=timeout; break; fi
  sleep 5
done
stream
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
