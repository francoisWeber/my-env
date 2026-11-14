# Variables d'environnement communes à tous les profils. À éditer à la main.
# Pas de secrets ici (dépôt public): ils vont dans ~/.config/my-env/local.sh.
# Helpers disponibles: path_prepend <dir>, path_append <dir> (sans doublons).

# Homebrew (Apple Silicon puis Intel)
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

path_prepend "$HOME/.local/bin"

# z: navigation par fréquence (brew "z")
[ -r "${HOMEBREW_PREFIX:-/opt/homebrew}/etc/profile.d/z.sh" ] && . "${HOMEBREW_PREFIX:-/opt/homebrew}/etc/profile.d/z.sh"

export EDITOR="code --wait"
export CLICOLOR=1
