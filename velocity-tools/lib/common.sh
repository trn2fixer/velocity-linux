#!/usr/bin/env bash
# Velocity Linux shared library. Sourced by `velocity` and `velocity-install`.
# shellcheck disable=SC2034

VELOCITY_VERSION="${VELOCITY_VERSION:-0.1.0}"
VELOCITY_SHARE="${VELOCITY_SHARE:-/usr/share/velocity}"
VELOCITY_PRESETS="${VELOCITY_PRESETS:-${VELOCITY_SHARE}/presets}"
VELOCITY_STATE_DIR="${VELOCITY_STATE_DIR:-/var/lib/velocity}"
VELOCITY_LOG="${VELOCITY_LOG:-/var/log/velocity.log}"

# Target root. "/" for the running system, "/mnt" while installing.
VELOCITY_ROOT="${VELOCITY_ROOT:-/}"

# ---------- palette ----------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_VIOLET=$'\e[38;2;124;92;255m'
  C_CYAN=$'\e[38;2;34;211;238m'
  C_DIM=$'\e[38;2;140;140;160m'
  C_RED=$'\e[38;2;243;139;168m'
  C_GREEN=$'\e[38;2;166;227;161m'
  C_YELLOW=$'\e[38;2;249;226;175m'
  C_BOLD=$'\e[1m'
  C_RESET=$'\e[0m'
else
  C_VIOLET='' C_CYAN='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BOLD='' C_RESET=''
fi

# ---------- logging ----------
_log_file() {
  local f="${VELOCITY_LOG}"
  mkdir -p "$(dirname "${f}")" 2>/dev/null || return 0
  printf '%s %s\n' "$(date '+%F %T')" "$*" >>"${f}" 2>/dev/null || true
}
log()  { printf '%s▸%s %s\n' "${C_VIOLET}" "${C_RESET}" "$*"; _log_file "INFO $*"; }
ok()   { printf '%s✓%s %s\n' "${C_GREEN}" "${C_RESET}" "$*"; _log_file "OK   $*"; }
warn() { printf '%s!%s %s\n' "${C_YELLOW}" "${C_RESET}" "$*" >&2; _log_file "WARN $*"; }
err()  { printf '%s✗%s %s\n' "${C_RED}" "${C_RESET}" "$*" >&2; _log_file "ERR  $*"; }
die()  { err "$@"; exit 1; }
hdr()  { printf '\n%s%s%s%s\n' "${C_BOLD}" "${C_CYAN}" "$*" "${C_RESET}"; }
dim()  { printf '%s%s%s\n' "${C_DIM}" "$*" "${C_RESET}"; }

# ---------- environment ----------
need_root() {
  [[ ${EUID} -eq 0 ]] || die "This needs root. Try: sudo $0 $*"
}

has() { command -v "$1" >/dev/null 2>&1; }

is_live() { [[ -d /run/archiso ]] || grep -qs 'archisobasedir' /proc/cmdline; }

in_target() {
  # Run a command inside the target root (chroot when installing, direct otherwise).
  if [[ "${VELOCITY_ROOT}" == "/" ]]; then
    "$@"
  else
    arch-chroot "${VELOCITY_ROOT}" "$@"
  fi
}

target_path() { # target_path /etc/foo -> /mnt/etc/foo
  local p="$1"
  if [[ "${VELOCITY_ROOT}" == "/" ]]; then printf '%s' "${p}"; else printf '%s%s' "${VELOCITY_ROOT%/}" "${p}"; fi
}

# ---------- UI (gum when available, plain fallback) ----------
ui_has_gum() { has gum && [[ -t 0 && -t 1 ]]; }

