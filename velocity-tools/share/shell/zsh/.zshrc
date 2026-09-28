# ~/.zshrc · Velocity Linux defaults. Edit freely; this file is yours.
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt autocd share_history hist_ignore_dups hist_ignore_space correct

autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

alias ls='eza --icons --group-directories-first'
alias ll='eza -la --icons --group-directories-first --git'
alias lt='eza --tree --level=2 --icons'
alias cat='bat --paging=never --style=plain'
alias ..='cd ..'
alias up='sudo pacman -Syu'
alias vl='velocity'

[[ -f /etc/velocity/starship.toml ]] && export STARSHIP_CONFIG=/etc/velocity/starship.toml
command -v starship >/dev/null && eval "$(starship init zsh)"
command -v zoxide   >/dev/null && eval "$(zoxide init zsh)"
