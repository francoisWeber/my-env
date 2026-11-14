#!/usr/bin/env bash
# Génère une clé SSH ed25519 si elle n'existe pas (ne l'écrase JAMAIS), la charge
# dans l'agent + trousseau macOS, et prépare ~/.ssh/config.
#
#   scripts/ssh-key.sh [chemin_de_la_clé]     (défaut: ~/.ssh/id_ed25519)
set -euo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

KEY="${1:-$HOME/.ssh/id_ed25519}"
SSH_CONFIG="$HOME/.ssh/config"
BEGIN="# >>> my-env >>>"
END="# <<< my-env <<<"

run mkdir -p "$HOME/.ssh"
[ "$DRY_RUN" = 1 ] || chmod 700 "$HOME/.ssh"

# --- clé -----------------------------------------------------------------------
if [ -e "$KEY" ]; then
  ok "clé SSH déjà présente: $KEY (inchangée)"
else
  comment="$(whoami)@$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
  log "Génération de $KEY (ed25519). Choisis une passphrase quand ssh-keygen la demande."
  run ssh-keygen -t ed25519 -a 100 -C "$comment" -f "$KEY"
fi

# --- ~/.ssh/config: bloc idempotent, ajouté en fin de fichier -------------------
if [ -f "$SSH_CONFIG" ] && grep -Fxq "$BEGIN" "$SSH_CONFIG"; then
  ok "$SSH_CONFIG contient déjà le bloc my-env"
elif [ "$DRY_RUN" = 1 ]; then
  log "[dry-run] ajout du bloc 'Host *' (AddKeysToAgent, UseKeychain) dans $SSH_CONFIG"
else
  touch "$SSH_CONFIG"; chmod 600 "$SSH_CONFIG"
  {
    [ -s "$SSH_CONFIG" ] && printf '\n'
    printf '%s\n' "$BEGIN" "Host *" "  AddKeysToAgent yes" "  UseKeychain yes" "$END"
  } >> "$SSH_CONFIG"
  ok "bloc my-env ajouté à $SSH_CONFIG"
fi

# --- agent + clé publique ------------------------------------------------------
if [ "$DRY_RUN" != 1 ] && [ -f "$KEY" ]; then
  ssh-add --apple-use-keychain "$KEY" 2>/dev/null || warn "ssh-add a échoué (passphrase annulée ?)"
  if [ -f "$KEY.pub" ]; then
    pbcopy < "$KEY.pub" 2>/dev/null && ok "clé publique copiée dans le presse-papiers"
    echo "    $(cat "$KEY.pub")"
    echo "    Pour l'enregistrer sur GitHub:  gh ssh-key add \"$KEY.pub\" --title \"$(hostname -s)\""
  fi
fi
