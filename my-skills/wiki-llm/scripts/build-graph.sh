#!/usr/bin/env bash
# Régénère graph.tsv (liste d'arêtes source<TAB>target) à partir des liens [[...]] de wiki/.
# Usage : build-graph.sh [racine du wiki]   (défaut : $WIKI_ROOT, sinon ~/Obsidian-LLM-wiki)
set -euo pipefail

root="${1:-${WIKI_ROOT:-$HOME/Obsidian-LLM-wiki}}"
cd "$root"

# Seules les cibles correspondant à un article existant sont gardées : cela écarte les faux
# positifs (ex. LaTeX x[[1]]). Les liens cassés sont signalés sur stderr.
titles="$(mktemp)"; tmp="$(mktemp)"
trap 'rm -f "$titles" "$tmp"' EXIT
find wiki -type f -name '*.md' -exec basename {} .md \; > "$titles"
{
  printf 'source\ttarget\n'
  find wiki -type f -name '*.md' -exec awk -v titles="$titles" '
    BEGIN { while ((getline t < titles) > 0) known[t] = 1 }
    FNR == 1 { src = FILENAME; sub(/^.*\//, "", src); sub(/\.md$/, "", src) }
    {
      line = $0
      while (match(line, /\[\[[^]]+\]\]/)) {
        t = substr(line, RSTART + 2, RLENGTH - 4)
        sub(/[|#].*$/, "", t)   # retire alias [[X|alias]] et ancre [[X#titre]]
        if (t in known) print src "\t" t
        else if (t ~ /[A-Za-z]/) print "lien casse : " src " -> " t > "/dev/stderr"
        line = substr(line, RSTART + RLENGTH)
      }
    }' {} + | LC_ALL=C sort -u
} > "$tmp"
mv "$tmp" graph.tsv
