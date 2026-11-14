# shellcheck shell=bash
# Fonctions partagées par install.sh et scripts/*.sh (bash 3.2 compatible: macOS vierge).

MY_ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/my-env"
PROFILES_FILE="$CONFIG_DIR/profiles"
DRY_RUN="${DRY_RUN:-0}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ✓\033[0m  %s\n' "$*"; }
warn() { printf '\033[1;33m ! \033[0m  %s\n' "$*" >&2; }
die()  { printf '\033[1;31m ✗\033[0m  %s\n' "$*" >&2; exit 1; }

# Exécute la commande, ou l'affiche seulement en --dry-run.
run() {
  if [ "$DRY_RUN" = 1 ]; then
    printf '    [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

# Profils actifs: $MY_ENV_PROFILES > ~/.config/my-env/profiles > "perso". Séparés par virgule ou espace.
resolved_profiles() {
  local p="${MY_ENV_PROFILES:-}"
  if [ -z "$p" ] && [ -r "$PROFILES_FILE" ]; then
    p="$(cat "$PROFILES_FILE")"
  fi
  printf '%s\n' "${p:-perso}" | tr ',' ' '
}

# Couches à appliquer, dans l'ordre: common puis chaque profil (le dernier gagne).
layers() {
  local p
  echo common
  for p in $(resolved_profiles); do
    [ "$p" = common ] || echo "$p"
  done
}
