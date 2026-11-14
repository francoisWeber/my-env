# shellcheck shell=sh
# Point d'entrée du shell, sourcé par ~/.zshrc (bloc injecté par install.sh).
# Charge, dans l'ordre: common/ puis chaque profil actif, pour env.sh puis alias.sh.
# Un profil listé APRÈS peut donc surcharger ce qui vient avant.
# Enfin ~/.config/my-env/local.sh (hors dépôt: réglages propres à cette machine).

[ -n "${MY_ENV_DIR:-}" ] || return 0

# Ajoute un dossier au PATH s'il n'y est pas déjà (évite les doublons à chaque source).
path_prepend() { case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH" ;; esac; }
path_append()  { case ":$PATH:" in *":$1:"*) ;; *) PATH="$PATH:$1" ;; esac; }

_myenv_load() {
  # zsh ne découpe pas $VAR sans guillemets, contrairement à bash/sh
  [ -n "${ZSH_VERSION:-}" ] && setopt local_options sh_word_split
  _cfg="${XDG_CONFIG_HOME:-$HOME/.config}/my-env"
  _profiles="${MY_ENV_PROFILES:-}"
  if [ -z "$_profiles" ] && [ -r "$_cfg/profiles" ]; then _profiles="$(cat "$_cfg/profiles")"; fi
  _profiles="$(printf '%s' "${_profiles:-perso}" | tr ',' ' ')"

  for _f in env.sh alias.sh; do
    [ -r "$MY_ENV_DIR/common/$_f" ] && . "$MY_ENV_DIR/common/$_f"
    for _p in $_profiles; do
      [ -r "$MY_ENV_DIR/$_p/$_f" ] && . "$MY_ENV_DIR/$_p/$_f"
    done
  done
  [ -r "$_cfg/local.sh" ] && . "$_cfg/local.sh"
  unset _cfg _profiles _f _p
  return 0
}
_myenv_load
unset -f _myenv_load

# Retire les doublons du PATH en gardant la première occurrence (brew shellenv, sous-shells...)
PATH="$(printf '%s' "$PATH" | awk -v RS=: '!seen[$0]++ { printf "%s%s", sep, $0; sep=":" }')"
export PATH
