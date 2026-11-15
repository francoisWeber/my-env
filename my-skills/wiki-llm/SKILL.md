---
name: wiki-llm
description: Interroger et alimenter le wiki personnel de l'utilisateur (Obsidian). Query quand l'utilisateur demande explicitement une recherche dans le wiki ("cherche dans le wiki", "as-tu un article sur le sujet ?", "que dit notre wiki ?" ou similaire). Ingest quand il demande explicitement d'y persister une information ou un document ("ajoute ça au wiki", "note ça dans le wiki", "verse ça à notre base de connaissance", "ingère ce document" ou équivalent). Ne pas déclencher sans demande explicite.
---

# LLM Wiki

Le wiki est un graphe de petits articles markdown inter-référencés façon Obsidian.md. On s'inspire de la méthode Zettelkasten qui consiste à mettre en place un graphe de notes atomiques qui se cross-référencent. Il capitalise les sources étudiées et la substance des discussions techniques, pour ne pas les redériver.

Deux opérations :
- **Query** (rechercher) : voir [query.md](query.md).
- **Ingest** (alimenter) : voir [ingest.md](ingest.md). Un ingest commence toujours par un query.

Lis le fichier correspondant à l'opération avant d'agir.

## Emplacement et structure

Racine : la variable d'environnement `WIKI_ROOT`, par défaut `~/Obsidian-LLM-wiki` (système de fichiers local, synchronisé par Nextcloud). Résous-la en premier avec `echo "${WIKI_ROOT:-$HOME/Obsidian-LLM-wiki}"` et utilise le chemin absolu obtenu, partout ci-dessous, avec les outils de lecture/écriture (ils n'acceptent pas `$VAR`). Les scripts du skill appliquent la même règle.

- `index.md` : une ligne par article, point d'entrée de la recherche.
- `graph.tsv` : graphe des liens entre articles, une arête `source<TAB>target` par ligne (en-tête `source	target`). **Fichier dérivé** : régénéré par le script `scripts/build-graph.sh` du skill, jamais édité à la main.
- `log.md` : journal append-only des écritures.
- `raw/` : sources immuables, jamais modifiées après création.
- `wiki/` : les articles.

Crée ces éléments s'ils sont absents (dossiers : `mkdir -p "<racine>/raw" "<racine>/wiki"`). Ne touche jamais à `.obsidian/` ni aux fichiers `.sync_*`.

## Nommage

Caractères autorisés dans tout nom de fichier : `a-z`, `A-Z`, `0-9`, espace, tiret. Pas d'accents, pas d'autre ponctuation (Obsidian casse les liens sur `/ \ : * ? " < > | # ^ [ ]`).

- **Article** : `<idée principale> - <YYYY-MM-DD>.md`, date de création. Un article n'est jamais renommé.
  Exemple : `Quantization binaire pour HNSW - 2026-11-13.md`
- **Source** : `<type> <YYYY-MM-DD> - <nom rapide>.<ext>`, type parmi `discussion`, `PDF`, `URL`, `note` (note manuscrite migrée depuis un autre vault, date = date de création de la note), `image` (pièce jointe d'une note migrée, référencée dans l'article par `![légende](../raw/<nom encodé en %20>)` et non par `[[ ]]`).
  Exemple : `PDF 2026-11-13 - HNSW Malkov.pdf`

## index.md

Une ligne par article : titre complet (lien) puis mots-clés en minuscules séparés par des virgules.

```markdown
- [[Quantization binaire pour HNSW - 2026-11-13]] > vespa, hnsw, binary-quantization, ann
```

Les mots-clés vivent uniquement ici : ils peuvent évoluer sans casser aucun lien.

## Article

```markdown
---
title: Quantization binaire pour HNSW - 2026-11-13
sources: ["raw/PDF 2026-11-13 - HNSW Malkov.pdf", "raw/discussion 2026-11-13 - tuning HNSW.md"]
updated: 2026-11-13
---
Texte concis, un seul sujet. Voir aussi [[Autre article - 2026-10-02]].
```

- `title` = nom du fichier sans `.md`. `updated` = date de dernière modification.
- Un seul sujet, **500 mots maximum** (équations LaTeX non comptées). Au-delà, extraire un concept dans un article à part et le référencer depuis l'article initial.
- Riche en liens `[[titre complet]]` vers des articles existants ou créés dans le même ingest.
