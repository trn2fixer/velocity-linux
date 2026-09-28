# Velocity Linux shell defaults (system-wide, /etc/profile.d).
# Users override in ~/.bashrc, ~/.zshrc or ~/.config/fish/config.fish.
export STARSHIP_CONFIG="${STARSHIP_CONFIG:-/etc/velocity/starship.toml}"
export EDITOR="${EDITOR:-micro}"
export VISUAL="${VISUAL:-${EDITOR}}"
export FASTFETCH_CONFIG="${FASTFETCH_CONFIG:-/etc/velocity/fastfetch.jsonc}"
