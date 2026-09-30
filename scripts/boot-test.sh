#!/usr/bin/env bash
# Boot a Velocity ISO headless in QEMU and read the verdict off the serial console.
#
#   scripts/boot-test.sh out/velocity-*.iso [--mode live|install] [--timeout SECS]
#
#   live     boot the ISO with `velocity.selftest`, expect VELOCITY_SELFTEST_OK   (default)
#   install  1) boot the ISO with `velocity.autoinstall`, which runs an unattended
#               velocity-install onto a blank virtio disk, expect VELOCITY_AUTOINSTALL_OK
#            2) boot from that disk (no ISO), expect VELOCITY_INSTALLTEST_OK
#
# Needs: qemu-system-x86_64, qemu-img, bsdtar, blkid or isoinfo. Uses KVM when available.
set -euo pipefail

ISO="${1:?path to iso}"; shift || true
MODE=live
TIMEOUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) echo "unknown option $1" >&2; exit 1 ;;
  esac
done

OUT="$(dirname "${ISO}")/boot-test-${MODE}"
mkdir -p "${OUT}"

bsdtar -xf "${ISO}" -C "${OUT}" velocity/boot/x86_64/vmlinuz-linux velocity/boot/x86_64/initramfs-linux.img
KERNEL="${OUT}/velocity/boot/x86_64/vmlinuz-linux"
INITRD="${OUT}/velocity/boot/x86_64/initramfs-linux.img"
DISK="${OUT}/disk.qcow2"
qemu-img create -q -f qcow2 "${DISK}" 20G

ACCEL=(-accel tcg -cpu max); ACCEL_NAME=tcg
if [[ -w /dev/kvm ]]; then ACCEL=(-accel kvm -cpu host); ACCEL_NAME=kvm; fi

LABEL="$(blkid -o value -s LABEL "${ISO}" 2>/dev/null || true)"
[[ -n "${LABEL}" ]] || LABEL="$(isoinfo -d -i "${ISO}" 2>/dev/null | awk -F': ' '/^Volume id/{print $2}')"
[[ -n "${LABEL}" ]] || { echo "could not read ISO volume label" >&2; exit 1; }
echo "ISO label: ${LABEL}   accel: ${ACCEL_NAME}   mode: ${MODE}"

# run_vm <serial-log> <ok-marker> <fail-marker> <timeout> <qemu args...>
# Streams the serial console, returns 0 on ok-marker, 1 on fail-marker, 2 on timeout/early exit.
run_vm() {
  local serial="$1" okm="$2" failm="$3" timeout="$4"; shift 4
  : >"${serial}"
  qemu-system-x86_64 "${ACCEL[@]}" -machine q35 -m 4096 -smp 2 \
    -display none -serial "file:${serial}" -monitor none -no-reboot "$@" &
  local qpid=$!
  local printed=0 total result=""
  stream() {
    total="$(wc -l <"${serial}")"
    if (( total > printed )); then
      sed -n "$((printed + 1)),${total}p" "${serial}" | tr -d '\r' \
        | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g; s/\x1b[()][A-Z0-9]//g; s/^/  [vm] /'
      printed=${total}
    fi
  }
  local deadline=$((SECONDS + timeout))
  while kill -0 "${qpid}" 2>/dev/null; do
    stream
    if grep -q "${okm}" "${serial}"; then result=ok; break; fi
    if grep -q "${failm}" "${serial}"; then result=fail; break; fi
    if (( SECONDS >= deadline )); then result=timeout; break; fi
    sleep 5
  done
  stream
  sleep 10
  kill "${qpid}" 2>/dev/null || true
  wait "${qpid}" 2>/dev/null || true
  # The VM may print its verdict and power off between two polls; check once more.
  if [[ -z "${result}" || "${result}" == timeout ]]; then
    if grep -q "${okm}" "${serial}"; then result=ok
    elif grep -q "${failm}" "${serial}"; then result=fail
    fi
  fi
  case "${result}" in
    ok) return 0 ;;
    fail) return 1 ;;
    *) echo "  (no verdict: ${result:-qemu exited early})"; return 2 ;;
  esac
}

# shellcheck disable=SC2054  # commas are part of QEMU's option syntax, not array separators
CDROM=(-device ahci,id=ahci -drive "file=${ISO},media=cdrom,if=none,id=cd0,readonly=on" -device ide-cd,drive=cd0,bus=ahci.0)
VDISK=(-drive "file=${DISK},if=virtio,format=qcow2")
# shellcheck disable=SC2054
NET=(-nic user,model=virtio-net-pci)
BASE_APPEND="archisobasedir=velocity archisolabel=${LABEL} rootdelay=20 cow_spacesize=1G console=tty0 console=ttyS0,115200"

case "${MODE}" in
  live)
    echo "== boot live ISO, run self-test =="
    if run_vm "${OUT}/serial-live.log" VELOCITY_SELFTEST_OK VELOCITY_SELFTEST_FAIL "${TIMEOUT:-720}" \
        -kernel "${KERNEL}" -initrd "${INITRD}" -append "${BASE_APPEND} velocity.selftest" \
        "${CDROM[@]}" "${VDISK[@]}" "${NET[@]}"; then
      echo "LIVE TEST PASSED"
    else
      echo "LIVE TEST FAILED"; exit 1
    fi ;;
  install)
    echo "== phase 1: boot live ISO, unattended install to virtio disk =="
    if ! run_vm "${OUT}/serial-install.log" VELOCITY_AUTOINSTALL_OK VELOCITY_AUTOINSTALL_FAIL "${TIMEOUT:-2400}" \
        -kernel "${KERNEL}" -initrd "${INITRD}" -append "${BASE_APPEND} velocity.autoinstall" \
        "${CDROM[@]}" "${VDISK[@]}" "${NET[@]}"; then
      echo "INSTALL TEST FAILED (phase 1: install)"; exit 1
    fi
    echo "== phase 2: boot the installed system from disk =="
    if run_vm "${OUT}/serial-firstboot.log" VELOCITY_INSTALLTEST_OK VELOCITY_INSTALLTEST_FAIL 600 \
        -boot c "${VDISK[@]}" "${NET[@]}"; then
      echo "INSTALL TEST PASSED"
    else
      echo "INSTALL TEST FAILED (phase 2: first boot)"; exit 1
    fi ;;
  *) echo "unknown mode ${MODE}" >&2; exit 1 ;;
esac
