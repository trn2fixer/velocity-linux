#!/usr/bin/env bash
# Static checks that run anywhere bash exists (Git Bash on Windows, CI, Arch).
#   scripts/check.sh
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO}" || exit 1
fails=0
pass() { printf 'ok   %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*" >&2; fails=$((fails + 1)); }

# 1. every bash script parses
scripts=(
  build.sh scripts/build-iso.sh scripts/check.sh scripts/boot-test.sh
  profile/profiledef.sh
  profile/airootfs/usr/local/bin/velocity-live-init
  profile/airootfs/usr/local/bin/velocity-selftest
  profile/airootfs/usr/local/bin/choose-mirror
  profile/airootfs/usr/local/bin/livecd-sound
  profile/airootfs/usr/local/bin/Installation_guide
  velocity-tools/bin/velocity velocity-tools/bin/velocity-install
  velocity-tools/lib/common.sh velocity-tools/lib/presets.sh velocity-tools/lib/brand.sh
  velocity-tools/PKGBUILD velocity-tools/velocity-tools.install
)
for s in "${scripts[@]}"; do
  if bash -n "${s}" 2>/dev/null; then pass "syntax ${s}"; else fail "syntax ${s}"; fi
done
for p in velocity-tools/presets/*/*.preset; do
  if bash -n "${p}" 2>/dev/null; then pass "syntax ${p}"; else fail "syntax ${p}"; fi
done

# 2. shellcheck when available
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -S warning -x -e SC1091,SC2154 build.sh scripts/*.sh velocity-tools/bin/* velocity-tools/lib/*.sh \
      profile/airootfs/usr/local/bin/*; then
    pass "shellcheck"
  else
    fail "shellcheck"
  fi
else
  printf 'skip shellcheck (not installed)\n'
fi

# 3. presets declare required fields and load cleanly
export VELOCITY_PRESETS="${REPO}/velocity-tools/presets" VELOCITY_SHARE="${REPO}/velocity-tools/share"
export VELOCITY_LOG=/dev/null VELOCITY_STATE_DIR=/tmp/velocity-check-state NO_COLOR=1
# shellcheck disable=SC1091
source velocity-tools/lib/common.sh
# shellcheck disable=SC1091
source velocity-tools/lib/presets.sh
for kind in desktop bundle theme; do
  for id in $(preset_ids "${kind}"); do
    if preset_load "${kind}" "${id}" && [[ -n "${NAME}" && -n "${DESC}" && "${KIND}" == "${kind}" && ${#PACKAGES[@]} -gt 0 ]]; then
      pass "preset ${kind}/${id} (${#PACKAGES[@]} pkgs)"
    else
      fail "preset ${kind}/${id}: NAME/DESC/KIND/PACKAGES missing or KIND != ${kind}"
    fi
  done
done

# 4. profile structure
for f in profile/packages.x86_64 profile/pacman.conf profile/syslinux/syslinux.cfg \
         profile/efiboot/loader/loader.conf profile/efiboot/loader/entries/01-velocity.conf \
         profile/airootfs/etc/os-release profile/symlinks.txt; do
  [[ -f "${f}" ]] && pass "exists ${f}" || fail "missing ${f}"
done
grep -q '^velocity-tools$' profile/packages.x86_64 && pass "velocity-tools in package list" || fail "velocity-tools not in packages.x86_64"
grep -q '^\[velocity\]' profile/pacman.conf && pass "[velocity] repo in build pacman.conf" || fail "no [velocity] repo in profile/pacman.conf"
grep -q '^\[velocity\]' profile/airootfs/etc/pacman.conf && fail "live pacman.conf must NOT contain [velocity]" || pass "live pacman.conf clean"

# every file with exec bit declared in profiledef exists
while read -r line; do
  [[ "${line}" =~ \[\"([^\"]+)\"\]=\"0:0:755\" ]] || continue
  f="profile/airootfs${BASH_REMATCH[1]}"
  [[ -f "${f}" ]] && pass "profiledef exec ${BASH_REMATCH[1]}" || fail "profiledef references missing ${f}"
done <profile/profiledef.sh

# symlink manifest is well formed
while read -r link target; do
  [[ -z "${link}" || "${link}" == \#* ]] && continue
  [[ -n "${target}" ]] && pass "symlink ${link}" || fail "symlink ${link} has no target"
done <profile/symlinks.txt

# 5. hyprland rice references only files that exist
for f in hypr/hyprland.conf hypr/theme.conf hypr/hyprpaper.conf waybar/config.jsonc waybar/style.css waybar/theme.css \
         kitty/kitty.conf kitty/theme.conf rofi/config.rasi dunst/dunstrc; do
  [[ -f "velocity-tools/share/configs/hyprland/${f}" ]] && pass "rice ${f}" || fail "rice missing ${f}"
done

# 6. JSON-ish configs parse (strip // comments)
py=""
for cand in python3 python py; do
  if command -v "${cand}" >/dev/null 2>&1 && "${cand}" -c 'pass' >/dev/null 2>&1; then py="${cand}"; break; fi
done
if [[ -n "${py}" ]]; then
  for j in velocity-tools/share/fastfetch/config.jsonc velocity-tools/share/configs/hyprland/waybar/config.jsonc; do
    if "${py}" - "${j}" <<'EOF'
import json, re, sys
src = open(sys.argv[1], encoding="utf-8").read()
src = re.sub(r"^\s*//.*$", "", src, flags=re.M)
json.loads(src)
EOF
    then pass "json ${j}"; else fail "json ${j}"; fi
  done
else
  printf 'skip json checks (no python)\n'
fi

rm -rf /tmp/velocity-check-state
echo
if [[ ${fails} -eq 0 ]]; then echo "all checks passed"; else echo "${fails} check(s) failed"; exit 1; fi
