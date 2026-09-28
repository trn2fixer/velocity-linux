# ~/.config/fish/config.fish · Velocity Linux defaults. Edit freely.
set -g fish_greeting

alias ls 'eza --icons --group-directories-first'
alias ll 'eza -la --icons --group-directories-first --git'
alias lt 'eza --tree --level=2 --icons'
alias cat 'bat --paging=never --style=plain'
alias up 'sudo pacman -Syu'
alias vl 'velocity'

if test -f /etc/velocity/starship.toml
    set -gx STARSHIP_CONFIG /etc/velocity/starship.toml
end
if status is-interactive
    type -q starship; and starship init fish | source
    type -q zoxide;   and zoxide init fish | source
end
