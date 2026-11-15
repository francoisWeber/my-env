# Alias communs à tous les profils. À éditer à la main.

alias ll="ls -lhFG"
alias octal='stat -f %A'
alias ..='cd ..'
alias ...='cd ../..'

# thefuck: corrige la dernière commande en tapant `fuck` (brew "thefuck", cf. `brew info thefuck`)
command -v thefuck >/dev/null 2>&1 && eval "$(thefuck --alias)"
