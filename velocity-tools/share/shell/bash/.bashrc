# ~/.bashrc · Velocity Linux defaults. Edit freely; this file is yours.
[[ $- != *i* ]] && return

HISTSIZE=10000
HISTFILESIZE=10000
HISTCONTROL=ignoreboth
shopt -s histappend checkwinsize autocd cdspell

alias ls='eza --icons --group-directories-first'
alias ll='eza -la --icons --group-directories-first --git'
alias lt='eza --tree --level=2 --icons'
alias cat='bat --paging=never --style=plain'
alias ..='cd ..'
alias up='sudo pacman -Syu'
alias vl='velocity'

[[ -f /etc/velocity/starship.toml ]] && export STARSHIP_CONFIG=/etc/velocity/starship.toml
command -v starship >/dev/null && eval "$(starship init bash)"
command -v zoxide   >/dev/null && eval "$(zoxide init bash)"
