#!/usr/bin/env bash
# Bootstrap d'un Mac. Idempotent: peut être relancé sans risque.
# Mac vierge: télécharger le zip du dépôt, le placer dans ~/code/my-env, puis `bash install.sh`.
#
#   bash install.sh                      # profil "perso" (ou celui déjà enregistré)
#   bash install.sh --profile perso,pro  # superpose plusieurs profils
#   bash install.sh --dry-run            # montre ce qui serait fait, ne modifie rien
#   bash install.sh --skip brew,ssh      # étapes: xcode,brew,shell,git,ssh,skills,apps
set -euo pipefail

# shellcheck source=scripts/lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/lib.sh"

SKIP=","
PROFILES_ARG=""

usage() { sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1 ;;
    -p|--profile) PROFILES_ARG="${2:?--profile attend une valeur}"; shift ;;
    --skip)       SKIP=",${2:?--skip attend une liste}," ; shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            usage; die "option inconnue: $1" ;;
  esac
  shift
done
export DRY_RUN

skipped() { case "$SKIP" in *",$1,"*) return 0 ;; esac; return 1; }

[ "$(uname -s)" = Darwin ] || die "Ce bootstrap cible macOS uniquement."
# Le bloc ajouté au .zshrc pointe vers ce dossier pour toujours: pas depuis un endroit temporaire.
case "$MY_ENV_DIR" in
  "$HOME"/Downloads/*|/tmp/*|/private/tmp/*|/var/folders/*|/private/var/folders/*)
    if [ "$DRY_RUN" != 1 ]; then
      die "Dossier temporaire ($MY_ENV_DIR). Déplace-le d'abord: mkdir -p ~/code && mv \"$MY_ENV_DIR\" ~/code/my-env && bash ~/code/my-env/install.sh"
    fi ;;
esac
[ -n "$PROFILES_ARG" ] && MY_ENV_PROFILES="$PROFILES_ARG"
export MY_ENV_PROFILES="$(resolved_profiles)"
for p in $MY_ENV_PROFILES; do
  [ -d "$MY_ENV_DIR/$p" ] || die "Profil inconnu: '$p' (dossier $MY_ENV_DIR/$p introuvable)"
done
[ "$DRY_RUN" = 1 ] && warn "Mode --dry-run: rien ne sera modifié."
log "Dépôt: $MY_ENV_DIR"
log "Profils: common + $MY_ENV_PROFILES"

# --- 1. Xcode Command Line Tools --------------------------------------------
step_xcode() {
  if xcode-select -p >/dev/null 2>&1; then ok "Xcode CLT déjà présents"; return; fi
  log "Installation des Xcode Command Line Tools (une fenêtre va s'ouvrir)"
  run xcode-select --install || true
  if [ "$DRY_RUN" != 1 ]; then
    until xcode-select -p >/dev/null 2>&1; do sleep 5; done
  fi
}

# --- 2. Homebrew + Brewfiles -------------------------------------------------
find_brew() {
  local p
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$p" ] && { echo "$p"; return 0; }
  done
  command -v brew
}

install_homebrew() {
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

step_brew() {
  local brew layer file
  brew="$(find_brew || true)"
  if [ -z "$brew" ]; then
    log "Installation de Homebrew"
    run install_homebrew
    brew="$(find_brew || true)"
  else
    ok "Homebrew déjà présent"
  fi
  if [ -z "$brew" ]; then warn "brew introuvable (dry-run ?): bundles ignorés"; return; fi
  eval "$("$brew" shellenv)"
  export HOMEBREW_NO_ENV_HINTS=1
  for layer in $(layers); do
    file="$MY_ENV_DIR/$layer/Brewfile"
    [ -f "$file" ] || continue
    log "brew bundle: $layer/Brewfile"
    run "$brew" bundle --file="$file" \
      || warn "Erreurs dans $layer/Brewfile (app déjà installée hors brew ? essaie: brew install --cask --adopt <nom>)"
  done
}

# --- 3. Injection dans ~/.zshrc (et ~/.bashrc s'il existe) --------------------
BLOCK_BEGIN="# >>> my-env >>>"
BLOCK_END="# <<< my-env <<<"

shell_block() {
  local dir="$MY_ENV_DIR"
  case "$dir" in "$HOME"/*) dir="\$HOME${dir#"$HOME"}" ;; esac
  printf '%s\n' "$BLOCK_BEGIN"
  printf '%s\n' "# Géré par my-env/install.sh. Éditer les fichiers du dépôt, pas ce bloc."
  printf 'export MY_ENV_DIR="%s"\n' "$dir"
  printf '%s\n' '[ -r "$MY_ENV_DIR/shell/init.sh" ] && . "$MY_ENV_DIR/shell/init.sh"'
  printf '%s\n' "$BLOCK_END"
}

inject_block() {
  local file="$1" desired existing tmp
  desired="$(shell_block)"
  existing=""
  [ -f "$file" ] && existing="$(awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" '$0==b{p=1} p{print} $0==e{p=0}' "$file")"
  if [ "$existing" = "$desired" ]; then ok "$file déjà à jour"; return; fi
  if [ "$DRY_RUN" = 1 ]; then log "[dry-run] injection du bloc my-env dans $file"; return; fi
  touch "$file"
  [ -e "$file.pre-my-env" ] || cp "$file" "$file.pre-my-env"
  tmp="$(mktemp)"
  awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" '$0==b{s=1;next} $0==e{s=0;next} !s' "$file" > "$tmp"
  { cat "$tmp"; [ -s "$tmp" ] && printf '\n'; printf '%s\n' "$desired"; } > "$file"
  rm -f "$tmp"
  ok "bloc my-env écrit dans $file (sauvegarde: $file.pre-my-env)"
}

step_shell() {
  inject_block "$HOME/.zshrc"
  [ -f "$HOME/.bashrc" ] && inject_block "$HOME/.bashrc"
  if [ "$DRY_RUN" != 1 ]; then
    mkdir -p "$CONFIG_DIR"
    printf '%s\n' "$MY_ENV_PROFILES" > "$PROFILES_FILE"
    ok "profils enregistrés dans $PROFILES_FILE"
  fi
}

# --- 4. Git: include du gitconfig partagé + identité + hook anti-secrets ------
step_git() {
  local inc="$MY_ENV_DIR/git/gitconfig" name email
  if git config --global --get-all include.path 2>/dev/null | grep -Fxq "$inc"; then
    ok "gitconfig partagé déjà inclus"
  else
    run git config --global --add include.path "$inc"
  fi
  if command -v git-lfs >/dev/null 2>&1; then run git lfs install --skip-repo >/dev/null; fi
  if [ -z "$(git config --global user.email || true)" ] && [ "$DRY_RUN" != 1 ] && ( : </dev/tty ) 2>/dev/null; then
    printf 'Identité git (user.name): ' >/dev/tty; read -r name </dev/tty
    printf 'Identité git (user.email): ' >/dev/tty; read -r email </dev/tty
    [ -n "$name" ]  && git config --global user.name "$name"
    [ -n "$email" ] && git config --global user.email "$email"
  fi
  if [ -d "$MY_ENV_DIR/.git" ]; then
    run git -C "$MY_ENV_DIR" config core.hooksPath .githooks
  fi
}

# --- 5. Clé SSH --------------------------------------------------------------
step_ssh() { bash "$MY_ENV_DIR/scripts/ssh-key.sh" "${MY_ENV_SSH_KEY:-$HOME/.ssh/id_ed25519}"; }

# --- 6. Skills Claude ---------------------------------------------------------------
# <couche>/skills.list, une ligne par skill:
#   <nom>                            -> lien symbolique vers my-skills/<nom>
#   <url git> <chemin> <commit|tag>  -> copie figée du dossier <chemin> du dépôt public
# Un dossier déjà présent dans ~/.claude/skills et non géré par nous n'est jamais écrasé:
# il est déplacé en <nom>.pre-my-env.
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

set_aside() {
  local t="$1"
  { [ -e "$t" ] || [ -L "$t" ]; } || return 0
  if [ -e "$t.pre-my-env" ] || [ -L "$t.pre-my-env" ]; then
    warn "$t existe, et $t.pre-my-env aussi: ignoré, à résoudre à la main"; return 1
  fi
  run mv "$t" "$t.pre-my-env"
  warn "$t déjà présent: déplacé en $t.pre-my-env"
}

skill_local() {
  local name="$1" src="$MY_ENV_DIR/my-skills/$1" dst="$SKILLS_DIR/$1"
  if [ ! -f "$src/SKILL.md" ]; then warn "skill local introuvable: my-skills/$name"; return 0; fi
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then ok "skill $name déjà lié"; return 0; fi
  if [ -L "$dst" ]; then run rm "$dst"; else set_aside "$dst" || return 0; fi
  run ln -s "$src" "$dst"
  if [ "$DRY_RUN" != 1 ]; then ok "skill $name -> my-skills/$name"; fi
}

skill_public() {
  local url="$1" path="$2" rev="$3" name dst want tmp
  name="$(basename "$path")"; dst="$SKILLS_DIR/$name"; want="$url $path $rev"
  if [ -f "$dst/.my-env-source" ] && [ "$(cat "$dst/.my-env-source")" = "$want" ]; then
    ok "skill $name déjà à jour ($rev)"; return 0
  fi
  if [ "$DRY_RUN" = 1 ]; then log "[dry-run] skill $name <- $url @ $rev"; return 0; fi
  tmp="$(mktemp -d)"
  if ! { git -C "$tmp" init -q && git -C "$tmp" fetch -q --depth 1 "$url" "$rev" && git -C "$tmp" checkout -q FETCH_HEAD; }; then
    warn "skill $name: impossible de récupérer '$rev' depuis $url (SHA complet de 40 caractères ou tag requis)"
    rm -rf "$tmp"; return 0
  fi
  if [ ! -f "$tmp/$path/SKILL.md" ]; then
    warn "skill $name: $path/SKILL.md absent à $rev"; rm -rf "$tmp"; return 0
  fi
  if [ -f "$dst/.my-env-source" ]; then rm -rf "$dst"; else set_aside "$dst" || { rm -rf "$tmp"; return 0; }; fi
  cp -R "$tmp/$path" "$dst"
  printf '%s\n' "$want" > "$dst/.my-env-source"
  rm -rf "$tmp"
  ok "skill $name installé depuis $url @ ${rev:0:12}"
}

step_skills() {
  local layer f line a b c rest
  run mkdir -p "$SKILLS_DIR"
  for layer in $(layers); do
    f="$MY_ENV_DIR/$layer/skills.list"
    [ -f "$f" ] || continue
    # fd 3: git/ssh lisent stdin et avaleraient le reste du fichier
    while IFS= read -r -u 3 line || [ -n "$line" ]; do
      line="${line%%#*}"
      read -r a b c rest <<< "$line" || true
      [ -n "${a:-}" ] || continue
      case "$a" in
        *://*|git@*)
          if [ -n "${c:-}" ]; then skill_public "$a" "$b" "$c"
          else warn "$layer/skills.list: ligne incomplète (url chemin commit): $a"; fi ;;
        *) skill_local "$a" ;;
      esac
    done 3< "$f"
  done
}

# --- 7. Config des apps ----------------------------------------------------------
# Rectangle lit ~/Library/Application Support/Rectangle/RectangleConfig.json à son lancement
# et demande confirmation dans une popup avant d'appliquer (puis consomme le fichier).
step_apps() {
  local src="$MY_ENV_DIR/apps-configs/RectangleConfig.json"
  local dir="$HOME/Library/Application Support/Rectangle"
  if [ ! -d /Applications/Rectangle.app ] && [ "$DRY_RUN" != 1 ]; then
    warn "Rectangle non installé: config ignorée"; return 0
  fi
  run mkdir -p "$dir"
  run cp "$src" "$dir/RectangleConfig.json"
  if pgrep -x Rectangle >/dev/null 2>&1; then
    warn "Rectangle tourne déjà: quitte-le et relance-le pour qu'il propose d'appliquer la config"
  else
    run open -a Rectangle
    ok "Rectangle lancé: accepte la popup pour appliquer la config"
  fi
}

for step in xcode brew shell git ssh skills apps; do
  if skipped "$step"; then warn "étape '$step' ignorée"; continue; fi
  log "Étape: $step"
  "step_$step"
done

echo
ok "Terminé. Ouvre un nouveau terminal (ou: exec zsh) pour charger la config."