ui_choose() { # ui_choose "header" opt1 opt2 ...
  local header="$1"; shift
  if ui_has_gum; then
    gum choose --header "${header}" --cursor.foreground "#22d3ee" --header.foreground "#7c5cff" "$@"
  else
    local i=1 opt
    printf '%s\n' "${header}" >&2
    for opt in "$@"; do printf '  %d) %s\n' "${i}" "${opt}" >&2; ((i++)); done
    local n
    while :; do
      read -r -p "> " n
      [[ "${n}" =~ ^[0-9]+$ && ${n} -ge 1 && ${n} -le $# ]] && { printf '%s\n' "${!n}"; return 0; }
    done
  fi
}

ui_multi() { # ui_multi "header" opt1 opt2 ... ; prints one per line
  local header="$1"; shift
  if ui_has_gum; then
    gum choose --no-limit --header "${header}" --cursor.foreground "#22d3ee" --header.foreground "#7c5cff" --selected.foreground "#22d3ee" "$@"
  else
    local i=1 opt
    printf '%s (space-separated numbers, empty for none)\n' "${header}" >&2
    for opt in "$@"; do printf '  %d) %s\n' "${i}" "${opt}" >&2; ((i++)); done
    local line n
    read -r -p "> " line
    for n in ${line}; do
      [[ "${n}" =~ ^[0-9]+$ && ${n} -ge 1 && ${n} -le $# ]] && printf '%s\n' "${!n}"
    done
  fi
}

ui_confirm() { # ui_confirm "question" -> exit 0 yes
  if ui_has_gum; then
    gum confirm --prompt.foreground "#7c5cff" --selected.background "#22d3ee" "$1"
  else
    local a
    read -r -p "$1 [y/N] " a
    [[ "${a}" =~ ^[Yy] ]]
  fi
}

ui_input() { # ui_input "prompt" [default]
  if ui_has_gum; then
    gum input --prompt "$1 " --value "${2:-}" --prompt.foreground "#7c5cff" --cursor.foreground "#22d3ee"
  else
    local a
    read -r -p "$1 ${2:+[$2] }" a
    printf '%s\n' "${a:-${2:-}}"
  fi
}

ui_password() {
  if ui_has_gum; then
    gum input --password --prompt "$1 " --prompt.foreground "#7c5cff"
  else
    local a
    read -r -s -p "$1 " a; echo >&2
    printf '%s\n' "${a}"
  fi
}

ui_spin() { # ui_spin "title" cmd args...
  local title="$1"; shift
  if ui_has_gum; then
    gum spin --spinner dot --title "${title}" --spinner.foreground "#22d3ee" -- "$@"
  else
    log "${title}"
    "$@"
  fi
}

ui_banner() {
  printf '%s' "${C_VIOLET}"
  cat <<'EOF'
  ╦  ╦╔═╗╦  ╔═╗╔═╗╦╔╦╗╦ ╦
  ╚╗╔╝║╣ ║  ║ ║║  ║ ║ ╚╦╝
   ╚╝ ╚═╝╩═╝╚═╝╚═╝╩ ╩  ╩
EOF
  printf '%s  %sArch-based. Yours from the first boot.%s\n\n' "${C_RESET}" "${C_CYAN}" "${C_RESET}"
}

# ---------- pacman ----------
pac_installed() { in_target pacman -Qq "$1" >/dev/null 2>&1; }

pac_install() { # pac_install pkg...
  [[ $# -eq 0 ]] && return 0
  local missing=()
  local p
  for p in "$@"; do pac_installed "${p}" || missing+=("${p}"); done
  [[ ${#missing[@]} -eq 0 ]] && { dim "already installed: $*"; return 0; }
  log "installing: ${missing[*]}"
  in_target pacman -S --needed --noconfirm "${missing[@]}"
}

pac_remove() {
  [[ $# -eq 0 ]] && return 0
  local present=()
  local p
  for p in "$@"; do pac_installed "${p}" && present+=("${p}"); done
  [[ ${#present[@]} -eq 0 ]] && return 0
  log "removing: ${present[*]}"
  in_target pacman -Rns --noconfirm "${present[@]}"
}

svc_enable() { # svc_enable unit...
  [[ $# -eq 0 ]] && return 0
  log "enabling: $*"
  if [[ "${VELOCITY_ROOT}" == "/" ]]; then
    systemctl enable "$@"
  else
    systemctl --root="${VELOCITY_ROOT}" enable "$@"
  fi
}

svc_disable() {
  [[ $# -eq 0 ]] && return 0
  if [[ "${VELOCITY_ROOT}" == "/" ]]; then
    systemctl disable "$@" 2>/dev/null || true
  else
    systemctl --root="${VELOCITY_ROOT}" disable "$@" 2>/dev/null || true
  fi
}

# ---------- state ----------
state_set() { # state_set key value
  local d; d="$(target_path "${VELOCITY_STATE_DIR}")"
  mkdir -p "${d}"
  printf '%s\n' "$2" >"${d}/$1"
}
state_get() { # state_get key [default]
  local f; f="$(target_path "${VELOCITY_STATE_DIR}")/$1"
  if [[ -r "${f}" ]]; then cat "${f}"; else printf '%s\n' "${2:-}"; fi
}

# ---------- btrfs snapshot (safety net before big changes) ----------
snapshot_maybe() { # snapshot_maybe "reason"
  local root; root="$(target_path /)"
  [[ "$(findmnt -no FSTYPE "${root}" 2>/dev/null)" == "btrfs" ]] || return 0
  has btrfs || return 0
  local snapdir; snapdir="$(target_path /.snapshots)"
  mkdir -p "${snapdir}"
  local name; name="velocity-$(date +%Y%m%d-%H%M%S)-${1// /_}"
  if btrfs subvolume snapshot -r "${root}" "${snapdir}/${name}" >/dev/null 2>&1; then
    ok "snapshot created: /.snapshots/${name}"
  fi
}

# ---------- users ----------
target_users() { # regular users in target (uid >= 1000, not nobody)
  awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' "$(target_path /etc/passwd)" 2>/dev/null
}

user_home() { # user_home name -> path inside target
  local h
  h="$(awk -F: -v u="$1" '$1 == u {print $6}' "$(target_path /etc/passwd)")"
  target_path "${h:-/home/$1}"
}

# Copy a config tree into a user's home with ownership fixed.
install_user_config() { # install_user_config <user> <src_dir> <dest_rel>
  local user="$1" src="$2" rel="$3"
  local home; home="$(user_home "${user}")"
  [[ -d "${src}" ]] || return 0
  mkdir -p "${home}/${rel}"
  cp -rT "${src}" "${home}/${rel}"
  in_target chown -R "${user}:${user}" "/${home#"$(target_path /)"}/${rel}" 2>/dev/null \
    || chown -R "${user}:${user}" "${home}/${rel}" 2>/dev/null || true
}
