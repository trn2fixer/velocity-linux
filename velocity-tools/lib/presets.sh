#!/usr/bin/env bash
# Preset engine. A preset is a bash-sourceable file with these variables:
#
#   NAME="KDE Plasma"                      human name
#   DESC="Polished, full-featured desktop" one line
#   KIND="desktop"                         desktop | bundle | theme
#   TAGS=(wayland full)                    free-form
#   PACKAGES=(plasma-desktop konsole ...)  installed with pacman
#   OPTIONAL=(kdeconnect ...)              offered as checkboxes
#   SERVICES=(sddm bluetooth)              systemctl enable
#   CONFLICTS=(gdm lightdm)                services to disable / packages left alone
#   SESSION="plasma"                       for display manager default
#   post_apply() { ... }                   optional function, runs in target context
#
# shellcheck disable=SC2034

# Reset preset variables so a stale preset never leaks into the next.
preset_reset() {
  NAME="" DESC="" KIND="" SESSION=""
  TAGS=() PACKAGES=() OPTIONAL=() SERVICES=() CONFLICTS=()
  unset -f post_apply 2>/dev/null || true
}

preset_file() { # preset_file <kind> <id>
  local kind="$1" id="$2"
  local f="${VELOCITY_PRESETS}/${kind}s/${id}.preset"
  [[ -r "${f}" ]] && printf '%s\n' "${f}"
}

preset_load() { # preset_load <kind> <id>
  local f
  f="$(preset_file "$1" "$2")" || return 1
  preset_reset
  PRESET_ID="$2"
  # shellcheck disable=SC1090
  source "${f}"
}

preset_ids() { # preset_ids <kind>
  local f
  for f in "${VELOCITY_PRESETS}/$1s"/*.preset; do
    [[ -e "${f}" ]] || continue
    basename "${f}" .preset
  done
}

preset_list() { # preset_list <kind>  -> table
  local kind="$1" id
  for id in $(preset_ids "${kind}"); do
    preset_load "${kind}" "${id}"
    local mark=" "
    [[ "$(state_get "${kind}")" == "${id}" ]] && mark="${C_CYAN}●${C_RESET}"
    printf ' %s %s%-12s%s %s%s%s\n' "${mark}" "${C_BOLD}" "${id}" "${C_RESET}" "${C_DIM}" "${DESC}" "${C_RESET}"
  done
}

preset_apply() { # preset_apply <kind> <id> [--with opt1,opt2] [--no-optional]
  local kind="$1" id="$2"; shift 2
  local with="" ask_optional=1
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --with) with="$2"; shift 2 ;;
      --no-optional) ask_optional=0; shift ;;
      *) shift ;;
    esac
  done

  preset_load "${kind}" "${id}" || die "unknown ${kind}: ${id}"
  hdr "${NAME}"
  dim "${DESC}"

  local pkgs=("${PACKAGES[@]}")

  # Optional packages: from --with, or interactive checkboxes.
  if [[ ${#OPTIONAL[@]} -gt 0 ]]; then
    if [[ -n "${with}" ]]; then
      IFS=',' read -r -a extra <<<"${with}"
      pkgs+=("${extra[@]}")
    elif [[ ${ask_optional} -eq 1 && -t 0 ]]; then
      mapfile -t extra < <(ui_multi "Optional extras for ${NAME}:" "${OPTIONAL[@]}")
      pkgs+=("${extra[@]}")
    fi
  fi

  snapshot_maybe "${kind}-${id}"

  pac_install "${pkgs[@]}"

  local c
  for c in "${CONFLICTS[@]}"; do svc_disable "${c}"; done
  svc_enable "${SERVICES[@]}"

  if declare -F post_apply >/dev/null; then
    log "running post-apply steps"
    post_apply
  fi

  state_set "${kind}" "${id}"
  ok "${NAME} applied"
}

preset_show() { # preset_show <kind> <id>
  preset_load "$1" "$2" || die "unknown $1: $2"
  hdr "${NAME}"
  printf '%s\n\n' "${DESC}"
  printf '%sPackages%s   %s\n' "${C_BOLD}" "${C_RESET}" "${PACKAGES[*]}"
  [[ ${#OPTIONAL[@]} -gt 0 ]] && printf '%sOptional%s   %s\n' "${C_BOLD}" "${C_RESET}" "${OPTIONAL[*]}"
  [[ ${#SERVICES[@]} -gt 0 ]] && printf '%sServices%s   %s\n' "${C_BOLD}" "${C_RESET}" "${SERVICES[*]}"
  [[ ${#TAGS[@]} -gt 0 ]] && printf '%sTags%s       %s\n' "${C_BOLD}" "${C_RESET}" "${TAGS[*]}"
  return 0
}
