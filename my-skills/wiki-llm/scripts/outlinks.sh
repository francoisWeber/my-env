#!/usr/bin/env bash
# Liens sortants : articles référencés par l'article donné, lus dans graph.tsv.
# Usage : outlinks.sh "<titre complet de l'article>"
# Racine du wiki surchargeable via WIKI_ROOT.
set -euo pipefail
[ $# -eq 1 ] || { echo "usage : $(basename "$0") \"<titre complet>\"" >&2; exit 2; }
root="${WIKI_ROOT:-$HOME/Obsidian-LLM-wiki}"
awk -F'\t' -v t="$1" 'NR > 1 && $1 == t { print $2 }' "$root/graph.tsv"
