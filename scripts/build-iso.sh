#!/usr/bin/env bash
# Build the Velocity Linux ISO. Runs INSIDE an Arch Linux environment as root
# (the Docker image from ./Dockerfile, or a real Arch box with archiso installed).
#
#   scripts/build-iso.sh [--out DIR] [--work DIR] [--skip-assets]
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${REPO}/out"
WORK="/tmp/velocity-work"
SKIP_ASSETS=0
LOCAL_REPO=/velocity-repo                       # path referenced by profile/pacman.conf
AIROOTFS_REPO="${REPO}/profile/airootfs/opt/velocity-repo"  # copied onto the ISO for the installer

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --work) WORK="$2"; shift 2 ;;
    --skip-assets) SKIP_ASSETS=1; shift ;;
    *) echo "unknown option $1" >&2; exit 1 ;;
  esac
done

log() { printf '\e[38;2;124;92;255m▸\e[0m %s\n' "$*"; }
ok()  { printf '\e[38;2;166;227;161m✓\e[0m %s\n' "$*"; }
die() { printf '\e[38;2;243;139;168m✗\e[0m %s\n' "$*" >&2; exit 1; }

[[ ${EUID} -eq 0 ]] || die "run as root (mkarchiso needs it)"
[[ -f /etc/arch-release ]] || die "this must run on Arch Linux (use ./build.sh for Docker)"

log "installing build dependencies"
pacman -Sy --needed --noconfirm archiso base-devel git python python-pillow >/dev/null

# ---------- 1. assets ----------
if [[ ${SKIP_ASSETS} -eq 0 ]]; then
  log "generating assets (wallpapers, splash, grub theme images)"
  python3 "${REPO}/assets/generate.py" --out "${REPO}/assets/out"
fi
mkdir -p "${REPO}/profile/syslinux"
[[ -f "${REPO}/assets/out/splash.png" ]] && cp -f "${REPO}/assets/out/splash.png" "${REPO}/profile/syslinux/splash.png"

# ---------- 2. build velocity-tools package ----------
log "building velocity-tools"
BUILD_USER=velobuild
id -u "${BUILD_USER}" >/dev/null 2>&1 || useradd -m -s /bin/bash "${BUILD_USER}"
PKG_TMP="$(mktemp -d)"
cp -r "${REPO}/velocity-tools" "${REPO}/LICENSE" "${PKG_TMP}/"
mkdir -p "${PKG_TMP}/assets" && cp -r "${REPO}/assets/out" "${PKG_TMP}/assets/" 2>/dev/null || true
chown -R "${BUILD_USER}" "${PKG_TMP}"
( cd "${PKG_TMP}/velocity-tools" && sudo -u "${BUILD_USER}" makepkg -f --nodeps --noconfirm >/dev/null )
PKG_FILE="$(ls "${PKG_TMP}"/velocity-tools/velocity-tools-*.pkg.tar.* | head -n1)"
[[ -f "${PKG_FILE}" ]] || die "makepkg produced no package"
ok "built $(basename "${PKG_FILE}")"

# ---------- 3. local repo (for mkarchiso and for the installer on the ISO) ----------
log "creating local pacman repo"
rm -rf "${LOCAL_REPO}" "${AIROOTFS_REPO}"
mkdir -p "${LOCAL_REPO}"
cp "${PKG_FILE}" "${LOCAL_REPO}/"
repo-add -q "${LOCAL_REPO}/velocity.db.tar.gz" "${LOCAL_REPO}"/*.pkg.tar.*
mkdir -p "${AIROOTFS_REPO}"
cp -r "${LOCAL_REPO}/." "${AIROOTFS_REPO}/"
ok "repo at ${LOCAL_REPO} (copied to airootfs:/opt/velocity-repo)"

# ---------- 4. symlinks declared in profile/symlinks.txt ----------
log "creating airootfs symlinks"
while read -r link target; do
  [[ -z "${link}" || "${link}" == \#* ]] && continue
  mkdir -p "$(dirname "${REPO}/profile/airootfs/${link}")"
  ln -sfn "${target}" "${REPO}/profile/airootfs/${link}"
done <"${REPO}/profile/symlinks.txt"

# executable bits are also declared in profiledef.sh, but make the tree honest on Linux
chmod 755 "${REPO}"/profile/airootfs/usr/local/bin/* 2>/dev/null || true

# ---------- 5. mkarchiso ----------
log "running mkarchiso (this takes a while)"
rm -rf "${WORK}"
mkdir -p "${OUT}" "${WORK}"
mkarchiso -v -w "${WORK}" -o "${OUT}" "${REPO}/profile"

# ---------- 6. checksums ----------
( cd "${OUT}" && sha256sum ./*.iso >SHA256SUMS )
ok "ISO ready:"
ls -lh "${OUT}"/*.iso
cat "${OUT}/SHA256SUMS"

# tidy: do not leave the built repo inside the source tree for git
rm -rf "${AIROOTFS_REPO}"
find "${REPO}/profile/airootfs" -type l -delete
