#!/usr/bin/env bash
# Branding: makes an Arch system identify as Velocity Linux without breaking
# anything that checks ID_LIKE=arch. Re-run safe. Reapplied by a pacman hook
# whenever `filesystem` updates /usr/lib/os-release.

brand_os_release() {
  local f; f="$(target_path /etc/os-release)"
  cat >"${f}" <<'EOF'
NAME="Velocity Linux"
PRETTY_NAME="Velocity Linux"
ID=velocity
ID_LIKE=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;124;92;255"
HOME_URL="https://github.com/velocity-linux/velocity"
DOCUMENTATION_URL="https://github.com/velocity-linux/velocity/tree/main/docs"
SUPPORT_URL="https://github.com/velocity-linux/velocity/discussions"
BUG_REPORT_URL="https://github.com/velocity-linux/velocity/issues"
LOGO=velocity
EOF
  # /etc/os-release is normally a symlink to /usr/lib/os-release; we replaced
  # it with a real file above, which is what systemd documents as the override.
  cat >"$(target_path /etc/lsb-release)" <<'EOF'
DISTRIB_ID="Velocity"
DISTRIB_RELEASE="rolling"
DISTRIB_DESCRIPTION="Velocity Linux"
EOF
}

brand_issue() {
  cat >"$(target_path /etc/issue)" <<'EOF'
Velocity Linux \r (\l)

EOF
  cat >"$(target_path /etc/motd)" <<'EOF'
EOF
}

brand_fastfetch() {
  local d; d="$(target_path /etc/velocity)"
  mkdir -p "${d}"
  cp -f "${VELOCITY_SHARE}/fastfetch/config.jsonc" "${d}/fastfetch.jsonc" 2>/dev/null || true
  cp -f "${VELOCITY_SHARE}/fastfetch/logo.txt" "${d}/logo.txt" 2>/dev/null || true
}

brand_grub() {
  # Installs the Velocity GRUB theme and points /etc/default/grub at it.
  local theme_src="${VELOCITY_SHARE}/grub/theme"
  local theme_dst; theme_dst="$(target_path /boot/grub/themes/velocity)"
  local def; def="$(target_path /etc/default/grub)"
  [[ -d "${theme_src}" && -f "${def}" ]] || return 0
  mkdir -p "${theme_dst}"
  cp -rT "${theme_src}" "${theme_dst}"
  sed -i \
    -e 's|^#\?GRUB_DISTRIBUTOR=.*|GRUB_DISTRIBUTOR="Velocity"|' \
    -e 's|^#\?GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/velocity/theme.txt"|' \
    -e 's|^#\?GRUB_TIMEOUT=.*|GRUB_TIMEOUT=3|' \
    -e 's|^#\?GRUB_DISABLE_OS_PROBER=.*|GRUB_DISABLE_OS_PROBER=false|' \
    "${def}"
  grep -q '^GRUB_THEME=' "${def}" || echo 'GRUB_THEME="/boot/grub/themes/velocity/theme.txt"' >>"${def}"
  grep -q '^GRUB_DISTRIBUTOR=' "${def}" || echo 'GRUB_DISTRIBUTOR="Velocity"' >>"${def}"
}

brand_wallpapers() {
  local dst; dst="$(target_path /usr/share/backgrounds/velocity)"
  mkdir -p "${dst}"
  cp -f "${VELOCITY_SHARE}"/wallpapers/*.png "${dst}/" 2>/dev/null || true
}

brand_shell_defaults() {
  # System-wide shell niceties. Users can override in their own rc files.
  local d; d="$(target_path /etc/velocity)"
  mkdir -p "${d}" "$(target_path /etc/profile.d)"
  cp -f "${VELOCITY_SHARE}/shell/starship.toml" "${d}/starship.toml" 2>/dev/null || true
  cp -f "${VELOCITY_SHARE}/shell/velocity.sh" "$(target_path /etc/profile.d/velocity.sh)" 2>/dev/null || true
}

brand_apply() {
  log "applying Velocity branding to ${VELOCITY_ROOT}"
  brand_os_release
  brand_issue
  brand_fastfetch
  brand_wallpapers
  brand_shell_defaults
  brand_grub
  ok "branding applied"
}
