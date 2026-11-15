#!/usr/bin/env bash
# Copie un document source (PDF, etc.) dans raw/ sans le modifier.
# Usage : add-raw.sh <fichier source> "<type> <YYYY-MM-DD> - <nom rapide>.<ext>"
# Refuse un nom non conforme et n'écrase jamais une source existante (raw/ est immuable).
# Racine du wiki surchargeable via WIKI_ROOT.
set -euo pipefail

[ $# -eq 2 ] || { echo "usage : $(basename "$0") <fichier source> \"<type> <YYYY-MM-DD> - <nom rapide>.<ext>\"" >&2; exit 2; }
src="$1"; name="$2"
root="${WIKI_ROOT:-$HOME/Obsidian-LLM-wiki}"

[ -f "$src" ] || { echo "source introuvable : $src" >&2; exit 1; }
[[ "$name" =~ ^(discussion|PDF|URL|note|image)\ [0-9]{4}-[0-9]{2}-[0-9]{2}\ -\ [A-Za-z0-9\ -]+\.[A-Za-z0-9]+$ ]] \
  || { echo "nom non conforme : $name" >&2; exit 1; }

dest="$root/raw/$name"
[ -e "$dest" ] && { echo "existe deja, raw/ est immuable : raw/$name" >&2; exit 1; }

mkdir -p "$root/raw"
cp -n "$src" "$dest"
echo "raw/$name"
